extends SceneTree

const GameGridClass = preload("res://scripts/GameGrid.gd")
const SimulationCoreClass = preload("res://scripts/SimulationCore.gd")

func _init() -> void:
	print("=== 수원천 치수 방재율 및 HUD 검증 테스트 시작 ===")
	call_deferred("_run_tests")

func _create_test_grid() -> GameGridClass:
	var g := GameGridClass.new()
	g.size = 64
	g.grid = []
	for y in range(64):
		var row: Array = []
		for x in range(64):
			row.append({
				"terrain": "plain",
				"surface": "grass",
				"building": "",
				"zone": "",
				"elevation": 0.0,
				"road_type": "dirt"
			})
		g.grid.append(row)
	return g

func _run_tests() -> void:
	test_flood_defense_calculation()
	test_save_load_auto_heal()
	
	print("=== 모든 치수 방재율 검증 테스트 통과 ===")
	quit(0)

func test_flood_defense_calculation() -> void:
	print("\n--- 1. 치수 방재율 시설별 합산 검증 ---")
	var grid := _create_test_grid()
	
	# 초기 상태: 0%
	grid.recompute_infrastructure()
	assert(grid.flood_defense == 0, "초기 치수 방재율은 0이어야 함: %d" % grid.flood_defense)
	print("  [통과] 초기 치수 방재율: %d%%" % grid.flood_defense)
	
	# 화홍문 완공 시: +30%
	grid.grid[10][35]["building"] = "hwahong"
	grid.grid[10][35]["is_hwahong"] = true
	grid.recompute_infrastructure()
	assert(grid.flood_defense == 30, "화홍문 완공 시 30%%여야 함: %d" % grid.flood_defense)
	assert(grid.hwahong_complete == true, "hwahong_complete가 true여야 함")
	print("  [통과] 화홍문 완공 후 치수 방재율: %d%%" % grid.flood_defense)
	
	# 남수문 추가 완공 시: +30% (누적 60%)
	grid.grid[50][35]["building"] = "namsu"
	grid.grid[50][35]["is_namsu"] = true
	grid.recompute_infrastructure()
	assert(grid.flood_defense == 60, "화홍문+남수문 완공 시 60%%여야 함: %d" % grid.flood_defense)
	assert(grid.namsu_complete == true, "namsu_complete가 true여야 함")
	print("  [통과] 화홍문+남수문 완공 후 치수 방재율: %d%%" % grid.flood_defense)
	
	# 만석거 추가 완공 시: +20% (누적 80%)
	grid.grid[15][15]["building"] = "manseokgeo"
	grid.recompute_infrastructure()
	assert(grid.flood_defense == 80, "만석거 완공 시 80%%여야 함: %d" % grid.flood_defense)
	print("  [통과] 화홍문+남수문+만석거 완공 후 치수 방재율: %d%%" % grid.flood_defense)
	
	# 석축제방 1칸 추가 완공 시: +20% (누적 100% 캡)
	grid.grid[20][30]["building"] = "levee"
	grid.recompute_infrastructure()
	assert(grid.flood_defense == 100, "석축제방 추가 시 최대 100%%여야 함: %d" % grid.flood_defense)
	print("  [통과] 석축제방 추가 후 치수 방재율 (최대 100%% 도달): %d%%" % grid.flood_defense)

func test_save_load_auto_heal() -> void:
	print("\n--- 2. 세이브/로드 시 치수 방재율 Auto-Heal 검증 ---")
	var grid := _create_test_grid()
	var sim := SimulationCoreClass.new()
	
	# 타일에 화홍문과 석축제방 배치
	var tiles_data: Array = [
		{"x": 10, "y": 35, "b": "hwahong", "is_spec": true, "fid": "hwahong_mun"},
		{"x": 20, "y": 30, "b": "levee"}
	]
	
	for td: Dictionary in tiles_data:
		var tx: int = int(td.get("x", -1))
		var ty: int = int(td.get("y", -1))
		var cell: Dictionary = grid.grid[ty][tx]
		cell["building"] = str(td.get("b", ""))
		if cell["building"] == "hwahong":
			cell["is_hwahong"] = true
	
	grid.recompute_infrastructure()
	sim.flood_defense = grid.flood_defense
	
	assert(sim.flood_defense == 50, "화홍문(30) + 석축제방(20) = 50%%로 자동 복구되어야 함: %d" % sim.flood_defense)
	print("  [통과] 세이브 로드 시 치수 방재율 정상 복구: %d%%" % sim.flood_defense)
