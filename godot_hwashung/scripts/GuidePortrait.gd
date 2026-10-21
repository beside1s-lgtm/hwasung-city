extends Control
class_name GuidePortrait

## PORT-TRACE [튜토리얼·길잡이]: 길잡이 "김판관"(수원부 판관) 도트 초상.
## 김판관 추천 정확도(학문력·민심·왕권)에 따라 세 모습으로 바뀐다 — 70 미만 어벙 / 70 이상 착실 / 90 이상 엘리트.
## PortraitArt가 코드로 그린 80x80 도트를 NEAREST로 2배 키워 보이고, 말할 땐 입을 오물거리고 가끔 눈을 깜빡인다.

var talking := false
var court: CourtSystem = null
var _t := 0.0
var _tier := 0

func _ready() -> void:
	custom_minimum_size = Vector2(160, 160)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_refresh_tier()

func _refresh_tier() -> void:
	var acc := 0.0
	if court != null:
		acc = court.recommend_accuracy()
	_tier = PortraitArt.tier_for_accuracy(acc)
	PortraitArt.kim_tier = _tier

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	if int(_t * 2.0) != int((_t - delta) * 2.0):
		_refresh_tier()
	queue_redraw()

func _draw() -> void:
	var blink := fmod(_t, 3.4) < 0.13
	var talk := talking and fmod(_t * 7.0, 2.0) < 1.0
	var tex := PortraitArt.kim(_tier, talk, blink)
	draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
