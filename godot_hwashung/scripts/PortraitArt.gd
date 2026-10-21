extends RefCounted
class_name PortraitArt

## 살피기 팝업·길잡이용 도트 초상/일러스트(80x80). PixelArt로 코드에서 그리며 한 번 만들어 캐시한다.
## 표시할 때는 TextureRect/Control에 texture_filter = NEAREST로 2배(160px)로 키워 보여 줄 것.
## make(key)가 null이면 옛 그림(InspectNarrativeGenerator)으로 되돌아간다 — 키를 한 묶음씩 옮기는 중이다.

const S := 80
const INK := Color("1a1410")

static var _cache: Dictionary = {}
## 김판관 현재 단계(0 어벙 / 1 착실 / 2 엘리트). GuidePortrait가 학문력 변화에 맞춰 갱신한다.
static var kim_tier: int = 0

static func tier_for_accuracy(acc: float) -> int:
	if acc >= 90.0:
		return 2
	if acc >= 70.0:
		return 1
	return 0

static func make(key: String) -> ImageTexture:
	if _cache.has(key):
		return _cache[key]
	var tex: ImageTexture = null
	match key:
		"kim_pankwan":
			tex = kim(kim_tier)
		_:
			tex = _make_extra(key)
	if tex != null:
		_cache[key] = tex
	return tex

## 키별 확장 지점(뒤 단계에서 채운다)
static func _make_extra(key: String) -> ImageTexture:
	if PortraitLand.has(key):
		return PortraitLand.make(key)
	if PortraitPeople.has(key):
		return PortraitPeople.make(key)
	if PortraitScenes.has(key):
		return PortraitScenes.make(key)
	if PortraitFolk.has(key):
		return PortraitFolk.make(key)
	return null

# ─────────────────────────────────────────── 공통 조각
static func _finish(bg: PixelArt, fig: PixelArt, edge: Color, ring: Color) -> ImageTexture:
	fig.outline(INK)
	bg.blit(fig)
	# 둥근 틀 밖은 지우고 테두리를 다시 올린다
	var cx := float(S) * 0.5
	var cy := float(S) * 0.5
	var r := float(S) * 0.5 - 1.0
	for yy in range(S):
		for xx in range(S):
			var dx := float(xx) + 0.5 - cx
			var dy := float(yy) + 0.5 - cy
			var d := sqrt(dx * dx + dy * dy)
			if d > r:
				bg.img.set_pixel(xx, yy, Color(0, 0, 0, 0))
			elif d > r - 1.0:
				bg.img.set_pixel(xx, yy, edge)
			elif d > r - 3.0 and d <= r - 2.0:
				bg.img.set_pixel(xx, yy, ring)
	return bg.texture()

static func _sparkle(a: PixelArt, x: int, y: int, c: Color) -> void:
	a.px(x, y, c)
	a.px(x - 1, y, Color(c.r, c.g, c.b, 0.6))
	a.px(x + 1, y, Color(c.r, c.g, c.b, 0.6))
	a.px(x, y - 1, Color(c.r, c.g, c.b, 0.6))
	a.px(x, y + 1, Color(c.r, c.g, c.b, 0.6))

# ─────────────────────────────────────────── 김판관(수원부 판관): 학문력(추천 정확도)에 따라 세 모습
## tier 0 = 어벙(정확도 70 미만), 1 = 정직하고 착한(70 이상), 2 = 세련된 엘리트(90 이상)
static func kim(tier: int, talk: bool = false, blink: bool = false) -> ImageTexture:
	var key := "_kim_%d_%d_%d" % [tier, int(talk), int(blink)]
	if _cache.has(key):
		return _cache[key]
	var bg := PixelArt.new(S, S)
	var fig := PixelArt.new(S, S)
	var skin := Color("f1c9a0")
	var skin_sh := Color("d49f78")
	var ink := Color("231a14")
	var robe: Color
	var edge: Color
	var ring: Color
	match tier:
		0:
			robe = Color("55885f")
			bg.medallion(Color("f6ecd0"), Color("d8c79c"), Color("6b5a3a"), Color("a89870"))
			edge = Color("6b5a3a")
			ring = Color("a89870")
		1:
			robe = Color("2f7a58")
			bg.medallion(Color("fffbe6"), Color("c8dcb4"), Color("3f6b4f"), Color("8fb08a"))
			edge = Color("3f6b4f")
			ring = Color("8fb08a")
		_:
			robe = Color("1d5a63")
			bg.medallion(Color("f8e8b0"), Color("27407e"), Color("b8902a"), Color("ecc862"))
			edge = Color("b8902a")
			ring = Color("ecc862")
			for sp in [Vector2i(14, 20), Vector2i(64, 16), Vector2i(10, 46), Vector2i(68, 40), Vector2i(22, 10), Vector2i(58, 8), Vector2i(70, 58)]:
				_sparkle(bg, sp.x, sp.y, Color("fff2b8"))
			# 비단 구름무늬 줄
			for k in range(6):
				var ang := TAU * float(k) / 6.0 + 0.3
				bg.ell(40.0 + cos(ang) * 31.0, 40.0 + sin(ang) * 31.0, 2.5, 1.5, Color(0.93, 0.78, 0.35, 0.55))

	# ── 몸: 단령(둥근 깃 관복)
	var body := PackedVector2Array([Vector2(4, 80), Vector2(8, 65), Vector2(18, 57), Vector2(62, 57), Vector2(72, 65), Vector2(76, 80)])
	if tier == 0:
		# 헐렁한 옷: 어깨가 처지고 옷깃이 흘러내린다
		body = PackedVector2Array([Vector2(3, 80), Vector2(6, 68), Vector2(17, 60), Vector2(63, 60), Vector2(74, 68), Vector2(77, 80)])
	fig.spoly(body, robe, 0.16, -0.32)
	if tier == 0:
		for wr in [[22, 70, 27, 76], [54, 66, 50, 74], [14, 74, 18, 79], [64, 72, 66, 79]]:
			fig.line(wr[0], wr[1], wr[2], wr[3], PixelArt.shade(robe, -0.3))
	else:
		# 소매·가슴 주름을 가지런히
		fig.line(18, 66, 14, 79, PixelArt.shade(robe, -0.26))
		fig.line(62, 66, 66, 79, PixelArt.shade(robe, -0.34))
	# 목
	fig.rect(35, 48, 10, 13, skin_sh)
	fig.rect(35, 48, 3, 13, skin)
	# 깃(둥근 칼라)과 동정
	fig.ell(40, 61, 10, 5, PixelArt.shade(robe, -0.38))
	fig.ell(40, 59.5, 7, 3.5, skin_sh)
	for i in range(-9, 10):
		var yy := 61 + int(float(i * i) / 22.0)
		fig.px(40 + i, yy, Color("f2efe4"))
		fig.px(40 + i, yy + 1, PixelArt.shade(Color("f2efe4"), -0.18))

	# ── 흉배(가슴의 수놓은 판)
	var hb := Rect2i(29, 65, 22, 13)
	var border := Color("c9a73f")
	if tier == 0:
		border = Color("8d7a4a")
	elif tier == 2:
		border = Color("f0cb52")
	fig.rect(hb.position.x, hb.position.y, hb.size.x, hb.size.y, Color("1f3a70") if tier != 2 else Color("1a2f66"))
	fig.rect(hb.position.x, hb.position.y, hb.size.x, 1, border)
	fig.rect(hb.position.x, hb.position.y + hb.size.y - 1, hb.size.x, 1, border)
	fig.rect(hb.position.x, hb.position.y, 1, hb.size.y, border)
	fig.rect(hb.position.x + hb.size.x - 1, hb.position.y, 1, hb.size.y, border)
	if tier == 2:
		fig.rect(hb.position.x + 2, hb.position.y + 2, hb.size.x - 4, 1, Color("b8342a"))
		fig.rect(hb.position.x + 2, hb.position.y + hb.size.y - 3, hb.size.x - 4, 1, Color("b8342a"))
	var white := Color("f4f1e8")
	if tier == 0:
		fig.ell(39, 72, 4.5, 3, white)
		fig.px(43, 68, white)
		fig.px(44, 67, Color("c0392b"))
	else:
		var crane_ofs: Array = [Vector2i(0, 0)] if tier == 1 else [Vector2i(-5, 1), Vector2i(5, 1)]
		for co: Vector2i in crane_ofs:
			var dir := 1 if (tier == 1 or co.x < 0) else -1
			var bx := 40 + co.x
			var by := 72 + co.y
			fig.ell(bx, by, 3.5 if tier == 2 else 4.5, 2.4, white)
			fig.px(bx - dir * 4, by, Color("2a2a36"))
			fig.px(bx - dir * 4, by + 1, Color("2a2a36"))
			fig.line(bx + dir * 3, by - 1, bx + dir * 4, by - 4, white, 1)
			fig.px(bx + dir * 4, by - 5, white)
			fig.px(bx + dir * 4, by - 6, Color("c0392b"))
			fig.px(bx + dir * 5, by - 5, Color("e8c040"))
			fig.px(bx - 1, by + 3, Color("c9a73f"))
			fig.px(bx + 1, by + 3, Color("c9a73f"))
		if tier == 2:
			fig.ell(40, 69, 2.2, 2.2, Color("d6452f"))
			for cx2 in [32, 48]:
				fig.px(cx2, 68, Color("e8d890"))
				fig.px(cx2 + 1, 67, Color("e8d890"))

	# ── 머리(따로 그려 몸 위에 얹는다 — 목을 짧게 하려고 3칸 내려서 겹친다)
	var body_fig := fig
	fig = PixelArt.new(S, S)
	var hx := 40.0
	var hy := 35.0
	var rx := 12.5
	if tier == 2:
		rx = 11.5
	fig.soft_ball(hx, hy, rx, 14.5, skin)
	if tier == 2:
		# 갸름한 턱선
		fig.poly(PackedVector2Array([Vector2(31, 42), Vector2(49, 42), Vector2(42, 51), Vector2(38, 51)]), skin)
	# 귀
	fig.soft_ball(hx - rx - 0.5, 37, 2.0, 3.2, skin)
	fig.soft_ball(hx + rx + 0.5, 37, 2.0, 3.2, skin)
	fig.px(int(hx - rx - 1), 37, skin_sh)
	fig.px(int(hx + rx), 37, skin_sh)

	# ── 표정
	match tier:
		0:
			# 처진 팔자 눈썹(걱정스런 얼굴), 동그란 눈이 서로 다른 데를 본다
			for b in [[30, 33, 36, 30], [44, 30, 50, 33]]:
				fig.line(b[0], b[1], b[2], b[3], Color("4a3a2a"), 1)
			for ex in [34, 46]:
				fig.rect(ex - 2, 35, 5, 5, Color("fbf8ee"))
				fig.rect(ex - 2, 34, 5, 1, Color("b98f6a"))
			fig.rect(33, 37, 2, 2, ink)
			fig.px(33, 37, Color.WHITE)
			fig.rect(47, 35, 2, 2, ink)
			fig.px(47, 35, Color.WHITE)
			# 꿀꺽 삼킨 듯한 벌린 입, 앞니
			fig.rect(37, 45, 6, 4, Color("7a2a20"))
			fig.rect(38, 45, 4, 1, Color("f6f0e0"))
			fig.rect(38, 48, 3, 1, Color("e07a7a"))
			# 상기된 볼, 먹물 자국, 식은땀
			fig.rect(28, 41, 4, 3, Color(1.0, 0.45, 0.45, 0.55))
			fig.rect(48, 41, 4, 3, Color(1.0, 0.45, 0.45, 0.55))
			fig.rect(31, 38, 2, 1, Color("3a2e26"))
			fig.px(30, 39, Color("3a2e26"))
			fig.rect(54, 30, 2, 3, Color("9fd0f0"))
			fig.px(55, 33, Color("9fd0f0"))
			fig.px(54, 30, Color("e8f6ff"))
		1:
			for b in [[30, 32, 36, 31], [44, 31, 50, 32]]:
				fig.line(b[0], b[1], b[2], b[3], Color("3a2c20"), 1)
			for ex in [34, 46]:
				fig.rect(ex - 1, 35, 3, 4, ink)
				fig.px(ex - 1, 35, Color.WHITE)
				fig.rect(ex - 2, 34, 5, 1, Color("5a4030"))
			# 환한 미소
			fig.line(36, 44, 38, 46, Color("7a2a20"))
			fig.line(38, 46, 42, 46, Color("7a2a20"))
			fig.line(42, 46, 44, 44, Color("7a2a20"))
			fig.rect(28, 41, 4, 3, Color(1.0, 0.5, 0.5, 0.32))
			fig.rect(48, 41, 4, 3, Color(1.0, 0.5, 0.5, 0.32))
		_:
			for b in [[29, 30, 31, 30], [31, 31, 36, 32], [44, 32, 49, 31], [49, 30, 51, 30]]:
				fig.line(b[0], b[1], b[2], b[3], Color("241a14"), 1)
			for ex in [34, 46]:
				fig.rect(ex - 2, 35, 5, 3, Color("fbf8ee"))
				fig.rect(ex - 1, 35, 3, 3, ink)
				fig.px(ex, 35, Color("5a7ab0"))
				fig.rect(ex - 3, 34, 7, 1, Color("1a1410"))
				fig.px(ex + (3 if ex > 40 else -3), 35, Color("1a1410"))
			# 눈 밑 음영으로 총기, 한쪽 입꼬리를 올린 자신감
			fig.rect(31, 39, 5, 1, Color(0.6, 0.4, 0.3, 0.35))
			fig.rect(44, 39, 5, 1, Color(0.6, 0.4, 0.3, 0.35))
			fig.line(37, 46, 42, 46, Color("7a2a20"))
			fig.px(43, 45, Color("7a2a20"))
			fig.px(44, 44, Color("7a2a20"))
	# 코
	fig.px(40, 40, skin_sh)
	fig.px(40, 41, skin_sh)
	fig.px(41, 41, skin_sh)
	fig.px(39, 39, PixelArt.shade(skin, 0.3))

	# ── 수염
	match tier:
		0:
			for p in [Vector2i(35, 43), Vector2i(34, 44), Vector2i(45, 43), Vector2i(46, 44), Vector2i(38, 51), Vector2i(41, 52), Vector2i(43, 50)]:
				fig.px(p.x, p.y, Color("3a3a3a"))
		1:
			fig.spoly(PackedVector2Array([Vector2(32, 42), Vector2(39, 41), Vector2(39, 44), Vector2(33, 45)]), Color("2f2f2f"))
			fig.spoly(PackedVector2Array([Vector2(48, 42), Vector2(41, 41), Vector2(41, 44), Vector2(47, 45)]), Color("2f2f2f"))
			fig.ball(40, 51, 5.5, 4.5, Color("333333"))
			fig.rect(36, 47, 8, 2, Color("333333"))
		_:
			fig.line(32, 43, 38, 42, Color("22222a"))
			fig.line(48, 43, 42, 42, Color("22222a"))
			fig.px(31, 44, Color("22222a"))
			fig.px(49, 44, Color("22222a"))
			fig.poly(PackedVector2Array([Vector2(37, 48), Vector2(43, 48), Vector2(41, 59), Vector2(40, 61), Vector2(39, 59)]), Color("26262e"))
			fig.px(38, 50, Color("8a8a98"))
			fig.px(39, 53, Color("8a8a98"))

	# ── 사모(紗帽): 둥근 모정과 양옆 뿔(각)
	var tilt := 2 if tier == 0 else 0
	var hat := Color("1c1c26")
	var crown := PackedVector2Array([Vector2(30 + tilt, 28), Vector2(31 + tilt * 2, 13), Vector2(35 + tilt * 2, 8), Vector2(45 + tilt * 2, 8), Vector2(49 + tilt * 2, 13), Vector2(50 + tilt, 28)])
	if tier == 0:
		# 삐딱하게 얹은 사모: 오른쪽 뿔은 쳐들리고 왼쪽 뿔은 처진다
		fig.spoly(PackedVector2Array([Vector2(31, 25), Vector2(8, 28), Vector2(7, 31), Vector2(31, 29)]), Color("14141b"))
		fig.spoly(PackedVector2Array([Vector2(51, 22), Vector2(71, 15), Vector2(72, 18), Vector2(51, 26)]), Color("14141b"))
	else:
		var wy := 21
		fig.spoly(PackedVector2Array([Vector2(30, wy), Vector2(6 if tier == 2 else 9, wy - 1), Vector2(6 if tier == 2 else 9, wy + 2), Vector2(30, wy + 4)]), Color("14141b"))
		fig.spoly(PackedVector2Array([Vector2(50, wy), Vector2(74 if tier == 2 else 71, wy - 1), Vector2(74 if tier == 2 else 71, wy + 2), Vector2(50, wy + 4)]), Color("14141b"))
	fig.spoly(crown, hat, 0.3, -0.2)
	fig.rect(29 + tilt, 25, 22, 3, Color("2e2e3c"))
	if tier == 2:
		fig.rect(29, 25, 22, 1, Color("e8c040"))
		fig.ball(40, 16, 2.5, 2.5, Color("57c0a8"))
		fig.px(39, 15, Color.WHITE)
	elif tier == 1:
		fig.rect(29, 25, 22, 1, Color("b89a40"))

	# 머리를 몸 위로(윤곽선은 합친 뒤 한 번에)
	body_fig.blit(fig, 0, 3)
	fig = body_fig
	# ── 손에 든 것
	if tier == 0:
		# 거꾸로 든 두루마리와 번진 먹
		fig.rect(10, 66, 6, 14, Color("e8dcb8"))
		fig.rect(10, 66, 1, 14, Color("fff4d0"))
		fig.rect(15, 66, 1, 14, Color("b8a880"))
		fig.rect(9, 64, 8, 2, Color("8a6a3a"))
		fig.rect(12, 70, 2, 3, Color("2a2a2a"))
		fig.ball(13, 78, 3, 2.4, skin)
	elif tier == 2:
		# 상아 홀(笏)을 쥐다
		fig.spoly(PackedVector2Array([Vector2(56, 62), Vector2(61, 60), Vector2(63, 76), Vector2(58, 78)]), Color("f0ead6"), 0.1, -0.25)
		fig.ball(59, 72, 3.2, 2.8, skin)

	# 말하는 입·눈 깜빡임(애니메이션 프레임)
	if blink:
		for ex in [34, 46]:
			fig.rect(ex - 3, 36, 7, 7, skin)
			fig.rect(ex - 2, 40, 5, 1, ink)
	if talk:
		fig.rect(37, 47, 6, 4, Color("7a2a20"))
		fig.rect(38, 50, 4, 1, Color("d86a6a"))
		if tier == 1:
			fig.rect(38, 47, 4, 1, Color("f6f0e0"))
	return _finish_cache(key, bg, fig, edge, ring)

static func _finish_cache(key: String, bg: PixelArt, fig: PixelArt, edge: Color, ring: Color) -> ImageTexture:
	var tex := _finish(bg, fig, edge, ring)
	_cache[key] = tex
	return tex
