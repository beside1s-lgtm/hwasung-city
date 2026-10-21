extends RefCounted
class_name TaxManager

## [호조 탕평 조세, 인구 규모별 조세 저항선 및 등급별 차등 과세 매니저]
## Single Source of Truth: 조세율 집계, 조세 저항선 평가, 2년차 이후 등급별 차등 세수 산출

## 1. 3대 조세 총합 산출 (토지세 + 시전세 + 군포세)
static func get_total_tax_rate(sim: SimulationCore) -> float:
	if sim == null:
		return 21.0
	return float(sim.tax_rate_land + sim.tax_rate_market + sim.tax_rate_military)

## 2. 인구 규모별 조세 저항선 임계치 (%)
## 10만 이상 ~ 20만 미만: > 15%
## 20만 이상 ~ 30만 미만: > 12%
## 30만 이상 ~ 40만 미만: > 10%
## 40만 이상 ~ 50만 미만: > 8%
## 50만 이상 ~ 60만 미만: > 6%
## 60만 이상 ~ 70만 미만: > 4%
## 70만 이상: > 3%
## 10만 미만: 임계치 없음 (100.0%)
static func get_tax_threshold_for_population(pop: int) -> float:
	if pop >= 700000:
		return 3.0
	elif pop >= 600000:
		return 4.0
	elif pop >= 500000:
		return 6.0
	elif pop >= 400000:
		return 8.0
	elif pop >= 300000:
		return 10.0
	elif pop >= 200000:
		return 12.0
	elif pop >= 100000:
		return 15.0
	else:
		return 100.0

## 3. 조세 저항 발생 여부 판정
static func is_tax_resistance_active(pop: int, total_tax: float) -> bool:
	if pop < 100000:
		return false
	var threshold: float = get_tax_threshold_for_population(pop)
	return total_tax > threshold

## 4. 조세 저항선 초과 시 인구 유출(감소) 비율 산출
## 초과 시 감소율: (현재 조세 총합 - 임계치) * 0.5% (0.005)
static func get_tax_resistance_penalty_rate(pop: int, total_tax: float) -> float:
	if not is_tax_resistance_active(pop, total_tax):
		return 0.0
	var threshold: float = get_tax_threshold_for_population(pop)
	var excess: float = total_tax - threshold
	return excess * 0.005

## 5. 게임 2년차(1791년 이상 또는 8턴 경과) 이후 등급별 차등 과세 활성 여부
## 인게임 기준 초기 2년(8턴) 동안은 튜토리얼 기본 세수를 유지하고 이후 활성화
static func is_differentiated_tax_active(sim: SimulationCore) -> bool:
	if sim == null:
		return false
	return (sim.current_year >= 1791) or (sim.turn > 8)

## 6. 등급별 차등 세수 계산 공식
## 민가 세금 비례 (초가 B_house 기준):
## - 초가집(res_1): 1 * B_house
## - 일반 기와집(res_2): 2 * B_house
## - 대부호의 집(res_3): 10 * B_house
## 상점 세금 비례 (일반 상점 B_shop 기준):
## - 일반 상점(com_1, ind_1): 1 * B_shop
## - 고급 상점(com_2, ind_2): 2 * B_shop
## - 공방 공급 버프: 공방 1개소당 상점 10개소까지 세수 +2% (1.02배) 가산
static func calculate_differentiated_taxes(tier_counts: Dictionary, base_house_tax: int, base_shop_tax: int, is_diff_active: bool, workshop_count: int = -1) -> Dictionary:
	var thatched_cnt: int = int(tier_counts.get("thatched_count", 0))
	var tile_cnt: int = int(tier_counts.get("tile_count", 0))
	var mansion_cnt: int = int(tier_counts.get("mansion_count", 0))
	var basic_shop_cnt: int = int(tier_counts.get("basic_shop_count", 0))
	var luxury_shop_cnt: int = int(tier_counts.get("luxury_shop_count", 0))

	var house_tax_total: int = 0
	var shop_tax_total: int = 0

	var total_houses: int = thatched_cnt + tile_cnt + mansion_cnt
	var total_shops: int = basic_shop_cnt + luxury_shop_cnt
	var ws_cnt: int = workshop_count if workshop_count >= 0 else BuildingManager.active_workshop_count
	var covered_shops: int = mini(total_shops, ws_cnt * 10)
	var uncovered_shops: int = maxi(0, total_shops - covered_shops)
	var extra_buff_tax: int = 0

	if not is_diff_active:
		# 시작 2년(8턴) 보호 기간: 모든 가옥/상점 기본 세수 균일 징수 + 공방 버프
		house_tax_total = total_houses * base_house_tax
		var covered_tax: float = float(covered_shops) * float(base_shop_tax) * 1.02
		var uncovered_tax: float = float(uncovered_shops) * float(base_shop_tax)
		shop_tax_total = int(round(covered_tax + uncovered_tax))
		extra_buff_tax = maxi(0, shop_tax_total - (total_shops * base_shop_tax))
	else:
		# 2년차 이후 등급별 차등 과세 적용
		var thatched_tax: int = thatched_cnt * base_house_tax
		var tile_tax: int = tile_cnt * (base_house_tax * 2)
		var mansion_tax: int = mansion_cnt * (base_house_tax * 10)
		house_tax_total = thatched_tax + tile_tax + mansion_tax

		var basic_tax: int = basic_shop_cnt * base_shop_tax
		var luxury_tax: int = luxury_shop_cnt * (base_shop_tax * 2)
		var base_shop_total: int = basic_tax + luxury_tax

		if total_shops > 0 and covered_shops > 0:
			var avg_tax_per_shop: float = float(base_shop_total) / float(total_shops)
			extra_buff_tax = int(round(float(covered_shops) * avg_tax_per_shop * 0.02))
		shop_tax_total = base_shop_total + extra_buff_tax

	return {
		"house_tax": house_tax_total,
		"shop_tax": shop_tax_total,
		"total_tax": house_tax_total + shop_tax_total,
		"is_differentiated": is_diff_active,
		"covered_shops": covered_shops,
		"workshop_count": ws_cnt,
		"shop_buff_amount": extra_buff_tax
	}

