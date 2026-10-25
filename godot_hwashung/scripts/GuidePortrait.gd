extends Control
class_name GuidePortrait

## PORT-TRACE [튜토리얼·길잡이]: 길잡이 "김판관"(수원부 판관) 도트 초상.
## 김판관 추천 정확도(학문력·민심·왕권)에 따라 세 모습으로 바뀐다 — 70 미만 어벙 / 70 이상 착실 / 90 이상 엘리트.
## PNG 파일(kim_pangwan_tier0/1/2.png)이 존재하면 우선 사용하고, 없으면 PortraitArt 코드 생성으로 폴백한다.
## PNG 사용 시 말하기/눈깜빡임 애니메이션은 생략된다.

var talking := false
var court: CourtSystem = null
var _t := 0.0
var _tier := 0

const _PNG_BASE: String = "res://assets/sprites/npcs/named/"
var _png_textures: Array[Texture2D] = []
var _use_png: bool = false
## 대통령제(1897~): 비서실장 김종수 양장 초상. kim_secretary_tier0/1/2.png 세 장이 있으면 그것을,
## kim_secretary.png 한 장만 있으면 세 모습 모두 그것을 쓴다. 없으면 김판관 초상 그대로.
var _modern_textures: Array[Texture2D] = []
var _modern_checked := false

static func is_secretary() -> bool:
	return ModernPoliticsManager.instance != null and ModernizationManager.is_active() and ModernPoliticsManager.instance.system != ModernPoliticsManager.SYS_MONARCHY

func _load_modern_textures() -> void:
	_modern_checked = true
	_modern_textures.clear()
	for i: int in range(3):
		var path: String = _PNG_BASE + "kim_secretary_tier%d.png" % i
		if ResourceLoader.exists(path, "Texture2D"):
			_modern_textures.append(load(path) as Texture2D)
	if _modern_textures.size() != 3:
		_modern_textures.clear()
		var one: String = _PNG_BASE + "kim_secretary.png"
		if ResourceLoader.exists(one, "Texture2D"):
			var t: Texture2D = load(one) as Texture2D
			_modern_textures = [t, t, t]

func _ready() -> void:
	custom_minimum_size = Vector2(160, 160)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_png_textures()
	_refresh_tier()

## PNG 파일 3장(tier0/1/2)을 로드한다. 한 장이라도 없으면 코드 생성 폴백 사용.
func _load_png_textures() -> void:
	_png_textures.clear()
	var all_ok: bool = true
	for i: int in range(3):
		var path: String = _PNG_BASE + "kim_pangwan_tier%d.png" % i
		if ResourceLoader.exists(path, "Texture2D"):
			var tex: Texture2D = load(path) as Texture2D
			if tex != null:
				_png_textures.append(tex)
			else:
				all_ok = false
				break
		else:
			all_ok = false
			break
	_use_png = all_ok and _png_textures.size() == 3

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
	if is_secretary():
		if not _modern_checked:
			_load_modern_textures()
		if _modern_textures.size() == 3:
			draw_texture_rect(_modern_textures[clampi(_tier, 0, 2)], Rect2(Vector2.ZERO, size), false)
			return
	if _use_png:
		var tier_idx: int = clampi(_tier, 0, 2)
		draw_texture_rect(_png_textures[tier_idx], Rect2(Vector2.ZERO, size), false)
	else:
		var blink := fmod(_t, 3.4) < 0.13
		var talk := talking and fmod(_t * 7.0, 2.0) < 1.0
		var tex := PortraitArt.kim(_tier, talk, blink)
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
