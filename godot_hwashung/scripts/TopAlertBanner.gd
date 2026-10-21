extends PanelContainer
class_name TopAlertBanner

## [상단 중앙 긴급/일반 알림 배너 - 10초 유지 & 사용자 종료 후 5초 직렬화 큐]
## 턴 전환 및 사건 발생 시 쏟아지는 메시지가 서로 덮어쓰거나 순간 과부하를 주지 않도록
## FIFO 대기열로 관리하고, 사건 발생 시 알림창 옆에 [위치 보기 🔍] 버튼을 제공하여 현장 확인을 지원합니다.

@warning_ignore("unused_signal")
signal location_view_requested(target_world_pos: Vector2)

var _alert_queue: Array[Dictionary] = []
var _is_showing: bool = false
var _display_timer: float = 0.0
var _current_msg: String = ""
var _current_pos: Vector2 = Vector2.ZERO
const DISPLAY_DURATION: float = 10.0 # 최소 10초 동안 유지
const SERIALIZE_DELAY: float = 5.0 # 사용자 종료 후 다음 알림 생성까지 5초 직렬화 지연
var _cooldown_timer: float = 0.0

var message_label: Label
var view_button: Button
var close_button: Button
var remaining_badge: Label

func _ready() -> void:
	visible = false
	_build_ui()

func _build_ui() -> void:
	custom_minimum_size = Vector2(0, 42)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.45, 0.11, 0.08, 0.98) # 단청 주홍 붉은색
	sb.border_color = Color(0.96, 0.65, 0.12, 1.0) # 황금빛 테두리
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.75)
	sb.shadow_size = 8
	sb.content_margin_left = 14
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	add_theme_stylebox_override("panel", sb)

	var hbox := HBoxContainer.new()
	hbox.name = "HBoxContainer"
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hbox)

	message_label = Label.new()
	message_label.name = "MessageLabel"
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88))
	message_label.add_theme_font_size_override("font_size", 13)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(message_label)

	view_button = Button.new()
	view_button.name = "ViewLocationButton"
	view_button.text = "위치 보기 🔍"
	view_button.custom_minimum_size = Vector2(85, 26)
	view_button.add_theme_font_size_override("font_size", 11)
	view_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var v_sb := StyleBoxFlat.new()
	v_sb.bg_color = Color(0.68, 0.18, 0.10, 0.95)
	v_sb.border_color = Color(1.0, 0.78, 0.28, 1.0)
	v_sb.set_border_width_all(1)
	v_sb.set_corner_radius_all(4)
	v_sb.content_margin_left = 6
	v_sb.content_margin_right = 6
	v_sb.content_margin_top = 2
	v_sb.content_margin_bottom = 2
	view_button.add_theme_stylebox_override("normal", v_sb)

	var v_hov := v_sb.duplicate() as StyleBoxFlat
	v_hov.bg_color = Color(0.85, 0.28, 0.15, 1.0)
	view_button.add_theme_stylebox_override("hover", v_hov)

	view_button.add_theme_color_override("font_color", Color(1.0, 0.98, 0.90))
	view_button.pressed.connect(_on_view_pressed)
	view_button.visible = false
	hbox.add_child(view_button)

	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "✕ 닫기"
	close_button.custom_minimum_size = Vector2(58, 26)
	close_button.add_theme_font_size_override("font_size", 11)
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.25, 0.06, 0.05, 0.9)
	btn_sb.border_color = Color(0.85, 0.55, 0.15, 0.8)
	btn_sb.set_border_width_all(1)
	btn_sb.set_corner_radius_all(4)
	btn_sb.content_margin_left = 6
	btn_sb.content_margin_right = 6
	btn_sb.content_margin_top = 2
	btn_sb.content_margin_bottom = 2
	close_button.add_theme_stylebox_override("normal", btn_sb)

	var btn_hov := btn_sb.duplicate() as StyleBoxFlat
	btn_hov.bg_color = Color(0.55, 0.15, 0.12, 1.0)
	close_button.add_theme_stylebox_override("hover", btn_hov)

	close_button.add_theme_color_override("font_color", Color(0.99, 0.94, 0.80))
	close_button.pressed.connect(_on_close_pressed)
	hbox.add_child(close_button)

func push_alert(msg: String, target_world_pos: Vector2 = Vector2.ZERO) -> void:
	if not GameSettings.is_disaster_popup_enabled():
		return
	if msg.strip_edges() == "":
		return

	# UI가 아직 미생성 상태이면 즉시 빌드 (SceneTree 테스트 환경 대응)
	if view_button == null:
		_build_ui()

	# [이분화 원칙] 정무 관련 조언 및 완료 보고는 김판관이 전담하므로 상단 팝업에서 완전 차단
	for gov_kw: String in ["초야 인재", "인재 출현", "인재 천거", "등용 가능", "호포책", "현륭원 친림", "서장대 훈련", "세자서연", "조세 조율", "완공", "완수", "대역사", "실학 연구", "세자 교육", "어명 달성"]:
		if gov_kw in msg and not ("습격" in msg or "침입" in msg or "출현하여 약탈" in msg):
			return

	# 현재 표시 중인 메시지나 대기열에 이미 존재하는 메시지는 중복 적재 배제
	if _is_showing and _current_msg == msg:
		return
	for q_item: Dictionary in _alert_queue:
		if str(q_item.get("msg", "")) == msg:
			return
	# 과도한 알림 난립을 방지하기 위해 대기열을 최대 3건으로 제한
	if _alert_queue.size() >= 3:
		return

	_alert_queue.append({
		"msg": msg,
		"pos": target_world_pos
	})
	if not _is_showing and _cooldown_timer <= 0.0:
		_show_next_alert()
	else:
		_update_display_text()

func _update_display_text() -> void:
	if not _is_showing or message_label == null:
		return
	var remaining: int = _alert_queue.size()
	if remaining > 0:
		message_label.text = "%s  (외 %d건 대기 중)" % [_current_msg, remaining]
	else:
		message_label.text = _current_msg

func _show_next_alert() -> void:
	if _alert_queue.is_empty():
		_is_showing = false
		_current_msg = ""
		_current_pos = Vector2.ZERO
		if view_button != null:
			view_button.visible = false
		visible = false
		return

	_is_showing = true
	var item: Dictionary = _alert_queue.pop_front()
	_current_msg = str(item.get("msg", ""))
	var _raw_pos = item.get("pos", Vector2.ZERO)
	_current_pos = _raw_pos if _raw_pos is Vector2 else Vector2.ZERO
	_update_display_text()

	if view_button != null:
		view_button.visible = (_current_pos != Vector2.ZERO and GameSettings.is_incident_goto_enabled())

	_display_timer = DISPLAY_DURATION
	visible = true
	modulate.a = 1.0

func _close_current_alert() -> void:
	_is_showing = false
	_current_msg = ""
	_current_pos = Vector2.ZERO
	if view_button != null:
		view_button.visible = false
	visible = false
	_cooldown_timer = SERIALIZE_DELAY

func _process(delta: float) -> void:
	if _is_showing:
		_display_timer -= delta
		if _display_timer <= 0.0:
			_close_current_alert()
		return

	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0 and not _alert_queue.is_empty():
			_show_next_alert()

func _on_view_pressed() -> void:
	if _current_pos != Vector2.ZERO:
		location_view_requested.emit(_current_pos)

func _on_close_pressed() -> void:
	if not _alert_queue.is_empty():
		_show_next_alert()
	else:
		_close_current_alert()

func clear_alerts() -> void:
	_alert_queue.clear()
	_is_showing = false
	_current_msg = ""
	_current_pos = Vector2.ZERO
	_cooldown_timer = 0.0
	if view_button != null:
		view_button.visible = false
	visible = false
