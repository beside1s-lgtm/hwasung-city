extends Node
class_name BuildingAmbience

## PORT-TRACE [건물 단독 확대 효과음]: 사용자 요청 — "카메라를 일정 배율 이상 확대해 특수 건물 하나만 화면에 들어올 때만
## 그 건물의 고유 효과음(봉돈 바람·불, 연무대 기합·활시위, 포루 포성, 서장대 징·북, 관아 곤장·문초)을 틀고, 둘 이상이
## 함께 보이면 모두 끄라". 성능 원칙(사용자 명시): 매 프레임 판정하지 않는다 — 카메라가 움직이면 타이머만 되돌리고,
## 멈춘 뒤 0.2초가 지나면 딱 한 번 화면 안 특수 건물 수를 센다(디바운스). 건물 위치 목록은 지도가 바뀔 때만 다시 모은다.
## 소리는 에셋 없이 PCM으로 합성해 반복 재생(루프)하며, 처음 쓸 때 한 번만 만든다. 기존 AudioSystem은 건드리지 않는다.

const ZOOM_IN_THRESHOLD := 1.6
const DEBOUNCE := 0.2
const MIX_RATE := 22050
const LOOP_SEC := 3.0
## 건물 → 소리 종류
const SOUND_OF := {
	"bongdon": "bongdon", "yeonmudae": "yeonmudae", "poru": "poru", "seojangdae": "seojangdae",
	"gwana": "gwana", "haenggung": "gwana",
	"hyanggyo": "ritual", # PORT-TRACE [교육 기관]: 향교 = 제례 악기(편종·편경·북)
}

var grid: GameGrid
var camera: Camera2D
var city: CityLayer
var audio: AudioSystem

var _player: AudioStreamPlayer
var _tween: Tween
var _cache := {}         # 소리 종류 → AudioStreamWAV
var _spots: Array = []   # [{pos: Vector2(화면 좌표), kind}]
var _spots_dirty := true
var _last_pos := Vector2.INF
var _last_zoom := 0.0
var _still := 0.0
var _pending := true
var active := false # false면 소리를 내지 않는다(타이틀 화면)
var _playing := ""

func setup(g: GameGrid, cam: Camera2D, c: CityLayer, a: AudioSystem) -> void:
	grid = g
	camera = cam
	city = c
	audio = a
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = -60.0
	add_child(_player)
	grid.grid_changed.connect(func():
		_spots_dirty = true
		_pending = true
	)

func _process(delta: float) -> void:
	if camera == null:
		return
	if not active and _playing != "":
		_set_sound("")
	var pos := camera.get_screen_center_position()
	var z := camera.zoom.x
	if pos != _last_pos or z != _last_zoom:
		_last_pos = pos
		_last_zoom = z
		_still = 0.0
		_pending = true
		return
	if not _pending:
		return
	_still += delta
	if _still >= DEBOUNCE:
		_pending = false
		_evaluate()

func _evaluate() -> void:
	if not active:
		_set_sound("")
		return
	if audio != null and not audio.enabled:
		_set_sound("")
		return
	if _last_zoom < ZOOM_IN_THRESHOLD:
		_set_sound("")
		return
	if _spots_dirty:
		_collect_spots()
	var view_size := get_viewport().get_visible_rect().size / _last_zoom
	var view := Rect2(_last_pos - view_size * 0.5, view_size)
	var found := ""
	var count := 0
	for s: Dictionary in _spots:
		if view.has_point(s["pos"]):
			count += 1
			found = s["kind"]
			if count >= 2:
				break
	_set_sound(found if count == 1 else "") # 둘 이상이면 모두 음소거

## 특수 건물 위치(행궁·관아는 앵커 한 칸만)
func _collect_spots() -> void:
	_spots_dirty = false
	_spots.clear()
	for y in range(grid.size):
		for x in range(grid.size):
			var t: Dictionary = grid.grid[y][x]
			var b: String = t["building"]
			# 서당·매곡서원(공터 묶음의 기준 칸) = 글 읽는 소리
			if b == "" and t.has("plaza") and str(t["plaza"].get("kind", "")) in ["seodang", "seowon", "maegok_seowon"] and int(t["plaza"]["x0"]) == x and int(t["plaza"]["y0"]) == y:
				_spots.append({"pos": city.cell_center(float(x) + 1.0, float(y) + 1.0, float(t.get("elevation", 1.0))), "kind": "reading"})
			if SOUND_OF.has(b) and not t.has("wall_build"):
				var e := float(t.get("elevation", 1.0))
				_spots.append({"pos": city.cell_center(float(x) + 0.5, float(y) + 0.5, e), "kind": SOUND_OF[b]})

func _set_sound(kind: String) -> void:
	if kind == _playing:
		return
	_playing = kind
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	if kind == "":
		_tween.tween_property(_player, "volume_db", -60.0, 0.5)
		_tween.tween_callback(_player.stop)
		return
	_player.stream = _stream(kind)
	if not _player.playing:
		_player.volume_db = -60.0
		_player.play()
	_tween.tween_property(_player, "volume_db", -8.0, 0.8)

# ---------------------------------------------------------------- 합성
func _stream(kind: String) -> AudioStreamWAV:
	if _cache.has(kind):
		return _cache[kind]
	var n := int(MIX_RATE * LOOP_SEC)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	match kind:
		"bongdon": _syn_bongdon(buf, rng)
		"yeonmudae": _syn_yeonmudae(buf, rng)
		"poru": _syn_poru(buf, rng)
		"seojangdae": _syn_seojangdae(buf, rng)
		"gwana": _syn_gwana(buf, rng)
		"reading": _syn_reading(buf, rng)
		"ritual": _syn_ritual(buf, rng)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = MIX_RATE
	st.stereo = false
	st.data = data
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = n
	_cache[kind] = st
	return st

## 저역 통과한 잡음(바람·웅성임·화염 바탕)
func _noise_bed(buf: PackedFloat32Array, rng: RandomNumberGenerator, alpha: float, amp: float, wobble_hz: float) -> void:
	var lp := 0.0
	for i in range(buf.size()):
		var t := float(i) / MIX_RATE
		lp += alpha * (rng.randf_range(-1.0, 1.0) - lp)
		# 반복 이음매가 튀지 않게 고리 모양 흔들림(루프 길이의 정수배 주기)
		var wob := 0.6 + 0.4 * sin(TAU * t * wobble_hz)
		buf[i] += lp * amp * wob

## 감쇠하는 사인(타격음·북·포성 저음). f1로 음높이가 미끄러진다.
func _hit(buf: PackedFloat32Array, at: float, f0: float, f1: float, decay: float, amp: float) -> void:
	var s0 := int(at * MIX_RATE)
	var ph := 0.0
	var anim_len := mini(buf.size() - s0, int(decay * 6.0 * MIX_RATE))
	for k in range(maxi(0, anim_len)):
		var t := float(k) / MIX_RATE
		var f := lerpf(f0, f1, minf(1.0, t / decay))
		ph += f / MIX_RATE
		buf[s0 + k] += sin(TAU * ph) * amp * exp(-t / decay)

## 짧은 잡음 터짐(곤장·딱 소리·불티)
func _burst(buf: PackedFloat32Array, rng: RandomNumberGenerator, at: float, decay: float, amp: float) -> void:
	var s0 := int(at * MIX_RATE)
	var anim_len := mini(buf.size() - s0, int(decay * 6.0 * MIX_RATE))
	for k in range(maxi(0, anim_len)):
		buf[s0 + k] += rng.randf_range(-1.0, 1.0) * amp * exp(-float(k) / MIX_RATE / decay)

## 봉돈: 높은 곳의 바람 + 봉화 장작 타닥거림
func _syn_bongdon(buf: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	_noise_bed(buf, rng, 0.015, 1.4, 1.0 / LOOP_SEC)
	for i in range(28):
		_burst(buf, rng, rng.randf_range(0.0, LOOP_SEC - 0.1), rng.randf_range(0.004, 0.012), rng.randf_range(0.15, 0.4))
	_noise_bed(buf, rng, 0.12, 0.08, 2.0 / LOOP_SEC) # 화염 쉭쉭

## 연무대: 기합(낮은 톱니 "얍") + 활시위 튕김 + 과녁 맞는 소리
func _syn_yeonmudae(buf: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	for at: float in [0.15, 1.6]:
		var s0 := int(at * MIX_RATE)
		var ph := 0.0
		var lp := 0.0
		for k in range(int(0.28 * MIX_RATE)):
			var t := float(k) / MIX_RATE
			ph += lerpf(190.0, 150.0, t / 0.28) / MIX_RATE
			var saw := 2.0 * fposmod(ph, 1.0) - 1.0
			lp += 0.18 * (saw - lp)
			buf[s0 + k] += lp * 0.5 * sin(PI * t / 0.28)
	for at2: float in [0.8, 2.3]:
		_hit(buf, at2, 330.0, 240.0, 0.12, 0.35) # 시위 퉁
		_burst(buf, rng, at2, 0.006, 0.3)
		_hit(buf, at2 + 0.35, 110.0, 80.0, 0.05, 0.5) # 과녁 퍽
		_burst(buf, rng, at2 + 0.35, 0.02, 0.25)
	_noise_bed(buf, rng, 0.03, 0.12, 1.0 / LOOP_SEC)

## 포루: 묵직한 포성과 우르릉 여운
func _syn_poru(buf: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	_hit(buf, 0.2, 70.0, 38.0, 0.35, 0.9)
	var s0 := int(0.2 * MIX_RATE)
	var lp := 0.0
	for k in range(buf.size() - s0):
		var t := float(k) / MIX_RATE
		lp += 0.04 * (rng.randf_range(-1.0, 1.0) - lp)
		buf[s0 + k] += lp * 3.0 * exp(-t / 0.7)
	_noise_bed(buf, rng, 0.01, 0.3, 1.0 / LOOP_SEC)

## 서장대: 북 둥·둥·둥 + 징 웅~
func _syn_seojangdae(buf: PackedFloat32Array, _rng: RandomNumberGenerator) -> void:
	for at: float in [0.0, 0.45, 0.9]:
		_hit(buf, at, 95.0, 60.0, 0.18, 0.6)
	var s0 := int(1.35 * MIX_RATE)
	for k in range(buf.size() - s0):
		var t := float(k) / MIX_RATE
		var g := sin(TAU * 196.0 * t) * 0.3 + sin(TAU * 199.5 * t) * 0.25 + sin(TAU * 287.0 * t) * 0.12 + sin(TAU * 411.0 * t) * 0.06
		buf[s0 + k] += g * exp(-t / 0.9) * minf(1.0, t / 0.03)

## 관아: 곤장 "딱!" 두 번 + 웅성이는 문초 소리
func _syn_gwana(buf: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	_noise_bed(buf, rng, 0.05, 0.25, 2.0 / LOOP_SEC)
	for at: float in [0.6, 2.0]:
		_burst(buf, rng, at, 0.012, 0.9)
		_hit(buf, at, 600.0, 420.0, 0.02, 0.4)

## 서당·서원: 아이들 글 읽는 소리 — 음절마다 높낮이가 오르내리는(하늘 천~ 따 지~) 노랫가락, 두 목소리가 조금 어긋나게
func _syn_reading(buf: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var contour := [1.0, 1.25, 1.0, 0.9, 1.12, 1.0, 1.33, 1.0, 0.9, 1.0, 1.25, 1.12]
	for voice in range(2):
		var ph := 0.0
		var lp := 0.0
		var base := 210.0 if voice == 0 else 262.0
		for i in range(buf.size()):
			var t := float(i) / MIX_RATE + float(voice) * 0.08
			var syl := int(t / 0.25) % contour.size()
			var st := fmod(t, 0.25) / 0.25
			ph += base * float(contour[syl]) * (1.0 + 0.03 * sin(t * 30.0)) / MIX_RATE
			var saw := 2.0 * fposmod(ph, 1.0) - 1.0
			lp += 0.12 * (saw - lp)
			buf[i] += lp * 0.22 * sin(PI * clampf(st * 1.1, 0.0, 1.0))
	_noise_bed(buf, rng, 0.02, 0.05, 1.0 / LOOP_SEC)

## 향교 제례악: 편종·편경 같은 맑은 쇳소리(황·태·중·임·남 5음) 차례로 + 낮은 북
func _syn_ritual(buf: PackedFloat32Array, _rng: RandomNumberGenerator) -> void:
	var notes := [262.0, 294.0, 349.0, 392.0, 440.0, 392.0]
	for k in range(notes.size()):
		var s0 := int(float(k) * 0.5 * MIX_RATE)
		var f: float = notes[k]
		for j in range(mini(buf.size() - s0, int(1.2 * MIX_RATE))):
			var t := float(j) / MIX_RATE
			buf[s0 + j] += (sin(TAU * f * t) * 0.3 + sin(TAU * f * 2.76 * t) * 0.08) * exp(-t / 0.45)
	_hit(buf, 0.0, 90.0, 60.0, 0.2, 0.4)
