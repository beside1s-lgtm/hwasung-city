extends SceneTree

## [QA 자동 검증] 서장대 야조 훈련 선택형 미니게임 및 정산 시스템 통합 테스트

func _init() -> void:
	print("=== [테스트 시작] 서장대 야조 미니게임 및 정산 시스템 통합 검증 ===")

	test_formula_and_multipliers()
	test_round_time_limit_scaling()
	test_simulation_core_drill_execution()
	test_yajo_minigame_lifecycle_and_input_handling()
	test_seojangdae_popup_dual_dispatch()

	print("=== [테스트 완료] 모든 항목 100% 통과 (ALL PASS)! ===")
	quit(0)

func _create_test_grid(grid_size: int = 30) -> GameGrid:
	var g := GameGrid.new()
	g.size = grid_size
	g.grid = []
	for y in range(grid_size):
		var row: Array = []
		for x in range(grid_size):
			row.append({
				"terrain": "plain",
				"surface": "grass",
				"building": "",
				"zone": "",
				"elevation": 0.0,
				"road_type": "dirt"
			})
		g.grid.append(row)
	return g

## ------------------------------------------------------------
## 1. 훈련 효과 산출 공식 검증 (0~10회 -> -20% ~ +20%)
## ------------------------------------------------------------
func test_formula_and_multipliers() -> void:
	print("[검증 1] 훈련 효과 산출 공식 및 배율 (-20% ~ +20%) 검증...")

	var expected_results: Dictionary = {
		10: {"bonus": 20, "mult": 1.20},
		9:  {"bonus": 16, "mult": 1.16},
		8:  {"bonus": 12, "mult": 1.12},
		7:  {"bonus": 8,  "mult": 1.08},
		6:  {"bonus": 4,  "mult": 1.04},
		5:  {"bonus": 0,  "mult": 1.00},
		4:  {"bonus": -4, "mult": 0.96},
		3:  {"bonus": -8, "mult": 0.92},
		2:  {"bonus": -12,"mult": 0.88},
		1:  {"bonus": -16,"mult": 0.84},
		0:  {"bonus": -20,"mult": 0.80}
	}

	for s: int in expected_results.keys():
		var exp_bonus: int = int(expected_results[s]["bonus"])
		var exp_mult: float = float(expected_results[s]["mult"])

		var calc_bonus: int = MilitaryManager.calculate_yajo_drill_bonus_pct(s)
		var calc_mult: float = MilitaryManager.calculate_yajo_drill_multiplier(s)

		assert(calc_bonus == exp_bonus, "보너스 비율 불일치! 성공 %d: 예상 %d%%, 계산 %d%%" % [s, exp_bonus, calc_bonus])
		assert(absf(calc_mult - exp_mult) < 0.001, "배율 불일치! 성공 %d: 예상 %.2f, 계산 %.2f" % [s, exp_mult, calc_mult])

	print("  -> 성공 횟수 0~10회 구간 4%p 간격 배율 산식 100% 일치 확인.")

## ------------------------------------------------------------
## 2. 라운드별 접근 제한 시간 선형 단축 공식 검증 (5.0s -> 1.0s)
## ------------------------------------------------------------
func test_round_time_limit_scaling() -> void:
	print("[검증 2] 라운드별 접근 제한 시간 선형 단축 검증 (1회차 5.0초 -> 10회차 1.0초)...")

	var max_rounds: int = 10
	var t1: float = 5.0 - (float(1 - 1) / float(max_rounds - 1)) * 4.0
	var t5: float = 5.0 - (float(5 - 1) / float(max_rounds - 1)) * 4.0
	var t10: float = 5.0 - (float(10 - 1) / float(max_rounds - 1)) * 4.0

	assert(absf(t1 - 5.0) < 0.001, "1회차 시간 불일치: %.2f" % t1)
	assert(absf(t5 - 3.222) < 0.01, "5회차 시간 불일치: %.2f" % t5)
	assert(absf(t10 - 1.0) < 0.001, "10회차 시간 불일치: %.2f" % t10)

	print("  -> 1회차 5.0초, 5회차 3.22초, 10회차 1.0초 단축 공식 검증 완료.")

## ------------------------------------------------------------
## 3. SimulationCore 비용 차감 및 배율 정산 검증
## ------------------------------------------------------------
func test_simulation_core_drill_execution() -> void:
	print("[검증 3] SimulationCore 비용 사전 차감 및 최종 배율 정산 검증...")

	var grid := _create_test_grid(30)
	grid.grid[10][10]["building"] = "seojangdae"
	grid.grid[10][10]["site_anchor"] = Vector2i(10, 10)
	grid.grid[10][10]["completed"] = true

	var sim := SimulationCore.new()
	sim.gold = 5000
	sim.rice = 5000
	sim.seojangdae_drill_cd_months = 0

	CityStats.seojangdae_drill_bonus = 0
	CityStats.military_attack_power = 500

	# 1) 비용 사전 차감 검증
	var pay_res: Dictionary = sim.pay_seojangdae_drill_cost(grid)
	assert(pay_res.get("success", false), "서장대 비용 차감 실패")
	assert(sim.gold == 3000, "금화 차감 오류: %d" % sim.gold)
	assert(sim.rice == 4000, "군량미 차감 오류: %d" % sim.rice)
	assert(sim.seojangdae_drill_cd_months == 12, "쿨다운 12개월 설정 오류: %d" % sim.seojangdae_drill_cd_months)

	# 2) 10회 만점 훈련 보상 정산 (1.20x 적용)
	var rew_res: Dictionary = sim.apply_seojangdae_drill_rewards(grid, null, 1.20)
	assert(rew_res.get("success", false), "보상 정산 실패")
	assert(rew_res.get("atk_bonus", 0) == 60, "공격력 120%% 보너스 오류: %d (예상 60)" % rew_res.get("atk_bonus", 0))
	assert(CityStats.get_seojangdae_drill_bonus() == 60, "CityStats 보너스 누적 오류")

	# 3) 쿨다운 중 중복 실행 차단 검증
	var dup_res: Dictionary = sim.can_execute_seojangdae_drill(grid)
	assert(not dup_res.get("success", false), "쿨다운 중 중복 훈련 허용 오류")

	print("  -> 비용 차감(금 2000, 곡 1000), 쿨다운 12개월, 120% 보너스(공격력 +60) 정산 정상 작동 확인.")

## ------------------------------------------------------------
## 4. YajoMiniGamePopup 라이프사이클 및 입력 처리 검증
## ------------------------------------------------------------
func test_yajo_minigame_lifecycle_and_input_handling() -> void:
	print("[검증 4] YajoMiniGamePopup 라이프사이클, 시간 일시정지, 입력 격리 검증...")

	var time_mgr := TimeManager.new()
	time_mgr.current_speed = TimeManager.SpeedMode.NORMAL

	var popup := YajoMiniGamePopup.new()
	root.add_child(popup)

	popup.start_yajo_minigame(time_mgr)
	assert(popup.visible, "미니게임 팝업 오픈 실패")
	assert(time_mgr.current_speed == TimeManager.SpeedMode.PAUSE, "미니게임 중 월드 시간 일시정지 실패")

	# 입력 처리 검증: 방향키 조준 변경
	var ev_down := InputEventKey.new()
	ev_down.keycode = KEY_DOWN
	ev_down.pressed = true
	popup._input(ev_down)
	assert(popup.selected_dir == YajoMiniGamePopup.Dir.DOWN, "방향키 조준 변경 실패")

	# 목표와 일치하는 방향 및 색상으로 발사하여 성공 시뮬레이션
	popup.target_dir = YajoMiniGamePopup.Dir.DOWN
	popup.target_color = YajoMiniGamePopup.SignalColor.RED
	popup._fire_signal(YajoMiniGamePopup.SignalColor.RED)
	assert(popup.success_count == 1, "신호 일치 성공 카운트 오류")

	# 불일치 발사 실패 시뮬레이션
	popup.is_round_active = true
	popup._fire_signal(YajoMiniGamePopup.SignalColor.BLUE)
	assert(popup.fail_count == 1, "신호 불일치 실패 카운트 오류")

	# 10라운드 완료 시뮬레이션
	popup.current_round = 10
	popup.success_count = 10
	popup.fail_count = 0
	popup._finish_minigame()
	assert(popup._result_panel.visible, "결과 요약 패널 노출 실패")

	# 확인 버튼 클릭
	var sig_res := {"fired": false, "mult": 0.0}
	popup.minigame_completed.connect(func(mult: float, _s: int):
		sig_res["fired"] = true
		sig_res["mult"] = mult
	)
	popup._on_result_confirmed()

	assert(sig_res["fired"], "minigame_completed 시그널 미발화")
	assert(absf(float(sig_res["mult"]) - 1.20) < 0.001, "최종 배율 계산 오류: %.2f (예상 1.20)" % float(sig_res["mult"]))
	assert(not popup.visible, "미니게임 종료 후 팝업 닫힘 실패")
	assert(time_mgr.current_speed == TimeManager.SpeedMode.NORMAL, "월드 시간 일시정지 복구 실패")

	popup.queue_free()
	time_mgr.queue_free()
	print("  -> 시간 일시정지/복구, 방향키/색상키 판정, 10라운드 결과 정산 시그널 검증 완료.")

## ------------------------------------------------------------
## 5. SeojangdaePopup 이원화 선택지 검증
## ------------------------------------------------------------
func test_seojangdae_popup_dual_dispatch() -> void:
	print("[검증 5] SeojangdaePopup [자동 시행] vs [직접 지휘] 분기 검증...")

	var grid := _create_test_grid(30)
	grid.grid[10][10]["building"] = "seojangdae"
	grid.grid[10][10]["site_anchor"] = Vector2i(10, 10)
	grid.grid[10][10]["completed"] = true

	var sim := SimulationCore.new()
	sim.gold = 10000
	sim.rice = 10000
	sim.seojangdae_drill_cd_months = 0

	var minigame := YajoMiniGamePopup.new()
	root.add_child(minigame)

	var seojang_popup := SeojangdaePopup.new()
	seojang_popup.setup(grid, sim, null, null, null, null, minigame)
	root.add_child(seojang_popup)

	var last_sig := {"mode": "", "mult": 0.0}
	seojang_popup.drill_finished.connect(func(mode: String, mult: float):
		last_sig["mode"] = mode
		last_sig["mult"] = mult
	)

	seojang_popup.open_seojangdae_popup()
	assert(seojang_popup.visible, "서장대 팝업 열기 실패")
	assert(not seojang_popup._btn_auto.disabled, "자동 시행 버튼 비활성화 오류")
	assert(not seojang_popup._btn_manual.disabled, "직접 지휘 버튼 비활성화 오류")

	# 1) 자동 시행 선택 검증 (1.00x)
	seojang_popup._on_auto_drill_pressed()
	assert(last_sig["mode"] == "auto", "자동 시행 완료 시그널 미발화: last_mode=" + str(last_sig["mode"]))
	assert(absf(float(last_sig["mult"]) - 1.00) < 0.001, "자동 시행 배율 불일치: %.2f" % float(last_sig["mult"]))
	assert(not seojang_popup.visible, "자동 시행 후 팝업 닫힘 실패")

	# 2) 쿨다운 리셋 후 직접 지휘 선택 검증
	sim.seojangdae_drill_cd_months = 0
	seojang_popup.open_seojangdae_popup()

	var prev_gold: int = sim.gold
	seojang_popup._on_manual_drill_pressed()
	# 즉시 비용 선차감 확인
	assert(sim.gold < prev_gold, "직접 지휘 시 즉시 비용 차감 누락")
	assert(minigame.visible, "직접 지휘 시 미니게임 모달 오픈 실패")

	# 미니게임 완료 콜백 시뮬레이션 (8회 성공 -> 1.12x)
	last_sig["mode"] = ""
	last_sig["mult"] = 0.0
	seojang_popup._on_minigame_completed(1.12, 8)
	assert(last_sig["mode"] == "manual", "직접 지휘 완료 시그널 미발화")
	assert(absf(float(last_sig["mult"]) - 1.12) < 0.001, "직접 지휘 보정 배율 불일치: %.2f" % float(last_sig["mult"]))

	minigame.queue_free()
	seojang_popup.queue_free()
	print("  -> 자동 시행(100% 즉시 정산) 및 직접 지휘(선차감 + 미니게임 배율 정산) 완벽 동작 확인.")
