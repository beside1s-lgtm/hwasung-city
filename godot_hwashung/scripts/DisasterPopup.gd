extends Control
class_name DisasterPopup

## [긴급 재난 및 공성 침입 전용 모달 팝업]
## 화재, 수해 범람, 도적 공성전 등 긴급 재난(PRIORITY_CRITICAL = 1) 발생 시
## 다른 모든 일반 팝업보다 최우선 순위로 화면 중앙에 긴급 경보를 표시합니다.
## 알림창 옆에 [현장 위치 보기 🔍] 버튼을 제공하여 사태 수습 현장을 직접 관찰할 수 있도록 지원합니다.

@warning_ignore("unused_signal")
signal popup_closed
@warning_ignore("unused_signal")
signal location_view_requested(target_world_pos: Vector2)

var _center: CenterContainer
var _panel: PanelContainer
var _title_label: Label
var _desc_label: Label
var _stats_label: Label
var _view_loc_btn: Button
var _confirm_btn: Button
var _target_world_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_ui()
	_sync_viewport_size()
	if is_inside_tree() and get_viewport():
		get_viewport().size_changed.connect(_sync_viewport_size)
	visible = false

func _sync_viewport_size() -> void:
	if not is_inside_tree() or get_viewport() == null:
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	if vp_size.x > 0.0 and vp_size.y > 0.0:
		size = vp_size
		if _center:
			_center.size = vp_size

func _ensure_ui() -> void:
	if _panel == null:
		_build_ui()

func _build_ui() -> void:
	_center = CenterContainer.new()
	_center.name = "CenterContainer"
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)

	_panel = PanelContainer.new()
	_panel.name = "DisasterPanel"
	_panel.custom_minimum_size = Vector2(580, 360)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("fffcf7") # 전통 한지 바탕
	sb.border_color = Color("b91c1c") # 긴급 재난 붉은 경보 테두리
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0.6, 0.05, 0.05, 0.5)
	sb.shadow_size = 18
	sb.set_content_margin_all(22)
	_panel.add_theme_stylebox_override("panel", sb)
	_center.add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "🚨 [긴급 재난 경보]"
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color("991b1b"))
	vbox.add_child(_title_label)

	var sub_label: Label = Label.new()
	sub_label.text = "“백성의 안위가 백척간두에 섰으니, 조정과 관아는 신속히 대책을 강구하라!”"
	sub_label.add_theme_font_size_override("font_size", 11)
	sub_label.add_theme_color_override("font_color", Color("7f1d1d"))
	vbox.add_child(sub_label)

	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	_desc_label = Label.new()
	_desc_label.text = "재난 내용..."
	_desc_label.custom_minimum_size = Vector2(520, 40)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", 14)
	_desc_label.add_theme_color_override("font_color", Color("1c1917"))
	vbox.add_child(_desc_label)

	_stats_label = Label.new()
	_stats_label.text = ""
	_stats_label.custom_minimum_size = Vector2(520, 20)
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.add_theme_font_size_override("font_size", 12)
	_stats_label.add_theme_color_override("font_color", Color("b91c1c"))
	vbox.add_child(_stats_label)

	var btn_box: HBoxContainer = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_END
	btn_box.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_box)

	_view_loc_btn = Button.new()
	_view_loc_btn.text = "현장 위치 보기 🔍"
	_view_loc_btn.custom_minimum_size = Vector2(140, 38)
	_view_loc_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var v_sb := StyleBoxFlat.new()
	v_sb.bg_color = Color(0.72, 0.22, 0.12, 0.95)
	v_sb.border_color = Color(1.0, 0.78, 0.28, 1.0)
	v_sb.set_border_width_all(1)
	v_sb.set_corner_radius_all(4)
	v_sb.content_margin_left = 8
	v_sb.content_margin_right = 8
	v_sb.content_margin_top = 4
	v_sb.content_margin_bottom = 4
	_view_loc_btn.add_theme_stylebox_override("normal", v_sb)
	var v_hov := v_sb.duplicate() as StyleBoxFlat
	v_hov.bg_color = Color(0.85, 0.28, 0.15, 1.0)
	_view_loc_btn.add_theme_stylebox_override("hover", v_hov)
	_view_loc_btn.add_theme_color_override("font_color", Color(1.0, 0.98, 0.90))
	_view_loc_btn.pressed.connect(_on_view_loc_pressed)
	_view_loc_btn.visible = false
	btn_box.add_child(_view_loc_btn)

	_confirm_btn = Button.new()
	_confirm_btn.text = "사태를 수습하고 방재에 임하라 ▶"
	_confirm_btn.custom_minimum_size = Vector2(200, 38)
	_confirm_btn.pressed.connect(close_popup)
	btn_box.add_child(_confirm_btn)

func show_disaster(title_text: String, msg: String, damage_data: Dictionary = {}, target_pos: Vector2 = Vector2.ZERO) -> void:
	if not GameSettings.is_disaster_popup_enabled():
		close_popup()
		return
	_ensure_ui()
	_sync_viewport_size()
	_target_world_pos = target_pos
	_title_label.text = "🚨 [%s]" % title_text
	_desc_label.text = msg

	var stats_lines: Array[String] = []
	if damage_data.has("gold"):
		stats_lines.append("국고 손실: -%d냥" % int(damage_data["gold"]))
	if damage_data.has("rice"):
		stats_lines.append("군량 유실: -%d석" % int(damage_data["rice"]))
	if damage_data.has("loyalty"):
		stats_lines.append("민심 변동: -%d" % int(damage_data["loyalty"]))
	if damage_data.has("defense"):
		stats_lines.append("성 방호력 피해: -%d" % int(damage_data["defense"]))

	if not stats_lines.is_empty():
		_stats_label.text = "【피해 현황】 " + " | ".join(stats_lines)
		_stats_label.visible = true
	else:
		_stats_label.visible = false

	if _view_loc_btn != null:
		_view_loc_btn.visible = (_target_world_pos != Vector2.ZERO and GameSettings.is_incident_goto_enabled())

	visible = true

func _on_view_loc_pressed() -> void:
	var target_p: Vector2 = _target_world_pos
	if target_p != Vector2.ZERO:
		location_view_requested.emit(target_p)
	close_popup()

func close_popup() -> void:
	_target_world_pos = Vector2.ZERO
	if _view_loc_btn != null:
		_view_loc_btn.visible = false
	visible = false
	emit_signal("popup_closed")
