extends RefCounted
class_name DisasterManager

## [도적 침입 및 공방전(Siege Defense) 틱 전투 시뮬레이션 매니저]
## 1. 도적 기본 스탯: 공격력 500, 체력 500 (화성행궁 장용영 5,000명 기본 공격력 500과 호각)
## 2. 도적의 공세: 매 틱마다 성 방호력(내구도/체력)을 먼저 깎아냄.
##    성 방호력이 남아있는 동안에는 민가 약탈, 인명 피해, 행궁 함락이 일절 발생하지 않음 (방호력 0 시 도시 함락 및 약탈)
## 3. 장용영의 반격: 아군 총 공격력(기본 500 + 시설 추가분 + 서장대 야조 훈련분)으로 매 틱 도적 체력을 차감
##    아군 공격력이 높을수록 방호력을 다 깎기 전에 빠르게 전멸하여 무피해 격퇴 성공
## 4. 성능 최적화: 매 프레임 연산 배제, 1.0초 주기 분산 틱 처리

const DEFAULT_BANDIT_ATTACK: int = 500
const DEFAULT_BANDIT_HP: int = 500
const TICK_INTERVAL: float = 1.0

var is_combat_active: bool = false
var bandit_hp: int = 500
var bandit_attack: int = 500
var combat_duration: float = 0.0
var _tick_timer: float = 0.0

## 도적 공방전 개시
func start_siege_combat(init_atk: int = DEFAULT_BANDIT_ATTACK, init_hp: int = DEFAULT_BANDIT_HP) -> void:
	is_combat_active = true
	bandit_hp = init_hp
	bandit_attack = init_atk
	combat_duration = 0.0
	_tick_timer = 0.0

## 공방전 1초 분산 틱 처리 (반환: 전투 상태 Dictionary)
func process_combat_tick(delta: float, sim: SimulationCore = null, grid: GameGrid = null) -> Dictionary:
	if not is_combat_active:
		return {"active": false, "finished": false, "repelled": false}

	combat_duration += delta
	_tick_timer += delta

	# 1.0초 주기가 아니면 스킵 (성능 가드레일 준수)
	if _tick_timer < TICK_INTERVAL:
		return {
			"active": true,
			"finished": false,
			"repelled": false,
			"bandit_hp": bandit_hp,
			"defense_left": CityStats.get_fortress_defense_power()
		}

	_tick_timer = 0.0

	var current_defense: int = CityStats.get_fortress_defense_power()
	var ally_attack: int = CityStats.get_military_attack_power()

	# 1. 도적의 공세: 성 방호력을 먼저 깎아냄
	# 틱당 도적 공격력 (500 기준 틱당 50의 피해를 방호력에 입힘)
	var bandit_tick_damage: int = maxi(10, int(round(float(bandit_attack) * 0.1)))
	var defense_absorbed: bool = false

	if current_defense > 0:
		# 성 방호력이 방어막 역할을 하여 피해를 흡수
		defense_absorbed = true
		CityStats.apply_defense_damage(bandit_tick_damage, sim)
		# 방호력이 남아있는 동안에는 민가 약탈, 인명 피해, 국고 손실 일체 없음
	else:
		# 방호력 0 (도시 함락 및 약탈 발생)
		defense_absorbed = false
		if sim != null:
			sim.gold = maxi(0, sim.gold - 25)
			sim.rice = maxi(0, sim.rice - 15)
			sim.loyalty = maxi(0, sim.loyalty - 2)
			if randf() < 0.3:
				sim.population = maxi(10, sim.population - 1)

	# 2. 장용영의 반격: 아군 총 공격력으로 도적 체력 차감
	# 틱당 아군 피해량 (공격력 500 기준 틱당 100 차감 -> 5초 만에 소탕, 700이면 3.5초 만에 소탕)
	var ally_tick_damage: int = maxi(20, int(round(float(ally_attack) * 0.2)))
	bandit_hp = maxi(0, bandit_hp - ally_tick_damage)

	# 3. 승패 판정
	if bandit_hp <= 0:
		# 도적 전멸 및 격퇴 성공
		is_combat_active = false
		if sim != null:
			sim.bandit_active = false
			sim.bandit_suppression_turns = 24 # 2년(24개월) 평온
		return {
			"active": false,
			"finished": true,
			"repelled": true,
			"defense_absorbed": defense_absorbed,
			"message": "장용영 군병이 결사 항전하여 도적 떼를 완전히 소탕하고 격퇴했습니다!"
		}

	# 방호력이 0이고 오랜 시간(20초 이상) 지체 시 도적 약탈 후 퇴각 (왕권 30 미만 시 도시 함락 엔딩 발화)
	if current_defense <= 0 and combat_duration >= 20.0:
		is_combat_active = false
		var royal_val: int = CityStats.get_royal_power()
		if sim != null:
			sim.bandit_active = false
			royal_val = sim.authority

		if royal_val < 30 and EndingManager.instance != null:
			var ending_key: String = "COUP_DETAT" if royal_val < 20 else "FALLEN_CITY"
			EndingManager.instance.trigger_fall_of_city_ending(ending_key)
			return {
				"active": false,
				"finished": true,
				"repelled": false,
				"defense_absorbed": false,
				"message": "[도시 함락] 왕권 실추로 인해 화적 떼가 화성행궁을 점거하여 도시가 함락되었습니다."
			}

		return {
			"active": false,
			"finished": true,
			"repelled": false,
			"defense_absorbed": false,
			"message": "성 방호력이 무너져 도적 떼가 읍내를 약탈하고 도주했습니다."
		}

	return {
		"active": true,
		"finished": false,
		"repelled": false,
		"bandit_hp": bandit_hp,
		"defense_left": CityStats.get_fortress_defense_power(),
		"defense_absorbed": defense_absorbed
	}

## 단일 틱 시뮬레이션 정적 헬퍼 (테스트 및 인스턴스리스 호출용)
static func simulate_combat_round(current_defense: int, ally_attack: int, current_bandit_hp: int, bandit_attack: int = 500) -> Dictionary:
	var bandit_dmg: int = maxi(10, int(round(float(bandit_attack) * 0.1)))
	var new_def: int = maxi(0, current_defense - bandit_dmg)
	var absorbed: bool = current_defense > 0

	var ally_dmg: int = maxi(20, int(round(float(ally_attack) * 0.2)))
	var new_hp: int = maxi(0, current_bandit_hp - ally_dmg)

	return {
		"new_defense": new_def,
		"new_bandit_hp": new_hp,
		"absorbed": absorbed,
		"bandit_defeated": new_hp <= 0
	}
