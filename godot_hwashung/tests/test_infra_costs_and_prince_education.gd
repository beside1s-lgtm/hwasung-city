extends SceneTree

const DifficultyManagerClass = preload("res://scripts/DifficultyManager.gd")
const FortressWallManagerClass = preload("res://scripts/FortressWallManager.gd")
const BuildingManagerClass = preload("res://scripts/BuildingManager.gd")
const CrownPrinceEducationManagerClass = preload("res://scripts/CrownPrinceEducationManager.gd")
const TombVisitManagerClass = preload("res://scripts/TombVisitManager.gd")
const GameGridClass = preload("res://scripts/GameGrid.gd")
const SimulationCoreClass = preload("res://scripts/SimulationCore.gd")
const CourtSystemClass = preload("res://scripts/CourtSystem.gd")
const QuestSystemClass = preload("res://scripts/QuestSystem.gd")

func _init() -> void:
	print("=== [테스트 시작] 성곽·성문 인프라 소모량, 세자 교육 게이지, 군사/참배 비용 및 난이도 배율·보상 검증 ===")
	call_deferred("_run_tests")

func _create_test_grid() -> GameGrid:
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
	_test_wall_and_gate_costs()
	_test_gov_cell_maintenance()
	_test_crown_prince_education_gauge_and_freeze()
	_test_military_drill_and_tomb_visit_costs()
	_test_quest_reward_isolation_by_difficulty()

	print("=== [테스트 완료] 성곽/성문 인프라, 세자 교육, 군사/참배, 난이도 배율 및 보상 전 항목 100% 통과! ===")
	quit(0)

## 1. 성곽 1칸 건설(1,000냥/500석), 보수(500냥/250석) 및 성문(2,000냥/1,500석) 난이도 배율 검증
func _test_wall_and_gate_costs() -> void:
	print("[검증 1] 성곽 건설/보수 및 성문 건립 비용 난이도 배율 검증...")

	# 1) 쉬움 (EASY: x1.0)
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.EASY)
	assert(DifficultyManagerClass.get_cost_multiplier() == 1.0, "쉬움 배율 1.0 오류")

	var wall_cost_easy: Dictionary = FortressWallManagerClass.get_wall_build_cost()
	assert(wall_cost_easy["gold"] == 1000 and wall_cost_easy["rice"] == 500, "쉬움 성곽 건설비 오류: %s" % str(wall_cost_easy))

	var wall_rep_easy: Dictionary = FortressWallManagerClass.get_wall_repair_cost()
	assert(wall_rep_easy["gold"] == 500 and wall_rep_easy["rice"] == 250, "쉬움 성곽 보수비 오류: %s" % str(wall_rep_easy))

	var gate_cost_easy: Dictionary = FortressWallManagerClass.get_gate_build_cost()
	assert(gate_cost_easy["gold"] == 2000 and gate_cost_easy["rice"] == 1500, "쉬움 성문 건립비 오류: %s" % str(gate_cost_easy))

	# 2) 보통 (NORMAL: x2.0)
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.NORMAL)
	assert(DifficultyManagerClass.get_cost_multiplier() == 2.0, "보통 배율 2.0 오류")

	var wall_cost_norm: Dictionary = FortressWallManagerClass.get_wall_build_cost()
	assert(wall_cost_norm["gold"] == 2000 and wall_cost_norm["rice"] == 1000, "보통 성곽 건설비(2배) 오류: %s" % str(wall_cost_norm))

	var wall_rep_norm: Dictionary = FortressWallManagerClass.get_wall_repair_cost()
	assert(wall_rep_norm["gold"] == 1000 and wall_rep_norm["rice"] == 500, "보통 성곽 보수비(2배) 오류: %s" % str(wall_rep_norm))

	var gate_cost_norm: Dictionary = FortressWallManagerClass.get_gate_build_cost()
	assert(gate_cost_norm["gold"] == 4000 and gate_cost_norm["rice"] == 3000, "보통 성문 건립비(2배) 오류: %s" % str(gate_cost_norm))

	# 3) 어려움 (HARD: x3.0)
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.HARD)
	assert(DifficultyManagerClass.get_cost_multiplier() == 3.0, "어려움 배율 3.0 오류")

	var wall_cost_hard: Dictionary = FortressWallManagerClass.get_wall_build_cost()
	assert(wall_cost_hard["gold"] == 3000 and wall_cost_hard["rice"] == 1500, "어려움 성곽 건설비(3배) 오류: %s" % str(wall_cost_hard))

	var wall_rep_hard: Dictionary = FortressWallManagerClass.get_wall_repair_cost()
	assert(wall_rep_hard["gold"] == 1500 and wall_rep_hard["rice"] == 750, "어려움 성곽 보수비(3배) 오류: %s" % str(wall_rep_hard))

	var gate_cost_hard: Dictionary = FortressWallManagerClass.get_gate_build_cost()
	assert(gate_cost_hard["gold"] == 6000 and gate_cost_hard["rice"] == 4500, "어려움 성문 건립비(3배) 오류: %s" % str(gate_cost_hard))

	# 4) GameGrid get_tool_cost 연동 검증
	var grid := _create_test_grid()
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.EASY)
	var tool_wall_easy: Dictionary = grid.get_tool_cost("wall", 0, 0)
	assert(tool_wall_easy["gold"] == 1000 and tool_wall_easy["rice"] == 500, "GameGrid 쉬움 성곽 비용 불일치")
	var tool_gate_easy: Dictionary = grid.get_tool_cost("gate", 0, 0)
	assert(tool_gate_easy["gold"] == 2000 and tool_gate_easy["rice"] == 1500, "GameGrid 쉬움 성문 비용 불일치")

	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.NORMAL)
	var tool_wall_norm: Dictionary = grid.get_tool_cost("wall", 0, 0)
	assert(tool_wall_norm["gold"] == 2000 and tool_wall_norm["rice"] == 1000, "GameGrid 보통 성곽 2배 비용 불일치")
	var tool_gate_norm: Dictionary = grid.get_tool_cost("gate", 0, 0)
	assert(tool_gate_norm["gold"] == 4000 and tool_gate_norm["rice"] == 3000, "GameGrid 보통 성문 2배 비용 불일치")

	# 5) 성곽 타일 1칸 파손 보수 로직 실행 검증
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.EASY)
	grid.grid[5][5]["building"] = "wall"
	grid.grid[5][5]["is_damaged"] = true
	grid.grid[5][5]["wall_health"] = 40

	var sim := SimulationCoreClass.new()
	sim.gold = 5000
	sim.rice = 5000
	var rep_res: Dictionary = FortressWallManagerClass.repair_wall_tile(grid, 5, 5, sim)
	assert(bool(rep_res["success"]) == true, "성곽 타일 보수 실패")
	assert(sim.gold == 4500 and sim.rice == 4750, "보수 비용(금 500, 곡 250) 차감 오류: gold=%d, rice=%d" % [sim.gold, sim.rice])
	assert(bool(grid.grid[5][5]["is_damaged"]) == false, "보수 후 damaged 플래그 해제 실패")
	assert(int(grid.grid[5][5]["wall_health"]) == 100, "보수 후 체력 100 복구 실패")

	print("  -> 성곽 축성/보수 및 성문 건립 비용 100% 검증 통과!")

## 2. 관공서 타일 1칸당 매 턴 200냥 유지비 시스템 및 O(1) 캐시 검증
func _test_gov_cell_maintenance() -> void:
	print("[검증 2] 관공서 셀 면적 비례 턴당 200냥 유지비 검증...")
	var sim := SimulationCoreClass.new()
	sim.population = 0 # 인구 조세 0으로 순수 관청 유지비만 정밀 측정
	sim.tax_rate_market = 0
	sim.tax_rate_land = 0
	sim.tax_rate_military = 0

	# 1) 쉬움 난이도: 칸당 200냥
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.EASY)

	# 2x2 관아 = 4칸 -> 턴당 800냥
	sim.total_gov_cell_count = 4
	sim.gold = 10000
	sim.rice = 10000
	sim._process_monthly_budget()
	assert(sim.gold == 9200, "관아(4칸) 턴당 유지비 800냥 차감 실패: 현재 gold=%d" % sim.gold)

	# 7x7 화성행궁 = 49칸 -> 턴당 9,800냥
	sim.total_gov_cell_count = 49
	sim.gold = 20000
	sim._process_monthly_budget()
	assert(sim.gold == 10200, "행궁(49칸) 턴당 유지비 9,800냥 차감 실패: 현재 gold=%d" % sim.gold)

	# 2) 보통 난이도 (2배): 칸당 400냥
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.NORMAL)
	sim.total_gov_cell_count = 4 # 관아 4칸 -> 턴당 1,600냥
	sim.gold = 10000
	sim._process_monthly_budget()
	assert(sim.gold == 8400, "보통 난이도 관아 유지비(1,600냥) 차감 실패: 현재 gold=%d" % sim.gold)

	# 3) 어려움 난이도 (3배): 칸당 600냥
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.HARD)
	sim.total_gov_cell_count = 4 # 관아 4칸 -> 턴당 2,400냥
	sim.gold = 10000
	sim._process_monthly_budget()
	assert(sim.gold == 7600, "어려움 난이도 관아 유지비(2,400냥) 차감 실패: 현재 gold=%d" % sim.gold)

	# 4) 그리드 관공서 셀 자동 카운팅 검증
	var grid := _create_test_grid()
	grid.grid[1][1]["building"] = "gwana"
	grid.grid[1][2]["building"] = "gwana"
	grid.grid[2][1]["building"] = "gwana"
	grid.grid[2][2]["building"] = "gwana"
	var counted: int = BuildingManagerClass.count_gov_cells(grid)
	assert(counted == 4, "그리드 관아 셀 4칸 집계 실패: %d" % counted)
	sim.recalculate_gov_cell_count(grid)
	assert(sim.total_gov_cell_count == 4, "SimulationCore 셀 수 캐싱 동기화 실패")

	print("  -> 관공서 면적 유지비 200냥 시스템 검증 통과!")

## 3. 세자 교육 게이지 시스템, 학문력 연동(1%~10%), 턴당 2,000냥 지속 소모 및 재정 부족 동결 검증
func _test_crown_prince_education_gauge_and_freeze() -> void:
	print("[검증 3] 세자 교육 게이지 및 국고 부족 안전 동결 검증...")
	var sim := SimulationCoreClass.new()
	var prince_mgr := CrownPrinceEducationManagerClass.new()
	prince_mgr.progress = 50.0

	# 1) 쉬움 난이도: 턴당 2,000냥
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.EASY)
	sim.gold = 10000
	var start_res: Dictionary = prince_mgr.start_education(sim)
	assert(bool(start_res["success"]) == true, "세자 교육 시작 실패")
	assert(prince_mgr.status == CrownPrinceEducationManagerClass.EducationStatus.ACTIVE, "활성 상태 진입 실패")

	# 학문력 0점: 턴당 1.0% 상승, 금 2,000냥 차감
	var turn1: Dictionary = prince_mgr.process_turn(sim, 0)
	assert(is_equal_approx(float(turn1["step"]), 1.0), "학문력 0점 시 상승률 1.0%% 불일치: %f" % float(turn1["step"]))
	assert(is_equal_approx(prince_mgr.progress, 51.0), "진척도 51.0%% 불일치: %f" % prince_mgr.progress)
	assert(sim.gold == 8000, "턴당 2,000냥 차감 실패: 현재 gold=%d" % sim.gold)

	# 학문력 100점: 턴당 10.0% 상승, 금 2,000냥 차감
	var turn2: Dictionary = prince_mgr.process_turn(sim, 100)
	assert(is_equal_approx(float(turn2["step"]), 10.0), "학문력 100점 시 상승률 10.0%% 불일치: %f" % float(turn2["step"]))
	assert(is_equal_approx(prince_mgr.progress, 61.0), "진척도 61.0%% 불일치: %f" % prince_mgr.progress)
	assert(sim.gold == 6000, "턴당 2,000냥 차감 실패: 현재 gold=%d" % sim.gold)

	# 학문력 50점: 1 + 4.5 = 5.5% 상승
	var turn3: Dictionary = prince_mgr.process_turn(sim, 50)
	assert(is_equal_approx(float(turn3["step"]), 5.5), "학문력 50점 시 상승률 5.5%% 불일치: %f" % float(turn3["step"]))
	assert(is_equal_approx(prince_mgr.progress, 66.5), "진척도 66.5%% 불일치: %f" % prince_mgr.progress)

	# 2) 보통 난이도 (2배): 턴당 4,000냥
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.NORMAL)
	sim.gold = 10000
	var turn4: Dictionary = prince_mgr.process_turn(sim, 100)
	assert(sim.gold == 6000, "보통 난이도 4,000냥 차감 실패: 현재 gold=%d" % sim.gold)

	# 3) 국고 부족 시 교육 강제 취소 없이 일시 동결 (PAUSED_NO_FUNDS) 검증
	sim.gold = 1000 # 4,000냥 미달
	var prev_progress: float = prince_mgr.progress
	var turn_fail: Dictionary = prince_mgr.process_turn(sim, 100)
	assert(prince_mgr.status == CrownPrinceEducationManagerClass.EducationStatus.PAUSED_NO_FUNDS, "재정 부족 시 동결 상태 전환 실패")
	assert(is_equal_approx(prince_mgr.progress, prev_progress), "동결 시 게이지가 보존되지 않고 변경됨: %f vs %f" % [prince_mgr.progress, prev_progress])
	assert(sim.gold == 1000, "동결 시 국고 차감되지 않아야 함")

	# 4) 국고 재확보 시 자동 재개 검증
	sim.gold = 10000
	var turn_recover: Dictionary = prince_mgr.process_turn(sim, 100)
	assert(prince_mgr.status == CrownPrinceEducationManagerClass.EducationStatus.ACTIVE, "재정 회복 후 활성 상태 복귀 실패")
	assert(prince_mgr.progress > prev_progress, "재개 후 게이지 상승 실패")
	assert(sim.gold == 6000, "재개 후 정상 차감 실패")

	print("  -> 세자 교육 게이지 및 국고 부족 안전 동결 FSM 검증 통과!")

## 4. 군사훈련(야조/연무대) 및 현륭원 참배 비용(금 2,000냥, 곡 1,000석) 검증
func _test_military_drill_and_tomb_visit_costs() -> void:
	print("[검증 4] 군사훈련 및 현륭원 참배 비용 검증...")
	var sim := SimulationCoreClass.new()
	var grid := _create_test_grid()
	grid.grid[6][29]["building"] = "seojangdae" # 서장대 완공 타일

	# 1) 쉬움 난이도: 1회당 금 2,000냥, 곡 1,000석
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.EASY)
	var drill_cost_easy: Dictionary = DifficultyManagerClass.get_military_drill_cost()
	assert(drill_cost_easy["gold"] == 2000 and drill_cost_easy["rice"] == 1000, "쉬움 훈련비 불일치")
	var tomb_cost_easy: Dictionary = DifficultyManagerClass.get_tomb_visit_cost()
	assert(tomb_cost_easy["gold"] == 2000 and tomb_cost_easy["rice"] == 1000, "쉬움 참배비 불일치")

	# 서장대 야조 실행 및 차감 검증
	sim.gold = 5000
	sim.rice = 5000
	sim.seojangdae_drill_cd_months = 0
	var drill_res: Dictionary = sim.execute_seojangdae_drill(grid, null)
	assert(bool(drill_res["success"]) == true, "서장대 야조 실행 실패")
	assert(sim.gold == 3000 and sim.rice == 4000, "서장대 야조 비용(금 2,000, 곡 1,000) 차감 오류: gold=%d, rice=%d" % [sim.gold, sim.rice])

	# 현륭원 참배 실행 및 차감 검증
	var court := CourtSystemClass.new()
	court.setup(sim)
	court.hyoryungwon["visited"] = false
	var tomb_res: Dictionary = TombVisitManagerClass.execute_tomb_visit(court, sim)
	assert(bool(tomb_res["success"]) == true, "현륭원 참배 실패")
	assert(sim.gold == 1000 and sim.rice == 3000, "현륭원 참배 비용(금 2,000, 곡 1,000) 차감 오류: gold=%d, rice=%d" % [sim.gold, sim.rice])
	assert(court.hyeonryungwon_visits >= 1, "참배 횟수 미반영")

	# 2) 보통 난이도 (2배): 금 4,000냥, 곡 2,000석
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.NORMAL)
	var drill_cost_norm: Dictionary = DifficultyManagerClass.get_military_drill_cost()
	assert(drill_cost_norm["gold"] == 4000 and drill_cost_norm["rice"] == 2000, "보통 훈련비(2배) 불일치")
	var tomb_cost_norm: Dictionary = DifficultyManagerClass.get_tomb_visit_cost()
	assert(tomb_cost_norm["gold"] == 4000 and tomb_cost_norm["rice"] == 2000, "보통 참배비(2배) 불일치")

	# 자원 부족 시 차단 검증
	sim.gold = 3000 # 4,000냥 부족
	sim.rice = 1500 # 2,000석 부족
	court.hyoryungwon["visited"] = false
	var fail_tomb: Dictionary = TombVisitManagerClass.execute_tomb_visit(court, sim)
	assert(bool(fail_tomb["success"]) == false, "자원 부족 시 참배 차단 실패")

	print("  -> 군사훈련 및 현륭원 참배 비용 검증 통과!")

## 5. 쉬움 난이도 김판관 과업 보상 상향(금 1,000냥, 곡 1,000석) 및 보통/어려움 격리 검증
func _test_quest_reward_isolation_by_difficulty() -> void:
	print("[검증 5] 김판관 과업 보상 쉬움 난이도 상향 및 보통/어려움 격리 검증...")
	var sim := SimulationCoreClass.new()
	var grid := _create_test_grid()
	var court := CourtSystemClass.new()
	court.setup(sim)
	var quest_sys := QuestSystemClass.new()
	quest_sys.setup(grid, sim, court)

	# 1) 쉬움 (EASY): 과업 보상이 금 1,000냥, 곡식 1,000석으로 상향 지급
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.EASY)
	sim.gold = 0
	sim.rice = 0
	# 제1교지: 화성행궁 건립 완료 충족
	grid.grid[10][10]["building"] = "haenggung"
	quest_sys.check_current_quest()
	assert(sim.gold == 1000 and sim.rice == 1000, "쉬움 과업 보상(금 1000, 곡 1000) 상향 미적용: gold=%d, rice=%d" % [sim.gold, sim.rice])

	# 2) 보통 (NORMAL): 기존 보상 그대로 유지 (제2교지 삼남대로: 금 150, 쌀 50)
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.NORMAL)
	sim.gold = 0
	sim.rice = 0
	# 제2교지 조건: 도로 5칸
	for i in range(5):
		grid.grid[15][10 + i]["building"] = "road"
		grid.grid[15][10 + i]["terrain"] = "plain"
	quest_sys.check_current_quest()
	assert(sim.gold == 150 and sim.rice == 50, "보통 과업 보상 기존 밸런스(금 150, 곡 50) 보존 실패: gold=%d, rice=%d" % [sim.gold, sim.rice])

	# 3) 어려움 (HARD): 기존 보상 그대로 유지
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.HARD)
	var base_reward: Dictionary = {"gold": 200, "rice": 50}
	var hard_reward: Dictionary = DifficultyManagerClass.get_quest_reward(base_reward)
	assert(hard_reward["gold"] == 200 and hard_reward["rice"] == 50, "어려움 과업 보상 기존 유지 실패: %s" % str(hard_reward))

	print("  -> 김판관 과업 보상 쉬움 상향 및 보통/어려움 격리 검증 통과!")
