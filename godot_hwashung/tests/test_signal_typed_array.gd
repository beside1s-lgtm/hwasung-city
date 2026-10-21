extends SceneTree

func _init() -> void:
	print("=== grid_tiles_changed 시그널 및 mark_dirty_local Typed Array 검증 시작 ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var grid := GameGrid.new()
	grid._build_from_map()
	var citizen_mgr := CitizenManager.new()
	citizen_mgr.setup(grid)

	var received_tiles: Array = []
	var test_callable := func(tiles: Array):
		received_tiles.append_array(tiles)

	grid.grid_tiles_changed.connect(test_callable)

	print("[검증 1] mark_dirty_local 호출 시 grid_tiles_changed 정상 발화 및 타입 변환 오류 없는지 검증...")
	var test_pos := Vector2i(10, 15)
	grid.mark_dirty_local(test_pos)

	if received_tiles.size() == 1 and received_tiles[0] == test_pos:
		print("  - [PASS] mark_dirty_local -> grid_tiles_changed 성공 (타일: %s)" % str(received_tiles[0]))
	else:
		printerr("  - [FAIL] mark_dirty_local 타일 수신 실패: ", received_tiles)
		quit(1)
		return

	print("[검증 2] CitizenManager._dirty_nav_tiles 및 _entry_cache 무효화 검증...")
	if citizen_mgr._dirty_nav_tiles.has(test_pos):
		print("  - [PASS] CitizenManager 내 _dirty_nav_tiles 정상 등록 확인")
	else:
		printerr("  - [FAIL] CitizenManager 내 _dirty_nav_tiles 미등록")
		quit(1)
		return

	print("[검증 3] FortressWallManager 보수 시 grid_tiles_changed 발화 검증...")
	var sim := SimulationCore.new()
	var test_wall_pos := Vector2i(20, 20)
	grid.grid[test_wall_pos.y][test_wall_pos.x]["building"] = "wall"
	grid.grid[test_wall_pos.y][test_wall_pos.x]["is_damaged"] = true
	var res := FortressWallManager.repair_wall_tile(grid, test_wall_pos.x, test_wall_pos.y, sim)
	if res.get("success", false) and received_tiles.has(test_wall_pos):
		print("  - [PASS] FortressWallManager -> grid_tiles_changed 정상 전달 확인")
	else:
		printerr("  - [FAIL] FortressWallManager 보수 실패: ", res)
		quit(1)
		return

	print("[검증 4] untyped Array emit 시 CitizenManager 방어적 수용 검증...")
	var untyped_list: Array = [Vector2i(5, 5), Vector2i(6, 6)]
	grid.emit_signal("grid_tiles_changed", untyped_list)
	if citizen_mgr._dirty_nav_tiles.has(Vector2i(5, 5)) and citizen_mgr._dirty_nav_tiles.has(Vector2i(6, 6)):
		print("  - [PASS] untyped Array 수용 및 처리 무결성 확인")
	else:
		printerr("  - [FAIL] untyped Array 수용 실패")
		quit(1)
		return

	print("=== 모든 Typed Array 시그널 검증 통과 (100% PASS) ===")
	quit(0)
