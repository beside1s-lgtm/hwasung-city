extends Node
class_name InputManager

## [플레이어 입력 유휴(Idle) 감지 및 조작 안전 가드 매니저]
## 플레이어가 건물 배치 모드, 드래그 설치, 카메라 조작 중이거나
## 마우스/키보드 입력 직후(0.4초 미만)일 때 이벤트 팝업의 출력을 대기(Hold)시킵니다.

static var instance: InputManager = null

const IDLE_THRESHOLD: float = 0.4

var idle_time: float = 1.0 # 초기에는 유휴 상태로 시작
var is_mouse_down: bool = false
var city: CityLayer = null
var camera: CameraController = null

func _init() -> void:
	instance = self

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		idle_time = 0.0
	elif event is InputEventMouseButton:
		idle_time = 0.0
		is_mouse_down = event.pressed
	elif event is InputEventKey and event.pressed:
		idle_time = 0.0

func _process(delta: float) -> void:
	idle_time += delta

## 플레이어가 조작 중(건설 모드, 드래그, 버튼 누름, 카메라 이동, 입력 직후)인지 판정
func is_player_busy() -> bool:
	# 1. 건설 모드 또는 타일 드래그 중
	if BuildManager.is_building_mode:
		return true

	if city != null:
		if city.current_tool != "inspect":
			return true
		if city.has_method("is_dragging") and city.is_dragging():
			return true

	# 2. 카메라 조작 중
	if camera != null and camera.is_panning:
		return true

	# 3. 마우스 버튼 누름 상태
	if is_mouse_down:
		return true
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		return true

	# 4. 마지막 입력으로부터 유휴 시간이 임계치 미만
	if idle_time < IDLE_THRESHOLD:
		return true

	return false

## 다음 이벤트를 안전하게 화면에 띄울 수 있는 유휴 상태인지 판정
func can_show_next_event() -> bool:
	if is_player_busy():
		return false
	if EventManager.has_active_modal():
		return false
	if idle_time < IDLE_THRESHOLD:
		return false
	return true

## 유휴 시간 리셋
func reset_idle_time() -> void:
	idle_time = 0.0
