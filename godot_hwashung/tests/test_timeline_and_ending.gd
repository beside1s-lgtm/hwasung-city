extends SceneTree

const TimeManagerClass = preload("res://scripts/TimeManager.gd")
const SimulationCoreClass = preload("res://scripts/SimulationCore.gd")
const RoyalProcessionManagerClass = preload("res://scripts/RoyalProcessionManager.gd")
const EndingManagerClass = preload("res://scripts/EndingManager.gd")
const GameGridClass = preload("res://scripts/GameGrid.gd")
const CourtSystemClass = preload("res://scripts/CourtSystem.gd")
const SaveSystemClass = preload("res://scripts/SaveSystem.gd")
const CityStats = preload("res://scripts/CityStats.gd")

func _init() -> void:
	print("=== [테스트 시작] 역사적 연도 이벤트 및 10대 멀티 엔딩 시스템 검증 ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	_test_time_manager_sync()
	_test_simulation_core_sync()
	_test_city_stats_and_save_load()
	_test_eulmyo_conditions_and_grace_period()
	_test_eulmyo_late_procession()
	_test_ending_manager_ten_branches()
	_test_ending_trigger_at_1800()

	print("=== [테스트 완료] 모든 역사적 타임라인 및 10대 엔딩 검증 100% 통과! ===")
	quit(0)

## 1. TimeManager 1789년 시작 및 Single Source of Truth, 시그널 검증
func _test_time_manager_sync() -> void:
	print("[검증 1] TimeManager 1789년 1월 시작 및 일원화 연산 검증...")
	var tm: TimeManager = TimeManagerClass.new()
	root.add_child(tm)

	assert(tm.current_year == 1789, "TimeManager 시작 연도는 1789년이어야 함. 현재: %d" % tm.current_year)
	assert(tm.current_month == 1, "TimeManager 시작 월은 1월이어야 함")
	assert(tm.current_day == 1, "TimeManager 시작 일은 1일이어야 함")

	var year_sig_emitted: Array[int] = []
	var month_sig_emitted: Array[int] = []
	tm.year_changed.connect(func(y: int): year_sig_emitted.append(y))
	tm.month_changed.connect(func(m: int): month_sig_emitted.append(m))

	# 1개월(30일) 진행 -> 2월로 변경
	tm.advance_day(30)
	assert(tm.current_month == 2, "30일 후는 2월이어야 함. 현재: %d" % tm.current_month)
	assert(tm.current_year == 1789, "30일 후는 1789년이어야 함")
	assert(month_sig_emitted.has(2), "month_changed(2) 시그널이 발행되어야 함")

	# 추가 11개월(330일) 진행 -> 1790년 1월
	tm.advance_day(330)
	assert(tm.current_year == 1790, "360일(1년) 후는 1790년이어야 함. 현재: %d" % tm.current_year)
	assert(tm.current_month == 1, "360일 후는 1월이어야 함. 현재: %d" % tm.current_month)
	assert(year_sig_emitted.has(1790), "year_changed(1790) 시그널이 발행되어야 함")

	# 1795년(6년 경과)으로 시간 스킵
	tm.skip_to_year(1795)
	assert(tm.current_year == 1795, "1795년으로 스킵되어야 함. 현재: %d" % tm.current_year)

	# 1년 강제 스킵 (F8 기능) 검증 -> 1796년
	tm.advance_year(1)
	assert(tm.current_year == 1796, "1년 스킵 후 1796년이어야 함. 현재: %d" % tm.current_year)

	tm.queue_free()
	print("  -> TimeManager 1789년 시작 및 연도/월 일원화 연산 검증 통과.")

## 2. SimulationCore 연도 동기화 검증
func _test_simulation_core_sync() -> void:
	print("[검증 2] SimulationCore 연도 1789년 동기화 검증...")
	var sim: SimulationCore = SimulationCoreClass.new()
	root.add_child(sim)

	assert(sim.current_year == 1789, "SimulationCore 시작 연도는 1789년이어야 함. 현재: %d" % sim.current_year)

	# 30틱(1개월) 후
	sim.on_simulation_tick(30)
	assert(sim.current_year == 1789, "30틱 후는 1789년이어야 함")

	# 360틱(1년) 후
	sim.on_simulation_tick(360)
	assert(sim.current_year == 1790, "360틱 후는 1790년이어야 함. 현재: %d" % sim.current_year)

	# 2160틱(6년 = 72개월) 후 -> 1795년
	sim.on_simulation_tick(2160)
	assert(sim.current_year == 1795, "2160틱 후는 1795년이어야 함. 현재: %d" % sim.current_year)

	sim.queue_free()
	print("  -> SimulationCore 연도 동기화 검증 통과.")

## 3. 4대 신규 평가 지표 및 세이브/로드 호환성 검증
func _test_city_stats_and_save_load() -> void:
	print("[검증 3] 4대 신규 평가 지표(세자 교육도, 현륭원 친림, 탕평도, 방호력) 및 세이브/로드 검증...")
	CityStats.reset_to_defaults()

	# 1) 기본 초기값 검증
	assert(CityStats.get_crown_prince_education() == 0, "세자 교육도 초기값은 0이어야 함")
	assert(CityStats.get_hyeonryungwon_visits() == 0, "현륭원 친림 횟수 초기값은 0이어야 함")
	assert(CityStats.get_faction_balance_score() == 50, "탕평도 초기값은 50이어야 함")
	assert(CityStats.get_fortress_defense_power() == 0, "성 방호력 초기값은 0이어야 함")

	var sim: SimulationCore = SimulationCoreClass.new()
	var court: CourtSystem = CourtSystemClass.new()
	var grid: GameGrid = GameGridClass.new()
	var tm: TimeManager = TimeManagerClass.new()
	root.add_child(sim)
	root.add_child(court)
	root.add_child(grid)
	root.add_child(tm)

	court.setup(sim)

	# 2) 현륭원 친림 횟수 증가 검증
	court.visit_hyoryungwon()
	assert(court.get_hyeonryungwon_visits() == 1, "친림 후 방문 횟수가 1이어야 함")
	assert(CityStats.get_hyeonryungwon_visits() == 1, "CityStats 친림 횟수도 1로 동기화되어야 함")

	# 3) 세자 교육도 변동 검증 (점진적 서연 착수 및 동기화)
	court.crown_prince["invested"] = true # 책봉 완료 가정
	sim.gold = 50000
	sim.rice = 50000
	court.study_prince()
	assert(sim.tech_tree.prince_studying, "study_prince 호출 시 시강원 서연이 활성화되어야 함")
	court.set_crown_prince_education(70) # 세이브/로드 검증을 위해 70점으로 설정
	assert(court.get_crown_prince_education() == 70, "세자 교육도가 70이어야 함")
	assert(CityStats.get_crown_prince_education() == 70, "CityStats 세자 교육도도 70으로 동기화되어야 함")


	# 4) 정파 탕평도 검증 (한 정파 독점 시 20 이하로 급락)
	# 노론 3명 독점 등용
	sim.retainers["hong_inhan"] = true
	sim.retainers["sim_hwanji"] = true
	sim.retainers["gu_seonbok"] = true
	var monopoly_score: int = court.update_faction_balance()
	assert(monopoly_score <= 20, "한 정파 독점 시 탕평도는 20 이하여야 함. 현재: %d" % monopoly_score)
	assert(CityStats.get_faction_balance_score() <= 20, "CityStats 탕평도도 동기화되어야 함")

	# 탕평책: 소론, 남인, 실학파 고른 등용
	sim.retainers["jo_simtae"] = true     # 소론
	sim.retainers["seo_yugu"] = true      # 소론
	sim.retainers["chae_jegong"] = true   # 남인
	sim.retainers["jeong_yakyong"] = true # 남인
	sim.retainers["park_jega"] = true     # 실학파
	sim.retainers["kim_hongdo"] = true    # 실학파
	sim.retainers["baek_dongsu"] = true   # 실학파
	var balanced_score: int = court.update_faction_balance()
	assert(balanced_score >= 70, "고른 등용 시 탕평도는 70 이상이어야 함. 현재: %d" % balanced_score)

	# 5) 성 방호력 계산 검증
	sim.fortress_progress = 80
	sim.military_power = 90
	court._on_turn(1, 0, 1789)
	var def_power: int = CityStats.get_fortress_defense_power()
	assert(def_power >= 40, "성곽 완공률 80%% 및 국방력 반영 시 방호력은 40 이상이어야 함. 현재: %d" % def_power)

	# 6) 세이브/로드 및 Null-safe Fallback 검증
	var test_slot: int = 99
	SaveSystemClass.save_game(test_slot, sim, grid)

	# 지표 임의 훼손
	CityStats.set_crown_prince_education(15)
	CityStats.set_hyeonryungwon_visits(999)
	CityStats.set_faction_balance_score(5)
	CityStats.set_fortress_defense_power(1)

	# 로드 수행
	var load_ok: bool = SaveSystemClass.load_game(test_slot, sim, grid, tm)
	assert(load_ok, "세이브 파일 로드 성공해야 함")
	assert(CityStats.get_crown_prince_education() == 70, "저장된 세자 교육도(70)가 복원되어야 함")
	assert(CityStats.get_hyeonryungwon_visits() == 1, "저장된 현륭원 친림 횟수(1)가 복원되어야 함")
	assert(CityStats.get_faction_balance_score() == balanced_score, "저장된 탕평도가 복원되어야 함")
	assert(CityStats.get_fortress_defense_power() == def_power, "저장된 방호력이 복원되어야 함")

	# 세이브 파일 정리
	SaveSystemClass.delete_save(test_slot)

	# Null-safe Fallback 검증 (필드가 없는 빈 Dictionary 로드 시 기본값으로 초기화)
	CityStats.deserialize({})
	assert(CityStats.get_crown_prince_education() == 0, "빈 데이터 로드 시 교육도는 0이어야 함")
	assert(CityStats.get_hyeonryungwon_visits() == 0, "빈 데이터 로드 시 친림 횟수는 0이어야 함")
	assert(CityStats.get_faction_balance_score() == 50, "빈 데이터 로드 시 탕평도는 50이어야 함")
	assert(CityStats.get_fortress_defense_power() == 0, "빈 데이터 로드 시 방호력은 0이어야 함")

	court.queue_free()
	tm.queue_free()
	grid.queue_free()
	sim.queue_free()
	print("  -> 4대 핵심 지표 및 세이브/로드 검증 통과.")

## 4. 을묘원행 조건 미달 시 디버그 로깅 및 1795년 조건 충족 시 정상 발동
func _test_eulmyo_conditions_and_grace_period() -> void:
	print("[검증 4] 을묘원행 조건 미달 디버그 로그 및 1795년 발동 검증...")
	var sim: SimulationCore = SimulationCoreClass.new()
	var grid: GameGrid = GameGridClass.new()
	var tm: TimeManager = TimeManagerClass.new()
	var rp: RoyalProcessionManager = RoyalProcessionManagerClass.new()
	root.add_child(sim)
	root.add_child(grid)
	root.add_child(tm)
	root.add_child(rp)

	rp.setup(sim, grid, null, tm)

	# 1) 초기 상태(1789년): 조건 미달 (자원, 성벽, 인재 등 부족) -> check_eulmyo_conditions() false
	var initial_check: bool = rp.check_eulmyo_conditions()
	assert(not initial_check, "초기 자원 미달 상태에서는 을묘원행 조건을 통과하지 못해야 함")

	# 2) 1789년 및 1794년에는 조건이 충족되더라도 자동 발동되지 않아야 함
	_set_eulmyo_satisfaction(sim, grid, true)
	var trig_1789: bool = rp.evaluate_monthly_trigger(-1, true)
	assert(not trig_1789, "1789년에는 조건을 만족해도 자동 발동되지 않아야 함")

	tm.skip_to_year(1794)
	var trig_1794: bool = rp.evaluate_monthly_trigger(-1, true)
	assert(not trig_1794, "1794년에도 조건을 만족해도 자동 발동되지 않아야 함")

	# 3) 1795년으로 시간 이동 시 자동으로 조건 검사 및 발동되어야 함
	tm.skip_to_year(1795)
	assert(tm.current_year == 1795, "1795년으로 이동 완료되어야 함")
	assert(rp.eulmyo_triggered, "1795년 도달 시 조건이 충족되어 있으므로 을묘원행이 자동 발동되어야 함")
	assert(sim.is_eulmyo_active, "sim.is_eulmyo_active가 true여야 함")

	rp.queue_free()
	tm.queue_free()
	grid.queue_free()
	sim.queue_free()
	print("  -> 을묘원행 조건 검사 및 1795년 발동 검증 통과.")

## 5. 1795년 이후 지연된 을묘원행 (Late Procession) 검증
func _test_eulmyo_late_procession() -> void:
	print("[검증 5] 1795년 이후 지연된 을묘원행(Late Procession) 발동 검증...")
	var sim: SimulationCore = SimulationCoreClass.new()
	var grid: GameGrid = GameGridClass.new()
	var tm: TimeManager = TimeManagerClass.new()
	var rp: RoyalProcessionManager = RoyalProcessionManagerClass.new()
	root.add_child(sim)
	root.add_child(grid)
	root.add_child(tm)
	root.add_child(rp)

	rp.setup(sim, grid, null, tm)

	# 1797년(1795년 경과 후)으로 시간 이동 (조건 미달 상태)
	tm.skip_to_year(1797)
	assert(tm.current_year == 1797, "1797년이어야 함")
	var not_ready: bool = rp.evaluate_monthly_trigger(-1, true)
	assert(not not_ready, "조건 미달 시에는 1797년이어도 미발동")

	# 1797년에 뒤늦게 조건 달성
	_set_eulmyo_satisfaction(sim, grid, true)
	var late_trig: bool = rp.evaluate_monthly_trigger(-1, true)
	assert(late_trig, "1795년 이후 조건 충족 시 지연된 을묘원행으로 즉시 발동되어야 함")
	assert(rp.eulmyo_triggered, "eulmyo_triggered 플래그가 설정되어야 함")

	rp.queue_free()
	tm.queue_free()
	grid.queue_free()
	sim.queue_free()
	print("  -> 지연된 을묘원행(Late Procession) 안전장치 검증 통과.")

## 6. 1800년 정조 승하 10대 멀티 엔딩 분기 조건 전수 검증
func _test_ending_manager_ten_branches() -> void:
	print("[검증 6] 1800년 정조 승하 10대 멀티 엔딩 분기 조건 전수 검증...")
	var sim: SimulationCore = SimulationCoreClass.new()
	var grid: GameGrid = GameGridClass.new()
	root.add_child(sim)
	root.add_child(grid)

	# 기본 정상 상태 프리셋 설정 헬퍼
	var reset_base = func():
		CityStats.reset_to_defaults()
		CityStats.set_hyeonryungwon_visits(3) # 친림 3회
		CityStats.set_crown_prince_education(60) # 세자 보통
		CityStats.set_faction_balance_score(60) # 탕평 보통
		CityStats.set_fortress_defense_power(60) # 방호력 보통
		CityStats.set_academic_power(70) # 학문력 70
		sim.gold = 10000
		sim.rice = 10000
		sim.authority = 70
		sim.loyalty = 70
		sim.academic = 70
		sim.fortress_progress = 75
		grid.fortress_progress = 75
		sim.is_eulmyo_completed = false
		sim.boyuron = true
		sim.segi_policy = true
		for rk in sim.retainers.keys():
			sim.retainers[rk] = false

	# 1) [제1엔딩: 서학의 난 (무너진 사직)] - 서학 인재 등용 + 실학 연구(보유론·서기수용론) 미완료
	reset_base.call()
	sim.retainers["jeong_yakyong"] = true
	sim.boyuron = false # 보유론 미연구
	var r1 = EndingManagerClass.evaluate_12_endings(sim, grid)
	assert(r1["type"] == "WESTERN_COLLAPSE" and r1["num"] == 1, "제1엔딩 서학의 난 판정 오류: %s, num: %d" % [r1["type"], r1["num"]])

	# 2) [제2엔딩: 불효의 저주 (종묘사직의 진노)] - visits == 0
	reset_base.call()
	CityStats.set_hyeonryungwon_visits(0)
	var r2 = EndingManagerClass.evaluate_12_endings(sim, grid)
	assert(r2["type"] == "UNFILIAL_CURSE" and r2["num"] == 2, "제2엔딩 불효의 저주 판정 오류: %s" % r2["type"])

	# 3) [제3엔딩: 피폐한 빈국 (재정 파탄)] - gold <= 0 or grain <= 0
	reset_base.call()
	sim.gold = 0
	var r3 = EndingManagerClass.evaluate_12_endings(sim, grid)
	assert(r3["type"] == "BANKRUPT_RUIN" and r3["num"] == 3, "제3엔딩 피폐한 빈국 판정 오류: %s" % r3["type"])

	# 4) [제4엔딩: 사대부의 반정 (왕권 실추)] - royal_power < 25
	reset_base.call()
	sim.authority = 20
	var r4 = EndingManagerClass.evaluate_12_endings(sim, grid)
	assert(r4["type"] == "COUP_DETAT" and r4["num"] == 4, "제4엔딩 사대부의 반정 판정 오류: %s" % r4["type"])

	# 5) [제5엔딩: 민초의 거대한 봉기 (민중 혁명)] - morale < 30
	reset_base.call()
	sim.loyalty = 25
	var r5 = EndingManagerClass.evaluate_12_endings(sim, grid)
	assert(r5["type"] == "PEASANT_REVOLT" and r5["num"] == 5, "제5엔딩 민초의 거대한 봉기 판정 오류: %s" % r5["type"])

	# 6) [제6엔딩: 함락된 신도시 (국방 붕괴)] - fortress_defense_power < 30 and wall_completion < 70
	reset_base.call()
	CityStats.set_fortress_defense_power(20)
	sim.fortress_progress = 50
	grid.fortress_progress = 50
	var r6 = EndingManagerClass.evaluate_12_endings(sim, grid)
	assert(r6["type"] == "FALLEN_CITY" and r6["num"] == 6, "제6엔딩 함락된 신도시 판정 오류: %s" % r6["type"])

	# 7) [제7엔딩: 약탈당한 풍요 (수탈 엔딩)] - gold >= 100000 and grain >= 100000 and defense < 35
	reset_base.call()
	sim.gold = 150000
	sim.rice = 150000
	CityStats.set_fortress_defense_power(30)
	var r7 = EndingManagerClass.evaluate_12_endings(sim, grid)
	assert(r7["type"] == "PLUNDERED_WEALTH" and r7["num"] == 7, "제7엔딩 약탈당한 풍요 판정 오류: %s" % r7["type"])

	# 8) [제8엔딩: 피바람의 당쟁 (신사화)] - faction_balance_score < 30
	reset_base.call()
	CityStats.set_faction_balance_score(20)
	var r8 = EndingManagerClass.evaluate_12_endings(sim, grid)
	assert(r8["type"] == "BLOODY_FACTION" and r8["num"] == 8, "제8엔딩 피바람의 당쟁 판정 오류: %s" % r8["type"])

	# 9) [제9엔딩: 세도정치의 암운 (외척 발호)] - crown_prince_education < 40
	reset_base.call()
	CityStats.set_crown_prince_education(30)
	var r9 = EndingManagerClass.evaluate_12_endings(sim, grid)
	assert(r9["type"] == "SEDO_DARKNESS" and r9["num"] == 9, "제9엔딩 세도정치의 암운 판정 오류: %s" % r9["type"])

	# 10) [제10엔딩: 무지의 늪 (후진국화의 길)] - wall >= 100 and academic_power < 60
	reset_base.call()
	sim.fortress_progress = 100
	grid.fortress_progress = 100
	CityStats.set_fortress_defense_power(75)
	CityStats.set_academic_power(40)
	sim.academic = 40
	var r10 = EndingManagerClass.evaluate_12_endings(sim, grid)
	assert(r10["type"] == "IGNORANCE_SWAMP" and r10["num"] == 10, "제10엔딩 무지의 늪 판정 오류: %s" % r10["type"])

	# 11) [제11엔딩: 미완의 개혁과 수호의 요새 (수호 엔딩)] - wall >= 100 and defense >= 70 and academic >= 60
	reset_base.call()
	sim.fortress_progress = 100
	grid.fortress_progress = 100
	CityStats.set_fortress_defense_power(75)
	CityStats.set_academic_power(70)
	sim.academic = 70
	sim.is_eulmyo_completed = false # 을묘 미완 -> 진 엔딩 미달
	var r11 = EndingManagerClass.evaluate_12_endings(sim, grid)
	assert(r11["type"] == "DEFENSE_FORTRESS" and r11["num"] == 11, "제11엔딩 수호 요새 판정 오류: %s" % r11["type"])

	# 12) [제12엔딩: 대조선 르네상스 (진 엔딩)] - ALL AND 조건 완벽 충족
	reset_base.call()
	sim.fortress_progress = 100
	grid.fortress_progress = 100
	CityStats.set_fortress_defense_power(85)
	sim.is_eulmyo_completed = true
	CityStats.set_crown_prince_education(75)
	CityStats.set_faction_balance_score(70)
	CityStats.set_academic_power(80)
	sim.academic = 80
	sim.loyalty = 85
	sim.authority = 85
	sim.boyuron = true
	sim.segi_policy = true
	var r12 = EndingManagerClass.evaluate_12_endings(sim, grid)
	assert(r12["type"] == "TRUE_RENAISSANCE" and r12["num"] == 12, "제12엔딩 대조선 르네상스 판정 오류: %s" % r12["type"])

	grid.queue_free()
	sim.queue_free()
	print("  -> 12대 멀티 엔딩 분기 전수 검증 100% 통과 (12/12 PASS).")


## 7. 1800년 도달 시 게임 루프 정지 및 EndingPopup 호출 검증
func _test_ending_trigger_at_1800() -> void:
	print("[검증 7] 1800년 도달 시 시뮬레이션 일시정지 및 EndingPopup 인스턴스화 검증...")
	var sim: SimulationCore = SimulationCoreClass.new()
	var grid: GameGrid = GameGridClass.new()
	var tm: TimeManager = TimeManagerClass.new()
	var em: EndingManagerClass = EndingManagerClass.new()
	root.add_child(sim)
	root.add_child(grid)
	root.add_child(tm)
	root.add_child(em)

	em.setup(sim, grid, tm)

	# 1799년에는 엔딩 미발동
	tm.skip_to_year(1799)
	assert(not em.ending_triggered_flag, "1799년에는 엔딩 플래그가 꺼져 있어야 함")
	assert(tm.current_speed == TimeManager.SpeedMode.NORMAL, "1799년에는 타이머가 동작해야 함")

	# 1800년 도달
	tm.skip_to_year(1800)
	assert(tm.current_year == 1800, "1800년에 도달해야 함")
	assert(em.ending_triggered_flag, "1800년 도달 시 엔딩이 자동으로 발동되어야 함")
	assert(tm.current_speed == TimeManager.SpeedMode.PAUSE, "엔딩 발동 시 시뮬레이션이 일시정지(PAUSE)되어야 함")
	assert(em.ending_popup_instance != null, "EndingPopup 인스턴스가 생성되어야 함")

	em.queue_free()
	tm.queue_free()
	grid.queue_free()
	sim.queue_free()
	print("  -> 1800년 도달 시 일시정지 및 EndingPopup 호출 검증 통과.")

## 을묘원행 조건을 인위적으로 충족/불충족시키는 헬퍼
func _set_eulmyo_satisfaction(sim: SimulationCore, grid: GameGrid, ok: bool) -> void:
	if ok:
		sim.gold = 250000
		sim.rice = 250000
		sim.authority = 85
		sim.loyalty = 90
		sim.fortress_progress = 100
		grid.fortress_progress = 100
		sim.retainers["chae_jegong"] = true
		sim.retainers["jeong_yakyong"] = true
		sim.retainers["kim_hongdo"] = true

		# 사대문 및 장안문-행궁 도로/박석길 타일 모의 배치
		grid.grid[6][26]["building"] = "gate"
		grid.grid[6][26]["gate_name"] = "장안문"
		grid.grid[54][16]["building"] = "gate"
		grid.grid[54][16]["gate_name"] = "팔달문"
		grid.grid[13][6]["building"] = "gate"
		grid.grid[13][6]["gate_name"] = "화서문"
		grid.grid[29][48]["building"] = "gate"
		grid.grid[29][48]["gate_name"] = "창룡문"

		# 북쪽 외곽 도로 (y <= 4)
		grid.grid[2][26]["building"] = "road"
		grid.grid[5][26]["building"] = "road"

		# 장안문 (26, 6) 남쪽부터 행궁 인근까지 도로 연결
		for y: int in range(7, 33):
			grid.grid[y][26]["building"] = "road"
		grid.grid[32][22]["building"] = "haenggung"
		grid.grid[32][25]["building"] = "road"
		grid.grid[32][25]["road_type"] = "stone" # 박석길
		grid.grid[32][26]["building"] = "road"

		# 신풍루(25, 32)부터 팔달문(16, 54)까지 남쪽 도로 연결 (장안문-행궁-팔달문 완전 연결)
		for y: int in range(33, 55):
			grid.grid[y][25]["building"] = "road"
		for x: int in range(17, 26):
			grid.grid[54][x]["building"] = "road"
	else:
		sim.gold = 1000
		sim.rice = 1000
