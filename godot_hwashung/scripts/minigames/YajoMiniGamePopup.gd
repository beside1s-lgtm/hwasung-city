extends Control
class_name YajoMiniGamePopup

## [서장대 야조 훈련 미니게임: 신호 전달 디펜스 모달]
## - 밤하늘의 서장대와 사방(장안문, 팔달문, 화서문, 창룡문) 신호 조련
## - 총 10웨이브, 5.0초 -> 1.0초 선형 단축
## - 방향키(↑↓←→)로 방향 조준 + Q/W/E/R로 일치하는 색상 신호탄 발사
## - 성공 횟수(0~10회)에 따라 -20% ~ +20% (0.80x ~ 1.20x) 최종 훈련 효과 정산
## - 입력 격리: _input에서 get_viewport().set_input_as_handled()로 월드 카메라 조작 차단

signal minigame_completed(final_multiplier: float, success_count: int)

enum Dir { UP = 0, DOWN = 1, LEFT = 2, RIGHT = 3 }
enum SignalColor { RED = 0, BLUE = 1, YELLOW = 2, GREEN = 3 }

const COLOR_MAP: Dictionary = {
	SignalColor.RED: Color("#E63946"),    # Q: 붉은색 (적색)
	SignalColor.BLUE: Color("#2A9D8F"),   # W: 파란색 (청색)
	SignalColor.YELLOW: Color("#E9C46A"), # E: 노란색 (황색)
	SignalColor.GREEN: Color("#4CAF50")   # R: 초록색 (녹색)
}

const DIR_LABELS: Dictionary = {
	Dir.UP: "북: 장안문",
	Dir.DOWN: "남: 팔달문",
	Dir.LEFT: "서: 화서문",
	Dir.RIGHT: "동: 창룡문"
}

const COLOR_NAMES: Dictionary = {
	SignalColor.RED: "붉은색 (Q)",
	SignalColor.BLUE: "파란색 (W)",
	SignalColor.YELLOW: "노란색 (E)",
	SignalColor.GREEN: "초록색 (R)"
}

const MAX_ROUNDS: int = 10

var current_round: int = 0
var success_count: int = 0
var fail_count: int = 0

var target_dir: int = Dir.UP
var target_color: int = SignalColor.RED
var selected_dir: int = Dir.UP

var time_limit: float = 5.0
var time_left: float = 5.0
var is_round_active: bool = false
var feedback_timer: float = 0.0

# 외부 의존성 (일시 정지 제어용)
var time_manager: TimeManager = null
var _saved_speed_mode: int = 1

# UI 컴포넌트 참조
var _backdrop: ColorRect
var _center_container: CenterContainer
var _main_panel: PanelContainer
var _header_round_lbl: Label
var _header_score_lbl: Label
var _center_arena: Control
var _seojangdae_box: PanelContainer
var _aim_indicator_lbl: Label
var _gate_boxes: Dictionary = {} # dir -> PanelContainer
var _target_unit: PanelContainer
var _target_color_badge: ColorRect
var _target_text_lbl: Label
var _timer_bar: ProgressBar
var _timer_lbl: Label
var _feedback_lbl: Label

# 하단 키 매뉴얼 버튼/패널
var _dir_manual_panels: Dictionary = {}
var _color_manual_panels: Dictionary = {}

# 결과 패널
var _result_center: CenterContainer
var _result_panel: PanelContainer
var _result_summary_lbl: Label
var _result_confirm_btn: Button

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _main_panel == null:
		_build_ui()
	call_deferred("_sync_viewport_size")
	if is_inside_tree() and get_viewport():
		if not get_viewport().size_changed.is_connected(_sync_viewport_size):
			get_viewport().size_changed.connect(_sync_viewport_size)
	visible = false
	set_process(false)
	set_process_input(false)

func _sync_viewport_size() -> void:
	if not is_inside_tree() or get_viewport() == null:
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	if vp_size.x > 0.0 and vp_size.y > 0.0:
		set_deferred("size", vp_size)
		if _backdrop != null:
			_backdrop.set_deferred("size", vp_size)
		if _center_container != null:
			_center_container.set_deferred("size", vp_size)
		if _result_center != null:
			_result_center.set_deferred("size", vp_size)

func _build_ui() -> void:
	if _main_panel != null:
		return

	# 1. 화면 전체 어두운 야간 반투명 배경
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.04, 0.06, 0.10, 0.88)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	# 2. 메인 프레임 중앙 정렬용 CenterContainer
	_center_container = CenterContainer.new()
	_center_container.name = "CenterContainer"
	_center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center_container)

	# 3. 메인 프레임 패널 (780 x 560 고정)
	_main_panel = PanelContainer.new()
	_main_panel.name = "MainPanel"
	_main_panel.custom_minimum_size = Vector2(780, 560)
	_main_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var main_sb := StyleBoxFlat.new()
	main_sb.bg_color = Color(0.10, 0.13, 0.18, 0.98) # 고요한 밤색
	main_sb.border_color = Color(0.78, 0.65, 0.40)     # 금박 테두리
	main_sb.set_border_width_all(3)
	main_sb.set_corner_radius_all(10)
	main_sb.shadow_color = Color(0, 0, 0, 0.6)
	main_sb.shadow_size = 14
	main_sb.set_content_margin_all(16)
	_main_panel.add_theme_stylebox_override("panel", main_sb)
	_center_container.add_child(_main_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 10)
	_main_panel.add_child(root_vbox)

	# --- 상단 헤더 ---
	var header_bar := HBoxContainer.new()
	header_bar.custom_minimum_size = Vector2(0, 40)
	root_vbox.add_child(header_bar)

	var title_lbl := Label.new()
	title_lbl.text = "[서장대 야조(夜操) 친림 지휘 — 신호 전달 훈련]"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.65))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_bar.add_child(title_lbl)

	_header_round_lbl = Label.new()
	_header_round_lbl.text = "진행: 1 / 10회"
	_header_round_lbl.add_theme_font_size_override("font_size", 15)
	_header_round_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	header_bar.add_child(_header_round_lbl)

	# 상태 요약 스트립
	_header_score_lbl = Label.new()
	_header_score_lbl.text = "현재 성적: 성공 0회 / 실패 0회 (예상 훈련 효과: 0%)"
	_header_score_lbl.add_theme_font_size_override("font_size", 13)
	_header_score_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	root_vbox.add_child(_header_score_lbl)

	# --- 중앙 아레나 뷰 (사방 성문 + 중앙 서장대) ---
	_center_arena = Control.new()
	_center_arena.custom_minimum_size = Vector2(748, 280)
	_center_arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center_arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_vbox.add_child(_center_arena)

	# 아레나 배경 박스
	var arena_bg := Panel.new()
	arena_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var arena_sb := StyleBoxFlat.new()
	arena_sb.bg_color = Color(0.06, 0.08, 0.12, 0.85)
	arena_sb.border_color = Color(0.25, 0.35, 0.45, 0.6)
	arena_sb.set_border_width_all(2)
	arena_sb.set_corner_radius_all(6)
	arena_bg.add_theme_stylebox_override("panel", arena_sb)
	arena_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_arena.add_child(arena_bg)

	# 4대문 박스 생성 (북/남/서/동)
	_create_gate_boxes()

	# 중앙 서장대 박스
	_create_seojangdae_box()

	# 다가오는 적 표적 노드
	_create_target_unit()

	# 판정 피드백 라벨 (성공/실패 큰 텍스트)
	_feedback_lbl = Label.new()
	_feedback_lbl.set_anchors_preset(Control.PRESET_CENTER)
	_feedback_lbl.offset_left = -220
	_feedback_lbl.offset_top = 40
	_feedback_lbl.offset_right = 220
	_feedback_lbl.offset_bottom = 80
	_feedback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_feedback_lbl.add_theme_font_size_override("font_size", 18)
	_feedback_lbl.visible = false
	_center_arena.add_child(_feedback_lbl)

	# --- 남은 시간 게이지 바 ---
	var timer_hb := HBoxContainer.new()
	timer_hb.custom_minimum_size = Vector2(0, 24)
	timer_hb.add_theme_constant_override("separation", 10)
	root_vbox.add_child(timer_hb)

	var timer_tag := Label.new()
	timer_tag.text = "접근 제한시간:"
	timer_tag.add_theme_font_size_override("font_size", 13)
	timer_tag.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	timer_hb.add_child(timer_tag)

	_timer_bar = ProgressBar.new()
	_timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer_bar.custom_minimum_size = Vector2(0, 20)
	_timer_bar.min_value = 0.0
	_timer_bar.max_value = 5.0
	_timer_bar.value = 5.0
	_timer_bar.show_percentage = false

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.9, 0.35, 0.25)
	bar_fill.set_corner_radius_all(4)
	_timer_bar.add_theme_stylebox_override("fill", bar_fill)

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.18, 0.24)
	bar_bg.set_corner_radius_all(4)
	_timer_bar.add_theme_stylebox_override("background", bar_bg)
	timer_hb.add_child(_timer_bar)

	_timer_lbl = Label.new()
	_timer_lbl.custom_minimum_size = Vector2(60, 0)
	_timer_lbl.text = "5.0초"
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timer_lbl.add_theme_font_size_override("font_size", 13)
	_timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	timer_hb.add_child(_timer_lbl)

	# --- 하단 키 매뉴얼 HUD 상시 표시 ---
	_build_manual_hud(root_vbox)

	# --- 결과 오버레이 패널 ---
	_build_result_overlay()

func _create_gate_boxes() -> void:
	# 북: 상단 중앙 (x: 374, y: 30)
	_gate_boxes[Dir.UP] = _make_gate_card("북: 장안문 (↑)", Vector2(374, 30))
	# 남: 하단 중앙 (x: 374, y: 250)
	_gate_boxes[Dir.DOWN] = _make_gate_card("남: 팔달문 (↓)", Vector2(374, 250))
	# 서: 좌측 중앙 (x: 100, y: 140)
	_gate_boxes[Dir.LEFT] = _make_gate_card("서: 화서문 (←)", Vector2(100, 140))
	# 동: 우측 중앙 (x: 648, y: 140)
	_gate_boxes[Dir.RIGHT] = _make_gate_card("동: 창룡문 (→)", Vector2(648, 140))

func _make_gate_card(title: String, center_pos: Vector2) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(140, 36)
	pc.position = center_pos - Vector2(70, 18)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.16, 0.22, 0.92)
	sb.border_color = Color(0.40, 0.50, 0.65)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(4)
	pc.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 0.95))
	pc.add_child(lbl)

	_center_arena.add_child(pc)
	return pc

func _create_seojangdae_box() -> void:
	_seojangdae_box = PanelContainer.new()
	_seojangdae_box.custom_minimum_size = Vector2(150, 70)
	_seojangdae_box.position = Vector2(374, 140) - Vector2(75, 35)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.15, 0.10, 0.95)
	sb.border_color = Color(0.95, 0.80, 0.40) # 금박 테두리
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(6)
	_seojangdae_box.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	_seojangdae_box.add_child(vb)

	var title := Label.new()
	title.text = "[서장대 본영]"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	vb.add_child(title)

	_aim_indicator_lbl = Label.new()
	_aim_indicator_lbl.text = "현재 조준: 북 (↑)"
	_aim_indicator_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aim_indicator_lbl.add_theme_font_size_override("font_size", 12)
	_aim_indicator_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	vb.add_child(_aim_indicator_lbl)

	_center_arena.add_child(_seojangdae_box)

func _create_target_unit() -> void:
	_target_unit = PanelContainer.new()
	_target_unit.custom_minimum_size = Vector2(130, 32)
	_target_unit.visible = false

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.14, 0.95)
	sb.border_color = Color(1.0, 0.3, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(4)
	_target_unit.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 6)
	_target_unit.add_child(hb)

	_target_color_badge = ColorRect.new()
	_target_color_badge.custom_minimum_size = Vector2(16, 16)
	_target_color_badge.color = Color("#E63946")
	hb.add_child(_target_color_badge)

	_target_text_lbl = Label.new()
	_target_text_lbl.text = "적: 붉은색 [Q]"
	_target_text_lbl.add_theme_font_size_override("font_size", 12)
	_target_text_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	hb.add_child(_target_text_lbl)

	_center_arena.add_child(_target_unit)

func _build_manual_hud(parent: Control) -> void:
	var manual_panel := PanelContainer.new()
	manual_panel.custom_minimum_size = Vector2(0, 105)

	var m_sb := StyleBoxFlat.new()
	m_sb.bg_color = Color(0.08, 0.10, 0.14, 0.95)
	m_sb.border_color = Color(0.35, 0.45, 0.55)
	m_sb.set_border_width_all(1)
	m_sb.set_corner_radius_all(6)
	m_sb.set_content_margin_all(8)
	manual_panel.add_theme_stylebox_override("panel", m_sb)
	parent.add_child(manual_panel)

	var mvb := VBoxContainer.new()
	mvb.add_theme_constant_override("separation", 6)
	manual_panel.add_child(mvb)

	var m_title := Label.new()
	m_title.text = "지휘 조작법 (자판 직접 입력)"
	m_title.add_theme_font_size_override("font_size", 12)
	m_title.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	mvb.add_child(m_title)

	# 1단계 방향 조준 버튼열
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	mvb.add_child(row1)

	var r1_tag := Label.new()
	r1_tag.text = "1단계 (방향 조준):"
	r1_tag.custom_minimum_size = Vector2(130, 0)
	r1_tag.add_theme_font_size_override("font_size", 12)
	r1_tag.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	row1.add_child(r1_tag)

	_dir_manual_panels[Dir.UP] = _make_key_chip("[↑] 북문(장안문)", row1)
	_dir_manual_panels[Dir.DOWN] = _make_key_chip("[↓] 남문(팔달문)", row1)
	_dir_manual_panels[Dir.LEFT] = _make_key_chip("[←] 서문(화서문)", row1)
	_dir_manual_panels[Dir.RIGHT] = _make_key_chip("[→] 동문(창룡문)", row1)

	# 2단계 신호 발사 버튼열
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	mvb.add_child(row2)

	var r2_tag := Label.new()
	r2_tag.text = "2단계 (신호 발사):"
	r2_tag.custom_minimum_size = Vector2(130, 0)
	r2_tag.add_theme_font_size_override("font_size", 12)
	r2_tag.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	row2.add_child(r2_tag)

	_color_manual_panels[SignalColor.RED] = _make_color_chip("[Q] 붉은등", COLOR_MAP[SignalColor.RED], row2)
	_color_manual_panels[SignalColor.BLUE] = _make_color_chip("[W] 파란등", COLOR_MAP[SignalColor.BLUE], row2)
	_color_manual_panels[SignalColor.YELLOW] = _make_color_chip("[E] 노란등", COLOR_MAP[SignalColor.YELLOW], row2)
	_color_manual_panels[SignalColor.GREEN] = _make_color_chip("[R] 초록등", COLOR_MAP[SignalColor.GREEN], row2)

func _make_key_chip(text: String, parent: Control) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(135, 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.18, 0.24)
	sb.border_color = Color(0.35, 0.45, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(3)
	pc.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	pc.add_child(lbl)

	parent.add_child(pc)
	return pc

func _make_color_chip(text: String, col: Color, parent: Control) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(135, 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r * 0.3, col.g * 0.3, col.b * 0.3, 0.9)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(3)
	pc.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", col.lightened(0.4))
	pc.add_child(lbl)

	parent.add_child(pc)
	return pc

func _build_result_overlay() -> void:
	_result_center = CenterContainer.new()
	_result_center.name = "ResultCenterContainer"
	_result_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_center.visible = false
	add_child(_result_center)

	_result_panel = PanelContainer.new()
	_result_panel.name = "ResultPanel"
	_result_panel.custom_minimum_size = Vector2(420, 260)
	_result_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.12, 0.16, 0.98)
	sb.border_color = Color(0.95, 0.80, 0.40)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.8)
	sb.shadow_size = 20
	sb.set_content_margin_all(20)
	_result_panel.add_theme_stylebox_override("panel", sb)
	_result_center.add_child(_result_panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 14)
	_result_panel.add_child(vb)

	var r_title := Label.new()
	r_title.text = "[야조 훈련 결과 정산]"
	r_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r_title.add_theme_font_size_override("font_size", 16)
	r_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	vb.add_child(r_title)

	_result_summary_lbl = Label.new()
	_result_summary_lbl.text = "10회 중 10회 성공\n훈련 효과 보정: +20% (1.20x)"
	_result_summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_summary_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_summary_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_summary_lbl.add_theme_font_size_override("font_size", 14)
	_result_summary_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vb.add_child(_result_summary_lbl)

	_result_confirm_btn = Button.new()
	_result_confirm_btn.text = "훈련 성료 및 효과 적용"
	_result_confirm_btn.custom_minimum_size = Vector2(200, 38)
	_result_confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.20, 0.35, 0.20)
	btn_sb.border_color = Color(0.6, 0.9, 0.6)
	btn_sb.set_border_width_all(1)
	btn_sb.set_corner_radius_all(6)
	_result_confirm_btn.add_theme_stylebox_override("normal", btn_sb)
	_result_confirm_btn.pressed.connect(_on_result_confirmed)
	vb.add_child(_result_confirm_btn)

## =========================================================================
## 게임 라이프사이클 제어
## =========================================================================
func start_yajo_minigame(p_time_manager: TimeManager = null) -> void:
	_sync_viewport_size()
	time_manager = p_time_manager
	if time_manager != null:
		_saved_speed_mode = int(time_manager.current_speed)
		time_manager.set_speed(TimeManager.SpeedMode.PAUSE)

	visible = true
	set_process(true)
	set_process_input(true)

	current_round = 0
	success_count = 0
	fail_count = 0
	selected_dir = Dir.UP
	feedback_timer = 0.0

	_result_panel.visible = false
	if _result_center != null:
		_result_center.visible = false
	_feedback_lbl.visible = false
	_highlight_aim_direction()

	_start_next_round()

func _start_next_round() -> void:
	current_round += 1
	if current_round > MAX_ROUNDS:
		_finish_minigame()
		return

	# 1회차 5.0초 -> 10회차 1.0초 선형 단축 공식
	# T(r) = 5.0 - ((r - 1) / 9.0) * 4.0
	time_limit = 5.0 - (float(current_round - 1) / float(MAX_ROUNDS - 1)) * 4.0
	time_left = time_limit
	_timer_bar.max_value = time_limit
	_timer_bar.value = time_left

	# 사방(동서남북) 및 색상(QWER) 무작위 출제
	target_dir = randi() % 4
	target_color = randi() % 4

	is_round_active = true
	feedback_timer = 0.0
	_feedback_lbl.visible = false

	_update_round_ui()
	_update_target_visual(0.0)

func _update_round_ui() -> void:
	_header_round_lbl.text = "진행: %d / %d회" % [current_round, MAX_ROUNDS]

	var cur_bonus_pct: int = (success_count - 5) * 4
	var sign_str: String = ("+" if cur_bonus_pct > 0 else "") + str(cur_bonus_pct) + "%"
	_header_score_lbl.text = "현재 성적: 성공 %d회 / 실패 %d회 (예상 훈련 효과: %s)" % [
		success_count, fail_count, sign_str
	]

	# 적 표적 정보 갱신
	_target_unit.visible = true
	_target_color_badge.color = COLOR_MAP[target_color]
	_target_text_lbl.text = "표적: %s" % COLOR_NAMES[target_color]

	var sb: StyleBoxFlat = _target_unit.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.border_color = COLOR_MAP[target_color]

func _highlight_aim_direction() -> void:
	_aim_indicator_lbl.text = "현재 조준: %s" % DIR_LABELS[selected_dir]

	# 하단 키 매뉴얼 하이라이트
	for d: int in _dir_manual_panels.keys():
		var p: PanelContainer = _dir_manual_panels[d]
		var sb: StyleBoxFlat = p.get_theme_stylebox("panel") as StyleBoxFlat
		if sb != null:
			if d == selected_dir:
				sb.bg_color = Color(0.35, 0.28, 0.12)
				sb.border_color = Color(1.0, 0.85, 0.3)
				sb.set_border_width_all(2)
			else:
				sb.bg_color = Color(0.14, 0.18, 0.24)
				sb.border_color = Color(0.35, 0.45, 0.55)
				sb.set_border_width_all(1)

	# 성문 박스 하이라이트
	for d: int in _gate_boxes.keys():
		var gb: PanelContainer = _gate_boxes[d]
		var g_sb: StyleBoxFlat = gb.get_theme_stylebox("panel") as StyleBoxFlat
		if g_sb != null:
			if d == selected_dir:
				g_sb.border_color = Color(1.0, 0.85, 0.3)
				g_sb.set_border_width_all(2)
			else:
				g_sb.border_color = Color(0.40, 0.50, 0.65)
				g_sb.set_border_width_all(1)

## =========================================================================
## 입력 처리 (월드 입력 가로채기 보장)
## =========================================================================
func _set_input_handled() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# 결과창 표시 중 엔터/스페이스로 확인
	if _result_panel.visible:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_set_input_handled()
			_on_result_confirmed()
		return

	# 1. 방향키 조준
	match event.keycode:
		KEY_UP:
			selected_dir = Dir.UP
			_highlight_aim_direction()
			_set_input_handled()
			return
		KEY_DOWN:
			selected_dir = Dir.DOWN
			_highlight_aim_direction()
			_set_input_handled()
			return
		KEY_LEFT:
			selected_dir = Dir.LEFT
			_highlight_aim_direction()
			_set_input_handled()
			return
		KEY_RIGHT:
			selected_dir = Dir.RIGHT
			_highlight_aim_direction()
			_set_input_handled()
			return

	# 2. QWER 색상 신호탄 발사
	match event.keycode:
		KEY_Q:
			_set_input_handled()
			_fire_signal(SignalColor.RED)
			return
		KEY_W:
			_set_input_handled()
			_fire_signal(SignalColor.BLUE)
			return
		KEY_E:
			_set_input_handled()
			_fire_signal(SignalColor.YELLOW)
			return
		KEY_R:
			_set_input_handled()
			_fire_signal(SignalColor.GREEN)
			return

func _fire_signal(fired_color: int) -> void:
	if not is_round_active:
		return
	is_round_active = false

	# 조준한 방향과 신호탄 색상이 모두 일치하면 성공
	var is_success: bool = (selected_dir == target_dir and fired_color == target_color)
	if is_success:
		success_count += 1
		_show_feedback("신호 일치! %s 방어 성공" % DIR_LABELS[target_dir], Color(0.4, 0.9, 0.4))
	else:
		fail_count += 1
		var err_reason: String = ""
		if selected_dir != target_dir:
			err_reason = "방향 오조준"
		else:
			err_reason = "신호등 색상 불일치"
		_show_feedback("신호 실패! (%s)" % err_reason, Color(1.0, 0.4, 0.4))

	feedback_timer = 0.65

func _show_feedback(msg: String, col: Color) -> void:
	_feedback_lbl.text = msg
	_feedback_lbl.add_theme_color_override("font_color", col)
	_feedback_lbl.visible = true

## =========================================================================
## 메인 루프 (시간 감쇄 및 표적 접근 보간)
## =========================================================================
func _process(delta: float) -> void:
	if not visible:
		return

	if feedback_timer > 0.0:
		feedback_timer -= delta
		if feedback_timer <= 0.0:
			_feedback_lbl.visible = false
			_start_next_round()
		return

	if not is_round_active:
		return

	time_left = maxf(0.0, time_left - delta)
	_timer_bar.value = time_left
	_timer_lbl.text = "%.1f초" % time_left

	var progress: float = 1.0 - (time_left / time_limit)
	_update_target_visual(progress)

	if time_left <= 0.0:
		is_round_active = false
		fail_count += 1
		_show_feedback("시간 초과! 신호 전달 지연", Color(1.0, 0.4, 0.4))
		feedback_timer = 0.65

func _update_target_visual(progress: float) -> void:
	# 사방 성문 위치에서 중앙 서장대 위치로 선형 접근
	var gate_pos: Vector2 = Vector2.ZERO
	match target_dir:
		Dir.UP: gate_pos = Vector2(374, 55)
		Dir.DOWN: gate_pos = Vector2(374, 225)
		Dir.LEFT: gate_pos = Vector2(150, 140)
		Dir.RIGHT: gate_pos = Vector2(598, 140)

	var center_pos := Vector2(374, 140)
	var current_pos: Vector2 = gate_pos.lerp(center_pos, clampf(progress, 0.0, 0.85))

	_target_unit.position = current_pos - Vector2(65, 16)

## =========================================================================
## 종료 및 정산
## =========================================================================
func _finish_minigame() -> void:
	is_round_active = false
	_target_unit.visible = false

	# 10회 성공: +20% (1.20x) / 5회 성공: 0% (1.00x) / 0회 성공: -20% (0.80x)
	var bonus_pct: int = (success_count - 5) * 4
	var final_mult: float = 1.0 + float(bonus_pct) / 100.0

	var sign_str: String = ("+" if bonus_pct > 0 else "") + str(bonus_pct) + "%"
	_result_summary_lbl.text = "총 10회 훈련 중 [%d회 성공 / %d회 실패]\n최종 훈련 효과 보정: %s (%.2f배)" % [
		success_count, fail_count, sign_str, final_mult
	]

	_result_panel.visible = true
	if _result_center != null:
		_result_center.visible = true

func _on_result_confirmed() -> void:
	var bonus_pct: int = (success_count - 5) * 4
	var final_mult: float = 1.0 + float(bonus_pct) / 100.0

	_result_panel.visible = false
	if _result_center != null:
		_result_center.visible = false
	visible = false
	set_process(false)
	set_process_input(false)

	# 일시정지 복구
	if time_manager != null:
		time_manager.set_speed(_saved_speed_mode)

	minigame_completed.emit(final_mult, success_count)
