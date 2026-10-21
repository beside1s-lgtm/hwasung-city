extends CanvasLayer
class_name CrownPrincePopup

## [시강원 세자서연(경연) 팝업 UI 컨트롤러]
## 1. 6단계 캐릭터 외형·성장 FSM 및 전용 초상화, 감정 표현, 고유 대사 타이핑 연출
## 2. 턴당 2,000냥 지속 소모 및 재정 부족 안전 일시 정지 안내
## 3. 시그널 기반 실시간 UI 갱신 (education_progress_changed, stage_changed)

signal closed

var sim: SimulationCore = null
var court: CourtSystem = null
var prince_mgr: CrownPrinceEducationManager = null

@onready var close_btn_top: Button = $CenterContainer/MainPanel/MarginContainer/VBox/TitleBar/CloseButtonTop
@onready var close_btn_bottom: Button = $CenterContainer/MainPanel/MarginContainer/VBox/Footer/CloseButtonBottom
@onready var stage_badge_label: Label = $CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/LeftPortraitPanel/LeftVBox/StageBadgeLabel
@onready var portrait_rect: TextureRect = $CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/LeftPortraitPanel/LeftVBox/PortraitFrame/PortraitRect
@onready var sparkle_label: Label = $CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/LeftPortraitPanel/LeftVBox/PortraitFrame/SparkleLabel
@onready var quote_label: Label = $CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/LeftPortraitPanel/LeftVBox/QuotePanel/QuoteLabel
@onready var desc_label: Label = $CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/LeftPortraitPanel/LeftVBox/DescLabel

@onready var status_header_label: Label = $CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/RightWorkPanel/RightVBox/StatusHeaderLabel
@onready var gauge_label: Label = $CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/RightWorkPanel/RightVBox/GaugeSection/GaugeLabel
@onready var progress_bar: ProgressBar = $CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/RightWorkPanel/RightVBox/GaugeSection/ProgressBar

@onready var acad_val: Label = $CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/RightWorkPanel/RightVBox/InfoGrid/AcadVal
@onready var speed_val: Label = $CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/RightWorkPanel/RightVBox/InfoGrid/SpeedVal
@onready var cost_val: Label = $CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/RightWorkPanel/RightVBox/InfoGrid/CostVal
@onready var buff_val: Label = $CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/RightWorkPanel/RightVBox/InfoGrid/BuffVal

@onready var alert_label: Label = $CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/RightWorkPanel/RightVBox/AlertLabel
@onready var toggle_btn: Button = $CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/RightWorkPanel/RightVBox/ActionHBox/ToggleButton

var _typing_tween: Tween = null
var _last_rendered_stage: int = -1

func _ready() -> void:
	visible = false
	_ensure_node_refs()
	if close_btn_top:
		close_btn_top.pressed.connect(close_popup)
	if close_btn_bottom:
		close_btn_bottom.pressed.connect(close_popup)
	if toggle_btn:
		toggle_btn.pressed.connect(_on_toggle_pressed)

func _ensure_node_refs() -> void:
	if close_btn_top == null:
		close_btn_top = get_node_or_null("CenterContainer/MainPanel/MarginContainer/VBox/TitleBar/CloseButtonTop") as Button
	if close_btn_bottom == null:
		close_btn_bottom = get_node_or_null("CenterContainer/MainPanel/MarginContainer/VBox/Footer/CloseButtonBottom") as Button
	if stage_badge_label == null:
		stage_badge_label = get_node_or_null("CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/LeftPortraitPanel/LeftVBox/StageBadgeLabel") as Label
	if portrait_rect == null:
		portrait_rect = get_node_or_null("CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/LeftPortraitPanel/LeftVBox/PortraitFrame/PortraitRect") as TextureRect
	if sparkle_label == null:
		sparkle_label = get_node_or_null("CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/LeftPortraitPanel/LeftVBox/PortraitFrame/SparkleLabel") as Label
	if quote_label == null:
		quote_label = get_node_or_null("CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/LeftPortraitPanel/LeftVBox/QuotePanel/QuoteLabel") as Label
	if desc_label == null:
		desc_label = get_node_or_null("CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/LeftPortraitPanel/LeftVBox/DescLabel") as Label
	if status_header_label == null:
		status_header_label = get_node_or_null("CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/RightWorkPanel/RightVBox/StatusHeaderLabel") as Label
	if gauge_label == null:
		gauge_label = get_node_or_null("CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/RightWorkPanel/RightVBox/GaugeSection/GaugeLabel") as Label
	if progress_bar == null:
		progress_bar = get_node_or_null("CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/RightWorkPanel/RightVBox/GaugeSection/ProgressBar") as ProgressBar
	if acad_val == null:
		acad_val = get_node_or_null("CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/RightWorkPanel/RightVBox/InfoGrid/AcadVal") as Label
	if speed_val == null:
		speed_val = get_node_or_null("CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/RightWorkPanel/RightVBox/InfoGrid/SpeedVal") as Label
	if cost_val == null:
		cost_val = get_node_or_null("CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/RightWorkPanel/RightVBox/InfoGrid/CostVal") as Label
	if buff_val == null:
		buff_val = get_node_or_null("CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/RightWorkPanel/RightVBox/InfoGrid/BuffVal") as Label
	if alert_label == null:
		alert_label = get_node_or_null("CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/RightWorkPanel/RightVBox/AlertLabel") as Label
	if toggle_btn == null:
		toggle_btn = get_node_or_null("CenterContainer/MainPanel/MarginContainer/VBox/ContentHBox/RightWorkPanel/RightVBox/ActionHBox/ToggleButton") as Button

func setup(s: SimulationCore, c: CourtSystem = null) -> void:
	sim = s
	court = c
	if sim != null and sim.crown_prince_manager != null:
		prince_mgr = sim.crown_prince_manager
		_bind_prince_signals()

func _bind_prince_signals() -> void:
	if prince_mgr == null:
		return
	if not prince_mgr.education_progress_changed.is_connected(_on_progress_changed):
		prince_mgr.education_progress_changed.connect(_on_progress_changed)
	if not prince_mgr.stage_changed.is_connected(_on_stage_changed):
		prince_mgr.stage_changed.connect(_on_stage_changed)
	if not prince_mgr.education_paused.is_connected(_on_education_paused):
		prince_mgr.education_paused.connect(_on_education_paused)
	if not prince_mgr.education_resumed.is_connected(_on_education_resumed):
		prince_mgr.education_resumed.connect(_on_education_resumed)
	if not prince_mgr.education_completed.is_connected(_on_education_completed):
		prince_mgr.education_completed.connect(_on_education_completed)

func open_popup() -> void:
	_ensure_node_refs()
	visible = true
	_refresh_ui()

func close_popup() -> void:
	visible = false
	emit_signal("closed")

func _refresh_ui() -> void:
	_ensure_node_refs()
	if prince_mgr == null and sim != null:
		prince_mgr = sim.crown_prince_manager
		_bind_prince_signals()

	if prince_mgr == null:
		return

	var cur_score: float = prince_mgr.progress
	var stage_idx: int = CrownPrinceData.get_stage_by_score(cur_score)
	_update_visual_stage(stage_idx, false)

	# 점수 게이지 갱신
	if progress_bar:
		progress_bar.value = cur_score

	# 학문력 및 속도 (1.5배 감속 반영, 학문력 비례 버프 연동 유지)
	var acad: int = sim.academic if sim != null else 0
	var acad_clamped: float = clampf(float(acad), 0.0, 100.0)
	var speed: float = (1.0 + (acad_clamped / 100.0) * 9.0) / 1.5
	var turn_cost: int = prince_mgr.get_turn_cost()

	# 게이지 텍스트: [■■■■■□□□□□] 50 / 100점 (턴당 +5.5%)
	var filled_count: int = clampi(int(cur_score / 10.0), 0, 10)
	var gauge_str: String = ""
	for i in range(10):
		gauge_str += "■" if i < filled_count else "□"
	if gauge_label:
		gauge_label.text = "[%s] %d / 100점 (매달 +%.1f%%)" % [gauge_str, int(cur_score), speed]

	if acad_val:
		acad_val.text = "%d점 (향교, 서당, 규장각 사대부)" % acad
	if speed_val:
		speed_val.text = "매달 +%.1f%% (기본 0.7%% + 학문력 비례)" % speed
	if cost_val:
		cost_val.text = "%s냥 (난이도 배율 적용)" % _format_number(turn_cost)
	if buff_val:
		buff_val.text = CrownPrinceData.get_stage_buff_text(stage_idx)

	# 상태 머신 표시
	match prince_mgr.status:
		CrownPrinceEducationManager.EducationStatus.IDLE:
			if status_header_label:
				status_header_label.text = "상태: 경연 대기 중 | 소모: 매달 %s냥" % _format_number(turn_cost)
				status_header_label.add_theme_color_override("font_color", Color("555555"))
			if toggle_btn:
				toggle_btn.text = "경연 시작"
				toggle_btn.disabled = false
			if alert_label:
				alert_label.visible = false

		CrownPrinceEducationManager.EducationStatus.ACTIVE:
			if status_header_label:
				status_header_label.text = "상태: 경연 진행 중 | 소모: 매달 %s냥" % _format_number(turn_cost)
				status_header_label.add_theme_color_override("font_color", Color("2563eb"))
			if toggle_btn:
				toggle_btn.text = "경연 일시 중지"
				toggle_btn.disabled = false
			if alert_label:
				alert_label.visible = false

		CrownPrinceEducationManager.EducationStatus.PAUSED_NO_FUNDS:
			if status_header_label:
				status_header_label.text = "상태: 재정 부족 일시 정지 | 필요: 매달 %s냥" % _format_number(turn_cost)
				status_header_label.add_theme_color_override("font_color", Color("dc2626"))
			if toggle_btn:
				toggle_btn.text = "경연 재개"
				toggle_btn.disabled = false
			if alert_label:
				alert_label.visible = true
				alert_label.text = "⚠️ [경연 중단] 국고가 부족하여 세자 교육이 정체되었습니다. (필요: %s냥)" % _format_number(turn_cost)

		CrownPrinceEducationManager.EducationStatus.COMPLETED:
			if status_header_label:
				status_header_label.text = "상태: 제왕학 완수 (교육 종료)"
				status_header_label.add_theme_color_override("font_color", Color("16a34a"))
			if toggle_btn:
				toggle_btn.text = "제왕학 완수"
				toggle_btn.disabled = true
			if alert_label:
				alert_label.visible = false

func _update_visual_stage(stage_idx: int, animate_sparkle: bool = false) -> void:
	if stage_idx == _last_rendered_stage and not animate_sparkle:
		return
	_last_rendered_stage = stage_idx

	if stage_badge_label:
		stage_badge_label.text = CrownPrinceData.get_stage_badge(stage_idx)

	if portrait_rect:
		var tex: Texture2D = CrownPrinceData.get_portrait_texture(stage_idx)
		portrait_rect.texture = tex

	if desc_label:
		desc_label.text = CrownPrinceData.get_stage_description(stage_idx)

	# 대사 타이핑 연출
	var target_quote: String = "\"%s\"" % CrownPrinceData.get_stage_quote(stage_idx)
	if quote_label != null:
		quote_label.text = target_quote
	_start_quote_typing(target_quote)

	# 성장 축하 반짝임 연출
	if animate_sparkle and sparkle_label:
		sparkle_label.visible = true
		sparkle_label.modulate = Color(1, 1, 1, 1)
		var tw: Tween = create_tween()
		tw.tween_property(sparkle_label, "modulate:a", 0.0, 1.8).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(func(): sparkle_label.visible = false)

func _start_quote_typing(full_text: String) -> void:
	if quote_label == null:
		return
	if _typing_tween != null and _typing_tween.is_valid():
		_typing_tween.kill()

	quote_label.text = full_text



func _on_toggle_pressed() -> void:
	if prince_mgr == null:
		return

	if prince_mgr.status == CrownPrinceEducationManager.EducationStatus.ACTIVE:
		prince_mgr.pause_education("사용자 일시 중지")
	elif prince_mgr.status == CrownPrinceEducationManager.EducationStatus.PAUSED_NO_FUNDS:
		var res: Dictionary = prince_mgr.resume_education(sim)
		if not bool(res.get("success", false)):
			if alert_label:
				alert_label.visible = true
				alert_label.text = str(res.get("msg", ""))
	elif prince_mgr.status == CrownPrinceEducationManager.EducationStatus.IDLE:
		var res2: Dictionary = prince_mgr.start_education(sim)
		if not bool(res2.get("success", false)):
			if alert_label:
				alert_label.visible = true
				alert_label.text = str(res2.get("msg", ""))

	_refresh_ui()

func _on_progress_changed(_new_score: float, _stage_idx: int) -> void:
	if visible:
		_refresh_ui()

func _on_stage_changed(_old_stage: int, new_stage: int) -> void:
	if visible:
		_update_visual_stage(new_stage, true)
		_refresh_ui()

func _on_education_paused(_reason: String) -> void:
	if visible:
		_refresh_ui()

func _on_education_resumed() -> void:
	if visible:
		_refresh_ui()

func _on_education_completed() -> void:
	if visible:
		_update_visual_stage(5, true)
		_refresh_ui()

func _format_number(n: int) -> String:
	var s: String = str(absi(n))
	var out := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return ("-" if n < 0 else "") + out
