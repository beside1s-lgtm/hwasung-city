extends Node2D
class_name PuzzleArt
## PORT-TRACE [역사 사전 퍼즐 그림]: 3대 퍼즐판의 "완성 배경화"를 코드로 한 번 그려(SubViewport) 한 장의 텍스처로 만든다.
## 외부 그림 파일은 쓰지 않는다. 판마다 한 장만 두고, 조각은 이 한 장에서 직소 모양으로 오려 보여 준다(조각마다 이미지를 쪼개지 않음).
## fortress = 수원 화성 성곽 전경(치성·포루·홍예문), banghwa = 용연에 비친 방화수류정(눈 내린 저녁), hwahong = 일곱 홍예에서 물이 쏟아지는 화홍문.

var scene_id: String = "fortress"
const W := 960.0
const H := 640.0

static var _cache: Dictionary = {}

## 판 그림 텍스처. 한 번 만들면 캐시한다(없으면 null — 호출한 쪽이 viewport로 렌더해 set_cached 한다).
static func cached(id: String) -> Texture2D:
	return _cache.get(id)

static func set_cached(id: String, tex: Texture2D) -> void:
	_cache[id] = tex

## 직접 준비한 사진·그림이 있으면 코드 그림 대신 그것을 판 그림으로 쓴다.
## 파일: res://assets/encyclopedia/board_<fortress|banghwa|hwahong>.(jpg|png|webp). 비율이 달라도 판(3:2)에 맞춰 펴 바른다(3:2 권장, 1920x1280 이상이면 선명).
static func external_texture(id: String) -> Texture2D:
	for ext: String in ["jpg", "jpeg", "png", "webp"]:
		var path := "res://assets/encyclopedia/board_%s.%s" % [id, ext]
		if ResourceLoader.exists(path):
			var src := load(path) as Texture2D
			return _fit_board(src) if src != null else null
	return null

## 완성 영상 파일(res://assets/encyclopedia/board_<판 그림 id>.ogv). Godot은 Theora(.ogv)만 재생한다. 없으면 빈 문자열.
static func video_path(id: String) -> String:
	var p := "res://assets/encyclopedia/board_%s.ogv" % id
	return p if ResourceLoader.exists(p) else ""

## 잘라 내지 않은 원본 사진(영상과 같은 화면 비율로 보여 주려고). 없으면 null.
static func original_texture(id: String) -> Texture2D:
	for ext: String in ["jpg", "jpeg", "png", "webp"]:
		var path := "res://assets/encyclopedia/board_%s.%s" % [id, ext]
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null

## 판은 3:2다. 비율이 다른 사진은 가운데(조금 왼쪽 치우침)를 3:2로 오려 쓰고, 작은 사진은 부드럽게 키워 조각이 덜 뭉개지게 한다.
static func _fit_board(src: Texture2D) -> Texture2D:
	var img: Image = src.get_image()
	if img == null or img.is_empty():
		return src
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var want := W / H
	var ratio := float(w) / float(h)
	if absf(ratio - want) > 0.02:
		if ratio > want:
			var cw := int(round(float(h) * want))
			img = img.get_region(Rect2i(int(round(float(w - cw) * 0.3)), 0, cw, h))
		else:
			var ch := int(round(float(w) / want))
			img = img.get_region(Rect2i(0, int(round(float(h - ch) * 0.5)), w, ch))
	if img.get_width() < 1440:
		img.resize(1440, 960, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)

func _draw() -> void:
	match scene_id:
		"fortress", "jangan":
			_scene_fortress()
		"banghwa":
			_scene_banghwa()
		"hwahong":
			_scene_hwahong()

# ---------------------------------------------------------------- 도우미
func _pt_circle(c: Vector2, rx: float, ry: float, n: int = 20) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(n):
		var a := TAU * float(i) / float(n)
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out

func _ell(c: Vector2, rx: float, ry: float, col: Color) -> void:
	draw_colored_polygon(_pt_circle(c, rx, ry), col)

func _poly(pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3:
		draw_colored_polygon(pts, col)

func _grad(r: Rect2, top: Color, bottom: Color) -> void:
	var pts := PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.position + r.size, r.position + Vector2(0, r.size.y)])
	var cols := PackedColorArray([top, top, bottom, bottom])
	draw_polygon(pts, cols)

func _cloud(c: Vector2, s: float, col: Color = Color(1, 1, 1, 0.95)) -> void:
	for o: Vector3 in [Vector3(-34, 6, 22), Vector3(-12, -8, 28), Vector3(16, -4, 30), Vector3(40, 6, 22), Vector3(4, 10, 34)]:
		_ell(c + Vector2(o.x, o.y) * s, o.z * s, o.z * 0.72 * s, col)

func _line(a: Vector2, b: Vector2, col: Color, w: float = 1.0) -> void:
	draw_line(a, b, col, w)

## 소나무: 굽은 붉은 줄기 + 층층 솔잎 구름(아래 진하고 위 밝게). snow면 솔잎 위에 눈.
func _pine(base: Vector2, s: float, lean: float, snow: bool = false) -> void:
	var bark := Color("7a4630")
	var k1 := base + Vector2(8.0 * lean, -50.0) * s
	var k2 := base + Vector2(-4.0 * lean, -100.0) * s
	var k3 := base + Vector2(14.0 * lean, -150.0) * s
	draw_line(base, k1, bark, 12.0 * s)
	draw_line(k1, k2, bark, 9.0 * s)
	draw_line(k2, k3, bark, 6.0 * s)
	draw_line(base + Vector2(2, 0), k1 + Vector2(2, 0), bark.lightened(0.3), 2.5 * s)
	var pads: Array = [[k2 + Vector2(-46.0 * lean, 8) * s, 44.0, 17.0], [k1 + Vector2(40.0 * lean, -8) * s, 40.0, 16.0], [k2 + Vector2(6.0 * lean, -12) * s, 46.0, 18.0], [k3 + Vector2(0, -6) * s, 56.0, 21.0]]
	draw_line(k2, k2 + Vector2(-46.0 * lean, 8) * s, bark, 5.0 * s)
	draw_line(k1, k1 + Vector2(40.0 * lean, -8) * s, bark, 4.0 * s)
	for pd: Array in pads:
		var q: Vector2 = pd[0]
		var rx: float = float(pd[1]) * s
		var ry: float = float(pd[2]) * s
		_ell(q + Vector2(0, 6 * s), rx, ry, Color("1d4a2c"))
		_ell(q + Vector2(2 * s, -2 * s), rx * 0.86, ry * 0.8, Color("2e6a3a"))
		_ell(q + Vector2(5 * s, -7 * s), rx * 0.5, ry * 0.5, Color("5a9a48"))
		if snow:
			_ell(q + Vector2(0, -9 * s), rx * 0.8, ry * 0.42, Color("f2f6f8"))

func _round_tree(base: Vector2, s: float, col: Color) -> void:
	draw_line(base, base + Vector2(0, -34) * s, Color("6b4a30"), 8.0 * s)
	_ell(base + Vector2(0, -52) * s, 30.0 * s, 26.0 * s, col.darkened(0.25))
	_ell(base + Vector2(-8, -58) * s, 24.0 * s, 20.0 * s, col)
	_ell(base + Vector2(-10, -64) * s, 12.0 * s, 9.0 * s, col.lightened(0.25))

func _bush(c: Vector2, s: float, col: Color) -> void:
	_ell(c + Vector2(0, 0), 26.0 * s, 15.0 * s, col.darkened(0.22))
	_ell(c + Vector2(-5, -4) * s, 20.0 * s, 12.0 * s, col)
	_ell(c + Vector2(-8, -7) * s, 9.0 * s, 5.0 * s, col.lightened(0.25))

## 성가퀴(여장): 위쪽이 톱니 모양인 낮은 벽
func _merlons(a: Vector2, b: Vector2, h: float, col: Color, w: float = 16.0, gap: float = 9.0) -> void:
	var line_len := a.distance_to(b)
	var d := (b - a) / maxf(line_len, 1.0)
	var n := int(line_len / (w + gap))
	for i in range(n):
		var p := a + d * (float(i) * (w + gap))
		var q := p + d * w
		_poly(PackedVector2Array([p, q, q - Vector2(0, h), p - Vector2(0, h)]), col)
		_poly(PackedVector2Array([p - Vector2(0, h), q - Vector2(0, h), q - Vector2(0, h + 3), p - Vector2(0, h + 3)]), col.darkened(0.25))
		var m := (p + q) * 0.5
		draw_line(m - Vector2(0, h * 0.7), m - Vector2(0, h * 0.25), Color(0.1, 0.1, 0.12), 2.0) # 총안

## 돌벽 면: 사각형 다리꼴(a0→a1 윗변, 아래로 h) 안에 돌 줄눈
func _stone_face(p0: Vector2, p1: Vector2, h: float, col: Color, rows: int = 4, mortar: Color = Color(0, 0, 0, 0.18), rand_seed: int = 0) -> void:
	var q0 := p0 + Vector2(0, h)
	var q1 := p1 + Vector2(0, h)
	_poly(PackedVector2Array([p0, p1, q1, q0]), col)
	for r in range(1, rows):
		var tt := float(r) / float(rows)
		draw_line(p0.lerp(q0, tt), p1.lerp(q1, tt), mortar, 1.2)
	var wall_len := p0.distance_to(p1)
	var cols := maxi(2, int(wall_len / 34.0))
	for r in range(rows):
		var t0 := float(r) / float(rows)
		var t1 := float(r + 1) / float(rows)
		for k in range(cols + 1):
			var f := (float(k) + (0.5 if (r + rand_seed) % 2 == 1 else 0.0)) / float(cols)
			if f <= 0.0 or f >= 1.0:
				continue
			var top := p0.lerp(p1, f).lerp(q0.lerp(q1, f), t0)
			var bot := p0.lerp(p1, f).lerp(q0.lerp(q1, f), t1)
			draw_line(top, bot, mortar, 1.0)

## 팔작지붕 한 채(정면에서 본 모습): 처마가 양끝에서 치솟은 곡선, 기왓골, 합각, 용마루
func _roof(cx: float, eave_y: float, half_w: float, rise: float, tile: Color, edge: Color, snow: bool = false) -> void:
	var up := 16.0
	var n := 14
	var top_l := Vector2(cx - half_w * 0.62, eave_y - rise)
	var top_r := Vector2(cx + half_w * 0.62, eave_y - rise)
	var eave := PackedVector2Array()
	for i in range(n + 1):
		var t := float(i) / float(n)
		var x := lerpf(cx - half_w, cx + half_w, t)
		var lift := up * pow(absf(t * 2.0 - 1.0), 3.0)
		eave.append(Vector2(x, eave_y - lift + 2.0 * sin(t * PI)))
	var body := PackedVector2Array()
	for p: Vector2 in eave:
		body.append(p)
	body.append(top_r)
	body.append(top_l)
	_poly(body, tile)
	# 기왓골
	for k in range(1, 18):
		var t2 := float(k) / 18.0
		var base_p: Vector2 = eave[int(t2 * n)]
		var top_p := top_l.lerp(top_r, t2)
		draw_line(base_p, base_p.lerp(top_p, 0.94), tile.darkened(0.22), 1.2)
	# 처마 끝 선과 단청 띠
	for i in range(n):
		draw_line(eave[i], eave[i + 1], edge, 3.0)
		draw_line(eave[i] + Vector2(0, 5), eave[i + 1] + Vector2(0, 5), Color("2e8a6a"), 3.0)
		draw_line(eave[i] + Vector2(0, 9), eave[i + 1] + Vector2(0, 9), Color("c0392b"), 2.0)
	# 용마루(흰 양성바름)
	_poly(PackedVector2Array([top_l + Vector2(-8, 0), top_r + Vector2(8, 0), top_r + Vector2(8, -6), top_l + Vector2(-8, -6)]), Color("ece9e2"))
	_ell(top_l + Vector2(-10, -4), 7.0, 6.0, Color("2a2f36"))
	_ell(top_r + Vector2(10, -4), 7.0, 6.0, Color("2a2f36"))
	if snow:
		var sn := PackedVector2Array([top_l + Vector2(-8, -6), top_r + Vector2(8, -6), top_r.lerp(eave[n - 3], 0.32), top_l.lerp(eave[3], 0.32)])
		_poly(sn, Color(0.96, 0.98, 1.0, 0.95))

## 기둥 줄 + 난간 + 창방 단청 띠(누각 한 층). x0~x1, 마루 y, 높이 h
func _pavilion_floor(x0: float, x1: float, floor_y: float, h: float, pillars: int, _snow: bool = false) -> void:
	var red := Color("b3362a")
	_poly(PackedVector2Array([Vector2(x0 - 6, floor_y), Vector2(x1 + 6, floor_y), Vector2(x1 + 6, floor_y + 7), Vector2(x0 - 6, floor_y + 7)]), Color("6e4a2c"))
	# 안쪽 어둠(트인 마루)
	_poly(PackedVector2Array([Vector2(x0, floor_y - h), Vector2(x1, floor_y - h), Vector2(x1, floor_y), Vector2(x0, floor_y)]), Color("3a2a22"))
	for i in range(pillars):
		var x := lerpf(x0, x1, float(i) / float(maxi(1, pillars - 1)))
		draw_line(Vector2(x, floor_y), Vector2(x, floor_y - h), red, 8.0)
		draw_line(Vector2(x - 2, floor_y), Vector2(x - 2, floor_y - h), red.lightened(0.25), 2.0)
		_ell(Vector2(x, floor_y), 6.0, 2.5, Color("d6d0c1"))
	# 계자난간
	draw_line(Vector2(x0, floor_y - 18), Vector2(x1, floor_y - 18), Color("5a1c14"), 4.0)
	draw_line(Vector2(x0, floor_y - 8), Vector2(x1, floor_y - 8), Color("8e3427"), 3.0)
	var nb := int((x1 - x0) / 12.0)
	for k in range(nb + 1):
		var xx := lerpf(x0, x1, float(k) / float(nb))
		draw_line(Vector2(xx, floor_y - 18), Vector2(xx, floor_y - 4), Color("8e3427"), 2.5)
	# 창방 단청 띠
	_poly(PackedVector2Array([Vector2(x0 - 4, floor_y - h), Vector2(x1 + 4, floor_y - h), Vector2(x1 + 4, floor_y - h - 12), Vector2(x0 - 4, floor_y - h - 12)]), Color("2e8a6a"))
	draw_line(Vector2(x0 - 4, floor_y - h - 1), Vector2(x1 + 4, floor_y - h - 1), Color("c0392b"), 2.0)
	var nd := int((x1 - x0) / 14.0)
	for k in range(1, nd):
		var xd := lerpf(x0, x1, float(k) / float(nd))
		_ell(Vector2(xd, floor_y - h - 6), 2.2, 2.2, Color("f4d03f") if k % 2 == 0 else Color("e05a3a"))

# ================================================================= 1. 수원 화성 성곽
func _scene_fortress() -> void:
	_grad(Rect2(0, 0, W, 330), Color("5eaee8"), Color("dff3ff"))
	# 햇살
	_ell(Vector2(790, 96), 120, 120, Color(1, 0.96, 0.7, 0.18))
	_ell(Vector2(790, 96), 74, 74, Color(1, 0.96, 0.7, 0.32))
	_ell(Vector2(790, 96), 44, 44, Color("fff3b0"))
	_cloud(Vector2(190, 92), 1.1)
	_cloud(Vector2(520, 60), 0.9, Color(1, 1, 1, 0.9))
	_cloud(Vector2(930, 190), 0.8)
	# 먼 산
	_poly(PackedVector2Array([Vector2(0, 330), Vector2(0, 250), Vector2(90, 205), Vector2(190, 250), Vector2(300, 190), Vector2(430, 262), Vector2(560, 214), Vector2(700, 270), Vector2(830, 222), Vector2(960, 268), Vector2(960, 330)]), Color("9bbfd8"))
	_poly(PackedVector2Array([Vector2(0, 340), Vector2(0, 288), Vector2(140, 262), Vector2(280, 300), Vector2(430, 276), Vector2(600, 306), Vector2(760, 282), Vector2(960, 312), Vector2(960, 340)]), Color("7fb08c"))
	# 둥근 언덕
	_poly(PackedVector2Array([Vector2(0, 640), Vector2(0, 360), Vector2(160, 330), Vector2(380, 350), Vector2(640, 322), Vector2(840, 340), Vector2(960, 330), Vector2(960, 640)]), Color("8fcf6a"))
	_poly(PackedVector2Array([Vector2(0, 640), Vector2(0, 470), Vector2(220, 440), Vector2(520, 470), Vector2(800, 430), Vector2(960, 450), Vector2(960, 640)]), Color("78c25a"))
	# 성벽: 왼쪽 아래에서 오른쪽 위로 이어지는 띠(윗선 곡선)
	var top: Array[Vector2] = []
	for i in range(0, 41):
		var t := float(i) / 40.0
		top.append(Vector2(-30.0 + t * 1020.0, 468.0 - 130.0 * t + 22.0 * sin(t * 4.2)))
	var wall_h := 86.0
	# 성벽 몸체(앞면)
	var body := PackedVector2Array()
	for p: Vector2 in top:
		body.append(p)
	for i in range(top.size() - 1, -1, -1):
		body.append(top[i] + Vector2(0, wall_h))
	_poly(body, Color("c2bbae"))
	# 돌 줄눈(가로 3줄 + 세로 어긋남)
	for r in range(1, 4):
		var poly_line := PackedVector2Array()
		for p2: Vector2 in top:
			poly_line.append(p2 + Vector2(0, wall_h * float(r) / 4.0))
		draw_polyline(poly_line, Color(0.3, 0.28, 0.25, 0.28), 1.4)
	for i in range(0, top.size() - 1):
		for r2 in range(4):
			var off := 0.5 if (i + r2) % 2 == 1 else 0.0
			var f := 0.5 + off
			var a := top[i].lerp(top[i + 1], fmod(f, 1.0)) + Vector2(0, wall_h * float(r2) / 4.0)
			draw_line(a, a + Vector2(0, wall_h / 4.0), Color(0.3, 0.28, 0.25, 0.25), 1.0)
	# 아랫단 그림자
	var shadow := PackedVector2Array()
	for p3: Vector2 in top:
		shadow.append(p3 + Vector2(0, wall_h))
	for i2 in range(top.size() - 1, -1, -1):
		shadow.append(top[i2] + Vector2(0, wall_h + 10))
	_poly(shadow, Color(0.2, 0.3, 0.15, 0.4))
	# 성가퀴
	for i3 in range(0, top.size() - 1):
		if i3 % 2 == 0:
			_merlons(top[i3] + Vector2(0, 2), top[i3 + 1] + Vector2(0, 2), 16.0, Color("a29b8e"), 20.0, 8.0)
	# 치성(튀어나온 네모 보루) 둘
	for tt: float in [0.24, 0.74]:
		var ci := int(tt * 40.0)
		var c: Vector2 = top[ci]
		var bw := 118.0
		var bh := 104.0
		_poly(PackedVector2Array([c + Vector2(-bw * 0.5, 8), c + Vector2(bw * 0.5, 4), c + Vector2(bw * 0.5, 4 + bh), c + Vector2(-bw * 0.5, 8 + bh)]), Color("b4ad9f"))
		_stone_face(c + Vector2(-bw * 0.5, 8), c + Vector2(bw * 0.5, 4), bh, Color("b4ad9f"), 4, Color(0.25, 0.22, 0.2, 0.3), 1)
		_poly(PackedVector2Array([c + Vector2(bw * 0.5, 4), c + Vector2(bw * 0.5 + 30, -6), c + Vector2(bw * 0.5 + 30, bh - 6), c + Vector2(bw * 0.5, 4 + bh)]), Color("8f897d"))
		_poly(PackedVector2Array([c + Vector2(-bw * 0.5, 8), c + Vector2(bw * 0.5, 4), c + Vector2(bw * 0.5 + 30, -6), c + Vector2(-bw * 0.5 + 30, -2)]), Color("d9d3c6"))
		_merlons(c + Vector2(-bw * 0.5 + 30, -2), c + Vector2(bw * 0.5 + 30, -6), 16.0, Color("a29b8e"), 20.0, 9.0)
	# 포루: 성벽 가운데 우뚝 솟은 누각
	var pc: Vector2 = top[int(0.5 * 40.0)]
	var tower_w := 190.0
	_poly(PackedVector2Array([pc + Vector2(-tower_w * 0.5, 6), pc + Vector2(tower_w * 0.5, 0), pc + Vector2(tower_w * 0.5, 100), pc + Vector2(-tower_w * 0.5, 106)]), Color("b9b2a4"))
	_stone_face(pc + Vector2(-tower_w * 0.5, 6), pc + Vector2(tower_w * 0.5, 0), 100.0, Color("b9b2a4"), 4, Color(0.25, 0.22, 0.2, 0.3), 0)
	# 포루 총안(작은 네모 구멍)
	for k in range(5):
		var px := lerpf(pc.x - 66.0, pc.x + 66.0, float(k) / 4.0)
		_poly(PackedVector2Array([Vector2(px - 7, pc.y + 38), Vector2(px + 7, pc.y + 38), Vector2(px + 7, pc.y + 54), Vector2(px - 7, pc.y + 54)]), Color("2a2a30"))
	_pavilion_floor(pc.x - 74.0, pc.x + 74.0, pc.y + 2.0, 54.0, 5)
	_roof(pc.x, pc.y - 56.0, 118.0, 52.0, Color("55616a"), Color("2b3138"))
	# 깃발
	for fx: float in [pc.x - 128.0, pc.x + 128.0]:
		draw_line(Vector2(fx, pc.y + 4), Vector2(fx, pc.y - 80), Color("5c3a21"), 3.0)
		_poly(PackedVector2Array([Vector2(fx, pc.y - 80), Vector2(fx + 38, pc.y - 70), Vector2(fx, pc.y - 58)]), Color("d4362a") if fx < pc.x else Color("2f67c0"))
	# 홍예문(왼쪽): 성벽을 뚫은 아치 + 붉은 문
	var gc: Vector2 = top[int(0.1 * 40.0)] + Vector2(0, 94)
	_poly(PackedVector2Array([gc + Vector2(-34, 0), gc + Vector2(34, 0), gc + Vector2(34, -50), gc + Vector2(-34, -50)]), Color("3a3028"))
	_poly(_pt_circle(gc + Vector2(0, -50), 34, 28, 18), Color("3a3028"))
	draw_arc(gc + Vector2(0, -50), 38, PI, TAU, 18, Color("ddd7ca"), 6.0)
	for dx: float in [-17.0, 0.0, 17.0]:
		draw_line(gc + Vector2(dx, 0), gc + Vector2(dx, -50), Color("8a2a20"), 3.0)
	# 앞 풀밭과 길
	_poly(PackedVector2Array([Vector2(0, 640), Vector2(0, 560), Vector2(200, 540), Vector2(520, 575), Vector2(960, 545), Vector2(960, 640)]), Color("6bb84e"))
	_poly(PackedVector2Array([Vector2(300, 640), Vector2(420, 560), Vector2(520, 560), Vector2(470, 640)]), Color("e6d6a4"))
	# 나무와 꽃
	_pine(Vector2(120, 600), 1.15, 1.0)
	_pine(Vector2(870, 585), 1.0, -1.0)
	_round_tree(Vector2(70, 470), 0.9, Color("5aae52"))
	_round_tree(Vector2(930, 430), 0.9, Color("62b858"))
	_bush(Vector2(640, 585), 1.0, Color("4ea64a"))
	_bush(Vector2(260, 590), 0.9, Color("56ae50"))
	for i4 in range(24):
		var fxp := 40.0 + float((i4 * 137) % 880)
		var fyp := 580.0 + float((i4 * 53) % 50)
		_ell(Vector2(fxp, fyp), 3.0, 3.0, [Color("ffd23f"), Color("ff7aa8"), Color("ffffff")][i4 % 3])

# ================================================================= 2. 용연에 비친 방화수류정
func _draw_banghwa_main(snow_alpha: float = 1.0) -> void:
	# 언덕(눈 덮인 둔덕)
	_poly(PackedVector2Array([Vector2(130, 420), Vector2(230, 372), Vector2(330, 346), Vector2(480, 330), Vector2(640, 344), Vector2(760, 378), Vector2(860, 420)]), Color("d6c8a8"))
	_poly(PackedVector2Array([Vector2(200, 400), Vector2(290, 368), Vector2(400, 350), Vector2(520, 346), Vector2(640, 360), Vector2(740, 392), Vector2(700, 410), Vector2(560, 380), Vector2(420, 384), Vector2(280, 412)]), Color(0.97, 0.97, 0.96, snow_alpha))
	# 잔가지 관목(눈 쌓인 덤불)
	for b: Vector3 in [Vector3(260, 394, 1.0), Vector3(350, 372, 0.8), Vector3(610, 372, 0.9), Vector3(700, 394, 1.1), Vector3(520, 392, 0.7)]:
		_ell(Vector2(b.x, b.y), 30.0 * b.z, 14.0 * b.z, Color("9d8a78"))
		_ell(Vector2(b.x, b.y - 6.0 * b.z), 24.0 * b.z, 9.0 * b.z, Color(0.97, 0.97, 0.97, snow_alpha))
	# 성벽(누각 양옆으로 낮게 이어짐)
	_stone_face(Vector2(120, 352), Vector2(360, 330), 56.0, Color("a8895a"), 3, Color(0.2, 0.15, 0.1, 0.3), 1)
	_stone_face(Vector2(600, 330), Vector2(860, 352), 56.0, Color("a8895a"), 3, Color(0.2, 0.15, 0.1, 0.3), 0)
	_merlons(Vector2(120, 352), Vector2(360, 330), 12.0, Color("8a6f48"), 18.0, 9.0)
	_merlons(Vector2(600, 330), Vector2(860, 352), 12.0, Color("8a6f48"), 18.0, 9.0)
	# 누각을 받친 석축(각루 기단): 누런 화강암
	_poly(PackedVector2Array([Vector2(360, 286), Vector2(600, 286), Vector2(624, 392), Vector2(336, 392)]), Color("c9a96a"))
	_stone_face(Vector2(360, 286), Vector2(600, 286), 106.0, Color("c9a96a"), 5, Color(0.25, 0.18, 0.1, 0.35), 0)
	_poly(PackedVector2Array([Vector2(354, 280), Vector2(606, 280), Vector2(600, 292), Vector2(360, 292)]), Color("e0cb98"))
	# 누각: 마루 → 기둥 → 창방 → 큰 팔작지붕, 그 위에 직각으로 엇갈린 작은 지붕
	_pavilion_floor(396.0, 564.0, 282.0, 58.0, 7)
	_roof(480.0, 214.0, 196.0, 68.0, Color("3f6a66"), Color("1f3a38"), true)
	# 엇갈린 위쪽 합각 지붕(작게)
	_roof(430.0, 178.0, 96.0, 50.0, Color("3a625e"), Color("1f3a38"), true)
	# 절병통
	draw_line(Vector2(480, 150), Vector2(480, 122), Color("d4af37"), 4.0)
	_ell(Vector2(480, 118), 6.0, 7.0, Color("d4af37"))
	# 현판은 처마 아래 벽에 작게
	_poly(PackedVector2Array([Vector2(452, 232), Vector2(508, 232), Vector2(508, 248), Vector2(452, 248)]), Color("1a1410"))
	draw_rect(Rect2(452, 232, 56, 16), Color("d4af37"), false, 1.5)
	# 소나무(누각 왼쪽 뒤) 한 그루
	_pine(Vector2(300, 392), 0.5, -1.0, true)

func _scene_banghwa() -> void:
	# 저녁 하늘: 위는 푸르고 지평선으로 갈수록 주황
	_grad(Rect2(0, 0, W, 210), Color("5d86b6"), Color("f2b46c"))
	_grad(Rect2(0, 210, W, 150), Color("f2b46c"), Color("ffe2a8"))
	# 구름 띠
	for c: Vector3 in [Vector3(220, 90, 1.4), Vector3(700, 60, 1.2), Vector3(520, 140, 1.0)]:
		_cloud(Vector2(c.x, c.y), c.z, Color(1, 0.86, 0.78, 0.55))
	# 먼 산
	_poly(PackedVector2Array([Vector2(0, 370), Vector2(0, 330), Vector2(120, 312), Vector2(260, 332), Vector2(400, 300), Vector2(520, 330), Vector2(720, 304), Vector2(860, 328), Vector2(960, 316), Vector2(960, 370)]), Color(0.55, 0.5, 0.58, 0.8))
	# 못 바닥: 위쪽 둑 너머 하늘빛이 비치는 물
	_grad(Rect2(0, 396, W, 244), Color("e8b278"), Color("2d4a50"))
	# 반영: 누각을 아래로 뒤집어 흐리게
	draw_set_transform(Vector2(0, 2.0 * 392.0), 0.0, Vector2(1, -1))
	_draw_banghwa_main(0.75)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 반영을 물빛으로 덮어 흐림 + 가로 물결줄
	_grad(Rect2(0, 396, W, 244), Color(0.78, 0.55, 0.32, 0.45), Color(0.1, 0.22, 0.24, 0.78))
	for i in range(34):
		var yy := 400.0 + float(i) * 7.2
		var xx := float((i * 211) % 700)
		draw_line(Vector2(xx, yy), Vector2(xx + 120.0 + float((i * 37) % 120), yy), Color(1, 0.9, 0.7, 0.14), 2.0)
	# 위의 실제 풍경
	_draw_banghwa_main(1.0)
	# 앞쪽 물가: 왼쪽 눈 쌓인 둑(돌 호안) / 오른쪽 반도
	_poly(PackedVector2Array([Vector2(0, 470), Vector2(0, 396), Vector2(180, 392), Vector2(420, 412), Vector2(300, 428), Vector2(120, 446)]), Color(0.96, 0.97, 0.98))
	_poly(PackedVector2Array([Vector2(0, 470), Vector2(120, 446), Vector2(300, 428), Vector2(420, 412), Vector2(420, 420), Vector2(300, 438), Vector2(120, 458), Vector2(0, 482)]), Color("8a8478"))
	_poly(PackedVector2Array([Vector2(960, 470), Vector2(960, 420), Vector2(760, 428), Vector2(640, 450), Vector2(780, 476)]), Color(0.96, 0.97, 0.98))
	_poly(PackedVector2Array([Vector2(960, 480), Vector2(780, 482), Vector2(640, 458), Vector2(640, 450), Vector2(780, 476), Vector2(960, 470)]), Color("8a8478"))
	# 돌 호안의 돌 테두리 무늬
	for k in range(12):
		var xk := 640.0 + float(k) * 28.0
		draw_line(Vector2(xk, 456.0 + 0.5 * absf(float(k) - 4.0) * 2.0), Vector2(xk, 480), Color(0.2, 0.18, 0.16, 0.35), 1.2)
	# 오른쪽 소나무 두 그루(굽은 줄기)
	_pine(Vector2(820, 440), 1.5, -1.0, true)
	_pine(Vector2(900, 452), 1.15, 1.0, true)
	# 왼쪽 버드나무(잎 진 늘어진 가지)
	draw_line(Vector2(70, 430), Vector2(90, 300), Color("6b5440"), 9.0)
	for i2 in range(16):
		var bx := 40.0 + float(i2) * 10.0
		draw_line(Vector2(80.0 + float(i2 % 4) * 5.0, 300.0 + float(i2 % 3) * 10.0), Vector2(bx, 380.0 + float((i2 * 7) % 40)), Color(0.78, 0.7, 0.45, 0.8), 1.6)
	# 오리 몇 마리
	for d: Vector2 in [Vector2(690, 438), Vector2(712, 442)]:
		_ell(d, 9.0, 5.0, Color("6a5a40"))
		_ell(d + Vector2(7, -5), 4.0, 4.0, Color("2f6a4a"))
	# 눈송이
	for j in range(40):
		var sx := float((j * 97) % 960)
		var sy := float((j * 61) % 400)
		_ell(Vector2(sx, sy), 1.8, 1.8, Color(1, 1, 1, 0.8))

# ================================================================= 3. 화홍문 일곱 홍예
func _scene_hwahong() -> void:
	_grad(Rect2(0, 0, W, 360), Color("62b0ec"), Color("eaf7ff"))
	_cloud(Vector2(150, 90), 1.3)
	_cloud(Vector2(470, 50), 1.0)
	_cloud(Vector2(800, 120), 1.2)
	# 오른쪽 언덕과 멀리 보이는 방화수류정
	_poly(PackedVector2Array([Vector2(520, 400), Vector2(640, 300), Vector2(760, 232), Vector2(960, 190), Vector2(960, 470), Vector2(560, 470)]), Color("78bb54"))
	_poly(PackedVector2Array([Vector2(640, 420), Vector2(760, 330), Vector2(960, 270), Vector2(960, 470), Vector2(640, 470)]), Color("5aa543"))
	# 언덕 위 작은 누각
	_poly(PackedVector2Array([Vector2(760, 232), Vector2(900, 222), Vector2(906, 250), Vector2(756, 258)]), Color("b9b2a4"))
	_pavilion_floor(776.0, 886.0, 226.0, 34.0, 5)
	_roof(831.0, 190.0, 92.0, 34.0, Color("4a5560"), Color("2b3138"))
	# 계단(언덕 오르는 돌계단)
	for i in range(12):
		var sx := 560.0 + float(i) * 18.0
		var sy := 410.0 - float(i) * 13.0
		_poly(PackedVector2Array([Vector2(sx, sy), Vector2(sx + 22, sy - 8), Vector2(sx + 22, sy + 2), Vector2(sx, sy + 10)]), Color("d6d0c1"))
		draw_line(Vector2(sx, sy + 10), Vector2(sx + 22, sy + 2), Color(0.3, 0.28, 0.25, 0.4), 1.0)
	# 담쟁이로 덮인 오른쪽 성벽
	_stone_face(Vector2(600, 392), Vector2(960, 372), 108.0, Color("b6b1a4"), 4, Color(0.25, 0.22, 0.2, 0.28), 0)
	for k in range(30):
		var vx := 610.0 + float((k * 53) % 340)
		var vy := 400.0 + float((k * 29) % 80)
		_ell(Vector2(vx, vy), 26.0, 14.0, Color("3f8a3a") if k % 2 == 0 else Color("56a748"))
	# 화홍문 몸체: 긴 돌벽 + 일곱 홍예
	var wy := 336.0
	_stone_face(Vector2(24, wy), Vector2(630, wy), 150.0, Color("b9b4a7"), 5, Color(0.25, 0.22, 0.2, 0.3), 1)
	_poly(PackedVector2Array([Vector2(24, wy), Vector2(630, wy), Vector2(630, wy - 10), Vector2(24, wy - 10)]), Color("d9d4c6"))
	_merlons(Vector2(24, wy - 10), Vector2(630, wy - 10), 12.0, Color("a29c8f"), 20.0, 10.0)
	# 일곱 개의 무지개 문
	for i2 in range(7):
		var ax := 78.0 + float(i2) * 78.0
		_poly(PackedVector2Array([Vector2(ax - 30, wy + 150), Vector2(ax + 30, wy + 150), Vector2(ax + 30, wy + 104), Vector2(ax - 30, wy + 104)]), Color("1d3a4a"))
		_poly(_pt_circle(Vector2(ax, wy + 104), 30, 30, 18), Color("1d3a4a"))
		draw_arc(Vector2(ax, wy + 104), 34, PI, TAU, 18, Color("ddd7ca"), 6.0)
		# 안쪽으로 비치는 물빛
		_grad(Rect2(ax - 28, wy + 118, 56, 32), Color("2f6a86"), Color("8fd0ee"))
		for q in range(4):
			draw_line(Vector2(ax - 26 + q * 4, wy + 124 + q * 6), Vector2(ax + 22, wy + 126 + q * 6), Color(1, 1, 1, 0.5), 1.5)
	# 문루: 석축 위 두 칸 높이의 누각
	_pavilion_floor(98.0, 462.0, wy - 10.0, 66.0, 6)
	_roof(280.0, wy - 82.0, 236.0, 78.0, Color("60706a"), Color("2b3138"))
	# 현판 華虹門
	_poly(PackedVector2Array([Vector2(238, wy - 66), Vector2(322, wy - 66), Vector2(322, wy - 46), Vector2(238, wy - 46)]), Color("15110d"))
	draw_rect(Rect2(238, wy - 66, 84, 20), Color("d4af37"), false, 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(247, wy - 51), "華虹門", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f4e8c8"))
	# 성벽 위 깃발
	for fx: float in [520.0, 560.0, 600.0]:
		draw_line(Vector2(fx, wy - 10), Vector2(fx, wy - 54), Color("5c3a21"), 2.5)
		_poly(PackedVector2Array([Vector2(fx, wy - 54), Vector2(fx + 22, wy - 48), Vector2(fx, wy - 40)]), Color("d4362a"))
	# 물이 쏟아지는 계단식 폭포와 못
	_grad(Rect2(0, wy + 150, W, 640.0 - (wy + 150)), Color("5aa8d8"), Color("1d5d84"))
	for r in range(8):
		var yy := wy + 156.0 + float(r) * 26.0
		var xoff := float((r * 83) % 40)
		# 흰 물거품 줄
		for k2 in range(18):
			var x0 := -20.0 + xoff + float(k2) * 56.0
			var a := Vector2(x0, yy + sin(float(k2) + float(r)) * 4.0)
			draw_line(a, a + Vector2(44, 3), Color(1, 1, 1, 0.8 - float(r) * 0.07), 5.0 - float(r) * 0.3)
		draw_line(Vector2(0, yy + 14), Vector2(W, yy + 14), Color(0.2, 0.4, 0.55, 0.25), 2.0)
	# 낙수 줄기(홍예마다 하얀 폭포)
	for i3 in range(7):
		var fx2 := 78.0 + float(i3) * 78.0
		_poly(PackedVector2Array([Vector2(fx2 - 26, wy + 146), Vector2(fx2 + 26, wy + 146), Vector2(fx2 + 40, wy + 220), Vector2(fx2 - 40, wy + 220)]), Color(1, 1, 1, 0.65))
	# 앞쪽 풀과 돌
	_poly(PackedVector2Array([Vector2(0, 640), Vector2(0, 590), Vector2(120, 574), Vector2(260, 610), Vector2(280, 640)]), Color("4e9a3e"))
	_bush(Vector2(70, 596), 1.2, Color("3f8a3a"))
	_bush(Vector2(210, 620), 0.8, Color("52a244"))
	for s: Vector3 in [Vector3(420, 600, 1.0), Vector3(520, 618, 0.8), Vector3(700, 606, 1.2), Vector3(850, 620, 0.9)]:
		_ell(Vector2(s.x, s.y), 30.0 * s.z, 12.0 * s.z, Color("8a8478"))
		_ell(Vector2(s.x - 4, s.y - 4), 22.0 * s.z, 8.0 * s.z, Color("b0aa9c"))
	# 오른쪽 나무
	_round_tree(Vector2(930, 470), 1.0, Color("4fa44a"))
	_round_tree(Vector2(560, 380), 0.8, Color("5aae52"))
