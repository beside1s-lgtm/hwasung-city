extends RefCounted
class_name DistrictSpawner

## [조선 후기 6대 신분·직업군 전용 거점 스폰 & 거점 결손 방어 시스템]
## 중인, 아전, 전문 장인, 보부상, 승군, 백정의 거점 검색 및 안전 스폰

## 안전한 활성 가옥 타일 필터링 (폐허화된 빈집 제외)
static func filter_active_houses(manager: Node, houses: Array[Vector2i]) -> Array[Vector2i]:
	if houses.is_empty():
		return []
	var grid_ref = manager.get("grid") if "grid" in manager else null
	if grid_ref == null or not ("grid" in grid_ref):
		return houses
	var active: Array[Vector2i] = []
	for p: Vector2i in houses:
		var cell: Dictionary = grid_ref.grid[p.y][p.x]
		if not BuildingManager.is_ruined(cell):
			active.append(p)
	return active if not active.is_empty() else houses

## 가옥 점유 및 폐허 상태 동기화 프록시
static func update_housing_occupancy(grid_ref, pop_mgr) -> Dictionary:
	return BuildingManager.update_housing_occupancy(grid_ref, pop_mgr)

## 안전한 스폰 위치 도출 (지정 거점 부재 시 대체 도로 또는 안전 좌표로 Fallback)
static func get_safe_spawn_pos(manager: Node, preferred_pos: Vector2i, fallback_cache: Array[Vector2i]) -> Vector2i:
	if preferred_pos.x >= 0 and preferred_pos.y >= 0:
		return preferred_pos
	var filtered_cache: Array[Vector2i] = filter_active_houses(manager, fallback_cache)
	if not filtered_cache.is_empty():
		return filtered_cache[randi() % filtered_cache.size()]
	var roads: Array[Vector2i] = manager.get("_roads_cache") if "get" in manager else []
	if not roads.is_empty():
		return roads[randi() % roads.size()]
	return Vector2i(16, 16)

## 1. 중인 (기술관/의원) 스폰: 행궁 인근 또는 개량 기와집(res_2) / 약방
static func spawn_jungin(manager: Node, preferred_pos: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var hg_gate: Vector2i = manager.get("_haenggung_gate") if "_haenggung_gate" in manager else Vector2i(-1, -1)
	var rich_houses: Array[Vector2i] = manager.get("_rich_house_cache") if "_rich_house_cache" in manager else []
	var res_cache: Array[Vector2i] = manager.get("_res_cache") if "_res_cache" in manager else []

	var spawn_pos: Vector2i = preferred_pos
	if spawn_pos.x < 0:
		if hg_gate.x >= 0:
			spawn_pos = hg_gate
		elif not rich_houses.is_empty():
			spawn_pos = rich_houses[randi() % rich_houses.size()]
		else:
			spawn_pos = get_safe_spawn_pos(manager, Vector2i(-1, -1), res_cache)

	var next_id: int = manager.get("_next_agent_id") if "_next_agent_id" in manager else 1
	if "_next_agent_id" in manager:
		manager._next_agent_id = next_id + 1

	var name_str: String = manager.generate_npc_name(NPCBase.JobType.JUNGIN) if manager.has_method("generate_npc_name") else "의원 유태석"
	var ag: Dictionary = NPCBase.acquire_agent(next_id, NPCBase.JobType.JUNGIN, spawn_pos, name_str)
	ag["home_tile"] = spawn_pos
	ag["bubble_text"] = "탕약을 정성껏 달이고 침을 놓아 백성을 구휼하오."
	ag["bubble_timer"] = 3.5

	# 행궁 및 기와집 왕복 웨이포인트 구성
	var wps: Array[Vector2i] = [spawn_pos]
	if hg_gate.x >= 0 and hg_gate != spawn_pos:
		wps.append(hg_gate)
	ag["waypoints"] = wps

	if "agents" in manager:
		manager.agents.append(ag)
	return ag

## 2. 관아 아전 (향리/이방) 스폰: 화성유수부 관아(gwana) 또는 행궁 인근 가옥
static func spawn_ajeoun(manager: Node, preferred_pos: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var gwana_cache: Array[Vector2i] = manager.get("_gwana_cache") if "_gwana_cache" in manager else []
	var hg_gate: Vector2i = manager.get("_haenggung_gate") if "_haenggung_gate" in manager else Vector2i(-1, -1)
	var com_cache: Array[Vector2i] = manager.get("_com_cache") if "_com_cache" in manager else []

	var spawn_pos: Vector2i = preferred_pos
	if spawn_pos.x < 0:
		if not gwana_cache.is_empty():
			spawn_pos = gwana_cache[0]
		elif hg_gate.x >= 0:
			spawn_pos = hg_gate
		else:
			spawn_pos = get_safe_spawn_pos(manager, Vector2i(-1, -1), com_cache)

	var next_id: int = manager.get("_next_agent_id") if "_next_agent_id" in manager else 1
	if "_next_agent_id" in manager:
		manager._next_agent_id = next_id + 1

	var name_str: String = manager.generate_npc_name(NPCBase.JobType.AJEOUN) if manager.has_method("generate_npc_name") else "이방 최진규"
	var ag: Dictionary = NPCBase.acquire_agent(next_id, NPCBase.JobType.AJEOUN, spawn_pos, name_str)
	ag["home_tile"] = spawn_pos
	ag["bubble_text"] = "호구 대장과 결세 장부를 꼼꼼히 점검하시오!"
	ag["bubble_timer"] = 3.5

	# 관아 -> 저잣거리/민가 순찰 웨이포인트
	var wps: Array[Vector2i] = [spawn_pos]
	if not com_cache.is_empty():
		wps.append(com_cache[randi() % com_cache.size()])
	ag["waypoints"] = wps

	if "agents" in manager:
		manager.agents.append(ag)
	return ag

## 3. 전문 장인 (도편수/석수) 스폰: 공방 부근 가옥/공방 채 (ind_1/ind_2/factory)
static func spawn_specific_artisan(manager: Node, preferred_pos: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var ws_cache: Array[Vector2i] = manager.get("_workshop_cache") if "_workshop_cache" in manager else []
	var wall_cache: Array[Vector2i] = manager.get("_wall_cache") if "_wall_cache" in manager else []

	var spawn_pos: Vector2i = preferred_pos
	if spawn_pos.x < 0:
		if not ws_cache.is_empty():
			spawn_pos = ws_cache[randi() % ws_cache.size()]
		else:
			spawn_pos = get_safe_spawn_pos(manager, Vector2i(-1, -1), wall_cache)

	var next_id: int = manager.get("_next_agent_id") if "_next_agent_id" in manager else 1
	if "_next_agent_id" in manager:
		manager._next_agent_id = next_id + 1

	var name_str: String = manager.generate_npc_name(NPCBase.JobType.ARTISAN) if manager.has_method("generate_npc_name") else "도편수 이성길"
	var ag: Dictionary = NPCBase.acquire_agent(next_id, NPCBase.JobType.ARTISAN, spawn_pos, name_str)
	ag["home_tile"] = spawn_pos
	ag["bubble_text"] = "전돌과 화강암을 빈틈없이 맞추어 천년 성곽을 쌓으세!"
	ag["bubble_timer"] = 3.5
	ag["extra"] = {"hammer_anim": 0.0, "trade": "smith"}

	# 공방 -> 성벽 보수 현장 웨이포인트
	var wps: Array[Vector2i] = [spawn_pos]
	if not wall_cache.is_empty():
		wps.append(wall_cache[randi() % wall_cache.size()])
	ag["waypoints"] = wps

	if "agents" in manager:
		manager.agents.append(ag)
	return ag

## 4. 보부상 (부보상/객주) 스폰: 저잣거리 주막/객주 (com_1/com_2)
static func spawn_bobusang(manager: Node, preferred_pos: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var shop_cache: Array[Vector2i] = manager.get("_shop_cache") if "_shop_cache" in manager else []
	var gate_cache: Array[Vector2i] = manager.get("_gate_cache") if "_gate_cache" in manager else []

	var spawn_pos: Vector2i = preferred_pos
	if spawn_pos.x < 0:
		if not shop_cache.is_empty():
			spawn_pos = shop_cache[randi() % shop_cache.size()]
		else:
			spawn_pos = get_safe_spawn_pos(manager, Vector2i(-1, -1), gate_cache)

	var next_id: int = manager.get("_next_agent_id") if "_next_agent_id" in manager else 1
	if "_next_agent_id" in manager:
		manager._next_agent_id = next_id + 1

	var name_str: String = manager.generate_npc_name(NPCBase.JobType.BOBUSANG) if manager.has_method("generate_npc_name") else "개성보부상 만석"
	var ag: Dictionary = NPCBase.acquire_agent(next_id, NPCBase.JobType.BOBUSANG, spawn_pos, name_str)
	ag["home_tile"] = spawn_pos
	ag["bubble_text"] = "삼남의 햅쌀과 서해 소금이오! 저잣거리로 모이시오!"
	ag["bubble_timer"] = 3.5

	# 저잣거리 <-> 성문 사전 정의 웨이포인트 순환
	var wps: Array[Vector2i] = [spawn_pos]
	if not gate_cache.is_empty():
		wps.append(gate_cache[randi() % gate_cache.size()])
	ag["waypoints"] = wps

	if "agents" in manager:
		manager.agents.append(ag)
	return ag

## 5. 승군 (호국 의승) 스폰: 성 밖 사찰(용주사 등) 또는 성문 외곽
static func spawn_monk_soldier(manager: Node, preferred_pos: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var gate_cache: Array[Vector2i] = manager.get("_gate_cache") if "_gate_cache" in manager else []
	var patrol_roads: Array[Vector2i] = manager.get("_patrol_roads_cache") if "_patrol_roads_cache" in manager else []
	var levee_cache: Array[Vector2i] = manager.get("_levee_cache") if "_levee_cache" in manager else []

	var spawn_pos: Vector2i = preferred_pos
	if spawn_pos.x < 0:
		if not gate_cache.is_empty():
			spawn_pos = gate_cache[randi() % gate_cache.size()]
		elif not patrol_roads.is_empty():
			spawn_pos = patrol_roads[randi() % patrol_roads.size()]
		else:
			spawn_pos = get_safe_spawn_pos(manager, Vector2i(-1, -1), levee_cache)

	var next_id: int = manager.get("_next_agent_id") if "_next_agent_id" in manager else 1
	if "_next_agent_id" in manager:
		manager._next_agent_id = next_id + 1

	var name_str: String = manager.generate_npc_name(NPCBase.JobType.MONK_SOLDIER) if manager.has_method("generate_npc_name") else "승병장 탄묵"
	var ag: Dictionary = NPCBase.acquire_agent(next_id, NPCBase.JobType.MONK_SOLDIER, spawn_pos, name_str)
	ag["home_tile"] = spawn_pos
	ag["bubble_text"] = "호국 의승의 원력으로 화성 성곽을 굳건히 수호하리라."
	ag["bubble_timer"] = 3.5

	# 성곽 순찰로 및 제방 사전 정의 웨이포인트 순환
	var wps: Array[Vector2i] = [spawn_pos]
	if not patrol_roads.is_empty():
		var sample_cnt: int = mini(3, patrol_roads.size())
		for _i in range(sample_cnt):
			wps.append(patrol_roads[randi() % patrol_roads.size()])
	if not levee_cache.is_empty():
		wps.append(levee_cache[randi() % levee_cache.size()])
	ag["waypoints"] = wps

	if "agents" in manager:
		manager.agents.append(ag)
	return ag

## 6. 백정 (도축/가죽공) 스폰: 성벽 바깥 외곽/저습지 주변 소박한 움막 (1x1)
static func spawn_butcher(manager: Node, preferred_pos: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var water_banks: Array[Dictionary] = manager.get("_water_banks_cache") if "_water_banks_cache" in manager else []
	var agr_cache: Array[Vector2i] = manager.get("_agr_cache") if "_agr_cache" in manager else []

	var spawn_pos: Vector2i = preferred_pos
	if spawn_pos.x < 0:
		if not water_banks.is_empty():
			var wb: Dictionary = water_banks[randi() % water_banks.size()]
			spawn_pos = wb.get("pos", Vector2i(12, 12))
		else:
			spawn_pos = get_safe_spawn_pos(manager, Vector2i(-1, -1), agr_cache)

	var next_id: int = manager.get("_next_agent_id") if "_next_agent_id" in manager else 1
	if "_next_agent_id" in manager:
		manager._next_agent_id = next_id + 1

	var name_str: String = manager.generate_npc_name(NPCBase.JobType.BUTCHER) if manager.has_method("generate_npc_name") else "가죽공 무쇠"
	var ag: Dictionary = NPCBase.acquire_agent(next_id, NPCBase.JobType.BUTCHER, spawn_pos, name_str)
	ag["home_tile"] = spawn_pos
	ag["bubble_text"] = "질 좋은 가죽을 무두질하고 고기를 정결히 손질하세."
	ag["bubble_timer"] = 3.5
	ag["extra"] = {"tanning_anim": 0.0}

	# 움막 <-> 저잣거리/수원천변 왕복 웨이포인트
	var wps: Array[Vector2i] = [spawn_pos]
	var shop_cache: Array[Vector2i] = manager.get("_shop_cache") if "_shop_cache" in manager else []
	if not shop_cache.is_empty():
		wps.append(shop_cache[randi() % shop_cache.size()])
	ag["waypoints"] = wps

	if "agents" in manager:
		manager.agents.append(ag)
	return ag

## 도시 발전 상태에 따른 6대 직업군 일괄 보충 스케줄러
static func spawn_all_district_professionals(manager: Node) -> void:
	if not ("agents" in manager):
		return
	var agents_list: Array = manager.agents

	# 직업별 활성 인원수 확인
	var counts := {
		NPCBase.JobType.JUNGIN: 0,
		NPCBase.JobType.AJEOUN: 0,
		NPCBase.JobType.ARTISAN: 0,
		NPCBase.JobType.BOBUSANG: 0,
		NPCBase.JobType.MONK_SOLDIER: 0,
		NPCBase.JobType.BUTCHER: 0
	}

	for a_val in agents_list:
		if a_val is Dictionary:
			var a: Dictionary = a_val as Dictionary
			if a.get("is_dead", false):
				continue
			var jt: int = int(a.get("job_type", NPCBase.JobType.COMMONER))
			if counts.has(jt):
				counts[jt] += 1

	# 직업별 목표 인원수 (최소 1~2인 유지)
	if counts[NPCBase.JobType.JUNGIN] < 1:
		spawn_jungin(manager)
	if counts[NPCBase.JobType.AJEOUN] < 1:
		spawn_ajeoun(manager)
	if counts[NPCBase.JobType.ARTISAN] < 2:
		spawn_specific_artisan(manager)
	if counts[NPCBase.JobType.BOBUSANG] < 2:
		spawn_bobusang(manager)
	if counts[NPCBase.JobType.MONK_SOLDIER] < 2:
		spawn_monk_soldier(manager)
	if counts[NPCBase.JobType.BUTCHER] < 1:
		spawn_butcher(manager)

## 7. 민간 포수 (사포수) 스폰: 마을 침범 산짐승 즉시 소탕 및 산악 원정 사냥
static func spawn_saposu(manager: Node, preferred_pos: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var res_cache: Array[Vector2i] = manager.get("_res_cache") if "_res_cache" in manager else []
	var mountain_cache: Array[Vector2i] = manager.get("_mountain_cache") if "_mountain_cache" in manager else []
	var forest_cache: Array[Vector2i] = manager.get("_forest_cache") if "_forest_cache" in manager else []
	var roads_cache: Array[Vector2i] = manager.get("_roads_cache") if "_roads_cache" in manager else []

	var spawn_pos: Vector2i = preferred_pos
	if spawn_pos.x < 0:
		if not res_cache.is_empty():
			spawn_pos = res_cache[randi() % res_cache.size()]
		elif not roads_cache.is_empty():
			spawn_pos = roads_cache[randi() % roads_cache.size()]
		elif not mountain_cache.is_empty():
			spawn_pos = mountain_cache[randi() % mountain_cache.size()]
		else:
			spawn_pos = get_safe_spawn_pos(manager, Vector2i(-1, -1), forest_cache)

	if manager.has_method("_add_road_agent"):
		var leader: Dictionary = manager.call("_add_road_agent", "saposu", spawn_pos)
		leader["leader"] = true
		leader["state"] = "search"
		leader["speed"] = 0.82
		leader["bubble_text"] = "조총에 화승을 걸고 산짐승을 소탕하세!"
		leader["bubble_timer"] = 3.5
		return leader
	return {}

## ─────────────────────────────────────────────────────────────
## [성 밖 민간가옥 도로 연결 필수화 & 대유둔전 수리시설 인접 형성 고증 시스템]
## ─────────────────────────────────────────────────────────────

## 후보 좌표 기준 상·하·좌·우 4방향 중 최소 1곳에 유효 도로가 존재하는지 O(1) 검사
static func has_adjacent_road(grid: GameGrid, pos: Vector2i) -> bool:
	return RoadNetwork.has_adjacent_road(grid, pos)

## 성 밖 민간가옥 스폰 자격 검사 (도로 인접성 필수)
static func can_spawn_outskirt_house(grid: GameGrid, pos: Vector2i) -> bool:
	if grid == null or not grid.in_bounds(pos.x, pos.y):
		return false
	var cell: Dictionary = grid.grid[pos.y][pos.x]
	# 성 밖 평지 타일만 허용
	if cell.get("terrain", "") != "outside":
		return false
	# 이미 건물이 있거나 구획이 지정된 곳은 제외
	if cell.get("building", "") != "" or cell.get("zone", "") != "":
		return false
	# 물이나 산악 지형 제외
	if cell.get("terrain", "") in ["water", "mountain"]:
		return false
	# 필수: 상하좌우 4방향 중 최소 1면에 유효 도로가 접해야 함
	if not has_adjacent_road(grid, pos):
		return false
	return true

## 특정 좌표가 맵 상의 만석거/저수지 유효 관개 반경(기본 8칸) 이내인지 검사
static func is_near_reservoir(grid: GameGrid, pos: Vector2i, max_dist: int = 8) -> bool:
	if grid == null:
		return false
	if grid.reservoir_positions.is_empty():
		grid.update_reservoir_positions()
	return grid.is_near_reservoir(pos, max_dist)

## 대유둔전(경작지) 자연 개간 및 스폰 자격 검사 (만석거/저수지 연동 필수)
## 역사 고증: 정조의 만석거/축만제 축조로 농업용수가 공급된 수리시설 반경(8칸)에만 형성
static func can_spawn_dunjeon(grid: GameGrid, pos: Vector2i, max_dist: int = 8) -> bool:
	if grid == null or not grid.in_bounds(pos.x, pos.y):
		return false
	var cell: Dictionary = grid.grid[pos.y][pos.x]
	# 1. 성 밖 임의 위치 무작위 스폰 전면 금지 (성 밖 평지만 허용)
	if cell.get("terrain", "") != "outside" or cell.get("building", "") != "" or cell.get("zone", "") != "":
		return false
	# 2. 맵 상에 만석거, 축만제 또는 지정된 대형 저수지/보 수리시설이 존재해야 함
	if grid.reservoir_positions.is_empty():
		grid.update_reservoir_positions()
	if grid.reservoir_positions.is_empty():
		return false
	# 3. 해당 수리시설 기준 유효 관개 반경(8칸 이내)의 평지 타일에만 대유둔전 형성
	if not is_near_reservoir(grid, pos, max_dist):
		return false
	return true

## [세이브 로드 마이그레이션 훅]: 도로 없는 맹지 방치 가옥 및 저수지 없는 허공 둔전 정리
static func clean_isolated_outskirts(grid: GameGrid, sim: SimulationCore = null) -> Dictionary:
	if grid == null or grid.grid.is_empty():
		return {"cleaned_houses": 0, "cleaned_farms": 0}

	grid.update_reservoir_positions()
	var cleaned_houses: int = 0
	var cleaned_farms: int = 0

	for y: int in range(grid.size):
		for x: int in range(grid.size):
			var cell: Dictionary = grid.grid[y][x]
			if cell.get("terrain", "") != "outside":
				continue
			var b: String = str(cell.get("building", ""))
			var z: String = str(cell.get("zone", ""))
			var pt := Vector2i(x, y)

			# 1. 도로가 없는 맹지에 방치된 성 밖 민간가옥/주막 정리
			if b.begins_with("res") or b.begins_with("com"):
				var has_adj: bool = has_adjacent_road(grid, pt)
				var road_connected: bool = grid.is_road_connected(x, y, 3)
				if not has_adj and not road_connected:
					cell["building"] = ""
					if z in ["res", "com"]:
						cell["zone"] = ""
					cell.erase("isolated_turns")
					cleaned_houses += 1

			# 2. 대유둔전(agr)은 저수지가 없더라도 천수답(식량 생산 -10% 페널티)으로 정상 경작되므로
			# 플레이어가 설정한 구획이나 경작지를 세이브 로드 시 강제로 삭제하지 않고 보존한다.

	if cleaned_houses > 0:
		grid.recount_zone_counts()
		grid.recompute_infrastructure()
		if sim and sim.pop_manager:
			sim.pop_manager.sync_housing_lists_from_grid(grid)
			sim.pop_manager.update_housing_occupancy(grid)
		print("[세이브 정리 완료] 성 밖 맹지 가옥 %d채를 자연 정리했습니다." % cleaned_houses)

	return {"cleaned_houses": cleaned_houses, "cleaned_farms": cleaned_farms}

## [런타임 턴 점검 훅]: 도로 미연결 경고(!)가 3턴 이상 지속된 고립 가옥 자동 소멸
static func clean_stalled_isolated_houses(grid: GameGrid, sim: SimulationCore = null) -> int:
	if grid == null or grid.grid.is_empty():
		return 0

	var removed_count: int = 0
	for y: int in range(grid.size):
		for x: int in range(grid.size):
			var cell: Dictionary = grid.grid[y][x]
			if cell.get("terrain", "") != "outside":
				continue
			var b: String = str(cell.get("building", ""))
			if not (b.begins_with("res") or b.begins_with("com")):
				continue

			# 도로 연결 상태 점검
			if not grid.is_road_connected(x, y):
				var turns: int = int(cell.get("isolated_turns", 0)) + 1
				cell["isolated_turns"] = turns
				if turns >= 3:
					# 백성이 떠난 것으로 판정하여 자연 철거
					cell["building"] = ""
					if cell.get("zone", "") in ["res", "com"]:
						cell["zone"] = ""
					cell.erase("isolated_turns")
					removed_count += 1
			else:
				cell.erase("isolated_turns")

	if removed_count > 0:
		grid.recount_zone_counts()
		if sim and sim.pop_manager:
			sim.pop_manager.sync_housing_lists_from_grid(grid)
			sim.pop_manager.update_housing_occupancy(grid)
		print("[고립 가옥 자연 철거] 도로 미연결 3턴 경과 고립 가옥 %d채가 자연 철거되었습니다." % removed_count)

	return removed_count
