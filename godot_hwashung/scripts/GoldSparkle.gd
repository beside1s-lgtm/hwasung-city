extends Control
class_name GoldSparkle
## PORT-TRACE [퍼즐 완성 축하 이펙트(gold_sparkle_fx)]: 황금빛 불꽃 입자. 한 번 터뜨리기(burst)와 일정 시간 폭죽(fireworks)을 지원한다.
## 입자는 가볍게 직접 그려(원 + 네 갈래 별) 저사양에서도 부담이 적다. 입자가 모두 사라지면 처리를 멈춘다.

var _ps: Array = [] # {p, v, life, max, col, size, star}
var _fire_left := 0.0
var _fire_acc := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)

## origin(이 컨트롤 좌표)에서 사방으로 터뜨린다
func burst(origin: Vector2, count: int = 90, speed: float = 360.0, hue_shift: float = 0.0) -> void:
	for i in range(count):
		var ang := randf() * TAU
		var sp := speed * (0.25 + randf() * 0.75)
		var base := Color.from_hsv(0.12 + hue_shift + randf() * 0.04, 0.55 + randf() * 0.4, 1.0)
		_ps.append({
			"p": origin, "v": Vector2(cos(ang), sin(ang)) * sp, "life": 1.0 + randf() * 0.9, "max": 1.9,
			"col": base, "size": 2.0 + randf() * 3.2, "star": randf() < 0.3,
		})
	set_process(true)

## 위에서 아래로 흩날리는 금빛 가루(잔잔한 축하)
func shower(count: int = 60) -> void:
	for i in range(count):
		_ps.append({
			"p": Vector2(randf() * size.x, -10.0 - randf() * 120.0), "v": Vector2((randf() - 0.5) * 60.0, 90.0 + randf() * 140.0),
			"life": 2.0 + randf() * 1.6, "max": 3.6, "col": Color.from_hsv(0.11 + randf() * 0.05, 0.6, 1.0), "size": 2.0 + randf() * 2.4, "star": randf() < 0.4,
		})
	set_process(true)

## 시간(초) 동안 화면 곳곳에서 폭죽
func fireworks(seconds: float = 3.0) -> void:
	_fire_left = seconds
	set_process(true)

func _process(delta: float) -> void:
	if _fire_left > 0.0:
		_fire_left -= delta
		_fire_acc -= delta
		if _fire_acc <= 0.0:
			_fire_acc = 0.28
			burst(Vector2(size.x * (0.15 + randf() * 0.7), size.y * (0.12 + randf() * 0.45)), 70, 300.0, randf() * 0.5 - 0.1)
	var keep: Array = []
	for pt: Dictionary in _ps:
		pt["life"] = float(pt["life"]) - delta
		if float(pt["life"]) > 0.0:
			var v: Vector2 = pt["v"]
			v.y += 260.0 * delta # 중력
			v *= 1.0 - 0.9 * delta # 공기 저항
			pt["v"] = v
			pt["p"] = (pt["p"] as Vector2) + v * delta
			keep.append(pt)
	_ps = keep
	queue_redraw()
	if _ps.is_empty() and _fire_left <= 0.0:
		set_process(false)

func _draw() -> void:
	for pt: Dictionary in _ps:
		var a := clampf(float(pt["life"]) / float(pt["max"]) * 1.6, 0.0, 1.0)
		var col: Color = pt["col"]
		col.a = a
		var p: Vector2 = pt["p"]
		var sz: float = pt["size"]
		draw_circle(p, sz, col)
		if bool(pt["star"]):
			var r := sz * 2.6
			draw_line(p - Vector2(r, 0), p + Vector2(r, 0), col, 1.2)
			draw_line(p - Vector2(0, r), p + Vector2(0, r), col, 1.2)
