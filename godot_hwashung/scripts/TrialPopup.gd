extends CanvasLayer
class_name TrialPopup

## [화성유수부 공형청 원옥 심리 전용 모달 팝업]
## 한지 스타일 배경, 좌측 죄인 진술 및 초상, 우측 비장/아전 수사 기록, 하단 3대 판결 선택지
## 및 판결 후 결과 연출(플로팅 스탯 변동치, 판결봉 타격)

signal verdict_selected(choice_index: int)
signal popup_closed

var trial_manager: TrialManager = null
var current_case: Dictionary = {}
var is_resolved: bool = false

var _backdrop: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _close_btn: Button

# 좌측 죄인 영역
var _def_portrait: TextureRect
var _def_name_label: Label
var _def_desc_label: Label

# 우측 수사 기록 영역
var _inv_portrait: TextureRect
var _inv_title_label: Label
var _inv_report_label: Label

# 하단 선택지 영역
var _choice_box: VBoxContainer
var _choice_buttons: Array[Button] = []
var _resolved_notice_label: Label

# 결과 피드백 패널/플로팅 배너
var _verdict_panel: PanelContainer
var _verdict_title: Label
var _verdict_desc: Label
var _verdict_stats_label: Label
var _verdict_confirm_btn: Button

func _init() -> void:
	layer = 86 # InspectPopup(85) 바로 위, 중요 모달 계층

func _ready() -> void:
	_build_ui()
	visible = false

func _build_ui() -> void:
	# 1. 반투명 배경 딤
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)

	# 2. 중앙 한지 두루마리 대형 팝업 패널
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(680, 500)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -340
	_panel.offset_top = -250
	_panel.offset_right = 340
	_panel.offset_bottom = 250

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fffdf6")          # 전통 한지 크림색
	sb.border_color = Color("5c3a21")      # 짙은 목재 테두리
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 14
	sb.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(main_vbox)

	# [상단 헤더] 제목 + 정조 흠휼 격언 + 닫기 버튼
	var header_hbox := HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_box)

	_title_label = Label.new()
	_title_label.text = "⚖️ [화성유수부 공형청 원옥(寃獄) 심리]"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color("8f1d1d")) # 조선 궁중 홍색
	title_box.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = "“정조 대왕의 흠휼(欽恤) 뜻을 받들어 억울한 죄인이 없도록 신중히 명판결을 내리시오.”"
	_subtitle_label.add_theme_font_size_override("font_size", 11)
	_subtitle_label.add_theme_color_override("font_color", Color("78502c"))
	title_box.add_child(_subtitle_label)

	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.flat = true
	_close_btn.custom_minimum_size = Vector2(28, 28)
	_close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_btn.add_theme_font_size_override("font_size", 16)
	_close_btn.add_theme_color_override("font_color", Color("7a5835"))
	_close_btn.pressed.connect(close_trial)
	header_hbox.add_child(_close_btn)

	var sep1 := HSeparator.new()
	var sep1_sb := StyleBoxLine.new()
	sep1_sb.color = Color("c9b28b")
	sep1_sb.thickness = 1
	sep1.add_theme_stylebox_override("separator", sep1_sb)
	main_vbox.add_child(sep1)

	# [중앙 2단 수평 레이아웃] 좌: 죄인 진술, 우: 아전/비장 수사 기록
	var mid_hbox := HBoxContainer.new()
	mid_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(mid_hbox)

	# 1. 좌측 죄인 패널
	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var l_sb := StyleBoxFlat.new()
	l_sb.bg_color = Color("f7f3e8")
	l_sb.border_color = Color("b39268")
	l_sb.set_border_width_all(2)
	l_sb.set_corner_radius_all(6)
	l_sb.set_content_margin_all(10)
	left_panel.add_theme_stylebox_override("panel", l_sb)
	mid_hbox.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_panel.add_child(left_vbox)

	var l_top_hbox := HBoxContainer.new()
	l_top_hbox.add_theme_constant_override("separation", 10)
	left_vbox.add_child(l_top_hbox)

	_def_portrait = TextureRect.new()
	_def_portrait.custom_minimum_size = Vector2(64, 64)
	_def_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_def_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_def_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	l_top_hbox.add_child(_def_portrait)

	var l_title_vbox := VBoxContainer.new()
	l_top_hbox.add_child(l_title_vbox)

	var l_sec_lbl := Label.new()
	l_sec_lbl.text = "👤 [취조 죄인]"
	l_sec_lbl.add_theme_font_size_override("font_size", 11)
	l_sec_lbl.add_theme_color_override("font_color", Color("8c5224"))
	l_title_vbox.add_child(l_sec_lbl)

	_def_name_label = Label.new()
	_def_name_label.text = "죄인 이름 (신분)"
	_def_name_label.add_theme_font_size_override("font_size", 14)
	_def_name_label.add_theme_color_override("font_color", Color("2c1a0e"))
	l_title_vbox.add_child(_def_name_label)

	_def_desc_label = Label.new()
	_def_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_def_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_def_desc_label.add_theme_font_size_override("font_size", 12)
	_def_desc_label.add_theme_color_override("font_color", Color("3a2416"))
	_def_desc_label.add_theme_constant_override("line_spacing", 4)
	left_vbox.add_child(_def_desc_label)

	# 2. 우측 비장/아전 수사 기록 패널
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var r_sb := StyleBoxFlat.new()
	r_sb.bg_color = Color("f3ece0")
	r_sb.border_color = Color("9e7d58")
	r_sb.set_border_width_all(2)
	r_sb.set_corner_radius_all(6)
	r_sb.set_content_margin_all(10)
	right_panel.add_theme_stylebox_override("panel", r_sb)
	mid_hbox.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_panel.add_child(right_vbox)

	var r_top_hbox := HBoxContainer.new()
	r_top_hbox.add_theme_constant_override("separation", 10)
	right_vbox.add_child(r_top_hbox)

	_inv_portrait = TextureRect.new()
	_inv_portrait.custom_minimum_size = Vector2(64, 64)
	_inv_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_inv_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_inv_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r_top_hbox.add_child(_inv_portrait)

	var r_title_vbox := VBoxContainer.new()
	r_top_hbox.add_child(r_title_vbox)

	var r_sec_lbl := Label.new()
	r_sec_lbl.text = "📜 [수사 및 현장 실황]"
	r_sec_lbl.add_theme_font_size_override("font_size", 11)
	r_sec_lbl.add_theme_color_override("font_color", Color("2a4e6c"))
	r_title_vbox.add_child(r_sec_lbl)

	_inv_title_label = Label.new()
	_inv_title_label.text = "아전/비장의 수사 보고"
	_inv_title_label.add_theme_font_size_override("font_size", 14)
	_inv_title_label.add_theme_color_override("font_color", Color("1a2e3b"))
	r_title_vbox.add_child(_inv_title_label)

	_inv_report_label = Label.new()
	_inv_report_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inv_report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inv_report_label.add_theme_font_size_override("font_size", 12)
	_inv_report_label.add_theme_color_override("font_color", Color("24333c"))
	_inv_report_label.add_theme_constant_override("line_spacing", 4)
	right_vbox.add_child(_inv_report_label)

	var sep2 := HSeparator.new()
	var sep2_sb := StyleBoxLine.new()
	sep2_sb.color = Color("c9b28b")
	sep2_sb.thickness = 1
	sep2.add_theme_stylebox_override("separator", sep2_sb)
	main_vbox.add_child(sep2)

	# [하단 판결 선택지 영역]
	var btm_vbox := VBoxContainer.new()
	btm_vbox.add_theme_constant_override("separation", 6)
	main_vbox.add_child(btm_vbox)

	var choice_title := Label.new()
	choice_title.text = "⚖️ [화성유수 판결 결단]: 아래 세 가지 처분 중 사안의 정황에 맞추어 결단을 내리십시오."
	choice_title.add_theme_font_size_override("font_size", 12)
	choice_title.add_theme_color_override("font_color", Color("5c3a21"))
	btm_vbox.add_child(choice_title)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 6)
	btm_vbox.add_child(_choice_box)

	for i in range(3):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 36)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_font_size_override("font_size", 12)
		_apply_choice_btn_style(btn, i)
		var c_idx: int = i
		btn.pressed.connect(func(): _on_choice_pressed(c_idx))
		_choice_box.add_child(btn)
		_choice_buttons.append(btn)

	_resolved_notice_label = Label.new()
	_resolved_notice_label.text = "※ 이번 계절의 송사는 이미 판결을 마쳤습니다. 다음 계절에 새로운 송사가 당도합니다."
	_resolved_notice_label.add_theme_font_size_override("font_size", 12)
	_resolved_notice_label.add_theme_color_override("font_color", Color("2b6cb0"))
	_resolved_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resolved_notice_label.visible = false
	btm_vbox.add_child(_resolved_notice_label)

	# 3. 판결 결과 안내 오버레이 패널
	_build_verdict_overlay()

func _apply_choice_btn_style(btn: Button, idx: int) -> void:
	var sb := StyleBoxFlat.new()
	match idx:
		0: # 엄벌 (붉은 계열 테두리)
			sb.bg_color = Color("f9edea")
			sb.border_color = Color("c05646")
		1: # 타협 (갈색/황토 계열)
			sb.bg_color = Color("f7f4ea")
			sb.border_color = Color("9c824a")
		2: # 관용 (녹청 계열)
			sb.bg_color = Color("eaf5ed")
			sb.border_color = Color("489c62")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", sb)

	var hsb := sb.duplicate() as StyleBoxFlat
	hsb.set_border_width_all(2)
	hsb.bg_color = hsb.bg_color.darkened(0.05)
	btn.add_theme_stylebox_override("hover", hsb)

	btn.add_theme_color_override("font_color", Color("1a1410"))
	btn.add_theme_color_override("font_hover_color", Color("000000"))

func _build_verdict_overlay() -> void:
	_verdict_panel = PanelContainer.new()
	_verdict_panel.custom_minimum_size = Vector2(500, 260)
	_verdict_panel.set_anchors_preset(Control.PRESET_CENTER)
	_verdict_panel.offset_left = -250
	_verdict_panel.offset_top = -130
	_verdict_panel.offset_right = 250
	_verdict_panel.offset_bottom = 130
	_verdict_panel.visible = false

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fffcf0")
	sb.border_color = Color("8f1d1d")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 12
	sb.set_content_margin_all(16)
	_verdict_panel.add_theme_stylebox_override("panel", sb)
	add_child(_verdict_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_verdict_panel.add_child(vb)

	_verdict_title = Label.new()
	_verdict_title.text = "📜 [판결 집행 완료]"
	_verdict_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_verdict_title.add_theme_font_size_override("font_size", 16)
	_verdict_title.add_theme_color_override("font_color", Color("8f1d1d"))
	vb.add_child(_verdict_title)

	var sep := HSeparator.new()
	vb.add_child(sep)

	_verdict_desc = Label.new()
	_verdict_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_verdict_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_verdict_desc.add_theme_font_size_override("font_size", 13)
	_verdict_desc.add_theme_color_override("font_color", Color("2c1a0e"))
	_verdict_desc.add_theme_constant_override("line_spacing", 4)
	vb.add_child(_verdict_desc)

	_verdict_stats_label = Label.new()
	_verdict_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_verdict_stats_label.add_theme_font_size_override("font_size", 13)
	_verdict_stats_label.add_theme_color_override("font_color", Color("78350f"))
	vb.add_child(_verdict_stats_label)

	var b_hb := HBoxContainer.new()
	b_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(b_hb)

	_verdict_confirm_btn = Button.new()
	_verdict_confirm_btn.text = "판결안 실록 기록 및 닫기"
	_verdict_confirm_btn.custom_minimum_size = Vector2(180, 32)
	_verdict_confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_verdict_confirm_btn.pressed.connect(func():
		_verdict_panel.visible = false
		close_trial()
	)
	b_hb.add_child(_verdict_confirm_btn)

## 사건 데이터를 팝업에 주입하고 모달 활성화
func open_trial(case_data: Dictionary, resolved_this_turn: bool = false) -> void:
	current_case = case_data
	is_resolved = resolved_this_turn

	_title_label.text = "⚖️ [화성유수부 공형청]: %s" % case_data.get("title", "원옥(寃獄) 심리")
	_def_name_label.text = case_data.get("defendant_name", "죄인")
	_def_desc_label.text = case_data.get("defendant_desc", "")
	_inv_title_label.text = case_data.get("investigator_title", "수사 보고")
	_inv_report_label.text = case_data.get("investigator_report", "")

	# 초상화 주입
	var def_tex_key: String = case_data.get("defendant_portrait", "criminal")
	var inv_tex_key: String = case_data.get("investigator_portrait", "ajeon_investigator")
	_def_portrait.texture = PortraitArt.make(def_tex_key)
	_inv_portrait.texture = PortraitArt.make(inv_tex_key)

	# 선택지 주입
	var choices: Array = case_data.get("choices", [])
	for i in range(_choice_buttons.size()):
		if i < choices.size():
			var ch: Dictionary = choices[i]
			_choice_buttons[i].text = ch.get("label", "")
			_choice_buttons[i].visible = not is_resolved
		else:
			_choice_buttons[i].visible = false

	_choice_box.visible = not is_resolved
	_resolved_notice_label.visible = is_resolved
	_verdict_panel.visible = false

	visible = true

func _on_choice_pressed(choice_index: int) -> void:
	if is_resolved:
		return
	emit_signal("verdict_selected", choice_index)
	if trial_manager:
		var res: Dictionary = trial_manager.apply_verdict(choice_index)
		if res.get("success", false):
			_show_verdict_result(res)
		else:
			close_trial()

func _show_verdict_result(res: Dictionary) -> void:
	_verdict_title.text = "📜 [%s 판결 집행]" % res.get("title", "송사")
	_verdict_desc.text = res.get("verdict_text", "")

	var stats_parts: Array[String] = []
	var r_val: int = int(res.get("delta_royal", 0))
	var l_val: int = int(res.get("delta_loyalty", 0))
	var g_val: int = int(res.get("delta_gold", 0))
	var rc_val: int = int(res.get("delta_rice", 0))

	if r_val != 0:
		stats_parts.append("[👑 왕권 %s%d]" % [("+" if r_val > 0 else ""), r_val])
	if l_val != 0:
		stats_parts.append("[❤️ 민심 %s%d]" % [("+" if l_val > 0 else ""), l_val])
	if g_val != 0:
		stats_parts.append("[🪙 국고 %s%d냥]" % [("+" if g_val > 0 else ""), g_val])
	if rc_val != 0:
		stats_parts.append("[🌾 군량 %s%d석]" % [("+" if rc_val > 0 else ""), rc_val])

	if stats_parts.is_empty():
		_verdict_stats_label.text = "[현상 유지: 수치 변동 없음]"
	else:
		_verdict_stats_label.text = " ".join(stats_parts)

	_verdict_panel.visible = true

func close_trial() -> void:
	visible = false
	_verdict_panel.visible = false
	emit_signal("popup_closed")

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
		close_trial()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE:
			close_trial()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		close_trial()
		get_viewport().set_input_as_handled()
