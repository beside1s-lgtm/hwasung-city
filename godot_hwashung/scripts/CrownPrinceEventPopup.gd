extends Control
class_name CrownPrinceEventPopup

## [세자 제왕학 서연 건의 및 성취 전용 모달 팝업]
## 세자 시강원의 서연 진행도 갱신, 학문적 도약 및 단계 상승 시
## 우선순위 대기열(PRIORITY_URGENT = 2)을 통해 화면에 정중히 보고합니다.

@warning_ignore("unused_signal")
signal popup_closed

var prince_mgr_ref: CrownPrinceEducationManager = null
var sim_ref: SimulationCore = null

var _center: CenterContainer
var _panel: PanelContainer
var _title_label: Label
var _portrait_rect: TextureRect
var _stage_badge: Label
var _quote_label: Label
var _desc_label: Label
var _confirm_btn: Button

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
	_panel.name = "PrincePanel"
	_panel.custom_minimum_size = Vector2(560, 420)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("fffdf6")
	sb.border_color = Color("1e3a8a") # 왕세자 청람색 테두리
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 14
	sb.set_content_margin_all(22)
	_panel.add_theme_stylebox_override("panel", sb)
	_center.add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "📜 [동궁(東宮) 제왕학 서연 보고]"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color("1e3a8a"))
	vbox.add_child(_title_label)

	var sub_label: Label = Label.new()
	sub_label.text = "“시강원 학관들이 세자 저하의 배움을 정성껏 보도하고 있사옵니다.”"
	sub_label.add_theme_font_size_override("font_size", 11)
	sub_label.add_theme_color_override("font_color", Color("1e40af"))
	vbox.add_child(sub_label)

	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	var content_hbox: HBoxContainer = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(content_hbox)

	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(100, 120)
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content_hbox.add_child(_portrait_rect)

	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 6)
	content_hbox.add_child(info_vbox)

	_stage_badge = Label.new()
	_stage_badge.text = "단계: 1단계 천자문"
	_stage_badge.add_theme_font_size_override("font_size", 15)
	_stage_badge.add_theme_color_override("font_color", Color("1c1917"))
	info_vbox.add_child(_stage_badge)

	_desc_label = Label.new()
	_desc_label.text = "세자 저하께서 유교 경전을 익히시며 성군의 자질을 닦고 계십니다."
	_desc_label.custom_minimum_size = Vector2(380, 30)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", 12)
	_desc_label.add_theme_color_override("font_color", Color("334155"))
	info_vbox.add_child(_desc_label)

	_quote_label = Label.new()
	_quote_label.text = "\"\""
	_quote_label.custom_minimum_size = Vector2(500, 30)
	_quote_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quote_label.add_theme_font_size_override("font_size", 12)
	_quote_label.add_theme_color_override("font_color", Color("475569"))
	vbox.add_child(_quote_label)

	var btn_box: HBoxContainer = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_box)

	_confirm_btn = Button.new()
	_confirm_btn.text = "서연을 독려하라 ▶"
	_confirm_btn.custom_minimum_size = Vector2(150, 36)
	_confirm_btn.pressed.connect(close_popup)
	btn_box.add_child(_confirm_btn)

func show_event(prince_data: Dictionary) -> void:
	_ensure_ui()
	_sync_viewport_size()
	var stage_idx: int = int(prince_data.get("stage", 0))
	_stage_badge.text = "단계: %s" % CrownPrinceData.get_stage_badge(stage_idx)
	_desc_label.text = CrownPrinceData.get_stage_description(stage_idx)
	_quote_label.text = "“%s”" % CrownPrinceData.get_stage_quote(stage_idx)
	if _portrait_rect:
		_portrait_rect.texture = CrownPrinceData.get_portrait_texture(stage_idx)

	visible = true

func close_popup() -> void:
	visible = false
	emit_signal("popup_closed")
