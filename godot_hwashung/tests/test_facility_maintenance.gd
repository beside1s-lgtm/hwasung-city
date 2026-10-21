extends SceneTree

const DifficultyManagerClass = preload("res://scripts/DifficultyManager.gd")
const FacilityMaintenanceManagerClass = preload("res://scripts/FacilityMaintenanceManager.gd")
const GameGridClass = preload("res://scripts/GameGrid.gd")
const SimulationCoreClass = preload("res://scripts/SimulationCore.gd")

func _init() -> void:
	print("=== [테스트 시작] 공공시설 턴당 운영자금 및 난이도 배율 시스템 검증 ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	_test_maintenance_multipliers()
	_test_haenggung_population_scaling()
	_test_facility_base_costs()
	_test_roads_and_levees_cost()
	_test_grid_maintenance_calculation()
	_test_difficulty_scaling_simulation()
	_test_deficit_penalties()
	_test_monthly_budget_integration()

	print("=== [테스트 완료] 공공시설 턴당 운영자금 전 항목 100% 검증 성공! ===")
	quit(0)

## 1. 난이도별 유지비 배율 검증 (쉬움 1.0, 보통 1.2, 어려움 1.3)
func _test_maintenance_multipliers() -> void:
	print("[검증 1] 난이도별 운영자금 배율 검증...")
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.EASY)
	assert(is_equal_approx(FacilityMaintenanceManagerClass.get_maintenance_multiplier(), 1.0), "쉬움 배율은 1.0x이어야 함")

	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.NORMAL)
	assert(is_equal_approx(FacilityMaintenanceManagerClass.get_maintenance_multiplier(), 1.20), "보통 배율은 1.2x이어야 함")

	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.HARD)
	assert(is_equal_approx(FacilityMaintenanceManagerClass.get_maintenance_multiplier(), 1.30), "어려움 배율은 1.3x이어야 함")
	print("  - [PASS] 난이도별 배율 (1.0x / 1.2x / 1.3x) 검증 완료")

## 2. 행궁 인구 비례 소모 검증
func _test_haenggung_population_scaling() -> void:
	print("[검증 2] 행궁 인구 규모 비례 소모 검증...")
	# 초기 인구 (120명): 100냥
	assert(FacilityMaintenanceManagerClass.calculate_haenggung_base_gold(120) == 100, "인구 120명일 때 기본 100냥이어야 함")
	assert(FacilityMaintenanceManagerClass.calculate_haenggung_base_gold(500) == 100, "인구 500명일 때 기본 100냥이어야 함")
	assert(FacilityMaintenanceManagerClass.calculate_haenggung_base_gold(999) == 100, "인구 999명일 때 기본 100냥이어야 함")

	# 인구 1,000명: 1,000냥
	assert(FacilityMaintenanceManagerClass.calculate_haenggung_base_gold(1000) == 1000, "인구 1,000명일 때 1,000냥이어야 함")
	# 인구 2,500명: 2,000냥
	assert(FacilityMaintenanceManagerClass.calculate_haenggung_base_gold(2500) == 2000, "인구 2,500명일 때 2,000냥이어야 함")
	# 인구 10,000명: 10,000냥
	assert(FacilityMaintenanceManagerClass.calculate_haenggung_base_gold(10000) == 10000, "인구 10,000명일 때 10,000냥이어야 함")
	print("  - [PASS] 행궁 인구 비례 소모 공식 검증 완료")

## 3. 시설별 기본 비용 테이블 정합성 검증
func _test_facility_base_costs() -> void:
	print("[검증 3] 시설별 쉬움 기준 턴당 기본 비용 검증...")
	var tbl: Dictionary = FacilityMaintenanceManagerClass.BASE_MAINTENANCE_TABLE

	assert(tbl["patrol"]["gold"] == 500 and tbl["patrol"]["rice"] == 500, "순라청: 500냥/500석")
	assert(tbl["firefighter"]["gold"] == 500 and tbl["firefighter"]["rice"] == 500, "멸화군: 500냥/500석")
	assert(tbl["seojangdae"]["gold"] == 2000 and tbl["seojangdae"]["rice"] == 2000, "서장대: 2000냥/2000석")
	assert(tbl["yeonmudae"]["gold"] == 2000 and tbl["yeonmudae"]["rice"] == 2000, "연무대: 2000냥/2000석")
	assert(tbl["gwana"]["gold"] == 2000 and tbl["gwana"]["rice"] == 2000, "관아: 2000냥/2000석")
	assert(tbl["bongdon"]["gold"] == 2000 and tbl["bongdon"]["rice"] == 0, "봉돈: 2000냥")
	assert(tbl["poru"]["gold"] == 2000 and tbl["poru"]["rice"] == 0, "포루: 2000냥")
	assert(tbl["gongsimdon"]["gold"] == 2000 and tbl["gongsimdon"]["rice"] == 0, "공심돈: 2000냥")
	assert(tbl["gate"]["gold"] == 2000 and tbl["gate"]["rice"] == 0, "사대문: 각 2000냥")
	assert(tbl["banghwasuryu"]["gold"] == 2000 and tbl["banghwasuryu"]["rice"] == 0, "방화수류정: 2000냥")
	assert(tbl["manseokgeo"]["gold"] == 2000 and tbl["manseokgeo"]["rice"] == 2000, "만석거: 2000냥/2000석")
	assert(tbl["chukmanje"]["gold"] == 2000 and tbl["chukmanje"]["rice"] == 2000, "축만제: 2000냥/2000석")
	assert(tbl["well"]["gold"] == 500 and tbl["well"]["rice"] == 0, "우물: 500냥")
	assert(tbl["hwahong"]["gold"] == 1000 and tbl["hwahong"]["rice"] == 0, "화홍문: 1000냥")
	assert(tbl["namsu"]["gold"] == 1000 and tbl["namsu"]["rice"] == 0, "남수문: 1000냥")
	assert(tbl["jinhulso"]["gold"] == 500 and tbl["jinhulso"]["rice"] == 500, "진휼소: 500냥/500석")
	print("  - [PASS] 시설별 기본 비용 테이블 검증 완료")

## 4. 도로 및 제방 소모 비용 검증
func _test_roads_and_levees_cost() -> void:
	print("[검증 4] 도로 및 제방 소모 비용 검증...")
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.EASY)

	var grid := GameGridClass.new()
	root.add_child(grid)
	_clean_grid_buildings(grid)

	# 흙길 25개 배치 -> 10개당 1냥 -> ceil(25/10) = 3냥
	for i in range(25):
		grid.grid[10][10 + i]["building"] = "road"

	# 박석길 20개 배치 -> 10개당 5냥 -> ceil(20/10)*5 = 10냥
	for i in range(20):
		grid.grid[12][10 + i]["building"] = "stone_road"

	var res: Dictionary = FacilityMaintenanceManagerClass.calculate_turn_maintenance(grid, 120)
	assert(res["details"]["road"]["gold"] == 3, "흙길 25개 비용은 3냥이어야 함: %d" % res["details"]["road"]["gold"])
	assert(res["details"]["stone_road"]["gold"] == 10, "박석길 20개 비용은 10냥이어야 함: %d" % res["details"]["stone_road"]["gold"])

	grid.queue_free()
	print("  - [PASS] 도로 비용 계산 검증 완료")

## 5. 그리드 상 공공시설 집계 및 유지비 총액 검증
func _test_grid_maintenance_calculation() -> void:
	print("[검증 5] 그리드 내 공공시설 집계 및 유지비 총액 검증...")
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.EASY)

	var grid := GameGridClass.new()
	root.add_child(grid)
	_clean_grid_buildings(grid)

	# 순라청 1개, 멸화군 1개, 우물 2개 배치
	grid.grid[5][5]["building"] = "patrol"
	grid.grid[5][6]["building"] = "firefighter"
	grid.grid[5][7]["building"] = "well"
	grid.grid[5][8]["building"] = "well"

	# 행궁 7x7 (site_anchor로 묶인 49개 타일이지만 1개소로 계산되어야 함)
	var h_anch := Vector2i(20, 20)
	for dy in range(7):
		for dx in range(7):
			var cell: Dictionary = grid.grid[20 + dy][20 + dx]
			cell["building"] = "haenggung"
			cell["site_anchor"] = h_anch

	var res: Dictionary = FacilityMaintenanceManagerClass.calculate_turn_maintenance(grid, 10000)
	# 인구 10,000명이므로 행궁은 10,000냥
	assert(res["details"]["haenggung"]["count"] == 1, "행궁은 49타일이어도 1개소로 카운트되어야 함: %d" % res["details"]["haenggung"]["count"])
	assert(res["details"]["haenggung"]["gold"] == 10000, "행궁 금화 10,000냥이어야 함: %d" % res["details"]["haenggung"]["gold"])

	assert(res["details"]["patrol"]["count"] == 1, "순라청 1개소")
	assert(res["details"]["patrol"]["gold"] == 500, "순라청 500냥")
	assert(res["details"]["patrol"]["rice"] == 500, "순라청 500석")

	assert(res["details"]["firefighter"]["count"] == 1, "멸화군 1개소")
	assert(res["details"]["firefighter"]["gold"] == 500, "멸화군 500냥")
	assert(res["details"]["firefighter"]["rice"] == 500, "멸화군 500석")

	assert(res["details"]["well"]["count"] == 2, "우물 2개소")
	assert(res["details"]["well"]["gold"] == 1000, "우물 2개 1,000냥")

	# 총액 검증: 10000 + 500 + 500 + 1000 = 12,000냥, 곡식: 500 + 500 = 1,000석
	assert(res["total_gold"] == 12000, "총 금화 12,000냥 불일치: %d" % res["total_gold"])
	assert(res["total_rice"] == 1000, "총 곡식 1,000석 불일치: %d" % res["total_rice"])

	grid.queue_free()
	print("  - [PASS] 다칸 건물 앵커 단일화 및 총액 집계 검증 완료")

## 6. 난이도별 차등 배율 적용 검증 (보통 +20%, 어려움 +30%)
func _test_difficulty_scaling_simulation() -> void:
	print("[검증 6] 보통(+20%), 어려움(+30%) 배율 적용 검증...")

	var grid := GameGridClass.new()
	root.add_child(grid)
	_clean_grid_buildings(grid)

	# 서장대(2000냥/2000석) 1개소
	grid.grid[15][15]["building"] = "seojangdae"
	grid.grid[15][15]["site_anchor"] = Vector2i(15, 15)

	# 1. 쉬움: 2,000냥 / 2,000석
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.EASY)
	var res_easy: Dictionary = FacilityMaintenanceManagerClass.calculate_turn_maintenance(grid, 500)
	assert(res_easy["details"]["seojangdae"]["gold"] == 2000, "쉬움 서장대 2000냥")
	assert(res_easy["details"]["seojangdae"]["rice"] == 2000, "쉬움 서장대 2000석")

	# 2. 보통: 2,000 * 1.2 = 2,400냥 / 2,400석
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.NORMAL)
	var res_norm: Dictionary = FacilityMaintenanceManagerClass.calculate_turn_maintenance(grid, 500)
	assert(res_norm["details"]["seojangdae"]["gold"] == 2400, "보통 서장대 2400냥(+20%%)이어야 함: %d" % res_norm["details"]["seojangdae"]["gold"])
	assert(res_norm["details"]["seojangdae"]["rice"] == 2400, "보통 서장대 2400석(+20%%)이어야 함: %d" % res_norm["details"]["seojangdae"]["rice"])

	# 3. 어려움: 2,000 * 1.3 = 2,600냥 / 2,600석
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.HARD)
	var res_hard: Dictionary = FacilityMaintenanceManagerClass.calculate_turn_maintenance(grid, 500)
	assert(res_hard["details"]["seojangdae"]["gold"] == 2600, "어려움 서장대 2600냥(+30%%)이어야 함: %d" % res_hard["details"]["seojangdae"]["gold"])
	assert(res_hard["details"]["seojangdae"]["rice"] == 2600, "어려움 서장대 2600석(+30%%)이어야 함: %d" % res_hard["details"]["seojangdae"]["rice"])

	grid.queue_free()
	print("  - [PASS] 난이도 배율 적용 검증 완료")

## 7. 재정 결손(체납) 시 페널티 처리 검증
func _test_deficit_penalties() -> void:
	print("[검증 7] 재정 및 군량 결손 시 페널티 검증...")
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.EASY)

	var sim := SimulationCoreClass.new()
	var grid := GameGridClass.new()
	root.add_child(sim)
	root.add_child(grid)

	# 순라청 (500냥/500석)
	grid.grid[10][10]["building"] = "patrol"

	# 자금 부족 상태 설정
	sim.gold = 100
	sim.rice = 100
	sim.loyalty = 80
	sim.authority = 70

	var res: Dictionary = FacilityMaintenanceManagerClass.apply_turn_maintenance(sim, grid)
	assert(res["deficit_gold"] == true, "금화 결손 발생해야 함")
	assert(res["deficit_rice"] == true, "곡식 결손 발생해야 함")
	assert(sim.gold == 0, "국고는 0으로 처리")
	assert(sim.rice == 0, "군량은 0으로 처리")
	assert(sim.loyalty < 80, "민심 페널티 차감")
	assert(sim.authority < 70, "왕권 페널티 차감")

	sim.queue_free()
	grid.queue_free()
	print("  - [PASS] 결손 페널티 검증 완료")

## 8. SimulationCore 월 예산 정산 연동 검증
func _test_monthly_budget_integration() -> void:
	print("[검증 8] SimulationCore 월 예산 정산 연동 검증...")
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.EASY)

	var sim := SimulationCoreClass.new()
	var grid := GameGridClass.new()
	root.add_child(sim)
	root.add_child(grid)
	_clean_grid_buildings(grid)
	sim.grid_ref = grid

	# 서장대 배치
	grid.grid[15][15]["building"] = "seojangdae"
	grid.grid[15][15]["site_anchor"] = Vector2i(15, 15)

	sim.gold = 5000
	sim.rice = 5000
	sim.population = 500

	sim._process_monthly_budget()

	assert(sim.last_maintenance_result.has("total_gold"), "last_maintenance_result에 total_gold가 기록되어야 함")
	assert(sim.last_maintenance_result["total_gold"] == 2000, "서장대 2000냥 기록되어야 함: %d" % sim.last_maintenance_result["total_gold"])
	assert(sim.last_maintenance_result["total_rice"] == 2000, "서장대 2000석 기록되어야 함: %d" % sim.last_maintenance_result["total_rice"])

	sim.queue_free()
	grid.queue_free()
	print("  - [PASS] SimulationCore 월 예산 연동 검증 완료")

func _clean_grid_buildings(grid: GameGridClass) -> void:
	if grid == null or not ("grid" in grid):
		return
	var g_size: int = int(grid.size)
	for y: int in range(g_size):
		for x: int in range(g_size):
			var cell: Dictionary = grid.grid[y][x]
			cell["building"] = ""
			cell.erase("facility_id")
			cell.erase("site_anchor")
			cell.erase("gate_name")
			cell.erase("gate_kind")
