extends SceneTree

## [화성유수부 원옥 친국·명판결 시스템 통합 단위 테스트]
## 1. TrialCaseDatabase 사건 목록 및 구조 무결성 검증
## 2. TrialManager 계절별 사건 배정 및 턴당 1회 제한 플래그 검증
## 3. 3대 판결 유형별(엄벌, 타협, 관용) 스탯 변동치(±5 가드) 검증
## 4. 직렬화/역직렬화(세이브/로드) 무결성 검증
## 5. BuildingInteractionManager 및 화성유수부 관아 액션 연동 검증

func _init() -> void:
	print("=== [테스트 시작] 화성유수부 원옥(寃獄) 친국·명판결 시스템 검증 ===")

	# 1. 사건 데이터베이스 검증
	print("[검증 1] TrialCaseDatabase 사건 데이터 구조 및 고증 사건 수 검증...")
	var all_cases: Array[Dictionary] = TrialCaseDatabase.get_all_cases()
	assert(all_cases.size() >= 10, "사건 데이터베이스는 최소 10건 이상이어야 합니다. 현재: %d" % all_cases.size())
	for c: Dictionary in all_cases:
		assert(c.has("id") and c["id"] != "", "사건 ID 누락")
		assert(c.has("title") and c["title"] != "", "사건 제목 누락")
		assert(c.has("defendant_desc"), "죄인 진술 누락")
		assert(c.has("investigator_report"), "수사 보고 누락")
		assert(c.has("choices") and c["choices"].size() == 3, "선택지는 정확히 3개여야 합니다: %s" % c["id"])
		for ch: Dictionary in c["choices"]:
			var r_val: int = int(ch.get("royal_power", 0))
			var l_val: int = int(ch.get("loyalty", 0))
			assert(r_val >= -5 and r_val <= 5, "왕권 변동치는 ±5 이내여야 합니다: %d" % r_val)
			assert(l_val >= -5 and l_val <= 5, "민심 변동치는 ±5 이내여야 합니다: %d" % l_val)
	print("  - [PASS] 고증 기반 10종 사건 데이터 구조 및 ±5 수치 가드 검증 완료 (총 %d건)" % all_cases.size())

	# 2. TrialManager 인스턴스화 및 턴당 1회 판결 라이프사이클 검증
	print("[검증 2] TrialManager 계절 사건 배정 및 턴당 1회 제한 검증...")
	var sim := SimulationCore.new()
	sim.gold = 3000
	sim.rice = 2000
	sim.loyalty = 80
	CityStats.set_royal_power(50)

	var trial_mgr := TrialManager.new()
	trial_mgr.setup(sim, null)

	assert(trial_mgr.has_pending_trial(), "초기 상태에서 심리 대기 중인 사건이 존재해야 합니다.")
	var cur_case: Dictionary = trial_mgr.get_current_case()
	assert(not cur_case.is_empty(), "현재 사건을 가져올 수 있어야 합니다.")
	var init_case_id: String = cur_case["id"]
	print("  - 배정된 계절 송사: [%s] %s" % [init_case_id, cur_case["title"]])

	# 3. 판결 집행 및 스탯 변동 검증 (선택지 0: 엄벌)
	print("[검증 3] 판결 선택지 집행 및 왕권·민심·충성도 트레이드오프 검증...")
	var init_royal: int = CityStats.get_royal_power()
	var init_loyalty: int = sim.loyalty

	var choice0: Dictionary = cur_case["choices"][0]
	var exp_dr: int = int(choice0["royal_power"])
	var exp_dl: int = int(choice0["loyalty"])

	var verdict_res: Dictionary = trial_mgr.apply_verdict(0)
	assert(verdict_res.get("success", false), "판결 집행이 성공해야 합니다.")

	var after_royal: int = CityStats.get_royal_power()
	var after_loyalty: int = sim.loyalty

	assert(after_royal == init_royal + exp_dr, "왕권 변동치 불일치: 기대 %d, 실제 %d" % [init_royal + exp_dr, after_royal])
	assert(after_loyalty == init_loyalty + exp_dl, "민심 변동치 불일치: 기대 %d, 실제 %d" % [init_loyalty + exp_dl, after_loyalty])
	print("  - [PASS] 선택지 0 집행 성공: 왕권(%s%d), 민심(%s%d)" % [("+" if exp_dr >= 0 else ""), exp_dr, ("+" if exp_dl >= 0 else ""), exp_dl])

	# 중복 판결 방지 검증 (동일 턴 내 재판결 시도 차단)
	assert(trial_mgr.has_resolved_trial_this_turn == true, "해당 턴 판결 플래그가 true여야 합니다.")
	assert(trial_mgr.has_pending_trial() == false, "이미 해결한 턴에는 대기 송사가 없어야 합니다.")
	var dup_res: Dictionary = trial_mgr.apply_verdict(1)
	assert(dup_res.get("success", false) == false, "한 턴 내 중복 판결은 차단되어야 합니다.")
	print("  - [PASS] 동일 턴 내 중복 판결 원천 차단 확인")

	# 4. 계절 턴 진행 시 신규 사건 생성 검증
	print("[검증 4] 턴 진행(계절 전환) 후 플래그 리셋 및 신규 송사 배정 검증...")
	sim.turn = 2
	trial_mgr._on_turn_advanced(2, 1, 1789)
	assert(trial_mgr.has_resolved_trial_this_turn == false, "새 턴에서는 플래그가 false로 리셋되어야 합니다.")
	assert(trial_mgr.has_pending_trial() == true, "새 턴에서는 새로운 대기 송사가 존재해야 합니다.")
	var next_case: Dictionary = trial_mgr.get_current_case()
	assert(next_case["id"] != init_case_id, "이전 턴에 해결한 사건과 다른 새로운 사건이 배정되어야 합니다: %s vs %s" % [next_case["id"], init_case_id])
	print("  - [PASS] 새 턴에 신규 송사 정상 배정 확인: [%s] %s" % [next_case["id"], next_case["title"]])

	# 선택지 2: 관용 집행 검증
	var ch2: Dictionary = next_case["choices"][2]
	var exp_dr2: int = int(ch2["royal_power"])
	var exp_dl2: int = int(ch2["loyalty"])
	var exp_rice2: int = int(ch2.get("rice", 0))

	var prev_rice: int = sim.rice
	var royal_before2: int = CityStats.get_royal_power()
	var loyalty_before2: int = sim.loyalty

	var res2: Dictionary = trial_mgr.apply_verdict(2)
	assert(res2.get("success", false), "관용 판결 집행 성공해야 함")
	assert(CityStats.get_royal_power() == royal_before2 + exp_dr2, "관용 후 왕권 수치 검증")
	assert(sim.loyalty == loyalty_before2 + exp_dl2, "관용 후 민심 수치 검증")
	assert(sim.rice == prev_rice + exp_rice2, "관용 후 곡식 수치 검증")
	print("  - [PASS] 관용 선택지 집행 및 자원 연동 검증 성공")

	# 5. 직렬화/역직렬화 (SaveSystem 호환) 검증
	print("[검증 5] 세이브/로드 직렬화 및 역직렬화 무결성 검증...")
	var saved_dict: Dictionary = trial_mgr.serialize()
	assert(saved_dict.has("has_resolved_trial_this_turn"), "직렬화 필드 누락")
	assert(saved_dict.has("solved_case_ids"), "해결 사건 목록 누락")

	var trial_mgr_load := TrialManager.new()
	trial_mgr_load.setup(sim, null)
	trial_mgr_load.deserialize(saved_dict)
	assert(trial_mgr_load.has_resolved_trial_this_turn == trial_mgr.has_resolved_trial_this_turn, "복원 플래그 불일치")
	assert(trial_mgr_load.solved_case_ids.size() == trial_mgr.solved_case_ids.size(), "복원된 해결 목록 크기 불일치")
	print("  - [PASS] 세이브/로드 역직렬화 무결성 확인")

	# 6. BuildingInteractionManager 연동 검증
	print("[검증 6] BuildingInteractionManager 관아 인터랙션 바인딩 검증...")
	var gwana_acts: Array[Dictionary] = BuildingInteractionManager.get_interactions_for_building("gwana", trial_mgr)
	assert(gwana_acts.size() >= 3, "관아 인터랙션은 최소 3개(송사, 도적, 포호책) 이상이어야 합니다.")
	var found_trial: bool = false
	var found_bandit: bool = false
	var found_tiger: bool = false
	for a: Dictionary in gwana_acts:
		if a["id"] == "trial": found_trial = true
		elif a["id"] == "bandit": found_bandit = true
		elif a["id"] == "tiger": found_tiger = true
	assert(found_trial and found_bandit and found_tiger, "관아 인터랙션 필수 3대 항목 누락")
	print("  - [PASS] 관아 인터랙션(송사 친국, 도적 소탕, 포호책) 100% 보존 및 연동 확인")

	# 7. UI 인스턴스화 및 널세이프 렌더링 검증
	print("[검증 7] TrialPopup UI 인스턴스화 및 렌더링 검증...")
	var popup := TrialPopup.new()
	popup.trial_manager = trial_mgr
	trial_mgr.trial_popup = popup
	popup._ready()
	popup.open_trial(cur_case, false)
	assert(popup.visible == true, "팝업이 정상적으로 visible 상태가 되어야 합니다.")
	assert(popup._choice_buttons.size() == 3, "선택지 버튼이 3개 생성되어야 합니다.")
	popup.close_trial()
	assert(popup.visible == false, "팝업이 닫혀야 합니다.")
	popup.free()
	print("  - [PASS] TrialPopup 모달 생성 및 데이터 바인딩 정상 확인")

	sim.free()
	trial_mgr.free()
	trial_mgr_load.free()

	print("=== [테스트 완료] 화성유수부 원옥 친국·명판결 시스템 7대 전 항목 100% 통과! ===")
	quit(0)
