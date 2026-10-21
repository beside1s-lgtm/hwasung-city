extends Node
class_name TrialManager

## [화성유수부 원옥(寃獄) 친국·명판결 시스템 코어 컨트롤러]
## 1. 계절별(매 턴) 1회 송사 판결 기회 제공:
##    - has_resolved_trial_this_turn 플래그로 턴당 1회 제한.
##    - 미해결 시 다음 턴으로 이월되며, 턴 시작 시 알림 배너 발화.
## 2. 흠휼사상 기반 판결 집행 및 스탯 반영 (왕권, 민심, 충성도/재정 ±5 가드)
## 3. 세이브/로드 완벽 지원 및 널세이프 폴백.

signal trial_case_ready(case_data: Dictionary)
signal trial_resolved(case_data: Dictionary, choice_index: int, verdict_result: Dictionary)
signal notice(msg: String, icon: String)

var sim: SimulationCore = null
var current_case: Dictionary = {}
var has_resolved_trial_this_turn: bool = false
var solved_case_ids: Array[String] = []
var pending_case_id: String = ""
var audio_sys: AudioSystem = null
var trial_popup = null # TrialPopup 인스턴스 참조
const UNHEARD_LOYALTY_LOSS: int = 1 # 판결 못 한 송사를 넘긴 계절마다 민심 감소

func setup(p_sim: SimulationCore, p_audio: AudioSystem = null) -> void:
	sim = p_sim
	audio_sys = p_audio
	if sim:
		# 송사는 계절마다(1턴 = 1개월이므로 계절이 바뀌는 달에만)
		if not sim.season_advanced.is_connected(_on_season_advanced):
			sim.season_advanced.connect(_on_season_advanced)

	# 최초 시작 시 첫 송사 생성
	if current_case.is_empty():
		generate_seasonal_case()

## 계절이 바뀔 때 호출
func _on_season_advanced(_season_index: int, _year: int) -> void:
	# 턴 시작 시 이전 턴 미해결 사건이 있다면 유지하거나, 새로 배정
	var was_resolved: bool = has_resolved_trial_this_turn
	has_resolved_trial_this_turn = false
	if current_case.is_empty() or pending_case_id == "":
		generate_seasonal_case()
	else:
		# PORT-TRACE [송사 적체]: 판결하지 못한 채 계절을 넘기면 원통한 백성 — 민심 -1 (관아가 없으면 송사를 열 수조차 없다)
		if not was_resolved and sim != null:
			sim.loyalty = clampi(sim.loyalty - UNHEARD_LOYALTY_LOSS, 0, 100)
			sim.state_updated.emit(sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)
			if SunlacheongManager.gwana_built:
				emit_signal("notice", "[원통한 백성] 지난 계절의 송사를 판결하지 않아 원성이 쌓입니다. (민심 -%d)" % UNHEARD_LOYALTY_LOSS, "⚖️")
			else:
				emit_signal("notice", "[원통한 백성] 고을에 관아가 없어 송사를 들어줄 곳이 없습니다. 관아를 지으십시오. (민심 -%d)" % UNHEARD_LOYALTY_LOSS, "⚖️")
		# 미처리 사건 알림 재발화
		emit_signal("trial_case_ready", current_case)
		if SunlacheongManager.gwana_built:
			emit_signal("notice", "화성유수부에 미결된 백성의 송사가 대기 중입니다. 공형청에서 친국하십시오.", "⚖️")

## 계절별 신규 사건 생성
func generate_seasonal_case() -> Dictionary:
	var turn_num: int = sim.turn if sim else 1
	var picked: Dictionary = TrialCaseDatabase.pick_seasonal_case(turn_num, solved_case_ids)
	current_case = picked
	pending_case_id = str(picked.get("id", ""))
	emit_signal("trial_case_ready", current_case)
	if SunlacheongManager.gwana_built:
		emit_signal("notice", "계절 송사가 당도하였습니다. 화성유수부에서 백성의 원통함을 살피십시오.", "⚖️")
	else:
		emit_signal("notice", "백성이 송사를 아뢰려 하나 고을에 관아가 없습니다. 관아를 지어야 송사를 열 수 있습니다.", "⚖️")
	return current_case

## 현재 심리 가능한 사건이 있는지 여부
func has_pending_trial() -> bool:
	return not has_resolved_trial_this_turn and not current_case.is_empty()

## 현재 활성 사건 반환
func get_current_case() -> Dictionary:
	if current_case.is_empty() and pending_case_id != "":
		current_case = TrialCaseDatabase.get_case_by_id(pending_case_id)
	if current_case.is_empty():
		generate_seasonal_case()
	return current_case

## 판결 실행
func apply_verdict(choice_index: int) -> Dictionary:
	var c_data: Dictionary = get_current_case()
	if c_data.is_empty():
		return {"success": false, "message": "심리 중인 사건이 없습니다."}

	if has_resolved_trial_this_turn:
		return {"success": false, "message": "이번 계절에는 이미 송사를 판결하였습니다. 다음 계절에 다시 열립니다."}

	var choices: Array = c_data.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return {"success": false, "message": "유효하지 않은 판결 번호입니다."}

	var choice: Dictionary = choices[choice_index]

	# 1. 스탯 변동치 적용 (최대 ±5 제한 엄수)
	var delta_royal: int = clampi(int(choice.get("royal_power", 0)), -5, 5)
	var delta_loyalty: int = clampi(int(choice.get("loyalty", 0)), -5, 5)
	var delta_gold: int = int(choice.get("gold", 0))
	var delta_rice: int = int(choice.get("rice", 0))

	# CityStats 및 SimulationCore 반영
	# 왕권의 원본은 sim.authority — CityStats만 바꾸면 화면 수치가 그대로였다
	if delta_royal != 0:
		if sim:
			sim.add_royal_authority(delta_royal)
		else:
			CityStats.add_royal_power(delta_royal)

	if sim:
		if delta_loyalty != 0:
			sim.loyalty = clampi(sim.loyalty + delta_loyalty, 0, 100)
		if delta_gold != 0:
			sim.gold = maxi(0, sim.gold + delta_gold)
		if delta_rice != 0:
			sim.rice = maxi(0, sim.rice + delta_rice)
		sim.state_updated.emit(sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)

	# 2. 판결봉 효과음 및 완료 처리
	if audio_sys:
		audio_sys.play("gavel")

	has_resolved_trial_this_turn = true
	var case_id: String = str(c_data.get("id", ""))
	if case_id != "" and not (case_id in solved_case_ids):
		solved_case_ids.append(case_id)

	var verdict_text: String = str(choice.get("verdict_text", "판결이 집행되었습니다."))
	var result_data: Dictionary = {
		"success": true,
		"case_id": case_id,
		"title": c_data.get("title", ""),
		"choice_type": choice.get("type", "normal"),
		"delta_royal": delta_royal,
		"delta_loyalty": delta_loyalty,
		"delta_gold": delta_gold,
		"delta_rice": delta_rice,
		"verdict_text": verdict_text
	}

	# 사건 해결 완료 알림
	emit_signal("trial_resolved", c_data, choice_index, result_data)

	# 사건 슬롯 비우기 (다음 턴에 새 사건 배정)
	current_case = {}
	pending_case_id = ""

	return result_data

## 팝업 열기 요청
func open_trial_ui() -> void:
	if not SunlacheongManager.gwana_built:
		emit_signal("notice", "고을에 관아가 없어 송사를 열 수 없습니다. 관아(2×2)를 먼저 지으십시오.", "⚖️")
		return
	if trial_popup != null and trial_popup.has_method("open_trial"):
		var c_data: Dictionary = get_current_case()
		trial_popup.open_trial(c_data, has_resolved_trial_this_turn)

## 직렬화 (SaveSystem 연동)
func serialize() -> Dictionary:
	return {
		"has_resolved_trial_this_turn": has_resolved_trial_this_turn,
		"pending_case_id": pending_case_id,
		"solved_case_ids": solved_case_ids
	}

## 역직렬화 (SaveSystem 연동)
func deserialize(data: Dictionary) -> void:
	has_resolved_trial_this_turn = bool(data.get("has_resolved_trial_this_turn", false))
	pending_case_id = str(data.get("pending_case_id", ""))
	solved_case_ids.clear()
	var raw_solved = data.get("solved_case_ids", [])
	if raw_solved is Array:
		for s in raw_solved:
			solved_case_ids.append(str(s))
	if pending_case_id != "":
		current_case = TrialCaseDatabase.get_case_by_id(pending_case_id)
	else:
		current_case = {}
