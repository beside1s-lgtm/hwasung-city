extends Node
class_name UrbanEvolutionManager

## 1820~1900년대 도시 점진 변천 (근대화 시대 전용)
## - 1단계(1820~): 전통 건물 → 석조 건물.
## - 아래 건물 개편은 모두 석조 전환 100% 뒤(2단계)에만 할 수 있다.
## - 연무대는 건물을 눌러 [신식 군사기지 개편]을 할 수 있다(국방력 +150).
## - 축만제·만석거는 건물을 눌러 [호수공원 조성]을 하면 근대 호수공원이 된다(자동 변환 없음).
## - 문화재 보존: 성곽·사대문·수문·군사시설(장대·포루·공심돈·봉돈 등)·화성행궁은 끝까지 그대로 둔다.
##   (게임의 최종 목표가 현대 수원화성과 비교하는 것이므로 화성 유산은 바뀌지 않는다)
## - 2단계(석조 전환 100% 뒤): 저잣거리→상업시설 빌딩, 공방→금융·서비스 구역, 가옥→택지(빌라·양옥),
##   대유둔전(농지)→공업지역 공장(농업 사회 → 공업 사회), 박석길→전철 궤도, 흙길→자동차 도로.
## - 공업 오염: 공업지역 칸 반경 4칸 안의 택지·상업·금융 칸이 오염된다. 오염 칸 20개당 매달 민심 -1(최대 -5).
## - NPC 복식: 1단계와 같은 비율로 한복 → 양복·양장.
## - 해마다 1월에 변환 비율이 (1 + 근대화 가속 점수)%씩 오른다. 가속 점수 0~10 → 연 1~11%.
##   가속 점수 = 서학 진척도(최대 3) + 외교 성공 1회당 0.5(최대 4) + 근대 과학 분야 1개당 0.6(최대 3)
## - 칸·시민마다 고정 난수값(0~1)을 두고 "값 < 비율"이면 근대화된 것으로 본다.
##   비율은 오르기만 하므로 한 번 바뀐 대상은 되돌아가거나 두 번 바뀌지 않는다(중복 변환 없음).
## - 외형·이름만 바뀌고 건물 ID·세수·유지비 계산은 그대로다.
## - 그림은 아직 없다. 에셋이 들어오면 CityLayer·CitizenLayer가 building_stage()·citizen_is_modern()을 보고
##   ASSET_* 경로의 그림을 쓰도록 연결한다. (지금은 상태와 이름만 바뀐다)
## - 근대 BGM: 근대화 진입 때와 그 뒤 36턴(3년)마다 직전 곡과 다른 곡으로 무작위 교체.

signal stage_advanced(stage: int, ratio: float)
signal bgm_changed(track_id: String)

const STAGE_NONE := 0
const STAGE_STONE := 1
const STAGE_METRO := 2

const BGM_TRACKS := ["modern_bgm_01", "modern_bgm_02", "modern_bgm_03", "modern_bgm_04", "modern_bgm_05"]
const BGM_PERIOD_TURNS := 36
const BGM_FADE := 2.0

## 에셋 경로(그림·음원이 들어오면 연결)
const ASSET_BUILDINGS := "res://assets/buildings/modern/"
const ASSET_NPCS := "res://assets/npcs/modern/"
const ASSET_SHEET := "res://assets/buildings/modern/modern_sheet.png"

## 2단계 구획 종류와 명칭. 건물 ID 앞부분으로 가른다(zone_res·res_2·thatch_house_03 등).
const ZONE_RES := "res"
const ZONE_COM := "com"
const ZONE_FIN := "fin"
const ZONE_IND := "ind"
const ZONE_NAMES := {"res": "택지", "com": "상업시설", "fin": "금융·서비스 구역", "ind": "공업지역"}
const ZONE_PREFIXES := {
	"res": ["zone_res", "res_", "house", "thatch_house", "tile_house"],
	"com": ["zone_com", "com_", "market"],
	"fin": ["zone_ind", "ind_", "factory", "workshop", "ws_"],
	"ind": ["zone_agr", "agr_"],
}
const POLLUTION_RADIUS := 4
const POLLUTION_CELLS_PER_POINT := 20
const POLLUTION_MAX_PENALTY := 5
const ROAD_ZONING := {"stone_road": "전철 궤도", "road": "자동차 도로"}
## 문화재(화성 유산): 어떤 단계에서도 바꾸지 않는다
const HERITAGE := [
	"wall", "gate", "jangan", "paldal", "changryong", "hwaseo", "hwahong",
	"seojangdae", "bongdon", "gongsimdon", "poru", "yeonmudae", "banghwasuryu", "yongyeon",
	"haenggung", "haenggung_site", "yeonghwajeong", "yeonghwajeong_site",
]
## 석조 전환 대상이 아닌 것(문화재·자연·도로 등)
const EXCLUDED := ["", "road", "stone_road", "levee", "reservoir", "well", "chukmanje", "chukmanje_site", "manseokgeo", "manseokgeo_site"]

## 저수지 → 근대 호수공원 (건물을 눌러 직접 조성). 저수지 기능(관개·치수)은 그대로다.
const LAKE_PARKS := {
	"chukmanje": {"name": "축만제 호수공원", "sprite": "chukmanje_park", "match": "축만제"},
	"manseokgeo": {"name": "만석거 호수공원", "sprite": "manseokgeo_park", "match": "만석거"},
}
const LAKE_PARK_COST := 30000
## 연무대 → 신식 군사기지 (건물을 눌러 직접 개편). 자동 변환 대상은 아니다.
const MILITARY_BASE_NAME := "연무대 신식 군사기지"
const MILITARY_BASE_COST := 50000
const MILITARY_BASE_DEFENSE := 150
const LAKE_PARK_LOYALTY := 10
const HERITAGE_DECAY_PER_YEAR := 1.5
const HERITAGE_RESTORE_STEP := 10.0
const HERITAGE_RESTORE_COST := 20000
const REPUBLIC_HAENGGUNG_NAME := "대통령궁·국회·법원 (옛 화성행궁)"

static var instance: UrbanEvolutionManager = null

var sim: SimulationCore
var grid: GameGrid
var time_manager: TimeManager

var stone_ratio: float = 0.0   # 1단계 진행률 0~1
var metro_ratio: float = 0.0   # 2단계 진행률 0~1
var current_bgm: String = ""
var lake_parks: Dictionary = {} # "chukmanje"/"manseokgeo" -> true
var plaza_upgrades: Dictionary = {} # "market"/"kids"/"play" -> true
## 근대 상하수도: 우물 → 집수정, 저수지 → 생활용수 공급시설, 수도 연결 대공사(여러 달), 하수처리시설(새 2x2 건물)
var wells_upgraded: bool = false
var reservoirs_upgraded: bool = false
var water_project_started: bool = false
var water_project_done_turns: int = 0
var military_base: bool = false
var civic_upgrades: Dictionary = {} # "gwana"/"patrol"/"firefighter" -> true
var polluted_cells: int = 0     # 지난달 오염된 택지·상업·금융 칸 수
var pollution_penalty: int = 0  # 지난달 오염으로 깎인 민심
var next_bgm_turn: int = 0
## 문화재 보존도(0~100): 화성 문화재(성곽·사대문·수문·군사시설·행궁)의 상태.
## 해마다 조금씩 낡고(-1.5), 침공·반란·전쟁 때 크게 부서진다. [문화재 보수]로 되살린다.
var heritage_condition: float = 100.0
var haenggung_republic: bool = false # 1897 현대 정치체제 전환 뒤 화성행궁 = 대통령궁·국회·법원

func _init() -> void:
	name = "UrbanEvolutionManager"

func setup(s: SimulationCore, g: GameGrid, t: TimeManager) -> void:
	sim = s
	grid = g
	time_manager = t
	UrbanEvolutionManager.instance = self
	if not time_manager.year_changed.is_connected(_on_year_changed):
		time_manager.year_changed.connect(_on_year_changed)
	if not sim.turn_advanced.is_connected(_on_turn):
		sim.turn_advanced.connect(_on_turn)
	if not grid.grid_changed.is_connected(_on_grid_changed):
		grid.grid_changed.connect(_on_grid_changed)

func _on_grid_changed() -> void:
	_rate_cache = -1

static func is_active() -> bool:
	return instance != null and ModernizationManager.is_active()

## 근대화 시대 진입 직후(ModernizationManager.start_modernization)
func on_modernization_started() -> void:
	stone_ratio = 0.0
	metro_ratio = 0.0
	heritage_condition = 100.0
	haenggung_republic = false
	_pick_new_bgm()

# ==================== 문화재 보존도·도시화율 ====================

func damage_heritage(amount: float) -> void:
	heritage_condition = clampf(heritage_condition - amount, 0.0, 100.0)

## 문화재 보수: 20,000냥 → 보존도 +10
func restore_heritage() -> bool:
	if not is_active() or heritage_condition >= 100.0 or sim.gold < HERITAGE_RESTORE_COST:
		return false
	sim.gold -= HERITAGE_RESTORE_COST
	heritage_condition = minf(100.0, heritage_condition + HERITAGE_RESTORE_STEP)
	return true

## 도시화율(0~100) = (석조 전환율 + 대도시화율) / 2
func urbanization_rate() -> int:
	return int(round((stone_ratio + metro_ratio) * 50.0))

# ==================== 가속 점수·연간 진행 ====================

## 근대화 가속 점수(0~10)
func acceleration_score() -> float:
	var mm: ModernizationManager = ModernizationManager.instance
	if mm == null:
		return 0.0
	var done := 0
	for f in ModernizationManager.FIELDS:
		if mm.field_done(f["id"]):
			done += 1
	var west := float(mm.western_progress()) / 100.0 * 3.0
	var diplo := minf(float(mm.diplomacy_successes) * 0.5, 4.0)
	var sci := minf(float(done) * 0.6, 3.0)
	return clampf(west + diplo + sci, 0.0, 10.0)

## 한 해 변환 비율(0.01~0.11)
func annual_rate() -> float:
	return (1.0 + acceleration_score()) / 100.0

func current_stage() -> int:
	if metro_ratio > 0.0 or stone_ratio >= 1.0:
		return STAGE_METRO
	return STAGE_STONE if is_active() else STAGE_NONE

func _on_year_changed(_y: int) -> void:
	if SaveSystem.is_loading or not is_active():
		return
	damage_heritage(HERITAGE_DECAY_PER_YEAR)
	var r := annual_rate()
	if stone_ratio < 1.0:
		stone_ratio = minf(1.0, stone_ratio + r)
		emit_signal("stage_advanced", STAGE_STONE, stone_ratio)
	else:
		metro_ratio = minf(1.0, metro_ratio + r)
		emit_signal("stage_advanced", STAGE_METRO, metro_ratio)
	apply_modern_tiles()

# ==================== 대상별 판정 ====================

## 칸·시민마다 고정된 0~1 값(저장 없이 늘 같다)
static func _hash01(key: String) -> float:
	return float(abs(hash(key)) % 100000) / 100000.0

## 건물 칸의 시대 단계 (0 전통 / 1 석조 / 2 대도시)
func building_stage(x: int, y: int) -> int:
	if not is_active() or grid == null or not grid.in_bounds(x, y):
		return STAGE_NONE
	var t: Dictionary = grid.grid[y][x]
	var b: String = String(t.get("building", ""))
	if is_heritage(t):
		return STAGE_NONE
	# 개편 대상 관공서·학교는 직접 개편하기 전까지 전통 모습 그대로(석조 자동 전환 없음)
	if CIVIC_UPGRADES.has(b.trim_suffix("_site")) or (t.get("plaza") is Dictionary and String(t["plaza"].get("kind", "")) in ["seodang", "seowon"]):
		return STAGE_NONE
	var v := _cell_hash01(x, y, b)
	var zk := zone_kind(b)
	if b in ROAD_ZONING or zk != "":
		if v < metro_ratio:
			return STAGE_METRO
	if zk == ZONE_IND:
		return STAGE_NONE # 둔전은 석조 단계 없이 농지로 남았다가 2단계에 공장이 된다
	if b in EXCLUDED:
		return STAGE_NONE
	return STAGE_STONE if v < stone_ratio else STAGE_NONE

## _hash01("x,y,건물") 캐시: 칸마다 [건물 ID, 값]을 기억해 건물이 그대로면 다시 해시하지 않는다(매달 전체 칸 판정이 렉의 원인이었음)
var _hv_bld := PackedStringArray()
var _hv_val := PackedFloat64Array()
var _pick_h := PackedInt64Array() # 칸마다 근대 그림 고르기용 해시(-1 = 아직 계산 안 함)

func _cell_hash01(x: int, y: int, b: String) -> float:
	var n := grid.size * grid.size
	if _hv_bld.size() != n:
		_hv_bld.resize(n)
		_hv_bld.fill("\n") # 어떤 건물 ID와도 다른 값
		_hv_val.resize(n)
	var i := y * grid.size + x
	if _hv_bld[i] != b:
		_hv_bld[i] = b
		_hv_val[i] = _hash01("%d,%d,%s" % [x, y, b])
	return _hv_val[i]

func _cell_pick(x: int, y: int) -> int:
	var n := grid.size * grid.size
	if _pick_h.size() != n:
		_pick_h.resize(n)
		_pick_h.fill(-1)
	var i := y * grid.size + x
	if _pick_h[i] < 0:
		_pick_h[i] = absi(hash("%d,%d" % [x, y]))
	return _pick_h[i]

# ==================== 근대 그림 적용 (CityLayer가 칸의 is_modernized·modern_id로 그림을 고른다) ====================

const SPRITE_DIR := "res://assets/sprites/buildings_modern/%s.png"
## 단계·구획별 근대 그림 후보(앞에서부터 파일이 있는 것만 씀). 마지막 이름은 지금 들어 있는 임시 그림.
const MODERN_SPRITES := {
	"stone": {
		"res": ["stone_house_01", "stone_house_02", "stone_house_03", "stone_building"],
		"com": ["stone_shop_01", "stone_shop_02", "stone_building"],
		"fin": ["stone_office_01", "stone_building"],
	},
	"metro": {
		"res": ["villa_01", "villa_02", "brick_mansion_01", "brick_mansion_02", "villa"],
		"com": ["modern_highrise_01", "modern_highrise_02", "modern_highrise"],
		"fin": ["finance_bank_01", "finance_office_01", "service_hotel_01", "service_cafe_01", "stone_building"],
	},
}
static var _sprite_exists := {}
static var _avail_cache := {} # "stone/res" → 파일이 있는 그림 이름들

static func _sprite_ok(id: String) -> bool:
	if not _sprite_exists.has(id):
		_sprite_exists[id] = ResourceLoader.exists(SPRITE_DIR % id)
	return bool(_sprite_exists[id])

## 칸 하나의 근대 그림 이름("" = 전통 그대로). 같은 칸은 늘 같은 그림(칸 좌표로 고정).
func modern_sprite_for(x: int, y: int) -> String:
	if grid == null or not grid.in_bounds(x, y):
		return ""
	var t: Dictionary = grid.grid[y][x]
	var b: String = String(t.get("building", ""))
	# 그림을 바꾸는 건물(우물·가옥·상점·공방)이 아니면 단계 판정부터 건너뛴다
	if b != "well" and not (b.begins_with("res_") or b.begins_with("com_") or b.begins_with("ind_")):
		return ""
	var stage := building_stage(x, y)
	if stage == STAGE_NONE:
		return ""
	if b == "well":
		return WATER_COLLECTOR_SPRITE if wells_upgraded and _sprite_ok(WATER_COLLECTOR_SPRITE) else ""
	if bool(t.get("is_ruined", false)):
		return "" # 지금은 가옥·상점·공방 그림만 바꾼다(둔전·도로·특수 건물은 다음 단계)
	var avail := _avail_sprites("metro" if stage == STAGE_METRO else "stone", zone_kind(b))
	if avail.is_empty():
		return ""
	return String(avail[_cell_pick(x, y) % avail.size()])

static func _avail_sprites(stage_key: String, zk: String) -> Array:
	var k := stage_key + "/" + zk
	if not _avail_cache.has(k):
		var pools: Dictionary = MODERN_SPRITES[stage_key]
		_avail_cache[k] = (pools[zk] as Array).filter(func(id: String) -> bool: return _sprite_ok(id)) if pools.has(zk) else []
	return _avail_cache[k]

## 모든 칸에 근대 표시를 적는다. 바뀐 칸이 있으면 Main의 분할 재굽기(프레임당 정해진 칸 수)로 그 띠만 다시 그린다.
func apply_modern_tiles() -> void:
	if grid == null:
		return
	var changed := 0
	var active := is_active()
	for y in range(grid.size):
		for x in range(grid.size):
			var t: Dictionary = grid.grid[y][x]
			var want := modern_sprite_for(x, y) if active else ""
			if want == "":
				if t.has("modern_id") or bool(t.get("is_modernized", false)):
					t.erase("modern_id")
					t.erase("is_modernized")
					changed += 1
			elif String(t.get("modern_id", "")) != want:
				t["modern_id"] = want
				t["is_modernized"] = true
				changed += 1
	if changed > 0:
		var main := get_parent()
		if main and main.has_method("_rebake_world"):
			main._rebake_world()
		if main and "citizen_layer" in main and main.citizen_layer != null:
			main.citizen_layer._occ_dirty = true # 사람을 가리는 건물 앞 그림도 새 그림으로

## 화성 문화재 칸인지 (건물 ID·수문 표시·시설 ID로 판정)
static func is_heritage(t: Dictionary) -> bool:
	var b: String = String(t.get("building", ""))
	if b in HERITAGE or b.begins_with("gate"):
		return true
	if bool(t.get("is_hwahong", false)) or bool(t.get("is_namsu", false)) or bool(t.get("is_maehyang", false)):
		return true
	var fid: String = String(t.get("facility_id", ""))
	return fid in ["hwahong_mun", "namsu_mun", "maehwang_gyo"]

## 살피기 창 제목으로 호수공원 대상 찾기("" = 해당 없음)
static func lake_park_id_for_title(title: String) -> String:
	for id in LAKE_PARKS:
		if title.contains(String(LAKE_PARKS[id]["match"])):
			return id
	return ""

func is_lake_park(id: String) -> bool:
	return bool(lake_parks.get(id, false))

## 호수공원 조성: 국고 30,000냥 → 민심 +10, 이름·그림이 호수공원으로 바뀐다
func build_lake_park(id: String) -> bool:
	if not upgrades_unlocked() or not LAKE_PARKS.has(id) or is_lake_park(id) or sim.gold < LAKE_PARK_COST:
		return false
	if grid and grid.count_completed(id) == 0:
		return false
	sim.gold -= LAKE_PARK_COST
	sim.loyalty = mini(100, sim.loyalty + LAKE_PARK_LOYALTY)
	lake_parks[id] = true
	apply_landmark_tiles()
	return true

## 건물 ID → 2단계 구획 종류("" = 해당 없음)
static func zone_kind(b: String) -> String:
	for k in ZONE_PREFIXES:
		for pre in ZONE_PREFIXES[k]:
			if b.begins_with(pre):
				return k
	return ""

func _cell_zone(x: int, y: int) -> String:
	var zk := zone_kind(String(grid.grid[y][x].get("building", "")))
	if zk == "" or building_stage(x, y) != STAGE_METRO:
		return ""
	return zk

## 공업 오염: 매달 정산. 공업지역 반경 4칸 안의 택지·상업·금융 칸 수를 세어 민심을 깎는다.
func _process_pollution() -> void:
	polluted_cells = 0
	pollution_penalty = 0
	if grid == null or metro_ratio <= 0.0:
		return
	# 칸마다 구획을 한 번만 판정해 두고 이웃은 표에서 읽는다
	var n := grid.size
	var zones := PackedStringArray()
	zones.resize(n * n)
	var inds: Array[Vector2i] = []
	for y in range(n):
		for x in range(n):
			var cz := _cell_zone(x, y)
			zones[y * n + x] = cz
			if cz == ZONE_IND:
				inds.append(Vector2i(x, y))
	var hit := {}
	for c: Vector2i in inds:
		for ny in range(maxi(0, c.y - POLLUTION_RADIUS), mini(n, c.y + POLLUTION_RADIUS + 1)):
			for nx in range(maxi(0, c.x - POLLUTION_RADIUS), mini(n, c.x + POLLUTION_RADIUS + 1)):
				var z := zones[ny * n + nx]
				if z == ZONE_RES or z == ZONE_COM or z == ZONE_FIN:
					hit[ny * n + nx] = true
	polluted_cells = hit.size()
	@warning_ignore("integer_division")
	pollution_penalty = mini(POLLUTION_MAX_PENALTY, polluted_cells / POLLUTION_CELLS_PER_POINT)
	if pollution_penalty > 0:
		sim.loyalty = maxi(0, sim.loyalty - pollution_penalty)

## 관공서 근대화: 건물을 눌러 개편하면 같은 종류 전체가 바뀌고, 그 건물의 NPC도 근대 복장으로 바뀐다.
const CIVIC_UPGRADES := {
	"gwana": {"match": ["관아", "동헌", "유수부"], "old": "화성유수부 관아", "name": "정부청사", "cost": 40000, "effect": "민심 +5, 왕권 +5",
		"npc": {"npc_ajeon": "npc_modern_official"}},
	"patrol": {"match": ["순라청"], "old": "순라청", "name": "경찰서", "cost": 20000, "effect": "순라청 국방 기여 2배(칸당 30→60)",
		"npc": {"npc_patrol": "npc_modern_police", "patrol_officer": "npc_modern_police"}},
	"firefighter": {"match": ["멸화군", "수성소"], "old": "멸화군 수성소", "name": "소방서", "cost": 20000, "effect": "민심 +5",
		"npc": {"npc_firefighter": "npc_modern_firefighter"}},
	"jinhulso": {"match": ["진휼소"], "old": "진휼소", "name": "복지관", "cost": 20000, "effect": "민심 +5",
		"npc": {}},
	"hyanggyo": {"match": ["향교"], "old": "수원향교", "name": "수원 대학교", "cost": 50000,
		"effect": "서학 연구 속도 +1배, 서당→초등학교·서원→중등학교 전환",
		"npc": {}},
}
## 마당 근대화: 같은 종류 마당 전체가 바뀐다(GameGrid plaza kind 기준). 그림은 buildings_modern/<sprite>.png
const PLAZA_UPGRADES := {
	"market": {"match": "난전", "old": "저잣거리 난전 마당", "name": "시민공원", "sprite": "park_citizen", "cost": 15000, "loyalty": 3},
	"kids": {"match": "동네 놀이터", "old": "골목 어린이 마당", "name": "어린이 놀이터", "sprite": "playground_modern", "cost": 10000, "loyalty": 2},
	"play": {"match": "마당놀이", "old": "여인 놀이마당", "name": "체육공원", "sprite": "sports_park", "cost": 15000, "loyalty": 3},
}

static func plaza_kind_for_title(title: String) -> String:
	if _is_person_title(title):
		return ""
	for k in PLAZA_UPGRADES:
		if title.contains(String(PLAZA_UPGRADES[k]["match"])):
			return k
	return ""

func is_plaza_upgraded(kind: String) -> bool:
	return is_active() and bool(plaza_upgrades.get(kind, false))

## 마당 개편: 석조 전환 뒤, 국고를 내고 민심이 오른다
func build_plaza_upgrade(kind: String) -> bool:
	if not upgrades_unlocked() or not PLAZA_UPGRADES.has(kind) or is_plaza_upgraded(kind):
		return false
	var info: Dictionary = PLAZA_UPGRADES[kind]
	if sim.gold < int(info["cost"]) or grid.list_plazas(kind).is_empty():
		return false
	sim.gold -= int(info["cost"])
	sim.loyalty = mini(100, sim.loyalty + int(info["loyalty"]))
	plaza_upgrades[kind] = true
	var main := get_parent()
	if main and "citizen_layer" in main and main.citizen_layer != null:
		main.citizen_layer._play_dirty = true
	return true

## 개편한 마당의 근대 그림(없으면 null → 옛 마당 장면 그대로)
func plaza_texture(kind: String) -> Texture2D:
	if not is_plaza_upgraded(kind):
		return null
	var id := String(PLAZA_UPGRADES[kind]["sprite"])
	if not _sprite_ok(id):
		return null
	return load(SPRITE_DIR % id) as Texture2D

# ==================== 근대 상하수도 ====================
const WELL_UPGRADE_COST := 10000
const RESERVOIR_UPGRADE_COST := 20000
const WATER_PROJECT_TURNS := 6
const WATER_PROJECT_COST_PER_TURN := 10000
const WATER_COLLECTOR_SPRITE := "water_collector"   # 집수정(우물 칸)
const WATER_PLANT_SPRITE := "water_supply_plant"     # 생활용수 공급시설(저수지 칸)

func water_project_done() -> bool:
	return water_project_done_turns >= WATER_PROJECT_TURNS

## 근대 수도 영향권: 집수정(개편한 우물, 반경 = 우물 반경)·생활용수 공급시설(개편한 저수지, 반경 20)·
## 하수처리시설(반경 20). 수도 연결 대공사가 끝나면 모든 반경이 1.5배.
## 석조 전환 뒤(근대 수도 공사를 할 수 있을 때)부터는 영향권 밖 가옥·상점에 물방울이 뜬다(예전 우물 경고와 같은 표시).
## 물방울이 하나도 없으면 상하수도 보급률 100%.
const WATER_PLANT_RADIUS := 20.0
const SEWAGE_RADIUS := 20.0
const WATER_PROJECT_RADIUS_MULT := 1.5
var _cov_field := PackedByteArray()
var _cov_valid := false
var _rate_cache := -1 # 상하수도 보급률 캐시(지도·수도 시설이 바뀌면 -1) — 근대 HUD가 1초마다 읽는다

func water_modern_active() -> bool:
	return upgrades_unlocked()

func invalidate_water() -> void:
	_cov_valid = false
	_rate_cache = -1
	var main := get_parent()
	if main and "citizen_layer" in main and main.citizen_layer != null:
		main.citizen_layer._drops_dirty = true # 물방울 표시 다시 계산

func _stamp(cx: int, cy: int, r: float) -> void:
	var ri := int(ceil(r))
	for yy in range(maxi(0, cy - ri), mini(grid.size, cy + ri + 1)):
		for xx in range(maxi(0, cx - ri), mini(grid.size, cx + ri + 1)):
			if float((xx - cx) * (xx - cx) + (yy - cy) * (yy - cy)) <= r * r:
				_cov_field[yy * grid.size + xx] = 1

func _build_cov() -> void:
	_cov_field.resize(grid.size * grid.size)
	_cov_field.fill(0)
	var k := WATER_PROJECT_RADIUS_MULT if water_project_done() else 1.0
	for y in range(grid.size):
		for x in range(grid.size):
			var b: String = String(grid.grid[y][x].get("building", ""))
			if b == "well" and wells_upgraded:
				_stamp(x, y, GameGrid.WELL_RADIUS * k)
			elif b == "reservoir" and reservoirs_upgraded:
				_stamp(x, y, WATER_PLANT_RADIUS * k)
			elif b == "sewage":
				_stamp(x, y, SEWAGE_RADIUS * k)
	_cov_valid = true

func water_covered(x: int, y: int) -> bool:
	if not _cov_valid:
		_build_cov()
	return _cov_field[y * grid.size + x] == 1

## 근대 수도 영향권 밖의 가옥·상점(물방울 표시용)
func water_uncovered_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(grid.size):
		for x in range(grid.size):
			var b: String = String(grid.grid[y][x].get("building", ""))
			if (b.begins_with("res_") or b.begins_with("com_")) and not water_covered(x, y):
				out.append(Vector2i(x, y))
	return out

## 상하수도 보급률(0~100) = 근대 수도 영향권 안의 가옥·상점 비율. 석조 전환 전에는 0.
func water_supply_rate() -> int:
	if not is_active() or not water_modern_active():
		return 0
	if _rate_cache >= 0 and _cov_valid:
		return _rate_cache
	var total := 0
	var covered := 0
	for y in range(grid.size):
		for x in range(grid.size):
			var b: String = String(grid.grid[y][x].get("building", ""))
			if b.begins_with("res_") or b.begins_with("com_"):
				total += 1
				if water_covered(x, y):
					covered += 1
	_rate_cache = 100 if total == 0 else int(floor(float(covered) * 100.0 / float(total)))
	return _rate_cache

## 우물 전체를 집수정으로 (석조 전환 뒤)
func upgrade_wells() -> bool:
	if not upgrades_unlocked() or wells_upgraded or sim.gold < WELL_UPGRADE_COST or grid.count_completed("well") == 0:
		return false
	sim.gold -= WELL_UPGRADE_COST
	wells_upgraded = true
	invalidate_water()
	apply_modern_tiles()
	return true

## 저수지 전체를 생활용수 공급시설로 (석조 전환 뒤)
func upgrade_reservoirs() -> bool:
	if not upgrades_unlocked() or reservoirs_upgraded or sim.gold < RESERVOIR_UPGRADE_COST or grid.count_completed("reservoir") == 0:
		return false
	sim.gold -= RESERVOIR_UPGRADE_COST
	reservoirs_upgraded = true
	invalidate_water()
	var main := get_parent()
	if main and main.has_method("_rebake_world"):
		main._rebake_world()
	return true

## 수도 연결 대공사 착공: 매달 10,000냥씩 6달 (국고가 모자란 달은 공사가 멈춤)
func start_water_project() -> bool:
	if not upgrades_unlocked() or water_project_started:
		return false
	water_project_started = true
	return true

func _process_water() -> void:
	invalidate_water() # 한 달 사이 지은·헐린 건물과 하수처리시설 완공을 반영
	if water_project_started and not water_project_done():
		if sim.gold >= WATER_PROJECT_COST_PER_TURN:
			sim.gold -= WATER_PROJECT_COST_PER_TURN
			water_project_done_turns += 1
			if water_project_done():
				invalidate_water()
			if water_project_done() and ModernizationManager.instance:
				ModernizationManager.instance.emit_signal("notice", "수도 연결 대공사가 끝났습니다! 집집마다 수도관으로 맑은 물이 들어갑니다.", "🚰")
	# 보급률 50% 이상이면 매달 민심 +1, 100%면 +2
	var rate := water_supply_rate()
	if rate >= 50:
		sim.loyalty = mini(100, sim.loyalty + (2 if rate >= 100 else 1))

## 저수지 칸 위에 얹을 생활용수 공급시설 그림(개편 전이거나 그림이 없으면 null)
func water_plant_texture() -> Texture2D:
	if not is_active() or not reservoirs_upgraded or not _sprite_ok(WATER_PLANT_SPRITE):
		return null
	return load(SPRITE_DIR % WATER_PLANT_SPRITE) as Texture2D

## 대학교 개편 뒤 학교 이름(살피기 제목)과 학생 NPC(행동 종류 → 근대 그림)
const SCHOOL_TITLES := {"서당": "초등학교", "서원": "중등학교"}
const SCHOOL_NPC_TYPES := {
	"seodang_student": "npc_modern_student", "student": "npc_modern_student",
	"yusaeng": "npc_modern_student", "scholar": "npc_modern_student",
	"seodang_teacher": "npc_modern_official", "teacher": "npc_modern_official",
}
const SECONDARY_PER_ELEMENTARY := 5

## 사람 살피기 창(예: "수원향교 유생 김 씨")은 건물로 보지 않는다
static func _is_person_title(title: String) -> bool:
	for w in ["유생", "학동", "훈장"]:
		if title.contains(w):
			return true
	return false

static func civic_id_for_title(title: String) -> String:
	if _is_person_title(title):
		return ""
	for id in CIVIC_UPGRADES:
		for m in CIVIC_UPGRADES[id]["match"]:
			if title.contains(m):
				return id
	return ""

func is_civic_upgraded(id: String) -> bool:
	return bool(civic_upgrades.get(id, false))

func build_civic_upgrade(id: String) -> bool:
	if not upgrades_unlocked() or not CIVIC_UPGRADES.has(id) or is_civic_upgraded(id):
		return false
	var cost: int = CIVIC_UPGRADES[id]["cost"]
	if sim.gold < cost or (grid and grid.count_completed(id) == 0):
		return false
	sim.gold -= cost
	civic_upgrades[id] = true
	match id:
		"gwana":
			sim.loyalty = mini(100, sim.loyalty + 5)
			sim.authority = mini(100, sim.authority + 5)
		"firefighter", "jinhulso":
			sim.loyalty = mini(100, sim.loyalty + 5)
	apply_landmark_tiles()
	return true

## 근대 관공서 NPC 그림 이름 (바뀌지 않으면 원래 이름 그대로)
func modern_npc_sprite(sprite_id: String) -> String:
	if not is_active():
		return sprite_id
	for id in civic_upgrades:
		if civic_upgrades[id]:
			var m: Dictionary = CIVIC_UPGRADES[id]["npc"]
			if m.has(sprite_id):
				return String(m[sprite_id])
	return sprite_id

## 건물 개편(관공서·호수공원·군사기지·대학교)은 석조 전환이 끝난 뒤(2단계)에만 열린다
func upgrades_unlocked() -> bool:
	return is_active() and stone_ratio >= 1.0

func has_university() -> bool:
	return is_active() and is_civic_upgraded("hyanggyo")

## 시민 행동 종류(type)로 근대 그림 이름 찾기 — 대학교 개편 뒤 학생·교사("" = 그대로)
func modern_npc_for_type(agent_type: String) -> String:
	if has_university():
		return String(SCHOOL_NPC_TYPES.get(agent_type, ""))
	return ""

## 살피기 창 제목을 근대 이름으로 (개편·조성한 것만)
func modern_title(title: String) -> String:
	if not is_active() or _is_person_title(title):
		return title
	if haenggung_republic and title.contains("행궁"):
		return REPUBLIC_HAENGGUNG_NAME
	if wells_upgraded and title.begins_with("마을 공동 우물"):
		return "집수정 (마을 상수도)"
	var pk := plaza_kind_for_title(title)
	if pk != "" and is_plaza_upgraded(pk):
		return String(PLAZA_UPGRADES[pk]["name"])
	for id in CIVIC_UPGRADES:
		if is_civic_upgraded(id):
			for m in CIVIC_UPGRADES[id]["match"]:
				if title.contains(m):
					return String(CIVIC_UPGRADES[id]["name"])
	if has_university():
		for k in SCHOOL_TITLES:
			if title.contains(k):
				return String(SCHOOL_TITLES[k])
	var lake_id := lake_park_id_for_title(title)
	if lake_id != "" and is_lake_park(lake_id):
		return String(LAKE_PARKS[lake_id]["name"])
	if military_base and (title.contains("연무대") or title.contains("동장대")):
		return MILITARY_BASE_NAME
	return title

## 순라청(경찰서) 칸당 국방 기여
func patrol_defense_per_station() -> int:
	return 60 if is_civic_upgraded("patrol") else 30

## 연무대 신식 군사기지 개편: 국고 50,000냥 → 신식군대 국방력 +150
func build_military_base() -> bool:
	if not upgrades_unlocked() or military_base or sim.gold < MILITARY_BASE_COST:
		return false
	if grid and grid.count_completed("yeonmudae") == 0:
		return false
	sim.gold -= MILITARY_BASE_COST
	ModernizationManager.instance.modern_weapon_bonus += MILITARY_BASE_DEFENSE
	military_base = true
	apply_landmark_tiles()
	ModernizationManager.instance.on_military_base_built() # 임오군란
	return true

## 근대화된 칸의 구획 명칭 (해당 없으면 빈 문자열)
func zoning_name(x: int, y: int) -> String:
	var b: String = String(grid.grid[y][x].get("building", "")) if grid and grid.in_bounds(x, y) else ""
	var lake_id := b.trim_suffix("_site")
	if LAKE_PARKS.has(lake_id) and is_lake_park(lake_id):
		return String(LAKE_PARKS[lake_id]["name"])
	if b == "yeonmudae" and military_base:
		return MILITARY_BASE_NAME
	if CIVIC_UPGRADES.has(b.trim_suffix("_site")) and is_civic_upgraded(b.trim_suffix("_site")):
		return String(CIVIC_UPGRADES[b.trim_suffix("_site")]["name"])
	if building_stage(x, y) != STAGE_METRO:
		return ""
	var k := zone_kind(b)
	return String(ZONE_NAMES[k]) if k != "" else String(ROAD_ZONING.get(b, ""))

## 시민 복식이 근대식인지 (시민 고유 키: 이름·ID 등)
func citizen_is_modern(citizen_key: String) -> bool:
	if not is_active():
		return false
	return _hash01("npc:" + citizen_key) < maxf(stone_ratio, metro_ratio)

## 말·가마 대신 자전거·자동차 (2단계 비율)
func vehicle_is_modern(key: String) -> bool:
	return is_active() and _hash01("veh:" + key) < metro_ratio

# ==================== 근대 BGM (36턴 주기) ====================

func _on_turn(turn: int, _season: int, _year: int) -> void:
	if not is_active():
		return
	_process_pollution()
	_process_water()
	apply_modern_tiles() # 새로 지은 건물도 그 칸의 단계에 맞게
	apply_landmark_tiles() # 대학교 개편 뒤 새로 생긴 서당·서원도 학교 그림으로
	if turn >= next_bgm_turn:
		_pick_new_bgm()

func _pick_new_bgm() -> void:
	var pool: Array = BGM_TRACKS.duplicate()
	pool.erase(current_bgm)
	current_bgm = String(pool[randi() % pool.size()])
	next_bgm_turn = (sim.turn if sim else 0) + BGM_PERIOD_TURNS
	if MusicManager.instance:
		MusicManager.instance.switch_to_track(current_bgm, BGM_FADE)
	emit_signal("bgm_changed", current_bgm)

# ==================== 저장 ====================

func serialize() -> Dictionary:
	return {
		"stone_ratio": stone_ratio,
		"metro_ratio": metro_ratio,
		"current_bgm": current_bgm,
		"next_bgm_turn": next_bgm_turn,
		"lake_parks": lake_parks.duplicate(),
		"military_base": military_base,
		"civic_upgrades": civic_upgrades.duplicate(),
		"heritage_condition": heritage_condition,
		"haenggung_republic": haenggung_republic,
		"plaza_upgrades": plaza_upgrades.duplicate(),
		"wells_upgraded": wells_upgraded,
		"reservoirs_upgraded": reservoirs_upgraded,
		"water_project_started": water_project_started,
		"water_project_done_turns": water_project_done_turns
	}

func deserialize(d: Dictionary) -> void:
	stone_ratio = float(d.get("stone_ratio", 0.0))
	metro_ratio = float(d.get("metro_ratio", 0.0))
	current_bgm = String(d.get("current_bgm", ""))
	next_bgm_turn = int(d.get("next_bgm_turn", 0))
	military_base = bool(d.get("military_base", false))
	heritage_condition = float(d.get("heritage_condition", 100.0))
	call_deferred("apply_modern_tiles") # 1800 본편 저장이면 근대 표시를 모두 지운다
	call_deferred("apply_landmark_tiles") # 개편 건물 그림 표시도 저장 내용대로(1800 본편이면 모두 지움)
	haenggung_republic = bool(d.get("haenggung_republic", false))
	plaza_upgrades = (d.get("plaza_upgrades", {}) as Dictionary).duplicate() if d.get("plaza_upgrades", {}) is Dictionary else {}
	wells_upgraded = bool(d.get("wells_upgraded", false))
	reservoirs_upgraded = bool(d.get("reservoirs_upgraded", false))
	water_project_started = bool(d.get("water_project_started", false))
	water_project_done_turns = int(d.get("water_project_done_turns", 0))
	call_deferred("invalidate_water")
	civic_upgrades = (d.get("civic_upgrades", {}) as Dictionary).duplicate() if d.get("civic_upgrades", {}) is Dictionary else {}
	lake_parks = (d.get("lake_parks", {}) as Dictionary).duplicate() if d.get("lake_parks", {}) is Dictionary else {}

# ==================== 개편한 건물의 지도 그림 ====================
## 개편·조성한 건물은 칸에 "lm_modern"(buildings_modern/<이름>.png)을 적고, CityLayer가 그 그림으로 그린다.
## 칸 내용이 바뀌어야 Main의 바뀐 칸 다시 굽기가 그 띠를 다시 그리므로 부지 칸 전체에 적는다.
const LANDMARK_SPRITES := {
	"gwana": "gov_office", "jinhulso": "welfare_center", "hyanggyo": "university",
	"patrol": "police_station", "firefighter": "fire_station",
}
const LANDMARK_BUILDINGS := ["haenggung", "hyanggyo", "gwana", "jinhulso", "chukmanje", "manseokgeo", "yeonmudae", "patrol", "firefighter"]

## 지도 그림 종류(건물 이름에서 _site를 뗀 것, 또는 서당·서원 마당 종류). "" = 개편 대상 아님
static func landmark_key_of(t: Dictionary) -> String:
	var b: String = String(t.get("building", "")).trim_suffix("_site")
	if b in LANDMARK_BUILDINGS:
		return b
	if t.has("plaza") and t["plaza"] is Dictionary:
		var k := String((t["plaza"] as Dictionary).get("kind", ""))
		if k in ["seodang", "seowon", "maegok_seowon"]:
			return k
	return ""

## 개편한 건물의 근대 그림 이름("" = 옛 그림 그대로)
func landmark_sprite_for(key: String) -> String:
	if not is_active() or key == "":
		return ""
	var id := ""
	match key:
		"haenggung":
			if haenggung_republic:
				id = "haenggung_republic"
		"chukmanje", "manseokgeo":
			if is_lake_park(key):
				id = String(LAKE_PARKS[key]["sprite"])
		"yeonmudae":
			if military_base:
				id = "yeonmudae_base"
		"seodang":
			if has_university():
				id = "elementary_school"
		"seowon", "maegok_seowon":
			if has_university():
				id = "secondary_school"
		_:
			if LANDMARK_SPRITES.has(key) and is_civic_upgraded(key):
				id = String(LANDMARK_SPRITES[key])
	return id if id != "" and _sprite_ok(id) else ""

## 모든 칸의 개편 건물 그림 표시를 다시 적는다. 바뀐 칸이 있으면 그 띠만 다시 굽고 가림막도 새로.
func apply_landmark_tiles() -> void:
	if grid == null:
		return
	var changed := 0
	var want_of := {}
	for y in range(grid.size):
		for x in range(grid.size):
			var t: Dictionary = grid.grid[y][x]
			var key := landmark_key_of(t)
			var want := ""
			if key != "":
				if not want_of.has(key):
					want_of[key] = landmark_sprite_for(key)
				want = String(want_of[key])
			if want == "":
				if t.has("lm_modern"):
					t.erase("lm_modern")
					changed += 1
			elif String(t.get("lm_modern", "")) != want:
				t["lm_modern"] = want
				changed += 1
	if changed > 0:
		var main := get_parent()
		if main and main.has_method("_rebake_world"):
			main._rebake_world()
		if main and "citizen_layer" in main and main.citizen_layer != null:
			main.citizen_layer._occ_dirty = true
