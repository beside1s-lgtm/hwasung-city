extends RefCounted
class_name PaddyFieldArt

## 조선 시대 대유둔전(大有屯田) 및 권농 고증 2D 도트그래픽 렌더러
## 타일 정점에 밀착된 2.5D 아이소메트릭 기하학과 사계절 생태(모내기·초록벼·황금벼·추수)
## 및 필지별 미세 톤 변조(Tone Modulation)를 통한 광활한 평야 모자이크 패치워크 구현

## 기본 팔레트 정의
const COL_LEVEE_SPRING := Color("543f29")
const COL_LEVEE_SUMMER := Color("3a5e24")
const COL_LEVEE_AUTUMN := Color("6c5535")
const COL_LEVEE_WINTER := Color("7a7368")

const COL_STONE_LEVEE := Color("827b72")
const COL_STONE_HIGHLIGHT := Color("9e988e")
const COL_WOOD_GATE := Color("3d2817")
const COL_WATER_INFLOW := Color(0.55, 0.82, 0.95, 0.85)

## 둔전 렌더링 메인 진입점
static func draw_field(
	ci: CanvasItem,
	x: int,
	y: int,
	_t: Dictionary,
	c: Vector2,
	p_n: Vector2,
	p_e: Vector2,
	p_s: Vector2,
	p_w: Vector2,
	season: String,
	is_advanced: bool,
	has_water: bool,
	is_drought: bool,
	anim_tick: float = 0.0
) -> void:
	# 1. 결정론적 시드 및 필지별 모자이크 톤 변조 (사진과 같은 항공 패치워크 효과)
	var tile_seed: int = (x * 73856093) ^ (y * 19349663)
	var tone_var: int = (tile_seed >> 3) & 7
	var tint_shift: float = (float(tone_var) - 3.5) * 0.035
	var warm_shift: float = (float((tile_seed >> 7) & 3) - 1.5) * 0.04
	var furrow_axis: int = (tile_seed >> 2) & 1

	# 2. 타일 정점 인셋(Inset)을 통한 정밀한 2.5D 논두렁 기하학 (타일에 100% 밀착)
	var inset_ratio: float = 0.87 if is_advanced else 0.85
	var ip_n: Vector2 = c.lerp(p_n, inset_ratio)
	var ip_e: Vector2 = c.lerp(p_e, inset_ratio)
	var ip_s: Vector2 = c.lerp(p_s, inset_ratio)
	var ip_w: Vector2 = c.lerp(p_w, inset_ratio)

	# 3. 논두렁(Levee / 둑길) 렌더링
	_draw_levees(ci, p_n, p_e, p_s, p_w, ip_n, ip_e, ip_s, ip_w, season, is_advanced, tile_seed)

	# 4. 내곽 논바닥(Paddy Bed) 다각형 채우기
	var bed_poly := PackedVector2Array([ip_n, ip_e, ip_s, ip_w])
	_draw_paddy_bed(ci, bed_poly, season, has_water, is_drought, tint_shift, warm_shift, anim_tick)

	# 5. 사계절 작물 및 볏이랑(Furrows) 정밀 2D 도트 드로잉
	match season:
		"봄":
			_draw_spring_rice_seedlings(ci, ip_n, ip_e, ip_s, ip_w, furrow_axis, is_advanced, has_water, is_drought, tint_shift)
		"여름":
			_draw_summer_green_paddy(ci, ip_n, ip_e, ip_s, ip_w, furrow_axis, is_advanced, is_drought, tint_shift, warm_shift, anim_tick)
		"가을":
			_draw_autumn_golden_harvest(ci, ip_n, ip_e, ip_s, ip_w, furrow_axis, is_advanced, is_drought, tint_shift, warm_shift)
		"겨울":
			_draw_winter_straw_stacks(ci, c, ip_n, ip_e, ip_s, ip_w, furrow_axis, is_advanced, tint_shift)
		_:
			_draw_spring_rice_seedlings(ci, ip_n, ip_e, ip_s, ip_w, furrow_axis, is_advanced, has_water, is_drought, tint_shift)

	# 6. 관개 수문/물꼬 디테일 (대유둔전 agr_2 전용)
	if is_advanced and not is_drought:
		_draw_irrigation_gate(ci, ip_s, p_s, c)


## 논두렁(둑길) 렌더러
static func _draw_levees(
	ci: CanvasItem,
	p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2,
	ip_n: Vector2, ip_e: Vector2, ip_s: Vector2, ip_w: Vector2,
	season: String,
	is_advanced: bool,
	tile_seed: int
) -> void:
	# 계절별 논두렁 바탕색
	var base_col: Color
	match season:
		"봄": base_col = COL_LEVEE_SPRING
		"여름": base_col = COL_LEVEE_SUMMER
		"가을": base_col = COL_LEVEE_AUTUMN
		"겨울": base_col = COL_LEVEE_WINTER
		_: base_col = COL_LEVEE_SPRING

	if is_advanced:
		base_col = base_col.lerp(COL_STONE_LEVEE, 0.6)

	# 4개 변 외곽-내곽 사다리꼴 논두렁
	ci.draw_colored_polygon(PackedVector2Array([p_n, p_e, ip_e, ip_n]), base_col.lightened(0.08)) # 북동 (빛받음)
	ci.draw_colored_polygon(PackedVector2Array([p_n, ip_n, ip_w, p_w]), base_col.lightened(0.12)) # 북서 (빛받음)
	ci.draw_colored_polygon(PackedVector2Array([p_w, ip_w, ip_s, p_s]), base_col.darkened(0.12))  # 남서 (음영)
	ci.draw_colored_polygon(PackedVector2Array([p_e, p_s, ip_s, ip_e]), base_col.darkened(0.18))  # 남동 (음영)

	# 논두렁 외곽 1px 도트 테두리
	ci.draw_line(p_n, p_w, Color("ffffff", 0.18), 1.0)
	ci.draw_line(p_n, p_e, Color("ffffff", 0.12), 1.0)
	ci.draw_line(p_w, p_s, Color("000000", 0.25), 1.0)
	ci.draw_line(p_e, p_s, Color("000000", 0.30), 1.0)

	# 흙둑/돌둑 텍스처 도트
	if is_advanced:
		# 화강암 석축 줄눈 도트
		for k: float in [0.25, 0.50, 0.75]:
			var stone_pt1: Vector2 = p_w.lerp(p_s, k)
			ci.draw_line(stone_pt1, stone_pt1 + Vector2(1.2, -0.6), COL_STONE_HIGHLIGHT, 1.2)
			var stone_pt2: Vector2 = p_n.lerp(p_e, k)
			ci.draw_line(stone_pt2, stone_pt2 + Vector2(-1.2, 0.6), COL_STONE_HIGHLIGHT, 1.2)
	else:
		# 소박한 잔디 점 / 흙 점
		var grass_dot: Color = Color("62ab35") if season != "겨울" else Color("91887e")
		if (tile_seed & 1) == 0:
			FastDraw.circle(ci, p_n.lerp(p_w, 0.4), 1.2, grass_dot)
			FastDraw.circle(ci, p_e.lerp(p_s, 0.6), 1.0, grass_dot)
		else:
			FastDraw.circle(ci, p_n.lerp(p_e, 0.5), 1.1, grass_dot)
			FastDraw.circle(ci, p_w.lerp(p_s, 0.4), 1.2, grass_dot)


## 내곽 논바닥 렌더러
static func _draw_paddy_bed(
	ci: CanvasItem,
	bed_poly: PackedVector2Array,
	season: String,
	has_water: bool,
	is_drought: bool,
	tint_shift: float,
	warm_shift: float,
	anim_tick: float
) -> void:
	var bed_col: Color
	match season:
		"봄":
			if is_drought:
				bed_col = Color(0.48 + tint_shift, 0.38 + tint_shift, 0.28 + warm_shift)
			else:
				# 찰랑이는 맑은 무논 수면 (하늘빛 반사)
				bed_col = Color(0.28 + tint_shift * 0.5, 0.52 + tint_shift * 0.6, 0.64 + warm_shift * 0.3)
		"여름":
			if is_drought:
				bed_col = Color(0.32 + tint_shift, 0.44 + tint_shift, 0.22)
			else:
				# 짙푸른 녹음 바닥
				bed_col = Color(0.14 + warm_shift * 0.3, 0.35 + tint_shift * 0.6, 0.12 + tint_shift * 0.3)
		"가을":
			# 찬란한 황금빛 융단
			bed_col = Color(0.84 + warm_shift * 0.5, 0.64 + tint_shift * 0.7, 0.16 + tint_shift * 0.3)
		"겨울":
			# 추수 후 마른 볏짚/황토
			bed_col = Color(0.58 + tint_shift * 0.4, 0.49 + tint_shift * 0.3, 0.38 + warm_shift * 0.3)
		_:
			bed_col = Color(0.28, 0.52, 0.64)

	FastDraw.poly(ci, bed_poly, bed_col)

	# 봄철 무논 물결 반사광
	if season == "봄" and not is_drought and has_water:
		var p1: Vector2 = bed_poly[3].lerp(bed_poly[0], 0.3)
		var p2: Vector2 = bed_poly[2].lerp(bed_poly[1], 0.3)
		var shimmer_phase: float = sin(anim_tick * 2.0 + p1.x * 0.05) * 0.08
		ci.draw_line(p1, p2, Color(0.68, 0.88, 0.98, 0.30 + shimmer_phase), 1.4)
	elif is_drought:
		# 가뭄 거북등 균열 도트
		var mid: Vector2 = (bed_poly[0] + bed_poly[2]) * 0.5
		ci.draw_line(mid + Vector2(-5, -2), mid + Vector2(4, 3), Color("38291a", 0.7), 1.0)
		ci.draw_line(mid + Vector2(-1, -4), mid + Vector2(2, 5), Color("38291a", 0.7), 1.0)


## 봄: 모내기철 렌더러 (못줄을 띄워 오와 열을 맞춘 앙증맞은 어린 모)
static func _draw_spring_rice_seedlings(
	ci: CanvasItem,
	ip_n: Vector2, ip_e: Vector2, ip_s: Vector2, ip_w: Vector2,
	axis: int,
	is_advanced: bool,
	has_water: bool,
	is_drought: bool,
	tint_shift: float
) -> void:
	var rows: Array[float] = [0.22, 0.42, 0.62, 0.82]
	if is_advanced:
		rows = [0.18, 0.34, 0.50, 0.66, 0.82]

	var col_stem: Color = Color(0.48 + tint_shift * 0.5, 0.88, 0.24) if not is_drought else Color(0.55, 0.62, 0.32)
	var col_leaf: Color = Color(0.64 + tint_shift * 0.5, 0.96, 0.34) if not is_drought else Color(0.65, 0.72, 0.40)
	var col_shadow: Color = Color(0.18, 0.38, 0.22, 0.60)

	for r_t: float in rows:
		var p_start: Vector2 = ip_n.lerp(ip_w, r_t) if axis == 0 else ip_w.lerp(ip_s, r_t)
		var p_end: Vector2 = ip_e.lerp(ip_s, r_t) if axis == 0 else ip_n.lerp(ip_e, r_t)

		# 고랑/물길 얕은 음영선
		if has_water and not is_drought:
			ci.draw_line(p_start, p_end, Color(0.20, 0.40, 0.50, 0.35), 1.0)

		# 모내기 포기 배치 (균등 간격)
		var count: int = 5 if is_advanced else 4
		for k: int in range(count):
			var ct: float = float(k + 1) / float(count + 1)
			var cp: Vector2 = p_start.lerp(p_end, ct)

			# 수면 반사/그림자 점
			if has_water and not is_drought:
				FastDraw.circle(ci, cp + Vector2(0.0, 0.5), 1.2, Color(0.65, 0.85, 0.98, 0.35))
				FastDraw.circle(ci, cp, 0.8, col_shadow)

			# 앙증맞은 어린 모 2~3가닥 도트
			ci.draw_line(cp, cp + Vector2(-1.0, -2.4), col_stem, 1.2)
			ci.draw_line(cp, cp + Vector2(1.0, -2.6), col_leaf, 1.2)
			ci.draw_line(cp, cp + Vector2(0.0, -3.2), col_leaf, 1.0)


## 여름: 초록 벼 생육기 렌더러 (바람에 일렁이는 짙푸른 벼이랑과 녹음 융단)
static func _draw_summer_green_paddy(
	ci: CanvasItem,
	ip_n: Vector2, ip_e: Vector2, ip_s: Vector2, ip_w: Vector2,
	axis: int,
	is_advanced: bool,
	is_drought: bool,
	tint_shift: float,
	warm_shift: float,
	anim_tick: float
) -> void:
	var rows: Array[float] = [0.20, 0.40, 0.60, 0.80]
	if is_advanced:
		rows = [0.16, 0.32, 0.48, 0.64, 0.80]

	var col_dark: Color = Color(0.14 + warm_shift * 0.2, 0.38 + tint_shift * 0.5, 0.10)
	var col_mid: Color = Color(0.22 + warm_shift * 0.2, 0.58 + tint_shift * 0.6, 0.16)
	var col_light: Color = Color(0.42 + warm_shift * 0.3, 0.82 + tint_shift * 0.6, 0.26)

	if is_drought:
		col_mid = col_mid.lerp(Color("726e48"), 0.4)
		col_light = col_light.lerp(Color("8a8458"), 0.4)

	var wind_sway: float = sin(anim_tick * 2.5) * 0.8

	for r_t: float in rows:
		var p_start: Vector2 = ip_n.lerp(ip_w, r_t) if axis == 0 else ip_w.lerp(ip_s, r_t)
		var p_end: Vector2 = ip_e.lerp(ip_s, r_t) if axis == 0 else ip_n.lerp(ip_e, r_t)

		# 벼이랑 밑동 짙은 그림자 리본
		ci.draw_line(p_start, p_end, col_dark, 1.8)

		# 풍성한 벼포기 연쇄 (볼륨감 있는 2D 도트)
		var count: int = 6 if is_advanced else 5
		for k: int in range(count):
			var ct: float = float(k + 1) / float(count + 1)
			var cp: Vector2 = p_start.lerp(p_end, ct)

			# 벼 줄기 및 좌우 풍성한 잎사귀
			ci.draw_line(cp, cp + Vector2(-1.8 + wind_sway * 0.5, -4.5), col_mid, 1.4)
			ci.draw_line(cp, cp + Vector2(1.8 + wind_sway * 0.5, -4.8), col_mid, 1.4)
			ci.draw_line(cp, cp + Vector2(wind_sway, -6.5), col_light, 1.6)
			# 잎끝 하이라이트 도트
			FastDraw.circle(ci, cp + Vector2(wind_sway, -6.5), 1.0, col_light.lightened(0.15))


## 가을: 황금빛 벼이삭 수확기 렌더러 (고개 숙인 풍성한 이삭과 황금 들판)
static func _draw_autumn_golden_harvest(
	ci: CanvasItem,
	ip_n: Vector2, ip_e: Vector2, ip_s: Vector2, ip_w: Vector2,
	axis: int,
	is_advanced: bool,
	is_drought: bool,
	tint_shift: float,
	warm_shift: float
) -> void:
	var rows: Array[float] = [0.20, 0.40, 0.60, 0.80]
	if is_advanced:
		rows = [0.16, 0.32, 0.48, 0.64, 0.80]

	# 눈부신 황금빛/호박빛 팔레트
	var col_stalk: Color = Color(0.72 + warm_shift * 0.4, 0.54 + tint_shift * 0.5, 0.16)
	var col_grain: Color = Color(0.94 + warm_shift * 0.3, 0.74 + tint_shift * 0.6, 0.18)
	var col_high: Color = Color(1.0, 0.90 + tint_shift * 0.4, 0.42)
	var col_shadow: Color = Color(0.55, 0.38, 0.10)

	if is_drought:
		col_grain = col_grain.lerp(Color("7a6a42"), 0.35)
		col_high = col_high.lerp(Color("968456"), 0.35)

	for r_t: float in rows:
		var p_start: Vector2 = ip_n.lerp(ip_w, r_t) if axis == 0 else ip_w.lerp(ip_s, r_t)
		var p_end: Vector2 = ip_e.lerp(ip_s, r_t) if axis == 0 else ip_n.lerp(ip_e, r_t)

		# 황금빛 이랑 띠
		ci.draw_line(p_start, p_end, col_shadow, 1.5)

		# 고개 숙인 풍성한 벼이삭
		var count: int = 6 if is_advanced else 5
		for k: int in range(count):
			var ct: float = float(k + 1) / float(count + 1)
			var cp: Vector2 = p_start.lerp(p_end, ct)

			# 볏대 줄기
			ci.draw_line(cp, cp + Vector2(0.0, -3.2), col_stalk, 1.4)
			# 고개 숙인 이삭 목 (오른쪽 아래로 늘어짐)
			ci.draw_line(cp + Vector2(0.0, -3.2), cp + Vector2(2.4, -4.5), col_grain, 2.0)
			ci.draw_line(cp + Vector2(2.4, -4.5), cp + Vector2(3.5, -3.2), col_grain, 1.8)

			# 알알이 영근 금빛 알곡 하이라이트
			FastDraw.circle(ci, cp + Vector2(2.5, -4.8), 1.3, col_high)
			FastDraw.circle(ci, cp + Vector2(3.5, -3.4), 1.1, col_high)
			if is_advanced:
				FastDraw.circle(ci, cp + Vector2(1.2, -4.2), 1.1, col_high)


## 겨울: 추수 후 논 렌더러 (정돈된 그루터기, 볏가리 볏짚단, 눈 덮인 논바닥)
static func _draw_winter_straw_stacks(
	ci: CanvasItem,
	c: Vector2,
	ip_n: Vector2, ip_e: Vector2, ip_s: Vector2, ip_w: Vector2,
	axis: int,
	is_advanced: bool,
	tint_shift: float
) -> void:
	var rows: Array[float] = [0.22, 0.44, 0.66, 0.88]
	var col_stubble: Color = Color(0.42 + tint_shift * 0.3, 0.34 + tint_shift * 0.2, 0.24)
	var col_straw_chaff: Color = Color(0.72, 0.62, 0.44)
	var col_snow: Color = Color(0.96, 0.98, 1.0, 0.85)

	# 1. 이랑을 따라 정돈된 벼 그루터기(밑동)
	for r_t: float in rows:
		var p_start: Vector2 = ip_n.lerp(ip_w, r_t) if axis == 0 else ip_w.lerp(ip_s, r_t)
		var p_end: Vector2 = ip_e.lerp(ip_s, r_t) if axis == 0 else ip_n.lerp(ip_e, r_t)

		ci.draw_line(p_start, p_end, col_stubble.darkened(0.2), 1.0)

		var count: int = 5
		for k: int in range(count):
			var ct: float = float(k + 1) / float(count + 1)
			var cp: Vector2 = p_start.lerp(p_end, ct)
			# 그루터기 도트 및 마른 볏짚
			ci.draw_line(cp, cp + Vector2(0.0, -1.8), col_stubble, 1.4)
			ci.draw_line(cp, cp + Vector2(0.8, -0.8), col_straw_chaff, 1.0)
			# 고랑 사이의 잔설 도트
			if k % 2 == 0:
				FastDraw.circle(ci, cp + Vector2(-1.5, 0.5), 1.0, col_snow)

	# 2. 조선 볏가리 (원추형 볏짚단 / 볏섬)
	_draw_single_straw_stack(ci, c + Vector2(-5.0, 0.5), 3.8, 8.0)
	_draw_single_straw_stack(ci, c + Vector2(6.0, -2.5), 3.2, 7.0)
	if is_advanced:
		_draw_single_straw_stack(ci, c + Vector2(1.0, 4.0), 3.4, 7.5)


## 단일 볏가리(볏짚단) 렌더러
static func _draw_single_straw_stack(ci: CanvasItem, base: Vector2, radius: float, height: float) -> void:
	# 바닥 그림자 타원
	FastDraw.circle(ci, base + Vector2(1.0, 1.0), radius * 0.95, Color(0.0, 0.0, 0.0, 0.28))

	# 원추형 볏가리 몸체 폴리곤
	var pts := PackedVector2Array([
		base + Vector2(-radius, 0.0),
		base + Vector2(radius, 0.0),
		base + Vector2(radius * 0.4, -height),
		base + Vector2(-radius * 0.4, -height)
	])
	ci.draw_colored_polygon(pts, Color("886e48"))

	# 볏짚 결 및 새끼줄 띠
	var band_y1: float = base.y - height * 0.35
	var band_y2: float = base.y - height * 0.65
	ci.draw_line(Vector2(base.x - radius * 0.8, band_y1), Vector2(base.x + radius * 0.8, band_y1), Color("4e3820"), 1.2)
	ci.draw_line(Vector2(base.x - radius * 0.6, band_y2), Vector2(base.x + radius * 0.6, band_y2), Color("4e3820"), 1.2)

	# 햇살 받는 볏짚 하이라이트
	ci.draw_line(base + Vector2(-radius * 0.5, -2.0), base + Vector2(-radius * 0.2, -height * 0.8), Color("ad9262"), 1.2)

	# 꼭대기에 소복하게 얹힌 새하얀 눈 모자
	var snow_pts := PackedVector2Array([
		base + Vector2(-radius * 0.55, -height + 0.5),
		base + Vector2(radius * 0.55, -height + 0.5),
		base + Vector2(0.0, -height - 2.5)
	])
	ci.draw_colored_polygon(snow_pts, Color("ffffff"))
	FastDraw.circle(ci, base + Vector2(0.0, -height - 1.2), 1.5, Color("ffffff"))


## 관개 수문/물꼬 렌더러 (대유둔전 석축 물꼬)
static func _draw_irrigation_gate(ci: CanvasItem, ip_s: Vector2, p_s: Vector2, _c: Vector2) -> void:
	var gp: Vector2 = ip_s.lerp(p_s, 0.5)
	# 나무 물꼬 말뚝 2개
	ci.draw_line(gp + Vector2(-2.5, 1.0), gp + Vector2(-2.5, -4.0), COL_WOOD_GATE, 1.6)
	ci.draw_line(gp + Vector2(2.5, 1.0), gp + Vector2(2.5, -4.0), COL_WOOD_GATE, 1.6)
	# 수문 판자
	ci.draw_line(gp + Vector2(-2.5, -2.5), gp + Vector2(2.5, -2.5), Color("5a3d24"), 2.0)
	# 맑은 유입 물길 도트
	FastDraw.circle(ci, gp + Vector2(0.0, -0.5), 1.2, COL_WATER_INFLOW)
