extends SceneTree

## [공방 경제·군사 복합 시너지 엔진 종합 검증 테스트]
## 1. 상점 20개 / 공방 1개 -> 10개만 +2% 세수 버프, 나머지 10개 기본 세수
## 2. 상점 40개 / 공방 5개 -> 40개 전체 +2% 세수 버프 (초과분 버프 없음)
## 3. 1년(4턴) 경과 후 공방 0개 시 국방력 -50% 페널티 및 초기 4턴 유예 검증
## 4. 공방 1개소당 +0.25% 선형 증가 및 20개소 이상 시 최대 +5.0% 상한 고정 검증
## 5. 공방 완공/철거 시 실시간 O(1) 카운터 델타 반영 및 세수/군사력 연동 검증

func _init() -> void:
	print("=== 공방(수공업·대장간) 경제·군사 복합 시너지 엔진 검증 시작 ===")

	test_criteria_1_partial_buff()
	test_criteria_2_full_buff_and_overflow_cap()
	test_criteria_3_grace_period_and_penalty()
	test_criteria_4_linear_military_buff_and_cap()
	test_criteria_5_realtime_demolish_and_build()

	print("\n[SUCCESS] 모든 5대 수락 조건(Acceptance Criteria) 검증 통과!")
	quit(0)

## 1. 상점이 20개일 때 공방이 1개면 10개 상점에만 +2% 세수가 붙고, 나머지 10개는 기본 세수가 적용되는가?
func test_criteria_1_partial_buff() -> void:
	print("\n--- 검증 1: 부분 버프 적용 (상점 20개, 공방 1개) ---")
	var base_shop_tax: int = 100
	var res: Dictionary = WorkshopManager.calculate_market_tax(20, 1, base_shop_tax)

	assert(res["covered_shops"] == 10, "커버된 상점 수가 10이어야 함 (실제: %d)" % res["covered_shops"])
	assert(res["uncovered_shops"] == 10, "커버되지 않은 상점 수가 10이어야 함 (실제: %d)" % res["uncovered_shops"])

	# 기대 세수: (10 * 100 * 1.02) + (10 * 100) = 1020 + 1000 = 2020
	var expected_tax: int = 2020
	assert(res["total_tax"] == expected_tax, "총 세수가 2020이어야 함 (실제: %d)" % res["total_tax"])
	assert(res["buff_amount"] == 20, "추가 세수 버프 금액이 20이어야 함 (실제: %d)" % res["buff_amount"])

	# MarketManager를 통한 정산도 동일한지 확인
	var mm_res: Dictionary = MarketManager.calculate_market_tax(20, 1, base_shop_tax)
	assert(mm_res["total_tax"] == expected_tax, "MarketManager 세수 산출 일치 확인")
	print("[PASS] 상점 20개 / 공방 1개: 10개에만 +2% 세수(총 2020냥) 정확히 적용 완료")

## 2. 상점이 40개일 때 공방이 5개면 40개 상점 전체에 +2% 세수가 정상 적용되는가? (초과분 버프 없음 확인)
func test_criteria_2_full_buff_and_overflow_cap() -> void:
	print("\n--- 검증 2: 전체 버프 적용 및 초과 버프 없음 (상점 40개, 공방 5개) ---")
	var base_shop_tax: int = 100
	# 공방 5개는 최대 50개 상점까지 커버 가능하나 총 상점이 40개이므로 40개 전체만 적용
	var res: Dictionary = WorkshopManager.calculate_market_tax(40, 5, base_shop_tax)

	assert(res["covered_shops"] == 40, "커버된 상점 수가 40이어야 함 (실제: %d)" % res["covered_shops"])
	assert(res["uncovered_shops"] == 0, "커버되지 않은 상점 수가 0이어야 함 (실제: %d)" % res["uncovered_shops"])

	# 기대 세수: 40 * 100 * 1.02 = 4080 (기본 4000 + 버프 80)
	var expected_tax: int = 4080
	assert(res["total_tax"] == expected_tax, "총 세수가 4080이어야 함 (실제: %d)" % res["total_tax"])
	assert(res["buff_amount"] == 80, "추가 세수 버프 금액이 80이어야 함 (초과 버프 없음, 실제: %d)" % res["buff_amount"])
	print("[PASS] 상점 40개 / 공방 5개: 40개 전체에 +2% 세수(총 4080냥) 적용 및 초과 버프 없음 확인 완료")

## 3. 게임 1년 경과 후 공방이 1개도 없으면 도시 국방력이 정확히 -50% 감소하고 경고 알림이 노출되는가?
func test_criteria_3_grace_period_and_penalty() -> void:
	print("\n--- 검증 3: 초기 1년(4턴) 유예 및 공방 부재 시 -50% 페널티 ---")
	var base_def: int = 100

	# 1~4턴 (초기 1년): 공방이 0개여도 유예로 인해 승수 1.00 유지
	for turn in range(1, 5):
		var mult: float = WorkshopManager.get_military_multiplier(0, turn)
		assert(is_equal_approx(mult, 1.0), "초기 %d턴 공방 0개 승수는 1.0이어야 함" % turn)
		var total_def: int = CityStats.calculate_total_defense_power(base_def, 0, turn)
		assert(total_def == 100, "%d턴 방호력은 100 유지되어야 함" % turn)
		assert(not WorkshopManager.is_penalty_active(0, turn), "%d턴은 페널티 비활성화 상태여야 함" % turn)

	# 5턴 (1년 초과, 1790년): 공방 0개 시 승수 0.50 (-50% 페널티 강제 적용)
	var mult_turn5: float = WorkshopManager.get_military_multiplier(0, 5)
	assert(is_equal_approx(mult_turn5, 0.50), "5턴 공방 0개 승수는 0.50이어야 함")
	var penalized_def: int = CityStats.calculate_total_defense_power(base_def, 0, 5)
	assert(penalized_def == 50, "5턴 방호력은 정확히 50 (-50%%)이어야 함 (실제: %d)" % penalized_def)
	assert(WorkshopManager.is_penalty_active(0, 5), "5턴 공방 0개 페널티 활성화 확인")

	var status: Dictionary = WorkshopManager.get_military_status_info(0, 5)
	assert(status["is_penalized"] == true, "페널티 플래그 참 확인")
	assert(status["warning_message"].contains("무기 보급이 마비되었습니다"), "경고 메시지 확인")
	print("[PASS] 초기 1년(4턴) 유예 정상 보장 및 5턴 이후 공방 0개 시 정확히 -50%(100 -> 50) 삭감 확인 완료")

## 4. 공방을 1개 지을 때마다 군사력이 +0.25%씩 증가하며, 20개소 이상 설치 시 정확히 최대 +5.0%로 고정되는가?
func test_criteria_4_linear_military_buff_and_cap() -> void:
	print("\n--- 검증 4: 공방 1개소당 +0.25% 선형 증가 및 20개소 최대 +5.0% 상한 고정 ---")
	var base_def: int = 1000

	# 1개: +0.25% -> 승수 1.0025 -> 1002.5 -> 1003 (반올림)
	var mult_1: float = WorkshopManager.get_military_multiplier(1, 5)
	assert(is_equal_approx(mult_1, 1.0025), "공방 1개 승수 1.0025")
	var def_1: int = CityStats.calculate_total_defense_power(base_def, 1, 5)
	assert(def_1 == 1003, "공방 1개 국방력: 1003")

	# 2개: +0.50% -> 승수 1.0050 -> 1005
	var mult_2: float = WorkshopManager.get_military_multiplier(2, 5)
	assert(is_equal_approx(mult_2, 1.0050), "공방 2개 승수 1.0050")
	var def_2: int = CityStats.calculate_total_defense_power(base_def, 2, 5)
	assert(def_2 == 1005, "공방 2개 국방력: 1005")

	# 10개: +2.50% -> 승수 1.0250 -> 1025
	var mult_10: float = WorkshopManager.get_military_multiplier(10, 5)
	assert(is_equal_approx(mult_10, 1.0250), "공방 10개 승수 1.0250")
	var def_10: int = CityStats.calculate_total_defense_power(base_def, 10, 5)
	assert(def_10 == 1025, "공방 10개 국방력: 1025")

	# 20개: 최대 상한 +5.00% -> 승수 1.0500 -> 1050
	var mult_20: float = WorkshopManager.get_military_multiplier(20, 5)
	assert(is_equal_approx(mult_20, 1.0500), "공방 20개 승수 1.0500")
	var def_20: int = CityStats.calculate_total_defense_power(base_def, 20, 5)
	assert(def_20 == 1050, "공방 20개 국방력: 1050")

	# 30개 (20개 초과): 최대 상한선 유지 (+5.0% 고정) -> 승수 1.0500 -> 1050
	var mult_30: float = WorkshopManager.get_military_multiplier(30, 5)
	assert(is_equal_approx(mult_30, 1.0500), "공방 30개 승수도 1.0500 상한 유지")
	var def_30: int = CityStats.calculate_total_defense_power(base_def, 30, 5)
	assert(def_30 == 1050, "공방 30개 국방력도 1050 상한 유지")
	print("[PASS] 공방 1개당 +0.25% 선형 증가 및 20개소 이상 시 최대 +5.0% 고정 확인 완료")

## 5. 공방을 철거하거나 파괴당했을 때 감소된 수량이 실시간으로 세수와 군사력에 정확히 반영되는가?
func test_criteria_5_realtime_demolish_and_build() -> void:
	print("\n--- 검증 5: 실시간 완공 및 철거(감소) 반영 검증 ---")
	BuildingManager.active_workshop_count = 0
	BuildingManager.active_market_shop_count = 0

	# 1. 상점 15개, 공방 2개 순차 완공
	for i in range(15):
		BuildingManager.update_workshop_and_shop_delta("", "com_1")
	for i in range(2):
		BuildingManager.update_workshop_and_shop_delta("", "ind_1")

	assert(BuildingManager.active_market_shop_count == 15, "상점 수 15개")
	assert(BuildingManager.active_workshop_count == 2, "공방 수 2개")

	# 세수: 공방 2개 -> 상점 15개 전체 커버 (20개 용량 중 15개 사용)
	var tax_res: Dictionary = WorkshopManager.calculate_market_tax(
		BuildingManager.active_market_shop_count,
		BuildingManager.active_workshop_count,
		10
	)
	assert(tax_res["covered_shops"] == 15, "15개 전체 커버")

	# 2. 공방 1개 철거 (ind_1 -> "")
	BuildingManager.update_workshop_and_shop_delta("ind_1", "")
	assert(BuildingManager.active_workshop_count == 1, "철거 후 공방 수 1개로 실시간 감소")

	# 공방 1개로 감소되었으므로 상점 10개만 커버되고 5개는 미커버
	var tax_after_demolish: Dictionary = WorkshopManager.calculate_market_tax(
		BuildingManager.active_market_shop_count,
		BuildingManager.active_workshop_count,
		10
	)
	assert(tax_after_demolish["covered_shops"] == 10, "철거 후 커버 상점 수 10개로 감소")
	assert(tax_after_demolish["uncovered_shops"] == 5, "미커버 상점 수 5개")
	# 세수: (10 * 10 * 1.02) + (5 * 10) = 102 + 50 = 152
	assert(tax_after_demolish["total_tax"] == 152, "철거 후 세수 즉시 152냥으로 감소 반영")

	# 3. 마지막 공방마저 철거 (공방 0개)
	BuildingManager.update_workshop_and_shop_delta("ind_1", "")
	assert(BuildingManager.active_workshop_count == 0, "공방 수 0개")

	# 턴 5에서 군사력 계산 시 페널티(-50%) 즉각 적용
	var def_after_all_demolished: int = CityStats.calculate_total_defense_power(100, BuildingManager.active_workshop_count, 5)
	assert(def_after_all_demolished == 50, "공방 전무 시 방호력 50으로 즉시 반토막")
	print("[PASS] 공방 완공 및 철거 시 실시간 O(1) 갱신 및 세수/군사력 연동 검증 완료")
