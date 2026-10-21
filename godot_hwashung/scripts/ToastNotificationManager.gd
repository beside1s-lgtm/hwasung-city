class_name ToastNotificationManager
extends CanvasLayer

## [토스트 알림 슬라이더 매니저]
## 우측 상단 슬라이드 인(0.25s) -> 3.0s 대기 -> 페이드아웃(0.3s) 연출을 지원하는 모던 토스트 시스템.

signal toast_finished

var _toast_panel: PanelContainer
var _toast_icon: TextureRect
var _toast_label: Label
var _current_tween: Tween = null
var _toast_queue: Array[Dictionary] = []
var _is_displaying: bool = false

func _ready() -> void:
	layer = 90
	_build_ui()

func _build_ui() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.anchor_left = 1.0
	_toast_panel.anchor_right = 1.0
	_toast_panel.offset_left = -340.0
	_toast_panel.offset_right = -16.0
	_toast_panel.offset_top = 56.0
	_toast_panel.offset_bottom = 106.0
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.06, 0.96)
	sb.border_color = Color(0.85, 0.65, 0.25, 0.95)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 8
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_toast_panel.add_theme_stylebox_override("panel", sb)
	add_child(_toast_panel)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_child(hb)

	_toast_icon = TextureRect.new()
	_toast_icon.custom_minimum_size = Vector2(24, 24)
	_toast_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_toast_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_toast_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(_toast_icon)

	_toast_label = Label.new()
	_toast_label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.90))
	_toast_label.add_theme_font_size_override("font_size", 14)
	_toast_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(_toast_label)

## 토스트 알림 예약 및 표시
func show_toast(msg: String, icon_tex: Texture2D = null) -> void:
	_toast_queue.append({
		"msg": msg,
		"icon": icon_tex
	})
	if not _is_displaying:
		_process_next_toast()

func _process_next_toast() -> void:
	if _toast_queue.is_empty():
		_is_displaying = false
		return

	_is_displaying = true
	var item: Dictionary = _toast_queue.pop_front()
	var msg: String = str(item.get("msg", ""))
	var icon: Texture2D = item.get("icon") as Texture2D

	_toast_label.text = msg
	if icon != null:
		_toast_icon.texture = icon
		_toast_icon.visible = true
	else:
		_toast_icon.visible = false

	var base_right: float = -16.0
	var hidden_right: float = 350.0

	_toast_panel.visible = true
	_toast_panel.modulate.a = 0.0
	_toast_panel.offset_right = hidden_right
	_toast_panel.offset_left = hidden_right - 324.0

	if _current_tween and _current_tween.is_running():
		_current_tween.kill()

	_current_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 1. 슬라이드 인 (0.25초)
	_current_tween.parallel().tween_property(_toast_panel, "offset_right", base_right, 0.25)
	_current_tween.parallel().tween_property(_toast_panel, "offset_left", base_right - 324.0, 0.25)
	_current_tween.parallel().tween_property(_toast_panel, "modulate:a", 1.0, 0.20)
	# 2. 3.0초 대기
	_current_tween.chain().tween_interval(3.0)
	# 3. 페이드아웃 및 슬라이드 아웃 (0.3초)
	_current_tween.chain().set_ease(Tween.EASE_IN)
	_current_tween.parallel().tween_property(_toast_panel, "modulate:a", 0.0, 0.30)
	_current_tween.parallel().tween_property(_toast_panel, "offset_top", 40.0, 0.30)
	_current_tween.chain().tween_callback(func():
		_toast_panel.visible = false
		_toast_panel.offset_top = 56.0
		toast_finished.emit()
		_process_next_toast()
	)
