extends SceneTree

func _init() -> void:
	print("=== 성 밖 도둑 및 성문 미완공 탈출, 성 밖 순라청 요격 시스템 단위 테스트 시작 ===")
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

	# 성 안(10..30)과 성 밖(그 외) 설정
	for y in range(40):
		for x in range(40):
			if x < 10 or x > 30 or y < 10 or y > 30:
				grid.grid[y][x]["terrain"] = "outside"

	# 관아 설치
	grid.grid[20][20]["building"] = "gwana"

	# -------------------------------------------------------------
	# Test 1: 성 밖(terrain == "outside") 도둑 스폰 시 성문 대신 맵 가장자리로 탈출 검증
	# -------------------------------------------------------------
	total += 1
	# 성문(장안문) 완공 설치 (20, 10)
	grid.grid[10][20]["building"] = "jangan_mun"

	var gate_pos_expected := Vector2((20.0 - 10.0) * 32.0, (20.0 + 10.0) * 16.0)

	# 성 밖 상점 위치 (5, 5) - 성문보다 맵 서북 경계(0, 5)에 훨씬 가까움
	var outside_spawn := Vector2i(5, 5)
	var outside_world_pos := Vector2((5.0 - 5.0) * 32.0, (5.0 + 5.0) * 16.0)

	var target_escape: Vector2 = BuildingManager.get_thief_escape_target_world_pos(outside_world_pos, grid)

	# 성 밖 도둑은 성문(jangan_mun)으로 가지 않아야 함!
	assert(target_escape != gate_pos_expected, "성 밖 도둑은 성문으로 도망치지 않아야 함")
	# 맵 외곽 테두리 밖 좌표로 지정되었는지 확인 (경계 밖 좌표는 음수이거나 40 초과)
	var esc_tx: float = (target_escape.x / 32.0 + target_escape.y / 16.0) / 2.0
	var esc_ty: float = (target_escape.y / 16.0 - target_escape.x / 32.0) / 2.0
	assert(esc_tx < 0.0 or esc_tx > 39.0 or esc_ty < 0.0 or esc_ty > 39.0, "성 밖 도둑의 탈출 지점은 맵 가장자리 밖이어야 함")

	# CriminalNPC와 ThiefNPC setup 검증
	var crm := CriminalNPC.new()
	crm.setup_criminal(101, CriminalNPC.CriminalKind.PICKPOCKET, outside_spawn, -1, grid)
	assert(crm.target_gate_pos != gate_pos_expected, "CriminalNPC 도둑의 탈출 좌표도 성문이 아닌 맵 외곽이어야 함")

	var thf := ThiefNPC.new()
	thf.setup(201, outside_world_pos, -1, grid)
	assert(thf.target_gate_pos != gate_pos_expected, "ThiefNPC 도둑의 탈출 좌표도 성문이 아닌 맵 외곽이어야 함")

	passed += 1
	print("[PASS] Test 1: 성 밖 도둑 스폰 시 성문 대신 맵 가장자리로 탈출 검증 완료")

	# -------------------------------------------------------------
	# Test 2: 성문 미완공(성문 0개 또는 공사 중) 시 성내 도둑이 길 없는 외곽/야산으로 탈출 검증
	# -------------------------------------------------------------
	total += 1
	# 성문 철거(또는 공사 중 설정)
	grid.grid[10][20]["building"] = "jangan_mun"
	grid.grid[10][20]["under_construction"] = true # 미완공 공사 중

	var inside_spawn := Vector2i(15, 15)
	var inside_world_pos := Vector2((15.0 - 15.0) * 32.0, (15.0 + 15.0) * 16.0)

	var target_no_gate: Vector2 = BuildingManager.get_thief_escape_target_world_pos(inside_world_pos, grid)
	assert(target_no_gate != gate_pos_expected, "미완공 성문으로는 도둑이 탈출할 수 없어야 함")

	var ng_tx: float = (target_no_gate.x / 32.0 + target_no_gate.y / 16.0) / 2.0
	var ng_ty: float = (target_no_gate.y / 16.0 - target_no_gate.x / 32.0) / 2.0
	assert(ng_tx < 0.0 or ng_tx > 39.0 or ng_ty < 0.0 or ng_ty > 39.0, "성문이 없을 때 도둑은 길 없는 맵 외곽으로 도망가야 함")

	passed += 1
	print("[PASS] Test 2: 성문 미완공 시 성내 도둑의 길 없는 외곽 도주 검증 완료")

	# -------------------------------------------------------------
	# Test 3: 성문 완공 시 성내 도둑이 가장 가까운 성문으로 정상 도주 검증
	# -------------------------------------------------------------
	total += 1
	# 성문 정상 완공
	grid.grid[10][20].erase("under_construction")

	var target_with_gate: Vector2 = BuildingManager.get_thief_escape_target_world_pos(inside_world_pos, grid)
	assert(target_with_gate == gate_pos_expected, "성내 도둑은 완공된 성문이 있을 때 성문으로 도주해야 함")

	passed += 1
	print("[PASS] Test 3: 성문 완공 시 성내 도둑의 성문 도주 검증 완료")

	# -------------------------------------------------------------
	# Test 4: 성 밖 순라청 우선 요격 출동 검증
	# -------------------------------------------------------------
	total += 1
	var sm := SunlacheongManager.new()
	sm.patrol_stations.clear()

	# 성내 순라청 (20, 20) 및 성 밖 순라청 (4, 4) 등록
	sm.patrol_stations.append(Vector2i(20, 20)) # 성내
	sm.patrol_stations.append(Vector2i(4, 4))   # 성 밖

	# 성 밖 도둑 (5, 5) 발생 시뮬레이션
	var out_crm := CriminalNPC.new()
	out_crm.setup_criminal(102, CriminalNPC.CriminalKind.PICKPOCKET, Vector2i(5, 5), -1, grid)

	# 성 밖 도둑의 도주를 막기 위해 성 밖 순라청(4, 4)이 우선 출동해야 함!
	sm.dispatch_police_for_thief(out_crm, out_crm.target_gate_pos)
	assert(sm.officer_pool.size() >= 1, "출동 포졸이 할당되어야 함")
	var dispatched_off: PatrolOfficerNPC = sm.officer_pool[0]
	assert(dispatched_off.home_pos == Vector2i(4, 4), "성 밖 도둑에 대해 성 밖 순라청(4, 4)이 최우선 출동해야 함")

	passed += 1
	print("[PASS] Test 4: 성 밖 순라청 우선 요격 출동 검증 완료")

	# -------------------------------------------------------------
	# Test 5: 성 밖 도둑 체포 및 관아 압송 라이프사이클 검증
	# -------------------------------------------------------------
	total += 1
	assert(out_crm.is_arrestable == true, "탈출 전까지 체포 가능 상태여야 함")
	assert(dispatched_off.state == PatrolOfficerNPC.State.MOVE_TO_CRIME, "포졸이 현장 출동 중이어야 함")

	# 포졸이 성 밖 도둑에게 접근하여 체포
	dispatched_off.global_position = out_crm.global_position
	dispatched_off._process_arrest_logic(0.1)
	assert(out_crm.state == CriminalNPC.CriminalState.ARRESTED, "포졸 접근 시 도둑이 ARRESTED 포박 상태로 전이되어야 함")

	# 1.5초 후 압송 상태 전이
	dispatched_off._process_arrest_logic(1.6)
	assert(dispatched_off.state == PatrolOfficerNPC.State.ESCORT_TO_YUSUBU, "포박 후 관아 압송 상태로 전이되어야 함")

	# 관아 도달 시 도둑 삭제 및 사건 종료
	dispatched_off.global_position = dispatched_off.yusubu_pos
	dispatched_off._process_arrest_logic(0.1)
	assert(out_crm.is_dead == true, "관아 도달 시 범죄자가 완전히 삭제(is_dead)되어야 함")

	passed += 1
	print("[PASS] Test 5: 성 밖 도둑 체포 및 관아 압송 라이프사이클 검증 완료")

	print("\n===========================================")
	print("단위 테스트 결과: %d/%d 통과 (100%% PASS)" % [passed, total])
	print("===========================================")
	quit()
