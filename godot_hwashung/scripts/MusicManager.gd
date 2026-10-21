extends Node
class_name MusicManager

## [배경음악 관리자]
## 곡 이름(track id) 하나가 곧 파일 이름이다. assets/music/<곡이름>.ogg(또는 .mp3/.wav)가 있으면 그 파일을 반복 재생하고,
## 없으면 같은 이름의 임시 국악풍 곡을 코드로 합성해 대신 튼다(그래서 파일이 하나도 없어도 곡이 바뀌는 흐름을 바로 확인할 수 있다).
## 어떤 곡을 틀지는 0.5초마다 게임 상태를 보고 고른다. 우선순위가 높은 상황은 곧바로, 낮아지는 쪽은 MIN_HOLD초 뒤에 바뀐다.
##   엔딩(100) > 인트로·타이틀(90) > 반란·외침(80) > 도적(70) > 화재(60) > 수해(55) > 을묘원행(50) > 역병(40) > 흉년(30) > 계절(0)
## 곡 목록과 만드는 법은 assets/music/MUSIC_GUIDE.md.

const DIR := "res://assets/music/"
const EXTS := ["ogg", "mp3", "wav"]
const RATE := 22050
const FADE := 1.5          # 곡이 바뀔 때 교차 페이드(1.5초 규격)
const MIN_HOLD := 18.0     # 한 곡을 최소한 이만큼은 듣게 한다(낮은 우선순위로 내려갈 때만)
const SETTINGS_PATH := "user://music_settings.cfg"

static var instance: MusicManager = null

const SCALES := {
	"pyeong": [0, 2, 5, 7, 9],   # 평조(맑고 담담)
	"gye": [0, 3, 5, 7, 10],     # 계면조(떨며 꺾는 슬픈 가락)
	"wu": [0, 2, 4, 7, 9],       # 우조에 가까운 밝은 5음
	"tense": [0, 1, 5, 7, 8],    # 긴박한 음계
}

## 곡 명세(임시 합성용). bpm·마디 수(4의 배수)·으뜸음(MIDI)·음계·주선율 악기·선율 밀도(0~1)·타악(0~2)·반주(0~3)·지속음
const SPECS := {
	"main_theme": {"label": "주제곡 — 화성의 아침", "bpm": 66, "bars": 8, "root": 62, "scale": "pyeong", "lead": "flute", "density": 0.55, "perc": 1, "arp": 2, "drone": true, "seed": 11},
	"season_spring": {"label": "봄 — 꽃이 피는 성", "bpm": 84, "bars": 8, "root": 67, "scale": "wu", "lead": "pluck", "density": 0.6, "perc": 0, "arp": 3, "drone": false, "seed": 21},
	"season_summer": {"label": "여름 — 푸른 둔전", "bpm": 76, "bars": 8, "root": 64, "scale": "pyeong", "lead": "flute", "density": 0.5, "perc": 1, "arp": 2, "drone": true, "seed": 22},
	"season_autumn": {"label": "가을 — 황금 들녘", "bpm": 70, "bars": 8, "root": 62, "scale": "gye", "lead": "bow", "density": 0.5, "perc": 1, "arp": 2, "drone": true, "seed": 23},
	"season_winter": {"label": "겨울 — 눈 덮인 성곽", "bpm": 54, "bars": 8, "root": 57, "scale": "pyeong", "lead": "bow", "density": 0.3, "perc": 0, "arp": 1, "drone": true, "seed": 24},
	"bgm_spring": {"label": "봄 — 꽃이 피는 성", "bpm": 84, "bars": 8, "root": 67, "scale": "wu", "lead": "pluck", "density": 0.6, "perc": 0, "arp": 3, "drone": false, "seed": 21},
	"bgm_summer": {"label": "여름 — 푸른 둔전", "bpm": 76, "bars": 8, "root": 64, "scale": "pyeong", "lead": "flute", "density": 0.5, "perc": 1, "arp": 2, "drone": true, "seed": 22},
	"bgm_autumn": {"label": "가을 — 황금 들녘", "bpm": 70, "bars": 8, "root": 62, "scale": "gye", "lead": "bow", "density": 0.5, "perc": 1, "arp": 2, "drone": true, "seed": 23},
	"bgm_winter": {"label": "겨울 — 눈 덮인 성곽", "bpm": 54, "bars": 8, "root": 57, "scale": "pyeong", "lead": "bow", "density": 0.3, "perc": 0, "arp": 1, "drone": true, "seed": 24},
	"event_famine": {"label": "흉년 — 빈 곳간", "bpm": 50, "bars": 8, "root": 55, "scale": "gye", "lead": "bow", "density": 0.28, "perc": 0, "arp": 0, "drone": true, "seed": 31},
	"event_flood": {"label": "홍수 — 불어난 물", "bpm": 108, "bars": 8, "root": 59, "scale": "tense", "lead": "pluck", "density": 0.7, "perc": 2, "arp": 3, "drone": true, "seed": 32},
	"event_fire": {"label": "화재 — 번지는 불길", "bpm": 120, "bars": 8, "root": 62, "scale": "tense", "lead": "pluck", "density": 0.8, "perc": 2, "arp": 3, "drone": false, "seed": 33},
	"event_bandit": {"label": "도적 — 어둠 속의 그림자", "bpm": 100, "bars": 8, "root": 57, "scale": "gye", "lead": "bow", "density": 0.55, "perc": 2, "arp": 2, "drone": true, "seed": 34},
	"event_rebel": {"label": "반란 — 성문 앞의 함성", "bpm": 92, "bars": 8, "root": 55, "scale": "tense", "lead": "bow", "density": 0.5, "perc": 2, "arp": 2, "drone": true, "seed": 35},
	"event_invasion": {"label": "외침 — 몰려오는 군세", "bpm": 96, "bars": 8, "root": 52, "scale": "tense", "lead": "flute", "density": 0.45, "perc": 2, "arp": 1, "drone": true, "seed": 36},
	"event_eulmyo": {"label": "을묘원행 — 봉수당 진찬연", "bpm": 80, "bars": 12, "root": 64, "scale": "wu", "lead": "flute", "density": 0.65, "perc": 1, "arp": 3, "drone": true, "seed": 37},
	"event_plague": {"label": "역병 — 닫힌 문", "bpm": 46, "bars": 8, "root": 54, "scale": "tense", "lead": "bow", "density": 0.25, "perc": 0, "arp": 0, "drone": true, "seed": 38},
	# 엔딩 13곡: 엔딩 ID(EndingManager.ENDING_DATA의 id)를 소문자로 붙인다.
	"ending_western_collapse": {"label": "결말 — 서쪽 성벽의 붕괴", "bpm": 52, "bars": 8, "root": 55, "scale": "gye", "lead": "bow", "density": 0.3, "perc": 1, "arp": 0, "drone": true, "seed": 101},
	"ending_unfilial_curse": {"label": "결말 — 불효의 저주", "bpm": 48, "bars": 8, "root": 53, "scale": "gye", "lead": "bow", "density": 0.25, "perc": 0, "arp": 0, "drone": true, "seed": 102},
	"ending_bankrupt_ruin": {"label": "결말 — 텅 빈 국고", "bpm": 56, "bars": 8, "root": 57, "scale": "gye", "lead": "flute", "density": 0.3, "perc": 0, "arp": 1, "drone": true, "seed": 103},
	"ending_coup_detat": {"label": "결말 — 한밤의 정변", "bpm": 88, "bars": 8, "root": 54, "scale": "tense", "lead": "bow", "density": 0.45, "perc": 2, "arp": 1, "drone": true, "seed": 104},
	"ending_peasant_revolt": {"label": "결말 — 들불처럼 번진 민란", "bpm": 94, "bars": 8, "root": 55, "scale": "tense", "lead": "pluck", "density": 0.5, "perc": 2, "arp": 2, "drone": true, "seed": 105},
	"ending_fallen_city": {"label": "결말 — 함락된 신도시", "bpm": 50, "bars": 8, "root": 52, "scale": "tense", "lead": "bow", "density": 0.28, "perc": 1, "arp": 0, "drone": true, "seed": 106},
	"ending_plundered_wealth": {"label": "결말 — 약탈당한 곳간", "bpm": 58, "bars": 8, "root": 56, "scale": "gye", "lead": "pluck", "density": 0.35, "perc": 1, "arp": 1, "drone": true, "seed": 107},
	"ending_bloody_faction": {"label": "결말 — 피로 물든 붕당", "bpm": 72, "bars": 8, "root": 53, "scale": "tense", "lead": "bow", "density": 0.4, "perc": 2, "arp": 1, "drone": true, "seed": 108},
	"ending_sedo_darkness": {"label": "결말 — 세도의 어둠", "bpm": 52, "bars": 8, "root": 51, "scale": "tense", "lead": "bow", "density": 0.28, "perc": 0, "arp": 0, "drone": true, "seed": 109},
	"ending_ignorance_swamp": {"label": "결말 — 무지의 늪", "bpm": 54, "bars": 8, "root": 58, "scale": "gye", "lead": "flute", "density": 0.3, "perc": 0, "arp": 1, "drone": true, "seed": 110},
	"ending_defense_fortress": {"label": "결말 — 수호의 성", "bpm": 68, "bars": 8, "root": 60, "scale": "pyeong", "lead": "flute", "density": 0.5, "perc": 1, "arp": 2, "drone": true, "seed": 111},
	"ending_true_renaissance": {"label": "결말 — 대조선의 문예 부흥", "bpm": 84, "bars": 12, "root": 62, "scale": "wu", "lead": "flute", "density": 0.7, "perc": 1, "arp": 3, "drone": true, "seed": 112},
	"ending_bandit_fall": {"label": "결말 — 도적에게 넘어간 화성", "bpm": 60, "bars": 8, "root": 54, "scale": "tense", "lead": "bow", "density": 0.3, "perc": 1, "arp": 0, "drone": true, "seed": 113},
}

const PRIORITY := {"ending": 100, "title": 90, "rebel": 80, "bandit": 70, "fire": 60, "flood": 55, "eulmyo": 50, "plague": 40, "famine": 30, "season": 0}

# --- Main이 연결해 주는 게임 상태 ---
var sim: SimulationCore
var siege: SiegeSystem
var time_manager: TimeManager
var court: CourtSystem
var game_started: Callable # () -> bool

var enabled := true
var _flags := {}            # intro·bandit_battle 등 이벤트가 켜고 끄는 깃발
var _ending_id := ""        # 엔딩 곡을 틀 엔딩 ID(소문자)
var _ending_pending := false # 엔딩 영상이 도는 동안 배경음악을 끈다
var _want := ""             # 지금 틀려고 하는 곡(빈 문자열 = 무음)
var _want_prio := -1
var _hold := 0.0
var _poll := 0.0
var _playing := ""          # 실제로 나오고 있는 곡
var _players: Array[AudioStreamPlayer] = []
var _front := 0
var _fade_tw: Tween
var _volume := 0.7

var _file_cache := {}       # 곡 → 파일 스트림(없으면 null)
var _synth_cache := {}      # 곡 → 합성 스트림
var _gen_queue: Array[String] = []
var _gen_thread: Thread
var _gen_id := ""
var _gen_out: AudioStreamWAV

func _ready() -> void:
	MusicManager.instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		var bi := AudioServer.bus_count - 1
		AudioServer.set_bus_name(bi, "Music")
		AudioServer.set_bus_send(bi, "Master")
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	_load_settings()
	_apply_volume()

func _exit_tree() -> void:
	if _gen_thread != null and _gen_thread.is_started():
		_gen_thread.wait_to_finish()

# ============================================================ 바깥에서 부르는 곳
func set_flag(key: String, on: bool) -> void:
	_flags[key] = on

## 엔딩이 발동되면 영상이 끝날 때까지 배경음악을 끈다
func begin_ending() -> void:
	_ending_pending = true

## 엔딩 팝업이 뜰 때 엔딩 곡을 튼다
func play_ending(ending_data: Dictionary) -> void:
	_ending_pending = false
	_ending_id = String(ending_data.get("id", "")).to_lower()
	if not SPECS.has("ending_" + _ending_id):
		_ending_id = "defense_fortress" if int(ending_data.get("num", 0)) == 0 else _ending_id
	_hold = MIN_HOLD

## 새 게임·불러오기·타이틀 복귀 때 엔딩 상태를 비운다
func clear_ending() -> void:
	_ending_id = ""
	_ending_pending = false

func get_volume() -> float:
	return _volume

func set_volume(v: float, save: bool = true) -> void:
	_volume = clampf(v, 0.0, 1.0)
	_apply_volume()
	if save:
		var cf := ConfigFile.new()
		cf.set_value("music", "volume", _volume)
		cf.save(SETTINGS_PATH)

## 설정 화면에서 쓰는 곡 이름(현재 곡)
func current_label() -> String:
	if _playing == "":
		return ""
	return String((SPECS.get(_playing, {}) as Dictionary).get("label", _playing))

## 곡 ID → 한글 이름 (MUSIC_GUIDE·디버그용)
static func track_label(id: String) -> String:
	return String((SPECS.get(id, {}) as Dictionary).get("label", id))

func _load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		_volume = clampf(float(cf.get_value("music", "volume", 0.7)), 0.0, 1.0)

func _apply_volume() -> void:
	var bi := AudioServer.get_bus_index("Music")
	if bi >= 0:
		AudioServer.set_bus_volume_db(bi, linear_to_db(maxf(_volume, 0.0001)) - 4.0)
		AudioServer.set_bus_mute(bi, _volume <= 0.001)

# ============================================================ 어떤 곡을 틀지
## [곡 ID, 우선순위]. 곡 ID가 빈 문자열이면 무음.
func _context_track() -> Array:
	if _ending_pending:
		return ["", PRIORITY["ending"]]
	if _ending_id != "":
		return ["ending_" + _ending_id, PRIORITY["ending"]]
	if bool(_flags.get("intro", false)):
		return ["", PRIORITY["title"]] # 인트로 영상 자체의 소리를 가리지 않는다
	if not game_started.is_valid() or not bool(game_started.call()):
		return ["main_theme", PRIORITY["title"]]

	# [위기 BGM 발동 조건 엄격 제한]
	# 단순히 민심이 낮거나 도적 소굴이 성 밖에 있다는 이유만으로 위기 음악을 틀지 않음!
	# 오직 적군(도적떼/반란군/열강)이 실제로 성문을 공격하거나 성내로 진입하여 전투 중일 때(is_active_invasion == true)만 재생!
	var is_invasion_combat: bool = bool(_flags.get("bandit_battle", false)) or AudioManager.is_active_invasion
	if not is_invasion_combat and SiegeDefenseManager.instance != null:
		is_invasion_combat = SiegeDefenseManager.instance.is_battle_active
	if not is_invasion_combat and siege != null:
		is_invasion_combat = String(siege.state) in ["march", "siege"]

	if is_invasion_combat:
		if siege != null and String(siege.state) in ["march", "siege"]:
			return ["event_invasion" if String(siege.kind) == "horde" else "event_rebel", PRIORITY["rebel"]]
		return ["event_bandit", PRIORITY["bandit"]]

	if sim != null:
		if sim.fire_active:
			return ["event_fire", PRIORITY["fire"]]
		if sim.flood_crisis_active:
			return ["event_flood", PRIORITY["flood"]]
		if sim.is_eulmyo_active or (court != null and bool(court.eulmyo.get("active", false))):
			return ["event_eulmyo", PRIORITY["eulmyo"]]
		if sim.plague_active:
			return ["event_plague", PRIORITY["plague"]]
		if sim.drought_active or sim.rice <= 0:
			return ["event_famine", PRIORITY["famine"]]

	var season := time_manager.get_current_season() if time_manager != null else "봄"
	match season:
		"여름": return ["season_summer", 0]
		"가을": return ["season_autumn", 0]
		"겨울": return ["season_winter", 0]
	return ["season_spring", 0]

func _process(delta: float) -> void:
	_pump_generation()
	_hold += delta
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.5
		var pick := _context_track()
		var id: String = pick[0]
		var prio: int = pick[1]
		if id != _want:
			var urgent := prio > _want_prio or prio >= 90 or _want_prio >= 90
			if urgent or _hold >= MIN_HOLD:
				_want = id
				_want_prio = prio
				_hold = 0.0
	if _want != _playing:
		_try_play(_want)

# ============================================================ 재생
func _try_play(id: String) -> void:
	if id == "" or not enabled:
		if _playing != "":
			_playing = ""
			_crossfade(null)
		return
	var st := _get_stream(id)
	if st == null:
		return # 합성 중: 만들어질 때까지 지금 곡을 이어서 튼다
	_playing = id
	_crossfade(st)

func _crossfade(st: AudioStream) -> void:
	_crossfade_with_duration(st, FADE)

func _crossfade_with_duration(st: AudioStream, dur: float) -> void:
	if _fade_tw != null and _fade_tw.is_valid():
		_fade_tw.kill()
	var old := _players[_front]
	_front = 1 - _front
	var nw := _players[_front]
	_fade_tw = create_tween().set_parallel(true)
	if old.playing:
		_fade_tw.tween_property(old, "volume_db", -60.0, dur)
		_fade_tw.chain().tween_callback(old.stop)
	if st != null:
		nw.stream = st
		nw.volume_db = -60.0
		nw.play()
		_fade_tw.tween_property(nw, "volume_db", 0.0, dur)

## 사계절 BGM 자동 전환 슬롯 (명세 규격 1.5초 크로스페이드)
func on_season_changed(new_season: String) -> void:
	var season_track: String = "season_spring"
	match new_season:
		"여름", "summer": season_track = "season_summer"
		"가을", "autumn": season_track = "season_autumn"
		"겨울", "winter": season_track = "season_winter"
		_: season_track = "season_spring"

	var is_invasion: bool = bool(_flags.get("bandit_battle", false)) or AudioManager.is_active_invasion
	if not is_invasion and SiegeDefenseManager.instance != null:
		is_invasion = SiegeDefenseManager.instance.is_battle_active
	if not is_invasion and siege != null:
		is_invasion = String(siege.state) in ["march", "siege"]

	if not is_invasion:
		switch_to_track(season_track, 1.5)

## 특정 트랙으로 즉시 크로스페이드 전환
func switch_to_track(id: String, custom_fade: float = 1.5) -> void:
	_want = id
	_want_prio = 0
	_hold = 0.0
	if _playing != id:
		_playing = id
		var st := _get_stream(id)
		if st != null:
			_crossfade_with_duration(st, custom_fade)

## 평화로운 현재 계절 BGM으로 즉시 복귀
func switch_to_season_bgm() -> void:
	var cur_season: String = time_manager.get_current_season() if time_manager != null else "봄"
	on_season_changed(cur_season)

func _get_stream(id: String) -> AudioStream:
	var f := _file_stream(id)
	if f != null:
		return f
	if _synth_cache.has(id):
		return _synth_cache[id]
	if SPECS.has(id) and id != _gen_id and not _gen_queue.has(id):
		_gen_queue.append(id)
	return null

func _file_stream(id: String) -> AudioStream:
	if _file_cache.has(id):
		return _file_cache[id]
	var found: AudioStream = null
	var target_ids: Array[String] = [id]
	if id.begins_with("bgm_"):
		target_ids.append(id.replace("bgm_", "season_"))
	elif id.begins_with("season_"):
		target_ids.append(id.replace("season_", "bgm_"))

	for tid: String in target_ids:
		for e: String in EXTS:
			var p := DIR + tid + "." + e
			if ResourceLoader.exists(p):
				var s: Resource = load(p)
				if s is AudioStreamOggVorbis:
					(s as AudioStreamOggVorbis).loop = true
				elif s is AudioStreamMP3:
					(s as AudioStreamMP3).loop = true
				found = s as AudioStream
				break
		if found != null:
			break
	_file_cache[id] = found
	return found

# ============================================================ 임시 곡 합성(스레드)
func _pump_generation() -> void:
	if _gen_thread != null:
		if _gen_thread.is_alive():
			return
		_gen_thread.wait_to_finish()
		_gen_thread = null
		if _gen_out != null:
			_synth_cache[_gen_id] = _gen_out
		_gen_out = null
		_gen_id = ""
	if _gen_queue.is_empty():
		return
	# 지금 틀려는 곡을 먼저 만든다
	var i := _gen_queue.find(_want)
	_gen_id = _gen_queue.pop_at(i if i >= 0 else 0)
	_gen_thread = Thread.new()
	_gen_thread.start(_generate.bind(_gen_id))

func _generate(id: String) -> void:
	_gen_out = MusicManager.synth_track(id)

static func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)

## 5음 음계의 도수(0=으뜸음, 5=한 옥타브 위)를 MIDI 음 높이로
static func _pitch(root: int, scale: Array, deg: int) -> float:
	return float(root + int(scale[posmod(deg, 5)]) + 12 * floori(deg / 5.0))

static func synth_track(id: String) -> AudioStreamWAV:
	var spec: Dictionary = SPECS.get(id, {})
	if spec.is_empty():
		return null
	var bpm: float = float(spec["bpm"])
	var beat := 60.0 / bpm
	var bars: int = int(spec["bars"])
	var n := int(float(bars * 4) * beat * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec["seed"])
	var scale: Array = SCALES[spec["scale"]]
	var root: int = int(spec["root"])
	var bar_s := beat * 4.0
	var eighth := beat * 0.5

	# 1) 지속음(으뜸음·5음) — 2마디마다
	if bool(spec["drone"]):
		var b := 0
		while b < bars:
			_add_tone(buf, float(b) * bar_s, _hz(float(root) - 12.0), bar_s * 2.0, 0.20, 0.6, 0.0)
			_add_tone(buf, float(b) * bar_s, _hz(float(root) - 5.0), bar_s * 2.0, 0.10, 0.6, 0.0)
			b += 2

	# 2) 반주(가야금 뜯기): 3=8분, 2=한 박, 1=두 박마다
	var arp: int = int(spec["arp"])
	if arp > 0:
		var step := eighth if arp == 3 else (beat if arp == 2 else beat * 2.0)
		var steps := int(float(bars) * bar_s / step)
		var pat := [0, 2, 4, 2, 0, 3, 4, 3]
		for k in steps:
			var deg: int = int(pat[(k + int(float(k) / 8.0) % 2) % pat.size()]) - 5
			_add_pluck(buf, float(k) * step, _hz(_pitch(root, scale, deg)), 1.2, 0.17 if arp >= 2 else 0.2, rng)

	# 3) 주선율: 4마디 가락 A(앞 두 마디 같고 끝만 다른 변주 B)를 번갈아
	var density: float = float(spec["density"])
	var lead: String = String(spec["lead"])
	var phrase_a := _make_phrase(rng, density)
	var phrase_b := _vary_phrase(rng, phrase_a, density)
	var p := 0
	while p < int(float(bars) / 4.0):
		var ph: Array = phrase_a if p % 2 == 0 else phrase_b
		var t0 := float(p * 4) * bar_s
		for note_v in ph:
			var nt: Dictionary = note_v
			var start := t0 + float(nt["e"]) * eighth
			var dur := float(nt["len"]) * eighth
			var hz := _hz(_pitch(root, scale, int(nt["deg"])) + 12.0)
			match lead:
				"pluck":
					_add_pluck(buf, start, hz, minf(dur * 1.6, 1.6), 0.32, rng)
				"bow":
					_add_tone(buf, start, hz, dur * 1.1, 0.26, 0.18, 5.6)
				_:
					_add_tone(buf, start, hz, dur * 1.05, 0.26, 0.09, 5.0, rng)
		p += 1

	# 4) 타악(장구·북): 0 없음 / 1 은은하게 / 2 몰아치게
	var perc: int = int(spec["perc"])
	if perc > 0:
		var k := 0
		while k < bars * 8:
			var pos := k % 8
			var at := float(k) * eighth
			if perc == 1:
				if pos == 0:
					_add_drum(buf, at, 0, 0.30, rng)
				elif pos == 4 or pos == 6:
					_add_drum(buf, at, 1, 0.12, rng)
			else:
				if pos == 0 or pos == 3 or pos == 4:
					_add_drum(buf, at, 0, 0.42, rng)
				elif pos % 2 == 0 or pos == 7:
					_add_drum(buf, at, 1, 0.16, rng)
			k += 1

	# 5) 울림(되울림 두 번) + 음량 정규화
	var d1 := int(0.27 * RATE)
	var d2 := int(0.46 * RATE)
	var mixed := PackedFloat32Array()
	mixed.resize(n)
	var peak := 0.0001
	for i in n:
		var v := buf[i] + 0.26 * buf[posmod(i - d1, n)] + 0.14 * buf[posmod(i - d2, n)]
		mixed[i] = v
		peak = maxf(peak, absf(v))
	var gain := 0.82 / peak
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, clampi(int(mixed[i] * gain * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav

## 4마디(8분음표 32칸) 선율: [{e: 시작칸, len: 길이, deg: 도수}]
static func _make_phrase(rng: RandomNumberGenerator, density: float) -> Array:
	var out: Array = []
	var deg := 2
	var e := 0
	while e < 32:
		var strong := e % 8 == 0
		if strong or rng.randf() < density:
			var ln: int = [1, 2, 2, 3, 4][rng.randi() % 5]
			ln = mini(ln, 32 - e)
			if e + ln > 28 and e < 28:
				ln = 28 - e # 마지막 마디 앞에서 한 번 끊고 마무리음을 놓는다
			deg += int([-2, -1, -1, 0, 1, 1, 2][rng.randi() % 7])
			deg = clampi(deg, -1, 7)
			if deg > 5 and rng.randf() < 0.4:
				deg -= 2 # 너무 높이 머물지 않게
			out.append({"e": e, "len": ln, "deg": deg})
			e += ln
		else:
			e += 1
	# 끝: 마지막 마디 첫 박에 으뜸음(0) 또는 5도(3)로 길게 닫는다
	while not out.is_empty() and int((out[out.size() - 1] as Dictionary)["e"]) >= 28:
		out.pop_back()
	out.append({"e": 28, "len": 4, "deg": 0 if rng.randf() < 0.6 else 3})
	return out

## 앞 두 마디(16칸)는 그대로 두고 뒤쪽만 다시 짠 변주
static func _vary_phrase(rng: RandomNumberGenerator, a: Array, density: float) -> Array:
	var out: Array = []
	for nv in a:
		if int((nv as Dictionary)["e"]) + int((nv as Dictionary)["len"]) <= 16:
			out.append(nv)
	var tail := _make_phrase(rng, density)
	for nv in tail:
		if int((nv as Dictionary)["e"]) >= 16:
			out.append(nv)
	return out

## 가야금 뜯는 소리: 바로 사그라드는 배음 합
static func _add_pluck(buf: PackedFloat32Array, start_s: float, hz: float, dur_s: float, amp: float, _rng: RandomNumberGenerator) -> void:
	var n := buf.size()
	var s0 := int(start_s * RATE)
	var cnt := int(dur_s * RATE)
	var w := TAU * hz / RATE
	for i in cnt:
		var t := float(i) / RATE
		var env := exp(-t * 3.4)
		var a := float(i) * w
		var v := sin(a) + 0.5 * sin(2.0 * a) * exp(-t * 4.0) + 0.22 * sin(3.0 * a) * exp(-t * 6.0)
		var atk := minf(1.0, float(i) / 90.0) # 딸깍 소리 방지
		buf[(s0 + i) % n] += v * env * atk * amp

## 대금(맑은 숨결)·해금(떠는 활소리): 느린 어택 + 비브라토
static func _add_tone(buf: PackedFloat32Array, start_s: float, hz: float, dur_s: float, amp: float, breath: float, vib_hz: float, rng: RandomNumberGenerator = null) -> void:
	var n := buf.size()
	var s0 := int(start_s * RATE)
	var cnt := int(dur_s * RATE)
	var attack := minf(0.12, dur_s * 0.35)
	var release := minf(0.35, dur_s * 0.45)
	var phase := 0.0
	for i in cnt:
		var t := float(i) / RATE
		var env := minf(1.0, t / attack) * minf(1.0, (dur_s - t) / release)
		var vib := 1.0 + (0.006 * sin(TAU * vib_hz * t) if vib_hz > 0.0 else 0.0)
		phase += TAU * hz * vib / RATE
		var v := sin(phase) + 0.30 * sin(2.0 * phase) + 0.12 * sin(3.0 * phase)
		if rng != null:
			v += (rng.randf() - 0.5) * breath * 2.0
		buf[(s0 + i) % n] += v * maxf(env, 0.0) * amp

## 장구/북: kind 0 = 낮은 북(궁), 1 = 높은 채편
static func _add_drum(buf: PackedFloat32Array, start_s: float, kind: int, amp: float, rng: RandomNumberGenerator) -> void:
	var n := buf.size()
	var s0 := int(start_s * RATE)
	var dur := 0.32 if kind == 0 else 0.1
	var cnt := int(dur * RATE)
	var phase := 0.0
	for i in cnt:
		var t := float(i) / RATE
		var f := (48.0 + 70.0 * exp(-t * 18.0)) if kind == 0 else (210.0 + 90.0 * exp(-t * 30.0))
		phase += TAU * f / RATE
		var env := exp(-t * (11.0 if kind == 0 else 38.0))
		var v := sin(phase) * env
		if kind == 1:
			v += (rng.randf() - 0.5) * 0.9 * exp(-t * 55.0)
		buf[(s0 + i) % n] += v * amp
