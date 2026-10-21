extends SceneTree

const PopulationManagerClass = preload("res://scripts/PopulationManager.gd")
const BuildingManagerClass = preload("res://scripts/BuildingManager.gd")
const ResourceManagerClass = preload("res://scripts/ResourceManager.gd")
const SimulationCoreClass = preload("res://scripts/SimulationCore.gd")
const GameGridClass = preload("res://scripts/GameGrid.gd")
const SaveSystemClass = preload("res://scripts/SaveSystem.gd")

func _init() -> void:
	print("=== [테스트 시작] 화성 신도시 인구 유입책, 가옥-인구 동적 수용량, 폐허 순환 및 복지·세제 정책 검증 ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	_test_haenggung_completion_boost()
	_test_housing_capacity_and_calculation()
	_test_population_decline_and_ruin_lifecycle()
	_test_population_recovery_and_restoration()
	_test_tax_policy_effects()
	_test_five_welfare_facilities_cumulative_bonus()
	_test_seasonal_growth_rate_clamping_and_decline()
	_test_seasonal_tax_revenue_formula()
	_test_save_system_population_and_ruins_integrity()

	print("=== [테스트 완료] 정조의 화성 신도시 인구 역학 시스템 9대 전 항목 100% 통과! ===")
	quit(0)

## 1. 화성행궁 완공 인구 부스팅 (+6,000명 즉시 유입 및 기본 수용량 6,000 인정)
func _test_haenggung_completion_boost() -> void:
	print("[검증 1] 화성행궁 완공 인구 +6,000명 즉시 유입 및 기본 수용량 검증...")
	var sim: SimulationCore = SimulationCoreClass.new()
	assert(sim.population == 120, "초기 인구는 120명이어야 함")
	assert(sim.pop_manager.haenggung_completed == false, "초기 행궁 완공 상태는 false여야 함")
	assert(sim.pop_manager.get_total_housing_capacity() == 0, "가옥 없을 때 초기 행궁 미완공 수용량은 0이어야 함")

	# 행궁 완공 발화
	var res: Dictionary = sim.trigger_haenggung_completion()
	assert(res.get("applied", false) == true, "행궁 완공 부스팅 발화 실패")
	assert(res.get("added_pop", 0) == 6000, "행궁 완공 추가 인구 6,000 불일치")
	assert(sim.population == 6120, "행궁 완공 후 총 인구 6,120 불일치: %d" % sim.population)
	assert(sim.pop_manager.haenggung_completed == true, "행궁 완공 플래그 true여야 함")
	assert(sim.pop_manager.get_total_housing_capacity() == 6000, "행궁 자체 기본 수용량 6,000 인정 실패")

	# 중복 발화 방지 (1회 발화 보장)
	var dup_res: Dictionary = sim.trigger_haenggung_completion()
	assert(dup_res.get("applied", false) == false, "행궁 중복 완공 부스팅은 차단되어야 함")
	assert(sim.population == 6120, "중복 발화 후 인구 변동 없어야 함")
	print("  - [PASS] 화성행궁 완공 시 6,000명 즉시 유입 및 기본 수용량 인정 성공")

## 2. 가옥 수용량 및 총 주거 수용 한계치 공식 검증 (1채당 최대 100명)
func _test_housing_capacity_and_calculation() -> void:
	print("[검증 2] 민가 1채당 최대 100명 인구 수용량 및 Capacity 공식 검증...")
	var pop_mgr: PopulationManager = PopulationManagerClass.new(120)
	pop_mgr.haenggung_completed = true
	assert(pop_mgr.get_total_housing_capacity() == 6000, "행궁만 있을 때 수용량 6,000")

	# 가옥 5채 등록
	for i in range(5):
		pop_mgr.register_house_tile(Vector2i(10 + i, 10), false)
	assert(pop_mgr.active_houses_list.size() == 5, "활성 가옥 5채 등록 실패")
	# 총 수용 한계치 = 6000 + 5 * 100 = 6,500
	assert(pop_mgr.get_total_housing_capacity() == 6500, "총 수용 한계치 6,500 불일치: %d" % pop_mgr.get_total_housing_capacity())

	# 가옥 10채 추가 등록
	for i in range(10):
		pop_mgr.register_house_tile(Vector2i(20 + i, 20), false)
	assert(pop_mgr.active_houses_list.size() == 15, "활성 가옥 15채 등록 실패")
	assert(pop_mgr.get_total_housing_capacity() == 7500, "총 수용 한계치 7,500 불일치: %d" % pop_mgr.get_total_housing_capacity())
	print("  - [PASS] 가옥당 100명 수용량 및 총 주거 수용 한계치 공식 검증 성공")

## 3. 인구 감소 시 [정상 가옥 -> 폐허] 자동 전환 라이프사이클 검증 (비파괴적 전환)
func _test_population_decline_and_ruin_lifecycle() -> void:
	print("[검증 3] 인구 감소 시 잉여 가옥의 비파괴적 폐허화(is_ruined = true) 검증...")
	var grid: GameGrid = GameGridClass.new()
	var pop_mgr: PopulationManager = PopulationManagerClass.new(6300)
	pop_mgr.haenggung_completed = true
	# 6,300명이면 행궁 6,000명 외에 300명이 필요하므로 3채의 가옥이 필요
	# 5채의 가옥을 등록 (2채 잉여 발생)
	for i in range(5):
		var pos := Vector2i(15 + i, 15)
		grid.grid[pos.y][pos.x]["building"] = "res_1"
		grid.grid[pos.y][pos.x]["is_ruined"] = false
		pop_mgr.register_house_tile(pos, false)

	assert(pop_mgr.active_houses_list.size() == 5, "초기 활성 가옥 5채")
	assert(pop_mgr.ruined_houses_list.size() == 0, "초기 폐허 0채")

	# 인구 대비 점유율 갱신 실행
	var res: Dictionary = pop_mgr.update_housing_occupancy(grid)
	assert(res["ruined_count"] == 2, "잉여 가옥 2채가 폐허로 전환되어야 함: %d" % res["ruined_count"])
	assert(pop_mgr.active_houses_list.size() == 3, "활성 가옥 3채 유지되어야 함: %d" % pop_mgr.active_houses_list.size())
	assert(pop_mgr.ruined_houses_list.size() == 2, "폐허 목록 2채여야 함: %d" % pop_mgr.ruined_houses_list.size())

	# 비파괴성 검증: 타일 객체 및 building 속성은 그대로 유지되며 is_ruined 플래그만 true로 변경
	for p: Vector2i in res["ruined_tiles"]:
		var cell: Dictionary = grid.grid[p.y][p.x]
		assert(cell["building"] == "res_1", "건물 타입 res_1 보존 실패")
		assert(cell["is_ruined"] == true, "is_ruined 플래그 true 설정 실패")
	print("  - [PASS] 인구 감소 시 잉여 가옥 폐허화 및 비파괴성 검증 성공")

## 4. 인구 재증가 시 [폐허 -> 정상 가옥] 자동 복원 검증
func _test_population_recovery_and_restoration() -> void:
	print("[검증 4] 인구 재증가 시 기존 폐허 타일 우선 자동 복원 검증...")
	var grid: GameGrid = GameGridClass.new()
	var pop_mgr: PopulationManager = PopulationManagerClass.new(6100) # 필요 가옥 1채
	pop_mgr.haenggung_completed = true

	# 1채 활성, 3채 폐허 상태 설정
	var pos1 := Vector2i(5, 5)
	grid.grid[pos1.y][pos1.x]["building"] = "res_1"
	grid.grid[pos1.y][pos1.x]["is_ruined"] = false
	pop_mgr.register_house_tile(pos1, false)

	for i in range(3):
		var rp := Vector2i(6 + i, 5)
		grid.grid[rp.y][rp.x]["building"] = "res_1"
		grid.grid[rp.y][rp.x]["is_ruined"] = true
		pop_mgr.register_house_tile(rp, true)

	assert(pop_mgr.active_houses_list.size() == 1, "활성 가옥 1채")
	assert(pop_mgr.ruined_houses_list.size() == 3, "폐허 가옥 3채")

	# 인구가 6,350명으로 증가 (필요 가옥 4채)
	pop_mgr.total_population = 6350
	var res: Dictionary = pop_mgr.update_housing_occupancy(grid)

	assert(res["restored_count"] == 3, "부족한 3채가 폐허에서 정상 복원되어야 함: %d" % res["restored_count"])
	assert(pop_mgr.active_houses_list.size() == 4, "활성 가옥 4채로 복원되어야 함: %d" % pop_mgr.active_houses_list.size())
	assert(pop_mgr.ruined_houses_list.size() == 0, "폐허 목록 0채여야 함: %d" % pop_mgr.ruined_houses_list.size())

	# 그리드 상의 is_ruined 플래그가 false로 복원되었는지 확인
	for p: Vector2i in res["restored_tiles"]:
		var cell: Dictionary = grid.grid[p.y][p.x]
		assert(cell["building"] == "res_1", "건물 타입 보존")
		assert(cell["is_ruined"] == false, "is_ruined 플래그 false 복원 실패")
	print("  - [PASS] 인구 재증가 시 폐허 자동 복원 검증 성공")

## 5. 세율 정책 (감면/표준/가혹) 민심, 계절 증가율, 세수 계수 검증
func _test_tax_policy_effects() -> void:
	print("[검증 5] 세금 정책 3단계(감면/표준/가혹) 계수 및 효과 검증...")
	var pop_mgr: PopulationManager = PopulationManagerClass.new(10000)

	# 1) 감면책 (EXEMPT): 민심 +15, 계절 증가율 +2.0%p (+0.02), 세수 계수 0.5배
	pop_mgr.set_tax_policy(PopulationManagerClass.TaxPolicy.EXEMPT)
	assert(pop_mgr.get_tax_policy() == PopulationManagerClass.TaxPolicy.EXEMPT, "감면책 설정 실패")
	assert(pop_mgr.get_tax_policy_loyalty_effect() == 15, "감면책 민심 +15 불일치")
	assert(is_equal_approx(pop_mgr.get_tax_policy_growth_rate_effect(), 0.020), "감면책 증가율 +0.02 불일치")
	assert(is_equal_approx(pop_mgr.get_tax_rate_multiplier(), 0.5), "감면책 세수 계수 0.5 불일치")
	assert(pop_mgr.calculate_seasonal_tax(10000) == 750, "감면책 10,000명 세수 750냥 불일치: %d" % pop_mgr.calculate_seasonal_tax(10000))

	# 2) 표준세 (STANDARD): 민심 0, 계절 증가율 +0.0%p (0.00), 세수 계수 1.0배
	pop_mgr.set_tax_policy(PopulationManagerClass.TaxPolicy.STANDARD)
	assert(pop_mgr.get_tax_policy_loyalty_effect() == 0, "표준세 민심 0 불일치")
	assert(is_equal_approx(pop_mgr.get_tax_policy_growth_rate_effect(), 0.000), "표준세 증가율 0.0 불일치")
	assert(is_equal_approx(pop_mgr.get_tax_rate_multiplier(), 1.0), "표준세 세수 계수 1.0 불일치")
	assert(pop_mgr.calculate_seasonal_tax(10000) == 1500, "표준세 10,000명 세수 1,500냥 불일치: %d" % pop_mgr.calculate_seasonal_tax(10000))

	# 3) 가혹세 (HARSH): 민심 -25, 계절 증가율 -2.5%p (-0.025), 세수 계수 1.5배
	pop_mgr.set_tax_policy(PopulationManagerClass.TaxPolicy.HARSH)
	assert(pop_mgr.get_tax_policy_loyalty_effect() == -25, "가혹세 민심 -25 불일치")
	assert(is_equal_approx(pop_mgr.get_tax_policy_growth_rate_effect(), -0.025), "가혹세 증가율 -0.025 불일치")
	assert(is_equal_approx(pop_mgr.get_tax_rate_multiplier(), 1.5), "가혹세 세수 계수 1.5 불일치")
	assert(pop_mgr.calculate_seasonal_tax(10000) == 2250, "가혹세 10,000명 세수 2,250냥 불일치: %d" % pop_mgr.calculate_seasonal_tax(10000))
	print("  - [PASS] 세율 정책 3단계 효과 및 세수 계수 검증 성공")

## 6. 5대 복지·수리 시설 누적 보너스 검증
func _test_five_welfare_facilities_cumulative_bonus() -> void:
	print("[검증 6] 5대 복지·수리 시설(만석거/축만제/순라청/멸화군/진휼소) 누적 보너스 검증...")
	var pop_mgr: PopulationManager = PopulationManagerClass.new(1000)
	var welfare: Dictionary = {
		"manseokgeo": false, "chukmanje": false, "patrol": false, "firefighter": false, "jinhulso": false
	}

	# 아무 시설도 없을 때
	var eff0: Dictionary = pop_mgr.get_welfare_effects(welfare)
	assert(eff0["loyalty_bonus"] == 0 and is_equal_approx(eff0["growth_rate_bonus"], 0.0), "기본 효과 0")

	# 만석거: 민심 +5, 증가율 +0.8%p (+0.008)
	welfare["manseokgeo"] = true
	var eff1: Dictionary = pop_mgr.get_welfare_effects(welfare)
	assert(eff1["loyalty_bonus"] == 5 and is_equal_approx(eff1["growth_rate_bonus"], 0.008), "만석거 보너스 불일치")

	# 축만제 추가: 민심 +5, 증가율 +0.8%p (누적 +10, +0.016)
	welfare["chukmanje"] = true
	var eff2: Dictionary = pop_mgr.get_welfare_effects(welfare)
	assert(eff2["loyalty_bonus"] == 10 and is_equal_approx(eff2["growth_rate_bonus"], 0.016), "축만제 누적 보너스 불일치")

	# 순라청 추가: 민심 +4, 증가율 +0.6%p (누적 +14, +0.022)
	welfare["patrol"] = true
	var eff3: Dictionary = pop_mgr.get_welfare_effects(welfare)
	assert(eff3["loyalty_bonus"] == 14 and is_equal_approx(eff3["growth_rate_bonus"], 0.022), "순라청 누적 보너스 불일치")

	# 멸화군 추가: 민심 +4, 증가율 +0.6%p (누적 +18, +0.028)
	welfare["firefighter"] = true
	var eff4: Dictionary = pop_mgr.get_welfare_effects(welfare)
	assert(eff4["loyalty_bonus"] == 18 and is_equal_approx(eff4["growth_rate_bonus"], 0.028), "멸화군 누적 보너스 불일치")

	# 진휼소 추가: 민심 +6, 증가율 +1.0%p (누적 +24, +0.038)
	welfare["jinhulso"] = true
	var eff5: Dictionary = pop_mgr.get_welfare_effects(welfare)
	assert(eff5["loyalty_bonus"] == 24, "5대 복지 시설 누적 민심 24 불일치: %d" % eff5["loyalty_bonus"])
	assert(is_equal_approx(eff5["growth_rate_bonus"], 0.038), "5대 복지 시설 누적 증가율 +0.038 불일치: %f" % eff5["growth_rate_bonus"])
	print("  - [PASS] 5대 복지·수리 시설 누적 보너스 검증 성공")

## 7. 계절별 인구 증가율 상하한 통제(0%~5%) 및 가혹세 역성장(인구 감소) 검증
func _test_seasonal_growth_rate_clamping_and_decline() -> void:
	print("[검증 7] 계절별 인구 증가율 공식, 0~5% 클램프 및 가혹세 역성장 검증...")
	var pop_mgr: PopulationManager = PopulationManagerClass.new(1000)

	# 1) 표준세, 민심 50, 복지시설 없음 -> 기본 1.0% (0.01)
	pop_mgr.set_tax_policy(PopulationManagerClass.TaxPolicy.STANDARD)
	var w_empty: Dictionary = {}
	var rate_normal: float = pop_mgr.calculate_seasonal_growth_rate(50, w_empty)
	assert(is_equal_approx(rate_normal, 0.010), "기본 증가율 1.0% 불일치: %f" % rate_normal)

	# 2) 감면책(+2.0%p) + 5대 복지시설(+3.8%p) + 민심 100(+1.0%p) = 총 7.8%p -> 최대 5.0% 상한 클램프
	pop_mgr.set_tax_policy(PopulationManagerClass.TaxPolicy.EXEMPT)
	var w_all: Dictionary = {
		"manseokgeo": true, "chukmanje": true, "patrol": true, "firefighter": true, "jinhulso": true
	}
	var rate_max: float = pop_mgr.calculate_seasonal_growth_rate(100, w_all)
	assert(is_equal_approx(rate_max, 0.050), "최대 증가율 상한 5.0% 클램프 실패: %f" % rate_max)

	# 3) 표준세, 민심 0 -> 1.0% - 1.0% = 0.0% -> 최소 0.0% 하한 통제
	pop_mgr.set_tax_policy(PopulationManagerClass.TaxPolicy.STANDARD)
	var rate_min: float = pop_mgr.calculate_seasonal_growth_rate(0, w_empty)
	assert(is_equal_approx(rate_min, 0.000), "일반 상황 최소 증가율 0.0% 통제 실패: %f" % rate_min)

	# 4) 가혹세 설정 시: 기본 1.0% + 가혹세 -2.5%p = -1.5% (-0.015) -> 인구 순감소(역성장) 허용!
	pop_mgr.set_tax_policy(PopulationManagerClass.TaxPolicy.HARSH)
	var rate_decline: float = pop_mgr.calculate_seasonal_growth_rate(50, w_empty)
	assert(rate_decline < 0.0, "가혹세 시 음수 증가율(인구 순감소) 허용되어야 함: %f" % rate_decline)
	assert(is_equal_approx(rate_decline, -0.015), "가혹세 증가율 -1.5% 불일치: %f" % rate_decline)

	# 5) 가혹세 + 민심 파탄(민심 10) 시: 기본 1.0% + 가혹세 -2.5%p + 민심(-0.8%p) = -2.3%
	var rate_severe: float = pop_mgr.calculate_seasonal_growth_rate(10, w_empty)
	assert(rate_severe < -0.02, "가혹세 및 민심 파탄 시 심각한 인구 감소 발생해야 함: %f" % rate_severe)
	print("  - [PASS] 증가율 0%~5% 클램프 및 가혹세 역성장 검증 성공")

## 8. 계절 세수 공식 및 ResourceManager 연동 검증
func _test_seasonal_tax_revenue_formula() -> void:
	print("[검증 8] 인구 비례 계절 세수 공식 및 ResourceManager 국고 입고 검증...")
	var sim: SimulationCore = SimulationCoreClass.new()
	sim.population = 10000
	sim.gold = 1000
	sim.pop_manager.total_population = 10000
	sim.pop_manager.set_tax_policy(PopulationManagerClass.TaxPolicy.STANDARD)

	# 표준세: floor(10,000 * 0.15 * 1.0) = 1,500냥
	var tax_std: int = sim.pop_manager.calculate_seasonal_tax(10000)
	assert(tax_std == 1500, "표준세 10,000명 세수 1,500냥 불일치: %d" % tax_std)

	# ResourceManager를 통한 세수 입고
	var new_gold: int = ResourceManagerClass.add_gold(tax_std, sim)
	assert(new_gold == 2500 and sim.gold == 2500, "국고 1,500냥 입고 후 총 2,500냥 불일치: %d" % sim.gold)

	# 계절 틱 처리 연동: process_seasonal_population()
	sim.population = 8000
	sim.pop_manager.total_population = 8000
	sim.pop_manager.set_tax_policy(PopulationManagerClass.TaxPolicy.EXEMPT) # 감면책: 0.5배
	# floor(8,000 * 0.15 * 0.5) = 600냥
	var old_g: int = sim.gold
	var tick_res: Dictionary = sim.process_seasonal_population()
	assert(tick_res["seasonal_tax"] == 600, "감면책 세수 600냥 불일치: %d" % tick_res["seasonal_tax"])
	assert(sim.gold == old_g + 600, "계절 틱 세수 국고 반영 실패: %d" % sim.gold)
	print("  - [PASS] 인구 비례 계절 세수 공식 및 국고 입고 검증 성공")

## 9. SaveSystem 직렬화 및 역직렬화 무결성 검증
func _test_save_system_population_and_ruins_integrity() -> void:
	print("[검증 9] SaveSystem 인구수, 세율 정책, 폐허 가옥 목록 직렬화 무결성 검증...")
	var sim: SimulationCore = SimulationCoreClass.new()
	var grid: GameGrid = GameGridClass.new()
	sim.population = 7500
	sim.pop_manager.total_population = 7500
	sim.pop_manager.haenggung_completed = true
	sim.pop_manager.haenggung_boost_applied = true
	sim.pop_manager.set_tax_policy(PopulationManagerClass.TaxPolicy.EXEMPT)

	# 타일 1개는 활성 가옥, 1개는 폐허 가옥
	var p_active := Vector2i(12, 12)
	var p_ruined := Vector2i(13, 13)
	grid.grid[p_active.y][p_active.x]["building"] = "res_1"
	grid.grid[p_active.y][p_active.x]["is_ruined"] = false
	grid.grid[p_ruined.y][p_ruined.x]["building"] = "res_1"
	grid.grid[p_ruined.y][p_ruined.x]["is_ruined"] = true
	sim.pop_manager.register_house_tile(p_active, false)
	sim.pop_manager.register_house_tile(p_ruined, true)

	# 슬롯 9에 저장
	var save_ok: bool = SaveSystemClass.save_game(9, sim, grid)
	assert(save_ok, "게임 저장 실패")

	# 새 시뮬레이션 및 그리드로 로드 검증
	var sim_loaded: SimulationCore = SimulationCoreClass.new()
	var grid_loaded: GameGrid = GameGridClass.new()
	var load_ok: bool = SaveSystemClass.load_game(9, sim_loaded, grid_loaded)
	assert(load_ok, "게임 로드 실패")

	# 인구 및 정책 복원 검증
	assert(sim_loaded.population == 7500, "인구수 7,500 복원 실패: %d" % sim_loaded.population)
	assert(sim_loaded.pop_manager.total_population == 7500, "pop_manager 인구수 복원 실패")
	assert(sim_loaded.pop_manager.haenggung_completed == true, "행궁 완공 상태 복원 실패")
	assert(sim_loaded.pop_manager.haenggung_boost_applied == true, "행궁 부스팅 플래그 복원 실패")
	assert(sim_loaded.get_tax_policy() == PopulationManagerClass.TaxPolicy.EXEMPT, "세율 정책 EXEMPT 복원 실패")

	# 타일 및 폐허 목록 복원 검증
	assert(grid_loaded.grid[p_active.y][p_active.x]["is_ruined"] == false, "활성 가옥 is_ruined false 복원 실패")
	assert(grid_loaded.grid[p_ruined.y][p_ruined.x]["is_ruined"] == true, "폐허 가옥 is_ruined true 복원 실패")
	assert(sim_loaded.pop_manager.active_houses_list.has(p_active), "활성 가옥 목록 복원 실패")
	assert(sim_loaded.pop_manager.ruined_houses_list.has(p_ruined), "폐허 가옥 목록 복원 실패")

	# 테스트 슬롯 파일 정리
	SaveSystemClass.delete_save(9)
	print("  - [PASS] SaveSystem 인구수/세율/폐허 목록 직렬화 무결성 검증 성공")
