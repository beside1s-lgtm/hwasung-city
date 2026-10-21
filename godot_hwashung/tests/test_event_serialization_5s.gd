extends SceneTree

## [검증 테스트] 턴 전환 퀘스트/상황 5초 직렬화 딜레이 엔진 검증
## TopAlertBanner, EventManager, TutorialGuide의 5초 쿨다운 직렬화 동작 확인

const TopAlertBannerClass = preload("res://scripts/TopAlertBanner.gd")
const EventManagerClass = preload("res://scripts/EventManager.gd")
const TutorialGuideClass = preload("res://scripts/TutorialGuide.gd")

func _init() -> void:
	print("=== [테스트 시작] 턴 전환 퀘스트 및 상황 5초 직렬화(Serialization) 검증 ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	_test_top_alert_banner_serialization()
	_test_event_manager_serialization()
	_test_tutorial_guide_serialization()
	print("=== [테스트 완료] 모든 상황/퀘스트 5초 직렬화 전 항목 100% 통과! ===")
	quit(0)

## 1. TopAlertBanner: 닫기 후 5초 뒤 다음 알림 생성 검증
func _test_top_alert_banner_serialization() -> void:
	print("[검증 1] TopAlertBanner 사용자 종료 후 5초 직렬화 검증...")
	var banner := TopAlertBannerClass.new()
	root.add_child(banner)

	# 1) 2개의 알림 순차 등록
	banner.push_alert("삼남대로가 뚫려 보부상이 모여듭니다!")
	banner.push_alert("가을 대풍으로 군량 500석이 수확되었습니다!")

	assert(banner._is_showing == true, "첫 번째 알림이 즉시 표시되지 않음")
	assert(banner.visible == true, "배너가 화면에 보이지 않음")
	assert(banner.message_label.text.contains("외 1건 대기 중"), "대기 중 뱃지 텍스트 누락")

	# 2) 사용자가 닫기 버튼 클릭
	banner._on_close_pressed()

	assert(banner._is_showing == false, "닫기 후 즉시 숨김 실패")
	assert(banner.visible == false, "닫기 후 배너가 여전히 표시됨")
	assert(is_equal_approx(banner._cooldown_timer, 5.0), "5초 쿨다운 타이머 설정 실패: %f" % banner._cooldown_timer)

	# 3) 2.5초 경과 -> 아직 두 번째 알림이 뜨지 않아야 함
	banner._process(2.5)
	assert(banner._is_showing == false, "5초 경과 전 두 번째 알림이 조기 발화됨")
	assert(banner.visible == false, "5초 경과 전 배너가 조기 표시됨")
	assert(is_equal_approx(banner._cooldown_timer, 2.5), "쿨다운 타이머 차감 불일치")

	# 4) 추가 2.6초 경과 (총 5.1초) -> 두 번째 알림 생성
	banner._process(2.6)
	assert(banner._is_showing == true, "5초 후 두 번째 알림이 생성되지 않음")
	assert(banner.visible == true, "5초 후 배너가 표시되지 않음")
	assert(banner.message_label.text.contains("가을 대풍"), "두 번째 알림 내용 불일치: %s" % banner.message_label.text)

	banner.queue_free()
	print("  -> TopAlertBanner 5초 직렬화 검증 통과!")

## 2. EventManager: 이벤트 해결 후 5초 뒤 다음 모달 생성 검증
func _test_event_manager_serialization() -> void:
	print("[검증 2] EventManager 모달 해결 후 5초 직렬화 검증...")
	var ev_mgr := EventManagerClass.new()
	root.add_child(ev_mgr)

	# 1) 2개의 이벤트 큐잉
	ev_mgr.enqueue_disaster("화재 경보", "저잣거리에서 불이 났습니다.")
	ev_mgr.enqueue_disaster("홍수 경보", "수원천이 범람했습니다.")

	# 큐 펌프
	ev_mgr._process(0.1)
	assert(ev_mgr.is_displaying_event == true, "첫 번째 이벤트가 표시되지 않음")
	assert(str(ev_mgr.current_event.get("title", "")) == "화재 경보", "첫 번째 이벤트 불일치")

	# 2) 사용자가 확인/닫기 완료
	ev_mgr.on_event_resolved()

	assert(ev_mgr.is_displaying_event == false, "이벤트 해결 후 상태 리셋 실패")
	assert(is_equal_approx(ev_mgr._pump_delay_timer, 5.0), "이벤트 매니저 5초 딜레이 설정 실패: %f" % ev_mgr._pump_delay_timer)

	# 3) 2.5초 경과 -> 두 번째 이벤트 미발생 확인
	ev_mgr._process(2.5)
	assert(ev_mgr.is_displaying_event == false, "5초 경과 전 두 번째 이벤트가 조기 팝업됨")
	assert(is_equal_approx(ev_mgr._pump_delay_timer, 2.5), "이벤트 딜레이 타이머 차감 불일치")

	# 4) 추가 2.6초 경과 (총 5.1초) -> 두 번째 이벤트 팝업
	ev_mgr._process(2.6)
	assert(ev_mgr.is_displaying_event == true, "5초 후 두 번째 이벤트가 팝업되지 않음")
	assert(str(ev_mgr.current_event.get("title", "")) == "홍수 경보", "두 번째 이벤트 내용 불일치")

	ev_mgr.queue_free()
	print("  -> EventManager 5초 직렬화 검증 통과!")

## 3. TutorialGuide: 조언 확인 후 5초 뒤 다음 조언 생성 검증
func _test_tutorial_guide_serialization() -> void:
	print("[검증 3] TutorialGuide 조언 확인 후 5초 직렬화 검증...")
	var guide := TutorialGuideClass.new()
	root.add_child(guide)

	guide._advice_cooldown = 0.0
	guide._mode = "step"

	# 1) 조언 2개 큐에 적재
	guide._advice_queue.append({"key": "adv_1", "text": "첫 번째 조언", "btn": "", "kind": "", "target": "", "turn": 1, "prio": 10})
	guide._advice_queue.append({"key": "adv_2", "text": "두 번째 조언", "btn": "", "kind": "", "target": "", "turn": 1, "prio": 9})

	# 첫 번째 조언 표출
	guide._show_next_advice()
	assert(guide._mode == "advice", "조언 모드 진입 실패")
	assert(str(guide._advice_now.get("key", "")) == "adv_1", "첫 번째 조언 불일치")

	# 2) 사용자가 '알겠어요' 클릭으로 조언 완료
	guide._resume_after_talk()

	assert(is_equal_approx(guide._advice_cooldown, 5.0), "조언 완료 후 5초 쿨다운 설정 실패: %f" % guide._advice_cooldown)
	assert(guide._mode == "step", "기본 안내 모드로 안전 복귀 실패")

	# 3) 2.5초 경과 -> 두 번째 조언 미발생 확인
	guide._process(2.5)
	assert(guide._mode == "step", "5초 경과 전 두 번째 조언이 조기 팝업됨")
	assert(is_equal_approx(guide._advice_cooldown, 2.5), "조언 쿨다운 차감 불일치")

	# 4) 추가 2.6초 경과 (총 5.1초) -> 두 번째 조언 표출
	guide._process(2.6)
	assert(guide._mode == "advice", "5초 후 두 번째 조언이 표출되지 않음")
	assert(str(guide._advice_now.get("key", "")) == "adv_2", "두 번째 조언 키 불일치")

	guide.queue_free()
	print("  -> TutorialGuide 5초 직렬화 검증 통과!")
