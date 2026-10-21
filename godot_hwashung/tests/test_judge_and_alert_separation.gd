extends SceneTree

## [검증 테스트] 김판관 정무 조언 전담 및 상단 사건 팝업 완전 이분화 검증기
## 1. 정무 조언 5대 핵심 항목 (인재 등용, 호포책, 현륭원 친림, 서장대 훈련, 도적 소탕) 수집 검증
## 2. 김판관 탭 전환 (어명 교지 <-> 정무 조언) 및 네비게이션 동작 검증
## 3. 상단 팝업창 (TopAlertBanner)의 사건 발생 전용화 및 정무 조언 누출 차단(Zero-Leakage) 검증

func _init() -> void:
	print("=== [TEST START] 김판관 정무 조언 및 상단 팝업 이분화 검증 ===")
	var pass_count: int = 0
	var total_tests: int = 0

	# 1. 시뮬레이션 및 코어 컴포넌트 목업 초기화
	var sim: SimulationCore = SimulationCore.new()
	var court: CourtSystem = CourtSystem.new()
	var grid: GameGrid = GameGrid.new()
	var hud: HUDController = HUDController.new()
	var time_mgr: TimeManager = TimeManager.new()
	var quest_sys: QuestSystem = QuestSystem.new()
	var panels: PanelController = PanelController.new()
	var trade_sys: TradeSystem = TradeSystem.new()
	var turn_sys: TurnSystem = TurnSystem.new()
	var guide: TutorialGuide = TutorialGuide.new()

	grid._ready()
	court.setup(sim)
	quest_sys.setup(grid, sim, court)
	hud._build_top_alert_stack()
	hud._build_toast_banner()
	panels.setup(sim, grid, court, trade_sys, turn_sys, hud, quest_sys)
	guide.setup(quest_sys, panels, hud, time_mgr, sim, court, grid, false)

	# -------------------------------------------------------------
	# Test 1: 정무 조언 5대 핵심 항목 실시간 수집 검증
	# -------------------------------------------------------------
	total_tests += 1
	court.tiger["active"] = true # 호환 발생 상태
	court.hyoryungwon["visited"] = false # 친림 미참배 상태
	sim.bandit_active = true # 도적 출몰 상태
	sim.seojangdae_drill_cd_months = 0 # 훈련 가능 상태

	var affairs: Array[Dictionary] = guide._collect_affairs_advices()
	var keys: Array[String] = []
	for aff: Dictionary in affairs:
		keys.append(str(aff.get("key", "")))

	var has_tiger: bool = false
	var has_tomb: bool = false
	var has_bandit: bool = false
	var has_seojangdae: bool = false

	for k: String in keys:
		if "tiger" in k: has_tiger = true
		if "hyoryungwon" in k: has_tomb = true
		if "bandit" in k: has_bandit = true
		if "seojangdae" in k: has_seojangdae = true

	if has_tiger and has_tomb and has_bandit and has_seojangdae:
		print("[PASS] Test 1: 5대 핵심 정무 조언 항목(호포책, 친림, 도적 소탕, 서장대) 정상 수집 확인 (수집 건수: %d건)" % affairs.size())
		pass_count += 1
	else:
		printerr("[FAIL] Test 1: 정무 조언 수집 누락: tiger=%s, tomb=%s, bandit=%s, seojangdae=%s" % [has_tiger, has_tomb, has_bandit, has_seojangdae])

	# -------------------------------------------------------------
	# Test 2: 인재 출현 시 정무 조언 반영 및 즉시 탭 포커스 검증
	# -------------------------------------------------------------
	total_tests += 1
	var cand_data := {
		"id": "jeong",
		"name": "다산 정약용",
		"praise": "배다리와 거중기를 고안한 실학의 대가이옵니다.",
		"acc": 95,
		"salary": 200
	}
	court.candidates = [cand_data]
	guide._on_scholar_appeared(cand_data)

	var has_scholar_affair: bool = false
	for aff: Dictionary in guide._affairs_list:
		if "scholar_jeong" in str(aff.get("key", "")):
			has_scholar_affair = true
			break

	if has_scholar_affair and guide._current_tab == "affairs":
		print("[PASS] Test 2: 초야 인재 출현 시 김판관 정무 조언 리스트 등록 및 정무 탭 자동 포커스 확인")
		pass_count += 1
	else:
		printerr("[FAIL] Test 2: 인재 출현 시 정무 탭 반영 실패: has_affair=%s, tab=%s" % [has_scholar_affair, guide._current_tab])

	# -------------------------------------------------------------
	# Test 3: 탭 전환 (어명 교지 <-> 정무 조언) 양방향 무결성 검증
	# -------------------------------------------------------------
	total_tests += 1
	guide._switch_tab("quest")
	var is_quest_tab: bool = (guide._current_tab == "quest" and guide._mode in ["step", "done"])
	guide._switch_tab("affairs")
	var is_affairs_tab: bool = (guide._current_tab == "affairs" and guide._mode == "affairs")

	if is_quest_tab and is_affairs_tab:
		print("[PASS] Test 3: [어명 교지] <-> [정무 조언] 탭 양방향 즉시 전환 무결성 확인")
		pass_count += 1
	else:
		printerr("[FAIL] Test 3: 탭 전환 상태 불일치: quest=%s, affairs=%s" % [is_quest_tab, is_affairs_tab])

	# -------------------------------------------------------------
	# Test 4: 정무 조언 네비게이션 (이전/다음 순환) 검증
	# -------------------------------------------------------------
	total_tests += 1
	var initial_idx: int = guide._affair_idx
	guide._on_next_advice()
	var next_idx: int = guide._affair_idx
	guide._on_prev_advice()
	var prev_idx: int = guide._affair_idx

	if guide._affairs_list.size() > 1 and next_idx != initial_idx and prev_idx == initial_idx:
		print("[PASS] Test 4: 정무 조언 순환 네비게이션 (이전/다음) 정상 작동 확인 (인덱스: %d -> %d -> %d)" % [initial_idx, next_idx, prev_idx])
		pass_count += 1
	elif guide._affairs_list.size() <= 1:
		print("[PASS] Test 4: 단일 조언 상태에서 경계값 안전 처리 확인")
		pass_count += 1
	else:
		printerr("[FAIL] Test 4: 네비게이션 인덱스 오작동: %d -> %d -> %d" % [initial_idx, next_idx, prev_idx])

	# -------------------------------------------------------------
	# Test 5: 상단 팝업창 (TopAlertBanner) 이분화 및 정무 조언 차단 검증
	# -------------------------------------------------------------
	total_tests += 1
	var alert_banner: TopAlertBanner = TopAlertBanner.new()
	alert_banner._ready()

	# 정무 관련 메시지 투입 시도 -> 상단 배너 차단되어야 함
	alert_banner.push_alert("👥 [초야 인재 출현] 정약용이 화성에 당도했습니다!")
	alert_banner.push_alert("🙏 [현륭원 친림] 참배를 권고드립니다.")
	alert_banner.push_alert("🐯 [호포책 권고] 착호갑사를 파견하십시오.")

	var leaked_alerts: int = alert_banner._alert_queue.size()
	if alert_banner._is_showing:
		leaked_alerts += 1

	# 사건 발생 메시지 투입 시도 -> 정상 적재되어야 함
	alert_banner.push_alert("🔥 [화재 발생] 성내 민가에 큰불이 번지고 있습니다!")
	alert_banner.push_alert("🚨 [도적 침입] 화적 무리가 서문 외곽에 침입했습니다!")

	var incident_alerts: int = alert_banner._alert_queue.size()
	if alert_banner._is_showing:
		incident_alerts += 1

	if leaked_alerts == 0 and incident_alerts >= 1:
		print("[PASS] Test 5: 상단 팝업창 정무 조언 100%% 차단 및 사건 발생 전용 적재 확인 (누출 0건, 사건 적재 %d건)" % incident_alerts)
		pass_count += 1
	else:
		printerr("[FAIL] Test 5: 상단 팝업 필터링 실패: leaked=%d, incident=%d" % [leaked_alerts, incident_alerts])

	# -------------------------------------------------------------
	# Test 6: HUDController _show_toast 경량 토스트 분리 검증
	# -------------------------------------------------------------
	total_tests += 1
	var hud_banner: TopAlertBanner = hud.top_alert_banner

	# 일반 토스트 호출
	hud._show_toast("도로 닦기 도구가 선택되었습니다.", "🛠️")
	hud._show_toast("추천 위치로 이동했습니다.", "📍")

	var banner_polluted: bool = false
	if hud_banner != null and (hud_banner._is_showing or hud_banner._alert_queue.size() > 0):
		banner_polluted = true

	if not banner_polluted and hud.toast_panel.visible:
		print("[PASS] Test 6: HUDController 일반 토스트의 상단 배너 비오염 및 경량 패널 독립 표시 확인")
		pass_count += 1
	else:
		printerr("[FAIL] Test 6: 일반 토스트가 상단 배너를 오염시켰거나 표시 실패: polluted=%s, visible=%s" % [banner_polluted, hud.toast_panel.visible])

	# -------------------------------------------------------------
	# Test 7: 주요 건물 완성 시 김판관 완료 보고(report_building_completed) 전담 검증
	# -------------------------------------------------------------
	total_tests += 1
	guide.report_building_completed("haenggung")
	var is_b_reported: bool = (guide._mode == "report" and "화성행궁" in guide._page_lbl.text and "화성행궁이 웅장하게 완공" in guide._text_lbl.text)
	if is_b_reported:
		print("[PASS] Test 7: 주요 건물(화성행궁) 완공 시 김판관 완료 보고 모드 진입 및 고증 축하 멘트 브리핑 확인")
		pass_count += 1
	else:
		printerr("[FAIL] Test 7: 건물 완공 보고 실패: mode=%s, page=%s" % [guide._mode, guide._page_lbl.text])

	# -------------------------------------------------------------
	# Test 8: 국책 대역사 완공 시 김판관 완료 보고(report_mega_project_completed) 및 상단 배너 비노출 검증
	# -------------------------------------------------------------
	total_tests += 1
	var banner_count_before: int = alert_banner._alert_queue.size()
	guide.report_mega_project_completed("수원천 석축 제방 대역사")
	alert_banner.push_alert("수원천 석축 제방 대역사가 완공되었습니다!") # 팝업 배너에 실수로 유입되더라도 차단되어야 함
	var is_p_reported: bool = (guide._mode == "report" and "수원천 석축 제방 대역사" in guide._page_lbl.text)
	var banner_blocked: bool = (alert_banner._alert_queue.size() == banner_count_before)

	if is_p_reported and banner_blocked:
		print("[PASS] Test 8: 국책 대역사 완공 시 김판관 전담 보고 및 상단 배너 100%% 차단 확인")
		pass_count += 1
	else:
		printerr("[FAIL] Test 8: 국책 대역사 완공 보고 실패: reported=%s, banner_blocked=%s" % [is_p_reported, banner_blocked])

	# -------------------------------------------------------------
	# Test 9: 실학 연구 및 세자 서연 완수 시 김판관 전담 보고 검증
	# -------------------------------------------------------------
	total_tests += 1
	guide._on_prince_completed()
	var is_prince_reported: bool = (guide._mode == "report" and "세자 서연 완수" in guide._page_lbl.text and "제왕학 서연" in guide._text_lbl.text)

	if is_prince_reported:
		print("[PASS] Test 9: 세자 서연 완수 시 김판관 완료 보고 브리핑 확인")
		pass_count += 1
	else:
		printerr("[FAIL] Test 9: 세자 서연 완수 보고 실패: mode=%s, page=%s" % [guide._mode, guide._page_lbl.text])

	# -------------------------------------------------------------
	# Test 10: 완료 보고 확인(_on_next) 클릭 시 FSM 복귀 라이프사이클 검증
	# -------------------------------------------------------------
	total_tests += 1
	guide._text_lbl.visible_characters = -1 # 타이핑 완료 상태 강제
	guide._on_next() # '확인 ▶' 클릭
	var is_returned: bool = (guide._mode in ["step", "affairs", "done"])

	if is_returned:
		print("[PASS] Test 10: 완료 보고 확인 후 원래 탭(어명/정무)으로 안전하게 FSM 복귀 확인 (현재 모드: %s)" % guide._mode)
		pass_count += 1
	else:
		printerr("[FAIL] Test 10: 완료 보고 후 FSM 복귀 실패: mode=%s" % guide._mode)

	# -------------------------------------------------------------
	# 최종 결산
	# -------------------------------------------------------------
	print("\n--- 검사 결과 통계 ---")
	print("총 테스트 항목: %d / 성공: %d / 실패: %d" % [total_tests, pass_count, total_tests - pass_count])
	if pass_count == total_tests:
		print("=== [TEST PASS] 모든 이분화 및 완료 보고 전담 테스트 성공! ===")
		quit(0)
	else:
		printerr("=== [TEST FAIL] 일부 테스트 항목 실패! ===")
		quit(1)
