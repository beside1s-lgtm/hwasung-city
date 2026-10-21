extends RefCounted
class_name GoodsArt
## PORT-TRACE [물품 그림]: 공방 도구·짐·장터 물건 그림(assets/sprites/goods/<id>.png, tools/art_ingest.py가 art_inbox/goods에서 만듦).
## 그림이 있으면 바닥 가운데를 p에 맞춰 그리고 true, 없으면 false → 부르는 쪽이 예전 코드 그림을 그린다.
## 크기: 캔버스(24~32px)를 K배 — 사람(키 약 22px) 곁에 놓이는 물건 크기.

const K := 0.46
const DIR := "res://assets/sprites/goods/%s.png"
static var _cache := {}

## 가게 업종 → 판매대에 놓일 물건
const TRADE_GOODS := {
	"fish": "dried_fish", "jeotgal": "fish_basket", "salt": "salt_sack", "rice": "rice_sack", "veg": "fruit_basket",
	"fruit": "fruit_basket", "silk": "silk_bolt", "cotton": "silk_bolt", "myeonju": "silk_bolt", "ramie": "silk_bolt",
	"yugi": "brassware", "brass": "brassware", "bangmul": "brassware", "herb": "herb_pack", "onggi": "onggi",
	"pottery": "onggi", "gat": "gat", "shoe": "straw_shoes", "jumak": "makgeolli", "gukbap": "makgeolli",
	"tteok": "tteok", "book": "bundle", "gaekju": "crate", "lumber": "log_bundle", "firewood": "log_bundle",
}

static func tex(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var t: Texture2D = null
	var path := DIR % id
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	elif FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			t = ImageTexture.create_from_image(img)
	_cache[id] = t
	return t

static func has(id: String) -> bool:
	return tex(id) != null

static func draw(ci: CanvasItem, p: Vector2, id: String, scale: float = 1.0, flip: bool = false) -> bool:
	var t := tex(id)
	if t == null:
		return false
	var k := K * scale
	var w := float(t.get_width()) * k
	var h := float(t.get_height()) * k
	var r := Rect2(p.x - w * 0.5, p.y - h, w, h)
	if flip:
		r = Rect2(r.position.x + w, r.position.y, -w, h)
	ci.draw_texture_rect(t, r, false)
	return true
