extends SceneTree

## [검증 테스트] 성 밖 민간가옥 도로 연결 필수화 및 대유둔전 수리시설 인접 형성 고증 반영 검증
## 1. 도로 인접성 검사 (has_adjacent_road)
## 2. 맹지 외곽 가옥 스폰 차단 및 가로변 취락 형성 (can_spawn_outskirt_house)
## 3. 만석거/저수지 부재 시 둔전 스폰 차단 및 반경 8칸 이내 한정 개간 (can_spawn_dunjeon)
## 4. 세이브 로드 시 맹지 가옥 & 허공 둔전 정리 마이그레이션 (clean_isolated_outskirts)
## 5. 도로 미연결 3턴 경과 고립 가옥 자동 소멸 (clean_stalled_isolated_houses)

func _init() -> void:
	var results: Array[String] = []
	var pass_count: int = 0
	var fail_count: int = 0

	print("=== 성 밖 민간가옥 도로 연결 & 대유둔전 수리시설 고증 테스트 시작 ===")

	var grid := GameGrid.new()
	grid.size = 32
	grid.grid = []
	for y in range(grid.size):
		var row: Array = []
		for x in range(grid.size):
			row.append({
				"x": x, "y": y,
				"terrain": "outside",
				"building": "",
				"zone": "",
				"surface": "normal",
				"under_construction": false
			})
		grid.grid.append(row)

	var sim := SimulationCore.new()
	sim.population = 500
	sim.loyalty = 80
	sim.demand_agr = 50

	# -------------------------------------------------------------
	# 테스트 1: 도로 인접성 검사 (has_adjacent_road)
	# -------------------------------------------------------------
	var road_pos := Vector2i(10, 10)
	grid.grid[road_pos.y][road_pos.x]["building"] = "road"

	var adj_north := Vector2i(10, 9)
	var adj_south := Vector2i(10, 11)
	var adj_west := Vector2i(9, 10)
	var adj_east := Vector2i(11, 10)
	var diag_pos := Vector2i(11, 11)
	var far_pos := Vector2i(15, 15)

	var t1_ok: bool = (
		RoadNetwork.has_adjacent_road(grid, adj_north) and
		RoadNetwork.has_adjacent_road(grid, adj_south) and
		RoadNetwork.has_adjacent_road(grid, adj_west) and
		RoadNetwork.has_adjacent_road(grid, adj_east) and
		not RoadNetwork.has_adjacent_road(grid, diag_pos) and
		not RoadNetwork.has_adjacent_road(grid, far_pos)
	)
	if t1_ok:
		pass_count += 1
		results.append("[PASS 1] RoadNetwork 및 DistrictSpawner 상하좌우 O(1) 도로 인접성 검사 정상")
	else:
		fail_count += 1
		results.append("[FAIL 1] 도로 인접성 검사 실패")

	# -------------------------------------------------------------
	# 테스트 2: 성 밖 민간가옥 스폰 자격 검사 (can_spawn_outskirt_house)
	# 맹지 가옥 스폰 원천 차단 및 도로변 취락 허용
	# -------------------------------------------------------------
	var can_adj: bool = DistrictSpawner.can_spawn_outskirt_house(grid, adj_north)
	var can_far: bool = DistrictSpawner.can_spawn_outskirt_house(grid, far_pos)
	var can_diag: bool = DistrictSpawner.can_spawn_outskirt_house(grid, diag_pos)

	if can_adj and not can_far and not can_diag:
		pass_count += 1
		results.append("[PASS 2] 맹지 외곽 가옥 스폰 원천 차단 및 도로 인접 가옥만 스폰 허용 정상")
	else:
		fail_count += 1
		results.append("[FAIL 2] 외곽 가옥 스폰 검사 실패 (can_adj: %s, can_far: %s, can_diag: %s)" % [can_adj, can_far, can_diag])

	# -------------------------------------------------------------
	# 테스트 3: 대유둔전 수리시설(만석거/저수지) 부재 시 스폰 차단
	# -------------------------------------------------------------
	grid.reservoir_positions.clear()
	var can_farm_no_resv: bool = DistrictSpawner.can_spawn_dunjeon(grid, Vector2i(5, 5), 8)
	if not can_farm_no_resv:
		pass_count += 1
		results.append("[PASS 3] 수리시설(만석거/저수지) 부재 시 성 밖 둔전 자연 발생 100% 차단 정상")
	else:
		fail_count += 1
		results.append("[FAIL 3] 수리시설 부재 중에도 둔전 스폰이 허용되는 오류 발생")

	# -------------------------------------------------------------
	# 테스트 4: 만석거 축조 후 반경 8칸 이내 대유둔전 한정 개간
	# -------------------------------------------------------------
	var resv_pos := Vector2i(20, 20)
	grid.grid[resv_pos.y][resv_pos.x]["building"] = "manseokgeo"
	grid.update_reservoir_positions()

	var farm_in_range := Vector2i(23, 22) # 맨해튼 거리 |23-20| + |22-20| = 3 + 2 = 5 <= 8
	var farm_out_range := Vector2i(26, 26) # 맨해튼 거리 |26-20| + |26-20| = 6 + 6 = 12 > 8

	var can_in: bool = DistrictSpawner.can_spawn_dunjeon(grid, farm_in_range, 8)
	var can_out: bool = DistrictSpawner.can_spawn_dunjeon(grid, farm_out_range, 8)

	if can_in and not can_out:
		pass_count += 1
		results.append("[PASS 4] 만석거 반경 8칸 이내 한정 대유둔전 개간 허용 및 원거리 차단 정상")
	else:
		fail_count += 1
		results.append("[FAIL 4] 만석거 반경 둔전 개간 판정 실패 (can_in: %s, can_out: %s)" % [can_in, can_out])

	# -------------------------------------------------------------
	# 테스트 5: 세이브 로드 시 맹지 가옥 & 허공 둔전 정리 마이그레이션 (clean_isolated_outskirts)
	# -------------------------------------------------------------
	# 맹지 가옥 배치 (도로 없음)
	var blind_house := Vector2i(2, 2)
	grid.grid[blind_house.y][blind_house.x]["building"] = "res_1"

	# 정상 도로 인접 가옥 배치
	var valid_house := adj_north
	grid.grid[valid_house.y][valid_house.x]["building"] = "res_1"

	# 만석거 반경 밖 허공 둔전 배치
	var invalid_farm := farm_out_range
	grid.grid[invalid_farm.y][invalid_farm.x]["building"] = "agr_1"
	grid.grid[invalid_farm.y][invalid_farm.x]["zone"] = "agr"

	# 만석거 반경 내 정상 둔전 배치
	var valid_farm := farm_in_range
	grid.grid[valid_farm.y][valid_farm.x]["building"] = "agr_1"
	grid.grid[valid_farm.y][valid_farm.x]["zone"] = "agr"

	var clean_res: Dictionary = DistrictSpawner.clean_isolated_outskirts(grid, sim)

	var blind_cleaned: bool = (grid.grid[blind_house.y][blind_house.x]["building"] == "")
	var valid_preserved: bool = (grid.grid[valid_house.y][valid_house.x]["building"] == "res_1")
	var invalid_farm_cleaned: bool = (grid.grid[invalid_farm.y][invalid_farm.x]["building"] == "" and grid.grid[invalid_farm.y][invalid_farm.x]["zone"] == "")
	var valid_farm_preserved: bool = (grid.grid[valid_farm.y][valid_farm.x]["building"] == "agr_1")

	if blind_cleaned and valid_preserved and invalid_farm_cleaned and valid_farm_preserved:
		pass_count += 1
		results.append("[PASS 5] 세이브 로드 마이그레이션: 맹지 가옥 및 허공 둔전 자연 정리 정상 작동")
	else:
		fail_count += 1
		results.append("[FAIL 5] 마이그레이션 실패 (blind_cl: %s, val_pres: %s, inv_farm_cl: %s, val_farm_pres: %s)" % [blind_cleaned, valid_preserved, invalid_farm_cleaned, valid_farm_preserved])

	# -------------------------------------------------------------
	# 테스트 6: 도로 미연결 경고 3턴 경과 고립 가옥 자동 소멸 (clean_stalled_isolated_houses)
	# -------------------------------------------------------------
	var stalled_house := Vector2i(30, 30)
	grid.grid[stalled_house.y][stalled_house.x]["building"] = "res_1"

	# 1턴: 아직 유지
	DistrictSpawner.clean_stalled_isolated_houses(grid, sim)
	var turn1_stay: bool = (grid.grid[stalled_house.y][stalled_house.x]["building"] == "res_1")

	# 2턴: 아직 유지
	DistrictSpawner.clean_stalled_isolated_houses(grid, sim)
	var turn2_stay: bool = (grid.grid[stalled_house.y][stalled_house.x]["building"] == "res_1")

	# 3턴: 3턴 누적되어 자연 철거
	DistrictSpawner.clean_stalled_isolated_houses(grid, sim)
	var turn3_removed: bool = (grid.grid[stalled_house.y][stalled_house.x]["building"] == "")

	if turn1_stay and turn2_stay and turn3_removed:
		pass_count += 1
		results.append("[PASS 6] 도로 미연결 경고 3턴 경과 고립 가옥 자연 철거 정상 작동")
	else:
		fail_count += 1
		results.append("[FAIL 6] 고립 가옥 자동 소멸 실패 (t1: %s, t2: %s, t3: %s)" % [turn1_stay, turn2_stay, turn3_removed])

	# -------------------------------------------------------------
	# 테스트 7: OutsideSettlement grow() 및 grow_dunjian() 통합 시뮬레이션
	# -------------------------------------------------------------
	var outside := OutsideSettlement.new()
	outside.setup(grid, sim)

	# 빈 맵(도로 및 저수지 없음) 상태에서 grow() 실행 -> 스폰 0
	for y in range(grid.size):
		for x in range(grid.size):
			grid.grid[y][x]["building"] = ""
			grid.grid[y][x]["zone"] = ""
	grid.reservoir_positions.clear()
	grid.reservoir_poi_pool.clear()

	var grown_empty: int = outside.grow()
	var t7_empty_ok: bool = (grown_empty == 0)

	# 도로 1칸 및 만석거 배치 후 grow()
	grid.grid[15][15]["building"] = "road"
	grid.grid[20][20]["building"] = "manseokgeo"
	grid.update_reservoir_positions()

	var grown_with_infra: int = outside.grow()
	var t7_infra_ok: bool = (grown_with_infra > 0)

	# 스폰된 가옥들이 도로에 인접해 있는지 전수 검증
	var all_spawned_houses_adjacent: bool = true
	var all_spawned_farms_near_res: bool = true

	for y in range(grid.size):
		for x in range(grid.size):
			var cell: Dictionary = grid.grid[y][x]
			var b: String = str(cell.get("building", ""))
			var pt := Vector2i(x, y)
			if b.begins_with("res") or b.begins_with("com"):
				if not RoadNetwork.has_adjacent_road(grid, pt):
					all_spawned_houses_adjacent = false
			elif b.begins_with("agr"):
				if not grid.is_near_reservoir(pt, 8):
					all_spawned_farms_near_res = false

	if t7_empty_ok and t7_infra_ok and all_spawned_houses_adjacent and all_spawned_farms_near_res:
		pass_count += 1
		results.append("[PASS 7] OutsideSettlement 통합 시뮬레이션: 인프라 부재 시 스폰 차단 및 완비 시 규칙 준수 스폰 정상")
	else:
		fail_count += 1
		results.append("[FAIL 7] OutsideSettlement 통합 검증 실패 (empty: %s, infra: %s, adj: %s, near: %s)" % [t7_empty_ok, t7_infra_ok, all_spawned_houses_adjacent, all_spawned_farms_near_res])

	# 결과 출력 및 파일 저장
	var report_path := "res://test_outskirt_result.txt"
	var fa := FileAccess.open(report_path, FileAccess.WRITE)
	if fa:
		fa.store_line("=== 성 밖 민간가옥 도로 연결 & 대유둔전 고증 테스트 결과 ===")
		fa.store_line("성공: %d / 실패: %d" % [pass_count, fail_count])
		for r in results:
			fa.store_line(r)
		fa.close()

	print("성공: %d / 실패: %d" % [pass_count, fail_count])
	for r in results:
		print(r)

	if fail_count == 0:
		print("=== 모든 테스트 완벽 통과 (PASS) ===")
		quit(0)
	else:
		printerr("=== 테스트 실패 존재 (FAIL) ===")
		quit(1)
