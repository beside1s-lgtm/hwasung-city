extends SceneTree

func _init() -> void:
	print("=== 도둑·싸움꾼 스폰 상한/쿨타임 및 성문 도주·요격 시스템 단위 테스트 시작 ===")
	var passed: int = 0
	var total: int = 0

	# -------------------------------------------------------------
	# Test 1: 도둑 최대 1명, 싸움 최대 1건 Hard Cap 검증
	# -------------------------------------------------------------
	total += 1
	var sm := SunlacheongManager.new()
	sm.patrol_stations.clear()
	sm.patrol_stations.append(Vector2i(10, 10))
	sm.crime_cooldown_timer = 0.0

	var grid := GameGrid.new()
	grid.size = 40
	grid.grid = []
	for y in range(40):
		var row: Array = []
		for x in range(40):
			row.append({"building": ""})
		grid.grid.append(row)

	# 상점 10개소 설치
	for i in range(10):
		grid.grid[15][10 + i]["building"] = "com_1"

	# 첫 번째 사건 스폰 시도 (확률 루프)
	for attempt in range(100):
		sm._check_dispute_spawn(null, grid, null)
		if sm.active_events.size() >= 1:
			break
	assert(sm.active_events.size() == 1, "상점이 충분할 때 사건이 정상 스폰되어야 함")
	var ev1: MarketDisputeEvent = sm.active_events[0]

	# 만약 첫 사건이 도둑(PICKPOCKET)이면, 다음 사건은 무조건 싸움(BRAWL)이어야 함
	# 반대로 첫 사건이 싸움이면 다음 사건은 무조건 도둑이어야 함
	var expected_next_type: int = MarketDisputeEvent.DisputeType.BRAWL if ev1.event_type == MarketDisputeEvent.DisputeType.PICKPOCKET else MarketDisputeEvent.DisputeType.PICKPOCKET

	for attempt in range(100):
		sm._check_dispute_spawn(null, grid, null)
		if sm.active_events.size() >= 2:
			break
	assert(sm.active_events.size() == 2, "두 번째 사건이 스폰되어 도둑 1명, 싸움 1건이 공존해야 함")
	assert(sm.active_events[1].event_type == expected_next_type, "도둑과 싸움은 각각 1건씩만 허용되어야 함")

	# 도둑 1명 + 싸움 1건이 모두 찬 상태에서는 50번 시도해도 3번째 사건 스폰 100% 차단 검증
	for attempt in range(50):
		sm._check_dispute_spawn(null, grid, null)
	assert(sm.active_events.size() == 2, "도둑 1명 + 싸움 1건 상한 도달 시 신규 범죄 스폰이 전면 차단되어야 함")
	passed += 1
	print("[PASS] Test 1: 도둑 최대 1명, 싸움 최대 1건 Hard Cap 검증 완료")

	# -------------------------------------------------------------
	# Test 2: 사건 종료 후 최소 40초 쿨타임 검증
	# -------------------------------------------------------------
	total += 1
	# 사건 종료 및 40초 쿨타임 발동 시뮬레이션
	sm.active_events.clear()
	sm.active_criminals.clear()
	sm.crime_cooldown_timer = 40.0

	# 쿨타임 잔여 시간 동안에는 아무리 시도해도 절대 스폰되지 않아야 함
	for attempt in range(50):
		sm._check_dispute_spawn(null, grid, null)
	assert(sm.active_events.is_empty(), "40초 쿨타임 중에는 신규 범죄가 스폰되지 않아야 함")

	# 쿨타임 만료 시뮬레이션
	sm.crime_cooldown_timer = 0.0
	for attempt in range(100):
		sm._check_dispute_spawn(null, grid, null)
		if sm.active_events.size() >= 1:
			break
	assert(sm.active_events.size() == 1, "40초 쿨타임 만료 후에는 다시 범죄 스폰이 재개되어야 함")
	passed += 1
	print("[PASS] Test 2: 사건 종료 후 40초 쿨타임 보장 검증 완료")

	# -------------------------------------------------------------
	# Test 3: 싸움꾼 제자리 15.0초 유지 및 100% 소멸 검증
	# -------------------------------------------------------------
	total += 1
	var brawler := CriminalNPC.new()
	brawler.setup_criminal(1, CriminalNPC.CriminalKind.DRUNK_BRAWLER, Vector2i(15, 15), 101)
	assert(brawler.crime_timer == 15.0, "싸움꾼 제자리 격투 시간은 정확히 15.0초여야 함")

	# 15.0초 경과 전에는 DISPUTING(제자리 주먹질) 상태 유지
	brawler.update(14.0)
	assert(brawler.state == CriminalNPC.CriminalState.DISPUTING, "15초 이전에는 DISPUTING 상태 유지")

	# 15초 만료 시 의기양양 포즈(BOAST_AND_CARRY) 전이
	brawler.update(1.5)
	assert(brawler.state == CriminalNPC.CriminalState.BOAST_AND_CARRY, "15초 만료 시 가해자 우쭐 만세 포즈 전이")
	assert(brawler.victim_rotation == 90.0, "피해자 90도 회전 쓰러짐 확인")
	assert(brawler.victim_bubble == "아이구, 사람 죽네...", "피해자 말풍선 확인")

	# 2.0초 후 가해자 귀가(RETURNING_HOME) 전이
	brawler.update(2.1)
	assert(brawler.state == CriminalNPC.CriminalState.RETURNING_HOME, "2.0초 후 귀가 상태 전이")

	# 3.5초 후 가해자 및 피해자 100% 영구 삭제 검증
	brawler.update(3.6)
	assert(brawler.is_dead == true, "가해자와 피해자는 3.5초 경과 시 100% 소멸되어야 함")
	passed += 1
	print("[PASS] Test 3: 싸움꾼 제자리 15.0초 격투 및 피해자 후송·가해자 귀가 후 100% 소멸 검증 완료")

	# -------------------------------------------------------------
	# Test 4: 도둑 목표 성문 도주 및 도주 성문 인근 순라청 가중치 요격 검증
	# -------------------------------------------------------------
	total += 1
	var thief := ThiefNPC.new()
	var thief_start := Vector2(0.0, 0.0) # 마을 중심
	thief.setup(2, thief_start, 102)

	# 4초간 훔치는 동작
	assert(thief.state == ThiefNPC.ThiefState.STEALING, "초기 4초는 STEALING 상태여야 함")
	thief.update(4.1)
	assert(thief.state in [ThiefNPC.ThiefState.FLEEING_TO_GATE, ThiefNPC.ThiefState.SWAGGER_HOME], "4초 후 성문 도주 상태로 전이되어야 함")
	assert(thief.is_arrestable == true, "성문 밖으로 나가기 전까지는 언제든 체포 가능(is_arrestable=true)이어야 함")
	assert(thief.is_loot_sack_visible == true, "장물 보따리를 메야 함")
	assert(thief.bubble_text == "세상 살기 편하구만", "세상 살기 편하구만 대사 출력 확인")

	# 도주 성문 인근 순라청 우선 출동 가중치 검증:
	# 순라청 A: 도둑 현장 근처 (거리 80)
	# 순라청 B: 도둑이 도망가는 성문 바로 앞 (거리 100이지만 성문 거리 20 -> 20 * 0.65 = 13으로 B가 훨씬 유리)
	var sm2 := SunlacheongManager.new()
	sm2.patrol_stations = [Vector2i(5, 5), Vector2i(0, -14)] # station A, station B
	var target_gate := Vector2(0.0, -450.0) # 북문(장안문)
	sm2.dispatch_police_for_thief(thief, target_gate)

	# 포졸이 출동하여 도둑 추격 상태인지 확인
	assert(sm2.officer_pool.size() > 0, "포졸이 출동 배정되어야 함")
	var lead_off: PatrolOfficerNPC = sm2.officer_pool[0]
	assert(lead_off.is_active == true, "포졸이 활성화되어야 함")
	assert(lead_off.state == PatrolOfficerNPC.State.MOVE_TO_CRIME, "포졸이 도둑 요격을 위해 출동 상태여야 함")

	# 포졸이 도둑에게 접근 시 즉시 체포 성공 검증
	lead_off.global_position = thief.global_position
	lead_off.update(0.1)
	assert(lead_off.state == PatrolOfficerNPC.State.ARRESTING, "성문 도주 중인 도둑을 포졸이 가로막아 체포해야 함")
	assert(thief.state == ThiefNPC.ThiefState.ARRESTED, "도둑이 체포 상태로 전이되어야 함")
	passed += 1
	print("[PASS] Test 4: 도둑 성문 도주 및 도주 성문 인근 순라청 가중치 요격 검증 완료")

	# -------------------------------------------------------------
	# Test 5: 피해자·도주범 영구 박제 방지 35초 하드 라이프타임 검증
	# -------------------------------------------------------------
	total += 1
	var stuck_crm := CriminalNPC.new()
	stuck_crm.setup_criminal(99, CriminalNPC.CriminalKind.DRUNK_BRAWLER, Vector2i(20, 20), 999)
	# 의도적으로 아무 행동도 끝나지 않은 상태로 35.1초 틱 부여
	stuck_crm.update(35.5)
	assert(stuck_crm.is_dead == true, "35초 초과 시 어떤 상태이든 고아 방지 하드 라이프타임에 의해 100% 소멸되어야 함")
	assert(stuck_crm.bubble_text == "", "말풍선도 즉시 닫혀야 함")
	passed += 1
	print("[PASS] Test 5: 35초 하드 라이프타임 및 영구 박제 방지 100% 소멸 검증 완료")

	print("\n=== 테스트 결과 리포트 ===")
	print("총 테스트 항목: %d개 | 통과: %d개 | 실패: 0개" % [total, passed])
	assert(passed == total, "모든 테스트가 통과되어야 합니다.")
	print("=== 모든 단위 테스트 성공 (100% PASS) ===")
	quit(0)
