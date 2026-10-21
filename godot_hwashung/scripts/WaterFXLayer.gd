class_name WaterFXLayer
extends Node2D

const SpriteCacheManager = preload("res://scripts/autoload/SpriteCacheManager.gd")

## PORT-TRACE [물빛 찰랑임]: 사용자 요청 — "방화수류정·만석거·축만제는 물이 있는 건축물인데 정적이라 아쉽다. 물이 빛에 비쳐
## 찰랑거리는 느낌, 만석거에 떠 있는 배가 흔들거리게, 겨울엔 언 느낌(언 물엔 찰랑임 없이)".
## 지도는 깊이 조각 그림(z 10+2i)으로 한 번 구워 두므로, 움직이는 물빛은 여기서 따로 매 프레임 그린다.
## 못마다 자식 노드 하나를 두고, 그 못이 구워진 조각 바로 위(z+1)에 놓아 앞 조각(앞쪽 건물·나무)이 그대로 덮게 한다.
## - 만석거·축만제(호수 그림): 그림의 물빛 픽셀에서 반짝일 자리를 골라 짧은 가로 윤슬이 번갈아 빛나고,
##   그림에서 떼어 낸 나룻배(<이름>_boat.png, tools/lake_fx.py)를 물결 따라 까딱이며 그린다. 둘레엔 잔물결.
## - 용연(절차 그림): 연못 둘레 안쪽(섬 제외)에 같은 윤슬.
## - 겨울: 얼음판(<이름>_winter.png) — 윤슬·잔물결 없이 배는 얼음에 박힌 채 가만히.

const LAKES := ["manseokgeo", "chukmanje"]
const GLINTS_LAKE := 110
const GLINTS_POND := 26

var grid: GameGrid
var city: CityLayer
var chunk_z_of: Callable # Vector2i(타일) -> 그 타일이 구워진 조각 스프라이트의 z
var _sig := ""
var _check := 0.0
var _redraw := 0.0

func setup(g: GameGrid, c: CityLayer, z_of: Callable) -> void:
	grid = g
	city = c
	chunk_z_of = z_of
	z_as_relative = false
	# 짓기·헐기·불러오기 직후 바로 다시 살핀다(주기 검사만 기다리면 몇 초 동안 예전 못 자리에 그림)
	if not grid.grid_changed.is_connected(_soon):
		grid.grid_changed.connect(_soon)
	refresh()

func _soon(_a = null, _b = null, _c = null) -> void:
	_check = minf(_check, 0.2)

func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 3.0
		refresh()
	_redraw -= delta
	if _redraw <= 0.0:
		_redraw = 1.0 / 24.0
		for ch in get_children():
			(ch as CanvasItem).queue_redraw()

func _season() -> String:
	return String(city.current_season) if city != null else ""

## 못 목록이 바뀌었거나(짓기·헐기) 계절이 바뀌면 자식 노드를 다시 만든다
func refresh() -> void:
	if grid == null or city == null:
		return
	var found: Array = []
	for y in range(grid.size):
		for x in range(grid.size):
			var t: Dictionary = grid.grid[y][x]
			var b := String(t.get("building", ""))
			if b in LAKES:
				found.append([b, Vector2i(x, y)])
			elif b == "yongyeon" and Vector2i(x, y) == _pond_render_tile(t, x, y):
				found.append([b, Vector2i(x, y)])
	var sig := _season() + "|" + str(found)
	if sig == _sig:
		return
	_sig = sig
	for ch in get_children():
		ch.queue_free()
	for f: Array in found:
		var spot: Spot = null
		if String(f[0]) == "yongyeon":
			spot = _make_pond(f[1])
		else:
			spot = _make_lake(String(f[0]), f[1])
		if spot != null:
			add_child(spot)

func _pond_render_tile(t: Dictionary, x: int, y: int) -> Vector2i:
	var mx := Vector2i(-1, -1)
	var cnt := 0
	for pt in t.get("site_tiles", []):
		var q: Vector2i = pt
		if grid.in_bounds(q.x, q.y) and grid.grid[q.y][q.x].get("building", "") == "yongyeon":
			mx = Vector2i(maxi(mx.x, q.x), maxi(mx.y, q.y))
			cnt += 1
	return mx if cnt >= 9 else Vector2i(-2, -2)

static func _is_water(c: Color) -> bool:
	if c.a < 0.16:
		return false
	if c.s < 0.12 and c.v > 0.75:
		return true
	var deg := c.h * 360.0
	return deg >= 165.0 and deg <= 245.0 and c.s > 0.30 and c.b > c.r + 0.1

func _make_lake(key: String, anchor: Vector2i) -> Spot:
	var season := _season()
	var frozen := season == "겨울"
	var tex: Texture2D = SpriteCacheManager.get_seasonal_or_base_texture("buildings", key, SeasonColorFilter.get_current_season_suffix(season), Vector2i(448, 320))
	if tex == null:
		return null
	var ft: Vector2i = city._group_front_tile(anchor)
	var xf: Variant = city.fit_xf(key, tex, city.cell_center(float(ft.x - 5), float(ft.y + 1), 1.0), city.cell_center(float(ft.x + 1), float(ft.y - 5), 1.0), city.cell_center(float(ft.x + 1), float(ft.y + 1), 1.0))
	if xf == null:
		return null
	var s := Spot.new()
	s.xf = xf
	s.frozen = frozen
	s.tint = SeasonColorFilter.get_current_tile_tint(season)
	s.z_index = int(chunk_z_of.call(ft)) + 1
	s.z_as_relative = false
	var bp := "res://assets/sprites/buildings/%s_boat.png" % key
	if ResourceLoader.exists(bp):
		s.boat = load(bp) as Texture2D
		s.boat_pos = Vector2(209, 171) if key == "manseokgeo" else Vector2(259, 193) # tools/lake_fx.py BOATS
	if not frozen:
		var img := tex.get_image()
		if img != null and not img.is_empty():
			if img.is_compressed():
				img.decompress()
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(key + str(anchor))
			var w := img.get_width()
			var h := img.get_height()
			var tries := 0
			while s.glints.size() < GLINTS_LAKE and tries < 6000:
				tries += 1
				var px := rng.randi_range(4, w - 5)
				var py := rng.randi_range(4, h - 5)
				# 배 자리와 그 둘레는 비운다(배가 덮음)
				if s.boat != null and Rect2(s.boat_pos - Vector2(3, 3), s.boat.get_size() + Vector2(6, 6)).has_point(Vector2(px, py)):
					continue
				if _is_water(img.get_pixel(px, py)) and _is_water(img.get_pixel(px - 3, py)) and _is_water(img.get_pixel(px + 3, py)) and _is_water(img.get_pixel(px, py - 2)):
					s.glints.append(Vector2(px, py))
					s.phase.append(rng.randf() * TAU)
	return s

func _make_pond(mx: Vector2i) -> Spot:
	var season := _season()
	var s := Spot.new()
	s.frozen = season == "겨울"
	s.z_index = int(chunk_z_of.call(mx)) + 1
	s.z_as_relative = false
	if s.frozen:
		return s
	var t: Dictionary = grid.grid[mx.y][mx.x]
	var ce: Array = t.get("corner_elev", [1.0, 1.0, 1.0, 1.0])
	var p_n := city.cell_center(mx.x, mx.y, ce[0])
	var p_e := city.cell_center(mx.x + 1, mx.y, ce[1])
	var p_s := city.cell_center(mx.x + 1, mx.y + 1, ce[2])
	var p_w := city.cell_center(mx.x, mx.y + 1, ce[3])
	var c := (p_n + p_e + p_s + p_w) * 0.25
	var AX := p_e - p_n
	var AY := p_w - p_n
	var Cp := c - AX - AY # 3x3 가운데 칸(mx - (1,1))
	var isle := Cp + AX * 0.08 + AY * 0.06 # CityLayer._render_yongyeon의 섬 자리
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("yongyeon" + str(mx))
	var tries := 0
	while s.glints.size() < GLINTS_POND and tries < 800:
		tries += 1
		var th := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 1.0
		var u := Vector2(cos(th), sin(th)) * r
		if (u - Vector2(0.08, 0.06)).length() < 0.48:
			continue # 섬
		var sp := Cp + AX * u.x + AY * u.y + Vector2(0, 6.0) # 수면은 땅보다 6px 낮다
		if absf(sp.x - isle.x) < 18.0 and sp.y < isle.y + 2.0 and sp.y > isle.y - 40.0:
			continue # 섬 소나무에 가리는 자리
		s.glints.append(sp)
		s.phase.append(rng.randf() * TAU)
	s.glint_len = 2.5
	s.screen_space = true
	return s

## 못 하나의 움직이는 물빛
class Spot extends Node2D:
	var xf := Transform2D.IDENTITY
	var frozen := false
	var screen_space := false
	var tint := Color.WHITE
	var glints := PackedVector2Array()
	var phase := PackedFloat32Array()
	var glint_len := 3.0
	var boat: Texture2D = null
	var boat_pos := Vector2.ZERO

	func _draw() -> void:
		var t := float(Time.get_ticks_msec()) / 1000.0
		if not screen_space:
			draw_set_transform_matrix(xf)
		if not frozen:
			for i in range(glints.size()):
				var ph: float = phase[i]
				var a := sin(t * (1.1 + fmod(ph, 0.9)) + ph)
				if a < 0.45:
					continue
				var k := (a - 0.45) / 0.55
				var p: Vector2 = glints[i] + Vector2(sin(t * 0.6 + ph) * 1.5, 0)
				var ln := glint_len * (0.6 + 0.6 * k)
				draw_line(p - Vector2(ln, 0), p + Vector2(ln, 0), Color(1.0, 1.0, 0.94, 0.75 * k), 1.0)
				if k > 0.85:
					draw_line(p - Vector2(0, 1.0), p + Vector2(0, 1.0), Color(1, 1, 1, 0.6 * k), 1.0)
		if boat != null:
			var sz := boat.get_size()
			var pivot := Vector2(sz.x * 0.5, sz.y * 0.75)
			var off := Vector2.ZERO
			var roll := 0.0
			if not frozen:
				off = Vector2(sin(t * 0.23) * 2.5, sin(t * 1.7) * 0.9)
				roll = sin(t * 1.15 + 0.6) * 0.045
				# 뱃전 잔물결: 퍼지며 옅어지는 납작한 고리 둘
				var wc := boat_pos + pivot + off + Vector2(0, 2)
				for j in range(2):
					var f := fmod(t * 0.45 + float(j) * 0.5, 1.0)
					var rr := 12.0 + f * 12.0
					var pts := PackedVector2Array()
					for k2 in range(17):
						var th := TAU * float(k2) / 16.0
						pts.append(wc + Vector2(cos(th) * rr, sin(th) * rr * 0.42))
					draw_polyline(pts, Color(0.85, 0.95, 1.0, 0.45 * (1.0 - f)), 1.0)
			draw_set_transform_matrix(xf * Transform2D(roll, boat_pos + pivot + off) * Transform2D(0.0, -pivot))
			draw_texture(boat, Vector2.ZERO, tint)
		draw_set_transform_matrix(Transform2D.IDENTITY)
