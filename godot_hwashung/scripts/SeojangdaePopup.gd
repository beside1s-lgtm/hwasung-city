extends CanvasLayer
class_name SeojangdaePopup

## [서장대(華城壯臺) 정무 및 연례 야조 훈련 선택 모달]
## - 실행 방식 이원화: [자동 시행 (기본 효과 100%)] vs [직접 지휘 (미니게임: 80% ~ 120%)]
## - 두 방식 모두 실행 즉시 기본 훈련 비용(금화/군량미) 동일 차감
## - 직접 지휘 선택 시 YajoMiniGamePopup 호출 및 성공 횟수 비례 최종 보정 정산

signal drill_finished(mode: String, multiplier: float)

var _backdrop: ColorRect
var _center: CenterContainer
var _panel: PanelContainer
var _title_lbl: Label
var _desc_lbl: Label
var _info_lbl: Label
var _btn_auto: Button
var _btn_manual: Button
var _close_btn: Button

# 외부 참조 객체
var grid: GameGrid = null
var sim: SimulationCore = null
var citizens: CitizenManager = null
var hud: HUDController = null
var audio: Node = null
var time_manager: TimeManager = null
var yajo_minigame: YajoMiniGamePopup = null

func _init() -> void:
	layer = 87
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _ready() -> void:
	if _panel == null:
		_build_ui()
	_sync_viewport_size()
	if is_inside_tree() and get_viewport():
		if not get_viewport().size_changed.is_connected(_sync_viewport_size):
			get_viewport().size_changed.connect(_sync_viewport_size)
	visible = false

func _sync_viewport_size() -> void:
	if not is_inside_tree() or get_viewport() == null:
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	if vp_size.x > 0.0 and vp_size.y > 0.0:
		if _backdrop != null:
			_backdrop.size = vp_size
		if _center != null:
			_center.size = vp_size

func setup(
	p_grid: GameGrid,
	p_sim: SimulationCore,
	p_citizens: CitizenManager,
	p_hud: HUDController = null,
	p_audio: Node = null,
	p_time_mgr: TimeManager = null,
	p_minigame: YajoMiniGamePopup = null
) -> void:
	grid = p_grid
	sim = p_sim
	citizens = p_citizens
	hud = p_hud
	audio = p_audio
	time_manager = p_time_mgr
	yajo_minigame = p_minigame

	if yajo_minigame != null and not yajo_minigame.minigame_completed.is_connected(_on_minigame_completed):
		yajo_minigame.minigame_completed.connect(_on_minigame_completed)

func open_seojangdae_popup() -> void:
	_sync_viewport_size()
	_refresh_ui()
	visible = true

func close_seojangdae_popup() -> void:
	visible = false

func _build_ui() -> void:
	if _panel != null:
		return
	# 1. 반투명 배경
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	_backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close_seojangdae_popup()
	)
	add_child(_backdrop)

	# 2. 중앙 컨테이너
	_center = CenterContainer.new()
	_center.name = "CenterContainer"
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)

	# 3. 중앙 한지 패널 (640 x 440)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(640, 440)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fffdf5")          # 한지 크림색
	sb.border_color = Color("7a5835")      # 고목 테두리
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 12
	sb.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", sb)
	_center.add_child(_panel)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 12)
	_panel.add_child(vb)

	# 상단 헤더 (제목 + 닫기 버튼)
	var header_hb := HBoxContainer.new()
	vb.add_child(header_hb)

	_title_lbl = Label.new()
	_title_lbl.text = "[서장대(華城壯臺) 정무 및 야조 훈련]"
	_title_lbl.add_theme_font_size_override("font_size", 16)
	_title_lbl.add_theme_color_override("font_color", Color("78350f"))
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hb.add_child(_title_lbl)

	_close_btn = Button.new()
	_close_btn.text = "닫기"
	_close_btn.custom_minimum_size = Vector2(50, 28)
	_close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_btn.pressed.connect(close_seojangdae_popup)
	header_hb.add_child(_close_btn)

	# 설명 라벨
	_desc_lbl = Label.new()
	_desc_lbl.text = "팔달산 정상에 우뚝 솟은 서장대에서 외장용영 대장 백동수가 성곽과 장용영 군사들을 총지휘합니다. (을묘원행 때는 정조 대왕께서 친히 지휘)\n야간 조련(야조: 夜操)을 거행하여 성곽 횃불을 밝히고 공격력과 사기를 크게 증진시킬 수 있습니다."
	_desc_lbl.custom_minimum_size = Vector2(590, 0)
	_desc_lbl.add_theme_font_size_override("font_size", 12)
	_desc_lbl.add_theme_color_override("font_color", Color("57534e"))
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_desc_lbl)

	# 정보 카드
	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var c_sb := StyleBoxFlat.new()
	c_sb.bg_color = Color("f5f0e6")
	c_sb.border_color = Color("d4c3ab")
	c_sb.set_border_width_all(1)
	c_sb.set_corner_radius_all(6)
	c_sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", c_sb)
	vb.add_child(card)

	var card_vb := VBoxContainer.new()
	card_vb.add_theme_constant_override("separation", 6)
	card.add_child(card_vb)

	_info_lbl = Label.new()
	_info_lbl.text = "훈련 정보를 불러오는 중입니다..."
	_info_lbl.custom_minimum_size = Vector2(570, 0)
	_info_lbl.add_theme_font_size_override("font_size", 13)
	_info_lbl.add_theme_color_override("font_color", Color("292524"))
	_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vb.add_child(_info_lbl)

	# 훈련 방식 안내 문구
	var guide_lbl := Label.new()
	guide_lbl.text = "훈련 집행 방식을 선택하십시오:\n- [자동 시행]: 즉시 완료되며 기본 훈련 효과(100%)를 얻습니다.\n- [친림 지휘]: 신호 전달 솜씨 겨루기를 직접 수행하여 성공 횟수에 따라 80% ~ 120% 효과를 획득합니다."
	guide_lbl.custom_minimum_size = Vector2(570, 0)
	guide_lbl.add_theme_font_size_override("font_size", 12)
	guide_lbl.add_theme_color_override("font_color", Color("1e3a8a"))
	guide_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vb.add_child(guide_lbl)

	# 하단 실행 버튼 2종
	var btn_hb := HBoxContainer.new()
	btn_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hb.add_theme_constant_override("separation", 12)
	vb.add_child(btn_hb)

	_btn_auto = Button.new()
	_btn_auto.text = "자동 시행 (기본 효과 100%)"
	_btn_auto.custom_minimum_size = Vector2(260, 42)
	_btn_auto.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_button_style(_btn_auto, Color(0.20, 0.28, 0.20), Color(0.7, 0.9, 0.7))
	_btn_auto.pressed.connect(_on_auto_drill_pressed)
	btn_hb.add_child(_btn_auto)

	_btn_manual = Button.new()
	_btn_manual.text = "친림 지휘 (솜씨 겨루기: 80% ~ 120%)"
	_btn_manual.custom_minimum_size = Vector2(280, 42)
	_btn_manual.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_button_style(_btn_manual, Color(0.28, 0.20, 0.15), Color(0.95, 0.85, 0.5))
	_btn_manual.pressed.connect(_on_manual_drill_pressed)
	btn_hb.add_child(_btn_manual)

func _apply_button_style(btn: Button, bg_col: Color, border_col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", sb)

	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = bg_col.lightened(0.15)
	btn.add_theme_stylebox_override("hover", sb_h)

	var sb_d := sb.duplicate() as StyleBoxFlat
	sb_d.bg_color = Color(0.3, 0.3, 0.3, 0.7)
	sb_d.border_color = Color(0.5, 0.5, 0.5, 0.7)
	btn.add_theme_stylebox_override("disabled", sb_d)

func _refresh_ui() -> void:
	var has_sj: bool = grid.count_completed("seojangdae") > 0 if grid else false
	var cd_months: int = sim.seojangdae_drill_cd_months if sim else 0
	var drill_b: int = CityStats.get_seojangdae_drill_bonus()
	var cur_atk: int = CityStats.get_military_attack_power()

	var drill_cost: Dictionary = DifficultyManager.get_military_drill_cost()
	var cost_gold: int = int(drill_cost.get("gold", 2000))
	var cost_rice: int = int(drill_cost.get("rice", 1000))

	var status_text: String = "훈련 가능 (연 1회 가능)"
	if cd_months > 0:
		status_text = "올해 야조 실시 완료 (다음 훈련까지 %d개월)" % cd_months

	var has_funds: bool = (sim != null and sim.gold >= cost_gold and sim.rice >= cost_rice)

	_info_lbl.text = "• 서장대 건립 여부: %s\n• 현재 장용영 총 공격력: %d\n• 야조 누적 성장 가산: +%d (최대 +1000)\n• 훈련 상태: %s\n• 훈련 비용: 금화 %s냥, 군량 %s석 (난이도 배율 적용)\n• 기본 보상 (100%%): 공격력 +50(해마다 1월 -50), 왕권 +5, 민심 +3, 횃불 점등" % [
		"완공됨" if has_sj else "미완공 (서장대 필요)",
		cur_atk, drill_b, status_text,
		_fmt_num(cost_gold), _fmt_num(cost_rice)
	]

	if not has_sj:
		_btn_auto.text = "서장대 미완공 (훈련 불가)"
		_btn_auto.disabled = true
		_btn_manual.text = "서장대 미완공 (훈련 불가)"
		_btn_manual.disabled = true
	elif cd_months > 0:
		_btn_auto.text = "올해 야조 완료 (%d개월 후)" % cd_months
		_btn_auto.disabled = true
		_btn_manual.text = "올해 야조 완료 (%d개월 후)" % cd_months
		_btn_manual.disabled = true
	elif not has_funds:
		_btn_auto.text = "자금/군량 부족"
		_btn_auto.disabled = true
		_btn_manual.text = "자금/군량 부족"
		_btn_manual.disabled = true
	else:
		_btn_auto.text = "자동 시행 (기본 효과 100%)"
		_btn_auto.disabled = false
		_btn_manual.text = "친림 지휘 (솜씨 겨루기: 80% ~ 120%)"
		_btn_manual.disabled = false

func _fmt_num(val: int) -> String:
	var s: String = str(val)
	var res: String = ""
	var cnt: int = 0
	for i: int in range(s.length() - 1, -1, -1):
		if cnt > 0 and cnt % 3 == 0:
			res = "," + res
		res = s[i] + res
		cnt += 1
	return res

## 1. 자동 시행 (기본 효과 100%)
func _on_auto_drill_pressed() -> void:
	if sim == null:
		return

	var res: Dictionary = sim.execute_seojangdae_drill(grid, citizens, 1.0)
	if res.get("success", false):
		if hud != null:
			hud._show_toast(str(res.get("msg", "야조 훈련 완료")), "훈련")
		if audio != null and audio.has_method("play"):
			audio.play("yajo")
		emit_signal("drill_finished", "auto", 1.0)
		close_seojangdae_popup()
	else:
		if hud != null:
			hud._show_toast(str(res.get("msg", "훈련 실패")), "경고")

## 2. 친림 지휘 (미니게임: 80% ~ 120%)
func _on_manual_drill_pressed() -> void:
	if sim == null:
		return

	# 실행 즉시 기본 훈련 비용(금화/군량미) 선차감 및 쿨다운 설정
	var pay_res: Dictionary = sim.pay_seojangdae_drill_cost(grid)
	if not pay_res.get("success", false):
		if hud != null:
			hud._show_toast(str(pay_res.get("msg", "비용 차감 실패")), "경고")
		return

	# 서장대 팝업 닫고 미니게임 팝업 실행
	close_seojangdae_popup()

	if yajo_minigame != null:
		yajo_minigame.start_yajo_minigame(time_manager)
	else:
		# fallback: 미니게임 모달 부재 시 기본 보상 지급
		var fallback_res: Dictionary = sim.apply_seojangdae_drill_rewards(grid, citizens, 1.0)
		if hud != null:
			hud._show_toast(str(fallback_res.get("msg", "야조 훈련 완료")), "훈련")
		emit_signal("drill_finished", "auto", 1.0)

## 미니게임 종료 콜백
func _on_minigame_completed(final_multiplier: float, success_count: int) -> void:
	if sim == null:
		return

	var _res: Dictionary = sim.apply_seojangdae_drill_rewards(grid, citizens, final_multiplier)
	if hud != null:
		var bonus_pct: int = (success_count - 5) * 4
		var sign_str: String = ("+" if bonus_pct > 0 else "") + str(bonus_pct) + "%"
		var toast_msg: String = "친림 지휘 성료! 10회 중 %d회 성공으로 훈련 효과 %s(%.2f배)가 적용되었습니다." % [
			success_count, sign_str, final_multiplier
		]
		hud._show_toast(toast_msg, "승전")

	if audio != null and audio.has_method("play"):
		audio.play("yajo")

	emit_signal("drill_finished", "manual", final_multiplier)
