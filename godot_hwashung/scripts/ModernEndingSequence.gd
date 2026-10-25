extends CanvasLayer
class_name ModernEndingSequence

## 1945년 근대화 본 엔딩 연출: 지금까지 가꾼 도시 화면을 찍어 천천히 다가가다가,
## 현대 수원화성 전경 그림으로 서서히 바뀐다(크로스페이드 + 자막). 끝나면 엔딩 팝업으로 넘어간다.
## 현대 전경 그림은 엔딩마다 다르다(사용자가 직접 만들어 넣음):
##   글로벌 선진국 도약 → res://assets/illustrations/modern_suwon_global_advanced.png
##   중진국의 늪       → res://assets/illustrations/modern_suwon_middle_trap.png
##   후진국화          → res://assets/illustrations/modern_suwon_underdeveloped.png
## 엔딩 그림이 없으면 공용 그림(modern_suwon_hwaseong.png), 그것도 없으면 어둡게 사라지며 자막만 보여 준다.

const MODERN_IMAGE := "res://assets/illustrations/modern_suwon_hwaseong.png"
const ENDING_IMAGES := {
	"GLOBAL_ADVANCED": "res://assets/illustrations/modern_suwon_global_advanced.png",
	"MIDDLE_TRAP": "res://assets/illustrations/modern_suwon_middle_trap.png",
	"UNDERDEVELOPED": "res://assets/illustrations/modern_suwon_underdeveloped.png",
}
const ENDING_LINES := {
	"GLOBAL_ADVANCED": "그리고 오늘, 수원 화성은 세계유산으로 남아 세계적인 도시와 함께 숨 쉽니다.",
	"MIDDLE_TRAP": "그리고 오늘, 수원은 성장의 문턱에서 멈춘 채 옛 성곽과 함께 다음 도약을 기다립니다.",
	"UNDERDEVELOPED": "그리고 오늘, 부서진 성곽 너머로 가난한 도시가 지난 영광을 기억합니다.",
}
const ZOOM_TIME := 9.0
const FADE_START := 3.0
const FADE_TIME := 4.0
const HOLD_TIME := 3.0

var _done: Callable
var _key: String = ""

static func play(parent: Node, caption: String, on_done: Callable, ending_key: String = "") -> void:
	var seq = load("res://scripts/ModernEndingSequence.gd").new() # 자기 class_name 직접 참조 대신 경로로 만든다(전역 클래스 캐시가 늦게 갱신될 때 대비)
	seq.layer = 99
	seq._done = on_done
	seq._key = ending_key
	parent.add_child(seq)
	seq._start(caption)

func _start(caption: String) -> void:
	var tm: TimeManager = ModernizationManager.instance.time_manager if ModernizationManager.instance else null
	if tm:
		tm.set_speed(TimeManager.SpeedMode.PAUSE)
	if DisplayServer.get_name() == "headless":
		_finish()
		return
	# 1) 지금 화면(플레이어의 도시)을 찍는다
	var shot := get_viewport().get_texture().get_image()
	var city_tex := ImageTexture.create_from_image(shot)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color.BLACK
	root.add_child(bg)
	var city := _full_rect(city_tex)
	root.add_child(city)
	var modern: TextureRect = null
	var img_path := String(ENDING_IMAGES.get(_key, ""))
	if img_path == "" or not ResourceLoader.exists(img_path):
		img_path = MODERN_IMAGE
	if ResourceLoader.exists(img_path):
		modern = _full_rect(load(img_path) as Texture2D)
		modern.modulate.a = 0.0
		root.add_child(modern)
	var lbl := Label.new()
	lbl.text = caption
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	lbl.offset_top = -110
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color("fef3c7"))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.modulate.a = 0.0
	root.add_child(lbl)
	# 2) 천천히 다가가며(확대) 현대 수원화성으로 겹쳐 바뀐다
	var size := get_viewport().get_visible_rect().size
	city.pivot_offset = size / 2.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(city, "scale", Vector2(1.18, 1.18), ZOOM_TIME).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lbl, "modulate:a", 1.0, 1.5)
	if modern != null:
		modern.pivot_offset = size / 2.0
		modern.scale = Vector2(1.08, 1.08)
		tw.tween_property(modern, "modulate:a", 1.0, FADE_TIME).set_delay(FADE_START)
		tw.tween_property(modern, "scale", Vector2(1.0, 1.0), ZOOM_TIME - FADE_START).set_delay(FADE_START)
	else:
		tw.tween_property(city, "modulate", Color(0.15, 0.15, 0.15), FADE_TIME).set_delay(FADE_START)
	tw.chain().tween_interval(HOLD_TIME)
	tw.chain().tween_callback(func():
		lbl.text = String(ENDING_LINES.get(_key, "그리고 오늘, 수원 화성은 세계유산으로 남아 도시와 함께 숨 쉽니다."))
	)
	tw.chain().tween_interval(HOLD_TIME)
	tw.chain().tween_callback(_finish)

func _full_rect(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _finish() -> void:
	queue_free()
	if _done.is_valid():
		_done.call()
