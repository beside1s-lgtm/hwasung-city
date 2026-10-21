extends SceneTree

## [이벤트 팝업 대기열 및 조작 안전성 통합 검증 테스트]
## 1. 우선순위 FIFO 큐 정렬 검증 (재난 1 > 친림/서연 2 > 인재/딜레마 3 > 시보 4)
## 2. 플레이어 조작/건설 중 팝업 보류 및 유휴(Idle) 시 순차 팝업 검증
## 3. 오클릭 차단 가드 (모달 활성 시 타일 클릭/카메라 팬 차단) 검증
## 4. 순차 팝업 및 0.2초 여백 딜레이 검증
## 5. 이벤트 증발(Starvation) 방지 100% 처리 검증

func _init() -> void:
	print("=== [TEST] 이벤트 대기열 및 조작 안전성 통합 검증 시작 ===")
	_run_tests()

func _run_tests() -> void:
	var total_passed: int = 0
	var total_tests: int = 0

	# 1. 우선순위 큐 정렬 테스트
	total_tests += 1
	if _test_priority_queue_ordering():
		total_passed += 1
		print("  [PASS] 1. 우선순위 큐 정렬 (재난 > 친림 > 인재 > 시보 & 동일 우선순위 FIFO) 검증 완료")
	else:
		printerr("  [FAIL] 1. 우선순위 큐 정렬 실패")

	# 2. 플레이어 건설/조작 중 팝업 보류 및 유휴 감지 테스트
	total_tests += 1
	if _test_player_busy_and_idle_guard():
		total_passed += 1
		print("  [PASS] 2. 플레이어 건설/드래그/입력 중 팝업 보류 및 유휴 후 트리거 검증 완료")
	else:
		printerr("  [FAIL] 2. 플레이어 조작 중 팝업 보류 실패")

	# 3. 입력 차단막(Input Barrier) 및 오클릭 방어 테스트
	total_tests += 1
	if _test_modal_input_barrier_guard():
		total_passed += 1
		print("  [PASS] 3. 모달 활성 시 월드 타일 오클릭/카메라 입력 차단 가드 검증 완료")
	else:
		printerr("  [FAIL] 3. 입력 차단막 방어 실패")

	# 4. 순차 실행 및 0.2초 여백 전이 테스트
	total_tests += 1
	if _test_sequential_pump_and_delay():
		total_passed += 1
		print("  [PASS] 4. 순차 팝업 실행(1회 1개) 및 0.2초 여백 딜레이 검증 완료")
	else:
		printerr("  [FAIL] 4. 순차 실행 및 딜레이 실패")

	# 5. 이벤트 누락/증발(Starvation) 방지 전수 처리 테스트
	total_tests += 1
	if _test_zero_starvation_guarantee():
		total_passed += 1
		print("  [PASS] 5. 이벤트 증발 없는 100% 전수 순차 처리 검증 완료")
	else:
		printerr("  [FAIL] 5. 이벤트 증발 방지 검증 실패")

	print("\n=== [TEST RESULT] 총 %d개 테스트 중 %d개 성공 ===" % [total_tests, total_passed])
	if total_passed == total_tests:
		print(">>> 모든 이벤트 팝업 대기열 및 조작 안전성 검증을 100% 통과했습니다. (ALL PASS) <<<")
		quit(0)
	else:
		printerr(">>> 일부 검증에 실패했습니다. (FAIL) <<<")
		quit(1)

## 1. 우선순위 정렬 및 동일 우선순위 FIFO 보존 검증
func _test_priority_queue_ordering() -> bool:
	var em: EventManager = EventManager.new()

	# 뒤섞인 순서로 유입: 시보(4) -> 인재A(3) -> 친림(2) -> 재난(1) -> 인재B(3)
	em.enqueue_event({"id": "sibo_1", "priority": EventManager.PRIORITY_LOW, "type": "sibo"})
	em.enqueue_event({"id": "scholar_A", "priority": EventManager.PRIORITY_NORMAL, "type": "scholar"})
	em.enqueue_event({"id": "tomb_1", "priority": EventManager.PRIORITY_URGENT, "type": "tomb_visit"})
	em.enqueue_event({"id": "disaster_1", "priority": EventManager.PRIORITY_CRITICAL, "type": "disaster"})
	em.enqueue_event({"id": "scholar_B", "priority": EventManager.PRIORITY_NORMAL, "type": "scholar"})

	if em.event_queue.size() != 5:
		em.free()
		return false

	# 기대 순서:
	# 1: disaster_1 (Priority 1)
	# 2: tomb_1 (Priority 2)
	# 3: scholar_A (Priority 3, A가 B보다 먼저 유입)
	# 4: scholar_B (Priority 3)
	# 5: sibo_1 (Priority 4)
	var expected_ids: Array[String] = ["disaster_1", "tomb_1", "scholar_A", "scholar_B", "sibo_1"]
	for i: int in range(5):
		if str(em.event_queue[i]["id"]) != expected_ids[i]:
			printerr("  - 순서 불일치: index %d expected %s got %s" % [i, expected_ids[i], em.event_queue[i]["id"]])
			em.free()
			return false

	em.free()
	return true

## 2. 플레이어 조작 중 팝업 보류 및 유휴 감지 검증
func _test_player_busy_and_idle_guard() -> bool:
	var im: InputManager = InputManager.new()
	var em: EventManager = EventManager.new()
	em.input_mgr = im

	em.enqueue_disaster("화재 발생", "민가에서 불길이 치솟습니다.")

	# 시나리오 A: 마우스 입력 직후 (유휴 시간 0.1초) -> 팝업 불가
	im.idle_time = 0.1
	if im.is_player_busy() != true or em.can_show_next_event() != false:
		im.free()
		em.free()
		return false

	# 시나리오 B: 마우스 버튼 누름 상태 -> 팝업 불가
	im.idle_time = 1.0
	im.is_mouse_down = true
	if im.is_player_busy() != true or em.can_show_next_event() != false:
		im.free()
		em.free()
		return false
	im.is_mouse_down = false

	# 시나리오 C: 건설 모드 활성화 (BuildManager) -> 팝업 불가
	var mock_city: CityLayer = CityLayer.new()
	mock_city.current_tool = "road" # 도로 배치 모드
	BuildManager.city_layer = mock_city
	if BuildManager.is_building_mode != true:
		mock_city.free()
		im.free()
		em.free()
		return false
	if em.can_show_next_event() != false:
		mock_city.free()
		im.free()
		em.free()
		return false

	# 시나리오 D: 조사 모드로 복귀 및 유휴 0.5초 경과 -> 팝업 허용
	mock_city.current_tool = "inspect"
	im.idle_time = 0.5
	if im.is_player_busy() != false:
		mock_city.free()
		im.free()
		em.free()
		return false
	if em.can_show_next_event() != true:
		mock_city.free()
		im.free()
		em.free()
		return false

	mock_city.free()
	im.free()
	em.free()
	return true

## 3. 모달 입력 차단막 및 오클릭 방어 검증
func _test_modal_input_barrier_guard() -> bool:
	var em: EventManager = EventManager.new()
	root.add_child(em)

	# 팝업 전: 모달 비활성 상태
	if EventManager.has_active_modal() != false:
		em.queue_free()
		return false

	em.enqueue_disaster("도적 출현", "변방에서 도적이 접근 중입니다.")
	em._pump_next_event()

	# 팝업 활성화 후: has_active_modal() true 및 Dimmer 활성화
	if EventManager.has_active_modal() != true:
		em.queue_free()
		return false

	if em._backdrop_dimmer == null or em._backdrop_dimmer.visible != true:
		em.queue_free()
		return false

	if em._backdrop_dimmer.mouse_filter != Control.MOUSE_FILTER_STOP:
		em.queue_free()
		return false

	# 해결 후: 모달 비활성 복구
	em.on_event_resolved()
	if EventManager.has_active_modal() != false:
		em.queue_free()
		return false
	if em._backdrop_dimmer.visible != false:
		em.queue_free()
		return false

	em.queue_free()
	return true

## 4. 순차 팝업 및 0.2초 여백 딜레이 검증
func _test_sequential_pump_and_delay() -> bool:
	var em: EventManager = EventManager.new()
	root.add_child(em)

	em.enqueue_event({"id": "ev1", "priority": EventManager.PRIORITY_URGENT, "type": "generic", "title": "1번 사건"})
	em.enqueue_event({"id": "ev2", "priority": EventManager.PRIORITY_NORMAL, "type": "generic", "title": "2번 사건"})

	# 첫 번째 이벤트 팝업
	em._pump_next_event()
	if str(em.current_event.get("id", "")) != "ev1":
		em.queue_free()
		return false
	if em.is_displaying_event != true:
		em.queue_free()
		return false

	# 1번 이벤트가 열려 있는 동안은 2번 이벤트가 겹쳐서 뜨지 않음 (1회 1개 강제)
	if em.can_show_next_event() != false:
		em.queue_free()
		return false

	# 1번 이벤트 확인/종료 -> 0.2초 딜레이 타이머 설정
	em.on_event_resolved()
	if em.is_displaying_event != false:
		em.queue_free()
		return false
	if em._pump_delay_timer < 0.19: # 0.2초 여백 딜레이 확인
		em.queue_free()
		return false

	# 딜레이 경과 시뮬레이션
	em._process(0.25)
	# 2번 이벤트가 자동으로 팝업되어야 함
	if str(em.current_event.get("id", "")) != "ev2":
		em.queue_free()
		return false
	if em.is_displaying_event != true:
		em.queue_free()
		return false

	em.on_event_resolved()
	em.queue_free()
	return true

## 5. 이벤트 누락/증발 없는 100% 전수 처리 검증
func _test_zero_starvation_guarantee() -> bool:
	var em: EventManager = EventManager.new()
	root.add_child(em)

	var resolved_order: Array[String] = []
	em.event_resolved.connect(func(ev: Dictionary):
		resolved_order.append(str(ev.get("id", "")))
	)

	var test_count: int = 10
	for i: int in range(test_count):
		var prio: int = (i % 4) + 1
		em.enqueue_event({
			"id": "event_%d" % i,
			"priority": prio,
			"type": "generic"
		})

	if em.event_queue.size() != test_count:
		em.queue_free()
		return false

	# 긴급 건설 상황을 모사하여 10번 모두 대기열에 안전하게 유지되는지 확인
	var im: InputManager = InputManager.new()
	im.idle_time = 0.1 # 플레이어가 바쁨
	em.input_mgr = im

	for _step: int in range(5):
		em._process(0.1)
		# 바쁜 동안에는 대기열 크기가 10개 그대로 보존되어야 함
		if em.event_queue.size() != test_count:
			im.free()
			em.queue_free()
			return false

	# 플레이어 작업 종료 -> 유휴 상태 전환
	im.idle_time = 1.0

	# 10개 이벤트가 순차적으로 모두 처리되는지 확인
	while not em.event_queue.is_empty() or em.is_displaying_event:
		em._process(0.3)
		if em.is_displaying_event:
			em.on_event_resolved()

	if resolved_order.size() != test_count:
		printerr("  - 처리된 이벤트 수 불일치: %d / %d" % [resolved_order.size(), test_count])
		im.free()
		em.queue_free()
		return false

	im.free()
	em.queue_free()
	return true
