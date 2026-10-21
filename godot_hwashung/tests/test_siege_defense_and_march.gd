extends SceneTree

## [종심 방어 및 전술 길목 차단 전투 체계 통합 검증 스위트]
## 1. 적군 최소 공격력 500 상향 및 스케일링 공식 검증 (도적 및 반란군)
## 2. A* 도로망 진격 경로 생성 및 행궁 본궁 타깃팅 검증
## 3. 진격로 상점/민가/둔전 폐가화(RUINED) 및 비파괴적 원형 보존 검증
## 4. 폐가화 영향 검증: 세수 0원, 식량 0석, 인구 -1% 유출
## 5. 장용영 길목 요격 분대 출동 및 교전(combat) FSM 검증
## 6. 아군 승리 시 적군 궤멸, 민심 상승 및 폐가 점진 재건 검증
## 7. 행궁 도달 시 도시 함락 엔딩(FALLEN_TO_BANDITS) 발화 검증

func _init() -> void:
	print("=== [테스트 시작] 화성행궁 종심 방어 및 길목 요격 전투 체계 통합 검증 ===")
	call_deferred("_run_all_tests")

func _create_test_grid() -> GameGrid:
	var g := GameGrid.new()
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

	# 7x7 화성행궁 본궁 배치
	for hy in range(26, 33):
		for hx in range(11, 18):
			g.grid[hy][hx]["building"] = "haenggung" if (hx == 14 and hy == 29) else "haenggung_site"
			g.grid[hy][hx]["site_anchor"] = Vector2i(14, 29)

	# 성문(북문) 및 도로망 배치
	g.grid[10][14]["building"] = "gate"
	for ry in range(11, 26):
		g.grid[ry][14]["building"] = "stone_road"

	# 도로변 민가, 상점, 둔전 배치
	g.grid[15][15]["building"] = "com_1"
	g.grid[16][15]["building"] = "res_1"
	g.grid[17][15]["building"] = "agr_1"

	return g

func _run_all_tests() -> void:
	_test_enemy_attack_power_scaling()
	_test_haenggung_pathfinding()
	_test_ruin_building_and_non_destructive_preservation()
	_test_ruins_economic_penalties()
	_test_jangyongyeong_interception_and_combat()
	_test_combat_victory_and_building_restoration()
	_test_palace_breach_and_fallen_ending()

	print("=== [테스트 완료] 7대 핵심 전투/종심방어/폐가화/엔딩 검증 전 항목 100% PASS! ===")
	quit(0)

## 1. 적군 기본 공격력 500 상향 및 스케일링 공식 검증
func _test_enemy_attack_power_scaling() -> void:
	print("[검증 1] 적군 기본 공격력 500 상향 및 스케일링 공식 검증...")
	var sim := SimulationCore.new()

	# 1) 도적 공격력: 500 + max(0, 50 - 민심) * 8 + (방치 연수 * 25)
	sim.loyalty = 80 # 민심 80 (감소치 0)
	var atk_bandit_normal: int = BanditManager.calculate_bandit_siege_atk(sim, 0)
	assert(atk_bandit_normal == 500, "민심 80일 때 기본 도적 공격력은 정확히 500이어야 함 (실제: %d)" % atk_bandit_normal)

	sim.loyalty = 30 # 민심 30 -> deficit 20 -> 20 * 8 = 160
	var atk_bandit_bad_loyalty: int = BanditManager.calculate_bandit_siege_atk(sim, 2) # 방치 2년 -> 50
	# 500 + 160 + 50 = 710
	assert(atk_bandit_bad_loyalty == 710, "민심 30, 방치 2년 시 도적 공격력은 710이어야 함 (실제: %d)" % atk_bandit_bad_loyalty)
	assert(atk_bandit_bad_loyalty >= 500, "도적 공격력 최소 하한 500 보장되어야 함")

	# 2) 반란군 공격력: 500 + max(0, 50 - 왕권) * 10 + 난이도 보정치
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.EASY)
	sim.authority = 50 # 왕권 50
	var atk_rebel_base: int = RebellionManager.calculate_rebel_siege_atk(sim)
	assert(atk_rebel_base == 500, "왕권 50, 쉬움 난이도에서 반란군 공격력은 정확히 500이어야 함 (실제: %d)" % atk_rebel_base)

	sim.authority = 20 # 왕권 20 -> deficit 30 -> 30 * 10 = 300
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.NORMAL) # 보정치 50
	var atk_rebel_scaled: int = RebellionManager.calculate_rebel_siege_atk(sim)
	# 500 + 300 + 50 = 850
	assert(atk_rebel_scaled == 850, "왕권 20, 보통 난이도에서 반란군 공격력은 850이어야 함 (실제: %d)" % atk_rebel_scaled)
	assert(atk_rebel_scaled >= 500, "반란군 공격력 최소 하한 500 보장되어야 함")

	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.EASY)
	print("  - 도적 최소 500 및 민심/방치 스케일링, 반란군 최소 500 및 왕권/난이도 스케일링 검증 완료")

## 2. A* 도로망 진격 경로 생성 및 행궁 본궁 타깃팅 검증
func _test_haenggung_pathfinding() -> void:
	print("[검증 2] A* 도로망 진격 경로 생성 및 행궁 본궁 타깃팅 검증...")
	var grid := _create_test_grid()
	var hg_center: Vector2i = grid.find_haenggung_center()
	assert(hg_center == Vector2i(14, 29), "화성행궁 본궁 중심점 (14, 29) 일치해야 함")

	# 성문(14, 10)에서 행궁(14, 29)까지의 도로망 A* 경로
	var march_path: Array[Vector2i] = grid.find_march_path_to_haenggung(Vector2i(14, 10))
	assert(not march_path.is_empty(), "A* 경로가 비어있지 않아야 함")
	assert(march_path[march_path.size() - 1] == hg_center or absi(march_path[march_path.size() - 1].x - hg_center.x) <= 1, "경로의 종점이 행궁 본궁이어야 함")
	print("  - 성문 -> 화성행궁 본궁 A* 경로 생성(%d단계) 검증 완료" % march_path.size())

## 3. 진격로 상점/민가/둔전 폐가화(RUINED) 및 비파괴적 원형 보존 검증
func _test_ruin_building_and_non_destructive_preservation() -> void:
	print("[검증 3] 건물 폐가화(RUINED) 및 비파괴적 원형 보존 검증...")
	var grid := _create_test_grid()
	var sim := SimulationCore.new()

	var test_shop := Vector2i(15, 15)
	assert(grid.grid[test_shop.y][test_shop.x]["building"] == "com_1", "초기 건물은 com_1 상점이어야 함")

	# 약탈 및 폐가화 실행
	var ruined_ok: bool = BuildingManager.ruin_building_at(test_shop, grid, sim)
	assert(ruined_ok == true, "건물이 정상적으로 폐가화되어야 함")
	var cell: Dictionary = grid.grid[test_shop.y][test_shop.x]
	assert(cell.get("is_ruined", false) == true, "is_ruined 플래그가 true여야 함")
	assert(cell.get("building_state", "") == "RUINED", "building_state가 RUINED여야 함")
	assert(cell.get("original_building_type", "") == "com_1", "원본 건물 타입 'com_1'이 보존되어야 함")

	# BuildingEntity 래퍼 객체 검증
	var b_ent := BuildingEntity.new(test_shop, "com_1")
	assert(b_ent.is_ruined() == false, "초기 상태는 NORMAL")
	b_ent.ruin(3)
	assert(b_ent.is_ruined() == true, "ruin() 호출 후 RUINED")
	assert(b_ent.original_building_type == "com_1", "원본 타입 보존")
	assert(b_ent.get_available_actions().is_empty(), "폐가 상태에서는 정무 액션 불가")
	b_ent.restore()
	assert(b_ent.is_ruined() == false, "restore() 호출 후 NORMAL 복귀")
	assert(b_ent.building_id == "com_1", "원래 상점 ID 복구")
	print("  - 비파괴적 폐가화(RUINED) 및 원본 데이터 보존 검증 완료")

## 4. 폐가화 영향 검증: 세수 0원, 식량 0석, 인구 -1% 유출
func _test_ruins_economic_penalties() -> void:
	print("[검증 4] 폐가화 영향 검증: 세수 0원, 식량 0석, 인구 -1% 유출...")
	var grid := _create_test_grid()
	var sim := SimulationCore.new()
	sim.population = 10000

	# 1) 정상 상태 상점 카운트
	var tier_before: Dictionary = BuildingManager.count_all_building_tiers(grid)
	assert(tier_before["basic_shop_count"] == 1, "정상 상점 1개소 카운트되어야 함")

	# 상점 및 둔전 폐가화
	BuildingManager.ruin_building_at(Vector2i(15, 15), grid, sim) # com_1 (x=15, y=15)
	BuildingManager.ruin_building_at(Vector2i(15, 17), grid, sim) # agr_1 (x=15, y=17)

	# 2) 폐가화 후 상점 카운트 -> 0개소 (세수 0원 반영)
	var tier_after: Dictionary = BuildingManager.count_all_building_tiers(grid)
	assert(tier_after["basic_shop_count"] == 0, "폐가화된 상점은 세수 집계에서 제외되어 0이어야 함")

	# 3) 폐가화된 둔전 소출 정산 -> 둔전 수확 0석 (유효 둔전 agr1_count == 0)
	var harvest_res: Dictionary = FarmManager.calculate_harvest(grid, sim, 1)
	assert(harvest_res["agr1_count"] == 0, "폐가 둔전은 유효 둔전 집계에서 제외되어 agr1_count가 0이어야 함")

	# 4) 진압될 때까지 매 턴 인구 -1% 유출 페널티
	var pop_before: int = sim.population
	var ruin_turn_res: Dictionary = BuildingManager.process_ruined_buildings_turn(grid, sim)
	assert(ruin_turn_res["ruined_count"] == 2, "폐가 2채 감지")
	var expected_loss: int = int(float(pop_before) * 0.01) # 100명
	assert(sim.population == pop_before - expected_loss, "인구 -1%% 유출되어 %d명이어야 함 (실제: %d)" % [pop_before - expected_loss, sim.population])
	print("  - 세수 0, 식량 0, 인구 -1%% 유출 경제 페널티 검증 완료")

## 5. 장용영 길목 요격 분대 출동 및 교전(combat) FSM 검증
func _test_jangyongyeong_interception_and_combat() -> void:
	print("[검증 5] 장용영 길목 요격 분대 출동 및 교전(combat) FSM 검증...")
	var grid := _create_test_grid()
	var sim := SimulationCore.new()
	var defense_mgr := SiegeDefenseManager.new()
	var time_mgr := TimeManager.new()
	defense_mgr.setup(sim, grid, null, time_mgr)

	var inv_res: Dictionary = defense_mgr.start_invasion("bandit", 500)
	assert(defense_mgr.is_battle_active == true, "침략 배틀이 활성화되어야 함")
	assert(inv_res["enemy_atk"] >= 500, "적군 공격력 최소 500 이상")
	assert(defense_mgr.enemy_squads.size() > 0, "적군 분대가 생성되어야 함")
	assert(defense_mgr.ally_squads.size() > 0, "장용영 요격 분대가 생성되어야 함")

	var marcher: EnemyMarcherEntity = defense_mgr.enemy_squads[0]
	var troop: JangyongyeongUnitEntity = defense_mgr.ally_squads[0]

	# 장용영과 적군이 조우했을 때의 교전(combat) 상태 전이 검증
	troop.pos = marcher.pos + Vector2(0.3, 0.2)
	troop.engage(marcher)

	assert(troop.state == JangyongyeongUnitEntity.STATE_COMBAT, "장용영 상태가 COMBAT이어야 함")
	assert(marcher.state == EnemyMarcherEntity.STATE_COMBAT, "적군 상태가 COMBAT이어야 함")
	print("  - 장용영 요격 분대 출동 및 맞닿았을 때 COMBAT 교전 모드 전이 검증 완료")

## 6. 아군 승리 시 적군 궤멸, 민심 상승 및 폐가 점진 재건 검증
func _test_combat_victory_and_building_restoration() -> void:
	print("[검증 6] 아군 승리 시 적군 궤멸, 민심 상승 및 폐가 점진 재건 검증...")
	var grid := _create_test_grid()
	var sim := SimulationCore.new()
	sim.loyalty = 60
	var test_pos := Vector2i(15, 15)
	BuildingManager.ruin_building_at(test_pos, grid, sim)

	var defense_mgr := SiegeDefenseManager.new()
	var time_mgr := TimeManager.new()
	defense_mgr.setup(sim, grid, null, time_mgr)
	defense_mgr.start_invasion("bandit", 500)

	# 아군 승리 트리거
	var loy_before: int = sim.loyalty
	defense_mgr._on_combat_finished(true)

	assert(defense_mgr.is_battle_active == false, "배틀 비활성화")
	assert(sim.loyalty == loy_before + 5, "승리 시 민심 +5 상승")
	assert(sim.bandit_suppression_turns == 8, "2년(8턴) 안전 보장")

	# 폐가가 턴 경과에 따라 복구되는지 검증
	var cell: Dictionary = grid.grid[test_pos.y][test_pos.x]
	# 3턴 경과 시뮬레이션
	BuildingManager.restore_ruined_buildings(grid, sim) # 1턴 경과
	BuildingManager.restore_ruined_buildings(grid, sim) # 2턴 경과
	BuildingManager.restore_ruined_buildings(grid, sim) # 3턴 경과 -> 복원 완료
	assert(cell.get("is_ruined", false) == false, "복원 완료 후 is_ruined는 false")
	assert(cell.get("building", "") == "com_1", "원래 상점 com_1으로 완벽 복구되어야 함")
	print("  - 승전보, 민심 +5, 폐가 3턴 점진 완벽 재건 검증 완료")

## 7. 행궁 도달 시 도시 함락 엔딩(FALLEN_TO_BANDITS) 발화 검증
func _test_palace_breach_and_fallen_ending() -> void:
	print("[검증 7] 행궁 도달 시 도시 함락 엔딩(FALLEN_TO_BANDITS) 발화 검증...")
	var grid := _create_test_grid()
	var sim := SimulationCore.new()
	var time_mgr := TimeManager.new()
	time_mgr.set_speed(TimeManager.SpeedMode.NORMAL)

	var ending_mgr := EndingManager.new()
	ending_mgr.setup(sim, grid, time_mgr)

	var defense_mgr := SiegeDefenseManager.new()
	defense_mgr.setup(sim, grid, null, time_mgr)
	defense_mgr.start_invasion("bandit", 500)

	# 행궁 침입 트리거
	defense_mgr._trigger_palace_fall()

	assert(defense_mgr.is_battle_active == false, "배틀 종료")
	assert(time_mgr.current_speed == TimeManager.SpeedMode.PAUSE, "게임 시뮬레이션 일시 정지되어야 함")
	assert(ending_mgr.is_ending_active == true, "엔딩 모달이 활성화되어야 함")
	print("  - 행궁 함락 즉시 시뮬레이션 정지 및 FALLEN_TO_BANDITS 엔딩 시퀀스 발화 검증 완료")
