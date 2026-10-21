extends Node
class_name SeasonManager

## [사계절 순환 및 계절 전환 시그널 총괄 매니저]
## 사계절 BGM 자동 전환 및 시각 필터 동기화의 단일 진실 공급원(SSOT)

@warning_ignore("unused_signal")
signal season_changed(new_season: String)

static var instance: SeasonManager = null

var current_season: String = "봄"

func _init() -> void:
	SeasonManager.instance = self

func _ready() -> void:
	SeasonManager.instance = self

static func get_instance() -> SeasonManager:
	return SeasonManager.instance

static func emit_season_changed(new_season: String) -> void:
	if SeasonManager.instance != null:
		SeasonManager.instance.current_season = new_season
		SeasonManager.instance.emit_signal("season_changed", new_season)
	if AudioManager.instance != null:
		AudioManager.instance.on_season_changed(new_season)

func set_season(new_season: String) -> void:
	if current_season != new_season:
		current_season = new_season
		emit_signal("season_changed", new_season)
		if AudioManager.instance != null:
			AudioManager.instance.on_season_changed(new_season)
