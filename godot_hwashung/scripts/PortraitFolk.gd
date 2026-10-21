extends RefCounted
class_name PortraitFolk

## 살피기 팝업의 민속놀이·일상 활동·동물 도트 그림(80x80). 몸짓이 있는 작은 인물(man/woman)을 모아 장면을 만든다.

const S := 80
const SCENES := ["seokjeon", "ssireum", "kite", "firefighting", "hunting", "playing", "washing", "fishing", "cheering", "training", "jwibul",
	"bull_parade", "ganggang", "lion", "neolttwigi", "swing", "kids", "play", "namsadang", "jeongisu", "pungmul", "talchum", "paengi", "taekkyeon"]
const ANIMALS := ["tiger", "wolf", "wild_boar", "deer", "crane", "rabbit", "cattle"]

static func has(key: String) -> bool:
	return SCENES.has(key) or ANIMALS.has(key)

const SKIN := Color("f1c9a0")
const WHITE := Color("efe8d8")

# ─────────────────────────────────────────── 작은 인물(키 약 16px, y는 발바닥)
## la/ra: 어깨에서 손까지 / ll/rl: 엉덩이에서 발까지의 상대 위치
static func man(a: PixelArt, x: int, y: int, robe: Color, hat: String = "topknot", la: Vector2i = Vector2i(-2, 6), ra: Vector2i = Vector2i(2, 6), ll: Vector2i = Vector2i(-1, 5), rl: Vector2i = Vector2i(1, 5), skirt: bool = false) -> void:
	var sh := y - 11
	var hip := y - 5
	# 다리
	if not skirt:
		a.line(x - 1, hip, x + ll.x, hip + ll.y, WHITE, 2)
		a.line(x + 1, hip, x + rl.x, hip + rl.y, PixelArt.shade(WHITE, -0.2), 2)
		a.px(x + ll.x, hip + ll.y + 1, Color("4a4038"))
		a.px(x + rl.x, hip + rl.y + 1, Color("4a4038"))
	# 몸통
	if skirt:
		a.poly(PackedVector2Array([Vector2(x - 2, sh), Vector2(x + 3, sh), Vector2(x + 5, y), Vector2(x - 4, y)]), robe)
		a.rect(x - 2, sh, 5, 3, Color("f4efe0"))
		a.px(x, sh + 3, Color("c0392b"))
	else:
		a.rect(x - 2, sh, 5, 7, robe)
		a.rect(x - 2, sh, 1, 7, PixelArt.shade(robe, 0.18))
		a.rect(x + 2, sh, 1, 7, PixelArt.shade(robe, -0.28))
	# 팔
	a.line(x - 2, sh + 1, x - 2 + la.x, sh + 1 + la.y, robe, 2)
	a.line(x + 2, sh + 1, x + 2 + ra.x, sh + 1 + ra.y, PixelArt.shade(robe, -0.15), 2)
	a.px(x - 2 + la.x, sh + 1 + la.y, SKIN)
	a.px(x + 2 + ra.x, sh + 1 + ra.y, SKIN)
	# 머리
	a.ball(float(x) + 0.5, float(sh) - 2.5, 2.8, 3.0, SKIN)
	a.px(x + 1, sh - 3, Color("1a1410"))
	_hat(a, x, sh - 5, hat)

static func _hat(a: PixelArt, x: int, hy: int, hat: String) -> void:
	match hat:
		"topknot":
			a.rect(x - 2, hy, 5, 2, Color("26201c"))
			a.rect(x - 1, hy - 2, 3, 2, Color("26201c"))
		"gat":
			a.rect(x - 5, hy + 1, 11, 1, Color("1c1c26"))
			a.rect(x - 2, hy - 3, 5, 4, Color("1c1c26"))
		"jeonlip":
			a.rect(x - 5, hy + 1, 11, 1, Color("2a2420"))
			a.rect(x - 3, hy - 2, 7, 3, Color("2a2a30"))
			a.px(x, hy - 4, Color("c0392b"))
			a.px(x + 1, hy - 3, Color("c0392b"))
		"helmet":
			a.rect(x - 3, hy - 1, 7, 3, Color("747c86"))
			a.px(x, hy - 3, Color("c0392b"))
		"satgat":
			a.line(x - 5, hy + 2, x + 5, hy + 2, Color("d4b878"))
			a.rect(x - 3, hy - 1, 7, 3, Color("d4b878"))
		"sangmo":
			a.rect(x - 4, hy + 1, 9, 1, Color("c0392b"))
			a.rect(x - 2, hy - 2, 5, 3, Color("f0ead8"))
			for k in range(5):
				a.line(x, hy - 2, x - 3 + k * 2, hy - 8 + (k & 1), Color("f4f0e0"))
		"bun":
			a.rect(x - 2, hy, 5, 2, Color("1c1a1a"))
			a.ball(float(x) - 1.0, float(hy) + 3.0, 1.8, 1.8, Color("1c1a1a"))
		"braid":
			a.rect(x - 2, hy, 5, 2, Color("1c1a1a"))
			a.line(x - 2, hy + 2, x - 3, hy + 11, Color("1c1a1a"), 2)
			a.px(x - 3, hy + 11, Color("c0392b"))
		"headband":
			a.rect(x - 2, hy, 5, 2, Color("26201c"))
			a.rect(x - 2, hy + 2, 5, 1, Color("efe6d4"))
		"headband_red":
			a.rect(x - 2, hy, 5, 2, Color("26201c"))
			a.rect(x - 2, hy + 2, 5, 1, Color("c02a22"))
		"none":
			a.rect(x - 2, hy + 1, 5, 1, Color("26201c"))
		_:
			pass

static func woman(a: PixelArt, x: int, y: int, robe: Color, hat: String = "bun", la: Vector2i = Vector2i(-2, 6), ra: Vector2i = Vector2i(2, 6)) -> void:
	man(a, x, y, robe, hat, la, ra, Vector2i(-1, 5), Vector2i(1, 5), true)

# ─────────────────────────────────────────── 조립
static func make(key: String) -> ImageTexture:
	var bg := PixelArt.new(S, S)
	var f := PixelArt.new(S, S)
	var night := false
	match key:
		"tiger", "wolf", "wild_boar", "deer", "rabbit":
			PortraitScenes.sky(bg, Color("a8cde8"), Color("e8f0dc"), 50)
			PortraitScenes.hills(bg, 46, 12.0, Color("7a9a78"), float(key.length()))
			PortraitScenes.grass(bg, 54, Color("78a458"), Color("4a7a3a"))
			PortraitScenes.pine(bg, 9, 54, 0.8)
			PortraitScenes.pine(bg, 71, 54, 0.7)
			_animal(f, key)
		"crane":
			PortraitScenes.sky(bg, Color("b8dcf0"), Color("f0f4ec"), 50)
			PortraitScenes.hills(bg, 50, 10.0, Color("9ab090"), 0.5)
			PortraitScenes.water(bg, 0, 58, 80, 22, Color("5aa2d0"), Color("2a6a9e"))
			_crane(f)
		"cattle":
			PortraitScenes.sky(bg, Color("b8dcf0"), Color("f4efe0"), 50)
			PortraitScenes.hills(bg, 48, 12.0, Color("8aae78"), 1.0)
			PortraitScenes.grass(bg, 54, Color("86b45a"), Color("5a8844"))
			_cattle(f)
		"jwibul":
			night = true
			PortraitScenes.sky(bg, Color("0d1630"), Color("2a2a50"), 60)
			bg.ell(62, 14, 7, 7, Color("f4ecc8"))
			bg.ell(65, 12, 6, 6, Color("0f1834"))
			for k in range(14):
				bg.px((k * 29 + 7) % 78, (k * 17 + 4) % 36, Color("e8e0c0"))
			PortraitScenes.grass(bg, 56, Color("3a4a38"), Color("22302a"))
			_jwibul(f)
		"ganggang":
			night = true
			PortraitScenes.sky(bg, Color("131a3a"), Color("3a3a62"), 60)
			bg.ell(40, 18, 11, 11, Color("fbf0c8"))
			bg.ell(40, 18, 14, 14, Color(1, 0.95, 0.7, 0.18))
			PortraitScenes.grass(bg, 54, Color("3a4a38"), Color("22302a"))
			_ganggang(f)
		_:
			PortraitScenes.sky(bg, Color("b8dcf0"), Color("f4efe0"), 52)
			_scene(bg, f, key)
	f.outline(Color("1f1812") if not night else Color("0a0c18"))
	return PortraitArt._finish(bg, f, Color("7a5835"), Color("c9b28b"))

static func _scene(bg: PixelArt, f: PixelArt, key: String) -> void:
	match key:
		"seokjeon":
			PortraitScenes.hills(bg, 46, 12.0, Color("8aae78"), 1.9)
			PortraitScenes.ground_path(bg, 54, Color("cdbf9e"))
			PortraitScenes.water(bg, 28, 56, 24, 8, Color("5aa2d0"), Color("2a6a9e"))
			for k in range(3):
				man(f, 10 + k * 7, 62, Color("e8e0cc"), "headband", Vector2i(-4, -3), Vector2i(5, -6), Vector2i(-2, 5), Vector2i(2, 5))
				man(f, 54 + k * 7, 62, Color("d8c8a8"), "headband_red", Vector2i(-5, -6), Vector2i(4, -3), Vector2i(-2, 5), Vector2i(2, 5))
			for p in [Vector2i(32, 40), Vector2i(38, 34), Vector2i(46, 38), Vector2i(26, 46), Vector2i(50, 44)]:
				f.ball(float(p.x), float(p.y), 1.6, 1.6, Color("6a665c"))
			PortraitScenes.flag(f, 8, 28, Color("2f67c0"), 22)
			PortraitScenes.flag(f, 70, 28, Color("c0392b"), 22)
		"ssireum":
			PortraitScenes.hills(bg, 44, 12.0, Color("8aae78"), 0.8)
			bg.ell(40, 66, 38, 10, Color("e8d8a8"))
			bg.ell(40, 66, 38, 10, Color("e8d8a8"))
			for k in range(4):
				man(f, 8 + k * 7, 54, WHITE, "topknot")
				man(f, 52 + k * 7, 54, Color("d8c8a8"), "gat")
			# 씨름꾼 둘: 샅바를 잡고 맞붙은 모습
			man(f, 33, 66, Color("2f67c0"), "none", Vector2i(5, 2), Vector2i(7, -2), Vector2i(-3, 5), Vector2i(3, 5))
			man(f, 46, 66, Color("c0392b"), "none", Vector2i(-7, 0), Vector2i(-5, 3), Vector2i(-3, 5), Vector2i(3, 5))
		"kite":
			PortraitScenes.cloud(bg, 8, 14)
			PortraitScenes.hills(bg, 56, 10.0, Color("8aae78"), 0.3)
			PortraitScenes.grass(bg, 60, Color("78a458"), Color("5a8844"))
			# 방패연
			f.spoly(PackedVector2Array([Vector2(56, 10), Vector2(66, 22), Vector2(56, 34), Vector2(46, 22)]), Color("c0392b"), 0.2, -0.2)
			f.poly(PackedVector2Array([Vector2(56, 16), Vector2(61, 22), Vector2(56, 28), Vector2(51, 22)]), Color("efe8d8"))
			f.ball(56, 22, 2.6, 2.6, Color("2f67c0"))
			f.line(56, 34, 54, 46, Color("e8c040"), 1)
			for k in range(4):
				f.rect(55 + (k & 1), 35 + k * 3, 1, 3, Color("e8c040"))
			f.line(54, 46, 30, 62, Color("f4f0e0"))
			man(f, 28, 70, Color("2f67c0"), "none", Vector2i(2, -6), Vector2i(6, -5), Vector2i(-2, 5), Vector2i(2, 5))
			man(f, 14, 70, Color("e8c8c0"), "braid")
		"firefighting":
			PortraitScenes.sky(bg, Color("6a5a6a"), Color("e8a870"), 52)
			PortraitScenes.ground_path(bg, 62, Color("b8a888"))
			PortraitScenes.hall(f, 22, 56, 64, 1)
			for k in range(8):
				var fx := 26 + k * 4
				f.ball(float(fx), 40.0 - float(k % 3) * 3.0, 4.0, 6.0, Color("f28a30"))
				f.ball(float(fx), 42.0 - float(k % 3) * 3.0, 2.4, 4.0, Color("f8d040"))
			f.ball(40, 24, 7, 6, Color(0.35, 0.33, 0.33, 0.8))
			f.ball(46, 16, 6, 5, Color(0.4, 0.38, 0.38, 0.6))
			man(f, 14, 72, Color("e8e0cc"), "topknot", Vector2i(4, -5), Vector2i(5, -3))
			man(f, 66, 72, Color("e8e0cc"), "gat", Vector2i(-5, -3), Vector2i(-6, -5))
			f.line(20, 62, 28, 52, Color("5ab0e8"), 2)
			f.line(60, 62, 52, 52, Color("5ab0e8"), 2)
			f.rect(14, 70, 6, 5, Color("8a5a2a"))
		"hunting":
			PortraitScenes.hills(bg, 46, 14.0, Color("6a8a70"), 2.2)
			PortraitScenes.grass(bg, 56, Color("78a458"), Color("4a7a3a"))
			PortraitScenes.pine(bg, 70, 60, 1.0)
			PortraitScenes.pine(bg, 60, 58, 0.8)
			man(f, 18, 72, Color("7a5a3a"), "satgat", Vector2i(7, -5), Vector2i(-1, -4), Vector2i(-2, 5), Vector2i(2, 5))
			f.line(26, 58, 30, 70, Color("6a4a2a"), 2)
			f.line(26, 58, 20, 64, Color("e8e0c8"))
			f.line(26, 58, 36, 62, Color("e8c040"))
			_deer(f, 54, 66, 0.8)
		"playing", "kids", "play":
			PortraitScenes.hills(bg, 46, 10.0, Color("8aae78"), 0.4)
			PortraitScenes.ground_path(bg, 52, Color("d6c8a4"))
			PortraitScenes.tile_roof(bg, 0, 28, 28, 40, Color("3c4650"))
			bg.rect(2, 40, 24, 12, Color("efe8d8"))
			var cols := [Color("c0392b"), Color("2f67c0"), Color("e8c040"), Color("2ecc71")]
			man(f, 14, 68, cols[0], "braid", Vector2i(-4, -2), Vector2i(4, -4), Vector2i(-2, 5), Vector2i(2, 5))
			man(f, 30, 66, cols[1], "none", Vector2i(-5, -3), Vector2i(6, -5), Vector2i(-3, 4), Vector2i(2, 2))
			man(f, 46, 70, cols[2], "none", Vector2i(-4, 3), Vector2i(5, -2), Vector2i(-2, 5), Vector2i(2, 5))
			woman(f, 62, 68, Color("e86a8a"), "braid", Vector2i(-3, -4), Vector2i(3, -4))
			f.ball(34, 48, 2.5, 2.5, Color("f1c40f")) # 제기
			f.line(32, 46, 30, 42, Color("c0392b"))
			f.line(34, 46, 34, 41, Color("c0392b"))
			f.line(36, 46, 38, 42, Color("c0392b"))
			f.rect(52, 74, 5, 4, Color("e8c040")) # 딱지
			f.rect(58, 75, 5, 4, Color("2f67c0"))
		"washing":
			PortraitScenes.hills(bg, 44, 12.0, Color("8aae78"), 1.3)
			PortraitScenes.grass(bg, 48, Color("78a458"), Color("5a8844"))
			PortraitScenes.water(bg, 0, 58, 80, 22, Color("5aa2d0"), Color("2a6a9e"))
			PortraitScenes.willow(f, 66, 58)
			f.ell(24, 60, 14, 4, Color("9a968a"))
			f.ell(46, 62, 9, 3, Color("8a867a"))
			woman(f, 22, 60, Color("e8c8c0"), "bun", Vector2i(4, 5), Vector2i(8, 3))
			f.line(30, 58, 34, 52, Color("8a5a2a"), 2) # 빨랫방망이
			f.rect(26, 58, 8, 3, Color("f4f0e6")) # 빨래
			woman(f, 46, 60, Color("8ab0c8"), "braid", Vector2i(3, 5), Vector2i(7, 4))
			f.ell(58, 64, 5, 3, Color("8a5a2a")) # 빨래 광주리
		"fishing":
			PortraitScenes.hills(bg, 44, 14.0, Color("8aae78"), 2.7)
			PortraitScenes.grass(bg, 50, Color("78a458"), Color("5a8844"))
			PortraitScenes.water(bg, 0, 60, 80, 20, Color("5aa2d0"), Color("2a6a9e"))
			man(f, 18, 60, Color("7a9a68"), "satgat", Vector2i(5, 3), Vector2i(9, 0), Vector2i(-1, 5), Vector2i(3, 4))
			f.line(26, 54, 58, 30, Color("8a6a3a"))
			f.line(58, 30, 58, 62, Color("e8e0c8"))
			f.ball(58, 62, 1.6, 1.6, Color("c0392b"))
			f.ell(48, 70, 5, 2.2, Color("b8c8d8"))
			f.px(52, 69, Color("2a3a4a"))
			f.ell(14, 66, 4, 3, Color("8a5a2a"))
		"cheering":
			PortraitScenes.hills(bg, 44, 12.0, Color("8aae78"), 0.1)
			PortraitScenes.ground_path(bg, 56, Color("cdbf9e"))
			for k in range(5):
				var cx := 8 + k * 15
				man(f, cx, 66 + (k & 1) * 4, [Color("2f67c0"), Color("c0392b"), Color("e8e0cc"), Color("2ecc71"), Color("e8c040")][k], ["gat", "topknot", "satgat", "headband", "gat"][k], Vector2i(-4, -7), Vector2i(4, -7), Vector2i(-2, 5), Vector2i(2, 5))
			PortraitScenes.flag(f, 20, 26, Color("c0392b"), 22)
			PortraitScenes.flag(f, 60, 22, Color("2f67c0"), 24)
			for k in range(6):
				f.px(10 + k * 12, 20 + (k * 7) % 12, Color("f1c40f"))
		"training":
			PortraitScenes.hills(bg, 46, 10.0, Color("8aae78"), 3.3)
			PortraitScenes.ground_path(bg, 54, Color("d6c8a4"))
			for r in range(2):
				for k in range(4):
					var tx := 14 + k * 16
					var ty := 62 + r * 10
					man(f, tx, ty, [Color("6a2a2a"), Color("224870")][(k + r) % 2], "jeonlip", Vector2i(3, -4), Vector2i(5, -8), Vector2i(-2, 5), Vector2i(2, 5))
					f.line(tx + 7, ty - 4, tx + 7, ty - 26, Color("7a5230"), 1)
					f.poly(PackedVector2Array([Vector2(tx + 7, ty - 30), Vector2(tx + 9, ty - 25), Vector2(tx + 5, ty - 25)]), Color("b8c0c8"))
			PortraitScenes.flag(f, 70, 18, Color("c0392b"), 22)
		"bull_parade":
			PortraitScenes.hills(bg, 44, 12.0, Color("8aae78"), 0.9)
			PortraitScenes.grass(bg, 54, Color("86b45a"), Color("5a8844"))
			_cattle_body(f, 40, 66, 1.2, Color("c89a58"))
			f.rect(32, 34, 16, 14, Color("c0392b")) # 비단 안장
			f.rect(32, 34, 16, 2, Color("e8c040"))
			man(f, 40, 36, Color("2f67c0"), "sangmo", Vector2i(-6, -5), Vector2i(6, -5), Vector2i(-3, 3), Vector2i(3, 3))
			f.rect(6, 56, 10, 14, Color("c0392b"))
			f.rect(6, 56, 10, 2, Color("f1c40f"))
		"lion":
			PortraitScenes.hills(bg, 46, 10.0, Color("8aae78"), 2.5)
			PortraitScenes.ground_path(bg, 56, Color("d6c8a4"))
			# 사자 탈과 천 몸통
			f.ball(34, 42, 12, 11, Color("d8a020"))
			f.ball(34, 44, 9, 8, Color("c0392b"))
			f.ball(30, 40, 2.6, 2.6, Color("ffffff"))
			f.ball(38, 40, 2.6, 2.6, Color("ffffff"))
			f.px(30, 40, Color("1a1410"))
			f.px(38, 40, Color("1a1410"))
			f.rect(31, 48, 7, 3, Color("fbf0d0"))
			for k in range(7):
				f.line(22 + k * 3, 32, 20 + k * 3, 28 - (k & 1) * 2, Color("f0e8d0"))
			f.spoly(PackedVector2Array([Vector2(24, 50), Vector2(52, 50), Vector2(64, 70), Vector2(20, 70)]), Color("2f67c0"), 0.16, -0.3)
			for k in range(4):
				f.rect(28 + k * 8, 54, 4, 10, Color("e8c040"))
			man(f, 72, 70, Color("e8e0cc"), "sangmo", Vector2i(-3, -6), Vector2i(3, 2))
		"neolttwigi":
			PortraitScenes.hills(bg, 44, 12.0, Color("8aae78"), 0.6)
			PortraitScenes.grass(bg, 52, Color("78a458"), Color("5a8844"))
			PortraitScenes.stone_wall(bg, 0, 36, 80, 18, Color("b4a890"))
			bg.rect(0, 34, 80, 3, Color("8a6a40"))
			f.rect(36, 64, 8, 6, Color("8a6a40")) # 가마니 받침
			f.line(12, 64, 68, 54, Color("a87848"), 3) # 널
			woman(f, 14, 64, Color("e86a8a"), "braid", Vector2i(-5, 0), Vector2i(5, 0))
			woman(f, 62, 24, Color("3a9a8a"), "braid", Vector2i(-6, -4), Vector2i(6, -4))
		"swing":
			PortraitScenes.hills(bg, 50, 14.0, Color("6a8a70"), 1.2)
			PortraitScenes.grass(bg, 58, Color("78a458"), Color("5a8844"))
			f.rect(36, 4, 6, 62, Color("5a3a22"))
			f.ball(38, 8, 16, 8, Color("4a8a46"))
			f.ball(56, 14, 10, 6, Color("5a9a4a"))
			f.line(52, 10, 56, 52, Color("c0392b"), 1)
			f.line(66, 10, 62, 52, Color("c0392b"), 1)
			f.rect(54, 52, 10, 2, Color("8a6a40"))
			woman(f, 59, 52, Color("e86a8a"), "braid", Vector2i(-3, -5), Vector2i(3, -5))
			f.line(59, 36, 70, 36, Color("e86a8a"), 1)
		"namsadang":
			PortraitScenes.hills(bg, 46, 12.0, Color("8aae78"), 0.2)
			PortraitScenes.ground_path(bg, 60, Color("d6c8a4"))
			f.line(6, 36, 74, 36, Color("a07a48"), 2) # 줄
			f.rect(5, 36, 3, 28, Color("5a3a22"))
			f.rect(72, 36, 3, 28, Color("5a3a22"))
			man(f, 40, 36, Color("2f67c0"), "sangmo", Vector2i(-8, -2), Vector2i(8, -4), Vector2i(-4, 1), Vector2i(3, 5))
			f.line(48, 24, 48, 32, Color("5a3a22"))
			f.ell(48, 22, 5, 1.6, Color("efe8d8")) # 버나(접시 돌리기)
			f.line(32, 28, 34, 33, Color("e8c040"))
			for k in range(6):
				man(f, 12 + k * 11, 70, [Color("e8e0cc"), Color("c8d8c0"), Color("e8c8c0")][k % 3], ["gat", "topknot", "none"][k % 3], Vector2i(-2, 4), Vector2i(2, 4))
		"jeongisu":
			PortraitScenes.hills(bg, 46, 12.0, Color("8aae78"), 1.0)
			PortraitScenes.grass(bg, 56, Color("78a458"), Color("5a8844"))
			PortraitScenes.round_tree(f, 66, 56, 9, Color("4a8a46"))
			man(f, 38, 62, Color("7a5aa0"), "gat", Vector2i(-4, 2), Vector2i(5, -2), Vector2i(-2, 4), Vector2i(2, 4))
			f.rect(32, 46, 12, 8, Color("2a4a7a")) # 이야기책
			f.rect(32, 46, 2, 8, Color("1a3260"))
			f.rect(43, 47, 1, 6, Color("f2ead0"))
			for k in range(5):
				var lx := 8 + k * 14
				man(f, lx, 72 + (k & 1) * 2, [Color("e8e0cc"), Color("c8d8c0"), Color("e8c8c0"), Color("d8c8a8"), Color("e8e0cc")][k], ["topknot", "braid", "gat", "bun", "none"][k], Vector2i(-2, 3), Vector2i(2, 3))
			f.ball(30, 40, 3, 2, Color("f6f0e0")) # 말풍선
			f.ball(52, 38, 3, 2, Color("f6f0e0"))
		"pungmul":
			PortraitScenes.hills(bg, 46, 12.0, Color("8aae78"), 2.1)
			PortraitScenes.ground_path(bg, 56, Color("d6c8a4"))
			var cols2 := [Color("c0392b"), Color("2f67c0"), Color("e8c040"), Color("2ecc71"), Color("c0392b")]
			for k in range(5):
				man(f, 10 + k * 15, 64 + (k % 2) * 4, cols2[k], "sangmo", Vector2i(-3, 3), Vector2i(4, 2), Vector2i(-2, 5) if k % 2 == 0 else Vector2i(-3, 4), Vector2i(2, 5))
			f.ball(14, 52, 4, 4, Color("e8c040")) # 꽹과리
			f.ball(40, 56, 6, 5, Color("a8342a")) # 장구
			f.rect(36, 55, 8, 2, Color("e8d8a0"))
			f.ball(66, 52, 5, 5, Color("5a3a22")) # 북
			f.ball(66, 52, 3, 3, Color("efe8d8"))
			for k in range(8):
				f.line(8 + k * 9, 30, 6 + k * 9, 24 + (k & 1) * 3, Color("f4f0e0"))
		"talchum":
			PortraitScenes.hills(bg, 46, 12.0, Color("8aae78"), 3.0)
			PortraitScenes.ground_path(bg, 52, Color("d6c8a4"))
			# 하회탈 춤꾼: 긴 소매를 휘날린다
			f.ball(40, 28, 9, 10, Color("d8a85a"))
			f.rect(33, 25, 4, 2, Color("1a1410"))
			f.rect(43, 25, 4, 2, Color("1a1410"))
			f.rect(37, 34, 6, 2, Color("a8342a"))
			f.px(40, 31, Color("8a5a2a"))
			f.rect(31, 18, 18, 4, Color("1c1c26"))
			f.spoly(PackedVector2Array([Vector2(32, 40), Vector2(48, 40), Vector2(54, 70), Vector2(26, 70)]), Color("2f8a6a"), 0.18, -0.3)
			f.spoly(PackedVector2Array([Vector2(32, 42), Vector2(6, 34), Vector2(8, 44), Vector2(32, 52)]), Color("f4f0e0"), 0.1, -0.2)
			f.spoly(PackedVector2Array([Vector2(48, 42), Vector2(74, 50), Vector2(72, 60), Vector2(48, 52)]), Color("f4f0e0"), 0.1, -0.2)
			man(f, 10, 70, Color("e8e0cc"), "gat")
			man(f, 70, 70, Color("c8d8c0"), "topknot")
		"paengi":
			PortraitScenes.sky(bg, Color("c8dcec"), Color("f4f8fc"), 52)
			PortraitScenes.hills(bg, 46, 12.0, Color("a8b8c4"), 0.9)
			bg.rect(0, 54, 80, 26, Color("d8ecf8"))
			for k in range(10):
				bg.line((k * 31) % 70, 58 + (k * 7) % 18, (k * 31) % 70 + 6, 59 + (k * 7) % 18, Color("ffffff"))
			man(f, 22, 70, Color("5a7ab0"), "none", Vector2i(-3, -4), Vector2i(6, -6), Vector2i(-2, 4), Vector2i(2, 5))
			f.line(28, 64, 40, 68, Color("a07a48"))
			f.poly(PackedVector2Array([Vector2(38, 62), Vector2(46, 62), Vector2(42, 70)]), Color("c0392b"))
			f.rect(41, 58, 2, 4, Color("8a5a2a"))
			man(f, 58, 72, Color("e8c8c0"), "braid", Vector2i(-2, 4), Vector2i(4, 2))
			f.px(36, 64, Color("ffffff"))
			f.px(48, 66, Color("ffffff"))
		"taekkyeon":
			PortraitScenes.hills(bg, 46, 12.0, Color("8aae78"), 1.5)
			PortraitScenes.grass(bg, 54, Color("78a458"), Color("5a8844"))
			man(f, 24, 66, Color("2f67c0"), "headband", Vector2i(-6, -4), Vector2i(4, 0), Vector2i(-3, 5), Vector2i(4, 4))
			f.line(24, 61, 34, 56, WHITE, 2) # 쭉 뻗은 발차기 다리
			man(f, 56, 66, Color("c0392b"), "headband", Vector2i(-7, -2), Vector2i(3, -6), Vector2i(-2, 5), Vector2i(2, 5))
			for k in range(5):
				f.px(34 + k * 3, 52 + (k & 1) * 2, Color("f1c40f"))
		_:
			pass

static func _jwibul(f: PixelArt) -> void:
	# 깡통 불을 돌리는 아이들: 불 궤적 원
	for r in [8, 14]:
		for k in range(24):
			var ang := TAU * float(k) / 24.0
			var c := Color("f8c040") if k % 3 != 0 else Color("e8602a")
			f.px(int(26.0 + cos(ang) * float(r)), int(46.0 + sin(ang) * float(r) * 0.8), c)
	f.ball(34, 40, 3.5, 3.5, Color("f8d040"))
	f.ball(34, 40, 2, 2, Color("fff4c0"))
	f.ball(54, 38, 3.5, 3.5, Color("f8c040"))
	for p in [Vector2i(20, 30), Vector2i(60, 28), Vector2i(48, 24), Vector2i(12, 40)]:
		f.px(p.x, p.y, Color("ffd060"))
	man(f, 26, 66, Color("6a7ab0"), "topknot", Vector2i(-6, -5), Vector2i(7, -3), Vector2i(-2, 5), Vector2i(2, 5))
	man(f, 54, 66, Color("b07a6a"), "headband", Vector2i(-7, -5), Vector2i(5, -2), Vector2i(-2, 5), Vector2i(2, 5))
	man(f, 40, 70, Color("8a9a6a"), "none", Vector2i(-3, 3), Vector2i(4, -5))

static func _ganggang(f: PixelArt) -> void:
	# 달 아래 손에 손을 잡고 도는 한복 여인들(원근으로 눌린 원)
	var cols := [Color("e86a8a"), Color("3a9a8a"), Color("e8c040"), Color("8a5ab0"), Color("e86a8a"), Color("3a9a8a"), Color("e8a040"), Color("5a8ad0")]
	for k in range(8):
		var ang := TAU * float(k) / 8.0 + 0.4
		var px_ := int(40.0 + cos(ang) * 26.0)
		var py := int(60.0 + sin(ang) * 10.0)
		woman(f, px_, py, cols[k], "braid" if k % 2 == 0 else "bun", Vector2i(-4, 1) if k % 2 == 0 else Vector2i(-3, -2), Vector2i(4, 1))
	f.ell(40, 62, 26, 9, Color(1, 0.95, 0.7, 0.07))

# ─────────────────────────────────────────── 동물
static func _animal(f: PixelArt, key: String) -> void:
	match key:
		"tiger":
			_quad(f, 34, 62, 0.95, Color("e8902a"), Color("2a1a10"), true, "cat")
		"wolf":
			_quad(f, 34, 62, 0.9, Color("8a8e94"), Color("4a4e54"), false, "dog")
		"wild_boar":
			_quad(f, 34, 62, 0.9, Color("5a4638"), Color("2e2218"), false, "boar")
		"deer":
			_deer(f, 40, 64, 1.3)
		"rabbit":
			_rabbit(f)

## 네발짐승 옆모습(오른쪽을 본다). 무늬 stripes: 호랑이 줄무늬
static func _quad(f: PixelArt, cx: int, gy: int, s: float, base: Color, dark: Color, stripes: bool, kind: String) -> void:
	# 꼬리
	f.line(int(cx - 22.0 * s), int(gy - 20.0 * s), int(cx - 32.0 * s), int(gy - 12.0 * s), dark if kind != "cat" else base, 3)
	if kind == "cat":
		f.rect(int(cx - 33.0 * s), int(gy - 13.0 * s), 3, 3, dark)
	# 뒷다리 / 앞다리(몸 뒤)
	for lx in [-16.0, 14.0]:
		f.spoly(PackedVector2Array([Vector2(cx + lx * s - 3, gy - 22 * s), Vector2(cx + lx * s + 4, gy - 22 * s), Vector2(cx + lx * s + 3, gy), Vector2(cx + lx * s - 2, gy)]), PixelArt.shade(base, -0.2), 0.1, -0.3)
	# 몸통
	f.ball(float(cx), float(gy) - 24.0 * s, 22.0 * s, 11.0 * s, base)
	if kind == "boar":
		for k in range(10):
			f.line(int(cx - 18.0 * s + float(k) * 3.6 * s), int(gy - 35.0 * s), int(cx - 20.0 * s + float(k) * 3.6 * s), int(gy - 38.0 * s), dark)
	if kind == "cat":
		f.ell(cx, gy - 17.0 * s, 17.0 * s, 4.0 * s, Color("f4e8d0")) # 배
	for lx in [-12.0, 18.0]:
		f.spoly(PackedVector2Array([Vector2(cx + lx * s - 3, gy - 20 * s), Vector2(cx + lx * s + 4, gy - 20 * s), Vector2(cx + lx * s + 3, gy), Vector2(cx + lx * s - 2, gy)]), base, 0.12, -0.28)
		f.rect(int(cx + lx * s - 3), int(gy) - 2, 7, 3, dark if kind != "cat" else Color("f4e8d0"))
	if stripes:
		for k in range(7):
			var sx := cx - 18.0 * s + float(k) * 6.0 * s
			f.line(int(sx), int(gy - 33.0 * s), int(sx + 2), int(gy - 22.0 * s), dark, 2)
		for lx in [-12.0, 18.0, -16.0, 14.0]:
			f.line(int(cx + lx * s - 3), int(gy - 12 * s), int(cx + lx * s + 3), int(gy - 12 * s), dark)
	# 머리
	var hx := cx + int(24.0 * s)
	var hy := gy - int(30.0 * s)
	f.ball(float(hx), float(hy), 9.0 * s, 8.0 * s, base)
	# 귀
	var ear := Color("4a3a30") if kind != "cat" else dark
	f.poly(PackedVector2Array([Vector2(hx - 6, hy - 6 * s), Vector2(hx - 4, hy - 12 * s), Vector2(hx - 1, hy - 7 * s)]), base)
	f.poly(PackedVector2Array([Vector2(hx + 1, hy - 7 * s), Vector2(hx + 4, hy - 12 * s), Vector2(hx + 6, hy - 6 * s)]), base)
	f.px(hx - 4, int(hy - 9 * s), ear)
	f.px(hx + 4, int(hy - 9 * s), ear)
	# 주둥이
	f.ball(float(hx) + 5.0 * s, float(hy) + 3.0 * s, 5.0 * s, 3.4 * s, Color("f0e4d0") if kind != "boar" else Color("7a6050"))
	f.px(hx + int(9 * s), hy + 1, Color("1a1410"))
	if kind == "boar":
		f.poly(PackedVector2Array([Vector2(hx + 5, hy + 4), Vector2(hx + 9, hy + 7), Vector2(hx + 6, hy + 8)]), Color("f4efe0"))
	if kind == "dog" or kind == "cat":
		f.line(hx + 4, hy + 6, hx + 9, hy + 6, Color("7a2a20"))
		f.px(hx + 6, hy + 7, Color("f4f0e6"))
	# 눈
	f.rect(hx + 1, hy - 2, 3, 2, Color("f4d840") if kind != "boar" else Color("e8d8b0"))
	f.px(hx + 2, hy - 2, Color("1a1410"))
	f.px(hx + 2, hy - 3, Color("1a1410"))
	if stripes:
		f.line(hx - 4, hy - 4, hx - 2, hy, dark)
		f.line(hx, hy - 6, hx + 1, hy - 3, dark)

static func _deer(f: PixelArt, cx: int, gy: int, s: float) -> void:
	var base := Color("b8824a")
	for lx in [-9.0, -5.0, 8.0, 12.0]:
		f.line(int(cx + lx * s), int(gy - 16 * s), int(cx + lx * s) + 1, gy, PixelArt.shade(base, -0.15), 2)
		f.rect(int(cx + lx * s), gy - 1, 2, 2, Color("3a2a20"))
	f.ball(float(cx), float(gy) - 18.0 * s, 15.0 * s, 8.0 * s, base)
	for k in range(9):
		f.px(int(cx - 10.0 * s + float(k) * 2.4 * s), int(gy - 20.0 * s + float(k % 3) * 2.0 * s), Color("f4e8d0")) # 꽃무늬 점
	f.ell(cx, gy - 13.0 * s, 11.0 * s, 3.0 * s, Color("f0e4cc"))
	# 목과 머리
	f.poly(PackedVector2Array([Vector2(cx + 9 * s, gy - 22 * s), Vector2(cx + 14 * s, gy - 22 * s), Vector2(cx + 20 * s, gy - 36 * s), Vector2(cx + 15 * s, gy - 36 * s)]), base)
	var hx := cx + int(19.0 * s)
	var hy := gy - int(36.0 * s)
	f.ball(float(hx), float(hy), 6.0 * s, 4.6 * s, base)
	f.ball(float(hx) + 5.0 * s, float(hy) + 2.0 * s, 3.4 * s, 2.4 * s, Color("e8d8b8"))
	f.px(hx + int(8.0 * s), hy + 1, Color("1a1410"))
	f.px(hx + 1, hy - 1, Color("1a1410"))
	f.poly(PackedVector2Array([Vector2(hx - 3, hy - 3), Vector2(hx - 6, hy - 8), Vector2(hx - 1, hy - 4)]), base)
	# 뿔
	for dx in [-1, 2]:
		f.line(hx + dx, hy - 4, hx + dx - 2, hy - 12, Color("e8dcc0"), 1)
		f.line(hx + dx - 1, hy - 8, hx + dx + 2, hy - 11, Color("e8dcc0"), 1)
		f.line(hx + dx - 2, hy - 12, hx + dx, hy - 15, Color("e8dcc0"), 1)
	f.rect(int(cx - 17.0 * s), int(gy - 22.0 * s), 3, 3, Color("f4e8d0"))

static func _rabbit(f: PixelArt) -> void:
	var base := Color("e8e0d0")
	f.ball(34, 62, 14, 10, base)
	f.ball(52, 56, 8, 7, base)
	f.ball(24, 62, 4, 4, Color("f8f4ec")) # 꼬리
	# 긴 귀
	f.ell(50, 40, 2.6, 8, base)
	f.ell(56, 41, 2.6, 8, PixelArt.shade(base, -0.08))
	f.ell(50, 41, 1.2, 6, Color("f0b8b8"))
	f.ell(56, 42, 1.2, 6, Color("f0b8b8"))
	f.px(55, 55, Color("1a1410"))
	f.px(55, 54, Color("1a1410"))
	f.px(59, 58, Color("f0a0a0"))
	f.line(58, 60, 62, 59, Color("c8c0b0"))
	f.line(58, 61, 62, 63, Color("c8c0b0"))
	f.rect(44, 68, 6, 3, Color("d8d0c0"))
	f.rect(24, 70, 8, 3, Color("d8d0c0"))
	# 풀과 당근
	f.poly(PackedVector2Array([Vector2(60, 66), Vector2(66, 64), Vector2(62, 74)]), Color("e8782a"))
	f.line(66, 64, 69, 61, Color("5a9a4a"))
	f.line(65, 64, 66, 60, Color("5a9a4a"))

static func _crane(f: PixelArt) -> void:
	var white := Color("f6f4ee")
	# 몸통(가운데가 불룩) + 검은 꼬리깃
	f.ball(36, 44, 17, 8, white)
	f.spoly(PackedVector2Array([Vector2(18, 44), Vector2(8, 52), Vector2(10, 46), Vector2(22, 40)]), Color("2a2a32"))
	# 날개깃(접은 날개 끝 검정)
	f.spoly(PackedVector2Array([Vector2(26, 38), Vector2(48, 40), Vector2(40, 50), Vector2(22, 46)]), Color("e8e6e0"), 0.1, -0.2)
	f.line(24, 46, 40, 49, Color("2a2a32"), 2)
	# 긴 목과 머리
	f.line(48, 40, 56, 22, white, 3)
	f.line(56, 22, 56, 14, white, 3)
	f.ball(57, 12, 3.2, 3, white)
	f.ell(57, 9.5, 2.4, 1.4, Color("d03a2a")) # 단정(붉은 정수리)
	f.line(60, 13, 70, 15, Color("d8b040"), 2) # 부리
	f.px(58, 12, Color("1a1410"))
	f.line(55, 15, 54, 24, Color("2a2a32"))
	# 긴 다리
	f.line(34, 52, 34, 66, Color("c0b080"), 1)
	f.line(40, 52, 42, 66, Color("c0b080"), 1)
	f.line(32, 66, 38, 66, Color("c0b080"))
	f.line(40, 66, 46, 66, Color("c0b080"))
	# 소나무 가지
	f.line(0, 20, 22, 18, Color("4a3424"), 2)
	f.ball(10, 22, 7, 3, Color("2f6a3a"))
	f.ball(22, 20, 5, 3, Color("2f6a3a"))

static func _cattle_body(f: PixelArt, cx: int, gy: int, s: float, base: Color) -> void:
	for lx in [-15.0, -9.0, 9.0, 15.0]:
		f.spoly(PackedVector2Array([Vector2(cx + lx * s - 3, gy - 20 * s), Vector2(cx + lx * s + 3, gy - 20 * s), Vector2(cx + lx * s + 2, gy), Vector2(cx + lx * s - 2, gy)]), PixelArt.shade(base, -0.12), 0.1, -0.3)
		f.rect(int(cx + lx * s - 3), gy - 2, 6, 3, Color("3a2a20"))
	f.ball(float(cx), float(gy) - 24.0 * s, 24.0 * s, 12.0 * s, base)
	f.ball(float(cx) - 20.0 * s, float(gy) - 28.0 * s, 8.0 * s, 8.0 * s, PixelArt.shade(base, 0.03))
	f.line(int(cx - 26.0 * s), int(gy - 24.0 * s), int(cx - 30.0 * s), int(gy - 10.0 * s), Color("5a3a22"), 2)
	f.rect(int(cx - 31.0 * s), int(gy - 11.0 * s), 3, 4, Color("3a2a20"))

static func _cattle(f: PixelArt) -> void:
	var base := Color("c89a58")
	_cattle_body(f, 34, 66, 1.0, base)
	# 머리: 뿔과 코뚜레
	var hx := 62
	var hy := 40
	f.ball(float(hx), float(hy), 9, 8, base)
	f.ball(float(hx) + 5.0, float(hy) + 3.0, 6, 4.5, Color("e0c0a0"))
	f.px(hx + 9, hy + 4, Color("1a1410"))
	f.circle_ring(hx + 9, hy + 6, 2, Color("c8c8c8"))
	f.px(hx + 1, hy - 2, Color("1a1410"))
	f.line(hx - 3, hy - 6, hx - 8, hy - 12, Color("f0e8d0"), 2)
	f.line(hx + 3, hy - 6, hx + 8, hy - 12, Color("f0e8d0"), 2)
	f.poly(PackedVector2Array([Vector2(hx - 6, hy - 3), Vector2(hx - 11, hy), Vector2(hx - 6, hy + 2)]), PixelArt.shade(base, -0.15))
	f.rect(48, 30, 3, 14, Color("8a5a2a")) # 멍에
	f.line(48, 30, 58, 28, Color("8a5a2a"), 2)
	f.line(22, 66, 8, 60, Color("8a6a40"), 1)
	f.line(8, 60, 4, 70, Color("7a5230"), 2)
