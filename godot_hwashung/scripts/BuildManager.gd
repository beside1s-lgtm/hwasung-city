extends RefCounted
class_name BuildManager

## [건설 모드 상태 감시 및 조작 인터페이스 관리자]
## CityLayer의 도구 선택 및 드래그 상태를 추적하여 팝업이 난입하지 않도록 방어합니다.

static var city_layer: Node = null

## 현재 플레이어가 건설 모드(배치 준비 또는 드래그 중)인지 여부
static var is_building_mode: bool:
	get:
		if city_layer != null:
			var is_tool_active: bool = (city_layer.current_tool != "inspect")
			var is_drag: bool = city_layer.is_dragging() if city_layer.has_method("is_dragging") else false
			return is_tool_active or is_drag
		return false

## 외부에서 건설 모드 강제 해제 요청 시 호출
static func cancel_building() -> void:
	if city_layer != null and city_layer.has_method("cancel_build_or_select"):
		city_layer.cancel_build_or_select()
