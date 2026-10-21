extends Node
class_name OutsideSettlement

# PORT-TRACE P25: 사용자 요청 — "성문 밖의 길을 중심으로 상업지역이 자연발생하고 민가들도
# 생겨났던 것을 구현". 성 밖(城底) 백성은 플레이어가 구획을 지정하지 않아도 성문에서 이어지는
# 옛 간선로(GameGrid.outbound_roads, generate_map.py 참고)를 따라 스스로 저잣거리/민가가
# 들어선다. 세금 징수와 복지(구휼)는 별도 장부를 만들지 않고, res_1/com_1 등 기존 건물
# 타입으로 그대로 심어서 GameGrid.develop_and_harvest / SimulationCore의 기존 인구·세수·
# 구휼 로직을 그대로 타게 한다 — 즉 "성 밖의 백성도 백성으로 취급"이 코드 레벨에서 보장된다.
#
# [수정 고증]: 성 밖 민간가옥 도로 연결 필수화 & 대유둔전 수리시설(만석거·저수지) 인접 형성 고증 반영
# 1. 맹지 무작위 가옥 스폰 차단: 반드시 유효 도로와 최소 1면 이상 맞닿을 때만 생성 (has_adjacent_road)
# 2. 대유둔전 수리시설 연동: 만석거/저수지 완공 시 반경 8칸 이내에만 자연 개간 형성
# 3. 고립 가옥 자동 소멸: 도로 미연결 경고 3턴 지속 시 백성 이탈 철거

var grid: GameGrid
var sim: SimulationCore

## PORT-TRACE [경량화 감사]: PanelController가 `outside.settlements.size()`를 참조하는데
## 이 프로퍼티가 없어 패널을 열면 "Invalid get index 'settlements'" 오류가 났다. grow()가
## 새로 심을 때마다 좌표를 여기 기록해 실제 자연발생 가구/저자 수와 일치시켰다.
var settlements: Array[Vector2i] = []

func setup(g: GameGrid, s: SimulationCore) -> void:
	grid = g
	sim = s

## 도로 인접성 검사 프록시 (상하좌우 4방향 유효 도로 존재 여부)
func has_adjacent_road(pos: Vector2i) -> bool:
	return DistrictSpawner.has_adjacent_road(grid, pos)

## 성 밖 민간가옥 스폰 자격 검사 (도로 인접성 필수)
func can_spawn_outskirt_house(pos: Vector2i) -> bool:
	return DistrictSpawner.can_spawn_outskirt_house(grid, pos)

## 만석거/저수지 근접 여부 검사
func is_near_reservoir(pos: Vector2i, max_dist: int = 8) -> bool:
	return DistrictSpawner.is_near_reservoir(grid, pos, max_dist)

## 대유둔전 스폰 자격 검사 (수리시설 존재 및 반경 8칸 이내 필수)
func can_spawn_dunjeon(pos: Vector2i) -> bool:
	return DistrictSpawner.can_spawn_dunjeon(grid, pos, 8)

## 도로에 최소 1면 이상 맞닿은 빈 성 밖 평지만 후보로 삼는다.
func _candidate_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if grid == null:
		return out

	for y: int in range(grid.size):
		for x: int in range(grid.size):
			var pt := Vector2i(x, y)
			# 도로 인접성 필수 검증 (맹지 스폰 원천 차단)
			if DistrictSpawner.can_spawn_outskirt_house(grid, pt):
				out.append(pt)
	return out

## 계절(턴) 경계마다 1회 호출. 안쪽 도시 인구·민심이 높을수록 성 밖에도 더 활발히 정착한다.
## 관공시설(동헌/순라청/멸화군, GameGrid.has_security_coverage) 치안망이 없으면 정착이 자주 무산된다.
func grow() -> int:
	if grid == null or sim == null:
		return 0

	# 1. 도로 미연결 경고 3턴 이상 지속된 고립 가옥 자동 소멸 처리
	clean_isolated_houses()

	var candidates: Array[Vector2i] = _candidate_tiles()
	var pressure: int = clampi(int(float(sim.population) / 150.0) + int(float(sim.loyalty - 50) / 20.0), 0, 8)
	var planted: int = 0

	if not candidates.is_empty():
		candidates.shuffle()
		for pt: Vector2i in candidates:
			if planted >= pressure:
				break
			# 도로 인접성 재확인 (다른 건물이 앞서 지어졌을 경우 대비)
			if not DistrictSpawner.can_spawn_outskirt_house(grid, pt):
				continue
			var covered: bool = grid.has_security_coverage(pt.x, pt.y)
			if not covered and randf() < 0.5:
				continue # 치안 공백 지역은 절반 확률로 정착 실패(도적/화재 등)
			var kind: String = "com_1" if randf() < 0.35 else "res_1"
			grid.grid[pt.y][pt.x]["building"] = kind
			settlements.append(pt)
			planted += 1

	# 2. 대유둔전(경작지) 수리시설 연동 자동 개간 및 확장
	var dunjeon_planted: int = grow_dunjian()
	planted += dunjeon_planted

	if planted > 0:
		grid.recount_zone_counts()
		grid.emit_signal("grid_changed")
	return planted

## 고립 가옥 자연 철거 훅
func clean_isolated_houses() -> int:
	if grid == null:
		return 0
	return DistrictSpawner.clean_stalled_isolated_houses(grid, sim)

## 성 밖 외곽 지역 둔전(농지) 수리시설 연동 자동 구획 및 스폰
## [역사 고증]: 정조 대왕의 만석거·축만제 축조로 농업용수를 공급한 대유평(대유둔전) 일대 반경 8칸에만 형성
func grow_dunjian() -> int:
	if grid == null or sim == null:
		return 0

	# 1. 맵 상에 만석거/저수지 수리시설이 전혀 없으면 성 밖 둔전 자연 발생 100% 차단
	if grid.reservoir_positions.is_empty():
		grid.update_reservoir_positions()
	if grid.reservoir_positions.is_empty():
		return 0

	# 2. 경제 지표 및 경작 한도 검사 (가옥 1채당 최대 30칸)
	var farm_limit: int = DifficultyManager.get_farm_capacity_limit(grid.houses_count)
	if grid.farms_count >= farm_limit:
		return 0

	# 둔전 개간 수요 계산: 농업 수요, 인구수, 저수지 보유 현황
	var base_demand: int = clampi(int(float(sim.demand_agr) / 20.0) + int(float(sim.population) / 100.0), 0, 5)
	if grid.reservoir_count > 0:
		base_demand += 2 # 만석거/저수지 축조 시 개간 장려
	base_demand = mini(base_demand, farm_limit - grid.farms_count)

	if base_demand <= 0:
		return 0

	# 3. 수리시설 반경 8칸 이내 POI 풀 또는 유효 좌표에서만 후보군 추출
	var candidates: Array[Vector2i] = []
	if not grid.reservoir_poi_pool.is_empty():
		for pt: Vector2i in grid.reservoir_poi_pool:
			if DistrictSpawner.can_spawn_dunjeon(grid, pt, 8):
				candidates.append(pt)
	else:
		# POI 풀이 비었을 경우 전체 저수지 주변 스캔
		for rp: Vector2i in grid.reservoir_positions:
			for dy: int in range(-8, 9):
				for dx: int in range(-8, 9):
					if absi(dx) + absi(dy) <= 8:
						var pt := Vector2i(rp.x + dx, rp.y + dy)
						if grid.in_bounds(pt.x, pt.y) and DistrictSpawner.can_spawn_dunjeon(grid, pt, 8):
							if not candidates.has(pt):
								candidates.append(pt)

	if candidates.is_empty():
		return 0

	candidates.shuffle()
	var planted_farms: int = 0
	for pt: Vector2i in candidates:
		if planted_farms >= base_demand or grid.farms_count >= farm_limit:
			break
		var t: Dictionary = grid.grid[pt.y][pt.x]
		t["zone"] = "agr"
		t["building"] = "agr_1"
		t["surface"] = "field" # 조선 고유 흙밭/논밭
		planted_farms += 1
		grid.farms_count += 1

	if planted_farms > 0:
		grid.rebuild_canals()
		grid.recompute_infrastructure(bool(sim.retainers.get("jeong_yakyong", false)))

	return planted_farms

## 관공시설 미비 지역이 절반을 넘으면 민심 하락, 완전히 관리되면 소폭 상승.
func unrest_delta() -> int:
	var total: int = 0
	var uncovered: int = 0
	for row_val in grid.grid:
		var row: Array = row_val as Array
		for t_val in row:
			var t: Dictionary = t_val as Dictionary
			var b: String = str(t.get("building", ""))
			if t.get("terrain", "") == "outside" and (b.begins_with("res") or b.begins_with("com")):
				total += 1
				if not grid.has_security_coverage(int(t.get("x", 0)), int(t.get("y", 0))):
					uncovered += 1
	if total == 0:
		return 0
	if float(uncovered) > float(total) / 2.0:
		return -2
	elif uncovered == 0:
		return 1
	return 0

## HUD/패널 표시용 집계
func stats() -> Dictionary:
	var houses: int = 0
	var stalls: int = 0
	var covered: int = 0
	var pop: int = 0
	for row_val in grid.grid:
		var row: Array = row_val as Array
		for t_val in row:
			var t: Dictionary = t_val as Dictionary
			var b: String = str(t.get("building", ""))
			if t.get("terrain", "") != "outside":
				continue
			if b.begins_with("res"):
				houses += 1
				pop += 9 if b == "res_2" else 3
				if grid.has_security_coverage(int(t.get("x", 0)), int(t.get("y", 0))):
					covered += 1
			elif b.begins_with("com"):
				stalls += 1
				if grid.has_security_coverage(int(t.get("x", 0)), int(t.get("y", 0))):
					covered += 1
	var total: int = houses + stalls
	return {"houses": houses, "stalls": stalls, "population": pop, "covered": covered, "total": total}
