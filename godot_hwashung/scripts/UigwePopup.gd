extends CanvasLayer
class_name UigwePopup

## [규장각 의궤 편찬 목록 및 게이지 FSM 팝업]
## - 원행을묘정리의궤 / 화성성역의궤 독립 진척도 관리
## - 학문력 연동 턴당 진행률 및 프로그레스 바 실시간 반영
## - [편찬 시작] / [일시 중지] / [편찬 재개] -> 완료 시 [📖 의궤 열람] 전환
## - 완료된 의궤 클릭 시 UigweViewerModal(도감) 오픈

signal closed

var sim: SimulationCore = null
var court: CourtSystem = null
var uigwe_mgr: UigweManager = null
var viewer_modal: UigweViewerModal = null

var _overlay: ColorRect = null
var _main_panel: PanelContainer = null

# 의궤별 UI 컨트롤 참조 딕셔너리
var _ui_cards: Dictionary = {}

func _init() -> void:
	layer = 106 # 팝업 레이어

func _ready() -> void:
	_build_ui()
	visible = false

func setup(p_sim: SimulationCore, p_court: CourtSystem = null, p_uigwe_mgr: UigweManager = null) -> void:
	sim = p_sim
	court = p_court
	if p_uigwe_mgr != null:
		uigwe_mgr = p_uigwe_mgr
	elif sim != null and "uigwe_manager" in sim and sim.uigwe_manager != null:
		uigwe_mgr = sim.uigwe_manager

	if uigwe_mgr != null:
		if not uigwe_mgr.uigwe_progress_updated.is_connected(_on_progress_updated):
			uigwe_mgr.uigwe_progress_updated.connect(_on_progress_updated)
		if not uigwe_mgr.uigwe_started.is_connected(_on_status_changed):
			uigwe_mgr.uigwe_started.connect(_on_status_changed)
			uigwe_mgr.uigwe_paused.connect(_on_status_paused)
			uigwe_mgr.uigwe_resumed.connect(_on_status_changed)
			uigwe_mgr.uigwe_completed.connect(_on_status_changed)

	refresh_ui()

func _build_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.55)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close_popup()
	)
	add_child(_overlay)

	# 메인 한지풍 패널 (820 x 560)
	_main_panel = PanelContainer.new()
	_main_panel.custom_minimum_size = Vector2(820, 560)
	_main_panel.set_anchors_preset(Control.PRESET_CENTER)
	_main_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_main_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color("f6f1e3")
	panel_sb.set_border_width_all(3)
	panel_sb.border_color = Color("2c241e")
	panel_sb.set_corner_radius_all(3)
	panel_sb.shadow_color = Color(0, 0, 0, 0.45)
	panel_sb.shadow_size = 14
	panel_sb.shadow_offset = Vector2(4, 6)
	_main_panel.add_theme_stylebox_override("panel", panel_sb)
	_overlay.add_child(_main_panel)

	# 배경 한지 텍스처
	if ResourceLoader.exists("res://assets/ui/hanji_paper.png"):
		var paper := TextureRect.new()
		paper.texture = load("res://assets/ui/hanji_paper.png")
		paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		paper.stretch_mode = TextureRect.STRETCH_SCALE
		paper.set_anchors_preset(Control.PRESET_FULL_RECT)
		paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_main_panel.add_child(paper)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_main_panel.add_child(margin)

	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 10)
	margin.add_child(root_vb)

	# 1. 상단 헤더
	var header_hb := HBoxContainer.new()
	root_vb.add_child(header_hb)

	var title_vb := VBoxContainer.new()
	title_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hb.add_child(title_vb)

	var title_lbl := Label.new()
	title_lbl.text = "📚 규장각 의궤 편찬 (奎章閣 儀軌 編纂)"
	ThemeManager.apply_title_font(title_lbl, 22)
	title_lbl.add_theme_color_override("font_color", Color("1c1612"))
	title_vb.add_child(title_lbl)

	var subtitle_lbl := Label.new()
	subtitle_lbl.text = "규장각에서 나라의 큰일을 그림과 글로 자세히 기록하여 후세에 전합니다."
	ThemeManager.apply_base_font(subtitle_lbl, 13)
	subtitle_lbl.add_theme_color_override("font_color", Color("4d3e34"))
	title_vb.add_child(subtitle_lbl)

	var close_btn := Button.new()
	close_btn.text = " ✕ "
	close_btn.custom_minimum_size = Vector2(34, 30)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(close_popup)
	_style_close_button(close_btn)
	header_hb.add_child(close_btn)

	# 구분 먹선
	root_vb.add_child(_create_divider(2))

	# 2. 의궤 카드 목록 (스크롤/VBox)
	var cards_vb := VBoxContainer.new()
	cards_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_vb.add_theme_constant_override("separation", 12)
	root_vb.add_child(cards_vb)

	for id: String in ["wonhaeng", "seongyeok"]:
		var card := _build_uigwe_card(id)
		cards_vb.add_child(card)

	# 3. 하단 안내 및 닫기
	var footer_hb := HBoxContainer.new()
	root_vb.add_child(footer_hb)

	var tip_lbl := Label.new()
	tip_lbl.text = "※ 학문력이 높을수록 편찬 속도가 빨라지며, 이덕무·채제공 등용 시 편찬비가 할인됩니다."
	ThemeManager.apply_base_font(tip_lbl, 12)
	tip_lbl.add_theme_color_override("font_color", Color("665447"))
	tip_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hb.add_child(tip_lbl)

	var btm_close := Button.new()
	btm_close.text = "닫기"
	btm_close.custom_minimum_size = Vector2(80, 32)
	btm_close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btm_close.pressed.connect(close_popup)
	_style_button(btm_close, Color("5c493a"))
	footer_hb.add_child(btm_close)

	# 뷰어 모달 사전 인스턴스화
	viewer_modal = UigweViewerModal.new()
	add_child(viewer_modal)

func _build_uigwe_card(id: String) -> PanelContainer:
	var info: Dictionary = UigweManager.UIGWE_DATA.get(id, {})
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color("efe5cf")
	card_sb.set_border_width_all(1)
	card_sb.border_color = Color("8c735a")
	card_sb.set_corner_radius_all(4)
	card_sb.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", card_sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	card.add_child(vb)

	# 1줄: 제목 및 상태 뱃지
	var row1 := HBoxContainer.new()
	vb.add_child(row1)

	var title_lbl := Label.new()
	title_lbl.text = str(info.get("name", "의궤"))
	ThemeManager.apply_title_font(title_lbl, 17)
	title_lbl.add_theme_color_override("font_color", Color("1c140e"))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(title_lbl)

	var status_badge := Label.new()
	status_badge.text = "[ 미착수 ]"
	ThemeManager.apply_base_font(status_badge, 13)
	status_badge.add_theme_color_override("font_color", Color("7a614c"))
	row1.add_child(status_badge)

	# 2줄: 해금 조건
	var cond_lbl := Label.new()
	cond_lbl.text = "• 조건: %s" % str(info.get("condition_desc", ""))
	ThemeManager.apply_base_font(cond_lbl, 13)
	cond_lbl.add_theme_color_override("font_color", Color("382e26"))
	vb.add_child(cond_lbl)

	# 3줄: 비용 및 예상 소요 연도
	var cost_lbl := Label.new()
	cost_lbl.text = "• 비용: 연간 5,000냥 | 예상 소요: 계산 중..."
	ThemeManager.apply_base_font(cost_lbl, 13)
	cost_lbl.add_theme_color_override("font_color", Color("2d3748"))
	vb.add_child(cost_lbl)

	# 4줄: 프로그레스 바 및 수치 라벨
	var prog_hb := HBoxContainer.new()
	prog_hb.add_theme_constant_override("separation", 10)
	vb.add_child(prog_hb)

	var pb := ProgressBar.new()
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.custom_minimum_size = Vector2(0, 22)
	pb.min_value = 0.0
	pb.max_value = 100.0
	pb.value = 0.0
	pb.show_percentage = false

	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color("dcd0b8")
	pb_bg.set_border_width_all(1)
	pb_bg.border_color = Color("7a6854")
	pb_bg.set_corner_radius_all(3)
	pb.add_theme_stylebox_override("background", pb_bg)

	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = Color("8c6239")
	pb_fill.set_corner_radius_all(3)
	pb.add_theme_stylebox_override("fill", pb_fill)
	prog_hb.add_child(pb)

	var prog_lbl := Label.new()
	prog_lbl.text = "0.0% (매달 +0.0%)"
	ThemeManager.apply_base_font(prog_lbl, 13)
	prog_lbl.custom_minimum_size = Vector2(140, 0)
	prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prog_lbl.add_theme_color_override("font_color", Color("1c140e"))
	prog_hb.add_child(prog_lbl)

	# 5줄: 조작 버튼
	var action_hb := HBoxContainer.new()
	action_hb.alignment = BoxContainer.ALIGNMENT_END
	action_hb.add_theme_constant_override("separation", 8)
	vb.add_child(action_hb)

	var action_btn := Button.new()
	action_btn.text = "편찬 시작"
	action_btn.custom_minimum_size = Vector2(130, 34)
	action_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_button(action_btn, Color("8c6239"))
	action_btn.pressed.connect(func(): _on_action_button_pressed(id))
	action_hb.add_child(action_btn)

	var view_btn := Button.new()
	view_btn.text = "📖 의궤 열람"
	view_btn.custom_minimum_size = Vector2(130, 34)
	view_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_view_button(view_btn)
	view_btn.pressed.connect(func(): _on_view_button_pressed(id))
	view_btn.visible = false
	action_hb.add_child(view_btn)

	_ui_cards[id] = {
		"status_badge": status_badge,
		"cond_lbl": cond_lbl,
		"cost_lbl": cost_lbl,
		"progress_bar": pb,
		"prog_lbl": prog_lbl,
		"action_btn": action_btn,
		"view_btn": view_btn
	}

	return card

func refresh_ui() -> void:
	if not is_inside_tree() or _ui_cards.is_empty():
		return

	var acad_power: int = CityStats.get_academic_power()
	if acad_power == 0 and sim != null and sim.academic > 0:
		acad_power = sim.academic

	var rate: float = UigweManager.get_turn_progress_rate(acad_power)
	var annual_cost: int = UigweManager.get_annual_cost("", sim)
	var turn_cost: int = UigweManager.get_turn_cost("", sim)

	for id: String in ["wonhaeng", "seongyeok"]:
		if not _ui_cards.has(id):
			continue
		var widgets: Dictionary = _ui_cards[id]
		var cur_p: float = 0.0
		var status: int = UigweManager.UigweStatus.INACTIVE

		if uigwe_mgr != null:
			cur_p = float(uigwe_mgr.progress_dict.get(id, 0.0))
			status = int(uigwe_mgr.status_dict.get(id, UigweManager.UigweStatus.INACTIVE))

		# 선행 조건 검사
		var prereq: Dictionary = {"satisfied": true, "reason": ""}
		if uigwe_mgr != null:
			prereq = uigwe_mgr.check_prerequisites(id, court, sim)

		var sb: Label = widgets["status_badge"]
		var cl: Label = widgets["cond_lbl"]
		var cstl: Label = widgets["cost_lbl"]
		var pb: ProgressBar = widgets["progress_bar"]
		var pl: Label = widgets["prog_lbl"]
		var ab: Button = widgets["action_btn"]
		var vb: Button = widgets["view_btn"]

		pb.value = cur_p

		# 조건 만족 여부 텍스트
		if bool(prereq.get("satisfied", false)):
			cl.add_theme_color_override("font_color", Color("1b5e20")) # 녹색
		else:
			cl.add_theme_color_override("font_color", Color("b71c1c")) # 적색
			if str(prereq.get("reason", "")) != "":
				cl.text = "• 조건: %s (※ %s)" % [str(UigweManager.UIGWE_DATA[id]["condition_desc"]), str(prereq.get("reason"))]

		# 예상 소요 연도
		var rem_turns: int = UigweManager.get_estimated_turns_remaining(cur_p, acad_power)
		var rem_years: float = float(rem_turns) / 12.0
		cstl.text = "• 비용: 연간 %s냥 (달마다 약 %s냥) | 예상 소요: 약 %.1f년 (%d개월, 학문력 %d점)" % [
			_fmt_num(annual_cost), _fmt_num(turn_cost), rem_years, rem_turns, acad_power
		]

		pl.text = "%.1f%% (매달 +%.2f%%)" % [cur_p, rate]

		# 상태별 버튼 및 뱃지 분기
		match status:
			UigweManager.UigweStatus.INACTIVE:
				sb.text = "[ 미착수 ]"
				sb.add_theme_color_override("font_color", Color("5c493a"))
				ab.text = "편찬 시작"
				ab.visible = true
				ab.disabled = not bool(prereq.get("satisfied", false))
				vb.visible = false
			UigweManager.UigweStatus.COMPILING:
				sb.text = "[ 편찬 진행 중 ]"
				sb.add_theme_color_override("font_color", Color("1b5e20"))
				ab.text = "일시 중지"
				ab.visible = true
				ab.disabled = false
				vb.visible = false
			UigweManager.UigweStatus.PAUSED:
				sb.text = "[ 일시 정지 (재정/대기) ]"
				sb.add_theme_color_override("font_color", Color("b71c1c"))
				ab.text = "편찬 재개"
				ab.visible = true
				ab.disabled = not bool(prereq.get("satisfied", false))
				vb.visible = false
			UigweManager.UigweStatus.COMPLETED:
				sb.text = "[ 편찬 완료 🏆 ]"
				sb.add_theme_color_override("font_color", Color("854d0e"))
				pl.text = "100.0% (간행 완료)"
				ab.visible = false
				vb.visible = true

func _on_action_button_pressed(id: String) -> void:
	if uigwe_mgr == null:
		return

	var status: int = int(uigwe_mgr.status_dict.get(id, UigweManager.UigweStatus.INACTIVE))
	var _res: Dictionary = {}
	match status:
		UigweManager.UigweStatus.INACTIVE:
			_res = uigwe_mgr.start_compilation(id, sim, court)
		UigweManager.UigweStatus.COMPILING:
			_res = uigwe_mgr.pause_compilation(id)
		UigweManager.UigweStatus.PAUSED:
			_res = uigwe_mgr.resume_compilation(id, sim)

	refresh_ui()

func _on_view_button_pressed(id: String) -> void:
	if viewer_modal != null:
		viewer_modal.open_viewer(id)

func _on_status_changed(_id: String) -> void:
	refresh_ui()

func _on_status_paused(_id: String, _reason: String) -> void:
	refresh_ui()

func _on_progress_updated(_id: String, _progress: float) -> void:
	refresh_ui()

func open_popup() -> void:
	refresh_ui()
	visible = true
	if _overlay != null:
		_overlay.modulate.a = 0.0
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		tw.tween_property(_overlay, "modulate:a", 1.0, 0.2)
		if _main_panel != null:
			_main_panel.scale = Vector2(0.95, 0.95)
			_main_panel.pivot_offset = _main_panel.size * 0.5
			tw.tween_property(_main_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close_popup() -> void:
	var tw: Tween = create_tween()
	if _overlay != null:
		tw.tween_property(_overlay, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		visible = false
		emit_signal("closed")
	)

func _fmt_num(n: int) -> String:
	var s: String = str(n)
	var res: String = ""
	var cnt: int = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			res = "," + res
	return res

func _create_divider(thickness: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, thickness + 4)
	var line := ColorRect.new()
	line.color = Color("382e26")
	line.custom_minimum_size = Vector2(0, thickness)
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(line)
	return c

func _style_close_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("4a3b32")
	sb.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", Color("fdfbf7"))

func _style_button(btn: Button, bg_col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = Color("382e26")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", Color("fdfbf7"))
	ThemeManager.apply_title_font(btn, 13)

func _style_view_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("92400e") # 우아한 비단 금빛/적갈색
	sb.border_color = Color("f59e0b")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", Color("fef3c7"))
	ThemeManager.apply_title_font(btn, 14)
