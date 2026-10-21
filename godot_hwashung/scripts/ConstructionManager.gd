extends RefCounted
class_name ConstructionManager

## [화성성역 건설 관리자 & 자율 완공(Self-Completion) 시뮬레이션 엔진]
## 1. 인부 NPC 도달 여부와 무관하게 시간 경과에 따라 진행도가 차오르는 자율 완공 타이머 (턴당 20%, 인부 지원 시 +15%)
## 2. 도로 인접성 우선순위 큐 (도심 중심에서 외곽으로 순차 확장)
## 3. 장기 미완공(Stalled Site) 감시견(Watchdog, 6턴 이상 경과 시 강제 완공)
## 4. 기존 세이브 파일 로드 시 정체 비계 타일 자동 복구(Auto-Heal) 및 순차 완공 훅

## 공사 중인 개별 사이트 레코드 구조
## { "pos": Vector2i, "build_progress": float, "age_ticks": int, "building": String, "zone": String, "dist_to_road": int }
static var active_construction_sites: Array[Dictionary] = []

## 공사 현장 등록 (이미 등록된 경우 중복 방지)
static func register_construction_site(pos: Vector2i, initial_progress: float = 0.0, age: int = 0) -> void:
	for site: Dictionary in active_construction_sites:
		if site.get("pos", Vector2i(-1, -1)) == pos:
			return
	active_construction_sites.append({
		"pos": pos,
		"build_progress": initial_progress,
		"age_ticks": age,
	})

## 등록 해제
static func unregister_construction_site(pos: Vector2i) -> void:
	var remaining: Array[Dictionary] = []
	for site: Dictionary in active_construction_sites:
		if site.get("pos", Vector2i(-1, -1)) != pos:
			remaining.append(site)
	active_construction_sites = remaining

## 주변에 일꾼/인부 또는 활동 중인 주민이 있는지 판정 (인부 지원 보너스 +15% 산출용)
static func _has_worker_support(pos: Vector2i, citizens: Node) -> bool:
	if citizens == null or not ("agents" in citizens):
		return false
	var agents_arr: Array = citizens.agents
	for ag: Dictionary in agents_arr:
		var apos: Vector2 = ag.get("pos", Vector2(-99, -99))
		if absf(apos.x - float(pos.x)) <= 3.0 and absf(apos.y - float(pos.y)) <= 3.0:
			var job: int = int(ag.get("job", -1))
			# 공사 인부(ARTISAN), 일꾼, 또는 보부상/일반 백성이 현장 주변을 왕래할 때 보너스 적용
			if job in [NPCBase.JobType.ARTISAN, NPCBase.JobType.COMMONER, NPCBase.JobType.BOBUSANG]:
				return true
	return false

## [핵심 엔진] 턴(Turn) 틱 기반 자율 완공 시뮬레이션
## 인부 물리적 도착과 무관하게 모든 공사 현장에 매 턴 자율 진행도를 누적하고, 6턴 이상 방치 시 즉시 완공
static func process_turn(grid: GameGrid, sim: SimulationCore = null, citizens: Node = null) -> Array[Vector2i]:
	if grid == null:
		return []

	# 1. 맵 전체에서 미등록된 공사 중 타일(zone_build, under_construction, wall_build) 동적 스캔 및 등록
	var current_map_sites: Dictionary = {}
	for y: int in range(grid.size):
		for x: int in range(grid.size):
			var cell: Dictionary = grid.grid[y][x]
			var is_staged: bool = cell.has("zone_build") or cell.get("under_construction", false) or cell.has("wall_build")
			if is_staged:
				var p := Vector2i(x, y)
				current_map_sites[p] = true
				var prog: float = float(cell.get("zone_build", 0.0)) * 100.0
				var existing: bool = false
				for s: Dictionary in active_construction_sites:
					if s.get("pos", Vector2i(-1, -1)) == p:
						existing = true
						break
				if not existing:
					register_construction_site(p, prog, 0)

	# 2. 맵에서 이미 완공되거나 철거된 사이트 정리
	var valid_sites: Array[Dictionary] = []
	for s2: Dictionary in active_construction_sites:
		var sp: Vector2i = s2.get("pos", Vector2i(-1, -1))
		if current_map_sites.has(sp):
			valid_sites.append(s2)
	active_construction_sites = valid_sites

	if active_construction_sites.is_empty():
		return []

	# 3. 도로 인접성 우선순위화: 도로와 바로 맞닿아 있는 타일부터 우선 처리 (도심에서 외곽으로 확장)
	for s3: Dictionary in active_construction_sites:
		var sp3: Vector2i = s3["pos"]
		var d_road: int = grid.distance_to_road(sp3.x, sp3.y) if grid.has_method("distance_to_road") else 99
		s3["dist_to_road"] = d_road

	active_construction_sites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("dist_to_road", 99)) < int(b.get("dist_to_road", 99))
	)

	# 4. 자율 진행도 누적 및 완공 검사
	var completed_tiles: Array[Vector2i] = []
	var remaining_sites: Array[Dictionary] = []

	for site: Dictionary in active_construction_sites:
		var pos: Vector2i = site["pos"]
		if not grid.in_bounds(pos.x, pos.y):
			continue
		var cell: Dictionary = grid.grid[pos.y][pos.x]

		# 턴당 기본 진행도 +20.0%, 인부/백성 지원 시 +15.0%
		var has_worker: bool = _has_worker_support(pos, citizens)
		var progress_gain: float = 20.0 + (15.0 if has_worker else 0.0)

		var cur_progress: float = float(site.get("build_progress", 0.0)) + progress_gain
		var cur_age: int = int(site.get("age_ticks", 0)) + 1
		site["build_progress"] = cur_progress
		site["age_ticks"] = cur_age

		# 타일 데이터의 zone_build 및 wall_build에도 진행도 동기화 반영
		if cell.has("zone_build"):
			cell["zone_build"] = clampf(cur_progress / 100.0, 0.0, 1.0)
		if cell.has("wall_build") and int(cell.get("wall_build", 1)) > 0:
			if cur_progress >= 50.0 and int(cell.get("wall_build", 1)) > 1:
				cell["wall_build"] = int(cell["wall_build"]) - 1

		# 완공 조건 검사: 진행도 100% 도달 또는 6개월(6턴) 이상 경과한 장기 미완공(Stalled Site) 강제 탈출
		if cur_progress >= 100.0 or cur_age >= 6:
			BuildingManager.complete_building(pos, grid, sim)
			completed_tiles.append(pos)
		else:
			remaining_sites.append(site)

	active_construction_sites = remaining_sites

	if not completed_tiles.is_empty():
		grid.notify_batch_changed(completed_tiles)
		grid.emit_signal("construction_progressed")

	return completed_tiles

## [세이브 호환성 복구]: 게임 로드 시 수년간 비계로 묶여 있는 건물터들을 즉시 감지하여 1~2턴 내 순차 완공
static func on_game_loaded(grid: GameGrid, sim: SimulationCore = null) -> void:
	if grid == null:
		return
	active_construction_sites.clear()

	var stalled_tiles: Array[Vector2i] = []
	for y: int in range(grid.size):
		for x: int in range(grid.size):
			var cell: Dictionary = grid.grid[y][x]
			var is_staged: bool = cell.has("zone_build") or cell.get("under_construction", false) or cell.has("wall_build")
			if is_staged:
				stalled_tiles.append(Vector2i(x, y))

	if stalled_tiles.is_empty():
		return

	# 도로 거리 사전 캐싱 (정렬 시 O(N log N)번의 중복 BFS 호출 방지)
	var dist_cache: Dictionary = {}
	if grid.has_method("distance_to_road"):
		for pt in stalled_tiles:
			dist_cache[pt] = grid.distance_to_road(pt.x, pt.y)

	# 도로와의 거리에 따라 O(1) 캐시 기반 정렬
	stalled_tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = int(dist_cache.get(a, 99))
		var db: int = int(dist_cache.get(b, 99))
		return da < db
	)

	# 10년 이상 장기 방치된 기존 세이브의 경우, 도로에 바로 맞닿은 상위 35%는 즉시 완공하고
	# 나머지는 age_ticks = 4~5(진행도 80%)를 부여하여 다음 1~2턴 내에 깨끗하게 순차 완공되도록 세팅
	var immediate_complete_count: int = maxi(1, int(float(stalled_tiles.size()) * 0.35))
	var completed_now: Array[Vector2i] = []

	for i: int in range(stalled_tiles.size()):
		var p: Vector2i = stalled_tiles[i]
		if i < immediate_complete_count:
			# skip_heavy_sync = true 로 개별 중복 전체 맵 스캔을 방지
			BuildingManager.complete_building(p, grid, sim, true)
			completed_now.append(p)
		else:
			# 다음 턴에 즉시 완공되도록 age_ticks 4, build_progress 75% 부여
			register_construction_site(p, 75.0, 4)
			grid.register_build_tile(p.x, p.y)

	# 루프 완료 후 단 1회 일괄 동기화 (O(N^2) 병목 제거)
	if not completed_now.is_empty():
		BuildingManager.sync_workshop_and_shop_counts(grid)
		if sim and sim.pop_manager:
			sim.pop_manager.sync_housing_lists_from_grid(grid)
			sim.pop_manager.update_housing_occupancy(grid)
		CityStats.recalculate_defense_and_attack(grid, sim)
		GameProgressManager.scan(grid, sim)
		if sim != null:
			sim.sync_mega_projects_with_grid(grid)
		grid.notify_batch_changed(completed_now)
		grid.emit_signal("construction_progressed")

	print("[건설 시스템 세이브 복구] 총 %d개의 정체 비계 타일 감지: %d개 즉시 완공, %d개 순차 완공 큐 등록 완료." % [stalled_tiles.size(), completed_now.size(), stalled_tiles.size() - completed_now.size()])
