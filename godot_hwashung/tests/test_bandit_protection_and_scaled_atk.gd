extends SceneTree

const BanditManagerClass = preload("res://scripts/BanditManager.gd")
const CitizenManagerClass = preload("res://scripts/CitizenManager.gd")
const SimulationCoreClass = preload("res://scripts/SimulationCore.gd")
const GameGridClass = preload("res://scripts/GameGrid.gd")

func _init() -> void:
	print("=== [테스트 시작] 도적 초반 2년 보호기간 및 민심 연동 공격력(300~600) 검증 ===")
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
	_test_early_game_protection()
	_test_bandit_atk_scaling_by_loyalty()
	_test_start_raid_initial_attack()

	print("=== [테스트 완료] 도적 초반 보호기간 및 민심 연동 공격력 전 항목 100% 통과! ===")
	quit(0)

## 1. 초반 2년(8턴) 도적 침략 및 소굴/상단약탈 보호기간 검증
func _test_early_game_protection() -> void:
	print("[검증 1] 초반 2년(8턴, year < 1791) 보호기간 검증...")
	var sim := SimulationCoreClass.new()
	var grid := _create_test_grid()
	var b_mgr := BanditManagerClass.new()
	b_mgr.init_outer_tiles(grid)

	# 1) 1789년(1년차), turn 4: 보호기간
	sim.current_year = 1789
	sim.turn = 4
	sim.loyalty = 20
	var res1: Dictionary = b_mgr.process_turn(sim, grid)
	assert(not res1.get("camp_spawned", false), "1789년에는 도적 소굴이 스폰되지 않아야 함")
	assert(b_mgr.camps.is_empty(), "소굴 수가 0이어야 함")
	assert(BanditManagerClass.calculate_bandit_spawn_chance(sim, true) == 0.0, "스폰 확률 0%여야 함")
	var raid1: Dictionary = BanditManagerClass.apply_caravan_raid(sim)
	assert(raid1.get("protected", false) == true, "상단 약탈이 보호되어야 함")

	# 2) 1790년(2년차), turn 8: 보호기간 유지
	sim.current_year = 1790
	sim.turn = 8
	var res2: Dictionary = b_mgr.process_turn(sim, grid)
	assert(not res2.get("camp_spawned", false), "turn 8까지는 보호기간 유지")
	assert(BanditManagerClass.calculate_bandit_spawn_chance(sim, true) == 0.0, "turn 8 스폰 확률 0%")

	# 3) CitizenManager의 도적 침략 루프 검사
	var citizens := CitizenManagerClass.new()
	citizens.sim = sim
	citizens.grid = grid
	citizens._bandit_raid_timer = 0.0
	citizens._manage_bandits(0.1)
	assert(not citizens._bandit_raid_active, "초반 2년 내에는 CitizenManager에서도 도적 침략이 발동되지 않아야 함")

	print("  - 초반 2년(8턴) 도적 소굴·상단약탈·침공 완전 차단 검증 통과")

## 2. 민심 연동 도적 공격력 산출 공식 검증 (첫 공격력 300 시작, 민심 악화 시 점차 증가)
func _test_bandit_atk_scaling_by_loyalty() -> void:
	print("[검증 2] 민심 연동 공격력 공식 (300 시작 ~ 최대 600) 검증...")
	var sim := SimulationCoreClass.new()

	# 1) 민심 100 (최고치): 첫 공격력 300
	sim.loyalty = 100
	var atk_100: int = BanditManagerClass.calculate_bandit_siege_atk(sim)
	assert(atk_100 == 300, "민심 100일 때 도적 공격력은 300이어야 함 (실제: %d)" % atk_100)

	# 2) 민심 80: 300 + (20 * 3) = 360
	sim.loyalty = 80
	var atk_80: int = BanditManagerClass.calculate_bandit_siege_atk(sim)
	assert(atk_80 == 360, "민심 80일 때 도적 공격력은 360이어야 함 (실제: %d)" % atk_80)

	# 3) 민심 50 (절반): 300 + (50 * 3) = 450
	sim.loyalty = 50
	var atk_50: int = BanditManagerClass.calculate_bandit_siege_atk(sim)
	assert(atk_50 == 450, "민심 50일 때 도적 공격력은 450이어야 함 (실제: %d)" % atk_50)

	# 4) 민심 0 (최악): 300 + (100 * 3) = 600 (상한선)
	sim.loyalty = 0
	var atk_0: int = BanditManagerClass.calculate_bandit_siege_atk(sim)
	assert(atk_0 == 600, "민심 0일 때 도적 공격력은 최대 600이어야 함 (실제: %d)" % atk_0)

	# 5) sim == null일 때 기본값 300 반환
	var atk_null: int = BanditManagerClass.calculate_bandit_siege_atk(null)
	assert(atk_null == 300, "sim이 null일 때 기본 300 반환")

	print("  - 민심 100(300) -> 민심 80(360) -> 민심 50(450) -> 민심 0(600) 점진 스케일링 검증 통과")

## 3. start_raid 및 _start_bandit_raid 시 bandit_siege_atk 동기화 검증
func _test_start_raid_initial_attack() -> void:
	print("[검증 3] 침입 개시 시 도적 공격력 적용 검증...")
	var sim := SimulationCoreClass.new()
	var grid := _create_test_grid()
	var citizens := CitizenManagerClass.new()
	citizens.sim = sim
	citizens.grid = grid

	# 민심 90일 때 침입 개시 -> 300 + (10 * 3) = 330
	sim.loyalty = 90
	var b_mgr := BanditManagerClass.new()
	b_mgr.start_raid(sim, grid, citizens)
	assert(b_mgr.bandit_siege_atk == 330, "BanditManager 침공 공격력 330 검증 (실제: %d)" % b_mgr.bandit_siege_atk)
	b_mgr.finish_raid(true, sim, grid, citizens)

	# CitizenManager 침략 개시 -> _start_bandit_raid
	sim.loyalty = 70 # 300 + (30 * 3) = 390
	citizens._start_bandit_raid()
	assert(citizens._bandit_siege_atk == 390, "CitizenManager 침공 공격력 390 검증 (실제: %d)" % citizens._bandit_siege_atk)
	citizens._end_bandit_raid(true)

	print("  - BanditManager 및 CitizenManager 침입 시 민심 연동 공격력 적용 검증 통과")
