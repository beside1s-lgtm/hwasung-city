extends SceneTree

## [테스트 슈트: 인구 규모별 한계 조세율 저항선, 가옥/상점 등급별 차등 세수 및 시장 인구부양력 동역학 엔진 검증]

const SimulationCoreClass = preload("res://scripts/SimulationCore.gd")
const GameGridClass = preload("res://scripts/GameGrid.gd")
const PopulationManagerClass = preload("res://scripts/PopulationManager.gd")

func _init() -> void:
	print("=== [테스트 시작] 경제 시뮬레이션 및 조세/시장 동역학 검증 ===")
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	_test_population_tax_resistance_thresholds()
	_test_tax_resistance_population_penalty()
	_test_differentiated_tax_year_transition()
	_test_differentiated_tax_ratios()
	_test_market_support_capacity_at_21_percent()
	_test_market_support_capacity_decay_and_growth()
	_test_market_zero_divide_safeguards()
	_test_simulation_core_process_turn_economy()

	print("=== [테스트 완료] 8대 경제·조세·시장 동역학 검증 100% PASS! ===")
	quit(0)

## 1. 인구 규모별 조세 저항선 임계치 (%) 테이블 검증
func _test_population_tax_resistance_thresholds() -> void:
	print("[검증 1] 인구 규모별 조세 저항선 임계치 검증...")
	# 10만 미만: 임계치 없음(100.0)
	assert(TaxManager.get_tax_threshold_for_population(50000) == 100.0, "10만 미만은 저항선이 없어야 함")
	# 10만 이상 ~ 20만 미만: 15%
	assert(TaxManager.get_tax_threshold_for_population(100000) == 15.0, "10만 임계치 15% 불일치")
	assert(TaxManager.get_tax_threshold_for_population(199999) == 15.0, "19만 임계치 15% 불일치")
	# 20만 이상 ~ 30만 미만: 12%
	assert(TaxManager.get_tax_threshold_for_population(200000) == 12.0, "20만 임계치 12% 불일치")
	# 30만 이상 ~ 40만 미만: 10%
	assert(TaxManager.get_tax_threshold_for_population(300000) == 10.0, "30만 임계치 10% 불일치")
	# 40만 이상 ~ 50만 미만: 8%
	assert(TaxManager.get_tax_threshold_for_population(400000) == 8.0, "40만 임계치 8% 불일치")
	# 50만 이상 ~ 60만 미만: 6%
	assert(TaxManager.get_tax_threshold_for_population(500000) == 6.0, "50만 임계치 6% 불일치")
	# 60만 이상 ~ 70만 미만: 4%
	assert(TaxManager.get_tax_threshold_for_population(600000) == 4.0, "60만 임계치 4% 불일치")
	# 70만 이상: 3%
	assert(TaxManager.get_tax_threshold_for_population(700000) == 3.0, "70만 임계치 3% 불일치")
	assert(TaxManager.get_tax_threshold_for_population(1000000) == 3.0, "100만 임계치 3% 불일치")
	print("  - [PASS] 임계치 테이블 전 구간 일치")

## 2. 조세 저항선 초과 시 인구 유출 페널티 공식 검증
func _test_tax_resistance_population_penalty() -> void:
	print("[검증 2] 조세 저항선 초과 시 인구 유출 공식 검증...")
	# 15만 인구, 조세 총합 18% (임계치 15%, 초과 3%p)
	# 감소율: (18 - 15) * 0.5% = 1.5% (0.015)
	# 150,000 * 0.015 = 2,250명 감소
	var pop: int = 150000
	var total_tax: float = 18.0
	assert(TaxManager.is_tax_resistance_active(pop, total_tax) == true, "저항 발동이어야 함")
	var pen_rate: float = TaxManager.get_tax_resistance_penalty_rate(pop, total_tax)
	assert(is_equal_approx(pen_rate, 0.015), "감소율 0.015 불일치: %f" % pen_rate)

	var res: Dictionary = CityStats.update_population(pop, 1000, total_tax)
	assert(bool(res["is_resisting"]) == true, "is_resisting 플래그 true여야 함")
	assert(int(res["delta"]) == -2250, "감소량 -2250 불일치: %d" % int(res["delta"]))
	assert(int(res["new_population"]) == 150000 - 2250, "인구 감소 후 불일치: %d" % int(res["new_population"]))

	# 임계치 이하 (조세 총합 14%): 저항 미발동, 정상 자연 증가 (1000)
	var res2: Dictionary = CityStats.update_population(pop, 1000, 14.0)
	assert(bool(res2["is_resisting"]) == false, "저항 미발동이어야 함")
	assert(int(res2["delta"]) == 1000, "자연 증가량 1000 불일치")
	assert(int(res2["new_population"]) == 151000, "새 인구 151000 불일치")
	print("  - [PASS] 조세 저항선 인구 감소 공식 정확히 반영")

## 3. 시작 2년(8턴) 보호 기간 전후 차등 과세 활성화 검증
func _test_differentiated_tax_year_transition() -> void:
	print("[검증 3] 2년 보호 기간 전후 차등 과세 전환 검증...")
	var sim: SimulationCore = SimulationCoreClass.new()
	sim.current_year = 1789
	sim.turn = 1
	assert(TaxManager.is_differentiated_tax_active(sim) == false, "1년차(1789)는 기본 세수 유지여야 함")

	sim.current_year = 1790
	sim.turn = 8
	assert(TaxManager.is_differentiated_tax_active(sim) == false, "8턴까지는 기본 세수 유지여야 함")

	sim.current_year = 1791
	sim.turn = 9
	assert(TaxManager.is_differentiated_tax_active(sim) == true, "1791년(2년차 경과)부터 차등 과세 활성화되어야 함")
	print("  - [PASS] 2년차 보호 기간 전환 정확함")

## 4. 등급별 차등 세수 비율 검증 (초가 1 : 기와 2 : 대부호 10 / 일반상점 1 : 고급상점 2)
func _test_differentiated_tax_ratios() -> void:
	print("[검증 4] 가옥 및 상점 등급별 세수 비율 검증...")
	var tier_counts: Dictionary = {
		"thatched_count": 10,  # 초가 10채
		"tile_count": 5,       # 기와 5채
		"mansion_count": 2,    # 대부호 2채
		"basic_shop_count": 8, # 일반상점 8곳
		"luxury_shop_count": 4 # 고급상점 4곳
	}
	var b_house: int = 10
	var b_shop: int = 20

	# 1) 2년 이전 (is_diff_active = false): 1:1:1 및 1:1
	var normal_res: Dictionary = TaxManager.calculate_differentiated_taxes(tier_counts, b_house, b_shop, false)
	# 가옥: (10 + 5 + 2) * 10 = 170
	# 상점: (8 + 4) * 20 = 240
	assert(int(normal_res["house_tax"]) == 170, "튜토리얼 가옥 세수 170 불일치: %d" % int(normal_res["house_tax"]))
	assert(int(normal_res["shop_tax"]) == 240, "튜토리얼 상점 세수 240 불일치: %d" % int(normal_res["shop_tax"]))

	# 2) 2년 이후 (is_diff_active = true): 1:2:10 및 1:2
	var diff_res: Dictionary = TaxManager.calculate_differentiated_taxes(tier_counts, b_house, b_shop, true)
	# 가옥: 10*10 + 5*(10*2) + 2*(10*10) = 100 + 100 + 200 = 400
	# 상점: 8*20 + 4*(20*2) = 160 + 160 = 320
	assert(int(diff_res["house_tax"]) == 400, "차등 가옥 세수 400 불일치: %d" % int(diff_res["house_tax"]))
	assert(int(diff_res["shop_tax"]) == 320, "차등 상점 세수 320 불일치: %d" % int(diff_res["shop_tax"]))
	assert(int(diff_res["total_tax"]) == 720, "차등 총 세수 720 불일치: %d" % int(diff_res["total_tax"]))
	print("  - [PASS] 1:2:10 및 1:2 등급별 차등 세수 비율 완전 일치")

## 5. 조세 총합 21% 기준 시장 인구부양력 고정 검증
func _test_market_support_capacity_at_21_percent() -> void:
	print("[검증 5] 3대 조세 총합 21% 균형점 부양력 고정 검증...")
	MarketManager.set_carrying_ratio(1.0)
	var updated_ratio: float = MarketManager.update_carrying_ratio(21.0)
	assert(is_equal_approx(updated_ratio, 1.0), "21% 조세에서는 부양력 비율이 1.0으로 고정되어야 함")
	print("  - [PASS] 21% 균형점 정체 상태 검증 성공")

## 6. 조세 총합 21% 초과/미만 시 인구부양력 동적 팽창/수축 검증
func _test_market_support_capacity_decay_and_growth() -> void:
	print("[검증 6] 21% 초과 시 수축 및 미만 시 팽창 검증...")
	# 1) 조세 총합 25% (> 21%): 감소폭 (25 - 21) * 0.005 = 0.02 -> 0.98
	MarketManager.set_carrying_ratio(1.0)
	var decayed: float = MarketManager.update_carrying_ratio(25.0)
	assert(is_equal_approx(decayed, 0.98), "25%% 조세 시 0.98로 감소해야 함: %f" % decayed)

	# 2) 조세 총합 15% (< 21%): 증가폭 (21 - 15) * 0.005 = 0.03 -> 1.01
	MarketManager.set_carrying_ratio(0.98)
	var grown: float = MarketManager.update_carrying_ratio(15.0)
	assert(is_equal_approx(grown, 1.01), "15%% 조세 시 1.01로 증가해야 함: %f" % grown)
	print("  - [PASS] 21% 기준 동적 팽창/수축 정확히 작동")

## 7. 경계값 0 나누기(Zero-Divide) 안전 방어 검증
func _test_market_zero_divide_safeguards() -> void:
	print("[검증 7] 시장 수 0, 인구 0 Zero-Divide 안전 방어 검증...")
	assert(MarketManager.calculate_market_support_capacity(0, 1.0) == 0, "상점 0개 시 부양력 0이어야 함")
	assert(MarketManager.get_commercial_density(0, 0) == 0.0, "상점 0, 인구 0 시 0.0 반환(크래시 없음)")
	assert(MarketManager.get_commercial_density(10, 0) == 0.0, "인구 0 시 0 나누기 방어")
	assert(MarketManager.get_commercial_density(0, 1000) == 0.0, "상점 0 시 0.0 반환")
	print("  - [PASS] Zero-Divide 크래시 완벽 방어")

## 8. SimulationCore process_turn_economy() 통합 검증
func _test_simulation_core_process_turn_economy() -> void:
	print("[검증 8] SimulationCore.process_turn_economy() 통합 연동 검증...")
	var sim: SimulationCore = SimulationCoreClass.new()
	sim.current_year = 1792
	sim.turn = 12
	sim.gold = 5000
	sim.population = 250000 # 20만~30만 구간 (임계치 12%)
	sim.tax_rate_land = 6
	sim.tax_rate_market = 6
	sim.tax_rate_military = 6 # 합계 18% > 12% (6% 초과 -> 감소율 3.0%)

	var econ_res: Dictionary = sim.process_turn_economy(null)
	assert(econ_res.has("total_tax_rate"), "total_tax_rate 포함되어야 함")
	assert(econ_res.has("market_dynamics"), "market_dynamics 포함되어야 함")
	assert(econ_res.has("diff_tax"), "diff_tax 포함되어야 함")

	# 인구 유출 확인: 250,000 * 0.03 = 7,500명 감소 -> 242,500
	assert(sim.population < 250000, "조세 저항선 초과로 인구가 감소해야 함")
	assert(sim.population == 250000 - 7500, "인구 감소량 불일치: %d" % sim.population)
	print("  - [PASS] SimulationCore 턴 정산 경제 동역학 통합 완료 (인구 유출: -7,500명)")
