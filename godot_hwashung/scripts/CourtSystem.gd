extends Node
class_name CourtSystem

# PORT-TRACE: src/domain/RetainerManager.ts, src/types.ts (ResearchTech, crownPrince, tigerCrisis,
# hyoryungwon, eulmyoEvent), GameState.ts (resolveTigerCrisis, investCrownPrince,
# studyCrownPrince, visitHyoryungwon), main.ts (호환/세자 이벤트 트리거)
# 이식 로그: docs/godot_port_log.md 항목 P3

signal notice(msg: String)
signal tiger_resolved_event(choice: String, success: bool)

var sim: SimulationCore
var hired_scholars: Dictionary:
	get:
		return ScholarManager.hired_scholars

## id -> SimulationCore.retainers 키 매핑 (기존 4명은 기존 키 유지)
const RETAINER_KEYS := {
	"jeong": "jeong_yakyong", "chae": "chae_jegong", "park": "park_jega", "baek": "baek_dongsu",
	"kim": "kim_hongdo", "seo": "seo_yugu", "guk": "hong_gukyeong", "gu": "gu_seonbok", "hong": "hong_inhan",
	"jo": "jo_simtae", "bau": "kim_bau", "yu": "yu_hanji",
	"kim_josun": "kim_josun", "jeong_beomjo": "jeong_beomjo", "lee_gahwan": "lee_gahwan",
	"lee_seonggil": "lee_seonggil", "musoe": "musoe",
}

const RETAINER_LIST := [
	{"id": "jeong", "name": "다산 정약용", "role": "남인 실학 / 성역 실무", "cost": 200, "desc": "거중기로 성곽 완공 가속, 방호력 강화"},
	{"id": "chae", "name": "번암 채제공", "role": "남인 영수 / 영의정", "cost": 150, "desc": "대역사 공사비 25% 절감, 남인 결집"},
	{"id": "park", "name": "초정 박제가", "role": "북학파 / 검서관", "cost": 180, "desc": "상업 교역량 +20%, 청나라 신기술"},
	{"id": "baek", "name": "야뇌 백동수", "role": "장용영 무예 총관", "cost": 200, "desc": "매달 국방력 +10, 도적 침략 100% 차단"},
	{"id": "kim", "name": "단원 김홍도", "role": "중인 / 도화서 화원", "cost": 120, "desc": "매달 민심 +2, 의궤도 완성"},
	{"id": "seo", "name": "풍석 서유구", "role": "소론 / 농학자", "cost": 160, "desc": "둔전 식량 생산 +25%, 수리 개선"},
	{"id": "guk", "name": "도승지 홍국영", "role": "측근·숙위소 대장", "cost": 220, "desc": "왕권 +15 즉시 (부작용: 매달 민심 -1)"},
	{"id": "gu", "name": "어영대장 구선복", "role": "군부 실세", "cost": 250, "desc": "매달 국방력 +15 (부작용: 군량 -10)"},
	{"id": "hong", "name": "좌의정 홍인한", "role": "노론 척신 / 우의정", "cost": 0, "desc": "국고 +3,000냥 확보 (부작용: 국고 누수 5%, 왕권 -1)"},
	{"id": "jo", "name": "수원부사 조심태", "role": "치수·토목 감동", "cost": 140, "desc": "매달 방재율 +5, 도로 건설비 절감"},
	{"id": "bau", "name": "석수 김바우", "role": "수석 석공 명장", "cost": 130, "desc": "매달 성곽 완공도 +2, 대역사 투입비 절감"},
	{"id": "yu", "name": "명필 유한지", "role": "예서 명필", "cost": 110, "desc": "매달 민심 +1, 왕권 +1"},
	{"id": "kim_josun", "name": "풍고 김조순", "role": "노론 시파 / 규장각 제학", "cost": 180, "desc": "조정 정국 안정, 세자 교육 보조"},
	{"id": "jeong_beomjo", "name": "해좌 정범조", "role": "소론 원로 / 대제학", "cost": 150, "desc": "향교 유생 결집, 왕권 정당성 부여"},
	{"id": "lee_gahwan", "name": "정헌 이가환", "role": "남인 학자 / 공조판서", "cost": 220, "desc": "수학적 축성 정밀도 상승, 천문 역법 교정"},
	{"id": "lee_seonggil", "name": "도편수 이성길", "role": "수석 목수 도편수", "cost": 150, "desc": "화성행궁 및 목조 누각 축조 가속"},
	{"id": "musoe", "name": "가죽공 무쇠", "role": "군수 가죽공 장인", "cost": 100, "desc": "갑옷 및 군장 완비로 방호력 가산"},
]


## 연구 (TS에는 목록만 있고 비용/효과 UI가 없어 Godot에서 비용을 정의)
const RESEARCH_LIST := [
	{"id": "goguma", "name": "조엄의 감저(고구마) 도입", "cost": 1000, "desc": "구황작물 보급 — 군량 소비 37% 감소"},
	{"id": "gwanong", "name": "과농소초 및 통상 개화론", "cost": 1000, "desc": "북학파 상업 무역 및 청나라 농기구 도입 — 식량 생산 +40%"},
	{"id": "seed", "name": "임원경제지·우량 벼 품종", "cost": 1000, "desc": "조선 후기 농정 백과사전 및 둔전 수리 농법 — 식량 생산 +20%"},
	{"id": "fertilizer", "name": "일반 농법(녹비·퇴비 시비법)", "cost": 1000, "desc": "기본 농서 및 백성들의 농업 기술 — 매달 식량 +60"},
	{"id": "reservoir", "name": "만석거 관개 정비", "cost": 1000, "desc": "만석거 수리 시설 확충 및 관개 정비 — 매달 식량 +80"},
	# PORT-TRACE [서학 디버프·연구]: 서학과 유학·정책의 조화
	{"id": "boyuron", "name": "남인 실학자의 보유론(補儒論)", "cost": 1000, "desc": "유교 고전의 상제(上帝)와 서학의 천주를 같이 보아 효제충신을 보완 — 천주교당 왕권 감소 소멸, 민심 +1/달, 학문력 +5"},
	{"id": "segi", "name": "기기도설·거중기·서기수용론", "cost": 1000, "desc": "정학(주자학)을 중심에 두고 서양 기술은 이용후생으로 수용 — 《기하원본》·《기기도설》, 거중기·녹로 실전 배치: 왕권 감소 무효, 서학 인재 연구비 -30%, 대역사 비용 -20%"},
	{"id": "sugusik", "name": "수학적 축성술·천문 역법", "cost": 1000, "desc": "수학·기하학 기반 정밀 성벽 축조 및 측량 — 수문 내구도 및 성곽 방호력 강화"}
]

var research := {"goguma": false, "gwanong": false, "seed": false, "fertilizer": false, "reservoir": false, "boyuron": false, "segi": false, "sugusik": false}


var crown_prince := {"invested": false, "education": 0, "tutor": ""}
var tiger := {"active": false, "solved": false}
var hyoryungwon := {"visited": false, "blessing": false}
var eulmyo := {"active": false, "solved": 0, "done": false}
var milestones := {"wonhaeng1789": false, "eulmyo1795": false}

# 4대 핵심 평가 지표 (세자 교육도, 현륭원 친림 횟수, 탕평도, 성 방호력)
var crown_prince_education: int = 0
var hyeonryungwon_visits: int = 0
var faction_balance_score: int = 50
var fortress_defense_power: int = 0

## PORT-TRACE [시기별 추천·의궤 편찬]: 정조 시대 두 의궤 — 을묘원행의 기록 《원행을묘정리의궤》
## (1797 간행)와 화성 축성의 전 과정을 담은 《화성성역의궤》(1801 간행). 게임이 1800년까지라
## 둘 다 1796년부터 편찬할 수 있게 하고, 앞선 일(원행·축성)을 해야만 펴낼 수 있다.
const UIGWE_LIST := [
	{"id": "wonhaeng", "name": "원행을묘정리의궤(園幸乙卯整理儀軌)", "cost": 300,
		"desc": "1795년 을묘원행(혜경궁 회갑 진찬연·격쟁 판결)의 모든 과정을 정리자 활자로 간행", "auth": 8, "loyal": 5},
	{"id": "seongyeok", "name": "화성성역의궤(華城城役儀軌)", "cost": 400,
		"desc": "화성 축성의 설계도·공사 인부·비용·거중기까지 낱낱이 기록한 공사 보고서", "auth": 12, "loyal": 5},
]
const UIGWE_FROM_YEAR := 1796
var uigwe := {"wonhaeng": false, "seongyeok": false}
var current_year := 1789

func setup(s: SimulationCore) -> void:
	sim = s
	sim.turn_advanced.connect(_on_turn)
	sim.academic_hit.connect(academic_hit)
	crown_prince_education = CityStats.get_crown_prince_education()
	hyeonryungwon_visits = CityStats.get_hyeonryungwon_visits()
	faction_balance_score = CityStats.get_faction_balance_score()
	fortress_defense_power = CityStats.get_fortress_defense_power()
	# 게임 첫머리: 축성의 두 기둥(정약용·채제공)이 이미 천거되어 기다린다(예전엔 처음부터 등용 상태였음)
	for sid: String in ["jeong", "chae"]:
		candidates.append({"id": sid, "turns": 8, "praise": "참된 인재이옵니다! %s" % SCHOLARS[sid]["desc"], "accurate": true, "acc": 100})

func is_hired(id: String) -> bool:
	return sim.retainers.get(RETAINER_KEYS.get(id, id), false)

func toggle_retainer(id: String) -> String:
	var info: Dictionary = {}
	for r in RETAINER_LIST:
		if r["id"] == id:
			info = r
	var key: String = RETAINER_KEYS.get(id, id)
	if sim.retainers.get(key, false):
		sim.retainers[key] = false
		ScholarManager.hired_scholars.erase(key)
		update_faction_and_academic()
		_push()
		return "신하를 해임하였습니다."
	if sim.gold < info["cost"]:
		return "국고가 부족합니다."
	sim.gold -= info["cost"]
	sim.retainers[key] = true
	ScholarManager.hired_scholars[key] = true
	GameProgressManager.unlock_puzzle_piece("people", key) # 역사 사전 퍼즐 조각 해금
	if id == "guk":
		sim.authority = min(100, sim.authority + 15)
	update_faction_and_academic()
	_push()
	return "%s을(를) 조정에 등용하였습니다." % info["name"]

func buy_research(id: String) -> String:
	if research.get(id, false) or (sim and sim.tech_tree and sim.tech_tree.is_completed(id)):
		return "이미 연구를 마쳤습니다."
	for r in RESEARCH_LIST:
		if r["id"] == id:
			var cost := research_cost(int(r["cost"]))
			if sim and sim.tech_tree:
				var res_msg: String = str(sim.tech_tree.start_research(id, sim, cost))
				_push()
				return res_msg
			if sim.gold < cost:
				return "국고가 부족합니다."
			sim.gold -= cost
			research[id] = true
			if id == "boyuron":
				sim.boyuron = true
				sim.academic = mini(100, sim.academic + 5)
				CityStats.set_academic_power(sim.academic)
			elif id == "segi":
				sim.segi_policy = true
			_push()
			return "%s 연구를 완료했습니다." % r["name"]
	return ""


## 턴당 인재/연구 효과. 그리드 수확량(base)에 배율을 적용하고 부가 효과를 sim에 직접 반영. 반환: 보정된 {gold,rice,pop}
func apply_turn_effects(base: Dictionary) -> Dictionary:
	var g: int = int(base.get("gold", 0))
	var r: int = int(base.get("rice", 0))
	var p: int = int(base.get("pop", 0))
	if sim == null or not ("retainers" in sim) or sim.retainers == null:
		return {"gold": g, "rice": r, "pop": p}
	var rt: Dictionary = sim.retainers
	if rt["park_jega"]: g = int(floor(g * 1.4))
	if rt["seo_yugu"]: r = int(floor(r * 1.25))
	if rt["hong_inhan"]:
		# 득: 등용 뒤 4개월간 시전세 +20% / 실: 매달 국고 5% 누수, 왕권 -1
		if hong_boost_turns > 0:
			g = int(floor(g * 1.2))
			hong_boost_turns -= 1
		sim.gold = maxi(0, sim.gold - int(float(sim.gold) * 0.05))
		sim.authority = maxi(0, sim.authority - 1)
	if rt["kim_hongdo"]: sim.loyalty = min(100, sim.loyalty + 2)
	if rt["hong_gukyeong"]: sim.loyalty = max(0, sim.loyalty - 1)
	if rt["baek_dongsu"]: sim.military_power += 10
	if rt["gu_seonbok"]:
		sim.military_power += 15
		r -= 10
	if rt.get("jo_simtae", false): sim.flood_defense = mini(100, sim.flood_defense + 5)
	if rt.get("kim_bau", false): sim.fortress_progress = mini(100, sim.fortress_progress + 2)
	if rt.get("yu_hanji", false):
		sim.loyalty = mini(100, sim.loyalty + 1)
		sim.authority = mini(100, sim.authority + 1)
	# PORT-TRACE [인재 랜덤 풀]: 신규 실학자 효과
	if rt.get("park_jiwon", false): g = int(floor(g * 1.5))          # 연암 박지원: 저잣거리 상업·유통 세수 대폭
	if rt.get("yu_deukgong", false): sim.loyalty = mini(100, sim.loyalty + 1)
	if rt.get("kim_jeonghui", false): sim.loyalty = mini(100, sim.loyalty + 1) # 예술·문화 만족
	if rt.get("sim_hwanji", false):
		sim.authority = maxi(0, sim.authority - 2)  # 벽파 영수 — 왕권 잠식
		sim.loyalty = mini(100, sim.loyalty + 1)    # 득: 노론 사대부 장악 — 양반 반발 억제
	if rt.get("kim_josun", false):
		sim.authority = mini(100, sim.authority + 1) # 조정 정국 안정
	if rt.get("jeong_beomjo", false):
		sim.authority = mini(100, sim.authority + 1) # 향교 유생 결집, 왕권 정당성
	if rt.get("lee_gahwan", false):
		sim.fortress_progress = mini(100, sim.fortress_progress + 1) # 수학적 축성 정밀도
	if rt.get("lee_seonggil", false):
		sim.fortress_progress = mini(100, sim.fortress_progress + 1) # 목수 도편수 축조 가속
	if rt.get("musoe", false):
		sim.military_power += 2 # 군수 갑주 및 군장 보너스
	if rt.get("lee_gigyeong", false):
		sim.academic = maxi(0, sim.academic - 2) # 서학 탄압
		if rt.get("jeong_yakyong", false):
			sim.loyalty = maxi(0, sim.loyalty - 1) # 정약용과 불화
	if research["gwanong"]: r = int(floor(r * 1.4))
	if research["seed"]: r = int(floor(r * 1.2))
	if research["fertilizer"]: r += 60
	if research["reservoir"]: r += 80
	if research["goguma"]:
		# 소비 절감분을 환급 형태로 반영 (Core의 월 소비 로직을 건드리지 않기 위함)
		r += int(floor((sim.population * 0.3 + sim.military_power * 0.1) * 0.37 * 3.0))
	if hyoryungwon["blessing"]:
		sim.loyalty = min(100, sim.loyalty + 1)
	return {"gold": g, "rice": r, "pop": p}

func _on_turn(turn: int, season_index: int, year: int) -> void:
	current_year = year
	_turn_scholars()
	update_faction_balance()
	fortress_defense_power = CityStats.get_fortress_defense_power()
	# PORT-TRACE [시기별 추천·의궤 편찬]: 현륭원 친림은 "금년도" 한 번 — 새해(봄)마다 다시 가능하게.
	# (예전엔 한 번 가면 영영 "이미 금년도 참배를 마쳤다"로 막혔다.)
	var season_start: bool = sim != null and sim.month_now() in [3, 6, 9, 12]
	if season_index == 0 and season_start:
		hyoryungwon["visited"] = false

	# 쿨타임(24개월 = 2년) 만료 시 재출현 가능하도록 상태 해제
	if sim and sim.tiger_cooldown_turns <= 0 and tiger.get("solved", false):
		tiger["solved"] = false

	# 포호(호랑이 출몰): 해마다 한 번(turn % 12 == 6 → 6월) 검사, 퇴치 후 2년(24개월) 쿨타임 동안 출몰 완전 차단
	if turn % 12 == 6 and not tiger["solved"] and not tiger["active"]:
		if year >= 1778 and (sim == null or sim.tiger_cooldown_turns <= 0):
			tiger["active"] = true
			emit_signal("notice", "팔달산 능선에 호환(맹호)이 발생했습니다. 포호책에서 대응하십시오.")

	if year == 1790 and season_index == 0 and season_start and not crown_prince["invested"]:
		emit_signal("notice", "원자(순조)께서 탄생하셨습니다. 세자서연에서 책봉을 결단하십시오.")
	if year >= 1789 and not milestones["wonhaeng1789"]:
		milestones["wonhaeng1789"] = true
		sim.gold = max(0, sim.gold - 300)
		sim.loyalty = min(100, sim.loyalty + 15)
		sim.authority = min(100, sim.authority + 10)
		emit_signal("notice", "1789년 현륭원 원행: 정약용의 배다리로 한강을 건넜습니다. (금 -300, 민심 +15, 왕권 +10)")
	if year >= 1795 and not milestones["eulmyo1795"]:
		milestones["eulmyo1795"] = true
		eulmyo["active"] = true
		emit_signal("notice", "1795년 을묘년 원행: 봉수당진찬연과 격쟁 판결이 열렸습니다.")
	_push()

func resolve_tiger(choice: String) -> String:
	match choice:
		"army":
			if sim.military_power < 60 or sim.rice < 100:
				return "장용영 군사력(최소 60) 또는 군량이 부족합니다."
			sim.rice -= 100
			sim.gold += 500
			sim.authority = min(100, sim.authority + 15)
			sim.loyalty = min(100, sim.loyalty + 20)
			sim.tiger_cooldown_turns = 24 # 퇴치 후 2년(24개월) 안전 쿨타임
			tiger["active"] = false
			tiger["solved"] = true
			_push()
			emit_signal("tiger_resolved_event", "army", true)
			return "착호군이 맹호를 사냥했습니다. (금 +500, 왕권 +15, 민심 +20, 2년간 안전)"
		"clear":
			if sim.gold < 180:
				return "산지 개간 예산이 부족합니다."
			sim.gold -= 180
			sim.rice += 200
			sim.loyalty = min(100, sim.loyalty + 8)
			sim.tiger_cooldown_turns = 24 # 개간 후 2년(24개월) 안전 쿨타임
			tiger["active"] = false
			tiger["solved"] = true
			_push()
			emit_signal("tiger_resolved_event", "clear", true)
			return "산지를 개간해 호랑이 서식지를 농지로 바꾸었습니다. (식량 +200, 민심 +8, 2년간 안전)"
		_:
			if sim.gold < 80:
				return "현상금 재정이 부족합니다."
			sim.gold -= 80
			tiger["active"] = false
			var ok: bool = randf() < 0.6
			if ok:
				sim.loyalty = min(100, sim.loyalty + 10)
				sim.tiger_cooldown_turns = 24 # 사냥 성공 시 2년(24개월) 안전 쿨타임
				tiger["solved"] = true
			else:
				sim.population = max(10, sim.population - 5)
				sim.loyalty = max(0, sim.loyalty - 12)
			_push()
			emit_signal("tiger_resolved_event", "bounty", ok)
			return "명포수가 호랑이를 처치했습니다. (민심 +10, 2년간 안전)" if ok else "포수 실패로 백성이 희생되었습니다. (인구 -5, 민심 -12)"

## 맹수(호랑이·승냥이)가 민가를 습격해 발생하는 호환 재난 위기 트리거
func trigger_tiger_raid_crisis() -> void:
	if not tiger.get("active", false):
		tiger["active"] = true
		tiger["solved"] = false
		emit_signal("notice", "팔달산 맹호와 승냥이가 민가를 습격했습니다! 포호책(포호 대책)을 결단하십시오.")
		_push()


func invest_prince(tutor: String) -> String:
	if crown_prince["invested"]:
		return "이미 세자를 책봉했습니다."
	if sim.gold < 300:
		return "책봉 의식과 시강원 설치를 위한 국고(300냥)가 부족합니다."
	sim.gold -= 300
	crown_prince["invested"] = true
	crown_prince["tutor"] = tutor
	crown_prince["education"] = maxi(0, int(crown_prince.get("education", 0)))
	crown_prince_education = int(crown_prince["education"])
	CityStats.set_crown_prince_education(crown_prince_education)
	sim.authority = max(0, sim.authority - 5)
	sim.loyalty = min(100, sim.loyalty + 10)
	_push()
	return "원자를 세자로 책봉하고 시강원 서연을 시작했습니다."

func study_prince() -> String:
	if not crown_prince["invested"]:
		return "먼저 세자를 책봉해야 합니다."
	if crown_prince["education"] >= 100:
		return "세자께서 이미 제왕학을 완수하셨습니다."
	if sim and sim.crown_prince_manager:
		var res: Dictionary = sim.crown_prince_manager.start_education(sim)
		crown_prince["education"] = int(sim.crown_prince_manager.progress)
		crown_prince_education = int(crown_prince["education"])
		_push()
		return str(res.get("msg", ""))
	if sim and sim.tech_tree:
		var s_msg: String = sim.tech_tree.start_prince_study(sim)
		_push()
		return s_msg
	var turn_cost: int = DifficultyManager.get_prince_education_turn_cost()
	if sim.gold < turn_cost:
		return "시강원 서연 운영에 필요한 국고(%d냥)가 부족합니다." % turn_cost
	sim.gold -= turn_cost
	crown_prince["education"] = min(100, int(crown_prince.get("education", 0)) + 10)
	crown_prince_education = int(crown_prince["education"])
	CityStats.set_crown_prince_education(crown_prince_education)
	sim.authority = min(100, sim.authority + 5)
	_push()
	if crown_prince["education"] >= 100:
		return "경축: 세자께서 제왕학을 완수하셨습니다."
	return "서연으로 세자의 역량이 증진되었습니다. (진척도 %d%%)" % crown_prince["education"]


func visit_hyoryungwon() -> String:
	var res: Dictionary = TombVisitManager.execute_tomb_visit(self, sim)
	if res.get("success", false):
		_push()
	return str(res.get("msg", ""))

func solve_gyeokjaeng() -> String:
	if not eulmyo["active"]:
		return "지금은 원행 기간이 아닙니다."
	sim.loyalty = min(100, sim.loyalty + 15)
	sim.authority = min(100, sim.authority + 10)
	eulmyo["solved"] += 1
	if eulmyo["solved"] >= 3:
		eulmyo["active"] = false
		eulmyo["done"] = true
	_push()
	return "격쟁 탄원을 판결해 환곡 빚을 탕감했습니다. (민심 +15, 왕권 +10)"

## 의궤 편찬 가능 여부(가능하면 빈 문자열, 아니면 이유)
func uigwe_block_reason(id: String) -> String:
	if uigwe.get(id, false):
		return "이미 간행했습니다."
	if current_year < UIGWE_FROM_YEAR:
		return "%d년 이후에 편찬할 수 있습니다." % UIGWE_FROM_YEAR
	if id == "wonhaeng" and not milestones["eulmyo1795"]:
		return "1795년 을묘원행을 먼저 치러야 합니다."
	if id == "seongyeok" and sim.fortress_progress < 80:
		return "화성 성곽을 더 쌓아야 합니다. (완공률 80% 이상)"
	return ""

func publish_uigwe(id: String) -> String:
	var info: Dictionary = {}
	for u in UIGWE_LIST:
		if u["id"] == id:
			info = u
	if info.is_empty():
		return ""
	var why := uigwe_block_reason(id)
	if why != "":
		return why
	var ucost := int(info["cost"])
	if sim.retainers.get("lee_deokmu", false):
		ucost = int(ceil(float(ucost) * 0.7)) # 이덕무 검서관 — 서적 간행비 -30%
	if sim.gold < ucost:
		return "편찬에 필요한 국고(%d냥)가 부족합니다." % ucost
	sim.gold -= ucost
	uigwe[id] = true
	sim.authority = min(100, sim.authority + int(info["auth"]))
	sim.loyalty = min(100, sim.loyalty + int(info["loyal"]))
	_push()
	return "《%s》을(를) 간행했습니다. 후세에 길이 남을 기록입니다! (왕권 +%d, 민심 +%d)" % [info["name"], int(info["auth"]), int(info["loyal"])]

func _push() -> void:
	sim.emit_signal("state_updated", sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)

# ================================================================ 인재 랜덤 풀 · 녹봉 · 학문력
## PORT-TRACE [인재 랜덤 풀·녹봉·학문력]: 사용자 요청 — 고정 목록을 사서 등용하던 방식 대신, 매 턴 일정 확률로(학문력·교육 시설 연동)
## 후보가 무작위로 나타나고, 등용하면 매 턴 녹봉(50~500냥)이 국고에서 빠진다. 국고가 모자라면 녹봉이 비싼 사람부터 사직.
## 기존 12명 + 신규 7명(정약용·박제가·서유구는 겹침 — 새 명세 녹봉)을 한 풀로 통합(사용자 결정).
## grade: S/A/B/C/D/F, salary: 턴당 녹봉, acad: 등용 시 학문력 상승, bad: 겉과 속이 다른 인물(김판관이 잘못 천거할 수 있음)
const SCHOLARS := {
	"jeong": {"key": "jeong_yakyong", "name": "다산 정약용", "grade": "S", "salary": 500, "acad": 10, "desc": "거중기·녹로로 대역사 공기 35% 단축, 성 방호력 +100 / 높은 녹봉, 보수 유림 반발·서학 시비"},
	"park_jiwon": {"key": "park_jiwon", "name": "연암 박지원", "grade": "S", "salary": 450, "acad": 10, "desc": "저잣거리 상업·유통 세수 +50%, 《열하일기》"},
	"hong_daeyong": {"key": "hong_daeyong", "name": "담헌 홍대용", "grade": "A", "salary": 350, "acad": 10, "desc": "학문력 +10, 천문·과학 연구 비용 -20%"},
	"lee_deokmu": {"key": "lee_deokmu", "name": "청장관 이덕무", "grade": "A", "salary": 300, "acad": 8, "desc": "규장각 검서관 — 세자 서연 가속, 의궤 간행비 -30%"},
	"park": {"key": "park_jega", "name": "초정 박제가", "grade": "A", "salary": 320, "acad": 8, "desc": "수레·선박 유통으로 상업 세수 +40%, 전돌 생산 효율"},
	"chae": {"key": "chae_jegong", "name": "번암 채제공", "grade": "A", "salary": 300, "acad": 9, "desc": "성역 총리대신 — 대역사 공사비 25% 절감, 남인 결집"},
	"baek": {"key": "baek_dongsu", "name": "야뇌 백동수", "grade": "A", "salary": 280, "acad": 0, "desc": "장용영 무예 총관 — 국방력 +10/달, 도적 침략 차단, 성 방호력 +300"},
	"lee_gahwan": {"key": "lee_gahwan", "name": "정헌 이가환", "grade": "A", "salary": 280, "acad": 9, "desc": "공조판서 / 수학·천문학 — 축성 정밀도 상승, 천문 역법 교정 / 서학 연루 상소"},
	"kim_josun": {"key": "kim_josun", "name": "풍고 김조순", "grade": "A", "salary": 220, "acad": 6, "desc": "노론 시파 / 규장각 제학 — 조정 정국 안정, 세자 교육 보조 / 세도정치 잠재력"},
	"yu_deukgong": {"key": "yu_deukgong", "name": "영재 유득공", "grade": "B", "salary": 200, "acad": 7, "desc": "역사 연구 학문력 +7, 민심 +1/달, 《발해고》"},
	"kim_jeonghui": {"key": "kim_jeonghui", "name": "추사 김정희(청년)", "grade": "B", "salary": 250, "acad": 4, "desc": "비문 고증·예술 — 민심 +1/달"},
	"seo": {"key": "seo_yugu", "name": "풍석 서유구", "grade": "B", "salary": 180, "acad": 7, "desc": "《임원경제지》 — 둔전 농업 소출 +25%"},
	"jeong_beomjo": {"key": "jeong_beomjo", "name": "해좌 정범조", "grade": "B", "salary": 200, "acad": 6, "desc": "소론 원로 / 대제학 — 향교 유생 결집, 왕권 정당성 부여"},
	"kim": {"key": "kim_hongdo", "name": "단원 김홍도", "grade": "B", "salary": 200, "acad": 5, "desc": "도화서 화원 — 민심 +2/달, 의궤도 완성"},
	"jo": {"key": "jo_simtae", "name": "수원부사 조심태", "grade": "B", "salary": 200, "acad": 1, "desc": "치수·토목 감동 — 방재율 +5/달"},
	"bau": {"key": "kim_bau", "name": "석수 김바우", "grade": "B", "salary": 150, "acad": 0, "desc": "수석 석공 명장 — 성곽 완공도 +2/달, 대역사 투입 -20%"},
	"lee_seonggil": {"key": "lee_seonggil", "name": "도편수 이성길", "grade": "B", "salary": 180, "acad": 0, "desc": "수석 목수 도편수 — 목조 누각 및 행궁 건립 가속"},
	"musoe": {"key": "musoe", "name": "가죽공 무쇠", "grade": "C", "salary": 120, "acad": 0, "desc": "군수 피혁 명장 — 갑옷 및 군장 완비로 방호력 가산"},
	"yu": {"key": "yu_hanji", "name": "명필 유한지", "grade": "B", "salary": 150, "acad": 2, "desc": "예서 명필 — 민심 +1, 왕권 +1/달"},
	"gu": {"key": "gu_seonbok", "name": "어영대장 구선복", "grade": "C", "salary": 250, "acad": 0, "desc": "국방력 +15/달 (부작용: 군량 -10/달)"},
	"guk": {"key": "hong_gukyeong", "name": "도승지 홍국영", "grade": "C", "salary": 220, "acad": 0, "desc": "등용 즉시 왕권 +15 (부작용: 민심 -1/달)"},
	"hong": {"key": "hong_inhan", "name": "좌의정 홍인한", "grade": "D", "salary": 100, "acad": -5, "bad": true, "desc": "등용 즉시 금 3,000냥 헌납·4개월 동안 시전세 +20% / 매달 국고 5% 누수·왕권 -1"},
	"lee_gigyeong": {"key": "lee_gigyeong", "name": "이기경", "grade": "D", "salary": 70, "acad": -4, "bad": true, "desc": "서학 탄압으로 학문력 -2/달, 정약용과 함께면 불화(민심 -1·거중기 효과 반감)"},
	"sim_hwanji": {"key": "sim_hwanji", "name": "만포 심환지", "grade": "F", "salary": 50, "acad": -3, "bad": true, "desc": "노론 장악 — 양반 반발 억제(민심 +1/달)·군포세 저항 감소 / 왕권 -2/달, 대역사 태업(공기 20% 지연), 신기술 반대(연구비 +25%)"},
}

const GRADE_WEIGHT := {"S": 1.0, "A": 2.0, "B": 3.0, "C": 2.0, "D": 2.0, "F": 1.5}
const FLATTER := ["학식과 경륜이 뛰어나 국가에 큰 보탬이 될 거물이옵니다!", "조정의 기둥이 될 인물이니 꼭 쓰셔야 하옵니다!"]
const UNDERSELL := ["글은 좀 읽었다 하나 그저 평범한 선비로 보이옵니다.", "딱히 눈에 띄는 재주는 모르겠사옵니다."]

signal scholar_appeared(cand: Dictionary)
## 등용 후보 [{id, turns, praise(김판관 평), accurate}]
var candidates: Array = []
## 교육 시설(서원·향교 등)이 더해 주는 인재 출현 확률(2단계에서 갱신)
var talent_bonus := 0.0
## 교육 시설이 더해 주는 연구 비용 할인(0~1)
var research_bonus := 0.0

func scholar_by_key(key: String) -> String:
	for id in SCHOLARS:
		if SCHOLARS[id]["key"] == key:
			return id
	return ""

## 연구 비용: 학문력에 비례해 최대 30% + 홍대용 20% + 교육 시설(향교 15%) 할인, 합쳐 최대 60%
func research_cost(base: int) -> int:
	var disc := float(sim.academic) / 100.0 * 0.3 + research_bonus
	if sim.retainers.get("hong_daeyong", false):
		disc += 0.2
	# 서기수용론 + 서학 인재: 기술 연구 추가 -30%(합계 최대 70%)
	var western_on: bool = sim.retainers.get("jeong_yakyong", false) or sim.retainers.get("hong_daeyong", false)
	if sim.segi_policy and western_on:
		disc += 0.3
	var mult := 1.0 - clampf(disc, 0.0, 0.7 if sim.segi_policy else 0.6)
	# 실: 홍인한 개혁 비용 상승 +20%, 심환지 신기술 반대 +25%
	if sim.retainers.get("hong_inhan", false):
		mult *= 1.2
	if sim.retainers.get("sim_hwanji", false):
		mult *= 1.25
	return int(ceil(float(base) * mult))

## 김판관 추천 정확도(%) = 민심x0.3 + 왕권x0.3 + 학문력x0.4
func recommend_accuracy() -> float:
	return clampf(float(sim.loyalty) * 0.3 + float(sim.authority) * 0.3 + float(sim.academic) * 0.4, 0.0, 100.0)

## 재해(호환·화재·수해·반란 등)로 학문력 차감 — 이덕무가 있으면 절반
func academic_hit(amount: int, _reason: String = "") -> void:
	var a := amount
	if sim.retainers.get("lee_deokmu", false):
		a = int(ceil(float(a) * 0.5))
	sim.academic = clampi(sim.academic - a, 0, 100)

func _turn_scholars() -> void:
	# 저장에서 불러온 연구 완료 상태(sim 쪽 플래그)를 연구 목록에 반영
	if sim.boyuron:
		research["boyuron"] = true
	if sim.segi_policy:
		research["segi"] = true
	# 1) 녹봉 — 비싼 사람부터 지급, 모자라면 사직
	var hired: Array = []
	for id in SCHOLARS:
		if sim.retainers.get(SCHOLARS[id]["key"], false):
			hired.append(id)
	hired.sort_custom(func(a, b): return get_scholar_salary(a) > get_scholar_salary(b))
	var _paid := 0
	# PORT-TRACE [방치하면 인재 전원 사직]: 유지비가 국고보다 커서 국고가 0이 된 달에 녹봉을 못 받은 인재가 한꺼번에 모두 사직했다 —
	# 한 달에 한 명(녹봉이 가장 비싼 사람)만 떠나고, 나머지는 밀린 녹봉을 기다리며 남는다.
	var resigned := false
	var unpaid: Array[String] = []
	for id2 in hired:
		var sal: int = get_scholar_salary(id2)
		if sim.gold >= sal:
			sim.gold -= sal
			_paid += sal
		elif not resigned:
			resigned = true
			sim.retainers[SCHOLARS[id2]["key"]] = false
			ScholarManager.hired_scholars.erase(SCHOLARS[id2]["key"])
			emit_signal("notice", "국고가 바닥나 녹봉을 주지 못하자 %s이(가) 사직하고 낙향했습니다." % SCHOLARS[id2]["name"])
		else:
			unpaid.append(str(SCHOLARS[id2]["name"]))
	if not unpaid.is_empty():
		emit_signal("notice", "녹봉이 밀린 신하 %d명(%s)이 조정을 떠날까 동요하고 있습니다. 국고를 채우지 않으면 다음 달에도 한 명씩 떠납니다." % [unpaid.size(), ", ".join(unpaid)])
	if resigned:
		update_faction_and_academic()
	# 2) 학문력: 민심 하락이면 깎이고, 홍대용·유득공은 조금씩 쌓는다
	if sim.loyalty < 25:
		sim.academic = maxi(0, sim.academic - 2)
	elif sim.loyalty < 40:
		sim.academic = maxi(0, sim.academic - 1)
	if sim.retainers.get("hong_daeyong", false) and sim.academic < 100:
		sim.academic = mini(100, sim.academic + 1)
	# 3) 후보 만료 + 새 후보 출현(학문력·교육 시설 연동)
	var keep: Array = []
	for c in candidates:
		c["turns"] = int(c["turns"]) - 1
		if int(c["turns"]) > 0 and not sim.retainers.get(SCHOLARS[c["id"]]["key"], false):
			keep.append(c)
	candidates = keep
	var chance := 0.25 + float(sim.academic) / 200.0 + talent_bonus
	if candidates.size() < 3 and randf() < chance:
		_spawn_candidate()

func _spawn_candidate() -> void:
	var pool: Array = []
	var weights: Array = []
	var ac := float(sim.academic)
	for id in SCHOLARS:
		if sim.retainers.get(SCHOLARS[id]["key"], false):
			continue
		var dup := false
		for c in candidates:
			if c["id"] == id:
				dup = true
		if dup:
			continue
		var g: String = SCHOLARS[id]["grade"]
		var w: float = GRADE_WEIGHT[g]
		if g == "S":
			w *= 1.0 + ac / 25.0 # 학문력이 높을수록 S·A급이 잘 나온다
		elif g == "A":
			w *= 1.0 + ac / 50.0
		pool.append(id)
		weights.append(w)
	if pool.is_empty():
		return
	var tot := 0.0
	for w2 in weights:
		tot += w2
	var r := randf() * tot
	var pick: String = pool[0]
	for i in range(pool.size()):
		r -= weights[i]
		if r <= 0.0:
			pick = pool[i]
			break
	var info: Dictionary = SCHOLARS[pick]
	var acc := recommend_accuracy()
	var accurate := randf() * 100.0 < acc
	var praise: String
	if accurate:
		if info.get("bad", false):
			praise = "겉으론 번지르르하나 속을 들여다보니 경계해야 할 인물이옵니다. (%s)" % info["desc"]
		else:
			praise = "참된 인재이옵니다! %s" % info["desc"]
	else:
		# 오판 천거: 판관의 눈이 흐리면 척신을 충신으로, 서학 거두를 위험인물로
		if pick == "hong":
			praise = "선대왕 때부터 나라를 떠받친 충신 중의 충신이옵니다! 곳간을 채워 줄 큰 어른이시옵니다."
		elif pick == "jeong":
			praise = "재주는 있다 하나 서학(천주학)에 물든 위험한 서학쟁이라는 소문이 파다하옵니다…"
		elif info.get("bad", false) or info["grade"] in ["C"]:
			praise = FLATTER[randi() % FLATTER.size()]
		elif info["grade"] in ["S", "A"]:
			praise = UNDERSELL[randi() % UNDERSELL.size()]
		else:
			praise = "쓸 만한 인물로 보이옵니다."
	# 역사 단서(호·관직 이력·대표 행적)는 늘 함께 — 플레이어가 역사 지식으로 판단하도록
	var prof: Dictionary = PROFILE.get(pick, {})
	if not prof.is_empty():
		praise += "\n  [단서] 호: %s · 이력: %s · 행적: %s" % [prof.get("ho", "-"), prof.get("career", "-"), prof.get("deed", "-")]
	var cand := {"id": pick, "turns": 4, "praise": praise, "accurate": accurate, "acc": int(acc)}
	candidates.append(cand)
	emit_signal("scholar_appeared", cand)

## ScholarDiscoveryPopup 및 외부 연동용 별칭 (hire_candidate 호출)
func hire_scholar(id: String) -> String:
	return hire_candidate(id)

## 후보 등용(녹봉은 등용 즉시 첫 턴분을 치르고 이후 매 턴) / 등용된 인물 해임
func hire_candidate(id: String) -> String:
	var info: Dictionary = SCHOLARS.get(id, {})
	if info.is_empty():
		var mapped_id: String = scholar_by_key(id)
		if mapped_id != "":
			id = mapped_id
			info = SCHOLARS.get(id, {})
	if info.is_empty() and ScholarManager.TALENTS_DATA.has(id):
		info = ScholarManager.TALENTS_DATA[id]
	if info.is_empty():
		return ""

	var ret_key: String = str(info.get("key", id))
	if ScholarManager.is_scholar_hired(ret_key, sim.retainers if sim != null else {}):
		candidates = candidates.filter(func(c): return c["id"] != id)
		return "이미 조정에 등용된 인재이옵니다."

	var sal: int = get_scholar_salary(id)
	if sim.gold < sal:
		return "첫 녹봉(%d냥)을 줄 국고가 부족합니다." % sal
	sim.gold -= sal
	sim.retainers[ret_key] = true
	ScholarManager.hired_scholars[ret_key] = true
	GameProgressManager.unlock_puzzle_piece("people", ret_key) # 역사 사전 퍼즐 조각 해금
	if id in WesternLearning.ORTHODOX:
		sim.authority = mini(100, sim.authority + 3) # 정통 유학 인재 등용 — 왕권 회복
	if id == "hong":
		sim.gold += 3000 # 득: 척신의 일시 헌납
		hong_boost_turns = 4
	var acad_gain: int = int(info.get("acad", info.get("academic", 0)))
	sim.academic = clampi(sim.academic + acad_gain, 0, 100)
	if id == "guk":
		sim.authority = min(100, sim.authority + 15)
	candidates = candidates.filter(func(c): return c["id"] != id)
	update_faction_and_academic()
	_push()
	return "%s을(를) 조정에 등용했습니다. (녹봉 매달 %d냥)" % [str(info.get("name", id)), sal]

func dismiss_scholar(id: String) -> String:
	var info: Dictionary = SCHOLARS.get(id, {})
	if info.is_empty():
		return ""
	var ret_k: String = str(info.get("key", id))
	sim.retainers[ret_k] = false
	ScholarManager.hired_scholars.erase(ret_k)
	update_faction_and_academic()
	_push()
	return "%s을(를) 해임했습니다." % info["name"]


func total_salary() -> int:
	var s := 0
	for id in SCHOLARS:
		if sim.retainers.get(SCHOLARS[id]["key"], false):
			s += get_scholar_salary(id)
	return s

## 난이도 연동 관리 녹봉 계산 (쉬움: 1.0x, 보통: 2.0x, 어려움: 3.0x)
func get_scholar_salary(id: String) -> int:
	var info: Dictionary = SCHOLARS.get(id, {})
	if info.is_empty():
		var mapped_id: String = scholar_by_key(id)
		if mapped_id != "":
			info = SCHOLARS.get(mapped_id, {})
	if info.is_empty() and ScholarManager.TALENTS_DATA.has(id):
		info = ScholarManager.TALENTS_DATA[id]
	if info.is_empty():
		return 0
	var base_sal: int = int(info.get("salary", 0))
	var mult: float = DifficultyManager.get_retainer_salary_multiplier()
	return int(round(float(base_sal) * mult))

static func calculate_scholar_salary(base_sal: int) -> int:
	var mult: float = DifficultyManager.get_retainer_salary_multiplier()
	return int(round(float(base_sal) * mult))

## PORT-TRACE [인재 양면성]: 호(號)·관직 이력·대표 행적 단서(천거 문구에 늘 붙음) + 득실, western = 서학 성향(2단계 천주교당 디버프)
var hong_boost_turns := 0
const PROFILE := {
	"jeong": {"ho": "다산(茶山)·사암", "career": "1789 대과 급제, 규장각 초계문신·경기 암행어사", "deed": "한강 배다리·거중기 설계, 《기기도설》 연구", "western": true},
	"park_jiwon": {"ho": "연암(燕巖)", "career": "벼슬 없이 연행(1780) 수행, 뒤에 안의 현감", "deed": "《열하일기》, 《허생전》"},
	"hong_daeyong": {"ho": "담헌(湛軒)", "career": "1765 연행, 세손익위사 시직", "deed": "혼천의 제작, 지전설, 《의산문답》", "western": true},
	"lee_deokmu": {"ho": "청장관(靑莊館)·아정", "career": "서얼 출신 규장각 초대 검서관", "deed": "《청장관전서》, 《무예도보통지》 편찬"},
	"park": {"ho": "초정(楚亭)", "career": "서얼 출신 규장각 검서관", "deed": "《북학의》 — 수레·벽돌 사용 주장"},
	"chae": {"ho": "번암(樊巖)", "career": "영의정, 화성 성역 총리대신", "deed": "신해통공(1791), 화성 축성 총괄"},
	"baek": {"ho": "야뇌(野餒)", "career": "장용영 초관", "deed": "《무예도보통지》 무예 고증"},
	"yu_deukgong": {"ho": "영재(泠齋)", "career": "서얼 출신 규장각 검서관", "deed": "《발해고》 — 남북국 시대론"},
	"kim_jeonghui": {"ho": "추사(秋史)·완당", "career": "청년기 북학 수학(연행은 1809)", "deed": "추사체, 금석학(북한산비 고증)"},
	"seo": {"ho": "풍석(楓石)", "career": "규장각 대교, 여러 고을 수령", "deed": "《임원경제지》 농서"},
	"kim": {"ho": "단원(檀園)", "career": "도화서 화원, 연풍 현감", "deed": "《화성능행도》, 풍속화첩"},
	"jo": {"ho": "-", "career": "수원부사·화성유수", "deed": "화성 축성 실무 감독"},
	"bau": {"ho": "-", "career": "석수(石手) 장인", "deed": "화성 성벽 석축"},
	"yu": {"ho": "기원(綺園)", "career": "사자관", "deed": "화성 장안문·팔달문 상량문 글씨"},
	"gu": {"ho": "-", "career": "어영대장·훈련대장, 무관 실세", "deed": "사도세자 죽음에 연루 의심, 역모로 처형(1786)"},
	"guk": {"ho": "-", "career": "도승지·숙위대장", "deed": "세손 시절 호위, 세도 권력 전횡 뒤 축출(1779)"},
	"hong": {"ho": "-", "career": "좌의정, 혜경궁의 숙부", "deed": "세손 대리청정 반대(\"삼불필지설\"), 사사(1776)"},
	"lee_gigyeong": {"ho": "-", "career": "사헌부·사간원 관원", "deed": "서학 배척 상소, 정약용과 대립"},
	"sim_hwanji": {"ho": "만포(晩圃)", "career": "벽파 영수, 뒤에 영의정", "deed": "정조와 비밀 어찰 수백 통 — 순조 초 신유박해 주도"},
	"kim_josun": {"ho": "풍고(楓皐)", "career": "규장각 직제학, 순조의 장인", "deed": "정조의 두터운 신임, 세자 보호"},
	"jeong_beomjo": {"ho": "해좌(海左)", "career": "대제학, 예조판서", "deed": "문장과 유학의 대가, 향교 유생 결집"},
	"lee_gahwan": {"ho": "정헌(貞軒)", "career": "공조판서, 규장각 검교", "deed": "실학 수학·천문 역법, 《기하원본》 연구", "western": true},
	"lee_seonggil": {"ho": "-", "career": "화성성역 도편수", "deed": "화성행궁 및 봉수당 목조 가구 축조"},
	"musoe": {"ho": "-", "career": "화성성역 피혁 장인", "deed": "장용영 군사 갑주 및 마구 제작"},
}


## 서학 성향 인물인가(정약용·홍대용)
func is_western(id: String) -> bool:
	return bool(PROFILE.get(id, {}).get("western", false))

# ================================================================ 4대 핵심 지표 API & 동기화
func update_faction_balance() -> int:
	faction_balance_score = CityStats.calculate_faction_balance_from_retainers(sim.retainers if sim else {})
	CityStats.set_faction_balance_score(faction_balance_score)
	return faction_balance_score

func update_faction_and_academic() -> void:
	update_faction_balance()
	if sim:
		var grid_ref = sim.get("grid") if "grid" in sim else null
		sim.academic = CityStats.recalculate_academic_power(grid_ref, sim.retainers)


func get_crown_prince_education() -> int:
	return crown_prince_education

func set_crown_prince_education(val: int) -> void:
	crown_prince_education = clampi(val, 0, 100)
	crown_prince["education"] = crown_prince_education
	CityStats.set_crown_prince_education(crown_prince_education)

func get_hyeonryungwon_visits() -> int:
	return hyeonryungwon_visits

func set_hyeonryungwon_visits(val: int) -> void:
	hyeonryungwon_visits = maxi(0, val)
	CityStats.set_hyeonryungwon_visits(hyeonryungwon_visits)

func get_faction_balance_score() -> int:
	return faction_balance_score

func set_faction_balance_score(val: int) -> void:
	faction_balance_score = clampi(val, 0, 100)
	CityStats.set_faction_balance_score(faction_balance_score)

func get_fortress_defense_power() -> int:
	fortress_defense_power = CityStats.get_fortress_defense_power()
	return fortress_defense_power

func set_fortress_defense_power(val: int) -> void:
	fortress_defense_power = maxi(0, val)
	CityStats.set_fortress_defense_power(fortress_defense_power)
