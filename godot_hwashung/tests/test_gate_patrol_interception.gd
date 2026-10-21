extends SceneTree

func _init() -> void:
	print("=== 성문 근처 순라청 요격 및 도둑 다중 포위망 체포 시스템 정밀 검증 시작 ===")
	var passed: int = 0
	var total: int = 0

	var grid := GameGrid.new()
	grid.size = 40
	grid.grid = []
	for y in range(40):
		var row: Array = []
		for x in range(40):
			row.append({
				"terrain": "grass",
				"building": ""
			})
		grid.grid.append(row)

	# 관아 설치 (20, 20)
	grid.grid[20][20]["building"] = "gwana"
	# 성문(장안문) 완공 설치 (20, 5)
	grid.grid[5][20]["building"] = "jangan_mun"
	var gate_world_pos := Vector2((20.0 - 5.0) * 32.0, (20.0 + 5.0) * 16.0)

	# 저잣거리 상점 5개소 설치 (15, 15) 주변
	for i in range(5):
		grid.grid[15][13 + i]["building"] = "com_1"

	var sm := SunlacheongManager.new()

	# -------------------------------------------------------------
	# Test 1: 성문 근처 순라청 대량 건설 시 실시간 캐시 동기화 검증
	# -------------------------------------------------------------
	total += 1
	# 성문 근처에 순라청 4개소 및 저잣거리 근처에 1개소 건설 (총 5개소)
	grid.grid[6][20]["building"] = "patrol" # 성문 바로 앞 (20, 6)
	grid.grid[6][21]["building"] = "patrol" # 성문 옆 (21, 6)
	grid.grid[5][19]["building"] = "patrol" # 성문 옆 (19, 5)
	grid.grid[7][20]["building"] = "patrol" # 성문 앞길 (20, 7)
	grid.grid[16][16]["building"] = "patrol" # 저잣거리 근처 (16, 16)

	# update_system 호출 시 그리드에서 5개소 순라청이 즉시 동기화되는지 검증
	sm.update_system(0.1, null, grid, null)
	assert(sm.patrol_stations.size() == 5, "성문 근처 대량 건설된 순라청 5개소가 즉시 동기화되어야 함")
	passed += 1
	print("[PASS] Test 1: 순라청 대량 건설 시 update_system 실시간 캐시 동기화 검증 완료")

	# -------------------------------------------------------------
	# Test 2: 도둑 스폰 시 성문 길목 순라청 1차 요격 + 저잣거리 순라청 2차 협공 포위망 출동 검증
	# -------------------------------------------------------------
	total += 1
	sm.crime_cooldown_timer = 0.0
	sm.active_events.clear()
	sm.active_criminals.clear()

	# 도둑 사건 발생 트리거
	var ev := MarketDisputeEvent.new()
	ev.setup_event(1, MarketDisputeEvent.DisputeType.PICKPOCKET, Vector2i(15, 15))
	assert(ev.max_time >= 25.0, "도둑 이벤트는 성문 추격전을 위해 28.0초 안전 시간을 가져야 함")
	sm.active_events.append(ev)

	var thief := CriminalNPC.new()
	thief.setup_criminal(1, CriminalNPC.CriminalKind.PICKPOCKET, Vector2i(15, 15), ev.event_id, grid)
	assert(thief.target_gate_pos == gate_world_pos, "도둑의 탈출 목표는 장안문이어야 함")
	sm.active_criminals.append(thief)

	# 출동 실행
	sm.dispatch_police_for_thief(thief, thief.target_gate_pos, ev)

	# 이벤트와 출동 포졸 ID 정상 연결 검증
	assert(ev.assigned_officer_id >= 0, "이벤트에 출동 포졸 ID가 바인딩되어야 함")
	var lead_off: PatrolOfficerNPC = null
	for off in sm.officer_pool:
		if off.id == ev.assigned_officer_id:
			lead_off = off
			break
	assert(lead_off != null, "선두 포졸이 존재해야 함")
	assert(lead_off.target_event_id == ev.event_id, "포졸에게 이벤트 ID가 바인딩되어야 함")

	# 1차 요격 포졸은 성문 바로 앞(20, 6 또는 20, 7) 순라청에서 출동해야 함!
	var lead_home: Vector2i = lead_off.home_pos
	assert(lead_home.y <= 7, "1차 요격 포졸은 성문 바로 앞 순라청에서 출동해야 함 (현재: %s)" % str(lead_home))

	# 2차 협공 포졸 검증 (다중 순라청 협공 포위망)
	var active_officers: Array[PatrolOfficerNPC] = []
	for off in sm.officer_pool:
		if off.is_active and off.state == PatrolOfficerNPC.State.MOVE_TO_CRIME:
			active_officers.append(off)
	assert(active_officers.size() >= 2, "성문 길목 차단 + 후방 추격 포위망으로 최소 2명 이상 출동해야 함")

	passed += 1
	print("[PASS] Test 2: 성문 길목 차단 최우선 요격 및 2차 협공 포위망 출동 검증 완료")

	# -------------------------------------------------------------
	# Test 3: 체포 거리 36.0px 반경 낚아채기 및 이벤트 조기 실패 차단 검증
	# -------------------------------------------------------------
	total += 1
	# 도둑이 훔치기 4초 후 성문으로 도주 개시
	thief.steal_prep_timer = 0.0
	thief.update(0.1)
	assert(thief.state == CriminalNPC.CriminalState.SWAGGER_HOME, "도둑이 도주 상태여야 함")
	assert(thief.is_arrestable == true, "성문 도착 전까지 상시 체포 가능 상태여야 함")

	# 성문 근처 순라청 포졸이 마주 보며 접근하여 30px 거리에서 조우
	lead_off.global_position = thief.global_position + Vector2(30.0, 0.0)
	lead_off._process_arrest_logic(0.1)

	# 36.0px 반경 내 도달 시 즉시 체포되어야 함
	assert(lead_off.state == PatrolOfficerNPC.State.ARRESTING, "36.0px 이내 접근 시 포졸이 ARRESTING 상태로 전이되어야 함")
	assert(thief.state == CriminalNPC.CriminalState.ARRESTED, "도둑이 즉시 포박(ARRESTED)되어야 함")

	# update_officers 호출 시 이벤트가 SUPPRESSED로 마감되어 15초 강제 실패가 방지되어야 함
	sm._update_officers(0.1, grid, null)
	assert(ev.state == MarketDisputeEvent.EventState.SUPPRESSED, "포졸이 도둑을 체포하면 이벤트가 SUPPRESSED로 전이되어야 함")

	passed += 1
	print("[PASS] Test 3: 체포 거리 36.0px 낚아채기 및 이벤트 조기 실패 차단 검증 완료")

	# -------------------------------------------------------------
	# Test 4: 15초 경과 후에도 억울한 치안 실패(페널티) 방지 검증
	# -------------------------------------------------------------
	total += 1
	# 15초 경과 시뮬레이션
	sm._update_active_events(16.0, null, grid, null)
	assert(ev.state != MarketDisputeEvent.EventState.FAILED, "도둑이 체포되었으므로 15초가 지나도 FAILED가 되지 않아야 함")

	passed += 1
	print("[PASS] Test 4: 체포 진행 중 15초 경과 시 억울한 치안 실패 방지 검증 완료")

	# -------------------------------------------------------------
	# Test 5: 관아 압송 완료 및 범죄자 완전 제거, 40초 쿨타임 가동 검증
	# -------------------------------------------------------------
	total += 1
	# 1.5초 결박 후 관아 압송 전이
	lead_off._process_arrest_logic(1.6)
	assert(lead_off.state == PatrolOfficerNPC.State.ESCORT_TO_YUSUBU, "관아 압송 상태로 전이되어야 함")

	# 관아 정문 도착 시뮬레이션
	lead_off.global_position = lead_off.yusubu_pos
	lead_off._process_arrest_logic(0.1)
	assert(thief.is_dead == true, "관아 도달 시 도둑 노드가 완전히 삭제(is_dead)되어야 함")
	assert(sm.crime_cooldown_timer == 40.0, "사건 해결 후 40초 전역 쿨타임이 가동되어야 함")

	passed += 1
	print("[PASS] Test 5: 관아 압송 완료 및 도둑 완전 제거, 40초 쿨타임 가동 검증 완료")

	print("\n===========================================")
	print("단위 테스트 결과: %d/%d 통과 (100%% PASS)" % [passed, total])
	print("===========================================")
	quit()
