extends SceneTree

func _init() -> void:
	print("=== [TEST] 건설 자율 완공 및 수원향교 오리엔테이션 단위 테스트 시작 ===")
	var grid := GameGrid.new()
	grid._build_from_map()

	# 1. 수원향교 도로 오리엔테이션 검증
	print("[1/3] 수원향교 스마트 오리엔테이션 테스트...")
	var test_tiles: Array[Vector2i] = [
		Vector2i(20, 20), Vector2i(21, 20), Vector2i(22, 20), Vector2i(23, 20),
		Vector2i(20, 21), Vector2i(21, 21), Vector2i(22, 21), Vector2i(23, 21),
		Vector2i(20, 22), Vector2i(21, 22), Vector2i(22, 22), Vector2i(23, 22),
		Vector2i(20, 23), Vector2i(21, 23), Vector2i(22, 23), Vector2i(23, 23)
	]
	# 동쪽(x=24)에 도로 배치
	for y in range(20, 24):
		grid.grid[y][24]["building"] = "road"
	var facing: String = grid.get_best_road_facing_direction(test_tiles)
	assert(facing == "east", "향교 동쪽 도로 인접 시 facing_direction은 east여야 합니다! 실제: %s" % facing)
	print("  -> 향교 동쪽 도로 접점 감지 성공: facing = %s (PASS)" % facing)

	# 2. ConstructionManager 자율 완공 틱 누적 테스트
	print("[2/3] ConstructionManager 자율 완공 틱 누적 테스트...")
	var target_p := Vector2i(30, 30)
	var t: Dictionary = grid.grid[target_p.y][target_p.x]
	t["zone"] = "res"
	t["building"] = "res_1"
	t["zone_build"] = 0.0
	t["under_construction"] = true
	ConstructionManager.register_construction_site(target_p, 0.0, 0)

	# 5턴 진행 시 100% 도달하여 완공되어야 함 (20% * 5 = 100%)
	for turn_i in range(5):
		var completed: Array[Vector2i] = ConstructionManager.process_turn(grid, null, null)
		if turn_i == 4:
			assert(completed.has(target_p), "5턴 후 자율 완공되어야 합니다!")
			assert(t.get("under_construction", false) == false, "under_construction은 false여야 합니다!")
			assert(not t.has("zone_build"), "zone_build는 제거되어야 합니다!")
			assert(t.get("building", "") == "res_1", "건물은 res_1로 확정되어야 합니다!")
	print("  -> 5턴 자율 완공 및 비계 해제 성공 (PASS)")

	# 3. SaveSystem on_game_loaded 훅 데드락 복구 테스트
	print("[3/3] SaveSystem on_game_loaded 장기 방치 타일 복구 테스트...")
	var p_stalled := Vector2i(35, 35)
	var t_s: Dictionary = grid.grid[p_stalled.y][p_stalled.x]
	t_s["zone"] = "com"
	t_s["zone_build"] = 0.0
	t_s["under_construction"] = true

	ConstructionManager.on_game_loaded(grid, null)
	# 1턴 진행 시 age_ticks가 4 이상이므로 즉시/차기 턴 완공 보장
	ConstructionManager.process_turn(grid, null, null)
	assert(t_s.get("under_construction", false) == false, "로드 후 1턴 내에 완공되어야 합니다!")
	assert(not t_s.has("zone_build"), "zone_build가 제거되어야 합니다!")
	print("  -> 세이브 로드 후 정체 비계 1턴 내 완공 복구 성공 (PASS)")

	print("=== 모든 단위 테스트 성공 (ALL PASS) ===")
	quit()
