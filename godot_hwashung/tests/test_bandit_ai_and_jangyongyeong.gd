extends SceneTree

const CityStatsClass = preload("res://scripts/CityStats.gd")
const GameGridClass = preload("res://scripts/GameGrid.gd")
const SimulationCoreClass = preload("res://scripts/SimulationCore.gd")
const CitizenManagerClass = preload("res://scripts/CitizenManager.gd")
const BanditManagerClass = preload("res://scripts/BanditManager.gd")
const BanditEntityClass = preload("res://scripts/BanditEntity.gd")
const JangyongyeongTroopClass = preload("res://scripts/JangyongyeongTroop.gd")
const EndingManagerClass = preload("res://scripts/EndingManager.gd")
const DisasterManagerClass = preload("res://scripts/DisasterManager.gd")

func _init() -> void:
	print("=== [테스트 시작] 왕권 연동 도적 침입 AI 분기, 실시간 약탈, 장용영 요격 및 압송/함락 엔딩 검증 ===")
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
	_test_royal_power_branching_ai()
	_test_bandit_wall_attack_and_breach()
	_test_realtime_safe_looting()
	_test_jangyongyeong_dispatch_and_combat()
	_test_combat_victory_and_arrest_escort()
	_test_city_fall_ending_trigger()
	_test_baek_dongsu_hundred_percent_protection()

	print("=== [테스트 완료] 왕권 연동 도적 AI & 장용영 요격 & 압송/함락 엔딩 7대 전 항목 100% 통과! ===")
	quit(0)

## 1. 왕권 수치 연동 AI 분기 검증 (외곽 약탈 vs 행궁 직격)
func _test_royal_power_branching_ai() -> void:
	print("[검증 1] 왕권(Royal Power) 연동 AI 분기 검증...")
	CityStatsClass.reset_to_defaults()
	var grid := _create_test_grid()
	var sim := SimulationCoreClass.new()
	var citizens := CitizenManagerClass.new()
	citizens.grid = grid
	citizens.sim = sim

	# 1) 왕권 >= 30: 외곽 약탈 모드
	sim.authority = 70
	CityStatsClass.set_royal_power(70)
	var bandit_mgr := BanditManagerClass.new()
	var res1: Dictionary = bandit_mgr.start_raid(sim, grid, citizens)
	assert(res1["mode"] == BanditManagerClass.AI_STATE_RAID_OUTSKIRTS, "왕권 70일 때는 외곽 약탈 모드여야 함")
	assert(bandit_mgr.raid_mode == BanditManagerClass.AI_STATE_RAID_OUTSKIRTS, "매니저 모드가 outskirts여야 함")

	# 2) 왕권 < 30: 행궁 직격 모드
	sim.authority = 20
	CityStatsClass.set_royal_power(20)
	var bandit_mgr2 := BanditManagerClass.new()
	var res2: Dictionary = bandit_mgr2.start_raid(sim, grid, citizens)
	assert(res2["mode"] == BanditManagerClass.AI_STATE_ASSAULT_PALACE, "왕권 20일 때는 행궁 직격 반란 모드여야 함")
	assert(bandit_mgr2.raid_mode == BanditManagerClass.AI_STATE_ASSAULT_PALACE, "매니저 모드가 assault_palace여야 함")
	assert(res2["target"] == bandit_mgr2.haenggung_palace_pos, "타깃이 행궁 본궁 좌표여야 함")
	print("  - 왕권 >= 30 외곽 약탈 & 왕권 < 30 행궁 직격 분기 검증 통과")

## 2. 성벽/성문 충돌 시 성벽 타격(attack_wall) 및 성 방호력 차감 후 돌파 검증
func _test_bandit_wall_attack_and_breach() -> void:
	print("[검증 2] 성벽 타격(attack_wall) 및 성 방호력 차감 후 돌파 검증...")
	CityStatsClass.reset_to_defaults()
	CityStatsClass.set_fortress_defense_power(30) # 방호력 30 설정

	var grid := _create_test_grid()
	var sim := SimulationCoreClass.new()
	var citizens := CitizenManagerClass.new()
	citizens.grid = grid
	citizens.sim = sim

	# 성벽 타일 배치
	grid.grid[15][15]["building"] = "wall"

	# 도적 생성 (행궁 직격 모드)
	var b_dict: Dictionary = citizens._add_bandit_agent(Vector2i(15, 14), Vector2i(24, 28), "assault_palace")
	citizens._update_bandit(b_dict, 0.1)

	# 성벽 인접 시 attack_wall 상태 전이 확인
	assert(b_dict["state"] == "attack_wall", "성벽과 접촉 시 attack_wall 상태로 전이되어야 함 (실제: %s)" % b_dict["state"])

	# 공방전 틱으로 방호력 차감 검사
	citizens._bandit_raid_active = true
	citizens._bandit_siege_atk = 500
	citizens._manage_bandits(0.2) # 0.2초 틱 실행
	var def_after: int = CityStatsClass.get_fortress_defense_power()
	assert(def_after < 30, "도적의 성벽 공격으로 방호력이 차감되어야 함 (차감 후: %d)" % def_after)

	# 방호력 0 도달 시 성벽 돌파(march 복귀) 확인
	CityStatsClass.set_fortress_defense_power(0)
	citizens._update_bandit(b_dict, 0.1)
	assert(b_dict["state"] == "march", "방호력이 0이 되면 성벽 돌파 후 march로 복귀해야 함 (실제: %s)" % b_dict["state"])
	print("  - 성벽 타격 및 방호력 차감, 방호력 0 시 돌파 검증 통과")

## 3. 이동 경로상 민가/상점 실시간 안전 약탈 (비파괴적) 검증
func _test_realtime_safe_looting() -> void:
	print("[검증 3] 실시간 비파괴적 약탈(is_looted = true) 및 자원 유출 검증...")
	var grid := _create_test_grid()
	var sim := SimulationCoreClass.new()
	sim.gold = 1000
	sim.rice = 500
	sim.loyalty = 80

	var citizens := CitizenManagerClass.new()
	citizens.grid = grid
	citizens.sim = sim

	var loot_pos := Vector2i(10, 10)
	grid.grid[loot_pos.y][loot_pos.x]["building"] = "res_1"

	# 도적이 민가 위치에 도달
	citizens._loot_tile_safe(loot_pos)

	# 타일이 파괴되지 않고 is_looted 플래그 설정 확인
	assert(grid.grid[loot_pos.y][loot_pos.x]["building"] == "res_1", "타일 빌딩이 유지되어야 함 (비파괴성 보장)")
	assert(grid.grid[loot_pos.y][loot_pos.x].get("is_looted", false) == true, "is_looted 플래그가 true여야 함")
	assert(float(grid.grid[loot_pos.y][loot_pos.x].get("looted_timer", 0.0)) > 0.0, "looted_timer가 설정되어야 함")

	# 국고, 식량, 민심 일부 유출 확인
	assert(sim.gold == 975, "금화 25냥 감소 확인 (실제: %d)" % sim.gold)
	assert(sim.rice == 485, "식량 15석 감소 확인 (실제: %d)" % sim.rice)
	assert(sim.loyalty == 79, "민심 1 감소 확인 (실제: %d)" % sim.loyalty)

	# 25초 경과 후 자동 복구 확인
	var b_mgr = citizens.get("bandit_mgr")
	if b_mgr:
		b_mgr._update_looted_tiles(26.0, grid)
	assert(grid.grid[loot_pos.y][loot_pos.x].get("is_looted", false) == false, "타이머 만료 후 is_looted가 false로 자동 복구되어야 함")
	print("  - 비파괴적 약탈, 자원 유출 및 타이머 만료 자동 복구 검증 통과")

## 4. 장용영 군대 긴급 출동 및 실시간 교전 연출 검증
func _test_jangyongyeong_dispatch_and_combat() -> void:
	print("[검증 4] 장용영 정예 요격 부대 출동 및 교전 공식 검증...")
	CityStatsClass.reset_to_defaults()
	CityStatsClass.set_military_attack_power(500) # 장용영 기본 공격력 500

	var grid := _create_test_grid()
	var sim := SimulationCoreClass.new()
	var citizens := CitizenManagerClass.new()
	citizens.grid = grid
	citizens.sim = sim
	citizens._haenggung_gate = Vector2i(24, 28)

	# 장용영 부대 출동
	citizens.dispatch_jangyongyeong_squad(Vector2i(20, 20))
	var troops: Array[Dictionary] = citizens.agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "jangyongyeong_soldier")
	assert(troops.size() == 6, "장용영 군사 6명이 스폰되어야 함 (실제: %d)" % troops.size())
	assert(troops[0].get("extra", {}).get("is_flag_bearer", false) == true, "선두 1번 병사는 깃발병이어야 함")

	# 도적과 조우 시 combat 상태 전이 검사
	var tr: Dictionary = troops[0]
	tr["x"] = 20.0
	tr["y"] = 20.0
	var b_agent: Dictionary = citizens._add_bandit_agent(Vector2i(20, 20), Vector2i(24, 28))
	citizens._update_jangyongyeong_soldier(tr, 0.1)
	assert(tr["state"] == "combat", "도적과 조우 시 장용영 병사는 combat 상태로 전이되어야 함 (실제: %s)" % tr["state"])
	assert(b_agent["state"] == "combat", "도적 또한 combat 상태로 전이되어야 함 (실제: %s)" % b_agent["state"])

	# 교전 데미지 공식 검증: 초당 아군 피해량 = ally_atk / 5
	# 0.2초 틱당 피해량 = ally_atk / 25 = 500 / 25 = 20
	citizens._bandit_raid_active = true
	citizens._bandit_siege_hp = 500
	citizens._manage_bandits(0.2)
	assert(citizens._bandit_siege_hp <= 480, "0.2초 틱당 아군 공격력에 비례해 최소 20 이상의 도적 체력이 차감되어야 함 (현재: %d)" % citizens._bandit_siege_hp)
	print("  - 장용영 부대 출동, 깃발병, 백병전 combat 상태 전이 및 데미지 공식 검증 통과")

## 5. 도적 소탕 시 포박 및 관아 압송(승리) 루프 검증
func _test_combat_victory_and_arrest_escort() -> void:
	print("[검증 5] 도적 소탕, 포박(arrested), 관아 압송(prisoner_escort) 및 승리 보상 검증...")
	var grid := _create_test_grid()
	var sim := SimulationCoreClass.new()
	sim.loyalty = 70

	var citizens := CitizenManagerClass.new()
	citizens.grid = grid
	citizens.sim = sim

	# 관아 타일 배치
	grid.grid[20][20]["building"] = "gwana"
	citizens._gwana_cache.append(Vector2i(20, 20))

	# 도적 체력 0 도달 시뮬레이션
	citizens._bandit_raid_active = true
	citizens._bandit_siege_hp = 5
	CityStatsClass.set_military_attack_power(500)

	var b_agent: Dictionary = citizens._add_bandit_agent(Vector2i(22, 22), Vector2i(24, 28))
	b_agent["state"] = "combat"

	# 0.2초 틱 진행 시 도적 체력 소진 -> 승리 발화
	citizens._manage_bandits(0.2)

	assert(citizens._bandit_raid_active == false, "도적 침입이 종료되어야 함")
	assert(sim.bandit_active == false, "시뮬레이션 도적 플래그가 해제되어야 함")
	assert(sim.bandit_suppression_turns == 24, "24개월(2년) 안전 보장이 부여되어야 함")
	assert(sim.loyalty == 75, "민심이 +5 상승해야 함 (실제: %d)" % sim.loyalty)

	# 관아로 압송 중인 prisoner_escort 에이전트 존재 확인
	var escorts: Array[Dictionary] = citizens.agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "prisoner_escort")
	assert(escorts.size() > 0, "포박된 도적을 관아로 압송하는 에이전트가 생성되어야 함")
	print("  - 도적 소탕, 관아 압송 에이전트 생성, 민심 +5 및 8턴 평온 버프 검증 통과")

## 6. 성 방호력 소진 및 행궁 본궁 도달 시 도시 함락 엔딩(패배) 발화 검증
func _test_city_fall_ending_trigger() -> void:
	print("[검증 6] 행궁 함락 시 EndingManager.trigger_fall_of_city_ending 호출 및 게임 오버 검증...")
	CityStatsClass.reset_to_defaults()
	CityStatsClass.set_fortress_defense_power(0) # 방호력 0
	CityStatsClass.set_royal_power(15) # 왕권 15 (극단적 실추)

	var grid := _create_test_grid()
	var sim := SimulationCoreClass.new()
	sim.authority = 15

	var citizens := CitizenManagerClass.new()
	citizens.grid = grid
	citizens.sim = sim
	citizens._haenggung_gate = Vector2i(24, 28)
	citizens._bandit_mode = "assault_palace"

	# EndingManager 생성 및 등록
	var ending_mgr := EndingManagerClass.new()
	ending_mgr.setup(sim, grid, null)

	# 도적이 행궁 본궁 앞마당에 도달
	var b_agent: Dictionary = citizens._add_bandit_agent(Vector2i(24, 28), Vector2i(24, 28), "assault_palace")
	b_agent["x"] = 24.5
	b_agent["y"] = 28.5

	citizens._bandit_raid_active = true
	citizens._manage_bandits(0.2)

	assert(ending_mgr.ending_triggered_flag == true, "EndingManager의 ending_triggered_flag가 true여야 함")
	assert(ending_mgr.is_ending_active == true, "엔딩 모달이 활성화되어야 함")
	print("  - 행궁 본궁 점거 시 EndingManager 비극 엔딩 발화 및 게임 오버 검증 통과")

## 7. 백동수 등용 시 도적 침략 100% 완전 차단 검증
func _test_baek_dongsu_hundred_percent_protection() -> void:
	print("[검증 7] 무예 인재 백동수 등용 시 도적 침략 100% 차단 검증...")
	var grid := _create_test_grid()
	var sim := SimulationCoreClass.new()
	var citizens := CitizenManagerClass.new()
	citizens.grid = grid
	citizens.sim = sim

	# 백동수 등용
	sim.retainers["baek_dongsu"] = true
	citizens._bandit_raid_active = true

	var b_agent: Dictionary = citizens._add_bandit_agent(Vector2i(10, 10), Vector2i(20, 20))
	citizens._manage_bandits(0.1)

	assert(citizens._bandit_raid_active == false, "백동수 등용 시 도적 침입이 즉각 종료되어야 함")
	assert(b_agent["state"] == "retreat", "도적이 즉시 퇴각(retreat)해야 함")
	print("  - 백동수 등용 시 도적 침략 100% 완전 차단 검증 통과")
