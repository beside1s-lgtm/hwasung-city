extends Node
class_name SimulationCore

## 심시티 2000 스타일 틱 기반 시뮬레이터
signal state_updated(gold: int, rice: int, pop: int, loyalty: int, flood_defense: int)
signal project_completed(project_name: String)
signal disaster_alert(msg: String)
signal academic_hit(amount: int, reason: String) # PORT-TRACE [학문력]: 재해로 학문력 차감(CourtSystem이 처리)
# PORT-TRACE P2: 계절(=TS의 1턴, 90틱) 경계 신호 및 국책사업 착공/완공 ID 신호 (docs/godot_port_log.md)
signal turn_advanced(turn: int, season_index: int, year: int)
signal project_started(project_id: String)
signal project_finished(project_id: String)
signal project_skipped(project_id: String, msg: String) # 사용자가 시설을 직접 지어 대역사를 쓰지 않게 된 경우
@warning_ignore("unused_signal")
signal project_paused(project_id: String, msg: String)
@warning_ignore("unused_signal")
signal project_resumed(project_id: String, msg: String)
signal bandit_raid_started(pos: Vector2i)
signal bandit_raid_ended(repelled: bool)
signal bandit_camp_subjugated
@warning_ignore("unused_signal")
signal fire_outbreak(pos: Vector2i)
@warning_ignore("unused_signal")
signal fire_extinguished(pos: Vector2i)
@warning_ignore("unused_signal")
signal gazette_published(issue_num: int, year: int, season: String)
## PORT-TRACE [달·계절 구분]: 1턴 = 1개월. 계절(3~5월 봄·6~8월 여름·9~11월 가을·12~2월 겨울)이 바뀌는 달의 턴에서만 내보낸다.
## season_index는 새로 시작한 계절, 송사·계절 결산처럼 "계절마다" 일어나는 일은 이것에 붙인다.
@warning_ignore("unused_signal")
signal season_advanced(season_index: int, year: int)

# 자원 상태
var gold: int = 2500
var rice: int = 1600
var population: int = 120
var loyalty: int = 88
var military_power: int = 70
var flood_defense: int = 0 # 치수 방재율 (%)
var famine_active: bool = false  # 기근 발생 중 여부 (food <= 0)
var authority: int = 70 # PORT-TRACE P2: 왕권 (TS state.authority)
## PORT-TRACE [공성전]: 성 방호력 피로도(도적떼를 막을 때마다 누적, 턴마다 25 회복), 성을 떠난 유민 수, 반란군·도적떼 재발 대기 턴
var defense_fatigue: int = 0
var defense_repair_bonus: int = 0 # 성곽 수축 보수 누적치
var defense_damage_taken: int = 0 # 도적/반란군 공격 피해도
var refugees: int = 0
var rebel_cd: int = 0
var horde_cd: int = 0
var fortress_progress: int = 0 # 성곽 완공도 (%)
var defense_power: int = 1000 # 성곽 방호력 (0~1000)
var is_wartime_mobilized: bool = false # 전시 총동원 모드 플래그
var repair_state: Dictionary = {"active": false, "type": "none", "turns_left": 0} # 보수 공사 FSM 상태
var troop_roster: Dictionary = {"total": 20, "posu": 12, "sasu": 3, "salsu": 3, "gipo": 2} # 조선 후기 삼수병·기포병 편제
var turn: int = 1 # PORT-TRACE P2: 턴 카운터 — 1턴 = 1개월(30틱). 1턴이 1789년 1월
var current_year: int = 1789
var pop_manager: PopulationManager = null

# 을묘원행(1795) 국책 대기록 및 시간 일시정지 플래그
var is_time_frozen: bool = false
var is_eulmyo_active: bool = false
var is_eulmyo_completed: bool = false
@warning_ignore("unused_signal")
signal eulmyo_triggered
@warning_ignore("unused_signal")
signal eulmyo_completed

# 도적 침략 및 소굴 토벌 시스템 상태
var bandit_active: bool = false
var bandit_camp_pos: Vector2i = Vector2i(4, 8)
var bandit_suppression_cooldown: float = 0.0
var bandit_raid_count: int = 0
var bandit_suppression_turns: int = 0 # 도적 억제 쿨타임(개월) — 2년 = 24
var bandit_manager: BanditManager = null

# 동적 난이도 및 성장 비례 위협 스케일러 캐시 변수 (O(1) 턴당 1회 산출)
var cached_crime_rate_bonus: float = 0.0
var cached_morale_multiplier: float = 1.0
var cached_threat_escalation: float = 0.0
var cached_bandit_spawn_chance: float = 0.0
var last_maintenance_result: Dictionary = {}

# 화재 재난 상태
var fire_active: bool = false
var grid_ref: GameGrid = null

# 자연재해 및 전시 수해(홍수) 위기 시스템 상태
var flood_crisis_active: bool = false # 수해 위기 모드 (생산력 및 방호력 50% 반감)
var flood_crisis_turns_left: int = 0  # 수해 위기 남은 턴 수 (기본 1계절=1턴)
var drought_active: bool = false      # 가뭄 상태 (1계절 지속)
var drought_turns_left: int = 0
var plague_active: bool = false       # 역병 상태 (1계절 지속)
var plague_turns_left: int = 0
signal flood_crisis_started
signal flood_crisis_ended

# 호랑이(호환) 위협 쿨타임(개월) — 2년 = 24
var tiger_cooldown_turns: int = 0

# 심시티 2000 RCI 수요 지수 (-100 ~ +100)
var demand_res: int = 65
var demand_com: int = 45
var demand_agr: int = 50

# 세율 (호조 탕평 조세, 1~20%)
var tax_rate_land: int = 7
var tax_rate_market: int = 7
var tax_rate_military: int = 7

# 등용된 실학 인재
var retainers = {
	# PORT-TRACE [인재 랜덤 풀]: 이제 처음부터 등용된 신하는 없다 — 매 턴 후보가 나타나면 녹봉을 주고 등용(CourtSystem.SCHOLARS)
	"jeong_yakyong": false, # 거중기 (공기 35% 단축)
	"chae_jegong": false,   # 총리대신 (공사비 25% 절감)
	"park_jega": false,    # 북학/상업
	"seo_yugu": false,     # 임원경제지/농업
	# PORT-TRACE P2: TS 인재 9명 중 Godot 미구현 5명 추가
	"baek_dongsu": false,  # 장용영 (턴당 국방력 +10)
	"kim_hongdo": false,   # 도화서 (턴당 민심 +2)
	"hong_gukyeong": false,# 홍국영 (왕권 +15 즉시, 턴당 민심 -1)
	"gu_seonbok": false,   # 구선복 (턴당 국방력 +15, 군량 -10)
	"hong_inhan": false,   # 홍인한 (턴당 금 +200, 민심 -1)
	"jo_simtae": false,    # 조심태 (수원부사, 치수/도로 감동)
	"kim_bau": false,      # 김바우 (수석 석공 명장)
	"yu_hanji": false,     # 유한지 (예서 명필)
	# PORT-TRACE [인재 랜덤 풀]: 정조 시대 실학자 신규 7인(정약용·박제가·서유구는 기존 키 재사용)
	"park_jiwon": false, "hong_daeyong": false, "lee_deokmu": false, "yu_deukgong": false,
	"kim_jeonghui": false, "lee_gigyeong": false, "sim_hwanji": false,
	# 12인 사대부 및 현장 기술 장인 신규 추가
	"kim_josun": false, "jeong_beomjo": false, "lee_gahwan": false,
	"lee_seonggil": false, "musoe": false,
}
## PORT-TRACE [학문력]: 도시 학문력(0~100) — 교육 시설·학자 등용으로 오르고 민심 하락·재해로 깎인다
var academic: int = 0

# 사병 음모(Conspiracy Loop) 상태 머신 데이터
var active_conspirator_id: String = ""      # 현재 사병을 모으고 있는 인물 ID
var active_conspirator_name: String = ""    # 화면에 표시할 주모자 이름
var active_conspirator_title: String = ""   # 화면에 표시할 직함/신분
var conspiracy_stage: int = 0               # 0: 없음, 1: 사병 포착, 2: 세력 확장, 3: 반란 임박
var conspiracy_cooldown_turns: int = 0      # 다음 보고까지 남은 턴 수
var is_conspiracy_decision_pending: bool = false # 현재 결정 대기 중 플래그 (5초 중복 팝업 원천 방어)
var purged_conspirators: Dictionary = {}    # 백동수 압수수색 등으로 이미 처단된 인물 목록
var is_gu_seon_bok_resolved: bool = false   # 하위 호환성용 플래그

# 대체 주모자 후보 풀 (구선복 미등용 또는 숙청 시 순차/조건부 선택)
const CONSPIRATOR_CANDIDATES: Array[Dictionary] = [
	{"id": "gu_seon_bok", "name": "구선복", "require_hired": true, "title": "훈련대장 구선복"},
	{"id": "hong_remnant", "name": "홍국영 일파 잔당", "require_hired": false, "title": "세도 구세력 잔당"},
	{"id": "byeokpa_lord", "name": "벽파 중신 심씨 일문", "require_hired": false, "title": "조정 벽파 권신"},
	{"id": "local_warlord", "name": "안산 토호 무장 박씨", "require_hired": false, "title": "기호 지방 토호"}
]
## PORT-TRACE [서학 디버프·연구]: 보유론·서기수용론 연구 완료 여부, 장용영 사열을 한 해(연도)
var boyuron := false
var segi_policy := false
var jangyong_review_year := 0
var tech_tree: Node = null
var crown_prince_manager: CrownPrinceEducationManager = null
var uigwe_manager: UigweManager = null
var court_ref: Node = null
var total_gov_cell_count: int = 0 # 완공된 관공서 점유 셀 수 캐시 (O(1) 턴당 유지비 계산용)
var seojangdae_drill_cd_months: int = 0 # 서장대 연례 야조 훈련 쿨다운 (12개월 = 1년 주기)
var yeonmudae_drill_cd_months: int = 0  # 연무대 연례 무예 사열 쿨다운 (12개월 = 1년 주기)
var military_drill_manager: Node = null
var haenggung_completed: bool = false # 화성행궁 완공 여부 (기본 공격력 500 활성화 플래그)
var trial_manager: TrialManager = null # 화성유수부 원옥 친국·송사 매니저


# 국책 대역사 목록 (턴 단위 공기 및 4대 권역 완전 연결 성곽 고증 개편)
const MEGA_PROJECTS_DEFAULT: Array[Dictionary] = [
	{
		"id": "suwon_levee",
		# 수원천 양안 제방 (TurnSystem.setup에서 실제 물길 양안 전체로 확장 연동)
		"target_tiles": [{"x":29,"y":22,"building":"levee"},{"x":42,"y":22,"building":"levee"},{"x":29,"y":32,"building":"levee"},{"x":42,"y":32,"building":"levee"},{"x":29,"y":42,"building":"levee"},{"x":42,"y":42,"building":"levee"},{"x":29,"y":51,"building":"levee"},{"x":29,"y":54,"building":"levee"}],
		"name": "수원천 석축 제방 대역사",
		"base_turns": 4, # 기존 대비 2배 연장 (4턴 = 4개월)
		"progress_turns": 0,
		"cost_per_turn_gold": 1000,
		"cost_per_turn_rice": 1000,
		"base_ticks": 4, # 호환용
		"progress_ticks": 0,
		"cost_per_tick_gold": 1000,
		"cost_per_tick_rice": 1000,
		"is_started": false,
		"is_completed": false,
		"reward_flood_defense": 100,
		"reward_msg": "수원천 석축 제방이 완공되어 치수 방재율 100%를 달성했습니다!"
	},
	{
		"id": "manseok_reservoir",
		# 웅장한 만석거 본체 저수지와 부속 정자인 영화정(2x2), 대유둔전 관개 단지 세트 일괄 축조
		"target_tiles": [
			{"x":8,"y":2,"building":"manseokgeo"},{"x":9,"y":2,"building":"manseokgeo_site"},{"x":10,"y":2,"building":"manseokgeo_site"},
			{"x":8,"y":3,"building":"manseokgeo_site"},{"x":9,"y":3,"building":"manseokgeo_site"},{"x":10,"y":3,"building":"manseokgeo_site"},
			{"x":8,"y":4,"building":"manseokgeo_site"},{"x":9,"y":4,"building":"manseokgeo_site"},{"x":10,"y":4,"building":"manseokgeo_site"},
			{"x":11,"y":3,"building":"yeonghwajeong"},{"x":12,"y":3,"building":"yeonghwajeong_site"},
			{"x":11,"y":4,"building":"yeonghwajeong_site"},{"x":12,"y":4,"building":"yeonghwajeong_site"},
			{"x":10,"y":5,"building":"canal"},{"x":11,"y":5,"building":"canal"},{"x":12,"y":5,"building":"canal"},
			{"x":13,"y":3,"building":"agr_2"},{"x":14,"y":3,"building":"agr_2"},{"x":13,"y":4,"building":"agr_2"},{"x":14,"y":4,"building":"agr_2"}
		],
		"name": "만석거 및 대유둔전 관개 대역사",
		"base_turns": 4, # 역사 고증 4개월 (4턴)
		"progress_turns": 0,
		"cost_per_turn_gold": 1250, # 총액 금 5,000냥 / 4턴 분할
		"cost_per_turn_rice": 250,  # 총액 곡 1,000석 / 4턴 분할
		"base_ticks": 4,
		"progress_ticks": 0,
		"cost_per_tick_gold": 1250,
		"cost_per_tick_rice": 250,
		"is_started": false,
		"is_completed": false,
		"reward_flood_defense": 20,
		"reward_msg": "만석거 본체와 영화정이 완공되어 대유둔전 관개 수로에 물이 넘쳐납니다!"
	},
	{
		"id": "paldal_fortress",
		# 팔달산 남단(10,51)에서 화서문(6,13)까지 서성곽 완전 연결(서장대는 별도 건물 — 이 대역사와 무관)
		"target_tiles": [
			{"x": 10, "y": 51, "building": "wall"}, {"x": 10, "y": 50, "building": "wall"}, {"x": 9, "y": 49, "building": "wall"}, {"x": 9, "y": 48, "building": "wall"},
			{"x": 8, "y": 47, "building": "wall"}, {"x": 8, "y": 46, "building": "wall"}, {"x": 7, "y": 45, "building": "wall"}, {"x": 7, "y": 44, "building": "wall"},
			{"x": 7, "y": 43, "building": "wall"}, {"x": 7, "y": 42, "building": "wall"}, {"x": 6, "y": 41, "building": "wall"}, {"x": 6, "y": 40, "building": "wall"},
			{"x": 6, "y": 39, "building": "wall"}, {"x": 6, "y": 38, "building": "wall"}, {"x": 6, "y": 37, "building": "wall"}, {"x": 6, "y": 36, "building": "wall"},
			{"x": 6, "y": 35, "building": "wall"}, {"x": 6, "y": 34, "building": "wall"}, {"x": 6, "y": 33, "building": "wall"}, {"x": 6, "y": 32, "building": "wall"},
			{"x": 6, "y": 31, "building": "wall"}, {"x": 6, "y": 30, "building": "wall"}, {"x": 6, "y": 29, "building": "wall"}, {"x": 6, "y": 28, "building": "wall"},
			{"x": 6, "y": 27, "building": "wall"}, {"x": 6, "y": 26, "building": "wall"}, {"x": 6, "y": 25, "building": "wall"}, {"x": 6, "y": 24, "building": "wall"},
			{"x": 6, "y": 23, "building": "wall"}, {"x": 6, "y": 22, "building": "wall"}, {"x": 6, "y": 21, "building": "wall"}, {"x": 6, "y": 20, "building": "wall"},
			{"x": 6, "y": 19, "building": "wall"}, {"x": 6, "y": 18, "building": "wall"}, {"x": 6, "y": 17, "building": "wall"}, {"x": 6, "y": 16, "building": "wall"},
			{"x": 6, "y": 15, "building": "wall"}, {"x": 6, "y": 14, "building": "wall"}, {"x": 6, "y": 13, "building": "gate"}
		],
		"name": "팔달산 능선 서성곽 대역사",
		"structures": [{"kind": "gongsimdon", "type": "seobuk", "x": 6, "y": 20}], # 대역사 완공 때 함께 세우는 공심돈·포루(종류와 대략의 자리)
		"base_turns": 12, # 성곽 대역사 공기 12턴(1년)
		"progress_turns": 0,
		"cost_per_turn_gold": 3000, # 턴당 부담 상향(공기 단축)
		"cost_per_turn_rice": 1000,
		"base_ticks": 12,
		"progress_ticks": 0,
		"cost_per_tick_gold": 3000,
		"cost_per_tick_rice": 1000,
		"is_started": false,
		"is_completed": false,
		"reward_flood_defense": 0,
		"reward_msg": "팔달산 서성곽과 화서문이 우뚝 솟아 서부 방어선이 빈틈없이 완전 연결되었습니다! 서북공심돈도 함께 세워졌습니다!"
	},
	{
		"id": "hwahong_north",
		# 화서문(6,13)부터 장안문(26,6), 화홍문 수문교(35,13)를 거쳐 동북 능선(43,18)까지 북성곽 완전 연결
		"target_tiles": [
			{"x": 6, "y": 13, "building": "gate"}, {"x": 7, "y": 12, "building": "wall"}, {"x": 7, "y": 11, "building": "wall"}, {"x": 8, "y": 10, "building": "wall"},
			{"x": 8, "y": 9, "building": "wall"}, {"x": 9, "y": 8, "building": "wall"}, {"x": 9, "y": 7, "building": "wall"}, {"x": 10, "y": 6, "building": "wall"},
			{"x": 11, "y": 6, "building": "wall"}, {"x": 12, "y": 6, "building": "wall"}, {"x": 13, "y": 6, "building": "wall"}, {"x": 14, "y": 6, "building": "wall"},
			{"x": 15, "y": 6, "building": "wall"}, {"x": 16, "y": 6, "building": "wall"}, {"x": 17, "y": 6, "building": "wall"}, {"x": 18, "y": 6, "building": "wall"},
			{"x": 19, "y": 6, "building": "wall"}, {"x": 20, "y": 6, "building": "wall"}, {"x": 21, "y": 6, "building": "wall"}, {"x": 22, "y": 6, "building": "wall"},
			{"x": 23, "y": 6, "building": "wall"}, {"x": 24, "y": 6, "building": "wall"}, {"x": 25, "y": 6, "building": "wall"}, {"x": 26, "y": 6, "building": "gate"},
			{"x": 27, "y": 7, "building": "wall"}, {"x": 28, "y": 8, "building": "wall"}, {"x": 29, "y": 8, "building": "wall"}, {"x": 30, "y": 9, "building": "wall"},
			{"x": 31, "y": 10, "building": "wall"}, {"x": 32, "y": 11, "building": "wall"}, {"x": 33, "y": 11, "building": "wall"}, {"x": 34, "y": 12, "building": "wall"},
			{"x": 35, "y": 13, "building": "hwahong"}, {"x": 36, "y": 14, "building": "wall"}, {"x": 37, "y": 14, "building": "wall"}, {"x": 38, "y": 15, "building": "wall"},
			{"x": 39, "y": 15, "building": "wall"}, {"x": 40, "y": 16, "building": "wall"}, {"x": 41, "y": 17, "building": "wall"}, {"x": 42, "y": 17, "building": "wall"},
			{"x": 43, "y": 18, "building": "wall"}
		],
		"name": "화홍문 및 장안문 북성곽 대역사",
		"structures": [{"kind": "poru", "type": "bukseo", "x": 12, "y": 6}, {"kind": "poru", "type": "buk", "x": 20, "y": 6}], # 대역사 완공 때 함께 세우는 공심돈·포루(종류와 대략의 자리)
		"base_turns": 12, # 성곽 대역사 공기 12턴(1년)
		"progress_turns": 0,
		"cost_per_turn_gold": 3000, # 턴당 부담 상향(공기 단축)
		"cost_per_turn_rice": 1000,
		"base_ticks": 12,
		"progress_ticks": 0,
		"cost_per_tick_gold": 3000,
		"cost_per_tick_rice": 1000,
		"is_started": false,
		"is_completed": false,
		"reward_flood_defense": 0,
		"reward_msg": "화홍문 북수문과 장안문 북성곽이 틈새 없이 완전 연결되었습니다! 북서포루와 북포루도 함께 세워졌습니다!"
	},
	{
		"id": "changryong_east",
		# 동북 능선(43,18)부터 창룡문(48,29)을 거쳐 남수문 인근(29,54)까지 동성곽 완전 연결
		"target_tiles": [
			{"x": 43, "y": 18, "building": "wall"}, {"x": 44, "y": 19, "building": "wall"}, {"x": 45, "y": 20, "building": "wall"}, {"x": 46, "y": 21, "building": "wall"},
			{"x": 47, "y": 22, "building": "wall"}, {"x": 48, "y": 23, "building": "wall"}, {"x": 48, "y": 24, "building": "wall"}, {"x": 48, "y": 25, "building": "wall"},
			{"x": 48, "y": 26, "building": "wall"}, {"x": 48, "y": 27, "building": "wall"}, {"x": 48, "y": 28, "building": "wall"}, {"x": 48, "y": 29, "building": "gate"},
			{"x": 48, "y": 30, "building": "wall"}, {"x": 48, "y": 31, "building": "wall"}, {"x": 47, "y": 32, "building": "wall"}, {"x": 47, "y": 33, "building": "wall"},
			{"x": 47, "y": 34, "building": "wall"}, {"x": 47, "y": 35, "building": "wall"}, {"x": 46, "y": 36, "building": "wall"}, {"x": 46, "y": 37, "building": "wall"},
			{"x": 46, "y": 38, "building": "wall"}, {"x": 45, "y": 39, "building": "wall"}, {"x": 44, "y": 40, "building": "wall"}, {"x": 44, "y": 41, "building": "wall"},
			{"x": 43, "y": 42, "building": "wall"}, {"x": 42, "y": 43, "building": "wall"}, {"x": 41, "y": 44, "building": "wall"}, {"x": 40, "y": 45, "building": "wall"},
			{"x": 40, "y": 46, "building": "wall"}, {"x": 39, "y": 47, "building": "wall"}, {"x": 38, "y": 48, "building": "wall"}, {"x": 37, "y": 49, "building": "wall"},
			{"x": 36, "y": 49, "building": "wall"}, {"x": 35, "y": 50, "building": "wall"}, {"x": 34, "y": 51, "building": "wall"}, {"x": 33, "y": 51, "building": "wall"},
			{"x": 32, "y": 52, "building": "wall"}, {"x": 31, "y": 53, "building": "wall"}, {"x": 30, "y": 53, "building": "wall"}, {"x": 29, "y": 54, "building": "wall"}
		],
		"name": "창룡문 권역 동성곽 대역사",
		"structures": [{"kind": "gongsimdon", "type": "dongbuk", "x": 48, "y": 26}, {"kind": "poru", "type": "dongbuk", "x": 48, "y": 31}], # 대역사 완공 때 함께 세우는 공심돈·포루(종류와 대략의 자리)
		"base_turns": 12, # 성곽 대역사 공기 12턴(1년)
		"progress_turns": 0,
		"cost_per_turn_gold": 3000, # 턴당 부담 상향(공기 단축)
		"cost_per_turn_rice": 1000,
		"base_ticks": 12,
		"progress_ticks": 0,
		"cost_per_tick_gold": 3000,
		"cost_per_tick_rice": 1000,
		"is_started": false,
		"is_completed": false,
		"reward_flood_defense": 0,
		"reward_msg": "창룡문과 동성곽이 우뚝 솟아 동부 방어선이 완전 연결되었습니다! 동북공심돈과 동북포루도 함께 세워졌습니다!"
	},
	{
		"id": "namsu_south",
		# 남수문(29,54)부터 팔달문(16,54)을 거쳐 팔달산 남단(10,51)까지 남성곽 완전 연결
		"target_tiles": [
			{"x": 29, "y": 54, "building": "wall"}, {"x": 28, "y": 54, "building": "wall"}, {"x": 27, "y": 54, "building": "wall"}, {"x": 26, "y": 54, "building": "wall"},
			{"x": 25, "y": 54, "building": "wall"}, {"x": 24, "y": 54, "building": "wall"}, {"x": 23, "y": 54, "building": "wall"}, {"x": 22, "y": 54, "building": "wall"},
			{"x": 21, "y": 54, "building": "wall"}, {"x": 20, "y": 54, "building": "wall"}, {"x": 19, "y": 54, "building": "wall"}, {"x": 18, "y": 54, "building": "wall"},
			{"x": 17, "y": 54, "building": "wall"}, {"x": 16, "y": 54, "building": "gate"}, {"x": 15, "y": 54, "building": "wall"}, {"x": 14, "y": 53, "building": "wall"},
			{"x": 13, "y": 53, "building": "wall"}, {"x": 12, "y": 52, "building": "wall"}, {"x": 11, "y": 52, "building": "wall"}, {"x": 10, "y": 51, "building": "wall"}
		],
		"name": "남수문 및 팔달문 권역 남성곽 대역사",
		"structures": [{"kind": "gongsimdon", "type": "nam", "x": 20, "y": 54}, {"kind": "poru", "type": "nam", "x": 26, "y": 54}], # 대역사 완공 때 함께 세우는 공심돈·포루(종류와 대략의 자리)
		"base_turns": 12, # 성곽 대역사 공기 12턴(1년)
		"progress_turns": 0,
		"cost_per_turn_gold": 3000, # 턴당 부담 상향(공기 단축)
		"cost_per_turn_rice": 1000,
		"base_ticks": 12,
		"progress_ticks": 0,
		"cost_per_tick_gold": 3000,
		"cost_per_tick_rice": 1000,
		"is_started": false,
		"is_completed": false,
		"reward_flood_defense": 0,
		"reward_msg": "남수문과 팔달문 남성곽이 연결되어 남부 관문 방어선이 완전 연결되었습니다! 남공심돈과 남포루도 함께 세워졌습니다!"
	}
]
var mega_projects: Array = MEGA_PROJECTS_DEFAULT.duplicate(true)

## PORT-TRACE P2: 대역사 발주 (TS startMegaProject). 첫 턴 비용 검사 후 착공.
func start_mega_project(id: String, target_grid: GameGrid = null) -> Dictionary:
	var active_grid: GameGrid = target_grid if target_grid != null else grid_ref
	if active_grid != null:
		sync_mega_projects_with_grid(active_grid)
	for p in mega_projects:
		if p["id"] != id:
			continue
		if bool(p.get("is_completed", false)):
			return {"success": false, "msg": "이미 완공된 사업입니다."}
		if bool(p.get("is_disabled", false)):
			return {"success": false, "msg": str(p.get("disabled_msg", "직접 지으신 시설이 있어 이 대역사는 쓸 수 없습니다."))}
		if bool(p.get("is_started", false)):
			return {"success": false, "msg": "이미 공사가 진행 중입니다."}
		if id == "defense_fortification" and active_grid != null:
			if active_grid.count_completed("wall") == 0:
				return {"success": false, "msg": "성곽을 먼저 축조해야 합니다"}
		var raw_gold: int = int(p.get("cost_per_turn_gold", p.get("cost_per_tick_gold", 0)))
		var raw_rice: int = int(p.get("cost_per_turn_rice", p.get("cost_per_tick_rice", 0)))
		var cg: int = int(ceil(raw_gold * (0.75 if retainers.get("chae_jegong", false) else 1.0) * (0.80 if retainers.get("kim_bau", false) else 1.0)))
		var cr: int = int(ceil(raw_rice * (0.75 if retainers.get("chae_jegong", false) else 1.0) * (0.80 if retainers.get("kim_bau", false) else 1.0)))
		if gold < cg or rice < cr:
			return {"success": false, "msg": "착공에 필요한 국고나 군량이 부족하옵니다!"}
		p["is_started"] = true
		p["is_paused"] = false
		emit_signal("project_started", id)
		emit_signal("state_updated", gold, rice, population, loyalty, flood_defense)
		return {"success": true, "msg": "어명을 받들어 [%s] 대역사에 착공하였습니다!" % p["name"]}
	return {"success": false, "msg": "해당 국책사업이 존재하지 않습니다."}

func _init() -> void:
	if pop_manager == null:
		pop_manager = PopulationManager.new(population)
	if tech_tree == null:
		tech_tree = TechTreeManager.new()
	if crown_prince_manager == null:
		crown_prince_manager = CrownPrinceEducationManager.new()
	if uigwe_manager == null:
		uigwe_manager = UigweManager.new()

func _ready() -> void:
	if pop_manager == null:
		pop_manager = PopulationManager.new(population)
	if tech_tree == null:
		tech_tree = TechTreeManager.new()
	if crown_prince_manager == null:
		crown_prince_manager = CrownPrinceEducationManager.new()
	if uigwe_manager == null:
		uigwe_manager = UigweManager.new()
	if tech_tree and not tech_tree.is_inside_tree():
		add_child(tech_tree)
	if crown_prince_manager and not crown_prince_manager.is_inside_tree():
		add_child(crown_prince_manager)
	if uigwe_manager and not uigwe_manager.is_inside_tree():
		add_child(uigwe_manager)
	emit_signal("state_updated", gold, rice, population, loyalty, flood_defense)


## 달(1~12) → 계절 번호(0 봄 3~5월, 1 여름 6~8월, 2 가을 9~11월, 3 겨울 12~2월). TimeManager.get_current_season과 같다.
static func season_of_month(m: int) -> int:
	if m >= 3 and m <= 5:
		return 0
	if m >= 6 and m <= 8:
		return 1
	if m >= 9 and m <= 11:
		return 2
	return 3

## 지금 달(1~12). 1턴 = 1789년 1월부터 한 달씩.
func month_now() -> int:
	return posmod(turn - 1, 12) + 1

## 지금 계절 번호
func season_now() -> int:
	return season_of_month(month_now())

## TimeManager의 simulation_tick 시그널에 바인딩
func on_simulation_tick(total_ticks: int) -> void:
	if is_time_frozen:
		return

	# 10틱(=열흘) 단위: RCI 수요 및 미세 인구 변동
	if total_ticks % 10 == 0:
		_update_rci_demands()

	# 30틱(=1개월 = 1턴) 단위: 턴 진행, 호조 조세 수취 및 군량 소비, 국책 대역사 턴 공정
	if total_ticks % 30 == 0:
		_advance_monthly_turn(total_ticks)

	emit_signal("state_updated", gold, rice, population, loyalty, flood_defense)

func _advance_monthly_turn(ticks: int) -> void:
	turn += 1
	var total_months: int = int(float(ticks) / 30.0)
	current_year = 1789 + int(float(total_months) / 12.0)
	var month_idx: int = (total_months % 12) + 1
	var season_cycle: int = season_of_month(month_idx)
	var season_start: bool = month_idx in [3, 6, 9, 12]

	# 인게임 재난 쿨타임 감소 (1턴 = 1개월)
	if tiger_cooldown_turns > 0:
		tiger_cooldown_turns -= 1
	if bandit_suppression_turns > 0:
		bandit_suppression_turns -= 1
	if seojangdae_drill_cd_months > 0:
		seojangdae_drill_cd_months -= 1
	if yeonmudae_drill_cd_months > 0:
		yeonmudae_drill_cd_months -= 1
	if month_idx == 1 and current_year > 1789:
		_apply_annual_drill_decay()

	# 자연재해 지속 턴 감소 처리 (1계절 지속)
	var has_jh: bool = false
	if grid_ref != null:
		has_jh = (grid_ref.count_completed("jinhulso") > 0)
	elif pop_manager != null and pop_manager.has_method("has_welfare_facility"):
		has_jh = pop_manager.has_welfare_facility("jinhulso")

	if flood_crisis_active:
		flood_crisis_turns_left -= 1
		if not has_jh:
			loyalty = maxi(0, loyalty - 2) # 진휼소 부재 시 수해 민심 추가 하락(달마다 -2, 한 계절 -6)
		if flood_crisis_turns_left <= 0:
			end_flood_crisis()
	if drought_active:
		drought_turns_left -= 1
		if not has_jh:
			loyalty = maxi(0, loyalty - 2) # 진휼소 부재 시 가뭄 민심 추가 하락(달마다 -2)
		if drought_turns_left <= 0:
			drought_active = false
	if plague_active:
		plague_turns_left -= 1
		if not has_jh:
			loyalty = maxi(0, loyalty - 2) # 진휼소 부재 시 역병 민심 추가 하락(달마다 -2)
		if plague_turns_left <= 0:
			plague_active = false

	# 월 예산 조세 및 군량 소비
	_process_monthly_budget()

	# 국책 대역사 턴 공정 진행 (턴당 비용 차감 및 인재 버프 적용)
	_process_mega_projects()

	# 실학 연구 턴 정산 진행 (턴당 국고 1,000냥 지속 소모 및 진척도 가산)
	process_turn_research()

	# 세자 교육 턴 정산 진행 (매 턴 국고 2,000냥*배율 지속 소모 및 학문력 비례 게이지 상승)
	process_turn_crown_prince_education()

	# 규장각 의궤 편찬 턴 정산 진행 (학문력 연동 턴당 상승률 가산 및 연간 비용 차감)
	process_turn_uigwe()

	# 폐가화 동역학 및 인구 유출 정산 (약탈/침략 폐가 존재 시 인구 -1%, 진압 시 서서히 복구)
	if grid_ref != null:
		BuildingManager.process_ruined_buildings_turn(grid_ref, self)
		if not bandit_active and (bandit_manager == null or not bandit_manager.is_raid_active):
			BuildingManager.restore_ruined_buildings(grid_ref, self)


	# [process_seasonal_population은 Main.gd의 season_changed 핸들러에서 단독 호출]
	# 이 위치에서 직접 호출하면 season_changed 시그널 핸들러와 이중 실행되어 인구/세수가 2배 처리됨

	# 사병 음모 턴 쿨타임 감소 (실시간 타이머 금지, 오직 턴 정산 시에만 감소)
	if conspiracy_cooldown_turns > 0:
		conspiracy_cooldown_turns -= 1

	emit_signal("turn_advanced", turn, season_cycle, current_year)
	if season_start:
		emit_signal("season_advanced", season_cycle, current_year)

	# 계절 재난 판정 (여름 장마철: 7월)
	if month_idx == 7:
		if flood_defense < 50:
			var damage_gold: int = 150
			var damage_rice: int = 100
			var def_ratio: float = clampf(float(flood_defense) / 100.0, 0.0, 0.8)
			damage_gold = int(float(damage_gold) * (1.0 - def_ratio))
			damage_rice = int(float(damage_rice) * (1.0 - def_ratio))
			gold = max(0, gold - damage_gold)
			rice = max(0, rice - damage_rice)
			loyalty = max(0, loyalty - 8)
			var flood_msg: String = "수원천이 집중호우로 범람하여 가옥이 침수되고 군량이 유실되었습니다! 수해 비상 대피 체제가 발령됩니다."
			emit_signal("disaster_alert", flood_msg)
			if EventManager.instance != null:
				EventManager.instance.enqueue_disaster("수원천 범람 수해", flood_msg, {
					"gold": damage_gold, "rice": damage_rice, "loyalty": 8
				})
			emit_signal("academic_hit", 4, "수해") # 학당·서책이 물에 잠김
			trigger_flood_crisis(3) # 한 계절(3개월)
		else:
			loyalty = min(100, loyalty + 5)
			emit_signal("disaster_alert", "수원천 석축 제방이 큰 장마를 완벽히 막아내어 백성들이 안도합니다.")

## 실학 연구 턴 정산 진행 (턴당 국고 1,000냥 지속 소모 및 진척도 가산)
func process_turn_research() -> Dictionary:
	if tech_tree != null:
		var has_lee_deokmu: bool = bool(retainers.get("lee_deokmu", false))
		var acad_power: int = CityStats.get_academic_power()
		if acad_power == 0 and academic > 0:
			acad_power = academic
		return tech_tree.process_turn_research(acad_power, self, has_lee_deokmu, true)
	return {}


func is_scholar_or_general_hired(cid: String) -> bool:
	if cid in ["gu_seon_bok", "gu_seonbok"]:
		return bool(retainers.get("gu_seonbok", false)) or bool(retainers.get("gu_seon_bok", false)) or ScholarManager.is_scholar_hired("gu_seonbok")
	return ScholarManager.is_scholar_hired(cid, retainers)

## 현재 상황에 맞는 사병 모집 주모자 선정 (동적 주모자 풀)
func select_available_conspirator() -> Dictionary:
	for cand in CONSPIRATOR_CANDIDATES:
		var cid: String = str(cand["id"])
		if purged_conspirators.has(cid):
			continue
		if bool(cand.get("require_hired", false)) and not is_scholar_or_general_hired(cid):
			continue
		return cand
	return {"id": "generic_traitor_" + str(turn), "name": "불만을 품은 구군영 장수", "title": "구군영 반발 세력"}

## 왕권 수치 가감 및 전역 동기화
func add_royal_authority(amount: int) -> void:
	authority = clampi(authority + amount, 0, 100)
	CityStats.set_royal_power(authority)
	emit_signal("state_updated", gold, rice, population, loyalty, flood_defense)

## 인재/장수 등용 해임 및 숙청 처리
func dismiss_hired_character(char_id: String) -> void:
	if char_id in ["gu_seon_bok", "gu_seonbok"]:
		retainers["gu_seonbok"] = false
		retainers["gu_seon_bok"] = false
		ScholarManager.hired_scholars.erase("gu_seonbok")
		ScholarManager.hired_scholars.erase("gu_seon_bok")
		if court_ref != null and court_ref.has_method("update_faction_and_academic"):
			court_ref.update_faction_and_academic()

## [백동수 압수수색 / 강경 처단] 선택 시 (왕권 강화 및 해당 주모자 숙청)
func on_conspiracy_crackdown_selected() -> String:
	var target_name: String = active_conspirator_name if active_conspirator_name != "" else "반란 주모자"
	if active_conspirator_id != "":
		purged_conspirators[active_conspirator_id] = true
		if active_conspirator_id in ["gu_seon_bok", "gu_seonbok"]:
			dismiss_hired_character("gu_seon_bok")

	add_royal_authority(10) # 왕권 +10 강화

	active_conspirator_id = ""
	active_conspirator_name = ""
	conspiracy_stage = 0
	conspiracy_cooldown_turns = randi_range(24, 36) # 2~3년(24~36개월) 휴지기 쿨타임
	is_conspiracy_decision_pending = false

	return "⚔️ 백동수가 [%s]의 사병 본거지를 급습하여 압수수색하고 역모를 평정했습니다! (왕권 +10)" % target_name

## [묵인 / 관망] 선택 시 (영구 락 금지 -> 1년~1년 반 뒤 재보고 및 3회 누적 시 실제 반란)
func on_conspiracy_ignore_selected() -> String:
	conspiracy_stage += 1
	add_royal_authority(-3) # 묵인으로 인한 왕권 미세 하락

	var target_name: String = active_conspirator_name if active_conspirator_name != "" else "사병 세력"
	var msg: String = ""

	if conspiracy_stage >= 3:
		# 3회 연속 묵인 시 실제 반란군 봉기 발생
		msg = "🔥 [%s]의 사병들이 끝내 반란을 일으켜 화성행궁으로 진격합니다!" % target_name
		RebellionManager.spawn_rebel_invasion(target_name, self)
		if active_conspirator_id != "":
			purged_conspirators[active_conspirator_id] = true
		active_conspirator_id = ""
		conspiracy_stage = 0
		conspiracy_cooldown_turns = 30
	else:
		# 12~18개월 뒤에 동일 주모자의 사병 보고가 다시 올라옴
		msg = "⚠️ [%s]의 사병 훈련을 묵인했습니다. 세력이 은밀히 확장되고 있습니다." % target_name
		conspiracy_cooldown_turns = randi_range(12, 18)

	is_conspiracy_decision_pending = false
	return msg

## 수해(홍수) 위기 발동
func trigger_flood_crisis(p_turns: int = 3) -> void:
	flood_crisis_active = true
	flood_crisis_turns_left = p_turns
	emit_signal("flood_crisis_started")
	var has_jh: bool = false
	if grid_ref != null:
		has_jh = (grid_ref.count_completed("jinhulso") > 0)
	elif pop_manager != null and pop_manager.has_method("has_welfare_facility"):
		has_jh = pop_manager.has_welfare_facility("jinhulso")

	if not has_jh:
		loyalty = maxi(0, loyalty - 12)
		var alert_msg: String = "🌊 [수해 위기 발생] 수원천이 범람하였으나 이재민을 구제할 진휼소가 없어 백성들이 큰 고통을 겪고 있습니다! (민심 대폭 하락 -12)"
		emit_signal("disaster_alert", alert_msg)
		if EventManager.instance != null:
			EventManager.instance.enqueue_disaster("수해 구휼 위기", alert_msg, {"loyalty": 12})
	else:
		loyalty = maxi(0, loyalty - 3)
		emit_signal("disaster_alert", "🌊 [수해 위기 발생] 수원천이 범람하였으나 진휼소에서 수재민들에게 따뜻한 밥과 쉼터를 제공하여 민심을 지켜냈습니다.")
	emit_signal("state_updated", gold, rice, population, loyalty, flood_defense)

func end_flood_crisis() -> void:
	flood_crisis_active = false
	flood_crisis_turns_left = 0
	emit_signal("flood_crisis_ended")
	emit_signal("disaster_alert", "수해가 잦아들고 물길이 안정되어 저잣거리와 생산 시설이 일상을 되찾았습니다.")
	emit_signal("state_updated", gold, rice, population, loyalty, flood_defense)

func _process_mega_projects() -> void:
	for p in mega_projects:
		if p["is_started"] and not p["is_completed"]:
			var cost_gold: int = int(p.get("cost_per_turn_gold", p.get("cost_per_tick_gold", 0)))
			var cost_rice: int = int(p.get("cost_per_turn_rice", p.get("cost_per_tick_rice", 0)))

			# 채제공 총리대신: 공사비 25% 절감
			if retainers.get("chae_jegong", false):
				cost_gold = int(ceil(cost_gold * 0.75))
				cost_rice = int(ceil(cost_rice * 0.75))

			# 서기수용론: 이용후생 — 대역사 비용 -20%
			if segi_policy:
				cost_gold = int(ceil(cost_gold * 0.8))
				cost_rice = int(ceil(cost_rice * 0.8))

			# 홍인한(척신): 개혁 대역사 비용 +10%
			if retainers.get("hong_inhan", false):
				cost_gold = int(ceil(cost_gold * 1.1))
				cost_rice = int(ceil(cost_rice * 1.1))

			# 김바우 석수 명장: 턴당 투입 자원(금/곡) 20% 추가 할인
			if retainers.get("kim_bau", false):
				cost_gold = int(ceil(cost_gold * 0.80))
				cost_rice = int(ceil(cost_rice * 0.80))

			var was_paused: bool = bool(p.get("is_paused", false))

			# 재정(금화/군량) 부족 시: 사업 취소 없이 진행 일시 멈춤(Pause)
			if gold < cost_gold or rice < cost_rice:
				if not was_paused:
					p["is_paused"] = true
					var pause_msg: String = "[%s] 대역사의 재정이 부족하여 공사가 일시 멈추었습니다. (필요: 금 %d냥, 곡 %d석)" % [p["name"], cost_gold, cost_rice]
					emit_signal("project_paused", str(p["id"]), pause_msg)
					emit_signal("disaster_alert", pause_msg)
				continue

			# 재정 충족 시: 이전에 일시 멈춤 상태였다면 자동 속개(Resume)
			if was_paused:
				p["is_paused"] = false
				var resume_msg: String = "국고가 확충되어 일시 중단되었던 [%s] 대역사 공사를 재개하였습니다!" % [p["name"]]
				emit_signal("project_resumed", str(p["id"]), resume_msg)

			gold -= cost_gold
			rice -= cost_rice
			
			# 정약용 거중기: 35% 공기 단축 (진행도 가속 누적)
			if not p.has("progress_float"):
				p["progress_float"] = float(p.get("progress_turns", p.get("progress_ticks", 0)))
			var turn_gain: float = 1.35 if retainers.get("jeong_yakyong", false) else 1.0
			# 심환지(벽파 영수) 등용 시 태업 — 공기 20% 지연, 이기경이 정약용과 함께면 불화로 거중기 효과 반감
			if retainers.get("sim_hwanji", false):
				turn_gain *= 0.8
			if retainers.get("lee_gigyeong", false) and retainers.get("jeong_yakyong", false):
				turn_gain = 1.0 + (turn_gain - 1.0) * 0.5
			p["progress_float"] += turn_gain
			p["progress_turns"] = int(p["progress_float"])
			p["progress_ticks"] = p["progress_turns"]

			var base_req: int = int(p.get("base_turns", p.get("base_ticks", 12)))
			if p["progress_turns"] >= base_req:
				p["is_completed"] = true
				p["is_started"] = false
				p["is_paused"] = false
				if p["reward_flood_defense"] > 0:
					flood_defense = min(100, flood_defense + p["reward_flood_defense"])
				if p["id"] == "defense_fortification":
					military_power += 50
				var p_name: String = str(p.get("name", p.get("reward_msg", "국책 대역사")))
				emit_signal("project_completed", p_name)
				emit_signal("project_finished", p["id"]) # PORT-TRACE P2

func _update_rci_demands() -> void:
	# 심시티 2000 RCI 수요 함수
	var target_pop = population
	demand_res = clamp(60 + int((loyalty - 70) * 0.5) - int((tax_rate_military - 7) * 4), -100, 100)
	demand_com = clamp(40 + int(target_pop * 0.1) - int((tax_rate_market - 7) * 5), -100, 100)
	demand_agr = clamp(45 + int(max(0, target_pop * 2 - rice) * 0.05) - int((tax_rate_land - 7) * 4), -100, 100)

	# 인구 자연 증감 (기근 중에는 자연 유입 0명 고정)
	if demand_res > 20 and rice > 100 and not famine_active:
		population += 1

## 지난 한 달 동안 국고가 늘거나 준 양(세수·유지비·녹봉·공사비 모두 포함) — 김판관 재정 조언용.
## 턴(TurnSystem)이 끝날 때마다 지난 턴 끝과 비교해 채운다(월 예산은 턴 중간에 돌아 그 사이 값으로는 정확히 잴 수 없다).
var last_month_gold_delta: int = 0
var gold_at_last_budget: int = -1
## 최근 석 달의 달별 국고 변화(계절 세수 몰림을 고르게 보려고)
var recent_gold_deltas: Array[int] = []

## 최근 석 달 국고 변화 합(석 달이 다 차지 않았으면 0 — 판단 보류)
func get_recent_season_gold_delta() -> int:
	if recent_gold_deltas.size() < 3:
		return 0
	var s := 0
	for d: int in recent_gold_deltas:
		s += d
	return s

func _process_monthly_budget() -> void:
	# 상업세, 전세(지대), 군포
	var market_tax: int = int(float(population) * 0.6 * (float(tax_rate_market) / 7.0))
	var land_tax: int = int(float(rice) * 0.03 * (float(tax_rate_land) / 7.0))
	gold += int(float(market_tax + land_tax) * TaxManager.revenue_mult(grid_ref)) # 쇠전·사대문 교역로 세입 가산

	# [공공시설 턴당 운영자금 및 도로 유지비 정산]
	# 행궁, 관아, 서장대, 연무대, 순라청, 멸화군, 성곽 방어시설, 사대문, 수문, 수리시설, 도로망 등 턴당 금화/곡식 일괄 정산
	last_maintenance_result = FacilityMaintenanceManager.apply_turn_maintenance(self, grid_ref)

	# [인구 비례 기본 식량 소모] 공식: floor(총인구 / 1000) × 10석
	# 예: 인구 1만 = 100석, 10만 = 1000석, 50만 = 5000석
	var food_consumption: int = int(floor(float(population) / 1000.0)) * 10
	# 최소 소모량 보장(소규모 인구용): 군사 유지 소모 포함
	food_consumption = maxi(food_consumption, int(float(population) / 10.0) + int(float(military_power) / 10.0))
	rice = maxi(0, rice - food_consumption)

	# [기근(Famine) 엔진]
	if rice <= 0:
		var has_jh: bool = false
		if grid_ref != null:
			has_jh = (grid_ref.count_completed("jinhulso") > 0)
		elif pop_manager != null and pop_manager.has_method("has_welfare_facility"):
			has_jh = pop_manager.has_welfare_facility("jinhulso")

		if not famine_active:
			famine_active = true
			if not has_jh:
				var fam_msg: String = "🚨 [기근 참상] 식량이 바닥났으나 구휼할 진휼소마저 없어 백성들이 굶주리고 원망이 하늘을 찌릅니다! (민심 대폭 하락 -15)"
				emit_signal("disaster_alert", fam_msg)
				if EventManager.instance != null:
					EventManager.instance.enqueue_disaster("기근 참상", fam_msg, {"loyalty": 15})
			else:
				emit_signal("disaster_alert", "🍲 [기근 발생·진휼 구제] 식량이 바닥났으나 진휼소에서 따뜻한 죽을 나누어 주어 기근 속에서도 민심의 동요를 막아냈습니다.")

		if not has_jh:
			# 진휼소 부재 시: 기근 대처 불가로 민심 대폭 하락 (-15) 및 아사/유민 유출 3%
			loyalty = maxi(0, loyalty - 15)
			var famine_pop_loss: int = maxi(1, int(float(population) * 0.03))
			population = maxi(0, population - famine_pop_loss)
		else:
			# 진휼소 완공 시: 구휼미 배급으로 민심 하락 대폭 완화 (-2) 및 아사자 최소화 (0.5%)
			loyalty = maxi(0, loyalty - 2)
			var famine_pop_loss: int = maxi(1, int(float(population) * 0.005))
			population = maxi(0, population - famine_pop_loss)

		if pop_manager != null:
			pop_manager.total_population = population
	else:
		# 식량 충족 시 기근 해제
		if famine_active:
			famine_active = false
			emit_signal("disaster_alert", "[기근 해소] 군량 창고가 채워져 백성들이 안정을 되찾았습니다.")

## 동적 쌀 시세 산출 (100석당 금화 냥)
## 계절, 작황(방재율/수리), 창고 쌀 재고량에 따른 실시간 변동
func get_rice_market_price_per_100() -> int:
	var base_price: float = 50.0

	# 1. 계절별 주기 효과 (0: 봄, 1: 여름, 2: 가을, 3: 겨울)
	var s_idx: int = season_now()
	match s_idx:
		0: base_price += 15.0 # 봄: 춘궁기(보릿고개) 쌀값 상승
		1: base_price += 6.0  # 여름: 장마 및 생육기 시세 상승
		2: base_price -= 16.0 # 가을: 벼 수확기 대풍으로 시세 대폭 하락
		3: base_price += 0.0  # 겨울: 안정세

	# 2. 창고 쌀 재고량에 따른 희소성 프리미엄/할인
	if rice < 300:
		base_price += 25.0 # 군량 기근 폭등
	elif rice < 700:
		base_price += 12.0 # 재고 부족
	elif rice > 2200:
		base_price -= 10.0 # 쌀 풍족

	# 3. 치수/작황 안전도 (수해 위험 시 쌀값 폭등)
	if flood_defense < 40:
		base_price += 10.0
	elif flood_defense >= 80:
		base_price -= 5.0

	return clampi(int(round(base_price)), 25, 95)

func get_rice_market_status() -> String:
	var s_idx: int = season_now()
	var p: int = get_rice_market_price_per_100()
	var desc: String = ""
	if rice < 400:
		desc = "군량 곳간이 바닥나 곡식 시세가 급등했습니다."
	elif s_idx == 0:
		desc = "봄철 춘궁기(보릿고개)로 쌀 시세가 높습니다."
	elif s_idx == 2:
		desc = "가을 수확기 풍년으로 삼남의 쌀 시세가 저렴합니다."
	elif flood_defense < 50:
		desc = "수해 우려로 곡물 시장이 불안정합니다."
	else:
		desc = "삼남로 물류가 원활하여 평년 시세를 유지하고 있습니다."
	return "현재 시세: 100석당 금 %d냥 (%s)" % [p, desc]

## 금화를 소모하여 곡식(식량)을 매입하는 상업/환곡 기능
func buy_rice(amount: int) -> Dictionary:
	if amount <= 0:
		return {"success": false, "msg": "매입할 수량을 올바르게 지정하십시오."}
	var price_per_100: int = get_rice_market_price_per_100()
	var total_cost: int = int(ceil(float(amount) / 100.0 * float(price_per_100)))

	if gold < total_cost:
		return {
			"success": false,
			"msg": "국고가 부족합니다! (필요: 금 %d냥, 보유: 금 %d냥)" % [total_cost, gold]
		}

	gold -= total_cost
	rice += amount
	emit_signal("state_updated", gold, rice, population, loyalty, flood_defense)
	return {
		"success": true,
		"cost": total_cost,
		"amount": amount,
		"msg": "환곡 상업으로 곡식 %d석을 매입하였습니다. (금 %d냥 지출)" % [amount, total_cost]
	}

## 곡식을 저잣거리에 내다 팔아 금을 얻는다. 파는 값은 사는 값의 80%(사고팔아 금을 불리지 못하게)
const RICE_SELL_RATIO := 0.8

func get_rice_sell_price_per_100() -> int:
	return maxi(1, int(floor(float(get_rice_market_price_per_100()) * RICE_SELL_RATIO)))

func sell_rice(amount: int) -> Dictionary:
	if amount <= 0:
		return {"success": false, "msg": "팔 수량을 올바르게 지정하십시오."}
	if rice < amount:
		return {"success": false, "msg": "곳간의 곡식이 부족합니다! (팔 곡식: %d석, 보유: %d석)" % [amount, rice]}
	var income: int = int(floor(float(amount) / 100.0 * float(get_rice_sell_price_per_100())))
	rice -= amount
	gold += income
	emit_signal("state_updated", gold, rice, population, loyalty, flood_defense)
	return {
		"success": true,
		"income": income,
		"amount": amount,
		"msg": "곳간의 곡식 %d석을 저잣거리에 내다 팔았습니다. (금 %d냥 수입)" % [amount, income]
	}

func update_fortress(grid: GameGrid) -> void:
	if not grid:
		return
	grid_ref = grid
	grid.recompute_infrastructure(retainers.get("jeong_yakyong", false))
	fortress_progress = grid.fortress_progress
	flood_defense = grid.flood_defense
	CityStats.recalculate_defense_and_attack(grid, self)
	sync_mega_projects_with_grid(grid)

## 그리드 상에 완공된 건축물(사대문, 수문, 서장대, 행궁, 관아, 만석거, 제방 등)을 검사하여
## 관련된 국책 대역사를 '완공' 상태로 자동 전환한다 (고정 좌표 탈피 & 임의 위치 건축 100% 인정)
## PORT-TRACE [대역사 비활성]: 사용자가 대역사 안의 시설(성문·행궁·관아·만석거·제방 등)을 직접 지으면, 그 대역사를 쓰지 않겠다는
## 뜻이므로 대역사를 "비활성"으로 돌린다. (예전엔 문 하나만 지어도 대역사가 완공 처리돼 성곽·부속 건물이 통째로 깔렸다.)
## 착공 중이거나 이미 완공된 대역사는 건드리지 않는다.
func sync_mega_projects_with_grid(target_grid: GameGrid) -> void:
	if target_grid == null:
		return

	for p in mega_projects:
		if bool(p.get("is_completed", false)) or bool(p.get("is_disabled", false)) or bool(p.get("is_started", false)):
			continue
		var pid: String = str(p.get("id", ""))
		var what := ""

		match pid:
			"manseok_reservoir":
				if target_grid.has_completed_facility("manseokgeo") or target_grid.count_completed("manseokgeo") > 0 or target_grid.has_site_started("manseokgeo"):
					what = "만석거"
			"suwon_levee":
				if target_grid.count_completed("levee") >= 4:
					what = "석축제방"
			"paldal_fortress":
				# 서장대 완공은 이 대역사와 무관하다. 화서문을 직접 세운 경우만 비활성.
				if target_grid.has_completed_facility("hwaseo") or _is_tile_completed(target_grid, 6, 13, "gate"):
					what = "화서문"
			"hwahong_north":
				if target_grid.has_completed_facility("jangan") or _is_tile_completed(target_grid, 26, 6, "gate") \
					or target_grid.has_completed_facility("hwahong") or target_grid.count_completed("hwahong") > 0:
					what = "장안문·화홍문"
			"changryong_east":
				if target_grid.has_completed_facility("changryong") or _is_tile_completed(target_grid, 48, 29, "gate"):
					what = "창룡문"
			"namsu_south":
				if target_grid.has_completed_facility("paldal") or _is_tile_completed(target_grid, 16, 54, "gate") \
					or target_grid.has_completed_facility("namsu") or target_grid.count_completed("namsu") > 0:
					what = "팔달문·남수문"

		if what != "":
			p["is_disabled"] = true
			p["disabled_msg"] = "%s을(를) 직접 지으셔서 [%s] 대역사는 쓰지 않습니다. (대역사의 자동 완성은 일어나지 않습니다)" % [what, str(p.get("name", ""))]
			emit_signal("project_skipped", pid, str(p["disabled_msg"]))

func _is_tile_completed(target_grid: GameGrid, x: int, y: int, expected_building: String) -> bool:
	if not target_grid.in_bounds(x, y):
		return false
	var t: Dictionary = target_grid.grid[y][x]
	var cur_b: String = str(t.get("building", ""))
	var is_under_const: bool = bool(t.get("under_construction", false))
	if is_under_const or cur_b == "wall_build" or cur_b == "":
		return false
	if cur_b == expected_building:
		return true
	if expected_building == "wall" and (cur_b in ["wall", "poru", "gongsimdon", "chiseong", "ammun", "gate", "hwahong", "namsu", "seojangdae"]):
		return true
	if expected_building == "gate" and cur_b == "gate":
		return true
	if expected_building == "hwahong" and (cur_b == "hwahong" or cur_b == "namsu"):
		return true
	if expected_building == "namsu" and (cur_b == "namsu" or cur_b == "hwahong"):
		return true
	return false

## 서장대 연례 군사 훈련 (야조: 夜操) 시스템 실행 가능 여부 사전 검증
func can_execute_seojangdae_drill(grid: GameGrid) -> Dictionary:
	if grid == null:
		return {"success": false, "msg": "도시 지도가 준비되지 않았습니다."}

	var has_sj: bool = grid.count_completed("seojangdae") > 0
	if not has_sj:
		return {"success": false, "msg": "서장대(화성장대)가 완공되지 않았습니다. 서장대를 먼저 축조하십시오."}

	if seojangdae_drill_cd_months > 0:
		return {"success": false, "msg": "올해의 서장대 야조 군사 훈련을 이미 마쳤습니다. (다음 훈련까지 %d개월 남음)" % seojangdae_drill_cd_months}

	var drill_cost: Dictionary = DifficultyManager.get_seojangdae_drill_cost()
	var cost_gold: int = int(drill_cost["gold"])
	var cost_rice: int = int(drill_cost["rice"])
	if gold < cost_gold or rice < cost_rice:
		return {"success": false, "msg": "군사 훈련 자금이나 군량이 부족합니다. (필요: 금화 %d냥, 군량 %d석)" % [cost_gold, cost_rice]}

	return {"success": true, "cost_gold": cost_gold, "cost_rice": cost_rice}

## 서장대 훈련 비용 선차감 및 쿨다운 설정
func pay_seojangdae_drill_cost(grid: GameGrid) -> Dictionary:
	var check: Dictionary = can_execute_seojangdae_drill(grid)
	if not check.get("success", false):
		return check

	var cost_gold: int = int(check.get("cost_gold", 2000))
	var cost_rice: int = int(check.get("cost_rice", 1000))

	gold -= cost_gold
	rice -= cost_rice
	seojangdae_drill_cd_months = 12
	emit_signal("state_updated", gold, rice, population, loyalty, flood_defense)
	return {"success": true, "cost_gold": cost_gold, "cost_rice": cost_rice}

## 서장대 훈련 보상 정산 (배율 multiplier: 0.80x ~ 1.20x 적용)
func apply_seojangdae_drill_rewards(grid: GameGrid, citizens: CitizenManager, multiplier: float = 1.0) -> Dictionary:
	var eff_mult: float = clampf(multiplier, 0.80, 1.20)
	var atk_bonus: int = int(round(50.0 * eff_mult))
	var auth_bonus: int = int(round(5.0 * eff_mult))
	var loy_bonus: int = int(round(3.0 * eff_mult))
	var bonus_pct: int = int(round((eff_mult - 1.0) * 100.0))

	authority = mini(100, authority + auth_bonus)
	CityStats.set_royal_power(authority)
	loyalty = mini(100, loyalty + loy_bonus)

	CityStats.add_seojangdae_drill_bonus(atk_bonus)
	if grid != null:
		CityStats.recalculate_defense_and_attack(grid, self)

	if military_drill_manager != null and military_drill_manager.has_method("start_seojangdae_drill"):
		military_drill_manager.start_seojangdae_drill(false)
	elif citizens != null and citizens.has_method("start_yajo"):
		citizens.start_yajo()

	emit_signal("state_updated", gold, rice, population, loyalty, flood_defense)

	var bonus_sign_str: String = ("+" if bonus_pct > 0 else "") + str(bonus_pct) + "%"
	var msg: String = "서장대에서 야간 군사 훈련(야조)을 성대히 거행했습니다!\n성곽 곳곳에 횃불이 밝혀지고 오방기가 펄럭입니다. (훈련 보정 %s: 장용영 공격력 +%d, 왕권 +%d, 민심 +%d)" % [
		bonus_sign_str, atk_bonus, auth_bonus, loy_bonus
	]

	return {
		"success": true,
		"msg": msg,
		"multiplier": eff_mult,
		"atk_bonus": atk_bonus,
		"auth_bonus": auth_bonus,
		"loy_bonus": loy_bonus
	}

## 서장대 연례 군사 훈련 (야조: 夜操) 시스템 실행 (비용 차감 + 보상 일괄 실행)
## - 쿨다운 및 조건: 1년에 단 1회(12개월 주기). 서장대 완공 상태.
## - 소모 비용: 금화 2,000냥, 군량 1,000석
## - 효과: 실행 즉시 성곽 야경 횃불 연출(start_yajo) 발화,
##         장용영 공격력 +50 상승 (누적 최대 1000, 해마다 1월 -50),
##         왕권 +5, 군사 사기 진작으로 민심 +3 상승
func execute_seojangdae_drill(grid: GameGrid, citizens: CitizenManager, multiplier: float = 1.0) -> Dictionary:
	var check: Dictionary = can_execute_seojangdae_drill(grid)
	if not check.get("success", false):
		return check

	pay_seojangdae_drill_cost(grid)
	return apply_seojangdae_drill_rewards(grid, citizens, multiplier)

## 연무대(동장대) 연례 무예 사열 훈련 실행 가능 여부 사전 검증
func can_execute_yeonmudae_drill(grid: GameGrid) -> Dictionary:
	if grid == null:
		return {"success": false, "msg": "도시 지도가 준비되지 않았습니다."}

	var has_ym: bool = grid.count_completed("yeonmudae") > 0
	if not has_ym:
		return {"success": false, "msg": "연무대(동장대)가 완공되지 않았습니다. 연무대를 먼저 축조하십시오."}

	if yeonmudae_drill_cd_months > 0:
		return {"success": false, "msg": "올해의 연무대 무예 사열 훈련을 이미 마쳤습니다. (다음 훈련까지 %d개월 남음)" % yeonmudae_drill_cd_months}

	var drill_cost: Dictionary = DifficultyManager.get_yeonmudae_drill_cost()
	var cost_gold: int = int(drill_cost["gold"])
	var cost_rice: int = int(drill_cost["rice"])
	if gold < cost_gold or rice < cost_rice:
		return {"success": false, "msg": "무예 사열 자금이나 군량이 부족합니다. (필요: 금화 %d냥, 군량 %d석)" % [cost_gold, cost_rice]}

	return {"success": true, "cost_gold": cost_gold, "cost_rice": cost_rice}

## PORT-TRACE [훈련 안 하면 군사력 감소]: 사용자 요청 — "훈련을 안 하면 매년 -50, 둘 중 하나만 하면 현상 유지, 둘 다 하면 증가".
## 해마다 1월 훈련 누적 공격력(서장대 야조·연무대 사열로 쌓인 몫, 0~1000)이 -50 깎인다.
## 훈련 한 번이 +50(성과에 따라 40~60)이므로 하나만 하면 제자리, 둘 다 하면 +50 남짓 오른다.
## 건물(행궁·서장대·연무대·순라청)에서 나오는 기본 공격력은 깎이지 않는다.
const DRILL_DECAY_PER_YEAR := 50
func _apply_annual_drill_decay() -> void:
	var before: int = CityStats.get_seojangdae_drill_bonus()
	if before <= 0:
		return
	CityStats.add_seojangdae_drill_bonus(-DRILL_DECAY_PER_YEAR)
	if grid_ref != null:
		CityStats.recalculate_defense_and_attack(grid_ref, self)
	emit_signal("disaster_alert", "새해가 밝아 군기가 조금 풀렸습니다. 훈련으로 쌓은 군사 공격력 -%d (%d → %d). 해마다 서장대 야조와 연무대 사열 가운데 하나는 해야 제자리를 지키고, 둘 다 하면 오릅니다." % [before - CityStats.get_seojangdae_drill_bonus(), before, CityStats.get_seojangdae_drill_bonus()])

## 연무대 훈련 비용 선차감 및 쿨다운 설정
func pay_yeonmudae_drill_cost(grid: GameGrid) -> Dictionary:
	var check: Dictionary = can_execute_yeonmudae_drill(grid)
	if not check.get("success", false):
		return check

	var cost_gold: int = int(check.get("cost_gold", 2000))
	var cost_rice: int = int(check.get("cost_rice", 2000))

	gold -= cost_gold
	rice -= cost_rice
	yeonmudae_drill_cd_months = 12
	jangyong_review_year = current_year
	emit_signal("state_updated", gold, rice, population, loyalty, flood_defense)
	return {"success": true, "cost_gold": cost_gold, "cost_rice": cost_rice}

## 연무대 훈련 보상 정산 (배율 multiplier: 0.80x ~ 1.20x 적용)
func apply_yeonmudae_drill_rewards(grid: GameGrid, multiplier: float = 1.0) -> Dictionary:
	var eff_mult: float = clampf(multiplier, 0.80, 1.20)
	var atk_bonus: int = int(round(50.0 * eff_mult)) # 서장대 야조와 같은 +50: 해마다 -50 감소를 훈련 하나로 메운다
	var mil_bonus: int = int(round(5.0 * eff_mult))
	var loy_bonus: int = int(round(3.0 * eff_mult))
	var auth_gain: int = 8 if retainers.get("baek_dongsu", false) else 5
	var bonus_pct: int = int(round((eff_mult - 1.0) * 100.0))

	loyalty = mini(100, loyalty + loy_bonus)
	military_power = mini(100, military_power + mil_bonus)
	authority = mini(100, authority + auth_gain)
	jangyong_review_year = current_year

	CityStats.add_seojangdae_drill_bonus(atk_bonus) # 공격력 영구 보너스
	if grid != null:
		CityStats.recalculate_defense_and_attack(grid, self)

	if military_drill_manager != null and military_drill_manager.has_method("start_yeonmudae_drill"):
		military_drill_manager.start_yeonmudae_drill()

	emit_signal("state_updated", gold, rice, population, loyalty, flood_defense)

	var bonus_sign_str: String = ("+" if bonus_pct > 0 else "") + str(bonus_pct) + "%"
	var msg: String = "연무대에서 장용영 군사들의 일사불란한 무예 사열을 거행했습니다!\n(훈련 보정 %s: 장용영 공격력 +%d, 군사력 +%d, 민심 +%d, 왕권 +%d)" % [
		bonus_sign_str, atk_bonus, mil_bonus, loy_bonus, auth_gain
	]

	return {
		"success": true,
		"msg": msg,
		"multiplier": eff_mult,
		"atk_bonus": atk_bonus,
		"mil_bonus": mil_bonus,
		"loy_bonus": loy_bonus,
		"auth_bonus": auth_gain
	}

## 연무대(동장대) 연례 무예 사열 훈련 실행
## - 쿨다운 및 조건: 1년에 단 1회(12개월 주기). 연무대 완공 상태.
## - 소모 비용: 금화 2,000냥, 군량 2,000석 (난이도 배율 적용)
## - 효과: 실행 즉시 카메라 연무대 자동 이동 및 국궁 일제 사격·창검술 시각화 발화,
##         장용영 공격력 +50 상승 (누적 최대 1000 상한, 해마다 1월 -50), 민심 +3, 군사력 +5, 왕권 +5(백동수 +8) 상승
func execute_yeonmudae_drill(grid: GameGrid, multiplier: float = 1.0) -> Dictionary:
	var check: Dictionary = can_execute_yeonmudae_drill(grid)
	if not check.get("success", false):
		return check

	pay_yeonmudae_drill_cost(grid)
	return apply_yeonmudae_drill_rewards(grid, multiplier)


func notify_bandit_raid_started(pos: Vector2i) -> void:
	bandit_raid_started.emit(pos)

func notify_bandit_raid_ended(repelled: bool) -> void:
	bandit_raid_ended.emit(repelled)

func notify_bandit_camp_subjugated() -> void:
	bandit_camp_subjugated.emit()

func get_relief_food_cost() -> int:
	return DifficultyManager.get_relief_food_cost(population)

## [공공기관 계절 유지비 & 인재 녹봉 일괄 정산]
## 매 계절(봄/여름/가을/겨울 전환 시) 1회 호출
func process_seasonal_maintenance(target_grid: GameGrid = null) -> Dictionary:
	var active_grid: GameGrid = target_grid if target_grid != null else grid_ref
	var maint_rate: float = DifficultyManager.get_public_maintenance_rate()
	var retainer_sal: int = DifficultyManager.get_retainer_salary()

	# 1. 공공기관 유지비 계산 (호환성 보존)
	var total_facility_base_cost: int = 0
	var _facility_count: int = 0
	if active_grid != null and maint_rate > 0.0:
		for y: int in range(active_grid.size):
			for x: int in range(active_grid.size):
				var b: String = str(active_grid.grid[y][x].get("building", ""))
				if DifficultyManager.is_public_facility(b):
					total_facility_base_cost += DifficultyManager.get_public_facility_base_cost(b)
					_facility_count += 1

	var facility_maintenance: int = int(round(float(total_facility_base_cost) * maint_rate))

	# 2. 인재 녹봉 계산 (등용된 인재 수)
	var hired_count: int = 0
	for k: String in retainers.keys():
		if bool(retainers[k]):
			hired_count += 1
	var total_salaries: int = hired_count * retainer_sal

	var total_expenses: int = facility_maintenance + total_salaries

	if total_expenses > 0:
		if gold >= total_expenses:
			gold -= total_expenses
			emit_signal("state_updated", gold, rice, population, loyalty, flood_defense)
			return {
				"success": true,
				"facility_maintenance": facility_maintenance,
				"retainer_salaries": total_salaries,
				"total": total_expenses,
				"deficit": false
			}
		else:
			# 국고 부족 디버프: 금화 0 처리, 민심 및 왕권 감소, 알림 발생
			var shortage: int = total_expenses - gold
			gold = 0
			loyalty = maxi(0, loyalty - 8)
			authority = maxi(0, authority - 5)
			var shortage_msg: String = "국고가 부족하여 공공기관 계절 유지비와 인재 녹봉이 체납되었습니다! (민심 -8, 왕권 -5)"
			emit_signal("disaster_alert", shortage_msg)
			if EventManager.instance != null:
				EventManager.instance.enqueue_disaster("재정 결손 비상", shortage_msg, {"loyalty": 8})
			emit_signal("state_updated", gold, rice, population, loyalty, flood_defense)
			return {
				"success": false,
				"facility_maintenance": facility_maintenance,
				"retainer_salaries": total_salaries,
				"total": total_expenses,
				"deficit": true,
				"shortage": shortage
			}

	return {
		"success": true,
		"facility_maintenance": 0,
		"retainer_salaries": 0,
		"total": 0,
		"deficit": false
	}

# ==================== 인구 역학 및 세제·복지 시뮬레이션 연동 ====================

## 화성행궁 완공 시 기본 인구 +6,000명 즉시 유입 및 기본 수용량 인정
func trigger_haenggung_completion(target_grid: GameGrid = null) -> Dictionary:
	var active_grid: GameGrid = target_grid if target_grid != null else grid_ref
	if pop_manager == null:
		pop_manager = PopulationManager.new(population)
	pop_manager.total_population = population
	var res: Dictionary = pop_manager.on_haenggung_completed()
	if bool(res.get("applied", false)):
		population = pop_manager.total_population
		if active_grid != null:
			pop_manager.update_housing_occupancy(active_grid)
		emit_signal("state_updated", gold, rice, population, loyalty, flood_defense)
	return res

## 세율 정책 변경 (감면책/표준세/가혹세)
func set_tax_policy(policy: PopulationManager.TaxPolicy) -> void:
	if pop_manager == null:
		pop_manager = PopulationManager.new(population)
	pop_manager.set_tax_policy(policy)
	var loyalty_delta: int = pop_manager.get_tax_policy_loyalty_effect()
	if loyalty_delta != 0:
		loyalty = clampi(loyalty + loyalty_delta, 0, 100)
	emit_signal("state_updated", gold, rice, population, loyalty, flood_defense)

func get_tax_policy() -> PopulationManager.TaxPolicy:
	if pop_manager == null:
		pop_manager = PopulationManager.new(population)
	return pop_manager.get_tax_policy()

func get_tax_policy_name() -> String:
	if pop_manager == null:
		pop_manager = PopulationManager.new(population)
	return pop_manager.get_tax_policy_name()

## 계절 전환 시 인구 증가율(0~5%) 연산, 인구 갱신, 세수 국고 입고 및 가옥-폐허 순환 동기화
func process_seasonal_population(target_grid: GameGrid = null) -> Dictionary:
	var active_grid: GameGrid = target_grid if target_grid != null else grid_ref
	if pop_manager == null:
		pop_manager = PopulationManager.new(population)
	pop_manager.total_population = population
	var res: Dictionary = pop_manager.process_seasonal_tick(loyalty, active_grid, self)
	population = pop_manager.total_population
	
	# 계절 세수 국고 입고: floor(현재 인구 * 0.15 * 세율 계수)
	var seasonal_tax: int = int(float(res.get("seasonal_tax", 0)) * TaxManager.revenue_mult(active_grid)) # 쇠전·사대문 교역로 세입 가산
	res["seasonal_tax"] = seasonal_tax
	if seasonal_tax > 0:
		ResourceManager.add_gold(seasonal_tax, self)
		
	emit_signal("state_updated", gold, rice, population, loyalty, flood_defense)
	return res

## [턴 경제 및 시장 동역학 통합 정산 엔진]
## 1. 조세 총합 및 조세 저항선 평가
## 2. 가옥·상점 등급별 차등 세수 산출 및 국고 입고 (시작 2년/8턴 이후 활성화)
## 3. 3대 조세 합계 21% 기준 시장 인구부양력 동역학 갱신
func process_turn_economy(target_grid: GameGrid = null) -> Dictionary:
	var active_grid: GameGrid = target_grid if target_grid != null else grid_ref
	var total_tax: float = TaxManager.get_total_tax_rate(self)
	var is_diff_active: bool = TaxManager.is_differentiated_tax_active(self)

	# 1. 등급별 건물 집계 (O(1) 캐시 활용)
	var tier_counts: Dictionary = BuildingManager.get_building_tier_counts(active_grid)

	# 기본 초가집 세금: 가옥 1채당 기본 세수 5냥 (세율 계수 비례)
	# 기본 일반 상점 세금: 상점 1곳당 기본 세수 10냥 (세율 계수 비례 및 치안 실패 시 10% 감액)
	var base_house_tax: int = maxi(1, int(round(5.0 * (float(tax_rate_military) / 7.0))))
	var market_tax_mult: float = MarketManager.get_dispute_tax_multiplier()
	var base_shop_tax: int = maxi(1, int(round(10.0 * (float(tax_rate_market) / 7.0) * market_tax_mult)))

	var ws_count: int = BuildingManager.active_workshop_count
	var diff_tax_res: Dictionary = TaxManager.calculate_differentiated_taxes(
		tier_counts, base_house_tax, base_shop_tax, is_diff_active, ws_count
	)

	# 차등 과세 세수 국고 입고 (난이도별 세수 배율 반영)
	var tax_mult: float = DifficultyManager.get_tax_multiplier() * TaxManager.revenue_mult(active_grid) # 쇠전·사대문 교역로 세입 가산
	var diff_total_tax: int = int(diff_tax_res.get("total_tax", 0))
	if diff_total_tax > 0:
		var final_diff_tax: int = int(floor(float(diff_total_tax) * tax_mult))
		ResourceManager.add_gold(final_diff_tax, self)
		diff_tax_res["house_tax"] = int(floor(float(diff_tax_res.get("house_tax", 0)) * tax_mult))
		diff_tax_res["shop_tax"] = int(floor(float(diff_tax_res.get("shop_tax", 0)) * tax_mult))
		diff_tax_res["total_tax"] = final_diff_tax

	# 2. 시장 인구부양력 동역학 처리
	var market_res: Dictionary = MarketManager.process_turn_market(self, active_grid)

	# 3. 조세 저항선에 따른 인구 유출 감시
	var pop_res: Dictionary = CityStats.update_population(population, 0, total_tax)
	if bool(pop_res.get("is_resisting", false)):
		var pop_loss: int = absi(int(pop_res.get("delta", 0)))
		if pop_loss > 0:
			population = maxi(0, population - pop_loss)
			if pop_manager != null:
				pop_manager.total_population = population
			emit_signal("disaster_alert", "[조세 저항 경고] 과중한 세금 부담으로 유민이 발생하여 인구 %d명이 성 밖으로 유출되었습니다!" % pop_loss)

	# 4. 공방 군사력 승수 정산 및 무기 조달 경고 감시
	var def_res: Dictionary = CityStats.recalculate_defense_and_attack(active_grid, self)
	if ws_count == 0 and turn > 4:
		emit_signal("disaster_alert", "⚠️ [군수품 부족] 공방이 전무하여 군사들의 무기 보급이 마비되었습니다! (군사력 -50%)")

	# 5. 동적 난이도 및 도시 성장(인구 10만+ / 국부 10만+) 스케일러 턴 정산 및 캐싱 (O(1))
	cached_crime_rate_bonus = DifficultyManager.get_crime_chance_bonus(population)
	cached_morale_multiplier = DifficultyManager.get_morale_gain_multiplier(population)
	cached_threat_escalation = DifficultyManager.get_threat_escalation(gold, rice)
	var is_autumn_turn: bool = (season_now() == 2)
	cached_bandit_spawn_chance = BanditManager.calculate_bandit_spawn_chance(self, is_autumn_turn)

	# 6. 동적 도적 소굴 스폰/성장/약탈/공성전 턴 정산
	var bandit_res: Dictionary = {}
	if bandit_manager != null:
		bandit_res = bandit_manager.process_turn(self, active_grid)

	emit_signal("state_updated", gold, rice, population, loyalty, flood_defense)

	return {
		"total_tax_rate": total_tax,
		"is_differentiated_active": is_diff_active,
		"diff_tax": diff_tax_res,
		"market_dynamics": market_res,
		"population_status": pop_res,
		"defense_status": def_res,
		"workshop_count": ws_count,
		"dynamic_scaling": {
			"crime_rate_bonus": cached_crime_rate_bonus,
			"morale_multiplier": cached_morale_multiplier,
			"threat_escalation": cached_threat_escalation,
			"bandit_spawn_chance": cached_bandit_spawn_chance
		},
		"bandit_status": bandit_res
	}

## 민심 가산 및 갱신 메서드 (난이도 및 인구 감쇠 공식 적용)
func add_morale(amount: int) -> int:
	return CityStats.add_morale(amount, self, population)

## 전체 관공서 점유 셀 수 재계산 (BuildingManager 위임)
func recalculate_gov_cell_count(target_grid: GameGrid = null) -> int:
	var active_grid: GameGrid = target_grid if target_grid != null else grid_ref
	if active_grid == null:
		return total_gov_cell_count
	total_gov_cell_count = BuildingManager.count_gov_cells(active_grid)
	return total_gov_cell_count

## 관공서 완공/철거 시 점유 셀 수 증감 반영 (O(1) 캐시)
func add_gov_cells(count: int) -> void:
	total_gov_cell_count = maxi(0, total_gov_cell_count + count)

## 세자 교육 턴 정산 처리 (CrownPrinceEducationManager 위임)
func process_turn_crown_prince_education() -> Dictionary:
	if crown_prince_manager == null or CrownPrinceEducationManager.prince_affairs_closed(current_year): # 1800년 엔딩(순조 즉위) 뒤·현대 정치체제 전환 뒤에는 세자 교육 없음(비용도 안 나감)
		return {}
	return crown_prince_manager.process_turn(self, academic)

## 규장각 의궤 편찬 턴 정산 처리 (UigweManager 위임)
func process_turn_uigwe() -> Dictionary:
	if uigwe_manager == null:
		return {}
	var acad_power: int = CityStats.get_academic_power()
	if acad_power == 0 and academic > 0:
		acad_power = academic
	return uigwe_manager.process_turn(self, acad_power, court_ref as CourtSystem)

## 순라청 기여(+30/개소) 및 장용영 훈련치가 반영된 아군 총 국방력 산출
func get_effective_military_power(target_grid: GameGrid = null) -> int:
	var active_grid: GameGrid = target_grid if target_grid != null else grid_ref
	var patrol_cnt: int = 0
	if active_grid != null and active_grid.grid is Array:
		var g_size: int = active_grid.grid.size()
		for y: int in range(g_size):
			var row: Array = active_grid.grid[y]
			for x: int in range(row.size()):
				var cell: Dictionary = row[x]
				if str(cell.get("building", "")) == "patrol" and not cell.get("under_construction", false):
					patrol_cnt += 1
	elif SunlacheongManager.instance != null:
		patrol_cnt = SunlacheongManager.instance.patrol_stations.size()

	var drill_bonus: int = CityStats.get_seojangdae_drill_bonus()
	return military_power + (patrol_cnt * 30) + drill_bonus
