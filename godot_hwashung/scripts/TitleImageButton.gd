extends Control
class_name TitleImageButton

## 타이틀 그림 위에 얹는 투명 버튼. 그림(영상 마지막 장면) 한 장에서 버튼 부분을 오려 상태마다 효과를 준다 —
##   · 마우스를 올리면: 밝아지고 금빛 테두리·후광이 켜지며 빛줄기가 한 번 스친다
##   · 누르고 있으면: 버튼이 안으로 들어가듯 작아지고 어두워지며 안쪽 그림자가 생긴다
##   · 떼면: 눌림이 풀린 뒤 pressed 신호를 보낸다
## 새 그림 없이 코드로 만든 효과다. round=true면 동그란 아이콘 버튼(원형 마스크 + 둥근 후광).

signal pressed
signal hovered

var round_icon := false
var _base: ImageTexture
var _bright: ImageTexture
var _dark: ImageTexture
var _h := 0.0        # 올림 정도 0~1(부드럽게 따라간다)
var _p := 0.0        # 눌림 정도 0~1
var _sweep := 1.0    # 빛줄기 위치(0~1, 1이면 끝)
var _hover_in := false
var _holding := false

## img = 타이틀 전체 그림, region = 그 그림에서 이 버튼의 픽셀 영역
func setup(img: Image, region: Rect2i, as_round: bool = false) -> void:
	round_icon = as_round
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = false
	var crop := img.get_region(region)
	crop.convert(Image.FORMAT_RGBA8)
	var bright := Image.create(crop.get_width(), crop.get_height(), false, Image.FORMAT_RGBA8)
	var dark := Image.create(crop.get_width(), crop.get_height(), false, Image.FORMAT_RGBA8)
	var w := crop.get_width()
	var h := crop.get_height()
	for y in range(h):
		for x in range(w):
			var c := crop.get_pixel(x, y)
			var a := 1.0
			if round_icon:
				var dx := (float(x) + 0.5 - float(w) * 0.5) / (float(w) * 0.5)
				var dy := (float(y) + 0.5 - float(h) * 0.5) / (float(h) * 0.5)
				a = clampf((1.0 - sqrt(dx * dx + dy * dy)) * 7.0, 0.0, 1.0)
			crop.set_pixel(x, y, Color(c.r, c.g, c.b, a))
			bright.set_pixel(x, y, Color(minf(1.0, c.r * 1.3 + 0.07), minf(1.0, c.g * 1.26 + 0.045), minf(1.0, c.b * 1.12 + 0.0), a))
			dark.set_pixel(x, y, Color(c.r * 0.72, c.g * 0.7, c.b * 0.68, a))
	_base = ImageTexture.create_from_image(crop)
	_bright = ImageTexture.create_from_image(bright)
	_dark = ImageTexture.create_from_image(dark)
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	set_process(false)

func _on_enter() -> void:
	_hover_in = true
	_sweep = 0.0
	emit_signal("hovered")
	set_process(true)

func _on_exit() -> void:
	_hover_in = false
	_holding = false
	set_process(true)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (ev as InputEventMouseButton).pressed:
			_holding = true
			set_process(true)
			accept_event()
		else:
			var fire := _holding and _hover_in
			_holding = false
			set_process(true)
			if fire:
				# 눌림이 눈에 보이도록 잠깐 있다가 동작을 일으킨다
				get_tree().create_timer(0.11).timeout.connect(func():
					if is_inside_tree():
						emit_signal("pressed"))
			accept_event()

func _process(delta: float) -> void:
	var th := 1.0 if _hover_in else 0.0
	var tp := 1.0 if _holding else 0.0
	_h = move_toward(_h, th, delta * 9.0)
	_p = move_toward(_p, tp, delta * 16.0)
	if _hover_in and _sweep < 1.0:
		_sweep = minf(1.0, _sweep + delta * 1.6)
	queue_redraw()
	if _h == th and _p == tp and (_sweep >= 1.0 or not _hover_in):
		set_process(false)

func _draw() -> void:
	if _base == null or (_h <= 0.001 and _p <= 0.001):
		return
	var r := Rect2(Vector2.ZERO, size)
	var center := size * 0.5
	var press_scale := 1.0 - 0.045 * _p
	var hover_scale := 1.0 + (0.045 if round_icon else 0.0) * _h
	var s := press_scale * hover_scale
	var off := Vector2(0.0, 3.0 * _p)
	var dr := Rect2(center - size * 0.5 * s + off, size * s)
	if round_icon:
		# 동그란 아이콘: 둥근 후광 + 올리면 밝게, 누르면 작아지며 어둡게
		var rad := minf(size.x, size.y) * 0.5
		for k in range(3):
			draw_arc(center, rad * (1.0 + 0.1 * float(k + 1)) * hover_scale, 0.0, TAU, 40, Color(1.0, 0.85, 0.35, 0.28 * _h * (1.0 - float(k) * 0.3)), 2.0)
		draw_texture_rect(_base, dr, false)
		draw_texture_rect(_bright, dr, false, Color(1, 1, 1, _h * (1.0 - _p)))
		draw_texture_rect(_dark, dr, false, Color(1, 1, 1, _p))
		draw_arc(center + off, rad * s * 0.98, 0.0, TAU, 40, Color(1.0, 0.88, 0.45, 0.85 * _h), 1.6)
		return
	# 네모 버튼: 눌릴 때 뒤에 깊게 파인 홈이 드러난다
	if _p > 0.0:
		draw_rect(r.grow(1.0), Color(0.04, 0.025, 0.015, 0.92 * _p))
	# 후광(올림)
	for k in range(4):
		var g := float(k + 1) * 3.0
		draw_rect(r.grow(g), Color(1.0, 0.82, 0.3, 0.16 * _h * (1.0 - float(k) * 0.22) * (1.0 - _p)), false, 2.0)
	draw_texture_rect(_base, dr, false)
	draw_texture_rect(_bright, dr, false, Color(1, 1, 1, _h * (1.0 - _p)))
	draw_texture_rect(_dark, dr, false, Color(1, 1, 1, _p))
	# 빛줄기(올릴 때 한 번 가로질러 지나간다)
	if _sweep < 1.0 and _p < 0.5:
		var bx := lerpf(-0.25, 1.25, _sweep) * size.x
		var bw := size.x * 0.16
		var poly := PackedVector2Array([Vector2(bx, 0), Vector2(bx + bw, 0), Vector2(bx + bw - size.y * 0.25, size.y), Vector2(bx - size.y * 0.25, size.y)])
		var clipped := _clip_to_rect(poly, r)
		if clipped.size() >= 3:
			draw_colored_polygon(clipped, Color(1.0, 0.97, 0.8, 0.2))
	# 테두리(올림은 금빛, 누름은 어두운 금)
	var bc := Color(1.0, 0.86, 0.38, 0.95 * _h).lerp(Color(0.6, 0.45, 0.15, 0.9), _p)
	draw_rect(dr.grow(-1.0), bc, false, 2.0)
	# 눌렸을 때 안쪽 그림자(위·왼쪽은 어둡게, 아래·오른쪽은 살짝 밝게)
	if _p > 0.0:
		for k in range(5):
			var a := 0.34 * _p * (1.0 - float(k) / 5.0)
			draw_rect(Rect2(dr.position.x, dr.position.y + float(k), dr.size.x, 1.0), Color(0, 0, 0, a))
			draw_rect(Rect2(dr.position.x + float(k), dr.position.y, 1.0, dr.size.y), Color(0, 0, 0, a * 0.8))
			draw_rect(Rect2(dr.position.x, dr.end.y - 1.0 - float(k), dr.size.x, 1.0), Color(1, 0.95, 0.8, a * 0.35))

## 빛줄기 평행사변형을 버튼 사각형 안으로 자른다
func _clip_to_rect(poly: PackedVector2Array, r: Rect2) -> PackedVector2Array:
	var box := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var res: Array[PackedVector2Array] = Geometry2D.intersect_polygons(poly, box)
	return res[0] if not res.is_empty() else PackedVector2Array()
