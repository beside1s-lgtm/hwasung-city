extends RefCounted
class_name WallLoopValidator

## [수원화성 사대문 폐곡선(Closed Loop) 연결 검증 시스템]
## 장안문(북), 팔달문(남), 화서문(서), 창룡문(동) 4대문이 모두 완공되어 있고,
## 성곽 타일들로 4대문을 순서대로 경유하는 완전한 닫힌 루프(Cycle)를 형성하는지 검증합니다.
## 하드코딩된 특정 좌표에 의존하지 않고, 사대문끼리 성곽으로 단절 없이 연결되어 있으면 폐곡선으로 판정합니다.
## 성능 최적화: Event-driven (성벽/성문 배치 및 철거 시에만 dirty 플래그 갱신 및 재계산)

const WALL_CONNECTORS: Array[String] = [
	"wall", "gate", "seojangdae", "seojangdae_site", "bongdon", "bongdon_site", "gongsimdon", 
	"gongsimdon_wall", "gongsimdon_site", "poru", "poru_site", "yeonmudae", "yeonmudae_range", 
	"banghwasuryu", "hwahong", "namsu", "chiseong", "ammun", "water_gate", "dongjangdae",
	"dongbuk_gongsimdon", "seobuk_gongsimdon", "dongam_mun", "seonam_ammun", "bukam_mun"
]

const DIRS8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
]

var _is_dirty: bool = true
var _cached_result: Dictionary = {
	"is_closed_loop": false,
	"raw_progress": 0,
	"validated_progress": 0,
	"visited_gates": [],
	"missing_gates": ["jangan", "paldal", "hwaseo", "changryong"],
	"tooltip_message": "사대문이 성곽으로 완전히 이어지지 않았습니다."
}

## 타일이 성곽 연결선으로 유효한지 검사
static func is_wall_connector_tile(tile: Dictionary) -> bool:
	if tile.is_empty():
		return false
	if tile.has("wall_build") or bool(tile.get("under_construction", false)):
		return false
	var b: String = str(tile.get("building", ""))
	if b in WALL_CONNECTORS:
		return true
	if bool(tile.get("is_namsu", false)) or bool(tile.get("is_hwahong", false)) or bool(tile.get("is_bridge", false)):
		return true
	var fac_id: String = str(tile.get("facility_id", ""))
	if fac_id != "":
		if fac_id in ["hwahong_mun", "namsu_mun", "jangan_mun", "paldal_mun", "hwaseo_mun", "changryong_mun"]:
			return true
		if fac_id.contains("wall") or fac_id.contains("gate") or fac_id.contains("poru") or fac_id.contains("gongsimdon") or fac_id.contains("bongdon"):
			return true
	return false

func invalidate() -> void:
	_is_dirty = true

func is_dirty() -> bool:
	return _is_dirty

## 폐곡선 검증 실행 (dirty일 때만 연산 수행)
func validate_loop(grid: GameGrid, force: bool = false) -> Dictionary:
	if not _is_dirty and not force:
		return _cached_result

	_is_dirty = false

	if grid == null or grid.grid.is_empty():
		_cached_result = {
			"is_closed_loop": false,
			"raw_progress": 0,
			"validated_progress": 0,
			"visited_gates": [],
			"missing_gates": ["jangan", "paldal", "hwaseo", "changryong"],
			"tooltip_message": "성곽 지형 정보가 없습니다."
		}
		return _cached_result

	# 1. 사대문 타일군 및 모든 성곽 연결 타일 수집
	var gate_tiles: Dictionary = {
		"jangan": [] as Array[Vector2i],
		"paldal": [] as Array[Vector2i],
		"hwaseo": [] as Array[Vector2i],
		"changryong": [] as Array[Vector2i]
	}
	var gate_positions: Dictionary = {} # gate_id -> 대표 좌표 Vector2i
	var all_wall_tiles: Dictionary = {} # Vector2i -> bool

	for y: int in range(grid.size):
		for x: int in range(grid.size):
			var tile: Dictionary = grid.grid[y][x]
			if not is_wall_connector_tile(tile):
				continue

			var pos := Vector2i(x, y)
			all_wall_tiles[pos] = true

			var b: String = str(tile.get("building", ""))
			var fac_id: String = str(tile.get("facility_id", ""))
			var is_gate: bool = (b == "gate" or fac_id.ends_with("_mun") or fac_id == "gate")

			if is_gate:
				var gate_id: String = ""
				var gname: String = str(tile.get("gate_name", ""))
				if gname.contains("화서") or gname.contains("hwaseo") or fac_id == "hwaseo_mun":
					gate_id = "hwaseo"
				elif gname.contains("장안") or gname.contains("jangan") or fac_id == "jangan_mun":
					gate_id = "jangan"
				elif gname.contains("팔달") or gname.contains("paldal") or fac_id == "paldal_mun":
					gate_id = "paldal"
				elif gname.contains("창룡") or gname.contains("changryong") or fac_id == "changryong_mun":
					gate_id = "changryong"
				elif absi(x - 6) <= 6 and absi(y - 13) <= 6:
					gate_id = "hwaseo" # 서문 고증 권역
				elif absi(x - 26) <= 6 and absi(y - 6) <= 6:
					gate_id = "jangan" # 북문 고증 권역
				elif absi(x - 16) <= 6 and absi(y - 54) <= 6:
					gate_id = "paldal" # 남문 고증 권역
				elif absi(x - 48) <= 6 and absi(y - 29) <= 6:
					gate_id = "changryong" # 동문 고증 권역
				elif x < 20 and absi(y - 13) < 12:
					gate_id = "hwaseo" # 서문 폴백
				elif y < 18:
					gate_id = "jangan" # 북문 폴백
				elif y > 42:
					gate_id = "paldal" # 남문 폴백
				else:
					gate_id = "changryong" # 동문 폴백

				if gate_tiles.has(gate_id):
					(gate_tiles[gate_id] as Array[Vector2i]).append(pos)
					if not gate_positions.has(gate_id):
						gate_positions[gate_id] = pos

	# 그리드 get_four_gates_positions()를 통한 사대문 좌표 보완
	if grid.has_method("get_four_gates_positions"):
		var fg_map: Dictionary = grid.get_four_gates_positions()
		for g_key: String in ["jangan", "hwaseo", "paldal", "changryong"]:
			if (gate_tiles[g_key] as Array[Vector2i]).is_empty():
				var gp: Vector2i = fg_map.get(g_key, Vector2i(-1, -1))
				if gp.x >= 0 and gp.y >= 0 and grid.in_bounds(gp.x, gp.y):
					var gt: Dictionary = grid.grid[gp.y][gp.x]
					if is_wall_connector_tile(gt):
						(gate_tiles[g_key] as Array[Vector2i]).append(gp)
						gate_positions[g_key] = gp
						all_wall_tiles[gp] = true

	# 누락된 성문 검사
	var required_gates: Array[String] = ["jangan", "hwaseo", "paldal", "changryong"]
	var missing: Array[String] = []
	for gname: String in required_gates:
		if (gate_tiles[gname] as Array[Vector2i]).is_empty():
			missing.append(gname)

	var tiles_ja: Array[Vector2i] = gate_tiles["jangan"]
	var tiles_hw: Array[Vector2i] = gate_tiles["hwaseo"]
	var tiles_pd: Array[Vector2i] = gate_tiles["paldal"]
	var tiles_cr: Array[Vector2i] = gate_tiles["changryong"]

	var has_ja: bool = not tiles_ja.is_empty()
	var has_hw: bool = not tiles_hw.is_empty()
	var has_pd: bool = not tiles_pd.is_empty()
	var has_cr: bool = not tiles_cr.is_empty()

	# 2. 4개 구간의 성벽 연속성 및 결손(gap) 검증
	# 구간 1: jangan <-> hwaseo (서북 성곽) - paldal, changryong 타일군 경유 금지
	# 구간 2: hwaseo <-> paldal (서남 성곽) - jangan, changryong 타일군 경유 금지
	# 구간 3: paldal <-> changryong (동남 성곽) - jangan, hwaseo 타일군 경유 금지
	var forb_nw: Dictionary = _combine_forbidden_with_margins([tiles_pd, tiles_cr], [tiles_ja, tiles_hw])
	var forb_sw: Dictionary = _combine_forbidden_with_margins([tiles_ja, tiles_cr], [tiles_hw, tiles_pd])
	var forb_se: Dictionary = _combine_forbidden_with_margins([tiles_ja, tiles_hw], [tiles_pd, tiles_cr])
	var forb_ne: Dictionary = _combine_forbidden_with_margins([tiles_hw, tiles_pd], [tiles_cr, tiles_ja])

	var res_nw: Dictionary = _calculate_gate_gap_and_walls(tiles_ja, tiles_hw, all_wall_tiles, forb_nw, grid) if (has_ja and has_hw) else {"gap": 9999, "has_wall": false, "wall_count": 0}
	var res_sw: Dictionary = _calculate_gate_gap_and_walls(tiles_hw, tiles_pd, all_wall_tiles, forb_sw, grid) if (has_hw and has_pd) else {"gap": 9999, "has_wall": false, "wall_count": 0}
	var res_se: Dictionary = _calculate_gate_gap_and_walls(tiles_pd, tiles_cr, all_wall_tiles, forb_se, grid) if (has_pd and has_cr) else {"gap": 9999, "has_wall": false, "wall_count": 0}
	var res_ne: Dictionary = _calculate_gate_gap_and_walls(tiles_cr, tiles_ja, all_wall_tiles, forb_ne, grid) if (has_cr and has_ja) else {"gap": 9999, "has_wall": false, "wall_count": 0}

	var ok_nw: bool = (int(res_nw["gap"]) == 0)
	var ok_sw: bool = (int(res_sw["gap"]) == 0)
	var ok_se: bool = (int(res_se["gap"]) == 0)
	var ok_ne: bool = (int(res_ne["gap"]) == 0)

	# 각 구간별 달성도 산출 (구간당 최대 25.0%, 한 칸 끊길 때마다 0.25% 부족)
	var score_nw: float = _calculate_segment_score(res_nw, has_ja and has_hw)
	var score_sw: float = _calculate_segment_score(res_sw, has_hw and has_pd)
	var score_se: float = _calculate_segment_score(res_se, has_pd and has_cr)
	var score_ne: float = _calculate_segment_score(res_ne, has_cr and has_ja)

	var total_float_progress: float = score_nw + score_sw + score_se + score_ne
	var is_loop_complete: bool = ok_nw and ok_sw and ok_se and ok_ne

	# 유연한 폐곡선 폴백 (4대문이 다른 순환 경로로 연결된 경우)
	if not is_loop_complete and missing.is_empty():
		var flexible_closed: bool = _verify_flexible_closed_loop(gate_tiles, all_wall_tiles)
		if flexible_closed:
			is_loop_complete = true
			total_float_progress = 100.0

	var final_int_progress: int = 0
	if is_loop_complete:
		final_int_progress = 100
	else:
		final_int_progress = mini(99, int(floorf(total_float_progress)))

	var broken_segments: Array[String] = []
	var gap_details: Array[String] = []
	if not ok_nw:
		broken_segments.append("서북성곽(장안문-화서문)")
		var g_nw: int = int(res_nw["gap"])
		if g_nw < 9999 and g_nw > 0: gap_details.append("서북 %d칸" % g_nw)
	if not ok_sw:
		broken_segments.append("서남성곽(화서문-팔달문)")
		var g_sw: int = int(res_sw["gap"])
		if g_sw < 9999 and g_sw > 0: gap_details.append("서남 %d칸" % g_sw)
	if not ok_se:
		broken_segments.append("동남성곽(팔달문-창룡문)")
		var g_se: int = int(res_se["gap"])
		if g_se < 9999 and g_se > 0: gap_details.append("동남 %d칸" % g_se)
	if not ok_ne:
		broken_segments.append("동북성곽(창룡문-장안문)")
		var g_ne: int = int(res_ne["gap"])
		if g_ne < 9999 and g_ne > 0: gap_details.append("동북 %d칸" % g_ne)

	var tip_msg: String = ""
	if is_loop_complete:
		tip_msg = "사대문이 성곽으로 완전히 연결되어 화성 성곽 폐곡선이 100% 완공되었습니다!"
	elif not missing.is_empty():
		var missing_korean: Array[String] = []
		for m: String in missing:
			match m:
				"jangan": missing_korean.append("장안문(북)")
				"paldal": missing_korean.append("팔달문(남)")
				"hwaseo": missing_korean.append("화서문(서)")
				"changryong": missing_korean.append("창룡문(동)")
		tip_msg = "화성 성곽 완공도 %d%% (미완성 성문: %s)" % [final_int_progress, ", ".join(missing_korean)]
	else:
		var gap_suffix: String = (", 결손: " + ", ".join(gap_details)) if not gap_details.is_empty() else ""
		tip_msg = "화성 성곽 완공도 %d%% (%s 구간 단절%s)" % [
			final_int_progress, 
			", ".join(broken_segments),
			gap_suffix
		]

	_cached_result = {
		"is_closed_loop": is_loop_complete,
		"raw_progress": final_int_progress,
		"validated_progress": final_int_progress,
		"float_progress": total_float_progress,
		"segment_scores": {
			"nw": score_nw,
			"sw": score_sw,
			"se": score_se,
			"ne": score_ne
		},
		"segment_gaps": {
			"nw": int(res_nw["gap"]),
			"sw": int(res_sw["gap"]),
			"se": int(res_se["gap"]),
			"ne": int(res_ne["gap"])
		},
		"visited_gates": gate_positions.keys(),
		"missing_gates": missing,
		"broken_segments": broken_segments,
		"tooltip_message": tip_msg
	}

	return _cached_result

## 구간별 축성 점수 산출 (구간당 최대 25.0%, 완전 연결 시 25.0%, 중간 단절 시 1칸당 0.25% 부족)
func _calculate_segment_score(path_res: Dictionary, gates_exist: bool) -> float:
	if not gates_exist:
		return 0.0

	var gap: int = int(path_res.get("gap", 9999))
	var has_wall: bool = bool(path_res.get("has_wall", false))
	var wall_cnt: int = int(path_res.get("wall_count", 0))

	# 완전히 연결된 경우
	if gap == 0:
		return 25.0

	# 성곽이 1칸도 놓이지 않은 경우 (두 문 사이 성벽 미건설)
	if not has_wall and wall_cnt == 0:
		return 0.0

	# 성곽이 놓여있으나 중간에 끊긴 경우: 1칸당 0.25%씩 부족
	return maxf(0.0, 25.0 - float(gap) * 0.25)

## 두 성문 타일군 사이의 최단 성벽 결손 칸 수(gap) 및 경로 상 성벽 존재 여부 계산 (2-버킷 0-1 BFS)
## 반환: Dictionary {"gap": int, "has_wall": bool, "wall_count": int}
func _calculate_gate_gap_and_walls(
	start_tiles: Array[Vector2i], 
	goal_tiles: Array[Vector2i], 
	wall_tiles: Dictionary, 
	forbidden_set: Dictionary, 
	grid: GameGrid
) -> Dictionary:
	if start_tiles.is_empty() or goal_tiles.is_empty() or grid == null:
		return {"gap": 9999, "has_wall": false, "wall_count": 0}

	var goal_set: Dictionary = {}
	for gp: Vector2i in goal_tiles:
		goal_set[gp] = true

	var start_set: Dictionary = {}
	for sp: Vector2i in start_tiles:
		start_set[sp] = true

	# 0-1 BFS: cost 0과 cost 1을 처리하기 위한 2개 버킷
	var dist: Dictionary = {} # Vector2i -> int
	var wall_count_map: Dictionary = {} # Vector2i -> int (경로 상 거친 순수 성벽 수)
	
	var bucket_curr: Array[Vector2i] = []
	var bucket_next: Array[Vector2i] = []

	for sp: Vector2i in start_tiles:
		dist[sp] = 0
		wall_count_map[sp] = 0
		bucket_curr.append(sp)

	var min_gap: int = 9999
	var found_has_wall: bool = false
	var max_walls_on_path: int = 0
	var head: int = 0

	# 두 성문 타일군을 포함하는 권역 바운딩 박스 계산 (여유 마진: 8칸)
	var min_bx: int = 9999
	var max_bx: int = -9999
	var min_by: int = 9999
	var max_by: int = -9999
	for sp_b: Vector2i in start_tiles:
		min_bx = mini(min_bx, sp_b.x)
		max_bx = maxi(max_bx, sp_b.x)
		min_by = mini(min_by, sp_b.y)
		max_by = maxi(max_by, sp_b.y)
	for gp_b: Vector2i in goal_tiles:
		min_bx = mini(min_bx, gp_b.x)
		max_bx = maxi(max_bx, gp_b.x)
		min_by = mini(min_by, gp_b.y)
		max_by = maxi(max_by, gp_b.y)
	min_bx = maxi(0, min_bx - 8)
	max_bx = mini(grid.size - 1, max_bx + 8)
	min_by = maxi(0, min_by - 8)
	max_by = mini(grid.size - 1, max_by + 8)

	while head < bucket_curr.size() or not bucket_next.is_empty():
		if head >= bucket_curr.size():
			bucket_curr = bucket_next
			bucket_next = []
			head = 0

		var curr: Vector2i = bucket_curr[head]
		head += 1

		var d: int = int(dist[curr])
		var w_cnt: int = int(wall_count_map[curr])

		if goal_set.has(curr):
			min_gap = d
			found_has_wall = (w_cnt > 0)
			max_walls_on_path = w_cnt
			break

		for dir_vec: Vector2i in DIRS8:
			var nxt: Vector2i = curr + dir_vec
			if not grid.in_bounds(nxt.x, nxt.y):
				continue
			if nxt.x < min_bx or nxt.x > max_bx or nxt.y < min_by or nxt.y > max_by:
				continue
			if forbidden_set.has(nxt) and not goal_set.has(nxt):
				continue

			var is_wall: bool = wall_tiles.has(nxt)
			var cost: int = 0 if is_wall else 1
			var new_d: int = d + cost
			var is_pure_wall: bool = (is_wall and not start_set.has(nxt) and not goal_set.has(nxt))
			var new_w: int = w_cnt + (1 if is_pure_wall else 0)

			if not dist.has(nxt) or new_d < int(dist[nxt]):
				dist[nxt] = new_d
				wall_count_map[nxt] = new_w
				if cost == 0:
					bucket_curr.append(nxt) # cost 0은 현재 버킷 끝에 추가하여 우선 탐색
				else:
					bucket_next.append(nxt) # cost 1은 다음 레벨 버킷에 추가

	return {
		"gap": min_gap,
		"has_wall": found_has_wall,
		"wall_count": max_walls_on_path
	}

## 금지된 성문 타일군 및 주변 1칸(마진)을 병합 (단, 시작/목표 성문 타일은 제외)
func _combine_forbidden_with_margins(tile_arrays: Array, exclude_tile_arrays: Array) -> Dictionary:
	var exclude_set: Dictionary = {}
	for arr_e in exclude_tile_arrays:
		for pt_e in (arr_e as Array[Vector2i]):
			exclude_set[pt_e] = true

	var out: Dictionary = {}
	for arr in tile_arrays:
		for pt_val in (arr as Array[Vector2i]):
			var pt: Vector2i = pt_val
			out[pt] = true
			for dir_vec: Vector2i in DIRS8:
				var adj: Vector2i = pt + dir_vec
				if not exclude_set.has(adj):
					out[adj] = true
	return out

## 타일군 배열들을 하나의 Dictionary 집합으로 병합
func _combine_sets(tile_arrays: Array) -> Dictionary:
	var out: Dictionary = {}
	for arr in tile_arrays:
		for pt in arr:
			out[pt] = true
	return out

## 시작 성문 타일군에서 목표 성문 타일군까지 금지된 성문 타일군을 거치지 않고 성곽 타일만으로 도달 가능한지 BFS 탐색
func _is_path_connected_sets(start_tiles: Array[Vector2i], goal_tiles: Array[Vector2i], wall_tiles: Dictionary, forbidden_set: Dictionary) -> bool:
	if start_tiles.is_empty() or goal_tiles.is_empty():
		return false

	var goal_set: Dictionary = {}
	for gp: Vector2i in goal_tiles:
		goal_set[gp] = true

	var queue: Array[Vector2i] = []
	var visited: Dictionary = {}

	for sp: Vector2i in start_tiles:
		if goal_set.has(sp):
			return true
		visited[sp] = true
		queue.append(sp)

	var head: int = 0
	while head < queue.size():
		var curr: Vector2i = queue[head]
		head += 1

		if goal_set.has(curr):
			return true

		for d: Vector2i in DIRS8:
			var nxt: Vector2i = curr + d
			if not wall_tiles.has(nxt):
				continue
			if visited.has(nxt):
				continue
			# 목표 성문이 아닌 금지된 타일은 통과하지 않음
			if forbidden_set.has(nxt) and not goal_set.has(nxt):
				continue

			visited[nxt] = true
			queue.append(nxt)

	return false

## 사대문 간의 임의 형태 폐곡선(순환 루프) 성립 여부 검증
func _verify_flexible_closed_loop(gate_tiles: Dictionary, wall_tiles: Dictionary) -> bool:
	var gates: Array[String] = ["jangan", "hwaseo", "paldal", "changryong"]
	var adj: Dictionary = {
		"jangan": [] as Array[String],
		"hwaseo": [] as Array[String],
		"paldal": [] as Array[String],
		"changryong": [] as Array[String]
	}

	# 6개 성문 쌍 간의 직접 연결 여부 검사 (다른 2개 성문 경유 금지)
	for i in range(gates.size()):
		for j in range(i + 1, gates.size()):
			var g1: String = gates[i]
			var g2: String = gates[j]
			var forbidden: Dictionary = {}
			for k in range(gates.size()):
				if k != i and k != j:
					for pt in (gate_tiles[gates[k]] as Array[Vector2i]):
						forbidden[pt] = true

			var conn: bool = _is_path_connected_sets(gate_tiles[g1], gate_tiles[g2], wall_tiles, forbidden)
			if conn:
				(adj[g1] as Array[String]).append(g2)
				(adj[g2] as Array[String]).append(g1)

	# 모든 성문의 연결 차수가 최소 2 이상이어야 순환 루프(폐곡선) 성립 가능
	for g: String in gates:
		if (adj[g] as Array[String]).size() < 2:
			return false

	# 4개 성문을 모두 지나는 단순 순환(Cycle)이 존재하는지 확인
	return _find_cycle_4(adj, "jangan", "jangan", {}, 0)

func _find_cycle_4(adj: Dictionary, current: String, start: String, visited: Dictionary, depth: int) -> bool:
	if depth == 4:
		return current == start

	visited[current] = true
	var neighbors: Array = adj.get(current, [])
	for nxt in neighbors:
		var n_str: String = str(nxt)
		if n_str == start and depth == 3:
			return true
		if not visited.has(n_str):
			if _find_cycle_4(adj, n_str, start, visited.duplicate(), depth + 1):
				return true
	return false

## 성곽 폐곡선 중 미완성/단절 지점 탐색 (열린 끝단 및 실제 단절 타일 좌표 반환)
## 하드코딩된 성곽 위치는 일절 포함하지 않고, 실제 성벽이 끊기거나 공사 중인 위치만 반환합니다.
func find_unconnected_wall_points(grid: GameGrid) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if grid == null or grid.grid.is_empty():
		return result

	var all_wall_tiles: Dictionary = {}
	var seen: Dictionary = {}

	# 1. 건설 중(wall_build, under_construction)인 성곽/성문 타일 수집 (최우선 미완성 지점)
	for y: int in range(grid.size):
		for x: int in range(grid.size):
			var tile: Dictionary = grid.grid[y][x]
			var b: String = str(tile.get("building", ""))
			var is_wall_type: bool = (b in WALL_CONNECTORS or b.begins_with("wall") or b == "gate" or bool(tile.get("is_namsu", false)) or bool(tile.get("is_hwahong", false)))
			if is_wall_type and (tile.has("wall_build") or bool(tile.get("under_construction", false))):
				var p_build := Vector2i(x, y)
				if not seen.has(p_build):
					seen[p_build] = true
					result.append(p_build)

			# 완공된 연결 타일 등록
			if is_wall_connector_tile(tile):
				all_wall_tiles[Vector2i(x, y)] = true

	# 사대문 폐곡선 검증 실행
	var loop_state: Dictionary = validate_loop(grid, true)
	if loop_state.get("is_closed_loop", false):
		# 사대문이 성곽으로 완전히 연결되어 폐곡선이 100% 성립된 경우 미완성 지점 없음
		if result.is_empty():
			return []

	# 2. 기존 완공 성벽 중 이웃 성벽이 1개 이하인 '열린 끝단(단절부)' 수집
	# (단, 성문 타일 자체는 통로가 열려 있을 수 있으므로 제외하고 순수 성벽 끝단만 수집)
	for pos: Vector2i in all_wall_tiles.keys():
		var t_pos: Dictionary = grid.grid[pos.y][pos.x]
		var b_pos: String = str(t_pos.get("building", ""))
		# 순수 성벽(wall) 타일인 경우 끝단 검사
		if b_pos == "wall":
			var neighbor_count: int = 0
			for d: Vector2i in DIRS8:
				var nxt: Vector2i = pos + d
				if all_wall_tiles.has(nxt):
					neighbor_count += 1
			if neighbor_count < 2:
				if not seen.has(pos):
					seen[pos] = true
					result.append(pos)

	return result
