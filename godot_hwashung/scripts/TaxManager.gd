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

## 2-1. 인구 상한 (사용자 결정: "맵이 제한되어 집·저잣거리·둔전·공방을 더 못 지으니 인구에도 상한을")
## 인구 상한 = min(세율 상한, 생산력 상한). 세율 상한은 위 조세 저항선을 그대로 거꾸로 읽은 것 + 최저 세율(합 3%)일 때 100만.
##   합 3% → 100만 · 4% → 70만 · 5~6% → 60만 · 7~8% → 50만 · 9~10% → 40만 · 11~12% → 30만 · 13~15% → 20만 · 그 위 → 10만
const POP_CAP_MAX := 1000000
static func get_population_cap_for_tax(total_tax: float) -> int:
	if total_tax <= 3.0:
		return POP_CAP_MAX
	elif total_tax <= 4.0:
		return 700000
	elif total_tax <= 6.0:
		return 600000
	elif total_tax <= 8.0:
		return 500000
	elif total_tax <= 10.0:
		return 400000
	elif total_tax <= 12.0:
		return 300000
	elif total_tax <= 15.0:
		return 200000
	return 100000

## 생산력 상한: 백성이 살 집과 먹고살 일자리·식량이 있어야 머문다. 다 지은 도시(민가 약 780·상점 약 390·공방 약 200·둔전 약 390칸)가 약 92만.
const POP_PER_HOUSE := 600
const POP_PER_SHOP := 600
const POP_PER_WORKSHOP := 500
const POP_PER_FARM := 300
## PORT-TRACE [근대 인구 부양]: 사용자 요청 — "근대 기술과 다층건물이 생기면 같은 면적에서 더 많은 인구를 부양하도록".
## 근대화 시대에 개편된 칸은 같은 땅에서 더 많이 먹여 살린다: 석조 1.25배, 2단계(택지 빌라·상업 빌딩·금융 구역·공장) 2배.
## 세율 상한(최대 100만)도 도시 전체 평균 배율만큼 함께 오른다.
const MODERN_STONE_MULT := 1.25
const MODERN_METRO_MULT := 2.0
## {"base": 전통 기준 상한, "modern": 근대 개편 반영 상한}
static func get_production_population_caps(grid) -> Dictionary:
	if grid == null or not ("grid" in grid):
		return {"base": POP_CAP_MAX, "modern": POP_CAP_MAX}
	var uem: UrbanEvolutionManager = UrbanEvolutionManager.instance if UrbanEvolutionManager.is_active() else null
	var base := 0
	var modern := 0.0
	for y: int in range(grid.grid.size()):
		var row: Array = grid.grid[y]
		for x: int in range(row.size()):
			var b: String = str(row[x].get("building", ""))
			var n := 0
			if b.begins_with("res"):
				n = POP_PER_HOUSE
			elif b.begins_with("com"):
				n = POP_PER_SHOP
			elif b.begins_with("ind"):
				n = POP_PER_WORKSHOP
			elif b.begins_with("agr"):
				n = POP_PER_FARM
			if n == 0:
				continue
			base += n
			var m := 1.0
			if uem != null:
				match uem.building_stage(x, y):
					UrbanEvolutionManager.STAGE_METRO: m = MODERN_METRO_MULT
					UrbanEvolutionManager.STAGE_STONE: m = MODERN_STONE_MULT
			modern += float(n) * m
	return {"base": base, "modern": int(modern)}

static func get_production_population_cap(grid) -> int:
	return int(get_production_population_caps(grid)["modern"])

## 인구 상한(세율·생산력 중 작은 쪽)과 각각의 값. modern_mult = 근대 개편으로 늘어난 도시 평균 배율(1 = 전통 그대로)
static func get_population_cap(total_tax: float, grid) -> Dictionary:
	var caps := get_production_population_caps(grid)
	var base: int = int(caps["base"])
	var mult := float(caps["modern"]) / float(base) if base > 0 else 1.0
	# 근대 의학 4분야(예방접종·미생물학·해부학·공중위생학) 하나마다 +10%
	var med := ModernizationManager.medical_pop_mult()
	mult *= med
	var tax_cap := int(float(get_population_cap_for_tax(total_tax)) * maxf(1.0, mult))
	# 게임 초반(건물이 적을 때 행궁 완공 유입 등)을 막지 않도록 최소 1만
	var prod_cap := maxi(10000, int(float(caps["modern"]) * med))
	return {"cap": mini(tax_cap, prod_cap), "tax_cap": tax_cap, "prod_cap": prod_cap, "modern_mult": mult}

## PORT-TRACE [세입 가산]: 사용자 요청 — "특정 조건에서만 생기는 우시장(쇠전)에 세입 +1%", "사대문 교역로가 이어지면 세입 증가".
## 세입(달마다 상업세·전세, 가옥·상점 차등 과세, 계절 세수)에 곱하는 배율.
##   수원 쇠전(팔달문 저잣거리 3x3) +1% · 성 밖 교역로가 개통된 성문 하나마다 +2% · 사대문이 모두 이어지면 +2% 더 → 최대 +11%
const CATTLE_MARKET_REVENUE := 0.01
const GATE_ROUTE_REVENUE := 0.02
const ALL_GATES_REVENUE := 0.02
static func revenue_bonus(grid) -> Dictionary:
	var out := {"cattle": 0.0, "gates": 0.0, "mult": 1.0}
	if grid == null or not ("grid" in grid):
		return out
	if not grid.list_plazas("cattle").is_empty():
		out["cattle"] = CATTLE_MARKET_REVENUE
	if grid.logistics != null:
		var n: int = grid.logistics.connected_kinds().size()
		out["gates"] = GATE_ROUTE_REVENUE * n + (ALL_GATES_REVENUE if n == 4 else 0.0)
	out["mult"] = 1.0 + float(out["cattle"]) + float(out["gates"])
	return out

static func revenue_mult(grid) -> float:
	return float(revenue_bonus(grid)["mult"])

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

