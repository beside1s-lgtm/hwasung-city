extends RefCounted
class_name FarmManager

## [대유둔전 식량 생산 및 관개 수혜 정산 엔진]
## 1. 수리 농업 인프라 엔진(IrrigationManager)과 결합하여 둔전 타일별 소출 산출
## 2. 게임 시작 초기 1년(4턴) 유예 기간 동안 가뭄/용수 부족 페널티(-10%) 유예
## 3. 만석거 특화 버프(+10%), 일반 관개(정상 100%), 용수 부족(-10%) 반영

## 게임 시작 초기 유예 기간 판정 (초기 1년/4턴 이하)
static func is_grace_period(sim: SimulationCore) -> bool:
	if sim == null:
		return true
	return int(sim.turn) <= 4

## 타일 수리 상태에 따른 관개 배율 산출
static func get_irrigation_multiplier(tile: Dictionary, is_grace: bool = false) -> float:
	return IrrigationManager.get_yield_multiplier(tile, is_grace)

## 개별 둔전 타일 최종 소출 계산 (기본 소출 × 관개 배율)
static func calculate_tile_yield(tile: Dictionary, base_yield: float, is_grace: bool = false) -> int:
	var mult: float = get_irrigation_multiplier(tile, is_grace)
	return int(round(base_yield * mult))

## 분기별 둔전 수확 정산 및 물류 세입 산출 위임 래퍼
static func calculate_harvest(grid: GameGrid, sim: SimulationCore, season_index: int) -> Dictionary:
	if grid == null or sim == null:
		return {
			"gross_yield": 0,
			"net_income": 0,
			"logistics_ratio": 1.0,
			"logistics_eff": 1.0,
			"gates_connected": 0,
			"total_farms": 0
		}

	# 턴 정산 전 최신 관개 현황 동기화
	IrrigationManager.recalculate_irrigation(grid, sim)

	var is_grace: bool = is_grace_period(sim)
	var base_yield: int = 0
	var farm_count: int = 0
	var agr1_count: int = 0
	var agr2_count: int = 0
	var canal_count: int = 0
	var levee_count: int = 0
	var farm_limit: int = DifficultyManager.get_farm_capacity_limit(grid.houses_count)
	var cultivated_farms: int = 0

	for y_pos: int in range(grid.size):
		for x_pos: int in range(grid.size):
			var t_cell: Dictionary = grid.grid[y_pos][x_pos]
			var b_str: String = str(t_cell.get("building", ""))
			var z_str: String = str(t_cell.get("zone", ""))
			
			if bool(t_cell.get("is_ruined", false)) or bool(t_cell.get("is_looted", false)):
				continue
			
			if b_str == "agr_1":
				if not grid.is_road_connected(x_pos, y_pos):
					continue
				farm_count += 1
				agr1_count += 1
				if cultivated_farms < farm_limit:
					cultivated_farms += 1
					var irr_flag: bool = bool(t_cell.get("irrigated", false))
					var raw_val: float = 45.0 * (1.55 if irr_flag else 1.0)
					base_yield += calculate_tile_yield(t_cell, raw_val, is_grace)
			elif b_str == "agr_2":
				if not grid.is_road_connected(x_pos, y_pos):
					continue
				farm_count += 1
				agr2_count += 1
				if cultivated_farms < farm_limit:
					cultivated_farms += 1
					var irr_flag: bool = bool(t_cell.get("irrigated", false))
					var raw_val: float = 150.0 * (1.60 if irr_flag else 1.0)
					base_yield += calculate_tile_yield(t_cell, raw_val, is_grace)
			elif z_str == "agr" and b_str == "":
				if not grid.is_road_connected(x_pos, y_pos):
					continue
				farm_count += 1
				if cultivated_farms < farm_limit:
					cultivated_farms += 1
					base_yield += calculate_tile_yield(t_cell, 25.0, is_grace)
			elif b_str == "canal":
				canal_count += 1
			elif b_str == "levee":
				levee_count += 1

	# 백성 자급 텃밭 소출
	base_yield += int(float(sim.population) * 0.4)

	# 2. 공공시설물 및 농학자 보너스
	var has_manseokgeo: bool = grid.count_completed("manseokgeo") > 0 or grid.reservoir_count >= 6
	var res_count: int = grid.count_completed("reservoir")
	var seo_yugu: bool = bool(sim.retainers.get("seo_yugu", false))

	var irr_mult: float = 1.0
	var irr_add: int = 0
	if has_manseokgeo:
		irr_mult += 0.65
		irr_add += 180
	irr_mult += float(res_count) * 0.20
	irr_add += res_count * 40

	var levee_bonus: float = minf(float(levee_count) / 5.0 * 0.05, 0.35)
	irr_mult += levee_bonus
	var canal_bonus: float = minf(float(canal_count) / 5.0 * 0.05, 0.40)
	irr_mult += canal_bonus

	if grid.count_completed("yongyeon") > 0:
		irr_mult += 0.15
	if grid.has_method("has_yeonghwajeong_near_manseok") and grid.has_yeonghwajeong_near_manseok():
		irr_mult += 0.25
		irr_add += 60
	if seo_yugu:
		irr_mult += 0.40
		irr_add += 90

	# 3. 노동력 및 민심 비례
	var labor_mult: float = clampf(0.5 + (float(sim.population) / 120.0) * 0.7, 0.5, 2.2)
	var loyalty_mult: float = clampf(0.4 + (float(sim.loyalty) / 70.0) * 0.6, 0.4, 1.4)

	# 4. 계절 주기
	var season_multipliers: Array[float] = [0.35, 0.75, 2.5, 0.15]
	var season_mult: float = season_multipliers[clampi(season_index, 0, 3)]

	var gross_yield: int = int(round((float(base_yield) * irr_mult + float(irr_add)) * labor_mult * loyalty_mult * season_mult))
	if sim.drought_active or sim.flood_crisis_active:
		var d_pen: float = DifficultyManager.get_disaster_penalty("drought")
		gross_yield = int(float(gross_yield) * (1.0 - d_pen))
	gross_yield = maxi(gross_yield, 10)

	# 5. 성문 및 물류 효율
	var logistics: Dictionary = grid.check_dunjian_logistics()
	var ratio: float = float(logistics.get("ratio", 1.0))
	var gates_connected: int = int(logistics.get("gates", 0))
	var total_farms: int = int(logistics.get("total", farm_count))

	var logistics_eff: float = 1.0
	if total_farms > 0:
		logistics_eff = 0.35 + (0.65 * ratio)
		if gates_connected == 0:
			logistics_eff = minf(logistics_eff, 0.45)
		elif ratio >= 0.90 and gates_connected >= 1:
			var tech_ratio: float = float(agr2_count) / maxf(1.0, float(farm_count))
			logistics_eff = 1.25 + (tech_ratio * 0.40)

	var tax_factor: float = clampf(float(sim.tax_rate_land) / 7.0, 0.5, 2.0)
	var intake_rate: float = 0.35 * tax_factor
	if season_index == 2:
		intake_rate = maxf(intake_rate, 0.42 * tax_factor)

	var net_income: int = int(round(float(gross_yield) * intake_rate * logistics_eff))
	net_income = maxi(net_income, 5)

	if sim.flood_crisis_active:
		gross_yield = int(float(gross_yield) * 0.5)
		net_income = maxi(int(float(net_income) * 0.5), 2)

	return {
		"gross_yield": gross_yield,
		"net_income": net_income,
		"logistics_ratio": ratio,
		"logistics_eff": logistics_eff,
		"gates_connected": gates_connected,
		"total_farms": total_farms,
		"agr1_count": agr1_count,
		"agr2_count": agr2_count,
		"irrigation_multiplier": irr_mult,
		"season_multiplier": season_mult
	}
