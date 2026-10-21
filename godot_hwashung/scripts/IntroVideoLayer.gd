extends CanvasLayer
class_name IntroVideoLayer

## [화성성역 인트로 영상 재생 레이어]
## 정조 대왕과 화성성역 오프닝 시네마틱을 전체화면 16:9 비율로 재생하며,
## 스페이스, ESC, 마우스 클릭으로 건너뛸 수 있습니다.

signal intro_finished

var root_control: Control
var video_player: VideoStreamPlayer
var bg_rect: ColorRect
var skip_btn: Button
var aspect_container: AspectRatioContainer
var _is_finishing: bool = false

func _ready() -> void:
	layer = 120 # 최상위 레이어에 표시

	# 0. 전체 화면 루트 컨트롤 (페이드인/페이드아웃 알파 트윈 담당)
	root_control = Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	# 1. 칠흑 같은 암전 배경
	bg_rect = ColorRect.new()
	bg_rect.color = Color(0.02, 0.02, 0.03, 1.0)
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(bg_rect)

	# 2. 16:9 영화적 비율 유지 컨테이너
	aspect_container = AspectRatioContainer.new()
	aspect_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	aspect_container.ratio = 16.0 / 9.0
	aspect_container.stretch_mode = AspectRatioContainer.STRETCH_FIT
	root_control.add_child(aspect_container)

	# 3. 비디오 스트림 플레이어
	video_player = VideoStreamPlayer.new()
	video_player.expand = true
	video_player.loop = false
	video_player.bus = "Master"
	aspect_container.add_child(video_player)

	# 비디오 스트림 로드 (Theora OGV 포맷)
	var stream: VideoStreamTheora = load("res://assets/intro_video.ogv") as VideoStreamTheora
	if stream:
		video_player.stream = stream
		video_player.finished.connect(_on_video_finished)
	else:
		# 비디오 로드 실패 시 즉시 종료
		call_deferred("_finish_intro")
		return

	# 4. 우측 상단 건너뛰기 버튼
	skip_btn = Button.new()
	skip_btn.text = "건너뛰기  [Esc · 띄어쓰기 글쇠]"
	skip_btn.custom_minimum_size = Vector2(160, 36)
	skip_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_btn.offset_left = -180.0
	skip_btn.offset_top = 20.0
	skip_btn.offset_right = -20.0
	skip_btn.offset_bottom = 56.0
	skip_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	skip_btn.add_theme_font_size_override("font_size", 12)

	var sb_norm := StyleBoxFlat.new()
	sb_norm.bg_color = Color(0.12, 0.08, 0.06, 0.85)
	sb_norm.border_color = Color(0.65, 0.48, 0.25, 0.9)
	sb_norm.set_border_width_all(1)
	sb_norm.set_corner_radius_all(4)
	sb_norm.set_content_margin_all(6)
	skip_btn.add_theme_stylebox_override("normal", sb_norm)

	var sb_hov := sb_norm.duplicate() as StyleBoxFlat
	sb_hov.bg_color = Color(0.25, 0.16, 0.10, 0.95)
	sb_hov.border_color = Color(0.98, 0.85, 0.40, 1.0)
	skip_btn.add_theme_stylebox_override("hover", sb_hov)
	skip_btn.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
	skip_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.55))

	skip_btn.pressed.connect(_finish_intro)
	root_control.add_child(skip_btn)

	# 5. 첫 프레임 페이드인 연출 및 비디오 시작
	root_control.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(root_control, "modulate:a", 1.0, 0.35)
	tween.tween_callback(func():
		video_player.play()
	)

func _unhandled_input(event: InputEvent) -> void:
	if _is_finishing:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER]:
			get_viewport().set_input_as_handled()
			_finish_intro()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_finish_intro()

func _on_video_finished() -> void:
	_finish_intro()

func _finish_intro() -> void:
	if _is_finishing:
		return
	_is_finishing = true

	# 1. 전환 연출 중 건너뛰기 버튼 즉시 숨김
	if skip_btn:
		skip_btn.visible = false

	# 2. 마지막 프레임을 화면에 고정하여 블랙아웃 단절감 원천 방지
	if video_player and video_player.is_playing():
		video_player.paused = true

	# 3. 0.8초 크로스페이드 트윈 (상위 레이어가 서서히 투명해지며 하위 타이틀 화면과 자연스럽게 오버랩)
	var tween := create_tween()
	if root_control:
		tween.tween_property(root_control, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func():
		if video_player:
			video_player.stop()
		emit_signal("intro_finished")
		queue_free()
	)
