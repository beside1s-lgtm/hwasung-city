extends CanvasLayer
class_name StartGamePopup

## [화성성역 초기 게임 난이도 선택 모달 UI]
## 닥종이 한지 & 옻칠 목재 프레임 스타일로 구성된 새 게임 난이도(쉬움 / 보통 / 어려움) 선택 창

signal difficulty_selected(difficulty: int)
signal popup_closed

var root_control: Control
var modal_overlay: ColorRect
var modal_panel: PanelContainer
var audio_sys: AudioSystem = null

func _ready() -> void:
	layer = 125 # 타이틀(115) 및 HUD보다 상위
	_build_ui()
	_animate_open()

func _build_ui() -> void:
	root_control = Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_control)

	# 1. 배경 어두운 딤 오버레이
	modal_overlay = ColorRect.new()
	modal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_overlay.color = Color(0.02, 0.02, 0.03, 0.75)
	root_control.add_child(modal_overlay)

	# 2. 중앙 메인 패널 (1000 x 580)
	modal_panel = PanelContainer.new()
	modal_panel.anchor_left = 0.5
	modal_panel.anchor_top = 0.5
	modal_panel.anchor_right = 0.5
	modal_panel.anchor_bottom = 0.5
	modal_panel.offset_left = -500.0
	modal_panel.offset_top = -285.0
	modal_panel.offset_right = 500.0
	modal_panel.offset_bottom = 285.0
	modal_panel.custom_minimum_size = Vector2(1000, 570)
	root_control.add_child(modal_panel)

	# 닥종이 한지 & 옻칠 목재 테두리 스타일
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color("fef3c7") # 한지 베이지
	panel_sb.border_color = Color("451a03") # 옻칠 목재
	panel_sb.set_border_width_all(5)
	panel_sb.set_corner_radius_all(10)
	panel_sb.shadow_color = Color(0, 0, 0, 0.8)
	panel_sb.shadow_size = 28
	panel_sb.set_content_margin_all(18)
	modal_panel.add_theme_stylebox_override("panel", panel_sb)

	var vb_main := VBoxContainer.new()
	vb_main.add_theme_constant_override("separation", 14)
	modal_panel.add_child(vb_main)

	# 3. 헤더 바 (단청 주홍)
	var header_panel := PanelContainer.new()
	var h_sb := StyleBoxFlat.new()
	h_sb.bg_color = Color("991b1b") # 단청 주홍
	h_sb.set_content_margin_all(10)
	h_sb.set_corner_radius_all(6)
	header_panel.add_theme_stylebox_override("panel", h_sb)
	vb_main.add_child(header_panel)

	var hb_head := HBoxContainer.new()
	header_panel.add_child(hb_head)

	var title_lbl := Label.new()
	title_lbl.text = "화성성역의 길: 치세 난이도 결단"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_color_override("font_color", Color("fef3c7"))
	title_lbl.add_theme_font_size_override("font_size", 20)
	hb_head.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = " ✕ 닫기 "
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var c_sb := StyleBoxFlat.new()
	c_sb.bg_color = Color("7f1d1d")
	c_sb.set_corner_radius_all(4)
	close_btn.add_theme_stylebox_override("normal", c_sb)
	close_btn.pressed.connect(_on_close_pressed)
	hb_head.add_child(close_btn)

	# 안내 설명 라벨
	var subtitle_lbl := Label.new()
	subtitle_lbl.text = "성역을 일으키고 백성을 구휼할 정책 기조를 선택하시옵소서. 군왕의 결단에 따라 나라의 재정과 시련이 달라집니다."
	subtitle_lbl.add_theme_color_override("font_color", Color("78350f"))
	subtitle_lbl.add_theme_font_size_override("font_size", 14)
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb_main.add_child(subtitle_lbl)

	# 4. 난이도 카드 3종 수평 배치
	var cards_container := HBoxContainer.new()
	cards_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_container.add_theme_constant_override("separation", 14)
	vb_main.add_child(cards_container)

	_create_difficulty_card(
		cards_container,
		DifficultyManager.Difficulty.EASY,
		"태평성대",
		"쉬움",
		Color("15803d"), # 녹색 포인트
		Color("f0fdf4"), # 연녹 배경
		"기존 화성 축성의 재미를 편안하게 즐기는 입문용 난이도.\n자원이 풍족하게 공급되며 재정이 여유롭습니다.",
		[
			"• 건설비 및 물자 소모량 기본 (1.0x)",
			"• 공공기관 계절 유지비 없음",
			"• 상점 및 둔전 무제한 자연 확장",
			"• 흉년 구휼미 500석 고정 소모",
			"• 성벽 축성 노임 지출 없음"
		]
	)

	_create_difficulty_card(
		cards_container,
		DifficultyManager.Difficulty.NORMAL,
		"성역의 고난",
		"보통 (추천)",
		Color("0369a1"), # 청색 포인트
		Color("f0f9ff"), # 연청 배경
		"조선 후기 실제 경제 상황에 맞춘 역사적 고증 난이도.\n민가 없이는 상업과 농업이 자라지 않으며,\n유지비와 재난 관리가 성역의 성패를 가릅니다.",
		[
			"• 박석길 건설비: 흙길의 정확히 10배",
			"• 관리 녹봉 쉬움의 2배 & 세수 30% 감액",
			"• 인구 1만당 구휼미 10배 계단식 증액",
			"• 민가 1채당 상점 2채 / 둔전 30칸 제한",
			"• 공공기관 분기 유지비 20% & 인재 계절 녹봉 200냥",
			"• 성벽 1칸 축조 시 유급 노임(금 50 / 곡 20)",
			"• 가뭄/홍수 식량 -70%, 화재 세수 -80%"
		]
	)

	_create_difficulty_card(
		cards_container,
		DifficultyManager.Difficulty.HARD,
		"위기의 조선",
		"어려움",
		Color("b91c1c"), # 적색 포인트
		Color("fef2f2"), # 연적 배경
		"보통 난이도 대비 모든 지출과 자원 소모가 10% 증가하는 가혹한 시련.\n철저한 재정 계획과 엄격한 구휼 대책이 요구됩니다.",
		[
			"• 보통 난이도의 모든 제약 조건 기본 적용",
			"• 관리 녹봉 쉬움의 3배 & 세수 40% 감액",
			"• 모든 건설/유지비/노임 +10% 할증 (1.10x)",
			"• 박석길 포장비 흙길의 11배",
			"• 인재 계절 녹봉 300냥 (쉬움 기준 3배)",
			"• 축성 노임 금 55냥·곡 22석 (+10%)",
			"• 가뭄/홍수 식량 -80%, 화재 세수 -90%"
		]
	)

	# 5. 하단 알림 팁
	var tip_lbl := Label.new()
	tip_lbl.text = "※ 선택된 난이도는 실록 기록에 영구 보존되며, 치세 도중 변경할 수 없습니다."
	tip_lbl.add_theme_color_override("font_color", Color("92400e"))
	tip_lbl.add_theme_font_size_override("font_size", 12)
	tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb_main.add_child(tip_lbl)

func _create_difficulty_card(
	parent: HBoxContainer,
	diff_val: int,
	title_kr: String,
	badge_kr: String,
	accent_color: Color,
	bg_color: Color,
	desc_text: String,
	features: Array[String]
) -> void:
	var card_panel := PanelContainer.new()
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var c_sb := StyleBoxFlat.new()
	c_sb.bg_color = bg_color
	c_sb.border_color = accent_color
	c_sb.set_border_width_all(3)
	c_sb.set_corner_radius_all(8)
	c_sb.set_content_margin_all(14)
	c_sb.shadow_color = Color(0, 0, 0, 0.15)
	c_sb.shadow_size = 6
	card_panel.add_theme_stylebox_override("panel", c_sb)
	parent.add_child(card_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card_panel.add_child(vb)

	# 배지 (난이도 표기)
	var badge_panel := PanelContainer.new()
	var b_sb := StyleBoxFlat.new()
	b_sb.bg_color = accent_color
	b_sb.set_corner_radius_all(4)
	b_sb.set_content_margin_all(4)
	badge_panel.add_theme_stylebox_override("panel", b_sb)
	vb.add_child(badge_panel)

	var badge_lbl := Label.new()
	badge_lbl.text = badge_kr
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_color_override("font_color", Color.WHITE)
	badge_lbl.add_theme_font_size_override("font_size", 13)
	badge_panel.add_child(badge_lbl)

	# 제목
	var title_lbl := Label.new()
	title_lbl.text = title_kr
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color", accent_color)
	title_lbl.add_theme_font_size_override("font_size", 20)
	vb.add_child(title_lbl)

	# 구분선
	var sep := HSeparator.new()
	vb.add_child(sep)

	# 설명
	var desc_lbl := Label.new()
	desc_lbl.text = desc_text
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", Color("1f2937"))
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.custom_minimum_size = Vector2(0, 55)
	vb.add_child(desc_lbl)

	# 특징 리스트
	var feat_box := VBoxContainer.new()
	feat_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	feat_box.add_theme_constant_override("separation", 4)
	vb.add_child(feat_box)

	for f_str: String in features:
		var f_lbl := Label.new()
		f_lbl.text = f_str
		f_lbl.add_theme_color_override("font_color", Color("374151"))
		f_lbl.add_theme_font_size_override("font_size", 11)
		f_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		feat_box.add_child(f_lbl)

	# 선택 결단 버튼
	var btn := Button.new()
	btn.text = "%s 선택" % title_kr
	btn.custom_minimum_size = Vector2(0, 38)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = accent_color
	btn_normal.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = accent_color.lightened(0.2)
	btn_hover.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_press := StyleBoxFlat.new()
	btn_press.bg_color = accent_color.darkened(0.2)
	btn_press.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("pressed", btn_press)

	btn.pressed.connect(func(): _on_difficulty_chosen(diff_val))
	vb.add_child(btn)

func _animate_open() -> void:
	root_control.modulate.a = 0.0
	modal_panel.scale = Vector2(0.9, 0.9)
	modal_panel.pivot_offset = modal_panel.size * 0.5

	var tween := create_tween().set_parallel(true)
	tween.tween_property(root_control, "modulate:a", 1.0, 0.25)
	tween.tween_property(modal_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_difficulty_chosen(diff: int) -> void:
	if audio_sys:
		audio_sys.play("coin")
	DifficultyManager.set_difficulty(int(diff))
	difficulty_selected.emit(int(diff))
	_animate_close()

func _on_close_pressed() -> void:
	if audio_sys:
		audio_sys.play("pop")
	emit_signal("popup_closed")
	_animate_close()

func _animate_close() -> void:
	var tween := create_tween()
	tween.tween_property(root_control, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
