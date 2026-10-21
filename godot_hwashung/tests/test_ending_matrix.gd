extends SceneTree

const EndingManager = preload("res://scripts/EndingManager.gd")
const CityStats = preload("res://scripts/CityStats.gd")
const SimulationCore = preload("res://scripts/SimulationCore.gd")
const GameGrid = preload("res://scripts/GameGrid.gd")

func _init() -> void:
	print("=== [결함 심각도(Deficit Severity) 매트릭스 엔진 전용 단위 테스트 시작] ===")
	_run_tests()
	print("=== [모든 결함 심각도 단위 테스트 100% 통과 (PASS)] ===")
	quit(0)

func _run_tests() -> void:
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
		sim.gold = 50000
		sim.rice = 50000
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

	# 1. 재정 파탄 임계치 검증 (금화 9,999냥 또는 곡식 9,999석일 때 재정 파탄 후보 정상 등록 및 도출)
	print("[검증 1] 재정 파탄 임계치 상향(10,000냥/석) 검증...")
	reset_base.call()
	sim.fortress_progress = 80 # 11번 수호 미달 유도
	grid.fortress_progress = 80
	sim.gold = 9999
	sim.rice = 50000
	var res1 = EndingManager.evaluate_12_endings(sim, grid)
	assert(res1["type"] == "BANKRUPT_RUIN", "금 9999냥일 때 재정 파탄 엔딩이어야 함. 결과: %s" % res1["type"])
	assert(res1["num"] == 3, "엔딩 번호는 3번이어야 함")

	reset_base.call()
	sim.fortress_progress = 80
	grid.fortress_progress = 80
	sim.gold = 50000
	sim.rice = 9999
	var res1_grain = EndingManager.evaluate_12_endings(sim, grid)
	assert(res1_grain["type"] == "BANKRUPT_RUIN", "곡식 9999석일 때 재정 파탄 엔딩이어야 함. 결과: %s" % res1_grain["type"])

	# 2. STEP 2 특수 인과관계 엔딩 우선권 검증: 서학 인재 등용 + 미완수 시 1번 사상 붕괴 우선
	print("[검증 2] STEP 2 서학 인재 등용 및 실학 미연구 시 최우선 사상 붕괴 검증...")
	reset_base.call()
	sim.fortress_progress = 80
	grid.fortress_progress = 80
	sim.retainers["jeong_yakyong"] = true
	sim.boyuron = false
	sim.gold = 1000 # 재정도 파탄 상태
	sim.authority = 10 # 왕권도 파탄 상태
	var res2 = EndingManager.evaluate_12_endings(sim, grid)
	assert(res2["type"] == "WESTERN_COLLAPSE", "서학 인재 등용 후 미연구 시 재정/왕권 파탄보다 1번 사상 붕괴가 우선해야 함. 결과: %s" % res2["type"])

	# 3. STEP 2 현륭원 친림 0회 시 2번 불효의 저주 우선권
	print("[검증 3] STEP 2 현륭원 친림 0회 시 불효의 저주 우선 검증...")
	reset_base.call()
	sim.fortress_progress = 80
	grid.fortress_progress = 80
	CityStats.set_hyeonryungwon_visits(0)
	sim.gold = 2000
	sim.loyalty = 15
	var res3 = EndingManager.evaluate_12_endings(sim, grid)
	assert(res3["type"] == "UNFILIAL_CURSE", "친림 0회 시 2번 불효의 저주가 우선해야 함. 결과: %s" % res3["type"])

	# 4. STEP 3 다중 파탄 시 심각도(Severity) 점수제 경쟁: 왕권 24 vs 민심 20 -> 5번 민중 봉기 승리
	print("[검증 4] 왕권 24 (S=0.044) vs 민심 20 (S=0.366) 경쟁 검증...")
	reset_base.call()
	sim.fortress_progress = 80
	grid.fortress_progress = 80
	sim.authority = 24 # s4 = (25-24)/25 * 1.1 = 0.044
	sim.loyalty = 20   # s5 = (30-20)/30 * 1.1 = 0.3666
	var res4 = EndingManager.evaluate_12_endings(sim, grid)
	assert(res4["type"] == "PEASANT_REVOLT", "민심 20이 왕권 24보다 더 심각하므로 5번 민중 봉기여야 함. 결과: %s" % res4["type"])

	# 5. STEP 3 금화 2,000냥 (S3=0.96) vs 국방력 28 (S6=0.04) -> 3번 재정 파탄 승리
	print("[검증 5] 금화 2,000냥 (S=0.96) vs 국방력 28/성곽70% (S=0.04) 경쟁 검증...")
	reset_base.call()
	sim.fortress_progress = 70
	grid.fortress_progress = 70
	CityStats.set_fortress_defense_power(28)
	sim.gold = 2000 # s3 = (10000-2000)/10000 * 1.2 = 0.96
	var res5 = EndingManager.evaluate_12_endings(sim, grid)
	assert(res5["type"] == "BANKRUPT_RUIN", "재정이 더 심각하므로 3번 재정 파탄이어야 함. 결과: %s" % res5["type"])

	# 6. STEP 3 탕평도 15 단독 파탄 시 8번 정쟁 엔딩 도출
	print("[검증 6] 탕평도 15 단독 결함 시 8번 피바람의 당쟁 엔딩 검증...")
	reset_base.call()
	sim.fortress_progress = 80
	grid.fortress_progress = 80
	CityStats.set_faction_balance_score(15)
	var res6 = EndingManager.evaluate_12_endings(sim, grid)
	assert(res6["type"] == "BLOODY_FACTION", "탕평도 15 결함 시 8번 정쟁 엔딩이어야 함. 결과: %s" % res6["type"])

	# 7. STEP 3 세자 교육도 20 단독 파탄 시 9번 세도정치 엔딩 도출
	print("[검증 7] 세자 교육도 20 결함 시 9번 세도정치 엔딩 검증...")
	reset_base.call()
	sim.fortress_progress = 80
	grid.fortress_progress = 80
	CityStats.set_crown_prince_education(20)
	var res7 = EndingManager.evaluate_12_endings(sim, grid)
	assert(res7["type"] == "SEDO_DARKNESS", "세자 교육 20 결함 시 9번 세도정치 엔딩이어야 함. 결과: %s" % res7["type"])

	# 8. STEP 1 진 엔딩(12번) 성취 평가 선행 격리 검증
	print("[검증 8] 진 엔딩(12번) 최고 위업 선행 격리 검증...")
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
	var res8 = EndingManager.evaluate_12_endings(sim, grid)
	assert(res8["type"] == "TRUE_RENAISSANCE", "진 엔딩 조건 충족 시 12번 진 엔딩이어야 함. 결과: %s" % res8["type"])

	# 9. evaluate_final_ending_1800 별칭 메서드 동작 검증
	var res9 = EndingManager.evaluate_final_ending_1800(sim, grid)
	assert(res9["type"] == "TRUE_RENAISSANCE", "evaluate_final_ending_1800도 동일하게 12번 진 엔딩이어야 함")

	grid.queue_free()
	sim.queue_free()
