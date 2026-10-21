extends RefCounted
class_name MarketArt

## PORT-TRACE [저잣거리·공방·공공시설 변형]: 사용자가 "심시티 2000 풍 수원화성 저잣거리/관아·공공시설/
## 공방 거리/대형 시설" 참고 도판 네 장을 보내며, 한 가지 고정 그림 대신 같은 종류의 건물도 여러 외형
## (변형)으로 지어지게 해 달라고 요청. 에셋 파일을 들여오지 않고(프로젝트 원칙: 절차적 드로잉) 도판의
## 양식을 코드로 옮겼다 — 붉은 기와(육의전·중형 상점)/노란 초가(간이 상점)/흰 차일(난전), 열린 가게
## 앞면에 진열한 상품, 한자 간판 깃발, 공방 마당의 가마·풀무·건조대, 관아의 회색 기와 담장 등.
##
## 모든 그림은 타일의 "앞(길 쪽) 방향" 로컬 좌표계에서 그린다: P(u,v,h) = o + a*u + f*v - (0,h).
## a = 길과 나란한 반벡터, f = 가운데→길 쪽 모서리 중점. 타일 꼭짓점에서 뽑으므로 화면을 돌려도 맞다.
## 호출하는 쪽(CityLayer._draw) 안에서만 불러야 한다(ci.draw_* 는 그리기 중에만 유효).

# ---------------------------------------------------------------- 상점·공방 종류
## 육의전(박석길가): 선전(비단)·면포전·면주전·지전·저포전·내외어물전
const YUK_TRADES := ["silk", "cotton", "myeonju", "paper", "ramie", "fish", "yugi", "bangmul"]
## 흙길가 난전·일반 상점(작은 가게)과 큰 가게
const NAN_SMALL := ["rice", "veg", "meat", "pottery", "tent", "shoes", "fruit", "tteok", "jipsin", "salt", "tobacco"]
## 박석길·행궁 인근의 큰 가게: 육의전 + 고급 객주(客主, 상인 숙소 겸 도매)
const YUK_BIG := ["silk", "cotton", "myeonju", "paper", "ramie", "fish", "yugi", "bangmul", "gaekju"]
const NAN_BIG := ["gukbap", "jumak", "herb", "rice", "pottery"]
## 공방
const WORKSHOP_TRADES := ["brass", "onggi", "smith", "gat", "shoe", "brush", "bow", "hanji"]

## 가게 이름(말풍선·툴팁용)
const TRADE_NAMES := {
	"silk": "선전(비단)", "cotton": "면포전", "myeonju": "면주전", "paper": "지전", "ramie": "저포전", "fish": "어물전",
	"rice": "싸전", "veg": "채소전", "meat": "육전", "pottery": "옹기전", "tent": "난전", "shoes": "갖신전",
	"gukbap": "국밥집", "jumak": "주막", "herb": "약방", "gaekju": "객주",
	"yugi": "유기전", "bangmul": "방물전", "fruit": "과일전", "tteok": "떡전", "jipsin": "짚신전", "salt": "소금전", "tobacco": "연초전",
	"brass": "유기공방", "onggi": "옹기가마", "smith": "대장간", "gat": "갓방", "shoe": "신방",
	"brush": "필묵방", "bow": "궁시방", "hanji": "한지방",
	"book": "서책방", "cattle": "쇠전(우시장)", "jeotgal": "젓갈전", "lumber": "목재전", "firewood": "장작전(시탄전)",
}
## PORT-TRACE [사대문 물류]: 성문 특화 시장에만 서는 업종(GateLogistics.MARKET_*). 서책방은 장안문 앞 고급 기와 점포.
const GATE_TILED := ["book"]
const SIGN_CHARS := {
	"silk": "緞", "cotton": "綿", "myeonju": "紬", "paper": "紙", "ramie": "苧", "fish": "魚",
	"rice": "米", "veg": "菜", "meat": "肉", "pottery": "甕", "tent": "", "shoes": "靴",
	"gukbap": "食", "jumak": "酒", "herb": "藥", "gaekju": "客",
	"yugi": "鍮", "bangmul": "物", "fruit": "果", "tteok": "餠", "jipsin": "履", "salt": "鹽", "tobacco": "草",
	"brass": "鍮", "onggi": "陶", "smith": "鐵", "gat": "笠", "shoe": "鞋", "brush": "筆", "bow": "弓", "hanji": "紙",
	"book": "冊", "cattle": "牛", "jeotgal": "醢", "lumber": "木", "firewood": "薪",
}

const ROOF_RED := Color("8e4b32")   # 붉은 기와(상점)
const ROOF_SLATE := Color("3a4048") # 회색 기와(관아)
const THATCH := Color("c9a24a")
const WALL_PLASTER := Color("e6dcc6")
const TIMBER := Color("6e4a2c")
const INTERIOR := Color("3a2616")

# ---------------------------------------------------------------- 기본 도형
static func P(o: Vector2, a: Vector2, f: Vector2, u: float, v: float, h: float = 0.0) -> Vector2:
	return o + a * u + f * v - Vector2(0, h)

## 2D 평면 외적(cross product)을 통한 유효 면적 검사 (축퇴 폴리곤 및 Godot 4 삼각분할 실패 방지)
static func is_valid_tri(p0: Vector2, p1: Vector2, p2: Vector2, min_area2: float = 0.5) -> bool:
	var cross: float = (p1.x - p0.x) * (p2.y - p0.y) - (p1.y - p0.y) * (p2.x - p0.x)
	return absf(cross) >= min_area2

static func draw_safe_tri(ci: CanvasItem, p0: Vector2, p1: Vector2, p2: Vector2, col: Color) -> bool:
	if is_valid_tri(p0, p1, p2):
		FastDraw.poly(ci, PackedVector2Array([p0, p1, p2]), col)
		return true
	return false

static func draw_safe_quad(ci: CanvasItem, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, col: Color) -> bool:
	var drawn: bool = false
	if is_valid_tri(p0, p1, p2):
		FastDraw.poly(ci, PackedVector2Array([p0, p1, p2]), col)
		drawn = true
	if is_valid_tri(p0, p2, p3):
		FastDraw.poly(ci, PackedVector2Array([p0, p2, p3]), col)
		drawn = true
	return drawn

## 상자 몸체(벽). open_front면 길 쪽 면을 어두운 가게 안으로 비워 둔다. 반환: 앞면 네 점(진열용)
static func box(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, bu: float, bv: float, h0: float, h1: float,
		wall: Color, open_front: bool = false) -> PackedVector2Array:
	var g: Array[Vector2] = [a * -bu + f * -bv, a * bu + f * -bv, a * bu + f * bv, a * -bu + f * bv]
	var order: Array[int] = [0, 1, 2, 3]
	order.sort_custom(func(i: int, j: int): return (g[i] + g[(i + 1) % 4]).y < (g[j] + g[(j + 1) % 4]).y)
	var front := PackedVector2Array()
	for i in order:
		var p0: Vector2 = o + g[i] - Vector2(0, h0)
		var p1: Vector2 = o + g[(i + 1) % 4] - Vector2(0, h0)
		var q0: Vector2 = o + g[i] - Vector2(0, h1)
		var q1: Vector2 = o + g[(i + 1) % 4] - Vector2(0, h1)
		var mid: Vector2 = g[i] + g[(i + 1) % 4]
		var col := wall if mid.x >= 0.0 else wall.darkened(0.18)
		if open_front and i == 2:
			col = INTERIOR
			front = PackedVector2Array([p0, p1, q1, q0])
		draw_safe_quad(ci, p0, p1, q1, q0, col)
		# 기둥과 인방(나무 뼈대)
		ci.draw_line(p0, q0, TIMBER, 1.3)
		ci.draw_line(p1, q1, TIMBER, 1.3)
		ci.draw_line(q0, q1, TIMBER, 1.2)
		if not (open_front and i == 2):
			ci.draw_line(p0.lerp(q0, 0.45), p1.lerp(q1, 0.45), TIMBER.lightened(0.1), 0.8)
	return front

## 우진각(팔작 흉내) 지붕. thatch면 둥글고 누런 초가. snow면 처마와 지붕면에 자연스럽게 눈이 얹힘.
static func roof(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, ru: float, rv: float, ridge_u: float,
		h_eave: float, h_ridge: float, col: Color, thatch: bool = false, snow: bool = false) -> void:
	var eu := Vector2(0, h_eave)
	var e: Array[Vector2] = [o + a * -ru + f * -rv - eu, o + a * ru + f * -rv - eu, o + a * ru + f * rv - eu, o + a * -ru + f * rv - eu]
	var r0 := o + a * -ridge_u - Vector2(0, h_ridge)
	var r1 := o + a * ridge_u - Vector2(0, h_ridge)
	var planes: Array = [
		{"pts": PackedVector2Array([e[0], e[1], r1, r0]), "dir": -f, "long": true, "i": 0},
		{"pts": PackedVector2Array([e[1], e[2], r1]), "dir": a, "long": false, "i": 1},
		{"pts": PackedVector2Array([e[2], e[3], r0, r1]), "dir": f, "long": true, "i": 2},
		{"pts": PackedVector2Array([e[3], e[0], r0]), "dir": -a, "long": false, "i": 3},
	]
	planes.sort_custom(func(p, q): return (p["dir"] as Vector2).y < (q["dir"] as Vector2).y)
	var roof_col: Color = col.lerp(Color("dce5ed"), 0.78) if snow else col
	if snow and thatch:
		roof_col = Color("edf2f7")
	for pl in planes:
		var n: Vector2 = (pl["dir"] as Vector2).normalized()
		var shade: float = 0.16 * n.y + 0.07 * n.x
		var c2 := roof_col.lightened(shade) if shade > 0.0 else roof_col.darkened(-shade)
		var pts: PackedVector2Array = pl["pts"]
		var has_drawn: bool = false
		if pts.size() == 4:
			has_drawn = draw_safe_quad(ci, pts[0], pts[1], pts[2], pts[3], c2)
		elif pts.size() == 3:
			has_drawn = draw_safe_tri(ci, pts[0], pts[1], pts[2], c2)
		if pl["long"] and has_drawn and pts.size() >= 4:
			# 기왓골/이엉 결: 처마에서 용마루로 가는 줄
			var line_col: Color
			if snow:
				line_col = c2.darkened(0.12)
			else:
				line_col = c2.darkened(0.25) if not thatch else c2.darkened(0.18)
			var steps := 6 if not thatch else 8
			for k in range(1, steps):
				var t := float(k) / float(steps)
				var bottom: Vector2 = pts[0].lerp(pts[1], t)
				var top: Vector2 = pts[3].lerp(pts[2], t)
				ci.draw_line(bottom, bottom.lerp(top, 0.92), line_col, 0.7)
	if snow:
		# 눈이 소복이 쌓인 2.5D 처마 외곽선
		FastDraw.polyline(ci, PackedVector2Array([e[0], e[1], e[2], e[3], e[0]]), Color("f8fafc", 0.96), 2.2)
		# 용마루와 추녀마루 눈 쌓임 하이라이트
		ci.draw_line(r0, r1, Color("ffffff"), 2.4)
		ci.draw_line(e[0], r0, Color("f8fafc"), 1.8)
		ci.draw_line(e[1], r1, Color("f8fafc"), 1.8)
		ci.draw_line(e[2], r1, Color("f8fafc"), 1.8)
		ci.draw_line(e[3], r0, Color("f8fafc"), 1.8)
	else:
		FastDraw.polyline(ci, PackedVector2Array([e[0], e[1], e[2], e[3], e[0]]), roof_col.darkened(0.45), 1.0)
		if thatch:
			ci.draw_line(r0, r1, roof_col.darkened(0.3), 2.4) # 용마름
		else:
			ci.draw_line(r0, r1, Color("e0dcd2"), 1.8)
			ci.draw_line(e[0], r0, Color("d8d4ca"), 0.9)
			ci.draw_line(e[1], r1, Color("d8d4ca"), 0.9)
			ci.draw_line(e[2], r1, Color("d8d4ca"), 0.9)
			ci.draw_line(e[3], r0, Color("d8d4ca"), 0.9)

## 차양(가게 앞 처마를 늘인 널판 지붕) + 앞 기둥 두 개
static func awning(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, bu: float, v0: float, v1: float, h_back: float, h_front: float, col: Color) -> void:
	var b0 := P(o, a, f, -bu, v0, h_back)
	var b1 := P(o, a, f, bu, v0, h_back)
	var f1 := P(o, a, f, bu, v1, h_front)
	var f0 := P(o, a, f, -bu, v1, h_front)
	for s: float in [-bu * 0.92, bu * 0.92]:
		ci.draw_line(P(o, a, f, s, v1 - 0.02, 0.0), P(o, a, f, s, v1 - 0.02, h_front), TIMBER, 1.2)
	draw_safe_quad(ci, b0, b1, f1, f0, col)
	ci.draw_line(f0, f1, col.darkened(0.4), 1.0)

## 흰 차일 천막(난전) — 네 기둥 + 가운데가 살짝 처진 천
static func tent(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, bu: float, bv: float, h: float, col: Color) -> void:
	var corners: Array[Vector2] = [P(o, a, f, -bu, -bv, h + 2.0), P(o, a, f, bu, -bv, h + 2.0), P(o, a, f, bu, bv, h), P(o, a, f, -bu, bv, h)]
	for su: float in [-bu, bu]:
		for sv: float in [-bv, bv]:
			ci.draw_line(P(o, a, f, su, sv, 0.0), P(o, a, f, su, sv, h + (2.0 if sv < 0 else 0.0)), Color("8a6a42"), 1.1)
	var mid := (corners[0] + corners[1] + corners[2] + corners[3]) * 0.25 + Vector2(0, 1.5)
	draw_safe_tri(ci, corners[0], corners[1], mid, col.darkened(0.08))
	draw_safe_tri(ci, corners[1], corners[2], mid, col)
	draw_safe_tri(ci, corners[2], corners[3], mid, col.lightened(0.05))
	draw_safe_tri(ci, corners[3], corners[0], mid, col.darkened(0.04))
	FastDraw.polyline(ci, PackedVector2Array([corners[0], corners[1], corners[2], corners[3], corners[0]]), col.darkened(0.35), 0.8)

## 간판 깃발(장대 + 세로 기 + 한자)
static func sign_flag(ci: CanvasItem, base: Vector2, ch: String, cloth: Color = Color("f2ead6")) -> void:
	ci.draw_line(base, base - Vector2(0, 26), Color("5c3a21"), 1.3)
	var r := Rect2(base + Vector2(1.0, -25.0), Vector2(8.0, 13.0))
	ci.draw_rect(r, cloth)
	ci.draw_rect(r, Color("7a1f14"), false, 0.8)
	if ch != "":
		ci.draw_string(ThemeDB.fallback_font, base + Vector2(1.6, -15.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("7a1f14"))

## 낮은 담장 한 토막(회벽 + 기와 머리) — u0..u1 구간, v 위치, 두께 th
static func wall_seg(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, u0: float, u1: float, v: float, h: float, along_v: bool = false) -> void:
	var ctr := (u0 + u1) * 0.5
	var half := absf(u1 - u0) * 0.5
	if along_v:
		box(ci, o + a * v + f * ctr, f, a, half, 0.06, 0.0, h, Color("d8cfbb"))
	else:
		box(ci, o + a * ctr + f * v, a, f, half, 0.06, 0.0, h, Color("d8cfbb"))
	var p0: Vector2
	var p1: Vector2
	if along_v:
		p0 = P(o, a, f, v, u0, h)
		p1 = P(o, a, f, v, u1, h)
	else:
		p0 = P(o, a, f, u0, v, h)
		p1 = P(o, a, f, u1, v, h)
	ci.draw_line(p0, p1, Color("3a3f47"), 2.2)

# ---------------------------------------------------------------- 2.5D 아이소 소품 헬퍼

## 아이소메트릭 박스 단순 헬퍼 (소품용): p=화면 기준점, av=가로축벡터, fv=세로축벡터
## w=가로반폭, d=세로반폭, h=높이(픽셀), top/side_l/side_r 색상
static func _iso_box(ci: CanvasItem, p: Vector2, av: Vector2, fv: Vector2,
		w: float, d: float, h: float,
		top: Color, side_l: Color, side_r: Color) -> void:
	var b0 := p - av * w - fv * d
	var b1 := p + av * w - fv * d
	var b2 := p + av * w + fv * d
	var b3 := p - av * w + fv * d
	var t0 := b0 - Vector2(0, h)
	var t1 := b1 - Vector2(0, h)
	var t2 := b2 - Vector2(0, h)
	var t3 := b3 - Vector2(0, h)
	draw_safe_quad(ci, b0, b1, t1, t0, side_l.darkened(0.22))
	draw_safe_quad(ci, b0, b3, t3, t0, side_r.darkened(0.28))
	draw_safe_quad(ci, b1, b2, t2, t1, side_l)
	draw_safe_quad(ci, b2, b3, t3, t2, side_r)
	draw_safe_quad(ci, t0, t1, t2, t3, top)
	var dk := top.darkened(0.5)
	ci.draw_line(t0, t1, dk, 0.6)
	ci.draw_line(t1, t2, dk, 0.6)
	ci.draw_line(t2, t3, dk, 0.6)
	ci.draw_line(t3, t0, dk, 0.6)

## 아이소메트릭 원통 (항아리·독): p=화면 기준점, av/fv=축벡터, r=반지름, h=높이
static func _iso_cyl(ci: CanvasItem, p: Vector2, av: Vector2, fv: Vector2,
		r: float, h: float, body: Color, top_col: Color, steps: int = 8) -> void:
	var pts_b: PackedVector2Array = PackedVector2Array()
	var pts_t: PackedVector2Array = PackedVector2Array()
	for i in range(steps):
		var ang := TAU * float(i) / float(steps)
		var off := av * cos(ang) * r + fv * sin(ang) * r * 0.5
		pts_b.append(p + off)
		pts_t.append(p + off - Vector2(0, h))
	for i in range(steps):
		var ni := (i + 1) % steps
		if (pts_b[i] + pts_b[ni]).y >= p.y * 2.0 - 2.0:
			var shade := 0.15 * sin(TAU * float(i) / float(steps))
			draw_safe_quad(ci, pts_b[i], pts_b[ni], pts_t[ni], pts_t[i],
					body.lightened(shade) if shade > 0.0 else body.darkened(-shade))
	var top_pts: PackedVector2Array = PackedVector2Array()
	for i in range(steps):
		top_pts.append(pts_t[i])
	FastDraw.poly(ci, top_pts, top_col)
	FastDraw.polyline(ci, top_pts, top_col.darkened(0.4), 0.7)

## 아이소메트릭 불룩한 마대/가마니
static func _iso_sack(ci: CanvasItem, p: Vector2, av: Vector2, fv: Vector2,
		w: float, d: float, h: float, col: Color) -> void:
	var bulge := Vector2(0, -h * 0.25)
	var b0 := p - av * w - fv * d
	var b1 := p + av * w - fv * d
	var b2 := p + av * w + fv * d
	var b3 := p - av * w + fv * d
	var mid_b := (b0 + b1 + b2 + b3) * 0.25
	var apex := mid_b - Vector2(0, h) + bulge
	draw_safe_tri(ci, b0, b1, apex, col.darkened(0.1))
	draw_safe_tri(ci, b1, b2, apex, col)
	draw_safe_tri(ci, b2, b3, apex, col.lightened(0.08))
	draw_safe_tri(ci, b3, b0, apex, col.darkened(0.18))
	ci.draw_line(apex + Vector2(-1.5, 2), apex + Vector2(1.5, 2), col.darkened(0.5), 1.0)
	ci.draw_line(mid_b - Vector2(0, h * 0.5) + Vector2(-2, 0),
			mid_b - Vector2(0, h * 0.5) + Vector2(2, 0), col.darkened(0.4), 0.6)

# ---------------------------------------------------------------- 상품·소품

## 비단/면포 두루마리 묶음 — 아이소메트릭 납작한 원통 더미
static func bolts(ci: CanvasItem, p: Vector2, cols: Array) -> void:
	var av := Vector2(2.2, 1.0).normalized() * 1.8
	var fv := Vector2(-1.4, 1.0).normalized() * 0.8
	for i in range(cols.size()):
		var row_i := int(float(i) / 3.0)
		var col_i := i % 3
		var bp := p + Vector2(-5.0 + float(col_i) * 3.8, -float(row_i) * 3.2 - float(col_i % 2) * 1.0)
		var c := cols[i] as Color
		_iso_cyl(ci, bp, av, fv, 1.8, 2.0, c.darkened(0.2), c, 6)
		ci.draw_line(bp - Vector2(1.6, 2.2), bp + Vector2(1.6, 2.2), c.darkened(0.4), 0.5)

## 쌀가마니/마대 더미 — 아이소메트릭 불룩한 마대
static func sacks(ci: CanvasItem, p: Vector2) -> void:
	var av := Vector2(2.0, 0.9)
	var fv := Vector2(-1.2, 0.9)
	var sack_col := Color("e0cc8a")
	var positions: Array[Vector2] = [Vector2(-3.5, 0.8), Vector2(3.0, 1.2), Vector2(-0.5, -2.5)]
	for off: Vector2 in positions:
		_iso_sack(ci, p + off, av, fv, 3.2, 1.4, 3.8, sack_col)
		var sp := p + off - Vector2(0, 1.5)
		ci.draw_line(sp + Vector2(-3.0, 0.5), sp + Vector2(3.0, -0.5), Color("8a6a2a"), 0.7)
		ci.draw_line(sp + Vector2(-3.0, 2.5), sp + Vector2(3.0, 1.5), Color("8a6a2a"), 0.7)

## 대바구니 묶음 — 아이소메트릭 원통형 광주리 + 내용물
static func baskets(ci: CanvasItem, p: Vector2, fill: Array) -> void:
	var av := Vector2(2.0, 0.9)
	var fv := Vector2(-1.2, 0.9)
	for i in range(fill.size()):
		var q := p + Vector2(-5.0 + float(i) * 5.0, float(i % 2) * 0.8)
		var fc := fill[i] as Color
		_iso_cyl(ci, q, av, fv, 2.8, 2.5, Color("7a5a32"), Color("8a6a3c"), 7)
		var inner_pts: PackedVector2Array = PackedVector2Array()
		for k in range(7):
			var ang := TAU * float(k) / 7.0
			inner_pts.append(q + av * cos(ang) * 1.9 + fv * sin(ang) * 0.9 - Vector2(0, 2.5))
		FastDraw.poly(ci, inner_pts, fc)
		draw_safe_tri(ci, q + av * 0.7 - Vector2(0, 3.4),
				q + av * 0.2 + fv * 0.4 - Vector2(0, 3.4),
				q + av * 0.2 + fv * 0.4 - Vector2(0, 3.8), fc.lightened(0.4))
		for k in range(1, 3):
			var ring_h := float(k) * 0.7
			var rpts: PackedVector2Array = PackedVector2Array()
			for m in range(7):
				var ang2 := TAU * float(m) / 7.0
				rpts.append(q + av * cos(ang2) * 2.8 + fv * sin(ang2) * 1.35 - Vector2(0, ring_h))
			FastDraw.polyline(ci, rpts, Color("5a3a1a"), 0.5)

## 항아리/독 — 아이소메트릭 입체 도기
static func jars(ci: CanvasItem, p: Vector2, n: int, big: bool = false) -> void:
	var s := 1.4 if big else 1.0
	var av := Vector2(2.0, 0.9) * s
	var fv := Vector2(-1.2, 0.9) * s
	for i in range(n):
		var row_offset: float = floorf(float(i) / 3.0)
		var q := p + Vector2((float(i % 3) - 1.0) * 4.5 * s, -row_offset * 3.0 * s + float(i % 2) * 1.0)
		_iso_cyl(ci, q, av, fv, 2.5 * s, 4.5 * s, Color("5e3a22"), Color("7a5236"), 8)
		_iso_cyl(ci, q - Vector2(0, 4.5 * s), av * 0.65, fv * 0.65, 1.6 * s, 1.5 * s,
				Color("6e4a2e"), Color("8a6040"), 6)
		_iso_cyl(ci, q - Vector2(0, 6.0 * s), av * 0.4, fv * 0.4, 1.0 * s, 1.0 * s,
				Color("4a2c18"), Color("3a2010"), 5)
		for k in range(3):
			var ang3 := TAU * float(k + 1) / 5.0
			var side_p := q + av * cos(ang3) * 2.5 * s + fv * sin(ang3) * 1.2 * s
			ci.draw_line(side_p, side_p - Vector2(0, 4.0 * s), Color("3e2010", 0.4), 0.5)

## 덕장 생선 걸대 — 아이소메트릭 각재 + 생선 실루엣
static func fish_rack(ci: CanvasItem, p: Vector2) -> void:
	var av := Vector2(2.0, 0.9)
	var fv := Vector2(-1.2, 0.9)
	for sx: float in [-6.0, 6.0]:
		var kp := p + Vector2(sx, 0)
		_iso_box(ci, kp - Vector2(0, 5), av * 0.6, fv * 0.6, 0.6, 0.6, 10.0,
				Color("7a5030"), Color("6a4028"), Color("5a3020"))
	ci.draw_line(p + Vector2(-7, -10), p + Vector2(7, -10), TIMBER, 1.4)
	ci.draw_line(p + Vector2(-7, -11), p + Vector2(7, -11), TIMBER.lightened(0.2), 0.5)
	for i in range(5):
		var x := -4.5 + float(i) * 2.2
		var fish_col := Color("d8aa40") if i % 2 == 0 else Color("d0ccc0")
		var fp := p + Vector2(x, -10)
		draw_safe_quad(ci, fp + Vector2(-0.9, 0), fp + Vector2(0.9, 0),
				fp + Vector2(0.6, -5.0), fp + Vector2(-0.6, -5.0), fish_col)
		draw_safe_tri(ci, fp + Vector2(-0.6, -5.0), fp + Vector2(0.6, -5.0),
				fp + Vector2(0, -7.0), fish_col.darkened(0.3))
		FastDraw.circle(ci, fp + Vector2(0.4, -1.2), 0.35, Color("1a1a1a"))
		ci.draw_line(fp, fp - Vector2(0, 0.5), Color("8a6a2a"), 0.7)

## 고기걸이 — 아이소메트릭 횡대 + 고기 덩이
static func meat_hang(ci: CanvasItem, p: Vector2) -> void:
	var av := Vector2(2.0, 0.9)
	var fv := Vector2(-1.2, 0.9)
	draw_safe_quad(ci, p + Vector2(-6, -11), p + Vector2(6, -11),
			p + Vector2(6, -10), p + Vector2(-6, -10), TIMBER)
	ci.draw_line(p + Vector2(-6, -11), p + Vector2(6, -11), TIMBER.lightened(0.2), 0.7)
	for x: float in [-3.5, 0.5, 3.5]:
		var hp := p + Vector2(x, -10)
		ci.draw_line(hp, hp + Vector2(0.4, -0.8), Color("606060"), 0.8)
		var mp := hp + Vector2(0, 0.5)
		draw_safe_quad(ci, mp + Vector2(-1.2, 0), mp + Vector2(1.2, 0),
				mp + Vector2(0.8, -4.0), mp + Vector2(-0.8, -4.0), Color("b8433a"))
		draw_safe_quad(ci, mp + Vector2(-1.2, 0), mp + Vector2(1.2, 0),
				mp + Vector2(1.0, -1.0), mp + Vector2(-1.0, -1.0), Color("f0e0d0"))
		_iso_cyl(ci, mp - Vector2(0, 3.8), av * 0.3, fv * 0.3, 0.5, 0.4,
				Color("e8e0d0"), Color("f4f0e8"), 5)

## 한지 종이 더미 — 아이소메트릭 납작 박스 + 두루마리
static func paper_stack(ci: CanvasItem, p: Vector2) -> void:
	var av := Vector2(2.2, 1.0)
	var fv := Vector2(-1.4, 1.0)
	for i in range(4):
		var sp := p + Vector2(-float(i) * 0.4, -float(i) * 1.8)
		_iso_box(ci, sp, av * 2.2, fv * 0.9, 2.2, 0.9, 1.3,
				Color("f7f3e8").darkened(0.02 * float(i)),
				Color("e0dcd0").darkened(0.05 * float(i)),
				Color("d4d0c4").darkened(0.05 * float(i)))
		ci.draw_line(sp + Vector2(-1.5, -float(i) * 1.8 - 1.2),
				sp + Vector2(1.5, -float(i) * 1.8 - 1.2), Color("d8d2c0"), 0.4)
	_iso_box(ci, p + Vector2(3.5, -2), av * 0.4, fv * 0.3, 0.4, 0.3, 7.0,
			Color("5a3a22"), Color("4a3018"), Color("3e2810"))
	_iso_cyl(ci, p + Vector2(5.5, -1.5), Vector2(2.2, 1.0).normalized() * 1.2,
			Vector2(-1.4, 1.0).normalized() * 0.6, 1.2, 5.5, Color("4a3a28"), Color("f0ead8"), 6)

## 갖신 진열 — 아이소메트릭 박스 위 신발 실루엣
static func shoes(ci: CanvasItem, p: Vector2) -> void:
	var av := Vector2(2.0, 0.9)
	var fv := Vector2(-1.2, 0.9)
	for i in range(4):
		var q := p + Vector2(-5.5 + float(i) * 3.6, -float(i % 2) * 1.2)
		var shoe_col := Color("2a1e18") if i % 2 == 0 else Color("7a3a2a")
		_iso_box(ci, q, av * 1.4, fv * 0.5, 1.4, 0.5, 0.8,
				shoe_col.darkened(0.3), shoe_col.darkened(0.4), shoe_col.darkened(0.5))
		draw_safe_tri(ci, q + av * 1.4 - Vector2(0, 0.8),
				q + av * 2.0 - Vector2(0, 0.3),
				q + av * 1.4 + fv * 0.3 - Vector2(0, 0.8), shoe_col)
		draw_safe_quad(ci, q - av * 1.0 - Vector2(0, 0.8),
				q - av * 0.2 - Vector2(0, 0.8),
				q - av * 0.2 - Vector2(0, 2.5),
				q - av * 1.0 - Vector2(0, 2.5), shoe_col.lightened(0.1))

static func table(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, u: float, v: float, w: float, d: float, h: float = 3.0) -> void:
	var t0 := P(o, a, f, u - w, v - d, h)
	var t1 := P(o, a, f, u + w, v - d, h)
	var t2 := P(o, a, f, u + w, v + d, h)
	var t3 := P(o, a, f, u - w, v + d, h)
	for q: Vector2 in [t2, t3]:
		ci.draw_line(q, q + Vector2(0, h), Color("4a2e18"), 1.0)
	draw_safe_quad(ci, t0, t1, t2, t3, Color("9a7248"))
	FastDraw.polyline(ci, PackedVector2Array([t0, t1, t2, t3, t0]), Color("5a3a20"), 0.7)

static func mat(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, u: float, v: float, w: float, d: float) -> void:
	draw_safe_quad(ci, P(o, a, f, u - w, v - d), P(o, a, f, u + w, v - d), P(o, a, f, u + w, v + d), P(o, a, f, u - w, v + d), Color("c8b27a"))
	ci.draw_line(P(o, a, f, u - w, v), P(o, a, f, u + w, v), Color("a8925a"), 0.6)

## 솥/가마 — 아이소메트릭 아궁이 블록 + 반구형 솥
static func cauldron(ci: CanvasItem, p: Vector2) -> void:
	var av := Vector2(2.0, 0.9)
	var fv := Vector2(-1.2, 0.9)
	_iso_box(ci, p - Vector2(0, 2), av * 3.5, fv * 2.2, 3.5, 2.2, 4.0,
			Color("9a6848"), Color("7a5038"), Color("6a4030"))
	draw_safe_quad(ci, p + av * 1.0 + fv * 2.2,
			p + av * 3.0 + fv * 2.2,
			p + av * 3.0 + fv * 2.2 - Vector2(0, 3.0),
			p + av * 1.0 + fv * 2.2 - Vector2(0, 3.0), Color("2a1810"))
	FastDraw.circle(ci, p + Vector2(0, -1.5), 1.2, Color("f08a24"))
	_iso_cyl(ci, p - Vector2(0, 6), av * 3.0, fv * 1.5, 3.0, 2.8,
			Color("1c1c1e"), Color("2c2c30"), 10)
	_iso_cyl(ci, p - Vector2(0, 9.0), av * 0.6, fv * 0.3, 0.6, 1.2,
			Color("3a3a3e"), Color("5a5a60"), 5)
	for s: Vector2 in [Vector2(-1.0, -11), Vector2(1.5, -15), Vector2(-0.5, -19)]:
		FastDraw.circle(ci, p + s, 1.8, Color(1, 1, 1, 0.45))

## 가마/요 — 아이소메트릭 돔 도기 가마
static func kiln(ci: CanvasItem, p: Vector2, r: float = 7.0) -> void:
	var av := Vector2(2.0, 0.9)
	var fv := Vector2(-1.2, 0.9)
	_iso_box(ci, p, av * r * 0.95, fv * r * 0.6, r * 0.95, r * 0.6, r * 0.4,
			Color("9a5a38"), Color("7a4428"), Color("6a3820"))
	var dome := PackedVector2Array()
	for i in range(9):
		var ang := PI * float(i) / 8.0
		dome.append(p + Vector2(cos(ang) * r, -sin(ang) * r * 0.6) - Vector2(0, r * 0.4))
	for i in range(1, 8):
		var ang2 := PI * float(i) / 8.0
		dome.append(p + Vector2(-cos(ang2) * r, sin(ang2) * r * 0.18))
	FastDraw.poly(ci, dome, Color("8a5436"))
	for k_idx in range(2, 8, 2):
		var ang3 := PI * float(k_idx) / 8.0
		ci.draw_line(
			p + Vector2(cos(ang3) * r, -sin(ang3) * r * 0.6) - Vector2(0, r * 0.4),
			p + Vector2(-cos(ang3) * r, -sin(ang3) * r * 0.6) - Vector2(0, r * 0.4),
			Color("6a3a22"), 0.6)
	draw_safe_quad(ci, p + av * 1.0 + fv * r * 0.58 - Vector2(0, 1.5),
			p + av * 3.0 + fv * r * 0.58 - Vector2(0, 1.5),
			p + av * 3.0 + fv * r * 0.58 - Vector2(0, r * 0.4),
			p + av * 1.0 + fv * r * 0.58 - Vector2(0, r * 0.4), Color("1e120c"))
	FastDraw.circle(ci, p + av * 1.8 + fv * r * 0.55 - Vector2(0, 2.0), 1.2, Color("f08a24"))

## 굴뚝 — 아이소메트릭 벽돌 기둥 + 연기
static func chimney(ci: CanvasItem, p: Vector2, h: float) -> void:
	var av := Vector2(2.0, 0.9)
	var fv := Vector2(-1.2, 0.9)
	_iso_box(ci, p - Vector2(0, h * 0.5), av * 1.0, fv * 0.8, 1.0, 0.8, h,
			Color("9a4a30"), Color("7a3a24"), Color("6a3020"))
	for k in range(int(h / 4.0)):
		ci.draw_line(p - Vector2(0, float(k) * 4.0) + av * 1.0 + fv * 0.8,
				p - Vector2(0, float(k) * 4.0) - av * 1.0 + fv * 0.8,
				Color("6a2e1c"), 0.5)
	for s: Vector2 in [Vector2(0, -h - 3), Vector2(2, -h - 7), Vector2(-1, -h - 11)]:
		FastDraw.circle(ci, p + s, 2.2, Color(0.5, 0.5, 0.52, 0.48))

## 대장간 화로·모루 — 아이소메트릭 블록
static func forge(ci: CanvasItem, p: Vector2) -> void:
	var av := Vector2(2.0, 0.9)
	var fv := Vector2(-1.2, 0.9)
	_iso_box(ci, p - Vector2(0, 3), av * 3.0, fv * 2.0, 3.0, 2.0, 3.5,
			Color("7a4a34"), Color("5a3224"), Color("4a2818"))
	draw_safe_quad(ci, p + av * 1.5 + fv * 0.8 - Vector2(0, 3.5),
			p + av * 3.0 + fv * 0.8 - Vector2(0, 3.5),
			p + av * 3.0 + fv * 2.0 - Vector2(0, 3.5),
			p + av * 1.5 + fv * 2.0 - Vector2(0, 3.5), Color("f5a030"))
	FastDraw.circle(ci, p + av * 2.2 + fv * 1.4 - Vector2(0, 4.0), 1.4, Color("ffe07a"))
	var an := p + Vector2(9, 0)
	_iso_box(ci, an - Vector2(0, 1.5), av * 0.8, fv * 0.5, 0.8, 0.5, 3.0,
			Color("3c3c42"), Color("2a2a30"), Color("222228"))
	_iso_box(ci, an - Vector2(0, 3.5), av * 2.0, fv * 0.8, 2.0, 0.8, 1.2,
			Color("4c4c52"), Color("3a3a40"), Color("303038"))

## 유기(놋그릇) — 아이소메트릭 원통형 그릇 진열
static func brassware(ci: CanvasItem, p: Vector2) -> void:
	var av := Vector2(2.0, 0.9)
	var fv := Vector2(-1.2, 0.9)
	for i in range(5):
		var q := p + Vector2(-5.0 + float(i) * 2.6, -float(i % 2) * 1.5)
		_iso_cyl(ci, q, av * 0.9, fv * 0.5, 1.6, 1.4, Color("c8980a"), Color("e0b030"), 7)
		FastDraw.circle(ci, q - av * 0.4 - Vector2(0, 1.6), 0.5, Color("f4e080"))
		var rim_pts: PackedVector2Array = PackedVector2Array()
		for k in range(7):
			var ang := TAU * float(k) / 7.0
			rim_pts.append(q + av * cos(ang) * 1.6 + fv * sin(ang) * 0.8 - Vector2(0, 1.4))
		FastDraw.polyline(ci, rim_pts, Color("f4d060"), 0.7)

## 활 걸이 — 아이소메트릭 선반 + 활 실루엣
static func bow_rack(ci: CanvasItem, p: Vector2) -> void:
	var av := Vector2(2.0, 0.9)
	var fv := Vector2(-1.2, 0.9)
	for sx: float in [-5.0, 5.0]:
		_iso_box(ci, p + Vector2(sx, 0) - Vector2(0, 6), av * 0.5, fv * 0.5, 0.5, 0.5, 12.0,
				Color("6a4428"), Color("5a3820"), Color("4a2e18"))
	ci.draw_line(p + Vector2(-5, -12), p + Vector2(5, -12), TIMBER, 1.4)
	ci.draw_line(p + Vector2(-5, -13), p + Vector2(5, -13), TIMBER.lightened(0.15), 0.6)
	for i in range(3):
		var x := -3.0 + float(i) * 3.0
		FastDraw.arc(ci, p + Vector2(x, -7.5), 4.2, -PI * 0.48 - 0.8, -PI * 0.48 + 0.8, 8,
				Color("3a2416"), 1.4)
		ci.draw_line(p + Vector2(x - 3.1, -9.8), p + Vector2(x - 3.1, -5.2),
				Color("e8e0c0"), 0.5)
		ci.draw_line(p + Vector2(x + 1.0, -12.0), p + Vector2(x + 2.8, -4.5),
				Color("8a6030"), 0.8)
		draw_safe_tri(ci, p + Vector2(x + 2.8, -4.5), p + Vector2(x + 2.0, -4.0),
				p + Vector2(x + 3.4, -4.0), Color("5a3020"))

## 한지 건조대 — 아이소메트릭 목재 틀 + 한지 면
static func drying_frame(ci: CanvasItem, p: Vector2) -> void:
	var av := Vector2(2.0, 0.9)
	var fv := Vector2(-1.2, 0.9)
	for sx: float in [-6.0, 6.0]:
		_iso_box(ci, p + Vector2(sx, 0) - Vector2(0, 5), av * 0.5, fv * 0.5, 0.5, 0.5, 10.0,
				TIMBER.lightened(0.1), TIMBER, TIMBER.darkened(0.2))
	for k in range(3):
		ci.draw_line(p + Vector2(-6.5, -float(k) * 3.5 - 3.0),
				p + Vector2(6.5, -float(k) * 3.5 - 3.0), TIMBER.lightened(0.15), 1.0)
	for i in range(3):
		var sp := p + Vector2(-5.5 + float(i) * 4.0, -3.5)
		draw_safe_quad(ci, sp, sp + Vector2(3.5, 0),
				sp + Vector2(3.5, -6.0), sp + Vector2(0, -6.0),
				Color("f7f3e8", 0.88))
		ci.draw_rect(Rect2(sp + Vector2(0, -6.0), Vector2(3.5, 6.0)),
				Color("c8c0a8", 0.5), false, 0.5)

## 갓 진열 — 아이소메트릭 챙+탕건 실루엣
static func hats(ci: CanvasItem, p: Vector2) -> void:
	var av := Vector2(2.0, 0.9)
	var fv := Vector2(-1.2, 0.9)
	for i in range(3):
		var q := p + Vector2(-4.5 + float(i) * 4.5, -float(i % 2) * 1.2)
		_iso_cyl(ci, q, av * 1.2, fv * 0.6, 2.8, 0.5, Color("181818"), Color("252525"), 8)
		_iso_cyl(ci, q - Vector2(0, 0.5), av * 0.5, fv * 0.25, 1.0, 2.6,
				Color("1c1c1c"), Color("202020"), 6)
		draw_safe_tri(ci, q - av * 0.5 - Vector2(0, 3.1),
				q + av * 0.5 - Vector2(0, 3.1),
				q - Vector2(0, 4.5), Color("141414"))
		FastDraw.circle(ci, q - av * 0.3 - Vector2(0, 1.0), 0.4, Color("3a3a3a"))

## 붓 걸이대 — 아이소메트릭 가로대 + 붓 실루엣
static func brushes(ci: CanvasItem, p: Vector2) -> void:
	var av := Vector2(2.0, 0.9)
	var fv := Vector2(-1.2, 0.9)
	_iso_box(ci, p - Vector2(0, 8), av * 3.5, fv * 0.5, 3.5, 0.5, 0.8,
			TIMBER.lightened(0.15), TIMBER, TIMBER.darkened(0.15))
	for i in range(6):
		var x := -4.5 + float(i) * 1.8
		_iso_cyl(ci, p + Vector2(x, -1.5), Vector2(2.0, 0.9).normalized() * 0.35,
				Vector2(-1.2, 0.9).normalized() * 0.2, 0.35, 6.5,
				Color("c8a064"), Color("d8b070"), 5)
		draw_safe_tri(ci, p + Vector2(x - 0.5, -1.5), p + Vector2(x + 0.5, -1.5),
				p + Vector2(x, 0.8), Color("1a1a1a"))
		FastDraw.circle(ci, p + Vector2(x, 0.6), 0.3, Color("f0f0f0"))

## 물독 — 아이소메트릭 도기 + 물 표면
static func water_jars(ci: CanvasItem, p: Vector2) -> void:
	var av := Vector2(2.0, 0.9)
	var fv := Vector2(-1.2, 0.9)
	for i in range(3):
		var q := p + Vector2(-4.5 + float(i) * 4.5, 0)
		_iso_cyl(ci, q, av, fv, 2.6, 4.0, Color("4a3020"), Color("3a2418"), 8)
		_iso_cyl(ci, q - Vector2(0, 4.0), av * 0.6, fv * 0.6, 1.5, 1.2,
				Color("3a2418"), Color("2e1c12"), 6)
		var water_pts: PackedVector2Array = PackedVector2Array()
		for k in range(8):
			var ang := TAU * float(k) / 8.0
			water_pts.append(q + av * cos(ang) * 1.4 + fv * sin(ang) * 0.7 - Vector2(0, 5.0))
		FastDraw.poly(ci, water_pts, Color("4a8fb0"))
		FastDraw.circle(ci, q - av * 0.4 - Vector2(0, 5.3), 0.5, Color("8ad0f0"))

## 목재 사다리 — 아이소메트릭 기울기 표현
static func ladder(ci: CanvasItem, p: Vector2) -> void:
	var lb := p + Vector2(0, 0)
	var lt := p + Vector2(3.5, -16)
	var rb := p + Vector2(3.0, 0)
	var rt := p + Vector2(6.5, -16)
	ci.draw_line(lb, lt, TIMBER, 1.3)
	ci.draw_line(rb, rt, TIMBER, 1.3)
	for k in range(1, 6):
		var t := float(k) / 6.0
		ci.draw_line(lb.lerp(lt, t), rb.lerp(rt, t), TIMBER.lightened(0.1), 1.0)

# ---------------------------------------------------------------- 조립: 상점
## 상점 한 칸. trade = YUK_TRADES/NAN_SMALL/NAN_BIG 중 하나, big = com_2(큰 가게)
## PORT-TRACE [상점 외형 다양화]: variant 1이면 벽 없이 기둥에 지붕만 얹은 "열린 가게"(지붕 아래로 물건이 다 보임),
## 그 밖엔 앞이 트인 벽체 가게. 업종 25가지 x 외형 2~3가지로 거리가 단조롭지 않게.
static func draw_shop(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, trade: String, big: bool, variant: int = 0) -> void:
	_draw_shop_body(ci, o, a, f, trade, big, variant)
	# PORT-TRACE [화서문 어염시장]: 어물·소금 가게는 가게 옆에 덕장(조기·북어·굴비 꾸러미)·대바구니·가마니를 늘어놓아
	# 다른 시장과 한눈에 구분되게 한다
	if trade == "fish" or trade == "salt":
		_seafood_props(ci, o, a, f, trade)

static func _draw_shop_body(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, trade: String, big: bool, variant: int = 0) -> void:
	# 가게 앞 흙마당(또는 박석)
	var yard_col := Color("b7a27a") if not (trade in YUK_TRADES) else Color("cdbf9e")
	FastDraw.poly(ci, PackedVector2Array([P(o, a, f, -0.9, -0.9), P(o, a, f, 0.9, -0.9), P(o, a, f, 0.9, 0.9), P(o, a, f, -0.9, 0.9)]), yard_col)
	var sign_base := P(o, a, f, 0.86, 0.78)
	var ch: String = SIGN_CHARS.get(trade, "")
	if trade == "gaekju":
		# 객주: 붉은 기와 ㄱ자 큰 집 + 마당의 짐짝(곡식 가마·옹기) + 짐 부리는 수레 자리
		var ow := o + a * -0.55 + f * -0.1
		box(ci, ow, f, a, 0.6, 0.3, 0.0, 11.0, WALL_PLASTER)
		roof(ci, ow, f, a, 0.78, 0.48, 0.35, 10.0, 18.0, ROOF_RED)
		var ob0 := o + a * 0.2 + f * -0.4
		box(ci, ob0, a, f, 0.62, 0.36, 0.0, 12.0, WALL_PLASTER, true)
		roof(ci, ob0, a, f, 0.82, 0.58, 0.4, 11.0, 20.0, ROOF_RED)
		sacks(ci, P(o, a, f, 0.1, 0.45))
		jars(ci, P(o, a, f, 0.55, 0.6), 3)
		sacks(ci, P(o, a, f, -0.2, 0.7))
		sign_flag(ci, sign_base, ch, Color("f6efd8"))
		return
	if trade == "cattle":
		_cattle_yard(ci, o, a, f, big)
		sign_flag(ci, sign_base, ch, Color("f6efd8"))
		return
	if trade == "jeotgal":
		_jeotgal_stall(ci, o, a, f, big)
		sign_flag(ci, sign_base, ch, Color("f6efd8"))
		return
	if trade == "lumber":
		_lumber_yard(ci, o, a, f, big)
		sign_flag(ci, sign_base, ch, Color("f6efd8"))
		return
	if variant % 3 == 1 and not big and not (trade in ["tent", "pottery", "gukbap", "jumak", "herb"]):
		_open_shed(ci, o, a, f, trade, trade in YUK_TRADES)
		sign_flag(ci, sign_base, ch, Color("f6efd8"))
		return
	if trade in YUK_TRADES or trade in GATE_TILED:
		_draw_yuk_shop(ci, o, a, f, trade, big)
		sign_flag(ci, sign_base, ch, Color("f6efd8"))
		return
	match trade:
		"tent":
			var cloth := Color("efe8d6")
			mat(ci, o, a, f, -0.35, 0.2, 0.4, 0.35)
			tent(ci, o + a * -0.3 + f * 0.05, a, f, 0.55, 0.55, 10.0, cloth)
			_goods_front(ci, o, a, f, "veg", -0.35, 0.45)
			mat(ci, o, a, f, 0.5, 0.35, 0.3, 0.3)
			tent(ci, o + a * 0.5 + f * 0.25, a, f, 0.35, 0.4, 8.0, Color("d9c9a3"))
			_goods_front(ci, o, a, f, "shoes" if not big else "rice", 0.5, 0.5)
		"pottery":
			# 기둥만 세운 초가 헛간 + 옹기 무더기
			for su: float in [-0.6, 0.6]:
				for sv: float in [-0.55, 0.15]:
					ci.draw_line(P(o, a, f, su, sv), P(o, a, f, su, sv, 10.0), TIMBER, 1.2)
			jars(ci, P(o, a, f, 0.0, -0.25), 6, big)
			roof(ci, o + f * -0.2, a, f, 0.78, 0.55, 0.3, 9.0, 15.0, ROOF_RED if big else THATCH, not big)
			jars(ci, P(o, a, f, -0.3, 0.6), 3)
			jars(ci, P(o, a, f, 0.45, 0.55), 2, true)
		"gukbap":
			var ob := o + f * -0.3
			box(ci, ob, a, f, 0.7, 0.4, 0.0, 11.0, WALL_PLASTER, true)
			roof(ci, ob, a, f, 0.9, 0.62, 0.45, 10.0, 19.0, ROOF_RED)
			table(ci, o, a, f, -0.35, 0.45, 0.28, 0.18)
			table(ci, o, a, f, 0.15, 0.55, 0.22, 0.16)
			cauldron(ci, P(o, a, f, 0.6, 0.45))
		"jumak":
			var ob2 := o + f * -0.35 + a * 0.15
			box(ci, ob2, a, f, 0.6, 0.38, 0.0, 10.0, WALL_PLASTER, true)
			roof(ci, ob2, a, f, 0.8, 0.6, 0.35, 9.0, 17.0, THATCH, true)
			# 옆채(부엌) — 길과 수직으로
			var ow := o + a * -0.62 + f * 0.1
			box(ci, ow, f, a, 0.4, 0.25, 0.0, 8.0, WALL_PLASTER)
			roof(ci, ow, f, a, 0.55, 0.42, 0.2, 7.0, 13.0, THATCH, true)
			table(ci, o, a, f, 0.25, 0.5, 0.3, 0.2)
			jars(ci, P(o, a, f, -0.25, 0.7), 2)
			# 주막 등(燈)과 "酒" 깃발
			sign_flag(ci, sign_base, "酒", Color("f6efd8"))
			FastDraw.circle(ci, P(o, a, f, 0.72, 0.1, 12.0), 1.8, Color("e8453a"))
			return
		"herb":
			var ob3 := o + f * -0.3
			var fr := box(ci, ob3, a, f, 0.68, 0.4, 0.0, 11.0, WALL_PLASTER, true)
			if fr.size() == 4:
				# 약장(서랍장)
				for k in range(1, 4):
					ci.draw_line(fr[0].lerp(fr[3], float(k) / 4.0), fr[1].lerp(fr[2], float(k) / 4.0), Color("8a6a42"), 0.6)
				for k in range(1, 5):
					ci.draw_line(fr[0].lerp(fr[1], float(k) / 5.0), fr[3].lerp(fr[2], float(k) / 5.0), Color("8a6a42"), 0.6)
			roof(ci, ob3, a, f, 0.88, 0.62, 0.45, 10.0, 19.0, ROOF_RED)
			baskets(ci, P(o, a, f, -0.1, 0.55), [Color("7a8a3a"), Color("a8743a"), Color("5a7a3a")])
		_:
			# 초가 간이 상점(싸전·채소전·육전·갖신전). 큰 가게(com_2)로 승급하면 회벽 + 붉은 기와 가게
			var ob4 := o + f * -0.28
			var sz := 0.66 if big else 0.58
			box(ci, ob4, a, f, sz, 0.38, 0.0, 10.0 if big else 9.0, WALL_PLASTER if big else Color("d9c9a6"), true)
			if big:
				roof(ci, ob4, a, f, sz + 0.22, 0.64, sz * 0.6, 10.0, 18.0, ROOF_RED)
			else:
				roof(ci, ob4, a, f, sz + 0.2, 0.62, 0.25, 8.0, 15.0, THATCH, true)
			awning(ci, o, a, f, sz * 0.9, 0.12, 0.42, 8.0, 6.0, Color("a88a5a"))
			table(ci, o, a, f, 0.0, 0.58, 0.45, 0.16, 2.5)
			_goods_front(ci, o, a, f, trade, 0.0, 0.58)
			if big:
				_goods_front(ci, o, a, f, trade, -0.6, 0.72)
	sign_flag(ci, sign_base, ch)

## 열린 가게: 네 기둥 + 지붕(기와 또는 초가), 벽 없이 지붕 아래 매대 두 줄에 물건이 훤히 보인다
static func _open_shed(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, trade: String, tiled: bool) -> void:
	var ob := o + f * -0.15
	var posts: Array = []
	for su: float in [-0.62, 0.62]:
		for sv: float in [-0.55, 0.35]:
			posts.append([P(ob, a, f, su, sv), P(ob, a, f, su, sv, 11.0)])
	posts.sort_custom(func(p, q): return (p[0] as Vector2).y < (q[0] as Vector2).y)
	# 뒤쪽 기둥 → 매대·물건 → 앞쪽 기둥 → 지붕
	for i in range(2):
		ci.draw_line(posts[i][0], posts[i][1], TIMBER, 1.3)
	table(ci, ob, a, f, 0.0, -0.25, 0.5, 0.15, 3.0)
	_goods_front(ci, ob, a, f, trade, 0.0, -0.25)
	table(ci, o, a, f, 0.0, 0.55, 0.5, 0.15, 2.5)
	_goods_front(ci, o, a, f, trade, 0.0, 0.55)
	for i in range(2, 4):
		ci.draw_line(posts[i][0], posts[i][1], TIMBER, 1.3)
	roof(ci, ob + f * -0.1, a, f, 0.8, 0.62, 0.35, 11.0, 17.0, ROOF_RED if tiled else THATCH, not tiled)

## 육의전: 붉은 기와 가게, 앞이 트인 진열칸 + 차양 + 매대. big이면 뒤로 곳간채가 붙은 ㄱ자.
static func _draw_yuk_shop(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, trade: String, big: bool) -> void:
	if big:
		var ow := o + a * -0.55 + f * -0.15
		box(ci, ow, f, a, 0.55, 0.28, 0.0, 10.0, WALL_PLASTER)
		roof(ci, ow, f, a, 0.72, 0.46, 0.3, 9.0, 16.0, ROOF_RED)
	var ob := o + f * -0.3 + (a * 0.18 if big else Vector2.ZERO)
	var bu := 0.62 if big else 0.72
	var fr := box(ci, ob, a, f, bu, 0.4, 0.0, 12.0, WALL_PLASTER, true)
	if fr.size() == 4:
		# 진열 선반(두 단) + 선반 위 상품
		for k: float in [0.35, 0.68]:
			ci.draw_line(fr[0].lerp(fr[3], k), fr[1].lerp(fr[2], k), Color("9a7248"), 0.9)
		var mid_low := (fr[0].lerp(fr[3], 0.35) + fr[1].lerp(fr[2], 0.35)) * 0.5
		_goods_front(ci, o, a, f, trade, 0.0, 0.0, mid_low + Vector2(0, 1))
	roof(ci, ob, a, f, bu + 0.2, 0.64, bu * 0.6, 11.0, 20.0, ROOF_RED)
	awning(ci, o + (a * 0.18 if big else Vector2.ZERO), a, f, bu * 0.95, 0.12, 0.45, 10.0, 7.5, Color("b4895a"))
	table(ci, o, a, f, 0.05, 0.6, 0.5, 0.16, 3.0)
	_goods_front(ci, o, a, f, trade, 0.05, 0.6)

## 매대 위(또는 at 좌표) 상품
static func _goods_front(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, trade: String, u: float, v: float, at: Vector2 = Vector2.INF) -> void:
	var p := P(o, a, f, u, v, 3.0) if at == Vector2.INF else at
	match trade:
		"silk": bolts(ci, p, [Color("c0392b"), Color("2e86c1"), Color("f4d03f"), Color("8e44ad"), Color("16a085"), Color("e67e22")])
		"cotton": bolts(ci, p, [Color("f4f1e8"), Color("ece6d6"), Color("f4f1e8"), Color("e2dac6"), Color("f4f1e8")])
		"myeonju": bolts(ci, p, [Color("f3e5c8"), Color("e8d0d8"), Color("d8e4f0"), Color("f3e5c8"), Color("efe0b0")])
		"ramie": bolts(ci, p, [Color("d8ccaa"), Color("cfc29c"), Color("d8ccaa"), Color("c4b690")])
		"paper": paper_stack(ci, p)
		"fish": fish_rack(ci, p + Vector2(0, 2))
		"rice": sacks(ci, p)
		"veg": baskets(ci, p, [Color("4f9a3a"), Color("c0392b"), Color("e8c040")])
		"meat": meat_hang(ci, p + Vector2(0, 2))
		"shoes": shoes(ci, p)
		"pottery": jars(ci, p, 3)
		"yugi": brassware(ci, p)
		"bangmul":
			# 방물: 색실 타래·빗·노리개가 걸린 횃대
			ci.draw_line(p + Vector2(-6, -9), p + Vector2(6, -9), TIMBER, 1.0)
			var cs: Array[Color] = [Color("c0392b"), Color("e8b820"), Color("2e86c1"), Color("8e44ad"), Color("16a085")]
			for i in range(5):
				ci.draw_line(p + Vector2(-5 + i * 2.5, -9), p + Vector2(-5 + i * 2.5, -4), cs[i], 1.2)
				FastDraw.circle(ci, p + Vector2(-5 + i * 2.5, -3.5), 0.8, cs[(i + 2) % 5])
		"fruit": baskets(ci, p, [Color("e0702a"), Color("c0392b"), Color("e8c040")])
		"tteok":
			for i in range(3):
				var q := p + Vector2(-6 + i * 4.5, -(i % 2) * 1.0)
				ci.draw_rect(Rect2(q + Vector2(-1.8, -2.4), Vector2(3.6, 2.4)), [Color("f4f0e4"), Color("e88aa8"), Color("8fbf5a")][i])
				ci.draw_rect(Rect2(q + Vector2(-1.8, -2.4), Vector2(3.6, 2.4)), Color("8a7a5a"), false, 0.5)
		"jipsin":
			for i in range(3):
				var q2 := p + Vector2(-6 + i * 4.5, -(i % 2) * 1.0)
				FastDraw.poly(ci, PackedVector2Array([q2, q2 + Vector2(3, 0), q2 + Vector2(3.4, -1.2), q2 + Vector2(0.4, -1.2)]), Color("d8b86a"))
			ci.draw_rect(Rect2(p + Vector2(5, -4), Vector2(3, 4)), Color("c8a85a")) # 말아 둔 멍석
		"salt":
			for i in range(3):
				var q3 := p + Vector2(-5 + i * 5.0, 0)
				FastDraw.circle(ci, q3, 2.4, Color("8a6236"))
				FastDraw.circle(ci, q3 + Vector2(0, -1.6), 2.0, Color("f8f8f4"))
		"book":
			# 서책: 푸른·누런 표지 책 더미(오침 안정법 실 매듭)
			for i in range(4):
				var bq := p + Vector2(-6 + (i % 2) * 6.5, -(float(i) / 2.0) * 2.6)
				ci.draw_rect(Rect2(bq + Vector2(0, -2.2), Vector2(5.4, 2.2)), [Color("2e4a7a"), Color("c8a860"), Color("3a5a3a"), Color("2e4a7a")][i])
				ci.draw_line(bq + Vector2(0.6, -2.2), bq + Vector2(0.6, 0), Color("f0e8d0"), 0.5)
		"jeotgal":
			# 젓갈 독(뚜껑 위 새우젓 분홍) + 짚 꾸러미
			for i in range(3):
				var jq := p + Vector2(-5 + i * 5.0, -(i % 2) * 1.0)
				FastDraw.circle(ci, jq + Vector2(0, -2.2), 2.4, Color("5e3a22"))
				FastDraw.circle(ci, jq + Vector2(0, -4.2), 1.5, Color("e8a0a0"))
			ci.draw_rect(Rect2(p + Vector2(6, -5), Vector2(2.6, 5)), Color("d8b86a"))
			ci.draw_line(p + Vector2(6, -2.5), p + Vector2(8.6, -2.5), Color("8a6a2a"), 0.6)
		"firewood":
			# 장작더미(통나무 단면) + 숯 섬
			for i in range(6):
				var fq := p + Vector2(-6 + (i % 3) * 2.8, -(float(i) / 3.0) * 2.6)
				FastDraw.circle(ci, fq + Vector2(0, -1.3), 1.4, Color("a8784a"))
				FastDraw.circle(ci, fq + Vector2(0, -1.3), 0.6, Color("d8b080"))
			FastDraw.circle(ci, p + Vector2(5, -2), 2.6, Color("2a2420"))
			FastDraw.circle(ci, p + Vector2(5.6, -2.8), 0.8, Color("4a4440"))
		"lumber":
			for i in range(3):
				ci.draw_line(p + Vector2(-7, -1.5 - i * 2.2), p + Vector2(6, -2.5 - i * 2.2), Color("8a5a32"), 2.0)
		"cattle":
			_cow(ci, p + Vector2(0, 1), 0.7, Color("8a5a32"))
		"tobacco":
			ci.draw_line(p + Vector2(-6, -10), p + Vector2(6, -10), TIMBER, 1.0)
			for i in range(4):
				FastDraw.poly(ci, PackedVector2Array([p + Vector2(-4.5 + i * 3, -10), p + Vector2(-3 + i * 3, -10), p + Vector2(-3.7 + i * 3, -4)]), Color("8a5a28"))
		_: sacks(ci, p)

## 덕장(나무 걸대)에 매단 조기(누런)·북어(잿빛) + 볏짚에 엮은 굴비 꾸러미, 대바구니, (소금전이면) 가마니
static func _seafood_props(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, trade: String) -> void:
	var r0 := P(o, a, f, -0.85, 0.25)
	var r1 := P(o, a, f, -0.85, 0.85)
	ci.draw_line(r0, r0 - Vector2(0, 13), TIMBER, 1.1)
	ci.draw_line(r1, r1 - Vector2(0, 13), TIMBER, 1.1)
	ci.draw_line(r0 - Vector2(0, 13), r1 - Vector2(0, 13), TIMBER, 1.0)
	for i in range(5):
		var q: Vector2 = (r0 - Vector2(0, 13)).lerp(r1 - Vector2(0, 13), (float(i) + 0.5) / 5.0)
		var col := Color("d8b24a") if i % 2 == 0 else Color("9a9a92")
		ci.draw_line(q, q + Vector2(0, 5.5), col, 1.5)
		FastDraw.poly(ci, PackedVector2Array([q + Vector2(-1, 5.5), q + Vector2(1, 5.5), q + Vector2(0, 7.2)]), col.darkened(0.2))
	# 굴비 꾸러미(짚 끈에 줄줄이)
	var g := P(o, a, f, 0.85, 0.85)
	ci.draw_line(g, g - Vector2(0, 11), TIMBER, 1.0)
	for k in range(4):
		ci.draw_line(g + Vector2(1, -10 + k * 2.4), g + Vector2(4.5, -10 + k * 2.4), Color("d8b24a"), 1.4)
	ci.draw_line(g + Vector2(1, -11), g + Vector2(1, -2), Color("c8a85a"), 0.6)
	if trade == "salt":
		for k in range(2):
			var sq := P(o, a, f, 0.55 - 0.3 * float(k), 0.92)
			FastDraw.poly(ci, PackedVector2Array([sq + Vector2(-3.2, 0), sq + Vector2(3.2, 0), sq + Vector2(2.8, -3.6), sq + Vector2(-2.8, -3.6)]), Color("d8c48a"))
			FastDraw.circle(ci, sq + Vector2(0, -3.7), 1.4, Color("fafaf6"))
	else:
		baskets(ci, P(o, a, f, 0.35, 0.92), [Color("b8c4cc"), Color("d8b24a")])

## 젓갈 난전: 돌 깐 장독대에 큰 옹기독이 두 줄로 늘어서고 뚜껑은 짚 고깔로 봉함, 뒤로 초가(큰 가게면 기와) 차양
static func _jeotgal_stall(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, big: bool) -> void:
	draw_safe_quad(ci, P(o, a, f, -0.8, -0.35), P(o, a, f, 0.8, -0.35), P(o, a, f, 0.8, 0.75), P(o, a, f, -0.8, 0.75), Color("a8a49a"))
	for su: float in [-0.7, 0.7]:
		ci.draw_line(P(o, a, f, su, -0.6), P(o, a, f, su, -0.6, 12.0), TIMBER, 1.2)
	roof(ci, o + f * -0.55, a, f, 0.85, 0.35, 0.4, 11.0, 15.0, ROOF_RED if big else THATCH, not big)
	for row in range(2):
		var cols := 4 if big else 3
		for k in range(cols):
			var u := -0.6 + 1.2 * float(k) / float(cols - 1)
			var q := P(o, a, f, u, -0.05 + 0.5 * float(row))
			var r := 3.4 if row == 0 else 3.0
			FastDraw.circle(ci, q + Vector2(0, -r), r, Color("5e3a22"))
			FastDraw.circle(ci, q + Vector2(-r * 0.35, -r * 1.3), r * 0.35, Color("8a5a38"))
			# 짚 고깔 뚜껑
			FastDraw.poly(ci, PackedVector2Array([q + Vector2(-r * 0.8, -r * 1.8), q + Vector2(r * 0.8, -r * 1.8), q + Vector2(0, -r * 2.9)]), Color("d8b85a"))
			ci.draw_line(q + Vector2(-r * 0.8, -r * 1.8), q + Vector2(r * 0.8, -r * 1.8), Color("a8883a"), 0.7)

## 소 한 마리(옆모습, s = 크기)
static func _cow(ci: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	FastDraw.circle(ci, p + Vector2(0, 0.5), 6.0 * s, Color(0, 0, 0, 0.18))
	for lx: float in [-5.0, -3.0, 3.0, 5.0]:
		ci.draw_line(p + Vector2(lx, -3) * s, p + Vector2(lx, 0) * s, col.darkened(0.3), 1.4 * s)
	FastDraw.poly(ci, PackedVector2Array([p + Vector2(-7, -3) * s, p + Vector2(6, -3) * s, p + Vector2(6, -9) * s, p + Vector2(-7, -9) * s]), col)
	FastDraw.circle(ci, p + Vector2(8, -8) * s, 2.8 * s, col)
	FastDraw.circle(ci, p + Vector2(9.6, -7) * s, 1.2 * s, Color("d8a888"))
	ci.draw_line(p + Vector2(7, -10.5) * s, p + Vector2(6, -12.5) * s, Color("e8e0c8"), 0.9 * s)
	ci.draw_line(p + Vector2(9, -10.5) * s, p + Vector2(10, -12.5) * s, Color("e8e0c8"), 0.9 * s)
	ci.draw_line(p + Vector2(-7, -8) * s, p + Vector2(-9, -4) * s, col.darkened(0.3), 0.9 * s)

## 쇠전(우시장): 건물 없이 말뚝 울타리 친 공터에 소를 매어 두고, 구석에 여물 더미와 거간꾼 초막
static func _cattle_yard(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, big: bool) -> void:
	FastDraw.poly(ci, PackedVector2Array([P(o, a, f, -0.92, -0.92), P(o, a, f, 0.92, -0.92), P(o, a, f, 0.92, 0.92), P(o, a, f, -0.92, 0.92)]), Color("a8946a"))
	# 뒤쪽 초막(거간꾼 자리)
	var oh := o + a * -0.5 + f * -0.55
	box(ci, oh, a, f, 0.32, 0.25, 0.0, 7.0, Color("d9c9a6"))
	roof(ci, oh, a, f, 0.45, 0.4, 0.15, 6.0, 11.0, ROOF_RED if big else THATCH, not big)
	# 여물 더미
	FastDraw.circle(ci, P(o, a, f, 0.55, -0.55, 2.0), 4.0, Color("d8b85a"))
	FastDraw.circle(ci, P(o, a, f, 0.5, -0.6, 4.5), 2.6, Color("e8cc70"))
	# 소 매는 가로대 + 소들
	ci.draw_line(P(o, a, f, -0.7, 0.0, 5.0), P(o, a, f, 0.7, 0.0, 5.0), TIMBER, 1.1)
	var cows: Array = [[-0.4, 0.15], [0.3, 0.1]]
	if big:
		cows.append([0.0, 0.55])
	for c: Array in cows:
		_cow(ci, P(o, a, f, float(c[0]), float(c[1])), 0.75, Color("8a5a32") if int(c[0] * 10.0) % 2 == 0 else Color("6a4026"))
	# 앞 울타리 말뚝
	for k in range(5):
		var u := -0.85 + float(k) * 0.425
		ci.draw_line(P(o, a, f, u, 0.88), P(o, a, f, u, 0.88, 5.0), TIMBER, 1.0)
	ci.draw_line(P(o, a, f, -0.85, 0.88, 3.5), P(o, a, f, 0.85, 0.88, 3.5), TIMBER, 0.8)

## 목재전: 마당에 통나무 더미·켠 판재, 뒤로 헛간(큰 가게면 기와), 톱질 모탕
static func _lumber_yard(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, big: bool) -> void:
	FastDraw.poly(ci, PackedVector2Array([P(o, a, f, -0.92, -0.92), P(o, a, f, 0.92, -0.92), P(o, a, f, 0.92, 0.92), P(o, a, f, -0.92, 0.92)]), Color("b09a72"))
	var ob := o + f * -0.45
	box(ci, ob, a, f, 0.6, 0.3, 0.0, 9.0, Color("c8b48a") if not big else WALL_PLASTER, true)
	roof(ci, ob, a, f, 0.78, 0.5, 0.3, 8.0, 14.0, ROOF_RED if big else THATCH, not big)
	# 통나무 더미(단면 원이 보이게 길 쪽으로 쌓음)
	for i in range(6 if big else 4):
		var row := int(float(i) / 3.0)
		var q := P(o, a, f, -0.55 + float(i % 3) * 0.22 + float(row) * 0.11, 0.35, 2.6 + float(row) * 4.0)
		FastDraw.circle(ci, q, 2.4, Color("9a6a3a"))
		FastDraw.circle(ci, q, 1.2, Color("d8b080"))
	# 판재 더미
	for k in range(3):
		ci.draw_line(P(o, a, f, 0.2, 0.55, 1.0 + k * 1.4), P(o, a, f, 0.8, 0.45, 1.0 + k * 1.4), Color("c89a60"), 2.0)
	# 모탕 + 도끼
	var m := P(o, a, f, 0.55, 0.0)
	ci.draw_rect(Rect2(m + Vector2(-2, -3), Vector2(4, 3)), Color("7a5030"))
	ci.draw_line(m + Vector2(0, -3), m + Vector2(3, -8), TIMBER, 0.9)

# ---------------------------------------------------------------- 조립: 공방
static func draw_workshop(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, trade: String, big: bool) -> void:
	FastDraw.poly(ci, PackedVector2Array([P(o, a, f, -0.9, -0.9), P(o, a, f, 0.9, -0.9), P(o, a, f, 0.9, 0.9), P(o, a, f, -0.9, 0.9)]), Color("9a8260"))
	var ch: String = SIGN_CHARS.get(trade, "")
	if big:
		# 관영 공방: 담장으로 두른 마당 + 작업채 두 동
		wall_seg(ci, o, a, f, -0.9, 0.9, -0.88, 7.0)
		wall_seg(ci, o, a, f, -0.88, 0.2, -0.88, 7.0, true)
		wall_seg(ci, o, a, f, -0.88, 0.2, 0.88, 7.0, true)
		var ow := o + a * -0.5 + f * -0.35
		box(ci, ow, f, a, 0.42, 0.3, 0.0, 10.0, Color("d4c4a0"), false)
		roof(ci, ow, f, a, 0.58, 0.48, 0.25, 9.0, 16.0, ROOF_SLATE)
		var ob := o + a * 0.3 + f * -0.45
		box(ci, ob, a, f, 0.5, 0.3, 0.0, 10.0, Color("d4c4a0"), true)
		roof(ci, ob, a, f, 0.66, 0.5, 0.3, 9.0, 16.0, ROOF_SLATE)
		_workshop_props(ci, o, a, f, trade, true)
	else:
		var ob2 := o + f * -0.4
		var thatch: bool = trade in ["gat", "shoe", "hanji", "brush"]
		box(ci, ob2, a, f, 0.62, 0.34, 0.0, 9.0, Color("d4c4a0"), true)
		roof(ci, ob2, a, f, 0.8, 0.56, 0.3, 8.0, 15.0, THATCH if thatch else ROOF_RED, thatch)
		_workshop_props(ci, o, a, f, trade, false)
	sign_flag(ci, P(o, a, f, 0.88, 0.8), ch, Color("efe6cc"))

static func _workshop_props(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, trade: String, big: bool) -> void:
	match trade:
		"brass":
			forge(ci, P(o, a, f, -0.35, 0.35))
			brassware(ci, P(o, a, f, 0.35, 0.6))
			if big:
				chimney(ci, P(o, a, f, -0.7, 0.05), 20.0)
				brassware(ci, P(o, a, f, -0.1, 0.75))
		"onggi":
			kiln(ci, P(o, a, f, -0.35, 0.3), 8.0 if big else 6.5)
			jars(ci, P(o, a, f, 0.35, 0.55), 5 if big else 3, big)
			if big:
				kiln(ci, P(o, a, f, 0.1, 0.05), 6.0)
				jars(ci, P(o, a, f, -0.3, 0.8), 3)
		"smith":
			forge(ci, P(o, a, f, -0.3, 0.4))
			chimney(ci, P(o, a, f, -0.55, 0.05), 16.0 if big else 12.0)
			if big:
				forge(ci, P(o, a, f, 0.3, 0.6))
		"gat":
			table(ci, o, a, f, 0.0, 0.55, 0.45, 0.16)
			hats(ci, P(o, a, f, 0.0, 0.55, 3.0))
		"shoe":
			table(ci, o, a, f, 0.0, 0.55, 0.45, 0.16)
			shoes(ci, P(o, a, f, 0.0, 0.55, 3.0))
		"brush":
			brushes(ci, P(o, a, f, -0.25, 0.55))
			paper_stack(ci, P(o, a, f, 0.4, 0.6))
		"bow":
			bow_rack(ci, P(o, a, f, -0.3, 0.5))
			if big:
				bow_rack(ci, P(o, a, f, 0.35, 0.55))
		"hanji":
			drying_frame(ci, P(o, a, f, -0.2, 0.5))
			# 닥풀 통(지통)
			ci.draw_rect(Rect2(P(o, a, f, 0.5, 0.6) + Vector2(-4, -4), Vector2(8, 4)), Color("6e4a2c"))
			ci.draw_rect(Rect2(P(o, a, f, 0.5, 0.6) + Vector2(-3.4, -3.8), Vector2(6.8, 1.4)), Color("c8dde0"))
			if big:
				drying_frame(ci, P(o, a, f, 0.35, 0.8))

# ---------------------------------------------------------------- 조립: 공공시설
## kind: "well"/"patrol"/"firefighter", variant 0~2
static func draw_public(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, kind: String, variant: int) -> void:
	match kind:
		"well":
			match variant % 3:
				0: # 단독 우물 — 돌우물 + 도르래 틀
					var wc := P(o, a, f, 0.0, 0.1)
					FastDraw.circle(ci, wc + Vector2(0, -2), 6.0, Color("8f8a80"))
					FastDraw.circle(ci, wc + Vector2(0, -3), 4.2, Color("2a4a5a"))
					FastDraw.arc(ci, wc + Vector2(0, -2), 6.0, 0, TAU, 14, Color("5e5a52"), 1.0)
					ci.draw_line(wc + Vector2(-6, -2), wc + Vector2(-6, -14), TIMBER, 1.2)
					ci.draw_line(wc + Vector2(6, -2), wc + Vector2(6, -14), TIMBER, 1.2)
					ci.draw_line(wc + Vector2(-7, -14), wc + Vector2(7, -14), TIMBER, 1.4)
					ci.draw_line(wc + Vector2(1, -14), wc + Vector2(1, -7), Color("c8b48a"), 0.6)
					ci.draw_rect(Rect2(wc + Vector2(-0.5, -8), Vector2(3, 2.4)), Color("6e4a2c"))
				1: # 지붕 우물 — 네모 우물 위 작은 기와 정자
					var sq := PackedVector2Array([P(o, a, f, -0.3, -0.3, 3.0), P(o, a, f, 0.3, -0.3, 3.0), P(o, a, f, 0.3, 0.3, 3.0), P(o, a, f, -0.3, 0.3, 3.0)])
					box(ci, o, a, f, 0.3, 0.3, 0.0, 3.0, Color("9a948a"))
					FastDraw.poly(ci, PackedVector2Array([sq[0].lerp(sq[2], 0.15), sq[1].lerp(sq[3], 0.15), sq[2].lerp(sq[0], 0.15), sq[3].lerp(sq[1], 0.15)]), Color("2a4a5a"))
					for su: float in [-0.42, 0.42]:
						for sv: float in [-0.42, 0.42]:
							ci.draw_line(P(o, a, f, su, sv), P(o, a, f, su, sv, 13.0), Color("8a2e22"), 1.2)
					roof(ci, o, a, f, 0.6, 0.6, 0.12, 12.0, 19.0, ROOF_SLATE)
				_: # 공동 우물 — 박석 마당 + 우물 + 물구유(빨래터)
					FastDraw.poly(ci, PackedVector2Array([P(o, a, f, -0.85, -0.85), P(o, a, f, 0.85, -0.85), P(o, a, f, 0.85, 0.85), P(o, a, f, -0.85, 0.85)]), Color("b8b0a0"))
					for k: float in [-0.4, 0.0, 0.4]:
						ci.draw_line(P(o, a, f, -0.85, k), P(o, a, f, 0.85, k), Color("a09888"), 0.6)
					var wc2 := P(o, a, f, -0.35, -0.25)
					FastDraw.circle(ci, wc2 + Vector2(0, -2), 5.0, Color("8f8a80"))
					FastDraw.circle(ci, wc2 + Vector2(0, -3), 3.4, Color("2a4a5a"))
					box(ci, o + a * 0.3 + f * 0.35, a, f, 0.45, 0.12, 0.0, 3.0, Color("8f8a80"))
					var tq := PackedVector2Array([P(o, a, f, -0.12, 0.28, 3.0), P(o, a, f, 0.72, 0.28, 3.0), P(o, a, f, 0.72, 0.42, 3.0), P(o, a, f, -0.12, 0.42, 3.0)])
					FastDraw.poly(ci, tq, Color("4a8fb0"))
		"patrol":
			_compound(ci, o, a, f, ROOF_SLATE)
			# 창 거치대
			for i in range(3):
				var sp := P(o, a, f, 0.35 + i * 0.12, 0.6)
				ci.draw_line(sp, sp - Vector2(0, 14), Color("5c3a21"), 0.9)
				FastDraw.poly(ci, PackedVector2Array([sp - Vector2(0, 14), sp - Vector2(-1, 11), sp - Vector2(1, 11)]), Color("c8ccd0"))
			if variant % 2 == 1:
				_watch_tower(ci, P(o, a, f, -0.62, 0.55), false)
			sign_flag(ci, P(o, a, f, 0.85, 0.82), "巡", Color("2c3e6b"))
		"firefighter":
			_compound(ci, o, a, f, ROOF_SLATE)
			water_jars(ci, P(o, a, f, 0.3, 0.6))
			ladder(ci, P(o, a, f, -0.5, 0.62))
			if variant % 2 == 1:
				_watch_tower(ci, P(o, a, f, -0.7, 0.35), true)
			sign_flag(ci, P(o, a, f, 0.85, 0.82), "禁", Color("8a2e1f"))
		"jinhulso":
			_compound(ci, o, a, f, ROOF_SLATE)
			# 구휼 큰 가마솥(죽 솥)과 김, 쌀가마니, 구휼 깃발(賑)
			var pot_p := P(o, a, f, 0.35, 0.55)
			ci.draw_rect(Rect2(pot_p + Vector2(-5, -4), Vector2(10, 4)), Color("2c2a29"))
			FastDraw.circle(ci, pot_p + Vector2(0, -5), 5.5, Color("353535"))
			FastDraw.circle(ci, pot_p + Vector2(0, -6), 4.2, Color("ece6d0"))
			ci.draw_line(pot_p + Vector2(-2, -9), pot_p + Vector2(-2, -13), Color(1, 1, 1, 0.5), 1.0)
			ci.draw_line(pot_p + Vector2(2, -8), pot_p + Vector2(2, -14), Color(1, 1, 1, 0.5), 1.0)
			var rice_p := P(o, a, f, -0.45, 0.6)
			ci.draw_rect(Rect2(rice_p + Vector2(-4, -6), Vector2(8, 6)), Color("b89658"))
			ci.draw_line(rice_p + Vector2(-4, -3), rice_p + Vector2(4, -3), Color("785628"), 0.8)
			sign_flag(ci, P(o, a, f, 0.85, 0.82), "賑", Color("b8860b"))

## 관아 마당: 뒤·옆 담장 + 회색 기와 청사
static func _compound(ci: CanvasItem, o: Vector2, a: Vector2, f: Vector2, roof_col: Color) -> void:
	FastDraw.poly(ci, PackedVector2Array([P(o, a, f, -0.9, -0.9), P(o, a, f, 0.9, -0.9), P(o, a, f, 0.9, 0.9), P(o, a, f, -0.9, 0.9)]), Color("c2b594"))
	wall_seg(ci, o, a, f, -0.9, 0.9, -0.88, 7.0)
	wall_seg(ci, o, a, f, -0.88, 0.3, -0.88, 7.0, true)
	wall_seg(ci, o, a, f, -0.88, 0.3, 0.88, 7.0, true)
	var ob := o + f * -0.35
	box(ci, ob, a, f, 0.62, 0.34, 0.0, 11.0, Color("e2dac8"))
	ci.draw_rect(Rect2(P(o, a, f, 0.0, -0.01, 0.0) + Vector2(-2.5, -7), Vector2(5, 7)), Color("5a2a1c"))
	roof(ci, ob, a, f, 0.82, 0.56, 0.4, 10.0, 18.0, roof_col)

## 고각(망루) — 돌 기단 + 기둥 + 작은 지붕. bell이면 종을 단다.
static func _watch_tower(ci: CanvasItem, p: Vector2, bell: bool) -> void:
	ci.draw_rect(Rect2(p + Vector2(-4, -5), Vector2(8, 5)), Color("8f8a80"))
	for x: float in [-3.4, 3.4]:
		ci.draw_line(p + Vector2(x, -5), p + Vector2(x, -22), Color("6e2a1c"), 1.3)
	ci.draw_line(p + Vector2(-4, -14), p + Vector2(4, -14), TIMBER, 1.0)
	if bell:
		FastDraw.circle(ci, p + Vector2(0, -17), 2.0, Color("b08a3a"))
	FastDraw.poly(ci, PackedVector2Array([p + Vector2(-7, -22), p + Vector2(7, -22), p + Vector2(0, -29)]), ROOF_SLATE)
	ci.draw_line(p + Vector2(-7, -22), p + Vector2(7, -22), ROOF_SLATE.darkened(0.4), 1.0)
