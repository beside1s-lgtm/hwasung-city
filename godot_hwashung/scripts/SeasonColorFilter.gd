class_name SeasonColorFilter
extends CanvasModulate

## [계절별 전역 색조 및 그림자 필터]
## 봄, 여름, 가을, 겨울 계절 전환 시 월드 레이어 전용 CanvasModulate 색조와
## PNG 베이킹용 드롭 섀도우 및 타일 색조를 일원화하여 관리합니다.
## UI 캔버스 레이어(CanvasLayer)에는 영향을 주지 않고 오직 월드 CanvasItem에만 적용됩니다.

# 1. 월드 전역 색조 (CanvasModulate)
const WORLD_TINTS: Dictionary = {
	"봄": Color("FFFDF8"),
	"여름": Color("F7FFF9"),
	"가을": Color("FFF6EB"),
	"겨울": Color("EBF3FF")
}

# 2. PNG 드롭 섀도우 톤 (Alpha 결합)
const SHADOW_COLORS: Dictionary = {
	"봄": Color("2A282D77"),
	"여름": Color("1C232199"),
	"가을": Color("33201488"),
	"겨울": Color("1A223388")
}

# 3. 본체 계절 색조 (Tile Tint)
const TILE_TINTS: Dictionary = {
	"봄": Color("FFFDF8"),
	"여름": Color("F7FFF9"),
	"가을": Color("FFF6EB"),
	"겨울": Color("EBF3FF")
}

# 4. 계절 접미사
const SEASON_SUFFIXES: Dictionary = {
	"봄": "_spring",
	"여름": "_summer",
	"가을": "_autumn",
	"겨울": "_winter"
}

var _tween: Tween = null
var current_season: String = "봄"

func _ready() -> void:
	color = get_current_world_tint(current_season)

static func get_current_season_suffix(season: String) -> String:
	return str(SEASON_SUFFIXES.get(season, "_spring"))

static func get_current_shadow_color(season: String) -> Color:
	return SHADOW_COLORS.get(season, Color("2A282D77"))

static func get_current_tile_tint(season: String) -> Color:
	return TILE_TINTS.get(season, Color("FFFDF8"))

static func get_current_world_tint(season: String) -> Color:
	return WORLD_TINTS.get(season, Color("FFFDF8"))

## 계절 전환 트윈 (기본 1.2초 보간)
func transition_to_season(new_season: String, duration: float = 1.2) -> void:
	current_season = new_season

	# 1820년 근대화 모드에서 여름으로 고정된 상태인지 안전 확인
	if _is_season_locked():
		color = get_current_world_tint("여름")
		return

	var target_col: Color = get_current_world_tint(new_season)

	if _tween != null and _tween.is_running():
		_tween.kill()

	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "color", target_col, duration)

func _is_season_locked() -> bool:
	# SeasonManager 또는 ModernizationManager의 여름 고정 여부 질의
	var root_node: Node = get_tree().current_scene if get_tree() != null else null
	if root_node != null and "time_manager" in root_node:
		var tm: Variant = root_node.get("time_manager")
		if tm != null and "is_season_locked" in tm and tm.call("is_season_locked"):
			return true
	return false
