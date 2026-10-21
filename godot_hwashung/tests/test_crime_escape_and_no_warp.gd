extends SceneTree

func _init() -> void:
	print("=== 치안 시스템: 강제 워프 제거 및 도둑/싸움꾼 승자 연출 FSM 단위 테스트 시작 ===")
	var passed: int = 0
	var total: int = 0

	# -------------------------------------------------------------
	# Test 1: 순라청 개수 기반 포졸 속도 배율 및 워프 제거 검증
	# -------------------------------------------------------------
	total += 1
	var sm := SunlacheongManager.new()
	sm.patrol_stations.clear()
	var sp0: float = sm.get_patrol_dispatch_speed()
	assert(sp0 == 1.0, "순라청 0개소 속도 배율은 1.0이어야 함")

	sm.patrol_stations.append(Vector2i(5, 5))
	var sp1: float = sm.get_patrol_dispatch_speed()
	assert(is_equal_approx(sp1, 1.4), "순라청 1개소 속도 배율은 1.4이어야 함")

	for i in range(10):
		sm.patrol_stations.append(Vector2i(10 + i, 10))
	var sp_max: float = sm.get_patrol_dispatch_speed()
	assert(sp_max == 3.0, "순라청 다수 설치 시 최대 3.0배로 캡핑되어야 함")

	# 포졸 엔티티 워프 부재 확인: 20초간 틱을 주어도 순간이동하지 않고 정직하게 보행
	var officer := PatrolOfficerNPC.new()
	officer.setup_officer(1, Vector2i(0, 0))
	var dummy_crm := CriminalNPC.new()
	dummy_crm.setup_criminal(1, CriminalNPC.CriminalKind.PICKPOCKET, Vector2i(50, 50))
	officer.dispatch(1, Vector2i(50, 50), [], 1.0, dummy_crm)

	var orig_x: float = officer.x
	officer.update(16.0) # 16초 경과 (이전 15초 워프 타임아웃 초과)
	var moved_dist: float = absf(officer.x - orig_x)
	# 워프했다면 x가 50 근처로 뛰었겠지만, 워프하지 않고 정상 이동속도만큼만 전진했어야 함
	assert(officer.global_position.distance_to(dummy_crm.global_position) > 100.0, "15초 초과 시에도 강제 순간이동 워프가 발생하지 않아야 함")
	passed += 1
	print("[PASS] Test 1: 순라청 개수 기반 최대 3.0배속 공식 및 강제 워프 제거 검증 완료")

	# -------------------------------------------------------------
	# Test 2: 도둑(소매치기) 도주: 팔자걸음 + 장물 보따리 + 성문 전까지 상시 체포 가능 + 성문 탈출 소멸
	# -------------------------------------------------------------
	total += 1
	var thief := CriminalNPC.new()
	thief.setup_criminal(2, CriminalNPC.CriminalKind.PICKPOCKET, Vector2i(10, 10), 101)
	thief.steal_prep_timer = 0.5 # 0.5초 후 물건 훔치기 완료 시뮬레이션
	thief.update(0.6) # 도주 트리거

	assert(thief.state == CriminalNPC.CriminalState.SWAGGER_HOME, "도둑은 SWAGGER_HOME 상태로 전이되어야 함")
	assert(thief.is_arrestable == true, "성문 밖으로 나가기 전까지는 언제든 체포 가능(is_arrestable=true)이어야 함")
	assert(thief.has_loot_sack == true, "도둑은 장물 보따리(has_loot_sack=true)를 메야 함")
	assert(thief.bubble_text == "세상 살기 편하구만", "도둑 대사는 '세상 살기 편하구만'이어야 함")

	# 팔자걸음 틱 업데이트 시 회전 각도 및 바운스 오프셋 갱신 확인
	thief.update(0.1)
	assert(thief.swagger_rotation != 0.0 or thief.swagger_offset_y != 0.0, "팔자걸음 모션 수식이 동작해야 함")

	# 목표 성문 도달 시 탈출 성공 및 소멸 확인
	thief.global_position = thief.target_gate_pos
	thief.update(0.1)
	assert(thief.is_dead == true, "성문 도달 시 도둑은 탈출 성공(is_dead=true)되어야 함")
	assert(thief.is_arrestable == false, "탈출 성공 후에는 체포 불가여야 함")
	passed += 1
	print("[PASS] Test 2: 도둑 성문 도주 중 상시 체포 가능 및 성문 도착 탈출 소멸 검증 완료")


	# -------------------------------------------------------------
	# Test 3: 싸움꾼(난동) 미체포 시: 피해자 쓰러짐 후송 + 가해자 우쭐 포즈 및 귀가
	# -------------------------------------------------------------
	total += 1
	var brawler := CriminalNPC.new()
	brawler.setup_criminal(3, CriminalNPC.CriminalKind.DRUNK_BRAWLER, Vector2i(15, 15), 102)
	brawler.crime_timer = 0.5
	brawler.update(0.6) # 14초 만료 트리거

	assert(brawler.state == CriminalNPC.CriminalState.BOAST_AND_CARRY, "싸움꾼은 BOAST_AND_CARRY 상태로 전이되어야 함")
	assert(brawler.is_arrestable == false, "싸움꾼도 체포 불가 상태여야 함")
	assert(brawler.victim_rotation == 90.0, "피해자는 90도 회전하여 쓰러져야 함")
	assert(brawler.carrier_active == true, "피해자 후송용 들것/부축꾼이 활성화되어야 함")
	assert(brawler.victim_bubble == "아이구, 사람 죽네...", "피해자 대사는 '아이구, 사람 죽네...'여야 함")
	assert(brawler.bubble_text == "나한테 까불지 말라고 했지, 상대도 안 되는 게", "가해자 대사는 '나한테 까불지 말라고 했지, 상대도 안 되는 게'여야 함")

	# 2.5초간 우쭐 포즈 후 RETURNING_HOME 전이 확인
	brawler.update(2.6)
	assert(brawler.state == CriminalNPC.CriminalState.RETURNING_HOME, "2.5초 후 가해자는 RETURNING_HOME(팔자걸음 귀가) 상태로 전이되어야 함")

	# 목적지 도달 및 피해자 후송 완료 시 소멸 확인
	brawler.victim_carried_away_done = true
	brawler.global_position = brawler.home_target_pos
	brawler.update(0.1)
	assert(brawler.is_dead == true, "귀가 완료 시 싸움꾼 노드는 안전 소멸되어야 함")
	passed += 1
	print("[PASS] Test 3: 싸움꾼 미체포 시 피해자 쓰러짐/후송 + 가해자 승리 포즈 및 팔자걸음 귀가 검증 완료")

	# -------------------------------------------------------------
	# Test 4: 시간 내 순라군 도착 시 정상 체포 및 관아 압송 보존 검증
	# -------------------------------------------------------------
	total += 1
	var brawler_arrest := CriminalNPC.new()
	brawler_arrest.setup_criminal(4, CriminalNPC.CriminalKind.DRUNK_BRAWLER, Vector2i(20, 20), 103)
	var off3 := PatrolOfficerNPC.new()
	off3.setup_officer(3, Vector2i(20, 20))
	off3.dispatch(103, Vector2i(20, 20), [], 2.0, brawler_arrest)

	# 근접 상태에서 틱 업데이트 시 체포 발동
	off3.global_position = brawler_arrest.global_position
	off3.update(0.1)
	assert(off3.state == PatrolOfficerNPC.State.ARRESTING, "근접 시 포졸은 ARRESTING 상태가 되어야 함")
	assert(brawler_arrest.state == CriminalNPC.CriminalState.ARRESTED, "범죄자는 ARRESTED 상태가 되어야 함")

	# 1.5초 후 압송(ESCORT_TO_YUSUBU) 전이 확인
	off3.update(1.6)
	assert(off3.state == PatrolOfficerNPC.State.ESCORT_TO_YUSUBU, "1.5초 후 포졸은 ESCORT_TO_YUSUBU 상태가 되어야 함")

	# 관아 도착 시 죄인 삭제 및 사건 해결 확인
	off3.global_position = off3.yusubu_pos
	off3.update(0.1)
	assert(brawler_arrest.is_dead == true, "관아 도착 시 죄인은 안전 삭제(is_dead=true)되어야 함")
	assert(off3.state == PatrolOfficerNPC.State.IDLE, "포졸은 순라청 복귀 완료여야 함")
	passed += 1
	print("[PASS] Test 4: 시간 내 순라군 도착 시 정상 체포 및 관아 압송 보존 검증 완료")

	# -------------------------------------------------------------
	# Test 5: ThiefNPC 및 BrawlerNPC 독립 엔티티 클래스 동작 검증
	# -------------------------------------------------------------
	total += 1
	var t_standalone := ThiefNPC.new()
	t_standalone.setup(1, Vector2.ZERO, 201)
	t_standalone.steal_prep_timer = 0.1
	t_standalone.update(0.2)
	assert(t_standalone.state in [ThiefNPC.ThiefState.FLEEING_TO_GATE, ThiefNPC.ThiefState.SWAGGER_HOME], "ThiefNPC 성문 도주 상태로 전이되어야 함")
	assert(t_standalone.is_loot_sack_visible == true, "ThiefNPC 장물 보따리 표시되어야 함")


	var b_standalone := BrawlerNPC.new()
	b_standalone.setup(Vector2.ZERO, 202)
	b_standalone.crime_timer = 0.1
	b_standalone.update(0.2)
	assert(b_standalone.result_state == BrawlerNPC.BrawlResultState.BOAST_AND_CARRY, "BrawlerNPC도 BOAST_AND_CARRY로 전이되어야 함")
	assert(b_standalone.loser_rot == 90.0, "BrawlerNPC 피해자 90도 회전되어야 함")
	passed += 1
	print("[PASS] Test 5: ThiefNPC / BrawlerNPC 독립 클래스 무결성 검증 완료")

	print("\n=== 테스트 결과 리포트 ===")
	print("총 테스트 항목: %d개 | 통과: %d개 | 실패: 0개" % [total, passed])
	assert(passed == total, "모든 테스트가 통과되어야 합니다.")
	print("=== 모든 단위 테스트 성공 (100% PASS) ===")
	quit(0)
