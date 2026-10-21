extends CanvasLayer
class_name HistoryEncyclopediaLayer
## PORT-TRACE [역사 사전 퍼즐 도감]: 타이틀 메뉴의 [역사 사전]을 텍스트 목록 대신 3개의 수원화성 직소 퍼즐판(역사 인물 12 · 화성 건축물 16 ·
## 백성의 생활상 20)으로 보여 준다. 인재 등용·시설 완공·살피기로 발견한 조각이 영구 해금되어 한 조각씩 맞춰지고, 조각을 누르면 읽을거리 창이 열린다.
## 한 판을 다 맞추면 금빛 폭죽과 축하 배너, 모든 판을 맞추면 궁중 취타 팡파르와 축하 창이 열린다.
## 화면 비율: 판은 AspectRatioContainer(3:2)에 넣어 해상도가 달라도 찌그러지지 않는다.

signal closed

var audio_sys: AudioSystem = null # 타이틀 화면이 넘겨 준다(없으면 효과음 생략)

var _root: Control
var _panel: PanelContainer
var _tabs: Array[Button] = []
var _cur := 0
var _aspect: AspectRatioContainer
var _view: PuzzleBoardView = null
var _list: VBoxContainer
var _desc: Label
var _bar: ProgressBar
var _bar_lbl: Label
var _full_btn: Button
var _detail: PuzzleDetailModal
var _fx: GoldSparkle
var _banner: PanelContainer
var _banner_lbl: Label
var _overlay: Control = null # 전체화면 감상 / 영상 / 올클리어 창(한 번에 하나)
var _loading: Dictionary = {}

func _ready() -> void:
	layer = 118 # 타이틀(115)·그 모달 위
	_build_ui()
	_select_tab(0)

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	_panel = PanelContainer.new()
	_panel.anchor_left = 0.03
	_panel.anchor_right = 0.97
	_panel.anchor_top = 0.04
	_panel.anchor_bottom = 0.96
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fef3c7")
	sb.border_color = Color("451a03")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.8)
	sb.shadow_size = 22
	sb.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_panel.add_child(vb)

	# 머리줄
	var head := PanelContainer.new()
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color("991b1b")
	hsb.set_content_margin_all(8)
	hsb.set_corner_radius_all(4)
	head.add_theme_stylebox_override("panel", hsb)
	vb.add_child(head)
	var hh := HBoxContainer.new()
	head.add_child(hh)
	var title := Label.new()
	title.text = "화성성역 역사 사전 — 수원화성 조각 맞추기 도감"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color("fef3c7"))
	hh.add_child(title)
	var close := Button.new()
	close.text = " ✕ "
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.pressed.connect(_close)
	hh.add_child(close)

	# 탭
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	vb.add_child(tab_row)
	var grp := ButtonGroup.new()
	for i in range(PuzzleData.BOARDS.size()):
		var tb := Button.new()
		tb.toggle_mode = true
		tb.button_group = grp
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size = Vector2(0, 38)
		tb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tb.pressed.connect(_select_tab.bind(i))
		tab_row.add_child(tb)
		_tabs.append(tb)

	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_color_override("font_color", Color("57534e"))
	_desc.add_theme_font_size_override("font_size", 13)
	vb.add_child(_desc)

	# 본문: 왼쪽 조각 목록(발견 여부·힌트) + 오른쪽 퍼즐판 (비율 고정)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	vb.add_child(body)
	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(250, 0)
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.99, 0.93, 0.76, 1.0)
	ssb.border_color = Color("a8884a")
	ssb.set_border_width_all(2)
	ssb.set_corner_radius_all(4)
	ssb.set_content_margin_all(8)
	side.add_theme_stylebox_override("panel", ssb)
	body.add_child(side)
	var sscroll := ScrollContainer.new()
	sscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(sscroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	sscroll.add_child(_list)
	_aspect = AspectRatioContainer.new()
	_aspect.ratio = PuzzleData.BOARD_SIZE.x / PuzzleData.BOARD_SIZE.y
	_aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	_aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_aspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_aspect)

	# 아래 줄: 진행도 + 버튼
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	vb.add_child(foot)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(220, 22)
	_bar.show_percentage = false
	foot.add_child(_bar)
	_bar_lbl = Label.new()
	_bar_lbl.add_theme_color_override("font_color", Color("1c1917"))
	_bar_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_bar_lbl)
	_full_btn = Button.new()
	_full_btn.text = "🖼 전체화면 감상"
	_full_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_full_btn.pressed.connect(_open_fullscreen)
	foot.add_child(_full_btn)

	# 상세 창 · 효과 · 배너 (맨 위)
	_detail = PuzzleDetailModal.new()
	_root.add_child(_detail)
	_fx = GoldSparkle.new()
	_root.add_child(_fx)
	_banner = PanelContainer.new()
	_banner.visible = false
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.offset_left = -330
	_banner.offset_right = 330
	_banner.offset_top = 70
	_banner.offset_bottom = 134
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.45, 0.08, 0.06, 0.96)
	bsb.border_color = Color("ffd75e")
	bsb.set_border_width_all(3)
	bsb.set_corner_radius_all(8)
	bsb.set_content_margin_all(12)
	_banner.add_theme_stylebox_override("panel", bsb)
	_banner_lbl = Label.new()
	_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_lbl.add_theme_font_size_override("font_size", 18)
	_banner_lbl.add_theme_color_override("font_color", Color("fff1a8"))
	_banner.add_child(_banner_lbl)
	_root.add_child(_banner)

# ---------------------------------------------------------------- 탭·판
func _refresh_tabs() -> void:
	for i in range(_tabs.size()):
		var b: Dictionary = PuzzleData.BOARDS[i]
		var id := String(b["id"])
		var n := GameProgressManager.unlocked_count(id)
		var tot := PuzzleData.pieces_of(id).size()
		_tabs[i].text = "%s %s  (%d/%d)%s" % [b["icon"], b["title"], n, tot, "  ✅" if n >= tot else ""]
		_tabs[i].set_pressed_no_signal(i == _cur)

func _select_tab(i: int) -> void:
	_cur = i
	var b: Dictionary = PuzzleData.BOARDS[i]
	var id := String(b["id"])
	if _view != null:
		_view.queue_free()
	_view = PuzzleBoardView.new()
	_aspect.add_child(_view)
	_view.setup(id)
	_view.piece_clicked.connect(_on_piece_clicked)
	var tex := PuzzleArt.cached(String(b["bg"]))
	if tex != null:
		_view.set_art(tex)
	else:
		_ensure_art(String(b["bg"]), i)
	_desc.text = "완성 그림: %s   |   %s" % [b["bg_title"], b["unlock_rule"]]
	_rebuild_list(id)
	_update_progress()
	_refresh_tabs()
	if id in GameProgressManager.pending_board_celebrations():
		get_tree().create_timer(0.7).timeout.connect(func(): _celebrate_board(id))

func _update_progress() -> void:
	var id := String(PuzzleData.BOARDS[_cur]["id"])
	var n := GameProgressManager.unlocked_count(id)
	var tot := PuzzleData.pieces_of(id).size()
	_bar.max_value = float(tot)
	_bar.value = float(n)
	_bar_lbl.text = "발견한 조각 %d / %d" % [n, tot]
	_full_btn.disabled = n < tot
	_full_btn.text = "🎬 완성 영상 감상" if PuzzleArt.video_path(String(PuzzleData.BOARDS[_cur]["bg"])) != "" else "🖼 전체화면 감상"

## 왼쪽 목록: 맞춘 조각은 이름(눌러서 읽기), 못 맞춘 조각은 힌트
func _rebuild_list(bid: String) -> void:
	for ch in _list.get_children():
		ch.queue_free()
	for pc: Dictionary in PuzzleData.pieces_of(bid):
		var pid := String(pc["id"])
		if GameProgressManager.is_unlocked(bid, pid):
			var btn := Button.new()
			btn.text = "%s %s  (%s)" % ["▶" if bid == "endings" else "✔", pc["name"], pc["hanja"]]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.flat = true
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.add_theme_color_override("font_color", Color("14532d"))
			btn.add_theme_font_size_override("font_size", 13)
			btn.pressed.connect(_on_piece_clicked.bind(pid))
			_list.add_child(btn)
		else:
			var l := Label.new()
			l.text = "?  미지의 조각 — %s" % pc["hint"]
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.add_theme_color_override("font_color", Color("78716c"))
			l.add_theme_font_size_override("font_size", 12)
			_list.add_child(l)

## 판 그림을 코드로 한 번 그려 텍스처로 만든다(SubViewport → 이미지). 캐시되어 다음부터는 즉시.
func _ensure_art(bg: String, board_index: int) -> void:
	if _loading.has(bg):
		return
	var ext_tex := PuzzleArt.external_texture(bg)
	if ext_tex != null:
		PuzzleArt.set_cached(bg, ext_tex)
		if is_instance_valid(_view) and _cur == board_index:
			_view.set_art(ext_tex)
		return
	_loading[bg] = true
	var vp := SubViewport.new()
	vp.size = Vector2i(int(PuzzleData.BOARD_SIZE.x), int(PuzzleData.BOARD_SIZE.y))
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var art := PuzzleArt.new()
	art.scene_id = bg
	vp.add_child(art)
	add_child(vp)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image() if vp.get_texture() != null else null
	vp.queue_free()
	if img == null or img.is_empty():
		_loading.erase(bg)
		return
	var tex := ImageTexture.create_from_image(img)
	PuzzleArt.set_cached(bg, tex)
	if is_instance_valid(_view) and _cur == board_index:
		_view.set_art(tex)

# ---------------------------------------------------------------- 조각 상세
func _on_piece_clicked(piece_id: String) -> void:
	var b: Dictionary = PuzzleData.BOARDS[_cur]
	var bid := String(b["id"])
	if not GameProgressManager.is_unlocked(bid, piece_id):
		return
	var pieces := PuzzleData.pieces_of(bid)
	for i in range(pieces.size()):
		if String(pieces[i]["id"]) == piece_id:
			if bid == "endings":
				_play_ending(pieces[i])
				return
			var crop := _view.piece_rect(i)
			_detail.show_piece(b, pieces[i], PuzzleArt.cached(String(b["bg"])), crop)
			if audio_sys != null:
				audio_sys.play("select")
			return

## 맞춘 엔딩 조각을 누르면 그 시네마틱 영상을 다시 본다(영상이 없으면 엔딩 이야기 글만 보여 준다)
func _play_ending(pc: Dictionary) -> void:
	var key := String(pc.get("ending_key", ""))
	var data: Dictionary = EndingManager.ENDING_DATA.get(key, {})
	if data.is_empty():
		for k in EndingManager.ENDING_DATA:
			if String(EndingManager.ENDING_DATA[k].get("type", "")) == String(pc.get("ending_type", "")):
				data = EndingManager.ENDING_DATA[k]
	var path := EndingManager.get_ending_video_path(data)
	if path != "":
		var vl := EndingVideoLayer.new()
		add_child(vl)
		vl.play_video(path, String(data.get("title", "")), String(data.get("subtitle", "")))
	else:
		_detail.show_piece(PuzzleData.board("endings"), pc, null, Rect2())

# ---------------------------------------------------------------- 완성 연출
func _show_banner(text: String, seconds: float = 4.0) -> void:
	_banner_lbl.text = text
	_banner.modulate.a = 0.0
	_banner.visible = true
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.4)
	tw.tween_interval(seconds)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func(): _banner.visible = false)

func _celebrate_board(bid: String) -> void:
	if not (bid in GameProgressManager.pending_board_celebrations()):
		return
	GameProgressManager.mark_board_celebrated(bid)
	var b: Dictionary = PuzzleData.board(bid)
	# 황금빛 폭죽(gold_sparkle_fx) + 배너 + 테두리 광택
	var c := _fx.size * 0.5
	_fx.burst(c + Vector2(-160, -40), 90, 380.0)
	_fx.burst(c + Vector2(180, -70), 90, 380.0, 0.05)
	_fx.burst(c + Vector2(0, 50), 110, 440.0, -0.02)
	_fx.shower(70)
	if audio_sys != null:
		audio_sys.play("coin")
	_show_banner("🎉 [축하] <%s> 조각판을 완벽히 완성하셨습니다!" % b["title"])
	if is_instance_valid(_view):
		var tw := create_tween()
		tw.tween_method(func(v: float):
			if is_instance_valid(_view):
				_view.glow = v
				_view.queue_redraw()
		, 0.0, 1.0, 0.6)
		tw.tween_method(func(v: float):
			if is_instance_valid(_view):
				_view.glow = v
				_view.queue_redraw()
		, 1.0, 0.35, 1.6)
		for i in range(_view.pieces.size()):
			_view.flash_piece(i)
	_update_progress()
	_refresh_tabs()
	var cin_delay := 0.0
	if PuzzleArt.video_path(String(b["bg"])) != "":
		# 완성 폭죽이 가라앉으면 사진에서 이어지는 완성 영상을 보여 준다
		cin_delay = 3.0
		get_tree().create_timer(cin_delay).timeout.connect(func():
			if is_instance_valid(self) and String(PuzzleData.BOARDS[_cur]["id"]) == bid:
				_open_fullscreen()
		)
	if GameProgressManager.all_clear_pending():
		get_tree().create_timer(3.4 + (28.0 if cin_delay > 0.0 else 0.0)).timeout.connect(_all_clear)

func _all_clear() -> void:
	if not GameProgressManager.all_clear_pending():
		return
	GameProgressManager.mark_all_clear_seen()
	_close_overlay()
	_fx.fireworks(5.0)
	if audio_sys != null:
		audio_sys.play("yajo") # 궁중 취타(북·징) 팡파르
	var ov := _make_overlay()
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.offset_left = -360
	p.offset_right = 360
	p.offset_top = -170
	p.offset_bottom = 170
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.32, 0.05, 0.04, 0.97)
	sb.border_color = Color("ffd75e")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(24)
	p.add_theme_stylebox_override("panel", sb)
	ov.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var t := Label.new()
	t.text = "👑 [대조선 문예 부흥의 완성]"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", Color("ffe27a"))
	v.add_child(t)
	var m := Label.new()
	m.text = "수원화성의 모든 역사와 백성의 삶을 집대성하셨습니다!\n\n정조 대왕이 꿈꾸던 새 도시의 이야기가 마지막 조각까지 맞춰졌습니다."
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.add_theme_font_size_override("font_size", 17)
	m.add_theme_color_override("font_color", Color("fff1c8"))
	v.add_child(m)
	var ok := Button.new()
	ok.text = "  확인  "
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_close_overlay)
	v.add_child(ok)
	_update_progress()

# ---------------------------------------------------------------- 오버레이(전체화면 감상·영상·올클리어)
func _make_overlay() -> Control:
	_close_overlay()
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var d := ColorRect.new()
	d.color = Color(0, 0, 0, 0.88)
	d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(d)
	_root.add_child(_overlay)
	# 폭죽이 오버레이 위에 보이도록 맨 위로
	_root.move_child(_fx, _root.get_child_count() - 1)
	return _overlay

func _close_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		# 영상은 닫는 즉시 멈추고 메모리에서 내린다(지연 로딩)
		for ch in _overlay.get_children():
			if ch is VideoStreamPlayer:
				(ch as VideoStreamPlayer).stop()
				(ch as VideoStreamPlayer).stream = null
		_overlay.queue_free()
	_overlay = null

## 사진에서 이어지는 완성 영상: 먼저 사진이 천천히 확대되며 보이고, 영상이 사진 위로 부드럽게 겹쳐 나타나 재생된다.
## 영상은 사진으로 만든 board_<id>.ogv 이므로 첫 장면이 사진과 같아 끊김이 없다. 끝나면 마지막 장면에 머물고 클릭하면 닫힌다.
func _open_cinematic(b: Dictionary, vpath: String) -> void:
	var bg_id := String(b["bg"])
	var ov := _make_overlay()
	ov.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_close_overlay()
	)
	var photo: Texture2D = PuzzleArt.original_texture(bg_id)
	if photo == null:
		photo = PuzzleArt.cached(bg_id)
	var ratio := 16.0 / 9.0
	if photo != null:
		ratio = float(photo.get_width()) / float(photo.get_height())
	var asp := AspectRatioContainer.new()
	asp.ratio = ratio
	asp.stretch_mode = AspectRatioContainer.STRETCH_FIT
	asp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	asp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(asp)
	var stage := Control.new()
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	asp.add_child(stage)
	var pic := TextureRect.new()
	pic.texture = photo
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.pivot_offset = Vector2(640, 360)
	pic.modulate.a = 0.0
	stage.add_child(pic)
	var vp := VideoStreamPlayer.new()
	vp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp.expand = true
	vp.stream = load(vpath) as VideoStream
	vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.modulate.a = 0.0
	stage.add_child(vp)
	var cap := Label.new()
	cap.text = "%s — 누르면 닫힙니다" % b["bg_title"]
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	cap.offset_top = -40
	cap.add_theme_color_override("font_color", Color("fff1c8"))
	cap.add_theme_font_size_override("font_size", 16)
	cap.modulate.a = 0.0
	ov.add_child(cap)
	# 1) 사진이 어둠 속에서 떠오르며 천천히 다가온다  2) 영상이 사진 위로 번져 나오며 재생  3) 끝나면 제목 안내
	var tw := create_tween()
	tw.tween_property(pic, "modulate:a", 1.0, 1.0)
	tw.parallel().tween_property(pic, "scale", Vector2(1.04, 1.04), 2.6).from(Vector2(1.0, 1.0))
	tw.tween_callback(func():
		if is_instance_valid(vp):
			vp.play()
	)
	tw.tween_property(vp, "modulate:a", 1.0, 0.9)
	vp.finished.connect(func():
		if is_instance_valid(cap):
			create_tween().tween_property(cap, "modulate:a", 1.0, 0.8)
		if audio_sys != null:
			audio_sys.play("coin")
	)
	if audio_sys != null:
		audio_sys.play("season")
	_fx.shower(40)

func _open_fullscreen() -> void:
	var b: Dictionary = PuzzleData.BOARDS[_cur]
	var vpath := PuzzleArt.video_path(String(b["bg"]))
	if vpath != "":
		_open_cinematic(b, vpath)
		return
	var tex := PuzzleArt.cached(String(b["bg"]))
	var ov := _make_overlay()
	ov.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_close_overlay()
	)
	if tex != null:
		var tex_rect := TextureRect.new()
		tex_rect.texture = tex
		tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex_rect.offset_left = 40
		tex_rect.offset_right = -40
		tex_rect.offset_top = 40
		tex_rect.offset_bottom = -70
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ov.add_child(tex_rect)
	var cap := Label.new()
	cap.text = "%s — 누르면 닫힙니다" % b["bg_title"]
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	cap.offset_top = -56
	cap.add_theme_color_override("font_color", Color("fff1c8"))
	cap.add_theme_font_size_override("font_size", 18)
	ov.add_child(cap)
	_fx.shower(40)

# ---------------------------------------------------------------- 닫기
func _close() -> void:
	_close_overlay()
	emit_signal("closed")
	queue_free()

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE:
		if _overlay != null and is_instance_valid(_overlay):
			_close_overlay()
		elif _detail.visible:
			_detail.close()
		else:
			_close()
		get_viewport().set_input_as_handled()
