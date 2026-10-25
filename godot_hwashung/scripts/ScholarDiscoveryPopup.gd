extends Control
class_name ScholarDiscoveryPopup

const SpriteCacheManager = preload("res://scripts/autoload/SpriteCacheManager.gd")

## [초야의 인재 천거 전용 모달 팝업]
## 턴 전환 시 새로운 사대부나 기술 장인이 출현했을 때
## 우선순위 대기열을 거쳐 한 번에 1명씩 안전하게 천거 창을 표시합니다.

@warning_ignore("unused_signal")
signal popup_closed
@warning_ignore("unused_signal")
signal scholar_hired(scholar_id: String)

var court_ref: CourtSystem = null
var sim_ref: SimulationCore = null
var current_cand: Dictionary = {}

var _center: CenterContainer
var _panel: PanelContainer
var _portrait_rect: TextureRect
var _title_label: Label
var _name_label: Label
var _role_label: Label
var _salary_label: Label
var _praise_label: Label
var _hire_btn: Button
var _pass_btn: Button

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
	_panel.name = "ScholarPanel"
	_panel.custom_minimum_size = Vector2(560, 420)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("fffdf6") # 전통 한지 크림색
	sb.border_color = Color("5c3a21") # 짙은 옻칠 목재 테두리
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 14
	sb.set_content_margin_all(22)
	_panel.add_theme_stylebox_override("panel", sb)
	_center.add_child(_panel)

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(main_vbox)

	# [상단 헤더]
	_title_label = Label.new()
	_title_label.text = "👥 [초야의 인재 천거 상소]"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color("8f1d1d"))
	main_vbox.add_child(_title_label)

	var sub_label: Label = Label.new()
	sub_label.text = "“탕평의 큰 뜻을 펼치시어 나라의 기둥이 될 인재를 거두어 주옵소서.”"
	sub_label.add_theme_font_size_override("font_size", 11)
	sub_label.add_theme_color_override("font_color", Color("78502c"))
	main_vbox.add_child(sub_label)

	var sep: HSeparator = HSeparator.new()
	main_vbox.add_child(sep)

	# [중앙 정보: 초상화 + 상세 정보]
	var content_hbox: HBoxContainer = HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(content_hbox)

	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = Vector2(100, 120)
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content_hbox.add_child(_portrait_rect)

	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 6)
	content_hbox.add_child(info_vbox)

	_name_label = Label.new()
	_name_label.text = "성명: -"
	ThemeManager.apply_title_font(_name_label, 16)
	_name_label.add_theme_color_override("font_color", Color("1d4ed8"))
	info_vbox.add_child(_name_label)

	_role_label = Label.new()
	_role_label.text = "직능: -"
	_role_label.add_theme_font_size_override("font_size", 13)
	_role_label.add_theme_color_override("font_color", Color("3b2f2f"))
	info_vbox.add_child(_role_label)

	_salary_label = Label.new()
	_salary_label.text = "녹봉: -"
	_salary_label.add_theme_font_size_override("font_size", 13)
	_salary_label.add_theme_color_override("font_color", Color("b45309"))
	info_vbox.add_child(_salary_label)

	_praise_label = Label.new()
	_praise_label.text = "\"\""
	_praise_label.custom_minimum_size = Vector2(500, 30)
	_praise_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_praise_label.add_theme_font_size_override("font_size", 12)
	_praise_label.add_theme_color_override("font_color", Color("44403c"))
	main_vbox.add_child(_praise_label)

	# [하단 버튼 바]
	var btn_hbox: HBoxContainer = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	btn_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(btn_hbox)

	_pass_btn = Button.new()
	_pass_btn.text = "보류 (다음에 검토)"
	_pass_btn.custom_minimum_size = Vector2(130, 36)
	_pass_btn.pressed.connect(_on_pass_pressed)
	btn_hbox.add_child(_pass_btn)

	_hire_btn = Button.new()
	_hire_btn.text = "인재 등용하기"
	_hire_btn.custom_minimum_size = Vector2(130, 36)
	_hire_btn.pressed.connect(_on_hire_pressed)
	btn_hbox.add_child(_hire_btn)

func show_candidate(cand_data: Dictionary, court: CourtSystem = null, sim: SimulationCore = null) -> void:
	_ensure_ui()
	_sync_viewport_size()
	current_cand = cand_data
	court_ref = court
	sim_ref = sim

	var sid: String = str(cand_data.get("id", ""))
	var s_info: Dictionary = CourtSystem.SCHOLARS.get(sid, {}) if CourtSystem.SCHOLARS.has(sid) else {}
	if s_info.is_empty() and ScholarManager.TALENTS_DATA.has(sid):
		s_info = ScholarManager.TALENTS_DATA[sid]

	var s_name: String = str(s_info.get("name", cand_data.get("name", sid)))
	var s_role: String = str(s_info.get("role", cand_data.get("role", "초야의 명사")))
	var s_desc: String = str(s_info.get("desc", ""))
	var sal: int = int(s_info.get("salary", cand_data.get("salary", 150)))
	if court_ref != null:
		sal = court_ref.get_scholar_salary(sid)

	_name_label.text = "성명: %s" % s_name
	_role_label.text = "직능: %s\n(%s)" % [s_role, s_desc]
	_salary_label.text = "요구 녹봉: 매달 %d냥" % sal
	_praise_label.text = "“%s”" % str(cand_data.get("praise", s_desc))

	# 초상화 주입 (48x48 네임드 캐릭터 고유 초상화 우선)
	var tex: Texture2D = SpriteCacheManager.get_named_character_texture(sid, true)
	if tex == null:
		tex = InspectNarrativeGenerator.get_portrait("scholar")
	if _portrait_rect:
		_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_portrait_rect.texture = tex

	visible = true

func _on_hire_pressed() -> void:
	var sid: String = str(current_cand.get("id", ""))
	if sid != "":
		ScholarManager.hire_scholar(sid, sim_ref, court_ref)
		if court_ref != null:
			if court_ref.has_method("hire_scholar"):
				court_ref.hire_scholar(sid)
			elif court_ref.has_method("hire_candidate"):
				court_ref.hire_candidate(sid)
	emit_signal("scholar_hired", sid)
	close_popup()

func _on_pass_pressed() -> void:
	close_popup()

func close_popup() -> void:
	visible = false
	emit_signal("popup_closed")
