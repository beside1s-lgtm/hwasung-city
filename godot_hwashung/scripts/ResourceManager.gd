extends RefCounted
class_name ResourceManager

## [수원화성 국고 및 자원 관리 모듈]
## SimulationCore와 연동되어 금화(gold) 및 군량(rice) 자원의 증감 및 세입 입고를 일원화 관리

static func add_gold(amount: int, sim: SimulationCore = null) -> int:
	if sim == null:
		return 0
	sim.gold += amount
	sim.emit_signal("state_updated", sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)
	return sim.gold

static func deduct_gold(amount: int, sim: SimulationCore = null) -> bool:
	if sim == null or sim.gold < amount:
		return false
	sim.gold -= amount
	sim.emit_signal("state_updated", sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)
	return true

static func add_rice(amount: int, sim: SimulationCore = null) -> int:
	if sim == null:
		return 0
	sim.rice += amount
	sim.emit_signal("state_updated", sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)
	return sim.rice

static func deduct_rice(amount: int, sim: SimulationCore = null) -> bool:
	if sim == null or sim.rice < amount:
		return false
	sim.rice -= amount
	sim.emit_signal("state_updated", sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)
	return true

static func get_gold(sim: SimulationCore = null) -> int:
	return sim.gold if sim != null else 0

static func get_rice(sim: SimulationCore = null) -> int:
	return sim.rice if sim != null else 0

## [부의 역설] 초과 금화 조회 (100,000 기준)
static func get_excess_gold(sim: SimulationCore = null) -> int:
	return maxi(0, get_gold(sim) - 100000)

## [부의 역설] 초과 곡식 조회 (100,000 기준)
static func get_excess_rice(sim: SimulationCore = null) -> int:
	return maxi(0, get_rice(sim) - 100000)

## [부의 역설] 총 초과 부(Surplus Wealth) 조회 (금화 초과분 + 곡식 초과분)
static func get_total_excess_wealth(sim: SimulationCore = null) -> int:
	return get_excess_gold(sim) + get_excess_rice(sim)

## 초과 부 상세 딕셔너리 반환
static func get_surplus_wealth_info(sim: SimulationCore = null) -> Dictionary:
	var eg: int = get_excess_gold(sim)
	var er: int = get_excess_rice(sim)
	return {
		"excess_gold": eg,
		"excess_rice": er,
		"total_excess": eg + er
	}
