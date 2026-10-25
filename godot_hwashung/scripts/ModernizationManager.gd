extends Node
class_name ModernizationManager

## 1820 근대화 시대 (포스트 엔드게임)
## - 11·12번 긍정 엔딩 뒤 [근대화 시작]을 고르면 1820년(순조 20년) 1월부터 이어서 진행한다.
## - 1턴 = 1개월, 계절 변화는 본편과 동일하게 유지한다.
## - 열강 침공: 매년 1월 확률 판정. 확률 = 50% - 외교 신뢰도×4.5% (신뢰도 0 → 50%, 10 → 5%).
##   침공국은 동맹국이 아닌 나라 중 외교를 한 번도 성공하지 못한 나라가 먼저.
##   침공력 = 400 + 경과 연수×15 ± 30. 아군 = 성곽 방호 + 장용영/신식군대(전사자 제외) + 순라청 + 동맹 원군(국당 500).
##   패배 시 식민지화 엔딩(일본이면 일본 침략 엔딩).
## - 역사 사건: 1875년 일본 대규모 침공(침공력 2배), 1876년 일본 조약 회담(문답 10개, 하나라도 틀리면 일본 침략 엔딩).
## - 국제외교 회담(삼남 교역 자리의 [외교] 버튼·사대문): 첫 침공 격퇴 후 해금, 3턴당 1회. 성공 1회마다 외교 신뢰도 +1(최대 10).
## - 동맹: 신뢰도 10이면 나라를 골라 협상(문답 3개). 최대 5개국, 연합국·추축국 동시 동맹 불가.
##   동맹국은 매년 5% 확률로 침략당해 파병을 요청한다. 파병을 거부하면 동맹 파기 + 신뢰도 -5.
##   파병 전투는 양측 군사력 차이로 승률(10~90%)을 정하고, 승패에 따라 보낸 군사 일부 또는 전부를 잃는다.
## - 서학 진척도(0~100): 근대 과학 5개 분야 게이지 평균. 연구 중인 분야만 매 턴 찬다(실학 연구 방식).
##   속도 배율 = 1 + 서양 서적(권당 +0.5) + 유학 다녀온 인재(학문 능력×0.4), 최대 10배
##   → 버프 없음 50년, 최대 버프 5년.

signal notice(msg: String, icon: String)

const START_YEAR := 1820
const CLEARED_SAVE_PATH := "user://save_1800_cleared.json"
const POSITIVE_ENDINGS := ["DEFENSE_FORTRESS", "TRUE_RENAISSANCE"]
const DIPLOMACY_COOLDOWN_TURNS := 3
const MAX_TRUST := 10
const MAX_ALLIES := 5
const ALLY_REINFORCEMENT := 500
const ALLY_INVADED_CHANCE := 0.05
const TRUST_PENALTY_BETRAYAL := 5
const CASUALTY_RECOVERY_PER_YEAR := 50
const JAPAN_INVASION_YEAR := 1875
const JAPAN_TREATY_YEAR := 1876
const GAPSIN_YEAR := 1884
const FINAL_YEAR := 1945
const IMO_REBEL_POWER := 1000
const INVASION_HERITAGE_DAMAGE := 8.0
const SINO_JAPANESE_WAR_HERITAGE_DAMAGE := 30.0

## 근대 과학 연구 분야 (각 게이지 0~100)
const FIELDS := [
	{"id": "gunnery", "name": "서양 포술·탄도학", "desc": "신식 대포와 탄도 계산법", "effect": "신식군대 국방력 +80"},
	{"id": "chemistry", "name": "화학·제련", "desc": "화약 개량과 강철 제련", "effect": "국방력 +50"},
	{"id": "steam", "name": "증기기관·기계학", "desc": "증기 동력과 기계 공작", "effect": "매달 국고 +3,000냥"},
	{"id": "medicine", "name": "서양 의학·종두법", "desc": "우두 접종과 해부학", "effect": "민심 +10"},
	{"id": "survey", "name": "천문·측량·지리학", "desc": "세계 지도와 정밀 측량", "effect": "외교 성공률 +5%"},
]
## PORT-TRACE [근대 의학 4분야]: 사용자 요청 — "예방접종·현미경(미생물학)·해부학·공중위생학을 연구해 각각 인구 부양력 +10%".
## [서양 의학·종두법]을 마치면 열린다. 연구 방식·비용·속도는 위 분야와 같고, 서학 진척도(5분야 평균)에는 들지 않는다.
## 부양력 배율은 건물 개편(석조·다층) 배율에 곱해진다(TaxManager.get_population_cap).
const MEDICAL_FIELDS := [
	{"id": "vaccination", "name": "예방접종(우두 보급)", "desc": "우두를 온 백성에게 접종해 천연두를 막음", "effect": "인구 부양력 +10%"},
	{"id": "microbiology", "name": "현미경·미생물학", "desc": "병원균을 찾아내 전염병을 막음", "effect": "인구 부양력 +10%"},
	{"id": "anatomy", "name": "해부학·외과", "desc": "몸의 구조를 밝혀 수술로 목숨을 살림", "effect": "인구 부양력 +10%"},
	{"id": "hygiene", "name": "공중위생학", "desc": "검역·청결·상하수도로 도시 질병을 줄임", "effect": "인구 부양력 +10%"},
]
const MEDICAL_POP_BONUS := 0.10
const RESEARCH_TURN_COST := 10000
const FIELD_BASE_GAIN := 100.0 / 120.0 # 배율 1일 때 분야 하나 10년(120턴) → 5분야 50년
const MAX_SPEED_MULT := 10.0
const BOOK_COST := 10000
const BOOK_BONUS := 0.5
const MAX_BOOKS := 3
const STUDY_COST := 10000
const STUDY_TURNS := 12
const MAX_STUDENTS := 3
const STUDY_ABILITY_FACTOR := 0.4 # 인재 학문 능력(acad 0~10) × 0.4

static var instance: ModernizationManager = null

var sim: SimulationCore
var grid: GameGrid
var time_manager: TimeManager
var court: CourtSystem

var active: bool = false
var trust: int = 0                  # 외교 신뢰도 0~10
var allies: Array = []              # 동맹국 id (ModernDiplomacyData.NATIONS)
var engaged: Dictionary = {}        # 외교를 성공한 적 있는 나라 id -> true
var army_casualties: int = 0        # 파병·전투로 잃은 군사력(해마다 50씩 회복)
var japan_1875_done: bool = false
var treaty_1876_done: bool = false
var last_year_event: int = 0        # 연간 사건을 마지막으로 처리한 해
var imo_done: bool = false          # 임오군란(연무대 군사기지 개편 때 1회)
var gapsin_checked: bool = false    # 1884년 갑신정변 조건 검사 완료
var sino_japanese_war_year: int = 0 # 갑신정변 수습 실패 뒤 청일전쟁이 터지는 해(0 = 없음)
var _event_queue: Array = []        # 같은 달에 겹친 사건 팝업을 차례로 띄운다
var _imo_queued: bool = false       # 임오군란이 이미 줄에 서 있음(저장 안 함)
var invasions_repelled: int = 0
var diplomacy_unlocked: bool = false
var last_diplomacy_turn: int = -999
var modern_weapon_bonus: int = 0   # 신식 무기(외교 보상) 누적 국방력
var acceleration_bonus: float = 0.0 # 외교 '근대화 가속' 보상: 연구 속도 배율 가산
var field_progress: Dictionary = {} # 분야 id -> 0~100
var current_field: String = ""
var research_paused: bool = false   # 국고 부족으로 멈춤
var books_bought: int = 0
var students: Dictionary = {}       # 인재 key -> {"return_turn": int, "acad": int}
var last_result: String = ""
var diplomacy_successes: int = 0    # 외교 회담 성공 횟수(도시 변천 가속 점수)
var _emergency_layer: CanvasLayer = null

func _init() -> void:
	name = "ModernizationManager"
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup(s: SimulationCore, g: GameGrid, t: TimeManager, c: CourtSystem) -> void:
	sim = s
	grid = g
	time_manager = t
	court = c
	ModernizationManager.instance = self
	if not sim.turn_advanced.is_connected(_on_turn):
		sim.turn_advanced.connect(_on_turn)

static func is_positive_ending(ending_data: Dictionary) -> bool:
	return String(ending_data.get("type", "")) in POSITIVE_ENDINGS

static func is_active() -> bool:
	return instance != null and instance.active

# ==================== 근대화 시작 ====================

## 1800년 엔딩 시점 세이브를 따로 보관한 뒤 1820년 1월로 넘어간다.
func start_modernization() -> void:
	if active:
		return
	SaveSystem.save_game_to_path(CLEARED_SAVE_PATH, sim, grid)
	active = true
	if time_manager:
		time_manager.jump_to_year(START_YEAR)
		sim.current_year = time_manager.current_year
		sim.turn = time_manager.get_total_months() + 1
		CityStats.current_game_turn = sim.turn
		time_manager.set_speed(TimeManager.SpeedMode.NORMAL)
	if UrbanEvolutionManager.instance:
		UrbanEvolutionManager.instance.on_modernization_started()
	last_year_event = START_YEAR # 진입한 해(1820년)는 침공 판정을 건너뛴다
	_refresh_panels()
	emit_signal("notice", "1820년(순조 20년), 근대화의 거센 물결이 밀려옵니다. 열강의 침공에 대비하십시오!", "🌊")

func _refresh_panels() -> void:
	var main := get_parent()
	if main and "panels" in main and main.panels:
		main.panels.refresh_modern_labels()

# ==================== 서학 진척도·국방력 ====================

## 서학 진척도(0~100) = 근대 과학 5분야 게이지 평균
func western_progress() -> int:
	var total := 0.0
	for f in FIELDS:
		total += float(field_progress.get(f["id"], 0.0))
	return clampi(int(total / float(FIELDS.size())), 0, 100)

func field_done(id: String) -> bool:
	return float(field_progress.get(id, 0.0)) >= 100.0

## 의학 4분야는 [서양 의학·종두법]을 마쳐야 착수할 수 있다
func medical_unlocked() -> bool:
	return field_done("medicine")

static func is_medical_field(id: String) -> bool:
	for f in MEDICAL_FIELDS:
		if f["id"] == id:
			return true
	return false

## 의학 분야로 늘어난 인구 부양력 배율(1.0 ~ 1.4). 근대화 전이면 1.0
static func medical_pop_mult() -> float:
	if not is_active():
		return 1.0
	var n := 0
	for f in MEDICAL_FIELDS:
		if instance.field_done(f["id"]):
			n += 1
	return 1.0 + MEDICAL_POP_BONUS * n

func is_studying(key: String) -> bool:
	return students.has(key) and sim.turn < int(students[key]["return_turn"])

## 연구 속도 배율 = 1 + 서적 + 귀국한 유학생 능력 + 외교 가속, 최대 10배
func speed_mult() -> float:
	var m := 1.0 + books_bought * BOOK_BONUS + acceleration_bonus
	if UrbanEvolutionManager.instance and UrbanEvolutionManager.instance.has_university():
		m += 1.0
	for k in students:
		if not is_studying(k):
			m += float(students[k]["acad"]) * STUDY_ABILITY_FACTOR
	return minf(m, MAX_SPEED_MULT)

## 유학 보낼 수 있는 인재 목록 [{key,name,acad}]
func study_candidates() -> Array:
	var out: Array = []
	for id in CourtSystem.SCHOLARS:
		var sc: Dictionary = CourtSystem.SCHOLARS[id]
		if int(sc["acad"]) > 0 and sim.retainers.get(sc["key"], false):
			out.append({"key": sc["key"], "name": sc["name"], "acad": int(sc["acad"])})
	return out

func start_field(id: String) -> bool:
	if field_done(id) or (is_medical_field(id) and not medical_unlocked()):
		return false
	current_field = id
	research_paused = false
	return true

func buy_books() -> bool:
	if books_bought >= MAX_BOOKS or sim.gold < BOOK_COST:
		return false
	sim.gold -= BOOK_COST
	books_bought += 1
	return true

func send_abroad(key: String, nm: String, acad: int) -> bool:
	if students.has(key) or students.size() >= MAX_STUDENTS or sim.gold < STUDY_COST:
		return false
	sim.gold -= STUDY_COST
	students[key] = {"return_turn": sim.turn + STUDY_TURNS, "acad": acad, "name": nm}
	return true

func _process_research() -> void:
	for k in students:
		if int(students[k]["return_turn"]) == sim.turn:
			emit_signal("notice", "%s이(가) 서양 유학을 마치고 돌아왔습니다! 서학 연구 속도가 빨라집니다." % String(students[k].get("name", "유학생")), "🎓")
	if field_done("steam"):
		sim.gold += 3000
	if current_field == "":
		return
	if sim.gold < RESEARCH_TURN_COST:
		research_paused = true
		return
	research_paused = false
	sim.gold -= RESEARCH_TURN_COST
	var v := minf(100.0, float(field_progress.get(current_field, 0.0)) + FIELD_BASE_GAIN * speed_mult())
	field_progress[current_field] = v
	if v >= 100.0:
		_apply_field_effect(current_field)
		for f in FIELDS + MEDICAL_FIELDS:
			if f["id"] == current_field:
				emit_signal("notice", "근대 과학 [%s] 연구를 마쳤습니다! (%s)" % [f["name"], f["effect"]], "🔬")
		current_field = ""

func _apply_field_effect(id: String) -> void:
	match id:
		"gunnery": modern_weapon_bonus += 80
		"chemistry": modern_weapon_bonus += 50
		"medicine": sim.loyalty = mini(100, sim.loyalty + 10)

func patrol_count() -> int:
	return grid.count_buildings("patrol") if grid else 0

## 아군 국방력 = 성곽 방호 + 장용영/신식군대 + 순라청
func defense_power() -> int:
	var walls: int = CityStats.get_fortress_defense_power()
	var army: int = army_power()
	var per: int = UrbanEvolutionManager.instance.patrol_defense_per_station() if UrbanEvolutionManager.instance else 30
	var patrol: int = patrol_count() * per
	return walls + army + patrol

## 장용영/신식군대(파병·전투 전사자 제외) — 파병할 수 있는 군사력이기도 하다
func army_power() -> int:
	return maxi(0, CityStats.get_military_attack_power() + modern_weapon_bonus - army_casualties)

func ally_reinforcement() -> int:
	return allies.size() * ALLY_REINFORCEMENT

## 1년 침공 확률: 신뢰도 0 → 50%, 10 → 5% (비례)
func invasion_chance() -> float:
	return 0.50 - 0.045 * float(clampi(trust, 0, MAX_TRUST))

func invasion_power() -> int:
	var years: int = maxi(0, sim.current_year - START_YEAR)
	return 400 + years * 15 + randi_range(-30, 30)

# ==================== 열강 침공·연간 사건 ====================

func _on_turn(_turn: int, _season: int, _year: int) -> void:
	if not active:
		return
	_process_research()
	var y: int = time_manager.current_year if time_manager else sim.current_year
	if time_manager and time_manager.current_month == 1 and y > last_year_event:
		last_year_event = y
		_yearly_events(y)

## 다른 관리자(정치체제)가 연간 사건 팝업을 줄에 세운다
func queue_event(ev: Callable) -> void:
	_event_queue.append(ev)

func after_event() -> void:
	_after_event()

## 매년 1월: 1945 결산 → 전사자 회복 → 역사 사건(갑신정변·청일전쟁·정치체제·일본) / 무작위 침공 → 동맹국 피침
func _yearly_events(y: int) -> void:
	if y >= FINAL_YEAR:
		_event_queue.clear()
		_final_1945()
		return
	army_casualties = maxi(0, army_casualties - CASUALTY_RECOVERY_PER_YEAR)
	if y >= GAPSIN_YEAR and not gapsin_checked:
		if allies.size() == 1 and allies[0] == "qing":
			_event_queue.append(_open_gapsin) # 결과가 나면 gapsin_checked = true
		else:
			gapsin_checked = true
	# 임오군란 도중 저장·불러오기를 했으면 다시 연다
	if UrbanEvolutionManager.instance and UrbanEvolutionManager.instance.military_base and not imo_done and not _imo_queued:
		_imo_queued = true
		_event_queue.append(_open_imo_mutiny)
	if sino_japanese_war_year > 0 and y >= sino_japanese_war_year:
		sino_japanese_war_year = 0
		_event_queue.append(_resolve_sino_japanese_war)
	if ModernPoliticsManager.instance:
		ModernPoliticsManager.instance.yearly(y)
	if y >= JAPAN_INVASION_YEAR and not japan_1875_done:
		_event_queue.append(func(): _resolve_invasion("japan", 2.0, "1875년 일본 대규모 침공"))
	elif y >= JAPAN_TREATY_YEAR and not treaty_1876_done:
		_event_queue.append(_open_treaty_1876)
	elif randf() < invasion_chance():
		var attacker := _pick_invader()
		if attacker != "":
			_event_queue.append(func(): _resolve_invasion(attacker, 1.0, ""))
	for ally in allies.duplicate():
		if randf() < ALLY_INVADED_CHANCE:
			var a_id: String = ally
			_event_queue.append(func(): _open_ally_invaded(a_id))
	_run_next_event()

func _run_next_event() -> void:
	if _event_queue.is_empty() or not active:
		return
	var ev: Callable = _event_queue.pop_front()
	ev.call()

## 동맹국이 아닌 나라 중 외교를 한 적 없는 나라가 먼저 침략한다
func _pick_invader() -> String:
	var fresh: Array = []
	var others: Array = []
	for id in ModernDiplomacyData.NATIONS:
		if id in allies:
			continue
		if engaged.has(id):
			others.append(id)
		else:
			fresh.append(id)
	var pool := fresh if not fresh.is_empty() else others
	return "" if pool.is_empty() else String(pool[randi() % pool.size()])

func _resolve_invasion(nation: String, mult: float, event_title: String) -> void:
	var power_name := ModernDiplomacyData.nation_name(nation)
	var atk: int = int(float(invasion_power()) * mult)
	var help: int = ally_reinforcement()
	var def: int = defense_power() + help
	_play_bombardment()
	var title_txt := event_title if event_title != "" else "%s의 침공" % power_name
	var help_txt := ("\n동맹 원군 %d개국이 %d의 군사로 도왔습니다." % [allies.size(), help]) if help > 0 else ""
	if def >= atk:
		if nation == "japan" and mult > 1.0:
			japan_1875_done = true
		invasions_repelled += 1
		var h_dmg := INVASION_HERITAGE_DAMAGE * mult
		if UrbanEvolutionManager.instance:
			UrbanEvolutionManager.instance.damage_heritage(h_dmg)
		sim.loyalty = mini(100, sim.loyalty + 10)
		sim.military_power += 15
		var first_unlock := not diplomacy_unlocked
		diplomacy_unlocked = true
		var body := "%s! %s 군대가 화성을 포격했으나 성곽과 군영이 막아냈습니다.\n\n침공력 %d  vs  아군 국방력 %d%s\n\n민심 +10, 국방 위상 +15, 포격으로 문화재 보존도 -%d" % [title_txt, power_name, atk, def, help_txt, int(h_dmg)]
		if first_unlock:
			body += "\n\n국제외교 회담이 해금되었습니다. 정무의 [🌐 외교] 또는 사대문에서 회담을 여십시오."
		_show_emergency_panel("비변사 비상 보고 — 격퇴", body, Color("15803d"), _after_event)
	else:
		var body := "%s! %s 군대의 포화가 성문을 무너뜨렸습니다.\n\n침공력 %d  vs  아군 국방력 %d%s" % [title_txt, power_name, atk, def, help_txt]
		_show_emergency_panel("비변사 비상 보고 — 함락", body, Color("7f1d1d"), func():
			_lose_country(nation)
		)

func _after_event() -> void:
	if time_manager and _event_queue.is_empty():
		time_manager.set_speed(TimeManager.SpeedMode.NORMAL)
	_run_next_event()

func _lose_country(nation: String) -> void:
	_end_with("JAPAN_ANNEXED" if nation == "japan" else "COLONIZED")

# ==================== 역사 사건: 임오군란·갑신정변·청일전쟁 ====================

## 연무대 신식 군사기지 개편 직후: 구식 군대 설득(문답 3개). 실패하면 반란군 1000과 싸운다.
func on_military_base_built() -> void:
	if imo_done or _imo_queued:
		return
	_imo_queued = true
	_event_queue.append(_open_imo_mutiny)
	_run_next_event()

func _open_imo_mutiny() -> void:
	var intro := "연무대가 신식 군사기지로 바뀌자, 차별받던 구식 군대가 들고일어났습니다(임오군란).\n군졸들을 설득하십시오. 한 번이라도 잘못 답하면 반란군 %d이 화성으로 몰려옵니다." % IMO_REBEL_POWER
	var pop := DiplomacyQuizPopup.open(self, "⚔️ 임오군란 — 구식 군대 설득", intro, ModernDiplomacyData.IMO_PERSUADE, Color("b45309"), time_manager,
		func():
			imo_done = true
			sim.loyalty = mini(100, sim.loyalty + 5)
			_show_emergency_panel("임오군란 수습", "밀린 군료를 치르고 구식 군인을 신식 군대로 끌어안았습니다.\n군심이 안정되었습니다. (민심 +5)", Color("15803d"), _after_event),
		func(): _resolve_rebellion())
	pop.piece_on_finish = "imo"

func _resolve_rebellion() -> void:
	var def: int = defense_power()
	_play_bombardment()
	if def >= IMO_REBEL_POWER:
		imo_done = true
		var dmg := 5.0
		if UrbanEvolutionManager.instance:
			UrbanEvolutionManager.instance.damage_heritage(dmg)
		sim.loyalty = maxi(0, sim.loyalty - 5)
		_show_emergency_panel("임오군란 진압", "반란군 %d을(를) 아군 국방력 %d으로 막아 냈습니다.\n싸움 중에 문화재 일부가 부서졌습니다. (문화재 보존도 -%d, 민심 -5)" % [IMO_REBEL_POWER, def, int(dmg)], Color("15803d"), _after_event)
	else:
		_show_emergency_panel("임오군란 — 함락", "반란군 %d이(가) 아군 국방력 %d을 무너뜨리고 화성을 장악했습니다." % [IMO_REBEL_POWER, def], Color("7f1d1d"), func():
			_end_with("IMO_REBELLION"))

## 1884년: 동맹국이 청나라 하나뿐이면 갑신정변. 실패하면 신뢰도 0·청 동맹 파기·수년 안에 청일전쟁.
func _open_gapsin() -> void:
	var intro := "1884년 겨울, 동맹국 청나라의 간섭에 반발한 급진 개화파가 정변을 일으켰습니다(갑신정변).\n사태를 바르게 수습하지 못하면 국제 신뢰를 모두 잃고 청과의 동맹도 깨집니다."
	var pop := DiplomacyQuizPopup.open(self, "🔥 갑신정변", intro, ModernDiplomacyData.GAPSIN, Color("b91c1c"), time_manager,
		func():
			gapsin_checked = true
			trust = mini(MAX_TRUST, trust + 1)
			_show_emergency_panel("갑신정변 수습", "외국 군대를 끌어들이지 않고 정변을 수습했습니다.\n청·일 양국의 간섭을 막아 냈습니다. (외교 신뢰도 +1)", Color("15803d"), _after_event),
		func():
			gapsin_checked = true
			trust = 0
			allies.erase("qing")
			sino_japanese_war_year = (time_manager.current_year if time_manager else sim.current_year) + randi_range(2, 4)
			_show_emergency_panel("갑신정변 — 수습 실패", "정변이 외국 군대의 개입으로 번졌습니다. 국제 신뢰를 모두 잃고 청나라와의 동맹이 깨졌습니다.\n청·일 양국이 조선을 두고 맞서기 시작했습니다. 수년 안에 전쟁이 일어날 것입니다.\n\n외교 신뢰도 → 0", Color("7f1d1d"), _after_event))
	pop.piece_on_finish = "gapsin"

## 청일전쟁: 화성 땅이 전쟁터가 되어 도시 시설 50%가 부서지고 문화재도 크게 다친다(문화재 보수로 복원 가능)
func _resolve_sino_japanese_war() -> void:
	var ruined := 0
	var cands: Array[Vector2i] = []
	for yy in range(grid.size):
		for xx in range(grid.size):
			var t: Dictionary = grid.grid[yy][xx]
			var b: String = String(t.get("building", ""))
			if b == "" or b in ["road", "stone_road", "canal", "ruin", "burned_wasteland"] or UrbanEvolutionManager.is_heritage(t) or bool(t.get("is_ruined", false)):
				continue
			cands.append(Vector2i(xx, yy))
	cands.shuffle()
	@warning_ignore("integer_division")
	for i in range(cands.size() / 2):
		if BuildingManager.ruin_building_at(cands[i], grid, sim):
			ruined += 1
	if UrbanEvolutionManager.instance:
		UrbanEvolutionManager.instance.damage_heritage(SINO_JAPANESE_WAR_HERITAGE_DAMAGE)
	sim.loyalty = maxi(0, sim.loyalty - 15)
	_play_bombardment()
	_show_emergency_panel("청일전쟁 발발", "청과 일본의 군대가 화성 땅에서 맞붙었습니다!\n도시 시설 %d곳이 부서지고, 성곽과 사대문도 포화에 크게 다쳤습니다.\n\n문화재 보존도 -%d, 민심 -15\n[문화재 보수]와 재건으로 도시를 되살리십시오." % [ruined, int(SINO_JAPANESE_WAR_HERITAGE_DAMAGE)], Color("7f1d1d"), _after_event)

# ==================== 1945 결산 ====================

## 근대화 지표 (0~100)
func metric_heritage() -> int:
	return int(round(UrbanEvolutionManager.instance.heritage_condition)) if UrbanEvolutionManager.instance else 0

func metric_urban() -> int:
	var um := UrbanEvolutionManager.instance
	if um == null:
		return 0
	return int(round(float(um.urbanization_rate()) * 0.8 + float(um.water_supply_rate()) * 0.2)) # 도시화율 80% + 상하수도 보급률 20%

func metric_academic() -> int:
	return int(round((float(western_progress()) + float(clampi(CityStats.get_academic_power(), 0, 100))) / 2.0))

func metric_alliance() -> int:
	return int(round(float(allies.size()) / float(MAX_ALLIES) * 100.0))

## 결산 점수 = 문화재 30% + 도시화 25% + 학문 25% + 동맹 20%
func final_score() -> int:
	return int(round(metric_heritage() * 0.30 + metric_urban() * 0.25 + metric_academic() * 0.25 + metric_alliance() * 0.20))

func final_ending_key() -> String:
	var sc := final_score()
	if sc >= 70:
		return "GLOBAL_ADVANCED"
	if sc >= 40:
		return "MIDDLE_TRAP"
	return "UNDERDEVELOPED"

func _final_1945() -> void:
	var key := final_ending_key()
	var caption := "1945년, 화성의 백오십 년.\n문화재 보존도 %d · 도시화율 %d · 학문 %d · 동맹 %d  →  결산 %d점" % [metric_heritage(), metric_urban(), metric_academic(), metric_alliance(), final_score()]
	active = false
	_event_queue.clear()
	ModernEndingSequence.play(get_parent(), caption, func(): EndingManager.trigger_ending(key), key)

func _end_with(key: String) -> void:
	active = false
	_event_queue.clear()
	EndingManager.trigger_ending(key)

# ==================== 1876 일본 조약 회담 ====================

func _open_treaty_1876() -> void:
	var intro := "1876년, 일본 전권대신 구로다 기요타카가 군함을 이끌고 강화도에 나타나 조약 체결을 요구합니다.\n접견대신으로서 일본의 요구를 하나하나 받아치십시오. 한 번이라도 잘못 답하면 일본에 나라를 넘겨주게 됩니다."
	var tp := DiplomacyQuizPopup.open(self, "🇯🇵 1876 강화도 회담", intro, ModernDiplomacyData.TREATY_1876, Color("b91c1c"), time_manager,
		func():
			treaty_1876_done = true
			engaged["japan"] = true
			trust = mini(MAX_TRUST, trust + 1)
			_show_emergency_panel("강화도 회담 타결", "불평등 조항을 모두 막아 내고 대등한 조약을 맺었습니다!\n조선은 주권을 지킨 채 치세를 이어 갑니다.\n\n외교 신뢰도 +1", Color("15803d"), _after_event),
		func(): _lose_country("japan"))
	tp.piece_per_question = "treaty_%d"

# ==================== 동맹 ====================

func can_negotiate_alliance(nation: String) -> Dictionary:
	if trust < MAX_TRUST:
		return {"ok": false, "why": "외교 신뢰도 %d/10" % trust}
	if nation in allies:
		return {"ok": false, "why": "이미 동맹"}
	if allies.size() >= MAX_ALLIES:
		return {"ok": false, "why": "동맹 최대 %d개국" % MAX_ALLIES}
	var bloc := ModernDiplomacyData.bloc_of(nation)
	for a in allies:
		if ModernDiplomacyData.bloc_of(a) != bloc:
			return {"ok": false, "why": "%s과(와) 동맹 중이라 불가" % ModernDiplomacyData.BLOC_NAMES[ModernDiplomacyData.bloc_of(a)]}
	if diplomacy_turns_left() > 0:
		return {"ok": false, "why": "다음 외교까지 %d개월" % diplomacy_turns_left()}
	return {"ok": true, "why": ""}

func negotiate_alliance(nation: String, on_done: Callable) -> void:
	if not bool(can_negotiate_alliance(nation)["ok"]):
		return
	last_diplomacy_turn = sim.turn
	var nm := ModernDiplomacyData.nation_name(nation)
	var intro := "%s 공사가 동맹 조건을 내걸었습니다. 상대의 요구에 알맞게 답하십시오. 하나라도 틀리면 협상이 결렬됩니다." % nm
	var ap := DiplomacyQuizPopup.open(self, "🤝 %s 동맹 협상" % nm, intro, ModernDiplomacyData.ALLIANCE[nation], Color("1d4ed8"), time_manager,
		func():
			allies.append(nation)
			engaged[nation] = true
			emit_signal("notice", "%s과(와) 동맹을 맺었습니다! 침략을 받으면 원군 %d이 달려옵니다." % [nm, ALLY_REINFORCEMENT], "🤝")
			on_done.call(),
		func():
			emit_signal("notice", "%s과(와)의 동맹 협상이 결렬되었습니다." % nm, "✖")
			on_done.call())
	ap.piece_on_finish = "ally_%s" % nation

## 동맹국 피침: 파병할 군사력을 정하거나 거부(동맹 파기·신뢰도 -5)
func _open_ally_invaded(nation: String) -> void:
	if not nation in allies:
		_after_event()
		return
	var nm := ModernDiplomacyData.nation_name(nation)
	var ally_pow := randi_range(300, 700)
	var enemy_pow := randi_range(600, 1300)
	var avail := army_power()
	if time_manager:
		time_manager.set_speed(TimeManager.SpeedMode.PAUSE)
	var layer := CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	var body := "동맹국 %s이(가) 침략을 받아 원군을 요청했습니다!\n\n%s 군사력 %d  vs  침략군 %d (차이 %d)\n우리가 보낼 수 있는 군사력: %d\n\n보낸 군사는 싸움 결과에 따라 살아 돌아오거나 전멸할 수 있습니다. 거부하면 동맹이 깨지고 외교 신뢰도가 %d 깎입니다." % [nm, nm, ally_pow, enemy_pow, enemy_pow - ally_pow, avail, TRUST_PENALTY_BETRAYAL]
	var panel := _make_panel(layer, "📯 %s 파병 요청" % nm, body, Color("b45309"))
	var vb: VBoxContainer = panel.get_meta("vbox")
	var lbl := Label.new()
	vb.add_child(lbl)
	var sld := HSlider.new()
	sld.min_value = 0
	sld.max_value = maxi(avail, 1)
	sld.step = 10
	sld.value = mini(avail, maxi(0, enemy_pow - ally_pow + 100))
	sld.custom_minimum_size = Vector2(440, 24)
	vb.add_child(sld)
	var upd := func(v: float):
		lbl.text = "파병 군사력: %d  →  예상 승률 %d%%" % [int(v), int(round(_battle_win_chance(ally_pow + int(v), enemy_pow) * 100.0))]
	sld.value_changed.connect(upd)
	upd.call(sld.value)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	vb.add_child(hb)
	var b_send := Button.new()
	b_send.text = "파병"
	b_send.custom_minimum_size = Vector2(140, 36)
	b_send.disabled = avail <= 0
	hb.add_child(b_send)
	var b_refuse := Button.new()
	b_refuse.text = "거부 (동맹 파기)"
	b_refuse.custom_minimum_size = Vector2(160, 36)
	hb.add_child(b_refuse)
	b_send.pressed.connect(func():
		layer.queue_free()
		var sent := int(sld.value)
		if sent <= 0:
			_betray_ally(nation)
		else:
			_dispatch_battle(nation, ally_pow, enemy_pow, sent)
	)
	b_refuse.pressed.connect(func():
		layer.queue_free()
		_betray_ally(nation)
	)

## 승률: 군사력 차이 비율로 10~90% — 약해도 이길 수 있지만 크게 뒤집히지는 않는다
static func _battle_win_chance(ours: int, theirs: int) -> float:
	var big := float(maxi(maxi(ours, theirs), 1))
	return clampf(0.5 + 0.4 * float(ours - theirs) / big, 0.1, 0.9)

func _dispatch_battle(nation: String, ally_pow: int, enemy_pow: int, sent: int) -> void:
	var nm := ModernDiplomacyData.nation_name(nation)
	var win := randf() < _battle_win_chance(ally_pow + sent, enemy_pow)
	var loss_rate := randf_range(0.0, 0.3) if win else randf_range(0.5, 1.0)
	if not win and loss_rate > 0.9:
		loss_rate = 1.0 # 전멸
	var lost := int(round(float(sent) * loss_rate))
	army_casualties += lost
	var body := ""
	if win:
		trust = mini(MAX_TRUST, trust + 1)
		body = "%s과(와) 함께 침략군을 물리쳤습니다!\n\n파병 %d 중 %d 전사, %d 생환.\n외교 신뢰도 +1" % [nm, sent, lost, sent - lost]
	elif lost >= sent:
		body = "%s 원정군이 패하여 파병한 군사 %d이(가) 전멸했습니다.\n동맹은 유지됩니다." % [nm, sent]
	else:
		body = "%s 원정군이 패했습니다.\n\n파병 %d 중 %d 전사, %d 생환.\n동맹은 유지됩니다." % [nm, sent, lost, sent - lost]
	_show_emergency_panel("파병 결과", body, Color("15803d") if win else Color("7f1d1d"), _after_event)

func _betray_ally(nation: String) -> void:
	allies.erase(nation)
	trust = maxi(0, trust - TRUST_PENALTY_BETRAYAL)
	_show_emergency_panel("동맹 파기", "%s의 파병 요청을 거절하여 동맹이 깨졌습니다.\n국제 사회의 신뢰를 잃었습니다. (외교 신뢰도 -%d)" % [ModernDiplomacyData.nation_name(nation), TRUST_PENALTY_BETRAYAL], Color("7f1d1d"), _after_event)

## 군대 스폰 없이 포격 섬광 + 포성만
func _play_bombardment() -> void:
	var main := get_parent()
	if main and "audio" in main and main.audio:
		main.audio.play_limited("cannon")
	if DisplayServer.get_name() == "headless":
		return
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1.0, 0.55, 0.15, 0.0)
	layer.add_child(flash)
	var tw := create_tween()
	for i in range(3):
		tw.tween_property(flash, "color:a", 0.45, 0.08)
		tw.tween_property(flash, "color:a", 0.0, 0.35)
	tw.tween_callback(layer.queue_free)

func _show_emergency_panel(title: String, body: String, col: Color, on_close: Callable = Callable()) -> void:
	if _emergency_layer and is_instance_valid(_emergency_layer):
		_emergency_layer.queue_free()
	var prev_speed: int = time_manager.current_speed if time_manager else TimeManager.SpeedMode.NORMAL
	if time_manager:
		time_manager.set_speed(TimeManager.SpeedMode.PAUSE)
	_emergency_layer = CanvasLayer.new()
	_emergency_layer.layer = 95
	add_child(_emergency_layer)
	var panel := _make_panel(_emergency_layer, title, body, col)
	var btn := Button.new()
	btn.text = "확인"
	btn.custom_minimum_size = Vector2(120, 34)
	panel.get_meta("vbox").add_child(btn)
	var layer_ref := _emergency_layer
	btn.pressed.connect(func():
		layer_ref.queue_free()
		if on_close.is_valid():
			on_close.call()
		elif time_manager:
			time_manager.set_speed(prev_speed as TimeManager.SpeedMode)
	)

## 공용 패널(제목·본문). 반환 패널의 meta "vbox"에 버튼을 붙인다.
static func _make_panel(parent: Node, title: String, body: String, col: Color) -> PanelContainer:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	parent.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1c1917")
	sb.border_color = col
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var lt := Label.new()
	lt.text = title
	lt.add_theme_font_size_override("font_size", 20)
	lt.add_theme_color_override("font_color", col.lightened(0.35))
	lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(lt)
	var lb := Label.new()
	lb.text = body
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.custom_minimum_size = Vector2(440, 0)
	vb.add_child(lb)
	panel.set_meta("vbox", vb)
	return panel

# ==================== 근대화 선택 팝업 ====================

## 긍정 엔딩 에필로그를 닫은 뒤 호출. [근대화 시작] / [마치기]
func offer_modernization() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 96
	add_child(layer)
	var body := "1800년 화성의 기초를 다진 조선은 격동의 19세기를 맞이합니다. 1820년, 근대화의 거센 물결을 마주하시겠습니까?"
	var panel := _make_panel(layer, "격동의 19세기", body, Color("b8860b"))
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	panel.get_meta("vbox").add_child(hb)
	var b_start := Button.new()
	b_start.text = "근대화 시작"
	b_start.custom_minimum_size = Vector2(140, 36)
	hb.add_child(b_start)
	var b_end := Button.new()
	b_end.text = "마치기"
	b_end.custom_minimum_size = Vector2(140, 36)
	hb.add_child(b_end)
	b_start.pressed.connect(func():
		layer.queue_free()
		start_modernization()
	)
	b_end.pressed.connect(layer.queue_free)

# ==================== 사대문 국제외교 ====================

static func is_great_gate(title: String) -> bool:
	for g in ["장안문", "팔달문", "창룡문", "화서문"]:
		if title.contains(g):
			return true
	return false

func diplomacy_turns_left() -> int:
	return maxi(0, last_diplomacy_turn + DIPLOMACY_COOLDOWN_TURNS - sim.turn)

func diplomacy_success_rate() -> float:
	var r := 0.40 + float(western_progress()) / 100.0 * 0.35 + float(CityStats.get_academic_power()) / 100.0 * 0.15
	if field_done("survey"):
		r += 0.05
	return minf(r, 1.0)

## 회담 실행. 결과 문구를 돌려준다.
func hold_summit() -> Dictionary:
	if not diplomacy_unlocked or diplomacy_turns_left() > 0:
		return {}
	last_diplomacy_turn = sim.turn
	var nation_id: String = ModernDiplomacyData.NATIONS.keys()[randi() % ModernDiplomacyData.NATIONS.size()]
	var nation := ModernDiplomacyData.nation_name(nation_id)
	var rate := diplomacy_success_rate()
	if randf() >= rate:
		return {"ok": false, "nation": nation, "rate": rate, "msg": "%s과(와)의 회담이 결렬되었습니다." % nation}
	diplomacy_successes += 1
	trust = mini(MAX_TRUST, trust + 1)
	engaged[nation_id] = true
	var msg := ""
	match randi() % 3:
		0:
			sim.gold += 20000
			msg = "%s으로부터 차관 20,000냥을 들여왔습니다." % nation
		1:
			modern_weapon_bonus += 50
			msg = "%s의 신식 무기를 들여와 국방력이 50 올랐습니다." % nation
		_:
			acceleration_bonus += 1.0
			msg = "%s과(와) 기술 교류 협정을 맺어 근대화가 가속됩니다. (서학 연구 속도 +1배)" % nation
	return {"ok": true, "nation": nation, "rate": rate, "msg": msg}

# ==================== 저장 ====================

func serialize() -> Dictionary:
	return {
		"active": active,
		"trust": trust,
		"allies": allies.duplicate(),
		"engaged": engaged.duplicate(),
		"army_casualties": army_casualties,
		"japan_1875_done": japan_1875_done,
		"treaty_1876_done": treaty_1876_done,
		"last_year_event": last_year_event,
		"imo_done": imo_done,
		"gapsin_checked": gapsin_checked,
		"sino_japanese_war_year": sino_japanese_war_year,
		"invasions_repelled": invasions_repelled,
		"diplomacy_unlocked": diplomacy_unlocked,
		"last_diplomacy_turn": last_diplomacy_turn,
		"modern_weapon_bonus": modern_weapon_bonus,
		"acceleration_bonus": acceleration_bonus,
		"field_progress": field_progress.duplicate(),
		"current_field": current_field,
		"books_bought": books_bought,
		"diplomacy_successes": diplomacy_successes,
		"students": students.duplicate(true)
	}

## 근대화 데이터가 없는 (1800년 본편) 저장을 불러오면 기본값으로 돌아간다.
func deserialize(d: Dictionary) -> void:
	active = bool(d.get("active", false))
	trust = int(d.get("trust", 0))
	allies = (d.get("allies", []) as Array).duplicate() if d.get("allies", []) is Array else []
	engaged = (d.get("engaged", {}) as Dictionary).duplicate() if d.get("engaged", {}) is Dictionary else {}
	army_casualties = int(d.get("army_casualties", 0))
	japan_1875_done = bool(d.get("japan_1875_done", false))
	treaty_1876_done = bool(d.get("treaty_1876_done", false))
	last_year_event = int(d.get("last_year_event", START_YEAR))
	_imo_queued = false
	# 저장 전 화면에 떠 있던 사건 창(문답·비상 보고·파병 요청)은 지운다 — 끝나지 않은 사건은 다음 해에 다시 열린다
	for ch in get_children():
		if ch is CanvasLayer:
			ch.queue_free()
	_emergency_layer = null
	imo_done = bool(d.get("imo_done", false))
	gapsin_checked = bool(d.get("gapsin_checked", false))
	sino_japanese_war_year = int(d.get("sino_japanese_war_year", 0))
	_event_queue.clear()
	invasions_repelled = int(d.get("invasions_repelled", 0))
	diplomacy_unlocked = bool(d.get("diplomacy_unlocked", false))
	last_diplomacy_turn = int(d.get("last_diplomacy_turn", -999))
	modern_weapon_bonus = int(d.get("modern_weapon_bonus", 0))
	acceleration_bonus = float(d.get("acceleration_bonus", 0.0))
	field_progress = (d.get("field_progress", {}) as Dictionary).duplicate() if d.get("field_progress", {}) is Dictionary else {}
	current_field = String(d.get("current_field", ""))
	research_paused = false
	books_bought = int(d.get("books_bought", 0))
	diplomacy_successes = int(d.get("diplomacy_successes", 0))
	students = (d.get("students", {}) as Dictionary).duplicate(true) if d.get("students", {}) is Dictionary else {}
	last_result = ""
	_refresh_panels()
