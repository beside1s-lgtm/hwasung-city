extends Node
class_name GameGrid

# PORT-TRACE: src/core/GameState.ts (grid, getRoadMask/getWallMask, updateFortressScore,
# updateWaterManagement, getDistanceToRoad, hasConnectedNeighbor, zone development)
# 이식 로그: docs/godot_port_log.md 항목 P1

## 격자 데이터 모델. 지형은 terrain_data.json(정점 높이맵 + 이산 지형 분류)에서 도출한다.
## PORT-TRACE P24: 기존에는 Tiled 타일 인덱스(정수)로만 지형을 표현해 고저차를 담을 수 없었다.
## generate_map.py가 (size+1)^2 정점 높이맵을 직접 구워 이 JSON으로 내보내고, Tiled(.tmj)는
## 이제 좌표 변환 전용 빈 격자 하나만 담당한다(TiledMapLoader 참고).

signal grid_changed
signal grid_tiles_changed(tiles: Array[Vector2i])
## PORT-TRACE [단계별 건설]: 공사 중인 건물의 공정 단계(터 다지기 → 골조 → 마무리)가 바뀔 때만 발신.
## 그림(베이크)만 다시 그리면 되므로 grid_changed(시민 캐시·길찾기 재구성 유발)와 분리했다.
signal construction_progressed
## 사대문 외곽 도로 연결 상태 변경 시그널 (이벤트 기반 Throttled BFS)
signal border_road_connections_changed(connections: Dictionary)
## 사대문 외부 교역로 최초 개통 알림 시그널
signal external_road_opened(gate_kind: String, sign_title: String)
## 수원천 남수문·화홍문 현판 하사 시그널 (WaterStructureManager에서 트리거)
@warning_ignore("unused_signal")
signal water_gate_signboard_bestowed(facility_id: String, fac_name: String, center_pos: Vector2i)

const TERRAIN_PATH := "res://maps/terrain_data.json"

## PORT-TRACE [렉: 턴 정산 멈칫]: 지도가 바뀌면(턴 정산·건설) 시민 길 정보, 가림막, 놀이마당 목록, 지도 굽기가
## 저마다 지도 전체를 다시 세는데(각 20~40ms), 한 프레임에 몰려 0.1~0.2초씩 멈췄다.
## 무거운 다시 계산은 프레임마다 하나만 하도록 차례를 나눈다 — 이번 프레임에 이미 누가 썼으면 다음 프레임에 다시 청한다.
## 턴 계산은 자기 프레임마다 frame_take()로 차례를 먼저 차지해, 다른 다시 계산은 턴이 끝난 뒤로 미룬다.
static var _budget_frame := -1

## 이번 프레임 차례가 비었으면 차지하고 true, 아니면 false(다음 프레임에 다시 청할 것)
static func frame_claim() -> bool:
	var f := Engine.get_process_frames()
	if f == _budget_frame:
		return false
	_budget_frame = f
	return true

## 이번 프레임 차례를 무조건 차지한다(턴 계산처럼 미룰 수 없는 일)
static func frame_take() -> void:
	_budget_frame = Engine.get_process_frames()

enum BuildingType {
	NONE = 0,
	RESIDENTIAL = 1,
	COMMERCIAL = 2,
	AGRICULTURAL = 3,
	INDUSTRIAL = 4,
	WALL = 5,
	GATE = 6,
	SPECIAL = 7
}

const COST_MAP := {
	"road": {"gold": 20, "rice": 0},
	"stone_road": {"gold": 35, "rice": 5},
	"wall": {"gold": 1000, "rice": 500}, # 성곽 신규 축성 원가 (쉬움: 1,000냥/500석)
	"gate": {"gold": 2000, "rice": 1500}, # 사대문/암문/수문 건립 원가 (쉬움: 2,000냥/1,500석)
	"well": {"gold": 50, "rice": 10},
	"zone_res": {"gold": 30, "rice": 0},
	"zone_com": {"gold": 40, "rice": 0},
	"zone_agr": {"gold": 20, "rice": 20},
	"zone_ind": {"gold": 40, "rice": 10}, # PORT-TRACE [공방 구획]: 야조소·와소·벽돌소 작업장 부지
	"levee": {"gold": 60, "rice": 20},
	"reservoir": {"gold": 250, "rice": 100},
	"seojangdae": {"gold": 200, "rice": 80},
	"bongdon": {"gold": 150, "rice": 50},
	"gongsimdon": {"gold": 160, "rice": 50},
	"poru": {"gold": 180, "rice": 60},
	"yeonmudae": {"gold": 220, "rice": 70},
	"banghwasuryu": {"gold": 350, "rice": 140}, # 방화수류정(1x1) & 용연(3x3) 일체형 복합 구조물
	"yongyeon": {"gold": 350, "rice": 140},     # 방화수류정-용연 일체형 생성 연동
	"hwahong": {"gold": 2000, "rice": 1500},    # 화홍문(북수문) 4x1 수문교 (성문 규격: 2,000냥/1,500석)
	"yeonghwajeong": {"gold": 300, "rice": 100},# 영화정(迎華亭) 2x2 관청형 누정
	"guesthouse": {"gold": 200, "rice": 60},
	"factory": {"gold": 250, "rice": 80},
	"haenggung": {"gold": 500, "rice": 200}, # PORT-TRACE [행궁]: 화성행궁 - 정조 원행/을묘 진찬연의 무대가 될 왕실 별궁
	"patrol": {"gold": 120, "rice": 30},
	"firefighter": {"gold": 100, "rice": 20},
	"chukmanje": {"gold": 2080, "rice": 880}, # 축만제 (서호) 6x6 만석거와 동일 금액 및 기간 (턴당 260냥/110석 x 8턴)
	"jinhulso": {"gold": 5000, "rice": 5000}, # 진휼소 2x2 관영 구휼 복지 시설 (턴당 2,500냥/2,500석 x 2턴)
	"sewage": {"gold": 30000, "rice": 0}, # 근대화 시대 하수처리시설 2x2 (턴당 10,000냥 x 3턴)
}

var _logistics_cache: Dictionary = {}
var _logistics_dirty: bool = true
var _border_connections_cache: Dictionary = {}
var _border_connections_dirty: bool = true
var _announced_border_routes: Dictionary = {}
var _active_build_tiles: Dictionary = {} # PORT-TRACE [심시티 2000급 경량화]: 공사 중인 칸만 O(1) 추적하여 매 틱 4,096칸 루프 제거

## 사대문 방향별 역사적 목적지 명칭 매핑 (엄격한 20자 2줄 고증 규격)
const ROAD_DESTINATION_NAMES: Dictionary = {
	"jangan": {
		"gate_name": "장안문",
		"gate_kind": "jangan",
		"dir": "북쪽",
		"sign_title": "한양(漢陽)으로 가는 길",
		"desc": "국왕의 능행차로이자\n한양 조정으로 직통하는 간선로입니다.",
		"history": "국왕의 능행차로 및 한양 조정 직통 간선로",
		"edge_dir": "north"
	},
	"paldal": {
		"gate_name": "팔달문",
		"gate_kind": "paldal",
		"dir": "남쪽",
		"sign_title": "삼남대로 / 현륭원(융릉)으로 가는 길",
		"desc": "충청·전라·경상 삼남 유통로이자\n사도세자 묘소로 향하는 능행길입니다.",
		"history": "충청·전라·경상 삼남 유통로 및 사도세자 묘소 능행길",
		"edge_dir": "south"
	},
	"changryong": {
		"gate_name": "창룡문",
		"gate_kind": "changryong",
		"dir": "동쪽",
		"sign_title": "광주 / 동해로 가는 길",
		"desc": "남한산성과 광주 고을을 잇는\n목재와 물자 보급의 핵심 통로입니다.",
		"history": "남한산성 및 광주 목재/물자 보급로",
		"edge_dir": "east"
	},
	"hwaseo": {
		"gate_name": "화서문",
		"gate_kind": "hwaseo",
		"dir": "서쪽",
		"sign_title": "남양만 / 서해 갯벌로 가는 길",
		"desc": "남양포 소금과 수산물을 실어 나르는\n서해안 해상 무역 연결로입니다.",
		"history": "남양포 소금, 수산물 및 해상 무역 연결로",
		"edge_dir": "west"
	}
}

const WALL_CONNECTORS := ["wall", "gate", "seojangdae", "seojangdae_site", "bongdon", "bongdon_site", "gongsimdon", "gongsimdon_site", "gongsimdon_wall", "poru", "poru_site", "yeonmudae", "yeonmudae_site", "banghwasuryu", "hwahong", "namsu"]
## PORT-TRACE [행궁=동헌]: 화성행궁은 수원유수부의 관아(동헌)를 겸했다 — 별도 동헌(office)을
## 없애고, 행궁 부지 가장자리 어디로든 길이 붙도록 확장 칸(haenggung_site)도 도로 연결 대상.
const ROAD_CONNECTORS := ["road", "stone_road", "wall", "gate", "levee", "guesthouse", "factory", "patrol", "firefighter", "haenggung", "haenggung_site", "gwana", "gwana_site", "jongnu", "jongnu_site", "yeonghwajeong", "yeonghwajeong_site", "chukmanje", "chukmanje_site", "jinhulso", "jinhulso_site"]

var size: int = 64
var grid: Array = [] # grid[y][x] = Dictionary
var fortress_progress: int = 0
var wall_loop_validator: WallLoopValidator = WallLoopValidator.new()
var flood_defense: int = 0
var reservoir_count: int = 0
## [대유둔전 수리시설 연동 고증: 만석거/저수지 위치 목록 및 유효 개간 POI 풀]
var reservoir_positions: Array[Vector2i] = []
var reservoir_poi_pool: Array[Vector2i] = []

## [인구 역학 매니저 참조]
var pop_manager = null

## [난이도 밸런스 연동 O(1) 캐싱 카운터]
var houses_count: int = 0
var shops_count: int = 0
var farms_count: int = 0

## [등급별 차등 과세 O(1) 캐싱 카운터]
var thatched_count: int = 0
var tile_count: int = 0
var mansion_count: int = 0
var basic_shop_count: int = 0
var luxury_shop_count: int = 0

var is_drought: bool = false
var is_fire_active: bool = false

func set_disasters(drought: bool, flood: bool, fire: bool) -> void:
	is_drought = drought
	is_flood_crisis = flood
	is_fire_active = fire

func recount_zone_counts() -> void:
	houses_count = 0
	shops_count = 0
	farms_count = 0
	thatched_count = 0
	tile_count = 0
	mansion_count = 0
	basic_shop_count = 0
	luxury_shop_count = 0
	for y: int in range(size):
		for x: int in range(size):
			var b: String = str(grid[y][x].get("building", ""))
			if b.begins_with("res"):
				houses_count += 1
				if b == "res_1":
					thatched_count += 1
				elif b == "res_2":
					tile_count += 1
				elif b == "res_3":
					mansion_count += 1
			elif b.begins_with("com") or b.begins_with("ind"):
				shops_count += 1
				if b in ["com_1", "ind_1"]:
					basic_shop_count += 1
				elif b in ["com_2", "ind_2"]:
					luxury_shop_count += 1
			elif b.begins_with("agr"):
				farms_count += 1
	BuildingManager.sync_workshop_and_shop_counts(self)
	if pop_manager != null and pop_manager.has_method("sync_housing_lists_from_grid"):
		pop_manager.sync_housing_lists_from_grid(self)

func _update_zone_count_delta(old_b: String, new_b: String) -> void:
	if old_b == new_b:
		return
	if old_b.begins_with("res"):
		houses_count = maxi(0, houses_count - 1)
		if old_b == "res_1":
			thatched_count = maxi(0, thatched_count - 1)
		elif old_b == "res_2":
			tile_count = maxi(0, tile_count - 1)
		elif old_b == "res_3":
			mansion_count = maxi(0, mansion_count - 1)
	elif old_b.begins_with("com") or old_b.begins_with("ind"):
		shops_count = maxi(0, shops_count - 1)
		if old_b in ["com_1", "ind_1"]:
			basic_shop_count = maxi(0, basic_shop_count - 1)
		elif old_b in ["com_2", "ind_2"]:
			luxury_shop_count = maxi(0, luxury_shop_count - 1)
	elif old_b.begins_with("agr"):
		farms_count = maxi(0, farms_count - 1)

	if new_b.begins_with("res"):
		houses_count += 1
		if new_b == "res_1":
			thatched_count += 1
		elif new_b == "res_2":
			tile_count += 1
		elif new_b == "res_3":
			mansion_count += 1
	elif new_b.begins_with("com") or new_b.begins_with("ind"):
		shops_count += 1
		if new_b in ["com_1", "ind_1"]:
			basic_shop_count += 1
		elif new_b in ["com_2", "ind_2"]:
			luxury_shop_count += 1
	elif new_b.begins_with("agr"):
		farms_count += 1

	BuildingManager.update_workshop_and_shop_delta(old_b, new_b)


## PORT-TRACE P24: 실좌표 4대문/성 밖 옛 간선로 — TradeSystem, OutsideSettlement가 참조한다.
var gates: Dictionary = {}
var outbound_roads: Dictionary = {}

## PORT-TRACE [지형 편집]: (size+1)x(size+1) 공유 정점 높이맵. paint_terrain()이 여기를 직접
## 고쳐 산 정상·하천·평지 붓칠이 이웃 타일과 이가 맞물리게(seam 없이) 한다.
var vertex_heights: Array = []
var _loaded_json_cache: Dictionary = {}

var _road_dist_field: Array = [] # 계절 경계마다 1회 갱신되는 도로 거리장(멀티소스 BFS)

## PORT-TRACE [터 축조]: 사용자 요청 — "행궁이나 동헌 같은 건물은 단일 건물이 아니라 상당한
## 공간을 차지하는 터 개념... 바로 건설되는 게 아니라 기초 공사부터 기간을 잡고 완공되는 걸
## 보여주는 게 심시티 느낌". 클릭한 타일을 중심으로 정사각형 부지를 확보하고, 국책 대역사와
## 같은 방식(매턴 비용·비계 연출)으로 여러 턴에 걸쳐 완공한다. radius=1 -> 3x3 부지.
## PORT-TRACE [터 축조 일반화]: 처음엔 정사각형(radius)만 지원했으나, 만석거(6x6, 짝수 변)를
## 추가하면서 가로/세로를 따로 줄 수 있게 w/h로 일반화했다. w=h=2r+1인 기존 항목(office,
## haenggung)은 동작이 그대로 보존된다(중심이 클릭한 칸). 짝수(w=6 등)는 중심을 살짝
## 오른쪽/아래로 치우쳐 잡는다(바닥 개수를 맞추기 위한 불가피한 선택).
const SITE_BUILDINGS := {
	# PORT-TRACE [행궁=동헌 + 7x7 복합 궁궐]: 사용자 요청 — "화성행궁이 동헌 역할을 겸했으니
	# 동헌을 따로 짓지 말고 행궁을 세우게 하고, 여러 전각이 어우러진 복합시설로 더 웅장하게".
	# 첫 교지 건물이 되었으므로 공기는 6→4턴으로 줄이고, 부지는 7x7로 키워 신풍루·좌익문·봉수당·
	# 장락당·낙남헌·행각·후원이 들어앉게 했다(지형 데이터상 7x7 평지 부지 1,000곳 이상 확인).
	"haenggung": {"w": 7, "h": 7, "turns": 4, "cost_per_turn": {"gold": 250, "rice": 90}},
	# PORT-TRACE [만석거 6x6]: 사용자가 "만석거도 6x6 정도 되는 아주 큰 저수지인데 한 칸으로
	# 묘사돼 웅장함이 안 산다"며 실제 규모에 맞는 다칸 부지를 요청 — haenggung과 같은 부지
	# 축조 시스템을 그대로 재사용해 6x6으로 짓는다.
	"manseokgeo": {"w": 6, "h": 6, "turns": 8, "cost_per_turn": {"gold": 260, "rice": 110}},
	# 축만제(서호) 6x6: 만석거와 동일한 금액(260냥/110석 x 8턴 = 2,080냥/880석) 및 기간으로 가운데 인공섬(서호 당주) 특화 랜드마크
	"chukmanje": {"w": 6, "h": 6, "turns": 8, "cost_per_turn": {"gold": 260, "rice": 110}},
	# 진휼소(賑恤所) 2x2: 관영 구휼 복지 종합 단지 (2턴 분할, 총 금화 5,000냥 / 군량 5,000석)
	"jinhulso": {"w": 2, "h": 2, "turns": 2, "cost_per_turn": {"gold": 2500, "rice": 2500}},
	# PORT-TRACE [관아·옥사 2x2]: 사용자 요청 — "죄수를 가두는 감옥과 관아를 2x2로, 그 안에서 죄수를 심판하는 모습".
	# 한 단지 안에 동헌(사또 자리)·재판 마당(형틀)·원형 옥사·솟을삼문. 붙잡힌 화적·좀도둑이 압송돼 와 문초받고 갇힌다.
	"gwana": {"w": 2, "h": 2, "turns": 2, "cost_per_turn": {"gold": 120, "rice": 40}},
	# PORT-TRACE [종루(여민각) 2x2]: 플레이어가 짓는 도구가 아니라 행궁 앞 박석 십자로가 열리면 조정이 자동 착공(무료)
	"jongnu": {"w": 2, "h": 2, "turns": 2, "cost_per_turn": {"gold": 0, "rice": 0}},
	# PORT-TRACE [수원향교 4x4]: 성 밖 평지 + 성문과 길로 이어진 곳에만(validate_site)
	"hyanggyo": {"w": 4, "h": 4, "turns": 3, "cost_per_turn": {"gold": 300, "rice": 150}},
	# 영화정(迎華亭) 2x2: 만석거 남쪽 실용적 관청형 누정
	"yeonghwajeong": {"w": 2, "h": 2, "turns": 2, "cost_per_turn": {"gold": 150, "rice": 50}},
	# 근대화 시대 하수처리시설 2x2: 하단 메뉴바의 홍예성문 자리에서 짓는다(근대화 시대에만)
	"sewage": {"w": 2, "h": 2, "turns": 3, "cost_per_turn": {"gold": 10000, "rice": 0}},
}

const SITE_OUTSIDE_OK := ["manseokgeo", "chukmanje", "yeonghwajeong", "hyanggyo", "jinhulso", "sewage"] # 성 밖(outside) 들판에도 지을 수 있는 부지 건물

var active_sites: Array = [] # [{building, anchor, tiles, turns_left, total_turns, cost_per_turn}]

## [스마트 오리엔테이션] 대형 부지 건물의 최적 입구 방향(도로 접점이 가장 많은 변) 계산 함수.
## facing: "north"=북(y-), "south"=남(y+), "west"=서(x-), "east"=동(x+)
## 스폰 시 단 1회만 호출하여 타일 데이터에 저장 — 런타임 프레임 연산 없음.
func get_best_road_facing_direction(tiles: Array[Vector2i]) -> String:
	var scores := {"north": 0.0, "south": 0.0, "west": 0.0, "east": 0.0}
	var inset := {}
	var min_x := 9999
	var max_x := -9999
	var min_y := 9999
	var max_y := -9999
	for p: Vector2i in tiles:
		inset[p] = true
		min_x = mini(min_x, p.x)
		max_x = maxi(max_x, p.x)
		min_y = mini(min_y, p.y)
		max_y = maxi(max_y, p.y)

	# 4개 변(북/남/서/동) 외곽으로 1~3칸 범위의 도로 타일을 거리 역가중치로 채점
	for dist in range(1, 4):
		var weight: float = 4.0 - float(dist) # 1칸: 3.0점, 2칸: 2.0점, 3칸: 1.0점
		# 북쪽 (y < min_y)
		for x in range(min_x, max_x + 1):
			var ny := min_y - dist
			if in_bounds(x, ny):
				var b_u: String = grid[ny][x].get("building", "")
				if b_u in ["road", "stone_road", "gate"]:
					scores["north"] += weight
		# 남쪽 (y > max_y)
		for x in range(min_x, max_x + 1):
			var sy := max_y + dist
			if in_bounds(x, sy):
				var b_d: String = grid[sy][x].get("building", "")
				if b_d in ["road", "stone_road", "gate"]:
					scores["south"] += weight
		# 서쪽 (x < min_x)
		for y in range(min_y, max_y + 1):
			var wx := min_x - dist
			if in_bounds(wx, y):
				var b_l: String = grid[y][wx].get("building", "")
				if b_l in ["road", "stone_road", "gate"]:
					scores["west"] += weight
		# 동쪽 (x > max_x)
		for y in range(min_y, max_y + 1):
			var ex := max_x + dist
			if in_bounds(ex, y):
				var b_r: String = grid[y][ex].get("building", "")
				if b_r in ["road", "stone_road", "gate"]:
					scores["east"] += weight

	var best: String = "south"
	var best_score: float = -1.0
	# 도로 점수가 가장 높은 변을 선택 (동률 시 한국 전통 남향 우선)
	for dir: String in ["south", "east", "west", "north"]:
		if scores[dir] > best_score:
			best_score = scores[dir]
			best = dir
	return best

## [향교 진입로] 입구 방향 변에서 바로 1칸 밖 빈 타일을 흙길로 개통 (입구 보행 노드 자동 개방)
func _open_hyanggyo_entrance(tiles: Array[Vector2i], facing: String) -> void:
	var inset := {}
	for p: Vector2i in tiles:
		inset[p] = true
	var dv := Vector2i(0, 1)
	match facing:
		"north": dv = Vector2i(0, -1)
		"west":  dv = Vector2i(-1, 0)
		"east":  dv = Vector2i(1, 0)
	for p3: Vector2i in tiles:
		var out_pt: Vector2i = p3 + dv
		if inset.has(out_pt) or not in_bounds(out_pt.x, out_pt.y):
			continue
		var on_edge := false
		match facing:
			"south": on_edge = not inset.has(Vector2i(p3.x, p3.y + 1))
			"north": on_edge = not inset.has(Vector2i(p3.x, p3.y - 1))
			"west":  on_edge = not inset.has(Vector2i(p3.x - 1, p3.y))
			"east":  on_edge = not inset.has(Vector2i(p3.x + 1, p3.y))
		if not on_edge:
			continue
		var ot: Dictionary = grid[out_pt.y][out_pt.x]
		if ot.get("building", "") == "" and ot.get("zone", "") == "" and ot.get("terrain", "") in ["plain", "outside"]:
			ot["building"] = "road"
			ot["road_type"] = "dirt"
			break
var is_flood_crisis: bool = false # 수해 위기 모드 플래그 (생산 및 방호력 50% 반감)

func set_flood_crisis(active: bool) -> void:
	is_flood_crisis = active

## 방화수류정(2x2) & 용연(3x3) 일체형 복합 오브젝트 타일군 계산
## 방화수류정 2x2는 성곽 2칸 라인(성벽 상부)과 반드시 직결되며,
## 용연 3x3은 성곽 바깥(outside 들판) 방향으로만 강제 오프셋되어 자동 생성된다.
## 성벽(성곽 잇는 시설 포함)과 8방으로 맞닿은 칸 — 성벽 바로 바깥 띠 땅
func _beside_wall(pt: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if (dx != 0 or dy != 0) and is_wall_connector(pt.x + dx, pt.y + dy):
				return true
	return false

## 용연을 팔 수 있는 칸: 빈 땅·수로, 또는 논밭(둔전은 연못으로 바뀐다)
func _yongyeon_free(pt: Vector2i) -> bool:
	var b := String(grid[pt.y][pt.x].get("building", ""))
	return b == "" or b == "canal" or b.begins_with("agr")

func get_banghwa_complex_tiles(cx: int, cy: int) -> Dictionary:
	# PORT-TRACE [방화수류정 1x1]: 사용자 요청 — "건물 사이즈를 1x1로 줄이고(아기자기하게), 용연이 가려지지 않게".
	# 정자는 클릭한 한 칸, 용연(3x3)은 정자와 한 변을 맞대고 정자를 가운데에 둔다(정자 → 연못 가운데까지 2칸).
	var banghwa: Array[Vector2i] = [Vector2i(cx, cy)]

	# 4방향(북, 동, 남, 서) 중 용연(3x3)이 '성곽 바깥(outside)'에 가장 많이 안착하는 방향
	var candidate_dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var best_dir := Vector2i(0, -1)
	var max_outside_count := -1
	var best_yongyeon: Array[Vector2i] = []

	for dir: Vector2i in candidate_dirs:
		var cur_yong: Array[Vector2i] = []
		var mid: Vector2i = Vector2i(cx, cy) + dir * 2
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				cur_yong.append(mid + Vector2i(ox, oy))

		var outside_count := 0
		var all_valid := true
		for pt: Vector2i in cur_yong:
			if not in_bounds(pt.x, pt.y):
				all_valid = false
				break
			var terr: String = String(grid[pt.y][pt.x].get("terrain", ""))
			if terr == "outside" or terr == "water":
				outside_count += 1
				# 비어 있는(또는 논밭·수로뿐인) 성 밖 칸을 더 쳐 준다 — 집·길이 있는 쪽보다 빈 들판 쪽에 연못을 판다
				if _yongyeon_free(pt):
					outside_count += 10
			elif terr != "plain":
				all_valid = false
			elif _yongyeon_free(pt) and _beside_wall(pt):
				outside_count += 5 # 성벽 바로 바깥 띠 땅

		if all_valid and outside_count > max_outside_count:
			max_outside_count = outside_count
			best_dir = dir
			best_yongyeon = cur_yong

	if best_yongyeon.is_empty():
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				best_yongyeon.append(Vector2i(cx, cy - 2) + Vector2i(ox, oy))

	return {
		"banghwa": banghwa,
		"yongyeon": best_yongyeon,
		"anchor": Vector2i(cx, cy),
		"out_dir": best_dir
	}

## 화홍문(북수문 4x1 수문교) 타일군 계산
func get_hwahong_tiles(cx: int, cy: int) -> Dictionary:
	var v_water := 0
	var h_water := 0
	for d in range(-2, 3):
		if in_bounds(cx, cy + d) and grid[cy + d][cx].get("terrain", "") == "water":
			v_water += 1
		if in_bounds(cx + d, cy) and grid[cy][cx + d].get("terrain", "") == "water":
			h_water += 1
	var along_x := v_water >= h_water
	var tiles: Array[Vector2i] = []
	if along_x:
		for dx in range(-1, 3):
			tiles.append(Vector2i(cx + dx, cy))
	else:
		for dy in range(-1, 3):
			tiles.append(Vector2i(cx, cy + dy))
	return {"tiles": tiles, "along_x": along_x, "anchor": Vector2i(cx, cy)}

func get_site_footprint(cx: int, cy: int, w: int, h: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var x0: int = cx - int(float(w - 1) / 2.0)
	var y0: int = cy - int(float(h - 1) / 2.0)
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			tiles.append(Vector2i(x, y))
	return tiles

func validate_site(building: String, cx: int, cy: int) -> String:
	if not SITE_BUILDINGS.has(building):
		return "알 수 없는 시설입니다."
	var info: Dictionary = SITE_BUILDINGS[building]
	var w: int = info["w"]
	var h: int = info["h"]
	if building == "sewage" and not UrbanEvolutionManager.is_active():
		return "하수처리시설은 근대화 시대에만 지을 수 있습니다."
	# PORT-TRACE [영화정 2x2]: 만석거가 완공된 뒤, 만석거 둑에서 3칸 안에만 세운다(저수지 물을 굽어보는 관청형 정자)
	if building == "yeonghwajeong":
		if count_completed("manseokgeo") == 0:
			return "영화정은 만석거가 완공된 뒤에 그 곁에 세울 수 있습니다."
		var near_mg := false
		for pt0 in get_site_footprint(cx, cy, w, h):
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					if String(building_at(pt0.x + dx, pt0.y + dy)).begins_with("manseokgeo"):
						near_mg = true
		if not near_mg:
			return "영화정은 만석거 둑에서 3칸 안에 세워야 합니다."
	if building == "hyanggyo":
		for pt1 in get_site_footprint(cx, cy, w, h):
			if in_bounds(pt1.x, pt1.y) and grid[pt1.y][pt1.x]["terrain"] != "outside":
				return "수원향교는 반드시 성곽 바깥 평지에만 세울 수 있습니다."
		if not _site_road_to_gate(get_site_footprint(cx, cy, w, h)):
			return "수원향교는 성문까지 길로 곧장 이어진 자리에 세워야 합니다. (부지에 맞닿은 길이 성문과 연결되어야 함)"
	for pt in get_site_footprint(cx, cy, w, h):
		if not in_bounds(pt.x, pt.y):
			return "부지가 지도 밖으로 벗어납니다. (%d x %d칸 필요)" % [w, h]
		var t: Dictionary = grid[pt.y][pt.x]
		# PORT-TRACE [둔전·저수지·수로]: 만석거 같은 저수지는 성 밖 들판에도 축조할 수 있다.
		var outside_ok: bool = building in SITE_OUTSIDE_OK and t["terrain"] == "outside"
		if t["terrain"] != "plain" and not outside_ok:
			if building in SITE_OUTSIDE_OK:
				return "부지 전체가 평탄한 들판(성 안·성 밖 평지)이어야 합니다. (%d x %d칸 필요)" % [w, h]
			return "부지 전체가 평탄한 성 안 대지여야 합니다. (%d x %d칸 필요)" % [w, h]
		if t["building"] != "" or t["zone"] != "" or t["under_construction"]:
			return "부지 안에 이미 다른 시설이 있습니다. %d x %d칸을 비워두십시오." % [w, h]
	return ""

## 착공: 국책 대역사(start_mega_project)와 마찬가지로 첫 턴 비용을 즉시 치르고 비계를 세운다.
func start_site_construction(building: String, cx: int, cy: int, sim: SimulationCore) -> Dictionary:
	var err := validate_site(building, cx, cy)
	if err != "":
		return {"success": false, "msg": err}
	var info: Dictionary = SITE_BUILDINGS[building]
	var cost: Dictionary = info["cost_per_turn"]
	if sim.gold < cost["gold"] or sim.rice < cost["rice"]:
		return {"success": false, "msg": "착공에 필요한 첫 달 국고나 군량이 부족합니다."}
	sim.gold -= cost["gold"]
	sim.rice -= cost["rice"]
	var tiles := get_site_footprint(cx, cy, info["w"], info["h"])
	for pt in tiles:
		grid[pt.y][pt.x]["under_construction"] = true
		register_build_tile(pt.x, pt.y)
	active_sites.append({
		"building": building, "anchor": Vector2i(cx, cy), "tiles": tiles,
		"turns_left": int(info["turns"]) - 1, "total_turns": info["turns"], "cost_per_turn": cost,
		# 완공까지 남은 날(틱): 이번 계절의 남은 날 + 그 뒤 (턴-2)계절
		"bp_ticks": 0, "bp_total": _ticks_until_boundaries(int(info["turns"]) - 1),
	})

	# PORT-TRACE [만석거 6x6 & 영화정 세트]: 만석거 축조 시 부속 정자인 영화정(2x2)을 둑 곁(동쪽/남쪽)에 세트로 일괄 착공
	if building == "manseokgeo":
		plant_cherry_groves_around_manseokgeo(Vector2i(cx, cy), int(info["w"]), int(info["h"]))
		var y_pos := Vector2i(cx + int(info["w"]), cy + 2)
		if validate_site("yeonghwajeong", y_pos.x, y_pos.y) != "":
			y_pos = Vector2i(cx + 2, cy + int(info["h"]))
		if validate_site("yeonghwajeong", y_pos.x, y_pos.y) == "":
			plant_cherry_groves_around_manseokgeo(y_pos, 2, 2)
			var y_info: Dictionary = SITE_BUILDINGS["yeonghwajeong"]
			var y_tiles := get_site_footprint(y_pos.x, y_pos.y, int(y_info["w"]), int(y_info["h"]))
			for ypt in y_tiles:
				grid[ypt.y][ypt.x]["under_construction"] = true
				register_build_tile(ypt.x, ypt.y)
			active_sites.append({
				"building": "yeonghwajeong", "anchor": y_pos, "tiles": y_tiles,
				"turns_left": int(info["turns"]) - 1, "total_turns": info["turns"],
				"cost_per_turn": {"gold": 0, "rice": 0},
				"bp_ticks": 0, "bp_total": _ticks_until_boundaries(int(info["turns"]) - 1),
			})
	elif building in ["yeonghwajeong", "chukmanje"]:
		plant_cherry_groves_around_manseokgeo(Vector2i(cx, cy), int(info["w"]), int(info["h"]))

	# [수원향교 스마트 오리엔테이션]: 착공 시 단 1회 도로 접점 분석 → facing_direction 결정
	# 홍살문 입구가 도로를 향하도록 앵커 타일과 부지 전체에 기록
	if building == "hyanggyo":
		var facing: String = get_best_road_facing_direction(tiles)
		for pt_h: Vector2i in tiles:
			grid[pt_h.y][pt_h.x]["facing_direction"] = facing
		_open_hyanggyo_entrance(tiles, facing)

	emit_signal("grid_changed")
	return {"success": true, "msg": "%s 터를 닦고 착공했습니다. (예상 공기: %d개월)" % [building, info["turns"]]}

## 계절(턴) 경계마다 1회 호출. 완공된 터의 건물 이름 목록을 반환한다.
func process_site_tick(sim: SimulationCore) -> Array:
	var completed: Array = []
	var remaining: Array = []
	for site in active_sites:
		var cost: Dictionary = site["cost_per_turn"]
		if site["turns_left"] > 0:
			sim.gold = max(0, sim.gold - int(cost["gold"]))
			sim.rice = max(0, sim.rice - int(cost["rice"]))
			site["turns_left"] -= 1
		if site["turns_left"] <= 0:
			var anchor: Vector2i = site["anchor"]
			for pt in site["tiles"]:
				var t: Dictionary = grid[pt.y][pt.x]
				t["under_construction"] = false
				unregister_build_tile(pt.x, pt.y)
				if pt == anchor:
					t["building"] = site["building"]
					t["site_tiles"] = site["tiles"]
				else:
					t["building"] = "%s_site" % site["building"]
					t["site_anchor"] = anchor
			completed.append(site["building"])
			BuildingManager.on_building_completed(site["building"], self, sim)
		else:
			remaining.append(site)
	active_sites = remaining
	if not completed.is_empty():
		emit_signal("grid_changed")
	return completed

## PORT-TRACE [사대문 물류]: 성문 밖 길 개통·특화 시장·십자로 시전 판정(지도가 바뀌면 다음 조회 때 1회 재계산)
var logistics := GateLogistics.new()

func _ready() -> void:
	logistics.grid = self
	grid_changed.connect(logistics.mark_dirty)
	grid_tiles_changed.connect(func(_t): logistics.mark_dirty())
	grid_changed.connect(func(): _border_connections_dirty = true)
	grid_tiles_changed.connect(func(_t): _border_connections_dirty = true)
	# PORT-TRACE [성능: 물 공급 표]: 지도가 바뀌면 물 공급 표를 다음 조회 때 다시 찍는다
	grid_changed.connect(func():
		_water_valid = false
		_security_field_valid = false)
	grid_tiles_changed.connect(func(_t):
		_water_valid = false
		_security_field_valid = false)
	_build_from_map()

func _build_from_map() -> void:
	# PORT-TRACE P24: 실제 수원 화성 답사 지도 기반 고정 영토(P23)에 정점 높이맵을 더해
	# 입체 지형(산/계곡/하상 깊이)까지 표현한다. 자세한 좌표 설계는 generate_map.py 참고.
	var terrain_arr: Array = []
	var surfaces_arr: Array = []
	var corner_heights: Array = []
	var _hyoryungwon_pos: Array = [-1, -1]
	if FileAccess.file_exists(TERRAIN_PATH):
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(TERRAIN_PATH)) == OK:
			var td: Dictionary = json.data
			_loaded_json_cache = td # PORT-TRACE [지형 저장]: export_terrain_data()가 부가 필드 보존에 사용
			size = int(td.get("size", 64))
			terrain_arr = td.get("terrain", [])
			surfaces_arr = td.get("surfaces", [])
			corner_heights = td.get("corner_heights", [])
			gates = td.get("gates", {})
			outbound_roads = td.get("outbound_roads", {})
			_hyoryungwon_pos = td.get("hyoryungwon_pos", [-1, -1])

	var vs := size + 1
	vertex_heights = []
	for vy in range(vs):
		var vrow: Array = []
		for vx in range(vs):
			var idx := vy * vs + vx
			vrow.append(corner_heights[idx] if corner_heights.size() > idx else 1.0)
		vertex_heights.append(vrow)

	grid = []
	for y in range(size):
		var row: Array = []
		for x in range(size):
			var i := y * size + x
			var terr: String = terrain_arr[i] if terrain_arr.size() > i else "outside"
			var surf: String = surfaces_arr[i] if surfaces_arr.size() > i else ("water" if terr == "water" else ("forest" if terr == "mountain" else "grass"))
			row.append({
				"x": x, "y": y, "elevation": 1.0, "terrain": terr, "surface": surf,
				"corner_elev": [1.0, 1.0, 1.0, 1.0],
				"building": "", "zone": "", "level": 1, "under_construction": false, "is_bridge": false,
				"road_type": "dirt",
			})
		grid.append(row)

	# 성곽 예정 라인(성내/외 경계)을 완만한 구릉 지형으로 돋워 성 안팎을 육안으로 직관 구별 가능하도록 보정
	for y in range(size):
		for x in range(size):
			var terr: String = grid[y][x]["terrain"]
			if terr != "outside" and terr != "water" and terr != "mountain":
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if in_bounds(nx, ny) and grid[ny][nx]["terrain"] == "outside":
						grid[y][x]["is_boundary_ridge"] = true
						grid[y][x]["elevation"] = maxf(float(grid[y][x]["elevation"]), 1.25)
						break

	for y in range(size):
		for x in range(size):
			_refresh_tile_elevation(x, y)

	# 현륭원(융릉)은 실제 고증에 따라 성 밖(화성시 안녕동)에 위치하므로 맵 타일이 아닌 어명/조정 참배 이벤트로 운용됨.

	# PORT-TRACE P25: 성문 밖으로 이어지는 옛 간선로(고정) — 성저 자연발생 취락(OutsideSettlement)이
	# 이 길을 따라 저잣거리/민가를 스스로 들여앉힌다. 플레이어가 놓은 도로가 아니므로 철거해도
	# 무방하지만(성문 확장 계획 변경 등), 기본값으로는 항상 존재한다.
	for key in outbound_roads.keys():
		for pt in outbound_roads[key]:
			var px := int(pt[0])
			var py := int(pt[1])
			if in_bounds(px, py) and grid[py][px]["building"] == "":
				grid[py][px]["building"] = "road"

	_road_dist_field = []
	recount_zone_counts()
	emit_signal("grid_changed")

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size and y < size

func is_in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size and y < size

func is_valid_coord(coord: Vector2i) -> bool:
	return in_bounds(coord.x, coord.y)

func tile(x: int, y: int) -> Dictionary:
	return grid[y][x]

func building_at(x: int, y: int) -> String:
	if not in_bounds(x, y):
		return ""
	return grid[y][x]["building"]

## 인접 4방향 비트마스크: 북1(y-1) 동2(x+1) 남4(y+1) 서8(x-1)
func get_road_mask(x: int, y: int) -> int:
	var m := 0
	if is_road_connector(x, y - 1): m |= 1
	if is_road_connector(x + 1, y): m |= 2
	if is_road_connector(x, y + 1): m |= 4
	if is_road_connector(x - 1, y): m |= 8
	return m

func get_wall_mask(x: int, y: int) -> int:
	var m := 0
	if is_wall_connector(x, y - 1): m |= 1
	if is_wall_connector(x + 1, y): m |= 2
	if is_wall_connector(x, y + 1): m |= 4
	if is_wall_connector(x - 1, y): m |= 8
	return m

## PORT-TRACE [대각선 연결]: 십자(직교) 4방향만 연결 판정을 하다 보니, 계단식으로 대각선으로
## 이어놓은 도로/성곽은 서로 직교 이웃이 아니라서 끊긴 것처럼 보였다. 대각 이웃(NE/SE/SW/NW)이
## 연결체이고, 그 사이의 두 직교 이웃(예: NE라면 N과 E)이 "둘 다는" 연결체가 아닐 때만
## 대각선 커넥터를 켠다 — 이미 ㄱ자로 직교 연결이 되어 있으면 대각선 스텁을 겹쳐 그리지 않는다.
## PORT-TRACE [깔끔한 도로]: 대각선 연결 조각은 두 도로 칸 사이를 잇는 중간 칸이 "하나도" 없을 때만
## 그린다(지그재그 계단식 길). 예전엔 중간 칸 둘 중 하나만 있어도 그려서, 사거리 주변 칸들끼리 서로
## 대각선 조각을 뻗어 교차로에 X자 쐐기 무늬가 생겼다.
func get_road_diag_mask(x: int, y: int) -> int:
	var m := 0
	if is_road_connector(x + 1, y - 1) and not (is_road_connector(x + 1, y) or is_road_connector(x, y - 1)): m |= 1 # NE
	if is_road_connector(x + 1, y + 1) and not (is_road_connector(x + 1, y) or is_road_connector(x, y + 1)): m |= 2 # SE
	if is_road_connector(x - 1, y + 1) and not (is_road_connector(x - 1, y) or is_road_connector(x, y + 1)): m |= 4 # SW
	if is_road_connector(x - 1, y - 1) and not (is_road_connector(x - 1, y) or is_road_connector(x, y - 1)): m |= 8 # NW
	return m

func get_wall_diag_mask(x: int, y: int) -> int:
	var m := 0
	if is_wall_connector(x + 1, y - 1) and not (is_wall_connector(x + 1, y) and is_wall_connector(x, y - 1)): m |= 1
	if is_wall_connector(x + 1, y + 1) and not (is_wall_connector(x + 1, y) and is_wall_connector(x, y + 1)): m |= 2
	if is_wall_connector(x - 1, y + 1) and not (is_wall_connector(x - 1, y) and is_wall_connector(x, y + 1)): m |= 4
	if is_wall_connector(x - 1, y - 1) and not (is_wall_connector(x - 1, y) and is_wall_connector(x, y - 1)): m |= 8
	return m

func is_wall_connector(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	return grid[y][x]["building"] in WALL_CONNECTORS

## 성곽 축조 예정 라인 (성 안과 성 밖이 맞닿는 둘레 경계 타일 판정)
func is_wall_planned_boundary(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	var t: Dictionary = grid[y][x]
	if t.get("is_boundary_ridge", false):
		return true
	if t.get("terrain", "") != "outside" and t.get("terrain", "") != "water":
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if in_bounds(nx, ny) and grid[ny][nx].get("terrain", "") == "outside":
				return true
	return false

## 순찰로를 만드는 성곽·방어시설(이 건물에 맞닿은 칸이 순찰로)
const PATROL_ANCHORS := {"wall": true, "gate": true, "poru": true, "gongsimdon": true, "gongsimdon_wall": true, "seojangdae": true, "yeonmudae": true, "banghwasuryu": true}

## 성곽 순찰로(순라길) 및 보행로 판정: 성벽/성문/방어시설 바로 옆 1칸 바닥면 타일
## PORT-TRACE [렉: 턴 정산 멈칫]: 거리장·시민 길 정보가 지도 전체 칸마다 부르므로 부를 때마다 배열을 만들지 않고 이웃 넷을 바로 본다
func is_patrol_road(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= size or y >= size:
		return false
	var t: Dictionary = grid[y][x]
	if t.get("terrain", "") == "water" and not t.get("is_bridge", false):
		return false
	var b: String = t.get("building", "")
	if b == "wall" or b == "gate":
		return false
	# 성벽, 성문, 방어시설에 맞닿아 있는 타일 판정 (상부 및 바로 옆 1칸 라인 보행로)
	var row: Array = grid[y]
	if x + 1 < size and PATROL_ANCHORS.has(row[x + 1].get("building", "")):
		return true
	if x > 0 and PATROL_ANCHORS.has(row[x - 1].get("building", "")):
		return true
	if y + 1 < size and PATROL_ANCHORS.has(grid[y + 1][x].get("building", "")):
		return true
	if y > 0 and PATROL_ANCHORS.has(grid[y - 1][x].get("building", "")):
		return true
	return false

func is_road_connector(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	var t: Dictionary = grid[y][x]
	return t["building"] in ROAD_CONNECTORS or t["zone"] != "" or is_patrol_road(x, y)

## 거리장 기반 O(1) 도로 거리 조회 (파라미터 및 반환값 호환 유지)
func distance_to_road(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return 99
	if _road_dist_field.is_empty() or _road_connected_dirty:
		build_road_distance_field()
	if y < _road_dist_field.size() and x < _road_dist_field[y].size():
		var d: int = _road_dist_field[y][x]
		return d if d >= 0 else 99
	return 99

## 도로 거리장(Distance Transform Map): 일반 도로, 석축제방, 성곽 순찰로, 교량을 시드(0)로 하는 멀티소스 BFS
func build_road_distance_field() -> Array:
	var field := []
	for y in range(size):
		var row := []
		row.resize(size)
		row.fill(-1)
		field.append(row)
	var queue: Array = []
	for y in range(size):
		for x in range(size):
			var t: Dictionary = grid[y][x]
			var b: String = t.get("building", "")
			# 일반 길 + 석축제방(보행로) + 성곽 순찰로 + 교량 타일을 거리 0 시드로 등록
			if b in ["road", "stone_road", "gate", "levee"] or t.get("is_bridge", false) or is_patrol_road(x, y):
				field[y][x] = 0
				queue.append(Vector2i(x, y))
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		var d: int = field[p.y][p.x]
		for n in [Vector2i(p.x + 1, p.y), Vector2i(p.x - 1, p.y), Vector2i(p.x, p.y + 1), Vector2i(p.x, p.y - 1)]:
			if in_bounds(n.x, n.y) and field[n.y][n.x] == -1:
				field[n.y][n.x] = d + 1
				queue.append(n)
	_road_dist_field = field
	return field

func has_neighbor(x: int, y: int, target: String) -> bool:
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		if building_at(x + d.x, y + d.y) == target:
			return true
	return false

func has_connected_neighbor(x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx := x + dx
			var ny := y + dy
			if in_bounds(nx, ny) and (grid[ny][nx]["building"] != "" or grid[ny][nx]["zone"] != ""):
				return true
	return false

func count_buildings(prefix: String) -> int:
	var c := 0
	for row in grid:
		for t in row:
			if String(t["building"]).begins_with(prefix):
				c += 1
	return c

## PORT-TRACE P25: 성 밖 옛 간선로(고정 사전 배치)를 제외하고 "성 안에서 플레이어가 직접 지은"
## 것만 센다. 교지(어명) 달성 판정처럼 플레이어 행동을 확인해야 하는 곳에 쓴다.
func count_buildings_inside(prefix: String) -> int:
	var c := 0
	for row in grid:
		for t in row:
			if t["terrain"] != "outside" and String(t["building"]).begins_with(prefix):
				c += 1
	return c

func has_any_zone() -> bool:
	for row in grid:
		for t in row:
			if t["zone"] != "":
				return true
	return false

## 심시티 2000 상수도망 1:1 대응 (암거/개거/우물/저수지/하천 반경 3타일 내 물 공급 판정)
## PORT-TRACE [인프라 관할 범위]: 사용자 요청 — 우물 관할 약 80칸, 순라청·멸화군 관할 약 200칸, 물이 모자란
## 가옥·상점엔 물방울 표시, 배치할 때 관할 범위 오버레이. 64x64 지도라 "반경 80칸"이면 지도 전체를 덮으므로
## 넓이(칸 수)로 해석했다: 우물 반경 5칸(원 넓이 약 80칸), 순라청·멸화군 반경 8칸(약 200칸).
## 강·저수지·제방·수로 같은 자연 물길은 예전처럼 3칸 안이면 물을 길어 쓸 수 있다.
## (P66) 사용자 요청으로 우물·순라청·멸화군 효과 적용 반경(커버리지)을 기존 대비 2배로 확장:
## 우물 반경 8.1 -> 16.2, 순라청·멸화군 반경 11.7 -> 23.4
const WELL_RADIUS := 16.2
const PATROL_RADIUS := 23.4
const FIRE_RADIUS := 23.4
## 만석거(6x6 대형 저수지): 일반 저수지 대비 10배 관개 커버리지 반경 (반경 30타일)
const MANSEOK_RADIUS := 30.0

## 도로 연결성 (Road Connection) 필수 시스템
## 성곽 위의 군사 시설(성곽 자체가 길의 역할을 하므로 예외)을 제외한
## 모든 일반 건물/관청/생산시설은 입구 타일이 '흙길' 또는 '박석길' 타일과 1칸 이상 인접 접촉해야 기능 활성화.
## 성능 최적화: 도로가 건설되거나 철거될 때만 Dirty Flag 기반으로 캐싱 갱신.
var _road_connected_dirty: bool = true

func mark_road_network_dirty() -> void:
	_road_connected_dirty = true

func update_road_connectivity() -> void:
	if not _road_connected_dirty:
		return
	_road_connected_dirty = false
	build_road_distance_field()

	for y in range(size):
		for x in range(size):
			var t: Dictionary = grid[y][x]
			var b: String = t.get("building", "")
			var z: String = t.get("zone", "")
			if b == "" and z == "":
				t["road_connected"] = true
				t["road_dist"] = _road_dist_field[y][x] if y < _road_dist_field.size() and x < _road_dist_field[y].size() else 99
				continue

			# 성곽 위의 군사 시설은 성곽 자체가 길 역할을 하므로 도로 연결성 예외
			if b in ["wall", "gate", "gongsimdon", "gongsimdon_wall", "poru", "bongdon", "hwahong", "namsu", "banghwasuryu"]:
				t["road_connected"] = true
				t["road_dist"] = 0
				continue

			# 도로 타일 자체 및 석축제방(levee) 타일은 항상 도로 연결
			if b in ["road", "stone_road", "levee"] or t.get("is_bridge", false) or is_patrol_road(x, y):
				t["road_connected"] = true
				t["road_dist"] = 0
				continue

			# 서장대는 등산로(도로) 또는 순찰로/성곽길과 연결되어야 함 (허용 거리 3칸)
			if b.begins_with("seojangdae"):
				var d_seo: int = _road_dist_field[y][x] if y < _road_dist_field.size() and x < _road_dist_field[y].size() else 99
				t["road_dist"] = d_seo
				t["road_connected"] = (d_seo <= 3 or d_seo == 0)
				continue

			# 부지(다칸) 건물의 경우 전체 부지 타일 중 최소 도로 거리 확인
			var check_tiles: Array = [Vector2i(x, y)]
			if t.has("site_tiles"):
				check_tiles = t["site_tiles"]
			elif t.has("site_anchor"):
				var a: Vector2i = t["site_anchor"]
				if in_bounds(a.x, a.y) and grid[a.y][a.x].has("site_tiles"):
					check_tiles = grid[a.y][a.x]["site_tiles"]

			var min_dist: int = 999
			for pt_raw in check_tiles:
				var pt: Vector2i = pt_raw as Vector2i
				if in_bounds(pt.x, pt.y) and pt.y < _road_dist_field.size() and pt.x < _road_dist_field[pt.y].size():
					var d: int = _road_dist_field[pt.y][pt.x]
					if d >= 0 and d < min_dist:
						min_dist = d

			# 구획별 도로 연결 허용 거리 (Road-connection Tolerance Buffer):
			# 대유둔전(농지 구역): 도로로부터 최대 6칸 거리 이내 (수로 관개 시 자동 연결)
			# 저잣거리/방리(주거/상업/공방 등 일반 구역): 도로로부터 최대 3칸 거리 이내
			var is_agr: bool = (z == "agr" or b.begins_with("agr") or b in ["manseokgeo", "manseokgeo_site"] or t.get("irrigated", false))
			var max_allowed_dist: int = 6 if is_agr else 3
			var connected: bool = (min_dist <= max_allowed_dist or (is_agr and t.get("irrigated", false)))

			t["road_dist"] = min_dist
			t["road_connected"] = connected

func is_road_connected(x: int, y: int, max_dist: int = -1, zone_type: String = "") -> bool:
	if not in_bounds(x, y):
		return false
	var t: Dictionary = grid[y][x]
	var b: String = t.get("building", "")
	var z: String = t.get("zone", "")

	# 성곽, 성문, 방어시설, 석축제방, 도로, 교량, 순찰로는 항시 연결 보장
	if b in ["road", "stone_road", "wall", "gate", "gongsimdon", "gongsimdon_wall", "poru", "bongdon", "hwahong", "namsu", "banghwasuryu", "levee"] or t.get("is_bridge", false) or is_patrol_road(x, y):
		return true

	# 빈 타일이면서 요청 zone_type도 없으면 연결로 간주
	if b == "" and z == "" and zone_type == "":
		return true

	if _road_connected_dirty or _road_dist_field.is_empty():
		update_road_connectivity()

	# 다칸 부지 건물의 경우 부지 내 최소 거리 반영
	var dist: int = t.get("road_dist", 99)
	if _road_dist_field.size() > y and _road_dist_field[y].size() > x:
		var df: int = _road_dist_field[y][x]
		if df >= 0 and (dist > df or dist == 99):
			dist = df

	# 구획 타입 판정: zone_type 인자 우선, 없으면 타일의 zone/building 기준
	var chk_zone: String = zone_type if zone_type != "" else z
	var is_agr: bool = (chk_zone == "agr" or chk_zone.begins_with("agr") or b.begins_with("agr") or b in ["manseokgeo", "manseokgeo_site"] or t.get("irrigated", false))

	# 관개된 농지는 수로를 통한 수운 연결로 간주
	if is_agr and t.get("irrigated", false):
		return true

	var threshold: int = max_dist if max_dist >= 0 else (6 if is_agr else 3)
	return dist <= threshold

## 반경 r(원) 안에 names 중 하나라도 있는가
func _within(x: int, y: int, r: float, names: Array) -> bool:
	var ri := int(ceil(r))
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			if dx * dx + dy * dy > r * r:
				continue
			if in_bounds(x + dx, y + dy) and grid[y + dy][x + dx]["building"] in names:
				return true
	return false

## 관할 범위 오버레이용: 해당 시설들이 덮는 모든 칸
func coverage_tiles(names: Array, r: float) -> Array[Vector2i]:
	var hit := PackedByteArray()
	hit.resize(size * size)
	var ri := int(ceil(r))
	for y in range(size):
		for x in range(size):
			if grid[y][x]["building"] in names:
				for dy in range(-ri, ri + 1):
					for dx in range(-ri, ri + 1):
						if dx * dx + dy * dy <= r * r and in_bounds(x + dx, y + dy):
							hit[(y + dy) * size + x + dx] = 1
	var out: Array[Vector2i] = []
	for i in range(hit.size()):
		if hit[i] == 1:
			out.append(Vector2i(i % size, int(float(i) / float(size))))
	return out

## PORT-TRACE [성능: 물 공급 표]: 측정(건물 ~1000채) 결과 턴 계산이 700ms 걸렸고, 주범은 칸마다 만석거 반경 30칸(약 3,700칸)을
## 다시 훑던 이 함수였다. 이제 물길(3칸)·우물(반경)·만석거(반경 30)를 한 번 표에 찍어 두고 표에서 읽는다(지도가 바뀌면 다시 찍음).
var _water_field := PackedByteArray()
var _water_valid := false

func _build_water_field() -> void:
	_water_field.resize(size * size)
	_water_field.fill(0)
	var wr := int(ceil(WELL_RADIUS))
	var mr := int(ceil(MANSEOK_RADIUS)) + 3
	for y in range(size):
		for x in range(size):
			var t: Dictionary = grid[y][x]
			var b: String = t["building"]
			if t["terrain"] == "water" or b in ["reservoir", "levee", "canal"]:
				for yy in range(maxi(0, y - 3), mini(size, y + 4)):
					for xx in range(maxi(0, x - 3), mini(size, x + 4)):
						_water_field[yy * size + xx] = 1
			elif b == "well":
				for yy in range(maxi(0, y - wr), mini(size, y + wr + 1)):
					for xx in range(maxi(0, x - wr), mini(size, x + wr + 1)):
						if (xx - x) * (xx - x) + (yy - y) * (yy - y) <= int(WELL_RADIUS * WELL_RADIUS):
							_water_field[yy * size + xx] = 1
			elif b == "manseokgeo": # 6x6 만석거 기준 칸 — 둑 둘레까지 반경 30
				for yy in range(maxi(0, y - mr), mini(size, y + mr + 1)):
					for xx in range(maxi(0, x - mr), mini(size, x + mr + 1)):
						if (xx - x) * (xx - x) + (yy - y) * (yy - y) <= mr * mr:
							_water_field[yy * size + xx] = 1
	_water_valid = true

func has_water_supply(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	if not _water_valid:
		_build_water_field()
	return _water_field[y * size + x] == 1

func _has_water_supply_scan(x: int, y: int) -> bool:
	# 만석거(6x6 대형 저수지): 일반 소형 저수지(반경 3타일) 대비 10배인 반경 30타일 유효 관개
	if _within(x, y, MANSEOK_RADIUS, ["manseokgeo", "manseokgeo_site"]):
		return true
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var nx := x + dx
			var ny := y + dy
			if in_bounds(nx, ny):
				var t: Dictionary = grid[ny][nx]
				if t["terrain"] == "water" or t["building"] in ["reservoir", "levee", "canal"]:
					return true
	return _within(x, y, WELL_RADIUS, ["well"])

func has_fire_coverage(x: int, y: int) -> bool:
	return _within(x, y, FIRE_RADIUS, ["firefighter"])

## 물이 모자란 가옥·상점(물방울 표시용)
func water_shortage_tiles() -> Array[Vector2i]:
	# 근대화 시대(석조 전환 뒤): 근대 수도 영향권 밖이 물방울. 물방울이 없으면 상하수도 보급률 100%
	if UrbanEvolutionManager.instance and UrbanEvolutionManager.is_active() and UrbanEvolutionManager.instance.water_modern_active():
		return UrbanEvolutionManager.instance.water_uncovered_tiles()
	var out: Array[Vector2i] = []
	for y in range(size):
		for x in range(size):
			var b: String = grid[y][x]["building"]
			if (b.begins_with("res_") or b.begins_with("com_")) and not has_water_supply(x, y):
				out.append(Vector2i(x, y))
	return out

## 영화정이 만석거 또는 저수지 인근(반경 6칸)에 배치되어 있는지 판정 (관개 둔전 농정 보너스)
func has_yeonghwajeong_near_manseok() -> bool:
	for y in range(size):
		for x in range(size):
			var b: String = grid[y][x].get("building", "")
			if b == "yeonghwajeong":
				for dy in range(-6, 7):
					for dx in range(-6, 7):
						var nx: int = x + dx
						var ny: int = y + dy
						if in_bounds(nx, ny):
							var nb: String = grid[ny][nx].get("building", "")
							if nb in ["manseokgeo", "manseokgeo_site", "reservoir"]:
								return true
	return false

## [만석거 & 영화정 벚꽃숲/벚꽃밭 조성]:
## 만석거 호안 둘레 둑 밖 및 영화정 정원 외곽의 빈 들판에 흐드러진 벚꽃숲(surface = "cherry")을 자동 식재
func plant_cherry_groves_around_manseokgeo(anchor: Vector2i, w: int = 6, h: int = 6) -> void:
	for dy: int in range(-2, h + 3):
		for dx: int in range(-2, w + 3):
			var qx: int = anchor.x + dx
			var qy: int = anchor.y + dy
			if not in_bounds(qx, qy):
				continue
			# 부지 본체 영역은 제외
			if qx >= anchor.x and qx < anchor.x + w and qy >= anchor.y and qy < anchor.y + h:
				continue
			var cell: Dictionary = grid[qy][qx]
			var b: String = cell.get("building", "")
			var z: String = cell.get("zone", "")
			var terr: String = cell.get("terrain", "")
			var surf: String = cell.get("surface", "")
			# 자연 들판/풀밭/숲 타일이면서 건물과 구역이 없는 곳에 벚꽃숲 식재
			if b == "" and z == "" and not cell.get("under_construction", false) and terr != "water" and terr != "mountain":
				if surf in ["grass", "forest", "field", "dirt", ""]:
					cell["surface"] = "cherry"

## 심시티 2000 치안/발전소 1:1 대응 (순라청/동헌/서장대/봉돈/공심돈/포루/연무대 치안·방어망)
## PORT-TRACE [렉 해결]: 턴 계산 중에는 치안망을 칸마다 121칸씩 훑지 않고, 시작할 때 한 번 찍어 둔 표를 쓴다.
var _security_field: PackedByteArray = PackedByteArray()
var _security_field_valid := false
const SECURITY_SOURCES := ["haenggung", "haenggung_site", "gwana", "gwana_site", "jongnu", "jongnu_site", "seojangdae", "bongdon", "patrol", "gate", "gongsimdon", "poru", "yeonmudae", "banghwasuryu"]

func _build_security_field() -> void:
	_security_field.resize(size * size)
	_security_field.fill(0)
	for y in range(size):
		for x in range(size):
			var sb: String = grid[y][x]["building"]
			if sb == "patrol":
				# 순라청 치안 관할 원
				var pr := int(ceil(PATROL_RADIUS))
				for yy in range(maxi(0, y - pr), mini(size, y + pr + 1)):
					for xx in range(maxi(0, x - pr), mini(size, x + pr + 1)):
						if (xx - x) * (xx - x) + (yy - y) * (yy - y) <= int(PATROL_RADIUS * PATROL_RADIUS):
							_security_field[yy * size + xx] = 1
			elif sb in SECURITY_SOURCES or (grid[y][x].get("is_namsu", false) and not grid[y][x].has("wall_build")):
				for yy in range(maxi(0, y - 5), mini(size, y + 6)):
					for xx in range(maxi(0, x - 5), mini(size, x + 6)):
						_security_field[yy * size + xx] = 1
	_security_field_valid = true

func has_security_coverage(x: int, y: int) -> bool:
	# PORT-TRACE [성능: 치안 표]: 측정 — 성 밖 취락 확장(outside.grow)이 칸마다 순라청 반경(~580칸)을 다시 훑어 턴마다 ~76ms.
	# 표가 없으면 그 자리에서 한 번 찍어 쓰고, 지도가 바뀌면(grid_changed) 다음 조회 때 다시 찍는다.
	if not _security_field_valid and in_bounds(x, y):
		_build_security_field()
	if _security_field_valid and in_bounds(x, y):
		return _security_field[y * size + x] == 1
	if _near_namsu(x, y):
		return true
	if _within(x, y, PATROL_RADIUS, ["patrol"]):
		return true
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var nx := x + dx
			var ny := y + dy
			if in_bounds(nx, ny):
				var b: String = grid[ny][nx]["building"]
				if b in ["haenggung", "haenggung_site", "gwana", "gwana_site", "jongnu", "jongnu_site", "seojangdae", "bongdon", "gate", "gongsimdon", "poru", "yeonmudae", "banghwasuryu"]:
					return true
	return false

## PORT-TRACE P21: 수원천이 지도를 관통하므로 도로/성곽만은 다리(교량)/수문으로 하천을 건널 수 있게 한다.
## 성곽이 물 위를 건너면 화성 8경의 으뜸인 북수문(화홍문) 및 남수문이 된다.
const BRIDGEABLE := ["road", "stone_road", "wall", "gate"]
## PORT-TRACE P25: 성 밖에서도 플레이어가 지을 수 있는 도구 (자연발생 구획/저잣거리는 제외)
## PORT-TRACE [둔전·공방 성 밖 허용]: 정조 시대 화성은 둔전(대유평·서호·만년제)과 매연·화재
## 위험이 있는 공방(야조소·와소)을 성 밖 외곽에 두었다 — 사용자 요청으로 둔전·공방 구획과
## 저수지를 성 밖에도 지을 수 있게 했다(주거·상업 구획은 여전히 성 밖 자연발생에 맡긴다).
const OUTSIDE_ALLOWED_TOOLS := ["road", "stone_road", "well", "patrol", "firefighter", "yongyeon", "zone_agr", "zone_ind", "reservoir", "yeonghwajeong"]

## 도구 적용 가능 여부 검사. 실패 시 사유 문자열, 성공 시 빈 문자열.
func validate_tool(tool: String, x: int, y: int) -> String:
	if not in_bounds(x, y):
		return "지도 밖입니다."
	var t: Dictionary = grid[y][x]
	if tool == "inspect":
		return ""
	# PORT-TRACE P25: 성 밖(城底)은 플레이어가 직접 구획을 지정할 수 없다.
	if t["terrain"] == "outside" and not (tool in OUTSIDE_ALLOWED_TOOLS):
		return "화성 성곽 밖에는 도로·우물·관공시설, 둔전·공방 구획, 저수지만 지을 수 있습니다. (민가·저잣거리는 성 밖에 자연히 들어섭니다)"
	# PORT-TRACE [둔전 성내 건설 제한]: 둔전은 성 밖 외곽 들판에만 조성할 수 있고 성내 건설은 제한된다.
	if tool == "zone_agr" and t["terrain"] != "outside":
		return "둔전(농지)은 성벽 내부에 건설할 수 없습니다. 성 밖 외곽 들판에만 개간할 수 있습니다."
	if tool == "demolish":
		return ""
	if t["terrain"] == "water" and tool != "levee" and not (tool in BRIDGEABLE):
		return "수원천 물길 위에는 지을 수 없습니다. (도로는 다리, 성곽은 화홍문 수문으로 건널 수 있습니다)"
	if t["under_construction"]:
		return "국책 대역사 공사 중인 구역입니다."
	if tool == "seojangdae":
		# PORT-TRACE [서장대 2x2]: 팔달산 정상 바위 위 2x2(클릭한 칸이 왼쪽 위) — 네 칸 모두 산지·빈 땅
		return get_seojangdae_tiles(x, y).get("err", "")
	elif tool == "bongdon":
		# PORT-TRACE [봉돈 4x1]: 완공된 성벽 4칸에 덧씌우고 성 밖 4칸으로 돌출
		return get_bongdon_tiles(x, y).get("err", "")
	elif tool == "gongsimdon":
		# PORT-TRACE [공심돈 3x3]: 완공 성벽 가운데 칸을 클릭 → 성벽 3칸 + 안쪽 3칸 + 바깥 3칸
		return get_gongsimdon_tiles(x, y).get("err", "")
	elif tool == "yeonmudae":
		# PORT-TRACE [연무대 5x5]: 클릭한 칸이 가운데, 성 안 평지 5x5가 한 변으로 성곽에 맞닿아야
		return get_yeonmudae_tiles(x, y).get("err", "")
	elif tool == "poru":
		# PORT-TRACE [포루 5종 2x2]: 완공 성벽 2칸 + 바깥 2칸으로 돌출
		return get_poru_tiles(x, y).get("err", "")
	elif tool in ["gongsimdon", "poru"]:
		if count_completed("wall") == 0:
			return "성곽을 먼저 축조해야 합니다."
		if t["building"] != "wall":
			return "%s는 이미 축조된 성벽 칸 위에만 증축할 수 있습니다." % ("공심돈" if tool == "gongsimdon" else "포루")
		return "" # 기존 성곽 타일 위 클릭 시 즉시 업그레이드 허용
	elif tool == "yeonmudae":
		if t["terrain"] == "water":
			return "연무대(동장대)는 지상에 지어야 합니다."
	elif tool in ["banghwasuryu", "yongyeon"]:
		# 방화수류정(1x1) & 용연(3x3) 일체형 복합 구조물 검증
		var comp := get_banghwa_complex_tiles(x, y)
		var b_arr: Array = comp["banghwa"]
		var y_arr: Array = comp["yongyeon"]
		for pt in b_arr:
			if not in_bounds(pt.x, pt.y):
				return "방화수류정 부지가 지도 밖으로 벗어납니다."
			var bt: Dictionary = grid[pt.y][pt.x]
			if bt["building"] != "" and bt["building"] != "canal" and bt["building"] != "wall":
				return "방화수류정 부지에 이미 다른 시설이 있습니다."
		for pt in y_arr:
			if not in_bounds(pt.x, pt.y):
				return "용연(3x3) 연못 부지가 지도 밖으로 벗어납니다."
			var yt: Dictionary = grid[pt.y][pt.x]
			if not _yongyeon_free(pt):
				return "용연(3x3) 부지에 이미 다른 시설이 있습니다."
			# 용연은 반드시 성곽 바깥(outside 또는 물)에 — 단, 성벽 바로 바깥 띠 땅(성벽에 맞닿은 평지)은 허용
			if yt.get("terrain", "") != "outside" and yt.get("terrain", "") != "water" and not _beside_wall(pt):
				return "용연(연못)은 반드시 성곽 바깥(외측 들판)에만 생성되어야 합니다."
		var out_n := 0
		for pt2 in y_arr:
			if String(grid[pt2.y][pt2.x].get("terrain", "")) in ["outside", "water"]:
				out_n += 1
		if out_n < 5:
			return "용연(연못)은 반드시 성곽 바깥(외측 들판)에만 생성되어야 합니다."

		# 방화수류정은 성곽과 직결(성벽 칸 위이거나 성벽/성곽 경계에 맞닿음)
		var wall_connect_count := 0
		for pt in b_arr:
			if grid[pt.y][pt.x].get("building", "") == "wall" or is_wall_planned_boundary(pt.x, pt.y):
				wall_connect_count += 1
			else:
				for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
					if in_bounds(pt.x + d.x, pt.y + d.y) and grid[pt.y + d.y][pt.x + d.x].get("building", "") == "wall":
						wall_connect_count += 1
						break
		if wall_connect_count < 1:
			return "방화수류정은 성곽과 반드시 맞닿아 성벽 위에 세워져야 합니다."
	elif tool == "hwahong":
		var hw := get_hwahong_tiles(x, y)
		var hw_tiles: Array = hw["tiles"]
		var water_found := false
		for pt in hw_tiles:
			if not in_bounds(pt.x, pt.y):
				return "화홍문(4x1) 수문교 부지가 지도 밖으로 벗어납니다."
			var ht: Dictionary = grid[pt.y][pt.x]
			if ht["terrain"] == "water":
				water_found = true
			if ht["building"] != "" and ht["building"] != "wall" and ht["building"] != "canal":
				return "화홍문(4x1) 부지에 이미 다른 건물이 있습니다."
		if not water_found:
			return "화홍문은 수원천 물길 위에 4x1 수문교로 축조해야 합니다."
	elif tool in ["reservoir", "chukmanje"]:
		# PORT-TRACE [둔전·저수지·수로]: 예전엔 "고지대(고도 1.8 이상)에만" 지을 수 있어 사실상 성
		# 밖 들판에는 못 지었다. 실제 만석거·축만제·만년제는 들판 가장자리에 둑을 쌓아 만든
		# 저수지이므로 평지(성 안·성 밖)에 짓게 하고, 산 위만 막는다.
		if t["terrain"] == "mountain":
			return "저수지(축만제)는 산 위가 아니라 들판(성 안·성 밖 평지)에 만듭니다."
	elif t["terrain"] == "mountain" and tool != "wall" and tool != "gate" and tool != "road" and tool != "stone_road":
		# PORT-TRACE [산길]: "실제로 성은 산길을 타고 만들어졌고 산 속에 길도 있었다" 요청 —
		# 성곽/관문뿐 아니라 도로(산길)도 산악 지형에 낼 수 있게 허용.
		return "산악 지형에는 성곽·관문·길(도로)만 지을 수 있습니다."
	if tool == "wall" and _is_structure_tile(t):
		return "이미 서장대·봉돈·공심돈 같은 군사 시설이 서 있는 칸입니다. 성벽은 그 곁으로 이어 쌓으십시오."
	if (tool == "wall" and t["building"] == "road") or (tool in ["road", "stone_road"] and t["building"] == "wall") or (tool == "gate" and t["building"] in ["road", "wall"]):
		return ""
	# 흙길과 박석길 상호 교체 및 업그레이드 허용
	if (tool in ["road", "stone_road"]) and t["building"] == "road":
		return ""
	# 전소된 황무지(burned_wasteland)는 잔해를 철거(demolish)하고 신규 구획을 재지정해야만 건물이 들어설 수 있다
	if t["building"] == "burned_wasteland" or t.get("is_burned_wasteland", false):
		if tool != "demolish":
			return "화재로 전소된 황무지입니다. 먼저 철거 도구로 잔해를 치워야 합니다."
	# 자동 수로(canal) 및 전소된 폐허(ruin)는 그 위에 다른 것을 지으면 비켜서 다시 연결/재건되므로 막지 않는다.
	# PORT-TRACE [방화수류정 성곽 위]: 방화수류정은 성곽 칸 위에 올려 짓는다(성벽은 그대로 이어지고 그 위에 누각) — 성곽을 "이미 있는 건물"로 막지 않음
	if t["building"] != "" and t["building"] != "canal" and t["building"] != "ruin" and tool != "wall" and not (tool in ["gongsimdon", "poru", "banghwasuryu"] and t["building"] == "wall"):
		return "이미 건물이 있습니다."
	if t["building"] == "hyoryungwon":
		return "현륭원은 철거할 수 없습니다."
	return ""

## 수상 교량/수문 건설은 육상보다 비용이 크다 (화강암 교각/수문 공사 가산)
## 난이도(DifficultyManager) 연동: 박석길 차등 비용, 성벽 노임 지출, 어려움 10% 할증 적용
func get_tool_cost(tool: String, x: int, y: int) -> Dictionary:
	var base: Dictionary
	if tool == "stone_road":
		var dirt_base: Dictionary = COST_MAP.get("road", {"gold": 20, "rice": 0})
		base = DifficultyManager.get_stone_road_cost(dirt_base)
	elif tool == "wall":
		base = FortressWallManager.get_wall_build_cost()
	else:
		var raw_base: Dictionary = COST_MAP.get(tool, {"gold": 0, "rice": 0})
		var mult: float = DifficultyManager.get_cost_multiplier()
		if mult != 1.0:
			base = {
				"gold": int(round(float(raw_base.get("gold", 0)) * mult)),
				"rice": int(round(float(raw_base.get("rice", 0)) * mult))
			}
		else:
			base = raw_base.duplicate()

	if in_bounds(x, y) and grid[y][x]["terrain"] == "water" and tool in BRIDGEABLE:
		return {"gold": base["gold"] * 3, "rice": base["rice"] + 15}
	return base

## PORT-TRACE [경량화 감사]: recompute_infrastructure() 최적화
func apply_tool(tool: String, x: int, y: int, suppress_signal: bool = false) -> void:
	var t: Dictionary = grid[y][x]
	var old_b: String = str(t.get("building", ""))
	if tool == "demolish":
		if t["building"] != "hyoryungwon":
			var group: Array = []
			if t.has("site_tiles"):
				group = t["site_tiles"]
			elif t.has("site_anchor"):
				var a: Vector2i = t["site_anchor"]
				if in_bounds(a.x, a.y) and grid[a.y][a.x].has("site_tiles"):
					group = grid[a.y][a.x]["site_tiles"]
			# 연무대 활터(성 밖 표적 구역)도 연무대와 함께 철거한다
			var ym_anchor := Vector2i(-1, -1)
			if t.has("ym_rng") or t.has("ym5"):
				ym_anchor = t.get("site_anchor", Vector2i(x, y))
			if ym_anchor.x >= 0 and in_bounds(ym_anchor.x, ym_anchor.y) and grid[ym_anchor.y][ym_anchor.x].has("ym_range"):
				group = group.duplicate()
				group.append_array(grid[ym_anchor.y][ym_anchor.x]["ym_range"])
			_dissolve_house_group(t)
			WaterStructureManager.clear_structure_metadata(t)
			if group.is_empty():
				t["building"] = ""
				t["zone"] = ""
				t["is_bridge"] = false
				t.erase("is_burned_wasteland")
				t.erase("on_fire")
				t.erase("fire_progress")
				t.erase("wall_build")
				t.erase("wall_build_total")
				t.erase("zone_build")
				t.erase("bp_ticks")
				t.erase("bp_total")
				t.erase("trade")
				t.erase("trade_cat")
				t.erase("variant")
				t.erase("house_variant")
				t.erase("prosper")
				t.erase("plaza")
				t.erase("road_type")
			else:
				for pt in group:
					var gt: Dictionary = grid[pt.y][pt.x]
					_update_zone_count_delta(str(gt.get("building", "")), "")
					WaterStructureManager.clear_structure_metadata(gt)
					var was_on_wall: bool = bool(gt.get("sj_wall", false)) or bool(gt.get("bh_wall", false))
					gt["building"] = "wall" if was_on_wall else ""
					gt["zone"] = ""
					gt["is_bridge"] = false
					gt.erase("site_tiles")
					gt.erase("site_anchor")
					for k: String in ["bd4", "sj2", "sj_wall", "bh_wall", "gs3", "ym5", "ym_rng", "ym_range", "pr2", "wall_build", "wall_build_total", "bp_ticks", "bp_total"]:
						gt.erase(k)
	elif tool == "stone_road":
		t["building"] = "road"
		t["road_type"] = "stone"
		t["zone"] = ""
		t["is_bridge"] = (t["terrain"] == "water")
		if t["terrain"] == "water":
			WaterStructureManager.on_bridge_built(self, x, y)
	elif tool == "road":
		t["building"] = "road"
		t["road_type"] = "dirt"
		t["zone"] = ""
		t["is_bridge"] = (t["terrain"] == "water")
		if t["terrain"] == "water":
			WaterStructureManager.on_bridge_built(self, x, y)
	elif tool.begins_with("zone_"):
		t["zone"] = tool.trim_prefix("zone_")
		if t["building"] == "canal":
			t["building"] = "" # 수로를 구획으로 덮으면 수로는 rebuild_canals()가 비켜서 다시 낸다
	elif tool in ["banghwasuryu", "yongyeon"]:
		var comp := get_banghwa_complex_tiles(x, y)
		var b_arr: Array = comp["banghwa"]
		var y_arr: Array = comp["yongyeon"]
		var all_tiles: Array = []
		all_tiles.append_array(b_arr)
		all_tiles.append_array(y_arr)
		var anchor: Vector2i = comp["anchor"]
		for pt in b_arr:
			var gt: Dictionary = grid[pt.y][pt.x]
			if String(gt["building"]) == "wall":
				gt["bh_wall"] = true # 성벽 위에 세운 칸(철거하면 성벽으로 돌아가고, 그림은 성벽 높이만큼 받침을 올린다)
			gt["building"] = "banghwasuryu"
			gt["zone"] = ""
			gt["site_anchor"] = anchor
			gt["site_tiles"] = all_tiles
			gt["wall_build"] = 1
			gt["wall_build_total"] = 1
			gt["bp_ticks"] = 0
			gt["bp_total"] = _ticks_until_boundaries(1)
			register_build_tile(pt.x, pt.y)
		for pt in y_arr:
			var gt: Dictionary = grid[pt.y][pt.x]
			gt["building"] = "yongyeon"
			gt["zone"] = ""
			gt["terrain"] = "water" # 용연은 인공 연못
			gt["site_anchor"] = anchor
			gt["site_tiles"] = all_tiles
			gt["wall_build"] = 1
			gt["wall_build_total"] = 1
			gt["bp_ticks"] = 0
			gt["bp_total"] = _ticks_until_boundaries(1)
			register_build_tile(pt.x, pt.y)
	elif tool == "bongdon":
		var bd := get_bongdon_tiles(x, y)
		var all_t: Array[Vector2i] = []
		all_t.append_array(bd["wall"])
		all_t.append_array(bd["out"])
		var bd_anchor: Vector2i = (bd["wall"] as Array)[0]
		var info := {"axis": bd["axis"], "out": bd["out_dir"], "start": bd_anchor}
		for pt: Vector2i in all_t:
			var gt: Dictionary = grid[pt.y][pt.x]
			gt["building"] = "bongdon" if pt in (bd["wall"] as Array) else "bongdon_site"
			gt["zone"] = ""
			gt["bd4"] = info
			gt["site_anchor"] = bd_anchor
			gt["wall_build"] = 2
			gt["wall_build_total"] = 2
			gt["bp_ticks"] = 0
			gt["bp_total"] = _ticks_until_boundaries(2)
			register_build_tile(pt.x, pt.y)
		grid[bd_anchor.y][bd_anchor.x]["site_tiles"] = all_t
	elif tool == "poru":
		_build_poru(x, y, get_poru_tiles(x, y), "", false)
	elif tool == "gongsimdon":
		_build_gongsimdon(x, y, get_gongsimdon_tiles(x, y), "", false)
	elif tool == "yeonmudae":
		var ym := get_yeonmudae_tiles(x, y)
		var ym_tiles: Array = ym["tiles"]
		var ym_info := {"center": Vector2i(x, y), "wall_dir": ym["wall_dir"]}
		for pt: Vector2i in ym_tiles:
			var gt2: Dictionary = grid[pt.y][pt.x]
			gt2["building"] = "yeonmudae" if pt == Vector2i(x, y) else "yeonmudae_site"
			gt2["zone"] = ""
			gt2["ym5"] = ym_info
			gt2["site_anchor"] = Vector2i(x, y)
			gt2["wall_build"] = 3
			gt2["wall_build_total"] = 3
			gt2["bp_ticks"] = 0
			gt2["bp_total"] = _ticks_until_boundaries(3)
			register_build_tile(pt.x, pt.y)
		grid[y][x]["site_tiles"] = ym_tiles
		# 활터: 성 밖 과녁 구역 칸을 연무대 부속으로 잡는다(민가·논이 들어서지 못한다)
		var ym_range: Array = ym.get("range", [])
		for rq: Vector2i in ym_range:
			var rg: Dictionary = grid[rq.y][rq.x]
			rg["building"] = "yeonmudae_range"
			rg["zone"] = ""
			rg["site_anchor"] = Vector2i(x, y)
			rg["ym_rng"] = true
		grid[y][x]["ym_range"] = ym_range
	elif tool == "seojangdae":
		var sj := get_seojangdae_tiles(x, y)
		var sj_tiles: Array = sj["tiles"]
		for pt: Vector2i in sj_tiles:
			var gt: Dictionary = grid[pt.y][pt.x]
			if String(gt["building"]) == "wall":
				gt["sj_wall"] = true # 성벽 위에 세운 칸(철거하면 성벽으로 돌아간다, 그림은 성벽 높이만큼 받침을 올린다)
			gt["building"] = "seojangdae" if pt == Vector2i(x, y) else "seojangdae_site"
			gt["zone"] = ""
			gt["sj2"] = true
			gt["site_anchor"] = Vector2i(x, y)
			gt["wall_build"] = 2
			gt["wall_build_total"] = 2
			gt["bp_ticks"] = 0
			gt["bp_total"] = _ticks_until_boundaries(2)
			register_build_tile(pt.x, pt.y)
		grid[y][x]["site_tiles"] = sj_tiles
	elif tool == "hwahong":
		var hw := get_hwahong_tiles(x, y)
		var hw_tiles: Array = hw["tiles"]
		var hw_anchor: Vector2i = hw["anchor"]
		for pt in hw_tiles:
			var gt: Dictionary = grid[pt.y][pt.x]
			gt["building"] = "wall"
			gt["zone"] = ""
			gt["is_bridge"] = true
			gt["site_anchor"] = hw_anchor
			gt["site_tiles"] = hw_tiles
			gt["is_hwahong"] = true
			gt["wall_build"] = 2
			gt["wall_build_total"] = 2
			gt["bp_ticks"] = 0
			gt["bp_total"] = _ticks_until_boundaries(2)
			WaterStructureManager.bind_structure_metadata(gt, "hwahong_mun", "화홍문 (華虹門)")
			register_build_tile(pt.x, pt.y)
	else:
		var was: String = t["building"]
		t["building"] = tool
		t["zone"] = ""
		t["is_bridge"] = (t["terrain"] == "water" and tool in BRIDGEABLE)
		if tool == "wall" and t["terrain"] == "water":
			WaterStructureManager.on_wall_cross_river(self, x, y)
		# PORT-TRACE [성곽 축조 기간]: 성곽·성문은 선을 긋는 즉시 완성되지 않고 몇 턴에 걸쳐 쌓는다.
		# 이미 같은 것이 있는 칸을 다시 그을 때는 진행 중인 공정을 처음으로 되돌리지 않는다.
		if WALL_BUILD_TURNS.has(tool) and was != tool:
			t["wall_build"] = int(WALL_BUILD_TURNS[tool])
			t["wall_build_total"] = int(WALL_BUILD_TURNS[tool])
			t["bp_ticks"] = 0
			t["bp_total"] = _ticks_until_boundaries(int(WALL_BUILD_TURNS[tool]))
			register_build_tile(x, y)
		# PORT-TRACE [공공시설 변형]: 우물(단독/지붕/공동)·순라청·멸화군(망루 유무)은 지을 때 외형을 고른다
		if tool in ["well", "patrol", "firefighter"] and was != tool:
			t["variant"] = randi() % 3
	_update_zone_count_delta(old_b, str(t.get("building", "")))
	_logistics_dirty = true
	_road_connected_dirty = true
	_border_connections_dirty = true
	wall_loop_validator.invalidate()
	if tool in ["demolish", "reservoir", "manseokgeo", "chukmanje", "zone_agr"] or old_b in ["reservoir", "manseokgeo", "chukmanje", "agr_1", "agr_2"]:
		IrrigationManager.recalculate_irrigation(self, null)
	if not suppress_signal:
		var changed_pt: Array[Vector2i] = [Vector2i(x, y)]
		emit_signal("grid_tiles_changed", changed_pt)
		emit_signal("grid_changed")
		BuildingManager.on_building_completed(tool, self, null)

## 포루(2x2)를 짓는다. forced_type이 있으면 그 종류로(대역사), instant면 공사 없이 완공 상태로.
func _build_poru(x: int, y: int, pr: Dictionary, forced_type: String, instant: bool) -> void:
	var pr_all: Array[Vector2i] = []
	pr_all.append_array(pr["wall"])
	pr_all.append_array(pr["out"])
	var pr_anchor: Vector2i = (pr["wall"] as Array)[0]
	var base_elev_pr: float = float(grid[pr_anchor.y][pr_anchor.x].get("elevation", 1.0))
	var pr_info := {"start": pr_anchor, "axis": pr["axis"], "out": pr["out_dir"], "type": forced_type if forced_type != "" else pr["type"], "elevation": base_elev_pr, "len": int(pr.get("len", 2))}
	for pt: Vector2i in pr_all:
		var gt: Dictionary = grid[pt.y][pt.x]
		gt["building"] = "poru" if pt in (pr["wall"] as Array) else "poru_site"
		gt["zone"] = ""
		gt["pr2"] = pr_info
		gt["site_anchor"] = pr_anchor
		if instant:
			gt["under_construction"] = false
			gt.erase("wall_build")
		else:
			gt["wall_build"] = 2
			gt["wall_build_total"] = 2
			gt["bp_ticks"] = 0
			gt["bp_total"] = _ticks_until_boundaries(2)
			register_build_tile(pt.x, pt.y)
	grid[pr_anchor.y][pr_anchor.x]["site_tiles"] = pr_all

## 공심돈(3x3)을 짓는다(forced_type·instant는 포루와 같다)
func _build_gongsimdon(x: int, y: int, gs: Dictionary, forced_type: String, instant: bool) -> void:
	var gs_all: Array[Vector2i] = []
	gs_all.append_array(gs["wall"])
	gs_all.append_array(gs["in"])
	gs_all.append_array(gs["out"])
	var base_elev_gs: float = float(grid[y][x].get("elevation", 1.0))
	var gs_info := {"center": Vector2i(x, y), "axis": gs["axis"], "out": gs["out_dir"], "type": forced_type if forced_type != "" else gs["type"], "elevation": base_elev_gs, "c2": int(gs.get("pair", 1))}
	for pt: Vector2i in gs_all:
		var gt: Dictionary = grid[pt.y][pt.x]
		gt["building"] = "gongsimdon" if pt == Vector2i(x, y) else ("gongsimdon_wall" if pt in (gs["wall"] as Array) else "gongsimdon_site")
		gt["zone"] = ""
		gt["gs3"] = gs_info
		gt["site_anchor"] = Vector2i(x, y)
		if instant:
			gt["under_construction"] = false
			gt.erase("wall_build")
		else:
			gt["wall_build"] = 3
			gt["wall_build_total"] = 3
			gt["bp_ticks"] = 0
			gt["bp_total"] = _ticks_until_boundaries(3)
			register_build_tile(pt.x, pt.y)
	grid[y][x]["site_tiles"] = gs_all

func _structure_type_exists(kind: String, typ: String) -> bool:
	var key := "gs3" if kind == "gongsimdon" else "pr2"
	for row in grid:
		for t: Dictionary in row:
			if t.has(key) and String((t[key] as Dictionary).get("type", "")) == typ:
				return true
	return false

## PORT-TRACE [성곽 대역사의 공심돈·포루]: 성곽 대역사가 끝나면 그 구간 성벽 위에 공심돈·포루를 함께 세운다. 대략의 자리(x, y) 가까운 완공 성벽에서
## 지을 수 있는 칸(곧은 성벽 3칸·바깥 빈 땅 등)을 찾아 공사 없이 완공 상태로 둔다. 이미 같은 종류가 있으면(직접 지었으면) 건너뛴다.
func place_project_structures(structs: Array) -> void:
	var placed := false
	for st: Dictionary in structs:
		var kind := String(st.get("kind", ""))
		var typ := String(st.get("type", ""))
		if _structure_type_exists(kind, typ):
			continue
		var pref := Vector2i(int(st["x"]), int(st["y"]))
		var cands: Array[Vector2i] = []
		for yy in range(pref.y - 14, pref.y + 15):
			for xx in range(pref.x - 14, pref.x + 15):
				if in_bounds(xx, yy) and _is_done_wall(xx, yy):
					cands.append(Vector2i(xx, yy))
		cands.sort_custom(func(a: Vector2i, b: Vector2i): return absi(a.x - pref.x) + absi(a.y - pref.y) < absi(b.x - pref.x) + absi(b.y - pref.y))
		for cpt: Vector2i in cands:
			if kind == "gongsimdon":
				var gs := get_gongsimdon_tiles(cpt.x, cpt.y)
				if String(gs["err"]) == "":
					_build_gongsimdon(cpt.x, cpt.y, gs, typ, true)
					placed = true
					break
			else:
				var pr := get_poru_tiles(cpt.x, cpt.y)
				if String(pr["err"]) == "":
					_build_poru(cpt.x, cpt.y, pr, typ, true)
					placed = true
					break
	if placed:
		wall_loop_validator.invalidate()
		emit_signal("grid_changed")

## 일괄 건설/지형 변경 후 단 1회 호출하여 신호 폭풍 및 중복 재계산 방지
func notify_batch_changed(tiles: Array[Vector2i]) -> void:
	_logistics_dirty = true
	_road_connected_dirty = true
	_border_connections_dirty = true
	wall_loop_validator.invalidate()
	emit_signal("grid_tiles_changed", tiles)
	emit_signal("grid_changed")
	BuildingManager.on_building_completed("", self, null)

## PORT-TRACE [성곽 축조 기간]: 사용자 요청 — "성곽도 선을 긋는 것만으로 완성되는 게 아니라 2턴
## 정도 제작되는 과정이 보여지고, 일꾼들이 건축기구로 석축을 쌓는 모습을 보면 재밌겠다".
## 성곽 2턴, 성문(육축·문루·옹성) 3턴. 남은 턴은 t["wall_build"]에, 전체 턴은 t["wall_build_total"]에.
## 공사 중에도 building은 "wall"/"gate"라서 이웃과의 연결·교지 조건(봉돈 인접 등)은 그대로 성립하고,
## 성곽 완공률(fortress_progress)에는 다 쌓은 구간만 들어간다. 그림은 단계별로 높아지는 석축 +
## 비계(CityLayer), 일꾼·거중기 애니메이션은 CitizenManager가 공사 중 구간에 배치한다.
## PORT-TRACE [건설 기간 확대]: 사용자 요청 — "사대문, 서장대, 봉돈 같은 건물도 클릭하면 바로
## 생기지 말고 1턴쯤 짓는 모습을 보여 달라". 한 칸짜리 관아·군사·수리 시설도 같은 공정 타이머를
## 쓴다(동헌·행궁·만석거는 원래부터 여러 턴 짓는 부지 건물). 성문은 3턴에서 2턴으로 조정.
const WALL_BUILD_TURNS := {
	"wall": 2, "gate": 2,
	"seojangdae": 1, "bongdon": 1, "gongsimdon": 1, "poru": 1, "yeonmudae": 1,
	"banghwasuryu": 1, "yongyeon": 1, "reservoir": 1, "levee": 1,
	"patrol": 1, "firefighter": 1, "guesthouse": 1, "factory": 1,
}

## 다 지은 것만 센다(공사 중인 칸 제외) — 교지 달성 판정용
func count_completed(prefix: String) -> int:
	var c := 0
	for row in grid:
		for t in row:
			if not t.has("wall_build") and String(t["building"]).begins_with(prefix):
				c += 1
	return c

## 착공(공사 중) 또는 완공 여부 판정 (부지 지정 즉시 퀘스트/가이드 완료 처리용)
func has_site_started(building: String) -> bool:
	for s in active_sites:
		if s.get("building", "") == building:
			return true
	for row in grid:
		for t in row:
			if String(t.get("building", "")).begins_with(building):
				return true
	return false

func is_wall_building(t: Dictionary) -> bool:
	return t.has("wall_build")

## 0~1: 성곽/성문이 얼마나 올라갔는지(완공이면 1). 착공 직후 1/(총+1), 한 턴마다 한 단씩 오른다.
## PORT-TRACE [단계별 건설]: 이제는 날(틱) 단위 공정률(bp_ticks/bp_total)이 있으면 그것을 쓴다 —
## 턴 사이에도 석축이 조금씩 오르고, 한 칸 건물은 터 다지기 → 골조 → 마무리로 넘어간다.
func wall_build_fraction(t: Dictionary) -> float:
	if t.has("zone_build"):
		return clampf(float(t["zone_build"]), 0.0, 1.0)
	if not t.has("wall_build"):
		return 1.0
	if t.has("bp_total") and int(t["bp_total"]) > 0:
		return clampf(float(t["bp_ticks"]) / float(t["bp_total"]), 0.03, 0.98)
	var total := float(t.get("wall_build_total", 2))
	var left := float(t["wall_build"])
	return clampf((total - left + 1.0) / (total + 1.0), 0.1, 1.0)

## 계절(턴) 경계마다 1회. 공사 중인 성곽·성문을 한 단계씩 쌓고, 이번 턴에 다 쌓인 칸 수를 반환.
func process_wall_builds() -> Dictionary:
	heal_structure_overwrites()
	var walls_done := 0
	var gates_done := 0
	var others: Array = [] # 이번 턴에 다 지은 그 밖의 건물 이름(중복 없이)
	var changed := false
	for row in grid:
		for t in row:
			if not t.has("wall_build"):
				continue
			changed = true
			var b: String = t["building"]
			if not WALL_BUILD_TURNS.has(b):
				# 공사 중에 철거·교체된 칸 — 타이머만 치운다
				t.erase("wall_build")
				t.erase("wall_build_total")
				continue
			t["wall_build"] = int(t["wall_build"]) - 1
			if int(t["wall_build"]) <= 0:
				if b == "wall":
					walls_done += 1
				elif b == "gate":
					gates_done += 1
				elif not (b in others):
					others.append(b)
				t.erase("wall_build")
				t.erase("wall_build_total")
				t.erase("bp_ticks")
				t.erase("bp_total")
	if changed:
		emit_signal("grid_changed")
		if walls_done > 0 or gates_done > 0 or not others.is_empty():
			BuildingManager.on_building_completed("wall", self, null)
	return {"wall": walls_done, "gate": gates_done, "others": others}

## 정점 배열(vertex_heights)에서 타일 (x,y)의 4개 모서리를 다시 읽어 elevation/corner_elev를 갱신.
func _refresh_tile_elevation(x: int, y: int) -> void:
	if not in_bounds(x, y):
		return
	var h_n: float = vertex_heights[y][x]
	var h_e: float = vertex_heights[y][x + 1]
	var h_s: float = vertex_heights[y + 1][x + 1]
	var h_w: float = vertex_heights[y + 1][x]
	var t: Dictionary = grid[y][x]
	t["corner_elev"] = [h_n, h_e, h_s, h_w]
	t["elevation"] = (h_n + h_e + h_s + h_w) / 4.0

## PORT-TRACE [지형 편집]: 사용자가 "산 정상 위치가 실제와 다르고, 행궁 자리도 애매하고,
## 하천도 실제와 달라서" 직접 지형을 그리고 싶다고 요청 — generate_map.py를 다시 돌리지 않고도
## 게임 안에서 붓으로 산/하천/평지를 다시 배치할 수 있게 한다. 건설 도구(validate_tool/비용)를
## 거치지 않는 "지도 설계" 전용 도구이며, 성 안/밖 구분 없이 어디든 칠할 수 있다.
## PORT-TRACE [지형 편집 세분화]: "지형 편집 툴이 너무 단순하다. 물의 깊이를 조절하고 싶은데
## 무조건 깊은 물만 만들어진다"는 요청 — 물 붓에 깊이 3단계를 둔다. 얕은 물은 걸어서 건널 만한
## 여울, 깊은 물은 기존처럼 배로만 건너는 깊은 하천.
const TERRAIN_PAINT_HEIGHT := {
	"plain": 1.0,
	"water_shallow": 0.5, "water": -0.4, "water_deep": -1.5,
}
## PORT-TRACE [블록 쌓기]: "산의 높이를 블록 쌓듯이 높일 수 있으면" 요청 — 산 붓만은 한 번
## 칠할 때 고정 높이로 덮어쓰지 않고, 클릭(드래그 1획)마다 한 단계씩 누적으로 쌓아 올린다.
const MOUNTAIN_BLOCK_STEP := 1.0
const MOUNTAIN_MAX_HEIGHT := 10.0

## 타일이 순수 산악(mountain) 지형인지 여부 판정
func is_mountain_tile(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	var t: Dictionary = grid[y][x]
	return String(t.get("terrain", "")) == "mountain"

## 해당 타일에 산짐승이 서식 가능한지 판정 (산지/깊은 숲 타일이면서 도로/건물/농지/제방 없음)
func is_wildlife_habitat(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	var t: Dictionary = grid[y][x]
	var terr: String = String(t.get("terrain", ""))
	var surf: String = String(t.get("surface", ""))
	var b: String = String(t.get("building", ""))
	var zone: String = String(t.get("zone", ""))
	if terr == "plain" or terr == "water":
		return false
	if b != "" or zone != "":
		return false
	return terr == "mountain" or (surf in ["forest", "rocky"] and terr != "plain")

func paint_terrain(cx: int, cy: int, kind: String, radius: int = 1, suppress_signal: bool = false) -> void:
	# 지표면 질감 브러시 (풀밭, 돌밭, 흙바닥, 흙밭, 우거진 숲)
	if kind in ["grass", "dirt", "field", "rocky", "forest"]:
		var surf_pts: Array[Vector2i] = []
		for y in range(cy - radius, cy + radius + 1):
			for x in range(cx - radius, cx + radius + 1):
				if not in_bounds(x, y):
					continue
				if Vector2(x - cx, y - cy).length() > radius + 0.4:
					continue
				var t: Dictionary = grid[y][x]
				t["surface"] = kind
				surf_pts.append(Vector2i(x, y))
		if not suppress_signal:
			emit_signal("grid_tiles_changed", surf_pts)
			emit_signal("grid_changed")
		return

	if kind == "mountain":
		_paint_mountain_block(cx, cy, radius, MOUNTAIN_BLOCK_STEP, suppress_signal)
		return
	# PORT-TRACE [지형 편집 세분화]: "산도 레벨에 맞게 다듬고 싶은데 그저 평지와 산만 있어서
	# 산을 깎으면 가파른 경사가 생긴다"는 요청 — 기존엔 "평지 붓"으로 단번에 높이 1.0까지
	# 깎아내려서 주변 산과 단차가 크게 생겼다. "산 깎기"는 산 쌓기와 같은 1블록 단위로 거꾸로
	# 내려서, 계단식으로 자연스럽게 낮출 수 있게 한다.
	if kind == "mountain_down":
		_paint_mountain_block(cx, cy, radius, -MOUNTAIN_BLOCK_STEP, suppress_signal)
		return
	if not TERRAIN_PAINT_HEIGHT.has(kind):
		return
	var h: float = TERRAIN_PAINT_HEIGHT[kind]
	# PORT-TRACE [지형 편집 세분화]: "water_shallow"/"water_deep"는 깊이만 다른 물이므로 실제
	# terrain 분류는 그대로 "water"로 저장한다(교량·범람 등 기존 로직이 "water" 문자열만 본다).
	var terrain_kind := "water" if kind.begins_with("water") else kind
	var touched_vertices: Dictionary = {}
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if not in_bounds(x, y):
				continue
			if Vector2(x - cx, y - cy).length() > radius + 0.4:
				continue
			var t: Dictionary = grid[y][x]
			t["terrain"] = terrain_kind
			t["building"] = ""
			t["zone"] = ""
			t["is_bridge"] = false
			t["under_construction"] = false
			for vy in [y, y + 1]:
				for vx in [x, x + 1]:
					vertex_heights[vy][vx] = h
					touched_vertices[Vector2i(vx, vy)] = true
	# 칠한 정점을 공유하는 모든 타일(붓 경계 바깥 1칸 포함)을 다시 계산해 이음매를 없앤다.
	var touched_tiles: Dictionary = {}
	for v in touched_vertices.keys():
		for dy in [-1, 0]:
			for dx in [-1, 0]:
				var tp := Vector2i(v.x + dx, v.y + dy)
				if in_bounds(tp.x, tp.y):
					touched_tiles[tp] = true
	for tp in touched_tiles.keys():
		_refresh_tile_elevation(tp.x, tp.y)
	if not suppress_signal:
		var tp_arr: Array[Vector2i] = []
		for k in touched_tiles.keys():
			tp_arr.append(k)
		emit_signal("grid_tiles_changed", tp_arr)
		emit_signal("grid_changed")

## 붓 반경 안 타일들이 공유하는 정점만 모아 한 번씩만 올리거나 내려서, 한 번 클릭하면 붓 영역
## 전체가 정확히 한 블록만큼 계단식으로 오르내린다("블록 쌓기"/"블록 깎기"). step이 양수면
## 산 쌓기, 음수면 산 깎기다. 이미 있는 도로/성곽/관문은 산길처럼 그대로 두고 높이만 바꾼다
## (실제로 성곽과 산길은 산을 그대로 타고 지어졌다).
func _paint_mountain_block(cx: int, cy: int, radius: int, step: float, suppress_signal: bool = false) -> void:
	var pts: Array[Vector2i] = []
	for y in range(cy - radius, cy + radius + 1):
		for x in range(cx - radius, cx + radius + 1):
			if in_bounds(x, y) and Vector2(x - cx, y - cy).length() <= radius + 0.4:
				pts.append(Vector2i(x, y))
	paint_mountain_tiles(pts, step, suppress_signal)

## PORT-TRACE [섬세한 지형 편집]: 사용자 요청 — "산이나 강을 그리면 주변 3칸이 한꺼번에 올라와 원하는
## 지형을 그리기 힘들다. 낮은 언덕을 만들려면 1레벨씩만 조정할 수 있어야 한다". 붓 크기(1/3/5칸)는
## CityLayer가 정해 넘기고, 여기서는 한 획(드래그 한 번)에 칠해진 칸들의 꼭짓점을 "한 번씩만"
## step만큼 올리거나 내린다 — 예전엔 드래그한 칸마다 3x3 붓을 따로 찍어 겹친 꼭짓점이 여러 번 솟았다.
func paint_mountain_stroke(centers: Array[Vector2i], radius: int, step: float) -> Array[Vector2i]:
	var target_set := {}
	for c0: Vector2i in centers:
		for y in range(c0.y - radius, c0.y + radius + 1):
			for x in range(c0.x - radius, c0.x + radius + 1):
				if in_bounds(x, y) and Vector2(x - c0.x, y - c0.y).length() <= radius + 0.4:
					target_set[Vector2i(x, y)] = true
	var pts: Array[Vector2i] = []
	for k in target_set.keys():
		pts.append(k)
	paint_mountain_tiles(pts, step, true)
	return pts

func paint_mountain_tiles(pts: Array[Vector2i], step: float, suppress_signal: bool = false) -> void:
	var vertex_set: Dictionary = {}
	for pt: Vector2i in pts:
		var x := pt.x
		var y := pt.y
		var t: Dictionary = grid[y][x]
		var b: String = t["building"]
		if step > 0.0:
			if not (b == "road" or b == "wall" or b == "gate"):
				t["building"] = ""
				t["zone"] = ""
			t["terrain"] = "mountain"
		t["is_bridge"] = false
		t["under_construction"] = false
		for vy in [y, y + 1]:
			for vx in [x, x + 1]:
				vertex_set[Vector2i(vx, vy)] = true
	var plain_h: float = TERRAIN_PAINT_HEIGHT["plain"]
	for v in vertex_set.keys():
		vertex_heights[v.y][v.x] = clampf(vertex_heights[v.y][v.x] + step, plain_h, MOUNTAIN_MAX_HEIGHT)
	var touched_tiles: Dictionary = {}
	for v in vertex_set.keys():
		for dy in [-1, 0]:
			for dx in [-1, 0]:
				var tp := Vector2i(v.x + dx, v.y + dy)
				if in_bounds(tp.x, tp.y):
					touched_tiles[tp] = true
	for tp in touched_tiles.keys():
		_refresh_tile_elevation(tp.x, tp.y)
		# PORT-TRACE [지형 편집 세분화]: 산 깎기로 네 꼭짓점이 모두 평지 높이까지 완전히
		# 내려오면 실제로도 더 이상 산이 아니므로 terrain을 "plain"으로 되돌린다(건설 규칙에
		# 쓰이는 t["terrain"]=="mountain" 판정이 시각적 높이와 어긋나지 않도록).
		var gt: Dictionary = grid[tp.y][tp.x]
		if gt["terrain"] == "mountain":
			var ce: Array = gt["corner_elev"]
			if ce[0] <= plain_h + 0.01 and ce[1] <= plain_h + 0.01 and ce[2] <= plain_h + 0.01 and ce[3] <= plain_h + 0.01:
				gt["terrain"] = "plain"
	if not suppress_signal:
		var tp_arr: Array[Vector2i] = []
		for k in touched_tiles.keys():
			tp_arr.append(k)
		emit_signal("grid_tiles_changed", tp_arr)
		emit_signal("grid_changed")

func export_terrain_data(path: String = TERRAIN_PATH) -> Dictionary:
	if FileAccess.file_exists(path):
		var old_text := FileAccess.get_file_as_string(path)
		var bak := FileAccess.open(path.get_basename() + ".backup.json", FileAccess.WRITE)
		if bak:
			bak.store_string(old_text)
			bak.close()
	var out: Dictionary = _loaded_json_cache.duplicate(true)
	out["size"] = size
	var flat_heights: Array = []
	for row in vertex_heights:
		for h in row:
			flat_heights.append(h)
	out["corner_heights"] = flat_heights
	var flat_terrain: Array = []
	var flat_surfaces: Array = []
	for row in grid:
		for t in row:
			flat_terrain.append(t["terrain"])
			flat_surfaces.append(t.get("surface", "grass"))
	out["terrain"] = flat_terrain
	out["surfaces"] = flat_surfaces
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"success": false, "msg": "기록을 열 수 없습니다: %s" % path}
	f.store_string(JSON.stringify(out))
	f.close()
	return {"success": true, "msg": "지형을 새 기본값으로 저장했습니다."}

## ───────────────────────────────────────────── 둔전·저수지·수로
## PORT-TRACE [둔전·저수지·수로]: 사용자 요청 — "성 외곽에 농지와 저수지를 만들 수 있어야 하고,
## 저수지에서 수로를 연결해 농지로 물을 공급해야 한다. 수로는 저수지를 만들면 자동으로 생성".
## 정조 시대 대유평(만석거)·서호(축만제)·만년제처럼 저수지를 끼고 둔전을 경영한 방식을 따른다.
## - 수로(building "canal")는 플레이어가 직접 놓지 않는다. 저수지(reservoir/만석거)에서 가까운
##   둔전부터 너비우선탐색(BFS)으로 최단 경로를 찾아 빈 땅에 자동으로 판다. 경로가 겹치면
##   자연스럽게 가지를 친 하나의 수로망이 된다.
## - 도로를 가로지르는 곳은 도로를 그대로 두고 "culvert"(돌 암거) 표시만 한다.
## - 논을 거쳐 더 먼 논으로 물이 흘러갈 수 있다(논물 대기) — 논 위에는 수로를 파지 않는다.
## - 저수지를 철거·되돌리면 저수지와 끊긴 수로는 자동으로 메워진다.
const CANAL_REACH := 14 # 저수지에서 수로를 뻗는 최대 거리(칸)
const RESERVOIR_BUILDINGS := ["reservoir", "manseokgeo", "manseokgeo_site", "chukmanje", "chukmanje_site", "yongyeon"]
const CANAL_DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

## 만석거/축만제/저수지 위치 목록 및 주변 유효 개간 POI 풀 갱신
func update_reservoir_positions() -> Array[Vector2i]:
	reservoir_positions.clear()
	reservoir_poi_pool.clear()
	var seen_poi: Dictionary = {}

	for y: int in range(size):
		for x: int in range(size):
			var cell: Dictionary = grid[y][x]
			if cell.get("building", "") in RESERVOIR_BUILDINGS and not cell.has("wall_build"):
				reservoir_positions.append(Vector2i(x, y))

	# 저수지 중심/타일들 기준 8칸(맨해튼 거리) 이내의 성 밖 평지 타일을 POI 풀에 사전 캐싱
	for rp: Vector2i in reservoir_positions:
		for dy: int in range(-8, 9):
			for dx: int in range(-8, 9):
				if absi(dx) + absi(dy) <= 8:
					var px: int = rp.x + dx
					var py: int = rp.y + dy
					if in_bounds(px, py):
						var pt := Vector2i(px, py)
						if not seen_poi.has(pt):
							seen_poi[pt] = true
							var ct: Dictionary = grid[py][px]
							if ct.get("terrain", "") == "outside" and ct.get("building", "") == "" and ct.get("zone", "") == "":
								reservoir_poi_pool.append(pt)

	WaterStructureManager.sync_reservoir_positions(self)
	return reservoir_positions

## 특정 좌표가 만석거/저수지 유효 관개 반경(기본 8칸) 이내인지 O(N_resv) 검사
func is_near_reservoir(pos: Vector2i, max_dist: int = 8) -> bool:
	if reservoir_positions.is_empty():
		return false
	for rp: Vector2i in reservoir_positions:
		if absi(pos.x - rp.x) + absi(pos.y - rp.y) <= max_dist:
			return true
	return false

## 해당 좌표 기준 상·하·좌·우 4방향에 도로가 인접해 있는지 O(1) 검사
func has_adjacent_road(pos: Vector2i) -> bool:
	if not in_bounds(pos.x, pos.y):
		return false
	for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		var n: Vector2i = pos + d
		if in_bounds(n.x, n.y):
			var cell: Dictionary = grid[n.y][n.x]
			var b: String = str(cell.get("building", ""))
			if b in ["road", "stone_road"] or cell.get("road_type", "") in ["dirt", "stone"] or cell.get("is_bridge", false) or is_patrol_road(n.x, n.y):
				return true
	return false

func is_farm_tile(t: Dictionary) -> bool:
	return t["zone"] == "agr" or String(t["building"]).begins_with("agr")

## 물이 흐를 수 있는 "물길" 타일(저수지·수로·암거 도로·논)
func is_waterway_tile(t: Dictionary) -> bool:
	var b: String = t["building"]
	return b in RESERVOIR_BUILDINGS or b == "canal" or t.get("culvert", false) or is_farm_tile(t)

func _canal_passable(t: Dictionary) -> bool:
	if t.get("under_construction", false):
		return false
	var b: String = t["building"]
	if b == "canal" or b in ["road", "stone_road"] or is_farm_tile(t):
		return true
	return b == "" and t["zone"] == "" and t["terrain"] in ["plain", "outside"]

func _reservoir_sources() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(size):
		for x in range(size):
			if grid[y][x]["building"] in RESERVOIR_BUILDINGS and not grid[y][x].has("wall_build"):
				out.append(Vector2i(x, y)) # 다 판 저수지만 물을 보낸다
	return out

## 수로망 재구성. 바뀐 게 있으면 true.
func rebuild_canals() -> bool:
	var sources := _reservoir_sources()
	var changed := false

	# 1) 저수지와 연결이 끊긴 옛 수로·암거 정리
	var linked := {}
	var queue: Array[Vector2i] = []
	for s in sources:
		linked[s] = true
		queue.append(s)
	var qi := 0
	while qi < queue.size():
		var p: Vector2i = queue[qi]
		qi += 1
		for d in CANAL_DIRS:
			var n := p + d
			if not in_bounds(n.x, n.y) or linked.has(n):
				continue
			var nt: Dictionary = grid[n.y][n.x]
			if nt["building"] == "canal" or nt.get("culvert", false) or is_farm_tile(nt):
				linked[n] = true
				queue.append(n)
	for y in range(size):
		for x in range(size):
			var t: Dictionary = grid[y][x]
			if linked.has(Vector2i(x, y)):
				continue
			if t["building"] == "canal":
				t["building"] = ""
				changed = true
			if t.get("culvert", false):
				t.erase("culvert")
				changed = true
	if sources.is_empty():
		return changed

	# 2) 저수지에서 가중 최단거리 탐색(Dial 버킷). 도로 칸은 비용 3 — 수로가 도로를 "따라"
	#    흐르지 않고 짧게 "가로지르기"만 하게 한다(그냥 BFS면 긴 도로 전체가 암거가 된다).
	var parent := {}
	var dist := {}
	var done := {}
	var order: Array[Vector2i] = []
	var buckets: Array = [[]]
	for s in sources:
		dist[s] = 0
		buckets[0].append(s)
	var cost_now := 0
	while cost_now < buckets.size():
		var bk: Array = buckets[cost_now]
		for p: Vector2i in bk:
			if done.has(p) or int(dist[p]) != cost_now:
				continue
			done[p] = true
			order.append(p)
			for d in CANAL_DIRS:
				var n := p + d
				if not in_bounds(n.x, n.y) or done.has(n):
					continue
				var nt: Dictionary = grid[n.y][n.x]
				if not _canal_passable(nt):
					continue
				var nc := cost_now + (3 if (nt["building"] in ["road", "stone_road"]) and not nt.get("culvert", false) else 1)
				if nc > CANAL_REACH:
					continue
				if not dist.has(n) or nc < int(dist[n]):
					dist[n] = nc
					parent[n] = p
					while buckets.size() <= nc:
						buckets.append([])
					buckets[nc].append(n)
		cost_now += 1

	# 3) 가까운 둔전부터: 이미 물길에 닿아 있지 않으면 부모를 거슬러 올라가며 수로를 판다
	var wet := {}
	for s in sources:
		wet[s] = true
	for p in order:
		var t: Dictionary = grid[p.y][p.x]
		if wet.has(p):
			continue
		if t["building"] == "canal" or t.get("culvert", false):
			if _touches(wet, p):
				wet[p] = true
			continue
		if not is_farm_tile(t):
			continue
		if _touches(wet, p):
			wet[p] = true
			continue
		# 목표 논 → 저수지 쪽으로 경로를 되짚으며 물길을 만든다
		var path: Array[Vector2i] = []
		var cur: Vector2i = p
		var trace_visited: Dictionary = {}
		while parent.has(cur) and not wet.has(cur):
			if trace_visited.has(cur):
				break
			trace_visited[cur] = true
			path.append(cur)
			cur = parent[cur]
		for q in path:
			var qt: Dictionary = grid[q.y][q.x]
			if qt["building"] == "" and qt["zone"] == "":
				qt["building"] = "canal"
				changed = true
			elif (qt["building"] == "road" or qt["building"] == "stone_road") and not qt.get("culvert", false):
				qt["culvert"] = true
				changed = true
			wet[q] = true
	return changed

func _touches(wet: Dictionary, p: Vector2i) -> bool:
	for d in CANAL_DIRS:
		if wet.has(p + d):
			return true
	return false

## 저수지에서 수로·암거·논을 따라 물이 닿는 논에 t["irrigated"]=true
func _recompute_irrigation() -> void:
	var seen := {}
	var queue: Array[Vector2i] = _reservoir_sources()
	for s in queue:
		seen[s] = true
	var qi := 0
	while qi < queue.size():
		var p: Vector2i = queue[qi]
		qi += 1
		for d in CANAL_DIRS:
			var n := p + d
			if not in_bounds(n.x, n.y) or seen.has(n):
				continue
			if is_waterway_tile(grid[n.y][n.x]):
				seen[n] = true
				queue.append(n)
	for y in range(size):
		for x in range(size):
			var t: Dictionary = grid[y][x]
			t["irrigated"] = is_farm_tile(t) and seen.has(Vector2i(x, y))

## 둔전 ↔ 도로 ↔ 성문 ↔ 성내 저장소(행궁/관아) 물류 경로 검증
## [PORT-TRACE 둔전 물류 BFS]: 둔전에서 생산된 곡물이 성문을 거쳐 성내 저장고로 운송되는 경로를 검증한다.
func check_dunjian_logistics() -> Dictionary:
	if not _logistics_dirty and not _logistics_cache.is_empty():
		return _logistics_cache

	var farm_tiles: Array[Vector2i] = []
	var inner_depots: Array[Vector2i] = []
	var completed_gates: Array[Vector2i] = []
	
	for y: int in range(size):
		for x: int in range(size):
			var t: Dictionary = grid[y][x]
			var b: String = t["building"]
			if is_farm_tile(t):
				farm_tiles.append(Vector2i(x, y))
			if b == "gate" and not t.has("wall_build"):
				completed_gates.append(Vector2i(x, y))
			if (b == "haenggung" or b == "haenggung_site") and not t.has("wall_build"):
				inner_depots.append(Vector2i(x, y))

	if farm_tiles.is_empty():
		_logistics_cache = {
			"total": 0,
			"connected": 0,
			"ratio": 1.0,
			"gates": completed_gates.size(),
			"has_depot": not inner_depots.is_empty()
		}
		_logistics_dirty = false
		return _logistics_cache

	# 행궁이 아직 미완공이면 성내 순라청/관공시설 또는 성내 도로를 임시 관아 저장소로 삼음
	if inner_depots.is_empty():
		for y: int in range(size):
			for x: int in range(size):
				var t: Dictionary = grid[y][x]
				if t["terrain"] != "outside" and (t["building"] in ["patrol", "guesthouse", "firefighter"] or t["building"] == "road"):
					inner_depots.append(Vector2i(x, y))
					if inner_depots.size() >= 6:
						break
			if inner_depots.size() >= 6:
				break

	# 성문이나 성내 저장소가 없으면 성 밖 둔전과의 연결 불가 -> 조기 반환 (불필요한 BFS 차단)
	if completed_gates.is_empty() or inner_depots.is_empty():
		_logistics_cache = {
			"total": farm_tiles.size(),
			"connected": 0,
			"ratio": 0.0,
			"gates": completed_gates.size(),
			"has_depot": not inner_depots.is_empty()
		}
		_logistics_dirty = false
		return _logistics_cache

	# 1단계: 성내 저장소에서 성내 도로망을 따라 닿을 수 있는 완공된 성문(gate) 탐색
	var inner_visited: Dictionary = {}
	var inner_queue: Array[Vector2i] = []
	for p: Vector2i in inner_depots:
		inner_visited[p] = true
		inner_queue.append(p)
	
	var reached_gates: Array[Vector2i] = []
	var q_idx: int = 0
	while q_idx < inner_queue.size():
		var cur: Vector2i = inner_queue[q_idx]
		q_idx += 1
		for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var n: Vector2i = cur + d
			if not in_bounds(n.x, n.y) or inner_visited.has(n):
				continue
			var nt: Dictionary = grid[n.y][n.x]
			var nb: String = nt["building"]
			if nb == "gate" and not nt.has("wall_build"):
				inner_visited[n] = true
				reached_gates.append(n)
			elif nb == "road" or nb in ["haenggung", "haenggung_site", "patrol", "guesthouse", "firefighter"]:
				if nt["terrain"] != "outside":
					inner_visited[n] = true
					inner_queue.append(n)

	# 2단계: 성내 저장소와 연결된 성문들로부터 성 밖 도로망을 따라 BFS 전파
	var logistics_roads: Dictionary = {}
	var outer_queue: Array[Vector2i] = []
	for g: Vector2i in reached_gates:
		logistics_roads[g] = true
		outer_queue.append(g)
	
	var o_idx: int = 0
	while o_idx < outer_queue.size():
		var cur: Vector2i = outer_queue[o_idx]
		o_idx += 1
		for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var n: Vector2i = cur + d
			if not in_bounds(n.x, n.y) or logistics_roads.has(n):
				continue
			var nt: Dictionary = grid[n.y][n.x]
			# 도로 및 암거 도로를 통해 운송 가능
			if nt["building"] == "road" or nt.get("culvert", false):
				logistics_roads[n] = true
				outer_queue.append(n)

	# 3단계: 각 둔전 타일이 물류 도로망에 인접해 있는지 검증
	var connected_count: int = 0
	for f: Vector2i in farm_tiles:
		var is_conn: bool = false
		for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var n: Vector2i = f + d
			if logistics_roads.has(n):
				is_conn = true
				break
		if is_conn:
			connected_count += 1

	var ratio: float = float(connected_count) / float(farm_tiles.size()) if farm_tiles.size() > 0 else 0.0
	_logistics_cache = {
		"total": farm_tiles.size(),
		"connected": connected_count,
		"ratio": ratio,
		"gates": reached_gates.size(),
		"has_depot": not inner_depots.is_empty()
	}
	_logistics_dirty = false
	return _logistics_cache

## 도로 타일 여부 검사 (일반 흙길, 박석길, 성문, 교량 도로)
func is_walkable_road_tile(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	var t: Dictionary = grid[y][x]
	var b: String = String(t.get("building", ""))
	if b == "road" or b == "stone_road" or b == "gate":
		return true
	if t.get("is_bridge", false) and b != "":
		return true
	return false

## [동적 건축물 좌표 관리]: 사용자가 직접 건축한 시설 및 성문의 실제 좌표를 동적 추적/갱신

## 성문 좌표 수동/동적 등록
func update_gate_position(gate_id: String, pos: Vector2i) -> void:
	gates[gate_id] = [pos.x, pos.y]
	_border_connections_dirty = true
	_logistics_dirty = true

## 특정 성문(사대문 및 수문)의 현재 실제 좌표 조회
func get_gate_pos(gate_id: String) -> Vector2i:
	var g_map: Dictionary = get_four_gates_positions()
	if g_map.has(gate_id):
		var p: Vector2i = g_map[gate_id]
		if p.x >= 0 and p.y >= 0:
			return p
	if gate_id in ["hwahong", "namsu"]:
		var w_pos: Vector2i = get_facility_pos(gate_id)
		if w_pos.x >= 0 and w_pos.y >= 0:
			return w_pos
	if gates.has(gate_id):
		var arr: Array = gates[gate_id]
		return Vector2i(int(arr[0]), int(arr[1]))
	# 기본 고증 fallback
	match gate_id:
		"jangan": return Vector2i(26, 6)
		"paldal": return Vector2i(16, 54)
		"hwaseo": return Vector2i(6, 13)
		"changryong": return Vector2i(48, 29)
		"hwahong": return Vector2i(35, 13)
		"namsu": return Vector2i(29, 54)
	return Vector2i(-1, -1)

## 사대문(장안문, 팔달문, 화서문, 창룡문) 타일 좌표 동적 조회 및 gates 딕셔너리 동기화
func get_four_gates_positions() -> Dictionary:
	var out: Dictionary = {
		"jangan": Vector2i(-1, -1),
		"paldal": Vector2i(-1, -1),
		"hwaseo": Vector2i(-1, -1),
		"changryong": Vector2i(-1, -1)
	}
	# 1. 실제 그리드 상의 완공된 gate 타일 전수 조사로 사용자가 지은 좌표를 최우선 확정
	for y: int in range(size):
		for x: int in range(size):
			var t: Dictionary = grid[y][x]
			if t.get("building", "") == "gate" and not bool(t.get("under_construction", false)) and not t.has("wall_build"):
				var gname: String = String(t.get("gate_name", ""))
				if gname.contains("장안") or gname.contains("jangan"):
					out["jangan"] = Vector2i(x, y)
					gates["jangan"] = [x, y]
				elif gname.contains("팔달") or gname.contains("paldal"):
					out["paldal"] = Vector2i(x, y)
					gates["paldal"] = [x, y]
				elif gname.contains("화서") or gname.contains("hwaseo"):
					out["hwaseo"] = Vector2i(x, y)
					gates["hwaseo"] = [x, y]
				elif gname.contains("창룡") or gname.contains("changryong"):
					out["changryong"] = Vector2i(x, y)
					gates["changryong"] = [x, y]
				else:
					# 이름 미지정 성문의 경우 방위/위치 기반 스마트 자동 매핑
					if y < 20 and out["jangan"].x < 0:
						out["jangan"] = Vector2i(x, y)
						gates["jangan"] = [x, y]
					elif y > 40 and out["paldal"].x < 0:
						out["paldal"] = Vector2i(x, y)
						gates["paldal"] = [x, y]
					elif x < 20 and out["hwaseo"].x < 0:
						out["hwaseo"] = Vector2i(x, y)
						gates["hwaseo"] = [x, y]
					elif x > 35 and out["changryong"].x < 0:
						out["changryong"] = Vector2i(x, y)
						gates["changryong"] = [x, y]

	# 2. 아직 그리드 상에 완공된 문이 없는 방위는 기존 gates 딕셔너리 또는 기본 고증 좌표를 폴백으로 유지
	if out["jangan"].x < 0 and gates.has("jangan"):
		var ja: Array = gates["jangan"]
		out["jangan"] = Vector2i(int(ja[0]), int(ja[1]))
	if out["paldal"].x < 0 and gates.has("paldal"):
		var pa: Array = gates["paldal"]
		out["paldal"] = Vector2i(int(pa[0]), int(pa[1]))
	if out["hwaseo"].x < 0 and gates.has("hwaseo"):
		var hw: Array = gates["hwaseo"]
		out["hwaseo"] = Vector2i(int(hw[0]), int(hw[1]))
	if out["changryong"].x < 0 and gates.has("changryong"):
		var ch: Array = gates["changryong"]
		out["changryong"] = Vector2i(int(ch[0]), int(ch[1]))

	return out

## 특정 핵심 건축물(행궁, 관아, 서장대, 연무대, 만석거, 수문 등)의 현재 실제 완공 좌표 조회
## 사용자가 직접 건설한 경우 그 위치를 반환하며, 미건설 시 역사적 권장 기본 좌표를 반환
func get_facility_pos(facility_id: String) -> Vector2i:
	# 사대문
	if facility_id in ["jangan", "paldal", "hwaseo", "changryong"]:
		return get_gate_pos(facility_id)

	# 건물 그리드 스캔 (사용자가 지은 완공 건물 탐색)
	for y: int in range(size):
		for x: int in range(size):
			var cell: Dictionary = grid[y][x]
			if cell.has("wall_build") or bool(cell.get("under_construction", false)):
				continue
			var b: String = str(cell.get("building", ""))
			var fac: String = str(cell.get("facility_id", ""))
			if b == facility_id or b == (facility_id + "_site") or fac == facility_id:
				return cell.get("site_anchor", Vector2i(x, y))
			if facility_id == "seojangdae" and cell.has("sj2"):
				return cell.get("site_anchor", Vector2i(x, y))
			if facility_id == "yeonmudae" and cell.has("ym5"):
				return cell.get("site_anchor", Vector2i(x, y))

	# 미완공 시 기본 고증 권장 좌표
	match facility_id:
		"haenggung": return Vector2i(14, 29) # 팔달산 동쪽 기슭 완만한 평지 7x7(가운데 칸)
		"gwana": return Vector2i(22, 28)
		"seojangdae": return Vector2i(5, 28) # 팔달산 정상 바위 2x2(왼쪽 위 칸) — 고도 최고점
		"yeonmudae": return Vector2i(38, 20)
		"manseokgeo": return Vector2i(8, 2)
		"hwahong": return Vector2i(35, 13)
		"namsu": return Vector2i(29, 54)

	return Vector2i(-1, -1)

## 특정 핵심 건축물이 맵 상에 완공되었는지 확인 (좌표 고정 없이 임의의 위치 건축 모두 인정)
func has_completed_facility(facility_id: String) -> bool:
	if facility_id in ["jangan", "paldal", "hwaseo", "changryong"]:
		var g_map: Dictionary = get_four_gates_positions()
		var gp: Vector2i = g_map.get(facility_id, Vector2i(-1, -1))
		if gp.x >= 0 and gp.y >= 0 and in_bounds(gp.x, gp.y):
			var t: Dictionary = grid[gp.y][gp.x]
			if t.get("building", "") == "gate" and not bool(t.get("under_construction", false)) and not t.has("wall_build"):
				return true
		return false

	if facility_id in ["hwahong", "namsu"]:
		for y: int in range(size):
			for x: int in range(size):
				var cell: Dictionary = grid[y][x]
				if cell.get("building", "") == facility_id and not bool(cell.get("under_construction", false)) and not cell.has("wall_build"):
					return true
		return false

	var p: Vector2i = get_facility_pos(facility_id)
	if p.x >= 0 and p.y >= 0 and in_bounds(p.x, p.y):
		var cell: Dictionary = grid[p.y][p.x]
		var b: String = str(cell.get("building", ""))
		var fac: String = str(cell.get("facility_id", ""))
		if (b == facility_id or b.begins_with(facility_id) or fac == facility_id) and not bool(cell.get("under_construction", false)) and not cell.has("wall_build"):
			return true
	return false

## 사대문(장안문, 팔달문, 화서문, 창룡문) 완공 여부 전수 검사
func are_all_four_gates_built() -> bool:
	var g_map: Dictionary = get_four_gates_positions()
	var found_keys: Dictionary = {}
	for k: String in ["jangan", "paldal", "hwaseo", "changryong"]:
		var p: Vector2i = g_map.get(k, Vector2i(-1, -1))
		if p.x >= 0 and p.y >= 0 and in_bounds(p.x, p.y):
			var t: Dictionary = grid[p.y][p.x]
			if t.get("building", "") == "gate" and not t.get("under_construction", false) and not t.has("wall_build"):
				found_keys[k] = true

	if found_keys.size() >= 4:
		return true

	var total_gates: int = 0
	for y: int in range(size):
		for x: int in range(size):
			var t: Dictionary = grid[y][x]
			if t.get("building", "") == "gate" and not t.get("under_construction", false) and not t.has("wall_build"):
				total_gates += 1
	return total_gates >= 4

## 사대문 기준 외곽 도로 도달 알고리즘 (Edge Reachability BFS)
## 이벤트 기반 호출(Throttled): 도로 타일 배치/철거 시에만 1회 계산 후 캐싱
func check_border_road_connections() -> Dictionary:
	if not _border_connections_dirty and not _border_connections_cache.is_empty():
		return _border_connections_cache

	_border_connections_dirty = false
	var gate_map: Dictionary = get_four_gates_positions()

	var new_results: Dictionary = {
		"jangan": {
			"connected": false,
			"gate_pos": gate_map["jangan"],
			"border_tile": Vector2i(-1, -1),
			"info": ROAD_DESTINATION_NAMES["jangan"]
		},
		"paldal": {
			"connected": false,
			"gate_pos": gate_map["paldal"],
			"border_tile": Vector2i(-1, -1),
			"info": ROAD_DESTINATION_NAMES["paldal"]
		},
		"changryong": {
			"connected": false,
			"gate_pos": gate_map["changryong"],
			"border_tile": Vector2i(-1, -1),
			"info": ROAD_DESTINATION_NAMES["changryong"]
		},
		"hwaseo": {
			"connected": false,
			"gate_pos": gate_map["hwaseo"],
			"border_tile": Vector2i(-1, -1),
			"info": ROAD_DESTINATION_NAMES["hwaseo"]
		}
	}

	# 4대문 각각에 대해 최외곽 경계선 도달 BFS 수행
	for k: String in ["jangan", "paldal", "changryong", "hwaseo"]:
		var gp: Vector2i = gate_map[k]
		if gp.x < 0 or gp.y < 0 or not in_bounds(gp.x, gp.y):
			continue

		var seen: Dictionary = {gp: true}
		var q: Array[Vector2i] = [gp]
		var head: int = 0
		var found_edge: Vector2i = Vector2i(-1, -1)

		while head < q.size() and head < 1200:
			var c: Vector2i = q[head]
			head += 1

			# 최외곽 경계선 도달 판정 (Edge Touch)
			if c != gp:
				var hit: bool = false
				match k:
					"jangan":
						hit = (c.y == 0)
					"paldal":
						hit = (c.y == size - 1)
					"hwaseo":
						hit = (c.x == 0)
					"changryong":
						hit = (c.x == size - 1)
				if hit:
					found_edge = c
					break

			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + d
				if seen.has(n) or not in_bounds(n.x, n.y):
					continue
				if not is_walkable_road_tile(n.x, n.y):
					continue
				seen[n] = true
				q.append(n)

		if found_edge.x >= 0:
			new_results[k]["connected"] = true
			new_results[k]["border_tile"] = found_edge

	# 신규 개통 알림 이벤트 처리
	var prev_cache: Dictionary = _border_connections_cache
	for k: String in ["jangan", "paldal", "changryong", "hwaseo"]:
		var is_conn: bool = bool(new_results[k]["connected"])
		var was_conn: bool = bool(prev_cache.get(k, {}).get("connected", false))
		if is_conn and not was_conn and not _announced_border_routes.has(k):
			_announced_border_routes[k] = true
			var inf: Dictionary = ROAD_DESTINATION_NAMES[k]
			emit_signal("external_road_opened", k, inf["sign_title"])
			var banner_msg: String = "[교역로 개통] 사대문과 외부를 잇는 '%s'이 열렸습니다!" % inf["sign_title"]
			if logistics:
				logistics.emit_signal("notice", banner_msg, "🪧")
		elif not is_conn and was_conn:
			_announced_border_routes.erase(k)

	_border_connections_cache = new_results
	emit_signal("border_road_connections_changed", _border_connections_cache)
	return _border_connections_cache


## 성곽 완공률과 치수 방재율 (updateFortressScore / updateWaterManagement)
func recompute_infrastructure(_jeong_hired: bool = false) -> void:
	get_four_gates_positions()
	WaterStructureManager.auto_heal_structures(self)
	update_reservoir_positions()
	# PORT-TRACE [둔전·저수지·수로]: 저수지·둔전이 바뀔 때마다 수로망과 관개 여부를 다시 계산
	if rebuild_canals():
		emit_signal("grid_changed")
	_recompute_irrigation()
	var _walls := 0
	var levees := 0
	var resv := 0
	for row in grid:
		for t in row:
			if t.has("wall_build"):
				continue # 아직 쌓는 중인 성곽·성문은 완공률에 넣지 않는다
			match t["building"]:
				"wall", "gate", "seojangdae", "bongdon", "gongsimdon", "gongsimdon_wall", "poru", "yeonmudae", "banghwasuryu":
					_walls += 1
				"levee": levees += 1
				"reservoir", "yongyeon": resv += 1
				"manseokgeo": resv += 6 # PORT-TRACE [만석거 6x6]: 실제 규모에 맞게 저수량 가중치를 크게 준다
	# PORT-TRACE [남수문·화홍문]: 완공된 수문 칸은 성곽 세 칸 몫(남·북 방어), 수문 및 저수지가 있으면 치수 방재율 가산
	var namsu := 0
	var hwahong := 0
	for row2 in grid:
		for t2 in row2:
			if not t2.has("wall_build"):
				if t2.get("is_namsu", false) or t2.get("building", "") == "namsu" or str(t2.get("facility_id", "")) == "namsu_mun":
					namsu += 1
				if t2.get("is_hwahong", false) or t2.get("building", "") == "hwahong" or str(t2.get("facility_id", "")) == "hwahong_mun":
					hwahong += 1
	_walls += namsu * 2
	_walls += hwahong * 2
	namsu_complete = namsu > 0
	hwahong_complete = hwahong > 0
	var loop_res: Dictionary = wall_loop_validator.validate_loop(self)
	fortress_progress = int(loop_res.get("validated_progress", 0))

	if is_flood_crisis:
		fortress_progress = int(float(fortress_progress) * 0.5) # 수해 위기 시 성 방호력 50% 반감
	var calc_flood: int = levees * 20
	if namsu_complete:
		calc_flood += 30
	if hwahong_complete:
		calc_flood += 30
	if resv > 0:
		calc_flood += mini(20, resv * 4)
	flood_defense = mini(100, calc_flood)
	reservoir_count = resv

func is_wall_loop_completed() -> bool:
	if wall_loop_validator:
		return wall_loop_validator.validate_loop(self).get("is_closed_loop", false)
	return false

# ---------------------------------------------------------------- 단계별 건설 공정(날 단위)
## PORT-TRACE [단계별 건설]: 사용자 요청 — "성문·성곽 말고 행궁·민가·저잣거리 등 모든 건물이 배치
## 즉시 완공되지 않고 공정률에 따라 터 다지기 → 뼈대/골조 → 완공 형태로 바뀌게". 완공 자체는 예전처럼
## 턴 경계에서 이뤄지고(경제·교지 판정 불변), 여기서는 그 사이의 날(틱)마다 공정률만 올려 그림을 바꾼다.
## 민가·저잣거리·공방은 자라나는(또는 기와집으로 승급하는) 순간부터 한 달(30일)에 걸쳐 지어진다.
const ZONE_BUILD_TICKS := 30
const DAYS_PER_TURN := 90
var current_tick: int = 0
var _last_progress_emit: int = -100

## 지금부터 n번째 턴 경계까지 남은 날 수
func _ticks_until_boundaries(n: int) -> int:
	return (DAYS_PER_TURN - current_tick % DAYS_PER_TURN) + maxi(n - 1, 0) * DAYS_PER_TURN

## 공정 단계 0=터 다지기, 1=골조, 2=마무리(완성 모습 + 비계), 3=완공
static func build_stage(frac: float) -> int:
	if frac >= 1.0:
		return 3
	if frac < 0.34:
		return 0
	if frac < 0.67:
		return 1
	return 2

func site_fraction(site: Dictionary) -> float:
	var total := int(site.get("bp_total", 0))
	if total <= 0:
		var tt := float(site.get("total_turns", 2))
		return clampf((tt - 1.0 - float(site["turns_left"])) / maxf(tt - 1.0, 1.0), 0.03, 0.98)
	return clampf(float(site.get("bp_ticks", 0)) / float(total), 0.03, 0.98)

## 공사 중인 부지(행궁·만석거)에서 이 칸이 속한 부지 정보. 없으면 빈 딕셔너리.
func site_at(p: Vector2i) -> Dictionary:
	for site in active_sites:
		if p in site["tiles"]:
			return site
	return {}

## TimeManager.simulation_tick마다(Main에서 연결). 공정률을 올리고 단계가 바뀐 곳이 있으면 다시 그리게 한다.
func on_build_tick(total_ticks: int) -> void:
	current_tick = total_ticks
	# PORT-TRACE [심시티 2000급 경량화]: 공사 중인 타일이나 부지가 없으면 4,096칸 전수조사를 즉시 회피(0ms)
	if _active_build_tiles.is_empty() and active_sites.is_empty():
		return

	var stage_changed := false
	var finished: Array[Vector2i] = []

	for pos: Vector2i in _active_build_tiles.keys():
		if not in_bounds(pos.x, pos.y):
			finished.append(pos)
			continue
		var t: Dictionary = grid[pos.y][pos.x]
		if t.has("zone_build"):
			var old_s: int = build_stage(float(t["zone_build"]))
			var f := float(t["zone_build"]) + 1.0 / float(ZONE_BUILD_TICKS)
			if f >= 1.0:
				t.erase("zone_build")
				finished.append(pos)
				stage_changed = true
			else:
				t["zone_build"] = f
				var new_s: int = build_stage(f)
				if new_s != old_s:
					stage_changed = true
		elif t.has("wall_build"):
			var old_s: int = int(wall_build_fraction(t) * 4.0)
			if t.has("bp_total"):
				t["bp_ticks"] = int(t["bp_ticks"]) + 1
			var new_s: int = int(wall_build_fraction(t) * 4.0)
			if new_s != old_s:
				stage_changed = true
		else:
			finished.append(pos)

	for p in finished:
		_active_build_tiles.erase(p)

	for site in active_sites:
		var old_s: int = build_stage(site_fraction(site))
		site["bp_ticks"] = int(site.get("bp_ticks", 0)) + 1
		var new_s: int = build_stage(site_fraction(site))
		if new_s != old_s:
			stage_changed = true

	# 시각적 공사 단계(터다지기->골조->마무리)가 실제로 바뀌었을 때만 지도를 다시 굽는다 (주기적 렉 완전 차단)
	if stage_changed and total_ticks - _last_progress_emit >= 2:
		_last_progress_emit = total_ticks
		emit_signal("construction_progressed")

func register_build_tile(x: int, y: int) -> void:
	_active_build_tiles[Vector2i(x, y)] = true

func unregister_build_tile(x: int, y: int) -> void:
	_active_build_tiles.erase(Vector2i(x, y))

## 민가·저잣거리·공방이 새로 들어서거나 승급할 때 공사를 시작한다(논밭은 제외 — 갈아엎으면 바로 논이다).
func _start_zone_build(t: Dictionary, x: int = -1, y: int = -1) -> void:
	var b: String = t["building"]
	if b.begins_with("res") or b.begins_with("com") or b.begins_with("ind"):
		t["zone_build"] = 0.0
		if x >= 0 and y >= 0:
			register_build_tile(x, y)
			ConstructionManager.register_construction_site(Vector2i(x, y), 0.0, 0)
	# PORT-TRACE [민가 외형 변형]: 초가 1A~1E(5종), 기와집 1F~1I(4종) 중 하나
	if b == "res_1":
		t["house_variant"] = randi() % HouseArt.HOUSE_VARIANTS[1].size()
	elif b == "res_2":
		t["house_variant"] = randi() % HouseArt.HOUSE_VARIANTS[2].size()
	if x >= 0 and (b.begins_with("com") or b.begins_with("ind")):
		assign_trade(x, y)

# ---------------------------------------------------------------- 상점·공방 업종(변형)과 집적
## PORT-TRACE [저잣거리 업종·집적]: 사용자 요청 — "박석길 주변에는 육의전, 흙길 주변에는 난전과 기타
## 상점이 들어서고, 비슷한 종류의 상점과 공방이 서로 붙어 모여 생기게(집적 효과)". 가게가 들어설 때
## (또는 기와집으로 승급할 때) 업종을 정한다: 1) 맞닿은 길이 박석길이면 육의전 목록, 흙길이면 난전 목록,
## 2) 반경 2칸 안의 가게·공방 업종을 세어 가장 많은 "업종 계열"을 80% 확률로 따른다(같은 거리에 같은
## 업종이 모인다). 업종은 t["trade"], 박석/흙 구분은 t["trade_cat"]에 저장하고 그림(MarketArt)이 읽는다.
const TRADE_FAMILY := {
	"silk": "cloth", "cotton": "cloth", "myeonju": "cloth", "ramie": "cloth", "paper": "paper", "fish": "food",
	"rice": "food", "veg": "food", "meat": "food", "gukbap": "food", "jumak": "food", "pottery": "pottery",
	"tent": "misc", "shoes": "leather", "herb": "misc", "gaekju": "misc",
	"yugi": "metal", "bangmul": "cloth", "fruit": "food", "tteok": "food", "jipsin": "leather", "salt": "food", "tobacco": "misc",
	"brass": "metal", "smith": "metal", "onggi": "pottery", "gat": "leather", "shoe": "leather",
	"brush": "paper", "hanji": "paper", "bow": "metal",
	"book": "paper", "cattle": "livestock", "jeotgal": "food", "lumber": "wood", "firewood": "wood",
}

# ---------------------------------------------------------------- 장마당(공터)
## PORT-TRACE [장마당·세시풍속]: 사용자 요청 — "장터 구역을 지정하면 면적의 약 10%를 상점이 들어서지 않는
## 빈 공터 '장마당'(2x2 또는 3x3)으로 남겨, 평소엔 난전·통행로로 쓰다가 계절 행사 때 연희 무대가 되게".
## 저잣거리 구획을 칠할 때(CityLayer) 칠한 칸 묶음 안에서 길과 맞닿은 정사각 덩어리를 골라 t["plaza"]
## = {x0, y0, n}을 단다. 장마당 칸은 구획(com)은 유지하되 가게가 자라지 않는다(develop_and_harvest).
## PORT-TRACE [주택가 놀이마당]: kind = "market"(장마당) 또는 "play"(방·리 주거 구획 안 2x2 공터 — 여인들의
## 널뛰기·그네뛰기). 놀이마당은 주거 구획 약 30칸마다 한 곳(12칸 이상 칠했을 때), 항상 2x2.
## PORT-TRACE [놀이마당 빈도·골목 놀이터]: 사용자 요청 — 놀이마당(널뛰기·그네) 빈도를 1/4로 줄이고, 같은 빈도로
## 어린이 골목 놀이터("kids": 말뚝박기·술래잡기·제기차기·강아지)를 둔다. 둘 다 주거 구획 120칸당 기대 1곳(소수점은 확률).
## PORT-TRACE [수원 쇠전 3x3]: kind "cattle"은 allocate_cattle_market가 팔달문 근처 저잣거리 안에 3x3으로 한 곳만 잡는다.
func allocate_plazas(tiles: Array[Vector2i], kind: String = "market", only: Array = []) -> int:
	if tiles.size() < (12 if kind in ["play", "kids"] else 8):
		return 0
	var inset := {}
	for p: Vector2i in tiles:
		inset[p] = true
	var n := 3 if (tiles.size() >= 45 and kind == "market") or kind == "cattle" else 2
	var want := maxi(1, int(round(float(tiles.size()) * 0.1 / float(n * n))))
	if kind in ["play", "kids"]:
		var expect := float(tiles.size()) / 120.0
		want = int(expect) + (1 if randf() < expect - floorf(expect) else 0)
		if want <= 0:
			return 0
	elif kind == "cattle" or kind == "salt":
		want = 1
	var cands: Array = tiles.duplicate() if only.is_empty() else only.duplicate()
	cands.shuffle()
	var made := 0
	for pass_i in range(2): # 1회차: 길과 맞닿은 덩어리만, 2회차: 아무 데나
		for p: Vector2i in cands:
			if made >= want:
				return made
			var ok := true
			var near_road := false
			for dy in range(n):
				for dx in range(n):
					var q := Vector2i(p.x + dx, p.y + dy)
					if not inset.has(q) or grid[q.y][q.x].has("plaza") or grid[q.y][q.x]["building"] != "":
						ok = false
					elif has_neighbor(q.x, q.y, "road"):
						near_road = true
			if not ok or (pass_i == 0 and not near_road):
				continue
			for dy in range(n):
				for dx in range(n):
					grid[p.y + dy][p.x + dx]["plaza"] = {"x0": p.x, "y0": p.y, "n": n, "kind": kind}
			made += 1
	return made

## 지금 온전히 남아 있는 장마당 목록 [{x0, y0, n, center: Vector2}]
func list_plazas(kind: String = "market") -> Array:
	var out: Array = []
	for y in range(size):
		for x in range(size):
			var t: Dictionary = grid[y][x]
			if not t.has("plaza"):
				continue
			var pl: Dictionary = t["plaza"]
			if int(pl["x0"]) != x or int(pl["y0"]) != y or String(pl.get("kind", "market")) != kind:
				continue
			var n := int(pl["n"])
			var whole := true
			for dy in range(n):
				for dx in range(n):
					if not in_bounds(x + dx, y + dy) or not grid[y + dy][x + dx].has("plaza") or grid[y + dy][x + dx]["building"] != "":
						whole = false
			if whole:
				out.append({"x0": x, "y0": y, "n": n, "center": Vector2(float(x) + float(n) * 0.5, float(y) + float(n) * 0.5)})
	return out

func is_stone_road(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	var t: Dictionary = grid[y][x]
	return t["building"] == "road" and t.get("road_type", "dirt") == "stone"

## "yuk"(박석길가 육의전) 또는 "nan"(흙길가 난전·일반 상점)
func shop_category(x: int, y: int) -> String:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if is_stone_road(x + d.x, y + d.y):
			return "yuk"
	# PORT-TRACE [장마당·세시풍속]: 화성행궁 인근(3칸 안)도 시전 거리 — 육의전·객주가 들어선다
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if absi(dx) + absi(dy) <= 3 and String(building_at(x + dx, y + dy)).begins_with("haenggung"):
				return "yuk"
	return "nan"

func _trade_pool(b: String, cat: String) -> Array:
	if b.begins_with("ind"):
		return MarketArt.WORKSHOP_TRADES
	if cat == "yuk":
		return MarketArt.YUK_BIG if b == "com_2" else MarketArt.YUK_TRADES
	return MarketArt.NAN_BIG if b == "com_2" else MarketArt.NAN_SMALL

## [저잣거리 상점 20종 & 4대문 상권 클러스터링]
## 팔달문 우시장(09_paldal_cattle_market)의 기존 생성 조건과 가축 거래 기믹을 100% 보존
func get_shop_asset_id(x: int, y: int) -> String:
	if not in_bounds(x, y):
		return "market_shop_01"
	var t: Dictionary = grid[y][x]

	# 1. 팔달문 우시장(소전) 무조건 보존
	if t.has("plaza"):
		var pl: Dictionary = t["plaza"]
		if String(pl.get("kind", "")) == "cattle":
			return "market_shop_09"

	if t.has("shop_asset_id"):
		return String(t["shop_asset_id"])

	# 2. 박석길 인접 여부 (고급 시전·육의전 4종: 01~04)
	var near_stone := false
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if is_stone_road(x + d.x, y + d.y):
			near_stone = true
			break
	if near_stone and randf() < 0.75:
		var s_id: String = "market_shop_%02d" % (1 + randi() % 4)
		t["shop_asset_id"] = s_id
		return s_id

	# 3. 4대문 상권 밀집 (장안/팔달/창룡/화서)
	var gate_positions: Dictionary = get_four_gates_positions()
	var closest_gate := ""
	var min_dist: int = 9999
	for g_key: String in ["jangan", "paldal", "changryong", "hwaseo"]:
		if gate_positions.has(g_key):
			var gp: Vector2i = gate_positions[g_key]
			if gp.x >= 0:
				var dist: int = absi(x - gp.x) + absi(y - gp.y)
				if dist < min_dist:
					min_dist = dist
					closest_gate = g_key

	var chosen_id: String = ""
	if min_dist <= 16 and randf() < 0.75:
		match closest_gate:
			"jangan": # 북문 4종 (05~08)
				chosen_id = "market_shop_%02d" % (5 + randi() % 4)
			"paldal": # 남문 3종 (10~12)
				chosen_id = "market_shop_%02d" % (10 + randi() % 3)
			"changryong": # 동문 4종 (13~16)
				chosen_id = "market_shop_%02d" % (13 + randi() % 4)
			"hwaseo": # 서문 4종 (17~20)
				chosen_id = "market_shop_%02d" % (17 + randi() % 4)

	if chosen_id == "":
		chosen_id = "market_shop_%02d" % (1 + randi() % 20)

	t["shop_asset_id"] = chosen_id
	return chosen_id

## [조선시대 고증 공방 13종 에셋 ID 결정]
func get_workshop_asset_id(x: int, y: int) -> String:
	if not in_bounds(x, y):
		return "ws_1x1_carpenter"
	var t: Dictionary = grid[y][x]
	if t.has("ws_asset_id"):
		return String(t["ws_asset_id"])

	# 기본 1x1 소형 공방 (5종)
	var small_keys: Array[String] = ["ws_1x1_carpenter", "ws_1x1_bamboo", "ws_1x1_hanji", "ws_1x1_metalcraft", "ws_1x1_leather"]
	var sid: String = small_keys[(x * 7 + y * 13) % small_keys.size()]
	t["ws_asset_id"] = sid
	return sid

## [방·리 가옥 20종 에셋 ID 결정]
func get_house_asset_id(x: int, y: int) -> String:
	if not in_bounds(x, y):
		return "thatch_house_01"
	var t: Dictionary = grid[y][x]
	var b: String = t.get("building", "")

	if b == "res_1":
		if t.has("hgroup"):
			var v: int = int(t.get("house_variant", 7))
			v = clampi(v, 7, 9)
			return "thatch_house_%02d" % (v + 1)
		else:
			var v1: int = int(t.get("house_variant", (x * 3 + y * 5) % 7))
			v1 = clampi(v1, 0, 6)
			return "thatch_house_%02d" % (v1 + 1)
	else:
		# res_2, res_3
		if t.has("hgroup"):
			var hg: Dictionary = t["hgroup"]
			var gw: int = int(hg.get("w", 1))
			var gh: int = int(hg.get("h", 1))
			if gw >= 3 and gh >= 3:
				return "tile_house_10_3x3"
			elif (gw >= 3 and gh >= 2) or (gw >= 2 and gh >= 3):
				return "tile_house_10_3x2"
			elif gw >= 2 and gh >= 2:
				var v4: int = int(t.get("house_variant", 7))
				v4 = 7 if v4 < 8 else 8
				return "tile_house_%02d" % (v4 + 1)
			else:
				var v3: int = int(t.get("house_variant", 4))
				v3 = clampi(v3, 4, 6)
				return "tile_house_%02d" % (v3 + 1)
		else:
			var v0: int = int(t.get("house_variant", (x * 7 + y * 11) % 4))
			v0 = clampi(v0, 0, 3)
			return "tile_house_%02d" % (v0 + 1)

func assign_trade(x: int, y: int) -> void:
	var t: Dictionary = grid[y][x]
	var b: String = t["building"]
	if not (b.begins_with("com") or b.begins_with("ind")):
		return
	var cat := shop_category(x, y) if b.begins_with("com") else "ind"
	var pool := _trade_pool(b, cat)
	# PORT-TRACE [사대문 물류]: 개통된 성문 안쪽 6칸은 그 문으로 들어오는 물자의 전문 시장(장안문 지전·서책,
	# 팔달문 쇠전·싸전, 화서문 소금·어물·젓갈, 창룡문 목재·장작·약방·대장간)
	# 박석길가·행궁 인근(육의전 거리, cat == "yuk")은 성문 시장보다 육의전이 우선이다
	var gk := logistics.market_kind_at(x, y) if cat != "yuk" else ""
	if gk != "":
		var gpool := logistics.pool_for(gk, b)
		if not gpool.is_empty():
			pool = gpool
	var cur: String = t.get("trade", "")
	if cur in pool and t.get("trade_cat", "") == cat:
		return
	# 이웃 업종 계열 집계
	var fam_count := {}
	var trade_count := {}
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if (dx == 0 and dy == 0) or absi(dx) + absi(dy) > 3 or not in_bounds(x + dx, y + dy):
				continue
			var nt: Dictionary = grid[y + dy][x + dx]
			var ntr: String = nt.get("trade", "")
			if ntr == "":
				continue
			var fam: String = TRADE_FAMILY.get(ntr, "misc")
			fam_count[fam] = int(fam_count.get(fam, 0)) + 1
			trade_count[ntr] = int(trade_count.get(ntr, 0)) + 1
	var pick := ""
	if not fam_count.is_empty() and randf() < 0.8:
		var best_fam := ""
		var best_n := -1
		for fam in fam_count:
			if int(fam_count[fam]) > best_n:
				best_n = int(fam_count[fam])
				best_fam = fam
		# 같은 업종이 이웃에 있으면 그대로, 아니면 같은 계열 업종 중 하나
		var best_tr := ""
		var best_tn := -1
		for t_name in trade_count:
			if t_name in pool and TRADE_FAMILY.get(t_name, "misc") == best_fam and int(trade_count[t_name]) > best_tn:
				best_tn = int(trade_count[t_name])
				best_tr = t_name
		if best_tr != "":
			pick = best_tr
		else:
			var same_fam: Array = pool.filter(func(t_item: String) -> bool: return TRADE_FAMILY.get(t_item, "misc") == best_fam)
			if not same_fam.is_empty():
				pick = same_fam[randi() % same_fam.size()]
	if pick == "":
		pick = pool[randi() % pool.size()]
	if cur != "" and cur != pick and not t.has("zone_build"):
		t["zone_build"] = 0.0 # 업종이 바뀌면(예: 흙길이 박석길로 포장됨) 가게를 새로 짓는다
		register_build_tile(x, y)
		ConstructionManager.register_construction_site(Vector2i(x, y), 0.0, 0)
	t["trade"] = pick
	t["trade_cat"] = cat
	t["variant"] = randi() % 3

## 자율 구획 발전 및 수확. 반환: {gold, rice, pop}
# ---------------------------------------------------------------- 입지 점수·상점 번영·민가 등급
## PORT-TRACE [입지·번영·민가 등급]: 사용자 요청 — "상점은 성문 인근·도로 교차로·유동 인구가 많은 곳일수록,
## 치안·민심이 좋을수록 잘 자라고, 시전세가 낮으면 번영하고 높으면 침체·폐업한다. 매출과 세입은 입지 점수와
## 번영도로 달라진다. 민가는 박석길·관아 근처 중심부에 기와집·부호의 집이, 흙길·성곽 외곽 변두리에
## 초가가 서고, 길이 포장되는 등 기반이 좋아지면 윗 등급으로 개축된다."
## - 입지 점수(land_value, 0~100): 길(박석 +25/흙 +10), 교차로 +10, 성문 4칸 안 +15(8칸 안 +7),
##   유동 인구(주변 2칸 가게·공방 x3 최대 15, 길 칸 x1 최대 8), 관아·공공시설 4칸 안 +12(우물 +5),
##   치안망 +8, 성 밖 -15, 성곽 2칸 안 -8(외곽). 턴마다 구획 칸만 계산해 t["lv"]에 둔다.
## - 성장 배율 g = 입지/50 x 민심/70 x 세율 계수(7% 기준, 1%p마다 -+10%), 0.15~2.0.
## - 상점 번영도 t["prosper"](1~5): 조건이 좋으면 +1, 나쁘면 -1. 1단계에서 나쁜 조건이 이어지면 폐업(큰 가게는
##   작은 가게로 줄고, 작은 가게는 문을 닫는다). 매출 = 기본(35/110) x (0.5 + 입지/100) x (0.8 + 0.1 x 번영도).
## - 민가 등급: res_1 초가 -> res_2 기와집(입지 45 이상) -> 이웃 기와집과 합쳐 1x2 기와집(입지 60 이상) ->
##   네 채가 모여 2x2 부호의 집 res_3(입지 70 이상). 변두리(입지 45 미만)는 초가에 머문다.
var policy := {"loyalty": 70, "tax_market": 7, "tax_land": 7, "tax_military": 7}
const PUBLIC_BUILDINGS := ["haenggung", "haenggung_site", "gwana", "gwana_site", "jongnu", "jongnu_site", "patrol", "firefighter", "guesthouse", "seojangdae", "yeonmudae"]
var _gate_list: Array[Vector2i] = []

func set_policy(loyalty: int, tax_market: int, tax_land: int, tax_military: int, population: int = 0) -> void:
	policy = {"loyalty": loyalty, "tax_market": tax_market, "tax_land": tax_land, "tax_military": tax_military, "pop": population}

func _refresh_gate_list() -> void:
	_gate_list.clear()
	for y in range(size):
		for x in range(size):
			if grid[y][x]["building"] == "gate" and not grid[y][x].has("wall_build"):
				_gate_list.append(Vector2i(x, y))

func _road_degree(x: int, y: int) -> int:
	var n := 0
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if is_road_connector(x + d.x, y + d.y):
			n += 1
	return n

## PORT-TRACE [성능: 땅값 표]: 턴 계산 동안만(_lv_fast) 칸마다 9x9를 다시 훑지 않고, 턴 시작에 한 번 찍은 표에서
## 주변 가게·길 수(5x5), 관공서 가점(마름모 4칸), 행궁 인접(마름모 4칸), 성곽 인접(5x5)을 읽는다.
var _lv_fast := false
var _f_shops := PackedByteArray()
var _f_roads := PackedByteArray()
var _f_pub := PackedByteArray()
var _f_palace := PackedByteArray()
var _f_wall := PackedByteArray()

func _build_lv_fields() -> void:
	var n := size * size
	for arr: PackedByteArray in [_f_shops, _f_roads, _f_pub, _f_palace, _f_wall]:
		arr.resize(n)
		arr.fill(0)
	for y in range(size):
		for x in range(size):
			var b: String = grid[y][x]["building"]
			if b == "":
				continue
			var is_shop := b.begins_with("com") or b.begins_with("ind")
			if is_shop or b == "road":
				for yy in range(maxi(0, y - 2), mini(size, y + 3)):
					for xx in range(maxi(0, x - 2), mini(size, x + 3)):
						var i := yy * size + xx
						if is_shop:
							_f_shops[i] = mini(255, _f_shops[i] + 1)
						else:
							_f_roads[i] = mini(255, _f_roads[i] + 1)
			var pubv := 12 if b in PUBLIC_BUILDINGS else (5 if b == "well" else 0)
			var pal := b.begins_with("haenggung")
			if pubv > 0 or pal:
				for yy2 in range(maxi(0, y - 4), mini(size, y + 5)):
					for xx2 in range(maxi(0, x - 4), mini(size, x + 5)):
						if absi(xx2 - x) + absi(yy2 - y) > 4:
							continue
						var i2 := yy2 * size + xx2
						if pubv > _f_pub[i2]:
							_f_pub[i2] = pubv
						if pal:
							_f_palace[i2] = 1
			if b == "wall":
				for yy3 in range(maxi(0, y - 2), mini(size, y + 3)):
					for xx3 in range(maxi(0, x - 2), mini(size, x + 3)):
						_f_wall[yy3 * size + xx3] = 1

func land_value(x: int, y: int) -> int:
	if _lv_fast:
		return _land_value_fast(x, y)
	var v := 0
	var road_adj := 0
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if is_stone_road(x + d.x, y + d.y):
			road_adj = maxi(road_adj, 25)
		elif building_at(x + d.x, y + d.y) == "road":
			road_adj = maxi(road_adj, 10)
	v += road_adj
	# 교차로(길이 세 갈래 이상 만나는 칸)가 바로 곁에 있으면
	var crossing := false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if building_at(x + dx, y + dy) == "road" and _road_degree(x + dx, y + dy) >= 3:
				crossing = true
	if crossing:
		v += 10
	# 성문 인근
	var gd := 99
	for g: Vector2i in _gate_list:
		gd = mini(gd, absi(g.x - x) + absi(g.y - y))
	if gd <= 4:
		v += 15
	elif gd <= 8:
		v += 7
	# 유동 인구·관아
	var shops := 0
	var roads := 0
	var public_bonus := 0
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var nx := x + dx
			var ny := y + dy
			if not in_bounds(nx, ny) or absi(dx) + absi(dy) > 4:
				continue
			var nb: String = grid[ny][nx]["building"]
			if absi(dx) <= 2 and absi(dy) <= 2:
				if nb.begins_with("com") or nb.begins_with("ind"):
					shops += 1
				elif nb == "road":
					roads += 1
			if nb in PUBLIC_BUILDINGS:
				public_bonus = 12
			elif nb == "well":
				public_bonus = maxi(public_bonus, 5)
	v += mini(shops * 3, 15) + mini(roads, 8) + public_bonus
	if has_security_coverage(x, y):
		v += 8
	# PORT-TRACE [경제 규모·입지 등급]: 사용자 요청 — "도시 경제 규모가 커지면 초가가 기와·중층 건물로 발전하고,
	# 화성행궁·사대문 대로변·관공서 근처는 처음부터 고급 상점과 기와집이 들어서게". 행궁 4칸 안 +20,
	# 도시 인구가 늘수록 모든 땅의 값어치가 함께 오른다(인구 80명당 +1, 최대 +15).
	var near_palace := false
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			if absi(dx) + absi(dy) <= 4 and String(building_at(x + dx, y + dy)).begins_with("haenggung"):
				near_palace = true
	if near_palace:
		v += 20
	v += mini(15, int(float(policy.get("pop", 0)) / 80.0))
	if grid[y][x]["terrain"] == "outside":
		v -= 15
	elif _near_wall(x, y):
		v -= 8
	return clampi(v, 0, 100)

func _land_value_fast(x: int, y: int) -> int:
	var v := 0
	var road_adj := 0
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if is_stone_road(x + d.x, y + d.y):
			road_adj = maxi(road_adj, 25)
		elif building_at(x + d.x, y + d.y) == "road":
			road_adj = maxi(road_adj, 10)
	v += road_adj
	var crossing := false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if building_at(x + dx, y + dy) == "road" and _road_degree(x + dx, y + dy) >= 3:
				crossing = true
	if crossing:
		v += 10
	var gd := 99
	for g: Vector2i in _gate_list:
		gd = mini(gd, absi(g.x - x) + absi(g.y - y))
	if gd <= 4:
		v += 15
	elif gd <= 8:
		v += 7
	var i := y * size + x
	v += mini(int(_f_shops[i]) * 3, 15) + mini(int(_f_roads[i]), 8) + int(_f_pub[i])
	if has_security_coverage(x, y):
		v += 8
	if _f_palace[i] == 1:
		v += 20
	v += mini(15, int(float(policy.get("pop", 0)) / 80.0))
	if grid[y][x]["terrain"] == "outside":
		v -= 15
	elif _f_wall[i] == 1:
		v -= 8
	return clampi(v, 0, 100)

func _near_wall(x: int, y: int) -> bool:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if building_at(x + dx, y + dy) == "wall":
				return true
	return false

## 성장 배율: 입지·민심·세율(상점은 시전세, 민가는 지세·군포 평균)
func _growth_mult(lv: int, tax: float) -> float:
	var tax_factor := clampf(1.0 - (tax - 7.0) * 0.1, 0.3, 1.6)
	return clampf((float(lv) / 50.0) * (float(policy["loyalty"]) / 70.0) * tax_factor, 0.15, 2.0)

## PORT-TRACE [성능: 턴 계산 나누기]: stepped면 지도 16줄마다 한 프레임 쉬어 가며 계산한다(턴 처리 프레임이 ~200ms 멈칫하던 것을
## 여러 프레임으로 분산). 결과는 같다. TurnSystem은 await로 부른다.
func develop_and_harvest(demand_res: int, demand_com: int, demand_agr: int, hyoryungwon_blessing: bool, stepped: bool = false) -> Dictionary:
	var add_gold := 0
	var add_rice := 0
	var add_pop := 0
	var closed := 0
	var closed_tax := 0
	var closed_unrest := 0
	var closed_site := 0
	var dist_field := build_road_distance_field() # PORT-TRACE P24: O(size^2) 1회로 거리장 선계산
	# PORT-TRACE [렉: 턴 정산 멈칫]: 거리장(20ms 남짓), 치안·생활 수준장·물류(20ms 남짓), 첫 줄들을 프레임마다 나눈다
	if stepped and is_inside_tree():
		await get_tree().process_frame
		GameGrid.frame_take()
	_refresh_gate_list()
	_build_security_field()
	_build_lv_fields()
	_lv_fast = true
	_water_valid = false
	logistics.refresh()
	jongnu_pos = find_building_anchor("jongnu")
	maehyang_pos = _find_maehyang()
	if stepped and is_inside_tree():
		await get_tree().process_frame
		GameGrid.frame_take()
	var tax_m := float(policy["tax_market"])
	var tax_r := (float(policy["tax_land"]) + float(policy["tax_military"])) * 0.5
	var loyalty := int(policy["loyalty"])
	var farm_capacity_limit: int = DifficultyManager.get_farm_capacity_limit(houses_count)
	var current_cultivated_farms: int = 0
	for y in range(size):
		if stepped and y % 16 == 15 and is_inside_tree():
			await get_tree().process_frame
			GameGrid.frame_take()
		for x in range(size):
			var t: Dictionary = grid[y][x]
			var d: int = dist_field[y][x] if dist_field[y][x] >= 0 else 99
			var b: String = t["building"]
			# PORT-TRACE [둔전·저수지·수로]: 수로로 물을 받는 논(irrigated)은 길이 없어도 개간되고,
			# 소출이 1.5배다. 공방(ind)은 상업 수요를 따라 야조소(ind_1)→관영 수공업소(ind_2)로 큰다.
			var irrigated: bool = t.get("irrigated", false)
			var z: String = t["zone"]
			# 도로 연결 필수 시스템: 도로 미연결 시 일반 건물/구획 생산 및 성장 100% 정지
			var road_ok: bool = is_road_connected(x, y)
			if not road_ok and (z != "" or b != ""):
				continue
			var lv := 0
			if z != "":
				lv = land_value(x, y)
				t["lv"] = lv
			# 업종이 아직 없거나, 길 포장이 바뀌어 육의전/난전 구분이 달라진 가게는 업종을 다시 정한다
			if (b.begins_with("com") or b.begins_with("ind")) and (not t.has("trade") or (b.begins_with("com") and t.get("trade_cat", "") != shop_category(x, y))):
				assign_trade(x, y)
			elif (b.begins_with("com") or b.begins_with("ind")) and not t.has("zone_build") and randf() < 0.2:
				# 성문 길이 새로 이어지면 성문 앞 가게들이 몇 턴에 걸쳐 차츰 그 문의 특화 업종으로 바뀐다
				var gk0 := logistics.market_kind_at(x, y) if not (b.begins_with("com") and String(t.get("trade_cat", "")) == "yuk") else ""
				if gk0 != "":
					var gp0 := logistics.pool_for(gk0, b)
					if not gp0.is_empty() and not (String(t.get("trade", "")) in gp0):
						assign_trade(x, y)
			if z != "" and b == "" and t.has("plaza"):
				# 장마당·놀이마당: 가게·집이 들어서지 않는 공터. 수원 쇠전(3x3)은 기준 칸에서 소 거래 세입을 거둔다
				var plz: Dictionary = t["plaza"]
				if String(plz.get("kind", "")) == "cattle" and int(plz["x0"]) == x and int(plz["y0"]) == y:
					add_gold += 150 + (100 if "paldal" in logistics.connected_kinds() else 0)
				elif String(plz.get("kind", "")) == "salt" and int(plz["x0"]) == x and int(plz["y0"]) == y:
					add_gold += 120 + (80 if "hwaseo" in logistics.connected_kinds() else 0) # 염전 소금 창고 도매
			elif z != "" and b == "":
				var dem := demand_res if z == "res" else (demand_agr if z == "agr" else demand_com)
				var g0 := _growth_mult(lv, tax_m if z == "com" else tax_r)
				if dem > 0 and (z == "agr" or randf() < clampf(0.35 + 0.5 * g0, 0.2, 1.0)):
					if z == "agr":
						if d <= 6 or irrigated:
							t["building"] = "agr_1"
							_start_zone_build(t, x, y)
					else:
						if d <= 3:
							if z == "com":
								if DifficultyManager.can_spawn_shop(houses_count, shops_count):
									t["building"] = "com_1"
									_start_zone_build(t, x, y)
									shops_count += 1
							else:
								t["building"] = "%s_1" % z
								_start_zone_build(t, x, y)
								if z == "res":
									houses_count += 1
					if String(t["building"]).begins_with("com"):
						t["prosper"] = 2
					# 처음부터 좋은 자리(입지 70 이상: 행궁·성문 대로변·관아 근처)면 초가 대신 기와집이 선다
					if t["building"] == "res_1" and lv >= 70:
						t["building"] = "res_2"
						t["house_variant"] = randi() % HouseArt.HOUSE_VARIANTS[2].size()
			elif b.begins_with("com"):
				# ---- 상점: 번영도·승급·침체·폐업
				var gm := _growth_mult(lv, tax_m)
				var sup := logistics.supply_at(x, y) # 물류 공급도 0~7
				var good := (lv >= 45 or (sup >= 2 and lv >= 30)) and tax_m <= 8.0 and loyalty >= 60
				var bad := tax_m >= 11.0 or loyalty < 40 or lv < 20
				var pr := int(t.get("prosper", 2))
				if good:
					pr = mini(pr + 1, 5)
				elif bad:
					pr = maxi(pr - 1, 1)
				if sup >= 4 and not bad:
					pr = mini(pr + 1, 5) # 사대문 물자가 모이는 십자로 시전: 번영도 추가 상승
				var near_bell := jongnu_pos.x >= 0 and absi(jongnu_pos.x - x) + absi(jongnu_pos.y - y) <= 7
				if near_bell and not bad:
					pr = mini(pr + 1, 5) # 종루 앞 시전: 번영도 추가 상승
				var near_bridge := maehyang_pos.x >= 0 and absi(maehyang_pos.x - x) + absi(maehyang_pos.y - y) <= 6
				if near_bridge and not bad and randf() < 0.5:
					pr = mini(pr + 1, 5) # 매향교 다리목 상권
				t["prosper"] = pr
				t["supply"] = sup
				t["bell"] = near_bell
				t["bridge"] = near_bridge
				var shut := false
				if bad and pr == 1:
					var close_p := 0.06 + maxf(0.0, tax_m - 10.0) * 0.04 + (0.06 if loyalty < 40 else 0.0)
					if randf() < close_p:
						closed += 1
						# 폐업 까닭: 세금 → 민심 → 입지 순으로 하나만 센다(알림이 실제 까닭을 말하도록)
						if tax_m >= 11.0:
							closed_tax += 1
						elif loyalty < 40:
							closed_unrest += 1
						else:
							closed_site += 1
						shut = true
						if b == "com_2":
							t["building"] = "com_1"
						else:
							t["building"] = ""
							t.erase("trade")
							t.erase("trade_cat")
							shops_count = maxi(0, shops_count - 1)
				# 물자가 넉넉한 곳(성문 특화 시장·십자로 시전)의 초가 난전은 수요·입지 문턱이 낮고 더 빨리 기와 가게로 승급
				var up_dem := 5 if sup >= 2 else 15
				var up_lv := 30 if sup >= 2 else 40
				if not shut and b == "com_1" and demand_com > up_dem and lv >= up_lv and has_water_supply(x, y):
					if randf() < clampf((0.45 if d == 1 else 0.3) * gm * (1.0 + 0.3 * float(sup)), 0.0, 0.95):
						t["building"] = "com_2"
						_start_zone_build(t, x, y)
			elif b == "res_1":
				# ---- 민가: 입지 45 이상이면 기와집으로 개축(입지 70 이상이면 수요와 상관없이)
				if lv >= 45 and has_water_supply(x, y):
					var chance := (0.5 if demand_res > 15 else 0.15) * _growth_mult(lv, tax_r)
					if lv >= 70:
						chance = maxf(chance, 0.3)
					if randf() < chance:
						t["building"] = "res_2"
						_start_zone_build(t, x, y)
			elif b.ends_with("_1") and (b.begins_with("agr") or b.begins_with("ind")):
				var kind := b.substr(0, 3)
				var dem2 := demand_agr if kind == "agr" else demand_com
				var water_ok := has_water_supply(x, y)
				if kind == "agr" and irrigated:
					if dem2 > 10 and randf() < 0.5:
						t["building"] = "agr_2"
				elif kind == "agr" and d == 1:
					if dem2 > 15 and water_ok and randf() < 0.65:
						t["building"] = "agr_2"
				elif kind == "ind" and d <= 3:
					if dem2 > 15 and water_ok and randf() < 0.45 * _growth_mult(lv, tax_m):
						t["building"] = "ind_2"
						_start_zone_build(t, x, y)
			var bonus := 1.4 if d == 1 else 1.0
			var irr_bonus := 1.5 if irrigated else 1.0
			if is_flood_crisis and String(t["building"]).begins_with("com"):
				t["sales"] = 0 # 수해 비상 대피 시 저잣거리 상점 영업 일괄 전면 정지
			else:
				match t["building"]:
					"res_1": add_pop += int(round(3 * bonus))
					"res_2": add_pop += int(round((11 if t.has("hgroup") else 9) * bonus))
					"res_3": add_pop += int(round(16 * bonus))
					"com_1", "com_2":
						var base := 35.0 if t["building"] == "com_1" else 110.0
						var sales := int(round(base * (0.5 + float(lv) / 100.0) * (0.8 + 0.1 * float(t.get("prosper", 2))) * (1.0 + 0.15 * float(t.get("supply", 0))) * (1.3 if t.get("bell", false) else 1.0) * (1.15 if t.get("bridge", false) else 1.0)))
						if is_fire_active:
							var f_pen: float = DifficultyManager.get_disaster_penalty("fire")
							sales = int(float(sales) * (1.0 - f_pen))
						t["sales"] = sales
						add_gold += sales
					"agr_1", "agr_2":
						if current_cultivated_farms < farm_capacity_limit:
							current_cultivated_farms += 1
							t.erase("labor_shortage")
							var base_r: float = 40.0 if t["building"] == "agr_1" else 100.0
							var is_grace: bool = true
							if "sim" in self and self.sim != null:
								is_grace = FarmManager.is_grace_period(self.sim)
							var r_yield: int = FarmManager.calculate_tile_yield(t, base_r * irr_bonus, is_grace)
							if is_drought or is_flood_crisis:
								var d_pen: float = DifficultyManager.get_disaster_penalty("drought")
								r_yield = int(float(r_yield) * (1.0 - d_pen))
							add_rice += r_yield
						else:
							t["labor_shortage"] = true
					"ind_1": add_gold += int(round(50 * bonus))  # 야조소·가마터
					"ind_2": add_gold += int(round(130 * bonus)) # 관영 수공업소(병기 수리·기와·벽돌)
					"guesthouse": add_gold += 140
					"factory": add_gold += 160
					"haenggung": add_gold += 220 # PORT-TRACE [행궁]: 왕실 별궁 운영·진상 수입
	# PORT-TRACE [영화정 2x2]: 만석거 곁 영화정(수리 관청)이 둔전 관개를 살피면 관개 논 소출 +15%
	if has_yeonghwajeong_near_manseok():
		var irr_n := 0
		for row3 in grid:
			for t3 in row3:
				if t3.get("irrigated", false) and String(t3["building"]).begins_with("agr"):
					irr_n += 1
		add_rice += int(round(float(irr_n) * 9.0))
	# PORT-TRACE [렉: 턴 정산 멈칫]: 민가 묶음(10ms 남짓)·공방 묶음(20ms 남짓)을 마지막 줄들과 한 프레임에 몰지 않는다
	if stepped and is_inside_tree():
		await get_tree().process_frame
		GameGrid.frame_take()
	_form_house_groups(tax_r)
	if stepped and is_inside_tree():
		await get_tree().process_frame
		GameGrid.frame_take()
	_form_workshop_groups()
	_security_field_valid = false # 턴 계산이 끝나면 다시 실시간 판정으로(건설로 치안망이 바뀔 수 있음)
	_lv_fast = false
	if hyoryungwon_blessing:
		add_gold += 80
	if is_flood_crisis:
		# 수해 비상 대피 체제: 국가 생산력(금화/식량) 50% 일시 반감
		add_gold = int(float(add_gold) * 0.5)
		add_rice = int(float(add_rice) * 0.5)
	emit_signal("grid_changed")
	return {"gold": add_gold, "rice": add_rice, "pop": add_pop, "shops_closed": closed,
		"shops_closed_tax": closed_tax, "shops_closed_unrest": closed_unrest, "shops_closed_site": closed_site}

## 반경 r 이내에 2x2 이상 또는 3x2/3x3 대형 저택이 존재하는지 검사 (희소성 Spacing Quota 강제)
func _is_near_large_mansion(cx: int, cy: int, radius: int, min_w: int = 2) -> bool:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var nx: int = cx + dx
			var ny: int = cy + dy
			if not in_bounds(nx, ny):
				continue
			var t: Dictionary = grid[ny][nx]
			if t.has("hgroup"):
				var hg: Dictionary = t["hgroup"]
				if int(hg.get("w", 1)) >= min_w or int(hg.get("h", 1)) >= min_w:
					return true
	return false

## 도시 전체 가옥 종류별 집계 (피라미드 비율 유지용)
func _count_house_types() -> Dictionary:
	var total_houses: int = 0
	var thatch_1x1: int = 0
	var thatch_2x1: int = 0
	var tile_1x1: int = 0
	var tile_1x2: int = 0
	var tile_2x2: int = 0
	var tile_mansion: int = 0 # 3x2, 3x3

	var visited_groups: Dictionary = {}
	for y: int in range(size):
		for x: int in range(size):
			var t: Dictionary = grid[y][x]
			var b: String = t.get("building", "")
			if not b.begins_with("res"):
				continue
			total_houses += 1
			if t.has("hgroup"):
				var hg: Dictionary = t["hgroup"]
				var key: String = "%d_%d" % [int(hg["x0"]), int(hg["y0"])]
				if visited_groups.has(key):
					continue
				visited_groups[key] = true
				var gw: int = int(hg.get("w", 1))
				var gh: int = int(hg.get("h", 1))
				if b == "res_1":
					thatch_2x1 += 1
				elif gw >= 3 or gh >= 3:
					tile_mansion += 1
				elif gw == 2 and gh == 2:
					tile_2x2 += 1
				else:
					tile_1x2 += 1
			else:
				if b == "res_1":
					thatch_1x1 += 1
				else:
					tile_1x1 += 1

	return {
		"total": total_houses,
		"thatch_1x1": thatch_1x1,
		"thatch_2x1": thatch_2x1,
		"tile_1x1": tile_1x1,
		"tile_1x2": tile_1x2,
		"tile_2x2": tile_2x2,
		"tile_mansion": tile_mansion
	}

## 공방 규모별 집계
func _count_workshop_types() -> Dictionary:
	var total_ws: int = 0
	var ws_1x1: int = 0
	var ws_2x1: int = 0
	var ws_2x2: int = 0
	var ws_3x3: int = 0
	var visited: Dictionary = {}

	for y: int in range(size):
		for x: int in range(size):
			var t: Dictionary = grid[y][x]
			var b: String = t.get("building", "")
			if not b.begins_with("ind"):
				continue
			total_ws += 1
			if t.has("ws_group"):
				var wg: Dictionary = t["ws_group"]
				var key: String = "%d_%d" % [int(wg["x0"]), int(wg["y0"])]
				if visited.has(key):
					continue
				visited[key] = true
				var ww: int = int(wg.get("w", 1))
				var wh: int = int(wg.get("h", 1))
				if ww == 3 and wh == 3:
					ws_3x3 += 1
				elif ww == 2 and wh == 2:
					ws_2x2 += 1
				else:
					ws_2x1 += 1
			else:
				ws_1x1 += 1

	return {
		"total": total_ws,
		"ws_1x1": ws_1x1,
		"ws_2x1": ws_2x1,
		"ws_2x2": ws_2x2,
		"ws_3x3": ws_3x3
	}

func _is_near_workshop(cx: int, cy: int, radius: int, min_w: int = 2) -> bool:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var nx: int = cx + dx
			var ny: int = cy + dy
			if not in_bounds(nx, ny):
				continue
			var t: Dictionary = grid[ny][nx]
			if t.has("ws_group"):
				var wg: Dictionary = t["ws_group"]
				if int(wg.get("w", 1)) >= min_w or int(wg.get("h", 1)) >= min_w:
					return true
	return false

## 기와집 및 초가집의 유기적 합필 (엄격한 피라미드 비율 및 희소성 거리 쿼터 적용)
func _form_house_groups(tax_r: float) -> void:
	var stats: Dictionary = _count_house_types()
	var total_h: int = int(stats.get("total", 0))
	if total_h <= 0:
		return

	# 피라미드 상한선 쿼터 계산
	var max_mansion: int = int(float(total_h) * 0.02) # 2% 이하 (가옥 50채당 최대 1채)
	var max_tile_2x2: int = int(float(total_h) * 0.06) # 6% 이하
	var max_tile_1x2: int = int(float(total_h) * 0.12) # 12% 이하
	var cur_mansion: int = int(stats.get("tile_mansion", 0))
	var cur_tile_2x2: int = int(stats.get("tile_2x2", 0))
	var cur_tile_1x2: int = int(stats.get("tile_1x2", 0))
	var cur_thatch_2x1: int = int(stats.get("thatch_2x1", 0))
	var total_thatch: int = int(stats.get("thatch_1x1", 0)) + cur_thatch_2x1
	var max_thatch_2x1: int = int(float(total_thatch) * 0.25) # 초가의 25% 상한

	for y: int in range(size - 1):
		for x: int in range(size - 1):
			var t: Dictionary = grid[y][x]
			if t.has("zone_build"):
				continue
			var b: String = t.get("building", "")
			var lv: int = int(t.get("lv", 0))
			var gr: float = _growth_mult(lv, tax_r)

			# ---------------------------------------------------------
			# 1. 2x1 중형 합필 초가집 (입지 30~44, 초가의 25% 상한)
			# ---------------------------------------------------------
			if b == "res_1" and not t.has("hgroup") and lv >= 30 and lv < 45 and cur_thatch_2x1 < max_thatch_2x1:
				for dd: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
					var nx: int = x + dd.x
					var ny: int = y + dd.y
					if in_bounds(nx, ny):
						var nt: Dictionary = grid[ny][nx]
						if nt.get("building", "") == "res_1" and not nt.has("hgroup") and not nt.has("zone_build"):
							if randf() < 0.25 * gr:
								var g_info := {"x0": x, "y0": y, "w": 2 if dd.x == 1 else 1, "h": 2 if dd.y == 1 else 1}
								var v_idx := 7 + (randi() % 3) # 08~10 (인덱스 7~9)
								t["hgroup"] = g_info
								t["house_variant"] = v_idx
								nt["hgroup"] = g_info
								nt["house_variant"] = v_idx
								cur_thatch_2x1 += 1
								break

			# 기와집이 아니면 이후 상위 합필 건너뜀
			if not (b in ["res_2", "res_3"]):
				continue

			# ---------------------------------------------------------
			# 2. 3x3 / 3x2 대부호·거상 대저택 (입지 80+, 박석길 인접, 반경 10칸 이격, 2% 이하)
			# ---------------------------------------------------------
			if total_h >= 50 and cur_mansion < max_mansion and lv >= 80 and not _is_near_large_mansion(x, y, 10, 3):
				var near_stone := false
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if is_stone_road(x + d.x, y + d.y):
						near_stone = true
						break
				if near_stone:
					# 3x3 검사
					if x + 2 < size and y + 2 < size:
						var ok9 := true
						for dy9: int in range(3):
							for dx9: int in range(3):
								var q9: Dictionary = grid[y + dy9][x + dx9]
								if not (q9.get("building", "") in ["res_2", "res_3"]) or int(q9.get("lv", 0)) < 80 or q9.has("zone_build"):
									ok9 = false
									break
						if ok9 and randf() < 0.2 * gr:
							for dy9: int in range(3):
								for dx9: int in range(3):
									var q9b: Dictionary = grid[y + dy9][x + dx9]
									q9b["building"] = "res_3"
									q9b["hgroup"] = {"x0": x, "y0": y, "w": 3, "h": 3}
									q9b["house_variant"] = 10 # 3x3 거상 대저택
									q9b["zone_build"] = 0.0
									register_build_tile(x + dx9, y + dy9)
									ConstructionManager.register_construction_site(Vector2i(x + dx9, y + dy9), 0.0, 0)
							cur_mansion += 1
							continue

					# 3x2 검사
					if x + 2 < size and y + 1 < size and cur_mansion < max_mansion:
						var ok6 := true
						for dy6: int in range(2):
							for dx6: int in range(3):
								var q6: Dictionary = grid[y + dy6][x + dx6]
								if not (q6.get("building", "") in ["res_2", "res_3"]) or int(q6.get("lv", 0)) < 80 or q6.has("zone_build"):
									ok6 = false
									break
						if ok6 and randf() < 0.2 * gr:
							for dy6: int in range(2):
								for dx6: int in range(3):
									var q6b: Dictionary = grid[y + dy6][x + dx6]
									q6b["building"] = "res_3"
									q6b["hgroup"] = {"x0": x, "y0": y, "w": 3, "h": 2}
									q6b["house_variant"] = 9 # 3x2 대부호 별서
									q6b["zone_build"] = 0.0
									register_build_tile(x + dx6, y + dy6)
									ConstructionManager.register_construction_site(Vector2i(x + dx6, y + dy6), 0.0, 0)
							cur_mansion += 1
							continue

			# ---------------------------------------------------------
			# 3. 2x2 부호의 집 (입지 70+, 반경 4칸 이격, 6% 이하)
			# ---------------------------------------------------------
			if cur_tile_2x2 < max_tile_2x2 and lv >= 70 and not _is_near_large_mansion(x, y, 4, 2):
				var sq: Array[Vector2i] = [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1)]
				var ok4 := true
				for q: Vector2i in sq:
					var qt: Dictionary = grid[q.y][q.x]
					if qt.get("building", "") != "res_2" or int(qt.get("lv", 0)) < 70 or qt.has("zone_build"):
						ok4 = false
						break
					if qt.has("hgroup"):
						var hg: Dictionary = qt["hgroup"]
						if int(hg["x0"]) < x or int(hg["y0"]) < y or int(hg["x0"]) + int(hg["w"]) > x + 2 or int(hg["y0"]) + int(hg["h"]) > y + 2:
							ok4 = false
							break
				if ok4 and randf() < 0.3 * gr:
					var v: int = 7 + (randi() % 2) # tile_house_08, 09
					for q: Vector2i in sq:
						var qt2: Dictionary = grid[q.y][q.x]
						qt2["building"] = "res_3"
						qt2["hgroup"] = {"x0": x, "y0": y, "w": 2, "h": 2}
						qt2["house_variant"] = v
						qt2["zone_build"] = 0.0
						register_build_tile(q.x, q.y)
						ConstructionManager.register_construction_site(q, 0.0, 0)
					cur_tile_2x2 += 1
					continue

			# ---------------------------------------------------------
			# 4. 1x2 중규모 여염 기와집 (입지 60+, 12% 이하)
			# ---------------------------------------------------------
			if cur_tile_1x2 < max_tile_1x2 and not t.has("hgroup") and lv >= 60:
				for dd: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
					var nx: int = x + dd.x
					var ny: int = y + dd.y
					if in_bounds(nx, ny):
						var nt: Dictionary = grid[ny][nx]
						if nt.get("building", "") == "res_2" and not nt.has("hgroup") and int(nt.get("lv", 0)) >= 60 and not nt.has("zone_build"):
							if randf() < 0.35 * gr:
								var g := {"x0": x, "y0": y, "w": 2 if dd.x == 1 else 1, "h": 2 if dd.y == 1 else 1}
								var v2: int = 4 + (randi() % 3) # tile_house_05 ~ 07
								for q2: Vector2i in [Vector2i(x, y), Vector2i(nx, ny)]:
									var qt3: Dictionary = grid[q2.y][q2.x]
									qt3["hgroup"] = g
									qt3["house_variant"] = v2
									qt3["zone_build"] = 0.0
									register_build_tile(q2.x, q2.y)
									ConstructionManager.register_construction_site(q2, 0.0, 0)
								cur_tile_1x2 += 1
								break

## 공방 규모별 유기적 합필 (1x1 55%, 2x1 30%, 2x2 12%, 3x3 3% 이하)
func _form_workshop_groups() -> void:
	var stats: Dictionary = _count_workshop_types()
	var total_ws: int = int(stats.get("total", 0))
	if total_ws <= 0:
		return

	var max_3x3: int = int(float(total_ws) * 0.03) # 3% 이하 (공방 25칸당 최대 1곳)
	var max_2x2: int = int(float(total_ws) * 0.12) # 12%
	var max_2x1: int = int(float(total_ws) * 0.30) # 30%
	var cur_3x3: int = int(stats.get("ws_3x3", 0))
	var cur_2x2: int = int(stats.get("ws_2x2", 0))
	var cur_2x1: int = int(stats.get("ws_2x1", 0))

	for y: int in range(size - 1):
		for x: int in range(size - 1):
			var t: Dictionary = grid[y][x]
			if not (t.get("building", "") in ["ind_1", "ind_2"]) or t.has("zone_build"):
				continue

			# 1. 3x3 관영 군기시/화기 주조창 (총 25칸 이상, 반경 12칸 이격)
			if total_ws >= 25 and cur_3x3 < max_3x3 and not _is_near_workshop(x, y, 12, 3):
				if x + 2 < size and y + 2 < size:
					var ok9 := true
					for dy9: int in range(3):
						for dx9: int in range(3):
							var q9: Dictionary = grid[y + dy9][x + dx9]
							if not (q9.get("building", "") in ["ind_1", "ind_2"]) or q9.has("zone_build"):
								ok9 = false
								break
					if ok9 and randf() < 0.2:
						for dy9: int in range(3):
							for dx9: int in range(3):
								var q9b: Dictionary = grid[y + dy9][x + dx9]
								q9b["building"] = "ind_2"
								q9b["ws_group"] = {"x0": x, "y0": y, "w": 3, "h": 3}
								q9b["ws_asset_id"] = "ws_3x3_royal_arsenal"
						cur_3x3 += 1
						continue

			# 2. 2x2 대형 가마/목재소 (반경 5칸 이격)
			if cur_2x2 < max_2x2 and not _is_near_workshop(x, y, 5, 2):
				var sq: Array[Vector2i] = [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1)]
				var ok4 := true
				for q: Vector2i in sq:
					var qt: Dictionary = grid[q.y][q.x]
					if not (qt.get("building", "") in ["ind_1", "ind_2"]) or qt.has("zone_build"):
						ok4 = false
						break
				if ok4 and randf() < 0.3:
					var ws_large_keys: Array[String] = ["ws_2x2_ceramics", "ws_2x2_lumber_machinery"]
					var chosen_key: String = ws_large_keys[randi() % ws_large_keys.size()]
					for q: Vector2i in sq:
						var qt2: Dictionary = grid[q.y][q.x]
						qt2["building"] = "ind_2"
						qt2["ws_group"] = {"x0": x, "y0": y, "w": 2, "h": 2}
						qt2["ws_asset_id"] = chosen_key
					cur_2x2 += 1
					continue

			# 3. 2x1 중형 공방
			if cur_2x1 < max_2x1 and not t.has("ws_group"):
				for dd: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
					var nx: int = x + dd.x
					var ny: int = y + dd.y
					if in_bounds(nx, ny):
						var nt: Dictionary = grid[ny][nx]
						if (nt.get("building", "") in ["ind_1", "ind_2"]) and not nt.has("ws_group") and not nt.has("zone_build"):
							if randf() < 0.35:
								var ws_mid_keys: Array[String] = ["ws_2x1_blacksmith", "ws_2x1_dyeing", "ws_2x1_stonemason", "ws_2x1_tile_kiln", "ws_2x1_shoemaker"]
								var chosen_m: String = ws_mid_keys[randi() % ws_mid_keys.size()]
								var g_ws := {"x0": x, "y0": y, "w": 2 if dd.x == 1 else 1, "h": 2 if dd.y == 1 else 1}
								for q2: Vector2i in [Vector2i(x, y), Vector2i(nx, ny)]:
									var qt3: Dictionary = grid[q2.y][q2.x]
									qt3["ws_group"] = g_ws
									qt3["ws_asset_id"] = chosen_m
								cur_2x1 += 1
								break

## 그룹 민가 하나가 헐리면 나머지 칸은 단독 기와집으로 돌아간다.
func _dissolve_house_group(t: Dictionary) -> void:
	if not t.has("hgroup"):
		return
	var g: Dictionary = t["hgroup"]
	for yy: int in range(int(g["y0"]), int(g["y0"]) + int(g["h"])):
		for xx: int in range(int(g["x0"]), int(g["x0"]) + int(g["w"])):
			if not in_bounds(xx, yy):
				continue
			var gt: Dictionary = grid[yy][xx]
			gt.erase("hgroup")
			gt.erase("house_variant")
			if gt["building"] == "res_3":
				gt["building"] = "res_2"

func count_zone_buildings() -> Dictionary:
	var r := 0
	var c := 0
	var a := 0
	var i_n := 0
	for row in grid:
		for t in row:
			var b: String = t["building"]
			if b.begins_with("res"): r += 3 if b == "res_3" else (2 if b == "res_2" else 1)
			if b.begins_with("com"): c += 2 if b == "com_2" else 1
			if b.begins_with("agr"): a += 2 if b == "agr_2" else 1
			if b.begins_with("ind"): i_n += 2 if b == "ind_2" else 1
	return {"res": r, "com": c, "agr": a, "ind": i_n}

## PORT-TRACE [제방 연속화]: 사용자 지적 — "제방 공사가 띄엄띄엄 형식적으로 만들어지고 말만
## 공사가 끝났다고 되어 있다. 강을 따라 제방이 쌓여야 든든하다". 원인은 suwon_levee 대역사의
## 대상이 수원천 양안에 8칸만 드문드문 박힌 고정 좌표였던 것. 이제 실제 물길(terrain "water")에
## 닿은 모든 빈 땅(8방향 이웃 — 굽이진 곳도 끊기지 않게)을 대상으로 삼아, 완공하면 강줄기를
## 따라 끊김 없는 석축 제방이 선다. 지형 붓으로 하천을 바꿔도 게임 시작 시점의 물길을 따른다.
## PORT-TRACE [제방 빨래터·낚시터]: 사용자 요청 — "제방을 쌓으면 낚시꾼과 빨래 아낙이 물가에 갈 수 없다.
## 낚시는 제방 위에서도 할 수 있고, 제방 너머 빨래터가 생길 수 있어야 한다"(1900년대 수원천 제방 아래
## 빨래터 사진 참고). 물과 맞닿은 제방 칸 가운데 일정 간격(좌표 해시로 약 5칸에 1곳)을 빨래터로 삼아,
## 그림(CityLayer: 돌계단 + 넓적한 빨래돌)과 빨래 아낙 배치(CitizenManager)가 같은 자리를 쓴다.
func water_dir_at(x: int, y: int) -> Vector2i:
	var v := Vector2i.ZERO
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if in_bounds(x + d.x, y + d.y) and grid[y + d.y][x + d.x]["terrain"] == "water":
			v += d
	return v

func is_laundry_spot(x: int, y: int) -> bool:
	if not in_bounds(x, y) or grid[y][x]["building"] != "levee" or grid[y][x].has("wall_build"):
		return false
	if water_dir_at(x, y) == Vector2i.ZERO:
		return false
	return (x * 7 + y * 13) % 5 == 0

func river_levee_targets() -> Array:
	var out: Array = []
	for y in range(size):
		for x in range(size):
			var t: Dictionary = grid[y][x]
			if t["terrain"] == "water" or t["terrain"] == "mountain":
				continue
			if t["building"] != "" or t["zone"] != "":
				continue
			var near_water := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if (dx != 0 or dy != 0) and in_bounds(x + dx, y + dy) and grid[y + dy][x + dx]["terrain"] == "water":
						near_water = true
			if near_water:
				out.append({"x": x, "y": y, "building": "levee"})
	return out

## 국책 대역사 대상 타일 공사 플래그 / 완공 배치
## PORT-TRACE [국책 대역사 행궁 7x7]: 대역사 목표에 행궁 한 칸만 적혀 있으면 지도에는 한 칸짜리 바닥만 생겼다.
## 행궁은 부지 건물(7x7)이므로 목표 한 칸(가운데)을 부지 전체로 풀어, 착공 땐 7x7 비계를, 완공 땐 신풍루·봉수당 등 복합 궁궐을 세운다.
func _expand_site_targets(targets: Array) -> Array:
	var out: Array = []
	for pt in targets:
		if String(pt.get("building", "")) == "haenggung" and not pt.has("anchor"):
			var info: Dictionary = SITE_BUILDINGS["haenggung"]
			var a := Vector2i(int(pt["x"]), int(pt["y"]))
			for q: Vector2i in get_site_footprint(a.x, a.y, int(info["w"]), int(info["h"])):
				out.append({"x": q.x, "y": q.y, "building": "haenggung" if q == a else "haenggung_site", "anchor": a})
		else:
			out.append(pt)
	return out

## 서장대·봉돈·공심돈·연무대·포루처럼 여러 칸이 한 건물인 군사 시설 칸인가(성벽을 덧쌓거나 덮어쓰면 건물이 사라진다)
func _is_structure_tile(t: Dictionary) -> bool:
	return t.has("sj2") or t.has("bd4") or t.has("gs3") or t.has("ym5") or t.has("pr2") \
		or String(t.get("building", "")) in ["banghwasuryu", "yongyeon", "yeonmudae_range"]

## target 근처에서 validate_site가 통과하는 가장 가까운 부지 가운데 칸(없으면 (-1,-1))
func find_valid_site_near(building: String, target: Vector2i, max_r: int = 24) -> Vector2i:
	for r in range(0, max_r):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var x := target.x + dx
				var y := target.y + dy
				if in_bounds(x, y) and validate_site(building, x, y) == "":
					return Vector2i(x, y)
	return Vector2i(-1, -1)

## 서장대(2x2)는 칸마다 sj2 표시를 갖는다. 예전에 성벽 도구가 그 칸을 "wall"로 덮어써 건물이 사라진 경우를 되살린다.
## PORT-TRACE [포루 1x2·공심돈 2x2]: 예전 세이브의 포루(성벽 2+바깥 2)·공심돈(성벽 3+안 3+바깥 3)을 새 크기로 —
## 남길 칸만 두고 나머지 성벽 칸은 성벽으로, 안·바깥 칸은 빈 땅으로 돌린다.
func shrink_legacy_forts() -> void:
	var done := {}
	for y in range(size):
		for x in range(size):
			var t: Dictionary = grid[y][x]
			var b := String(t.get("building", ""))
			if t.has("pr2") and b in ["poru", "poru_site"]:
				var info: Dictionary = t["pr2"]
				var a: Vector2i = t.get("site_anchor", Vector2i(x, y))
				if done.has(a):
					continue
				done[a] = true
				var keep_w: Vector2i = info["start"]
				var keep_o: Vector2i = keep_w + (info["out"] as Vector2i)
				var tiles: Array = grid[a.y][a.x].get("site_tiles", [])
				for q in tiles:
					var qq := Vector2i(q)
					if qq != keep_w and qq != keep_o and in_bounds(qq.x, qq.y):
						_revert_fort_tile(qq)
				info["len"] = 1
				for kq: Vector2i in [keep_w, keep_o]:
					if in_bounds(kq.x, kq.y) and grid[kq.y][kq.x].has("pr2"):
						(grid[kq.y][kq.x]["pr2"] as Dictionary)["len"] = 1 # 세이브에서 읽으면 칸마다 따로 된 사전
				grid[keep_w.y][keep_w.x]["site_tiles"] = [keep_w, keep_o]
			elif t.has("gs3") and b in ["gongsimdon", "gongsimdon_wall", "gongsimdon_site"]:
				var gi: Dictionary = t["gs3"]
				var c: Vector2i = gi["center"]
				if done.has(c):
					continue
				done[c] = true
				var ax: Vector2i = (gi["axis"] as Vector2i) * int(gi.get("c2", 1)) # 새로 지은 것(c2 있음)은 그 방향 그대로 — 여러 번 돌아도 같음
				var od: Vector2i = gi["out"]
				var keep: Array = [c, c + ax, c + od, c + ax + od]
				var tiles2: Array = grid[c.y][c.x].get("site_tiles", [])
				for q2 in tiles2:
					var qq2 := Vector2i(q2)
					if not (qq2 in keep) and in_bounds(qq2.x, qq2.y):
						_revert_fort_tile(qq2)
				var c2v := int(gi.get("c2", 1))
				gi["c2"] = c2v
				for kq2 in keep:
					var kk := Vector2i(kq2)
					if in_bounds(kk.x, kk.y) and grid[kk.y][kk.x].has("gs3"):
						(grid[kk.y][kk.x]["gs3"] as Dictionary)["c2"] = c2v
				grid[c.y][c.x]["site_tiles"] = keep
				var cw := c + ax
				if in_bounds(cw.x, cw.y):
					grid[cw.y][cw.x]["building"] = "gongsimdon_wall"

func _revert_fort_tile(q: Vector2i) -> void:
	var gt: Dictionary = grid[q.y][q.x]
	var b := String(gt.get("building", ""))
	gt["building"] = "wall" if b in ["poru", "gongsimdon", "gongsimdon_wall"] else ""
	gt["zone"] = ""
	for k: String in ["pr2", "gs3", "site_anchor", "site_tiles", "wall_build", "wall_build_total", "bp_ticks", "bp_total"]:
		gt.erase(k)

## PORT-TRACE [방화수류정 1x1]: 예전 세이브의 2x2 방화수류정을 1칸으로 — 용연 가운데에 가장 가까운 칸만 남기고,
## 나머지 칸은 성벽 위였으면 성벽으로, 아니면 빈 땅으로 돌린다. 용연 칸들의 기준 칸·부지 목록도 새로.
func shrink_legacy_banghwa() -> void:
	var done := {}
	for y in range(size):
		for x in range(size):
			var t: Dictionary = grid[y][x]
			if String(t.get("building", "")) != "banghwasuryu":
				continue
			var anchor: Vector2i = t.get("site_anchor", Vector2i(x, y))
			if done.has(anchor):
				continue
			done[anchor] = true
			var tiles: Array = t.get("site_tiles", [])
			var bh: Array[Vector2i] = []
			var yong: Array[Vector2i] = []
			for pt in tiles:
				var q := Vector2i(pt)
				if not in_bounds(q.x, q.y):
					continue
				var b := String(grid[q.y][q.x].get("building", ""))
				if b == "banghwasuryu":
					bh.append(q)
				elif b == "yongyeon":
					yong.append(q)
			if bh.size() <= 1:
				continue
			var pc := Vector2.ZERO
			for q2: Vector2i in yong:
				pc += Vector2(q2)
			pc = pc / float(maxi(1, yong.size())) if not yong.is_empty() else Vector2(anchor)
			# 성벽 줄 위였던 칸(bh_wall) 중에서 용연에 가장 가까운 칸 — 성곽에서 곁가지로 튀어나오지 않게
			var cands: Array[Vector2i] = []
			for q6: Vector2i in bh:
				if bool(grid[q6.y][q6.x].get("bh_wall", false)):
					cands.append(q6)
			if cands.is_empty():
				cands = bh
			var keep: Vector2i = cands[0]
			for q3: Vector2i in cands:
				if Vector2(q3).distance_to(pc) < Vector2(keep).distance_to(pc):
					keep = q3
			var all_t: Array = [keep]
			all_t.append_array(yong)
			for q4: Vector2i in bh:
				var gt: Dictionary = grid[q4.y][q4.x]
				if q4 == keep:
					gt["site_anchor"] = keep
					gt["site_tiles"] = all_t
					continue
				gt["building"] = "wall" if bool(gt.get("bh_wall", false)) else ""
				gt["zone"] = ""
				gt.erase("site_tiles")
				gt.erase("site_anchor")
				for k: String in ["bh_wall", "wall_build", "wall_build_total", "bp_ticks", "bp_total"]:
					gt.erase(k)
			for q5: Vector2i in yong:
				grid[q5.y][q5.x]["site_anchor"] = keep
				grid[q5.y][q5.x]["site_tiles"] = all_t

func heal_structure_overwrites() -> void:
	var changed := false
	for y in range(size):
		for x in range(size):
			var t: Dictionary = grid[y][x]
			if not t.has("sj2"):
				continue
			var anc: Vector2i = t.get("site_anchor", Vector2i(x, y))
			var want := "seojangdae" if anc == Vector2i(x, y) else "seojangdae_site"
			if String(t["building"]) != want:
				t["building"] = want
				t["under_construction"] = false
				changed = true
	if changed:
		emit_signal("grid_changed")

func set_construction(targets: Array, on: bool) -> void:
	targets = _expand_site_targets(targets)
	for pt in targets:
		if in_bounds(pt["x"], pt["y"]):
			var t: Dictionary = grid[pt["y"]][pt["x"]]
			var cur_b: String = str(t.get("building", ""))
			if pt["building"] == "wall" and _is_structure_tile(t):
				continue
			# 이미 유효한 건물(목표 건물과 일치하거나 성벽 상위 방어시설 등)이 완공되어 있다면 비계 덮어쓰기 방지
			if on and cur_b != "" and cur_b != "wall_build" and not bool(t.get("under_construction", false)):
				if cur_b == pt["building"] or (pt["building"] == "wall" and (cur_b in ["poru", "gongsimdon", "chiseong", "ammun", "gate", "hwahong", "namsu", "seojangdae"])):
					continue
			t["under_construction"] = on
	emit_signal("grid_changed")

func complete_targets(targets: Array) -> void:
	targets = _expand_site_targets(targets)
	for pt in targets:
		if in_bounds(pt["x"], pt["y"]):
			var t: Dictionary = grid[pt["y"]][pt["x"]]
			var cur_b: String = str(t.get("building", ""))
			var is_under: bool = bool(t.get("under_construction", false))
			# 서장대 등 다칸 군사 시설 칸은 성벽으로 덮어쓰지 않는다(서장대 2x2의 (1,1)칸이 성벽이 되면 건물이 안 보인다)
			if pt["building"] == "wall" and _is_structure_tile(t):
				t["under_construction"] = false
				continue

			# 타일에 이미 완공된 주요 건물이 있는 경우: 기존 시설 보존하고 비계만 해제
			if cur_b != "" and cur_b != "wall_build" and not is_under:
				if cur_b == pt["building"]:
					t["under_construction"] = false
					continue
				if pt["building"] == "wall" and (cur_b in ["poru", "gongsimdon", "chiseong", "ammun", "gate", "hwahong", "namsu", "seojangdae"]):
					t["under_construction"] = false
					continue

			t["building"] = pt["building"]
			t["under_construction"] = false
			t["zone"] = ""
			if pt.has("anchor"):
				# 행궁 7x7: 칸마다 부지 가운데 칸을 가리키고, 가운데 칸은 부지 전체 목록을 갖는다(터 축조와 같은 모양)
				t["site_anchor"] = pt["anchor"]
				if pt["building"] == "haenggung":
					var hinfo: Dictionary = SITE_BUILDINGS["haenggung"]
					t["site_tiles"] = get_site_footprint(int(pt["anchor"].x), int(pt["anchor"].y), int(hinfo["w"]), int(hinfo["h"]))
			if pt["building"] == "gate" and not t.has("gate_name"):
				# 서쪽 성문(6,13)은 y가 작아도 화서문이다(예전엔 y<15면 무조건 장안문이라, 서성곽 완공이 장안문 완공으로 오인돼 북성곽·화홍문이 줄줄이 자동 완공됐다)
				t["gate_name"] = "화서문 (華西門)" if int(pt["x"]) < 15 else ("장안문 (長安門)" if int(pt["y"]) < 15 else ("팔달문 (八達門)" if int(pt["y"]) > 45 else ("화서문 (華西門)" if int(pt["x"]) < 20 else "창룡문 (蒼龍門)")))
	recompute_infrastructure()
	emit_signal("grid_changed")

## 팔달문(남문, 현판 이름 또는 남쪽 방향) 10칸 안에 칠한 저잣거리 칸 가운데 3x3 수원 쇠전(우시장)을 한 곳만 잡는다
func allocate_cattle_market(tiles: Array[Vector2i]) -> bool:
	return _allocate_gate_yard(tiles, "paldal", "cattle")

## PORT-TRACE [화서문 어염시장]: 화서문 10칸 안 저잣거리에 2x2 염전 소금 창고(plaza kind "salt")를 한 곳만 확정
func allocate_salt_store(tiles: Array[Vector2i]) -> bool:
	return _allocate_gate_yard(tiles, "hwaseo", "salt")

## gate_kind 성문 10칸 안에 칠한 칸 가운데 특화 부지(plaza_kind, 크기는 allocate_plazas가 정함)를 도시에 한 곳만 잡는다
func _allocate_gate_yard(tiles: Array[Vector2i], gate_kind: String, plaza_kind: String) -> bool:
	if not list_plazas(plaza_kind).is_empty():
		return false
	logistics.mark_dirty()
	logistics.refresh()
	var gate_list: Array[Vector2i] = []
	for r: Dictionary in logistics.routes:
		if r["kind"] == gate_kind:
			gate_list.append(r["gate"])
	if gate_list.is_empty():
		var four_gates: Dictionary = get_four_gates_positions()
		if four_gates.has(gate_kind):
			var fg: Vector2i = four_gates[gate_kind]
			if fg.x >= 0 and in_bounds(fg.x, fg.y):
				gate_list.append(fg)
	if gate_list.is_empty():
		return false
	var near: Array = []
	for p: Vector2i in tiles:
		for g: Vector2i in gate_list:
			if absi(p.x - g.x) + absi(p.y - g.y) <= 10:
				near.append(p)
				break
	if near.is_empty():
		return false
	return allocate_plazas(tiles, plaza_kind, near) > 0

# ---------------------------------------------------------------- 종루(여민각)
## PORT-TRACE [종루(여민각) 2x2]: 사용자 요청 — "행궁 신풍루 정면에서 뻗은 박석길(10칸 안)이 동서(남북) 길과 만나는
## 사거리가 완성되는 순간 그 모퉁이에 2x2 종루(여민각)를 자동 착공". 신풍루는 행궁(7x7, 앵커=중심) 동쪽 가운데
## (앵커+(3,0))라 정면 길은 앵커+(4,0)부터 +x로 뻗는다. 그 길이 끊기지 않고 박석길인 동안만 따라가며, 남·북·동 세 방향이
## 모두 길(흙길 포함)인 첫 칸을 십자로로 본다. 모퉁이 네 곳 중 비어 있는(평지·건물 없음·공터 아님) 2x2를 고른다.
var jongnu_pos := Vector2i(-1, -1) # 완공된 종루 앵커(턴 계산 때 갱신)

func find_building_anchor(b: String) -> Vector2i:
	for y in range(size):
		for x in range(size):
			if grid[y][x]["building"] == b:
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func has_jongnu() -> bool:
	for s in active_sites:
		if s["building"] == "jongnu":
			return true
	return find_building_anchor("jongnu").x >= 0

## 지을 자리(2x2 앵커) 또는 (-1,-1)
func find_jongnu_site() -> Vector2i:
	var hg := find_building_anchor("haenggung")
	if hg.x < 0:
		return Vector2i(-1, -1)
	for i in range(4, 14):
		var p := hg + Vector2i(i, 0)
		if not is_stone_road(p.x, p.y):
			return Vector2i(-1, -1)
		var cross := building_at(p.x, p.y - 1) == "road" and building_at(p.x, p.y + 1) == "road" and building_at(p.x + 1, p.y) == "road"
		if not cross:
			continue
		for c: Vector2i in [Vector2i(p.x + 1, p.y + 1), Vector2i(p.x + 1, p.y - 2), Vector2i(p.x - 2, p.y + 1), Vector2i(p.x - 2, p.y - 2)]:
			var ok := true
			for dy in range(2):
				for dx in range(2):
					var q := c + Vector2i(dx, dy)
					if not in_bounds(q.x, q.y):
						ok = false
						continue
					var t: Dictionary = grid[q.y][q.x]
					if t["terrain"] != "plain" or t["building"] != "" or t.has("plaza") or t["under_construction"]:
						ok = false
			if ok:
				return c
		return Vector2i(-1, -1) # 십자로는 열렸지만 네 모퉁이가 다 차 있음 — 나중에 비면 다시
	return Vector2i(-1, -1)

## 조건이 맞으면 무료로 착공하고 true
func try_start_jongnu(sim: SimulationCore) -> bool:
	if has_jongnu():
		return false
	var c := find_jongnu_site()
	if c.x < 0:
		return false
	for dy in range(2):
		for dx in range(2):
			grid[c.y + dy][c.x + dx]["zone"] = ""
	return bool(start_site_construction("jongnu", c.x, c.y, sim).get("success", false))

# ---------------------------------------------------------------- 남수문(南水門)
## PORT-TRACE [남수문]: 사용자 요청 — "수원천 남쪽 끝에서 동·서 성곽이 하천을 가로질러 이어지는 순간 남수문을 자동 축조".
## 물 위 성곽 구간(가로 또는 세로로 연속된 물 위 wall 칸)이 지도 남쪽 절반에 있고, 양 끝 바로 바깥이 땅 위 성곽 연결체
## (성곽·성문·포루 등)면 그 구간 전체를 남수문으로 바꾸고(is_namsu, 화홍문 도구로 지은 칸은 제외) 2턴짜리 축조를 다시 건다.
## 완공되면 다리처럼 순라군이 건너다니고(is_bridge), 치수 방재율 +30, 성곽 완공률 가중, 주변 치안 거점.
var namsu_complete := false
var hwahong_complete := false

func _near_namsu(x: int, y: int) -> bool:
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			if in_bounds(x + dx, y + dy):
				var t: Dictionary = grid[y + dy][x + dx]
				if t.get("is_namsu", false) and not t.has("wall_build"):
					return true
	return false

func _is_water_wall_tile(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return false
	var t: Dictionary = grid[y][x]
	return t["building"] == "wall" and t["terrain"] == "water" and not t.get("is_hwahong", false)

## 새로 남수문이 된 구간의 칸 목록(없으면 빈 배열)
func detect_namsu() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(int(float(size) / 2.0), size):
		for x in range(size):
			if not _is_water_wall_tile(x, y) or grid[y][x].get("is_namsu", false):
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				if _is_water_wall_tile(x - d.x, y - d.y):
					continue # 구간의 시작 칸에서만 검사
				var span: Array[Vector2i] = []
				var p := Vector2i(x, y)
				while _is_water_wall_tile(p.x, p.y):
					span.append(p)
					p += d
				if span.size() < 2:
					continue
				var before := Vector2i(x, y) - d
				if not (is_wall_connector(before.x, before.y) and grid[before.y][before.x]["terrain"] != "water"):
					continue
				if not (is_wall_connector(p.x, p.y) and grid[p.y][p.x]["terrain"] != "water"):
					continue
				for q: Vector2i in span:
					var t: Dictionary = grid[q.y][q.x]
					t["is_namsu"] = true
					t["is_bridge"] = true
					t["site_anchor"] = span[0]
					t["wall_build"] = 2
					t["wall_build_total"] = 2
					t["bp_ticks"] = 0
					t["bp_total"] = _ticks_until_boundaries(2)
					WaterStructureManager.bind_structure_metadata(t, WaterStructureManager.FACILITY_NAMSU, WaterStructureManager.NAME_NAMSU)
					register_build_tile(q.x, q.y)
					out.append(q)
	if not out.is_empty():
		emit_signal("grid_changed")
	return out

## 새로 화홍문이 된 구간의 칸 목록(없으면 빈 배열)
func detect_hwahong() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var half_y: int = int(float(size) / 2.0)
	for y in range(half_y):
		for x in range(size):
			if not _is_water_wall_tile(x, y) or grid[y][x].get("is_hwahong", false):
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				if _is_water_wall_tile(x - d.x, y - d.y):
					continue
				var span: Array[Vector2i] = []
				var p := Vector2i(x, y)
				while _is_water_wall_tile(p.x, p.y) and p.y < half_y:
					span.append(p)
					p += d
				if span.size() < 2:
					continue
				var before := Vector2i(x, y) - d
				if not (is_wall_connector(before.x, before.y) and grid[before.y][before.x]["terrain"] != "water"):
					continue
				if not (is_wall_connector(p.x, p.y) and grid[p.y][p.x]["terrain"] != "water"):
					continue
				for q: Vector2i in span:
					var t: Dictionary = grid[q.y][q.x]
					t["is_hwahong"] = true
					t["is_bridge"] = true
					t["site_anchor"] = span[0]
					WaterStructureManager.bind_structure_metadata(t, WaterStructureManager.FACILITY_HWAHONG, WaterStructureManager.NAME_HWAHONG)
					out.append(q)
	if not out.is_empty():
		emit_signal("grid_changed")
	return out

func on_wall_cross_river(x: int, y: int) -> Dictionary:
	return WaterStructureManager.on_wall_cross_river(self, x, y)

func on_bridge_built(x: int, y: int) -> Dictionary:
	return WaterStructureManager.on_bridge_built(self, x, y)

# ---------------------------------------------------------------- 매향교(梅香橋)
## PORT-TRACE [매향교]: 사용자 요청 — "신풍루-종로 십자로-창룡문을 잇는 동서 큰길이 수원천을 건너면 화강암 석교 매향교를
## 자동 가설". 행궁(앵커=중심) 동쪽, 행궁 정면 길 줄(앵커 y) 위아래 2줄 안에서 물 위 길(다리) 구간을 찾고, 양 끝 바로
## 바깥이 땅 위 길이면 그 구간을 매향교(is_maehyang)로 바꾼다(가장 정면 줄에 가까운 한 구간, 도시에 하나).
## 다리목 양쪽 천변 빈 땅에 매화나무(t["plum"])를 심는다. 그림은 CityLayer, 이동·상권 효과는 CitizenManager·develop.
var maehyang_pos := Vector2i(-1, -1)

func _find_maehyang() -> Vector2i:
	for y in range(size):
		for x in range(size):
			if grid[y][x].get("is_maehyang", false) and grid[y][x]["building"] == "road": # 다리를 헐면 다시 놓을 수 있게
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _is_water_road(x: int, y: int) -> bool:
	return in_bounds(x, y) and grid[y][x]["building"] == "road" and grid[y][x]["terrain"] == "water"

func _is_land_road(x: int, y: int) -> bool:
	return in_bounds(x, y) and grid[y][x]["building"] == "road" and grid[y][x]["terrain"] != "water"

## 새로 매향교가 된 칸 목록(없으면 빈 배열)
func detect_maehyang() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if _find_maehyang().x >= 0:
		return out
	var hg := find_building_anchor("haenggung")
	if hg.x < 0:
		return out
	var best: Array[Vector2i] = []
	var best_d := 99
	for y in range(hg.y - 2, hg.y + 3):
		var x := hg.x + 4
		while x < size:
			if _is_water_road(x, y) and not _is_water_road(x - 1, y):
				var span: Array[Vector2i] = []
				var p := x
				while _is_water_road(p, y):
					span.append(Vector2i(p, y))
					p += 1
				if _is_land_road(x - 1, y) and _is_land_road(p, y) and absi(y - hg.y) < best_d:
					best = span
					best_d = absi(y - hg.y)
				x = p
			else:
				x += 1
	if best.is_empty():
		return out
	for q: Vector2i in best:
		grid[q.y][q.x]["is_maehyang"] = true
		grid[q.y][q.x]["road_type"] = "stone"
		grid[q.y][q.x]["is_bridge"] = true
		WaterStructureManager.bind_structure_metadata(grid[q.y][q.x], WaterStructureManager.FACILITY_MAEHWANG, WaterStructureManager.NAME_MAEHWANG)
		out.append(q)
	# 다리목 양쪽 천변 빈 땅에 매화나무(최대 6그루)
	var planted := 0
	var ends: Array[Vector2i] = [best[0] - Vector2i(1, 0), best[best.size() - 1] + Vector2i(1, 0)]
	for e: Vector2i in ends:
		for dy: int in [-1, 1, -2, 2]:
			for dx: int in [0, -1, 1]:
				if planted >= 6:
					break
				var q2 := e + Vector2i(dx, dy)
				if not in_bounds(q2.x, q2.y):
					continue
				var t2: Dictionary = grid[q2.y][q2.x]
				if t2["terrain"] == "plain" and t2["building"] == "" and t2["zone"] == "" and not t2.has("plaza"):
					t2["plum"] = true
					planted += 1
	emit_signal("grid_changed")
	return out

# ---------------------------------------------------------------- 봉돈 4x1 · 서장대 2x2
## PORT-TRACE [봉돈 4x1]: 클릭한 완공 성벽 칸을 포함해 한 줄로 이어진 완공 성벽 4칸(가능하면 클릭 칸이 가운데)을 고르고,
## 그 바깥(성 밖 "outside"가 더 많은 쪽) 4칸이 비어 있으면 돌출부로 쓴다. 반환 {wall, out, axis, out_dir, err}
func _is_done_wall(x: int, y: int) -> bool:
	return in_bounds(x, y) and grid[y][x]["building"] == "wall" and not grid[y][x].has("wall_build") and grid[y][x]["terrain"] != "water" and not grid[y][x].get("is_hwahong", false)

func get_bongdon_tiles(x: int, y: int) -> Dictionary:
	var res := {"wall": [], "out": [], "axis": Vector2i(1, 0), "out_dir": Vector2i(0, 1), "err": ""}
	if count_completed("wall") == 0:
		res["err"] = "봉돈은 성곽이 완공된 이후에만 축조할 수 있습니다. 성곽을 먼저 쌓아 주십시오."
		return res
	if not _is_done_wall(x, y):
		res["err"] = "봉돈은 이미 완공된 성벽 위에 덧씌워 짓습니다. 성벽을 누르십시오."
		return res
	var d := Vector2i(1, 0) if (_is_done_wall(x - 1, y) or _is_done_wall(x + 1, y)) else Vector2i(0, 1)
	var best_start := Vector2i(-99, -99)
	for off: int in [1, 2, 0, 3]:
		var s := Vector2i(x, y) - d * off
		var ok := true
		for k in range(4):
			if not _is_done_wall(s.x + d.x * k, s.y + d.y * k):
				ok = false
		if ok:
			best_start = s
			break
	if best_start.x == -99:
		res["err"] = "봉돈(4x1)은 곧게 이어진 완공 성벽 4칸이 필요합니다."
		return res
	var perp := Vector2i(d.y, d.x)
	var score := {perp: 0, -perp: 0}
	for k in range(4):
		var w := best_start + d * k
		for side: Vector2i in [perp, -perp]:
			var q := w + side
			if in_bounds(q.x, q.y) and grid[q.y][q.x]["terrain"] == "outside":
				score[side] = int(score[side]) + 1
	var out_dir: Vector2i = perp if int(score[perp]) >= int(score[-perp]) else -perp
	var walls: Array[Vector2i] = []
	var outs: Array[Vector2i] = []
	for k in range(4):
		var w2 := best_start + d * k
		var o2 := w2 + out_dir
		if not in_bounds(o2.x, o2.y):
			res["err"] = "봉돈 돌출부가 지도 밖으로 벗어납니다."
			return res
		var ot: Dictionary = grid[o2.y][o2.x]
		if ot["building"] != "" or ot["zone"] != "" or ot["terrain"] == "water" or ot["under_construction"]:
			res["err"] = "봉돈이 성 밖으로 돌출할 자리(성벽 바깥 4칸)가 비어 있어야 합니다."
			return res
		walls.append(w2)
		outs.append(o2)
	res["wall"] = walls
	res["out"] = outs
	res["axis"] = d
	res["out_dir"] = out_dir
	return res

## PORT-TRACE [서장대 2x2]: 클릭한 칸이 왼쪽 위인 2x2, 네 칸 모두 산지(팔달산)·빈 땅. 반환 {tiles, err}
func get_seojangdae_tiles(x: int, y: int) -> Dictionary:
	var tiles: Array[Vector2i] = []
	for dy in range(2):
		for dx in range(2):
			var q := Vector2i(x + dx, y + dy)
			if not in_bounds(q.x, q.y):
				return {"tiles": tiles, "err": "서장대(2x2) 부지가 지도 밖으로 벗어납니다."}
			var t: Dictionary = grid[q.y][q.x]
			if t["terrain"] != "mountain":
				return {"tiles": tiles, "err": "서장대(2x2)는 팔달산 정상 바위(산지) 네 칸 위에만 축조할 수 있습니다."}
			# PORT-TRACE [서장대는 성곽 위에]: 산정 빈 땅뿐 아니라 이미 완공된 성벽 위에도 세울 수 있다(성벽 위 누각 — 실제 서장대도 성곽 위에 있다)
			var on_wall: bool = t["building"] == "wall" and not t.has("wall_build") and not bool(t.get("is_hwahong", false)) and not bool(t.get("is_bridge", false)) and not bool(t["under_construction"])
			if not on_wall and (t["building"] != "" or t["zone"] != "" or t["under_construction"]):
				return {"tiles": tiles, "err": "서장대(2x2) 부지 안에 이미 다른 시설이 있습니다."}
			tiles.append(q)
	return {"tiles": tiles, "err": ""}

# ---------------------------------------------------------------- 공심돈 3x3 · 연무대 5x5
## PORT-TRACE [공심돈 3x3]: 클릭한 완공 성벽 칸이 가운데. 성벽 방향으로 양옆 완공 성벽 각 1칸(성벽 3칸), 그 안쪽 3칸·바깥 3칸이
## 비어 있어야 한다. 종류는 위치로 자동(사용자 결정): 가장 가까운 개통/완공 성문이 창룡문·장안문(동북) → 동북공심돈(소라각),
## 화서문(서북) → 서북공심돈, 팔달문(남) → 남공심돈. 성문이 없으면 지도 중심에서 본 방향(남쪽 절반=남, 서쪽=서북, 그 밖=동북).
## PORT-TRACE [공심돈 2x2]: 사용자 요청 — "공심돈은 4대문보다 커서 부자연스럽다, 2x2로". 완공 성벽 칸을 클릭 →
## 그 칸과 성벽을 따라 이웃한 완공 성벽 한 칸 + 둘의 성 밖 쪽 두 칸(성 안쪽 칸은 쓰지 않음). 몸통은 성벽에 걸쳐 바깥으로 불룩.
func get_gongsimdon_tiles(x: int, y: int) -> Dictionary:
	var res := {"wall": [], "in": [], "out": [], "axis": Vector2i(1, 0), "out_dir": Vector2i(0, 1), "type": "dongbuk", "err": "", "pair": 1}
	if not _is_done_wall(x, y):
		res["err"] = "공심돈(2x2)은 완공된 성벽 칸을 눌러 짓습니다."
		return res
	for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		for sg: int in [1, -1]:
			var w2 := Vector2i(x, y) + d * sg
			if not _is_done_wall(w2.x, w2.y):
				continue
			var perp := Vector2i(d.y, d.x)
			var dirs: Array[Vector2i] = []
			var sc := 0
			for w: Vector2i in [Vector2i(x, y), w2]:
				var q := w + perp
				if in_bounds(q.x, q.y) and grid[q.y][q.x]["terrain"] == "outside":
					sc += 1
				var q3 := w - perp
				if in_bounds(q3.x, q3.y) and grid[q3.y][q3.x]["terrain"] == "outside":
					sc -= 1
			if sc > 0:
				dirs = [perp]
			elif sc < 0:
				dirs = [-perp]
			else:
				var cvec := Vector2(float(x), float(y)) - Vector2(float(size), float(size)) * 0.5
				dirs = [perp if cvec.dot(Vector2(perp)) >= 0.0 else -perp]
			for out_dir: Vector2i in dirs:
				var outs: Array[Vector2i] = []
				var ok := true
				for w3: Vector2i in [Vector2i(x, y), w2]:
					var q2 := w3 + out_dir
					if not in_bounds(q2.x, q2.y):
						ok = false
						break
					var t2: Dictionary = grid[q2.y][q2.x]
					if t2["building"] != "" or t2["zone"] != "" or t2["terrain"] == "water" or t2["under_construction"]:
						ok = false
						break
					outs.append(q2)
				if not ok:
					continue
				res["wall"] = [Vector2i(x, y), w2]
				res["out"] = outs
				res["axis"] = d
				res["out_dir"] = out_dir
				res["pair"] = sg
				res["type"] = _gongsimdon_type(x, y)
				return res
	res["err"] = "공심돈(2x2)은 이어진 완공 성벽 2칸과 그 바깥 2칸의 빈 자리가 필요합니다."
	return res

func _gongsimdon_type(x: int, y: int) -> String:
	logistics.refresh()
	var best := ""
	var bd := 99999
	for r: Dictionary in logistics.routes:
		var g: Vector2i = r["gate"]
		var dd := absi(g.x - x) + absi(g.y - y)
		if dd < bd:
			bd = dd
			best = r["kind"]
	match best:
		"changryong", "jangan": return "dongbuk"
		"hwaseo": return "seobuk"
		"paldal": return "nam"
	if float(y) > float(size) / 2.0:
		return "nam"
	return "seobuk" if float(x) < float(size) / 2.0 else "dongbuk"

## PORT-TRACE [연무대 5x5]: 클릭한 칸이 가운데인 성 안 평지 5x5(모두 빈 땅). 한 변 바로 바깥 줄에 성곽(성벽·성문 등) 칸이
## 셋 이상 있어야 하고(외곽 성곽 라인과 접함), 그 방향(wall_dir)으로 국궁장 과녁이 성 밖을 향한다.
func get_yeonmudae_tiles(x: int, y: int) -> Dictionary:
	var tiles: Array[Vector2i] = []
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var q := Vector2i(x + dx, y + dy)
			if not in_bounds(q.x, q.y):
				return {"tiles": tiles, "range": [], "wall_dir": Vector2i.ZERO, "err": "연무대(5x5) 부지가 지도 밖으로 벗어납니다."}
			var t: Dictionary = grid[q.y][q.x]
			if t["terrain"] != "plain" or t["building"] != "" or t["zone"] != "" or t["under_construction"]:
				return {"tiles": tiles, "range": [], "wall_dir": Vector2i.ZERO, "err": "연무대(5x5)는 성 안 빈 평지 5x5가 필요합니다."}
			tiles.append(q)
	var best_dir := Vector2i.ZERO
	var best_n := 0
	for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := 0
		var perp := Vector2i(dir.y, dir.x)
		for k in range(-2, 3):
			var q2 := Vector2i(x, y) + dir * 3 + perp * k
			if is_wall_connector(q2.x, q2.y):
				n += 1
		if n > best_n:
			best_n = n
			best_dir = dir
	if best_n < 3:
		return {"tiles": tiles, "range": [], "wall_dir": Vector2i.ZERO, "err": "연무대(5x5)는 국궁장이 성 밖을 향하도록 한 변이 외곽 성곽에 맞닿아야 합니다."}
	# PORT-TRACE [연무대 활터]: 성 밖 과녁 구역(성벽 바깥 4칸 길이 x 폭 5칸)을 연무대의 부속시설로 함께 잡아 둔다.
	# 예전엔 과녁 그림만 성 밖에 서 있고 땅은 비어 있어, 그 사이에 민가·논이 들어섰다.
	var perp_r := Vector2i(best_dir.y, best_dir.x)
	var range_tiles: Array[Vector2i] = []
	for dd in range(4, 8):
		for kk in range(-2, 3):
			var rq := Vector2i(x, y) + best_dir * dd + perp_r * kk
			if not in_bounds(rq.x, rq.y):
				continue
			var rt: Dictionary = grid[rq.y][rq.x]
			if rt["terrain"] == "water" or rt["building"] != "" or rt["zone"] != "" or rt["under_construction"]:
				continue # 길·물길 등 이미 쓰는 칸은 비켜 간다
			range_tiles.append(rq)
	return {"tiles": tiles, "range": range_tiles, "wall_dir": best_dir, "err": ""}

# ---------------------------------------------------------------- 포루 5종 2x2
## PORT-TRACE [포루 5종 2x2]: 클릭한 완공 성벽 칸 + 성벽을 따라 이웃한 완공 성벽 1칸(성벽 2칸), 그 바깥 2칸(비어 있어야)으로
## 돌출. 종류는 위치로 자동(사용자 결정): 지도 중심에서 본 방향 — 동포루·서포루·남포루·북동포루·북서포루.
## PORT-TRACE [포루 1x2]: 사용자 요청 — "포루는 성곽 밖으로 돌출된 직사각형. 성곽 한 칸과 튀어나온 한 칸, 총 2칸".
## 완공 성벽 칸을 클릭 → 그 칸 + 성 밖 쪽 바로 옆 한 칸.
func get_poru_tiles(x: int, y: int) -> Dictionary:
	var res := {"wall": [], "out": [], "axis": Vector2i(1, 0), "out_dir": Vector2i(0, 1), "type": "dong", "err": "", "len": 1}
	if count_completed("wall") == 0:
		res["err"] = "성곽을 먼저 축조해야 합니다."
		return res
	if not _is_done_wall(x, y):
		res["err"] = "포루(1x2)는 완공된 성벽 칸을 눌러 바깥으로 돌출시켜 짓습니다."
		return res
	var d := Vector2i(1, 0)
	if not (_is_done_wall(x - 1, y) or _is_done_wall(x + 1, y)) and (_is_done_wall(x, y - 1) or _is_done_wall(x, y + 1)):
		d = Vector2i(0, 1)
	var perp := Vector2i(d.y, d.x)
	var cands: Array[Vector2i] = []
	var o1 := Vector2i(x, y) + perp
	var o2 := Vector2i(x, y) - perp
	if in_bounds(o1.x, o1.y) and grid[o1.y][o1.x]["terrain"] == "outside":
		cands.append(perp)
	if in_bounds(o2.x, o2.y) and grid[o2.y][o2.x]["terrain"] == "outside":
		cands.append(-perp)
	if cands.is_empty():
		var cvec := Vector2(float(x), float(y)) - Vector2(float(size), float(size)) * 0.5
		cands.append(perp if cvec.dot(Vector2(perp)) >= 0.0 else -perp)
	for out_dir: Vector2i in cands:
		var o := Vector2i(x, y) + out_dir
		if not in_bounds(o.x, o.y):
			continue
		var ot: Dictionary = grid[o.y][o.x]
		if ot["building"] != "" or ot["zone"] != "" or ot["terrain"] == "water" or ot["under_construction"]:
			continue
		res["wall"] = [Vector2i(x, y)]
		res["out"] = [o]
		res["axis"] = d
		res["out_dir"] = out_dir
		res["type"] = _poru_type(x, y)
		return res
	res["err"] = "포루(1x2)는 완공 성벽 칸과 그 바로 바깥 한 칸의 빈 자리가 필요합니다."
	return res

## PORT-TRACE [포루 4종]: 북서포루(砲樓, 화포를 쏘는 공격형)·동북포루(鋪樓, 군사 대기·감시)·북포루(鋪樓, 지형 특색)·남포루(砲樓).
## 지도 중심에서 본 방향으로 정한다: 남쪽 → 남포루, 북쪽 → 북포루, 북서·서쪽 → 북서포루, 북동·동쪽 → 동북포루.
func _poru_type(x: int, y: int) -> String:
	var v := Vector2(x, y) - Vector2(size, size) * 0.5
	var ang := rad_to_deg(atan2(v.y, v.x)) # 0=동, 90=남, 180=서, -90=북
	if ang > 22.5 and ang < 157.5:
		return "nam"
	if ang >= 157.5 or ang <= -112.5:
		return "bukseo"
	if ang > -112.5 and ang <= -67.5:
		return "buk"
	return "dongbuk"

# ---------------------------------------------------------------- 교육 시설(향교·서원·서당)
## 부지에 맞닿은 길이 길을 따라(최대 400칸) 성문에 닿는가
func _site_road_to_gate(tiles: Array) -> bool:
	var inset := {}
	for p in tiles:
		inset[p] = true
	var q: Array[Vector2i] = []
	var seen := {}
	for p2 in tiles:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p2 + d
			if inset.has(n) or seen.has(n) or not in_bounds(n.x, n.y):
				continue
			if grid[n.y][n.x]["building"] == "gate":
				return true
			if grid[n.y][n.x]["building"] == "road":
				seen[n] = true
				q.append(n)
	var head := 0
	while head < q.size() and head < 400:
		var c: Vector2i = q[head]
		head += 1
		for d2: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n2 := c + d2
			if seen.has(n2) or not in_bounds(n2.x, n2.y):
				continue
			var b: String = grid[n2.y][n2.x]["building"]
			if b == "gate":
				return true
			if b == "road":
				seen[n2] = true
				q.append(n2)
	return false

## PORT-TRACE [서당·매곡서원]: 방·리(res) 구획 안 n x n 자리 — 빈 구획 칸 우선, 서당(allow_huts)은 초가(res_1)도 헐고 쓸 수 있음.
## need_stone: 둘레 바로 바깥에 박석길 칸이 이만큼 이상(매곡서원 = 박석길로 둘러싸인 방리). 찾으면 plaza(kind)로 확정하고 앵커 반환.
## relax: 자리가 없을 때(도시가 기와집으로 꽉 참) 기와집(res_2) 자리와, n x n 안에 통째로 들어가는 묶음 집(hgroup) 자리도 쓴다
func allocate_edu_site(kind: String, n: int, need_stone: int, allow_huts: bool, relax: bool = false) -> Vector2i:
	var cands: Array[Vector2i] = []
	for y in range(size - n + 1):
		for x in range(size - n + 1):
			if grid[y][x]["zone"] == "res":
				cands.append(Vector2i(x, y))
	cands.shuffle()
	for pass_i in range((3 if relax else 2) if allow_huts else 1):
		for p: Vector2i in cands:
			var ok := true
			for dy in range(n):
				for dx in range(n):
					var t: Dictionary = grid[p.y + dy][p.x + dx]
					var b: String = t["building"]
					var grp_ok := false
					if pass_i == 2 and t.has("hgroup"):
						var hg: Dictionary = t["hgroup"]
						grp_ok = int(hg["x0"]) >= p.x and int(hg["y0"]) >= p.y and int(hg["x0"]) + int(hg.get("w", 1)) <= p.x + n and int(hg["y0"]) + int(hg.get("h", 1)) <= p.y + n
					if t["zone"] != "res" or t.has("plaza") or (t.has("hgroup") and not grp_ok) or t.has("zone_build"):
						ok = false
					elif not (b == "" or (pass_i >= 1 and b == "res_1") or (pass_i == 2 and b in ["res_2", "res_1"])):
						ok = false
			if not ok:
				continue
			if need_stone > 0:
				var stones := 0
				for k in range(-1, n + 1):
					for q: Vector2i in [Vector2i(p.x + k, p.y - 1), Vector2i(p.x + k, p.y + n), Vector2i(p.x - 1, p.y + k), Vector2i(p.x + n, p.y + k)]:
						if is_stone_road(q.x, q.y):
							stones += 1
				if stones < need_stone:
					continue
			for dy2 in range(n):
				for dx2 in range(n):
					var t2: Dictionary = grid[p.y + dy2][p.x + dx2]
					t2["building"] = ""
					t2.erase("house_variant")
					t2.erase("hgroup")
					t2["plaza"] = {"x0": p.x, "y0": p.y, "n": n, "kind": kind}
					t2["facility_id"] = kind
					t2["special_type"] = kind
					if kind == "seowon":
						t2["building_type"] = "SPECIAL"
						t2["building_name"] = "화성 유학 서원 (書院)"
					elif kind == "seodang":
						t2["building_name"] = "동네 서당 (글방)"
			emit_signal("grid_changed")
			return p
	return Vector2i(-1, -1)

# ---------------------------------------------------------------- 건설 교착(Deadlock) 자가 회복 시스템
## [셀프 힐링 타이머]: 인게임 2계절(= 2턴) 이상 공사 진행도가 정체된 부지(active_sites)와
## 성곽·단일 건물(wall_build) 비계를 강제 완공하여 맵을 교착 상태에서 해방시킨다.
## TurnSystem이 홀수 턴마다 호출하므로 매 프레임 검사 없이 분산 처리된다.
## 정상적인 자원 조달 루트는 유지하되, 장기 미완공 시에만 자동 회복(Self-Healing)으로 보완.
const STALL_TURN_THRESHOLD := 2  # 2턴(= 2계절) 이상 진행도 동결 시 강제 진행
const STALL_FORCE_GAIN := 0.25   # 강제 진행 시 매 검사당 +25% 적용 → 최대 4회 내 완공

## [건설 교착 해소] 부지(active_sites) 공정 정지 감지 및 강제 완공 처리
## 반환값: 이번 호출에서 강제 완공된 건물 이름 목록 (Array[String])
func check_stalled_construction() -> Array:
	var forced_complete: Array = []
	var remaining_sites: Array = []

	for site: Dictionary in active_sites:
		var bp_ticks: int = int(site.get("bp_ticks", 0))
		var bp_total: int = int(site.get("bp_total", 1))
		var stall_count: int = int(site.get("_stall_count", 0))
		var cur_frac: float = clampf(float(bp_ticks) / float(maxi(bp_total, 1)), 0.0, 1.0)
		var prev_frac: float = float(site.get("_prev_frac", -1.0))

		if prev_frac < 0.0:
			# 첫 검사 기준점 등록 — 아직 판정 없음
			site["_prev_frac"] = cur_frac
			site["_stall_count"] = 0
			remaining_sites.append(site)
			continue

		if absf(cur_frac - prev_frac) < 0.01:
			stall_count += 1
		else:
			stall_count = 0
		site["_stall_count"] = stall_count
		site["_prev_frac"] = cur_frac

		if stall_count >= STALL_TURN_THRESHOLD:
			# 강제 진행: bp_ticks +25%, turns_left 강제 1 감소
			var gain: int = maxi(1, int(float(bp_total) * STALL_FORCE_GAIN))
			site["bp_ticks"] = mini(bp_ticks + gain, bp_total)
			if int(site.get("turns_left", 0)) > 0:
				site["turns_left"] = int(site["turns_left"]) - 1
			site["_stall_count"] = 0

		# 완공 판정
		if int(site.get("turns_left", 0)) <= 0:
			var anchor_s: Vector2i = site["anchor"]
			for pt_s in site["tiles"]:
				var gt_s: Dictionary = grid[pt_s.y][pt_s.x]
				gt_s["under_construction"] = false
				unregister_build_tile(pt_s.x, pt_s.y)
				if pt_s == anchor_s:
					gt_s["building"] = site["building"]
					gt_s["site_tiles"] = site["tiles"]
				else:
					gt_s["building"] = "%s_site" % site["building"]
					gt_s["site_anchor"] = anchor_s
			forced_complete.append(site["building"])
		else:
			remaining_sites.append(site)

	if not forced_complete.is_empty():
		active_sites = remaining_sites
		emit_signal("grid_changed")

	# 성곽·단일 건물 wall_build 비계 강제 완공 (5턴 이상 정체 시)
	for row_g: Array in grid:
		for t_g: Dictionary in row_g:
			if not t_g.has("wall_build"):
				continue
			var wb: int = int(t_g["wall_build"])
			var w_stall: int = int(t_g.get("_w_stall", 0))
			var w_prev: int = int(t_g.get("_w_prev", wb + 99))
			if wb == w_prev:
				w_stall += 1
			else:
				w_stall = 0
			t_g["_w_stall"] = w_stall
			t_g["_w_prev"] = wb
			if w_stall >= 5 and wb > 0:
				t_g["wall_build"] = maxi(wb - 1, 0)
				t_g["_w_stall"] = 0
			if int(t_g.get("wall_build", 1)) <= 0:
				t_g.erase("wall_build")
				t_g.erase("wall_build_total")
				t_g.erase("bp_ticks")
				t_g.erase("bp_total")
				t_g.erase("_w_stall")
				t_g.erase("_w_prev")

	return forced_complete

## [종심 방어 전술] 화성행궁 중심점 조회
func find_haenggung_center() -> Vector2i:
	var hg := find_building_anchor("haenggung")
	if hg.x >= 0 and hg.y >= 0:
		return hg
	for y: int in range(size):
		for x: int in range(size):
			if str(grid[y][x].get("building", "")).begins_with("haenggung"):
				return Vector2i(x, y)
	return Vector2i(14, 29)

## [종심 방어 전술] 반경 내 타일 리스트 조회 (Chebyshev)
func get_tiles_in_radius(pos: Vector2i, radius: int = 1) -> Array[Vector2i]:
	var res: Array[Vector2i] = []
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var p := Vector2i(pos.x + dx, pos.y + dy)
			if in_bounds(p.x, p.y):
				res.append(p)
	return res

## [종심 방어 전술] 성문/진입점에서 화성행궁 본궁까지의 도로망 우선 A* 진격 경로 사전 계산
func find_march_path_to_haenggung(start_pos: Vector2i) -> Array[Vector2i]:
	var goal: Vector2i = find_haenggung_center()
	if not in_bounds(start_pos.x, start_pos.y) or not in_bounds(goal.x, goal.y):
		return [goal]
	if start_pos == goal:
		return [goal]

	var dist_map: Dictionary = {}
	var prev_map: Dictionary = {}
	var frontier: Array[Vector2i] = [start_pos]
	dist_map[start_pos] = 0.0

	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var max_iterations: int = 1500
	var iters: int = 0
	var reached: bool = false

	while not frontier.is_empty() and iters < max_iterations:
		iters += 1
		# 최소 추정 비용 노드 인출
		var best_idx: int = 0
		var best_cost: float = 999999.0
		for idx: int in range(frontier.size()):
			var cand: Vector2i = frontier[idx]
			var g_cost: float = float(dist_map.get(cand, 9999.0))
			var h_cost: float = float(absi(cand.x - goal.x) + absi(cand.y - goal.y))
			var f_cost: float = g_cost + h_cost
			if f_cost < best_cost:
				best_cost = f_cost
				best_idx = idx

		var current: Vector2i = frontier[best_idx]
		frontier.remove_at(best_idx)

		if current == goal or (absi(current.x - goal.x) <= 1 and absi(current.y - goal.y) <= 1):
			goal = current
			reached = true
			break

		var cur_g: float = float(dist_map.get(current, 0.0))

		for d: Vector2i in dirs:
			var next_pos: Vector2i = current + d
			if not in_bounds(next_pos.x, next_pos.y):
				continue

			var cell: Dictionary = grid[next_pos.y][next_pos.x]
			var bld: String = str(cell.get("building", ""))
			var ter: String = str(cell.get("terrain", "plain"))

			var step_cost: float = 3.0
			if bld == "stone_road":
				step_cost = 1.0
			elif bld == "road" or bld == "gate":
				step_cost = 1.2
			elif bld in ["canal", "levee"]:
				step_cost = 1.8
			elif bld.begins_with("haenggung"):
				step_cost = 1.0
			elif bld == "wall":
				step_cost = 12.0
			elif ter == "water":
				step_cost = 25.0
			elif ter == "mountain":
				step_cost = 10.0
			else:
				step_cost = 3.0

			var new_g: float = cur_g + step_cost
			if not dist_map.has(next_pos) or new_g < float(dist_map[next_pos]):
				dist_map[next_pos] = new_g
				prev_map[next_pos] = current
				if not frontier.has(next_pos):
					frontier.append(next_pos)

	if not reached and not dist_map.has(goal):
		# Fallback: 직선 기반 보간 경로
		var fb_path: Array[Vector2i] = []
		var cur_p: Vector2i = start_pos
		while cur_p != goal and fb_path.size() < 100:
			var step_x: int = clampi(goal.x - cur_p.x, -1, 1)
			var step_y: int = clampi(goal.y - cur_p.y, -1, 1)
			if step_x != 0:
				cur_p.x += step_x
			elif step_y != 0:
				cur_p.y += step_y
			fb_path.append(cur_p)
		return fb_path

	# 경로 역추적
	var march_path: Array[Vector2i] = []
	var trace_curr: Vector2i = goal
	while trace_curr != start_pos and prev_map.has(trace_curr):
		march_path.append(trace_curr)
		trace_curr = prev_map[trace_curr]
	march_path.reverse()

	if march_path.is_empty():
		march_path.append(goal)

	return march_path

## 특정 타일의 상태가 변경되었음을 알리고 관련 캐시를 무효화하는 헬퍼 메서드
func mark_dirty_local(pos: Vector2i) -> void:
	_logistics_dirty = true
	_border_connections_dirty = true
	if has_signal("grid_tiles_changed"):
		var changed_tiles: Array[Vector2i] = [pos]
		emit_signal("grid_tiles_changed", changed_tiles)
	if has_signal("grid_changed"):
		emit_signal("grid_changed")
