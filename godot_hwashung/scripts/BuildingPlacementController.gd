extends RefCounted
class_name BuildingPlacementController

## [건설 배치 제어자 호환 인터페이스]
## BuildManager와 연계하여 건설 모드 상태 질의를 지원합니다.

static func is_busy() -> bool:
	return BuildManager.is_building_mode

static func cancel_placement() -> void:
	BuildManager.cancel_building()
