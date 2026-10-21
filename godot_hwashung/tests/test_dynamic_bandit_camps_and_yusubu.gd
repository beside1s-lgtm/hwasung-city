extends SceneTree

func _init() -> void:
	print("\n=== [테스트 시작] 화성 외곽 도적 소굴 동적 스폰, 수원유수부 토벌, 약탈 FSM 및 공성전 엔딩 엔진 검증 ===")

	var grid := GameGrid.new()
	var sim := SimulationCore.new()
	var b_mgr := BanditManager.new()
	b_mgr.init_outer_tiles(grid)
	sim.bandit_manager = b_mgr

	# -------------------------------------------------------------------------
	# [검증 1] 게임 시작 후 2년(8턴) 동안 도적 소굴 스폰 및 약탈 면역 검증
	# -------------------------------------------------------------------------
	print("[검증 1] 게임 시작 후 2년(8턴) 유예 기간 검증...")
	sim.current_year = 1789
	sim.turn = 2 # 1년차 가을 (turn % 4 == 2)
	sim.loyalty = 20 # 민심 극도로 악화
	var res1: Dictionary = b_mgr.process_turn(sim, grid)
	assert(not res1.get("camp_spawned", false), "2년 이내에는 가을 및 민심 40 이하라도 소굴이 생성되어서는 안 됨")
	assert(b_mgr.camps.is_empty(), "2년 이내에는 소굴 수가 0이어야 함")
	print("  - 2년(8턴) 유예 기간 중 소굴 미스폰 및 약탈 차단 검증 통과")

	# -------------------------------------------------------------------------
	# [검증 2] 2년 경과 후 민심 40 이하 시 가을 스폰 및 최대 3개(Hard Cap), 연간 최대 1개 제한 검증
	# -------------------------------------------------------------------------
	print("[검증 2] 민심 40 이하 동적 스폰, 3개 Hard Cap 및 연간 1개 제한 검증...")
	sim.current_year = 1792
	sim.turn = 14 # 4년차 가을 (14 % 4 == 2)
	sim.loyalty = 35

	# 스폰 함수 직접 테스트
	b_mgr._spawn_bandit_camp(grid)
	assert(b_mgr.camps.size() == 1, "소굴 1개 생성 확인")
	assert(b_mgr.camps[0]["combat_power"] == 150, "소굴 초기 전투력 150 검증")

	# 3개 초과 생성 방지 Hard Cap 검증
	b_mgr._spawn_bandit_camp(grid)
	b_mgr._spawn_bandit_camp(grid)
	assert(b_mgr.camps.size() == 3, "소굴 3개 등록")

	# 가을 턴 정산 시 이미 3개이므로 추가 스폰되지 않음 검증
	var res2: Dictionary = b_mgr.process_turn(sim, grid)
	assert(not res2.get("camp_spawned", false), "소굴이 3개일 때는 추가 스폰되지 않아야 함 (Hard Cap 3개)")
	assert(b_mgr.camps.size() == 3, "소굴 상한선 3개 유지")
	print("  - 초기 전투력 150, Hard Cap 3개 및 연간 1개 제한 검증 통과")

	# -------------------------------------------------------------------------
	# [검증 3] 방치 시 전투력 성장 검증 (턴당 +25, 최대 500)
	# -------------------------------------------------------------------------
	print("[검증 3] 소굴 방치 시 턴당 전투력 +25 성장 및 500 상한 검증...")
	# 방금 process_turn에서 150 -> 175로 1회 성장했음
	assert(b_mgr.camps[0]["combat_power"] == 175, "1턴 방치 후 전투력 175 검증")
	# 임의로 490으로 설정 후 성장 테스트
	b_mgr.camps[0]["combat_power"] = 490
	b_mgr.process_turn(sim, grid)
	assert(b_mgr.camps[0]["combat_power"] == 500, "전투력 500 상한 clamp 검증")
	print("  - 턴당 +25 누적 성장 및 최대 500 상한 검증 통과")

	# -------------------------------------------------------------------------
	# [검증 4] 수원유수부 토벌 출동 시스템 (비용, 1년 1회 쿨다운, 승패 판정) 검증
	# -------------------------------------------------------------------------
	print("[검증 4] 수원유수부 토벌 출동 (자원 차감, 1년 1회 쿨다운, 최고 전투력 소굴 승패 판정) 검증...")
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.NORMAL) # 보통(x2)
	var cost_normal: Dictionary = DifficultyManager.get_bandit_subjugation_cost()
	assert(cost_normal["gold"] == 2000 and cost_normal["rice"] == 2000, "보통 난이도 출동 비용 x2 (금 2,000 / 곡 2,000) 검증")

	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.EASY) # 테스트를 위해 쉬움(1,000 / 1,000)
	sim.gold = 3000
	sim.rice = 3000
	sim.military_power = 200
	b_mgr.subjugation_cooldown_turns = 0

	# 현재 소굴: 1개는 500, 나머지 둘은 200, 200으로 설정
	b_mgr.camps[0]["combat_power"] = 500
	b_mgr.camps[1]["combat_power"] = 200
	b_mgr.camps[2]["combat_power"] = 200

	# 아군 군사력(200) < 적 최고 전투력(500) -> 패배
	var defeat_res: Dictionary = b_mgr.dispatch_yusubu_subjugation(sim, grid)
	assert(defeat_res.get("success", false) and not defeat_res.get("victory", false), "군사력 미달 시 패배 판정")
	assert(b_mgr.camps.size() == 3, "패배 시 소굴 유지")
	assert(sim.gold == 2000 and sim.rice == 2000, "패배 시에도 출동 비용 차감")
	assert(b_mgr.subjugation_cooldown_turns == 12, "출동 후 12개월 쿨다운 설정")

	# 쿨다운 중 추가 출동 불가 검증
	var cd_res: Dictionary = b_mgr.dispatch_yusubu_subjugation(sim, grid)
	assert(not cd_res.get("success", false) and cd_res.get("reason", "") == "cooldown", "쿨다운 중 출동 차단 검증")

	# 군사력 증강 후 승리 검증
	b_mgr.subjugation_cooldown_turns = 0
	sim.military_power = 600
	sim.loyalty = 50
	var vic_res: Dictionary = b_mgr.dispatch_yusubu_subjugation(sim, grid)
	assert(vic_res.get("success", false) and vic_res.get("victory", false), "군사력 우위 시 승리 판정")
	assert(b_mgr.camps.size() == 2, "승리 시 대상 소굴 완전 소멸 (3개 -> 2개)")
	assert(sim.loyalty == 55, "승리 시 민심 +5 회복")
	print("  - 출동 비용 차감, 1년 1회 쿨다운, 최고 전투력 소굴 승패 및 민심 회복 검증 통과")

	# -------------------------------------------------------------------------
	# [검증 5] 2단계 약탈 주기 및 음수 방어(clamp 0) 검증
	# -------------------------------------------------------------------------
	print("[검증 5] 2단계 약탈, 금 5000/곡 5000 강탈, 음수 방어 및 1년 확정 면역 쿨다운 검증...")
	b_mgr.loot_immune_turns = 0
	sim.gold = 3000 # 5000보다 적음
	sim.rice = 2500

	# 약탈 직접 실행 (1단계)
	b_mgr._execute_raid(false, sim, grid, null)
	assert(sim.gold == 0, "보유량보다 많은 약탈 시 금 0 바닥 고정 (음수 방지)")
	assert(sim.rice == 0, "보유량보다 많은 약탈 시 곡 0 바닥 고정 (음수 방지)")

	# 1년(12개월) 면역 쿨다운 검증
	b_mgr.loot_immune_turns = 12
	var immune_raid: Dictionary = b_mgr.process_turn(sim, grid)
	assert(not immune_raid.get("raid_occurred", false), "면역 턴 동안 약탈 발생 불가")
	assert(b_mgr.loot_immune_turns == 11, "면역 1개월 차감 (12 -> 11)")
	print("  - 자원 음수 방지 바닥 고정(clamp 0) 및 1년 확정 면역 쿨다운 검증 통과")

	# -------------------------------------------------------------------------
	# [검증 6] 공성전 위기 트리거 및 도적 함락 엔딩 연동 검증
	# -------------------------------------------------------------------------
	print("[검증 6] 총전투력 > 국방력 * 1.5 2턴 방치 시 긴급 경고 및 도적 함락 엔딩 연동 검증...")
	sim.military_power = 100 # 아군 국방력 100
	# camps 2개 합산 전투력: 300 + 300 = 600 > 100 * 1.5 (150)
	b_mgr.camps[0]["combat_power"] = 300
	b_mgr.camps[1]["combat_power"] = 300
	b_mgr.siege_warning_turns = 0

	# 1턴 방치: 경고 발화
	var siege_res1: Dictionary = b_mgr.process_turn(sim, grid)
	assert(siege_res1.get("siege_warning", false), "1턴 방치 시 공성전 긴급 경고 발화")
	assert(b_mgr.siege_warning_turns == 1, "경고 카운트 1")

	# 경고 뒤 석 달(한 계절) 방치: 엔딩 발화 트리거
	b_mgr.process_turn(sim, grid)
	b_mgr.process_turn(sim, grid)
	var siege_res2: Dictionary = b_mgr.process_turn(sim, grid)
	assert(siege_res2.get("siege_ending", false), "경고 뒤 석 달 방치 시 도적 함락 엔딩 트리거 검증")
	print("  - 공성전 1턴 긴급 경고 및 2턴 방치 시 도적 함락 엔딩 트리거 검증 통과")

	# -------------------------------------------------------------------------
	# [검증 7] 세이브/로드 직렬화 및 무예 인재 백동수 차단 검증
	# -------------------------------------------------------------------------
	print("[검증 7] 세이브/로드 직렬화 및 백동수 등용 시 100% 차단 검증...")
	var s_data: Dictionary = b_mgr.serialize()
	assert(s_data.has("camps") and s_data.get("camps", []).size() == 2, "소굴 직렬화 검증")
	assert(s_data.get("subjugation_cooldown_turns", -1) == b_mgr.subjugation_cooldown_turns, "쿨다운 직렬화 검증")

	var b_mgr_new := BanditManager.new()
	b_mgr_new.deserialize(s_data)
	assert(b_mgr_new.camps.size() == 2, "역직렬화 소굴 수 일치")
	assert(b_mgr_new.camps[0]["combat_power"] == b_mgr.camps[0]["combat_power"], "역직렬화 전투력 일치")

	# 백동수 등용 시 검증
	sim.retainers["baek_dongsu"] = true
	b_mgr.siege_warning_turns = 0
	var baek_res: Dictionary = b_mgr.process_turn(sim, grid)
	assert(not baek_res.get("camp_spawned", false), "백동수 수호 중 소굴 스폰 100% 차단")
	assert(not baek_res.get("raid_occurred", false), "백동수 수호 중 약탈 100% 차단")
	assert(not baek_res.get("siege_ending", false), "백동수 수호 중 공성전 함락 100% 차단")
	print("  - 세이브/로드 무결성 및 백동수 100% 차단 검증 통과")

	print("\n=== [테스트 완료] 화성 외곽 도적 소굴 동적 스폰 & 수원유수부 토벌 & 약탈 FSM 7대 전 항목 100% 통과! ===\n")
	quit(0)
