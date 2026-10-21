extends RefCounted
class_name DifficultyManager

## [화성성역 난이도 관리 시스템]
## 쉬움(태평성대), 보통(성역의 고난), 어려움(위기의 조선) 난이도별 경제, 인구, 건설, 재해 밸런스 중앙 관리자

enum Difficulty {
	EASY = 0,   ## 태평성대 (기존 밸런스 보존, 배율 1.0)
	NORMAL = 1, ## 성역의 고난 (역사적 고증 밸런스, 배율 2.0)
	HARD = 2    ## 위기의 조선 (가혹한 시련, 배율 3.0)
}

const DIFFICULTY_NAMES: Dictionary = {
	Difficulty.EASY: "쉬움 (태평성대)",
	Difficulty.NORMAL: "보통 (성역의 고난)",
	Difficulty.HARD: "어려움 (위기의 조선)"
}

const DIFFICULTY_DESCS: Dictionary = {
	Difficulty.EASY: "기존 화성 축성의 재미를 편안하게 즐기는 입문용 난이도. 자원이 풍족하고 지출 배율 1.0x가 적용됩니다.",
	Difficulty.NORMAL: "조선 후기 실제 경제 상황에 맞춘 역사적 난이도. 모든 건설·보수·유지비에 2.0x 배율이 적용됩니다.",
	Difficulty.HARD: "모든 건설·보수·관청유지·세자교육·훈련·참배 비용에 3.0x 배율이 적용되는 가혹한 시련입니다."
}

## 전역 현재 난이도 (기본값: EASY로 역호환성 100% 보장)
static var current_difficulty: Difficulty = Difficulty.EASY

@warning_ignore("unused_signal")
signal difficulty_changed(new_diff: Difficulty)

static func set_difficulty(diff: int) -> void:
	var target: Difficulty = Difficulty.EASY
	match diff:
		1: target = Difficulty.NORMAL
		2: target = Difficulty.HARD
		_: target = Difficulty.EASY
	current_difficulty = target
	print("[DifficultyManager] 게임 난이도 설정됨: %s" % DIFFICULTY_NAMES.get(target, "쉬움"))

static func get_difficulty() -> Difficulty:
	return current_difficulty

static func get_difficulty_name() -> String:
	return DIFFICULTY_NAMES.get(current_difficulty, "쉬움 (태평성대)")

static func get_difficulty_desc() -> String:
	return DIFFICULTY_DESCS.get(current_difficulty, "")

## [단일 난이도 계수기 (Difficulty Multiplier)] SSOT
## 모든 건설비, 보수비, 관청 유지비, 세자 교육비, 훈련/참배 비용에 적용
## 쉬움: x1.0, 보통: x2.0, 어려움: x3.0
static func get_cost_multiplier() -> float:
	match current_difficulty:
		Difficulty.EASY:
			return 1.0
		Difficulty.NORMAL:
			return 2.0
		Difficulty.HARD:
			return 3.0
		_:
			return 1.0

## [공공시설 턴당 운영자금 배율 (Facility Maintenance Multiplier)]
## 쉬움: x1.0, 보통: x1.2 (+20%), 어려움: x1.3 (+30%)
static func get_facility_maintenance_multiplier() -> float:
	match current_difficulty:
		Difficulty.EASY:
			return 1.0
		Difficulty.NORMAL:
			return 1.20
		Difficulty.HARD:
			return 1.30
		_:
			return 1.0

# -------------------------------------------------------------------------
# 성곽 / 성문 / 관공서 / 세자 교육 / 군사훈련 / 참배 기본 비용 및 배율 정산
# -------------------------------------------------------------------------

## 성곽 신규 건설비 (쉬움 기준: 금 1,000냥, 곡 500석)
static func get_wall_build_cost() -> Dictionary:
	var mult: float = get_cost_multiplier()
	return {
		"gold": int(round(1000.0 * mult)),
		"rice": int(round(500.0 * mult))
	}

## 성곽 파손 보수비 (쉬움 기준: 금 500냥, 곡 250석)
static func get_wall_repair_cost() -> Dictionary:
	var mult: float = get_cost_multiplier()
	return {
		"gold": int(round(500.0 * mult)),
		"rice": int(round(250.0 * mult))
	}

## 성문 건립비 (사대문/암문/수문 1개소, 쉬움 기준: 금 2,000냥, 곡 1,500석)
static func get_gate_build_cost() -> Dictionary:
	var mult: float = get_cost_multiplier()
	return {
		"gold": int(round(2000.0 * mult)),
		"rice": int(round(1500.0 * mult))
	}

## 관공서 턴당 점유 셀 1칸당 유지비 (쉬움 기준: 매 턴 금 200냥)
static func get_gov_maintenance_cost_per_cell() -> int:
	var mult: float = get_cost_multiplier()
	return int(round(200.0 * mult))

## 세자 교육 턴당 소모비 (쉬움 기준: 매 턴 금 2,000냥)
static func get_prince_education_turn_cost() -> int:
	var mult: float = get_cost_multiplier()
	return int(round(2000.0 * mult))

## 서장대 야조 군사훈련 1회성 소모비 (쉬움 기준: 금 2,000냥, 곡 1,000석)
static func get_military_drill_cost() -> Dictionary:
	var mult: float = get_cost_multiplier()
	return {
		"gold": int(round(2000.0 * mult)),
		"rice": int(round(1000.0 * mult))
	}

static func get_seojangdae_drill_cost() -> Dictionary:
	return get_military_drill_cost()

## 연무대 장용영 무예 사열 1회성 소모비 (쉬움 기준: 금 2,000냥, 곡 2,000석)
static func get_yeonmudae_drill_cost() -> Dictionary:
	var mult: float = get_cost_multiplier()
	return {
		"gold": int(round(2000.0 * mult)),
		"rice": int(round(2000.0 * mult))
	}

## 화성유수부 도적 소굴 토벌 출동 비용 (쉬움: 금 1,000냥, 곡 1,000석 / 보통: x2 / 어려움: x3)
static func get_bandit_subjugation_cost() -> Dictionary:
	var mult: float = get_cost_multiplier()
	return {
		"gold": int(round(1000.0 * mult)),
		"rice": int(round(1000.0 * mult))
	}

## 현륭원 참배 행사 1회성 소모비 (쉬움 기준: 금 2,000냥, 곡 1,000석)
static func get_tomb_visit_cost() -> Dictionary:
	var mult: float = get_cost_multiplier()
	return {
		"gold": int(round(2000.0 * mult)),
		"rice": int(round(1000.0 * mult))
	}

## 김판관 과업(퀘스트) 보상 산출 (쉬움: 금 1,000냥, 곡 1,000석 일괄 상향, 보통/어려움: 기존 보상 유지)
static func get_quest_reward(base_reward: Dictionary) -> Dictionary:
	var reward: Dictionary = base_reward.duplicate()
	if current_difficulty == Difficulty.EASY:
		reward["gold"] = 1000
		reward["rice"] = 1000
	return reward

# -------------------------------------------------------------------------
# 도로 및 인구/재해 밸런스
# -------------------------------------------------------------------------

## 1. 박석길 건설 비용 산출 (흙길 대비 배율)
## - 쉬움: 기존 흙길/박석길 유지
## - 보통: 흙길 건설비의 정확히 10배 (또는 배율 연동)
## - 어려움: 흙길 건설비의 11배
static func get_stone_road_cost(base_dirt_cost: Dictionary) -> Dictionary:
	var dirt_gold: int = int(base_dirt_cost.get("gold", 20))
	var dirt_rice: int = int(base_dirt_cost.get("rice", 0))

	match current_difficulty:
		Difficulty.EASY:
			return {"gold": 35, "rice": 5}
		Difficulty.NORMAL:
			return {"gold": dirt_gold * 3, "rice": dirt_rice * 3}
		Difficulty.HARD:
			return {
				"gold": int(round(float(dirt_gold) * 3.3)),
				"rice": int(round(float(dirt_rice) * 3.3))
			}
	return {"gold": 35, "rice": 5}

## 2. 인구 비례 구휼미 소모량 산출
## - 기본: 500석
## - 백성 수 10,000명 단위마다 10배씩 증액: 500 * max(1, 10^(floor(pop / 10000)))
## - 어려움: 보통 요구량 * 1.1
static func get_relief_food_cost(population: int) -> int:
	match current_difficulty:
		Difficulty.EASY:
			return 500
		Difficulty.NORMAL, Difficulty.HARD:
			var tier: int = maxi(0, int(float(population) / 10000.0))
			var multiplier: int = 1
			for _i: int in range(tier):
				multiplier *= 10
			var base_req: int = 500 * multiplier
			if current_difficulty == Difficulty.HARD:
				return int(round(float(base_req) * 1.10))
			return base_req
	return 500

## 3. 민가 기반 저잣거리(상업) 조성 허용 여부 판정
static func can_spawn_shop(houses_count: int, shops_count: int) -> bool:
	match current_difficulty:
		Difficulty.EASY:
			return true
		Difficulty.NORMAL, Difficulty.HARD:
			if houses_count <= 0:
				return false
			if shops_count >= houses_count * 2:
				return false
			return true
	return true

## 4. 민가 기반 대유둔전(농업) 활성 경작지 한도 산출
static func get_farm_capacity_limit(houses_count: int) -> int:
	match current_difficulty:
		Difficulty.EASY:
			return 999999
		Difficulty.NORMAL, Difficulty.HARD:
			return houses_count * 30
	return 999999

## 5. 공공기관 계절(분기) 유지비 비율
static func get_public_maintenance_rate() -> float:
	match current_difficulty:
		Difficulty.EASY:
			return 0.0
		Difficulty.NORMAL:
			return 0.20
		Difficulty.HARD:
			return 0.22
	return 0.0

## 6. 인재 계절 녹봉 (1인당)
## - 쉬움: 0냥 (기존 밸런스 보존)
## - 보통: 200냥 (쉬움 기준치 100냥의 2배)
## - 어려움: 300냥 (쉬움 기준치 100냥의 3배)
static func get_retainer_salary() -> int:
	match current_difficulty:
		Difficulty.EASY:
			return 0
		Difficulty.NORMAL:
			return 200
		Difficulty.HARD:
			return 300
	return 0

## 6-1. 관리(인재) 개별 턴 녹봉 배율 (Retainer Salary Multiplier)
## - 쉬움: 1.0x (쉬움 기준 녹봉 보존)
## - 보통: 2.0x (쉬움의 2배)
## - 어려움: 3.0x (쉬움의 3배)
static func get_retainer_salary_multiplier() -> float:
	match current_difficulty:
		Difficulty.EASY:
			return 1.0
		Difficulty.NORMAL:
			return 2.0
		Difficulty.HARD:
			return 3.0
	return 1.0

## 6-2. 난이도별 세수 징수 배율 (Tax Revenue Multiplier)
## - 쉬움: 1.0x (100% 징수, 기본값 보존)
## - 보통: 0.70x (지금보다 30% 덜 걷힘)
## - 어려움: 0.60x (지금보다 40% 덜 걷힘)
static func get_tax_multiplier() -> float:
	match current_difficulty:
		Difficulty.EASY:
			return 1.0
		Difficulty.NORMAL:
			return 0.70
		Difficulty.HARD:
			return 0.60
	return 1.0

## 7. 모범적 축성 노임 지출 (성벽 1칸 축조 시 추가 노임)
static func get_wall_labor_cost() -> Dictionary:
	match current_difficulty:
		Difficulty.EASY:
			return {"gold": 0, "rice": 0}
		Difficulty.NORMAL:
			return {"gold": 50, "rice": 20}
		Difficulty.HARD:
			return {"gold": 55, "rice": 22}
	return {"gold": 0, "rice": 0}

## 8. 재해 시 생산 감소율
static func get_disaster_penalty(disaster_type: String) -> float:
	match disaster_type:
		"drought", "flood":
			match current_difficulty:
				Difficulty.EASY:
					return 0.20
				Difficulty.NORMAL:
					return 0.70
				Difficulty.HARD:
					return 0.80
		"fire":
			match current_difficulty:
				Difficulty.EASY:
					return 0.20
				Difficulty.NORMAL:
					return 0.80
				Difficulty.HARD:
					return 0.90
	return 0.0

## 공공기관 건물별 기준 초기 건설비 매핑
const PUBLIC_FACILITY_BASE_COSTS: Dictionary = {
	"haenggung": 500,
	"gwana": 1000,
	"hyanggyo": 250,
	"seodang": 150,
	"hyeminseo": 200,
	"poru": 180,
	"jongnu": 220,
	"seojangdae": 200,
	"bongdon": 150,
	"yeonmudae": 220,
	"banghwasuryu": 350,
	"hwahong": 2000,
	"yeonghwajeong": 300,
	"patrol": 120,
	"firefighter": 100,
	"gongsimdon": 160
}

static func is_public_facility(building_id: String) -> bool:
	return PUBLIC_FACILITY_BASE_COSTS.has(building_id)

static func get_public_facility_base_cost(building_id: String) -> int:
	return int(PUBLIC_FACILITY_BASE_COSTS.get(building_id, 0))

# -------------------------------------------------------------------------
# 동적 난이도 및 도시 성장(인구 10만+ / 국부 10만+) 비례 위협 스케일링 엔진 (SSOT)
# -------------------------------------------------------------------------

## 난이도별 범죄율 인구 계수 (인구 100,000명 초과분 10,000명 단위당)
## 쉬움: 0.5% (0.005), 보통: 1.0% (0.010), 어려움: 1.5% (0.015)
const CRIME_POP_COEFF: Dictionary = {
	Difficulty.EASY: 0.005,
	Difficulty.NORMAL: 0.010,
	Difficulty.HARD: 0.015
}

## 난이도별 범죄 추가 확률 최대 상한선 (Hard Cap)
## 쉬움: +20% (0.20), 보통: +30% (0.30), 어려움: +40% (0.40)
const CRIME_MAX_BONUS: Dictionary = {
	Difficulty.EASY: 0.20,
	Difficulty.NORMAL: 0.30,
	Difficulty.HARD: 0.40
}

## 치안 인프라(순라청/유수부) 결핍 시 피해 증폭 배율
## 쉬움: 1.0배 (민심 -2, 세수 -10%)
## 보통: 1.5배 (민심 -3, 세수 -15%)
## 어려움: 2.0배 (민심 -4, 세수 -20%)
const SECURITY_DEFICIT_PENALTY_MULT: Dictionary = {
	Difficulty.EASY: 1.0,
	Difficulty.NORMAL: 1.5,
	Difficulty.HARD: 2.0
}

## 거대 도시 민심 획득 기본 승수 (Morale Drag Base Multiplier)
## 쉬움: 1.0, 보통: 0.85, 어려움: 0.70
const MORALE_DIFFICULTY_MULT: Dictionary = {
	Difficulty.EASY: 1.0,
	Difficulty.NORMAL: 0.85,
	Difficulty.HARD: 0.70
}

## 국부(금화·곡식 10만+) 축적 비례 도적 스폰 재물 계수 (초과 부 20,000당)
## 쉬움: 0.5% (0.005), 보통: 1.0% (0.010), 어려움: 2.0% (0.020)
const WEALTH_BANDIT_COEFF: Dictionary = {
	Difficulty.EASY: 0.005,
	Difficulty.NORMAL: 0.010,
	Difficulty.HARD: 0.020
}

## 도적 소굴 스폰 가산 확률 최대 상한 (25.0% = 0.25)
const WEALTH_BANDIT_MAX_BONUS: float = 0.25

## 상단 습격 시 초과 재물 추가 약탈율
## 쉬움/보통: 초과분의 2% (0.02), 어려움: 초과분의 3% (0.03)
const EXCESS_LOOT_RATE: Dictionary = {
	Difficulty.EASY: 0.02,
	Difficulty.NORMAL: 0.02,
	Difficulty.HARD: 0.03
}

## 1. 인구 10만 초과 비례 추가 범죄 확률 계산 (SSOT)
## 추가 범죄 확률(%) = max(0, floor((총인구 - 100,000) / 10,000)) * 인구계수
static func get_crime_rate_modifier(population: int) -> float:
	if population <= 100000:
		return 0.0
	var excess_pop: int = population - 100000
	var tier: int = maxi(0, int(float(excess_pop) / 10000.0))
	var coeff: float = float(CRIME_POP_COEFF.get(current_difficulty, 0.010))
	var max_bonus: float = float(CRIME_MAX_BONUS.get(current_difficulty, 0.30))
	var bonus: float = float(tier) * coeff
	return clampf(bonus, 0.0, max_bonus)

## alias 지원 (get_crime_chance_bonus)
static func get_crime_chance_bonus(population: int) -> float:
	return get_crime_rate_modifier(population)

## 2. 치안 인프라(순라청/유수부) 결핍 시 피해 배율 반환
static func get_security_deficit_penalty_multiplier() -> float:
	return float(SECURITY_DEFICIT_PENALTY_MULT.get(current_difficulty, 1.0))

## 3. 도시 규모 및 난이도 연동 민심 획득 승수 계산 (Morale Drag)
## 실제 민심 획득량 = 기본 획득치 * 난이도 기본 승수 * (1.0 - 인구 감쇠율)
## 인구 감쇠율 = min(0.30, max(0.0, (총인구 - 100,000) / 1,000,000.0))
static func get_morale_gain_multiplier(population: int = 0) -> float:
	var base_mult: float = float(MORALE_DIFFICULTY_MULT.get(current_difficulty, 0.85))
	var pop_decay: float = 0.0
	if population > 100000:
		pop_decay = clampf(float(population - 100000) / 1000000.0, 0.0, 0.30)
	return base_mult * (1.0 - pop_decay)

## 4. 국부(금화·곡식 10만+) 비례 도적·반란 위협 가산 확률 계산
## W_excess = max(0, gold - 100,000) + max(0, grain - 100,000)
## 도적 스폰 가산 확률(%) = min(0.25, floor(W_excess / 20,000) * 재물 계수)
static func get_threat_escalation(gold: int, rice: int) -> float:
	var excess_gold: int = maxi(0, gold - 100000)
	var excess_rice: int = maxi(0, rice - 100000)
	var total_excess: int = excess_gold + excess_rice
	if total_excess <= 0:
		return 0.0
	var units: int = maxi(0, int(float(total_excess) / 20000.0))
	var coeff: float = float(WEALTH_BANDIT_COEFF.get(current_difficulty, 0.010))
	var bonus: float = float(units) * coeff
	return clampf(bonus, 0.0, WEALTH_BANDIT_MAX_BONUS)

## alias 지원 (get_bandit_spawn_bonus)
static func get_bandit_spawn_bonus(gold: int, rice: int) -> float:
	return get_threat_escalation(gold, rice)

## 5. 초과 부에 대한 상단 습격 추가 약탈 비율 반환 (쉬움/보통 2%, 어려움 3%)
static func get_excess_loot_rate() -> float:
	return float(EXCESS_LOOT_RATE.get(current_difficulty, 0.02))
