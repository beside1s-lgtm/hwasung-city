extends Node
class_name TechTreeManager

## [실학 학문력 연동 점진적 연구 엔진 및 세자 제왕학 서연 매니저]
## - 턴당 지속 국고 소모 (1,000냥, 정약용 버프 시 700냥)
## - 과제별 필수 인재 선결 조건 FSM 및 인재 공백/재정 부족 안전 일시정지
## - 점진적 진행도 가산 = 1 + floor(학문력 / 10) (1% ~ 10%)

enum ResearchStatus {
	IDLE = 0,
	ACTIVE = 1,
	PAUSED_NO_FUNDS = 2,
	PAUSED_NO_SCHOLAR = 3,
	COMPLETED = 4
}

signal research_started(tech_id: String)
signal research_progress_updated(tech_id: String, progress: float)
signal research_completed(tech_id: String)
signal research_status_changed(tech_id: String, status: int)
signal research_paused(tech_id: String, reason: String)
@warning_ignore("unused_signal")
signal research_resumed(tech_id: String)
signal prince_study_progress_updated(progress: float)
signal prince_study_completed

const TECH_LIST: Array[Dictionary] = [
	{
		"id": "goguma",
		"name": "조엄의 감저(고구마) 도입",
		"cost": 1000,
		"turn_cost": 1000,
		"required_scholar_id": "",
		"required_scholar_name": "",
		"desc": "구황작물 보급 — 군량 소비 37% 감소"
	},
	{
		"id": "gwanong",
		"name": "과농소초 및 통상 개화론",
		"cost": 1000,
		"turn_cost": 1000,
		"required_scholar_id": "park_jega",
		"required_scholar_name": "박제가",
		"desc": "북학파 상업 무역 및 청나라 농기구 도입 — 식량 생산 +40%"
	},
	{
		"id": "seed",
		"name": "임원경제지·우량 벼 품종",
		"cost": 1000,
		"turn_cost": 1000,
		"required_scholar_id": "seo_yugu",
		"required_scholar_name": "서유구",
		"desc": "조선 후기 농정 백과사전 및 둔전 수리 농법 — 식량 생산 +20%"
	},
	{
		"id": "fertilizer",
		"name": "일반 농법(녹비·퇴비 시비법)",
		"cost": 1000,
		"turn_cost": 1000,
		"required_scholar_id": "",
		"required_scholar_name": "",
		"desc": "기본 농서 및 백성들의 농업 기술 — 매달 식량 +60"
	},
	{
		"id": "reservoir",
		"name": "만석거 관개 정비",
		"cost": 1000,
		"turn_cost": 1000,
		"required_scholar_id": "",
		"required_scholar_name": "",
		"desc": "만석거 수리 시설 확충 및 관개 정비 — 매달 식량 +80"
	},
	{
		"id": "boyuron",
		"name": "남인 실학자의 보유론(補儒論)",
		"cost": 1000,
		"turn_cost": 1000,
		"required_scholar_id": "namin",
		"required_scholar_name": "남인 인재",
		"desc": "유교 고전과 서학의 천주 조화 — 천주교당 왕권 감소 소멸, 민심 +1/달, 학문력 +5"
	},
	{
		"id": "segi",
		"name": "기기도설·거중기·서기수용론",
		"cost": 1000,
		"turn_cost": 1000,
		"required_scholar_id": "jeong_yakyong",
		"required_scholar_name": "정약용",
		"desc": "《기기도설》·거중기 실전 배치 — 왕권 감소 무효, 서학 인재 연구비 -30%, 대역사 비용 -20%"
	},
	{
		"id": "sugusik",
		"name": "수학적 축성술·천문 역법",
		"cost": 1000,
		"turn_cost": 1000,
		"required_scholar_id": "lee_gahwan",
		"required_scholar_name": "이가환",
		"desc": "수학·기하학 기반 정밀 성벽 축조 및 측량 — 수문 내구도 및 성곽 방호력 강화"
	}
]

## 실학 연구 진행도 (0.0% ~ 100.0%)
var tech_progress_dict: Dictionary = {
	"goguma": 0.0, "gwanong": 0.0, "seed": 0.0, "fertilizer": 0.0,
	"reservoir": 0.0, "boyuron": 0.0, "segi": 0.0, "sugusik": 0.0
}

## 연구 완료 상태 (true / false)
var tech_completed_dict: Dictionary = {
	"goguma": false, "gwanong": false, "seed": false, "fertilizer": false,
	"reservoir": false, "boyuron": false, "segi": false, "sugusik": false
}

## 현재 진행 중인 실학 과제 ID
var current_researching: String = ""

## active_research_id 호환성 프로퍼티
var active_research_id: String:
	get:
		return current_researching
	set(val):
		current_researching = val

## 연구 상태 FSM
var research_status: int = ResearchStatus.IDLE

## 동일 턴 중복 정산 방지 가드
var last_processed_turn: int = -1

## 세자 제왕학 서연 진행도 (0.0% ~ 100.0%)
var prince_edu_progress: float = 0.0
var prince_studying: bool = false

func _init() -> void:
	name = "TechTreeManager"
	process_mode = Node.PROCESS_MODE_ALWAYS

## 과제 정보 조회
func get_tech_info(id: String) -> Dictionary:
	for t: Dictionary in TECH_LIST:
		if t["id"] == id:
			return t
	return {}

## 필수 인재 선결 조건 검사
func check_scholar_prerequisite(tech_id: String, sim: Node = null) -> Dictionary:
	var info: Dictionary = get_tech_info(tech_id)
	if info.is_empty():
		return {"satisfied": false, "required_scholar": "", "name": ""}

	var req_id: String = str(info.get("required_scholar_id", ""))
	var req_name: String = str(info.get("required_scholar_name", ""))
	if req_id == "":
		return {"satisfied": true, "required_scholar": "", "name": ""}

	var retainers: Dictionary = {}
	if sim != null and "retainers" in sim and sim.retainers is Dictionary:
		retainers = sim.retainers

	var satisfied: bool = ScholarManager.has_scholar(req_id, retainers)
	return {
		"satisfied": satisfied,
		"required_scholar": req_id,
		"name": req_name
	}

## 턴당 지속 연구비 산출 (정약용 등용 시 -30% 할인 -> 700냥)
func get_research_turn_cost(tech_id: String, sim: Node = null) -> int:
	var base_cost: int = 1000
	var info: Dictionary = get_tech_info(tech_id)
	if not info.is_empty():
		base_cost = int(info.get("turn_cost", 1000))

	var jeong_hired: bool = false
	if sim != null and "retainers" in sim and sim.retainers is Dictionary:
		jeong_hired = ScholarManager.has_scholar("jeong_yakyong", sim.retainers)
	elif sim != null and sim.has_method("is_hired"):
		jeong_hired = bool(sim.call("is_hired", "jeong"))

	if jeong_hired:
		return int(float(base_cost) * 0.7)
	return base_cost

## 연구 착수 요청 (일시불 완납 폐지, 필수 인재 선결 조건 검사 후 등록)
func start_research(id: String, sim: Node = null, _cost_override: int = -1) -> String:
	if bool(tech_completed_dict.get(id, false)):
		return "이미 연구를 완료했습니다."
	if current_researching == id:
		return "이미 연구가 진행 중입니다. (진척도 %d%%)" % int(tech_progress_dict.get(id, 0.0))

	var info: Dictionary = get_tech_info(id)
	if info.is_empty():
		return "존재하지 않는 연구 과제입니다."

	# 필수 인재 등용 선결 조건 검사
	var prereq: Dictionary = check_scholar_prerequisite(id, sim)
	if not bool(prereq.get("satisfied", true)):
		var sch_name: String = str(prereq.get("name", "필수 인재"))
		return "[%s] 등용이 필요하여 연구에 착수할 수 없습니다." % sch_name

	current_researching = id
	research_status = ResearchStatus.ACTIVE
	if not tech_progress_dict.has(id):
		tech_progress_dict[id] = 0.0

	emit_signal("research_started", id)
	emit_signal("research_status_changed", id, research_status)
	return "《%s》 연구에 착수했습니다. 매달 국고가 지속 지출되며 학문력에 따라 점진적으로 진척됩니다." % str(info["name"])

## 진행 중인 연구 중단 (진행도 보존)
func stop_research(id: String = "") -> String:
	if current_researching == "" or (id != "" and current_researching != id):
		return "진행 중인 연구가 없습니다."

	var stopped_id: String = current_researching
	current_researching = ""
	research_status = ResearchStatus.IDLE
	emit_signal("research_status_changed", stopped_id, research_status)
	return "연구를 일시 중단했습니다. 진행도는 보존됩니다."

## 연구 즉시 강제 완료 (테스트/치트/초기 상태 복원용)
func complete_research_instantly(id: String, sim: Node = null) -> void:
	tech_progress_dict[id] = 100.0
	tech_completed_dict[id] = true
	if current_researching == id:
		current_researching = ""
	research_status = ResearchStatus.COMPLETED
	_apply_tech_effects(id, sim)
	emit_signal("research_completed", id)
	emit_signal("research_status_changed", id, research_status)

## 세자 제왕학 서연 시작 요청
func start_prince_study(sim: Node) -> String:
	if prince_edu_progress >= 100.0:
		return "세자께서 이미 제왕학을 완수하셨습니다."
	if prince_studying:
		return "이미 시강원 서연이 진행 중입니다. (진척도 %d%%)" % int(prince_edu_progress)

	if sim:
		if sim.gold < 100 or sim.rice < 40:
			return "서연 운영에 필요한 국고(100냥) 또는 군량(40석)이 부족합니다."
		sim.gold -= 100
		sim.rice -= 40

	prince_studying = true
	return "시강원 서연에 착수했습니다. 매달 학문력에 비례해 세자의 역량이 점진적으로 증진됩니다."

## 연구 완료 여부 확인
## 남은(아직 다 하지 않은) 실학 과제가 있는가
func has_remaining_research() -> bool:
	for k in tech_completed_dict.keys():
		if not bool(tech_completed_dict[k]):
			return true
	return false

func is_completed(id: String) -> bool:
	return bool(tech_completed_dict.get(id, false))

## 연구 완료 여부 확인 (별칭 및 시뮬레이션 상태 호환 지원)
func has_researched(id: String, sim: Node = null) -> bool:
	var target_id: String = id
	if target_id == "seogi_suyong" or target_id == "segi_policy":
		target_id = "segi"
	if bool(tech_completed_dict.get(target_id, false)):
		return true
	if sim != null:
		if target_id == "boyuron" and bool(sim.get("boyuron")):
			return true
		if target_id == "segi" and bool(sim.get("segi_policy")):
			return true
	return false

## 연구 진척도 확인 (0.0 ~ 100.0)
func get_progress(id: String) -> float:
	return float(tech_progress_dict.get(id, 0.0))

## 현재 진행 중인 연구 id 확인
func get_current_research() -> String:
	return current_researching

## 턴당 국고 지속 소모 및 점진적 진척도 정산 엔진
## - 국고 1,000냥(정약용 시 700냥) 지속 차감
## - 국고 부족 시 PAUSED_NO_FUNDS 상태 전환 (진행도 보존)
## - 인재 공백 시 PAUSED_NO_SCHOLAR 상태 전환 (진행도 보존)
## - 공식: 턴당 진척도 = 1 + floor(학문력 / 10) (최소 1% ~ 최대 10%)
func process_turn_research(academic_power: int, sim: SimulationCore = null, has_lee_deokmu: bool = false, check_turn_guard: bool = false) -> Dictionary:
	if check_turn_guard and sim != null and "turn" in sim and sim.turn == last_processed_turn:
		return {
			"step": 0.0,
			"cost_deducted": 0,
			"status": research_status,
			"research_completed": "",
			"prince_completed": false
		}

	if sim != null and "turn" in sim:
		last_processed_turn = int(sim.turn)


	var base_step: float = float(1 + clampi(int(float(academic_power) / 10.0), 0, 9)) # 1% ~ 10%
	var result: Dictionary = {
		"step": base_step,
		"cost_deducted": 0,
		"status": research_status,
		"research_completed": "",
		"prince_completed": false
	}

	# 1. 실학 연구 과제 지속 정산
	if current_researching != "":
		var cur_id: String = current_researching

		# (1) 인재 해임/공백 검사
		var prereq: Dictionary = check_scholar_prerequisite(cur_id, sim)
		if not bool(prereq.get("satisfied", true)):
			research_status = ResearchStatus.PAUSED_NO_SCHOLAR
			result["status"] = research_status
			emit_signal("research_paused", cur_id, "필수 인재 공백")
			emit_signal("research_status_changed", cur_id, research_status)
		else:
			# (2) 재정 고갈 안전장치 (Budget Starvation Guard)
			var turn_cost: int = get_research_turn_cost(cur_id, sim)
			var current_gold: int = ResourceManager.get_gold(sim)
			if sim != null and current_gold < turn_cost:
				research_status = ResearchStatus.PAUSED_NO_FUNDS
				result["status"] = research_status
				emit_signal("research_paused", cur_id, "재정 부족")
				emit_signal("research_status_changed", cur_id, research_status)
			else:
				# 정상 연구 진행 (국고 차감 및 진척도 가산)
				research_status = ResearchStatus.ACTIVE
				if sim != null:
					ResourceManager.deduct_gold(turn_cost, sim)
					result["cost_deducted"] = turn_cost
				result["status"] = research_status

				var current_p: float = float(tech_progress_dict.get(cur_id, 0.0))
				var new_p: float = clampf(current_p + base_step, 0.0, 100.0)
				tech_progress_dict[cur_id] = new_p

				emit_signal("research_progress_updated", cur_id, new_p)

				if new_p >= 100.0:
					tech_completed_dict[cur_id] = true
					research_status = ResearchStatus.COMPLETED
					current_researching = ""
					_apply_tech_effects(cur_id, sim)
					result["research_completed"] = cur_id
					emit_signal("research_completed", cur_id)
					emit_signal("research_status_changed", cur_id, research_status)

	# 2. 세자 제왕학 서연 점진적 진척 (이덕무 검서관 등용 시 +2% 가산 보너스)
	if prince_studying and prince_edu_progress < 100.0:
		var prince_step: float = base_step + (2.0 if has_lee_deokmu else 0.0)
		prince_edu_progress = clampf(prince_edu_progress + prince_step, 0.0, 100.0)
		CityStats.set_crown_prince_education(int(prince_edu_progress))

		emit_signal("prince_study_progress_updated", prince_edu_progress)

		if prince_edu_progress >= 100.0:
			prince_studying = false
			result["prince_completed"] = true
			emit_signal("prince_study_completed")

	return result

## 하위 호환 래퍼: 기존 process_turn_tick 호출 대응
func process_turn_tick(academic_power: int, sim: Node = null, has_lee_deokmu: bool = false) -> Dictionary:
	return process_turn_research(academic_power, sim as SimulationCore, has_lee_deokmu)

## 완료된 연구의 시뮬레이션 효과 적용
func _apply_tech_effects(id: String, sim: Node) -> void:
	if sim == null:
		return
	match id:
		"boyuron":
			sim.boyuron = true
			sim.academic = mini(100, sim.academic + 5)
			CityStats.set_academic_power(sim.academic)
		"segi":
			sim.segi_policy = true

## 세이브용 직렬화 데이터
func serialize() -> Dictionary:
	return {
		"tech_progress_dict": tech_progress_dict.duplicate(),
		"tech_completed_dict": tech_completed_dict.duplicate(),
		"current_researching": current_researching,
		"research_status": research_status,
		"prince_edu_progress": prince_edu_progress,
		"prince_studying": prince_studying
	}

## 역직렬화 (Null-Safe Fallback 보장)
func deserialize(data: Dictionary) -> void:
	tech_progress_dict = {
		"goguma": 0.0, "gwanong": 0.0, "seed": 0.0, "fertilizer": 0.0,
		"reservoir": 0.0, "boyuron": 0.0, "segi": 0.0, "sugusik": 0.0
	}
	var saved_prog: Dictionary = data.get("tech_progress_dict", {})
	for k: String in saved_prog.keys():
		tech_progress_dict[k] = clampf(float(saved_prog[k]), 0.0, 100.0)

	tech_completed_dict = {
		"goguma": false, "gwanong": false, "seed": false, "fertilizer": false,
		"reservoir": false, "boyuron": false, "segi": false, "sugusik": false
	}
	var saved_comp: Dictionary = data.get("tech_completed_dict", {})
	for k2: String in saved_comp.keys():
		tech_completed_dict[k2] = bool(saved_comp[k2])

	current_researching = str(data.get("current_researching", ""))
	research_status = int(data.get("research_status", ResearchStatus.IDLE if current_researching == "" else ResearchStatus.ACTIVE))
	prince_edu_progress = clampf(float(data.get("prince_edu_progress", 0.0)), 0.0, 100.0)
	prince_studying = bool(data.get("prince_studying", false))
