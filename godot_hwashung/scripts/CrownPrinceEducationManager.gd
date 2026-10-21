extends Node
class_name CrownPrinceEducationManager

## [세자 제왕학 교육 게이지 및 시강원 서연 관리 엔진]
## 1. 단순 클릭 1회성 완료 폐지 -> 턴당 지속 국고 소모(2,000냥 * 난이도 배율)
## 2. 도시 총 학문력(0~100점) 연동 턴당 게이지 상승: (1% + (학문력 / 100 * 9%)) / 1.5 (약 0.67% ~ 6.67%)
## 3. 재정 고갈 시 게이지 날아가지 않고 안전 일시 동결 (PAUSED / PAUSED_NO_FUNDS)
## 4. 게이지 100% 도달 시 정조의 효심과 왕세자 덕목 완성 이벤트 및 최종 보너스 (민심 +15, 왕권 +20)

enum EducationStatus {
	IDLE = 0,
	ACTIVE = 1,
	PAUSED_NO_FUNDS = 2,
	COMPLETED = 3
}

## 프롬프트 사양 대응 EducationState 별칭 열거형
enum EducationState {
	INACTIVE = 0,
	ACTIVE = 1,
	PAUSED = 2,
	COMPLETED = 3
}

const BASE_COST: int = 2000

signal education_started
signal education_progress_updated(progress: float)
signal education_progress_changed(new_score: float, stage_index: int)
signal stage_changed(old_stage: int, new_stage: int)
signal education_paused(reason: String)
signal education_resumed
signal education_completed

var status: int = EducationStatus.IDLE
var progress: float = 0.0 # 초기 세자 교육도 (기본 0%)
var current_stage: int = 0 # 0점이므로 기본 1단계 (유아 세자)
var tutor: String = ""
var is_invested: bool = false

func is_education_active() -> bool:
	return status == EducationStatus.ACTIVE or status == EducationStatus.PAUSED_NO_FUNDS or status == EducationStatus.COMPLETED or progress > 0.0

func _init() -> void:
	name = "CrownPrinceEducationManager"
	process_mode = Node.PROCESS_MODE_ALWAYS
	current_stage = CrownPrinceData.get_stage_by_score(progress)

## 세자 책봉 및 서연 개시
func invest_and_start_education(tutor_name: String = "", sim: SimulationCore = null) -> Dictionary:
	is_invested = true
	tutor = tutor_name
	return start_education(sim)

## 세자 교육 착수 요청
func start_education(sim: SimulationCore = null) -> Dictionary:
	if progress >= 100.0 or status == EducationStatus.COMPLETED:
		status = EducationStatus.COMPLETED
		return {"success": false, "msg": "세자께서 이미 제왕학을 완수하셨습니다."}

	if status == EducationStatus.ACTIVE:
		return {"success": false, "msg": "이미 시강원 서연이 진행 중입니다. (진척도 %d%%)" % int(progress)}

	var turn_cost: int = get_turn_cost()
	if sim != null and sim.gold < turn_cost:
		status = EducationStatus.PAUSED_NO_FUNDS
		emit_signal("education_paused", "국고 부족으로 교육이 일시 동결되었습니다.")
		return {
			"success": false,
			"msg": "시강원 서연 운영에 필요한 국고(금화 %d냥)가 부족하여 시작 즉시 일시 동결됩니다." % turn_cost
		}

	status = EducationStatus.ACTIVE
	emit_signal("education_started")
	return {
		"success": true,
		"msg": "시강원 서연에 착수했습니다. 매달 국고가 지속 지출되며 학문력에 따라 점진적으로 진척됩니다."
	}

## 턴당 필요 국고 비용 계산 (난이도 배율 반영)
func get_turn_cost() -> int:
	return DifficultyManager.get_prince_education_turn_cost()

## 세자 교육 수동 일시 중단 (진행도 보존)
func pause_education(reason: String = "수동 일시 중단") -> void:
	if status == EducationStatus.ACTIVE:
		status = EducationStatus.PAUSED_NO_FUNDS
		emit_signal("education_paused", reason)

## 세자 교육 재개
func resume_education(sim: SimulationCore = null) -> Dictionary:
	if progress >= 100.0:
		status = EducationStatus.COMPLETED
		return {"success": false, "msg": "이미 제왕학 교육이 완료되었습니다."}

	var turn_cost: int = get_turn_cost()
	if sim != null and sim.gold < turn_cost:
		status = EducationStatus.PAUSED_NO_FUNDS
		return {"success": false, "msg": "국고(금화 %d냥)가 부족하여 교육을 재개할 수 없습니다." % turn_cost}

	status = EducationStatus.ACTIVE
	emit_signal("education_resumed")
	return {"success": true, "msg": "시강원 서연을 재개했습니다."}

## 단계 변경 확인 및 시그널 발행 FSM
func update_stage_if_needed() -> void:
	var new_stage: int = CrownPrinceData.get_stage_by_score(progress)
	if new_stage != current_stage:
		var old_stage: int = current_stage
		current_stage = new_stage
		emit_signal("stage_changed", old_stage, new_stage)

## 매 턴 진행도 및 재정 정산 FSM
## - 비용: DifficultyManager.get_prince_education_turn_cost() (쉬움: 2,000냥, 보통: 4,000냥, 어려움: 6,000냥)
## - 상승 공식: (1.0 + (학문력 / 100.0 * 9.0)) / 1.5 -> 학문력 0: 약 0.67%, 학문력 100: 약 6.67% (1.5배 감속)
func process_turn(sim: SimulationCore, academic_power: int) -> Dictionary:
	var result: Dictionary = {
		"step": 0.0,
		"cost_deducted": 0,
		"status": status,
		"completed": false
	}

	if status == EducationStatus.COMPLETED or progress >= 100.0:
		status = EducationStatus.COMPLETED
		result["status"] = status
		return result

	var turn_cost: int = get_turn_cost()

	# 재정 부족 동결 상태에서 국고 확보 시 자동 재개
	if status == EducationStatus.PAUSED_NO_FUNDS:
		if sim != null and sim.gold >= turn_cost:
			status = EducationStatus.ACTIVE
			emit_signal("education_resumed")
		else:
			result["status"] = status
			return result

	if status == EducationStatus.ACTIVE:
		# 재정 점검
		if sim != null and sim.gold < turn_cost:
			status = EducationStatus.PAUSED_NO_FUNDS
			result["status"] = status
			emit_signal("education_paused", "재정 부족으로 세자 교육 일시 동결 (필요: 금화 %d냥)" % turn_cost)
			return result

		# 정상 진행: 국고 차감
		if sim != null:
			sim.gold -= turn_cost
			result["cost_deducted"] = turn_cost

		# 공식: (1 + (학문력 / 100 * 9)) / 1.5 -> 약 0.67% ~ 6.67% (기존 대비 1.5배 감속, 학문력 버프 연동 유지)
		var acad_clamped: float = clampf(float(academic_power), 0.0, 100.0)
		var base_rate: float = 1.0 + (acad_clamped / 100.0) * 9.0
		var rate: float = base_rate / 1.5
		progress = clampf(progress + rate, 0.0, 100.0)
		result["step"] = rate

		CityStats.set_crown_prince_education(int(progress))
		update_stage_if_needed()

		emit_signal("education_progress_updated", progress)
		emit_signal("education_progress_changed", progress, current_stage)

		if progress >= 100.0:
			status = EducationStatus.COMPLETED
			result["completed"] = true
			emit_signal("education_completed")
			if sim != null:
				sim.authority = mini(100, sim.authority + 20)
				sim.loyalty = mini(100, sim.loyalty + 15)

	result["status"] = status
	return result

## 세자 점수 직접 설정 (세이브 복원 등)
func set_progress(val: float) -> void:
	progress = clampf(val, 0.0, 100.0)
	CityStats.set_crown_prince_education(int(progress))
	update_stage_if_needed()
	emit_signal("education_progress_updated", progress)
	emit_signal("education_progress_changed", progress, current_stage)
	if progress >= 100.0:
		status = EducationStatus.COMPLETED
