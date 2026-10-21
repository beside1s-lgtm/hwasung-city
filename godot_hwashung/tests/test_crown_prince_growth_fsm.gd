extends SceneTree

const DifficultyManagerClass = preload("res://scripts/DifficultyManager.gd")
const CrownPrinceEducationManagerClass = preload("res://scripts/CrownPrinceEducationManager.gd")
const CrownPrinceDataClass = preload("res://scripts/CrownPrinceData.gd")
const CrownPrincePopupClass = preload("res://scripts/CrownPrincePopup.gd")
const SimulationCoreClass = preload("res://scripts/SimulationCore.gd")
const CourtSystemClass = preload("res://scripts/CourtSystem.gd")
const CityStatsClass = preload("res://scripts/CityStats.gd")
const InspectNarrativeGeneratorClass = preload("res://scripts/InspectNarrativeGenerator.gd")

func _init() -> void:
	print("=== [테스트 시작] 세자 경연 6단계 캐릭터 외형·성장 FSM 및 재정 소모 시스템 종합 검증 ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	_test_six_stages_data_and_fsm()
	_test_turn_cost_and_difficulty_multipliers()
	_test_paused_on_low_funds_no_reset()
	_test_completion_at_100_and_permanent_lock()
	_test_signals_and_visual_portrait_caching()
	_test_inspect_narrative_and_popup_integration()

	print("=== [테스트 완료] 세자 경연 6단계 비주얼 성장 FSM 및 재정 소모 시스템 100% 통과! ===")
	quit(0)

## 1. 6단계 점수 구간별 상태, 초상화, 명칭, 대사, 버프 사양표 일치 검증
func _test_six_stages_data_and_fsm() -> void:
	print("[검증 1] 6단계 캐릭터 성장 FSM 점수 구간, 명칭, 대사, 버프 검증...")

	# 0~20점: 유아 (stage 0)
	assert(CrownPrinceDataClass.get_stage_by_score(0.0) == 0, "0점 단계 오류")
	assert(CrownPrinceDataClass.get_stage_by_score(10.0) == 0, "10점 단계 오류")
	assert(CrownPrinceDataClass.get_stage_by_score(20.0) == 0, "20점 단계 오류")
	assert(CrownPrinceDataClass.get_stage_title(0) == "유아 세자", "1단계 명칭 오류")
	assert(CrownPrinceDataClass.get_stage_quote(0).contains("나비 잡으러"), "1단계 대사 오류")

	# 21~40점: 어린이 (stage 1)
	assert(CrownPrinceDataClass.get_stage_by_score(21.0) == 1, "21점 단계 오류")
	assert(CrownPrinceDataClass.get_stage_by_score(30.0) == 1, "30점 단계 오류")
	assert(CrownPrinceDataClass.get_stage_by_score(40.0) == 1, "40점 단계 오류")
	assert(CrownPrinceDataClass.get_stage_title(1) == "어린이 세자", "2단계 명칭 오류")
	assert(CrownPrinceDataClass.get_stage_quote(1).contains("논어의 한 구절"), "2단계 대사 오류")
	assert(CrownPrinceDataClass.get_stage_buff_text(1) == "민심 +2", "2단계 버프 오류")

	# 41~60점: 사춘기 (stage 2)
	assert(CrownPrinceDataClass.get_stage_by_score(41.0) == 2, "41점 단계 오류")
	assert(CrownPrinceDataClass.get_stage_by_score(50.0) == 2, "50점 단계 오류")
	assert(CrownPrinceDataClass.get_stage_by_score(60.0) == 2, "60점 단계 오류")
	assert(CrownPrinceDataClass.get_stage_title(2) == "사춘기 학생 세자", "3단계 명칭 오류")
	assert(CrownPrinceDataClass.get_stage_quote(2).contains("옛 성현의 말씀"), "3단계 대사 오류")
	assert(CrownPrinceDataClass.get_stage_buff_text(2) == "연구속도 +3%", "3단계 버프 오류")

	# 61~80점: 청년 (stage 3)
	assert(CrownPrinceDataClass.get_stage_by_score(61.0) == 3, "61점 단계 오류")
	assert(CrownPrinceDataClass.get_stage_by_score(70.0) == 3, "70점 단계 오류")
	assert(CrownPrinceDataClass.get_stage_by_score(80.0) == 3, "80점 단계 오류")
	assert(CrownPrinceDataClass.get_stage_title(3) == "청년 세자", "4단계 명칭 오류")
	assert(CrownPrinceDataClass.get_stage_quote(3).contains("장용영 군사들"), "4단계 대사 오류")
	assert(CrownPrinceDataClass.get_stage_buff_text(3) == "도시 국방력 +50", "4단계 버프 오류")

	# 81~99점: 책벌레 (stage 4)
	assert(CrownPrinceDataClass.get_stage_by_score(81.0) == 4, "81점 단계 오류")
	assert(CrownPrinceDataClass.get_stage_by_score(90.0) == 4, "90점 단계 오류")
	assert(CrownPrinceDataClass.get_stage_by_score(99.0) == 4, "99점 단계 오류")
	assert(CrownPrinceDataClass.get_stage_title(4) == "책벌레 세자", "5단계 명칭 오류")
	assert(CrownPrinceDataClass.get_stage_quote(4).contains("규장각의 모든 서책"), "5단계 대사 오류")
	assert(CrownPrinceDataClass.get_stage_buff_text(4) == "학문력 +10", "5단계 버프 오류")

	# 100점: 성인 군주 (stage 5)
	assert(CrownPrinceDataClass.get_stage_by_score(100.0) == 5, "100점 단계 오류")
	assert(CrownPrinceDataClass.get_stage_title(5) == "성인 군주", "6단계 명칭 오류")
	assert(CrownPrinceDataClass.get_stage_quote(5).contains("탕탕평평의 치세"), "6단계 대사 오류")
	assert(CrownPrinceDataClass.get_stage_buff_text(5) == "민심 +15, 왕권 +20", "6단계 버프 오류")

	print("  -> 6단계 점수 구간 및 고증 대사/스탯 100% 일치 확인!")

## 2. 턴당 2,000냥 지속 소모 및 난이도별 배율 (2,000 / 4,000 / 6,000냥) 검증
func _test_turn_cost_and_difficulty_multipliers() -> void:
	print("[검증 2] 턴당 2,000냥 소모 및 난이도 배율 검증...")
	var sim := SimulationCoreClass.new()
	var prince_mgr := CrownPrinceEducationManagerClass.new()

	# 1) 쉬움 (EASY, 배율 1.0) -> 2,000냥
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.EASY)
	assert(prince_mgr.get_turn_cost() == 2000, "쉬움 턴당 비용 2,000냥 불일치")
	sim.gold = 10000
	prince_mgr.start_education(sim)
	var res1: Dictionary = prince_mgr.process_turn(sim, 0) # 학문력 0 -> +0.67% (1.5배 감속)
	assert(is_equal_approx(float(res1["step"]), 1.0 / 1.5), "학문력 0 턴당 학습 속도 1.5배 감속 검증 실패: %f" % float(res1["step"]))
	assert(int(res1["cost_deducted"]) == 2000, "쉬움 국고 2,000냥 차감 실패")
	assert(sim.gold == 8000, "국고 잔액 8,000냥 불일치: %d" % sim.gold)

	# 2) 보통 (NORMAL, 배율 2.0) -> 4,000냥
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.NORMAL)
	assert(prince_mgr.get_turn_cost() == 4000, "보통 턴당 비용 4,000냥 불일치")
	sim.gold = 10000
	var res2: Dictionary = prince_mgr.process_turn(sim, 50) # 학문력 50 -> +3.67% (1.5배 감속)
	assert(is_equal_approx(float(res2["step"]), 5.5 / 1.5), "학문력 50 턴당 학습 속도 1.5배 감속 검증 실패: %f" % float(res2["step"]))
	assert(int(res2["cost_deducted"]) == 4000, "보통 국고 4,000냥 차감 실패")
	assert(sim.gold == 6000, "국고 잔액 6,000냥 불일치: %d" % sim.gold)

	# 3) 어려움 (HARD, 배율 3.0) -> 6,000냥
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.HARD)
	assert(prince_mgr.get_turn_cost() == 6000, "어려움 턴당 비용 6,000냥 불일치")
	sim.gold = 10000
	var res3: Dictionary = prince_mgr.process_turn(sim, 100) # 학문력 100 -> +6.67% (1.5배 감속)
	assert(is_equal_approx(float(res3["step"]), 10.0 / 1.5), "학문력 100 턴당 학습 속도 1.5배 감속 검증 실패: %f" % float(res3["step"]))
	assert(int(res3["cost_deducted"]) == 6000, "어려움 국고 6,000냥 차감 실패")
	assert(sim.gold == 4000, "국고 잔액 4,000냥 불일치: %d" % sim.gold)

	print("  -> 턴당 비용 및 난이도 배율(쉬움 2천/보통 4천/어려움 6천) 검증 통과!")

## 3. 국고 부족 시 점수 리셋 없이 안전 일시 정지(PAUSED) 및 재확보 시 자동 재개 검증
func _test_paused_on_low_funds_no_reset() -> void:
	print("[검증 3] 국고 고갈 시 진행도 안전 보존 및 일시 동결 FSM 검증...")
	var sim := SimulationCoreClass.new()
	var prince_mgr := CrownPrinceEducationManagerClass.new()
	prince_mgr.set_progress(75.5)

	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.EASY)
	prince_mgr.status = CrownPrinceEducationManagerClass.EducationStatus.ACTIVE
	sim.gold = 1500 # 필요 2,000냥 미달

	var prev_score: float = prince_mgr.progress
	var turn_res: Dictionary = prince_mgr.process_turn(sim, 50)

	assert(prince_mgr.status == CrownPrinceEducationManagerClass.EducationStatus.PAUSED_NO_FUNDS, "일시 정지 전이 실패")
	assert(is_equal_approx(prince_mgr.progress, prev_score), "국고 고갈 시 점수가 초기화되거나 변경됨: %f vs %f" % [prince_mgr.progress, prev_score])
	assert(sim.gold == 1500, "국고가 차감되지 않아야 함")
	assert(int(turn_res["cost_deducted"]) == 0, "차감액이 0이어야 함")

	# 국고 재충전 시 자동 재개
	sim.gold = 5000
	var resume_res: Dictionary = prince_mgr.process_turn(sim, 50)
	assert(prince_mgr.status == CrownPrinceEducationManagerClass.EducationStatus.ACTIVE, "국고 충전 후 자동 재개 실패")
	assert(prince_mgr.progress > prev_score, "재개 후 게이지 상승 실패")
	assert(sim.gold == 3000, "재개 후 정상 2,000냥 차감 실패")

	print("  -> 국고 고갈 시 Zero Regression 점수 보존 및 자동 복구 검증 통과!")

## 4. 100점 도달 시 '성인 군주' 완성 및 비용 차감 영구 중단(COMPLETED) 검증
func _test_completion_at_100_and_permanent_lock() -> void:
	print("[검증 4] 100점 제왕학 완수, 최종 보너스(민심 +15, 왕권 +20) 및 비용 차감 중단 검증...")
	var sim := SimulationCoreClass.new()
	sim.authority = 50
	sim.loyalty = 50
	sim.gold = 10000

	var prince_mgr := CrownPrinceEducationManagerClass.new()
	prince_mgr.set_progress(95.0)
	prince_mgr.status = CrownPrinceEducationManagerClass.EducationStatus.ACTIVE

	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.EASY)
	# 학문력 100 -> +10% 추가 -> 100점 돌파
	var comp_turn: Dictionary = prince_mgr.process_turn(sim, 100)

	assert(is_equal_approx(prince_mgr.progress, 100.0), "100점 상한 클램프 실패: %f" % prince_mgr.progress)
	assert(prince_mgr.status == CrownPrinceEducationManagerClass.EducationStatus.COMPLETED, "COMPLETED 상태 전이 실패")
	assert(bool(comp_turn["completed"]) == true, "완료 플래그 미발생")
	assert(sim.authority == 70, "왕권 +20 보너스 미적용: %d" % sim.authority)
	assert(sim.loyalty == 65, "민심 +15 보너스 미적용: %d" % sim.loyalty)

	# 다음 턴 실행 시 비용이 더 이상 차감되지 않고 100점으로 영구 유지
	var post_gold: int = sim.gold
	var next_turn: Dictionary = prince_mgr.process_turn(sim, 100)
	assert(sim.gold == post_gold, "100점 완수 후 국고가 계속 차감됨: %d vs %d" % [sim.gold, post_gold])
	assert(is_equal_approx(prince_mgr.progress, 100.0), "100점 유지 실패")
	assert(prince_mgr.current_stage == 5, "성인 군주 5단계 유지 실패")

	print("  -> 100점 제왕학 완수 및 영구 비용 잠금 검증 통과!")

## 5. 단계별 6종 초상화 캐싱 및 시그널 발행 검증
func _test_signals_and_visual_portrait_caching() -> void:
	print("[검증 5] 6종 초상화 텍스처 사전 캐싱 및 시그널 발행 검증...")

	for i in range(6):
		var tex: Texture2D = CrownPrinceDataClass.get_portrait_texture(i)
		assert(tex != null, "초상화 stage_%02d.png 로딩 실패" % (i + 1))
		assert(tex.get_width() > 0 and tex.get_height() > 0, "초상화 유효 해상도 오류")

	var prince_mgr := CrownPrinceEducationManagerClass.new()
	assert(prince_mgr.current_stage == 0, "초기 세자 단계는 0(제1단계: 유아 세자)이어야 함")
	assert(is_equal_approx(prince_mgr.progress, 0.0), "초기 세자 진척도는 0.0이어야 함")
	print("prince_mgr created, init stage=", prince_mgr.current_stage)
	prince_mgr.set_progress(10.0) # 0단계 유지 (현재 단계: 0)
	print("prince_mgr set_progress(10.0), stage=", prince_mgr.current_stage)

	var signal_stage_fired: Array[bool] = [false]
	var signal_prog_fired: Array[bool] = [false]

	prince_mgr.stage_changed.connect(func(old_s: int, new_s: int):
		print("stage_changed signal received: ", old_s, " -> ", new_s)
		signal_stage_fired[0] = true
		assert(old_s == 0 and new_s == 1, "stage_changed 파라미터 불일치: %d -> %d" % [old_s, new_s])
	)
	prince_mgr.education_progress_changed.connect(func(p: float, s: int):
		print("education_progress_changed signal received: ", p, " stage=", s)
		signal_prog_fired[0] = true
		assert(is_equal_approx(p, 25.0) and s == 1, "education_progress_changed 파라미터 불일치")
	)

	prince_mgr.set_progress(25.0) # 1단계로 전이
	print("after set_progress(25.0), signal_stage_fired=", signal_stage_fired[0], " stage=", prince_mgr.current_stage)
	assert(signal_stage_fired[0], "stage_changed 시그널 미발행")
	assert(signal_prog_fired[0], "education_progress_changed 시그널 미발행")

	prince_mgr.free()

	print("  -> 초상화 6종 텍스처 캐싱 및 단계 전이 시그널 검증 통과!")

## 6. 살피기 내러티브 및 CrownPrincePopup UI 통합 검증
func _test_inspect_narrative_and_popup_integration() -> void:
	print("[검증 6] 화성행궁 살피기 내러티브 및 CrownPrincePopup 씬 인스턴스화 검증...")

	var sim := SimulationCoreClass.new()
	var court := CourtSystemClass.new()
	court.setup(sim)

	# 1) 화성행궁 살피기 데이터에서 세자 정보 및 6단계 대사 반영 확인
	sim.crown_prince_manager.set_progress(65.0) # 3단계 (청년 세자)
	var h_entity: Dictionary = {"building": "haenggung"}
	var insp_data: Dictionary = InspectNarrativeGeneratorClass.build_inspect_data(h_entity, sim, null, null)

	assert(insp_data["title"].contains("세자 시강원"), "행궁 제목에 시강원 미반영")
	assert(insp_data["description"].contains("청년 세자"), "설명에 단계 명칭 미반영")
	assert(insp_data["description"].contains("장용영 군사들"), "설명에 단계 대사 미반영")

	# 2) CrownPrincePopup 씬 로드 및 인스턴스화 검증
	var scene: PackedScene = load("res://scenes/CrownPrincePopup.tscn")
	assert(scene != null, "CrownPrincePopup.tscn 로드 실패")

	var popup: CrownPrincePopup = scene.instantiate() as CrownPrincePopup
	assert(popup != null, "CrownPrincePopup 인스턴스화 실패")
	root.add_child(popup)
	popup.setup(sim, court)
	popup.open_popup()

	assert(popup.visible == true, "팝업 오픈 실패")
	assert(popup.stage_badge_label != null and popup.stage_badge_label.text.contains("청년 세자"), "팝업 배지 갱신 오류")
	assert(popup.quote_label != null and popup.quote_label.text.contains("장용영 군사들"), "팝업 대사 갱신 오류")

	popup.close_popup()
	assert(popup.visible == false, "팝업 닫기 실패")
	popup.queue_free()

	print("  -> 살피기 내러티브 연동 및 팝업 씬 바인딩 100% 검증 통과!")
