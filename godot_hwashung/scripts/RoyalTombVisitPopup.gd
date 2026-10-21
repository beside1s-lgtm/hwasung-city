extends Control
class_name RoyalTombVisitPopup

## [현륭원(융건릉) 친림 참배 어명 건의 모달 팝업]
## 사도세자의 묘소인 현륭원 친림 참배를 거행할 시기가 도래했을 때
## 우선순위 대기열(PRIORITY_URGENT = 2)을 거쳐 정조 대왕에게 윤허를 청합니다.

@warning_ignore("unused_signal")
signal popup_closed
@warning_ignore("unused_signal")
signal tomb_visit_confirmed

var court_ref: CourtSystem = null
var sim_ref: SimulationCore = null

var _center: CenterContainer
var _panel: PanelContainer
var _title_label: Label
var _desc_label: Label
var _cost_label: Label
var _benefit_label: Label
var _conduct_btn: Button
var _postpone_btn: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_ui()
	_sync_viewport_size()
	if is_inside_tree() and get_viewport():
		get_viewport().size_changed.connect(_sync_viewport_size)
	visible = false

func _sync_viewport_size() -> void:
	if not is_inside_tree() or get_viewport() == null:
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	if vp_size.x > 0.0 and vp_size.y > 0.0:
		size = vp_size
		if _center:
			_center.size = vp_size

func _ensure_ui() -> void:
	if _panel == null:
		_build_ui()

func _build_ui() -> void:
	_center = CenterContainer.new()
	_center.name = "CenterContainer"
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)

	_panel = PanelContainer.new()
	_panel.name = "RoyalTombPanel"
	_panel.custom_minimum_size = Vector2(580, 400)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("fffdf6")
	sb.border_color = Color("854d0e") # 황실 황금빛 옻칠 테두리
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 14
	sb.set_content_margin_all(22)
	_panel.add_theme_stylebox_override("panel", sb)
	_center.add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "👑 [현륭원(顯隆園) 친림 참배 건의]"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color("854d0e"))
	vbox.add_child(_title_label)

	var sub_label: Label = Label.new()
	sub_label.text = "“선친(사도세자)을 향한 지극한 효심이 만백성을 감동케 하고 화성 번영의 뿌리가 되옵니다.”"
	sub_label.add_theme_font_size_override("font_size", 11)
	sub_label.add_theme_color_override("font_color", Color("713f12"))
	vbox.add_child(sub_label)

	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	_desc_label = Label.new()
	_desc_label.text = "전하, 계절이 무르익어 현륭원 친림 참배를 거행할 때가 되었사옵니다.\n거둥(行幸)을 거행하시어 효심의 가호를 받으시고 백성들의 충정을 결집하시겠습니까?"
	_desc_label.custom_minimum_size = Vector2(520, 40)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", 13)
	_desc_label.add_theme_color_override("font_color", Color("1c1917"))
	vbox.add_child(_desc_label)

	_cost_label = Label.new()
	var cost_dict: Dictionary = TombVisitManager.get_tomb_visit_cost()
	_cost_label.text = "소요 비용: 금화 %d냥, 군량 %d석" % [int(cost_dict.get("gold", 2000)), int(cost_dict.get("rice", 1000))]
	_cost_label.add_theme_font_size_override("font_size", 12)
	_cost_label.add_theme_color_override("font_color", Color("b45309"))
	vbox.add_child(_cost_label)

	_benefit_label = Label.new()
	_benefit_label.text = "참배 효과: 민심 +20, 왕권 +15, 효심의 가호(농업 생산 가산 활성화)"
	_benefit_label.add_theme_font_size_override("font_size", 12)
	_benefit_label.add_theme_color_override("font_color", Color("15803d"))
	vbox.add_child(_benefit_label)

	var btn_hbox: HBoxContainer = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	btn_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_hbox)

	_postpone_btn = Button.new()
	_postpone_btn.text = "다음 기회로 미룸"
	_postpone_btn.custom_minimum_size = Vector2(130, 36)
	_postpone_btn.pressed.connect(close_popup)
	btn_hbox.add_child(_postpone_btn)

	_conduct_btn = Button.new()
	_conduct_btn.text = "친림 참배 거행하기"
	_conduct_btn.custom_minimum_size = Vector2(140, 36)
	_conduct_btn.pressed.connect(_on_conduct_pressed)
	btn_hbox.add_child(_conduct_btn)

func show_proposal(court: CourtSystem, sim: SimulationCore) -> void:
	_ensure_ui()
	_sync_viewport_size()
	court_ref = court
	sim_ref = sim
	var cost_dict: Dictionary = TombVisitManager.get_tomb_visit_cost()
	var c_gold: int = int(cost_dict.get("gold", 2000))
	var c_rice: int = int(cost_dict.get("rice", 1000))
	_cost_label.text = "소요 비용: 금화 %d냥, 군량 %d석" % [c_gold, c_rice]

	var can_afford: bool = (sim != null and sim.gold >= c_gold and sim.rice >= c_rice)
	_conduct_btn.disabled = not can_afford
	if not can_afford:
		_conduct_btn.text = "국고/군량 부족"
	else:
		_conduct_btn.text = "친림 참배 거행하기"

	visible = true

func _on_conduct_pressed() -> void:
	if court_ref != null and sim_ref != null:
		var res: Dictionary = TombVisitManager.execute_tomb_visit(court_ref, sim_ref)
		if bool(res.get("success", false)):
			emit_signal("tomb_visit_confirmed")
	close_popup()

func close_popup() -> void:
	visible = false
	emit_signal("popup_closed")
