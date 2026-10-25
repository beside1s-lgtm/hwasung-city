extends RefCounted
class_name BuildingManager

## [가옥 상태 관리 및 건물-복지 시설 연동 매니저]
## 정상 가옥 ↔ 폐허(잡초 우거진 빈집/무너진 초가) 상태 동기화 및 건물 관리 헬퍼
## 국방 지표(성 방호력 및 군사 공격력) 실시간 갱신 훅 및 Auto-Heal 지원
## [공방 및 저잣거리 상점 카운터 캐시]
## O(1) 매칭 연산 및 실시간 시너지 엔진을 위한 전역 활성 카운터
static var active_workshop_count: int = 0
static var active_market_shop_count: int = 0

## 타일이 공방(수공업·대장간·작업장)인지 여부 판정
static func is_workshop(building_id: String) -> bool:
	return building_id.begins_with("ind") or building_id in ["workshop", "smithy", "foundry", "woodcraft"]

## 타일이 저잣거리 상점인지 여부 판정
static func is_market_shop(building_id: String) -> bool:
	return building_id.begins_with("com")

## 건물 완공/철거 시 공방 및 상점 활성 카운터 델타 반영 (O(1))
static func update_workshop_and_shop_delta(old_b: String, new_b: String) -> void:
	if old_b == new_b:
		return
	if is_workshop(old_b):
		active_workshop_count = maxi(0, active_workshop_count - 1)
	elif is_market_shop(old_b):
		active_market_shop_count = maxi(0, active_market_shop_count - 1)

	if is_workshop(new_b):
		active_workshop_count += 1
	elif is_market_shop(new_b):
		active_market_shop_count += 1

## 그리드 전수 스캔을 통한 공방 및 상점 수 완전 동기화 (세이브 로드/초기화 시)
static func sync_workshop_and_shop_counts(grid: GameGrid) -> Dictionary:
	active_workshop_count = 0
	active_market_shop_count = 0
	if grid == null or not ("grid" in grid):
		return {"workshops": 0, "shops": 0}

	var g_size: int = int(grid.size)
	for y: int in range(g_size):
		for x: int in range(g_size):
			var cell: Dictionary = grid.grid[y][x]
			if cell.has("wall_build") or cell.has("zone_build") or bool(cell.get("under_construction", false)):
				continue
			var b: String = str(cell.get("building", ""))
			if is_workshop(b):
				active_workshop_count += 1
			elif is_market_shop(b):
				active_market_shop_count += 1

	return {
		"workshops": active_workshop_count,
		"shops": active_market_shop_count
	}

## 가옥 타일이 폐허인지 여부 확인
static func is_ruined(cell: Dictionary) -> bool:
	return bool(cell.get("is_ruined", false))

## 가옥 타일을 폐허 또는 정상 상태로 설정
static func set_ruined(cell: Dictionary, ruined: bool) -> void:
	cell["is_ruined"] = ruined

## 건물 파괴(약탈/폐가화): 원본 건물을 queue_free 하지 않고 original_building_type 보존
static func ruin_building_at(pos: Vector2i, grid: GameGrid, _sim: SimulationCore = null) -> bool:
	if grid == null or not grid.in_bounds(pos.x, pos.y):
		return false
	var cell: Dictionary = grid.grid[pos.y][pos.x]
	var bld: String = str(cell.get("building", ""))
	if bld == "" and str(cell.get("zone", "")) == "":
		return false
	if bool(cell.get("is_ruined", false)):
		return false

	if cell.get("original_building_type", "") == "" and bld != "":
		cell["original_building_type"] = bld

	cell["is_ruined"] = true
	cell["building_state"] = "RUINED"
	cell["is_looted"] = true
	cell["looted_timer"] = 35.0
	cell["ruined_rebuild_turns"] = 3

	if is_workshop(bld) or is_market_shop(bld):
		sync_workshop_and_shop_counts(grid)

	if grid != null:
		if grid.has_method("mark_dirty_local"):
			grid.mark_dirty_local(pos)
		elif grid.has_signal("grid_changed"):
			grid.emit_signal("grid_changed")
	return true

## 적군 진압 완료 후 일정 턴에 걸쳐 서서히 본래 건물로 복구/재건
static func restore_ruined_buildings(grid: GameGrid, sim: SimulationCore = null, force_all: bool = false) -> int:
	if grid == null or not ("grid" in grid):
		return 0

	var restored_count: int = 0
	var g_size: int = int(grid.size)

	for y: int in range(g_size):
		for x: int in range(g_size):
			var cell: Dictionary = grid.grid[y][x]
			if not bool(cell.get("is_ruined", false)):
				continue

			var remaining_turns: int = int(cell.get("ruined_rebuild_turns", 3)) - 1
			cell["ruined_rebuild_turns"] = maxi(0, remaining_turns)

			if force_all or remaining_turns <= 0:
				var orig_b: String = str(cell.get("original_building_type", ""))
				if orig_b != "":
					cell["building"] = orig_b
				cell["is_ruined"] = false
				cell["building_state"] = "NORMAL"
				cell.erase("is_looted")
				cell.erase("looted_timer")
				cell.erase("ruined_rebuild_turns")
				restored_count += 1
				if grid != null:
					if grid.has_method("mark_dirty_local"):
						grid.mark_dirty_local(Vector2i(x, y))
					elif grid.has_signal("grid_changed"):
						grid.emit_signal("grid_changed")

	if restored_count > 0:
		sync_workshop_and_shop_counts(grid)
		CityStats.recalculate_defense_and_attack(grid, sim)

	return restored_count

## 매 턴 폐가화 동역학: 진압될 때까지 매 턴 도시 전체 인구 -1%씩 유출
static func process_ruined_buildings_turn(grid: GameGrid, sim: SimulationCore = null) -> Dictionary:
	if grid == null or not ("grid" in grid):
		return {"ruined_count": 0, "pop_loss": 0}

	var g_size: int = int(grid.size)
	var ruined_count: int = 0

	for y: int in range(g_size):
		for x: int in range(g_size):
			var cell: Dictionary = grid.grid[y][x]
			if bool(cell.get("is_ruined", false)):
				ruined_count += 1

	var pop_loss: int = 0
	if ruined_count > 0 and sim != null:
		# 진압될 때까지 매 턴 도시 전체 인구 -1%씩 유출
		pop_loss = maxi(1, int(float(sim.population) * 0.01))
		sim.population = maxi(10, sim.population - pop_loss)

	return {
		"ruined_count": ruined_count,
		"pop_loss": pop_loss
	}

## 폐허 스프라이트 프레임 또는 변형 번호 반환
static func get_ruined_variant(cell: Dictionary, x: int, y: int) -> int:
	if cell.has("ruined_variant"):
		return int(cell["ruined_variant"])
	return absi(x * 19 + y * 23) % 3

## 인구 대비 가옥 수용량을 검사하여 가옥 ↔ 폐허 상태 일괄 동기화
static func update_housing_occupancy(grid_ref, pop_mgr: PopulationManager) -> Dictionary:
	if pop_mgr == null:
		return {}
	return pop_mgr.update_housing_occupancy(grid_ref)

## 타일이 5대 복지 시설에 해당하는지 여부 판정
static func is_welfare_facility(building_id: String) -> bool:
	return building_id in ["manseokgeo", "manseokgeo_site", "chukmanje", "patrol", "firefighter", "jinhulso"]

## 타일이 관공서(정부/공공) 시설에 해당하는지 여부 판정
static func is_gov_facility(building_id: String) -> bool:
	return DifficultyManager.is_public_facility(building_id) or building_id in [
		"haenggung", "haenggung_site", "gwana", "gwana_site",
		"patrol", "firefighter", "hyeminseo", "hyanggyo", "hyanggyo_site",
		"seodang", "seojangdae", "yeonmudae", "jongnu", "bongdon",
		"poru", "gongsimdon"
	]

## 시설 완공 훅 (on_building_completed)
## 방어 시설(성곽, 포루, 성문, 수문 등) 및 군사 지휘/치안 시설(행궁, 서장대, 순라청, 연무대)
## 완공 시 CityStats의 방호력과 공격력을 즉시 재계산하여 동기화
## 수리시설(만석거, 축만제, 저수지) 완공 시 저수지 POI 풀 즉각 갱신
static func on_building_completed(building_id: String, grid: GameGrid, sim: SimulationCore = null) -> void:
	if grid == null:
		return
	if is_workshop(building_id) or is_market_shop(building_id):
		sync_workshop_and_shop_counts(grid)
	CityStats.recalculate_defense_and_attack(grid, sim)
	GameProgressManager.scan(grid, sim) # 역사 사전 퍼즐 조각 해금
	if is_gov_facility(building_id) and sim != null and "recalculate_gov_cell_count" in sim:
		sim.recalculate_gov_cell_count(grid)
	if building_id in ["manseokgeo", "manseokgeo_site", "chukmanje", "chukmanje_site", "reservoir", "yongyeon"] or building_id.begins_with("agr"):
		grid.update_reservoir_positions()
		IrrigationManager.recalculate_irrigation(grid, sim)
	if building_id in ["manseokgeo", "manseokgeo_site"]:
		var m_pos: Vector2i = grid.get_facility_pos("manseokgeo")
		if m_pos != Vector2i(-1, -1):
			grid.plant_cherry_groves_around_manseokgeo(m_pos, 6, 6)
	elif building_id in ["yeonghwajeong", "yeonghwajeong_site"]:
		var y_pos: Vector2i = grid.get_facility_pos("yeonghwajeong")
		if y_pos != Vector2i(-1, -1):
			grid.plant_cherry_groves_around_manseokgeo(y_pos, 2, 2)
	if sim != null:
		sim.sync_mega_projects_with_grid(grid)

## 세이브 파일 로드 또는 상태 복원 시 이미 건설된 시설 전수 집계하여 방호력/공격력 재계산 (Auto-Heal)
static func auto_heal_defense_and_attack(grid: GameGrid, sim: SimulationCore = null) -> Dictionary:
	if grid == null:
		return {"defense": 0, "attack": 0}
	sync_workshop_and_shop_counts(grid)
	IrrigationManager.recalculate_irrigation(grid, sim)
	var m_pos: Vector2i = grid.get_facility_pos("manseokgeo")
	if m_pos != Vector2i(-1, -1):
		grid.plant_cherry_groves_around_manseokgeo(m_pos, 6, 6)
	var y_pos: Vector2i = grid.get_facility_pos("yeonghwajeong")
	if y_pos != Vector2i(-1, -1):
		grid.plant_cherry_groves_around_manseokgeo(y_pos, 2, 2)
	return CityStats.recalculate_defense_and_attack(grid, sim)

## 성 밖 도로 없는 맹지 방치 가옥 정리 (DistrictSpawner 위임)
static func clean_isolated_outskirts(grid: GameGrid, sim: SimulationCore = null) -> Dictionary:
	return DistrictSpawner.clean_isolated_outskirts(grid, sim)

## [건설 완공 헬퍼]: 비계 스프라이트를 해제하고 정식 건물 인스턴스로 확정 변환
## 인구 수용량 갱신, 완공 FX 트리거 및 데드락 복구 로깅 수행
static func complete_building(tile_pos: Vector2i, grid: GameGrid, sim: SimulationCore = null, skip_heavy_sync: bool = false) -> bool:
	if grid == null or not grid.in_bounds(tile_pos.x, tile_pos.y):
		return false
	var cell: Dictionary = grid.grid[tile_pos.y][tile_pos.x]

	# 비계 및 공사 플래그 해제
	cell["under_construction"] = false
	cell.erase("zone_build")
	cell.erase("wall_build")
	cell.erase("wall_build_total")
	cell.erase("bp_ticks")
	cell.erase("bp_total")
	cell.erase("_stall_count")
	cell.erase("_prev_frac")
	cell.erase("_w_stall")
	cell.erase("_w_prev")
	grid.unregister_build_tile(tile_pos.x, tile_pos.y)

	var b: String = cell.get("building", "")
	var z: String = cell.get("zone", "")

	# 건물이 아직 없는 구역 타일이면 구역에 맞는 기본 건물 배치
	if b == "" and z != "":
		match z:
			"res":
				cell["building"] = "res_1"
				cell["house_variant"] = randi() % 5
			"com":
				cell["building"] = "com_1"
				cell["prosper"] = 2
				grid.assign_trade(tile_pos.x, tile_pos.y)
			"ind":
				cell["building"] = "ind_1"
				grid.assign_trade(tile_pos.x, tile_pos.y)
			"agr":
				cell["building"] = "agr_1"
		b = cell.get("building", "")

	# 대량 완공 시에는 개별 호출을 스킵하고 일괄 1회만 동기화하도록 지원
	if not skip_heavy_sync:
		# 주거용 건물이 완공되었을 경우 PopulationManager에 주거 리스트 및 수용량 갱신 통보
		if b.begins_with("res"):
			if sim and sim.pop_manager:
				sim.pop_manager.sync_housing_lists_from_grid(grid)
				sim.pop_manager.update_housing_occupancy(grid)

		# 방어/치안/복지 시설 완공 후속 조치
		on_building_completed(b, grid, sim)

	var b_kr: String = InspectNarrativeGenerator.get_korean_name(b, b)
	print("[건설 데드락 복구] (%d, %d) 위치의 정체된 건물(%s, %s)이 자율 완공되었습니다." % [tile_pos.x, tile_pos.y, b_kr, b])
	return true

## 특정 유형의 완공된 건물 위치(site_anchor 또는 x, y) 탐색
static func get_building_pos(b_type: String, grid: GameGrid) -> Vector2i:
	if grid == null:
		return Vector2i(-1, -1)
	for y: int in range(grid.size):
		for x: int in range(grid.size):
			var cell: Dictionary = grid.grid[y][x]
			if cell.has("wall_build") or bool(cell.get("under_construction", false)):
				continue
			var b: String = str(cell.get("building", ""))
			var fac: String = str(cell.get("facility_id", ""))
			if b == b_type or b == (b_type + "_site") or fac == b_type:
				return cell.get("site_anchor", Vector2i(x, y))
			if b_type == "seojangdae" and cell.has("sj2"):
				return cell.get("site_anchor", Vector2i(x, y))
			if b_type == "yeonmudae" and cell.has("ym5"):
				return cell.get("site_anchor", Vector2i(x, y))
	return Vector2i(-1, -1)

## 역사 이벤트 및 의례 연출용 시설별 정밀 중심 좌표 반환 (봉수당, 신풍루, 낙남헌, 서장대, 연무대, 사대문, 수문 등)
## 사용자가 직접 건축한 실제 좌표를 최우선으로 반영
static func get_building_center_pos(facility_id: String, grid: GameGrid) -> Vector2i:
	if grid == null:
		return Vector2i(-1, -1)

	match facility_id:
		"haenggung_bongsudang", "haenggung_yard":
			var h_pos := get_building_pos("haenggung", grid)
			if h_pos.x >= 0 and h_pos.y >= 0:
				# 7x7 복합 행궁의 정중앙 마당 (anchor)
				return h_pos
			return grid.get_facility_pos("haenggung")

		"haenggung_hall":
			var h_pos := get_building_pos("haenggung", grid)
			if h_pos.x >= 0 and h_pos.y >= 0:
				# 정전 봉수당 본전 전각 (anchor 기준 서쪽 1칸)
				var bp := h_pos + Vector2i(-1, 0)
				return bp if grid.in_bounds(bp.x, bp.y) else h_pos
			return grid.get_facility_pos("haenggung")

		"haenggung_sinpungru":
			var h_pos := get_building_pos("haenggung", grid)
			if h_pos.x >= 0 and h_pos.y >= 0:
				# 정문 신풍루 문루 (anchor 기준 동쪽 3칸)
				var sp := h_pos + Vector2i(3, 0)
				return sp if grid.in_bounds(sp.x, sp.y) else h_pos
			return grid.get_facility_pos("haenggung")

		"haenggung_naknam":
			var h_pos := get_building_pos("haenggung", grid)
			if h_pos.x >= 0 and h_pos.y >= 0:
				# 낙남헌 (anchor 기준 서쪽 2칸)
				var np := h_pos + Vector2i(-2, 0)
				return np if grid.in_bounds(np.x, np.y) else h_pos
			return grid.get_facility_pos("haenggung")

		"seojangdae":
			return grid.get_facility_pos("seojangdae")

		"yeonmudae":
			return grid.get_facility_pos("yeonmudae")

		"manseokgeo":
			return grid.get_facility_pos("manseokgeo")

		"gwana":
			return grid.get_facility_pos("gwana")

		"jangan_gate", "jangan":
			return grid.get_gate_pos("jangan")

		"paldal_gate", "paldal":
			return grid.get_gate_pos("paldal")

		"hwaseo_gate", "hwaseo":
			return grid.get_gate_pos("hwaseo")

		"changryong_gate", "changryong":
			return grid.get_gate_pos("changryong")

		"hwahong_gate", "hwahong":
			return grid.get_gate_pos("hwahong")

		"namsu_gate", "namsu":
			return grid.get_gate_pos("namsu")

		_:
			var dyn_pos: Vector2i = grid.get_facility_pos(facility_id)
			if dyn_pos.x >= 0 and dyn_pos.y >= 0:
				return dyn_pos
			return get_building_pos(facility_id, grid)

## 화성유수부(관아) 타일 위치 조회 (없을 시 기본값 — 행궁은 관아를 대신하지 않는다)
static func get_yusubu_tile_position(grid: GameGrid = null) -> Vector2i:
	if SunlacheongManager.gwana_built:
		return SunlacheongManager.gwana_anchor
	if grid != null:
		var gw: Vector2i = grid.get_facility_pos("gwana")
		if gw.x >= 0 and gw.y >= 0:
			return gw
	return Vector2i(20, 20)

## 화성유수부(관아) 월드 2.5D 등각 좌표 조회
static func get_yusubu_world_position(grid: GameGrid = null) -> Vector2:
	var tp: Vector2i = get_yusubu_tile_position(grid)
	return Vector2((float(tp.x) - float(tp.y)) * 32.0, (float(tp.x) + float(tp.y)) * 16.0)

## 가장 가까운 맵 외곽 경계(길 없는 야산/숲/맵 가장자리 밖) 월드 2.5D 등각 좌표 조회
static func get_nearest_map_boundary_escape_pos(origin_world_pos: Vector2, grid: GameGrid = null) -> Vector2:
	if grid != null and grid.grid is Array and not grid.grid.is_empty():
		var g_size: int = grid.grid.size()
		var orig_tx: float = (origin_world_pos.x / 32.0 + origin_world_pos.y / 16.0) / 2.0
		var orig_ty: float = (origin_world_pos.y / 16.0 - origin_world_pos.x / 32.0) / 2.0
		var ot := Vector2(orig_tx, orig_ty)

		# 맵의 4대 외곽 테두리 밖(여유 2타일 외곽) 지점 계산
		var candidate_targets: Array[Vector2] = [
			Vector2(-2.0, clampf(orig_ty, 0.0, float(g_size - 1))),                 # 서북 외곽 (x < 0)
			Vector2(float(g_size + 1), clampf(orig_ty, 0.0, float(g_size - 1))),    # 동남 외곽 (x >= g_size)
			Vector2(clampf(orig_tx, 0.0, float(g_size - 1)), -2.0),                 # 동북 외곽 (y < 0)
			Vector2(clampf(orig_tx, 0.0, float(g_size - 1)), float(g_size + 1))     # 서남 외곽 (y >= g_size)
		]

		var best_cand: Vector2 = candidate_targets[0]
		var best_d: float = ot.distance_to(best_cand)
		for cand in candidate_targets:
			var d: float = ot.distance_to(cand)
			if d < best_d:
				best_d = d
				best_cand = cand

		return Vector2((best_cand.x - best_cand.y) * 32.0, (best_cand.x + best_cand.y) * 16.0)

	# 그리드가 없는 경우 기본 외곽 방향 벡터로 350px 질주
	var dir: Vector2 = origin_world_pos.normalized()
	if dir.length_squared() < 0.01:
		dir = Vector2(1.0, 0.5).normalized()
	return origin_world_pos + dir * 350.0

## 도둑(소매치기) 전용 탈출 목표 좌표 계산:
## 1. 성 밖(terrain == "outside")에서 스폰된 경우: 성문으로 안 가고 가장 가까운 맵 외곽 경계/야산으로 도망.
## 2. 성 안에서 스폰되었으나 완공된 성문이 없는 경우: 길 없는 외곽 야산/맵 경계로 아무렇게나 도망.
## 3. 성 안에서 스폰되었고 완공된 성문이 있는 경우: 가장 가까운 완공 성문으로 도망.
static func get_thief_escape_target_world_pos(origin_world_pos: Vector2, grid: GameGrid = null) -> Vector2:
	var is_outside: bool = false
	if grid != null and grid.grid is Array and not grid.grid.is_empty():
		var orig_tx: float = (origin_world_pos.x / 32.0 + origin_world_pos.y / 16.0) / 2.0
		var orig_ty: float = (origin_world_pos.y / 16.0 - origin_world_pos.x / 32.0) / 2.0
		var ix: int = int(roundf(orig_tx))
		var iy: int = int(roundf(orig_ty))
		if grid.in_bounds(ix, iy):
			var cell: Dictionary = grid.grid[iy][ix]
			if str(cell.get("terrain", "")) == "outside":
				is_outside = true

	# 1. 성 밖에서 스폰된 도둑: 성문으로 안 가고 맵 외곽 경계/야산으로 도망
	if is_outside:
		return get_nearest_map_boundary_escape_pos(origin_world_pos, grid)

	# 2. 성 안에서 스폰된 도둑: 완공된 성문 검색
	var gate_positions: Array[Vector2] = []
	if grid != null and grid.grid is Array:
		var g_size: int = grid.grid.size()
		for y in range(g_size):
			var row: Array = grid.grid[y]
			for x in range(row.size()):
				var cell: Dictionary = row[x]
				# 미완공(공사 중) 성문 제외
				if cell.has("wall_build") or cell.has("zone_build") or bool(cell.get("under_construction", false)):
					continue
				var bld: String = str(cell.get("building", "")).to_lower()
				var fac: String = str(cell.get("facility_id", "")).to_lower()
				if bld in ["jangan_mun", "paldal_mun", "hwaseo_mun", "changryong_mun"] or fac in ["jangan_mun", "paldal_mun", "hwaseo_mun", "changryong_mun"] or bld.ends_with("_mun") or fac.ends_with("_mun"):
					var gw_pos := Vector2((float(x) - float(y)) * 32.0, (float(x) + float(y)) * 16.0)
					if not gate_positions.has(gw_pos):
						gate_positions.append(gw_pos)

	# 3. 완공된 성문이 존재하는 경우: 가장 가까운 완공 성문으로 도주
	if not gate_positions.is_empty():
		var best_pos: Vector2 = gate_positions[0]
		var best_dist: float = origin_world_pos.distance_to(best_pos)
		for gp: Vector2 in gate_positions:
			var d: float = origin_world_pos.distance_to(gp)
			if d < best_dist:
				best_dist = d
				best_pos = gp
		return best_pos

	# 4. 성문이 아직 완공되지 않았거나 없는 경우: 길 없는 외곽/야산으로 아무렇게나 도망
	return get_nearest_map_boundary_escape_pos(origin_world_pos, grid)

## 가장 가까운 4대문(장안문·팔달문·창룡문·화서문) 월드 2.5D 등각 좌표 조회 (하위 호환성 유지)
static func get_nearest_city_gate_world_pos(origin_world_pos: Vector2, grid: GameGrid = null) -> Vector2:
	return get_thief_escape_target_world_pos(origin_world_pos, grid)


## 랜덤 민가 또는 성 밖/외곽 탈출점 월드 2.5D 좌표 반환 (범죄자 귀가·은신처용)
static func get_random_house_or_exit_pos(origin_world_pos: Vector2, grid: GameGrid = null) -> Vector2:
	if grid != null and grid.grid is Array:
		var houses: Array[Vector2i] = []
		var exits: Array[Vector2i] = []
		var g_size: int = grid.grid.size()
		var orig_tx: float = (origin_world_pos.x / 32.0 + origin_world_pos.y / 16.0) / 2.0
		var orig_ty: float = (origin_world_pos.y / 16.0 - origin_world_pos.x / 32.0) / 2.0
		var orig_tile := Vector2(orig_tx, orig_ty)

		for y in range(g_size):
			var row: Array = grid.grid[y]
			for x in range(row.size()):
				var cell: Dictionary = row[x]
				var b: String = str(cell.get("building", ""))
				var z: String = str(cell.get("zone", ""))
				if b.begins_with("res_") or z == "res" or b == "house":
					houses.append(Vector2i(x, y))
				elif x == 0 or y == 0 or x == g_size - 1 or y == g_size - 1:
					exits.append(Vector2i(x, y))

		if not houses.is_empty():
			houses.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
				return Vector2(a).distance_to(orig_tile) < Vector2(b).distance_to(orig_tile)
			)
			var pick_idx: int = randi() % mini(houses.size(), 5)
			var target_t: Vector2i = houses[pick_idx]
			return Vector2((float(target_t.x) - float(target_t.y)) * 32.0, (float(target_t.x) + float(target_t.y)) * 16.0)
		elif not exits.is_empty():
			var exit_t: Vector2i = exits[randi() % exits.size()]
			return Vector2((float(exit_t.x) - float(exit_t.y)) * 32.0, (float(exit_t.x) + float(exit_t.y)) * 16.0)

	return origin_world_pos + Vector2(250.0, -120.0)


## [건물 등급별 캐시 카운터] O(1) 집계를 위한 건물 분류 및 카운팅
static func get_building_tier_counts(grid: GameGrid) -> Dictionary:
	if grid == null:
		return {
			"thatched_count": 0,
			"tile_count": 0,
			"mansion_count": 0,
			"basic_shop_count": 0,
			"luxury_shop_count": 0
		}

	# GameGrid에 캐싱된 값이 있는 경우 O(1) 반환
	if "thatched_count" in grid and "tile_count" in grid and "mansion_count" in grid:
		return {
			"thatched_count": int(grid.get("thatched_count")),
			"tile_count": int(grid.get("tile_count")),
			"mansion_count": int(grid.get("mansion_count")),
			"basic_shop_count": int(grid.get("basic_shop_count")),
			"luxury_shop_count": int(grid.get("luxury_shop_count"))
		}

	# 캐시가 없는 경우 전수 집계 후 반환
	return count_all_building_tiers(grid)

## 전체 그리드 순회 후 건물 등급 전수 집계
static func count_all_building_tiers(grid: GameGrid) -> Dictionary:
	var counts := {
		"thatched_count": 0,
		"tile_count": 0,
		"mansion_count": 0,
		"basic_shop_count": 0,
		"luxury_shop_count": 0
	}
	if grid == null or not ("grid" in grid):
		return counts

	var g_size: int = int(grid.size)
	for y: int in range(g_size):
		for x: int in range(g_size):
			var cell: Dictionary = grid.grid[y][x]
			if bool(cell.get("is_ruined", false)) or bool(cell.get("is_looted", false)):
				continue
			var b: String = str(cell.get("building", ""))
			if b == "res_1":
				counts["thatched_count"] += 1
			elif b == "res_2":
				counts["tile_count"] += 1
			elif b == "res_3":
				counts["mansion_count"] += 1
			elif b in ["com_1", "ind_1"]:
				counts["basic_shop_count"] += 1
			elif b in ["com_2", "ind_2"]:
				counts["luxury_shop_count"] += 1

	return counts

## 성곽 신규 건설비 조회
static func get_wall_build_cost() -> Dictionary:
	return FortressWallManager.get_wall_build_cost()

## 성곽 파손 보수비 조회
static func get_wall_repair_cost() -> Dictionary:
	return FortressWallManager.get_wall_repair_cost()

## 성문 건립비 조회
static func get_gate_build_cost() -> Dictionary:
	return FortressWallManager.get_gate_build_cost()

## 전체 그리드 내 완공된 관공서 점유 셀 수 전수 집계
static func count_gov_cells(grid: GameGrid) -> int:
	if grid == null or not ("grid" in grid):
		return 0
	var count: int = 0
	var g_size: int = int(grid.size)
	for y: int in range(g_size):
		for x: int in range(g_size):
			var cell: Dictionary = grid.grid[y][x]
			if cell.has("wall_build") or bool(cell.get("under_construction", false)):
				continue
			var b: String = str(cell.get("building", ""))
			var fac: String = str(cell.get("facility_id", ""))
			if is_gov_facility(b) or (fac != "" and is_gov_facility(fac)):
				count += 1
	return count

## 특정 빌딩 타입에 해당하는 타일들의 anchor 좌표 수집
static func get_buildings_by_type(type_name: String, grid: GameGrid) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if grid == null or not ("grid" in grid):
		return result
	var g_size: int = int(grid.size)
	var t_upper: String = type_name.to_upper()
	for y: int in range(g_size):
		for x: int in range(g_size):
			var cell: Dictionary = grid.grid[y][x]
			if cell.has("wall_build") or bool(cell.get("under_construction", false)):
				continue
			var b: String = str(cell.get("building", "")).to_upper()
			var fac: String = str(cell.get("facility_id", "")).to_upper()
			if t_upper == "MANSEOKGEO":
				if b in ["MANSEOKGEO", "MANSEOKGEO_SITE"] or fac == "MANSEOKGEO":
					var anch: Vector2i = cell.get("site_anchor", Vector2i(x, y))
					if not (anch in result):
						result.append(anch)
			elif t_upper == "RESERVOIR":
				if b in ["RESERVOIR", "CHUKMANJE", "CHUKMANJE_SITE"] or fac in ["RESERVOIR", "CHUKMANJE"]:
					var anch2: Vector2i = cell.get("site_anchor", Vector2i(x, y))
					if not (anch2 in result):
						result.append(anch2)
			else:
				if b == t_upper or fac == t_upper:
					var anch3: Vector2i = cell.get("site_anchor", Vector2i(x, y))
					if not (anch3 in result):
						result.append(anch3)
	return result

## 특정 빌딩 타입의 완공 개수 반환
static func get_building_count(type_name: String, grid: GameGrid) -> int:
	return get_buildings_by_type(type_name, grid).size()

## 전체 둔전 및 농경지 타일 리스트 수집 (원본 cell 참조 유지)
static func get_all_farms(grid: GameGrid) -> Array[Dictionary]:
	var farms: Array[Dictionary] = []
	if grid == null or not ("grid" in grid):
		return farms
	var g_size: int = int(grid.size)
	for y: int in range(g_size):
		for x: int in range(g_size):
			var cell: Dictionary = grid.grid[y][x]
			var b: String = str(cell.get("building", ""))
			var z: String = str(cell.get("zone", ""))
			if b in ["agr_1", "agr_2"] or (z == "agr" and b == ""):
				farms.append({
					"pos": Vector2i(x, y),
					"grid_pos": Vector2(x, y),
					"cell": cell,
					"x": x,
					"y": y
				})
	return farms
