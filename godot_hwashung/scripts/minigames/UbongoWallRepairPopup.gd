extends Control
class_name UbongoWallRepairPopup

## [수원화성 석축 직접 보수 — 우봉고 퍼즐 미니게임]
## - 3라운드 순차 진행: 3조각(35초) → 4조각(45초) → 5조각(60초)
## - 조각 드래그&드롭, 우클릭(또는 R키) 90도 회전, 스페이스바 완성 검증
## - 성공 수에 따라 기본 회복량 대비 ×0.9(0/3) ~ ×3.0(3/3) 차등 정산
## - UI 무결성: CenterContainer 기반 정렬, 폭 폭증 방지, 독립 GUI 이벤트 처리

signal minigame_completed(success_count: int, base_restore: int)

## ─────────── 캔버스 내부 클래스 (Godot 4 _draw() 무결성 보장) ───────────
class BoardCanvas extends Control:
	var popup: UbongoWallRepairPopup
	func _draw() -> void:
		if popup != null:
			popup._render_board(self)

class TrayCanvas extends Control:
	var popup: UbongoWallRepairPopup
	func _draw() -> void:
		if popup != null:
			popup._render_tray(self)

## ─────────── 상수 ───────────
const CELL_SIZE: int = 56          # 격자 1칸 픽셀 크기
const PIECE_COLORS: Array[Color] = [
	Color("e06c24"), Color("22a050"), Color("2563eb"), Color("dc2626"),
	Color("8b5cf6"), Color("0ea5e9"), Color("db2777"), Color("ca8a04"),
	Color("059669"), Color("3b82f6"), Color("b91c1c"), Color("15803d")
]

const ROUND_TIME_LIMITS: Array[int] = [35, 45, 60]
const ROUND_PIECE_COUNTS: Array[int] = [3, 4, 5]

## 성공 수 → 회복 배율 (0개 90%, 1개 110%, 2개 200%, 3개 300%)
const RESTORE_MULTIPLIERS: Array[float] = [0.90, 1.10, 2.00, 3.00]

## ─────────── 상태 변수 ───────────
var _current_round: int = 0           # 0-indexed (0, 1, 2)
var _success_count: int = 0
var _time_left: float = 35.0
var _round_active: bool = false
var _base_restore: int = 300

## 현재 퍼즐 데이터
var _target_grid: Array = []          # 2D int[H][W]: 1=목표 석축 칸, 0=외부
var _placed_grid: Array = []          # 2D int[H][W]: 0=빈칸, pid=배치된 조각
var _board_w: int = 0
var _board_h: int = 0
var _piece_ids: Array[int] = []
var _piece_shapes: Array = []         # 각 조각의 현재 모양 행렬
var _piece_rot_indices: Array[int] = []
var _all_piece_rotations: Array = []  # 조각별 4개 회전 캐시

## 드래그 상태
var _dragging_piece_idx: int = -1
var _drag_pos: Vector2 = Vector2.ZERO

## 배치 위치 (조각별 보드 좌상단 셀 좌표, Vector2i(-1, -1)이면 트레이 보관)
var _piece_placements: Array[Vector2i] = []

## 시간관리자 참조 (일시정지 제어)
var time_manager: TimeManager = null
var _saved_speed_mode: int = 1

## ─────────── UI 노드 참조 ───────────
var _backdrop: ColorRect
var _main_center: CenterContainer
var _main_panel: PanelContainer
var _round_lbl: Label
var _timer_bar: ProgressBar
var _timer_lbl: Label
var _score_lbl: Label
var _board_draw: BoardCanvas
var _piece_tray: TrayCanvas
var _hint_lbl: Label
var _confirm_btn: Button
var _close_btn: Button

## 결과 오버레이
var _result_center: CenterContainer
var _result_panel: PanelContainer
var _result_lbl: Label
var _result_btn: Button

## ─────────── 초기화 ───────────
func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	_sync_viewport_size()
	if is_inside_tree() and get_viewport():
		if not get_viewport().size_changed.is_connected(_sync_viewport_size):
			get_viewport().size_changed.connect(_sync_viewport_size)
	visible = false
	set_process(false)

func _sync_viewport_size() -> void:
	if not is_inside_tree() or get_viewport() == null:
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	if vp_size.x > 0.0 and vp_size.y > 0.0:
		size = vp_size
		if _backdrop:
			_backdrop.size = vp_size
		if _main_center:
			_main_center.size = vp_size
		if _result_center:
			_result_center.size = vp_size

## ─────────── UI 구성 ───────────
func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)

	## 1. 전체 화면 반투명 배경 딤 (배경 맵 클릭 100% 차단)
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.65)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	## 2. 화면 중앙 정렬 CenterContainer
	_main_center = CenterContainer.new()
	_main_center.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_main_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_main_center)

	## 3. 메인 다이얼로그 패널
	_main_panel = PanelContainer.new()
	_main_panel.custom_minimum_size = Vector2(880.0, 600.0)
	_main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fdf8ee")
	sb.border_color = Color("6d4c2d")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = 14
	sb.set_content_margin_all(0.0)
	_main_panel.add_theme_stylebox_override("panel", sb)
	_main_center.add_child(_main_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	_main_panel.add_child(vbox)

	## 4. 상단 타이틀 바
	var header_panel := PanelContainer.new()
	var h_sb := StyleBoxFlat.new()
	h_sb.bg_color = Color("451a03")
	h_sb.corner_radius_top_left = 8
	h_sb.corner_radius_top_right = 8
	h_sb.set_content_margin_all(10.0)
	header_panel.add_theme_stylebox_override("panel", h_sb)
	vbox.add_child(header_panel)

	var h_hbox := HBoxContainer.new()
	h_hbox.add_theme_constant_override("separation", 12)
	header_panel.add_child(h_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "🧱 수원화성 성곽 직접 석축 보수 — 성돌 맞추기"
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", Color("fef3c7"))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_hbox.add_child(title_lbl)

	_round_lbl = Label.new()
	_round_lbl.text = "[ 1 / 3 판 ]"
	_round_lbl.add_theme_font_size_override("font_size", 14)
	_round_lbl.add_theme_color_override("font_color", Color("fde68a"))
	h_hbox.add_child(_round_lbl)

	_close_btn = Button.new()
	_close_btn.text = " ✕ "
	_close_btn.custom_minimum_size = Vector2(32.0, 28.0)
	_close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var close_sb := StyleBoxFlat.new()
	close_sb.bg_color = Color("78350f")
	close_sb.border_color = Color("b45309")
	close_sb.set_border_width_all(1)
	close_sb.set_corner_radius_all(4)
	_close_btn.add_theme_stylebox_override("normal", close_sb)
	_close_btn.add_theme_color_override("font_color", Color("fef3c7"))
	_close_btn.pressed.connect(_on_close_clicked)
	h_hbox.add_child(_close_btn)

	## 5. 상태 바 (시간, 점수)
	var status_panel := PanelContainer.new()
	var sp_sb := StyleBoxFlat.new()
	sp_sb.bg_color = Color("78350f")
	sp_sb.set_content_margin_all(8.0)
	status_panel.add_theme_stylebox_override("panel", sp_sb)
	vbox.add_child(status_panel)

	var s_hbox := HBoxContainer.new()
	s_hbox.add_theme_constant_override("separation", 16)
	status_panel.add_child(s_hbox)

	var t_lbl_hdr := Label.new()
	t_lbl_hdr.text = "남은 시간:"
	t_lbl_hdr.add_theme_color_override("font_color", Color("fde68a"))
	t_lbl_hdr.add_theme_font_size_override("font_size", 13)
	s_hbox.add_child(t_lbl_hdr)

	_timer_bar = ProgressBar.new()
	_timer_bar.custom_minimum_size = Vector2(240.0, 20.0)
	_timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer_bar.min_value = 0.0
	_timer_bar.max_value = 100.0
	_timer_bar.value = 100.0
	s_hbox.add_child(_timer_bar)

	_timer_lbl = Label.new()
	_timer_lbl.text = "35초"
	_timer_lbl.custom_minimum_size = Vector2(45.0, 0.0)
	_timer_lbl.add_theme_color_override("font_color", Color("fef3c7"))
	_timer_lbl.add_theme_font_size_override("font_size", 14)
	s_hbox.add_child(_timer_lbl)

	_score_lbl = Label.new()
	_score_lbl.text = "현재 성공: 0회 / 실패: 0회"
	_score_lbl.add_theme_color_override("font_color", Color("fde68a"))
	_score_lbl.add_theme_font_size_override("font_size", 13)
	s_hbox.add_child(_score_lbl)

	## 6. 퍼즐 본체 영역 (좌: 석축 목표 영역, 우: 사용 가능 조각 트레이)
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 16)
	var body_margin := MarginContainer.new()
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_margin.add_theme_constant_override("margin_left", 16)
	body_margin.add_theme_constant_override("margin_right", 16)
	body_margin.add_theme_constant_override("margin_top", 12)
	body_margin.add_theme_constant_override("margin_bottom", 8)
	body_margin.add_child(body_hbox)
	vbox.add_child(body_margin)

	## 좌측: 석축 목표 영역
	var board_vbox := VBoxContainer.new()
	board_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_child(board_vbox)

	var board_hdr := Label.new()
	board_hdr.text = "🏛️ [ 석축 홈 틈새 (하얀 목표 영역을 빈틈없이 채우세요) ]"
	board_hdr.add_theme_font_size_override("font_size", 13)
	board_hdr.add_theme_color_override("font_color", Color("78350f"))
	board_vbox.add_child(board_hdr)

	_board_draw = BoardCanvas.new()
	_board_draw.popup = self
	_board_draw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_draw.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_draw.mouse_filter = Control.MOUSE_FILTER_PASS
	_board_draw.gui_input.connect(_on_board_gui_input)
	board_vbox.add_child(_board_draw)

	## 우측: 조각 트레이
	var tray_vbox := VBoxContainer.new()
	tray_vbox.custom_minimum_size = Vector2(250.0, 320.0)
	tray_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_child(tray_vbox)

	var tray_hdr := Label.new()
	tray_hdr.text = "🧱 [ 사용 가능한 화강암 성돌 ]"
	tray_hdr.add_theme_font_size_override("font_size", 13)
	tray_hdr.add_theme_color_override("font_color", Color("78350f"))
	tray_vbox.add_child(tray_hdr)

	_piece_tray = TrayCanvas.new()
	_piece_tray.popup = self
	_piece_tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_piece_tray.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_piece_tray.mouse_filter = Control.MOUSE_FILTER_PASS
	_piece_tray.gui_input.connect(_on_tray_gui_input)
	tray_vbox.add_child(_piece_tray)

	## 7. 조작 안내 및 완성 버튼
	var footer_hbox := HBoxContainer.new()
	footer_hbox.add_theme_constant_override("separation", 12)
	var footer_margin := MarginContainer.new()
	footer_margin.add_theme_constant_override("margin_left", 16)
	footer_margin.add_theme_constant_override("margin_right", 16)
	footer_margin.add_theme_constant_override("margin_top", 4)
	footer_margin.add_theme_constant_override("margin_bottom", 12)
	footer_margin.add_child(footer_hbox)
	vbox.add_child(footer_margin)

	_hint_lbl = Label.new()
	_hint_lbl.text = "🖱️ 끌기(조각 이동) | 오른쪽 누름 또는 R 글쇠(90° 회전) | 띄어쓰기 글쇠(완성 확인)\n[효과] 3개 성공: +200% | 2개 성공: +100% | 1개 성공: +10% | 전패: -10%"
	_hint_lbl.add_theme_font_size_override("font_size", 11)
	_hint_lbl.add_theme_color_override("font_color", Color("78350f"))
	_hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hbox.add_child(_hint_lbl)

	_confirm_btn = Button.new()
	_confirm_btn.text = "성돌 맞춤 완료 (띄어쓰기 글쇠)"
	_confirm_btn.custom_minimum_size = Vector2(200.0, 42.0)
	_confirm_btn.add_theme_font_size_override("font_size", 13)
	_confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var c_sb := StyleBoxFlat.new()
	c_sb.bg_color = Color("1e40af")
	c_sb.border_color = Color("93c5fd")
	c_sb.set_border_width_all(2)
	c_sb.set_corner_radius_all(6)
	c_sb.set_content_margin_all(6.0)
	_confirm_btn.add_theme_stylebox_override("normal", c_sb)
	var c_sb_h := c_sb.duplicate() as StyleBoxFlat
	c_sb_h.bg_color = Color("2563eb")
	_confirm_btn.add_theme_stylebox_override("hover", c_sb_h)
	_confirm_btn.add_theme_color_override("font_color", Color("ffffff"))
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	footer_hbox.add_child(_confirm_btn)

	## 8. 결과 모달 오버레이 (CenterContainer로 완벽 중앙 정렬, 폭 폭증 방지)
	_result_center = CenterContainer.new()
	_result_center.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_result_center.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_center.visible = false
	add_child(_result_center)

	## 결과 배경 딤
	var r_backdrop := ColorRect.new()
	r_backdrop.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	r_backdrop.color = Color(0.0, 0.0, 0.0, 0.45)
	r_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_center.add_child(r_backdrop)

	_result_panel = PanelContainer.new()
	_result_panel.custom_minimum_size = Vector2(440.0, 220.0)
	_result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var r_sb := StyleBoxFlat.new()
	r_sb.bg_color = Color("fffdf5")
	r_sb.border_color = Color("7a5835")
	r_sb.set_border_width_all(3)
	r_sb.set_corner_radius_all(10)
	r_sb.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	r_sb.shadow_size = 12
	r_sb.set_content_margin_all(24.0)
	_result_panel.add_theme_stylebox_override("panel", r_sb)
	_result_center.add_child(_result_panel)

	var r_vbox := VBoxContainer.new()
	r_vbox.add_theme_constant_override("separation", 16)
	_result_panel.add_child(r_vbox)

	_result_lbl = Label.new()
	_result_lbl.text = ""
	_result_lbl.custom_minimum_size = Vector2(380.0, 60.0)
	_result_lbl.add_theme_font_size_override("font_size", 15)
	_result_lbl.add_theme_color_override("font_color", Color("451a03"))
	_result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r_vbox.add_child(_result_lbl)

	var r_btn_center := CenterContainer.new()
	r_vbox.add_child(r_btn_center)

	_result_btn = Button.new()
	_result_btn.text = "다음 판"
	_result_btn.custom_minimum_size = Vector2(160.0, 40.0)
	_result_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var rb_sb := StyleBoxFlat.new()
	rb_sb.bg_color = Color("8c6239")
	rb_sb.border_color = Color("5c3a21")
	rb_sb.set_border_width_all(2)
	rb_sb.set_corner_radius_all(6)
	rb_sb.set_content_margin_all(6.0)
	_result_btn.add_theme_stylebox_override("normal", rb_sb)
	var rb_sb_h := rb_sb.duplicate() as StyleBoxFlat
	rb_sb_h.bg_color = Color("a87848")
	_result_btn.add_theme_stylebox_override("hover", rb_sb_h)
	_result_btn.add_theme_color_override("font_color", Color("ffffff"))
	_result_btn.pressed.connect(_on_result_btn_pressed)
	r_btn_center.add_child(_result_btn)

## ─────────── 공개 진입점 ───────────
func open_ubongo_puzzle(base_restore_amount: int, tm: TimeManager = null) -> void:
	_base_restore = base_restore_amount
	time_manager = tm
	_current_round = 0
	_success_count = 0
	_result_center.visible = false
	_sync_viewport_size()

	# 결과 버튼 시그널 안전 초기화
	if _result_btn.pressed.is_connected(_on_finish_confirmed):
		_result_btn.pressed.disconnect(_on_finish_confirmed)
	if not _result_btn.pressed.is_connected(_on_result_btn_pressed):
		_result_btn.pressed.connect(_on_result_btn_pressed)

	## 시뮬레이션 일시정지
	if time_manager != null and time_manager.has_method("get_speed_mode"):
		_saved_speed_mode = time_manager.get_speed_mode()
		if time_manager.has_method("set_speed_mode"):
			time_manager.set_speed_mode(0)

	visible = true
	set_process(true)
	_start_round()

## ─────────── 라운드 시작 ───────────
func _start_round() -> void:
	var r: int = _current_round
	var round_num: int = r + 1

	## 프리셋 데이터 추출
	var puzzle: Dictionary = UbongoPuzzlePresets.get_random_puzzle(round_num)
	var raw_pieces: Array = puzzle.get("pieces", [])
	_piece_ids.clear()
	for pid_val: Variant in raw_pieces:
		_piece_ids.append(int(pid_val))

	var raw_mask: Array = puzzle.get("target_mask", [])
	_target_grid = []
	for row_val: Variant in raw_mask:
		_target_grid.append(Array(row_val as Array))
	_board_h = _target_grid.size()
	_board_w = (_target_grid[0] as Array).size() if _board_h > 0 else 0

	## 배치 그리드 초기화
	_placed_grid = []
	for _ry: int in range(_board_h):
		var placed_row: Array = []
		for _cx: int in range(_board_w):
			placed_row.append(0)
		_placed_grid.append(placed_row)

	## 조각 회전 캐시 생성
	_piece_shapes.clear()
	_piece_rot_indices.clear()
	_all_piece_rotations.clear()
	for pid: int in _piece_ids:
		var base_shape: Array = UbongoPuzzlePresets.PIECE_SHAPES.get(pid, [])
		var rots: Array = _compute_rotations(base_shape)
		_all_piece_rotations.append(rots)
		_piece_shapes.append(_deep_copy_array(rots[0]))
		_piece_rot_indices.append(0)

	## 배치 위치 초기화 (미배치 = 트레이)
	_piece_placements.resize(_piece_ids.size())
	for pi: int in range(_piece_ids.size()):
		_piece_placements[pi] = Vector2i(-1, -1)

	## 타이머 설정
	_time_left = float(ROUND_TIME_LIMITS[r])
	_dragging_piece_idx = -1
	_round_active = true

	## HUD 갱신
	_round_lbl.text = "[ %d / 3 판 ]" % round_num
	_timer_bar.max_value = _time_left
	_timer_bar.value = _time_left
	_timer_lbl.text = "%d초" % int(_time_left)
	_update_score_lbl()

	_board_draw.queue_redraw()
	_piece_tray.queue_redraw()

## ─────────── 틱 업데이트 ───────────
func _process(delta: float) -> void:
	if not _round_active:
		return

	_time_left -= delta
	var tl_clamped: float = maxf(0.0, _time_left)
	_timer_bar.value = tl_clamped
	_timer_lbl.text = "%d초" % int(tl_clamped)

	if _time_left < 10.0:
		_timer_lbl.add_theme_color_override("font_color", Color("ef4444"))
	elif _time_left < 20.0:
		_timer_lbl.add_theme_color_override("font_color", Color("f59e0b"))
	else:
		_timer_lbl.add_theme_color_override("font_color", Color("fef3c7"))

	if _time_left <= 0.0:
		_on_time_out()

## ─────────── 전역 마우스 드래그 입력 ───────────
func _input(event: InputEvent) -> void:
	if not visible:
		return

	if _dragging_piece_idx >= 0:
		if event is InputEventMouseMotion:
			var mm := event as InputEventMouseMotion
			_drag_pos = mm.global_position
			_board_draw.queue_redraw()
			_piece_tray.queue_redraw()
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				_rotate_piece(_dragging_piece_idx)
				get_viewport().set_input_as_handled()
				return
			elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
				_on_drag_released(mb.global_position)
				get_viewport().set_input_as_handled()
				return

## ─────────── 키보드 단축키 입력 ───────────
func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key_ev := event as InputEventKey
		## 결과 창이 떠 있는 상태에서는 Space/Enter로 다음 진행
		if _result_center != null and _result_center.visible:
			if key_ev.keycode == KEY_SPACE or key_ev.keycode == KEY_ENTER:
				_result_btn.emit_signal("pressed")
				get_viewport().set_input_as_handled()
				return

		## ESC: 닫기 / 포기
		if key_ev.keycode == KEY_ESCAPE:
			_on_close_clicked()
			get_viewport().set_input_as_handled()
			return

		if not _round_active:
			return

		## R키: 드래그 중인 조각 90도 회전
		if key_ev.keycode == KEY_R and _dragging_piece_idx >= 0:
			_rotate_piece(_dragging_piece_idx)
			get_viewport().set_input_as_handled()
		## 스페이스바: 맞춤 완성 확인
		elif key_ev.keycode == KEY_SPACE:
			_on_confirm_pressed()
			get_viewport().set_input_as_handled()

## ─────────── 보드 영역 GUI 입력 (드래그 시작) ───────────
func _on_board_gui_input(event: InputEvent) -> void:
	if not _round_active:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var cell := _local_to_cell(mb.position)
			if _is_valid_cell(cell.x, cell.y):
				var pid: int = int((_placed_grid[cell.y] as Array)[cell.x])
				if pid > 0:
					var pi: int = _find_piece_idx(pid)
					_remove_piece_from_board(pi)
					_dragging_piece_idx = pi
					_drag_pos = _board_draw.get_global_transform() * mb.position
					_board_draw.queue_redraw()
					_piece_tray.queue_redraw()

## ─────────── 트레이 영역 GUI 입력 (드래그 시작 / 우클릭 회전) ───────────
func _on_tray_gui_input(event: InputEvent) -> void:
	if not _round_active:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				var pi: int = _piece_at_tray_local(mb.position)
				if pi >= 0:
					if _piece_placements[pi] != Vector2i(-1, -1):
						_remove_piece_from_board(pi)
					_dragging_piece_idx = pi
					_drag_pos = _piece_tray.get_global_transform() * mb.position
					_board_draw.queue_redraw()
					_piece_tray.queue_redraw()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				var pi: int = _piece_at_tray_local(mb.position)
				if pi >= 0:
					_rotate_piece(pi)

## ─────────── 드래그 릴리즈 및 스마트 자석 스냅 ───────────
func _on_drag_released(global_pos: Vector2) -> void:
	if _dragging_piece_idx < 0:
		return
	var pi: int = _dragging_piece_idx
	_dragging_piece_idx = -1

	var local_board: Vector2 = _board_draw.get_global_transform().affine_inverse() * global_pos
	var board_rect := Rect2(Vector2.ZERO, _board_draw.size)
	var expanded_rect := board_rect.grow(30.0)

	if expanded_rect.has_point(local_board):
		var cell := _local_to_cell(local_board)
		var shape: Array = _piece_shapes[pi]
		var sw: int = (shape[0] as Array).size()
		var sh: int = shape.size()

		var top_x: int = cell.x - int(float(sw) * 0.5)
		var top_y: int = cell.y - int(float(sh) * 0.5)

		var best_pos := _find_best_placement(pi, top_x, top_y)
		if best_pos != Vector2i(-999, -999):
			_try_place_piece(pi, best_pos.x, best_pos.y)
		else:
			## 배치 불가능한 위치에 놓으면 트레이로 반환
			_piece_placements[pi] = Vector2i(-1, -1)
	else:
		## 보드 밖(트레이 영역 등)에 놓으면 트레이로 반환
		_piece_placements[pi] = Vector2i(-1, -1)

	_board_draw.queue_redraw()
	_piece_tray.queue_redraw()

func _can_place_piece(pi: int, start_x: int, start_y: int) -> bool:
	var shape: Array = _piece_shapes[pi]
	var sh: int = shape.size()
	var sw: int = (shape[0] as Array).size()

	for sr: int in range(sh):
		for sc: int in range(sw):
			if int((shape[sr] as Array)[sc]) == 0:
				continue
			var br: int = start_y + sr
			var bc: int = start_x + sc
			if br < 0 or br >= _board_h or bc < 0 or bc >= _board_w:
				return false
			if int((_target_grid[br] as Array)[bc]) == 0:
				return false
			if int((_placed_grid[br] as Array)[bc]) != 0:
				return false
	return true

func _find_best_placement(pi: int, start_x: int, start_y: int) -> Vector2i:
	if _can_place_piece(pi, start_x, start_y):
		return Vector2i(start_x, start_y)

	## 근접 1칸 오프셋 자석 스냅 탐색 (우선순위 순)
	const OFFSETS: Array[Vector2i] = [
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
	]
	for off: Vector2i in OFFSETS:
		var nx: int = start_x + off.x
		var ny: int = start_y + off.y
		if _can_place_piece(pi, nx, ny):
			return Vector2i(nx, ny)

	return Vector2i(-999, -999)

func _try_place_piece(pi: int, start_x: int, start_y: int) -> bool:
	if not _can_place_piece(pi, start_x, start_y):
		return false

	var shape: Array = _piece_shapes[pi]
	var sh: int = shape.size()
	var sw: int = (shape[0] as Array).size()

	for sr: int in range(sh):
		for sc: int in range(sw):
			if int((shape[sr] as Array)[sc]) == 1:
				(_placed_grid[start_y + sr] as Array)[start_x + sc] = _piece_ids[pi]
	_piece_placements[pi] = Vector2i(start_x, start_y)
	return true

func _remove_piece_from_board(pi: int) -> void:
	var placement: Vector2i = _piece_placements[pi]
	if placement == Vector2i(-1, -1):
		return
	var shape: Array = _piece_shapes[pi]
	for sr: int in range(shape.size()):
		for sc: int in range((shape[sr] as Array).size()):
			if int((shape[sr] as Array)[sc]) == 1:
				var br: int = placement.y + sr
				var bc: int = placement.x + sc
				if br >= 0 and br < _board_h and bc >= 0 and bc < _board_w:
					(_placed_grid[br] as Array)[bc] = 0
	_piece_placements[pi] = Vector2i(-1, -1)

func _rotate_piece(pi: int) -> void:
	var was_placed: bool = _piece_placements[pi] != Vector2i(-1, -1)
	var old_placement: Vector2i = _piece_placements[pi]
	if was_placed:
		_remove_piece_from_board(pi)

	var rots: Array = _all_piece_rotations[pi]
	_piece_rot_indices[pi] = (_piece_rot_indices[pi] + 1) % rots.size()
	_piece_shapes[pi] = _deep_copy_array(rots[_piece_rot_indices[pi]])

	if was_placed:
		if not _try_place_piece(pi, old_placement.x, old_placement.y):
			_piece_placements[pi] = Vector2i(-1, -1)

	_board_draw.queue_redraw()
	_piece_tray.queue_redraw()

## ─────────── 판정 및 라운드 핸들러 ───────────
func _check_board_complete() -> bool:
	for ry: int in range(_board_h):
		for cx: int in range(_board_w):
			var target_val: int = int((_target_grid[ry] as Array)[cx])
			var placed_val: int = int((_placed_grid[ry] as Array)[cx])
			if target_val == 1 and placed_val == 0:
				return false
			if target_val == 0 and placed_val > 0:
				return false
	return true

func _on_confirm_pressed() -> void:
	if not _round_active:
		return
	if _check_board_complete():
		_on_round_success()
	else:
		_hint_lbl.text = "⚠️ 아직 맞지 않는 틈새가 있습니다! 하얀 석축 영역을 빈틈없이 채워주세요."
		_hint_lbl.add_theme_color_override("font_color", Color("dc2626"))
		var t := get_tree().create_timer(1.2)
		t.timeout.connect(func():
			_hint_lbl.text = "🖱️ 끌기(조각 이동) | 오른쪽 누름 또는 R 글쇠(90° 회전) | 띄어쓰기 글쇠(완성 확인)\n[효과] 3개 성공: +200% | 2개 성공: +100% | 1개 성공: +10% | 전패: -10%"
			_hint_lbl.add_theme_color_override("font_color", Color("78350f"))
		)

func _on_round_success() -> void:
	_round_active = false
	_success_count += 1
	_show_round_result(true)

func _on_time_out() -> void:
	_round_active = false
	_show_round_result(false)

func _show_round_result(success: bool) -> void:
	_update_score_lbl()
	var round_num: int = _current_round + 1
	var btn_txt := "다음 판" if round_num < 3 else "최종 결산"

	if success:
		_show_overlay("🎉 %d판 성공!\n성돌이 빈틈없이 완벽하게 맞물렸습니다!" % round_num, btn_txt)
	else:
		_show_overlay("⏰ %d판 시간 초과!\n제한 시간 내에 성돌을 맞추지 못했습니다." % round_num, btn_txt)

func _on_result_btn_pressed() -> void:
	_result_center.visible = false
	_current_round += 1
	if _current_round < 3:
		_start_round()
	else:
		_finish_game()

func _finish_game() -> void:
	_round_active = false
	set_process(false)

	if time_manager != null and time_manager.has_method("set_speed_mode"):
		time_manager.set_speed_mode(_saved_speed_mode)

	var multiplier: float = RESTORE_MULTIPLIERS[clampi(_success_count, 0, 3)]
	var final_restore: int = int(float(_base_restore) * multiplier)

	var effect_desc := ""
	if _success_count == 3:
		effect_desc = "대성공 (3/3): 완벽한 축성술! 기본 회복량의 300% (+200% 가산) 달성!"
	elif _success_count == 2:
		effect_desc = "우수 (2/3): 견고한 성돌 맞춤! 기본 회복량의 200% (+100% 가산) 달성!"
	elif _success_count == 1:
		effect_desc = "보통 (1/3): 간신히 틈새 봉합. 기본 회복량의 110% (+10% 가산) 달성."
	else:
		effect_desc = "아쉬운 실패 (0/3): 성돌 규격 불일치. 기본 회복량의 90% (-10% 감산) 적용."

	var summary := "🧱 [성곽 직접 보수 최종 결산]\n성공: %d / 3회 | 최종 방호력 회복: +%d\n\n%s" % [_success_count, final_restore, effect_desc]
	_result_lbl.text = summary
	_result_btn.text = "보수 완료 및 복귀"
	_result_center.visible = true

	# 콜백 교체: 확인 누르면 시그널 발송 및 닫기
	if _result_btn.pressed.is_connected(_on_result_btn_pressed):
		_result_btn.pressed.disconnect(_on_result_btn_pressed)
	_result_btn.pressed.connect(_on_finish_confirmed)

func _on_finish_confirmed() -> void:
	if _result_btn.pressed.is_connected(_on_finish_confirmed):
		_result_btn.pressed.disconnect(_on_finish_confirmed)
	_result_btn.pressed.connect(_on_result_btn_pressed)
	_result_center.visible = false
	visible = false
	minigame_completed.emit(_success_count, _base_restore)

func _on_close_clicked() -> void:
	_round_active = false
	set_process(false)

	if time_manager != null and time_manager.has_method("set_speed_mode"):
		time_manager.set_speed_mode(_saved_speed_mode)

	_result_center.visible = false
	visible = false

	# 진행 중이던 성공 횟수 기준으로 안전 정산 발송
	minigame_completed.emit(_success_count, _base_restore)

func _show_overlay(txt: String, btn_text: String) -> void:
	_result_lbl.text = txt
	_result_btn.text = btn_text
	_result_center.visible = true

## ─────────── 렌더링 (CanvasItem _draw() 내부 직접 드로우) ───────────
func _render_board(canvas: Control) -> void:
	var ox: float = _get_board_origin().x
	var oy: float = _get_board_origin().y

	## 1. 하얀 목표 영역 그리기 (target_mask == 1인 칸만 선명하게 드로우)
	for ry: int in range(_board_h):
		for cx: int in range(_board_w):
			if int((_target_grid[ry] as Array)[cx]) != 1:
				continue
			var x: float = ox + float(cx) * float(CELL_SIZE)
			var y: float = oy + float(ry) * float(CELL_SIZE)
			var cell_rect := Rect2(x, y, float(CELL_SIZE), float(CELL_SIZE))

			# 화강암 석축 홈 타일 (밝은 크림/백색)
			canvas.draw_rect(cell_rect, Color("faf8f2"), true)
			# 테두리 (돌 틈새 라인)
			canvas.draw_rect(cell_rect, Color("c4b5a0"), false, 1.5)

	## 2. 배치된 성돌 조각 그리기
	for ry: int in range(_board_h):
		for cx: int in range(_board_w):
			var pid: int = int((_placed_grid[ry] as Array)[cx])
			if pid <= 0:
				continue
			var pi: int = _find_piece_idx(pid)
			var col: Color = PIECE_COLORS[pi % PIECE_COLORS.size()]
			var x: float = ox + float(cx) * float(CELL_SIZE)
			var y: float = oy + float(ry) * float(CELL_SIZE)
			var inset_rect := Rect2(x + 2.0, y + 2.0, float(CELL_SIZE) - 4.0, float(CELL_SIZE) - 4.0)

			canvas.draw_rect(inset_rect, col, true)
			canvas.draw_rect(inset_rect, col.darkened(0.25), false, 2.0)

	## 3. 드래그 중인 조각 마우스 추적 렌더링
	if _dragging_piece_idx >= 0:
		var pi: int = _dragging_piece_idx
		var shape: Array = _piece_shapes[pi]
		var col: Color = PIECE_COLORS[pi % PIECE_COLORS.size()]
		var sw: int = (shape[0] as Array).size()
		var sh: int = shape.size()

		var local_mouse := canvas.get_global_transform().affine_inverse() * _drag_pos
		var hover_cell := _local_to_cell(local_mouse)
		var top_x: int = hover_cell.x - int(float(sw) * 0.5)
		var top_y: int = hover_cell.y - int(float(sh) * 0.5)

		var best_pos := _find_best_placement(pi, top_x, top_y)
		var has_snap: bool = best_pos != Vector2i(-999, -999)
		var guide_x: int = best_pos.x if has_snap else top_x
		var guide_y: int = best_pos.y if has_snap else top_y

		# 3-1. 보드 위 유효 스냅 가이드 미리보기 (스냅 가능 시 밝은 하이라이트 + 흰 테두리, 불가 시 붉은 경고)
		for sr: int in range(sh):
			for sc: int in range(sw):
				if int((shape[sr] as Array)[sc]) != 1:
					continue
				var br: int = guide_y + sr
				var bc: int = guide_x + sc
				if _is_valid_cell(bc, br):
					var sx: float = ox + float(bc) * float(CELL_SIZE)
					var sy: float = oy + float(br) * float(CELL_SIZE)
					var ghost_rect := Rect2(sx + 2.0, sy + 2.0, float(CELL_SIZE) - 4.0, float(CELL_SIZE) - 4.0)
					if has_snap:
						var ghost_col := col
						ghost_col.a = 0.70
						canvas.draw_rect(ghost_rect, ghost_col, true)
						canvas.draw_rect(ghost_rect, Color.WHITE, false, 2.0)
					else:
						canvas.draw_rect(ghost_rect, Color(0.9, 0.2, 0.2, 0.35), true)
						canvas.draw_rect(ghost_rect, Color(0.9, 0.2, 0.2, 0.8), false, 1.5)

		# 3-2. 커서에 따라다니는 조각 본체
		var drag_origin := local_mouse - Vector2(float(sw * CELL_SIZE) * 0.5, float(sh * CELL_SIZE) * 0.5)
		for sr: int in range(sh):
			for sc: int in range(sw):
				if int((shape[sr] as Array)[sc]) != 1:
					continue
				var fx: float = drag_origin.x + float(sc) * float(CELL_SIZE)
				var fy: float = drag_origin.y + float(sr) * float(CELL_SIZE)
				var float_rect := Rect2(fx + 2.0, fy + 2.0, float(CELL_SIZE) - 4.0, float(CELL_SIZE) - 4.0)
				var float_col := col
				float_col.a = 0.88
				canvas.draw_rect(float_rect, float_col, true)
				canvas.draw_rect(float_rect, col.darkened(0.35), false, 2.0)

func _render_tray(canvas: Control) -> void:
	# 트레이 배경
	canvas.draw_rect(Rect2(0.0, 0.0, canvas.size.x, canvas.size.y), Color(0.92, 0.88, 0.80, 0.5), true)

	var title_font := ThemeDB.fallback_font
	var tray_y: float = 16.0
	var mini_cell: int = 24

	for pi: int in range(_piece_ids.size()):
		var is_placed: bool = _piece_placements[pi] != Vector2i(-1, -1)
		var is_dragging: bool = (pi == _dragging_piece_idx)
		var shape: Array = _piece_shapes[pi]
		var sh: int = shape.size()
		var sw: int = (shape[0] as Array).size()
		var piece_w: float = float(sw * mini_cell)
		var piece_h: float = float(sh * mini_cell)

		var px: float = 20.0
		var py: float = tray_y

		var col: Color = PIECE_COLORS[pi % PIECE_COLORS.size()]
		if is_placed or is_dragging:
			col = Color(0.7, 0.7, 0.7, 0.35)

		for sr: int in range(sh):
			for sc: int in range(sw):
				if int((shape[sr] as Array)[sc]) != 1:
					continue
				var rx: float = px + float(sc) * float(mini_cell)
				var ry: float = py + float(sr) * float(mini_cell)
				var blk_rect := Rect2(rx + 1.0, ry + 1.0, float(mini_cell) - 2.0, float(mini_cell) - 2.0)
				canvas.draw_rect(blk_rect, col, true)
				canvas.draw_rect(blk_rect, col.darkened(0.3), false, 1.0)

		# 조각 번호 레이블
		var lbl_str := "#%d" % _piece_ids[pi]
		if is_placed:
			lbl_str += " (배치됨)"
		canvas.draw_string(title_font, Vector2(px + piece_w + 12.0, py + piece_h * 0.5 + 5.0),
			lbl_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("5c3a21") if not is_placed else Color("888888"))

		tray_y += piece_h + 18.0

## ─────────── 좌표 변환 헬퍼 ───────────
func _get_board_origin() -> Vector2:
	if _board_h == 0 or _board_w == 0:
		return Vector2.ZERO
	var pixel_w: float = float(_board_w * CELL_SIZE)
	var pixel_h: float = float(_board_h * CELL_SIZE)
	var ox: float = maxf(10.0, (_board_draw.size.x - pixel_w) * 0.5)
	var oy: float = maxf(10.0, (_board_draw.size.y - pixel_h) * 0.5)
	return Vector2(ox, oy)

func _local_to_cell(local_pos: Vector2) -> Vector2i:
	var origin := _get_board_origin()
	var rx: float = local_pos.x - origin.x
	var ry: float = local_pos.y - origin.y
	return Vector2i(int(floorf(rx / float(CELL_SIZE))), int(floorf(ry / float(CELL_SIZE))))

func _is_valid_cell(cx: int, cy: int) -> bool:
	return cy >= 0 and cy < _board_h and cx >= 0 and cx < _board_w

func _piece_at_tray_local(local_pos: Vector2) -> int:
	var tray_y: float = 16.0
	var mini_cell: int = 24

	for pi: int in range(_piece_ids.size()):
		var shape: Array = _piece_shapes[pi]
		var sh: int = shape.size()
		var piece_h: float = float(sh * mini_cell)

		var hit_rect := Rect2(Vector2(4.0, tray_y - 4.0), Vector2(240.0, piece_h + 12.0))
		if hit_rect.has_point(local_pos):
			return pi

		tray_y += piece_h + 18.0
	return -1

func _find_piece_idx(pid: int) -> int:
	for i: int in range(_piece_ids.size()):
		if _piece_ids[i] == pid:
			return i
	return 0

func _update_score_lbl() -> void:
	var fail_count: int = _current_round - _success_count
	_score_lbl.text = "현재 성공: %d회 / 실패: %d회" % [_success_count, fail_count]

## ─────────── 유틸 ───────────
func _compute_rotations(mat: Array) -> Array:
	var res: Array = []
	var cur: Array = _deep_copy_array(mat)
	for _i: int in range(4):
		if _not_in_list(cur, res):
			res.append(_deep_copy_array(cur))
		cur = UbongoPuzzlePresets.rotate_piece_clockwise(cur)
	return res

func _not_in_list(mat: Array, lst: Array) -> bool:
	for existing: Variant in lst:
		if _arrays_equal(mat, existing as Array):
			return false
	return true

func _arrays_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for ri: int in range(a.size()):
		var ra: Array = a[ri] as Array
		var rb: Array = b[ri] as Array
		if ra.size() != rb.size():
			return false
		for ci: int in range(ra.size()):
			if int(ra[ci]) != int(rb[ci]):
				return false
	return true

func _deep_copy_array(mat: Array) -> Array:
	var res: Array = []
	for row_val: Variant in mat:
		res.append(Array(row_val as Array))
	return res
