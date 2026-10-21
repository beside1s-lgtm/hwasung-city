extends RefCounted
class_name WaterStructureManager

## 수원천 수문 및 교량(남수문, 화홍문, 매향교) 엔티티 판정 및 메타데이터 관리자
## 1. 하천 교차 성곽/도로 감지 시 특수 건물 ID 및 정식 명칭 자동 바인딩
## 2. 세이브/로드 시 기존 타일 자동 복구(Auto-Heal) 보장
## 3. 현판 하사 축하 트리거 및 월드 마커(GateSignboard) 연동 지원

@warning_ignore("unused_signal")
signal gate_signboard_bestowed(facility_id: String, fac_name: String, center_pos: Vector2i)

static var on_signboard_bestowed_callback: Callable = Callable()

const FACILITY_NAMSU: String = "namsu_mun"
const FACILITY_HWAHONG: String = "hwahong_mun"
const FACILITY_MAEHWANG: String = "maehwang_gyo"

const NAME_NAMSU: String = "남수문 (南水門)"
const NAME_HWAHONG: String = "화홍문 (華虹門)"
const NAME_MAEHWANG: String = "매향교 (梅香橋)"

## [만석거/축만제/저수지 수리시설 좌표 캐시]
static var reservoir_positions: Array[Vector2i] = []

const TYPE_SPECIAL: int = 7

## 저수지 위치 목록 동기화
static func sync_reservoir_positions(grid: Object) -> Array[Vector2i]:
	reservoir_positions.clear()
	if grid == null:
		return reservoir_positions
	for rp: Vector2i in grid.reservoir_positions:
		reservoir_positions.append(rp)
	return reservoir_positions

## 저수지 좌표 목록 반환
static func get_reservoir_positions() -> Array[Vector2i]:
	return reservoir_positions

## 특정 좌표가 저수지 유효 관개 반경 이내인지 검사
static func is_near_reservoir(pos: Vector2i, max_dist: int = 8) -> bool:
	if reservoir_positions.is_empty():
		return false
	for rp: Vector2i in reservoir_positions:
		if absi(pos.x - rp.x) + absi(pos.y - rp.y) <= max_dist:
			return true
	return false

## 특수 건물 메타데이터 명시적 주입 (Dictionary 메타데이터 지원)
static func bind_structure_metadata(tile: Dictionary, facility_id: String, fac_name: String) -> void:
	tile["facility_id"] = facility_id
	tile["special_building_id"] = facility_id
	tile["name"] = fac_name
	tile["is_special_building"] = true
	tile["building_type"] = TYPE_SPECIAL

## 특수 건물 메타데이터 제거
static func clear_structure_metadata(tile: Dictionary) -> void:
	tile.erase("facility_id")
	tile.erase("special_building_id")
	tile.erase("is_special_building")
	tile.erase("name")
	if tile.has("building_type") and int(tile.get("building_type", 0)) == TYPE_SPECIAL:
		tile.erase("building_type")

## 하천 타일 위 성벽 축조 훅 (on_wall_cross_river)
## 수원천 북쪽 상류는 화홍문(hwahong_mun), 남쪽 하류는 남수문(namsu_mun)으로 판정
static func on_wall_cross_river(grid: Object, x: int, y: int) -> Dictionary:
	if grid == null or not grid.in_bounds(x, y):
		return {}
	var t: Dictionary = grid.grid[y][x]
	if t.get("terrain", "") != "water" or t.get("building", "") != "wall":
		return {}

	var half_y: int = int(float(grid.size) / 2.0)
	var is_south: bool = y >= half_y
	var fac_id: String = FACILITY_NAMSU if is_south else FACILITY_HWAHONG
	var fac_name: String = NAME_NAMSU if is_south else NAME_HWAHONG

	t["is_bridge"] = true
	if is_south:
		t["is_namsu"] = true
	else:
		t["is_hwahong"] = true
	bind_structure_metadata(t, fac_id, fac_name)

	# 연속된 하천 성벽 구간 전체에 동기화
	var span: Array[Vector2i] = _find_water_wall_span(grid, x, y)
	for pt: Vector2i in span:
		var st: Dictionary = grid.grid[pt.y][pt.x]
		st["is_bridge"] = true
		if is_south:
			st["is_namsu"] = true
		else:
			st["is_hwahong"] = true
		bind_structure_metadata(st, fac_id, fac_name)

	# 중심 타일 계산
	var center_pos: Vector2i = span[int(float(span.size()) / 2.0)] if not span.is_empty() else Vector2i(x, y)

	# 현판 하사 시그널 발화 (GameGrid 및 글로벌 콜백)
	if grid.has_signal("water_gate_signboard_bestowed"):
		grid.emit_signal("water_gate_signboard_bestowed", fac_id, fac_name, center_pos)

	if on_signboard_bestowed_callback.is_valid():
		on_signboard_bestowed_callback.call(fac_id, fac_name, center_pos)

	# 국방 방호력 갱신 (BuildingManager)
	BuildingManager.on_building_completed(fac_id, grid, null)

	return {
		"facility_id": fac_id,
		"name": fac_name,
		"tiles": span,
		"center_pos": center_pos
	}

## 하천 타일 위 교량 가설 훅 (on_bridge_built)
## 화홍문과 남수문 사이 중심부 도로 가설 시 매향교(maehwang_gyo)로 판정
static func on_bridge_built(grid: Object, x: int, y: int) -> Dictionary:
	if grid == null or not grid.in_bounds(x, y):
		return {}
	var t: Dictionary = grid.grid[y][x]
	if t.get("terrain", "") != "water" or not (t.get("building", "") in ["road", "stone_road"]):
		return {}

	var span: Array[Vector2i] = _find_water_road_span(grid, x, y)
	var is_central: bool = y >= 14 and y <= 50
	if is_central or t.get("is_maehyang", false):
		for pt: Vector2i in span:
			var st: Dictionary = grid.grid[pt.y][pt.x]
			st["is_maehyang"] = true
			st["road_type"] = "stone"
			st["is_bridge"] = true
			bind_structure_metadata(st, FACILITY_MAEHWANG, NAME_MAEHWANG)

		var center_pos: Vector2i = span[int(float(span.size()) / 2.0)] if not span.is_empty() else Vector2i(x, y)
		if grid.has_signal("water_gate_signboard_bestowed"):
			grid.emit_signal("water_gate_signboard_bestowed", FACILITY_MAEHWANG, NAME_MAEHWANG, center_pos)
		if on_signboard_bestowed_callback.is_valid():
			on_signboard_bestowed_callback.call(FACILITY_MAEHWANG, NAME_MAEHWANG, center_pos)

		return {
			"facility_id": FACILITY_MAEHWANG,
			"name": NAME_MAEHWANG,
			"tiles": span,
			"center_pos": center_pos
		}
	return {}

## 세이브 파일 로드 또는 격자 변경 시 누락된 특수건물 메타데이터 자동 복구(Auto-Heal)
static func auto_heal_structures(grid: Object) -> void:
	if grid == null or grid.grid.is_empty():
		return
	var half_y: int = int(float(grid.size) / 2.0)
	for y: int in range(grid.size):
		for x: int in range(grid.size):
			var t: Dictionary = grid.grid[y][x]
			if t.get("terrain", "") != "water":
				continue
			var b: String = t.get("building", "")
			if b == "wall":
				t["is_bridge"] = true
				if t.get("is_namsu", false) or y >= half_y:
					t["is_namsu"] = true
					bind_structure_metadata(t, FACILITY_NAMSU, NAME_NAMSU)
				else:
					t["is_hwahong"] = true
					bind_structure_metadata(t, FACILITY_HWAHONG, NAME_HWAHONG)
			elif b in ["road", "stone_road"]:
				if t.get("is_maehyang", false) or (y >= 14 and y <= 50):
					t["is_maehyang"] = true
					t["road_type"] = "stone"
					t["is_bridge"] = true
					bind_structure_metadata(t, FACILITY_MAEHWANG, NAME_MAEHWANG)

## 물 위 연속 성벽 구간 탐색
static func _find_water_wall_span(grid: Object, cx: int, cy: int) -> Array[Vector2i]:
	var span: Array[Vector2i] = []
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [Vector2i(cx, cy)]
	visited[Vector2i(cx, cy)] = true

	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		span.append(curr)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = curr + d
			if grid.in_bounds(n.x, n.y) and not visited.has(n):
				var nt: Dictionary = grid.grid[n.y][n.x]
				if nt.get("terrain", "") == "water" and nt.get("building", "") == "wall":
					visited[n] = true
					queue.append(n)
	return span

## 물 위 연속 도로 구간 탐색
static func _find_water_road_span(grid: Object, cx: int, cy: int) -> Array[Vector2i]:
	var span: Array[Vector2i] = []
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [Vector2i(cx, cy)]
	visited[Vector2i(cx, cy)] = true

	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		span.append(curr)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = curr + d
			if grid.in_bounds(n.x, n.y) and not visited.has(n):
				var nt: Dictionary = grid.grid[n.y][n.x]
				if nt.get("terrain", "") == "water" and nt.get("building", "") in ["road", "stone_road"]:
					visited[n] = true
					queue.append(n)
	return span
