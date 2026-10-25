extends Node2D
class_name CitizenLayer

const SpriteCacheManager = preload("res://scripts/autoload/SpriteCacheManager.gd")

## 조선 정조 시대 백성 일상 렌더러 & 네임드 NPC 7인 2.5D 시각화 & 말풍선 시스템
## 정약용, 체제공, 조심태, 김홍도, 석수 김바우, 구선복, 유한지
## 수원천 빨래/낚시, 산과 나무꾼, 저잣거리, 가마, 파발마, 선비, 수레

var grid: GameGrid
var citizens: CitizenManager
var city: CityLayer
var current_season: String = "봄"
var festivals: FestivalSystem # PORT-TRACE [장마당·세시풍속]: 계절 놀이판(Main이 연결)
# PORT-TRACE [인프라 관할 범위]: 물방울(물 부족 가옥·상점)과 관할 범위 오버레이 캐시 — 지도가 바뀔 때만 다시 계산
var _drops: Array[Vector2i] = []
var _drops_dirty := true
var _cov_tool := ""
var _cov_tiles: Array[Vector2i] = []
var _cov_dirty := true
const COVERAGE_TOOLS := {
	"well": {"names": ["well"], "r": GameGrid.WELL_RADIUS, "col": Color(0.25, 0.6, 1.0, 0.22), "line": Color(0.45, 0.75, 1.0, 0.9)},
	"patrol": {"names": ["patrol"], "r": GameGrid.PATROL_RADIUS, "col": Color(0.3, 0.4, 0.9, 0.2), "line": Color(0.5, 0.6, 1.0, 0.9)},
	"firefighter": {"names": ["firefighter"], "r": GameGrid.FIRE_RADIUS, "col": Color(0.95, 0.35, 0.2, 0.2), "line": Color(1.0, 0.55, 0.35, 0.9)},
}

const HW := 32.0
const HH := 16.0

var tex_characters: Texture2D = (load("res://assets/characters_atlas.png") as Texture2D) if ResourceLoader.exists("res://assets/characters_atlas.png") else null
var font_neodgm: Font = preload("res://assets/fonts/neodgm.ttf")

const CHAR_ROWS := {
	"carrier": 0, "merchant": 1, "guard": 2, "farmer": 3, "tiger": 4
}

## 렌더 스로틀: 시민 레이어는 30fps 상한으로만 다시 그린다.
## 60fps 내내 agents.sort_custom + _draw 전체 순회 비용을 절반으로 줄인다.
var _redraw_acc: float = 0.0
const _REDRAW_INTERVAL: float = 1.0 / 30.0
var _sorted_agents: Array[Dictionary] = []
var _jeongisu_spot := Vector2.INF
var _play_dirty_jg := true
## PORT-TRACE [주택가 놀이마당·관아]: 놀이마당 목록(지도가 바뀔 때만 다시 구함)과 장면 시간(일시정지면 멈춤)
var _play_yards: Array = []
var _kid_yards: Array = []
var _cattle_yards: Array = []
var _sea_spots: Array = [] # [{pos: Vector2i, kind: "jeotgal"/"salt"/"store"}]
var _fort_spots: Array = []
var _edu_spots: Array = []
var _work_spots: Array = [] # 공방·가게 앞마당 일하는 장면 자리(지도가 바뀔 때만 다시 모음)
var _chapels: Array[Vector2i] = [] # [{kind: "seodang"/"seowon"/"hyanggyo", x0, y0, n}] # [{kind: "bongdon"/"seojangdae"/"yeonghwajeong", anchor: Vector2i, info}]
var _play_dirty := true
var _scene_t := 0.0
## PORT-TRACE [렉: 턴 정산 멈칫]: 지도가 바뀐 뒤 다시 만들 것 — 2: 가림막부터, 1: 놀이마당·물방울·관할 목록.
## 각각 20ms 남짓이라 GameGrid.frame_claim 차례를 받아 프레임마다 하나씩(시민 길 정보·지도 굽기와도 겹치지 않게)
var _grid_pending := 0

# 성곽 미완성 지점 하이라이트 가이드
var wall_guide_target: Vector2i = Vector2i(-1, -1)
var wall_guide_timer: float = 0.0

# 사건 및 화재 현장 위치 핑(Incident Ping)
var _incident_pings: Array[Dictionary] = []

func ping_incident(world_pos: Vector2, ping_text: String = "사건 현장") -> void:
	_incident_pings.append({
		"pos": world_pos,
		"text": ping_text,
		"timer": 3.0,
		"max_timer": 3.0
	})
	queue_redraw()

func _update_incident_pings(delta: float) -> void:
	if _incident_pings.is_empty():
		return
	var rem: Array[int] = []
	for i: int in range(_incident_pings.size()):
		var p_dict: Dictionary = _incident_pings[i]
		p_dict["timer"] = float(p_dict.get("timer", 0.0)) - delta
		if float(p_dict["timer"]) <= 0.0:
			rem.append(i)
	rem.sort()
	rem.reverse()
	for idx: int in rem:
		_incident_pings.remove_at(idx)
	if not _incident_pings.is_empty():
		queue_redraw()

func show_wall_guide(cell_pos: Vector2i, duration: float = 5.0) -> void:
	wall_guide_target = cell_pos
	wall_guide_timer = duration
	queue_redraw()

# 청크 인터리빙 외부 호환 인터페이스
var _chunk_count: int = 0

func setup(g: GameGrid, c: CitizenManager, city_layer: CityLayer) -> void:
	grid = g
	citizens = c
	city = city_layer
	z_index = 1000 # 말풍선 및 최상위 UI는 항상 화면 맨 위에 노출
	y_sort_enabled = true
	grid.grid_changed.connect(func():
		_grid_pending = 2
	)

func setup_chunks(_count: int, _chunk_depth: float, _band_depth: float) -> void:
	_chunk_count = 0

func _get_view_bounds() -> Rect2:
	var vp_rect: Rect2 = get_viewport_rect()
	var inv_xform: Transform2D = get_canvas_transform().affine_inverse()
	var p0: Vector2 = inv_xform * vp_rect.position
	var p1: Vector2 = inv_xform * Vector2(vp_rect.position.x + vp_rect.size.x, vp_rect.position.y)
	var p2: Vector2 = inv_xform * (vp_rect.position + vp_rect.size)
	var p3: Vector2 = inv_xform * Vector2(vp_rect.position.x, vp_rect.position.y + vp_rect.size.y)
	var min_x: float = minf(minf(p0.x, p1.x), minf(p2.x, p3.x)) - 90.0
	var max_x: float = maxf(maxf(p0.x, p1.x), maxf(p2.x, p3.x)) + 90.0
	var min_y: float = minf(minf(p0.y, p1.y), minf(p2.y, p3.y)) - 90.0
	var max_y: float = maxf(maxf(p0.y, p1.y), maxf(p2.y, p3.y)) + 90.0
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

func _is_special_or_event_entity(a: Dictionary) -> bool:
	if SpecialEntityManager.is_special_entity(a):
		return true
	if a.get("is_plaza_event", false) or a.get("is_custom", false) or a.get("festival", false) or a.get("custom", false):
		return true
	if a.get("is_named", false) or a.get("is_drill", false) or a.get("drill", false):
		return true
	if a.get("is_procession", false) or a.get("procession", false) or a.get("trip", false):
		return true
	if a.get("is_firefighter", false) or a.get("is_fire_volunteer", false) or a.get("is_flood_worker", false):
		return true
	if a.get("is_criminal", false) or a.get("is_patrol", false) or a.get("is_bandit", false) or a.get("is_rebel", false) or a.get("is_combat", false):
		return true
	var atype: String = str(a.get("type", ""))
	if atype.begins_with("named_") or atype.begins_with("procession_"):
		return true
	if SeasonalCustomManager.is_seasonal_custom(atype):
		return true
	if atype in [
		"bandit", "horde", "rebel", "invader", "thief", "pickpocket", "brawler", "criminal", "criminal_npc",
		"jangyongyeong", "jangyongyeong_soldier", "patrol_soldier", "patrol_officer", "officer", "sunla", "guard",
		"chakhogapsa", "posu", "sasu", "salsu", "gipo", "official_rider", "monk_soldier", "volunteer_militia", "militia",
		"pungmul", "pungmul_band", "bull_parade", "nongak", "stretcher", "sandang", "custom", "festival",
		"ssireum", "juldagi", "taekkyeon", "talchum", "seokjeon", "ganggang", "kites", "paengi", "jwibul", "neolttwigi", "swing",
		"seodang", "seowon", "hyanggyo", "seodang_teacher", "seodang_student", "scholar", "student", "teacher", "yusaeng",
		"firefighter", "firefighter_soldier", "bucket_volunteer", "volunteer_bucket", "fire_panic",
		"flood_sandbag", "flood_refugee",
		"tiger", "wolf", "predator", "hunter", "saposu", "bait", "marksman", "torch_bearer",
		"drowning", "rescuer", "jeongisu"
	]:
		return true
	var a_state: String = str(a.get("state", ""))
	if a_state in ["arrested", "escorted", "dispatch", "suppress", "combat", "attack_wall", "firing", "triumph_march", "drowning", "saved", "rescue", "drill"]:
		return true
	return false

func _process(delta: float) -> void:
	if wall_guide_timer > 0.0:
		wall_guide_timer = maxf(0.0, wall_guide_timer - delta)
		queue_redraw()
	if not _incident_pings.is_empty():
		_update_incident_pings(delta)
	if _grid_pending > 0 and GameGrid.frame_claim():
		if _grid_pending == 2:
			_occ_dirty = true
			_grid_pending = 1
		else:
			_drops_dirty = true
			_cov_dirty = true
			_play_dirty = true
			_play_dirty_jg = true
			_grid_pending = 0
		queue_redraw()
	_scene_t += delta * (citizens.time_scale if citizens else 1.0)
	_redraw_acc += delta
	if _redraw_acc >= _REDRAW_INTERVAL:
		_redraw_acc -= _REDRAW_INTERVAL
		if citizens and city:
			# 에이전트 깊이 정렬 (Schwartzian Transform으로 O(N) 키 사전계산 후 빠른 정렬)
			# 전체 활성 에이전트를 깊이순으로 정렬하여 _draw에서 근거리/원거리/특수상황 필터링을 완벽 처리
			var list: Array[Dictionary] = []
			for a: Dictionary in citizens.agents:
				a["_depth"] = float(a.get("x", 0.0)) + float(a.get("y", 0.0))
				list.append(a)
			list.sort_custom(func(u: Dictionary, v: Dictionary) -> bool:
				return float(u.get("_depth", 0.0)) < float(v.get("_depth", 0.0))
			)
			_sorted_agents = list

			# 에이전트 깊이 정렬 완료 후 전체 다시 그리기 트리거
		queue_redraw()

func _draw() -> void:
	if grid == null or city == null:
		return
	_bubble_queue.clear()
	_bubble_defer = true
	_maybe_bake_gates()
	_maybe_bake_structs()

	# 성곽 미완성 지점 안내 점멸 하이라이트 가이드 (최상위 Y-Sort 레이어 렌더링)
	if wall_guide_timer > 0.0 and grid.in_bounds(wall_guide_target.x, wall_guide_target.y):
		_draw_wall_guide_highlight()

	# 도적 소굴(근거지) 렌더링 (동적 복수 소굴 지원 - 소탕 시 완전 소멸)
	if citizens and citizens.sim:
		var b_mgr: BanditManager = citizens.bandit_mgr
		if b_mgr != null and not b_mgr.camps.is_empty():
			for c_dict: Dictionary in b_mgr.camps:
				var c_pos: Vector2i = c_dict.get("pos", Vector2i(-1, -1))
				if c_pos.x >= 0 and grid.in_bounds(c_pos.x, c_pos.y):
					var c_elev: float = grid.grid[c_pos.y][c_pos.x].get("elevation", 1.0)
					var cp := city.cell_center(float(c_pos.x) + 0.5, float(c_pos.y) + 0.5, c_elev)
					_draw_bandit_camp(cp, false)

	# 방화 피해 가옥 불길 및 연기 연출
	if citizens and citizens.is_bandit_raid_active():
		var target_house: Vector2i = citizens.get_bandit_target_house()
		if grid.in_bounds(target_house.x, target_house.y):
			var h_elev: float = grid.grid[target_house.y][target_house.x].get("elevation", 1.0)
			var hp := city.cell_center(float(target_house.x) + 0.5, float(target_house.y) + 0.5, h_elev)
			_draw_house_fire_smoke(hp)

	# 실시간 약탈 피해 타일(is_looted) 검은 연기 및 불꽃 연출 (O(K) 딕셔너리 순회)
	if citizens and citizens.bandit_mgr and not citizens.bandit_mgr.looted_tiles.is_empty():
		var v_bounds: Rect2 = _get_view_bounds()
		for lp_tile: Vector2i in citizens.bandit_mgr.looted_tiles.keys():
			if grid.in_bounds(lp_tile.x, lp_tile.y):
				var elev: float = grid.grid[lp_tile.y][lp_tile.x].get("elevation", 1.0)
				var lp := city.cell_center(float(lp_tile.x) + 0.5, float(lp_tile.y) + 0.5, elev)
				if v_bounds.has_point(lp):
					_draw_house_fire_smoke(lp)

	# 일반 화재(공방, 상가, 가옥) 불길 및 연기 연출
	if citizens:
		var v_bounds: Rect2 = _get_view_bounds()
		for f: Dictionary in citizens.get_active_fires():
			var fpos: Vector2i = f.get("pos", Vector2i(-1, -1))
			if grid.in_bounds(fpos.x, fpos.y) and not f.get("extinguished", false):
				var f_elev: float = grid.grid[fpos.y][fpos.x].get("elevation", 1.0)
				var fp := city.cell_center(float(fpos.x) + 0.5, float(fpos.y) + 0.5, f_elev)
				if v_bounds.has_point(fp):
					_draw_house_fire_smoke(fp)

	var tiger_active_flag: bool = citizens != null and citizens.has_active_tiger()
	# PORT-TRACE [을묘원행]: 행차 동안엔 거리 사람·장면을 모두 감추고(RoyalProcessionManager가 행렬·길가 도열 백성·격쟁/상언을 그림)
	var eulmyo_on: bool = citizens != null and citizens.sim != null and citizens.sim.is_eulmyo_active

	if eulmyo_on:
		_bubble_defer = false
		_bubble_queue.clear()
		_draw_incident_pings()
		return
	# 0. 계절 놀이판(장마당 연희·석전·연날리기 등) — 호랑이 출현 시 공연/연희자 전원 피신하여 렌더링 억제
	if festivals and not tiger_active_flag:
		FestivalArt.draw_all(self, festivals, city, grid)
	# 0-1. 주택가 놀이마당(널뛰기·그네), 서당·향교, 성곽 군사훈련, 전기수 이야기판, 관아 재판, 종루 타종:
	# 화면 확대 축소(줌 배율)와 무관하게 목적 행동을 하는 인물들은 상시 노출 (화면 컬링은 각 함수 내부 bounds 검사로 안전 수행)
	_scene_small(true)
	# PORT-TRACE [우시장 소 사라짐]: 호랑이가 나오면 놀이마당을 통째로 건너뛰어 쇠전 소까지 사라졌다 — 쇠전은 늘 소로 북적인다
	_draw_play_yards(tiger_active_flag)
	_draw_fort_scenes()
	if not tiger_active_flag:
		_draw_jeongisu()
	_draw_edu_scenes()
	if not tiger_active_flag:
		_draw_work_scenes()
		_draw_market_life()
	_draw_chapels()
	_scene_small(false)
	_draw_siege()
	_scene_small(true)
	_draw_gwana_scenes()
	_scene_small(false)
	_draw_bell_ring()

	# 0-1. 교전 구역 바닥 흙먼지 연기 (백병전 난전 분위기 연출)
	_draw_combat_dust_clouds()

	# 1. 조선 백성, 네임드 NPC 및 건설 장비 에이전트 렌더링
	if citizens and not _sorted_agents.is_empty():
		var bounds: Rect2 = _get_view_bounds()
		var current_lod: int = CameraLODController.get_lod()
		var visible_tiles: int = citizens.get_visible_tile_count()
		var _show_normal_agents: bool = (visible_tiles <= CitizenManager.TILE_LIMIT_NPC_VISIBLE)
		var show_normal_bubbles: bool = (visible_tiles <= CitizenManager.TILE_LIMIT_BUBBLE_VISIBLE)

		var is_close_up: bool = (visible_tiles <= CitizenManager.TILE_LIMIT_NPC_VISIBLE) and (current_lod != CameraLODController.LODLevel.LOW)

		# A. 화면 뷰포트 영역(bounds) 내에 위치한 유효 에이전트 수집
		var visible_agents: Array[Dictionary] = []
		for a: Dictionary in _sorted_agents:
			if a.get("is_hidden_shelter", false):
				continue # 피신 인원 제외
			var gx: int = clampi(int(round(float(a["x"]))), 0, grid.size - 1)
			var gy: int = clampi(int(round(float(a["y"]))), 0, grid.size - 1)
			var elev: float = grid.grid[gy][gx]["elevation"] if grid.in_bounds(gx, gy) else 0.0
			var p: Vector2 = city.cell_center(float(a["x"]), float(a["y"]), elev)
			if bounds.has_point(p):
				visible_agents.append(a)

		if is_close_up:
			# [근거리 확대 뷰]: 시야 내 모든 에이전트를 풍성하고 북적북적하게 렌더링
			for a: Dictionary in visible_agents:
				_draw_agent(a)
		else:
			# [원거리 축소 뷰]:
			# 1. 특수 상황 유닛 (을묘원행, 서장대 사열/훈련, 도적떼 침공/전투, 장용영 요격군, 순라군, 네임드 인물):
			#    화면 크기 및 인원수 제한에 일체 구애받지 않고 100% 전원 무조건 렌더링!
			# 2. 일상 일반 백성 (상인, 짐꾼, 농민 등 배경 인구):
			#    거리가 썰렁해 보이지 않도록 최대 30명을 화면 전역에 균등 분산하여 렌더링!
			var special_event_agents: Array[Dictionary] = []
			var general_civilians: Array[Dictionary] = []

			for a: Dictionary in visible_agents:
				if _is_special_or_event_entity(a):
					special_event_agents.append(a)
				else:
					general_civilians.append(a)

			var draw_list: Array[Dictionary] = []
			# 특수 상황 인원은 전원 100% 무조건 추가
			draw_list.append_array(special_event_agents)

			# 일상 일반 백성은 도시 인구수에 비례하여 균등 분산 추가
			# (1만 미만: 20명, 10만 이상: 30명, 30만 이상: 50명, 중간 구간 점진 증가)
			var cur_pop: int = 0
			if citizens and citizens.sim:
				cur_pop = citizens.sim.population
			elif city and city.sim:
				cur_pop = city.sim.population

			var max_general_npcs_distant: int = 20
			if cur_pop >= 300000:
				max_general_npcs_distant = 50
			elif cur_pop >= 100000:
				var t_high: float = clampf(float(cur_pop - 100000) / 200000.0, 0.0, 1.0)
				max_general_npcs_distant = 30 + int(t_high * 20.0)
			elif cur_pop >= 10000:
				var t_mid: float = clampf(float(cur_pop - 10000) / 90000.0, 0.0, 1.0)
				max_general_npcs_distant = 20 + int(t_mid * 10.0)
			else:
				max_general_npcs_distant = 20

			if general_civilians.size() <= max_general_npcs_distant:
				draw_list.append_array(general_civilians)
			else:
				var stride: float = float(general_civilians.size()) / float(max_general_npcs_distant)
				for si: int in range(max_general_npcs_distant):
					var pick_idx: int = clampi(int(float(si) * stride), 0, general_civilians.size() - 1)
					draw_list.append(general_civilians[pick_idx])

			# Y-Sort(깊이 순) 정렬 후 일괄 렌더링
			draw_list.sort_custom(func(u: Dictionary, v: Dictionary) -> bool:
				return float(u.get("_depth", 0.0)) < float(v.get("_depth", 0.0))
			)
			for a: Dictionary in draw_list:
				_draw_agent(a)

		# 말풍선 레이어 (근거리에서는 300칸 이하 시 노출, 원거리에서는 중요 NPC만 선별 노출)
		for a: Dictionary in _sorted_agents:
			if a.get("is_hidden_shelter", false):
				continue
			var btext: String = a.get("bubble_text", "")
			if btext != "":
				var is_special_b: bool = _is_special_or_event_entity(a)
				if not is_close_up and not is_special_b:
					continue
				if is_close_up and not show_normal_bubbles and not is_special_b:
					continue
				var gx2: int = clampi(int(round(float(a["x"]))), 0, grid.size - 1)
				var gy2: int = clampi(int(round(float(a["y"]))), 0, grid.size - 1)
				var elev2: float = grid.grid[gy2][gx2]["elevation"] if grid.in_bounds(gx2, gy2) else 0.0
				var p2: Vector2 = city.cell_center(float(a["x"]), float(a["y"]), elev2)
				if bounds.has_point(p2):
					var n_name: String = a.get("name", "")
					if not String(a.get("type", "")) in ["deer", "crane", "wild_boar", "rabbit", "wolf", "tiger", "sparrow_flock", "scarecrow", "bait", "geojunggi", "nongno"]:
						p2.y -= 14.0 # 도트 스프라이트 사람은 키가 커서 말풍선을 머리 위로
					_draw_speech_bubble(p2, btext, n_name, is_special_b)

		# 1-0. 백병전 상공 교전 헤드업 상태 바 (Battle Status HUD) 렌더링
		_draw_battle_status_hud()
		# 1-0-1. 화재 진화 상공 헤드업 게이지 바 (Fire Status HUD) 렌더링
		_draw_fire_status_hud()

	_bubble_defer = false
	for bq: Array in _bubble_queue:
		_draw_speech_bubble(bq[0], bq[1], bq[2], bq[3])
	_bubble_queue.clear()
	# 1-0-1-1. 공성전 공격/방호 막대 (사람 위에 덮이는 성문 앞 그림보다 나중에)
	_draw_siege_bar()
	# 1-0-2. 사건 및 화재 위치 펄스 핑 렌더링
	_draw_incident_pings()
	# 1-1. 물 부족 물방울 + 관할 범위 오버레이
	_draw_infra_overlays()
	# 1-2. 성문 밖 외부 길 끝 이정표
	_draw_gate_signposts()

	# 2. 마우스 호버 커서 다이아몬드 및 실제 규격 고스트 프리뷰 (드래그 중이 아닐 때)
	if not city._is_dragging and grid.in_bounds(city.hover_cell.x, city.hover_cell.y):
		var hx: int = city.hover_cell.x
		var hy: int = city.hover_cell.y
		if city.current_tool == "inspect":
			# 조사 모드: 1x1 노란색 다이아몬드 커서
			var ce: Array = grid.tile(hx, hy).get("corner_elev", [1.0, 1.0, 1.0, 1.0])
			var hp_n := city.cell_center(hx, hy, ce[0])
			var hp_e := city.cell_center(hx + 1, hy, ce[1])
			var hp_s := city.cell_center(hx + 1, hy + 1, ce[2])
			var hp_w := city.cell_center(hx, hy + 1, ce[3])
			var col := Color(1, 0.9, 0.3, 0.85)
			FastDraw.polyline(self, PackedVector2Array([hp_n, hp_e, hp_s, hp_w, hp_n]), col, 2.0)
		else:
			# 건설 배치 모드: 실제 규격 풋프린트 기반 청사진 고스트 프리뷰 (초록/빨강 피드백)
			var raw_fp: Array = city.get_tool_footprint(city.current_tool, hx, hy)
			var footprint: Array[Vector2i] = []
			for pt in raw_fp:
				if pt is Vector2i:
					footprint.append(pt)
				elif pt is Vector2:
					footprint.append(Vector2i(int(pt.x), int(pt.y)))
			var is_valid: bool = city.is_tool_valid_at(city.current_tool, hx, hy)
			var fill_col: Color = Color(0.18, 0.82, 0.32, 0.42) if is_valid else Color(0.92, 0.18, 0.18, 0.42)
			var line_col: Color = Color(0.35, 1.0, 0.45, 0.95) if is_valid else Color(1.0, 0.32, 0.32, 0.95)

			for pt: Vector2i in footprint:
				if grid.in_bounds(pt.x, pt.y):
					var ce: Array = grid.tile(pt.x, pt.y).get("corner_elev", [1.0, 1.0, 1.0, 1.0])
					var gp_n := city.cell_center(pt.x, pt.y, ce[0])
					var gp_e := city.cell_center(pt.x + 1, pt.y, ce[1])
					var gp_s := city.cell_center(pt.x + 1, pt.y + 1, ce[2])
					var gp_w := city.cell_center(pt.x, pt.y + 1, ce[3])
					var poly := PackedVector2Array([gp_n, gp_e, gp_s, gp_w])
					FastDraw.poly(self, poly, fill_col)
					FastDraw.polyline(self, PackedVector2Array([gp_n, gp_e, gp_s, gp_w, gp_n]), line_col, 1.4)

	# 3. 드래그 고스트 미리보기
	if city._is_dragging and not city._drag_tiles.is_empty():
		var p_col := city._get_preview_color(city.current_tool)
		for dt: Vector2i in city._drag_tiles:
			if grid.in_bounds(dt.x, dt.y):
				var ce2: Array = grid.tile(dt.x, dt.y).get("corner_elev", [1.0, 1.0, 1.0, 1.0])
				var gp_n := city.cell_center(dt.x, dt.y, ce2[0])
				var gp_e := city.cell_center(dt.x + 1, dt.y, ce2[1])
				var gp_s := city.cell_center(dt.x + 1, dt.y + 1, ce2[2])
				var gp_w := city.cell_center(dt.x, dt.y + 1, ce2[3])
				var gcenter := (gp_n + gp_e + gp_s + gp_w) * 0.25
				var poly := PackedVector2Array([
					gcenter + (gp_n - gcenter) * 0.95, gcenter + (gp_e - gcenter) * 0.95,
					gcenter + (gp_s - gcenter) * 0.95, gcenter + (gp_w - gcenter) * 0.95,
				])
				FastDraw.poly(self, poly, p_col)
				FastDraw.polyline(self, poly + PackedVector2Array([poly[0]]), p_col.lightened(0.4), 2.0)

	# 4. 이정표에 마우스를 올리면 행선지·유입 물자 안내 카드(맨 위에)
	_draw_signpost_card()

	# 5. 삼수병/기포병 발사체 및 총구 화염/연막 VFX (오브젝트 풀링 렌더링)
	_draw_military_vfx()

## 코스 활동 네임드: 걸을 땐 걷는 모습, 정거장에 서면 머물며 행동(act) 소품을 들거나 놓고 한다
## 48x48 고품질 스프라이트 시트 렌더러 (24, 43 발 피봇)
func _draw_character_sprite_48x48(p: Vector2, tex: Texture2D, dir: int, frame: int, alpha: float = 1.0, is_named: bool = true) -> void:
	if tex == null:
		return
	var scale_val: float = NpcSprites.NAMED_SCALE if is_named else 0.70
	var dir_map: Array[int] = [1, 0, 3, 2]
	var iso_dir: int = dir_map[clampi(dir, 0, 3)]
	var iso_phase: int = clampi(frame, 0, 3) % 2
	var src_rect := Rect2(float(iso_phase) * 48.0, float(iso_dir) * 48.0, 48.0, 48.0)
	var dest_rect := Rect2(p.x - 24.0 * scale_val, p.y - 42.0 * scale_val, 48.0 * scale_val, 48.0 * scale_val)
	var mod := Color(1.0, 1.0, 1.0, alpha)
	draw_texture_rect_region(tex, dest_rect, src_rect, mod)

func _draw_named_extra(p: Vector2, a: Dictionary) -> void:
	var nid := String(a.get("named_id", ""))
	var working := String(a.get("state", "")) == "work"
	var dir := _sdir(a)
	var frame: int = 0 if working else int(float(a.get("anim", 0.0))) % 4
	var alpha: float = float(a.get("fade_alpha", 1.0))

	var act := String((a.get("extra", {}) as Dictionary).get("act", "")) if working else ""
	if nid == "kim_hongdo" and working:
		_draw_named_kim_hongdo(p, a) # 일할 때는 돗자리 펴고 앉아 화지에 그림
		return
	var sx := _ssx(dir)
	# 뒤쪽을 보는 방향이면 소품을 인물 뒤에 먼저 그린다
	if act != "" and dir >= 2:
		_draw_named_act(p, act, sx, _scene_t)

	var ntex: Texture2D = SpriteCacheManager.get_named_character_texture(nid)
	if ntex != null:
		_draw_character_sprite_48x48(p, ntex, dir, frame, alpha)
	else:
		_draw_oval_shadow(p + Vector2(0, 1), 8.0, 2.6, Color(0, 0, 0, 0.2))
		_spr(p, NamedNpcs.sprite_kind(nid), a, 0, dir, 0 if working else -1)

	# 앞쪽을 보는 방향이면 소품을 인물 앞에 그린다
	if act != "" and dir < 2:
		_draw_named_act(p, act, sx, _scene_t)

func _draw_named_act(p: Vector2, act: String, sx: float, t: float) -> void:
	var hand := p + Vector2(sx * 5.0, -12.0)
	match act:
		"read":
			# 두 손에 펼쳐 든 책(가끔 책장을 넘김)
			_draw_book_open(hand + Vector2(-sx * 1.5, 3.0), 0.8, sx)
			if fmod(t, 4.0) < 0.5:
				FastDraw.poly(self, PackedVector2Array([hand + Vector2(-sx * 1.5, 3.0), hand + Vector2(sx * 2.0, -1.5), hand + Vector2(sx * 2.0, 1.2)]), Color("faf3dc"))
		"write":
			# 낮은 서안 위에 종이를 놓고 붓을 놀린다
			var d := p + Vector2(sx * 9.0, -4.0)
			FastDraw.poly(self, PackedVector2Array([d + Vector2(-6, 0), d + Vector2(6, 0), d + Vector2(6, 3), d + Vector2(-6, 3)]), Color("5a3a22"))
			FastDraw.poly(self, PackedVector2Array([d + Vector2(-4, -1), d + Vector2(4, -1), d + Vector2(5, 1), d + Vector2(-5, 1)]), Color("f2ead0"))
			var bx := sin(t * 3.0) * 2.0
			draw_line(d + Vector2(bx, -9), d + Vector2(bx * 0.6, -1), Color("3d2916"), 1.2)
			FastDraw.circle(self, d + Vector2(bx * 0.6, -1), 0.9, Color("1a1410"))
		"paint":
			# 손에 펼쳐 든 화첩(왼쪽 쪽엔 그리던 풍속화) + 다른 손 붓질
			var al := hand + Vector2(-sx * 1.0, 1.0)
			var pg := PackedVector2Array([al + Vector2(-5, -1), al + Vector2(0, 0), al + Vector2(0, -6), al + Vector2(-5, -7)])
			var pg2 := PackedVector2Array([al + Vector2(0, 0), al + Vector2(5, -1), al + Vector2(5, -7), al + Vector2(0, -6)])
			FastDraw.poly(self, PackedVector2Array([pg[0] + Vector2(0, 1), pg2[1] + Vector2(0, 1), pg2[2], pg[3]]), Color("4a5a6a")) # 쪽빛 표지
			FastDraw.poly(self, pg, Color("f3eddd"))
			FastDraw.poly(self, pg2, Color("ece4cf"))
			var fig := al + Vector2(-sx * 2.5, -3.2)
			draw_line(fig + Vector2(-1.5, 0.8), fig + Vector2(0, -1), Color(0.15, 0.13, 0.12, 0.8), 0.5)
			draw_line(fig + Vector2(0, -1), fig + Vector2(1.5, 0.6), Color(0.15, 0.13, 0.12, 0.8), 0.5)
			FastDraw.circle(self, fig + Vector2(0.2, 1.6), 0.5, Color(0.15, 0.12, 0.1))
			FastDraw.circle(self, fig + Vector2(-0.8, 0.4), 0.6, Color(0.45, 0.6, 0.4, 0.7))
			var bt := al + Vector2(sx * 2.5 + sin(t * 2.5) * 1.2, -3.0)
			draw_line(bt + Vector2(sx * 3.0, -4.0), bt, Color("4a3020"), 0.8) # 붓
			FastDraw.circle(self, bt, 0.5, Color("111111"))
		"survey":
			# 측량 막대와 붉은 천
			var pole := p + Vector2(sx * 8.0, 0.0)
			draw_line(pole, pole + Vector2(0, -26), Color("5a3a22"), 1.4)
			FastDraw.poly(self, PackedVector2Array([pole + Vector2(0, -26), pole + Vector2(sx * 7.0, -24), pole + Vector2(0, -21)]), Color("c0392b") if int(t) % 2 == 0 else Color("efe6d0"))
			draw_line(hand, p + Vector2(sx * 6.0, -4.0), Color("3d2916"), 1.0)
		"drill":
			# 칼을 휘두르는 호
			var a0 := fmod(t * 5.0, TAU)
			draw_arc(hand, 10.0, a0, a0 + 1.6, 8, Color(0.92, 0.94, 0.98, 0.8), 1.8)
			draw_line(hand, hand + Vector2(cos(a0 + 0.8), sin(a0 + 0.8)) * 9.0, Color("c8d0d8"), 1.6)
		"inspect":
			# 손을 이마에 대고 멀리 살핀다 + 점검 문서
			draw_line(p + Vector2(sx * 4.0, -20.0), p + Vector2(sx * 8.0, -26.0), Color("e8c9a0"), 1.6)
			FastDraw.poly(self, PackedVector2Array([hand + Vector2(-3, 2), hand + Vector2(3, 2), hand + Vector2(3, 7), hand + Vector2(-3, 7)]), Color("efe6c8"))
		"bargain":
			# 엽전이 오가는 흥정
			var cy := -26.0 - absf(sin(t * 3.0)) * 5.0
			FastDraw.circle(self, p + Vector2(sx * 6.0, cy), 1.8, Color("e8c040"))
			FastDraw.circle(self, p + Vector2(sx * 6.0, cy), 0.7, Color("8a6a1a"))
			FastDraw.circle(self, p + Vector2(sx * 11.0, cy + 3.0), 1.4, Color("f2d060"))
		"build":
			# 나무토막 위에 망치질
			var w := p + Vector2(sx * 9.0, -2.0)
			FastDraw.poly(self, PackedVector2Array([w + Vector2(-7, 0), w + Vector2(7, 0), w + Vector2(7, 3), w + Vector2(-7, 3)]), Color("b08a58"))
			var sw := sin(t * 6.0)
			draw_line(hand, w + Vector2(sx * (-2.0 + sw * 2.0), -9.0 - sw * 3.0), Color("5a3a22"), 1.4)
			FastDraw.circle(self, w + Vector2(sx * (-2.0 + sw * 2.0), -9.0 - sw * 3.0), 2.0, Color("3a3a40"))
		"craft":
			# 모루 위에 불꽃
			var an := p + Vector2(sx * 9.0, -2.0)
			FastDraw.poly(self, PackedVector2Array([an + Vector2(-5, 0), an + Vector2(5, 0), an + Vector2(3, -4), an + Vector2(-3, -4)]), Color("3a3e44"))
			if fmod(t, 0.5) < 0.2:
				FastDraw.circle(self, an + Vector2(0, -7), 1.4, Color("ffd060"))
				FastDraw.circle(self, an + Vector2(sx * 3, -9), 0.9, Color("f28a30"))
		"farm":
			# 발치의 새싹과 논두렁을 살피는 모습
			for k in range(3):
				var fx := p + Vector2(sx * (6.0 + float(k) * 3.0), 1.0)
				draw_line(fx, fx + Vector2(-1, -4), Color("4a9a3a"), 1.2)
				draw_line(fx, fx + Vector2(1, -4), Color("6ac04a"), 1.2)
		"speak":
			# 손을 들어 가르치는 몸짓
			var g := sin(t * 2.0) * 2.0
			draw_line(p + Vector2(sx * 4.0, -16.0), p + Vector2(sx * 10.0, -22.0 + g), Color("e8c9a0"), 1.6)
			draw_arc(p + Vector2(sx * 11.0, -22.0 + g), 4.0, -1.0, 1.0, 6, Color(1, 1, 1, 0.5), 1.0)

## [LOD 2: 원거리 조감] 저잣거리 및 주요 거점 군중 마커 렌더링
func _draw_crowd_markers() -> void:
	if grid == null or citizens == null:
		return
	var marker_tex: Texture2D = SpriteCacheManager.get_or_create_texture("vfx", "crowd_marker", Vector2i(32, 32))
	if marker_tex == null:
		return
	var bounds: Rect2 = _get_view_bounds()
	var count: int = 0
	for com_pos: Vector2i in citizens._com_cache:
		if count >= 16:
			break
		if grid.in_bounds(com_pos.x, com_pos.y):
			var elev: float = grid.grid[com_pos.y][com_pos.x].get("elevation", 1.0)
			var cp: Vector2 = city.cell_center(float(com_pos.x) + 0.5, float(com_pos.y) + 0.5, elev)
			if bounds.has_point(cp):
				var m_rect := Rect2(cp.x - 16.0, cp.y - 28.0, 32.0, 32.0)
				draw_texture_rect(marker_tex, m_rect, false)
				count += 1

## PORT-TRACE [건물 뒤 사람 가리기]: 사람을 그린 뒤, 그 사람보다 앞에 선 건물 그림 중 사람과 겹치는 부분만 다시 덮는다
var _occ: Array = []
var _occ_by_tile := {}
var _occ_dirty := true

func _rebuild_occluders() -> void:
	_occ_dirty = false
	_occ = city.collect_occluders()
	_occ_by_tile.clear()
	# 성문이 바뀐 때(새로 짓기·공사 진척·헐기)만 앞 그림을 다시 굽는다
	var gsig := ""
	for o0: Dictionary in _occ:
		if o0.has("gate"):
			var gx0 := int(o0["x0"])
			var gy0 := int(o0["y0"])
			gsig += "%d,%d,%.2f,%s;" % [gx0, gy0, grid.wall_build_fraction(grid.grid[gy0][gx0]), str(grid.grid[gy0][gx0].get("gate_name", ""))]
	if gsig != _gate_sig:
		_gate_sig = gsig
		_gate_bake_needed = true
	for i in range(_occ.size()):
		var o: Dictionary = _occ[i]
		var r: Rect2 = o["rect"]
		var reach: int = int(ceil(r.size.y / 32.0)) + 1
		var fwd := 0
		if o.has("gate"): # 성문은 문길·옹성 안(성 밖·안 양쪽)까지 판정한다
			fwd = int((o["gate"] as Dictionary)["reach"])
		for ty in range(int(o["y0"]) - reach, int(o["y1"]) + 1 + fwd):
			for tx in range(int(o["x0"]) - reach, int(o["x1"]) + 1 + fwd):
				var k := Vector2i(tx, ty)
				if not _occ_by_tile.has(k):
					_occ_by_tile[k] = []
				(_occ_by_tile[k] as Array).append(i)

func _occlude_agent(a: Dictionary) -> void:
	if _occ_dirty:
		_rebuild_occluders()
	var ax: float = float(a["x"])
	var ay: float = float(a["y"])
	var lst: Variant = _occ_by_tile.get(Vector2i(int(floor(ax)), int(floor(ay))), null)
	if lst == null:
		return
	var gx: int = clampi(int(round(ax)), 0, grid.size - 1)
	var gy: int = clampi(int(round(ay)), 0, grid.size - 1)
	var p := city.cell_center(ax, ay, float(grid.grid[gy][gx]["elevation"]))
	p.y -= float((a.get("extra", {}) as Dictionary).get("lift", 0.0))
	var ar := Rect2(p.x - 20.0, p.y - 64.0, 40.0, 68.0)
	var tint: Color = SeasonColorFilter.get_current_tile_tint(city.current_season)
	var painted: Array = [] # 덮어 그린 건물: [앞 깊이, 화면 범위]
	for i: int in lst:
		var o: Dictionary = _occ[i]
		if o.has("gate"):
			_occlude_gate(o, ax, ay, ar)
			continue
		if o.has("paint"):
			# 성벽·포루·공심돈·방화수류정: 그 시설 칸(위를 걷는 군사 포함)이나 앞이면 그대로, 뒤면 구운 앞 그림으로 덮는다
			if ax >= float(o["x1"]) + 1.0 or ay >= float(o["y1"]) + 1.0:
				continue
			if ax >= float(o["x0"]) and ay >= float(o["y0"]):
				continue
			var pr: Rect2 = o["rect"]
			var pit := ar.intersection(pr)
			if pit.size.x <= 0.5 or pit.size.y <= 0.5:
				continue
			var ptex: Texture2D = (_struct_tex.get(o["paint"], {}) as Dictionary).get("tex", null)
			if ptex != null:
				draw_texture_rect_region(ptex, pit, Rect2(pit.position - pr.position, pit.size))
			continue
		# 부지보다 앞(x나 y가 부지 끝을 넘음)이면 사람이 앞, 부지 안(마당)은 그대로 둔다
		if ax >= float(o["x1"]) + 1.0 or ay >= float(o["y1"]) + 1.0:
			continue
		if ax >= float(o["x0"]) and ay >= float(o["y0"]):
			continue
		var r: Rect2 = o["rect"]
		var it := ar.intersection(r)
		if it.size.x <= 0.5 or it.size.y <= 0.5:
			continue
		var tex: Texture2D = city.occluder_texture(o)
		if tex == null:
			continue
		if o.has("bd"): # 지도와 같은 자리(그림 크기가 자리와 다르면 비율 유지)
			r = CityLayer.modern_fit_rect(tex, r)
			it = ar.intersection(r)
			if it.size.x <= 0.5 or it.size.y <= 0.5:
				continue
		painted.append([int(o["x1"]) + int(o["y1"]), it, Vector2i(int(o["x1"]), int(o["y1"])), Vector2i(int(o["x0"]), int(o["y0"]))])
		if o.has("xf"): # 땅에 맞춰 변형해 그린 랜드마크: 같은 변환 아래 그림 좌표로 덮는다
			var xf: Transform2D = o["xf"]
			var inv := xf.affine_inverse()
			var sb := Rect2(inv * it.position, Vector2.ZERO)
			for cq2: Vector2 in [Vector2(it.end.x, it.position.y), Vector2(it.position.x, it.end.y), it.end]:
				sb = sb.expand(inv * cq2)
			sb = sb.intersection(Rect2(Vector2.ZERO, Vector2(tex.get_width(), tex.get_height())))
			if sb.size.x > 0.5 and sb.size.y > 0.5:
				draw_set_transform_matrix(xf)
				draw_texture_rect_region(tex, sb, sb, tint)
				draw_set_transform_matrix(Transform2D.IDENTITY)
			continue
		var sx := float(tex.get_width()) / r.size.x
		var sy := float(tex.get_height()) / r.size.y
		draw_texture_rect_region(tex, it, Rect2((it.position - r.position) * Vector2(sx, sy), it.size * Vector2(sx, sy)), tint)
	# PORT-TRACE [성벽 비침]: 성 뒤 건물로 사람을 덮으면 그 건물 그림이 앞에 선 성벽 위까지 칠해져 성 위 길이 비쳐 보였다 —
	# 덮어 그린 건물보다 앞에 있는 성벽·포루 등의 앞 그림을 그 자리에 다시 덮는다.
	if painted.is_empty():
		return
	var cand := {}
	for i1: int in lst:
		cand[i1] = true
	for pe0: Array in painted:
		for i1b: int in _occ_by_tile.get(pe0[2], []):
			cand[i1b] = true
	for i2: int in cand.keys():
		var so: Dictionary = _occ[i2]
		if not so.has("paint"):
			continue
		var sd := int(so["x1"]) + int(so["y1"])
		var stex: Texture2D = (_struct_tex.get(so["paint"], {}) as Dictionary).get("tex", null)
		if stex == null:
			continue
		var spr: Rect2 = so["rect"]
		for pe: Array in painted:
			if sd <= int(pe[0]):
				continue
			# 성벽이 건물보다 확실히 앞(x나 y로 건물 부지를 넘어섬)일 때만. 대각선 옆 성벽까지 덮으면
			# 성벽 바로 안쪽의 키 큰 근대 건물 지붕 위로 성벽이 비쳐 보였다(사람이 그 앞을 지날 때)
			var b1: Vector2i = pe[2]
			if not (int(so["x0"]) > b1.x or int(so["y0"]) > b1.y):
				continue
			var sit := (pe[1] as Rect2).intersection(spr)
			if sit.size.x > 0.5 and sit.size.y > 0.5:
				draw_texture_rect_region(stex, sit, Rect2(sit.position - spr.position, sit.size))

## PORT-TRACE [문 통과 2중 그림]: 성문 그림을 한 번 더(앞 그림) — 홍예 구멍은 뚫어 둔다. 문 뒤나 문길·옹성 안에 든 사람 위에만
## 덮으면, 문 뒤에선 안 보이고 문길 안에선 홍예 구멍으로만 보이다가 문을 나서면(문 앞쪽) 앞 그림 위로 온전히 보인다.
var _gate_tex := {}          # 성문 칸 → 구운 앞 그림
var _gate_bake_needed := false
var _gate_baking := false
var _gate_baked_season := ""
var _gate_sig := "-"

func _occlude_gate(o: Dictionary, ax: float, ay: float, ar: Rect2) -> void:
	var gi: Dictionary = o["gate"]
	var key := Vector2i(int(o["x0"]), int(o["y0"]))
	var tex: Texture2D = _gate_tex.get(key, null)
	if tex == null:
		return
	var d: Vector2i = gi["out"]
	var v: float = ((ax - float(key.x) - 0.5) * float(d.x) + (ay - float(key.y) - 0.5) * float(d.y)) / (0.5 * float(gi["gs"]))
	if bool(gi["cam_out"]):
		if v > float(gi["front_v"]):
			return
	elif v < float(gi["front_v"]):
		return
	var r: Rect2 = gi["rect"]
	var it := ar.intersection(r)
	if it.size.x <= 0.5 or it.size.y <= 0.5:
		return
	draw_texture_rect_region(tex, it, Rect2(it.position - r.position, it.size))

func _maybe_bake_gates() -> void:
	if _gate_baking:
		return
	if _occ_dirty:
		_rebuild_occluders()
	if not _gate_bake_needed and _gate_baked_season == city.current_season:
		return
	_gate_bake_needed = false
	_gate_baked_season = city.current_season
	_gate_baking = true
	call_deferred("_bake_gates") # 그리는 중에는 노드를 붙일 수 없다

func _bake_gates() -> void:
	_gate_baking = true
	var jobs: Array = []
	for o: Dictionary in _occ:
		if not o.has("gate"):
			continue
		var gi: Dictionary = o["gate"]
		var r: Rect2 = gi["rect"]
		var vp := SubViewport.new()
		vp.transparent_bg = true
		vp.size = Vector2i(ceili(r.size.x), ceili(r.size.y))
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var painter := CityLayer.new()
		painter.auto_redraw = false
		painter.grid = grid
		painter.sim = city.sim
		painter.ref_layer = city.ref_layer
		painter.current_season = city.current_season
		painter.gate_paint_tile = Vector2i(int(o["x0"]), int(o["y0"]))
		painter.position = -r.position
		vp.add_child(painter)
		add_child(vp)
		jobs.append([vp, gi, painter.gate_paint_tile])
	if jobs.is_empty():
		_gate_tex.clear()
		_gate_baking = false
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var fresh := {}
	for jb: Array in jobs:
		var vp2: SubViewport = jb[0]
		var gi2: Dictionary = jb[1]
		var img: Image = vp2.get_texture().get_image()
		vp2.queue_free()
		if img == null or img.is_empty():
			continue
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		var r2: Rect2 = gi2["rect"]
		for hole: PackedVector2Array in gi2["holes"]:
			var loc := PackedVector2Array()
			var mn := Vector2(INF, INF)
			var mx := Vector2(-INF, -INF)
			for q: Vector2 in hole:
				var lq := q - r2.position
				loc.append(lq)
				mn = Vector2(minf(mn.x, lq.x), minf(mn.y, lq.y))
				mx = Vector2(maxf(mx.x, lq.x), maxf(mx.y, lq.y))
			for py in range(maxi(0, int(mn.y)), mini(img.get_height(), int(ceil(mx.y)) + 1)):
				for px in range(maxi(0, int(mn.x)), mini(img.get_width(), int(ceil(mx.x)) + 1)):
					if Geometry2D.is_point_in_polygon(Vector2(px + 0.5, py + 0.5), loc):
						img.set_pixel(px, py, Color(0, 0, 0, 0))
		fresh[jb[2]] = ImageTexture.create_from_image(img)
	_gate_tex = fresh
	_gate_baking = false
	queue_redraw()

## PORT-TRACE [성곽·군사시설 앞 그림]: 사용자 요청 — "건물 뒤에 있는 사람은 가려져야 입체감이 산다". 코드로 그리는 성벽·포루·공심돈·
## 방화수류정은 그림 파일이 없어 가림막이 없었다 → 시설 하나씩 작은 SubViewport에 따로 그려 구워 두고(바뀐 것만 다시), 뒤에 선 사람 위에 덮는다.
var _struct_tex := {} # 칸 → {sig, tex}
var _struct_baking := false

func _maybe_bake_structs() -> void:
	if _struct_baking:
		return
	if _occ_dirty:
		_rebuild_occluders()
	for o: Dictionary in _occ:
		if o.has("paint") and String((_struct_tex.get(o["paint"], {}) as Dictionary).get("sig", "")) != String(o["psig"]):
			# PORT-TRACE [렉: 계절 바뀌는 달 멈칫]: 굽기 한 묶음도 무거운 일 차례를 받아서(턴 계산·가림막·지도 굽기와 겹치지 않게)
			if not GameGrid.frame_claim():
				return # 다음 그리기 때 다시
			_struct_baking = true
			call_deferred("_bake_structs")
			return

func _bake_structs() -> void:
	var jobs: Array = []
	var live := {}
	for o: Dictionary in _occ:
		if not o.has("paint"):
			continue
		live[o["paint"]] = true
		if String((_struct_tex.get(o["paint"], {}) as Dictionary).get("sig", "")) == String(o["psig"]):
			continue
		var r: Rect2 = o["rect"]
		var vp := SubViewport.new()
		vp.transparent_bg = true
		vp.size = Vector2i(maxi(1, ceili(r.size.x)), maxi(1, ceili(r.size.y)))
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var painter := CityLayer.new()
		painter.auto_redraw = false
		painter.grid = grid
		painter.sim = city.sim
		painter.ref_layer = city.ref_layer
		painter.current_season = city.current_season
		painter.struct_paint_tile = o["paint"]
		painter.position = -r.position
		vp.add_child(painter)
		add_child(vp)
		jobs.append([vp, o["paint"], o["psig"]])
		if jobs.size() >= 16:
			break # 한 번에 너무 많이 굽지 않게(나머지는 다음 차례) — 48개씩이면 만들기·그리기·읽어오기가 각 30~50ms로 멈칫했다
	for k in _struct_tex.keys():
		if not live.has(k):
			_struct_tex.erase(k)
	if not jobs.is_empty():
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		for jb: Array in jobs:
			var vp2: SubViewport = jb[0]
			var img: Image = vp2.get_texture().get_image()
			vp2.queue_free()
			if img == null or img.is_empty():
				continue
			_struct_tex[jb[1]] = {"sig": jb[2], "tex": ImageTexture.create_from_image(img)}
	_struct_baking = false
	queue_redraw()

## (예전) 성문 뒤나 문길(성문 칸) 안에 든 사람은 그리지 않았다 — 지금은 앞 그림으로 덮는다
func _hidden_by_gate(a: Dictionary) -> bool:
	if _occ_dirty:
		_rebuild_occluders()
	var ax: float = float(a["x"])
	var ay: float = float(a["y"])
	var lst: Variant = _occ_by_tile.get(Vector2i(int(floor(ax)), int(floor(ay))), null)
	if lst == null:
		return false
	var p := city.cell_center(ax, ay, 1.0)
	for i: int in lst:
		var o: Dictionary = _occ[i]
		if not o.has("hide"):
			continue
		if ax >= float(o["x1"]) + 1.0 or ay >= float(o["y1"]) + 1.0:
			continue
		if (o["rect"] as Rect2).has_point(p):
			return true
	return false

## PORT-TRACE [건물 위 장인]: 일하는 중(work·rest)인 직업인(장인·백정·의원·아전 등)이 건물 칸에 서 있으면 건물 안에 있는 셈 —
## 지붕 위에 그리지 않는다(길로 나서면 다시 보임). 공방 자리 장인(is_spot)은 공방 앞 장면 인물이 대신 보여 준다.
func _agent_indoors(a: Dictionary) -> bool:
	if bool(a.get("inside", false)):
		return true # 행궁·관아 안에 들어가 일하는 중
	var t := String(a.get("type", ""))
	if bool(a.get("is_spot", false)) and t == "artisan":
		return true
	if int(a.get("job_type", 0)) != 0 and String(a.get("state", "")) in ["work", "rest"]:
		var tx := clampi(int(floor(float(a["x"]))), 0, grid.size - 1)
		var ty := clampi(int(floor(float(a["y"]))), 0, grid.size - 1)
		var tt: Dictionary = grid.grid[ty][tx]
		return not (String(tt["building"]) in ["", "road"]) and not tt.has("plaza")
	return false

## PORT-TRACE [거리 사람들의 정체성]: 취객 — 비틀(좌우로 기우뚱)·쓰러짐(길에 누워 코 고는 김)·부축(이웃 쪽으로 기댐)
func _draw_drunkard(p: Vector2, a: Dictionary) -> void:
	var st := String(a.get("state", ""))
	var t := float(a.get("anim", 0.0))
	if st == "fallen":
		var side := 1.0 if int(a.get("id", 0)) % 2 == 0 else -1.0
		_sheet_lying(p + Vector2(0, -3), "npc_drunkard" if NpcSprites._has_sheet("npc_drunkard") else "npc_cheonmin", PI * 0.5 * side)
		var zt := fmod(t * 0.25, 1.0)
		draw_string(ThemeDB.fallback_font, p + Vector2(4.0 + zt * 4.0, -10.0 - zt * 10.0), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1, 1.0 - zt))
		return
	var lean := sin(t * 0.45) * 0.24 if st == "stagger" else 0.32 * (1.0 if int(a.get("id", 0)) % 2 == 0 else -1.0)
	var keep := NpcSprites.base_xf
	NpcSprites.base_xf = keep * Transform2D(lean, Vector2.ONE, 0.0, p)
	draw_set_transform_matrix(NpcSprites.base_xf)
	NpcSprites.draw_agent(self, Vector2.ZERO, "drunkard", a, current_season == "겨울")
	NpcSprites.base_xf = keep
	draw_set_transform_matrix(keep)

## 에이전트를 발밑 기준으로 줄여 그리는 동안(NpcSprites.base_xf), 화면의 실제 지점 w를 그 좌표계로 — 물줄기·밧줄 끝이 진짜 불·물에 닿게
func _world_in_agent(_feet: Vector2, w: Vector2) -> Vector2:
	return NpcSprites.base_xf.affine_inverse() * w

func _draw_agent(a: Dictionary) -> void:
	if _agent_indoors(a):
		return
	# PORT-TRACE [크기 통일 2]: 어른 에이전트는 발밑을 기준으로 그림 전체(몸·소품·말·짐)를 BODY_K배로 줄여 그린다(아이는 그대로)
	var sk := NpcSprites.kind_for(String(a.get("type", "")), int(a.get("id", 0)))
	if sk.begins_with("child"):
		_draw_agent_body(a)
	else:
		var gx: int = clampi(int(round(float(a["x"]))), 0, grid.size - 1)
		var gy: int = clampi(int(round(float(a["y"]))), 0, grid.size - 1)
		var feet := city.cell_center(float(a["x"]), float(a["y"]), float(grid.grid[gy][gx]["elevation"]))
		var k := NpcSprites.BODY_K
		NpcSprites.base_xf = Transform2D(0.0, Vector2(k, k), 0.0, feet * (1.0 - k))
		NpcSprites.body_k = 1.0
		draw_set_transform_matrix(NpcSprites.base_xf)
		_draw_agent_body(a)
		NpcSprites.base_xf = Transform2D.IDENTITY
		NpcSprites.body_k = NpcSprites.BODY_K
		draw_set_transform_matrix(Transform2D.IDENTITY)
	if not bool(a.get("is_hidden_shelter", false)):
		_occlude_agent(a)

func _draw_agent_body(a: Dictionary) -> void:
	var gx: int = clampi(int(round(float(a["x"]))), 0, grid.size - 1)
	var gy: int = clampi(int(round(float(a["y"]))), 0, grid.size - 1)
	var elev: float = grid.grid[gy][gx]["elevation"] if grid.in_bounds(gx, gy) else 0.0
	var p := city.cell_center(float(a["x"]), float(a["y"]), elev)
	p.y -= float((a.get("extra", {}) as Dictionary).get("lift", 0.0)) # 제방 위 낚시꾼 등
	var atype: String = a.get("type", "carrier")

	if atype == "drunkard" and a.get("street_folk", false):
		_draw_drunkard(p, a)
		return

	# PORT-TRACE [NPC 도트 스프라이트 1단계]: 백성·짐꾼·상인·군졸·선비·관리는 코드로 구운 도트 스프라이트(NpcSprites)로
	var sk := NpcSprites.kind_for(atype, int(a.get("id", 0)))
	if sk != "":
		NpcSprites.draw_agent(self, p, sk, a, current_season == "겨울")
		return

	# 네임드 캐릭터 26인 우선 검사 및 48x48 고품질 렌더링
	if atype.begins_with("named_"):
		var nid: String = String(a.get("named_id", atype))
		if NamedNpcs.has(nid):
			_draw_named_extra(p, a)
			return
		match atype:
			"named_jeong_yakyong":
				_draw_named_jeong_yakyong(p, a)
				return
			"named_chae_jegong":
				_draw_named_chae_jegong(p, a)
				return
			"named_jo_simtae":
				_draw_named_jo_simtae(p, a)
				return
			"named_kim_hongdo":
				_draw_named_kim_hongdo(p, a)
				return
			"named_kim_bau":
				_draw_named_kim_bau(p, a)
				return
			"named_gu_seonbok":
				_draw_named_gu_seonbok(p, a)
				return
			"named_yu_hanji":
				_draw_named_yu_hanji(p, a)
				return
			_:
				var ntex: Texture2D = SpriteCacheManager.get_named_character_texture(nid)
				if ntex != null:
					var dir: int = _sdir(a)
					var frame: int = int(float(a.get("anim", 0.0))) % 4
					var alpha: float = float(a.get("fade_alpha", 1.0))
					_draw_character_sprite_48x48(p, ntex, dir, frame, alpha)
					return

	match atype:
		# 건설 장비 및 특수 일상
		"geojunggi":
			_draw_geojunggi(p, a)
		"nongno":
			_draw_nongno(p, a)
		"yuheonggeo":
			_draw_yuheonggeo(p)
		"mason":
			_draw_mason(p, a)
		"foreman":
			_draw_foreman(p, a)
		"fisher":
			_draw_fisher(p, a)
		"kite_flyer":
			_draw_kite_flyer(p, a)
		"washer":
			_draw_washer(p, a)
		"water_play":
			_draw_water_play(p, a)
		"drowning":
			_draw_drowning(p, a)
		"ice_sled":
			_draw_ice_sled(p, a)
		"ice_fisher":
			_draw_ice_fisher(p, a)
		"catholic":
			_draw_catholic(p, a)
		"horse_messenger":
			_draw_horse_messenger(p, a)
		"scholar":
			_draw_scholar(p, a)
		"official":
			_draw_official(p, a)
		"palanquin":
			_draw_palanquin(p, a)
		"cart":
			_draw_cart(p, a)
		"woodcutter":
			_draw_woodcutter(p, a)
		"shopper":
			_draw_shopper(p, a)
		"deer":
			_draw_wild_deer(p, a)
		"crane":
			_draw_wild_crane(p, a)
		"wild_boar":
			_draw_wild_boar(p, a)
		"rabbit":
			_draw_wild_rabbit(p, a)
		"hunter":
			_draw_hunter(p, a)
		"wolf":
			_draw_wild_wolf(p, a)
		"tiger":
			_draw_wild_tiger(p, a)
		"chakhogapsa":
			_draw_chakhogapsa(p, a)
		"beater":
			_draw_beater(p, a)
		"marksman":
			_draw_marksman(p, a)
		"bait":
			_draw_bait(p, a)
		"bandit":
			_draw_bandit(p, a)
		"patrol_soldier":
			_draw_patrol_soldier(p, a)
		"criminal_npc":
			_draw_criminal_npc(p, a)
		"jangyongyeong_soldier":
			_draw_jangyongyeong_soldier(p, a)
		"firefighter_soldier":
			_draw_firefighter_soldier(p, a)
		"bucket_volunteer":
			_draw_bucket_volunteer(p, a)
		"flood_sandbag":
			_draw_flood_sandbag(p, a)
		"flood_refugee":
			_draw_flood_refugee(p, a)
		"shopkeeper":
			_draw_shopkeeper(p, a)
		"jungin", "physician":
			_draw_jungin(p, a)
		"ajeon", "ajeoun":
			_draw_ajeon(p, a)
		"artisan", "artisan_master":
			_draw_artisan(p, a)
		"monk_soldier":
			_draw_monk_soldier(p, a)
		"butcher":
			_draw_butcher(p, a)
		"porter":
			_draw_porter(p, a)
		"pungmul_band":
			_draw_pungmul_band(p, a)
		"bull_parade":
			_draw_bull_parade(p, a)
		"stretcher":
			_draw_stretcher(p, a)
		"ox_plow":
			_draw_ox_plow(p, a)
		"farmer_cart":
			_draw_farmer_cart(p, a)
		"scarecrow":
			_draw_scarecrow(p, a)
		"sparrow_flock":
			_draw_sparrow_flock(p, a)
		"farmer":
			_draw_farmer_life(p, a)
		# 사대문 운반꾼
		"official_rider":
			_draw_official_rider(p, a)
		"book_peddler":
			_draw_bundle_walker(p, a, Color("f2eee4"), Color("2e4a7a"), true)
		"gov_cart":
			_draw_ox_cart(p, a, "gov")
		"ox_driver":
			_draw_ox_driver(p, a)
		"grain_cart":
			_draw_ox_cart(p, a, "grain")
		"bobusang":
			_draw_bobusang(p, a)
		"salt_porter":
			_draw_jige_porter(p, a, "salt")
		"fish_peddler":
			_draw_fish_peddler(p, a)
		"wood_cart":
			_draw_ox_cart(p, a, "wood")
		"simmani":
			_draw_simmani(p, a)
		"prisoner_escort":
			_draw_prisoner_escort(p, a)
		"saposu":
			_draw_saposu(p, a)
		"yusaeng":
			_draw_yusaeng(p, a)
		"rebel":
			_draw_rebel(p, a)
		"horde":
			_draw_horde(p, a)
		"militia":
			_draw_militia(p, a)
		"supply_carrier":
			_draw_supply_carrier(p, a)
		"traitor":
			_draw_traitor(p, a)
		"posu":
			_draw_posu(p, a)
		"sasu":
			_draw_sasu(p, a)
		"salsu":
			_draw_salsu(p, a)
		"gipo":
			_draw_gipo(p, a)

		# 기본 아틀라스 텍스처
		"carrier", "merchant", "guard":
			var char_row: int = CHAR_ROWS.get(atype, 0)
			var frame: int = int(a.get("anim", 0.0)) % 4
			var src_rect := Rect2(frame * 32, char_row * 32, 32, 32)
			var dest_rect := Rect2(p.x - 16.0, p.y - 24.0, 32.0, 32.0)
			if tex_characters != null:
				draw_texture_rect_region(tex_characters, dest_rect, src_rect)
			else:
				_spr(p, atype, a)

			# 계절별 복식 악세서리 (겨울 방한모/목도리/입김, 여름 삿갓)
			if current_season == "겨울":
				FastDraw.circle(self, p + Vector2(0, -23), 2.2, Color("1c1917"))
				draw_line(p + Vector2(-3, -22), p + Vector2(-2, -16), Color("2b1e16"), 1.2)
				draw_line(p + Vector2(3, -22), p + Vector2(2, -16), Color("2b1e16"), 1.2)
				draw_line(p + Vector2(-4, -13), p + Vector2(4, -13), Color("5c4033"), 1.8)
				var breath_anim: float = sin(float(a.get("anim", 0.0)) * 3.0)
				if breath_anim > 0.4:
					FastDraw.circle(self, p + Vector2(4.5 + breath_anim * 1.5, -15.0 - breath_anim), 1.0, Color(1, 1, 1, 0.65))
			elif current_season == "여름" and atype in ["carrier", "farmer"]:
				draw_line(p + Vector2(-7, -22), p + Vector2(7, -22), Color("8c6d46"), 1.8)
				FastDraw.poly(self, PackedVector2Array([
					p + Vector2(-6, -22), p + Vector2(6, -22), p + Vector2(0, -26)
				]), Color("a6845c"))
		_:
			_spr(p, NpcSprites.CROWD[absi(int(a.get("id", 0))) % NpcSprites.CROWD.size()], a) # 이름 없는 종류는 거리 백성 도트로

# ============================================================ 네임드 NPC 7인 전용 렌더러

## 1. 정약용 (실학자·수원화성 설계자 - 제도 탁자 및 설계도 검토)
func _draw_named_jeong_yakyong(p: Vector2, a: Dictionary) -> void:
	# 제도 탁자 앞에 선 정약용(옥색 도포·흑립), 붓으로 성곽 도면을 짚는다
	var r_pos := p + Vector2(8, 0)
	var dir := _sdir(a)
	var frame: int = int(float(a.get("anim", 0.0))) % 4
	var alpha: float = float(a.get("fade_alpha", 1.0))
	var tex := SpriteCacheManager.get_named_character_texture("named_jeong_yakyong")
	if tex != null:
		_draw_character_sprite_48x48(r_pos, tex, dir, frame, alpha)
	else:
		_spr(r_pos, "named_jy", a, 0, 1, 0)
	_scholar_desk(p + Vector2(-4, 0), Color("5c3a1d"), true)
	draw_line(r_pos + Vector2(-5, -7), r_pos + Vector2(-10, -9), Color("382313"), 1.4) # 붓

## 탁자(서안) + 펼친 종이. plan이면 붉은 성곽 도면, 아니면 굵은 예서 묵서
func _scholar_desk(c: Vector2, wood: Color, plan: bool) -> void:
	FastDraw.poly(self, PackedVector2Array([c + Vector2(-11, -6), c + Vector2(5, -6), c + Vector2(9, -13), c + Vector2(-7, -13)]), wood)
	FastDraw.poly(self, PackedVector2Array([c + Vector2(-11, -6), c + Vector2(5, -6), c + Vector2(5, -4), c + Vector2(-11, -4)]), wood.darkened(0.3))
	draw_line(c + Vector2(-10, -4), c + Vector2(-10, 1), wood.darkened(0.4), 2.0)
	draw_line(c + Vector2(4, -4), c + Vector2(4, 1), wood.darkened(0.4), 2.0)
	FastDraw.poly(self, PackedVector2Array([c + Vector2(-8, -7.5), c + Vector2(2, -7.5), c + Vector2(5, -12), c + Vector2(-5, -12)]), Color("faf6ed"))
	if plan:
		FastDraw.polyline(self, PackedVector2Array([c + Vector2(-6, -8.5), c + Vector2(-3, -11), c + Vector2(2, -11), c + Vector2(1, -8.5), c + Vector2(-6, -8.5)]), Color("b02e2e"), 1.0)
	else:
		draw_line(c + Vector2(-5, -9), c + Vector2(-1, -9), Color("111111"), 1.8)
		draw_line(c + Vector2(-3, -10.5), c + Vector2(-3, -8), Color("111111"), 1.4)

## 2. 체제공 (영의정·화성성역 총리사 - 4인 가마 및 화려한 관복)
func _draw_named_chae_jegong(p: Vector2, a: Dictionary) -> void:
	var dir := _sdir(a)
	var sx := _ssx(dir)
	var d2 := 0 if sx > 0 else 1
	_draw_oval_shadow(p + Vector2(0, 1), 22.0, 6.0, Color(0, 0, 0, 0.26))
	# 뒷줄 가마꾼 둘 → 가마 → 앞줄 가마꾼 둘(가마채를 어깨에)
	for off: Vector2 in [Vector2(-15, -3), Vector2(13, -3)]:
		_spr(p + off, "bearer", a, 0, d2)
	draw_line(p + Vector2(-22, -16), p + Vector2(22, -16), Color("5c3a1c"), 2.4) # 가마채
	FastDraw.poly(self, PackedVector2Array([p + Vector2(-9, -8), p + Vector2(9, -8), p + Vector2(9, -26), p + Vector2(-9, -26)]), Color("8f1d1d"))
	FastDraw.poly(self, PackedVector2Array([p + Vector2(9, -8), p + Vector2(12, -10), p + Vector2(12, -27), p + Vector2(9, -26)]), Color("6a1414"))
	FastDraw.poly(self, PackedVector2Array([p + Vector2(-12, -26), p + Vector2(14, -26), p + Vector2(1, -33)]), Color("141414")) # 흑칠 지붕
	draw_rect(Rect2(p + Vector2(-4, -21), Vector2(8, 8)), Color("d4af37")) # 황금빛 창
	draw_rect(Rect2(p + Vector2(-3, -20), Vector2(6, 6)), Color("5a1010"))
	# 가마 창문 안 채제공 48x48 컷
	var c_tex := SpriteCacheManager.get_named_character_texture("named_chae_jegong", true)
	if c_tex != null:
		var c_dest := Rect2(p.x - 7.0, p.y - 25.0, 14.0, 14.0)
		var c_src := Rect2(17.0, 9.0, 14.0, 14.0)
		draw_texture_rect_region(c_tex, c_dest, c_src, Color.WHITE)
	for off2: Vector2 in [Vector2(-18, 2), Vector2(17, 2)]:
		_spr(p + off2, "bearer", a, 1, d2)

## 3. 조심태 (수원부사·화성 감동당상 - 백마/적갈마를 타고 순시)
func _draw_named_jo_simtae(p: Vector2, a: Dictionary) -> void:
	var sx := _ssx(_sdir(a))
	_draw_horse(p, a, sx, Color("ededed"), Color("b0b0b0"))
	# PORT-TRACE [조심태 말]: 예전엔 4칸짜리처럼 칸 0~3을 읽어(시트는 2칸) 반은 빈 칸이 찍혀 깜빡였고, 줄도 반대로 골라 거꾸로 탔다
	var jdir := _gdir_of(a, sx)
	if not NpcSprites.sheet_for("named_jo_simtae").is_empty():
		_draw_rider(p + Vector2(-1 * sx, -23), "named_jo_simtae", jdir)
	else:
		_draw_rider(p + Vector2(-1 * sx, -23), "official", jdir)

## PORT-TRACE [말 탄 사람 하체]: 말 위 사람은 허리 위만 잘라 그려 하체가 투명하게 비어 보였다 → 허리 아래 다리 한쪽(시트에서 반쪽 폭)을
## 말 옆구리로 내려뜨려 걸터앉은 모습으로. seat = 허리(안장) 자리
## PORT-TRACE [말 탄 사람 엉덩이]: 사용자 요청 — "뒷모습은 허리에서 자르면 공중에 뜬 것 같다, 엉덩이까지 남겨라".
## 몸은 엉덩이까지(48칸 시트 위 35줄) 안장에 붙이고, 그 아래로 바라보는 쪽 다리를 말 옆구리에 늘어뜨린다(모든 방향).
func _draw_rider(seat: Vector2, kind: String, dir: int) -> void:
	var sh := NpcSprites.sheet_for(kind)
	var sc := 1.0
	var leg := Callable()
	if not sh.is_empty():
		var tex: Texture2D = sh[0]
		sc = NpcSprites.adult_k(NpcSprites.NAMED_SCALE if bool(sh[1]) else (0.52 if bool(sh[2]) else 0.70))
		var row: int = [1, 0, 3, 2][clampi(dir, 0, 3)]
		# 말 옆구리 중 보이는 쪽 다리(사람 기준): 오른쪽 아래(0)·오른쪽 위(2)는 오른다리, 왼쪽 아래(1)·왼쪽 위(3)는 왼다리.
		# 48칸 시트에서 앞모습은 오른다리가 그림 왼쪽(15), 뒷모습은 오른다리가 그림 오른쪽(24)에 있다.
		var hx: float = [15.0, 24.0, 24.0, 15.0][clampi(dir, 0, 3)]
		leg = func() -> void:
			draw_texture_rect_region(tex, Rect2(seat.x + (hx - 24.0) * sc, seat.y + 2.0 * sc, 9.0 * sc, 9.0 * sc), Rect2(hx, float(row) * 48.0 + 34.0, 9.0, 9.0))
	var back := dir >= 2
	if back and leg.is_valid():
		leg.call() # 뒷모습: 다리는 엉덩이 뒤로 살짝 보이게 먼저
	# PORT-TRACE [말 탄 몸통]: 투구·수염이 큰 군졸 그림은 35줄로 자르면 허리 아래가 거의 없어 말 위에서 몸이 끊겨 보였다 — 허벅지(40줄)까지 남겨 말 등에 걸친다
	NpcSprites.draw_upper(self, seat + Vector2(0, 6.0 * sc), kind, 0, current_season == "겨울", dir, 27, 0, "", 1.0, 40.0)
	if not back and leg.is_valid():
		leg.call()

## 말: 몸통·목·머리·꼬리·네 다리(걸음). sx = 바라보는 쪽
func _draw_horse(p: Vector2, a: Dictionary, sx: float, col: Color, _mane: Color) -> void:
	AnimalSprites.draw_dir(self, p, "horse", int(float(a.get("anim", 0.0)) * 4.0), _gdir_of(a, sx), col)

## 에이전트가 가는 격자 방향(0~3) — dir 벡터가 없으면 좌우(sx)로
func _gdir_of(a: Dictionary, sx: float) -> int:
	if a.has("dir") and (a["dir"] is Vector2 or a["dir"] is Vector2i):
		return NpcSprites.dir_of(a)
	return 0 if sx > 0.0 else 1

## 격자 방향 → 화면에서 앞으로 나아가는 단위 벡터(마름모 대각선)
func _scr_fwd(dir: int) -> Vector2:
	match dir:
		0: return Vector2(32, 16).normalized()
		1: return Vector2(-32, 16).normalized()
		2: return Vector2(32, -16).normalized()
	return Vector2(-32, -16).normalized()

## 4. 김홍도 (도화서 화원·단원 - 돗자리 펴고 풍속화 그리기)
func _draw_named_kim_hongdo(p: Vector2, _a: Dictionary) -> void:
	# PORT-TRACE [김홍도 그림 그리기]: 사용자 요청 — "좌우를 계속 바꾸고, 들고 다니는 게 전혀 그림 같지 않다".
	# 왕골 돗자리를 깔고 그 위에 펼친 화지(먹선 산·소나무·인물 둘에 옅은 담채) 앞에 앉아(늘 종이 쪽을 봄) 붓을 놀린다. 곁에 벼루와 붓통.
	var t := _scene_t
	var m := p + Vector2(-3, 0)
	var mat := PackedVector2Array([m + Vector2(-15, 0), m + Vector2(0, -7.5), m + Vector2(15, 0), m + Vector2(0, 7.5)])
	FastDraw.poly(self, mat, Color("c9ad6e"))
	for k in range(1, 6):
		var f := float(k) / 6.0
		draw_line(mat[0].lerp(mat[1], f), mat[3].lerp(mat[2], f), Color("b39552"), 0.5) # 돗자리 결
	FastDraw.polyline(self, PackedVector2Array(Array(mat) + [mat[0]]), Color("7a5f30"), 0.8)
	var pc := m + Vector2(-3, -0.5)
	if not GoodsArt.draw(self, pc + Vector2(0, 4), "painting_sheet", 0.6):
		var paper := PackedVector2Array([pc + Vector2(-8, 0), pc + Vector2(0, -4), pc + Vector2(8, 0), pc + Vector2(0, 4)])
		FastDraw.poly(self, paper, Color("f3eddd"))
		FastDraw.polyline(self, PackedVector2Array(Array(paper) + [paper[0]]), Color("b8ab8a"), 0.5)
		# 먹선 산 두 봉우리 + 소나무 + 사람 둘(풍속화 밑그림)과 옅은 담채
		draw_line(pc + Vector2(-5.5, -0.5), pc + Vector2(-3.5, -2.6), Color(0.15, 0.13, 0.12, 0.8), 0.6)
		draw_line(pc + Vector2(-3.5, -2.6), pc + Vector2(-1.5, -0.8), Color(0.15, 0.13, 0.12, 0.8), 0.6)
		draw_line(pc + Vector2(-2.5, -1.2), pc + Vector2(-0.8, -2.4), Color(0.3, 0.28, 0.26, 0.6), 0.5)
		FastDraw.circle(self, pc + Vector2(-4.2, -1.2), 0.9, Color(0.45, 0.6, 0.4, 0.7)) # 담채 녹색
		FastDraw.circle(self, pc + Vector2(2.2, -0.6), 0.6, Color(0.15, 0.12, 0.1))
		draw_line(pc + Vector2(2.2, -0.2), pc + Vector2(2.2, 1.2), Color(0.15, 0.12, 0.1), 0.6)
		FastDraw.circle(self, pc + Vector2(4.0, -0.2), 0.6, Color(0.15, 0.12, 0.1))
		draw_line(pc + Vector2(4.0, 0.2), pc + Vector2(4.0, 1.6), Color(0.15, 0.12, 0.1), 0.6)
		FastDraw.circle(self, pc + Vector2(3.1, 1.0), 0.7, Color(0.75, 0.45, 0.35, 0.7)) # 담채 주홍
	# 벼루·먹·붓통
	var ink := m + Vector2(-11, 1)
	FastDraw.poly(self, PackedVector2Array([ink + Vector2(-2.5, 0), ink + Vector2(0, -1.3), ink + Vector2(2.5, 0), ink + Vector2(0, 1.3)]), Color("2c2a2a"))
	FastDraw.circle(self, ink + Vector2(0.3, -0.2), 0.8, Color("0e0d0d"))
	draw_line(ink + Vector2(4, 0), ink + Vector2(4, -4), Color("6a4a2a"), 1.6) # 붓통
	draw_line(ink + Vector2(3.6, -4), ink + Vector2(3.2, -6.5), Color("8a6a3a"), 0.6)
	draw_line(ink + Vector2(4.4, -4), ink + Vector2(4.9, -6.2), Color("8a6a3a"), 0.6)
	# 김홍도: 종이 오른쪽 앞에 앉아 왼쪽(종이)을 바라보며
	var kp := pc + Vector2(10, 3)
	_spr_seat(kp, "named_kim_hongdo", 1, Color("e9e2cf"))
	var tip := pc + Vector2(1.0 + sin(t * 1.7) * 2.0, -0.5 + cos(t * 2.3) * 0.8)
	draw_line(kp + Vector2(-4, -10) * _sk(), tip, Color("4a3020"), 0.9) # 붓대
	FastDraw.circle(self, tip, 0.6, Color("111111"))

## 5. 석수 김바우 (수원화성 수석 석공 명장 - 화강암 용머리 조각)
func _draw_named_kim_bau(p: Vector2, a: Dictionary) -> void:
	# 깎고 있는 화강암 용머리
	var sd := p + Vector2(-8, 0)
	FastDraw.poly(self, PackedVector2Array([sd + Vector2(-6, 0), sd + Vector2(5, 0), sd + Vector2(6, -14), sd + Vector2(-5, -15)]), Color("9e988e"))
	FastDraw.poly(self, PackedVector2Array([sd + Vector2(5, 0), sd + Vector2(8, -2), sd + Vector2(9, -15), sd + Vector2(6, -14)]), Color("7e786e"))
	draw_line(sd + Vector2(-4, -11), sd + Vector2(3, -8), Color("4a453e"), 1.4) # 용 뿔·수염 음각
	FastDraw.circle(self, sd + Vector2(0, -12), 1.2, Color("4a453e"))
	var b_pos := p + Vector2(7, 0)
	var tex := SpriteCacheManager.get_named_character_texture("named_kim_bau")
	if tex != null:
		var dir := _sdir(a)
		var frame := int(float(a.get("anim", 0.0))) % 4
		_draw_character_sprite_48x48(b_pos, tex, dir, frame, float(a.get("fade_alpha", 1.0)))
	else:
		_spr(b_pos, "named_bau", a, 0, 1, 0)
	var hand := b_pos + Vector2(-4.5, -7)
	var ham_y := -13.0 + sin(float((a.get("extra", {}) as Dictionary).get("hammer_anim", 0.0)) * TAU) * 4.0
	draw_line(hand + Vector2(-1, 1), hand + Vector2(-5, 2), Color("736b63"), 1.6) # 정
	draw_line(hand, b_pos + Vector2(-3, ham_y), Color("423225"), 1.8)
	FastDraw.circle(self, b_pos + Vector2(-3, ham_y), 2.4, Color("211e1c")) # 쇠망치

## 6. 구선복 (훈련대장·장용영 군사 지휘관 - 철갑 투구와 대도)
func _draw_named_gu_seonbok(p: Vector2, a: Dictionary) -> void:
	var dir := _sdir(a)
	var sx := _ssx(dir)
	var pole := p + Vector2(6 * sx, 0)
	draw_line(pole + Vector2(0, -6), pole + Vector2(0, -38), Color("3d2916"), 1.6) # 깃대
	FastDraw.poly(self, PackedVector2Array([pole + Vector2(0, -38), pole + Vector2(11 * sx, -34), pole + Vector2(0, -29)]), Color("d48e1c")) # 장용영 영기
	var tex := SpriteCacheManager.get_named_character_texture("named_gu_seon_bok")
	if tex != null:
		var frame := int(float(a.get("anim", 0.0))) % 4
		_draw_character_sprite_48x48(p, tex, dir, frame, float(a.get("fade_alpha", 1.0)))
	else:
		_spr(p, "general", a)
	draw_line(p + Vector2(-5 * sx, -10), p + Vector2(-9 * sx, -2), Color("8a847b"), 2.2) # 환도

## 7. 유한지 (조선 최고의 예서 명필 - 서안에서 대형 붓으로 휘호)
func _draw_named_yu_hanji(p: Vector2, a: Dictionary) -> void:
	var u_pos := p + Vector2(8, 0)
	var dir := _sdir(a)
	var frame: int = int(float(a.get("anim", 0.0))) % 4
	var alpha: float = float(a.get("fade_alpha", 1.0))
	var tex := SpriteCacheManager.get_named_character_texture("named_yu_hanji")
	if tex != null:
		_draw_character_sprite_48x48(u_pos, tex, dir, frame, alpha)
	else:
		_spr(u_pos, "named_yu", a, 0, 1, 0)
	_scholar_desk(p + Vector2(-4, 0), Color("4a2d14"), false)
	draw_line(u_pos + Vector2(-5, -7), u_pos + Vector2(-10, -9), Color("261a10"), 2.0) # 대형 붓

# ============================================================ 말풍선 (Speech Bubble) 렌더러
## 말풍선은 화면을 충분히 확대했을 때(카메라 배율 BUBBLE_MIN_ZOOM 이상 — 배율 범위 0.5~2.5의 절반 지점)만, 그리고 지금 화면에 보이는 인물에게만 띄운다.
## PORT-TRACE [말풍선 위 NPC]: 그리기 도중 나온 말풍선은 모아 두었다가 사람을 다 그린 뒤 맨 위에 그린다
var _bubble_queue: Array = []
var _bubble_defer := false

func _draw_speech_bubble(p: Vector2, text: String, name_tag: String, is_special_bubble: bool = false) -> void:
	if text.strip_edges() == "":
		return
	if _bubble_defer:
		_bubble_queue.append([p, text, name_tag, is_special_bubble])
		return
	if not is_special_bubble:
		var visible_tiles: int = citizens.get_visible_tile_count() if citizens != null else 300
		if visible_tiles > CitizenManager.TILE_LIMIT_BUBBLE_VISIBLE:
			return
	if not _get_view_bounds().has_point(p):
		return

	var font_size: int = 12
	var text_w: float = font_neodgm.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var tag_w: float = font_neodgm.get_string_size(name_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if name_tag != "" else 0.0
	var box_w: float = maxf(text_w + 16.0, tag_w + 24.0)
	var box_h: float = 30.0

	var bx: float = p.x - box_w * 0.5
	var by: float = p.y - 42.0

	# 그림자
	FastDraw.poly(self, PackedVector2Array([
		Vector2(bx + 2, by + 2), Vector2(bx + box_w + 2, by + 2),
		Vector2(bx + box_w + 2, by + box_h + 2), Vector2(bx + 2, by + box_h + 2)
	]), Color(0.0, 0.0, 0.0, 0.30))

	# 크림색 한지 말풍선 본체
	var bubble_poly := PackedVector2Array([
		Vector2(bx, by), Vector2(bx + box_w, by),
		Vector2(bx + box_w, by + box_h), Vector2(bx, by + box_h)
	])
	FastDraw.poly(self, bubble_poly, Color("fffdf5"))
	FastDraw.polyline(self, PackedVector2Array(bubble_poly + PackedVector2Array([bubble_poly[0]])), Color("3d2817"), 1.5)

	# 하단 말풍선 꼬리표
	var tail_pts := PackedVector2Array([
		Vector2(p.x - 4, by + box_h),
		Vector2(p.x + 4, by + box_h),
		Vector2(p.x, by + box_h + 6)
	])
	FastDraw.poly(self, tail_pts, Color("fffdf5"))
	draw_line(tail_pts[0], tail_pts[2], Color("3d2817"), 1.5)
	draw_line(tail_pts[1], tail_pts[2], Color("3d2817"), 1.5)

	# 이름 태그
	if name_tag != "":
		draw_string(font_neodgm, Vector2(bx + 7, by + 12), name_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("912323"))
		draw_string(font_neodgm, Vector2(bx + 7, by + 25), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("1f1812"))
	else:
		draw_string(font_neodgm, Vector2(bx + 8, by + 20), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("1f1812"))

# ============================================================ 기존 건설 장비 및 일상 렌더러
func _draw_geojunggi(p: Vector2, a: Dictionary) -> void:
	var c_anim: float = float((a.get("extra", {}) as Dictionary).get("cable_anim", 0.0))
	AnimalSprites.draw(self, p, "geojunggi", clampi(int((sin(c_anim) + 1.0) * 2.0), 0, 3))

func _draw_nongno(p: Vector2, a: Dictionary) -> void:
	var ang: float = float((a.get("extra", {}) as Dictionary).get("crane_angle", 0.0))
	AnimalSprites.draw(self, p, "nongno", clampi(int((sin(ang) + 1.0) * 2.0), 0, 3))

func _draw_yuheonggeo(p: Vector2) -> void:
	AnimalSprites.draw(self, p, "yuheonggeo", int(Time.get_ticks_msec() / 200.0))
	_spr(p + Vector2(23, 1), "bearer", {"anim": Time.get_ticks_msec() / 250.0}, 0, 1)

func _draw_mason(p: Vector2, a: Dictionary) -> void:
	var m := p + Vector2(-5, 0)
	_spr(m, "mason", a, 0, 0, 0)
	FastDraw.poly(self, PackedVector2Array([p + Vector2(2, 0), p + Vector2(11, 0), p + Vector2(11, -8), p + Vector2(2, -8)]), Color("948f86"))
	FastDraw.poly(self, PackedVector2Array([p + Vector2(11, 0), p + Vector2(13, -2), p + Vector2(13, -10), p + Vector2(11, -8)]), Color("7a756c"))
	FastDraw.poly(self, PackedVector2Array([p + Vector2(2, -8), p + Vector2(11, -8), p + Vector2(13, -10), p + Vector2(4, -10)]), Color("aaa59a"))
	var hand := m + Vector2(4.5, -7)
	var ham_y := -14.0 + sin(float((a.get("extra", {}) as Dictionary).get("hammer_anim", 0.0)) * TAU) * 3.5
	draw_line(hand, m + Vector2(7, ham_y), Color("574b40"), 1.6)
	draw_line(m + Vector2(5, ham_y), m + Vector2(9, ham_y), Color("292623"), 2.4)

func _draw_foreman(p: Vector2, a: Dictionary) -> void:
	var dir := _sdir(a)
	var sx := _ssx(dir)
	_spr(p, "foreman", a, 0, dir, 0)
	var h := p + Vector2(4.5 * sx, -7)
	draw_line(h + Vector2(0, 3), h + Vector2(0, -26), Color("3d2916"), 1.5)
	FastDraw.poly(self, PackedVector2Array([h + Vector2(0, -26), h + Vector2(10 * sx, -22), h + Vector2(0, -18)]), Color("cc2525"))

## 수원천 낚시꾼 (낚시 -> 입질 -> 월척 파닥거림 -> 물고기 꿰미 메고 귀가)
func _draw_fisher(p: Vector2, a: Dictionary) -> void:
	var state: String = a.get("state", "fishing")
	var anim := float(a.get("anim", 0.0))
	if state == "go_home":
		var dir := _sdir(a)
		var sx := _ssx(dir)
		if dir < 2:
			draw_line(p + Vector2(-10 * sx, -6), p + Vector2(12 * sx, -22), Color("7a5626"), 1.8) # 멘 낚싯대
		_spr(p, "fisher", a, 0, dir)
		if dir >= 2:
			draw_line(p + Vector2(-10 * sx, -6), p + Vector2(12 * sx, -22), Color("7a5626"), 1.8)
		var h := p + Vector2(4.5 * sx, -7)
		var f_flop := sin(anim * 16.0) * 2.0
		draw_line(h, h + Vector2(1 * sx, 5), Color("3d2916"), 1.0)
		FastDraw.poly(self, PackedVector2Array([h + Vector2(-1.5, 5), h + Vector2(2.5, 5), h + Vector2(3.5 + f_flop, 11), h + Vector2(-0.5 + f_flop, 11)]), Color("cfd8dc")) # 꿰미 물고기
		return
	# 강가 바위에 앉아 낚시
	FastDraw.poly(self, PackedVector2Array([p + Vector2(-9, 2), p + Vector2(6, 3), p + Vector2(9, -4), p + Vector2(-6, -5)]), Color("6e6962"))
	var fframe := int(anim * 0.8) % 2
	if state == "hook":
		fframe = 1
	elif state == "caught":
		fframe = 2 + int(anim * 3.0) % 2
	if _try_act(p + Vector2(-1, 0), ["npc_fisherman__fish"], fframe, true):
		if state == "hook": # 찌가 까딱이며 물결
			var jg := sin(anim * 18.0) * 2.0
			FastDraw.circle(self, p + Vector2(20, 4 + jg), 1.4, Color("e64320"))
			FastDraw.arc(self, p + Vector2(20, 4), 4.0, 0, TAU, 8, Color(1.0, 1.0, 1.0, 0.6), 1.2)
		return
	var s := p + Vector2(-2, -3)
	_spr_seat(s, "fisher", 0, Color("d8d0c0"))
	var h2 := s + Vector2(4.5, -7)
	if state == "caught":
		draw_line(h2, p + Vector2(10, -30), Color("7a5626"), 2.0)
		draw_line(p + Vector2(10, -30), p + Vector2(15, -16), Color(1.0, 1.0, 1.0, 0.8), 1.0)
		var fish_anim := sin(anim * 22.0) * 3.5
		var fc := p + Vector2(15, -15)
		FastDraw.poly(self, PackedVector2Array([fc + Vector2(-2, -3), fc + Vector2(4, -3), fc + Vector2(5 + fish_anim, 3), fc + Vector2(-1 + fish_anim, 3)]), Color("d1e4eb"))
		draw_line(fc + Vector2(3, 3), fc + Vector2(5, 6), Color("b0bec5"), 1.2)
		FastDraw.circle(self, fc + Vector2(-4, -2), 0.9, Color("e0f7fa"))
		FastDraw.circle(self, fc + Vector2(6, -6), 0.9, Color("e0f7fa"))
	elif state == "hook":
		draw_line(h2, p + Vector2(13, -16), Color("7a5626"), 1.8)
		draw_line(p + Vector2(13, -16), p + Vector2(18, -8), Color("7a5626"), 1.5)
		draw_line(p + Vector2(18, -8), p + Vector2(20, 4), Color(1.0, 1.0, 1.0, 0.7), 1.0)
		var jiggle := sin(anim * 18.0) * 2.0
		FastDraw.circle(self, p + Vector2(20, 4 + jiggle), 1.4, Color("e64320"))
		FastDraw.arc(self, p + Vector2(20, 4), 4.0, 0, TAU, 8, Color(1.0, 1.0, 1.0, 0.6), 1.2)
		FastDraw.arc(self, p + Vector2(20, 4), 6.5, 0, TAU, 8, Color(1.0, 1.0, 1.0, 0.35), 1.0)
	else:
		draw_line(h2, p + Vector2(18, -20), Color("7a5626"), 1.5)
		draw_line(p + Vector2(18, -20), p + Vector2(20, 3), Color(1.0, 1.0, 1.0, 0.65), 1.0)
		var bob := sin(anim * 3.0) * 1.0
		FastDraw.circle(self, p + Vector2(20, 3 + bob), 1.2, Color("e64320"))
		FastDraw.arc(self, p + Vector2(20, 3), 3.2, 0, TAU, 8, Color(1.0, 1.0, 1.0, 0.4), 1.0)

## 겨울철 연날리기 동자 (얼레를 쥐고 방패연을 띄우며 바람을 맞음)
func _draw_kite_flyer(p: Vector2, a: Dictionary) -> void:
	var anim: float = float(a.get("anim", 0.0))
	var t: float = _scene_t
	var step_f: int = int(anim * 4.0) % 2
	var dir := _sdir(a)
	_spr(p, "kite_flyer", a, 0, dir, step_f)
	# 하늘 높이 띄운 방패연과 연실
	var hand := p + Vector2(4.0, -18.0)
	var kp := hand + Vector2(16.0 + sin(t * 1.4) * 8.0, -44.0 + sin(t * 2.1) * 5.0)
	draw_line(hand, kp, Color(1.0, 1.0, 1.0, 0.65), 0.8)
	FestivalArt._kite(self, kp, Color("c0392b"), t)

## 수원천 빨래하는 아낙 (방망이질 -> 대야에 담기 -> 머리에 빨랫대야 이고 사뿐사뿐 귀가)
## PORT-TRACE [동작 그림 연결]: 후보 동작 그림(ids) 중 있는 첫 번째로 그리고 true. 없으면 false → 예전 덧그림 방식.
func _try_act(p: Vector2, ids: Array, frame: int, face_right: bool, sc: float = 0.70, alpha: float = 1.0) -> bool:
	for id in ids:
		if NpcSprites.action_frames(String(id)) > 0:
			return NpcSprites.draw_action(self, p, String(id), frame, face_right, sc, alpha)
	return false

func _draw_washer(p: Vector2, a: Dictionary) -> void:
	var state: String = a.get("state", "washing")
	if state == "go_home":
		var dir := _sdir(a)
		var sx := _ssx(dir)
		_spr(p, "washer", a, 0, dir)
		# 머리에 인 빨랫대야 + 받친 손
		draw_line(p + Vector2(4.5 * sx, -14), p + Vector2(5 * sx, -25), Color("f7f7f5"), 2.0)
		_draw_oval_shadow(p + Vector2(0, -27), 7.0, 2.6, Color("5e3c1d"))
		_draw_oval_shadow(p + Vector2(0, -28), 5.2, 2.0, Color("fdfdfa"))
		return
	FastDraw.poly(self, PackedVector2Array([p + Vector2(-7, 2), p + Vector2(7, 2), p + Vector2(8, -3), p + Vector2(-6, -3)]), Color("5c5750")) # 빨랫돌
	var s := p + Vector2(-3, -1)
	if state != "done" and _try_act(p + Vector2(-2, 2), ["npc_peasant_woman__wash"], int(float(a.get("anim", 0.0)) * 4.0), false):
		_draw_oval_shadow(p + Vector2(-12, -1), 4.6, 2.2, Color("5e3c1d")) # 빨래 광주리
		_draw_oval_shadow(p + Vector2(-12, -2), 3.2, 1.6, Color("ffffff", 0.9))
		if sin(float(a.get("anim", 0.0)) * 8.0) > 0.6: # 물방울
			FastDraw.circle(self, p + Vector2(6, -6), 1.0, Color(0.85, 0.95, 1.0, 0.9))
			FastDraw.circle(self, p + Vector2(9, -9), 0.8, Color(0.85, 0.95, 1.0, 0.8))
		return
	_spr_seat(s, "washer", 0, Color("1b375e"))
	if state == "done":
		_draw_oval_shadow(p + Vector2(-11, -1), 5.0, 2.4, Color("5e3c1d"))
		_draw_oval_shadow(p + Vector2(-11, -2), 3.6, 1.8, Color("ffffff"))
	else:
		var beat := sin(float(a.get("anim", 0.0)) * 8.0)
		var bat_y := -4.0 + (2.0 if beat > 0.0 else -3.0)
		draw_line(s + Vector2(4.5, -7), p + Vector2(7, bat_y), Color("9c7c56"), 2.0) # 방망이
		_draw_oval_shadow(p + Vector2(-12, -1), 4.6, 2.2, Color("5e3c1d"))
		_draw_oval_shadow(p + Vector2(-12, -2), 3.2, 1.6, Color("ffffff", 0.9))

## 수원천 여름철 물장구/멱감기 전용 렌더러 (하반신 물속 잠김, 물보라 파티클 동반)
func _draw_water_play(p: Vector2, a: Dictionary) -> void:
	var anim_val: float = float(a.get("anim", 0.0)) + float(a.get("anim_seed", 0.0))
	var alpha: float = float(a.get("fade_alpha", 1.0))
	var dir := _sdir(a)

	# 1. 수면 아래 하반신 잠김: 상반신만 수면 위로 노출 (18줄 자름, 신발 서기 모션 금지)
	var arm_frame: int = clampi(roundi(absf(sin(anim_val * 4.0)) * 3.0), 0, 3)
	NpcSprites.draw_upper(self, p + Vector2(0.0, -1.0), "child_m", 0, false, dir, 18, arm_frame, "cheer", alpha)

	# 2. 물보라 파티클 및 첨벙거리는 동심원 수면 파문 (splash_fx)
	var w_t: float = anim_val * 5.0
	var r1: float = fmod(w_t, 10.0)
	var r2: float = fmod(w_t + 5.0, 10.0)
	# 수면 동심원 타원 물결 2중 파문
	FastDraw.arc(self, p + Vector2(0.0, 1.0), r1 * 1.4, 0.0, TAU, 10, Color(0.55, 0.85, 1.0, (1.0 - r1 / 10.0) * 0.7 * alpha), 1.0)
	FastDraw.arc(self, p + Vector2(0.0, 1.0), r2 * 1.4, 0.0, TAU, 10, Color(0.55, 0.85, 1.0, (1.0 - r2 / 10.0) * 0.7 * alpha), 1.0)

	# 첨벙거리는 물보라 물방울 파티클 (4개)
	for i: int in range(4):
		var ang_off: float = float(i) * 1.57 + sin(w_t * 2.0) * 0.5
		var splash_dist: float = 4.0 + absf(sin(w_t * 3.0 + float(i))) * 6.0
		var drop_h: float = -2.0 - absf(sin(w_t * 6.0 + float(i) * 1.7)) * 7.0
		var drop_pos := p + Vector2(cos(ang_off) * splash_dist, drop_h)
		FastDraw.circle(self, drop_pos, 1.3, Color(0.75, 0.92, 1.0, 0.85 * alpha))

## 수원천 익수자(drowning) 전용 렌더러 (허우적거림 및 구조 장대/밧줄 연동)
func _draw_drowning(p: Vector2, a: Dictionary) -> void:
	var anim_val: float = float(a.get("anim", 0.0)) + float(a.get("anim_seed", 0.0))
	var alpha: float = float(a.get("fade_alpha", 1.0))
	var dir := _sdir(a)
	var dr_state: String = a.get("state", "drowning")

	var ice := bool(a.get("ice", false))
	var who := "child_m" if bool(a.get("is_child", false)) else "commoner"
	if dr_state == "saved":
		# 구조되어 물가에 무사히 앉아 안도하는 모습(얼음물에 빠졌으면 덜덜 떨며)
		var shiver := sin(_scene_t * 40.0) * 0.6 if ice else 0.0
		NpcSprites.draw_upper(self, p + Vector2(shiver, -2.0), who, 0, ice, dir, 20, 1, "tired", alpha)
		return
	if ice:
		_draw_ice_hole(p, 11.0, alpha)

	# 1. 격렬한 상하 요동 (가라앉았다 뜨는 모션)
	var sink_y: float = sin(anim_val * 6.0) * 3.5
	var arm_frame: int = clampi(roundi(absf(sin(anim_val * 8.0)) * 3.0), 0, 3)
	NpcSprites.draw_upper(self, p + Vector2(0.0, sink_y), who, 0, ice, dir, 16, arm_frame, "panic", alpha)

	# 2. 격렬한 물보라 및 거품 파티클 (splash_fx)
	var w_t: float = anim_val * 7.0
	for i: int in range(6):
		var ang: float = float(i) * 1.05 + sin(w_t) * 0.4
		var dist: float = 5.0 + absf(sin(w_t + float(i))) * 7.0
		var h_drop: float = -3.0 - absf(sin(w_t * 2.0 + float(i))) * 8.0
		var drop_pos := p + Vector2(cos(ang) * dist, h_drop)
		FastDraw.circle(self, drop_pos, 1.4, Color(0.8, 0.95, 1.0, 0.9 * alpha))

	# 동심원 물결
	var r: float = fmod(w_t, 12.0)
	FastDraw.arc(self, p + Vector2(0.0, 2.0), r * 1.5, 0.0, TAU, 10, Color(0.6, 0.9, 1.0, (1.0 - r / 12.0) * alpha), 1.2)

	# 3. 구조자(rescuer)가 장대나 밧줄을 내미는 연출
	var rescuer_id: int = int(a.get("rescuer_id", -1))
	if rescuer_id >= 0 and citizens != null:
		for cand_r: Dictionary in citizens.agents:
			if cand_r["id"] == rescuer_id and cand_r.get("state", "") == "rescuing":
				var rp := _cc(float(cand_r["x"]) + 0.5, float(cand_r["y"]) + 0.5)
				if rp.distance_to(p) < 140.0:
					# 구조 밧줄/장대 렌더링
					draw_line(rp + Vector2(0, -6), p + Vector2(0, sink_y - 2), Color("8c6d46"), 2.0)
					FastDraw.circle(self, p + Vector2(0, sink_y - 2), 2.2, Color("d4a373"))
				break

## 깨진 얼음 구멍: 시커먼 물 + 둘레에 들린 얼음 조각
func _draw_ice_hole(p: Vector2, r: float, alpha: float = 1.0) -> void:
	_draw_oval_shadow(p + Vector2(0, 1), r + 2.0, (r + 2.0) * 0.45, Color(0.55, 0.68, 0.78, 0.7 * alpha))
	_draw_oval_shadow(p + Vector2(0, 1), r, r * 0.42, Color(0.08, 0.2, 0.3, 0.95 * alpha))
	for i in range(7):
		var th := TAU * float(i) / 7.0 + 0.3
		var q := p + Vector2(cos(th) * r * 1.05, sin(th) * r * 0.46 + 1.0)
		var tn := Vector2(-sin(th), cos(th) * 0.45) * 2.6
		FastDraw.poly(self, PackedVector2Array([q - tn, q + tn, q + Vector2(cos(th) * 3.0, -2.2)]), Color(0.9, 0.96, 1.0, alpha))

## 겨울 언 수원천 썰매 아이: 나무 썰매에 앉아 양손 꼬챙이로 얼음을 지치며 미끄러진다. 갈라질 땐 얼음 금이 번진다.
func _draw_ice_sled(p: Vector2, a: Dictionary) -> void:
	var alpha: float = float(a.get("fade_alpha", 1.0))
	var anim: float = float(a.get("anim", 0.0)) + float(a.get("anim_seed", 0.0))
	var dir := _sdir(a)
	var sx := float(_ssx(dir))
	var k := _sk()
	if String(a.get("state", "")) == "crack":
		for i in range(5):
			var th := TAU * float(i) / 5.0 + 0.4
			draw_line(p + Vector2(0, 1), p + Vector2(cos(th) * 13.0, sin(th) * 5.5 + 1.0), Color(1, 1, 1, 0.85 * alpha), 1.0)
	_draw_oval_shadow(p + Vector2(0, 2), 10.0 * k, 2.8 * k, Color(0.3, 0.42, 0.52, 0.35 * alpha))
	# 썰매: 널판 + 앞이 들린 쇠날 두 줄
	var fw := Vector2(7.0 * sx, -1.2) * k
	var sd := Vector2(0, 2.2) * k
	for rl: float in [-1.0, 1.0]:
		var o := sd * rl * 0.5 + Vector2(0, 1.0)
		draw_line(p - fw + o, p + fw + o, Color("4a4f55", alpha), 1.0)
		draw_line(p + fw + o, p + fw * 1.25 + o - Vector2(0, 1.6), Color("4a4f55", alpha), 1.0)
	FastDraw.poly(self, PackedVector2Array([p - fw - sd * 0.6, p + fw - sd * 0.6, p + fw + sd * 0.5, p - fw + sd * 0.5]), Color("8a6440", alpha))
	draw_line(p - fw - sd * 0.6, p + fw - sd * 0.6, Color("b08a5e", alpha), 1.0)
	# 썰매에 무릎 꿇고 앉은 아이(무릎까지 남김: 너무 자르면 헤엄치는 것처럼 보인다) + 꼬챙이 둘(번갈아 얼음을 찍음)
	var body := p + Vector2(-1.5 * sx, -1.0) * k
	NpcSprites.draw_upper(self, body, "child_m", 0, true, dir, 26, 1, "", alpha, 40.0)
	for hi in range(2):
		var pushk := sin(anim * 4.0 + float(hi) * PI)
		var hand := body + Vector2((2.5 + float(hi) * 2.0) * sx, -7.0) * k
		var tip := p + Vector2((-6.0 - 3.0 * pushk) * sx + float(hi) * 2.0 * sx, 3.0 + float(hi)) * k
		draw_line(hand, tip, Color("5a3d24", alpha), 1.0)
	# 날이 긁고 간 얼음 가루
	if String(a.get("state", "")) != "crack":
		for i in range(3):
			var f := fmod(anim * 1.3 + float(i) * 0.33, 1.0)
			FastDraw.circle(self, p + Vector2((-9.0 - f * 8.0) * sx, 2.0 - f * 2.0) * k, 0.9, Color(1, 1, 1, (1.0 - f) * 0.8 * alpha))

## 겨울 얼음구멍 빙어낚시: 짚방석에 쪼그려 앉아 짧은 낚싯대를 얼음 구멍에 드리운다. 걸리면 은빛 빙어가 파닥.
func _draw_ice_fisher(p: Vector2, a: Dictionary) -> void:
	var alpha: float = float(a.get("fade_alpha", 1.0))
	var anim: float = float(a.get("anim", 0.0)) + float(a.get("anim_seed", 0.0))
	var state: String = a.get("state", "fishing")
	var k := _sk()
	var hole := p + Vector2(11.0, 3.0) * k
	if state == "crack":
		for i in range(5):
			var th := TAU * float(i) / 5.0 + 0.2
			draw_line(p + Vector2(4, 2), p + Vector2(4.0 + cos(th) * 14.0, 2.0 + sin(th) * 6.0), Color(1, 1, 1, 0.85 * alpha), 1.0)
	_draw_oval_shadow(hole, 4.2 * k, 1.9 * k, Color(0.75, 0.86, 0.94, alpha))
	_draw_oval_shadow(hole, 3.2 * k, 1.3 * k, Color(0.1, 0.24, 0.34, alpha))
	_draw_oval_shadow(p + Vector2(-9, 2) * k, 3.4 * k, 1.6 * k, Color("6b5a3a", alpha)) # 빙어 담는 바구니
	FastDraw.poly(self, PackedVector2Array([p + Vector2(-6, 0) * k, p + Vector2(5, 0) * k, p + Vector2(5, 3) * k, p + Vector2(-6, 3) * k]), Color("b89a5a", alpha)) # 짚방석
	_spr_seat(p + Vector2(-1, -2) * k, "fisher", 0, Color("d8d0c0"))
	var hand := p + Vector2(4.0, -9.0) * k
	var rod_tip := hand + Vector2(7.0, -3.0) * k
	draw_line(hand, rod_tip, Color("7a5626", alpha), 1.2)
	var jig := 0.0
	if state == "hook":
		jig = sin(anim * 18.0) * 1.5
	draw_line(rod_tip, hole + Vector2(0, jig), Color(1, 1, 1, 0.7 * alpha), 0.7)
	if state == "hook":
		FastDraw.arc(self, hole, 4.0 * k, 0, TAU, 8, Color(1, 1, 1, 0.6 * alpha), 1.0)
	elif state == "caught":
		var lift := hole + Vector2(-1.0, -7.0 - absf(sin(anim * 3.0)) * 3.0) * k
		draw_line(rod_tip, lift, Color(1, 1, 1, 0.8 * alpha), 0.7)
		var flop := sin(anim * 20.0) * 1.2
		FastDraw.poly(self, PackedVector2Array([lift + Vector2(-1.2, 0), lift + Vector2(1.2, 0), lift + Vector2(0.8 + flop, 5.0), lift + Vector2(-0.6 + flop, 5.0)]), Color("dfe7ec", alpha))

## 서학 천주교 신자(catholic) 전용 렌더러
func _draw_catholic(p: Vector2, a: Dictionary) -> void:
	var dir := _sdir(a)
	var sx := _ssx(dir)
	var state: String = a.get("state", "idle")

	if state == "fleeing":
		# 혼비백산 도주 (전력 질주)
		var run_anim: float = sin(float(a.get("anim", 0.0)) * 12.0) * 3.0
		NpcSprites.draw_kind(self, p + Vector2(0, -absf(run_anim) * 0.5), "scholar", 0, current_season == "겨울", dir, int(float(a.get("anim", 0.0)) * 2.0) % 4)
		_draw_alert_exclamation(p + Vector2(0, -26))
	elif state == "arrested":
		# 포박된 모습
		NpcSprites.draw_kind(self, p, "scholar", 0, current_season == "겨울", dir, 0)
		var kr := _sk()
		draw_line(p + Vector2(-4, -12) * kr, p + Vector2(4, -10) * kr, Color("8a6a3a"), 1.1) # 오랏줄
		draw_line(p + Vector2(-4, -9) * kr, p + Vector2(4, -7) * kr, Color("8a6a3a"), 1.1)
	elif state == "prayer":
		# 단정한 합장 기도 모션
		_spr_seat(p, "scholar", dir, Color("e6e0d0")) # 무릎 꿇고 앉아 합장
		var kh := _sk()
		FastDraw.circle(self, p + Vector2(1.5 * float(sx), -12.5) * kh, 1.1 * kh, Color("e8c9a0")) # 모은 두 손
		FastDraw.circle(self, p + Vector2(1.5 * float(sx), -14.0) * kh, 0.9 * kh, Color("e8c9a0"))
	else:
		# 평시 조용한 모습
		_spr_seat(p, "scholar", dir, Color("e6e0d0"))

## 경고 느낌표 (!) 드로우 헬퍼
func _draw_alert_exclamation(pos: Vector2) -> void:
	FastDraw.circle(self, pos + Vector2(0, -6), 5.0, Color("e63946"))
	draw_line(pos + Vector2(0, -9), pos + Vector2(0, -5), Color("ffffff"), 1.8)
	FastDraw.circle(self, pos + Vector2(0, -3), 0.9, Color("ffffff"))

func _draw_horse_messenger(p: Vector2, a: Dictionary) -> void:
	var sx := _ssx(_sdir(a))
	_draw_horse(p, a, sx, Color("6e3012"), Color("21130b"))
	draw_line(p + Vector2(-4 * sx, -32), p + Vector2(-9 * sx, -48), Color("42321c"), 1.2) # 등에 꽂은 전령기
	FastDraw.poly(self, PackedVector2Array([p + Vector2(-9 * sx, -48), p + Vector2(-17 * sx, -45), p + Vector2(-9 * sx, -42)]), Color("d69a1e"))
	_draw_rider(p + Vector2(-1 * sx, -23), "messenger", _gdir_of(a, sx))

func _draw_scholar(p: Vector2, _a: Dictionary) -> void:
	FastDraw.circle(self, p + Vector2(0, 1), 3.5, Color(0.0, 0.0, 0.0, 0.22))
	var robe := PackedVector2Array([
		p + Vector2(-4, 0), p + Vector2(4, 0),
		p + Vector2(2, -12), p + Vector2(-2, -12)
	])
	FastDraw.poly(self, robe, Color("f7f7f5"))
	FastDraw.circle(self, p + Vector2(0, -13), 2.0, Color("ecc29a"))
	draw_line(p + Vector2(-6, -16), p + Vector2(6, -16), Color("111111"), 1.8)
	FastDraw.poly(self, PackedVector2Array([
		p + Vector2(-2.5, -16), p + Vector2(2.5, -16),
		p + Vector2(2, -21), p + Vector2(-2, -21)
	]), Color("1c1c1c"))
	draw_line(p + Vector2(2, -7), p + Vector2(5, -9), Color("dedad0"), 1.6)

func _draw_official(p: Vector2, _a: Dictionary) -> void:
	FastDraw.circle(self, p + Vector2(0, 1), 4.0, Color(0.0, 0.0, 0.0, 0.25))
	var robe := PackedVector2Array([
		p + Vector2(-4, 0), p + Vector2(4, 0),
		p + Vector2(3, -12), p + Vector2(-3, -12)
	])
	FastDraw.poly(self, robe, Color("941f1f"))
	FastDraw.poly(self, PackedVector2Array([
		p + Vector2(-1.5, -9), p + Vector2(1.5, -9),
		p + Vector2(1.5, -6), p + Vector2(-1.5, -6)
	]), Color("d4af37"))
	FastDraw.circle(self, p + Vector2(0, -13), 2.0, Color("ecc29a"))
	FastDraw.circle(self, p + Vector2(0, -17), 2.5, Color("111111"))
	draw_line(p + Vector2(-5, -16), p + Vector2(5, -16), Color("111111"), 1.8)

func _draw_palanquin(p: Vector2, a: Dictionary) -> void:
	var sx := _ssx(_sdir(a))
	var d2 := 0 if sx > 0 else 1
	_draw_oval_shadow(p + Vector2(0, 1), 18.0, 5.0, Color(0, 0, 0, 0.25))
	_spr(p + Vector2(-14, 0), "bearer", a, 0, d2)
	draw_line(p + Vector2(-19, -15), p + Vector2(19, -15), Color("5c3a1c"), 2.0)
	FastDraw.poly(self, PackedVector2Array([p + Vector2(-8, -8), p + Vector2(8, -8), p + Vector2(8, -24), p + Vector2(-8, -24)]), Color("1c3a63"))
	FastDraw.poly(self, PackedVector2Array([p + Vector2(-10, -24), p + Vector2(11, -24), p + Vector2(0, -30)]), Color("111111"))
	draw_rect(Rect2(p + Vector2(-3, -19), Vector2(6, 7)), Color("a12525"))
	_spr(p + Vector2(14, 0), "bearer", a, 1, d2)

func _draw_cart(p: Vector2, a: Dictionary) -> void:
	FastDraw.circle(self, p + Vector2(0, 1), 7.0, Color(0.0, 0.0, 0.0, 0.25))
	FastDraw.poly(self, PackedVector2Array([p + Vector2(-12, -6), p + Vector2(0, -6), p + Vector2(0, -13), p + Vector2(-12, -13)]), Color("baa063"))
	draw_line(p + Vector2(-12, -9), p + Vector2(0, -9), Color("6e5728"), 1.0)
	FastDraw.circle(self, p + Vector2(-5, -3), 4.0, Color("4a2d14"))
	FastDraw.circle(self, p + Vector2(-5, -3), 1.3, Color("9e8469"))
	draw_line(p + Vector2(0, -8), p + Vector2(8, -8), Color("5e3c1d"), 1.8) # 손잡이
	_spr(p + Vector2(11, 0), "bearer", a, 0, 0)

func _draw_woodcutter(p: Vector2, a: Dictionary) -> void:
	var dir := _sdir(a)
	var sx := _ssx(dir)
	var has_wood: bool = (a.get("extra", {}) as Dictionary).get("has_wood", false)
	if NpcSprites.sheet_for("woodcutter").size() > 0 and String(NpcSprites.sheet_for("woodcutter")[3]) == "npc_woodcutter":
		has_wood = false # 새 나무꾼 그림엔 나뭇짐 지게가 이미 있다
		_spr(p, "woodcutter", a, 0, dir)
		return
	if has_wood and dir < 2:
		_wood_load(p, sx)
	_spr(p, "woodcutter", a, 0, dir)
	if has_wood and dir >= 2:
		_wood_load(p, sx)
	var h := p + Vector2(4.5 * sx, -7)
	draw_line(h, h + Vector2(3 * sx, -6), Color("734924"), 1.5) # 도끼 자루
	draw_line(h + Vector2(2 * sx, -6), h + Vector2(5 * sx, -5), Color("8a8a90"), 2.2) # 도끼날

## 지게에 진 장작 다발
func _wood_load(p: Vector2, sx: float) -> void:
	var b := p + Vector2(-2 * sx, -14)
	draw_line(b + Vector2(-5, 14), b + Vector2(-5, -6), Color("6e4a2c"), 1.2)
	draw_line(b + Vector2(5, 14), b + Vector2(5, -6), Color("6e4a2c"), 1.2)
	for k in range(4):
		draw_line(b + Vector2(-7, -8 + k * 3), b + Vector2(7, -9 + k * 3), Color("69401b"), 2.4)
		FastDraw.circle(self, b + Vector2(-7, -8 + k * 3), 1.2, Color("b08050"))

func _draw_shopper(p: Vector2, a: Dictionary) -> void:
	var aid := int(a.get("id", 0))
	if absi(aid) % 3 != 0: # 셋 중 둘은 조합 백성(흰옷·여러 모자·수염·체형)
		var fr0: int = int(float(a.get("anim", 0.0))) % NpcSprites.FRAMES
		if PeopleVariety.draw(self, p, PeopleVariety.pick(aid), _sdir(a), fr0, float(a.get("fade_alpha", 1.0)), NpcSprites.SMALL_K if NpcSprites.small else 1.0):
			return
	var sk: String = MARKET_CROWD[absi(aid) % MARKET_CROWD.size()]
	if not NpcSprites.sheet_for(sk).is_empty():
		var fr: int = int(float(a.get("anim", 0.0))) % NpcSprites.FRAMES
		NpcSprites.draw_kind(self, p, sk, 0, current_season == "겨울", _sdir(a), fr, "", float(a.get("fade_alpha", 1.0)))
		return
	_draw_shopper_old(p, a)

func _draw_shopper_old(p: Vector2, a: Dictionary) -> void:
	FastDraw.circle(self, p + Vector2(0, 1), 3.5, Color(0.0, 0.0, 0.0, 0.22))

	var cloth_colors: Array[Color] = []
	match current_season:
		"봄":
			cloth_colors = [Color("a8c99f"), Color("f2b5bd"), Color("b2d8d8"), Color("fce4a6"), Color("faf7f2")]
		"여름":
			cloth_colors = [Color("faf7ee"), Color("f0eade"), Color("e8e2d5"), Color("e0ece4")]
		"가을":
			cloth_colors = [Color("8b4513"), Color("2c3e50"), Color("7f5539"), Color("3d5a80"), Color("b08968")]
		"겨울":
			cloth_colors = [Color("334155"), Color("475569"), Color("3e2723"), Color("5c4033")]
		_:
			cloth_colors = [Color("ebe6dc"), Color("a8c99f"), Color("d4afb3"), Color("9bb9d6")]

	var col: Color = cloth_colors[int(a.get("id", 0)) % cloth_colors.size()]
	FastDraw.circle(self, p + Vector2(0, -11), 2.0, Color("ecc29a"))
	var robe := PackedVector2Array([
		p + Vector2(-3, 0), p + Vector2(3, 0),
		p + Vector2(2, -10), p + Vector2(-2, -10)
	])
	FastDraw.poly(self, robe, col)

	# 계절별 머리 및 방한/방서 장신구
	match current_season:
		"봄":
			draw_line(p + Vector2(-3, -13), p + Vector2(3, -13), Color("c49a62"), 1.5)
		"여름":
			draw_line(p + Vector2(-4, -13), p + Vector2(4, -13), Color("c49a62"), 1.8)
			if int(a.get("id", 0)) % 2 == 0:
				FastDraw.circle(self, p + Vector2(4, -7), 1.4, Color("ffffff")) # 접부채
		"가을":
			draw_line(p + Vector2(-3, -13), p + Vector2(3, -13), Color("2b1e16"), 1.6)
			draw_line(p + Vector2(-2, -6), p + Vector2(2, -6), Color("b08938"), 1.2) # 허리띠
		"겨울":
			FastDraw.circle(self, p + Vector2(0, -13), 2.4, Color("1c1917"))
			draw_line(p + Vector2(-2.5, -12), p + Vector2(-1.5, -7), Color("2b1e16"), 1.2)
			draw_line(p + Vector2(2.5, -12), p + Vector2(1.5, -7), Color("2b1e16"), 1.2)
			draw_line(p + Vector2(-3, -9), p + Vector2(3, -9), Color("6c584c"), 1.8) # 털목도리
			var breath: float = sin(float(a.get("anim", 0.0)) * 2.5)
			if breath > 0.4:
				FastDraw.circle(self, p + Vector2(3.5 + breath, -11.5), 0.9, Color(1, 1, 1, 0.65)) # 겨울 입김

# ============================================================ 산짐승 및 야생동물 전용 렌더러

## 꽃사슴 / 노루 (갈색 몸체, 흰 반점, 수사슴 뿔)
func _draw_wild_deer(p: Vector2, a: Dictionary) -> void:
	AnimalSprites.draw_dir(self, p, "deer", int(float(a.get("anim", 0.0)) * 4.0), _sdir(a))

## 두루미 / 백로 (긴 다리, 우아한 순백 깃털, 붉은 정수리, 물고기 쪼는 부리)
func _draw_wild_crane(p: Vector2, a: Dictionary) -> void:
	AnimalSprites.draw_dir(self, p, "crane", int(float(a.get("anim", 0.0)) * 2.0), _sdir(a))

## 멧돼지 (다부진 흑갈색 몸체, 억센 갈기, 뾰족한 주둥이, 흰 엄니)
func _draw_wild_boar(p: Vector2, a: Dictionary) -> void:
	AnimalSprites.draw_dir(self, p, "boar", int(float(a.get("anim", 0.0)) * 4.0), _sdir(a))

## 산토끼 (흰색 몸체, 쫑긋한 귀, 솜꼬리, 깡충깡충 도약)
func _draw_wild_rabbit(p: Vector2, a: Dictionary) -> void:
	AnimalSprites.draw_dir(self, p, "rabbit", int(float(a.get("anim", 0.0)) * 4.0), _sdir(a))

# ============================================================ 사냥꾼, 맹수, 포호책 전용 렌더러

## 조선 사냥꾼 (패랭이, 활, 화살통, 사냥감 가죽/고기 보따리, 저잣거리 판매 돗자리)
func _draw_hunter(p: Vector2, a: Dictionary) -> void:
	var state: String = a.get("state", "search_prey")
	var dir := _sdir(a)
	var sx := _ssx(dir)
	if state == "sell":
		FastDraw.poly(self, PackedVector2Array([p + Vector2(-2, 1), p + Vector2(16, 1), p + Vector2(19, -7), p + Vector2(1, -7)]), Color("c2a66e"))
		FastDraw.poly(self, PackedVector2Array([p + Vector2(2, -2), p + Vector2(8, -2), p + Vector2(10, -6), p + Vector2(4, -6)]), Color("9e2a2b"))
		FastDraw.poly(self, PackedVector2Array([p + Vector2(9, -1), p + Vector2(15, -1), p + Vector2(16, -5), p + Vector2(10, -5)]), Color("6f4e37"))
		dir = 0
		sx = 1.0
	var carry: bool = a.get("has_meat", false) and state != "sell"
	var bow_on_back := state != "hunt"
	if dir < 2:
		if carry:
			_back_bundle(p, sx, Color("804e28"), Color("a83232"))
		if bow_on_back:
			draw_line(p + Vector2(-6 * sx, -24), p + Vector2(5 * sx, -8), Color("4a2810"), 1.6)
	_spr(p, "hunter", a, 0, dir, 0 if state in ["sell", "hunt"] else -1)
	if dir >= 2:
		if carry:
			_back_bundle(p, sx, Color("804e28"), Color("a83232"))
		if bow_on_back:
			draw_line(p + Vector2(-6 * sx, -24), p + Vector2(5 * sx, -8), Color("4a2810"), 1.6)
	if state == "hunt":
		var bp := p + Vector2(11 * sx, -13)
		FastDraw.polyline(self, PackedVector2Array([bp + Vector2(0, -8), bp + Vector2(3 * sx, 0), bp + Vector2(0, 8)]), Color("4a2810"), 1.8)
		draw_line(bp + Vector2(0, -8), bp + Vector2(0, 8), Color("faf0ca"), 0.9)
		draw_line(p + Vector2(4 * sx, -13), bp + Vector2(5 * sx, 0), Color("38220f"), 1.2) # 화살

## 등에 진 보따리(색 col, 위에 얹은 덩이 top)
func _back_bundle(p: Vector2, sx: float, col: Color, top: Color) -> void:
	var b := p + Vector2(-4 * sx, -16)
	draw_rect(Rect2(b + Vector2(-5, -5), Vector2(10, 11)), col)
	draw_rect(Rect2(b + Vector2(-5, -5), Vector2(10, 11)), col.darkened(0.4), false, 0.7)
	FastDraw.circle(self, b + Vector2(0, -5), 3.0, top)

## 승냥이 / 늑대 (잿빛 날렵한 몸체, 날카로운 주둥이, 세운 귀, 긴 꼬리)
func _draw_wild_wolf(p: Vector2, a: Dictionary) -> void:
	AnimalSprites.draw_dir(self, p, "wolf", int(float(a.get("anim", 0.0)) * 4.5), _sdir(a))

## 조선 호랑이 (위풍당당한 황호, 검은 줄무늬, 흰 턱, 무시무시한 송곳니)
func _draw_wild_tiger(p: Vector2, a: Dictionary) -> void:
	AnimalSprites.draw_dir(self, p, "tiger", int(float(a.get("anim", 0.0)) * 4.0), _sdir(a))

## 장용영 착호갑사 (붉은 전립, 철릭 관복, 조총/창, '착호' 깃발, 호피 노획)
func _draw_chakhogapsa(p: Vector2, a: Dictionary) -> void:
	var state: String = a.get("state", "rush_to_hunt")
	var dir := _sdir(a)
	var sx := _ssx(dir)
	var flag := func() -> void:
		draw_line(p + Vector2(-4 * sx, -12), p + Vector2(-7 * sx, -36), Color("4a3525"), 1.5)
		FastDraw.poly(self, PackedVector2Array([p + Vector2(-7 * sx, -36), p + Vector2(-16 * sx, -33), p + Vector2(-7 * sx, -28)]), Color("d90429"))
	if state == "firing" and _try_act(p, ["npc_hunter__shoot", "npc_soldier__shoot"], 1 + int(float(a.get("anim", 0.0)) * 3.0) % 3, sx > 0.0):
		flag.call()
		return
	if dir < 2:
		flag.call()
	_spr(p, "trooper", a, 3, dir, 0 if state == "firing" else -1)
	if dir >= 2:
		flag.call()
	if a.get("has_tiger_skin", false):
		FastDraw.poly(self, PackedVector2Array([p + Vector2(-7 * sx, -9), p + Vector2(-1 * sx, -9), p + Vector2(0, -19), p + Vector2(-6 * sx, -19)]), Color("e07a22"))
		for k in range(3):
			draw_line(p + Vector2(-6 * sx, -17 + k * 3), p + Vector2(-1 * sx, -17 + k * 3), Color("111111"), 1.0)
	var h := p + Vector2(4.5 * sx, -8)
	if state == "firing":
		draw_line(h + Vector2(-3 * sx, 0), h + Vector2(13 * sx, -1), Color("3d2c1d"), 2.0)
		FastDraw.circle(self, h + Vector2(15 * sx, -1), 2.8, Color("ffb703"))
		FastDraw.circle(self, h + Vector2(16 * sx, -1), 1.3, Color("ffffff"))
	else:
		draw_line(h + Vector2(0, 2), h + Vector2(5 * sx, -16), Color("3d2c1d"), 1.8) # 어깨에 기댄 조총

## 횃불 몰이꾼 / 관리 (타오르는 횃불, 놋쇠 꽹과리)
func _draw_beater(p: Vector2, a: Dictionary) -> void:
	var dir := _sdir(a)
	var sx := _ssx(dir)
	var anim_val := float(a.get("anim", 0.0))
	_spr(p, "bearer", a, 1, dir)
	var off := p + Vector2(-5.5 * sx, -7)
	FastDraw.circle(self, off, 3.0, Color("e9c46a")) # 꽹과리
	FastDraw.circle(self, off, 1.6, Color("b08938"))
	var h := p + Vector2(4.5 * sx, -7)
	draw_line(h, h + Vector2(5 * sx, -12), Color("4a2d16"), 2.0) # 횃불 자루
	var fl := sin(anim_val * 12.0) * 1.2
	var fp := h + Vector2(5 * sx, -14)
	FastDraw.circle(self, fp + Vector2(fl, 0), 3.2, Color("e63946"))
	FastDraw.circle(self, fp + Vector2(fl * 0.5, 0), 2.0, Color("ffb703"))
	FastDraw.circle(self, fp, 1.0, Color("fff3b0"))

## 조선 명포수 (바위 은신처 뒤에 엎드린 조준 자세)
func _draw_marksman(p: Vector2, _a: Dictionary) -> void:
	AnimalSprites.draw(self, p, "marksman", int(_scene_t * 2.0))

## 미끼 (산기슭에 놓인 큼직한 사냥 고기 및 덫)
func _draw_bait(p: Vector2, _a: Dictionary) -> void:
	AnimalSprites.draw(self, p, "bait", 0)

# ============================================================ 도적 & 순라군 & 소굴 렌더러

## 도적(화적 떼) 렌더러 (검은/갈색 야행복, 붉은 복면, 횃불 및 약탈 보따리)
func _draw_bandit(p: Vector2, a: Dictionary) -> void:
	var dir := _sdir(a)
	var sx := _ssx(dir)
	var state: String = a.get("state", "march")

	if state == "arrested" and _try_act(p, ["npc_bandit__bound", "npc_thief__bound"], int(float(a.get("anim", 0.0))) % 4, sx > 0.0):
		return
	if state in ["attack_wall", "combat"] and str(a.get("weapon_type", "blade")) in ["blade", "spear"] and _try_act(p, ["npc_bandit__attack"], int(float(Time.get_ticks_msec()) * 0.006) % 4, sx > 0.0):
		return
	if state == "arrested":
		# 포승줄에 묶인 포박 모션
		_spr(p, "prisoner", a, 0, dir)
		draw_line(p + Vector2(-3 * sx, -12), p + Vector2(3 * sx, -12), Color("8a6a3a"), 1.4)
		draw_line(p + Vector2(0, -14), p + Vector2(0, -8), Color("8a6a3a"), 1.2)
		return

	var sack := state in ["raid", "retreat"]
	if sack and dir < 2:
		_back_bundle(p, sx, Color("d4a373"), Color("c49363"))
	_spr(p, "bandit", a, 0, dir)
	if sack and dir >= 2:
		_back_bundle(p, sx, Color("d4a373"), Color("c49363"))

	var w_type: String = str(a.get("weapon_type", "blade"))
	var h_b := p + Vector2(4.5 * sx, -7)

	match w_type:
		"gunner":
			# 도적 포수 (사제 조총)
			var b_tip := h_b + Vector2(10.0 * sx, -6.0)
			draw_line(h_b - Vector2(2 * sx, -1), b_tip, Color("374151"), 2.2)
			if state in ["attack_wall", "combat"]:
				var t_sec: float = float(Time.get_ticks_msec()) * 0.005
				if sin(t_sec * 8.0) > 0.4:
					FastDraw.circle(self, b_tip, 3.2, Color("fde047"))
					draw_line(b_tip, b_tip + Vector2(5 * sx, -2), Color("f97316"), 2.0)
					FastDraw.circle(self, b_tip + Vector2(4 * sx, -3), 2.5, Color(0.85, 0.85, 0.85, 0.6))
		"archer":
			# 도적 사수 (사제 각궁 및 불화살)
			var bow_c := h_b + Vector2(5.0 * sx, -5.0)
			draw_line(bow_c + Vector2(0, -8), bow_c + Vector2(2.5 * sx, 0), Color("78350f"), 1.8)
			draw_line(bow_c + Vector2(2.5 * sx, 0), bow_c + Vector2(0, 8), Color("78350f"), 1.8)
			draw_line(bow_c + Vector2(0, -8), bow_c + Vector2(0, 8), Color("fde047"), 1.0)
			var arr_t := bow_c + Vector2(7.0 * sx, -3.0)
			draw_line(bow_c, arr_t, Color("b45309"), 1.5)
			FastDraw.circle(self, arr_t, 2.0, Color("ef4444"))
		"spear":
			# 도적 창수 (죽창 / 사제 창)
			var s_tip := h_b + Vector2(10.0 * sx, -5.0)
			if state in ["attack_wall", "combat"]:
				var t_val_b: float = sin(float(Time.get_ticks_msec()) * 0.02) * 5.0
				s_tip += Vector2(t_val_b * sx, -1.0)
			draw_line(h_b - Vector2(3.0 * sx, -1.0), s_tip, Color("854d0e"), 2.2)
			draw_line(s_tip, s_tip + Vector2(4.0 * sx, -1.0), Color("9ca3af"), 2.4)
			if state == "combat":
				FastDraw.circle(self, s_tip + Vector2(3.0 * sx, -1.0), 2.2, Color("f97316"))
		_:
			# 도적 살수 (횃불 및 환도)
			var tp := p + Vector2(5.5 * sx, -16)
			if state == "attack_wall":
				tp += Vector2(2.0 * sx, -4.0 + sin(Time.get_ticks_msec() * 0.01) * 3.0)
			draw_line(tp + Vector2(0, 9), tp, Color("493322"), 2.0)
			var fs: float = 0.8 + 0.35 * sin(float((a.get("extra", {}) as Dictionary).get("flame_anim", 0.0)))
			FastDraw.poly(self, PackedVector2Array([tp + Vector2(-2.8 * fs, 0), tp + Vector2(2.8 * fs, 0), tp + Vector2(0, -7.0 * fs)]), Color(1.0, 0.45, 0.05, 0.9))
			FastDraw.circle(self, tp + Vector2(0, -2.2 * fs), 2.2 * fs, Color(1.0, 0.85, 0.2, 0.9))

	# 교전 시 타격 불꽃 및 칼부림
	if state == "combat":
		var spk := p + Vector2(6.0 * sx, -10.0)
		FastDraw.circle(self, spk, 3.2, Color(1.0, 0.95, 0.3, 0.95))
		FastDraw.circle(self, spk, 1.8, Color(1.0, 0.5, 0.1, 1.0))
		var t_spk: float = float(Time.get_ticks_msec()) * 0.02
		for s_i in range(3):
			var s_ang: float = t_spk + float(s_i) * 2.094
			draw_line(spk, spk + Vector2(cos(s_ang), sin(s_ang)) * 5.0, Color(1.0, 0.85, 0.2, 0.9), 1.2)

## 장용영 정예 요격군 렌더러 (정예 군복, 조총/활/환도 삼수병 편제, 선두 깃발병 군기 휘날림)
func _draw_jangyongyeong_soldier(p: Vector2, a: Dictionary) -> void:
	var dir := _sdir(a)
	var sx := _ssx(dir)
	var state: String = a.get("state", "rush")
	var is_flag: bool = bool(a.get("extra", {}).get("is_flag_bearer", false))
	var w_type: String = str(a.get("weapon_type", "blade"))
	if state == "combat" and not is_flag:
		var cf := int(float(Time.get_ticks_msec()) * 0.006) % 4
		var cids: Array = ["npc_soldier__shoot"] if w_type == "gunner" else (["npc_soldier__bow"] if w_type == "archer" else ["npc_soldier__attack"])
		if _try_act(p, cids, cf, sx > 0.0):
			return

	_spr(p, "trooper", a, 0, dir)

	var h := p + Vector2(4.5 * sx, -8)

	match w_type:
		"gunner":
			# 장용영 조총수: 총열 조준 및 일제 사격
			var g_tip := h + Vector2(11.0 * sx, -7.0)
			draw_line(h - Vector2(3.0 * sx, -2.0), g_tip, Color("1f2937"), 2.4) # 정예 조총신
			draw_line(h - Vector2(4.5 * sx, 1.0), h, Color("78350f"), 2.6) # 목재 개머리판
			if state == "combat":
				var t_val: float = float(Time.get_ticks_msec()) * 0.006
				if sin(t_val * 7.0) > 0.35:
					# 격발 섬광
					FastDraw.circle(self, g_tip, 3.8, Color("fef08a"))
					draw_line(g_tip, g_tip + Vector2(7.0 * sx, -2.0), Color("f97316"), 2.2)
					# 자욱한 화약 연막
					for smi in range(3):
						FastDraw.circle(self, g_tip + Vector2((3.0 + float(smi) * 3.0) * sx, -3.0 - float(smi) * 2.0), 2.6 + float(smi) * 1.4, Color(0.92, 0.92, 0.92, 0.65 - float(smi) * 0.18))
		"archer":
			# 장용영 궁수: 각궁을 당겨 편전(애기살) 발사
			var b_c := h + Vector2(6.0 * sx, -6.0)
			draw_line(b_c + Vector2(0, -9.0), b_c + Vector2(3.0 * sx, 0), Color("854d0e"), 2.0)
			draw_line(b_c + Vector2(3.0 * sx, 0), b_c + Vector2(0, 9.0), Color("854d0e"), 2.0)
			draw_line(b_c + Vector2(0, -9.0), b_c + Vector2(0, 9.0), Color("e5e7eb"), 1.2)
			if state == "combat":
				var a_tip := b_c + Vector2(9.0 * sx, -4.0)
				draw_line(b_c - Vector2(3.0 * sx, 0), a_tip, Color("b45309"), 1.6)
				FastDraw.circle(self, a_tip, 2.0, Color("fef08a"))
		"spear":
			# 장용영 당파창수 (삼지창)
			var sp_tip := h + Vector2(12.0 * sx, -6.0)
			if state == "combat":
				var t_val_j: float = sin(float(Time.get_ticks_msec()) * 0.02) * 5.5
				sp_tip += Vector2(t_val_j * sx, -1.5)
			draw_line(h - Vector2(4.0 * sx, 1.0), sp_tip, Color("5c3a21"), 2.2)
			draw_line(sp_tip, sp_tip + Vector2(4.5 * sx, -1.0), Color("e5e7eb"), 2.6)
			draw_line(sp_tip - Vector2(1.5 * sx, 0.0), sp_tip + Vector2(1.5 * sx, -4.0), Color("d1d5db"), 1.8)
			draw_line(sp_tip - Vector2(1.5 * sx, 0.0), sp_tip + Vector2(1.5 * sx, 3.5), Color("d1d5db"), 1.8)
			if state == "combat":
				FastDraw.circle(self, sp_tip + Vector2(3.0 * sx, -1.0), 2.8, Color("fef08a"))
				FastDraw.circle(self, sp_tip + Vector2(3.0 * sx, -1.0), 1.5, Color("f97316"))
		_:
			# 장용영 살수: 환도 (칼)
			if state == "combat":
				var slash_angle: float = sin(Time.get_ticks_msec() * 0.02) * 0.8
				var blade_tip := h + Vector2(9.0 * sx, -11.0).rotated(slash_angle)
				draw_line(h, blade_tip, Color("e5e7eb"), 2.2) # 강철 환도날
				draw_line(h, h + Vector2(2.5 * sx, -2.5), Color("dc2626"), 2.5) # 붉은 칼자루
				FastDraw.circle(self, blade_tip, 3.0, Color(1.0, 0.95, 0.4, 0.95))
				FastDraw.circle(self, blade_tip, 1.6, Color(1.0, 0.6, 0.15, 1.0))
			else:
				draw_line(h + Vector2(-2.0 * sx, 4.0), h + Vector2(5.0 * sx, -8.0), Color("9ca3af"), 1.8)

	# 선두 깃발병 (장용영 군기 붉은 깃발)
	if is_flag:
		var pole_base := p + Vector2(-5.0 * sx, -6.0)
		var pole_top := pole_base + Vector2(0.0, -26.0)
		draw_line(pole_base, pole_top, Color("78350f"), 2.2) # 깃대
		# 삼각 군기 펄럭임
		var wave: float = sin(Time.get_ticks_msec() * 0.008) * 2.5
		var flag_pts := PackedVector2Array([
			pole_top,
			pole_top + Vector2(10.0 * sx + wave, 2.0),
			pole_top + Vector2(12.0 * sx + wave, 7.0),
			pole_top + Vector2(0.0, 10.0)
		])
		FastDraw.poly(self, flag_pts, Color("dc2626")) # 장용영 붉은 군기
		FastDraw.circle(self, pole_top + Vector2(4.0 * sx, 5.0), 1.5, Color("fef08a")) # 금색 문양

## 교전 구역 바닥 흙먼지 파티클 연출 (백병전 격전지 가시화)
func _draw_combat_dust_clouds() -> void:
	if citizens == null or not citizens.is_bandit_battle_active() or city == null:
		return
	var v_bounds: Rect2 = _get_view_bounds()
	var t_msec: float = float(Time.get_ticks_msec()) * 0.005

	for a: Dictionary in citizens.agents:
		if a.get("state", "") == "combat" and not a.get("is_dead", false):
			var gx: int = clampi(int(round(float(a["x"]))), 0, grid.size - 1)
			var gy: int = clampi(int(round(float(a["y"]))), 0, grid.size - 1)
			var elev: float = grid.grid[gy][gx]["elevation"] if grid.in_bounds(gx, gy) else 0.0
			var p: Vector2 = city.cell_center(float(a["x"]), float(a["y"]), elev)
			if v_bounds.has_point(p):
				for k in range(3):
					var phase: float = t_msec + float(k) * 2.1
					var dust_offset := Vector2(sin(phase) * 6.0, cos(phase * 1.3) * 3.0)
					var dust_r: float = 3.0 + sin(phase * 2.0) * 1.5
					FastDraw.circle(self, p + dust_offset + Vector2(0, -2.0), dust_r, Color(0.72, 0.60, 0.45, 0.4))

## 교전 헤드업 게이지 바 (Battle Status HUD) 렌더링
func _draw_battle_status_hud() -> void:
	if citizens == null or not citizens.is_bandit_battle_active() or city == null:
		return

	var v_bounds: Rect2 = _get_view_bounds()
	var combatants: Array[Dictionary] = citizens.agents.filter(func(a: Dictionary) -> bool:
		return not a.get("is_dead", false) and (a.get("type", "") in ["bandit", "jangyongyeong_soldier"]) and a.get("state", "") == "combat"
	)
	if combatants.is_empty():
		return

	# 교전 중심점 계산
	var sum_p := Vector2.ZERO
	for c: Dictionary in combatants:
		var gx: int = clampi(int(round(float(c["x"]))), 0, grid.size - 1)
		var gy: int = clampi(int(round(float(c["y"]))), 0, grid.size - 1)
		var elev: float = grid.grid[gy][gx]["elevation"] if grid.in_bounds(gx, gy) else 0.0
		sum_p += city.cell_center(float(c["x"]), float(c["y"]), elev)
	var cp: Vector2 = sum_p / float(combatants.size())
	if not v_bounds.has_point(cp):
		return

	# 교전 상공 y - 32에 게이지 바 렌더링
	var bar_pos: Vector2 = cp + Vector2(-30, -32)
	var bar_w: float = 60.0
	var bar_h: float = 6.0

	# 1. 배경 프레임
	draw_rect(Rect2(bar_pos + Vector2(-2, -2), Vector2(bar_w + 4, bar_h + 4)), Color(0.1, 0.05, 0.05, 0.9), true)
	draw_rect(Rect2(bar_pos + Vector2(-2, -2), Vector2(bar_w + 4, bar_h + 4)), Color(0.85, 0.65, 0.25, 0.9), false, 1.0)

	# 2. 도적 체력 비율 (붉은색 바)
	var hp_ratio: float = clampf(float(citizens._bandit_siege_hp) / 500.0, 0.0, 1.0)
	var hp_w: float = bar_w * hp_ratio
	if hp_w > 0.0:
		draw_rect(Rect2(bar_pos, Vector2(hp_w, bar_h)), Color(0.95, 0.2, 0.2, 0.95), true)

	# 3. 중앙 분할선
	draw_line(bar_pos + Vector2(bar_w * 0.5, -2), bar_pos + Vector2(bar_w * 0.5, bar_h + 2), Color(1.0, 1.0, 1.0, 0.6), 1.0)

	if font_neodgm:
		var txt := "⚔️ [치열한 교전 중!] 장용영 정예군이 적의 진격을 저지하고 있습니다!"
		var t_size := font_neodgm.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
		draw_string(font_neodgm, cp + Vector2(-t_size.x * 0.5, -36), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1.0, 0.95, 0.7))

## 화재 진압 헤드업 게이지 바 (Fire Extinguish Status HUD) 렌더링
func _draw_fire_status_hud() -> void:
	if citizens == null or city == null or grid == null:
		return
	var active_fires: Array[Dictionary] = citizens.get_active_fires()
	if active_fires.is_empty():
		return

	var v_bounds: Rect2 = _get_view_bounds()
	for f: Dictionary in active_fires:
		if f.get("extinguished", false):
			continue
		var fpos: Vector2i = f.get("pos", Vector2i(-1, -1))
		if not grid.in_bounds(fpos.x, fpos.y):
			continue
		var elev: float = float(grid.grid[fpos.y][fpos.x].get("elevation", 0.0))
		var fp: Vector2 = city.cell_center(float(fpos.x) + 0.5, float(fpos.y) + 0.5, elev)
		if not v_bounds.has_point(fp):
			continue

		# 멸화군 및 자원 진화대 카운트
		var ff_count: int = 0
		var vol_count: int = 0
		for a: Dictionary in citizens.agents:
			if a.get("target_fire_pos", Vector2i(-1, -1)) == fpos and not a.get("is_dead", false):
				var at: String = str(a.get("type", ""))
				var ast: String = str(a.get("state", ""))
				if at == "firefighter_soldier" and ast == "extinguish":
					ff_count += 1
				elif at == "bucket_volunteer" and ast == "pour_water":
					vol_count += 1

		var prog: float = float(f.get("fire_progress", 0.1))
		var quench_ratio: float = clampf(1.0 - prog, 0.0, 1.0)

		# 화재 상공 y - 34에 상태 바 렌더링
		var bar_w: float = 64.0
		var bar_h: float = 6.0
		var bar_pos: Vector2 = fp + Vector2(-bar_w * 0.5, -34.0)

		# 1. 배경 프레임
		draw_rect(Rect2(bar_pos + Vector2(-2, -2), Vector2(bar_w + 4, bar_h + 4)), Color(0.12, 0.06, 0.04, 0.9), true)
		var frame_col: Color = Color(0.95, 0.70, 0.20, 0.95) if (ff_count > 0 or vol_count > 0) else Color(0.85, 0.20, 0.20, 0.95)
		draw_rect(Rect2(bar_pos + Vector2(-2, -2), Vector2(bar_w + 4, bar_h + 4)), frame_col, false, 1.0)

		# 2. 진화 게이지
		if ff_count > 0 or vol_count > 0:
			var q_w: float = bar_w * quench_ratio
			if q_w > 0.0:
				draw_rect(Rect2(bar_pos, Vector2(q_w, bar_h)), Color(0.18, 0.80, 0.35, 0.95), true)
		else:
			var f_w: float = bar_w * prog
			if f_w > 0.0:
				draw_rect(Rect2(bar_pos, Vector2(f_w, bar_h)), Color(0.95, 0.25, 0.15, 0.95), true)

		# 3. 상태 텍스트
		if font_neodgm:
			var txt: String = ""
			var col: Color = Color(1.0, 0.95, 0.70)
			if ff_count > 0 or vol_count > 0:
				txt = "🧯 [화마 진압 중] 진압률 %d%% (멸화군 %d명, 백성 %d명)" % [int(quench_ratio * 100.0), ff_count, vol_count]
				col = Color("fef08a")
			else:
				txt = "🔥 [불길 확산 중!] 멸화군 진화 부대 출동 요망"
				col = Color("fca5a5")
			var t_size: Vector2 = font_neodgm.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 9)
			var tp: Vector2 = fp + Vector2(-t_size.x * 0.5, -46.0)
			draw_rect(Rect2(tp + Vector2(-3, -1), t_size + Vector2(6, 3)), Color(0.05, 0.05, 0.05, 0.75), true)
			draw_string(font_neodgm, tp + Vector2(0, t_size.y - 2), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, col)

## 사건 및 화재 위치 펄스 핑 (Incident Ping) 렌더링
func _draw_incident_pings() -> void:
	if _incident_pings.is_empty():
		return
	var v_bounds: Rect2 = _get_view_bounds()
	for p_dict: Dictionary in _incident_pings:
		var p: Vector2 = p_dict.get("pos", Vector2.ZERO) as Vector2
		if not v_bounds.has_point(p):
			continue
		var timer: float = float(p_dict.get("timer", 0.0))
		var max_t: float = float(p_dict.get("max_timer", 3.0))
		var ratio: float = clampf(timer / max_t, 0.0, 1.0)
		var pulse: float = fmod((max_t - timer) * 2.5, 1.0)

		# 1. 퍼져나가는 동심원 핑 (황금빛 & 주홍빛)
		var r1: float = 14.0 + pulse * 38.0
		var a1: float = (1.0 - pulse) * ratio * 0.9
		draw_arc(p, r1, 0.0, TAU, 32, Color(0.96, 0.65, 0.12, a1), 2.2)

		var r2: float = 8.0 + fmod(pulse + 0.5, 1.0) * 38.0
		var a2: float = (1.0 - fmod(pulse + 0.5, 1.0)) * ratio * 0.7
		draw_arc(p, r2, 0.0, TAU, 32, Color(0.95, 0.25, 0.15, a2), 1.8)

		# 2. 중심 십자 표적 마커
		var cross_r: float = 8.0
		draw_line(p + Vector2(-cross_r, 0), p + Vector2(cross_r, 0), Color(1.0, 0.90, 0.40, ratio), 1.5)
		draw_line(p + Vector2(0, -cross_r), p + Vector2(0, cross_r), Color(1.0, 0.90, 0.40, ratio), 1.5)

		# 3. 사건 현장 라벨 말풍선
		if font_neodgm:
			var txt: String = "🚨 [%s]" % str(p_dict.get("text", "사건 현장"))
			var t_size: Vector2 = font_neodgm.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
			var tp: Vector2 = p + Vector2(-t_size.x * 0.5, -r1 - 12.0)
			draw_rect(Rect2(tp + Vector2(-4, -2), t_size + Vector2(8, 4)), Color(0.12, 0.03, 0.03, 0.85 * ratio), true)
			draw_rect(Rect2(tp + Vector2(-4, -2), t_size + Vector2(8, 4)), Color(0.96, 0.70, 0.20, 0.95 * ratio), false, 1.0)
			draw_string(font_neodgm, tp + Vector2(0, t_size.y - 2), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1.0, 0.98, 0.85, ratio))

## 순라군(병졸) 렌더러 (조선 포졸 벙거지 모자, 청색 제복, 육모방망이)
func _draw_patrol_soldier(p: Vector2, a: Dictionary) -> void:
	var dir := _sdir(a)
	var sx := _ssx(dir)
	var state: String = str(a.get("state", "patrol_wall"))
	var anim: float = float(a.get("anim", 0.0))

	if state == "suppress" and _try_act(p, ["npc_patrol__subdue"], int(anim * 4.0) % 4, sx > 0.0):
		return
	_spr(p, "patrol", a, 0, dir)

	var h := p + Vector2(4.5 * sx, -7)
	if state == "suppress":
		# 진압 중: 육모방망이를 격렬히 휘두름
		var swing_angle: float = sin(anim * 14.0) * 0.8
		var baton_end := h + Vector2((3.0 + cos(swing_angle) * 4.0) * sx, -11.0 + sin(swing_angle) * 8.0)
		draw_line(h + Vector2(0, 2), baton_end, Color("865a36"), 2.6) # 육모방망이
		FastDraw.circle(self, baton_end, 1.6, Color("6a4022"))
		# 타격 스파크 이펙트
		if sin(anim * 14.0) > 0.3:
			draw_line(baton_end + Vector2(-3, -3), baton_end + Vector2(3, 3), Color("fbbf24"), 1.2)
			draw_line(baton_end + Vector2(-3, 3), baton_end + Vector2(3, -3), Color("f59e0b"), 1.2)
	elif state == "escort":
		# 압송 중: 한 손에 오라줄을 쥐고 당김
		draw_line(h + Vector2(0, 2), h + Vector2(3 * sx, -9), Color("865a36"), 2.2)
		FastDraw.circle(self, h + Vector2(3 * sx, -9), 1.3, Color("6a4022"))
		# 뒤쪽으로 이어지는 오라줄
		draw_line(h + Vector2(-2 * sx, -4), p + Vector2(-12 * sx, -6), Color("8a6a3a"), 1.2)
	else:
		# 평시/출동
		draw_line(h + Vector2(0, 2), h + Vector2(3 * sx, -11), Color("865a36"), 2.4)
		FastDraw.circle(self, h + Vector2(3 * sx, -11), 1.4, Color("6a4022"))

## 저잣거리 범죄자 및 분쟁 NPC 렌더러 (취객 난동범, 소매치기 도둑, 결박/압송, 골든타임 게이지)
# ============================================================ 저잣거리 싸움(새 도트 시트)
## PORT-TRACE [싸움 v2]: 가해자와 상대가 "같은 사람"으로 보이지 않게 서로 다른 그림 묶음에서 고른다(사건 id로 고정).
## 싸움 = 서로 마주 보고 서기·걷기 두 칸을 빠르게 번갈아 + 주먹을 뻗을 때 몸을 내밀고 상대는 밀림(타격 섬광·흙먼지).
## 쓰러짐 = 상대 그림을 0.4초 동안 90도로 돌려 눕힘(머리 위 별). 후송 = 들것꾼 둘(피해자와 다른 그림)이 걷기 동작으로
## 장대를 메고, 그 사이에 쓰러진 그 사람 그림을 눕혀 얹어 약방 쪽으로. 가해자 = 제자리에서 들썩이며 우쭐 → 걸어서 떠남.
const BRAWLER_SHEETS := ["npc_brawler", "npc_cheonmin", "npc_hallyang"]
const OPPONENT_SHEETS := ["npc_bobusang", "npc_farmer", "npc_artisan_blacksmith", "npc_fisherman", "npc_yangban_scholar"]
const BEARER_SHEETS := ["npc_cheonmin", "npc_farmer"]
var _brawl_handed := {} # 들것 후송으로 넘긴 싸움 사건 id

## 화면 위 from → to를 바라보는 게임 방향(0~3)
func _dir_toward(from: Vector2, to: Vector2) -> int:
	return NpcSprites.dir_of({"dir": _gdir_screen(to - from)})

## 48x48 시트 인물. frame 0 = 서기, 1 = 걷기
func _sheet(p: Vector2, sheet_id: String, dir: int, frame: int, alpha: float = 1.0) -> bool:
	var tex: Texture2D = SpriteCacheManager.get_npc_texture(sheet_id)
	if tex == null:
		return false
	_draw_character_sprite_48x48(p, tex, dir, frame, alpha, false)
	return true

## 누운 사람: 시트의 서 있는 그림을 angle(라디안, ±PI/2면 완전히 누움)만큼 돌려 center에 그림
func _sheet_lying(center: Vector2, sheet_id: String, angle: float, alpha: float = 1.0) -> void:
	var tex: Texture2D = SpriteCacheManager.get_npc_texture(sheet_id)
	if tex == null:
		draw_line(center + Vector2(-10, 0), center + Vector2(8, 0), Color("ca8a04"), 3.5)
		FastDraw.circle(self, center + Vector2(-11, 0), 3.0, Color("e6bf98"))
		return
	var s := NpcSprites.adult_k(0.70)
	NpcSprites.set_xf(self, center, angle, Vector2(s, s))
	draw_texture_rect_region(tex, Rect2(-24.0, -26.0, 48.0, 48.0), Rect2(0, 0, 48, 48), Color(1, 1, 1, alpha))
	NpcSprites.reset_xf(self)

func _brawl_pick(id: int, victim_kind: String = "") -> Array:
	var b: String = BRAWLER_SHEETS[absi(id) % BRAWLER_SHEETS.size()]
	var o: String = OPPONENT_SHEETS[absi(id * 7 + 3) % OPPONENT_SHEETS.size()]
	if o == b:
		o = OPPONENT_SHEETS[(OPPONENT_SHEETS.find(o) + 1) % OPPONENT_SHEETS.size()]
	if victim_kind == "drunk" and NpcSprites._has_sheet("npc_drunkard"):
		o = "npc_drunkard" # 왈패에게 얻어맞는 취객
	return [b, o]

func _draw_brawl_scene(p: Vector2, mp: Vector2, a: Dictionary, state: String, anim: float) -> void:
	var extra: Dictionary = a.get("extra", {})
	var pick := _brawl_pick(int(a.get("id", 0)), String(extra.get("victim_kind", "")))
	var b_sheet: String = pick[0]
	var o_sheet: String = pick[1]
	if state in ["disputing", "fleeing"]:
		var to_o := (mp - p).normalized() if mp.distance_to(p) > 0.5 else Vector2(-1, 0)
		var punch := maxf(0.0, sin(anim * 8.0))
		var hit := punch > 0.75
		var mid := (p + mp) * 0.5
		var bp := mid - to_o * 10.0 + to_o * punch * 4.0 # 반 칸쯤 떨어져 마주 서고, 주먹 뻗을 때 몸을 내밂
		var op := mid + to_o * (10.0 + (2.5 if hit else 0.0)) # 맞으면 뒤로 밀림
		var fr := int(anim * 8.0) % 2
		var b_dir := _dir_toward(p, mp)
		var o_dir := _dir_toward(mp, p)
		var first_brawler := bp.y < op.y
		if first_brawler:
			if not _sheet(bp, b_sheet, b_dir, fr):
				_spr(bp, "carrier", a, 0, b_dir)
		if not _sheet(op, o_sheet, o_dir, 1 - fr):
			_spr(op, "merchant", a, 0, o_dir)
		if not first_brawler:
			if not _sheet(bp, b_sheet, b_dir, fr):
				_spr(bp, "carrier", a, 0, b_dir)
		if hit:
			var hit_p := (bp + op) * 0.5 + Vector2(0, -14.0)
			FastDraw.circle(self, hit_p, 3.5, Color("fef08a"))
			FastDraw.circle(self, hit_p, 1.8, Color("ef4444"))
			draw_line(hit_p + Vector2(-3, -3), hit_p + Vector2(3, 3), Color("f59e0b"), 1.2)
			draw_line(hit_p + Vector2(-3, 3), hit_p + Vector2(3, -3), Color("f59e0b"), 1.2)
		for di in range(2):
			var d_phase: float = anim * 5.0 + float(di) * 3.14
			FastDraw.circle(self, (p + mp) * 0.5 + Vector2(sin(d_phase) * 6.0, 1.0), 2.2, Color(0.7, 0.6, 0.45, 0.5))
		return
	if not (state in ["boast_and_carry", "returning_home"]):
		_sheet(p, b_sheet, _sdir(a), 0) # 체포·압송 등 다른 상태: 가해자만
		return
	# 가해자: 우쭐(제자리 들썩임) → 귀가(걷기)
	var s_y: float = float(extra.get("swagger_y", 0.0))
	var boasting: bool = bool(extra.get("is_boasting", false))
	var away := _dir_toward(mp, p) if mp.distance_to(p) > 0.5 else _sdir(a) # 피해자 반대쪽(귀가 방향)을 봄
	if not _sheet(p + Vector2(0, s_y), b_sheet, _dir_toward(p, mp) if boasting else away, 0 if boasting else int(anim * 6.0) % 2):
		_spr(p, "carrier", a, 0, away)
	var boast_txt: String = str(a.get("bubble_text", ""))
	if boast_txt != "":
		_draw_speech_bubble(p + Vector2(0, -24), boast_txt, "")
	# 피해자: 쓰러짐 → 들것 후송
	if not bool(extra.get("carrier_active", false)) or bool(extra.get("victim_done", false)):
		return
	var carry_left := float(extra.get("carry_left", 4.0))
	var elapsed := 5.0 - carry_left
	var clinic := Vector2(float(extra.get("clinic_x", 0.0)), float(extra.get("clinic_y", 0.0)))
	var to_c := Vector2(1, 0)
	if clinic != Vector2.ZERO:
		var cs := city.cell_center(clinic.x, clinic.y, 1.0)
		if cs.distance_to(mp) > 1.0:
			var dv := cs - mp # 화면의 대각선 네 방향(길 방향) 중 가까운 쪽으로 — 수직이면 들것꾼이 겹쳐 들것이 가려진다
			to_c = Vector2(2.0 * (1.0 if dv.x >= 0.0 else -1.0), 1.0 if dv.y >= 0.0 else -1.0).normalized()
	var head_right := to_c.x >= 0.0 # 머리가 가는 쪽
	var fall := clampf(elapsed / 0.4, 0.0, 1.0)
	var lie_angle := (PI * 0.5 if head_right else -PI * 0.5) * fall
	if elapsed < 1.0:
		# 쓰러져 누운 채 머리 위로 별 / 들것꾼 둘이 뛰어옴
		_sheet_lying(mp + Vector2(0, -10.0 * (1.0 - fall) - 3.0), o_sheet, lie_angle)
		for k in range(3):
			var ang := anim * 6.0 + float(k) * TAU / 3.0
			FastDraw.circle(self, mp + Vector2(cos(ang) * 6.0, -12.0 + sin(ang) * 2.0), 1.2, Color("fde047"))
		var come := clampf(elapsed, 0.0, 1.0)
		for side: float in [-1.0, 1.0]:
			var bp2 := mp + to_c * side * lerpf(40.0, 15.0, come)
			_sheet(bp2, BEARER_SHEETS[0 if side < 0.0 else 1], _dir_toward(bp2, mp), int(anim * 8.0) % 2)
	elif citizens != null and citizens.has_method("spawn_patient"):
		# 1초 뒤: 길을 따라 약방(없으면 행궁)으로 가는 들것 후송으로 넘긴다 — 같은 사람 그림을 넘겨 장면이 이어지게
		var cid := int(a.get("id", 0))
		if not _brawl_handed.has(cid):
			var vt := Vector2i(int(floor(float(extra.get("merchant_x", 0.0)))), int(floor(float(extra.get("merchant_y", 0.0)))))
			_brawl_handed[cid] = bool(citizens.spawn_patient(vt, "싸움", o_sheet))
		if bool(_brawl_handed[cid]):
			return
	if elapsed >= 1.0: # 갈 곳(약방·행궁·관아·순라청)이 없으면 그 자리에서 실어 감
		# (후송 기능이 없을 때) 장대를 메고 약방 쪽으로: 뒤 들것꾼 → 들것·피해자 → 앞 들것꾼
		var fr2 := int(anim * 6.0) % 2
		var walk_dir := _dir_toward(mp, mp + to_c)
		var back_p := mp - to_c * 15.0
		var front_p := mp + to_c * 15.0
		var pole_y := -16.0
		var parts: Array = [[back_p.y, 0], [mp.y, 1], [front_p.y, 2]]
		parts.sort_custom(func(x1: Array, x2: Array) -> bool: return float(x1[0]) < float(x2[0]))
		for part: Array in parts:
			match int(part[1]):
				0:
					_sheet(back_p, BEARER_SHEETS[0], walk_dir, fr2)
				2:
					_sheet(front_p, BEARER_SHEETS[1], walk_dir, 1 - fr2)
				1:
					draw_line(back_p + Vector2(0, pole_y), front_p + Vector2(0, pole_y), Color("6e4a2c"), 1.8) # 장대
					var mid := mp + Vector2(0, pole_y + 2.0)
					draw_line(mid - to_c * 9.0, mid + to_c * 9.0, Color("f2eee4"), 3.0) # 들것 천
					_sheet_lying(mid + Vector2(0, -3.0), o_sheet, PI * 0.5 if head_right else -PI * 0.5)
	var vic_txt: String = str(extra.get("victim_bubble", ""))
	if vic_txt != "":
		_draw_speech_bubble(mp + Vector2(0, -26), vic_txt, "")

func _draw_criminal_npc(p: Vector2, a: Dictionary) -> void:
	var dir := _sdir(a)
	var sx := _ssx(dir)
	var extra: Dictionary = a.get("extra", {})
	var c_kind: String = str(extra.get("criminal_kind", "drunk_brawler"))
	var state: String = str(a.get("state", "disputing"))
	var anim: float = float(a.get("anim", 0.0))

	# 피해 상인 위치 계산
	var mx: float = float(extra.get("merchant_x", float(a.get("x", 0.0)) - 0.35))
	var my: float = float(extra.get("merchant_y", float(a.get("y", 0.0))))
	var m_elev: float = 0.0
	if grid != null and city != null:
		var mgx: int = clampi(int(round(mx)), 0, grid.size - 1)
		var mgy: int = clampi(int(round(my)), 0, grid.size - 1)
		m_elev = grid.grid[mgy][mgx].get("elevation", 0.0)
	var mp: Vector2 = city.cell_center(mx, my, m_elev) if city != null else p + Vector2(-12.0 * sx, 0.0)

	var s_y: float = float(extra.get("swagger_y", 0.0))
	var p_draw := p + Vector2(0.0, s_y)

	# 1. 캐릭터 몸체 및 맞은편 상인 액션 드로우
	if c_kind == "drunk_brawler":
		_draw_brawl_scene(p, mp, a, state, anim)
	else:
		# 소매치기: 동작 그림이 있으면 훔치기·도주·포박 동작으로
		var tf := int(anim * 6.0) % 4
		var thief_right := sx > 0.0
		var drew_thief := false
		if state == "disputing":
			drew_thief = _try_act(p, ["npc_thief__steal"], int(anim * 2.0) % 4, thief_right)
		elif state in ["fleeing", "swagger_home", "dispersed"]:
			drew_thief = _try_act(p_draw, ["npc_thief__run"], tf, thief_right)
		elif state in ["arrested", "escorted", "jailed"]:
			drew_thief = _try_act(p, ["npc_thief__bound"], int(anim * 3.0) % 4, thief_right)
		if drew_thief:
			if state == "swagger_home":
				var swag2: String = "세상 살기 편하구만"
				_draw_speech_bubble(p_draw + Vector2(0, -26), swag2, "")
			if state in ["disputing", "fleeing"]:
				var vk := String(extra.get("victim_kind", "shop"))
				if vk == "house":
					_spr(mp, "commoner_w", a, 0, dir) # 집을 털린 아낙이 뛰쳐나옴
				elif vk != "drunk": # 취객은 따로 걸어가며(StreetLife) 털린 줄 뒤늦게 안다
					_spr(mp, "merchant", a, 0, dir) # 쫓아오는 상인
		elif state == "swagger_home":
			# 도둑의 의기양양 팔자걸음 귀가
			_spr(p_draw, "bandit", a, 0, dir)
			# 등에 메고 가는 큼직한 장물 보따리
			var loot_pos := p_draw + Vector2(-5.0 * sx, -9.0)
			FastDraw.circle(self, loot_pos, 5.0, Color("e2e8f0")) # 비단 보따리
			draw_line(loot_pos + Vector2(-3, -2), loot_pos + Vector2(3, 2), Color("c084fc"), 1.8)
			draw_line(p_draw + Vector2(2.0 * sx, -7.0), loot_pos, Color("78350f"), 1.5) # 어깨 끈

			# 머리 위 고유 대사 말풍선
			var swag_txt: String = "세상 살기 편하구만"
			var st_size: Vector2 = font_neodgm.get_string_size(swag_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
			var st_p := p_draw + Vector2(-st_size.x * 0.5, -28.0)
			draw_rect(Rect2(st_p + Vector2(-3, -2), st_size + Vector2(6, 4)), Color(0, 0, 0, 0.75))
			draw_string(font_neodgm, st_p, swag_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color("fef08a"))
		else:
			_spr(p, "bandit", a, 0, dir)
			var bundle_pos := p + Vector2(3.0 * sx, -7.0)
			FastDraw.circle(self, bundle_pos, 3.5, Color("e2e8f0")) # 비단 보따리
			draw_line(bundle_pos + Vector2(-2, -1), bundle_pos + Vector2(2, 1), Color("c084fc"), 1.4)

			# 피해 상인의 추격 모션 (손을 뻗으며 헐레벌떡 뒤쫓아옴)
			if state in ["disputing", "fleeing"]:
				_spr(mp, "merchant", a, 0, dir)
				# 상인이 팔을 앞으로 뻗고 달리는 모션
				var reach_hand := mp + Vector2(5.0 * sx, -8.0 + sin(anim * 8.0) * 2.0)
				draw_line(mp + Vector2(1.0 * sx, -6.0), reach_hand, Color("ca8a04"), 2.0)
				# 상인의 당황 땀방울 FX
				var sweat_pos := mp + Vector2(3.0 * sx, -15.0 + sin(anim * 6.0) * 2.0)
				FastDraw.circle(self, sweat_pos, 1.5, Color("38bdf8"))
				# 헐레벌떡 발자국 먼지
				var dust_p := mp + Vector2(-4.0 * sx, 1.0)
				FastDraw.circle(self, dust_p, 2.0, Color(0.75, 0.65, 0.5, 0.45))

	# 2. 결박/오라줄 연출 (ARRESTED 또는 ESCORTED)
	if state in ["arrested", "escorted"]:
		# 가슴과 어깨를 가로지르는 오라줄 포승
		draw_line(p + Vector2(-4, -12), p + Vector2(4, -8), Color("8a6a3a"), 1.8)
		draw_line(p + Vector2(-4, -8), p + Vector2(4, -12), Color("8a6a3a"), 1.8)
		draw_line(p + Vector2(-3, -5), p + Vector2(3, -5), Color("8a6a3a"), 1.5)

	# 3. 머리 위 아이콘 점멸 및 골든타임 게이지 바 (DISPUTING 또는 FLEEING 상태일 때)
	if state in ["disputing", "fleeing"]:
		var t_sec: float = Time.get_ticks_msec() / 1000.0
		var blink: bool = int(t_sec * 3.5) % 2 == 0

		# 아이콘 텍스트: [싸움] 또는 [도둑]
		var tag_text: String = "[싸움]" if c_kind == "drunk_brawler" else "[도둑]"
		var tag_col: Color = Color("ef4444") if blink else Color("f59e0b")
		var t_size: Vector2 = font_neodgm.get_string_size(tag_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
		var tag_p := p + Vector2(-t_size.x * 0.5, -28.0)
		draw_string(font_neodgm, tag_p, tag_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, tag_col)

		# 피해 상인 말풍선 렌더링
		var v_txt: String = str(extra.get("victim_bubble", ""))
		if v_txt != "":
			var v_size: Vector2 = font_neodgm.get_string_size(v_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 9)
			var vp_pos := mp + Vector2(-v_size.x * 0.5, -26.0)
			draw_rect(Rect2(vp_pos + Vector2(-2, -2), v_size + Vector2(4, 3)), Color(0, 0, 0, 0.7))
			draw_string(font_neodgm, vp_pos, v_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 9, Color("fef08a"))

		# 골든타임 타이머 게이지 바 (오직 사건이 ACTIVE 상태일 때만 렌더링)
		var ev_id: int = int(extra.get("event_id", -1))
		var ev_ratio: float = 1.0
		var is_event_active: bool = false
		if SunlacheongManager.instance != null:
			var ev_obj: MarketDisputeEvent = SunlacheongManager.instance._find_event(ev_id)
			if ev_obj != null and ev_obj.state == MarketDisputeEvent.EventState.ACTIVE:
				ev_ratio = ev_obj.get_time_ratio()
				is_event_active = true

		if is_event_active:
			var bar_w: float = 24.0
			var bar_h: float = 3.0
			var bar_p := p + Vector2(-bar_w * 0.5, -20.0)
			# 배경 바 (검은 반투명)
			draw_rect(Rect2(bar_p, Vector2(bar_w, bar_h)), Color(0, 0, 0, 0.6))
			# 진행 바 (시간에 따라 초록 -> 노랑 -> 빨강)
			var fill_col := Color("22c55e") # 초록
			if ev_ratio < 0.3:
				fill_col = Color("ef4444") # 빨강
			elif ev_ratio < 0.6:
				fill_col = Color("eab308") # 노랑
			draw_rect(Rect2(bar_p, Vector2(bar_w * ev_ratio, bar_h)), fill_col)
	elif state == "dispersed":
		# 실패 후 분노 해산: 머리 위 [분노] 표시
		var rage_txt: String = "[분노]"
		var r_size: Vector2 = font_neodgm.get_string_size(rage_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
		draw_string(font_neodgm, p + Vector2(-r_size.x * 0.5, -28.0), rage_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color("dc2626"))


## 멸화군(소방대원) 렌더러 (흑색 방화복, 쇠갈고리 멸화봉, 물통, 진화 시 물줄기 분사)
func _draw_firefighter_soldier(p: Vector2, a: Dictionary) -> void:
	var dir := _sdir(a)
	var sx := _ssx(dir)
	var state: String = a.get("state", "rush_to_fire")
	var hook := p + Vector2(-5.5 * sx, -7)
	draw_line(hook + Vector2(0, 4), hook + Vector2(0, -20), Color("78350f"), 2.0) # 멸화봉
	draw_line(hook + Vector2(0, -20), hook + Vector2(4 * sx, -22), Color("9ca3af"), 2.2)
	_spr(p, "fireman", a, 0, dir, 0 if state == "extinguish" else -1)
	var bucket := p + Vector2(5.5 * sx, -8)
	FastDraw.poly(self, PackedVector2Array([bucket + Vector2(-3, 0), bucket + Vector2(3, 0), bucket + Vector2(2, 6), bucket + Vector2(-2, 6)]), Color("92400e"))
	draw_line(bucket + Vector2(-3, 0), bucket + Vector2(3, 0), Color("38bdf8"), 1.5)
	if state == "extinguish":
		var t_f: float = Time.get_ticks_msec() / 1000.0
		var spray_target := p + Vector2(sx * 18.0, -10.0 + sin(t_f * 10.0) * 4.0)
		var target_fire: Vector2i = a.get("target_fire_pos", Vector2i(-1, -1))
		if grid != null and city != null and grid.in_bounds(target_fire.x, target_fire.y):
			var f_elev: float = grid.grid[target_fire.y][target_fire.x].get("elevation", 1.0)
			spray_target = _world_in_agent(p, city.cell_center(float(target_fire.x) + 0.5, float(target_fire.y) + 0.5, f_elev) + Vector2(0, -8.0 + sin(t_f * 10.0) * 3.0))
		draw_line(bucket, spray_target, Color("38bdf8", 0.85), 2.5)
		for i: int in range(4):
			var splash_pt := bucket.lerp(spray_target, float(i + 1) / 4.0) + Vector2(0, sin(t_f * 15.0 + float(i)) * 4.0)
			FastDraw.circle(self, splash_pt, 2.0, Color("bae6fd", 0.9))

## 자원 진화대(백성 양동이 부대) 렌더러 (물 긷기, 물동이 나르기, 화마에 물 뿌리기)
func _draw_bucket_volunteer(p: Vector2, a: Dictionary) -> void:
	var dir := _sdir(a)
	var sx := _ssx(dir)
	var state: String = a.get("state", "fetch_water")
	_spr(p, "bearer", a, 1, dir, 0 if state == "pour_water" else -1)
	var bucket := p + Vector2(5.5 * sx, -8)
	FastDraw.poly(self, PackedVector2Array([bucket + Vector2(-3.2, 0), bucket + Vector2(3.2, 0), bucket + Vector2(2.2, 6), bucket + Vector2(-2.2, 6)]), Color("a16207"))
	if a.get("has_water", false):
		draw_line(bucket + Vector2(-3, 0), bucket + Vector2(3, 0), Color("38bdf8"), 1.8)
	if state == "pour_water":
		var t_f: float = Time.get_ticks_msec() / 1000.0
		var splash_target := p + Vector2(sx * 14.0, -9.0 + sin(t_f * 8.0) * 3.0)
		var target_fire: Vector2i = a.get("target_fire_pos", Vector2i(-1, -1))
		if grid != null and city != null and grid.in_bounds(target_fire.x, target_fire.y):
			var f_elev: float = grid.grid[target_fire.y][target_fire.x].get("elevation", 1.0)
			splash_target = _world_in_agent(p, city.cell_center(float(target_fire.x) + 0.5, float(target_fire.y) + 0.5, f_elev) + Vector2(0, -6.0 + sin(t_f * 8.0) * 2.5))
		draw_line(bucket, splash_target, Color("38bdf8", 0.9), 2.2)
		for i: int in range(3):
			var s_off := bucket.lerp(splash_target, float(i + 1) / 3.0) + Vector2(0, sin(t_f * 12.0 + float(i)) * 3.5)
			FastDraw.circle(self, s_off, 1.8, Color("bae6fd", 0.85))

## 민관군 합동 방재대 렌더러 (흙포대/가마니 메고 제방 보강)
func _draw_flood_sandbag(p: Vector2, a: Dictionary) -> void:
	var dir := _sdir(a)
	var sx := _ssx(dir)
	var state: String = a.get("state", "carry_sandbag")
	_spr(p, "laborer", a, 0, dir, 0 if state == "pile_sandbag" else -1)
	if state == "carry_sandbag" or state == "fetch_sandbag":
		var bag := p + Vector2(-2 * sx, -24)
		FastDraw.poly(self, PackedVector2Array([bag + Vector2(-8, -3), bag + Vector2(8, -3), bag + Vector2(9, 3), bag + Vector2(-9, 3)]), Color("b49258"))
		draw_line(bag + Vector2(-3, -3), bag + Vector2(-3, 3), Color("6a4e23"), 1.2)
		draw_line(bag + Vector2(3, -3), bag + Vector2(3, 3), Color("6a4e23"), 1.2)
		draw_line(p + Vector2(4.5 * sx, -14), bag + Vector2(6 * sx, 2), Color("3b4252"), 2.0) # 받친 팔
	elif state == "pile_sandbag":
		var pile := p + Vector2(sx * 11.0, 1.0)
		for k: int in range(2):
			var b_y := float(k) * 4.0
			FastDraw.poly(self, PackedVector2Array([pile + Vector2(-7, -b_y), pile + Vector2(7, -b_y), pile + Vector2(6, 3 - b_y), pile + Vector2(-6, 3 - b_y)]), Color("a27e46"))
			draw_line(pile + Vector2(-3, -b_y), pile + Vector2(-3, 3 - b_y), Color("5c4018"), 1.0)
			draw_line(pile + Vector2(3, -b_y), pile + Vector2(3, 3 - b_y), Color("5c4018"), 1.0)

## 수해 피난민 렌더러 (머리에 봇짐을 이고 팔달산 고지대로 대피)
func _draw_flood_refugee(p: Vector2, a: Dictionary) -> void:
	var dir := _sdir(a)
	_spr(p, "refugee", a, 0, dir)
	var bp := p + Vector2(0, -29)
	FastDraw.poly(self, PackedVector2Array([bp + Vector2(-6.5, -3), bp + Vector2(6.5, -3), bp + Vector2(5.5, 4), bp + Vector2(-5.5, 4)]), Color("3b82f6"))
	draw_line(bp + Vector2(-2, -3), bp + Vector2(2, -5.5), Color("1d4ed8"), 1.5)
	draw_line(bp + Vector2(2, -3), bp + Vector2(-2, -5.5), Color("1d4ed8"), 1.5)
	draw_line(p + Vector2(-5.5, -14), bp + Vector2(-5, 3), Color("e8ecf0"), 2.0) # 봇짐 받친 두 팔
	draw_line(p + Vector2(5.5, -14), bp + Vector2(5, 3), Color("e8ecf0"), 2.0)

## 도적 소굴(근거지) 렌더러 (조선 화적 움막·토굴 채양, 거친 통나무 목책, 화톳불 및 약탈물)
func _draw_bandit_camp(p: Vector2, is_suppressed: bool) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0

	# 1. 짓밟힌 거친 흙바닥 및 맹지/산지 은신처 타원 그림자 (2.5D 아이소메트릭 다이아몬드 타원)
	var ground_pts := PackedVector2Array([
		p + Vector2(0, -11),
		p + Vector2(25, 1),
		p + Vector2(0, 13),
		p + Vector2(-25, 1)
	])
	FastDraw.poly(self, ground_pts, Color(0.18, 0.13, 0.09, 0.52))

	var inner_ground := PackedVector2Array([
		p + Vector2(-1, -7),
		p + Vector2(18, 1),
		p + Vector2(0, 9),
		p + Vector2(-18, 1)
	])
	FastDraw.poly(self, inner_ground, Color(0.26, 0.18, 0.12, 0.65))

	# 2. 뒤편 거친 통나무 가시 목책 (Palisade) - 불규칙하고 뾰족하게 깎은 통나무들
	var p_fence_x: Array[float] = [-20.0, -15.0, -10.0, -5.0, 5.0, 10.0, 16.0, 21.0]
	var p_fence_h: Array[float] = [15.0, 18.0, 16.0, 19.0, 17.0, 19.0, 16.0, 14.0]
	for i: int in range(p_fence_x.size()):
		var fx: float = p_fence_x[i]
		var fh: float = p_fence_h[i]
		var fy_base: float = p.y - 4.0 + (absf(fx) / 25.0) * 5.0
		var log_base := Vector2(p.x + fx, fy_base)
		var log_top := log_base + Vector2(0, -fh)
		if is_suppressed:
			# 토벌 시 부러지고 기울어진 목책
			var lean: float = -4.0 if i % 2 == 0 else 5.0
			log_top = log_base + Vector2(lean, -fh * 0.6)
		# 통나무 껍질과 음영
		draw_line(log_base, log_top, Color("2d1e14"), 3.2)
		draw_line(log_base, log_top, Color("5c4028"), 2.0)
		draw_line(log_top, log_top + Vector2(0, -2.5), Color("3d2817"), 1.2) # 뾰족한 끝단

	# 가로 버팀목 밧줄 엮음
	if not is_suppressed:
		draw_line(p + Vector2(-19, -10), p + Vector2(-5, -8), Color("3d2a1b"), 1.6)
		draw_line(p + Vector2(5, -8), p + Vector2(20, -9), Color("3d2a1b"), 1.6)

	# 3. 조선 화적 움막 (Dugout Straw Hut) 본체 렌더링
	# 움막 중심점: p 기준 좌상단 편향 (p + Vector2(-5, -1))
	var hut_c := p + Vector2(-5, -1)

	# (1) 움막 기단 흙벽 및 반토굴 벽체 (다갈색 진흙/돌담)
	var wall_pts := PackedVector2Array([
		hut_c + Vector2(-15, 3),
		hut_c + Vector2(7, 3),
		hut_c + Vector2(7, -8),
		hut_c + Vector2(-15, -8)
	])
	var wall_col := Color("4a3525") if not is_suppressed else Color("322318")
	FastDraw.poly(self, wall_pts, wall_col)
	# 흙벽 아래 그림자 및 질감
	draw_line(hut_c + Vector2(-15, 3), hut_c + Vector2(7, 3), Color("22150c"), 1.8)
	draw_line(hut_c + Vector2(-14, -2), hut_c + Vector2(6, -2), Color("382619"), 1.0)

	# (2) 움막 지붕: 억새·볏짚·통나무 껍질을 겹겹이 얹은 원추형/우진각 초가지붕
	# 상단 용마루/꼭짓점: hut_c + Vector2(-4, -21)
	var roof_ridge := hut_c + Vector2(-4, -21)
	var roof_eave_left := hut_c + Vector2(-18, -6)
	var roof_eave_right := hut_c + Vector2(10, -6)
	var roof_eave_front := hut_c + Vector2(-4, -2)

	if is_suppressed:
		# 토벌된 상태: 지붕이 반쯤 주저앉고 그을린 잔해
		roof_ridge = hut_c + Vector2(-3, -13)
		roof_eave_left = hut_c + Vector2(-17, -4)
		roof_eave_right = hut_c + Vector2(9, -5)
		roof_eave_front = hut_c + Vector2(-3, 0)

	# 지붕 좌측면 (그늘진 갈색 짚풀)
	var roof_left_pts := PackedVector2Array([
		roof_ridge,
		roof_eave_left,
		roof_eave_front
	])
	var r_left_col := Color("6d5231") if not is_suppressed else Color("2c241c")
	FastDraw.poly(self, roof_left_pts, r_left_col)

	# 지붕 우측면 (빛을 받는 황갈색 짚풀)
	var roof_right_pts := PackedVector2Array([
		roof_ridge,
		roof_eave_front,
		roof_eave_right
	])
	var r_right_col := Color("8a6b3f") if not is_suppressed else Color("3d3126")
	FastDraw.poly(self, roof_right_pts, r_right_col)

	# 이엉 엮은 볏짚단 결(가로/세로 거친 줄무늬 도트 라인)
	var straw_line_col := Color("4a361e") if not is_suppressed else Color("1a140f")
	var straw_hi_col := Color("a8844f") if not is_suppressed else Color("4d3f33")
	if not is_suppressed:
		# 가로 새끼줄(이엉 매듭)
		draw_line(roof_eave_left.lerp(roof_ridge, 0.35), roof_eave_right.lerp(roof_ridge, 0.35), straw_line_col, 1.2)
		draw_line(roof_eave_left.lerp(roof_ridge, 0.70), roof_eave_right.lerp(roof_ridge, 0.70), straw_line_col, 1.0)
		# 세로 짚단 흐름
		for st: float in [0.2, 0.45, 0.7, 0.85]:
			var b_pt: Vector2 = roof_eave_left.lerp(roof_eave_right, st)
			draw_line(b_pt, roof_ridge, straw_hi_col, 0.8)
	else:
		# 부서진 목재 대들보 노출
		draw_line(roof_ridge + Vector2(-2, 2), roof_eave_front + Vector2(1, -2), Color("181008"), 2.0)
		draw_line(roof_ridge + Vector2(2, 4), roof_eave_right + Vector2(-2, 1), Color("24170d"), 1.6)

	# 처마 끝단 두툼한 짚단 마감
	draw_line(roof_eave_left, roof_eave_front, straw_line_col, 1.8)
	draw_line(roof_eave_front, roof_eave_right, straw_line_col, 1.8)

	# (3) 움막 입구(거적대기 문) 및 내부 암흑
	var door_pts := PackedVector2Array([
		hut_c + Vector2(-7, 3),
		hut_c + Vector2(-1, 3),
		hut_c + Vector2(-1, -6),
		hut_c + Vector2(-7, -6)
	])
	FastDraw.poly(self, door_pts, Color("140e0a"))
	# 걷어 올린 낡은 멍석/삼베 거적문
	if not is_suppressed:
		var flap_pts := PackedVector2Array([
			hut_c + Vector2(-8, -6),
			hut_c + Vector2(0, -6),
			hut_c + Vector2(-2, -9),
			hut_c + Vector2(-6, -9)
		])
		FastDraw.poly(self, flap_pts, Color("6b5033"))
		# 입구 기둥 통나무
		draw_line(hut_c + Vector2(-8, 3), hut_c + Vector2(-8, -7), Color("362314"), 1.8)
		draw_line(hut_c + Vector2(0, 3), hut_c + Vector2(0, -7), Color("362314"), 1.8)

	# 4. 약탈품 궤짝, 곡물 가마니, 짐 보따리 (움막 우측 전면)
	var loot_pos := p + Vector2(11, 2)
	# 나무 궤짝
	FastDraw.rect(self, Rect2(loot_pos + Vector2(-3, -5), Vector2(6, 5)), Color("4e3520"))
	draw_line(loot_pos + Vector2(-3, -5), loot_pos + Vector2(3, -5), Color("6d4c2e"), 1.0)
	draw_line(loot_pos + Vector2(-3, -2), loot_pos + Vector2(3, -2), Color("24170e"), 1.0)
	# 쌀가마니/포대 (볏짚색 둥근 묶음)
	FastDraw.circle(self, loot_pos + Vector2(4, -2), 3.0, Color("8f7347"))
	draw_line(loot_pos + Vector2(2, -2), loot_pos + Vector2(6, -2), Color("5c4728"), 1.0)
	# 산짐승 가죽 널어놓은 말림대 (사슴/호랑이 모피)
	var rack_p := p + Vector2(-19, 1)
	draw_line(rack_p, rack_p + Vector2(0, -13), Color("3d2919"), 1.8)
	draw_line(rack_p + Vector2(7, 2), rack_p + Vector2(7, -11), Color("3d2919"), 1.8)
	draw_line(rack_p + Vector2(-1, -11), rack_p + Vector2(8, -9), Color("4a321e"), 1.4)
	if not is_suppressed:
		# 널어둔 호피/가죽
		var pelt_pts := PackedVector2Array([
			rack_p + Vector2(0, -10),
			rack_p + Vector2(7, -8),
			rack_p + Vector2(6, -2),
			rack_p + Vector2(1, -3)
		])
		FastDraw.poly(self, pelt_pts, Color("9e5a23"))
		draw_line(rack_p + Vector2(2, -7), rack_p + Vector2(5, -6), Color("2b180a"), 1.0) # 호피 줄무늬

	# 5. 야영 화톳불(모닥불) 및 조리용 삼각 거치대
	var fire_pos := p + Vector2(3, 7)
	# 둘러놓은 자연석 조약돌
	for ang: float in [0.0, 1.2, 2.3, 3.5, 4.7]:
		var r_stone := fire_pos + Vector2(cos(ang) * 4.5, sin(ang) * 3.0)
		FastDraw.circle(self, r_stone, 1.6, Color("443e39"))

	if not is_suppressed:
		# 삼각 나뭇가지 솥걸이
		draw_line(fire_pos + Vector2(-4, 2), fire_pos + Vector2(0, -9), Color("3d2716"), 1.5)
		draw_line(fire_pos + Vector2(4, 2), fire_pos + Vector2(0, -9), Color("3d2716"), 1.5)
		draw_line(fire_pos + Vector2(0, 4), fire_pos + Vector2(0, -9), Color("29180c"), 1.5)
		# 매달린 가마솥
		FastDraw.circle(self, fire_pos + Vector2(0, -4), 2.2, Color("1f1d1c"))

		# 모닥불 재와 불씨
		FastDraw.circle(self, fire_pos, 3.2, Color(0.18, 0.12, 0.08, 0.8))
		# 깜빡이는 장작불 애니메이션
		var f_flicker: float = sin(t * 12.0) * 0.8 + cos(t * 19.0) * 0.5
		FastDraw.circle(self, fire_pos + Vector2(0, -1), 3.0 + f_flicker * 0.4, Color(1.0, 0.40, 0.08, 0.95))
		FastDraw.circle(self, fire_pos + Vector2(0, -2.5), 1.8 + f_flicker * 0.3, Color(1.0, 0.82, 0.20, 0.95))

		# 피어오르는 모닥불 장작 연기 (3단계 파티클 연출)
		for sk: int in range(3):
			var sphase: float = fmod(t * 1.2 + float(sk) * 0.33, 1.0)
			var smk_y: float = fire_pos.y - 7.0 - sphase * 16.0
			var smk_x: float = fire_pos.x + sin(t * 3.0 + float(sk) * 2.0) * 3.5 + sphase * 2.5
			var smk_r: float = 1.4 + sphase * 3.2
			var smk_a: float = (1.0 - sphase) * 0.45
			FastDraw.circle(self, Vector2(smk_x, smk_y), smk_r, Color(0.68, 0.65, 0.62, smk_a))
	else:
		# 토벌된 상태: 꺼진 잿더미와 연기 한 가닥
		FastDraw.circle(self, fire_pos, 3.5, Color("2d2b29"))
		FastDraw.circle(self, fire_pos + Vector2(-1, 0), 1.5, Color("484542"))
		var s_ext: float = fmod(t * 0.8, 1.0)
		FastDraw.circle(self, Vector2(fire_pos.x + sin(t * 2.0) * 2.0, fire_pos.y - 4.0 - s_ext * 8.0), 1.2 + s_ext * 1.5, Color(0.4, 0.4, 0.4, (1.0 - s_ext) * 0.3))

	# 6. 화적 깃발 / 토벌 관군 깃발 (우측 상단 거친 장대)
	var flag_pole := p + Vector2(17, -2)
	draw_line(flag_pole + Vector2(0, 5), flag_pole + Vector2(0, -25), Color("2a1d13"), 2.2)
	draw_line(flag_pole + Vector2(0, -25), flag_pole + Vector2(0, -27), Color("4a3424"), 1.2) # 뾰족한 장대 끝

	if not is_suppressed:
		# 펄럭이는 흑색/갈색 해적/화적 깃발 (도깨비/해골 문양)
		var f_wave: float = sin(t * 6.0) * 1.5
		var flag_pts := PackedVector2Array([
			flag_pole + Vector2(0, -25),
			flag_pole + Vector2(13 + f_wave, -20),
			flag_pole + Vector2(0, -14)
		])
		FastDraw.poly(self, flag_pts, Color("1c1917"))
		# 깃발 테두리 찢어진 누더기 결
		draw_line(flag_pole + Vector2(0, -25), flag_pole + Vector2(13 + f_wave, -20), Color("3d3835"), 1.0)
		# 깃발 중앙 붉은 표식
		FastDraw.circle(self, flag_pole + Vector2(5 + f_wave * 0.5, -20), 2.0, Color("a8281e"))
	else:
		# 토벌 완료: 정조 대 장용영(壯勇營) 청홍 관군 승전 깃발
		var f_wave2: float = sin(t * 4.0) * 1.2
		var flag_gov := PackedVector2Array([
			flag_pole + Vector2(0, -25),
			flag_pole + Vector2(14 + f_wave2, -19),
			flag_pole + Vector2(0, -13)
		])
		FastDraw.poly(self, flag_gov, Color("1d4ed8"))
		draw_line(flag_pole + Vector2(0, -25), flag_pole + Vector2(14 + f_wave2, -19), Color("93c5fd"), 1.2)
		FastDraw.circle(self, flag_pole + Vector2(6 + f_wave2 * 0.5, -19), 2.2, Color("e11d48"))


## 가옥 방화 피해 화염 및 연기 연출
func _draw_house_fire_smoke(p: Vector2) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0

	for i: int in range(3):
		var fx: float = p.x + (float(i) - 1.0) * 7.0 + sin(t * 8.0 + float(i)) * 2.0
		var fy: float = p.y - 12.0
		var f_height: float = 10.0 + sin(t * 10.0 + float(i) * 2.0) * 4.0
		FastDraw.poly(self, PackedVector2Array([
			Vector2(fx - 4, fy), Vector2(fx + 4, fy),
			Vector2(fx, fy - f_height)
		]), Color(1.0, 0.35, 0.05, 0.85))
		FastDraw.circle(self, Vector2(fx, fy - f_height * 0.4), 2.5, Color(1.0, 0.85, 0.2, 0.9))

	for k: int in range(4):
		var phase: float = fmod(t * 1.5 + float(k) * 0.4, 1.0)
		var sy: float = p.y - 18.0 - phase * 22.0
		var sx: float = p.x + sin(t * 3.0 + float(k)) * 6.0 + phase * 4.0
		var s_radius: float = 3.0 + phase * 6.0
		var s_alpha: float = (1.0 - phase) * 0.55
		FastDraw.circle(self, Vector2(sx, sy), s_radius, Color(0.2, 0.2, 0.2, s_alpha))

# ============================================================ 저잣거리·공방 사람들
## PORT-TRACE [저잣거리·공방 NPC]: 가게 주인(흰 저고리 + 앞치마, 호객할 때 손을 흔든다),
## 장인(업종별 연장: 망치·물레·붓), 짐꾼(지게에 업종 색 짐 보따리).
func _draw_shopkeeper(p: Vector2, a: Dictionary) -> void:
	var dir := _sdir(a)
	var sx := _ssx(dir)
	_spr(p, "shopkeeper", a, 0, dir, 0)
	if String(a.get("bubble_text", "")) != "":
		# 손님을 부르며 팔을 흔든다
		var wave := sin(float(a.get("anim", 0.0)) * 2.0) * 2.0
		draw_line(p + Vector2(5 * sx, -14), p + Vector2(9 * sx, -21 + wave), Color("f2eee4"), 2.0)
		FastDraw.circle(self, p + Vector2(9 * sx, -21 + wave), 1.3, Color("ecc29a"))

## 중인 (기술관/의원): 옥색/담청색 도포, 흑립(갓), 약상자 및 침통
func _draw_jungin(p: Vector2, a: Dictionary) -> void:
	_spr(p, "jungin", a)

## 관아 아전 (향리/이방): 홍색 쾌자/관복, 이방관, 손에 든 장부(문서/호패)
func _draw_ajeon(p: Vector2, a: Dictionary) -> void:
	_spr(p, "ajeon", a)

## 승군 (호국 의승): 잿빛 장삼, 붉은 가사 띠, 삿갓, 주장자(지팡이/육환장)
func _draw_monk_soldier(p: Vector2, a: Dictionary) -> void:
	_spr(p, "monk", a)

## 백정 (도축/가죽공): 먹색/갈색 무명옷, 가죽 앞치마, 가죽 무두질판 또는 칼
func _draw_butcher(p: Vector2, a: Dictionary) -> void:
	var dir := _sdir(a)
	var sx := _ssx(dir)
	_spr(p, "butcher", a, 0, dir)
	var h := p + Vector2(4.5 * sx, -7)
	draw_line(h, h + Vector2(3 * sx, -4), Color("cccccc"), 1.4) # 칼

func _draw_artisan(p: Vector2, a: Dictionary) -> void:
	var extra: Dictionary = a.get("extra", {})
	var trade: String = extra.get("trade", "")
	# PORT-TRACE [하체 없는 장인]: 앉아 일하는 그림(허리 위만)을 걸어 다닐 때도 써서 하체 없는 사람이 돌아다녔다 → 걷는 동안엔 걷는 그림 + 멘 연장
	if not bool(a.get("is_spot", false)) or String(a.get("state", "")) in ["travel", "patrol", "walk", "go_home", "rescuing"]:
		var dir := _sdir(a)
		var sx := _ssx(dir)
		if dir >= 2:
			_spr(p, "artisan", a, 0, dir)
		if not GoodsArt.draw(self, p + Vector2(-4.0 * sx, -8), "crate", 0.55):
			draw_line(p + Vector2(-3 * sx, -5), p + Vector2(4 * sx, -20), Color("6e4a2c"), 1.6) # 멘 연장 자루
		if dir < 2:
			_spr(p, "artisan", a, 0, dir)
		return
	var s := p + Vector2(-3, 0)
	_spr_seat(s, "artisan", 0, Color("b0a080"))
	var h := s + Vector2(4.5, -7)
	var ph: float = float(extra.get("hammer_anim", 0.0))
	match trade:
		"onggi":
			_draw_oval_shadow(p + Vector2(8, -1), 5.0, 2.2, Color("6e4a2c"))
			var ang := ph * TAU
			draw_line(p + Vector2(8, -1), p + Vector2(8, -1) + Vector2(cos(ang), sin(ang) * 0.45) * 4.5, Color("3a2616"), 0.8)
			FastDraw.poly(self, PackedVector2Array([p + Vector2(5, -2), p + Vector2(11, -2), p + Vector2(10, -8), p + Vector2(6, -8)]), Color("9a6a44")) # 빚는 항아리
		"brush", "hanji", "gat":
			draw_rect(Rect2(p + Vector2(4, -3), Vector2(8, 3)), Color("f4f0e4"))
			draw_line(h, h + Vector2(4, 2 + sin(ph * TAU) * 1.2), Color("3a2616"), 1.0)
		_:
			var hy := -15.0 + sin(ph * TAU) * 4.0
			draw_rect(Rect2(p + Vector2(4, -4), Vector2(8, 4)), Color("3c3c42")) # 모루·작업판
			draw_line(h, s + Vector2(8, hy), Color("574b40"), 1.4)
			draw_line(s + Vector2(6, hy), s + Vector2(10, hy), Color("292623"), 2.2)
			if trade in ["smith", "brass"] and sin(ph * TAU) < -0.8:
				FastDraw.circle(self, p + Vector2(8, -5), 1.2, Color("ffcc55"))
				FastDraw.circle(self, p + Vector2(10, -7), 0.8, Color("ffcc55"))

func _draw_porter(p: Vector2, a: Dictionary) -> void:
	var extra: Dictionary = a.get("extra", {})
	var trade: String = extra.get("trade", "")
	var dir := _sdir(a)
	var load_col := Color("b08a3a")
	match trade:
		"onggi": load_col = Color("5e3a22")
		"brass": load_col = Color("d8a93a")
		"hanji", "brush": load_col = Color("f4f0e4")
		"smith", "bow": load_col = Color("4a4a50")
		"gat": load_col = Color("1c1c1c")
	var loaded: bool = a.get("state", "") == "to_shop"
	var psh := NpcSprites.sheet_for("porter_e")
	if not psh.is_empty() and String(psh[3]) == "npc_porter":
		loaded = false # 새 짐꾼 그림엔 지게 짐이 이미 있다
	var draw_load := func() -> void:
		if loaded:
			var b := p + Vector2(0, -26)
			draw_rect(Rect2(b + Vector2(-5, -4), Vector2(10, 9)), load_col)
			draw_rect(Rect2(b + Vector2(-5, -4), Vector2(10, 9)), load_col.darkened(0.4), false, 0.7)
	if dir < 2:
		draw_load.call()
	_spr(p, "porter_e", a, 0, dir)
	if dir >= 2:
		draw_load.call()

# ============================================================ 영농 생태계 및 농민 Life Simulation 렌더러

func _draw_oval_shadow(p: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(12):
		var ang: float = float(i) / 12.0 * TAU
		pts.append(p + Vector2(cos(ang) * rx, sin(ang) * ry))
	FastDraw.poly(self, pts, col)

func _draw_farmer_life(p: Vector2, a: Dictionary) -> void:
	var extra: Dictionary = a.get("extra", {})
	var season: String = String(extra.get("season", current_season))
	var m_anim: float = sin(float(extra.get("m_timer", 0.0)) * 2.5)
	var bend_y: float = absf(m_anim) * 2.0
	var dir := _sdir(a)
	var sx := _ssx(dir)

	# 소를 끄는 농민 (우마 이동 루프 연동 고증)
	# PORT-TRACE [소 네 방향]: 소는 농부 뒤(가는 방향 반대쪽)에서 같은 쪽을 보고 따라온다. 위로 갈 땐 소가 화면 앞이라 나중에
	var has_ox := bool(extra.get("has_ox", false))
	var fwd := _scr_fwd(dir)
	var ox_pos := p - fwd * 15.0
	var draw_ox_now := func() -> void:
		_draw_oval_shadow(ox_pos + Vector2(0, 2), 14.0, 6.0, Color(0, 0, 0, 0.25))
		_draw_ox(ox_pos, a, float(sx), Color("9a521e"))
		draw_line(p + Vector2(4.5 * float(sx), -7 + bend_y), ox_pos + fwd * 8.0 + Vector2(0, -9.0), Color("3d2612"), 1.1) # 고삐
	if has_ox and fwd.y > 0.0:
		draw_ox_now.call()

	_spr(p + Vector2(0, bend_y), "farmer", a, int(a.get("id", 0)) % 2, dir)
	if has_ox and fwd.y <= 0.0:
		draw_ox_now.call()
	var h := p + Vector2(4.5 * float(sx), -7 + bend_y)
	if extra.get("is_drought", false):
		FastDraw.circle(self, p + Vector2(7 * sx, -24 + bend_y), 1.6, Color(0.3, 0.6, 0.9, 0.85))
		FastDraw.circle(self, p + Vector2(9 * sx, -20 + bend_y), 1.1, Color(0.3, 0.6, 0.9, 0.7))
		draw_line(h, p + Vector2(8 * sx, 1), Color("8c6d46"), 1.4)
		return
	match season:
		"봄":
			# 모내기: 손에 쥔 모 + 논물 파문
			_draw_oval_shadow(p + Vector2(0, 2), 8.0, 2.5, Color(0.3, 0.5, 0.8, 0.35))
			draw_line(h, h + Vector2(2 * sx, 7), Color("3d8526"), 1.8)
			draw_line(h + Vector2(1 * sx, 0), h + Vector2(4 * sx, 6), Color("4aa62f"), 1.8)
		"여름":
			# 김매기: 호미
			draw_line(h, h + Vector2(4 * sx, 6), Color("4a4a50"), 1.6)
			draw_line(h + Vector2(4 * sx, 6), h + Vector2(6 * sx, 8), Color("2b2b2e"), 2.4)
		"가을":
			# 벼 베기: 낫 + 볏단
			draw_line(h, h + Vector2(3 * sx, 5), Color("6c5338"), 1.6)
			FastDraw.arc(self, h + Vector2(4 * sx, 5), 3.0, -PI * 0.5, PI * 0.5, 4, Color("8c8c94"), 2.0)
			var o := p + Vector2(-5.5 * sx, -7 + bend_y)
			FastDraw.poly(self, PackedVector2Array([o + Vector2(-3, -7), o + Vector2(2, -8), o + Vector2(2, 3), o + Vector2(-3, 3)]), Color("cca03a"))
			draw_line(o + Vector2(-3, -2), o + Vector2(2, -2), Color("5c3a1d"), 1.2)

func _draw_ox_plow(p: Vector2, a: Dictionary) -> void:
	var extra: Dictionary = a.get("extra", {})
	var dir: float = float(extra.get("dir", 1.0))
	var anim: float = float(a.get("anim", 0.0))
	var step: float = sin(anim * 4.0)
	_draw_oval_shadow(p + Vector2(0, 2), 18.0, 7.0, Color(0, 0, 0, 0.28))
	var ox_p := p + Vector2(dir * 14.0, 0)
	_draw_ox(ox_p, a, dir, Color("9a521e"))
	var head_x: float = ox_p.x + dir * 16.0
	var head_y: float = ox_p.y - 16.0
	var plow_p := p + Vector2(-dir * 2.0, 1.0)
	draw_line(ox_p + Vector2(-dir * 12.0, -12.0), plow_p + Vector2(0, -2.0), Color("5c3a1d"), 2.0)
	FastDraw.poly(self, PackedVector2Array([plow_p + Vector2(-2, -3), plow_p + Vector2(2, -3), plow_p + Vector2(dir * 3, 3)]), Color("3a3a40"))
	FastDraw.poly(self, PackedVector2Array([plow_p + Vector2(-2, -3), plow_p + Vector2(dir * 3, 3), plow_p + Vector2(-dir * 2, 3)]), Color("2d2d32"))
	if absf(step) > 0.3:
		FastDraw.circle(self, plow_p + Vector2(-dir * 4.0, 2.0), 1.5, Color("4a2d12"))
		FastDraw.circle(self, plow_p + Vector2(-dir * 6.0, 1.0), 1.0, Color("5c3a1d"))
	# 뒤따르며 쟁기 자루를 잡은 농부
	var farmer_p := p + Vector2(-dir * 14.0, 0)
	_spr(farmer_p, "farmer", a, 0, 0 if dir > 0 else 1)
	draw_line(farmer_p + Vector2(4.5 * dir, -7), plow_p + Vector2(0, -2.0), Color("5c3a1d"), 1.4)
	draw_line(farmer_p + Vector2(4.5 * dir, -9), Vector2(head_x + dir * 3.0, head_y + 2.0), Color("3d2612"), 0.9) # 고삐

func _draw_farmer_cart(p: Vector2, a: Dictionary) -> void:
	var extra: Dictionary = a.get("extra", {})
	var has_load: bool = bool(extra.get("has_load", true))
	var dir := _sdir(a)
	var fwd := _scr_fwd(dir)
	var puller := p + fwd * 9.0
	var front_first := fwd.y < 0.0
	if front_first:
		_spr(puller, "farmer", a, 1, dir)
	_draw_iso_cart(p - fwd * 3.0, fwd, "hay" if has_load else "", float(a.get("anim", 0.0)), 0.75, puller + Vector2(0, -8))
	if not front_first:
		_spr(puller, "farmer", a, 1, dir)

func _draw_scarecrow(p: Vector2, a: Dictionary) -> void:
	if GoodsArt.draw(self, p + Vector2(0, 2), "scarecrow", 1.8):
		return
	AnimalSprites.draw(self, p, "scarecrow", int(float(a.get("anim", 0.0)) * 1.5))

func _draw_sparrow_flock(p: Vector2, a: Dictionary) -> void:
	var anim: float = float(a.get("anim", 0.0))
	AnimalSprites.draw(self, p + Vector2(sin(anim * 0.5) * 3.0, cos(anim * 0.7) * 2.0), "sparrow", int(anim * 3.0))

# ============================================================ 세시풍속 행렬
## PORT-TRACE [장마당·세시풍속]: 풍물패 길놀이(상모 돌리는 다섯 명 일렬), 씨름 장사 황소 퍼레이드, 들것
func _draw_pungmul_band(p: Vector2, a: Dictionary) -> void:
	var dirv: Vector2 = a.get("dir", Vector2.RIGHT)
	var back := -Vector2(dirv.x * 16.0 - dirv.y * 16.0, (dirv.x + dirv.y) * 8.0).normalized() * 9.0
	var t := float(a.get("anim", 0.0))
	var dir := _sdir(a)
	for i in range(4, -1, -1):
		var q := p + back * float(i) - Vector2(0, absf(sin(t * 1.2 + float(i))) * 2.0)
		_spr(q, "pungmul", a, i % 4, dir)
		var ang := t * 1.8 + float(i)
		draw_line(q - Vector2(0, 27), q - Vector2(0, 27) + Vector2(cos(ang) * 10.0, sin(ang) * 4.0), Color.WHITE, 1.0) # 상모 끈
		if i == 0:
			draw_line(q + Vector2(7, 0), q + Vector2(7, -36), Color("5c3a21"), 1.2)
			draw_rect(Rect2(q + Vector2(8, -36), Vector2(7, 12)), Color("f4f0e4"))
			draw_string(ThemeDB.fallback_font, q + Vector2(8.5, -27), "農", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("7a1f14"))

func _draw_bull_parade(p: Vector2, a: Dictionary) -> void:
	var t := float(a.get("anim", 0.0))
	var bdir := _gdir_of(a, 1.0)
	var fwd := _scr_fwd(bdir)
	var jp := p - fwd * 22.0 + Vector2(0, 2) # 뒤따르는 장구잽이
	var drum := func() -> void:
		_spr(jp, "pungmul", a, 1, bdir)
		_draw_oval_shadow(jp + Vector2(5, -11), 3.0, 2.0, Color("c0392b")) # 장구
	if fwd.y > 0.0:
		drum.call()
	_draw_ox(p, {"anim": t * 0.6, "dir": a.get("dir", Vector2(1, 0))}, 1.0, Color("8a5a32"))
	for k in range(5):
		FastDraw.circle(self, p + Vector2(-9 + k * 4.0, -21), 1.6, [Color("c0392b"), Color("e8b820"), Color("2e8b57"), Color("1f5fa8"), Color("e88aa8")][k])
	# 소 등에 탄 장사(꽃 단 머리)
	NpcSprites.draw_upper(self, p + Vector2(-2, -18), "pungmul", 0, current_season == "겨울", bdir, 27, 0, "", 1.0, 35.0) # 엉덩이까지 소 등에
	FastDraw.circle(self, p + Vector2(-2, -44), 1.6, Color("e8453a"))
	if fwd.y <= 0.0:
		drum.call()

func _draw_stretcher(p: Vector2, a: Dictionary) -> void:
	var t := float(a.get("anim", 0.0))
	if a.get("state", "") == "treat":
		FastDraw.poly(self, PackedVector2Array([p + Vector2(-12, -1), p + Vector2(8, -1), p + Vector2(8, -5), p + Vector2(-12, -5)]), Color("f2eee4"))
		FastDraw.circle(self, p + Vector2(-11, -5.5), 2.6, Color("e6bf98"))
		draw_line(p + Vector2(-13, -6.5), p + Vector2(-8, -6.5), Color("ffffff"), 1.6) # 붕대
		var hand := sin(t * 1.5)
		_spr_seat(p + Vector2(5, -3), "jungin", 1, Color("7aa5b8"))
		draw_line(p + Vector2(0, -10 - hand), p + Vector2(-3, -6 - hand), Color("d8d8d8"), 0.7) # 침
		return
	# PORT-TRACE [들것 v2]: 걷는 방향(게임 방향 0~3 = 격자 +x·+y·-y·-x)을 화면 대각선으로 바꿔 앞뒤 들것꾼을 세우고,
	# 그 사이 장대·들것 천 위에 다친 사람 그림을 눕힌다(싸움이면 싸우던 그 사람, 아니면 백성 그림).
	var gd := _sdir(a)
	var dirs4: Array[Vector2] = [Vector2(2, 1), Vector2(-2, 1), Vector2(2, -1), Vector2(-2, -1)]
	var to_c: Vector2 = dirs4[clampi(gd, 0, 3)].normalized()
	var fr := int(t * 6.0) % 2
	var patient: String = String((a.get("extra", {}) as Dictionary).get("patient_sheet", ""))
	if patient == "":
		patient = "npc_farmer"
	var back_p := p - to_c * 15.0
	var front_p := p + to_c * 15.0
	var parts: Array = [[back_p.y, 0], [p.y, 1], [front_p.y, 2]]
	parts.sort_custom(func(x1: Array, x2: Array) -> bool: return float(x1[0]) < float(x2[0]))
	for part: Array in parts:
		match int(part[1]):
			0:
				if not _sheet(back_p, BEARER_SHEETS[0], gd, fr):
					_spr(back_p, "bearer", a, 0, gd)
			2:
				if not _sheet(front_p, BEARER_SHEETS[1], gd, 1 - fr):
					_spr(front_p, "bearer", a, 1, gd)
			1:
				draw_line(back_p + Vector2(0, -16), front_p + Vector2(0, -16), Color("6e4a2c"), 1.8)
				var mid := p + Vector2(0, -14)
				draw_line(mid - to_c * 9.0, mid + to_c * 9.0, Color("f2eee4"), 3.0)
				_sheet_lying(mid + Vector2(0, -3.0), patient, PI * 0.5 if to_c.x >= 0.0 else -PI * 0.5)

# ============================================================ 인프라 관할 범위 · 물방울
## PORT-TRACE [인프라 관할 범위]: 우물 반경 5칸(약 80칸)을 벗어나 물이 모자란 가옥·상점 위에 파란 물방울이
## 둥실거린다. 우물·순라청·멸화군 도구를 들면 이미 지은 시설들의 관할 범위가 옅게 칠해지고, 커서 자리에
## 새로 지으면 덮일 범위가 테두리로 보인다. 목록은 지도가 바뀌거나 도구가 바뀔 때만 다시 계산한다.
func _tile_poly(x: int, y: int, k: float = 1.0) -> PackedVector2Array:
	var ce: Array = grid.tile(x, y).get("corner_elev", [1.0, 1.0, 1.0, 1.0])
	var a := city.cell_center(x, y, ce[0])
	var b := city.cell_center(x + 1, y, ce[1])
	var c := city.cell_center(x + 1, y + 1, ce[2])
	var d := city.cell_center(x, y + 1, ce[3])
	var m := (a + b + c + d) * 0.25
	return PackedVector2Array([m + (a - m) * k, m + (b - m) * k, m + (c - m) * k, m + (d - m) * k])

func _draw_infra_overlays() -> void:
	var tool: String = city.current_tool
	if COVERAGE_TOOLS.has(tool):
		var spec: Dictionary = COVERAGE_TOOLS[tool]
		if _cov_dirty or _cov_tool != tool:
			_cov_tiles = grid.coverage_tiles(spec["names"], spec["r"])
			_cov_tool = tool
			_cov_dirty = false
		for pt: Vector2i in _cov_tiles:
			FastDraw.poly(self, _tile_poly(pt.x, pt.y, 0.98), spec["col"])
		# 커서 자리에 지으면 덮일 범위(테두리만)
		var h: Vector2i = city.hover_cell
		if not city._is_dragging and grid.in_bounds(h.x, h.y):
			var r: float = spec["r"]
			var ri := int(ceil(r))
			for dy in range(-ri, ri + 1):
				for dx in range(-ri, ri + 1):
					if dx * dx + dy * dy <= r * r and grid.in_bounds(h.x + dx, h.y + dy):
						var pp := _tile_poly(h.x + dx, h.y + dy, 0.9)
						FastDraw.polyline(self, pp + PackedVector2Array([pp[0]]), spec["line"], 1.0)
	else:
		_cov_tool = ""
	# 물방울
	if _drops_dirty:
		_drops = grid.water_shortage_tiles()
		_drops_dirty = false
		_build_drop_mesh()
	if not _drop_meshes.is_empty():
		var bob := sin(Time.get_ticks_msec() * 0.004) * 2.0
		draw_set_transform(Vector2(0.0, -bob))
		for m: Array in _drop_meshes:
			RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), m[1], m[0], m[2])
		draw_set_transform(Vector2.ZERO)

## 물방울 전부를 삼각형 묶음으로 미리 굽는다(물방울 칸이 바뀔 때만). 근대화 뒤에는 수도 영향권 밖 가옥·상점
## 전부에 물방울이 떠서, 하나씩 원 조각으로 그리면 한 프레임에 그리기가 수만 번이 되어 렉이 났다.
var _drop_meshes: Array = [] # [점, 삼각형 번호, 색] 묶음들
const DROP_BATCH := 1500     # 묶음 하나에 넣을 물방울 수
func _build_drop_mesh() -> void:
	_drop_meshes.clear()
	if _drops.is_empty():
		return
	# 몸통(원 + 위로 뾰족한 끝)과 하이라이트 모양 — 볼록 다각형이라 첫 점 기준 부채꼴로 나눈다
	var circ := PackedVector2Array()
	for i in range(12):
		var ang := TAU * float(i) / 12.0
		circ.append(Vector2(cos(ang), sin(ang)) * 3.6)
	circ.append(Vector2(0, -8))
	var body := Geometry2D.convex_hull(circ)
	body.remove_at(body.size() - 1) # 닫는 점(첫 점과 같음) 빼기
	var hi := PackedVector2Array()
	for i in range(6):
		var ang2 := TAU * float(i) / 6.0
		hi.append(Vector2(-1.2, -0.8) + Vector2(cos(ang2), sin(ang2)) * 1.0)
	var body_col := Color("2f8fe0")
	var hi_col := Color(1, 1, 1, 0.8)
	var pts := PackedVector2Array()
	var idx := PackedInt32Array()
	var cols := PackedColorArray()
	var n := 0
	for pt: Vector2i in _drops:
		var tp := _tile_poly(pt.x, pt.y)
		var top := (tp[0] + tp[2]) * 0.5 - Vector2(0, 34.0)
		for shape: Array in [[body, body_col], [hi, hi_col]]:
			var poly: PackedVector2Array = shape[0]
			var base := pts.size()
			for v: Vector2 in poly:
				pts.append(top + v)
				cols.append(shape[1])
			for k in range(1, poly.size() - 1):
				idx.append(base)
				idx.append(base + k)
				idx.append(base + k + 1)
		n += 1
		if n % DROP_BATCH == 0:
			_drop_meshes.append([pts, idx, cols])
			pts = PackedVector2Array()
			idx = PackedInt32Array()
			cols = PackedColorArray()
	if not pts.is_empty():
		_drop_meshes.append([pts, idx, cols])

# ============================================================ 사대문 운반꾼
## PORT-TRACE [사대문 물류]: 문마다 다른 짐을 진 운반꾼. 장안문 = 말 탄 관료·서책 보따리 상인·관용 수레,
## 팔달문 = 소 모는 마부·곡식 달구지·패랭이 보부상, 화서문 = 소금 가마니 지게꾼·생선 광주리 인 아낙,
## 창룡문 = 장작 실은 우마차·약초 망태기 멘 심마니. 진행 방향(화면 좌우)에 맞춰 좌우를 뒤집는다.
## PORT-TRACE [NPC 도트 스프라이트 2단계]: 사람 몸은 NpcSprites 도트로 그리고, 손에 든 것·등짐·탈것만 그 위에 덧그린다.
## 도트 인물(발 위치 p)의 손: 화면 앞쪽 손 p+(4.5·sx, -7), 반대 손 p+(-5.5·sx, -7), 머리 위 p+(0, -27).
## 등짐은 앞모습(방향 0·1)이면 몸보다 먼저, 뒷모습(2·3)이면 몸 뒤에 그린다.
func _scene_small(on: bool) -> void:
	NpcSprites.small = on
	AnimalSprites.small = on

## 장면 덧그림(곤장·의자·무릎 등) 크기 비율 — 작은 인물을 그리는 중이면 0.7
func _sk() -> float:
	return NpcSprites.SMALL_K if NpcSprites.small else 1.0

func _sdir(a: Dictionary) -> int:
	if a.has("dir") and (a["dir"] is Vector2 or a["dir"] is Vector2i):
		return NpcSprites.dir_of(a)
	return 0 if float(a.get("dir_x", 1.0)) >= 0.0 else 1

func _ssx(dir: int) -> float:
	return 1.0 if dir == 0 or dir == 2 else -1.0

func _spr(p: Vector2, kind: String, a: Dictionary, variant: int = 0, dir: int = -1, frame: int = -1) -> void:
	var d := dir if dir >= 0 else _sdir(a)
	var f := frame if frame >= 0 else int(float(a.get("anim", 0.0))) % NpcSprites.FRAMES
	var alpha: float = float(a.get("fade_alpha", 1.0))
	NpcSprites.draw_kind(self, p, kind, variant, current_season == "겨울", d, f, "", alpha)

## 앉은 사람: 허리 위 도트 + 접은 무릎(lap 색)
## PORT-TRACE [앉은 사람]: 사용자 요청 — "하반신이 잘린 모습이 전혀 앉아 있는 것 같지 않다. 엉덩이까지는 보여야".
## 몸은 엉덩이까지(48칸 시트 위 35줄) 그려 엉덩이가 바닥(p)에 닿게 하고, 그 앞에 좌우로 벌린 양반다리(무릎·버선발)를 옷자락 빛으로.
## 뒷모습(dir 2·3)이면 다리는 몸에 가려 무릎 끝만 보이도록 몸보다 먼저 그린다. lap = 바지·치맛자락 빛.
func _spr_seat(p: Vector2, kind: String, dir: int, lap: Color, variant: int = 0) -> void:
	# PORT-TRACE [앉은 사람 엉덩이]: 허리 바로 아래에서 자르고 작은 흰 타원 다리를 붙여 땅에 묻힌 듯 보였다 —
	# 엉덩이·허벅지까지(48칸 시트 39줄) 남기고, 그 사람 옷 색으로 양반다리(접은 무릎)를 몸보다 넓게 그린다.
	var k := _sk()
	_draw_oval_shadow(p + Vector2(0, 1.5) * k, 11.0 * k, 3.2 * k, Color(0, 0, 0, 0.24))
	var col := _hip_col(kind, dir, lap)
	var back := dir >= 2
	if back:
		_seat_legs(p, k, col)
	NpcSprites.draw_upper(self, p + Vector2(0, -0.5) * k, kind, variant, current_season == "겨울", dir, 26, 0, "", 1.0, 39.0)
	if not back:
		_seat_legs(p, k, col)

## 앉은 사람 다리 색: 그 사람 시트의 엉덩이 줄(36~38줄) 옷 색 평균(없으면 lap)
var _hip_cache := {}
func _hip_col(kind: String, dir: int, fallback: Color) -> Color:
	var key := "%s|%d" % [kind, dir]
	if _hip_cache.has(key):
		return _hip_cache[key]
	var col := fallback
	var sh := NpcSprites.sheet_for(kind)
	if not sh.is_empty():
		var img: Image = (sh[0] as Texture2D).get_image()
		if img != null and not img.is_empty():
			if img.is_compressed():
				img.decompress()
			var row: int = [1, 0, 3, 2][clampi(dir, 0, 3)]
			var acc := Vector3.ZERO
			var n := 0
			for yy in range(row * 48 + 35, row * 48 + 39):
				for xx in range(12, 36):
					if yy < img.get_height() and xx < img.get_width():
						var c := img.get_pixel(xx, yy)
						if c.a > 0.5 and c.get_luminance() > 0.12:
							acc += Vector3(c.r, c.g, c.b)
							n += 1
			if n >= 4:
				acc /= float(n)
				col = Color(acc.x, acc.y, acc.z).darkened(0.08)
	_hip_cache[key] = col
	return col

func _seat_legs(p: Vector2, k0: float, lap: Color) -> void:
	var k := k0 * 0.85 # 엉덩이 폭보다 조금 넓게 벌린 양반다리
	var legs := PackedVector2Array()
	for q: Vector2 in [Vector2(-9.5, 0.6), Vector2(-9.2, -2.8), Vector2(-6, -5.0), Vector2(6, -5.0), Vector2(9.2, -2.8), Vector2(9.5, 0.6), Vector2(6.5, 2.8), Vector2(-6.5, 2.8)]:
		legs.append(p + q * k)
	FastDraw.poly(self, legs, lap)
	# 앞으로 접힌 정강이(조금 어둡게)와 두 무릎 사이 주름
	FastDraw.poly(self, PackedVector2Array([p + Vector2(-9.5, 0.6) * k, p + Vector2(9.5, 0.6) * k, p + Vector2(6.5, 2.8) * k, p + Vector2(-6.5, 2.8) * k]), lap.darkened(0.18))
	draw_line(p + Vector2(-1.5, -4.4) * k, p + Vector2(-0.5, 0.8) * k, lap.darkened(0.25), 0.6)
	FastDraw.polyline(self, PackedVector2Array(Array(legs) + [legs[0]]), Color(0.23, 0.18, 0.13, 0.85), 0.7)
	FastDraw.circle(self, p + Vector2(-3.0, 1.6) * k, 1.2 * k, Color("f2efe6")) # 버선발
	FastDraw.circle(self, p + Vector2(3.0, 1.6) * k, 1.2 * k, Color("f2efe6"))

func _face(a: Dictionary) -> float:
	var d: Vector2 = a.get("dir", Vector2.RIGHT)
	return 1.0 if (d.x - d.y) >= 0.0 else -1.0

func _walk_person(p: Vector2, a: Dictionary, robe: Color, hat: int) -> void:
	var step := sin(float(a.get("anim", 0.0)) * 2.0) * 1.2
	draw_line(p + Vector2(-1.5, 0), p + Vector2(-1.5 + step, -4), Color("5a4a38"), 1.3)
	draw_line(p + Vector2(1.5, 0), p + Vector2(1.5 - step, -4), Color("5a4a38"), 1.3)
	FestivalArt.person(self, p + Vector2(0, -2), robe, hat, 0.1)

func _draw_ox(p: Vector2, a: Dictionary, sx: float, col: Color = Color("8a5a32")) -> void:
	var alpha: float = float(a.get("fade_alpha", 1.0))
	AnimalSprites.draw_dir(self, p, "ox", int(float(a.get("anim", 0.0)) * 2.0), _gdir_of(a, sx), col, alpha)

func _draw_official_rider(p: Vector2, a: Dictionary) -> void:
	var sx := _ssx(_sdir(a))
	_draw_horse(p, a, sx, Color("e8e0d0"), Color("b0a890"))
	_draw_rider(p + Vector2(-1 * sx, -23), "official", _gdir_of(a, sx))
	# 일산(붉은 양산) 든 말구종: 말 옆, 화면 앞쪽(아래) 편에서 같은 쪽을 보고 걷는다
	var odir := _gdir_of(a, sx)
	var ofw := _scr_fwd(odir)
	var operp := Vector2(-ofw.y, ofw.x)
	if operp.y < 0.0:
		operp = -operp
	var g := p + operp * 12.0
	_spr(g, "bearer", a, 0, odir)
	var h := g + Vector2(-5.5 * sx, -7)
	draw_line(h, h + Vector2(0, -26), Color("5c3a21"), 1.0)
	FastDraw.poly(self, PackedVector2Array([h + Vector2(-8, -26), h + Vector2(8, -26), h + Vector2(0, -31)]), Color("c0392b"))

## 보따리를 등에 멘 행상(서책 상인)
func _draw_bundle_walker(p: Vector2, a: Dictionary, _robe: Color, _bundle: Color, _books: bool) -> void:
	_spr(p, "book_peddler", a)

## 소달구지·관용 수레: 앞에 소(관용은 말), 바퀴 하나 달린 수레, 짐(곡식 섬·장작·붉은 휘장 궤짝), 고삐 잡은 마부
## PORT-TRACE [소달구지]: 사용자 요청 — "소달구지 뒤 수레가 소와 어울리지 않는다". 바퀴 반지름 4px짜리 평평한 원판 대신,
## 가는 방향(fwd, 마름모 대각선)에 맞춘 입체 수레: 판자 짐칸(옆널) + 짐칸 양옆 큰 나무바퀴(세로로 선 타원, 바큇살이 굴러감) +
## 앞으로 뻗은 끌채 두 개(yoke = 끌채 끝이 닿는 곳). 화면 뒤쪽 바퀴 → 짐칸·짐 → 앞쪽 바퀴 순.
func _draw_iso_cart(c: Vector2, fwd: Vector2, load_kind: String, anim: float, sc: float = 1.0, yoke: Vector2 = Vector2.INF) -> void:
	var side := Vector2(-fwd.x, fwd.y) # 다른 마름모 대각선
	if side.y < 0.0:
		side = -side
	var L := 8.0 * sc
	var Wd := 5.0 * sc
	var R := 5.2 * sc
	var H := 7.5 * sc # 짐칸 높이(바퀴 축 위)
	_draw_oval_shadow(c + Vector2(0, 1), 12.0 * sc, 4.0 * sc, Color(0, 0, 0, 0.22))
	var wheels: Array = [c - side * (Wd + 0.8 * sc), c + side * (Wd + 0.8 * sc)] # [뒤쪽(화면 위), 앞쪽]
	var draw_wheel := func(base: Vector2) -> void:
		var cw := base - Vector2(0, R)
		var rim := PackedVector2Array()
		for i in range(14):
			var th := TAU * float(i) / 14.0
			rim.append(cw + fwd * R * cos(th) + Vector2(0, -R * sin(th)))
		FastDraw.poly(self, rim, Color("6e4a28"))
		FastDraw.polyline(self, PackedVector2Array(Array(rim) + [rim[0]]), Color("2e1a08"), 1.0)
		for sp in range(4):
			var th2 := anim * 2.5 + float(sp) * PI * 0.25
			draw_line(cw - fwd * R * 0.8 * cos(th2) - Vector2(0, -R * 0.8 * sin(th2)), cw + fwd * R * 0.8 * cos(th2) + Vector2(0, -R * 0.8 * sin(th2)), Color("3d230d"), 0.8)
		FastDraw.circle(self, cw, 1.1 * sc, Color("2e1a08"))
	draw_wheel.call(wheels[0])
	# 끌채 두 개(짐칸 앞 모서리 → 멍에)
	var front_l := c + fwd * L - side * (Wd - 1.0 * sc) - Vector2(0, H - 1.0 * sc)
	var front_r := c + fwd * L + side * (Wd - 1.0 * sc) - Vector2(0, H - 1.0 * sc)
	var yk := yoke if yoke != Vector2.INF else c + fwd * (L + 9.0 * sc) - Vector2(0, H - 2.0 * sc)
	draw_line(front_l, yk - side * 1.5 * sc, Color("5e3c1d"), 1.3)
	draw_line(front_r, yk + side * 1.5 * sc, Color("5e3c1d"), 1.3)
	# 짐칸: 바닥판 + 옆널(화면 앞을 보는 두 면)
	var up := Vector2(0, H)
	var b := [c - fwd * L - side * Wd - up, c + fwd * L - side * Wd - up, c + fwd * L + side * Wd - up, c - fwd * L + side * Wd - up]
	var wall := Vector2(0, 2.5 * sc)
	for e in [[b[3], b[2]], [b[0], b[3]] if fwd.x > 0.0 else [b[1], b[2]]]:
		var e0: Vector2 = e[0]
		var e1: Vector2 = e[1]
		MarketArt.draw_safe_quad(self, e0, e1, e1 - wall, e0 - wall, Color("8a6236"))
	FastDraw.poly(self, PackedVector2Array([b[0] - wall, b[1] - wall, b[2] - wall, b[3] - wall]), Color("a8804e"))
	for k in range(1, 4):
		var f := float(k) / 4.0
		draw_line((b[0] as Vector2).lerp(b[3], f) - wall, (b[1] as Vector2).lerp(b[2], f) - wall, Color("7a5630"), 0.5) # 판자 줄
	FastDraw.polyline(self, PackedVector2Array([b[0] - wall, b[1] - wall, b[2] - wall, b[3] - wall, b[0] - wall]), Color("3e2814"), 0.7)
	var top := c - up - wall
	match load_kind:
		"grain":
			for q: Vector2 in [Vector2(-4, 0), Vector2(0, 1), Vector2(4, 0), Vector2(-2, -3), Vector2(2, -3)]:
				var gp := top + (fwd * q.x * 0.9 + side * q.y * 1.2) * sc + Vector2(0, q.y * 1.0 - 1.5) * sc
				FastDraw.circle(self, gp, 2.6 * sc, Color("e6d7b0")) # 가마니
				FastDraw.arc(self, gp, 2.6 * sc, PI, TAU, 6, Color("a8946a"), 0.6)
		"wood":
			for k in range(3):
				for j in range(3 - k):
					var lp := top + (side * (-3.0 + float(j) * 3.0 + float(k) * 1.5)) * sc + Vector2(0, -2.0 - float(k) * 2.6) * sc
					draw_line(lp - fwd * 7.0 * sc, lp + fwd * 7.0 * sc, Color("8a5a32"), 2.4 * sc) # 통나무
					FastDraw.circle(self, lp + fwd * 7.0 * sc, 1.2 * sc, Color("d8b080"))
		"gov":
			var bx := top + Vector2(0, -1.0) * sc
			MarketArt.draw_safe_quad(self, bx - fwd * 5.0 * sc - side * 3.0 * sc, bx + fwd * 5.0 * sc - side * 3.0 * sc, bx + fwd * 5.0 * sc - side * 3.0 * sc - Vector2(0, 6) * sc, bx - fwd * 5.0 * sc - side * 3.0 * sc - Vector2(0, 6) * sc, Color("8e2a1e"))
			FastDraw.poly(self, PackedVector2Array([bx - fwd * 5.0 * sc - side * 3.0 * sc - Vector2(0, 6) * sc, bx + fwd * 5.0 * sc - side * 3.0 * sc - Vector2(0, 6) * sc, bx + fwd * 5.0 * sc + side * 3.0 * sc - Vector2(0, 6) * sc, bx - fwd * 5.0 * sc + side * 3.0 * sc - Vector2(0, 6) * sc]), Color("a83a2a")) # 관용 궤짝
			draw_line(bx - side * 3.0 * sc - Vector2(0, 3) * sc - fwd * 5.0 * sc, bx - side * 3.0 * sc - Vector2(0, 3) * sc + fwd * 5.0 * sc, Color("d4af37"), 0.8)
			var pole := bx - fwd * 5.0 * sc
			draw_line(pole - Vector2(0, 6) * sc, pole - Vector2(0, 20) * sc, Color("5c3a21"), 0.9)
			FastDraw.poly(self, PackedVector2Array([pole - Vector2(0, 20) * sc, pole - Vector2(0, 20) * sc - fwd * 5.0 * sc, pole - Vector2(0, 15) * sc - fwd * 5.0 * sc, pole - Vector2(0, 15) * sc]), Color("f4e04a")) # 官 깃발
		"hay":
			var hp := top + Vector2(0, -2.5) * sc
			FastDraw.poly(self, PackedVector2Array([hp - fwd * 7.0 * sc - side * 4.0 * sc, hp + fwd * 7.0 * sc - side * 4.0 * sc, hp + fwd * 6.0 * sc + side * 4.0 * sc + Vector2(0, -3) * sc, hp - fwd * 6.0 * sc + side * 4.0 * sc + Vector2(0, -3) * sc]), Color("d4aa48")) # 볏단
			draw_line(hp - side * 4.0 * sc, hp + side * 4.0 * sc - Vector2(0, 3) * sc, Color("5e3c1a"), 1.0)
	draw_wheel.call(wheels[1])

func _draw_ox_cart(p: Vector2, a: Dictionary, load_kind: String) -> void:
	var sx := _face(a)
	# PORT-TRACE [소 네 방향]: 마부 → 소 → 수레가 가는 방향(마름모 대각선)으로 줄지어, 화면 위쪽 것부터 그린다
	var cdir := _gdir_of(a, sx)
	var fwd := _scr_fwd(cdir)
	sx = 1.0 if fwd.x >= 0.0 else -1.0
	FastDraw.circle(self, p + Vector2(0, 1), 10.0, Color(0, 0, 0, 0.22))
	var ox_p := p + fwd * 12.0
	var lead_p := p + fwd * 24.0 + Vector2(0, 2)
	var front_first := fwd.y < 0.0 # 위로 가면 앞(소·마부)이 화면 위 → 먼저
	if front_first:
		_spr(lead_p, "bearer", a, 0, cdir)
		_draw_ox(ox_p, a, sx, Color("b0a890") if load_kind == "gov" else Color("8a5a32"))
	_draw_iso_cart(p - fwd * 5.0, fwd, load_kind, float(a.get("anim", 0.0)), 1.0, ox_p - fwd * 8.0 + Vector2(0, -8))
	if not front_first:
		_draw_ox(ox_p, a, sx, Color("b0a890") if load_kind == "gov" else Color("8a5a32"))
		_spr(lead_p, "bearer", a, 0, cdir)

## 소 몰고 오는 마부(쇠전으로): 소 두 마리 + 회초리 든 마부
func _draw_ox_driver(p: Vector2, a: Dictionary) -> void:
	var sx := _face(a)
	var alpha: float = float(a.get("fade_alpha", 1.0))
	# PORT-TRACE [소 네 방향]: 소 두 마리가 앞서고 마부가 뒤에서 몬다 — 가는 대각선 방향으로 줄지어, 화면 위쪽부터
	var ddir := _gdir_of(a, sx)
	var fwd := _scr_fwd(ddir)
	sx = 1.0 if fwd.x >= 0.0 else -1.0
	var d := p - fwd * 24.0 + Vector2(0, 2)
	var items: Array = [[p + fwd * 10.0, 0], [p - fwd * 6.0 + Vector2(0, 2), 1], [d, 2]]
	items.sort_custom(func(u: Array, v: Array) -> bool: return (u[0] as Vector2).y < (v[0] as Vector2).y)
	for it: Array in items:
		match int(it[1]):
			0: _draw_ox(it[0], a, sx)
			1: _draw_ox(it[0], a, sx, Color("6a4026"))
			2:
				_spr(d, "bearer", a, 1, ddir)
				draw_line(d + Vector2(4.5 * sx, -7.0), d + Vector2(4.5 * sx, -7.0) + fwd * 8.0 + Vector2(0, -10.0), Color(0.43, 0.29, 0.17, alpha), 0.9) # 회초리

## 패랭이(목화송이 단 대갓) 쓴 보부상: 지게에 등짐
func _draw_bobusang(p: Vector2, a: Dictionary) -> void:
	_spr(p, "bobusang", a)

## 지게꾼: 소금 가마니(흰 섬) 두 개
func _draw_jige_porter(p: Vector2, a: Dictionary, _load: String) -> void:
	var dir := _sdir(a)
	var sx := _ssx(dir)
	_spr(p, "porter", a, 0, dir)
	# 땀 닦기: 이따금 팔을 이마로 올리고 땀방울이 떨어진다
	var wipe := sin(float(a.get("anim", 0.0)) * 0.45 + float(a.get("id", 0)))
	if wipe > 0.6:
		draw_line(p + Vector2(5 * sx, -13), p + Vector2(3 * sx, -20), Color("c8b890"), 2.0)
		var dropt := fmod(float(a.get("anim", 0.0)) * 2.0, 1.0)
		FastDraw.circle(self, p + Vector2(-4 * sx, -19 + dropt * 7.0), 0.9, Color("8fc8f0"))
		FastDraw.circle(self, p + Vector2(4 * sx, -17 + fmod(dropt + 0.5, 1.0) * 7.0), 0.8, Color("8fc8f0"))

## 생선 광주리를 머리에 인 아낙
func _draw_fish_peddler(p: Vector2, a: Dictionary) -> void:
	var sx := _ssx(_sdir(a))
	_spr(p, "peddler_w", a)
	draw_line(p + Vector2(-5.5 * sx, -14), p + Vector2(-6 * sx, -25), Color("e8dcd0"), 2.0) # 받친 손
	var b := p + Vector2(0, -27)
	FastDraw.poly(self, PackedVector2Array([b + Vector2(-7, 0), b + Vector2(7, 0), b + Vector2(8, -3), b + Vector2(-8, -3)]), Color("8a6236"))
	for k in range(3):
		var fq := b + Vector2(-4.5 + k * 4.5, -4)
		FastDraw.poly(self, PackedVector2Array([fq + Vector2(-2.5, 0), fq + Vector2(2, -1), fq + Vector2(2, 1)]), Color("b8c4cc"))
		FastDraw.poly(self, PackedVector2Array([fq + Vector2(2, 0), fq + Vector2(3.2, -1.2), fq + Vector2(3.2, 1.2)]), Color("8a98a4"))

## 심마니: 약초 망태기 + 지팡이
func _draw_simmani(p: Vector2, a: Dictionary) -> void:
	var dir := _sdir(a)
	var sx := _ssx(dir)
	var basket := func() -> void:
		var b := p + Vector2(-4 * sx, -15)
		FastDraw.circle(self, b, 5.0, Color("8a7a4a"))
		for k in range(3):
			draw_line(b + Vector2(-4 + k * 4, 3), b + Vector2(-4 + k * 4, -3), Color("6a5a30"), 0.6)
		for q: Vector2 in [Vector2(-3, -5), Vector2(0.5, -6.5), Vector2(3.5, -5)]:
			FastDraw.circle(self, b + q, 1.6, Color("4f8a3a"))
		FastDraw.circle(self, b + Vector2(0.5, -8), 1.0, Color("c0392b")) # 산삼 열매
	if dir < 2:
		basket.call()
	_spr(p, "simmani", a, 0, dir)
	if dir >= 2:
		basket.call()
	draw_line(p + Vector2(4.5 * sx, -8), p + Vector2(7 * sx, 1), Color("6e4a2c"), 1.2) # 지팡이

# ============================================================ 성문 밖 외부 길 이정표
## PORT-TRACE [사대문 물류]: 지도 끝까지 이어진 성문 길 끝자락에 장승 겸 이정표 푯말. 마우스를 올리면 안내 카드.
func _draw_gate_signposts() -> void:
	if grid == null:
		return
	var conn_map: Dictionary = grid.check_border_road_connections()
	var font := ThemeDB.fallback_font

	for k: String in ["jangan", "paldal", "changryong", "hwaseo"]:
		var r: Dictionary = conn_map.get(k, {})
		if not r.get("connected", false):
			continue
		var e: Vector2i = r.get("border_tile", Vector2i(-1, -1))
		if e.x < 0 or e.y < 0:
			continue
		var tp := _tile_poly(e.x, e.y)
		var base := (tp[0] + tp[2]) * 0.5 + Vector2(-12, -4)
		var inf: Dictionary = GameGrid.ROAD_DESTINATION_NAMES.get(k, {})
		var label: String = String(inf.get("sign_title", "외부로 가는 길"))

		# 전통 목조 장승 기둥 + 상단 붉은 띠
		draw_line(base, base + Vector2(0, -32), Color("5c3a21"), 3.5)
		FastDraw.circle(self, base + Vector2(0, -33), 3.0, Color("7a4c28"))
		draw_line(base + Vector2(-3, -34), base + Vector2(3, -34), Color("9e2a2b"), 1.5)

		# 푯말 크기 동적 산출 (여백 포함)
		var str_sz: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		var pad_x: float = 6.0
		var pad_y: float = 3.0
		var rect := Rect2(base + Vector2(4, -30), Vector2(str_sz.x + pad_x * 2.0, str_sz.y + pad_y * 2.0))

		# 그림자 + 크림색 한지 바탕 + 목재 테두리
		draw_rect(Rect2(rect.position + Vector2(1, 1), rect.size), Color(0, 0, 0, 0.3))
		draw_rect(rect, Color("fffdf5"))
		draw_rect(rect, Color("6e4a2c"), false, 1.2)
		draw_string(font, rect.position + Vector2(pad_x, str_sz.y + 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("2c1810"))

func _draw_signpost_card() -> void:
	if grid == null or city._is_dragging:
		return
	var h: Vector2i = city.hover_cell
	var conn_map: Dictionary = grid.check_border_road_connections()
	var font := ThemeDB.fallback_font

	for k: String in ["jangan", "paldal", "changryong", "hwaseo"]:
		var r: Dictionary = conn_map.get(k, {})
		if not r.get("connected", false):
			continue
		var e: Vector2i = r.get("border_tile", Vector2i(-1, -1))
		if absi(h.x - e.x) > 1 or absi(h.y - e.y) > 1:
			continue

		var inf: Dictionary = GameGrid.ROAD_DESTINATION_NAMES.get(k, {})
		var n: int = 0
		if citizens:
			for a: Dictionary in citizens.agents:
				if a.get("gate_kind", "") == k:
					n += 1

		var desc_lines: PackedStringArray = String(inf.get("desc", "")).split("\n")
		var lines: Array[String] = [
			"🚩 %s (%s) — %s" % [inf.get("gate_name", "성문"), inf.get("dir", "외곽"), inf.get("sign_title", "")],
		]
		for dl: String in desc_lines:
			if dl != "":
				lines.append("   " + dl)
		lines.append("역사: " + String(inf.get("history", "")))
		lines.append("운반꾼 현황: %d명 왕래 중%s" % [n, (" · 사대문 전면 개통 가산" if grid.logistics != null and grid.logistics.all_connected() else "")])

		var wmax: float = 0.0
		for ln: String in lines:
			wmax = maxf(wmax, font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)

		var tp := _tile_poly(e.x, e.y)
		var anchor := (tp[0] + tp[2]) * 0.5 + Vector2(0, -42)
		var card_h: float = 16.0 * float(lines.size()) + 14.0
		var rect := Rect2(anchor - Vector2(wmax * 0.5 + 12, card_h), Vector2(wmax + 24, card_h))

		# 한지풍 짙은 묵색 배경 + 금빛 테두리
		draw_rect(rect, Color(0.12, 0.08, 0.05, 0.94))
		draw_rect(rect, Color("d4af37"), false, 1.5)
		for i: int in range(lines.size()):
			var col: Color = Color("fde68a") if i == 0 else Color("f5efe0")
			var fsz: int = 12 if i == 0 else 10
			draw_string(font, rect.position + Vector2(10, 18 + i * 16), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, col)
		return

# ============================================================ 주택가 놀이마당 · 관아 재판
func _cc(fx: float, fy: float) -> Vector2:
	var gx := clampi(int(fx), 0, grid.size - 1)
	var gy := clampi(int(fy), 0, grid.size - 1)
	return city.cell_center(fx, fy, float(grid.grid[gy][gx].get("elevation", 1.0)))

## 한복 입은 여인(치마 폭이 넓은 종 모양). braid면 댕기 땋은 처녀, 아니면 쪽진 아낙. arms: 팔 벌림(0~1)
func _woman(p: Vector2, jeogori: Color, chima: Color, braid: bool, arms: float = 0.0) -> void:
	FestivalArt.woman(self, p, jeogori, chima, braid, arms)

## PORT-TRACE [주택가 놀이마당]: 2x2 놀이마당 하나 = 그네(높은 두 기둥 + 가로대, 줄 타고 앞뒤로 크게 흔들리는 처녀)
## + 널뛰기(짚단 위 널판, 양 끝 두 여인이 번갈아 솟구침) + 구경하는 아낙들. 시간 t 하나로 그리는 장면(개별 NPC 없음).
## 겨울엔 그네를 매지 않고(단오 놀이) 설 널뛰기만, 여름엔 단오 그네가 더 높이.
func _draw_play_yards(cattle_only: bool = false) -> void:
	if _play_dirty:
		_play_yards = grid.list_plazas("play")
		_kid_yards = grid.list_plazas("kids")
		_cattle_yards = grid.list_plazas("cattle")
		_sea_spots.clear()
		for sy in range(grid.size):
			for sx2 in range(grid.size):
				var st: Dictionary = grid.grid[sy][sx2]
				var stb: String = st["building"]
				if (stb == "com_1" or stb == "com_2") and not st.has("zone_build") and String(st.get("trade", "")) in ["jeotgal", "salt"]:
					_sea_spots.append({"pos": Vector2i(sx2, sy), "kind": st["trade"]})
		for sp in grid.list_plazas("salt"):
			_sea_spots.append({"pos": Vector2i(int(sp["x0"]), int(sp["y0"]) + 1), "kind": "store"})
		_edu_spots.clear()
		_chapels.clear()
		for cy in range(grid.size):
			for cx in range(grid.size):
				if grid.grid[cy][cx].get("cheonju", false):
					_chapels.append(Vector2i(cx, cy))
		_gate_tiles.clear()
		for gy in range(grid.size):
			for gx in range(grid.size):
				if grid.grid[gy][gx]["building"] == "gate":
					_gate_tiles.append(Vector2i(gx, gy))
		_collect_work_spots()
		_market_plazas = grid.list_plazas("market").filter(func(pl: Dictionary) -> bool:
			var n0 := int(pl["n"])
			var half_n := int(float(n0) / 2.0)
			return not _near_gate(int(pl["x0"]) + half_n, int(pl["y0"]) + half_n, 2 + half_n))
		for ek: String in ["seodang", "seowon"]:
			for ep in grid.list_plazas(ek):
				_edu_spots.append({"kind": ek, "x0": int(ep["x0"]), "y0": int(ep["y0"]), "n": int(ep["n"])})
		_fort_spots.clear()
		for fy in range(grid.size):
			for fx in range(grid.size):
				var ft: Dictionary = grid.grid[fy][fx]
				var fb: String = ft["building"]
				if ft.has("wall_build"):
					continue
				if fb == "bongdon" and ft.has("bd4") and ft.get("site_anchor", Vector2i(-1, -1)) == Vector2i(fx, fy):
					_fort_spots.append({"kind": "bongdon", "anchor": Vector2i(fx, fy), "info": ft["bd4"]})
				elif fb == "seojangdae":
					_fort_spots.append({"kind": "seojangdae", "anchor": Vector2i(fx, fy), "big": ft.has("sj2")})
				elif fb == "yeonghwajeong":
					_fort_spots.append({"kind": "yeonghwajeong", "anchor": Vector2i(fx, fy)})
				elif fb == "hyanggyo":
					_edu_spots.append({"kind": "hyanggyo", "x0": fx - 1, "y0": fy - 1, "n": 4})
				elif fb == "yeonmudae" and ft.has("ym5"):
					_fort_spots.append({"kind": "yeonmudae", "anchor": Vector2i(fx, fy), "info": ft["ym5"]})
				elif fb == "poru" and ft.has("pr2") and ft.get("site_anchor", Vector2i(-1, -1)) == Vector2i(fx, fy):
					_fort_spots.append({"kind": "poru", "anchor": Vector2i(fx, fy), "info": ft["pr2"]})
				elif fb == "haenggung":
					_fort_spots.append({"kind": "haenggung", "anchor": Vector2i(fx, fy)})
				elif fb == "gongsimdon" and ft.has("gs3"):
					_fort_spots.append({"kind": "gongsimdon", "anchor": Vector2i(fx, fy), "info": ft["gs3"]})
		_play_dirty = false
	if cattle_only: # 호랑이 출현 중: 사람 놀이판은 쉬고, 쇠전의 매인 소만
		_draw_cattle_yards()
		return
	_draw_sea_scenes()
	_draw_modern_plazas()
	_draw_kid_yards()
	_draw_cattle_yards()
	if _play_yards.is_empty():
		return
	var bounds := _get_view_bounds()
	var t := _scene_t
	var play_modern := _modern_plaza_tex("play") != null
	for pl: Dictionary in _play_yards:
		if play_modern:
			break # 체육공원으로 바뀜(_draw_modern_plazas)
		var x0 := float(pl["x0"])
		var y0 := float(pl["y0"])
		var cen := _cc(x0 + 1.0, y0 + 1.0)
		if not bounds.has_point(cen):
			continue
		var ph := float(int(pl["x0"]) * 7 + int(pl["y0"]) * 13)
		# 구경꾼(뒷줄)
		_woman(_cc(x0 + 0.35, y0 + 0.3), Color("f4f0e4"), Color("6a7fa8"), false, maxf(0.0, sin(t * 3.0 + ph)) * 0.6)
		_woman(_cc(x0 + 1.7, y0 + 0.35), Color("f6e3a0"), Color("8a4a6a"), false, 0.0)
		if current_season != "겨울":
			# 그네: 뒤쪽 칸(0.5~1.5, y0+0.6)에 두 기둥, 가로대에서 줄
			var b0 := _cc(x0 + 0.45, y0 + 0.75)
			var b1 := _cc(x0 + 1.45, y0 + 0.75)
			var hgt := 52.0
			draw_line(b0, b0 - Vector2(0, hgt), Color("6e4a2c"), 2.2)
			draw_line(b1, b1 - Vector2(0, hgt), Color("6e4a2c"), 2.2)
			draw_line(b0 - Vector2(0, hgt), b1 - Vector2(0, hgt), Color("5c3a21"), 2.0)
			var pivot := (b0 + b1) * 0.5 - Vector2(0, hgt)
			var amp := 1.0 if current_season == "여름" else 0.75
			var th := sin(t * 1.7 + ph) * amp
			# 그네는 기둥 면에 수직(화면 앞뒤)으로 흔들린다 — 앞으로 나올수록 아래·옆으로
			var swing_dir := (_cc(x0 + 0.95, y0 + 1.3) - _cc(x0 + 0.95, y0 + 0.75)).normalized()
			var seat := pivot + Vector2(0, cos(th) * 40.0) + swing_dir * sin(th) * 30.0
			draw_line(pivot + Vector2(-3, 0), seat + Vector2(-3, 0), Color("d8c49a"), 0.9)
			draw_line(pivot + Vector2(3, 0), seat + Vector2(3, 0), Color("d8c49a"), 0.9)
			draw_line(seat + Vector2(-4, 0), seat + Vector2(4, 0), Color("6e4a2c"), 1.6)
			_woman(seat, Color("f6e3a0"), Color("c0392b"), true, 0.9)
			# 치맛자락 휘날림
			var flut := -swing_dir * signf(cos(t * 1.7 + ph)) * 3.0
			FastDraw.poly(self, PackedVector2Array([seat + Vector2(-4, -1), seat + Vector2(4, -1), seat + flut + Vector2(0, 3)]), Color("e0584a"))
		# 널뛰기: 앞쪽 칸(y0+1.5)에 짚단 + 널판
		var mid := _cc(x0 + 1.0, y0 + 1.5)
		var lft := _cc(x0 + 0.45, y0 + 1.5)
		var rgt := _cc(x0 + 1.55, y0 + 1.5)
		FastDraw.circle(self, mid + Vector2(0, -1.5), 3.4, Color("d8b85a"))
		draw_line(mid + Vector2(-3, -1.5), mid + Vector2(3, -1.5), Color("a8883a"), 0.7)
		var w := sin(t * 3.2 + ph)
		var hl := maxf(0.0, w) * 16.0   # 왼쪽 여인이 솟은 높이
		var hr := maxf(0.0, -w) * 16.0
		var tilt := w * 3.5            # 왼쪽 사람이 떠 있으면 반대쪽(오른쪽) 끝이 눌려 내려간다
		var el := lft + Vector2(0, -3.0 - tilt)
		var er := rgt + Vector2(0, -3.0 + tilt)
		draw_line(el, er, Color("8a5a32"), 2.4)
		# 널 양 끝에서 마주 본다: 왼쪽(뒤) 여인은 +x(오른쪽 아래)를 보는 앞모습, 오른쪽(앞) 여인은 -x(왼쪽 위)를 보는 뒷모습
		FestivalArt.woman(self, el - Vector2(0, hl), Color("f4f0e4"), Color("2e86c1"), true, 0.4 + 0.6 * (hl / 16.0), 0)
		FestivalArt.woman(self, er - Vector2(0, hr), Color("f6e3a0"), Color("8e44ad"), true, 0.4 + 0.6 * (hr / 16.0), 3)
		# 구경꾼(앞줄)
		_woman(_cc(x0 + 0.3, y0 + 1.95), Color("f4f0e4"), Color("4f8a5a"), false, maxf(0.0, sin(t * 2.6 + ph + 1.0)) * 0.7)
		FestivalArt.person(self, _cc(x0 + 1.85, y0 + 1.85), Color("f2eee4"), 2, 0.2, Color(0, 0, 0, 0), 0.8) # 꼬마

## 사또(붉은 관복 + 사모): 대청 의자에 앉음
func _satto(p: Vector2, arm: float) -> void:
	# PORT-TRACE [관아 소품]: 사용자 요청 — "도형 몇 개로만 표현되어 뭘 표현한 건지 모르겠다". 의자 네모·붉은 네모 대신
	# 사또가 대청 마루에 양반다리로 앉고, 앞에 낮은 서안(문서·붓·인궤)을 둔다. 판결할 때 손을 든다.
	var k := _sk()
	_spr_seat(p, "official", 0, Color("a82a2a"), 1)
	var d := p + Vector2(7, 4) * k # 서안: 사또 오른쪽 앞
	if not GoodsArt.draw(self, d + Vector2(0, 2) * k, "seoan", 0.75 * k):
		var top := PackedVector2Array([d + Vector2(-7, 0) * k, d + Vector2(0, -3.5) * k, d + Vector2(7, 0) * k, d + Vector2(0, 3.5) * k])
		for lg: Vector2 in [Vector2(-6, 0), Vector2(6, 0), Vector2(0, 3)]:
			draw_line(d + lg * k, d + (lg + Vector2(0, 3)) * k, Color("3e2814"), 1.0) # 다리
		FastDraw.poly(self, top, Color("6e4526"))
		FastDraw.polyline(self, PackedVector2Array(Array(top) + [top[0]]), Color("3e2814"), 0.6)
		FastDraw.poly(self, PackedVector2Array([d + Vector2(-4, 0) * k, d + Vector2(-0.5, -1.8) * k, d + Vector2(3, 0) * k, d + Vector2(-0.5, 1.8) * k]), Color("f2ead0")) # 문서
		draw_line(d + Vector2(-2.5, -0.2) * k, d + Vector2(1.5, -0.2) * k, Color(0.2, 0.15, 0.1, 0.7), 0.5)
		draw_rect(Rect2(d + Vector2(3.5, -2.2) * k, Vector2(2.2, 1.8) * k), Color("8e2a1e")) # 인궤(관인 상자)
		draw_line(d + Vector2(-5, 1) * k, d + Vector2(-2, 2.4) * k, Color("2a1a10"), 0.8) # 붓
	if arm > 0.0:
		draw_line(p + Vector2(4, -13) * k, p + Vector2(8, -16 - arm * 5.0) * k, Color("a82a2a"), 2.0 * k)
		FastDraw.circle(self, p + Vector2(8.5, -17 - arm * 5.0) * k, 1.2 * k, Color("ecc29a"))

## 나졸: 검은 전립(벙거지) + 붉은 쾌자, 곤장(swing 0~1)
func _najol(p: Vector2, swing: float, facing: float) -> void:
	# 나졸: 검은 전립 + 붉은 쾌자 도트, 곤장(swing 0~1)을 들었다 내리침 — 곤장은 자루 + 넓적한 노 모양 날
	var w := current_season == "겨울"
	NpcSprites.draw_kind(self, p, "najol", 0, w, 0 if facing > 0.0 else 1, 0)
	var k := _sk()
	var ang := -1.3 + swing * 1.9
	var hand := p + Vector2(4.5 * facing, -7) * k
	var dv := Vector2(cos(ang) * facing, sin(ang))
	var nv := Vector2(-dv.y, dv.x)
	var b0 := hand + dv * 4.0 * k
	var b1 := hand + dv * 13.0 * k
	draw_line(hand, b0, Color("5e3a1e"), 1.4 * k) # 자루
	FastDraw.poly(self, PackedVector2Array([b0 - nv * 0.9 * k, b1 - nv * 1.6 * k, b1 + nv * 1.6 * k, b0 + nv * 0.9 * k]), Color("8a3a22")) # 넓적한 날
	FastDraw.polyline(self, PackedVector2Array([b0 - nv * 0.9 * k, b1 - nv * 1.6 * k, b1 + nv * 1.6 * k, b0 + nv * 0.9 * k]), Color("3e1a10"), 0.5)

## 흰옷 죄인. pose: 0 꿇어앉음, 1 형틀에 엎드림, 2 목에 칼 쓰고 앉음
func _prisoner(p: Vector2, pose: int, facing: float = 1.0) -> void:
	var k := _sk()
	match pose:
		1:
			# 형틀(다리 넷 달린 긴 나무 틀)에 엎드림
			if not GoodsArt.draw(self, p + Vector2(-1, 1) * k, "hyeongteul", 0.9 * k):
				var bl := p + Vector2(-12, -5) * k
				var br := p + Vector2(9, -5) * k
				for lx: float in [-11.0, -3.0, 8.0]:
					draw_line(p + Vector2(lx, -5) * k, p + Vector2(lx, 0) * k, Color("3e2814"), 1.1)
				FastDraw.poly(self, PackedVector2Array([bl, br, br + Vector2(1.5, -2) * k, bl + Vector2(1.5, -2) * k]), Color("7a5230"))
			FastDraw.poly(self, PackedVector2Array([p + Vector2(-11, -7) * k, p + Vector2(7, -7) * k, p + Vector2(7, -11) * k, p + Vector2(-9, -11.5) * k]), Color("ece6d8")) # 엎드린 흰옷
			draw_line(p + Vector2(-11, -7) * k, p + Vector2(7, -7) * k, Color("8a8478"), 0.6)
			FastDraw.circle(self, p + Vector2(9.5 * facing, -9) * k, 2.6 * k, Color("e6bf98"))
			FastDraw.circle(self, p + Vector2(9.5 * facing, -10.5) * k, 2.3 * k, Color("1c1814")) # 산발
			draw_line(p + Vector2(-5, -6.5) * k, p + Vector2(-5, -12) * k, Color("8a6a3a"), 1.1) # 묶은 줄
			draw_line(p + Vector2(2, -6.5) * k, p + Vector2(2, -11.5) * k, Color("8a6a3a"), 1.1)
		2:
			# PORT-TRACE [칼 쓴 죄수]: 사진 고증 — 책상다리로 앉은 죄수의 목에 넓고 긴 널(칼)을 씌워, 널이 턱 바로 밑에서
			# 무릎 앞 땅까지 거의 곧게(앞으로 살짝 기울어) 내려와 몸통을 가린다. 얼굴은 널 위로 다 보이고, 목 양옆에 비녀(쇠막대).
			_spr_seat(p, "prisoner", 0 if facing > 0.0 else 1, Color("ddd6c6"))
			# 그림 배율(장면 축소 포함)로 턱 높이를 잰다 — 죄수 시트의 턱은 22줄, 앉은 그림은 39줄에서 자른다
			var sc := NpcSprites.adult_k(0.70) * (NpcSprites.SMALL_K if NpcSprites.small else 1.0)
			var chin := 0.5 * k + (39.0 - 22.5) * sc
			var top := p + Vector2(0.4 * facing * k, -chin + 1.0 * k)  # 턱 바로 밑(목 구멍)
			var bot := p + Vector2(2.4 * facing, 3.2) * k               # 무릎 앞 땅
			var hw_t := 8.0 * sc
			var hw_b := 9.0 * sc
			var plank := PackedVector2Array([top + Vector2(-hw_t, -0.6 * k), top + Vector2(hw_t, -0.6 * k), bot + Vector2(hw_b, 0), bot + Vector2(-hw_b, 0)])
			FastDraw.poly(self, plank, Color("6e5c48"))
			# 한쪽 옆면 두께(널이 판자처럼 보이게)와 나뭇결·옹이
			var side := 1.0 if facing > 0.0 else -1.0
			FastDraw.poly(self, PackedVector2Array([plank[1] if side > 0.0 else plank[0], (plank[1] if side > 0.0 else plank[0]) + Vector2(1.2 * side, 0.8) * k, (plank[2] if side > 0.0 else plank[3]) + Vector2(1.2 * side, 0.3) * k, plank[2] if side > 0.0 else plank[3]]), Color("4e4034"))
			for gx: float in [-0.45, 0.1, 0.5]:
				draw_line(top.lerp(top + Vector2(hw_t * gx, 0), 1.0) + Vector2(0, 1.5 * k), bot + Vector2(hw_b * gx, -1.0 * k), Color(0.27, 0.22, 0.17, 0.55), 0.5)
			FastDraw.circle(self, top.lerp(bot, 0.55) + Vector2(-1.6, 0) * k, 0.7 * k, Color("3e3226"))
			FastDraw.polyline(self, PackedVector2Array(Array(plank) + [plank[0]]), Color("2e241a"), 0.6)
			# 목 양옆 비녀(쇠막대)
			draw_line(top + Vector2(-hw_t - 1.8 * k, 0.2 * k), top + Vector2(hw_t + 1.8 * k, 0.2 * k), Color("2a2622"), 1.0)
		_:
			# 꿇어앉음 + 뒤로 묶은 포승
			_spr_seat(p, "prisoner", 0 if facing > 0.0 else 1, Color("ddd6c6"))
			draw_line(p + Vector2(-4, -11) * k, p + Vector2(4, -9.5) * k, Color("8a6a3a"), 1.1)
			draw_line(p + Vector2(-4, -8) * k, p + Vector2(4, -6.5) * k, Color("8a6a3a"), 1.1)

## PORT-TRACE [관아·옥사 2x2]: 관아 단지 장면 — 대청의 사또, 마당 양편 나졸, 재판 종류별 연출(화적·좀도둑 문초:
## 형틀에 엎드린 죄인에게 곤장 / 송사: 백성 둘이 꿇어앉아 아뢰고 사또가 판결), 옥사 안 칼 쓴 죄수들.
## 말풍선은 재판 진행도에 따라 한 번에 하나씩 바뀐다. 관아 수(보통 1~2곳)만큼만 그린다.
const TRIAL_LINES := {
	"bandit": [["satto", "네 이놈! 네 죄를 네가 알렷다!"], ["prisoner", "아이고 사또 나으리, 억울하옵니다!"], ["najol", "매우 쳐라! 하나요~"], ["najol", "둘이요~ 셋이요~"], ["satto", "저놈을 옥에 단단히 가두어라!"]],
	"thief": [["satto", "장터에서 남의 물건을 훔쳤느냐?"], ["prisoner", "배가 고파 그만… 잘못했습니다요!"], ["najol", "볼기 열 대요~"], ["satto", "옥에 가두고 장물은 돌려주어라."]],
	"lawsuit": [["a", "사또! 저놈이 제 논 물꼬를 막았습니다요!"], ["b", "아니옵니다, 제 땅이옵니다!"], ["satto", "양전 대장을 가져오너라."], ["satto", "물꼬는 반씩 나누어 쓰고 화해하렷다!"]],
}

func _draw_gwana_scenes() -> void:
	if citizens == null or citizens._gwana_cache.is_empty():
		return
	var bounds := _get_view_bounds()
	var t := _scene_t
	for gw: Vector2i in citizens._gwana_cache:
		if not grid.in_bounds(gw.x, gw.y):
			continue
		var tile: Dictionary = grid.grid[gw.y][gw.x]
		if tile["building"] != "gwana":
			continue
		var fx := float(gw.x)
		var fy := float(gw.y)
		# PORT-TRACE [관아 마당 자리]: (0,0) 동헌, (1,0) 원형 옥사, (0,1) 재판 마당, (1,1) 솟을삼문. 사람은 재판 마당 안쪽
		# (앞 담에서 떨어진 곳)과 삼문 밖에만 세운다.
		var hall := _cc(fx + 0.5, fy + 1.1) # 동헌 섬돌 앞
		if not bounds.has_point(hall):
			continue
		var trial := float(tile.get("gw_trial", 0.0))
		var kind := String(tile.get("gw_kind", ""))
		var yard := _cc(fx + 0.5, fy + 1.45)
		var lines: Array = TRIAL_LINES.get(kind, [])
		var speaker := ""
		var text := ""
		if trial > 0.0 and not lines.is_empty():
			var total := float(tile.get("gw_trial_len", trial))
			var idx := clampi(int((1.0 - trial / maxf(total, 0.1)) * float(lines.size())), 0, lines.size() - 1)
			speaker = lines[idx][0]
			text = lines[idx][1]
		# 옥사 죄수(칼 쓰고 앉음)
		var np := mini(4, int(tile.get("gw_prisoners", 0)))
		for i in range(np):
			_prisoner(_cc(fx + 1.18 + 0.3 * float(i % 2), fy + 0.12 + 0.3 * float(int(float(i) / 2.0)) + 0.08 * float(i % 2)), 2) # 옥사 안에 두 줄로 띄엄띄엄
		# 대청의 사또
		var satto_p := hall + Vector2(0, -3)
		_satto(satto_p, 1.0 if speaker == "satto" else 0.0)
		var najol_l := _cc(fx + 0.2, fy + 1.3)
		var najol_r := _cc(fx + 0.82, fy + 1.4)
		# 삼문 밖: 문지기 하나 + 18초마다 찾아오는 민원인(걸어와 서성이다 들어감)
		_najol(_cc(fx + 1.5, fy + 2.3), 0.0, 1.0)
		var gc := fmod(t + fx * 3.0, 18.0)
		if gc < 8.0:
			var pv := Vector2(fx + 1.55, fy + 3.4).lerp(Vector2(fx + 1.35, fy + 2.35), clampf(gc / 4.0, 0.0, 1.0))
			_yard_person(_cc(pv.x, pv.y), Color("e8dcc4"), 0, Vector2(0, -1), gc < 4.0, 0.3 * sin(t * 2.0), t)
		var who := Vector2.ZERO
		if trial > 0.0 and kind in ["bandit", "thief"]:
			_prisoner(yard, 1)
			var sw := 0.5 + 0.5 * sin(t * 4.0)
			_najol(najol_l, sw if speaker == "najol" else 0.0, 1.0)
			_najol(najol_r, 0.0, -1.0)
			who = {"satto": satto_p, "prisoner": yard, "najol": najol_l}.get(speaker, Vector2.ZERO)
		else:
			_najol(najol_l, 0.0, 1.0)
			_najol(najol_r, 0.0, -1.0)
			if trial > 0.0 and kind == "lawsuit":
				var pa := yard + Vector2(-9, 0)
				var pb := yard + Vector2(9, 2)
				FestivalArt.person(self, pa, Color("e8dcc4"), 2, 0.6 if speaker == "a" else 0.0, Color(0, 0, 0, 0), 0.85)
				FestivalArt.person(self, pb, Color("d8ccb0"), 1, 0.6 if speaker == "b" else 0.0, Color(0, 0, 0, 0), 0.85)
				who = {"satto": satto_p, "a": pa, "b": pb}.get(speaker, Vector2.ZERO)
		if text != "" and who != Vector2.ZERO:
			_draw_speech_bubble(who + Vector2(0, -20), text, "사또" if speaker == "satto" else "", true)

## 압송: 앞장선 포졸이 오랏줄로 흰옷 죄인을 끌고 간다
func _draw_prisoner_escort(p: Vector2, a: Dictionary) -> void:
	var sx := _face(a)
	var d2 := 0 if sx > 0 else 1
	var lead := p + Vector2(8 * sx, 0)
	var back := p + Vector2(-8 * sx, 0)
	_spr(back, "prisoner", a, 0, d2)
	_spr(lead, "najol", a, 0, d2)
	draw_line(back + Vector2(0, -12), lead + Vector2(-5.5 * sx, -7), Color("8a6a3a"), 0.8) # 오랏줄
	draw_line(back + Vector2(-3, -12), back + Vector2(3, -12), Color("8a6a3a"), 1.0) # 포승

# ============================================================ 어린이 골목 놀이터 · 수원 쇠전
## 아이(어른의 0.7배). boy면 더벅머리, 아니면 댕기 땋은 계집아이
func _kid(p: Vector2, robe: Color, boy: bool, arms: float = 0.0, _s: float = 0.68, dir: int = 0) -> void:
	# 아이 도트(머리 큰 아이 몸집). 사내아이는 더벅머리, 계집아이는 댕기 땋은 머리 + 붉은 치마
	# dir: 0 앞-오른, 1 앞-왼, 2 뒤-오른, 3 뒤-왼
	var key := NpcSprites.custom_kind("child_m" if boy else "child_f", robe, robe.darkened(0.12) if boy else Color("c0392b"), Color("c0392b"))
	NpcSprites.draw_kind(self, p, key, 0, current_season == "겨울", dir, clampi(roundi(arms * 3.0), 0, 3), "cheer")

## 말뚝박기 엎드린 아이: 다리는 그대로 세우고, 허리 위(머리·몸통)를 왼쪽 위(앞 아이 쪽)로 눕혀 그린다. 아이 뒷모습(왼쪽 위를 봄) 칸.
func _bent_kid(p: Vector2, robe: Color, boy: bool) -> void:
	var key := NpcSprites.custom_kind("child_m" if boy else "child_f", robe, robe.darkened(0.12) if boy else Color("c0392b"), Color("c0392b"))
	var sh := NpcSprites.sheet_for(key)
	if sh.is_empty():
		FastDraw.poly(self, PackedVector2Array([p + Vector2(-6, -7), p + Vector2(5, -7), p + Vector2(5, -12), p + Vector2(-6, -12)]), robe)
		return
	var tex: Texture2D = sh[0]
	var sc: float = 0.52 * _sk()
	var row := 96.0 # 2줄 = 뒤-왼쪽
	const HIP := 38.0 # 칸 안 허리 높이(머리 꼭대기 16, 발 46)
	# 다리(허리 아래)
	draw_texture_rect_region(tex, Rect2(p.x - 24.0 * sc, p.y + (HIP - 42.0) * sc, 48.0 * sc, (48.0 - HIP) * sc), Rect2(0, row + HIP, 48, 48.0 - HIP))
	# 허리 위: 허리를 축으로 왼쪽 위로 눕힘
	var hip := p + Vector2(0, (HIP - 42.0) * sc)
	# 꺾인 허리 바깥쪽 부채꼴 빈틈: 허리 몇 줄을 0에서 눕힌 각도까지 조금씩 돌려 겹쳐 그려 옷으로 메운다
	const BEND := -1.25
	const SEAM := 7.0 # 메움에 쓰는 허리 위 줄 수
	for si in range(6):
		NpcSprites.set_xf(self, hip, BEND * float(si) / 6.0, Vector2(sc, sc))
		draw_texture_rect_region(tex, Rect2(-24.0, -SEAM, 48.0, SEAM), Rect2(0, row + HIP - SEAM, 48, SEAM))
	NpcSprites.set_xf(self, hip, BEND, Vector2(sc, sc))
	draw_texture_rect_region(tex, Rect2(-24.0, 14.0 - HIP, 48.0, HIP - 14.0), Rect2(0, row + 14.0, 48, HIP - 14.0))
	NpcSprites.reset_xf(self)

## 강아지(백구/황구): 꼬리를 흔들며 달림. sx = 좌우 방향
func _dog(p: Vector2, col: Color, sx: float, t: float) -> void:
	AnimalSprites.draw(self, p, "dog", int(t * 8.0), sx > 0.0, col)

## PORT-TRACE [어린이 골목 놀이터]: 2x2 놀이터 하나 = 말뚝박기(느티나무에 기댄 말뚝 아이 + 허리 잡고 엎드린 아이들,
## 뒤에서 달려와 등에 올라타는 아이) + 술래잡기(술래가 둥글게 쫓음) + 제기차기(제기가 오르내림) + 아이들 쫓는 백구·황구.
## 아이 4~5명과 강아지 둘을 시간 t 하나로 그린다(개별 NPC 없음).
func _draw_kid_yards() -> void:
	if _kid_yards.is_empty():
		return
	var bounds := _get_view_bounds()
	var t := _scene_t
	var robes: Array[Color] = [Color("f4f0e4"), Color("e8b8c8"), Color("b8d0e8"), Color("f6e3a0"), Color("c8e0b8")]
	if _modern_plaza_tex("kids") != null:
		return # 어린이 놀이터로 바뀜(_draw_modern_plazas)
	for pl: Dictionary in _kid_yards:
		var x0 := float(pl["x0"])
		var y0 := float(pl["y0"])
		var cen := _cc(x0 + 1.0, y0 + 1.0)
		if not bounds.has_point(cen):
			continue
		var ph := float(int(pl["x0"]) * 5 + int(pl["y0"]) * 11)
		# 말뚝박기: 나무(기준 칸) 앞에 말뚝 아이 서고, 엎드린 아이 둘이 줄지어 허리를 잡음
		var post := _cc(x0 + 0.55, y0 + 0.6)
		_kid(post, robes[0], true, 0.3)
		# PORT-TRACE [엎드린 아이]: 네모 도형 대신 아이 그림(뒷모습)을 허리에서 꺾어 앞 아이 엉덩이에 머리를 박은 모습으로
		var kk := _sk()
		var b0 := post + Vector2(12.5, 0.5) * kk
		var bend: Array[Vector2] = [b0, b0 + Vector2(12.5, 2.7) * kk]
		for i in range(2):
			_bent_kid(bend[i], robes[1 + i], i == 0)
		# 달려와 뛰어오르는 아이(4초 주기: 달리기 → 도약 → 등에 앉음)
		var cyc := fmod(t * 0.25 + ph * 0.01, 1.0)
		var run_from := _cc(x0 + 1.8, y0 + 1.4)
		var land := bend[1] + Vector2(-4, -5) * kk
		var jp: Vector2
		if cyc < 0.5:
			jp = run_from.lerp(bend[1] + Vector2(6, 0), cyc / 0.5)
		elif cyc < 0.65:
			var k := (cyc - 0.5) / 0.15
			jp = (bend[1] + Vector2(6, 0)).lerp(land, k) - Vector2(0, sin(k * PI) * 10.0)
		else:
			jp = land
		# 오른쪽 아래에서 엎드린 아이들(왼쪽 위) 쪽으로 달려가므로 엎드린 아이와 같은 뒤-왼쪽 뒷모습
		_kid(jp, robes[3], true, 0.8 if cyc < 0.65 else 0.2, 0.68, 3)
		# 제기차기: 한쪽 발을 들썩, 제기가 오르내림
		var jg := _cc(x0 + 0.4, y0 + 1.6)
		if not FestivalArt._act(self, jg, "act_jegi", t, 4.0, false, 0.52):
			_kid(jg, robes[4], true, 0.2)
			var up := absf(sin(t * 3.0 + ph))
			draw_line(jg + Vector2(2, -1), jg + Vector2(6, -2 - up * 4.0), Color("5a4a38"), 1.6) # 차올린 발
			var jegi := jg + Vector2(6, -12 - up * 18.0)
			FastDraw.circle(self, jegi, 1.2, Color("8a8a8a"))
			draw_line(jegi, jegi + Vector2(-1, -3), Color("e8453a"), 0.8)
			draw_line(jegi, jegi + Vector2(1, -3), Color("f4d03f"), 0.8)
		# 술래잡기: 술래가 빙 돌며 쫓고 한 아이가 도망
		var rc := _cc(x0 + 1.35, y0 + 1.35)
		var ang := t * 1.6 + ph
		var flee := rc + Vector2(cos(ang) * 18.0, sin(ang) * 8.0)
		var tag := rc + Vector2(cos(ang - 0.9) * 18.0, sin(ang - 0.9) * 8.0)
		_kid(flee, robes[1], false, 0.5)
		_kid(tag, robes[2], true, 0.9)
		# 강아지 둘: 백구는 술래 뒤를 쫓고, 황구는 말뚝박기 마당 앞을 제멋대로 오가며 뛰논다(아이와 따로 움직임)
		var d1 := rc + Vector2(cos(ang - 1.6) * 18.0, sin(ang - 1.6) * 8.0)
		_dog(d1, Color("f2eee4"), -1.0 if sin(ang - 1.6) > 0.0 else 1.0, t)
		var dw := t * 0.9 + ph
		var d2 := run_from + Vector2(-8.0 + sin(dw) * 14.0, 9.0 + sin(dw * 1.9) * 3.0) * kk
		_dog(d2, Color("c8903a"), 1.0 if cos(dw) > 0.0 else -1.0, t + 1.0)

## PORT-TRACE [수원 쇠전 3x3]: 말뚝 줄에 매인 소 일곱(제자리에서 조금씩 서성이며 방향을 바꿈)과 소장수가 고삐를 끌고
## 마당을 한 바퀴 도는 소 한 마리, 매인 소를 차례로 찾아가 이빨을 보고 흥정하는 거간꾼과 손님(말풍선이 번갈아),
## 주막 평상에서 막걸리 사발을 드는 두 사람. 개별 NPC 없이 시간 t 하나로 위치를 계산한다(화면 밖이면 그리지 않음).
const COW_TALK := ["이빨 좀 봅시다… 일곱 살배기구먼.", "힘 좋은 일소요, 열닷 냥!", "에이, 열두 냥에 합시다!", "열석 냥, 더는 못 깎소!", "좋소, 손뼉 칩시다!"]
## 매인 소 자리(쇠전 안 좌표 0~3)와 털빛
const YARD_COWS := [[0.35, 1.3, Color("b07838")], [0.95, 1.3, Color("8a5a32")], [1.55, 1.3, Color("c08a48")], [2.15, 1.3, Color("6a4026")],
	[0.35, 2.3, Color("9a6a3a")], [0.95, 2.3, Color("c89a58")], [1.55, 2.3, Color("7a4a2a")]]
## 소장수가 소를 끌고 도는 길(쇠전 안 좌표, 닫힌 고리)
const YARD_LOOP := [Vector2(0.4, 0.8), Vector2(1.8, 0.8), Vector2(2.6, 1.7), Vector2(2.6, 2.75), Vector2(0.4, 2.75)]
const YARD_LOOP_SPEED := 0.22 # 칸/초
const BROKER_VISIT := 9.0      # 거간꾼이 소 한 마리에 쓰는 시간(초): 앞 2.5초 걷기 + 흥정

## 닫힌 고리 위에서 거리 d만큼 간 곳과 그때의 진행 방향
func _loop_point(d: float) -> Array:
	var total := 0.0
	for i in YARD_LOOP.size():
		total += (YARD_LOOP[(i + 1) % YARD_LOOP.size()] as Vector2).distance_to(YARD_LOOP[i])
	d = fposmod(d, total)
	for i in YARD_LOOP.size():
		var a: Vector2 = YARD_LOOP[i]
		var b: Vector2 = YARD_LOOP[(i + 1) % YARD_LOOP.size()]
		var seg := a.distance_to(b)
		if d <= seg:
			return [a.lerp(b, d / seg), (b - a).normalized()]
		d -= seg
	return [YARD_LOOP[0], Vector2(1, 0)]

## 쇠전 안 사람(도트 인물). walking이면 걷는 동작, 아니면 팔 든 정도 arm(0~1)로 서 있는 자세
func _yard_person(p: Vector2, robe: Color, hat: int, gdir: Vector2, walking: bool, arm: float, t: float) -> void:
	var base := "yangban" if hat == 1 else ("commoner_m" if hat == 0 else "bearer")
	var acc := Color("b8352a") if hat == 1 else robe.darkened(0.25)
	var key := NpcSprites.custom_kind(base, robe, robe.darkened(0.06), acc, {})
	var dir := NpcSprites.dir_of({"dir": gdir})
	var winter := current_season == "겨울"
	if walking:
		NpcSprites.draw_kind(self, p, key, 0, winter, dir, int(t * 6.0) % NpcSprites.FRAMES)
	else:
		NpcSprites.draw_kind(self, p, key, 0, winter, dir, clampi(roundi(arm * 3.0), 0, 3), "cheer")

func _draw_cattle_yards() -> void:
	if _cattle_yards.is_empty():
		return
	var bounds := _get_view_bounds()
	var t := _scene_t
	for pl: Dictionary in _cattle_yards:
		var x0 := float(pl["x0"])
		var y0 := float(pl["y0"])
		var cen := _cc(x0 + 1.5, y0 + 1.5)
		if not bounds.grow(120.0).has_point(cen):
			continue
		var items: Array = [] # [화면 y, 종류, 자료…] — 앞뒤 순서대로 그리려고 모은다
		# 1) 매인 소: 말뚝 줄 따라 조금씩 서성이고, 가끔 몸을 돌린다
		for i in YARD_COWS.size():
			var cw: Array = YARD_COWS[i]
			var ph := float(i) * 1.7
			var lp := Vector2(float(cw[0]) + 0.12 * sin(t * 0.35 + ph), float(cw[1]) + 0.05 * sin(t * 0.27 + ph * 0.6))
			var face := 1.0 if sin(t * 0.11 + float(i) * 2.1) > 0.0 else -1.0
			items.append([_cc(x0 + lp.x, y0 + lp.y), "cow", face, cw[2], t * 0.15 + float(i)])
		# 2) 고삐에 끌려 마당을 도는 소 + 앞서 걷는 소장수
		var d := t * YARD_LOOP_SPEED
		var cow_at: Array = _loop_point(d)
		var man_at: Array = _loop_point(d + 0.32)
		var cow_lp: Vector2 = cow_at[0]
		var man_lp: Vector2 = man_at[0]
		var cow_p := _cc(x0 + cow_lp.x, y0 + cow_lp.y)
		var man_p := _cc(x0 + man_lp.x, y0 + man_lp.y)
		var cow_dir: Vector2 = cow_at[1]
		var scr_dx := (cow_dir.x - cow_dir.y) # 화면 가로 방향(격자 x는 오른쪽 아래, y는 왼쪽 아래)
		items.append([cow_p, "cow", 1.0 if scr_dx >= 0.0 else -1.0, Color("a86a34"), t * 0.6])
		items.append([man_p, "walker", man_at[1], Color("e8dcc4"), 2, cow_p])
		# 3) 거간꾼과 손님: 매인 소를 차례로 찾아가 흥정
		var visit := int(t / BROKER_VISIT)
		var in_visit := fmod(t, BROKER_VISIT)
		var tgt: Array = YARD_COWS[visit % YARD_COWS.size()]
		var prev: Array = YARD_COWS[(visit + YARD_COWS.size() - 1) % YARD_COWS.size()]
		var stand := Vector2(float(tgt[0]) - 0.3, float(tgt[1]) + 0.18)
		var from := Vector2(float(prev[0]) - 0.3, float(prev[1]) + 0.18)
		var walking := in_visit < 2.5
		var bk := from.lerp(stand, clampf(in_visit / 2.5, 0.0, 1.0))
		var gd := (stand - from).normalized() if walking else Vector2(1, 0) # 흥정할 땐 소 쪽(격자 +x)을 본다
		var buyer_lp := bk + Vector2(-0.1, 0.32)
		var broker_p := _cc(x0 + bk.x, y0 + bk.y)
		var buyer_p := _cc(x0 + buyer_lp.x, y0 + buyer_lp.y)
		items.append([broker_p, "person", gd, Color("d8ccb0"), 1, walking, 0.6 + 0.3 * sin(t * 3.0)])
		items.append([buyer_p, "person", gd if walking else Vector2(0.6, -0.8).normalized(), Color("c8d4e0"), 0, walking, 0.0])
		# 4) 주막 평상(오른쪽 모서리): 막걸리 사발을 드는 두 사람
		var jm := _cc(x0 + 2.5, y0 + 0.6)
		var cheers := 0.5 + 0.5 * sin(t * 1.5)
		items.append([jm + Vector2(-10, 2), "person", Vector2(1, 0), Color("e8dcc4"), 1, false, cheers])
		items.append([jm + Vector2(10, 3), "person", Vector2(0, 1), Color("d8ccb0"), 2, false, 1.0 - cheers])
		items.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2).y < (b[0] as Vector2).y)
		for it: Array in items:
			var ip: Vector2 = it[0]
			match String(it[1]):
				"cow":
					_draw_ox(ip, {"anim": float(it[4])}, float(it[2]), it[3])
				"walker":
					_yard_person(ip, it[3], int(it[4]), it[2], true, 0.0, t)
					var hand := ip + Vector2(0, -9)
					var muzzle: Vector2 = (it[5] as Vector2) + Vector2(0, -8)
					draw_line(hand, muzzle, Color("6b4a2a"), 1.0) # 고삐
				"person":
					_yard_person(ip, it[3], int(it[4]), it[2], bool(it[5]), float(it[6]), t)
		FastDraw.circle(self, jm + Vector2(-4, -12 - cheers * 9.0), 2.0, Color("f4f0e4")) # 막걸리 사발
		FastDraw.circle(self, jm + Vector2(16, -11 - (1.0 - cheers) * 9.0), 2.0, Color("f4f0e4"))
		# 흥정 말풍선: 소 앞에 섰을 때만 거간꾼·손님이 번갈아
		if not walking:
			var phase := int((in_visit - 2.5) / 3.2) % COW_TALK.size()
			var talk_i := (visit * 2 + phase) % COW_TALK.size()
			_draw_speech_bubble((broker_p if phase % 2 == 0 else buyer_p) + Vector2(0, -22), COW_TALK[talk_i], "")

# ============================================================ 화서문 어염시장 장면
## PORT-TRACE [화서문 어염시장]: 젓갈 가게 = 상인이 독에서 국자로 젓갈을 퍼 보이고 손님이 고개를 숙여 냄새를 맡으며 흥정,
## 소금 가게·소금 창고 = 상인이 됫박으로 소금을 떠 손님 자루에 부어 줌(흰 알갱이가 흘러내림). 가게 앞 길가에서 시간 t 하나로
## 그린다(개별 NPC 없음). 화면에 보이는 곳 중 최대 10곳만, 말풍선은 가게마다 엇갈려 가끔씩.
const JEOTGAL_TALK := ["곰삭은 새우젓 맛 좀 보시오!", "음~ 냄새 좋구먼. 한 종지에 얼마요?", "두 푼이오, 김장엔 이게 최고요!", "한 푼 반에 주시오!"]
const SALT_TALK := ["한 됫박 수북이 담아 드리리다!", "서해 천일염이라 짜고 달다오.", "김장할 소금 닷 되만 주시오."]
func _draw_sea_scenes() -> void:
	if _sea_spots.is_empty():
		return
	var bounds := _get_view_bounds()
	var t := _scene_t
	var drawn := 0
	for sp: Dictionary in _sea_spots:
		if drawn >= 10:
			break
		var pos: Vector2i = sp["pos"]
		var ce: Array = grid.tile(pos.x, pos.y).get("corner_elev", [1.0, 1.0, 1.0, 1.0])
		var p_n := city.cell_center(pos.x, pos.y, ce[0])
		var p_e := city.cell_center(pos.x + 1, pos.y, ce[1])
		var p_s := city.cell_center(pos.x + 1, pos.y + 1, ce[2])
		var p_w := city.cell_center(pos.x, pos.y + 1, ce[3])
		var c := (p_n + p_e + p_s + p_w) * 0.25
		if not bounds.has_point(c):
			continue
		drawn += 1
		var fr: Array = city._front_frame(pos.x, pos.y, c, p_n, p_e, p_s, p_w)
		var a: Vector2 = fr[0]
		var f: Vector2 = fr[1]
		var ph := float(pos.x * 7 + pos.y * 3)
		var seller := MarketArt.P(c, a, f, -0.25, 0.9)
		var buyer := MarketArt.P(c, a, f, 0.35, 1.05)
		var kind: String = sp["kind"]
		var talk_i := int(t / 3.0 + ph) % 4
		if kind == "jeotgal":
			# 상인 옆 작은 독 + 국자질(퍼 올렸다 내밀기)
			FastDraw.circle(self, seller + Vector2(6, -3), 3.0, Color("5e3a22"))
			var sc := 0.5 + 0.5 * sin(t * 1.8 + ph)
			FestivalArt.person(self, seller, Color("e8dcc4"), 2, sc * 0.6)
			var ladle := seller + Vector2(6, -6 - sc * 6.0)
			draw_line(seller + Vector2(4, -9), ladle, MarketArt.TIMBER, 0.9)
			FastDraw.circle(self, ladle, 1.4, Color("e8a0a0"))
			# 손님: 고개를 숙여 냄새 맡기(몸을 앞으로 기울임)
			var sniff := maxf(0.0, sin(t * 1.8 + ph - 0.8)) * 3.0
			FestivalArt.person(self, buyer + Vector2(-sniff, sniff * 0.6), Color("d8ccb0"), 1, 0.2)
			if talk_i % 2 == 0 and int(t / 3.0 + ph) % 3 == 0:
				var line: String = JEOTGAL_TALK[int(t / 3.0 + ph) % JEOTGAL_TALK.size()]
				_draw_speech_bubble((seller if line.ends_with("시오!") or line.ends_with("최고요!") else buyer) + Vector2(0, -22), line, "")
		else:
			# PORT-TRACE [소금 됫박질]: 됫박이 사람 머리 높이로 날아가 "손님 머리에 소금을 던지는" 것처럼 보였다 →
			# 상인이 됫박을 손에 쥔 채 곁의 소금 섬에서 떠서(허리 높이) 둘 사이 바닥에 벌려 둔 손님 자루에 붓는다.
			var cyc := fmod(t * 0.5 + ph * 0.1, 1.0)
			var sack := seller + Vector2(-6, 1)
			if not GoodsArt.draw(self, sack + Vector2(0, 1), "salt_sack", 0.8):
				FastDraw.poly(self, PackedVector2Array([sack + Vector2(-3.5, 0), sack + Vector2(3.5, 0), sack + Vector2(3, -6), sack + Vector2(-3, -6)]), Color("d8c48a"))
				FastDraw.circle(self, sack + Vector2(0, -6), 2.6, Color("fafaf6"))
			var bag := seller.lerp(buyer, 0.55) + Vector2(0, 1.5)
			FestivalArt.person(self, seller, Color("e8dcc4"), 2, 0.15)
			FestivalArt.person(self, buyer, Color("d8ccb0"), 1, 0.25)
			FastDraw.poly(self, PackedVector2Array([bag + Vector2(-2.8, 0), bag + Vector2(2.8, 0), bag + Vector2(3.2, -5), bag + Vector2(-3.2, -5)]), Color("c8b896")) # 아가리 벌린 자루
			FastDraw.poly(self, PackedVector2Array([bag + Vector2(-3.2, -5), bag + Vector2(3.2, -5), bag + Vector2(2.4, -4), bag + Vector2(-2.4, -4)]), Color("8a7a58"))
			# 뜨기(0~0.35) → 옮기기(0.35~0.6) → 붓기(0.6~1)
			var u := 0.0 if cyc < 0.35 else (clampf((cyc - 0.35) / 0.25, 0.0, 1.0))
			var doe: Vector2 = (sack + Vector2(0, -6)).lerp(bag + Vector2(0, -7.5), u) + Vector2(0, -sin(u * PI) * 2.0)
			draw_line(seller + Vector2(1.5, -12), doe + Vector2(0, -1), Color("e8c9a0"), 1.2) # 팔
			var tilt := clampf((cyc - 0.6) / 0.15, 0.0, 1.0)
			var dq := PackedVector2Array([doe + Vector2(-2.2, -1.5), doe + Vector2(2.2, -1.5 + tilt * 1.5), doe + Vector2(2.2, 1.5 + tilt * 1.5), doe + Vector2(-2.2, 1.5)])
			FastDraw.poly(self, dq, Color("8a6236")) # 됫박
			if tilt < 0.5:
				FastDraw.circle(self, doe + Vector2(0, -1.8), 1.5, Color("fafaf6"))
			if cyc > 0.65:
				for k in range(3):
					FastDraw.circle(self, doe + Vector2(1.5 + float(k) * 0.4, 2.0 + fmod(t * 6.0 + float(k), 3.0)), 0.55, Color("ffffff")) # 흘러내리는 소금
			if int(t / 3.0 + ph) % 3 == 0:
				_draw_speech_bubble(seller + Vector2(0, -22), SALT_TALK[int(t / 3.0 + ph) % SALT_TALK.size()], "")

## PORT-TRACE [종루(여민각) 2x2]: 타종 순간 3초 — 종 둘레로 퍼지는 소리 물결 고리 + "댕~" 글자
func _draw_bell_ring() -> void:
	if citizens == null or citizens.bell_ring_t <= 0.0 or citizens._jongnu.x < 0:
		return
	var j: Vector2i = citizens._jongnu
	var c := _cc(float(j.x) + 1.0, float(j.y) + 1.0) - Vector2(0, 24)
	var k := 1.0 - citizens.bell_ring_t / 3.0
	for i in range(3):
		var r := fmod(k * 3.0 + float(i) / 3.0, 1.0)
		FastDraw.arc(self, c, 10.0 + r * 70.0, 0.0, TAU, 32, Color(1.0, 0.92, 0.6, (1.0 - r) * 0.7), 1.6)
	draw_string(ThemeDB.fallback_font, c + Vector2(14, -30 - k * 10.0), "댕~", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.95, 0.75, 1.0 - k))

# ============================================================ 2단계: 봉돈·서장대·영화정 장면
## PORT-TRACE [봉돈·서장대·영화정 연출]: 건물마다 시간 t 하나로 그리는 장면(화면 밖이면 건너뜀).
## 봉돈: 평시 연조 하나에서 연기(봉수 1거), 도적 침입·야조 때는 다섯 연조 모두 봉화(불꽃+연기). 위에서 수비병 둘이
## 깃발·횃불로 신호를 주고받음. 서장대: 평시 경계병 둘이 순찰, 30초마다 교대식(넷이 오가며 "교대하오!"),
## 야조 때 어둑한 밤빛 + 사방 수백 횃불 + 청사초롱 + 오방기 + 지휘 말풍선. 영화정: 만석거 물비늘 + 거니는 관리·나그네.
func _draw_fort_scenes() -> void:
	if _fort_spots.is_empty():
		return
	var bounds := _get_view_bounds()
	var t := _scene_t
	var alarm := citizens != null and (citizens.is_bandit_raid_active() or citizens.yajo_t > 0.0)
	for fs: Dictionary in _fort_spots:
		var a: Vector2i = fs["anchor"]
		match String(fs["kind"]):
			"bongdon":
				var tops: Array[Vector2] = city.bongdon_chimney_tops(fs["info"])
				if not bounds.has_point(tops[2]):
					continue
				for k in range(5):
					if not alarm and k != 0:
						continue
					var tp: Vector2 = tops[k]
					if alarm:
						for f in range(3):
							var fl := sin(t * 12.0 + float(k * 3 + f)) * 1.5
							FastDraw.circle(self, tp + Vector2(fl, -2.0 - f * 2.5), 3.0 - f * 0.8, [Color("f5a030"), Color("ffd060"), Color("fff0a0")][f])
					for p in range(4):
						var ph := fmod(t * 0.6 + float(p) * 0.25 + float(k) * 0.13, 1.0)
						FastDraw.circle(self, tp + Vector2(sin(ph * 6.0 + float(k)) * 3.0 + ph * 6.0, -6.0 - ph * 30.0), 2.5 + ph * 5.0, Color(0.85, 0.85, 0.85, 0.55 * (1.0 - ph)) if not alarm else Color(0.5, 0.48, 0.45, 0.6 * (1.0 - ph)))
				# 수비병 둘: 깃발 신호 ↔ 횃불 응답
				var g1: Vector2 = tops[1] + Vector2(0, 14)
				var g2: Vector2 = tops[3] + Vector2(0, 14)
				_najol(g1, 0.0, 1.0)
				_najol(g2, 0.0, -1.0)
				var up := 0.5 + 0.5 * sin(t * 1.5)
				draw_line(g1 + Vector2(3, -9), g1 + Vector2(3, -22 - up * 4.0), Color("5c3a21"), 0.9)
				draw_rect(Rect2(g1 + Vector2(3, -22 - up * 4.0), Vector2(6, 4)), Color("c0392b") if int(t / 2.0) % 2 == 0 else Color("e8b820"))
				draw_line(g2 + Vector2(-3, -9), g2 + Vector2(-3, -18), Color("5c3a21"), 0.9)
				FastDraw.circle(self, g2 + Vector2(-3, -19 - (1.0 - up) * 3.0), 2.2, Color("ffb040"))
			"seojangdae":
				var big: bool = fs["big"]
				var cen := _cc(float(a.x) + (1.0 if big else 0.5), float(a.y) + (1.0 if big else 0.5)) - Vector2(0, 10)
				if not bounds.has_point(cen):
					continue
				if citizens.sim != null and citizens.sim.is_eulmyo_active:
					continue # 을묘원행 사열·야조는 RoyalProcessionManager가 그린다
				if citizens.yajo_t > 0.0:
					_draw_yajo(cen, t)
				else:
					_draw_seojangdae_watch(a, 2 if big else 1, t)
			"yeonmudae":
				if citizens.sim != null and citizens.sim.is_eulmyo_active:
					continue # 을묘원행 친림 활쏘기는 RoyalProcessionManager가 그린다
				_draw_yeonmudae_scene(fs["info"], bounds, t)
			"gongsimdon":
				_draw_gongsimdon_patrol(fs["info"], bounds, t)
			"poru":
				_draw_poru_scene(fs["info"], bounds, t)
			"haenggung":
				if citizens.sim != null and citizens.sim.is_eulmyo_active:
					continue # 을묘원행 의례(RoyalProcessionManager)가 마당을 쓴다
				_draw_haenggung_court(a, bounds, t)
				_draw_jangyong(a, bounds, t)
			"yeonghwajeong":
				var cen2 := _cc(float(a.x) + 1.0, float(a.y) + 1.0)
				if not bounds.has_point(cen2):
					continue
				var fd: Vector2i = city.yeonghwajeong_front(a)
				var front := _cc(float(a.x) + 1.0 + float(fd.x) * 1.6, float(a.y) + 1.0 + float(fd.y) * 1.6)
				# 물비늘(만석거 쪽)
				for i in range(6):
					var ph2 := fmod(t * 0.4 + float(i) * 0.17, 1.0)
					var wp := front.lerp(_cc(float(a.x) + 1.0 + float(fd.x) * 3.0, float(a.y) + 1.0 + float(fd.y) * 3.0), float(i) / 6.0) + Vector2(sin(float(i) * 2.3) * 14.0, 0)
					draw_line(wp + Vector2(-3, 0), wp + Vector2(3, 0), Color(1, 1, 1, 0.6 * sin(ph2 * PI)), 1.0)
				# 거니는 관리(푸른 관복)·나그네(봇짐)
				var walk := sin(t * 0.25) * 16.0
				var side := (_cc(float(a.x) + 1.0 + float(fd.y), float(a.y) + 1.0 + float(fd.x)) - cen2).normalized()
				var off := (front - cen2) * 0.45
				FestivalArt.person(self, cen2 + off + side * walk, Color("2a4a8a"), 1, 0.1)
				var traveler_pos := cen2 + off * 0.8 - side * (walk * 0.7 + 8.0)
				FestivalArt.person(self, traveler_pos, Color("e8dcc4"), 1, 0.0)
				draw_rect(Rect2(traveler_pos + Vector2(-5, -10), Vector2(4, 4)), Color("8a6a3a"))
				if int(t / 9.0) % 3 == 0:
					_draw_speech_bubble(cen2 + off + side * walk + Vector2(0, -20), "만석거 물빛이 참 좋구나.", "")

## PORT-TRACE [서장대 평시]: 누각 위가 아니라 산정 앞자락(묶음 바깥, 화면 앞쪽 두 변)에서 — 앞 모서리 양옆에 창 든 보초 둘,
## 앞쪽 두 변을 따라 ㄱ자로 오가는 순찰병 하나, 30초마다 아래에서 올라오는 교대조 둘("교대하오! 이상 없소!").
func _draw_seojangdae_watch(a: Vector2i, n: int, t: float) -> void:
	var fx := float(a.x)
	var fy := float(a.y)
	var nf := float(n)
	_najol(_cc(fx + nf + 0.3, fy + nf - 0.45), 0.0, -1.0)
	_najol(_cc(fx + nf - 0.45, fy + nf + 0.3), 0.0, 1.0)
	# 순찰: 오른쪽 변(+x 바깥) ↔ 앞 모서리 ↔ 왼쪽 변(+y 바깥)을 왕복
	var path: Array[Vector2] = [Vector2(fx + nf + 0.35, fy + 0.3), Vector2(fx + nf + 0.35, fy + nf + 0.35), Vector2(fx + 0.3, fy + nf + 0.35)]
	var u := fmod(t * 0.05, 2.0)
	var k := u if u < 1.0 else 2.0 - u
	var gp: Vector2 = path[0].lerp(path[1], k * 2.0) if k < 0.5 else path[1].lerp(path[2], (k - 0.5) * 2.0)
	var dv := (_cc(gp.x + 0.05, gp.y) - _cc(gp.x, gp.y)) if k < 0.5 else (_cc(gp.x, gp.y + 0.05) - _cc(gp.x, gp.y))
	if u >= 1.0:
		dv = -dv
	_najol(_cc(gp.x, gp.y), 0.0, 1.0 if dv.x >= 0.0 else -1.0)
	var cyc := fmod(t, 30.0)
	if cyc < 5.0:
		var k2 := cyc / 5.0
		var p0 := Vector2(fx + nf + 1.6, fy + nf + 1.6).lerp(Vector2(fx + nf + 0.65, fy + nf + 0.65), k2)
		_najol(_cc(p0.x, p0.y), 0.0, -1.0)
		_najol(_cc(p0.x + 0.25, p0.y + 0.1), 0.0, -1.0)
		_draw_speech_bubble(_cc(p0.x, p0.y) + Vector2(0, -24), "교대하오! 이상 없소!", "", true)

## 야조: 어둑한 밤빛, 사방 수백 횃불(깜빡임), 누각 둘레 청사초롱, 오방기 다섯, 지휘 말풍선
func _draw_yajo(cen: Vector2, t: float) -> void:
	var dark := PackedVector2Array()
	for i in range(24):
		var ang := TAU * float(i) / 24.0
		dark.append(cen + Vector2(cos(ang) * 230.0, sin(ang) * 120.0))
	FastDraw.poly(self, dark, Color(0.05, 0.07, 0.18, 0.38))
	for i in range(140):
		var hx := float((i * 7919) % 460) - 230.0
		var hy := float((i * 104729) % 240) - 120.0
		if (hx * hx) / (230.0 * 230.0) + (hy * hy) / (120.0 * 120.0) > 1.0:
			continue
		var fl := 0.6 + 0.4 * sin(t * 9.0 + float(i))
		FastDraw.circle(self, cen + Vector2(hx, hy), 1.6 * fl + 0.6, Color(1.0, 0.65 + 0.25 * fl, 0.25, 0.9))
	for i in range(6):
		var ang2 := TAU * float(i) / 6.0
		var lp := cen + Vector2(cos(ang2) * 30.0, sin(ang2) * 14.0 - 6.0)
		draw_line(lp - Vector2(0, 10), lp - Vector2(0, 6), Color("3a2a1a"), 0.8)
		draw_rect(Rect2(lp + Vector2(-2, -6), Vector2(4, 5)), Color("2e5fb0"))
		draw_rect(Rect2(lp + Vector2(-2, -6), Vector2(4, 1.5)), Color("c0392b"))
		FastDraw.circle(self, lp + Vector2(0, -3.5), 1.2, Color(1, 0.9, 0.6, 0.8))
	var obang: Array[Color] = [Color("1f5fa8"), Color("c0392b"), Color("e8b820"), Color("f4f0e4"), Color("1c1c1c")]
	for i in range(5):
		var fp := cen + Vector2(-24.0 + 12.0 * float(i), -8.0)
		draw_line(fp, fp - Vector2(0, 26), Color("3a2a1a"), 1.0)
		var wv := sin(t * 3.0 + float(i)) * 2.0
		FastDraw.poly(self, PackedVector2Array([fp - Vector2(0, 26), fp + Vector2(9 + wv, -23), fp - Vector2(0, 19)]), obang[i])
	var cmd := ["북을 울려라!", "청룡기를 올려라 — 동문 진 전개!", "횃불을 높이 들어라!", "학익진을 펼쳐라!"]
	_draw_speech_bubble(cen + Vector2(0, -40), cmd[int(t / 4.0) % cmd.size()], "", true)

# ============================================================ 3단계: 연무대 훈련 · 공심돈 순찰
## PORT-TRACE [연무대 5x5 연출]: 광장에 2줄x5명 창검 병사가 구령에 맞춰 일제히 찌르고(4초마다 진법 바꿈: 일자진 ↔ 원진),
## 지휘관이 깃발로 신호, 사대에서 궁병 넷이 차례로 시위를 당겨 쏘면 화살이 포물선으로 성벽 너머 과녁(성 밖 3칸)에 꽂히고
## "관중이오!" 외침. 시간 t 하나로 그리는 장면, 화면 밖이면 건너뜀.
func _draw_yeonmudae_scene(info: Dictionary, bounds: Rect2, t: float) -> void:
	var cen: Vector2 = city.ym_pt(info, 0.0, 0.0)
	if not bounds.has_point(cen):
		return
	var to_wall: Vector2 = (city.ym_pt(info, 0.0, 1.0) - cen).normalized()
	var side_x := 1.0 if to_wall.x >= 0.0 else -1.0
	# 과녁(성 밖) — 나무 판에 동심원, 다리 둘
	var targets: Array[Vector2] = []
	for r: float in [-1.4, 0.0, 1.4]:
		var tp: Vector2 = city.ym_pt(info, r, 6.2)
		targets.append(tp)
		draw_line(tp + Vector2(-3, 0), tp + Vector2(-3, -10), Color("5c3a21"), 1.0)
		draw_line(tp + Vector2(3, 0), tp + Vector2(3, -10), Color("5c3a21"), 1.0)
		draw_rect(Rect2(tp + Vector2(-5, -20), Vector2(10, 12)), Color("f4f0e4"))
		FastDraw.circle(self, tp + Vector2(0, -14), 3.6, Color("1f5fa8"))
		FastDraw.circle(self, tp + Vector2(0, -14), 1.8, Color("c0392b"))
	# 창검·진법 병사: 훈련(포격 훈련·야조) 때만 4초마다 일자진 ↔ 원진, 평시엔 둘씩 짝지어 쉬며 창 손질
	var ym_drill: bool = MilitaryDrillManager.active_kind == MilitaryDrillManager.DrillType.YEONMUDAE_DRILL
	var drilling: bool = ym_drill or (citizens != null and (citizens.drill_t >= 0.0 or citizens.yajo_t > 0.0))
	if not drilling:
		for pr in range(2):
			var bp: Vector2 = city.ym_pt(info, -1.0 + 1.6 * float(pr), 0.4)
			_najol(bp, 0.0, 1.0)
			_najol(bp + Vector2(10, 2), 0.3 + 0.3 * sin(t * 1.3 + float(pr)), -1.0)
	var formation := int(t / 4.0) % 2
	var thrust := maxf(0.0, sin(t * 4.0))
	var idx := 0
	for row in range(2 if drilling else 0):
		for col in range(5):
			var p: Vector2
			if formation == 0:
				p = city.ym_pt(info, -1.2 + 0.6 * float(col), -0.2 + 0.7 * float(row))
			else:
				var ang := TAU * float(idx) / 10.0 + t * 0.2
				p = city.ym_pt(info, cos(ang) * 1.1, 0.3 + sin(ang) * 0.8)
			_najol(p, 0.0, side_x)
			var hand := p + Vector2(2.5 * side_x, -9)
			draw_line(hand - to_wall * 3.0, hand + to_wall * (8.0 + thrust * 5.0), Color("8a8a8a"), 1.0) # 창
			idx += 1
	# 지휘관: 사열 훈련 때는 외장용영 대장 백동수가 등채로 지휘, 평시엔 당직 군관
	var cmd_p: Vector2 = city.ym_pt(info, -1.9, 0.9)
	var cf := side_x
	NpcSprites.draw_kind(self, cmd_p, "baek_dongsu" if ym_drill else "general", 0, current_season == "겨울", 0 if cf > 0.0 else 1, 0)
	var cup := 0.5 + 0.5 * sin(t * 2.0)
	var chand := cmd_p + Vector2(4.5 * cf, -14.0) * _sk()
	draw_line(chand, chand + Vector2(5.0 * cf, -5.0 - cup * 6.0) * _sk(), Color("5c3a21"), 1.2)
	if ym_drill and int(t / 3.0) % 3 == 0:
		_draw_speech_bubble(cmd_p + Vector2(0, -30), "장용영은 들어라 — 진을 바꿔라!", "", true)
	elif drilling and int(t / 2.0) % 4 == 0:
		_draw_speech_bubble(cmd_p + Vector2(0, -22), "찔러! 하나, 둘!" if formation == 0 else "원진(圓陣)으로 둘러서라!", "", true)
	# 궁병 넷: 3초 주기로 차례로 당기기(0~1.2초) → 쏘기 → 화살 비행(1.2~2.2초)
	for i in range(4):
		var ap: Vector2 = city.ym_pt(info, -1.2 + 0.8 * float(i), 2.0)
		var cyc := fmod(t + float(i) * 0.75, 3.0)
		var drawn := clampf(cyc / 1.2, 0.0, 1.0) if cyc < 1.2 else 0.0
		NpcSprites.draw_kind(self, ap, "sasu", 0, current_season == "겨울", 0 if side_x > 0.0 else 1, 0)
		var bow := ap + Vector2(4 * side_x, -12) * _sk() + to_wall * 2.0
		FastDraw.arc(self, bow, 4.5, -PI * 0.5 - 1.0, -PI * 0.5 + 1.0, 6, Color("3a2416"), 1.1)
		draw_line(bow + Vector2(0, -4), bow - to_wall * (drawn * 4.0), Color("e8e0c8"), 0.5)
		draw_line(bow + Vector2(0, 4), bow - to_wall * (drawn * 4.0), Color("e8e0c8"), 0.5)
		if cyc >= 1.2 and cyc < 2.2:
			var k := (cyc - 1.2) / 1.0
			var tg: Vector2 = targets[i % 3] + Vector2(0, -14)
			var arrow := bow.lerp(tg, k) - Vector2(0, sin(k * PI) * 26.0)
			var nxt := bow.lerp(tg, minf(1.0, k + 0.05)) - Vector2(0, sin(minf(1.0, k + 0.05) * PI) * 26.0)
			var dirv := (nxt - arrow).normalized()
			draw_line(arrow - dirv * 5.0, arrow, Color("3a2416"), 1.0)
		elif cyc >= 2.2 and cyc < 2.8:
			var tg2: Vector2 = targets[i % 3] + Vector2(0, -14)
			draw_line(tg2 - to_wall * 4.0, tg2, Color("3a2416"), 1.0) # 꽂힌 화살
			if i == 0:
				_draw_speech_bubble(tg2 + Vector2(0, -24), "관중(貫中)이오!", "", true)

## PORT-TRACE [공심돈 순찰]: 공심돈 꼭대기 마루를 병졸 둘이 돌며 망을 봄(원통형은 원, 장방형은 네모 둘레를 따라)
func _draw_gongsimdon_patrol(info: Dictionary, bounds: Rect2, t: float) -> void:
	var H: float = city.gongsimdon_top_h(info)
	var cen: Vector2 = city.gs_pt(info, 0.0, city.GS_VC, H)
	if not bounds.has_point(cen):
		return
	var r: float = city.gongsimdon_radius(info)
	var winter := current_season == "겨울"
	# PORT-TRACE [공심돈 병졸]: 병졸은 처마 아래 여장 뒤로 가려져 돈다 — 앞쪽 반 호를 지날 때만 상체가 보이고, 뒤쪽 반에서는 몸통 뒤로 사라진다.
	for i in range(2):
		var ph := fmod(t * 0.07 + float(i) * 0.5, 1.0)
		var ang := TAU * ph
		var p: Vector2 = city.gs_pt(info, cos(ang) * r * 0.78, city.GS_VC + sin(ang) * r * 0.78, H)
		if p.y < cen.y + 1.0:
			continue
		var p2: Vector2 = city.gs_pt(info, cos(ang + 0.1) * r * 0.78, city.GS_VC + sin(ang + 0.1) * r * 0.78, H)
		var dir_i := 0 if p2.x >= p.x else 1
		NpcSprites.draw_upper(self, p + Vector2(0, 2), "trooper", i, winter, dir_i, 11, int(t * 3.0) % NpcSprites.FRAMES)
		if int(t / 6.0 + float(i)) % 5 == 0:
			draw_line(p + Vector2(3.0 * (1.0 if dir_i == 0 else -1.0), -9), p + Vector2(7.0 * (1.0 if dir_i == 0 else -1.0), -10), Color("c8a064"), 1.0) # 망보기
	# 포구에서 화포: 8초마다 한 포구가 불을 뿜고 연기가 퍼진다
	var ports: Array = city.gongsimdon_ports(info)
	if not ports.is_empty():
		var pi_ := int(t / 8.0) % ports.size()
		var since := fmod(t, 8.0)
		var port: Dictionary = ports[pi_]
		var pp: Vector2 = port["p"]
		var pd: Vector2 = port["d"]
		if since < 0.35:
			for f in range(3):
				FastDraw.circle(self, pp + pd * (6.0 + float(f) * 4.0), 5.0 - float(f) * 1.2, [Color("fff0a0"), Color("ffb040"), Color("e8602a")][f])
		if since < 4.0:
			for c in range(4):
				var k := since / 4.0
				var drift := pd * (9.0 + since * 8.0 + float(c) * 4.0) + Vector2(sin(float(c) * 1.7) * 5.0, -since * 3.0 - float(c) * 2.0)
				FastDraw.circle(self, pp + drift, 3.5 + since * 3.0 + float(c), Color(0.96, 0.96, 0.94, 0.7 * (1.0 - k)))

# ============================================================ 4단계: 포루 · 행궁 재판
## PORT-TRACE [포루 연출]: 평시 — 꼭대기에서 당직 포병이 포탄 더미·화약통을 허리 숙여 살핌.
## 포격 훈련(CitizenManager.drill_t, 24초): 0~5초 장전(포병이 포탄을 들어 올림) → 5~8초 심지 불꽃 → 8·12·16초 포구마다
## 엇갈려 화염 + 부풀며 퍼지는 백색 연막(6초). 개체를 만들지 않고 시간으로만 그린다(풀링 불필요).
func _draw_poru_scene(info: Dictionary, bounds: Rect2, t: float) -> void:
	var _tall: float = city.poru_height(info)
	var top: Vector2 = city.pr_pt(info, float(info.get("len", 2)) + 0.45, 0.0, 18.0) # 포루 옆 성벽 위 성도(포병·보초가 서는 자리)
	if not bounds.has_point(top):
		return
	if city.poru_muzzles(info).is_empty():
		# 대기·감시형(鋪樓): 성도에서 먼 곳을 살피는 보초
		_najol(top + Vector2(0, 2), 0.0, 1.0)
		if int(_scene_t / 7.0) % 3 == 0:
			draw_line(top + Vector2(4, -8), top + Vector2(10, -10), Color("c8a064"), 1.2) # 손차양/망원
		return
	var dt: float = citizens.drill_t
	# 포탄 더미 + 화약통
	var pile := top + Vector2(-9, 3)
	for k in range(4):
		FastDraw.circle(self, pile + Vector2(float(k % 2) * 3.0 - 1.5, -(float(k) / 2.0) * 2.6), 1.6, Color("2a2a2e"))
	draw_rect(Rect2(top + Vector2(8, 0), Vector2(4, 5)), Color("6e4a2c"))
	var g := top + Vector2(2, 6)
	if dt < 0.0:
		_najol(g + Vector2(0, sin(t * 1.2) * 1.0), 0.6 + 0.4 * sin(t * 1.2), 1.0)
		return
	if dt < 5.0:
		_najol(g, 0.2, 1.0)
		FastDraw.circle(self, g + Vector2(4, -10 - absf(sin(dt * 2.0)) * 4.0), 1.8, Color("2a2a2e")) # 포탄 장전
		if dt < 2.5:
			_draw_speech_bubble(g + Vector2(0, -28), "포탄 장전!", "", true)
		return
	_najol(g, 0.0, 1.0)
	var muzzles: Array[Vector2] = city.poru_muzzles(info)
	var outv: Vector2 = (city.pr_pt(info, 0.5, 2.0) - city.pr_pt(info, 0.5, 1.0)).normalized()
	if dt < 8.0:
		for mz: Vector2 in muzzles:
			FastDraw.circle(self, mz - outv * 6.0 - Vector2(0, 3), 1.2 + 0.6 * sin(t * 20.0), Color("ffd060")) # 심지 불꽃
		_draw_speech_bubble(g + Vector2(0, -28), "심지에 불 붙여라!", "", true)
		return
	for i in range(muzzles.size()):
		var fire_t := 8.0 + 4.0 * float(i)
		var since := dt - fire_t
		if since < 0.0:
			continue
		var mz2: Vector2 = muzzles[i]
		if since < 0.35:
			for f in range(3):
				FastDraw.circle(self, mz2 + outv * (4.0 + f * 4.0), 5.0 - f * 1.2, [Color("fff0a0"), Color("ffb040"), Color("e8602a")][f])
		if since < 6.0:
			for c in range(5):
				var k := since / 6.0
				var drift := outv * (10.0 + since * 9.0 + float(c) * 5.0) + Vector2(sin(float(c) * 1.7) * 6.0, -since * 3.0 - float(c) * 2.0)
				FastDraw.circle(self, mz2 + drift, 4.0 + since * 3.0 + float(c), Color(0.96, 0.96, 0.94, 0.75 * (1.0 - k)))

## PORT-TRACE [행궁 정당 집무]: 재판·태형·칼 쓴 죄수는 유수부 관아에서만(기능 분리) — 행궁 정당 앞에선 관원이 집무하고
## 마당 양편에 포졸이 지킨다. 가끔 관원이 공문을 처리하는 말풍선.
const HG_OFFICE_LINES := ["장계(狀啓)를 한양으로 올려라.", "화성 축성 일지를 가져오너라.", "오늘 진상품 목록을 살피겠다.", "행궁 수직(守直)을 엄히 하라."]
func _draw_haenggung_court(a: Vector2i, bounds: Rect2, t: float) -> void:
	# 행궁은 기준 칸이 한가운데, 정문이 격자 +x. 봉수당(a.x-1)과 좌익문(a.x+1) 사이 한 줄만 트인 마당이라 사람은 이 줄 안에만.
	var hall := _cc(float(a.x) + 0.12, float(a.y) + 0.5) # 봉수당 앞 월대
	if not bounds.has_point(hall):
		return
	var cyc := fmod(t, 40.0)
	_satto(hall, 1.0 if cyc < 4.0 else 0.0)
	_najol(_cc(float(a.x) + 0.5, float(a.y) - 0.2), 0.0, 1.0)
	_najol(_cc(float(a.x) + 0.65, float(a.y) + 1.15), 0.0, -1.0)
	if cyc < 4.0:
		_draw_speech_bubble(hall + Vector2(0, -20), HG_OFFICE_LINES[int(t / 40.0) % HG_OFFICE_LINES.size()], "판관", true)

# ============================================================ 생태계 2단계 그림
## PORT-TRACE [사포수]: 벙거지 + 갈색 더그레, 어깨에 멘 조총(긴 총신·화승). 겨눌 땐 총을 수평으로 사냥감 쪽, 쏘면 총구 불꽃·연기.
## 짐: 지게에 사냥감(호랑이면 줄무늬 가죽), 행궁에서 바칠 땐 앞에 호랑이 가죽을 펼쳐 보인다.
func _draw_saposu(p: Vector2, a: Dictionary) -> void:
	var st: String = a.get("state", "")
	var dir := _sdir(a)
	if st == "aim" and a.has("aim_at"):
		var at: Vector2 = a["aim_at"]
		var right := (at.x - float(a["x"])) - (at.y - float(a["y"])) >= 0.0
		dir = 0 if right else 1
	var sx := _ssx(dir)
	var carry: String = a.get("carry", "")
	var has_carry := carry != "" and st in ["to_workshop", "to_palace"]
	var col := Color("d88a2a") if carry == "tiger" else (Color("8a6a46") if carry in ["deer", "wolf"] else Color("5a4030"))
	if has_carry and dir < 2:
		_back_bundle(p, sx, col, col.darkened(0.2))
	if st == "aim":
		var fire_now := float(a.get("fire_t", 0.0)) > 0.0
		if _try_act(p, ["npc_hunter__shoot", "npc_soldier__shoot"], 2 if fire_now else 1, sx > 0.0):
			return
	if st != "aim" and dir < 2:
		draw_line(p + Vector2(3 * sx, -3), p + Vector2(-2 * sx, -25), Color("3a2a1a"), 1.6) # 멘 조총
	_spr(p, "saposu", a, 0, dir, 0 if st in ["aim", "present"] else -1)
	if has_carry and dir >= 2:
		_back_bundle(p, sx, col, col.darkened(0.2))
	if st != "aim" and dir >= 2:
		draw_line(p + Vector2(3 * sx, -3), p + Vector2(-2 * sx, -25), Color("3a2a1a"), 1.6)
	if st == "aim":
		var gs := p + Vector2(3 * sx, -13)
		var ge := gs + Vector2(16.0 * sx, -1.0)
		draw_line(gs, ge, Color("3a2a1a"), 1.8)
		draw_line(gs, gs + Vector2(-4.0 * sx, 2.0), Color("6e4a2c"), 2.4) # 개머리
		if float(a.get("fire_t", 0.0)) > 0.0:
			FastDraw.circle(self, ge + Vector2(2.0 * sx, 0), 3.0, Color("ffd060"))
			FastDraw.circle(self, ge + Vector2(5.0 * sx, -2), 3.8, Color(0.9, 0.9, 0.9, 0.6))
	if st == "present":
		var pelt := p + Vector2(13.0 * sx, 3)
		FastDraw.poly(self, PackedVector2Array([pelt + Vector2(-9, 0), pelt + Vector2(9, -1), pelt + Vector2(10, 4), pelt + Vector2(-8, 5)]), Color("d88a2a"))
		for k in range(5):
			draw_line(pelt + Vector2(-6 + k * 3.2, -0.5), pelt + Vector2(-5 + k * 3.2, 4.5), Color("1a1410"), 1.0)
		FastDraw.circle(self, pelt + Vector2(11, 1.5), 2.6, Color("d88a2a"))

## PORT-TRACE [장용영]: 정조의 친위 군영. 일반 포졸과 달리 흑색 철릭에 청색 전대, 붉은 상모 단 전립, 기창(작은 깃발 단 창).
## 신풍루(행궁 동향 정문) 좌우 군영 앞에서 셋씩 줄 맞춰 발맞춰 오가며 순찰(시간으로만 그림, 화면 밖이면 건너뜀).
func _jangyong_soldier(p: Vector2, step: float, sx: float) -> void:
	# 장용영: 흑색 철릭 + 청색 전대 + 붉은 상모 전립 도트, 노란 기창
	var key := NpcSprites.custom_kind("trooper", Color("1c1e26"), Color("3a3030"), Color("2e5fb0"), {"plume_col": "d03028"})
	var fr := 1 if step > 0.5 else (3 if step < -0.5 else 0)
	NpcSprites.draw_kind(self, p, key, 0, current_season == "겨울", 0 if sx > 0.0 else 1, fr)
	var k := _sk()
	var sp := p + Vector2(4.5 * sx, -7) * k
	draw_line(sp + Vector2(0, 6) * k, sp + Vector2(0, -24) * k, Color("6e4a2c"), 1.2)
	draw_line(sp + Vector2(0, -24) * k, sp + Vector2(0, -28) * k, Color("c8c8c8"), 1.4)
	FastDraw.poly(self, PackedVector2Array([sp + Vector2(0, -23) * k, sp + Vector2(6.0 * sx, -20.5) * k, sp + Vector2(0, -18) * k]), Color("e8b820"))

func _draw_jangyong(a: Vector2i, bounds: Rect2, t: float) -> void:
	# PORT-TRACE [행궁 정문 밖]: 행궁 묶음은 a-3 ~ a+3 칸, 앞 담은 x = a.x+4. 병사는 담 밖 앞길(x = a.x+4.4)에서만 오간다.
	var gate := _cc(float(a.x) + 4.3, float(a.y) + 0.5)
	if not bounds.has_point(gate):
		return
	# PORT-TRACE [행궁 수문장 셋씩]: 사용자 요청 — "양쪽에 셋씩 서 있는 게 입구를 지키는 느낌". 예전엔 셋씩 길 위에서
	# 제자리걸음해 길을 막는 것처럼 보였다 → 신풍루 담 바로 앞에 문 양쪽으로 셋씩 줄지어 서고(문 가운데는 비움), 창을 세운 채 가끔 고쳐 잡는다.
	for side: float in [-1.0, 1.0]:
		for i in range(3):
			var gy := float(a.y) + 0.5 + side * (0.42 + 0.36 * float(i))
			var shift := 0.6 if fmod(t * 0.35 + float(i) * 1.7 + side, 6.0) < 0.4 else 0.0 # 창 고쳐 잡기
			_jangyong_soldier(_cc(float(a.x) + 4.22 + 0.04 * float(i), gy), shift, side)
	# 정문을 드나드는 관리: 14초마다 길에서 문 앞까지 걸어와 들어가고(사라짐), 반대로 나와서 길로 떠남
	var cyc := fmod(t, 14.0)
	if cyc < 4.0:
		var p_in := Vector2(float(a.x) + 5.6, float(a.y) + 0.5).lerp(Vector2(float(a.x) + 4.15, float(a.y) + 0.5), cyc / 4.0)
		_yard_person(_cc(p_in.x, p_in.y), Color("2a4a8a"), 1, Vector2(-1, 0), true, 0.0, t)
	elif cyc >= 7.0 and cyc < 11.0:
		var p_out := Vector2(float(a.x) + 4.15, float(a.y) + 0.5).lerp(Vector2(float(a.x) + 5.6, float(a.y) + 0.5), (cyc - 7.0) / 4.0)
		_yard_person(_cc(p_out.x, p_out.y), Color("8a2a2a"), 1, Vector2(1, 0), true, 0.0, t)

## PORT-TRACE [전기수]: 겨울이면 장터 장마당(없으면 가게 앞)에 소설 읽어 주는 전기수가 앉아 책을 펼치고 과장된 몸짓으로 이야기,
## 백성 3~5명이 반원으로 둘러앉아 손뼉 치고 환호. 말풍선은 대목마다 바뀜(4초).
const JEONGISU_LINES := ["(탁!) 이때 홍길동이 구름을 타고 휙~ 날아가니!", "임경업 장군이 칼을 뽑아 드니 오랑캐가 벌벌!", "흥부네 박을 타는데 슬근슬근 톱질이야~", "(탁!) 다음 대목은 내일 이 시간에 들려 드리리다!"]
const LISTENER_LINES := ["얼쑤! 그래서 어찌 되었소?", "아이고, 그 대목이 제일이오!", "어서 다음 얘기 들려주시오!"]
func _draw_jeongisu() -> void:
	if current_season != "겨울" or citizens == null:
		return
	if _play_dirty_jg:
		_play_dirty_jg = false
		_jeongisu_spot = Vector2.INF
		var pls: Array = grid.list_plazas("market")
		if not pls.is_empty():
			var c0: Vector2 = pls[0]["center"]
			_jeongisu_spot = c0
		elif not citizens._shop_cache.is_empty():
			var s0: Vector2i = citizens._shop_cache[0]
			_jeongisu_spot = Vector2(float(s0.x) + 0.5, float(s0.y) + 1.2)
	var spot: Vector2 = _jeongisu_spot
	if spot == Vector2.INF:
		return
	var c := _cc(spot.x, spot.y)
	if not _get_view_bounds().has_point(c):
		return
	var t := _scene_t
	# 둘러앉은 청중(뒷줄 → 전기수 → 앞줄)
	var n := 5
	for pass_i in range(2):
		for i in range(n):
			var ang := PI * 0.15 + PI * 0.7 * float(i) / float(n - 1)
			var front := pass_i == 1
			if (i % 2 == 0) != front:
				continue
			var lp := c + Vector2(cos(ang + PI) * 26.0, sin(ang + PI) * 9.0 + 8.0) if not front else c + Vector2(cos(ang) * 26.0, sin(ang) * 9.0 + 6.0)
			var clap := maxf(0.0, sin(t * 6.0 + float(i) * 1.3))
			FestivalArt.person(self, lp, [Color("f4f0e4"), Color("dfe6ee"), Color("e8dcc4"), Color("b9c8d6"), Color("f0d8d8")][i], 1 if i % 2 == 0 else 2, clap * 0.7, Color(0, 0, 0, 0), 0.85)
		if pass_i == 0:
			# 전기수: 돗자리 위에서 펼친 고소설 서책과 부채를 들고 과장된 제스처로 낭독
			FastDraw.poly(self, PackedVector2Array([c + Vector2(-12, 3), c + Vector2(12, 3), c + Vector2(9, 8), c + Vector2(-9, 8)]), Color("c8b27a"))
			FastDraw.polyline(self, PackedVector2Array([c + Vector2(-12, 3), c + Vector2(12, 3), c + Vector2(9, 8), c + Vector2(-9, 8), c + Vector2(-12, 3)]), Color("8c734b"), 1.0)
			var gest_step: int = int(t * 2.2) % 2
			NpcSprites.draw_kind(self, c, "jeongisu", 0, current_season == "겨울", 0, int(_scene_t * 2.0) % 4 if NpcSprites.action_frames("npc_jeongisu__tell") > 0 else gest_step, "tell")
	var line_i := int(t / 4.0)
	if line_i % 3 == 2:
		_draw_speech_bubble(c + Vector2(26, -20), LISTENER_LINES[line_i % LISTENER_LINES.size()], "", true)
	else:
		_draw_speech_bubble(c + Vector2(0, -26), JEONGISU_LINES[line_i % JEONGISU_LINES.size()], "전기수", true)

# ============================================================ 공성전 그림
## PORT-TRACE [공성전]: 반란군 — 붉은 머리띠·검붉은 군복의 정규 무장(창·환도), 몇은 '反' 깃발. 도적떼 — 누더기 백성이 몽둥이·낫·횃불.
## 공성 중이면 무기를 휘두르는 동작. 목표 둘레에 사다리(성벽 있을 때)·충차, 성벽 위 수비군 화살, 공격력/방호력 막대.
## PORT-TRACE [공성전]: 반란군 — 10명 이상의 포수·사수·살수 편제 (화포·조총, 각궁 불화살, 환도·장창)
## 공성 중이면 총포 발포, 활 시위 당기기, 무기 휘두르기 모션을 격렬히 수행.
func _draw_rebel(p: Vector2, a: Dictionary) -> void:
	var dir := _sdir(a)
	var sx := _ssx(dir)
	var anim: float = float(a.get("anim", 0.0))
	var sieging: bool = bool(a.get("sieging", false))
	var w_class: String = str(a.get("weapon_class", "blade"))
	var flag := int(a.get("slot", 1)) % 4 == 0

	# 1. 깃발병 ('反' 군기)
	if flag:
		var fp := p + Vector2(-5.5 * sx, -7)
		draw_line(fp + Vector2(0, 7), fp + Vector2(0, -26), Color("3a2416"), 1.0)
		draw_rect(Rect2(fp + Vector2(0 if sx > 0 else -10, -26), Vector2(10, 8)), Color("1c1c1c"))
		draw_string(ThemeDB.fallback_font, fp + Vector2(1.5 if sx > 0 else -8.5, -19.5), "反", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("e8453a"))

	_spr(p, "rebel", a, 0, dir)
	var hand := p + Vector2(4.5 * sx, -7)

	# 2. 병종별 무기 및 공격 연출 (포/활/칼)
	match w_class:
		"gunner":
			# 포수 (조총/사제 화포) - 총열 조준 및 격발 연막/화염
			var barrel_angle: float = -0.35 if sieging else -0.15
			var barrel_tip := hand + Vector2(12.0 * sx, -6.0).rotated(barrel_angle)
			draw_line(hand - Vector2(2.0 * sx, -2.0), barrel_tip, Color("1f2937"), 2.2) # 총열
			draw_line(hand - Vector2(4.0 * sx, 1.0), hand, Color("78350f"), 2.5) # 개머리판

			if sieging:
				# 격발 주기: 1.5초마다 굉음과 함께 총구 화염 및 백색 화약 연막 뿜뿜
				var fire_cycle: float = fmod(anim * 1.8 + float(int(a.get("slot", 0))), 2.0)
				if fire_cycle < 0.4:
					# 총구 화염 (노랑-주황 불꽃)
					var flash_len: float = 6.0 + sin(anim * 25.0) * 3.0
					var flash_tip := barrel_tip + Vector2(flash_len * sx, -flash_len * 0.4)
					FastDraw.circle(self, barrel_tip, 3.5, Color("fef08a"))
					draw_line(barrel_tip, flash_tip, Color("f97316"), 2.5)
					# 화약 연막 (자욱한 백색 연기)
					for si in range(3):
						var s_off := Vector2((5.0 + float(si) * 4.0) * sx, -4.0 - float(si) * 3.0)
						FastDraw.circle(self, barrel_tip + s_off, 2.8 + float(si) * 1.5, Color(0.9, 0.9, 0.9, 0.6 - float(si) * 0.15))

		"archer":
			# 사수 (각궁) - 시위를 당겨 성벽으로 불화살 곡사 발사
			var bow_cen := hand + Vector2(6.0 * sx, -6.0)
			# 활 몸통 (곡선형 호)
			draw_line(bow_cen + Vector2(0, -9.0), bow_cen + Vector2(3.0 * sx, 0), Color("854d0e"), 1.8)
			draw_line(bow_cen + Vector2(3.0 * sx, 0), bow_cen + Vector2(0, 9.0), Color("854d0e"), 1.8)

			var draw_cycle: float = fmod(anim * 2.2 + float(int(a.get("slot", 0))), 2.2)
			if draw_cycle > 1.2:
				# 시위 팽팽히 당김
				draw_line(bow_cen + Vector2(0, -9.0), bow_cen - Vector2(4.0 * sx, 0), Color("fef08a"), 1.0)
				draw_line(bow_cen + Vector2(0, 9.0), bow_cen - Vector2(4.0 * sx, 0), Color("fef08a"), 1.0)
				# 얹은 화살 및 불꽃
				var arr_tip := bow_cen + Vector2(8.0 * sx, -4.0)
				draw_line(bow_cen - Vector2(4.0 * sx, 0), arr_tip, Color("b45309"), 1.4)
				FastDraw.circle(self, arr_tip, 2.2, Color("ef4444"))
			else:
				# 평시 시위
				draw_line(bow_cen + Vector2(0, -9.0), bow_cen + Vector2(0, 9.0), Color("e5e7eb"), 1.0)

		_:
			# 살수 (환도 및 장창) - 무기를 치켜들고 함성을 지르며 돌격
			var swing := (0.5 + 0.5 * sin(anim * 6.0)) if sieging else 0.0
			var tip := hand + Vector2(7.0 * sx * swing, -17.0 + swing * 9.0)
			draw_line(hand + Vector2(0, 4), tip, Color("6e4a2c"), 1.5) # 창 자루
			draw_line(tip, tip + (tip - hand).normalized() * 5.0, Color("e5e7eb"), 2.2) # 창날
			if sieging and swing > 0.6:
				# 휘두름 잔상 및 스파크
				draw_line(tip - Vector2(3 * sx, -2), tip + Vector2(3 * sx, 2), Color("fbbf24"), 1.5)
				FastDraw.circle(self, tip, 2.5, Color("f59e0b", 0.8))

func _draw_horde(p: Vector2, a: Dictionary) -> void:
	var dir := _sdir(a)
	var sx := _ssx(dir)
	var swing := (0.5 + 0.5 * sin(float(a.get("anim", 0.0)) * 3.0)) if a.get("sieging", false) else 0.2
	_spr(p, "horde", a, 0, dir)
	var hand := p + Vector2(4.5 * sx, -7)
	match int(a.get("slot", 0)) % 3:
		0: # 횃불
			draw_line(hand + Vector2(0, 2), hand + Vector2(1.5 * sx, -12), Color("6e4a2c"), 1.4)
			FastDraw.circle(self, hand + Vector2(1.5 * sx, -14), 2.6 + sin(float(a.get("anim", 0.0)) * 9.0) * 0.5, Color("ffb040"))
			FastDraw.circle(self, hand + Vector2(1.5 * sx, -14), 1.3, Color("fff0b0"))
		1: # 낫
			draw_line(hand, hand + Vector2(4.0 * sx, -8 + swing * 5.0), Color("6e4a2c"), 1.2)
			FastDraw.arc(self, hand + Vector2(4.0 * sx, -9 + swing * 5.0), 3.2, -PI, 0.0, 5, Color("b8b8b8"), 1.2)
		_: # 몽둥이
			draw_line(hand, hand + Vector2(5.0 * sx * swing, -12 + swing * 6.0), Color("7a5634"), 2.4)

func _draw_siege() -> void:
	var sg: SiegeSystem = citizens.siege if citizens else null
	if sg == null or sg.state == "" or sg.state == "warning":
		return
	var tg: Vector2i = sg.target
	if not grid.in_bounds(tg.x, tg.y):
		return
	var c := _cc(float(tg.x) + 0.5, float(tg.y) + 0.5)
	if not _get_view_bounds().has_point(c):
		return
	var t := _scene_t
	if sg.state == "siege":
		if sg.walled:
			# 사다리 둘(성벽에 기대어) + 충차가 성문을 두드림
			for o: float in [-26.0, 24.0]:
				var b := c + Vector2(o, 10)
				draw_line(b, b + Vector2(4, -28), Color("7a5634"), 1.4)
				draw_line(b + Vector2(5, 0), b + Vector2(9, -28), Color("7a5634"), 1.4)
				for k in range(1, 6):
					var u := float(k) / 6.0
					draw_line(b + Vector2(4, -28) * u, b + Vector2(5, 0) + Vector2(4, -28) * u, Color("7a5634"), 0.8)
			var ram := c + Vector2(0, 12) + Vector2(sin(t * 3.0) * 4.0, 0)
			draw_rect(Rect2(ram + Vector2(-10, -8), Vector2(20, 6)), Color("5a3a20"))
			draw_line(ram + Vector2(-12, -5), ram + Vector2(12, -5), Color("3a2416"), 3.0)
			FastDraw.circle(self, ram + Vector2(-6, -1), 2.5, Color("3a2416"))
			FastDraw.circle(self, ram + Vector2(6, -1), 2.5, Color("3a2416"))
		# 1. 수비군(장용영) 조총 일제 사격 (성벽 위 총구 섬광 및 자욱한 화약 연막)
		for g_i in range(4):
			var g_phase: float = fmod(t * 2.2 + float(g_i) * 0.45, 1.8)
			var gun_pos := c + Vector2(-28.0 + float(g_i) * 18.0, -38.0)
			if g_phase < 0.35:
				# 총구 섬광
				FastDraw.circle(self, gun_pos, 3.2, Color("fef08a"))
				draw_line(gun_pos, gun_pos + Vector2(sin(t * 15.0) * 4.0, 8.0), Color("f97316"), 2.0)
				# 백색 화약 연막
				for sm_i in range(3):
					var sm_off := Vector2(float(sm_i) * 3.0, -float(sm_i) * 2.5)
					FastDraw.circle(self, gun_pos + sm_off, 2.5 + float(sm_i) * 1.5, Color(0.92, 0.92, 0.92, 0.6 - float(sm_i) * 0.18))
				# 조총 탄환 궤적 (아래 반란군 진영으로)
				draw_line(gun_pos, gun_pos + Vector2(0, 35.0), Color("e5e7eb", 0.7), 1.2)

		# 2. 성곽 대포(불랑기포/포루) 포격 연출
		var cannon_phase: float = fmod(t * 0.8, 2.5)
		if cannon_phase < 0.5:
			var cannon_pos := c + Vector2(32.0, -42.0)
			FastDraw.circle(self, cannon_pos, 5.0, Color("fbbf24")) # 대포 발포구
			FastDraw.circle(self, cannon_pos, 2.8, Color("ef4444"))
			# 날아가는 붉은 포탄 투사체
			var shell_t: float = cannon_phase / 0.5
			var shell_pos: Vector2 = cannon_pos.lerp(c + Vector2(-15.0, 22.0), shell_t)
			FastDraw.circle(self, shell_pos, 3.0, Color("1f2937"))
			FastDraw.circle(self, shell_pos + Vector2(0, -1), 1.5, Color("f97316"))
			if shell_t > 0.85:
				# 착탄 폭발 FX
				FastDraw.circle(self, c + Vector2(-15.0, 22.0), 6.5, Color("f97316", 0.8))
				FastDraw.circle(self, c + Vector2(-15.0, 22.0), 3.5, Color("fef08a"))

		# 3. 수비군 궁수 화살 비 (곡사 궤적)
		for i in range(6):
			var ph := fmod(t * 0.9 + float(i) * 0.17, 1.0)
			var from := c + Vector2(-30.0 + float(i) * 12.0, -36.0)
			var to := c + Vector2(-20.0 + float(i) * 8.0, 18.0)
			var ap := from.lerp(to, ph) - Vector2(0, sin(ph * PI) * 10.0)
			draw_line(ap, ap + (to - from).normalized() * 5.0, Color("2a1a10"), 1.0)

		# 4. 반란군 불화살 및 총포 맞불 사격 (아래 -> 성벽/성문)
		for r_i in range(3):
			var r_ph := fmod(t * 1.1 + float(r_i) * 0.33, 1.0)
			var r_from := c + Vector2(-25.0 + float(r_i) * 20.0, 22.0)
			var r_to := c + Vector2(-15.0 + float(r_i) * 15.0, -18.0)
			var r_ap := r_from.lerp(r_to, r_ph) - Vector2(0, sin(r_ph * PI) * 12.0)
			draw_line(r_ap, r_ap + (r_to - r_from).normalized() * 5.0, Color("ea580c"), 1.6) # 불화살
			FastDraw.circle(self, r_ap, 1.8, Color("fef08a")) # 불꽃
			if r_ph > 0.9:
				# 성벽 충돌 스파크 및 돌 파편
				FastDraw.circle(self, r_to, 2.5, Color("fbbf24"))
				draw_line(r_to + Vector2(-2, -2), r_to + Vector2(2, 2), Color("d97706"), 1.0)

		# 5. 격전지 자욱한 화약 연기와 흙먼지
		for k2 in range(5):
			var sp := fmod(t * 0.45 + float(k2) * 0.2, 1.0)
			FastDraw.circle(self, c + Vector2(-20.0 + k2 * 9.0, 8.0 - sp * 26.0), 4.5 + sp * 7.0, Color(0.65, 0.60, 0.55, 0.42 * (1.0 - sp)))

## 공성전 공격력 / 성 방호력 막대.
## PORT-TRACE [게이지 깜빡임]: 사람들보다 먼저 그리면, 성문 근처를 지나는 군사마다 성문 앞 그림 조각이 덮여
## 막대가 잘렸다 보였다 했다 — 사람·말풍선을 다 그린 뒤에 그린다.
func _draw_siege_bar() -> void:
	var sg: SiegeSystem = citizens.siege if citizens else null
	if sg == null or sg.state == "" or sg.state == "warning":
		return
	var tg: Vector2i = sg.target
	if not grid.in_bounds(tg.x, tg.y):
		return
	var c := _cc(float(tg.x) + 0.5, float(tg.y) + 0.5)
	if not _get_view_bounds().has_point(c):
		return
	var defense := sg.defense_power()
	var top := c + Vector2(-50, -62)
	draw_rect(Rect2(top, Vector2(100, 22)), Color(0.08, 0.05, 0.03, 0.85))
	draw_rect(Rect2(top + Vector2(4, 4), Vector2(92.0 * clampf(float(sg.attack) / 1000.0, 0.0, 1.0), 6)), Color("d02a20"))
	draw_rect(Rect2(top + Vector2(4, 12), Vector2(92.0 * clampf(float(defense) / 1000.0, 0.0, 1.0), 6)), Color("2e86c1"))
	draw_string(ThemeDB.fallback_font, top + Vector2(4, -2), "%s 공격 %d  대  방호 %d" % ["반란군" if sg.kind == "rebel" else "도적떼", sg.attack, defense], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("fde68a"))

# ============================================================ 민·군 합동 방어 체제 전용 렌더러

## 1. 의병/민병대 (상인·주민 동원 - 죽창/쇠스랑/몽둥이 무장 및 성벽 투석)
func _draw_militia(p: Vector2, a: Dictionary) -> void:
	if not _get_view_bounds().has_point(p):
		return
	var dir := _sdir(a)
	var sx := _ssx(dir)
	var anim: float = float(a.get("anim", 0.0))
	var swing: float = sin(anim * 8.0)
	var weapon: String = str(a.get("weapon", "bamboo_spear"))
	_spr(p, "militia", a, 0, dir)
	var hand := p + Vector2(4.5 * sx, -8 + swing * 2.0)
	match weapon:
		"bamboo_spear":
			var thrust: float = maxf(0.0, swing * 6.0)
			draw_line(hand - Vector2(5 * sx, -5), hand + Vector2((14 + thrust) * sx, -13), Color("5c7d36"), 2.0)
			draw_line(hand + Vector2((12 + thrust) * sx, -12), hand + Vector2((16 + thrust) * sx, -14), Color("f4ecd8"), 1.6)
		"pitchfork":
			draw_line(hand - Vector2(4 * sx, -4), hand + Vector2(12 * sx, -10 + swing * 3.0), Color("4a3525"), 1.8)
			draw_line(hand + Vector2(11 * sx, -11), hand + Vector2(14 * sx, -14), Color("7f8c8d"), 1.4)
			draw_line(hand + Vector2(12 * sx, -10), hand + Vector2(15 * sx, -10), Color("7f8c8d"), 1.4)
		"flail":
			draw_line(hand - Vector2(2 * sx, 0), hand + Vector2(7 * sx, -14 + swing * 5.0), Color("5c3a21"), 2.0)
			draw_line(hand + Vector2(7 * sx, -14 + swing * 5.0), hand + Vector2(14 * sx, -7 - swing * 4.0), Color("3d2314"), 2.2)
		_:
			draw_line(hand, hand + Vector2(9 * sx * swing, -12 + swing * 6.0), Color("5c3a21"), 2.4)
			if fmod(anim * 2.0, 1.0) > 0.5:
				FastDraw.circle(self, hand + Vector2(7 * sx, -16), 2.2, Color("5d6d7e"))

## 2. 부녀자 보급대 (물동이·주먹밥 바구니·화살통 머리에 이고 보급 지원)
func _draw_supply_carrier(p: Vector2, a: Dictionary) -> void:
	if not _get_view_bounds().has_point(p):
		return
	var dir := _sdir(a)
	var kind: String = str(a.get("supply_kind", "riceball"))
	_spr(p, "supply", a, 0, dir)
	var ht := p + Vector2(0, -27)
	match kind:
		"water_pot":
			FastDraw.poly(self, PackedVector2Array([ht + Vector2(-5, 0), ht + Vector2(5, 0), ht + Vector2(4, -8), ht + Vector2(-4, -8)]), Color("4a2311"))
			draw_line(ht + Vector2(-4.5, -8), ht + Vector2(4.5, -8), Color("2e160b"), 1.6)
		"riceball":
			draw_line(ht + Vector2(-7, -1), ht + Vector2(7, -1), Color("b7950b"), 2.4)
			for r in range(4):
				FastDraw.circle(self, ht + Vector2(-4.5 + r * 3.0, -3.5), 1.9, Color("ffffff"))
		"arrows":
			draw_rect(Rect2(ht + Vector2(-4, -7), Vector2(8, 7)), Color("512e17"))
			for ar in range(3):
				draw_line(ht + Vector2(-2.5 + ar * 2.5, -7), ht + Vector2(-2.5 + ar * 2.5, -12), Color("2c3e50"), 1.0)
		"stones":
			draw_line(ht + Vector2(-6, -1), ht + Vector2(6, -1), Color("784212"), 2.6)
			for st in range(3):
				FastDraw.circle(self, ht + Vector2(-3 + st * 3.0, -3.5), 2.0, Color("566573"))
		_:
			FastDraw.circle(self, ht + Vector2(0, -4), 4.2, Color("fdfefe"))
			draw_line(ht + Vector2(-2.5, -8), ht + Vector2(2.5, -8), Color("c0392b"), 1.2)
	draw_line(p + Vector2(5.5, -14), ht + Vector2(5, -1), Color("f7f9f9"), 1.8) # 받친 손

## 3. 배신자/내통자 (성문 몰래 열거나 길 안내)
func _draw_traitor(p: Vector2, a: Dictionary) -> void:
	if not _get_view_bounds().has_point(p):
		return
	var dir := _sdir(a)
	var sx := _ssx(dir)
	_spr(p, "traitor", a, 0, dir)
	var hand := p + Vector2(4.5 * sx, -7)
	draw_line(hand, hand + Vector2(4 * sx, -4), Color("b7950b"), 1.5) # 황동 열쇠
	FastDraw.circle(self, hand + Vector2(4 * sx, -4), 1.4, Color("f1c40f"))

# ============================================================ 조선 후기 삼수병 및 기포병 렌더러

## 1. 포수 (砲手, 조총병 60% - 조총 일제 사격)
func _draw_posu(p: Vector2, a: Dictionary) -> void:
	if not _get_view_bounds().has_point(p):
		return
	var dir := _sdir(a)
	var sx := _ssx(dir)
	var is_wartime: bool = str(a.get("state", "")) == "wartime_posu"
	if not is_wartime and dir < 2:
		draw_line(p + Vector2(4 * sx, -4), p + Vector2(6 * sx, -27), Color("566573"), 1.8)
	_spr(p, "trooper", a, 0, dir, 0 if is_wartime else -1)
	var hand := p + Vector2(4.5 * sx, -9)
	if is_wartime:
		draw_line(hand - Vector2(5 * sx, 1), hand + Vector2(15 * sx, -2), Color("566573"), 2.0) # 총열
		draw_line(hand - Vector2(8 * sx, 3), hand - Vector2(3 * sx, 1), Color("6e2c00"), 2.6) # 개머리판
		FastDraw.circle(self, hand + Vector2(1 * sx, -1), 1.2, Color("f39c12")) # 화승 불씨
	elif dir >= 2:
		draw_line(p + Vector2(4 * sx, -4), p + Vector2(6 * sx, -27), Color("566573"), 1.8)

## 2. 사수 (射手, 궁병 15% - 곡사 궁술)
func _draw_sasu(p: Vector2, a: Dictionary) -> void:
	if not _get_view_bounds().has_point(p):
		return
	var dir := _sdir(a)
	var sx := _ssx(dir)
	var is_wartime: bool = str(a.get("state", "")) == "wartime_sasu"
	draw_line(p + Vector2(-3 * sx, -22), p + Vector2(-7 * sx, -11), Color("784212"), 2.4) # 동개(화살통)
	_spr(p, "trooper", a, 1, dir, 0 if is_wartime else -1)
	var bow := p + Vector2(6 * sx, -12)
	if is_wartime:
		if sx > 0:
			FastDraw.arc(self, bow, 9.0, -PI * 0.45, PI * 0.45, 6, Color("784212"), 1.8)
		else:
			FastDraw.arc(self, bow, 9.0, PI * 0.55, PI * 1.45, 6, Color("784212"), 1.8)
		draw_line(bow + Vector2(0, -8), bow - Vector2(5 * sx, 0), Color("eaeded"), 1.0)
		draw_line(bow + Vector2(0, 8), bow - Vector2(5 * sx, 0), Color("eaeded"), 1.0)
		draw_line(bow - Vector2(6 * sx, 0), bow + Vector2(9 * sx, 0), Color("2c3e50"), 1.2)
	else:
		draw_line(bow + Vector2(0, -8), bow + Vector2(2 * sx, 0), Color("784212"), 1.6)
		draw_line(bow + Vector2(2 * sx, 0), bow + Vector2(0, 8), Color("784212"), 1.6)
		draw_line(bow + Vector2(0, -8), bow + Vector2(0, 8), Color("eaeded"), 0.8)

## 3. 살수 (殺手, 근접 백병전병 15% - 당파창·등패)
func _draw_salsu(p: Vector2, a: Dictionary) -> void:
	if not _get_view_bounds().has_point(p):
		return
	var dir := _sdir(a)
	var sx := _ssx(dir)
	var swing: float = sin(float(a.get("anim", 0.0)) * 8.0)
	_spr(p, "trooper", a, 2, dir)
	var sh := p + Vector2(-5 * sx, -10)
	FastDraw.circle(self, sh, 5.5, Color("b7950b")) # 등패
	FastDraw.circle(self, sh, 3.0, Color("7d6608"))
	var hand := p + Vector2(4.5 * sx, -9 + swing * 2.0)
	var tip := hand + Vector2(12 * sx, -10 + swing * 3.0)
	draw_line(hand - Vector2(5 * sx, -5), tip, Color("4a2311"), 2.0)
	draw_line(tip, tip + Vector2(5 * sx, -2), Color("bdc3c7"), 1.8)
	draw_line(tip, tip + Vector2(2 * sx, -6), Color("bdc3c7"), 1.4)
	draw_line(tip, tip + Vector2(3 * sx, 3), Color("bdc3c7"), 1.4)

## 4. 기포병 (騎砲手, 기마 화포/총병 10% - 군마 탑승 & 기동 타격)
func _draw_gipo(p: Vector2, a: Dictionary) -> void:
	if not _get_view_bounds().has_point(p):
		return
	var dir := _sdir(a)
	var sx := _ssx(dir)
	var trot: float = sin(float(a.get("anim", 0.0)) * 10.0) * 1.5
	_draw_horse(p + Vector2(0, trot * 0.5), a, sx, Color("512e17"), Color("2a1608"))
	_draw_rider(p + Vector2(-1 * sx, -23 + trot * 0.5), "trooper", _gdir_of(a, sx))
	var gs := p + Vector2(2 * sx, -31 + trot * 0.5)
	draw_line(gs, gs + Vector2(13 * sx, -3), Color("2c3e50"), 2.5)
	FastDraw.circle(self, gs + Vector2(13 * sx, -3), 1.5, Color("f39c12"))

# ============================================================ 발사체 및 VFX 오브젝트 풀 렌더러
func _draw_military_vfx() -> void:
	var mm: MilitaryManager = citizens.military_mgr if citizens else null
	if mm == null:
		return

	var view_bounds := _get_view_bounds()

	# 1. 백색 연막 파티클 풀
	for p: Dictionary in mm.smoke_pool:
		if not p["active"]:
			continue
		var pos := _cc(float(p["x"]), float(p["y"]))
		if not view_bounds.has_point(pos):
			continue
		var u: float = float(p["life"]) / float(p["max_life"])
		var sz: float = float(p["size"]) + u * 6.0
		var col := Color(0.92, 0.94, 0.95, (1.0 - u) * 0.65)
		FastDraw.circle(self, pos - Vector2(0, u * 10.0), sz, col)

	# 2. 총구 섬광 풀
	for f: Dictionary in mm.flash_pool:
		if not f["active"]:
			continue
		var pos2 := _cc(float(f["x"]), float(f["y"]))
		if not view_bounds.has_point(pos2):
			continue
		FastDraw.circle(self, pos2, 3.5, Color(1.0, 0.85, 0.2, 0.9))
		FastDraw.circle(self, pos2, 1.8, Color(1.0, 1.0, 0.9, 1.0))

	# 3. 곡사 화살 투사체 풀
	for ar: Dictionary in mm.arrow_pool:
		if not ar["active"]:
			continue
		var prog: float = float(ar["progress"])
		var p_start := _cc(float(ar["from_x"]), float(ar["from_y"]))
		var p_goal := _cc(float(ar["to_x"]), float(ar["to_y"]))
		var cur_p := p_start.lerp(p_goal, prog)
		var arc_y := sin(prog * PI) * float(ar["arc_h"])
		cur_p.y -= arc_y
		if not view_bounds.has_point(cur_p):
			continue
		var dir := (p_goal - p_start).normalized()
		draw_line(cur_p, cur_p + dir * 4.5, Color("2a1a10"), 1.2)



# ============================================================ 교육 기관 장면
## PORT-TRACE [책 그림]: 사용자 요청 — "책으로 묘사된 것이 전혀 책 같지 않다". 조선 선장본(실로 엮은 책): 펼친 책은 가운데가
## 접혀 오목한 두 쪽(누런 한지에 세로 글줄), 덮은 책은 누런 표지 + 왼쪽 등에 실로 꿰맨 다섯 땀. 물품 그림(book_open·book_stack)이 있으면 그것.
func _draw_book_open(p: Vector2, k: float, sx: float = 1.0) -> void:
	if GoodsArt.draw(self, p + Vector2(0, 1.5 * k), "book_open", 0.55 * k, sx < 0.0):
		return
	var L := PackedVector2Array([p + Vector2(-5.5, -1.2) * k, p + Vector2(0, 0) * k, p + Vector2(0, -2.8) * k, p + Vector2(-5.5, -4.2) * k])
	var R := PackedVector2Array([p + Vector2(0, 0) * k, p + Vector2(5.5, -1.2) * k, p + Vector2(5.5, -4.2) * k, p + Vector2(0, -2.8) * k])
	FastDraw.poly(self, PackedVector2Array([L[0] + Vector2(0, 0.8 * k), R[1] + Vector2(0, 0.8 * k), R[2], L[3]]), Color("8a6a3a")) # 표지 테
	FastDraw.poly(self, L, Color("efe5c8"))
	FastDraw.poly(self, R, Color("e4d8b6"))
	for i in range(3):
		var fx := -4.4 + float(i) * 1.5
		draw_line(p + Vector2(fx, -3.5 + fx * 0.05) * k, p + Vector2(fx, -1.6 + fx * 0.22) * k, Color(0.15, 0.12, 0.1, 0.7), 0.5) # 세로 글줄
		draw_line(p + Vector2(-fx, -3.5 + fx * 0.05) * k, p + Vector2(-fx, -1.6 + fx * 0.22) * k, Color(0.15, 0.12, 0.1, 0.6), 0.5)
	draw_line(p + Vector2(0, -2.8) * k, p, Color("8a7a5a"), 0.6) # 접힌 가운데

func _draw_book_closed(p: Vector2, k: float) -> void:
	if GoodsArt.draw(self, p + Vector2(0, 2.0 * k), "book_stack", 0.5 * k):
		return
	var q := PackedVector2Array([p + Vector2(-3, 0) * k, p + Vector2(3, -1) * k, p + Vector2(3, -6) * k, p + Vector2(-3, -5) * k])
	FastDraw.poly(self, PackedVector2Array([q[0] + Vector2(0.8, 0.8) * k, q[1] + Vector2(0.8, 0.8) * k, q[2] + Vector2(0.8, 0.8) * k, q[3] + Vector2(0.8, 0.8) * k]), Color("efe5c8")) # 책장 두께
	FastDraw.poly(self, q, Color("c9a65c")) # 누런 표지
	FastDraw.polyline(self, PackedVector2Array(Array(q) + [q[0]]), Color("5e4524"), 0.6)
	for i in range(5):
		var t := (float(i) + 0.5) / 5.0
		var sp := q[0].lerp(q[3], t)
		draw_line(sp, sp + Vector2(0.9, -0.15) * k, Color("3a2a1a"), 0.6) # 실 땀
	draw_rect(Rect2(p + Vector2(0.2, -4.6) * k, Vector2(1.2, 2.6) * k), Color("efe5c8")) # 제목 쪽지

## 유생: 푸른 도포 + 검은 유건, 책 보따리
func _draw_yusaeng(p: Vector2, a: Dictionary) -> void:
	var sx := _ssx(_sdir(a))
	_spr(p, "yusaeng", a)
	_draw_book_closed(p + Vector2(4.0 * sx, -6.0) * _sk(), _sk()) # 옆구리에 낀 책

func _scholar_seated(p: Vector2, robe: Color, sway: float, book: bool) -> void:
	# 앉아 글 읽는 유생(유건) — 몸을 좌우로 흔들며
	var key := NpcSprites.custom_kind("yusaeng", robe, robe, Color("2e4a7a"))
	_spr_seat(p + Vector2(roundf(sway), 0), key, 0, robe.darkened(0.08))
	if book:
		var k := _sk()
		_draw_book_open(p + Vector2(0, 0.5) * k, k * 0.6) # 무릎 위에 펼친 책

## PORT-TRACE [서당 — 김홍도 〈서당〉]: 대청 앞, 회초리 든 훈장이 앉고 앞에 등 돌려 눈물 훔치는 학동, 그를 보며 킥킥대는 아이들
## (몸을 들썩), 천자문 짚어 가며 몸을 좌우로 흔들며 읽는 학동들. 말풍선 "하늘 천, 따 지~" / 훈장 "다시 외워 보거라!".
## 매곡서원: 강당 마루 독서하는 유생들 + 정자 둘레 산책. 수원향교: 대성전 앞 제관 셋이 절(제향), 명륜당 마당 두 유생 토론.
func _draw_edu_scenes() -> void:
	if _edu_spots.is_empty():
		return
	var bounds := _get_view_bounds()
	var t := _scene_t
	for e: Dictionary in _edu_spots:
		var x0 := float(e["x0"])
		var y0 := float(e["y0"])
		var n := float(e["n"])
		var cen := _cc(x0 + n * 0.5, y0 + n * 0.5)
		if not bounds.has_point(cen):
			continue
		match String(e["kind"]):
			"seodang":
				var dc := _cc(x0 + 1.0, y0 + 0.95) # 대청 마루 훈장님 위치
				_satto_teacher(dc + Vector2(-10, -2), t)

				# 동자 학동(댕기머리 아이들) 4명 마루에 앉아 글 읽는 앰비언트 연출
				var s_offsets: Array[Vector2] = [Vector2(4, -3), Vector2(14, -2), Vector2(5, 5), Vector2(15, 6)]
				var lap_colors: Array[Color] = [Color("e9e4d6"), Color("e2dccb"), Color("ece6d8"), Color("ddd6c4")] # 흰 무명 바지
				var sk_val: float = _sk()
				for si: int in range(4):
					var sp: Vector2 = dc + s_offsets[si]
					var s_sway: float = sin(t * 1.8 + float(si) * 0.9) * 0.7
					_spr_seat(sp + Vector2(roundf(s_sway), 0), "child_m", 3, lap_colors[si], si)
					# 학동 무릎 위에 펼친 천자문
					_draw_book_open(sp + Vector2(roundf(s_sway), 0.5 * sk_val), sk_val * 0.5)

				# 12초 주기 교차 낭독 말풍선 연출 (훈장 낭독 -> 학동 1 복창 -> 학동 2 복창, 줌아웃과 무관하게 상시 노출)
				var loop_t: float = fmod(t + float(x0) * 2.3, 12.0)
				if loop_t < 3.8:
					_draw_speech_bubble(dc + Vector2(-10, -22), "하늘 천(天), 따 지(地)... 다시 외워 보거라!", "훈장", true)
				elif loop_t >= 4.0 and loop_t < 7.6:
					_draw_speech_bubble(dc + Vector2(4, -20), "검을 현(玄), 누를 황(黃)...", "학동", true)
				elif loop_t >= 8.0 and loop_t < 11.6:
					_draw_speech_bubble(dc + Vector2(14, -19), "집 우(宇), 집 주(宙)...", "학동", true)
			"seowon":
				var kd := _cc(x0 + 1.5, y0 + 1.6)
				for i2 in range(3):
					_scholar_seated(kd + Vector2(-14.0 + float(i2) * 14.0, -4.0), Color("9ec0de"), sin(t * 1.2 + float(i2)) * 0.8, true)
				var pv := _cc(x0 + 2.6, y0 + 0.5)
				var ang := t * 0.3
				FestivalArt.person(self, pv + Vector2(cos(ang) * 14.0, sin(ang) * 6.0 + 8.0), Color("9ec0de"), 1, 0.1)
				if int(t / 6.0) % 3 == 0:
					_draw_speech_bubble(kd + Vector2(0, -24), "학이시습지면 불역열호아라…", "", true)
			"hyanggyo":
				var dsp := _cc(x0 + 2.0, y0 + 1.25) # 대성전 앞
				var jegwan := NpcSprites.custom_kind("yusaeng", Color("a8322a"), Color("a8322a"), Color("1a1a1a"))
				for k in range(3):
					var bow := 0.5 + 0.5 * sin(t * 1.0 + float(k) * 0.2)
					var pp := dsp + Vector2(-14.0 + float(k) * 14.0, 4.0)
					if bow > 0.6:
						_spr_seat(pp, jegwan, 2, Color("8a2a22")) # 엎드려 절하는 뒷모습
					else:
						NpcSprites.draw_kind(self, pp, jegwan, 0, current_season == "겨울", 2, 0)
				var mp := _cc(x0 + 2.0, y0 + 2.9) # 명륜당 마당
				FestivalArt.person(self, mp + Vector2(-10, 0), Color("9ec0de"), 1, 0.5 + 0.5 * sin(t * 2.0), Color(0, 0, 0, 0), 1.0, 0)
				FestivalArt.person(self, mp + Vector2(10, 1), Color("f4f0e4"), 1, 0.5 + 0.5 * sin(t * 2.0 + 2.0), Color(0, 0, 0, 0), 1.0, 1)
				if int(t / 5.0) % 2 == 0:
					_draw_speech_bubble(mp + Vector2(-10, -28), ["성즉리(性卽理)라 하였소!", "실사구시(實事求是)가 먼저요!"][int(t / 10.0) % 2], "", true)

# ============================================================ 장터 생활(김홍도 풍속화처럼)
## PORT-TRACE [장터 생활]: 업종별 상인·여러 손님·장마당의 좌판 상인·엿장수와 따라다니는 아이들·비틀거리는 취객·
## 손자 손 잡은 할아버지·도둑을 제압하는 포졸. 개별 NPC 없이 시간 t로만 그리고, 화면에 보이는 장마당 4곳까지.
const TRADE_SELLER := {
	"fish": "fish_seller", "jeotgal": "fish_seller", "meat": "butcher", "herb": "physician", "tteok": "tteok_seller",
	"jumak": "jumo", "gukbap": "jumo", "rice": "farmer", "veg": "peddler_w", "fruit": "peddler_w",
	"silk": "peddler_w", "cotton": "peddler_w", "myeonju": "peddler_w", "ramie": "peddler_w", "paper": "peddler_w",
	"book": "book_peddler", "yugi": "artisan", "brass": "artisan", "gat": "artisan", "shoes": "artisan", "shoe": "artisan",
	"jipsin": "artisan", "brush": "artisan", "bow": "artisan", "hanji": "artisan", "pottery": "porter", "onggi": "porter",
	"salt": "porter", "tobacco": "bobusang", "bangmul": "peddler_w", "tent": "bobusang",
}
const MARKET_CROWD := ["grandpa", "grandma", "mother_baby", "lady", "yangban", "farmer", "peddler_w", "child_m", "child_f", "cheonmin", "jumo", "book_peddler", "drunkard"]
const SELLER_CALLS := ["사려~ 사려~ 싱싱한 물건이오!", "골라 보시오, 밑지고 파오!", "오늘 장 파하기 전에 떨이요~"]
const YEOT_CALLS := ["엿 사려~ 찰떡같이 붙는 엿이오!", "철컥철컥~ 엿 한 가락에 한 푼!", "헌 고무신, 헌 솥 다 받소~"]
const DRUNK_CALLS := ["허허, 달이 둘이로구나~", "주모~ 한 사발만 더!", "내가 왕년에는 말이여~"]
var _market_plazas: Array = []

## 인물 종류(NpcSprites 연결 표의 이름)로 그리기. walking이면 걷는 칸, 아니면 서기(+팔 든 정도)
func _kind_at(p: Vector2, kind: String, gdir: Vector2, walking: bool, t: float, arm: float = 0.0) -> void:
	var dir := NpcSprites.dir_of({"dir": gdir})
	if walking:
		NpcSprites.draw_kind(self, p, kind, 0, current_season == "겨울", dir, int(t * 6.0) % NpcSprites.FRAMES)
	else:
		NpcSprites.draw_kind(self, p, kind, 0, current_season == "겨울", dir, clampi(roundi(arm * 3.0), 0, 3), "cheer" if arm > 0.0 else "")

func _draw_market_life() -> void:
	if _market_plazas.is_empty() or _modern_plaza_tex("market") != null: # 시민공원으로 바뀌면 난전 장면 대신 공원 그림
		return
	if get_canvas_transform().get_scale().x < 0.55:
		return
	var bounds := _get_view_bounds()
	var t := _scene_t
	var fest_spots := {}
	if festivals:
		for sc: Dictionary in festivals.scenes:
			fest_spots[sc.get("plaza", Vector2i(-1, -1))] = true
	var drawn := 0
	for pl: Dictionary in _market_plazas:
		if drawn >= 4:
			break
		var x0 := float(pl["x0"])
		var y0 := float(pl["y0"])
		var n := float(pl["n"])
		var cen := _cc(x0 + n * 0.5, y0 + n * 0.5)
		if not bounds.has_point(cen):
			continue
		drawn += 1
		var busy := fest_spots.has(Vector2i(int(x0), int(y0))) # 놀이판이 열린 장마당은 가장자리만
		var ph := float(int(x0) * 7 + int(y0) * 13)
		_market_vignettes(x0, y0, n, t + ph, busy)

func _market_vignettes(x0: float, y0: float, n: float, t: float, busy: bool) -> void:
	var items: Array = [] # [화면 y, Callable]
	# 1) 좌판 상인(앞쪽 모서리): 앉아서 손짓, 앞에 돗자리와 물건, 손님 둘이 들여다봄
	var jp := _cc(x0 + n - 0.35, y0 + 0.4)
	items.append([jp.y, func() -> void:
		FastDraw.poly(self, PackedVector2Array([jp + Vector2(-12, 4), jp + Vector2(0, -2), jp + Vector2(12, 4), jp + Vector2(0, 10)]), Color("b89a5a")) # 돗자리
		var mat_goods: Array = [["straw_shoes", "fruit_basket"], ["herb_pack", "tteok"], ["fish_basket", "onggi"]][int(x0 + y0) % 3]
		if GoodsArt.has(String(mat_goods[0])):
			GoodsArt.draw(self, jp + Vector2(-5, 6), String(mat_goods[0]), 0.7)
			GoodsArt.draw(self, jp + Vector2(5, 7), String(mat_goods[1]), 0.7)
		else:
			for k in range(5):
				FastDraw.circle(self, jp + Vector2(-6 + k * 3, 4 + (k % 2) * 2), 1.4, [Color("e8b820"), Color("c0392b"), Color("2e8b57"), Color("f4f0e4"), Color("8e44ad")][k])
		NpcSprites.draw_upper(self, jp + Vector2(-2, -1), "grandma" if int(x0 + y0) % 2 == 0 else "peddler_w", 0, current_season == "겨울", 1)
	])
	var cust_a := _cc(x0 + n - 0.05, y0 + 0.85)
	var cust_b := _cc(x0 + n - 0.6, y0 + 0.9)
	var ka: String = MARKET_CROWD[int(t / 20.0) % MARKET_CROWD.size()]
	var kb: String = MARKET_CROWD[(int(t / 20.0) + 5) % MARKET_CROWD.size()]
	items.append([cust_a.y, func() -> void: _kind_at(cust_a, ka, Vector2(0, -1), false, t)])
	items.append([cust_b.y, func() -> void: _kind_at(cust_b, kb, Vector2(-1, 0), false, t)])
	# 2) 엿장수: 장마당 뒤쪽 변을 오가며 가위를 철컥, 아이 둘이 졸졸
	var u := fmod(t * 0.06, 2.0)
	var k01 := u if u < 1.0 else 2.0 - u
	var yg := Vector2(x0 + 0.3, y0 + 0.2).lerp(Vector2(x0 + n - 0.3, y0 + 0.2), k01) if not busy else Vector2(x0 + 0.2, y0 + 0.2).lerp(Vector2(x0 + 0.2, y0 + n - 0.3), k01)
	var ydir := (Vector2(1, 0) if not busy else Vector2(0, 1)) * (1.0 if u < 1.0 else -1.0)
	var yp := _cc(yg.x, yg.y)
	items.append([yp.y, func() -> void:
		_kind_at(yp, "yeot_seller", ydir, true, t)
		GoodsArt.draw(self, yp + Vector2(-3, -5), "yeot_tray", 0.75, ydir.x < 0.0) # 가슴 앞에 멘 엿판
		var snip := absf(sin(t * 8.0)) * 3.0 # 엿가위 철컥철컥
		var hp := yp + Vector2(5, -14)
		draw_line(hp, hp + Vector2(5, -2 - snip), Color("6a6a70"), 1.2)
		draw_line(hp, hp + Vector2(5, -2 + snip), Color("6a6a70"), 1.2)
	])
	for c in range(2):
		var cg := yg - ydir * (0.35 + 0.25 * float(c)) + Vector2(0.08, 0.1) * float(c)
		var cp := _cc(cg.x, cg.y)
		var ck := "child_m" if c == 0 else "child_f"
		items.append([cp.y, func() -> void: _kind_at(cp, ck, ydir, true, t + float(c))])
	# 3) 취객: 장마당 가운데를 비틀비틀 가로지름(놀이판이 열려 있으면 생략)
	if not busy:
		var dc := fmod(t * 0.045, 1.0)
		var dg := Vector2(x0 + 0.2, y0 + n - 0.4).lerp(Vector2(x0 + n - 0.2, y0 + 0.6), dc)
		var dp := _cc(dg.x, dg.y) + Vector2(sin(t * 2.3) * 4.0, 0)
		items.append([dp.y, func() -> void:
			var lean := sin(t * 2.3) * 0.18 # 몸이 좌우로 기우뚱
			NpcSprites.set_xf(self, dp, lean, Vector2.ONE)
			var keep_xf := NpcSprites.base_xf
			NpcSprites.base_xf = NpcSprites.base_xf * Transform2D(lean, Vector2.ONE, 0.0, dp)
			_kind_at(Vector2.ZERO, "drunkard", Vector2(1, -1).normalized() if cos(t * 2.3) > 0.0 else Vector2(1, 0), true, t * 0.6)
			NpcSprites.base_xf = keep_xf
			NpcSprites.reset_xf(self)
		])
	# 4) 할아버지와 손자: 앞쪽 변을 천천히, 손을 잡고(손 사이 선)
	var gu := fmod(t * 0.035, 2.0)
	var gk := gu if gu < 1.0 else 2.0 - gu
	var gg := Vector2(x0 + 0.3, y0 + n - 0.2).lerp(Vector2(x0 + n - 0.5, y0 + n - 0.2), gk)
	var gdir := Vector2(1, 0) * (1.0 if gu < 1.0 else -1.0)
	var gp := _cc(gg.x, gg.y)
	var sp := _cc(gg.x + 0.05, gg.y + 0.22)
	items.append([gp.y, func() -> void: _kind_at(gp, "grandpa", gdir, true, t * 0.5)])
	items.append([sp.y, func() -> void:
		_kind_at(sp, "child_m", gdir, true, t * 0.5 + 0.3)
		draw_line(gp + Vector2(2, -12), sp + Vector2(1, -8), Color("ecc29a"), 1.0) # 맞잡은 손
	])
	# 5) 포졸 제압: 50초마다 9초 동안 — 포졸이 꿇어앉은 도둑의 어깨를 누르고 오랏줄
	var cyc := fmod(t, 50.0)
	if cyc < 9.0 and not busy:
		var ag := _cc(x0 + 0.5, y0 + n * 0.55)
		var pg := ag + Vector2(-9, -2)
		items.append([ag.y, func() -> void:
			_prisoner(ag, 0, 1.0)
			_najol(pg, 0.3 + 0.3 * sin(t * 6.0), 1.0)
			draw_line(pg + Vector2(4, -10), ag + Vector2(0, -8), Color("8a6a3a"), 1.2) # 오랏줄
		])
		if cyc < 3.0:
			_draw_speech_bubble(pg + Vector2(0, -26), "게 섰거라, 이놈! 남의 물건에 손을 대?", "")
	items.sort_custom(func(a1: Array, a2: Array) -> bool: return float(a1[0]) < float(a2[0]))
	for it: Array in items:
		(it[1] as Callable).call()
	# 말풍선: 한 번에 하나만
	var talk := int(t / 7.0) % 6
	if fmod(t, 7.0) < 3.0:
		match talk:
			0: _draw_speech_bubble(jp + Vector2(0, -20), SELLER_CALLS[int(t / 42.0) % SELLER_CALLS.size()], "")
			2: _draw_speech_bubble(yp + Vector2(0, -26), YEOT_CALLS[int(t / 42.0) % YEOT_CALLS.size()], "")
			4:
				if not busy:
					var dc2 := fmod(t * 0.045, 1.0)
					var dg2 := Vector2(x0 + 0.2, y0 + n - 0.4).lerp(Vector2(x0 + n - 0.2, y0 + 0.6), dc2)
					_draw_speech_bubble(_cc(dg2.x, dg2.y) + Vector2(0, -26), DRUNK_CALLS[int(t / 42.0) % DRUNK_CALLS.size()], "")

# ============================================================ 공방·가게 앞마당 일하는 장면
## PORT-TRACE [건물 속 생활]: 건물 그림과 따로 노는 NPC 대신, 건물 앞마당에서 그 건물의 일을 하는 사람을 시간 t 하나로 그린다
## (개별 NPC 없음). 공방 = 업종별 동작(망치질·톱질·정질·가마·염색·종이 뜨기…)과 불꽃·연기·톱밥, 가게 = 상인의 손짓과
## 길에서 걸어와 흥정하고 보따리를 들고 돌아가는 손님. 화면에 보이는 곳만, 공방 16·가게 20곳까지, 많이 축소하면 생략.
const WORK_MAX_WS := 16
const WORK_MAX_SHOP := 20
const SHOP_TALK := [["어서 오시오, 물건 좋소!", "이건 얼마요?"], ["두 냥만 주시오.", "에이, 한 냥 반에 합시다!"], ["허허, 밑지고 파는 거요.", "좋소, 싸 주시오."]]
const WS_TALK := {
	"smith": ["쇠는 달았을 때 두드려야지!", "풀무 더 세게 밟아라!"], "wood": ["먹줄 따라 반듯하게!", "톱밥 날린다, 비켜서게."],
	"stone": ["정 한 번에 돌결 하나…", "성돌은 반듯해야 하네."], "kiln": ["가마 불 꺼뜨리지 마라!", "기와 한 장도 깨지 말게."],
	"dye": ["쪽물 빛이 곱게 들었네.", "볕에 잘 말려야 하네."], "hanji": ["발을 고르게 흔들어야지.", "닥나무 껍질 더 가져오너라."],
	"craft": ["손끝이 야무져야 하오.", "주문받은 물건 내일까진 되오."], "arsenal": ["화약은 불 조심!", "창날 녹슨 것 골라내라."],
}

func _collect_work_spots() -> void:
	_work_spots.clear()
	for y in range(grid.size):
		for x in range(grid.size):
			var t: Dictionary = grid.grid[y][x]
			if t.has("zone_build") or t.get("is_ruined", false):
				continue
			var b: String = t["building"]
			if b.begins_with("ind"):
				var gx := x
				var gy := y
				var w := 1
				var h := 1
				if t.has("ws_group"):
					var wg: Dictionary = t["ws_group"]
					if int(wg["x0"]) != x or int(wg["y0"]) != y:
						continue # 묶음은 첫 칸에서 한 번만
					w = int(wg.get("w", 1))
					h = int(wg.get("h", 1))
					gx = x + w - 1 # 화면에서 가장 앞 칸 기준
					gy = y + h - 1
				var fe := _spot_front(x, y, gx, gy)
				if fe.is_empty():
					continue # 앞에 사람이 설 땅(길·빈터)이 없으면 장면 없음 — 물·남의 지붕 위에 서지 않게
				_work_spots.append({"kind": "ws", "id": grid.get_workshop_asset_id(x, y), "pos": fe[0], "edge": fe[1], "size": maxi(w, h)})
			elif (b == "com_1" or b == "com_2") and not t.has("plaza") and not (String(t.get("trade", "")) in ["jeotgal", "salt", "cattle"]):
				var fe2 := _spot_front(x, y, x, y)
				if fe2.is_empty():
					continue
				_work_spots.append({"kind": "shop", "trade": String(t.get("trade", "")), "pos": fe2[0], "edge": fe2[1], "size": 1})

## PORT-TRACE [문 통과]: 성문 그림이 커져 둘레 칸을 덮으므로, 성문 가까이엔 가게·장마당 장면을 그리지 않는다(문 위에 선 사람처럼 보임)
var _gate_tiles: Array[Vector2i] = []
func _near_gate(x: int, y: int, r: int = 2) -> bool:
	for gt: Vector2i in _gate_tiles:
		if absi(gt.x - x) <= r and absi(gt.y - y) <= r:
			return true
	return false

## PORT-TRACE [장인이 물·지붕 위에]: 부지 둘레 칸 중 바깥 이웃이 사람이 설 수 있는 땅(돌길 3 > 길 2 > 빈 뭍 1)인 모서리를 고른다.
## 화면 앞쪽(+x·+y) 모서리만. [칸, 모서리 번호(GATE_EDGE_DIRS)] 또는 빈 배열.
func _spot_front(x0: int, y0: int, x1: int, y1: int) -> Array:
	var best: Array = []
	var best_s := 0
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			for e in range(4):
				var d: Vector2i = CityLayer.GATE_EDGE_DIRS[e]
				if d.x < 0 or d.y < 0:
					continue # 뒤쪽 모서리 장면은 건물에 가려야 하는데 덮어 그리게 되므로 앞쪽(+x·+y)만
				var nx := tx + d.x
				var ny := ty + d.y
				if nx >= x0 and nx <= x1 and ny >= y0 and ny <= y1:
					continue
				if not grid.in_bounds(nx, ny):
					continue
				var nt: Dictionary = grid.grid[ny][nx]
				if String(nt.get("terrain", "")) == "water" or bool(nt.get("is_bridge", false)):
					continue
				var nb: String = nt["building"]
				var sc := 0
				if grid.is_stone_road(nx, ny):
					sc = 30
				elif nb == "road":
					sc = 20
				elif nb == "" and not nt.has("plaza"):
					sc = 10
				if sc == 0 or _near_gate(nx, ny):
					continue
				if sc > best_s:
					best_s = sc
					best = [Vector2i(tx, ty), e]
	return best

## 칸 하나의 [중심, 앞쪽을 따라가는 축 a, 길 쪽(앞)으로 향하는 축 f]
func _tile_frame(x: int, y: int, edge: int = -1) -> Array:
	var ce: Array = grid.tile(x, y).get("corner_elev", [1.0, 1.0, 1.0, 1.0])
	var p_n := city.cell_center(x, y, ce[0])
	var p_e := city.cell_center(x + 1, y, ce[1])
	var p_s := city.cell_center(x + 1, y + 1, ce[2])
	var p_w := city.cell_center(x, y + 1, ce[3])
	var c := (p_n + p_e + p_s + p_w) * 0.25
	if edge >= 0:
		var rel: Array[Vector2] = [p_n - c, p_e - c, p_s - c, p_w - c]
		var ea: Vector2 = rel[edge]
		var eb: Vector2 = rel[(edge + 1) % 4]
		return [c, (eb - ea) * 0.5, (ea + eb) * 0.5]
	var fr: Array = city._front_frame(x, y, c, p_n, p_e, p_s, p_w)
	return [c, fr[0], fr[1]]

## 화면에서 움직이는 방향 → 도트 인물이 볼 격자 방향(격자 +x = 화면 오른쪽 아래, +y = 왼쪽 아래)
func _gdir_screen(dv: Vector2) -> Vector2:
	if dv.y >= 0.0:
		return Vector2(1, 0) if dv.x >= 0.0 else Vector2(0, 1)
	return Vector2(0, -1) if dv.x >= 0.0 else Vector2(-1, 0)

func _ws_group(id: String) -> String:
	if id.contains("blacksmith") or id.contains("metalcraft"):
		return "smith"
	if id.contains("carpenter") or id.contains("lumber"):
		return "wood"
	if id.contains("stonemason"):
		return "stone"
	if id.contains("kiln") or id.contains("ceramics"):
		return "kiln"
	if id.contains("dyeing"):
		return "dye"
	if id.contains("hanji"):
		return "hanji"
	if id.contains("arsenal"):
		return "arsenal"
	return "craft" # 죽세·가죽·갖바치

## 굴뚝·가마 연기: 올라가며 커지고 옅어지는 동그라미 셋
func _puffs(p: Vector2, t: float, big: float) -> void:
	for k in range(3):
		var u := fmod(t * 0.35 + float(k) / 3.0, 1.0)
		FastDraw.circle(self, p + Vector2(sin(t + float(k)) * 2.0 + u * 4.0, -u * 22.0 * big), (2.0 + u * 4.0) * big, Color(0.82, 0.8, 0.76, 0.55 * (1.0 - u)))

func _draw_work_scenes() -> void:
	if _work_spots.is_empty():
		return
	if get_canvas_transform().get_scale().x < 0.55:
		return # 너무 멀리서 보면 사람이 점처럼 보여 생략
	var bounds := _get_view_bounds()
	var t := _scene_t
	var n_ws := 0
	var n_shop := 0
	var talk_slot := int(t / 6.0)
	for sp: Dictionary in _work_spots:
		var pos: Vector2i = sp["pos"]
		var probe := city.cell_center(float(pos.x) + 0.5, float(pos.y) + 0.5, 1.0)
		if not bounds.has_point(probe):
			continue
		var is_ws: bool = sp["kind"] == "ws"
		if is_ws:
			if n_ws >= WORK_MAX_WS:
				continue
			n_ws += 1
		else:
			if n_shop >= WORK_MAX_SHOP:
				continue
			n_shop += 1
		var fr := _tile_frame(pos.x, pos.y, int(sp.get("edge", -1)))
		var a: Vector2 = fr[1]
		var f: Vector2 = fr[2]
		# 가게: 상인은 가게 앞 판매대, 손님은 길에서 / 공방: 장인은 길이 아니라 공방 앞 처마 밑(건물 안)에서 일한다
		var c: Vector2 = fr[0] + f * (0.25 if is_ws else 0.75)
		var ph := float((pos.x * 7 + pos.y * 13) % 17)
		var chatty := (pos.x * 3 + pos.y * 5 + talk_slot) % 14 == 0 and fmod(t, 6.0) < 3.0 # 열 곳 중 한 곳꼴로, 3초씩만
		if is_ws:
			_ws_scene(String(sp["id"]), c, a, f, t + ph, int(sp["size"]), chatty)
		else:
			_shop_scene(c, a, f, t + ph, chatty, int(t / 6.0 + ph), String(sp.get("trade", "")))

func _ws_scene(id: String, c: Vector2, a: Vector2, f: Vector2, t: float, size: int, chatty: bool) -> void:
	var g := _ws_group(id)
	var wp := MarketArt.P(c, a, f, -0.15, 0.78) # 일하는 사람 자리(앞마당)
	var tool_p := MarketArt.P(c, a, f, 0.2, 0.82)
	var face := _gdir_screen(tool_p - wp)
	match g:
		"smith":
			var hit := absf(sin(t * 4.0))
			FastDraw.circle(self, MarketArt.P(c, a, f, -0.5, 0.35) + Vector2(0, -4), 3.5 + hit, Color(1.0, 0.55, 0.15, 0.55)) # 화덕 불빛
			if not GoodsArt.draw(self, tool_p + Vector2(0, 2), "anvil"):
				draw_rect(Rect2(tool_p + Vector2(-3, -4), Vector2(6, 3)), Color("3a3a40")) # 모루
			_yard_person(wp, Color("8a6a4a"), 0, face, false, hit, t)
			if hit < 0.25:
				for k in range(4):
					var ang := float(k) * 1.4 + t * 9.0
					FastDraw.circle(self, tool_p + Vector2(cos(ang) * 4.0, -6.0 - absf(sin(ang)) * 4.0), 0.8, Color("ffd060"))
			_puffs(MarketArt.P(c, a, f, -0.5, 0.2) + Vector2(0, -18), t, 0.8)
			if size > 1: # 대장간: 풀무질하는 도제
				var bp := MarketArt.P(c, a, f, -0.6, 0.75)
				_yard_person(bp, Color("c8b898"), 0, Vector2(1, 0), false, 0.5 + 0.5 * sin(t * 2.0), t)
		"wood":
			var saw := sin(t * 3.0)
			if not GoodsArt.draw(self, tool_p + Vector2(0, 2), "workbench"):
				draw_line(tool_p + Vector2(-6, -3), tool_p + Vector2(6, -5), Color("c8a070"), 2.5) # 판자
			_yard_person(wp + a * (saw * 0.06), Color("b8a888"), 0, face, false, 0.4 + 0.3 * saw, t)
			for k in range(3):
				FastDraw.circle(self, tool_p + Vector2(-1 + k, fmod(t * 5.0 + float(k) * 1.3, 4.0) - 3.0), 0.6, Color("e8d0a0"))
			if size > 1: # 목재소: 통나무를 메고 오가는 일꾼
				_carrier(MarketArt.P(c, a, f, 0.7, 0.6), MarketArt.P(c, a, f, -0.7, 1.1), t * 0.12, Color("a89878"), "log")
		"stone":
			var tap := absf(sin(t * 6.0))
			if not GoodsArt.draw(self, tool_p + Vector2(0, 2), "stone_block"):
				FastDraw.poly(self, PackedVector2Array([tool_p + Vector2(-5, 0), tool_p + Vector2(5, 0), tool_p + Vector2(5, -6), tool_p + Vector2(-5, -6)]), Color("b0aca4"))
			_yard_person(wp, Color("9a8a70"), 0, face, false, tap * 0.6, t)
			if tap < 0.3:
				for k in range(3):
					FastDraw.circle(self, tool_p + Vector2(-3 + k * 3, -7 - float(k)), 0.7, Color("e0dcd4"))
		"kiln":
			_puffs(MarketArt.P(c, a, f, 0.0, 0.0) + Vector2(0, -22), t, 1.3)
			FastDraw.circle(self, MarketArt.P(c, a, f, 0.1, 0.55) + Vector2(0, -3), 2.5 + 0.8 * sin(t * 5.0), Color(1.0, 0.5, 0.1, 0.6)) # 아궁이 불
			_carrier(MarketArt.P(c, a, f, 0.55, 0.85), MarketArt.P(c, a, f, -0.55, 0.85), t * 0.15, Color("c8b898"), "tiles")
		"dye":
			var lift := 0.5 + 0.5 * sin(t * 1.4)
			var cols: Array[Color] = [Color("2c4a8c"), Color("b8352a"), Color("d8a830")]
			var cloth: Color = cols[int(t / 4.5) % 3]
			if GoodsArt.draw(self, tool_p + Vector2(0, 2), "dye_vat"):
				GoodsArt.draw(self, MarketArt.P(c, a, f, 0.65, 0.55), "dyed_cloth")
			else:
				FastDraw.circle(self, tool_p + Vector2(0, -2), 4.0, Color("2a3a6a")) # 쪽물 독
			draw_line(tool_p + Vector2(-2, -4), tool_p + Vector2(-2, -4 - lift * 10.0), cloth, 3.0)
			_yard_person(wp, Color("e8e0d0"), 2, face, false, lift, t)
		"hanji":
			var dip := 0.5 + 0.5 * sin(t * 1.6)
			if not GoodsArt.draw(self, tool_p + Vector2(0, 2), "paper_vat"):
				FastDraw.circle(self, tool_p + Vector2(0, -2), 4.5, Color("9ab8c8")) # 지통
			draw_rect(Rect2(tool_p + Vector2(-4, -6 - dip * 5.0), Vector2(8, 2)), Color("f4f0e4")) # 발 위 종이
			_yard_person(wp, Color("e8e0d0"), 2, face, false, dip * 0.7, t)
		"arsenal":
			_carrier(MarketArt.P(c, a, f, 0.9, 0.7), MarketArt.P(c, a, f, -0.9, 0.7), t * 0.1, Color("4a5a8a"), "crate")
			_carrier(MarketArt.P(c, a, f, -0.6, 1.0), MarketArt.P(c, a, f, 0.6, 1.0), t * 0.1 + 0.5, Color("4a5a8a"), "crate")
			_yard_person(MarketArt.P(c, a, f, 1.1, 1.05), Color("2c3e6a"), 0, Vector2(1, 0), false, 0.0, t) # 보초
		_:
			var work := 0.5 + 0.5 * sin(t * 2.5)
			_yard_person(wp, Color("c0a888"), 0, face, false, work * 0.7, t)
			if not GoodsArt.draw(self, tool_p + Vector2(0, 2), "workbench"):
				draw_rect(Rect2(tool_p + Vector2(-3, -4), Vector2(6, 3)), Color("9a7a50")) # 작업대
	if chatty:
		var lines: Array = WS_TALK.get(g, WS_TALK["craft"])
		_draw_speech_bubble(wp + Vector2(0, -22), String(lines[int(t / 6.0) % lines.size()]), "")

## 두 곳 사이를 오가며 짐을 나르는 일꾼(u: 0~1 반복, 가는 길엔 짐을 지고 오는 길엔 빈손)
func _carrier(p0: Vector2, p1: Vector2, u: float, robe: Color, load_kind: String) -> void:
	var cyc := fmod(u, 1.0)
	var going := cyc < 0.5
	var k := cyc * 2.0 if going else (cyc - 0.5) * 2.0
	var p := p0.lerp(p1, k) if going else p1.lerp(p0, k)
	var dv := (p1 - p0) if going else (p0 - p1)
	_yard_person(p, robe, 0, _gdir_screen(dv), true, 0.0, u * 40.0)
	if going:
		var gid: String = {"log": "log_bundle", "tiles": "roof_tiles", "crate": "crate"}.get(load_kind, "")
		if gid != "" and GoodsArt.draw(self, p + Vector2(-2, -10), gid, 0.7):
			return
		match load_kind:
			"log": draw_line(p + Vector2(-7, -15), p + Vector2(7, -17), Color("8a5a32"), 2.5)
			"tiles": draw_rect(Rect2(p + Vector2(-4, -19), Vector2(8, 4)), Color("5a6070"))
			"crate": draw_rect(Rect2(p + Vector2(-4, -18), Vector2(8, 5)), Color("7a5634"))

## 가게: 상인이 손짓하고, 손님이 길에서 걸어와 흥정한 뒤 보따리를 들고 돌아간다(주기 16초)
func _shop_scene(c: Vector2, a: Vector2, f: Vector2, t: float, chatty: bool, talk_i: int, trade: String = "") -> void:
	var seller := MarketArt.P(c, a, f, -0.25, 0.72)
	var counter := MarketArt.P(c, a, f, 0.05, 0.85)
	var gest := 0.5 + 0.5 * sin(t * 1.7)
	var tg: String = GoodsArt.TRADE_GOODS.get(trade, "")
	if tg != "":
		GoodsArt.draw(self, counter + Vector2(0, 2), tg, 0.85) # 판매대에 놓인 물건
	var road := MarketArt.P(c, a, f, 0.75, 1.15)
	var stop := MarketArt.P(c, a, f, 0.3, 1.08)
	var cyc := fmod(t, 16.0)
	var buyer := Vector2.ZERO
	var walking := false
	var dv := Vector2.ZERO
	var has_bundle := false
	var present := true
	if cyc < 3.0:
		buyer = road.lerp(stop, cyc / 3.0)
		walking = true
		dv = stop - road
	elif cyc < 10.0:
		buyer = stop
		dv = counter - stop
	elif cyc < 13.0:
		buyer = stop.lerp(road, (cyc - 10.0) / 3.0)
		walking = true
		dv = road - stop
		has_bundle = true
	else:
		present = false
	var serve := present and not walking
	var seller_face := _gdir_screen((buyer if present else road) - seller)
	var buyer_robe := Color("d8ccb0") if int(t / 16.0) % 2 == 0 else Color("c8d4e0")
	var buyer_hat := 1 if int(t / 16.0) % 3 == 0 else 0
	var seller_kind: String = TRADE_SELLER.get(trade, "")
	var buyer_kind: String = MARKET_CROWD[(int(t / 16.0) * 3 + int(c.x)) % MARKET_CROWD.size()]
	# 앞뒤 순서: 화면 아래쪽(앞)을 나중에 그린다
	var buyer_first := present and buyer.y < seller.y
	var draw_buyer := func() -> void:
		if not NpcSprites.sheet_for(buyer_kind).is_empty():
			_kind_at(buyer, buyer_kind, _gdir_screen(dv), walking, t, 0.3 if not walking else 0.0)
			if has_bundle and not GoodsArt.draw(self, buyer + Vector2(5, -3), "bundle", 0.7):
				FastDraw.circle(self, buyer + Vector2(5, -7), 2.6, Color("c8a060"))
		else:
			_shop_buyer(buyer, buyer_robe, buyer_hat, dv, walking, has_bundle, t)
	if buyer_first:
		draw_buyer.call()
	if seller_kind != "" and not NpcSprites.sheet_for(seller_kind).is_empty():
		_kind_at(seller, seller_kind, seller_face, false, t, gest if serve else 0.0)
	else:
		_yard_person(seller, Color("e8dcc4"), 2, seller_face, false, gest if serve else 0.2, t)
	if present and not buyer_first:
		draw_buyer.call()
	if chatty and serve:
		var pair: Array = SHOP_TALK[talk_i % SHOP_TALK.size()]
		var second := fmod(cyc - 3.0, 7.0) > 3.5
		_draw_speech_bubble((buyer if second else seller) + Vector2(0, -22), String(pair[1] if second else pair[0]), "")

func _shop_buyer(p: Vector2, robe: Color, hat: int, dv: Vector2, walking: bool, bundle: bool, t: float) -> void:
	_yard_person(p, robe, hat, _gdir_screen(dv), walking, 0.3, t)
	if bundle and not GoodsArt.draw(self, p + Vector2(5, -3), "bundle", 0.7):
		FastDraw.circle(self, p + Vector2(5, -7), 2.6, Color("c8a060")) # 보따리

## 훈장: 갓 쓰고 수염, 회초리를 들었다 놓았다
func _satto_teacher(p: Vector2, t: float) -> void:
	# 훈장: 갓 쓴 흰 도포, 흰 수염, 회초리를 들었다 놓았다
	var key := NpcSprites.custom_kind("yangban", Color("e8e2d4"), Color("e8e2d4"), Color("6a3a3a"))
	_spr_seat(p, key, 0, Color("d8d2c4"))
	var k := _sk()
	draw_line(p + Vector2(0.5, -9) * k, p + Vector2(0.5, -6) * k, Color("f0f0f0"), 1.4 * k) # 흰 수염
	var sw := 0.5 + 0.5 * sin(t * 1.4)
	draw_line(p + Vector2(5, -8) * k, p + Vector2(11, -13 - sw * 6.0) * k, Color("6e4a2c"), 1.0) # 회초리

## PORT-TRACE [천주교당]: 집회소 앞에 숨죽여 모인 교우 셋(흰 옷, 고개 숙여 기도), 가끔 "천주를 공경하세…" 속삭임
func _draw_chapels() -> void:
	if _chapels.is_empty():
		return
	var bounds := _get_view_bounds()
	var t := _scene_t
	# PORT-TRACE [교우 모임]: 교우 셋이 집회소 칸에, 천주교 학자는 그 앞 길에 따로 있어 혼자 떨어져 앉은 듯했다 —
	# 학자가 있으면 그 바로 앞에 셋이 등을 보이고 무릎 꿇어 한 무리로 모이고, 학자가 쫓기거나 붙잡히면 흩어진다.
	var scholar_of := {}
	if citizens:
		for a: Dictionary in citizens.agents:
			if a.get("type", "") == "catholic" and not a.get("is_dead", false):
				scholar_of[(a.get("extra", {}) as Dictionary).get("home", Vector2i(-1, -1))] = a
	const BELIEVERS := ["believer_w", "believer_m", "believer_old"]
	for h: Vector2i in _chapels:
		var c := _cc(float(h.x) + 0.5, float(h.y) + 0.95)
		var sc: Dictionary = scholar_of.get(h, {})
		if not sc.is_empty():
			if String(sc.get("state", "")) in ["fleeing", "arrested"]:
				continue # 관헌이 들이닥치자 교우들은 흩어졌다
			var gx := clampi(int(round(float(sc["x"]))), 0, grid.size - 1)
			var gy := clampi(int(round(float(sc["y"]))), 0, grid.size - 1)
			c = city.cell_center(float(sc["x"]), float(sc["y"]), float(grid.grid[gy][gx]["elevation"])) + Vector2(0, 12.0) * _sk()
		if not bounds.has_point(c):
			continue
		for i in range(3):
			var p := c + Vector2(-10.0 + float(i) * 10.0, 2.0 + float(i % 2) * 2.5) * _sk()
			# 등 돌려 무릎 꿇고 기도(왼쪽 사람은 오른쪽 뒤, 오른쪽 사람은 왼쪽 뒤를 보며 가운데 학자를 향함)
			_spr_seat(p, BELIEVERS[i], 2 if i == 0 else (3 if i == 2 else 2 + int(t / 6.0 + float(h.y)) % 2), Color("e6e0d2"))
		if sc.is_empty() and int(t / 8.0 + float(h.x)) % 4 == 0:
			_draw_speech_bubble(c + Vector2(0, -18), "쉿… 천주를 공경하세…", "")

## 성곽 미완성 끊김 지점 점멸 타일 가이드 하이라이트
func _draw_wall_guide_highlight() -> void:
	if not grid or not city or not grid.in_bounds(wall_guide_target.x, wall_guide_target.y):
		return
	var elev: float = float(grid.grid[wall_guide_target.y][wall_guide_target.x].get("elevation", 0.0))
	var c: Vector2 = city.cell_center(float(wall_guide_target.x) + 0.5, float(wall_guide_target.y) + 0.5, elev)
	var t: float = float(Time.get_ticks_msec()) * 0.006
	var pulse: float = 0.5 + 0.5 * sin(t)
	var col: Color = Color("ff3333").lerp(Color("ffdd00"), pulse)
	col.a = 0.9

	var half_w: float = 32.0
	var half_h: float = 16.0
	var p_n: Vector2 = c + Vector2(0.0, -half_h)
	var p_e: Vector2 = c + Vector2(half_w, 0.0)
	var p_s: Vector2 = c + Vector2(0.0, half_h)
	var p_w: Vector2 = c + Vector2(-half_w, 0.0)

	var poly: PackedVector2Array = PackedVector2Array([p_n, p_e, p_s, p_w])
	var outline: PackedVector2Array = PackedVector2Array([p_n, p_e, p_s, p_w, p_n])

	draw_colored_polygon(poly, Color(col.r, col.g, col.b, 0.35))
	draw_polyline(outline, col, 3.0)

	# 중앙 안내 가이드 십자/경고 표시
	draw_line(c + Vector2(0, -7), c + Vector2(0, 3), col, 2.5)
	draw_circle(c + Vector2(0, 6), 1.6, col)

# ============================================================ 근대화 시대: 마당 → 시민공원·어린이 놀이터·체육공원
## 개편한 마당 종류의 근대 그림(UrbanEvolutionManager). 그림 파일이 없거나 개편 전이면 null(옛 장면 그대로)
func _modern_plaza_tex(kind: String) -> Texture2D:
	var um := UrbanEvolutionManager.instance
	return um.plaza_texture(kind) if um != null else null

## 마당 하나(n×n 칸)를 덮는 아이소 그림: 그림 아래쪽 n*16 픽셀이 바닥 마름모(art_ingest 캔버스 규격)
var _mp_cache := {}       # 마당 종류 → 목록(마당이 바뀔 때만 다시 셈)
var _mp_src: Array = []

func _draw_modern_plazas() -> void:
	if not is_same(_mp_src, _play_yards): # _draw_play_yards가 마당 목록을 새로 만들면 같이 갱신
		_mp_src = _play_yards
		_mp_cache.clear()
	var bounds := _get_view_bounds()
	for kind: String in ["market", "kids", "play"]:
		var tex := _modern_plaza_tex(kind)
		if tex == null:
			continue
		if not _mp_cache.has(kind):
			_mp_cache[kind] = grid.list_plazas(kind)
		for pl: Dictionary in _mp_cache[kind]:
			var n := float(pl["n"])
			var cen := _cc(float(pl["x0"]) + n * 0.5, float(pl["y0"]) + n * 0.5)
			if not bounds.has_point(cen):
				continue
			var w := n * 64.0
			var h := w * float(tex.get_height()) / float(maxi(1, tex.get_width()))
			draw_texture_rect(tex, Rect2(cen.x - w * 0.5, cen.y + n * 16.0 - h, w, h), false)
