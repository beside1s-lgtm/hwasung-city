extends Control
class_name YeonmudaeMiniGamePopup

## [연무대 군사 훈련 직접 지휘 — 볏짚 인형 활쏘기 사냥 미니게임 모달]
## - 화면 정중앙 CenterContainer 및 뷰포트 크기 동적 동기화 (해상도 무관 완벽 센터링)
## - 마우스 조준선 과녁은 오직 가상 훈련 야드(아레나) 내부에서만 작동하며 외부에서는 일반 커서 유지
## - 상단 [닫기 ✕] 버튼 및 ESC 키로 언제든 안전하게 미니게임 중단/복귀 가능
## - 총 10회(10웨이브), 비행 소요 시간 1회차 4.0초 -> 10회차 1.0초 선형 단축
## - 이전 표적 소멸 후 0.5초 ~ 3.0초 랜덤 딜레이 후 무작위 좌/우 포물선 투척
## - 마우스 이동 조준 + 좌클릭 0.5초 홀드 장전 후 릴리즈 발사
## - 성공 횟수(0~10회)에 따른 최종 훈련 배율 80% ~ 120% (0.80x ~ 1.20x) 정산

signal minigame_completed(final_multiplier: float, success_count: int)

const MAX_ROUNDS: int = 10
const REQUIRED_DRAW_TIME: float = 0.5 # 0.5초 장전 필수
const HIT_RADIUS: float = 42.0        # 명중 판정 반경 (픽셀)

# 라운드 및 성적 관리
var current_round: int = 0
var success_count: int = 0
var fail_count: int = 0

# 표적(볏짚 인형) 상태 및 궤적 변수
var dummy_active: bool = false
var dummy_pos: Vector2 = Vector2.ZERO
var dummy_velocity: Vector2 = Vector2.ZERO
var dummy_gravity: float = 0.0
var flight_duration: float = 4.0
var flight_timer: float = 0.0
var dummy_rotation: float = 0.0
var spawn_from_left: bool = true

# 스폰 대기열 변수
var is_waiting_for_spawn: bool = false
var spawn_delay_timer: float = 0.0
var target_spawn_delay: float = 0.0

# 활 장전 및 조준 상태 변수 (아레나 내부 전용)
var is_mouse_in_arena: bool = false
var is_pressing_mouse: bool = false
var draw_gauge: float = 0.0
var is_fully_loaded: bool = false
var reticle_pos: Vector2 = Vector2(374.0, 180.0)

# 시각 피드백 및 발사체
var active_arrows: Array[Dictionary] = []       # 화살 비행 궤적
var active_particles: Array[Dictionary] = []    # 볏짚 파편 파티클
var floating_texts: Array[Dictionary] = []      # 플로팅 피드백 텍스트

# 시간 제어 참조
var time_manager: TimeManager = null
var _saved_speed_mode: int = 1

# UI 컴포넌트 참조
var _backdrop: ColorRect
var _center_container: CenterContainer
var _main_panel: PanelContainer
var _close_btn: Button
var _header_title_lbl: Label
var _header_progress_lbl: Label
var _header_score_lbl: Label
var _arena_container: PanelContainer
var _arena_draw: Control
var _gauge_bar: ProgressBar
var _gauge_label: Label
var _feedback_lbl: Label
var _guide_label: Label

# 결과 패널
var _result_panel: PanelContainer
var _result_summary_lbl: Label
var _result_detail_lbl: Label
var _result_confirm_btn: Button

func _init() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _main_panel == null:
		_build_ui()
	call_deferred("_sync_viewport_size")
	if is_inside_tree() and get_viewport():
		get_viewport().size_changed.connect(_sync_viewport_size)
	visible = false
	if _backdrop:
		_backdrop.visible = false
	if _center_container:
		_center_container.visible = false
	set_process(false)
	set_process_input(false)

func _sync_viewport_size() -> void:
	if not is_inside_tree() or get_viewport() == null:
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	if vp_size.x > 0.0 and vp_size.y > 0.0:
		set_deferred("size", vp_size)
		if _backdrop:
			_backdrop.set_deferred("size", vp_size)
		if _center_container:
			_center_container.set_deferred("size", vp_size)

func _build_ui() -> void:
	if _main_panel != null:
		return

	# 1. 화면 전체 어두운 야간/연무장 반투명 배경 (외부 클릭 흡수로 월드 보호)
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.04, 0.06, 0.10, 0.88)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	# 2. 화면 정중앙 배치용 CenterContainer (PRESET_FULL_RECT)
	_center_container = CenterContainer.new()
	_center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center_container)

	# 3. 메인 프레임 패널 (780 x 560 고정)
	_main_panel = PanelContainer.new()
	_main_panel.custom_minimum_size = Vector2(780, 560)
	_main_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var main_sb := StyleBoxFlat.new()
	main_sb.bg_color = Color(0.12, 0.14, 0.18, 0.98) # 고즈넉한 무예청 밤색
	main_sb.border_color = Color(0.82, 0.68, 0.38)     # 금박 황동 테두리
	main_sb.set_border_width_all(3)
	main_sb.set_corner_radius_all(10)
	main_sb.shadow_color = Color(0, 0, 0, 0.65)
	main_sb.shadow_size = 16
	main_sb.set_content_margin_all(14)
	_main_panel.add_theme_stylebox_override("panel", main_sb)
	_center_container.add_child(_main_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 8)
	_main_panel.add_child(root_vbox)

	# 4. 상단 헤더 바 (타이틀 + 진행도 + 닫기 버튼)
	var header_hb := HBoxContainer.new()
	root_vbox.add_child(header_hb)

	_header_title_lbl = Label.new()
	_header_title_lbl.text = "🏹 [연무대 군사 훈련 직접 지휘 — 볏짚 인형 활쏘기]"
	_header_title_lbl.add_theme_font_size_override("font_size", 16)
	_header_title_lbl.add_theme_color_override("font_color", Color("fef3c7"))
	_header_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hb.add_child(_header_title_lbl)

	_header_progress_lbl = Label.new()
	_header_progress_lbl.text = "진행: 1 / 10회"
	_header_progress_lbl.add_theme_font_size_override("font_size", 14)
	_header_progress_lbl.add_theme_color_override("font_color", Color("93c5fd"))
	header_hb.add_child(_header_progress_lbl)

	# 상단 우측 [닫기 ✕] 버튼
	_close_btn = Button.new()
	_close_btn.text = "닫기 ✕"
	_close_btn.custom_minimum_size = Vector2(64, 28)
	_close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_close_btn.pressed.connect(func(): close_minigame(true))

	var close_sb := StyleBoxFlat.new()
	close_sb.bg_color = Color(0.40, 0.16, 0.16)
	close_sb.border_color = Color(0.85, 0.40, 0.40)
	close_sb.set_border_width_all(1)
	close_sb.set_corner_radius_all(4)
	close_sb.set_content_margin_all(4)
	_close_btn.add_theme_stylebox_override("normal", close_sb)

	var close_sb_h := close_sb.duplicate() as StyleBoxFlat
	close_sb_h.bg_color = Color(0.58, 0.22, 0.22)
	_close_btn.add_theme_stylebox_override("hover", close_sb_h)
	header_hb.add_child(_close_btn)

	var header_sub_hb := HBoxContainer.new()
	root_vbox.add_child(header_sub_hb)

	_header_score_lbl = Label.new()
	_header_score_lbl.text = "현재 성적: 성공 0회 / 실패 0회 | 예상 훈련 보정: 0% (1.00x)"
	_header_score_lbl.add_theme_font_size_override("font_size", 13)
	_header_score_lbl.add_theme_color_override("font_color", Color("e2e8f0"))
	_header_score_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_sub_hb.add_child(_header_score_lbl)

	# 5. 중앙 가상 훈련 야드 아레나
	_arena_container = PanelContainer.new()
	_arena_container.custom_minimum_size = Vector2(752, 370)
	_arena_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_arena_container.mouse_filter = Control.MOUSE_FILTER_STOP # 아레나 영역 입력 전용 흡수
	_arena_container.mouse_entered.connect(_on_arena_mouse_entered)
	_arena_container.mouse_exited.connect(_on_arena_mouse_exited)
	_arena_container.gui_input.connect(_on_arena_gui_input)

	var arena_sb := StyleBoxFlat.new()
	arena_sb.bg_color = Color(0.08, 0.10, 0.14)
	arena_sb.border_color = Color(0.35, 0.40, 0.50)
	arena_sb.set_border_width_all(2)
	arena_sb.set_corner_radius_all(6)
	_arena_container.add_theme_stylebox_override("panel", arena_sb)
	root_vbox.add_child(_arena_container)

	_arena_draw = Control.new()
	_arena_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arena_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena_draw.draw.connect(_on_arena_draw)
	_arena_container.add_child(_arena_draw)

	# 장전 게이지 UI (아레나 하단 중앙)
	var gauge_hb := HBoxContainer.new()
	gauge_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	gauge_hb.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	gauge_hb.offset_top = -42
	gauge_hb.offset_bottom = -12
	gauge_hb.offset_left = -180
	gauge_hb.offset_right = 180
	gauge_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena_container.add_child(gauge_hb)

	_gauge_bar = ProgressBar.new()
	_gauge_bar.custom_minimum_size = Vector2(260, 22)
	_gauge_bar.min_value = 0.0
	_gauge_bar.max_value = 100.0
	_gauge_bar.value = 0.0
	_gauge_bar.show_percentage = false
	_gauge_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g_sb_bg := StyleBoxFlat.new()
	g_sb_bg.bg_color = Color(0.15, 0.18, 0.22, 0.9)
	g_sb_bg.set_corner_radius_all(4)
	_gauge_bar.add_theme_stylebox_override("background", g_sb_bg)
	var g_sb_fill := StyleBoxFlat.new()
	g_sb_fill.bg_color = Color(0.95, 0.75, 0.25)
	g_sb_fill.set_corner_radius_all(4)
	_gauge_bar.add_theme_stylebox_override("fill", g_sb_fill)
	gauge_hb.add_child(_gauge_bar)

	_gauge_label = Label.new()
	_gauge_label.text = "장전 대기"
	_gauge_label.add_theme_font_size_override("font_size", 12)
	_gauge_label.add_theme_color_override("font_color", Color("fef08a"))
	_gauge_label.custom_minimum_size = Vector2(80, 22)
	_gauge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gauge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge_hb.add_child(_gauge_label)

	# 피드백 라벨 (아레나 중앙 상단)
	_feedback_lbl = Label.new()
	_feedback_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_feedback_lbl.offset_top = 18
	_feedback_lbl.add_theme_font_size_override("font_size", 18)
	_feedback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_lbl.visible = false
	_arena_container.add_child(_feedback_lbl)

	# 6. 하단 키 매뉴얼 HUD 고정 패널
	var guide_panel := PanelContainer.new()
	guide_panel.custom_minimum_size = Vector2(752, 42)
	var g_panel_sb := StyleBoxFlat.new()
	g_panel_sb.bg_color = Color(0.18, 0.22, 0.28, 0.95)
	g_panel_sb.border_color = Color(0.45, 0.55, 0.65)
	g_panel_sb.set_border_width_all(1)
	g_panel_sb.set_corner_radius_all(6)
	g_panel_sb.set_content_margin_all(8)
	guide_panel.add_theme_stylebox_override("panel", g_panel_sb)
	root_vbox.add_child(guide_panel)

	_guide_label = Label.new()
	_guide_label.text = "🎯 [조작: 움직여 조준 | 왼쪽 단추를 누른 채: 활 장전 (0.5초) | 단추 떼기: 발사 (연속 사격 가능) | Esc 글쇠: 닫기]"
	_guide_label.add_theme_font_size_override("font_size", 13)
	_guide_label.add_theme_color_override("font_color", Color("fef3c7"))
	_guide_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide_panel.add_child(_guide_label)

	# 7. 결과 정산 오버레이 패널
	_build_result_panel()

func _build_result_panel() -> void:
	_result_panel = PanelContainer.new()
	_result_panel.custom_minimum_size = Vector2(460, 260)
	_result_panel.set_anchors_preset(Control.PRESET_CENTER)
	_result_panel.offset_left = -230
	_result_panel.offset_top = -130
	_result_panel.offset_right = 230
	_result_panel.offset_bottom = 130
	_result_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.14, 0.98)
	sb.border_color = Color(0.85, 0.70, 0.35)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.7)
	sb.shadow_size = 18
	sb.set_content_margin_all(20)
	_result_panel.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	_result_panel.add_child(vb)

	var title_lbl := Label.new()
	title_lbl.text = "🏹 연무대 군사 훈련 사열 성료"
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color("fef08a"))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title_lbl)

	_result_summary_lbl = Label.new()
	_result_summary_lbl.text = "총 10회 중 [0회 성공 / 0회 실패]"
	_result_summary_lbl.add_theme_font_size_override("font_size", 15)
	_result_summary_lbl.add_theme_color_override("font_color", Color("e2e8f0"))
	_result_summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_result_summary_lbl)

	_result_detail_lbl = Label.new()
	_result_detail_lbl.text = "최종 훈련 효과 보정: 0% (1.00x)"
	_result_detail_lbl.add_theme_font_size_override("font_size", 14)
	_result_detail_lbl.add_theme_color_override("font_color", Color("38bdf8"))
	_result_detail_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_result_detail_lbl)

	_result_confirm_btn = Button.new()
	_result_confirm_btn.text = "확인 및 훈련 성료"
	_result_confirm_btn.custom_minimum_size = Vector2(180, 38)
	_result_confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_result_confirm_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_confirm_btn.pressed.connect(_on_result_confirmed)

	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.20, 0.35, 0.22)
	btn_sb.border_color = Color(0.70, 0.90, 0.70)
	btn_sb.set_border_width_all(2)
	btn_sb.set_corner_radius_all(6)
	_result_confirm_btn.add_theme_stylebox_override("normal", btn_sb)

	var btn_hb := HBoxContainer.new()
	btn_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hb.add_child(_result_confirm_btn)
	vb.add_child(btn_hb)

	_result_panel.visible = false
	_center_container.add_child(_result_panel)

## =========================================================================
## 미니게임 시작 및 제어
## =========================================================================
func start_yeonmudae_minigame(p_time_manager: TimeManager = null) -> void:
	if _main_panel == null:
		_build_ui()
	time_manager = p_time_manager
	if time_manager != null:
		_saved_speed_mode = int(time_manager.current_speed)
		time_manager.set_speed(TimeManager.SpeedMode.PAUSE)

	_sync_viewport_size()
	visible = true
	if _backdrop:
		_backdrop.visible = true
	if _center_container:
		_center_container.visible = true
	set_process(true)
	set_process_input(true)

	current_round = 0
	success_count = 0
	fail_count = 0
	dummy_active = false
	is_waiting_for_spawn = false
	is_mouse_in_arena = false
	is_pressing_mouse = false
	draw_gauge = 0.0
	is_fully_loaded = false
	if _gauge_bar != null:
		_gauge_bar.value = 0.0
	if _gauge_label != null:
		_gauge_label.text = "장전 대기"

	active_arrows.clear()
	active_particles.clear()
	floating_texts.clear()

	_result_panel.visible = false
	_update_header_stats()

	_trigger_spawn_sequence()

func close_minigame(canceled: bool = false) -> void:
	dummy_active = false
	is_waiting_for_spawn = false
	is_mouse_in_arena = false
	is_pressing_mouse = false
	draw_gauge = 0.0
	is_fully_loaded = false

	visible = false
	if _backdrop:
		_backdrop.visible = false
	if _center_container:
		_center_container.visible = false
	set_process(false)
	set_process_input(false)

	# 시간 복원
	if time_manager != null:
		time_manager.set_speed(_saved_speed_mode as TimeManager.SpeedMode)

	if canceled:
		# 사용자가 중도 닫기를 누른 경우 기본 100% 보상 또는 현재까지 성공 수로 종료
		var bonus_pct: int = (success_count - 5) * 4
		var final_mult: float = 1.0 + float(bonus_pct) / 100.0
		emit_signal("minigame_completed", final_mult, success_count)

func _trigger_spawn_sequence() -> void:
	if current_round >= MAX_ROUNDS:
		_finish_minigame()
		return

	is_waiting_for_spawn = true
	dummy_active = false
	spawn_delay_timer = 0.0
	# 이전 표적이 사라진 후 0.5초 ~ 3.0초 사이 랜덤 대기
	target_spawn_delay = randf_range(0.5, 3.0)

func _spawn_straw_dummy() -> void:
	current_round += 1
	if current_round > MAX_ROUNDS:
		_finish_minigame()
		return

	dummy_active = true
	flight_timer = 0.0
	dummy_rotation = 0.0

	# 1회차 4.0초 -> 10회차 1.0초 선형 감소 공식: T(r) = 4.0 - ((r - 1) / 9.0) * 3.0
	var progress_ratio: float = float(current_round - 1) / float(MAX_ROUNDS - 1)
	flight_duration = 4.0 - progress_ratio * 3.0

	var arena_sz: Vector2 = _arena_container.size
	if arena_sz.x <= 10.0:
		arena_sz = Vector2(752.0, 370.0)

	# 좌측 또는 우측 무작위 스폰
	spawn_from_left = (randi() % 2 == 0)
	var start_x: float = 40.0 if spawn_from_left else (arena_sz.x - 40.0)
	var end_x: float = (arena_sz.x - 40.0) if spawn_from_left else 40.0

	var start_y: float = arena_sz.y - 70.0
	var peak_y: float = 70.0
	var height_diff: float = start_y - peak_y # 약 230px 포물선 정점 높이

	dummy_pos = Vector2(start_x, start_y)

	# 정밀 포물선 역학 계산 (정확히 flight_duration 동안 반대편에 착지)
	var vx: float = (end_x - start_x) / flight_duration
	dummy_gravity = (8.0 * height_diff) / (flight_duration * flight_duration)
	var vy: float = -(4.0 * height_diff) / flight_duration
	dummy_velocity = Vector2(vx, vy)

	_update_header_stats()

func _update_header_stats() -> void:
	_header_progress_lbl.text = "진행: %d / %d회" % [mini(current_round, MAX_ROUNDS), MAX_ROUNDS]
	var bonus_pct: int = (success_count - 5) * 4
	var final_mult: float = 1.0 + float(bonus_pct) / 100.0
	var sign_str: String = ("+" if bonus_pct > 0 else "") + str(bonus_pct) + "%"
	_header_score_lbl.text = "현재 성적: 성공 %d회 / 실패 %d회 | 예상 훈련 보정: %s (%.2f배)" % [
		success_count, fail_count, sign_str, final_mult
	]

## =========================================================================
## 아레나 영역 전용 마우스 입력 및 격리 핸들러
## =========================================================================
func _on_arena_mouse_entered() -> void:
	is_mouse_in_arena = true
	_arena_draw.queue_redraw()

func _on_arena_mouse_exited() -> void:
	is_mouse_in_arena = false
	if is_pressing_mouse:
		is_pressing_mouse = false
		draw_gauge = 0.0
		is_fully_loaded = false
		_gauge_bar.value = 0.0
		_gauge_label.text = "장전 대기"
	_arena_draw.queue_redraw()

func _on_arena_gui_input(event: InputEvent) -> void:
	if not visible:
		return

	# 1. 마우스 조준선 트래킹 (아레나 로컬 좌표)
	if event is InputEventMouseMotion:
		reticle_pos = event.position
		is_mouse_in_arena = true
		_arena_draw.queue_redraw()
		_arena_container.accept_event()

	# 2. 마우스 좌클릭 장전 및 발사
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 클릭 시작 -> 장전 가동
				is_pressing_mouse = true
				draw_gauge = 0.0
				is_fully_loaded = false
				_gauge_bar.value = 0.0
				_gauge_label.text = "장전 중..."
			else:
				# 클릭 떼기 -> 화살 발사!
				is_pressing_mouse = false
				if is_fully_loaded:
					_fire_arrow(reticle_pos)
				else:
					_on_draw_failed(reticle_pos)

				draw_gauge = 0.0
				is_fully_loaded = false
				_gauge_bar.value = 0.0
				_gauge_label.text = "장전 대기"

			_arena_container.accept_event()

## 전역 ESC 키 닫기 및 키보드 입력 방어
func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			close_minigame(true)
			get_viewport().set_input_as_handled()
			return
		# 미니게임 진행 중 기타 키보드 입력이 월드 카메라로 전파되지 않도록 차단
		get_viewport().set_input_as_handled()

func _on_draw_failed(pos: Vector2) -> void:
	# 0.5초 장전 미달 시 발사 실패 피드백
	_spawn_floating_text("장전 부족! (0.5초 필요)", pos, Color("ef4444"))

func _fire_arrow(target_pos: Vector2) -> void:
	var arena_sz: Vector2 = _arena_container.size
	if arena_sz.x <= 10.0:
		arena_sz = Vector2(752.0, 370.0)

	var archer_base_pos := Vector2(arena_sz.x * 0.5, arena_sz.y - 30.0)

	# 화살 비행 생성
	active_arrows.append({
		"start_pos": archer_base_pos,
		"target_pos": target_pos,
		"pos": archer_base_pos,
		"progress": 0.0,
		"speed": 12.0 # 0.08초 만에 도달
	})

	# 표적이 활성화되어 있고 조준선 반경 내에 있으면 명중 판정
	if dummy_active:
		var dist: float = target_pos.distance_to(dummy_pos)
		if dist <= HIT_RADIUS:
			# 명중!
			dummy_active = false
			success_count += 1
			_play_hit_vfx(dummy_pos)
			_spawn_floating_text("🎯 명중!", dummy_pos + Vector2(0, -20), Color("4ade80"))
			_update_header_stats()
			_trigger_spawn_sequence()
		else:
			_spawn_floating_text("빗나감!", target_pos, Color("f97316"))
	else:
		_spawn_floating_text("허공 사격", target_pos, Color("94a3b8"))

func _play_hit_vfx(pos: Vector2) -> void:
	# 볏짚 파편 파티클 14개 방출
	for i in range(14):
		var ang: float = randf_range(0.0, TAU)
		var spd: float = randf_range(90.0, 220.0)
		var p_vel := Vector2(cos(ang) * spd, sin(ang) * spd)
		var p_col: Color = Color("d97706") if (i % 2 == 0) else Color("fbbf24")
		active_particles.append({
			"pos": pos,
			"vel": p_vel,
			"life": 0.0,
			"max_life": randf_range(0.35, 0.65),
			"color": p_col,
			"size": randf_range(3.0, 6.0)
		})

func _spawn_floating_text(text: String, pos: Vector2, col: Color) -> void:
	floating_texts.append({
		"text": text,
		"pos": pos,
		"color": col,
		"timer": 0.0,
		"duration": 0.7
	})

## =========================================================================
## 메인 갱신 루프
## =========================================================================
func _process(delta: float) -> void:
	# 1. 스폰 대기 타이머
	if is_waiting_for_spawn:
		spawn_delay_timer += delta
		if spawn_delay_timer >= target_spawn_delay:
			is_waiting_for_spawn = false
			_spawn_straw_dummy()

	# 2. 볏짚 인형 포물선 비행 연산
	if dummy_active:
		flight_timer += delta
		dummy_velocity.y += dummy_gravity * delta
		dummy_pos += dummy_velocity * delta
		dummy_rotation += 220.0 * delta

		var arena_sz: Vector2 = _arena_container.size
		if arena_sz.x <= 10.0:
			arena_sz = Vector2(752.0, 370.0)

		# 시간 초과 또는 지면 도달 시 실패 처리
		if flight_timer >= flight_duration or dummy_pos.y > (arena_sz.y - 30.0):
			dummy_active = false
			fail_count += 1
			_spawn_floating_text("놓침!", dummy_pos, Color("ef4444"))
			_update_header_stats()
			_trigger_spawn_sequence()

	# 3. 활 장전 게이지 갱신 (0.5초 장전 필수)
	if is_pressing_mouse and not is_fully_loaded:
		draw_gauge += delta
		var ratio: float = clampf(draw_gauge / REQUIRED_DRAW_TIME, 0.0, 1.0)
		if _gauge_bar != null:
			_gauge_bar.value = ratio * 100.0
		if draw_gauge >= REQUIRED_DRAW_TIME:
			is_fully_loaded = true
			if _gauge_bar != null:
				_gauge_bar.value = 100.0
			if _gauge_label != null:
				_gauge_label.text = "⚡ 발사 준비 완료!"

	# 4. 화살 궤적 업데이트
	var finished_arrows: Array[int] = []
	for i in range(active_arrows.size()):
		var arr: Dictionary = active_arrows[i]
		var spd: float = float(arr["speed"])
		arr["progress"] = float(arr["progress"]) + spd * delta
		var prog: float = clampf(float(arr["progress"]), 0.0, 1.0)
		var sp: Vector2 = arr["start_pos"]
		var tp: Vector2 = arr["target_pos"]
		arr["pos"] = sp.lerp(tp, prog)
		if prog >= 1.0:
			finished_arrows.append(i)

	for i in range(finished_arrows.size() - 1, -1, -1):
		active_arrows.remove_at(finished_arrows[i])

	# 5. 파티클 업데이트
	var finished_parts: Array[int] = []
	for i in range(active_particles.size()):
		var pt: Dictionary = active_particles[i]
		pt["life"] = float(pt["life"]) + delta
		var l: float = float(pt["life"])
		var ml: float = float(pt["max_life"])
		if l >= ml:
			finished_parts.append(i)
		else:
			var vel: Vector2 = pt["vel"]
			vel.y += 300.0 * delta # 중력
			pt["vel"] = vel
			pt["pos"] = Vector2(pt["pos"]) + vel * delta

	for i in range(finished_parts.size() - 1, -1, -1):
		active_particles.remove_at(finished_parts[i])

	# 6. 플로팅 텍스트 업데이트
	var finished_texts: Array[int] = []
	for i in range(floating_texts.size()):
		var ft: Dictionary = floating_texts[i]
		ft["timer"] = float(ft["timer"]) + delta
		var t: float = float(ft["timer"])
		var dur: float = float(ft["duration"])
		if t >= dur:
			finished_texts.append(i)
		else:
			var pos: Vector2 = ft["pos"]
			pos.y -= 25.0 * delta # 위로 떠오름
			ft["pos"] = pos

	for i in range(finished_texts.size() - 1, -1, -1):
		floating_texts.remove_at(finished_texts[i])

	_arena_draw.queue_redraw()

## =========================================================================
## 아레나 2D 캔버스 드로우 (훈련장 배경, 병사, 볏짚, 화살, 조준선)
## =========================================================================
func _on_arena_draw() -> void:
	var sz: Vector2 = _arena_container.size
	if sz.x <= 10.0:
		sz = Vector2(752.0, 370.0)

	# 1) 가상 훈련 야드 배경 (훈련장 흙바닥과 토성)
	var ground_y: float = sz.y - 60.0

	# 하늘 그라데이션
	_arena_draw.draw_rect(Rect2(0, 0, sz.x, ground_y), Color(0.10, 0.14, 0.22), true)
	# 원경 토성/성벽 실루엣
	_arena_draw.draw_rect(Rect2(0, ground_y - 45.0, sz.x, 45.0), Color(0.18, 0.22, 0.30), true)
	_arena_draw.draw_line(Vector2(0, ground_y - 45.0), Vector2(sz.x, ground_y - 45.0), Color(0.35, 0.42, 0.52), 2.0)

	# 훈련장 황토 흙바닥
	_arena_draw.draw_rect(Rect2(0, ground_y, sz.x, sz.y - ground_y), Color(0.36, 0.28, 0.18), true)
	_arena_draw.draw_line(Vector2(0, ground_y), Vector2(sz.x, ground_y), Color(0.55, 0.42, 0.28), 3.0)

	# 2) 좌우 투척 대기 병사 (장용영 군관 및 병사 실루엣)
	_draw_soldier(Vector2(45.0, ground_y + 10.0), true)
	_draw_soldier(Vector2(sz.x - 45.0, ground_y + 10.0), false)

	# 중앙 하단 사수 (플레이어 측 사대 활시위 실루엣)
	_draw_player_archer(Vector2(sz.x * 0.5, sz.y - 15.0))

	# 3) 날아가는 볏짚 인형 (StrawDummy)
	if dummy_active:
		_draw_straw_dummy(dummy_pos, dummy_rotation)

	# 4) 날아가는 화살들
	for arr in active_arrows:
		var p: Vector2 = arr["pos"]
		var tp: Vector2 = arr["target_pos"]
		var dir_vec: Vector2 = (tp - Vector2(arr["start_pos"])).normalized()
		var arrow_tail: Vector2 = p - dir_vec * 22.0
		_arena_draw.draw_line(arrow_tail, p, Color("fef08a"), 2.5)
		_arena_draw.draw_circle(p, 2.5, Color("ffffff"))

	# 5) 파티클
	for pt in active_particles:
		var p: Vector2 = pt["pos"]
		var col: Color = pt["color"]
		var l: float = float(pt["life"])
		var ml: float = float(pt["max_life"])
		var alpha: float = clampf(1.0 - (l / ml), 0.0, 1.0)
		col.a = alpha
		var p_sz: float = float(pt["size"])
		_arena_draw.draw_rect(Rect2(p.x - p_sz * 0.5, p.y - p_sz * 0.5, p_sz, p_sz), col, true)

	# 6) 조준선 과녁 포인터 (Reticle) — 오직 마우스가 아레나 안에 있을 때만 표시
	if is_mouse_in_arena:
		_draw_reticle(reticle_pos)

	# 7) 플로팅 텍스트
	var font: Font = ThemeDB.fallback_font
	for ft in floating_texts:
		var text: String = ft["text"]
		var p: Vector2 = ft["pos"]
		var col: Color = ft["color"]
		var t: float = float(ft["timer"])
		var dur: float = float(ft["duration"])
		col.a = clampf(1.0 - (t / dur), 0.0, 1.0)
		if font:
			_arena_draw.draw_string(font, p + Vector2(-40, 0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, col)

func _draw_soldier(p: Vector2, face_right: bool) -> void:
	var col_body := Color(0.20, 0.30, 0.45) # 군복 감색
	var col_hat := Color(0.12, 0.12, 0.15)  # 벙거지 흑색
	var col_skin := Color(0.85, 0.68, 0.52) # 살구색
	var dir_mul: float = 1.0 if face_right else -1.0

	# 몸체
	_arena_draw.draw_rect(Rect2(p.x - 8.0, p.y - 28.0, 16.0, 24.0), col_body, true)
	# 얼굴
	_arena_draw.draw_circle(Vector2(p.x, p.y - 34.0), 6.0, col_skin)
	# 벙거지 모자
	_arena_draw.draw_rect(Rect2(p.x - 10.0, p.y - 41.0, 20.0, 4.0), col_hat, true)
	_arena_draw.draw_rect(Rect2(p.x - 6.0, p.y - 46.0, 12.0, 5.0), col_hat, true)
	# 팔 (투척 포즈)
	_arena_draw.draw_line(Vector2(p.x, p.y - 24.0), Vector2(p.x + dir_mul * 14.0, p.y - 32.0), col_body, 3.5)

func _draw_player_archer(p: Vector2) -> void:
	# 사대 깃발 및 플레이어 국궁 실루엣
	var col_bow := Color(0.78, 0.58, 0.35)
	_arena_draw.draw_arc(p + Vector2(0, -10), 20.0, -PI * 0.85, -PI * 0.15, 12, col_bow, 3.0)
	_arena_draw.draw_line(p + Vector2(-15, -10), p + Vector2(15, -10), Color(0.9, 0.9, 0.9, 0.7), 1.5)

func _draw_straw_dummy(p: Vector2, rot_deg: float) -> void:
	# 볏짚 인형 (StrawDummy) 회전 렌더링
	var col_straw := Color(0.82, 0.65, 0.30)      # 볏짚 황토색
	var col_straw_dark := Color(0.55, 0.40, 0.18) # 볏짚 음영
	var col_band := Color(0.75, 0.20, 0.20)       # 붉은 십자 띠
	var radius: float = 22.0

	var rot_rad: float = deg_to_rad(rot_deg)
	var forward := Vector2(cos(rot_rad), sin(rot_rad))
	var right := Vector2(-sin(rot_rad), cos(rot_rad))

	# 원형 볏짚 타깃 몸체
	_arena_draw.draw_circle(p, radius, col_straw)
	_arena_draw.draw_circle(p, radius * 0.65, col_straw_dark)
	_arena_draw.draw_circle(p, radius * 0.35, col_straw)

	# 십자 붉은 띠
	var p_top: Vector2 = p - forward * radius
	var p_bot: Vector2 = p + forward * radius
	var p_left: Vector2 = p - right * radius
	var p_right: Vector2 = p + right * radius
	_arena_draw.draw_line(p_top, p_bot, col_band, 3.0)
	_arena_draw.draw_line(p_left, p_right, col_band, 3.0)

	# 볏짚 수염 깃털 디테일
	for i in range(4):
		var ang: float = rot_rad + float(i) * (PI * 0.5) + 0.3
		var whisker_p: Vector2 = p + Vector2(cos(ang), sin(ang)) * (radius + 4.0)
		_arena_draw.draw_circle(whisker_p, 2.5, col_straw)

func _draw_reticle(p: Vector2) -> void:
	var col_reticle: Color = Color("38bdf8")
	if is_fully_loaded:
		col_reticle = Color("facc15") # 장전 완료 시 금빛 과녁으로 변경
	elif is_pressing_mouse:
		col_reticle = Color("f97316") # 장전 중 주황빛

	# 외곽 원형 링
	_arena_draw.draw_arc(p, 18.0, 0.0, TAU, 24, col_reticle, 2.0)
	# 십자 핀
	_arena_draw.draw_line(p + Vector2(-26.0, 0.0), p + Vector2(-8.0, 0.0), col_reticle, 2.0)
	_arena_draw.draw_line(p + Vector2(8.0, 0.0), p + Vector2(26.0, 0.0), col_reticle, 2.0)
	_arena_draw.draw_line(p + Vector2(0.0, -26.0), p + Vector2(0.0, -8.0), col_reticle, 2.0)
	_arena_draw.draw_line(p + Vector2(0.0, 8.0), p + Vector2(0.0, 26.0), col_reticle, 2.0)
	# 중앙 붉은 점
	_arena_draw.draw_circle(p, 2.5, Color("ef4444"))

## =========================================================================
## 종료 및 정산
## =========================================================================
func _finish_minigame() -> void:
	dummy_active = false
	is_waiting_for_spawn = false
	is_mouse_in_arena = false
	is_pressing_mouse = false

	# 10회 성공: +20% (1.20x) / 5회 성공: 0% (1.00x) / 0회 성공: -20% (0.80x)
	var bonus_pct: int = (success_count - 5) * 4
	var final_mult: float = 1.0 + float(bonus_pct) / 100.0

	var sign_str: String = ("+" if bonus_pct > 0 else "") + str(bonus_pct) + "%"
	_result_summary_lbl.text = "총 10회 중 [%d회 성공 / %d회 실패]" % [success_count, fail_count]
	_result_detail_lbl.text = "최종 훈련 효과 보정: %s (%.2f배)" % [sign_str, final_mult]

	_result_panel.visible = true

func _on_result_confirmed() -> void:
	var bonus_pct: int = (success_count - 5) * 4
	var final_mult: float = 1.0 + float(bonus_pct) / 100.0

	_result_panel.visible = false
	visible = false
	set_process(false)
	set_process_input(false)

	# 시간 복원
	if time_manager != null:
		time_manager.set_speed(_saved_speed_mode as TimeManager.SpeedMode)

	emit_signal("minigame_completed", final_mult, success_count)
