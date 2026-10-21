extends Node
class_name EndingManager

## 1800년 정조 승하 및 12대 멀티 엔딩 평가 엔진 매니저
## - 발동 시점: current_year >= 1800 (정조 재위 24년, 1800년 도달 즉시)
## - 게임 루프 일시정지(pause) 및 전용 엔딩 모달 화면(EndingPopup.tscn) 호출
## - 12대 멀티 엔딩 우선순위 평가 엔진 (우선순위 1~12번 엄격한 IF-ELIF 체인 검사)
## - F10 단축키를 통한 실시간 엔딩 테스트 지원

const EndingPopupScene = preload("res://scenes/EndingPopup.tscn")

signal ending_triggered(ending_data: Dictionary)
signal ending_closed
signal ending_popup_shown(ending_data: Dictionary) # 엔딩 팝업이 뜬 순간(배경음악이 엔딩 곡으로 바뀐다)

var sim: SimulationCore
var grid: GameGrid
var time_manager: TimeManager
var court: CourtSystem
var hud: HUDController

var is_ending_active: bool = false
var ending_triggered_flag: bool = false
var ending_popup_instance: Node = null

## [대조선 르네상스 진 엔딩] 필요 인구(100만)
const RENAISSANCE_MIN_POP := 1000000

## [재정 파탄 엔딩] 임계치 (금화 10,000냥, 곡식 10,000석 미만 시 파탄 후보)
const BANKRUPTCY_THRESHOLD := 10000

# ==================== 12대 멀티 엔딩 마스터 데이터 ====================
const ENDING_DATA: Dictionary = {
	"WESTERN_COLLAPSE": {
		"id": "WESTERN_COLLAPSE",
		"num": 1,
		"type": "WESTERN_COLLAPSE",
		"title": "서학의 난 (무너진 사직)",
		"subtitle": "서학 사상의 통제 실패로 무너진 삼강오륜과 종교적 광풍",
		"desc": "서학 인재들을 조정에 중용하였으나, '보유론'과 '서기수용론'을 통한 사상적 조화와 기술 수용 체계를 미처 완성하지 못했습니다.\n서학의 평등 교리가 무분별하게 퍼져나가며 백성들은 국왕의 왕명보다 천주를 앞세웠고, 종묘와 제사를 거부하는 풍조 속에 삼강오륜이 뿌리째 흔들렸습니다.\n정조 승하 직후 보수 사대부들의 대대적인 옥사와 피의 숙청이 몰아쳤고, 조선은 통제 불능의 종교적 혼란과 내전의 소용돌이 속으로 무너져 내렸습니다.",
		"theme_color": "701a75",
		"art_tag": "■ [제1결말: 서학의 난] 무너진 사직과 종교적 광풍 ■",
		"video_file": "res://assets/endings/ending_western_collapse.ogv"
	},
	"UNFILIAL_CURSE": {
		"id": "UNFILIAL_CURSE",
		"num": 2,
		"type": "UNFILIAL_CURSE",
		"title": "불효의 저주 (종묘사직의 진노)",
		"subtitle": "부모의 원혼을 저버려 종묘사직의 노여움을 사다",
		"desc": "1800년 6월 28일, 정조 대왕께서 홀연히 승하하셨습니다.\n그러나 재위 11년 동안 전하께서는 사도세자의 묘소인 현륭원에 단 한 번도 친림하지 않으셨습니다.\n효의 도리를 저버리고 부모의 원혼을 외면한 군주라는 유림의 지탄 속에,\n연이은 흉년과 역병이 덮쳐 화성은 백성들이 떠나간 버려진 불모지로 전락하였습니다.",
		"theme_color": "7f1d1d",
		"art_tag": "■ [제2결말: 종묘사직의 진노] 부모의 한을 외면한 불효의 저주 ■",
		"video_file": "res://assets/endings/ending_unfilial_curse.ogv"
	},
	"BANKRUPT_RUIN": {
		"id": "BANKRUPT_RUIN",
		"num": 3,
		"type": "BANKRUPT_RUIN",
		"title": "피폐한 빈국 (재정 파탄)",
		"subtitle": "바닥난 국고와 빚더미에 흩어진 백성의 유령 도시",
		"desc": "1800년, 성역 공사를 무리하게 밀어붙이다 국가 재정이 완전히 파탄에 이르렀습니다.\n인부들에게 지급할 패전과 곡식이 바닥나고 삼남의 조세조차 고갈되니,\n생계를 잃은 백성들은 사방으로 뿔뿔이 흩어졌습니다.\n정조 승하 후 남겨진 것은 거대한 빚더미와 미완성 축성터뿐, 화성은 황량한 유령 도시로 방치되었습니다.",
		"theme_color": "991b1b",
		"art_tag": "■ [제3결말: 재정 파탄] 국고 고갈과 백성들의 유망(流亡) ■",
		"video_file": "res://assets/endings/ending_bankrupt_ruin.ogv"
	},
	"COUP_DETAT": {
		"id": "COUP_DETAT",
		"num": 4,
		"type": "COUP_DETAT",
		"title": "사대부의 반정 (왕권 실추)",
		"subtitle": "실추된 왕권의 틈새로 일어난 벽파 사대부의 군사 반정",
		"desc": "정조 재위 말기, 왕권이 회복할 수 없을 정도로 실추되자 노론 벽파 사대부들이 은밀히 군사를 일으켰습니다.\n창경궁을 포위하고 조정을 장악한 척신 세력은 정조의 모든 개혁 정책을 일거에 폐기하고,\n수원화성을 '역적의 도읍'이라 규정하며 철거령을 내렸습니다.\n군주의 이상향은 사대부들의 권력 찬탈 앞에 처참히 짓밟혔습니다.",
		"theme_color": "831843",
		"art_tag": "■ [제4결말: 왕권 실추] 벽파 척신의 군사 반정과 개혁 폐기 ■",
		"video_file": "res://assets/endings/ending_coup_detat.ogv"
	},
	"PEASANT_REVOLT": {
		"id": "PEASANT_REVOLT",
		"num": 5,
		"type": "PEASANT_REVOLT",
		"title": "민초의 거대한 봉기 (민중 혁명)",
		"subtitle": "가혹한 부역과 원성에 폭발한 백성들의 횃불",
		"desc": "민심이 바닥을 치는 가운데 계속된 강제 노역과 가혹한 세정으로 원성이 하늘을 찔렀습니다.\n마침내 분노가 폭발한 수원과 삼남의 농민들이 괭이와 죽창, 횃불을 들고 봉기하였습니다.\n봉기군은 화성행궁과 관아를 불태우고 수령방백들을 축출하였으니,\n백성을 위한다던 신도시는 도리어 백성들의 손에 의해 불타는 폐허로 변하고 말았습니다.",
		"theme_color": "b91c1c",
		"art_tag": "■ [제5결말: 민중 혁명] 성난 백성들의 횃불과 관아 전소 ■",
		"video_file": "res://assets/endings/ending_peasant_revolt.ogv"
	},
	"FALLEN_CITY": {
		"id": "FALLEN_CITY",
		"num": 6,
		"type": "FALLEN_CITY",
		"title": "함락된 신도시 (국방 붕괴)",
		"subtitle": "취약한 방호벽 사이로 난입한 침략군과 잿더미가 된 성곽",
		"desc": "성벽은 허술했고 군사 시설과 수비 병력은 터무니없이 미약했습니다.\n정조 승하의 혼란을 틈타 침략군과 무장 도적 떼가 화성의 미완성 성벽 틈으로 난입하였습니다.\n사대문은 지켜지지 못했고 시전과 민가는 불바다가 되어 유린당했습니다.\n조선의 새로운 국방 요새로 건설되던 화성은 전략적 방어 기능을 완전히 상실하고 함락되었습니다.",
		"theme_color": "431407",
		"art_tag": "■ [제6결말: 국방 붕괴] 침략군의 난입과 불타는 신도시 ■",
		"video_file": "res://assets/endings/ending_fallen_city.ogv"
	},
	"PLUNDERED_WEALTH": {
		"id": "PLUNDERED_WEALTH",
		"num": 7,
		"type": "PLUNDERED_WEALTH",
		"title": "약탈당한 풍요 (수탈 결말)",
		"subtitle": "곳간은 넘쳐나나 지킬 방패가 없어 외세의 손쉬운 먹잇감이 되다",
		"desc": "저잣거리 상업과 둔전 농업으로 곳간에는 십만 냥의 황금과 십만 석의 군량이 가득 찼습니다.\n그러나 이를 지켜낼 성곽 방호력과 군사 체계는 턱없이 부실했습니다.\n정조 대왕께서 승하하시자마자 막대한 부를 노린 외세와 도적 무리가 무방비의 화성을 습격하여 재물을 모조리 약탈해 갔습니다.\n지킬 힘이 없는 풍요는 백성에게 축복이 아닌 참혹한 재앙이었습니다.",
		"theme_color": "c2410c",
		"art_tag": "▲ [제7결말: 수탈 결말] 무방비의 풍요와 적들의 잔혹한 약탈 ▲",
		"video_file": "res://assets/endings/ending_plundered_wealth.ogv"
	},
	"BLOODY_FACTION": {
		"id": "BLOODY_FACTION",
		"num": 8,
		"type": "BLOODY_FACTION",
		"title": "피바람의 당쟁 (신사화)",
		"subtitle": "탕평의 붕괴, 군주가 눈감자마자 몰아친 잔혹한 피의 숙청",
		"desc": "한 당파가 조정을 독점하고 탕평의 균형추가 무너지자, 정조 대왕의 승하는 곧 피바람의 신호탄이 되었습니다.\n권력을 독점한 당파는 반대파 관료와 실학자들을 역모로 몰아 잔혹하게 사사하고 숙청하였습니다.\n정약용과 채제공 등 화성을 함께 일군 인재들은 유배와 참형을 피하지 못했습니다.\n화성 도읍은 당쟁의 피비린내 속에 얼어붙었습니다.",
		"theme_color": "9f1239",
		"art_tag": "▲ [제8결말: 신사화] 탕평의 실종과 반대파 대학살 ▲",
		"video_file": "res://assets/endings/ending_bloody_faction.ogv"
	},
	"SEDO_DARKNESS": {
		"id": "SEDO_DARKNESS",
		"num": 9,
		"type": "SEDO_DARKNESS",
		"title": "세도정치의 암운 (외척 발호)",
		"subtitle": "준비되지 못한 어린 세자와 척신 외척의 가혹한 60년 세도정치",
		"desc": "정조께서는 승하하셨으나 세자는 시강원 서연과 제왕학을 충분히 깨치지 못해 유약하였습니다.\n어린 순조가 즉위하자마자 안동 김씨 등 외척 가문이 권력을 독점하고 삼정을 문란케 하였습니다.\n화성의 자립적 재정과 군영은 외척들의 사리사욕을 채우는 주머니로 전락하였고,\n조선은 60년에 걸친 칠흑 같은 세도정치의 어두운 터널로 진입하였습니다.",
		"theme_color": "374151",
		"art_tag": "▲ [제9결말: 세도정치] 유약한 군주와 외척 가문의 권력 독점 ▲",
		"video_file": "res://assets/endings/ending_sedo_darkness.ogv"
	},
	"IGNORANCE_SWAMP": {
		"id": "IGNORANCE_SWAMP",
		"num": 10,
		"type": "IGNORANCE_SWAMP",
		"title": "무지의 늪 (후진국화의 길)",
		"subtitle": "견고한 성벽 속에 갇힌 지식 빈곤과 쇄국 후진국으로의 전락",
		"desc": "둘레 수 킬로미터의 웅장한 돌성곽은 완공되었으나, 도시의 학문과 기술의 축적이 빈곤하여 신문물을 수용하지 못했습니다.\n향교와 서당의 교육 기틀이 미약하고 사대부와 실학자들의 깊이 있는 연구가 뒷받침되지 못하니,\n돌성곽은 외침을 막는 방패에 그쳤을 뿐 새로운 근대 문명을 잉태하지 못했습니다.\n조선은 개화와 부국강병의 기회를 영구히 놓친 채 쇄국과 낙후된 후진국으로 전락하고 말았습니다.",
		"theme_color": "334155",
		"art_tag": "▲ [제10결말: 무지의 늪] 지식 빈곤과 쇄국 후진국 전락 ▲",
		"video_file": "res://assets/endings/ending_ignorance_swamp.ogv"
	},
	"DEFENSE_FORTRESS": {
		"id": "DEFENSE_FORTRESS",
		"num": 11,
		"type": "DEFENSE_FORTRESS",
		"title": "미완의 개혁과 수호의 요새 (수호 결말)",
		"subtitle": "개혁은 군주의 서거로 멈췄으나, 철벽의 성곽은 백성을 영원히 지키리라",
		"desc": "1800년 6월, 비운의 개혁군주 정조께서 승하하시니 만백성이 오열하였습니다.\n비록 정치적 이상과 을묘원행의 위업을 온전히 완결 짓지는 못하였으나,\n둘레 5.7km의 견고한 화성 성곽과 난공불락의 포루·치성 방어망은 완성되었습니다.\n군왕의 웅대한 개혁은 멈추었을지라도, 굳건한 성벽 품 안에서 백성들은 외침을 막아내며 평안을 누릴 것입니다.",
		"theme_color": "15803d",
		"art_tag": "◆ [제11결말: 수호 요새] 난공불락의 수원화성과 백성의 방패 ◆",
		"video_file": "res://assets/endings/ending_defense_fortress.ogv"
	},
	"TRUE_RENAISSANCE": {
		"id": "TRUE_RENAISSANCE",
		"num": 12,
		"type": "TRUE_RENAISSANCE",
		"title": "대조선 문예 부흥 [참 결말]",
		"subtitle": "개혁의 완성, 이상도시 화성을 발판으로 연 위대한 황금기",
		"desc": "1800년 6월 28일 정조 대왕께서 승하하셨으나, 조선의 미래는 확고했습니다.\n인구 100만이 넘는 이상도시 화성의 완벽한 폐곡선 성곽과 최첨단 수리시설, 을묘원행의 숭고한 애민정신, 탕평의 인재들이 모두 갖추어졌습니다.\n보유론과 서기수용론을 통해 동서양의 학문과 기술이 조화를 이루고 높은 학문력을 바탕으로 부국강병을 단행하니,\n화성은 동방의 찬란한 근대 문명의 요람이 되었고 조선은 마침내 위대한 황금기(문예 부흥)를 열어젖혔습니다.",
		"theme_color": "b8860b",
		"art_tag": "★ [제12결말: 참 결말] 이상도시 화성의 완성, 대조선 문예 부흥 ★",
		"video_file": "res://assets/endings/ending_true_renaissance.ogv"
	},
	"BANDIT_FALL": {
		"id": "BANDIT_FALL",
		"num": 13,
		"type": "BANDIT_FALL",
		"title": "도적 떼의 행궁 함락 (화성의 비극)",
		"subtitle": "수비선이 무너져 행궁이 도적 떼에 유린당한 중도 패배 비극",
		"desc": "수원화성의 방호벽이 완전히 무너지고 정예 요격군마저 패퇴하자, 흉포한 도적 무리가 마침내 화성행궁 본궁까지 난입하여 도읍을 유린하였습니다.\n임금의 거처와 읍치가 잿더미로 변하고 백성들은 비탄에 잠겼으니, 화성성역의 원대한 꿈은 미완의 참극으로 비참하게 막을 내리고 말았습니다.",
		"theme_color": "450a0a",
		"art_tag": "■ [제13결말: 도적 함락] 도적 떼의 난입과 불타는 화성행궁 ■",
		"video_file": "res://assets/endings/ending_bandit_fall.ogv"
	},
	"FALLEN_TO_BANDITS": {
		"id": "FALLEN_TO_BANDITS",
		"num": 14,
		"type": "FALLEN_TO_BANDITS",
		"title": "화성행궁 함락 (도시 멸망)",
		"subtitle": "성문과 방어선 돌파 및 행궁 점령",
		"desc": "성문과 방어선이 무너지고 장용영마저 패퇴하여, 화성행궁이 도적/반란군의 말발굽에 유린당하였습니다.\n임금의 거처와 읍치가 잿더미로 변하고 백성들은 비탄에 잠겼으니, 화성성역의 원대한 꿈은 미완의 참극으로 비참하게 막을 내리고 말았습니다.",
		"theme_color": "450a0a",
		"art_tag": "■ [도시 함락] 적군의 난입과 불타는 화성행궁 ■",
		"video_file": "res://assets/endings/ending_bandit_fall.ogv"
	}
}

func _init() -> void:
	name = "EndingManager"
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup(
	s_core: SimulationCore,
	g_grid: GameGrid,
	t_mgr: TimeManager,
	c_court: CourtSystem = null,
	h_hud: HUDController = null
) -> void:
	sim = s_core
	grid = g_grid
	time_manager = t_mgr
	court = c_court
	hud = h_hud
	EndingManager.instance = self

	if time_manager:
		if not time_manager.month_changed.is_connected(_on_time_changed):
			time_manager.month_changed.connect(_on_time_changed)
		if not time_manager.year_changed.is_connected(_on_year_changed):
			time_manager.year_changed.connect(_on_year_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F10:
			print_debug("[EndingManager] F10 단축키 입력 감지: 12대 멀티 엔딩 강제 트리거")
			trigger_ending_sequence()

func _on_time_changed(_month: int) -> void:
	check_ending_trigger()

func _on_year_changed(_year: int) -> void:
	check_ending_trigger()

## 저장을 불러온 뒤 엔딩 상태를 불러온 시점에 맞춘다.
## 1800년 이후 저장(엔딩을 본 뒤의 자동 저장)을 불러오면 엔딩을 다시 시작하지 않고 그대로 이어 간다.
## 반대로 엔딩 전 저장을 불러오면 다음 1800년에 엔딩이 정상으로 다시 열린다.
func sync_after_load() -> void:
	is_ending_active = false
	ending_triggered_flag = time_manager != null and time_manager.current_year >= 1800
	for ch in get_children():
		if ch is EndingVideoLayer:
			ch.queue_free()
	if ending_popup_instance and is_instance_valid(ending_popup_instance):
		ending_popup_instance.queue_free()
		ending_popup_instance = null

## 1800년 도달 여부 정기 검사
func check_ending_trigger() -> bool:
	if SaveSystem.is_loading:
		return false
	if ending_triggered_flag or is_ending_active:
		return false
	if time_manager == null or sim == null:
		return false

	var current_year: int = time_manager.current_year
	if current_year >= 1800:
		ending_triggered_flag = true
		is_ending_active = true
		trigger_ending_sequence()
		return true

	return false

## 1800년 정조 승하 엔딩 시퀀스 가동
func trigger_ending_sequence() -> Dictionary:
	# 1) 시뮬레이션 일시 정지 (게임 루프 정지)
	if time_manager:
		time_manager.set_speed(TimeManager.SpeedMode.PAUSE)

	# 2) 12대 멀티 엔딩 평가
	var ending_data: Dictionary = evaluate_12_endings(sim, grid)

	# 3) 명확한 디버그 로그 출력
	print_debug("[1800년 정조 승하 12대 엔딩 판정] 번호: %d | 종류: %s | 제목: %s | 축성도: %d%% | 방호력: %d | 학문력: %d | 친림: %d회 | 재정(금/곡): %d/%d | 왕권: %d | 민심: %d | 탕평: %d | 세자: %d | 을묘: %s | 실학완수: %s" % [
		int(ending_data.get("num", 0)),
		ending_data.get("type", ""),
		ending_data.get("title", ""),
		int(ending_data.get("fortress", 0)),
		int(ending_data.get("defense_power", 0)),
		int(ending_data.get("academic_power", 0)),
		int(ending_data.get("hyeonryungwon_visits", 0)),
		int(ending_data.get("gold", 0)),
		int(ending_data.get("rice", 0)),
		int(ending_data.get("authority", 0)),
		int(ending_data.get("loyalty", 0)),
		int(ending_data.get("faction_balance", 0)),
		int(ending_data.get("prince_education", 0)),
		str(ending_data.get("eulmyo_done", false)),
		str(ending_data.get("silhak_done", false))
	])

	emit_signal("ending_triggered", ending_data)

	# 4) 엔딩별 시네마틱 영상 재생 후 팝업 오픈 (영상 부재 시 즉시 팝업 오픈)
	play_ending_sequence_flow(ending_data)

	return ending_data

## 기존 호환용 메서드
static func evaluate_ending(s: SimulationCore, g: GameGrid) -> Dictionary:
	return evaluate_12_endings(s, g)

static func evaluate_10_endings(s: SimulationCore, g: GameGrid) -> Dictionary:
	return evaluate_12_endings(s, g)

## 1800년 최종 엔딩 다중 중첩 판정 매트릭스 엔진 (3단계 계층 구조)
## - STEP 1: 위업 달성 검증 (12번 진 엔딩, 11번 수호 엔딩 선행 격리)
## - STEP 2: 특수 인과관계 엔딩 검증 (1번 서학 사상 붕괴, 2번 불효의 저주)
## - STEP 3: 결함 심각도(Deficit Severity) 점수제 경쟁 (임계치 대비 파탄 낙폭 최대치 엔딩 동적 도출)
static func evaluate_final_ending_1800(s: SimulationCore, g: GameGrid) -> Dictionary:
	return evaluate_12_endings(s, g)

## 1800년 판정 시 각 엔딩 후보의 S 점수 디버그 로그 출력
static func print_debug_ending_scores(scores: Dictionary, picked_key: String) -> void:
	var score_strs: Array[String] = []
	for k: String in scores.keys():
		var val: float = float(scores[k])
		score_strs.append("%s: %.4f" % [k, val])
	print_debug("[EndingManager] 결함 심각도(Severity) 점수 매트릭스 결산: [%s] -> 최종 선택: %s" % [
		", ".join(score_strs),
		picked_key
	])

## 1800년 정조 승하 12대 멀티 엔딩 평가 엔진
static func evaluate_12_endings(s: SimulationCore, g: GameGrid) -> Dictionary:
	# 1. 상태 지표 추출
	var fortress: int = 0
	var is_wall_loop: bool = false

	if g:
		fortress = g.fortress_progress
		if g.wall_loop_validator != null:
			var v_res: Dictionary = g.wall_loop_validator.validate_loop(g)
			is_wall_loop = bool(v_res.get("is_closed_loop", false)) or int(v_res.get("validated_progress", 0)) >= 100
		if not is_wall_loop and g.has_method("is_wall_loop_completed"):
			is_wall_loop = g.is_wall_loop_completed()
	if s:
		fortress = maxi(fortress, s.fortress_progress)

	var wall_completion: float = 100.0 if (fortress >= 100 or is_wall_loop) else float(fortress)
	var wall_100: bool = wall_completion >= 100.0

	var eulmyo_done: bool = s.is_eulmyo_completed if s else false
	if not eulmyo_done and s != null and s.uigwe_manager != null:
		var u_dict: Dictionary = s.uigwe_manager.serialize()
		if bool(u_dict.get("published_wonhaeng", false)) or bool(u_dict.get("wonhaeng_published", false)):
			eulmyo_done = true
	var gold: int = s.gold if s else 0
	var grain: int = s.rice if s else 0
	var pop: int = s.population if s else 0
	var royal_power: int = s.authority if s else 0
	var morale: int = s.loyalty if s else 0
	var academic: int = s.academic if s else 0
	var military: int = s.military_power if s else 0

	# 5대 핵심 지표
	var hyeonryungwon_visits: int = CityStats.get_hyeonryungwon_visits()
	var crown_prince_education: int = CityStats.get_crown_prince_education()
	if s != null:
		if s.crown_prince_manager != null:
			crown_prince_education = maxi(crown_prince_education, int(s.crown_prince_manager.progress))
		if s.tech_tree != null:
			crown_prince_education = maxi(crown_prince_education, int(s.tech_tree.prince_edu_progress))
	var faction_balance_score: int = CityStats.get_faction_balance_score()
	var fortress_defense_power: int = CityStats.get_fortress_defense_power()
	var academic_power: int = CityStats.get_academic_power()
	if academic_power == 0 and academic > 0:
		academic_power = academic

	# 방호력이 0인 경우 실시간 계산 fallback
	if fortress_defense_power == 0 and (wall_completion > 0 or military > 0):
		fortress_defense_power = CityStats.calculate_fortress_defense_power_from_grid(
			int(wall_completion),
			g.grid if g else [],
			military
		)

	# 실학 연구 완료 여부 (보유론, 서기수용론)
	var boyuron_done: bool = s.boyuron if s else false
	var segi_done: bool = s.segi_policy if s else false
	var silhak_done: bool = boyuron_done and segi_done

	# 서학 성향 인재 등용 여부
	var retainers: Dictionary = s.retainers if s else {}
	var has_western_scholar: bool = ScholarManager.has_western_scholar_hired(retainers)

	# 12번 진 엔딩 조건 판정
	var is_true_renaissance: bool = (
		wall_100
		and fortress_defense_power >= 80
		and eulmyo_done
		and crown_prince_education >= 70
		and faction_balance_score >= 60
		and morale >= 80
		and royal_power >= 80
		and academic_power >= 60
		and silhak_done
	)

	var picked_key: String = ""

	# ==================== [STEP 1: 최고 위업 달성 검증 (Supreme Success Tier)] ====================
	# 12번 진 엔딩 (대조선 르네상스) 조건 완벽 충족 시 최우선 확정
	if is_true_renaissance:
		picked_key = "TRUE_RENAISSANCE"

	# ==================== [STEP 2: 특수 인과관계 엔딩 검증 (Action Triggers)] ====================
	if picked_key == "":
		# 1순위: 서학 인재 등용 후 보유론/서기수용론 둘 다 미완수 -> 1번 사상 붕괴 확정
		if has_western_scholar and not silhak_done:
			picked_key = "WESTERN_COLLAPSE"
		# 2순위: 재위 24년간 현륭원 친림 0회 (패륜) -> 2번 불효의 저주 확정
		# 2순위: 을묘원행(1795년) 이후에만 현륭원 친림 0회를 불효 엔딩으로 판정
		# 1789~1794년 초반에는 아직 기회가 있으므로 조기 발동 차단
		elif hyeonryungwon_visits <= 0 and (s == null or int(s.current_year) >= 1795):
			picked_key = "UNFILIAL_CURSE"

	# ==================== [STEP 1-B: 수호 엔딩 달성 검증 (Defense Fortress Tier)] ====================
	# 11번 수호 엔딩 조건 충족 (단, 학문력 60 미만인 10번 지식 빈곤 상태 배제)
	if picked_key == "":
		if wall_100 and fortress_defense_power >= 70 and academic_power >= 60:
			picked_key = "DEFENSE_FORTRESS"

	# ==================== [STEP 3: 결함 심각도(Deficit Severity) 점수제 경쟁] ====================
	if picked_key == "":
		var scores: Dictionary = {}

		# 3번: 피폐한 빈국 (재정 파탄) - 임계치 10,000냥/10,000석, 가중치 1.2
		var def_gold: float = (float(BANKRUPTCY_THRESHOLD) - float(gold)) / float(BANKRUPTCY_THRESHOLD)
		var def_grain: float = (float(BANKRUPTCY_THRESHOLD) - float(grain)) / float(BANKRUPTCY_THRESHOLD)
		var s3: float = maxf(def_gold, def_grain) * 1.2
		if s3 > 0.0:
			scores["BANKRUPT_RUIN"] = s3

		# 4번: 체제 붕괴 (사대부의 반정) - 임계치 25, 가중치 1.1
		var s4: float = ((25.0 - float(royal_power)) / 25.0) * 1.1
		if s4 > 0.0:
			scores["COUP_DETAT"] = s4

		# 5번: 민초의 거대한 봉기 (민중 혁명) - 임계치 30, 가중치 1.1
		var s5: float = ((30.0 - float(morale)) / 30.0) * 1.1
		if s5 > 0.0:
			scores["PEASANT_REVOLT"] = s5

		# 6번: 국방 붕괴 (함락된 신도시) - 국방력 30, 성곽 70%, 가중치 0.6
		var s6_def: float = (30.0 - float(fortress_defense_power)) / 30.0
		var s6_wall: float = (70.0 - float(wall_completion)) / 70.0
		var s6: float = (s6_def + s6_wall) * 0.6
		if s6 > 0.0:
			scores["FALLEN_CITY"] = s6

		# 7번: 수탈 (약탈당한 풍요) - 금화 >= 10만 AND 곡식 >= 10만 AND 국방력 < 35, 가중치 1.3
		if gold >= 100000 and grain >= 100000 and fortress_defense_power < 35:
			var s7: float = ((35.0 - float(fortress_defense_power)) / 35.0) * 1.3
			if s7 > 0.0:
				scores["PLUNDERED_WEALTH"] = s7

		# 8번: 정쟁 (피바람의 당쟁) - 탕평도 30, 가중치 1.0
		var s8: float = ((30.0 - float(faction_balance_score)) / 30.0) * 1.0
		if s8 > 0.0:
			scores["BLOODY_FACTION"] = s8

		# 9번: 세도정치 (세도의 암운) - 세자 교육도 40, 가중치 1.0
		var s9: float = ((40.0 - float(crown_prince_education)) / 40.0) * 1.0
		if s9 > 0.0:
			scores["SEDO_DARKNESS"] = s9

		# 10번: 지식 빈곤 (무지의 늪) - 성곽 100% 완공 BUT 학문력 < 60, 가중치 1.0
		if wall_100 and academic_power < 60:
			var s10: float = ((60.0 - float(academic_power)) / 60.0) * 1.0
			if s10 > 0.0:
				scores["IGNORANCE_SWAMP"] = s10

		# 최고 심각도 엔딩 식별
		if scores.size() > 0:
			var best_key: String = ""
			var max_score: float = -999999.0
			for cand_key: String in scores.keys():
				var cand_score: float = float(scores[cand_key])
				if cand_score > max_score:
					max_score = cand_score
					best_key = cand_key
			picked_key = best_key
			print_debug_ending_scores(scores, picked_key)
		else:
			# 파탄 수치가 없는 안전 Fallback
			if not wall_100:
				if wall_completion < 70.0:
					picked_key = "FALLEN_CITY"
				elif academic_power < 60:
					picked_key = "IGNORANCE_SWAMP"
				else:
					picked_key = "DEFENSE_FORTRESS"
			else:
				if academic_power < 60:
					picked_key = "IGNORANCE_SWAMP"
				else:
					picked_key = "DEFENSE_FORTRESS"

	if picked_key == "" or not ENDING_DATA.has(picked_key):
		picked_key = "DEFENSE_FORTRESS"

	var base_info: Dictionary = ENDING_DATA[picked_key]
	var res: Dictionary = base_info.duplicate()

	# 종합 실록 데이터 첨부
	res["fortress"] = int(wall_completion)
	res["wall_100"] = wall_100
	res["eulmyo_done"] = eulmyo_done
	res["loyalty"] = morale
	res["authority"] = royal_power
	res["gold"] = gold
	res["rice"] = grain
	res["pop"] = pop
	res["defense_power"] = fortress_defense_power
	res["academic"] = academic
	res["academic_power"] = academic_power
	res["military"] = military
	res["hyeonryungwon_visits"] = hyeonryungwon_visits
	res["prince_education"] = crown_prince_education
	res["faction_balance"] = faction_balance_score
	res["silhak_done"] = silhak_done
	res["boyuron_done"] = boyuron_done
	res["segi_done"] = segi_done
	res["has_western_scholar"] = has_western_scholar
	res["year"] = 1800

	return res

## 엔딩별 비디오 파일 경로 조회
## 1) video_file 명시 경로 -> 2) ending_{type_lower}.ogv -> 3) ending_{num}_{type_lower}.ogv
## -> 4) ending_{num}.ogv -> 5) ending_default.ogv -> 6) ending_video.ogv 순으로 탐색
static func get_ending_video_path(ending_data: Dictionary) -> String:
	var explicit_path: String = String(ending_data.get("video_file", ""))
	if explicit_path != "" and (FileAccess.file_exists(explicit_path) or ResourceLoader.exists(explicit_path)):
		return explicit_path

	var etype_lower: String = String(ending_data.get("type", "")).to_lower()
	var enum_val: int = int(ending_data.get("num", 0))

	var candidates: Array[String] = [
		"res://assets/endings/ending_%s.ogv" % etype_lower,
		"res://assets/endings/ending_%d_%s.ogv" % [enum_val, etype_lower],
		"res://assets/endings/ending_%d.ogv" % enum_val,
		"res://assets/endings/ending_%s.ogv" % String(ending_data.get("type", "")),
		"res://assets/endings/ending_default.ogv",
		"res://assets/ending_video.ogv"
	]

	for p: String in candidates:
		if FileAccess.file_exists(p) or ResourceLoader.exists(p):
			return p

	return ""

## 엔딩별 시네마틱 영상 재생 후 팝업 오픈 핸드오버
func play_ending_sequence_flow(ending_data: Dictionary) -> void:
	# 역사 사전 [엔딩 모음] 퍼즐 조각 영구 해금(본 엔딩은 사전에서 다시 볼 수 있다)
	var enum_n: int = int(ending_data.get("num", 0))
	if enum_n > 0:
		GameProgressManager.unlock_puzzle_piece("endings", "ending_%d" % enum_n, int(ending_data.get("year", 0)))
	var video_path: String = get_ending_video_path(ending_data)

	# 헤드리스 모드(CLI 테스트)이거나 비디오 경로가 없는 경우 즉시 엔딩 팝업 오픈
	if DisplayServer.get_name() == "headless" or video_path == "":
		print_debug("[EndingManager] 헤드리스 환경 또는 비디오 에셋 없음 -> 즉시 엔딩 팝업 표시")
		show_ending_popup(ending_data)
		return

	print_debug("[EndingManager] 엔딩 영상 재생 시작: %s (엔딩 %d번 - %s)" % [
		video_path, int(ending_data.get("num", 0)), String(ending_data.get("title", ""))
	])
	var video_layer := EndingVideoLayer.new()
	add_child(video_layer)
	video_layer.video_finished.connect(func():
		show_ending_popup(ending_data)
	)
	var t_title: String = String(ending_data.get("title", ""))
	var t_subtitle: String = String(ending_data.get("subtitle", ""))
	var ok: bool = video_layer.play_video(video_path, t_title, t_subtitle)
	if not ok:
		if is_instance_valid(video_layer):
			video_layer.queue_free()
		show_ending_popup(ending_data)

## 전용 엔딩 모달 팝업 화면 생성 및 호출
func show_ending_popup(ending_data: Dictionary) -> void:
	if ending_popup_instance and is_instance_valid(ending_popup_instance):
		ending_popup_instance.queue_free()

	ending_popup_instance = EndingPopupScene.instantiate()
	add_child(ending_popup_instance)
	emit_signal("ending_popup_shown", ending_data)

	if ending_popup_instance.has_method("display_ending"):
		ending_popup_instance.display_ending(ending_data, sim, grid, time_manager)

	if ending_popup_instance.has_signal("popup_closed"):
		ending_popup_instance.popup_closed.connect(func():
			is_ending_active = false
			emit_signal("ending_closed")
		)

static var instance: EndingManager = null

## 전역 엔딩 즉시 발화 인터페이스
static func trigger_ending(ending_key: String = "FALLEN_TO_BANDITS") -> Dictionary:
	if instance != null:
		return instance.trigger_fall_of_city_ending(ending_key)
	return {}

## 도적/반란군의 행궁 함락으로 인한 강제 비극 엔딩 트리거 (국방 붕괴: 함락된 신도시 또는 사대부의 반정)
func trigger_fall_of_city_ending(override_key: String = "") -> Dictionary:
	if is_ending_active:
		return {}

	# 1) 시뮬레이션 일시 정지 (게임 루프 정지)
	if time_manager:
		time_manager.set_speed(TimeManager.SpeedMode.PAUSE)

	is_ending_active = true
	ending_triggered_flag = true

	var royal_val: int = CityStats.get_royal_power()
	if sim:
		royal_val = sim.authority

	var picked_key: String = override_key
	if picked_key == "":
		if royal_val < 20:
			picked_key = "COUP_DETAT"
		else:
			picked_key = "BANDIT_FALL"

	var base_info: Dictionary = ENDING_DATA.get(picked_key, ENDING_DATA["BANDIT_FALL"])
	var res: Dictionary = base_info.duplicate()

	res["fortress"] = int(grid.wall_loop_progress * 100.0) if (grid and "wall_loop_progress" in grid) else 0
	res["wall_100"] = false
	res["eulmyo_done"] = bool(sim.is_eulmyo_completed) if (sim and "is_eulmyo_completed" in sim) else false
	res["loyalty"] = sim.loyalty if (sim and "loyalty" in sim) else 0
	res["authority"] = royal_val
	res["gold"] = sim.gold if (sim and "gold" in sim) else 0
	res["rice"] = sim.rice if (sim and "rice" in sim) else 0
	res["pop"] = sim.population if (sim and "population" in sim) else 0
	res["defense_power"] = CityStats.get_fortress_defense_power()
	res["academic_power"] = CityStats.get_academic_power()
	res["military"] = sim.military_power if (sim and "military_power" in sim) else 0
	res["year"] = time_manager.current_year if time_manager else 1794

	print_debug("[행궁 함락 강제 엔딩 발화] 사유: %s | 제목: %s | 왕권: %d | 방호력: %d" % [
		picked_key, res.get("title", ""), royal_val, res.get("defense_power", 0)
	])

	emit_signal("ending_triggered", res)
	play_ending_sequence_flow(res)
	return res

