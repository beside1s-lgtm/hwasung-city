extends Control
class_name PuzzleBoardView
## PORT-TRACE [직소 퍼즐판]: 한 판의 완성 그림(텍스처 1장)을 직소 조각 모양(돌기·홈)으로 오려 보여 주는 컨트롤.
## 조각마다 이미지를 따로 만들지 않고 draw_colored_polygon의 UV로 같은 텍스처의 해당 부분만 그린다(메모리 절약).
## 맞춘 조각은 원본 색, 아직 모르는 조각은 어둡게 가린 실루엣과 "?"로 보인다. 부모를 AspectRatioContainer(3:2)에 넣어 찌그러지지 않게 한다.

signal piece_clicked(piece_id: String)

const SIZE := Vector2(960.0, 640.0) # 판 좌표계(PuzzleData.BOARD_SIZE와 같다)
## 직소 돌기 한 쪽 모양(가로 t 0~1, 높이 h는 짧은 변 대비). 버섯 모양 돌기.
const KNOB: Array[Vector2] = [
	Vector2(0.0, 0.0), Vector2(0.34, 0.0), Vector2(0.40, 0.015), Vector2(0.455, 0.05), Vector2(0.47, 0.10),
	Vector2(0.44, 0.15), Vector2(0.40, 0.19), Vector2(0.43, 0.24), Vector2(0.50, 0.26), Vector2(0.57, 0.24),
	Vector2(0.60, 0.19), Vector2(0.56, 0.15), Vector2(0.53, 0.10), Vector2(0.545, 0.05), Vector2(0.60, 0.015),
	Vector2(0.66, 0.0), Vector2(1.0, 0.0),
]

var board_id: String = ""
var cols: int = 4
var rows: int = 3
var art: Texture2D = null
var pieces: Array = []
var glow: float = 0.0 # 완성 축하 때 테두리 광택(0~1)

var free_cells: Array = []        # 조각이 없는 장식 칸(판을 다 맞춰야 그림이 드러난다)
var _cell_piece: Array[int] = []  # 칸 index → 조각 index(-1이면 장식 칸)
var _piece_cell: Array[int] = []  # 조각 index → 칸 index
var _polys: Array[PackedVector2Array] = []
var _centers: Array[Vector2] = []
var _hover: int = -1
var _flash: Dictionary = {} # 조각 index → 남은 번쩍임 시간

func _ready() -> void:
	set_process(false)

func setup(p_board_id: String) -> void:
	board_id = p_board_id
	var b: Dictionary = PuzzleData.board(p_board_id)
	cols = int(b["cols"])
	rows = int(b["rows"])
	free_cells = b.get("free_cells", [])
	pieces = PuzzleData.pieces_of(p_board_id)
	custom_minimum_size = Vector2(480, 320)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	_build_polys()
	queue_redraw()

func set_art(tex: Texture2D) -> void:
	art = tex
	queue_redraw()

## 판 좌표(960x640)에서 조각 index의 경계 상자
func piece_rect(i: int) -> Rect2:
	var poly: PackedVector2Array = _polys[_piece_cell[i]]
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p: Vector2 in poly:
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
	return Rect2(mn, mx - mn)

func flash_piece(i: int) -> void:
	_flash[_piece_cell[i]] = 1.2
	set_process(true)

func _process(delta: float) -> void:
	var any := false
	for k in _flash.keys():
		_flash[k] = float(_flash[k]) - delta
		if float(_flash[k]) <= 0.0:
			_flash.erase(k)
		else:
			any = true
	queue_redraw()
	if not any and glow <= 0.0:
		set_process(false)

# ---------------------------------------------------------------- 조각 모양
func _tab_sign(kind: int, r: int, c: int) -> float:
	var h := (c * 7 + r * 13 + kind * 5 + board_id.length() * 3) * 2654435761
	return 1.0 if ((h >> 5) & 1) == 0 else -1.0

func _edge(p0: Vector2, p1: Vector2, normal: Vector2, sgn: float, unit: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var d := p1 - p0
	for i in range(KNOB.size() - 1): # 끝점은 다음 변의 첫 점과 겹치므로 뺀다
		var k: Vector2 = KNOB[i]
		out.append(p0 + d * k.x + normal * (sgn * k.y * unit))
	return out

func _build_polys() -> void:
	_polys.clear()
	_centers.clear()
	_cell_piece.clear()
	_piece_cell.clear()
	var np := 0
	for ci in range(cols * rows):
		if ci in free_cells:
			_cell_piece.append(-1)
		else:
			_cell_piece.append(np)
			_piece_cell.append(ci)
			np += 1
	var cw := SIZE.x / float(cols)
	var ch := SIZE.y / float(rows)
	var unit := minf(cw, ch)
	for r in range(rows):
		for c in range(cols):
			var x0 := float(c) * cw
			var x1 := x0 + cw
			var y0 := float(r) * ch
			var y1 := y0 + ch
			var s_top := _tab_sign(0, r, c) if r > 0 else 0.0
			var s_bot := _tab_sign(0, r + 1, c) if r + 1 < rows else 0.0
			var s_left := _tab_sign(1, r, c) if c > 0 else 0.0
			var s_right := _tab_sign(1, r, c + 1) if c + 1 < cols else 0.0
			var poly := PackedVector2Array()
			poly.append_array(_edge(Vector2(x0, y0), Vector2(x1, y0), Vector2(0, 1), s_top, unit))
			poly.append_array(_edge(Vector2(x1, y0), Vector2(x1, y1), Vector2(1, 0), s_right, unit))
			poly.append_array(_edge(Vector2(x1, y1), Vector2(x0, y1), Vector2(0, 1), s_bot, unit))
			poly.append_array(_edge(Vector2(x0, y1), Vector2(x0, y0), Vector2(1, 0), s_left, unit))
			_polys.append(poly)
			_centers.append(Vector2(x0 + cw * 0.5, y0 + ch * 0.5))

# ---------------------------------------------------------------- 그리기
func _scale() -> float:
	return minf(size.x / SIZE.x, size.y / SIZE.y)

func _origin() -> Vector2:
	var s := _scale()
	return (size - SIZE * s) * 0.5

func _draw() -> void:
	if size.x < 16.0 or size.y < 16.0:
		return
	var s := _scale()
	var o := _origin()
	# 판 뒤 받침(어두운 나무)
	draw_rect(Rect2(o - Vector2(6, 6), SIZE * s + Vector2(12, 12)), Color("2a1a10"))
	draw_rect(Rect2(o, SIZE * s), Color("14100c"))
	if _polys.is_empty():
		return
	var font := ThemeDB.fallback_font
	var board_done := GameProgressManager.is_board_complete(board_id)
	for i in range(_polys.size()):
		var pi: int = _cell_piece[i]
		var unlocked: bool = (pi >= 0 and pi < pieces.size() and GameProgressManager.is_unlocked(board_id, String(pieces[pi]["id"]))) or (pi < 0 and board_done)
		var poly := PackedVector2Array()
		var uvs := PackedVector2Array()
		for p: Vector2 in _polys[i]:
			poly.append(o + p * s)
			uvs.append(p / SIZE)
		var fl: float = float(_flash.get(i, 0.0))
		if unlocked:
			if art != null:
				draw_colored_polygon(poly, Color.WHITE, uvs, art)
			else:
				draw_colored_polygon(poly, Color("6a8a9a"))
			if fl > 0.0:
				draw_colored_polygon(poly, Color(1, 0.95, 0.6, 0.55 * minf(fl, 1.0)))
			var edge_col := Color(1.0, 0.86, 0.35, 0.9) if i != _hover else Color(1, 1, 1, 1)
			var closed := poly.duplicate()
			closed.append(poly[0])
			draw_polyline(closed, Color(0, 0, 0, 0.45), 3.0)
			draw_polyline(closed, edge_col, 1.6 + (1.8 * glow if glow > 0.0 else 0.0) + (1.2 if i == _hover else 0.0))
		else:
			# 아직 못 찾은 조각은 그림이 전혀 비치지 않는 불투명한 먹빛 판으로 가린다(완성 그림을 미리 보여 주지 않는다)
			draw_colored_polygon(poly, Color("17120f"))
			var closed2 := poly.duplicate()
			closed2.append(poly[0])
			draw_polyline(closed2, Color(0.55, 0.5, 0.42, 0.55 if i != _hover else 0.95), 1.4)
			var cpos: Vector2 = o + _centers[i] * s
			var fs := int(46.0 * s)
			var mark := "?" if pi >= 0 else "封"
			var mcol := Color(0.85, 0.8, 0.7, 0.85) if pi >= 0 else Color(0.9, 0.72, 0.28, 0.9)
			var tw := font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(font, cpos - Vector2(tw.x * 0.5, -float(fs) * 0.32), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, mcol)

## 화면 위치의 "칸" index(-1이면 없음). 조각 index는 _cell_piece로 바꾼다
func _piece_at(local: Vector2) -> int:
	var s := _scale()
	var q := (local - _origin()) / s
	for i in range(_polys.size() - 1, -1, -1):
		if Geometry2D.is_point_in_polygon(q, _polys[i]):
			return i
	return -1

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var h := _piece_at((ev as InputEventMouseMotion).position)
		if h != _hover:
			_hover = h
			var hp: int = _cell_piece[h] if h >= 0 else -1
			var can_click := hp >= 0 and hp < pieces.size() and GameProgressManager.is_unlocked(board_id, String(pieces[hp]["id"]))
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_click else Control.CURSOR_ARROW
			queue_redraw()
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var c := _piece_at((ev as InputEventMouseButton).position)
		var i: int = _cell_piece[c] if c >= 0 else -1
		if i >= 0 and i < pieces.size():
			emit_signal("piece_clicked", String(pieces[i]["id"]))

func _get_tooltip(at_position: Vector2) -> String:
	var c := _piece_at(at_position)
	var i: int = _cell_piece[c] if c >= 0 else -1
	if c >= 0 and i < 0:
		return "장식 조각 — 판을 모두 맞추면 그림이 드러납니다"
	if i < 0 or i >= pieces.size():
		return ""
	var pc: Dictionary = pieces[i]
	if GameProgressManager.is_unlocked(board_id, String(pc["id"])):
		return "%s (%s) — 눌러서 읽어 보세요" % [pc["name"], pc["hanja"]]
	return "미지의 조각 — %s" % pc["hint"]

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = -1
		queue_redraw()
	elif what == NOTIFICATION_RESIZED:
		queue_redraw()
