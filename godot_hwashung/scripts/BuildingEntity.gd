extends RefCounted
class_name BuildingEntity

## [건물 인스턴스 래퍼 및 전각/특성 캡슐화 객체]
## 건물 타일 좌표, 건물 식별자, 전각 및 가용 정무 액션을 캡슐화
## 건물 상태(NORMAL <-> RUINED) 전이 및 비파괴적 원형 보존 관리

enum BuildingState {
	NORMAL = 0,
	RUINED = 1
}

const STATE_NORMAL: String = "NORMAL"
const STATE_RUINED: String = "RUINED"

var pos: Vector2i = Vector2i(-1, -1)
var building_id: String = ""
var building_name: String = ""
var is_completed: bool = false
var sub_buildings: Array[String] = []

var state: BuildingState = BuildingState.NORMAL
var building_state: String = STATE_NORMAL
var original_building_type: String = ""
var ruined_turns_remaining: int = 0

func _init(p_pos: Vector2i = Vector2i(-1, -1), p_building_id: String = "") -> void:
	pos = p_pos
	building_id = p_building_id
	original_building_type = p_building_id
	if building_id == "haenggung" or building_id == "haenggung_site":
		sub_buildings = ["oegyujanggak", "nangnamheon", "jeongniso"]

func ruin(rebuild_turns: int = 3) -> void:
	state = BuildingState.RUINED
	building_state = STATE_RUINED
	ruined_turns_remaining = rebuild_turns
	if original_building_type == "" and building_id != "":
		original_building_type = building_id

func restore() -> void:
	state = BuildingState.NORMAL
	building_state = STATE_NORMAL
	ruined_turns_remaining = 0
	if original_building_type != "":
		building_id = original_building_type

func is_ruined() -> bool:
	return state == BuildingState.RUINED or building_state == STATE_RUINED

func get_available_actions() -> Array[String]:
	if is_ruined():
		return []
	var acts: Array[String] = []
	var list: Array[Dictionary] = BuildingInteractionManager.get_interactions_for_building(building_id)
	for item: Dictionary in list:
		acts.append(String(item.get("action", "")))
	return acts

