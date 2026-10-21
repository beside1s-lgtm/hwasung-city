extends SceneTree

## [QA TEST] 가운데 흰색 추천 팝업 폐기, 구선복/인재/친림 1회성 락 및 상단 알림 10초 큐 검증

func _init() -> void:
	print("=== [QA TEST] 팝업 일원화, 이벤트 1회성 락 & 상단 알림 큐 검증 개시 ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var all_pass: bool = true

	# -------------------------------------------------------------
	# 1. 상단 빨간 알림 박스 (TopAlertBanner) 10초 유지 및 수동 닫기 큐 검증
	# -------------------------------------------------------------
	print("[TEST 1] TopAlertBanner 10초 유지 및 큐잉 동작 검증...")
	var banner := TopAlertBanner.new()
	root.add_child(banner)
	await process_frame
	await process_frame

	if banner.DISPLAY_DURATION < 10.0:
		printerr("[FAIL] 알림 지속 시간이 10초 미만: ", banner.DISPLAY_DURATION)
		all_pass = false

	banner.push_alert("첫 번째 알림: 화적 출몰")
	banner.push_alert("두 번째 알림: 장마 대비")

	if not banner.visible or not banner._is_showing:
		printerr("[FAIL] push_alert 후 배너가 활성화되지 않음")
		all_pass = false

	if not banner.message_label.text.contains("첫 번째 알림") or not banner.message_label.text.contains("외 1건 대기 중"):
		printerr("[FAIL] 대기 중 건수 또는 첫 번째 알림 텍스트 불일치: ", banner.message_label.text)
		all_pass = false

	# 중복 메시지 방어 검증
	banner.push_alert("두 번째 알림: 장마 대비") # 직전 큐와 동일 메시지
	if banner._alert_queue.size() != 1:
		printerr("[FAIL] 중복 메시지가 큐에 중복 적재됨: ", banner._alert_queue.size())
		all_pass = false

	# 수동 [닫기 ✕] 버튼 클릭 시뮬레이션
	banner._on_close_pressed()
	if not banner.message_label.text.begins_with("두 번째 알림: 장마 대비"):
		printerr("[FAIL] 닫기 클릭 후 두 번째 알림으로 전환되지 않음: ", banner.message_label.text)
		all_pass = false

	# 마지막 알림 닫기
	banner._on_close_pressed()
	if banner.visible or banner._is_showing:
		printerr("[FAIL] 모든 알림 소진 후 배너가 닫히지 않음")
		all_pass = false

	banner.queue_free()
	print("[PASS] TopAlertBanner 검증 완료!")

	# -------------------------------------------------------------
	# 2. 구선복의 난 1회성 락 (One-Shot Flag) 검증
	# -------------------------------------------------------------
	print("[TEST 2] 구선복의 난 및 고유 이벤트 1회성 락 검증...")
	var event_mgr := EventManager.new()
	root.add_child(event_mgr)
	await process_frame

	if not event_mgr.can_trigger_event("gu_seon_bok_dilemma"):
		printerr("[FAIL] 초기 상태에서 gu_seon_bok_dilemma 트리거 불가 판정")
		all_pass = false

	event_mgr.mark_event_triggered("gu_seon_bok_dilemma")

	if event_mgr.can_trigger_event("gu_seon_bok_dilemma"):
		printerr("[FAIL] mark_event_triggered 후에도 재발동이 허용됨")
		all_pass = false

	if not event_mgr.is_gu_seon_bok_resolved:
		printerr("[FAIL] is_gu_seon_bok_resolved 플래그가 true로 설정되지 않음")
		all_pass = false

	var sim := SimulationCore.new()
	sim.is_gu_seon_bok_resolved = true
	var dilemmas := NewspaperSystem.dilemma_pool(sim)
	for d in dilemmas:
		if d.get("id", "") == "gu_seon_bok_dilemma":
			printerr("[FAIL] is_gu_seon_bok_resolved=true 인데 딜레마 풀에 구선복이 포함됨")
			all_pass = false

	print("[PASS] 구선복의 난 1회성 락 검증 완료!")

	# -------------------------------------------------------------
	# 3. 인재 등용 상태 동기화 및 중복 등용 차단 검증
	# -------------------------------------------------------------
	print("[TEST 3] 인재 등용 상태 동기화 및 중복 등용 차단 검증...")
	sim.gold = 5000
	sim.retainers = {
		"jeong_yakyong": false,
		"chae_jegong": false,
		"baek_dongsu": false
	}
	ScholarManager.hired_scholars.clear()

	var court := CourtSystem.new()
	court.sim = sim

	# 첫 등용 시도
	var hire_success: bool = ScholarManager.hire_scholar("jeong_yakyong", sim, court)
	if not hire_success:
		printerr("[FAIL] ScholarManager.hire_scholar 실패")
		all_pass = false

	if not sim.retainers.get("jeong_yakyong", false) or not ScholarManager.is_scholar_hired("jeong_yakyong", sim.retainers):
		printerr("[FAIL] 등용 후 인재 상태 미반영")
		all_pass = false

	# 중복 등용 시도 (차단되어야 함)
	var dup_hire: bool = ScholarManager.hire_scholar("jeong_yakyong", sim, court)
	if dup_hire:
		printerr("[FAIL] 이미 등용된 인재의 중복 등용이 성공함")
		all_pass = false

	var court_msg: String = court.hire_candidate("jeong")
	if court_msg != "이미 조정에 등용된 인재이옵니다.":
		printerr("[FAIL] CourtSystem에서 이미 등용된 인재 중복 등용 차단 실패: ", court_msg)
		all_pass = false

	print("[PASS] 인재 등용 상태 동기화 및 중복 차단 검증 완료!")

	# -------------------------------------------------------------
	# 4. 가운데 흰색 추천 팝업 전면 비활성화 검증
	# -------------------------------------------------------------
	print("[TEST 4] 가운데 흰색 추천 팝업(scholar, tomb_visit, crown_prince, dilemma) 비활성화 검증...")
	event_mgr.enqueue_scholar({"id": "chae", "name": "번암 채제공"})
	event_mgr.enqueue_royal_tomb(court, sim)
	event_mgr.enqueue_crown_prince({"stage": 1})
	event_mgr.enqueue_dilemma({"title": "테스트 딜레마"})

	# 이벤트 펌프
	while not event_mgr.event_queue.is_empty() or event_mgr.is_displaying_event:
		event_mgr._process(0.5)
		await process_frame
		if event_mgr.is_displaying_event:
			# 가운데 흰색 패널이나 모달이 활성화되었는지 검사
			if event_mgr._generic_modal and event_mgr._generic_modal.visible:
				printerr("[FAIL] 가운데 흰색 GenericEventModal이 노출됨!")
				all_pass = false
			if event_mgr._scholar_popup and event_mgr._scholar_popup.visible:
				printerr("[FAIL] 가운데 흰색 ScholarDiscoveryPopup이 노출됨!")
				all_pass = false
			if event_mgr._royal_tomb_popup and event_mgr._royal_tomb_popup.visible:
				printerr("[FAIL] 가운데 흰색 RoyalTombVisitPopup이 노출됨!")
				all_pass = false
			if event_mgr._crown_prince_popup and event_mgr._crown_prince_popup.visible:
				printerr("[FAIL] 가운데 흰색 CrownPrinceEventPopup이 노출됨!")
				all_pass = false
			event_mgr.on_event_resolved()

	event_mgr.queue_free()
	print("[PASS] 가운데 흰색 추천 팝업 비활성화 검증 완료!")

	# -------------------------------------------------------------
	# 최종 검증 판정
	# -------------------------------------------------------------
	if all_pass:
		print("=== [QA TEST SUCCESS] 모든 테스트 통과 (PASS) ===")
		quit(0)
	else:
		printerr("=== [QA TEST FAILED] 검증 기준 미달 ===")
		quit(1)
