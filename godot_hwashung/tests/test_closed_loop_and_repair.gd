extends SceneTree

const GameGridClass = preload("res://scripts/GameGrid.gd")
const WallLoopValidatorClass = preload("res://scripts/WallLoopValidator.gd")
const SiegeSystemClass = preload("res://scripts/SiegeSystem.gd")
const SimulationCoreClass = preload("res://scripts/SimulationCore.gd")

func _init() -> void:
	print("=== [테스트 시작] 사대문 유연한 폐곡선 연결 검증 및 긴급 땜질 상태 제어 검증 ===")
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
	_test_flexible_closed_loop_custom_positions()
	_test_wall_connectors_include_structures()
	_test_unconnected_points_no_hardcoded_targets()
	_test_emergency_repair_state_and_disable()

	print("=== [테스트 완료] 사대문 폐곡선 및 긴급 땜질 신규 로직 100% 통과! ===")
	quit(0)

## 1. 하드코딩된 대역사 노선이 아닌 사용자 임의 경로라도 사대문이 성곽으로 연결되면 폐곡선 100% 인정 검증
func _test_flexible_closed_loop_custom_positions() -> void:
	print("[검증 1] 하드코딩 좌표 탈피: 사대문 임의 경로 성곽 연결 시 폐곡선 100% 완공 검증...")
	var grid := _create_test_grid()
	var validator := WallLoopValidatorClass.new()

	# 직사각형 형태의 폐곡선 배치 (20x20 크기)
	# 북문(장안): (30, 20)
	# 남문(팔달): (30, 40)
	# 서문(화서): (20, 30)
	# 동문(창룡): (40, 30)
	grid.grid[20][30]["building"] = "gate"
	grid.grid[20][30]["gate_name"] = "장안문"

	grid.grid[40][30]["building"] = "gate"
	grid.grid[40][30]["gate_name"] = "팔달문"

	grid.grid[30][20]["building"] = "gate"
	grid.grid[30][20]["gate_name"] = "화서문"

	grid.grid[30][40]["building"] = "gate"
	grid.grid[30][40]["gate_name"] = "창룡문"

	# 북쪽 변: (20,20) ~ (40,20)
	for x in range(20, 41):
		if x != 30:
			grid.grid[20][x]["building"] = "wall"

	# 남쪽 변: (20,40) ~ (40,40)
	for x in range(20, 41):
		if x != 30:
			grid.grid[40][x]["building"] = "wall"

	# 서쪽 변: (20,20) ~ (20,40)
	for y in range(20, 41):
		if y != 30:
			grid.grid[y][20]["building"] = "wall"

	# 동쪽 변: (40,20) ~ (40,40)
	for y in range(20, 41):
		if y != 30:
			grid.grid[y][40]["building"] = "wall"

	var res: Dictionary = validator.validate_loop(grid, true)
	assert(bool(res.get("is_closed_loop", false)), "사대문이 사각형 성벽으로 연결되었으므로 폐곡선이어야 함")
	assert(int(res.get("validated_progress", 0)) == 100, "완공 진행도 100%여야 함")
	assert((res.get("broken_segments", []) as Array).is_empty(), "단절 구간이 없어야 함")
	print("  -> 임의 위치 사대문 사각 루프 폐곡선 100% 검증 통과!")

## 2. 공심돈, 포루, 봉돈, 수문 등의 부지(site) 타일이 성벽 사이에 끼어도 연결선이 단절되지 않음 검증
func _test_wall_connectors_include_structures() -> void:
	print("[검증 2] 성곽 부속 시설(공심돈, 포루, 봉돈, 수문 등) 관통 연결성 검증...")
	var grid := _create_test_grid()
	var validator := WallLoopValidatorClass.new()

	# 사대문 기본 배치
	grid.grid[20][30]["building"] = "gate"
	grid.grid[20][30]["gate_name"] = "장안문"
	grid.grid[40][30]["building"] = "gate"
	grid.grid[40][30]["gate_name"] = "팔달문"
	grid.grid[30][20]["building"] = "gate"
	grid.grid[30][20]["gate_name"] = "화서문"
	grid.grid[30][40]["building"] = "gate"
	grid.grid[30][40]["gate_name"] = "창룡문"

	for x in range(20, 41):
		if x != 30:
			grid.grid[20][x]["building"] = "wall"
		if x != 30:
			grid.grid[40][x]["building"] = "wall"
	for y in range(20, 41):
		if y != 30:
			grid.grid[y][20]["building"] = "wall"
		if y != 30:
			grid.grid[y][40]["building"] = "wall"

	# 동쪽 성벽 중간(40, 25)에 동북공심돈과 공심돈 사이트 타일 배치
	grid.grid[25][40]["building"] = "gongsimdon"
	grid.grid[26][40]["building"] = "gongsimdon_site"
	# 동쪽 성벽 중간(40, 35)에 포루와 포루 사이트 타일 배치
	grid.grid[35][40]["building"] = "poru"
	grid.grid[36][40]["building"] = "poru_site"

	var res: Dictionary = validator.validate_loop(grid, true)
	assert(bool(res.get("is_closed_loop", false)), "공심돈과 포루 사이트 타일이 있어도 폐곡선이어야 함")
	print("  -> 성곽 부속 시설 및 사이트 타일 포함 폐곡선 무결성 검증 통과!")

## 3. 대역사 기본 타일 목록에 성벽이 없어도 미완성 지점으로 잡히지 않음 검증
func _test_unconnected_points_no_hardcoded_targets() -> void:
	print("[검증 3] find_unconnected_wall_points 하드코딩 제거 및 실제 단절 검증...")
	var grid := _create_test_grid()
	var validator := WallLoopValidatorClass.new()

	# 폐곡선이 완성된 상태에서는 대역사 기본 타일에 성벽이 없어도 미완성 지점이 0개여야 함
	grid.grid[20][30]["building"] = "gate"
	grid.grid[20][30]["gate_name"] = "장안문"
	grid.grid[40][30]["building"] = "gate"
	grid.grid[40][30]["gate_name"] = "팔달문"
	grid.grid[30][20]["building"] = "gate"
	grid.grid[30][20]["gate_name"] = "화서문"
	grid.grid[30][40]["building"] = "gate"
	grid.grid[30][40]["gate_name"] = "창룡문"

	for x in range(20, 41):
		if x != 30: grid.grid[20][x]["building"] = "wall"
		if x != 30: grid.grid[40][x]["building"] = "wall"
	for y in range(20, 41):
		if y != 30: grid.grid[y][20]["building"] = "wall"
		if y != 30: grid.grid[y][40]["building"] = "wall"

	var unconn: Array[Vector2i] = validator.find_unconnected_wall_points(grid)
	assert(unconn.is_empty(), "폐곡선 완성 상태에서는 하드코딩된 대역사 타일과 무관하게 미완성 지점이 0개여야 함 (실제: %d곳)" % unconn.size())
	print("  -> 폐곡선 완공 시 미완성 지점 0곳 검증 완료!")

	# 성벽 하나를 끊어서 실제 단절을 만들었을 때만 열린 끝단이 검출되는지 검증
	grid.grid[20][25]["building"] = "" # 북서쪽 성벽 1칸 구멍
	var unconn_broken: Array[Vector2i] = validator.find_unconnected_wall_points(grid)
	assert(not unconn_broken.is_empty(), "성벽에 실제 구멍(단절)이 생겼으므로 열린 끝단이 검출되어야 함")
	assert(Vector2i(24, 20) in unconn_broken or Vector2i(26, 20) in unconn_broken, "구멍 양옆 성벽이 단절 지점으로 검출되어야 함")
	print("  -> 실제 성벽 단절 지점만 정밀 검출 검증 완료 (검출: %d곳)!" % unconn_broken.size())

## 4. 긴급 땜질 상태 제어 및 불필요 시 비활성화 검증
func _test_emergency_repair_state_and_disable() -> void:
	print("[검증 4] 긴급 땜질 불필요 시 비활성화 및 안전 가드 검증...")
	var sim := SimulationCoreClass.new()
	sim.gold = 50000
	sim.rice = 50000
	var siege := SiegeSystemClass.new()
	siege.sim = sim

	# 피해가 0인 상태
	CityStats.set_fortress_defense_power(1000)
	sim.defense_fatigue = 0
	CityStats.apply_defense_damage(-CityStats.get_defense_damage_taken(), sim)

	var damage_taken: int = CityStats.get_defense_damage_taken()
	var fatigue: int = sim.defense_fatigue
	var actual_damage: int = maxi(damage_taken, fatigue)
	assert(actual_damage == 0, "초기 침략 피해는 0이어야 함")

	# 피해가 0일 때 emergency_repair 호출 시 자원 소모 없이 차단되어야 함
	var old_gold: int = sim.gold
	var old_rice: int = sim.rice
	var res_zero: Dictionary = siege.emergency_repair()
	assert(not bool(res_zero.get("success", false)), "피해가 없을 때는 긴급 땜질이 실행되지 않아야 함")
	assert(sim.gold == old_gold and sim.rice == old_rice, "자원이 소모되지 않아야 함")
	print("  -> 피해 0일 때 긴급 땜질 불필요 안전 차단 완료!")

	# 침략 피해 발생 상태 시뮬레이션
	CityStats.fortress_max_defense_power = 1000
	CityStats.apply_defense_damage(200, sim)
	var damage_after: int = CityStats.get_defense_damage_taken()
	assert(damage_after > 0, "피해 발생 후 damage_taken이 0보다 커야 함")

	# 피해가 있을 때는 정상적으로 회복 및 자원 소모
	var res_repair: Dictionary = siege.emergency_repair()
	assert(bool(res_repair.get("success", false)), "피해가 있을 때는 긴급 땜질이 정상 실행되어야 함")
	assert(sim.gold < old_gold and sim.rice < old_rice, "자원이 정상 소모되어야 함")
	print("  -> 침략 피해 발생 시 긴급 땜질 정상 복구 검증 완료!")
