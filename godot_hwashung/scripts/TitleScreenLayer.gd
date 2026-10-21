extends CanvasLayer
class_name TitleScreenLayer

## [화성성역 타이틀 화면 UI 컨트롤러]
## 인트로 영상 종료 후 자연스러운 크로스페이드로 전환되며,
## 원작 고화질 아트워크 기반의 5대 메인 메뉴 버튼 및 모달 시스템을 제공합니다.

signal start_new_game
## 이어하기: Main이 넣어 주는 불러오기 함수 (slot: int) -> bool. 성공하면 true.
var load_handler: Callable = Callable()

var root_control: Control
var aspect_container: AspectRatioContainer
var bg_texture_rect: TextureRect
var _title_img: Image = null # 버튼 모양을 오려 낼 타이틀 그림
var button_container: Control
var audio_sys: AudioSystem

var _is_starting: bool = false
var _modal_overlay: ColorRect
var _modal_panel: PanelContainer
var _modal_title: Label
var _modal_body: VBoxContainer
var _is_muted: bool = false

const TITLE_ASPECT_RATIO := 1280.0 / 720.0 # 인트로 영상 마지막 장면(16:9)과 똑같이 맞춘다

func _ready() -> void:
	layer = 115 # 인트로(120) 바로 아래, 게임 HUD/월드 위

	# 1. 전체 화면 루트 컨트롤 (페이드 트윈 담당)
	root_control = Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	# 칠흑 배경
	var bg_black := ColorRect.new()
	bg_black.color = Color(0.04, 0.03, 0.02, 1.0)
	bg_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(bg_black)

	# 2. 비율 유지 컨테이너 (1024:558)
	aspect_container = AspectRatioContainer.new()
	aspect_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	aspect_container.ratio = TITLE_ASPECT_RATIO
	aspect_container.stretch_mode = AspectRatioContainer.STRETCH_FIT
	root_control.add_child(aspect_container)

	# 3. 타이틀 아트워크 TextureRect
	bg_texture_rect = TextureRect.new()
	bg_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	var tex: Texture2D = load("res://assets/title_screen_main.jpg") as Texture2D
	if tex:
		bg_texture_rect.texture = tex
		_title_img = tex.get_image()
	aspect_container.add_child(bg_texture_rect)

	# 4. 버튼 오버레이 컨테이너 (TextureRect와 동일 비율로 일치)
	button_container = Control.new()
	button_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_texture_rect.add_child(button_container)

	_setup_menu_buttons()
	_setup_corner_icons()
	_setup_modal_system()

	GameSettings.ensure_loaded()
	GameSettings.apply_all()

	# 시작 시 반투명 준비
	root_control.modulate.a = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_F11:
			GameSettings.toggle_fullscreen()
			get_viewport().set_input_as_handled()

## 인트로에서 타이틀로의 부드러운 페이드인 트랜지션
func show_title_screen(fade_duration: float = 0.8) -> void:
	visible = true
	root_control.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(root_control, "modulate:a", 1.0, fade_duration)

## 5대 메인 메뉴 버튼 배치 (이미지 그래픽 프레임에 정확히 오버레이)
func _setup_menu_buttons() -> void:
	# 버튼 정의: {id, x_min, x_max, y_min, y_max, tooltip}
	# 전체 1024x558 기준 정밀 비율 좌표
	var btn_defs: Array[Dictionary] = [
		{"id": "new_game", "x0": 0.120, "x1": 0.262, "y0": 0.555, "y1": 0.715, "name": "새 치세"},
		{"id": "continue", "x0": 0.277, "x1": 0.415, "y0": 0.555, "y1": 0.715, "name": "불러오기"},
		{"id": "guide", "x0": 0.431, "x1": 0.570, "y0": 0.555, "y1": 0.715, "name": "도움말"},
		{"id": "chronicles", "x0": 0.586, "x1": 0.725, "y0": 0.555, "y1": 0.715, "name": "역사 사전"},
		{"id": "quit", "x0": 0.741, "x1": 0.879, "y0": 0.555, "y1": 0.715, "name": "끝내기"}
	]

	for d: Dictionary in btn_defs:
		var btn := _make_image_button(d, false)
		btn.tooltip_text = d["name"]
		var bid: String = d["id"]
		btn.pressed.connect(func(): _on_menu_button_pressed(bid))
		btn.hovered.connect(_on_button_hover)
		button_container.add_child(btn)

## 타이틀 그림에서 버튼 자리를 오려 hover(밝게)·눌림(들어가는 느낌) 효과를 주는 버튼을 만든다
func _make_image_button(d: Dictionary, as_round: bool) -> TitleImageButton:
	var btn := TitleImageButton.new()
	btn.anchor_left = d["x0"]
	btn.anchor_right = d["x1"]
	btn.anchor_top = d["y0"]
	btn.anchor_bottom = d["y1"]
	btn.offset_left = 0
	btn.offset_top = 0
	btn.offset_right = 0
	btn.offset_bottom = 0
	if _title_img != null:
		var iw := _title_img.get_width()
		var ih := _title_img.get_height()
		var rc := Rect2i(int(float(d["x0"]) * float(iw)), int(float(d["y0"]) * float(ih)), int(float(float(d["x1"]) - float(d["x0"])) * float(iw)), int(float(float(d["y1"]) - float(d["y0"])) * float(ih)))
		btn.setup(_title_img, rc, as_round)
	return btn

## 외곽 코너 아이콘 배치 (하단 중복 버튼 제거하고 상단 정위치 아이콘만 유지)
func _setup_corner_icons() -> void:
	var corners: Array[Dictionary] = [
		{"id": "settings_tl", "x0": 0.014, "x1": 0.054, "y0": 0.034, "y1": 0.106, "tip": "환경 설정"},
		{"id": "sound_tr", "x0": 0.859, "x1": 0.898, "y0": 0.034, "y1": 0.106, "tip": "음향 켜기·끄기"},
		{"id": "sound_tr", "x0": 0.904, "x1": 0.943, "y0": 0.034, "y1": 0.106, "tip": "음향 켜기·끄기"},
		{"id": "quit_tr", "x0": 0.948, "x1": 0.986, "y0": 0.034, "y1": 0.106, "tip": "끝내기"},
		{"id": "credits", "x0": 0.014, "x1": 0.054, "y0": 0.895, "y1": 0.972, "tip": "작품 정보 및 만든 사람들"}
	]

	for c: Dictionary in corners:
		var btn := _make_image_button(c, true)
		btn.tooltip_text = c["tip"]
		var cid: String = c["id"]
		btn.pressed.connect(func(): _on_corner_button_pressed(cid))
		btn.hovered.connect(_on_button_hover)
		button_container.add_child(btn)

func _on_button_hover() -> void:
	if audio_sys:
		audio_sys.play("pop")

## 메뉴 버튼 클릭 라우팅
func _on_menu_button_pressed(btn_id: String) -> void:
	if _is_starting:
		return
	if audio_sys:
		audio_sys.play("coin")

	match btn_id:
		"new_game":
			_open_difficulty_select_popup()
		"continue":
			_open_load_modal()
		"guide":
			_open_guide_modal()
		"chronicles":
			_open_chronicles_modal()
		"quit":
			_open_quit_modal()

func _on_corner_button_pressed(cid: String) -> void:
	if audio_sys:
		audio_sys.play("coin")
	match cid:
		"settings_tl":
			_open_settings_modal()
		"credits":
			_open_credits_modal()
		"sound_tr":
			_toggle_mute()
		"quit_tr":
			_open_quit_modal()

## 새 게임 시작 트랜지션
func _open_difficulty_select_popup() -> void:
	var popup: StartGamePopup = StartGamePopup.new()
	popup.audio_sys = audio_sys
	add_child(popup)
	popup.difficulty_selected.connect(func(_diff: int):
		_start_new_game_sequence()
	)

## 이어하기 성공 뒤: 타이틀을 걷어 내고 불러온 세상으로 들어간다(새 게임 신호는 보내지 않는다)
func _finish_load_sequence() -> void:
	_is_starting = true
	var tween := create_tween()
	tween.tween_property(root_control, "modulate:a", 0.0, 0.75)
	tween.tween_callback(func():
		visible = false
		queue_free()
	)

func _start_new_game_sequence() -> void:
	_is_starting = true
	var tween := create_tween()
	tween.tween_property(root_control, "modulate:a", 0.0, 0.75)
	tween.tween_callback(func():
		emit_signal("start_new_game")
		visible = false
		queue_free()
	)

func _toggle_mute() -> void:
	_is_muted = not _is_muted
	var master_bus_idx := AudioServer.get_bus_index("Master")
	if master_bus_idx >= 0:
		AudioServer.set_bus_mute(master_bus_idx, _is_muted)
	_open_toast("소리가 %s되었습니다." % ("음소거" if _is_muted else "켜짐"))

# ------------------------------------------------------------ 자체 모달 시스템 (닥종이 한지 & 옻칠 목재 프레임)
func _setup_modal_system() -> void:
	# 모달 배경 딤
	_modal_overlay = ColorRect.new()
	_modal_overlay.visible = false
	_modal_overlay.color = Color(0, 0, 0, 0.7)
	_modal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_modal()
	)
	root_control.add_child(_modal_overlay)

	# 모달 메인 프레임
	_modal_panel = PanelContainer.new()
	_modal_panel.visible = false
	# 화면 폭의 약 80%로 넓혀 기록 한 줄이 가로 스크롤 없이 다 보이게 한다
	_modal_panel.anchor_left = 0.1
	_modal_panel.anchor_top = 0.14
	_modal_panel.anchor_right = 0.9
	_modal_panel.anchor_bottom = 0.86
	_modal_panel.offset_left = 0.0
	_modal_panel.offset_top = 0.0
	_modal_panel.offset_right = 0.0
	_modal_panel.offset_bottom = 0.0
	_modal_panel.custom_minimum_size = Vector2(680, 440)
	root_control.add_child(_modal_panel)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fef3c7") # 닥종이 한지 베이지
	sb.border_color = Color("451a03") # 옻칠 목재 프레임
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.75)
	sb.shadow_size = 20
	sb.set_content_margin_all(14)
	_modal_panel.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_modal_panel.add_child(vb)

	# 제목 헤더 바 (단청 주홍)
	var title_panel := PanelContainer.new()
	var t_sb := StyleBoxFlat.new()
	t_sb.bg_color = Color("991b1b")
	t_sb.set_content_margin_all(8)
	t_sb.set_corner_radius_all(4)
	title_panel.add_theme_stylebox_override("panel", t_sb)
	vb.add_child(title_panel)

	var hb_title := HBoxContainer.new()
	title_panel.add_child(hb_title)

	_modal_title = Label.new()
	_modal_title.text = "제목"
	_modal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_title.add_theme_color_override("font_color", Color("fef3c7"))
	_modal_title.add_theme_font_size_override("font_size", 15)
	hb_title.add_child(_modal_title)

	var close_btn := Button.new()
	close_btn.text = " ✕ "
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(_close_modal)
	hb_title.add_child(close_btn)

	# 본문 스크롤 영역
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	_modal_body = VBoxContainer.new()
	_modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_modal_body)

func _open_modal(title: String) -> void:
	_modal_title.text = title
	for ch in _modal_body.get_children():
		ch.queue_free()
	_modal_overlay.visible = true
	_modal_panel.visible = true

func _close_modal() -> void:
	_modal_overlay.visible = false
	_modal_panel.visible = false

# ------------------------------------------------------------ 각 모달 컨텐츠 구현
func _open_load_modal() -> void:
	_open_modal("기록 불러오기")

	var desc := Label.new()
	desc.text = "보존된 선대 어록과 축성 실록 권을 선택하여 치세를 이어가거나 파기하십시오."
	desc.add_theme_color_override("font_color", Color("1c1917"))
	_modal_body.add_child(desc)

	var slot_indices: Array[int] = SaveSystem.SLOTS

	for slot_idx: int in slot_indices:
		var has_data: bool = SaveSystem.has_save(slot_idx)
		var s_data: Dictionary = SaveSystem.get_save_info(slot_idx) if has_data else {}

		var s_title: String = SaveSystem.get_formatted_title(slot_idx, s_data)
		var s_detail: String = ""

		if has_data:
			s_detail = "인구 %d명 | 국고 %d냥 | 군량 %d석 | 성곽 %d%% | 치수 %d%% (보존일시: %s)" % [
				int(s_data.get("pop", 120)), int(s_data.get("gold", 2500)), int(s_data.get("rice", 1600)),
				int(s_data.get("fortress", 0)), int(s_data.get("flood_defense", 0)),
				s_data.get("timestamp", "미상")
			]
		else:
			s_detail = "보존된 기록이 없습니다. 새로운 치세를 시작할 수 있습니다."

		var panel := PanelContainer.new()
		var psb := StyleBoxFlat.new()
		psb.bg_color = Color(0.95, 0.90, 0.80, 0.95) if has_data else Color(0.88, 0.84, 0.76, 0.7)
		psb.border_color = Color("8c7353") if has_data else Color("a89f91")
		psb.set_border_width_all(1)
		psb.set_corner_radius_all(4)
		psb.set_content_margin_all(8)
		panel.add_theme_stylebox_override("panel", psb)
		_modal_body.add_child(panel)

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		panel.add_child(hb)

		var vb_info := VBoxContainer.new()
		vb_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(vb_info)

		var l1 := Label.new()
		l1.text = s_title
		l1.add_theme_color_override("font_color", Color("991b1b") if has_data else Color("78716c"))
		l1.add_theme_font_size_override("font_size", 13)
		l1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l1.custom_minimum_size = Vector2(120, 0)
		vb_info.add_child(l1)

		var l2 := Label.new()
		l2.text = s_detail
		l2.add_theme_color_override("font_color", Color("44403c") if has_data else Color("a8a29e"))
		l2.add_theme_font_size_override("font_size", 11)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l2.custom_minimum_size = Vector2(120, 0)
		vb_info.add_child(l2)

		if has_data:
			# 1. 삭제(휴지통) 버튼 (이미지 1 요청 위치: 이어하기 좌측)
			var del_btn := Button.new()
			del_btn.text = "🗑️ 삭제"
			del_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			del_btn.custom_minimum_size = Vector2(70, 32)
			del_btn.add_theme_color_override("font_color", Color(0.98, 0.88, 0.88))
			del_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
			del_btn.add_theme_font_size_override("font_size", 12)

			var d_sb := StyleBoxFlat.new()
			d_sb.bg_color = Color(0.60, 0.15, 0.15, 0.90) # 단청 암적색
			d_sb.border_color = Color(0.85, 0.30, 0.30, 1.0)
			d_sb.set_border_width_all(1)
			d_sb.set_corner_radius_all(4)
			del_btn.add_theme_stylebox_override("normal", d_sb)

			var d_hsb := d_sb.duplicate() as StyleBoxFlat
			d_hsb.bg_color = Color(0.80, 0.20, 0.20, 1.0)
			d_hsb.border_color = Color(1.0, 0.60, 0.60, 1.0)
			del_btn.add_theme_stylebox_override("hover", d_hsb)

			var captured_title: String = s_title
			del_btn.pressed.connect(func():
				if audio_sys: audio_sys.play("pop")
				_open_confirm_delete_modal(slot_idx, captured_title)
			)
			hb.add_child(del_btn)

			# 2. 이어하기 버튼
			var load_btn := Button.new()
			load_btn.text = "이어하기"
			load_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			load_btn.custom_minimum_size = Vector2(80, 32)
			load_btn.add_theme_font_size_override("font_size", 12)

			var l_sb := StyleBoxFlat.new()
			l_sb.bg_color = Color(0.18, 0.12, 0.08, 0.95)
			l_sb.border_color = Color(0.85, 0.65, 0.35, 1.0)
			l_sb.set_border_width_all(1)
			l_sb.set_corner_radius_all(4)
			load_btn.add_theme_stylebox_override("normal", l_sb)

			var l_hsb := l_sb.duplicate() as StyleBoxFlat
			l_hsb.bg_color = Color(0.30, 0.20, 0.12, 1.0)
			l_hsb.border_color = Color(0.98, 0.85, 0.40, 1.0)
			load_btn.add_theme_stylebox_override("hover", l_hsb)

			var load_slot: int = slot_idx
			load_btn.pressed.connect(func():
				if audio_sys: audio_sys.play("coin")
				if not load_handler.is_valid():
					return
				if bool(load_handler.call(load_slot)):
					_close_modal()
					_finish_load_sequence()
				else:
					if audio_sys: audio_sys.play("error")
					load_btn.text = "불러오기 실패"
			)
			hb.add_child(load_btn)
		else:
			# 빈 슬롯: 새로 시작 버튼
			var start_btn := Button.new()
			start_btn.text = "새로 시작"
			start_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			start_btn.custom_minimum_size = Vector2(80, 32)
			start_btn.add_theme_font_size_override("font_size", 12)
			start_btn.pressed.connect(func():
				_close_modal()
				_start_new_game_sequence()
			)
			hb.add_child(start_btn)

## 세이브 슬롯 삭제 확인 팝업 (Confirm Modal)
func _open_confirm_delete_modal(slot_idx: int, slot_title: String) -> void:
	_open_modal("실록 기록 영구 파기")

	var warn_icon := Label.new()
	warn_icon.text = "⚠️"
	warn_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn_icon.add_theme_font_size_override("font_size", 32)
	_modal_body.add_child(warn_icon)

	var msg := Label.new()
	msg.text = "【%s】\n\n진정으로 이 치세 기록을 영구히 파기하시겠습니까?\n파기된 실록은 복구할 수 없사옵니다." % slot_title
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_color_override("font_color", Color("991b1b"))
	msg.add_theme_font_size_override("font_size", 13)
	_modal_body.add_child(msg)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 24)
	_modal_body.add_child(hb)

	var cancel_btn := Button.new()
	cancel_btn.text = "취소 (돌아가기)"
	cancel_btn.custom_minimum_size = Vector2(130, 36)
	cancel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cancel_btn.pressed.connect(func():
		_open_load_modal()
	)
	hb.add_child(cancel_btn)

	var confirm_del_btn := Button.new()
	confirm_del_btn.text = "영구 파기 (삭제)"
	confirm_del_btn.custom_minimum_size = Vector2(130, 36)
	confirm_del_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	confirm_del_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.9))

	var c_sb := StyleBoxFlat.new()
	c_sb.bg_color = Color(0.70, 0.15, 0.15, 1.0)
	c_sb.border_color = Color(0.95, 0.35, 0.35, 1.0)
	c_sb.set_border_width_all(2)
	c_sb.set_corner_radius_all(4)
	confirm_del_btn.add_theme_stylebox_override("normal", c_sb)

	confirm_del_btn.pressed.connect(func():
		SaveSystem.delete_save(slot_idx)
		if audio_sys: audio_sys.play("coin")
		_open_toast("선택하신 실록 기록이 영구히 파기되었습니다.")
		_open_load_modal()
	)
	hb.add_child(confirm_del_btn)

func _open_guide_modal() -> void:
	_open_modal("국정 치세 도움말")

	var sections: Array[Dictionary] = [
		{
			"title": "1. 기본 조작 및 시점",
			"body": "• 화면 이동: 오른쪽 단추를 누른 채 끌기 또는 W·A·S·D 또는 화살표 글쇠\n• 확대 배율: 가운데 바퀴를 굴려 확대·축소\n• 시점: 남동쪽에서 북서쪽을 바라보는 고정된 비스듬한 시점 (위편 팔달산, 아래편 창룡문·연무대)\n• 실행 취소: 최근 배치한 도로/건설 취소 [Z] 키"
		},
		{
			"title": "2. 화성 축성과 7대 어명 교지",
			"body": "• 화성행궁(관아) 건립을 시작으로 삼남대로, 성문, 저잣거리, 서장대, 봉돈, 성곽 축조까지 7단계 국책 과제를 완수하십시오.\n• 완공된 시설은 도시의 방재율과 국방력, 왕권을 드높입니다."
		},
		{
			"title": "3. 둔전 개간과 삼남 물류 경제",
			"body": "• 성 밖 외곽의 둔전(농지)에서 생산된 곡식은 [둔전 ↔ 도로 ↔ 성문 ↔ 성내] 직통 연결 시 국고 식량으로 환수됩니다.\n• 저수지(만석거)와 석축제방, 관개 수로를 완공하면 농업 생산량이 대폭 증폭됩니다.\n• 식량이 부족할 때는 삼남로 교역 창에서 금화를 지출하여 환곡(곡식 매입)을 시행하십시오."
		},
		{
			"title": "4. 호조 탕평 조세와 인재 등용",
			"body": "• 결작세(농업), 시전세(상업), 군포세(국방) 3대 세율을 적정선(7%)으로 유지하여 백성의 민심을 수습하십시오.\n• 다산 정약용(거중기 공기 35% 단축), 번암 채제공(공사비 25% 절감), 야뇌 백동수(도적 침략 100% 차단) 등 실학 인재를 적재적소에 등용하십시오."
		}
	]

	for sec: Dictionary in sections:
		var st := Label.new()
		st.text = sec["title"]
		st.add_theme_color_override("font_color", Color("991b1b"))
		st.add_theme_font_size_override("font_size", 14)
		_modal_body.add_child(st)

		var sb := Label.new()
		sb.text = sec["body"]
		sb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sb.add_theme_color_override("font_color", Color("1c1917"))
		_modal_body.add_child(sb)

		var div := HSeparator.new()
		_modal_body.add_child(div)

func _open_chronicles_modal() -> void:
	# PORT-TRACE [역사 사전 퍼즐 도감]: 텍스트 목록 대신 3개의 직소 퍼즐판(인물·건축물·생활상)으로 연다
	var enc := HistoryEncyclopediaLayer.new()
	enc.audio_sys = audio_sys
	add_child(enc)

func _open_settings_modal() -> void:
	_open_modal("화성성역 환경 설정")

	var desc := Label.new()
	desc.text = "치세 화면, 음향 환경 및 각종 알림/알림창 여부를 조율합니다."
	desc.add_theme_color_override("font_color", Color("1c1917"))
	desc.add_theme_font_size_override("font_size", 13)
	_modal_body.add_child(desc)

	GameSettings.build_unified_settings_cards(_modal_body, Callable(), Callable(self, "_rebuild_settings_modal"))

func _rebuild_settings_modal() -> void:
	if not _modal_overlay.visible:
		return
	for ch in _modal_body.get_children():
		ch.queue_free()
	var desc := Label.new()
	desc.text = "치세 화면, 음향 환경 및 각종 알림/알림창 여부를 조율합니다."
	desc.add_theme_color_override("font_color", Color("1c1917"))
	desc.add_theme_font_size_override("font_size", 13)
	_modal_body.add_child(desc)
	GameSettings.build_unified_settings_cards(_modal_body, Callable(), Callable(self, "_rebuild_settings_modal"))

func _open_credits_modal() -> void:
	_open_modal("작품 정보 및 기획")
	var text := Label.new()
	text.text = "《화성성역 1794: 정조의 24년》\n\n조선 제22대 국왕 정조의 수원화성 축성 대역사와 탕평책을 다룬 2.5D 역사 고을 경영 놀이입니다.\n\n• 기획 및 개발: 호치민시한국국제학교 교사 강지욱\n• 만든 도구: 고도(Godot) 4 — 누리집과 컴퓨터용\n• 소리와 그림: 조선 왕실 의궤 및 수원화성 성역 사료 고증"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_color_override("font_color", Color("1c1917"))
	_modal_body.add_child(text)

func _open_quit_modal() -> void:
	_open_modal("치세 종료")

	var msg := Label.new()
	msg.text = "진정으로 화성 성역의 치세를 멈추고 궁궐을 떠나시겠습니까?"
	msg.add_theme_color_override("font_color", Color("1c1917"))
	_modal_body.add_child(msg)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 20)
	_modal_body.add_child(hb)

	var cancel_btn := Button.new()
	cancel_btn.text = "통치 계속하기"
	cancel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cancel_btn.pressed.connect(_close_modal)
	hb.add_child(cancel_btn)

	var quit_btn := Button.new()
	quit_btn.text = "끝내기"
	quit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	quit_btn.pressed.connect(func():
		get_tree().quit()
	)
	hb.add_child(quit_btn)

func _open_toast(msg: String) -> void:
	# 간단한 중앙 알림 토스트
	var t_lbl := Label.new()
	t_lbl.text = msg
	t_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	t_lbl.offset_top = -60.0
	t_lbl.offset_bottom = -30.0
	t_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	root_control.add_child(t_lbl)
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(t_lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(t_lbl.queue_free)
