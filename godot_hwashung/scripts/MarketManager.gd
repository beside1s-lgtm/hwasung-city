extends RefCounted
class_name MarketManager

## [시장 인구부양력 동역학 엔진 및 조세 21% 균형점 시뮬레이터]
## Single Source of Truth: 인구 대비 시장 부양력 지표(market_support_capacity / carrying_ratio) 관리

## 계수 정의
const TAX_EQUILIBRIUM: float = 21.0       # 3대 조세 균형점 (%)
const CAPACITY_DECAY_FACTOR: float = 0.005 # 21% 초과 시 부양력 감소 계수
const CAPACITY_GROWTH_FACTOR: float = 0.005# 21% 미만 시 부양력 증가 계수

## 인구부양력 상태 변수 (기본 1.0 = 100%)
static var current_carrying_ratio: float = 1.0

## 치안 실패 페널티 상태 변수 (1턴간 저잣거리 세수 감소 및 상업 마비)
static var dispute_penalty_turns: int = 0
static var dispute_penalty_rate: float = 0.10
static var is_market_paralyzed: bool = false

## 치안 실패 페널티 발동 (다음 1턴간 상업 세수 감액 또는 마비)
static func apply_dispute_penalty(rate: float = 0.10, paralyzed: bool = false) -> void:
	dispute_penalty_turns = 1
	dispute_penalty_rate = clampf(rate, 0.0, 1.0)
	is_market_paralyzed = paralyzed

## 치안 실패 상업 세수 감액 배율 반환 (마비 시 0.0, 감액 시 1.0 - rate, 평시 1.0)
static func get_dispute_tax_multiplier() -> float:
	if dispute_penalty_turns <= 0:
		return 1.0
	if is_market_paralyzed:
		return 0.0
	return clampf(1.0 - dispute_penalty_rate, 0.0, 1.0)

## 1. 현재 인구부양력 비율 반환
static func get_carrying_ratio() -> float:
	return current_carrying_ratio

## 2. 인구부양력 비율 직접 설정 (로드/테스트용)
static func set_carrying_ratio(val: float) -> void:
	current_carrying_ratio = clampf(val, 0.1, 3.0)

## 3. 조세 총합에 따른 인구부양력 델타 및 갱신 계산
## - 조세 총합 == 21%: 델타 0 (정체 상태 유지)
## - 조세 총합 > 21%: 감소폭 (조세 합 - 21) * 0.005
## - 조세 총합 < 21%: 증가폭 (21 - 조세 합) * 0.005
static func update_carrying_ratio(total_tax: float) -> float:
	var delta: float = 0.0
	if is_equal_approx(total_tax, TAX_EQUILIBRIUM):
		delta = 0.0
	elif total_tax > TAX_EQUILIBRIUM:
		var excess: float = total_tax - TAX_EQUILIBRIUM
		delta = -excess * CAPACITY_DECAY_FACTOR
	else:
		var deficit: float = TAX_EQUILIBRIUM - total_tax
		delta = deficit * CAPACITY_GROWTH_FACTOR

	current_carrying_ratio = clampf(current_carrying_ratio + delta, 0.1, 3.0)
	return current_carrying_ratio

## 4. 시장의 총 인구부양력 계산 (Zero-Divide 및 0값 방어)
## 공식: (시장 수 * 상점당 기본 부양 인구 150명) * carrying_ratio
static func calculate_market_support_capacity(shop_count: int, carrying_ratio: float = -1.0) -> int:
	if shop_count <= 0:
		return 0
	var ratio: float = current_carrying_ratio if carrying_ratio < 0.0 else carrying_ratio
	var base_support_per_shop: float = 150.0
	var total_capacity: float = float(shop_count) * base_support_per_shop * ratio
	return maxi(0, int(round(total_capacity)))

## 5. 인구 대비 상업 비율 (Commercial Ratio) 산출 (Zero-Divide 방어)
## 공식: (상점 수 * 1000) / 인구
static func get_commercial_density(shop_count: int, population: int) -> float:
	if population <= 0:
		return 0.0
	if shop_count <= 0:
		return 0.0
	return (float(shop_count) / float(population)) * 1000.0

## 6. 시장 턴 동역학 갱신 (SimulationCore.process_turn_economy 연동)
static func process_turn_market(sim: SimulationCore, grid: GameGrid) -> Dictionary:
	var total_tax: float = TaxManager.get_total_tax_rate(sim)
	var prev_ratio: float = current_carrying_ratio
	var new_ratio: float = update_carrying_ratio(total_tax)

	var shops_cnt: int = 0
	if grid != null:
		shops_cnt = int(grid.shops_count)
	elif sim != null and "shops_count" in sim:
		shops_cnt = int(sim.get("shops_count"))

	var pop: int = sim.population if sim != null else 0
	var support_capacity: int = calculate_market_support_capacity(shops_cnt, new_ratio)
	var density: float = get_commercial_density(shops_cnt, pop)

	var penalty_mult: float = get_dispute_tax_multiplier()
	var raw_shop_tax: int = maxi(1, int(round(10.0 * (float(sim.tax_rate_market if sim != null else 7) / 7.0))))
	var effective_shop_tax: int = 0 if penalty_mult <= 0.0 else maxi(1, int(round(float(raw_shop_tax) * penalty_mult)))

	var ws_cnt: int = BuildingManager.active_workshop_count
	var market_tax_info: Dictionary = calculate_market_tax(shops_cnt, ws_cnt, effective_shop_tax)

	# 페널티 턴 감쇄 (1턴 적용 후 정상 복귀)
	var was_penalty_active: bool = dispute_penalty_turns > 0
	if dispute_penalty_turns > 0:
		dispute_penalty_turns -= 1
		if dispute_penalty_turns <= 0:
			is_market_paralyzed = false

	return {
		"total_tax": total_tax,
		"prev_ratio": prev_ratio,
		"carrying_ratio": new_ratio,
		"shop_count": shops_cnt,
		"support_capacity": support_capacity,
		"commercial_density": density,
		"workshop_count": ws_cnt,
		"market_tax_info": market_tax_info,
		"dispute_penalty_applied": was_penalty_active,
		"tax_multiplier": penalty_mult
	}

## 7. 저잣거리 상점 세수 버프 정산 (공방 1개소당 상점 10개소까지 +2% 세수 버프)
## 공식: (covered_shops * base_shop_tax * 1.02) + (uncovered_shops * base_shop_tax)
static func calculate_market_tax(total_shops: int, total_workshops: int, base_shop_tax: int) -> Dictionary:
	return WorkshopManager.calculate_market_tax(total_shops, total_workshops, base_shop_tax)

## 8. 저잣거리 살피기 및 조세 창용 UI 텍스트
static func get_market_buff_tooltip_text(covered_shops: int, total_shops: int) -> String:
	return WorkshopManager.get_market_buff_tooltip_text(covered_shops, total_shops)
