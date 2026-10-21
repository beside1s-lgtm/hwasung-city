extends RefCounted
class_name FastDraw

## PORT-TRACE [렉 해결: 묶음 그리기]: 사용자 제보 — "건물을 짓거나 계절이 바뀔 때 5초쯤 멈춘다".
## 실제 렌더러(OpenGL 호환)로 재 보니 지도 한 번 굽는 데 1.5~4.4초가 걸렸고, 화면 없는(headless) 측정에서는
## 0.1초였다 — 즉 GDScript가 아니라 렌더링 서버 쪽 비용. Godot 4 호환 렌더러는 draw_colored_polygon /
## draw_polygon / draw_circle / draw_polyline / draw_arc를 부를 때마다 "다각형 명령"을 만들고 그때마다
## 정점 버퍼(VBO)를 새로 할당한다. 지도에는 이런 도형이 수만 개라 굽기마다 버퍼 할당이 수만 번 일어났다.
## 반면 draw_primitive(점 1~4개)와 draw_line은 버퍼 할당 없이 한 덩어리로 묶여(batch) 그려진다.
## 여기 함수들은 같은 모양을 삼각형/사각형 primitive와 선분으로 쪼개 그린다(겉모습은 동일).

@warning_ignore("unused_private_class_variable")
static var _tri_cols := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
static var _no_uv := PackedVector2Array()

## 직사각형(draw_rect 대체 또는 지원). 4개 정점 primitive로 그린다.
static func rect(ci: CanvasItem, r: Rect2, col: Color, filled: bool = true, width: float = -1.0) -> void:
	if not filled:
		ci.draw_rect(r, col, false, width)
		return
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	poly(ci, pts, col)

## 채운 다각형(단색). 3~4점은 그대로, 그 이상은 삼각분할해 삼각형 primitive로.
static func poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	var n := pts.size()
	if n < 3:
		return
	if n <= 4:
		var cols := PackedColorArray()
		cols.resize(n)
		cols.fill(col)
		ci.draw_primitive(pts, cols, _no_uv)
		return
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		# 꼬인 다각형 등 삼각분할 실패 — 부채꼴로라도 그린다
		for i in range(1, n - 1):
			ci.draw_primitive(PackedVector2Array([pts[0], pts[i], pts[i + 1]]), PackedColorArray([col, col, col]), _no_uv)
		return
	var c3 := PackedColorArray([col, col, col])
	for i in range(0, idx.size(), 3):
		ci.draw_primitive(PackedVector2Array([pts[idx[i]], pts[idx[i + 1]], pts[idx[i + 2]]]), c3, _no_uv)

## 꼭짓점마다 색이 다른 다각형(draw_polygon 대체). 3~4점은 그대로, 그 이상은 부채꼴.
static func poly_colors(ci: CanvasItem, pts: PackedVector2Array, cols: PackedColorArray, _uvs: PackedVector2Array = PackedVector2Array(), _tex: Texture2D = null) -> void:
	var n := pts.size()
	if n < 3:
		return
	if cols.size() < n:
		var c0: Color = cols[0] if cols.size() > 0 else Color.WHITE
		poly(ci, pts, c0)
		return
	if n <= 4:
		ci.draw_primitive(pts, cols, _no_uv)
		return
	for i in range(1, n - 1):
		ci.draw_primitive(PackedVector2Array([pts[0], pts[i], pts[i + 1]]), PackedColorArray([cols[0], cols[i], cols[i + 1]]), _no_uv)

## 원(draw_circle 대체). 반지름에 따라 6~16각형 부채꼴. filled=false면 테두리 선.
static func circle(ci: CanvasItem, center: Vector2, radius: float, col: Color, filled: bool = true, width: float = -1.0, _aa: bool = false) -> void:
	if radius <= 0.0:
		return
	var seg := clampi(int(radius * 1.6) + 6, 6, 16)
	if not filled:
		arc(ci, center, radius, 0.0, TAU, seg, col, width)
		return
	var c3 := PackedColorArray([col, col, col])
	var prev := center + Vector2(radius, 0.0)
	for i in range(1, seg + 1):
		var ang := TAU * float(i) / float(seg)
		var cur := center + Vector2(cos(ang), sin(ang)) * radius
		ci.draw_primitive(PackedVector2Array([center, prev, cur]), c3, _no_uv)
		prev = cur

## 꺾은선(draw_polyline 대체) — 선분 묶음
static func polyline(ci: CanvasItem, pts: PackedVector2Array, col: Color, width: float = -1.0, _aa: bool = false) -> void:
	for i in range(pts.size() - 1):
		ci.draw_line(pts[i], pts[i + 1], col, width)

## 호(draw_arc 대체) — 선분 묶음
static func arc(ci: CanvasItem, center: Vector2, radius: float, start_angle: float, end_angle: float, point_count: int, col: Color, width: float = -1.0, _aa: bool = false) -> void:
	var n := maxi(point_count, 2)
	var prev := center + Vector2(cos(start_angle), sin(start_angle)) * radius
	for i in range(1, n):
		var ang := lerpf(start_angle, end_angle, float(i) / float(n - 1))
		var cur := center + Vector2(cos(ang), sin(ang)) * radius
		ci.draw_line(prev, cur, col, width)
		prev = cur
