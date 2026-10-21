extends SceneTree

## [QA TEST] 사병 음모 순환 루프(Conspiracy Loop), 선택지 분기, 동적 주모자 교체 및 쿨타임 검증

func _init() -> void:
	print("=== [QA TEST] 사병 음모 순환 루프(Conspiracy Loop) 종합 검증 개시 ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var all_pass: bool = true

	# -------------------------------------------------------------
	# 1. 사병 음모 딜레마 생성 및 쿨타임/중복 방지 검증
	# -------------------------------------------------------------
	print("[TEST 1] 사병 음모 딜레마 생성 및 쿨타임/중복 방지 검증...")
	var sim := SimulationCore.new()
	sim.authority = 50
	sim.conspiracy_cooldown_turns = 0
	sim.is_conspiracy_decision_pending = false

	# 초기 상태: 쿨타임 0, 대기 중 false -> 딜레마 풀에 포함되어야 함
	var pool: Array = NewspaperSystem.dilemma_pool(sim)
	var found: bool = false
	for d in pool:
		if str(d.get("id", "")) == "conspiracy_dilemma":
			found = true
			break
	if not found:
		printerr("[FAIL] 쿨타임 0일 때 conspiracy_dilemma가 풀에 생성되지 않음")
		all_pass = false

	# 쿨타임 3턴 설정 -> 풀에 미포함되어야 함
	sim.conspiracy_cooldown_turns = 3
	pool = NewspaperSystem.dilemma_pool(sim)
	found = false
	for d in pool:
		if str(d.get("id", "")) == "conspiracy_dilemma":
			found = true
			break
	if found:
		printerr("[FAIL] 쿨타임 > 0인데 conspiracy_dilemma가 풀에 생성됨")
		all_pass = false

	# 쿨타임 0이지만 결정 대기 중(is_conspiracy_decision_pending = true) -> 풀에 미포함되어야 함 (5초 스팸 방어)
	sim.conspiracy_cooldown_turns = 0
	sim.is_conspiracy_decision_pending = true
	pool = NewspaperSystem.dilemma_pool(sim)
	found = false
	for d in pool:
		if str(d.get("id", "")) == "conspiracy_dilemma":
			found = true
			break
	if found:
		printerr("[FAIL] is_conspiracy_decision_pending=true인데 딜레마 풀에 중복 생성됨")
		all_pass = false

	print("[PASS] TEST 1 완료!")

	# -------------------------------------------------------------
	# 2. 동적 주모자 선정 (구선복 등용/미등용/숙청별 분기)
	# -------------------------------------------------------------
	print("[TEST 2] 동적 주모자 선정 검증...")
	sim.is_conspiracy_decision_pending = false
	sim.conspiracy_cooldown_turns = 0
	sim.purged_conspirators.clear()

	# 2-1: 구선복 미등용 상태 -> 구선복은 건너뛰고 '홍국영 일파 잔당' 선정
	sim.retainers["gu_seonbok"] = false
	var c1: Dictionary = sim.select_available_conspirator()
	if str(c1.get("id", "")) != "hong_remnant":
		printerr("[FAIL] 구선복 미등용 시 hong_remnant가 선정되지 않음: ", c1)
		all_pass = false

	# 2-2: 구선복 등용 상태 -> 구선복 우선 선정
	sim.retainers["gu_seonbok"] = true
	var c2: Dictionary = sim.select_available_conspirator()
	if str(c2.get("id", "")) != "gu_seon_bok":
		printerr("[FAIL] 구선복 등용 시 gu_seon_bok이 선정되지 않음: ", c2)
		all_pass = false

	# 2-3: 구선복 숙청 후 -> 다음 후보('홍국영 일파 잔당')로 교체
	sim.purged_conspirators["gu_seon_bok"] = true
	var c3: Dictionary = sim.select_available_conspirator()
	if str(c3.get("id", "")) != "hong_remnant":
		printerr("[FAIL] 구선복 숙청 후 hong_remnant로 교체되지 않음: ", c3)
		all_pass = false

	print("[PASS] TEST 2 완료!")

	# -------------------------------------------------------------
	# 3. [선제 압수수색] 선택 시 상태 변화 검증
	# -------------------------------------------------------------
	print("[TEST 3] [선제 압수수색] 선택 시 왕권 강화, 숙청, 쿨타임(8~12턴) 검증...")
	sim.purged_conspirators.clear()
	sim.retainers["gu_seonbok"] = true
	ScholarManager.hired_scholars["gu_seonbok"] = true
	sim.authority = 50
	sim.conspiracy_cooldown_turns = 0
	sim.is_conspiracy_decision_pending = false

	pool = NewspaperSystem.dilemma_pool(sim)
	var consp_dilemma: Dictionary = {}
	for d in pool:
		if str(d.get("id", "")) == "conspiracy_dilemma":
			consp_dilemma = d
			break

	if consp_dilemma.is_empty():
		printerr("[FAIL] conspiracy_dilemma를 찾을 수 없음")
		all_pass = false
	else:
		# 첫 번째 선택지: 백동수의 선제 압수수색 실행
		var choice1: Dictionary = consp_dilemma["choices"][0]
		var eff1: Callable = choice1["effect"]
		var msg1: String = str(eff1.call())

		if not msg1.contains("압수수색") or not msg1.contains("왕권 +10"):
			printerr("[FAIL] 압수수색 결과 메시지 오류: ", msg1)
			all_pass = false

		if sim.authority != 60:
			printerr("[FAIL] 압수수색 후 왕권이 +10 되지 않음: ", sim.authority)
			all_pass = false

		if not sim.purged_conspirators.has("gu_seon_bok"):
			printerr("[FAIL] 구선복이 purged_conspirators에 등록되지 않음")
			all_pass = false

		if sim.retainers.get("gu_seonbok", false) or ScholarManager.is_scholar_hired("gu_seonbok"):
			printerr("[FAIL] 구선복이 등용 목록에서 해임되지 않음")
			all_pass = false

		if sim.conspiracy_cooldown_turns < 24 or sim.conspiracy_cooldown_turns > 36:
			printerr("[FAIL] 압수수색 후 쿨타임이 24~36개월 범위가 아님: ", sim.conspiracy_cooldown_turns)
			all_pass = false

		if sim.is_conspiracy_decision_pending:
			printerr("[FAIL] 결정 후 is_conspiracy_decision_pending이 해제되지 않음")
			all_pass = false

	print("[PASS] TEST 3 완료!")

	# -------------------------------------------------------------
	# 4. [묵인 / 관망] 선택 시 순환 루프 및 3회 연속 묵인 반란 봉기 검증
	# -------------------------------------------------------------
	print("[TEST 4] [묵인] 순환 루프 및 3회 누적 반란군 봉기 검증...")
	sim.authority = 50
	sim.conspiracy_stage = 0
	sim.conspiracy_cooldown_turns = 0
	sim.is_conspiracy_decision_pending = false
	sim.purged_conspirators.clear()
	sim.retainers["gu_seonbok"] = false # 대체 후보(홍국영 잔당)로 테스트

	# 4-1: 1회 묵인
	pool = NewspaperSystem.dilemma_pool(sim)
	consp_dilemma = {}
	for d in pool:
		if str(d.get("id", "")) == "conspiracy_dilemma":
			consp_dilemma = d
			break

	var choice_ignore: Dictionary = consp_dilemma["choices"][1]
	var eff_ignore: Callable = choice_ignore["effect"]
	var ignore_msg1: String = str(eff_ignore.call())

	if sim.conspiracy_stage != 1:
		printerr("[FAIL] 1회 묵인 후 conspiracy_stage != 1: ", sim.conspiracy_stage)
		all_pass = false

	if sim.authority != 47: # 50 - 3
		printerr("[FAIL] 1회 묵인 후 왕권 미세 하락(-3) 미반영: ", sim.authority)
		all_pass = false

	if sim.conspiracy_cooldown_turns < 12 or sim.conspiracy_cooldown_turns > 18:
		printerr("[FAIL] 묵인 후 쿨타임이 12~18개월 범위가 아님: ", sim.conspiracy_cooldown_turns)
		all_pass = false

	if not ignore_msg1.contains("은밀히 확장"):
		printerr("[FAIL] 묵인 메시지 불일치: ", ignore_msg1)
		all_pass = false

	# 4-2: 쿨타임 강제 경과 후 2회 묵인
	sim.conspiracy_cooldown_turns = 0
	pool = NewspaperSystem.dilemma_pool(sim)
	consp_dilemma = pool[pool.size() - 1]
	eff_ignore = consp_dilemma["choices"][1]["effect"]
	eff_ignore.call()

	if sim.conspiracy_stage != 2:
		printerr("[FAIL] 2회 묵인 후 conspiracy_stage != 2: ", sim.conspiracy_stage)
		all_pass = false

	# 4-3: 쿨타임 강제 경과 후 3회 묵인 -> 실제 반란군 봉기 발동
	sim.conspiracy_cooldown_turns = 0
	pool = NewspaperSystem.dilemma_pool(sim)
	consp_dilemma = pool[pool.size() - 1]
	eff_ignore = consp_dilemma["choices"][1]["effect"]
	var rebel_msg: String = str(eff_ignore.call())

	if not rebel_msg.contains("반란을 일으켜"):
		printerr("[FAIL] 3회 묵인 시 반란 봉기 메시지 없음: ", rebel_msg)
		all_pass = false

	if sim.conspiracy_stage != 0:
		printerr("[FAIL] 반란 봉기 후 conspiracy_stage가 초기화되지 않음: ", sim.conspiracy_stage)
		all_pass = false

	if sim.conspiracy_cooldown_turns != 30:
		printerr("[FAIL] 반란 봉기 후 쿨타임 30개월 미부여: ", sim.conspiracy_cooldown_turns)
		all_pass = false

	print("[PASS] TEST 4 완료!")

	# -------------------------------------------------------------
	# 5. 턴 정산 시 conspiracy_cooldown_turns 감소 검증
	# -------------------------------------------------------------
	print("[TEST 5] 턴 정산 시 음모 쿨타임 감소 검증...")
	sim.conspiracy_cooldown_turns = 5
	sim.on_simulation_tick(30) # 1턴 경과
	if sim.conspiracy_cooldown_turns != 4:
		printerr("[FAIL] 1턴 경과 후 쿨타임이 4로 감소하지 않음: ", sim.conspiracy_cooldown_turns)
		all_pass = false

	print("[PASS] TEST 5 완료!")

	# -------------------------------------------------------------
	# 6. 세이브/로드 상태 복원 검증
	# -------------------------------------------------------------
	print("[TEST 6] 세이브/로드 음모 상태 복원 검증...")
	sim.conspiracy_stage = 2
	sim.conspiracy_cooldown_turns = 7
	sim.purged_conspirators = {"gu_seon_bok": true}
	sim.active_conspirator_id = "hong_remnant"
	sim.active_conspirator_name = "홍국영 일파 잔당"
	sim.active_conspirator_title = "세도 구세력 잔당"
	sim.is_conspiracy_decision_pending = true

	var grid := GameGrid.new()
	grid.create_grid(10)
	SaveSystem.save_game(99, sim, grid)

	var loaded_sim := SimulationCore.new()
	var load_success: bool = SaveSystem.load_game(99, loaded_sim, grid)
	if not load_success:
		printerr("[FAIL] SaveSystem.load_game 실패")
		all_pass = false

	if loaded_sim.conspiracy_stage != 2:
		printerr("[FAIL] 복원된 conspiracy_stage 불일치: ", loaded_sim.conspiracy_stage)
		all_pass = false

	if loaded_sim.conspiracy_cooldown_turns != 7:
		printerr("[FAIL] 복원된 conspiracy_cooldown_turns 불일치: ", loaded_sim.conspiracy_cooldown_turns)
		all_pass = false

	if not loaded_sim.purged_conspirators.get("gu_seon_bok", false):
		printerr("[FAIL] 복원된 purged_conspirators 누락: ", loaded_sim.purged_conspirators)
		all_pass = false

	if loaded_sim.is_conspiracy_decision_pending != false:
		printerr("[FAIL] 로드 후 is_conspiracy_decision_pending은 false로 안전 초기화되어야 함")
		all_pass = false

	print("[PASS] TEST 6 완료!")

	# -------------------------------------------------------------
	# 결과 출력
	# -------------------------------------------------------------
	if all_pass:
		print("🎉 [ALL TESTS PASSED] 사병 음모 순환 루프(Conspiracy Loop) 6대 검증 100% 통과!")
	else:
		printerr("❌ [TEST FAILED] 일부 테스트 케이스 실패!")

	quit(0 if all_pass else 1)
