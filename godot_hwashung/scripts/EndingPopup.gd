extends CanvasLayer
class_name EndingPopup

## 1800년 정조 승하 및 화성성역 12대 멀티 엔딩 전용 모달 연출
## - 엄숙한 페이드인 연출 및 정조 승하 나레이션
## - 12대 엔딩별 고유 타이틀, 부제, 고증 에필로그 및 상징 문양
## - 11년간의 최종 치세 실록(인구, 국고, 군량, 완공도, 방호력, 학문력, 민심, 왕권, 세자 교육, 친림, 탕평, 을묘, 실학) 결산
## - 실록 세이브, 새로운 치세 시작(타이틀 복귀), 화성 계속 살펴보기 기능 제공

signal popup_closed
signal save_requested
signal restart_requested

@onready var bg_rect: ColorRect = $DimBackground
@onready var modal_container: CenterContainer = $CenterContainer
@onready var main_panel: PanelContainer = $CenterContainer/MainPanel

@onready var label_passing: Label = $CenterContainer/MainPanel/VBox/Header/PassingNotice
@onready var label_title: Label = $CenterContainer/MainPanel/VBox/Header/EndingTitle
@onready var label_subtitle: Label = $CenterContainer/MainPanel/VBox/Header/EndingSubtitle

@onready var art_container: PanelContainer = $CenterContainer/MainPanel/VBox/ArtContainer
@onready var art_label: Label = $CenterContainer/MainPanel/VBox/ArtContainer/ArtText

@onready var content_scroll: ScrollContainer = $CenterContainer/MainPanel/VBox/ContentScroll
@onready var label_desc: Label = $CenterContainer/MainPanel/VBox/ContentScroll/StoryText
@onready var stats_container: GridContainer = $CenterContainer/MainPanel/VBox/StatsSection/StatsGrid

@onready var btn_save: Button = $CenterContainer/MainPanel/VBox/Buttons/BtnSave
@onready var btn_restart: Button = $CenterContainer/MainPanel/VBox/Buttons/BtnRestart
@onready var btn_continue: Button = $CenterContainer/MainPanel/VBox/Buttons/BtnContinue

var _ending_data: Dictionary = {}
var _sim: SimulationCore = null
var _grid: GameGrid = null
var _time_mgr: TimeManager = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 150

	btn_save.pressed.connect(_on_save_pressed)
	btn_restart.pressed.connect(_on_restart_pressed)
	btn_continue.pressed.connect(_on_continue_pressed)

	# 초기 페이드인 효과
	bg_rect.modulate.a = 0.0
	main_panel.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(bg_rect, "modulate:a", 1.0, 1.0)
	tween.tween_property(main_panel, "modulate:a", 1.0, 1.0)

func _bind_nodes_safe() -> void:
	if label_title == null:
		label_title = get_node_or_null("CenterContainer/MainPanel/VBox/Header/EndingTitle") as Label
	if label_subtitle == null:
		label_subtitle = get_node_or_null("CenterContainer/MainPanel/VBox/Header/EndingSubtitle") as Label
	if label_desc == null:
		label_desc = get_node_or_null("CenterContainer/MainPanel/VBox/ContentScroll/StoryText") as Label
	if art_label == null:
		art_label = get_node_or_null("CenterContainer/MainPanel/VBox/ArtContainer/ArtText") as Label
	if stats_container == null:
		stats_container = get_node_or_null("CenterContainer/MainPanel/VBox/StatsSection/StatsGrid") as GridContainer
	if bg_rect == null:
		bg_rect = get_node_or_null("DimBackground") as ColorRect
	if main_panel == null:
		main_panel = get_node_or_null("CenterContainer/MainPanel") as PanelContainer

func display_ending(data: Dictionary, s: SimulationCore, g: GameGrid, tm: TimeManager) -> void:
	_ending_data = data
	_sim = s
	_grid = g
	_time_mgr = tm

	_bind_nodes_safe()

	# 시뮬레이션 일시 정지 보장
	if _time_mgr:
		_time_mgr.set_speed(TimeManager.SpeedMode.PAUSE)

	var _ending_type: String = String(data.get("type", "TRUE_RENAISSANCE"))
	var year_val: int = int(data.get("year", (_time_mgr.current_year if _time_mgr else 1800)))
	if label_passing:
		if _ending_type == "BANDIT_FALL" or year_val < 1800:
			label_passing.text = "조선 정조 %d년, 흉포한 도적 떼의 난입으로 화성행궁 함락" % year_val
		else:
			label_passing.text = "경신년(1800년) 6월 28일, 정조 대왕 승하(昇遐)"

	if label_title:
		label_title.text = String(data.get("title", "대조선 문예 부흥 [참 결말]"))
	if label_subtitle:
		label_subtitle.text = String(data.get("subtitle", ""))
	if label_desc:
		label_desc.text = String(data.get("desc", ""))

	# 12대 엔딩 타입별 테마 색상 및 상징 아트 스타일
	_apply_12_endings_theme(data)

	# 최종 치세 지표 동적 바인딩
	_populate_stats(data)

## 12대 엔딩별 고유 테마 컬러 및 상징 스타일 적용
func _apply_12_endings_theme(d: Dictionary) -> void:
	var color_hex: String = String(d.get("theme_color", "b8860b"))
	var title_col: Color = Color(color_hex)
	var art_tag: String = String(d.get("art_tag", ""))

	if label_title:
		label_title.add_theme_color_override("font_color", title_col)
	if art_label:
		art_label.text = art_tag

	var art_style: StyleBoxFlat = StyleBoxFlat.new()
	# 어두운 배경과 테두리 색상 조합
	art_style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	art_style.border_color = title_col
	art_style.set_border_width_all(2)
	art_style.set_corner_radius_all(4)
	art_style.set_content_margin_all(8)
	if art_container:
		art_container.add_theme_stylebox_override("panel", art_style)

## 11년간의 최종 치세 실록(1789~1800) 통계 렌더링
func _populate_stats(d: Dictionary) -> void:
	if stats_container == null:
		return
	for child in stats_container.get_children():
		child.queue_free()

	var stats: Array[Array] = [
		["최종 인구", "%d명" % int(d.get("pop", 0))],
		["국고 금화", "%s냥" % String.num_int64(int(d.get("gold", 0)))],
		["군량 비축", "%s석" % String.num_int64(int(d.get("rice", 0)))],
		["성곽 완공도", "%d%%" % int(d.get("fortress", 0))],
		["성곽 방호력", "%d점" % int(d.get("defense_power", 0))],
		["도시 학문력", "%d점" % int(d.get("academic_power", d.get("academic", 0)))],
		["백성 민심", "%d점" % int(d.get("loyalty", 0))],
		["조정 왕권", "%d점" % int(d.get("authority", 0))],
		["세자 교육도", "%d점" % int(d.get("prince_education", 50))],
		["현륭원 친림", "%d회" % int(d.get("hyeonryungwon_visits", 0))],
		["정파 탕평도", "%d점" % int(d.get("faction_balance", 50))],
		["을묘원행 완수", "완수(성공)" if bool(d.get("eulmyo_done", false)) else "미완(미실시)"],
		["실학 연구(보유·서기)", "완수(성공)" if bool(d.get("silhak_done", false)) else "미완(미실시)"]
	]

	for st: Array in stats:
		var box: HBoxContainer = HBoxContainer.new()
		var lbl_name: Label = Label.new()
		lbl_name.text = "• " + String(st[0]) + ": "
		lbl_name.add_theme_color_override("font_color", Color("4b5563"))
		lbl_name.add_theme_font_size_override("font_size", 12)
		box.add_child(lbl_name)

		var lbl_val: Label = Label.new()
		lbl_val.text = String(st[1])
		lbl_val.add_theme_color_override("font_color", Color("111827"))
		lbl_val.add_theme_font_size_override("font_size", 12)
		box.add_child(lbl_val)

		stats_container.add_child(box)

	_setup_replay_video_button(d)

## 엔딩 시네마틱 영상이 존재하는 경우 [영상 다시보기] 버튼 노출
func _setup_replay_video_button(d: Dictionary) -> void:
	var btn_box: HBoxContainer = get_node_or_null("CenterContainer/MainPanel/VBox/Buttons") as HBoxContainer
	if btn_box == null:
		return
	if btn_box.has_node("BtnReplayVideo"):
		var old_b: Node = btn_box.get_node("BtnReplayVideo")
		old_b.queue_free()

	var video_path: String = EndingManager.get_ending_video_path(d)
	if video_path == "":
		return

	var btn_replay: Button = Button.new()
	btn_replay.name = "BtnReplayVideo"
	btn_replay.text = "결말 영상 다시 보기"
	btn_replay.custom_minimum_size = Vector2(150, 36)
	btn_replay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.18, 0.22, 0.28, 0.95)
	sb_n.border_color = Color(0.85, 0.70, 0.35, 1.0)
	sb_n.set_border_width_all(1)
	sb_n.set_corner_radius_all(4)
	sb_n.set_content_margin_all(6)
	btn_replay.add_theme_stylebox_override("normal", sb_n)

	var sb_h := sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.28, 0.35, 0.45, 1.0)
	sb_h.border_color = Color(1.0, 0.88, 0.45, 1.0)
	btn_replay.add_theme_stylebox_override("hover", sb_h)
	btn_replay.add_theme_color_override("font_color", Color(0.95, 0.90, 0.75))

	btn_replay.pressed.connect(func():
		_on_replay_video_pressed(video_path, d)
	)
	btn_box.add_child(btn_replay)
	btn_box.move_child(btn_replay, 0) # 가장 왼쪽에 배치

func _on_replay_video_pressed(video_path: String, d: Dictionary) -> void:
	visible = false
	var v_layer := EndingVideoLayer.new()
	get_parent().add_child(v_layer)
	v_layer.video_finished.connect(func():
		visible = true
	)
	var t_title: String = String(d.get("title", ""))
	var t_subtitle: String = String(d.get("subtitle", ""))
	var ok: bool = v_layer.play_video(video_path, t_title, t_subtitle)
	if not ok:
		visible = true

func _on_save_pressed() -> void:
	if _sim and _grid:
		var ok: bool = SaveSystem.save_game(0, _sim, _grid)
		if ok:
			btn_save.text = "실록 저장 완료!"
			btn_save.disabled = true
			emit_signal("save_requested")

func _on_restart_pressed() -> void:
	emit_signal("restart_requested")
	# 메인 타이틀 화면 또는 게임 재시작
	var main = get_tree().root.get_node_or_null("Main")
	if main and main.has_method("open_title_screen"):
		queue_free()
		main.open_title_screen()
	else:
		get_tree().reload_current_scene()

func _on_continue_pressed() -> void:
	# 팝업 닫고 화성 자유 관람 모드 지속
	emit_signal("popup_closed")
	queue_free()
