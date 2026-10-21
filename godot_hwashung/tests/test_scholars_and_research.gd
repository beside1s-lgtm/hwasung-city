extends SceneTree

const ScholarManager = preload("res://scripts/ScholarManager.gd")
const CityStats = preload("res://scripts/CityStats.gd")
const TechTreeManager = preload("res://scripts/TechTreeManager.gd")
const EndingManager = preload("res://scripts/EndingManager.gd")
const SimulationCore = preload("res://scripts/SimulationCore.gd")
const GameGrid = preload("res://scripts/GameGrid.gd")
const SaveSystem = preload("res://scripts/SaveSystem.gd")

func _init() -> void:
	print("=== [테스트 시작] 조정 사대부 탕평 인재풀(12인), 무정파 기술 장인 격리, 학문력 연구 엔진 및 12대 엔딩 검증 ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	_test_artisan_isolation_and_faction_balance()
	_test_academic_power_calculation()
	_test_gradual_tech_tree_engine()
	_test_twelve_endings_priority_and_new_endings()
	_test_save_load_null_safe_fallback()

	print("=== [테스트 완료] 모든 사대부 탕평/기술 장인 격리, 학문력 연구 엔진 및 12대 엔딩 검증 100% 통과! ===")
	quit(0)

## 1. 무정파 현장 기술 장인 격리 및 탕평도 계산 모수 제외 검증
func _test_artisan_isolation_and_faction_balance() -> void:
	print("[검증 1] 무정파 기술 장인(김바우, 이성길, 무쇠) 격리 및 탕평도 계산 검증...")

	# 김바우, 이성길, 무쇠 속성 확인
	var bau = ScholarManager.TALENTS_DATA["kim_bau"]
	var seonggil = ScholarManager.TALENTS_DATA["lee_seonggil"]
	var musoe = ScholarManager.TALENTS_DATA["musoe"]

	assert(bau.faction == ScholarManager.Faction.NONE, "김바우는 Faction.NONE이어야 함")
	assert(bau.role_type == ScholarManager.RoleType.FIELD_ARTISAN, "김바우는 FIELD_ARTISAN이어야 함")
	assert(seonggil.faction == ScholarManager.Faction.NONE, "이성길은 Faction.NONE이어야 함")
	assert(seonggil.role_type == ScholarManager.RoleType.FIELD_ARTISAN, "이성길은 FIELD_ARTISAN이어야 함")
	assert(musoe.faction == ScholarManager.Faction.NONE, "무쇠는 Faction.NONE이어야 함")
	assert(musoe.role_type == ScholarManager.RoleType.FIELD_ARTISAN, "무쇠는 FIELD_ARTISAN이어야 함")

	# 1) 무정파 장인만 등용한 경우 -> court_scholars가 0명이므로 기본 평형치 50.0 반환
	var artisans_only := {"kim_bau": true, "lee_seonggil": true, "musoe": true, "baek_dongsu": true}
	var bal_artisan: float = ScholarManager.calculate_faction_balance(artisans_only)
	assert(bal_artisan == 50.0, "무정파 장인만 등용 시 탕평도는 기본값 50.0이어야 함. 현재: %f" % bal_artisan)

	# 2) 4개 정파 각 1인 등용 (노론: 심환지, 소론: 서유구, 남인: 채제공, 북학: 박제가)
	# max_share = 1/4 = 0.25 -> 점수 100점
	var balanced_scholars := {
		"sim_hwanji": true,
		"seo_yugu": true,
		"chae_jegong": true,
		"park_jega": true
	}
	var bal_100: float = ScholarManager.calculate_faction_balance(balanced_scholars)
	assert(is_equal_approx(bal_100, 100.0), "4개 정파 균등 등용 시 탕평도는 100이어야 함. 현재: " + str(bal_100))

	# 3) 위 균형 상태에 무정파 장인 3명(김바우, 이성길, 무쇠)을 추가 등용해도 탕평도 100.0이 그대로 유지되는지 검증!
	var balanced_with_artisans := balanced_scholars.duplicate()
	balanced_with_artisans["kim_bau"] = true
	balanced_with_artisans["lee_seonggil"] = true
	balanced_with_artisans["musoe"] = true
	var bal_with_art: float = ScholarManager.calculate_faction_balance(balanced_with_artisans)
	assert(is_equal_approx(bal_with_art, 100.0), "무정파 장인을 추가해도 탕평도는 분모/페널티에서 100% 제외되어 100.0을 유지해야 함! 현재: " + str(bal_with_art))

	# 4) 한 정파 독점 (노론 3명 독점: 심환지, 홍인한, 김조순) -> 탕평도 0점
	var noron_monopoly := {"sim_hwanji": true, "hong_inhan": true, "kim_josun": true}
	var bal_mono: float = ScholarManager.calculate_faction_balance(noron_monopoly)
	assert(is_equal_approx(bal_mono, 0.0), "노론 100% 독점 시 탕평도는 0이어야 함. 현재: " + str(bal_mono))

	print("  -> 무정파 기술 장인 격리 및 탕평도 100% 배제 검증 통과.")

## 2. 학문력(0~100점) 정밀 산출 공식 검증
func _test_academic_power_calculation() -> void:
	print("[검증 2] 학문력 공식 (향교 20점, 서당 1점, 사대부 스탯 가감, 장인 0점) 검증...")
	CityStats.reset_to_defaults()

	var grid := GameGrid.new()
	root.add_child(grid)

	# 그리드에 향교 1개, 서당 3개 배치
	grid.grid[10][10]["building"] = "hyanggyo"
	grid.grid[15][15]["building"] = "seodang"
	grid.grid[16][16]["building"] = "seodang"
	grid.grid[17][17]["building"] = "seodang"

	# 인재 등용: 정약용(+10), 박제가(+8), 심환지(-3), 김바우(+0, 장인)
	var retainers := {
		"jeong_yakyong": true,
		"park_jega": true,
		"sim_hwanji": true,
		"kim_bau": true
	}

	# 예상 점수: 교육시설(20*1 + 1*3 = 23) + 사대부(10 + 8 - 3 + 0 = 15) = 38점
	var acad: int = CityStats.recalculate_academic_power(grid, retainers)
	assert(acad == 38, "학문력 산출 오류. 기대값: 38, 산출값: " + str(acad))

	# 상한 clamp (100점 초과 시 100점 제한) 검증
	var heavy_grid := GameGrid.new()
	root.add_child(heavy_grid)
	for y in range(6):
		heavy_grid.grid[y][0]["building"] = "hyanggyo" # 6 * 20 = 120점
	var heavy_acad: int = CityStats.recalculate_academic_power(heavy_grid, retainers)
	assert(heavy_acad == 100, "학문력 상한은 100점으로 클램프되어야 함. 현재: " + str(heavy_acad))

	heavy_grid.queue_free()
	grid.queue_free()
	print("  -> 학문력 산출 공식 및 클램프 검증 통과.")

## 3. 점진적 실학 연구 및 세자 서연 엔진 검증
func _test_gradual_tech_tree_engine() -> void:
	print("[검증 3] 점진적 연구 엔진 (턴당 1+floor(학문/10), 1%~10% 진행) 검증...")
	var sim := SimulationCore.new()
	root.add_child(sim)

	var tech_mgr := TechTreeManager.new()
	root.add_child(tech_mgr)

	# 1) 학문력 0일 때: 턴당 진척도 = 1 + floor(0/10) = 1%
	sim.gold = 10000 # 턴당 국고 지속 소모(1,000냥)를 위한 충분한 국고
	sim.retainers["chae_jegong"] = true # 보유론 필수 인재(남인) 등용
	var msg1: String = tech_mgr.start_research("boyuron", sim)


	assert(tech_mgr.current_researching == "boyuron", "보유론 연구가 시작되어야 함")
	assert(tech_mgr.get_progress("boyuron") == 0.0, "시작 시 진행도는 0.0%")

	var t1: Dictionary = tech_mgr.process_turn_tick(0, sim, false)
	assert(t1["step"] == 1.0, "학문력 0일 때 턴당 진행도는 1%여야 함. 현재: " + str(t1["step"]))
	assert(is_equal_approx(tech_mgr.get_progress("boyuron"), 1.0), "1턴 후 진행도는 1.0%여야 함")

	# 2) 학문력 50일 때: 턴당 진척도 = 1 + floor(50/10) = 6%
	var t2: Dictionary = tech_mgr.process_turn_tick(50, sim, false)
	assert(t2["step"] == 6.0, "학문력 50일 때 턴당 진행도는 6%여야 함. 현재: " + str(t2["step"]))
	assert(is_equal_approx(tech_mgr.get_progress("boyuron"), 7.0), "진행도는 7.0%여야 함. 현재: " + str(tech_mgr.get_progress("boyuron")))

	# 3) 학문력 95일 때: 턴당 진척도 = 1 + floor(95/10) = 10% (최대 상한 10%)
	var t3: Dictionary = tech_mgr.process_turn_tick(95, sim, false)
	assert(t3["step"] == 10.0, "학문력 95일 때 턴당 진행도는 10%여야 함. 현재: " + str(t3["step"]))
	assert(is_equal_approx(tech_mgr.get_progress("boyuron"), 17.0), "진행도는 17.0%여야 함")


	# 4) 연구 완료 검증: 100% 도달 시 sim.boyuron 플래그가 설정되고 current_researching이 비워지는지 검증
	tech_mgr.tech_progress_dict["boyuron"] = 95.0
	var t_fin: Dictionary = tech_mgr.process_turn_tick(50, sim, false) # +6% -> 101% -> clamp 100%
	assert(tech_mgr.get_progress("boyuron") == 100.0, "완료 시 진행도는 100.0%로 클램프되어야 함")
	assert(tech_mgr.is_completed("boyuron"), "보유론이 완료 상태여야 함")
	assert(sim.boyuron, "sim.boyuron 플래그가 true여야 함")
	assert(tech_mgr.current_researching == "", "완료 후 현재 연구는 비워져야 함")

	# 5) 세자 서연 검증: 이덕무 보너스(+2%) 포함
	tech_mgr.prince_edu_progress = 50.0
	tech_mgr.start_prince_study(sim)
	assert(tech_mgr.prince_studying, "세자 서연이 시작되어야 함")

	# 학문력 40일 때: base_step = 5.0 + 이덕무(2.0) = 7.0%
	tech_mgr.process_turn_tick(40, sim, true)
	assert(is_equal_approx(tech_mgr.prince_edu_progress, 57.0), "이덕무 보너스 포함 서연 진행도는 57.0이어야 함. 현재: " + str(tech_mgr.prince_edu_progress))
	assert(CityStats.get_crown_prince_education() == 57, "CityStats 세자 교육도와 동기화되어야 함")


	tech_mgr.queue_free()
	sim.queue_free()
	print("  -> 점진적 연구 및 세자 서연 엔진 검증 통과.")

## 4. 신규 엔딩 2종 및 12대 멀티 엔딩 우선순위 검증
func _test_twelve_endings_priority_and_new_endings() -> void:
	print("[검증 4] 신규 엔딩 2종('서학 사상 붕괴', '지식 빈곤') 및 12대 엔딩 우선순위 검증...")
	var sim := SimulationCore.new()
	var grid := GameGrid.new()
	root.add_child(sim)
	root.add_child(grid)

	var reset_base = func():
		CityStats.reset_to_defaults()
		CityStats.set_hyeonryungwon_visits(3)
		CityStats.set_crown_prince_education(70)
		CityStats.set_faction_balance_score(70)
		CityStats.set_fortress_defense_power(70)
		CityStats.set_academic_power(70)
		sim.gold = 10000
		sim.rice = 10000
		sim.authority = 70
		sim.loyalty = 70
		sim.academic = 70
		sim.fortress_progress = 100
		grid.fortress_progress = 100
		sim.is_eulmyo_completed = false
		sim.boyuron = true
		sim.segi_policy = true
		for rk in sim.retainers.keys():
			sim.retainers[rk] = false

	# 1) [신규 1: 서학의 난 (WESTERN_COLLAPSE)] - 서학 인재 등용 + 보유론/서기수용론 미연구
	reset_base.call()
	sim.retainers["jeong_yakyong"] = true
	sim.boyuron = false # 보유론 미연구
	var r1 = EndingManager.evaluate_12_endings(sim, grid)
	assert(r1["type"] == "WESTERN_COLLAPSE", "1순위로 서학의 난 엔딩이 발동되어야 함. 현재: %s" % r1["type"])
	assert(r1["num"] == 1, "엔딩 번호는 1번이어야 함")

	# 서기수용론만 미연구인 경우도 서학의 난 발동
	reset_base.call()
	sim.retainers["jeong_yakyong"] = true
	sim.boyuron = true
	sim.segi_policy = false # 서기수용론 미연구
	var r1_b = EndingManager.evaluate_12_endings(sim, grid)
	assert(r1_b["type"] == "WESTERN_COLLAPSE", "서기수용론 미연구 시에도 서학의 난 엔딩 발동")

	# 둘 다 연구 완료된 상태면 서학의 난 미발동
	reset_base.call()
	sim.retainers["jeong_yakyong"] = true
	sim.boyuron = true
	sim.segi_policy = true
	var r1_safe = EndingManager.evaluate_12_endings(sim, grid)
	assert(r1_safe["type"] != "WESTERN_COLLAPSE", "보유론·서기수용론 모두 완료 시 서학의 난을 피해가야 함")

	# 2) [신규 2: 무지의 늪 (IGNORANCE_SWAMP)] - 성곽 완공(100%), 그러나 학문력 60 미만
	reset_base.call()
	CityStats.set_academic_power(45)
	sim.academic = 45
	var r10 = EndingManager.evaluate_12_endings(sim, grid)
	assert(r10["type"] == "IGNORANCE_SWAMP", "학문력 60 미만 시 10번 무지의 늪 엔딩이어야 함. 현재: %s" % r10["type"])
	assert(r10["num"] == 10, "엔딩 번호는 10번이어야 함")

	# 3) [제11엔딩: 수호 요새 (DEFENSE_FORTRESS)] - 성곽 100% + 방호력 70 이상 + 학문력 60 이상
	reset_base.call()
	CityStats.set_academic_power(65)
	sim.academic = 65
	CityStats.set_fortress_defense_power(75)
	sim.is_eulmyo_completed = false # 을묘 미완 -> 진 엔딩 미달
	var r11 = EndingManager.evaluate_12_endings(sim, grid)
	assert(r11["type"] == "DEFENSE_FORTRESS", "11번 수호 요새 엔딩이어야 함. 현재: %s" % r11["type"])
	assert(r11["num"] == 11, "엔딩 번호는 11번이어야 함")

	# 4) [제12엔딩: 대조선 르네상스 진 엔딩 (TRUE_RENAISSANCE)] - ALL AND 조건 완벽 달성
	reset_base.call()
	CityStats.set_fortress_defense_power(85)
	sim.is_eulmyo_completed = true
	CityStats.set_crown_prince_education(75)
	CityStats.set_faction_balance_score(70)
	CityStats.set_academic_power(75)
	sim.academic = 75
	sim.loyalty = 85
	sim.authority = 85
	sim.boyuron = true
	sim.segi_policy = true
	var r12 = EndingManager.evaluate_12_endings(sim, grid)
	assert(r12["type"] == "TRUE_RENAISSANCE", "12번 진 엔딩이어야 함. 현재: %s" % r12["type"])
	assert(r12["num"] == 12, "엔딩 번호는 12번이어야 함")

	# 진 엔딩 조건 중 학문력만 55점이면 -> 10번 무지의 늪으로 분기되어야 함!
	CityStats.set_academic_power(55)
	sim.academic = 55
	var r12_fail = EndingManager.evaluate_12_endings(sim, grid)
	assert(r12_fail["type"] == "IGNORANCE_SWAMP", "학문력 60 미만 시 진 엔딩이 차단되고 10번 무지의 늪이어야 함. 현재: %s" % r12_fail["type"])

	grid.queue_free()
	sim.queue_free()
	print("  -> 신규 엔딩 2종 및 12대 엔딩 우선순위 검증 통과.")

## 5. 세이브/로드 Null-safe Fallback 검증
func _test_save_load_null_safe_fallback() -> void:
	print("[검증 5] 세이브/로드 신규 필드(academic_power, tech_progress) Null-safe Fallback 검증...")

	# 빈 데이터 역직렬화
	CityStats.deserialize({})
	assert(CityStats.get_academic_power() == 0, "빈 데이터 시 academic_power는 0으로 안전 초기화")

	var tech_mgr := TechTreeManager.new()
	root.add_child(tech_mgr)
	tech_mgr.deserialize({})
	assert(tech_mgr.get_progress("boyuron") == 0.0, "빈 데이터 시 boyuron 진행도는 0.0")
	assert(tech_mgr.prince_edu_progress == 0.0, "빈 데이터 시 세자 교육도는 기본 0.0")
	assert(tech_mgr.current_researching == "", "빈 데이터 시 current_researching은 빈 문자열")

	tech_mgr.queue_free()
	print("  -> 세이브/로드 Null-safe Fallback 검증 통과.")
