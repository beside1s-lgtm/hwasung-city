extends CanvasLayer
class_name AcademyQuizPopup

## [수원향교·서원·서당 학문 강독 퀴즈 대화 모달]
## 1. 아바타가 말하는 김판관 스타일 대화형 UI
## 2. 3문제 순차 출제 및 화자별 고유 어투 적용
## 3. 정답/오답 즉시 피드백 및 결과에 따른 학문력 가산/감점 반영

static var instance: AcademyQuizPopup = null

signal quiz_finished(facility_type: String, score_delta: int)

var _backdrop: ColorRect
var _panel: PanelContainer
var _portrait_rect: TextureRect
var _speaker_name_lbl: Label
var _title_lbl: Label
var _speech_bubble_lbl: Label
var _q_num_lbl: Label
var _q_text_lbl: Label
var _options_vbox: VBoxContainer
var _feedback_panel: PanelContainer
var _feedback_lbl: Label
var _next_btn: Button
var _result_vbox: VBoxContainer
var _result_score_lbl: Label
var _result_academic_lbl: Label
var _result_comment_lbl: Label
var _result_close_btn: Button
var _quiz_vbox: VBoxContainer

var current_facility: String = "hyanggyo"
var current_year: int = 1789
var questions: Array[Dictionary] = []
var current_q_idx: int = 0
var correct_count: int = 0
var is_answered: bool = false
var sim_ref: SimulationCore = null

func _init() -> void:
	instance = self
	layer = 95 # InspectPopup(85)보다 상위 레이어

func _ready() -> void:
	instance = self
	_build_ui()
	visible = false

static func open_quiz(facility: String, year: int, sim: SimulationCore = null) -> void:
	if instance == null:
		return
	instance.sim_ref = sim
	instance.start_session(facility, year)

func _build_ui() -> void:
	# 1. 반투명 배경 딤
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	add_child(_backdrop)

	# 2. 중앙 정렬 컨테이너 (규칙 55 준수)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# 3. 메인 한지 패널
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(720, 480)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fffdf5")          # 고풍스러운 한지 크림색
	sb.border_color = Color("7a5835")      # 고목 목재 테두리
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 12
	sb.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_panel)

	# 메인 세로 박스
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(main_vbox)

	# 상단 행: 타이틀 + 닫기 버튼
	var top_row := HBoxContainer.new()
	main_vbox.add_child(top_row)

	_title_lbl = Label.new()
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.add_theme_font_size_override("font_size", 18)
	_title_lbl.add_theme_color_override("font_color", Color("8f1d1d"))
	top_row.add_child(_title_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.add_theme_color_override("font_color", Color("7a5835"))
	close_btn.pressed.connect(close_quiz)
	top_row.add_child(close_btn)

	var sep := HSeparator.new()
	var sep_sb := StyleBoxLine.new()
	sep_sb.color = Color("c9b28b")
	sep_sb.thickness = 2
	sep.add_theme_stylebox_override("separator", sep_sb)
	main_vbox.add_child(sep)

	# 중앙 가로 박스 (좌: 아바타 및 화자명 / 우: 말풍선 및 퀴즈 본문)
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(body_hbox)

	# [좌측] 아바타 영역
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(160, 0)
	left_vbox.add_theme_constant_override("separation", 8)
	body_hbox.add_child(left_vbox)

	var p_frame := PanelContainer.new()
	var p_sb := StyleBoxFlat.new()
	p_sb.bg_color = Color("f7f3e8")
	p_sb.border_color = Color("b39268")
	p_sb.set_border_width_all(2)
	p_sb.set_corner_radius_all(8)
	p_sb.set_content_margin_all(4)
	p_frame.add_theme_stylebox_override("panel", p_sb)
	left_vbox.add_child(p_frame)

	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(150, 150)
	_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p_frame.add_child(_portrait_rect)

	_speaker_name_lbl = Label.new()
	_speaker_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker_name_lbl.add_theme_font_size_override("font_size", 14)
	_speaker_name_lbl.add_theme_color_override("font_color", Color("5c3a21"))
	left_vbox.add_child(_speaker_name_lbl)

	# [우측] 말풍선 + 퀴즈 컨텐츠 영역
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 10)
	body_hbox.add_child(right_vbox)

	# 1. 화자 말풍선 패널
	var bubble_p := PanelContainer.new()
	var b_sb := StyleBoxFlat.new()
	b_sb.bg_color = Color("fef9e7")
	b_sb.border_color = Color("d4af37")
	b_sb.set_border_width_all(2)
	b_sb.set_corner_radius_all(8)
	b_sb.set_content_margin_all(10)
	bubble_p.add_theme_stylebox_override("panel", b_sb)
	right_vbox.add_child(bubble_p)

	_speech_bubble_lbl = Label.new()
	_speech_bubble_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech_bubble_lbl.add_theme_font_size_override("font_size", 14)
	_speech_bubble_lbl.add_theme_color_override("font_color", Color("331a06"))
	_speech_bubble_lbl.add_theme_constant_override("line_spacing", 4)
	bubble_p.add_child(_speech_bubble_lbl)

	# 2. 퀴즈 진행 컨테이너
	_quiz_vbox = VBoxContainer.new()
	_quiz_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_quiz_vbox.add_theme_constant_override("separation", 8)
	right_vbox.add_child(_quiz_vbox)

	_q_num_lbl = Label.new()
	_q_num_lbl.add_theme_font_size_override("font_size", 13)
	_q_num_lbl.add_theme_color_override("font_color", Color("8f1d1d"))
	_quiz_vbox.add_child(_q_num_lbl)

	_q_text_lbl = Label.new()
	_q_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_q_text_lbl.add_theme_font_size_override("font_size", 15)
	_q_text_lbl.add_theme_color_override("font_color", Color("1a1410"))
	_q_text_lbl.add_theme_constant_override("line_spacing", 4)
	_quiz_vbox.add_child(_q_text_lbl)

	# 보기 버튼들
	_options_vbox = VBoxContainer.new()
	_options_vbox.add_theme_constant_override("separation", 6)
	_quiz_vbox.add_child(_options_vbox)

	for i in range(4):
		var opt_btn := Button.new()
		opt_btn.custom_minimum_size = Vector2(0, 32)
		opt_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		opt_btn.add_theme_font_size_override("font_size", 13)
		opt_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var o_sb := StyleBoxFlat.new()
		o_sb.bg_color = Color("ffffff")
		o_sb.border_color = Color("c9b28b")
		o_sb.set_border_width_all(1)
		o_sb.set_corner_radius_all(6)
		o_sb.set_content_margin_all(8)
		opt_btn.add_theme_stylebox_override("normal", o_sb)

		var o_hov := o_sb.duplicate() as StyleBoxFlat
		o_hov.bg_color = Color("f7ecd5")
		o_hov.border_color = Color("8f1d1d")
		opt_btn.add_theme_stylebox_override("hover", o_hov)
		opt_btn.add_theme_color_override("font_color", Color("2c1a0e"))
		opt_btn.add_theme_color_override("font_hover_color", Color("8f1d1d"))

		var btn_idx: int = i
		opt_btn.pressed.connect(func(): _on_option_selected(btn_idx))
		_options_vbox.add_child(opt_btn)

	# 피드백 패널 및 다음 버튼
	_feedback_panel = PanelContainer.new()
	var fb_sb := StyleBoxFlat.new()
	fb_sb.bg_color = Color("f4efe2")
	fb_sb.border_color = Color("b39268")
	fb_sb.set_border_width_all(1)
	fb_sb.set_corner_radius_all(6)
	fb_sb.set_content_margin_all(8)
	_feedback_panel.add_theme_stylebox_override("panel", fb_sb)
	_quiz_vbox.add_child(_feedback_panel)

	var fb_hbox := HBoxContainer.new()
	_feedback_panel.add_child(fb_hbox)

	_feedback_lbl = Label.new()
	_feedback_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feedback_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_lbl.add_theme_font_size_override("font_size", 13)
	fb_hbox.add_child(_feedback_lbl)

	_next_btn = Button.new()
	_next_btn.text = "다음 문제 ▶"
	_next_btn.custom_minimum_size = Vector2(100, 32)
	_next_btn.add_theme_font_size_override("font_size", 13)
	_next_btn.pressed.connect(_on_next_pressed)
	var nb_sb := StyleBoxFlat.new()
	nb_sb.bg_color = Color("8f1d1d")
	nb_sb.border_color = Color("5c1010")
	nb_sb.set_border_width_all(1)
	nb_sb.set_corner_radius_all(6)
	nb_sb.set_content_margin_all(6)
	_next_btn.add_theme_stylebox_override("normal", nb_sb)
	_next_btn.add_theme_color_override("font_color", Color("ffffff"))
	fb_hbox.add_child(_next_btn)

	# 3. 최종 결과 화면 컨테이너 (퀴즈 종료 시 활성화)
	_result_vbox = VBoxContainer.new()
	_result_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_vbox.add_theme_constant_override("separation", 16)
	_result_vbox.visible = false
	right_vbox.add_child(_result_vbox)

	_result_score_lbl = Label.new()
	_result_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_score_lbl.add_theme_font_size_override("font_size", 22)
	_result_score_lbl.add_theme_color_override("font_color", Color("8f1d1d"))
	_result_vbox.add_child(_result_score_lbl)

	_result_academic_lbl = Label.new()
	_result_academic_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_academic_lbl.add_theme_font_size_override("font_size", 18)
	_result_academic_lbl.add_theme_color_override("font_color", Color("2e5a2e"))
	_result_vbox.add_child(_result_academic_lbl)

	_result_comment_lbl = Label.new()
	_result_comment_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_comment_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_comment_lbl.add_theme_font_size_override("font_size", 14)
	_result_comment_lbl.add_theme_color_override("font_color", Color("331a06"))
	_result_vbox.add_child(_result_comment_lbl)

	var btm_box := HBoxContainer.new()
	btm_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_vbox.add_child(btm_box)

	_result_close_btn = Button.new()
	_result_close_btn.text = "학문 강독 마치기 (확인)"
	_result_close_btn.custom_minimum_size = Vector2(180, 36)
	_result_close_btn.add_theme_font_size_override("font_size", 14)
	_result_close_btn.add_theme_stylebox_override("normal", nb_sb)
	_result_close_btn.add_theme_color_override("font_color", Color("ffffff"))
	_result_close_btn.pressed.connect(close_quiz)
	btm_box.add_child(_result_close_btn)

## 세션 시작
func start_session(facility: String, year: int) -> void:
	current_facility = facility
	current_year = year
	current_q_idx = 0
	correct_count = 0
	is_answered = false

	var qm: AcademyQuizManager = AcademyQuizManager.get_instance()
	questions = qm.generate_quiz_session(facility)
	if questions.is_empty():
		return

	var fac_info: Dictionary = AcademyQuizManager.QUIZ_DATA.get(facility, {})
	_title_lbl.text = str(fac_info.get("title", "학문 강독 시험"))
	_speaker_name_lbl.text = "%s\n(%s)" % [str(fac_info.get("speaker_name", "")), str(fac_info.get("speaker_title", ""))]

	var p_key: String = str(fac_info.get("portrait_key", "scholar"))
	var tex: Texture2D = InspectNarrativeGenerator.get_portrait(p_key)
	if tex:
		_portrait_rect.texture = tex
	else:
		_portrait_rect.texture = InspectNarrativeGenerator.get_portrait("scholar")

	_speech_bubble_lbl.text = str(fac_info.get("speech_greeting", ""))
	_quiz_vbox.visible = true
	_result_vbox.visible = false
	_feedback_panel.visible = false

	_show_question(0)
	visible = true

func _show_question(idx: int) -> void:
	current_q_idx = idx
	is_answered = false
	_feedback_panel.visible = false

	if idx >= questions.size():
		_show_results()
		return

	var q_data: Dictionary = questions[idx]
	_q_num_lbl.text = "제 %d 문 (총 3문)" % (idx + 1)
	_q_text_lbl.text = str(q_data.get("q", ""))

	var opts: Array = q_data.get("options", [])
	var btn_children: Array = _options_vbox.get_children()
	for i in range(btn_children.size()):
		var b: Button = btn_children[i] as Button
		if i < opts.size():
			b.text = "%d) %s" % [i + 1, str(opts[i])]
			b.visible = true
			b.disabled = false
			# 스타일 초기화
			var o_sb := StyleBoxFlat.new()
			o_sb.bg_color = Color("ffffff")
			o_sb.border_color = Color("c9b28b")
			o_sb.set_border_width_all(1)
			o_sb.set_corner_radius_all(6)
			o_sb.set_content_margin_all(8)
			b.add_theme_stylebox_override("normal", o_sb)
			b.add_theme_color_override("font_color", Color("2c1a0e"))
		else:
			b.visible = false

func _on_option_selected(opt_idx: int) -> void:
	if is_answered or current_q_idx >= questions.size():
		return
	is_answered = true

	var q_data: Dictionary = questions[current_q_idx]
	var correct_ans: int = int(q_data.get("answer", 0))
	var is_correct: bool = (opt_idx == correct_ans)

	if is_correct:
		correct_count += 1

	var fac_info: Dictionary = AcademyQuizManager.QUIZ_DATA.get(current_facility, {})
	var btn_children: Array = _options_vbox.get_children()

	for i in range(btn_children.size()):
		var b: Button = btn_children[i] as Button
		b.disabled = true
		if i == correct_ans:
			var cr_sb := StyleBoxFlat.new()
			cr_sb.bg_color = Color("e6f4ea") # 정답 초록빛
			cr_sb.border_color = Color("1e8e3e")
			cr_sb.set_border_width_all(2)
			cr_sb.set_corner_radius_all(6)
			cr_sb.set_content_margin_all(8)
			b.add_theme_stylebox_override("normal", cr_sb)
			b.add_theme_color_override("font_color", Color("137333"))
		elif i == opt_idx and not is_correct:
			var wr_sb := StyleBoxFlat.new()
			wr_sb.bg_color = Color("fce8e6") # 오답 붉은빛
			wr_sb.border_color = Color("d93025")
			wr_sb.set_border_width_all(2)
			wr_sb.set_corner_radius_all(6)
			wr_sb.set_content_margin_all(8)
			b.add_theme_stylebox_override("normal", wr_sb)
			b.add_theme_color_override("font_color", Color("c5221f"))

	# 말풍선 대사 갱신
	if is_correct:
		_speech_bubble_lbl.text = str(fac_info.get("speech_correct", "정답이오!"))
		_feedback_lbl.text = "✓ 정답입니다! " + str(q_data.get("explanation", ""))
		_feedback_lbl.add_theme_color_override("font_color", Color("137333"))
	else:
		_speech_bubble_lbl.text = str(fac_info.get("speech_wrong", "틀렸소!"))
		var opts: Array = q_data.get("options", [])
		var ans_str: String = str(opts[correct_ans]) if correct_ans < opts.size() else ""
		_feedback_lbl.text = "✕ 오답입니다! (정답: %s)\n%s" % [ans_str, str(q_data.get("explanation", ""))]
		_feedback_lbl.add_theme_color_override("font_color", Color("c5221f"))

	_next_btn.text = "결과 확인 ▶" if current_q_idx == 2 else "다음 문제 ▶"
	_feedback_panel.visible = true

func _on_next_pressed() -> void:
	if current_q_idx + 1 < questions.size():
		_show_question(current_q_idx + 1)
	else:
		_show_results()

func _show_results() -> void:
	_quiz_vbox.visible = false
	_result_vbox.visible = true

	var qm: AcademyQuizManager = AcademyQuizManager.get_instance()
	qm.record_quiz_completed(current_facility, current_year)
	var delta: int = qm.calculate_score_delta(correct_count)

	# 실제 학문력 반영!
	CityStats.add_academic_power(delta)
	if sim_ref != null:
		sim_ref.academic = CityStats.get_academic_power()

	var fac_info: Dictionary = AcademyQuizManager.QUIZ_DATA.get(current_facility, {})
	var res_dict: Dictionary = fac_info.get("results", {})
	var comment_txt: String = str(res_dict.get(correct_count, ""))

	_result_score_lbl.text = "시험 결과: 3문제 중 %d문제 정답!" % correct_count

	if delta > 0:
		_result_academic_lbl.text = "도시 학문력 +%d점 가산!" % delta
		_result_academic_lbl.add_theme_color_override("font_color", Color("137333"))
	elif delta == 0:
		_result_academic_lbl.text = "도시 학문력 변동 없음 (0점)"
		_result_academic_lbl.add_theme_color_override("font_color", Color("5c3a21"))
	else:
		_result_academic_lbl.text = "도시 학문력 %d점 감점!" % delta
		_result_academic_lbl.add_theme_color_override("font_color", Color("c5221f"))

	_result_comment_lbl.text = comment_txt
	_speech_bubble_lbl.text = comment_txt

	emit_signal("quiz_finished", current_facility, delta)

func close_quiz() -> void:
	visible = false
