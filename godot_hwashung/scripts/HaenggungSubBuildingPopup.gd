extends CanvasLayer
class_name HaenggungSubBuildingPopup

## [화성행궁 복합 전각 선택 및 어전 정무 모달]
## 외규장각(학문 연구, 의궤 편찬), 낙남헌(인재 등용), 정리소(현륭원 친림), 행궁 살피기 지원

signal action_requested(action_id: String)
signal inspect_requested

var _backdrop: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _desc_label: Label
var _close_btn: Button
var _btn_oegyu: Button
var _btn_uigwe: Button
var _btn_naknam: Button
var _btn_jeongni: Button
var _btn_prince: Button
var _btn_inspect: Button

var panels: PanelController = null
var court: CourtSystem = null
var sim: SimulationCore = null
var inspect_popup: InspectPopup = null
var current_tile: Dictionary = {}

func _init() -> void:
	layer = 88 # InspectPopup(85) 위에 표시

func _ready() -> void:
	_build_ui()
	visible = false

func _build_ui() -> void:
	# 1. 반투명 배경
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.5)
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)

	# 2. 중앙 패널 (한지 스타일)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(620, 400)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -310
	_panel.offset_top = -200
	_panel.offset_right = 310
	_panel.offset_bottom = 200

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fffdf5")          # 한지 크림색
	sb.border_color = Color("7a5835")      # 고목 테두리
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 10
	sb.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	# 상단 타이틀 바
	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)

	_title_label = Label.new()
	_title_label.text = "🏛️ 화성행궁 어전 정무 (華城行宮 御殿)"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color("8f1d1d"))
	top_row.add_child(_title_label)

	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.flat = true
	_close_btn.custom_minimum_size = Vector2(28, 28)
	_close_btn.add_theme_font_size_override("font_size", 14)
	_close_btn.add_theme_color_override("font_color", Color("7a5835"))
	_close_btn.pressed.connect(close_popup)
	top_row.add_child(_close_btn)

	var sep := HSeparator.new()
	var sep_sb := StyleBoxLine.new()
	sep_sb.color = Color("c9b28b")
	sep_sb.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_sb)
	vbox.add_child(sep)

	_desc_label = Label.new()
	_desc_label.text = "화성행궁 내 집무 공간을 선택하여 국가 정무와 왕실 행사를 윤허하십시오."
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", 12)
	_desc_label.add_theme_color_override("font_color", Color("57534e"))
	vbox.add_child(_desc_label)

	# 전각 버튼 목록
	var btn_vbox := VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_vbox)

	# 1. 외규장각: 실학 학문 연구
	_btn_oegyu = _create_pavilion_btn(
		"📜 [외규장각] 실학 학문 연구 착수",
		"매달 국고를 투입하여 농업·상업·수학 신기술을 연구합니다.",
		func(): _trigger_action("research")
	)
	btn_vbox.add_child(_btn_oegyu)

	# 1-2. 외규장각: 의궤 편찬
	_btn_uigwe = _create_pavilion_btn(
		"📚 [외규장각] 화성성역의궤 편찬 사업",
		"행차와 축성의 전 과정을 의궤도와 함께 역사 기록으로 간행합니다.",
		func():
			close_popup()
			if panels != null and panels.has_method("open_uigwe_popup"):
				panels.open_uigwe_popup()
			else:
				_trigger_action("uigwe")
	)
	btn_vbox.add_child(_btn_uigwe)

	# 2. 낙남헌: 인재 등용
	_btn_naknam = _create_pavilion_btn(
		"👥 [낙남헌] 사대부 및 실학자 인재 등용",
		"과거 시험과 천거를 통해 실학파·사대부 신하를 조정에 등용합니다.",
		func(): _trigger_action("court")
	)
	btn_vbox.add_child(_btn_naknam)

	# 3. 정리소: 현륭원 친림
	_btn_jeongni = _create_pavilion_btn(
		"🏛️ [정리소] 현륭원 친림 참배 거행",
		"정리소를 가동하여 화산 현륭원 능행 준비 및 참배 행사를 집행합니다.",
		func(): _trigger_action("hyoryungwon")
	)
	btn_vbox.add_child(_btn_jeongni)

	# 4. 봉수당/시강원: 세자서연 (경연)
	_btn_prince = _create_pavilion_btn(
		"👑 [봉수당·시강원] 왕세자 경연(서연) 집무",
		"세자의 6단계 성장 모습, 전용 초상화와 제왕학 교육을 맡아 봅니다.",
		func():
			close_popup()
			if panels != null and panels.has_method("open_crown_prince_popup"):
				panels.open_crown_prince_popup()
			else:
				_trigger_action("crown_prince")
	)
	btn_vbox.add_child(_btn_prince)


	# 하단 살피기 및 닫기
	var btm_row := HBoxContainer.new()
	btm_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btm_row)

	_btn_inspect = Button.new()
	_btn_inspect.text = "🔍 행궁 역사 살피기"
	_btn_inspect.custom_minimum_size = Vector2(140, 32)
	_btn_inspect.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_btn_inspect.pressed.connect(_on_inspect_clicked)
	_style_sub_btn(_btn_inspect, Color("4a3b32"))
	btm_row.add_child(_btn_inspect)

	var close_b := Button.new()
	close_b.text = "닫기"
	close_b.custom_minimum_size = Vector2(80, 32)
	close_b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_b.pressed.connect(close_popup)
	_style_sub_btn(close_b, Color("8c6239"))
	btm_row.add_child(close_b)

func _create_pavilion_btn(title: String, desc: String, on_click: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 44)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.text = "%s\n    └ %s" % [title, desc]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var n_sb := StyleBoxFlat.new()
	n_sb.bg_color = Color(0.96, 0.94, 0.90, 1.0)
	n_sb.border_color = Color(0.70, 0.55, 0.40, 1.0)
	n_sb.set_border_width_all(1)
	n_sb.set_corner_radius_all(5)
	n_sb.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", n_sb)

	var h_sb := n_sb.duplicate() as StyleBoxFlat
	h_sb.bg_color = Color(0.92, 0.88, 0.80, 1.0)
	h_sb.border_color = Color("8f1d1d")
	h_sb.set_border_width_all(2)
	btn.add_theme_stylebox_override("hover", h_sb)

	btn.add_theme_color_override("font_color", Color("1c1917"))
	btn.add_theme_color_override("font_hover_color", Color("8f1d1d"))
	btn.add_theme_font_size_override("font_size", 12)

	btn.pressed.connect(on_click)
	return btn

func _style_sub_btn(btn: Button, bg_col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = bg_col.darkened(0.2)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", sb)

	var h_sb := sb.duplicate() as StyleBoxFlat
	h_sb.bg_color = bg_col.lightened(0.15)
	btn.add_theme_stylebox_override("hover", h_sb)
	btn.add_theme_color_override("font_color", Color("ffffff"))

func open_haenggung_popup(tile_dict: Dictionary = {}) -> void:
	current_tile = tile_dict
	_refresh_buttons()
	visible = true

func _refresh_buttons() -> void:
	var cur_court: CourtSystem = court
	if cur_court == null and panels != null:
		cur_court = panels.court
	var cur_sim: SimulationCore = sim
	if cur_sim == null and panels != null:
		cur_sim = panels.sim

	var tech_mgr: TechTreeManager = null
	if cur_sim != null and "tech_tree" in cur_sim and cur_sim.tech_tree is TechTreeManager:
		tech_mgr = cur_sim.tech_tree as TechTreeManager

	# 1. 외규장각: 실학 학문 연구 현황
	var oegyu_badge: String = ""
	var oegyu_sub: String = "매달 국고를 투입하여 농업·상업·수학 신기술을 연구합니다."
	var oegyu_is_done: bool = false
	var oegyu_in_prog: bool = false
	if tech_mgr != null:
		var completed_cnt: int = 0
		for t_id in tech_mgr.tech_completed_dict.keys():
			if bool(tech_mgr.tech_completed_dict.get(t_id, false)):
				completed_cnt += 1
		var total_cnt: int = TechTreeManager.TECH_LIST.size()

		if completed_cnt >= total_cnt and total_cnt > 0:
			oegyu_badge = " [연구 완수 (%d/%d)]" % [completed_cnt, total_cnt]
			oegyu_sub = "농업·상업·수학 등 8대 실학 과제를 모두 집대성 완수하였습니다."
			oegyu_is_done = true
		elif tech_mgr.current_researching != "":
			var cur_info: Dictionary = tech_mgr.get_tech_info(tech_mgr.current_researching)
			var c_name: String = str(cur_info.get("name", "신기술"))
			var prog: int = int(float(tech_mgr.tech_progress_dict.get(tech_mgr.current_researching, 0.0)))
			oegyu_badge = " [연구 중: %s %d%%]" % [c_name, prog]
			oegyu_sub = "현재 활발히 연구 진행 중입니다. (완료: %d/%d 과제)" % [completed_cnt, total_cnt]
			oegyu_in_prog = true
		else:
			oegyu_badge = " [완료 %d/%d개]" % [completed_cnt, total_cnt]
			oegyu_sub = "매달 국고를 투입하여 농업·상업·수학 신기술을 연구합니다."
	_update_btn_ui(_btn_oegyu, "📜 [외규장각] 실학 학문 연구 착수", oegyu_badge, oegyu_sub, oegyu_is_done, oegyu_in_prog)

	# 2. 외규장각: 의궤 편찬 현황
	var uigwe_badge: String = ""
	var uigwe_sub: String = "행차와 축성의 전 과정을 의궤도와 함께 역사 기록으로 간행합니다."
	var uigwe_is_done: bool = false
	if cur_court != null:
		# court.uigwe와 uigwe_manager 이중 체크:
		# 세이브 로드 후 court.uigwe가 비어있는 경우에도 uigwe_manager.is_completed()로 폴백
		var uigwe_mgr = cur_sim.get("uigwe_manager") if cur_sim != null else null
		var wonhaeng_done: bool = bool(cur_court.uigwe.get("wonhaeng", false))
		var seongyeok_done: bool = bool(cur_court.uigwe.get("seongyeok", false))
		if not wonhaeng_done and uigwe_mgr != null and uigwe_mgr.is_completed("wonhaeng"):
			wonhaeng_done = true
			cur_court.uigwe["wonhaeng"] = true  # court.uigwe 동기화 (지연 복원)
		if not seongyeok_done and uigwe_mgr != null and uigwe_mgr.is_completed("seongyeok"):
			seongyeok_done = true
			cur_court.uigwe["seongyeok"] = true  # court.uigwe 동기화 (지연 복원)
		var uigwe_cnt: int = (1 if wonhaeng_done else 0) + (1 if seongyeok_done else 0)
		if uigwe_cnt >= 2:
			uigwe_badge = " [편찬 완수 (2/2권)]"
			uigwe_sub = "원행을묘정리의궤 및 화성성역의궤를 모두 편찬하여 규장각에 봉안했습니다."
			uigwe_is_done = true
		elif uigwe_cnt == 1:
			uigwe_badge = " [1/2권 편찬 완료]"
			uigwe_sub = "일부 의궤를 편찬했습니다. 남은 역사 기록을 간행하십시오."
		else:
			uigwe_badge = " [미편찬 (0/2권)]"
			uigwe_sub = "행차와 축성의 전 과정을 의궤도와 함께 역사 기록으로 간행합니다."
	_update_btn_ui(_btn_uigwe, "📚 [외규장각] 화성성역의궤 편찬 사업", uigwe_badge, uigwe_sub, uigwe_is_done, false)

	# 3. 낙남헌: 인재 등용 현황
	var naknam_badge: String = ""
	var naknam_sub: String = "과거 시험과 천거를 통해 실학파·사대부 신하를 조정에 등용합니다."
	var naknam_is_done: bool = false
	if cur_sim != null and "retainers" in cur_sim and cur_sim.retainers is Dictionary:
		var hired_scholars: int = 0
		var total_scholars: int = 0
		for t_key in ScholarManager.TALENTS_DATA.keys():
			var s_data: Dictionary = ScholarManager.TALENTS_DATA[t_key]
			if int(s_data.get("role_type", -1)) == ScholarManager.RoleType.COURT_SCHOLAR:
				total_scholars += 1
				if bool(cur_sim.retainers.get(t_key, false)):
					hired_scholars += 1
		if hired_scholars >= total_scholars and total_scholars > 0:
			naknam_badge = " [전원 등용 완수 (%d/%d명)]" % [hired_scholars, total_scholars]
			naknam_sub = "조정 4대 정파의 탕평 명현들을 모두 등용하여 정무를 보좌합니다."
			naknam_is_done = true
		else:
			naknam_badge = " [현재 등용 %d/%d명]" % [hired_scholars, total_scholars]
			naknam_sub = "과거 시험과 천거를 통해 실학파·사대부 신하를 조정에 등용합니다."
	_update_btn_ui(_btn_naknam, "👥 [낙남헌] 사대부 및 실학자 인재 등용", naknam_badge, naknam_sub, naknam_is_done, false)

	# 4. 정리소: 현륭원 친림 참배 현황
	var jeongni_badge: String = ""
	var jeongni_sub: String = "정리소를 가동하여 화산 현륭원 능행 준비 및 참배 행사를 집행합니다."
	var jeongni_is_done: bool = false
	if cur_court != null:
		var visited_this_year: bool = bool(cur_court.hyoryungwon.get("visited", false))
		var visits_count: int = CityStats.get_hyeonryungwon_visits()
		if visited_this_year:
			jeongni_badge = " [올해 참배 완료 (누적 %d회)]" % visits_count
			jeongni_sub = "금년도 현륭원 원행을 이미 봉행하였습니다. (효심의 가호 유지 중)"
			jeongni_is_done = true
		else:
			jeongni_badge = " [금년 미참배 (누적 %d회)]" % visits_count
			jeongni_sub = "정리소를 가동하여 화산 현륭원 능행 준비 및 참배 행사를 집행합니다."
	_update_btn_ui(_btn_jeongni, "🏛️ [정리소] 현륭원 친림 참배 거행", jeongni_badge, jeongni_sub, jeongni_is_done, false)

	# 5. 봉수당/시강원: 세자 서연 현황
	var prince_badge: String = ""
	var prince_sub: String = "세자의 6단계 성장 모습, 전용 초상화와 제왕학 교육을 맡아 봅니다."
	var prince_is_done: bool = false
	var prince_in_prog: bool = false
	var edu: int = CityStats.get_crown_prince_education()
	if edu >= 100:
		prince_badge = " [제왕학 완수 (100%)]"
		prince_sub = "세자께서 시강원 서연을 통해 제왕학 과정을 모두 완수하셨습니다."
		prince_is_done = true
	elif edu > 0:
		prince_badge = " [서연 진행 중 (%d%%)]" % edu
		prince_sub = "시강원에서 세자에게 강론을 열어 제왕학을 전수하고 있습니다."
		prince_in_prog = true
	else:
		prince_badge = " [서연 미착수 (0%)]"
		prince_sub = "세자의 6단계 성장 모습, 전용 초상화와 제왕학 교육을 맡아 봅니다."
	_update_btn_ui(_btn_prince, "👑 [봉수당·시강원] 왕세자 경연(서연) 집무", prince_badge, prince_sub, prince_is_done, prince_in_prog)

func _update_btn_ui(btn: Button, title: String, badge: String, desc: String, is_done: bool, in_progress: bool) -> void:
	if btn == null:
		return
	btn.text = "%s%s\n    └ %s" % [title, badge, desc]

	var n_sb := StyleBoxFlat.new()
	n_sb.set_border_width_all(1)
	n_sb.set_corner_radius_all(5)
	n_sb.set_content_margin_all(6)

	if is_done:
		n_sb.bg_color = Color(0.93, 0.97, 0.94, 1.0)
		n_sb.border_color = Color("2e7d32")
		btn.add_theme_color_override("font_color", Color("1b5e20"))
	elif in_progress:
		n_sb.bg_color = Color(0.99, 0.96, 0.91, 1.0)
		n_sb.border_color = Color("b45309")
		btn.add_theme_color_override("font_color", Color("78350f"))
	else:
		n_sb.bg_color = Color(0.96, 0.94, 0.90, 1.0)
		n_sb.border_color = Color(0.70, 0.55, 0.40, 1.0)
		btn.add_theme_color_override("font_color", Color("1c1917"))

	btn.add_theme_stylebox_override("normal", n_sb)

	var h_sb := n_sb.duplicate() as StyleBoxFlat
	h_sb.bg_color = n_sb.bg_color.darkened(0.04)
	h_sb.border_color = Color("8f1d1d")
	h_sb.set_border_width_all(2)
	btn.add_theme_stylebox_override("hover", h_sb)

func close_popup() -> void:
	visible = false

func _trigger_action(action_id: String) -> void:
	close_popup()
	emit_signal("action_requested", action_id)
	if panels != null and panels.has_method("open_action_modal"):
		panels.open_action_modal(action_id)

func _on_inspect_clicked() -> void:
	close_popup()
	emit_signal("inspect_requested")

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT):
		close_popup()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_SPACE:
			close_popup()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		close_popup()
		get_viewport().set_input_as_handled()
