class_name BibyeonsaSiboPopup
extends CanvasLayer

## [비변사 시보 (備邊司 時報) 한글 신문 UI 및 관인 시스템]
## - 낡은 한지 텍스처와 먹물 붓글씨 레이아웃
## - 훈민정음/휴먼옛체 제호 및 궁서체 본문 기사
## - 우측 하단 절대 고정(Anchor Bottom-Right) 붉은 전통 전서체 사각 관인 [비변사印] 날인
## - 김홍도 풍속화 풍 도트 일러스트 아틀라스 삽화 연동
## - 전면 풀-핏(Full-Fit) 레이아웃 및 가독성 최적화
## - 격년 8턴 발간 및 보관함 열람 지원

signal closed

var sim: SimulationCore = null
var grid: GameGrid = null
var current_edition: Dictionary = {}
var edition_history: Array[Dictionary] = []
var current_history_index: int = -1

var _overlay: ColorRect = null
var _main_panel: PanelContainer = null
var _paper_tex_rect: TextureRect = null
var _chk_auto_show: CheckBox = null

# 레이아웃 노드
var _header_info_lbl: Label = null
var _main_headline_lbl: Label = null
var _main_subhead_lbl: Label = null
var _main_body_lbl: Label = null
var _main_interview_lbl: Label = null
var _main_art_rect: TextureRect = null

var _sub1_title_lbl: Label = null
var _sub1_body_lbl: Label = null
var _sub1_art_rect: TextureRect = null

var _sub2_title_lbl: Label = null
var _sub2_body_lbl: Label = null
var _sub2_art_rect: TextureRect = null

var _sub3_title_lbl: Label = null
var _sub3_body_lbl: Label = null
var _sub3_art_rect: TextureRect = null

var _seal_overlay_rect: TextureRect = null
var _archive_btn: Button = null

func _init() -> void:
	layer = 105 # 최상단 팝업 레이어

func _ready() -> void:
	_build_ui()
	visible = false

func setup(p_sim: SimulationCore, p_grid: GameGrid) -> void:
	sim = p_sim
	grid = p_grid

## 새로운 호수 발간 시 호출
func publish_edition(issue_num: int) -> void:
	current_edition = GazetteArticleDatabase.get_current_gazette_edition(sim, grid, issue_num)
	edition_history.append(current_edition)
	current_history_index = edition_history.size() - 1
	_bind_edition_data(current_edition)

## 특정 에디션 데이터 열람
func show_edition(edition: Dictionary) -> void:
	current_edition = edition
	_bind_edition_data(current_edition)
	_open_popup()

func show_latest() -> void:
	if edition_history.is_empty():
		publish_edition(1)
	else:
		current_history_index = edition_history.size() - 1
		show_edition(edition_history[current_history_index])

func _open_popup() -> void:
	visible = true
	if _overlay != null:
		_overlay.modulate.a = 0.0
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		tw.tween_property(_overlay, "modulate:a", 1.0, 0.25)
		if _main_panel != null:
			_main_panel.scale = Vector2(0.92, 0.92)
			_main_panel.pivot_offset = _main_panel.size * 0.5
			tw.tween_property(_main_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 1프레임 뒤 실제 렌더 크기 확정 후 인장 배치 계산
	if is_inside_tree() and get_tree() != null:
		await get_tree().process_frame
		if is_instance_valid(self) and visible:
			_update_seal_layout()

func _close_popup() -> void:
	var tw: Tween = create_tween()
	if _overlay != null:
		tw.tween_property(_overlay, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		visible = false
		emit_signal("closed")
	)

func _build_ui() -> void:
	# 배경 어두운 딤드 오버레이
	_overlay = ColorRect.new()
	_overlay.color = Color(0.05, 0.04, 0.03, 0.65)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	# 중앙 한지 신문 컨테이너 (Full-Fit 가로 1060px, 세로 680px)
	_main_panel = PanelContainer.new()
	_main_panel.custom_minimum_size = Vector2(1060, 680)
	_main_panel.set_anchors_preset(Control.PRESET_CENTER)
	_main_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_main_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_overlay.add_child(_main_panel)

	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color("f6f1e3")
	panel_sb.set_border_width_all(3)
	panel_sb.border_color = Color("2c241e")
	panel_sb.set_corner_radius_all(2)
	panel_sb.shadow_color = Color(0, 0, 0, 0.45)
	panel_sb.shadow_size = 14
	panel_sb.shadow_offset = Vector2(4, 6)
	_main_panel.add_theme_stylebox_override("panel", panel_sb)

	# 배경 한지 텍스처
	if ResourceLoader.exists("res://assets/ui/hanji_paper.png"):
		_paper_tex_rect = TextureRect.new()
		_paper_tex_rect.texture = load("res://assets/ui/hanji_paper.png")
		_paper_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_paper_tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
		_paper_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_paper_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_main_panel.add_child(_paper_tex_rect)

	# 신문 전체 마진 레이아웃
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	_main_panel.add_child(margin)

	var root_vb := VBoxContainer.new()
	root_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vb.add_theme_constant_override("separation", 8)
	margin.add_child(root_vb)

	# 1. 헤더 영역 (제호 및 발간 정보)
	var header_vb := _build_header()
	root_vb.add_child(header_vb)

	# 구분 두 줄 먹선 (전통 신문 양식)
	var double_line := _create_newspaper_divider(2)
	root_vb.add_child(double_line)

	# 2. 신문 본문 2대 칼럼 레이아웃 (HBox: 좌측 1면 톱기사 + 우측 3단 서브기사)
	var body_hb := HBoxContainer.new()
	body_hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hb.add_theme_constant_override("separation", 20)
	root_vb.add_child(body_hb)

	# 좌측 1면 톱기사 (헤드라인 + 김홍도 풍속화 삽화 + 상세 본문 + 바닥 인용문 상자)
	var left_col := _build_left_top_column()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.size_flags_stretch_ratio = 1.35
	body_hb.add_child(left_col)

	# 중앙 세로 먹선 구분선
	var v_sep := VSeparator.new()
	v_sep.add_theme_constant_override("separation", 4)
	var v_sep_sb := StyleBoxFlat.new()
	v_sep_sb.bg_color = Color("382e26")
	v_sep_sb.border_width_left = 1
	v_sep_sb.border_color = Color("382e26")
	v_sep.add_theme_stylebox_override("separator", v_sep_sb)
	body_hb.add_child(v_sep)

	# 우측 서브 컬럼 (3대 기사: 인터뷰/맛집 + 풍속/연애 + 장터 단신)
	var right_col := _build_right_column()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.size_flags_stretch_ratio = 1.25
	body_hb.add_child(right_col)

	# 하단 구분 먹선
	var bottom_div := _create_newspaper_divider(1)
	root_vb.add_child(bottom_div)

	# 3. 하단 제어부 (보관함, 닫기, 자동 팝업 체크박스)
	var footer_hb := _build_footer()
	root_vb.add_child(footer_hb)

	# 4. 실물 유물 스타일 붉은 전서체 관인 [비변사印] - 우측 하단 절대 고정 오버레이 (Bottom-Right)
	_build_absolute_seal_overlay()

func _build_header() -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)

	# 상단 대형 제호: 휴먼옛체 먹물 인쇄 효과
	var title_lbl := Label.new()
	title_lbl.text = "備 邊 司  時 報 (비 변 사  시 보)"
	ThemeManager.apply_title_font(title_lbl, 34)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color", Color("1c1612"))
	title_lbl.add_theme_constant_override("shadow_offset_x", 1)
	title_lbl.add_theme_constant_override("shadow_offset_y", 1)
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.2, 0.15, 0.1, 0.25))
	vb.add_child(title_lbl)

	# 발간 정보 박스
	_header_info_lbl = Label.new()
	_header_info_lbl.text = "정조 18년(갑인년) 가을호 | 제 1호 | 수원유수부 발행 | 정가: 무료 배포"
	ThemeManager.apply_base_font(_header_info_lbl, 14)
	_header_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_info_lbl.add_theme_color_override("font_color", Color("3d3128"))
	vb.add_child(_header_info_lbl)

	return vb

func _build_left_top_column() -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)

	# 1. 톱기사 헤드라인 (대형 강조: 26px, 볼드 휴먼옛체)
	_main_headline_lbl = Label.new()
	_main_headline_lbl.text = "천하제일 철옹성 수원화성 완공 대경사!"
	ThemeManager.apply_title_font(_main_headline_lbl, 26)
	_main_headline_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_main_headline_lbl.add_theme_color_override("font_color", Color("1a120c"))
	_main_headline_lbl.add_theme_constant_override("line_spacing", 4)
	vb.add_child(_main_headline_lbl)

	# 2. 부제목 (17px, 짙은 적갈색 #8B2500)
	_main_subhead_lbl = Label.new()
	_main_subhead_lbl.text = "정약용 나리의 거중기 활약... 2년 9개월 만에 둘레 5.7km 폐곡선 완성"
	ThemeManager.apply_title_font(_main_subhead_lbl, 17)
	_main_subhead_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_main_subhead_lbl.add_theme_color_override("font_color", Color("8b2500"))
	vb.add_child(_main_subhead_lbl)

	# 3. 삽화 및 톱기사 본문 가로 배치
	var art_and_text_hb := HBoxContainer.new()
	art_and_text_hb.add_theme_constant_override("separation", 14)
	vb.add_child(art_and_text_hb)

	# 김홍도 풍속화 도트 삽화 (1.3배 확대: 180x180 프레임)
	var art_frame := PanelContainer.new()
	art_frame.custom_minimum_size = Vector2(184, 184)
	var af_sb := StyleBoxFlat.new()
	af_sb.bg_color = Color("ebe0c6")
	af_sb.set_border_width_all(2)
	af_sb.border_color = Color("4a3c2c")
	af_sb.set_content_margin_all(2)
	art_frame.add_theme_stylebox_override("panel", af_sb)
	art_and_text_hb.add_child(art_frame)

	_main_art_rect = TextureRect.new()
	_main_art_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_main_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_main_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_main_art_rect.custom_minimum_size = Vector2(180, 180)
	art_frame.add_child(_main_art_rect)

	# 본문 텍스트 (17px, 행간 6px)
	_main_body_lbl = Label.new()
	_main_body_lbl.text = "장안문에서 팔달문, 화서문, 창룡문과 화홍문에 이르는 화성 성곽이 한 치의 빈틈도 없이 온전히 맞물렸다."
	ThemeManager.apply_base_font(_main_body_lbl, 17)
	_main_body_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_main_body_lbl.add_theme_color_override("font_color", Color("241d17"))
	_main_body_lbl.add_theme_constant_override("line_spacing", 6)
	art_and_text_hb.add_child(_main_body_lbl)

	# 4. 하단 인용문 상자 (바닥까지 꽉 채우는 여유 있는 패널: size_flags_vertical = EXPAND_FILL)
	var quote_panel := PanelContainer.new()
	quote_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var q_sb := StyleBoxFlat.new()
	q_sb.bg_color = Color(0.92, 0.88, 0.78, 0.85)
	q_sb.border_width_left = 4
	q_sb.border_color = Color("8b2500")
	q_sb.set_content_margin_all(14)
	q_sb.set_corner_radius_all(3)
	quote_panel.add_theme_stylebox_override("panel", q_sb)
	vb.add_child(quote_panel)

	_main_interview_lbl = Label.new()
	_main_interview_lbl.text = "도편수 이성길 영감은 '내 평생 전국의 궁궐과 성을 지어보았으나 이토록 견고하고 아름다운 성곽은 처음'이라며 눈시울을 붉혔다."
	ThemeManager.apply_base_font(_main_interview_lbl, 16)
	_main_interview_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_main_interview_lbl.add_theme_color_override("font_color", Color("3d2c20"))
	_main_interview_lbl.add_theme_constant_override("line_spacing", 6)
	quote_panel.add_child(_main_interview_lbl)

	return vb

func _build_right_column() -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)

	# 1. 우측 상단 기사 (인터뷰 / 맛집)
	var sub1_card := _build_sub_article_card(1)
	sub1_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sub1_card)

	# 중간 가로 먹선
	var mid_line1 := _create_newspaper_divider(1)
	vb.add_child(mid_line1)

	# 2. 우측 중단 기사 (풍속 / 연애 / 사건사고)
	var sub2_card := _build_sub_article_card(2)
	sub2_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sub2_card)

	# 중간 가로 먹선
	var mid_line2 := _create_newspaper_divider(1)
	vb.add_child(mid_line2)

	# 3. 우측 하단 기사 (장터 단신 / 풍류 - 지면 하단 풀핏 채움)
	var sub3_card := _build_sub_article_card(3)
	sub3_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sub3_card)

	return vb

func _build_sub_article_card(slot: int) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)

	var text_vb := VBoxContainer.new()
	text_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vb.add_theme_constant_override("separation", 4)
	var title_lbl := Label.new()
	ThemeManager.apply_title_font(title_lbl, 17)
	title_lbl.add_theme_color_override("font_color", Color("1c140e"))
	text_vb.add_child(title_lbl)

	var body_lbl := Label.new()
	ThemeManager.apply_base_font(body_lbl, 16)
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.add_theme_color_override("font_color", Color("28201a"))
	body_lbl.add_theme_constant_override("line_spacing", 6)
	text_vb.add_child(body_lbl)

	# 삽화 프레임 (정사각 104x104 — 기사 높이만큼 세로로 늘어나 그림이 긴 칸 가운데 작게 뜨지 않게 위에 붙임)
	var art_frame := PanelContainer.new()
	art_frame.custom_minimum_size = Vector2(104, 104)
	art_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var af_sb := StyleBoxFlat.new()
	af_sb.bg_color = Color("ebe0c6")
	af_sb.set_border_width_all(1)
	af_sb.border_color = Color("4a3c2c")
	af_sb.set_content_margin_all(2)
	art_frame.add_theme_stylebox_override("panel", af_sb)

	var art_rect := TextureRect.new()
	art_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR # 붓 그림 삽화는 부드럽게
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_rect.custom_minimum_size = Vector2(100, 100)
	art_frame.add_child(art_rect)

	# 슬롯 3(우측 하단)의 경우, 우측 하단 관인(인장)과 겹치지 않도록 삽화를 좌측에 배치하고
	# 슬롯 1, 2는 기존과 같이 우측에 삽화를 배치한다.
	if slot == 3:
		hb.add_child(art_frame)
		hb.add_child(text_vb)
	else:
		hb.add_child(text_vb)
		hb.add_child(art_frame)

	match slot:
		1:
			_sub1_title_lbl = title_lbl
			_sub1_body_lbl = body_lbl
			_sub1_art_rect = art_rect
		2:
			_sub2_title_lbl = title_lbl
			_sub2_body_lbl = body_lbl
			_sub2_art_rect = art_rect
		3:
			_sub3_title_lbl = title_lbl
			_sub3_body_lbl = body_lbl
			_sub3_art_rect = art_rect

	return hb

## 4. 실물 유물 스타일 붉은 전서체 관인 [비변사印] - 우측 하단 독립 오버레이
## PanelContainer는 자식 앵커를 fullrect로 덮어씌우므로, _overlay(ColorRect) 바로 아래
## 독립 Control로 배치하고 팝업 오픈 시 _main_panel 기준 절대 position 을 계산한다.
func _build_absolute_seal_overlay() -> void:
	_seal_overlay_rect = TextureRect.new()
	var seal_path := "res://assets/ui/bibyeonsa_official_seal.png"
	if ResourceLoader.exists(seal_path):
		_seal_overlay_rect.texture = load(seal_path)
	elif ResourceLoader.exists("res://assets/ui/bibyeonsa_seal_bg.png"):
		_seal_overlay_rect.texture = load("res://assets/ui/bibyeonsa_seal_bg.png")

	# 우측 하단 절대 고정(Bottom-Right Anchor)
	_seal_overlay_rect.anchor_left = 1.0
	_seal_overlay_rect.anchor_right = 1.0
	_seal_overlay_rect.anchor_top = 1.0
	_seal_overlay_rect.anchor_bottom = 1.0

	# 신문 패널 세로 높이 기준 18% = 약 122px (680 * 0.18)
	var seal_size: float = clampf(_main_panel.custom_minimum_size.y * 0.18, 100.0, 200.0)

	_seal_overlay_rect.size = Vector2(seal_size, seal_size)
	_seal_overlay_rect.custom_minimum_size = Vector2(seal_size, seal_size)

	# EXPAND_IGNORE_SIZE + KEEP_ASPECT: 1:1 비율 보존
	_seal_overlay_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_seal_overlay_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# 전서체 획 선명도
	_seal_overlay_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	# 인주 느낌의 미세 투명도
	_seal_overlay_rect.modulate = Color(1.0, 1.0, 1.0, 0.94)

	# 마우스 클릭 완전 투과
	_seal_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 아날로그 손도장 각도
	_seal_overlay_rect.rotation_degrees = -2.5

	# ★ _main_panel(PanelContainer) 바깥, _overlay 자식으로 등록
	# → PanelContainer의 레이아웃 강제(fullrect)를 완전히 우회
	_overlay.add_child(_seal_overlay_rect)

## 팝업 오픈 후 1프레임 뒤 _main_panel 실제 위치/크기 기준으로 인장 position 결정
func _update_seal_layout() -> void:
	if _seal_overlay_rect == null or _main_panel == null:
		return

	var paper_h: float = _main_panel.size.y
	var paper_w: float = _main_panel.size.x
	if paper_h < 10.0:
		paper_h = _main_panel.custom_minimum_size.y
	if paper_w < 10.0:
		paper_w = _main_panel.custom_minimum_size.x

	# 신문 패널 세로 높이 기준 약 16% (가로세로 약 110px, 15.6인치 화면 기준 단아한 관인 크기)
	# PORT-TRACE [인장 축소]: 기사를 덜 가리게 우측 하단 모서리를 그대로 둔 채 80%로
	var seal_size: float = clampf(paper_h * 0.16, 95.0, 140.0) * 0.8
	_seal_overlay_rect.size = Vector2(seal_size, seal_size)
	_seal_overlay_rect.custom_minimum_size = Vector2(seal_size, seal_size)
	_seal_overlay_rect.pivot_offset = Vector2(seal_size * 0.5, seal_size * 0.5)

	# 우측 하단 절대 고정(Bottom-Right Anchor) 명시 유지
	_seal_overlay_rect.anchor_left = 1.0
	_seal_overlay_rect.anchor_right = 1.0
	_seal_overlay_rect.anchor_top = 1.0
	_seal_overlay_rect.anchor_bottom = 1.0

	# _overlay는 PRESET_FULL_RECT이므로 position=(0,0)
	# _main_panel.position이 overlay 내 로컬 좌표와 동일
	var panel_pos: Vector2 = _main_panel.position

	# 우측 하단 마진: 우측 테두리로부터 36px, 하단 닫기 버튼 위쪽 70px
	# sub3의 삽화가 좌측으로 이동되어 우측 하단 지면에 사진 간섭 없이 깨끗하게 안착됨
	_seal_overlay_rect.position = Vector2(
		panel_pos.x + paper_w - seal_size - 36.0,
		panel_pos.y + paper_h - seal_size - 70.0
	)


## 지난 호에 담긴 옛 갈래 이름도 지금 이름으로(저잣거리 가십 → 저잣거리 소식)
func _cat_label(v: Variant) -> String:
	return str(v).replace("저잣거리 가십", "저잣거리 소식")

func _build_footer() -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)

	# 체크박스: 자동 팝업 토글
	_chk_auto_show = CheckBox.new()
	_chk_auto_show.text = "신문 발행 시 자동으로 펼치기"
	ThemeManager.apply_base_font(_chk_auto_show, 13)
	_chk_auto_show.button_pressed = GameSettings.is_auto_show_gazette()
	_chk_auto_show.add_theme_color_override("font_color", Color("28201a"))
	_chk_auto_show.toggled.connect(func(pressed: bool):
		GameSettings.set_auto_show_gazette(pressed)
	)
	hb.add_child(_chk_auto_show)

	# 여백 스트레치
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)

	# 다시 읽기 보관함 버튼
	_archive_btn = Button.new()
	_archive_btn.text = "📜 지난 호수 읽기"
	ThemeManager.apply_base_font(_archive_btn, 14)
	_archive_btn.custom_minimum_size = Vector2(150, 36)
	_apply_newspaper_btn_style(_archive_btn, Color("4a3c2c"), Color("ede4cf"))
	_archive_btn.pressed.connect(_on_archive_pressed)
	hb.add_child(_archive_btn)

	# 닫기 버튼
	var close_btn := Button.new()
	close_btn.text = "닫기 (보관함으로 이동)"
	ThemeManager.apply_base_font(close_btn, 14)
	close_btn.custom_minimum_size = Vector2(170, 36)
	_apply_newspaper_btn_style(close_btn, Color("7a2016"), Color("f6ede0"))
	close_btn.pressed.connect(_close_popup)
	hb.add_child(close_btn)

	return hb

func _create_newspaper_divider(thickness: int = 2) -> Control:
	var sep := HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 4)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("2c221a")
	sb.border_width_top = thickness
	sb.border_color = Color("2c221a")
	sep.add_theme_stylebox_override("separator", sb)
	return sep

func _apply_newspaper_btn_style(btn: Button, border_col: Color, bg_col: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg_col
	normal.set_border_width_all(1)
	normal.border_color = border_col
	normal.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = bg_col.lightened(0.08)
	hover.set_border_width_all(2)
	hover.border_color = border_col
	hover.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = bg_col.darkened(0.08)
	pressed.set_border_width_all(1)
	pressed.border_color = border_col
	pressed.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", Color("1c140e"))
	btn.add_theme_color_override("font_hover_color", Color("7a2016"))
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _bind_edition_data(data: Dictionary) -> void:
	if data.is_empty():
		return

	if _header_info_lbl:
		_header_info_lbl.text = str(data.get("header_date", ""))

	var main_d: Dictionary = data.get("main", {})
	if _main_headline_lbl:
		_main_headline_lbl.text = str(main_d.get("headline", ""))
	if _main_subhead_lbl:
		_main_subhead_lbl.text = str(main_d.get("subhead", ""))
	if _main_body_lbl:
		_main_body_lbl.text = str(main_d.get("body", ""))
	if _main_interview_lbl:
		_main_interview_lbl.text = str(main_d.get("interview", ""))
	if _main_art_rect:
		_set_art(_main_art_rect, GazetteArticleDatabase.art_texture(main_d))

	var sub1_d: Dictionary = data.get("sub1", {})
	if _sub1_title_lbl:
		_sub1_title_lbl.text = "【%s】 %s" % [_cat_label(sub1_d.get("category", "소식")), str(sub1_d.get("headline", ""))]
	if _sub1_body_lbl:
		_sub1_body_lbl.text = str(sub1_d.get("body", ""))
	if _sub1_art_rect:
		_set_art(_sub1_art_rect, GazetteArticleDatabase.art_texture(sub1_d))

	var sub2_d: Dictionary = data.get("sub2", {})
	if _sub2_title_lbl:
		_sub2_title_lbl.text = "【%s】 %s" % [_cat_label(sub2_d.get("category", "풍속")), str(sub2_d.get("headline", ""))]
	if _sub2_body_lbl:
		_sub2_body_lbl.text = str(sub2_d.get("body", ""))
	if _sub2_art_rect:
		_set_art(_sub2_art_rect, GazetteArticleDatabase.art_texture(sub2_d))

	var sub3_d: Dictionary = data.get("sub3", {})
	if _sub3_title_lbl:
		_sub3_title_lbl.text = "【%s】 %s" % [_cat_label(sub3_d.get("category", "단신")), str(sub3_d.get("headline", ""))]
	if _sub3_body_lbl:
		_sub3_body_lbl.text = str(sub3_d.get("body", ""))
	if _sub3_art_rect:
		_set_art(_sub3_art_rect, GazetteArticleDatabase.art_texture(sub3_d))

	if _archive_btn:
		_archive_btn.visible = edition_history.size() > 1

func _on_archive_pressed() -> void:
	if edition_history.size() <= 1:
		return
	# 이전 호수 순환 열람
	current_history_index = (current_history_index - 1 + edition_history.size()) % edition_history.size()
	_bind_edition_data(edition_history[current_history_index])

## 삽화 넣기: 새 붓 그림(assets/illustrations/gazette)은 부드럽게, 옛 도트 풍속화는 또렷하게(NEAREST)
func _set_art(rect: TextureRect, tex: Texture2D) -> void:
	rect.texture = tex
	var painted := tex != null and tex.resource_path.contains("illustrations/gazette")
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if painted else CanvasItem.TEXTURE_FILTER_NEAREST
