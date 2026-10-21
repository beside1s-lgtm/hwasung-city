extends RefCounted
class_name RebellionManager

## [왕권 실추 연동 반란군 공성 및 전투력 관리자]
## 반란군 기본 최소 공격력 500 엄격 보장 및 스케일링 공식:
## 반란군 전투력 = 500 + max(0, 50 - 왕권) * 10 + 난이도 보정치

const DEFAULT_REBEL_SIEGE_HP: int = 500
const DEFAULT_REBEL_SIEGE_ATK: int = 500
const INITIAL_REBEL_SIEGE_ATK: int = 500

## 반란군 공격력 산출 공식
static func calculate_rebel_siege_atk(sim: Variant) -> int:
	var royal_val: int = CityStats.get_royal_power()
	if sim != null and ("authority" in sim):
		royal_val = int(sim.authority)

	var royal_deficit: int = maxi(0, 50 - royal_val)
	var diff_bonus: int = 0
	match DifficultyManager.get_difficulty():
		DifficultyManager.Difficulty.NORMAL:
			diff_bonus = 50
		DifficultyManager.Difficulty.HARD:
			diff_bonus = 100
		_:
			diff_bonus = 0

	var atk: int = INITIAL_REBEL_SIEGE_ATK + (royal_deficit * 10) + diff_bonus
	return maxi(500, atk)

## 반란군 체력 산출 (공격력 및 왕권 실추 비례)
static func calculate_rebel_siege_hp(sim: Variant) -> int:
	var royal_val: int = CityStats.get_royal_power()
	if sim != null and ("authority" in sim):
		royal_val = int(sim.authority)
	var hp_bonus: int = maxi(0, 50 - royal_val) * 6
	return maxi(500, DEFAULT_REBEL_SIEGE_HP + hp_bonus)

## 반란군 엔티티에 특수 개체 상시 표시 플래그 부여
static func mark_rebel_special(target: Variant) -> void:
	SpecialEntityManager.mark_special(target)
	if target is Dictionary:
		target["is_rebel"] = true

## 음모 묵인 3회 누적 시 실제 반란군 출병 트리거
static func spawn_rebel_invasion(leader_name: String, sim: Variant = null) -> void:
	if sim == null or not ("bandit_manager" in sim):
		return
	var b_mgr = sim.bandit_manager
	if b_mgr != null and b_mgr.has_method("start_raid"):
		b_mgr.start_raid(sim, sim.grid_ref, sim.citizens_ref if ("citizens_ref" in sim) else null, "assault_palace")
	sim.emit_signal("disaster_alert", "🚨 [%s]의 사병 무리가 끝내 반란을 일으켜 화성행궁 본궁으로 돌격하고 있습니다!" % leader_name)

