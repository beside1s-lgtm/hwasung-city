extends SceneTree

const GameGridClass = preload("res://scripts/GameGrid.gd")
const SimulationCoreClass = preload("res://scripts/SimulationCore.gd")
const CourtSystemClass = preload("res://scripts/CourtSystem.gd")
const SiegeSystemClass = preload("res://scripts/SiegeSystem.gd")
const CitizenManagerClass = preload("res://scripts/CitizenManager.gd")

func _init() -> void:
	print("=== [테스트 시작] 성 방호력 턴 리셋 차단 및 수축 대역사 정상 완공 생명주기 검증 ===")
	call_deferred("_run_tests")

func _create_test_grid() -> GameGridClass:
	var g := GameGridClass.new()
	g.size = 64
	g.grid = []
	for y: int in range(64):
		var row: Array = []
		for x: int in range(64):
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
	_test_court_turn_defense_preserve()
	_test_grand_repair_turns_and_completion()
	_test_high_defense_no_drop()
	_test_save_load_repair_bonus_integrity()

	print("=== [테스트 완료] 성 방호력 보수 및 수축 대역사 버그 수정 100% 검증 통과! ===")
	quit(0)

## 1. CourtSystem 턴 진행 시 성 방호력이 50으로 덮어써지지 않고 유지되는지 검증
func _test_court_turn_defense_preserve() -> void:
	print("[검증 1] CourtSystem 턴 전환 시 CityStats 방호력 유지 및 50 덮어쓰기 차단 검증...")
	var sim := SimulationCoreClass.new()
	var court := CourtSystemClass.new()
	court.setup(sim)

	CityStats.reset_to_defaults()
	var grid := _create_test_grid()
	grid.fortress_progress = 100
	CityStats.recalculate_defense_and_attack(grid, sim)

	var before_def: int = CityStats.get_fortress_defense_power()
	assert(before_def >= 50, "기본 방호력 산출 확인")

	# 수축 보수 등으로 방호력이 150으로 상승한 상태
	CityStats.add_repair_bonus(100, sim)
	var elevated_def: int = CityStats.get_fortress_defense_power()
	assert(elevated_def == before_def + 100, "방호력 증강 확인")
	assert(CityStats.get_defense_damage_taken() == 0, "피해도 0 확인")

	# 턴 진행 시뮬레이션
	court._on_turn(2, 1, 1789)

	var after_def: int = CityStats.get_fortress_defense_power()
	var dmg_taken: int = CityStats.get_defense_damage_taken()

	assert(after_def == elevated_def, "턴 진행 후에도 방호력이 50으로 추락하지 않고 유지되어야 함 (실제: %d)" % after_def)
	assert(dmg_taken == 0, "턴 진행 후에도 억지 피해도가 발생하지 않아야 함 (실제: %d)" % dmg_taken)
	assert(court.get_fortress_defense_power() == elevated_def, "CourtSystem 동기화 확인")
	print("  -> [PASS] CourtSystem 턴 진행 시 방호력 50 리셋 차단 성공!")

## 2. 수축 대역사 발주 시 턴당 turns_left 차감 및 완공 라이프사이클 검증
func _test_grand_repair_turns_and_completion() -> void:
	print("[검증 2] 수축 대역사 발주, turns_left 차감, 자원 소모 및 완공 FSM 검증...")
	var sim := SimulationCoreClass.new()
	var grid := _create_test_grid()
	var citizens := CitizenManagerClass.new()
	var court := CourtSystemClass.new()
	court.setup(sim)

	var siege := SiegeSystemClass.new()
	siege.setup(grid, sim, citizens, court)

	sim.gold = 5000
	sim.rice = 5000
	CityStats.reset_to_defaults()
	grid.fortress_progress = 100
	CityStats.recalculate_defense_and_attack(grid, sim)

	# 피해 발생 (피해도 30)
	CityStats.apply_defense_damage(30, sim)
	assert(CityStats.get_defense_damage_taken() == 30, "피해도 30 설정")

	# 수축 대역사 발주
	var start_res: Dictionary = siege.start_grand_repair()
	assert(bool(start_res.get("success", false)), "수축 대역사 발주 성공")
	assert(bool(siege.repair_state.get("active", false)), "수축 대역사 활성화")
	assert(int(siege.repair_state.get("turns_left", 0)) == 6, "공기 6턴 설정")
	assert(bool(sim.repair_state.get("active", false)), "sim.repair_state 동기화")

	# 1턴 진행 (복구 100~150으로 피해도 30 완치)
	siege._on_turn(2, 1, 1789)

	# 피해도가 0이 되었으므로 대역사가 정상 완공되어야 함!
	assert(CityStats.get_defense_damage_taken() == 0, "피해도 완치 확인")
	assert(bool(siege.repair_state.get("active", false)) == false, "피해 복구 완료 시 수축 대역사가 자동 완공되어야 함")
	assert(bool(sim.repair_state.get("active", false)) == false, "sim 상태 완공 동기화")

	print("  -> [PASS] 수축 대역사 turns_left 정상 차감 및 피해 복구 시 자동 완공 FSM 검증 성공!")

## 3. 고방호력(사용자 제보 상황: 9000대)에서 다음 턴 진행 시 500 추락 방지 검증
func _test_high_defense_no_drop() -> void:
	print("[검증 3] 9000대 방호력에서 턴 진행 시 500 추락 방지 및 방치 패널티 방지 검증...")
	var sim := SimulationCoreClass.new()
	var grid := _create_test_grid()
	var citizens := CitizenManagerClass.new()
	var court := CourtSystemClass.new()
	court.setup(sim)

	var siege := SiegeSystemClass.new()
	siege.setup(grid, sim, citizens, court)

	CityStats.reset_to_defaults()
	grid.fortress_progress = 100
	CityStats.defense_repair_bonus = 9450 # 사용자 데이터 상태 시뮬레이션
	CityStats.recalculate_defense_and_attack(grid, sim)
	siege._def_cache = -1 # 캐시 무효화 (단위 테스트 밀리초 실행 대응)

	var max_def: int = CityStats.get_max_defense_power()
	var cur_def: int = CityStats.get_fortress_defense_power()
	assert(max_def >= 9450, "최대 방호력 9450 이상 확인")
	assert(cur_def >= 4000, "현재 방호력 고수치 확인")
	assert(CityStats.get_defense_damage_taken() == 0, "피해도 0 확인")

	var initial_loyalty: int = sim.loyalty

	# 턴 진행
	court._on_turn(5, 0, 1790)
	siege._on_turn(5, 0, 1790)

	var after_def: int = CityStats.get_fortress_defense_power()
	var after_dmg: int = CityStats.get_defense_damage_taken()

	assert(after_def == cur_def, "고방호력 상태에서 턴 진행 후에도 방호력이 떨어지지 않아야 함 (실제: %d vs 예상: %d)" % [after_def, cur_def])
	assert(after_dmg == 0, "피해도가 0이어야 함 (실제: %d)" % after_dmg)
	assert(sim.loyalty >= initial_loyalty, "방호력이 충분하므로 방치 패널티(민심 감소)가 없어야 함")
	print("  -> [PASS] 고방호력 9000대 상태에서 턴 진행 시 방호력 보존 및 방치 경고 차단 성공!")

## 4. SaveSystem 직렬화/역직렬화 시 defense_repair_bonus 및 방호력 보존 검증
func _test_save_load_repair_bonus_integrity() -> void:
	print("[검증 4] SaveSystem 및 CityStats 직렬화/역직렬화 데이터 무결성 검증...")
	CityStats.reset_to_defaults()
	CityStats.defense_repair_bonus = 350
	CityStats.fortress_max_defense_power = 500
	CityStats.fortress_defense_power = 480
	CityStats.defense_damage_taken = 20

	var serialized: Dictionary = CityStats.serialize()
	assert(int(serialized.get("defense_repair_bonus", 0)) == 350, "보수 누적치 직렬화 일치")
	assert(int(serialized.get("defense_damage_taken", 0)) == 20, "피해도 직렬화 일치")
	assert(int(serialized.get("fortress_max_defense_power", 0)) == 500, "최대 방호력 직렬화 일치")

	CityStats.reset_to_defaults()
	assert(CityStats.get_defense_repair_bonus() == 0, "리셋 확인")

	CityStats.deserialize(serialized)
	assert(CityStats.get_defense_repair_bonus() == 350, "보수 누적치 역직렬화 복원")
	assert(CityStats.get_defense_damage_taken() == 20, "피해도 역직렬화 복원")
	assert(CityStats.get_max_defense_power() == 500, "최대 방호력 역직렬화 복원")
	assert(CityStats.get_fortress_defense_power() == 480, "현재 방호력 역직렬화 복원")
	print("  -> [PASS] SaveSystem 및 CityStats 직렬화/역직렬화 무결성 검증 성공!")
