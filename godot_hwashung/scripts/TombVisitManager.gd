extends RefCounted
class_name TombVisitManager

## [현륭원(융건릉) 친림 참배 관리 모듈]
## 1. 1회성 소모: 금화 2,000냥, 군량 1,000석 (난이도 배율 DifficultyManager.get_cost_multiplier() 연동)
## 2. 참배 거행 시 효심의 가호 발동, 민심 및 왕권 상승, 현륭원 친림 횟수 카운팅
## 3. 자원 부족 시 참배 안전 차단

static func get_tomb_visit_cost() -> Dictionary:
	return DifficultyManager.get_tomb_visit_cost()

static func can_visit(sim: SimulationCore) -> bool:
	if sim == null:
		return false
	var cost: Dictionary = get_tomb_visit_cost()
	return sim.gold >= int(cost["gold"]) and sim.rice >= int(cost["rice"])

static func execute_tomb_visit(court: CourtSystem, sim: SimulationCore) -> Dictionary:
	if court == null or sim == null:
		return {"success": false, "msg": "조정이 아직 준비되지 않았습니다."}

	if court.hyoryungwon.get("visited", false):
		return {"success": false, "msg": "이미 금년도 현륭원 참배를 마쳤습니다."}

	var cost: Dictionary = get_tomb_visit_cost()
	var cost_gold: int = int(cost["gold"])
	var cost_rice: int = int(cost["rice"])

	if sim.gold < cost_gold or sim.rice < cost_rice:
		return {
			"success": false,
			"msg": "현륭원 참배에 필요한 국고(금 %d냥) 또는 군량(곡 %d석)이 부족합니다." % [cost_gold, cost_rice]
		}

	sim.gold -= cost_gold
	sim.rice -= cost_rice

	court.hyoryungwon["visited"] = true
	court.hyoryungwon["blessing"] = true
	court.hyeonryungwon_visits += 1
	CityStats.add_hyeonryungwon_visit()

	sim.loyalty = mini(100, sim.loyalty + 20)
	sim.authority = mini(100, sim.authority + 15)
	sim.emit_signal("state_updated", sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)

	return {
		"success": true,
		"cost": cost,
		"visits": court.hyeonryungwon_visits,
		"msg": "현륭원 친림 참배를 성대히 거행했습니다. 효심의 가호가 활성화됩니다! (금 -%d냥, 곡 -%d석, 민심 +20, 왕권 +15, 누적 %d회)" % [
			cost_gold, cost_rice, court.hyeonryungwon_visits
		]
	}
