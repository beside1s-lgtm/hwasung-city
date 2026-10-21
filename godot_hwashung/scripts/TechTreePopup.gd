extends CanvasLayer
class_name TechTreePopup

## [실학 연구 학문력·버프 UI 및 턴당 지속 국고 소모 프로젝트 모달]
## - 도시 총 학문력(0~100점), 턴당 진척도(+N%), 턴당 소모 국고, 인재 버프 대시보드
## - 과제별 4단 상태 분기: 미연구(인재잠금), 미연구(착수가능), 연구진행중(게이지/잔여턴), 완료
## - 재정 부족(PAUSED_NO_FUNDS) 및 인재 공백(PAUSED_NO_SCHOLAR) 안전 일시정지 FSM 연출

signal closed

var sim: SimulationCore
var court: CourtSystem

@onready var dim_background: ColorRect = $DimBackground
@onready var main_panel: PanelContainer = $CenterContainer/MainPanel
@onready var title_label: Label = $CenterContainer/MainPanel/MarginContainer/VBox/TitleBar/TitleLabel
@onready var close_btn_top: Button = $CenterContainer/MainPanel/MarginContainer/VBox/TitleBar/CloseButtonTop
@onready var academic_label: Label = $CenterContainer/MainPanel/MarginContainer/VBox/Dashboard/DashVBox/StatHBox/AcademicLabel
@onready var speed_label: Label = $CenterContainer/MainPanel/MarginContainer/VBox/Dashboard/DashVBox/StatHBox/SpeedLabel
@onready var turn_cost_label: Label = $CenterContainer/MainPanel/MarginContainer/VBox/Dashboard/DashVBox/StatHBox/TurnCostLabel
@onready var buff_label: Label = $CenterContainer/MainPanel/MarginContainer/VBox/Dashboard/DashVBox/BuffLabel

@onready var tech_list_container: VBoxContainer = $CenterContainer/MainPanel/MarginContainer/VBox/Scroll/TechList
@onready var close_btn_bottom: Button = $CenterContainer/MainPanel/MarginContainer/VBox/Footer/CloseButtonBottom

var _is_open: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 130
	visible = false

	if close_btn_top != null:
		close_btn_top.pressed.connect(close_popup)
	if close_btn_bottom != null:
		close_btn_bottom.pressed.connect(close_popup)
	if dim_background != null:
		dim_background.gui_input.connect(_on_dim_gui_input)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			close_popup()
			get_viewport().set_input_as_handled()

func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_popup()

func setup(s: SimulationCore, c: CourtSystem = null) -> void:
	sim = s
	court = c

	if sim != null:
		if not sim.state_updated.is_connected(_on_sim_state_updated):
			sim.state_updated.connect(_on_sim_state_updated)
		if not sim.turn_advanced.is_connected(_on_sim_turn_advanced):
			sim.turn_advanced.connect(_on_sim_turn_advanced)

		var tech_mgr: TechTreeManager = sim.tech_tree
		if tech_mgr != null:
			if not tech_mgr.research_started.is_connected(_on_research_started):
				tech_mgr.research_started.connect(_on_research_started)
			if not tech_mgr.research_progress_updated.is_connected(_on_research_progress_updated):
				tech_mgr.research_progress_updated.connect(_on_research_progress_updated)
			if not tech_mgr.research_completed.is_connected(_on_research_completed):
				tech_mgr.research_completed.connect(_on_research_completed)
			if not tech_mgr.research_status_changed.is_connected(_on_research_status_changed):
				tech_mgr.research_status_changed.connect(_on_research_status_changed)
			if not tech_mgr.research_paused.is_connected(_on_research_paused):
				tech_mgr.research_paused.connect(_on_research_paused)

func open_popup() -> void:
	visible = true
	_is_open = true
	refresh_ui()

func close_popup() -> void:
	visible = false
	_is_open = false
	emit_signal("closed")

func _on_sim_state_updated(_g: int, _r: int, _p: int, _l: int, _f: int) -> void:
	if visible and _is_open:
		refresh_ui()

func _on_sim_turn_advanced(_turn: int, _season: int, _year: int) -> void:
	if visible and _is_open:
		refresh_ui()

func _on_research_started(_id: String) -> void:
	if visible and _is_open:
		refresh_ui()

func _on_research_progress_updated(_id: String, _progress: float) -> void:
	if visible and _is_open:
		refresh_ui()

func _on_research_completed(_id: String) -> void:
	if visible and _is_open:
		refresh_ui()

func _on_research_status_changed(_id: String, _status: int) -> void:
	if visible and _is_open:
		refresh_ui()

func _on_research_paused(_id: String, _reason: String) -> void:
	if visible and _is_open:
		refresh_ui()

## 대시보드 및 전체 과제 항목 실시간 갱신
func refresh_ui() -> void:
	if tech_list_container == null:
		return

	var tech_mgr: TechTreeManager = sim.tech_tree if sim != null else null
	var acad_power: int = CityStats.get_academic_power()
	if acad_power == 0 and sim != null and sim.academic > 0:
		acad_power = sim.academic

	var research_speed: int = 1 + clampi(int(float(acad_power) / 10.0), 0, 9)

	var is_jeong_hired: bool = false
	if sim != null and "retainers" in sim and sim.retainers is Dictionary:
		is_jeong_hired = ScholarManager.has_scholar("jeong_yakyong", sim.retainers)

	var cur_id: String = tech_mgr.current_researching if tech_mgr != null else ""
	var cur_status: int = tech_mgr.research_status if tech_mgr != null else TechTreeManager.ResearchStatus.IDLE

	var ongoing_cost: int = 0
	if cur_id != "" and tech_mgr != null:
		if cur_status == TechTreeManager.ResearchStatus.ACTIVE:
			ongoing_cost = tech_mgr.get_research_turn_cost(cur_id, sim)

	# 1. 상단 대시보드 라벨 갱신
	if academic_label != null:
		academic_label.text = "🏛️ 도시 총 학문력: %d / 100" % acad_power
	if speed_label != null:
		speed_label.text = "⚡ 연구 속도: 매달 +%d%%" % research_speed
	if turn_cost_label != null:
		if ongoing_cost > 0:
			turn_cost_label.text = "💰 연구 재정: 매달 -%d냥" % ongoing_cost
			turn_cost_label.add_theme_color_override("font_color", Color("b91c1c"))
		elif cur_status == TechTreeManager.ResearchStatus.PAUSED_NO_FUNDS:
			turn_cost_label.text = "💰 연구 재정: 재정 부족 일시 정지"
			turn_cost_label.add_theme_color_override("font_color", Color("ea580c"))
		elif cur_status == TechTreeManager.ResearchStatus.PAUSED_NO_SCHOLAR:
			turn_cost_label.text = "💰 연구 재정: 인재 공백 일시 정지"
			turn_cost_label.add_theme_color_override("font_color", Color("ea580c"))
		else:
			turn_cost_label.text = "💰 연구 재정: 매달 0냥 (미진행)"
			turn_cost_label.add_theme_color_override("font_color", Color("4b5563"))

	if buff_label != null:
		if is_jeong_hired:
			buff_label.text = "✨ [적용 효과: 다산 정약용 — 연구비 30% 감면 적용 중 -> 매달 700냥]"
			buff_label.add_theme_color_override("font_color", Color("15803d"))
		else:
			buff_label.text = "📜 [적용 효과: 없음 — 기본 연구비 매달 1,000냥 소모]"
			buff_label.add_theme_color_override("font_color", Color("6b7280"))

	# 2. 과제 목록 VBox 갱신
	for child in tech_list_container.get_children():
		child.queue_free()

	for tech: Dictionary in TechTreeManager.TECH_LIST:
		var tid: String = str(tech.get("id", ""))
		var tname: String = str(tech.get("name", ""))
		var tdesc: String = str(tech.get("desc", ""))
		var req_sch_id: String = str(tech.get("required_scholar_id", ""))
		var req_sch_name: String = str(tech.get("required_scholar_name", ""))

		var is_done: bool = tech_mgr.is_completed(tid) if tech_mgr != null else false
		var is_active: bool = (cur_id == tid)
		var progress_val: float = tech_mgr.get_progress(tid) if tech_mgr != null else 0.0

		var prereq_sat: bool = true
		if req_sch_id != "":
			if sim != null and "retainers" in sim and sim.retainers is Dictionary:
				prereq_sat = ScholarManager.has_scholar(req_sch_id, sim.retainers)
			else:
				prereq_sat = false

		var item_panel := PanelContainer.new()
		var p_style := StyleBoxFlat.new()
		p_style.set_corner_radius_all(6)
		p_style.set_content_margin_all(10)

		if is_done:
			p_style.bg_color = Color(0.93, 0.96, 0.93, 0.95)
			p_style.border_color = Color("15803d")
			p_style.set_border_width_all(1)
		elif is_active:
			if cur_status == TechTreeManager.ResearchStatus.PAUSED_NO_FUNDS or cur_status == TechTreeManager.ResearchStatus.PAUSED_NO_SCHOLAR:
				p_style.bg_color = Color(0.99, 0.93, 0.90, 0.95)
				p_style.border_color = Color("ea580c")
				p_style.set_border_width_all(2)
			else:
				p_style.bg_color = Color(0.92, 0.96, 0.98, 0.95)
				p_style.border_color = Color("0284c7")
				p_style.set_border_width_all(2)
		else:
			p_style.bg_color = Color(0.98, 0.97, 0.94, 0.95)
			p_style.border_color = Color(0.82, 0.79, 0.72, 1.0)
			p_style.set_border_width_all(1)

		item_panel.add_theme_stylebox_override("panel", p_style)
		tech_list_container.add_child(item_panel)

		var main_vbox := VBoxContainer.new()
		main_vbox.add_theme_constant_override("separation", 6)
		item_panel.add_child(main_vbox)

		# 상단 헤더 행 (이름 + 우측 버튼/배지)
		var top_hbox := HBoxContainer.new()
		top_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		main_vbox.add_child(top_hbox)

		var name_lbl := Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		if is_done:
			name_lbl.text = "[완료] " + tname
			name_lbl.add_theme_color_override("font_color", Color("15803d"))
		elif is_active:
			name_lbl.text = "[연구 중] " + tname
			name_lbl.add_theme_color_override("font_color", Color("0369a1"))
		else:
			name_lbl.text = "[미연구] " + tname
			name_lbl.add_theme_color_override("font_color", Color("1f2937"))

		top_hbox.add_child(name_lbl)

		# 우측 버튼 또는 완료 배지
		if is_done:
			var done_badge := Button.new()
			done_badge.text = "완료됨"
			done_badge.disabled = true
			done_badge.custom_minimum_size = Vector2(110, 32)
			top_hbox.add_child(done_badge)
		elif is_active:
			var stop_btn := Button.new()
			stop_btn.text = "연구 중단"
			stop_btn.custom_minimum_size = Vector2(110, 32)
			stop_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			stop_btn.pressed.connect(func():
				if tech_mgr != null:
					tech_mgr.stop_research(tid)
					refresh_ui()
			)
			top_hbox.add_child(stop_btn)
		else:
			# 미연구 상태
			var start_btn := Button.new()
			start_btn.custom_minimum_size = Vector2(140, 32)
			if not prereq_sat:
				start_btn.text = "[🔒 %s 필요]" % req_sch_name
				start_btn.disabled = true
				start_btn.tooltip_text = "조정에서 [%s]을(를) 등용해야 연구에 착수할 수 있습니다." % req_sch_name
			else:
				var cost_preview: int = 700 if is_jeong_hired else 1000
				start_btn.text = "연구 착수 (매달 %d냥)" % cost_preview
				start_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				start_btn.pressed.connect(func():
					if tech_mgr != null and sim != null:
						tech_mgr.start_research(tid, sim)
						refresh_ui()
				)
			top_hbox.add_child(start_btn)

		# 설명 텍스트
		var desc_lbl := Label.new()
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_color_override("font_color", Color("4b5563"))

		if not is_done and not prereq_sat:
			desc_lbl.text = "필수 인재: %s 필요 | %s" % [req_sch_name, tdesc]
		else:
			desc_lbl.text = tdesc
		main_vbox.add_child(desc_lbl)

		# 진행 중이거나 부분 진행도가 있는 경우 프로그레스 바 표시
		if is_active or (progress_val > 0.0 and not is_done):
			var pb_container := VBoxContainer.new()
			pb_container.add_theme_constant_override("separation", 3)
			main_vbox.add_child(pb_container)

			var prog_bar := ProgressBar.new()
			prog_bar.min_value = 0.0
			prog_bar.max_value = 100.0
			prog_bar.value = progress_val
			prog_bar.custom_minimum_size = Vector2(0, 20)
			prog_bar.show_percentage = false

			var p_fill := StyleBoxFlat.new()
			p_fill.set_corner_radius_all(3)

			var is_paused_funds: bool = (is_active and cur_status == TechTreeManager.ResearchStatus.PAUSED_NO_FUNDS)
			var is_paused_scholar: bool = (is_active and cur_status == TechTreeManager.ResearchStatus.PAUSED_NO_SCHOLAR)

			if is_paused_funds or is_paused_scholar:
				p_fill.bg_color = Color("ea580c")
			else:
				p_fill.bg_color = Color("0284c7")

			prog_bar.add_theme_stylebox_override("fill", p_fill)
			pb_container.add_child(prog_bar)

			var status_info_hbox := HBoxContainer.new()
			pb_container.add_child(status_info_hbox)

			var p_text := Label.new()
			p_text.text = "%d%% (매달 +%d%%)" % [int(progress_val), research_speed]
			p_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			p_text.add_theme_color_override("font_color", Color("1e293b"))
			status_info_hbox.add_child(p_text)

			var eta_turns: int = int(ceil(float(100.0 - progress_val) / float(maxi(1, research_speed))))
			var eta_lbl := Label.new()
			var cost_display: int = 700 if is_jeong_hired else 1000
			eta_lbl.text = "비용: 매달 %d냥 소모 중 | 잔여 예상 시간: 약 %d개월" % [cost_display, eta_turns]
			eta_lbl.add_theme_color_override("font_color", Color("475569"))
			status_info_hbox.add_child(eta_lbl)

			# 일시 정지 경고 라벨
			if is_paused_funds:
				var warn_lbl := Label.new()
				warn_lbl.text = "⚠️ [재정 부족으로 연구 일시 정지 (매달 %d냥 필요)]" % cost_display
				warn_lbl.add_theme_color_override("font_color", Color("dc2626"))
				main_vbox.add_child(warn_lbl)
			elif is_paused_scholar:
				var warn_sch_lbl := Label.new()
				warn_sch_lbl.text = "⚠️ [필수 인재(%s) 공백으로 연구 정체 (인재 재등용 필요)]" % req_sch_name
				warn_sch_lbl.add_theme_color_override("font_color", Color("ea580c"))
				main_vbox.add_child(warn_sch_lbl)
