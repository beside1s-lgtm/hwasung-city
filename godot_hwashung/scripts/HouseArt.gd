extends RefCounted
class_name HouseArt

## PORT-TRACE [민가 등급·외형 변형]: 사용자가 보낸 "정조시대 민가·부호의 집" 도판(1x1 초가 1A~1E, 1x1 기와집
## 1F~1I, 1x2 ㄱ자 기와집 2A~2C, 2x2 대부호의 집 6A·6B·6C·9C)의 양식을 절차적 드로잉으로 옮겼다.
## 에셋은 등급(tier) x 외형(variant) 표로 정리해 두었다 — 나중에 스프라이트로 바꾸고 싶으면 이 표의 id에
## 그림만 대응시키면 된다(HOUSE_VARIANTS). 그리는 좌표계는 MarketArt와 같다(길 쪽이 앞, 화면 회전 대응).

## 등급별 외형 목록(데이터 구조). tier: 1=초가(res_1), 2=기와집(res_2 단독), 3=1x2 기와집(res_2 그룹), 4=2x2 부호의 집(res_3)
const HOUSE_VARIANTS := {
	1: [
		{"id": "1A", "name": "싸리울 초가"}, {"id": "1B", "name": "텃밭 초가"}, {"id": "1C", "name": "빨래·곶감 걸이 초가"},
		{"id": "1D", "name": "장독 초가"}, {"id": "1E", "name": "장작 쌓은 초가"},
		{"id": "1J", "name": "닭장 초가"}, {"id": "1K", "name": "고추 말리는 초가"}, {"id": "1L", "name": "감나무 초가"},
	],
	2: [
		{"id": "1F", "name": "ㄱ자 기와집"}, {"id": "1G", "name": "흙마당 기와집"}, {"id": "1H", "name": "디딤돌 기와집"}, {"id": "1I", "name": "담장 기와집"},
		{"id": "1M", "name": "툇마루 화분 기와집"}, {"id": "1N", "name": "대문 기와집"},
	],
	3: [
		{"id": "2A", "name": "연못 정원 기와집"}, {"id": "2B", "name": "장독 마당 기와집"}, {"id": "2C", "name": "대문 달린 기와집"},
	],
	4: [
		{"id": "6A", "name": "연못·소나무 정원 저택"}, {"id": "6B", "name": "장독대 마당 저택"}, {"id": "6C", "name": "누각 딸린 저택"}, {"id": "9C", "name": "괴석·전나무 정원 저택"},
	],
	# PORT-TRACE [3x3 거상 대저택]: 기와집 아홉 채 자리가 모두 입지 80 이상이면 합쳐진다(res_3, hgroup 3x3)
	5: [
		{"id": "10A", "name": "연못 정자 거상 대저택"}, {"id": "10B", "name": "곳간·장독대 거상 대저택"},
	],
}

const GIWA := Color("3e4550")
const TIMBER_WALL := Color("c49a6a")
const PLASTER := Color("ece2cc")
const GRASS := Color("78a24e")
const DIRT := Color("c2a878")
const STONE := Color("a8a298")

static func P(o: Vector2, a: Vector2, f: Vector2, u: float, v: float, h: float = 0.0) -> Vector2:
	return o + a * u + f * v - Vector2(0, h)

static func ground(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, col: Color, k: float = 0.92) -> void:
	MarketArt.draw_safe_quad(ci, P(o, a, f, -k, -k), P(o, a, f, k, -k), P(o, a, f, k, k), P(o, a, f, -k, k), col)

## 집 한 채: 벽(나무 + 회벽) + 보이는 앞면에 문·창살 + 지붕. a를 따라 긴 집.
static func house(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, bu: float, bv: float, h: float, thatch: bool,
		ridge_u: float = -1.0, tiers: int = 1) -> void:
	MarketArt.box(ci, o, a, f, bu, bv, 0.0, h, TIMBER_WALL if not thatch else Color("cfae7c"))
	# 앞면(f 쪽)이 화면을 향하면 문·창을 그린다
	for side: float in [1.0, -1.0]:
		var fv := f * side
		if fv.y <= 0.0:
			continue
		var y0 := 2.0
		var y1 := h - 2.0
		# 가운데 문(어두운 판) + 양쪽 창살
		var d0 := P(o, a, f * side, -bu * 0.15, bv, y0 - 2.0)
		var d1 := P(o, a, f * side, bu * 0.15, bv, y0 - 2.0)
		MarketArt.draw_safe_quad(ci, d0, d1, d1 - Vector2(0, y1 - y0 + 1.0), d0 - Vector2(0, y1 - y0 + 1.0), Color("5a3a22"))
		for wu: float in [-bu * 0.6, bu * 0.6]:
			var w0 := P(o, a, f * side, wu - bu * 0.18, bv, y0 + 1.0)
			var w1 := P(o, a, f * side, wu + bu * 0.18, bv, y0 + 1.0)
			var hh := (y1 - y0) * 0.55
			MarketArt.draw_safe_quad(ci, w0, w1, w1 - Vector2(0, hh), w0 - Vector2(0, hh), PLASTER)
			ci.draw_line(w0.lerp(w1, 0.5), w0.lerp(w1, 0.5) - Vector2(0, hh), Color("7a5a3a"), 0.6)
			ci.draw_line(w0 - Vector2(0, hh * 0.5), w1 - Vector2(0, hh * 0.5), Color("7a5a3a"), 0.6)
		break
	var ru := bu + 0.18
	var rv := bv + 0.2
	var rr := ridge_u if ridge_u >= 0.0 else bu * 0.55
	if thatch:
		MarketArt.roof(ci, o, a, f, ru, rv, rr * 0.5, h - 1.0, h + 7.0, MarketArt.THATCH, true)
	else:
		MarketArt.roof(ci, o, a, f, ru, rv, rr, h - 1.0, h + 8.0, GIWA)
		if tiers >= 2:
			MarketArt.box(ci, o, a, f, bu * 0.55, bv * 0.6, h + 4.0, h + 9.0, TIMBER_WALL)
			MarketArt.roof(ci, o, a, f, bu * 0.75, bv + 0.05, rr * 0.6, h + 8.0, h + 15.0, GIWA)

static func pine(ci: CanvasItem, p: Vector2, s: float = 1.0) -> void:
	FastDraw.circle(ci, p + Vector2(1.5, 1), 3.5 * s, Color(0, 0, 0, 0.2))
	ci.draw_line(p, p + Vector2(-1, -9 * s), Color("5e3a22"), 1.6)
	FastDraw.circle(ci, p + Vector2(-3 * s, -8 * s), 3.2 * s, Color("2e5e30"))
	FastDraw.circle(ci, p + Vector2(3 * s, -10 * s), 3.0 * s, Color("356a36"))
	FastDraw.circle(ci, p + Vector2(0, -13 * s), 3.2 * s, Color("3f7a3e"))

static func round_tree(ci: CanvasItem, p: Vector2) -> void:
	ci.draw_line(p, p + Vector2(0, -6), Color("5e3a22"), 1.6)
	FastDraw.circle(ci, p + Vector2(0, -10), 5.0, Color("3f8a3a"))
	FastDraw.circle(ci, p + Vector2(-1.5, -11.5), 2.5, Color("5aa84a"))

static func conifer(ci: CanvasItem, p: Vector2) -> void:
	ci.draw_line(p, p + Vector2(0, -3), Color("5e3a22"), 1.4)
	FastDraw.poly(ci, PackedVector2Array([p + Vector2(-4, -3), p + Vector2(4, -3), p + Vector2(0, -16)]), Color("2c6a3a"))

static func pond(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, u: float, v: float, r: float) -> void:
	var pts := PackedVector2Array()
	for i in range(12):
		var ang := TAU * float(i) / 12.0
		pts.append(P(o, a, f, u + cos(ang) * r, v + sin(ang) * r * 0.8))
	FastDraw.poly(ci, pts, Color("4a8fb0"))
	FastDraw.polyline(ci, pts + PackedVector2Array([pts[0]]), STONE, 1.2)
	ci.draw_line(P(o, a, f, u - r * 0.4, v), P(o, a, f, u + r * 0.2, v - 0.05), Color("8fc4d8"), 0.8)

static func rocks(ci: CanvasItem, p: Vector2) -> void:
	for off: Vector2 in [Vector2(-3, 0), Vector2(2, 1), Vector2(0, -2)]:
		FastDraw.circle(ci, p + off, 1.8, Color("8f8a80"))
		FastDraw.circle(ci, p + off + Vector2(-0.5, -0.6), 0.8, Color("b8b2a8"))

static func stepping_stones(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, u: float, v0: float, v1: float) -> void:
	for k in range(4):
		var v := lerpf(v0, v1, float(k) / 3.0)
		FastDraw.circle(ci, P(o, a, f, u + (0.06 if k % 2 == 0 else -0.06), v), 1.6, STONE)

## 싸리 울타리(초가)
static func brush_fence(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2) -> void:
	var col := Color("9a7a4a")
	var corners: Array[Vector2] = [P(o, a, f, -0.88, -0.88), P(o, a, f, 0.88, -0.88), P(o, a, f, 0.88, 0.88), P(o, a, f, -0.88, 0.88)]
	for i in range(4):
		var p0: Vector2 = corners[i]
		var p1: Vector2 = corners[(i + 1) % 4]
		var gap := i == 2 # 앞쪽(v=+) 가운데에 사립문 자리
		for k in range(9):
			var t := float(k) / 8.0
			if gap and t > 0.35 and t < 0.65:
				continue
			var q := p0.lerp(p1, t)
			ci.draw_line(q, q - Vector2(0, 4), col, 0.9)
		ci.draw_line(p0 - Vector2(0, 3), p1 - Vector2(0, 3), col.darkened(0.2), 0.7)

## 솟을대문(작은 기와 대문) — 앞 담장 위치(u, v=0.9)
static func gate(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, u: float) -> void:
	var go := o + a * u + f * 0.9
	MarketArt.box(ci, go, a, f, 0.2, 0.08, 0.0, 9.0, Color("7a3a24"))
	MarketArt.roof(ci, go, a, f, 0.3, 0.16, 0.15, 8.0, 13.0, GIWA)

## 담장: 그룹(또는 단독) 둘레 중 outer[k]가 참인 모서리. 0=뒤,1=앞,2=왼,3=오른. 앞 담장은 따로(맨 나중) 그린다.
static func back_side_walls(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, outer: Array) -> void:
	# 화면 뒤쪽 담장부터
	var segs: Array = []
	if outer[0]:
		segs.append({"y": P(o, a, f, 0.0, -0.92).y, "u0": -0.95, "u1": 0.95, "v": -0.92, "along_v": false})
	if outer[2]:
		segs.append({"y": P(o, a, f, -0.92, 0.0).y, "u0": -0.95, "u1": 0.95, "v": -0.92, "along_v": true})
	if outer[3]:
		segs.append({"y": P(o, a, f, 0.92, 0.0).y, "u0": -0.95, "u1": 0.95, "v": 0.92, "along_v": true})
	segs.sort_custom(func(p, q): return p["y"] < q["y"])
	for sg in segs:
		MarketArt.wall_seg(ci, o, a, f, sg["u0"], sg["u1"], sg["v"], 7.0, sg["along_v"])

static func front_wall(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, gate_u: float) -> void:
	if gate_u > 5.0:
		MarketArt.wall_seg(ci, o, a, f, -0.95, 0.95, 0.92, 7.0)
		return
	if gate_u - 0.22 > -0.95:
		MarketArt.wall_seg(ci, o, a, f, -0.95, gate_u - 0.22, 0.92, 7.0)
	if gate_u + 0.22 < 0.95:
		MarketArt.wall_seg(ci, o, a, f, gate_u + 0.22, 0.95, 0.92, 7.0)
	gate(ci, o, a, f, gate_u)

# ---------------------------------------------------------------- 단독 민가
static func draw_single(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, tier: int, variant: int) -> void:
	if tier <= 1:
		ground(ci, o, a, f, DIRT)
		var ob := o + f * -0.3 + a * -0.1
		match variant % HOUSE_VARIANTS[1].size():
			0: # 1A 싸리울 초가
				brush_fence(ci, o, a, f)
				house(ci, ob, a, f, 0.5, 0.3, 8.0, true)
			1: # 1B 텃밭 초가
				MarketArt.draw_safe_quad(ci, P(o, a, f, 0.2, 0.25), P(o, a, f, 0.85, 0.25), P(o, a, f, 0.85, 0.85), P(o, a, f, 0.2, 0.85), Color("6a5236"))
				for k in range(4):
					var v := 0.33 + k * 0.15
					ci.draw_line(P(o, a, f, 0.25, v), P(o, a, f, 0.8, v), Color("5aa040"), 1.4)
				house(ci, ob, a, f, 0.5, 0.3, 8.0, true)
			2: # 1C 빨래·곶감 걸이
				house(ci, ob, a, f, 0.5, 0.3, 8.0, true)
				var r0 := P(o, a, f, 0.1, 0.6)
				var r1 := P(o, a, f, 0.8, 0.6)
				ci.draw_line(r0, r0 - Vector2(0, 11), MarketArt.TIMBER, 1.1)
				ci.draw_line(r1, r1 - Vector2(0, 11), MarketArt.TIMBER, 1.1)
				ci.draw_line(r0 - Vector2(0, 10), r1 - Vector2(0, 10), Color("d8cfb8"), 0.6)
				for k in range(5):
					var q := (r0 - Vector2(0, 10)).lerp(r1 - Vector2(0, 10), 0.15 + k * 0.17)
					FastDraw.circle(ci, q + Vector2(0, 2), 1.1, Color("e0702a") if k % 2 == 0 else Color("f4f0e4"))
			3: # 1D 장독 초가
				house(ci, ob, a, f, 0.5, 0.3, 8.0, true)
				MarketArt.jars(ci, P(o, a, f, 0.55, 0.55), 4)
				MarketArt.draw_safe_tri(ci, P(o, a, f, -0.7, 0.5), P(o, a, f, -0.4, 0.5), P(o, a, f, -0.55, 0.3, 6.0), MarketArt.THATCH.darkened(0.1))
			4: # 1E 장작 쌓은 초가
				house(ci, ob, a, f, 0.5, 0.3, 8.0, true)
				for k in range(3):
					ci.draw_line(P(o, a, f, 0.35, 0.55, 1.0 + k * 1.6), P(o, a, f, 0.8, 0.55, 1.0 + k * 1.6), Color("8a5a32"), 1.6)
				MarketArt.mat(ci, o, a, f, -0.4, 0.6, 0.3, 0.2)
			5: # 1J 닭장 초가: 작은 초가 닭장 + 마당의 닭
				house(ci, ob, a, f, 0.5, 0.3, 8.0, true)
				var co := o + a * 0.55 + f * 0.45
				MarketArt.box(ci, co, a, f, 0.18, 0.14, 0.0, 4.0, Color("b89a6a"))
				MarketArt.roof(ci, co, a, f, 0.26, 0.22, 0.05, 4.0, 7.0, MarketArt.THATCH, true)
				for k in range(3):
					var hp := P(o, a, f, -0.3 + k * 0.2, 0.6 + (k % 2) * 0.1)
					FastDraw.circle(ci, hp, 1.4, Color("f4f0e4"))
					FastDraw.circle(ci, hp + Vector2(1.2, -1.2), 0.6, Color("c0392b"))
			6: # 1K 고추 말리는 초가: 멍석 위 빨간 고추
				house(ci, ob, a, f, 0.5, 0.3, 8.0, true)
				MarketArt.mat(ci, o, a, f, 0.1, 0.58, 0.45, 0.22)
				for k in range(10):
					FastDraw.circle(ci, P(o, a, f, -0.25 + float(k % 5) * 0.17, 0.5 + (float(k) / 5.0) * 0.15), 0.9, Color("c8281e"))
			_: # 1L 감나무 초가: 마당의 감나무(주황 감) + 앞 사립문 울
				house(ci, ob, a, f, 0.5, 0.3, 8.0, true)
				var tp := P(o, a, f, 0.6, 0.45)
				round_tree(ci, tp)
				for k in range(5):
					FastDraw.circle(ci, tp + Vector2(-3.5 + k * 1.8, -10.0 + float(k % 2) * 2.5), 0.9, Color("f08a24"))
		return
	# 기와집 1F~1I
	ground(ci, o, a, f, GRASS)
	var ob2 := o + f * -0.3
	match variant % HOUSE_VARIANTS[2].size():
		0: # 1F ㄱ자
			house(ci, ob2 + a * -0.1, a, f, 0.55, 0.3, 10.0, false)
			house(ci, o + a * 0.55 + f * 0.15, f, a, 0.35, 0.22, 9.0, false)
			MarketArt.jars(ci, P(o, a, f, -0.5, 0.65), 3)
		1: # 1G 흙마당
			ground(ci, o + f * 0.45, a, f * 0.5, DIRT, 0.8)
			house(ci, ob2, a, f, 0.62, 0.32, 10.0, false)
			MarketArt.jars(ci, P(o, a, f, 0.6, 0.6), 3)
		2: # 1H 디딤돌
			house(ci, ob2, a, f, 0.62, 0.32, 10.0, false)
			stepping_stones(ci, o, a, f, 0.0, 0.2, 0.85)
			rocks(ci, P(o, a, f, 0.6, 0.6))
		3: # 1I 담장 + 나무
			back_side_walls(ci, o, a, f, [true, false, true, true])
			house(ci, ob2, a, f, 0.58, 0.3, 10.0, false)
			round_tree(ci, P(o, a, f, -0.6, 0.55))
		4: # 1M 툇마루 화분: 집 앞 툇마루 + 꽃 화분 줄
			house(ci, ob2, a, f, 0.62, 0.32, 10.0, false)
			var pots: Array[Color] = [Color("e05080"), Color("e8c040"), Color("c0392b"), Color("f4f0e4")]
			for k in range(4):
				var pp := P(o, a, f, -0.5 + k * 0.33, 0.45)
				FastDraw.circle(ci, pp, 1.6, Color("8a5a38"))
				FastDraw.circle(ci, pp + Vector2(0, -2), 1.4, pots[k])
		_: # 1N 대문 기와집: 사방 담장 + 작은 대문
			back_side_walls(ci, o, a, f, [true, false, true, true])
			house(ci, ob2, a, f, 0.58, 0.3, 10.0, false)
			front_wall(ci, o, a, f, 0.3)

# ---------------------------------------------------------------- 그룹 민가(1x2 기와집, 2x2 부호의 집)
## gi: 좌우 순번(0..W-1), gj: 앞뒤 순번(0=뒤 .. D-1=앞), outer: [뒤, 앞, 왼, 오른]이 그룹 바깥 모서리인가
static func draw_group_part(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, gi: int, gj: int, W: int, D: int,
		variant: int, outer: Array) -> void:
	var fancy_ground := GRASS if variant % 2 == 0 else DIRT
	ground(ci, o, a, f, fancy_ground, 0.98)
	back_side_walls(ci, o, a, f, outer)
	var front_row := gj == D - 1
	var gate_u := 99.0
	if W == 3:
		if front_row and gi == 1:
			gate_u = 0.0 # 거상 대저택: 앞줄 가운데 솟을대문
	elif front_row and gi == W - 1:
		gate_u = 0.35 if W > 1 else 0.45
	if W == 3 and D == 3:
		_mansion_3x3(ci, o, a, f, gi, gj, variant)
	elif D == 1:
		# ---- 1x2(길과 나란히 두 칸): ㄱ자 기와집 + 앞마당
		if gi == 0:
			house(ci, o + a * 0.14 + f * -0.42, a, f, 0.86, 0.28, 11.0, false, 0.86 + 0.18)
			match variant % 3:
				0:
					pond(ci, o, a, f, -0.2, 0.45, 0.28)
					pine(ci, P(o, a, f, -0.65, 0.5))
				1:
					MarketArt.jars(ci, P(o, a, f, -0.2, 0.55), 6)
				_:
					stepping_stones(ci, o, a, f, 0.2, 0.0, 0.8)
					round_tree(ci, P(o, a, f, -0.6, 0.55))
		else:
			house(ci, o + a * -0.43 + f * -0.42, a, f, 0.57, 0.28, 11.0, false, 0.57 + 0.18)
			house(ci, o + a * 0.52 + f * 0.0, f, a, 0.42, 0.24, 10.0, false)
			MarketArt.jars(ci, P(o, a, f, -0.3, 0.45), 2)
	elif W == 1:
		# ---- 1x2(길에서 안쪽으로 두 칸): 뒤 칸 안채, 앞 칸 마당 + 사랑채
		if gj == 0:
			house(ci, o + f * -0.1, a, f, 0.74, 0.34, 11.0, false)
			MarketArt.jars(ci, P(o, a, f, 0.6, -0.7), 3)
		else:
			house(ci, o + a * -0.52 + f * -0.1, f, a, 0.55, 0.24, 10.0, false)
			match variant % 3:
				0: pond(ci, o, a, f, 0.25, 0.1, 0.25)
				1: MarketArt.jars(ci, P(o, a, f, 0.3, 0.2), 5)
				_: round_tree(ci, P(o, a, f, 0.3, 0.1))
	else:
		# ---- 2x2 대부호의 집: 뒤 두 칸이 이어진 긴 안채, 앞 왼쪽 사랑채 + 정원, 앞 오른쪽 마당 + 솟을대문
		if gj == 0:
			var tiers := 2 if (variant % 4 == 2 and gi == 1) else 1
			var cu := 0.12 if gi == 0 else -0.12
			house(ci, o + a * cu + f * -0.35, a, f, 0.88, 0.34, 12.0, false, 0.88 + 0.18, tiers)
			if variant % 4 == 1 and gi == 0:
				MarketArt.jars(ci, P(o, a, f, -0.5, 0.55), 6, true) # 장독대
		elif gi == 0:
			house(ci, o + a * -0.4 + f * -0.05, f, a, 0.8, 0.26, 11.0, false, 0.8 + 0.18)
			match variant % 4:
				0: pine(ci, P(o, a, f, 0.35, 0.3), 1.2)
				1: MarketArt.jars(ci, P(o, a, f, 0.35, 0.35), 4, true)
				2: round_tree(ci, P(o, a, f, 0.35, 0.3))
				_: conifer(ci, P(o, a, f, 0.35, 0.3))
		else:
			match variant % 4:
				0: # 6A 연못 + 돌다리 + 소나무
					pond(ci, o, a, f, -0.15, -0.1, 0.42)
					ci.draw_line(P(o, a, f, -0.45, -0.1, 1.5), P(o, a, f, 0.15, -0.1, 1.5), STONE, 2.0)
					pine(ci, P(o, a, f, 0.55, -0.4), 1.1)
				1: # 6B 장독 마당
					ground(ci, o + f * -0.1, a * 0.8, f * 0.7, DIRT, 1.0)
					MarketArt.jars(ci, P(o, a, f, -0.1, 0.0), 6, true)
				2: # 6C 정원 + 괴석 + 소나무
					rocks(ci, P(o, a, f, -0.3, -0.2))
					pine(ci, P(o, a, f, 0.4, -0.3))
					stepping_stones(ci, o, a, f, 0.35, 0.0, 0.8)
				_: # 9C 괴석 + 전나무 + 작은 연못
					pond(ci, o, a, f, -0.35, -0.3, 0.25)
					rocks(ci, P(o, a, f, 0.1, -0.1))
					conifer(ci, P(o, a, f, 0.6, -0.5))
					conifer(ci, P(o, a, f, -0.7, 0.3))
	if front_row and outer[1]:
		front_wall(ci, o, a, f, gate_u)

## PORT-TRACE [3x3 거상 대저택]: 뒷줄 세 칸에 걸친 긴 중층 안채, 가운데 줄 왼쪽 사랑채·가운데 안마당(연못 정자 또는
## 장독대)·오른쪽 별당, 앞줄 왼쪽 정원·가운데 행랑채와 솟을대문·오른쪽 곳간. 칸마다 제 몫만 그려 이어 붙인다.
static func _mansion_3x3(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, gi: int, gj: int, variant: int) -> void:
	var pond_type := variant % 2 == 0
	match gj:
		0:
			var cu: float = [0.12, 0.0, -0.12][gi]
			var bu := 1.0 if gi == 1 else 0.88
			house(ci, o + a * cu + f * -0.35, a, f, bu, 0.36, 13.0, false, bu + 0.18, 2 if gi == 1 else 1)
		1:
			match gi:
				0:
					house(ci, o + a * -0.4 + f * 0.0, f, a, 0.85, 0.26, 11.0, false, 0.85 + 0.18)
				1:
					if pond_type:
						pond(ci, o, a, f, 0.0, 0.05, 0.5)
						# 연못 가운데 작은 정자
						var po := o + f * 0.05
						for su: float in [-0.18, 0.18]:
							for sv: float in [-0.18, 0.18]:
								ci.draw_line(P(po, a, f, su, sv), P(po, a, f, su, sv, 9.0), Color("8a2e22"), 1.1)
						MarketArt.roof(ci, po, a, f, 0.3, 0.3, 0.05, 8.0, 14.0, GIWA)
					else:
						ground(ci, o, a * 0.7, f * 0.7, STONE, 1.0)
						MarketArt.jars(ci, P(o, a, f, -0.15, 0.1), 6, true)
						MarketArt.jars(ci, P(o, a, f, 0.3, -0.1), 3, true)
				_:
					house(ci, o + a * 0.45 + f * -0.05, f, a, 0.6, 0.24, 10.0, false)
					round_tree(ci, P(o, a, f, -0.35, 0.45))
		_:
			match gi:
				0:
					pine(ci, P(o, a, f, -0.3, -0.1), 1.2)
					rocks(ci, P(o, a, f, 0.3, 0.2))
				1:
					house(ci, o + f * 0.3, a, f, 1.0, 0.2, 8.0, false, 1.18) # 행랑채(앞 담장 안쪽 긴 채)
				_:
					MarketArt.box(ci, o + f * -0.1, a, f, 0.45, 0.32, 0.0, 9.0, Color("d8cfbb"))
					MarketArt.roof(ci, o + f * -0.1, a, f, 0.6, 0.48, 0.25, 8.0, 14.0, GIWA)
					MarketArt.sacks(ci, P(o, a, f, 0.4, 0.55))

# ---------------------------------------------------------------- 폐허(무너진 빈집)
## [인구 유출 및 빈집 폐허화 렌더러]
## 주민이 이탈하여 잡초가 우거지고 서까래가 주저앉은 빈집/무너진 가옥 표현
static func draw_ruined_house(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, tier: int = 1, variant: int = 0) -> void:
	# 1. 잡초와 마른 흙이 뒤섞인 버려진 마당
	var col_wasteland := Color("5e5445")
	var col_weeds := Color("4a5232")
	var col_dry_weeds := Color("7a6e42")
	ground(ci, o, a, f, col_wasteland)

	# 마당 곳곳에 웃자란 잡초 덤불 (잡초 우거진 모습)
	for i in range(5):
		var wu: float = float((variant * 7 + i * 13) % 17) / 17.0 * 1.4 - 0.7
		var wv: float = float((variant * 11 + i * 19) % 17) / 17.0 * 1.4 - 0.7
		var wp := P(o, a, f, wu, wv)
		ci.draw_line(wp, wp + Vector2(-1.5, -4.5), col_weeds, 1.2)
		ci.draw_line(wp, wp + Vector2(1.8, -4.0), col_dry_weeds, 1.0)
		ci.draw_line(wp, wp + Vector2(0.2, -6.0), col_weeds.darkened(0.1), 1.1)

	var ob := o + f * -0.25 + a * -0.05
	var h: float = 6.0 if tier <= 1 else 7.5

	# 2. 삭아서 무너져 내린 벽체와 기울어진 기둥
	var col_decayed_wall := Color("453b32")
	MarketArt.box(ci, ob, a, f, 0.45, 0.28, 0.0, h, col_decayed_wall)

	# 퀭하게 뚫리고 주저앉은 문·창살
	var d0 := P(ob, a, f, -0.12, 0.28, 0.0)
	var d1 := P(ob, a, f, 0.12, 0.28, 0.0)
	MarketArt.draw_safe_quad(ci, d0, d1, d1 - Vector2(0, h * 0.6), d0 - Vector2(0, h * 0.75), Color("231c18"))

	# 부러지고 비스듬히 기울어진 서까래/기둥 통나무
	var pole_col := Color("3a2c20")
	ci.draw_line(P(ob, a, f, -0.35, 0.28), P(ob, a, f, -0.25, 0.28, h + 3.0), pole_col, 1.8)
	ci.draw_line(P(ob, a, f, 0.35, 0.28), P(ob, a, f, 0.45, 0.28, h + 1.5), pole_col, 1.6)

	# 3. 주저앉고 구멍 뚫린 지붕 (초가 또는 기와 파편)
	if tier <= 1:
		# 무너진 초가지붕: 썩은 볏짚단 뭉치와 뚫린 서까래 구멍
		var col_rotten_thatch := Color("544632")
		MarketArt.roof(ci, ob, a, f, 0.55, 0.38, 0.15, h - 1.5, h + 3.5, col_rotten_thatch, true)
		# 주저앉은 지붕 중앙 틈새 음영
		var hole_p0 := P(ob, a, f, -0.15, 0.0, h + 2.0)
		var hole_p1 := P(ob, a, f, 0.2, 0.0, h + 1.0)
		ci.draw_line(hole_p0, hole_p1, Color("1e1814"), 2.4)
	else:
		# 허물어진 기와집: 깨진 암막새/수막새 기와 파편과 벗겨진 흙
		var col_broken_giwa := Color("2c3038")
		MarketArt.roof(ci, ob, a, f, 0.58, 0.4, 0.2, h - 1.0, h + 4.5, col_broken_giwa)
		# 무너져 드러난 흙갈비(적심토)
		var soil_p := P(ob, a, f, 0.1, 0.1, h + 3.0)
		FastDraw.circle(ci, soil_p, 2.5, Color("5a4430"))

	# 4. 땅에 나뒹구는 깨진 독/항아리 파편 및 흩어진 잔해
	var debris_p0 := P(o, a, f, 0.35, 0.4)
	var debris_p1 := P(o, a, f, -0.4, 0.35)
	FastDraw.circle(ci, debris_p0, 1.8, Color("3d3228"))
	ci.draw_line(debris_p0, debris_p0 + Vector2(2, -1.5), Color("28201a"), 1.2)
	ci.draw_line(debris_p1, debris_p1 + Vector2(-3, 1), Color("4a3c30"), 1.5)
