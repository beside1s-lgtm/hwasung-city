# ProceduralIsoArtist.gd
# 2.5D 아이소메트릭 심시티 2000 풍 건축물/공동체 공간/랜드마크 정밀 도트 렌더러
# 순수 Image 픽셀 래스터라이제이션 엔진 (Headless 및 일반 환경 100% 동일 무손실 도트 생성)
class_name ProceduralIsoArtist
extends RefCounted

# =============================================================================
# 1. 고성능 2.5D 아이소메트릭 픽셀 래스터라이저 코어
# =============================================================================

## 안전한 픽셀 쓰기 (알파 블렌딩 지원)
static func set_p(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		if col.a >= 0.99:
			img.set_pixel(x, y, col)
		elif col.a > 0.01:
			var bg: Color = img.get_pixel(x, y)
			var a: float = col.a
			var out_c := Color(
				bg.r * (1.0 - a) + col.r * a,
				bg.g * (1.0 - a) + col.g * a,
				bg.b * (1.0 - a) + col.b * a,
				maxf(bg.a, a)
			)
			img.set_pixel(x, y, out_c)

## 두께 지원 선분 그리기
static func draw_line_img(img: Image, p0: Vector2, p1: Vector2, col: Color, width: float = 1.0) -> void:
	var dist: float = p0.distance_to(p1)
	var steps: int = maxi(1, int(ceilf(dist * 2.0)))
	var half_w: float = (width - 1.0) * 0.5
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var p: Vector2 = p0.lerp(p1, t)
		if width <= 1.0:
			set_p(img, int(roundf(p.x)), int(roundf(p.y)), col)
		else:
			for dy in range(int(floorf(-half_w)), int(ceilf(half_w)) + 1):
				for dx in range(int(floorf(-half_w)), int(ceilf(half_w)) + 1):
					if float(dx * dx + dy * dy) <= (half_w + 0.5) * (half_w + 0.5):
						set_p(img, int(roundf(p.x)) + dx, int(roundf(p.y)) + dy, col)

## 단색 채우기 삼각형 래스터라이저 (Barycentric 알고리즘)
static func fill_tri(img: Image, p0: Vector2, p1: Vector2, p2: Vector2, col: Color) -> void:
	var min_x: int = maxi(0, int(floorf(minf(p0.x, minf(p1.x, p2.x)))))
	var max_x: int = mini(img.get_width() - 1, int(ceilf(maxf(p0.x, maxf(p1.x, p2.x)))))
	var min_y: int = maxi(0, int(floorf(minf(p0.y, minf(p1.y, p2.y)))))
	var max_y: int = mini(img.get_height() - 1, int(ceilf(maxf(p0.y, maxf(p1.y, p2.y)))))

	var denom: float = (p1.y - p2.y) * (p0.x - p2.x) + (p2.x - p1.x) * (p0.y - p2.y)
	if absf(denom) < 0.0001:
		return
	var inv_denom: float = 1.0 / denom

	for y in range(min_y, max_y + 1):
		var fy: float = float(y) + 0.5
		for x in range(min_x, max_x + 1):
			var fx: float = float(x) + 0.5
			var w0: float = ((p1.y - p2.y) * (fx - p2.x) + (p2.x - p1.x) * (fy - p2.y)) * inv_denom
			var w1: float = ((p2.y - p0.y) * (fx - p2.x) + (p0.x - p2.x) * (fy - p2.y)) * inv_denom
			var w2: float = 1.0 - w0 - w1
			if w0 >= -0.001 and w1 >= -0.001 and w2 >= -0.001:
				set_p(img, x, y, col)

## 사각형 채우기 (2개의 삼각형 분할)
static func fill_quad(img: Image, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, col: Color) -> void:
	fill_tri(img, p0, p1, p2, col)
	fill_tri(img, p0, p2, p3, col)

## 직사각형 채우기
static func draw_rect_img(img: Image, rect: Rect2, col: Color) -> void:
	var min_x: int = maxi(0, int(floorf(rect.position.x)))
	var max_x: int = mini(img.get_width() - 1, int(ceilf(rect.position.x + rect.size.x)))
	var min_y: int = maxi(0, int(floorf(rect.position.y)))
	var max_y: int = mini(img.get_height() - 1, int(ceilf(rect.position.y + rect.size.y)))
	for y in range(min_y, max_y):
		for x in range(min_x, max_x):
			set_p(img, x, y, col)

## 원 채우기
static func draw_circle_img(img: Image, center: Vector2, r: float, col: Color) -> void:
	var min_x: int = maxi(0, int(floorf(center.x - r)))
	var max_x: int = mini(img.get_width() - 1, int(ceilf(center.x + r)))
	var min_y: int = maxi(0, int(floorf(center.y - r)))
	var max_y: int = mini(img.get_height() - 1, int(ceilf(center.y + r)))
	var r_sq: float = r * r
	for y in range(min_y, max_y + 1):
		var dy: float = float(y) - center.y
		for x in range(min_x, max_x + 1):
			var dx: float = float(x) - center.x
			if dx * dx + dy * dy <= r_sq:
				set_p(img, x, y, col)

## 타원 채우기
static func draw_ellipse_img(img: Image, center: Vector2, rx: float, ry: float, col: Color) -> void:
	var min_x: int = maxi(0, int(floorf(center.x - rx)))
	var max_x: int = mini(img.get_width() - 1, int(ceilf(center.x + rx)))
	var min_y: int = maxi(0, int(floorf(center.y - ry)))
	var max_y: int = mini(img.get_height() - 1, int(ceilf(center.y + ry)))
	for y in range(min_y, max_y + 1):
		var dy: float = (float(y) - center.y) / maxf(0.5, ry)
		for x in range(min_x, max_x + 1):
			var dx: float = (float(x) - center.x) / maxf(0.5, rx)
			if dx * dx + dy * dy <= 1.0:
				set_p(img, x, y, col)

# =============================================================================
# 2. 2.5D 아이소메트릭 수학 및 투영 기저 함수
# =============================================================================

## 아이소메트릭 로컬 좌표 투영 (u: 횡축 [-1, 1], v: 종축 [-1, 1], h: 높이 수직 상승)
static func iso_point(o: Vector2, u: float, v: float, h: float = 0.0, tile_w: float = 64.0, tile_h: float = 32.0) -> Vector2:
	return Vector2(
		o.x + (u - v) * (tile_w * 0.25),
		o.y + (u + v) * (tile_h * 0.25) - h
	)

## 2.5D 마름모 지면 기단 그리기 (화강암 축대 또는 흙마당 입체 석축)
static func draw_iso_ground(img: Image, o: Vector2, tw: float, th: float, col_fill: Color, col_edge: Color, base_h: float = 3.0) -> void:
	var g0: Vector2 = iso_point(o, -0.92, -0.92, 0.0, tw, th)
	var g1: Vector2 = iso_point(o, 0.92, -0.92, 0.0, tw, th)
	var g2: Vector2 = iso_point(o, 0.92, 0.92, 0.0, tw, th)
	var g3: Vector2 = iso_point(o, -0.92, 0.92, 0.0, tw, th)

	# 1. 수직 입체 석축 두께면 (지면에서 우뚝 선 2.5D 기단 전면/측면)
	if base_h > 0.5:
		var col_front_left: Color = col_edge.darkened(0.18)
		var col_front_right: Color = col_edge.darkened(0.38)
		var b_g3 := g3 + Vector2(0.0, base_h)
		var b_g2 := g2 + Vector2(0.0, base_h)
		var b_g1 := g1 + Vector2(0.0, base_h)
		fill_quad(img, g3, g2, b_g2, b_g3, col_front_left)
		fill_quad(img, g2, g1, b_g1, b_g2, col_front_right)
		draw_line_img(img, b_g3, b_g2, col_edge.darkened(0.5), 1.0)
		draw_line_img(img, b_g2, b_g1, col_edge.darkened(0.6), 1.0)
		draw_line_img(img, g2, b_g2, col_edge.darkened(0.5), 1.0)

	# 2. 기단 상단 마당/축대면
	fill_quad(img, g0, g1, g2, g3, col_fill)
	draw_line_img(img, g0, g1, col_edge, 1.0)
	draw_line_img(img, g1, g2, col_edge, 1.0)
	draw_line_img(img, g2, g3, col_edge, 1.0)
	draw_line_img(img, g3, g0, col_edge, 1.0)

## 2.5D 입체 박스 그리기 (기단, 벽면, 3면 음영, 목조 기둥 및 창호)
static func draw_iso_box(img: Image, o: Vector2, u0: float, u1: float, v0: float, v1: float, h0: float, h1: float,
		top_col: Color, left_col: Color, right_col: Color, tw: float, th: float,
		has_timber: bool = true, timber_col: Color = Color("5c3a21"), has_window: bool = false) -> void:
	var p_top0: Vector2 = iso_point(o, u0, v0, h1, tw, th)
	var p_top1: Vector2 = iso_point(o, u1, v0, h1, tw, th)
	var p_top2: Vector2 = iso_point(o, u1, v1, h1, tw, th)
	var p_top3: Vector2 = iso_point(o, u0, v1, h1, tw, th)

	var p_bot1: Vector2 = iso_point(o, u1, v0, h0, tw, th)
	var p_bot2: Vector2 = iso_point(o, u1, v1, h0, tw, th)
	var p_bot3: Vector2 = iso_point(o, u0, v1, h0, tw, th)

	# 좌측 벽면 (그늘 100% or 80%)
	fill_quad(img, p_top3, p_top2, p_bot2, p_bot3, left_col)
	# 우측 벽면 (그늘 70%)
	fill_quad(img, p_top2, p_top1, p_bot1, p_bot2, right_col)
	# 상단면 (햇빛 100%)
	fill_quad(img, p_top0, p_top1, p_top2, p_top3, top_col)

	# 목조 가구 기둥 및 인방
	if has_timber:
		draw_line_img(img, p_top3, p_bot3, timber_col, 1.0)
		draw_line_img(img, p_top2, p_bot2, timber_col, 1.2)
		draw_line_img(img, p_top1, p_bot1, timber_col, 1.0)
		draw_line_img(img, p_top3, p_top2, timber_col, 1.0)
		draw_line_img(img, p_top2, p_top1, timber_col, 1.0)
		draw_line_img(img, p_bot3, p_bot2, timber_col, 1.0)
		draw_line_img(img, p_bot2, p_bot1, timber_col, 1.0)

	# 앞면 격자 창살문/미닫이문
	if has_window and (h1 - h0) >= 8.0:
		var w_mid_u: float = (u0 + u1) * 0.5
		var w_p0: Vector2 = iso_point(o, w_mid_u - 0.25, v1, h0 + 2.0, tw, th)
		var w_p1: Vector2 = iso_point(o, w_mid_u + 0.25, v1, h0 + 2.0, tw, th)
		var w_p2: Vector2 = iso_point(o, w_mid_u + 0.25, v1, h1 - 3.0, tw, th)
		var w_p3: Vector2 = iso_point(o, w_mid_u - 0.25, v1, h1 - 3.0, tw, th)
		fill_quad(img, w_p3, w_p2, w_p1, w_p0, Color("f8fafc"))
		draw_line_img(img, w_p0, w_p1, timber_col, 1.0)
		draw_line_img(img, w_p1, w_p2, timber_col, 1.0)
		draw_line_img(img, w_p2, w_p3, timber_col, 1.0)
		draw_line_img(img, w_p3, w_p0, timber_col, 1.0)
		# 십자 창살
		var w_cx: Vector2 = w_p0.lerp(w_p1, 0.5)
		var w_tx: Vector2 = w_p3.lerp(w_p2, 0.5)
		draw_line_img(img, w_cx, w_tx, timber_col.lightened(0.2), 0.8)
		var w_ly: Vector2 = w_p0.lerp(w_p3, 0.5)
		var w_ry: Vector2 = w_p1.lerp(w_p2, 0.5)
		draw_line_img(img, w_ly, w_ry, timber_col.lightened(0.2), 0.8)

## 2.5D 조선 고유 정통 한옥 가구 구조 (다주칸 기둥, 창호 띠살 분합문, 머름, 툇마루, 오픈 대청마루)
static func draw_hanok_structure(
	img: Image, o: Vector2,
	u0: float, u1: float, v0: float, v1: float,
	h0: float, h1: float,
	tw: float, th: float,
	bays_u: int = 3, bays_v: int = 2,
	open_hall_idx: int = -1,
	timber_col: Color = Color("5c3a21"),
	wall_light: Color = Color("fdfbf7"),
	wall_shade: Color = Color("cbd5e1"),
	has_toetmaru: bool = true
) -> void:
	var p_top0: Vector2 = iso_point(o, u0, v0, h1, tw, th)
	var p_top1: Vector2 = iso_point(o, u1, v0, h1, tw, th)
	var p_top2: Vector2 = iso_point(o, u1, v1, h1, tw, th)
	var p_top3: Vector2 = iso_point(o, u0, v1, h1, tw, th)

	var p_bot1: Vector2 = iso_point(o, u1, v0, h0, tw, th)
	var p_bot2: Vector2 = iso_point(o, u1, v1, h0, tw, th)
	var p_bot3: Vector2 = iso_point(o, u0, v1, h0, tw, th)

	# 1. 우측면 (남동면, 짙은 음영 벽체)
	fill_quad(img, p_top2, p_top1, p_bot1, p_bot2, wall_shade)
	var shade_timber: Color = timber_col.darkened(0.25)
	draw_line_img(img, p_top2, p_bot2, shade_timber, 1.2)
	draw_line_img(img, p_top1, p_bot1, shade_timber, 1.0)
	draw_line_img(img, p_top2, p_top1, shade_timber, 1.0)
	draw_line_img(img, p_bot2, p_bot1, shade_timber, 1.0)
	if bays_v > 1:
		for kv: int in range(1, bays_v):
			var vt: float = float(kv) / float(bays_v)
			var vk: float = lerpf(v1, v0, vt)
			var pt_v: Vector2 = iso_point(o, u1, vk, h1, tw, th)
			var pb_v: Vector2 = iso_point(o, u1, vk, h0, tw, th)
			draw_line_img(img, pt_v, pb_v, shade_timber, 1.0)
		var pm_v0: Vector2 = iso_point(o, u1, v1, h0 + (h1 - h0) * 0.55, tw, th)
		var pm_v1: Vector2 = iso_point(o, u1, v0, h0 + (h1 - h0) * 0.55, tw, th)
		draw_line_img(img, pm_v0, pm_v1, shade_timber, 0.8)

	# 2. 좌측면 (정면, 남서면 - 한옥 전면 파사드)
	fill_quad(img, p_top3, p_top2, p_bot2, p_bot3, wall_light)

	# 툇마루 (바닥에서 2~3px 살짝 튀어나온 원목 마루널)
	if has_toetmaru and (h1 - h0) >= 12.0:
		var maru_v: float = v1 + 0.08
		var maru_h: float = h0 + 2.5
		var m_p0: Vector2 = iso_point(o, u0, v1, maru_h, tw, th)
		var m_p1: Vector2 = iso_point(o, u1, v1, maru_h, tw, th)
		var m_p2: Vector2 = iso_point(o, u1, maru_v, maru_h, tw, th)
		var m_p3: Vector2 = iso_point(o, u0, maru_v, maru_h, tw, th)
		var m_b2: Vector2 = iso_point(o, u1, maru_v, h0, tw, th)
		var m_b3: Vector2 = iso_point(o, u0, maru_v, h0, tw, th)
		fill_quad(img, m_p3, m_p2, m_p1, m_p0, Color("b45309"))
		fill_quad(img, m_p3, m_p2, m_b2, m_b3, Color("78350f"))
		draw_line_img(img, m_p3, m_p2, Color("451a03"), 0.8)

	# 상방 및 하방
	var beam_top0: Vector2 = iso_point(o, u0, v1, h1 - 1.5, tw, th)
	var beam_top1: Vector2 = iso_point(o, u1, v1, h1 - 1.5, tw, th)
	var beam_bot0: Vector2 = iso_point(o, u0, v1, h0 + 2.0, tw, th)
	var beam_bot1: Vector2 = iso_point(o, u1, v1, h0 + 2.0, tw, th)
	draw_line_img(img, beam_top0, beam_top1, timber_col, 1.4)
	draw_line_img(img, beam_bot0, beam_bot1, timber_col, 1.2)

	# 칸(Bay) 단위 정밀 분할 및 문/창호/대청 렌더링
	var bu: int = maxi(1, bays_u)
	for k: int in range(bu):
		var ku0: float = lerpf(u0, u1, float(k) / float(bu))
		var ku1: float = lerpf(u0, u1, float(k + 1) / float(bu))
		var is_open_hall: bool = (k == open_hall_idx)

		if is_open_hall:
			# 오픈 대청마루: 실내 그늘 + 바닥 우드 마루널
			var hall_t0: Vector2 = iso_point(o, ku0 + 0.04, v1, h1 - 2.0, tw, th)
			var hall_t1: Vector2 = iso_point(o, ku1 - 0.04, v1, h1 - 2.0, tw, th)
			var hall_b1: Vector2 = iso_point(o, ku1 - 0.04, v1, h0 + 2.5, tw, th)
			var hall_b0: Vector2 = iso_point(o, ku0 + 0.04, v1, h0 + 2.5, tw, th)
			fill_quad(img, hall_t0, hall_t1, hall_b1, hall_b0, Color("1c1917"))
			var floor_m0: Vector2 = hall_b0.lerp(hall_t0, 0.28)
			var floor_m1: Vector2 = hall_b1.lerp(hall_t1, 0.28)
			fill_quad(img, floor_m0, floor_m1, hall_b1, hall_b0, Color("92400e"))
			draw_line_img(img, floor_m0, floor_m1, Color("78350f"), 0.8)
			var win_bg: Vector2 = hall_t0.lerp(hall_t1, 0.5)
			draw_rect_img(img, Rect2(win_bg - Vector2(3, -2), Vector2(6, 4)), Color("fef08a", 0.6))
		else:
			# 온돌방 칸: 하단 머름 + 상단 띠살 창호문
			var bay_w: float = ku1 - ku0
			var margin: float = bay_w * 0.12
			var win_u0: float = ku0 + margin
			var win_u1: float = ku1 - margin
			var mureum_h: float = h0 + (h1 - h0) * 0.32
			var win_top_h: float = h1 - 3.0

			var mr_t0: Vector2 = iso_point(o, win_u0, v1, mureum_h, tw, th)
			var mr_t1: Vector2 = iso_point(o, win_u1, v1, mureum_h, tw, th)
			var mr_b1: Vector2 = iso_point(o, win_u1, v1, h0 + 2.0, tw, th)
			var mr_b0: Vector2 = iso_point(o, win_u0, v1, h0 + 2.0, tw, th)
			fill_quad(img, mr_t0, mr_t1, mr_b1, mr_b0, Color("78350f"))
			draw_line_img(img, mr_t0, mr_t1, Color("451a03"), 0.8)

			var w_t0: Vector2 = iso_point(o, win_u0, v1, win_top_h, tw, th)
			var w_t1: Vector2 = iso_point(o, win_u1, v1, win_top_h, tw, th)
			var w_b1: Vector2 = mr_t1
			var w_b0: Vector2 = mr_t0
			fill_quad(img, w_t0, w_t1, w_b1, w_b0, Color("f8fafc"))
			draw_line_img(img, w_t0, w_t1, timber_col, 0.9)
			draw_line_img(img, w_t1, w_b1, timber_col, 0.9)
			draw_line_img(img, w_b1, w_b0, timber_col, 0.9)
			draw_line_img(img, w_b0, w_t0, timber_col, 0.9)

			var w_mid_top: Vector2 = w_t0.lerp(w_t1, 0.5)
			var w_mid_bot: Vector2 = w_b0.lerp(w_b1, 0.5)
			draw_line_img(img, w_mid_top, w_mid_bot, timber_col, 0.9)
			for sl: int in [1, 2]:
				var st: float = float(sl) * 0.33
				var sl_p0: Vector2 = w_b0.lerp(w_t0, st)
				var sl_p1: Vector2 = w_b1.lerp(w_t1, st)
				draw_line_img(img, sl_p0, sl_p1, timber_col.lightened(0.2), 0.7)

	# 칸마다 세로 기둥 세우기
	for k: int in range(bu + 1):
		var ku: float = lerpf(u0, u1, float(k) / float(bu))
		var pt_col: Vector2 = iso_point(o, ku, v1, h1, tw, th)
		var pb_col: Vector2 = iso_point(o, ku, v1, h0, tw, th)
		draw_line_img(img, pt_col, pb_col, timber_col, 1.2 if (k == 0 or k == bu) else 1.0)
		draw_rect_img(img, Rect2(pt_col - Vector2(1, 1), Vector2(3, 2)), timber_col.darkened(0.2))

	# 3. 상단면 (천장면)
	fill_quad(img, p_top0, p_top1, p_top2, p_top3, wall_light.darkened(0.1))

	# 4. 처마 바로 밑 깊은 그림자 (지붕 드리움 효과)
	var sh_p0: Vector2 = iso_point(o, u0, v1, h1, tw, th)
	var sh_p1: Vector2 = iso_point(o, u1, v1, h1, tw, th)
	var sh_p2: Vector2 = iso_point(o, u1, v1, h1 - 2.2, tw, th)
	var sh_p3: Vector2 = iso_point(o, u0, v1, h1 - 2.2, tw, th)
	fill_quad(img, sh_p0, sh_p1, sh_p2, sh_p3, Color(0.12, 0.08, 0.06, 0.55))

## 2.5D 조선 고유 팔작/맞배 지붕 (버선코 처마 곡선 + 기와골/볏짚결 + 백회 용마루)
static func draw_iso_roof(img: Image, o: Vector2, u0: float, u1: float, v0: float, v1: float,
		eaves_h: float, ridge_h: float, roof_col: Color, ridge_col: Color, is_thatch: bool,
		tw: float, th: float) -> void:
	# 처마 꼭짓점 돌출 (버선코 곡선을 위해 귀처마 모서리는 살짝 높임, 벽체 가림 방지)
	var eu0: float = u0 - 0.14
	var eu1: float = u1 + 0.14
	var ev0: float = v0 - 0.14
	var ev1: float = v1 + 0.10

	var corner_lift: float = 2.4 if not is_thatch else 0.8
	var e0: Vector2 = iso_point(o, eu0, ev0, eaves_h + corner_lift, tw, th)
	var e1: Vector2 = iso_point(o, eu1, ev0, eaves_h + corner_lift, tw, th)
	var e2: Vector2 = iso_point(o, eu1, ev1, eaves_h + corner_lift, tw, th)
	var e3: Vector2 = iso_point(o, eu0, ev1, eaves_h + corner_lift, tw, th)

	# 용마루 선
	var ru0: float = (u0 + u1) * 0.5 - (u1 - u0) * 0.35
	var ru1: float = (u0 + u1) * 0.5 + (u1 - u0) * 0.35
	var rv: float = (v0 + v1) * 0.5

	var r0: Vector2 = iso_point(o, ru0, rv, ridge_h, tw, th)
	var r1: Vector2 = iso_point(o, ru1, rv, ridge_h, tw, th)

	var shade_col: Color = roof_col.darkened(0.28)
	var light_col: Color = roof_col.lightened(0.12)

	# 1. 지붕 사면 드로잉
	# 앞경사면 (좌하향)
	fill_quad(img, r0, r1, e2, e3, roof_col)
	# 우측 박공/경사면 (우하향, 그늘)
	fill_tri(img, r1, e1, e2, shade_col)
	# 좌측 박공/경사면 (좌상향, 양광)
	fill_tri(img, r0, e3, e0, light_col)

	# 2. 처마 밑 어두운 그림자 및 서까래
	var rafter_col := Color("3d2314")
	var rafter_steps: int = maxi(3, int((e2.distance_to(e3)) / 5.0))
	for k in range(rafter_steps + 1):
		var rt: float = float(k) / float(rafter_steps)
		var rp: Vector2 = e3.lerp(e2, rt)
		draw_line_img(img, rp, rp + Vector2(0, 1.8), rafter_col, 1.0)

	# 3. 지붕 텍스처 (기와골 or 볏짚단 결)
	if is_thatch:
		# 포근한 볏짚 가로 묶음선
		for k: int in range(1, 4):
			var thatch_ratio: float = float(k) * 0.25
			var tl: Vector2 = r0.lerp(e3, thatch_ratio)
			var tr_p: Vector2 = r1.lerp(e2, thatch_ratio)
			draw_line_img(img, tl, tr_p, Color("92400e"), 1.0)
		# 볏짚 용마름 (도톰한 갈색 띠)
		draw_line_img(img, r0, r1, ridge_col, 2.5)
	else:
		# 기와골 종선 (용마루에서 처마로 흐르는 기왓골)
		var steps: int = maxi(4, int((r1.distance_to(r0)) / 4.0))
		for k in range(1, steps):
			var gr: float = float(k) / float(steps)
			var g_top: Vector2 = r0.lerp(r1, gr)
			var g_bot: Vector2 = e3.lerp(e2, gr)
			draw_line_img(img, g_top, g_bot, Color("0f172a"), 1.0)
			# 기와골 하이라이트
			if k % 2 == 0:
				draw_line_img(img, g_top + Vector2(0.8, 0), g_bot + Vector2(0.8, 0), Color("475569"), 0.8)

		# 웅장한 백회 마감 용마루 (흰색/은회색)
		draw_line_img(img, r0, r1, Color("f8fafc"), 2.2)
		draw_line_img(img, r0, r1, ridge_col, 1.2)
		# 용마루 좌우 망와/취두 (치켜올라간 장식)
		draw_circle_img(img, r0 + Vector2(-1.0, -1.0), 1.6, Color("e2e8f0"))
		draw_circle_img(img, r1 + Vector2(1.0, -1.0), 1.6, Color("e2e8f0"))

	# 처마선 테두리
	draw_line_img(img, e3, e2, roof_col.darkened(0.4), 1.2)
	draw_line_img(img, e2, e1, roof_col.darkened(0.5), 1.2)

## 차양(상점 앞 처마를 늘인 널판/오색 천막) + 앞 기둥 두 개
static func draw_awning(img: Image, o: Vector2, u0: float, u1: float, v0: float, v1: float,
		h_back: float, h_front: float, cloth_col: Color, tw: float, th: float) -> void:
	var aw0: Vector2 = iso_point(o, u0, v0, h_back, tw, th)
	var aw1: Vector2 = iso_point(o, u1, v0, h_back, tw, th)
	var aw2: Vector2 = iso_point(o, u1, v1, h_front, tw, th)
	var aw3: Vector2 = iso_point(o, u0, v1, h_front, tw, th)

	# 차양 천막 면
	fill_quad(img, aw0, aw1, aw2, aw3, cloth_col)

	# 차양 스트라이프 줄무늬 (전통 2색 배색)
	var stripe_col: Color = Color("f8fafc") if cloth_col != Color("f8fafc") else Color("3b82f6")
	for s in range(1, 4):
		var st: float = float(s) * 0.25
		var sp0: Vector2 = aw0.lerp(aw1, st)
		var sp1: Vector2 = aw3.lerp(aw2, st)
		draw_line_img(img, sp0, sp1, stripe_col, 1.2)

	# 차양 앞면을 지탱하는 목조 기둥 2개
	var post_col := Color("5c3a21")
	var g_left: Vector2 = iso_point(o, u0 + 0.05, v1, 0.0, tw, th)
	var g_right: Vector2 = iso_point(o, u1 - 0.05, v1, 0.0, tw, th)
	draw_line_img(img, aw3, g_left, post_col, 1.2)
	draw_line_img(img, aw2, g_right, post_col, 1.2)

# =============================================================================
# 3. 고증 조경 및 마당 소품 도트 렌더러
# =============================================================================

## 장독대 (큰 독, 중독, 작은 단지 옹기 무리 + 뚜껑 하이라이트)
static func draw_onggi_jars(img: Image, pos: Vector2, count: int = 3) -> void:
	# 장독대 받침 석판
	draw_ellipse_img(img, pos + Vector2(0, 1), 6.0 + float(count) * 2.0, 3.5, Color("78716c"))
	for i in range(count):
		var ox: float = (float(i) - float(count - 1) * 0.5) * 4.5
		var r: float = 2.4 - float(i) * 0.4
		var jar_p: Vector2 = pos + Vector2(ox, -float(i) * 0.5)
		# 옹기 몸통
		draw_ellipse_img(img, jar_p, r, r * 1.2, Color("3b1d11"))
		# 옹기 뚜껑
		draw_ellipse_img(img, jar_p - Vector2(0, r * 0.8), r * 0.85, r * 0.45, Color("57300a"))
		# 뚜껑 반사광
		set_p(img, int(roundf(jar_p.x - 0.5)), int(roundf(jar_p.y - r * 0.9)), Color("a88950"))

## 한국 고유 붉은 노송 (소나무)
static func draw_pine_tree(img: Image, pos: Vector2, scale: float = 1.0) -> void:
	var trunk_col := Color("7c2d12")
	# 굽이친 소나무 붉은 줄기
	var p0: Vector2 = pos
	var p1: Vector2 = pos + Vector2(-2.0 * scale, -8.0 * scale)
	var p2: Vector2 = pos + Vector2(1.0 * scale, -15.0 * scale)
	var p3: Vector2 = pos + Vector2(-1.0 * scale, -22.0 * scale)
	draw_line_img(img, p0, p1, trunk_col, 2.2 * scale)
	draw_line_img(img, p1, p2, trunk_col, 1.8 * scale)
	draw_line_img(img, p2, p3, trunk_col, 1.4 * scale)

	# 층층이 펼쳐진 상록수 솔잎 덩어리
	var leaf_dark := Color("14532d")
	var leaf_mid := Color("166534")
	var leaf_light := Color("22c55e")
	var t1: Vector2 = p1 + Vector2(-5.0 * scale, -2.0 * scale)
	var t2: Vector2 = p2 + Vector2(6.0 * scale, -2.0 * scale)
	var t3: Vector2 = p3 + Vector2(0.0, -3.0 * scale)

	draw_ellipse_img(img, t1, 6.0 * scale, 3.5 * scale, leaf_dark)
	draw_ellipse_img(img, t1 - Vector2(0, 1), 4.5 * scale, 2.5 * scale, leaf_mid)

	draw_ellipse_img(img, t2, 7.0 * scale, 4.0 * scale, leaf_dark)
	draw_ellipse_img(img, t2 - Vector2(0, 1), 5.5 * scale, 3.0 * scale, leaf_mid)

	draw_ellipse_img(img, t3, 8.5 * scale, 5.0 * scale, leaf_dark)
	draw_ellipse_img(img, t3 - Vector2(0, 1.5), 6.5 * scale, 3.5 * scale, leaf_mid)
	draw_ellipse_img(img, t3 - Vector2(1, 2.5), 3.5 * scale, 2.0 * scale, leaf_light)

## 조선 누렁이 황소 (우시장 및 외양간 고유 도트)
static func draw_ox(img: Image, pos: Vector2, facing_right: bool = true) -> void:
	var ox_body := Color("854d0e")
	var ox_dark := Color("543018")
	var ox_horn := Color("fef3c7")
	var ox_dir: float = 1.0 if facing_right else -1.0

	# 그림자
	draw_ellipse_img(img, pos + Vector2(0, 1), 6.0, 3.0, Color(0, 0, 0, 0.3))

	# 다리 4개
	draw_line_img(img, pos + Vector2(-3, -2), pos + Vector2(-3, 2), ox_dark, 1.2)
	draw_line_img(img, pos + Vector2(-1, -2), pos + Vector2(-1, 2), ox_dark, 1.2)
	draw_line_img(img, pos + Vector2(2, -2), pos + Vector2(2, 2), ox_dark, 1.2)
	draw_line_img(img, pos + Vector2(4, -2), pos + Vector2(4, 2), ox_dark, 1.2)

	# 몸통 타원
	draw_ellipse_img(img, pos + Vector2(0, -3), 5.5, 3.8, ox_body)
	# 엉덩이/등 하이라이트
	draw_ellipse_img(img, pos + Vector2(-1, -4), 3.5, 2.0, ox_body.lightened(0.15))

	# 머리
	var head_p: Vector2 = pos + Vector2(5.0 * ox_dir, -5.0)
	draw_circle_img(img, head_p, 2.6, ox_dark)

	# 뿔
	draw_line_img(img, head_p + Vector2(0, -1), head_p + Vector2(ox_dir * 1.5, -4.0), ox_horn, 1.0)
	draw_line_img(img, head_p + Vector2(-ox_dir * 1.0, -1), head_p + Vector2(-ox_dir * 0.5, -4.0), ox_horn, 1.0)

	# 코뚜레와 워낭(방울)
	set_p(img, int(roundf(head_p.x + ox_dir * 2.0)), int(roundf(head_p.y + 1.0)), Color("facc15"))

## 암탉/수탉 도트
static func draw_chicken(img: Image, pos: Vector2, is_rooster: bool = false) -> void:
	var body_col: Color = Color("f8fafc") if not is_rooster else Color("b45309")
	draw_ellipse_img(img, pos, 2.0, 1.4, body_col)
	var head_p: Vector2 = pos + Vector2(1.8, -1.5)
	draw_circle_img(img, head_p, 1.2, body_col)
	# 붉은 볏
	set_p(img, int(roundf(head_p.x)), int(roundf(head_p.y - 1.2)), Color("dc2626"))
	# 노란 부리
	set_p(img, int(roundf(head_p.x + 1.2)), int(roundf(head_p.y)), Color("eab308"))

## 굴뚝과 몽실몽실 연기
static func draw_chimney_with_smoke(img: Image, pos: Vector2) -> void:
	# 굴뚝 본체 (황토벽돌)
	draw_rect_img(img, Rect2(pos - Vector2(1.5, 6), Vector2(3, 6)), Color("78350f"))
	draw_rect_img(img, Rect2(pos - Vector2(2, 7), Vector2(4, 1.5)), Color("1e293b"))
	# 연기 구름 (반투명 파티클 도트)
	draw_circle_img(img, pos - Vector2(1.0, 9.0), 2.0, Color(0.9, 0.9, 0.9, 0.5))
	draw_circle_img(img, pos - Vector2(2.5, 13.0), 3.0, Color(0.92, 0.92, 0.95, 0.4))
	draw_circle_img(img, pos - Vector2(4.5, 18.0), 4.2, Color(0.95, 0.95, 0.98, 0.25))

# =============================================================================
# 4. 방·리 가옥 20종 정밀 도트 렌더러 (초가 10종 + 기와 10종)
# =============================================================================

## 초가집 10종 (`thatch_house_01` ~ `10`)
static func paint_thatch_house(img: Image, c_size: Vector2, variant_idx: int) -> void:
	var is_2x1: bool = (variant_idx >= 7)
	var tw: float = 96.0 if is_2x1 else 64.0
	var th: float = 48.0 if is_2x1 else 32.0
	var o: Vector2 = Vector2(c_size.x * 0.5, c_size.y - th * 0.5 - 2.0)

	var col_ground := Color("d4b483")
	var col_wall := Color("d4b67b")
	var col_wall_shade := Color("a88950")
	var col_timber := Color("663d14")
	var col_thatch := Color("d97706")
	var col_ridge := Color("78350f")

	# 1. 흙 기단 마당
	draw_iso_ground(img, o, tw, th, col_ground, Color("997a48"))

	if not is_2x1:
		# 1x1 소박한 초가 (본채)
		draw_iso_box(img, o, -0.6, 0.6, -0.5, 0.5, 0.0, 14.0, col_wall, col_wall, col_wall_shade, tw, th, true, col_timber, true)
		draw_iso_roof(img, o, -0.65, 0.65, -0.55, 0.55, 13.0, 25.0, col_thatch, col_ridge, true, tw, th)

		# 변형별 고유 마당 소품 (01~07)
		match variant_idx:
			0: # 01: 싸리나무 울타리와 절구통
				var fence_a: Vector2 = iso_point(o, -0.85, 0.7, 0.0, tw, th)
				var fence_b: Vector2 = iso_point(o, 0.2, 0.7, 0.0, tw, th)
				draw_line_img(img, fence_a, fence_b, col_timber, 1.2)
				for fi in range(5):
					var fp: Vector2 = fence_a.lerp(fence_b, float(fi) / 4.0)
					draw_line_img(img, fp, fp - Vector2(0, 4), col_timber, 1.0)
				# 나무 절구통
				var mortar_p: Vector2 = iso_point(o, 0.55, 0.6, 0.0, tw, th)
				draw_ellipse_img(img, mortar_p, 2.5, 2.0, Color("57300a"))
				draw_ellipse_img(img, mortar_p - Vector2(0, 1.5), 2.0, 1.2, Color("1e293b"))
				draw_line_img(img, mortar_p, mortar_p - Vector2(2, 6), Color("b45309"), 1.0) # 절굿공이

			1: # 02: 갈색 옹기 장독대 3기
				var pot_base: Vector2 = iso_point(o, 0.45, 0.6, 0.0, tw, th)
				draw_onggi_jars(img, pot_base, 3)

			2: # 03: 지붕 위 백색 조롱박 덩굴
				var roof_c: Vector2 = iso_point(o, 0.0, 0.0, 23.0, tw, th)
				draw_circle_img(img, roof_c + Vector2(-5, 3), 2.2, Color("fef08a"))
				draw_circle_img(img, roof_c + Vector2(2, 5), 2.5, Color("ffffff"))
				draw_circle_img(img, roof_c + Vector2(7, 2), 2.0, Color("fef08a"))
				# 푸른 덩굴손
				draw_line_img(img, roof_c - Vector2(7, 0), roof_c + Vector2(9, 4), Color("15803d"), 1.0)

			3: # 04: 처마 밑 노란 메주와 붉은 고추 다발
				var eave_p: Vector2 = iso_point(o, -0.2, 0.55, 12.0, tw, th)
				# 메주 2덩이
				draw_rect_img(img, Rect2(eave_p - Vector2(2, -1), Vector2(2.5, 3.5)), Color("ca8a04"))
				draw_rect_img(img, Rect2(eave_p + Vector2(2, 1), Vector2(2.5, 3.5)), Color("ca8a04"))
				# 고추 다발
				draw_line_img(img, eave_p + Vector2(6, 0), eave_p + Vector2(6, 6), Color("dc2626"), 1.4)
				draw_line_img(img, eave_p + Vector2(8, 0), eave_p + Vector2(8, 5), Color("dc2626"), 1.4)

			4: # 05: 통나무 장작더미와 아궁이 굴뚝 연기
				var wood_p: Vector2 = iso_point(o, -0.7, 0.3, 0.0, tw, th)
				draw_rect_img(img, Rect2(wood_p - Vector2(4, 5), Vector2(8, 5)), Color("543018"))
				draw_line_img(img, wood_p - Vector2(4, 2), wood_p + Vector2(4, -2), Color("ca8a04"), 1.0)
				# 굴뚝 및 연기
				var chim_p: Vector2 = iso_point(o, -0.55, -0.35, 14.0, tw, th)
				draw_chimney_with_smoke(img, chim_p)

			5: # 06: 대나무 닭장과 모이 쪼는 닭
				var coop_p: Vector2 = iso_point(o, 0.5, 0.5, 0.0, tw, th)
				draw_rect_img(img, Rect2(coop_p - Vector2(4, 4), Vector2(7, 4)), Color("78350f"))
				draw_chicken(img, coop_p + Vector2(1, 2), false) # 흰 암탉
				draw_chicken(img, coop_p + Vector2(4, 0), true) # 수탉

			6: # 07: 마당 빨랫줄 (흰 무명천과 적삼)
				var pole_a: Vector2 = iso_point(o, -0.6, 0.7, 0.0, tw, th)
				var pole_b: Vector2 = iso_point(o, 0.3, 0.7, 0.0, tw, th)
				draw_line_img(img, pole_a, pole_a - Vector2(0, 11), col_timber, 1.2)
				draw_line_img(img, pole_b, pole_b - Vector2(0, 11), col_timber, 1.2)
				draw_line_img(img, pole_a - Vector2(0, 10), pole_b - Vector2(0, 10), Color("e2e8f0"), 1.0)
				# 널려 있는 무명옷
				draw_rect_img(img, Rect2(pole_a + Vector2(2, -9), Vector2(6, 6)), Color("ffffff"))
				draw_rect_img(img, Rect2(pole_a + Vector2(9, -8), Vector2(5, 5)), Color("f1f5f9"))
	else:
		# 2x1 부농 합필 초가 (08: ㄱ자 안채, 09: 외양간과 황소, 10: 쌍채 초가)
		match variant_idx:
			7: # 08: ㄱ자 안채 + 평상 멍석(고추 말리기)
				draw_iso_box(img, o, -0.8, 0.3, -0.5, 0.5, 0.0, 16.0, col_wall, col_wall, col_wall_shade, tw, th, true, col_timber, true)
				draw_iso_roof(img, o, -0.85, 0.35, -0.55, 0.55, 15.0, 28.0, col_thatch, col_ridge, true, tw, th)
				draw_iso_box(img, o, 0.2, 0.7, -0.5, 0.2, 0.0, 14.0, col_wall, col_wall, col_wall_shade, tw, th, true, col_timber, true)
				draw_iso_roof(img, o, 0.15, 0.75, -0.55, 0.25, 13.0, 24.0, col_thatch, col_ridge, true, tw, th)
				# 넓은 마당 평상
				var py_p: Vector2 = iso_point(o, 0.35, 0.6, 0.0, tw, th)
				draw_rect_img(img, Rect2(py_p - Vector2(6, 4), Vector2(12, 6)), Color("b45309"))
				# 붉은 태양초 고추 말리는 멍석
				draw_rect_img(img, Rect2(py_p - Vector2(5, 3), Vector2(10, 4)), Color("dc2626"))

			8: # 09: 본채 + 외양간(여물통과 황소) + 건초
				draw_iso_box(img, o, -0.8, 0.2, -0.5, 0.5, 0.0, 16.0, col_wall, col_wall, col_wall_shade, tw, th, true, col_timber, true)
				draw_iso_roof(img, o, -0.85, 0.25, -0.55, 0.55, 15.0, 28.0, col_thatch, col_ridge, true, tw, th)
				# 오픈형 외양간 구조물
				draw_iso_box(img, o, 0.3, 0.8, -0.4, 0.4, 0.0, 12.0, Color("543018"), Color("543018"), Color("381e08"), tw, th, true)
				draw_iso_roof(img, o, 0.25, 0.85, -0.45, 0.45, 11.0, 20.0, col_thatch, col_ridge, true, tw, th)
				# 늠름한 조선 황소
				var cow_p: Vector2 = iso_point(o, 0.55, 0.15, 0.0, tw, th)
				draw_ox(img, cow_p, false)
				# 황금빛 건초더미
				var hay_p: Vector2 = iso_point(o, 0.6, 0.55, 0.0, tw, th)
				draw_ellipse_img(img, hay_p, 4.0, 3.0, Color("ca8a04"))

			9: # 10: 쌍채 초가 + 가운데 우물 + 텃밭 두둑
				draw_iso_box(img, o, -0.8, -0.2, -0.5, 0.5, 0.0, 15.0, col_wall, col_wall, col_wall_shade, tw, th, true, col_timber, true)
				draw_iso_roof(img, o, -0.85, -0.15, -0.55, 0.55, 14.0, 26.0, col_thatch, col_ridge, true, tw, th)
				draw_iso_box(img, o, 0.2, 0.8, -0.5, 0.5, 0.0, 15.0, col_wall, col_wall, col_wall_shade, tw, th, true, col_timber, true)
				draw_iso_roof(img, o, 0.15, 0.85, -0.55, 0.55, 14.0, 26.0, col_thatch, col_ridge, true, tw, th)
				# 마당 원형 돌우물
				var well_p: Vector2 = iso_point(o, 0.0, 0.0, 0.0, tw, th)
				draw_circle_img(img, well_p, 3.5, Color("475569"))
				draw_circle_img(img, well_p, 2.2, Color("0284c7"))
				# 푸른 배추 텃밭
				var garden_p: Vector2 = iso_point(o, 0.0, 0.6, 0.0, tw, th)
				for gi in range(3):
					draw_circle_img(img, garden_p + Vector2(float(gi) * 3.5 - 3.5, 0), 1.6, Color("22c55e"))

## 기와집 10종 (`tile_house_01` ~ `10`)
static func paint_tile_house(img: Image, c_size: Vector2, variant_idx: int) -> void:
	var tw: float = 64.0
	var th: float = 32.0
	var base_h: float = 3.5
	if variant_idx in [4, 5, 6]: # 1x2 중규모
		tw = 96.0
		th = 48.0
		base_h = 4.5
	elif variant_idx in [7, 8]: # 2x2 부호
		tw = 128.0
		th = 64.0
		base_h = 5.5
	elif variant_idx == 9: # 3x2 대부호
		tw = 160.0
		th = 80.0
		base_h = 6.5
	elif variant_idx == 10: # 3x3 거상 대저택
		tw = 192.0
		th = 96.0
		base_h = 7.5

	var o: Vector2 = Vector2(c_size.x * 0.5, c_size.y - th * 0.5 - 2.0)
	var col_base := Color("cbd5e1")
	var col_wall := Color("fdfbf7")
	var col_wall_shade := Color("cbd5e1")
	var col_timber := Color("5c3a21")
	var col_tile := Color("1e293b")
	var col_ridge := Color("f8fafc")

	# 1. 단정한 화강암 축대 기단
	draw_iso_ground(img, o, tw, th, col_base, Color("64748b"), base_h)

	match variant_idx:
		0: # 01: 2칸 정갈한 한옥 맞배지붕 + 솟을대문과 쪽문
			draw_hanok_structure(img, o, -0.65, 0.65, -0.55, 0.45, 0.0, 19.0, tw, th, 2, 1, -1, col_timber, col_wall, col_wall_shade, true)
			draw_iso_roof(img, o, -0.7, 0.7, -0.6, 0.5, 18.0, 32.0, col_tile, col_ridge, false, tw, th)
			# 솟을대문 및 담장
			var gate_p: Vector2 = iso_point(o, 0.0, 0.65, 0.0, tw, th)
			draw_rect_img(img, Rect2(gate_p - Vector2(4, 9), Vector2(8, 9)), Color("451a03"))
			draw_rect_img(img, Rect2(gate_p - Vector2(5, 10), Vector2(10, 2)), Color("1e293b"))

		1: # 02: 2칸 ㄱ자 팔작지붕 + 장독대 4기
			draw_hanok_structure(img, o, -0.65, 0.45, -0.55, 0.45, 0.0, 19.0, tw, th, 2, 1, -1, col_timber, col_wall, col_wall_shade, true)
			draw_iso_roof(img, o, -0.7, 0.5, -0.6, 0.5, 18.0, 33.0, col_tile, col_ridge, false, tw, th)
			var onggi_p: Vector2 = iso_point(o, 0.5, 0.5, 0.0, tw, th)
			draw_onggi_jars(img, onggi_p, 4)

		2: # 03: 2칸 오픈 대청마루 선비가 + 담장 너머 만개한 분홍 매화나무
			draw_hanok_structure(img, o, -0.65, 0.65, -0.55, 0.4, 0.0, 19.0, tw, th, 2, 1, 1, col_timber, col_wall, col_wall_shade, true)
			draw_iso_roof(img, o, -0.7, 0.7, -0.6, 0.45, 18.0, 32.0, col_tile, col_ridge, false, tw, th)
			# 분홍빛 매화나무
			var tr_p: Vector2 = iso_point(o, 0.5, 0.65, 0.0, tw, th)
			draw_line_img(img, tr_p, tr_p - Vector2(3, 14), Color("451a03"), 1.8)
			draw_circle_img(img, tr_p - Vector2(4, 15), 5.5, Color("f472b6"))
			draw_circle_img(img, tr_p - Vector2(1, 18), 4.2, Color("fb7185"))
			draw_circle_img(img, tr_p + Vector2(2, 14), 3.0, Color("fbcfe8"))

		3: # 04: 2칸 대문 앞 돌사자 석등과 디딤돌 선비가
			draw_hanok_structure(img, o, -0.65, 0.65, -0.55, 0.45, 0.0, 19.0, tw, th, 2, 1, -1, col_timber, col_wall, col_wall_shade, true)
			draw_iso_roof(img, o, -0.7, 0.7, -0.6, 0.5, 18.0, 32.0, col_tile, col_ridge, false, tw, th)
			# 화강암 석등
			var st_p: Vector2 = iso_point(o, -0.4, 0.7, 0.0, tw, th)
			draw_rect_img(img, Rect2(st_p - Vector2(2, 7), Vector2(4, 7)), Color("94a3b8"))
			draw_circle_img(img, st_p - Vector2(0, 8), 1.5, Color("fef08a"))

		4: # 05 (1x2): 3칸 본채(중앙 대청) + 솟을대문 행랑채 분리
			draw_hanok_structure(img, o, -0.8, 0.4, -0.6, 0.2, 0.0, 22.0, tw, th, 3, 2, 1, col_timber, col_wall, col_wall_shade, true)
			draw_iso_roof(img, o, -0.85, 0.45, -0.65, 0.25, 21.0, 38.0, col_tile, col_ridge, false, tw, th)
			# 별채 솟을대문 행랑채
			draw_hanok_structure(img, o, -0.2, 0.3, 0.3, 0.7, 0.0, 16.0, tw, th, 2, 1, -1, col_timber, col_wall, col_wall_shade, false)
			draw_iso_roof(img, o, -0.25, 0.35, 0.25, 0.75, 15.0, 28.0, col_tile, col_ridge, false, tw, th)

		5: # 06 (1x2): 3칸 ㄷ자 안채 + 사랑채 + 마당 작은 연못과 정원석
			draw_hanok_structure(img, o, -0.8, 0.8, -0.6, -0.1, 0.0, 22.0, tw, th, 3, 2, 1, col_timber, col_wall, col_wall_shade, true)
			draw_iso_roof(img, o, -0.85, 0.85, -0.65, -0.05, 21.0, 38.0, col_tile, col_ridge, false, tw, th)
			draw_hanok_structure(img, o, -0.8, -0.3, -0.1, 0.6, 0.0, 19.0, tw, th, 2, 2, -1, col_timber, col_wall, col_wall_shade, true)
			draw_iso_roof(img, o, -0.85, -0.25, -0.15, 0.65, 18.0, 32.0, col_tile, col_ridge, false, tw, th)
			# 중정 작은 연못과 연잎
			var pond_p: Vector2 = iso_point(o, 0.3, 0.3, 0.0, tw, th)
			draw_ellipse_img(img, pond_p, 5.5, 3.5, Color("0284c7"))
			draw_circle_img(img, pond_p + Vector2(1, -1), 1.8, Color("22c55e"))

		6: # 07 (1x2): 3칸 안채 + 2층 사랑채 돌출 누마루
			draw_hanok_structure(img, o, -0.75, 0.75, -0.55, 0.45, 0.0, 24.0, tw, th, 3, 2, 1, col_timber, col_wall, col_wall_shade, true)
			draw_iso_roof(img, o, -0.8, 0.8, -0.6, 0.5, 23.0, 42.0, col_tile, col_ridge, false, tw, th)
			# 2층 돌출 누마루
			draw_iso_box(img, o, 0.3, 0.8, 0.2, 0.6, 6.0, 24.0, Color("78350f"), Color("78350f"), Color("451a03"), tw, th, true)

		7: # 08 (2x2): 4칸 팔작지붕 웅장한 대가(오픈 대청, 툇마루) + 정원 붉은 노송
			draw_hanok_structure(img, o, -0.8, 0.8, -0.75, 0.35, 0.0, 26.0, tw, th, 4, 2, 1, col_timber, col_wall, col_wall_shade, true)
			draw_iso_roof(img, o, -0.85, 0.85, -0.8, 0.4, 25.0, 48.0, col_tile, col_ridge, false, tw, th)
			# 정원 명품 노송
			var pine_p: Vector2 = iso_point(o, 0.45, 0.65, 0.0, tw, th)
			draw_pine_tree(img, pine_p, 1.25)

		8: # 09 (2x2): 4칸 화강암 석축 위 2층 누각 별당 저택
			draw_hanok_structure(img, o, -0.8, 0.8, -0.8, 0.25, 0.0, 26.0, tw, th, 4, 2, 2, col_timber, col_wall, col_wall_shade, true)
			draw_iso_roof(img, o, -0.85, 0.85, -0.85, 0.3, 25.0, 48.0, col_tile, col_ridge, false, tw, th)
			# 2층 붉은 단청 누각
			draw_iso_box(img, o, -0.3, 0.5, 0.1, 0.7, 0.0, 30.0, Color("991b1b"), Color("991b1b"), Color("7f1d1d"), tw, th, true)
			draw_iso_roof(img, o, -0.35, 0.55, 0.05, 0.75, 29.0, 52.0, col_tile, col_ridge, false, tw, th)

		9: # 10_3x2 (3x2): 5칸 대부호 별서 대저택 (오픈 대청 안채 + 사랑채 + 연못과 홍예 구름다리)
			draw_hanok_structure(img, o, -0.85, 0.85, -0.8, 0.15, 0.0, 28.0, tw, th, 5, 2, 2, col_timber, col_wall, col_wall_shade, true)
			draw_iso_roof(img, o, -0.9, 0.9, -0.85, 0.2, 27.0, 52.0, col_tile, col_ridge, false, tw, th)
			draw_hanok_structure(img, o, 0.2, 0.85, 0.15, 0.75, 0.0, 24.0, tw, th, 3, 2, 1, col_timber, col_wall, col_wall_shade, true)
			draw_iso_roof(img, o, 0.15, 0.9, 0.1, 0.8, 23.0, 44.0, col_tile, col_ridge, false, tw, th)
			# 후원 넓은 연못과 구름다리
			var pond_l: Vector2 = iso_point(o, -0.3, 0.5, 0.0, tw, th)
			draw_ellipse_img(img, pond_l, 11.0, 6.5, Color("0284c7"))
			draw_line_img(img, pond_l - Vector2(8, 0), pond_l + Vector2(8, 0), Color("e2e8f0"), 2.4)

		10: # 10_3x3 (3x3): 5칸 거상 구십구칸 대저택 (중층 2단 대궐형 팔작지붕 + 좌우 별당 + 대형 곳간)
			draw_hanok_structure(img, o, -0.75, 0.75, -0.7, 0.15, 0.0, 32.0, tw, th, 5, 2, 2, col_timber, col_wall, col_wall_shade, true)
			draw_iso_roof(img, o, -0.8, 0.8, -0.75, 0.2, 31.0, 56.0, col_tile, col_ridge, false, tw, th)
			# 2층 중층 누각
			draw_hanok_structure(img, o, -0.45, 0.45, -0.5, 0.0, 32.0, 48.0, tw, th, 3, 1, 1, col_timber, col_wall, col_wall_shade, false)
			draw_iso_roof(img, o, -0.5, 0.5, -0.55, 0.05, 47.0, 68.0, col_tile, col_ridge, false, tw, th)
			# 좌측 별당 및 우측 대형 곳간
			draw_hanok_structure(img, o, -0.85, -0.4, 0.1, 0.7, 0.0, 22.0, tw, th, 2, 2, -1, col_timber, col_wall, col_wall_shade, true)
			draw_iso_roof(img, o, -0.9, -0.35, 0.05, 0.75, 21.0, 38.0, col_tile, col_ridge, false, tw, th)
			draw_hanok_structure(img, o, 0.4, 0.85, 0.1, 0.7, 0.0, 22.0, tw, th, 2, 2, -1, col_timber, col_wall, col_wall_shade, true)
			draw_iso_roof(img, o, 0.35, 0.9, 0.05, 0.75, 21.0, 38.0, col_tile, col_ridge, false, tw, th)

# =============================================================================
# 5. 저잣거리 상점 20종 정밀 도트 렌더러 (취급 품목 선명 시각화 & 팔달문 우시장 엄수)
# =============================================================================

static func paint_market_shop(img: Image, c_size: Vector2, shop_idx: int) -> void:
	var tw: float = 64.0
	var th: float = 32.0
	var o: Vector2 = Vector2(c_size.x * 0.5, c_size.y - th * 0.5 - 5.0)

	var col_ground := Color("c2a373")
	var col_wall := Color("d4b67b")
	var col_wall_shade := Color("a88950")
	var col_roof := Color("8e4b32") # 상점 붉은 기와 기본
	var col_ridge := Color("f8fafc")

	# 마당 기단
	draw_iso_ground(img, o, tw, th, col_ground, Color("997a48"))

	# 지붕이 상품을 가리지 않도록 뒤편으로 컴팩트하게 배치 (v: [-0.75, -0.05])
	draw_iso_box(img, o, -0.6, 0.6, -0.75, -0.05, 0.0, 16.0, col_wall, col_wall, col_wall_shade, tw, th, true)
	draw_iso_roof(img, o, -0.65, 0.65, -0.8, 0.0, 15.0, 28.0, col_roof, col_ridge, false, tw, th)

	# 앞쪽으로 활짝 열린 차양 천막 (v: [-0.05, 0.55])
	var awning_colors: Array[Color] = [
		Color("3b82f6"), Color("dc2626"), Color("10b981"), Color("f59e0b"),
		Color("6366f1"), Color("ec4899"), Color("14b8a6"), Color("8b5cf6")
	]
	var cur_awn_col: Color = awning_colors[shop_idx % awning_colors.size()]
	draw_awning(img, o, -0.6, 0.6, -0.05, 0.55, 14.0, 8.0, cur_awn_col, tw, th)

	# 넓고 시원한 앞쪽 가판대 및 대형 고유 상품 (눈에 확 띄는 색채와 실루엣!)
	var disp_p: Vector2 = iso_point(o, 0.0, 0.35, 0.0, tw, th)

	match shop_idx:
		0: # 01: 선전 (비단 원단 롤 4색 + 걸린 비단)
			draw_rect_img(img, Rect2(disp_p - Vector2(9, 6), Vector2(18, 6)), Color("543018"))
			draw_rect_img(img, Rect2(disp_p - Vector2(8, 10), Vector2(4, 5)), Color("dc2626")) # 적색 비단
			draw_rect_img(img, Rect2(disp_p - Vector2(3, 10), Vector2(4, 5)), Color("2563eb")) # 청색 비단
			draw_rect_img(img, Rect2(disp_p + Vector2(2, -10), Vector2(4, 5)), Color("eab308")) # 황색 비단
			draw_rect_img(img, Rect2(disp_p + Vector2(7, -10), Vector2(4, 5)), Color("10b981")) # 녹색 비단

		1: # 02: 도자기 (순백자 달항아리 + 청화백자병 + 찻잔)
			draw_rect_img(img, Rect2(disp_p - Vector2(9, 5), Vector2(18, 5)), Color("78350f"))
			draw_circle_img(img, disp_p - Vector2(5, 8), 3.2, Color("f8fafc")) # 달항아리
			draw_ellipse_img(img, disp_p + Vector2(0, -9), 2.5, 4.0, Color("e2e8f0")) # 청화백자
			set_p(img, int(roundf(disp_p.x)), int(roundf(disp_p.y - 9)), Color("2563eb")) # 청화 문양
			draw_circle_img(img, disp_p + Vector2(6, -7), 2.2, Color("34d399")) # 분청 다기

		2: # 03: 약방 ('藥' 현판 + 약재 건조 채반 2기 + 약탕기 모락모락 연기)
			draw_rect_img(img, Rect2(disp_p - Vector2(9, 5), Vector2(18, 5)), Color("451a03"))
			draw_ellipse_img(img, disp_p - Vector2(5, 7), 3.5, 2.0, Color("ca8a04")) # 약재 채반
			draw_ellipse_img(img, disp_p + Vector2(5, -7), 3.5, 2.0, Color("92400e"))
			# 검은 무쇠 약탕기와 연기
			draw_circle_img(img, disp_p - Vector2(0, 7), 2.8, Color("0f172a"))
			draw_circle_img(img, disp_p - Vector2(0, 11), 1.8, Color(0.9, 0.9, 0.9, 0.6))
			draw_circle_img(img, disp_p + Vector2(1, -14), 2.4, Color(0.95, 0.95, 0.95, 0.4))

		3: # 04: 서책방 (푸른 표지 방각본 책더미 + 족자 산수화 + 붓걸이)
			draw_rect_img(img, Rect2(disp_p - Vector2(8, 5), Vector2(16, 5)), Color("78350f"))
			# 쌓인 푸른 책들
			draw_rect_img(img, Rect2(disp_p - Vector2(6, 9), Vector2(5, 5)), Color("1d4ed8"))
			draw_line_img(img, disp_p - Vector2(6, 9), disp_p - Vector2(1, 9), Color("f8fafc"), 1.0)
			# 벽에 걸린 족자
			draw_rect_img(img, Rect2(disp_p + Vector2(1, -13), Vector2(5, 9)), Color("fef08a"))
			draw_line_img(img, disp_p + Vector2(2, -8), disp_p + Vector2(5, -6), Color("1e293b"), 1.0) # 산수화

		4: # 05: 갓방 (대나무 선반 위 양반 흑립 갓 2기 + 붉은 갓끈)
			draw_rect_img(img, Rect2(disp_p - Vector2(8, 5), Vector2(16, 5)), Color("543018"))
			# 검은 갓 (양태 + 모자)
			draw_ellipse_img(img, disp_p - Vector2(4, 7), 3.5, 1.4, Color("020617"))
			draw_rect_img(img, Rect2(disp_p - Vector2(5, 11), Vector2(2.5, 4.0)), Color("020617"))
			draw_ellipse_img(img, disp_p + Vector2(4, -7), 3.5, 1.4, Color("020617"))
			draw_rect_img(img, Rect2(disp_p + Vector2(3, -11), Vector2(2.5, 4.0)), Color("020617"))
			draw_line_img(img, disp_p - Vector2(4, 7), disp_p - Vector2(4, 4), Color("ef4444"), 1.0)

		5: # 06: 은/옥공예 (붉은 융단 + 은비녀 + 비취 옥 노리개)
			draw_rect_img(img, Rect2(disp_p - Vector2(9, 5), Vector2(18, 5)), Color("991b1b")) # 붉은 융단
			draw_line_img(img, disp_p - Vector2(6, 7), disp_p - Vector2(1, 7), Color("e2e8f0"), 1.4) # 은비녀
			draw_circle_img(img, disp_p + Vector2(4, -7), 2.2, Color("10b981")) # 비취 노리개
			draw_line_img(img, disp_p + Vector2(4, -5), disp_p + Vector2(4, -2), Color("ef4444"), 1.0) # 술

		6: # 07: 유기전 (황금빛 방짜유기 놋그릇 세트 + 놋대야 + 징)
			draw_rect_img(img, Rect2(disp_p - Vector2(9, 4), Vector2(18, 4)), Color("78350f"))
			draw_ellipse_img(img, disp_p - Vector2(5, 6), 2.8, 1.8, Color("eab308"))
			draw_ellipse_img(img, disp_p - Vector2(0, 7), 3.2, 2.0, Color("facc15"))
			draw_ellipse_img(img, disp_p + Vector2(5, -6), 2.8, 1.8, Color("eab308"))

		7: # 08: 악기전 (12현 가야금 + 적/황 장구 + 북)
			draw_rect_img(img, Rect2(disp_p - Vector2(8, 10), Vector2(4, 10)), Color("92400e")) # 가야금
			draw_circle_img(img, disp_p + Vector2(4, -6), 2.8, Color("fef08a")) # 장구 통
			draw_circle_img(img, disp_p + Vector2(4, -6), 1.8, Color("dc2626"))

		8: # 09: 팔달문 우시장 (★ 고유 기믹 100% 보존: 통나무 울타리 + 여물통 + 늠름한 황소 2마리)
			# 통나무 외곽 울타리
			draw_line_img(img, disp_p - Vector2(11, 8), disp_p + Vector2(11, -8), Color("78350f"), 1.4)
			draw_line_img(img, disp_p - Vector2(11, 4), disp_p + Vector2(11, -4), Color("78350f"), 1.4)
			for pi in range(5):
				var px: float = -10.0 + float(pi) * 5.0
				draw_line_img(img, disp_p + Vector2(px, -9), disp_p + Vector2(px, 0), Color("543018"), 1.2)
			# 황소 2마리 (한 마리는 왼쪽, 한 마리는 오른쪽을 봄)
			draw_ox(img, disp_p - Vector2(4, 2), true)
			draw_ox(img, disp_p + Vector2(4, 4), false)
			# 건초 및 여물통
			draw_rect_img(img, Rect2(disp_p - Vector2(2, 6), Vector2(5, 3)), Color("543018"))
			draw_rect_img(img, Rect2(disp_p - Vector2(1.5, 5.5), Vector2(4, 2)), Color("ca8a04"))

		9: # 10: 어물전 (푸른 좌대 + 은빛 조기 + 엮은 굴비 건조대)
			draw_rect_img(img, Rect2(disp_p - Vector2(9, 4), Vector2(18, 4)), Color("0284c7")) # 푸른 좌대
			draw_line_img(img, disp_p - Vector2(6, 6), disp_p - Vector2(2, 6), Color("f1f5f9"), 1.8) # 생선
			draw_line_img(img, disp_p + Vector2(1, -6), disp_p + Vector2(6, -6), Color("e2e8f0"), 1.8)
			# 말리는 굴비 줄
			draw_line_img(img, disp_p - Vector2(5, 12), disp_p - Vector2(5, 6), Color("b45309"), 1.0)
			for fi in range(3):
				draw_ellipse_img(img, disp_p - Vector2(5, 7 + fi * 2), 1.8, 0.9, Color("ca8a04"))

		10: # 11: 객주 (보부상 화물 궤짝 3개 + 봇짐 + 지게)
			draw_rect_img(img, Rect2(disp_p - Vector2(8, 7), Vector2(7, 7)), Color("543018")) # 대형 궤짝
			draw_rect_img(img, Rect2(disp_p - Vector2(0, 6), Vector2(6, 6)), Color("78350f"))
			draw_ellipse_img(img, disp_p + Vector2(5, -4), 3.2, 2.2, Color("fef08a")) # 노란 봇짐

		11: # 12: 싸전 (쌀/보리 곡물 가마니 + 넘쳐흐르는 됫박)
			draw_ellipse_img(img, disp_p - Vector2(5, 6), 4.0, 3.0, Color("d97706")) # 가마니
			draw_ellipse_img(img, disp_p + Vector2(4, -6), 4.0, 3.0, Color("ca8a04"))
			draw_rect_img(img, Rect2(disp_p - Vector2(1.5, 4), Vector2(4, 4)), Color("543018")) # 됫박
			draw_circle_img(img, disp_p + Vector2(0.5, -4), 1.5, Color("f8fafc")) # 흰 쌀

		12: # 13: 육전 (통나무 도마 + 무쇠 칼 + 걸린 붉은 고기 덩어리)
			draw_ellipse_img(img, disp_p, 4.5, 2.5, Color("78350f")) # 통나무 도마
			draw_line_img(img, disp_p - Vector2(1, 2), disp_p - Vector2(1, 5), Color("0f172a"), 1.4) # 칼
			# 걸린 붉은 쇠고기 덩어리
			draw_ellipse_img(img, disp_p + Vector2(5, -9), 2.8, 4.0, Color("dc2626"))
			draw_ellipse_img(img, disp_p - Vector2(5, -9), 2.4, 3.5, Color("991b1b"))

		13: # 14: 옹기전 (탑처럼 쌓인 갈색 옹기 시루와 대형 물독)
			draw_onggi_jars(img, disp_p, 5)

		14: # 15: 주막 ('酒' 붉은 깃발 + 대포 술항아리 + 나무 평상과 주전자)
			var flag_p: Vector2 = disp_p - Vector2(8, 0)
			draw_line_img(img, flag_p, flag_p - Vector2(0, 14), Color("543018"), 1.2)
			draw_rect_img(img, Rect2(flag_p - Vector2(0, 13), Vector2(6, 6)), Color("dc2626"))
			# 술상과 주전자
			draw_rect_img(img, Rect2(disp_p - Vector2(1, 4), Vector2(8, 4)), Color("b45309"))
			draw_circle_img(img, disp_p + Vector2(2, -6), 1.8, Color("facc15")) # 놋주전자

		15: # 16: 과일전 (붉은 사과 + 노란 감 + 푸른 배 소쿠리들)
			draw_ellipse_img(img, disp_p - Vector2(5, 5), 3.5, 2.0, Color("ca8a04"))
			draw_circle_img(img, disp_p - Vector2(5, 7), 1.8, Color("ef4444")) # 사과
			draw_ellipse_img(img, disp_p + Vector2(5, -5), 3.5, 2.0, Color("ca8a04"))
			draw_circle_img(img, disp_p + Vector2(5, -7), 1.8, Color("f97316")) # 감

		16: # 17: 떡전 (시루떡 + 오색 송편 쟁반 + 떡메)
			draw_ellipse_img(img, disp_p - Vector2(3, 5), 4.5, 2.5, Color("b45309"))
			draw_circle_img(img, disp_p - Vector2(4, 7), 1.4, Color("f8fafc"))
			draw_circle_img(img, disp_p - Vector2(2, 7), 1.4, Color("ec4899"))
			draw_circle_img(img, disp_p + Vector2(0, -7), 1.4, Color("22c55e"))

		17: # 18: 신방 (짚신 다발 + 사슴가죽 태사혜 가죽신 진열대)
			draw_rect_img(img, Rect2(disp_p - Vector2(8, 5), Vector2(16, 5)), Color("78350f"))
			draw_ellipse_img(img, disp_p - Vector2(4, 7), 2.2, 1.2, Color("ca8a04")) # 짚신
			draw_ellipse_img(img, disp_p + Vector2(4, -7), 2.2, 1.2, Color("1e293b")) # 가죽신

		18: # 19: 소금/양념전 (새하얀 천일염 포대 + 고춧가루 단지)
			draw_ellipse_img(img, disp_p - Vector2(4, 6), 3.8, 3.0, Color("f8fafc")) # 소금포대
			draw_circle_img(img, disp_p + Vector2(4, -6), 2.5, Color("991b1b")) # 고춧가루

		19: # 20: 연초전 (처마 밑 말리는 노란 담뱃잎 + 놋쇠 담뱃대 장죽)
			draw_rect_img(img, Rect2(disp_p - Vector2(7, 4), Vector2(14, 4)), Color("543018"))
			draw_line_img(img, disp_p - Vector2(5, 7), disp_p + Vector2(5, -7), Color("facc15"), 1.2) # 장죽 담뱃대
			draw_ellipse_img(img, disp_p + Vector2(0, -8), 2.5, 3.5, Color("ca8a04")) # 담뱃잎

# =============================================================================
# 6. 조선시대 고증 공방 13종 도트 렌더러 (1x1, 2x1, 2x2, 3x3)
# =============================================================================

static func paint_workshop(img: Image, c_size: Vector2, ws_key: String) -> void:
	var tw: float = 64.0
	var th: float = 32.0
	if ws_key.begins_with("ws_2x1"):
		tw = 96.0
		th = 48.0
	elif ws_key.begins_with("ws_2x2"):
		tw = 128.0
		th = 64.0
	elif ws_key.begins_with("ws_3x3"):
		tw = 192.0
		th = 96.0

	var o: Vector2 = Vector2(c_size.x * 0.5, c_size.y - th * 0.5 - 5.0)
	var col_ground := Color("c2a373")
	var col_wall := Color("a88950")
	var col_wall_shade := Color("785a28")
	var col_roof := Color("334155") # 공방 견고한 기와/초가
	var col_ridge := Color("f8fafc")

	# 공방 입체 기단 (석축 두께면 포함)
	draw_iso_ground(img, o, tw, th, col_ground, Color("785a28"), 3.0)

	# 후면 본작업장 (기단 -> 벽면 -> 지붕 온전한 순서 및 충분한 벽체 높이 확보)
	draw_iso_box(img, o, -0.65, 0.65, -0.75, -0.05, 0.0, 19.0, col_wall, col_wall, col_wall_shade, tw, th, true, Color("5c3a21"), true)
	draw_iso_roof(img, o, -0.7, 0.7, -0.8, -0.02, 18.0, 31.0, col_roof, col_ridge, false, tw, th)

	var p_yard: Vector2 = iso_point(o, 0.0, 0.35, 0.0, tw, th)

	match ws_key:
		"ws_1x1_carpenter": # 목공방: 작업대 + 톱/대패 + 목재 대들보
			draw_rect_img(img, Rect2(p_yard - Vector2(8, 5), Vector2(16, 5)), Color("78350f"))
			draw_line_img(img, p_yard - Vector2(7, 8), p_yard + Vector2(7, -8), Color("fde68a"), 2.2) # 목재

		"ws_1x1_bamboo": # 죽공방: 푸른 대나무 살 + 엮은 채반
			for bi in range(4):
				var bx: float = -6.0 + float(bi) * 4.0
				draw_line_img(img, p_yard + Vector2(bx, -10), p_yard + Vector2(bx, 0), Color("16a34a"), 1.4)
			draw_ellipse_img(img, p_yard + Vector2(3, -2), 3.5, 2.0, Color("ca8a04"))

		"ws_1x1_hanji": # 한지방: 종이 뜨는 수조 + 건조 발
			draw_rect_img(img, Rect2(p_yard - Vector2(7, 6), Vector2(14, 6)), Color("543018"))
			draw_rect_img(img, Rect2(p_yard - Vector2(6, 5.5), Vector2(12, 5)), Color("0284c7"))
			draw_rect_img(img, Rect2(p_yard - Vector2(5, 12), Vector2(10, 6)), Color("f8fafc")) # 건조 한지

		"ws_1x1_metalcraft": # 금속세공: 작은 도가니로 + 집게
			draw_circle_img(img, p_yard - Vector2(3, 4), 3.5, Color("0f172a"))
			draw_circle_img(img, p_yard - Vector2(3, 4), 1.8, Color("ea580c")) # 불꽃
			draw_line_img(img, p_yard + Vector2(1, -6), p_yard + Vector2(6, -2), Color("94a3b8"), 1.2)

		"ws_1x1_leather": # 피혁공방: 무두질 가죽틀
			draw_rect_img(img, Rect2(p_yard - Vector2(8, 10), Vector2(16, 10)), Color("78350f"))
			draw_ellipse_img(img, p_yard - Vector2(0, 5), 6.5, 3.8, Color("ca8a04"))

		"ws_2x1_blacksmith": # 대장간: 불타는 화덕 + 모루 + 담금질 수조
			# 붉은 화덕
			draw_rect_img(img, Rect2(p_yard - Vector2(12, 10), Vector2(8, 10)), Color("451a03"))
			draw_circle_img(img, p_yard - Vector2(8, 6), 2.5, Color("dc2626")) # 붉은 석탄불
			# 무쇠 모루
			draw_rect_img(img, Rect2(p_yard + Vector2(2, -7), Vector2(7, 6)), Color("0f172a"))
			# 담금질 수조
			draw_rect_img(img, Rect2(p_yard + Vector2(11, -5), Vector2(6, 5)), Color("0284c7"))

		"ws_2x1_dyeing": # 천연염색: 쪽물/홍화 대형 염색독 + 펄럭이는 오색 천
			draw_circle_img(img, p_yard - Vector2(8, 4), 4.2, Color("1e3a8a")) # 남색 독
			draw_circle_img(img, p_yard - Vector2(0, 4), 4.2, Color("991b1b")) # 붉은 독
			# 건조 장대와 천
			draw_line_img(img, p_yard + Vector2(6, -14), p_yard + Vector2(14, -14), Color("543018"), 1.2)
			draw_rect_img(img, Rect2(p_yard + Vector2(7, -13), Vector2(6, 10)), Color("3b82f6"))

		"ws_2x1_stonemason": # 석수공방: 거대한 화강암 원석 + 석등 조각
			draw_rect_img(img, Rect2(p_yard - Vector2(10, 8), Vector2(9, 8)), Color("94a3b8"))
			draw_rect_img(img, Rect2(p_yard + Vector2(2, -10), Vector2(6, 10)), Color("cbd5e1"))

		"ws_2x1_tile_kiln": # 기와가마: 돔형 소성 가마 + 연기
			draw_ellipse_img(img, p_yard - Vector2(2, 6), 9.0, 7.0, Color("543018"))
			draw_chimney_with_smoke(img, p_yard - Vector2(2, 12))

		"ws_2x1_shoemaker": # 갖신공방: 가죽 재단대 + 목형 신발틀
			draw_rect_img(img, Rect2(p_yard - Vector2(9, 6), Vector2(18, 6)), Color("78350f"))
			draw_ellipse_img(img, p_yard - Vector2(4, 8), 3.0, 1.5, Color("1e293b"))
			draw_ellipse_img(img, p_yard + Vector2(4, -8), 3.0, 1.5, Color("991b1b"))

		"ws_2x2_ceramics": # 대형 도예가마: 긴 등가마 + 초벌 도자기 무리
			draw_rect_img(img, Rect2(p_yard - Vector2(16, 14), Vector2(32, 12)), Color("57300a"))
			draw_chimney_with_smoke(img, p_yard - Vector2(12, 16))
			for di in range(6):
				draw_circle_img(img, p_yard + Vector2(float(di) * 4.0 - 10.0, 2), 2.0, Color("f8fafc"))

		"ws_2x2_lumber_machinery": # 대형 목재소: 거대 수차 + 통나무 제재 틀
			draw_circle_img(img, p_yard - Vector2(12, 6), 7.0, Color("543018")) # 수차
			draw_rect_img(img, Rect2(p_yard - Vector2(2, 8), Vector2(18, 8)), Color("ca8a04")) # 통나무

		"ws_3x3_royal_arsenal": # 관영 군기시 주조창: 거대 용광로 2기 + 대포 주물 틀 + 방호책
			draw_rect_img(img, Rect2(p_yard - Vector2(24, 20), Vector2(16, 18)), Color("1e293b"))
			draw_circle_img(img, p_yard - Vector2(16, 10), 5.0, Color("ea580c")) # 쇳물
			draw_chimney_with_smoke(img, p_yard - Vector2(16, 22))
			draw_rect_img(img, Rect2(p_yard + Vector2(8, -12), Vector2(16, 6)), Color("475569")) # 청동 대포

# =============================================================================
# 7. 특수 공동체 공간 5종 및 핵심 랜드마크 4종 도트 렌더러
# =============================================================================

static func paint_special_facility(img: Image, c_size: Vector2, facility_key: String) -> void:
	var tw: float = 128.0
	var th: float = 64.0
	if facility_key == "maegok_seowon":
		tw = 192.0
		th = 96.0
	elif facility_key == "well":
		tw = 64.0
		th = 32.0

	var o: Vector2 = Vector2(c_size.x * 0.5, c_size.y - th * 0.5 - 2.0)

	match facility_key:
		"seodang": # 2x2 서당: 훈장님 온돌 글방 2칸 + 오픈 대청마루 1칸 + 툇마루 + 화강암 디딤돌 + 명품 소나무
			draw_iso_ground(img, o, tw, th, Color("cbd5e1"), Color("64748b"), 5.0)
			# 3칸 서당 본채 (좌측 2칸 글방 + 우측 1칸 오픈 대청마루, 벽체 높이 28px)
			draw_hanok_structure(img, o, -0.75, 0.75, -0.65, 0.25, 0.0, 28.0, tw, th, 3, 2, 2, Color("5c3a21"), Color("fdfbf7"), Color("cbd5e1"), true)
			# 팔작지붕 (처마 높이 26.0, 용마루 높이 50.0)
			draw_iso_roof(img, o, -0.8, 0.8, -0.7, 0.3, 26.0, 50.0, Color("1e293b"), Color("f8fafc"), false, tw, th)
			# 앞마당 화강암 디딤돌 3개
			var step0: Vector2 = iso_point(o, 0.1, 0.42, 0.0, tw, th)
			var step1: Vector2 = iso_point(o, 0.25, 0.52, 0.0, tw, th)
			var step2: Vector2 = iso_point(o, 0.4, 0.62, 0.0, tw, th)
			draw_ellipse_img(img, step0, 3.5, 2.0, Color("94a3b8"))
			draw_ellipse_img(img, step1, 4.0, 2.2, Color("94a3b8"))
			draw_ellipse_img(img, step2, 4.5, 2.5, Color("94a3b8"))
			# 앞마당 고즈넉한 선비 소나무
			var pine_p: Vector2 = iso_point(o, 0.55, 0.65, 0.0, tw, th)
			draw_pine_tree(img, pine_p, 1.15)

		"maegok_seowon": # 3x3 매곡서원: 5칸 명륜당 대강당 + 솟을삼문 + 배롱나무
			draw_iso_ground(img, o, tw, th, Color("cbd5e1"), Color("64748b"), 6.0)
			# 5칸 대강당 (중앙 오픈 강학당, 벽체 높이 30px)
			draw_hanok_structure(img, o, -0.75, 0.75, -0.75, 0.05, 0.0, 30.0, tw, th, 5, 2, 2, Color("5c3a21"), Color("fdfbf7"), Color("cbd5e1"), true)
			draw_iso_roof(img, o, -0.8, 0.8, -0.8, 0.1, 29.0, 54.0, Color("1e293b"), Color("f8fafc"), false, tw, th)
			# 솟을삼문
			draw_hanok_structure(img, o, -0.35, 0.35, 0.45, 0.85, 0.0, 18.0, tw, th, 3, 1, 1, Color("7f1d1d"), Color("fdfbf7"), Color("cbd5e1"), false)
			draw_iso_roof(img, o, -0.4, 0.4, 0.4, 0.9, 17.0, 32.0, Color("1e293b"), Color("f8fafc"), false, tw, th)

		"well": # 1x1 공동 우물
			paint_well(img, c_size)

## 우물 전용 정밀 렌더러
static func paint_well(img: Image, c_size: Vector2) -> void:
	var mid_x: int = int(c_size.x * 0.5)
	var base_y: int = int(c_size.y * 0.68)
	var wc := Vector2(float(mid_x), float(base_y))

	# 바닥 그림자
	draw_ellipse_img(img, wc + Vector2(1, 1), 11.0, 5.0, Color(0, 0, 0, 0.3))

	# 화강암 돌담 테두리
	draw_circle_img(img, wc - Vector2(0, 2), 8.5, Color("64748b"))
	draw_circle_img(img, wc - Vector2(0, 2.5), 7.8, Color("94a3b8"))

	# 깊은 물면
	draw_circle_img(img, wc - Vector2(0, 3.2), 5.2, Color("0f172a"))
	draw_circle_img(img, wc - Vector2(0, 3.8), 4.5, Color("0284c7"))
	draw_circle_img(img, wc - Vector2(-1, 4.2), 2.2, Color("38bdf8"))

	# 목조 기둥 2개와 지붕
	draw_line_img(img, wc - Vector2(7, 2), wc - Vector2(7, 18), Color("5c3a21"), 1.6)
	draw_line_img(img, wc + Vector2(7, -2), wc + Vector2(7, -18), Color("5c3a21"), 1.6)
	draw_line_img(img, wc - Vector2(8, 18), wc + Vector2(8, 18), Color("5c3a21"), 1.4)

	# 두레박과 밧줄
	draw_line_img(img, wc - Vector2(0, 18), wc - Vector2(0, 8), Color("fde68a"), 1.0)
	draw_rect_img(img, Rect2(wc - Vector2(2, 9), Vector2(4, 4)), Color("543018"))

	# 상단 맞배지붕
	var r_pts: Array[Vector2] = [
		wc + Vector2(-12, -18), wc + Vector2(0, -25), wc + Vector2(12, -18)
	]
	fill_tri(img, r_pts[0], r_pts[1], r_pts[2], Color("1e293b"))
	draw_line_img(img, r_pts[0], r_pts[2], Color("475569"), 1.2)
	draw_line_img(img, wc + Vector2(-6, -21), wc + Vector2(6, -21), Color("f8fafc"), 1.4)

## 핵심 랜드마크 4종
static func paint_landmark(img: Image, c_size: Vector2, landmark_key: String) -> void:
	match landmark_key:
		"haenggung": # 7x7 화성행궁 본궁
			var tw: float = 448.0
			var th: float = 224.0
			var o: Vector2 = Vector2(c_size.x * 0.5, c_size.y - th * 0.5 - 2.0)
			draw_iso_ground(img, o, tw, th, Color("cbd5e1"), Color("64748b"))
			# 봉수당 본채
			draw_iso_box(img, o, -0.5, 0.5, -0.8, -0.2, 0.0, 36.0, Color("dc2626"), Color("dc2626"), Color("991b1b"), tw, th, true)
			draw_iso_roof(img, o, -0.55, 0.55, -0.85, -0.15, 35.0, 70.0, Color("1e293b"), Color("f8fafc"), false, tw, th)
			# 신풍루 정문
			draw_iso_box(img, o, -0.3, 0.3, 0.5, 0.8, 0.0, 26.0, Color("dc2626"), Color("dc2626"), Color("991b1b"), tw, th, true)
			draw_iso_roof(img, o, -0.35, 0.35, 0.45, 0.85, 25.0, 52.0, Color("1e293b"), Color("f8fafc"), false, tw, th)

		"seojangdae": # 2x2 서장대
			var tw: float = 128.0
			var th: float = 64.0
			var o: Vector2 = Vector2(c_size.x * 0.5, c_size.y - th * 0.5 - 2.0)
			draw_iso_ground(img, o, tw, th, Color("94a3b8"), Color("475569"))
			draw_iso_box(img, o, -0.7, 0.7, -0.7, 0.7, 0.0, 18.0, Color("94a3b8"), Color("94a3b8"), Color("64748b"), tw, th, true)
			draw_iso_box(img, o, -0.5, 0.5, -0.5, 0.5, 18.0, 32.0, Color("dc2626"), Color("dc2626"), Color("991b1b"), tw, th, true)
			draw_iso_roof(img, o, -0.55, 0.55, -0.55, 0.55, 31.0, 54.0, Color("1e293b"), Color("f8fafc"), false, tw, th)

		"yeonmudae": # 2x2 연무대
			var tw: float = 128.0
			var th: float = 64.0
			var o: Vector2 = Vector2(c_size.x * 0.5, c_size.y - th * 0.5 - 2.0)
			draw_iso_ground(img, o, tw, th, Color("d4b483"), Color("997a48"))
			draw_iso_box(img, o, -0.6, 0.6, -0.6, 0.6, 0.0, 16.0, Color("b45309"), Color("b45309"), Color("78350f"), tw, th, true)
			draw_iso_roof(img, o, -0.65, 0.65, -0.65, 0.65, 15.0, 36.0, Color("1e293b"), Color("f8fafc"), false, tw, th)

		"yusubu": # 2x2 화성유수부 동헌
			var tw: float = 128.0
			var th: float = 64.0
			var o: Vector2 = Vector2(c_size.x * 0.5, c_size.y - th * 0.5 - 2.0)
			draw_iso_ground(img, o, tw, th, Color("cbd5e1"), Color("64748b"))
			draw_iso_box(img, o, -0.7, 0.7, -0.7, 0.5, 0.0, 20.0, Color("f8f5eb"), Color("f8f5eb"), Color("cbd5e1"), tw, th, true, Color("5c3a21"), true)
			draw_iso_roof(img, o, -0.75, 0.75, -0.75, 0.55, 19.0, 42.0, Color("1e293b"), Color("f8fafc"), false, tw, th)

		"yeonghwajeong": # 2x2 영화정 본각
			var tw_yg: float = 128.0
			var th_yg: float = 64.0
			var o_yg: Vector2 = Vector2(c_size.x * 0.5, c_size.y - th_yg * 0.5 - 2.0)
			draw_iso_ground(img, o_yg, tw_yg, th_yg, Color("cfcac0"), Color("94a3b8"))
			# 2단 화강암 장대석 기단
			draw_iso_box(img, o_yg, -0.85, 0.85, -0.75, 0.75, 0.0, 6.0, Color("beb8ac"), Color("beb8ac"), Color("7a7368"), tw_yg, th_yg, true)
			draw_iso_box(img, o_yg, -0.72, 0.72, -0.62, 0.62, 6.0, 10.0, Color("dcd6cb"), Color("dcd6cb"), Color("857d72"), tw_yg, th_yg, true)
			# 우물마루 목재 대청
			draw_iso_box(img, o_yg, -0.65, 0.65, -0.55, 0.55, 10.0, 11.0, Color("c08848"), Color("c08848"), Color("8e5c26"), tw_yg, th_yg, false)
			# 주칠 기둥 및 벽체
			draw_iso_box(img, o_yg, -0.55, 0.55, -0.45, 0.45, 11.0, 32.0, Color("fbf8f0"), Color("fbf8f0"), Color("94261e"), tw_yg, th_yg, true, Color("94261e"), true)
			# 날렵한 2.5D 팔작지붕
			draw_iso_roof(img, o_yg, -0.90, 0.90, -0.80, 0.80, 31.0, 56.0, Color("1e293b"), Color("f8fafc"), false, tw_yg, th_yg)

		"manseokgeo": # 6x6 만석거 대호수 썸네일
			var tw_mg: float = c_size.x * 0.88
			var th_mg: float = c_size.y * 0.44
			var o_mg: Vector2 = Vector2(c_size.x * 0.5, c_size.y - th_mg * 0.5 - 4.0)
			draw_iso_ground(img, o_mg, tw_mg, th_mg, Color("65a30d"), Color("475569"))
			# 에메랄드 비취빛 호수 수면
			draw_iso_ground(img, o_mg, tw_mg * 0.82, th_mg * 0.82, Color("0891b2"), Color("155e75"))
			draw_iso_ground(img, o_mg, tw_mg * 0.60, th_mg * 0.60, Color("0e7490"), Color("164e63"))
			# 중앙 타원형 조도(인공섬)
			draw_iso_ground(img, o_mg, tw_mg * 0.28, th_mg * 0.28, Color("4d7c0f"), Color("8a8478"))
			draw_pine_tree(img, o_mg - Vector2(2.0, 6.0), 0.9)

		"chukmanje": # 6x6 축만제(서호) 대호수 썸네일
			var tw_cm: float = c_size.x * 0.88
			var th_cm: float = c_size.y * 0.44
			var o_cm: Vector2 = Vector2(c_size.x * 0.5, c_size.y - th_cm * 0.5 - 4.0)
			draw_iso_ground(img, o_cm, tw_cm, th_cm, Color("5b823e"), Color("475569"))
			# 코발트 블루 서호 수면
			draw_iso_ground(img, o_cm, tw_cm * 0.82, th_cm * 0.82, Color("0284c7"), Color("075985"))
			# 서호 당주 갈대 모래톱
			draw_iso_ground(img, o_cm, tw_cm * 0.30, th_cm * 0.30, Color("d4b483"), Color("65a30d"))
			draw_circle_img(img, o_cm - Vector2(4.0, 4.0), 1.6, Color("ffffff")) # 백로 도트

# =============================================================================
# 8. CanvasItem 드로잉 호환 인터페이스 (선택적 호출 지원)
# =============================================================================

static func draw_thatch_house(ci: CanvasItem, c_size: Vector2, variant_idx: int) -> void:
	var img := Image.create(int(c_size.x), int(c_size.y), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	paint_thatch_house(img, c_size, variant_idx)
	var tex := ImageTexture.create_from_image(img)
	ci.draw_texture(tex, Vector2.ZERO)

static func draw_tile_house(ci: CanvasItem, c_size: Vector2, variant_idx: int) -> void:
	var img := Image.create(int(c_size.x), int(c_size.y), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	paint_tile_house(img, c_size, variant_idx)
	var tex := ImageTexture.create_from_image(img)
	ci.draw_texture(tex, Vector2.ZERO)

static func draw_market_shop(ci: CanvasItem, c_size: Vector2, shop_idx: int) -> void:
	var img := Image.create(int(c_size.x), int(c_size.y), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	paint_market_shop(img, c_size, shop_idx)
	var tex := ImageTexture.create_from_image(img)
	ci.draw_texture(tex, Vector2.ZERO)

static func draw_workshop(ci: CanvasItem, c_size: Vector2, ws_key: String) -> void:
	var img := Image.create(int(c_size.x), int(c_size.y), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	paint_workshop(img, c_size, ws_key)
	var tex := ImageTexture.create_from_image(img)
	ci.draw_texture(tex, Vector2.ZERO)

static func draw_special_facility(ci: CanvasItem, c_size: Vector2, facility_key: String) -> void:
	var img := Image.create(int(c_size.x), int(c_size.y), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	paint_special_facility(img, c_size, facility_key)
	var tex := ImageTexture.create_from_image(img)
	ci.draw_texture(tex, Vector2.ZERO)

static func draw_landmark(ci: CanvasItem, c_size: Vector2, landmark_key: String) -> void:
	var img := Image.create(int(c_size.x), int(c_size.y), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	paint_landmark(img, c_size, landmark_key)
	var tex := ImageTexture.create_from_image(img)
	ci.draw_texture(tex, Vector2.ZERO)

static func draw_well(ci: CanvasItem, c_size: Vector2) -> void:
	var img := Image.create(int(c_size.x), int(c_size.y), false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	paint_well(img, c_size)
	var tex := ImageTexture.create_from_image(img)
	ci.draw_texture(tex, Vector2.ZERO)
