extends Node
class_name UigweManager

## [규장각 의궤 편찬 FSM 및 학문력 연동 점진적 누적 매니저]
## 1. 단순 1회성 구매 폐지 -> 학문력 비례 게이지(0~100%) 점진적 편찬 시스템
## 2. 학문력 0일 때 80턴(20년, 턴당 1.25%), 학문력 100일 때 4턴(1년, 턴당 25.0%)
## 3. 연간 기본 비용 5,000냥 (1년 4턴 분할 정산: 턴당 약 1,250냥 전후, 난이도 및 연구할인율 적용)
## 4. 재정 고갈 시 점수 보존 및 안전 일시 정지 (PAUSED), 국고 확보 시 재개
## 5. 100% 완료 시 [📖 의궤 열람] 뷰어 모달 연동 및 역사적 가치 도감 열람

enum UigweStatus {
	INACTIVE = 0,   ## 미착수
	COMPILING = 1,  ## 편찬 진행 중
	PAUSED = 2,     ## 재정 부족 또는 수동 일시정지
	COMPLETED = 3   ## 100% 편찬 완료
}

signal uigwe_started(id: String)
signal uigwe_progress_updated(id: String, progress: float)
signal uigwe_paused(id: String, reason: String)
signal uigwe_resumed(id: String)
signal uigwe_completed(id: String)

const UIGWE_DATA: Dictionary = {
	"wonhaeng": {
		"id": "wonhaeng",
		"name": "원행을묘정리의궤 (園幸乙卯整理儀軌)",
		"short_name": "원행을묘정리의궤",
		"hanja": "園幸乙卯整理儀軌",
		"from_year": 1795,
		"condition_desc": "1795년 이후, 혜경궁 회갑연 완수",
		"base_annual_cost": 5000,
		"image_path": "res://assets/images/uigwe_wonhaeng.png",
		"auth_bonus": 10,
		"loyal_bonus": 10,
		"description": "1795년 정조가 어머니 혜경궁 홍씨를 모시고 거행한 화성 원행과 회갑연의 전 과정을 정리자 활자와 정밀한 반차도 도설로 집대성한 조선 기록문화의 정수입니다. 의식의 장엄함과 효심을 생생히 전하는 유네스코 세계기록유산입니다."
	},
	"seongyeok": {
		"id": "seongyeok",
		"name": "화성성역의궤 (華城城役儀軌)",
		"short_name": "화성성역의궤",
		"hanja": "華城城役儀軌",
		"from_year": 1796,
		"condition_desc": "1796년 이후, 화성 축성 공사 진행 중 (성곽 완공도 80% 이상, 채제공·정약용)",
		"base_annual_cost": 5000,
		"image_path": "res://assets/images/uigwe_hwaseong.png",
		"auth_bonus": 15,
		"loyal_bonus": 10,
		"description": "수원화성 축성의 설계도부터 소요 자재, 석수와 목수의 노임 및 실명, 정약용의 거중기 등 과학기구의 도면까지 공사의 모든 전말을 낱낱이 기록한 보고서입니다. 세계 건축사상 유례를 찾을 수 없는 완벽한 종합 기록물입니다."
	}
}

var progress_dict: Dictionary = {
	"wonhaeng": 0.0,
	"seongyeok": 0.0
}

var status_dict: Dictionary = {
	"wonhaeng": UigweStatus.INACTIVE,
	"seongyeok": UigweStatus.INACTIVE
}

## 프롬프트 사양 대응 독립 변수 호환성 프로퍼티
var progress_wonhaeng: float:
	get:
		return float(progress_dict.get("wonhaeng", 0.0))
	set(val):
		progress_dict["wonhaeng"] = val

var progress_hwaseong: float:
	get:
		return float(progress_dict.get("seongyeok", 0.0))
	set(val):
		progress_dict["seongyeok"] = val

func _init() -> void:
	name = "UigweManager"
	process_mode = Node.PROCESS_MODE_ALWAYS

func get_progress(id: String) -> float:
	return float(progress_dict.get(id, 0.0))

func set_progress(id: String, val: float) -> void:
	progress_dict[id] = clampf(val, 0.0, 100.0)
	if progress_dict[id] >= 100.0:
		status_dict[id] = UigweStatus.COMPLETED

func get_status(id: String) -> int:
	return int(status_dict.get(id, UigweStatus.INACTIVE))

func set_status(id: String, st: int) -> void:
	status_dict[id] = st

func is_completed(id: String) -> bool:
	return int(status_dict.get(id, UigweStatus.INACTIVE)) == UigweStatus.COMPLETED or float(progress_dict.get(id, 0.0)) >= 100.0

## 학문력(0~100) 연동 턴당 진행률 산출식 (1.25% ~ 25.0%)
static func get_turn_progress_rate(academic_power: int) -> float:
	var acad_clamped: float = clampf(float(academic_power), 0.0, 100.0)
	return 1.25 + (acad_clamped / 100.0 * 23.75)

func calculate_turn_rate(academic_power: int) -> float:
	return get_turn_progress_rate(academic_power)

## 완공까지 예상 남은 턴 수
static func get_estimated_turns_remaining(progress: float, academic_power: int) -> int:
	var rate: float = get_turn_progress_rate(academic_power)
	if rate <= 0.001:
		return 80
	var rem: float = maxf(0.0, 100.0 - progress)
	return int(ceil(rem / rate))

## 연구 및 인재 할인율 산출 (0.0 ~ 0.5)
static func get_cost_discount(sim: Node = null) -> float:
	var discount: float = 0.0
	if sim != null and "retainers" in sim and sim.retainers is Dictionary:
		# 이덕무 검서관: 서적 간행비 30% 할인
		if bool(sim.retainers.get("lee_deokmu", false)):
			discount = maxf(discount, 0.3)
		# 채제공 영의정: 국책 프로젝트 20% 할인
		if bool(sim.retainers.get("chae_jegong", false)):
			discount = maxf(discount, 0.2)
		# 정약용: 서기수용론/기술 20% 할인
		if bool(sim.retainers.get("jeong_yakyong", false)):
			discount = maxf(discount, 0.2)
	return discount

## 연간 실비용 산출 (5,000냥 * 난이도배율 * (1 - 할인율))
static func get_annual_cost(_id: String = "", sim: Node = null) -> int:
	var base_cost: float = 5000.0
	var diff_mult: float = 1.0
	if DifficultyManager != null:
		diff_mult = DifficultyManager.get_cost_multiplier()
	var discount: float = get_cost_discount(sim)
	var final_cost: float = base_cost * diff_mult * (1.0 - discount)
	return maxi(1000, int(round(final_cost)))

## 1년=4턴 기준 턴당 분할 정산 비용 (약 1,250냥 전후)
static func get_turn_cost(id: String = "", sim: Node = null) -> int:
	var annual: int = get_annual_cost(id, sim)
	return maxi(100, int(float(annual) / 12.0)) # 1턴 = 1개월

## 의궤 해금 선행 조건 검사
func check_prerequisites(id: String, court: CourtSystem = null, sim: SimulationCore = null) -> Dictionary:
	if not UIGWE_DATA.has(id):
		return {"satisfied": false, "reason": "존재하지 않는 의궤입니다."}

	var cur_year: int = 1789
	if court != null:
		cur_year = court.current_year
	elif sim != null:
		cur_year = sim.current_year

	var info: Dictionary = UIGWE_DATA[id]
	var from_yr: int = int(info.get("from_year", 1795))

	if cur_year < from_yr:
		return {
			"satisfied": false,
			"reason": "%d년 이후에 편찬할 수 있습니다. (현재 %d년)" % [from_yr, cur_year]
		}

	if id == "wonhaeng":
		if court != null and "milestones" in court and not court.milestones.get("eulmyo1795", false):
			if cur_year < 1795:
				return {
					"satisfied": false,
					"reason": "1795년 을묘원행(혜경궁 회갑연)을 먼저 치러야 합니다."
				}
	elif id == "seongyeok":
		if sim != null and sim.fortress_progress < 80:
			return {
				"satisfied": false,
				"reason": "화성 성곽을 더 축조해야 합니다. (완공률 80%% 이상, 현재 %d%%)" % int(sim.fortress_progress)
			}
		if sim != null and "retainers" in sim and sim.retainers is Dictionary:
			var has_chae: bool = bool(sim.retainers.get("chae_jegong", false))
			var has_jeong: bool = bool(sim.retainers.get("jeong_yakyong", false))
			if not has_chae and not has_jeong:
				return {
					"satisfied": false,
					"reason": "총리대신 채제공 또는 감동당상 정약용 나리를 등용해야 합니다."
				}

	return {"satisfied": true, "reason": ""}

## 편찬 시작 요청
func start_compilation(id: String, sim: SimulationCore = null, court: CourtSystem = null) -> Dictionary:
	if not UIGWE_DATA.has(id):
		return {"success": false, "msg": "존재하지 않는 의궤입니다."}

	var status: int = int(status_dict.get(id, UigweStatus.INACTIVE))
	if status == UigweStatus.COMPLETED or float(progress_dict.get(id, 0.0)) >= 100.0:
		status_dict[id] = UigweStatus.COMPLETED
		return {"success": false, "msg": "이미 편찬을 완료한 의궤입니다."}

	if status == UigweStatus.COMPILING:
		return {"success": false, "msg": "이미 편찬이 진행 중입니다."}

	var prereq: Dictionary = check_prerequisites(id, court, sim)
	if not bool(prereq.get("satisfied", false)):
		return {"success": false, "msg": str(prereq.get("reason", "선결 조건을 만족하지 못했습니다."))}

	var turn_cost: int = get_turn_cost(id, sim)
	if sim != null and sim.gold < turn_cost:
		status_dict[id] = UigweStatus.PAUSED
		emit_signal("uigwe_paused", id, "재정 부족")
		return {
			"success": false,
			"msg": "편찬 착수에 필요한 국고(%d냥)가 부족하여 시작 즉시 일시 중단됩니다." % turn_cost
		}

	status_dict[id] = UigweStatus.COMPILING
	emit_signal("uigwe_started", id)
	return {
		"success": true,
		"msg": "《%s》 편찬 사업에 착수했습니다. 매달 국고가 지속 소모되며 학문력에 따라 점진적으로 기록됩니다." % str(UIGWE_DATA[id]["name"])
	}

## 편찬 일시 중지
func pause_compilation(id: String) -> Dictionary:
	if not UIGWE_DATA.has(id):
		return {"success": false, "msg": "존재하지 않는 의궤입니다."}

	var status: int = int(status_dict.get(id, UigweStatus.INACTIVE))
	if status != UigweStatus.COMPILING:
		return {"success": false, "msg": "진행 중인 편찬 사업이 아닙니다."}

	status_dict[id] = UigweStatus.PAUSED
	emit_signal("uigwe_paused", id, "사용자 일시중지")
	return {"success": true, "msg": "편찬 사업을 일시 중단했습니다. 누적된 기록은 안전하게 보존됩니다."}

## 편찬 재개
func resume_compilation(id: String, sim: SimulationCore = null) -> Dictionary:
	if not UIGWE_DATA.has(id):
		return {"success": false, "msg": "존재하지 않는 의궤입니다."}

	var status: int = int(status_dict.get(id, UigweStatus.INACTIVE))
	if status != UigweStatus.PAUSED:
		return {"success": false, "msg": "일시 중지 상태가 아닙니다."}

	var turn_cost: int = get_turn_cost(id, sim)
	if sim != null and sim.gold < turn_cost:
		return {"success": false, "msg": "국고(%d냥)가 부족하여 아직 편찬을 재개할 수 없습니다." % turn_cost}

	status_dict[id] = UigweStatus.COMPILING
	emit_signal("uigwe_resumed", id)
	return {"success": true, "msg": "편찬 사업을 재개했습니다."}

## 턴 진행에 따른 비용 차감 및 진척도 누적 (매 턴 SimulationCore에서 호출)
func process_turn(sim: SimulationCore, academic_power: int, court: CourtSystem = null) -> Dictionary:
	var results: Dictionary = {}
	var rate: float = get_turn_progress_rate(academic_power)

	for id: String in ["wonhaeng", "seongyeok"]:
		var status: int = int(status_dict.get(id, UigweStatus.INACTIVE))
		if status != UigweStatus.COMPILING:
			continue

		var turn_cost: int = get_turn_cost(id, sim)
		if sim.gold < turn_cost:
			status_dict[id] = UigweStatus.PAUSED
			emit_signal("uigwe_paused", id, "재정 부족")
			sim.emit_signal("disaster_alert", "⚠️ [의궤 편찬 중단] 재정이 부족하여 《%s》 편찬 사업이 정체되었습니다." % str(UIGWE_DATA[id]["short_name"]))
			results[id] = {"success": false, "reason": "no_funds", "progress": progress_dict[id]}
			continue

		# 비용 지출 및 게이지 가산
		sim.gold -= turn_cost
		var cur_p: float = float(progress_dict.get(id, 0.0)) + rate
		progress_dict[id] = clampf(cur_p, 0.0, 100.0)
		emit_signal("uigwe_progress_updated", id, progress_dict[id])

		results[id] = {
			"success": true,
			"cost_paid": turn_cost,
			"rate": rate,
			"progress": progress_dict[id]
		}

		# 100% 도달 판정
		if progress_dict[id] >= 100.0:
			complete_compilation(id, sim, court)
			results[id]["completed"] = true

	return results

## 의궤 완공 처리 및 보상 지급
func complete_compilation(id: String, sim: SimulationCore = null, court: CourtSystem = null) -> void:
	progress_dict[id] = 100.0
	status_dict[id] = UigweStatus.COMPLETED

	if court != null and "uigwe" in court and court.uigwe is Dictionary:
		court.uigwe[id] = true

	var info: Dictionary = UIGWE_DATA.get(id, {})
	var auth_b: int = int(info.get("auth_bonus", 10))
	var loyal_b: int = int(info.get("loyal_bonus", 10))

	if sim != null:
		sim.authority = mini(100, sim.authority + auth_b)
		sim.loyalty = mini(100, sim.loyalty + loyal_b)
		sim.emit_signal("disaster_alert", "🎉 《%s》 편찬이 마침내 완수되었습니다! 후세에 길이 남을 유네스코 기록유산입니다. (왕권 +%d, 민심 +%d)" % [str(info.get("name", "의궤")), auth_b, loyal_b])
		sim.emit_signal("state_updated", sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)

	emit_signal("uigwe_completed", id)

## 세이브/로드 직렬화
func serialize() -> Dictionary:
	var items: Dictionary = {}
	for k: String in ["wonhaeng", "seongyeok"]:
		items[k] = {
			"progress": float(progress_dict.get(k, 0.0)),
			"status": int(status_dict.get(k, UigweStatus.INACTIVE))
		}
	return {
		"progress_dict": progress_dict.duplicate(true),
		"status_dict": status_dict.duplicate(true),
		"items": items
	}

## 세이브/로드 역직렬화 (Null-Safe Fallback)
func deserialize(data: Dictionary) -> void:
	if data.has("items") and data["items"] is Dictionary:
		for k: String in ["wonhaeng", "seongyeok"]:
			if data["items"].has(k) and data["items"][k] is Dictionary:
				progress_dict[k] = float(data["items"][k].get("progress", 0.0))
				status_dict[k] = int(data["items"][k].get("status", UigweStatus.INACTIVE))
	else:
		if data.has("progress_dict") and data["progress_dict"] is Dictionary:
			for k: String in ["wonhaeng", "seongyeok"]:
				progress_dict[k] = float(data["progress_dict"].get(k, 0.0))
		if data.has("status_dict") and data["status_dict"] is Dictionary:
			for k: String in ["wonhaeng", "seongyeok"]:
				status_dict[k] = int(data["status_dict"].get(k, UigweStatus.INACTIVE))

	# 100% 진행된 경우 완료 상태 보정
	for k: String in ["wonhaeng", "seongyeok"]:
		if float(progress_dict.get(k, 0.0)) >= 100.0:
			status_dict[k] = UigweStatus.COMPLETED
