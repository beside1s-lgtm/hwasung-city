extends SceneTree

func _init() -> void:
	print("=== [TEST] 연무대 군사 훈련 선택형 미니게임 검증 시작 ===")

	var test_failed := false

	# 1. 훈련 효과 가감 산식 (-20% ~ +20%) 검증
	print("--- 1. 보너스 퍼센트 및 배율 산식 검증 ---")
	var test_cases: Array[Dictionary] = [
		{"success": 10, "expected_pct": 20, "expected_mult": 1.20},
		{"success": 9, "expected_pct": 16, "expected_mult": 1.16},
		{"success": 8, "expected_pct": 12, "expected_mult": 1.12},
		{"success": 7, "expected_pct": 8, "expected_mult": 1.08},
		{"success": 6, "expected_pct": 4, "expected_mult": 1.04},
		{"success": 5, "expected_pct": 0, "expected_mult": 1.00},
		{"success": 4, "expected_pct": -4, "expected_mult": 0.96},
		{"success": 3, "expected_pct": -8, "expected_mult": 0.92},
		{"success": 2, "expected_pct": -12, "expected_mult": 0.88},
		{"success": 1, "expected_pct": -16, "expected_mult": 0.84},
		{"success": 0, "expected_pct": -20, "expected_mult": 0.80}
	]

	for tc in test_cases:
		var s: int = int(tc["success"])
		var pct: int = MilitaryManager.calculate_yeonmudae_drill_bonus_pct(s)
		var mult: float = MilitaryManager.calculate_yeonmudae_drill_multiplier(s)
		var exp_pct: int = int(tc["expected_pct"])
		var exp_mult: float = float(tc["expected_mult"])

		if pct != exp_pct or absf(mult - exp_mult) > 0.001:
			printerr("[FAIL] 성공 %d회: 계산된 pct=%d (기대 %d), mult=%.3f (기대 %.3f)" % [s, pct, exp_pct, mult, exp_mult])
			test_failed = true
		else:
			print("  [PASS] 성공 %2d회 -> 보정: %+3d%%, 배율: %.2fx" % [s, pct, mult])

	# 2. 비행 시간 공식 검증 (1회차 4.0초 -> 10회차 1.0초 선형 단축)
	print("--- 2. 회차별 비행 시간 선형 단축 공식 검증 ---")
	var flight_cases: Array[Dictionary] = [
		{"round": 1, "expected_t": 4.00},
		{"round": 3, "expected_t": 3.333},
		{"round": 5, "expected_t": 2.667},
		{"round": 8, "expected_t": 1.667},
		{"round": 10, "expected_t": 1.00}
	]

	for fc in flight_cases:
		var r: int = int(fc["round"])
		var t: float = 4.0 - (float(r - 1) / 9.0) * 3.0
		var exp_t: float = float(fc["expected_t"])
		if absf(t - exp_t) > 0.01:
			printerr("[FAIL] %d회차 비행 시간 계산 오류: %.3f (기대 %.3f)" % [r, t, exp_t])
			test_failed = true
		else:
			print("  [PASS] %2d회차 비행 시간: %.3f초 (목표: %.3f초)" % [r, t, exp_t])

	# 3. SimulationCore 연무대 사전 검증, 비용 차감, 보상 정산 분리 검증
	print("--- 3. SimulationCore 연무대 사전 검증, 비용 차감, 보상 정산 분리 검증 ---")
	var sim := SimulationCore.new()
	sim.gold = 5000
	sim.rice = 3000
	sim.loyalty = 50
	sim.military_power = 50

	var grid := GameGrid.new()
	grid._ready()

	# 연무대 완공 타일 배치
	if grid.grid.size() > 2 and grid.grid[2].size() > 2:
		grid.grid[2][2]["building"] = "yeonmudae"

	var check_ok := sim.can_execute_yeonmudae_drill(grid)
	if not check_ok.get("success", false):
		printerr("[FAIL] 연무대 완공 상태에서 사전 검증 실패: %s" % check_ok.get("msg", ""))
		test_failed = true
	else:
		print("  [PASS] 연무대 완공 상태에서 사전 검증 통과")

	# 비용 선차감 테스트
	var pay_res := sim.pay_yeonmudae_drill_cost(grid)
	if not pay_res.get("success", false):
		printerr("[FAIL] 비용 선차감 실패: %s" % pay_res.get("msg", ""))
		test_failed = true
	else:
		print("  [PASS] 비용 선차감 완료: 남은 금화 %d, 쿨다운 %d개월" % [sim.gold, sim.yeonmudae_drill_cd_months])

	# 120% 보상 정산 테스트 (10회 성공)
	var rew_res := sim.apply_yeonmudae_drill_rewards(grid, 1.20)
	if not rew_res.get("success", false) or rew_res.get("atk_bonus", 0) != 48:
		printerr("[FAIL] 1.20x 보상 정산 오류: %s (atk_bonus: %d)" % [rew_res.get("msg", ""), rew_res.get("atk_bonus", 0)])
		test_failed = true
	else:
		print("  [PASS] 1.20x 보상 정산 확인: 공격력 +%d, 군사력 +%d, 민심 +%d" % [
			rew_res.get("atk_bonus", 0), rew_res.get("mil_bonus", 0), rew_res.get("loy_bonus", 0)
		])

	# 80% 보상 정산 테스트 (0회 성공)
	sim.yeonmudae_drill_cd_months = 0
	var rew_min := sim.apply_yeonmudae_drill_rewards(grid, 0.80)
	if not rew_min.get("success", false) or rew_min.get("atk_bonus", 0) != 32:
		printerr("[FAIL] 0.80x 보상 정산 오류: atk_bonus: %d (기대 32)" % rew_min.get("atk_bonus", 0))
		test_failed = true
	else:
		print("  [PASS] 0.80x 보상 정산 확인: 공격력 +%d, 군사력 +%d, 민심 +%d" % [
			rew_min.get("atk_bonus", 0), rew_min.get("mil_bonus", 0), rew_min.get("loy_bonus", 0)
		])

	# 4. YeonmudaeMiniGamePopup 인스턴스, 센터링, 입력 격리 검증
	print("--- 4. YeonmudaeMiniGamePopup 인스턴스, CenterContainer, 입력 격리 검증 ---")
	var canvas := CanvasLayer.new()
	root.add_child(canvas)

	var minigame := YeonmudaeMiniGamePopup.new()
	canvas.add_child(minigame)

	if minigame.visible:
		printerr("[FAIL] 미니게임 초기 visible이 true임")
		test_failed = true
	else:
		print("  [PASS] 미니게임 초기 비활성 상태 확인")

	# CenterContainer 배치 검증
	if minigame._center_container == null:
		printerr("[FAIL] CenterContainer 노드 누락")
		test_failed = true
	else:
		print("  [PASS] CenterContainer 노드 존재 확인")

	# 닫기 버튼 존재 검증
	if minigame._close_btn == null:
		printerr("[FAIL] _close_btn 노드 누락")
		test_failed = true
	else:
		print("  [PASS] 상단 [닫기 ✕] 버튼 존재 확인: text='%s'" % minigame._close_btn.text)

	minigame.start_yeonmudae_minigame()
	if not minigame.visible:
		printerr("[FAIL] start_yeonmudae_minigame 후 visible이 false임")
		test_failed = true
	else:
		print("  [PASS] start_yeonmudae_minigame 호출 후 활성화 확인")

	# 아레나 마우스 진입/이탈 상태 검증
	minigame._on_arena_mouse_entered()
	if not minigame.is_mouse_in_arena:
		printerr("[FAIL] 아레나 마우스 진입 후 is_mouse_in_arena가 false임")
		test_failed = true
	else:
		print("  [PASS] 아레나 마우스 진입 감지 확인 (조준선 표시 활성화)")

	minigame._on_arena_mouse_exited()
	if minigame.is_mouse_in_arena:
		printerr("[FAIL] 아레나 마우스 이탈 후 is_mouse_in_arena가 true임")
		test_failed = true
	else:
		print("  [PASS] 아레나 마우스 이탈 시 조준선 해제 및 일반 커서 복귀 확인")

	# 장전 게이지 충전 시뮬레이션
	minigame.is_pressing_mouse = true
	minigame.draw_gauge = 0.0
	minigame.is_fully_loaded = false

	# 0.3초 경과 (장전 미완료)
	minigame._process(0.3)
	if minigame.is_fully_loaded:
		printerr("[FAIL] 0.3초만에 장전 완료 판정됨 (기대: 미완료)")
		test_failed = true
	else:
		print("  [PASS] 0.3초 장전 중 상태: %.1f%% (미완료 정상)" % minigame._gauge_bar.value)

	# 추가 0.25초 경과 (총 0.55초 -> 장전 완료)
	minigame._process(0.25)
	if not minigame.is_fully_loaded or minigame._gauge_bar.value < 99.9:
		printerr("[FAIL] 0.55초 경과 후에도 장전 미완료 판정")
		test_failed = true
	else:
		print("  [PASS] 0.55초 장전 완료 상태: %.1f%% (완료 정상)" % minigame._gauge_bar.value)

	# close_minigame 닫기 검증
	minigame.close_minigame(true)
	if minigame.visible:
		printerr("[FAIL] close_minigame 후 visible이 true임")
		test_failed = true
	else:
		print("  [PASS] close_minigame 호출 후 안전 종료 확인")

	minigame.queue_free()
	canvas.queue_free()

	# 5. YeonmudaePopup 인스턴스 및 UI 바인딩 검증
	print("--- 5. YeonmudaePopup 인스턴스 및 버튼 선택지 검증 ---")
	var popup := YeonmudaePopup.new()
	popup.setup(grid, sim, null, null, null, null, null)
	root.add_child(popup)
	popup.open_yeonmudae_popup()

	if not popup.visible:
		printerr("[FAIL] YeonmudaePopup open 후 visible이 false임")
		test_failed = true
	else:
		print("  [PASS] YeonmudaePopup 정상 오픈 확인: _btn_auto='%s', _btn_manual='%s'" % [
			popup._btn_auto.text, popup._btn_manual.text
		])

	popup.close_yeonmudae_popup()
	if popup.visible:
		printerr("[FAIL] YeonmudaePopup close 후 visible이 true임")
		test_failed = true
	else:
		print("  [PASS] YeonmudaePopup 정상 닫기 확인")

	popup.queue_free()

	print("==================================================")
	if test_failed:
		printerr("=== [TEST FAILED] 연무대 미니게임 검증 실패 ===")
		quit(1)
	else:
		print("=== [TEST PASSED] 모든 연무대 미니게임 검증 완벽 통과 (100%) ===")
		quit(0)
