extends Control
class_name PuzzleDetailModal
## PORT-TRACE [퍼즐 조각 상세 보기]: 맞춘 조각을 누르면 열리는 읽을거리 창. 왼쪽은 그림 카드, 오른쪽은 제목(한글·한자)과 3문단 이야기,
## 아래에는 [최초 발견 일자]와 [해금 완료] 도장. 상세 일러스트는 res://assets/encyclopedia/<조각 id>.png 가 있으면 그것을 쓰고,
## 없으면 퍼즐 그림의 그 조각 부분을 확대한 그림 카드로 보여 준다(외부 그림 없이도 동작).

signal closed

const ILLUST_DIR := "res://assets/encyclopedia/"

var _panel: PanelContainer
var _illust_box: Control
var _title: Label
var _hanja: Label
var _body: VBoxContainer
var _badge: Label
var _stamp: Label
var _seal: Label

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close()
	)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.08
	_panel.anchor_right = 0.92
	_panel.anchor_top = 0.08
	_panel.anchor_bottom = 0.92
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fef3c7")
	sb.border_color = Color("451a03")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.75)
	sb.shadow_size = 18
	sb.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	_panel.add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	var htitle := Label.new()
	htitle.text = "📜 이야기꾼의 역사 읽을거리"
	htitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	htitle.add_theme_color_override("font_color", Color("991b1b"))
	head.add_child(htitle)
	var cb := Button.new()
	cb.text = " ✕ "
	cb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cb.pressed.connect(close)
	head.add_child(cb)

	var hb := HBoxContainer.new()
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 18)
	root.add_child(hb)

	# 왼쪽: 그림 카드
	_illust_box = Control.new()
	_illust_box.custom_minimum_size = Vector2(250, 250)
	_illust_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(_illust_box)

	# 오른쪽: 글
	var rv := VBoxContainer.new()
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rv.add_theme_constant_override("separation", 6)
	hb.add_child(rv)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color("1c1917"))
	rv.add_child(_title)
	_hanja = Label.new()
	_hanja.add_theme_font_size_override("font_size", 16)
	_hanja.add_theme_color_override("font_color", Color("78350f"))
	rv.add_child(_hanja)
	rv.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_body)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	root.add_child(foot)
	_badge = Label.new()
	_badge.add_theme_color_override("font_color", Color("57534e"))
	_badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_badge)
	_stamp = Label.new()
	_stamp.text = " ✔ 해금 완료 "
	_stamp.add_theme_color_override("font_color", Color("b91c1c"))
	_stamp.add_theme_font_size_override("font_size", 18)
	foot.add_child(_stamp)

func close() -> void:
	visible = false
	emit_signal("closed")

## board = PuzzleData.BOARDS 항목, piece = 조각 정보, art = 판 그림, crop = 판 좌표에서의 조각 경계 상자
func show_piece(board: Dictionary, piece: Dictionary, art: Texture2D, crop: Rect2) -> void:
	_title.text = String(piece["name"])
	_hanja.text = "%s   ·   %s" % [piece["hanja"], board["title"]]
	for ch in _body.get_children():
		ch.queue_free()
	for para: String in (piece["story"] as Array):
		var l := Label.new()
		l.text = para
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(300, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_color_override("font_color", Color("1c1917"))
		l.add_theme_font_size_override("font_size", 15)
		_body.add_child(l)
	var yr := GameProgressManager.found_year(String(board["id"]), String(piece["id"]))
	_badge.text = "[최초 발견 일자: 정조 %d년 (%d)]" % [maxi(1, yr - 1775), yr] if yr > 0 else "[최초 발견 일자: 기록 없음]"
	_build_illustration(board, piece, art, crop)
	visible = true

func _load_piece_texture(piece_id: String) -> Texture2D:
	for ext: String in [".png", ".jpg", ".jpeg", ".webp"]:
		var p: String = ILLUST_DIR + piece_id + ext
		if ResourceLoader.exists(p):
			var res: Texture2D = load(p) as Texture2D
			if res != null:
				return res
		var gpath: String = ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(gpath):
			var img: Image = Image.new()
			var err: Error = img.load(gpath)
			if err == OK and not img.is_empty():
				return ImageTexture.create_from_image(img)
	return null

func _build_illustration(_board: Dictionary, piece: Dictionary, art: Texture2D, crop: Rect2) -> void:
	for ch in _illust_box.get_children():
		ch.queue_free()
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(250, 250)
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color("1c1410")
	fsb.border_color = Color("c9a050")
	fsb.set_border_width_all(4)
	fsb.set_corner_radius_all(4)
	fsb.set_content_margin_all(6)
	frame.add_theme_stylebox_override("panel", fsb)
	_illust_box.add_child(frame)

	var tex_rect := TextureRect.new()
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex_rect.custom_minimum_size = Vector2(238, 238)

	var pid: String = String(piece.get("id", ""))
	var piece_tex: Texture2D = _load_piece_texture(pid)

	if piece_tex != null:
		tex_rect.texture = piece_tex
	elif art != null:
		# 퍼즐 그림에서 그 조각 부분을 정사각형에 가깝게 오려 확대(그림 카드)
		# 판 좌표(960x640)를 실제 그림 크기로 옮겨 오린다(직접 준비한 사진처럼 크기가 달라도 맞다)
		var k := art.get_size() / PuzzleData.BOARD_SIZE
		var c := crop.get_center()
		var side := maxf(crop.size.x, crop.size.y) * 0.92
		var r := Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side))
		r.position.x = clampf(r.position.x, 0.0, maxf(0.0, PuzzleData.BOARD_SIZE.x - r.size.x))
		r.position.y = clampf(r.position.y, 0.0, maxf(0.0, PuzzleData.BOARD_SIZE.y - r.size.y))
		var at := AtlasTexture.new()
		at.atlas = art
		at.region = Rect2(r.position * k, r.size * k)
		tex_rect.texture = at
	frame.add_child(tex_rect)

	# piece_tex가 없는 극단적 폴백 상태에서만 한자 표시
	if piece_tex == null:
		var shade := ColorRect.new()
		shade.color = Color(0.1, 0.06, 0.03, 0.45)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex_rect.add_child(shade)
		var big := Label.new()
		big.text = String(piece.get("seal", "史"))
		big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		big.add_theme_font_size_override("font_size", 90)
		big.add_theme_color_override("font_color", Color("fff1c8"))
		big.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		big.add_theme_constant_override("shadow_offset_x", 3)
		big.add_theme_constant_override("shadow_offset_y", 3)
		tex_rect.add_child(big)

	# 품격 있는 낙관 인장 (우측 상단 모서리에 작고 깔끔하게 배치)
	_seal = Label.new()
	_seal.text = String(piece.get("seal", "史"))
	_seal.add_theme_font_size_override("font_size", 16)
	_seal.add_theme_color_override("font_color", Color("fef3c7"))
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color("991b1b")
	ssb.border_color = Color("facc15")
	ssb.set_border_width_all(1)
	ssb.set_corner_radius_all(3)
	ssb.set_content_margin_all(4)
	_seal.add_theme_stylebox_override("normal", ssb)
	_seal.position = Vector2(10, 10)
	_illust_box.add_child(_seal)
