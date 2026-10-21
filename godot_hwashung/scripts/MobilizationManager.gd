extends RefCounted
class_name MobilizationManager

## [민·군 합동 방어 체제 및 전시 총동원 매니저]
## 침략(공성전/반란/도적떼) 발생 시 도시 전체 상인 및 주민을 전시 비상 체제로 일괄 전이.
## 민심·왕권 기반 충성도 체크: 결사항전 단합 vs 일반 민병 vs 배신·내통(성문 개방).
## 부녀자 보급 지원(물동이/주먹밥/화살통) 및 전투 종료 시 원직 복귀(상태 머신 롤백) 보장.

signal mobilization_started(mode: String, buff_multiplier: float)
signal mobilization_ended
signal traitor_event_triggered(gate_pos: Vector2i)

enum LoyaltyBranch {
	UNITED_RESISTANCE, # 민심 >= 70 & 왕권 >= 60 (결사항전, 공방 +30%)
	NORMAL_MILITIA,    # 보통 (일반 의병/보급대)
	TREASON_BETRAYAL   # 민심 < 40 or 왕권 < 30 (동원 거부 30~50%, 성문 개방 배신자)
}

var is_wartime_mobilized: bool = false
var current_branch: LoyaltyBranch = LoyaltyBranch.NORMAL_MILITIA
var combat_buff: float = 1.0
var supply_mitigation_ratio: float = 0.0 # 보급 지원 시 방호력 감소 20% 경감
var betrayed_gate: Vector2i = Vector2i(-1, -1)

# 동원된 NPC들의 원래 상태 보관 (롤백 핸들러용)
# agent_id -> { "original_type": String, "original_state": String, "home_pos": Vector2i }
var _mobilized_backup: Dictionary = {}

## 충성도/왕권 상태 판정
func evaluate_loyalty_branch(loyalty: int, authority: int) -> LoyaltyBranch:
	if loyalty >= 70 and authority >= 60:
		return LoyaltyBranch.UNITED_RESISTANCE
	elif loyalty < 40 or authority < 30:
		return LoyaltyBranch.TREASON_BETRAYAL
	else:
		return LoyaltyBranch.NORMAL_MILITIA

## 전시 총동원 시작 (일괄 상태 전이)
func mobilize(citizens: CitizenManager, grid: GameGrid, sim: SimulationCore, target_gate: Vector2i) -> Dictionary:
	if is_wartime_mobilized:
		return {"success": false, "reason": "already_mobilized"}

	is_wartime_mobilized = true
	_mobilized_backup.clear()
	betrayed_gate = Vector2i(-1, -1)

	var cur_loyalty: int = sim.loyalty if sim else 50
	var cur_authority: int = sim.authority if sim else 50
	current_branch = evaluate_loyalty_branch(cur_loyalty, cur_authority)

	match current_branch:
		LoyaltyBranch.UNITED_RESISTANCE:
			combat_buff = 1.3 # 공격/방어 +30% 버프
			supply_mitigation_ratio = 0.20 # 20% 피해 경감
		LoyaltyBranch.NORMAL_MILITIA:
			combat_buff = 1.0
			supply_mitigation_ratio = 0.20
		LoyaltyBranch.TREASON_BETRAYAL:
			combat_buff = 0.7 # 사기 저하
			supply_mitigation_ratio = 0.0

	var mobilized_militia_count: int = 0
	var mobilized_supply_count: int = 0
	var traitors_count: int = 0

	var target_center: Vector2i = target_gate if grid.in_bounds(target_gate.x, target_gate.y) else Vector2i(int(float(grid.size) / 2.0), int(float(grid.size) / 2.0))

	# 도시 내 상인, 주민 에이전트 선별 및 일괄 전이
	for a: Dictionary in citizens.agents:
		if a.get("is_dead", false) or a.get("siege_unit", false):
			continue

		var atype: String = str(a.get("type", ""))
		# 상인 및 주민 직업군
		var is_merchant: bool = atype in ["shopkeeper", "merchant", "porter", "artisan", "shopper"]
		var is_female_or_elder: bool = atype in ["water_woman", "washerwoman", "granny", "nanny", "palace_lady"]
		var is_commoner: bool = atype in ["idle_walker", "scholar", "traveller", "commoner"]

		if not (is_merchant or is_female_or_elder or is_commoner):
			continue

		var aid: int = int(a.get("id", -1))
		if aid < 0:
			continue

		# 백업 데이터 저장
		_mobilized_backup[aid] = {
			"original_type": atype,
			"original_state": str(a.get("state", "idle")),
			"home_pos": Vector2i(int(a.get("x", 0)), int(a.get("y", 0)))
		}

		# 배신/내통 브랜치인 경우: 40% 확률로 동원 거부 및 일부 배신자 전환
		if current_branch == LoyaltyBranch.TREASON_BETRAYAL:
			var roll: float = randf()
			if roll < 0.40:
				# 동원 거부: 가옥으로 숨음
				a["state"] = "panic_hide"
				a["bubble_text"] = "이런 판국에 누구 좋으라고 싸운단 말인가!"
				a["bubble_timer"] = 3.5
				continue
			elif roll > 0.85 and traitors_count < 2 and target_gate.x >= 0:
				# 성문 내통 배신자!
				traitors_count += 1
				a["type"] = "traitor"
				a["state"] = "open_gate"
				a["speed"] = 1.3
				a["target_gate"] = target_gate
				a["bubble_text"] = "성문을 열어라! 적군에게 길을 터 주어야 우리가 산다!"
				a["bubble_timer"] = 5.0
				betrayed_gate = target_gate
				emit_signal("traitor_event_triggered", target_gate)
				continue

		# 정상 동원 분기
		if is_female_or_elder or (is_commoner and randf() < 0.3):
			# 부녀자 및 노약자 -> 보급 운반대 (SUPPLY_CARRIER)
			mobilized_supply_count += 1
			a["type"] = "supply_carrier"
			a["state"] = "carry_supply"
			a["speed"] = 0.95
			a["supply_kind"] = ["riceball", "water_pot", "arrows", "bandage", "stones"][randi() % 5]
			a["supply_target"] = target_center + Vector2i(randi_range(-2, 2), randi_range(-2, 2))
			a["bubble_text"] = "군사들이여, 주먹밥과 물을 받으시오!" if a["supply_kind"] == "riceball" else "성벽으로 화살과 돌을 나릅시다!"
			a["bubble_timer"] = 4.0
		else:
			# 상인 및 건장한 주민 -> 의병/민병대 (CIVILIAN_COMBAT)
			mobilized_militia_count += 1
			a["type"] = "militia"
			a["state"] = "defend_wall"
			a["speed"] = 1.15
			a["weapon"] = ["bamboo_spear", "flail", "pitchfork", "cudgel"][randi() % 4]
			a["combat_pos"] = target_center + Vector2i(randi_range(-1, 1), randi_range(-1, 1))
			if current_branch == LoyaltyBranch.UNITED_RESISTANCE:
				a["bubble_text"] = "수원화성을 지키자! 한 놈도 살려 보내지 마라!"
			else:
				a["bubble_text"] = "관군과 함께 우리 터전을 지키세!"
			a["bubble_timer"] = 4.0

	emit_signal("mobilization_started", "united" if current_branch == LoyaltyBranch.UNITED_RESISTANCE else ("betrayal" if current_branch == LoyaltyBranch.TREASON_BETRAYAL else "normal"), combat_buff)

	return {
		"success": true,
		"branch": current_branch,
		"militia": mobilized_militia_count,
		"supplies": mobilized_supply_count,
		"traitors": traitors_count,
		"buff": combat_buff
	}

## 전시 해제 및 롤백 핸들러 (전투 종료 시 원직/원위치 복구)
func demobilize(citizens: CitizenManager) -> void:
	if not is_wartime_mobilized:
		return

	is_wartime_mobilized = false

	# 백업 데이터를 기반으로 상태 롤백
	for a: Dictionary in citizens.agents:
		var aid: int = int(a.get("id", -1))
		if _mobilized_backup.has(aid):
			var backup: Dictionary = _mobilized_backup[aid]
			a["type"] = str(backup.get("original_type", "commoner"))
			a["state"] = str(backup.get("original_state", "idle"))
			a["bubble_text"] = "싸움이 끝났으니 다시 일터로 돌아가세."
			a["bubble_timer"] = 3.0
			a.erase("supply_kind")
			a.erase("supply_target")
			a.erase("combat_pos")
			a.erase("weapon")
			a.erase("target_gate")

	_mobilized_backup.clear()
	betrayed_gate = Vector2i(-1, -1)
	emit_signal("mobilization_ended")
