extends CanvasLayer
class_name ModernHUD

## 근대화 시대 상시 지표 띠(화면 위쪽 가운데). 근대화가 시작되면 나타나고, 1초마다 값을 고친다.
## 외교 신뢰도 · 동맹 · 문화재 보존도 · 도시화율 · 서학 진척도 · 정치체제

var _panel: PanelContainer
var _lbl: Label
var _t := 0.0

func _init() -> void:
	name = "ModernHUD"
	layer = 20

func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_top = 46
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.05, 0.82)
	sb.border_color = Color(0.72, 0.53, 0.04, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_lbl = Label.new()
	_lbl.add_theme_font_size_override("font_size", 12)
	_lbl.add_theme_color_override("font_color", Color("fde68a"))
	_panel.add_child(_lbl)
	_refresh()

func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	_refresh()

func _refresh() -> void:
	var mm := ModernizationManager.instance
	var on := mm != null and mm.active
	_panel.visible = on
	if not on:
		return
	var um := UrbanEvolutionManager.instance
	var pol := ModernPoliticsManager.instance
	var parts: Array[String] = [
		"🕊️ 신뢰도 %d/10" % mm.trust,
		"🤝 동맹 %d/%d" % [mm.allies.size(), ModernizationManager.MAX_ALLIES],
		"🏯 문화재 %d%%" % mm.metric_heritage(),
		"🏙️ 도시화 %d%%" % mm.metric_urban(),
		"🔬 서학 %d" % mm.western_progress(),
	]
	if um != null and um.stone_ratio < 1.0:
		parts.append("🪨 석조 전환 %d%%" % int(um.stone_ratio * 100.0))
	if pol != null and pol.system_label() != "":
		parts.append("⚖️ " + pol.system_label())
	_lbl.text = "   ".join(parts)
