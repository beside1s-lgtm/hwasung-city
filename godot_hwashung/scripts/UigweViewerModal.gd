extends CanvasLayer
class_name UigweViewerModal

## [완성된 규장각 의궤 열람 전용 뷰어(도감) 모달]
## - 고화질 의궤 사진(TextureRect, 종횡비 보존)
## - 상단 정식 명칭 (휴먼옛체 볼드)
## - 하단 100자 내외 고증 해설 텍스트 박스 (궁서체)
## - 단일 인스턴스 재사용 및 지연 로딩(Lazy Loading)으로 VRAM/GC 낭비 방지

signal closed

var _overlay: ColorRect = null
var _main_panel: PanelContainer = null
var _title_lbl: Label = null
var _image_rect: TextureRect = null
var _desc_lbl: Label = null
var _image_cache: Dictionary = {}

func _init() -> void:
	layer = 110 # 최상단 뷰어 레이어

func _ready() -> void:
	_build_ui()
	visible = false

func _build_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close_viewer()
	)
	add_child(_overlay)

	# 1. 메인 패널 (780 x 620 규격 단아한 한지풍)
	_main_panel = PanelContainer.new()
	_main_panel.custom_minimum_size = Vector2(780, 620)
	_main_panel.set_anchors_preset(Control.PRESET_CENTER)
	_main_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_main_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color("f6f1e3")
	panel_sb.set_border_width_all(3)
	panel_sb.border_color = Color("382e26")
	panel_sb.set_corner_radius_all(3)
	panel_sb.shadow_color = Color(0, 0, 0, 0.5)
	panel_sb.shadow_size = 16
	panel_sb.shadow_offset = Vector2(4, 6)
	_main_panel.add_theme_stylebox_override("panel", panel_sb)
	_overlay.add_child(_main_panel)

	# 한지 텍스처 배경
	if ResourceLoader.exists("res://assets/ui/hanji_paper.png"):
		var paper := TextureRect.new()
		paper.texture = load("res://assets/ui/hanji_paper.png")
		paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		paper.stretch_mode = TextureRect.STRETCH_SCALE
		paper.set_anchors_preset(Control.PRESET_FULL_RECT)
		paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_main_panel.add_child(paper)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	_main_panel.add_child(margin)

	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 14)
	margin.add_child(root_vb)

	# 1. 상단 헤더 (의궤 정식 명칭 및 닫기 버튼)
	var header_hb := HBoxContainer.new()
	root_vb.add_child(header_hb)

	_title_lbl = Label.new()
	_title_lbl.text = "📖 규장각 의궤 열람"
	ThemeManager.apply_title_font(_title_lbl, 24)
	_title_lbl.add_theme_color_override("font_color", Color("1c1612"))
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hb.add_child(_title_lbl)

	var close_btn := Button.new()
	close_btn.text = " ✕ "
	close_btn.custom_minimum_size = Vector2(36, 32)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(close_viewer)
	_style_close_button(close_btn)
	header_hb.add_child(close_btn)

	# 상단 구분 먹선
	root_vb.add_child(_create_divider(2))

	# 2. 중앙 의궤 사진 영역 (프레임 박스)
	var art_frame := PanelContainer.new()
	art_frame.custom_minimum_size = Vector2(720, 340)
	art_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var af_sb := StyleBoxFlat.new()
	af_sb.bg_color = Color("231d18")
	af_sb.set_border_width_all(2)
	af_sb.border_color = Color("8c6239")
	af_sb.set_corner_radius_all(2)
	art_frame.add_theme_stylebox_override("panel", af_sb)
	root_vb.add_child(art_frame)

	_image_rect = TextureRect.new()
	_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_image_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art_frame.add_child(_image_rect)

	# 3. 하단 고증 해설 텍스트 영역 (궁서체 16px, 한지풍 패널)
	var desc_panel := PanelContainer.new()
	desc_panel.custom_minimum_size = Vector2(0, 110)
	var dp_sb := StyleBoxFlat.new()
	dp_sb.bg_color = Color("ede3cc")
	dp_sb.set_border_width_all(1)
	dp_sb.border_color = Color("5c4b38")
	dp_sb.set_corner_radius_all(3)
	dp_sb.set_content_margin_all(14)
	desc_panel.add_theme_stylebox_override("panel", dp_sb)
	root_vb.add_child(desc_panel)

	_desc_lbl = Label.new()
	ThemeManager.apply_base_font(_desc_lbl, 16)
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_lbl.add_theme_color_override("font_color", Color("1f1a14"))
	_desc_lbl.add_theme_constant_override("line_spacing", 6)
	desc_panel.add_child(_desc_lbl)

	# 4. 하단 닫기 제어 버튼
	var btm_hb := HBoxContainer.new()
	btm_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vb.add_child(btm_hb)

	var btm_close := Button.new()
	btm_close.text = "도감 덮기 (닫기)"
	btm_close.custom_minimum_size = Vector2(160, 36)
	btm_close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btm_close.pressed.connect(close_viewer)
	_style_confirm_button(btm_close)
	btm_hb.add_child(btm_close)

## 뷰어 오픈 및 데이터 동적 인젝션
func open_viewer(uigwe_id: String) -> void:
	if _overlay == null:
		_build_ui()

	if not UigweManager.UIGWE_DATA.has(uigwe_id):
		return

	var info: Dictionary = UigweManager.UIGWE_DATA[uigwe_id]
	if _title_lbl != null:
		_title_lbl.text = "📖 %s" % str(info.get("name", "규장각 의궤"))
	if _desc_lbl != null:
		_desc_lbl.text = str(info.get("description", ""))

	# 이미지 지연 로딩 및 캐싱
	var img_path: String = str(info.get("image_path", ""))
	if _image_rect != null:
		if _image_cache.has(img_path):
			_image_rect.texture = _image_cache[img_path]
		elif ResourceLoader.exists(img_path):
			var tex: Texture2D = load(img_path) as Texture2D
			_image_cache[img_path] = tex
			_image_rect.texture = tex
		else:
			_image_rect.texture = null

	visible = true
	if is_inside_tree() and _overlay != null:
		_overlay.modulate.a = 0.0
		var tw: Tween = create_tween()
		if tw != null:
			tw.set_parallel(true)
			tw.tween_property(_overlay, "modulate:a", 1.0, 0.2)
			if _main_panel != null:
				_main_panel.scale = Vector2(0.95, 0.95)
				_main_panel.pivot_offset = _main_panel.size * 0.5
				tw.tween_property(_main_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif _overlay != null:
		_overlay.modulate.a = 1.0

func close_viewer() -> void:
	if is_inside_tree() and _overlay != null:
		var tw: Tween = create_tween()
		if tw != null:
			tw.tween_property(_overlay, "modulate:a", 0.0, 0.15)
			tw.tween_callback(func():
				visible = false
				emit_signal("closed")
			)
			return
	visible = false
	emit_signal("closed")

func _create_divider(thickness: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, thickness + 4)
	var line := ColorRect.new()
	line.color = Color("382e26")
	line.custom_minimum_size = Vector2(0, thickness)
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(line)
	return c

func _style_close_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("4a3b32")
	sb.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", Color("fdfbf7"))

func _style_confirm_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("8c6239")
	sb.border_color = Color("4a3b32")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", Color("fdfbf7"))
	ThemeManager.apply_title_font(btn, 14)
