extends Node
class_name AudioManager

## [도시 오디오 및 배경음악 총괄 오디오 시스템 관리자]
## 1. 사계절 BGM 자동 전환 (봄/여름/가을/겨울 1.5초 부드러운 크로스페이드)
## 2. 위기 BGM 엄격 통제 (오직 실제 공성전/침공 침입 전투 시에만 발동 및 종전 즉시 계절곡 복귀)

static var instance: AudioManager = null
static var is_active_invasion: bool = false

var music_mgr: MusicManager = null
var current_season: String = "봄"

func _init() -> void:
	AudioManager.instance = self

func _ready() -> void:
	AudioManager.instance = self

static func get_instance() -> AudioManager:
	return AudioManager.instance

## 사계절 BGM 자동 전환 슬롯 (명세 규격)
func on_season_changed(new_season: String) -> void:
	current_season = new_season
	if AudioManager.is_active_invasion:
		# 실제 전투 침공 중에는 위기 BGM을 유지하되 계절 정보만 기록
		return

	var track_id: String = _map_season_to_track_id(new_season)
	if music_mgr != null:
		music_mgr.switch_to_track(track_id, 1.5)
	elif MusicManager.instance != null:
		MusicManager.instance.switch_to_track(track_id, 1.5)

## 계절 이름 -> 트랙 ID 매핑 (bgm_spring / season_spring 호환)
func _map_season_to_track_id(s_name: String) -> String:
	match s_name:
		"여름", "summer": return "season_summer"
		"가을", "autumn": return "season_autumn"
		"겨울", "winter": return "season_winter"
		_: return "season_spring"

## 실제 적군 침공 위기 BGM 개시
func play_crisis_bgm(crisis_type: String = "invasion") -> void:
	AudioManager.is_active_invasion = true
	var track_id: String = "event_invasion"
	if crisis_type == "rebel":
		track_id = "event_rebel"
	elif crisis_type == "bandit":
		track_id = "event_bandit"

	if music_mgr != null:
		music_mgr.set_flag("bandit_battle", true)
		music_mgr.switch_to_track(track_id, 1.5)
	elif MusicManager.instance != null:
		MusicManager.instance.set_flag("bandit_battle", true)
		MusicManager.instance.switch_to_track(track_id, 1.5)

## 전투 종료(승리/진압) 즉시 위기 BGM 중단 및 계절 BGM 즉시 복귀
func stop_crisis_bgm() -> void:
	AudioManager.is_active_invasion = false
	if music_mgr != null:
		music_mgr.set_flag("bandit_battle", false)
		var track_id: String = _map_season_to_track_id(current_season)
		music_mgr.switch_to_track(track_id, 1.5)
	elif MusicManager.instance != null:
		MusicManager.instance.set_flag("bandit_battle", false)
		var track_id: String = _map_season_to_track_id(current_season)
		MusicManager.instance.switch_to_track(track_id, 1.5)
