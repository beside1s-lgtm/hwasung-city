extends RefCounted
class_name RoadNetwork

## [조선 화성 도로망 판정 및 인접성 분석 엔진]
## 흙길(road) 및 박석길(stone_road)의 타일 판정, 인접 도로 4방향 O(1) 검사 및 연결성 보조 유틸리티

const ROAD_BUILDINGS: Array[String] = ["road", "stone_road"]
const ADJACENT_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, -1), # 북
	Vector2i(0, 1),  # 남
	Vector2i(-1, 0), # 서
	Vector2i(1, 0)   # 동
]

## 타일이 유효 도로 타일인지 여부 판정
static func is_road_tile(cell: Dictionary) -> bool:
	if cell.is_empty():
		return false
	var b: String = str(cell.get("building", ""))
	if b in ROAD_BUILDINGS:
		return true
	if cell.get("is_bridge", false):
		return true
	return false

## 해당 좌표 기준 상·하·좌·우 4방향 중 최소 1곳에 유효 도로가 인접해 있는지 O(1) 검사
static func has_adjacent_road(grid: Object, pos: Vector2i) -> bool:
	if grid == null or not grid.in_bounds(pos.x, pos.y):
		return false

	for d: Vector2i in ADJACENT_DIRECTIONS:
		var n: Vector2i = pos + d
		if grid.in_bounds(n.x, n.y):
			var cell: Dictionary = grid.grid[n.y][n.x]
			if is_road_tile(cell):
				return true
			if cell.get("is_bridge", false):
				return true
			if grid.is_patrol_road(n.x, n.y):
				return true
	return false

## 인접한 도로 타일 좌표 목록 반환
static func get_adjacent_roads(grid: Object, pos: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if grid == null or not grid.in_bounds(pos.x, pos.y):
		return out

	for d: Vector2i in ADJACENT_DIRECTIONS:
		var n: Vector2i = pos + d
		if grid.in_bounds(n.x, n.y):
			var cell: Dictionary = grid.grid[n.y][n.x]
			if is_road_tile(cell) or cell.get("is_bridge", false) or grid.is_patrol_road(n.x, n.y):
				out.append(n)
	return out
