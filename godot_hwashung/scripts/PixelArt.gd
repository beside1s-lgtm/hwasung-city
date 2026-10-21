extends RefCounted
class_name PixelArt

## 도트(픽셀) 그림 도구. 작은 Image 위에 점·사각형·타원·다각형·선을 찍고, 빛(왼쪽 위)에 따른
## 3단 명암(밝은 면·기본·그늘)과 바둑판 디더링, 바깥 윤곽선을 자동으로 넣는다.
## 에셋을 가져오지 않고 코드로 그려 ImageTexture로 굳혀 쓴다(NEAREST 필터로 키워 보여 줄 것).

var w: int
var h: int
var img: Image

func _init(width: int, height: int) -> void:
	w = width
	h = height
	img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

func texture() -> ImageTexture:
	return ImageTexture.create_from_image(img)

# ─────────────────────────────────────────── 기본 점·면
func px(x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	if c.a >= 0.999:
		img.set_pixel(x, y, c)
	elif c.a > 0.0:
		var o := img.get_pixel(x, y)
		img.set_pixel(x, y, Color(o.r + (c.r - o.r) * c.a, o.g + (c.g - o.g) * c.a, o.b + (c.b - o.b) * c.a, maxf(o.a, c.a)))

func get_px(x: int, y: int) -> Color:
	if x < 0 or y < 0 or x >= w or y >= h:
		return Color(0, 0, 0, 0)
	return img.get_pixel(x, y)

func rect(x: int, y: int, rw: int, rh: int, c: Color) -> void:
	for yy in range(y, y + rh):
		for xx in range(x, x + rw):
			px(xx, yy, c)

func line(x0: int, y0: int, x1: int, y1: int, c: Color, thick: int = 1) -> void:
	var dx := x1 - x0
	var dy := y1 - y0
	var n := maxi(absi(dx), absi(dy))
	if n == 0:
		rect(x0, y0, thick, thick, c)
		return
	for i in range(n + 1):
		var t := float(i) / float(n)
		var xx := int(roundf(float(x0) + float(dx) * t))
		var yy := int(roundf(float(y0) + float(dy) * t))
		rect(xx - int(float(thick - 1) / 2.0), yy - int(float(thick - 1) / 2.0), thick, thick, c)

func circle_ring(cx: int, cy: int, r: int, c: Color) -> void:
	for k in range(16):
		var ang := TAU * float(k) / 16.0
		px(cx + int(roundf(cos(ang) * float(r))), cy + int(roundf(sin(ang) * float(r))), c)

func ell(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for yy in range(int(floor(cy - ry)), int(ceil(cy + ry)) + 1):
		for xx in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
			var dx := (float(xx) + 0.5 - cx) / rx
			var dy := (float(yy) + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				px(xx, yy, c)

# ─────────────────────────────────────────── 명암
static func shade(c: Color, k: float) -> Color:
	# k>0 밝게, k<0 어둡게(약간 차갑게 기울여 도트 느낌을 살린다)
	if k >= 0.0:
		return Color(minf(1.0, c.r + (1.0 - c.r) * k), minf(1.0, c.g + (1.0 - c.g) * k), minf(1.0, c.b + (1.0 - c.b) * k), c.a)
	var d := -k
	return Color(c.r * (1.0 - d), c.g * (1.0 - d * 0.95), c.b * (1.0 - d * 0.82), c.a)

const BAYER := [[0.0, 0.5], [0.75, 0.25]]

## 빛을 받는 공(타원) — 왼쪽 위가 밝고 오른쪽 아래가 어둡다. 경계에 디더링.
func ball(cx: float, cy: float, rx: float, ry: float, base: Color, lx: float = -0.55, ly: float = -0.65) -> void:
	for yy in range(int(floor(cy - ry)), int(ceil(cy + ry)) + 1):
		for xx in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
			var nx := (float(xx) + 0.5 - cx) / rx
			var ny := (float(yy) + 0.5 - cy) / ry
			var d2 := nx * nx + ny * ny
			if d2 > 1.0:
				continue
			var lit := (nx * lx + ny * ly) / 0.9 - d2 * 0.25
			var thr: float = BAYER[yy & 1][xx & 1] * 0.16
			var c := base
			if lit > 0.5 - thr:
				c = shade(base, 0.2)
			elif lit < -0.45 + thr:
				c = shade(base, -0.34)
			elif lit < -0.12 + thr:
				c = shade(base, -0.16)
			px(xx, yy, c)

## 피부처럼 매끈한 면: 디더링 없이 오른쪽 아래만 부드러운 그늘, 왼쪽 위에 작은 하이라이트
func soft_ball(cx: float, cy: float, rx: float, ry: float, base: Color) -> void:
	for yy in range(int(floor(cy - ry)), int(ceil(cy + ry)) + 1):
		for xx in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
			var nx := (float(xx) + 0.5 - cx) / rx
			var ny := (float(yy) + 0.5 - cy) / ry
			if nx * nx + ny * ny > 1.0:
				continue
			var s := nx * 0.62 + ny * 0.5
			var c := base
			if s > 0.78:
				c = shade(base, -0.2)
			elif s > 0.52:
				c = shade(base, -0.1)
			elif s < -0.62:
				c = shade(base, 0.08)
			px(xx, yy, c)

## 안이 채워진 다각형(스캔라인 판정)
func poly(pts: PackedVector2Array, c: Color) -> void:
	if pts.size() < 3:
		return
	var x0 := 1e9
	var y0 := 1e9
	var x1 := -1e9
	var y1 := -1e9
	for p in pts:
		x0 = minf(x0, p.x)
		y0 = minf(y0, p.y)
		x1 = maxf(x1, p.x)
		y1 = maxf(y1, p.y)
	for yy in range(int(floor(y0)), int(ceil(y1)) + 1):
		for xx in range(int(floor(x0)), int(ceil(x1)) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(float(xx) + 0.5, float(yy) + 0.5), pts):
				px(xx, yy, c)

## 빛이 드는 다각형: 왼쪽 위 밝은 면, 오른쪽 아래 그늘
func spoly(pts: PackedVector2Array, base: Color, hi: float = 0.16, lo: float = -0.3) -> void:
	if pts.size() < 3:
		return
	var x0 := 1e9
	var y0 := 1e9
	var x1 := -1e9
	var y1 := -1e9
	for p in pts:
		x0 = minf(x0, p.x)
		y0 = minf(y0, p.y)
		x1 = maxf(x1, p.x)
		y1 = maxf(y1, p.y)
	var bw := maxf(1.0, x1 - x0)
	var bh := maxf(1.0, y1 - y0)
	for yy in range(int(floor(y0)), int(ceil(y1)) + 1):
		for xx in range(int(floor(x0)), int(ceil(x1)) + 1):
			if not Geometry2D.is_point_in_polygon(Vector2(float(xx) + 0.5, float(yy) + 0.5), pts):
				continue
			var t := ((float(xx) - x0) / bw) * 0.62 + ((float(yy) - y0) / bh) * 0.38
			var thr: float = BAYER[yy & 1][xx & 1] * 0.1
			var c := base
			if t < 0.22 + thr:
				c = shade(base, hi)
			elif t > 0.78 - thr:
				c = shade(base, lo)
			elif t > 0.58 - thr:
				c = shade(base, lo * 0.5)
			px(xx, yy, c)

## 사각형 면에 세로 방향 명암(옷·기둥용)
func srect(x: int, y: int, rw: int, rh: int, base: Color) -> void:
	for yy in range(y, y + rh):
		for xx in range(x, x + rw):
			var t := float(xx - x) / maxf(1.0, float(rw - 1))
			var c := base
			if t < 0.2:
				c = shade(base, 0.14)
			elif t > 0.82:
				c = shade(base, -0.3)
			elif t > 0.64:
				c = shade(base, -0.14)
			px(xx, yy, c)

# ─────────────────────────────────────────── 윤곽·합성
## 불투명 픽셀 바깥 한 칸에 윤곽선을 두른다(안쪽 경계는 건드리지 않는다)
func outline(c: Color) -> void:
	var src := img.duplicate() as Image
	for yy in range(h):
		for xx in range(w):
			if src.get_pixel(xx, yy).a > 0.05:
				continue
			var near := false
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var qx: int = xx + o.x
				var qy: int = yy + o.y
				if qx >= 0 and qy >= 0 and qx < w and qy < h and src.get_pixel(qx, qy).a > 0.5:
					near = true
					break
			if near:
				img.set_pixel(xx, yy, c)

## 윤곽을 각 색의 어두운 톤으로(안쪽 경계 포함) — 색이 있는 윤곽이라 도트가 부드러워 보인다
func inner_edge(_c: Color, amount: float = 0.28) -> void:
	var src := img.duplicate() as Image
	for yy in range(h):
		for xx in range(w):
			var me := src.get_pixel(xx, yy)
			if me.a < 0.5:
				continue
			for o in [Vector2i(1, 0), Vector2i(0, 1)]:
				var q := Vector2i(xx + o.x, yy + o.y)
				if q.x >= w or q.y >= h:
					continue
				var nb := src.get_pixel(q.x, q.y)
				if nb.a < 0.5:
					continue
				# 서로 많이 다른 색 사이의 경계를 살짝 어둡게
				var diff := absf(me.r - nb.r) + absf(me.g - nb.g) + absf(me.b - nb.b)
				if diff > 0.45:
					img.set_pixel(q.x, q.y, shade(nb, -amount))

## 다른 그림을 이 그림 위에 겹친다(알파 합성)
func blit(o: PixelArt, ox: int = 0, oy: int = 0) -> void:
	for yy in range(o.h):
		for xx in range(o.w):
			var c := o.img.get_pixel(xx, yy)
			if c.a > 0.0:
				px(xx + ox, yy + oy, c)

## 둥근 한지 바탕: 중심이 밝은 방사 그라데이션 + 이중 테두리
func medallion(inner: Color, outer: Color, edge: Color, ring: Color) -> void:
	var cx := float(w) * 0.5
	var cy := float(h) * 0.5
	var r := float(mini(w, h)) * 0.5 - 1.0
	for yy in range(h):
		for xx in range(w):
			var dx := float(xx) + 0.5 - cx
			var dy := float(yy) + 0.5 - cy
			var d := sqrt(dx * dx + dy * dy)
			if d > r:
				continue
			var t := clampf(d / r, 0.0, 1.0)
			var thr: float = BAYER[yy & 1][xx & 1] * 0.12
			var c := inner.lerp(outer, clampf(t * t + thr - 0.06, 0.0, 1.0))
			if d > r - 1.0:
				c = edge
			elif d > r - 3.0 and d <= r - 2.0:
				c = ring
			px(xx, yy, c)
