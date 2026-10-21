extends RefCounted
class_name PortraitScenes

## 살피기 팝업의 건물·시설·풍경 도트 그림(80x80). 하늘·산·땅 배경 위에 기와지붕·석축·누각 따위를 쌓는다.
## 사람이 나오는 놀이·일 장면과 동물은 PortraitFolk / PortraitAnimals 가 맡는다.

const S := 80
const KEYS := ["construction", "house_thatched", "house_tile", "haenggung", "gate", "wall", "fort", "market", "facility", "jongnu", "seojangdae",
	"banghwasuryujeong", "hwahongmun", "hwahong_mun", "namsumun", "namsu_mun", "maehwang_gyo", "maehyang_gyo", "gongsimdon", "bongdon", "poru",
	"yeonmudae", "embankment", "road", "base_jungin", "base_ajeon", "base_artisan", "base_butcher", "seodang", "seowon", "shop_silk", "shop_fish",
	"shop_rice", "shop_smith", "shop_jumak"]

static func has(key: String) -> bool:
	return KEYS.has(key)

# ─────────────────────────────────────────── 배경 조각
static func sky(a: PixelArt, top: Color, bottom: Color, horizon: int = 56) -> void:
	for y in range(a.h):
		var t := clampf(float(y) / float(horizon), 0.0, 1.0)
		for x in range(a.w):
			var thr: float = PixelArt.BAYER[y & 1][x & 1] * 0.08
			a.px(x, y, top.lerp(bottom, clampf(t + thr - 0.04, 0.0, 1.0)))

static func hills(a: PixelArt, base_y: int, amp: float, c: Color, phase: float, freq: float = 0.11) -> void:
	for x in range(a.w):
		var yy := float(base_y) - amp * (0.55 + 0.45 * sin(float(x) * freq + phase)) - amp * 0.3 * sin(float(x) * freq * 2.3 + phase * 1.7)
		for y in range(int(yy), a.h):
			var shade := 0.0
			if y < int(yy) + 2:
				shade = 0.12
			a.px(x, y, PixelArt.shade(c, shade))

static func grass(a: PixelArt, y0: int, c1: Color, c2: Color) -> void:
	for y in range(y0, a.h):
		for x in range(a.w):
			var t := float(y - y0) / maxf(1.0, float(a.h - y0))
			var thr: float = PixelArt.BAYER[y & 1][x & 1] * 0.2
			a.px(x, y, c1.lerp(c2, clampf(t + thr - 0.1, 0.0, 1.0)))
	for k in range(26):
		var gx := (k * 37 + 11) % a.w
		var gy := y0 + 3 + (k * 53) % maxi(1, a.h - y0 - 3)
		a.px(gx, gy, PixelArt.shade(c1, 0.28))
		a.px(gx, gy - 1, PixelArt.shade(c1, 0.18))

static func ground_path(a: PixelArt, y0: int, c: Color) -> void:
	for y in range(y0, a.h):
		for x in range(a.w):
			var thr: float = PixelArt.BAYER[y & 1][x & 1] * 0.12
			a.px(x, y, PixelArt.shade(c, -0.1 * float(y - y0) / float(maxi(1, a.h - y0)) + thr * 0.5))

static func cloud(a: PixelArt, x: int, y: int, s: float = 1.0) -> void:
	for p in [Vector3(0, 0, 5), Vector3(5, -2, 6), Vector3(11, 0, 5), Vector3(6, 2, 7)]:
		a.ell(x + p.x * s, y + p.y * s, p.z * s, p.z * 0.6 * s, Color(1, 1, 1, 0.9))

static func pine(a: PixelArt, x: int, y: int, s: float = 1.0) -> void:
	a.rect(x - 1, y - int(6.0 * s), 2, int(7.0 * s), Color("5a3a22"))
	for k in range(3):
		var w := (9.0 - float(k) * 2.2) * s
		var yy := float(y) - 7.0 * s - float(k) * 5.0 * s
		a.spoly(PackedVector2Array([Vector2(float(x) - w, yy + 5.0 * s), Vector2(float(x), yy - 4.0 * s), Vector2(float(x) + w, yy + 5.0 * s)]), Color("2f6a3a"), 0.18, -0.34)

static func round_tree(a: PixelArt, x: int, y: int, r: float, c: Color) -> void:
	a.rect(x - 1, y - int(r * 0.9), 2, int(r * 1.1), Color("5a3a22"))
	a.ball(float(x), float(y) - r * 1.4, r, r * 0.9, c)

static func willow(a: PixelArt, x: int, y: int) -> void:
	a.rect(x - 1, y - 14, 3, 15, Color("5a4630"))
	a.ball(float(x), float(y) - 17.0, 9.0, 6.0, Color("7aa850"))
	for k in range(7):
		var sx := x - 9 + k * 3
		a.line(sx, y - 14, sx - 1 + (k & 1) * 2, y - 1 - (k % 3) * 2, Color("86b45a") if k % 2 == 0 else Color("6a9a48"))

static func blossom(a: PixelArt, x: int, y: int) -> void:
	a.rect(x - 1, y - 10, 2, 11, Color("4a3424"))
	a.line(x, y - 8, x - 6, y - 14, Color("4a3424"))
	a.line(x, y - 6, x + 6, y - 13, Color("4a3424"))
	for p in [Vector2i(-7, -15), Vector2i(-4, -17), Vector2i(0, -14), Vector2i(6, -14), Vector2i(8, -12), Vector2i(3, -16), Vector2i(-2, -12)]:
		a.ball(float(x + p.x), float(y + p.y), 2.4, 2.4, Color("f4b6c8"))
		a.px(x + p.x - 1, y + p.y - 1, Color("fff0f4"))

static func water(a: PixelArt, x: int, y: int, w: int, h: int, c1: Color = Color("4a90c8"), c2: Color = Color("2a6a9e")) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			var t := float(yy - y) / maxf(1.0, float(h))
			var thr: float = PixelArt.BAYER[yy & 1][xx & 1] * 0.16
			a.px(xx, yy, c1.lerp(c2, clampf(t + thr - 0.08, 0.0, 1.0)))
	for k in range(maxi(2, int(float(w * h) / 70.0))):
		var rx := x + 2 + (k * 29) % maxi(1, w - 6)
		var ry := y + 1 + (k * 17) % maxi(1, h - 2)
		a.line(rx, ry, rx + 3, ry, Color(1, 1, 1, 0.55))

static func flag(a: PixelArt, x: int, y: int, c: Color, h: int = 12) -> void:
	a.line(x, y, x, y + h, Color("5a3a22"))
	a.poly(PackedVector2Array([Vector2(x + 1, y), Vector2(x + 9, y + 2), Vector2(x + 1, y + 6)]), c)

static func smoke(a: PixelArt, x: int, y: int, n: int = 4) -> void:
	for k in range(n):
		a.ball(float(x + (k & 1) * 2 + k), float(y - k * 4), 2.0 + float(k) * 0.7, 2.0 + float(k) * 0.6, Color(0.92, 0.92, 0.92, 0.8 - float(k) * 0.14))

# ─────────────────────────────────────────── 건물 조각
## 기와지붕: 처마가 양끝에서 살짝 들린 팔작 모양
static func tile_roof(a: PixelArt, x0: int, x1: int, yt: int, yb: int, c: Color = Color("3c4650"), ridge: Color = Color("e8e6e0")) -> void:
	var inset := maxi(4, int(float(x1 - x0) / 6.0))
	var poly := PackedVector2Array([Vector2(x0 - 3, yb + 1), Vector2(x0 + 2, yb - 1), Vector2(x0 + inset, yt), Vector2(x1 - inset, yt), Vector2(x1 - 2, yb - 1), Vector2(x1 + 3, yb + 1), Vector2(x1, yb + 3), Vector2(x0, yb + 3)])
	a.spoly(poly, c, 0.14, -0.3)
	# 기왓골
	var n := int(float(x1 - x0) / 3.0)
	for k in range(1, n):
		var fx := float(k) / float(n)
		var tx := lerpf(float(x0 + inset), float(x1 - inset), fx)
		var bx := lerpf(float(x0), float(x1), fx)
		a.line(int(tx), yt + 1, int(bx), yb, PixelArt.shade(c, -0.22))
	a.line(x0 + inset, yt, x1 - inset, yt, ridge, 2)
	a.line(x0 + 1, yb + 2, x1 - 1, yb + 2, Color("1c2228"))
	# 처마 끝 막새
	for k in range(x0 + 2, x1 - 1, 3):
		a.px(k, yb + 3, Color("e8e0cc"))

static func snow_roof(a: PixelArt, x0: int, x1: int, yt: int, yb: int) -> void:
	tile_roof(a, x0, x1, yt, yb, Color("dce6ee"), Color("ffffff"))

static func stone_wall(a: PixelArt, x: int, y: int, w: int, h: int, base: Color = Color("a6a094")) -> void:
	a.srect(x, y, w, h, base)
	var row := 0
	for yy in range(y, y + h, 4):
		a.line(x, yy, x + w - 1, yy, PixelArt.shade(base, -0.28))
		var off := 5 if (row & 1) == 1 else 0
		for xx in range(x + off, x + w, 9):
			a.line(xx, yy, xx, mini(yy + 3, y + h - 1), PixelArt.shade(base, -0.24))
		row += 1
	a.line(x, y, x + w - 1, y, PixelArt.shade(base, 0.25))

static func brick_wall(a: PixelArt, x: int, y: int, w: int, h: int, base: Color = Color("5a5450")) -> void:
	a.srect(x, y, w, h, base)
	for yy in range(y, y + h, 2):
		a.line(x, yy, x + w - 1, yy, PixelArt.shade(base, -0.3))
		var off := 2 if (int(float(yy - y) / 2.0)) % 2 == 1 else 0
		for xx in range(x + off, x + w, 4):
			a.px(xx, yy + 1, PixelArt.shade(base, -0.22))

static func plaster_wall(a: PixelArt, x: int, y: int, w: int, h: int, base: Color = Color("efe8d8")) -> void:
	a.srect(x, y, w, h, base)

static func pillar(a: PixelArt, x: int, y: int, h: int, c: Color = Color("a8342a")) -> void:
	a.rect(x, y, 2, h, c)
	a.rect(x, y, 1, h, PixelArt.shade(c, 0.2))
	a.rect(x + 1, y, 1, h, PixelArt.shade(c, -0.25))

static func lattice(a: PixelArt, x: int, y: int, w: int, h: int, paper: Color = Color("f2e8c8")) -> void:
	a.rect(x, y, w, h, paper)
	for xx in range(x, x + w, 3):
		a.line(xx, y, xx, y + h - 1, Color("7a4a2a"))
	for yy in range(y, y + h, 3):
		a.line(x, yy, x + w - 1, yy, Color("7a4a2a"))
	a.rect(x - 1, y - 1, w + 2, 1, Color("5a3a22"))
	a.rect(x - 1, y + h, w + 2, 1, Color("5a3a22"))

static func door(a: PixelArt, x: int, y: int, w: int, h: int, c: Color = Color("6a3a22")) -> void:
	a.srect(x, y, w, h, c)
	var mid_x := x + int(float(w) / 2.0)
	var mid_y := y + int(float(h) / 2.0)
	a.line(mid_x, y, mid_x, y + h - 1, PixelArt.shade(c, -0.4))
	a.px(mid_x - 2, mid_y, Color("d8b040"))
	a.px(mid_x + 1, mid_y, Color("d8b040"))

static func arch(a: PixelArt, cx: int, y: int, r: int, h: int, fill: Color, rim: Color = Color("c4bdae")) -> void:
	# 반원 홍예 + 아래 직사각
	a.ell(float(cx), float(y), float(r + 2), float(r + 2), rim)
	a.rect(cx - r - 2, y, 2 * r + 4, h, rim)
	a.ell(float(cx), float(y), float(r), float(r), fill)
	a.rect(cx - r, y, 2 * r, h, fill)

## 다락(2층) 지붕 얹은 큰 건물: 석축 기단 + 기둥 + 창호 + 지붕
static func hall(a: PixelArt, x0: int, x1: int, ybase: int, floors: int, roof: Color = Color("3c4650"), wall: Color = Color("efe8d8"), snow: bool = false) -> void:
	var fh := 12
	stone_wall(a, x0 - 2, ybase - 6, x1 - x0 + 4, 7, Color("b8b2a4"))
	var y := ybase - 6
	for fl in range(floors):
		var ytop := y - fh
		plaster_wall(a, x0, ytop, x1 - x0, fh, wall)
		var n := maxi(2, int(float(x1 - x0) / 12.0))
		for k in range(n + 1):
			pillar(a, x0 + int(float(k) * float(x1 - x0 - 2) / float(n)), ytop, fh)
		for k in range(n):
			var wx := x0 + int(float(k) * float(x1 - x0 - 2) / float(n)) + 3
			var ww := int(float(x1 - x0) / float(n)) - 5
			if fl == 0 and k == int(float(n) / 2.0):
				door(a, wx, ytop + 3, ww, fh - 3)
			else:
				lattice(a, wx, ytop + 3, ww, fh - 6)
		var rb := ytop + 1
		var rt := rb - 8
		if snow:
			snow_roof(a, x0 - 5, x1 + 5, rt, rb)
		else:
			tile_roof(a, x0 - 5, x1 + 5, rt, rb, roof)
		# 단청 처마 장식줄
		a.rect(x0 - 3, rb + 3, x1 - x0 + 6, 1, Color("2e8a6a"))
		a.rect(x0 - 3, rb + 4, x1 - x0 + 6, 1, Color("b83a2c"))
		y = rt - 1
		# 위층은 좁게
		x0 += 3
		x1 -= 3

static func person(a: PixelArt, x: int, y: int, robe: Color, hat: String = "gat", facing: int = 1, _s: int = 1) -> void:
	# 키 약 11px의 작은 사람(y는 발 위치)
	var skin := Color("f1c9a0")
	a.rect(x - 2, y - 6, 5, 6, robe)
	a.rect(x - 2, y - 6, 1, 6, PixelArt.shade(robe, 0.16))
	a.rect(x + 2, y - 6, 1, 6, PixelArt.shade(robe, -0.3))
	a.rect(x - 1, y, 1, 2, Color("e8e0d0"))
	a.rect(x + 1, y, 1, 2, Color("e8e0d0"))
	a.rect(x - 1, y - 9, 3, 3, skin)
	a.px(x + (1 if facing > 0 else -1), y - 8, Color("1a1410"))
	match hat:
		"gat":
			a.rect(x - 3, y - 10, 7, 1, Color("1c1c26"))
			a.rect(x - 1, y - 12, 3, 2, Color("1c1c26"))
		"topknot":
			a.rect(x - 1, y - 10, 3, 1, Color("26201c"))
			a.rect(x, y - 11, 2, 1, Color("26201c"))
		"jeonlip":
			a.rect(x - 3, y - 10, 7, 1, Color("2a2420"))
			a.rect(x - 1, y - 12, 3, 2, Color("2a2a30"))
			a.px(x, y - 13, Color("c0392b"))
		"samo":
			a.rect(x - 1, y - 12, 3, 3, Color("14141b"))
			a.line(x - 4, y - 10, x + 4, y - 10, Color("14141b"))
		"helmet":
			a.rect(x - 2, y - 11, 5, 2, Color("747c86"))
			a.px(x, y - 12, Color("c0392b"))
		"satgat":
			a.line(x - 4, y - 9, x + 4, y - 9, Color("d4b878"))
			a.rect(x - 2, y - 11, 5, 2, Color("d4b878"))
		"none":
			a.rect(x - 1, y - 10, 3, 1, Color("26201c"))

# ─────────────────────────────────────────── 조립
static func make(key: String) -> ImageTexture:
	var bg := PixelArt.new(S, S)
	var fig := PixelArt.new(S, S)
	var edge := Color("7a5835")
	var ring := Color("c9b28b")
	match key:
		"house_thatched":
			sky(bg, Color("b8dcf0"), Color("eef6f0"))
			hills(bg, 54, 12.0, Color("8aae78"), 0.6)
			grass(bg, 56, Color("78a458"), Color("5a8844"))
			round_tree(fig, 12, 62, 7, Color("4a8a46"))
			_thatched(fig)
		"house_tile":
			sky(bg, Color("b8dcf0"), Color("eef6f0"))
			hills(bg, 52, 12.0, Color("8aae78"), 1.4)
			grass(bg, 56, Color("78a458"), Color("5a8844"))
			_house_tile(fig)
		"construction":
			sky(bg, Color("a8cde8"), Color("f0e8d0"))
			hills(bg, 52, 10.0, Color("a8b890"), 0.2)
			ground_path(bg, 56, Color("c8b088"))
			_construction(fig)
		"gate":
			sky(bg, Color("a8cde8"), Color("eef2ec"))
			hills(bg, 50, 12.0, Color("7a9a78"), 2.0)
			grass(bg, 60, Color("78a458"), Color("5a8844"))
			_gate(fig)
		"wall":
			sky(bg, Color("a8cde8"), Color("eef2ec"))
			hills(bg, 46, 14.0, Color("6a8a70"), 0.9)
			grass(bg, 62, Color("78a458"), Color("5a8844"))
			_wall(fig)
		"fort":
			sky(bg, Color("a8cde8"), Color("eef2ec"))
			hills(bg, 48, 12.0, Color("6a8a70"), 3.0)
			grass(bg, 62, Color("78a458"), Color("5a8844"))
			_fort(fig)
		"gongsimdon":
			sky(bg, Color("a8cde8"), Color("f0eadc"))
			hills(bg, 52, 12.0, Color("7a9a78"), 1.0)
			grass(bg, 64, Color("78a458"), Color("5a8844"))
			_gongsimdon(fig)
		"poru":
			sky(bg, Color("a8cde8"), Color("f0eadc"))
			hills(bg, 48, 12.0, Color("7a9a78"), 2.4)
			grass(bg, 66, Color("78a458"), Color("5a8844"))
			_poru(fig)
		"bongdon":
			sky(bg, Color("8fb4d8"), Color("e8dcc8"))
			hills(bg, 54, 16.0, Color("6a8470"), 0.4)
			grass(bg, 64, Color("78a458"), Color("5a8844"))
			_bongdon(fig)
		"haenggung":
			sky(bg, Color("a8cde8"), Color("f4efe0"))
			hills(bg, 44, 16.0, Color("6a8a70"), 1.6)
			ground_path(bg, 62, Color("cdbf9e"))
			_haenggung(fig)
		"jongnu":
			sky(bg, Color("a8cde8"), Color("f4efe0"))
			ground_path(bg, 62, Color("cdbf9e"))
			_jongnu(fig)
		"seojangdae":
			sky(bg, Color("9cc4e4"), Color("e8eef0"))
			hills(bg, 56, 10.0, Color("7a9a78"), 0.3)
			_seojangdae(bg, fig)
		"banghwasuryujeong":
			sky(bg, Color("a8cde8"), Color("f0eadc"))
			hills(bg, 50, 12.0, Color("7a9a78"), 2.8)
			_banghwa(bg, fig)
		"hwahongmun", "hwahong_mun":
			sky(bg, Color("a8cde8"), Color("f0eadc"))
			hills(bg, 48, 12.0, Color("7a9a78"), 3.4)
			_sumun(bg, fig, 7)
			# 화홍문: 물보라 위로 무지개가 선다
			for k in range(5):
				bg.ell(40.0, 58.0, 36.0 - float(k) * 1.6, 20.0 - float(k) * 1.0, [Color(0.9, 0.3, 0.3, 0.28), Color(0.95, 0.7, 0.3, 0.28), Color(0.95, 0.95, 0.4, 0.28), Color(0.4, 0.8, 0.5, 0.28), Color(0.4, 0.6, 0.9, 0.28)][k])
		"namsumun", "namsu_mun":
			sky(bg, Color("a8cde8"), Color("f0eadc"))
			hills(bg, 50, 10.0, Color("7a9a78"), 4.4)
			_sumun(bg, fig, 9)
		"maehwang_gyo", "maehyang_gyo":
			sky(bg, Color("b8d8ee"), Color("f6eef0"))
			hills(bg, 46, 12.0, Color("9ab090"), 0.7)
			_bridge(bg, fig)
		"yeonmudae":
			sky(bg, Color("a8cde8"), Color("f4efe0"))
			hills(bg, 46, 12.0, Color("6a8a70"), 0.5)
			ground_path(bg, 62, Color("d6c8a4"))
			_yeonmudae(fig)
		"embankment":
			sky(bg, Color("a8cde8"), Color("eef2ec"))
			hills(bg, 44, 10.0, Color("9ab090"), 1.1)
			_embankment(bg, fig)
		"road":
			sky(bg, Color("b8dcf0"), Color("eef6f0"))
			hills(bg, 44, 14.0, Color("8aae78"), 0.9)
			grass(bg, 46, Color("78a458"), Color("5a8844"))
			_road(bg, fig)
		"market":
			sky(bg, Color("b8dcf0"), Color("f4efe0"))
			ground_path(bg, 60, Color("cdbf9e"))
			_market(fig)
		"facility":
			sky(bg, Color("b8dcf0"), Color("f4efe0"))
			ground_path(bg, 62, Color("cdbf9e"))
			hall(fig, 20, 60, 66, 1)
			flag(fig, 66, 36, Color("c0392b"), 18)
		"base_jungin", "base_ajeon", "base_artisan", "base_butcher":
			sky(bg, Color("b8dcf0"), Color("f4efe0"))
			ground_path(bg, 62, Color("cdbf9e"))
			_base(bg, fig, key)
		"seodang":
			sky(bg, Color("b8dcf0"), Color("f4efe0"))
			hills(bg, 52, 10.0, Color("8aae78"), 2.0)
			grass(bg, 60, Color("78a458"), Color("5a8844"))
			_seodang(fig, false)
		"seowon":
			sky(bg, Color("b8dcf0"), Color("f4efe0"))
			hills(bg, 46, 14.0, Color("6a8a70"), 3.1)
			grass(bg, 62, Color("78a458"), Color("5a8844"))
			_seodang(fig, true)
		"shop_silk", "shop_fish", "shop_rice", "shop_smith", "shop_jumak":
			sky(bg, Color("b8dcf0"), Color("f4efe0"))
			ground_path(bg, 60, Color("cdbf9e"))
			_shop(fig, key)
		_:
			return null
	fig.outline(Color("1f1812"))
	return PortraitArt._finish(bg, fig, edge, ring)

# ─────────────────────────────────────────── 각 건물
static func _thatched(f: PixelArt) -> void:
	# 흙벽 + 사립문 + 볏짚 이엉
	f.srect(18, 40, 44, 22, Color("c4a782"))
	for k in range(5):
		f.line(20 + k * 9, 42, 22 + k * 9, 60, Color("b09670"))
	lattice(f, 24, 46, 10, 9)
	door(f, 42, 46, 12, 16, Color("7a5230"))
	# 이엉 지붕(둥글게 부푼 볏짚)
	f.spoly(PackedVector2Array([Vector2(10, 44), Vector2(18, 30), Vector2(30, 24), Vector2(50, 24), Vector2(62, 30), Vector2(70, 44), Vector2(66, 47), Vector2(14, 47)]), Color("d8b45e"), 0.2, -0.3)
	for k in range(9):
		f.line(14 + k * 6, 45, 20 + k * 5, 27, Color("b8923e"))
	for k in range(7):
		f.px(14 + k * 8, 46, Color("a8803a"))
	f.line(18, 28, 62, 28, Color("e8d28a"), 2)
	# 용마름과 박 넝쿨
	f.ball(22, 33, 4, 3.2, Color("e8dcc0"))
	f.ball(28, 31, 3, 2.6, Color("e8dcc0"))
	f.ball(56, 34, 3.4, 3, Color("f0d890"))
	# 굴뚝 연기
	f.rect(54, 20, 4, 6, Color("8a7a6a"))
	smoke(f, 57, 16, 4)
	# 돌담 / 장독
	f.ball(14, 60, 4, 3.2, Color("7a5a3a"))
	f.ball(20, 61, 3, 2.6, Color("6a4a2c"))

static func _house_tile(f: PixelArt) -> void:
	stone_wall(f, 14, 50, 52, 10, Color("a89a86"))
	plaster_wall(f, 18, 38, 44, 13, Color("f2ead8"))
	for k in range(5):
		pillar(f, 18 + k * 11, 38, 13, Color("7a4a2a"))
	lattice(f, 22, 41, 7, 7)
	lattice(f, 51, 41, 7, 7)
	door(f, 34, 41, 12, 10, Color("6a3a22"))
	tile_roof(f, 10, 70, 24, 38, Color("3c4650"))
	f.rect(54, 14, 5, 9, Color("8a7a6a"))
	smoke(f, 56, 10, 3)
	# 담장 너머 감나무
	round_tree(f, 8, 62, 6, Color("5a9a4a"))
	f.ball(5, 54, 1.5, 1.5, Color("e8782a"))
	f.ball(10, 52, 1.5, 1.5, Color("e8782a"))

static func _construction(f: PixelArt) -> void:
	# 거중기와 쌓는 성돌, 비계
	stone_wall(f, 8, 44, 28, 20, Color("a6a094"))
	for k in range(3):
		f.rect(10 + k * 9, 40, 8, 4, Color("b0aa9e"))
	# 비계(통나무 틀)
	for x in [44, 60]:
		f.line(x, 66, x, 20, Color("8a5a2a"), 2)
	for y in [30, 42, 54]:
		f.line(42, y, 62, y, Color("a06d3b"), 2)
	f.line(44, 54, 60, 30, Color("8a5a2a"))
	# 거중기: 삼각대 + 도르래 + 매달린 돌
	f.line(24, 66, 36, 14, Color("7a4a1e"), 3)
	f.line(46, 66, 36, 14, Color("7a4a1e"), 3)
	f.ball(36, 13, 4, 4, Color("5a626a"))
	f.line(36, 17, 36, 34, Color("d8c898"))
	f.rect(30, 34, 12, 9, Color("c4beb0"))
	f.rect(30, 34, 12, 2, Color("e0dacc"))
	f.ball(36, 60, 6, 6, Color("8a5a2a"))
	f.ball(36, 60, 2.6, 2.6, Color("5a3a1a"))
	# 일꾼들
	person(f, 20, 66, Color("e8e0cc"), "topknot")
	person(f, 54, 66, Color("e8e0cc"), "none")
	person(f, 66, 66, Color("c8d0d8"), "none")

static func _gate(f: PixelArt) -> void:
	# 홍예문 + 2층 문루 + 양옆 성벽
	stone_wall(f, 0, 52, 80, 12, Color("a6a094"))
	stone_wall(f, 18, 38, 44, 26, Color("b0aa9e"))
	arch(f, 40, 50, 8, 14, Color("1c1814"))
	f.rect(35, 50, 10, 14, Color("5a3a22"))
	f.line(40, 50, 40, 63, Color("2a1a10"))
	# 문루
	f.rect(24, 24, 32, 14, Color("efe8d8"))
	for k in range(5):
		pillar(f, 24 + k * 8, 24, 14)
	for k in range(4):
		lattice(f, 27 + k * 8, 28, 5, 7)
	tile_roof(f, 18, 62, 12, 24, Color("3c4650"))
	f.rect(16, 26, 48, 1, Color("2e8a6a"))
	flag(f, 12, 28, Color("c0392b"), 18)
	flag(f, 66, 28, Color("2f67c0"), 18)
	# 여장
	for k in range(0, 80, 8):
		f.rect(k, 48, 5, 4, Color("8a8478"))

static func _wall(f: PixelArt) -> void:
	# 성벽 줄기: 석축 + 여장(타) + 성곽 위 병사
	stone_wall(f, 0, 38, 80, 28, Color("aaa498"))
	for k in range(0, 80, 10):
		f.rect(k + 1, 28, 7, 10, Color("a49e92"))
		f.rect(k + 1, 28, 7, 2, Color("c4beb0"))
		f.rect(k + 3, 31, 2, 3, Color("2a2018"))
	f.rect(0, 36, 80, 2, Color("8a8478"))
	person(f, 20, 36, Color("6a2a2a"), "jeonlip")
	person(f, 54, 36, Color("224870"), "jeonlip")
	flag(f, 36, 8, Color("c0392b"), 22)

static func _fort(f: PixelArt) -> void:
	# 치성/돈대: 성벽에서 튀어나온 네모난 석대와 그 위의 병사
	stone_wall(f, 0, 48, 80, 16, Color("a6a094"))
	stone_wall(f, 22, 30, 36, 34, Color("b4aea0"))
	for k in range(22, 58, 8):
		f.rect(k + 1, 24, 6, 6, Color("a49e92"))
		f.rect(k + 3, 26, 2, 3, Color("2a2018"))
	f.rect(22, 30, 36, 2, Color("8a8478"))
	person(f, 32, 30, Color("6a2a2a"), "jeonlip")
	person(f, 46, 30, Color("224870"), "jeonlip")
	flag(f, 40, 6, Color("c0392b"), 20)

static func _gongsimdon(f: PixelArt) -> void:
	# 둥근 벽돌 몸통 + 처마 지붕 + 포구
	f.ell(40, 64, 20, 5, Color("a6a094"))
	f.srect(22, 28, 36, 36, Color("5c5853"))
	f.ell(40, 64, 18, 4, Color("5c5853"))
	for yy in range(30, 62, 3):
		f.line(22, yy, 57, yy, Color("423e3a"))
	f.rect(22, 44, 36, 3, Color("b8b2a4"))
	for k in range(3):
		f.rect(26 + k * 11, 36, 4, 4, Color("141210"))
		f.rect(28 + k * 11, 37, 5, 2, Color("2a2c30"))
	for k in range(4):
		f.rect(25 + k * 9, 52, 2, 3, Color("141210"))
	arch(f, 40, 58, 4, 6, Color("1c1814"))
	# 처마지붕(팔각)
	f.spoly(PackedVector2Array([Vector2(12, 28), Vector2(24, 12), Vector2(56, 12), Vector2(68, 28), Vector2(40, 32)]), Color("4d5762"), 0.16, -0.3)
	for k in range(1, 8):
		f.line(40, 10, 12 + k * 7, 29, Color("39414a"))
	f.line(14, 28, 66, 28, Color("2e8a6a"), 1)
	f.rect(38, 4, 4, 8, Color("2a2a30"))
	flag(f, 40, -2, Color("2f67c0"), 8)
	for k in range(5):
		pillar(f, 24 + k * 8, 28, 5, Color("a8322a"))

static func _poru(f: PixelArt) -> void:
	stone_wall(f, 0, 56, 80, 10, Color("a6a094"))
	stone_wall(f, 16, 44, 48, 22, Color("b8b2a4"))
	brick_wall(f, 20, 28, 40, 18, Color("4a4644"))
	for k in range(3):
		f.rect(25 + k * 12, 34, 5, 5, Color("121010"))
		f.rect(28 + k * 12, 35, 6, 2, Color("2a2c30"))
	for k in range(4):
		f.rect(24 + k * 10, 42, 2, 3, Color("121010"))
	# 위층 누각
	f.rect(24, 16, 32, 12, Color("9a3a2c"))
	for k in range(3):
		lattice(f, 27 + k * 9, 18, 6, 8, Color("efe4c8"))
	for k in range(4):
		pillar(f, 24 + k * 10, 16, 12, Color("7a2418"))
	tile_roof(f, 16, 64, 4, 16, Color("3c4650"))
	flag(f, 66, 20, Color("c0392b"), 20)
	flag(f, 12, 26, Color("2f67c0"), 18)

static func _bongdon(f: PixelArt) -> void:
	# 봉수대: 다섯 아궁이 굴뚝에서 오르는 연기
	stone_wall(f, 10, 50, 60, 16, Color("a6a094"))
	f.rect(8, 48, 64, 3, Color("c4beb0"))
	for k in range(5):
		var bx := 14 + k * 11
		brick_wall(f, bx, 32, 8, 18, Color("5c5853"))
		f.rect(bx - 1, 30, 10, 3, Color("b8b2a4"))
		f.rect(bx + 2, 42, 4, 5, Color("2a1a10"))
		smoke(f, bx + 4, 28, 4)
	f.rect(8, 40, 3, 8, Color("8a5a2a"))
	person(f, 66, 48, Color("6a2a2a"), "jeonlip")

static func _haenggung(f: PixelArt) -> void:
	# 중앙 봉수당 큰 전각 + 좌우 낭청 + 홍살문
	hall(f, 18, 62, 66, 1)
	hall(f, 2, 20, 66, 1)
	hall(f, 60, 78, 66, 1)
	f.rect(36, 60, 8, 6, Color("d8c8a0"))
	flag(f, 40, 20, Color("c0392b"), 18)
	# 홍살문
	f.rect(30, 52, 2, 14, Color("b22222"))
	f.rect(48, 52, 2, 14, Color("b22222"))
	f.rect(28, 50, 24, 2, Color("b22222"))

static func _jongnu(f: PixelArt) -> void:
	hall(f, 18, 62, 68, 2)
	# 종각의 큰 종
	f.ball(40, 50, 5, 6, Color("d4af37"))
	f.rect(37, 52, 6, 3, Color("a8872a"))
	f.line(40, 40, 40, 44, Color("5a3a22"))
	f.ell(40, 66, 8, 2, Color("8a6a2a"))

static func _seojangdae(bg: PixelArt, f: PixelArt) -> void:
	# 팔달산 바위 위 2층 누각
	bg.spoly(PackedVector2Array([Vector2(0, 80), Vector2(8, 58), Vector2(22, 52), Vector2(58, 52), Vector2(72, 58), Vector2(80, 80)]), Color("8a8a7c"), 0.2, -0.3)
	f.spoly(PackedVector2Array([Vector2(4, 80), Vector2(12, 62), Vector2(26, 56), Vector2(54, 56), Vector2(68, 62), Vector2(76, 80)]), Color("8e8e82"), 0.22, -0.3)
	hall(f, 22, 58, 62, 2)
	f.line(62, 40, 62, 18, Color("5a3a22"), 2)
	f.poly(PackedVector2Array([Vector2(63, 18), Vector2(76, 21), Vector2(63, 28)]), Color("e8c820"))
	pine(f, 10, 64, 0.8)
	pine(f, 71, 64, 0.8)

static func _banghwa(bg: PixelArt, f: PixelArt) -> void:
	# 용연(연못) 위로 솟은 바위 위 누각과 버드나무
	water(bg, 0, 56, 80, 24, Color("5aa2d0"), Color("2a6a9e"))
	f.spoly(PackedVector2Array([Vector2(8, 66), Vector2(14, 52), Vector2(28, 46), Vector2(58, 46), Vector2(70, 52), Vector2(74, 66)]), Color("8a867a"), 0.22, -0.32)
	# 십자(亞)형 지붕 정자
	for k in range(4):
		pillar(f, 26 + k * 9, 36, 12, Color("a8342a"))
	f.rect(26, 38, 29, 8, Color("efe8d8"))
	for k in range(3):
		lattice(f, 29 + k * 9, 39, 6, 6)
	tile_roof(f, 18, 62, 24, 36, Color("3c4650"))
	tile_roof(f, 30, 50, 14, 26, Color("464f5a"))
	f.line(40, 12, 40, 16, Color("e8e6e0"), 2)
	willow(f, 70, 66)
	willow(f, 8, 66)
	f.ell(40, 72, 24, 3, Color(1, 1, 1, 0.25))

static func _sumun(bg: PixelArt, f: PixelArt, arches: int) -> void:
	water(bg, 0, 60, 80, 20, Color("5aa2d0"), Color("2a6a9e"))
	stone_wall(f, 2, 42, 76, 22, Color("b0aa9e"))
	var span := int(float(70) / float(arches))
	for k in range(arches):
		var cx := 6 + int(float(span) / 2.0) + k * span
		arch(f, cx, 52, maxi(3, int(float(span) / 2.0) - 2), 12, Color("2a6a9e"), Color("cfc8b8"))
	hall(f, 22, 58, 42, 1)
	for k in range(0, 80, 8):
		f.rect(k + 1, 40, 5, 3, Color("8a8478"))

static func _bridge(bg: PixelArt, f: PixelArt) -> void:
	water(bg, 0, 54, 80, 26, Color("5aa2d0"), Color("2a6a9e"))
	f.rect(6, 40, 68, 8, Color("d8d2c4"))
	f.rect(6, 40, 68, 1, Color("f4f0e6"))
	for k in range(0, 68, 6):
		f.rect(7 + k, 33, 3, 7, Color("b0aa9c"))
	f.rect(6, 32, 68, 2, Color("8a8478"))
	for cx in [22, 40, 58]:
		arch(f, cx, 54, 6, 8, Color("2a6a9e"), Color("cfc8b8"))
	stone_wall(f, 6, 46, 68, 10, Color("c4beb0"))
	for cx in [22, 40, 58]:
		f.ell(float(cx), 56.0, 6.0, 7.0, Color("2a6a9e"))
	blossom(f, 12, 66)
	willow(f, 72, 66)

static func _yeonmudae(f: PixelArt) -> void:
	hall(f, 14, 50, 58, 1)
	# 과녁과 활 쏘는 사람
	f.line(64, 62, 64, 40, Color("6a4a2a"), 2)
	f.ball(64, 38, 8, 8, Color("efe8d8"))
	f.ball(64, 38, 6, 6, Color("2a4a8a"))
	f.ball(64, 38, 4, 4, Color("c0392b"))
	f.ball(64, 38, 1.6, 1.6, Color("f1c40f"))
	f.line(40, 60, 62, 40, Color("e8dcc0"))
	person(f, 36, 66, Color("224870"), "jeonlip")
	flag(f, 12, 22, Color("c0392b"), 18)

static func _embankment(bg: PixelArt, f: PixelArt) -> void:
	water(bg, 0, 54, 80, 26, Color("5aa2d0"), Color("2a6a9e"))
	stone_wall(f, 0, 38, 80, 18, Color("a6a094"))
	f.rect(0, 36, 80, 3, Color("8aae78"))
	for k in range(0, 80, 5):
		f.px(k, 35, Color("5a8844"))
	willow(f, 14, 38)
	willow(f, 62, 38)
	f.line(0, 56, 80, 56, Color("6a665c"), 2)

static func _road(_bg: PixelArt, f: PixelArt) -> void:
	# 박석 길(원근)과 길가 나무
	f.poly(PackedVector2Array([Vector2(34, 46), Vector2(46, 46), Vector2(74, 80), Vector2(6, 80)]), Color("b8b2a4"))
	for k in range(6):
		var yy := 50 + k * 6
		var half := 6 + int(float((yy - 46) * 14) / 34.0)
		f.line(40 - half, yy, 40 + half, yy, Color("8a8478"))
		for j in range(-1, 2):
			f.line(40 + int(float(j * half) / 2.0), yy, 40 + int(float(j * (half + 3)) / 2.0), yy + 6, Color("8a8478"))
	pine(f, 12, 62, 0.9)
	pine(f, 68, 60, 0.9)
	round_tree(f, 24, 48, 5, Color("5a9a4a"))
	round_tree(f, 56, 48, 5, Color("6aaa4a"))
	person(f, 40, 56, Color("e8e0cc"), "gat")

static func _market(f: PixelArt) -> void:
	# 저잣거리: 처마 맞댄 장옥들과 차양
	for k in range(3):
		var x0 := 4 + k * 25
		plaster_wall(f, x0, 40, 22, 22, [Color("efe8d8"), Color("e8dcc0"), Color("f2ead8")][k])
		tile_roof(f, x0 - 2, x0 + 24, 28, 40, Color("3c4650"))
		f.rect(x0 + 2, 46, 18, 3, [Color("c0392b"), Color("2f67c0"), Color("d4a020")][k]) # 차양
		f.rect(x0 + 4, 52, 14, 10, Color("5a3a22"))
		f.ball(float(x0 + 8), 55.0, 2.5, 2.5, [Color("e8782a"), Color("d8c8a0"), Color("8a6a3a")][k])
		f.ball(float(x0 + 14), 56.0, 2.5, 2.5, [Color("c0392b"), Color("7a9a68"), Color("e8d8a0")][k])
	person(f, 30, 66, Color("e8e0cc"), "topknot")
	person(f, 58, 66, Color("8aa070"), "gat")

static func _base(_bg: PixelArt, f: PixelArt, key: String) -> void:
	match key:
		"base_jungin":
			hall(f, 18, 62, 66, 1, Color("3c4650"), Color("e8eef0"))
			f.rect(34, 52, 12, 6, Color("5a7a8a"))
			person(f, 14, 70, Color("58728a"), "gat")
			person(f, 66, 70, Color("58728a"), "gat")
		"base_ajeon":
			hall(f, 16, 64, 66, 1, Color("4a4a44"), Color("e8e4d4"))
			flag(f, 12, 34, Color("3e6a6a"), 20)
			f.rect(34, 56, 12, 6, Color("e8dcb8"))
			person(f, 12, 72, Color("3e6a6a"), "samo")
		"base_artisan":
			f.srect(14, 42, 52, 20, Color("b8a07a"))
			tile_roof(f, 8, 72, 28, 42, Color("5a4a40"))
			f.rect(52, 18, 6, 12, Color("6a5a50"))
			smoke(f, 55, 14, 4)
			f.rect(20, 50, 14, 12, Color("2a1a10"))
			f.ball(27, 56, 3, 3, Color("f28a30")) # 화덕
			f.rect(44, 52, 12, 4, Color("5a626a")) # 모루
			f.rect(48, 56, 4, 6, Color("5a4630"))
			person(f, 38, 72, Color("8a7a64"), "none")
		_:
			f.srect(14, 42, 52, 20, Color("c8b898"))
			tile_roof(f, 8, 72, 28, 42, Color("4a4a44"))
			# 고기를 거는 갈고리와 고깃덩이
			f.line(24, 46, 56, 46, Color("5a4630"), 2)
			for k in range(3):
				f.line(30 + k * 10, 46, 30 + k * 10, 50, Color("7a7a7a"))
				f.ball(float(30 + k * 10), 54.0, 3.0, 5.0, Color("b84a40"))
			person(f, 60, 72, Color("e6e0d2"), "none")

static func _seodang(f: PixelArt, big: bool) -> void:
	if big:
		# 서원: 대문(三門) + 강당 + 담
		stone_wall(f, 4, 56, 72, 8, Color("a89a86"))
		hall(f, 12, 68, 62, 1)
		f.rect(2, 36, 4, 28, Color("8a6a40"))
		pine(f, 70, 62, 1.0)
		pine(f, 8, 62, 0.8)
		f.rect(34, 24, 12, 3, Color("2a2018"))
	else:
		f.srect(14, 42, 52, 20, Color("c4a782"))
		tile_roof(f, 8, 72, 28, 42, Color("5a5048"))
		lattice(f, 20, 46, 10, 10)
		lattice(f, 34, 46, 10, 10)
		door(f, 50, 46, 10, 16)
		round_tree(f, 74, 62, 6, Color("4a8a46"))
		# 훈장님과 아이들
		person(f, 28, 70, Color("e8e0cc"), "topknot")
		person(f, 44, 72, Color("f2d8a0"), "none")
		person(f, 56, 70, Color("e8c8c0"), "none")

static func _shop(f: PixelArt, key: String) -> void:
	var awn := Color("c0392b")
	var _goods := Color("d8c8a0")
	match key:
		"shop_silk":
			awn = Color("8e44ad")
		"shop_fish":
			awn = Color("2f67c0")
		"shop_rice":
			awn = Color("d4a020")
		"shop_smith":
			awn = Color("5a626a")
		_:
			awn = Color("a8342a")
	plaster_wall(f, 10, 36, 60, 28, Color("efe8d8"))
	tile_roof(f, 4, 76, 22, 36, Color("3c4650"))
	f.rect(10, 38, 60, 5, awn)
	for k in range(0, 60, 6):
		f.rect(10 + k, 43, 3, 3, awn)
	f.rect(14, 52, 52, 4, Color("7a5230")) # 가판
	f.rect(14, 56, 52, 8, Color("5a3a22"))
	match key:
		"shop_silk":
			for k in range(5):
				f.rect(16 + k * 10, 44, 6, 10, [Color("c0392b"), Color("2f67c0"), Color("e8c040"), Color("2ecc71"), Color("e91e63")][k])
		"shop_fish":
			for k in range(4):
				f.ell(float(22 + k * 12), 50.0, 5.0, 2.2, Color("a8c0d0"))
				f.px(26 + k * 12, 49, Color("2a3a4a"))
			f.line(20, 40, 20, 52, Color("5a3a22"))
		"shop_rice":
			for k in range(3):
				f.ball(float(24 + k * 14), 48.0, 7.0, 5.0, Color("e8dcb0"))
				f.rect(17 + k * 14, 50, 14, 4, Color("9a7a4a"))
		"shop_smith":
			f.ball(24, 48, 5, 5, Color("f28a30"))
			f.rect(40, 47, 14, 5, Color("5a626a"))
			f.line(58, 40, 62, 52, Color("5a626a"), 2)
			smoke(f, 24, 40, 3)
		_:
			for k in range(3):
				f.ell(float(24 + k * 14), 50.0, 5.0, 3.0, Color("8a5a2a"))
				f.rect(21 + k * 14, 50, 6, 4, Color("6a3a22"))
			f.line(40, 38, 40, 46, Color("5a3a22"))
			f.rect(36, 40, 8, 6, Color("f6f0e0"))
	person(f, 40, 72, Color("e8e0cc"), "topknot")
