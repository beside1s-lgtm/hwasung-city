extends Node
class_name CitizenManager


## 조선 정조 시대 백성 일상 시뮬레이션 & 자연 생태계(산짐승) & 도로망 통행 엔진
## 네임드 NPC 7인 조건부 등장 및 근무지 복귀(퇴근) 생명주기
## 산짐승 생태계 (꽃사슴, 두루미, 멧돼지, 산토끼), 수원천 낚시/빨래, 성곽 공사
## 조선 후기 6대 신분·직업군 (중인, 아전, 장인, 보부상, 승군, 백정) 전용 거점 생태계

enum JobType {
	COMMONER = 0,     # 일반 백성/상민 (기본값)
	JUNGIN = 1,       # 중인 (기술관/의원)
	AJEOUN = 2,       # 관아 아전 (향리/이방)
	ARTISAN = 3,      # 축성 장인 (도편수/석수)
	BOBUSANG = 4,     # 보부상 (객주)
	MONK_SOLDIER = 5, # 승군 (호국 의승)
	BUTCHER = 6       # 백정 (도축/가죽공)
}

const NAMES_JUNGIN_PREFIX: Array[String] = ["의원", "역관", "율관", "산학관", "의관", "사자관"]
const NAMES_JUNGIN_GIVEN: Array[String] = ["유태석", "고선익", "허균", "홍순언", "백광현", "김영조", "이수민", "조학기", "신경준", "한치윤", "유득공", "이덕무"]

const NAMES_AJEOUN_PREFIX: Array[String] = ["이방", "호방", "예방", "형방", "공방", "병방", "향리", "군교"]
const NAMES_AJEOUN_GIVEN: Array[String] = ["최진규", "김득원", "박종수", "정만호", "유병기", "안대섭", "장치복", "강태호", "오세창", "문덕배", "임원준", "송시열"]

const NAMES_ARTISAN_PREFIX: Array[String] = ["도편수", "석수장", "와장", "야장", "석수", "목수", "단청장", "조각장"]
const NAMES_ARTISAN_GIVEN: Array[String] = ["이성길", "김바우", "정성호", "박철구", "장득춘", "편순손", "황응선", "조유진", "백남석", "서달수", "천득이", "김막동"]

const NAMES_BOBUSANG_PREFIX: Array[String] = ["개성보부상", "객주", "한양상단", "송상", "의주상단", "수원보부상", "삼남보부상", "포구상단"]
const NAMES_BOBUSANG_GIVEN: Array[String] = ["만석", "배달호", "칠복", "덕삼", "팔봉", "윤봉길", "천돌", "삼룡", "개똥", "달수", "마당쇠", "득보"]

const NAMES_MONK_SOLDIER_PREFIX: Array[String] = ["승병장", "의승", "승군", "호국승", "도총섭"]
const NAMES_MONK_SOLDIER_GIVEN: Array[String] = ["탄묵", "혜인", "원담", "지엄", "법련", "각진", "성오", "인학", "자초", "무학", "유정", "휴정"]

const NAMES_BUTCHER_PREFIX: Array[String] = ["가죽공", "칼잡이", "갖바치", "무두장이", "도축공", "포육장"]
const NAMES_BUTCHER_GIVEN: Array[String] = ["무쇠", "칠성이", "돌석", "막동", "쇠돌", "개똥이", "삼식이", "곰손", "바우", "억쇠", "점돌이", "마당쇠"]

var grid: GameGrid
var court: CourtSystem
var sim: SimulationCore
var city: CityLayer = null

signal bandit_battle_started(world_pos: Vector2, location_name: String)
signal bandit_battle_ended(repelled: bool)
@warning_ignore("unused_signal")
signal predator_attacked(world_pos: Vector2, animal_type: String)

const TILE_LIMIT_NPC_VISIBLE: int = 400    # 400칸 이하부터 일반 NPC 보임
const TILE_LIMIT_BUBBLE_VISIBLE: int = 300 # 300칸 이하부터 일반 말풍선 보임

var agents: Array[Dictionary] = []
var active_npcs: Array[CitizenNPC] = []
var active_special_entities: Array = []
var tiger_spawned: bool = false
var _professional_timer: float = 4.0

func register_npc(npc: CitizenNPC) -> void:
	if npc != null and not active_npcs.has(npc):
		npc.citizen_manager_ref = self
		active_npcs.append(npc)
		if npc.is_special():
			register_special_entity(npc)

func unregister_npc(npc: CitizenNPC) -> void:
	if npc != null:
		active_npcs.erase(npc)
		unregister_special_entity(npc)

func register_special_entity(entity: Variant) -> void:
	if entity != null and not active_special_entities.has(entity):
		active_special_entities.append(entity)
	SpecialEntityManager.register_special(entity)

func unregister_special_entity(entity: Variant) -> void:
	if entity != null:
		active_special_entities.erase(entity)
	SpecialEntityManager.unregister_special(entity)

const JOB_ACTION_MAP: Dictionary = {
	# 1. 고증 공방 장인 8종
	"artisan_blacksmith": "JOB_BLACKSMITH_FORGE",
	"artisan_potter": "JOB_POTTER_WHEEL",
	"artisan_carpenter": "JOB_CARPENTER_PLANE",
	"artisan_weaver": "JOB_WEAVER_LOOM",
	"artisan_leather": "JOB_LEATHER_CUT",
	"artisan_mason": "JOB_MASON_CHISEL",
	"artisan_paper": "JOB_PAPER_SCOOP",
	"artisan_foundry": "JOB_FOUNDRY_POUR",
	"artisan": "JOB_ARTISAN_WORK",

	# 2. 저잣거리 상인 8종 (★ 팔달문 우시장 거간꾼 포함)
	"merchant_silk": "JOB_SILK_DISPLAY",
	"merchant_fish": "JOB_FISH_OFFER",
	"merchant_herb": "JOB_HERB_WEIGH",
	"merchant_fruit": "JOB_FRUIT_HAWK",
	"merchant_book": "JOB_BOOK_RECITE",
	"merchant_brass": "JOB_BRASS_POLISH",
	"merchant_tavern": "JOB_TAVERN_SERVE",
	"merchant_cattle": "JOB_CATTLE_BARGAIN",
	"merchant": "JOB_MERCHANT_HAGGLE",

	# 3. 신분·성별·연령 12대 완전 직교 계층
	"yangban_male": "JOB_YANGBAN_FAN",
	"yangban_female": "JOB_YANGBAN_SMILE",
	"elder_yangban_m": "JOB_ELDER_BEARD",
	"elder_yangban_f": "JOB_ELDER_CANE",
	"child_yangban_m": "JOB_CHILD_TOP",
	"child_yangban_f": "JOB_CHILD_JEGI",
	"commoner_male": "JOB_COMMONER_REST",
	"commoner_female": "JOB_COMMONER_BASKET",
	"elder_commoner_m": "JOB_ELDER_PIPE",
	"elder_commoner_f": "JOB_ELDER_BACK",
	"child_commoner_m": "JOB_CHILD_PEBBLE",
	"child_commoner_f": "JOB_CHILD_FLOWER",

	# 4. 기타 직업 및 군사
	"builder": "JOB_BUILDER_CONSTRUCT",
	"brawler": "JOB_BRAWL_FIGHT",
	"fisherman": "JOB_FISHER_FISH",
	"soldier": "JOB_MILITARY_DRILL",
	"jangyongyeong": "JOB_MILITARY_DRILL",
	"patrol_officer": "JOB_POLICE_PATROL",
	"firefighter": "JOB_FIRE_EXTINGUISH",
	"cook": "JOB_COOK_KITCHEN",
	"drunkard": "JOB_DRUNK_STAGGER",
	"thief": "JOB_THIEF_STEAL"
}

## 공방 업종(trade)에 맞는 고유 장인 타입 반환
static func get_artisan_type_for_trade(trade: String) -> String:
	match trade:
		"smith":
			return "artisan_blacksmith"
		"onggi":
			return "artisan_potter"
		"lumber", "gat", "brush":
			return "artisan_carpenter"
		"silk", "cotton", "ramie", "myeonju":
			return "artisan_weaver"
		"shoe":
			return "artisan_leather"
		"bow", "mason":
			return "artisan_mason"
		"hanji", "paper":
			return "artisan_paper"
		"brass", "foundry":
			return "artisan_foundry"
		_:
			return "artisan"

## 저잣거리 상점 업종(trade)에 맞는 고유 상인 타입 반환 (★ 팔달문 우시장 엄수)
static func get_merchant_type_for_trade(trade: String) -> String:
	match trade:
		"silk", "cotton", "myeonju", "ramie":
			return "merchant_silk"
		"fish", "jeotgal":
			return "merchant_fish"
		"herb":
			return "merchant_herb"
		"fruit", "veg", "rice", "tteok":
			return "merchant_fruit"
		"book":
			return "merchant_book"
		"yugi", "bangmul":
			return "merchant_brass"
		"jumak", "gukbap", "gaekju":
			return "merchant_tavern"
		"cattle": # 팔달문 우시장 거간꾼 고유 보존
			return "merchant_cattle"
		_:
			return "merchant"

## 신분·성별·연령 12대 완전 직교 다양성 프로필 생성 (어린이/성인/노인 x 양반/상민 x 남/여)
func get_random_citizen_profile() -> Dictionary:
	var roll: float = randf()
	var is_male: bool = (randf() < 0.5)
	var type_str: String = "commoner_male"
	var social_class: String = "commoner"
	var age_group: String = "adult"
	var col_mod: Color = Color(0.80, 0.82, 0.78)

	if roll < 0.15: # 양반 계층 (15%) - 고운 실크 명주 한복
		social_class = "yangban"
		var sub_roll: float = randf()
		if sub_roll < 0.40: # 성인 양반 (6%)
			age_group = "adult"
			type_str = "yangban_male" if is_male else "yangban_female"
			col_mod = Color(0.95, 0.92, 0.88)
		elif sub_roll < 0.67: # 노인 양반 (4%)
			age_group = "elder"
			type_str = "elder_yangban_m" if is_male else "elder_yangban_f"
			col_mod = Color(0.92, 0.90, 0.94)
		else: # 어린이 양반 (5%)
			age_group = "child"
			type_str = "child_yangban_m" if is_male else "child_yangban_f"
			col_mod = Color(1.0, 0.96, 0.92)
	else: # 상민·서민 계층 (85%) - 투박한 무명옷 및 삼베옷
		social_class = "commoner"
		var sub_roll: float = randf()
		if sub_roll < 0.59: # 성인 상민 (50%)
			age_group = "adult"
			type_str = "commoner_male" if is_male else "commoner_female"
			col_mod = Color(0.80, 0.82, 0.78)
		elif sub_roll < 0.76: # 노인 상민 (15%)
			age_group = "elder"
			type_str = "elder_commoner_m" if is_male else "elder_commoner_f"
			col_mod = Color(0.85, 0.84, 0.82)
		else: # 어린이 상민 (20%)
			age_group = "child"
			type_str = "child_commoner_m" if is_male else "child_commoner_f"
			col_mod = Color(0.88, 0.86, 0.84)

	return {
		"type": type_str,
		"social_class": social_class,
		"age_group": age_group,
		"gender": "M" if is_male else "F",
		"modulate": col_mod
	}

## [CitizenNPC 엔티티 스폰 헬퍼] 신분·성별·연령 및 직업별 11종 특수 애니메이션 자동 바인딩
func spawn_citizen_node(p_role: String = "random", p_grid_pos: Vector2i = Vector2i.ZERO, parent: Node2D = null) -> CitizenNPC:
	var assigned_type: String = p_role
	var job_act: String = "NONE"
	var mod_col := Color.WHITE

	if p_role == "random" or p_role == "citizen" or p_role == "":
		var prof := get_random_citizen_profile()
		assigned_type = String(prof["type"])
		mod_col = prof["modulate"]
	elif JOB_ACTION_MAP.has(p_role):
		assigned_type = p_role
		job_act = String(JOB_ACTION_MAP[p_role])

	var npc := CitizenNPC.new(assigned_type)
	npc.current_grid_pos = Vector2(p_grid_pos)
	npc.global_position = Vector2(
		(float(p_grid_pos.x) - float(p_grid_pos.y)) * 32.0,
		(float(p_grid_pos.x) + float(p_grid_pos.y)) * 16.0
	)
	if mod_col != Color.WHITE:
		npc.modulate = mod_col
	if job_act != "NONE":
		npc.set_job_action(job_act)

	if parent != null:
		parent.add_child(npc)
	register_npc(npc)
	return npc

# 전역 말풍선 풀 (최대 8개, 개별 NPC에 Control 노드 생성 금지)
var _bubble_pool: Array[Control] = []
const MAX_BUBBLES: int = 8

func get_visible_tile_count() -> int:
	var cam: Camera2D = null
	var vp: Viewport = get_viewport()
	if vp != null:
		cam = vp.get_camera_2d()
	if cam == null:
		var z: float = CameraLODController.current_zoom
		if z <= 0.0:
			z = 1.0
		var vp_sz: Vector2 = vp.get_visible_rect().size if vp != null else Vector2(1280.0, 720.0)
		if vp_sz.x <= 10.0 or vp_sz.y <= 10.0:
			vp_sz = Vector2(1280.0, 720.0)
		var view_sz: Vector2 = vp_sz / z
		var c_cols: int = int(view_sz.x / 64.0) + 1
		var c_rows: int = int(view_sz.y / 32.0) + 1
		return c_cols * c_rows

	var vp_size: Vector2 = vp.get_visible_rect().size if vp != null else Vector2(1280.0, 720.0)
	if vp_size.x <= 10.0 or vp_size.y <= 10.0:
		vp_size = Vector2(1280.0, 720.0)
	var zx: float = cam.zoom.x if cam.zoom.x > 0.0 else 1.0
	var zy: float = cam.zoom.y if cam.zoom.y > 0.0 else 1.0
	var view_size := Vector2(vp_size.x / zx, vp_size.y / zy)
	var cols: int = int(view_size.x / 64.0) + 1
	var rows: int = int(view_size.y / 32.0) + 1
	return cols * rows

func is_zoomed_in() -> bool:
	return get_visible_tile_count() <= TILE_LIMIT_NPC_VISIBLE

func _init_bubble_pool() -> void:
	if not _bubble_pool.is_empty():
		return
	for i in range(MAX_BUBBLES):
		var b := SpeechBubbleItem.new()
		b.name = "GlobalSpeechBubble%d" % i
		b.visible = false
		b.z_index = 1100 # PORT-TRACE [말풍선 위 NPC]: 시민 레이어(1000)보다 위 — 사람이 말풍선을 밟고 지나가지 않게
		add_child(b)
		_bubble_pool.append(b)

func acquire_speech_bubble(owner_node: Node2D, text: String, name_tag: String = "", duration: float = 3.0) -> Control:
	_init_bubble_pool()
	for b in _bubble_pool:
		if not b.visible:
			b.set_data(owner_node, text, name_tag, duration)
			return b
	if not _bubble_pool.is_empty():
		var oldest: Control = _bubble_pool[0]
		oldest.set_data(owner_node, text, name_tag, duration)
		return oldest
	return null

func release_speech_bubble(b: Control) -> void:
	if b != null and b in _bubble_pool:
		b.call("clear_data")

# 지형 및 시설 캐시
var _roads_cache: Array[Vector2i] = []
var _roads_set: Dictionary = {}
var _forest_cache: Array[Vector2i] = []
var _mountain_cache: Array[Vector2i] = [] # 순수 산악(mountain) 지형 타일 캐시
var _mountain_forest_cache: Array[Vector2i] = [] # 산지 또는 외곽 깊은 숲 타일 캐시
var _mountain_rocky_cache: Array[Vector2i] = [] # 산지 또는 외곽 깊은 암석 타일 캐시
var _water_banks_cache: Array[Dictionary] = [] # [{pos: Vector2i, water_dir: Vector2}]
var _seokjeon_pairs_cache: Array[Dictionary] = [] # [{bank_a: Vector2i, bank_b: Vector2i, dir: Vector2}]
var _boundary_check_timer: float = 0.0 # 맵 경계선 이탈자 0.5초 주기 검사
var _agr_cache: Array[Vector2i] = []
var _rocky_cache: Array[Vector2i] = []
var _grass_cache: Array[Vector2i] = []
var _wall_cache: Array[Vector2i] = []
var _office_cache: Array[Vector2i] = []
var _com_cache: Array[Vector2i] = []
var _res_cache: Array[Vector2i] = []
var _gate_cache: Array[Vector2i] = []
var _build_cache: Array[Vector2i] = [] # 공사 중인 칸 (PORT-TRACE [건설 기간])
var _open_gate := false               # 다 지은 성문이 있는가
var _military_cache: Array[Vector2i] = []
var _levee_cache: Array[Vector2i] = []
var _reservoir_cache: Array[Vector2i] = []
var _floodgate_cache: Array[Vector2i] = []
var _patrol_cache: Array[Vector2i] = [] # 순라청(patrol) 건물 캐시
var _patrol_roads_cache: Array[Vector2i] = [] # 성곽 안쪽 순찰로(길) 타일 캐시
var _patrol_roads_set: Dictionary = {}
var _routine_patrol_timer: float = 6.0 # 평상시 성곽 순라군 순찰 스케줄러 타이머
var sunla_manager: SunlacheongManager = null # 순라청 치안 컨트롤러
var _firefighter_cache: Array[Vector2i] = [] # 멸화군(firefighter) 건물 캐시
var _active_fires: Array[Dictionary] = [] # 활성 화재 목록
var _fire_timer: float = 45.0 # 화재 발생 타이머
var _shop_cache: Array[Vector2i] = []     # 다 지은 가게(com_1/com_2) — 가게 주인 배치용
var _house_cache: Array[Vector2i] = []    # 다 지은 민가(res_*) — 길손·농민의 집
var _rich_house_cache: Array[Vector2i] = [] # 기와집·부호의 집 — 가마 행차 목적지
var _haenggung_gate := Vector2i(-1, -1)   # 화성행궁 정문(신풍루) 칸 — 파발마·관리의 목적지
## PORT-TRACE [관아·옥사 2x2]: 완공된 관아 단지의 기준(앵커) 칸. 재판 상태는 앵커 타일 사전에 둔다:
## gw_trial(남은 재판 초), gw_kind("bandit"/"thief"/"lawsuit"), gw_prisoners(옥에 갇힌 죄수 수, 최대 6)
var _gwana_cache: Array[Vector2i] = []
var _seodang_cache: Array[Vector2i] = []
var _seodang_students: Dictionary = {} # Vector2i -> Array[Dictionary]
## PORT-TRACE [수원 쇠전 3x3]: 쇠전 기준 칸(없으면 -1)과 소몰이꾼 주기
var _cattle_yard := Vector2i(-1, -1)
var _salt_store := Vector2i(-1, -1)
## PORT-TRACE [종루(여민각) 2x2]: 완공된 종루 앵커, 타종 뒤 남은 활력 시간, 타종 물결 연출 시간
var _jongnu := Vector2i(-1, -1)
var bell_boost: float = 0.0
## PORT-TRACE [매향교]: 개통되면 동서 직통로 — 창룡문 운반꾼·군사 1.25배, 모든 길손 1.1배 빠르게
var maehyang_open := false
## PORT-TRACE [서장대 야조]: 국왕 행차 때 서장대 야간 군사 조련(《서장대성조도》) 남은 시간(초)
var yajo_t: float = 0.0
## PORT-TRACE [생태계 2단계]: 효과음 요청(사포수 조총·맹수 포효·비명) — Main이 채널 제한(동시 3)·0.1초 스로틀로 재생
signal sfx(kind: String)
var siege: SiegeSystem # PORT-TRACE [공성전]: 반란군·도적떼 부대원 이동은 SiegeSystem의 공유 흐름장으로
var military_mgr: MilitaryManager = MilitaryManager.new() # 삼수병(포수·사수·살수) 및 기포병 편제 관리자
var _saposu_timer: float = 20.0
var _panic_timer: float = 0.0
var _tiger_alert_active: bool = false
var _casualty_cd: float = 0.0
## PORT-TRACE [포루 포격 훈련]: 해마다 한 번 다섯 포루 일제 사격 훈련(장전 → 심지 점화 → 포격·백색 연막) 경과 시간(-1=쉼)
signal cannon_fired
var drill_t: float = -1.0
const DRILL_LEN := 24.0
var _drill_shots: int = 0
## PORT-TRACE [행궁 태형·판결]: 화성행궁(유수부 관아 겸) 동헌 마당 재판 — 남은 시간·종류·다음 재판까지
var hg_trial_t: float = 0.0
var hg_trial_len: float = 1.0
var hg_kind: String = ""
var _hg_next: float = 25.0
var bell_ring_t: float = 0.0 # PORT-TRACE [화서문 어염시장]: 2x2 염전 소금 창고 기준 칸
var _cattle_timer: float = 8.0
var _thief_timer: float = 60.0
var _lawsuit_timer: float = 20.0
var _release_timer: float = 90.0
var _raid_captured: int = 0
var _messenger_timer: float = 10.0
var _logistics_timer: float = 4.0

## PORT-TRACE [사대문 물류]: 성문마다 다른 운반꾼(지도 끝 외부 길에서 들어와 성문 특화 시장 → 일부는 십자로 시전)
const GATE_CARRIERS := {
	"jangan": ["official_rider", "book_peddler", "gov_cart"],
	"paldal": ["ox_driver", "grain_cart", "bobusang"],
	"hwaseo": ["salt_porter", "fish_peddler", "salt_porter"],
	"changryong": ["wood_cart", "simmani", "wood_cart"],
}
const GATE_ARRIVE := {
	"jangan": ["한양 서책 들어왔소!", "도성 공문이오!", "한양 비단 받으시오!"],
	"paldal": ["삼남 햅쌀이오!", "좋은 소 몰고 왔소!", "무명·삼베 받으시오!"],
	"hwaseo": ["서해 소금 가마니요!", "갓 올라온 젓갈이오!", "조기·건어물 왔소!"],
	"changryong": ["광주 목재 왔소!", "참숯·장작이오!", "산삼·약초 캐 왔소!"],
}
const HUB_LINES := ["십자로 시전에 물건 대러 왔소!", "자, 흥정 한번 합시다!", "이 값이면 넘기리다!"]
var _workshop_cache: Array[Vector2i] = [] # 다 지은 공방(ind_1/ind_2) — 장인·짐꾼 배치용
var _roads_dirty: bool = true
var _dirty_nav_tiles: Dictionary = {} # Dirty Grid 패턴용 국소 변경 타일 목록

## [저잣거리 공터 POI 시스템] 난전·사당패·쉼터 연출 변수
## 공터(plaza kind="market") 목록 캐시 — 그리드 갱신 시 재구성
var _market_plaza_cache: Array[Vector2i] = []   # 저잣거리 공터(장마당) 앵커 좌표 목록
var _plaza_event_timer: float = 30.0            # 공터 이벤트 갱신 주기 (초)
var _plaza_events: Array[Dictionary] = []        # 활성 공터 이벤트 풀 [{pos, kind, agents, timer}]
const PLAZA_EVENT_KINDS: Array[String] = ["nan_jeon", "sandang", "shelter"]  # 난전/사당패/쉼터
const PLAZA_EVENT_COOLDOWN: float = 60.0        # 이벤트 하나당 최소 유지 시간(초)
const PLAZA_MAX_EVENTS: int = 3                 # 동시 활성 이벤트 최대 수

# PORT-TRACE [길찾기]: 사용자 요청 — "사람·동물이 건물을 뚫고 다니지 않게, 일반 백성은 길을 우선 따라
# 다니고, 사냥꾼·나무꾼·군인·도적·공사 인부만 숲과 들판을 자유롭게 오가며, 건물에는 입구로만 드나들게".
# 격자 전체를 두 벌의 AStarGrid2D로 만든다 — 길 우선(_astar_road: 길 1, 들판 4, 산 8)과 자유 이동
# (_astar_free: 들판 1, 산 1.6). 건물·성벽·물(다리 제외)은 둘 다 막힌 칸이다. 목적지가 건물이면
# 그 건물과 맞닿은 길(없으면 빈 땅) 칸을 "입구"로 삼아 거기까지 길을 찾고, 입구에서 건물 안으로 들어간다.
const FREE_ROAMERS := ["farmer", "hunter", "woodcutter", "patrol_soldier", "bandit", "chakhogapsa", "beater", "marksman", "bait",
	"guard", "mason", "foreman", "geojunggi", "nongno", "yuheonggeo", "tiger", "wolf", "ox_plow", "scarecrow", "sparrow_flock",
	"firefighter_soldier", "posu", "sasu", "salsu", "gipo", "water_play", "drowning", "catholic"]
const MILITARY_STRUCTURES := ["seojangdae", "bongdon", "gongsimdon", "poru", "yeonmudae", "patrol", "firefighter"]
## PORT-TRACE [NPC 클리핑 차단]: 사용자 요청 — "건물·성벽·제방 위를 뛰어넘거나 가로지르지 않게". 예전엔 제방과
## 서장대·봉돈·공심돈·포루·연무대·순라청·멸화군 칸이 통행 가능이라 그 위로 걸어 다녔다. 이제 길·성문·수로·논밭·빈 땅만
## 지나다닌다(순라청·멸화군에서 나오는 병사는 _find_path가 출발 칸만 잠시 열어 준다).
## PORT-TRACE [제방 보행로]: 사용자 후속 요청 — 제방은 길과 이어지는 보행 칸(낚시꾼·빨래 아낙·연날리기·석전 청년이 오르내림).
## 성벽·성곽 시설·건물은 계속 통행 불가라 성곽이 완공되면 모든 NPC(맹수 포함)는 성문·암문(gate 칸)으로만 성 안팎을 오간다.
const PASSABLE_BUILDINGS := ["", "road", "stone_road", "gate", "canal", "levee", "agr_1", "agr_2", "ruin", "burned_wasteland"]
const DIRS4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
var _astar_road: AStarGrid2D
var _astar_free: AStarGrid2D
var _entry_cache: Dictionary = {}
var _nav_version: int = 0
var _path_budget: int = 0 # 한 프레임에 새로 계산할 수 있는 경로 수(급격한 부하 방지)
var _path_request_queue: Array[Dictionary] = []
const MAX_PATHS_PER_FRAME: int = 4
# PORT-TRACE [배속 연동]: TimeManager 배율(정지 0, 1x, 2x, 3x). Main이 speed_changed 때 갱신한다.
var time_scale: float = 1.0

# 도적 침략 및 순라청 토벌 시스템 변수
var bandit_mgr = BanditManager.new()
var _bandit_mode: String = "outskirts" # "outskirts" (왕권 >= 30) vs "assault_palace" (왕권 < 30)
var _bandit_raid_timer: float = 35.0
var _bandit_raid_active: bool = false
var _bandit_raid_duration: float = 0.0
var _bandit_target_house: Vector2i = Vector2i.ZERO
var _dispatch_cooldown: float = 0.0
var _damage_tick_timer: float = 0.0
var _bandit_siege_hp: int = 500
var _bandit_siege_atk: int = 500
var _subjugation_active: bool = false

var _spawn_timer: float = 0.0
var _named_check_timer: float = 0.0
var _named_bubble_timer: float = 0.0
var _spot_spawn_timer: float = 0.0
var _wildlife_timer: float = 0.0
var _hunter_timer: float = 12.0
var _nongak_timer: float = 20.0
var _fire_spread_tick_timer: float = 1.6 # 셀룰러 오토마타 1.6초 고정 틱
var _fire_origin: Vector2i = Vector2i(-1, -1) # 최초 발화점 (최대 10x10 범위의 기준점)
var _flood_response_timer: float = 2.0 # 수해 방재/피난 연출 타이머
var _predator_timer: float = 0.0
var _predator_raid_cooldown: float = 20.0
var _next_agent_id: int = 1
var current_season: String = "봄"

# 네임드 NPC별 재출현 쿨다운 (초 단위)
var named_cooldowns: Dictionary = {
	"jeong_yakyong": 0.0,
	"chae_jegong": 10.0,
	"jo_simtae": 15.0,
	"kim_hongdo": 12.0,
	"kim_bau": 5.0,
	"gu_seonbok": 20.0,
	"yu_hanji": 25.0
}

# 네임드 인물 마스터 도감 데이터 (각 인물별 20+ 상황별 마스터 대사 풀)
const NAMED_INFO := {
	"jeong_yakyong": {
		"id": "jeong_yakyong",
		"name": "정약용 (丁若鏞)",
		"title": "실학자·수원화성 설계자",
		"role_tag": "실학자·설계자",
		"icon": "📐",
		"lines": [
			"호환이 잦으니 팔달산 수풀을 정비하고, 장용영의 방포(포루)를 점검해야 하오!",
			"국고가 바닥나면 모립제(募立制) 품삯 지급이 어려워지니, 상업 진흥으로 재정을 확충해야 하오.",
			"군량이 부족하면 일꾼들이 돌을 들 힘이 없소. 둔전(농지)을 확충하고 관개수로를 터야 하오.",
			"백성의 원망이 높으면 천하의 명성(名城)도 사상누각이오. 부역을 줄이고 구휼미를 풀어야 하오.",
			"성벽만 높다고 성이 아니오. 치성과 공심돈을 세워 화포와 쇠뇌를 배치할 군병이 시급하오.",
			"수원천 범람을 막지 못하면 신시의 터전이 잠길 것이오. 어서 석축 제방을 쌓아야 하오!",
			"새로운 성곽 설계도 《성설(城說)》을 마련했으니, 지체 없이 지대석을 놓고 축성을 시작해야 하오.",
			"아직 성곽의 둘레가 턱없이 모자라오. 팔달산에서 채석한 화강암을 서둘러 운반해야 하오.",
			"길이 통하지 않으면 유형거와 수레가 다닐 수 없소. 도로부터 닦아야 자재가 원활히 운반되오.",
			"가뭄에 대비하려면 북쪽에 만석거를 축조하여 물을 가두고 수구(水溝)를 연결해야 하오.",
			"수원천 석축 제방이 견고하여, 홍수가 밀려와도 칠보산 물길이 신시를 해치지 못할 것이오.",
			"규격화된 규석과 전돌을 섞어 쌓으니, 포격에도 무너지지 않는 불멸의 성곽이 완성되어 가는구려!",
			"만석거의 수문과 수로가 논으로 통하니, 올해 대풍년은 따놓은 당상이오.",
			"홍예문(虹霓門) 위의 누각이 위풍당당하오. 통행과 방어를 동시에 만족시키는 구조요.",
			"봄바람이 온화하여 흙과 돌이 잘 마르니, 성곽 기초를 다지기에 더없이 좋은 계절이오.",
			"장마철에는 석회 반죽이 씻겨나갈 수 있으니, 배수로를 열고 인부들에게 척서단을 내려야 하오.",
			"가을 추수가 끝나 장정들의 손길이 모였으니, 축성 역사를 서둘러 진척시켜야 하오.",
			"엄동설한에는 석재 틈새가 얼어붙기 쉬우니 무리한 쌓기를 삼가고 도면을 정밀 검토해야 하오.",
			"거중기를 쓰니 장정 수십 명이 들 바위를 한두 사람이 가뿐히 들어올리는구려!",
			"기중가설(起重架說)과 유형거를 활용하면 백성의 노고는 덜고 공사비는 반으로 줄일 수 있소.",
			"성곽은 공격과 방어가 일치해야 하오. 굽은 치성(雉城)을 두어 적의 측면을 타격해야 합니다."
		],
		"leave_line": "오늘 실측을 마쳤으니 행궁으로 돌아가 정밀히 도면을 보정해야겠소.",
		"desc": "정조의 특명을 받아 1792년 《성설(城說)》을 저술하고 거중기와 유형거를 발명하여 화성 축성의 기틀을 마련한 불세출의 실학자입니다.",
		"activity": "공사 현장에서 거중기와 성곽 설계도를 실측하고 있습니다."
	},
	"chae_jegong": {
		"id": "chae_jegong",
		"name": "채제공 (蔡濟恭)",
		"title": "영의정·화성성역 총리사",
		"role_tag": "영의정·총리사",
		"icon": "📜",
		"lines": [
			"도성에 범이 날뛰다니 가당치 않소! 어영청과 장용영을 동원해 백성을 지켜야 하오.",
			"국고가 여의치 않으니 공사비 집행을 절감하고, 불요불급한 지출을 즉시 통제하시오.",
			"일꾼들이 굶주리면 대역사는 멈추오. 황해도와 충청도의 세곡미를 수원창으로 전운(轉運)하시오.",
			"백성의 원성을 사며 짓는 성은 무너지는 법이오. 즉시 노역을 중단하고 위로미를 하사하시오.",
			"성곽만 있고 군율이 해이하면 어찌 화성을 지키겠소? 장용영 군병들의 훈련을 독려하시오.",
			"수원천에 제방이 없으면 여름 장마 한 번에 신시가 흙탕물에 잠길 것이오. 석축부터 착공하시오!",
			"전하께서 하교하신 화성 축성의 대업을 아직 시작하지 못했소. 속히 지대석을 놓으시오.",
			"관아와 행궁으로 이어지는 길이 좁고 거칠어 어가(御駕) 행렬이 지나기 어렵소. 도로를 넓히시오.",
			"신시가 번영하려면 난전을 혁파하고 통공(通共) 정책으로 저잣거리를 크게 열어야 하오.",
			"행궁과 동헌이 반듯하게 서야 정무를 집행하고 백성의 송사를 바로잡을 수 있소.",
			"수원천 석축 제방이 반석처럼 굳건하니, 수해 걱정 없이 성역을 총괄할 수 있겠구려.",
			"일꾼들에게 매일 품삯을 후하게 지급하니 백성의 원망 없이 성벽이 하루가 다르게 솟는구려!",
			"사통팔달 뚫린 대로를 보니 장차 삼남(三南)의 물류가 모두 이곳 화성으로 통할 것이오.",
			"성문이 웅장하게 서니 화성의 위의(威儀)가 비로소 드러나는구려. 전하께서 크게 기뻐하실 것이오.",
			"봄기운이 만물에 깃드니, 전국의 석수와 목수들을 모아 모립제 역사를 본격화하시오.",
			"삼복더위에 인부들이 쓰러지지 않도록 내의원에서 제중단(濟衆丹)을 지어 넉넉히 나누어 주시오.",
			"가을 들녘이 누렇게 익어가니, 성역에 참여한 백성들에게 곡식을 넉넉히 셈해주시오.",
			"혹한기에는 성돌 쌓기를 멈추고 자재를 비축하며 인부들에게 털옷을 하사해 온기를 보존케 하시오.",
			"화성 성역은 백성을 수탈하는 부역이 아니라, 품삯을 주어 백성을 부유하게 만드는 구휼의 역사요!",
			"일꾼 한 사람 한 사람의 이름을 의궤에 기록하여 후세에 그 공로를 길이 전할 것이오.",
			"전하의 지극한 효심과 탕평의 큰 뜻을 이 화성 신시에 아로새겨야 하오."
		],
		"leave_line": "오늘 시찰을 마쳤으니 정무를 보러 행궁으로 들겠다.",
		"desc": "영조와 정조 대의 명재상. 화성 축성 총책임자로서 일꾼들에게 정당한 품삯을 지급하는 모립제(募立制)를 시행하고 축성을 진두지휘했습니다.",
		"activity": "가마를 타고 행궁 앞 대로를 순시하며 성역 진척을 총괄하고 있습니다."
	},
	"jo_simtae": {
		"id": "jo_simtae",
		"name": "조심태 (趙心泰)",
		"title": "수원부사·화성 감동당상",
		"role_tag": "수원부사·감동당상",
		"icon": "🐎",
		"lines": [
			"산기슭에 맹수가 출몰하여 민심이 흉흉하오! 포수들을 소집하고 관아 주변 순찰을 강화하겠소.",
			"공소(工所)의 자금이 빠듯하오. 팔달산 석재 운반 비용을 아끼도록 유형거를 적극 투입하시오.",
			"인부들의 식량이 부족하면 하루 채석량이 반토막 나오. 인근 읍에서 미곡을 급히 조달하시오.",
			"노역자들의 불만이 팽배하오. 오늘 하루는 작업을 쉬고 쇠고기국과 막걸리를 베풀어야 하오.",
			"야간 순찰병의 무장이 부실하오. 군기시에서 환도와 조총을 신속히 수령해야겠소.",
			"수원천에 제방이 전혀 없소! 장마철에 급류가 터지면 공사 현장 전체가 수몰될 판이오!",
			"수원천 일부만 쌓아서는 모자라오. 천변을 따라 석축 제방을 더 연장해야 안전하오.",
			"길이 진흙탕이라 달구지가 빠지고 있소! 박석을 깔거나 흙길을 서둘러 다져야 하오.",
			"채석장에 돌은 가득한데 아직 성곽 터를 잡지 못했소. 실측 기점을 서둘러 정해주시오.",
			"대왕교 북쪽 황무지를 개간하려면 만석거 저수지를 축조해 물길을 확보해야 하오.",
			"수원천 석축 제방 공사가 순조롭게 마무리되어, 백 년 만의 큰비가 와도 끄떡없겠소!",
			"남북으로 뚫린 간선도로 덕분에 팔달산의 석재가 하루 만에 성벽 현장으로 닿고 있소.",
			"성벽이 높게 솟아오르니 팔달산 아래 수원골이 천혜의 요새로 탈바꿈하고 있구려.",
			"홍예문이 웅장하게 올라갔소! 석수들과 목수들의 노고를 치하하며 특별 품삯을 내리겠소.",
			"해빙기에 지반이 약해질 수 있으니, 도로 노면을 점검하고 수원천 물길을 정비하시오.",
			"장마철 수원천 수위를 주야로 감시하시오! 제방 감시탑에 봉화를 올릴 준비를 마쳤소.",
			"추수철이 지나 장정들이 대거 몰려왔으니, 성벽과 도로 포장 공사에 총력을 다하겠소.",
			"겨울철 빙판길에 석재 운반 수레가 미끄러지지 않도록 도로에 모래를 뿌리도록 지시했소.",
			"화성 감동당상으로서 밤낮으로 공사 일지를 쓰며 석재 하나, 쌀 한 되도 헛되이 쓰이지 않게 하겠소.",
			"튼튼한 길과 바른 물길이야말로 신시가 번영하는 근본이오."
		],
		"leave_line": "순시를 마쳤으니 관아로 복귀하여 공역 일지를 작성하겠소.",
		"desc": "화성 축성 현장의 실무 최고 책임자. 현장을 밤낮으로 누비며 석재 운반, 물자 보급, 수원천 치수를 실질적으로 총괄했습니다.",
		"activity": "말을 타고 수원 시내와 성곽 공사 구간을 순시하고 있습니다."
	},
	"kim_hongdo": {
		"id": "kim_hongdo",
		"name": "김홍도 (金弘道)",
		"title": "도화서 화원·단원(檀園)",
		"role_tag": "도화서 화원",
		"icon": "🎨",
		"lines": [
			"숲속에서 호랑이 울음이 들려 붓을 쥘 수가 없구나. 백성들의 안위가 몹시 염려되네.",
			"공방에 안료와 비단 살 돈마저 떨어졌으니, 신시의 재정이 참으로 곤궁한 모양이오.",
			"주막거리 솥에 죽 끓이는 연기조차 희미하니, 굶주린 백성의 초췌한 낯빛을 그리기 애달프구나.",
			"장터 백성들의 얼굴에 수심이 가득 차 있으니, 화폭에 먹구름만 드리우는구나.",
			"초소의 군병들이 졸고 있으니, 이래서야 어찌 당당한 군영의 기상을 그릴 수 있겠는가.",
			"저잣거리가 아직 없으니 장돌뱅이의 활기찬 풍속화를 그릴 수가 없어 참으로 적막하구나.",
			"사람 다니는 길이 없으니 행려객도 없고, 오가는 나그네의 정취도 담을 수 없네.",
			"수원천 물길이 거칠어 버드나무 아래 멱감는 아이들을 그릴 수가 없구려. 제방이 필요해.",
			"아직 성벽의 뼈대조차 보이지 않으니, 《성역의궤》 권두도(卷頭圖)를 어찌 시작하겠소.",
			"장대한 누각이 없으니 화성의 으뜸가는 절경을 화폭에 채울 수가 없구나.",
			"저잣거리에 비단 장수, 옹기 장수가 북적이니 진정한 태평성대의 풍속화가 완성되는구나!",
			"수원천 맑은 물과 늘어진 능수버들, 제방길 걷는 아낙들의 모습이 한 폭의 진경산수로세.",
			"용머리 치성과 푸른 성곽이 산세를 휘감은 모습이 실로 천하의 장관이로다.",
			"장안문의 웅장한 홍예와 옹성이 먹선 위에서 살아서 꿈틀거리는 듯하구나!",
			"봄날 수원천변에 복사꽃과 버들잎이 흩날리니, 진분홍 안료를 풀어 화폭에 담아야겠네.",
			"녹음이 짙은 방화수류정 연못에 연꽃이 만발하니, 더위를 잊고 붓을 휘두르게 되는구나.",
			"들판의 황금 벼이삭과 팔달산 단풍이 어우러져 황홀한 금수강산을 이루었구나.",
			"하얗게 눈 덮인 화성 성곽과 눈 쌓인 누각의 운치는 백 년에 한 번 볼까 한 절경일세.",
			"전하의 능행차와 백성들의 환호성을 한 치의 거짓 없이 《화성능행도》에 바치리라.",
			"그림이란 모름지기 살아 숨 쉬는 백성의 땀방울과 웃음소리가 배어 있어야 진짜 명작이지."
		],
		"leave_line": "오늘 화폭은 흡족하게 채웠구나. 주막으로 돌아가야겠어.",
		"desc": "정조의 총애를 받은 궁중 화원. 화성능행도, 행궁 전경도 및 화성성역의궤의 삽화를 담당하며 정조 시대의 생생한 삶을 화폭에 기록했습니다.",
		"activity": "저잣거리와 수원천변에서 백성들의 일상 풍속을 화폭에 사생하고 있습니다."
	},
	"kim_bau": {
		"id": "kim_bau",
		"name": "석수 김바우 (金바우)",
		"title": "수원화성 수석 석공 명장",
		"role_tag": "수석 석공 명장",
		"icon": "🔨",
		"lines": [
			"팔달산 채석장에 범이 내려왔다니 정을 놓고 도망쳤소! 군사들이 호랑이를 먼저 잡아야 일하겠소!",
			"품삯이 밀리면 석수들이 뿔뿔이 흩어지오! 제때 엽전을 쥐여주어야 쇠망치를 쥐지요!",
			"바위를 깨뜨리려면 쌀밥심이 있어야 하오! 소금국에 보리밥이라도 든든히 먹여주시오!",
			"인부들의 불만이 커서 돌 다듬는 소리가 거칠어졌소. 이대로는 성벽이 비뚤어지겠소.",
			"성곽에 여장(女墻)과 총안(銃眼)을 뚫어두었는데, 지킬 군사가 없다니 답답할 노릇이오.",
			"팔달산에서 캐낸 화강암이 산더미요! 성곽 기초 지대석을 어디에 놓을지 어서 일러주시오!",
			"아직 성벽이 허리께도 안 찼소! 장정들을 더 붙여주어야 가을 전에 올릴 텐데!",
			"수원천 물길에 돌을 안 쌓으면 장마에 공사장 다 쓸려가오! 제방돌부터 깎아야 하오!",
			"수레길이 울퉁불퉁해서 수천 근짜리 성돌을 실은 유형거 바퀴가 부러졌소! 길부터 닦아주시오!",
			"저수지 수문에 쓸 방청석(防廳石)을 다 다듬어놨는데 만석거 터를 아직 안 파셨소?",
			"수원천 제방돌을 정으로 깎아 빈틈없이 맞췄으니, 용이 용트림해도 꿈쩍 안 할 걸세!",
			"팔달산 화강암과 구운 전돌이 찰떡궁합이오! 천 년을 갈 철벽 성곽이 완성되어 가오!",
			"성문 홍예석(虹霓石)을 반듯하게 짜 맞추고 나니, 내 석수 인생에 가장 자랑스런 걸작이오!",
			"거중기와 녹로 덕분에 인부들 허리 안 다치고 큰 바위를 번쩍번쩍 올리니 살맛 나오!",
			"땅이 녹았으니 채석장에 정을 박고 쐐기를 칠 때요! 깡깡 울리는 쇠망치 소리가 아주 경쾌하오.",
			"땡볕에 달궈진 돌은 살갗을 태울 듯 뜨겁소! 얼음물과 척서단을 보내준 조정에 감사하오.",
			"바람이 선선하니 돌 깎기에 이보다 좋은 철이 없소! 오늘 하루에 규석 서른 개를 깎겠소!",
			"손이 얼어 정을 놓치기 십상이오. 모닥불에 손을 녹이며 조심조심 정질을 해야 하오.",
			"돌은 거짓말을 안 하오. 정으로 한 번 더 두드릴수록 성벽은 백 년을 더 버티는 법이지.",
			"화홍문 일곱 수문 위에 올릴 용머리 석조는 내 평생의 정기를 쏟아부어 새길 걸세!"
		],
		"leave_line": "오늘 성돌 다듬기는 여기까지! 쇠망치를 챙겨 쉬러 가세.",
		"desc": "팔달산 채석장에서 화강암을 캐내고 다듬은 최고의 장인. 화성 성곽의 견고한 치성과 화서문·창룡문의 섬세한 석조물을 완성했습니다.",
		"activity": "팔달산 채석장과 성곽 아래에서 거대한 화강암을 정으로 다듬고 있습니다."
	},
	"gu_seonbok": {
		"id": "gu_seonbok",
		"name": "구선복 (具善復)",
		"title": "훈련대장·장용영 군사 지휘관",
		"role_tag": "훈련대장·장용영 지휘관",
		"icon": "⚔️",
		"lines": [
			"착호갑사(捉虎甲士) 전원 출동! 조총과 창을 겨누고 맹수를 포위 섬멸하라!",
			"군병들의 기강이 해이하고 훈련이 태만하다! 당장 서장대 아래로 집결하여 무예별감을 세워라!",
			"군량이 바닥나면 군심(軍心)이 흔들린다! 비축미를 군영으로 우선 배급하라!",
			"군수 자금이 부족해 조총의 화약과 조련 탄환이 동났다! 병조에 군자금을 긴급 청구하라.",
			"민심이 소요하면 성 안에서 변란이 일어날 수 있다! 성문 검문을 강화하고 첩자를 색출하라.",
			"서장대와 봉돈이 없으니 적의 동태를 감시할 눈과 귀가 없다! 군사 지휘소를 서둘러 세워라!",
			"방벽 하나 없는 벌판에서 어찌 도성을 지키겠는가? 외곽 방어선 성곽을 즉시 축조하라!",
			"성벽이 끊겨 있어 적의 침투에 무방비하다! 치성과 포루를 촘촘히 연결하라!",
			"성문이 없으면 유사시 군병의 출격과 차단이 불가능하다! 옹성을 갖춘 홍예문을 세워라!",
			"작전 도로가 좁아 기마대와 화포 수레가 기동할 수 없다! 군용 간선도로를 개통하라!",
			"서장대에서 휘하 군병을 한눈에 지휘하고, 봉돈의 다섯 횃불이 삼남으로 통하니 든든하도다!",
			"공심돈과 치성이 물샐틈없이 배치되어 왜적이든 청군이든 결코 뚫지 못할 철벽이다!",
			"장용영 군사들의 기운이 하늘을 찌른다! 주야간 야조(夜操) 훈련에 오차가 없도다!",
			"견고한 옹성과 적대를 갖춘 성문을 보니 조선 제일의 요새라 부르기에 부족함이 없다!",
			"해빙기 군영 정비를 마치고 성곽 경계 태세를 점검하라! 기마 조련을 시작한다!",
			"장마철에 화약이 눅눅해지지 않도록 군기고를 바짝 말리고 조총 격발 상태를 점검하라!",
			"추수기 군량미를 군창에 수매하고, 장용외영 군병들의 추계 대사습(활쏘기 대회)을 거행한다!",
			"엄동설한에도 보초병의 눈빛은 번뜩여야 한다! 얼어붙은 해자에 적의 척후병이 없는지 살피라!",
			"화성은 단순한 행궁이 아니라 국왕을 보위하고 북벌을 도모할 최후의 전략 거점이다.",
			"장용영의 군기는 추상같아야 한다! 한 치의 방심도 역적과 침략자에게 틈을 주는 법이다."
		],
		"leave_line": "군기 검열을 마쳤으니 장용영 군영으로 복귀한다!",
		"desc": "정조 연간 화성의 방위를 책임진 군사 지휘관. 성곽 내외의 군사 배치와 장용영 군병 훈련을 엄정하게 총괄했습니다.",
		"activity": "서장대와 성문에서 장용영 군병들의 군기를 검열하고 있습니다."
	},
	"yu_hanji": {
		"id": "yu_hanji",
		"name": "유한지 (兪漢芝)",
		"title": "조선 최고의 예서 명필",
		"role_tag": "예서 명필·서예가",
		"icon": "🖌️",
		"lines": [
			"사나운 맹수 소리에 붓끝이 떨리는구려. 묵향(墨香) 대신 피비린내가 나선 아니 될 텐데.",
			"현판에 입힐 금박과 질 좋은 송연묵(松煙墨)조차 구할 길 없으니 신시의 살림이 딱하구려.",
			"백성이 주리는데 화려한 현판이 무슨 소용이겠소. 굶주림을 면하는 것이 으뜸 문예이오.",
			"백성들의 시름 젖은 한숨 소리가 먹물에 번져 붓을 적실 수가 없구려.",
			"문(文)과 무(武)는 수레의 두 바퀴인데, 군비가 허술하니 성곽의 품격이 서지 않는구려.",
			"장안문 현판 글씨를 품에 품고 있건만, 걸어둘 성문 누각이 아직 없으니 애석하구나!",
			"성곽 없는 황량한 벌판에 무슨 글씨를 새기겠소? 도성의 골격부터 세워주시오.",
			"수원천 둑길이 삭막하여 물길의 풍류를 읊을 수가 없네. 단단한 석축이 먼저라오.",
			"사방으로 통하는 길이 없으니 선비들의 발길도 끊기고 묵향도 흩어지는구려.",
			"만석서호(萬石西湖)의 풍광을 노래할 저수지가 아직 파이지 않았소.",
			"장안문(長安門) 세 글자, 백성의 만대 태평을 빌며 한 획 한 획 예서로 정성껏 새겼네!",
			"사대문의 현판이 모두 걸리니 성곽의 위의와 문기(文氣)가 온 누리에 빛나는구려!",
			"수원천 맑은 물결 위에 화홍문(華虹門) 편액을 거니 물보라와 글씨가 어우러져 절경이로다!",
			"성돌 하나하나에 깃든 장인의 혼이 마치 힘찬 해서(楷書) 한 획과도 같구려.",
			"봄볕 아래 먹을 가니 먹향이 그윽하오. 새 봄을 맞아 행궁에 입춘대길(立春大吉)을 써 붙이세.",
			"장마철 습기에도 먹빛이 바래지 않도록, 최고급 아교로 정성껏 먹물을 배합하고 있네.",
			"청명한 가을 하늘 아래 방화수류정(訪花隨柳亭) 편액 글씨가 한층 더 운치 있게 돋보이는구려.",
			"벼루의 먹물이 어는 추위 속에서도, 선비의 지조를 담아 굳은 필획을 내리긋고 있소.",
			"예서(隷書)의 필획은 웅장하면서도 단정해야 화성의 기품과 진정으로 어울린다네.",
			"화성의 아름다움은 돌과 나무의 견고함뿐 아니라 그 안에 깃든 문치(文治)의 뜻에 있다오.",
			"방화수류정(꽃을 찾고 버들을 따라 노닌다) 현판은 자연과 정자가 하나 되는 경지를 담았네.",
			"글씨는 곧 그 사람의 마음이요, 도성의 현판은 임금의 덕성을 만천하에 드러내는 거울이지."
		],
		"leave_line": "성문 현판 휘호를 마쳤으니 서재로 돌아가세.",
		"desc": "화성 주요 건물의 현판과 표석 글씨를 쓴 명필. 장안문, 화서문 등의 현판 글씨를 담당하며 화성의 문화적 기품을 더했습니다.",
		"activity": "서안(책상)에서 웅장한 필체로 성문 현판 휘호를 작성하고 있습니다."
	}
}

## 네임드 NPC의 현재 도시 상태·민심·국정 실태·계절 기반 동적 대사 선택 엔진
func get_contextual_named_line(named_id: String) -> String:
	var is_tiger: bool = (court != null and court.tiger.get("active", false))
	var n_levee: int = _levee_cache.size()
	var n_wall: int = _wall_cache.size()
	var n_gate: int = _gate_cache.size()
	var n_road: int = _roads_cache.size()
	var n_com: int = _com_cache.size()
	var n_office: int = _office_cache.size()
	var n_mil: int = _military_cache.size()
	var n_resv: int = _reservoir_cache.size()

	var cur_gold: int = sim.gold if sim != null else 2500
	var cur_rice: int = sim.rice if sim != null else 1600
	var _cur_pop: int = sim.population if sim != null else 120
	var cur_loyalty: int = sim.loyalty if sim != null else 88
	var cur_mil: int = sim.military_power if sim != null else 70

	var urgent_lines: Array[String] = []
	var advice_lines: Array[String] = []
	var compliment_lines: Array[String] = []
	var season_lines: Array[String] = []
	var persona_lines: Array[String] = []
	var urgent_tiger: Array[String] = []

	match named_id:
		"jeong_yakyong":
			if is_tiger:
				urgent_tiger.append("호환이 잦으니 팔달산 수풀을 정비하고, 장용영의 방포(포루)를 점검해야 하오!")
			if cur_gold < 300:
				urgent_lines.append("국고가 바닥나면 모립제(募立制) 품삯 지급이 어려워지니, 상업 진흥으로 재정을 확충해야 하오.")
			if cur_rice < 200:
				urgent_lines.append("군량이 부족하면 일꾼들이 돌을 들 힘이 없소. 둔전(농지)을 확충하고 관개수로를 터야 하오.")
			if cur_loyalty < 45:
				urgent_lines.append("백성의 원망이 높으면 천하의 명성(名城)도 사상누각이오. 부역을 줄이고 구휼미를 풀어야 하오.")
			if cur_mil < 45:
				urgent_lines.append("성벽만 높다고 성이 아니오. 치성과 공심돈을 세워 화포와 쇠뇌를 배치할 군병이 시급하오.")

			if n_levee == 0:
				advice_lines.append("수원천 범람을 막지 못하면 신시의 터전이 잠길 것이오. 어서 석축 제방을 쌓아야 하오!")
			if n_wall == 0:
				advice_lines.append("새로운 성곽 설계도 《성설(城說)》을 마련했으니, 지체 없이 지대석을 놓고 축성을 시작해야 하오.")
			elif n_wall < 15:
				advice_lines.append("아직 성곽의 둘레가 턱없이 모자라오. 팔달산에서 채석한 화강암을 서둘러 운반해야 하오.")
			if n_road < 10:
				advice_lines.append("길이 통하지 않으면 유형거와 수레가 다닐 수 없소. 도로부터 닦아야 자재가 원활히 운반되오.")
			if n_resv == 0:
				advice_lines.append("가뭄에 대비하려면 북쪽에 만석거를 축조하여 물을 가두고 수구(水溝)를 연결해야 하오.")

			if n_levee >= 3:
				compliment_lines.append("수원천 석축 제방이 견고하여, 홍수가 밀려와도 칠보산 물길이 신시를 해치지 못할 것이오.")
			if n_wall >= 30:
				compliment_lines.append("규격화된 규석과 전돌을 섞어 쌓으니, 포격에도 무너지지 않는 불멸의 성곽이 완성되어 가는구려!")
			if n_resv >= 1:
				compliment_lines.append("만석거의 수문과 수로가 논으로 통하니, 올해 대풍년은 따놓은 당상이오.")
			if n_gate >= 2:
				compliment_lines.append("홍예문(虹霓門) 위의 누각이 위풍당당하오. 통행과 방어를 동시에 만족시키는 구조요.")

			match current_season:
				"봄": season_lines.append("봄바람이 온화하여 흙과 돌이 잘 마르니, 성곽 기초를 다지기에 더없이 좋은 계절이오.")
				"여름": season_lines.append("장마철에는 석회 반죽이 씻겨나갈 수 있으니, 배수로를 열고 인부들에게 척서단을 내려야 하오.")
				"가을": season_lines.append("가을 추수가 끝나 장정들의 손길이 모였으니, 축성 역사를 서둘러 진척시켜야 하오.")
				"겨울": season_lines.append("엄동설한에는 석재 틈새가 얼어붙기 쉬우니 무리한 쌓기를 삼가고 도면을 정밀 검토해야 하오.")

			persona_lines.append("거중기를 쓰니 장정 수십 명이 들 바위를 한두 사람이 가뿐히 들어올리는구려!")
			persona_lines.append("기중가설(起重架說)과 유형거를 활용하면 백성의 노고는 덜고 공사비는 반으로 줄일 수 있소.")
			persona_lines.append("성곽은 공격과 방어가 일치해야 하오. 굽은 치성(雉城)을 두어 적의 측면을 타격해야 합니다.")

		"chae_jegong":
			if is_tiger:
				urgent_tiger.append("도성에 범이 날뛰다니 가당치 않소! 어영청과 장용영을 동원해 백성을 지켜야 하오.")
			if cur_gold < 300:
				urgent_lines.append("국고가 여의치 않으니 공사비 집행을 절감하고, 불요불급한 지출을 즉시 통제하시오.")
			if cur_rice < 200:
				urgent_lines.append("일꾼들이 굶주리면 대역사는 멈추오. 황해도와 충청도의 세곡미를 수원창으로 전운(轉運)하시오.")
			if cur_loyalty < 45:
				urgent_lines.append("백성의 원성을 사며 짓는 성은 무너지는 법이오. 즉시 노역을 중단하고 위로미를 하사하시오.")
			if cur_mil < 45:
				urgent_lines.append("성곽만 있고 군율이 해이하면 어찌 화성을 지키겠소? 장용영 군병들의 훈련을 독려하시오.")

			if n_levee == 0:
				advice_lines.append("수원천에 제방이 없으면 여름 장마 한 번에 신시가 흙탕물에 잠길 것이오. 석축부터 착공하시오!")
			if n_wall == 0:
				advice_lines.append("전하께서 하교하신 화성 축성의 대업을 아직 시작하지 못했소. 속히 지대석을 놓으시오.")
			if n_road < 10:
				advice_lines.append("관아와 행궁으로 이어지는 길이 좁고 거칠어 어가(御駕) 행렬이 지나기 어렵소. 도로를 넓히시오.")
			if n_com == 0:
				advice_lines.append("신시가 번영하려면 난전을 혁파하고 통공(通共) 정책으로 저잣거리를 크게 열어야 하오.")
			if n_office == 0:
				advice_lines.append("행궁과 동헌이 반듯하게 서야 정무를 집행하고 백성의 송사를 바로잡을 수 있소.")

			if n_levee >= 3:
				compliment_lines.append("수원천 석축 제방이 반석처럼 굳건하니, 수해 걱정 없이 성역을 총괄할 수 있겠구려.")
			if n_wall >= 30:
				compliment_lines.append("일꾼들에게 매일 품삯을 후하게 지급하니 백성의 원망 없이 성벽이 하루가 다르게 솟는구려!")
			if n_road >= 20:
				compliment_lines.append("사통팔달 뚫린 대로를 보니 장차 삼남(三南)의 물류가 모두 이곳 화성으로 통할 것이오.")
			if n_gate >= 2:
				compliment_lines.append("성문이 웅장하게 서니 화성의 위의(威儀)가 비로소 드러나는구려. 전하께서 크게 기뻐하실 것이오.")

			match current_season:
				"봄": season_lines.append("봄기운이 만물에 깃드니, 전국의 석수와 목수들을 모아 모립제 역사를 본격화하시오.")
				"여름": season_lines.append("삼복더위에 인부들이 쓰러지지 않도록 내의원에서 제중단(濟衆丹)을 지어 넉넉히 나누어 주시오.")
				"가을": season_lines.append("가을 들녘이 누렇게 익어가니, 성역에 참여한 백성들에게 곡식을 넉넉히 셈해주시오.")
				"겨울": season_lines.append("혹한기에는 성돌 쌓기를 멈추고 자재를 비축하며 인부들에게 털옷을 하사해 온기를 보존케 하시오.")

			persona_lines.append("화성 성역은 백성을 수탈하는 부역이 아니라, 품삯을 주어 백성을 부유하게 만드는 구휼의 역사요!")
			persona_lines.append("일꾼 한 사람 한 사람의 이름을 의궤에 기록하여 후세에 그 공로를 길이 전할 것이오.")
			persona_lines.append("전하의 지극한 효심과 탕평의 큰 뜻을 이 화성 신시에 아로새겨야 하오.")

		"jo_simtae":
			if is_tiger:
				urgent_tiger.append("산기슭에 맹수가 출몰하여 민심이 흉흉하오! 포수들을 소집하고 관아 주변 순찰을 강화하겠소.")
			if cur_gold < 300:
				urgent_lines.append("공소(工所)의 자금이 빠듯하오. 팔달산 석재 운반 비용을 아끼도록 유형거를 적극 투입하시오.")
			if cur_rice < 200:
				urgent_lines.append("인부들의 식량이 부족하면 하루 채석량이 반토막 나오. 인근 읍에서 미곡을 급히 조달하시오.")
			if cur_loyalty < 45:
				urgent_lines.append("노역자들의 불만이 팽배하오. 오늘 하루는 작업을 쉬고 쇠고기국과 막걸리를 베풀어야 하오.")
			if cur_mil < 45:
				urgent_lines.append("야간 순찰병의 무장이 부실하오. 군기시에서 환도와 조총을 신속히 수령해야겠소.")

			# 제방 0개일 때 확실한 경고 대사 출력
			if n_levee == 0:
				advice_lines.append("수원천에 제방이 전혀 없소! 장마철에 급류가 터지면 공사 현장 전체가 수몰될 판이오!")
			elif n_levee < 3:
				advice_lines.append("수원천 일부만 쌓아서는 모자라오. 천변을 따라 석축 제방을 더 연장해야 안전하오.")
			if n_road < 10:
				advice_lines.append("길이 진흙탕이라 달구지가 빠지고 있소! 박석을 깔거나 흙길을 서둘러 다져야 하오.")
			if n_wall == 0:
				advice_lines.append("채석장에 돌은 가득한데 아직 성곽 터를 잡지 못했소. 실측 기점을 서둘러 정해주시오.")
			if n_resv == 0:
				advice_lines.append("대왕교 북쪽 황무지를 개간하려면 만석거 저수지를 축조해 물길을 확보해야 하오.")

			# 제방 3개 이상 완공 시에만 안심 대사 출력
			if n_levee >= 3:
				compliment_lines.append("수원천 석축 제방 공사가 순조롭게 마무리되어, 백 년 만의 큰비가 와도 끄떡없겠소!")
			if n_road >= 15:
				compliment_lines.append("남북으로 뚫린 간선도로 덕분에 팔달산의 석재가 하루 만에 성벽 현장으로 닿고 있소.")
			if n_wall >= 25:
				compliment_lines.append("성벽이 높게 솟아오르니 팔달산 아래 수원골이 천혜의 요새로 탈바꿈하고 있구려.")
			if n_gate >= 1:
				compliment_lines.append("홍예문이 웅장하게 올라갔소! 석수들과 목수들의 노고를 치하하며 특별 품삯을 내리겠소.")

			match current_season:
				"봄": season_lines.append("해빙기에 지반이 약해질 수 있으니, 도로 노면을 점검하고 수원천 물길을 정비하시오.")
				"여름": season_lines.append("장마철 수원천 수위를 주야로 감시하시오! 제방 감시탑에 봉화를 올릴 준비를 마쳤소.")
				"가을": season_lines.append("추수철이 지나 장정들이 대거 몰려왔으니, 성벽과 도로 포장 공사에 총력을 다하겠소.")
				"겨울": season_lines.append("겨울철 빙판길에 석재 운반 수레가 미끄러지지 않도록 도로에 모래를 뿌리도록 지시했소.")

			persona_lines.append("화성 감동당상으로서 밤낮으로 공사 일지를 쓰며 석재 하나, 쌀 한 되도 헛되이 쓰이지 않게 하겠소.")
			persona_lines.append("튼튼한 길과 바른 물길이야말로 신시가 번영하는 근본이오.")

		"kim_hongdo":
			if is_tiger:
				urgent_tiger.append("숲속에서 호랑이 울음이 들려 붓을 쥘 수가 없구나. 백성들의 안위가 몹시 염려되네.")
			if cur_gold < 300:
				urgent_lines.append("공방에 안료와 비단 살 돈마저 떨어졌으니, 신시의 재정이 참으로 곤궁한 모양이오.")
			if cur_rice < 200:
				urgent_lines.append("주막거리 솥에 죽 끓이는 연기조차 희미하니, 굶주린 백성의 초췌한 낯빛을 그리기 애달프구나.")
			if cur_loyalty < 45:
				urgent_lines.append("장터 백성들의 얼굴에 수심이 가득 차 있으니, 화폭에 먹구름만 드리우는구나.")
			if cur_mil < 45:
				urgent_lines.append("초소의 군병들이 졸고 있으니, 이래서야 어찌 당당한 군영의 기상을 그릴 수 있겠는가.")

			if n_com == 0:
				advice_lines.append("저잣거리가 아직 없으니 장돌뱅이의 활기찬 풍속화를 그릴 수가 없어 참으로 적막하구나.")
			if n_road < 10:
				advice_lines.append("사람 다니는 길이 없으니 행려객도 없고, 오가는 나그네의 정취도 담을 수 없네.")
			if n_levee == 0:
				advice_lines.append("수원천 물길이 거칠어 버드나무 아래 멱감는 아이들을 그릴 수가 없구려. 제방이 필요해.")
			if n_wall == 0:
				advice_lines.append("아직 성벽의 뼈대조차 보이지 않으니, 《성역의궤》 권두도(卷頭圖)를 어찌 시작하겠소.")
			if n_gate == 0:
				advice_lines.append("장대한 누각이 없으니 화성의 으뜸가는 절경을 화폭에 채울 수가 없구나.")

			if n_com >= 8:
				compliment_lines.append("저잣거리에 비단 장수, 옹기 장수가 북적이니 진정한 태평성대의 풍속화가 완성되는구나!")
			if n_levee >= 3:
				compliment_lines.append("수원천 맑은 물과 늘어진 능수버들, 제방길 걷는 아낙들의 모습이 한 폭의 진경산수로세.")
			if n_wall >= 25:
				compliment_lines.append("용머리 치성과 푸른 성곽이 산세를 휘감은 모습이 실로 천하의 장관이로다.")
			if n_gate >= 2:
				compliment_lines.append("장안문의 웅장한 홍예와 옹성이 먹선 위에서 살아서 꿈틀거리는 듯하구나!")

			match current_season:
				"봄": season_lines.append("봄날 수원천변에 복사꽃과 버들잎이 흩날리니, 진분홍 안료를 풀어 화폭에 담아야겠네.")
				"여름": season_lines.append("녹음이 짙은 방화수류정 연못에 연꽃이 만발하니, 더위를 잊고 붓을 휘두르게 되는구나.")
				"가을": season_lines.append("들판의 황금 벼이삭과 팔달산 단풍이 어우러져 황홀한 금수강산을 이루었구나.")
				"겨울": season_lines.append("하얗게 눈 덮인 화성 성곽과 눈 쌓인 누각의 운치는 백 년에 한 번 볼까 한 절경일세.")

			persona_lines.append("전하의 능행차와 백성들의 환호성을 한 치의 거짓 없이 《화성능행도》에 바치리라.")
			persona_lines.append("그림이란 모름지기 살아 숨 쉬는 백성의 땀방울과 웃음소리가 배어 있어야 진짜 명작이지.")

		"kim_bau":
			if is_tiger:
				urgent_tiger.append("팔달산 채석장에 범이 내려왔다니 정을 놓고 도망쳤소! 군사들이 호랑이를 먼저 잡아야 일하겠소!")
			if cur_gold < 300:
				urgent_lines.append("품삯이 밀리면 석수들이 뿔뿔이 흩어지오! 제때 엽전을 쥐여주어야 쇠망치를 쥐지요!")
			if cur_rice < 200:
				urgent_lines.append("바위를 깨뜨리려면 쌀밥심이 있어야 하오! 소금국에 보리밥이라도 든든히 먹여주시오!")
			if cur_loyalty < 45:
				urgent_lines.append("인부들의 불만이 커서 돌 다듬는 소리가 거칠어졌소. 이대로는 성벽이 비뚤어지겠소.")
			if cur_mil < 45:
				urgent_lines.append("성곽에 여장(女墻)과 총안(銃眼)을 뚫어두었는데, 지킬 군사가 없다니 답답할 노릇이오.")

			if n_wall == 0:
				advice_lines.append("팔달산에서 캐낸 화강암이 산더미요! 성곽 기초 지대석을 어디에 놓을지 어서 일러주시오!")
			elif n_wall < 15:
				advice_lines.append("아직 성벽이 허리께도 안 찼소! 장정들을 더 붙여주어야 가을 전에 올릴 텐데!")
			if n_levee == 0:
				advice_lines.append("수원천 물길에 돌을 안 쌓으면 장마에 공사장 다 쓸려가오! 제방돌부터 깎아야 하오!")
			if n_road < 10:
				advice_lines.append("수레길이 울퉁불퉁해서 수천 근짜리 성돌을 실은 유형거 바퀴가 부러졌소! 길부터 닦아주시오!")
			if n_resv == 0:
				advice_lines.append("저수지 수문에 쓸 방청석(防廳石)을 다 다듬어놨는데 만석거 터를 아직 안 파셨소?")

			if n_levee >= 3:
				compliment_lines.append("수원천 제방돌을 정으로 깎아 빈틈없이 맞췄으니, 용이 용트림해도 꿈쩍 안 할 걸세!")
			if n_wall >= 30:
				compliment_lines.append("팔달산 화강암과 구운 전돌이 찰떡궁합이오! 천 년을 갈 철벽 성곽이 완성되어 가오!")
			if n_gate >= 2:
				compliment_lines.append("성문 홍예석(虹霓石)을 반듯하게 짜 맞추고 나니, 내 석수 인생에 가장 자랑스런 걸작이오!")
			if n_wall >= 15:
				compliment_lines.append("거중기와 녹로 덕분에 인부들 허리 안 다치고 큰 바위를 번쩍번쩍 올리니 살맛 나오!")

			match current_season:
				"봄": season_lines.append("땅이 녹았으니 채석장에 정을 박고 쐐기를 칠 때요! 깡깡 울리는 쇠망치 소리가 아주 경쾌하오.")
				"여름": season_lines.append("땡볕에 달궈진 돌은 살갗을 태울 듯 뜨겁소! 얼음물과 척서단을 보내준 조정에 감사하오.")
				"가을": season_lines.append("바람이 선선하니 돌 깎기에 이보다 좋은 철이 없소! 오늘 하루에 규석 서른 개를 깎겠소!")
				"겨울": season_lines.append("손이 얼어 정을 놓치기 십상이오. 모닥불에 손을 녹이며 조심조심 정질을 해야 하오.")

			persona_lines.append("돌은 거짓말을 안 하오. 정으로 한 번 더 두드릴수록 성벽은 백 년을 더 버티는 법이지.")
			persona_lines.append("화홍문 일곱 수문 위에 올릴 용머리 석조는 내 평생의 정기를 쏟아부어 새길 걸세!")

		"gu_seonbok":
			if is_tiger:
				urgent_tiger.append("착호갑사(捉虎甲士) 전원 출동! 조총과 창을 겨누고 맹수를 포위 섬멸하라!")
			if cur_mil < 45:
				urgent_lines.append("군병들의 기강이 해이하고 훈련이 태만하다! 당장 서장대 아래로 집결하여 무예별감을 세워라!")
			if cur_rice < 200:
				urgent_lines.append("군량이 바닥나면 군심(軍心)이 흔들린다! 비축미를 군영으로 우선 배급하라!")
			if cur_gold < 300:
				urgent_lines.append("군수 자금이 부족해 조총의 화약과 조련 탄환이 동났다! 병조에 군자금을 긴급 청구하라.")
			if cur_loyalty < 45:
				urgent_lines.append("민심이 소요하면 성 안에서 변란이 일어날 수 있다! 성문 검문을 강화하고 첩자를 색출하라.")

			if n_mil == 0:
				advice_lines.append("서장대와 봉돈이 없으니 적의 동태를 감시할 눈과 귀가 없다! 군사 지휘소를 서둘러 세워라!")
			if n_wall == 0:
				advice_lines.append("방벽 하나 없는 벌판에서 어찌 도성을 지키겠는가? 외곽 방어선 성곽을 즉시 축조하라!")
			elif n_wall < 15:
				advice_lines.append("성벽이 끊겨 있어 적의 침투에 무방비하다! 치성과 포루를 촘촘히 연결하라!")
			if n_gate == 0:
				advice_lines.append("성문이 없으면 유사시 군병의 출격과 차단이 불가능하다! 옹성을 갖춘 홍예문을 세워라!")
			if n_road < 10:
				advice_lines.append("작전 도로가 좁아 기마대와 화포 수레가 기동할 수 없다! 군용 간선도로를 개통하라!")

			if n_mil >= 2:
				compliment_lines.append("서장대에서 휘하 군병을 한눈에 지휘하고, 봉돈의 다섯 횃불이 삼남으로 통하니 든든하도다!")
			if n_wall >= 30:
				compliment_lines.append("공심돈과 치성이 물샐틈없이 배치되어 왜적이든 청군이든 결코 뚫지 못할 철벽이다!")
			if cur_mil >= 75:
				compliment_lines.append("장용영 군사들의 기운이 하늘을 찌른다! 주야간 야조(夜操) 훈련에 오차가 없도다!")
			if n_gate >= 2:
				compliment_lines.append("견고한 옹성과 적대를 갖춘 성문을 보니 조선 제일의 요새라 부르기에 부족함이 없다!")

			match current_season:
				"봄": season_lines.append("해빙기 군영 정비를 마치고 성곽 경계 태세를 점검하라! 기마 조련을 시작한다!")
				"여름": season_lines.append("장마철에 화약이 눅눅해지지 않도록 군기고를 바짝 말리고 조총 격발 상태를 점검하라!")
				"가을": season_lines.append("추수기 군량미를 군창에 수매하고, 장용외영 군병들의 추계 대사습(활쏘기 대회)을 거행한다!")
				"겨울": season_lines.append("엄동설한에도 보초병의 눈빛은 번뜩여야 한다! 얼어붙은 해자에 적의 척후병이 없는지 살피라!")

			persona_lines.append("화성은 단순한 행궁이 아니라 국왕을 보위하고 북벌을 도모할 최후의 전략 거점이다.")
			persona_lines.append("장용영의 군기는 추상같아야 한다! 한 치의 방심도 역적과 침략자에게 틈을 주는 법이다.")

		"yu_hanji":
			if is_tiger:
				urgent_tiger.append("사나운 맹수 소리에 붓끝이 떨리는구려. 묵향(墨香) 대신 피비린내가 나선 아니 될 텐데.")
			if cur_gold < 300:
				urgent_lines.append("현판에 입힐 금박과 질 좋은 송연묵(松煙墨)조차 구할 길 없으니 신시의 살림이 딱하구려.")
			if cur_rice < 200:
				urgent_lines.append("백성이 주리는데 화려한 현판이 무슨 소용이겠소. 굶주림을 면하는 것이 으뜸 문예이오.")
			if cur_loyalty < 45:
				urgent_lines.append("백성들의 시름 젖은 한숨 소리가 먹물에 번져 붓을 적실 수가 없구려.")
			if cur_mil < 45:
				urgent_lines.append("문(文)과 무(武)는 수레의 두 바퀴인데, 군비가 허술하니 성곽의 품격이 서지 않는구려.")

			if n_gate == 0:
				advice_lines.append("장안문 현판 글씨를 품에 품고 있건만, 걸어둘 성문 누각이 아직 없으니 애석하구나!")
			if n_wall == 0:
				advice_lines.append("성곽 없는 황량한 벌판에 무슨 글씨를 새기겠소? 도성의 골격부터 세워주시오.")
			if n_levee == 0:
				advice_lines.append("수원천 둑길이 삭막하여 물길의 풍류를 읊을 수가 없네. 단단한 석축이 먼저라오.")
			if n_road < 10:
				advice_lines.append("사방으로 통하는 길이 없으니 선비들의 발길도 끊기고 묵향도 흩어지는구려.")
			if n_resv == 0:
				advice_lines.append("만석서호(萬石西湖)의 풍광을 노래할 저수지가 아직 파이지 않았소.")

			if n_gate >= 1:
				compliment_lines.append("장안문(長安門) 세 글자, 백성의 만대 태평을 빌며 한 획 한 획 예서로 정성껏 새겼네!")
			if n_gate >= 3:
				compliment_lines.append("사대문의 현판이 모두 걸리니 성곽의 위의와 문기(文氣)가 온 누리에 빛나는구려!")
			if n_levee >= 3:
				compliment_lines.append("수원천 맑은 물결 위에 화홍문(華虹門) 편액을 거니 물보라와 글씨가 어우러져 절경이로다!")
			if n_wall >= 25:
				compliment_lines.append("성돌 하나하나에 깃든 장인의 혼이 마치 힘찬 해서(楷書) 한 획과도 같구려.")

			match current_season:
				"봄": season_lines.append("봄볕 아래 먹을 가니 먹향이 그윽하오. 새 봄을 맞아 행궁에 입춘대길(立春大吉)을 써 붙이세.")
				"여름": season_lines.append("장마철 습기에도 먹빛이 바래지 않도록, 최고급 아교로 정성껏 먹물을 배합하고 있네.")
				"가을": season_lines.append("청명한 가을 하늘 아래 방화수류정(訪花隨柳亭) 편액 글씨가 한층 더 운치 있게 돋보이는구려.")
				"겨울": season_lines.append("벼루의 먹물이 어는 추위 속에서도, 선비의 지조를 담아 굳은 필획을 내리긋고 있소.")

			persona_lines.append("예서(隷書)의 필획은 웅장하면서도 단정해야 화성의 기품과 진정으로 어울린다네.")
			persona_lines.append("화성의 아름다움은 돌과 나무의 견고함뿐 아니라 그 안에 깃든 문치(文治)의 뜻에 있다오.")
			persona_lines.append("방화수류정(꽃을 찾고 버들을 따라 노닌다) 현판은 자연과 정자가 하나 되는 경지를 담았네.")
			persona_lines.append("글씨는 곧 그 사람의 마음이요, 도성의 현판은 임금의 덕성을 만천하에 드러내는 거울이지.")

	if is_tiger and not urgent_tiger.is_empty() and randf() < 0.70:
		return urgent_tiger[randi() % urgent_tiger.size()]

	var weighted_pool: Array[String] = []

	for l: String in urgent_lines:
		weighted_pool.append(l)
		weighted_pool.append(l)
		weighted_pool.append(l)

	for l: String in advice_lines:
		weighted_pool.append(l)
		weighted_pool.append(l)
		weighted_pool.append(l)

	for l: String in compliment_lines:
		weighted_pool.append(l)
		weighted_pool.append(l)

	for l: String in season_lines:
		weighted_pool.append(l)
		weighted_pool.append(l)

	for l: String in persona_lines:
		weighted_pool.append(l)

	if not weighted_pool.is_empty():
		return weighted_pool[randi() % weighted_pool.size()]

	var ninfo: Dictionary = named_info(named_id)
	var fallback_lines: Array = ninfo.get("lines", [])
	if not fallback_lines.is_empty():
		return fallback_lines[randi() % fallback_lines.size()]

	return "백성과 더불어 화성 신시의 번영을 도모합시다."

func setup(g: GameGrid, c: CourtSystem = null, s: SimulationCore = null) -> void:
	grid = g
	court = c
	sim = s
	if grid:
		if not grid.grid_changed.is_connected(_mark_roads_dirty):
			grid.grid_changed.connect(_mark_roads_dirty)
		if not grid.grid_tiles_changed.is_connected(_on_grid_tiles_changed):
			grid.grid_tiles_changed.connect(_on_grid_tiles_changed)
	if court and not court.tiger_resolved_event.is_connected(_on_tiger_resolved):
		court.tiger_resolved_event.connect(_on_tiger_resolved)

	for nid_x: String in NamedNpcs.ids():
		if not named_cooldowns.has(nid_x):
			named_cooldowns[nid_x] = randf_range(4.0, 40.0) # 한꺼번에 나타나지 않게 흩어 놓는다
	agents.clear()
	_roads_dirty = true
	_refresh_caches()
	_apply_plaza_poi_weights()  # [저잣거리 공터 POI] 캐시 갱신 후 내비게이션 유인 가중치 적용
	# 초반에는 자연 산짐승들만 활동하고 인공 NPC는 조건 충족 시 등장한다.
	_sync_wildlife()
	# 순라청 치안 컨트롤러 초기화
	if sunla_manager == null:
		sunla_manager = SunlacheongManager.new()
		sunla_manager.name = "SunlacheongManager"
		add_child(sunla_manager)
	sunla_manager.setup(grid)
	# PORT-TRACE [포졸 길찾기]: 체포·압송 포졸이 건물을 뚫고 일직선으로 가던 것 — 백성과 같은 길 우선 길찾기를 쓴다
	PatrolOfficerNPC.path_provider = func(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		if grid == null or not grid.in_bounds(from.x, from.y) or not grid.in_bounds(to.x, to.y):
			return out
		var ent := _entry_for(to)
		for q in _find_path({"type": "official"}, from, ent):
			out.append(Vector2i(q))
		return out
	if court and not sunla_manager.security_alert.is_connected(_on_sunla_security_alert):
		sunla_manager.security_alert.connect(_on_sunla_security_alert)

	# 조선 후기 삼수병(포수 60%, 사수 15%, 살수 15%) 및 기포병(10%) 편제 스폰
	if military_mgr:
		military_mgr.spawn_regular_army(self, grid, sim)

func _on_sunla_security_alert(msg: String) -> void:
	if court != null:
		court.emit_signal("notice", msg)

func _on_grid_tiles_changed(tiles: Array) -> void:
	for p_raw in tiles:
		var p: Vector2i = p_raw as Vector2i if p_raw is Vector2i else Vector2i(p_raw)
		_dirty_nav_tiles[p] = true
		_entry_cache.erase(p)
		for d: Vector2i in DIRS4:
			_entry_cache.erase(p + d)

func _update_nav_tiles_local(tiles: Array) -> void:
	if _astar_road == null or _astar_free == null:
		_build_nav()
		return
	for p_raw in tiles:
		var p: Vector2i = p_raw as Vector2i
		if not grid.in_bounds(p.x, p.y):
			continue
		var t: Dictionary = grid.grid[p.y][p.x]
		var is_walkable: bool = _tile_walkable(t)
		_astar_road.set_point_solid(p, not is_walkable)
		_astar_free.set_point_solid(p, not is_walkable)
		if is_walkable:
			var b: String = t.get("building", "")
			var mountain: bool = t.get("terrain", "") == "mountain"
			if b in ["road", "stone_road", "gate"]:
				_astar_road.set_point_weight_scale(p, 1.0)
			elif (b == "haenggung" or b == "haenggung_site") and _is_haenggung_passable(t):
				var pos := Vector2i(int(t.get("x", 0)), int(t.get("y", 0)))
				var anchor: Vector2i = t.get("site_anchor", pos)
				var rel := pos - anchor
				if rel in [Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 0), Vector2i(0, 0)]:
					_astar_road.set_point_weight_scale(p, 1.0)
				else:
					_astar_road.set_point_weight_scale(p, 1.2)
			elif b in ["agr_1", "agr_2"] or t.get("zone", "") == "agr":
				_astar_road.set_point_weight_scale(p, 1.6) # 대유둔전 서행 이동 허용
			else:
				_astar_road.set_point_weight_scale(p, 8.0 if mountain else 4.0)
			if b in ["agr_1", "agr_2"] or t.get("zone", "") == "agr":
				_astar_free.set_point_weight_scale(p, 1.6)
			else:
				_astar_free.set_point_weight_scale(p, 1.6 if mountain else 1.0)

		# 도로 및 건물 캐시 국소 갱신 (심시티 2000급 Dirty Grid 패턴 완결)
		var b_str: String = t.get("building", "")
		if b_str in ["road", "stone_road"]:
			if not _roads_set.has(p):
				_roads_set[p] = true
				_roads_cache.append(p)
		else:
			if _roads_set.has(p):
				_roads_set.erase(p)
				_roads_cache.erase(p)

		if b_str == "gate":
			if not _gate_cache.has(p): _gate_cache.append(p)
			_open_gate = true
		else:
			_gate_cache.erase(p)

		if b_str == "wall":
			if not _wall_cache.has(p): _wall_cache.append(p)
		else:
			_wall_cache.erase(p)

		if b_str.begins_with("res"):
			if not _res_cache.has(p): _res_cache.append(p)
		else:
			_res_cache.erase(p)

		if b_str.begins_with("com"):
			if not _com_cache.has(p): _com_cache.append(p)
			if not _shop_cache.has(p): _shop_cache.append(p)
		else:
			_com_cache.erase(p)
			_shop_cache.erase(p)

		if b_str.begins_with("ind"):
			if not _workshop_cache.has(p): _workshop_cache.append(p)
		else:
			_workshop_cache.erase(p)

		if b_str in ["haenggung", "haenggung_site"]:
			if not _office_cache.has(p): _office_cache.append(p)
		else:
			_office_cache.erase(p)

		if grid.is_wall_building(t):
			if not _build_cache.has(p): _build_cache.append(p)
		else:
			_build_cache.erase(p)

	_nav_version += 1
	# 변경된 타일을 실제로 통과하는 경로를 가진 에이전트만 경로 재탐색
	for a: Dictionary in agents:
		var cur_path: Array = a.get("path", [])
		for p_mod in tiles:
			if cur_path.has(p_mod):
				a.erase("path")
				break

	_check_and_mark_village_threat_animals()

## PORT-TRACE [불러온 뒤 성문 목록 빔]: 세이브를 불러오면 지도가 통째로 바뀌는데, 그 순간 화재 등으로 "바뀐 칸 몇 개"가 쌓여 있으면
## 국소 갱신만 하고 전체 갱신(성문·가게·집 목록, 길찾기)을 건너뛰어 성문 목록이 비거나 예전 지도 것으로 남았다 → 길손이 성문을 못 씀
func force_full_refresh() -> void:
	_dirty_nav_tiles.clear()
	_entry_cache.clear()
	_roads_dirty = true

func _mark_roads_dirty() -> void:
	if _dirty_nav_tiles.is_empty():
		_roads_dirty = true

func _refresh_caches() -> void:
	if grid == null:
		return
	_roads_cache.clear()
	_roads_set.clear()
	_forest_cache.clear()
	_mountain_cache.clear()
	_mountain_forest_cache.clear()
	_mountain_rocky_cache.clear()
	_water_banks_cache.clear()
	_seokjeon_pairs_cache.clear()
	_agr_cache.clear()
	_rocky_cache.clear()
	_grass_cache.clear()
	_wall_cache.clear()
	_office_cache.clear()
	_com_cache.clear()
	_res_cache.clear()
	_gate_cache.clear()
	_military_cache.clear()
	_build_cache.clear()
	_levee_cache.clear()
	_reservoir_cache.clear()
	_floodgate_cache.clear()
	_patrol_cache.clear()
	_firefighter_cache.clear()
	_patrol_roads_cache.clear()
	_patrol_roads_set.clear()
	_shop_cache.clear()
	_workshop_cache.clear()
	_house_cache.clear()
	_rich_house_cache.clear()
	_haenggung_gate = Vector2i(-1, -1)
	_gwana_cache.clear()
	_seodang_cache.clear()
	_cattle_yard = Vector2i(-1, -1)
	_salt_store = Vector2i(-1, -1)
	_jongnu = Vector2i(-1, -1)
	maehyang_open = false
	_open_gate = false
	_market_plaza_cache.clear() # [저잣거리 공터] 장마당 캐시 초기화
	_named_place_cache.clear()

	var sz: int = grid.size
	for y: int in range(sz):
		for x: int in range(sz):
			var t: Dictionary = grid.grid[y][x]
			var b: String = t.get("building", "")
			var surf: String = t.get("surface", "grass")
			var zone: String = t.get("zone", "")
			var terr: String = t.get("terrain", "plain")

			var pos := Vector2i(x, y)
			# 성곽 안쪽 순찰로(길) 타일 캐싱
			if grid.is_patrol_road(x, y):
				_patrol_roads_cache.append(pos)
				_patrol_roads_set[pos] = true

			# PORT-TRACE [건설 기간]: 지금 공사 중인 칸(성곽·성문·서장대·봉돈 등) — 공사 인부 배치용
			if grid.is_wall_building(t):
				_build_cache.append(pos)
			elif b == "gate":
				_open_gate = true # 다 지은 성문이 하나라도 있으면 사람 왕래가 시작될 수 있다
			if b in ["road", "stone_road", "levee"]:
				_roads_cache.append(pos)
				_roads_set[pos] = true
			elif b == "wall":
				_wall_cache.append(pos)
			elif b == "gate":
				_gate_cache.append(pos)
			elif b == "haenggung" or b == "haenggung_site": # PORT-TRACE [행궁=동헌]: 행궁이 관아를 겸함
				_office_cache.append(pos)
				# 완공된 행궁의 신풍루 정문 입구 타일은 보행 통행망에 연동
				if not t.get("under_construction", false):
					var h_anc: Vector2i = t.get("site_anchor", pos)
					if pos == h_anc + Vector2i(3, 0):
						_roads_cache.append(pos)
						_roads_set[pos] = true
			elif b in ["seojangdae", "bongdon", "gongsimdon", "poru", "yeonmudae"]:
				_military_cache.append(pos)
			elif b == "levee":
				_levee_cache.append(pos)
			elif b == "reservoir":
				_reservoir_cache.append(pos)
			elif b == "floodgate":
				_floodgate_cache.append(pos)
			elif b == "patrol":
				_patrol_cache.append(pos)
			elif b == "firefighter":
				_firefighter_cache.append(pos)
			elif (b == "com_1" or b == "com_2") and not t.has("zone_build"):
				_shop_cache.append(pos)
			elif b.begins_with("res_") and not t.has("zone_build"):
				_house_cache.append(pos)
				if b != "res_1":
					_rich_house_cache.append(pos)
			if b == "gwana":
				_gwana_cache.append(pos)
			elif b == "jongnu":
				_jongnu = pos
			if t.get("is_maehyang", false) and b == "road":
				maehyang_open = true
			if t.has("plaza") and String(t["plaza"].get("kind", "")) == "cattle" and int(t["plaza"]["x0"]) == x and int(t["plaza"]["y0"]) == y:
				_cattle_yard = pos
			if t.has("plaza") and String(t["plaza"].get("kind", "")) == "salt" and int(t["plaza"]["x0"]) == x and int(t["plaza"]["y0"]) == y:
				_salt_store = pos
			# [저잣거리 공터 POI] 장마당(market) 앵커 캐시 갱신
			if t.has("plaza") and String(t["plaza"].get("kind", "")) == "market" and int(t["plaza"]["x0"]) == x and int(t["plaza"]["y0"]) == y:
				_market_plaza_cache.append(pos)
			# [서당 학동 연출] 서당 앵커 캐시 및 학동 배치
			if t.has("plaza") and String(t["plaza"].get("kind", "")) == "seodang" and int(t["plaza"]["x0"]) == x and int(t["plaza"]["y0"]) == y:
				_seodang_cache.append(pos)
				if not _seodang_students.has(pos):
					spawn_seodang_students(pos)
			if b == "haenggung":
				_haenggung_gate = pos + Vector2i(3, 0) # 동향(東向) 정문 신풍루
			elif (b == "ind_1" or b == "ind_2") and not t.has("zone_build"):
				_workshop_cache.append(pos)

			# 실제 구역이 지정되거나 둔전 건물인 경우 등록
			if zone == "agr" or b == "agr_1" or b == "agr_2":
				_agr_cache.append(pos)
			elif zone == "com":
				_com_cache.append(pos)
			elif zone == "res":
				_res_cache.append(pos)

			if surf == "forest":
				_forest_cache.append(pos)
			elif surf == "rocky":
				_rocky_cache.append(pos)
			elif surf == "grass" and b == "" and zone == "":
				_grass_cache.append(pos)

			# 산악 지형 및 깊은 숲/암석 캐싱 (자연 상태의 산지 및 외곽 수종)
			if terr == "mountain" and b == "" and zone == "":
				_mountain_cache.append(pos)
				if surf == "forest":
					_mountain_forest_cache.append(pos)
				elif surf == "rocky":
					_mountain_rocky_cache.append(pos)
			elif terr != "plain" and terr != "water" and b == "" and zone == "":
				if surf == "forest":
					_mountain_forest_cache.append(pos)
				elif surf == "rocky":
					_mountain_rocky_cache.append(pos)

			# 수변 둔치 판정 (육지이면서 인접 타일에 물이 있는 타일)
			# PORT-TRACE [제방 빨래터·낚시터]: 제방 칸도 물가로 친다 — 낚시꾼은 둑 위에, 빨래 아낙은 둑 너머 물가에
			if terr != "water" and (b == "" or b == "levee"):
				var water_vec := Vector2.ZERO
				var has_water := false
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if grid.in_bounds(nx, ny) and grid.grid[ny][nx].get("terrain", "") == "water":
						water_vec += Vector2(d.x, d.y)
						has_water = true
				if has_water:
					_water_banks_cache.append({
						"pos": pos,
						"water_dir": water_vec.normalized(),
						"levee": b == "levee",
						"laundry": grid.is_laundry_spot(x, y),
					})

	# 수원천 석축 및 양안 제방 쌍 캐싱 (석전 이벤트용 사전 포인트 풀 O(1) 인출)
	for b_info: Dictionary in _water_banks_cache:
		var pa: Vector2i = b_info["pos"]
		var wdir: Vector2 = b_info["water_dir"]
		var step := Vector2i.ZERO
		if absf(wdir.x) >= absf(wdir.y):
			step = Vector2i(1 if wdir.x > 0.0 else -1, 0)
		else:
			step = Vector2i(0, 1 if wdir.y > 0.0 else -1)
		if step == Vector2i.ZERO:
			continue
		var water_found := false
		var opposite_bank := Vector2i(-1, -1)
		for probe_dist: int in range(1, 10):
			var probe := pa + step * probe_dist
			if not grid.in_bounds(probe.x, probe.y):
				break
			var probe_terr: String = grid.grid[probe.y][probe.x].get("terrain", "")
			if probe_terr == "water":
				water_found = true
			else:
				if water_found:
					opposite_bank = probe
				break
		if opposite_bank.x >= 0 and grid.grid[opposite_bank.y][opposite_bank.x].get("terrain", "") != "water":
			_seokjeon_pairs_cache.append({
				"bank_a": pa,
				"bank_b": opposite_bank,
				"dir": Vector2(step)
			})

	_roads_dirty = false
	_build_nav()
	_apply_plaza_poi_weights() # [저잣거리 공터 POI] 네비게이션 가중치 반영
	_check_and_mark_village_threat_animals()
	if sunla_manager != null:
		sunla_manager.sync_stations_from_grid(grid)

## 건물·성벽·물(다리 제외)·공사 중인 터는 막힌 칸. 길·성문·수로·제방·논밭·빈 땅은 지나갈 수 있다.
## 화성행궁 완공 시 신풍루(정문 입구) 및 삼도/중정 통행로를 통해 NPC가 궁궐 안팎을 자연스럽게 통행한다.
## 석축제방(levee)은 물 위에 축조되어도 보행 속성(Walkable)을 도로와 100% 동일하게 보장하여 갇힘을 방지한다.
func _tile_walkable(t: Dictionary) -> bool:
	var b: String = t.get("building", "")
	if b == "levee":
		return true
	if t.get("is_bridge", false):
		return true
	if t.get("terrain", "") == "water":
		return false
	if t.get("under_construction", false):
		return false
	if t.get("is_namsu", false):
		return not t.has("wall_build") # PORT-TRACE [남수문]: 완공되면 순라군·백성이 수문 위를 건너다닌다
	if b in PASSABLE_BUILDINGS:
		return true
	if t.get("zone", "") == "agr":
		return true
	if b == "haenggung" or b == "haenggung_site":
		return _is_haenggung_passable(t)
	return false

## 화성행궁 내부 통행로 판정: 신풍루 정문 입구 및 중심 삼도, 좌익문, 봉수당 앞마당
func _is_haenggung_passable(t: Dictionary) -> bool:
	var b: String = t.get("building", "")
	if b != "haenggung" and b != "haenggung_site":
		return false
	if t.get("under_construction", false):
		return false
	var pos := Vector2i(int(t.get("x", 0)), int(t.get("y", 0)))
	var anchor: Vector2i = t.get("site_anchor", pos)
	var rel := pos - anchor
	# 신풍루 정문 입구(+3, 0), 삼도(+2, 0), 좌익문(+1, 0), 중정 마당(0, 0), 월대 앞마당(-1, 0)
	# 및 좌우 회랑 안마당 (+1, 1), (+1, -1), (0, 1), (0, -1)
	return rel in [
		Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 0),
		Vector2i(0, 0), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(0, 1), Vector2i(0, -1)
	]

func _build_nav() -> void:
	var sz: int = grid.size
	_astar_road = AStarGrid2D.new()
	_astar_free = AStarGrid2D.new()
	for asg: AStarGrid2D in [_astar_road, _astar_free]:
		asg.region = Rect2i(0, 0, sz, sz)
		asg.cell_size = Vector2.ONE
		asg.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		asg.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar_road.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar_free.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar_road.update()
	_astar_free.update()
	for y in range(sz):
		for x in range(sz):
			var t: Dictionary = grid.grid[y][x]
			var p := Vector2i(x, y)
			if not _tile_walkable(t):
				_astar_road.set_point_solid(p, true)
				_astar_free.set_point_solid(p, true)
				continue
			var b: String = t.get("building", "")
			var mountain: bool = t.get("terrain", "") == "mountain"
			if b in ["road", "stone_road", "gate", "levee"] or _patrol_roads_set.has(p):
				_astar_road.set_point_weight_scale(p, 1.0)
			elif b in MILITARY_STRUCTURES:
				_astar_road.set_point_weight_scale(p, 1.8) # 진입 계단을 통해 접근 허용
			elif (b == "haenggung" or b == "haenggung_site") and _is_haenggung_passable(t):
				var pos := Vector2i(int(t.get("x", 0)), int(t.get("y", 0)))
				var anchor: Vector2i = t.get("site_anchor", pos)
				var rel := pos - anchor
				if rel in [Vector2i(3, 0), Vector2i(2, 0), Vector2i(1, 0), Vector2i(0, 0)]:
					_astar_road.set_point_weight_scale(p, 1.0)
				else:
					_astar_road.set_point_weight_scale(p, 1.2)
			elif b in ["agr_1", "agr_2"] or t.get("zone", "") == "agr":
				_astar_road.set_point_weight_scale(p, 1.6) # 대유둔전 서행 이동 허용
			else:
				_astar_road.set_point_weight_scale(p, 8.0 if mountain else 4.0)
			if b in ["agr_1", "agr_2"] or t.get("zone", "") == "agr":
				_astar_free.set_point_weight_scale(p, 1.6)
			else:
				_astar_free.set_point_weight_scale(p, 1.6 if mountain else 1.0)
	_entry_cache.clear()
	_nav_version += 1
	# 지도가 바뀌어 막힌 칸에 서 있게 된 사람은 경로를 새로 찾게 한다
	for a: Dictionary in agents:
		a.erase("path")

func _is_free_roamer(a: Dictionary) -> bool:
	return a.get("is_wild", false) or String(a.get("type", "")) in FREE_ROAMERS

## 고립 방지(Anti-Stuck): 특정 위치에서 가장 가까운 도로 타일 탐색
func _find_nearest_road(pos: Vector2i) -> Vector2i:
	if _roads_cache.is_empty():
		return Vector2i(-1, -1)
	var best_dist := 999999
	var best_p := Vector2i(-1, -1)
	for rp: Vector2i in _roads_cache:
		var d: int = absi(rp.x - pos.x) + absi(rp.y - pos.y)
		if d < best_dist:
			best_dist = d
			best_p = rp
			if d <= 1:
				break
	return best_p

## 익수자 구조용: 특정 위치에서 가장 가까운 수원천 물가 육지 타일 탐색
## 둑에 맞닿은 열린 물 칸(다리·남수문·건물 없는 수원천 물) — 물놀이·얼음놀이 자리
func _open_water_spots() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for b_entry: Dictionary in _water_banks_cache:
		var bp_pos: Vector2i = b_entry["pos"]
		var wdir_v: Vector2 = b_entry["water_dir"]
		var stp := Vector2i(roundi(wdir_v.x), roundi(wdir_v.y))
		if stp == Vector2i.ZERO:
			stp = Vector2i(1, 0)
		var wp_pos: Vector2i = bp_pos + stp
		if _is_open_water(wp_pos) and not out.has(wp_pos):
			out.append(wp_pos)
	return out

func _is_open_water(p: Vector2i) -> bool:
	if grid == null or not grid.in_bounds(p.x, p.y):
		return false
	var wt: Dictionary = grid.grid[p.y][p.x]
	return wt.get("terrain", "") == "water" and not wt.get("is_bridge", false) and not wt.get("is_namsu", false) and wt.get("building", "") == ""

## 썰매가 미끄러질 반대쪽 끝: 한 방향으로 3~2칸 내내 열린 물이면 그 끝 칸
func _ice_slide_end(p: Vector2i) -> Vector2i:
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	dirs.shuffle()
	for n in [3, 2]:
		for d: Vector2i in dirs:
			var ok := true
			for k in range(1, n + 1):
				if not _is_open_water(p + d * k):
					ok = false
					break
			if ok:
				return p + d * n
	return Vector2i(-1, -1)

## 얼음이 갈라질지(빠진 사람이 이미 있으면 안 깨짐, 한 사람당 평균 4분에 한 번꼴) → 1.5초 "쩍쩍" 뒤 _ice_break
func _ice_maybe_crack(a: Dictionary, delta: float) -> void:
	if randf() >= delta / 240.0:
		return
	for o: Dictionary in agents:
		if o.get("type", "") == "drowning" and not o.get("is_dead", false):
			return
	a["state"] = "crack"
	a["state_timer"] = 1.5
	a["bubble_text"] = "어, 어? 얼음이 쩍쩍 갈라진다!"
	a["bubble_timer"] = 1.6

func _ice_break(a: Dictionary) -> void:
	var cur := Vector2i(int(floor(float(a["x"]))), int(floor(float(a["y"]))))
	var dr := _add_spot_agent("drowning", cur, {"anim_seed": randf() * 4.0, "initial_state": "drowning", "state": "drowning", "rescued": false, "rescuer_id": -1, "ice": true})
	dr["x"] = a["x"]
	dr["y"] = a["y"]
	dr["ice"] = true
	dr["is_child"] = a.get("type", "") == "ice_sled"
	dr["bubble_text"] = "으악! 차가워! 사람 살려!"
	dr["bubble_timer"] = 2.5
	a["is_dead"] = true

func _find_nearest_water_bank(pos: Vector2i) -> Vector2i:
	if not _water_banks_cache.is_empty():
		var best_dist: int = 999999
		var best_bank := Vector2i(-1, -1)
		for b_entry: Dictionary in _water_banks_cache:
			var bp: Vector2i = b_entry["pos"]
			var d: int = absi(bp.x - pos.x) + absi(bp.y - pos.y)
			if d < best_dist:
				best_dist = d
				best_bank = bp
				if d <= 1:
					break
		if best_bank.x >= 0:
			return best_bank
	if grid != null:
		for d: Vector2i in DIRS4:
			var np: Vector2i = pos + d
			if grid.in_bounds(np.x, np.y) and grid.grid[np.y][np.x].get("terrain", "") != "water":
				return np
	return pos

## 호환 대피용: 특정 위치에서 가장 가까운 민가(res_*/house) 타일 탐색
func _find_nearest_shelter_house(pos: Vector2i) -> Vector2i:
	var pool: Array[Vector2i] = _house_cache if not _house_cache.is_empty() else _res_cache
	if pool.is_empty():
		return _find_nearest_road(pos)
	var best_dist := 999999
	var best_p := Vector2i(-1, -1)
	for hp: Vector2i in pool:
		var d: int = absi(hp.x - pos.x) + absi(hp.y - pos.y)
		if d < best_dist:
			best_dist = d
			best_p = hp
			if d <= 1:
				break
	return best_p

## 건물(막힌 칸)의 입구: 그 건물과 맞닿은 지나갈 수 있는 칸 중 길/성문을 우선. 다칸 건물은 부지를
## 가로질러 가장 가까운 바깥 칸을 찾는다. 막히지 않은 칸이면 그대로 돌려준다.
## 화성행궁은 담장을 가로지르지 않고 항상 신풍루(정문 입구)를 통해 출입한다.
func _entry_for(target: Vector2i) -> Vector2i:
	if _astar_free == null or not grid.in_bounds(target.x, target.y):
		return target
	var tt: Dictionary = grid.grid[target.y][target.x]
	var tb: String = tt.get("building", "")
	# 화성행궁 진입 시: 건물 담장을 뚫지 않고 반드시 신풍루(정문) 입구를 통해 통행
	if tb == "haenggung" or tb == "haenggung_site":
		var h_anchor: Vector2i = tt.get("site_anchor", target)
		var sinpungru := h_anchor + Vector2i(3, 0)
		var front_road := h_anchor + Vector2i(4, 0)
		if grid.in_bounds(front_road.x, front_road.y) and not _astar_free.is_point_solid(front_road):
			return front_road
		if grid.in_bounds(sinpungru.x, sinpungru.y) and not _astar_free.is_point_solid(sinpungru):
			return sinpungru
	if not _astar_free.is_point_solid(target):
		return target
	if _entry_cache.has(target):
		return _entry_cache[target]
	var seen := {target: true}
	var frontier: Array[Vector2i] = [target]
	var result := target
	for _ring in range(10):
		var next: Array[Vector2i] = []
		var found: Array[Vector2i] = []
		for p: Vector2i in frontier:
			for d: Vector2i in DIRS4:
				var n: Vector2i = p + d
				if not grid.in_bounds(n.x, n.y) or seen.has(n):
					continue
				seen[n] = true
				if _astar_free.is_point_solid(n):
					next.append(n)
				else:
					found.append(n)
		if not found.is_empty():
			result = found[0]
			for f: Vector2i in found:
				if _roads_set.has(f) or grid.grid[f.y][f.x].get("building", "") == "gate":
					result = f
					break
			break
		if next.is_empty():
			break
		frontier = next
	_entry_cache[target] = result
	return result

const FOUR_GATES: Array[Vector2i] = [
	Vector2i(26, 6),   # 장안문 (북)
	Vector2i(48, 29),  # 창룡문 (동)
	Vector2i(16, 54),  # 팔달문 (남)
	Vector2i(6, 13)    # 화서문 (서)
]

func _is_tile_outside(pos: Vector2i) -> bool:
	if grid == null or not grid.in_bounds(pos.x, pos.y):
		return true
	return grid.grid[pos.y][pos.x].get("terrain", "") == "outside"

func _get_raw_id_path(asg: AStarGrid2D, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if asg == null or asg.is_point_solid(to):
		return []
	var was_solid: bool = asg.is_point_solid(from)
	if was_solid:
		asg.set_point_solid(from, false)
	var ids: Array[Vector2i] = asg.get_id_path(from, to)
	if was_solid:
		asg.set_point_solid(from, true)
	return ids

func _find_path(a: Dictionary, from: Vector2i, to: Vector2i) -> Array:
	var asg: AStarGrid2D = _astar_free if _is_free_roamer(a) else _astar_road
	if asg == null or asg.is_point_solid(to):
		return []

	# 성 안 ↔ 성 밖 왕래 시 가장 가까운 사대문(장안/팔달/창룡/화서)을 1차 경유지(Waypoint)로 강제 지정 (HPA* 2단계 경로 결합)
	var crossing_boundary: bool = _is_tile_outside(from) != _is_tile_outside(to)
	if crossing_boundary:
		var best_gate := Vector2i(-1, -1)
		var best_cost := 99999
		for g: Vector2i in FOUR_GATES:
			if grid != null and grid.in_bounds(g.x, g.y):
				var t: Dictionary = grid.grid[g.y][g.x]
				var is_gate_ready: bool = t.get("building", "") == "gate" and not t.has("wall_build")
				var bonus: int = -20 if is_gate_ready else 0
				var cost: int = (abs(from.x - g.x) + abs(from.y - g.y)) + (abs(to.x - g.x) + abs(to.y - g.y)) + bonus
				if cost < best_cost:
					best_cost = cost
					best_gate = g
		if best_gate.x >= 0 and from != best_gate and to != best_gate:
			var path_to_gate: Array[Vector2i] = _get_raw_id_path(asg, from, best_gate)
			var path_from_gate: Array[Vector2i] = _get_raw_id_path(asg, best_gate, to)
			if not path_to_gate.is_empty() and not path_from_gate.is_empty():
				var combined: Array = []
				for i: int in range(1, path_to_gate.size()):
					combined.append(path_to_gate[i])
				for j: int in range(1, path_from_gate.size()):
					combined.append(path_from_gate[j])
				return combined

	var ids: Array[Vector2i] = _get_raw_id_path(asg, from, to)
	var out: Array = []
	for i: int in range(1, ids.size()):
		out.append(ids[i])
	return out

func _add_road_agent(type: String, start_pos: Vector2i) -> Dictionary:
	_next_agent_id += 1
	var spd: float = 1.0
	match type:
		"horse_messenger": spd = 2.4
		"cart", "grain_cart", "wood_cart", "gov_cart": spd = 0.75
		"ox_driver": spd = 0.7
		"official_rider": spd = 1.3
		"palanquin": spd = 0.85
		"scholar": spd = 0.8
		"guard": spd = 0.95
		_: spd = randf_range(0.9, 1.25)

	var prof := get_random_citizen_profile()
	var ag_type := type
	if type in ["shopper", "citizen"]:
		ag_type = String(prof["type"])

	var ag := {
		"id": _next_agent_id,
		"type": ag_type,
		"original_type": type,
		"social_class": String(prof["social_class"]),
		"gender": String(prof["gender"]),
		"modulate": prof["modulate"],
		"job_action": String(JOB_ACTION_MAP.get(type, "NONE")),
		"x": float(start_pos.x) + 0.5,
		"y": float(start_pos.y) + 0.5,
		"from_tile": start_pos,
		"to_tile": start_pos,
		"progress": 1.0,
		"dir": Vector2.RIGHT,
		"speed": spd,
		"anim": randf() * 4.0,
		"state": "walk",
		"state_timer": 0.0,
		"is_spot": false,
		"is_named": false,
		"is_wild": false,
		"bubble_text": "",
		"bubble_timer": 0.0,
		"extra": {}
	}
	agents.append(ag)
	return ag

# ============================================================ 화재 발생 및 멸화군(소방) 방화 시스템

func get_active_fires() -> Array[Dictionary]:
	return _active_fires

func _manage_fires(delta: float) -> void:
	if sim == null or grid == null:
		return

	# 초반 2년(turn <= 8, year < 1778) 재난 억제
	if sim.current_year < 1778 or sim.turn <= 8:
		return

	# 1. 화재 진행 및 셀룰러 오토마타(Cellular Automata) 10x10 확산/진화/전소 처리
	if not _active_fires.is_empty():
		# 고정 주기(1.6초) 셀룰러 오토마타 확산 연산 틱
		_fire_spread_tick_timer -= delta
		if _fire_spread_tick_timer <= 0.0:
			_fire_spread_tick_timer = 1.6
			_cellular_automata_fire_step()

		var fires_to_remove: Array[int] = []
		for idx: int in range(_active_fires.size()):
			var f: Dictionary = _active_fires[idx]
			var fpos: Vector2i = f["pos"]
			f["duration"] = float(f.get("duration", 0.0)) + delta

			# 멸화군 및 자원 진화 백성 현장 집계
			var ff_count := 0
			var vol_count := 0
			var ff_coming := 0
			for a: Dictionary in agents:
				if a.get("target_fire_pos", Vector2i(-1, -1)) == fpos and not a.get("is_dead", false):
					var at: String = a.get("type", "")
					var ast: String = a.get("state", "")
					if at == "firefighter_soldier" and ast == "extinguish":
						ff_count += 1
					elif at == "firefighter_soldier" and ast == "rush_to_fire":
						ff_coming += 1
					elif at == "bucket_volunteer" and ast == "pour_water":
						vol_count += 1

			var progress: float = float(f.get("fire_progress", 0.1))

			if ff_count > 0 or vol_count > 0:
				# 현장 진화 인력이 불길을 잡는 중 (진행도 감축)
				var quench_power: float = float(ff_count) * 0.25 + float(vol_count) * 0.15
				progress = maxf(0.0, progress - quench_power * delta)
				f["fire_progress"] = progress

				# 진화 성공 판정 (진행도 0 이하 도달 및 최소 3초 진압 지속)
				if progress <= 0.0 or f.get("extinguished", false):
					f["extinguished"] = true
					if grid.in_bounds(fpos.x, fpos.y):
						grid.grid[fpos.y][fpos.x].erase("on_fire")
						grid.grid[fpos.y][fpos.x].erase("fire_progress")
					fires_to_remove.append(idx)
					if court != null:
						court.emit_signal("notice", "멸화군과 백성들이 힘을 합쳐 화마를 완전히 진압하였습니다! (+민심 2%)")
					sim.loyalty = mini(100, sim.loyalty + 2)
					if sim.has_signal("fire_extinguished"):
						sim.fire_extinguished.emit(fpos)
					# 출동한 멸화군 및 자원 진화대 귀환
					for a: Dictionary in agents:
						if a.get("target_fire_pos", Vector2i(-1, -1)) == fpos:
							a["state"] = "go_home"
							a["bubble_text"] = "진화 완료! 불길이 잡혔다!"
							a["bubble_timer"] = 3.0
					continue
			else:
				# 진화 인력이 없거나 부족할 때: 화재 진행도 점진적 상승 (약 18초 후 전소)
				# 멸화군 수성소가 많을수록 빨리 달려와 18초 안에 끈다(설계 의도: 늦으면 전소)
				progress = minf(1.0, progress + (delta / 18.0))
				f["fire_progress"] = progress
				if grid.in_bounds(fpos.x, fpos.y):
					grid.grid[fpos.y][fpos.x]["fire_progress"] = progress

			# 멸화군 청사가 있는데 이 불에 아직 출동하지 않았다면 출동(불마다 한 조)
			if not _firefighter_cache.is_empty() and ff_count == 0 and ff_coming == 0 and not bool(f.get("ff_sent", false)) 					and agents.filter(func(q: Dictionary) -> bool: return q.get("type", "") == "firefighter_soldier" and not q.get("is_dead", false)).size() < 8:
				f["ff_sent"] = true
				_dispatch_firefighter_squad(fpos)

			# 전소 (진행도 1.0 도달 또는 18초 초과 시 전소되어 황무지로 변환)
			if progress >= 1.0 or float(f["duration"]) >= (30.0 if ff_count > 0 else 18.0): # 물 뿌리는 중엔 마저 끌 시간
				f["extinguished"] = true
				fires_to_remove.append(idx)
				_burn_tile_to_wasteland(fpos)

		# 제거할 화재 목록 정리
		if not fires_to_remove.is_empty():
			fires_to_remove.sort()
			fires_to_remove.reverse()
			for r_idx: int in fires_to_remove:
				_active_fires.remove_at(r_idx)

		if _active_fires.is_empty():
			_fire_origin = Vector2i(-1, -1)
			sim.fire_active = false
		else:
			sim.fire_active = true
		return

	sim.fire_active = false
	_fire_origin = Vector2i(-1, -1)
	# 2. 화재 발생 주기 타이머
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = randf_range(65.0, 110.0)
		_trigger_random_fire()

## 셀룰러 오토마타(Cellular Automata) 기반 화재 10x10 확산 스텝
func _cellular_automata_fire_step() -> void:
	if _active_fires.is_empty() or grid == null:
		return
	if _active_fires.size() >= 100: # 최대 10x10 면적(100타일) 상한 보호
		return

	var current_fires: Array[Dictionary] = _active_fires.duplicate()
	for f: Dictionary in current_fires:
		if f.get("extinguished", false):
			continue
		var fpos: Vector2i = f["pos"]
		if _fire_origin.x < 0:
			_fire_origin = fpos

		# 8방향 이웃 검사
		var neighbors: Array[Vector2i] = [
			fpos + Vector2i(1, 0), fpos + Vector2i(-1, 0),
			fpos + Vector2i(0, 1), fpos + Vector2i(0, -1),
			fpos + Vector2i(1, 1), fpos + Vector2i(-1, -1),
			fpos + Vector2i(1, -1), fpos + Vector2i(-1, 1)
		]

		for np: Vector2i in neighbors:
			if not grid.in_bounds(np.x, np.y):
				continue
			# 10x10 면적 엄격 제한 (최초 발화점 기준 반경 5타일 사각형 이내)
			if absi(np.x - _fire_origin.x) > 5 or absi(np.y - _fire_origin.y) > 5:
				continue
			if _active_fires.size() >= 100:
				break

			var nt: Dictionary = grid.grid[np.y][np.x]
			if nt.get("on_fire", false):
				continue
			var nb: String = nt.get("building", "")
			if nb in ["burned_wasteland", "ruin", "wall", "gate", "canal", "levee"]:
				continue # 불연성 지형 및 이미 탄 곳은 확산 불가

			# 가연성 건물 판정 (초가, 기와집, 상점, 공방, 둔전 등)
			var is_combustible: bool = (
				nb.begins_with("res") or nb.begins_with("com") or
				nb.begins_with("ind") or nb.begins_with("agr") or
				nb in ["guesthouse", "factory"]
			)
			if not is_combustible:
				continue

			# 확산 확률 계산 (방재 인프라 및 효심 정책에 따른 감쇄율 적용)
			var is_diag: bool = (np.x != fpos.x and np.y != fpos.y)
			var spread_prob: float = 0.20 if is_diag else 0.32

			# 멸화군 진화 중이면 80% 확산 억제
			var ff_near := agents.any(func(a: Dictionary) -> bool:
				return a.get("type", "") == "firefighter_soldier" and a.get("target_fire_pos", Vector2i(-1, -1)) == fpos
			)
			if ff_near:
				spread_prob *= 0.20

			# 백성 자원 진화대 참여 시 40% 확산 억제
			var vol_near := agents.any(func(a: Dictionary) -> bool:
				return a.get("type", "") == "bucket_volunteer" and a.get("target_fire_pos", Vector2i(-1, -1)) == fpos
			)
			if vol_near:
				spread_prob *= 0.60

			# 우물, 저수지, 만석거, 수로 인근(용수 확보) 60% 확산 억제
			if grid.has_water_supply(np.x, np.y):
				spread_prob *= 0.40

			# 융건릉 참배/진찬례 효심 정책 축복 활성화 시 50% 억제
			if court != null and court.hyoryungwon.get("blessing", false):
				spread_prob *= 0.50

			if randf() < spread_prob:
				_start_fire_at(np)

## 전소 타일의 황무지화 및 피해 규모 산출
func _burn_tile_to_wasteland(pos: Vector2i) -> void:
	if not grid.in_bounds(pos.x, pos.y):
		return
	var ft: Dictionary = grid.grid[pos.y][pos.x]
	var b_prev: String = String(ft.get("building", ""))

	# 타일 속성 영구 변환 (황무지화: 잔해 철거 및 신규 구획 재설정 필수)
	ft["building"] = "burned_wasteland"
	ft["is_burned_wasteland"] = true
	ft["zone"] = ""
	ft.erase("on_fire")
	ft.erase("fire_progress")

	# 피해 규모 산출 (인명, 국고, 군량, 민심)
	var loss_msg := ""
	if b_prev.begins_with("res"):
		sim.population = maxi(10, sim.population - 4)
		sim.loyalty = maxi(0, sim.loyalty - 4)
		loss_msg = "민가가 전소되어 인명 피해(-4명)와 민심(-4)이 하락했습니다."
		spawn_patient(pos, "화재")
	elif b_prev.begins_with("com"):
		sim.gold = maxi(0, sim.gold - 50)
		sim.loyalty = maxi(0, sim.loyalty - 3)
		loss_msg = "저잣거리 상가가 전소되어 국고(-50냥)와 상권이 큰 타격을 입었습니다."
	elif b_prev.begins_with("ind"):
		sim.gold = maxi(0, sim.gold - 70)
		sim.loyalty = maxi(0, sim.loyalty - 2)
		loss_msg = "공방 작업장이 전소되어 생산 시설(-70냥)이 소실되었습니다."
	elif b_prev.begins_with("agr"):
		sim.rice = maxi(0, sim.rice - 60)
		loss_msg = "둔전이 전소되어 군량미(-60석)가 잿더미가 되었습니다."
	else:
		sim.loyalty = maxi(0, sim.loyalty - 2)
		sim.gold = maxi(0, sim.gold - 30)
		loss_msg = "건물이 전소되어 황무지로 변했습니다."

	if court != null:
		court.academic_hit(2, "화재")
		court.emit_signal("notice", "안타깝도다! %s (철거 도구로 잔해를 치우고 재구획하십시오)" % loss_msg)

	# 참조 무결성 유지: 전소된 건물을 향하던 NPC들의 목적지 안전 해제 (Null-check & Crash 예방)
	for a: Dictionary in agents:
		if a.get("target_fire_pos", Vector2i(-1, -1)) == pos:
			a["state"] = "go_home"
			a["bubble_text"] = "안타깝도다... 이미 다 타버렸구나..."
			a["bubble_timer"] = 3.0
		elif a.get("goal", Vector2i(-1, -1)) == pos or a.get("to_tile", Vector2i(-1, -1)) == pos:
			a.erase("path")
			a["state"] = "go_home"
			a["bubble_text"] = "건물이 타버려 갈 곳을 잃었구나..."
			a["bubble_timer"] = 2.5

	var changed_tiles: Array[Vector2i] = [pos]
	grid.emit_signal("grid_tiles_changed", changed_tiles)
	grid.emit_signal("grid_changed")

func _trigger_random_fire() -> void:
	var candidates: Array[Vector2i] = []
	# 공방(ind) 우선, 그 다음 저잣거리(com), 민가(res)
	if not _workshop_cache.is_empty():
		candidates.append_array(_workshop_cache)
	if candidates.is_empty() and not _com_cache.is_empty():
		candidates.append_array(_com_cache)
	if candidates.is_empty() and not _res_cache.is_empty():
		candidates.append_array(_res_cache)

	if candidates.is_empty():
		return

	# 우물이나 저수지 인근 타일은 화재 위험 감소 (3타일 내 우물/하천 있으면 50% 확률 스킵)
	var pick: Vector2i = candidates[randi() % candidates.size()]
	if grid.has_water_supply(pick.x, pick.y) and randf() < 0.5:
		return

	_start_fire_at(pick)

func _start_fire_at(pos: Vector2i) -> void:
	if not grid.in_bounds(pos.x, pos.y):
		return
	var t: Dictionary = grid.grid[pos.y][pos.x]
	if t.get("on_fire", false):
		return

	if _fire_origin.x < 0:
		_fire_origin = pos # 최초 발화점 앵커링 (최대 10x10 범위의 기준점)

	t["on_fire"] = true
	t["fire_progress"] = 0.1
	_active_fires.append({
		"pos": pos,
		"duration": 0.0,
		"max_duration": 18.0,
		"fire_progress": 0.1,
		"extinguished": false,
		"spread": false
	})
	var fire_tiles: Array[Vector2i] = [pos]
	grid.emit_signal("grid_tiles_changed", fire_tiles)
	grid.emit_signal("grid_changed")

	var b_name: String = String(t.get("building", "건물"))
	var desc := "공방 구역" if b_name.begins_with("ind") else ("저잣거리 상가" if b_name.begins_with("com") else "민가")
	if sim != null:
		sim.fire_active = true
		sim.emit_signal("disaster_alert", "🚨 [화마(火魔) 경보] %s에서 화재가 발생하였습니다! 멸화군을 파견하여 진화하십시오!" % desc)
		if sim.has_signal("fire_outbreak"):
			sim.fire_outbreak.emit(pos)
	if court != null:
		court.emit_signal("notice", "불이야! %s에 화마가 덮쳤습니다! 서둘러 물을 대고 진화해야 합니다!" % desc)

	if not _firefighter_cache.is_empty():
		_dispatch_firefighter_squad(pos)

	# 민심 기반 NPC 행동 분기 (FSM 전이)
	_trigger_citizen_fire_reaction(pos)

## 민심 수치에 따른 주변 백성 행동 분기 (도망 vs 물 긷기 진화)
func _trigger_citizen_fire_reaction(fire_pos: Vector2i) -> void:
	if sim == null:
		return
	var loyalty: int = sim.loyalty
	var fire_center := Vector2(float(fire_pos.x) + 0.5, float(fire_pos.y) + 0.5)

	# 반경 8타일 내 일반 백성 검색
	var nearby_citizens: Array[Dictionary] = []
	for a: Dictionary in agents:
		if a.get("is_wild", false) or a.get("is_named", false):
			continue
		var at: String = a.get("type", "")
		if at in ["firefighter_soldier", "patrol_soldier", "guard", "chakhogapsa", "bandit"]:
			continue
		var cur := Vector2(float(a.get("x", 0.0)), float(a.get("y", 0.0)))
		if cur.distance_to(fire_center) <= 8.5:
			nearby_citizens.append(a)

	if nearby_citizens.is_empty():
		return

	# 민심 60 이하: 전원 비명을 지르며 반대 방향으로 도망 (Panic Run)
	if loyalty <= 60:
		for a: Dictionary in nearby_citizens:
			a["state"] = "fire_panic"
			a["panic_timer"] = randf_range(6.0, 10.0)
			a["flee_from"] = fire_center
			a["bubble_text"] = ["불이야! 살려주시오!", "다 타버리기 전에 도망치자!", "아이고, 화마가 덮쳤네!"][randi() % 3]
			a["bubble_timer"] = 3.5
	else:
		# 민심 61 이상: 민심에 비례하여 진압 돕는 자와 도망치는 자 비율 결정
		var help_ratio: float = clampf((float(loyalty) - 60.0) / 40.0, 0.0, 1.0)
		for a: Dictionary in nearby_citizens:
			if randf() < help_ratio:
				# 자원 진화대 전환 (물 긷기 -> 물 뿌리기 루프)
				a["type"] = "bucket_volunteer"
				a["state"] = "fetch_water"
				a["target_fire_pos"] = fire_pos
				a["water_source"] = _find_nearest_water_source(fire_pos)
				a["bubble_text"] = ["물을 퍼 날라라!", "불길을 막아야 하오!", "어서 물동이를 넘기시오!"][randi() % 3]
				a["bubble_timer"] = 2.5
			else:
				# 대피 모드
				a["state"] = "fire_panic"
				a["panic_timer"] = randf_range(5.0, 8.0)
				a["flee_from"] = fire_center
				a["bubble_text"] = "아이를 챙겨 어서 피하시오!"
				a["bubble_timer"] = 3.0

## 가장 가까운 용수 공급처(우물, 하천변, 저수지) 탐색
func _find_nearest_water_source(from_pos: Vector2i) -> Vector2i:
	var best_p := Vector2i(-1, -1)
	var best_dist := 999999
	for wb: Dictionary in _water_banks_cache:
		var wp: Vector2i = wb.get("pos", Vector2i(-1, -1))
		var d: int = absi(wp.x - from_pos.x) + absi(wp.y - from_pos.y)
		if d < best_dist:
			best_dist = d
			best_p = wp
			if d <= 2:
				break
	if best_p.x < 0 and not _roads_cache.is_empty():
		best_p = _find_nearest_road(from_pos)
	return best_p

func _dispatch_firefighter_squad(target_pos: Vector2i) -> void:
	if _firefighter_cache.is_empty():
		return
	
	# 가장 가까운 멸화군 관서(station) 선정
	var station_pos: Vector2i = _firefighter_cache[0]
	var best_d: float = Vector2(station_pos).distance_to(Vector2(target_pos))
	for i in range(1, _firefighter_cache.size()):
		var st: Vector2i = _firefighter_cache[i]
		var d: float = Vector2(st).distance_to(Vector2(target_pos))
		if d < best_d:
			best_d = d
			station_pos = st

	# 멸화군 개수에 따른 출동 속도 산출 (기본 1.0, 1개소당 +0.5, 최대 3.0)
	var ff_speed: float = clampf(1.0 + (float(_firefighter_cache.size()) * 0.5), 1.0, 3.0)

	var count: int = randi_range(3, 4)
	for i in range(count):
		_add_firefighter_soldier(station_pos, target_pos, i, ff_speed)

func _add_firefighter_soldier(start_pos: Vector2i, target_pos: Vector2i, idx: int, custom_speed: float = 1.45) -> Dictionary:
	_next_agent_id += 1
	var offset_v := Vector2(cos(idx * 1.57) * 0.4, sin(idx * 1.57) * 0.4)
	var ag: Dictionary = {
		"id": _next_agent_id,
		"type": "firefighter_soldier",
		"x": float(start_pos.x) + 0.5 + offset_v.x,
		"y": float(start_pos.y) + 0.5 + offset_v.y,
		"from_tile": start_pos,
		"to_tile": target_pos,
		"home_tile": start_pos,
		"progress": 0.0,
		"dir": Vector2.RIGHT,
		"speed": clampf(custom_speed, 1.0, 3.0),
		"anim": randf() * 4.0,
		"state": "rush_to_fire",
		"state_timer": 0.0,
		"target_pos": Vector2(float(target_pos.x) + 0.5 + offset_v.x, float(target_pos.y) + 0.5 + offset_v.y),
		"target_fire_pos": target_pos,
		"is_spot": false,
		"is_named": false,
		"is_wild": false,
		"bubble_text": "멸화군 출동! 물을 길어라!" if idx == 0 else "갈고리로 불길을 잡아라!",
		"bubble_timer": 3.0,
		"extra": {"idx": idx}
	}
	agents.append(ag)
	return ag

func _update_firefighter_soldier(a: Dictionary, delta: float) -> void:
	var state: String = a.get("state", "rush_to_fire")
	var target_pos: Vector2i = a.get("target_fire_pos", Vector2i(-1, -1))
	var home_pos: Vector2i = a.get("home_tile", Vector2i(10, 10))

	match state:
		"rush_to_fire":
			var tg := Vector2(float(target_pos.x) + 0.5, float(target_pos.y) + 0.5)
			var cur := Vector2(float(a["x"]), float(a["y"]))
			var c_dist: float = maxf(absf(cur.x - tg.x), absf(cur.y - tg.y))
			# 3칸 근접 도달 판정 (Chebyshev dist <= 3.2 시 즉시 원거리 방수 개시)
			if cur.distance_to(tg) <= 1.1 or c_dist <= 3.2:
				a["state"] = "extinguish"
				a["state_timer"] = 5.0
				a["bubble_text"] = "치이익-! 물을 뿌려라!"
				a["bubble_timer"] = 3.5
			else:
				_move_agent_towards(a, tg, delta, float(a.get("speed", 1.45)))
		"extinguish":
			var stimer: float = float(a.get("state_timer", 0.0)) - delta
			a["state_timer"] = stimer
			a["anim"] = float(a.get("anim", 0.0)) + delta * 6.0
			var is_fire_still_active := false
			for f: Dictionary in _active_fires:
				if f.get("pos", Vector2i(-1, -1)) == target_pos and not f.get("extinguished", false):
					is_fire_still_active = true
					break
			if not is_fire_still_active or stimer <= 0.0:
				a["state"] = "go_home"
				a["bubble_text"] = "진화 완료! 멸화청으로 개선하라!"
				a["bubble_timer"] = 3.0
		"go_home":
			var tg2 := Vector2(float(home_pos.x) + 0.5, float(home_pos.y) + 0.5)
			var cur2 := Vector2(float(a["x"]), float(a["y"]))
			if cur2.distance_to(tg2) <= 0.5:
				a["is_dead"] = true
			else:
				_move_agent_towards(a, tg2, delta, 0.95)

## 백성 자원 진화대(bucket_volunteer) FSM (물 긷기 -> 물동이 운반 -> 물 뿌리기 진화 루프)
func _update_bucket_volunteer(a: Dictionary, delta: float) -> void:
	var state: String = a.get("state", "fetch_water")
	var target_fire: Vector2i = a.get("target_fire_pos", Vector2i(-1, -1))
	var water_src: Vector2i = a.get("water_source", Vector2i(-1, -1))

	var is_fire_alive := false
	for f: Dictionary in _active_fires:
		if f.get("pos", Vector2i(-1, -1)) == target_fire and not f.get("extinguished", false):
			is_fire_alive = true
			break

	if not is_fire_alive:
		a["state"] = "go_home"
		a["bubble_text"] = "불이 꺼졌구나! 천만다행일세!"
		a["bubble_timer"] = 3.0
		a["is_dead"] = true
		return

	match state:
		"fetch_water":
			var tg := Vector2(float(water_src.x) + 0.5, float(water_src.y) + 0.5)
			var cur := Vector2(float(a["x"]), float(a["y"]))
			if cur.distance_to(tg) <= 1.2:
				a["state"] = "fill_bucket"
				a["state_timer"] = 1.2
				a["bubble_text"] = "물을 긷자, 어서!"
				a["bubble_timer"] = 1.5
			else:
				_move_agent_towards(a, tg, delta, float(a.get("speed", 1.25)))
		"fill_bucket":
			var st: float = float(a.get("state_timer", 0.0)) - delta
			a["state_timer"] = st
			a["anim"] = float(a.get("anim", 0.0)) + delta * 4.0
			if st <= 0.0:
				a["state"] = "carry_water"
				a["has_water"] = true
				a["bubble_text"] = "불길로 물을 날라라!"
				a["bubble_timer"] = 2.0
		"carry_water":
			var f_goal := Vector2(float(target_fire.x) + 0.5, float(target_fire.y) + 0.5)
			var cur2 := Vector2(float(a["x"]), float(a["y"]))
			var c_dist2: float = maxf(absf(cur2.x - f_goal.x), absf(cur2.y - f_goal.y))
			# 3칸 근접 도달 판정 (Chebyshev dist <= 3.2 시 즉시 투수 개시)
			if cur2.distance_to(f_goal) <= 1.3 or c_dist2 <= 3.2:
				a["state"] = "pour_water"
				a["state_timer"] = 2.0
				a["bubble_text"] = "물을 끼얹어라! 촤아악!"
				a["bubble_timer"] = 2.0
			else:
				_move_agent_towards(a, f_goal, delta, float(a.get("speed", 1.2)))
		"pour_water":
			var st2: float = float(a.get("state_timer", 0.0)) - delta
			a["state_timer"] = st2
			a["anim"] = float(a.get("anim", 0.0)) + delta * 6.0
			for f: Dictionary in _active_fires:
				if f.get("pos", Vector2i(-1, -1)) == target_fire:
					f["duration"] = maxf(0.0, float(f.get("duration", 0.0)) - delta * 1.5)
					f["fire_progress"] = maxf(0.0, float(f.get("fire_progress", 0.0)) - delta * 0.08)
			if st2 <= 0.0:
				a["has_water"] = false
				a["state"] = "fetch_water"

## 화재 발생 시 공포에 질린 백성 도망 (Panic Run)
func _update_fire_panic(a: Dictionary, delta: float) -> void:
	var panic_t: float = float(a.get("panic_timer", 5.0)) - delta
	a["panic_timer"] = panic_t
	if panic_t <= 0.0:
		a["state"] = "walk"
		return
	var cur := Vector2(float(a["x"]), float(a["y"]))
	var f_from: Vector2 = a.get("flee_from", cur)
	var away := (cur - f_from).normalized()
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	_move_agent_towards(a, cur + away * 3.0, delta, 1.7)
	a.erase("path")

## 수해(홍수) 발생 시 전시 비상 대피 체제 및 민관군 합동 방재 제어
func _manage_flood_crisis(delta: float) -> void:
	if sim == null or not sim.flood_crisis_active:
		return

	_flood_response_timer -= delta
	if _flood_response_timer > 0.0:
		return
	_flood_response_timer = 2.5

	# 1. 저잣거리 상인/노점 영업 중단 및 피난 모드 강제 전이
	for a: Dictionary in agents:
		var at: String = a.get("type", "")
		if at in ["shopkeeper", "artisan", "porter", "shopper", "merchant"] and a.get("state", "") != "flood_evacuate":
			a["type"] = "flood_refugee"
			a["state"] = "flee_to_high_ground"
			a["high_ground"] = Vector2i(randi_range(8, 14), randi_range(12, 22)) # 팔달산 서장대 고지대
			a["bubble_text"] = "홍수다! 짐을 싸서 팔달산으로 대피하자!"
			a["bubble_timer"] = 3.5

	# 2. 민관군 합동 방재대(flood_sandbag) 스폰 및 유지 (최대 5명)
	var current_sandbags := agents.filter(func(a: Dictionary) -> bool:
		return a.get("type", "") == "flood_sandbag" and not a.get("is_dead", false)
	)
	if current_sandbags.size() < 5 and not _water_banks_cache.is_empty():
		var wb: Dictionary = _water_banks_cache[randi() % _water_banks_cache.size()]
		var target_levee: Vector2i = wb["pos"]
		_add_flood_sandbag(target_levee)

	# 3. 고지대 피난민(flood_refugee) 행렬 유지 (최대 8명)
	var current_refugees := agents.filter(func(a: Dictionary) -> bool:
		return a.get("type", "") == "flood_refugee" and not a.get("is_dead", false)
	)
	if current_refugees.size() < 8 and not _roads_cache.is_empty():
		var start_p: Vector2i = _roads_cache[randi() % _roads_cache.size()]
		_add_flood_refugee(start_p)

func _add_flood_sandbag(target_levee: Vector2i) -> Dictionary:
	_next_agent_id += 1
	var depot_pos := target_levee + Vector2i(randi_range(-2, 2), randi_range(-2, 2))
	if depot_pos == target_levee: depot_pos.x += 1
	var ag: Dictionary = {
		"id": _next_agent_id,
		"type": "flood_sandbag",
		"x": float(depot_pos.x) + 0.5,
		"y": float(depot_pos.y) + 0.5,
		"from_tile": depot_pos,
		"to_tile": target_levee,
		"levee_pos": target_levee,
		"depot_pos": depot_pos,
		"state": "carry_sandbag",
		"state_timer": 0.0,
		"speed": 1.05,
		"anim": 0.0,
		"bubble_text": "가마니를 쌓아 물길을 막아라!",
		"bubble_timer": 3.0,
		"is_spot": false,
		"is_named": false,
		"is_wild": false
	}
	agents.append(ag)
	return ag

func _add_flood_refugee(start_pos: Vector2i) -> Dictionary:
	_next_agent_id += 1
	var high_p := Vector2i(randi_range(8, 14), randi_range(12, 22)) # 팔달산 능선 고지대
	var ag: Dictionary = {
		"id": _next_agent_id,
		"type": "flood_refugee",
		"x": float(start_pos.x) + 0.5,
		"y": float(start_pos.y) + 0.5,
		"from_tile": start_pos,
		"to_tile": high_p,
		"high_ground": high_p,
		"state": "flee_to_high_ground",
		"speed": 0.85,
		"anim": 0.0,
		"bubble_text": ["팔달산으로 대피하시오!", "물이 차오른다!", "어서 고지대로 가자!"][randi() % 3],
		"bubble_timer": 3.5,
		"is_spot": false,
		"is_named": false,
		"is_wild": false
	}
	agents.append(ag)
	return ag

func _update_flood_sandbag(a: Dictionary, delta: float) -> void:
	if not (sim != null and sim.flood_crisis_active):
		a["state"] = "go_home"
		a["bubble_text"] = "물이 빠졌으니 방재를 마친다!"
		a["bubble_timer"] = 2.5
		a["is_dead"] = true
		return
	var state: String = a.get("state", "carry_sandbag")
	var target_levee: Vector2i = a.get("levee_pos", Vector2i(32, 32))
	var depot_pos: Vector2i = a.get("depot_pos", target_levee + Vector2i(2, 0))

	match state:
		"carry_sandbag":
			var cur := Vector2(float(a["x"]), float(a["y"]))
			var tg := Vector2(float(target_levee.x) + 0.5, float(target_levee.y) + 0.5)
			if cur.distance_to(tg) <= 0.8:
				a["state"] = "pile_sandbag"
				a["state_timer"] = 2.5
				a["bubble_text"] = "가마니를 쌓아 물길을 막아라!"
				a["bubble_timer"] = 2.5
			else:
				_move_agent_towards(a, tg, delta, 1.0)
		"pile_sandbag":
			var st: float = float(a.get("state_timer", 0.0)) - delta
			a["state_timer"] = st
			a["anim"] = float(a.get("anim", 0.0)) + delta * 5.0
			if st <= 0.0:
				a["state"] = "fetch_sandbag"
		"fetch_sandbag":
			var cur2 := Vector2(float(a["x"]), float(a["y"]))
			var dp := Vector2(float(depot_pos.x) + 0.5, float(depot_pos.y) + 0.5)
			if cur2.distance_to(dp) <= 0.8:
				a["state"] = "carry_sandbag"
				a["bubble_text"] = "흙포대를 더 대시오!"
				a["bubble_timer"] = 2.0
			else:
				_move_agent_towards(a, dp, delta, 1.1)

func _update_flood_refugee(a: Dictionary, delta: float) -> void:
	if not (sim != null and sim.flood_crisis_active):
		a["state"] = "go_home"
		a["is_dead"] = true
		return
	var high_ground: Vector2i = a.get("high_ground", Vector2i(12, 18))
	var tg := Vector2(float(high_ground.x) + 0.5, float(high_ground.y) + 0.5)
	var cur := Vector2(float(a["x"]), float(a["y"]))
	if cur.distance_to(tg) <= 1.2:
		a["state"] = "sheltered"
		a["bubble_text"] = "팔달산 능선에 오르니 물을 피했구나..."
		a["bubble_timer"] = 4.0
	else:
		_move_agent_towards(a, tg, delta, 0.85)

## PORT-TRACE [교역 상인 복구]: TradeSystem.check_routes가 교역로 개통 순간 국경 관문에 상인을 내보낼 때
## 부르는 함수. 도적·순라군 기능을 추가하며 파일을 다시 쓰는 과정에서 이 함수가 빠져, 길을 놓아
## 교역로가 이어지는 순간 "Nonexistent function 'spawn_merchant'" 오류로 게임이 멈췄다(사용자 제보).
func spawn_merchant(border: Vector2i) -> void:
	if grid == null or not grid.in_bounds(border.x, border.y):
		return
	var ag := _add_road_agent("merchant", border)
	ag["bubble_text"] = "교역 물자 왔소!"
	ag["bubble_timer"] = 3.0

## 교역로 개통 시 보부상 및 짐수레 마차를 성문으로 유입시키는 카라반 행렬 스폰
func spawn_trade_caravan(border: Vector2i, gate_pos: Vector2i) -> void:
	if grid == null or not grid.in_bounds(border.x, border.y):
		return
	var m := _add_road_agent("merchant", border)
	m["bubble_text"] = "타관 교역 물자 도착이오!"
	m["bubble_timer"] = 3.5
	m["dest"] = gate_pos

	var c_type: String = "grain_cart" if randf() < 0.5 else "cart"
	var c := _add_road_agent(c_type, border)
	c["bubble_text"] = "특산물을 싣고 입성하오!"
	c["bubble_timer"] = 3.5
	c["dest"] = gate_pos

## PORT-TRACE [장마당·세시풍속]: 길을 따라 도는 행렬(풍물패 길놀이, 씨름 장사 황소 퍼레이드). 일반 길손과
## 같은 도로 보행 로직을 쓰고 ttl초 뒤 흩어진다. 마을 조건이 안 돼 길손을 정리할 때도 남겨 둔다.
func spawn_festival_walker(kind: String, start: Vector2i, ttl: float, chant: String) -> void:
	if not _roads_set.has(start):
		if _roads_cache.is_empty():
			return
		start = _roads_cache[randi() % _roads_cache.size()]
	var ag := _add_road_agent(kind, start)
	SeasonalCustomManager.apply_custom_flags(ag)
	ag["is_special_entity"] = true
	ag["is_always_visible"] = true
	ag["ttl"] = ttl
	ag["speed"] = 0.55
	ag["chant"] = chant
	ag["bubble_text"] = chant
	ag["bubble_timer"] = 4.0
	SeasonalCustomManager.tag_custom_actor(ag, kind)
	match kind:
		"bull_parade":
			ag["activity_type"] = "ACTIVITY_SSIREUM_CHAMPION"
		"pungmul_band":
			ag["activity_type"] = "ACTIVITY_PUNGMUL"
		_:
			ag["activity_type"] = kind

## 석전 부상자를 들것에 실어 약방·관아로
func spawn_stretcher(from: Vector2i, to: Vector2i) -> void:
	var ag := _add_spot_agent("stretcher", from, {"target": to})
	SeasonalCustomManager.apply_custom_flags(ag)
	ag["is_special_entity"] = true
	ag["is_always_visible"] = true
	ag["bubble_text"] = "아이고, 돌에 맞았네! 약방으로!"
	ag["bubble_timer"] = 4.0

func _add_spot_agent(type: String, pos: Vector2i, extra_data: Dictionary = {}) -> Dictionary:
	_next_agent_id += 1
	var offset_x: float = float(pos.x) + 0.5
	var offset_y: float = float(pos.y) + 0.5

	# 수변 물속 침범 방지: 육지 안쪽으로 오프셋
	if extra_data.has("water_dir"):
		var wdir: Vector2 = extra_data["water_dir"]
		if extra_data.get("levee", false):
			if type == "washer":
				# 둑 너머 물가 빨래터(둑 바깥 발치, 물과 맞닿은 곳)
				offset_x += wdir.x * 0.42
				offset_y += wdir.y * 0.42
			else:
				# 둑 위(마루)에 서서 낚싯대를 드리운다 — 그림에서 둑 높이만큼 올려 그린다
				offset_x += wdir.x * 0.08
				offset_y += wdir.y * 0.08
				extra_data["lift"] = 8.0
		else:
			offset_x -= wdir.x * 0.22
			offset_y -= wdir.y * 0.22

	var ag := {
		"id": _next_agent_id,
		"type": type,
		"x": offset_x,
		"y": offset_y,
		"from_tile": pos,
		"to_tile": pos,
		"progress": 1.0,
		"dir": Vector2.DOWN,
		"speed": 0.8,
		"anim": randf() * 4.0,
		"state": extra_data.get("initial_state", "work"),
		"state_timer": extra_data.get("initial_timer", randf_range(15.0, 25.0)),
		"is_spot": true,
		"is_named": false,
		"is_wild": false,
		"bubble_text": "",
		"bubble_timer": 0.0,
		"extra": extra_data
	}
	agents.append(ag)
	return ag

func _add_wild_animal(animal_type: String, pos: Vector2i, extra_data: Dictionary = {}) -> Dictionary:
	_next_agent_id += 1
	var ag := {
		"id": _next_agent_id,
		"type": animal_type,
		"x": float(pos.x) + 0.5,
		"y": float(pos.y) + 0.5,
		"from_tile": pos,
		"to_tile": pos,
		"dir": Vector2.RIGHT if randf() > 0.5 else Vector2.LEFT,
		"speed": randf_range(0.45, 0.75),
		"anim": randf() * 4.0,
		"state": "wander",
		"state_timer": randf_range(3.0, 6.0),
		"is_spot": false,
		"is_named": false,
		"is_wild": true,
		"bubble_text": "",
		"bubble_timer": 0.0,
		"extra": extra_data
	}
	agents.append(ag)
	return ag

## 네임드 정보: 옛 7인은 NAMED_INFO, 나머지 17인은 NamedNpcs
static func named_info(nid: String) -> Dictionary:
	if NAMED_INFO.has(nid):
		return NAMED_INFO[nid]
	return NamedNpcs.info(nid)

## 사람이 설 수 있는 칸(빈 땅·길, 물·건물 아님) — 아니면 가까운 그런 칸(길 먼저)
func _free_tile_near(p: Vector2i) -> Vector2i:
	var ok := func(q: Vector2i) -> bool:
		if grid == null or not grid.in_bounds(q.x, q.y):
			return false
		var t: Dictionary = grid.grid[q.y][q.x]
		return String(t.get("building", "")) in ["", "road", "stone_road"] and String(t.get("terrain", "")) != "water"
	if ok.call(p):
		return p
	var best := Vector2i(-1, -1)
	var best_d := 9999.0
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := p + Vector2i(dx, dy)
				if ok.call(q):
					var d := Vector2(dx, dy).length() - (0.5 if _roads_set.has(q) else 0.0)
					if d < best_d:
						best_d = d
						best = q
		if best.x >= 0:
			return best
	return p

func _add_named_agent(named_id: String, pos: Vector2i, home_pos: Vector2i) -> Dictionary:
	pos = _free_tile_near(pos) # PORT-TRACE [지붕 위 사람]: 성벽 옆·가게 칸 등 건물 칸에 자리 잡으면 지붕 위에 선다
	_next_agent_id += 1
	var ninfo: Dictionary = named_info(named_id)
	var first_line: String = get_contextual_named_line(named_id)

	var ag := {
		"id": _next_agent_id,
		"type": "named_" + named_id,
		"named_id": named_id,
		"name": ninfo.get("name", "인물"),
		"title": ninfo.get("title", ""),
		"role_tag": ninfo.get("role_tag", ""),
		"x": float(pos.x) + 0.5,
		"y": float(pos.y) + 0.5,
		"from_tile": pos,
		"to_tile": pos,
		"home_tile": home_pos,
		"progress": 1.0,
		"dir": Vector2.DOWN,
		"speed": 0.75,
		"anim": randf() * 4.0,
		"state": "work",
		"work_timer": randf_range(30.0, 45.0),
		"is_spot": true,
		"is_named": true,
		"is_wild": false,
		"bubble_text": first_line,
		"bubble_timer": 4.5,
		"extra": {}
	}
	agents.append(ag)
	return ag

## 엔티티 안전 제거 (Safe Despawn/Kill: null 참조 및 고아 노드 메모리 누수 방지)
func safe_remove_agent(a: Dictionary) -> void:
	if a.is_empty():
		return
	a["is_dead"] = true
	a["is_threat_target"] = false
	if a.has("node") and is_instance_valid(a.get("node", null)):
		var n: Node = a["node"]
		if n.is_inside_tree():
			n.queue_free()
	a.erase("node")

## 특정 위치가 현재 카메라 화면(뷰포트) 안인지 판정 (오프스크린 컬링/동결용)
func is_world_pos_on_screen(tile_pos: Vector2) -> bool:
	var vp: Viewport = get_viewport()
	if vp == null:
		return true
	var cam: Camera2D = vp.get_camera_2d()
	if cam == null:
		return true
	var zm: float = maxf(0.1, cam.zoom.x)
	var vp_size: Vector2 = vp.get_visible_rect().size / zm
	var cam_pos: Vector2 = cam.global_position
	# 2.5D 아이소메트릭 좌표: x = (gx - gy) * 32, y = (gx + gy) * 16
	var iso_x: float = (tile_pos.x - tile_pos.y) * 32.0
	var iso_y: float = (tile_pos.x + tile_pos.y) * 16.0
	var margin: float = 140.0
	return absf(iso_x - cam_pos.x) <= (vp_size.x * 0.5 + margin) and absf(iso_y - cam_pos.y) <= (vp_size.y * 0.5 + margin)

## 신규 산짐승 스폰 위치 엄격 유효성 검사 (산지/깊은 숲 전용 & 마을 50칸 외곽)
func can_spawn_wild_animal(pos: Vector2i) -> bool:
	if grid == null or not grid.in_bounds(pos.x, pos.y):
		return false
	var t: Dictionary = grid.grid[pos.y][pos.x]
	var terr: String = String(t.get("terrain", ""))
	var surf: String = String(t.get("surface", ""))
	var b: String = String(t.get("building", ""))
	var zone: String = String(t.get("zone", ""))

	# 평지, 수역, 농지, 제방, 도로, 건물 타일 스폰 100% 원천 차단
	if terr == "plain" or terr == "water":
		return false
	if b != "" or zone != "":
		return false
	if b in ["road", "stone_road", "levee", "wall", "gate"] or zone in ["agr", "res", "com", "ind"]:
		return false

	# 지형 속성 필수 조건: 산지(mountain)이거나 깊은 암석/숲(rocky/forest)
	var is_mountain_or_deep: bool = (terr == "mountain") or (surf in ["forest", "rocky"] and terr != "plain")
	if not is_mountain_or_deep:
		return false

	# 마을(민가, 상점, 저잣거리, 공방, 관아 등) 중심점과의 거리가 50칸 이상 떨어진 외곽일 것
	if not _is_wildlife_safe_zone(pos, 50):
		return false

	return true

## 민가(res), 저잣거리(com/shop), 공방(ind), 관아(gwana), 행궁 반경 min_dist칸 이내인지 체비쇼프 거리로 판정
func _is_wildlife_safe_zone(pos: Vector2i, min_dist: int = 50) -> bool:
	for r: Vector2i in _res_cache:
		if maxi(absi(pos.x - r.x), absi(pos.y - r.y)) < min_dist:
			return false
	for c: Vector2i in _com_cache:
		if maxi(absi(pos.x - c.x), absi(pos.y - c.y)) < min_dist:
			return false
	for s: Vector2i in _shop_cache:
		if maxi(absi(pos.x - s.x), absi(pos.y - s.y)) < min_dist:
			return false
	for ws: Vector2i in _workshop_cache:
		if maxi(absi(pos.x - ws.x), absi(pos.y - ws.y)) < min_dist:
			return false
	for gw: Vector2i in _gwana_cache:
		if maxi(absi(pos.x - gw.x), absi(pos.y - gw.y)) < min_dist:
			return false
	if _haenggung_gate.x >= 0:
		if maxi(absi(pos.x - _haenggung_gate.x), absi(pos.y - _haenggung_gate.y)) < min_dist:
			return false
	return true

## 50칸 외곽의 깊은 산악/산지 숲 지대 스폰 후보 타일 추출 (미달 시 100% 스폰 취소 Abort)
func _pick_safe_wildlife_spot(candidates: Array[Vector2i], _min_dist: int = 50) -> Vector2i:
	if candidates.is_empty():
		return Vector2i(-1, -1)
	var safe_spots: Array[Vector2i] = []
	for p: Vector2i in candidates:
		if can_spawn_wild_animal(p):
			safe_spots.append(p)
	if not safe_spots.is_empty():
		return safe_spots[randi() % safe_spots.size()]

	# 조건 미달 시 평지 유입을 원천 차단하기 위해 즉시 스폰 취소 (Fallback 금지)
	return Vector2i(-1, -1)

## 산짐승 스폰 범용 인터페이스
func spawn_animal(animal_type: String, pos: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var spawn_pos: Vector2i = pos
	if spawn_pos.x < 0 or spawn_pos.y < 0:
		var pool: Array[Vector2i] = _mountain_forest_cache if not _mountain_forest_cache.is_empty() else _mountain_cache
		spawn_pos = _pick_safe_wildlife_spot(pool, 50)

	if spawn_pos.x < 0 or not can_spawn_wild_animal(spawn_pos):
		return {} # 스폰 조건 미달 시 즉각 취소(Abort)

	return _add_wild_animal(animal_type, spawn_pos)

## 자연 산짐승 생태계 동기화 (마을 50칸 외곽 산지/깊은 숲 타일로만 100% 한정)
func _sync_wildlife() -> void:
	var wild_count: int = agents.filter(func(a: Dictionary) -> bool: return a.get("is_wild", false) and not a.get("is_dead", false)).size()
	var target_wild: int = 5

	if wild_count < target_wild:
		# 1. 두루미 / 백로 (수원천 수변 중 민가 50칸 밖)
		if not _water_banks_cache.is_empty() and randf() < 0.6:
			var safe_banks: Array[Dictionary] = _water_banks_cache.filter(func(sp: Dictionary) -> bool: return _is_wildlife_safe_zone(sp["pos"], 50))
			if not safe_banks.is_empty():
				var sp: Dictionary = safe_banks[randi() % safe_banks.size()]
				_add_wild_animal("crane", sp["pos"], {"water_dir": sp["water_dir"]})

		# 2. 꽃사슴 / 노루 (50칸 밖 산악 깊은 숲)
		var deer_pool: Array[Vector2i] = _mountain_forest_cache if not _mountain_forest_cache.is_empty() else _mountain_cache
		var deer_spot: Vector2i = _pick_safe_wildlife_spot(deer_pool, 50)
		if deer_spot.x >= 0 and randf() < 0.7:
			_add_wild_animal("deer", deer_spot)

		# 3. 멧돼지 (50칸 밖 산악 암석 또는 깊은 숲)
		var boar_pool: Array[Vector2i] = _mountain_rocky_cache if not _mountain_rocky_cache.is_empty() else _mountain_cache
		var boar_spot: Vector2i = _pick_safe_wildlife_spot(boar_pool, 50)
		if boar_spot.x >= 0:
			_add_wild_animal("wild_boar", boar_spot)

		# 4. 산토끼 (50칸 밖 산악 숲/산지)
		var rabbit_pool: Array[Vector2i] = _mountain_cache if not _mountain_cache.is_empty() else _mountain_forest_cache
		var rabbit_spot: Vector2i = _pick_safe_wildlife_spot(rabbit_pool, 50)
		if rabbit_spot.x >= 0:
			_add_wild_animal("rabbit", rabbit_spot)

## 마을 형성 시 잔존 산짐승 즉시 소탕 판정 (마을 반경 50칸 이내 동물 -> THREAT_TARGET 마킹 및 포수 비상 출동)
func _check_and_mark_village_threat_animals() -> void:
	var has_village: bool = not _res_cache.is_empty() or not _com_cache.is_empty() or not _shop_cache.is_empty()
	if not has_village:
		return

	var threat_found: int = 0
	var hopo: bool = _hoporyeong()
	for a: Dictionary in agents:
		if a.get("is_dead", false):
			continue
		var atype: String = String(a.get("type", ""))
		var is_animal: bool = a.get("is_wild", false) or (atype in ["tiger", "wolf", "deer", "wild_boar", "rabbit"])
		if not is_animal:
			continue

		# 호랑이는 조정의 결단인 호포제(호포령)를 통해서만 사냥/퇴치해야 하므로, 평시 자동 소탕 타깃에서 100% 제외
		if atype == "tiger" and not hopo:
			a["is_threat_target"] = false
			continue

		var apos := Vector2i(int(floor(float(a.get("x", 0.0)))), int(floor(float(a.get("y", 0.0)))))
		# 마을 경계 기준 50칸 이내에 이미 남아있는 산짐승인지 판정
		if not _is_wildlife_safe_zone(apos, 50):
			a["is_threat_target"] = true
			a["threat_reason"] = "village_intruder"
			threat_found += 1
		else:
			a["is_threat_target"] = false

	if threat_found > 0:
		_trigger_threat_hunt_dispatch()

## 마을 내 잔존/침범 산짐승 소탕을 위한 포수 긴급 출동 FSM
func _trigger_threat_hunt_dispatch() -> void:
	var has_active_hunter: bool = false
	for a: Dictionary in agents:
		if a.get("is_dead", false):
			continue
		var atype: String = String(a.get("type", ""))
		if atype == "saposu" and a.get("leader", false):
			has_active_hunter = true
			var st: String = String(a.get("state", ""))
			if st in ["search", "leave", "present", "deliver"]:
				a["state"] = "search"
				a["search_throttle"] = 0.0
				a["bubble_text"] = "마을에 산짐승이 나타났다! 서둘러 조총을 겨눠라!"
				a["bubble_timer"] = 3.5
		elif atype == "hunter":
			has_active_hunter = true
			var st2: String = String(a.get("state", ""))
			if st2 in ["search_prey", "go_home", "sell"]:
				a["state"] = "search_prey"
				a["search_throttle"] = 0.0
				a["bubble_text"] = "마을 안에 짐승이라니! 활시위를 당겨 소탕하세!"
				a["bubble_timer"] = 3.5

	# 활동 중인 포수가 없으면 쿨타임을 즉시 초기화하여 사포수 조 출동
	if not has_active_hunter:
		_saposu_timer = 0.0

## 포수/사냥꾼 타깃 탐색 함수 (1순위: 마을 반경 50칸 내 침범/잔존 짐승, 2순위: 외곽 산악 지형의 야생 짐승)
## 타깃 탐색 스로틀링: 2~3초 간격 타이머로 캐싱하여 매 프레임 거리 전수 계산 방지
func find_target_animal(hunter_pos: Vector2, hunter: Dictionary) -> Dictionary:
	var throttle: float = float(hunter.get("search_throttle", 0.0))
	var cached_id: int = int(hunter.get("target_animal_id", hunter.get("target_id", -1)))

	# 스로틀링 유효 기간 내에는 캐시된 기존 타깃 유지
	if throttle > 0.0 and cached_id >= 0:
		for a: Dictionary in agents:
			if a.get("id", -1) == cached_id and not a.get("is_dead", false):
				return a

	hunter["search_throttle"] = randf_range(2.0, 3.0)

	var threat_candidates: Array[Dictionary] = []
	var wild_candidates: Array[Dictionary] = []
	var hopo: bool = _hoporyeong()
	var has_village: bool = not _res_cache.is_empty() or not _com_cache.is_empty() or not _shop_cache.is_empty()

	for o: Dictionary in agents:
		if o.get("is_dead", false) or o.has("doomed"):
			continue
		var ot: String = String(o.get("type", ""))
		var is_animal: bool = o.get("is_wild", false) or (ot in ["tiger", "wolf", "deer", "wild_boar", "rabbit"])
		if not is_animal:
			continue

		# [호포제 전용 규약] 호랑이는 조정의 호포제(호포령 발동)를 통해서만 포획 가능 — 평시 자동 사냥 100% 차단
		# 활 사냥꾼(hunter)은 호랑이를 일절 타깃팅하지 않으며, 사포수(saposu)도 호포령이 꺼져 있으면 호랑이를 사냥할 수 없음
		if ot == "tiger":
			if not hopo or String(hunter.get("type", "")) == "hunter":
				continue

		var opos := Vector2(float(o["x"]), float(o["y"]))
		var is_threat: bool = o.get("is_threat_target", false)

		# 마을 50칸 이내 실시간 침범 여부 재확인
		if has_village and not is_threat:
			var otile := Vector2i(int(floor(opos.x)), int(floor(opos.y)))
			if not _is_wildlife_safe_zone(otile, 50):
				is_threat = true
				o["is_threat_target"] = true
				o["threat_reason"] = "village_intruder"

		if is_threat or (hopo and ot == "tiger"):
			threat_candidates.append(o)
		else:
			# 2순위: 외곽 산지/깊은 숲의 야생 짐승
			wild_candidates.append(o)

	# 1순위: 마을 반경 50칸 내 침범/잔존 짐승 우선 소탕
	if not threat_candidates.is_empty():
		var best_threat: Dictionary = {}
		var min_threat_dist: float = 999999.0
		for tc: Dictionary in threat_candidates:
			var tpos := Vector2(float(tc["x"]), float(tc["y"]))
			var d: float = hunter_pos.distance_to(tpos)
			if hopo and tc.get("type", "") == "tiger":
				d *= 0.2 # 호포령 중 호랑이 가중치
			if d < min_threat_dist:
				min_threat_dist = d
				best_threat = tc
		if not best_threat.is_empty():
			hunter["target_animal_id"] = best_threat.get("id", -1)
			hunter["target_id"] = best_threat.get("id", -1)
			return best_threat

	# 2순위: 외곽 산악 지형의 야생 짐승 원정 사냥
	if not wild_candidates.is_empty():
		var best_wild: Dictionary = {}
		var min_wild_dist: float = 999999.0
		for wc: Dictionary in wild_candidates:
			var wpos := Vector2(float(wc["x"]), float(wc["y"]))
			var d2: float = hunter_pos.distance_to(wpos)
			if d2 < min_wild_dist:
				min_wild_dist = d2
				best_wild = wc
		if not best_wild.is_empty():
			hunter["target_animal_id"] = best_wild.get("id", -1)
			hunter["target_id"] = best_wild.get("id", -1)
			return best_wild

	hunter["target_animal_id"] = -1
	hunter["target_id"] = -1
	return {}


## 특정 명소(Spot) 에이전트 동기화
func _sync_spot_agents() -> void:
	var active_fishers := agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "fisher")
	var active_washers := agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "washer")

	# 수원천변 낚시꾼 (물가 포인트에 최대 3명까지 자연스럽게 분산 스폰)
	var max_fishers: int = mini(3, _water_banks_cache.size())
	if active_fishers.size() < max_fishers and not _water_banks_cache.is_empty():
		var spot: Dictionary = _water_banks_cache[randi() % _water_banks_cache.size()]
		_add_spot_agent("fisher", spot["pos"], {
			"water_dir": spot["water_dir"],
			"levee": spot.get("levee", false),
			"initial_state": "fishing",
			"initial_timer": randf_range(16.0, 26.0)
		})

	if active_washers.is_empty() and not _water_banks_cache.is_empty():
		# 제방이 있으면 빨래터 자리를 우선(제방 칸 가운데 빨래터가 아닌 곳은 빼고), 없으면 아무 물가나
		var wash_spots: Array = _water_banks_cache.filter(func(sp: Dictionary) -> bool: return sp.get("laundry", false))
		if wash_spots.is_empty():
			wash_spots = _water_banks_cache.filter(func(sp: Dictionary) -> bool: return not sp.get("levee", false))
		if wash_spots.is_empty():
			wash_spots = _water_banks_cache
		var spot2: Dictionary = wash_spots[randi() % wash_spots.size()]
		_add_spot_agent("washer", spot2["pos"], {
			"water_dir": spot2["water_dir"],
			"levee": spot2.get("levee", false),
			"initial_state": "washing",
			"initial_timer": randf_range(18.0, 28.0)
		})

	# 겨울철 수원천변/외곽 평지 연날리기 동자 (kite_flyer) 생태계
	var active_kites := agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "kite_flyer")
	if current_season == "겨울":
		if active_kites.is_empty() and not _water_banks_cache.is_empty():
			var kite_spot: Dictionary = _water_banks_cache[randi() % _water_banks_cache.size()]
			_add_spot_agent("kite_flyer", kite_spot["pos"], {
				"water_dir": kite_spot["water_dir"],
				"anim_seed": randf() * 3.0,
				"fly_timer": randf_range(30.0, 60.0)
			})
	else:
		if not active_kites.is_empty():
			for kt: Dictionary in active_kites:
				kt["is_dead"] = true

	# 여름철 수원천 물장구/멱감기 (water_play) 소년·아이들 생태계
	var active_swimmers := agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "water_play")
	if current_season == "여름":
		if active_swimmers.is_empty() and not _water_banks_cache.is_empty():
			var valid_water_spots: Array[Vector2i] = []
			for b_entry: Dictionary in _water_banks_cache:
				var bp_pos: Vector2i = b_entry["pos"]
				var wdir_v: Vector2 = b_entry["water_dir"]
				var stp := Vector2i(roundi(wdir_v.x), roundi(wdir_v.y))
				if stp == Vector2i.ZERO:
					stp = Vector2i(1, 0)
				var wp_pos: Vector2i = bp_pos + stp
				if grid.in_bounds(wp_pos.x, wp_pos.y):
					var wt: Dictionary = grid.grid[wp_pos.y][wp_pos.x]
					if wt.get("terrain", "") == "water" and not wt.get("is_bridge", false) and not wt.get("is_namsu", false) and wt.get("building", "") == "":
						valid_water_spots.append(wp_pos)
			if not valid_water_spots.is_empty():
				valid_water_spots.shuffle()
				var count_kids: int = mini(3, valid_water_spots.size())
				for kid_i: int in range(count_kids):
					var sp_pt: Vector2i = valid_water_spots[kid_i]
					_add_spot_agent("water_play", sp_pt, {
						"anim_seed": float(kid_i) * 2.3 + randf(),
						"splash_phase": float(kid_i) * 1.5,
						"swim_timer": randf_range(20.0, 40.0)
					})
				# 물놀이 중 간혹 발생하는 실제 익수(drowning) 위기 상황
				var active_drowners := agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "drowning")
				if active_drowners.is_empty() and randf() < 0.4 and valid_water_spots.size() > 1:
					var dr_pt: Vector2i = valid_water_spots[valid_water_spots.size() - 1]
					_add_spot_agent("drowning", dr_pt, {
						"anim_seed": randf() * 4.0,
						"initial_state": "drowning", # PORT-TRACE [구조자 없음]: 예전엔 "state"를 extra에만 넣어 상태가 "work"로 시작 → 구조 로직이 아예 안 돌았다
						"state": "drowning",
						"drown_timer": 35.0,
						"rescued": false,
						"rescuer_id": -1
					})
	else:
		if not active_swimmers.is_empty():
			for sw: Dictionary in active_swimmers:
				sw["is_dead"] = true
		var non_summer_drowners := agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "drowning" and not bool(a.get("extra", {}).get("rescued", false)) and not bool(a.get("ice", false)))
		for nsd: Dictionary in non_summer_drowners:
			nsd["is_dead"] = true

	# PORT-TRACE [겨울 얼음놀이]: 사용자 요청 — "겨울엔 언 물(빙판)에서 썰매 타는 NPC, 빙어낚시. 얼음이 깨져 빠지면 주변에서 구해주게".
	# 언 수원천(겨울엔 물 칸이 빙판으로 그려진다) 위에 썰매 아이(ice_sled: 두 물 칸 사이를 오가며 미끄러짐)와
	# 얼음구멍 낚시꾼(ice_fisher)을 둔다. 이따금 얼음이 쩍 갈라져 빠지면(_ice_break) 익수자(drowning, ice)가 되어 여름 물놀이 익수와
	# 같은 구조 흐름(가까운 백성 → 없으면 달려오는 구조자)을 탄다.
	var active_ice := agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") in ["ice_sled", "ice_fisher"])
	if current_season == "겨울":
		if active_ice.is_empty() and not _water_banks_cache.is_empty():
			var ice_spots := _open_water_spots()
			ice_spots.shuffle()
			var n_sled := 0
			var n_fish := 0
			for ip: Vector2i in ice_spots:
				if n_sled < 2:
					var far := _ice_slide_end(ip)
					if far.x >= 0:
						var sl := _add_spot_agent("ice_sled", ip, {"anim_seed": randf() * 3.0})
						sl["slide_a"] = Vector2(float(ip.x) + 0.5, float(ip.y) + 0.5)
						sl["slide_b"] = Vector2(float(far.x) + 0.5, float(far.y) + 0.5)
						sl["slide_t"] = randf()
						sl["ttl"] = randf_range(70.0, 110.0)
						sl["is_child"] = true
						n_sled += 1
						continue
				if n_fish < 2:
					var fi := _add_spot_agent("ice_fisher", ip, {"anim_seed": randf() * 3.0, "initial_state": "fishing", "initial_timer": randf_range(8.0, 16.0)})
					fi["ttl"] = randf_range(80.0, 120.0)
					n_fish += 1
				if n_sled >= 2 and n_fish >= 2:
					break
	else:
		for ia: Dictionary in active_ice:
			ia["is_dead"] = true

	# 서학 천주교당 (cheonju) 신자 생태계
	var active_catholics := agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "catholic")
	var cheonju_spots: Array[Vector2i] = []
	if grid != null:
		for c_cy: int in range(grid.size):
			for c_cx: int in range(grid.size):
				if grid.grid[c_cy][c_cx].get("cheonju", false):
					cheonju_spots.append(Vector2i(c_cx, c_cy))
	if not cheonju_spots.is_empty():
		if active_catholics.size() < cheonju_spots.size():
			for ch_pos: Vector2i in cheonju_spots:
				var has_c: bool = false
				for ca: Dictionary in active_catholics:
					var ca_extra: Dictionary = ca.get("extra", {})
					if ca_extra.get("home", Vector2i(-1, -1)) == ch_pos:
						has_c = true
						break
				if not has_c:
					var entry_pt: Vector2i = _entry_for(ch_pos)
					_add_spot_agent("catholic", entry_pt, {
						"home": ch_pos,
						"state": "idle",
						"idle_timer": randf_range(5.0, 10.0),
						"is_arrested": false
					})
	else:
		for ca_del: Dictionary in active_catholics:
			ca_del["is_dead"] = true

	# 공사 장비 및 석수 — PORT-TRACE [건설 기간]: "지금 짓고 있는" 성곽·성문·서장대·봉돈 등
	# (GameGrid.is_wall_building)에만 둔다. 공사가 끝나면 인부도 떠나고, 새 현장이 생기면 그리로 옮긴다.
	# 서로 5칸 이상 떨어진 현장 최대 3곳에 각각 성벽 위 석수 + 주변에 거중기·유형거·석수·녹로·감관.
	var crew_types := ["geojunggi", "nongno", "yuheonggeo", "mason", "foreman"]
	agents = agents.filter(func(a: Dictionary) -> bool: return not (a.get("is_spot", false) and a.get("type", "") in crew_types))
	if not _build_cache.is_empty():
		var cands := _build_cache.duplicate()
		cands.shuffle()
		var sites: Array[Vector2i] = []
		for cand: Vector2i in cands:
			var far := true
			for s: Vector2i in sites:
				if absi(s.x - cand.x) + absi(s.y - cand.y) < 5:
					far = false
					break
			if far:
				sites.append(cand)
			if sites.size() >= 3:
				break
		for site: Vector2i in sites:
			_add_spot_agent("mason", site, {"hammer_anim": randf()})
			var free_spots: Array[Vector2i] = []
			for dx: int in [-1, 0, 1]:
				for dy: int in [-1, 0, 1]:
					var sp := Vector2i(site.x + dx, site.y + dy)
					if grid.in_bounds(sp.x, sp.y) and grid.grid[sp.y][sp.x].get("terrain", "") != "water" and grid.grid[sp.y][sp.x].get("building", "") == "":
						free_spots.append(sp)
			free_spots.shuffle()
			var crew: Array = [
				["geojunggi", {"cable_anim": randf() * TAU}],
				["yuheonggeo", {}],
				["mason", {"hammer_anim": randf()}],
				["nongno", {"crane_angle": randf() * TAU}],
				["foreman", {"inspect_timer": 0.0}],
			]
			for n: int in range(mini(crew.size(), free_spots.size())):
				_add_spot_agent(crew[n][0], free_spots[n], crew[n][1])

	_sync_market_agents()

	# 팔달산 나무꾼 (마을이나 장작 수요가 있을 때만)
	var has_village: bool = not _res_cache.is_empty() or not _roads_cache.is_empty()
	var woodcutters := agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "woodcutter")
	if woodcutters.is_empty() and has_village and not _forest_cache.is_empty() and not _roads_cache.is_empty():
		var forest_spot: Vector2i = _forest_cache[randi() % _forest_cache.size()]
		_add_spot_agent("woodcutter", forest_spot, {
			"has_wood": false,
			"target_forest": forest_spot,
			"village_road": _roads_cache[randi() % _roads_cache.size()]
		})

	# 농업 생태계 (농민, 소 쟁기질, 수확물 수레, 허수아비, 가을 참새 떼)
	var farm_types := ["farmer", "ox_plow", "farmer_cart", "scarecrow", "sparrow_flock"]
	if _agr_cache.is_empty():
		agents = agents.filter(func(a: Dictionary) -> bool: return not (a.get("type", "") in farm_types))
	else:
		# 현재 둔전 필지를 점유 중인 셀 집계 (1셀 1인 원칙)
		var occupied_cells: Dictionary = {}
		for a: Dictionary in agents:
			if not a.get("is_dead", false) and (a.get("type", "") in ["farmer", "ox_plow", "farmer_cart"]):
				var ex: Dictionary = a.get("extra", {})
				var cur_f: Vector2i = ex.get("field", a.get("from_tile", Vector2i(int(a.get("x", 0.0)), int(a.get("y", 0.0)))))
				occupied_cells[cur_f] = true

		# 1) 농민 (모내기/김매기/벼베기) - 1셀 1명 분산 배정
		var farmers := agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "farmer")
		var target_farmers: int = clampi(_agr_cache.size(), 2, 10)
		if farmers.size() < target_farmers:
			# 미점유 둔전 셀 후보군 수집
			var available_agrs: Array[Vector2i] = []
			for p_tile: Vector2i in _agr_cache:
				if not occupied_cells.has(p_tile):
					available_agrs.append(p_tile)
			if available_agrs.is_empty():
				available_agrs = _agr_cache.duplicate()
				available_agrs.shuffle()

			for k: int in range(farmers.size(), target_farmers):
				var farm_pos: Vector2i = available_agrs[k % available_agrs.size()]
				occupied_cells[farm_pos] = true

				# 대유둔전 전역을 자유롭게 순회하도록 서로 다른 필지 3~4곳을 타깃으로 구성
				var field_targets: Array[Vector2i] = [farm_pos]
				var step_stride: int = maxi(1, int(float(_agr_cache.size()) / 4.0))
				for s_idx in range(1, 4):
					var next_pos: Vector2i = _agr_cache[(k + s_idx * step_stride) % _agr_cache.size()]
					if not field_targets.has(next_pos):
						field_targets.append(next_pos)

				var home_pos: Vector2i = _house_cache[randi() % _house_cache.size()] if not _house_cache.is_empty() else farm_pos
				var first_field: Vector2i = field_targets[0]
				var fa := _add_spot_agent("farmer", home_pos, {
					"season": current_season,
					"f_timer": randf_range(0.0, 3.0),
					"m_timer": randf_range(0.0, 2.0),
					"field_targets": field_targets,
					"field_idx": 0,
					"field": first_field,
					"home": home_pos,
					"phase": "to_field" if home_pos != first_field else "work",
					"work_timer": randf_range(8.0, 14.0),
					"has_ox": (randf() > 0.4),
				})
				fa["from_tile"] = first_field
				# PORT-TRACE [지붕 위 사람]: 집 칸 한가운데(지붕 위)에서 나타나던 것 → 집 입구(앞길)에서 나와 들로 간다
				var fa_ent: Vector2i = _entry_for(home_pos)
				fa["x"] = float(fa_ent.x) + 0.5
				fa["y"] = float(fa_ent.y) + 0.5

		# 2) 소 쟁기질 (ox_plow) - 농민과 겹치지 않는 빈 둔전 셀에 배정
		var ox_plows := agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "ox_plow")
		var target_ox: int = clampi(int(float(_agr_cache.size()) / 3.0), 1, 3)
		if ox_plows.size() < target_ox:
			var free_ox_agrs: Array[Vector2i] = []
			for p_tile: Vector2i in _agr_cache:
				if not occupied_cells.has(p_tile):
					free_ox_agrs.append(p_tile)
			if free_ox_agrs.is_empty():
				free_ox_agrs = _agr_cache.duplicate()

			for k: int in range(ox_plows.size(), target_ox):
				var ox_pos: Vector2i = free_ox_agrs[k % free_ox_agrs.size()]
				occupied_cells[ox_pos] = true
				_add_spot_agent("ox_plow", ox_pos, {
					"dir": 1.0 if randf() > 0.5 else -1.0,
					"offset": randf_range(-0.2, 0.2),
					"field": ox_pos,
				})

		# 3) 수확물 운반 소달구지 (farmer_cart) - 대유둔전 여기저기를 자유롭게 순회
		var carts := agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "farmer_cart")
		var target_carts: int = clampi(int(float(_agr_cache.size()) / 3.0), 1, 3) if _agr_cache.size() >= 2 else 0
		if not _roads_cache.is_empty() and carts.size() < target_carts:
			for ck: int in range(carts.size(), target_carts):
				var start_farm: Vector2i = _agr_cache[(ck * 3 + randi() % 2) % _agr_cache.size()]
				var dest_town: Vector2i = _res_cache[randi() % _res_cache.size()] if not _res_cache.is_empty() else _roads_cache[randi() % _roads_cache.size()]
				_add_spot_agent("farmer_cart", start_farm, {
					"has_load": true,
					"farm_pt": start_farm,
					"town_pt": dest_town,
					"field": start_farm,
				})

		# 4) 허수아비 (scarecrow)
		var scarecrows := agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "scarecrow")
		var target_sc: int = clampi(int(float(_agr_cache.size()) / 3.0), 1, 3)
		if scarecrows.size() < target_sc:
			for k: int in range(scarecrows.size(), target_sc):
				var sc_pos: Vector2i = _agr_cache[(k * 3 + 1) % _agr_cache.size()]
				_add_spot_agent("scarecrow", sc_pos, {})

		# 5) 가을 수확기 참새 떼 (sparrow_flock)
		var sparrows := agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "sparrow_flock")
		if current_season == "가을" and sparrows.is_empty():
			var center_farm: Vector2i = _agr_cache[randi() % _agr_cache.size()]
			_add_spot_agent("sparrow_flock", center_farm, {
				"center": Vector2(float(center_farm.x) + 0.5, float(center_farm.y) + 0.5),
				"flight_timer": 0.0,
			})

# ---------------------------------------------------------------- 저잣거리·공방 사람들
## PORT-TRACE [저잣거리·공방 NPC]: 사용자 요청 — "저잣거리와 공방을 중심으로 관련된 사람들이 활동하게".
## - 가게 주인(shopkeeper): 가게 앞 길가에 서서 업종에 맞는 호객 소리를 한다(최대 10곳, 서로 떨어진 가게).
## - 장인(artisan): 공방 마당에서 망치질·물레질 등 일한다(최대 6곳).
## - 짐꾼(porter): 지게에 물건을 지고 공방 → 저잣거리 가게로 길을 따라 나른 뒤 돌아간다(최대 3명).
const SHOP_CALLS := {
	"silk": ["고운 비단 들여가시오!", "중국에서 온 공단이오!"], "cotton": ["질 좋은 무명이오!", "겨울 솜옷감 있소!"],
	"myeonju": ["명주 한 필 보시오!", "혼수 명주 들였소!"], "paper": ["장지·창호지 있소!", "과거 볼 시지(試紙)요!"],
	"ramie": ["한산 모시 들어왔소!", "여름엔 모시가 제일이오!"], "fish": ["굴비 사려!", "마른 조기 한 두름이오!"],
	"rice": ["햅쌀 사시오!", "쌀 한 되 퍼 드리리다!"], "veg": ["싱싱한 채소요!", "배추·무 사려!"],
	"meat": ["고기 사려!", "잔칫상 고기 있소!"], "pottery": ["장독 들여가시오!", "새 옹기 구웠소!"],
	"tent": ["골라 골라, 싸게 드리오!", "난전 물건 구경하시오!"], "shoes": ["꽃신 신어 보시오!", "갖신 튼튼하오!"],
	"gukbap": ["뜨끈한 국밥 한 그릇!", "장국밥 말아 드리오!"], "jumak": ["목 좀 축이고 가시오!", "막걸리 한 사발!"],
	"herb": ["감초 들여가시오!", "속 편한 약 지어 드리오!"],
	"yugi": ["안성맞춤 방짜 유기요!", "놋그릇 반짝반짝!"], "bangmul": ["노리개·색실 보고 가시오!", "참빗·비녀 있소!"],
	"fruit": ["달디단 홍시요!", "배·사과 사려!"], "tteok": ["떡 사려, 떡!", "따끈한 인절미요!"],
	"jipsin": ["짚신 한 켤레 서 푼!", "멍석·삼태기 있소!"], "salt": ["서해 천일염이오!", "김장 소금 들이시오!"],
	"tobacco": ["향 좋은 연초요!", "곰방대도 있소!"], "gaekju": ["먼 길 오신 손님, 쉬어 가시오!", "물건 맡기고 가시오!"],
	"book": ["한양서 갓 찍은 서책이오!", "사서삼경 있소!"], "cattle": ["힘 좋은 일소요!", "송아지도 있소, 흥정하시오!"],
	"jeotgal": ["곰삭은 새우젓이오!", "김장 젓갈 들이시오!"], "lumber": ["광주 소나무 목재요!", "대들보감 있소!"],
	"firewood": ["장작 한 짐이오!", "참숯 들여가시오!"],
}
const ARTISAN_LINES := {
	"brass": "쨍쨍! 방짜 유기 두드리는 중이오.", "onggi": "가마 불 조절이 제일 어렵지.", "smith": "뜨거울 때 쳐야 하오!",
	"gat": "대오리 갓 한 채에 보름이 걸린다오.", "shoe": "가죽 신 한 켤레 곧 나오오.", "brush": "족제비 털로 붓을 매오.",
	"bow": "각궁은 소뿔과 대나무로 만든다오.", "hanji": "닥나무 껍질로 종이를 뜨오.",
}

func _trade_at(p: Vector2i) -> String:
	return String(grid.grid[p.y][p.x].get("trade", ""))

## 가게/공방과 맞닿은 길 칸(가게 앞). 없으면 자기 칸.
func _front_road_of(p: Vector2i) -> Vector2i:
	for d: Vector2i in DIRS4:
		var n: Vector2i = p + d
		if _roads_set.has(n):
			return n
	return p

func _pick_spread(cands: Array[Vector2i], n: int, min_gap: int) -> Array[Vector2i]:
	var pool := cands.duplicate()
	pool.shuffle()
	var out: Array[Vector2i] = []
	for c2: Vector2i in pool:
		var ok := true
		for o2: Vector2i in out:
			if absi(o2.x - c2.x) + absi(o2.y - c2.y) < min_gap:
				ok = false
				break
		if ok:
			out.append(c2)
		if out.size() >= n:
			break
	return out

func _sync_market_agents() -> void:
	agents = agents.filter(func(a: Dictionary) -> bool: return not (a.get("is_spot", false) and a.get("type", "") in ["shopkeeper", "artisan"]))
	for sp: Vector2i in _pick_spread(_shop_cache, 10, 2):
		var front := _front_road_of(sp)
		if front == sp:
			continue # 앞길이 없는 가게: 주인이 가게 지붕 위에 서게 된다
		var trade_code: String = _trade_at(sp)
		var ag := _add_spot_agent("shopkeeper", sp, {"trade": trade_code, "shop": sp, "merchant_type": get_merchant_type_for_trade(trade_code)})
		ag["x"] = float(sp.x) + 0.5 + float(front.x - sp.x) * 0.55
		ag["y"] = float(sp.y) + 0.5 + float(front.y - sp.y) * 0.55
		ag["dir"] = Vector2(front - sp)
		ag["state_timer"] = randf_range(2.0, 12.0)
	for wp: Vector2i in _pick_spread(_workshop_cache, 6, 2):
		var front2 := _front_road_of(wp)
		var trade_code2: String = _trade_at(wp)
		var ag2 := _add_spot_agent("artisan", wp, {"trade": trade_code2, "hammer_anim": randf(), "artisan_type": get_artisan_type_for_trade(trade_code2)})
		ag2["x"] = float(wp.x) + 0.5 + float(front2.x - wp.x) * 0.2
		ag2["y"] = float(wp.y) + 0.5 + float(front2.y - wp.y) * 0.2
		ag2["state_timer"] = randf_range(6.0, 20.0)
	# 짐꾼: 공방과 가게가 모두 있을 때만
	var porters := agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "porter")
	if _shop_cache.is_empty() or _workshop_cache.is_empty():
		agents = agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") != "porter")
		return
	for k in range(maxi(0, mini(3, _workshop_cache.size()) - porters.size())):
		var from_w: Vector2i = _workshop_cache[randi() % _workshop_cache.size()]
		var to_s: Vector2i = _shop_cache[randi() % _shop_cache.size()]
		var start := _front_road_of(from_w)
		if start == from_w:
			continue # 앞길 없는 공방에서 나서면 공방 지붕 위를 걷는다
		var ag3 := _add_spot_agent("porter", start, {"trade": _trade_at(from_w), "workshop": from_w, "shop": to_s, "trips": 0})
		ag3["state"] = "to_shop"

func _update_market_agent(a: Dictionary, delta: float) -> void:
	var extra: Dictionary = a.get("extra", {})
	var trade: String = extra.get("trade", "")
	a["state_timer"] = float(a.get("state_timer", 0.0)) - delta
	match String(a["type"]):
		"shopkeeper":
			if float(a["state_timer"]) <= 0.0:
				var lines: Array = SHOP_CALLS.get(trade, ["어서 오시오!"])
				a["bubble_text"] = lines[randi() % lines.size()]
				a["bubble_timer"] = 3.5
				a["state_timer"] = randf_range(10.0, 18.0)
		"artisan":
			extra["hammer_anim"] = fmod(float(extra.get("hammer_anim", 0.0)) + delta * 1.6, 1.0)
			if float(a["state_timer"]) <= 0.0:
				a["bubble_text"] = ARTISAN_LINES.get(trade, "오늘도 일이 많구먼.")
				a["bubble_timer"] = 3.5
				a["state_timer"] = randf_range(16.0, 28.0)
		"porter":
			var goal_tile: Vector2i = extra.get("shop", Vector2i.ZERO) if a["state"] == "to_shop" else extra.get("workshop", Vector2i.ZERO)
			var goal := Vector2(float(goal_tile.x) + 0.5, float(goal_tile.y) + 0.5)
			var cur := Vector2(float(a["x"]), float(a["y"]))
			if cur.distance_to(goal) < 0.35:
				if a["state"] == "to_shop":
					a["state"] = "to_workshop"
					a["bubble_text"] = "%s 물건 들여왔소!" % MarketArt.TRADE_NAMES.get(trade, "공방")
					a["bubble_timer"] = 3.0
				else:
					extra["trips"] = int(extra.get("trips", 0)) + 1
					if int(extra["trips"]) >= 2:
						a["is_dead"] = true # 두 번 나르면 쉬러 간다(다음 동기화 때 새 짐꾼)
					else:
						a["state"] = "to_shop"
						extra["shop"] = _shop_cache[randi() % _shop_cache.size()] if not _shop_cache.is_empty() else goal_tile
			else:
				_move_agent_towards(a, goal, delta, 0.75)

## 인물 등용 여부 확인 헬퍼 (미등용 인물은 필드 및 이벤트 등장 전면 차단)
func _is_named_hired(nid: String) -> bool:
	if sim == null:
		return true
	return sim.retainers.get(nid, false)

## 네임드 NPC 조건부 등장 검사 (어울리는 장소가 만들어지고 조정에 등용되었을 때만 출현)
func _check_named_spawns(delta: float) -> void:
	for k: String in named_cooldowns:
		if named_cooldowns[k] > 0.0:
			named_cooldowns[k] = maxf(0.0, named_cooldowns[k] - delta)

	var current_named: Dictionary = {}
	for a: Dictionary in agents:
		if a.get("is_named", false):
			current_named[a.get("named_id", "")] = true

	# 1. 정약용: 등용 상태 AND (성곽 공사 또는 국책사업 진행 시)
	if not current_named.has("jeong_yakyong") and named_cooldowns["jeong_yakyong"] <= 0.0 and _is_named_hired("jeong_yakyong"):
		if not _wall_cache.is_empty() or (sim and sim.fortress_progress > 0):
			var home := _office_cache[0] if not _office_cache.is_empty() else Vector2i(13, 22)
			var spot := _wall_cache[0] + Vector2i(1, 0) if not _wall_cache.is_empty() else home
			_add_named_agent("jeong_yakyong", spot, home)
			named_cooldowns["jeong_yakyong"] = 80.0

	# 2. 체제공: 등용 상태 AND (행궁/동헌 완공 및 관아 앞 도로 연결 시 가마 타고 출현)
	if not current_named.has("chae_jegong") and named_cooldowns["chae_jegong"] <= 0.0 and _is_named_hired("chae_jegong"):
		if not _office_cache.is_empty() and _roads_cache.size() >= 10:
			var home2 := _office_cache[0]
			var spot2 := _roads_cache[mini(3, _roads_cache.size() - 1)]
			_add_named_agent("chae_jegong", spot2, home2)
			named_cooldowns["chae_jegong"] = 90.0

	# 3. 조심태: 등용 상태 AND (도로망 15칸 이상 형성 시 기마 순시 출현)
	if not current_named.has("jo_simtae") and named_cooldowns["jo_simtae"] <= 0.0 and _is_named_hired("jo_simtae"):
		if _roads_cache.size() >= 15:
			var home3 := _office_cache[0] if not _office_cache.is_empty() else _roads_cache[0]
			var spot3 := _roads_cache[mini(7, _roads_cache.size() - 1)]
			_add_named_agent("jo_simtae", spot3, home3)
			named_cooldowns["jo_simtae"] = 75.0

	# 4. 김홍도: 등용 상태 AND (저잣거리 com 구역 형성 시 돗자리 사생 출현)
	if not current_named.has("kim_hongdo") and named_cooldowns["kim_hongdo"] <= 0.0 and _is_named_hired("kim_hongdo"):
		if not _com_cache.is_empty():
			var home4 := _com_cache[0]
			var spot4 := _com_cache[0]
			if not _water_banks_cache.is_empty():
				spot4 = _water_banks_cache[0]["pos"]
			_add_named_agent("kim_hongdo", spot4, home4)
			named_cooldowns["kim_hongdo"] = 70.0

	# 5. 석수 김바우: 등용 상태 AND (성곽 wall 공사 시 채석장/성돌 조각 출현)
	if not current_named.has("kim_bau") and named_cooldowns["kim_bau"] <= 0.0 and _is_named_hired("kim_bau"):
		if not _wall_cache.is_empty():
			var home5 := _roads_cache[0] if not _roads_cache.is_empty() else Vector2i(10, 15)
			var spot5 := _wall_cache[mini(2, _wall_cache.size() - 1)] + Vector2i(0, 1)
			_add_named_agent("kim_bau", spot5, home5)
			named_cooldowns["kim_bau"] = 60.0

	# 6. 구선복: 등용 상태 AND (서장대/봉돈/성문 건설 시 군기 검열 출현)
	if not current_named.has("gu_seonbok") and named_cooldowns["gu_seonbok"] <= 0.0 and _is_named_hired("gu_seonbok"):
		if not _military_cache.is_empty() or not _gate_cache.is_empty():
			var home6 := _military_cache[0] if not _military_cache.is_empty() else _gate_cache[0]
			_add_named_agent("gu_seonbok", home6, home6)
			named_cooldowns["gu_seonbok"] = 85.0

	# 7. 유한지: 등용 상태 AND (홍예성문 gate 축조 시 현판 휘호 출현)
	if not current_named.has("yu_hanji") and named_cooldowns["yu_hanji"] <= 0.0 and _is_named_hired("yu_hanji"):
		if not _gate_cache.is_empty():
			var home7 := _roads_cache[0] if not _roads_cache.is_empty() else _gate_cache[0]
			var spot7 := _gate_cache[0] + Vector2i(1, 0)
			_add_named_agent("yu_hanji", spot7, home7)
			named_cooldowns["yu_hanji"] = 90.0

	# 8~24. 나머지 17인: 코스(주요 장소 순회) 활동 — NamedNpcs
	_check_route_named_spawns(current_named)

# ============================================================ 네임드 17인: 주요 장소 코스 활동
var _named_place_cache: Dictionary = {} # 장소 종류 → 칸 목록(지도가 바뀌어 캐시를 새로 만들 때 함께 비운다)

func _scan_tiles(codes: Array, plaza_kinds: Array = []) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in range(grid.size):
		for x: int in range(grid.size):
			var t: Dictionary = grid.grid[y][x]
			if t.has("wall_build"):
				continue # 공사 중인 칸은 제외
			var b: String = t.get("building", "")
			if b in codes:
				out.append(Vector2i(x, y))
			elif not plaza_kinds.is_empty() and t.get("plaza") is Dictionary and String((t["plaza"] as Dictionary).get("kind", "")) in plaza_kinds:
				out.append(Vector2i(x, y))
	return out

## 장소 종류(NamedNpcs 머리말 참고) → 지도에 지어진 해당 칸들
func _named_place_tiles(kind: String) -> Array[Vector2i]:
	if _named_place_cache.has(kind):
		return _named_place_cache[kind]
	var out: Array[Vector2i] = []
	match kind:
		"gate":
			out = _gate_cache.duplicate()
		"wall":
			out = _wall_cache.duplicate()
		"com":
			out = _shop_cache.duplicate() if not _shop_cache.is_empty() else _com_cache.duplicate()
		"haenggung":
			out = _office_cache.duplicate()
		"military":
			out = _military_cache.duplicate()
		"patrol":
			out = _patrol_cache.duplicate()
		"workshop":
			out = _workshop_cache.duplicate()
		"farm":
			out = _agr_cache.duplicate()
		"road":
			out = _roads_cache.duplicate()
		"levee":
			out = _levee_cache.duplicate()
		"bank":
			for be: Dictionary in _water_banks_cache:
				out.append(be["pos"])
		"reservoir":
			out = _reservoir_cache.duplicate()
			out.append_array(_scan_tiles(["manseokgeo", "chukmanje"]))
		"seojangdae":
			out = _scan_tiles(["seojangdae"])
		"yeonmudae":
			out = _scan_tiles(["yeonmudae"])
		"hyanggyo":
			out = _scan_tiles(["hyanggyo"])
		"jongnu":
			out = _scan_tiles(["jongnu"])
		"banghwa":
			out = _scan_tiles(["banghwasuryu"])
		"seodang":
			out = _seodang_cache.duplicate()
			out.append_array(_scan_tiles(["seowon"], ["seowon", "seodang"]))
	_named_place_cache[kind] = out
	return out

## 코스의 각 정거장(장소·행동·머무는 시간)을 지금 지도에 맞게 풀어 낸다. 지도에 없는 장소는 건너뛴다.
func _resolve_route(route: Array) -> Array:
	var stops: Array = []
	for step_v in route:
		var step: Dictionary = step_v
		var places: Array = step["place"] if step["place"] is Array else [step["place"]]
		for pk_v in places:
			var tiles: Array[Vector2i] = _named_place_tiles(String(pk_v))
			if tiles.is_empty():
				continue
			var tile: Vector2i = tiles[randi() % tiles.size()]
			var entry: Vector2i = _entry_for(tile)
			if not grid.in_bounds(entry.x, entry.y):
				continue
			stops.append({"place": tile, "entry": entry, "act": String(step["act"]), "secs": float(step["secs"]), "kind": String(pk_v)})
			break
	return stops

## 등용되었고 코스의 장소가 하나라도 지어져 있으면 그 인물을 내보낸다
func _check_route_named_spawns(current_named: Dictionary) -> void:
	for nid: String in NamedNpcs.ids():
		if current_named.has(nid) or float(named_cooldowns.get(nid, 0.0)) > 0.0 or not _is_named_hired(nid):
			continue
		var stops: Array = _resolve_route(NamedNpcs.EXTRA[nid]["route"])
		if stops.is_empty():
			continue
		var first: Vector2i = stops[0]["entry"]
		var ag: Dictionary = _add_named_agent(nid, first, first)
		ag["route_stops"] = stops
		ag["stop_i"] = 0
		ag["tour"] = 0
		ag["state"] = "tour"
		ag["speed"] = 0.8
		named_cooldowns[nid] = randf_range(70.0, 100.0)

## 코스 활동 FSM: 정거장으로 걸어가 → 행동하며 머물다 → 다음 정거장 … 두 바퀴 돌면 돌아간다. 처리했으면 true.
func _update_route_agent(a: Dictionary, delta: float) -> bool:
	if not a.has("route_stops"):
		return false
	var state: String = String(a.get("state", "tour"))
	if state != "tour" and state != "work":
		return false
	var stops: Array = a["route_stops"]
	var i: int = clampi(int(a.get("stop_i", 0)), 0, stops.size() - 1)
	var ex: Dictionary = a["extra"]
	var nid: String = String(a.get("named_id", ""))
	if state == "work":
		a["act_timer"] = float(a.get("act_timer", 0.0)) - delta
		if float(a["act_timer"]) <= 0.0:
			ex.erase("act")
			a.erase("inside")
			i += 1
			if i >= stops.size():
				i = 0
				a["tour"] = int(a.get("tour", 0)) + 1
				if int(a["tour"]) >= 2:
					a["state"] = "leave"
					a["bubble_text"] = String(named_info(nid).get("leave_line", "오늘은 이만 돌아가겠소."))
					a["bubble_timer"] = 4.0
					return true
			a["stop_i"] = i
			a["state"] = "tour"
			a.erase("path")
		return true
	var stop: Dictionary = stops[i]
	var entry: Vector2i = stop["entry"]
	var goal := Vector2(float(entry.x) + 0.5, float(entry.y) + 0.5)
	var cur := Vector2(float(a["x"]), float(a["y"]))
	if cur.distance_to(goal) < 0.5:
		a["state"] = "work"
		a["act_timer"] = float(stop["secs"]) * randf_range(0.85, 1.2)
		ex["act"] = String(stop["act"])
		# PORT-TRACE [행궁 입구 몰림]: 행궁·관아 같은 담장 두른 관청은 입구에 닿으면 안으로 들어간 것(보이지 않음) — 일을 마치면 다시 나온다
		if String(stop.get("kind", "")) == "haenggung":
			a["inside"] = true
			a["bubble_text"] = ""
			a["bubble_timer"] = 0.0
			a["act_timer"] = float(a["act_timer"]) + 4.0
			return true
		var pl: Vector2i = stop["place"]
		var face := Vector2(float(pl.x) + 0.5, float(pl.y) + 0.5) - cur
		if face.length() > 0.1:
			a["dir"] = face.normalized()
		a["bubble_text"] = get_contextual_named_line(nid)
		a["bubble_timer"] = 4.5
	else:
		_move_agent_towards(a, goal, delta, float(a.get("speed", 0.8)))
	return true

func _get_adjacent_roads(p: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d: Vector2i in dirs:
		var np: Vector2i = p + d
		if _roads_set.has(np):
			result.append(np)
	return result

func _process(delta: float) -> void:
	if grid == null:
		return

	if not _dirty_nav_tiles.is_empty():
		var dirty_keys := _dirty_nav_tiles.keys()
		_dirty_nav_tiles.clear()
		_roads_dirty = false
		_update_nav_tiles_local(dirty_keys)
	elif _roads_dirty:
		_roads_dirty = false
		_refresh_caches()
		_sync_spot_agents()
		_sync_wildlife()

	delta *= time_scale
	if delta <= 0.0:
		return # 일시정지: 사람·동물도 멈춘다
	if bell_boost > 0.0:
		bell_boost -= delta
	if bell_ring_t > 0.0:
		bell_ring_t -= delta

	# [저잣거리 공터 POI 이벤트] 경량 타이머 — 화면 밖 오브젝트 풀링 방식으로 분산 처리
	_plaza_event_timer -= delta
	if _plaza_event_timer <= 0.0:
		_plaza_event_timer = randf_range(25.0, 45.0)
		_update_plaza_events()
	if yajo_t > 0.0:
		yajo_t -= delta
	if drill_t >= 0.0:
		drill_t += delta
		# 8초·12초·16초에 포성(포루마다 화염이 엇갈려 터진다)
		var shots := 0
		for st: float in [8.0, 12.0, 16.0]:
			if drill_t >= st:
				shots += 1
		if shots > _drill_shots:
			_drill_shots = shots
			emit_signal("cannon_fired")
		if drill_t > DRILL_LEN:
			drill_t = -1.0
	_manage_haenggung_court(delta)
	_path_budget = 4
	process_path_queue(MAX_PATHS_PER_FRAME)

	var visible_tiles: int = get_visible_tile_count()
	var show_normal_npcs: bool = (visible_tiles <= TILE_LIMIT_NPC_VISIBLE)
	var show_normal_bubbles: bool = (visible_tiles <= TILE_LIMIT_BUBBLE_VISIBLE)
	var cam_rect: Rect2 = get_active_camera_world_rect().grow(96.0)

	# 1. 일반 시민 NPC 처리: 활동(논리 이동)은 항상 수행하되, 눈에만 조건부로 표시 (No Freeze / No Respawn)
	for npc in active_npcs:
		if not is_instance_valid(npc):
			continue

		# 줌 배율이나 화면 밖 여부와 상관없이 논리적 이동과 일상 활동은 끊김 없이 진행!
		npc.update_logical_activity(delta)

		# 세시풍속 참가 또는 특수 개체인지 확인
		if npc.is_participating_in_custom() or npc.is_special():
			npc.visible = true
			npc.set_bubble_enabled(true)
			npc.update_visual_animation(delta)
			continue

		# 일반 시민 가시성 판정 (400칸 이하 & 현재 카메라 뷰포트 안)
		var in_camera: bool = cam_rect.has_point(npc.global_position)
		var should_render_npc: bool = show_normal_npcs and in_camera

		npc.visible = should_render_npc
		if should_render_npc:
			npc.update_visual_animation(delta)
			# 말풍선은 300칸 이하일 때만 허용
			npc.set_bubble_enabled(show_normal_bubbles)
		else:
			npc.set_bubble_enabled(false)

	# 2. 특수 개체(도둑, 순라군, 도적떼, 반란군, 호랑이, 세시풍속) 처리: 화면 배율 무관 상시 표시!
	for special in active_special_entities:
		if not is_instance_valid(special):
			continue
		if special is CanvasItem:
			(special as CanvasItem).visible = true
		if special.has_method("update_logical_activity"):
			special.call("update_logical_activity", delta)
		elif special.has_method("update_logical_step_throttled"):
			special.call("update_logical_step_throttled", delta)
		if special.has_method("set_bubble_enabled"):
			special.call("set_bubble_enabled", true)
		if special.has_method("update_visual_animation"):
			special.call("update_visual_animation", delta)
		elif special.has_method("update_visual_step"):
			special.call("update_visual_step", delta)

	# 맹수(호랑이, 승냥이) 출몰 및 민가 습격 제어
	_manage_predators(delta)

	# 도적(화적 떼) 침략 및 순라군 방어 제어
	_manage_bandits(delta)

	# 평상시 성곽 안쪽 순라군 순찰 제어
	_manage_routine_patrol(delta)

	# 순라청 치안 FSM: 저잣거리 분쟁/소매치기 출동/진압/압송 및 골든타임 검사
	if sunla_manager:
		sunla_manager.update_system(delta, sim, grid, self)
		_sync_sunla_agents()

	# 조선 후기 삼수병 및 기포병 FSM (평시 사열/순시 & 전시 병종별 전술 앵커 배치)
	if military_mgr:
		var siege_pos: Vector2i = siege.target if (siege and siege.state != "") else Vector2i(-1, -1)
		military_mgr.update(self, delta, siege_pos)

	# 화재 발생 및 멸화군 소방 제어
	_manage_fires(delta)
	# 수해(홍수) 위기 대피 및 방재 제어
	_manage_flood_crisis(delta)

	# 사냥꾼(Hunter) 스폰 및 활동 제어
	# PORT-TRACE [사포수 및 사냥꾼]: 조총을 멘 사포수 무리 및 활 사냥꾼
	_manage_saposu(delta)
	_manage_hunters(delta)
	# PORT-TRACE [맹수 패닉]: 맹수 곁 백성이 비명을 지르며 달아나고, 붙잡히면 다쳐서 들것으로 후송
	_manage_panic(delta)

	# 관아: 재판 진행·좀도둑 검거·송사·석방
	_manage_gwana(delta)

	# 도로 위 보행자 스폰 주기적 관리
	_spawn_timer += delta
	if _spawn_timer >= 1.8:
		_spawn_timer = 0.0
		_manage_road_agents()

	# 농번기 대유둔전 농악대(풍물패) 대사습놀이 길거리 이벤트 제어
	_manage_nongak(delta)

	# 야생동물 생태계 주기적 관리 (3초마다)
	_wildlife_timer += delta
	if _wildlife_timer >= 3.5:
		_wildlife_timer = 0.0
		_sync_wildlife()

	# 네임드 NPC 조건부 등장 스케줄러 (5초마다 검사)
	_named_check_timer += delta
	if _named_check_timer >= 5.0:
		_named_check_timer = 0.0
		_check_named_spawns(5.0)

	# 네임드 말풍선 주기적 트리거 (11초 간격)
	_named_bubble_timer += delta
	if _named_bubble_timer >= 11.0:
		_named_bubble_timer = 0.0
		_trigger_random_named_bubble()

	# 스팟 재스폰 타이머
	_spot_spawn_timer += delta
	if _spot_spawn_timer >= 12.0:
		_spot_spawn_timer = 0.0
		_sync_spot_agents()

	# 조선 후기 6대 신분·직업군(중인, 아전, 장인, 보부상, 승군, 백정) 스폰 및 거점 관리
	_professional_timer += delta
	if _professional_timer >= 4.0:
		_professional_timer = 0.0
		_manage_district_professionals(delta)

	# 취객·노인과 손주 등 거리 사람들(3초마다 수 확인)
	StreetLife.update(self, delta)

	# 맵 경계선 이탈자 0.5초 간격 O(1) 유효 좌표 검사 및 자연 디스폰 처리
	_boundary_check_timer += delta
	if _boundary_check_timer >= 0.5:
		_boundary_check_timer = 0.0
		_check_boundary_despawns()

	# 에이전트 업데이트 및 종료자(despawn) 필터링 (화면 밖 Frustum Culling 및 틱 스케줄러 적용)
	var has_dead: bool = false
	var agent_cam_rect: Rect2 = get_active_camera_world_rect().grow(64.0)
	for a: Dictionary in agents:
		var elev: float = 0.0
		var gx: int = int(round(float(a.get("x", 0.0))))
		var gy: int = int(round(float(a.get("y", 0.0))))
		if grid != null and grid.in_bounds(gx, gy):
			elev = float(grid.grid[gy][gx].get("elevation", 0.0))
		var world_pos := Vector2(
			(float(a.get("x", 0.0)) - float(a.get("y", 0.0))) * 32.0,
			(float(a.get("x", 0.0)) + float(a.get("y", 0.0))) * 16.0 - elev * 12.0
		)
		var in_view: bool = agent_cam_rect.has_point(world_pos)
		a["in_view"] = in_view

		if in_view:
			_update_agent(a, delta)
		else:
			# 화면 밖에서는 0.5초마다 논리 좌표만 성큼 이동 (CPU 연산 90% 절약)
			var throttle_timer: float = float(a.get("throttle_timer", 0.0)) + delta
			if throttle_timer >= 0.5:
				_update_agent(a, throttle_timer)
				a["throttle_timer"] = 0.0
			else:
				a["throttle_timer"] = throttle_timer

		if a.get("is_dead", false):
			has_dead = true
	if has_dead:
		agents = agents.filter(func(a: Dictionary) -> bool: return not a.get("is_dead", false))

## [Step 4 & 5 최적화] 활성 카메라 월드 사각형 조회 (Frustum Culling용)
func get_active_camera_world_rect() -> Rect2:
	if CameraLODController.test_override_rect.size != Vector2.ZERO:
		return CameraLODController.test_override_rect
	var vp: Viewport = get_viewport()
	if vp == null:
		return Rect2(-3000.0, -3000.0, 6000.0, 6000.0)
	var cam: Camera2D = vp.get_camera_2d()
	if cam == null:
		var vs := Vector2(vp.get_visible_rect().size)
		return Rect2(Vector2.ZERO, vs)
	var zoom_scale: Vector2 = cam.zoom if cam.zoom != Vector2.ZERO else Vector2.ONE
	var half_size: Vector2 = (vp.get_visible_rect().size / zoom_scale) * 0.5
	var cam_pos: Vector2 = cam.global_position
	return Rect2(cam_pos - half_size, half_size * 2.0)

## [Step 5 최적화] A* 길찾기 비동기 요청 큐 등록
func request_path_async(requester: Variant, start_pos: Vector2i, end_pos: Vector2i, callback: Callable) -> void:
	_path_request_queue.append({
		"requester": requester,
		"start": start_pos,
		"end": end_pos,
		"callback": callback
	})

## [Step 5 최적화] 프레임당 최대 4회 경로 탐색 처리
func process_path_queue(limit: int = MAX_PATHS_PER_FRAME) -> void:
	var processed: int = 0
	while not _path_request_queue.is_empty() and processed < limit:
		var req: Dictionary = _path_request_queue.pop_front()
		var req_node: Variant = req.get("requester", null)
		var cb: Callable = req.get("callback", Callable())

		var valid_requester: bool = true
		if req_node is Object:
			valid_requester = is_instance_valid(req_node)

		if valid_requester and cb.is_valid():
			var dummy_ag: Dictionary = {}
			var path_arr: Array = _find_path(dummy_ag, req["start"], req["end"])
			cb.call(path_arr)
		processed += 1

## 맵 경계선(유효 그리드 바깥) 이탈 NPC 자연 디스폰 처리
func _check_boundary_despawns() -> void:
	if grid == null:
		return
	for a: Dictionary in agents:
		if a.get("is_dead", false) or a.get("fading_out", false):
			continue
		var gx: int = int(floor(float(a.get("x", 0.0))))
		var gy: int = int(floor(float(a.get("y", 0.0))))
		if not grid.is_in_bounds(gx, gy):
			# 유효 그리드 바깥에 도달한 NPC: 다른 고을로 떠난 것으로 판정하여 1초간 페이드 아웃 후 자연 소멸
			a["fading_out"] = true
			a["fade_timer"] = 1.0
			a["fade_duration"] = 1.0
			a["fade_alpha"] = 1.0
			a["bubble_text"] = ""

func _trigger_random_named_bubble() -> void:
	var named_list := agents.filter(func(a: Dictionary) -> bool: return a.get("is_named", false) and a.get("state", "") == "work")
	if named_list.is_empty():
		return
	var target_named: Dictionary = named_list[randi() % named_list.size()]
	var nid: String = target_named.get("named_id", "")
	target_named["bubble_text"] = get_contextual_named_line(nid)
	target_named["bubble_timer"] = 4.5

## 특정 위치 근처의 네임드 NPC 검색 (Inspect 클릭 판정용)
func get_named_npc_near(tile_pos: Vector2, radius: float = 1.0) -> Dictionary:
	for a: Dictionary in agents:
		if a.get("is_named", false):
			var ax: float = float(a.get("x", 0.0))
			var ay: float = float(a.get("y", 0.0))
			var dist := sqrt((ax - tile_pos.x) * (ax - tile_pos.x) + (ay - tile_pos.y) * (ay - tile_pos.y))
			if dist <= radius:
				var nid: String = a.get("named_id", "")
				a["bubble_text"] = get_contextual_named_line(nid)
				a["bubble_timer"] = 5.0
				return a
	return {}

## 특정 위치 근처의 일반 NPC 또는 동물 에이전트 검색 (Inspect 클릭 판정용)
func get_agent_near(tile_pos: Vector2, radius: float = 1.0) -> Dictionary:
	for a: Dictionary in agents:
		if a.get("is_dead", false):
			continue
		var ax: float = float(a.get("x", 0.0))
		var ay: float = float(a.get("y", 0.0))
		var dist := sqrt((ax - tile_pos.x) * (ax - tile_pos.x) + (ay - tile_pos.y) * (ay - tile_pos.y))
		if dist <= radius:
			return a
	return {}

## 농번기(봄~가을) 대유둔전 농악대(풍물패 길놀이) 대사습놀이 길거리 이벤트
func _manage_nongak(delta: float) -> void:
	if current_season not in ["봄", "여름", "가을"]:
		return
	if _agr_cache.size() < 2 or _roads_cache.is_empty():
		return
	_nongak_timer += delta
	if _nongak_timer >= 45.0:
		_nongak_timer = 0.0
		# 둔전 인근 도로 탐색
		var farm_pt: Vector2i = _agr_cache[randi() % _agr_cache.size()]
		var road_pt: Vector2i = _find_nearest_road(farm_pt)
		if road_pt.x >= 0:
			spawn_festival_walker("pungmul_band", road_pt, 40.0, "얼씨구! 대유둔전 풍년 농악 길놀이요!")

func _manage_road_agents() -> void:
	# 마을/주거지(res), 상업지(com), 관아(office) 등 실제 정주 공간이 하나도 없으면 일반 보행자/상인 스폰 전면 금지!
	var has_settlement: bool = (not _res_cache.is_empty() or not _com_cache.is_empty() or not _office_cache.is_empty())
	# PORT-TRACE [문 먼저, 그다음 사람]: 사용자 요청 — "길이 뚫리고 문이 생긴 뒤 저잣거리가 형성되면
	# 그 이후로 사람들이 다녀야 한다". 다 지은 성문 + 저잣거리 구획이 모두 있어야 길손이 오간다.
	var town_open: bool = _open_gate and not _com_cache.is_empty()
	if not has_settlement or not town_open or _roads_cache.is_empty():
		# 마을이 없으면 도로 위 인공 보행자 전부 정리 (야생 동물만 활동)
		agents = agents.filter(func(a: Dictionary) -> bool: return a.get("is_wild", false) or a.get("is_spot", false) or a.get("festival", false) or a.get("siege_unit", false) or a.get("type", "") == "stretcher") # 다친 사람 후송은 남긴다
		return

	var road_agents := agents.filter(func(a: Dictionary) -> bool: return not a.get("is_spot", false) and not a.get("is_wild", false))
	var target_count: int = clampi(int(float(_roads_cache.size()) / 5.0), 2, 30) # PORT-TRACE [성문 고르게]: 22 → 30

	# PORT-TRACE [목적 기반 이동]: 사용자 제보 — "사람들이 행궁 입구 등에 멍하니 몰려 있거나 목적 없이 배회한다".
	# 예전 길손은 아무 길 칸에서 태어나 갈림길마다 무작위로 꺾었다(막다른 길·행궁 앞에서 맴돎). 이제는 태어날 때
	# 역할에 맞는 "출발지 → 목적지" 한 쌍을 정하고, 길 우선 경로(_move_agent_towards)로 가서 목적 건물에 들어가면
	# 사라진다(_update_trip). 역할별 동선:
	#   파발마: 성문 → 행궁 정문 / 상인·수레(보부상): 성문 ↔ 가게, 가게 ↔ 가게(행궁 출입 금지)
	#   장보는 백성·선비·짐꾼: 집 ↔ 가게 / 관리: 행궁 ↔ 순라청·성문 / 포졸: 성문 ↔ 성문·순라청 / 가마: 행궁 ↔ 기와집
	_messenger_timer -= 1.8
	if _messenger_timer <= 0.0 and _haenggung_gate.x >= 0 and not _gate_cache.is_empty():
		_messenger_timer = randf_range(25.0, 40.0)
		_spawn_trip("horse_messenger", _gate_cache[randi() % _gate_cache.size()], _haenggung_gate, "장계(狀啓) 올리오!")
	_spawn_gate_carrier()
	_spawn_cattle_drover()
	if road_agents.size() >= target_count:
		return
	var pop: int = sim.population if sim else 100
	var plans: Array = [] # [type, from, to, 도착 말]

	# 도로와 정상 연결된 가옥 및 상점만 필터링 (고립 타일 스폰 차단)
	var connected_shops: Array[Vector2i] = []
	for sp: Vector2i in _shop_cache:
		if grid == null or grid.is_road_connected(sp.x, sp.y):
			connected_shops.append(sp)

	var connected_houses: Array[Vector2i] = []
	for hp: Vector2i in _house_cache:
		if grid == null or grid.is_road_connected(hp.x, hp.y):
			connected_houses.append(hp)

	if not connected_shops.is_empty():
		var shop_a: Vector2i = connected_shops[randi() % connected_shops.size()]
		var shop_b: Vector2i = connected_shops[randi() % connected_shops.size()]
		if not _gate_cache.is_empty():
			# PORT-TRACE [성문 고르게]: 상가가 몰린 문(장안문 등)으로만 사람이 쏠렸다 → 지금 오가는 길손이 가장 적은 문을 고르고,
			# 그 문 가까운 장터 가게(문 시장)로 간다 — 사대문이 고루 북적이게
			var gt: Vector2i = _quiet_gate()
			var near_shop := _shop_near(gt, connected_shops)
			if near_shop.x >= 0 and randf() < 0.7:
				shop_a = near_shop
			var near_shop_b := _shop_near(gt, connected_shops)
			if near_shop_b.x >= 0 and randf() < 0.7:
				shop_b = near_shop_b
			plans.append(["merchant", gt, shop_a, "물건 들여왔소!"] if randf() < 0.5 else ["merchant", shop_a, gt, ""])
			plans.append(["cart", gt, shop_b, ""])
		else:
			plans.append(["merchant", shop_a, shop_b, ""])
		if not connected_houses.is_empty():
			var home: Vector2i = connected_houses[randi() % connected_houses.size()]
			plans.append(["shopper", home, shop_a, ""] if randf() < 0.6 else ["shopper", shop_a, home, ""])
			plans.append(["carrier", shop_b, home, ""])
			plans.append(["scholar", home, shop_b, ""])
	if _haenggung_gate.x >= 0:
		var pub: Array[Vector2i] = []
		pub.append_array(_patrol_cache)
		pub.append_array(_gate_cache)
		if not pub.is_empty():
			var pt: Vector2i = pub[randi() % pub.size()]
			plans.append(["official", _haenggung_gate, pt, ""] if randf() < 0.5 else ["official", pt, _haenggung_gate, ""])
		if pop >= 150 and not _rich_house_cache.is_empty():
			plans.append(["palanquin", _haenggung_gate, _rich_house_cache[randi() % _rich_house_cache.size()], ""])
	if _gate_cache.size() >= 2 or (not _gate_cache.is_empty() and not _patrol_cache.is_empty()):
		var g1: Vector2i = _gate_cache[randi() % _gate_cache.size()]
		var others: Array[Vector2i] = []
		others.append_array(_gate_cache)
		others.append_array(_patrol_cache)
		others.erase(g1)
		if not others.is_empty():
			plans.append(["guard", g1, others[randi() % others.size()], ""])
	if plans.is_empty():
		return
	var plan: Array = plans[randi() % plans.size()]
	if plan[1] != plan[2]:
		var n_before := agents.size()
		_spawn_trip(plan[0], plan[1], plan[2], plan[3])
		if agents.size() > n_before:
			for gq: Vector2i in [plan[1], plan[2]]:
				if _gate_cache.has(gq):
					agents[agents.size() - 1]["trip_gate"] = gq

## 지금 오가는 길손(trip_gate)이 가장 적은 성문 — 같으면 무작위
func _quiet_gate() -> Vector2i:
	var cnt := {}
	for g0: Vector2i in _gate_cache:
		cnt[g0] = 0
	for a0: Dictionary in agents:
		var tg: Variant = a0.get("trip_gate", null)
		if tg != null and cnt.has(tg):
			cnt[tg] = int(cnt[tg]) + 1
	var pool := _gate_cache.duplicate()
	pool.shuffle()
	var best: Vector2i = pool[0]
	for g1: Vector2i in pool:
		if int(cnt[g1]) < int(cnt[best]):
			best = g1
	return best

## 성문에서 가까운(GateLogistics.MARKET_RADIUS 안) 가게 하나(없으면 (-1,-1))
func _shop_near(gate: Vector2i, shops: Array[Vector2i]) -> Vector2i:
	var near: Array[Vector2i] = []
	for sp: Vector2i in shops:
		if absi(sp.x - gate.x) + absi(sp.y - gate.y) <= GateLogistics.MARKET_RADIUS:
			near.append(sp)
	return near[randi() % near.size()] if not near.is_empty() else Vector2i(-1, -1)

## PORT-TRACE [사대문 물류]: 개통된(지도 끝까지 길이 이어진) 성문마다 그 문의 물자를 진 운반꾼이 지도 끝 길에서 나타나
## 성문 안 특화 시장 가게로 1차 운반하고, 화서문(소금·어물)·팔달문(곡식·가축) 운반꾼은 절반 넘게 십자로 시전까지 가서
## 흥정한 뒤 가게로 들어가 사라진다. _manage_road_agents(1.8초 주기) 안에서 약 5.4초마다 최대 한 명만 만든다.
func _spawn_gate_carrier() -> void:
	_logistics_timer -= 1.8
	if _logistics_timer > 0.0 or grid.logistics == null:
		return
	_logistics_timer = 5.4
	var rts: Array = grid.logistics.connected_routes()
	if rts.is_empty() or _shop_cache.is_empty():
		return
	var live := 0
	for a: Dictionary in agents:
		if a.has("gate_kind"):
			live += 1
	if live >= clampi(rts.size() * 3, 3, 12):
		return
	var r: Dictionary = rts[randi() % rts.size()]
	var kind: String = r["kind"]
	var gp: Vector2i = r["gate"]
	# 1차 목적지: 성문 특화 시장 가게(없으면 성문에서 가장 가까운 가게)
	var market: Array[Vector2i] = []
	var nearest := Vector2i(-1, -1)
	var nd := 999
	for sp: Vector2i in _shop_cache:
		var dd := absi(sp.x - gp.x) + absi(sp.y - gp.y)
		if dd <= GateLogistics.MARKET_RADIUS:
			market.append(sp)
		if dd < nd:
			nd = dd
			nearest = sp
	var first: Vector2i = market[randi() % market.size()] if not market.is_empty() else nearest
	var types: Array = GATE_CARRIERS[kind]
	var atype: String = types[randi() % types.size()]
	var lines: Array = GATE_ARRIVE[kind]
	# 화서문 소금 지게꾼은 염전 소금 창고가 있으면 거기에 먼저 부린다
	if atype == "salt_porter" and _salt_store.x >= 0:
		first = _salt_store + Vector2i(0, 1)
	var ag := _add_road_agent(atype, r["end"])
	ag["trip"] = true
	ag["goal"] = first
	ag["arrive_line"] = lines[randi() % lines.size()]
	ag["gate_kind"] = kind
	ag["trip_limit"] = 160.0
	# 2차 목적지: 십자로 시전(화서·팔달 물자는 60%, 나머지 25%)
	var hub: Vector2i = grid.logistics.hub
	if hub.x >= 0 and randf() < (0.6 if kind in ["hwaseo", "paldal"] else 0.25):
		var best := Vector2i(-1, -1)
		var bd := 999
		for sp2: Vector2i in _shop_cache:
			var d2 := absi(sp2.x - hub.x) + absi(sp2.y - hub.y)
			if d2 < bd and sp2 != first:
				bd = d2
				best = sp2
		if best.x >= 0 and bd <= GateLogistics.HUB_RADIUS:
			ag["next_goals"] = [best]

## PORT-TRACE [관아·옥사 2x2]: 죄인을 붙잡으면(화적 격퇴·소굴 토벌·좀도둑) 포졸이 오랏줄에 묶어 가장 가까운
## 관아로 압송한다(길손 trip 재사용). 도착하면 마당에서 문초(_start_trial). 관아가 없거나 압송 행렬이 이미 셋이면 false.
func capture_criminal(from: Vector2i, kind: String) -> bool:
	if _gwana_cache.is_empty():
		return false
	var live := 0
	for a: Dictionary in agents:
		if a.has("escort"):
			live += 1
	if live >= 3:
		return false
	var best: Vector2i = _gwana_cache[0]
	for gw: Vector2i in _gwana_cache:
		if absi(gw.x - from.x) + absi(gw.y - from.y) < absi(best.x - from.x) + absi(best.y - from.y):
			best = gw
	from = Vector2i(clampi(from.x, 0, grid.size - 1), clampi(from.y, 0, grid.size - 1))
	var ag := _add_road_agent("prisoner_escort", from)
	ag["trip"] = true
	ag["goal"] = best
	ag["arrive_line"] = ""
	ag["escort"] = kind
	ag["trip_limit"] = 160.0
	ag["speed"] = 0.8
	ag["bubble_text"] = "오랏줄 받아라! 관아로 가자!" if kind == "bandit" else "이 좀도둑놈, 딱 걸렸다!"
	ag["bubble_timer"] = 3.0
	return true

func _start_trial(gw: Vector2i, kind: String) -> void:
	if not grid.in_bounds(gw.x, gw.y) or grid.grid[gw.y][gw.x]["building"] != "gwana":
		return
	var t: Dictionary = grid.grid[gw.y][gw.x]
	if float(t.get("gw_trial", 0.0)) > 0.0 and String(t.get("gw_kind", "")) != "lawsuit":
		# 이미 문초 중이면 곧장 옥에 가둔다
		t["gw_prisoners"] = mini(6, int(t.get("gw_prisoners", 0)) + 1)
		return
	t["gw_trial"] = 22.0 if kind == "bandit" else 15.0
	t["gw_kind"] = kind
	t["gw_trial_len"] = float(t["gw_trial"])
	if kind == "bandit" and court != null:
		court.emit_signal("notice", "붙잡힌 화적을 관아로 압송해 사또가 마당에서 문초합니다. 죄인은 옥사에 갇힙니다.")

## 관아마다 재판 남은 시간 카운트다운(관아 수만큼만 — 보통 한두 곳), 가끔 좀도둑 검거·백성 송사·죄수 석방
func _manage_gwana(delta: float) -> void:
	if _gwana_cache.is_empty():
		return
	for gw: Vector2i in _gwana_cache:
		var t: Dictionary = grid.grid[gw.y][gw.x]
		var trial_rem := float(t.get("gw_trial", 0.0))
		if trial_rem > 0.0:
			trial_rem -= delta
			t["gw_trial"] = trial_rem
			if trial_rem <= 0.0 and String(t.get("gw_kind", "")) in ["bandit", "thief"]:
				t["gw_prisoners"] = mini(6, int(t.get("gw_prisoners", 0)) + 1) # 문초가 끝나면 옥에 가둔다
	# 좀도둑: 장터가 있으면 이따금 포졸이 붙잡아 온다
	_thief_timer -= delta
	if _thief_timer <= 0.0:
		_thief_timer = randf_range(80.0, 140.0)
		if not _shop_cache.is_empty():
			capture_criminal(_shop_cache[randi() % _shop_cache.size()], "thief")
	# 송사: 재판이 없는 관아에서 백성 둘이 다툼을 아뢴다
	_lawsuit_timer -= delta
	if _lawsuit_timer <= 0.0:
		_lawsuit_timer = randf_range(35.0, 60.0)
		var gw2: Vector2i = _gwana_cache[randi() % _gwana_cache.size()]
		var t2: Dictionary = grid.grid[gw2.y][gw2.x]
		if float(t2.get("gw_trial", 0.0)) <= 0.0:
			t2["gw_trial"] = 14.0
			t2["gw_trial_len"] = 14.0
			t2["gw_kind"] = "lawsuit"
	# 형기를 마친 죄수 석방
	_release_timer -= delta
	if _release_timer <= 0.0:
		_release_timer = 90.0
		for gw3: Vector2i in _gwana_cache:
			var t3: Dictionary = grid.grid[gw3.y][gw3.x]
			if int(t3.get("gw_prisoners", 0)) > 0 and randf() < 0.35:
				t3["gw_prisoners"] = int(t3["gw_prisoners"]) - 1

## PORT-TRACE [수원 쇠전 3x3]: 쇠전이 있으면 약 18초마다(동시 2행렬까지) 소몰이꾼이 팔달문 대로로 소를 몰고 들어와
## 쇠전 울타리 안으로 들어간다. 팔달문 바깥 길이 지도 끝까지 이어졌으면 지도 끝에서, 아니면 성문 바로 바깥에서 출발.
func _spawn_cattle_drover() -> void:
	if _cattle_yard.x < 0:
		return
	_cattle_timer -= 1.8
	if _cattle_timer > 0.0:
		return
	_cattle_timer = 18.0
	var live := 0
	for a: Dictionary in agents:
		if a.get("cattle_drover", false):
			live += 1
	if live >= 2 or grid.logistics == null:
		return
	grid.logistics.refresh()
	var start := Vector2i(-1, -1)
	for r: Dictionary in grid.logistics.routes:
		if r["kind"] == "paldal":
			start = r["end"] if r["connected"] else _outside_of_gate(r["gate"])
			break
	if start.x < 0:
		return
	var ag := _add_road_agent("ox_driver", start)
	ag["trip"] = true
	ag["goal"] = _cattle_yard + Vector2i(1, 1)
	ag["arrive_line"] = ["삼남에서 좋은 소 몰고 왔소!", "이랴~ 쇠전 다 왔다!", "일소 두 마리 들어갑니다!"][randi() % 3]
	ag["cattle_drover"] = true
	ag["gate_kind"] = "paldal"
	ag["trip_limit"] = 160.0

## 성문 바깥쪽 길 칸(성 밖에서 들어오는 길손의 출발점). 없으면 성문 칸 그대로.
func _outside_of_gate(g: Vector2i) -> Vector2i:
	for d: Vector2i in DIRS4:
		var n: Vector2i = g + d
		if _roads_set.has(n) and grid.grid[n.y][n.x]["terrain"] == "outside":
			return n
	return g

## 출발지(건물·성문·길) 칸에서 나와 목적지 칸까지 길을 따라 가는 길손 하나
func _spawn_trip(kind: String, from: Vector2i, to: Vector2i, arrive_line: String) -> void:
	# [장용영 병사 행동 교정] 장용영 병사 및 정규군이 일반 상점(MARKET_SHOP)이나 민가를 목적지로 삼는 것을 원천 차단!
	if kind in ["jangyongyeong_soldier", "posu", "sasu", "salsu", "gipo"]:
		if to in _shop_cache or to in _house_cache:
			return

	if from in _gate_cache:
		from = _outside_of_gate(from) # 성 밖에서 성문을 지나 들어온다
	var ag := _add_road_agent(kind, from)
	ag["trip"] = true
	ag["goal"] = to
	ag["arrive_line"] = arrive_line
	if kind == "horse_messenger":
		ag["bubble_text"] = "파발이오! 길을 비키시오!"
		ag["bubble_timer"] = 3.0

## 목적지까지 걸어가 건물에 들어가면 사라진다(도착 말이 있으면 잠시 말하고). 길을 못 찾으면 잠시 뒤 포기.
func _update_trip(a: Dictionary, delta: float) -> void:
	if a.get("state", "") == "arrived":
		a["state_timer"] = float(a.get("state_timer", 0.0)) - delta
		if float(a["state_timer"]) <= 0.0:
			a["is_dead"] = true
		return
	if a.get("state", "") == "trading":
		# 경유지(성문 특화 시장)에서 물건을 부리고 흥정한 뒤 다음 목적지(십자로 시전)로
		a["state_timer"] = float(a.get("state_timer", 0.0)) - delta
		if float(a["state_timer"]) <= 0.0:
			var nx: Array = a.get("next_goals", [])
			a["goal"] = nx.pop_front()
			a["next_goals"] = nx
			a["state"] = "walk"
			a["trip_age"] = 0.0
			if nx.is_empty():
				a["arrive_line"] = HUB_LINES[randi() % HUB_LINES.size()]
		return
	var g: Vector2i = a["goal"]
	var goal := Vector2(float(g.x) + 0.5, float(g.y) + 0.5)
	var cur := Vector2(float(a["x"]), float(a["y"]))
	var c_dist_goal: float = maxf(absf(cur.x - goal.x), absf(cur.y - goal.y))
	# 3칸 근접 도달 판정 (Chebyshev dist <= 3.0 시 목적지 상점/마당 진입 및 거래)
	# PORT-TRACE [행궁 입구 몰림]: 행궁(7x7)처럼 큰 건물은 목적지(가운데)에서 입구 길까지 4칸 넘게 떨어져 "3칸 근접" 도착이 끝내
	# 안 되고, 건물 칸엔 못 들어가니 입구 앞에 90초씩 몰려 서 있었다 → 그 건물의 입구 칸(또는 바로 옆)에 오면 들어간 것으로 본다.
	if not a.has("goal_entry") or a.get("goal_entry_of", Vector2i(-9, -9)) != g:
		a["goal_entry"] = _entry_for(g)
		a["goal_entry_of"] = g
	var ge: Vector2i = a["goal_entry"]
	var at_entry := maxf(absf(cur.x - (float(ge.x) + 0.5)), absf(cur.y - (float(ge.y) + 0.5))) <= 1.0
	if cur.distance_to(goal) < 0.35 or c_dist_goal <= 3.0 or at_entry:
		if a.has("escort"):
			_start_trial(g, String(a["escort"]))
		var line: String = a.get("arrive_line", "")
		var nxt: Array = a.get("next_goals", [])
		if not nxt.is_empty():
			a["bubble_text"] = line
			a["bubble_timer"] = 2.0
			a["state"] = "trading"
			a["state_timer"] = 2.2
			return
		if line != "":
			a["bubble_text"] = line
			a["bubble_timer"] = 1.5
			a["state"] = "arrived"
			a["state_timer"] = 1.2
		else:
			a["is_dead"] = true
		return
	# 어염로 운반꾼: 생선 행상은 이따금 외치고, 소금 지게꾼은 땀을 닦으며 한숨
	if a.get("bubble_timer", 0.0) <= 0.0 and randf() < delta * 0.07:
		match String(a.get("type", "")):
			"fish_peddler":
				a["bubble_text"] = ["싱싱한 조기 사시오!", "갓 올라온 굴비요~", "새우젓 있소, 새우젓!"][randi() % 3]
				a["bubble_timer"] = 2.5
			"salt_porter":
				a["bubble_text"] = ["어이구, 소금 짐 무겁다…", "후~ 땀 좀 닦고 가세.", "서해 천일염이오!"][randi() % 3]
				a["bubble_timer"] = 2.5
	a["trip_age"] = float(a.get("trip_age", 0.0)) + delta
	if float(a["trip_age"]) > float(a.get("trip_limit", 90.0)):
		a["is_dead"] = true # 너무 오래 헤매면(길이 끊김 등) 사라진다 — 한곳에 쌓이지 않게
		return
	_move_agent_towards(a, goal, delta, float(a.get("speed", 1.0)))

func _update_agent(a: Dictionary, delta: float) -> void:
	# 맵 경계선 이탈자 페이드 아웃 라이프사이클 처리
	if a.get("fading_out", false):
		var ft: float = float(a.get("fade_timer", 1.0)) - delta
		a["fade_timer"] = ft
		var dur: float = float(a.get("fade_duration", 1.0))
		a["fade_alpha"] = clampf(ft / dur, 0.0, 1.0)
		if ft <= 0.0:
			a["is_dead"] = true
			return

	# 수원천 물 타일 진입 제약: water_play(물놀이)를 제외한 모든 일반 NPC/가축의 물속 보행 원천 차단
	if not a.get("is_dead", false):
		var cur_gx: int = int(floor(float(a.get("x", 0.0))))
		var cur_gy: int = int(floor(float(a.get("y", 0.0))))
		if grid != null and grid.in_bounds(cur_gx, cur_gy):
			var cur_tile: Dictionary = grid.grid[cur_gy][cur_gx]
			if cur_tile.get("terrain", "") == "water" and not cur_tile.get("is_bridge", false) and not cur_tile.get("is_namsu", false) and cur_tile.get("building", "") != "levee":
				if a.get("type", "") not in ["water_play", "drowning", "ice_sled", "ice_fisher"]:
					var nr_pos: Vector2i = _find_nearest_road(Vector2i(cur_gx, cur_gy))
					if nr_pos.x >= 0:
						a["x"] = float(nr_pos.x) + 0.5
						a["y"] = float(nr_pos.y) + 0.5
						a["from_tile"] = nr_pos
						a["to_tile"] = nr_pos
						a.erase("path")

	a["anim"] = a.get("anim", 0.0) + delta * 5.0

	var btimer: float = a.get("bubble_timer", 0.0)
	if btimer > 0.0:
		btimer -= delta
		a["bubble_timer"] = btimer
		if btimer <= 0.0:
			a["bubble_text"] = ""
	if String(a.get("bubble_text", "")) != "":
		a["last_line"] = a["bubble_text"] # 살피기 팝업에 "방금 한 말"로

	# 익수자 구조 작업 중인 백성(rescuer) FSM
	if a.get("state", "") == "rescuing":
		var r_target_id: int = int(a.get("rescue_target_id", -1))
		var r_bank: Vector2i = a.get("rescue_bank_pt", Vector2i(-1, -1))
		var r_target: Dictionary = {}
		for cand_r: Dictionary in agents:
			if cand_r["id"] == r_target_id and not cand_r.get("is_dead", false):
				r_target = cand_r
				break
		if r_target.is_empty():
			a["state"] = "walk"
		else:
			var bank_v := Vector2(float(r_bank.x) + 0.5, float(r_bank.y) + 0.5)
			var cur_rv := Vector2(float(a["x"]), float(a["y"]))
			if cur_rv.distance_to(bank_v) > 0.45:
				_move_agent_towards(a, bank_v, delta, 1.2)
			else:
				# 물가에 도착! 손/장대/밧줄 내미는 구조 모션
				a["x"] = bank_v.x
				a["y"] = bank_v.y
				var r_time: float = float(a.get("rescue_time", 3.5)) - delta
				a["rescue_time"] = r_time
				if r_time <= 0.0:
					# 구조 성공! 익수자를 물가 육지로 끌어올림
					r_target["x"] = a["x"]
					r_target["y"] = a["y"]
					r_target["state"] = "saved"
					r_target["bubble_text"] = "콜록콜록... 살려주셔서 고맙소!"
					r_target["bubble_timer"] = 3.5
					r_target["save_timer"] = 4.0
					a["state"] = "walk"
					a["bubble_text"] = "휴우, 무사해서 정말 다행이오!"
					a["bubble_timer"] = 3.0
		return

	# Anti-Stuck (고립 방지): 이동 중 3초 이상 갇힌 NPC 감지 시 최근접 도로 타일로 텔레포트 리스폰
	if not a.get("is_wild", false) and not a.get("is_dead", false) and not a.get("is_spot", false) and not a.get("street_folk", false) and a.get("state", "walk") != "idle":
		var cur_pos := Vector2i(int(floor(a.get("x", 0.0))), int(floor(a.get("y", 0.0))))
		var last_pos: Vector2i = a.get("stuck_last_pos", cur_pos)
		if cur_pos == last_pos:
			var st_timer: float = float(a.get("stuck_timer", 0.0)) + delta
			a["stuck_timer"] = st_timer
			if st_timer >= 3.0:
				a["stuck_timer"] = 0.0
				var nr: Vector2i = _find_nearest_road(cur_pos)
				if nr.x >= 0:
					a["x"] = float(nr.x) + 0.5
					a["y"] = float(nr.y) + 0.5
					a["from_tile"] = nr
					a["to_tile"] = nr
					a.erase("path")
		else:
			a["stuck_last_pos"] = cur_pos
			a["stuck_timer"] = 0.0

	# PORT-TRACE [멈춰 선 길손]: 목적지(행궁 문 등) 앞에서 길이 막혀 12초 넘게 거의 움직이지 못한 길손·백성은 들어간 셈 치고 사라진다
	# (서 있는 사람이 걷는 사람보다 많아 거리가 활기 없어 보이던 문제)
	var lt: String = String(a.get("type", ""))
	if (a.get("trip", false) or lt.begins_with("commoner") or lt.begins_with("elder_commoner") or lt.begins_with("yangban") or lt in ["shopper", "carrier", "merchant", "official", "scholar"]) 			and not a.get("is_spot", false) and not a.get("is_named", false) and not a.get("festival", false) and String(a.get("state", "")) not in ["idle", "trading", "arrived", "rescuing", "shelter_in_house"]:
		var lcur := Vector2(float(a.get("x", 0.0)), float(a.get("y", 0.0)))
		var lp: Vector2 = a.get("linger_p", lcur)
		if lcur.distance_to(lp) > 0.3:
			a["linger_p"] = lcur
			a["linger_t"] = 0.0
		else:
			a["linger_p"] = lp
			a["linger_t"] = float(a.get("linger_t", 0.0)) + delta
			if float(a["linger_t"]) > 12.0:
				a["is_dead"] = true
				return

	# 호랑이 피신은 직업 순환보다 먼저(직업인은 아래 직업 갱신으로 빠져 피신처 문 앞에 서 있기만 했다)
	if a.get("is_professional", false) and (a.get("tiger_sheltered", false) or a.get("state", "") in ["shelter_in_house", "hidden_in_shelter"]):
		_update_shelter_agent(a, delta)
		return

	# 조선 후기 6대 신분·직업군(중인, 아전, 장인, 보부상, 승군, 백정) 순환 FSM 업데이트
	if a.get("is_professional", false):
		_update_professional_agent(a, delta)
		return

	# 사냥꾼, 맹수, 토벌대 에이전트 업데이트
	var atype: String = a.get("type", "")
	if a.get("siege_unit", false):
		if siege:
			siege.update_unit(a, delta)
		else:
			a["is_dead"] = true
		return
	if atype == "saposu":
		_update_saposu(a, delta)
		return
	# 호랑이 출현 시 민가(집)로 대피 및 은신 FSM
	if a.get("tiger_sheltered", false) or a.get("state", "") in ["shelter_in_house", "hidden_in_shelter"]:
		_update_shelter_agent(a, delta)
		return

	if float(a.get("panic_t", 0.0)) > 0.0:
		# 맹수를 피해 반대쪽으로 달아남(끝나면 원래 하던 일로)
		a["panic_t"] = float(a["panic_t"]) - delta
		var cur := Vector2(float(a["x"]), float(a["y"]))
		var away: Vector2 = (cur - (a.get("flee_from", cur) as Vector2)).normalized()
		if away == Vector2.ZERO:
			away = Vector2.RIGHT
		_move_agent_towards(a, cur + away * 3.0, delta, 1.8)
		a.erase("path")
		return
	# PORT-TRACE [거리 사람들의 정체성]: 취객·부축하는 이웃·노인과 손주
	if a.get("street_folk", false):
		StreetLife.update_agent(self, a, delta)
		return
	if atype == "hunter":
		_update_hunter(a, delta)
		return
	if atype in ["tiger", "wolf"]:
		_update_predator(a, delta)
		return
	if atype in ["chakhogapsa", "beater", "marksman", "bait"]:
		_update_expedition_agent(a, delta)
		return

	# 도적 및 순라군, 장용영 정예 요격군 에이전트 업데이트
	if atype == "bandit":
		_update_bandit(a, delta)
		return
	if atype == "patrol_soldier":
		_update_patrol_soldier(a, delta)
		return
	if atype == "jangyongyeong_soldier":
		_update_jangyongyeong_soldier(a, delta)
		return
	if atype == "firefighter_soldier":
		_update_firefighter_soldier(a, delta)
		return
	if atype == "bucket_volunteer":
		_update_bucket_volunteer(a, delta)
		return
	if atype == "flood_sandbag":
		_update_flood_sandbag(a, delta)
		return
	if atype == "flood_refugee":
		_update_flood_refugee(a, delta)
		return
	if atype == "fire_panic":
		_update_fire_panic(a, delta)
		return
	if atype in ["posu", "sasu", "salsu", "gipo"]:
		return # 삼수병 및 기포병은 military_mgr에서 그룹 FSM으로 제어

	# 산짐승(야생동물) 업데이트
	if a.get("is_wild", false):
		_update_wild_animal(a, delta)
		return

	# 네임드 에이전트 업데이트
	if a.get("is_named", false):
		_update_named_agent(a, delta)
		return

	# 저잣거리·공방 사람들
	if atype in ["shopkeeper", "artisan", "porter"]:
		_update_market_agent(a, delta)
		return

	# PORT-TRACE [장마당·세시풍속]: 들것(석전 부상자)은 목적지까지 가서 사라지고, 풍물패·황소 퍼레이드는
	# 정해진 시간 동안 일반 길손처럼 길을 따라 돌다가(아래 도로 보행 로직) 흩어진다.
	if atype == "stretcher":
		# PORT-TRACE [환자 후송]: 약방·행궁에 닿으면 6초 동안 붕대 감고 침 놓는 치료 장면(state "treat") 뒤 사라짐
		if a.get("state", "") == "treat":
			a["state_timer"] = float(a.get("state_timer", 0.0)) - delta
			if float(a["state_timer"]) <= 0.0:
				a["is_dead"] = true
			return
		var tg: Vector2i = (a.get("extra", {}) as Dictionary).get("target", Vector2i.ZERO)
		var goal := Vector2(float(tg.x) + 0.5, float(tg.y) + 0.5)
		var curs := Vector2(float(a["x"]), float(a["y"]))
		if curs.distance_to(goal) < 0.4 or _entry_for(tg) == Vector2i(int(floor(curs.x)), int(floor(curs.y))):
			a["state"] = "treat"
			a["state_timer"] = 6.0
			a["bubble_text"] = "의원이 침을 놓고 상처를 싸매는구나."
			a["bubble_timer"] = 3.0
		else:
			_move_agent_towards(a, goal, delta, 0.7)
		return
	if a.get("festival", false):
		a["ttl"] = float(a.get("ttl", 0.0)) - delta
		if float(a["ttl"]) <= 0.0:
			a["is_dead"] = true
			return
		if float(a.get("bubble_timer", 0.0)) <= 0.0 and randf() < delta * 0.15:
			a["bubble_text"] = a.get("chant", "")
			a["bubble_timer"] = 3.0

	# 고정 명소(Spot) 및 특수 에이전트 업데이트
	if a.get("is_spot", false) or atype in ["drowning", "catholic", "water_play"]:
		_update_spot_agent(a, delta)
		return

	# 목적지가 있는 길손(파발마·상인·백성·관리 등)
	if a.get("trip", false):
		_update_trip(a, delta)
		return

	# 도로 위 일반 보행자
	StreetLife.chatter(a, delta) # 성별·나이·신분에 맞는 혼잣말(가끔)
	var prog: float = a.get("progress", 1.0)
	var from_p: Vector2i = a.get("from_tile", Vector2i(int(a["x"]), int(a["y"])))
	var to_p: Vector2i = a.get("to_tile", from_p)

	if a.get("state", "walk") == "idle":
		var itimer: float = a.get("state_timer", 0.0) - delta
		a["state_timer"] = itimer
		if itimer <= 0.0:
			a["state"] = "walk"
		return

	if prog >= 1.0:
		from_p = to_p
		a["from_tile"] = from_p
		a["x"] = float(from_p.x) + 0.5
		a["y"] = float(from_p.y) + 0.5

		if randf() < 0.15 and a.get("type", "") in ["shopper", "merchant", "scholar"]:
			a["state"] = "idle"
			a["state_timer"] = randf_range(1.5, 3.0)
			return

		var adj: Array[Vector2i] = _get_adjacent_roads(from_p)
		if adj.is_empty():
			a["to_tile"] = from_p
			a["progress"] = 1.0
			return

		var best_next: Vector2i = adj[0]
		var cur_dir: Vector2 = a.get("dir", Vector2.RIGHT)
		var candidates: Array[Vector2i] = []
		for np: Vector2i in adj:
			var dvec := Vector2(np.x - from_p.x, np.y - from_p.y)
			if dvec.dot(cur_dir) > 0.1:
				candidates.append(np)

		if not candidates.is_empty() and randf() < 0.75:
			best_next = candidates[randi() % candidates.size()]
		else:
			best_next = adj[randi() % adj.size()]

		a["to_tile"] = best_next
		a["dir"] = Vector2(best_next.x - from_p.x, best_next.y - from_p.y).normalized()
		a["progress"] = 0.0
	else:
		var spd: float = a.get("speed", 1.0)
		prog += spd * delta
		a["progress"] = clampf(prog, 0.0, 1.0)
		var fx := float(from_p.x) + 0.5
		var fy := float(from_p.y) + 0.5
		var tx := float(to_p.x) + 0.5
		var ty := float(to_p.y) + 0.5
		a["x"] = lerpf(fx, tx, a["progress"])
		a["y"] = lerpf(fy, ty, a["progress"])

## 야생동물(산짐승) 상태 머신 (배회 -> 풀뜯기/사냥 -> 배회)
func _update_wild_animal(a: Dictionary, delta: float) -> void:
	var cur_pos := Vector2(float(a.get("x", 0.0)), float(a.get("y", 0.0)))
	var on_screen: bool = is_world_pos_on_screen(cur_pos)
	if on_screen:
		a["anim"] = float(a.get("anim", 0.0)) + delta * 2.8
	# 화면 밖일 경우 추가 도트 애니메이션 처리 동결 (Freeze)

	var atype: String = a.get("type", "")

	if atype == "tiger":
		var tx: float = a.get("to_x", 3.0)
		var ty: float = a.get("to_y", 3.0)
		var tdx: float = tx - a["x"]
		var tdy: float = ty - a["y"]
		var tdist: float = sqrt(tdx * tdx + tdy * tdy)
		if tdist < 0.2:
			a["to_x"] = clampf(a["x"] + randf_range(-1.8, 1.8), 1.0, 5.0)
			a["to_y"] = clampf(a["y"] + randf_range(-1.8, 1.8), 1.0, 6.0)
		else:
			_move_agent_towards(a, Vector2(float(a["x"]) + tdx, float(a["y"]) + tdy), delta, float(a["speed"])) # PORT-TRACE [길찾기]
		return

	var stimer: float = a.get("state_timer", 0.0) - delta
	a["state_timer"] = stimer

	if a.get("state", "wander") == "idle":
		if stimer <= 0.0:
			a["state"] = "wander"
			a["state_timer"] = randf_range(3.5, 7.0)
			# 새로운 목적지 타일 설정
			var cur_x: int = clampi(int(round(float(a["x"]))), 0, grid.size - 1)
			var cur_y: int = clampi(int(round(float(a["y"]))), 0, grid.size - 1)
			var nx: int = clampi(cur_x + randi_range(-2, 2), 1, grid.size - 2)
			var ny: int = clampi(cur_y + randi_range(-2, 2), 1, grid.size - 2)
			if _tile_walkable(grid.grid[ny][nx]): # PORT-TRACE [길찾기]: 물·건물 칸은 배회 목적지로 고르지 않는다
				a["target_x"] = float(nx) + 0.5
				a["target_y"] = float(ny) + 0.5
	else:
		# 배회(wander) 이동
		var tg_x: float = a.get("target_x", a["x"])
		var tg_y: float = a.get("target_y", a["y"])
		var w_dx: float = tg_x - a["x"]
		var w_dy: float = tg_y - a["y"]
		var w_dist: float = sqrt(w_dx * w_dx + w_dy * w_dy)
		if w_dist < 0.2 or stimer <= 0.0:
			a["state"] = "idle"
			a["state_timer"] = randf_range(2.0, 4.5)
		else:
			var spd: float = a.get("speed", 0.6)
			_move_agent_towards(a, Vector2(float(a["x"]) + w_dx, float(a["y"]) + w_dy), delta, spd) # PORT-TRACE [길찾기]

## 네임드 NPC 상태 머신 (활동 -> 퇴근 루틴 -> 거소 입청 despawn)
func _update_named_agent(a: Dictionary, delta: float) -> void:
	var nid: String = a.get("named_id", "")
	var ninfo: Dictionary = named_info(nid)
	var state: String = a.get("state", "work")

	# 미등용 인물 필드 활동 즉시 퇴거
	if not _is_named_hired(nid):
		if state != "leave":
			a["state"] = "leave"
			a["bubble_text"] = "조정의 부름이 다했으니 거소로 물러나겠소."
			a["bubble_timer"] = 3.0

	# 코스 활동 인물(NamedNpcs)은 자기 FSM으로(미등용이면 위에서 leave가 되어 아래 퇴장 처리로 넘어간다)
	if _update_route_agent(a, delta):
		return

	if state == "work":
		var w_timer: float = a.get("work_timer", 30.0) - delta
		a["work_timer"] = w_timer
		if w_timer <= 0.0:
			a["state"] = "leave"
			a["bubble_text"] = ninfo.get("leave_line", "오늘 업무를 마치고 거소로 돌아가겠소.")
			a["bubble_timer"] = 4.0
	elif state == "leave":
		var h_pos: Vector2i = a.get("home_tile", Vector2i(int(a["x"]), int(a["y"])))
		var target := Vector2(float(h_pos.x) + 0.5, float(h_pos.y) + 0.5)
		var l_dx: float = target.x - a["x"]
		var l_dy: float = target.y - a["y"]
		var l_dist: float = sqrt(l_dx * l_dx + l_dy * l_dy)
		if l_dist < 0.6:
			a["is_dead"] = true
		else:
			_move_agent_towards(a, Vector2(float(a["x"]) + l_dx, float(a["y"]) + l_dy), delta, 0.8) # PORT-TRACE [길찾기]

## 낚시꾼 & 빨래하는 아낙 생명주기
func _update_spot_agent(a: Dictionary, delta: float) -> void:
	var atype: String = a.get("type", "")
	var state: String = a.get("state", "work")
	var stimer: float = a.get("state_timer", 0.0) - delta
	a["state_timer"] = stimer

	match atype:
		"fisher":
			match state:
				"fishing":
					if stimer <= 0.0:
						a["state"] = "hook"
						a["state_timer"] = 3.2
				"hook":
					if stimer <= 0.0:
						a["state"] = "caught"
						a["state_timer"] = 4.0
						a["bubble_text"] = "월척이로세! 오늘 저녁은 매운탕이구나!"
						a["bubble_timer"] = 4.0
				"caught":
					if stimer <= 0.0:
						a["state"] = "go_home"
						var target_home := _res_cache[0] if not _res_cache.is_empty() else (_roads_cache[0] if not _roads_cache.is_empty() else Vector2i(int(a["x"]) - 3, int(a["y"])))
						a["home_pos"] = target_home
				"go_home":
					var h_pos: Vector2i = a.get("home_pos", Vector2i(int(a["x"]), int(a["y"])))
					var t_vec := Vector2(float(h_pos.x) + 0.5, float(h_pos.y) + 0.5)
					var g_dx: float = t_vec.x - a["x"]
					var g_dy: float = t_vec.y - a["y"]
					var g_dist: float = sqrt(g_dx * g_dx + g_dy * g_dy)
					if g_dist < 0.6:
						a["is_dead"] = true
					else:
						_move_agent_towards(a, Vector2(float(a["x"]) + g_dx, float(a["y"]) + g_dy), delta, 0.85) # PORT-TRACE [길찾기]

		"washer":
			match state:
				"washing":
					if stimer <= 0.0:
						a["state"] = "done"
						a["state_timer"] = 3.5
				"done":
					if stimer <= 0.0:
						a["state"] = "go_home"
						a["bubble_text"] = "햇볕이 좋아 빨래가 뽀송뽀송하겠네."
						a["bubble_timer"] = 3.5
						var target_home := _res_cache[0] if not _res_cache.is_empty() else (_roads_cache[0] if not _roads_cache.is_empty() else Vector2i(int(a["x"]) - 3, int(a["y"])))
						a["home_pos"] = target_home
				"go_home":
					var h_pos: Vector2i = a.get("home_pos", Vector2i(int(a["x"]), int(a["y"])))
					var t_vec := Vector2(float(h_pos.x) + 0.5, float(h_pos.y) + 0.5)
					var g_dx: float = t_vec.x - a["x"]
					var g_dy: float = t_vec.y - a["y"]
					var g_dist: float = sqrt(g_dx * g_dx + g_dy * g_dy)
					if g_dist < 0.6:
						a["is_dead"] = true
					else:
						_move_agent_towards(a, Vector2(float(a["x"]) + g_dx, float(a["y"]) + g_dy), delta, 0.8) # PORT-TRACE [길찾기]

		"ice_sled":
			# 두 칸 사이를 미끄러져 오간다(양 끝에서 느려지고 가운데서 빠르게) — 꼬챙이질은 그림에서
			a["anim"] = float(a.get("anim", 0.0)) + delta * 3.0 * time_scale
			a["ttl"] = float(a.get("ttl", 90.0)) - delta
			if current_season != "겨울" or float(a["ttl"]) <= 0.0:
				a["is_dead"] = true
				return
			if String(a.get("state", "")) == "crack":
				if stimer <= 0.0:
					_ice_break(a)
				return
			var st_t: float = float(a.get("slide_t", 0.0)) + delta * 0.16 * time_scale
			a["slide_t"] = st_t
			var pa: Vector2 = a.get("slide_a", Vector2(a["x"], a["y"]))
			var pb: Vector2 = a.get("slide_b", pa)
			var ph := fmod(st_t, 2.0)
			var u := ph if ph < 1.0 else 2.0 - ph
			u = u * u * (3.0 - 2.0 * u)
			var np := pa.lerp(pb, u)
			var mv := (pb - pa) * (1.0 if ph < 1.0 else -1.0)
			if mv.length() > 0.01:
				a["dir"] = mv.normalized()
			a["x"] = np.x
			a["y"] = np.y
			if float(a.get("bubble_timer", 0.0)) <= 0.0 and randf() < delta * 0.05:
				a["bubble_text"] = ["씽씽! 비켜라~", "꼬챙이질 한 번에 저만큼!", "얼음판이 거울 같구나!", "누가 더 멀리 가나 내기하자!"][randi() % 4]
				a["bubble_timer"] = 3.0
			_ice_maybe_crack(a, delta)

		"ice_fisher":
			a["anim"] = float(a.get("anim", 0.0)) + delta * 2.0 * time_scale
			a["ttl"] = float(a.get("ttl", 100.0)) - delta
			if current_season != "겨울" or float(a["ttl"]) <= 0.0:
				a["is_dead"] = true
				return
			match state:
				"fishing":
					if stimer <= 0.0:
						a["state"] = "hook"
						a["state_timer"] = 2.5
				"hook":
					if stimer <= 0.0:
						a["state"] = "caught"
						a["state_timer"] = 3.5
						a["bubble_text"] = ["빙어가 줄줄이 올라오는구나!", "요놈, 은빛이 곱기도 하지!", "얼음 밑에도 고기가 산다네."][randi() % 3]
						a["bubble_timer"] = 3.5
				"caught":
					if stimer <= 0.0:
						a["state"] = "fishing"
						a["state_timer"] = randf_range(9.0, 18.0)
				"crack":
					if stimer <= 0.0:
						_ice_break(a)
					return
			if state == "fishing" and float(a.get("bubble_timer", 0.0)) <= 0.0 and randf() < delta * 0.02:
				a["bubble_text"] = ["손이 꽁꽁 얼었네...", "구멍을 너무 크게 뚫었나?", "에취! 그래도 한 마리만 더."][randi() % 3]
				a["bubble_timer"] = 3.0
			_ice_maybe_crack(a, delta)

		"water_play":
			var sw_timer: float = float(a.get("swim_timer", 30.0)) - delta
			a["swim_timer"] = sw_timer
			a["anim"] = float(a.get("anim", 0.0)) + delta * 2.5 * time_scale
			if sw_timer <= 0.0 or current_season != "여름":
				a["is_dead"] = true
			elif float(a.get("bubble_timer", 0.0)) <= 0.0 and randf() < delta * 0.04:
				a["bubble_text"] = ["어푸어푸! 시원하다~", "물장구치세!", "수원천 물이 참 맑구나!"][randi() % 3]
				a["bubble_timer"] = 3.0

		"drowning":
			var dr_timer: float = float(a.get("drown_timer", 35.0)) - delta
			a["drown_timer"] = dr_timer
			a["anim"] = float(a.get("anim", 0.0)) + delta * 5.0 * time_scale
			var dr_state: String = a.get("state", "drowning")
			if dr_state == "work": # 예전 세이브·생성분
				dr_state = "drowning"
				a["state"] = "drowning"
			if dr_state == "drowning":
				if dr_timer <= 0.0:
					a["is_dead"] = true
					return
				# 2초마다 구조 요청 말풍선
				var dr_bt: float = float(a.get("bubble_timer", 0.0)) - delta
				if dr_bt <= 0.0:
					a["bubble_text"] = "어푸푸... 사람 살려주시오!"
					a["bubble_timer"] = 2.5
				else:
					a["bubble_timer"] = dr_bt

				# 주변 4타일 이내 육지 백성 1명을 구조자(rescuer)로 지정
				var rescuer_id: int = int(a.get("rescuer_id", -1))
				var cur_dpt := Vector2i(int(a["x"]), int(a["y"]))
				var bank_dpt: Vector2i = a.get("bank_pt", _find_nearest_water_bank(cur_dpt))
				a["bank_pt"] = bank_dpt
				# PORT-TRACE [구조자 없음]: 예전엔 허수아비·빨래꾼(제자리 인물)·매 프레임 다시 덮이는 포졸/범죄자 사전까지 구조자로
				# 뽑혀, 그 사람이 꼼짝 않는 동안 다른 사람도 안 뽑혔다. 이제 걸어 다니는 백성만 고르고, 맡은 사람이 구조를 그만두면 다시 고르며,
				# 3초 안에 아무도 없으면 가까운 길에서 백성이 달려온다(StreetLife 구조자).
				if rescuer_id >= 0:
					var rsc := StreetLife._find(self, rescuer_id)
					if rsc.is_empty() or String(rsc.get("state", "")) != "rescuing":
						rescuer_id = -1
						a["rescuer_id"] = -1
				if rescuer_id < 0:
					a["rescue_wait"] = float(a.get("rescue_wait", 0.0)) + delta
					for cand_d: Dictionary in agents:
						if cand_d["id"] == a["id"] or bool(cand_d.get("is_wild", false)):
							continue
						if cand_d.get("is_spot", false) or cand_d.get("is_professional", false) or cand_d.get("is_named", false) or cand_d.get("street_folk", false) or cand_d.get("is_special", false) or cand_d.get("festival", false) or cand_d.get("siege_unit", false):
							continue
						var cd_type: String = cand_d.get("type", "")
						if cd_type in ["drowning", "water_play", "bandit", "tiger", "wolf", "criminal_npc", "patrol_soldier", "stretcher", "scarecrow", "sparrow_flock", "ox_plow", "farmer_cart", "horse_messenger", "official_rider"]:
							continue
						var cd_pt := Vector2i(int(cand_d["x"]), int(cand_d["y"]))
						if absi(cd_pt.x - cur_dpt.x) <= 6 and absi(cd_pt.y - cur_dpt.y) <= 6:
							if grid != null and grid.in_bounds(cd_pt.x, cd_pt.y) and grid.grid[cd_pt.y][cd_pt.x].get("terrain", "") != "water":
								cand_d["state"] = "rescuing"
								cand_d["rescue_target_id"] = a["id"]
								cand_d["rescue_bank_pt"] = bank_dpt
								cand_d["rescue_time"] = 3.5
								cand_d["bubble_text"] = "사람 살려! 내가 가오!"
								cand_d["bubble_timer"] = 2.5
								a["rescuer_id"] = cand_d["id"]
								break
					if int(a.get("rescuer_id", -1)) < 0 and float(a["rescue_wait"]) > 3.0:
						var rs := StreetLife.spawn_rescuer(self, bank_dpt, int(a["id"]))
						if not rs.is_empty():
							a["rescuer_id"] = rs["id"]

			elif dr_state == "saved":
				var save_dt: float = float(a.get("save_timer", 4.0)) - delta
				a["save_timer"] = save_dt
				if save_dt <= 0.0:
					a["is_dead"] = true

		"catholic":
			var cat_state: String = a.get("state", "idle")
			var cat_extra: Dictionary = a.get("extra", {})
			a["anim"] = float(a.get("anim", 0.0)) + delta * 2.0 * time_scale

			# 실학 연구(보유론·서기수용론) 완료 여부 상시 동기화
			var is_cat_researched: bool = false
			if sim != null and ("tech_tree" in sim) and sim.tech_tree != null:
				is_cat_researched = sim.tech_tree.has_researched("boyuron", sim) and sim.tech_tree.has_researched("segi", sim)
			elif sim != null:
				is_cat_researched = bool(sim.boyuron and sim.segi_policy)

			if is_cat_researched:
				if cat_state == "fleeing" or cat_state == "arrested":
					cat_state = "prayer"
					a["state"] = "prayer"
				if cat_state == "prayer" or cat_state == "idle":
					var pr_bt: float = float(a.get("bubble_timer", 0.0)) - delta
					if pr_bt <= 0.0 and randf() < delta * 0.03:
						a["bubble_text"] = "하늘의 주님, 성상 전하를 굽어살피소서."
						a["bubble_timer"] = 3.5
					else:
						a["bubble_timer"] = maxf(0.0, pr_bt)
			else:
				if cat_state == "fleeing":
					var flee_tgt: Vector2i = a.get("flee_target", _find_nearest_road(Vector2i(int(a["x"]), int(a["y"]))))
					var flee_v := Vector2(float(flee_tgt.x) + 0.5, float(flee_tgt.y) + 0.5)
					_move_agent_towards(a, flee_v, delta, 1.4)
					# 인근 6칸 순라군 출동 접촉 검사
					for cand_cp: Dictionary in agents:
						if cand_cp.get("type", "") in ["patrol_soldier", "guard"]:
							var p_dist: float = Vector2(cand_cp["x"], cand_cp["y"]).distance_to(Vector2(a["x"], a["y"]))
							if p_dist < 0.85:
								a["state"] = "arrested"
								a["is_arrested"] = true
								a["bubble_text"] = "히익! 살려주소서!"
								a["bubble_timer"] = 2.0
								cand_cp["bubble_text"] = "사학 죄인 체포!"
								cand_cp["bubble_timer"] = 2.5
								a["arrest_timer"] = 2.5
								break
				elif cat_state == "arrested":
					var arr_t: float = float(a.get("arrest_timer", 2.5)) - delta
					a["arrest_timer"] = arr_t
					if arr_t <= 0.0:
						a["is_dead"] = true
				else:
					var cat_idlet: float = float(cat_extra.get("idle_timer", 6.0)) - delta
					cat_extra["idle_timer"] = cat_idlet
					if cat_idlet <= 0.0:
						cat_extra["idle_timer"] = randf_range(5.0, 10.0)
						if float(a.get("bubble_timer", 0.0)) <= 0.0 and randf() < 0.3:
							a["bubble_text"] = "쉿… 천주를 공경하세…"
							a["bubble_timer"] = 3.0

		"woodcutter":
			var extra: Dictionary = a.get("extra", {})
			var has_wood: bool = extra.get("has_wood", false)
			var f_spot: Vector2i = extra.get("target_forest", Vector2i(int(a["x"]), int(a["y"])))
			var v_spot: Vector2i = extra.get("village_road", Vector2i(int(a["x"]), int(a["y"])))
			var target_pos := Vector2(v_spot.x + 0.5, v_spot.y + 0.5) if has_wood else Vector2(f_spot.x + 0.5, f_spot.y + 0.5)
			var w_dx: float = target_pos.x - a["x"]
			var w_dy: float = target_pos.y - a["y"]
			var w_dist: float = sqrt(w_dx * w_dx + w_dy * w_dy)
			if w_dist < 0.2:
				extra["has_wood"] = not has_wood
				if not has_wood and not _roads_cache.is_empty():
					extra["village_road"] = _roads_cache[randi() % _roads_cache.size()]
			else:
				_move_agent_towards(a, Vector2(float(a["x"]) + w_dx, float(a["y"]) + w_dy), delta, 0.7) # PORT-TRACE [길찾기]

		"farmer":
			var extra: Dictionary = a.get("extra", {})
			var phase: String = extra.get("phase", "work")
			if phase == "to_field":
				var tgt_field: Vector2i = extra.get("field", Vector2i.ZERO)
				var tg_fv := Vector2(float(tgt_field.x) + 0.5, float(tgt_field.y) + 0.5)
				var cur_fv := Vector2(float(a["x"]), float(a["y"]))
				if cur_fv.distance_to(tg_fv) < 0.45:
					extra["phase"] = "work"
					extra["work_timer"] = randf_range(8.0, 14.0)
					a["from_tile"] = tgt_field
				else:
					_move_agent_towards(a, tg_fv, delta, 0.65)
					a["anim"] = float(a.get("anim", 0.0)) + delta * 2.0 * time_scale
				return
			elif phase == "to_home":
				var home_tile: Vector2i = extra.get("home", Vector2i.ZERO)
				var home_entry: Vector2i = _entry_for(home_tile)
				var home_fv := Vector2(float(home_tile.x) + 0.5, float(home_tile.y) + 0.5)
				var entry_fv := Vector2(float(home_entry.x) + 0.5, float(home_entry.y) + 0.5)
				var cur_hv := Vector2(float(a["x"]), float(a["y"]))
				# 가옥 앞/입구 도달 시 떨림 없이 집 안으로 쏙 들어가며 자연스럽게 디스폰
				if cur_hv.distance_to(home_fv) < 0.55 or cur_hv.distance_to(entry_fv) < 0.45:
					a["is_dead"] = true
				else:
					var target_hv: Vector2 = entry_fv if cur_hv.distance_to(entry_fv) >= 0.45 else home_fv
					_move_agent_towards(a, target_hv, delta, 0.65)
					a["anim"] = float(a.get("anim", 0.0)) + delta * 2.0 * time_scale
				return

			# phase == "work" (경작 중) - 한 셀에 1명 이상 뭉치지 않게 이격 거리 강제 유지
			var cur_fx: float = float(a["x"])
			var cur_fy: float = float(a["y"])
			var cur_fpos := Vector2(cur_fx, cur_fy)

			# 인접 농민/소/수레와의 뭉침 방지 (Anti-Clumping / Separation)
			for other: Dictionary in agents:
				if other == a or other.get("is_dead", false):
					continue
				var o_type: String = str(other.get("type", ""))
				if o_type in ["farmer", "ox_plow", "farmer_cart"]:
					var op := Vector2(float(other.get("x", 0.0)), float(other.get("y", 0.0)))
					var dist: float = cur_fpos.distance_to(op)
					if dist < 0.95 and dist > 0.01:
						var push_dir: Vector2 = (cur_fpos - op).normalized()
						var push_step: float = (0.95 - dist) * 0.5 * delta
						a["x"] = cur_fx + push_dir.x * push_step
						a["y"] = cur_fy + push_dir.y * push_step
						break

			var work_left: float = float(extra.get("work_timer", 10.0)) - delta
			extra["work_timer"] = work_left
			if work_left <= 0.0:
				var field_targets: Array = extra.get("field_targets", [])
				var cur_idx: int = int(extra.get("field_idx", 0))
				if cur_idx + 1 < field_targets.size():
					extra["field_idx"] = cur_idx + 1
					extra["field"] = field_targets[cur_idx + 1]
					extra["phase"] = "to_field"
					a["bubble_text"] = "다음 논으로 건너가세!"
					a["bubble_timer"] = 2.0
					return
				else:
					# 둔전 전역 자유 순회: 바로 귀가하지 않고 70% 확률로 다른 빈 둔전 셀로 재배정
					if randf() < 0.70 and not _agr_cache.is_empty():
						var next_free: Vector2i = _agr_cache[randi() % _agr_cache.size()]
						extra["field_targets"] = [next_free]
						extra["field_idx"] = 0
						extra["field"] = next_free
						extra["phase"] = "to_field"
						a["bubble_text"] = "저쪽 논도 물꼬를 살펴야겠네!"
						a["bubble_timer"] = 2.5
						return
					else:
						extra["phase"] = "to_home"
						a["bubble_text"] = "오늘 일은 여기까지 하고 집으로!"
						a["bubble_timer"] = 2.5
						return

			var f_timer: float = extra.get("f_timer", 0.0) + delta
			var m_timer: float = extra.get("m_timer", 0.0) + delta * time_scale
			extra["m_timer"] = m_timer
			extra["season"] = current_season

			var farm_tile: Vector2i = extra.get("field", a.get("from_tile", Vector2i(int(a["x"]), int(a["y"]))))
			var has_water: bool = grid.has_water_supply(farm_tile.x, farm_tile.y) if grid else true
			extra["is_drought"] = not has_water

			# 가뭄 vs 풍년 상태별 대사 주기적 연동
			var b_speech_timer: float = float(extra.get("speech_timer", 0.0)) + delta
			if b_speech_timer >= 7.0:
				b_speech_timer = 0.0
				if a.get("bubble_text", "") == "":
					if not has_water:
						var drought_lines := ["비가 와야 할 텐데...", "논바닥이 다 갈라지는구나...", "물이 없어 벼가 타들어가는구나!"]
						a["bubble_text"] = drought_lines[randi() % drought_lines.size()]
						a["bubble_timer"] = 3.0
					else:
						var harvest_lines := ["만석거 물길 덕에 풍년이로세!", "올해는 볏단이 묵직하겠구나!", "풍년일세, 풍년이야!"]
						a["bubble_text"] = harvest_lines[randi() % harvest_lines.size()]
						a["bubble_timer"] = 3.0
			extra["speech_timer"] = b_speech_timer
			if f_timer >= 4.0:
				f_timer = 0.0
				var base_tile: Vector2i = a.get("from_tile", Vector2i(int(a["x"]), int(a["y"])))
				a["x"] = float(base_tile.x) + 0.5 + randf_range(-0.3, 0.3)
				a["y"] = float(base_tile.y) + 0.5 + randf_range(-0.3, 0.3)
			extra["f_timer"] = f_timer
			a["anim"] = float(a.get("anim", 0.0)) + delta * 2.0 * time_scale

		"ox_plow":
			var extra: Dictionary = a.get("extra", {})
			var speed: float = 0.22 * time_scale
			var ox_dir: float = extra.get("dir", 1.0)
			var offset: float = extra.get("offset", 0.0) + delta * speed * ox_dir
			if absf(offset) > 0.35:
				ox_dir = -ox_dir
				extra["dir"] = ox_dir
			extra["offset"] = offset
			var base_tile: Vector2i = a.get("from_tile", Vector2i(int(a["x"]), int(a["y"])))
			a["x"] = float(base_tile.x) + 0.5 + offset
			a["y"] = float(base_tile.y) + 0.5 + sin(offset * 5.0) * 0.08
			a["anim"] = float(a.get("anim", 0.0)) + delta * 2.5 * time_scale

		"farmer_cart":
			var extra: Dictionary = a.get("extra", {})
			var has_load: bool = extra.get("has_load", true)
			var farm_pt: Vector2i = extra.get("farm_pt", Vector2i(int(a["x"]), int(a["y"])))
			var town_pt: Vector2i = extra.get("town_pt", farm_pt)
			var target_pt: Vector2i = town_pt if has_load else farm_pt
			var target_pos := Vector2(float(target_pt.x) + 0.5, float(target_pt.y) + 0.5)
			var cur_pos := Vector2(float(a["x"]), float(a["y"]))
			if cur_pos.distance_to(target_pos) < 0.4:
				extra["has_load"] = not has_load
				# 대유둔전 여기저기를 자유롭게 순회하도록 다음 둔전 및 도착지를 다변화
				if not has_load and not _agr_cache.is_empty():
					extra["farm_pt"] = _agr_cache[randi() % _agr_cache.size()]
				elif has_load and not _res_cache.is_empty():
					extra["town_pt"] = _res_cache[randi() % _res_cache.size()]
				elif has_load and not _roads_cache.is_empty():
					extra["town_pt"] = _roads_cache[randi() % _roads_cache.size()]
			else:
				_move_agent_towards(a, target_pos, delta, 0.65)
			a["anim"] = float(a.get("anim", 0.0)) + delta * 3.0 * time_scale

		"scarecrow":
			a["anim"] = float(a.get("anim", 0.0)) + delta * 1.5 * time_scale

		"sparrow_flock":
			var extra: Dictionary = a.get("extra", {})
			if current_season != "가을":
				a["y"] = float(a["y"]) - delta * 3.0
				if float(a["y"]) < -10.0:
					a["is_dead"] = true
			else:
				var flight_timer: float = extra.get("flight_timer", 0.0) + delta * time_scale
				extra["flight_timer"] = flight_timer
				var center_pt: Vector2 = extra.get("center", Vector2(float(a["x"]), float(a["y"])))
				var angle: float = flight_timer * 1.2
				var radius: float = 1.3 + sin(flight_timer * 0.8) * 0.6
				a["x"] = center_pt.x + cos(angle) * radius
				a["y"] = center_pt.y + sin(angle) * radius * 0.5
				a["anim"] = float(a.get("anim", 0.0)) + delta * 8.0 * time_scale

# ============================================================ 사냥꾼 & 맹수(호환) & 포호책 시스템

## 공통 이동 보조 유틸
## PORT-TRACE [길찾기]: 예전엔 목표를 향해 일직선으로 걸어 건물·성벽을 그대로 뚫고 지나갔다. 이제는
## 목표 칸(건물이면 그 입구)까지 A* 경로를 따라 칸 중심을 차례로 밟고, 입구에 닿은 뒤에만 목표 지점
## (건물 안)으로 곧장 들어간다. 경로를 못 찾는 드문 경우에만 예전처럼 곧장 걷는다.
## 목적지로 가는 길이 없어 6초 넘게 막힌 NPC 처리.
## 중요 인물(직업군·군인·네임드·사냥꾼 등)은 목적지 입구로 옮겨 일을 이어 가게 하고, 일반 백성은 1초 동안 흐려지며 사라진다(곧 새 백성이 나온다).
func _resolve_blocked_agent(a: Dictionary, entry: Vector2i) -> void:
	var atype := String(a.get("type", ""))
	var keep: bool = bool(a.get("is_professional", false)) or bool(a.get("siege_unit", false)) or bool(a.get("military_unit", false)) or atype.begins_with("named_") 		or atype in ["patrol_soldier", "jangyongyeong_soldier", "firefighter_soldier", "bandit", "hunter", "saposu", "chakhogapsa", "beater", "marksman", "bait", "official_rider"]
	a.erase("path")
	if keep and grid != null and grid.in_bounds(entry.x, entry.y):
		a["x"] = float(entry.x) + 0.5
		a["y"] = float(entry.y) + 0.5
		a["from_tile"] = entry
		a["to_tile"] = entry
	else:
		a["fading_out"] = true
		a["fade_timer"] = 1.0
		a["fade_duration"] = 1.0

func _move_agent_towards(a: Dictionary, target: Vector2, delta: float, speed: float) -> void:
	var cur := Vector2(float(a.get("x", 0.0)), float(a.get("y", 0.0)))
	if maehyang_open:
		if a.get("gate_kind", "") == "changryong" or String(a.get("type", "")) in ["patrol_soldier", "chakhogapsa", "official_rider", "guard", "official"]:
			speed *= 1.25
		elif a.get("trip", false):
			speed *= 1.1
	# 종루 타종 뒤 30초: 종루 12칸 안 백성들이 활기차게(1.3배 빠르게) 움직인다
	if bell_boost > 0.0 and _jongnu.x >= 0 and absf(cur.x - float(_jongnu.x)) + absf(cur.y - float(_jongnu.y)) <= 12.0:
		speed *= 1.3
	var sz: int = grid.size
	var cur_t := Vector2i(clampi(int(floor(cur.x)), 0, sz - 1), clampi(int(floor(cur.y)), 0, sz - 1))
	var goal_t := Vector2i(clampi(int(floor(target.x)), 0, sz - 1), clampi(int(floor(target.y)), 0, sz - 1))
	var waypoint := target
	var entry := _entry_for(goal_t)
	var no_path := false
	if cur_t != entry and cur_t != goal_t and _astar_free != null:
		var path: Array = a.get("path", [])
		if not a.has("path") or a.get("path_goal", Vector2i(-99, -99)) != entry or int(a.get("path_ver", -1)) != _nav_version:
			if _path_budget <= 0:
				return # 이번 프레임 경로 계산 한도 초과 — 다음 프레임에 이어서
			_path_budget -= 1
			path = _find_path(a, cur_t, entry)
			# PORT-TRACE [문워크]: 경로 첫 칸이 지금 칸이면 그 한가운데로 뒷걸음질쳤다 — 지금 칸은 건너뛰고 다음 칸으로
			if path.size() >= 2 and Vector2i(path[0]) == cur_t:
				path.pop_front()
			a["path"] = path
			a["path_goal"] = entry
			a["path_ver"] = _nav_version
		if path.is_empty():
			no_path = true
		else:
			var wp: Vector2i = path[0]
			waypoint = Vector2(float(wp.x) + 0.5, float(wp.y) + 0.5)
			if cur.distance_to(waypoint) < 0.08:
				path.pop_front()
				if not path.is_empty():
					wp = path[0]
					waypoint = Vector2(float(wp.x) + 0.5, float(wp.y) + 0.5)
	var d := waypoint - cur
	var dist := d.length()
	# 길이 없는데 목표로 곧장 가려 할 때: 다음 칸이 건물·성벽·제방·물이면 넘어가지 않고 멈춘다(오래 막히면 길손은 사라짐)
	if no_path and dist > 0.02:
		var ahead := cur + d / dist * 0.55
		var nt := Vector2i(clampi(int(floor(ahead.x)), 0, sz - 1), clampi(int(floor(ahead.y)), 0, sz - 1))
		if nt != cur_t and nt != goal_t and nt != entry and not _tile_walkable(grid.grid[nt.y][nt.x]):
			a["blocked_t"] = float(a.get("blocked_t", 0.0)) + delta
			if float(a["blocked_t"]) > 8.0 and a.get("trip", false):
				a["is_dead"] = true
			elif float(a["blocked_t"]) > 6.0:
				# 갈 길이 막혀 한 자리에 갇힌 NPC: 도착한 셈 치거나(중요 인물) 조용히 사라지게 한다
				a["blocked_t"] = 0.0
				_resolve_blocked_agent(a, entry)
			return
	if dist > 0.02:
		var step: float = minf(speed * delta, dist)
		a["x"] = cur.x + d.x / dist * step
		a["y"] = cur.y + d.y / dist * step
		a["dir"] = d / dist

	# PORT-TRACE [건물 진입 및 은닉 처리]: NPC가 귀가/퇴근/복귀 상태에서 건물 입구(또는 건물 타일)에 도달하면
	# 입구에 어색하게 머물지 않고 즉시 건물 안으로 진입하여 필드에서 숨김(Despawn) 및 건물 근무 상태 활성화
	var a_state: String = a.get("state", "")
	if a_state in ["go_home", "return", "leave", "enter_building"]:
		var dist_to_target := cur.distance_to(target)
		var dist_to_entry := cur.distance_to(Vector2(float(entry.x) + 0.5, float(entry.y) + 0.5))
		var c_dist_to_goal: float = maxf(absf(cur.x - (float(goal_t.x) + 0.5)), absf(cur.y - (float(goal_t.y) + 0.5)))
		# 3칸 근접 도달 판정 (Chebyshev dist <= 3.0 시 건물 내부 진입 및 갇힘 방지 은닉)
		if cur_t == entry or cur_t == goal_t or dist_to_target < 0.65 or dist_to_entry < 0.35 or c_dist_to_goal <= 3.0:
			a["is_dead"] = true
			if grid != null and grid.in_bounds(goal_t.x, goal_t.y):
				var gt: Dictionary = grid.grid[goal_t.y][goal_t.x]
				gt["is_manned"] = true
				gt["staff_count"] = int(gt.get("staff_count", 0)) + 1

## 1. 사냥꾼(Hunter) 스폰 및 활동 관리
func _manage_hunters(delta: float) -> void:
	if _res_cache.is_empty() or _com_cache.is_empty():
		return

	# 마을 내 잔존 짐승이 있으면 스폰 주기 대폭 단축하여 즉시 지원
	var has_threat: bool = false
	for o: Dictionary in agents:
		if o.get("is_threat_target", false) and not o.get("is_dead", false):
			has_threat = true
			break

	_hunter_timer += delta
	var threshold: float = 6.0 if has_threat else 28.0
	if _hunter_timer < threshold:
		return

	var current_hunters: Array[Dictionary] = []
	for a: Dictionary in agents:
		if a.get("type", "") == "hunter" and not a.get("is_dead", false):
			current_hunters.append(a)

	if current_hunters.size() >= (2 if has_threat else 1):
		return

	_hunter_timer = 0.0
	var home_tile: Vector2i = _res_cache[randi() % _res_cache.size()]
	_next_agent_id += 1
	var h_agent: Dictionary = {
		"id": _next_agent_id,
		"type": "hunter",
		"x": float(home_tile.x) + 0.5,
		"y": float(home_tile.y) + 0.5,
		"from_tile": home_tile,
		"to_tile": home_tile,
		"home_tile": home_tile,
		"progress": 1.0,
		"dir": Vector2.DOWN,
		"speed": 0.82,
		"anim": 0.0,
		"state": "search_prey",
		"state_timer": 0.0,
		"target_animal_id": -1,
		"target_pos": Vector2.ZERO,
		"has_meat": false,
		"meat_name": "",
		"has_leather": false,
		"is_spot": false,
		"is_named": false,
		"is_wild": false,
		"bubble_text": "마을에 침범한 짐승을 소탕하러 활을 메고 나섰소!" if has_threat else "활시위를 매만지고 산으로 사냥을 떠나세.",
		"bubble_timer": 3.5,
		"extra": {}
	}
	agents.append(h_agent)

## 사냥꾼 FSM 업데이트 (1순위 마을 침범 짐승 소탕, 2순위 산악 원정 사냥)
func _update_hunter(a: Dictionary, delta: float) -> void:
	var cur_pos := Vector2(float(a.get("x", 0.0)), float(a.get("y", 0.0)))
	var on_screen: bool = is_world_pos_on_screen(cur_pos)
	if on_screen:
		a["anim"] = float(a.get("anim", 0.0)) + delta * 3.2

	var state: String = a.get("state", "search_prey")
	var stimer: float = a.get("state_timer", 0.0) - delta
	a["state_timer"] = stimer

	match state:
		"search_prey":
			var best_prey: Dictionary = find_target_animal(cur_pos, a)

			if best_prey.is_empty():
				# 타깃이 없을 때 외곽 산지 타일로 원정 순찰 (Patrol & Hunt)
				var pool: Array[Vector2i] = _mountain_cache if not _mountain_cache.is_empty() else (_mountain_forest_cache if not _mountain_forest_cache.is_empty() else _forest_cache)
				if not a.has("roam") or cur_pos.distance_to(a["roam"]) < 0.6:
					if not pool.is_empty():
						var f: Vector2i = pool[randi() % pool.size()]
						a["roam"] = Vector2(float(f.x) + 0.5, float(f.y) + 0.5)
				if a.has("roam"):
					_move_agent_towards(a, a["roam"], delta, 0.72)
				return

			var prey_pos := Vector2(float(best_prey["x"]), float(best_prey["y"]))
			var min_dist: float = cur_pos.distance_to(prey_pos)
			a["target_animal_id"] = best_prey.get("id", -1)
			a["target_pos"] = prey_pos
			var is_threat: bool = best_prey.get("is_threat_target", false)

			if min_dist <= 1.5:
				a["state"] = "hunt"
				a["state_timer"] = 1.8
				if is_threat:
					a["bubble_text"] = "마을 침범 짐승이다! 활시위를 당긴다!"
				else:
					a["bubble_text"] = "숨을 죽이고 활을 겨눈다..."
				a["bubble_timer"] = 1.8
			else:
				if is_threat and float(a.get("bubble_timer", 0.0)) <= 0.0 and randf() < 0.04:
					a["bubble_text"] = "마을 안 산짐승을 쫓고 있소!"
					a["bubble_timer"] = 2.5
				_move_agent_towards(a, prey_pos, delta, float(a.get("speed", 0.82)))

		"hunt":
			if stimer <= 0.0:
				var tid: int = int(a.get("target_animal_id", -1))
				var ptype: String = "deer"
				var was_threat := false
				for other: Dictionary in agents:
					if other.get("id", -1) == tid and not other.get("is_dead", false):
						was_threat = other.get("is_threat_target", false)
						ptype = other.get("type", "deer")
						safe_remove_agent(other)
						break

				a["has_meat"] = true
				a["has_leather"] = true
				match ptype:
					"deer": a["meat_name"] = "꽃사슴 고기와 녹용"
					"wild_boar": a["meat_name"] = "멧돼지 고기와 가죽"
					"rabbit": a["meat_name"] = "산토끼 모피"
					"wolf": a["meat_name"] = "승냥이 가죽"
					"tiger": a["meat_name"] = "호랑이 가죽"
					_: a["meat_name"] = "야생동물 고기"

				if was_threat:
					a["bubble_text"] = "명중이다! 마을의 침범 짐승을 소탕했으니 저잣거리로 가세!"
				else:
					a["bubble_text"] = "명중이다! 실한 놈을 잡았으니 저잣거리로 가세!"
				a["bubble_timer"] = 3.5
				a["state"] = "go_market"
				if not _com_cache.is_empty():
					var m_tile: Vector2i = _com_cache[randi() % _com_cache.size()]
					a["target_pos"] = Vector2(float(m_tile.x) + 0.5, float(m_tile.y) + 0.5)
				elif not _workshop_cache.is_empty():
					var ws_tile: Vector2i = _workshop_cache[randi() % _workshop_cache.size()]
					a["target_pos"] = Vector2(float(ws_tile.x) + 0.5, float(ws_tile.y) + 0.5)

		"go_market":
			var m_pos: Vector2 = a.get("target_pos", Vector2(float(a["x"]), float(a["y"])))
			var my_pos2 := Vector2(float(a["x"]), float(a["y"]))
			if my_pos2.distance_to(m_pos) <= 0.5:
				a["state"] = "sell"
				a["state_timer"] = 4.5
				var m_name: String = a.get("meat_name", "고기")
				a["bubble_text"] = "싱싱한 %s 사시오!" % m_name
				a["bubble_timer"] = 4.0
			else:
				_move_agent_towards(a, m_pos, delta, 0.78)

		"sell":
			if stimer <= 0.0:
				if sim:
					sim.rice += 25
					sim.gold += 15
					sim.loyalty = mini(100, sim.loyalty + 1)
				a["has_meat"] = false
				a["has_leather"] = false

				# 마을 내에 또 다른 침범 위협 짐승이 남아있는지 확인
				var has_more_threat: bool = false
				for o3: Dictionary in agents:
					if o3.get("is_threat_target", false) and not o3.get("is_dead", false):
						has_more_threat = true
						break
				if has_more_threat:
					a["state"] = "search_prey"
					a["search_throttle"] = 0.0
					a["bubble_text"] = "마을에 아직 짐승이 남았구나! 서둘러 쫓세!"
					a["bubble_timer"] = 3.0
				else:
					a["state"] = "go_home"
					var h_tile: Vector2i = a.get("home_tile", Vector2i(int(a["x"]), int(a["y"])))
					a["target_pos"] = Vector2(float(h_tile.x) + 0.5, float(h_tile.y) + 0.5)
					a["bubble_text"] = "장사가 짭짤하구먼. 집으로 돌아가세."
					a["bubble_timer"] = 3.5

		"go_home":
			var h_pos: Vector2 = a.get("target_pos", Vector2(float(a["x"]), float(a["y"])))
			var my_pos3 := Vector2(float(a["x"]), float(a["y"]))
			if my_pos3.distance_to(h_pos) <= 0.5:
				a["is_dead"] = true
			else:
				_move_agent_towards(a, h_pos, delta, 0.75)

## 2. 맹수(호랑이, 승냥이) 출몰 및 민가 습격 관리
func _manage_predators(delta: float) -> void:
	_predator_timer += delta
	_predator_raid_cooldown = maxf(0.0, _predator_raid_cooldown - delta)

	# 초반 보호 기간: 게임 시작 후 인게임 2년(turn <= 8, year < 1778) 동안 호환/맹수 습격 완전 차단
	if sim and (sim.current_year < 1778 or sim.turn <= 8):
		return
	# 퇴치 후 안전 기간: 쿨타임(인게임 2년 = 8턴) 적용 중 출몰 및 습격 차단
	if sim and sim.tiger_cooldown_turns > 0:
		return

	var is_court_tiger: bool = court and court.tiger.get("active", false)
	var active_predators: Array[Dictionary] = []
	for a: Dictionary in agents:
		if a.get("type", "") in ["tiger", "wolf"] and not a.get("is_dead", false):
			active_predators.append(a)

	if is_court_tiger:
		var has_tiger: bool = false
		for p: Dictionary in active_predators:
			if p.get("type", "") == "tiger":
				has_tiger = true
				break
		if not has_tiger:
			var tiger_pool: Array[Vector2i] = _mountain_rocky_cache if not _mountain_rocky_cache.is_empty() else (_mountain_forest_cache if not _mountain_forest_cache.is_empty() else _mountain_cache)
			var s_spot: Vector2i = _pick_safe_wildlife_spot(tiger_pool, 50)
			if s_spot.x >= 0:
				_add_predator("tiger", s_spot)

	if active_predators.size() < (2 if is_court_tiger else 1) and _predator_timer >= 22.0:
		_predator_timer = 0.0
		var spawn_pool: Array[Vector2i] = _mountain_rocky_cache if (not _mountain_rocky_cache.is_empty() and randf() < 0.5) else (_mountain_forest_cache if not _mountain_forest_cache.is_empty() else _mountain_cache)
		var sp_pos: Vector2i = _pick_safe_wildlife_spot(spawn_pool, 50)
		if sp_pos.x >= 0:
			_add_predator("wolf" if randf() < 0.6 else "tiger", sp_pos)

func _add_predator(ptype: String, pos: Vector2i) -> Dictionary:
	_next_agent_id += 1
	var ag: Dictionary = {
		"id": _next_agent_id,
		"type": ptype,
		"x": float(pos.x) + 0.5,
		"y": float(pos.y) + 0.5,
		"from_tile": pos,
		"to_tile": pos,
		"home_tile": pos,
		"progress": 1.0,
		"dir": Vector2.RIGHT,
		"speed": 0.85 if ptype == "wolf" else 0.95,
		"anim": 0.0,
		"state": "prowl",
		"state_timer": randf_range(4.0, 8.0),
		"target_pos": Vector2(float(pos.x) + 0.5, float(pos.y) + 0.5),
		"is_spot": false,
		"is_named": false,
		"is_wild": true,
		"is_special": true,
		"is_special_entity": true,
		"is_always_visible": true,
		"bubble_text": "어흥!" if ptype == "tiger" else "크르릉...",
		"bubble_timer": 3.0,
		"extra": {}
	}
	agents.append(ag)
	return ag

## 맹수 FSM 업데이트
func _update_predator(a: Dictionary, delta: float) -> void:
	var atype: String = a.get("type", "tiger")
	if a.has("doomed"):
		a["doomed"] = float(a["doomed"]) - delta
		if float(a["doomed"]) <= 0.0:
			a["is_dead"] = true # 퇴치 시한 도래 — 연출이 덜 끝났어도 반드시 제거
			return
		if a.get("state", "") == "cornered":
			return # 착호군에게 포위되어 제자리
	var state: String = a.get("state", "prowl")
	var stimer: float = a.get("state_timer", 0.0) - delta
	a["state_timer"] = stimer

	match state:
		"prowl":
			if stimer <= 0.0:
				if not _res_cache.is_empty() and _predator_raid_cooldown <= 0.0 and randf() < 0.65:
					a["state"] = "stalk"
					var target_res: Vector2i = _res_cache[randi() % _res_cache.size()]
					a["target_pos"] = Vector2(float(target_res.x) + 0.5, float(target_res.y) + 0.5)
					a["state_timer"] = 15.0
					a["bubble_text"] = "어흥-! 배가 고프구나!" if atype == "tiger" else "아우우우-!"
					a["bubble_timer"] = 3.5
				else:
					a["state_timer"] = randf_range(4.0, 7.0)
					var base_spot: Vector2i = a.get("home_tile", Vector2i(int(a["x"]), int(a["y"])))
					var nx: int = clampi(base_spot.x + randi_range(-2, 2), 1, grid.size - 2)
					var ny: int = clampi(base_spot.y + randi_range(-2, 2), 1, grid.size - 2)
					a["target_pos"] = Vector2(float(nx) + 0.5, float(ny) + 0.5)

			var tg: Vector2 = a.get("target_pos", Vector2(float(a["x"]), float(a["y"])))
			_move_agent_towards(a, tg, delta, float(a.get("speed", 0.85)))

		"stalk":
			var r_pos: Vector2 = a.get("target_pos", Vector2(float(a["x"]), float(a["y"])))
			var cur_p := Vector2(float(a["x"]), float(a["y"]))
			if cur_p.distance_to(r_pos) <= 0.8 or stimer <= 0.0:
				a["state"] = "attack"
				a["state_timer"] = 3.5
				_predator_raid_cooldown = 35.0
				if sim:
					var loss_pop: int = randi_range(1, 3)
					var loss_loy: int = randi_range(2, 4)
					sim.population = maxi(10, sim.population - loss_pop)
					sim.loyalty = maxi(0, sim.loyalty - loss_loy)
				if court:
					court.trigger_tiger_raid_crisis()
				var tiger_wpos := Vector2((r_pos.x - r_pos.y) * 32.0, (r_pos.x + r_pos.y) * 16.0)
				emit_signal("predator_attacked", tiger_wpos, atype)
				# 호환(虎患)으로 다친 백성을 들것으로 의원에
				spawn_patient(Vector2i(int(r_pos.x), int(r_pos.y)), "호환")
				if court:
					court.academic_hit(2, "호환") # PORT-TRACE [학문력]: 재해로 학문력 차감
				emit_signal("sfx", "roar")
				a["bubble_text"] = "크롸롸-! (민가 습격)" if atype == "tiger" else "크르릉-! (가축 습격)"
				a["bubble_timer"] = 3.5
			else:
				_move_agent_towards(a, r_pos, delta, 0.95)

		"attack":
			if stimer <= 0.0:
				a["state"] = "flee"
				var h_spot: Vector2i = a.get("home_tile", Vector2i(2, 3))
				a["target_pos"] = Vector2(float(h_spot.x) + 0.5, float(h_spot.y) + 0.5)
				a["bubble_text"] = "어흥!"
				a["bubble_timer"] = 2.0

		"flee":
			var f_pos: Vector2 = a.get("target_pos", Vector2(float(a["x"]), float(a["y"])))
			var cur_p2 := Vector2(float(a["x"]), float(a["y"]))
			if cur_p2.distance_to(f_pos) <= 0.8:
				# 인명/가축 피해를 입히고 산속 은신처로 복귀하면 안전하게 소멸(Despawn)하여 영구 배회 방지
				a["is_dead"] = true
			else:
				_move_agent_towards(a, f_pos, delta, 1.1)

		"flee_map":
			var out_pos := Vector2(-2.0, float(a["y"]))
			_move_agent_towards(a, out_pos, delta, 1.4)
			if float(a["x"]) <= 0.5:
				a["is_dead"] = true

		"approach_bait":
			var b_pos: Vector2 = a.get("target_pos", Vector2(float(a["x"]), float(a["y"])))
			var cur_p3 := Vector2(float(a["x"]), float(a["y"]))
			if cur_p3.distance_to(b_pos) <= 0.5:
				a["state"] = "eat_bait"
				a["state_timer"] = 4.0
				a["bubble_text"] = "고기 냄새가 나는구나..."
				a["bubble_timer"] = 2.5
			else:
				_move_agent_towards(a, b_pos, delta, 0.7)

		"eat_bait":
			pass

## 3. 포호책(조정 정책) 시행 시 3가지 연출 발동
func _on_tiger_resolved(choice: String, success: bool) -> void:
	var predators: Array[Dictionary] = []
	for a: Dictionary in agents:
		if a.get("type", "") in ["tiger", "wolf"] and not a.get("is_dead", false):
			predators.append(a)

	var target_predator: Dictionary = {}
	if not predators.is_empty():
		target_predator = predators[0]
	# PORT-TRACE [호랑이 잔존 버그]: 사용자 제보 — "포호책으로 퇴치했는데 호랑이가 지도에 계속 돌아다닌다".
	# 원인: (1) 착호군이 명령 당시 위치로만 달려가 움직인 호랑이를 끝내 못 따라잡거나, (2) 개간(몰이)으로
	# 지도 왼쪽 끝까지 쫓아내는데 성벽·강에 막혀 영영 못 나가거나, (3) 그래서 제거 단계가 실행되지 않았다.
	# 이제 퇴치에 성공하면 맹수마다 "최후 시한(doomed)"을 붙여, 연출(포위·사격·도주)이 끝나지 않아도
	# 시한이 지나면 반드시 지도와 에이전트 목록에서 사라진다. 착호군 사냥이면 호랑이는 포위돼 제자리에 멈춘다.
	if success:
		for pr: Dictionary in predators:
			pr["doomed"] = 25.0
			if choice == "army":
				pr["state"] = "cornered"
				pr["bubble_text"] = "크르릉... (포위됨)"
				pr["bubble_timer"] = 3.0

	var start_pos: Vector2i = _office_cache[0] if not _office_cache.is_empty() else (_military_cache[0] if not _military_cache.is_empty() else (_roads_cache[0] if not _roads_cache.is_empty() else Vector2i(10, 10)))

	match choice:
		"army":
			var tg_pos: Vector2 = Vector2(float(target_predator.get("x", 4.0)), float(target_predator.get("y", 4.0))) if not target_predator.is_empty() else Vector2(4.0, 4.0)
			var squad_types: Array[String] = ["chakhogapsa", "chakhogapsa", "hunter", "hunter"]
			for i: int in range(squad_types.size()):
				_next_agent_id += 1
				var offset_v := Vector2(cos(i * 1.57) * 0.6, sin(i * 1.57) * 0.6)
				var sq_agent: Dictionary = {
					"id": _next_agent_id,
					"type": squad_types[i],
					"x": float(start_pos.x) + 0.5 + offset_v.x,
					"y": float(start_pos.y) + 0.5 + offset_v.y,
					"from_tile": start_pos, "to_tile": start_pos, "home_tile": start_pos,
					"progress": 1.0, "dir": Vector2.RIGHT, "speed": 1.15, "anim": 0.0,
					"state": "rush_to_hunt", "state_timer": 0.0,
					"target_pos": tg_pos + offset_v * 1.2,
					"target_predator_id": target_predator.get("id", -1),
					"has_tiger_skin": false,
					"is_spot": false, "is_named": false, "is_wild": false,
					"is_special": true, "is_always_visible": true,
					"bubble_text": "착호갑사 출두요! 맹호를 포위하라!" if i == 0 else "퇴로를 막아라!",
					"bubble_timer": 4.0, "extra": {"squad_index": i}
				}
				agents.append(sq_agent)

		"clear":
			var tg_pos2: Vector2 = Vector2(float(target_predator.get("x", 4.0)), float(target_predator.get("y", 4.0))) if not target_predator.is_empty() else Vector2(4.0, 4.0)
			var beater_types: Array[String] = ["official", "beater", "beater", "beater"]
			for i: int in range(beater_types.size()):
				_next_agent_id += 1
				var offset_v2 := Vector2(float(i - 1) * 0.5, float(i % 2) * 0.4)
				var b_agent: Dictionary = {
					"id": _next_agent_id,
					"type": beater_types[i],
					"x": float(start_pos.x) + 0.5 + offset_v2.x,
					"y": float(start_pos.y) + 0.5 + offset_v2.y,
					"from_tile": start_pos, "to_tile": start_pos, "home_tile": start_pos,
					"progress": 1.0, "dir": Vector2.RIGHT, "speed": 0.95, "anim": 0.0,
					"state": "march_clear", "state_timer": 0.0,
					"target_pos": tg_pos2 + offset_v2,
					"target_predator_id": target_predator.get("id", -1),
					"is_spot": false, "is_named": false, "is_wild": false,
					"is_special": true, "is_always_visible": true,
					"bubble_text": "꽹! 꽹! 훠이-! 물러가라!" if i > 0 else "서식지를 정비하고 불을 밝혀라!",
					"bubble_timer": 4.5, "extra": {}
				}
				agents.append(b_agent)

		"bounty":
			var bait_pos: Vector2 = Vector2(float(start_pos.x + 3) + 0.5, float(start_pos.y - 2) + 0.5)
			if not _rocky_cache.is_empty():
				bait_pos = Vector2(float(_rocky_cache[0].x) + 0.5, float(_rocky_cache[0].y) + 0.5)

			_next_agent_id += 1
			agents.append({
				"id": _next_agent_id, "type": "bait",
				"x": bait_pos.x, "y": bait_pos.y,
				"from_tile": Vector2i(int(bait_pos.x), int(bait_pos.y)),
				"to_tile": Vector2i(int(bait_pos.x), int(bait_pos.y)),
				"home_tile": Vector2i(int(bait_pos.x), int(bait_pos.y)),
				"progress": 1.0, "dir": Vector2.ZERO, "speed": 0.0, "anim": 0.0,
				"state": "placed", "state_timer": 20.0, "target_pos": bait_pos,
				"is_spot": true, "is_named": false, "is_wild": false,
				"is_special": true, "is_always_visible": true,
				"bubble_text": "신선한 미끼", "bubble_timer": 2.0, "extra": {}
			})

			_next_agent_id += 1
			agents.append({
				"id": _next_agent_id, "type": "marksman",
				"x": bait_pos.x + 1.2, "y": bait_pos.y + 0.8,
				"from_tile": Vector2i(int(bait_pos.x + 1), int(bait_pos.y + 1)),
				"to_tile": Vector2i(int(bait_pos.x + 1), int(bait_pos.y + 1)),
				"home_tile": start_pos,
				"progress": 1.0, "dir": Vector2.LEFT, "speed": 0.8, "anim": 0.0,
				"state": "ambush", "state_timer": 4.0, "target_pos": bait_pos,
				"target_predator_id": target_predator.get("id", -1),
				"is_spot": false, "is_named": false, "is_wild": false,
				"is_special": true, "is_always_visible": true,
				"bubble_text": "바위 뒤에 엎드려 놈이 미끼를 물기를 기다린다...",
				"bubble_timer": 4.0, "extra": {"success": success}
			})

			if not target_predator.is_empty():
				target_predator["state"] = "approach_bait"
				target_predator["target_pos"] = bait_pos

## 포호 원정대(착호갑사, 몰이꾼, 명포수, 미끼) 상태 머신
func _update_expedition_agent(a: Dictionary, delta: float) -> void:
	var atype: String = a.get("type", "")
	var state: String = a.get("state", "")
	var stimer: float = a.get("state_timer", 0.0) - delta
	a["state_timer"] = stimer

	match atype:
		"chakhogapsa":
			match state:
				"rush_to_hunt":
					# 표적 호랑이의 "지금" 위치를 따라간다(명령 당시 위치로만 가면 못 따라잡았다). 이미 없으면 바로 사격 단계로.
					var tid0: int = int(a.get("target_predator_id", -1))
					var tgt_alive := false
					for o0: Dictionary in agents:
						if o0.get("id", -1) == tid0 and not o0.get("is_dead", false):
							a["target_pos"] = Vector2(float(o0["x"]), float(o0["y"]))
							tgt_alive = true
							break
					var tg: Vector2 = a.get("target_pos", Vector2(float(a["x"]), float(a["y"])))
					var my_p := Vector2(float(a["x"]), float(a["y"]))
					if my_p.distance_to(tg) <= 1.5 or not tgt_alive:
						a["state"] = "firing"
						a["state_timer"] = 2.5
						a["bubble_text"] = "조총 일제 사격! 탕-! 탕-!"
						a["bubble_timer"] = 2.5
					else:
						_move_agent_towards(a, tg, delta, 1.2)
				"firing":
					if stimer <= 0.0:
						var tid: int = int(a.get("target_predator_id", -1))
						for other: Dictionary in agents:
							if other.get("id", -1) == tid or other.get("type", "") in ["tiger", "wolf"]:
								other["is_dead"] = true
						a["has_tiger_skin"] = true
						a["state"] = "triumph_march"
						var h_pos: Vector2i = _haenggung_gate if _haenggung_gate.x >= 0 else a.get("home_tile", Vector2i(10, 10))
						a["target_pos"] = Vector2(float(h_pos.x) + 0.5, float(h_pos.y) + 0.5)
						a["bubble_text"] = "착호 성공! 호피를 거두어 행궁으로 개선하라!"
						a["bubble_timer"] = 4.0
				"triumph_march":
					var tg2: Vector2 = a.get("target_pos", Vector2(float(a["x"]), float(a["y"])))
					var my_p2 := Vector2(float(a["x"]), float(a["y"]))
					if my_p2.distance_to(tg2) <= 0.8:
						a["state"] = "reward_ceremony"
						a["state_timer"] = 4.0
						a["bubble_text"] = "주상 전하, 포획한 범의 가죽을 바치옵니다!"
						a["bubble_timer"] = 3.5
						if sim:
							sim.gold += 150
							sim.loyalty = mini(100, sim.loyalty + 5)
					else:
						_move_agent_towards(a, tg2, delta, 0.85)
				"reward_ceremony":
					if stimer <= 0.0:
						a["state"] = "go_home"
						var h_pos2: Vector2i = a.get("home_tile", Vector2i(10, 10))
						a["target_pos"] = Vector2(float(h_pos2.x) + 0.5, float(h_pos2.y) + 0.5)
						a["bubble_text"] = "성은이 망극하옵니다!"
						a["bubble_timer"] = 2.5
				"go_home":
					var tg3: Vector2 = a.get("target_pos", Vector2(float(a["x"]), float(a["y"])))
					var my_p3 := Vector2(float(a["x"]), float(a["y"]))
					if my_p3.distance_to(tg3) <= 0.4:
						a["is_dead"] = true
					else:
						_move_agent_towards(a, tg3, delta, 0.85)

		"beater":
			match state:
				"march_clear":
					var tg3: Vector2 = a.get("target_pos", Vector2(float(a["x"]), float(a["y"])))
					var my_p3 := Vector2(float(a["x"]), float(a["y"]))
					if my_p3.distance_to(tg3) <= 1.6:
						var tid2: int = int(a.get("target_predator_id", -1))
						for other2: Dictionary in agents:
							if other2.get("id", -1) == tid2 or other2.get("type", "") in ["tiger", "wolf"]:
								other2["state"] = "flee_map"
								other2["bubble_text"] = "끼에엑-! (맹수 도주)"
								other2["bubble_timer"] = 3.0
						a["state"] = "cheer"
						a["state_timer"] = 3.0
						a["bubble_text"] = "놈이 달아난다! 서식지를 완전히 정비하라!"
						a["bubble_timer"] = 3.0
					else:
						_move_agent_towards(a, tg3, delta, 0.95)
				"cheer":
					if stimer <= 0.0:
						a["state"] = "go_home"
						var h_pos2: Vector2i = a.get("home_tile", Vector2i(10, 10))
						a["target_pos"] = Vector2(float(h_pos2.x) + 0.5, float(h_pos2.y) + 0.5)
				"go_home":
					var tg4: Vector2 = a.get("target_pos", Vector2(float(a["x"]), float(a["y"])))
					var my_p4 := Vector2(float(a["x"]), float(a["y"]))
					if my_p4.distance_to(tg4) <= 0.4:
						a["is_dead"] = true
					else:
						_move_agent_towards(a, tg4, delta, 0.8)

		"marksman":
			match state:
				"ambush":
					var b_pos: Vector2 = a.get("target_pos", Vector2(float(a["x"]), float(a["y"])))
					for other3: Dictionary in agents:
						if other3.get("type", "") in ["tiger", "wolf"] and not other3.get("is_dead", false):
							var ot_pos := Vector2(float(other3["x"]), float(other3["y"]))
							if ot_pos.distance_to(b_pos) <= 0.7:
								var is_succ: bool = a.get("extra", {}).get("success", true)
								if is_succ:
									other3["is_dead"] = true
									a["state"] = "go_home"
									a["bubble_text"] = "탕-! 명중이다! 현상금은 내 차지다!"
									a["bubble_timer"] = 4.0
								else:
									other3["state"] = "flee"
									a["state"] = "go_home"
									a["bubble_text"] = "불발이다! 놈이 눈치챘다!"
									a["bubble_timer"] = 3.5
								var h_pos3: Vector2i = a.get("home_tile", Vector2i(10, 10))
								a["target_pos"] = Vector2(float(h_pos3.x) + 0.5, float(h_pos3.y) + 0.5)
								break
				"go_home":
					var tg5: Vector2 = a.get("target_pos", Vector2(float(a["x"]), float(a["y"])))
					var my_p5 := Vector2(float(a["x"]), float(a["y"]))
					if my_p5.distance_to(tg5) <= 0.4:
						a["is_dead"] = true
					else:
						_move_agent_towards(a, tg5, delta, 0.8)

		"bait":
			if stimer <= 0.0:
				a["is_dead"] = true

# ============================================================ 도적(화적 떼) 침략 & 순라청 & 소굴 토벌 시스템

func is_bandit_raid_active() -> bool:
	return _bandit_raid_active

func get_bandit_camp_pos() -> Vector2i:
	if bandit_mgr != null and not bandit_mgr.camps.is_empty():
		var c_pos: Vector2i = bandit_mgr.camps[0].get("pos", Vector2i(-1, -1))
		if c_pos.x >= 0:
			return c_pos
	if sim != null and sim.bandit_camp_pos != Vector2i(4, 8) and sim.bandit_camp_pos.x >= 0:
		return sim.bandit_camp_pos
	return Vector2i(-1, -1)

## 교전 활성 여부
func is_bandit_battle_active() -> bool:
	return _bandit_raid_active

## 현재 교전 위치 (월드 좌표) 계산
func get_current_battle_world_pos() -> Vector2:
	# 교전 중(state == "combat")인 유닛들의 중심점 우선
	var combatants: Array[Dictionary] = agents.filter(func(a: Dictionary) -> bool:
		return not a.get("is_dead", false) and (a.get("type", "") in ["bandit", "jangyongyeong_soldier"]) and a.get("state", "") == "combat"
	)
	if not combatants.is_empty():
		var sum_pos := Vector2.ZERO
		for c: Dictionary in combatants:
			sum_pos += Vector2(float(c.get("x", 0.0)), float(c.get("y", 0.0)))
		var avg_pos := sum_pos / float(combatants.size())
		if city != null and grid != null:
			var gx: int = clampi(int(round(avg_pos.x)), 0, grid.size - 1)
			var gy: int = clampi(int(round(avg_pos.y)), 0, grid.size - 1)
			var elev: float = grid.grid[gy][gx].get("elevation", 0.0) if grid.in_bounds(gx, gy) else 0.0
			return city.cell_center(avg_pos.x, avg_pos.y, elev)
		return avg_pos

	# 없으면 활성 도적들의 중심점
	var live_bandits: Array[Dictionary] = agents.filter(func(a: Dictionary) -> bool:
		return not a.get("is_dead", false) and a.get("type", "") == "bandit"
	)
	if not live_bandits.is_empty():
		var sum_pos := Vector2.ZERO
		for b: Dictionary in live_bandits:
			sum_pos += Vector2(float(b.get("x", 0.0)), float(b.get("y", 0.0)))
		var avg_pos := sum_pos / float(live_bandits.size())
		if city != null and grid != null:
			var gx: int = clampi(int(round(avg_pos.x)), 0, grid.size - 1)
			var gy: int = clampi(int(round(avg_pos.y)), 0, grid.size - 1)
			var elev: float = grid.grid[gy][gx].get("elevation", 0.0) if grid.in_bounds(gx, gy) else 0.0
			return city.cell_center(avg_pos.x, avg_pos.y, elev)
		return avg_pos

	# 도적도 없으면 목표 지점
	if city != null and grid != null and grid.in_bounds(_bandit_target_house.x, _bandit_target_house.y):
		var elev: float = grid.grid[_bandit_target_house.y][_bandit_target_house.x].get("elevation", 0.0)
		return city.cell_center(float(_bandit_target_house.x) + 0.5, float(_bandit_target_house.y) + 0.5, elev)
	return Vector2(0, 1024)

## 현재 교전 위치의 고증 지명 반환
func get_current_battle_location_name() -> String:
	if _bandit_mode == "assault_palace":
		return "화성행궁 본궁 및 신풍루"
	if grid != null and grid.in_bounds(_bandit_target_house.x, _bandit_target_house.y):
		var mid: int = int(float(grid.size) / 2.0)
		if _bandit_target_house.y >= mid + 8:
			return "팔달문(남문) 외곽 민가"
		elif _bandit_target_house.y <= mid - 8:
			return "장안문(북문) 외곽 둔전"
		elif _bandit_target_house.x <= mid - 8:
			return "화서문(서문) 외곽 취락"
		elif _bandit_target_house.x >= mid + 8:
			return "창룡문(동문) 외곽 들판"
	return "수원부 외곽 민가"

func get_bandit_target_house() -> Vector2i:
	return _bandit_target_house

## 도적 침략 및 순라군 요격 주기적 제어
func _manage_bandits(delta: float) -> void:
	if sim == null:
		return

	if sim.bandit_suppression_cooldown > 0.0:
		sim.bandit_suppression_cooldown = maxf(0.0, sim.bandit_suppression_cooldown - delta)

	if _dispatch_cooldown > 0.0:
		_dispatch_cooldown = maxf(0.0, _dispatch_cooldown - delta)

	if bandit_mgr != null:
		bandit_mgr._update_looted_tiles(delta, grid)

	# 1. 백동수 등용 시 도적 침략 100% 완전 차단
	var baek_hired: bool = sim.retainers.get("baek_dongsu", false)
	if baek_hired:
		if _bandit_raid_active:
			for a: Dictionary in agents:
				if a.get("type", "") == "bandit":
					a["state"] = "retreat"
					a["bubble_text"] = "야뇌 백동수가 떴다! 모두 퇴각하라!"
					a["bubble_timer"] = 3.0
			_end_bandit_raid(true)
			if court != null:
				court.emit_signal("notice", "야뇌 백동수가 장용영 군병을 이끌고 화적 떼를 완전히 축출했습니다!")
		return

	# 2. 도적 침략 중 공방전(Siege Defense) 틱 루프
	if _bandit_raid_active:
		_bandit_raid_duration += delta
		_damage_tick_timer += delta

		var bandits: Array[Dictionary] = agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "bandit" and not a.get("is_dead", false))
		if bandits.is_empty():
			_end_bandit_raid(true)
			return

		# 0.2초 분산 틱 전투 연산: [도적 공격력 vs 성 방호력 차감] & [장용영 공격력 vs 도적 체력 차감]
		if _damage_tick_timer >= 0.2:
			_damage_tick_timer = 0.0

			var cur_def: int = CityStats.get_fortress_defense_power()
			var ally_atk: int = CityStats.get_military_attack_power()
			var _royal_val: int = CityStats.get_royal_power()
			if sim != null:
				_royal_val = sim.authority

			# 1) 도적의 성벽 타격: 성벽에 붙은 도적이 있으면 초당 성 방호력 차감
			var wall_attackers: Array[Dictionary] = bandits.filter(func(b: Dictionary) -> bool: return b.get("state", "") == "attack_wall")
			if not wall_attackers.is_empty() and cur_def > 0:
				var bandit_tick_dmg: int = maxi(2, int(round(float(_bandit_siege_atk) * 0.1 * 0.2)))
				CityStats.apply_defense_damage(bandit_tick_dmg, sim)

			# 2) 장용영의 요격 및 반격: 장용영 군사와 맞붙은 상태(combat)인 도적이 있을 때 도적 체력 차감
			var combat_bandits: Array[Dictionary] = bandits.filter(func(b: Dictionary) -> bool: return b.get("state", "") == "combat")
			var troops: Array[Dictionary] = agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "jangyongyeong_soldier" and not a.get("is_dead", false))
			var in_melee: bool = not combat_bandits.is_empty() or not troops.is_empty()

			if in_melee:
				# 공식: 초당 도적 피해량 = (장용영 총 공격력) / 5 -> 0.2초 틱당 = ally_atk / 25
				var ally_tick_dmg: int = maxi(4, int(round(float(ally_atk) / 25.0)))
				_bandit_siege_hp = maxi(0, _bandit_siege_hp - ally_tick_dmg)

			# 3) 도적 체력 소진 시 즉시 전멸 및 격퇴(포포) 성공
			if _bandit_siege_hp <= 0:
				for b: Dictionary in bandits:
					b["state"] = "arrested"
					b["bubble_text"] = "오랏줄을 받다니! 살려주시오!"
					b["bubble_timer"] = 3.5
					var b_pos := Vector2i(int(b.get("x", 0.0)), int(b.get("y", 0.0)))
					capture_criminal(b_pos, "bandit")
					b["is_dead"] = true

				for troop: Dictionary in troops:
					troop["state"] = "return"
					troop["bubble_text"] = "도적 떼를 모두 진압했다! 군영으로 복귀한다!"
					troop["bubble_timer"] = 3.5

				_end_bandit_raid(true)
				if sim != null:
					sim.loyalty = mini(100, sim.loyalty + 5)
				if court != null:
					court.emit_signal("notice", "[토포 성공] 장용영 군사들이 침입한 도적 떼를 완벽히 진압하여 관아로 압송하였습니다!")
				return

			# 4) 행궁 함락 판정: 왕권 < 30 반란 모드에서 도적이 행궁 본궁에 도달하고 방호력 소진 시
			var hg_tile: Vector2i = _haenggung_gate if _haenggung_gate.x >= 0 else Vector2i(24, 28)
			var breached: bool = false
			for b: Dictionary in bandits:
				var bx: float = float(b.get("x", 0.0))
				var by: float = float(b.get("y", 0.0))
				if Vector2(bx, by).distance_to(Vector2(float(hg_tile.x) + 0.5, float(hg_tile.y) + 0.5)) <= 1.5:
					breached = true
					b["state"] = "palace_breach"
					b["bubble_text"] = "행궁을 함락했다! 우리가 새 주인이로다!"
					b["bubble_timer"] = 4.0

			if breached and cur_def <= 0 and _bandit_mode == "assault_palace":
				_end_bandit_raid(false)
				EndingManager.trigger_ending("FALLEN_TO_BANDITS")
				if court != null:
					court.emit_signal("notice", "[도시 함락] 왕권 실추로 인해 화적 떼가 화성행궁을 점거하여 도시가 함락되었습니다!")
				return

		# 순라청 보유 시 순라군 자동 출격 대응
		if not _patrol_cache.is_empty() and _dispatch_cooldown <= 0.0:
			var active_patrols: Array[Dictionary] = agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "patrol_soldier" and not a.get("is_dead", false))
			if active_patrols.is_empty():
				dispatch_patrol_squad()

		# 방호력 소진 및 25초간 지체 시: 도적들이 약탈 후 소굴로 퇴각
		if CityStats.get_fortress_defense_power() <= 0 and _bandit_raid_duration >= 25.0:
			for b: Dictionary in bandits:
				if b.get("state", "") != "retreat":
					b["state"] = "retreat"
					b["bubble_text"] = "약탈을 마쳤으니 소굴로 튀자!"
					b["bubble_timer"] = 3.5
			_end_bandit_raid(false)
			if court != null:
				court.emit_signal("notice", "성 방호력이 무너져 화적 떼가 민가를 약탈하고 소굴로 도주했습니다! 방어 시설을 보수하십시오.")
		return

	# 3. 도적 침략 발생 조건 검사
	if sim.bandit_suppression_cooldown > 0.0 or sim.bandit_suppression_turns > 0:
		return

	# 초반 보호 기간: 게임 시작 후 인게임 2년(turn <= 8, year < 1791) 동안 도적 출몰 완전 차단
	if sim.current_year < 1791 or sim.turn <= 8:
		return

	if _res_cache.is_empty() and _com_cache.is_empty():
		return

	# 치안 불안정 조건: 국방력 < 50 OR 민심 < 55 OR 순라청 부재
	var is_insecure: bool = (sim.military_power < 50 or sim.loyalty < 55 or _patrol_cache.is_empty())
	if not is_insecure:
		return

	_bandit_raid_timer -= delta
	if _bandit_raid_timer <= 0.0:
		_bandit_raid_timer = randf_range(45.0, 75.0)
		var raid_chance: float = 0.55 if _patrol_cache.is_empty() else 0.35
		if randf() < raid_chance:
			_start_bandit_raid()

## 도적 침략 개시
func _start_bandit_raid() -> void:
	_bandit_raid_active = true
	_bandit_siege_hp = 500
	_bandit_siege_atk = BanditManager.calculate_bandit_siege_atk(sim)
	_raid_captured = 0
	_bandit_raid_duration = 0.0
	_damage_tick_timer = 0.0
	sim.bandit_active = true
	sim.bandit_raid_count += 1

	var royal_val: int = CityStats.get_royal_power()
	if sim != null:
		royal_val = sim.authority

	# 왕권 30 이상: 외곽 약탈 모드 / 왕권 30 미만: 행궁 직격 반란 모드
	_bandit_mode = "outskirts" if royal_val >= 30 else "assault_palace"

	if _bandit_mode == "outskirts":
		# 외곽 민가/상점 목표 지정
		if not _res_cache.is_empty():
			var best_p: Vector2i = _res_cache[0]
			var min_edge_d: int = 999
			for p: Vector2i in _res_cache:
				var ed: int = mini(mini(p.x, grid.size - 1 - p.x), mini(p.y, grid.size - 1 - p.y))
				if ed < min_edge_d:
					min_edge_d = ed
					best_p = p
			_bandit_target_house = best_p
		elif not _com_cache.is_empty():
			_bandit_target_house = _com_cache[randi() % _com_cache.size()]
		else:
			_bandit_target_house = Vector2i(10, 10)
	else:
		# 화성행궁 본궁 직격 목표 지정
		_bandit_target_house = _haenggung_gate if _haenggung_gate.x >= 0 else Vector2i(24, 28)

	var camp_pos: Vector2i = get_bandit_camp_pos()
	if camp_pos.x < 0 or camp_pos.y < 0:
		if bandit_mgr != null and grid != null:
			var new_c: Dictionary = bandit_mgr._spawn_bandit_camp(grid)
			camp_pos = new_c.get("pos", Vector2i(4, 8))
		else:
			camp_pos = Vector2i(4, 8)
	var bandit_count: int = 5 if _bandit_mode == "outskirts" else 7
	for i: int in range(bandit_count):
		var spawn_offset := Vector2i(randi_range(-1, 1), randi_range(-1, 1))
		var sp_pos := camp_pos + spawn_offset
		_add_bandit_agent(sp_pos, _bandit_target_house, _bandit_mode)

	# 장용영 정예 부대 긴급 출동 (행궁/군영에서 스폰)
	dispatch_jangyongyeong_squad(_bandit_target_house)

	sim.bandit_raid_started.emit(_bandit_target_house)
	var battle_wpos: Vector2 = get_current_battle_world_pos()
	var loc_name: String = get_current_battle_location_name()
	bandit_battle_started.emit(battle_wpos, loc_name)
	if court != null:
		if _bandit_mode == "outskirts":
			court.emit_signal("notice", "긴급 경보: 화적 떼가 출몰하여 외곽 민가를 방화·약탈하고 있습니다! 장용영 군사가 요격 출동합니다.")
		else:
			court.emit_signal("notice", "비상 경보: 왕권 실추를 틈타 대규모 반란 도적 떼가 화성행궁 본궁을 향해 맹렬히 진격하고 있습니다!")

## 도적 침략 종료
func _end_bandit_raid(repelled: bool) -> void:
	_bandit_raid_active = false
	sim.bandit_active = false
	_bandit_raid_timer = randf_range(50.0, 80.0)
	if repelled:
		sim.bandit_suppression_turns = 24 # 격퇴 성공 시 2년(24개월) 안전 보장
		BuildingManager.restore_ruined_buildings(grid, sim)
		if bandit_mgr != null:
			var cur_camp: Vector2i = get_bandit_camp_pos()
			if cur_camp.x >= 0:
				bandit_mgr.remove_camp_at(cur_camp)
		if sim:
			sim.notify_bandit_camp_subjugated()
	sim.bandit_raid_ended.emit(repelled)
	bandit_battle_ended.emit(repelled)

## 장용영 정예 요격 부대 출동
func dispatch_jangyongyeong_squad(target_spot: Vector2i) -> bool:
	var base_spot: Vector2i = _haenggung_gate if _haenggung_gate.x >= 0 else Vector2i(24, 28)
	if not _patrol_cache.is_empty() and randf() < 0.5:
		base_spot = _patrol_cache[0]

	var squad_size: int = 6
	for i: int in range(squad_size):
		var sp: Vector2i = base_spot + Vector2i(randi_range(-1, 1), randi_range(-1, 1))
		_add_jangyongyeong_soldier(sp, target_spot, i == 0) # 0번은 선두 깃발병
	return true

## 장용영 군사 에이전트 생성
func _add_jangyongyeong_soldier(pos: Vector2i, target_pos: Vector2i, flag_bearer: bool = false) -> Dictionary:
	_next_agent_id += 1
	var ag: Dictionary = {
		"id": _next_agent_id,
		"type": "jangyongyeong_soldier",
		"x": float(pos.x) + 0.5,
		"y": float(pos.y) + 0.5,
		"from_tile": pos,
		"to_tile": target_pos,
		"home_tile": pos,
		"progress": 0.0,
		"dir": Vector2.RIGHT,
		"speed": 1.65,
		"anim": randf() * 4.0,
		"state": "rush",
		"hp": 8,
		"state_timer": 0.0,
		"is_spot": false,
		"is_named": false,
		"is_wild": false,
		"bubble_text": "장용영 군기(軍旗)를 올려라! 화적을 일망타진하라!" if flag_bearer else "장용영 정예병 출동! 어명을 받들라!",
		"bubble_timer": 3.8,
		"extra": {
			"is_flag_bearer": flag_bearer,
			"target_tile": target_pos
		}
	}
	agents.append(ag)
	return ag

## 도적 에이전트 생성
func _add_bandit_agent(pos: Vector2i, target_pos: Vector2i, mode: String = "outskirts") -> Dictionary:
	_next_agent_id += 1
	var ag: Dictionary = {
		"id": _next_agent_id,
		"type": "bandit",
		"x": float(pos.x) + 0.5,
		"y": float(pos.y) + 0.5,
		"from_tile": pos,
		"to_tile": target_pos,
		"home_tile": get_bandit_camp_pos(),
		"progress": 0.0,
		"dir": Vector2.RIGHT,
		"speed": 1.15,
		"anim": randf() * 4.0,
		"state": "march",
		"hp": 4,
		"state_timer": 0.0,
		"is_spot": false,
		"is_named": false,
		"is_wild": false,
		"bubble_text": "외곽 민가를 털고 어서 튀자!" if mode == "outskirts" else "왕실의 권위는 땅에 떨어졌다! 행궁을 점령하라!",
		"bubble_timer": 3.5,
		"extra": {
			"flame_anim": randf() * TAU,
			"torch_swing": 0.0,
			"target_tile": target_pos,
			"mode": mode
		}
	}
	agents.append(ag)
	return ag


## 순라군(병졸) 에이전트 생성
func _add_patrol_soldier(pos: Vector2i, target_pos: Vector2i, is_subjugation: bool = false) -> Dictionary:
	_next_agent_id += 1
	var ag: Dictionary = {
		"id": _next_agent_id,
		"type": "patrol_soldier",
		"x": float(pos.x) + 0.5,
		"y": float(pos.y) + 0.5,
		"from_tile": pos,
		"to_tile": target_pos,
		"home_tile": pos,
		"progress": 0.0,
		"dir": Vector2.RIGHT,
		"speed": 1.4,
		"anim": randf() * 4.0,
		"state": "rush",
		"hp": 4,
		"state_timer": 0.0,
		"is_spot": false,
		"is_named": false,
		"is_wild": false,
		"bubble_text": "순라청 군병 출동! 화적을 토벌하라!",
		"bubble_timer": 3.5,
		"extra": {
			"is_subjugation": is_subjugation,
			"target_tile": target_pos
		}
	}
	agents.append(ag)
	return ag

## 유저 조작 / 자동 순라군 파견
func dispatch_patrol_squad() -> bool:
	if _patrol_cache.is_empty() and _office_cache.is_empty():
		return false
	if _dispatch_cooldown > 0.0:
		return false

	var base_spot: Vector2i = _patrol_cache[0] if not _patrol_cache.is_empty() else _office_cache[0]
	var target_spot: Vector2i = _bandit_target_house

	var squad_size: int = 4
	for i: int in range(squad_size):
		var sp: Vector2i = base_spot + Vector2i(randi_range(-1, 1), randi_range(-1, 1))
		_add_patrol_soldier(sp, target_spot, false)

	_dispatch_cooldown = 15.0
	if court != null:
		court.emit_signal("notice", "순라청에서 순라군 부대가 긴급 출동하여 화적을 추격합니다!")
	return true

## 도적 소굴(근거지) 토벌대 출격
func dispatch_subjugation() -> bool:
	if sim == null:
		return false
	if sim.bandit_suppression_cooldown > 0.0:
		return false

	# 도적 토벌 출동 시 아군 총 전투력 산출: 기본 군사력 + (순라청 개수 * 30) + 장용영 훈련치
	var total_combat_power: int = BanditManager.calculate_ally_combat_power(sim, grid)
	if total_combat_power < 35 and _patrol_cache.is_empty():
		if court != null:
			court.emit_signal("notice", "토벌을 위해서는 순라청을 건설하거나 국방력을 35 이상 확보해야 합니다.")
		return false

	var base_spot: Vector2i = _patrol_cache[0] if not _patrol_cache.is_empty() else (_office_cache[0] if not _office_cache.is_empty() else Vector2i(15, 20))
	var camp_pos: Vector2i = get_bandit_camp_pos()

	_subjugation_active = true
	var squad_size: int = 5 + mini(5, _patrol_cache.size() * 2)
	for i: int in range(squad_size):
		var sp: Vector2i = base_spot + Vector2i(randi_range(-1, 1), randi_range(-1, 1))
		_add_patrol_soldier(sp, camp_pos, true)

	if court != null:
		var bonus_text: String = " (순라청 보조 병력 %d명 합류)" % mini(5, _patrol_cache.size() * 2) if not _patrol_cache.is_empty() else ""
		court.emit_signal("notice", "정예 토벌대가 도적 소굴을 향해 진격합니다!%s 근거지를 소탕하라!" % bonus_text)
	return true

## 도적 상태 머신 업데이트 (왕권 연동 지능형 AI)
func _update_bandit(a: Dictionary, delta: float) -> void:
	var state: String = a.get("state", "march")
	var target_tile: Vector2i = a.get("extra", {}).get("target_tile", _bandit_target_house)
	var camp_pos: Vector2i = get_bandit_camp_pos()
	var mode: String = a.get("extra", {}).get("mode", _bandit_mode)

	var flame_val: float = float(a.get("extra", {}).get("flame_anim", 0.0)) + delta * 8.0
	a["extra"]["flame_anim"] = flame_val
	a["extra"]["torch_swing"] = sin(flame_val)

	var cur_tile := Vector2i(int(a["x"]), int(a["y"]))
	var cur_def: int = CityStats.get_fortress_defense_power()

	match state:
		"march":
			var tg := Vector2(float(target_tile.x) + 0.5, float(target_tile.y) + 0.5)
			var m_dx: float = tg.x - float(a["x"])
			var m_dy: float = tg.y - float(a["y"])
			var m_dist: float = sqrt(m_dx * m_dx + m_dy * m_dy)

			# 1) 성벽/성문 충돌 검사 (행궁 직격 모드일 때 방호력이 남아있으면 성벽 타격)
			if mode == "assault_palace" and cur_def > 0 and _is_near_wall_or_gate(cur_tile):
				a["state"] = "attack_wall"
				a["bubble_text"] = "성벽을 부숴라! 방호벽을 무너뜨려라!"
				a["bubble_timer"] = 2.5
				return

			# 2) 경로상 민가/상점 통과 시 실시간 약탈 (비파괴적)
			if grid != null and grid.in_bounds(cur_tile.x, cur_tile.y):
				var bld: String = String(grid.grid[cur_tile.y][cur_tile.x].get("building", ""))
				if (bld.begins_with("res_") or bld.begins_with("com_")) and not grid.grid[cur_tile.y][cur_tile.x].get("is_looted", false):
					_loot_tile_safe(cur_tile)
					a["state"] = "raid"
					a["state_timer"] = 0.0
					a["bubble_text"] = "불을 질러라! 쌀가마를 털어라!"
					a["bubble_timer"] = 2.5
					return

			# 3) 목표 도달 판정
			if m_dist < 0.8:
				if mode == "assault_palace":
					a["state"] = "palace_breach"
					a["bubble_text"] = "행궁을 함락했다! 우리가 새 주인이로다!"
					a["bubble_timer"] = 4.0
				else:
					a["state"] = "raid"
					a["state_timer"] = 0.0
					_loot_tile_safe(target_tile)
					a["bubble_text"] = "두둑이 챙겼다! 성 밖으로 튀자!"
					a["bubble_timer"] = 3.0
			else:
				_move_agent_towards(a, Vector2(float(a["x"]) + m_dx, float(a["y"]) + m_dy), delta, float(a["speed"]))

		"attack_wall":
			# 성벽을 때리는 모션: 방호력이 0이 되면 성벽 돌파!
			var at_timer: float = float(a.get("state_timer", 0.0)) + delta
			a["state_timer"] = at_timer
			if cur_def <= 0:
				a["state"] = "march"
				a["bubble_text"] = "성벽이 뚫렸다! 행궁으로 돌격하라!"
				a["bubble_timer"] = 3.0
			elif at_timer >= 2.0:
				a["state_timer"] = 0.0
				a["bubble_text"] = "성벽이 곧 무너진다! 힘을 합쳐라!"
				a["bubble_timer"] = 2.0

		"raid":
			var rtimer: float = float(a.get("state_timer", 0.0)) + delta
			a["state_timer"] = rtimer
			if rtimer >= 2.5:
				a["state_timer"] = 0.0
				if mode == "outskirts":
					a["state"] = "retreat"
					a["bubble_text"] = "약탈을 마쳤으니 소굴로 튀자!"
					a["bubble_timer"] = 3.5
				else:
					a["state"] = "march"
					a["bubble_text"] = "행궁으로 돌격하라!"
					a["bubble_timer"] = 2.5

		"combat":
			# 장용영 또는 순라군과 칼싸움
			var ctimer: float = float(a.get("state_timer", 0.0)) + delta
			a["state_timer"] = ctimer
			if ctimer >= 1.2:
				a["state_timer"] = 0.0
				var nearby_threat: bool = false
				for other: Dictionary in agents:
					if other.get("type", "") in ["patrol_soldier", "jangyongyeong_soldier"] and not other.get("is_dead", false):
						var dist: float = Vector2(float(other["x"]), float(other["y"])).distance_to(Vector2(float(a["x"]), float(a["y"])))
						if dist < 1.5:
							nearby_threat = true
							break
				if not nearby_threat:
					a["state"] = "march"

		"palace_breach":
			var ptimer: float = float(a.get("state_timer", 0.0)) + delta
			a["state_timer"] = ptimer
			if ptimer >= 3.0:
				a["state_timer"] = 0.0
				a["bubble_text"] = "이곳은 이제 우리 세상이다!"
				a["bubble_timer"] = 3.0

		"arrested":
			a["speed"] = 0.0

		"retreat":
			var ctg := Vector2(float(camp_pos.x) + 0.5, float(camp_pos.y) + 0.5)
			var r_dx: float = ctg.x - float(a["x"])
			var r_dy: float = ctg.y - float(a["y"])
			var r_dist: float = sqrt(r_dx * r_dx + r_dy * r_dy)
			if r_dist < 0.8:
				a["is_dead"] = true
			else:
				_move_agent_towards(a, Vector2(float(a["x"]) + r_dx, float(a["y"]) + r_dy), delta, 1.35)

## 장용영 정예 요격군 상태 머신 업데이트
func _update_jangyongyeong_soldier(a: Dictionary, delta: float) -> void:
	var state: String = a.get("state", "rush")
	var target_pos: Vector2i = a.get("extra", {}).get("target_tile", _bandit_target_house)
	var home_base: Vector2i = a.get("home_tile", Vector2i(24, 28))

	match state:
		"rush":
			var nearest_b: Dictionary = {}
			var min_bdist: float = 999.0
			var my_pos := Vector2(float(a["x"]), float(a["y"]))

			for b: Dictionary in agents:
				if b.get("type", "") == "bandit" and not b.get("is_dead", false):
					var b_pos := Vector2(float(b["x"]), float(b["y"]))
					var d: float = my_pos.distance_to(b_pos)
					if d < min_bdist:
						min_bdist = d
						nearest_b = b

			if not nearest_b.is_empty() and min_bdist < 1.4:
				a["state"] = "combat"
				a["state_timer"] = 0.0
				nearest_b["state"] = "combat"
				a["bubble_text"] = "장용영의 칼을 받아라! 역적 놈들아!"
				a["bubble_timer"] = 2.5
			elif not nearest_b.is_empty():
				var b_pos := Vector2(float(nearest_b["x"]), float(nearest_b["y"]))
				_move_agent_towards(a, b_pos, delta, float(a["speed"]))
			else:
				var tg := Vector2(float(target_pos.x) + 0.5, float(target_pos.y) + 0.5)
				if my_pos.distance_to(tg) >= 0.8:
					_move_agent_towards(a, tg, delta, float(a["speed"]))
				else:
					a["state"] = "return"

		"combat":
			var ctimer: float = float(a.get("state_timer", 0.0)) + delta
			a["state_timer"] = ctimer
			var has_enemy: bool = false
			var my_pos := Vector2(float(a["x"]), float(a["y"]))

			for b: Dictionary in agents:
				if b.get("type", "") == "bandit" and not b.get("is_dead", false):
					var b_pos := Vector2(float(b["x"]), float(b["y"]))
					if my_pos.distance_to(b_pos) < 1.6:
						has_enemy = true
						break

			if not has_enemy:
				a["state"] = "return"
				a["bubble_text"] = "도적 떼를 모두 진압했다! 군영으로 복귀한다!"
				a["bubble_timer"] = 3.5

		"return":
			var h_pos := Vector2(float(home_base.x) + 0.5, float(home_base.y) + 0.5)
			var my_pos := Vector2(float(a["x"]), float(a["y"]))
			if my_pos.distance_to(h_pos) < 0.8:
				a["is_dead"] = true
			else:
				_move_agent_towards(a, h_pos, delta, 1.2)

## 타일 안전 약탈 (비파괴적)
func _loot_tile_safe(pos: Vector2i) -> void:
	if grid == null or not grid.in_bounds(pos.x, pos.y):
		return
	var t: Dictionary = grid.grid[pos.y][pos.x]
	t["is_looted"] = true
	t["looted_timer"] = 25.0
	BuildingManager.ruin_building_at(pos, grid, sim)
	if bandit_mgr != null:
		bandit_mgr.looted_tiles[pos] = 25.0
	if sim != null:
		sim.gold = maxi(0, sim.gold - 25)
		sim.rice = maxi(0, sim.rice - 15)
		sim.loyalty = maxi(0, sim.loyalty - 1)

## 성벽/성문 인접 여부 검사
func _is_near_wall_or_gate(pos: Vector2i) -> bool:
	if grid == null or not grid.in_bounds(pos.x, pos.y):
		return false
	var dirs := [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 0)]
	for d in dirs:
		var np: Vector2i = pos + d
		if grid.in_bounds(np.x, np.y):
			var bld: String = String(grid.grid[np.y][np.x].get("building", ""))
			if bld == "wall" or bld == "gate" or bld.begins_with("floodgate"):
				return true
	return false

## 순라군 상태 머신 업데이트
func _update_patrol_soldier(a: Dictionary, delta: float) -> void:
	var state: String = a.get("state", "rush")
	var is_subjugation: bool = a.get("extra", {}).get("is_subjugation", false)
	var target_pos: Vector2i = a.get("extra", {}).get("target_tile", _bandit_target_house)

	match state:
		"rush":
			var tg := Vector2(float(target_pos.x) + 0.5, float(target_pos.y) + 0.5)
			var p_dx: float = tg.x - float(a["x"])
			var p_dy: float = tg.y - float(a["y"])
			var p_dist: float = sqrt(p_dx * p_dx + p_dy * p_dy)

			if is_subjugation:
				if p_dist < 0.8:
					a["state"] = "subjugate_battle"
					a["state_timer"] = 0.0
					a["bubble_text"] = "도적 소굴을 불태워라! 전원 항복하라!"
					a["bubble_timer"] = 3.5
				else:
					_move_agent_towards(a, Vector2(float(a["x"]) + p_dx, float(a["y"]) + p_dy), delta, float(a["speed"])) # PORT-TRACE [길찾기]
			else:
				var nearest_bandit: Dictionary = {}
				var min_bdist: float = 999.0
				for b: Dictionary in agents:
					if b.get("type", "") == "bandit" and not b.get("is_dead", false):
						var b_dx: float = float(b["x"]) - float(a["x"])
						var b_dy: float = float(b["y"]) - float(a["y"])
						var bd: float = sqrt(b_dx * b_dx + b_dy * b_dy)
						if bd < min_bdist:
							min_bdist = bd
							nearest_bandit = b

				if not nearest_bandit.is_empty() and min_bdist < 1.0:
					a["state"] = "combat"
					a["state_timer"] = 0.0
					nearest_bandit["state"] = "combat"
					a["bubble_text"] = "화적 놈들 꼼짝 마라! 포졸이 왔다!"
					a["bubble_timer"] = 3.0
				elif not nearest_bandit.is_empty():
					var b_dx: float = float(nearest_bandit["x"]) - float(a["x"])
					var b_dy: float = float(nearest_bandit["y"]) - float(a["y"])
					var _b_dist: float = sqrt(b_dx * b_dx + b_dy * b_dy)
					_move_agent_towards(a, Vector2(float(a["x"]) + b_dx, float(a["y"]) + b_dy), delta, float(a["speed"])) # PORT-TRACE [길찾기]
				elif p_dist >= 0.5:
					_move_agent_towards(a, Vector2(float(a["x"]) + p_dx, float(a["y"]) + p_dy), delta, float(a["speed"])) # PORT-TRACE [길찾기]
				else:
					a["state"] = "return"

		"combat":
			var ctimer: float = float(a.get("state_timer", 0.0)) + delta
			a["state_timer"] = ctimer
			if ctimer >= 1.5:
				a["state_timer"] = 0.0
				var has_enemy: bool = false
				for b: Dictionary in agents:
					if b.get("type", "") == "bandit" and not b.get("is_dead", false):
						var b_dist: float = sqrt(pow(float(b["x"]) - float(a["x"]), 2) + pow(float(b["y"]) - float(a["y"]), 2))
						if b_dist < 1.4:
							b["hp"] = int(b["hp"]) - 1
							has_enemy = true
							if int(b["hp"]) <= 0:
								b["is_dead"] = true
								# 관아가 있으면 쓰러진 화적 가운데 둘까지는 오랏줄에 묶어 관아로 압송
								if _raid_captured < 2 and capture_criminal(Vector2i(int(b["x"]), int(b["y"])), "bandit"):
									_raid_captured += 1
				if not has_enemy:
					a["state"] = "return"
					a["bubble_text"] = "화적을 모두 제압했다! 순라청으로 복귀한다!"
					a["bubble_timer"] = 3.5

		"subjugate_battle":
			var stimer: float = float(a.get("state_timer", 0.0)) + delta
			a["state_timer"] = stimer
			if stimer >= 3.5:
				a["state"] = "return"
				a["bubble_text"] = "도적 소굴을 소탕하고 전리품을 획득했다!"
				a["bubble_timer"] = 4.0
				if _subjugation_active:
					_subjugation_active = false
					sim.gold += 250
					sim.rice += 150
					sim.loyalty = mini(100, sim.loyalty + 8)
					sim.authority = mini(100, sim.authority + 10)
					sim.bandit_suppression_turns = 24 # 소탕 시 2년(24개월) 도적 출현 억제
					sim.bandit_suppression_cooldown = 180.0
					var camp_p: Vector2i = get_bandit_camp_pos()
					if bandit_mgr != null:
						bandit_mgr.remove_camp_at(camp_p)
					sim.bandit_camp_subjugated.emit()
					# 소굴 토벌로 사로잡은 화적 두 명을 관아로 압송
					for _k in range(2):
						capture_criminal(camp_p if camp_p.x >= 0 else Vector2i(4, 8), "bandit")
					if court != null:
						court.emit_signal("notice", "도적 소굴을 완전히 토벌하여 전리품(금 250, 식량 150)을 국고에 귀속하고 소굴을 완전히 소탕했습니다!")

		"patrol_wall":
			var p_timer: float = float(a.get("state_timer", 0.0)) - delta
			a["state_timer"] = p_timer
			if p_timer <= 0.0:
				a["state"] = "return"
				a["bubble_text"] = "성곽 순찰을 마쳤으니 거소로 복귀한다."
				a["bubble_timer"] = 3.0
			else:
				var next_wp: Vector2i = a.get("next_patrol_wp", Vector2i(-1, -1))
				var cur_p := Vector2(float(a["x"]), float(a["y"]))
				var wp_vec := Vector2(float(next_wp.x) + 0.5, float(next_wp.y) + 0.5)
				if next_wp.x < 0 or cur_p.distance_to(wp_vec) < 0.6:
					if not _patrol_roads_cache.is_empty():
						var cands: Array[Vector2i] = []
						var my_tile := Vector2i(int(a["x"]), int(a["y"]))
						for d: Vector2i in DIRS4:
							var adj_p: Vector2i = my_tile + d
							if _patrol_roads_set.has(adj_p) and adj_p != a.get("last_patrol_wp", my_tile):
								cands.append(adj_p)
						if not cands.is_empty():
							a["last_patrol_wp"] = my_tile
							next_wp = cands[randi() % cands.size()]
						else:
							next_wp = _patrol_roads_cache[randi() % _patrol_roads_cache.size()]
						a["next_patrol_wp"] = next_wp
				if next_wp.x >= 0:
					_move_agent_towards(a, Vector2(float(next_wp.x) + 0.5, float(next_wp.y) + 0.5), delta, float(a.get("speed", 1.0)))

		"return":
			var h_pos: Vector2i = a.get("home_tile", Vector2i(int(a["x"]), int(a["y"])))
			var tg := Vector2(float(h_pos.x) + 0.5, float(h_pos.y) + 0.5)
			var r_dx: float = tg.x - float(a["x"])
			var r_dy: float = tg.y - float(a["y"])
			var r_dist: float = sqrt(r_dx * r_dx + r_dy * r_dy)
			if r_dist < 0.6:
				a["is_dead"] = true
				if grid != null and grid.in_bounds(h_pos.x, h_pos.y):
					var ht: Dictionary = grid.grid[h_pos.y][h_pos.x]
					ht["is_manned"] = true
					ht["staff_count"] = int(ht.get("staff_count", 0)) + 1
			else:
				_move_agent_towards(a, Vector2(float(a["x"]) + r_dx, float(a["y"]) + r_dy), delta, 1.1) # PORT-TRACE [길찾기]

## 평상시 성곽 안쪽 순찰로(길) 순라군 순찰 관리
func _manage_routine_patrol(delta: float) -> void:
	if _bandit_raid_active:
		return
	if _patrol_roads_cache.size() < 4:
		return
	if _patrol_cache.is_empty() and _military_cache.is_empty() and _office_cache.is_empty():
		return

	_routine_patrol_timer -= delta
	if _routine_patrol_timer > 0.0:
		return
	_routine_patrol_timer = randf_range(16.0, 24.0)

	var active_wall_patrols := agents.filter(func(soldier: Dictionary) -> bool: return soldier.get("type", "") == "patrol_soldier" and soldier.get("state", "") == "patrol_wall" and not soldier.get("is_dead", false))
	if active_wall_patrols.size() >= 3:
		return

	var base_spot: Vector2i = _patrol_cache[0] if not _patrol_cache.is_empty() else (_military_cache[0] if not _military_cache.is_empty() else _office_cache[0])
	var target_road := _patrol_roads_cache[randi() % _patrol_roads_cache.size()]
	_next_agent_id += 1
	var ag: Dictionary = {
		"id": _next_agent_id,
		"type": "patrol_soldier",
		"x": float(base_spot.x) + 0.5,
		"y": float(base_spot.y) + 0.5,
		"from_tile": base_spot,
		"to_tile": target_road,
		"home_tile": base_spot,
		"progress": 0.0,
		"dir": Vector2.RIGHT,
		"speed": 0.95,
		"anim": randf() * 4.0,
		"state": "patrol_wall",
		"hp": 3,
		"state_timer": randf_range(25.0, 40.0),
		"is_spot": false,
		"is_named": false,
		"is_wild": false,
		"bubble_text": "성곽 순찰 이상 무!",
		"bubble_timer": 3.0,
		"next_patrol_wp": target_road,
		"last_patrol_wp": base_spot,
		"extra": {
			"is_routine": true
		}
	}
	agents.append(ag)

## 순라청 출동 포졸 및 저잣거리 범죄자 에이전트 동기화
func _sync_sunla_agents() -> void:
	if sunla_manager == null:
		return

	# 1. 활성 순라군 포졸 에이전트 동기화
	for off: PatrolOfficerNPC in sunla_manager.officer_pool:
		var ag_id: int = 80000 + off.id
		if off.is_active:
			var found: bool = false
			for a: Dictionary in agents:
				if int(a.get("id", -1)) == ag_id:
					var new_dict: Dictionary = off.to_agent_dict()
					new_dict["id"] = ag_id
					a.merge(new_dict, true)
					found = true
					break
			if not found:
				var new_dict: Dictionary = off.to_agent_dict()
				new_dict["id"] = ag_id
				agents.append(new_dict)
		else:
			for i: int in range(agents.size() - 1, -1, -1):
				if int(agents[i].get("id", -1)) == ag_id:
					agents.remove_at(i)

	# 2. 저잣거리 범죄자(난동범/소매치기) 에이전트 동기화
	for crm: CriminalNPC in sunla_manager.active_criminals:
		var crm_id: int = 90000 + crm.id
		if not crm.is_dead:
			var found: bool = false
			for a: Dictionary in agents:
				if int(a.get("id", -1)) == crm_id:
					var new_dict: Dictionary = crm.to_agent_dict()
					new_dict["id"] = crm_id
					a.merge(new_dict, true)
					found = true
					break
			if not found:
				var new_dict: Dictionary = crm.to_agent_dict()
				new_dict["id"] = crm_id
				agents.append(new_dict)
		else:
			for i: int in range(agents.size() - 1, -1, -1):
				if int(agents[i].get("id", -1)) == crm_id:
					agents.remove_at(i)

	# 3. 고아 범죄자 에이전트 클린업 (sunla_manager에 살아있지 않은 90000번대 에이전트 일괄 제거)
	var live_crm_ids: Array[int] = []
	for c: CriminalNPC in sunla_manager.active_criminals:
		if not c.is_dead:
			live_crm_ids.append(90000 + c.id)

	for i: int in range(agents.size() - 1, -1, -1):
		var a_id: int = int(agents[i].get("id", -1))
		if a_id >= 90000 and a_id < 100000:
			if not live_crm_ids.has(a_id):
				agents.remove_at(i)

## 소매치기 표적(취객·빈집) — 순라청 관리자가 사건 장소를 정할 때 부른다. 빈 사전이면 가게.
func street_theft_target() -> Dictionary:
	return StreetLife.theft_target(self)

## 종루 타종(매달 초하루·계절이 바뀔 때 Main이 부름). 종루가 없으면 false.
func ring_bell() -> bool:
	if _jongnu.x < 0:
		return false
	bell_boost = 30.0
	bell_ring_t = 3.0
	# 종루 가까운 길손 몇에게 한마디
	var said := 0
	for a: Dictionary in agents:
		if said >= 3:
			break
		if a.get("trip", false) and absf(float(a["x"]) - float(_jongnu.x)) + absf(float(a["y"]) - float(_jongnu.y)) <= 10.0:
			a["bubble_text"] = ["여민각 종이 울리네, 서두르세!", "파루(罷漏)로구나, 장 열 시간이오!", "종소리 참 맑구먼!"][randi() % 3]
			a["bubble_timer"] = 2.5
			said += 1
	return true

## 서장대가 있으면 야조를 연다(약 90초). 없으면 false.
func start_yajo() -> bool:
	var has_sj := false
	for y in range(grid.size):
		for x in range(grid.size):
			var b: String = grid.grid[y][x]["building"]
			if b == "seojangdae" and not grid.grid[y][x].has("wall_build"):
				has_sj = true
	if not has_sj:
		return false
	yajo_t = 90.0
	return true

## 새로 지은 포루(pr2)가 있으면 포격 훈련 시작
func start_cannon_drill() -> bool:
	for y in range(grid.size):
		for x in range(grid.size):
			var t: Dictionary = grid.grid[y][x]
			if t["building"] == "poru" and t.has("pr2") and not t.has("wall_build"):
				drill_t = 0.0
				_drill_shots = 0
				return true
	return false

## 행궁 마당 재판: 45~70초마다 하나(좀도둑 문초·화적 문초(최근 도적 침입 시)·백성 송사)
func _manage_haenggung_court(delta: float) -> void:
	# PORT-TRACE [재판은 관아에서]: 송사·문초·칼 쓴 죄수는 유수부 관아(TrialManager·관아 장면)로 옮겼다 — 행궁 마당에선 열지 않는다
	hg_trial_t = 0.0
	if true:
		return
	if _haenggung_gate.x < 0:
		return
	if hg_trial_t > 0.0:
		hg_trial_t -= delta
		return
	_hg_next -= delta
	if _hg_next <= 0.0:
		_hg_next = randf_range(45.0, 70.0)
		var kinds := ["thief", "lawsuit", "thief"]
		if sim and sim.bandit_raid_count > 0 and randf() < 0.4:
			kinds = ["bandit"]
		hg_kind = kinds[randi() % kinds.size()]
		hg_trial_len = 22.0 if hg_kind == "bandit" else 16.0
		hg_trial_t = hg_trial_len

# ============================================================ 생태계 2단계: 사포수 · 맹수 패닉 · 환자 후송
## PORT-TRACE [환자 후송]: 다친 사람(호환·화재·석전·공성 등)을 가장 가까운 약방(약방 가게) 또는 화성행궁(내의원)으로 들것 후송.
func spawn_patient(from: Vector2i, cause: String, patient_sheet: String = "") -> bool:
	var best := Vector2i(-1, -1)
	var bd := 9999
	for sp: Vector2i in _shop_cache:
		if String(grid.grid[sp.y][sp.x].get("trade", "")) == "herb":
			var d := absi(sp.x - from.x) + absi(sp.y - from.y)
			if d < bd:
				bd = d
				best = sp
	if best.x < 0 and _haenggung_gate.x >= 0:
		best = _haenggung_gate
	if best.x < 0: # 약방·행궁이 없으면 가까운 관아·순라청으로
		for cand: Vector2i in _gwana_cache + _patrol_cache:
			var d2 := absi(cand.x - from.x) + absi(cand.y - from.y)
			if d2 < bd:
				bd = d2
				best = cand
	if best.x < 0:
		return false
	var ag := _add_spot_agent("stretcher", from, {"target": best, "cause": cause, "patient_sheet": patient_sheet})
	ag["is_spot"] = false
	return true
## 호랑이(맹수) 출현 여부 조회 (마을 실질 호환 위기 상태 감지 — 외부 레이어 및 UI/축제 연동용)
func has_active_tiger() -> bool:
	# 1. 조정에서 포호책(호랑이 습격 위기)이 공식 활성화된 경우
	if court != null and court.tiger.get("active", false):
		return true
	# 2. 호랑이가 마을 안전거리(50칸) 이내로 침입하여 민가/가축을 습격하는 실질적 호환 상황
	for a: Dictionary in agents:
		if a.get("type", "") == "tiger" and not a.get("is_dead", false) and not a.has("doomed"):
			var apos := Vector2i(int(a.get("x", 0.0)), int(a.get("y", 0.0)))
			if not _is_wildlife_safe_zone(apos, 50) or a.get("state", "") in ["stalk_village", "raid_house"]:
				return true
	return false

## 호랑이가 완전히 사라졌을 때(퇴치, 소멸, 산속 도주) 은신 백성 일괄 복귀
func _on_tiger_vanished() -> void:
	for a: Dictionary in agents:
		if a.get("tiger_sheltered", false):
			a["tiger_sheltered"] = false
			a["is_hidden_shelter"] = false
			a["state"] = a.get("original_state", "walk")
			a["bubble_text"] = ["휴, 범이 물러갔구나!", "살았다! 이제 괜찮은 게지?", "안도라... 무사해서 다행이오."][randi() % 3]
			a["bubble_timer"] = 3.5

## 호랑이 피신 에이전트 업데이트: 민가(집)로 달려가 안으로 쏙 들어가 숨기
func _update_shelter_agent(a: Dictionary, delta: float) -> void:
	if a.get("is_hidden_shelter", false):
		return # 이미 집 안에 안전하게 숨어있음 (렌더링도 생략)

	var cur := Vector2(float(a["x"]), float(a["y"]))
	var target_tile: Vector2i = a.get("shelter_target", a.get("home_tile", Vector2i(int(a["x"]), int(a["y"]))))
	var tgt := Vector2(float(target_tile.x) + 0.5, float(target_tile.y) + 0.5)

	# PORT-TRACE [피신처 문 앞]: 피신처가 행궁·관아처럼 안으로 걸어 들어갈 수 없는 건물이면 문 앞에서 더 다가가지 못해
	# 도착으로 치지 않고 문 앞에 계속 서 있었다 — 1.5초 동안 더 가까워지지 못하면 문으로 들어간 것으로 본다.
	var dist := cur.distance_to(tgt)
	var best: float = float(a.get("sh_best", 99999.0))
	if dist < best - 0.05:
		a["sh_best"] = dist
		a["sh_stall"] = 0.0
	else:
		a["sh_stall"] = float(a.get("sh_stall", 0.0)) + delta
	if dist <= 0.8 or float(a.get("sh_stall", 0.0)) >= 1.5:
		a["is_hidden_shelter"] = true
		a["state"] = "hidden_in_shelter"
		a["bubble_text"] = ""
		a["bubble_timer"] = 0.0
		a.erase("sh_best")
		a.erase("sh_stall")
	else:
		_move_agent_towards(a, tgt, delta, float(a.get("speed", 1.0)) * 1.6)

## 맹수(호랑이·늑대·멧돼지) 패닉 관리:
## 호랑이 출현 시 전체 민간인/놀이패/상인이 집으로 도망쳐 숨고(shelter_in_house),
## 호랑이가 사라지면 원래 상태로 일제히 복귀한다.
func _manage_panic(delta: float) -> void:
	_casualty_cd = maxf(0.0, _casualty_cd - delta)
	_panic_timer -= delta
	if _panic_timer > 0.0:
		return
	_panic_timer = 0.4

	# 1. 호랑이 출현 상태 감지 및 전환
	var active_tiger := has_active_tiger()
	if active_tiger and not _tiger_alert_active:
		_tiger_alert_active = true
		var screamed_once := false
		for a: Dictionary in agents:
			if a.get("is_wild", false) or a.get("is_dead", false):
				continue
			var at: String = String(a.get("type", ""))
			if at in ["saposu", "chakhogapsa", "patrol_soldier", "beater", "marksman", "bait", "stretcher"]:
				continue
			if not a.get("tiger_sheltered", false):
				a["tiger_sheltered"] = true
				a["is_hidden_shelter"] = false
				a["original_state"] = a.get("state", "walk")
				a["state"] = "shelter_in_house"
				var sh_pos: Vector2i = a.get("home_tile", Vector2i(-1, -1))
				if sh_pos.x < 0 or not grid.in_bounds(sh_pos.x, sh_pos.y):
					sh_pos = _find_nearest_shelter_house(Vector2i(int(a["x"]), int(a["y"])))
				a["shelter_target"] = sh_pos
				a["bubble_text"] = ["호랑이다! 집으로 숨어라!", "범이 나타났다! 어서 안으로!", "문 걸어 잠가라!"][randi() % 3]
				a["bubble_timer"] = 3.5
				if not screamed_once:
					screamed_once = true
					emit_signal("sfx", "scream")
	elif not active_tiger and _tiger_alert_active:
		_tiger_alert_active = false
		_on_tiger_vanished()

	# 2. 근접 맹수 습격 및 늑대/멧돼지 국소 패닉 처리
	var beasts: Array[Dictionary] = []
	for a: Dictionary in agents:
		var t: String = a.get("type", "")
		if (t in ["tiger", "wolf"] and not a.has("doomed") and not a.get("is_dead", false)) or (t == "wild_boar" and a.get("state", "") == "wander"):
			beasts.append(a)
	if beasts.is_empty():
		return
	var screamed := false
	for b: Dictionary in beasts:
		var bp := Vector2(float(b["x"]), float(b["y"]))
		var reach := 3.5 if b["type"] != "wild_boar" else 2.0
		for a2: Dictionary in agents:
			if a2.get("is_wild", false) or a2.get("is_spot", false) or a2.get("is_dead", false) or a2.get("is_hidden_shelter", false):
				continue
			if String(a2.get("type", "")) in ["saposu", "hunter", "chakhogapsa", "beater", "marksman", "bait", "patrol_soldier", "firefighter_soldier", "bandit", "stretcher"]:
				continue
			var ap := Vector2(float(a2["x"]), float(a2["y"]))
			var d := ap.distance_to(bp)
			if d > reach:
				continue
			if d < 0.7 and b["type"] != "wild_boar" and _casualty_cd <= 0.0:
				_casualty_cd = 6.0
				a2["is_dead"] = true
				spawn_patient(Vector2i(int(ap.x), int(ap.y)), "호환")
				if sim:
					sim.population = maxi(10, sim.population - 1)
					sim.loyalty = maxi(0, sim.loyalty - 1)
				emit_signal("sfx", "roar")
				continue
			if float(a2.get("panic_t", 0.0)) <= 0.0 and not a2.get("tiger_sheltered", false):
				a2["panic_t"] = 4.0
				a2["flee_from"] = bp
				a2["bubble_text"] = "짐승이다! 도망쳐!"
				a2["bubble_timer"] = 2.5
				if not screamed:
					screamed = true
					emit_signal("sfx", "scream")

## PORT-TRACE [사포수]: 조총을 멘 사포수 2~3명이 산·들(숲·바위 칸)에서 무리지어 나타난다. 우두머리가 사냥감을 찾고 나머지는
## 뒤따른다. 사냥감에 3칸까지 다가가면 조총을 겨눠(1.5초) 쏜다(총구 불꽃·효과음). 평시엔 사슴·멧돼지·토끼·늑대를 잡아
## 지게에 지고 공방에 납품(금 +40), 호포령(조정 포호책 발동 = 호환 위기) 중엔 호랑이부터 쫓고, 잡으면 행궁 마당에서
## 호랑이 가죽을 펼쳐 바치고 상금을 받는다(금 +150, 민심 +3, 호환 해결·2년 안전).
func _manage_saposu(delta: float) -> void:
	if _res_cache.is_empty() and _com_cache.is_empty():
		return

	# 마을 내 잔존/침범 위협 짐승이 있으면 즉시 스폰 트리거
	var has_threat: bool = false
	for o: Dictionary in agents:
		if o.get("is_threat_target", false) and not o.get("is_dead", false):
			has_threat = true
			break

	_saposu_timer -= delta
	if has_threat:
		_saposu_timer = minf(_saposu_timer, 0.0) # 위협 시 즉각 출동

	if _saposu_timer > 0.0:
		return
	_saposu_timer = 25.0

	for a: Dictionary in agents:
		if a.get("type", "") == "saposu" and a.get("leader", false) and not a.get("is_dead", false):
			return

	# 스폰 위치: 위협 출동 시 마을(민가/도로) 우선, 평시에는 산악 지형에서 출동
	var sp: Vector2i = Vector2i(-1, -1)
	if has_threat:
		if not _res_cache.is_empty():
			sp = _res_cache[randi() % _res_cache.size()]
		elif not _roads_cache.is_empty():
			sp = _roads_cache[randi() % _roads_cache.size()]

	if sp.x < 0:
		var pool: Array[Vector2i] = _mountain_cache if not _mountain_cache.is_empty() else (_mountain_forest_cache if not _mountain_forest_cache.is_empty() else _forest_cache)
		if not pool.is_empty():
			sp = pool[randi() % pool.size()]
		elif not _roads_cache.is_empty():
			sp = _roads_cache[randi() % _roads_cache.size()]
		else:
			return

	var n := randi_range(2, 3)
	var leader := _add_road_agent("saposu", sp)
	leader["leader"] = true
	leader["state"] = "search"
	leader["speed"] = 0.82
	leader["search_throttle"] = 0.0
	leader["bubble_text"] = "마을에 산짐승이 나타났다! 서둘러 조총을 메고 출동하세!" if has_threat else "화승에 불 댕기고 산으로 가세!"
	leader["bubble_timer"] = 3.5
	for i in range(n - 1):
		var f := _add_road_agent("saposu", sp)
		f["follow_id"] = leader["id"]
		f["slot"] = i + 1
		f["speed"] = 0.92

func _hoporyeong() -> bool:
	return court != null and court.tiger.get("active", false)

func _update_saposu(a: Dictionary, delta: float) -> void:
	var cur := Vector2(float(a["x"]), float(a["y"]))
	var _on_screen: bool = is_world_pos_on_screen(cur)

	a["fire_t"] = maxf(0.0, float(a.get("fire_t", 0.0)) - delta)
	if a.has("follow_id"):
		var lead: Dictionary = {}
		for o: Dictionary in agents:
			if o.get("id", -1) == a["follow_id"]:
				lead = o
				break
		if lead.is_empty() or lead.get("is_dead", false):
			a["is_dead"] = true
			return
		a["state"] = lead.get("state", "")
		a["carry"] = lead.get("carry", "")
		if lead.get("state", "") == "aim":
			a["aim_at"] = lead.get("aim_at", Vector2.ZERO)
			if float(lead.get("fire_t", 0.0)) > 0.2 and float(a.get("fire_t", 0.0)) <= 0.0 and randf() < 0.5:
				a["fire_t"] = 0.25
		var slot := float(a.get("slot", 1))
		var ld: Vector2 = lead.get("dir", Vector2.RIGHT)
		var tgt := Vector2(float(lead["x"]), float(lead["y"])) - ld * 0.7 * slot + Vector2(-ld.y, ld.x) * 0.35 * (1.0 if int(slot) % 2 == 0 else -1.0)
		if cur.distance_to(tgt) > 0.25:
			_move_agent_towards(a, tgt, delta, float(lead.get("speed", 0.8)) * 1.15)
		return

	a["state_timer"] = float(a.get("state_timer", 0.0)) - delta
	match String(a.get("state", "search")):
		"search":
			a["age"] = float(a.get("age", 0.0)) + delta
			if float(a["age"]) > 160.0:
				a["state"] = "leave"
				return

			var best: Dictionary = find_target_animal(cur, a)
			if best.is_empty():
				# 타깃이 없을 때 외곽 산지 타일로 원정 순찰 (Patrol & Hunt)
				var pool: Array[Vector2i] = _mountain_cache if not _mountain_cache.is_empty() else (_mountain_forest_cache if not _mountain_forest_cache.is_empty() else _forest_cache)
				if not a.has("roam") or cur.distance_to(a["roam"]) < 0.6:
					if not pool.is_empty():
						var r: Vector2i = pool[randi() % pool.size()]
						a["roam"] = Vector2(float(r.x) + 0.5, float(r.y) + 0.5)
				if a.has("roam"):
					_move_agent_towards(a, a["roam"], delta, float(a["speed"]))
				return

			var bp := Vector2(float(best["x"]), float(best["y"]))
			var is_threat: bool = best.get("is_threat_target", false)
			if cur.distance_to(bp) <= 3.0:
				a["state"] = "aim"
				a["state_timer"] = 1.5
				a["target_id"] = best["id"]
				a["target_animal_id"] = best["id"]
				a["aim_at"] = bp
				if is_threat:
					a["bubble_text"] = "마을 침범 짐승이다! 조총을 겨눠라!"
				else:
					a["bubble_text"] = "숨 죽여라… 겨눠!"
				a["bubble_timer"] = 1.4
			else:
				if is_threat and float(a.get("bubble_timer", 0.0)) <= 0.0 and randf() < 0.05:
					a["bubble_text"] = "마을의 산짐승을 소탕하러 간다!"
					a["bubble_timer"] = 2.5
				_move_agent_towards(a, bp, delta, float(a["speed"]))

		"aim":
			if float(a["state_timer"]) <= 0.0:
				a["fire_t"] = 0.3
				emit_signal("sfx", "gun")
				var kill_type := ""
				var was_threat := false
				for o2: Dictionary in agents:
					if o2.get("id", -1) == a.get("target_id", -2) and not o2.get("is_dead", false):
						kill_type = o2.get("type", "")
						if kill_type == "tiger" and not _hoporyeong():
							# 호포제(호포령) 미발동 시 호랑이 사냥 원천 차단
							a["state"] = "search"
							return
						was_threat = o2.get("is_threat_target", false)
						safe_remove_agent(o2)
						break
				if kill_type == "":
					a["state"] = "search"
					return
				if kill_type == "tiger" and _hoporyeong():
					a["carry"] = "tiger"
					a["state"] = "to_palace" if _haenggung_gate.x >= 0 else "to_workshop"
					a["bubble_text"] = "범을 잡았다! 호포령이니 행궁에 바치세!"
					court.tiger["active"] = false
					court.tiger["solved"] = true
					if sim:
						sim.tiger_cooldown_turns = 24 # 2년
					court.emit_signal("notice", "호포령에 따라 사포수들이 조총으로 맹호를 잡았습니다! 행궁에 호랑이 가죽을 바치러 갑니다.")
				else:
					a["carry"] = kill_type
					a["state"] = "to_workshop"
					if was_threat:
						a["bubble_text"] = "마을 산짐승 소탕 완료! 지게에 싣고 공방으로 가세."
					else:
						a["bubble_text"] = "명중이오! 지게에 싣고 공방으로 가세."
				a["bubble_timer"] = 3.0
				var dest := Vector2i(-1, -1)
				if a["state"] == "to_palace":
					dest = _haenggung_gate
				elif not _workshop_cache.is_empty():
					dest = _workshop_cache[randi() % _workshop_cache.size()]
				elif not _shop_cache.is_empty():
					dest = _shop_cache[randi() % _shop_cache.size()]
				if dest.x < 0:
					a["state"] = "leave"
				a["dest"] = dest

		"to_workshop", "to_palace":
			var dt: Vector2i = a.get("dest", Vector2i(-1, -1))
			var goal := Vector2(float(dt.x) + 0.5, float(dt.y) + 0.5)
			if cur.distance_to(goal) < 0.5 or _entry_for(dt) == Vector2i(int(floor(cur.x)), int(floor(cur.y))):
				if a["state"] == "to_palace":
					a["state"] = "present"
					a["state_timer"] = 7.0
					a["bubble_text"] = "호랑이 가죽을 바치옵니다!"
					a["bubble_timer"] = 3.5
					if sim:
						sim.gold += 150
						sim.loyalty = mini(100, sim.loyalty + 3)
				else:
					a["state"] = "deliver"
					a["state_timer"] = 3.0
					a["bubble_text"] = "가죽과 고기 납품이오!"
					a["bubble_timer"] = 2.5
					if sim:
						sim.gold += 40
			else:
				_move_agent_towards(a, goal, delta, 0.75)

		"present", "deliver":
			if float(a["state_timer"]) <= 0.0:
				if a["state"] == "present":
					a["bubble_text"] = "상금 쉰 냥이라! 성은이 망극하오!"
					a["bubble_timer"] = 2.5
				a["carry"] = ""

				# 마을 내에 또 다른 침범 위협 짐승이 남아있는지 확인
				var has_more_threat: bool = false
				for o3: Dictionary in agents:
					if o3.get("is_threat_target", false) and not o3.get("is_dead", false):
						has_more_threat = true
						break
				if has_more_threat:
					a["state"] = "search"
					a["search_throttle"] = 0.0
					a["bubble_text"] = "마을에 아직 산짐승이 남았구나! 다음 놈을 쫓세!"
					a["bubble_timer"] = 3.0
				else:
					a["state"] = "leave"
					a["state_timer"] = 6.0

		"leave":
			# 숲 또는 산지로 돌아가며 사라짐
			a["state_timer"] = float(a.get("state_timer", 6.0)) - delta
			if float(a["state_timer"]) <= 0.0:
				a["is_dead"] = true
				return
			var pool_leave: Array[Vector2i] = _mountain_cache if not _mountain_cache.is_empty() else _forest_cache
			if not pool_leave.is_empty():
				var fz: Vector2i = pool_leave[0]
				_move_agent_towards(a, Vector2(float(fz.x) + 0.5, float(fz.y) + 0.5), delta, 0.8)

# ============================================================
# 조선 후기 6대 신분·직업군 고유 작명, 거점 스폰 및 FSM 시스템
# ============================================================

## 신분별 전용 작명 제너레이터 (O(1) 캐시 테이블 참조)
func generate_npc_name(job_type: int) -> String:
	match job_type:
		JobType.JUNGIN:
			var p: String = NAMES_JUNGIN_PREFIX[randi() % NAMES_JUNGIN_PREFIX.size()]
			var g: String = NAMES_JUNGIN_GIVEN[randi() % NAMES_JUNGIN_GIVEN.size()]
			return "%s %s" % [p, g]
		JobType.AJEOUN:
			var p: String = NAMES_AJEOUN_PREFIX[randi() % NAMES_AJEOUN_PREFIX.size()]
			var g: String = NAMES_AJEOUN_GIVEN[randi() % NAMES_AJEOUN_GIVEN.size()]
			return "%s %s" % [p, g]
		JobType.ARTISAN:
			var p: String = NAMES_ARTISAN_PREFIX[randi() % NAMES_ARTISAN_PREFIX.size()]
			var g: String = NAMES_ARTISAN_GIVEN[randi() % NAMES_ARTISAN_GIVEN.size()]
			return "%s %s" % [p, g]
		JobType.BOBUSANG:
			var p: String = NAMES_BOBUSANG_PREFIX[randi() % NAMES_BOBUSANG_PREFIX.size()]
			var g: String = NAMES_BOBUSANG_GIVEN[randi() % NAMES_BOBUSANG_GIVEN.size()]
			return "%s %s" % [p, g]
		JobType.MONK_SOLDIER:
			var p: String = NAMES_MONK_SOLDIER_PREFIX[randi() % NAMES_MONK_SOLDIER_PREFIX.size()]
			var g: String = NAMES_MONK_SOLDIER_GIVEN[randi() % NAMES_MONK_SOLDIER_GIVEN.size()]
			return "%s %s" % [p, g]
		JobType.BUTCHER:
			var p: String = NAMES_BUTCHER_PREFIX[randi() % NAMES_BUTCHER_PREFIX.size()]
			var g: String = NAMES_BUTCHER_GIVEN[randi() % NAMES_BUTCHER_GIVEN.size()]
			return "%s %s" % [p, g]
		_:
			return "백성 김돌쇠"

## 6대 직업군 거점 스폰 외부 인터페이스
func spawn_specific_artisan(workshop_pos: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	return DistrictSpawner.spawn_specific_artisan(self, workshop_pos)

func spawn_bobusang(market_pos: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	return DistrictSpawner.spawn_bobusang(self, market_pos)

func spawn_jungin(base_pos: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	return DistrictSpawner.spawn_jungin(self, base_pos)

func spawn_ajeoun(office_pos: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	return DistrictSpawner.spawn_ajeoun(self, office_pos)

func spawn_monk_soldier(temple_pos: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	return DistrictSpawner.spawn_monk_soldier(self, temple_pos)

func spawn_butcher(shack_pos: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	return DistrictSpawner.spawn_butcher(self, shack_pos)

## 6대 직업군 주기적 거점 관리
func _manage_district_professionals(_delta: float = 0.0) -> void:
	var has_settlement: bool = (not _res_cache.is_empty() or not _com_cache.is_empty() or not _office_cache.is_empty() or not _roads_cache.is_empty())
	if not has_settlement:
		return
	DistrictSpawner.spawn_all_district_professionals(self)

## 6대 직업군 고유 순환 FSM 업데이트
func _update_professional_agent(a: Dictionary, delta: float) -> void:
	var j_type: int = NPCBase.safe_job_type(a.get("job_type", JobType.COMMONER))
	var st: String = a.get("state", "work")
	var stimer: float = float(a.get("state_timer", 0.0)) - delta
	a["state_timer"] = stimer

	var wps: Array = a.get("waypoints", [])
	var wp_idx: int = int(a.get("waypoint_index", 0))

	var extra: Dictionary = a.get("extra", {})
	if j_type == JobType.ARTISAN:
		extra["hammer_anim"] = float(extra.get("hammer_anim", 0.0)) + delta * 3.5
		a["extra"] = extra
	elif j_type == JobType.BUTCHER:
		extra["tanning_anim"] = float(extra.get("tanning_anim", 0.0)) + delta * 3.0
		a["extra"] = extra

	match st:
		"work", "rest":
			if stimer <= 0.0:
				if not wps.is_empty():
					a["state"] = "travel" if j_type in [JobType.JUNGIN, JobType.ARTISAN, JobType.BOBUSANG, JobType.BUTCHER] else "patrol"
					a["state_timer"] = randf_range(12.0, 20.0)
					wp_idx = (wp_idx + 1) % wps.size()
					a["waypoint_index"] = wp_idx
					_set_professional_bubble(a, j_type, a["state"])
				else:
					a["state_timer"] = randf_range(5.0, 9.0)

		"travel", "patrol":
			if wps.is_empty():
				a["state"] = "work"
				a["state_timer"] = 5.0
				return

			var tg_tile: Vector2i = wps[wp_idx]
			var tg_pos := Vector2(float(tg_tile.x) + 0.5, float(tg_tile.y) + 0.5)
			var cur := Vector2(float(a["x"]), float(a["y"]))
			var dist: float = cur.distance_to(tg_pos)

			if dist < 0.6 or stimer <= 0.0:
				a["state"] = "work" if j_type != JobType.MONK_SOLDIER else (["work", "rest"][randi() % 2])
				a["state_timer"] = randf_range(5.0, 9.0)
				_set_professional_bubble(a, j_type, a["state"])
			else:
				var spd: float = float(a.get("speed", 1.0))
				_move_agent_towards(a, tg_pos, delta, spd)

## 직업별 상황 대사 말풍선 설정
func _set_professional_bubble(a: Dictionary, j_type: int, state: String) -> void:
	# PORT-TRACE [신분·직업 말투]: 중인 의원은 점잖은 하오체, 아전은 관청 말투, 장인은 투박한 하게체,
	# 보부상은 장사꾼 너스레(~수다), 승군은 염불, 백정(천민)은 몸을 낮춘 말투(~입죠·~습니다요)
	if a.get("bubble_timer", 0.0) > 0.0:
		return
	var work := state == "work" or state == "rest"
	var lines: Array = []
	match j_type:
		JobType.JUNGIN:
			lines = ["탕약이 다 달여졌으니 식기 전에 드시오.", "맥을 짚어 보니 기운이 허하오. 보약 한 첩 지어 드리리다.", "새로 들인 약재를 꼼꼼히 살피는 중이오."] if work else ["왕진 가는 길이니 길 좀 비켜 주시오.", "행궁에 입진하러 가오."]
		JobType.AJEOUN:
			lines = ["관아 장부를 맞춰 보는 중이오.", "결세와 호포 내역을 한 치 어김없이 따지시오!"] if work else ["호구 조사 나왔소! 식구 수를 바로 대시오.", "장터 말과 되가 바른지 살피러 왔소."]
		JobType.ARTISAN:
			lines = ["끌 끝이 한 치만 어긋나도 다 버린다네.", "모루에 쇠를 달궈 정과 망치를 벼리는 중이네."] if work else ["성벽 보수 현장에 자재 보러 가네.", "공방으로 돌아가 연장 챙겨야지."]
		JobType.BOBUSANG:
			lines = ["자, 골라 보시오! 비단이오, 바늘이오, 참빗이오!", "개성 인삼 왔수다! 한 뿌리 들이시오!"] if work else ["삼남 장터 돌고 왔수다, 이번엔 수원장이오!", "객주에 봇짐 부리러 가세나."]
		JobType.MONK_SOLDIER:
			lines = ["나무아미타불 관세음보살...", "잠시 숨을 고르고 호국을 위해 기도하세."] if work else ["성곽 순찰로를 돌며 경계를 늦추지 마라.", "수원천 제방을 점검하여 수해를 막으리라."]
		JobType.BUTCHER:
			lines = ["가죽 무두질하는 중입죠. 냄새가 좀 나도 용서하십쇼.", "이번 소가죽은 질이 참 좋습니다요."] if work else ["손질한 고기를 저자에 대러 갑니다요.", "천변 움막으로 돌아가 칼을 갈아야겠습죠."]
	if not lines.is_empty():
		a["bubble_text"] = String(lines[randi() % lines.size()])
		a["bubble_timer"] = 3.5
## [_update_plaza_events]: 저잣거리 장마당(plaza kind="market") 공터를 활기차게 채우는
## 난전·사당패·쉼터 팝업 이벤트를 오브젝트 풀링 방식으로 관리한다.
## - 화면 밖 공터는 연산을 동결(타이머만 감소)하여 프레임 드롭 방지.
## - 동시 최대 PLAZA_MAX_EVENTS개의 이벤트를 유지하고, 각 이벤트는 NPC
##   에이전트 딕셔너리 형태로 agents 배열에 풀링된다.
## - 이벤트 종료 후 자동 복귀(is_dead=true)하여 메모리 누수 방지.
func _update_plaza_events() -> void:
	if _market_plaza_cache.is_empty() or sim == null:
		return
	# 만료된 이벤트 제거
	var alive: Array[Dictionary] = []
	for ev: Dictionary in _plaza_events:
		ev["timer"] = float(ev.get("timer", 0.0)) - 30.0
		if float(ev["timer"]) > 0.0:
			alive.append(ev)
		else:
			# 이벤트 종료 — 해당 에이전트 퇴거(is_dead 플래그)
			for ev_ag: Dictionary in ev.get("agents", []):
				ev_ag["is_dead"] = true
	_plaza_events = alive

	# 비어 있는 공터에 새 이벤트 스폰
	if _plaza_events.size() >= PLAZA_MAX_EVENTS:
		return
	# 아직 이벤트가 없는 공터 후보만 선택
	var used_pos: Dictionary = {}
	for ev2: Dictionary in _plaza_events:
		used_pos[ev2.get("pos", Vector2i(-1, -1))] = true
	var candidates: Array[Vector2i] = []
	for p: Vector2i in _market_plaza_cache:
		if not used_pos.has(p):
			candidates.append(p)
	if candidates.is_empty():
		return
	candidates.shuffle()
	var target_pos: Vector2i = candidates[0]

	# 공터 크기 확인
	var plaza_n: int = 2
	if grid.in_bounds(target_pos.x, target_pos.y):
		var pt_data: Dictionary = grid.grid[target_pos.y][target_pos.x]
		if pt_data.has("plaza"):
			plaza_n = int(pt_data["plaza"].get("n", 2))

	# 이벤트 종류 무작위 선택 (난전/사당패/쉼터 3종)
	var kind: String = PLAZA_EVENT_KINDS[randi() % PLAZA_EVENT_KINDS.size()]
	var ev_agents: Array[Dictionary] = []

	match kind:
		"nan_jeon": # 난전 보따리 상인 1~2명
			var count: int = 1 + (1 if plaza_n >= 3 else 0)
			for i: int in range(count):
				if _next_agent_id > 9000:
					_next_agent_id = 1
				var ag: Dictionary = NPCBase.acquire_agent(
					_next_agent_id, NPCBase.JobType.BOBUSANG,
					target_pos + Vector2i(i, 0),
					["보따리 장수", "난전 상인", "채소 좌판"][i % 3]
				)
				_next_agent_id += 1
				ag["home_tile"] = target_pos
				ag["bubble_text"] = ["짚신·미투리 한 켤레 사시오!", "싱싱한 채소 들어왔소!", "삼남 햅쌀 팝니다!"][randi() % 3]
				ag["bubble_timer"] = 5.0
				ag["waypoints"] = [target_pos]
				ag["is_plaza_event"] = true
				agents.append(ag)
				ev_agents.append(ag)
		"sandang": # 사당패 광대 + 구경꾼 2~3명
			var sandang_pos: Vector2i = target_pos + Vector2i(int(float(plaza_n) / 2.0), int(float(plaza_n) / 2.0))
			if _next_agent_id > 9000:
				_next_agent_id = 1
			var performer: Dictionary = NPCBase.acquire_agent(
				_next_agent_id, NPCBase.JobType.COMMONER, sandang_pos, "광대"
			)
			_next_agent_id += 1
			performer["home_tile"] = sandang_pos
			performer["bubble_text"] = ["얼씨구 절씨구! 좋다 좋아!", "줄타기 한 번 보시겠소?", "징·장구 울려라!"][randi() % 3]
			performer["bubble_timer"] = 6.0
			performer["waypoints"] = [sandang_pos]
			performer["is_plaza_event"] = true
			agents.append(performer)
			ev_agents.append(performer)
			# 구경꾼 2명
			for _j: int in range(2):
				if not _shop_cache.is_empty() or not _res_cache.is_empty():
					var src: Array[Vector2i] = _shop_cache if not _shop_cache.is_empty() else _res_cache
					var crowd_pos: Vector2i = src[randi() % src.size()]
					if _next_agent_id > 9000:
						_next_agent_id = 1
					var crowd: Dictionary = NPCBase.acquire_agent(
						_next_agent_id, NPCBase.JobType.COMMONER, crowd_pos, "구경꾼"
					)
					_next_agent_id += 1
					crowd["home_tile"] = crowd_pos
					crowd["waypoints"] = [crowd_pos, sandang_pos]
					crowd["bubble_text"] = "오호라, 재주도 좋구나!"
					crowd["bubble_timer"] = 4.0
					crowd["is_plaza_event"] = true
					agents.append(crowd)
					ev_agents.append(crowd)
		"shelter": # 물장수 평상 쉼터 — 길손 2명 상주
			for _k: int in range(2):
				var rest_pos: Vector2i = target_pos + Vector2i(_k, 0)
				if _next_agent_id > 9000:
					_next_agent_id = 1
				var rester: Dictionary = NPCBase.acquire_agent(
					_next_agent_id, NPCBase.JobType.COMMONER, rest_pos, "길손"
				)
				_next_agent_id += 1
				rester["home_tile"] = rest_pos
				rester["waypoints"] = [rest_pos]
				rester["bubble_text"] = ["한숨 돌리고 가시지요.", "물 한 사발 드시오.", "발품 파느라 고단하구료."][randi() % 3]
				rester["bubble_timer"] = 5.0
				rester["is_plaza_event"] = true
				agents.append(rester)
				ev_agents.append(rester)

	_plaza_events.append({
		"pos": target_pos,
		"kind": kind,
		"agents": ev_agents,
		"timer": 90.0,
	})

## 공터 클릭 검사용 — InspectPopup이 plaza 타일 클릭 시 호출하여 활기찬 설명 반환
func get_plaza_inspect_text(pos: Vector2i) -> String:
	for ev: Dictionary in _plaza_events:
		if ev.get("pos", Vector2i(-1,-1)) == pos:
			var kind_str: String = ev.get("kind", "")
			match kind_str:
				"nan_jeon":
					return "저잣거리 난전 마당\n짚신·채소·짚공예를 파는 보따리 상인들이\n멍석을 깔고 활발히 흥정을 벌이고 있소.\n지나가는 백성들의 발길을 잡아 저잣거리가\n한층 더 북적이고 활기차오."
				"sandang":
					return "저잣거리 난전 마당\n사당패 광대가 징과 장구를 울리고\n줄타기를 선보이니 백성들이 몰려들어\n손뼉을 치고 탄성을 지르고 있소.\n장터가 온통 흥으로 들썩이오."
				"shelter":
					return "저잣거리 난전 마당\n물장수가 큰 항아리를 내놓고 평상을\n펼쳐두니 지친 길손들이 쉬어 가고\n있소. 차양 아래 도란도란 이야기꽃을\n피우며 잠시 삶의 여유를 나누고 있소."
	return "저잣거리 난전 마당\n비어 있는 공터요. 곧 난전 상인이나\n사당패가 들어서 활기를 불어넣을 것이오.\n백성들의 왕래가 잦아 저잣거리의\n심장부 구실을 하는 요긴한 마당이오."

## 공터 근처 NPC 내비게이션 유인 가중치 상향 (POI 가중치 적용)
## AStarGrid2D의 weight_scale을 낮춰 NPC가 공터 방향을 선호하게 한다.
## _refresh_caches 또는 grid_changed 이후 호출된다.
func _apply_plaza_poi_weights() -> void:
	if _astar_road == null or _market_plaza_cache.is_empty():
		return
	for p: Vector2i in _market_plaza_cache:
		if grid.in_bounds(p.x, p.y) and not _astar_road.is_point_solid(p):
			# 공터 타일 자체는 통행 가중치를 낮춰(0.6) NPC가 자연스럽게 모여들게 함
			_astar_road.set_point_weight_scale(p, 0.6)
			# 공터 반경 2칸도 가중치 약간 낮춤 (수렴 유도)
			for dy: int in range(-2, 3):
				for dx: int in range(-2, 3):
					var np: Vector2i = p + Vector2i(dx, dy)
					if grid.in_bounds(np.x, np.y) and not _astar_road.is_point_solid(np):
						_astar_road.set_point_weight_scale(np, 0.75)

## 서당 완공 및 스캔 시 동자 학동 3~4인 메타데이터 생성 및 배치
func spawn_seodang_students(seodang_pos: Vector2i) -> void:
	var students: Array[Dictionary] = []
	var student_names: Array[String] = ["개똥이", "만복이", "삼돌이", "바우"]
	for i: int in range(4):
		var s_data: Dictionary = {
			"name": student_names[i % student_names.size()],
			"offset_idx": i,
			"sway_offset": float(i) * 0.8,
			"variant": i % 4,
			"voice_line": "검을 현(玄), 누를 황(黃)..." if i == 0 else ("집 우(宇), 집 주(宙)..." if i == 1 else "넓을 홍(洪), 거칠 황(荒)...")
		}
		students.append(s_data)
	_seodang_students[seodang_pos] = students

func get_seodang_students(seodang_pos: Vector2i) -> Array[Dictionary]:
	if _seodang_students.has(seodang_pos):
		return _seodang_students[seodang_pos]
	spawn_seodang_students(seodang_pos)
	return _seodang_students[seodang_pos]

## 천주교 신자 인터랙션 FSM (실학 연구 연동)
func trigger_catholic_interaction(agent_or_pos: Variant) -> Dictionary:
	var is_researched: bool = false
	if sim != null and ("tech_tree" in sim) and sim.tech_tree != null:
		is_researched = sim.tech_tree.has_researched("boyuron", sim) and sim.tech_tree.has_researched("segi", sim)
	elif sim != null:
		is_researched = bool(sim.boyuron and sim.segi_policy)

	var target_agent: Dictionary = {}
	if agent_or_pos is Dictionary:
		target_agent = agent_or_pos as Dictionary
	elif agent_or_pos is Vector2i:
		var vpos: Vector2i = agent_or_pos as Vector2i
		for ag: Dictionary in agents:
			if ag.get("type", "") == "catholic" and (absi(int(ag["x"]) - vpos.x) <= 1 and absi(int(ag["y"]) - vpos.y) <= 1):
				target_agent = ag
				break

	if is_researched:
		if not target_agent.is_empty():
			target_agent["state"] = "prayer"
			target_agent["bubble_text"] = "하늘의 주님, 성상 전하를 굽어살피소서."
			target_agent["bubble_timer"] = 3.5
		return {
			"researched": true,
			"title": "천주교 신자 (서학 유생)",
			"description": "하늘의 주님께서 우리 성상 임금님을 굽어살피십니다.\n임금님의 덕치와 서양의 바른 학문이 함께 빛나니\n백성 모두가 형제처럼 평등하게 살아갈 것입니다.\n나라와 주상 전하를 위해 매일 기도를 올립니다.",
			"texture": InspectNarrativeGenerator.get_portrait("scholar")
		}
	else:
		if not target_agent.is_empty():
			trigger_catholic_panic_flee(target_agent)
		return {
			"researched": false,
			"title": "[사학 죄인 체포]",
			"description": "금지된 사학을 믿던 신자가 관헌을 보고 도주하다 붙잡혀 관아로 압송되었습니다.",
			"texture": InspectNarrativeGenerator.get_portrait("patrol_soldier")
		}

## 천주교 신자 혼비백산 도주 및 체포 FSM
func trigger_catholic_panic_flee(agent: Dictionary) -> void:
	agent["state"] = "fleeing"
	agent["bubble_text"] = "히익! 저는 아무것도 모르옵니다! 살려주소서!"
	agent["bubble_timer"] = 2.0
	var cur_pos := Vector2i(int(agent["x"]), int(agent["y"]))
	var flee_tgt: Vector2i = _find_nearest_road(cur_pos)
	if flee_tgt.x < 0:
		flee_tgt = cur_pos + Vector2i(2, 2)
	agent["flee_target"] = flee_tgt

	# 인근 순라군 출동
	var patrol_found: bool = false
	for cand_p: Dictionary in agents:
		if cand_p.get("type", "") in ["patrol_soldier", "guard"]:
			var cand_pos := Vector2i(int(cand_p["x"]), int(cand_p["y"]))
			if absi(cand_pos.x - cur_pos.x) <= 8 and absi(cand_pos.y - cur_pos.y) <= 8:
				cand_p["to_tile"] = flee_tgt
				cand_p["bubble_text"] = "게 섰거라! 사학 죄인이다!"
				cand_p["bubble_timer"] = 2.5
				patrol_found = true
				break
	if not patrol_found and grid != null:
		var sp_pt: Vector2i = flee_tgt
		var new_guard := _add_spot_agent("patrol_soldier", sp_pt, {
			"bubble_text": "게 섰거라! 사학 죄인이다!",
			"bubble_timer": 2.5
		})
		new_guard["speed"] = 1.0
