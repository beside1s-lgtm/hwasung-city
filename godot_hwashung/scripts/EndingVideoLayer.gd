extends CanvasLayer
class_name EndingVideoLayer

## [화성성역 12대 멀티 엔딩 시네마틱 영상 재생 레이어]
## 각 엔딩 결과에 부합하는 시네마틱 영상을 16:9 레터박스 비율로 재생하며,
## 스페이스, ESC, 엔터, 마우스 클릭으로 언제든 건너뛸 수 있습니다.
## 재생 종료 시 페이드아웃 트윈과 함께 video_finished 시그널을 발화하여
## 엔딩 실록 결산 팝업(EndingPopup)으로 매끄럽게 핸드오버합니다.

signal video_finished

var root_control: Control
var video_player: VideoStreamPlayer
var bg_rect: ColorRect
var skip_btn: Button
var aspect_container: AspectRatioContainer
var title_badge: PanelContainer
var title_label: Label
var subtitle_label: Label
var _is_finishing: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 145
	_setup_ui()

func _setup_ui() -> void:
	if root_control != null:
		return
	root_control = Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	# 1. 암전 배경
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
	video_player.finished.connect(_on_video_finished)

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

	skip_btn.pressed.connect(_finish_video)
	root_control.add_child(skip_btn)

	# 5. 좌측 상단 엔딩 타이틀 뱃지 (초반 4초간 은은하게 표시 후 페이드아웃)
	title_badge = PanelContainer.new()
	title_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title_badge.offset_left = 30.0
	title_badge.offset_top = 24.0
	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = Color(0.05, 0.05, 0.08, 0.75)
	badge_sb.border_color = Color(0.85, 0.70, 0.35, 0.8)
	badge_sb.set_border_width_all(1)
	badge_sb.set_corner_radius_all(4)
	badge_sb.set_content_margin_all(10)
	title_badge.add_theme_stylebox_override("panel", badge_sb)

	var vbox := VBoxContainer.new()
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.98, 0.88, 0.55))
	vbox.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.add_theme_font_size_override("font_size", 11)
	subtitle_label.add_theme_color_override("font_color", Color(0.80, 0.80, 0.85))
	vbox.add_child(subtitle_label)

	title_badge.add_child(vbox)
	root_control.add_child(title_badge)
	title_badge.visible = false

## 엔딩 비디오 재생 실행
func play_video(video_path: String, title_text: String = "", subtitle_text: String = "") -> bool:
	if not FileAccess.file_exists(video_path) and not ResourceLoader.exists(video_path):
		print_debug("[EndingVideoLayer] 비디오 에셋 파일이 존재하지 않음: %s" % video_path)
		call_deferred("_finish_video")
		return false

	# 헤드리스(CLI 테스트) 모드에서는 비디오 드라이버가 없어 영상 재생이 불가하므로 즉시 팝업 오픈으로 전환
	if DisplayServer.get_name() == "headless":
		call_deferred("_finish_video")
		return false

	var stream: VideoStreamTheora = load(video_path) as VideoStreamTheora
	if stream == null:
		print_debug("[EndingVideoLayer] VideoStreamTheora 변환 실패: %s" % video_path)
		call_deferred("_finish_video")
		return false

	if root_control == null or video_player == null:
		_setup_ui()

	video_player.stream = stream

	if title_text != "":
		title_label.text = title_text
		subtitle_label.text = subtitle_text
		title_badge.visible = true

		var badge_tween := create_tween()
		badge_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		badge_tween.tween_interval(4.0)
		badge_tween.tween_property(title_badge, "modulate:a", 0.0, 1.0)
		badge_tween.tween_callback(func(): title_badge.visible = false)

	# 페이드인 연출 및 비디오 시작
	root_control.modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(root_control, "modulate:a", 1.0, 0.4)
	tween.tween_callback(func():
		video_player.play()
	)
	return true

func _unhandled_input(event: InputEvent) -> void:
	if _is_finishing:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER]:
			get_viewport().set_input_as_handled()
			_finish_video()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_finish_video()

func _on_video_finished() -> void:
	_finish_video()

func _finish_video() -> void:
	if _is_finishing:
		return
	_is_finishing = true

	if skip_btn:
		skip_btn.visible = false
	if title_badge:
		title_badge.visible = false

	# 단절감 방지를 위해 마지막 프레임 일시정지 고정
	if video_player and video_player.is_playing():
		video_player.paused = true

	# 0.6초 크로스페이드 트윈
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if root_control:
		tween.tween_property(root_control, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func():
		if video_player:
			video_player.stop()
		emit_signal("video_finished")
		queue_free()
	)
