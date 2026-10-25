extends Node
class_name AudioSystem

# PORT-TRACE: src/core/AudioSystem.ts (Web Audio 오실레이터 효과음)
# 이식 로그: docs/godot_port_log.md 항목 P20
## TS의 오실레이터 기반 절차적 효과음을 AudioStreamWAV PCM 버퍼로 합성하여 재현한다.
## 에셋 파일 없이 순수 코드로 파형을 생성하므로 별도 사운드 리소스가 필요 없다.

enum Wave { SINE, TRIANGLE, SAWTOOTH }

const MIX_RATE := 22050
var enabled: bool = true
var _players: Array = []
var _pool_idx: int = 0

const POOL_SIZE := 6
var _warm_task := -1

func _ready() -> void:
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	# PORT-TRACE [렉: 첫 종소리 멈칫]: 종·취타·포성은 처음 울릴 때 그 자리에서 합성하느라(0.1초 남짓) 첫 달 정산 때 멈칫했다
	# → 시작할 때 일꾼 스레드에서 미리 합성해 둔다
	_warm_task = WorkerThreadPool.add_task(_warm_streams)

func _warm_streams() -> void:
	_bell_stream()
	_yajo_stream()
	_cannon_stream()

## 미리 합성이 아직 도는 중이면 끝날 때까지 기다린다(같은 소리를 두 스레드가 함께 만들지 않게)
func _wait_warm() -> void:
	if _warm_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_warm_task)
		_warm_task = -1

func _exit_tree() -> void:
	_wait_warm()

## type: "hammer" | "wall" | "coin" | "season" | "demolish" | "error" | "gavel"
func play(type: String) -> void:
	if not enabled:
		return
	if type == "bell" or type == "yajo" or type == "cannon":
		_wait_warm()
	var stream: AudioStreamWAV = _bell_stream() if type == "bell" else (_yajo_stream() if type == "yajo" else (_cannon_stream() if type == "cannon" else (_fx_stream(type) if type in ["gun", "roar", "scream", "gavel"] else _synthesize(type))))
	if stream == null:
		return
	if _players.is_empty():
		return
	var p = _players[_pool_idx]
	_pool_idx = (_pool_idx + 1) % _players.size()
	if p != null and is_instance_valid(p) and p is AudioStreamPlayer:
		p.stream = stream
		p.play()

## 주파수 2단(또는 지수 램프) + 지수 감쇠 게인 엔벨로프를 샘플 버퍼로 합성한다.
func _synthesize(type: String) -> AudioStreamWAV:
	var wave: int
	var f0: float
	var f1: float
	var dur: float
	var amp: float
	var stepped := false # true면 f0->f1 즉시 전환(setValueAtTime x2), false면 지수 램프

	match type:
		"hammer":
			wave = Wave.TRIANGLE; f0 = 140.0; f1 = 45.0; dur = 0.12; amp = 0.35
		"wall":
			wave = Wave.SINE; f0 = 95.0; f1 = 30.0; dur = 0.25; amp = 0.6
		"coin":
			wave = Wave.SINE; f0 = 659.25; f1 = 987.77; dur = 0.25; amp = 0.2; stepped = true
		"season":
			wave = Wave.TRIANGLE; f0 = 392.0; f1 = 523.25; dur = 0.6; amp = 0.3; stepped = true
		"demolish":
			wave = Wave.SAWTOOTH; f0 = 120.0; f1 = 30.0; dur = 0.3; amp = 0.4
		"error":
			wave = Wave.SAWTOOTH; f0 = 160.0; f1 = 110.0; dur = 0.25; amp = 0.3; stepped = true
		_:
			return null

	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var step_point := int(n * (0.08 / dur)) if stepped and dur > 0.08 else int(n * 0.5)
	for i in range(n):
		var t := float(i) / MIX_RATE
		var freq: float
		if stepped:
			freq = f0 if i < step_point else f1
		else:
			# 지수 램프: f(t) = f0 * (f1/f0)^(t/dur)
			var ratio := f1 / f0 if f0 != 0.0 else 1.0
			freq = f0 * pow(ratio, t / dur)
		phase += freq / MIX_RATE
		var s: float
		match wave:
			Wave.SINE:
				s = sin(phase * TAU)
			Wave.TRIANGLE:
				s = 2.0 * abs(2.0 * fposmod(phase, 1.0) - 1.0) - 1.0
			Wave.SAWTOOTH:
				s = 2.0 * fposmod(phase, 1.0) - 1.0
			_:
				s = 0.0
		# 지수 감쇠 게인 (0.01까지)
		var env := amp * pow(0.01 / amp, t / dur) if amp > 0.0 else 0.0
		var v := clampf(s * env, -1.0, 1.0)
		var sample := int(v * 32767.0)
		data.encode_s16(i * 2, sample)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream

## PORT-TRACE [종루(여민각) 2x2]: 범종 소리 — 맑고 묵직한 타종. 낮은 기본음 두 개(살짝 어긋나 "웅~웅" 맥놀이)
## + 비정수배 상음(종 특유의 쇳소리)이 서로 다른 빠르기로 사라진다. 4초 분량이라 한 번만 합성해 둔다.
var _bell_cache: AudioStreamWAV = null
func _bell_stream() -> AudioStreamWAV:
	if _bell_cache != null:
		return _bell_cache
	var dur := 4.0
	var n := int(MIX_RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var partials: Array = [[110.0, 0.42, 1.2], [111.3, 0.36, 1.25], [220.6, 0.16, 0.7], [294.0, 0.12, 0.5], [421.0, 0.08, 0.35], [598.0, 0.05, 0.22]]
	for i in range(n):
		var t := float(i) / MIX_RATE
		var s := 0.0
		for pt: Array in partials:
			s += sin(TAU * float(pt[0]) * t) * float(pt[1]) * exp(-t / (float(pt[2]) * dur * 0.4))
		var attack := minf(1.0, t / 0.008) # 당목이 치는 순간
		data.encode_s16(i * 2, int(clampf(s * attack * 0.8, -1.0, 1.0) * 32767.0))
	_bell_cache = AudioStreamWAV.new()
	_bell_cache.format = AudioStreamWAV.FORMAT_16_BITS
	_bell_cache.mix_rate = MIX_RATE
	_bell_cache.stereo = false
	_bell_cache.data = data
	return _bell_cache

## PORT-TRACE [서장대 야조]: 취타 — 북 셋(둥·둥·둥) 뒤 징 한 번(웅~), 3.5초. 한 번만 합성.
var _yajo_cache: AudioStreamWAV = null
func _yajo_stream() -> AudioStreamWAV:
	if _yajo_cache != null:
		return _yajo_cache
	var n := int(MIX_RATE * 3.5)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for at: float in [0.0, 0.4, 0.8]:
		var s0 := int(at * MIX_RATE)
		var ph := 0.0
		for k in range(int(0.6 * MIX_RATE)):
			var t := float(k) / MIX_RATE
			ph += lerpf(100.0, 58.0, minf(1.0, t / 0.2)) / MIX_RATE
			buf[s0 + k] += sin(TAU * ph) * 0.7 * exp(-t / 0.16)
	var g0 := int(1.25 * MIX_RATE)
	for k in range(n - g0):
		var t := float(k) / MIX_RATE
		var g := sin(TAU * 196.0 * t) * 0.3 + sin(TAU * 199.5 * t) * 0.25 + sin(TAU * 287.0 * t) * 0.12 + sin(TAU * 411.0 * t) * 0.05
		buf[g0 + k] += g * exp(-t / 0.9) * minf(1.0, t / 0.02)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		data.encode_s16(i * 2, int(clampf(buf[i] * 0.8, -1.0, 1.0) * 32767.0))
	_yajo_cache = AudioStreamWAV.new()
	_yajo_cache.format = AudioStreamWAV.FORMAT_16_BITS
	_yajo_cache.mix_rate = MIX_RATE
	_yajo_cache.stereo = false
	_yajo_cache.data = data
	return _yajo_cache

## PORT-TRACE [포루 포격 훈련]: 묵직한 포성 — 낮게 미끄러지는 저음 + 거친 잡음 폭발 + 우르릉 여운, 2.5초. 한 번만 합성.
var _cannon_cache: AudioStreamWAV = null
func _cannon_stream() -> AudioStreamWAV:
	if _cannon_cache != null:
		return _cannon_cache
	var n := int(MIX_RATE * 2.5)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1795
	var ph := 0.0
	var lp := 0.0
	for i in range(n):
		var t := float(i) / MIX_RATE
		ph += lerpf(75.0, 32.0, minf(1.0, t / 0.4)) / MIX_RATE
		lp += 0.06 * (rng.randf_range(-1.0, 1.0) - lp)
		var v := sin(TAU * ph) * 0.8 * exp(-t / 0.35) + lp * 3.2 * exp(-t / 0.6) + rng.randf_range(-1.0, 1.0) * 0.5 * exp(-t / 0.03)
		data.encode_s16(i * 2, int(clampf(v * 0.85, -1.0, 1.0) * 32767.0))
	_cannon_cache = AudioStreamWAV.new()
	_cannon_cache.format = AudioStreamWAV.FORMAT_16_BITS
	_cannon_cache.mix_rate = MIX_RATE
	_cannon_cache.stereo = false
	_cannon_cache.data = data
	return _cannon_cache

## PORT-TRACE [효과음 리미터]: 사용자 요청 — 맹수 포효·포격·비명·전투음이 한꺼번에 나도 볼륨이 터지지 않게 동시 3개까지,
## 같은 소리는 0.1초 안에 다시 내지 않는다(스로틀).
var _last_play := {}
func play_limited(type: String) -> void:
	if not enabled:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(type, -100000)) < 100:
		return
	var busy := 0
	for p: AudioStreamPlayer in _players:
		if p.playing:
			busy += 1
	if busy >= 3:
		return
	_last_play[type] = now
	play(type)

## 조총(탕! 짧은 잡음 + 둔탁한 저음), 범 포효(낮게 으르렁대는 톱니+잡음), 비명(떨리는 높은 음) — 각각 한 번만 합성
var _fx_cache := {}
func _fx_stream(type: String) -> AudioStreamWAV:
	if _fx_cache.has(type):
		return _fx_cache[type]
	var dur: float = {"gun": 0.5, "roar": 1.2, "scream": 0.6, "gavel": 0.35}.get(type, 0.4)
	var n := int(float(MIX_RATE) * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(type)
	var ph := 0.0
	var lp := 0.0
	for i in range(n):
		var t := float(i) / float(MIX_RATE)
		var v := 0.0
		match type:
			"gun":
				lp += 0.3 * (rng.randf_range(-1.0, 1.0) - lp)
				ph += lerpf(160.0, 60.0, minf(1.0, t / 0.1)) / float(MIX_RATE)
				v = rng.randf_range(-1.0, 1.0) * 0.8 * exp(-t / 0.015) + lp * 0.9 * exp(-t / 0.12) + sin(TAU * ph) * 0.5 * exp(-t / 0.08)
			"roar":
				ph += (70.0 + 15.0 * sin(TAU * 6.0 * t)) / float(MIX_RATE)
				lp += 0.05 * (rng.randf_range(-1.0, 1.0) - lp)
				var env := minf(1.0, t / 0.15) * exp(-maxf(0.0, t - 0.5) / 0.3)
				v = ((2.0 * fposmod(ph, 1.0) - 1.0) * 0.35 + lp * 2.0) * env
			"scream":
				ph += (980.0 + 160.0 * sin(TAU * 9.0 * t) + 300.0 * t) / float(MIX_RATE)
				var env2 := minf(1.0, t / 0.05) * exp(-maxf(0.0, t - 0.3) / 0.15)
				v = sin(TAU * ph) * 0.25 * env2
			"gavel":
				# 판결봉 타격음: 묵직한 오동나무 판결봉이 개석(목판)을 강하게 내려치는 둔탁하고 울림 있는 타격
				var burst := rng.randf_range(-1.0, 1.0) * exp(-t / 0.012) * 0.7
				var thud1 := sin(TAU * (140.0 * exp(-t / 0.06)) * t) * exp(-t / 0.08) * 0.6
				var body_res := sin(TAU * 260.0 * t) * exp(-t / 0.18) * 0.35 + sin(TAU * 480.0 * t) * exp(-t / 0.04) * 0.2
				v = burst + thud1 + body_res
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = MIX_RATE
	st.stereo = false
	st.data = data
	_fx_cache[type] = st
	return st
