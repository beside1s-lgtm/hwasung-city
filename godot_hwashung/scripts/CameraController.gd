extends Camera2D
class_name CameraController

## 2.5D 아이소메트릭 전용 팬/줌 카메라 컨트롤러

@export var move_speed: float = 600.0
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.5
@export var zoom_step: float = 0.15

var is_panning: bool = false
var pan_start_pos: Vector2 = Vector2.ZERO
var _focus_tween: Tween = null

func _ready() -> void:
	CameraLODController.register_camera(self)
	_notify_lod()

func _notify_lod() -> void:
	if CameraLODController.instance != null:
		CameraLODController.instance.check_zoom_lod(zoom.x)

func _unhandled_input(event: InputEvent) -> void:
	if EventManager.has_active_modal():
		is_panning = false
		return

	# 1. 마우스 휠 스크롤 줌
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_apply_zoom(1.0 + zoom_step, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_apply_zoom(1.0 - zoom_step, event.position)
		# 2. 마우스 휠 클릭(가운데 버튼) 또는 우클릭 팬
		elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				stop_focus_tween() # 수동 조작 시 트윈 즉시 해제
				is_panning = true
				pan_start_pos = event.position
			else:
				is_panning = false

	# 3. 드래그 이동
	elif event is InputEventMouseMotion and is_panning:
		stop_focus_tween() # 마우스 드래그 시 트윈 즉시 해제
		var delta_pos = (event.position - pan_start_pos) / zoom.x
		position -= delta_pos
		pan_start_pos = event.position

func _process(delta: float) -> void:
	if EventManager.has_active_modal():
		return

	# 키보드 WASD / 화살표 키 이동
	# PORT-TRACE [성문 명명 입력 버그]: 성문 현판명 등 글자 입력창에 타자 중일 때는 지도가 따라 움직이지 않게 한다.
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	var dir = Vector2.ZERO
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		dir.x += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		dir.x -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		dir.y += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		dir.y -= 1

	if dir != Vector2.ZERO:
		stop_focus_tween() # 키보드 이동 시 트윈 즉시 해제
		position += dir.normalized() * (move_speed / zoom.x) * delta

func _apply_zoom(factor: float, _mouse_screen_pos: Vector2) -> void:
	var prev_zoom = zoom.x
	var target_zoom = clamp(prev_zoom * factor, min_zoom, max_zoom)
	if target_zoom == prev_zoom:
		return

	# 마우스 커서 위치 중심 줌 보정
	var mouse_world_before = get_global_mouse_position()
	zoom = Vector2(target_zoom, target_zoom)
	var mouse_world_after = get_global_mouse_position()
	position += (mouse_world_before - mouse_world_after)
	_notify_lod()

func zoom_in() -> void:
	var target_zoom = clamp(zoom.x * (1.0 + zoom_step), min_zoom, max_zoom)
	zoom = Vector2(target_zoom, target_zoom)
	_notify_lod()

func zoom_out() -> void:
	var target_zoom = clamp(zoom.x * (1.0 - zoom_step), min_zoom, max_zoom)
	zoom = Vector2(target_zoom, target_zoom)
	_notify_lod()

func reset_view() -> void:
	stop_focus_tween()
	# PORT-TRACE [경량화 감사]: 맵이 20x20 -> 64x64(P24)로 확장된 뒤에도 옛 20그리드 중심 좌표
	# (0,320)가 그대로 남아 있어 "화면 중앙" 버튼이 실제 지도 북서쪽 구석으로 튀는 버그였다.
	position = Vector2(0, 1024)
	zoom = Vector2(1.2, 1.2)
	_notify_lod()

## 특정 월드 좌표로 시야 이동 (smooth = true 시 CUBIC 보간 자동 패닝, 기본 duration = 0.8초)
func focus_on_coordinate(world_pos: Vector2, smooth: bool = true, duration: float = 0.8) -> void:
	stop_focus_tween()
	if not smooth:
		position = world_pos
		return
	_focus_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_focus_tween.tween_property(self, "position", world_pos, duration)

## 수동 조작 시 포커스 트윈 즉시 중단 (조작 락 방지)
func stop_focus_tween() -> void:
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()
	_focus_tween = null

## 월드 좌표가 현재 화면 뷰포트 안에 있는지 여부 판정
func is_world_pos_in_view(world_pos: Vector2, margin: float = 30.0) -> bool:
	var vp_size: Vector2 = get_viewport_rect().size
	var half_size: Vector2 = (vp_size * 0.5) / zoom.x
	var left: float = position.x - half_size.x + margin / zoom.x
	var right: float = position.x + half_size.x - margin / zoom.x
	var top: float = position.y - half_size.y + margin / zoom.x
	var bottom: float = position.y + half_size.y - margin / zoom.x
	return world_pos.x >= left and world_pos.x <= right and world_pos.y >= top and world_pos.y <= bottom
