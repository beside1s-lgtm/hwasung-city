extends Node2D
class_name CityLayer

const SpriteCacheManager = preload("res://scripts/autoload/SpriteCacheManager.gd")

## 조선풍 픽셀아트 아틀라스 기반 2.5D 렌더러 & 심시티 2000 드래그/되돌리기 엔진

signal tool_message(msg: String)
signal tile_inspected(info: String)
signal city_changed
signal gate_naming_requested(pos: Vector2i, default_name: String, desc: String, suggestions: Array)
signal named_npc_inspected(npc_data: Dictionary)
signal tool_selected(tool: String)
@warning_ignore("unused_signal")
signal map_baking_started
@warning_ignore("unused_signal")
signal map_baking_completed

const BATCH_SIZE: int = 40

var grid: GameGrid
var sim: SimulationCore
var citizens: CitizenManager
var ref_layer: TileMapLayer # 좌표 변환 기준
var panels: PanelController
var tutorial: TutorialGuide
var inspect_popup: InspectPopup = null
var haenggung_sub_building_popup: HaenggungSubBuildingPopup = null
var building_interaction_manager: BuildingInteractionManager = null
var citizen_layer: CitizenLayer = null

func show_wall_guide(cell_pos: Vector2i, duration: float = 5.0) -> void:
	if citizen_layer and citizen_layer.has_method("show_wall_guide"):
		citizen_layer.show_wall_guide(cell_pos, duration)

var current_tool: String = "inspect"
var hover_cell := Vector2i(-1, -1)
var _anim := 0.0
var current_season: String = "봄":
	set(v):
		if current_season != v:
			current_season = v
			_vertex_colors_dirty = true
			queue_redraw()
var audio: AudioSystem

# 드래그 건설 및 고스트 미리보기 시스템
var _is_dragging: bool = false
var _drag_start: Vector2i = Vector2i(-1, -1)
var _drag_current: Vector2i = Vector2i(-1, -1)
var _drag_tiles: Array[Vector2i] = []

# 실행 취소 (Undo) 스택
var undo_stack: Array[Dictionary] = []

# 정점 컬러 캐시 (인접 4타일 지형 블렌딩 그라데이션)
var _vertex_colors: Array = []
var _vertex_colors_dirty: bool = true

# 타일 렌더링 깊이 정렬 캐시 (10,000개 딕셔너리 동적 할당 및 GC 스파이크 방지)
var _depth_sorted_tiles: Array[Vector2i] = []
var _depth_order_dirty: bool = true

# PORT-TRACE [렉 해결: 띠 굽기]: 지도를 화면 깊이(x+y) 2줄씩 묶은 "띠" 60여 개로 나눠 각각 따로 그린다.
# 띠 노드(band_master가 있는 CityLayer)는 자기 띠의 타일만 그리고, Main이 바뀐 타일이 속한 띠만 다시
# 그리게 한다 — 건물 하나 지을 때 지도 전체(4,096칸)가 아니라 수백 칸만 다시 그린다. 띠는 깊이 순서대로
# 겹쳐 있으므로 화가 알고리즘(뒤에서 앞으로 칠하기) 순서는 그대로다.
## PORT-TRACE [성능: 얇은 띠]: 측정 결과 띠 하나(깊이 2줄) 그리는 데 ~70ms — 계절이 바뀌어 전부 다시 구울 때 프레임마다
## 띠 하나씩이라 2초 넘게 14fps로 떨어졌다. 띠를 깊이 1줄로 얇게 나눠 프레임당 부담을 절반으로.
const BAND_DEPTH := 1.0
var band_master: CityLayer = null # 띠 노드면 정점 색·정렬을 이 마스터에서 빌려 쓴다
var band_index: int = -1
## PORT-TRACE [성능: 띠 토막]: 띠(대각선 한 줄, 최대 64칸)를 x 범위로 BAND_SEGS 토막 낸 것 중 몇 번째인지
const BAND_SEGS := 4
var band_seg: int = -1

static func seg_of(x: int, size: int) -> int:
	return clampi(int(float(x * BAND_SEGS) / float(maxi(1, size))), 0, BAND_SEGS - 1)
var auto_redraw: bool = true      # false면 grid_changed 때 스스로 다시 그리지 않는다(Main이 골라서 지시)
var _band_tiles: Array = []       # 마스터: 띠마다 그 띠에 속한 타일 목록(깊이 순)

const HW := 32.0
const HH := 16.0
const ELEV_STEP := 12.0

var tex_buildings: Texture2D = (load("res://assets/buildings_atlas.png") as Texture2D) if ResourceLoader.exists("res://assets/buildings_atlas.png") else null
var tex_characters: Texture2D = (load("res://assets/characters_atlas.png") as Texture2D) if ResourceLoader.exists("res://assets/characters_atlas.png") else null

const BUILDING_SLOTS := {
	"seojangdae": 33, "bongdon": 34, "gate": 35,
	"res_1": 36, "res_2": 37, "com_1": 38, "com_2": 39,
	"agr_1": 40, "agr_2": 41, "well": 42, "levee": 43,
	"reservoir": 44, "hyoryungwon": 45, "guesthouse": 46, "factory": 47,
	"patrol": 32, "firefighter": 43
}

const CHAR_ROWS := {
	"carrier": 0, "merchant": 1, "guard": 2, "farmer": 3, "tiger": 4
}

func setup(g: GameGrid, s: SimulationCore, c: CitizenManager, layer: TileMapLayer) -> void:
	grid = g
	sim = s
	citizens = c
	ref_layer = layer
	BuildManager.city_layer = self
	grid.grid_changed.connect(func():
		_vertex_colors_dirty = true
		_depth_order_dirty = true
		if auto_redraw:
			queue_redraw()
	)
	_vertex_colors_dirty = true
	z_index = 5

## 현재 타일 드래그 배치 중인지 여부 반환
func is_dragging() -> bool:
	return _is_dragging

## 고정 단일 시점(4방향 회전 영구 제거): 카메라는 성의 남동쪽 외곽에서 북서쪽을 바라본다.
## 그리드 +x=동, +y=남이고 DIAMOND_DOWN 배치이므로 (0,0)=북서 모서리가 화면 맨 위,
## 서쪽(팔달산)은 화면 위편, 동쪽(창룡문·연무대)은 화면 아래편에 놓인다.
## 회전 좌표 재계산이 없으므로 그리드 좌표를 그대로 화면 축에 곱한다.
func cell_center(x: float, y: float, elev: float = 0.0) -> Vector2:
	if not ref_layer:
		var p_iso := Vector2((x - y) * 32.0, (x + y) * 16.0)
		p_iso.y -= elev * ELEV_STEP
		return p_iso
	var o := ref_layer.map_to_local(Vector2i(0, 0))
	var ex := ref_layer.map_to_local(Vector2i(1, 0)) - o
	var ey := ref_layer.map_to_local(Vector2i(0, 1)) - o
	var p := o + ex * x + ey * y
	p.y -= elev * ELEV_STEP
	return p

func world_to_cell(p: Vector2) -> Vector2i:
	var rc := ref_layer.local_to_map(ref_layer.to_local(p))
	var guess := rc
	if grid and grid.in_bounds(guess.x, guess.y):
		var h: float = grid.tile(guess.x, guess.y)["elevation"]
		if absf(h) > 0.05:
			var adjusted := p + Vector2(0, h * ELEV_STEP)
			var rc2 := ref_layer.local_to_map(ref_layer.to_local(adjusted))
			var guess2 := rc2
			if grid.in_bounds(guess2.x, guess2.y):
				return guess2
	return guess

## PORT-TRACE [텍스처 베이크]: 이 CityLayer는 더 이상 "매 프레임 다시 그리는" 레이어가
## 아니다. 정적 지형/건물은 grid_changed가 일어날 때만 queue_redraw()가 호출되고
## (Main.gd의 WorldBaker 설정 참고), 그 결과가 SubViewport 텍스처로 한 번 구워져 화면에는
## 단일 스프라이트로 표시된다. 움직이는 시민·마우스 커서·드래그 미리보기는 CitizenLayer.gd가
## 따로 맡아 매 프레임 그린다. _anim은 봉돈 연기 등 정적 레이어 애니메이션이 "다음 번 다시
## 구워질 때" 자연스러운 위상을 갖도록 값만 조용히 흘려보낸다(그리기 자체는 트리거하지 않음).
func _process(delta: float) -> void:
	_anim += delta

# ---------------------------------------------------------------- 드래그 타일 계산 (Bresenham & Box)
func _calc_drag_tiles(p1: Vector2i, p2: Vector2i, tool: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not grid.in_bounds(p1.x, p1.y) or not grid.in_bounds(p2.x, p2.y):
		return result

	if tool.begins_with("zone_") or tool == "demolish":
		# 가로x세로 사각 구역 (Box Area)
		var min_x = mini(p1.x, p2.x)
		var max_x = maxi(p1.x, p2.x)
		var min_y = mini(p1.y, p2.y)
		var max_y = maxi(p1.y, p2.y)
		for y in range(min_y, max_y + 1):
			for x in range(min_x, max_x + 1):
				if grid.in_bounds(x, y):
					result.append(Vector2i(x, y))
	elif tool in ["road", "stone_road", "wall"] or tool.begins_with("terra_"):
		# 브레젠험(Bresenham) 직선 알고리즘으로 연속된 길/성곽 연결 (지형 붓질도 같은 방식으로 죽 긋는다)
		var x0 = p1.x
		var y0 = p1.y
		var x1 = p2.x
		var y1 = p2.y
		var dx = absi(x1 - x0)
		var dy = absi(y1 - y0)
		var sx = 1 if x0 < x1 else -1
		var sy = 1 if y0 < y1 else -1
		var err = dx - dy

		while true:
			if grid.in_bounds(x0, y0):
				result.append(Vector2i(x0, y0))
			if x0 == x1 and y0 == y1:
				break
			var e2 = 2 * err
			if e2 > -dy:
				err -= dy
				x0 += sx
			if e2 < dx:
				err += dx
				y0 += sy
	else:
		# 단일 타일 건물 (동헌, 관청, 저수지 등)
		result.append(p1)

	return result

## 도구별 실제 점유 규격(Footprint) 타일 목록 반환 (고스트 프리뷰용)
func get_tool_footprint(tool: String, cx: int, cy: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if grid == null:
		result.append(Vector2i(cx, cy))
		return result
	if GameGrid.SITE_BUILDINGS.has(tool):
		var info: Dictionary = GameGrid.SITE_BUILDINGS[tool]
		var raw_tiles: Array = grid.get_site_footprint(cx, cy, int(info["w"]), int(info["h"]))
		for pt in raw_tiles:
			if pt is Vector2i:
				result.append(pt)
			elif pt is Vector2:
				result.append(Vector2i(int(pt.x), int(pt.y)))
		return result
	elif tool == "bongdon":
		var bdf: Dictionary = grid.get_bongdon_tiles(cx, cy)
		if bdf.get("err", "") == "":
			for pt: Vector2i in bdf["wall"]:
				result.append(pt)
			for pt2: Vector2i in bdf["out"]:
				result.append(pt2)
			return result
		result.append(Vector2i(cx, cy))
		return result
	elif tool == "seojangdae":
		for dy in range(2):
			for dx in range(2):
				result.append(Vector2i(cx + dx, cy + dy))
		return result
	elif tool == "yeonmudae":
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				result.append(Vector2i(cx + dx, cy + dy))
		var ymp: Dictionary = grid.get_yeonmudae_tiles(cx, cy)
		if str(ymp.get("err", "")) == "":
			for rq: Vector2i in ymp.get("range", []):
				result.append(rq) # 성 밖 활터 구역도 함께 미리 보여 준다
		return result
	elif tool == "poru":
		var prf: Dictionary = grid.get_poru_tiles(cx, cy)
		if prf.get("err", "") == "":
			for pt: Vector2i in prf["wall"]:
				result.append(pt)
			for pt2: Vector2i in prf["out"]:
				result.append(pt2)
			return result
		result.append(Vector2i(cx, cy))
		return result
	elif tool == "gongsimdon":
		var gsf: Dictionary = grid.get_gongsimdon_tiles(cx, cy)
		if gsf.get("err", "") == "":
			for key: String in ["wall", "in", "out"]:
				for pt: Vector2i in gsf[key]:
					result.append(pt)
			return result
		result.append(Vector2i(cx, cy))
		return result
	elif tool == "hwahong":
		var hw: Dictionary = grid.get_hwahong_tiles(cx, cy)
		for pt in hw.get("tiles", []):
			if pt is Vector2i:
				result.append(pt)
			elif pt is Vector2:
				result.append(Vector2i(int(pt.x), int(pt.y)))
		return result
	elif tool in ["banghwasuryu", "yongyeon"]:
		var comp: Dictionary = grid.get_banghwa_complex_tiles(cx, cy)
		for pt in comp.get("banghwa", []):
			if pt is Vector2i:
				result.append(pt)
			elif pt is Vector2:
				result.append(Vector2i(int(pt.x), int(pt.y)))
		for pt in comp.get("yongyeon", []):
			if pt is Vector2i:
				result.append(pt)
			elif pt is Vector2:
				result.append(Vector2i(int(pt.x), int(pt.y)))
		return result
	else:
		result.append(Vector2i(cx, cy))
		return result

## 도구 배치 유효성 검사 (초록/빨강 피드백용)
func is_tool_valid_at(tool: String, cx: int, cy: int) -> bool:
	if grid == null:
		return false
	if GameGrid.SITE_BUILDINGS.has(tool):
		return grid.validate_site(tool, cx, cy) == ""
	else:
		return grid.validate_tool(tool, cx, cy) == ""

# ---------------------------------------------------------------- 입력 (드래그, 우클릭 취소, Undo)
func _unhandled_input(event: InputEvent) -> void:
	if grid == null:
		return
	if EventManager.has_active_modal():
		return
	if panels and panels.is_modal_open():
		return
	if tutorial and tutorial.is_modal_open():
		return

	if event is InputEventKey and event.pressed:
		if (event.keycode == KEY_Z and event.ctrl_pressed) or event.keycode == KEY_U:
			undo()
			return

	if event is InputEventMouseMotion:
		hover_cell = world_to_cell(get_global_mouse_position())
		if _is_dragging:
			_drag_current = hover_cell
			_drag_tiles = _calc_drag_tiles(_drag_start, _drag_current, current_tool)
			queue_redraw()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				hover_cell = world_to_cell(get_global_mouse_position())
				if current_tool == "inspect":
					_show_inspect(hover_cell)
					return
				# 대형 부지 시설(행궁, 만석거 등)은 클릭 1회로 즉시 부지 지정 및 착공 확정
				if GameGrid.SITE_BUILDINGS.has(current_tool) or current_tool in ["hwahong", "banghwasuryu", "yongyeon", "bongdon", "seojangdae", "gongsimdon", "yeonmudae", "poru"]:
					_is_dragging = false
					_apply_batch_build([hover_cell], current_tool)
					queue_redraw()
					return
				# 일반 도구(도로, 성곽, 구획 등): 드래그 시작
				_is_dragging = true
				_drag_start = hover_cell
				_drag_current = hover_cell
				_drag_tiles = _calc_drag_tiles(_drag_start, _drag_current, current_tool)
				queue_redraw()
			else:
				# 마우스 뗌 -> 일괄 건설 확정
				if _is_dragging:
					_is_dragging = false
					_apply_batch_build(_drag_tiles, current_tool)
					_drag_tiles.clear()
					queue_redraw()

		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_build_or_select()

## 마우스 우클릭 등에 의한 건설/선택 모드 취소
func cancel_build_or_select() -> void:
	var was_dragging: bool = _is_dragging
	_is_dragging = false
	_drag_tiles.clear()
	if current_tool != "inspect":
		current_tool = "inspect"
		emit_signal("tool_selected", "inspect")
		emit_signal("tool_message", "건물 배치를 취소하고 살피기로 복귀했습니다.")
		if audio: audio.play("select")
	elif was_dragging:
		emit_signal("tool_message", "건설을 취소하였습니다.")
		if audio: audio.play("error")
	queue_redraw()

func _show_inspect(c: Vector2i) -> void:
	if not grid.in_bounds(c.x, c.y):
		return

	# 1. 네임드 NPC 클릭 판정 우선 검사 (정조, 정약용, 김홍도 등)
	if citizens:
		var named_npc: Dictionary = citizens.get_named_npc_near(Vector2(float(c.x) + 0.5, float(c.y) + 0.5), 1.2)
		if not named_npc.is_empty():
			emit_signal("named_npc_inspected", named_npc)
			GameProgressManager.on_inspect_named(str(named_npc.get("named_id", ""))) # 역사 인물 퍼즐 조각 해금(살피기로만)
			var n_name: String = named_npc.get("name", "인물")
			var b_text: String = named_npc.get("bubble_text", "")
			emit_signal("tile_inspected", "[화성 명인] %s: \"%s\"" % [n_name, b_text])
			if inspect_popup:
				var n_entity: Dictionary = named_npc.duplicate()
				n_entity["kind"] = "named_npc"
				var data: Dictionary = InspectNarrativeGenerator.build_inspect_data(n_entity, sim, grid, citizens)
				inspect_popup.open_inspect(data["title"], data["description"], data["texture"])
			if audio: audio.play("coin")
			return

	# 2. 일반 보행 시민 / 야생 동물 클릭 판정 (상인, 순라군, 농민, 호랑이, 사슴 등)
	if citizens:
		var agent_near: Dictionary = citizens.get_agent_near(Vector2(float(c.x) + 0.5, float(c.y) + 0.5), 1.0)
		if not agent_near.is_empty():
			var a_type: String = agent_near.get("type", "시민")
			GameProgressManager.on_inspect_agent(a_type) # 역사 사전 퍼즐 조각 해금
			emit_signal("tile_inspected", "[살피기] %s" % a_type)
			if a_type == "catholic":
				var cat_res: Dictionary = citizens.trigger_catholic_interaction(agent_near)
				if inspect_popup:
					inspect_popup.open_inspect(cat_res["title"], cat_res["description"], cat_res["texture"])
				if audio: audio.play("select")
				return
			if inspect_popup:
				var a_entity: Dictionary = agent_near.duplicate()
				var is_wild: bool = agent_near.get("is_wild", false) or a_type in ["tiger", "wolf", "wild_boar", "deer", "crane", "rabbit"]
				a_entity["kind"] = "animal" if is_wild else "npc"
				var a_data: Dictionary = InspectNarrativeGenerator.build_inspect_data(a_entity, sim, grid, citizens)
				if not is_wild:
					# PORT-TRACE [거리 사람들의 정체성]: 팝업에 지금 하는 일과 방금 한 말을 덧붙인다
					var act := StreetLife.activity_of(agent_near)
					var said := String(agent_near.get("last_line", agent_near.get("bubble_text", "")))
					var more := ""
					if act != "":
						more += "

· 지금: " + act
					if said != "":
						more += ("
" if act != "" else "

") + "· 방금 한 말: \"" + said + "\""
					a_data["description"] = String(a_data["description"]) + more
				inspect_popup.open_inspect(a_data["title"], a_data["description"], a_data["texture"])
			if audio: audio.play("select")
			return

	# 2.5. 세시풍속 놀이판 및 민속놀이 마당 스팟 클릭 판정 (축제 놀이판, 그네/널뛰기 마당, 아이들 마당, 전기수)
	var folklore_act: String = ""
	var folklore_pos: Vector2 = Vector2(float(c.x) + 0.5, float(c.y) + 0.5)

	# A. FestivalSystem의 계절 놀이판 (festivals.scenes)
	var fest_sys: FestivalSystem = null
	if citizen_layer and citizen_layer.festivals:
		fest_sys = citizen_layer.festivals
	if fest_sys and not fest_sys.scenes.is_empty():
		for sc in fest_sys.scenes:
			var skind: String = str(sc.get("kind", ""))
			var sc_cen: Vector2 = sc.get("center", Vector2.INF)
			var dist: float = folklore_pos.distance_to(sc_cen)
			if skind == "seokjeon":
				var sc_oth: Vector2 = sc.get("other_pos", Vector2.INF)
				if dist <= 1.8 or (sc_oth != Vector2.INF and folklore_pos.distance_to(sc_oth) <= 1.8):
					folklore_act = "ACTIVITY_SEOKJEON"
					break
			elif dist <= 2.2:
				match skind:
					"jwibul":
						folklore_act = "ACTIVITY_JWIBULNORI"
					"kites":
						folklore_act = "ACTIVITY_KITE_FLYING"
					"ganggang":
						folklore_act = "ACTIVITY_GANGGANGSULLAE"
					"juldagi":
						folklore_act = "ACTIVITY_NAMSADANG"
					"ssireum":
						folklore_act = "ACTIVITY_SSIREUM"
					"talchum":
						folklore_act = "ACTIVITY_TALCHUM"
					"paengi":
						folklore_act = "ACTIVITY_PAENGI"
					"taekkyeon":
						folklore_act = "ACTIVITY_TAEKKYEON"
					"pungmul":
						if dist <= 0.8:
							folklore_act = "ACTIVITY_LION_DANCE"
						else:
							folklore_act = "ACTIVITY_PUNGMUL"
				if folklore_act != "":
					break

	# B. CitizenLayer의 상설 마당 스팟 (전기수, 그네/널뛰기 마당, 아이들 마당)
	if folklore_act == "":
		if citizen_layer and citizen_layer._jeongisu_spot != Vector2.INF:
			if folklore_pos.distance_to(citizen_layer._jeongisu_spot) <= 2.0:
				folklore_act = "ACTIVITY_JEONJISU"

		if folklore_act == "":
			var play_yards: Array = citizen_layer._play_yards if (citizen_layer and not citizen_layer._play_yards.is_empty()) else (grid.list_plazas("play") if grid else [])
			for pl in play_yards:
				var x0: int = int(pl.get("x0", -99))
				var y0: int = int(pl.get("y0", -99))
				if c.x >= x0 and c.x < x0 + 2 and c.y >= y0 and c.y < y0 + 2:
					if current_season != "겨울" and c.y == y0:
						folklore_act = "ACTIVITY_SWINGING"
					else:
						folklore_act = "ACTIVITY_NEOLTTWIGI"
					break

		if folklore_act == "":
			var kid_yards: Array = citizen_layer._kid_yards if (citizen_layer and not citizen_layer._kid_yards.is_empty()) else (grid.list_plazas("kids") if grid else [])
			for pl in kid_yards:
				var x0: int = int(pl.get("x0", -99))
				var y0: int = int(pl.get("y0", -99))
				if c.x >= x0 and c.x < x0 + 2 and c.y >= y0 and c.y < y0 + 2:
					folklore_act = "ACTIVITY_YARD_GAMES"
					break

	if folklore_act != "":
		GameProgressManager.on_inspect_activity(folklore_act) # 역사 사전 퍼즐 조각 해금
		emit_signal("tile_inspected", "[세시풍속] %s" % folklore_act)
		if inspect_popup:
			var f_entity: Dictionary = {
				"kind": "folklore",
				"activity_type": folklore_act,
				"pos": c
			}
			var f_data: Dictionary = InspectNarrativeGenerator.build_inspect_data(f_entity, sim, grid, citizens)
			inspect_popup.open_inspect(f_data["title"], f_data["description"], f_data["texture"])
		if audio: audio.play("select")
		return

	# 3. 도적 소굴 클릭 판정 (동적 소굴 SSOT 검사)
	if citizens and citizens.sim:
		var b_mgr: BanditManager = citizens.bandit_mgr
		if b_mgr != null and not b_mgr.camps.is_empty():
			var clicked_camp: Dictionary = {}
			for c_dict: Dictionary in b_mgr.camps:
				var c_pos: Vector2i = c_dict.get("pos", Vector2i(-1, -1))
				if c_pos.x >= 0 and absi(c.x - c_pos.x) <= 1 and absi(c.y - c_pos.y) <= 1:
					clicked_camp = c_dict
					break
			if not clicked_camp.is_empty():
				var c_name: String = str(clicked_camp.get("name", "도적 소굴"))
				var p_pwr: int = int(clicked_camp.get("combat_power", 150))
				var b_title: String = "[도적 소굴] %s (전투력 %d)" % [c_name, p_pwr]
				var b_desc: String = "깊은 산속 험준한 바위에 둥지를 튼 도적 떼.\n화성 신시의 민가와 상단을 노리며 숨어 있습니다.\n수원유수부 토벌대를 급파하거나 장용영으로 소탕해야 합니다.\n소탕 시 빼앗긴 재물을 되찾고 평온을 누립니다."
				emit_signal("tile_inspected", b_title)
				if inspect_popup:
					inspect_popup.open_inspect(b_title, b_desc, InspectNarrativeGenerator.get_portrait("bandit_camp"))
				if audio: audio.play("select")
				return

	# 4. 건물 / 건설 현장 / 주거 민가 / 지형 클릭 판정
	var t: Dictionary = grid.tile(c.x, c.y)
	var b: String = str(t.get("building", ""))
	var b_name := "빈 터"
	var p_info: Dictionary = t.get("plaza", {}) if t.get("plaza") is Dictionary else {}
	var p_kind: String = str(p_info.get("kind", ""))

	# 화성행궁 본궁 영역 클릭 판정 -> 전각 선택 UI (HaenggungSubBuildingPopup) 오픈
	var is_haenggung_tile: bool = (b == "haenggung" or b == "haenggung_site" or str(t.get("facility_id", "")).begins_with("haenggung"))
	if is_haenggung_tile and haenggung_sub_building_popup != null and not bool(t.get("under_construction", false)):
		haenggung_sub_building_popup.open_haenggung_popup(t)
		emit_signal("tile_inspected", "화성행궁 어전 정무: 전각을 선택하여 정무를 윤허하십시오.")
		if audio: audio.play("select")
		return

	if str(t.get("facility_id", "")) == "namsu_mun" or t.get("is_namsu", false):
		b_name = "남수문 (南水門)"
	elif str(t.get("facility_id", "")) == "hwahong_mun" or t.get("is_hwahong", false):
		b_name = "화홍문 (華虹門)"
	elif str(t.get("facility_id", "")) in ["maehwang_gyo", "maehyang_gyo"] or t.get("is_maehyang", false):
		b_name = "매향교 (梅香橋)"
	elif p_kind in ["seowon", "maegok_seowon"] or str(t.get("facility_id", "")) in ["seowon", "maegok_seowon"] or str(t.get("special_type", "")) in ["seowon", "maegok_seowon"] or b in ["seowon", "maegok_seowon"]:
		b_name = "화성 유학 서원 (書院)"
	elif p_kind == "seodang" or str(t.get("facility_id", "")) == "seodang" or str(t.get("special_type", "")) == "seodang" or b == "seodang":
		b_name = "동네 서당 (글방)"
	elif b in ["gwana", "gwana_site"] or str(t.get("facility_id", "")) in ["gwana", "gwana_site"]:
		b_name = "화성유수부 동헌 (관아)"
	elif b == "gate":
		var gn: String = t.get("gate_name", "")
		b_name = "[%s] 홍예성문" % (gn if gn != "" else "홍예성문")
	elif b == "wall" and (t["terrain"] == "water" or t.get("is_bridge", false)):
		var is_south: bool = c.y >= int(float(grid.size) / 2.0)
		b_name = "남수문 (南水門)" if is_south else "화홍문 (華虹門)"
	elif b == "patrol":
		b_name = "순라청 (치안·도적 소탕)"
	elif b == "res_1":
		b_name = "소박한 서민 초가집"
	elif b == "res_2":
		b_name = "단정한 살림 기와집 (여염집)"
	elif b == "res_3":
		b_name = "고급 사대부 기와집"
	elif b != "":
		b_name = InspectNarrativeGenerator.get_korean_name(b, b)
		if t.has("trade"): # 가게·공방은 업종 이름도 보여 준다(예: com_1 · 싸전)
			b_name = "%s · %s" % [b_name, MarketArt.TRADE_NAMES.get(t["trade"], t["trade"])]
		if t.has("prosper"):
			b_name += " · 번영 %d/5 · 매출 %d" % [int(t["prosper"]), int(t.get("sales", 0))]
		if t.has("lv"):
			b_name += " · 입지 %d" % int(t["lv"])
	emit_signal("tile_inspected", "(%d,%d) 지형:%s 고도:%.1f 건물:%s 구획:%s 도로거리:%d" % [
		c.x, c.y, t["terrain"], t["elevation"], b_name, t["zone"] if t["zone"] != "" else "-", grid.distance_to_road(c.x, c.y)
	])

	if inspect_popup:
		var t_entity: Dictionary = t.duplicate()
		t_entity["pos"] = c
		var has_special: bool = (
			str(t.get("facility_id", "")) != "" or
			t.get("is_special_building", false) or
			t.get("is_namsu", false) or
			t.get("is_hwahong", false) or
			t.get("is_maehyang", false) or
			(t.get("terrain") == "water" and b in ["wall", "road", "stone_road"]) or
			p_kind in ["seowon", "maegok_seowon", "seodang", "cattle", "play", "kids", "market"] or
			b in ["gwana", "gwana_site", "seowon", "maegok_seowon"]
		)
		if has_special:
			var s_id: String = str(t.get("facility_id", ""))
			if s_id == "":
				if t.get("is_namsu", false) or (b == "wall" and c.y >= int(float(grid.size) / 2.0)):
					s_id = "namsu_mun"
				elif t.get("is_hwahong", false) or b == "wall":
					s_id = "hwahong_mun"
				elif t.get("is_maehyang", false) or b in ["road", "stone_road"]:
					s_id = "maehwang_gyo"
				elif p_kind in ["seowon", "maegok_seowon"] or b in ["seowon", "maegok_seowon"]:
					s_id = "seowon"
				elif p_kind != "":
					s_id = p_kind
				elif b in ["gwana", "gwana_site"]:
					s_id = "gwana"
			t_entity["facility_id"] = s_id
			t_entity["special_building_id"] = s_id
			t_entity["special_type"] = s_id
			t_entity["is_special_building"] = true
			t_entity["building_name"] = b_name
		elif t.has("wall_build"):
			t_entity["under_construction"] = true
			t_entity["building_name"] = "성곽 체성"
		elif t.get("under_construction", false):
			t_entity["building_name"] = b_name
		if t.get("cheonju", false) and citizens:
			var cat_t_res: Dictionary = citizens.trigger_catholic_interaction(c)
			inspect_popup.open_inspect(cat_t_res["title"], cat_t_res["description"], cat_t_res["texture"])
			return
		var tile_data: Dictionary = InspectNarrativeGenerator.build_inspect_data(t_entity, sim, grid, citizens)
		inspect_popup.open_inspect(tile_data["title"], tile_data["description"], tile_data["texture"])

# ---------------------------------------------------------------- 성문 방위 판정 및 고증 데이터
## PORT-TRACE [성문 이름 고증]: 예전에는 y<24면 무조건 장안문으로 판정해, 지도 북서쪽의 서문(화서문)이나
## 북쪽 수원천 위 수문(화홍문)도 "장안문"으로 추천되는 문제가 있었다(사용자 제보). 이제는
## 1) 성문이 실제로 향하는 바깥 방향(_gate_outward_edge: 0=북,1=동,2=남,3=서)으로 방위를 정하고
## 2) 물(수원천) 위나 다리 위의 문이면 수문(북=화홍문, 남=남수문)으로 추천하며
## 3) 이미 다른 성문이 쓰는 이름은 빼고 남은 이름 중 첫 번째를 기본값으로 삼아 같은 이름의 문이 겹치지 않게 한다.
const GATE_NAME_TABLE := {
	"north": {"desc": "수도 한양을 바라보는 화성의 정문(북문)이자 '백성이 영원히 평안하라'는 뜻의 대문",
		"names": ["장안문 (長安門)", "북암문 (北暗門)"]},
	"south": {"desc": "사통팔달(四通八達) 삼남대로로 모든 물류와 인구가 통하는 번화한 남쪽 정문 (보물 제402호)",
		"names": ["팔달문 (八達門)", "남암문 (南暗門)"]},
	"west": {"desc": "팔달산 북서쪽 기슭에서 서해와 서남포구로 통하는 서쪽 대문 (보물 제403호)",
		"names": ["화서문 (華西門)", "서암문 (西暗門)", "서남암문 (西南暗門)"]},
	"east": {"desc": "동쪽 푸른 용의 기운으로 연무대와 이어져 신도시를 수호하는 동쪽 대문",
		"names": ["창룡문 (蒼龍門)", "동암문 (東暗門)"]},
	"water_north": {"desc": "수원천이 성 안으로 흘러드는 북쪽 수문. 일곱 칸 홍예 위에 누각을 얹어 '무지개가 뜬 문'이라 불린 화홍문(북수문)",
		"names": ["화홍문 (華虹門)", "북수문 (北水門)"]},
	"water_south": {"desc": "수원천이 성 밖으로 빠져나가는 남쪽 수문. 아홉 칸 홍예로 물을 흘려 보낸 남수문",
		"names": ["남수문 (南水門)"]},
}
const GATE_NAME_FALLBACK: Array[String] = ["진남문 (鎭南門)", "영춘문 (迎春門)", "보화문 (保和門)", "안녕문 (安寧門)", "만년문 (萬年門)", "경화문 (景和門)"]

## 이미 지어진 다른 성문들의 이름(괄호 앞 한글 이름 기준으로 비교)
func used_gate_names(except: Vector2i = Vector2i(-1, -1)) -> Array[String]:
	var used: Array[String] = []
	for y in range(grid.size):
		for x in range(grid.size):
			if Vector2i(x, y) == except:
				continue
			var t: Dictionary = grid.grid[y][x]
			if t["building"] == "gate":
				var gn: String = t.get("gate_name", "")
				if gn != "":
					used.append(gate_base_name(gn))
	return used

## "장안문 (長安門)" → "장안문"
static func gate_base_name(n: String) -> String:
	return n.split("(")[0].strip_edges()

func get_gate_info_for_pos(pos: Vector2i) -> Dictionary:
	var t: Dictionary = grid.tile(pos.x, pos.y)
	var on_water: bool = t["terrain"] == "water" or t.get("is_bridge", false)
	var e := _gate_outward_edge(pos.x, pos.y)
	var dir_key: String = ["north", "east", "south", "west"][e]
	if on_water:
		dir_key = "water_south" if e == 2 else "water_north"
	var entry: Dictionary = GATE_NAME_TABLE[dir_key]
	var used := used_gate_names(pos)
	var suggestions: Array = []
	for n: String in entry["names"]:
		if not (gate_base_name(n) in used):
			suggestions.append(n)
	for n: String in GATE_NAME_FALLBACK:
		if suggestions.size() >= 4:
			break
		if not (gate_base_name(n) in used) and not (n in suggestions):
			suggestions.append(n)
	var def_name: String = suggestions[0] if not suggestions.is_empty() else "새 성문"
	var desc: String = entry["desc"]
	var main_name: String = entry["names"][0]
	if gate_base_name(main_name) in used:
		desc += "
※ '%s'은(는) 이미 다른 성문에 걸려 있어 다른 이름을 추천합니다." % gate_base_name(main_name)
	return {
		"pos": pos,
		"default_name": def_name,
		"desc": desc,
		"suggestions": suggestions,
		"used": used,
	}

# ---------------------------------------------------------------- 일괄 건설 & Undo
func _apply_batch_build(tiles: Array[Vector2i], tool: String) -> void:
	if tiles.is_empty() or tool == "inspect":
		return

	# PORT-TRACE [지형 편집]: 평지/산/물/지표면 붓으로 지형을 편집한다.
	# 지형 편집 비용: 한 셀(타일)을 편집할 때마다 금화 1,000냥이 소모된다.
	if tool.begins_with("terra_"):
		var kind := tool.trim_prefix("terra_")
		var radius: int = panels.terrain_brush_radius if panels else 0
		var step: float = panels.terrain_step if panels else 1.0

		# 1) 실제로 지형 편집 영향(또는 브러시 타깃)을 받는 고유 셀 집합 계산
		var target_cells_map: Dictionary = {}
		for pt: Vector2i in tiles:
			for y in range(pt.y - radius, pt.y + radius + 1):
				for x in range(pt.x - radius, pt.x + radius + 1):
					if grid.in_bounds(x, y) and Vector2(x - pt.x, y - pt.y).length() <= float(radius) + 0.4:
						target_cells_map[Vector2i(x, y)] = true

		var cell_count: int = target_cells_map.size()
		if cell_count == 0:
			cell_count = tiles.size()

		const TERRAIN_CELL_COST: int = 1000
		var total_cost: int = cell_count * TERRAIN_CELL_COST

		if sim and sim.gold < total_cost:
			emit_signal("tool_message", "지형 편집 자금(금화 %d냥 필요, 보유: %d냥)이 부족하여 공사를 진행할 수 없습니다." % [total_cost, sim.gold])
			if audio: audio.play("error")
			return

		if sim:
			sim.gold -= total_cost

		var terra_pts: Array[Vector2i] = []
		if kind == "mountain" or kind == "mountain_down":
			terra_pts = grid.paint_mountain_stroke(tiles, radius, step if kind == "mountain" else -step)
		else:
			for pt in tiles:
				grid.paint_terrain(pt.x, pt.y, kind, radius, true)
				terra_pts.append(pt)
		grid.notify_batch_changed(terra_pts)
		if audio: audio.play("hammer")
		emit_signal("city_changed")
		var kind_msgs := {
			"mountain": "땅을 %s 높였습니다. (붓 %d칸, 누를 때마다 한 단씩, 금화 %d냥 소모)" % ["1단" if step >= 1.0 else "½단", radius * 2 + 1, total_cost],
			"mountain_down": "땅을 %s 낮췄습니다. (붓 %d칸, 누를 때마다 한 단씩, 금화 %d냥 소모)" % ["1단" if step >= 1.0 else "½단", radius * 2 + 1, total_cost],
			"water_shallow": "얕은 여울로 다시 그렸습니다. (%d셀, 금화 %d냥 소모)" % [cell_count, total_cost],
			"water": "물 붓으로 다시 그렸습니다. (%d셀, 금화 %d냥 소모)" % [cell_count, total_cost],
			"water_deep": "깊은 물로 다시 그렸습니다. (%d셀, 금화 %d냥 소모)" % [cell_count, total_cost],
			"plain": "평지로 다시 그렸습니다. (%d셀, 금화 %d냥 소모)" % [cell_count, total_cost],
		}
		emit_signal("tool_message", kind_msgs.get(kind, "지형을 다시 그렸습니다. (%d셀, 금화 %d냥 소모)" % [cell_count, total_cost]))
		return

	# PORT-TRACE [터 축조]: 행궁/동헌은 한 칸짜리 건물이 아니라 부지를 확보해 여러 턴에 걸쳐
	# 완공되는 "터"다. 드래그 대신 클릭한 지점을 부지 중심으로 삼는다.
	if GameGrid.SITE_BUILDINGS.has(tool):
		var origin: Vector2i = tiles[0]
		var res: Dictionary = grid.start_site_construction(tool, origin.x, origin.y, sim)
		emit_signal("tool_message", res.get("msg", ""))
		if res.get("success", false):
			if audio: audio.play("hammer")
			emit_signal("city_changed")
		else:
			if audio: audio.play("error")
		return

	var undo_record := {
		"tiles": [],
		"gold_spent": 0,
		"rice_spent": 0,
		"tool": tool
	}

	var built_count := 0
	var new_gates: Array[Vector2i] = []
	var last_err: String = ""

	for pt in tiles:
		if not grid.in_bounds(pt.x, pt.y):
			continue
		var t: Dictionary = grid.tile(pt.x, pt.y)

		if tool == "demolish":
			if t["building"] != "" or t["zone"] != "":
				undo_record["tiles"].append({
					"pos": pt,
					"building": t["building"],
					"zone": t["zone"],
					"gate_name": t.get("gate_name", ""),
					"is_bridge": t.get("is_bridge", false)
				})
				grid.apply_tool("demolish", pt.x, pt.y, true)
				built_count += 1
			continue

		var actual_tool := tool
		var existing_b: String = t["building"]
		var is_gate_trigger := false
		# 도로와 성곽이 교차하면 자동으로 웅장한 홍예성문(gate)으로 승격!
		if (tool == "wall" and existing_b == "road") or (tool in ["road", "stone_road"] and existing_b == "wall"):
			actual_tool = "gate"
			is_gate_trigger = true

		var err := grid.validate_tool(actual_tool, pt.x, pt.y)
		if err != "":
			last_err = err
			continue

		var cost: Dictionary = grid.get_tool_cost(actual_tool, pt.x, pt.y)
		if sim.gold < cost["gold"] or sim.rice < cost["rice"]:
			emit_signal("tool_message", "국고나 군량이 부족하여 일부 공사가 중단되었습니다.")
			if audio: audio.play("error")
			break

		sim.gold -= cost["gold"]
		sim.rice -= cost["rice"]
		undo_record["gold_spent"] += cost["gold"]
		undo_record["rice_spent"] += cost["rice"]

		undo_record["tiles"].append({
			"pos": pt,
			"building": t["building"],
			"zone": t["zone"],
			"surface": t.get("surface", "grass"),
			"road_type": t.get("road_type", "dirt"),
			"gate_name": t.get("gate_name", ""),
			"is_bridge": t.get("is_bridge", false)
		})

		grid.apply_tool(actual_tool, pt.x, pt.y, true)
		built_count += 1
		if is_gate_trigger or actual_tool == "gate":
			new_gates.append(pt)

	if built_count > 0:
		var modified_pts: Array[Vector2i] = []
		for item: Dictionary in undo_record["tiles"]:
			modified_pts.append(item["pos"])
		# PORT-TRACE [장마당·세시풍속]: 저잣거리 구획을 넓게 칠하면 약 10%를 장마당(공터)으로 남긴다
		if tool == "zone_com":
			if grid.allocate_cattle_market(modified_pts):
				emit_signal("tool_message", "팔달문 저잣거리에 3x3 수원 쇠전(우시장)이 들어섭니다. 삼남의 소가 모여듭니다!")
			if grid.allocate_salt_store(modified_pts):
				emit_signal("tool_message", "화서문 어염시장에 2x2 염전 소금 창고가 들어섭니다. 서해 천일염이 쌓입니다!")
			var made := grid.allocate_plazas(modified_pts)
			if made > 0:
				emit_signal("tool_message", "저잣거리 한가운데 장마당(공터) %d곳을 비워 두었습니다. 계절마다 놀이판이 열립니다." % made)
		elif tool == "zone_res":
			# PORT-TRACE [주택가 놀이마당]: 주거 구획 안 2x2 공터 — 아낙·처녀들이 널뛰기·그네뛰기를 한다
			var made_p := grid.allocate_plazas(modified_pts, "play")
			var made_k := grid.allocate_plazas(modified_pts, "kids")
			if made_p + made_k > 0:
				emit_signal("tool_message", "마을 안에 놀이마당 %d곳·아이들 골목 놀이터 %d곳을 비워 두었습니다." % [made_p, made_k])
		grid.notify_batch_changed(modified_pts)
		undo_stack.append(undo_record)
		if undo_stack.size() > 25:
			undo_stack.pop_front()

		sim.update_fortress(grid)
		sim.emit_signal("state_updated", sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)
		if audio:
			if tool == "demolish":
				audio.play("demolish")
			elif tool in ["wall", "gate"] or not new_gates.is_empty():
				audio.play("wall")
			else:
				audio.play("hammer")
		emit_signal("city_changed")
		const TOOL_KOREAN_NAMES: Dictionary = {
			"wall": "체성 성곽", "gate": "성문", "road": "도로", "stone_road": "박석길",
			"demolish": "철거", "patrol": "순라청", "firefighter": "멸화군",
			"reservoir": "저수지", "levee": "석축제방", "canal": "수로",
			"zone_res": "방리(주거구획)", "zone_com": "저잣거리(상업구획)",
			"zone_agr": "대유둔전(농지구획)", "zone_ind": "공방구획",
			"haenggung": "화성행궁", "gwana": "관아", "jongnu": "종루",
			"seojangdae": "서장대", "bongdon": "봉돈", "gongsimdon": "공심돈",
			"poru": "포루", "yeonmudae": "연무대", "dongjangdae": "연무대",
			"banghwasuryu": "방화수류정", "banghwasuryujeong": "방화수류정", "dongbuk_gakru": "방화수류정",
			"manseokgeo": "만석거", "chukmanje": "축만제", "hyanggyo": "수원향교",
			"seodang": "서당", "seowon": "서원", "guesthouse": "객사",
			"factory": "공방", "well": "우물", "yongyeon": "용연",
			"hwahongmun": "화홍문", "hwahong": "화홍문", "namsumun": "남수문", "namsu": "남수문",
			"maehwang_gyo": "매향교", "maehyang_gyo": "매향교",
			"jinhulso": "진휼소", "yeonghwajeong": "영화정",
		}
		var tool_kr: String = TOOL_KOREAN_NAMES.get(tool, InspectNarrativeGenerator.get_korean_name(tool, "화성 시설"))
		emit_signal("tool_message", "[%s] 공사 완료 (%d개 구역)" % [tool_kr, built_count])

		# 새로 생성된 성문들에 대해 사용자 명명 팝업 트리거
		for g_pos in new_gates:
			var g_info := get_gate_info_for_pos(g_pos)
			emit_signal("gate_naming_requested", g_pos, g_info["default_name"], g_info["desc"], g_info["suggestions"])
	elif last_err != "":
		emit_signal("tool_message", last_err)
		if audio: audio.play("error")

func undo() -> void:
	if undo_stack.is_empty():
		emit_signal("tool_message", "되돌릴 이전 작업이 없습니다.")
		return
	var rec: Dictionary = undo_stack.pop_back()
	var g_spent: int = rec.get("gold_spent", 0)
	var r_spent: int = rec.get("rice_spent", 0)
	sim.gold += g_spent
	sim.rice += r_spent

	for item in rec.get("tiles", []):
		var pt: Vector2i = item["pos"]
		if grid.in_bounds(pt.x, pt.y):
			var t: Dictionary = grid.tile(pt.x, pt.y)
			t["building"] = item["building"]
			t["zone"] = item["zone"]
			t["gate_name"] = item.get("gate_name", "")
			t["is_bridge"] = item.get("is_bridge", false)
			t.erase("wall_build")
			t.erase("wall_build_total")

	grid.recompute_infrastructure()
	sim.update_fortress(grid)
	sim.emit_signal("state_updated", sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)
	if audio:
		audio.play("coin")
	emit_signal("city_changed")
	emit_signal("tool_message", "이전 작업을 되돌렸습니다. (금 %d냥, 쌀 %d석 환불)" % [g_spent, r_spent])
	queue_redraw()
	# PORT-TRACE [되돌리기 지연 버그]: undo()가 grid 데이터는 바로 고치지만 GameGrid의
	# "grid_changed" 신호를 직접 내보내지 않아서, 텍스처 베이크(SubViewport)가 즉시 갱신되지
	# 않고 다음 턴 경계(체감상 수십 초 뒤)에야 우연히 다시 구워져 되돌린 결과가 뒤늦게 반영되는
	# 것처럼 보였다. 여기서 직접 신호를 내보내 다른 건설/철거처럼 즉시 화면에 반영한다.
	grid.emit_signal("grid_changed")


# ---------------------------------------------------------------- 렌더링
func _diamond(c: Vector2, s: float = 1.0) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -HH * s), c + Vector2(HW * s, 0), c + Vector2(0, HH * s), c + Vector2(-HW * s, 0)])

func _visible_bounds() -> Rect2i:
	if grid == null:
		return Rect2i(0, 0, 0, 0)
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Rect2i(0, 0, grid.size, grid.size)
	var vp_size := get_viewport_rect().size / cam.zoom
	var c_world := cam.position
	var p_min := c_world - vp_size * 0.5 - Vector2(128, 128)
	var p_max := c_world + vp_size * 0.5 + Vector2(128, 128)
	var corners := [
		world_to_cell(Vector2(p_min.x, p_min.y)),
		world_to_cell(Vector2(p_max.x, p_min.y)),
		world_to_cell(Vector2(p_min.x, p_max.y)),
		world_to_cell(Vector2(p_max.x, p_max.y))
	]
	var min_x := grid.size
	var max_x := 0
	var min_y := grid.size
	var max_y := 0
	for cn in corners:
		min_x = mini(min_x, cn.x)
		max_x = maxi(max_x, cn.x)
		min_y = mini(min_y, cn.y)
		max_y = maxi(max_y, cn.y)
	min_x = clampi(min_x - 4, 0, grid.size - 1)
	max_x = clampi(max_x + 4, 0, grid.size - 1)
	min_y = clampi(min_y - 4, 0, grid.size - 1)
	max_y = clampi(max_y + 4, 0, grid.size - 1)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

## PORT-TRACE [텍스처 베이크]: 예전엔 카메라가 보는 영역만 잘라 그렸다(뷰 컬링). 이제는
## grid_changed가 일어날 때만(=드물게) 호출되므로, 매번 지도 전체를 그려서
## SubViewport에 구워도 부담이 없다 — 오히려 그래야 카메라를 어디로 움직이든(패닝/줌)
## 다시 그릴 필요 없이 이미 구워진 텍스처를 그대로 보여줄 수 있다.
func _update_depth_sort() -> void:
	if grid == null:
		return
	# PORT-TRACE [렉 해결]: 4,096개 딕셔너리를 만들어 sort_custom 하던 것을 깊이 칸(반 칸 단위) 버킷 분류로
	# 바꿨다 — 정렬 없이 O(n). 깊이 키는 예전과 같다(x+y, 성문은 +2.5).
	var sz: int = grid.size
	var buckets: Array = []
	buckets.resize(sz * 4 + 8)
	for i in range(buckets.size()):
		buckets[i] = []
	for y: int in range(sz):
		for x: int in range(sz):
			var k2 := (x + y) * 2
			if grid.grid[y][x]["building"] == "gate":
				k2 += 5
			(buckets[k2] as Array).append(Vector2i(x, y))
	_depth_sorted_tiles.clear()
	_band_tiles.clear()
	for k2 in range(buckets.size()):
		var bk: Array = buckets[k2]
		if bk.is_empty():
			continue
		var bi := int(float(k2) * 0.5 / BAND_DEPTH)
		while _band_tiles.size() <= bi:
			_band_tiles.append([])
		for pt in bk:
			_depth_sorted_tiles.append(pt)
			(_band_tiles[bi] as Array).append(pt)
	_depth_order_dirty = false

## 띠 개수(마스터용) — Main이 띠 노드를 만들 때 쓴다. 문(+2.5)까지 감안한 최대 깊이 기준.
func band_count() -> int:
	return int((float(grid.size * 2) + 3.0) / BAND_DEPTH) + 1

## 타일 깊이 키(_update_depth_sort와 같은 규칙)로 띠 번호
func band_of(x: int, y: int) -> int:
	var d := float(x + y)
	if grid.in_bounds(x, y) and grid.grid[y][x]["building"] == "gate":
		d += 2.5
	return int(d / BAND_DEPTH)

## 마스터: 그리기 전에 정점 색·깊이 정렬(띠 목록)을 최신으로
func prepare_bands() -> void:
	if _vertex_colors_dirty or _vertex_colors.size() != grid.size + 1:
		_update_vertex_colors()
	if _depth_order_dirty or _depth_sorted_tiles.size() != grid.size * grid.size:
		_update_depth_sort()

## PORT-TRACE [문 통과 2중 그림]: 이 값이 있으면 그 성문 하나만 그린다(시민 레이어가 SubViewport에 구워 "앞 그림"으로 씀)
var gate_paint_tile := Vector2i(-1, -1)
## PORT-TRACE [성곽·군사시설 앞 그림]: 이 값이 있으면 그 칸의 성벽/포루/공심돈/방화수류정 하나만 그린다(시민 레이어가 구워 뒤에 선 사람 위에 덮음)
var struct_paint_tile := Vector2i(-1, -1)

func _draw() -> void:
	if grid == null or ref_layer == null:
		return
	if gate_paint_tile.x >= 0:
		_paint_gate_only(gate_paint_tile.x, gate_paint_tile.y)
		return
	if struct_paint_tile.x >= 0:
		_paint_struct_only(struct_paint_tile.x, struct_paint_tile.y)
		return
	if band_master != null:
		# 띠 노드: 마스터의 정점 색과 띠 목록을 빌려 자기 띠의 타일만 그린다
		_vertex_colors = band_master._vertex_colors
		if band_index >= 0 and band_index < band_master._band_tiles.size():
			var sz: int = grid.size
			for pt: Vector2i in band_master._band_tiles[band_index]:
				if band_seg < 0 or seg_of(pt.x, sz) == band_seg:
					_draw_tile(pt.x, pt.y)
		return
	if _vertex_colors_dirty or _vertex_colors.size() != grid.size + 1:
		_update_vertex_colors()
	if _depth_order_dirty or _depth_sorted_tiles.size() != grid.size * grid.size:
		_update_depth_sort()
	for pt: Vector2i in _depth_sorted_tiles:
		_draw_tile(pt.x, pt.y)

	# 도구 드래그/호버 프리뷰 및 만석거 관개 오버레이 고스트
	_draw_tool_previews()

## 도구 드래그 및 고스트 프리뷰 렌더링
func _draw_tool_previews() -> void:
	# 1. 만석거 배치 모드 활성화 시 (10배 관개 커버리지 고스트 프리뷰)
	if current_tool == "manseokgeo" and hover_cell.x >= 0 and grid.in_bounds(hover_cell.x, hover_cell.y):
		_draw_manseok_ghost_preview(hover_cell)

	# 2. 드래그 중인 타일들 프리뷰
	if not _drag_tiles.is_empty():
		var col := _get_preview_color(current_tool)
		for pt in _drag_tiles:
			if grid.in_bounds(pt.x, pt.y):
				var elev: float = grid.grid[pt.y][pt.x].get("elevation", 1.0)
				var c := cell_center(float(pt.x) + 0.5, float(pt.y) + 0.5, elev)
				FastDraw.poly(self, _diamond(c, 0.95), col)
				FastDraw.polyline(self, PackedVector2Array(_diamond(c, 0.95) + PackedVector2Array([_diamond(c, 0.95)[0]])), col.lightened(0.3), 1.2)
	elif hover_cell.x >= 0 and grid.in_bounds(hover_cell.x, hover_cell.y) and current_tool != "inspect":
		# 단일 타일 호버 프리뷰
		var elev2: float = grid.grid[hover_cell.y][hover_cell.x].get("elevation", 1.0)
		var c2 := cell_center(float(hover_cell.x) + 0.5, float(hover_cell.y) + 0.5, elev2)
		var col2 := _get_preview_color(current_tool)
		FastDraw.poly(self, _diamond(c2, 0.95), col2)
		FastDraw.polyline(self, PackedVector2Array(_diamond(c2, 0.95) + PackedVector2Array([_diamond(c2, 0.95)[0]])), col2.lightened(0.3), 1.2)

## 만석거 10배 관개 커버리지 고스트 프리뷰 (반경 30타일 유효 관개 범위 시각화)
func _draw_manseok_ghost_preview(cursor: Vector2i) -> void:
	var r: float = GameGrid.MANSEOK_RADIUS
	var c_elev: float = grid.grid[cursor.y][cursor.x].get("elevation", 1.0)
	var center_pos := cell_center(float(cursor.x) + 3.0, float(cursor.y) + 3.0, c_elev)

	# 6x6 만석거 본체 및 영화정 2x2 부지 가이드 다이아몬드
	var mg_col := Color(0.18, 0.65, 0.75, 0.55)
	for dy in range(6):
		for dx in range(6):
			var px: int = cursor.x + dx
			var py: int = cursor.y + dy
			if grid.in_bounds(px, py):
				var e: float = grid.grid[py][px].get("elevation", 1.0)
				var cp := cell_center(float(px) + 0.5, float(py) + 0.5, e)
				FastDraw.poly(self, _diamond(cp, 0.92), mg_col)

	# 10배 유효 관개 커버리지 오버레이 (반투명 청록빛)
	var cov_fill := Color(0.20, 0.75, 0.85, 0.18)
	var cov_line := Color(0.30, 0.88, 0.98, 0.75)
	var n_segs := 32
	var pts := PackedVector2Array()
	var rx: float = r * HW
	var ry: float = r * HH
	for i in range(n_segs):
		var th := float(i) * TAU / float(n_segs)
		pts.append(center_pos + Vector2(cos(th) * rx, sin(th) * ry))
	FastDraw.poly(self, pts, cov_fill)
	FastDraw.polyline(self, PackedVector2Array(pts + PackedVector2Array([pts[0]])), cov_line, 2.0)

## 도로 미연결 경고 아이콘 (!)
func _draw_road_disconnected_warning(c: Vector2) -> void:
	var wp := c + Vector2(0, -22.0)
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		var vp_size := get_viewport_rect().size / cam.zoom
		var view_rect := Rect2(cam.position - vp_size * 0.5 - Vector2(64, 64), vp_size + Vector2(128, 128))
		if not view_rect.has_point(wp):
			return
	var rw := 8.0
	var rh := 8.0
	var poly := PackedVector2Array([
		wp + Vector2(0, -rh), wp + Vector2(rw, 0),
		wp + Vector2(0, rh), wp + Vector2(-rw, 0)
	])
	FastDraw.poly(self, poly, Color(0.92, 0.22, 0.12, 0.92))
	FastDraw.polyline(self, PackedVector2Array([poly[0], poly[1], poly[2], poly[3], poly[0]]), Color("fef08a"), 1.2)
	draw_string(ThemeDB.fallback_font, wp + Vector2(-2.5, 4.0), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color("ffffff"))

func _get_preview_color(tool: String) -> Color:
	match tool:
		"road": return Color(0.85, 0.70, 0.40, 0.55) # 흙길 황토색
		"stone_road": return Color(0.75, 0.72, 0.68, 0.65) # 박석길 회백색
		"wall": return Color(0.85, 0.30, 0.20, 0.55) # 성곽 벽돌색
		"gate": return Color(0.95, 0.20, 0.20, 0.6)
		"zone_res": return Color(0.20, 0.60, 0.95, 0.5) # 주거 파란색
		"zone_com": return Color(0.95, 0.75, 0.20, 0.5) # 상업 노란색
		"zone_agr": return Color(0.40, 0.85, 0.30, 0.5) # 농업 초록색
		"zone_ind": return Color(0.78, 0.42, 0.22, 0.55) # 공방 가마 흙빛
		"demolish": return Color(0.95, 0.15, 0.15, 0.65) # 철거 붉은색
		"terra_grass": return Color(0.35, 0.80, 0.30, 0.55)
		"terra_dirt": return Color(0.70, 0.55, 0.35, 0.55)
		"terra_field": return Color(0.45, 0.32, 0.18, 0.55)
		"terra_rocky": return Color(0.60, 0.60, 0.60, 0.55)
		"terra_forest": return Color(0.18, 0.52, 0.22, 0.55)
		_: return Color(1.0, 0.90, 0.40, 0.55)

func _get_tile_base_ground_color(tx: int, ty: int) -> Color:
	var t: Dictionary = grid.grid[ty][tx]
	var terr: String = t.get("terrain", "plain")
	if terr == "water" and String(t.get("building", "")) == "yongyeon":
		terr = "outside" # PORT-TRACE [용연 연못가]: 둘레 들판과 같은 땅 위에 연못을 판다(예전엔 물빛 칸 + 덮개 잔디로 3x3 네모가 튀었다)
	var elev: float = t.get("elevation", 1.0)
	var surf: String = t.get("surface", "grass")
	var is_outside: bool = (terr == "outside")

	if terr == "water":
		if current_season == "겨울":
			var wt_w: float = clampf((0.60 - elev) / 1.6, 0.0, 1.0)
			return Color("7aa7bf").lerp(Color("41697d"), wt_w) # 얼어붙은 결빙 수면
		var wt: float = clampf((0.60 - elev) / 1.6, 0.0, 1.0)
		return Color("4a95bf").lerp(Color("1b486b"), wt)

	var base_col: Color
	match current_season:
		"봄":
			match surf:
				"dirt": base_col = Color("a1835e")
				"field": base_col = Color("5e442d")
				"rocky": base_col = Color("827d72")
				"forest": base_col = Color("316328")
				"grass", _: base_col = Color("8f8564") if is_outside else Color("63aa4c")
		"여름":
			match surf:
				"dirt": base_col = Color("9c7c55")
				"field": base_col = Color("594029")
				"rocky": base_col = Color("7a7569")
				"forest": base_col = Color("22521e")
				"grass", _: base_col = Color("877d5d") if is_outside else Color("4d9e38")
		"가을":
			match surf:
				"dirt": base_col = Color("a6845c")
				"field": base_col = Color("694b30")
				"rocky": base_col = Color("857f72")
				"forest": base_col = Color("5c3a1e")
				"grass", _: base_col = Color("968b64") if is_outside else Color("91994e")
		"겨울":
			match surf:
				"dirt": base_col = Color("b3a598")
				"field": base_col = Color("9c9489")
				"rocky": base_col = Color("a8a9a6")
				"forest": base_col = Color("788780")
				"grass", _: base_col = Color("dce5eb") if is_outside else Color("e4edf2")
		_:
			base_col = Color("5ea646")

	if elev < 0.95:
		var st: float = clampf((elev - 0.60) / 0.35, 0.0, 1.0)
		var shore_col: Color = Color("cbd5dc") if current_season == "겨울" else Color("b5aa8e")
		base_col = shore_col.lerp(base_col, st)
	elif elev > 2.20 and elev <= 4.0:
		var mt: float = clampf((elev - 2.20) / 1.80, 0.0, 1.0)
		var m_tint: Color = Color("d8e4eb") if current_season == "겨울" else (Color("59442b") if current_season == "가을" else Color("426934"))
		base_col = base_col.lerp(m_tint, mt * 0.7)
	elif elev > 4.0:
		var pt: float = clampf((elev - 4.0) / 2.50, 0.0, 1.0)
		var p_tint: Color = Color("eaf0f5") if current_season == "겨울" else Color("8a867c")
		base_col = base_col.lerp(p_tint, pt * 0.8)

	return base_col

func _update_vertex_colors() -> void:
	var sz: int = grid.size
	_vertex_colors.clear()
	_vertex_colors.resize(sz + 1)

	var tile_colors: Array = []
	tile_colors.resize(sz)
	for y: int in range(sz):
		var row: Array = []
		row.resize(sz)
		for x: int in range(sz):
			row[x] = _get_tile_base_ground_color(x, y)
		tile_colors[y] = row

	for vy: int in range(sz + 1):
		var vrow: Array = []
		vrow.resize(sz + 1)
		for vx: int in range(sz + 1):
			var r_sum: float = 0.0
			var g_sum: float = 0.0
			var b_sum: float = 0.0
			var count: int = 0

			for dy: int in [-1, 0]:
				var ty: int = vy + dy
				if ty < 0 or ty >= sz:
					continue
				for dx: int in [-1, 0]:
					var tx: int = vx + dx
					if tx < 0 or tx >= sz:
						continue
					var c: Color = tile_colors[ty][tx]
					r_sum += c.r
					g_sum += c.g
					b_sum += c.b
					count += 1

			if count > 0:
				vrow[vx] = Color(r_sum / float(count), g_sum / float(count), b_sum / float(count), 1.0)
			else:
				vrow[vx] = Color("5ea646")
		_vertex_colors[vy] = vrow

	_vertex_colors_dirty = false

## 풀이 난 곳 (사계절 초원 렌더러)
func _draw_grass_meadow(c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2, seed_val: int) -> void:
	var mode: int = (seed_val & 0xFF) % 10

	match current_season:
		"봄":
			if mode < 5:
				var gpos1: Vector2 = c + (p_e - p_w) * 0.15 + (p_s - p_n) * 0.1
				var gpos2: Vector2 = c - (p_e - p_w) * 0.20 - (p_s - p_n) * 0.15
				draw_line(gpos1, gpos1 + Vector2(0.0, -3.2), Color("3f7d2b", 0.75), 1.0)
				draw_line(gpos2, gpos2 + Vector2(1.0, -3.0), Color("589c3d", 0.75), 1.0)
			elif mode < 8:
				var spos: Vector2 = c + (p_e - p_w) * 0.12 * float((seed_val & 3) - 1.5)
				draw_line(spos, spos + Vector2(-1.5, -6.0), Color("3a7327"), 1.2)
				draw_line(spos, spos + Vector2(0.5, -8.0), Color("4e9435"), 1.3)
				draw_line(spos, spos + Vector2(2.5, -5.5), Color("44872e"), 1.2)
			else:
				var fpos: Vector2 = c + (p_e - p_w) * 0.15 + (p_s - p_n) * 0.1
				draw_line(fpos, fpos + Vector2(0, -3.0), Color("316323"), 1.0)
				var f_head: Vector2 = fpos + Vector2(0, -3.0)
				var ftype: int = (seed_val >> 4) % 3
				if ftype == 0:
					FastDraw.circle(self, f_head, 1.5, Color("ffffff")) # 하얀 냉이꽃
					FastDraw.circle(self, f_head, 0.6, Color("f7d046"))
				elif ftype == 1:
					FastDraw.circle(self, f_head, 1.6, Color("e64980")) # 분홍 진달래
				else:
					FastDraw.circle(self, f_head, 1.4, Color("fcc419")) # 노란 민들레

		"여름":
			if mode < 4:
				var gpos1: Vector2 = c + (p_e - p_w) * 0.15 + (p_s - p_n) * 0.1
				draw_line(gpos1, gpos1 + Vector2(0.0, -3.5), Color("2b5e1c", 0.8), 1.2)
			else:
				var spos: Vector2 = c + (p_e - p_w) * 0.12 * float((seed_val & 3) - 1.5)
				draw_line(spos, spos + Vector2(-1.5, -7.0), Color("255718"), 1.4)
				draw_line(spos, spos + Vector2(0.5, -9.5), Color("337321"), 1.5)
				draw_line(spos, spos + Vector2(2.5, -6.5), Color("2c631d"), 1.4)

		"가을":
			if mode < 5:
				var gpos1: Vector2 = c + (p_e - p_w) * 0.15 + (p_s - p_n) * 0.1
				var gpos2: Vector2 = c - (p_e - p_w) * 0.20 - (p_s - p_n) * 0.15
				draw_line(gpos1, gpos1 + Vector2(0.0, -3.2), Color("786c35", 0.7), 1.1)
				draw_line(gpos2, gpos2 + Vector2(1.0, -3.0), Color("8c7a3b", 0.7), 1.1)
			elif mode < 8:
				var spos: Vector2 = c + (p_e - p_w) * 0.12 * float((seed_val & 3) - 1.5)
				draw_line(spos, spos + Vector2(-1.0, -8.0), Color("877646"), 1.2)
				draw_line(spos, spos + Vector2(1.0, -10.0), Color("a3915c"), 1.3)
				draw_line(spos + Vector2(1.0, -10.0), spos + Vector2(3.0, -12.0), Color("d6cbb0"), 1.2) # 은빛 억새
			else:
				var fpos: Vector2 = c + (p_e - p_w) * 0.15 + (p_s - p_n) * 0.1
				draw_line(fpos, fpos + Vector2(0, -3.2), Color("5e5531"), 1.0)
				var f_head: Vector2 = fpos + Vector2(0, -3.2)
				FastDraw.circle(self, f_head, 1.5, Color("fafafa")) # 구절초
				FastDraw.circle(self, f_head, 0.7, Color("d99b26"))

		"겨울":
			if mode < 6:
				var spos1: Vector2 = c + (p_e - p_w) * 0.18 + (p_s - p_n) * 0.12
				FastDraw.circle(self, spos1, 1.8, Color("ffffff", 0.9)) # 소복한 눈뭉치
			else:
				var spos2: Vector2 = c - (p_e - p_w) * 0.15
				draw_line(spos2, spos2 + Vector2(0, -4.0), Color("8b9499", 0.8), 1.2)
				FastDraw.circle(self, spos2 + Vector2(0, -4.0), 1.4, Color("ffffff"))

## 흙바닥 렌더러
func _draw_dirt_ground(c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2, seed_val: int) -> void:
	var dot_col: Color = Color("543f28", 0.75) if current_season != "겨울" else Color("8a847d", 0.85)
	for i: int in range(3):
		var pr1: float = float((seed_val >> (i * 4)) & 15) / 15.0 - 0.5
		var pr2: float = float((seed_val >> (i * 4 + 2)) & 15) / 15.0 - 0.5
		var ppos: Vector2 = c + (p_e - p_w) * 0.32 * pr1 + (p_s - p_n) * 0.32 * pr2
		FastDraw.circle(self, ppos, 1.2, dot_col)

## 흙밭 및 논의 벼 렌더러 (사계절 모내기-생육-황금들판-추수)
func _draw_field_ground(c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2, _seed_val: int, has_crops: bool) -> void:
	var furrows: Array[float] = [-0.35, 0.0, 0.35]
	var furrow_col: Color = Color("3a2818", 0.85) if current_season != "겨울" else Color("6e655b", 0.85)

	for k: float in furrows:
		var off: Vector2 = (p_s - p_n) * 0.5 * k
		var span: float = 0.65 - absf(k) * 0.25
		var f_start: Vector2 = (p_w - c) * span + c + off
		var f_end: Vector2 = (p_e - c) * span + c + off
		draw_line(f_start, f_end, furrow_col, 1.6)

		if has_crops:
			match current_season:
				"봄":
					# 모내기철: 물이 찰랑이는 무논과 앙증맞은 어린 모
					draw_line(f_start, f_end, Color("45889e", 0.45), 2.0)
					for ci: int in range(3):
						var ct: float = float(ci + 1) / 4.0
						var cp: Vector2 = f_start.lerp(f_end, ct)
						draw_line(cp, cp + Vector2(-0.8, -2.8), Color("5ec437"), 1.4)
						draw_line(cp, cp + Vector2(0.8, -2.8), Color("69db3d"), 1.4)
				"여름":
					# 생육기: 짙고 무성하게 자라난 청록 벼포기
					for ci: int in range(3):
						var ct: float = float(ci + 1) / 4.0
						var cp: Vector2 = f_start.lerp(f_end, ct)
						draw_line(cp, cp + Vector2(-1.2, -6.0), Color("26701c"), 1.6)
						draw_line(cp, cp + Vector2(0.0, -7.5), Color("308c23"), 1.8)
						draw_line(cp, cp + Vector2(1.2, -5.8), Color("26701c"), 1.6)
				"가을":
					# 수확기: 탐스럽게 익어 고개 숙인 황금빛 벼이삭 (황금 들판)
					for ci: int in range(3):
						var ct: float = float(ci + 1) / 4.0
						var cp: Vector2 = f_start.lerp(f_end, ct)
						draw_line(cp, cp + Vector2(0.0, -5.5), Color("b08819"), 1.5)
						draw_line(cp + Vector2(0.0, -5.5), cp + Vector2(2.5, -4.2), Color("f0be24"), 2.2)
						FastDraw.circle(self, cp + Vector2(2.5, -4.2), 1.3, Color("e5a910"))
				"겨울":
					# 추수 후: 볏짚단(볏가리)과 눈 덮인 논바닥
					for ci: int in range(2):
						var ct: float = float(ci + 1) / 3.0
						var cp: Vector2 = f_start.lerp(f_end, ct)
						FastDraw.circle(self, cp + Vector2(0, -2.0), 2.2, Color("a89063"))
						FastDraw.circle(self, cp + Vector2(0, -3.4), 1.5, Color("ffffff"))

## 돌밭 렌더러
func _draw_rocky_ground(c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2, seed_val: int) -> void:
	var rpos: Vector2 = c + (p_e - p_w) * 0.12 + (p_s - p_n) * 0.08
	var rock_pts := PackedVector2Array([
		rpos + Vector2(-3.0, -1.5),
		rpos + Vector2(2.0, -2.5),
		rpos + Vector2(3.5, 1.5),
		rpos + Vector2(-2.0, 2.0)
	])
	var r_col: Color = Color("8f8a80") if current_season != "겨울" else Color("a8adaf")
	FastDraw.poly(self, rock_pts, r_col)
	draw_line(rpos + Vector2(-3.0, -1.5), rpos + Vector2(2.0, -2.5), Color("dedad2"), 1.2)
	if current_season == "겨울":
		FastDraw.circle(self, rpos + Vector2(0.0, -2.5), 1.6, Color("ffffff")) # 바위 위 소복한 눈
	for i: int in range(2):
		var jr: float = float((seed_val >> (i * 5 + 3)) & 15) / 15.0 - 0.5
		var jpos: Vector2 = c - (p_e - p_w) * 0.28 * jr - (p_s - p_n) * 0.22 * jr
		FastDraw.circle(self, jpos, 1.2, Color("423f3a", 0.8))

## ---------------------------------------------------- 4종 조선 수종 렌더러

## 1. 조선 소나무 (늘푸른 적송 - 구불구불한 붉은 줄기, 솔잎 덩어리, 겨울 설송)
func _draw_tree_pine(p: Vector2, season: String) -> void:
	FastDraw.circle(self, p + Vector2(1, 1), 3.5, Color(0.0, 0.0, 0.0, 0.25))
	draw_line(p, p + Vector2(-1, -7), Color("5e3019"), 2.6)
	draw_line(p + Vector2(-1, -7), p + Vector2(1, -15), Color("5e3019"), 2.0)

	var c_base: Color
	var c_high: Color
	match season:
		"봄":
			c_base = Color("1e4e26")
			c_high = Color("387a3e") # 연둣빛 송순
		"여름":
			c_base = Color("15381a")
			c_high = Color("23572b")
		"가을":
			c_base = Color("183b1d")
			c_high = Color("285c2f")
		"겨울":
			c_base = Color("193d20")
			c_high = Color("2d5e35")

	FastDraw.circle(self, p + Vector2(4, -10), 4.5, c_base)
	FastDraw.circle(self, p + Vector2(-5, -8), 4.0, c_base.darkened(0.1))
	FastDraw.circle(self, p + Vector2(1, -15), 5.5, c_high)

	# 겨울 소나무 설송(雪松) 눈 얹힘
	if season == "겨울":
		FastDraw.circle(self, p + Vector2(1, -17.5), 3.2, Color("ffffff"))
		FastDraw.circle(self, p + Vector2(4, -12.5), 2.2, Color("ffffff"))
		FastDraw.circle(self, p + Vector2(-5, -10.5), 2.0, Color("ffffff"))

## 2. 느티나무 / 참나무 (웅장한 활엽수 - 둥글고 풍성한 수관, 가을 갈색 단풍, 겨울 앙상한 가지+눈꽃)
func _draw_tree_zelkova(p: Vector2, season: String) -> void:
	FastDraw.circle(self, p + Vector2(1, 1), 4.0, Color(0.0, 0.0, 0.0, 0.25))
	draw_line(p, p + Vector2(0, -11), Color("422f22"), 2.6)

	if season == "겨울":
		# 겨울: 잎이 진 앙상한 가지와 눈꽃
		draw_line(p + Vector2(0, -11), p + Vector2(-5, -16), Color("4a3528"), 1.8)
		draw_line(p + Vector2(0, -11), p + Vector2(5, -16), Color("4a3528"), 1.8)
		draw_line(p + Vector2(0, -11), p + Vector2(0, -18), Color("4a3528"), 1.6)
		# 가지 위에 쌓인 눈
		FastDraw.circle(self, p + Vector2(0, -18), 1.8, Color("ffffff"))
		FastDraw.circle(self, p + Vector2(-5, -16), 1.6, Color("ffffff"))
		FastDraw.circle(self, p + Vector2(5, -16), 1.6, Color("ffffff"))
		return

	var fol_col: Color
	match season:
		"봄": fol_col = Color("5cb83b") # 라임 연두 새잎
		"여름": fol_col = Color("2e7a24") # 시원한 녹음
		"가을": fol_col = Color("b56926") # 그윽한 황갈색/주황 단풍
		_: fol_col = Color("3d822b")

	FastDraw.circle(self, p + Vector2(-3, -12), 4.8, fol_col.darkened(0.15))
	FastDraw.circle(self, p + Vector2(3, -13), 4.5, fol_col)
	FastDraw.circle(self, p + Vector2(0, -17), 5.5, fol_col.lightened(0.15))

## 3. 능수버들 (수양버들 - 아래로 길게 늘어뜨려진 아름다운 버들가지)
func _draw_tree_willow(p: Vector2, season: String) -> void:
	FastDraw.circle(self, p + Vector2(1, 1), 3.5, Color(0.0, 0.0, 0.0, 0.22))
	draw_line(p, p + Vector2(-2, -9), Color("453426"), 2.2)
	draw_line(p + Vector2(-2, -9), p + Vector2(0, -15), Color("453426"), 1.8)

	if season == "겨울":
		# 가느다란 은회색 가지와 상고대
		for ox: float in [-4.0, -1.0, 3.0]:
			draw_line(p + Vector2(ox * 0.5, -14), p + Vector2(ox, -6), Color("828d94"), 1.2)
			FastDraw.circle(self, p + Vector2(ox, -6), 1.0, Color("ffffff"))
		return

	var w_col: Color
	match season:
		"봄": w_col = Color("7ab83d") # 연노랑빛 버들가지
		"여름": w_col = Color("388c32") # 짙은 초록 버들
		"가을": w_col = Color("a69b2d") # 황록색 가을 버들
		_: w_col = Color("4ea63a")

	FastDraw.circle(self, p + Vector2(0, -15), 3.5, w_col)
	# 늘어진 버들가지 4가닥
	for ox: float in [-5.0, -2.0, 2.0, 5.0]:
		draw_line(p + Vector2(ox * 0.4, -14), p + Vector2(ox, -5), w_col, 1.4)

## 4. 계절목 (봄 화사한 벚꽃/살구꽃, 가을 붉은 홍단풍나무)
func _draw_tree_seasonal(p: Vector2, season: String, is_cherry: bool) -> void:
	FastDraw.circle(self, p + Vector2(1, 1), 3.5, Color(0.0, 0.0, 0.0, 0.24))
	draw_line(p, p + Vector2(0, -10), Color("3d2c20"), 2.2)

	match season:
		"봄":
			# 화사하게 만개한 연분홍 벚꽃 / 살구꽃 구름!
			var c_flower: Color = Color("f7b7cb") if is_cherry else Color("fcd288")
			FastDraw.circle(self, p + Vector2(-3, -11), 4.5, c_flower.darkened(0.1))
			FastDraw.circle(self, p + Vector2(3, -12), 4.2, c_flower)
			FastDraw.circle(self, p + Vector2(0, -16), 5.2, c_flower.lightened(0.2))
		"여름":
			# 싱그러운 녹색 잎
			FastDraw.circle(self, p + Vector2(-2, -11), 4.5, Color("307826"))
			FastDraw.circle(self, p + Vector2(2, -12), 4.2, Color("3a8f2f"))
			FastDraw.circle(self, p + Vector2(0, -16), 5.0, Color("48ab3c"))
		"가을":
			# 타오르는 붉은 단풍 (홍단풍)
			FastDraw.circle(self, p + Vector2(-2, -11), 4.5, Color("9e1b1b"))
			FastDraw.circle(self, p + Vector2(2, -12), 4.2, Color("c92a2a"))
			FastDraw.circle(self, p + Vector2(0, -16), 5.2, Color("e03131"))
		"겨울":
			# 앙상한 겨울 가지에 솜눈 덮인 설목
			draw_line(p + Vector2(0, -10), p + Vector2(-4, -15), Color("3d2c20"), 1.6)
			draw_line(p + Vector2(0, -10), p + Vector2(4, -15), Color("3d2c20"), 1.6)
			FastDraw.circle(self, p + Vector2(-4, -15), 2.0, Color("ffffff"))
			FastDraw.circle(self, p + Vector2(4, -15), 2.0, Color("ffffff"))
			FastDraw.circle(self, p + Vector2(0, -16), 2.4, Color("ffffff"))

## 나무가 우거진 곳 (4종 수종 조합 & 사계절 완전 동기화)
func _draw_forest_cluster(c: Vector2, _p_n: Vector2, _p_e: Vector2, _p_s: Vector2, _p_w: Vector2, seed_val: int) -> void:
	var tree_kind: int = (seed_val >> 2) % 4
	var t1: Vector2 = c + Vector2(-6.0, -2.0)
	var t2: Vector2 = c + Vector2(7.0, 3.0)

	# 1번 나무: 소나무 또는 느티나무
	if tree_kind in [0, 2]:
		_draw_tree_pine(t1, current_season)
	else:
		_draw_tree_zelkova(t1, current_season)

	# 2번 나무: 능수버들 또는 계절목(봄 벚꽃/가을 단풍)
	if tree_kind in [1, 2]:
		_draw_tree_willow(t2, current_season)
	else:
		var is_cherry: bool = (seed_val % 2 == 0)
		_draw_tree_seasonal(t2, current_season, is_cherry)

## [벚꽃나무 전용 2.5D 도트 렌더러]:
## 봄: 고목 가지에 활짝 만개한 3중 레이어 연분홍 벚꽃구름과 흩날리는 꽃비 픽셀
## 여름: 싱그러운 청록빛 녹음, 가을: 타오르는 붉은 단풍, 겨울: 눈꽃 덮인 설목
func _draw_cherry_blossom_tree(p: Vector2, season: String, scale_factor: float = 1.0, seed_val: int = 0) -> void:
	var s: float = scale_factor
	# 바닥 그림자
	FastDraw.circle(self, p + Vector2(1.0, 1.0) * s, 4.5 * s, Color(0.0, 0.0, 0.0, 0.22))
	# 나무 기둥 및 고목 가지 (약간 휜 운치 있는 곡선)
	var trunk_col: Color = Color("3d281c")
	draw_line(p, p + Vector2(-1.0, -9.0) * s, trunk_col, 2.4 * s)
	draw_line(p + Vector2(-1.0, -9.0) * s, p + Vector2(-5.0, -15.0) * s, trunk_col, 1.8 * s)
	draw_line(p + Vector2(-1.0, -9.0) * s, p + Vector2(4.0, -14.0) * s, trunk_col, 1.8 * s)
	draw_line(p + Vector2(-1.0, -9.0) * s, p + Vector2(0.0, -18.0) * s, trunk_col, 1.5 * s)

	match season:
		"봄":
			# 3중 볼륨감의 화사한 연분홍 벚꽃구름!
			var base_c: Color = Color("d97998")  # 하단 짙은 분홍 음영
			var mid_c: Color = Color("f7b7cb")   # 본체 만개한 연분홍
			var top_c: Color = Color("ffe8f0")   # 햇빛 받는 순백 핑크 하이라이트

			# 하단 음영 꽃송이
			FastDraw.circle(self, p + Vector2(-6.0, -15.0) * s, 5.0 * s, base_c)
			FastDraw.circle(self, p + Vector2(5.0, -14.0) * s, 4.8 * s, base_c)
			FastDraw.circle(self, p + Vector2(0.0, -13.0) * s, 4.5 * s, base_c)

			# 중간 볼륨 꽃송이
			FastDraw.circle(self, p + Vector2(-5.0, -18.0) * s, 6.0 * s, mid_c)
			FastDraw.circle(self, p + Vector2(4.0, -17.0) * s, 5.8 * s, mid_c)
			FastDraw.circle(self, p + Vector2(-1.0, -20.0) * s, 6.5 * s, mid_c)

			# 상단 하이라이트 꽃구름
			FastDraw.circle(self, p + Vector2(-2.0, -22.0) * s, 5.0 * s, top_c)
			FastDraw.circle(self, p + Vector2(2.0, -21.0) * s, 4.2 * s, top_c)

			# 바람에 흩날리는 벚꽃잎 픽셀 (꽃비)
			var petal_c: Color = Color(1.0, 0.72, 0.80, 0.95)
			var petal_light: Color = Color(1.0, 0.94, 0.96, 0.95)
			var r_seed: int = absi(seed_val)
			var offsets: Array[Vector2] = [
				Vector2(-10.0, -12.0), Vector2(9.0, -10.0),
				Vector2(-4.0, -6.0), Vector2(7.0, -4.0),
				Vector2(-8.0, 2.0), Vector2(11.0, 3.0)
			]
			for idx: int in range(offsets.size()):
				var off: Vector2 = offsets[idx] * s
				var col: Color = petal_c if (r_seed + idx) % 2 == 0 else petal_light
				FastDraw.circle(self, p + off, 1.2 * s, col)
		"여름":
			# 싱그러운 짙은 녹음
			FastDraw.circle(self, p + Vector2(-5.0, -15.0) * s, 5.5 * s, Color("2a6b22"))
			FastDraw.circle(self, p + Vector2(5.0, -14.0) * s, 5.2 * s, Color("2a6b22"))
			FastDraw.circle(self, p + Vector2(-2.0, -19.0) * s, 6.5 * s, Color("3b8c32"))
			FastDraw.circle(self, p + Vector2(2.0, -21.0) * s, 5.0 * s, Color("4da842"))
		"가을":
			# 타오르는 주홍/붉은 단풍
			FastDraw.circle(self, p + Vector2(-5.0, -15.0) * s, 5.5 * s, Color("961e1e"))
			FastDraw.circle(self, p + Vector2(5.0, -14.0) * s, 5.2 * s, Color("961e1e"))
			FastDraw.circle(self, p + Vector2(-2.0, -19.0) * s, 6.5 * s, Color("c23223"))
			FastDraw.circle(self, p + Vector2(2.0, -21.0) * s, 5.0 * s, Color("e36127"))
		"겨울":
			# 앙상한 겨울 가지에 솜눈 덮인 설목
			FastDraw.circle(self, p + Vector2(-5.0, -16.0) * s, 2.2 * s, Color("ffffff"))
			FastDraw.circle(self, p + Vector2(4.0, -15.0) * s, 2.0 * s, Color("ffffff"))
			FastDraw.circle(self, p + Vector2(-1.0, -19.0) * s, 2.5 * s, Color("ffffff"))
			FastDraw.circle(self, p + Vector2(2.0, -21.0) * s, 2.0 * s, Color("ffffff"))

## [벚꽃밭/벚꽃숲 전용 타일 렌더러]:
## 만석거 및 영화정 둘레에 펼쳐지는 봄 벚꽃 명소
func _draw_cherry_grove(c: Vector2, _p_n: Vector2, _p_e: Vector2, _p_s: Vector2, _p_w: Vector2, seed_val: int) -> void:
	# 1. 잔디 지표면 다이아몬드
	var grass_col: Color
	match current_season:
		"봄": grass_col = Color("78a04c")
		"여름": grass_col = Color("5e8e3a")
		"가을": grass_col = Color("8a844a")
		"겨울": grass_col = Color("c8cfb8")
		_: grass_col = Color("78a04c")
	FastDraw.poly(self, _diamond(c, 0.99), grass_col)

	# 2. 봄일 때: 바닥에 소복하게 쌓인 연분홍 벚꽃잎 융단 (낙화 도트)
	if current_season == "봄":
		var petal_floor_c: Color = Color(0.97, 0.72, 0.80, 0.85)
		var petal_floor_light: Color = Color(0.99, 0.89, 0.93, 0.90)
		for i: int in range(9):
			var r_angle: float = float(i) * 0.7 + float(seed_val % 13) * 0.2
			var r_dist: float = 3.0 + float((seed_val + i * 7) % 11)
			var dot_pos: Vector2 = c + Vector2(cos(r_angle) * r_dist, sin(r_angle) * r_dist * 0.5)
			var dot_col: Color = petal_floor_c if i % 2 == 0 else petal_floor_light
			FastDraw.circle(self, dot_pos, 1.1, dot_col)

	# 3. 벚꽃나무 1~2그루 배치 (좌표 약간 분산)
	var off_x1: float = -6.0 + float(seed_val % 5) - 2.0
	var off_y1: float = -2.0 + float((seed_val >> 2) % 5) - 2.0
	_draw_cherry_blossom_tree(c + Vector2(off_x1, off_y1), current_season, 1.1, seed_val)

	# 50% 확률로 아담한 벚꽃나무 1그루 추가 식재
	if (seed_val >> 4) % 2 == 0:
		var off_x2: float = 7.0 + float((seed_val >> 3) % 4) - 2.0
		var off_y2: float = 3.0 + float((seed_val >> 5) % 4) - 2.0
		_draw_cherry_blossom_tree(c + Vector2(off_x2, off_y2), current_season, 0.85, seed_val + 17)

func _draw_ground_surface(t: Dictionary, c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2, x: int, y: int) -> void:
	var surf: String = t.get("surface", "grass")
	var b: String = t.get("building", "")
	var zone: String = t.get("zone", "")
	var seed_val: int = (x * 73856093) ^ (y * 19349663)

	# 둔전(agr_1, agr_2)은 건물 레이어(PaddyFieldArt)에서 전용 2.5D 논두렁·논바닥을 일괄 렌더링
	if b in ["agr_1", "agr_2"]:
		return

	if zone == "agr" and b == "":
		_draw_farm_paddy_texture(c, false)
		return

	match surf:
		"grass":
			_draw_grass_meadow(c, p_n, p_e, p_s, p_w, seed_val)
		"dirt":
			_draw_dirt_ground(c, p_n, p_e, p_s, p_w, seed_val)
		"field":
			_draw_field_ground(c, p_n, p_e, p_s, p_w, seed_val, false)
		"rocky":
			_draw_rocky_ground(c, p_n, p_e, p_s, p_w, seed_val)
		"cherry", "cherry_blossom":
			if b == "" and zone == "":
				_draw_cherry_grove(c, p_n, p_e, p_s, p_w, seed_val)
			else:
				_draw_grass_meadow(c, p_n, p_e, p_s, p_w, seed_val)
		"forest":
			if b == "" and zone == "":
				_draw_forest_cluster(c, p_n, p_e, p_s, p_w, seed_val)
			else:
				_draw_grass_meadow(c, p_n, p_e, p_s, p_w, seed_val)
		_:
			_draw_grass_meadow(c, p_n, p_e, p_s, p_w, seed_val)

## 성곽 예정 라인 (성 안팎 경계 완만한 구릉 둔덕 및 축성 마커 렌더러)
func _draw_boundary_ridge(c: Vector2, _p_n: Vector2, _p_e: Vector2, _p_s: Vector2, _p_w: Vector2) -> void:
	var ridge_col: Color
	match current_season:
		"봄": ridge_col = Color(0.42, 0.54, 0.28, 0.50)
		"여름": ridge_col = Color(0.35, 0.50, 0.25, 0.50)
		"가을": ridge_col = Color(0.58, 0.48, 0.28, 0.50)
		"겨울": ridge_col = Color(0.80, 0.85, 0.88, 0.55)
		_: ridge_col = Color(0.42, 0.54, 0.28, 0.50)
	# 완만한 구릉 둔덕 다이아몬드
	var poly := _diamond(c, 0.82)
	FastDraw.poly(self, poly, ridge_col)
	# 성곽 예정 기준 말뚝 및 지대석 돌무지
	FastDraw.circle(self, c + Vector2(-3, -1), 1.5, Color("7a756c", 0.75))
	FastDraw.circle(self, c + Vector2(3, 1), 1.3, Color("68635c", 0.75))
	draw_line(c + Vector2(0, -4), c + Vector2(0, 2), Color("5c3a21", 0.85), 1.4)

## PORT-TRACE [건물 뒤 사람 가리기]: 사람은 지형·건물을 구운 그림 위의 시민 레이어에 그려져 건물 뒤에 있어도 지붕 위에 보였다.
## 그림 한 장(텍스처)으로 그리는 건물마다 {x0,y0,x1,y1(부지), rect(화면), bd 또는 lm} 목록을 만들어 주면, 시민 레이어가
## 건물 뒤(부지보다 앞 칸이 아닌 곳)에 선 사람 위에 그 건물 그림의 겹치는 부분만 다시 덮어 그린다.
func _group_rect(bc: Vector2, gw: int, gh: int) -> Rect2:
	if gw >= 3 and gh >= 3:
		return Rect2(bc.x - 96.0, bc.y + 48.0 - 160.0, 192.0, 160.0)
	elif (gw >= 3 and gh >= 2) or (gw >= 2 and gh >= 3):
		return Rect2(bc.x - 80.0, bc.y + 40.0 - 136.0, 160.0, 136.0)
	elif gw >= 2 and gh >= 2:
		return Rect2(bc.x - 64.0, bc.y + 32.0 - 112.0, 128.0, 112.0)
	elif gw >= 2 or gh >= 2:
		return Rect2(bc.x - 48.0, bc.y + 24.0 - 88.0, 96.0, 88.0)
	return Rect2(bc.x - 32.0, bc.y + 16.0 - 72.0, 64.0, 72.0)

func _tile_c(x: int, y: int) -> Vector2:
	var ce: Array = grid.grid[y][x].get("corner_elev", [1.0, 1.0, 1.0, 1.0])
	return (cell_center(x, y, ce[0]) + cell_center(x + 1, y, ce[1]) + cell_center(x + 1, y + 1, ce[2]) + cell_center(x, y + 1, ce[3])) * 0.25

func collect_occluders() -> Array:
	var out: Array = []
	if grid == null:
		return out
	for y in range(grid.size):
		for x in range(grid.size):
			var t: Dictionary = grid.grid[y][x]
			var b: String = t["building"]
			if b == "" or b == "road":
				continue
			if t.has("zone_build") and GameGrid.build_stage(grid.wall_build_fraction(t)) < 2:
				continue
			var mod: bool = bool(t.get("is_modernized", false))
			if b in ["ind_1", "ind_2", "res_1", "res_2", "res_3"]:
				var gk := "ws_group" if b.begins_with("ind") else "hgroup"
				if t.has(gk):
					var g: Dictionary = t[gk]
					var gw: int = int(g.get("w", 1))
					var gh: int = int(g.get("h", 1))
					var x0: int = int(g["x0"])
					var y0: int = int(g["y0"])
					if x != x0 + gw - 1 or y != y0 + gh - 1:
						continue
					var tid: String
					if b.begins_with("ind"):
						tid = str(grid.grid[y0][x0].get("ws_asset_id", grid.get_workshop_asset_id(x0, y0)))
					else:
						tid = grid.get_house_asset_id(x0, y0)
					var bc: Vector2 = cell_center(float(x0) + float(gw) * 0.5, float(y0) + float(gh) * 0.5, 1.0)
					out.append({"x0": x0, "y0": y0, "x1": x, "y1": y, "rect": _group_rect(bc, gw, gh), "bd": {"type_id": tid, "is_modernized": mod}})
				else:
					var tid2: String = grid.get_workshop_asset_id(x, y) if b.begins_with("ind") else grid.get_house_asset_id(x, y)
					var c := _tile_c(x, y)
					out.append({"x0": x, "y0": y, "x1": x, "y1": y, "rect": Rect2(c.x - 32.0, c.y + 16.0 - 72.0, 64.0, 72.0), "bd": {"type_id": tid2, "is_modernized": mod}})
			elif b == "gate":
				# PORT-TRACE [문 통과 2중 그림]: 성문은 코드 그림이라 시민 레이어가 따로 구운 "앞 그림"(홍예 구멍 뚫음)으로 덮는다
				var gi := gate_overlay_info(x, y)
				out.append({"x0": x, "y0": y, "x1": x, "y1": y, "rect": gi["rect"], "gate": gi})
			elif b == "wall" or b == "banghwasuryu":
				var sig_w := "%s|%.2f|%s" % [b, grid.wall_build_fraction(t), current_season]
				out.append({"x0": x, "y0": y, "x1": x, "y1": y, "rect": _struct_rect([Vector2i(x, y)], WALL_HEIGHT + (44.0 if b == "banghwasuryu" else (60.0 if _near_gate(x, y) else 8.0))), "paint": Vector2i(x, y), "psig": sig_w})
			elif (t.has("pr2") and b in ["poru", "poru_site"]) or (t.has("gs3") and b in ["gongsimdon", "gongsimdon_wall", "gongsimdon_site"]):
				var sa: Vector2i = t.get("site_anchor", Vector2i(x, y))
				if Vector2i(x, y) != _group_front_tile(sa):
					continue
				var stl: Array = grid.grid[sa.y][sa.x].get("site_tiles", [Vector2i(x, y)])
				var bx0 := 1 << 20
				var by0 := 1 << 20
				var bx1 := -1
				var by1 := -1
				for q4 in stl:
					var q5 := Vector2i(q4)
					bx0 = mini(bx0, q5.x)
					by0 = mini(by0, q5.y)
					bx1 = maxi(bx1, q5.x)
					by1 = maxi(by1, q5.y)
				var info_s: Dictionary = t["pr2"] if t.has("pr2") else t["gs3"]
				var sig_s := "%s|%.2f|%s|%s|%s" % [b, grid.wall_build_fraction(t), current_season, str(info_s.get("len", "")), str(info_s.get("c2", ""))]
				out.append({"x0": bx0, "y0": by0, "x1": bx1, "y1": by1, "rect": _struct_rect(stl, 118.0 if t.has("gs3") else 104.0, 26.0), "paint": Vector2i(x, y), "psig": sig_s})
			elif b == "com_1" or b == "com_2":
				var c2 := _tile_c(x, y)
				out.append({"x0": x, "y0": y, "x1": x, "y1": y, "rect": Rect2(c2.x - 32.0, c2.y + 16.0 - 72.0, 64.0, 72.0), "bd": {"type_id": grid.get_shop_asset_id(x, y), "is_modernized": mod}})
			else:
				var key := ""
				for k: String in LANDMARK_PNG.keys():
					if b == k or b == k + "_site":
						key = k
				if key == "":
					continue
				if not _landmark_png_state.has(key):
					var lp := "res://assets/sprites/buildings/lm_%s.png" % key
					_landmark_png_state[key] = ResourceLoader.exists(lp) or FileAccess.file_exists(ProjectSettings.globalize_path(lp))
				if not bool(_landmark_png_state[key]):
					continue
				var a: Vector2i = t.get("site_anchor", Vector2i(x, y))
				var st: Variant = grid.grid[a.y][a.x].get("site_tiles", null) if grid.in_bounds(a.x, a.y) else null
				if not (st is Array) or (st as Array).is_empty():
					continue
				var x0 := 1 << 20
				var y0 := 1 << 20
				var x1 := -1
				var y1 := -1
				for q: Vector2i in st:
					x0 = mini(x0, q.x)
					y0 = mini(y0, q.y)
					x1 = maxi(x1, q.x)
					y1 = maxi(y1, q.y)
				if x != x1 or y != y1:
					continue
				var size: Vector2i = LANDMARK_PNG[key][3]
				var w := float(x1 - x0 + 1)
				var h := float(y1 - y0 + 1)
				var bc2 := cell_center(float(x0) + w * 0.5, float(y0) + h * 0.5, 1.0)
				var o_lm := {"x0": x0, "y0": y0, "x1": x1, "y1": y1, "rect": Rect2(bc2.x - float(size.x) * 0.5, bc2.y + (w + h) * 8.0 - float(size.y), float(size.x), float(size.y)), "lm": key, "size": size}
				var ltex: Texture2D = SpriteCacheManager.get_or_create_texture("buildings", "lm_" + key, size)
				if ltex != null:
					var xf: Variant = fit_xf("lm_" + key, ltex, cell_center(float(x0), float(y1 + 1), 1.0), cell_center(float(x1 + 1), float(y0), 1.0), cell_center(float(x1 + 1), float(y1 + 1), 1.0))
					if xf != null:
						o_lm["xf"] = xf
						var bb := Rect2((xf as Transform2D) * Vector2.ZERO, Vector2.ZERO)
						for cq: Vector2 in [Vector2(size.x, 0), Vector2(0, size.y), Vector2(size)]:
							bb = bb.expand((xf as Transform2D) * cq)
						o_lm["rect"] = bb
				out.append(o_lm)
	return out

## 가림막으로 쓸 건물 그림(지금 계절판) — 구운 지도와 같은 텍스처
func occluder_texture(o: Dictionary) -> Texture2D:
	var sfx: String = SeasonColorFilter.get_current_season_suffix(current_season)
	if o.has("lm"):
		return SpriteCacheManager.get_seasonal_or_base_texture("buildings", "lm_" + String(o["lm"]), sfx, o["size"])
	var bd: Dictionary = o["bd"]
	var r: Rect2 = o["rect"]
	var category: String = "buildings_modern" if bool(bd.get("is_modernized", false)) else "buildings"
	return SpriteCacheManager.get_seasonal_or_base_texture(category, String(bd["type_id"]), sfx, Vector2i(int(r.size.x), int(r.size.y)),
		Callable(self, "_bake_procedural_building_to_image").bind(bd))

## 성문 칸 하나의 그림 기준: 중심 c, 성벽 방향 반벡터 a, 바깥 반벡터 f, 확대 배율 gs, 바깥 모서리 번호 o
func _gate_frame(x: int, y: int) -> Dictionary:
	var t: Dictionary = grid.grid[y][x]
	var ce: Array = t.get("corner_elev", [1.0, 1.0, 1.0, 1.0])
	var p_n := cell_center(x, y, ce[0])
	var p_e := cell_center(x + 1, y, ce[1])
	var p_s := cell_center(x + 1, y + 1, ce[2])
	var p_w := cell_center(x, y + 1, ce[3])
	var c := (p_n + p_e + p_s + p_w) * 0.25
	var g_name: String = t.get("gate_name", "")
	var o := _gate_outward_edge(x, y)
	var rel: Array[Vector2] = [p_n - c, p_e - c, p_s - c, p_w - c]
	var ea: Vector2 = rel[o]
	var eb: Vector2 = rel[(o + 1) % 4]
	return {"c": c, "a": (eb - ea) * 0.5, "f": (ea + eb) * 0.5, "gs": _gate_visual_scale(g_name), "o": o, "name": g_name, "frac": grid.wall_build_fraction(t)}

func _tile_corners(x: int, y: int) -> Array:
	var ce: Array = grid.grid[y][x].get("corner_elev", [1.0, 1.0, 1.0, 1.0])
	var p_n := cell_center(x, y, ce[0])
	var p_e := cell_center(x + 1, y, ce[1])
	var p_s := cell_center(x + 1, y + 1, ce[2])
	var p_w := cell_center(x, y + 1, ce[3])
	return [p_n, p_e, p_s, p_w, (p_n + p_e + p_s + p_w) * 0.25]

func _paint_struct_only(x: int, y: int) -> void:
	if not grid.in_bounds(x, y):
		return
	var t: Dictionary = grid.grid[y][x]
	var b := String(t["building"])
	var k := _tile_corners(x, y)
	if b == "wall":
		_draw_wall(x, y, k[0], k[1], k[2], k[3], k[4])
	elif t.has("pr2") and b in ["poru", "poru_site"]:
		var pa: Vector2i = t.get("site_anchor", Vector2i(x, y))
		for q in grid.grid[pa.y][pa.x].get("site_tiles", []):
			var pq := Vector2i(q)
			if grid.in_bounds(pq.x, pq.y) and String(grid.grid[pq.y][pq.x]["building"]) == "poru":
				var kp := _tile_corners(pq.x, pq.y)
				_draw_wall(pq.x, pq.y, kp[0], kp[1], kp[2], kp[3], kp[4])
		_draw_poru2(t["pr2"])
		_rewall_front_neighbors(pa)
	elif t.has("gs3") and b in ["gongsimdon", "gongsimdon_wall", "gongsimdon_site"]:
		var a: Vector2i = t.get("site_anchor", Vector2i(x, y))
		for q in grid.grid[a.y][a.x].get("site_tiles", []):
			var qq := Vector2i(q)
			if grid.in_bounds(qq.x, qq.y) and String(grid.grid[qq.y][qq.x]["building"]) in ["gongsimdon", "gongsimdon_wall"]:
				var kq := _tile_corners(qq.x, qq.y)
				_draw_wall(qq.x, qq.y, kq[0], kq[1], kq[2], kq[3], kq[4])
		_draw_gongsimdon3(t["gs3"])
		_rewall_front_neighbors(a)
	elif b == "banghwasuryu":
		_render_banghwasuryu(x, y, t, k[4], k[0], k[1], k[2], k[3])

## 시설 앞 그림이 덮을 화면 범위: 칸들의 바닥 꼭짓점을 감싸고 위로 up px
func _struct_rect(tiles: Array, up: float, side: float = 10.0) -> Rect2:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for q in tiles:
		var qq := Vector2i(q)
		if not grid.in_bounds(qq.x, qq.y):
			continue
		for p: Vector2 in (_tile_corners(qq.x, qq.y) as Array).slice(0, 4):
			mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
			mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
	return Rect2(mn - Vector2(side, up), (mx - mn) + Vector2(side * 2.0, up + 4.0))

func _paint_gate_only(x: int, y: int) -> void:
	if not grid.in_bounds(x, y) or grid.grid[y][x]["building"] != "gate":
		return
	var gf := _gate_frame(x, y)
	_gate_join = _gate_join_flags(x, y, int(gf["o"]))
	draw_set_transform(gf["c"], 0.0, Vector2(gf["gs"], gf["gs"]))
	_draw_gate(gf["a"], gf["f"], gf["name"], gf["frac"])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_gate_diag_links(x, y, int(gf["o"]))

## PORT-TRACE [성곽 새 단장]: MarketArt.box(평면 색 상자)에 PNG 그림 같은 짙은 외곽선을 더한 것 — 성곽 건물 전용
func _ft_box(o: Vector2, a: Vector2, f: Vector2, bu: float, bv: float, h0: float, h1: float, wall: Color, open_front: bool = false) -> PackedVector2Array:
	var top := MarketArt.box(self, o, a, f, bu, bv, h0, h1, wall, open_front)
	var g: Array[Vector2] = [o + a * -bu + f * -bv, o + a * bu + f * -bv, o + a * bu + f * bv, o + a * -bu + f * bv]
	var lo := Vector2(0, h0)
	var hi := Vector2(0, h1)
	for i in range(4):
		var q0: Vector2 = g[i]
		var q1: Vector2 = g[(i + 1) % 4]
		if (q0.y + q1.y) * 0.5 <= o.y:
			continue
		draw_line(q0 - lo, q1 - lo, FT_OUT, 0.8)
		draw_line(q0 - hi, q1 - hi, FT_OUT, 0.8)
		draw_line(q0 - lo, q0 - hi, FT_OUT, 0.8)
		draw_line(q1 - lo, q1 - hi, FT_OUT, 0.8)
	return top

## 돌(화강암 마름돌)·전돌 무늬 상자: 보이는 옆면만, 화면 뒤쪽 면부터. 윗면은 그리지 않는다(부르는 쪽에서)
func _ft_tex_box(o: Vector2, a: Vector2, f: Vector2, bu: float, bv: float, h0: float, h1: float, brick: bool) -> void:
	var g: Array[Vector2] = [o + a * -bu + f * -bv, o + a * bu + f * -bv, o + a * bu + f * bv, o + a * -bu + f * bv]
	var lo := Vector2(0, h0)
	var hi := Vector2(0, h1)
	var order: Array[int] = []
	for i in range(4):
		if (g[i].y + g[(i + 1) % 4].y) * 0.5 > o.y:
			order.append(i)
	order.sort_custom(func(i: int, j: int): return (g[i] + g[(i + 1) % 4]).y < (g[j] + g[(j + 1) % 4]).y)
	for i in order:
		var q0: Vector2 = g[i]
		var q1: Vector2 = g[(i + 1) % 4]
		var lit := ((q0 + q1) * 0.5).x >= o.x
		if brick:
			_ft_brick_face(q0 - lo, q1 - lo, q1 - hi, q0 - hi, lit)
		else:
			_draw_stone_face(q0 - lo, q1 - lo, q1 - hi, q0 - hi, FT_STONE if lit else FT_STONE_D, FT_MORTAR, maxi(2, int((h1 - h0) / 7.0)), maxi(2, int(q0.distance_to(q1) / 12.0)))

## 전돌(회색 벽돌) 면: 3px 단마다 줄눈, 엇갈린 세로 줄눈, 외곽선
func _ft_brick_face(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2, lit: bool) -> void:
	var base := FT_BRICK if lit else FT_BRICK_D
	FastDraw.poly(self, PackedVector2Array([p1, p2, p3, p4]), base)
	var h := p1.distance_to(p4)
	var rows := maxi(2, int(h / 3.0))
	var cols := maxi(2, int(p1.distance_to(p2) / 6.0))
	var joint := base.darkened(0.22)
	for r in range(rows):
		var v0 := float(r) / float(rows)
		var v1 := float(r + 1) / float(rows)
		if r > 0:
			draw_line(p1.lerp(p4, v0), p2.lerp(p3, v0), joint, 0.5)
		var off := 0.5 if r % 2 == 1 else 0.0
		for k in range(cols):
			var u := (float(k) + off) / float(cols)
			if u < 0.03:
				continue
			draw_line(p1.lerp(p2, u).lerp(p4.lerp(p3, u), v0), p1.lerp(p2, u).lerp(p4.lerp(p3, u), v1), joint, 0.5)
	FastDraw.polyline(self, PackedVector2Array([p1, p2, p3, p4, p1]), FT_OUT, 0.9)

## 홍예 구멍 다각형(문 그림 좌표, 확대 전) — _draw_gate_arch의 안쪽 어둠과 같은 모양
func _arch_poly(base: Vector2, along: Vector2, h_rect: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array([base - along, base + along])
	for k in range(11):
		var ang := PI * float(k) / 10.0
		pts.append(base + along * cos(ang) - Vector2(0, h_rect + r * sin(ang)))
	return pts

## 성문 "앞 그림" 정보: 화면 범위 rect, 뚫을 홍예 구멍(화면 좌표), 문 앞뒤 판정값
## 사람의 v(바깥 방향, 문 그림의 반칸×배율 단위)가 front_v보다 화면 앞쪽이면 그대로, 아니면 앞 그림을 덮는다.
func gate_overlay_info(x: int, y: int) -> Dictionary:
	var gf := _gate_frame(x, y)
	var c: Vector2 = gf["c"]
	var a: Vector2 = gf["a"]
	var f: Vector2 = gf["f"]
	var gs: float = gf["gs"]
	var sp := _gate_spec(String(gf["name"]))
	var V := GATE_V
	var has_ong: bool = sp["ong"]
	var rv: float = float(sp["rv"]) if has_ong else 0.0
	var ru: float = float(sp["ru"]) if has_ong else 0.0
	var cam_out: bool = f.y > 0.0
	var top_h := GATE_H1 + 46.0
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for uu: float in [-maxf(1.45, ru + 0.2), maxf(1.45, ru + 0.2)]:
		for vv: float in [-V - 0.3, V + rv + 0.3]:
			for hh: float in [0.0, top_h]:
				var q := c + (a * uu + f * vv - Vector2(0, hh)) * gs
				mn = Vector2(minf(mn.x, q.x), minf(mn.y, q.y))
				mx = Vector2(maxf(mx.x, q.x), maxf(mx.y, q.y))
	var rect := Rect2(mn - Vector2(6, 6), (mx - mn) + Vector2(12, 12))
	var holes: Array = []
	var face_v := V if cam_out else -V
	var body_hole := _arch_poly(f * face_v, a * GATE_ARCH_W, GATE_ARCH_H, GATE_ARCH_R)
	holes.append(body_hole)
	if cam_out and has_ong and bool(sp["ong_gate"]):
		var th_m := (float(sp["th0"]) + float(sp["th1"])) * 0.5
		var base := a * (ru * cos(th_m)) + f * (V + rv * sin(th_m))
		var tang := a * (-ru * sin(th_m)) + f * (rv * cos(th_m))
		holes.append(_arch_poly(base, tang.normalized() * GATE_ONG_ARCH_W, GATE_ONG_ARCH_H, GATE_ONG_ARCH_R))
	var world_holes: Array = []
	for hp: PackedVector2Array in holes:
		var wp := PackedVector2Array()
		for q2: Vector2 in hp:
			wp.append(c + q2 * gs)
		world_holes.append(wp)
	return {"rect": rect, "holes": world_holes, "gs": gs, "out": GATE_EDGE_DIRS[int(gf["o"])], "cam_out": cam_out,
		"front_v": (V + rv) if cam_out else -V, "reach": int(ceil(gs * (1.0 + rv))) + 1}

## [Step 3 최적화] 캐싱된 Texture2D 단일 드로우콜 렌더링 (계절별 텍스처/틴트 & 드롭 섀도우)
func _draw_building_cell(building_data: Dictionary, dest_rect: Rect2) -> void:
	var category: String = "buildings_modern" if building_data.get("is_modernized", false) else "buildings"
	var asset_id: String = building_data.get("type_id", "thatch_house")
	var season_sfx: String = SeasonColorFilter.get_current_season_suffix(current_season)
	var tex: Texture2D = SpriteCacheManager.get_seasonal_or_base_texture(
		category,
		asset_id,
		season_sfx,
		Vector2i(int(dest_rect.size.x), int(dest_rect.size.y)),
		Callable(self, "_bake_procedural_building_to_image").bind(building_data)
	)
	if tex != null:
		# 1. 알파 채널 기반 드롭 섀도우 패스 (우하단 3, 4px 오프셋)
		var shadow_col: Color = SeasonColorFilter.get_current_shadow_color(current_season)
		var shadow_rect := Rect2(dest_rect.position + Vector2(3.0, 4.0), dest_rect.size)
		draw_texture_rect(tex, shadow_rect, false, shadow_col)
		# 2. 본체 계절 색조(Tint) 렌더 패스
		var body_tint: Color = SeasonColorFilter.get_current_tile_tint(current_season)
		draw_texture_rect(tex, dest_rect, false, body_tint)
		# 3. 사계절 고유 디테일 오버레이 (겨울 눈 덮인 지붕·고드름·눈사람, 봄 개나리·철쭉·벚꽃, 여름 녹음, 가을 단풍·감나무)
		_draw_building_seasonal_overlay(building_data, dest_rect, current_season)

## [사계절 건축 고유 디테일 오버레이 — 렉 0%, 메모리 0MB 무부하 실시간 렌더러]
## - 겨울: 지붕 위 소복한 순백의 눈(Snow cap), 처마 끝 투명 고드름, 마당 눈 덮임과 눈사람
## - 봄: 마당 울타리 개나리(노란 꽃무리), 담장 밑 철쭉/진달래(화사한 진분홍), 흩날리는 벚꽃잎
## - 여름: 초록 잎이 무성한 싱그러운 마당 나무와 짙은 녹음, 시원한 마루/차양
## - 가을: 마당 나무의 불타는 붉은 단풍, 샛노란 은행잎, 주황빛 탐스러운 감나무, 지붕 위 낙엽
func _draw_building_seasonal_overlay(b_data: Dictionary, r: Rect2, season: String) -> void:
	if b_data.get("is_ruined", false):
		return

	var asset_id: String = b_data.get("type_id", "thatch_house")
	var seed_val: int = absi(asset_id.hash() ^ int(r.position.x * 13.0) ^ int(r.position.y * 29.0))
	var _is_thatch: bool = asset_id.begins_with("thatch") or b_data.get("building", "") == "res_1"
	var w: float = r.size.x
	var h: float = r.size.y
	var c_pos := Vector2(r.position.x + w * 0.5, r.position.y + h - 16.0)

	# 1. 마당 소품 앵커 (좌하단 또는 우하단)
	var yard_left := Vector2(c_pos.x - w * 0.35, c_pos.y + 4.0)
	var yard_right := Vector2(c_pos.x + w * 0.32, c_pos.y + 5.0)
	var eaves_p1 := Vector2(c_pos.x, c_pos.y - 12.0)

	match season:
		"겨울":
			# A. 지붕 눈은 건물 그림의 겨울판(<이름>_winter.png, tools/make_winter.py)에 그려져 있다

			# B. 마당 설경 및 아담한 눈사람
			if seed_val % 3 == 0:
				var sm_p: Vector2 = yard_right if (seed_val % 2 == 0) else yard_left
				FastDraw.poly(self, _diamond(sm_p, 0.35), Color("f1f5f9", 0.85))
				FastDraw.circle(self, sm_p - Vector2(0.0, 2.0), 2.6, Color("f8fafc"))
				FastDraw.circle(self, sm_p - Vector2(0.0, 5.8), 1.8, Color("ffffff"))
				FastDraw.circle(self, sm_p - Vector2(0.6, 6.2), 0.5, Color("1e293b"))
				FastDraw.circle(self, sm_p - Vector2(-0.6, 6.2), 0.5, Color("1e293b"))
				draw_line(sm_p - Vector2(0.0, 5.6), sm_p + Vector2(1.2, -5.6), Color("ea580c"), 0.8)
			else:
				var yp: Vector2 = yard_left if (seed_val % 2 == 0) else yard_right
				FastDraw.poly(self, _diamond(yp, 0.32), Color("f8fafc", 0.75))

		"봄":
			# A. 마당 울타리/처마 밑 활짝 핀 개나리 (샛노란 꽃무리)
			var forsythia_p: Vector2 = yard_left
			for fi in range(4):
				var fo_off: Vector2 = Vector2(float(fi * 2) - 3.0, float((fi * 3) % 4) - 2.0)
				draw_line(forsythia_p + fo_off, forsythia_p + fo_off - Vector2(0.0, 3.5), Color("65a30d"), 0.8)
				FastDraw.circle(self, forsythia_p + fo_off - Vector2(0.0, 3.5), 1.4, Color("facc15"))
				FastDraw.circle(self, forsythia_p + fo_off - Vector2(0.0, 4.0), 0.8, Color("fef08a"))

			# B. 담장 밑 진분홍 철쭉/진달래 꽃 무더기
			var azalea_p: Vector2 = yard_right
			for ai in range(3):
				var az_off: Vector2 = Vector2(float(ai * 3) - 3.0, float((ai * 2) % 3) - 1.0)
				FastDraw.circle(self, azalea_p + az_off - Vector2(0.0, 2.0), 1.8, Color("f43f5e"))
				FastDraw.circle(self, azalea_p + az_off - Vector2(0.0, 2.5), 1.1, Color("fb7185"))
				FastDraw.circle(self, azalea_p + az_off - Vector2(0.0, 0.5), 1.0, Color("15803d"))

			# C. 지붕과 마당에 흩날려 떨어진 연분홍 벚꽃잎들 (3~5개)
			var petal_col := Color(1.0, 0.74, 0.83, 0.92)
			FastDraw.circle(self, eaves_p1 + Vector2(-6.0, 1.0), 1.0, petal_col)
			FastDraw.circle(self, eaves_p1 + Vector2(7.0, -2.0), 0.9, petal_col)
			FastDraw.circle(self, c_pos + Vector2(2.0, 3.0), 1.0, petal_col)

		"여름":
			# A. 초록잎이 무성한 싱그러운 마당 나무와 짙은 녹음
			var tree_p: Vector2 = yard_right if (seed_val % 2 == 0) else yard_left
			FastDraw.poly(self, _diamond(tree_p + Vector2(1.0, 2.0), 0.35), Color(0.0, 0.0, 0.0, 0.22))
			draw_line(tree_p, tree_p - Vector2(0.0, 8.0), Color("451a03"), 1.8)
			FastDraw.circle(self, tree_p - Vector2(3.0, 9.0), 3.4, Color("14532d"))
			FastDraw.circle(self, tree_p + Vector2(3.0, 8.0), 3.2, Color("166534"))
			FastDraw.circle(self, tree_p - Vector2(0.0, 12.0), 4.2, Color("15803d"))
			FastDraw.circle(self, tree_p - Vector2(1.0, 13.0), 2.6, Color("22c55e"))

			# B. 마당 시원한 평상 그늘
			if seed_val % 2 == 1:
				var bench_p: Vector2 = yard_left
				draw_rect(Rect2(bench_p - Vector2(4.0, 2.0), Vector2(8.0, 4.0)), Color("b45309"))

		"가을":
			# A. 마당 나무의 불타는 붉은 단풍나무 또는 샛노란 은행나무
			var tree_p2: Vector2 = yard_right if (seed_val % 2 == 0) else yard_left
			FastDraw.poly(self, _diamond(tree_p2 + Vector2(1.0, 2.0), 0.32), Color(0.0, 0.0, 0.0, 0.20))
			draw_line(tree_p2, tree_p2 - Vector2(0.0, 8.0), Color("451a03"), 1.8)

			if seed_val % 2 == 0:
				FastDraw.circle(self, tree_p2 - Vector2(2.5, 9.0), 3.5, Color("991b1b"))
				FastDraw.circle(self, tree_p2 + Vector2(2.5, 8.0), 3.2, Color("b91c1c"))
				FastDraw.circle(self, tree_p2 - Vector2(0.0, 12.0), 4.2, Color("dc2626"))
				FastDraw.circle(self, tree_p2 - Vector2(0.5, 13.0), 2.5, Color("f87171"))
			else:
				FastDraw.circle(self, tree_p2 - Vector2(2.5, 9.0), 3.5, Color("a16207"))
				FastDraw.circle(self, tree_p2 + Vector2(2.5, 8.0), 3.2, Color("ca8a04"))
				FastDraw.circle(self, tree_p2 - Vector2(0.0, 12.0), 4.2, Color("eab308"))
				FastDraw.circle(self, tree_p2 - Vector2(0.5, 13.0), 2.5, Color("fef08a"))

			# B. 주황빛 탐스러운 감이 달린 감나무 (건물 3채 중 1채)
			if seed_val % 3 == 1:
				var persimmon_p: Vector2 = yard_left
				draw_line(persimmon_p, persimmon_p - Vector2(0.0, 6.0), Color("543018"), 1.4)
				for pk in range(3):
					var p_off := Vector2(float(pk * 3) - 3.0, -7.0 - float((pk * 2) % 3))
					FastDraw.circle(self, persimmon_p + p_off, 1.4, Color("ea580c"))
					FastDraw.circle(self, persimmon_p + p_off + Vector2(0.0, -1.0), 0.6, Color("365314"))

			# C. 지붕과 마당에 흩날려 떨어진 붉은/노란 낙엽 도트
			FastDraw.circle(self, eaves_p1 + Vector2(-5.0, 1.0), 1.1, Color("dc2626"))
			FastDraw.circle(self, eaves_p1 + Vector2(6.0, -1.5), 1.0, Color("eab308"))
			FastDraw.circle(self, c_pos + Vector2(-3.0, 4.0), 1.1, Color("d97706"))

func _bake_procedural_building_to_image(size: Vector2i, building_data: Dictionary) -> Image:
	var category: String = "buildings_modern" if building_data.get("is_modernized", false) else "buildings"
	var asset_id: String = building_data.get("type_id", "thatch_house")
	return SpriteCacheManager._create_standard_art_image(category, asset_id, size)

func _draw_farm_paddy_texture(c: Vector2, is_advanced: bool) -> void:
	var season_key: String = "spring"
	match current_season:
		"봄": season_key = "spring"
		"여름": season_key = "summer"
		"가을": season_key = "autumn"
		"겨울": season_key = "winter"
		_: season_key = "spring"
	var farm_tex_id: String = "farm_" + season_key
	var tex: Texture2D = SpriteCacheManager.get_or_create_texture("terrain", farm_tex_id, Vector2i(64, 32))
	if tex != null:
		var rect := Rect2(c.x - 32.0, c.y - 16.0, 64.0, 32.0)
		var tint: Color = Color(1.05, 1.05, 0.95, 1.0) if is_advanced else Color.WHITE
		draw_texture_rect(tex, rect, false, tint)

func _draw_terrain_edge_overlays(_x: int, _y: int, _c: Vector2, _t: Dictionary) -> void:
	# 길가·물가·성벽 주변 정사각형 스탬핑 아티팩트 완전 제거 (Zero Square Artifacts)
	return

func _bake_single_tile_png_layers(tile_pos: Vector2i, _season_suffix: String) -> void:
	if grid == null or not grid.in_bounds(tile_pos.x, tile_pos.y):
		return
	var t: Dictionary = grid.grid[tile_pos.y][tile_pos.x]
	var b: String = t.get("building", "")
	var zone: String = t.get("zone", "")

	# 둔전 타일 워밍업 캐싱
	if b in ["agr_1", "agr_2"] or (zone == "agr" and b == ""):
		var s_key: String = "spring"
		match current_season:
			"봄": s_key = "spring"
			"여름": s_key = "summer"
			"가을": s_key = "autumn"
			"겨울": s_key = "winter"
			_: s_key = "spring"
		var _farm_tex: Texture2D = SpriteCacheManager.get_or_create_texture("terrain", "farm_" + s_key, Vector2i(64, 32))

func bake_map_seasonal_async(_season_suffix: String = "") -> void:
	# [계절 전환 렉 0ms화] 전체 맵 비동기 재베이킹 전면 폐지
	# CanvasModulate 전역 색조 트윈으로 무부하 0ms 전환 보장
	map_baking_completed.emit()

func _draw_tile(x: int, y: int) -> void:
	var t: Dictionary = grid.grid[y][x]
	var ce: Array = t.get("corner_elev", [1.0, 1.0, 1.0, 1.0])
	var _elev: float = t["elevation"]

	var p_n := cell_center(x, y, ce[0])
	var p_e := cell_center(x + 1, y, ce[1])
	var p_s := cell_center(x + 1, y + 1, ce[2])
	var p_w := cell_center(x, y + 1, ce[3])

	# 인접 4개 타일의 지표면·고도 정점 컬러 캐시 읽기 (Gouraud 셰이딩 무경계 그라데이션)
	var slope: float = (ce[0] + ce[3]) - (ce[1] + ce[2])
	var light: float = clampf(1.0 + slope * 0.03, 0.72, 1.28)

	var col_n: Color = (_vertex_colors[y][x] as Color) * light
	var col_e: Color = (_vertex_colors[y][x + 1] as Color) * light
	var col_s: Color = (_vertex_colors[y + 1][x + 1] as Color) * light
	var col_w: Color = (_vertex_colors[y + 1][x] as Color) * light

	FastDraw.poly_colors(self, PackedVector2Array([p_n, p_e, p_s, p_w]), PackedColorArray([col_n, col_e, col_s, col_w]))

	var c := (p_n + p_e + p_s + p_w) * 0.25
	var zone: String = t["zone"]
	var b: String = t["building"]
	var is_bridge: bool = t.get("is_bridge", false)
	var on_water: bool = (t["terrain"] == "water" and b != "yongyeon") or is_bridge

	# 조선 정조 수원화성 자연 지표면 질감 렌더링 (물 위에는 렌더링 생략)
	if not on_water:
		_draw_ground_surface(t, c, p_n, p_e, p_s, p_w, x, y)
		# 성곽 예정 라인(성내/외 경계) 구릉 지형 시각화 (성벽/성문 미완공 시)
		if b != "wall" and b != "gate" and grid.is_wall_planned_boundary(x, y):
			_draw_boundary_ridge(c, p_n, p_e, p_s, p_w)

	if zone != "" and b == "" and t.has("plaza"):
		_draw_plaza_tile(x, y, t, c, p_n, p_e, p_s, p_w)
	elif zone != "" and b == "":
		var zone_cols := {
			"res": Color(0.25, 0.55, 0.95, 0.4), "com": Color(0.95, 0.75, 0.2, 0.4),
			"agr": Color(0.4, 0.85, 0.3, 0.4), "ind": Color(0.78, 0.42, 0.22, 0.42), # 공방: 가마 흙빛
		}
		var zc: Color = zone_cols.get(zone, Color(0.4, 0.85, 0.3, 0.4))
		FastDraw.poly(self, _diamond(c, 0.96), zc)
		FastDraw.polyline(self, PackedVector2Array(_diamond(c, 0.96) + PackedVector2Array([c + Vector2(0, -HH * 0.96)])), zc.lightened(0.3), 1.5)
		if zone == "agr" and t.get("irrigated", false):
			_draw_paddy_water(p_n, p_e, p_s, p_w)

	# PORT-TRACE [매향교]: 다리목 천변 매화나무(빈 땅일 때만)
	if b == "" and zone == "" and t.get("plum", false):
		_draw_plum_tree(c, x, y)
	_redraw_wall_leaks(x, y)

	# PORT-TRACE [건설 기간 확대]: 서장대·봉돈 등 한 칸 건물은 공사 중엔 완성 그림 대신 공사 현장을
	# (성곽·성문·화홍문은 각자 단계별로 쌓아 올리는 그림이 있으므로 제외)
	# PORT-TRACE [단계별 건설]: 민가·저잣거리·공방(zone_build)까지 넓히고, 공정률에 따라
	# 터 다지기 → 골조 → 마무리(완성 모습 + 비계) 세 단계로 그린다.
	var is_wall_top: bool = b in ["bongdon", "bongdon_site", "poru", "poru_site", "gongsimdon", "gongsimdon_site", "gongsimdon_wall", "seojangdae", "seojangdae_site", "yeonmudae", "yeonmudae_site", "banghwasuryu"] or bool(t.get("sj_wall", false)) or bool(t.get("bh_wall", false))
	var staged: bool = (t.has("wall_build") and not (b in ["wall", "gate"])) or t.has("zone_build")
	var b_stage: int = GameGrid.build_stage(grid.wall_build_fraction(t)) if staged else 3
	if staged and b_stage < 2:
		if is_wall_top:
			_draw_wall(x, y, p_n, p_e, p_s, p_w, c)
			_draw_finish_scaffold(c - Vector2(0, WALL_HEIGHT), p_n - Vector2(0, WALL_HEIGHT), p_e - Vector2(0, WALL_HEIGHT), p_s - Vector2(0, WALL_HEIGHT), p_w - Vector2(0, WALL_HEIGHT))
		else:
			_draw_build_stage(c, p_n, p_e, p_s, p_w, grid.wall_build_fraction(t), true)
	elif b == "road":
		_draw_road(x, y, p_n, p_e, p_s, p_w, c, on_water)
		if t.get("culvert", false):
			_draw_culvert(x, y, p_n, p_e, p_s, p_w, c)
	elif b == "canal":
		_draw_canal(x, y, p_n, p_e, p_s, p_w, c)
	elif b == "levee":
		_draw_levee(x, y, p_n, p_e, p_s, p_w, c)
		if grid.is_laundry_spot(x, y):
			_draw_laundry_spot(x, y, c, p_n, p_e, p_w)
	elif b == "ind_1" or b == "ind_2":
		if t.has("ws_group"):
			var wg: Dictionary = t["ws_group"]
			var gw: int = int(wg.get("w", 1))
			var gh: int = int(wg.get("h", 1))
			var x0: int = int(wg["x0"])
			var y0: int = int(wg["y0"])
			if x == x0 + gw - 1 and y == y0 + gh - 1:
				var t0: Dictionary = grid.grid[y0][x0]
				var ws_id: String = str(t0.get("ws_asset_id", grid.get_workshop_asset_id(x0, y0)))
				var bc: Vector2 = cell_center(float(x0) + float(gw) * 0.5, float(y0) + float(gh) * 0.5, 1.0)
				var rect: Rect2
				if gw >= 3 and gh >= 3:
					rect = Rect2(bc.x - 96.0, bc.y + 48.0 - 160.0, 192.0, 160.0)
				elif (gw >= 3 and gh >= 2) or (gw >= 2 and gh >= 3):
					rect = Rect2(bc.x - 80.0, bc.y + 40.0 - 136.0, 160.0, 136.0)
				elif gw >= 2 and gh >= 2:
					rect = Rect2(bc.x - 64.0, bc.y + 32.0 - 112.0, 128.0, 112.0)
				elif gw >= 2 or gh >= 2:
					rect = Rect2(bc.x - 48.0, bc.y + 24.0 - 88.0, 96.0, 88.0)
				else:
					rect = Rect2(bc.x - 32.0, bc.y + 16.0 - 72.0, 64.0, 72.0)
				var b_data: Dictionary = {
					"type_id": ws_id,
					"building": b,
					"is_modernized": bool(t.get("is_modernized", false)),
					"is_ruined": bool(t.get("is_ruined", false))
				}
				_draw_building_cell(b_data, rect)
		else:
			var ws_id: String = grid.get_workshop_asset_id(x, y)
			var b_data: Dictionary = {
				"type_id": ws_id,
				"building": b,
				"is_modernized": bool(t.get("is_modernized", false)),
				"is_ruined": bool(t.get("is_ruined", false))
			}
			_draw_building_cell(b_data, Rect2(c.x - 32.0, c.y + 16.0 - 72.0, 64.0, 72.0))
	elif b == "com_1" or b == "com_2":
		var s_id: String = grid.get_shop_asset_id(x, y)
		var b_data: Dictionary = {
			"type_id": s_id,
			"building": b,
			"is_modernized": bool(t.get("is_modernized", false)),
			"is_ruined": bool(t.get("is_ruined", false)),
			"trade": _trade_of(x, y, t)
		}
		_draw_building_cell(b_data, Rect2(c.x - 32.0, c.y + 16.0 - 72.0, 64.0, 72.0))
	elif b == "res_1" or b == "res_2" or b == "res_3":
		if t.has("hgroup"):
			var hg: Dictionary = t["hgroup"]
			var gw: int = int(hg.get("w", 1))
			var gh: int = int(hg.get("h", 1))
			var x0: int = int(hg["x0"])
			var y0: int = int(hg["y0"])
			if x == x0 + gw - 1 and y == y0 + gh - 1:
				var h_id: String = grid.get_house_asset_id(x0, y0)
				var bc: Vector2 = cell_center(float(x0) + float(gw) * 0.5, float(y0) + float(gh) * 0.5, 1.0)
				var rect: Rect2
				if gw >= 3 and gh >= 3:
					rect = Rect2(bc.x - 96.0, bc.y + 48.0 - 160.0, 192.0, 160.0)
				elif (gw >= 3 and gh >= 2) or (gw >= 2 and gh >= 3):
					rect = Rect2(bc.x - 80.0, bc.y + 40.0 - 136.0, 160.0, 136.0)
				elif gw >= 2 and gh >= 2:
					rect = Rect2(bc.x - 64.0, bc.y + 32.0 - 112.0, 128.0, 112.0)
				elif gw >= 2 or gh >= 2:
					rect = Rect2(bc.x - 48.0, bc.y + 24.0 - 88.0, 96.0, 88.0)
				else:
					rect = Rect2(bc.x - 32.0, bc.y + 16.0 - 72.0, 64.0, 72.0)
				var b_data: Dictionary = {
					"type_id": h_id,
					"building": b,
					"is_modernized": bool(t.get("is_modernized", false)),
					"is_ruined": bool(t.get("is_ruined", false))
				}
				_draw_building_cell(b_data, rect)
		else:
			var h_id: String = grid.get_house_asset_id(x, y)
			var b_data: Dictionary = {
				"type_id": h_id,
				"building": b,
				"is_modernized": bool(t.get("is_modernized", false)),
				"is_ruined": bool(t.get("is_ruined", false))
			}
			_draw_building_cell(b_data, Rect2(c.x - 32.0, c.y + 16.0 - 72.0, 64.0, 72.0))
		if t.get("cheonju", false):
			var cpos := c + (p_s - c) * 0.55
			draw_line(cpos + Vector2(0, -2), cpos + Vector2(0, -12), Color("f4f0e4"), 1.4)
			draw_line(cpos + Vector2(-3, -9), cpos + Vector2(3, -9), Color("f4f0e4"), 1.4)
			FastDraw.circle(self, cpos + Vector2(6, -6), 1.8, Color("f5c060"))
	elif b == "well":
		var b_data: Dictionary = {
			"type_id": "well",
			"building": b,
			"is_modernized": bool(t.get("is_modernized", false))
		}
		_draw_building_cell(b_data, Rect2(c.x - 32.0, c.y + 16.0 - 72.0, 64.0, 72.0))
	elif b == "wall":
		if t.get("is_namsu", false):
			_draw_namsumun(x, y, t)
		elif on_water or t.get("is_hwahong", false):
			_draw_hwahongmun(x, y, t)
		else:
			_draw_wall(x, y, p_n, p_e, p_s, p_w, c)
	elif b == "gate":
		# PORT-TRACE [4대문 웅장화]: 사용자가 "화성의 성문은 그 자체로 문화재적 가치가 있으니
		# 3~4칸 정도를 차지하는 웅장한 건물로 표현되어야 한다"고 요청. 실제로 그리드를 다칸
		# 부지로 바꾸면 성곽 연결성·교지 판정·기존 세이브 호환에 큰 위험이 따르므로, 대신
		# office처럼 draw_set_transform으로 확대해 화면상 3~4칸 폭에 걸치는 웅장함을 낸다
		# (그리드 데이터상으로는 여전히 1칸이라 도로/성곽 연결·수문장 로직은 그대로 안전하다).
		# PORT-TRACE [4대문 재설계]: 성 밖 모서리(o)의 실제 꼭짓점에서 두 축을 뽑아 넘긴다 —
		# a=성벽 방향 반벡터, f=중심→성 밖 모서리 중점. 꼭짓점은 회전이 반영돼 있어 4방향 모두 맞다.
		var g_name: String = t.get("gate_name", "")
		var o := _gate_outward_edge(x, y)
		var rel: Array[Vector2] = [p_n - c, p_e - c, p_s - c, p_w - c]
		var ea: Vector2 = rel[o]
		var eb: Vector2 = rel[(o + 1) % 4]
		var g_scale := _gate_visual_scale(g_name)
		_gate_join = _gate_join_flags(x, y, o)
		draw_set_transform(c, 0.0, Vector2(g_scale, g_scale))
		_draw_gate((eb - ea) * 0.5, (ea + eb) * 0.5, g_name, grid.wall_build_fraction(t))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_gate_diag_links(x, y, o)
	elif b == "seojangdae" or b == "seojangdae_site":
		# PORT-TRACE [서장대 2x2]: 네 칸 모두 바위 산정, 누각·서노대는 앞쪽 칸 (1,1)에서 한 번에
		var sj_a: Vector2i = t.get("site_anchor", Vector2i(x, y))
		var sj_lift := 0.0
		for sjq: Vector2i in [sj_a, sj_a + Vector2i(1, 0), sj_a + Vector2i(0, 1), sj_a + Vector2i(1, 1)]:
			if grid.in_bounds(sjq.x, sjq.y) and bool(grid.grid[sjq.y][sjq.x].get("sj_wall", false)):
				sj_lift = WALL_HEIGHT # 성벽 위에 세웠으면 성벽 높이만큼 받침을 올린다
		if not bool(t.get("sj_wall", false)):
			_draw_rock_outcrop(c, x, y)
		# PORT-TRACE [서장대 성곽 이음]: 바깥 성벽이 닿는 칸은 성벽을 칸 가운데(누각 기단 밑)까지 끌어들여 끊기지 않게
		if _wall_touches(x, y):
			_draw_wall(x, y, p_n, p_e, p_s, p_w, c)
		if Vector2i(x, y) - sj_a == Vector2i(1, 1) or Vector2i(x, y) == _group_front_tile(sj_a):
			_draw_seojangdae2(p_n, p_e, p_w, sj_lift)
	elif b == "bongdon" or b == "bongdon_site":
		if not t.has("bd4"):
			var base_el: float = float(t.get("elevation", 1.0))
			t["bd4"] = {"start": Vector2i(x, y), "axis": Vector2i(1, 0), "out": Vector2i(0, 1), "elevation": base_el}
		# PORT-TRACE [봉돈 4x1]: 성벽 4칸 + 바깥 4칸 묶음을 묶음의 가장 앞 칸에서 한 번에
		if Vector2i(x, y) == _group_front_tile(t.get("site_anchor", Vector2i(x, y))):
			_draw_bongdon4(t["bd4"])
			_rewall_front_neighbors(t.get("site_anchor", Vector2i(x, y)))
	elif t.has("pr2") and (b == "poru" or b == "poru_site"):
		# PORT-TRACE [포루 성곽 이음]: 성벽 줄에 앉은 포루 칸에도 성벽을 그려 이웃 성곽과 같은 높이로 이어지고, 포루 몸통은 그 위에.
		if b == "poru":
			_draw_wall(x, y, p_n, p_e, p_s, p_w, c)
		# PORT-TRACE [포루 5종 2x2]: 묶음의 가장 앞 칸에서 한 번에
		if Vector2i(x, y) == _group_front_tile(t.get("site_anchor", Vector2i(x, y))):
			_draw_poru2(t["pr2"])
			_rewall_front_neighbors(t.get("site_anchor", Vector2i(x, y)))
	elif t.has("gs3") and (b == "gongsimdon" or b == "gongsimdon_wall" or b == "gongsimdon_site"):
		# PORT-TRACE [공심돈 성곽 이음]: 공심돈이 앉은 성벽 두 칸에도 성벽(체성·여장·곡선 이음)을 그려 이웃 성곽과 끊김 없이 이어지고,
		# 둥근 몸통은 그 위에 걸쳐 선다. 묶음의 가장 앞 칸에서 몸통을 한 번에.
		if b == "gongsimdon" or b == "gongsimdon_wall":
			_draw_wall(x, y, p_n, p_e, p_s, p_w, c)
		if Vector2i(x, y) == _group_front_tile(t.get("site_anchor", Vector2i(x, y))):
			_draw_gongsimdon3(t["gs3"])
			_rewall_front_neighbors(t.get("site_anchor", Vector2i(x, y)))
	elif b == "yeonmudae_range":
		_draw_ym_range(x, y, c)
	elif b == "yeonmudae" or b == "yeonmudae_site":
		# PORT-TRACE [연무대 5x5]: 칸마다 훈련장 흙바닥, 기단·대루·영롱장은 가장 앞 칸에서 한 번에
		FastDraw.poly(self, _diamond(c, 0.99), Color("c8b48a"))
		if not t.has("ym5"):
			t["ym5"] = {"center": t.get("site_anchor", Vector2i(x, y)), "wall_dir": Vector2i(0, -1)}
		if Vector2i(x, y) == _group_front_tile(t.get("site_anchor", Vector2i(x, y))):
			_draw_yeonmudae5(t["ym5"])
	elif b == "hyanggyo" or b == "hyanggyo_site":
		# PORT-TRACE [수원향교 4x4]: 칸마다 마당, 전각들은 부지의 가장 앞 칸에서 한 번에
		var hk_a: Vector2i = t.get("site_anchor", Vector2i(x, y)) if b == "hyanggyo_site" else Vector2i(x, y)
		if not _landmark_png("hyanggyo", x, y, hk_a, p_n, p_e, p_s, p_w):
			_draw_hyanggyo_part(Vector2i(x, y), hk_a, c)
	elif b == "yeonghwajeong" or b == "yeonghwajeong_site":
		var yg_a: Vector2i = t.get("site_anchor", Vector2i(x, y)) if b == "yeonghwajeong_site" else Vector2i(x, y)
		_draw_yeonghwajeong_part(Vector2i(x, y) - yg_a, yg_a, c, p_n, p_e, p_w)
	elif b == "gongsimdon":
		# [PORT-FIX] 구형 에셋 제거 및 신규 규격(gs3) 자동 Fallback 매핑
		if not t.has("gs3"):
			var base_el: float = float(t.get("elevation", 1.0))
			t["gs3"] = {"center": Vector2i(x, y), "axis": Vector2i(1, 0), "out": Vector2i(0, 1), "type": "seobuk", "elevation": base_el}
		_draw_gongsimdon3(t["gs3"])
	elif b == "poru":
		# [PORT-FIX] 구형 에셋 제거 및 신규 규격(pr2) 자동 Fallback 매핑
		if not t.has("pr2"):
			var base_el: float = float(t.get("elevation", 1.0))
			t["pr2"] = {"start": Vector2i(x, y), "axis": Vector2i(1, 0), "out": Vector2i(0, 1), "type": "dong", "elevation": base_el}
		_draw_poru2(t["pr2"])
	elif b == "yeonmudae":
		var b_data: Dictionary = {"type_id": "yeonmudae", "building": b}
		_draw_building_cell(b_data, Rect2(c.x - 32.0, c.y - 48.0, 64.0, 64.0))
	elif b == "banghwasuryu":
		_render_banghwasuryu(x, y, t, c, p_n, p_e, p_s, p_w)
	elif b == "yongyeon":
		_render_yongyeon(x, y, t, c, p_n, p_e, p_s, p_w)
	elif b == "haenggung":
		# PORT-TRACE [행궁 7x7 재설계]: 앵커 타일(rel=0,0)은 중심축 박석길을 그린다. 나머지
		# 48칸은 아래 "haenggung_site" 분기에서 각자 자기 몫(신풍루/봉수당/행각 등)을 그린다.
		if not _landmark_png("haenggung", x, y, Vector2i(x, y), p_n, p_e, p_s, p_w):
			_draw_haenggung_part(Vector2i.ZERO, c, p_n, p_e, p_s, p_w)
	elif b == "haenggung_site":
		var anchor: Vector2i = t.get("site_anchor", Vector2i(x, y))
		if not _landmark_png("haenggung", x, y, anchor, p_n, p_e, p_s, p_w):
			_draw_haenggung_part(Vector2i(x, y) - anchor, c, p_n, p_e, p_s, p_w)
	elif b == "manseokgeo":
		# PORT-TRACE [만석거 6x6]: haenggung과 동일한 "앵커+_site 확장 타일" 패턴.
		_draw_manseokgeo_part(Vector2i.ZERO, c, p_n, p_e, p_s, p_w, Vector2i(x, y), Vector2i(x, y))
	elif b == "manseokgeo_site":
		var mg_anchor: Vector2i = t.get("site_anchor", Vector2i(x, y))
		_draw_manseokgeo_part(Vector2i(x, y) - mg_anchor, c, p_n, p_e, p_s, p_w, Vector2i(x, y), mg_anchor)
	elif b == "chukmanje":
		# 축만제(서호) 6x6: 서호 중심 타원형 인공섬(당주) 특화 랜드마크 렌더러
		_draw_chukmanje_part(Vector2i.ZERO, c, p_n, p_e, p_s, p_w, Vector2i(x, y), Vector2i(x, y))
	elif b == "chukmanje_site":
		var cm_anchor: Vector2i = t.get("site_anchor", Vector2i(x, y))
		_draw_chukmanje_part(Vector2i(x, y) - cm_anchor, c, p_n, p_e, p_s, p_w, Vector2i(x, y), cm_anchor)
	elif b == "jinhulso":
		# 진휼소 2x2: 관영 구휼 복지 종합 단지 (본청/양곡고/취사솥/배급줄)
		if not _landmark_png("jinhulso", x, y, Vector2i(x, y), p_n, p_e, p_s, p_w):
			_draw_jinhulso_part(Vector2i.ZERO, c, p_n, p_e, p_s, p_w)
	elif b == "jinhulso_site":
		var jh_anchor: Vector2i = t.get("site_anchor", Vector2i(x, y))
		if not _landmark_png("jinhulso", x, y, jh_anchor, p_n, p_e, p_s, p_w):
			_draw_jinhulso_part(Vector2i(x, y) - jh_anchor, c, p_n, p_e, p_s, p_w)
	elif b == "jongnu" or b == "jongnu_site":
		var jn_anchor: Vector2i = t.get("site_anchor", Vector2i(x, y)) if b == "jongnu_site" else Vector2i(x, y)
		if not _landmark_png("jongnu", x, y, jn_anchor, p_n, p_e, p_s, p_w):
			_draw_jongnu_part(Vector2i(x, y) - jn_anchor, c, p_n, p_e, p_w)
	elif b == "gwana":
		if not _landmark_png("gwana", x, y, Vector2i(x, y), p_n, p_e, p_s, p_w):
			_draw_gwana_part(x, y, Vector2i(x, y), c, p_n, p_e, p_s, p_w)
	elif b == "gwana_site":
		var gw_anchor: Vector2i = t.get("site_anchor", Vector2i(x, y))
		if not _landmark_png("gwana", x, y, gw_anchor, p_n, p_e, p_s, p_w):
			_draw_gwana_part(x, y, gw_anchor, c, p_n, p_e, p_s, p_w)
	elif b == "patrol" or b == "firefighter":
		# PORT-TRACE [순라청·멸화군 새 그림]: assets/sprites/buildings/patrol_station.png·firefighter_station.png가 있으면 그것으로
		var sid := "patrol_station" if b == "patrol" else "firefighter_station"
		if _bld_png_exists(sid):
			_draw_building_cell({"type_id": sid, "building": b}, Rect2(c.x - 32.0, c.y + 16.0 - 72.0, 64.0, 72.0))
		else:
			var pf := _front_frame(x, y, c, p_n, p_e, p_s, p_w)
			MarketArt.draw_public(self, c, pf[0], pf[1], b, _variant_of(x, y, t))
	elif b in ["ruin", "burned_wasteland"]:
		_draw_burned_wasteland(c, p_n, p_e, p_s, p_w)
	elif b in ["agr_1", "agr_2"]:
		_draw_farm_paddy_texture(c, b == "agr_2")
	elif b == "reservoir":
		_draw_reservoir_pond(x, y, c, p_n, p_e, p_s, p_w)
	elif BUILDING_SLOTS.has(b):
		_draw_building_slot(c, BUILDING_SLOTS[b])

	if staged and b_stage == 2:
		_draw_finish_scaffold(c, p_n, p_e, p_s, p_w)

	if t["under_construction"]:
		_draw_site_under_construction(x, y, c, p_n, p_e, p_s, p_w)

	# 도로 미연결 경고 아이콘 (!)
	if (b != "" or zone != "") and not grid.is_road_connected(x, y) and not b in ["wall", "gate", "gongsimdon", "gongsimdon_wall", "poru", "bongdon", "hwahong", "namsu", "banghwasuryu", "levee", "road", "stone_road", "yeonmudae_range"]:
		_draw_road_disconnected_warning(c)

## 전소된 황무지(burned_wasteland) 및 폐허(ruin) 렌더러: 잿더미 대지, 불탄 기둥 잔해, 피어오르는 연기
func _draw_burned_wasteland(c: Vector2, _p_n: Vector2, _p_e: Vector2, _p_s: Vector2, _p_w: Vector2) -> void:
	# 1. 잿더미 검은 다이아몬드 기단
	FastDraw.poly(self, _diamond(c, 0.96), Color("211f1e"))
	FastDraw.polyline(self, PackedVector2Array(_diamond(c, 0.96) + PackedVector2Array([_diamond(c, 0.96)[0]])), Color("121110"), 1.2)
	
	# 2. 타다 남은 숯과 잿더미 파편
	for off: Vector2 in [Vector2(-8, -2), Vector2(7, 3), Vector2(-3, 5), Vector2(5, -4), Vector2(-1, 1)]:
		FastDraw.circle(self, c + off, 1.6, Color("141312"))
	
	# 3. 비뚤어진 그을린 목재 기둥/서까래 잔해
	draw_line(c + Vector2(-6, 2), c + Vector2(-9, -9), Color("1c1714"), 2.4)
	draw_line(c + Vector2(4, 3), c + Vector2(8, -8), Color("2b1d16"), 2.2)
	draw_line(c + Vector2(-2, 1), c + Vector2(1, -12), Color("181412"), 2.0)
	draw_line(c + Vector2(-8, -4), c + Vector2(6, -2), Color("3a2416"), 1.5) # 쓰러진 대들보
	
	# 4. 연기 피어오름 (오프스크린 컬링 적용)
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		var vp_size := get_viewport_rect().size / cam.zoom
		var view_rect := Rect2(cam.position - vp_size * 0.5 - Vector2(64, 64), vp_size + Vector2(128, 128))
		if not view_rect.has_point(c):
			return
	for i: int in range(3):
		var phase: float = fmod(_anim * 1.2 + float(i) * 0.7, 2.0)
		var smoke_y: float = -6.0 - phase * 10.0
		var smoke_x: float = sin(phase * 3.0 + float(i)) * 3.5
		var r: float = 2.0 + phase * 2.2
		var alpha: float = clampf(1.0 - phase / 2.0, 0.0, 0.5)
		FastDraw.circle(self, c + Vector2(smoke_x, smoke_y), r, Color(0.42, 0.42, 0.45, alpha))

## 가뭄 구역 대유둔전 논밭 마른 흙 및 시든 작물 렌더링
func _draw_drought_crack(c: Vector2, _p_n: Vector2, _p_e: Vector2, _p_s: Vector2, _p_w: Vector2) -> void:
	FastDraw.poly(self, _diamond(c, 0.94), Color(0.68, 0.54, 0.36, 0.65))
	draw_line(c + Vector2(-8, -2), c + Vector2(6, 4), Color(0.42, 0.30, 0.18, 0.8), 1.2)
	draw_line(c + Vector2(-2, -5), c + Vector2(2, 6), Color(0.42, 0.30, 0.18, 0.8), 1.2)
	for ox: float in [-6.0, 0.0, 6.0]:
		draw_line(c + Vector2(ox, 2), c + Vector2(ox - 1.5, -4), Color(0.72, 0.60, 0.25), 1.4)
		draw_line(c + Vector2(ox, 2), c + Vector2(ox + 1.5, -3), Color(0.68, 0.55, 0.22), 1.2)

## ─────────────────────────────────────────────── 수로·암거·논물·공방
## PORT-TRACE [둔전·저수지·수로]: 자동 수로(GameGrid.rebuild_canals)가 판 "canal" 타일을 돌로
## 쌓은 도랑으로 그린다. 저수지·다른 수로·암거·논 쪽으로만 물길이 이어지고, 각 물길은 공유
## 모서리 중점까지 가서 이웃 물길과 정확히 맞물린다(성곽 팔과 같은 원리, 회전·경사 대응).
func _waterway_arms(x: int, y: int) -> Array[bool]:
	var out: Array[bool] = []
	for d: Vector2i in GameGrid.CANAL_DIRS:
		var nx := x + d.x
		var ny := y + d.y
		out.append(grid.in_bounds(nx, ny) and grid.is_waterway_tile(grid.grid[ny][nx]))
	return out

## 모서리 i(0=N,1=E,2=S,3=W) 방향으로 중심에서 모서리 중점까지 폭 k의 띠
func _edge_arm(c: Vector2, corners: Array[Vector2], i: int, k: float) -> PackedVector2Array:
	var a: Vector2 = corners[i]
	var b2: Vector2 = corners[(i + 1) % 4]
	var m := (a + b2) * 0.5
	var w := (b2 - a) * k
	return PackedVector2Array([c - w, m - w, m + w, c + w])

func _draw_canal(x: int, y: int, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2, c: Vector2) -> void:
	var corners: Array[Vector2] = [p_n, p_e, p_s, p_w]
	var arms := _waterway_arms(x, y)
	var rim := Color("8f8674")
	var water := Color("3f7fa3")
	# 1) 돌 호안(둑돌) — 넓은 띠
	FastDraw.poly(self, PackedVector2Array([c + (p_n - c) * 0.26, c + (p_e - c) * 0.26, c + (p_s - c) * 0.26, c + (p_w - c) * 0.26]), rim)
	for i in range(4):
		if arms[i]:
			FastDraw.poly(self, _edge_arm(c, corners, i, 0.22), rim)
	# 2) 물 — 좁은 띠
	FastDraw.poly(self, PackedVector2Array([c + (p_n - c) * 0.16, c + (p_e - c) * 0.16, c + (p_s - c) * 0.16, c + (p_w - c) * 0.16]), water)
	for i in range(4):
		if arms[i]:
			FastDraw.poly(self, _edge_arm(c, corners, i, 0.13), water)
			# 물비늘 한 줄
			var a: Vector2 = corners[i]
			var b2: Vector2 = corners[(i + 1) % 4]
			draw_line(c, (a + b2) * 0.5, Color(0.72, 0.88, 1.0, 0.6), 1.0)

## 도로를 가로지르는 수로 — 도로 아래 암거(돌 덮개)로 표시
func _draw_culvert(x: int, y: int, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2, c: Vector2) -> void:
	var corners: Array[Vector2] = [p_n, p_e, p_s, p_w]
	var arms := _waterway_arms(x, y)
	for i in range(4):
		if arms[i]:
			FastDraw.poly(self, _edge_arm(c, corners, i, 0.13), Color("3f7fa3"))
	var slab := PackedVector2Array([c + (p_n - c) * 0.3, c + (p_e - c) * 0.3, c + (p_s - c) * 0.3, c + (p_w - c) * 0.3])
	FastDraw.poly(self, slab, Color("a39c90"))
	FastDraw.polyline(self, slab + PackedVector2Array([slab[0]]), Color("6a655c"), 1.0)

## PORT-TRACE [제방 연속화]: 석축 제방. 예전엔 타일마다 같은 아틀라스 그림 한 장(멸화군과
## 공용 슬롯)이라 이어 쌓아도 낱개 더미로 보였다. 성곽과 같은 "허브+팔" 방식으로 이웃 제방과
## 공유 모서리에서 정확히 맞물리게 그려, 강줄기를 따라 한 줄로 이어진 둑이 된다. 성곽보다
## 낮고 넓게, 옆면은 막돌 쌓기(호안석), 윗면은 잔디 덮인 둑길.
## PORT-TRACE [제방 빨래터]: 둑 물쪽 비탈에 내려가는 돌계단 + 물가에 넓적한 빨래돌 서너 개와 빨랫감
func _draw_laundry_spot(x: int, y: int, c: Vector2, p_n: Vector2, p_e: Vector2, p_w: Vector2) -> void:
	var wd := grid.water_dir_at(x, y)
	var gx := (p_e - p_n) * 0.5
	var gy := (p_w - p_n) * 0.5
	var w := (gx * float(wd.x) + gy * float(wd.y))
	if w.length() < 0.01:
		return
	w = w.normalized() * gx.length()
	var side := (gy * float(wd.x) - gx * float(wd.y)).normalized() * gx.length()
	# 돌계단(둑 마루에서 물가로)
	for k in range(3):
		var t := 0.3 + 0.12 * float(k)
		var sc := c + w * t - Vector2(0, 8.0 - k * 2.6)
		draw_line(sc - side * 0.18, sc + side * 0.18, Color("8f897d"), 2.2)
		draw_line(sc - side * 0.18 + Vector2(0, 1.2), sc + side * 0.18 + Vector2(0, 1.2), Color("5a554d"), 0.8)
	# 물가 빨래돌 + 널어 둔 흰 빨랫감
	for i in range(3):
		var bp := c + w * 0.78 + side * (-0.45 + 0.45 * float(i))
		FastDraw.poly(self, PackedVector2Array([bp + Vector2(-4, 0), bp + Vector2(-1, -2), bp + Vector2(4, -1), bp + Vector2(2, 1.5)]), Color("a8a296"))
		draw_line(bp + Vector2(-4, 0), bp + Vector2(2, 1.5), Color("6e685e"), 0.8)
	var cloth := c + w * 0.62 + side * 0.5
	FastDraw.poly(self, PackedVector2Array([cloth, cloth + side * 0.25, cloth + side * 0.25 + w * 0.12, cloth + w * 0.12]), Color("f2f0e8"))

func _draw_levee(x: int, y: int, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2, c: Vector2) -> void:
	var corners: Array[Vector2] = [p_n, p_e, p_s, p_w]
	var conn: Array[bool] = []
	for d: Vector2i in GameGrid.CANAL_DIRS:
		var nx := x + d.x
		var ny := y + d.y
		conn.append(grid.in_bounds(nx, ny) and grid.grid[ny][nx]["building"] == "levee")
	var k := 0.32   # 둑 폭(모서리 대비)
	var lh := 8.0   # 둑 높이
	var col_light := Color("a39d90")
	var col_dark := Color("7d776c")
	var col_top := Color("7fa35a")
	var col_mortar := Color("5a554d")
	var no_merlon: Array[bool] = [false, false, false, false]
	var boxes: Array = []
	var hub := PackedVector2Array()
	for p: Vector2 in corners:
		hub.append(c + (p - c) * 2.0 * k)
	var hub_open: Array[bool] = [not conn[0], not conn[1], not conn[2], not conn[3]]
	boxes.append({"g": hub, "faces": hub_open, "cy": c.y})
	for i in range(4):
		if not conn[i]:
			continue
		var a: Vector2 = corners[i]
		var b2: Vector2 = corners[(i + 1) % 4]
		var m := (a + b2) * 0.5
		var w := (b2 - a) * k
		var s := c + (m - c) * 2.0 * k
		var sides: Array[bool] = [true, false, true, false]
		boxes.append({"g": PackedVector2Array([s - w, m - w, m + w, s + w]), "faces": sides, "cy": (s.y + m.y) * 0.5})
	boxes.sort_custom(func(u, v): return u["cy"] < v["cy"])
	for bx in boxes:
		_draw_wall_block(bx["g"], bx["faces"], no_merlon, lh, col_light, col_dark, col_top, col_mortar, col_mortar)

## 수로로 물을 받는 논 — 물 댄 논두렁 줄
func _draw_paddy_water(p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2) -> void:
	for k: float in [0.3, 0.5, 0.7]:
		var a := p_n.lerp(p_w, k)
		var b2 := p_e.lerp(p_s, k)
		draw_line(a.lerp(b2, 0.12), a.lerp(b2, 0.88), Color(0.55, 0.8, 1.0, 0.6), 1.2)

## PORT-TRACE [공방 구획]: 야조소·와소(ind_1) — 흙가마 + 작은 작업 헛간 + 연기.
## 관영 수공업소(ind_2) — 헛간 두 채, 벽돌 더미, 굴뚝.
func _draw_workshop(c: Vector2, big: bool) -> void:
	FastDraw.poly(self, _diamond(c, 0.85), Color("8c7353"))
	# 흙가마(돔)
	var kc := c + Vector2(-9, 3)
	var dome := PackedVector2Array()
	for i in range(9):
		var ang := PI * float(i) / 8.0
		dome.append(kc + Vector2(cos(ang) * 8.0, -sin(ang) * 8.0))
	for i in range(1, 8):
		var ang2 := PI * float(i) / 8.0
		dome.append(kc + Vector2(-cos(ang2) * 8.0, sin(ang2) * 2.5))
	FastDraw.poly(self, dome, Color("8a5436"))
	draw_rect(Rect2(kc + Vector2(-2.5, -4.0), Vector2(5.0, 4.0)), Color("1e120c"))
	FastDraw.circle(self, kc + Vector2(0, -1.5), 1.5, Color("f08a24"))
	# 연기
	for s: Vector2 in [Vector2(-1, -12), Vector2(2, -17), Vector2(-2, -22)]:
		FastDraw.circle(self, kc + s, 2.6, Color(0.55, 0.55, 0.55, 0.55))
	# 작업 헛간
	var sc := c + Vector2(8, 2)
	draw_rect(Rect2(sc + Vector2(-8, -9), Vector2(16, 9)), Color("c9b48a"))
	FastDraw.poly(self, PackedVector2Array([sc + Vector2(-11, -9), sc + Vector2(11, -9), sc + Vector2(7, -15), sc + Vector2(-7, -15)]), Color("3a3f47"))
	if big:
		# 두 번째 헛간 + 벽돌 더미 + 굴뚝
		var sc2 := c + Vector2(0, -8)
		draw_rect(Rect2(sc2 + Vector2(-7, -8), Vector2(14, 8)), Color("b9a57c"))
		FastDraw.poly(self, PackedVector2Array([sc2 + Vector2(-10, -8), sc2 + Vector2(10, -8), sc2 + Vector2(6, -13), sc2 + Vector2(-6, -13)]), Color("30353c"))
		for r in range(3):
			draw_rect(Rect2(c + Vector2(-2 + r * 3, 7 - r * 2), Vector2(6, 2)), Color("a8442a"))
		draw_rect(Rect2(sc + Vector2(4, -22), Vector2(3, 10)), Color("5a4a3a"))
		FastDraw.circle(self, sc + Vector2(5.5, -25), 2.4, Color(0.5, 0.5, 0.5, 0.55))

## PORT-TRACE [대각선 연결]: 도로/성곽 공통 대각선 커넥터 스텁. 이 타일 중심(c)에서 대각
## 이웃과 공유하는 꼭짓점(corner)까지 이어 그린다 — 계단식으로 놓인 대각선 도로/성곽이
## 끊겨 보이던 문제를 해결한다.
func _draw_diag_stub(c: Vector2, corner: Vector2, fill_col: Color, border_col: Color, width: float) -> void:
	var dir := (corner - c).normalized()
	var perp := Vector2(-dir.y, dir.x) * width
	FastDraw.poly(self, PackedVector2Array([c - perp, c + perp, corner + perp, corner - perp]), fill_col)
	draw_line(c - perp, corner - perp, border_col, 1.5)
	draw_line(c + perp, corner + perp, border_col, 1.5)

func _draw_road(x: int, y: int, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2, c: Vector2, on_water: bool) -> void:
	var mid_n := (p_n + p_e) * 0.5
	var mid_e := (p_e + p_s) * 0.5
	var mid_s := (p_s + p_w) * 0.5
	var mid_w := (p_w + p_n) * 0.5

	var cn := grid.is_road_connector(x, y - 1)
	var ce := grid.is_road_connector(x + 1, y)
	var cs := grid.is_road_connector(x, y + 1)
	var cw := grid.is_road_connector(x - 1, y)
	# 대각 이웃: NE=p_e, SE=p_s, SW=p_w, NW=p_n 꼭짓점을 공유한다(GameGrid.get_road_diag_mask 참고)
	var dmask := grid.get_road_diag_mask(x, y)
	var dne := (dmask & 1) != 0
	var dse := (dmask & 2) != 0
	var dsw := (dmask & 4) != 0
	var dnw := (dmask & 8) != 0

	var rw := 8.0
	var tan_n := (p_e - p_n).normalized()
	var tan_e := (p_s - p_e).normalized()
	var tan_s := (p_w - p_s).normalized()
	var tan_w := (p_n - p_w).normalized()

	var nl := mid_n - tan_n * rw; var nr := mid_n + tan_n * rw
	var el := mid_e - tan_e * rw; var er := mid_e + tan_e * rw
	var sl := mid_s - tan_s * rw; var sr := mid_s + tan_s * rw
	var wl := mid_w - tan_w * rw; var wr := mid_w + tan_w * rw

	if on_water and grid.grid[y][x].get("is_maehyang", false):
		_draw_maehyang(x, y, p_n, p_e, p_s, p_w, c)
		return
	if on_water:
		# 수원천 횡단 대형 석교 (Granite Arch Bridge)
		var b_col := Color("9e988e")       # 화강암 상판
		var dark_stone := Color("545048")  # 교각 및 아치 그림자
		var curb_col := Color("6a665e")    # 석난간 지대석
		var rail_col := Color("3a3834")    # 돌난간 두겁석

		# 교각 기단 (하천 바닥 아치 교각)
		draw_rect(Rect2(c + Vector2(-8, 0), Vector2(16, 14)), dark_stone)
		FastDraw.circle(self, c + Vector2(0, 7), 5.5, Color("14222e"))
		draw_rect(Rect2(c + Vector2(-5, 7), Vector2(10, 7)), Color(0.9, 0.95, 1.0, 0.75))

		# 전면 연속 화강암 교량 상판
		if not (cn or ce or cs or cw or dne or dse or dsw or dnw):
			FastDraw.poly(self, _diamond(c, 0.65), b_col)
			FastDraw.polyline(self, PackedVector2Array(_diamond(c, 0.65) + PackedVector2Array([c + Vector2(0, -HH * 0.65)])), rail_col, 2.0)
		else:
			FastDraw.poly(self, _diamond(c, 0.48), b_col)
			if cn:
				FastDraw.poly(self, PackedVector2Array([c - tan_n * rw * 0.8, c + tan_n * rw * 0.8, nr, nl]), b_col)
				draw_line(c - tan_n * rw * 0.8 - Vector2(0, 4), nl - Vector2(0, 4), rail_col, 2.0)
				draw_line(c + tan_n * rw * 0.8 - Vector2(0, 4), nr - Vector2(0, 4), rail_col, 2.0)
				draw_line(c, mid_n, curb_col, 1.0)
			if ce:
				FastDraw.poly(self, PackedVector2Array([c - tan_e * rw * 0.8, c + tan_e * rw * 0.8, er, el]), b_col)
				draw_line(c - tan_e * rw * 0.8 - Vector2(0, 4), el - Vector2(0, 4), rail_col, 2.0)
				draw_line(c + tan_e * rw * 0.8 - Vector2(0, 4), er - Vector2(0, 4), rail_col, 2.0)
				draw_line(c, mid_e, curb_col, 1.0)
			if cs:
				FastDraw.poly(self, PackedVector2Array([c - tan_s * rw * 0.8, c + tan_s * rw * 0.8, sr, sl]), b_col)
				draw_line(c - tan_s * rw * 0.8 - Vector2(0, 4), sl - Vector2(0, 4), rail_col, 2.0)
				draw_line(c + tan_s * rw * 0.8 - Vector2(0, 4), sr - Vector2(0, 4), rail_col, 2.0)
				draw_line(c, mid_s, curb_col, 1.0)
			if cw:
				FastDraw.poly(self, PackedVector2Array([c - tan_w * rw * 0.8, c + tan_w * rw * 0.8, wr, wl]), b_col)
				draw_line(c - tan_w * rw * 0.8 - Vector2(0, 4), wl - Vector2(0, 4), rail_col, 2.0)
				draw_line(c + tan_w * rw * 0.8 - Vector2(0, 4), wr - Vector2(0, 4), rail_col, 2.0)
				draw_line(c, mid_w, curb_col, 1.0)
			if dne: _draw_diag_stub(c, p_e, b_col, rail_col, rw * 0.95)
			if dse: _draw_diag_stub(c, p_s, b_col, rail_col, rw * 0.95)
			if dsw: _draw_diag_stub(c, p_w, b_col, rail_col, rw * 0.95)
			if dnw: _draw_diag_stub(c, p_n, b_col, rail_col, rw * 0.95)

		# 돌난간 동자석 기둥
		for rp in [nl, nr, el, er, sl, sr, wl, wr]:
			draw_line(rp, rp - Vector2(0, 6), rail_col, 2.0)
			FastDraw.circle(self, rp - Vector2(0, 6), 1.5, Color("d0ccc4"))
	else:
		var road_type: String = grid.grid[y][x].get("road_type", "dirt")
		if road_type == "stone":
			_draw_stone_road(c, p_n, p_e, p_s, p_w, mid_n, mid_e, mid_s, mid_w, nl, nr, el, er, sl, sr, wl, wr, tan_n, tan_e, tan_s, tan_w, rw, cn, ce, cs, cw, dne, dse, dsw, dnw)
		else:
			_draw_dirt_road(c, p_n, p_e, p_s, p_w, mid_n, mid_e, mid_s, mid_w, nl, nr, el, er, sl, sr, wl, wr, tan_n, tan_e, tan_s, tan_w, rw, cn, ce, cs, cw, dne, dse, dsw, dnw)
		if not (dne or dse or dsw or dnw):
			var conn: Array[bool] = [cn, ce, cs, cw]
			var road_corners: Array[Vector2] = [p_n, p_e, p_s, p_w]
			_draw_roadside_greenery(x, y, road_corners, c, conn, road_type == "stone")

## PORT-TRACE [삼남대로 가로수·꽃]: 사용자 요청 — "삼남로 주변을 아름다운 가로수나 꽃들로
## 꾸며라. 건물만 잔뜩 있는 것보다 식물이 조화롭게 어우러져야 조선의 아름다움". 도로 타일에서
## 도로가 이어지지 않은 모서리 쪽(= 길가)에 나무·꽃을 심는다. 타일 좌표 해시로 정하므로 다시
## 그려도 같은 자리에 같은 나무가 선다. 박석길(큰길)은 촘촘한 가로수 길, 흙길은 드문드문.
## 별도 타일을 차지하지 않는 순수 장식이라 건설 규칙에는 영향이 없다.
func _draw_roadside_greenery(x: int, y: int, corners: Array[Vector2], c: Vector2, conn: Array[bool], is_stone: bool) -> void:
	if not (conn[0] or conn[1] or conn[2] or conn[3]):
		return
	for i in range(4):
		if conn[i]:
			continue
		var h: int = absi(hash(Vector3i(x, y, i))) % 100
		var m := (corners[i] + corners[(i + 1) % 4]) * 0.5
		var p := c + (m - c) * 0.72
		if is_stone:
			if h < 55:
				_draw_street_tree(p, h)
			elif h < 80:
				_draw_flower_bed(p, h)
		else:
			if h < 18:
				_draw_street_tree(p, h)
			elif h < 45:
				_draw_flower_bed(p, h)

## 가로수: 느티나무 / 수양버들 / 소나무
func _draw_street_tree(p: Vector2, h: int) -> void:
	FastDraw.circle(self, p + Vector2(1, 1), 3.0, Color(0, 0, 0, 0.22))
	var kind := h % 3
	if kind == 1: # 수양버들 — 가지가 늘어진다
		draw_line(p, p + Vector2(0, -9), Color("5a4630"), 1.6)
		FastDraw.circle(self, p + Vector2(0, -11), 4.2, Color("7fae4a"))
		for dx: float in [-3.5, -1.5, 0.5, 2.5, 4.0]:
			draw_line(p + Vector2(dx, -11), p + Vector2(dx * 1.1, -5), Color("93c25a"), 1.0)
	elif kind == 2: # 소나무
		draw_line(p, p + Vector2(-1, -8), Color("5e3019"), 1.8)
		FastDraw.circle(self, p + Vector2(2, -9), 3.2, Color("1e4725"))
		FastDraw.circle(self, p + Vector2(-2, -11), 3.4, Color("2a6133"))
	else: # 느티나무
		draw_line(p, p + Vector2(0, -8), Color("4a3d30"), 1.8)
		FastDraw.circle(self, p + Vector2(-2, -10), 3.6, Color("356f28"))
		FastDraw.circle(self, p + Vector2(2, -11), 3.4, Color("3f7f2e"))
		FastDraw.circle(self, p + Vector2(0, -13), 3.6, Color("4a8f35"))

## 길가 꽃무리: 진달래·구절초·민들레·도라지
func _draw_flower_bed(p: Vector2, h: int) -> void:
	var cols: Array[Color] = [Color("e64368"), Color("fdfdfa"), Color("f0be24"), Color("b04fd0")]
	for k in range(4):
		var fp := p + Vector2((float(k) - 1.5) * 2.4, float(k % 2) * 1.2)
		draw_line(fp, fp + Vector2(0, -2.5), Color("2f5e22"), 1.0)
		FastDraw.circle(self, fp + Vector2(0, -2.8), 1.3, cols[(h + k) % 4])

func _line_intersection(p1: Vector2, d1: Vector2, p2: Vector2, d2: Vector2) -> Vector2:
	var det: float = d1.x * d2.y - d1.y * d2.x
	if absf(det) < 0.0001:
		return (p1 + p2) * 0.5
	var dp: Vector2 = p2 - p1
	var t: float = (dp.x * d2.y - dp.y * d2.x) / det
	return p1 + d1 * t

func _draw_dirt_road(c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2, mid_n: Vector2, mid_e: Vector2, mid_s: Vector2, mid_w: Vector2, _nl: Vector2, _nr: Vector2, _el: Vector2, _er: Vector2, _sl: Vector2, _sr: Vector2, _wl: Vector2, _wr: Vector2, tan_n: Vector2, tan_e: Vector2, _tan_s: Vector2, _tan_w: Vector2, rw: float, cn: bool, ce: bool, cs: bool, cw: bool, dne: bool, dse: bool, dsw: bool, dnw: bool) -> void:
	# PORT-TRACE [깔끔한 도로]: 황토 흙길 — 띠 + 가장자리 선 + 수레바퀴 자국(교차로 안에는 긋지 않음)
	_draw_clean_road(c, mid_n, mid_e, mid_s, mid_w, tan_n, tan_e, 9.0, [cn, ce, cs, cw],
		{"fill": Color("cbb085"), "edge": Color("8a6638"), "edge_w": 1.4, "mark": Color("b0915f"), "kind": "dirt"})
	if dne: _draw_diag_stub(c, p_e, Color("cbb085"), Color("8a6638"), rw * 0.95)
	if dse: _draw_diag_stub(c, p_s, Color("cbb085"), Color("8a6638"), rw * 0.95)
	if dsw: _draw_diag_stub(c, p_w, Color("cbb085"), Color("8a6638"), rw * 0.95)
	if dnw: _draw_diag_stub(c, p_n, Color("cbb085"), Color("8a6638"), rw * 0.95)

## PORT-TRACE [깔끔한 도로]: 사용자 요청 — "교차로가 너무 복잡하게 생겨 보기 좋지 않다, 그냥 + 모양이면
## 좋겠다, 심시티처럼 깔끔하게". 예전 사거리는 모서리 교점을 구해 12각형을 만들었는데, 그 교점과
## 테두리 선이 가운데에서 X자로 엇갈려 지저분했다. 이제는 심시티 방식으로:
##   칸 가운데 평행사변형 조각(타일 모서리와 나란한 정사각) + 이어진 방향마다 같은 폭의 띠.
## 테두리(연석) 선은 길의 바깥 가장자리에만 긋는다 — 일자·ㄱ자·T자·+자가 모두 같은 규칙으로 깔끔하다.
## style: {"fill", "edge", "edge_w", "mark"(바퀴 자국/줄눈 색), "kind"("dirt"/"stone")}
func _draw_clean_road(c: Vector2, mid_n: Vector2, mid_e: Vector2, mid_s: Vector2, mid_w: Vector2,
		tan_n: Vector2, tan_e: Vector2, half_w: float, conn: Array, style: Dictionary) -> void:
	var A := tan_n * half_w # 동서(타일 +x) 방향 반폭
	var B := tan_e * half_w # 남북(타일 +y) 방향 반폭
	var q_nw := c - A - B
	var q_ne := c + A - B
	var q_se := c + A + B
	var q_sw := c - A + B
	var fill: Color = style["fill"]
	var edge: Color = style["edge"]
	var edge_w: float = style["edge_w"]
	var mark: Color = style["mark"]
	var stone: bool = style["kind"] == "stone"
	# 띠: [가운데 쪽 왼, 가운데 쪽 오른, 끝 오른, 끝 왼]
	var arms: Array = [
		[q_nw, q_ne, mid_n + A, mid_n - A],
		[q_ne, q_se, mid_e + B, mid_e - B],
		[q_sw, q_se, mid_s + A, mid_s - A],
		[q_nw, q_sw, mid_w + B, mid_w - B],
	]
	FastDraw.poly(self, PackedVector2Array([q_nw, q_ne, q_se, q_sw]), fill)
	for i in range(4):
		if conn[i]:
			var arm: Array = arms[i]
			FastDraw.poly(self, PackedVector2Array([arm[0], arm[1], arm[2], arm[3]]), fill)
	# 표시: 흙길은 띠마다 수레바퀴 자국 두 줄, 박석길은 띠를 가로지르는 줄눈 + 가운데 판석 줄눈
	for i in range(4):
		if not conn[i]:
			continue
		var arm2: Array = arms[i]
		var a0: Vector2 = arm2[0]
		var a1: Vector2 = arm2[1]
		var a2: Vector2 = arm2[2]
		var a3: Vector2 = arm2[3]
		if stone:
			for k: float in [0.34, 0.67]:
				draw_line(a0.lerp(a3, k), a1.lerp(a2, k), mark, 1.0)
		else:
			for k: float in [0.3, 0.7]:
				draw_line(a0.lerp(a1, k).lerp(a3.lerp(a2, k), 0.15), a3.lerp(a2, k), mark, 1.2)
	if stone:
		draw_line((q_nw + q_ne) * 0.5, (q_sw + q_se) * 0.5, mark, 1.0)
		draw_line((q_nw + q_sw) * 0.5, (q_ne + q_se) * 0.5, mark, 1.0)
	# 가장자리(연석) 선: 가운데 조각에서 길이 없는 변 + 각 띠의 양옆
	var sides: Array = [[q_nw, q_ne], [q_ne, q_se], [q_sw, q_se], [q_nw, q_sw]]
	for i in range(4):
		if conn[i]:
			var arm3: Array = arms[i]
			draw_line(arm3[0], arm3[3], edge, edge_w)
			draw_line(arm3[1], arm3[2], edge, edge_w)
		else:
			var sd: Array = sides[i]
			draw_line(sd[0], sd[1], edge, edge_w)

func _draw_stone_road(c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2, mid_n: Vector2, mid_e: Vector2, mid_s: Vector2, mid_w: Vector2, _nl: Vector2, _nr: Vector2, _el: Vector2, _er: Vector2, _sl: Vector2, _sr: Vector2, _wl: Vector2, _wr: Vector2, tan_n: Vector2, tan_e: Vector2, _tan_s: Vector2, _tan_w: Vector2, rw: float, cn: bool, ce: bool, cs: bool, cw: bool, dne: bool, dse: bool, dsw: bool, dnw: bool) -> void:
	# PORT-TRACE [깔끔한 도로]: 화강암 박석길 — 띠 + 연석 + 가로 줄눈(교차로 가운데는 판석 네 장)
	_draw_clean_road(c, mid_n, mid_e, mid_s, mid_w, tan_n, tan_e, 10.0, [cn, ce, cs, cw],
		{"fill": Color("b8b2a5"), "edge": Color("6e685e"), "edge_w": 2.0, "mark": Color("8f897d"), "kind": "stone"})
	if dne: _draw_diag_stub(c, p_e, Color("b8b2a5"), Color("6e685e"), rw * 0.95)
	if dse: _draw_diag_stub(c, p_s, Color("b8b2a5"), Color("6e685e"), rw * 0.95)
	if dsw: _draw_diag_stub(c, p_w, Color("b8b2a5"), Color("6e685e"), rw * 0.95)
	if dnw: _draw_diag_stub(c, p_n, Color("b8b2a5"), Color("6e685e"), rw * 0.95)

## PORT-TRACE [성곽 돌 질감]: 사용자가 실제 화성 성벽 사진(크고 작은 화강암 덩이를 층층이
## 불규칙하게 쌓아 올린 "허튼층쌓기" 질감)을 보내며 "지금은 고가도로처럼 밋밋하다"고 지적 —
## 평평한 단색 사각형 위에 층마다 어긋나는(품질감을 위한 스태거) 돌덩이 격자를 얹고 돌마다
## 밝기를 살짝 흔들고 줄눈을 그어 석축 느낌을 낸다. p1(좌상)→p2(우상)→p3(우하)→p4(좌하)
## 순서의 사다리꼴 벽면 어디에나 쓸 수 있다.
func _draw_stone_face(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2, base_col: Color, mortar_col: Color, rows: int = 3, cols: int = 5) -> void:
	# PORT-TRACE [성곽 새 단장]: 줄눈 바탕 위에 조금씩 작게 다듬은 돌(위 모서리 밝게·아래 어둡게), 면 둘레 외곽선
	FastDraw.poly(self, PackedVector2Array([p1, p2, p3, p4]), mortar_col)
	for r in range(rows):
		var v0 := float(r) / rows
		var v1 := float(r + 1) / rows
		var stagger := 0.0 if r % 2 == 0 else 0.5 / cols
		for ci in range(-1, cols + 1):
			var u0 := clampf(float(ci) / cols + stagger, 0.0, 1.0)
			var u1 := clampf(float(ci + 1) / cols + stagger, 0.0, 1.0)
			if u1 - u0 < 0.01:
				continue
			var jitter: float = (float(hash(r * 131 + ci * 7) % 19) - 9.0) / 100.0 # -0.09..0.09
			var stone_col: Color = base_col.lightened(jitter) if jitter > 0.0 else base_col.darkened(-jitter)
			var a := p1.lerp(p2, u0).lerp(p4.lerp(p3, u0), v0)
			var b := p1.lerp(p2, u1).lerp(p4.lerp(p3, u1), v0)
			var cc := p1.lerp(p2, u1).lerp(p4.lerp(p3, u1), v1)
			var d := p1.lerp(p2, u0).lerp(p4.lerp(p3, u0), v1)
			var m := (a + b + cc + d) * 0.25
			var k := 0.84
			a = m + (a - m) * k
			b = m + (b - m) * k
			cc = m + (cc - m) * k
			d = m + (d - m) * k
			FastDraw.poly(self, PackedVector2Array([a, b, cc, d]), stone_col)
			draw_line(d, cc, stone_col.lightened(0.2), 0.8) # 위 모서리 빛
			draw_line(a, b, stone_col.darkened(0.22), 0.8)  # 아래 모서리 그늘
	FastDraw.polyline(self, PackedVector2Array([p1, p2, p3, p4, p1]), FT_OUT, 1.0)

## PORT-TRACE [성곽 "| | | |" 버그 — 모델 전면 교체]: 이전 방식은 "이웃과 연결된 모서리"에
## 옆면을 세웠다. 그런데 이웃과 맞닿는 모서리는 성벽이 "지나가는" 내부 경계라서, 거기 세운 면은
## 성벽 진행 방향에 수직인 칸막이가 된다 — 그래서 성벽이 ------ 로 이어지지 않고 | | | | 처럼
## 평행한 판자들로 보였다(사용자 스크린샷). 올바른 모델은 "타일 중앙의 작은 허브 + 연결된 이웃
## 쪽으로 뻗은 팔(arm)"이다. 각 팔은 모서리 중점까지 가서 이웃 타일의 팔과 정확히 같은 점에서
## 만나고, 보이는 옆면은 팔의 "긴 변"(진행 방향과 평행)에만 세운다. 모든 점은 실제 꼭짓점
## (p_n/p_e/p_s/p_w, 경사 포함)에서 파생하므로 산비탈과 4방향 화면 회전에서도 이음매가 맞는다.
## PORT-TRACE [성곽 새 단장]: 둘레의 PNG 건물(따뜻한 화강암·짙은 갈색 외곽선·기왓골)과 어울리게 성곽 계열 공용 색.
const FT_OUT := Color("3b2d22")      # 외곽선(PNG 그림과 같은 짙은 밤색)
const FT_STONE := Color("c8bda5")    # 화강암 빛 받는 면
const FT_STONE_D := Color("9b907a")  # 화강암 그늘 면
const FT_MORTAR := Color("6f6452")   # 줄눈
const FT_WALK := Color("948872")     # 성 위 길(전돌 바닥)
const FT_BRICK := Color("938d84")    # 여장·전돌 빛 받는 면
const FT_BRICK_D := Color("736e66")
const FT_TILE := Color("454b54")     # 기와
const FT_TILE_HI := Color("7b848f")
const FT_RIDGE := Color("dcd6ca")    # 용마루·추녀마루 회반죽
const FT_RED := Color("a8392b")      # 붉은 기둥
const FT_RED_D := Color("7a2a20")
const FT_GREEN := Color("2f8a74")    # 단청 녹색
const FT_DARK := Color("2a201a")     # 문 안·총안 어둠
const WALL_THICK_K := 0.22 # 성벽 두께: 모서리 길이 대비 반폭 비율(0.22 → 모서리의 44% 두께)
const WALL_HEIGHT := 18.0

## PORT-TRACE [성곽 매끈한 높이]: 성벽은 칸 꼭짓점 높이(산비탈·능선 융기)를 그대로 따르지 않고, 이음점(변 가운데·꼭짓점)의
## 높이만 이웃 칸과 공유한 채 그 사이를 곧게 잇는다 — 산에서도 성 위 길이 칸마다 꺾이거나 비틀리지 않고, 단면은 늘 수평.
## 아래 땅이 더 낮은 곳은 체성 밑동을 땅까지 내려 그려 공중에 뜨지 않는다.
const WALL_LINE_B := ["poru", "gongsimdon", "gongsimdon_wall"]
var _wf: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO] # 높이 0 꼭짓점(n,e,s,w)
var _wce: Array = [1.0, 1.0, 1.0, 1.0]

func _wall_frame(t: Dictionary, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2) -> void:
	_wce = t.get("corner_elev", [1.0, 1.0, 1.0, 1.0])
	var ps: Array[Vector2] = [p_n, p_e, p_s, p_w]
	for i in range(4):
		_wf[i] = ps[i] + Vector2(0, float(_wce[i]) * ELEV_STEP)

## 칸 안 위치 uv(0~1, 밖으로 조금 넘어도 됨)와 높이 h → 화면
func _wp(uv: Vector2, h: float) -> Vector2:
	var p: Vector2 = _wf[0] * (1.0 - uv.x) * (1.0 - uv.y) + _wf[1] * uv.x * (1.0 - uv.y) + _wf[2] * uv.x * uv.y + _wf[3] * (1.0 - uv.x) * uv.y
	return p - Vector2(0, h * ELEV_STEP)

## uv 자리의 땅 높이
func _wterr(uv: Vector2) -> float:
	var u := clampf(uv.x, 0.0, 1.0)
	var v := clampf(uv.y, 0.0, 1.0)
	return float(_wce[0]) * (1.0 - u) * (1.0 - v) + float(_wce[1]) * u * (1.0 - v) + float(_wce[2]) * u * v + float(_wce[3]) * (1.0 - u) * v

## 이음점 높이: 꼭짓점이면 그 꼭짓점, 변 가운데면 두 꼭짓점 평균(이웃 칸과 같은 값), 칸 가운데면 넷의 평균
func _wend_h(e: Vector2) -> float:
	var ce: Array = _wce
	if e == Vector2(0.5, 0.5):
		return (float(ce[0]) + float(ce[1]) + float(ce[2]) + float(ce[3])) * 0.25
	var cu: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in range(4):
		if e == cu[i]:
			return float(ce[i])
	for i in range(4):
		if e == (cu[i] + cu[(i + 1) % 4]) * 0.5:
			return (float(ce[i]) + float(ce[(i + 1) % 4])) * 0.5
	return _wterr(e)

## 밑동을 땅까지: 성벽 높이 h가 땅보다 높은 만큼 화면 아래로
func _wskirt(uv: Vector2, h: float) -> Vector2:
	return Vector2(0, maxf(0.0, h - _wterr(uv)) * ELEV_STEP + 1.0)

## 성벽 이음 판정. 포루·공심돈·서장대처럼 여러 칸 묶음 안에서는 성벽 줄에 앉은 칸끼리만 잇는다
## (서장대 칸은 바깥 성벽 쪽으로만 이어져 칸 가운데에서 그친다 — 누각 기단 밑으로 들어간다).
const WALL_SIDE_B := ["yeonmudae", "yeonmudae_site", "poru_site", "gongsimdon_site", "bongdon_site"]
func _wconn(x: int, y: int, nx: int, ny: int) -> bool:
	if not grid.is_wall_connector(nx, ny):
		return false
	# 성벽 줄 밖(연무대 마당·포루/공심돈/봉돈의 바깥 칸)은 성벽이 옆을 지나갈 뿐 — 그쪽으로 꺾여 들어가 끊기지 않게
	var nt0 := String(grid.grid[ny][nx]["building"])
	if nt0 in WALL_SIDE_B:
		return false
	var t: Dictionary = grid.grid[y][x]
	if not t.has("site_anchor"):
		return true
	var nt: Dictionary = grid.grid[ny][nx]
	if not nt.has("site_anchor") or Vector2i(nt["site_anchor"]) != Vector2i(t["site_anchor"]):
		return true
	if bool(t.get("sj_wall", false)) and bool(nt.get("sj_wall", false)):
		return true
	return String(t["building"]) in WALL_LINE_B and String(nt["building"]) in WALL_LINE_B

## PORT-TRACE [대각 이음 덧그림]: 대각선으로 잇는 성벽은 꼭짓점 둘레에서 옆 칸 위로 조금 넘어가는데, 그 옆 칸 땅이
## 나중에 그려져 성벽을 덮어 이가 빠진 듯 보였다. 땅을 그린 칸이 서·북 이웃 성벽의 넘어온 부분을 다시 그린다.
func _redraw_wall_leaks(x: int, y: int) -> void:
	for d: Vector2i in [Vector2i(-1, 0), Vector2i(0, -1)]:
		var nx := x + d.x
		var ny := y + d.y
		if not grid.in_bounds(nx, ny):
			continue
		var nt: Dictionary = grid.grid[ny][nx]
		var nb := String(nt["building"])
		if nb == "wall":
			if nt.get("is_namsu", false) or nt.get("is_hwahong", false) or nt["terrain"] == "water" or nt.get("is_bridge", false):
				continue
		elif not (nb in WALL_LINE_B):
			continue
		var k := _tile_corners(nx, ny)
		_draw_wall(nx, ny, k[0], k[1], k[2], k[3], k[4], true)

## PORT-TRACE [성문 이음]: 실제 화성처럼 성문 가까이에서 성벽이 육축 높이까지 차츰 높아지며 붙는다.
## 성문 바로 옆 칸은 육축 끝면에서 성벽을 끝내고(trim), 성문에서 두 칸째까지 높이를 올린다(경사 길이 GATE_RAMP_LEN칸).
## 돌려주는 값: {} 또는 {"p": 육축 끝면 자리(이 칸 uv), "abs": 육축 윗면 절대 높이(px), "trim", "other"}
const GATE_RAMP_LEN := 1.4
## 성문에서 두 칸 안(성문 쪽으로 높아지는 성벽)
func _near_gate(x: int, y: int) -> bool:
	for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		for st in [1, 2]:
			var q: Vector2i = Vector2i(x, y) + d * st
			if grid.in_bounds(q.x, q.y) and String(grid.grid[q.y][q.x]["building"]) == "gate":
				return true
	return false
func _gate_ramp(x: int, y: int, ends: Array[Vector2]) -> Dictionary:
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var emid: Array[Vector2] = [Vector2(0.5, 0.0), Vector2(1.0, 0.5), Vector2(0.5, 1.0), Vector2(0.0, 0.5)]
	for i in range(4):
		if not (emid[i] in ends):
			continue
		var dv := Vector2(dirs[i])
		for step in [1, 2]:
			var g: Vector2i = Vector2i(x, y) + dirs[i] * step
			if not grid.in_bounds(g.x, g.y):
				break
			var gb := String(grid.grid[g.y][g.x]["building"])
			if gb != "gate":
				if step == 1 and gb == "wall":
					continue
				break
			var o := _gate_outward_edge(g.x, g.y)
			if (o == 0 or o == 2) != (dirs[i].x != 0):
				break
			var s := _gate_visual_scale(String(grid.grid[g.y][g.x].get("gate_name", "")))
			var d := clampf(1.25 * s * 0.5 - 0.5, 0.0, 0.85) # 성문 칸 가장자리 밖으로 뻗은 육축 길이(칸)
			var gce: Array = grid.grid[g.y][g.x].get("corner_elev", [1.0, 1.0, 1.0, 1.0])
			var gel := (float(gce[0]) + float(gce[1]) + float(gce[2]) + float(gce[3])) * 0.25
			var out := {"abs": GATE_H1 * s + gel * ELEV_STEP, "hw": GATE_V * s * 0.5}
			if step == 1:
				var other := Vector2(-1, -1)
				if ends.size() == 2:
					other = ends[1] if ends[0] == emid[i] else ends[0]
				if ends.size() != 2 or other != emid[(i + 2) % 4]:
					return {} # 성문 바로 옆에서 꺾이거나 막히면 그대로
				out["p"] = emid[i] - dv * d
				out["trim"] = true
				out["other"] = other
			else:
				out["p"] = emid[i] + dv * (1.0 - d)
			return out
	return {}

## PORT-TRACE [시설 옆면 감춤]: 포루·봉돈·공심돈은 묶음의 가장 앞 칸에서 한 번에 그려, 그보다 먼저 그려진 앞쪽 이웃 성벽 끝을
## 시설의 옆면이 덮어 버렸다(옆면이 성벽 위로 드러남). 시설을 그린 뒤 앞쪽에서 붙는 성벽을 다시 그려 성벽이 옆면을 가리게 한다.
func _rewall_front_neighbors(anchor: Vector2i) -> void:
	if not grid.in_bounds(anchor.x, anchor.y):
		return
	var tiles: Array = grid.grid[anchor.y][anchor.x].get("site_tiles", [anchor])
	var front := _group_front_tile(anchor)
	var fband := band_of(front.x, front.y)
	var done := {}
	for q0 in tiles:
		var q := Vector2i(q0)
		for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var n := q + d
			if not grid.in_bounds(n.x, n.y) or done.has(n):
				continue
			var nt: Dictionary = grid.grid[n.y][n.x]
			if String(nt["building"]) != "wall" or nt.get("is_namsu", false) or nt.get("is_hwahong", false):
				continue
			if n.x + n.y < q.x + q.y:
				continue # 뒤쪽 성벽은 시설이 덮는 것이 맞다
			if band_of(n.x, n.y) > fband:
				continue # 아직 그려지지 않은 칸은 제 차례에 시설 앞에 그려진다
			done[n] = true
			var k := _tile_corners(n.x, n.y)
			_draw_wall(n.x, n.y, k[0], k[1], k[2], k[3], k[4])

## 서장대 칸: 묶음 밖 성벽(곧은·대각 이웃)이 닿는가
func _wall_touches(x: int, y: int) -> bool:
	for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		if grid.in_bounds(x + d.x, y + d.y) and _wconn(x, y, x + d.x, y + d.y):
			return true
	return false

func _draw_wall(x: int, y: int, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2, c: Vector2, leak_only: bool = false) -> void:
	# PORT-TRACE [성곽 축조 기간]: 공사 중이면 단계별 높이(기단 → 2/3 → 완공)로 쌓아 올리고,
	# 여장(성가퀴)은 다 쌓은 뒤에만 올린다. 둘레에는 나무 비계, 옆엔 다듬은 성돌 더미.
	var t: Dictionary = grid.grid[y][x]
	var frac := grid.wall_build_fraction(t)
	var in_progress := frac < 1.0
	var wh := WALL_HEIGHT * frac
	var k := WALL_THICK_K
	_wall_frame(t, p_n, p_e, p_s, p_w)

	var wn := _wconn(x, y, x, y - 1)   # 북쪽 이웃 — 공유 모서리 p_n↔p_e
	var we := _wconn(x, y, x + 1, y)   # 동쪽 이웃 — 공유 모서리 p_e↔p_s
	var ws := _wconn(x, y, x, y + 1)   # 남쪽 이웃 — 공유 모서리 p_s↔p_w
	var ww := _wconn(x, y, x - 1, y)   # 서쪽 이웃 — 공유 모서리 p_w↔p_n
	var dne := _wconn(x, y, x + 1, y - 1)
	var dse := _wconn(x, y, x + 1, y + 1)
	var dsw := _wconn(x, y, x - 1, y + 1)
	var dnw := _wconn(x, y, x - 1, y - 1)
	if String(t["building"]) in ["seojangdae", "seojangdae_site"]:
		# 서장대 칸은 곧은 이웃 성벽만 기단 밑으로 끌어들인다(대각 토막이 누각 앞에 덧그려지지 않게)
		dne = false
		dse = false
		dsw = false
		dnw = false

	# PORT-TRACE [성곽 곡선]: 이음점이 하나·둘인 칸은 "가운데 네모 + 팔" 대신 두 이음점(변 가운데 또는 대각 꼭짓점)을 잇는
	# 2차 곡선 띠로 그린다. 칸 경계에서 이웃 칸 곡선과 같은 점·같은 방향으로 만나 성곽이 매끈하게 굽이친다.
	# 대각 이음은 옆 두 칸 중 어느 쪽으로도 이어지지 않을 때만 센다(계단식 모서리에 엉뚱한 곁가지가 생기지 않게).
	var ends: Array[Vector2] = []
	if wn:
		ends.append(Vector2(0.5, 0.0))
	if we:
		ends.append(Vector2(1.0, 0.5))
	if ws:
		ends.append(Vector2(0.5, 1.0))
	if ww:
		ends.append(Vector2(0.0, 0.5))
	if dne and not we and not wn:
		ends.append(Vector2(1.0, 0.0))
	if dse and not we and not ws:
		ends.append(Vector2(1.0, 1.0))
	if dsw and not ww and not ws:
		ends.append(Vector2(0.0, 1.0))
	if dnw and not ww and not wn:
		ends.append(Vector2(0.0, 0.0))
	if ends.size() == 1 or ends.size() == 2:
		# 서장대 2x2: 막다른 성벽을 묶음 한가운데(누각 기단 밑)까지
		var tip := Vector2(0.5, 0.5)
		var bt := String(t["building"])
		if ends.size() == 1 and (bt == "seojangdae" or bt == "seojangdae_site") and t.has("site_anchor"):
			var sa: Vector2i = t["site_anchor"]
			if grid.in_bounds(sa.x, sa.y) and grid.grid[sa.y][sa.x].get("site_tiles", []).size() >= 4:
				tip = Vector2(sa + Vector2i(1, 1) - Vector2i(x, y))
		# PORT-TRACE [성문 이음]: 성문 육축은 크게 그려 옆 칸까지 뻗는다 — 곧게 이어지는 옆 칸 성벽은 육축 끝면에서 끝내야
		# (육축 속까지 그리면 앞쪽 칸 성벽이 육축 앞면 위에 덧그려져 엇나가 보였다).
		var no_cap := false
		var ramp := _gate_ramp(x, y, ends)
		if bool(ramp.get("trim", false)):
			var ends1: Array[Vector2] = [ramp["other"]]
			ends = ends1
			tip = ramp["p"]
			no_cap = true
		if not ramp.is_empty():
			ramp["abs"] = float(ramp["abs"]) * frac
		_draw_wall_curve(ends, wh, in_progress, leak_only, tip, no_cap, ramp)
		if leak_only:
			return
		var hubq := PackedVector2Array()
		for hp: Vector2 in [p_n, p_e, p_s, p_w]:
			hubq.append(c + (hp - c) * 2.0 * k)
		if in_progress:
			_draw_scaffold(hubq, wh)
			_draw_stone_pile(c + (p_s - c) * 0.55)
			return
		var def_p: int = 1000
		var repairing := false
		if citizens and citizens.siege:
			def_p = citizens.siege.defense_power()
			repairing = bool(citizens.siege.repair_state.get("active", false))
		if def_p <= 700:
			var mid0 := c - Vector2(0, wh * 0.4)
			draw_line(mid0 + Vector2(-3, -4), mid0 + Vector2(1, 0), Color("231914"), 1.2)
			draw_line(mid0 + Vector2(1, 0), mid0 + Vector2(-2, 4), Color("231914"), 1.0)
			FastDraw.circle(self, mid0, 3.5, Color(0.12, 0.08, 0.06, 0.45))
		if def_p <= 400:
			draw_rect(Rect2(c + Vector2(4, 2), Vector2(3.5, 2.5)), Color("544e45"))
		if repairing and def_p < 950:
			_draw_scaffold(hubq, wh)
			_draw_stone_pile(c + (p_s - c) * 0.55)
		return

	var col_stone := FT_STONE      # 화강암 체성(빛 받는 면)
	var col_shade := FT_STONE_D    # 음영측 체성
	var col_walkway := FT_WALK     # 성도 전돌 바닥(상판)
	var col_battlement := FT_TILE  # 여장 지붕돌
	var col_mortar := FT_MORTAR    # 돌 틈 줄눈
	var top_col := Color("7c7568") if in_progress else col_walkway # 공사 중 상판은 막돌 채움
	var no_merlon: Array[bool] = [false, false, false, false]
	var hc := _wend_h(Vector2(0.5, 0.5))
	var cuv := Vector2(0.5, 0.5)
	var cu: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]

	# 대각 이음 팔(허브 모서리 → 대각 이웃과 공유하는 꼭짓점). 비트 0=NE(p_e), 1=SE(p_s), 2=SW(p_w), 3=NW(p_n)
	var dmask := 0
	if dne and not (we and wn): dmask |= 1
	if dse and not (we and ws): dmask |= 2
	if dsw and not (ww and ws): dmask |= 4
	if dnw and not (ww and wn): dmask |= 8
	var diag_boxes: Array = []
	for i in range(4):
		if (dmask & (1 << i)) == 0:
			continue
		var cuv_i: Vector2 = cu[(i + 1) % 4]
		var suv := cuv + (cuv_i - cuv) * 2.0 * k
		var dv := (cuv_i - suv).normalized()
		var wv := Vector2(-dv.y, dv.x) * k
		var hcor := _wend_h(cuv_i)
		var uvs: Array[Vector2] = [suv - wv, cuv_i - wv, cuv_i + wv, suv + wv]
		var hs: Array[float] = [hc, hcor, hcor, hc]
		diag_boxes.append(_wbox(uvs, hs, [true, false, true, false]))
	if leak_only:
		for bx in diag_boxes:
			_draw_wall_block(bx["g"], bx["faces"], no_merlon if in_progress else bx["faces"], wh, col_stone, col_shade, top_col, col_mortar, col_battlement, bx["sk"])
		return

	var conn: Array[bool] = [wn, we, ws, ww]
	var boxes: Array = []
	# 허브: 중앙 작은 사각형. 연결된 방향의 면은 팔과 이어지는 내부면이라 그리지 않는다.
	var hub_uv: Array[Vector2] = []
	var hub_h: Array[float] = []
	for q: Vector2 in cu:
		hub_uv.append(cuv + (q - cuv) * 2.0 * k)
		hub_h.append(hc)
	var hub_open: Array[bool] = [not wn, not we, not ws, not ww]
	boxes.append(_wbox(hub_uv, hub_h, hub_open))
	# 팔: 허브 가장자리(s)에서 공유 모서리 중점(m)까지. 이웃 칸도 같은 모서리 중점·같은 높이를 쓰므로 맞물린다.
	for i in range(4):
		if not conn[i]:
			continue
		var a: Vector2 = cu[i]
		var b: Vector2 = cu[(i + 1) % 4]
		var m := (a + b) * 0.5
		var w := (b - a) * k
		var s := cuv + (m - cuv) * 2.0 * k
		var hm := _wend_h(m)
		boxes.append(_wbox([s - w, m - w, m + w, s + w], [hc, hm, hm, hc], [true, false, true, false]))
	boxes.append_array(diag_boxes)

	# 같은 타일 안에서도 화면 뒤쪽 블록부터 그려 앞쪽 블록이 덮게 한다(페인터스 알고리즘)
	boxes.sort_custom(func(u, v): return u["cy"] < v["cy"])
	for bx in boxes:
		var merl: Array = bx["faces"]
		if in_progress:
			merl = no_merlon
		_draw_wall_block(bx["g"], bx["faces"], merl, wh, col_stone, col_shade, top_col, col_mortar, col_battlement, bx["sk"])
		if in_progress:
			_draw_scaffold(bx["g"], wh)

	if in_progress:
		_draw_stone_pile(c + (p_s - c) * 0.55)

	# 방호력 디그레이드 및 수축 대역사 보수 비계 연출
	var def_power: int = 1000
	var is_repairing: bool = false
	if citizens and citizens.siege:
		def_power = citizens.siege.defense_power()
		is_repairing = bool(citizens.siege.repair_state.get("active", false))

	# 1. 성 방호력 70% 이하 (<= 700): 성벽 표면 금(Crack) 및 그을음 데칼
	if def_power <= 700:
		var col_crack := Color("231914")
		var col_soot := Color(0.12, 0.08, 0.06, 0.45)
		for bx in boxes:
			var bg: PackedVector2Array = bx["g"]
			if bg.size() >= 4:
				var mid := (bg[0] + bg[2]) * 0.5 - Vector2(0, wh * 0.4)
				draw_line(mid + Vector2(-3, -4), mid + Vector2(1, 0), col_crack, 1.2)
				draw_line(mid + Vector2(1, 0), mid + Vector2(-2, 4), col_crack, 1.0)
				FastDraw.circle(self, mid, 3.5, col_soot)

	# 2. 성 방호력 40% 이하 (<= 400): 성벽 일부 파손 및 무너진 성돌 파편 데칼
	if def_power <= 400:
		var col_rubble := Color("544e45")
		for bx in boxes:
			var bg: PackedVector2Array = bx["g"]
			if bg.size() >= 4:
				var rpos := (bg[1] + bg[2]) * 0.5 + Vector2(2, 2)
				draw_rect(Rect2(rpos, Vector2(3.5, 2.5)), col_rubble)
				draw_rect(Rect2(rpos + Vector2(3, 2), Vector2(2.5, 2.0)), Color("3d3830"))

	# 3. 수축(修築) 대역사 보수 진행 중: 비계 및 석수/목수 돌무더기 연출
	if is_repairing and def_power < 950 and not in_progress:
		for bx in boxes:
			_draw_scaffold(bx["g"], wh)
		_draw_stone_pile(c + (p_s - c) * 0.55)

## 성벽 블록 하나(uv 네 점·높이 넷) → 화면 바닥 사각형 + 밑동 길이
func _wbox(uvs: Array, hs: Array, faces: Array) -> Dictionary:
	var g := PackedVector2Array()
	var sk: Array[Vector2] = []
	for i in range(4):
		g.append(_wp(uvs[i], hs[i]))
		sk.append(_wskirt(uvs[i], hs[i]))
	return {"g": g, "faces": faces, "sk": sk, "cy": (g[0].y + g[1].y + g[2].y + g[3].y) * 0.25}

## PORT-TRACE [장마당·세시풍속]: 장마당(공터) 칸 — 다져진 흙마당. 3x3 장마당은 한가운데 뒤쪽 칸에
## 당산나무(금줄 두른 느티나무), 평소엔 칸마다 좌표 해시로 난전 돗자리가 드문드문. 계절 놀이판은
## CitizenLayer가 그 위에 덧그린다(지도 굽기와 분리 — 놀이판이 바뀌어도 지도를 다시 굽지 않는다).
## 건물 그림 파일이 있는가(없으면 예전 코드 그림) — 처음 한 번만 디스크 확인
static var _bld_png_state := {}
func _bld_png_exists(id: String) -> bool:
	if not _bld_png_state.has(id):
		var pth := "res://assets/sprites/buildings/%s.png" % id
		_bld_png_state[id] = ResourceLoader.exists(pth) or FileAccess.file_exists(ProjectSettings.globalize_path(pth))
	return bool(_bld_png_state[id])

func _draw_plaza_tile(x: int, y: int, t: Dictionary, c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2) -> void:
	FastDraw.poly(self, PackedVector2Array([p_n, p_e, p_s, p_w]), Color("cdb98e"))
	var h := absi(x * 92821 + y * 68917)
	for i in range(4):
		var off := Vector2(float((h >> (i * 3)) % 23) - 11.0, float((h >> (i * 4 + 1)) % 11) - 5.0)
		draw_line(c + off, c + off + Vector2(2, 0), Color("b8a274"), 1.0)
	var pl: Dictionary = t["plaza"]
	var n := int(pl["n"])
	var rx := x - int(pl["x0"])
	var ry := y - int(pl["y0"])
	if str(pl.get("kind", "market")) == "cattle":
		_draw_cattle_yard_tile(x, y, rx, ry, c, p_n, p_e, p_s, p_w)
		return
	if str(pl.get("kind", "market")) == "salt":
		if _bld_png_exists("salt_store_2x2"):
			var snow2: bool = (band_master.current_season if band_master else current_season) == "겨울"
			FastDraw.poly(self, PackedVector2Array([p_n, p_e, p_s, p_w]), Color("edf2f7") if snow2 else Color("c4b89a"))
			if rx == n - 1 and ry == n - 1:
				var bc2 := cell_center(float(pl["x0"]) + float(n) * 0.5, float(pl["y0"]) + float(n) * 0.5, 1.0)
				_draw_building_cell({"type_id": "salt_store_2x2", "building": "salt"}, Rect2(bc2.x - 64.0, bc2.y + 32.0 - 112.0, 128.0, 112.0))
			return
		_draw_salt_store_tile(rx, ry, c, p_n, p_e, p_s, p_w)
		return
	if str(pl.get("kind", "market")) in ["seodang", "seowon", "maegok_seowon"]:
		FastDraw.poly(self, PackedVector2Array([p_n, p_e, p_s, p_w]), Color("cfc09a"))
		if rx == n - 1 and ry == n - 1:
			var bc := cell_center(float(pl["x0"]) + float(n) * 0.5, float(pl["y0"]) + float(n) * 0.5, 1.0)
			var s_kind: String = str(pl["kind"])
			if s_kind == "seodang":
				_draw_building_cell({"type_id": "seodang", "building": "seodang"}, Rect2(bc.x - 64.0, bc.y + 32.0 - 112.0, 128.0, 112.0))
			else:
				_draw_building_cell({"type_id": "maegok_seowon", "building": "maegok_seowon"}, Rect2(bc.x - 96.0, bc.y + 48.0 - 160.0, 192.0, 160.0))
		return
	if str(pl.get("kind", "market")) in ["kids", "play"]:
		FastDraw.poly(self, PackedVector2Array([p_n, p_e, p_s, p_w]), Color("cdb98e"))
		return
	if n == 3 and rx == 1 and ry == 0:
		# 당산나무 + 금줄
		draw_line(c, c - Vector2(0, 12), Color("4a3422"), 3.0)
		FastDraw.circle(self, c - Vector2(-6, 16), 7.0, Color("3d7a35"))
		FastDraw.circle(self, c - Vector2(5, 18), 7.5, Color("468a3c"))
		FastDraw.circle(self, c - Vector2(0, 24), 7.0, Color("52984a"))
		draw_line(c - Vector2(3.5, 6), c - Vector2(-3.5, 6), Color("e8dcb0"), 1.4)
		for k in range(3):
			draw_line(c - Vector2(2.5 - k * 2.5, 6), c - Vector2(2.5 - k * 2.5, 3), Color("f4f0e4"), 0.8)
	elif h % 3 == 0:
		# 난전 돗자리 + 물건
		var m := c + Vector2(float(h % 9) - 4.0, 2.0)
		FastDraw.poly(self, PackedVector2Array([m + Vector2(-8, 0), m + Vector2(0, -4), m + Vector2(8, 0), m + Vector2(0, 4)]), Color("c8b27a"))
		FastDraw.circle(self, m + Vector2(-2, -1), 1.6, Color(["4f9a3a", "c0392b", "e8c040", "5e3a22"][h % 4]))
		FastDraw.circle(self, m + Vector2(2, 0), 1.6, Color(["e6d7b0", "8a6236", "4f9a3a", "c0392b"][(h >> 2) % 4]))

## ─────────────────────────────────────────────── 가게·공방·공공시설 앞면 방향
## 길(박석길 우선)·성문과 맞닿은 모서리를 "앞"으로 삼아 로컬 축 [a, f]를 돌려준다(성문 _draw_gate와 같은
## 방식: a=그 모서리 방향 반벡터, f=중심→모서리 중점). 길이 없으면 화면 앞쪽(남 모서리)을 앞으로 삼는다.
func _front_frame(x: int, y: int, c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2) -> Array:
	var best := -1
	var best_score := 0
	for e in range(4):
		var d: Vector2i = GATE_EDGE_DIRS[e]
		var nx := x + d.x
		var ny := y + d.y
		if not grid.in_bounds(nx, ny):
			continue
		var nb: String = grid.grid[ny][nx]["building"]
		var score := 0
		if grid.is_stone_road(nx, ny):
			score = 3
		elif nb == "road":
			score = 2
		elif nb == "gate":
			score = 1
		if score > best_score:
			best_score = score
			best = e
	if best < 0:
		# 길이 없으면 지금 화면에서 가장 앞(아래)에 보이는 모서리
		var rel0: Array[Vector2] = [p_n - c, p_e - c, p_s - c, p_w - c]
		var low := -INF
		for e in range(4):
			var mid: Vector2 = (rel0[e] + rel0[(e + 1) % 4]) * 0.5
			if mid.y > low:
				low = mid.y
				best = e
	var rel: Array[Vector2] = [p_n - c, p_e - c, p_s - c, p_w - c]
	var ea: Vector2 = rel[best]
	var eb: Vector2 = rel[(best + 1) % 4]
	return [(eb - ea) * 0.5, (ea + eb) * 0.5]

## 민가: 단독이면 길 쪽을 앞으로, 그룹(t["hgroup"])이면 그룹 전체가 길을 향하도록 칸마다 제 몫을 그린다
func _draw_house(x: int, y: int, t: Dictionary, c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2) -> void:
	var b: String = t["building"]
	var is_ruined: bool = bool(t.get("is_ruined", false))
	if not t.has("hgroup"):
		var fr := _front_frame(x, y, c, p_n, p_e, p_s, p_w)
		var tier := 1 if b == "res_1" else 2
		if is_ruined:
			HouseArt.draw_ruined_house(self, c, fr[0], fr[1], tier, int(t.get("house_variant", _variant_of(x, y, t))))
		else:
			HouseArt.draw_single(self, c, fr[0], fr[1], tier, int(t.get("house_variant", _variant_of(x, y, t))))
		return
	if is_ruined:
		var fr_grp := _front_frame(x, y, c, p_n, p_e, p_s, p_w)
		HouseArt.draw_ruined_house(self, c, fr_grp[0], fr_grp[1], 2, int(t.get("house_variant", _variant_of(x, y, t))))
		return
	var g: Dictionary = t["hgroup"]
	var x0 := int(g["x0"])
	var y0 := int(g["y0"])
	var w := int(g["w"])
	var h := int(g["h"])
	var fd := _group_front_dir(x0, y0, w, h)
	var ad := Vector2i(-fd.y, fd.x)
	var gx := (p_e - p_n) * 0.5
	var gy := (p_w - p_n) * 0.5
	var F := gx * float(fd.x) + gy * float(fd.y)
	var A := gx * float(ad.x) + gy * float(ad.y)
	var rx := x - x0
	var ry := y - y0
	var gj := 0
	var D := 1
	if fd.x != 0:
		D = w
		gj = rx if fd.x > 0 else w - 1 - rx
	else:
		D = h
		gj = ry if fd.y > 0 else h - 1 - ry
	var gi := 0
	var W := 1
	if ad.x != 0:
		W = w
		gi = rx if ad.x > 0 else w - 1 - rx
	else:
		W = h
		gi = ry if ad.y > 0 else h - 1 - ry
	var outer := [gj == 0, gj == D - 1, gi == 0, gi == W - 1]
	HouseArt.draw_group_part(self, c, A, F, gi, gj, W, D, int(t.get("house_variant", 0)), outer)

## 그룹 민가가 향할 방향(격자 단위): 둘레 바깥에 박석길(3)·흙길(2)이 가장 많이 닿은 쪽. 없으면 +y.
func _group_front_dir(x0: int, y0: int, w: int, h: int) -> Vector2i:
	var best := Vector2i(0, 1)
	var best_score := 0
	for d: Vector2i in GATE_EDGE_DIRS:
		var score := 0
		for yy in range(y0, y0 + h):
			for xx in range(x0, x0 + w):
				var nx := xx + d.x
				var ny := yy + d.y
				if nx >= x0 and nx < x0 + w and ny >= y0 and ny < y0 + h:
					continue
				if grid.is_stone_road(nx, ny):
					score += 3
				elif grid.building_at(nx, ny) == "road":
					score += 2
		if score > best_score:
			best_score = score
			best = d
	return best

## 업종이 아직 정해지지 않은 가게(첫 턴 전 등)는 좌표로 고정된 업종을 임시로 쓴다
func _trade_of(x: int, y: int, t: Dictionary) -> String:
	var trade_name: String = t.get("trade", "")
	if trade_name != "":
		return trade_name
	var b: String = t["building"]
	var pool: Array = MarketArt.WORKSHOP_TRADES
	if b.begins_with("com"):
		if grid.shop_category(x, y) == "yuk":
			pool = MarketArt.YUK_TRADES
		else:
			pool = MarketArt.NAN_BIG if b == "com_2" else MarketArt.NAN_SMALL
	return pool[absi(x * 73856093 ^ y * 19349663) % pool.size()]

func _variant_of(x: int, y: int, t: Dictionary) -> int:
	if t.has("variant"):
		return int(t["variant"])
	return absi(x * 31 + y * 17) % 3

## ─────────────────────────────────────────────── 단계별 건설(터 다지기 → 골조 → 마무리)
## PORT-TRACE [단계별 건설]: 공정 단계 0 = 터 다지기(말뚝·새끼줄·다진 흙·달구), 1 = 기단 + 나무 골조
## (_draw_construction_site), 2 = 완성 모습 위에 비계(_draw_finish_scaffold). structure=false인 칸
## (행궁 마당·길·후원 등)은 골조 없이 박석을 까는 모습만 보인다.
func _draw_build_stage(c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2, frac: float, structure: bool) -> void:
	if GameGrid.build_stage(frac) == 0:
		_draw_groundwork(c, p_n, p_e, p_s, p_w, frac / 0.34)
	elif structure:
		_draw_construction_site(c, p_n, p_e, p_s, p_w, (frac - 0.34) / 0.33)
	else:
		_draw_groundwork(c, p_n, p_e, p_s, p_w, 1.0)
		# 박석을 반쯤 깐 마당
		var k := clampf((frac - 0.34) / 0.33, 0.0, 1.0)
		FastDraw.poly(self, PackedVector2Array([c + (p_n - c) * 0.85, c + (p_e - c) * 0.85, c + (p_e - c) * 0.85 + (p_s - p_e) * 0.85 * k, c + (p_n - c) * 0.85 + (p_w - p_n) * 0.85 * k]), HG_PAVE)

## 터 다지기: 흙을 다진 바닥 + 네 귀퉁이 말뚝과 새끼줄(규준틀) + 흙더미 + 달구(땅 다지는 통나무)
func _draw_groundwork(c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2, k: float) -> void:
	var corners: Array[Vector2] = [p_n, p_e, p_s, p_w]
	var yard := PackedVector2Array()
	for p: Vector2 in corners:
		yard.append(c + (p - c) * 0.92)
	FastDraw.poly(self, yard, Color("8f7650").lerp(Color("a08a66"), clampf(k, 0.0, 1.0)))
	# 다짐 자국(줄무늬)
	for i in range(3):
		var tt := 0.25 + 0.25 * float(i)
		draw_line(c + (p_n - c) * 0.8 + (p_w - p_n) * 0.8 * tt, c + (p_e - c) * 0.8 + (p_s - p_e) * 0.8 * tt, Color(0.35, 0.26, 0.16, 0.35), 1.0)
	# 규준틀: 말뚝 + 새끼줄
	var stakes: Array[Vector2] = []
	for p: Vector2 in corners:
		var sp := c + (p - c) * 0.78
		draw_line(sp, sp - Vector2(0, 7), Color("6b4a2a"), 1.4)
		stakes.append(sp - Vector2(0, 5))
	for i in range(4):
		draw_line(stakes[i], stakes[(i + 1) % 4], Color("e8dcc0"), 0.8)
	# 흙더미
	var mound := c + (p_w - c) * 0.45
	FastDraw.poly(self, PackedVector2Array([mound + Vector2(-7, 0), mound + Vector2(7, 0), mound + Vector2(2, -5), mound + Vector2(-3, -4)]), Color("7a6040"))
	# 달구(땅 다지는 통나무) — 손잡이 달린 굵은 통나무
	var ram := c + (p_e - c) * 0.35 + Vector2(0, -2)
	draw_rect(Rect2(ram + Vector2(-2.5, -9), Vector2(5, 9)), Color("8a6a42"))
	draw_line(ram + Vector2(-6, -7), ram + Vector2(6, -7), Color("5c3a21"), 1.2)

## 마무리: 완성 모습 둘레에 남은 비계와 공사 깃발
func _draw_finish_scaffold(c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2) -> void:
	var g := PackedVector2Array()
	for p: Vector2 in [p_n, p_e, p_s, p_w]:
		g.append(c + (p - c) * 0.72)
	_draw_scaffold(g, 18.0)
	var pole := c + (p_e - c) * 0.8
	draw_line(pole, pole - Vector2(0, 30), Color("5c3a21"), 1.4)
	FastDraw.poly(self, PackedVector2Array([pole - Vector2(0, 30), pole - Vector2(-9, 27), pole - Vector2(0, 24)]), Color("c0392b"))

## 공사 중인 부지(행궁·만석거) 칸. 단계 0·1은 공사 현장, 단계 2는 완성될 모습 + 비계.
func _draw_site_under_construction(x: int, y: int, c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2) -> void:
	var site: Dictionary = grid.site_at(Vector2i(x, y))
	if site.is_empty():
		_draw_building_slot(c, 48)
		return
	var frac := grid.site_fraction(site)
	var rel: Vector2i = Vector2i(x, y) - (site["anchor"] as Vector2i)
	var bname: String = site["building"]
	var structure := true
	if bname == "haenggung":
		structure = _haenggung_is_structure(rel)
	elif bname == "manseokgeo":
		structure = false
	if GameGrid.build_stage(frac) < 2:
		if bname == "manseokgeo" and GameGrid.build_stage(frac) == 1:
			# 저수지: 둑을 쌓고 바닥을 파내는 중 — 파인 흙바닥
			FastDraw.poly(self, _diamond(c, 0.95), Color("6e5a3c"))
			FastDraw.polyline(self, PackedVector2Array(_diamond(c, 0.7)) + PackedVector2Array([_diamond(c, 0.7)[0]]), Color("5a4630"), 1.0)
		else:
			_draw_build_stage(c, p_n, p_e, p_s, p_w, frac, structure)
		return
	if bname == "haenggung":
		_draw_haenggung_part(rel, c, p_n, p_e, p_s, p_w)
	elif bname == "gwana":
		_draw_gwana_part(x, y, site["anchor"], c, p_n, p_e, p_s, p_w)
	elif bname == "jongnu":
		_draw_jongnu_part(rel, c, p_n, p_e, p_w)
	elif bname == "yeonghwajeong":
		_draw_yeonghwajeong_part(rel, site["anchor"], c, p_n, p_e, p_w)
	elif bname == "hyanggyo":
		_draw_hyanggyo_part(Vector2i(x, y), site["anchor"], c)
	elif bname == "manseokgeo":
		_draw_manseokgeo_part(rel, c, p_n, p_e, p_s, p_w)
	if structure:
		_draw_finish_scaffold(c, p_n, p_e, p_s, p_w)

## 행궁 배치표에서 이 칸에 전각·행각이 서는가(마당·길·나무·후원이면 false)
func _haenggung_is_structure(grid_rel: Vector2i) -> bool:
	var rel := Vector2i(grid_rel.y, grid_rel.x) # _draw_haenggung_part와 같은 동향(東向) 변환
	if absi(rel.x) == 3 or absi(rel.y) == 3:
		return true
	var part: String = HAENGGUNG_LAYOUT.get(rel, "yard")
	return not (part in ["yard", "path", "tree", "garden"])

## PORT-TRACE [건설 기간 확대]: 한 칸 건물의 공사 현장 — 다진 터와 석축 기단(진척만큼 높이),
## 그 위 나무 골조와 비계, 성돌 더미, 붉은 공사 깃발.
func _draw_construction_site(c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2, frac: float) -> void:
	var corners: Array[Vector2] = [p_n, p_e, p_s, p_w]
	# 다진 흙 터
	var yard := PackedVector2Array()
	for p: Vector2 in corners:
		yard.append(c + (p - c) * 0.9)
	FastDraw.poly(self, yard, Color("a08a66"))
	# 석축 기단(진척만큼 올라감)
	var base := PackedVector2Array()
	for p: Vector2 in corners:
		base.append(c + (p - c) * 0.6)
	var all_faces: Array[bool] = [true, true, true, true]
	var none: Array[bool] = [false, false, false, false]
	var bh := 3.0 + 6.0 * frac
	_draw_wall_block(base, all_faces, none, bh, Color("9c968a"), Color("7a756b"), Color("8a8272"), Color("4a453e"), Color("1c1d22"))
	# 기단 위 나무 골조(기둥 네 개 + 들보)
	var wood := Color("8a6a42")
	var up := Vector2(0, bh)
	var frame_h := 14.0
	var tops: Array[Vector2] = []
	for p: Vector2 in base:
		var foot := p - up + (c - p) * 0.2
		draw_line(foot, foot - Vector2(0, frame_h), wood, 1.6)
		tops.append(foot - Vector2(0, frame_h))
	for i in range(4):
		draw_line(tops[i], tops[(i + 1) % 4], wood, 1.4)
	# 둘레 비계
	_draw_scaffold(base, bh + frame_h - 6.0)
	# 성돌 더미와 공사 깃발
	_draw_stone_pile(c + (p_s - c) * 0.72 + Vector2(6, 0))
	var pole := c + (p_e - c) * 0.7
	draw_line(pole, pole - Vector2(0, 22), Color("5c3a21"), 1.4)
	FastDraw.poly(self, PackedVector2Array([pole - Vector2(0, 22), pole - Vector2(-9, 19), pole - Vector2(0, 16)]), Color("c0392b"))

## PORT-TRACE [성곽 축조 기간]: 공사 중인 블록 둘레의 나무 비계 — 네 모서리 기둥 + 가로대 두 단 + 가새
func _draw_scaffold(g: PackedVector2Array, wh: float) -> void:
	var wood := Color("7a5a36")
	var center := (g[0] + g[1] + g[2] + g[3]) * 0.25
	var top_h := wh + 8.0
	var poles: Array[Vector2] = []
	for p: Vector2 in g:
		poles.append(p + (p - center).normalized() * 1.5)
	for p: Vector2 in poles:
		draw_line(p, p - Vector2(0, top_h), wood, 1.2)
	for i in range(4):
		var p0: Vector2 = poles[i]
		var p1: Vector2 = poles[(i + 1) % 4]
		draw_line(p0 - Vector2(0, wh * 0.55), p1 - Vector2(0, wh * 0.55), wood, 1.0)
		draw_line(p0 - Vector2(0, top_h - 1.0), p1 - Vector2(0, top_h - 1.0), wood, 1.0)
	draw_line(poles[0] - Vector2(0, 1.0), poles[1] - Vector2(0, top_h - 1.0), wood.darkened(0.2), 0.9)

## 다듬어 쌓아 둔 성돌 더미
func _draw_stone_pile(p: Vector2) -> void:
	var col := Color("9c968a")
	var edge := Color("4a453e")
	for r: Rect2 in [Rect2(p + Vector2(-6, -3), Vector2(6, 3)), Rect2(p + Vector2(0, -3), Vector2(6, 3)), Rect2(p + Vector2(-3, -6), Vector2(6, 3))]:
		draw_rect(r, col)
		draw_rect(r, edge, false, 0.8)

## 성벽 한 블록(허브 또는 팔): 바닥 사각형 g(4점, 순서대로)를 wh만큼 세운 상자.
## faces[i]가 true인 변(g[i]→g[i+1])만 옆면을 세우고, 뒤쪽 면부터 그린 뒤 상판을 덮는다.
func _draw_wall_block(g: PackedVector2Array, faces: Array, merlons: Array, wh: float, col_light: Color, col_dark: Color, col_top: Color, col_mortar: Color, col_battle: Color, skirt: Array = []) -> void:
	var up := Vector2(0, wh)
	var center := (g[0] + g[1] + g[2] + g[3]) * 0.25
	var order: Array[int] = []
	for i in range(4):
		if faces[i]:
			order.append(i)
	order.sort_custom(func(i: int, j: int): return (g[i] + g[(i + 1) % 4]).y < (g[j] + g[(j + 1) % 4]).y)
	for i in order:
		var a: Vector2 = g[i]
		var b: Vector2 = g[(i + 1) % 4]
		var mid := (a + b) * 0.5
		# 화면 오른쪽을 향한 면은 밝게, 왼쪽은 그늘 — 회전 방향과 무관하게 일관된 조명
		var col := col_light if mid.x >= center.x else col_dark
		var sa: Vector2 = skirt[i] if skirt.size() == 4 else Vector2.ZERO # 밑동을 땅까지(성벽)
		var sb: Vector2 = skirt[(i + 1) % 4] if skirt.size() == 4 else Vector2.ZERO
		_draw_stone_face(a + sa, b + sb, b - up, a - up, col, col_mortar, maxi(2, int(wh / 7.0)), 3)
	var snow: bool = (band_master.current_season if band_master else current_season) == "겨울"
	var final_top: Color = Color("e4e9ee") if snow else col_top
	var topq := PackedVector2Array([g[0] - up, g[1] - up, g[2] - up, g[3] - up])
	FastDraw.poly(self, topq, final_top)
	if not snow: # 전돌 바닥 줄
		draw_line(topq[0].lerp(topq[3], 0.5), topq[1].lerp(topq[2], 0.5), final_top.darkened(0.12), 0.6)
	for i in range(4):
		if faces[i]:
			draw_line(topq[i], topq[(i + 1) % 4], FT_OUT, 0.9)
	# 여장: 화면 뒤쪽 변부터
	var mo: Array[int] = []
	for i in range(4):
		if merlons[i]:
			mo.append(i)
	mo.sort_custom(func(i: int, j: int): return (g[i] + g[(i + 1) % 4]).y < (g[j] + g[(j + 1) % 4]).y)
	for i in mo:
		var lit := ((g[i] + g[(i + 1) % 4]) * 0.5).x >= center.x
		_draw_wall_merlons(g[i] - up, g[(i + 1) % 4] - up, col_battle, snow, lit)

## 칸 안 위치(u, v ∈ 0~1, 경사 포함) → 화면: 네 꼭짓점 쌍선형 보간
func _wall_uv(u: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2) -> Vector2:
	return p_n * (1.0 - u.x) * (1.0 - u.y) + p_e * u.x * (1.0 - u.y) + p_s * u.x * u.y + p_w * (1.0 - u.x) * u.y

## 곡선 성벽 띠: ends(이음점 1~2개, 칸 안 좌표)를 칸 가운데를 조절점으로 잇는 2차 곡선을 따라 화강암 체성·성 위 길·여장.
## 높이는 두 이음점 높이를 곡선을 따라 곧게 잇고(단면 수평), 밑동은 땅까지. leak_only면 칸 밖으로 넘어간 마디만.
func _draw_wall_curve(ends: Array[Vector2], wh: float, in_progress: bool, leak_only: bool = false, tip: Vector2 = Vector2(0.5, 0.5), no_cap: bool = false, ramp: Dictionary = {}) -> void:
	var cpt := Vector2(0.5, 0.5)
	var a0: Vector2 = ends[0]
	var b0: Vector2 = ends[1] if ends.size() > 1 else tip
	var straight := ends.size() == 1 or absf((a0 - cpt).normalized().dot((b0 - cpt).normalized()) + 1.0) < 0.01
	var nseg := 3 if straight else 8
	var hw := WALL_THICK_K
	var h0 := _wend_h(a0)
	var h1 := _wend_h(b0)
	var cl: Array[Vector2] = []
	var tg: Array[Vector2] = []
	var hh: Array[float] = []
	for i in range(nseg + 1):
		var t := float(i) / float(nseg)
		if ends.size() == 1:
			cl.append(a0.lerp(tip, t))
			tg.append(tip - a0)
		else:
			cl.append(a0 * (1.0 - t) * (1.0 - t) + cpt * 2.0 * (1.0 - t) * t + b0 * t * t)
			tg.append((cpt - a0) * 2.0 * (1.0 - t) + (b0 - cpt) * 2.0 * t)
		hh.append(lerpf(h0, h1, t))
	var Luv: Array[Vector2] = []
	var Ruv: Array[Vector2] = []
	var L: Array[Vector2] = []
	var R: Array[Vector2] = []
	for i in range(cl.size()):
		var tv: Vector2 = tg[i].normalized()
		var hwi := hw
		if not ramp.is_empty():
			# 성문 가까이: 두께도 육축 두께까지 넓힌다
			hwi = lerpf(hw, float(ramp["hw"]), smoothstep(0.0, 1.0, 1.0 - cl[i].distance_to(ramp["p"]) / GATE_RAMP_LEN))
		var nv := Vector2(-tv.y, tv.x) * hwi
		Luv.append(cl[i] + nv)
		Ruv.append(cl[i] - nv)
		L.append(_wp(cl[i] + nv, hh[i]))
		R.append(_wp(cl[i] - nv, hh[i]))
	var up := Vector2(0, wh)
	# 성문 옆: 성벽 높이를 육축 높이까지 차츰 올린다
	var ups: Array[Vector2] = []
	for i in range(cl.size()):
		if ramp.is_empty():
			ups.append(Vector2(0, wh))
			continue
		var dist: float = cl[i].distance_to(ramp["p"])
		var kk := smoothstep(0.0, 1.0, 1.0 - dist / GATE_RAMP_LEN)
		var target := maxf(wh, float(ramp["abs"]) - hh[i] * ELEV_STEP)
		ups.append(Vector2(0, lerpf(wh, target, kk)))
	var snow: bool = (band_master.current_season if band_master else current_season) == "겨울"
	var top_col: Color = Color("e4e9ee") if snow else (Color("a89c84") if in_progress else FT_WALK)
	var segs: Array[int] = []
	for i in range(nseg):
		if leak_only:
			var outside := false
			for q: Vector2 in [Luv[i], Luv[i + 1], Ruv[i], Ruv[i + 1]]:
				if q.x < -0.001 or q.y < -0.001 or q.x > 1.001 or q.y > 1.001:
					outside = true
			if not outside:
				continue
		segs.append(i)
	if segs.is_empty():
		return
	segs.sort_custom(func(i: int, j: int) -> bool: return (L[i] + R[i + 1]).y < (L[j] + R[j + 1]).y)
	var rows := maxi(2, int(wh / 7.0))
	for i in segs:
		var mid := (L[i] + L[i + 1] + R[i] + R[i + 1]) * 0.25
		up = ups[i]
		# 두 옆면: 화면 아래(앞)를 향한 쪽만. 밑동은 땅까지 내린다.
		for side in range(2):
			var e0: Vector2 = L[i] if side == 0 else R[i + 1]
			var e1: Vector2 = L[i + 1] if side == 0 else R[i]
			var outv := (e0 + e1) * 0.5 - mid
			if outv.y <= 0.0:
				continue
			var s0: Vector2 = _wskirt(Luv[i], hh[i]) if side == 0 else _wskirt(Ruv[i + 1], hh[i + 1])
			var s1: Vector2 = _wskirt(Luv[i + 1], hh[i + 1]) if side == 0 else _wskirt(Ruv[i], hh[i])
			var u0: Vector2 = ups[i] if side == 0 else ups[i + 1]
			var u1: Vector2 = ups[i + 1] if side == 0 else ups[i]
			_draw_stone_face(e0 + s0, e1 + s1, e1 - u1, e0 - u0, FT_STONE if outv.x >= 0.0 else FT_STONE_D, FT_MORTAR, rows, maxi(1, int(round(e0.distance_to(e1) / 7.0))))
		var ua: Vector2 = ups[i]
		var ub: Vector2 = ups[i + 1]
		var topq := PackedVector2Array([L[i] - ua, L[i + 1] - ub, R[i + 1] - ub, R[i] - ua])
		FastDraw.poly(self, topq, top_col)
		draw_line(L[i] - ua, L[i + 1] - ub, FT_OUT, 0.9)
		draw_line(R[i] - ua, R[i + 1] - ub, FT_OUT, 0.9)
		if not in_progress:
			var pl: Array = [[L[i] - ua, L[i + 1] - ub], [R[i] - ua, R[i + 1] - ub]]
			pl.sort_custom(func(u: Array, v: Array) -> bool: return ((u[0] as Vector2) + (u[1] as Vector2)).y < ((v[0] as Vector2) + (v[1] as Vector2)).y)
			for e: Array in pl:
				var em: Vector2 = ((e[0] as Vector2) + (e[1] as Vector2)) * 0.5
				_draw_wall_merlons(e[0], e[1], FT_TILE, snow, em.x >= mid.x - up.x)
	# 막다른 끝: 칸 가운데 마구리 면
	if ends.size() == 1 and not leak_only and not no_cap:
		var c0: Vector2 = L[nseg]
		var c1: Vector2 = R[nseg]
		var midc := (c0 + c1) * 0.5
		var tipv: Vector2 = midc - (L[nseg - 1] + R[nseg - 1]) * 0.5
		if tipv.y > 0.0:
			_draw_stone_face(c1 + _wskirt(Ruv[nseg], hh[nseg]), c0 + _wskirt(Luv[nseg], hh[nseg]), c0 - up, c1 - up, FT_STONE_D, FT_MORTAR, rows, 1)
		draw_line(c0 - up, c1 - up, FT_OUT, 0.9)

## 여장(성가퀴) — 상판 모서리 t1→t2를 따라 이빨 모양 총안을 규칙적으로 배치한다.
func _draw_wall_merlons(t1: Vector2, t2: Vector2, _col: Color, snow: bool = false, lit: bool = true) -> void:
	# PORT-TRACE [성곽 새 단장]: 검은 네모 대신 — 회색 전돌로 쌓은 낮은 담(여장)을 타(垜)마다 끊고, 위에 기와 지붕돌, 가운데 총안
	var L := t1.distance_to(t2)
	var n := maxi(1, int(round(L / 8.0)))
	var h := 5.0
	var hv := Vector2(0, h)
	var face := FT_BRICK if lit else FT_BRICK_D
	for k in range(n):
		var gap := 0.11
		var s0 := t1.lerp(t2, (float(k) + gap) / float(n))
		var s1 := t1.lerp(t2, (float(k) + 1.0 - gap) / float(n))
		var q := PackedVector2Array([s0, s1, s1 - hv, s0 - hv])
		FastDraw.poly(self, q, face)
		draw_line(s0 - hv * 0.5, s1 - hv * 0.5, face.darkened(0.15), 0.5) # 전돌 줄
		var mid := (s0 + s1) * 0.5 - hv * 0.55
		draw_rect(Rect2(mid - Vector2(0.6, 0.9), Vector2(1.2, 1.8)), FT_DARK) # 총안
		FastDraw.polyline(self, PackedVector2Array([s1 - hv, s1, s0, s0 - hv]), FT_OUT, 0.7)
		# 지붕돌(기와)
		var cap0 := s0 - hv - Vector2(0.6, 0.4)
		var cap1 := s1 - hv + Vector2(0.6, -0.4)
		draw_line(cap0, cap1, Color("eef2f5") if snow else FT_TILE, 2.0)
		draw_line(cap0 - Vector2(0, 1.0), cap1 - Vector2(0, 1.0), Color("ffffff") if snow else FT_TILE_HI, 0.6)

## PORT-TRACE [대각선 연결]: 허브 모서리(start)에서 대각 이웃과 공유하는 꼭짓점(corner)까지
## 뻗는 팔. 두께는 정방향 팔과 같게(모서리 벡터 edge_vec × k), 방향은 진행 방향에 수직.
## 대각 이웃도 같은 꼭짓점에서 반대쪽 팔을 뻗으므로 꼭짓점에서 서로 만난다.
func _draw_wall_diag(start: Vector2, corner: Vector2, wh: float, k: float, edge_vec: Vector2, col_light: Color, col_dark: Color, col_top: Color, col_mortar: Color, col_battle: Color, merlons_on: bool = true) -> void:
	var dir := (corner - start).normalized()
	var half := edge_vec.length() * k
	var w := Vector2(-dir.y, dir.x) * half
	var arm := PackedVector2Array([start - w, corner - w, corner + w, start + w])
	var sides: Array[bool] = [true, false, true, false]
	var merl: Array[bool] = [false, false, false, false]
	if merlons_on:
		merl = sides
	_draw_wall_block(arm, sides, merl, wh, col_light, col_dark, col_top, col_mortar, col_battle)
	if not merlons_on:
		_draw_scaffold(arm, wh)

## ─────────────────────────────────────────────────────────────── 4대문
## PORT-TRACE [4대문 재설계 — 옹성은 성 밖으로, 4방향 뷰]: 사용자 요청 "옹성이 성 바깥을
## 향하게, 안쪽은 없어야 한다, 대각선 뷰 4방향 모두". 예전 구현은 옹성 방향을 화면상 고정
## 방향(좌하단)으로 잡아서, 문이 성의 어느 쪽에 있든/화면을 어떻게 돌리든 늘 같은 쪽으로
## 튀어나왔고 문루도 정면도 그림이라 돌려도 안 바뀌었다. 이제는
## (1) 그리드 데이터로 "성 밖" 모서리를 찾고(_gate_outward_edge),
## (2) 그 모서리의 실제 꼭짓점(회전이 이미 반영됨)에서 두 축 a(성벽 방향 반벡터)와
##     f(타일 중심→바깥 모서리 중점)를 뽑아 모든 부재를 P(u,v) = a*u + f*v 로 배치한다.
## 그래서 4방향 회전 모두에서 옹성은 항상 성 밖, 육축·문루는 성벽 선 위에 놓이고, 문루 지붕도
## 실제 입체(우진각 4면)로 그려져 보는 방향에 따라 제대로 돌아 보인다.
## 좌표는 타일 중심 기준 상대값이다(_draw_tile에서 draw_set_transform으로 확대 적용).

const GATE_EDGE_DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const GATE_ONG_SEG := 14
## PORT-TRACE [문 통과]: 사람(키 약 30px, 말 탄 사람 약 45px)이 홍예 아래로 지나가도록 육축·홍예를 키웠다(값은 확대 전 기준)
const GATE_V := 0.45
const GATE_H1 := 34.0
const GATE_ARCH_W := 0.3   # 홍예 반폭(성벽 방향 반벡터 a의 배수)
const GATE_ARCH_H := 18.0  # 홍예 곧은 부분 높이
const GATE_ARCH_R := 10.0  # 홍예 둥근 머리 높이
const GATE_ONG_H := 24.0
const GATE_ONG_ARCH_W := 9.0
const GATE_ONG_ARCH_H := 11.0
const GATE_ONG_ARCH_R := 8.0

## 성 밖을 향한 모서리 번호(0=N,1=E,2=S,3=W). 성벽이 지나가는 축에 수직인 두 방향 중
## "outside" 지형(또는 지도 밖)이 더 많은 쪽을 고른다. 동률이면 지도 중심에서 멀어지는 쪽.
func _gate_outward_edge(x: int, y: int) -> int:
	var along_x := grid.is_wall_connector(x + 1, y) or grid.is_wall_connector(x - 1, y)
	var along_y := grid.is_wall_connector(x, y - 1) or grid.is_wall_connector(x, y + 1)
	var cands: Array[int] = [0, 1, 2, 3]
	if along_x and not along_y:
		cands = [0, 2] # 성벽이 동서로 지나가면 문은 남북을 향한다
	elif along_y and not along_x:
		cands = [1, 3]
	var center := Vector2(grid.size, grid.size) * 0.5
	var here := Vector2(x, y)
	var best: int = cands[0]
	var best_score: float = -INF
	for e: int in cands:
		var d: Vector2i = GATE_EDGE_DIRS[e]
		var score := 0.0
		for step in range(1, 5):
			var nx := x + d.x * step
			var ny := y + d.y * step
			if not grid.in_bounds(nx, ny) or grid.tile(nx, ny)["terrain"] == "outside":
				score += 1.0
		score += 0.01 * ((here + Vector2(d)) - center).length() - 0.01 * (here - center).length()
		if score > best_score:
			best_score = score
			best = e
	return best

## 문별 고증 파라미터. ru/rv=옹성 반지름(성벽 방향/바깥 방향, 반칸 단위), th0~th1=옹성 호의
## 범위(0~π면 완전한 반원, 일부만이면 한쪽이 열린 옹성), ong_gate=옹성 정면 홍예문 여부.
func _gate_spec(gate_name: String) -> Dictionary:
	if gate_name.begins_with("장안문"): # 정문(북문): 반원 대옹성, 정면 옹성문, 중층 문루
		return {"tiers": 2, "ong": true, "ru": 1.05, "rv": 1.35, "th0": 0.0, "th1": PI, "ong_gate": true, "flags": true}
	if gate_name.begins_with("팔달문"): # 남문: 가장 크고 깊은 옹성, 중층 문루
		return {"tiers": 2, "ong": true, "ru": 1.15, "rv": 1.55, "th0": 0.0, "th1": PI, "ong_gate": true, "flags": true}
	if gate_name.begins_with("화서문"): # 서문: 한쪽이 열린 작은 반원 옹성, 단층 문루
		return {"tiers": 1, "ong": true, "ru": 0.9, "rv": 1.15, "th0": 0.0, "th1": PI * 0.72, "ong_gate": false, "flags": false}
	if gate_name.begins_with("창룡문"): # 동문: 반대쪽이 열린 반원 옹성, 단층 문루
		return {"tiers": 1, "ong": true, "ru": 0.95, "rv": 1.2, "th0": PI * 0.28, "th1": PI, "ong_gate": false, "flags": true}
	# 이름 없는 문(암문 등): 옹성 없이 육축+문루만
	return {"tiers": 2, "ong": false, "ru": 0.0, "rv": 0.0, "th0": 0.0, "th1": PI, "ong_gate": false, "flags": false}

## PORT-TRACE [4대문 웅장화]: 문화재적 위상에 맞춘 확대 배율(그리드는 1칸 그대로).
func _gate_visual_scale(gate_name: String) -> float:
	if gate_name.begins_with("장안문") or gate_name.begins_with("팔달문"):
		return 1.7
	if gate_name.begins_with("창룡문"):
		return 1.6
	if gate_name.begins_with("화서문"):
		return 1.6
	return 1.35 # 암문 등 이름 없는 문도 사람이 지날 만큼

## a: 성벽 방향 반벡터, f: 중심→성 밖 모서리 중점. 옹성이 화면 뒤쪽이면 먼저, 앞쪽이면 나중에
## 그려서 서로 올바르게 가린다.
## frac: 공사 진척(0~1, 1=완공). 공사 중엔 육축·옹성이 단계별로 올라가고 문루·깃발·여장은
## 완공 때 올라간다. 마지막 단계에선 문루의 나무 골조(기둥·보)만 먼저 선다.
## PORT-TRACE [성문 옆면 감춤]: 성벽이 이어진 쪽(육축 끝면)은 그리지 않는다 — 그 자리는 육축 높이·두께까지 키운 성벽이 채운다.
## [+a 쪽, -a 쪽]. +a는 성 밖 모서리 o의 다음 꼭짓점 쪽: o=0 → +x, 1 → +y, 2 → -x, 3 → -y
var _gate_join: Array[bool] = [false, false]
func _gate_join_flags(x: int, y: int, o: int) -> Array[bool]:
	var pd: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	var d: Vector2i = pd[clampi(o, 0, 3)]
	var res: Array[bool] = [false, false]
	for k in range(2):
		var q: Vector2i = Vector2i(x, y) + (d if k == 0 else -d)
		if grid.in_bounds(q.x, q.y) and String(grid.grid[q.y][q.x]["building"]) == "wall":
			var ends: Array[Vector2] = []
			# 그 칸 성벽이 곧게 이어져 육축에 붙는가(_gate_ramp가 잘라 붙이는 경우만)
			var emid: Array[Vector2] = [Vector2(0.5, 0.0), Vector2(1.0, 0.5), Vector2(0.5, 1.0), Vector2(0.0, 0.5)]
			var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
			for i in range(4):
				if _wconn(q.x, q.y, q.x + dirs[i].x, q.y + dirs[i].y):
					ends.append(emid[i])
			res[k] = bool(_gate_ramp(q.x, q.y, ends).get("trim", false))
		if not res[k] and _gate_diag_wall(x, y, o, k).x >= 0:
			res[k] = true # 대각으로 붙는 성벽은 _draw_gate_diag_links가 끝면을 감싸 잇는다
	return res

## 성문 축 방향 k(0=+a, 1=-a) 바로 옆 칸이 성벽이 아니고, 그 칸 옆(대각)에 성벽이 붙어 있으면 그 성벽 칸
func _gate_diag_wall(x: int, y: int, o: int, k: int) -> Vector2i:
	var pd: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	var ax: Vector2i = pd[clampi(o, 0, 3)] * (1 if k == 0 else -1)
	var t1: Vector2i = Vector2i(x, y) + ax
	if not grid.in_bounds(t1.x, t1.y) or grid.is_wall_connector(t1.x, t1.y):
		return Vector2i(-1, -1)
	for pp: Vector2i in [Vector2i(-ax.y, ax.x), Vector2i(ax.y, -ax.x)]:
		var w: Vector2i = t1 + pp
		if grid.in_bounds(w.x, w.y) and String(grid.grid[w.y][w.x]["building"]) == "wall":
			return w
	return Vector2i(-1, -1)

## PORT-TRACE [성문 대각 이음]: 성벽이 성문 모서리에 대각선으로 닿는 쪽 — 그 꼭짓점에서 성벽이 육축 끝 너머로 휘어 돌아
## 육축 높이·두께까지 높아지며 끝면에 붙는다(끝면은 그리지 않음). 성문을 그린 뒤 그 위에 그린다.
func _draw_gate_diag_links(x: int, y: int, o: int) -> void:
	var pd: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	var gname := String(grid.grid[y][x].get("gate_name", ""))
	var sc := _gate_visual_scale(gname)
	var frac := grid.wall_build_fraction(grid.grid[y][x])
	var gce: Array = grid.grid[y][x].get("corner_elev", [1.0, 1.0, 1.0, 1.0])
	var gel := (float(gce[0]) + float(gce[1]) + float(gce[2]) + float(gce[3])) * 0.25
	for k in range(2):
		var w := _gate_diag_wall(x, y, o, k)
		if w.x < 0:
			continue
		var ax := Vector2(pd[clampi(o, 0, 3)] * (1 if k == 0 else -1))
		var gc := Vector2(x, y) + Vector2(0.5, 0.5)
		var reach := 1.25 * sc * 0.5 # 육축 끝면까지(칸)
		var p1 := gc + ax * reach                 # 육축 끝면 가운데
		var p0 := (gc + Vector2(w) + Vector2(0.5, 0.5)) * 0.5 # 성문 칸과 대각 성벽 칸이 맞닿는 꼭짓점
		var cq := p1 + ax * 0.5                   # 끝 너머로 돌아 들어오는 조절점
		var wt: Dictionary = grid.grid[w.y][w.x]
		var kc := _tile_corners(w.x, w.y)
		_wall_frame(wt, kc[0], kc[1], kc[2], kc[3])
		var wo := Vector2(w)
		var h0 := _wend_h(p0 - wo)
		_draw_wall_link(p0 - wo, cq - wo, p1 - wo, h0, gel, WALL_HEIGHT * grid.wall_build_fraction(wt), GATE_H1 * sc * frac, WALL_THICK_K, GATE_V * sc * 0.5)

## 이음 성벽 띠: 2차 곡선 a→(c)→b를 따라 높이·두께를 차츰 바꾸며(양 끝 막음 면 없음)
func _draw_wall_link(a: Vector2, cc: Vector2, b: Vector2, h0: float, h1: float, wh0: float, wh1: float, hw0: float, hw1: float) -> void:
	var nseg := 10
	var L: Array[Vector2] = []
	var R: Array[Vector2] = []
	var ups: Array[Vector2] = []
	for i in range(nseg + 1):
		var t := float(i) / float(nseg)
		var pt := a * (1.0 - t) * (1.0 - t) + cc * 2.0 * (1.0 - t) * t + b * t * t
		var tv := ((cc - a) * 2.0 * (1.0 - t) + (b - cc) * 2.0 * t).normalized()
		var kk := smoothstep(0.0, 1.0, t)
		var nv := Vector2(-tv.y, tv.x) * lerpf(hw0, hw1, kk)
		var hh := lerpf(h0, h1, t)
		L.append(_wp(pt + nv, hh) + _wskirt(pt + nv, hh))
		R.append(_wp(pt - nv, hh) + _wskirt(pt - nv, hh))
		# 윗면 높이: 성문 칸 높이 기준 육축 윗면까지
		ups.append(Vector2(0, lerpf(wh0, wh1 + (h1 - hh) * ELEV_STEP, kk) + _wskirt(pt, hh).y))
	var snow: bool = (band_master.current_season if band_master else current_season) == "겨울"
	var top_col: Color = Color("e4e9ee") if snow else FT_WALK
	var segs: Array[int] = []
	for i in range(nseg):
		segs.append(i)
	segs.sort_custom(func(i: int, j: int) -> bool: return (L[i] + R[i + 1]).y < (L[j] + R[j + 1]).y)
	for i in segs:
		var mid := (L[i] + L[i + 1] + R[i] + R[i + 1]) * 0.25
		for side in range(2):
			var e0: Vector2 = L[i] if side == 0 else R[i + 1]
			var e1: Vector2 = L[i + 1] if side == 0 else R[i]
			var u0: Vector2 = ups[i] if side == 0 else ups[i + 1]
			var u1: Vector2 = ups[i + 1] if side == 0 else ups[i]
			var outv := (e0 + e1) * 0.5 - mid
			if outv.y <= 0.0:
				continue
			_draw_stone_face(e0, e1, e1 - u1, e0 - u0, FT_STONE if outv.x >= 0.0 else FT_STONE_D, FT_MORTAR, maxi(2, int(u0.y / 7.0)), maxi(1, int(round(e0.distance_to(e1) / 7.0))))
		var topq := PackedVector2Array([L[i] - ups[i], L[i + 1] - ups[i + 1], R[i + 1] - ups[i + 1], R[i] - ups[i]])
		FastDraw.poly(self, topq, top_col)
		draw_line(L[i] - ups[i], L[i + 1] - ups[i + 1], FT_OUT, 0.9)
		draw_line(R[i] - ups[i], R[i + 1] - ups[i + 1], FT_OUT, 0.9)
		for e: Array in [[L[i] - ups[i], L[i + 1] - ups[i + 1]], [R[i] - ups[i], R[i + 1] - ups[i + 1]]]:
			var em: Vector2 = ((e[0] as Vector2) + (e[1] as Vector2)) * 0.5
			_draw_wall_merlons(e[0], e[1], FT_TILE, snow, em.x >= mid.x)

func _draw_gate(a: Vector2, f: Vector2, gate_name: String, frac: float = 1.0) -> void:
	var sp := _gate_spec(gate_name)
	var U := 1.25   # 육축 길이(성벽 방향, 반칸 단위)
	var V := GATE_V   # 육축 두께(성 안↔밖 방향)
	var H1 := GATE_H1 * frac  # 육축 높이(px) — PORT-TRACE [문 통과]: 사람이 홍예 아래로 지나가도록 키움(22 → 34)
	var has_ong: bool = sp["ong"]
	var ong_behind := has_ong and (f * (V + float(sp["rv"]) * 0.6)).y < 0.0
	if ong_behind:
		_draw_gate_ongseong(a, f, V, sp, frac)
	_draw_gate_body(a, f, U, V, H1, sp, gate_name, frac)
	if has_ong and not ong_behind:
		_draw_gate_ongseong(a, f, V, sp, frac)

## 육축(홍예문이 뚫린 거대한 석축) + 문루 + 깃발 + 이름표
func _draw_gate_body(a: Vector2, f: Vector2, U: float, V: float, H1: float, sp: Dictionary, _gate_name: String, frac: float = 1.0) -> void:
	var done := frac >= 1.0
	var up := Vector2(0, H1)
	# 변 0: 성 안쪽 면(v=-V), 1: 끝면(u=+U), 2: 성 밖 면(v=+V), 3: 끝면(u=-U)
	var g: Array[Vector2] = [a * -U + f * -V, a * U + f * -V, a * U + f * V, a * -U + f * V]
	var order: Array[int] = [0, 1, 2, 3]
	order.sort_custom(func(i: int, j: int): return (g[i] + g[(i + 1) % 4]).y < (g[j] + g[(j + 1) % 4]).y)
	for i in order:
		if (i == 1 and _gate_join[0]) or (i == 3 and _gate_join[1]):
			continue # 성벽이 붙는 끝면
		var p0: Vector2 = g[i]
		var p1: Vector2 = g[(i + 1) % 4]
		var col := FT_STONE if (p0 + p1).x >= 0.0 else FT_STONE_D
		_draw_stone_face(p0, p1, p1 - up, p0 - up, col, FT_MORTAR, 5, 7 if i % 2 == 0 else 2)
		# 홍예문은 성 안·밖 양쪽 면에 뚫려 있다(통로). 무지개 틀(홍예)을 다 틀기 전엔 네모난 통로만.
		var arch_h := GATE_ARCH_H if frac >= 0.6 else H1 * 0.85
		var arch_r := GATE_ARCH_R if frac >= 0.6 else 0.0
		if i == 0:
			_draw_gate_arch(f * -V, a * GATE_ARCH_W, arch_h, arch_r)
		elif i == 2:
			_draw_gate_arch(f * V, a * GATE_ARCH_W, arch_h, arch_r)
	var topq := PackedVector2Array([g[0] - up, g[1] - up, g[2] - up, g[3] - up])
	FastDraw.poly(self, topq, FT_WALK if done else Color("a89c84"))
	FastDraw.polyline(self, PackedVector2Array([topq[0], topq[1], topq[2], topq[3], topq[0]]), FT_OUT, 0.9)

	if not done:
		# 공사 중: 육축 둘레 비계, 마지막 단계엔 문루 나무 골조, 옆엔 성돌 더미
		_draw_scaffold(PackedVector2Array(g), H1)
		if frac >= 0.7:
			var wood := Color("8a6a42")
			for uu: float in [-0.85, -0.42, 0.0, 0.42, 0.85]:
				for vv: float in [-0.3, 0.3]:
					var pb := a * uu + f * vv - up
					draw_line(pb, pb - Vector2(0, 11.0), wood, 1.4)
			for vv: float in [-0.3, 0.3]:
				draw_line(a * -0.85 + f * vv - up - Vector2(0, 11.0), a * 0.85 + f * vv - up - Vector2(0, 11.0), wood, 1.6)
		_draw_stone_pile(a * 1.6 + f * 0.6)
		return

	# 육축 위 여장(문루가 서는 가운데는 비운다): 화면 뒤쪽 줄부터
	var snow: bool = (band_master.current_season if band_master else current_season) == "겨울"
	var vs: Array[float] = [-V, V]
	vs.sort_custom(func(p: float, q: float): return (f * p).y < (f * q).y)
	for vv2: float in vs:
		for seg: Array in [[-U, -0.9], [0.9, U]]:
			_draw_wall_merlons(a * float(seg[0]) + f * vv2 - up, a * float(seg[1]) + f * vv2 - up, FT_TILE, snow, (f * vv2).x >= 0.0)

	# 성 안쪽 면(v = -V) 등성계단 (육축 상부 문루로 오르는 좌우 석계단)
	for uu: float in [-1.12, 1.12]:
		var stair_bot: Vector2 = a * uu + f * -V
		var stair_top: Vector2 = a * (uu * 0.72) + f * (-V * 0.95) - up
		draw_line(stair_bot, stair_top, FT_OUT, 2.6)
		draw_line(stair_bot - Vector2(0, 1.2), stair_top - Vector2(0, 1.2), FT_STONE, 1.6)

	var _top_h := _draw_gate_pavilion_iso(a, f, H1, int(sp["tiers"]))

	if sp["flags"]:
		var flag_cols: Array[Color] = [Color("c0392b"), Color("e8b820"), Color("1a5276"), Color("1e8449")]
		var cam_side := 1.0 if f.y > 0.0 else -1.0 # 카메라 쪽 가장자리에 세워 문루에 가리지 않게
		var idx := 0
		for uu: float in [-1.15, 1.15]:
			var base := a * uu + f * (V * 0.6 * cam_side) - up
			var tip := base - Vector2(0, 22.0)
			draw_line(base, tip, FT_OUT, 1.6)
			draw_line(base, tip, Color("6e4a2c"), 0.9)
			var sx := 1.0 if uu > 0.0 else -1.0
			var fl := PackedVector2Array([tip, tip + Vector2(sx * 9.0, 3.0), tip + Vector2(0, 6.0)])
			FastDraw.poly(self, fl, flag_cols[idx % 4])
			FastDraw.polyline(self, PackedVector2Array([fl[0], fl[1], fl[2]]), FT_OUT, 0.6)
			idx += 1

## [단일화 픽스] 현판 표시는 WorldMarkerManager 노드 인스턴스화 방식 1곳으로 단일화됨 (이중 출력 방지)
func _draw_gate_name_tag(_gate_name: String, _height: float) -> void:
	return


## 홍예 아치: base=면 바닥 중앙, along=면 방향 반폭 벡터(원근 기울기를 그대로 따름)
func _draw_gate_arch(base: Vector2, along: Vector2, h_rect: float, r: float) -> void:
	# PORT-TRACE [성곽 새 단장]: 어두운 문 안 + 밝은 홍예석 테두리(돌 마디) + 외곽선
	var seg := 10
	var pts := PackedVector2Array([base - along, base + along])
	for k in range(seg + 1):
		var ang := PI * float(k) / float(seg)
		pts.append(base + along * cos(ang) - Vector2(0, h_rect + r * sin(ang)))
	FastDraw.poly(self, pts, FT_DARK)
	# 문 안 바닥 쪽으로 갈수록 살짝 밝게(통로 너머 빛)
	draw_line(base - along * 0.8 - Vector2(0, 0.8), base + along * 0.8 - Vector2(0, 0.8), Color("4a3c30"), 1.2)
	var rim := PackedVector2Array()
	var rim_o := PackedVector2Array()
	for k in range(seg + 1):
		var ang2 := PI * float(k) / float(seg)
		rim.append(base + along * 1.12 * cos(ang2) - Vector2(0, h_rect + (r + 1.2) * sin(ang2)))
		rim_o.append(base + along * 1.26 * cos(ang2) - Vector2(0, h_rect + (r + 2.6) * sin(ang2)))
	FastDraw.polyline(self, rim, Color("ddd4c0"), 2.0)
	FastDraw.polyline(self, rim_o, FT_OUT, 0.8)
	for k in range(1, seg, 2): # 홍예석 마디
		draw_line(rim[k].lerp(base - Vector2(0, h_rect), 0.04), rim_o[k], FT_MORTAR, 0.6)
	# 문설주(곧은 옆 기둥돌)
	if h_rect > 0.5:
		for sgn: float in [-1.0, 1.0]:
			var jb := base + along * 1.12 * sgn
			draw_line(jb, jb - Vector2(0, h_rect), Color("ddd4c0"), 1.6)
	FastDraw.polyline(self, pts, FT_OUT, 0.8)

## 입체 문루: 1층 몸체 + 우진각 지붕, tiers=2면 2층 몸체 + 지붕을 한 번 더. 가장 높은 지점(px)을 반환.
func _draw_gate_pavilion_iso(a: Vector2, f: Vector2, h0: float, tiers: int) -> float:
	_draw_gate_pav_body(a, f, 0.85, 0.3, h0, h0 + 11.0)
	_draw_gate_hip_roof(a, f, 1.12, 0.56, 0.6, h0 + 10.0, h0 + 20.0)
	var top := h0 + 20.0
	var plaque_v := 0.3
	var plaque_h := h0 + 6.0
	if tiers >= 2:
		_draw_gate_pav_body(a, f, 0.55, 0.2, h0 + 16.0, h0 + 25.0)
		_draw_gate_hip_roof(a, f, 0.82, 0.4, 0.42, h0 + 24.0, h0 + 33.0)
		top = h0 + 33.0
		plaque_v = 0.2
		plaque_h = h0 + 21.0
	# 현판: 카메라를 향한 긴 면 한가운데
	var fs := 1.0 if f.y > 0.0 else -1.0
	var pc := f * (plaque_v * fs) - Vector2(0, plaque_h)
	var hw := a * 0.22
	FastDraw.poly(self, PackedVector2Array([
		pc - hw - Vector2(0, 2.2), pc + hw - Vector2(0, 2.2), pc + hw + Vector2(0, 2.2), pc - hw + Vector2(0, 2.2)
	]), Color("0f0f12"))
	draw_line(pc - hw * 0.8, pc + hw * 0.8, Color("e8b820"), 1.4)
	return top

## 문루 몸체(붉은 기둥 + 창방 단청 띠). bu/bv=반폭, h0~h1=높이 구간
func _draw_gate_pav_body(a: Vector2, f: Vector2, bu: float, bv: float, h0: float, h1: float) -> void:
	# PORT-TRACE [성곽 새 단장]: 어두운 마루 안 + 붉은 기둥 + 창방 단청(녹·적) + 외곽선 — 둘레 PNG 전각과 같은 차림
	var g: Array[Vector2] = [a * -bu + f * -bv, a * bu + f * -bv, a * bu + f * bv, a * -bu + f * bv]
	var lo := Vector2(0, h0)
	var hi := Vector2(0, h1)
	var floorq := PackedVector2Array([g[0] - lo, g[1] - lo, g[2] - lo, g[3] - lo])
	FastDraw.poly(self, floorq, Color("8a6a48")) # 마루
	var order: Array[int] = [0, 1, 2, 3]
	order.sort_custom(func(i: int, j: int): return (g[i] + g[(i + 1) % 4]).y < (g[j] + g[(j + 1) % 4]).y)
	for i in order:
		var p0: Vector2 = g[i] - lo
		var p1: Vector2 = g[(i + 1) % 4] - lo
		var q0: Vector2 = g[i] - hi
		var q1: Vector2 = g[(i + 1) % 4] - hi
		var lit := (g[i] + g[(i + 1) % 4]).x >= 0.0
		FastDraw.poly(self, PackedVector2Array([p0, p1, q1, q0]), Color("4a3428") if lit else Color("3a281f")) # 트인 마루 안 그늘
		var npil := 5 if i % 2 == 0 else 3
		for kk in range(npil):
			var tt := float(kk) / float(npil - 1)
			var pb := p0.lerp(p1, tt)
			var pt := q0.lerp(q1, tt)
			draw_line(pb, pt, FT_OUT, 2.6)
			draw_line(pb, pt, FT_RED if lit else FT_RED_D, 1.6)
		# 난간(계자난간 한 줄)
		draw_line(p0 - Vector2(0, 2.5), p1 - Vector2(0, 2.5), Color("6e4a2c"), 1.0)
		# 창방 단청: 녹색 띠 + 붉은 줄
		FastDraw.poly(self, PackedVector2Array([q0, q1, q1 + Vector2(0, 2.6), q0 + Vector2(0, 2.6)]), FT_GREEN if lit else FT_GREEN.darkened(0.2))
		draw_line(q0 + Vector2(0, 2.8), q1 + Vector2(0, 2.8), FT_RED, 0.8)
		draw_line(p0, p1, FT_OUT, 0.9)

## 우진각 지붕: 처마 사각형(ru×rv, 높이 h_eave)에서 용마루(±ridge_u, 높이 h_ridge)로 4면.
## 화면 뒤쪽을 향한 면부터 그리고, 각 면 밝기는 향하는 방향으로 정해 회전해도 입체감이 유지된다.
func _draw_gate_hip_roof(a: Vector2, f: Vector2, ru: float, rv: float, ridge_u: float, h_eave: float, h_ridge: float) -> void:
	# PORT-TRACE [성곽 새 단장]: 기왓골(처마→용마루 줄) + 처마 끝 살짝 치솟음 + 흰 마루 + 외곽선
	var snow: bool = (band_master.current_season if band_master else current_season) == "겨울"
	var eu := Vector2(0, h_eave)
	var e: Array[Vector2] = [
		a * -ru + f * -rv - eu, a * ru + f * -rv - eu, a * ru + f * rv - eu, a * -ru + f * rv - eu
	]
	var cen := -eu
	for i in range(4): # 네 귀가 바깥·위로 살짝 들림(앙곡)
		e[i] = e[i] + (e[i] - cen).normalized() * 1.5 - Vector2(0, 2.0)
	var r0 := a * -ridge_u - Vector2(0, h_ridge)
	var r1 := a * ridge_u - Vector2(0, h_ridge)
	var planes: Array = [
		{"pts": PackedVector2Array([e[0], e[1], r1, r0]), "dir": -f, "eave": [e[0], e[1]], "top": [r0, r1]},
		{"pts": PackedVector2Array([e[1], e[2], r1]), "dir": a, "eave": [e[1], e[2]], "top": [r1, r1]},
		{"pts": PackedVector2Array([e[2], e[3], r0, r1]), "dir": f, "eave": [e[2], e[3]], "top": [r1, r0]},
		{"pts": PackedVector2Array([e[3], e[0], r0]), "dir": -a, "eave": [e[3], e[0]], "top": [r0, r0]},
	]
	planes.sort_custom(func(p, q): return (p["dir"] as Vector2).y < (q["dir"] as Vector2).y)
	var base_col: Color = Color("e3e9ef") if snow else FT_TILE
	for pl in planes:
		var n: Vector2 = (pl["dir"] as Vector2).normalized()
		var shade: float = 0.2 * n.y + 0.1 * n.x
		var col: Color = base_col.lightened(shade) if shade > 0.0 else base_col.darkened(-shade)
		FastDraw.poly(self, pl["pts"], col)
		var ea: Vector2 = pl["eave"][0]
		var eb: Vector2 = pl["eave"][1]
		var ta: Vector2 = pl["top"][0]
		var tb: Vector2 = pl["top"][1]
		var nl := maxi(3, int(ea.distance_to(eb) / 3.0))
		for k in range(1, nl):
			var tt := float(k) / float(nl)
			draw_line(ea.lerp(eb, tt), ta.lerp(tb, tt), col.darkened(0.22) if not snow else Color("c8d2dc"), 0.6) # 기왓골
		if n.y > 0.0: # 앞쪽 처마: 막새 줄 + 처마 아래 그늘
			draw_line(ea + Vector2(0, 1.0), eb + Vector2(0, 1.0), Color("1c1f24"), 1.6)
			draw_line(ea, eb, col.lightened(0.25), 0.8)
		FastDraw.polyline(self, PackedVector2Array(Array(pl["pts"]) + [pl["pts"][0]]), FT_OUT, 0.9)
	var ridge_c := Color("ffffff") if snow else FT_RIDGE
	for i in range(4):
		draw_line(e[i], r0 if i == 0 or i == 3 else r1, ridge_c, 1.3) # 추녀마루
	draw_line(r0, r1, FT_OUT, 3.4)
	draw_line(r0, r1, ridge_c, 2.0) # 용마루
	for rp: Vector2 in [r0, r1]: # 취두
		FastDraw.circle(self, rp - Vector2(0, 1.6), 1.8, FT_OUT)
		FastDraw.circle(self, rp - Vector2(0, 1.8), 1.0, FT_TILE_HI)

## 옹성(甕城): 육축의 성 밖 면(v=+V)에서 바깥으로 둥글게 감싸는 성벽. 호를 짧은 성벽 블록으로
## 나눠 화면 깊이순으로 그린다(성곽과 같은 _draw_wall_block 사용 → 돌 질감·여장 통일).
func _draw_gate_ongseong(a: Vector2, f: Vector2, V: float, sp: Dictionary, frac: float = 1.0) -> void:
	var done := frac >= 1.0
	var ru: float = sp["ru"]
	var rv: float = sp["rv"]
	var th0: float = sp["th0"]
	var th1: float = sp["th1"]
	var k_in := 0.78 # 안쪽 호 비율 → 옹성 벽 두께
	var seg := GATE_ONG_SEG
	var outer: Array[Vector2] = []
	var inner: Array[Vector2] = []
	for i in range(seg + 1):
		var th := lerpf(th0, th1, float(i) / float(seg))
		outer.append(a * (ru * cos(th)) + f * (V + rv * sin(th)))
		inner.append(a * (ru * k_in * cos(th)) + f * (V + rv * k_in * sin(th)))

	# 옹성 안마당 박석(삼각 팬 — 오목한 다각형 삼각분할 실패를 피한다)
	var hub := f * V
	for i in range(seg):
		FastDraw.poly(self, PackedVector2Array([hub, inner[i], inner[i + 1]]), Color("b3a98f"))

	var H2 := GATE_ONG_H * frac
	var blocks: Array = []
	for i in range(seg):
		var gq := PackedVector2Array([outer[i], outer[i + 1], inner[i + 1], inner[i]])
		# 바깥면·안쪽면은 항상, 호의 끝은 "열린 옹성"일 때만 마감면을 세운다(닫힌 끝은 육축에 붙음)
		var faces: Array[bool] = [true, i == seg - 1 and th1 < PI - 0.01, true, i == 0 and th0 > 0.01]
		var merl: Array[bool] = [done and i % 2 == 0, false, false, false]
		blocks.append({"g": gq, "faces": faces, "merl": merl, "cy": (outer[i] + inner[i + 1]).y * 0.5, "i": i})
	blocks.sort_custom(func(p, q): return p["cy"] < q["cy"])

	# 옹성 정면 홍예문: 가운데 두 블록을 다 그린 직후에 그려야 뒤 블록엔 덮이지 않고 앞 블록엔
	# 가려진다. 바깥면이 카메라 반대쪽이면 원래 안 보이므로 그리지 않는다.
	var mid_a: int = int(float(seg) / 2.0) - 1
	var mid_b: int = int(float(seg) / 2.0)
	var mids := 0
	var show_gate: bool = sp["ong_gate"] and f.y > 0.0 and done
	var top_col := FT_WALK if done else Color("a89c84")
	for bk in blocks:
		_draw_wall_block(bk["g"], bk["faces"], bk["merl"], H2, FT_STONE, FT_STONE_D, top_col, FT_MORTAR, FT_TILE)
		if show_gate and (bk["i"] == mid_a or bk["i"] == mid_b):
			mids += 1
			if mids == 2:
				var th_m := (th0 + th1) * 0.5
				var base := a * (ru * cos(th_m)) + f * (V + rv * sin(th_m))
				var tang := a * (-ru * sin(th_m)) + f * (rv * cos(th_m))
				_draw_gate_arch(base, tang.normalized() * GATE_ONG_ARCH_W, GATE_ONG_ARCH_H, GATE_ONG_ARCH_R)

## PORT-TRACE [화홍문·남수문 다칸화]: 사용자 요청 — "성곽을 수원천 위로 만들면 화홍문이 하나의
## 건물로 3칸을 차지하며 만들어져야 한다". 예전엔 물 위 성곽 칸마다 누각까지 달린 작은 수문이
## 통째로 하나씩 그려져, 3칸 폭 하천을 건너면 수문 3개가 따로 서 있었다. 게다가 물 칸 꼭짓점은
## 하상 높이라 칸마다 상판이 물속으로 꺼졌다.
## 이제 물 위 성곽 칸은 모두 "석조 수문교 한 구간"이다:
## - 기준 높이를 평지 고도(1.0)로 잡아 상판이 강을 건너는 내내 수평을 유지하고, 강바닥까지는
##   교각(drop)으로 내려간다. 성곽과 같은 허브+팔 방식이라 양안 성곽과도 맞물린다.
## - 카메라 쪽 긴 면 수면 높이에 홍예 수문 아치.
## - 누각은 물 위 구간의 "가운데 칸" 하나에만 선다 → 여러 칸이 하나의 화홍문 건물로 보인다.
## PORT-TRACE [화홍문 중앙 정렬 및 4x1 규격 확장]:
## 기존 2x1 및 짝수 칸에서 좌측 칸 중심으로 문루가 치우치던 비대칭 버그를 해결.
## 하부 수문 석축 전체 폭의 기하학적 정중앙(피벗)을 기준으로 상부 목조 문루를 대칭으로 렌더링하고,
## 일곱 홍예(7련 아치)와 계단식 보 폭포수를 전체 폭에 맞춰 시원하게 연출한다.
func _draw_hwahongmun(x: int, y: int, t: Dictionary) -> void:
	var lvl := 1.0
	var q_n := cell_center(x, y, lvl)
	var q_e := cell_center(x + 1, y, lvl)
	var q_s := cell_center(x + 1, y + 1, lvl)
	var q_w := cell_center(x, y + 1, lvl)
	var cq := (q_n + q_e + q_s + q_w) * 0.25
	var ce: Array = t.get("corner_elev", [1.0, 1.0, 1.0, 1.0])
	var water_avg: float = (float(ce[0]) + float(ce[1]) + float(ce[2]) + float(ce[3])) / 4.0
	var drop: float = maxf(0.0, cell_center(x, y, water_avg).y - cell_center(x, y, lvl).y)
	var down := Vector2(0, drop)

	var wn := grid.is_wall_connector(x, y - 1)
	var we := grid.is_wall_connector(x + 1, y)
	var ws := grid.is_wall_connector(x, y + 1)
	var ww := grid.is_wall_connector(x - 1, y)
	var conn: Array[bool] = [wn, we, ws, ww]
	var along_x: bool = (we or ww) or not (wn or ws)
	var corners: Array[Vector2] = [q_n, q_e, q_s, q_w]
	var k := 0.34
	var frac := grid.wall_build_fraction(t)
	var done := frac >= 1.0
	var wh := WALL_HEIGHT * frac + drop

	var boxes: Array = []
	var hub := PackedVector2Array()
	for p: Vector2 in corners:
		hub.append(cq + (p - cq) * 2.0 * k + down)
	var hub_open: Array[bool] = [not wn, not we, not ws, not ww]
	boxes.append({"g": hub, "faces": hub_open, "cy": cq.y})
	for i in range(4):
		if not conn[i]:
			continue
		var a0: Vector2 = corners[i]
		var b0: Vector2 = corners[(i + 1) % 4]
		var m := (a0 + b0) * 0.5
		var w := (b0 - a0) * k
		var s := cq + (m - cq) * 2.0 * k
		var sides: Array[bool] = [true, false, true, false]
		boxes.append({"g": PackedVector2Array([s - w + down, m - w + down, m + w + down, s + w + down]), "faces": sides, "cy": (s.y + m.y) * 0.5})
	boxes.sort_custom(func(u, v): return u["cy"] < v["cy"])
	var no_merlon: Array[bool] = [false, false, false, false]
	for bx in boxes:
		var merl: Array = bx["faces"]
		if not done:
			merl = no_merlon
		_draw_wall_block(bx["g"], bx["faces"], merl, wh, FT_STONE, FT_STONE_D, FT_WALK if done else Color("a89c84"), FT_MORTAR, FT_TILE)
		if not done:
			_draw_scaffold(bx["g"], wh)
	if not done:
		return

	# 각 타일별 기본 아치/수문 배수
	var mid_n := (q_n + q_e) * 0.5
	var mid_e := (q_e + q_s) * 0.5
	var mid_s := (q_s + q_w) * 0.5
	var mid_w := (q_w + q_n) * 0.5
	var run_a: Vector2 = (mid_e - mid_w) * 0.5 if along_x else (mid_s - mid_n) * 0.5
	var side: Vector2 = (mid_s - mid_n) * 0.5 if along_x else (mid_e - mid_w) * 0.5
	var face_off: Vector2 = side * (2.0 * k)
	if face_off.y < 0.0:
		face_off = -face_off

	# 연속된 물 위 성곽(화홍문 구간) 정보 계산
	var span := _get_water_wall_span(x, y, along_x)
	var span_center: Vector2 = span["center_pivot"]
	
	# 수문 아치 렌더링 (각 타일에 2개씩 홍예 아치 배치)
	for u: float in [-0.5, 0.5]:
		var base := cq + run_a * u + face_off + down
		_draw_gate_arch(base, run_a.normalized() * 5.5, 2.0, 5.0)
		draw_line(base - run_a.normalized() * 5.0, base + run_a.normalized() * 5.0, Color(0.85, 0.93, 1.0, 0.8), 1.5)
		# 3단 계단식 보 폭포 포말 연출
		for step_i in range(3):
			var water_y := base + Vector2(0, 3.0 + step_i * 3.0)
			draw_line(water_y - run_a.normalized() * 4.0, water_y + run_a.normalized() * 4.0, Color(0.9, 0.96, 1.0, 0.7 - step_i * 0.15), 1.8)

	# 상부 목조 문루: 구간 전체 폭 기준 정중앙 피벗(Pivot)에 완벽 대칭으로 렌더링
	# 구간 내 화면 최전면(is_last) 타일에서 전체 중심에 딱 1회 안착
	if span["is_render_tile"]:
		draw_set_transform(span_center, 0.0, Vector2.ONE)
		# 전체 4칸 기준 문루 반폭 a, f
		var pav_a := run_a.normalized() * 26.0
		var pav_f := side.normalized() * 10.0
		_draw_hwahong_pavilion(pav_a, pav_f, WALL_HEIGHT)
		var hw_tag: String = "화홍문 (華虹門)"
		if t.has("wall_build") and t["wall_build"] > 0:
			hw_tag = "[축조 중] " + hw_tag
		# [단일화 픽스] 현판은 WorldMarkerManager 노드로 일원화됨
		# _draw_gate_name_tag(hw_tag, WALL_HEIGHT + 36.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 화홍문 전각 문루: 중앙 5칸 목조 누각, '華虹門' 현판, 계자난간, 팔작지붕
func _draw_hwahong_pavilion(a: Vector2, f: Vector2, h0: float) -> void:
	# 1층 몸체 (붉은 기둥, 중앙 마루, 살창 판문)
	_draw_gate_pav_body(a, f, 0.88, 0.35, h0, h0 + 13.0)
	# 수려한 팔작지붕 (처마 곡선 및 단청)
	_draw_gate_hip_roof(a, f, 1.18, 0.62, 0.55, h0 + 12.0, h0 + 23.0)
	# 정면 중앙 선명한 '華虹門' 현판
	var fs := 1.0 if f.y > 0.0 else -1.0
	var pc := f * (0.35 * fs) - Vector2(0, h0 + 7.5)
	var hw := a * 0.28
	FastDraw.poly(self, PackedVector2Array([
		pc - hw - Vector2(0, 3.0), pc + hw - Vector2(0, 3.0),
		pc + hw + Vector2(0, 3.0), pc - hw + Vector2(0, 3.0)
	]), Color("0d0d10"))
	FastDraw.polyline(self, PackedVector2Array([
		pc - hw - Vector2(0, 3.0), pc + hw - Vector2(0, 3.0),
		pc + hw + Vector2(0, 3.0), pc - hw + Vector2(0, 3.0),
		pc - hw - Vector2(0, 3.0)
	]), Color("d4af37"), 1.0)
	# '華虹門' 금색 글씨 상징선
	draw_line(pc - hw * 0.6, pc + hw * 0.6, Color("ffd700"), 1.8)

## 물 위 성곽(화홍문) 구간 스팬 및 전체 폭 정중앙 피벗 계산
func _get_water_wall_span(x: int, y: int, along_x: bool) -> Dictionary:
	var d := Vector2i(1, 0) if along_x else Vector2i(0, 1)
	var start_p := Vector2i(x, y)
	while _is_water_wall(start_p - d):
		start_p -= d
	var end_p := Vector2i(x, y)
	while _is_water_wall(end_p + d):
		end_p += d
	var count := (end_p.x - start_p.x + 1) if along_x else (end_p.y - start_p.y + 1)
	
	# 전체 타일 중심들의 산술 평균 = 전체 석축의 수학적 정중앙 피벗
	var sum_c := Vector2.ZERO
	for i in range(count):
		var cur := start_p + d * i
		var q_n := cell_center(cur.x, cur.y, 1.0)
		var q_e := cell_center(cur.x + 1, cur.y, 1.0)
		var q_s := cell_center(cur.x + 1, cur.y + 1, 1.0)
		var q_w := cell_center(cur.x, cur.y + 1, 1.0)
		sum_c += (q_n + q_e + q_s + q_w) * 0.25
	var center_pivot := sum_c / float(maxi(1, count))
	
	# 페인터스 알고리즘 상 y가 크거나 x가 큰 마지막 타일에서 누각을 그려 가림 방지
	var is_render := (x == end_p.x and y == end_p.y)
	return {
		"start": start_p,
		"end": end_p,
		"count": count,
		"center": center_pivot,
		"center_pivot": center_pivot,
		"is_render_tile": is_render
	}

func _is_water_wall(p: Vector2i) -> bool:
	if not grid.in_bounds(p.x, p.y):
		return false
	var t: Dictionary = grid.grid[p.y][p.x]
	return t["building"] == "wall" and (t["terrain"] == "water" or t.get("is_bridge", false))

## ─────────────────────────────────────────────── 화성행궁 (7x7 복합 궁궐)
## PORT-TRACE [행궁 7x7 복합 궁궐 재설계]: 사용자가 화성행궁 항공사진·안내 지도·복원 조감도를 보내며
## "여러 전각이 어우러진 복합시설인데 지금은 만들다 만 것 같다, 더 웅장하게"라고 요청. 예전 5x5는
## 화면 정면으로 고정된 작은 그림 몇 개와 빈 마당이라 휑했고, 화면을 돌려도 그림이 돌지 않았다.
## 이제는
## - 부지 전체를 박석 마당으로 깔고, 둘레는 긴 행각 + 바깥 담장이 끊김 없이 궁궐을 감싼다.
## - 정면(dy=+3) 신풍루(2층 누문) → 좌익문(안문)과 좌우 행각 → 중심축 삼도(박석길) → 정전
##   봉수당(넓은 월대 + 2단 지붕)과 좌우 익랑 → 낙남헌 → 후원(득중정 정자·소나무). 좌우에는
##   남·북군영, 서리청·집사청, 경룡관·유여택, 장락당·복내당·노래당이 늘어선다.
## - 모든 전각은 성문 문루와 같은 입체 헬퍼(_draw_gate_pav_body/_draw_gate_hip_roof)로
##   기단 → 붉은 기둥 몸체 → 우진각 기와지붕을 그린다. 축(ex, ey)을 타일의 실제 꼭짓점에서
##   뽑으므로 4방향 화면 회전에서도 올바르게 보인다.
## - 각 칸은 자기 몫만 그린다(부지 분산 렌더링) — 페인터스 알고리즘에 가려지지 않게.
## 좌표 rel=(dx,dy), dx·dy ∈ [-3,3]. dy=+3 정면, dy=-3 뒤(후원), dx=0 중심축.
const HAENGGUNG_LAYOUT := {
	Vector2i(0, 3): "sinpungru",                                  # 신풍루(정문)
	Vector2i(0, 2): "path", Vector2i(-1, 2): "tree", Vector2i(1, 2): "tree",
	Vector2i(-2, 2): "hall_s", Vector2i(2, 2): "hall_s",          # 남군영·북군영
	Vector2i(0, 1): "inner_gate",                                 # 좌익문
	Vector2i(-1, 1): "hangak_x", Vector2i(1, 1): "hangak_x",      # 좌익문 좌우 행각
	Vector2i(-2, 1): "hall_s_y", Vector2i(2, 1): "hall_s_y",      # 서리청·집사청
	Vector2i(0, 0): "path", Vector2i(-1, 0): "yard", Vector2i(1, 0): "yard",
	Vector2i(-2, 0): "hall_y", Vector2i(2, 0): "hall_y",          # 경룡관·유여택
	Vector2i(0, -1): "bongsudang",                                # 정전 봉수당
	Vector2i(-1, -1): "wing", Vector2i(1, -1): "wing",            # 봉수당 좌우 익랑
	Vector2i(-2, -1): "hall_y", Vector2i(2, -1): "hall_y",        # 장락당·복내당
	Vector2i(0, -2): "hall",                                      # 낙남헌
	Vector2i(-1, -2): "garden", Vector2i(1, -2): "garden",        # 후원
	Vector2i(-2, -2): "pavilion", Vector2i(2, -2): "hall_s",      # 득중정·노래당
}

const HG_PAVE := Color("d6caa8")      # 박석 마당
const HG_PAVE_LINE := Color("c2b58f")
const HG_PATH := Color("e4dbc2")      # 중심축 삼도(박석길)

func _draw_haenggung_part(grid_rel: Vector2i, c: Vector2, p_n: Vector2, p_e: Vector2, _p_s: Vector2, p_w: Vector2) -> void:
	# PORT-TRACE [행궁 동향]: 실제 화성행궁은 팔달산(서쪽)을 등지고 정문 신풍루가 동쪽을 바라본다.
	# 이 지도에서 동쪽은 격자 +x(창룡문·영남대로 방향)이므로, 배치표의 "정면(+dy)"을 격자 +x에,
	# "좌우(dx)"를 격자 y에 대응시킨다(좌우 대칭 배치라 거울상이 되어도 모양은 같다).
	var rel := Vector2i(grid_rel.y, grid_rel.x)
	var ex := (p_w - p_n) * 0.5 # 배치표 좌우(dx) = 격자 +y 반벡터
	var ey := (p_e - p_n) * 0.5 # 배치표 앞뒤(dy, +가 정면=동쪽) = 격자 +x 반벡터
	var perimeter := absi(rel.x) == 3 or absi(rel.y) == 3
	var part: String = HAENGGUNG_LAYOUT.get(rel, "yard")
	if perimeter and part != "sinpungru":
		part = "perimeter"

	if part == "garden":
		FastDraw.poly(self, PackedVector2Array([c - ex - ey, c + ex - ey, c + ex + ey, c - ex + ey]), Color("7fa35a"))
	else:
		_hg_paving(c, ex, ey)

	match part:
		"perimeter":
			_hg_perimeter(rel, c, ex, ey)
		"sinpungru":
			_hg_sinpungru(c, ex, ey)
		"inner_gate":
			_hg_inner_gate(c, ex, ey)
		"bongsudang":
			_hg_bongsudang(c, ex, ey)
		"hall":
			_hg_hall(c - ey * 0.1, ex * 0.8, ey * 0.45, 3.0, 10.0, 8.0)
			_hg_plaque(c - ey * 0.1, ex * 0.8, ey * 0.45, 3.0 + 7.0)
		"hall_y":
			_hg_hall(c, ey * 0.8, ex * 0.45, 3.0, 10.0, 8.0)
		"hall_s":
			_hg_hall(c, ex * 0.62, ey * 0.38, 2.0, 8.0, 6.0)
		"hall_s_y":
			_hg_hall(c, ey * 0.62, ex * 0.38, 2.0, 8.0, 6.0)
		"wing", "hangak_x":
			_hg_hall(c, ex * 1.0, ey * 0.3, 2.0, 7.0, 5.0, 1, 1.18) # 용마루를 끝까지 → 옆 칸과 이어지는 긴 지붕
		"pavilion":
			_hg_pavilion(c, ex, ey)
		"path":
			_hg_path(c, ex, ey)
		"tree":
			_hg_big_tree(c + ex * 0.1 - ey * 0.1)
		"garden":
			_hg_garden(c, ex, ey)
		_:
			pass

## 박석 마당 — 칸 전체를 깔아 이웃 칸과 이어지는 넓은 내정
func _hg_paving(c: Vector2, ex: Vector2, ey: Vector2) -> void:
	var snow: bool = (band_master.current_season if band_master else current_season) == "겨울"
	var pave_col: Color = Color("e8eef4") if snow else HG_PAVE
	var line_col: Color = Color("cbd5e1") if snow else HG_PAVE_LINE
	FastDraw.poly(self, PackedVector2Array([c - ex - ey, c + ex - ey, c + ex + ey, c - ex + ey]), pave_col)
	for k: float in [-0.5, 0.0, 0.5]:
		draw_line(c - ex + ey * k, c + ex + ey * k, line_col, 0.8)

## 중심축 삼도(가운데가 도드라진 박석길)
func _hg_path(c: Vector2, ex: Vector2, ey: Vector2) -> void:
	var snow: bool = (band_master.current_season if band_master else current_season) == "겨울"
	var path_col: Color = Color("f1f5f9") if snow else HG_PATH
	var line_col: Color = Color("cbd5e1") if snow else Color("a89c7c")
	var w := ex * 0.2
	FastDraw.poly(self, PackedVector2Array([c - w - ey, c + w - ey, c + w + ey, c - w + ey]), path_col)
	draw_line(c - w - ey, c - w + ey, line_col, 1.0)
	draw_line(c + w - ey, c + w + ey, line_col, 1.0)

## 화강암 기단(석축 대) — 바닥 중심 o, 반폭 a·f, 높이 h
func _hg_plinth(o: Vector2, a: Vector2, f: Vector2, h: float) -> void:
	var g := PackedVector2Array([o - a - f, o + a - f, o + a + f, o - a + f])
	var all4: Array[bool] = [true, true, true, true]
	var none4: Array[bool] = [false, false, false, false]
	_draw_wall_block(g, all4, none4, h, Color("b3ab9a"), Color("8f887a"), Color("c9c0ab"), Color("6e685e"), Color("1c1d22"))

## 전각 한 채: 기단 → 붉은 기둥 몸체(창방 단청 띠) → 우진각 기와지붕. a=긴 축 반폭, f=짧은 축 반폭.
## ridge_u: 용마루 길이(a 단위) — 1.18이면 박공 없이 끝까지 이어져 행각처럼 옆 칸과 연결된다.
## 반환: 기단 포함 전체 높이(px)
func _hg_hall(o: Vector2, a: Vector2, f: Vector2, plinth: float, body: float, roof: float, tiers: int = 1, ridge_u: float = 0.55) -> float:
	_hg_plinth(o, a * 1.06, f * 1.3, plinth)
	var top := o - Vector2(0, plinth)
	draw_set_transform(top, 0.0, Vector2.ONE)
	_draw_gate_pav_body(a, f, 1.0, 1.0, 0.0, body)
	_draw_gate_hip_roof(a, f, 1.18, 1.5, ridge_u, body - 1.0, body + roof)
	var h := body + roof
	if tiers >= 2:
		var b2 := body + roof * 0.5
		_draw_gate_pav_body(a, f, 0.62, 0.6, b2, b2 + body * 0.6)
		var e2 := b2 + body * 0.6
		_draw_gate_hip_roof(a, f, 0.86, 1.0, ridge_u * 0.7, e2 - 1.0, e2 + roof)
		h = e2 + roof
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return plinth + h

## 현판 — 카메라 쪽 긴 면 처마 아래
func _hg_plaque(o: Vector2, a: Vector2, f: Vector2, h: float) -> void:
	var fs := 1.0 if f.y > 0.0 else -1.0
	var pc := o + f * fs * 1.02 - Vector2(0, h)
	var hw := a * 0.28
	FastDraw.poly(self, PackedVector2Array([pc - hw - Vector2(0, 2.0), pc + hw - Vector2(0, 2.0), pc + hw + Vector2(0, 2.0), pc - hw + Vector2(0, 2.0)]), Color("0f0f12"))
	draw_line(pc - hw * 0.8, pc + hw * 0.8, Color("e8b820"), 1.3)

## 카메라 쪽 긴 면에 어두운 문 통로
func _hg_doorway(o: Vector2, a: Vector2, f: Vector2, plinth: float, h: float) -> void:
	var fs := 1.0 if f.y > 0.0 else -1.0
	var base := o + f * fs * 1.02 - Vector2(0, plinth)
	var w := a * 0.25
	FastDraw.poly(self, PackedVector2Array([base - w, base + w, base + w - Vector2(0, h), base - w - Vector2(0, h)]), Color("2a1510"))

## 담장 한 토막(흰 회벽 + 기와 얹은 머리)
func _hg_wall_seg(o: Vector2, a: Vector2, f: Vector2, h: float) -> void:
	var snow: bool = (band_master.current_season if band_master else current_season) == "겨울"
	var g := PackedVector2Array([o - a - f, o + a - f, o + a + f, o - a + f])
	var all4: Array[bool] = [true, true, true, true]
	var none4: Array[bool] = [false, false, false, false]
	var top_col: Color = Color("f8fafc") if snow else Color("3a3f47")
	_draw_wall_block(g, all4, none4, h, Color("e2dbcb"), Color("c2b9a6"), top_col, Color("b3a994"), Color("1c1d22"))
	if snow:
		draw_line(o - a + f - Vector2(0, h), o + a + f - Vector2(0, h), Color("ffffff"), 1.8)

## 둘레: 바깥 모서리 쪽에 담장, 그 안쪽에 긴 행각(모서리 칸은 모서리 전각). 화면 뒤쪽 것부터.
func _hg_perimeter(rel: Vector2i, c: Vector2, ex: Vector2, ey: Vector2) -> void:
	var outs: Array[Vector2] = []
	if rel.y == 3: outs.append(ey)
	if rel.y == -3: outs.append(-ey)
	if rel.x == 3: outs.append(ex)
	if rel.x == -3: outs.append(-ex)
	var items: Array = [] # [깊이(y), 종류, 인자...]
	for d: Vector2 in outs:
		var along := ey if (d.is_equal_approx(ex) or d.is_equal_approx(-ex)) else ex
		items.append({"y": (c + d * 0.93).y, "kind": "wall", "o": c + d * 0.93, "a": along, "f": d * 0.07})
	if outs.size() == 1:
		var d0: Vector2 = outs[0]
		var along0 := ey if (d0.is_equal_approx(ex) or d0.is_equal_approx(-ex)) else ex
		items.append({"y": (c + d0 * 0.4).y, "kind": "hangak", "o": c + d0 * 0.4, "a": along0, "f": d0 * 0.32})
	else:
		var dc: Vector2 = outs[0] + outs[1]
		items.append({"y": (c + dc * 0.4).y, "kind": "corner", "o": c + dc * 0.4, "a": ex * 0.45, "f": ey * 0.45})
	items.sort_custom(func(p, q): return p["y"] < q["y"])
	for it in items:
		match it["kind"]:
			"wall": _hg_wall_seg(it["o"], it["a"], it["f"], 9.0)
			"hangak": _hg_hall(it["o"], it["a"], it["f"], 2.0, 7.0, 5.0, 1, 1.18)
			"corner": _hg_hall(it["o"], it["a"], it["f"], 2.0, 8.0, 6.0)

## 신풍루(新豊樓) — 정문. 2층 누문 + 좌우 담장 이음 + 오방기
func _hg_sinpungru(c: Vector2, ex: Vector2, ey: Vector2) -> void:
	var items: Array = []
	for s: float in [-1.0, 1.0]:
		var o := c + ex * (s * 0.86) + ey * 0.93
		items.append({"y": o.y, "kind": "wall", "o": o})
	items.append({"y": c.y, "kind": "gate"})
	items.sort_custom(func(p, q): return p["y"] < q["y"])
	for it in items:
		if it["kind"] == "wall":
			_hg_wall_seg(it["o"], ex * 0.14, ey * 0.07, 9.0)
		else:
			var a := ex * 0.72
			var f := ey * 0.45
			var h := _hg_hall(c, a, f, 3.0, 12.0, 9.0, 2)
			_hg_doorway(c, a, f, 3.0, 9.0)
			_hg_plaque(c, a, f, 3.0 + 16.0)
			_hg_name_tag("신풍루", c - Vector2(0, h + 10.0))
	# 오방기 — 정문 앞 좌우
	var flag_cols: Array[Color] = [Color("c0392b"), Color("e8b820"), Color("1a5276"), Color("1e8449"), Color("f4f1e8")]
	var idx := 0
	for s: float in [-1.0, 1.0]:
		for k: float in [0.55, 0.85]:
			var base := c + ex * (s * k) + ey * 0.98
			var tip := base - Vector2(0, 24.0)
			draw_line(base, tip, Color("5c3a21"), 1.3)
			FastDraw.poly(self, PackedVector2Array([tip, tip + Vector2(s * 8.0, 3.0), tip + Vector2(0, 6.0)]), flag_cols[idx % flag_cols.size()])
			idx += 1

## 좌익문(左翊門) — 안쪽 문간채 + 양옆 담장 이음(좌우 행각과 연결)
func _hg_inner_gate(c: Vector2, ex: Vector2, ey: Vector2) -> void:
	for s: float in [-1.0, 1.0]:
		_hg_wall_seg(c + ex * (s * 0.74), ex * 0.26, ey * 0.08, 8.0)
	var a := ex * 0.45
	var f := ey * 0.3
	_hg_hall(c, a, f, 2.0, 9.0, 7.0)
	_hg_doorway(c, a, f, 2.0, 7.0)

## 봉수당(奉壽堂) — 정전. 앞으로 넓게 나온 월대 위에 가장 크고 높은 2단 지붕 전각
func _hg_bongsudang(c: Vector2, ex: Vector2, ey: Vector2) -> void:
	_hg_plinth(c + ey * 0.35, ex * 0.8, ey * 0.62, 4.0) # 월대(앞마당 단)
	var o := c - ey * 0.12
	var a := ex * 0.92
	var f := ey * 0.55
	var h := _hg_hall(o, a, f, 6.0, 13.0, 10.0, 2)
	_hg_plaque(o, a, f, 6.0 + 11.0)
	_hg_name_tag("봉수당", o - Vector2(0, h + 10.0))

## 득중정(得中亭) — 후원의 정자: 기단 + 네 기둥 + 사모지붕
func _hg_pavilion(c: Vector2, ex: Vector2, ey: Vector2) -> void:
	var a := ex * 0.4
	var f := ey * 0.4
	_hg_plinth(c, a * 1.15, f * 1.15, 3.0)
	var top := c - Vector2(0, 3.0)
	for su: float in [-1.0, 1.0]:
		for sv: float in [-1.0, 1.0]:
			var p := top + a * su + f * sv
			draw_line(p, p - Vector2(0, 9.0), Color("8a241c"), 1.8)
	draw_set_transform(top, 0.0, Vector2.ONE)
	_draw_gate_hip_roof(a, f, 1.35, 1.35, 0.1, 8.0, 16.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 마당의 큰 느티나무 — 사계절 잎 및 겨울 눈꽃
func _hg_big_tree(p: Vector2) -> void:
	var s: String = band_master.current_season if band_master else current_season
	FastDraw.circle(self, p + Vector2(2, 2), 5.0, Color(0, 0, 0, 0.22))
	draw_line(p, p + Vector2(0, -11), Color("4a3d30"), 2.4)
	match s:
		"봄":
			FastDraw.circle(self, p + Vector2(-4, -13), 5.5, Color("f472b6"))
			FastDraw.circle(self, p + Vector2(4, -14), 5.0, Color("fb7185"))
			FastDraw.circle(self, p + Vector2(0, -18), 5.5, Color("fbcfe8"))
		"가을":
			FastDraw.circle(self, p + Vector2(-4, -13), 5.5, Color("ea580c"))
			FastDraw.circle(self, p + Vector2(4, -14), 5.0, Color("f59e0b"))
			FastDraw.circle(self, p + Vector2(0, -18), 5.5, Color("b45309"))
		"겨울":
			draw_line(p + Vector2(0, -11), p + Vector2(-5, -17), Color("4a3d30"), 1.8)
			draw_line(p + Vector2(0, -11), p + Vector2(5, -17), Color("4a3d30"), 1.8)
			draw_line(p + Vector2(0, -11), p + Vector2(0, -19), Color("4a3d30"), 1.8)
			FastDraw.circle(self, p + Vector2(-4, -16), 3.0, Color("f8fafc", 0.95))
			FastDraw.circle(self, p + Vector2(4, -16), 2.8, Color("f8fafc", 0.95))
			FastDraw.circle(self, p + Vector2(0, -19), 3.2, Color("ffffff", 0.95))
		_: # "여름"
			FastDraw.circle(self, p + Vector2(-4, -13), 5.5, Color("356f28"))
			FastDraw.circle(self, p + Vector2(4, -14), 5.0, Color("3f7f2e"))
			FastDraw.circle(self, p + Vector2(0, -18), 5.5, Color("4a8f35"))

## 후원: 잔디 + 소나무 두 그루 + 괴석
func _hg_garden(c: Vector2, ex: Vector2, ey: Vector2) -> void:
	var s: String = band_master.current_season if band_master else current_season
	for off: Vector2 in [-ex * 0.4 - ey * 0.3, ex * 0.35 + ey * 0.2]:
		var p: Vector2 = c + off
		draw_line(p, p + Vector2(-1, -9), Color("5e3019"), 2.0)
		match s:
			"봄":
				FastDraw.circle(self, p + Vector2(3, -10), 3.6, Color("2d6236"))
				FastDraw.circle(self, p + Vector2(-3, -12), 3.8, Color("6aa250"))
				FastDraw.circle(self, p + Vector2(1, -16), 4.2, Color("f472b6"))
			"가을":
				FastDraw.circle(self, p + Vector2(3, -10), 3.6, Color("c2410c"))
				FastDraw.circle(self, p + Vector2(-3, -12), 3.8, Color("d97706"))
				FastDraw.circle(self, p + Vector2(1, -16), 4.2, Color("b45309"))
			"겨울":
				FastDraw.circle(self, p + Vector2(3, -10), 3.6, Color("1e4725"))
				FastDraw.circle(self, p + Vector2(-3, -12), 3.8, Color("2a6133"))
				FastDraw.circle(self, p + Vector2(1, -16), 4.2, Color("2f6b38"))
				FastDraw.circle(self, p + Vector2(0, -17), 3.5, Color("f8fafc", 0.95))
			_:
				FastDraw.circle(self, p + Vector2(3, -10), 3.6, Color("1e4725"))
				FastDraw.circle(self, p + Vector2(-3, -12), 3.8, Color("2a6133"))
				FastDraw.circle(self, p + Vector2(1, -16), 4.2, Color("2f6b38"))
	var r := c + ex * 0.3 - ey * 0.35
	FastDraw.poly(self, PackedVector2Array([r + Vector2(-3, 0), r + Vector2(3, 0), r + Vector2(2, -5), r + Vector2(-2, -4)]), Color("8f8a80"))
	if s == "겨울":
		draw_line(r + Vector2(-2, -4), r + Vector2(2, -5), Color("f8fafc"), 1.6)

## 주요 전각 이름표
func _hg_name_tag(text: String, p: Vector2) -> void:
	var sz := Vector2(float(text.length() * 11 + 12), 14)
	var r := Rect2(p - sz * 0.5, sz)
	draw_rect(r, Color(0.12, 0.08, 0.05, 0.85))
	draw_rect(r, Color("e8b820"), false, 1.0)
	draw_string(ThemeDB.fallback_font, p + Vector2(-sz.x * 0.5 + 6, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("fef3c7"))

## ─────────────────────────────────────────────── 만석거(萬石渠) 6x6 전용 2.5D 자연형 대호수 렌더러
## ─────────────────────────────────────────────── 만석거(萬石渠) 6x6 전용 2.5D 유기적 대호수 렌더러
## 정조 1795년 대유둔전 관개 대호수:
## - 6x6 유기적 호안 석축 둑길 (둘레 20칸): 코너 4곳 곡선 호안 및 견치석 2단 경사 석축, 수양버들/소나무/벚꽃 산책로
## - 북안 수변 영화정 소루 (rel=2,0): 수면 위로 뻗어나온 마루, 붉은 홍주, 팔작지붕과 은은한 수면 반영(Water Reflection)
## - 북안 나루터 선착장과 나룻배 (rel=3,0): 물가 화강암 계단, 목재 계선주, 노와 삿대를 갖춘 조선 전통 나룻배
## - 남안 대유둔전 방류 석조 홍예 수문 (rel=4,5): 2련 홍예 아치, 수문 권양기, 쏟아지는 백색 포말 폭포수
## ─────────────────────────────────────────────── 만석거(萬石渠) 6x6 전용 2.5D 대호수 렌더러
## 레퍼런스 고증: 시원하고 깊은 코발트 블루 대호수, 2단 입체 자연석/화강암 석축 제방,
## 둑길 돌계단, 2.5D 대각선 뷰 사각 기와 영화정(迎華亭) 누각, 한가로이 떠 있는 나룻배 1척
func _draw_manseokgeo_part(rel: Vector2i, c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2, tile := Vector2i(-1, -1), anchor := Vector2i(-1, -1)) -> void:
	# [고품질 PNG 전면 전환] 6x6 단일 고화질 PNG 텍스처 단일 드로우콜 렌더링
	var season_sfx: String = SeasonColorFilter.get_current_season_suffix(current_season)
	var lake_tex: Texture2D = SpriteCacheManager.get_seasonal_or_base_texture(
		"buildings", "manseokgeo", season_sfx, Vector2i(448, 320)
	)
	if lake_tex != null:
		# PORT-TRACE [호수 안 보임]: 기준 칸(anchor)은 부지 왼쪽 위가 아니라 안쪽(2,2)이다 → 부지 칸 목록의 가장 앞 칸에서 그린다
		var front_hit := rel == Vector2i(5, 5)
		if tile.x >= 0 and grid.in_bounds(anchor.x, anchor.y) and grid.grid[anchor.y][anchor.x].has("site_tiles"):
			front_hit = tile == _group_front_tile(anchor)
		if front_hit:
			# PORT-TRACE [호수 그림 정합]: 그림(448x320)은 바닥 마름모가 2:1이 아니고(좌우 꼭짓점 y≈181, 아래 꼭짓점 y≈319) 7x7 폭이라
			# 6x6 부지(가로 384, 마름모 높이 192)에 맞게 가로 0.857·세로 0.696으로 줄여, 가장 앞 칸(5,5)에서 한 번에 그린다
			# (뒤 칸에서 그리면 뒤에 그려지는 칸들의 바닥이 그림을 덮어 "그리다 만" 모습이 됐다).
			var shadow_col: Color = SeasonColorFilter.get_current_shadow_color(current_season)
			var body_tint: Color = SeasonColorFilter.get_current_tile_tint(current_season)
			var ft: Vector2i = tile if tile.x >= 0 else Vector2i(-1, -1)
			var sink := Vector2(0, 0.0) # 석축 옆면은 그림에서 지웠다(tools/flatten_base.py)
			if ft.x >= 0 and _draw_fitted(lake_tex, "manseokgeo", cell_center(float(ft.x - 5), float(ft.y + 1), 1.0) + sink, cell_center(float(ft.x + 1), float(ft.y - 5), 1.0) + sink, cell_center(float(ft.x + 1), float(ft.y + 1), 1.0) + sink, body_tint, shadow_col):
				return
			var rect := Rect2(c.x - 192.0, c.y + 16.0 - 222.6, 384.0, 222.6)
			draw_texture_rect(lake_tex, Rect2(rect.position + Vector2(3.0, 4.0), rect.size), false, shadow_col)
			draw_texture_rect(lake_tex, rect, false, body_tint)
		return

	# 폴백: PNG 부재 시 절차적 레거시 드로잉
	var rx: int = clampi(rel.x, 0, 5)
	var ry: int = clampi(rel.y, 0, 5)
	var is_bank: bool = (rx == 0 or rx == 5 or ry == 0 or ry == 5)

	if is_bank:
		if rx == 2 and ry == 0:
			_draw_manseokgeo_pavilion(c, p_w, p_s, p_e)
		elif rx == 3 and ry == 0:
			_draw_manseokgeo_dock(c, p_n, p_e, p_s, p_w)
		elif rx == 4 and ry == 5:
			_draw_manseokgeo_sluice(c, p_n, p_e, p_s, p_w)
		else:
			_draw_manseokgeo_bank(c, rx, ry, p_n, p_e, p_s, p_w)
	else:
		_draw_manseokgeo_water(c, rx, ry)

## 만석거 호수 수면 — 레퍼런스 스타일: 깊고 투명한 코발트/에메랄드 블루 심연, 잔잔한 수평 윤슬, 한가로운 나룻배
func _draw_manseokgeo_water(c: Vector2, rx: int, ry: int) -> void:
	# 1. 타일 이음새를 완전히 지우는 오버랩 마름모 (1.08 스케일)
	var dist_cen: float = sqrt(pow(float(rx) - 2.5, 2.0) + pow(float(ry) - 2.5, 2.0))
	var depth_t: float = clampf(1.0 - dist_cen / 3.4, 0.0, 1.0)
	var water_base: Color = Color("0284c7").lerp(Color("0c4a6e"), depth_t * 0.8)
	FastDraw.poly(self, _diamond(c, 1.08), water_base)

	# 2. 중심부 깊은 심연 그라데이션
	var water_deep: Color = Color("0369a1").lerp(Color("082f49"), depth_t)
	FastDraw.poly(self, _diamond(c, 0.85), water_deep)

	# 3. 수평 방향 잔잔한 은빛 물비늘 (수평 윤슬)
	var seed_w: int = absi(rx * 37 ^ ry * 73)
	var wave_col := Color("7dd3fc", 0.65)
	var wave_spec := Color("ffffff", 0.85)

	FastDraw.polyline(self, PackedVector2Array([
		c + Vector2(-15.0, -2.5), c + Vector2(-3.0, 1.5), c + Vector2(11.0, -1.8)
	]), wave_col, 1.2)
	FastDraw.polyline(self, PackedVector2Array([
		c + Vector2(-9.0, 5.5), c + Vector2(2.0, 8.5), c + Vector2(14.0, 5.0)
	]), wave_col, 1.0)
	# 은빛 햇살 반짝임 포인트
	FastDraw.circle(self, c + Vector2(-3.0, 1.5), 1.0, wave_spec)
	FastDraw.circle(self, c + Vector2(2.0, 8.5), 0.9, wave_spec)

	if seed_w % 2 == 0:
		FastDraw.polyline(self, PackedVector2Array([
			c + Vector2(-7.0, -8.0), c + Vector2(4.0, -5.5), c + Vector2(13.0, -8.0)
		]), wave_col, 0.9)
		FastDraw.circle(self, c + Vector2(4.0, -5.5), 0.9, wave_spec)

	# 4. 레퍼런스 이미지 스타일: 호수 중앙에 평화롭게 떠 있는 작은 조선 목선(나룻배) 1척 (rx=2, ry=3)
	if rx == 2 and ry == 3:
		var bp: Vector2 = c + Vector2(3.0, -2.0)
		# 배 아래 수면 물결 그림자
		FastDraw.poly(self, PackedVector2Array([
			bp + Vector2(-13.0, 4.0), bp + Vector2(13.0, 4.0),
			bp + Vector2(9.0, 8.0), bp + Vector2(-9.0, 8.0)
		]), Color(0.01, 0.15, 0.25, 0.40))
		# 배 외형 (날렵한 목선)
		FastDraw.poly(self, PackedVector2Array([
			bp + Vector2(-12.0, 0.0), bp + Vector2(0.0, -4.5),
			bp + Vector2(12.0, 1.5), bp + Vector2(2.0, 6.0)
		]), Color("854d0e"))
		# 배 안쪽 우물마루 판자
		FastDraw.poly(self, PackedVector2Array([
			bp + Vector2(-9.0, 0.2), bp + Vector2(0.0, -3.0),
			bp + Vector2(9.0, 1.2), bp + Vector2(1.5, 4.2)
		]), Color("543018"))
		draw_line(bp + Vector2(-6.0, -0.2), bp + Vector2(6.0, 1.8), Color("a16207"), 0.8)
		# 삿갓을 쓰고 낚싯대를 드리운 백성
		var fisher_p: Vector2 = bp + Vector2(-2.0, -1.0)
		draw_rect(Rect2(fisher_p - Vector2(1.5, 6.0), Vector2(3.0, 6.0)), Color("f8fafc")) # 흰 저고리
		FastDraw.poly(self, PackedVector2Array([
			fisher_p + Vector2(-4.0, -6.0), fisher_p + Vector2(4.0, -6.0),
			fisher_p + Vector2(0.0, -9.5)
		]), Color("d97706")) # 갈색 삿갓
		# 낚싯대 및 낚싯줄
		draw_line(fisher_p + Vector2(1.0, -4.0), fisher_p + Vector2(10.0, -9.0), Color("451a03"), 0.9)
		draw_line(fisher_p + Vector2(10.0, -9.0), fisher_p + Vector2(14.0, 2.0), Color("e0f2fe", 0.7), 0.7)
		FastDraw.circle(self, fisher_p + Vector2(14.0, 2.0), 0.8, Color("ffffff")) # 찌(찌 물결)
		# 노(Oar)
		draw_line(bp + Vector2(-5.0, 2.0), bp + Vector2(-8.0, 9.0), Color("ca8a04"), 1.2)
		# 배 주위 잔잔한 물결 링
		FastDraw.arc(self, bp + Vector2(0.0, 5.0), 7.0, -0.3, PI + 0.3, 8, Color("bae6fd", 0.6), 0.8)

	# 5. 사계절 수면 반응
	if current_season == "봄":
		FastDraw.circle(self, c + Vector2(-8.0, 3.0), 1.1, Color(0.98, 0.75, 0.83, 0.85))
		FastDraw.circle(self, c + Vector2(10.0, -4.0), 1.0, Color(1.0, 0.88, 0.93, 0.85))
	elif current_season == "가을":
		FastDraw.circle(self, c + Vector2(-6.0, 4.0), 1.2, Color("ea580c")) # 붉은 단풍잎
		FastDraw.circle(self, c + Vector2(8.0, -3.0), 1.1, Color("d97706")) # 은행잎
	elif current_season == "겨울":
		FastDraw.poly(self, _diamond(c, 0.98), Color(0.72, 0.86, 0.94, 0.80)) # 투명 살얼음판
		draw_line(c + Vector2(-13.0, -3.0), c + Vector2(11.0, 6.0), Color("ffffff", 0.7), 0.9)
		draw_line(c + Vector2(-4.0, 2.0), c + Vector2(7.0, -5.0), Color("ffffff", 0.5), 0.7)

## 만석거 호안(둑길) — 레퍼런스 스타일: 2단 입체 자연석/화강암 석축(石築) + 화강암 돌계단 + 다진 황토 산책로 + 수목
func _draw_manseokgeo_bank(c: Vector2, rx: int, ry: int, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2) -> void:
	# 1. 둑길 바탕 사계절 잔디/설경 둔덕
	var grass_col: Color
	match current_season:
		"봄": grass_col = Color("65a30d") # 파릇파릇한 봄 잔디
		"여름": grass_col = Color("3f6212") # 짙푸른 여름 잔디
		"가을": grass_col = Color("a16207") # 황금빛 가을 잔디
		"겨울": grass_col = Color("f1f5f9") # 하얗게 눈 덮인 겨울 제방
		_: grass_col = Color("65a30d")
	FastDraw.poly(self, _diamond(c, 1.02), grass_col)

	# 2. 견고한 화강암/자연석 2단 석축 팔레트
	var col_stone_top := Color("94a3b8") # 윗면 장대석 하이라이트
	var col_stone_face := Color("64748b") # 정면 석벽
	var col_stone_dark := Color("334155") # 음영 및 줄눈
	var col_foam := Color("e0f2fe", 0.90) # 물과 만나는 포말선
	var col_path := Color("f8fafc") if current_season == "겨울" else Color("d4b483") # 둑길 산책로

	# 3. 코너 4곳 및 4면 석축 렌더링
	if rx == 0 and ry == 0:
		# [북서 코너]: 북/서는 둑길, 남동쪽은 호수
		var m_in: Vector2 = c.lerp(p_s, 0.40)
		FastDraw.poly(self, PackedVector2Array([p_w, m_in, p_e, p_s]), col_stone_face)
		draw_line(p_w, m_in, col_stone_top, 1.8)
		draw_line(m_in, p_e, col_stone_top, 1.8)
		draw_line(p_w, p_s, col_foam, 1.3)
		draw_line(p_s, p_e, col_foam, 1.3)
		draw_line(p_n, c, col_path, 2.6) # 코너 둑길 산책로
	elif rx == 5 and ry == 0:
		# [북동 코너]: 북/동은 둑길, 남서쪽은 호수
		var m_in2: Vector2 = c.lerp(p_w, 0.40)
		FastDraw.poly(self, PackedVector2Array([p_n, m_in2, p_s, p_w]), col_stone_face)
		draw_line(p_n, m_in2, col_stone_top, 1.8)
		draw_line(m_in2, p_s, col_stone_top, 1.8)
		draw_line(p_n, p_w, col_foam, 1.3)
		draw_line(p_w, p_s, col_foam, 1.3)
		draw_line(p_e, c, col_path, 2.6)
	elif rx == 0 and ry == 5:
		# [남서 코너]: 서/남은 둑길, 북동쪽은 호수
		var m_in3: Vector2 = c.lerp(p_e, 0.40)
		FastDraw.poly(self, PackedVector2Array([p_n, m_in3, p_s, p_e]), col_stone_face)
		draw_line(p_n, m_in3, col_stone_top, 1.8)
		draw_line(m_in3, p_s, col_stone_top, 1.8)
		draw_line(p_n, p_e, col_foam, 1.3)
		draw_line(p_e, p_s, col_foam, 1.3)
		draw_line(p_w, c, col_path, 2.6)
	elif rx == 5 and ry == 5:
		# [남동 코너]: 동/남은 둑길, 북서쪽은 호수
		var m_in4: Vector2 = c.lerp(p_n, 0.40)
		FastDraw.poly(self, PackedVector2Array([p_w, m_in4, p_e, p_n]), col_stone_face)
		draw_line(p_w, m_in4, col_stone_top, 1.8)
		draw_line(m_in4, p_e, col_stone_top, 1.8)
		draw_line(p_w, p_n, col_foam, 1.3)
		draw_line(p_n, p_e, col_foam, 1.3)
		draw_line(p_s, c, col_path, 2.6)
	elif ry == 0:
		# [북안]: 호수 물이 남서쪽(p_w -> p_s)에 접함
		var cw: Vector2 = p_w.lerp(p_n, 0.45)
		var cs: Vector2 = p_s.lerp(p_e, 0.45)
		FastDraw.poly(self, PackedVector2Array([cw, cs, p_s, p_w]), col_stone_face)
		draw_line(cw, cs, col_stone_top, 1.8)
		draw_line(p_w, p_s, col_foam, 1.4)
		# 2단 석축 가로/세로 돌 줄눈
		for si: int in range(1, 4):
			var st: float = float(si) * 0.25
			draw_line(cw.lerp(cs, st), p_w.lerp(p_s, st), col_stone_dark, 1.1)
		draw_line(cw.lerp(p_w, 0.5), cs.lerp(p_s, 0.5), col_stone_dark, 0.9)
		draw_line(p_w.lerp(p_n, 0.72), p_s.lerp(p_e, 0.72), col_path, 2.4)
	elif rx == 0:
		# [서안]: 호수 물이 남동쪽(p_e -> p_s)에 접함
		var ce: Vector2 = p_e.lerp(p_n, 0.45)
		var cs2: Vector2 = p_s.lerp(p_w, 0.45)
		FastDraw.poly(self, PackedVector2Array([ce, cs2, p_s, p_e]), col_stone_face)
		draw_line(ce, cs2, col_stone_top, 1.8)
		draw_line(p_e, p_s, col_foam, 1.4)
		for si: int in range(1, 4):
			var st: float = float(si) * 0.25
			draw_line(ce.lerp(cs2, st), p_e.lerp(p_s, st), col_stone_dark, 1.1)
		draw_line(ce.lerp(p_e, 0.5), cs2.lerp(p_s, 0.5), col_stone_dark, 0.9)
		draw_line(p_e.lerp(p_n, 0.72), p_s.lerp(p_w, 0.72), col_path, 2.4)
	elif ry == 5:
		# [남안]: 호수 물이 북동쪽(p_n -> p_e)에 접함
		var cn: Vector2 = p_n.lerp(p_w, 0.45)
		var ce2: Vector2 = p_e.lerp(p_s, 0.45)
		FastDraw.poly(self, PackedVector2Array([cn, ce2, p_e, p_n]), col_stone_face)
		draw_line(cn, ce2, col_stone_top, 1.8)
		draw_line(p_n, p_e, col_foam, 1.4)
		for si: int in range(1, 4):
			var st: float = float(si) * 0.25
			draw_line(cn.lerp(ce2, st), p_n.lerp(p_e, st), col_stone_dark, 1.1)
		draw_line(cn.lerp(p_n, 0.5), ce2.lerp(p_e, 0.5), col_stone_dark, 0.9)
		draw_line(p_n.lerp(p_w, 0.72), p_e.lerp(p_s, 0.72), col_path, 2.4)

		# 레퍼런스 스타일: 남안 (rx=1, ry=5) 석벽에 수면으로 내려가는 화강암 3단 돌계단(Water Steps)
		if rx == 1:
			var st_top: Vector2 = cn.lerp(ce2, 0.5)
			var st_bot: Vector2 = p_n.lerp(p_e, 0.5)
			var st_w: Vector2 = (ce2 - cn).normalized() * 5.0
			FastDraw.poly(self, PackedVector2Array([
				st_top - st_w, st_top + st_w, st_bot + st_w, st_bot - st_w
			]), Color("cbd5e1"))
			# 3단 디딤판 줄눈
			draw_line(st_top.lerp(st_bot, 0.33) - st_w, st_top.lerp(st_bot, 0.33) + st_w, Color("64748b"), 1.1)
			draw_line(st_top.lerp(st_bot, 0.66) - st_w, st_top.lerp(st_bot, 0.66) + st_w, Color("64748b"), 1.1)
			draw_line(st_bot - st_w, st_bot + st_w, Color("f8fafc"), 1.2)
	elif rx == 5:
		# [동안]: 호수 물이 북서쪽(p_n -> p_w)에 접함
		var cn2: Vector2 = p_n.lerp(p_e, 0.45)
		var cw2: Vector2 = p_w.lerp(p_s, 0.45)
		FastDraw.poly(self, PackedVector2Array([cn2, cw2, p_w, p_n]), col_stone_face)
		draw_line(cn2, cw2, col_stone_top, 1.8)
		draw_line(p_n, p_w, col_foam, 1.4)
		for si: int in range(1, 4):
			var st: float = float(si) * 0.25
			draw_line(cn2.lerp(cw2, st), p_n.lerp(p_w, st), col_stone_dark, 1.1)
		draw_line(cn2.lerp(p_n, 0.5), cw2.lerp(p_w, 0.5), col_stone_dark, 0.9)
		draw_line(p_n.lerp(p_e, 0.72), p_w.lerp(p_s, 0.72), col_path, 2.4)

	# 4. 둑길 사계절 수목 연출
	var seed_b: int = absi(rx * 11 ^ ry * 19)
	match current_season:
		"봄":
			if (rx + ry) % 2 == 0:
				_draw_cherry_blossom_tree(c + Vector2(0.0, -6.0), current_season, 1.15, seed_b)
			else:
				_draw_tree_willow(c + Vector2(0.0, -5.0), current_season)
		"여름":
			if (rx + ry) % 2 == 0:
				_draw_tree_willow(c + Vector2(0.0, -5.0), current_season)
			else:
				_draw_pine_tree(c + Vector2(2.0, -4.0), current_season)
		"가을":
			if (rx + ry) % 2 == 0:
				_draw_tree_seasonal(c + Vector2(0.0, -6.0), current_season, false)
			else:
				_draw_tree_willow(c + Vector2(0.0, -5.0), current_season)
		"겨울":
			if (rx + ry) % 2 == 0:
				_draw_pine_tree(c + Vector2(2.0, -4.0), current_season)
				FastDraw.circle(self, c + Vector2(2.0, -14.0), 3.0, Color("f8fafc", 0.9))
			else:
				_draw_tree_willow(c + Vector2(0.0, -5.0), current_season)

## 만석거 북안 영화정(迎華亭) — 레퍼런스 스타일: 정통 2.5D 아이소메트릭 사각 기와 누각 (돌기단 + 계자난간 + 4기둥 + 날렵한 앙곡 사모지붕 + 절병통)
func _draw_manseokgeo_pavilion(c: Vector2, p_w: Vector2, p_s: Vector2, p_e: Vector2) -> void:
	var season: String = band_master.current_season if band_master else current_season
	var snow: bool = season == "겨울"

	# 1. 둑길 바탕 잔디 및 석축
	var bg_col: Color = Color("f1f5f9") if snow else Color("65a30d")
	FastDraw.poly(self, _diamond(c, 1.02), bg_col)
	var cw: Vector2 = p_w.lerp(c, 0.4)
	var cs: Vector2 = p_s.lerp(p_e, 0.4)
	FastDraw.poly(self, PackedVector2Array([cw, cs, p_s, p_w]), Color("64748b"))
	draw_line(p_w, p_s, Color("e0f2fe", 0.8), 1.3)

	# 2.5D 누각 중심 앵커
	var pc: Vector2 = c + Vector2(0.0, -4.0)

	# 2.5D 로컬 투영 람다: u: 남서->북동 (-1..1), v: 북서->남동 (-1..1), h: 수직 높이 (px)
	var iso_pt := func(u_val: float, v_val: float, h_val: float) -> Vector2:
		return pc + Vector2((u_val - v_val) * 26.0, (u_val + v_val) * 13.0 - h_val)

	# 2. 호수 수면에 드리운 누각의 은은한 그림자 반영 (Water Reflection)
	var refl_poly: PackedVector2Array = PackedVector2Array([
		iso_pt.call(-0.85, 0.75, -2.0), iso_pt.call(0.85, 0.75, -2.0),
		iso_pt.call(0.60, 1.40, -2.0), iso_pt.call(-0.60, 1.40, -2.0)
	])
	FastDraw.poly(self, refl_poly, Color(0.02, 0.18, 0.28, 0.42))
	draw_line(iso_pt.call(-0.70, 1.0, -2.0), iso_pt.call(0.70, 1.0, -2.0), Color("38bdf8", 0.45), 1.0)

	# 3. 화강암 2단 장대석 입체 기단 (Plinth)
	# 상판 디딤면 (h = 4.0)
	var plinth_top: PackedVector2Array = PackedVector2Array([
		iso_pt.call(-0.75, -0.75, 4.0), iso_pt.call(0.75, -0.75, 4.0),
		iso_pt.call(0.75, 0.75, 4.0), iso_pt.call(-0.75, 0.75, 4.0)
	])
	FastDraw.poly(self, plinth_top, Color("cbd5e1"))
	# 남서쪽 입체 수직 벽면 (v = 0.75, h: 0..4)
	var plinth_sw: PackedVector2Array = PackedVector2Array([
		iso_pt.call(-0.75, 0.75, 4.0), iso_pt.call(0.75, 0.75, 4.0),
		iso_pt.call(0.75, 0.75, 0.0), iso_pt.call(-0.75, 0.75, 0.0)
	])
	FastDraw.poly(self, plinth_sw, Color("94a3b8"))
	# 남동쪽 입체 수직 벽면 (u = 0.75, h: 0..4)
	var plinth_se: PackedVector2Array = PackedVector2Array([
		iso_pt.call(0.75, -0.75, 4.0), iso_pt.call(0.75, 0.75, 4.0),
		iso_pt.call(0.75, 0.75, 0.0), iso_pt.call(0.75, -0.75, 0.0)
	])
	FastDraw.poly(self, plinth_se, Color("64748b"))
	draw_line(iso_pt.call(-0.75, 0.75, 4.0), iso_pt.call(0.75, 0.75, 4.0), Color("f1f5f9"), 1.2)
	draw_line(iso_pt.call(0.75, -0.75, 4.0), iso_pt.call(0.75, 0.75, 4.0), Color("94a3b8"), 1.0)

	# 4. 우물마루 목재 바닥 (h = 4.2)
	var floor_poly: PackedVector2Array = PackedVector2Array([
		iso_pt.call(-0.66, -0.66, 4.2), iso_pt.call(0.66, -0.66, 4.2),
		iso_pt.call(0.66, 0.66, 4.2), iso_pt.call(-0.66, 0.66, 4.2)
	])
	FastDraw.poly(self, floor_poly, Color("b45309"))
	# 우물마루 청판 줄눈
	for ki: int in range(1, 4):
		var k_frac: float = -0.66 + float(ki) * 0.33
		draw_line(iso_pt.call(k_frac, -0.66, 4.2), iso_pt.call(k_frac, 0.66, 4.2), Color("78350f"), 0.8)

	# 5. 전통 목조 계자난간 (h: 4.2 ~ 7.5)
	var rail_pts: Array[Vector2] = [
		iso_pt.call(-0.68, 0.68, 7.5), iso_pt.call(0.68, 0.68, 7.5),
		iso_pt.call(0.68, -0.68, 7.5)
	]
	draw_line(rail_pts[0], rail_pts[1], Color("991b1b"), 1.6)
	draw_line(rail_pts[1], rail_pts[2], Color("7f1d1d"), 1.6)
	# 난간 동자 살대
	for ri: int in range(5):
		var rf: float = -0.60 + float(ri) * 0.30
		draw_line(iso_pt.call(rf, 0.68, 4.2), iso_pt.call(rf, 0.68, 7.5), Color("991b1b"), 1.2)

	# 6. 주칠 붉은 목조 기둥 4개 (홍주 4본, h: 4.2 ~ 18.0)
	var col_coords: Array[Vector2] = [
		Vector2(-0.52, -0.52), Vector2(0.52, -0.52), # 뒤쪽 기둥 2개
		Vector2(-0.52, 0.52), Vector2(0.52, 0.52)    # 앞쪽 기둥 2개
	]
	for c_pos: Vector2 in col_coords:
		var p_base: Vector2 = iso_pt.call(c_pos.x, c_pos.y, 4.2)
		var p_top: Vector2 = iso_pt.call(c_pos.x, c_pos.y, 18.0)
		# 초석
		FastDraw.circle(self, p_base, 1.6, Color("64748b"))
		# 기둥 본체
		draw_line(p_base, p_top, Color("8f261e"), 2.2)
		draw_line(p_base - Vector2(0.6, 0.0), p_top - Vector2(0.6, 0.0), Color("bc3c30"), 0.8)

	# 7. 처마 아래 청록 비취 단청 창방 띠 (h = 17.5 ~ 18.5)
	var danc_sw0: Vector2 = iso_pt.call(-0.58, 0.58, 18.0)
	var danc_sw1: Vector2 = iso_pt.call(0.58, 0.58, 18.0)
	var danc_se1: Vector2 = iso_pt.call(0.58, -0.58, 18.0)
	draw_line(danc_sw0, danc_sw1, Color("1b7570"), 2.0)
	draw_line(danc_sw1, danc_se1, Color("134e4a"), 2.0)
	draw_line(danc_sw0, danc_sw1, Color("2dd4bf"), 0.8)
	FastDraw.circle(self, danc_sw0, 1.2, Color("dc2626"))
	FastDraw.circle(self, danc_sw1, 1.2, Color("dc2626"))

	# '迎華亭' 미니 금빛 편액
	var sign_c: Vector2 = iso_pt.call(0.0, 0.58, 19.5)
	draw_rect(Rect2(sign_c - Vector2(6.5, 2.0), Vector2(13.0, 4.0)), Color("0f172a"))
	draw_rect(Rect2(sign_c - Vector2(6.5, 2.0), Vector2(13.0, 4.0)), Color("eab308"), false, 0.8)
	draw_line(sign_c - Vector2(4.5, 0.0), sign_c + Vector2(4.5, 0.0), Color("fde047"), 1.0)

	# 8. 2.5D 날렵한 사모(모임) 기와지붕 (안허리곡과 앙곡, h: 18.0 ~ 32.0)
	var _e_north: Vector2 = iso_pt.call(-0.95, -0.95, 18.0)
	var e_west: Vector2 = iso_pt.call(-0.95, 0.95, 18.0)
	var e_south: Vector2 = iso_pt.call(0.95, 0.95, 18.0)
	var e_east: Vector2 = iso_pt.call(0.95, -0.95, 18.0)
	var apex: Vector2 = iso_pt.call(0.0, 0.0, 32.0) # 지붕 상륜부 꼭대기

	# 남서쪽 면 (햇빛 받는 면: e_west -> apex -> e_south)
	var roof_sw: PackedVector2Array = PackedVector2Array([e_west, apex, e_south])
	FastDraw.poly(self, roof_sw, Color("dbe4eb") if snow else Color("253346"))
	# 남동쪽 면 (음영 진 면: e_south -> apex -> e_east)
	var roof_se: PackedVector2Array = PackedVector2Array([e_south, apex, e_east])
	FastDraw.poly(self, roof_se, Color("cbd5e1") if snow else Color("141c2b"))

	# 기와 줄골 (수키와/암키와 골)
	var ridge_col := Color("cbd5dc") if snow else Color("384a62")
	for ri: int in range(1, 4):
		var frac: float = float(ri) * 0.25
		var r_edge: Vector2 = e_west.lerp(e_south, frac)
		draw_line(apex, r_edge, ridge_col, 0.9)
	for ri2: int in range(1, 4):
		var frac2: float = float(ri2) * 0.25
		var r_edge2: Vector2 = e_south.lerp(e_east, frac2)
		draw_line(apex, r_edge2, ridge_col.darkened(0.15), 0.9)

	# 네 모서리 추녀마루 (내림마루 백회 양성바름)
	var hip_col := Color("f8fafc") if snow else Color("64748b")
	draw_line(apex, e_west, hip_col, 1.6)
	draw_line(apex, e_south, hip_col, 1.8)
	draw_line(apex, e_east, hip_col, 1.6)

	# 처마선 앙곡 강조
	draw_line(e_west, e_south, Color("f8fafc") if snow else Color("1e293b"), 1.8)
	draw_line(e_south, e_east, Color("f8fafc") if snow else Color("0f172a"), 1.8)

	# 9. 지붕 꼭대기 중앙 백자/청동 절병통(節甁桶, 호리병 상륜부 장식)
	draw_line(apex, apex - Vector2(0.0, 5.0), Color("94a3b8"), 1.4)
	FastDraw.circle(self, apex - Vector2(0.0, 3.0), 2.2, Color("f8fafc")) # 둥근 몸통
	FastDraw.circle(self, apex - Vector2(0.0, 6.0), 1.4, Color("facc15")) # 금빛 꼭지
	draw_line(apex - Vector2(0.0, 6.0), apex - Vector2(0.0, 8.5), Color("fde047"), 1.0)

## 만석거 북안 나루터 선착장과 정박한 나룻배
func _draw_manseokgeo_dock(c: Vector2, _p_n: Vector2, _p_e: Vector2, _p_s: Vector2, _p_w: Vector2) -> void:
	FastDraw.poly(self, _diamond(c, 1.02), Color("65a30d"))

	# 1. 호수 쪽으로 돌출된 화강암 돌계단 선착장
	var dock_pts: PackedVector2Array = PackedVector2Array([
		c + Vector2(-12.0, -2.0), c + Vector2(12.0, -8.0),
		c + Vector2(16.0, 9.0), c + Vector2(-8.0, 15.0)
	])
	FastDraw.poly(self, dock_pts, Color("94a3b8"))
	draw_line(c + Vector2(-12.0, -2.0), c + Vector2(16.0, 9.0), Color("cbd5e1"), 1.6)
	# 3단 화강암 계단 줄눈
	draw_line(c + Vector2(-10.0, 2.0), c + Vector2(14.0, -4.0), Color("64748b"), 1.0)
	draw_line(c + Vector2(-8.0, 6.0), c + Vector2(12.0, 0.0), Color("64748b"), 1.0)
	draw_line(c + Vector2(-6.0, 10.0), c + Vector2(10.0, 4.0), Color("64748b"), 1.0)

	# 2. 나무 계선주 (말뚝)
	var post_p: Vector2 = c + Vector2(13.0, 5.0)
	draw_rect(Rect2(post_p - Vector2(1.2, 7.0), Vector2(2.4, 8.0)), Color("451a03"))
	FastDraw.circle(self, post_p - Vector2(0.0, 7.0), 1.2, Color("78350f"))

	# 3. 물 위에 정박해 있는 디테일한 조선 목선 (나룻배)
	var boat_p: Vector2 = c + Vector2(20.0, 13.0)
	# 배 몸통 외형 (선미와 이물)
	FastDraw.poly(self, PackedVector2Array([
		boat_p + Vector2(-12.0, 0.0), boat_p + Vector2(0.0, -5.0),
		boat_p + Vector2(12.0, 2.5), boat_p + Vector2(2.0, 7.5)
	]), Color("854d0e"))
	# 배 안쪽 우물마루 판자
	FastDraw.poly(self, PackedVector2Array([
		boat_p + Vector2(-9.0, 0.0), boat_p + Vector2(0.0, -3.2),
		boat_p + Vector2(9.0, 1.8), boat_p + Vector2(1.5, 5.0)
	]), Color("543018"))
	draw_line(boat_p + Vector2(-6.0, -0.5), boat_p + Vector2(6.0, 2.2), Color("a16207"), 0.8)

	# 노(Oar)와 삿대
	draw_line(boat_p - Vector2(4.0, 6.0), boat_p + Vector2(6.0, 8.0), Color("ca8a04"), 1.3)
	FastDraw.circle(self, boat_p + Vector2(6.0, 8.0), 1.0, Color("eab308"))
	# 계선 밧줄
	draw_line(post_p, boat_p - Vector2(9.0, 0.0), Color("fde68a"), 1.0)
	# 배 주위 물결 포말
	draw_line(boat_p + Vector2(-10.0, 4.0), boat_p + Vector2(10.0, 6.0), Color("cffafe", 0.7), 0.8)

## 만석거 남안 대유둔전 방류 석조 홍예 수문 (Sluice Weir) — 2련 홍예 아치와 쏟아지는 폭포수
func _draw_manseokgeo_sluice(c: Vector2, _p_n: Vector2, _p_e: Vector2, _p_s: Vector2, _p_w: Vector2) -> void:
	FastDraw.poly(self, _diamond(c, 1.02), Color("65a30d"))
	var sp_c: Vector2 = c + Vector2(0.0, -3.0)

	# 1. 견고한 화강암 석조 수문 벽체
	draw_rect(Rect2(sp_c - Vector2(16.0, 10.0), Vector2(32.0, 16.0)), Color("64748b"))
	draw_rect(Rect2(sp_c - Vector2(17.0, 11.0), Vector2(34.0, 3.0)), Color("94a3b8")) # 수문 상판 장대석
	draw_line(sp_c - Vector2(17.0, 11.0), sp_c + Vector2(17.0, -11.0), Color("cbd5e1"), 1.2)

	# 화강암 면석 줄눈
	for ly: int in range(1, 4):
		var y_off: float = -10.0 + float(ly) * 3.5
		draw_line(sp_c + Vector2(-16.0, y_off), sp_c + Vector2(16.0, y_off), Color("475569"), 0.8)

	# 홍예 수문 아치 2련
	FastDraw.circle(self, sp_c + Vector2(-7.0, 1.0), 5.0, Color("0f172a"))
	FastDraw.circle(self, sp_c + Vector2(7.0, 1.0), 5.0, Color("0f172a"))
	# 홍예석 테두리 (Voussoirs)
	FastDraw.arc(self, sp_c + Vector2(-7.0, 1.0), 5.5, PI, PI * 2.0, 8, Color("cbd5e1"), 1.2)
	FastDraw.arc(self, sp_c + Vector2(7.0, 1.0), 5.5, PI, PI * 2.0, 8, Color("cbd5e1"), 1.2)

	# 수문 도르래 및 권양기 목재 구조
	draw_line(sp_c - Vector2(7.0, 10.0), sp_c - Vector2(7.0, 17.0), Color("543018"), 1.6)
	draw_line(sp_c + Vector2(7.0, 10.0), sp_c + Vector2(7.0, 17.0), Color("543018"), 1.6)
	draw_line(sp_c - Vector2(9.0, 17.0), sp_c + Vector2(9.0, 17.0), Color("78350f"), 1.4)
	# 쇠사슬 도르래
	FastDraw.circle(self, sp_c - Vector2(7.0, 15.0), 1.2, Color("94a3b8"))
	FastDraw.circle(self, sp_c + Vector2(7.0, 15.0), 1.2, Color("94a3b8"))

	# 2. 대유둔전으로 쏟아지는 거센 백색 포말의 폭포수
	var water_poly: PackedVector2Array = PackedVector2Array([
		sp_c + Vector2(-11.0, 3.0), sp_c + Vector2(11.0, 3.0),
		c + Vector2(14.0, 15.0), c + Vector2(-14.0, 15.0)
	])
	FastDraw.poly(self, water_poly, Color("bae6fd"))
	# 거센 물줄기 선들
	draw_line(sp_c + Vector2(-7.0, 3.0), c + Vector2(-9.0, 15.0), Color("ffffff"), 1.6)
	draw_line(sp_c + Vector2(7.0, 3.0), c + Vector2(9.0, 15.0), Color("ffffff"), 1.6)
	draw_line(sp_c, c + Vector2(0.0, 15.0), Color("ffffff"), 1.4)
	# 하단 물보라 미스트
	FastDraw.circle(self, c + Vector2(-6.0, 14.0), 2.5, Color(1.0, 1.0, 1.0, 0.75))
	FastDraw.circle(self, c + Vector2(6.0, 14.0), 2.5, Color(1.0, 1.0, 1.0, 0.75))
	FastDraw.circle(self, c + Vector2(0.0, 15.0), 2.0, Color(1.0, 1.0, 1.0, 0.85))

## ─────────────────────────────────────────────── 축만제(祝萬堤·서호) 6x6 전용 2.5D 대호수 렌더러
## 서호낙조의 따스한 황금빛 물비늘, 깊은 코발트 블루 심연, 2.5D 사모 기와 항미정(杭眉亭)과 능수버들 산책로
func _draw_chukmanje_part(rel: Vector2i, c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2, tile := Vector2i(-1, -1), anchor := Vector2i(-1, -1)) -> void:
	# [고품질 PNG 전면 전환] 6x6 단일 고화질 PNG 텍스처 단일 드로우콜 렌더링
	var season_sfx: String = SeasonColorFilter.get_current_season_suffix(current_season)
	var lake_tex: Texture2D = SpriteCacheManager.get_seasonal_or_base_texture(
		"buildings", "chukmanje", season_sfx, Vector2i(448, 320)
	)
	if lake_tex != null:
		# PORT-TRACE [호수 안 보임]: 기준 칸(anchor)은 부지 왼쪽 위가 아니라 안쪽(2,2)이다 → 부지 칸 목록의 가장 앞 칸에서 그린다
		var front_hit := rel == Vector2i(5, 5)
		if tile.x >= 0 and grid.in_bounds(anchor.x, anchor.y) and grid.grid[anchor.y][anchor.x].has("site_tiles"):
			front_hit = tile == _group_front_tile(anchor)
		if front_hit:
			# PORT-TRACE [호수 그림 정합]: 그림(448x320)은 바닥 마름모가 2:1이 아니고(좌우 꼭짓점 y≈181, 아래 꼭짓점 y≈319) 7x7 폭이라
			# 6x6 부지(가로 384, 마름모 높이 192)에 맞게 가로 0.857·세로 0.696으로 줄여, 가장 앞 칸(5,5)에서 한 번에 그린다
			# (뒤 칸에서 그리면 뒤에 그려지는 칸들의 바닥이 그림을 덮어 "그리다 만" 모습이 됐다).
			var shadow_col: Color = SeasonColorFilter.get_current_shadow_color(current_season)
			var body_tint: Color = SeasonColorFilter.get_current_tile_tint(current_season)
			var ft: Vector2i = tile if tile.x >= 0 else Vector2i(-1, -1)
			var sink := Vector2(0, 0.0) # 만석거: 두꺼운 석축 아랫단이 땅에 묻혀 떠 보이지 않게
			if ft.x >= 0 and _draw_fitted(lake_tex, "chukmanje", cell_center(float(ft.x - 5), float(ft.y + 1), 1.0) + sink, cell_center(float(ft.x + 1), float(ft.y - 5), 1.0) + sink, cell_center(float(ft.x + 1), float(ft.y + 1), 1.0) + sink, body_tint, shadow_col):
				return
			var rect := Rect2(c.x - 192.0, c.y + 16.0 - 222.6, 384.0, 222.6)
			draw_texture_rect(lake_tex, Rect2(rect.position + Vector2(3.0, 4.0), rect.size), false, shadow_col)
			draw_texture_rect(lake_tex, rect, false, body_tint)
		return

	# 폴백: PNG 부재 시 절차적 레거시 드로잉
	var rx: int = clampi(rel.x, 0, 5)
	var ry: int = clampi(rel.y, 0, 5)
	var is_bank: bool = (rx == 0 or rx == 5 or ry == 0 or ry == 5)

	if is_bank:
		if rx == 1 and ry == 0:
			_draw_chukmanje_hangmijeong(c)
		elif rx == 4 and ry == 5:
			_draw_manseokgeo_sluice(c, p_n, p_e, p_s, p_w)
		else:
			_draw_chukmanje_bank(c, rx, ry, p_n, p_e, p_s, p_w)
	else:
		_draw_chukmanje_water(c, rx, ry)

## 서호 호수 수면 — 깊고 투명한 코발트 블루 심연과 서호낙조 황금빛 윤슬, 작은 나룻배
func _draw_chukmanje_water(c: Vector2, rx: int, ry: int) -> void:
	var dist_cen: float = sqrt(pow(float(rx) - 2.5, 2.0) + pow(float(ry) - 2.5, 2.0))
	var depth_t: float = clampf(1.0 - dist_cen / 3.4, 0.0, 1.0)
	var water_col: Color = Color("0284c7").lerp(Color("082f49"), depth_t * 0.8)
	FastDraw.poly(self, _diamond(c, 1.08), water_col)

	var water_deep: Color = Color("0369a1").lerp(Color("0f172a"), depth_t)
	FastDraw.poly(self, _diamond(c, 0.85), water_deep)

	# 서호낙조 은빛 및 황금빛 물비늘
	var h: int = absi(rx * 29 ^ ry * 47)
	FastDraw.polyline(self, PackedVector2Array([
		c + Vector2(-14.0, -2.0), c + Vector2(-3.0, 2.0), c + Vector2(11.0, -1.5)
	]), Color("38bdf8", 0.75), 1.1)
	if h % 2 == 0:
		FastDraw.polyline(self, PackedVector2Array([
			c + Vector2(-8.0, 5.5), c + Vector2(3.0, 8.5), c + Vector2(13.0, 4.5)
		]), Color("fbbf24", 0.65), 1.0)
		FastDraw.circle(self, c + Vector2(3.0, 8.5), 1.0, Color("fef08a", 0.85))

	# 서호 호수 위 평화로운 나룻배 (rx=3, ry=2)
	if rx == 3 and ry == 2:
		var bp2: Vector2 = c + Vector2(-2.0, 1.0)
		FastDraw.poly(self, PackedVector2Array([
			bp2 + Vector2(-12.0, 3.0), bp2 + Vector2(12.0, 3.0),
			bp2 + Vector2(8.0, 7.0), bp2 + Vector2(-8.0, 7.0)
		]), Color(0.01, 0.15, 0.25, 0.35))
		FastDraw.poly(self, PackedVector2Array([
			bp2 + Vector2(-11.0, 0.0), bp2 + Vector2(0.0, -4.0),
			bp2 + Vector2(11.0, 1.2), bp2 + Vector2(1.5, 5.0)
		]), Color("854d0e"))
		FastDraw.poly(self, PackedVector2Array([
			bp2 + Vector2(-8.0, 0.2), bp2 + Vector2(0.0, -2.6),
			bp2 + Vector2(8.0, 1.0), bp2 + Vector2(1.2, 3.8)
		]), Color("543018"))
		draw_line(bp2 - Vector2(4.0, 5.0), bp2 + Vector2(5.0, 7.0), Color("ca8a04"), 1.2)
		draw_circle(bp2 + Vector2(-1.0, -2.0), 1.5, Color("f8fafc")) # 사공

	if current_season == "겨울":
		FastDraw.poly(self, _diamond(c, 0.98), Color(0.70, 0.84, 0.90, 0.80))
		draw_line(c + Vector2(-12.0, -3.0), c + Vector2(10.0, 5.0), Color("ffffff", 0.6), 0.8)

## 서호 제방 둑길 — 서호의 상징 능수버들 가로수 산책로
func _draw_chukmanje_bank(c: Vector2, rx: int, ry: int, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2) -> void:
	FastDraw.poly(self, _diamond(c, 1.02), Color("5b823e"))
	# 만석거 석축 로직 공유하여 코너와 직선 구간 연결
	_draw_manseokgeo_bank(c, rx, ry, p_n, p_e, p_s, p_w)

## 서호 명물 항미정(杭眉亭) 정자 — 소동파 시정의 고아한 2.5D 아이소메트릭 사모 기와 누각
func _draw_chukmanje_hangmijeong(c: Vector2) -> void:
	var season: String = band_master.current_season if band_master else current_season
	var snow: bool = season == "겨울"
	FastDraw.poly(self, _diamond(c, 1.02), Color("f1f5f9") if snow else Color("5b823e"))

	var pc: Vector2 = c + Vector2(0.0, -4.0)

	var iso_pt := func(u_val: float, v_val: float, h_val: float) -> Vector2:
		return pc + Vector2((u_val - v_val) * 24.0, (u_val + v_val) * 12.0 - h_val)

	# 1. 수면 반영
	var refl_poly: PackedVector2Array = PackedVector2Array([
		iso_pt.call(-0.80, 0.70, -2.0), iso_pt.call(0.80, 0.70, -2.0),
		iso_pt.call(0.55, 1.35, -2.0), iso_pt.call(-0.55, 1.35, -2.0)
	])
	FastDraw.poly(self, refl_poly, Color(0.01, 0.16, 0.28, 0.40))

	# 2. 2.5D 화강암 입체 기단
	var plinth_top: PackedVector2Array = PackedVector2Array([
		iso_pt.call(-0.70, -0.70, 3.5), iso_pt.call(0.70, -0.70, 3.5),
		iso_pt.call(0.70, 0.70, 3.5), iso_pt.call(-0.70, 0.70, 3.5)
	])
	FastDraw.poly(self, plinth_top, Color("cbd5e1"))
	var plinth_sw: PackedVector2Array = PackedVector2Array([
		iso_pt.call(-0.70, 0.70, 3.5), iso_pt.call(0.70, 0.70, 3.5),
		iso_pt.call(0.70, 0.70, 0.0), iso_pt.call(-0.70, 0.70, 0.0)
	])
	FastDraw.poly(self, plinth_sw, Color("94a3b8"))
	var plinth_se: PackedVector2Array = PackedVector2Array([
		iso_pt.call(0.70, -0.70, 3.5), iso_pt.call(0.70, 0.70, 3.5),
		iso_pt.call(0.70, 0.70, 0.0), iso_pt.call(0.70, -0.70, 0.0)
	])
	FastDraw.poly(self, plinth_se, Color("64748b"))

	# 3. 우물마루 목재 바닥
	var floor_poly: PackedVector2Array = PackedVector2Array([
		iso_pt.call(-0.62, -0.62, 3.8), iso_pt.call(0.62, -0.62, 3.8),
		iso_pt.call(0.62, 0.62, 3.8), iso_pt.call(-0.62, 0.62, 3.8)
	])
	FastDraw.poly(self, floor_poly, Color("b45309"))

	# 4. 붉은 기둥 4개 (홍주)
	var col_coords: Array[Vector2] = [
		Vector2(-0.48, -0.48), Vector2(0.48, -0.48),
		Vector2(-0.48, 0.48), Vector2(0.48, 0.48)
	]
	for c_pos: Vector2 in col_coords:
		var p_base: Vector2 = iso_pt.call(c_pos.x, c_pos.y, 3.8)
		var p_top: Vector2 = iso_pt.call(c_pos.x, c_pos.y, 16.5)
		draw_line(p_base, p_top, Color("8f261e"), 2.0)
		draw_line(p_base - Vector2(0.5, 0.0), p_top - Vector2(0.5, 0.0), Color("bc3c30"), 0.8)

	# 계자난간
	draw_line(iso_pt.call(-0.62, 0.62, 7.0), iso_pt.call(0.62, 0.62, 7.0), Color("991b1b"), 1.5)
	draw_line(iso_pt.call(0.62, 0.62, 7.0), iso_pt.call(0.62, -0.62, 7.0), Color("7f1d1d"), 1.5)

	# 단청 띠
	var danc_sw0: Vector2 = iso_pt.call(-0.52, 0.52, 16.5)
	var danc_sw1: Vector2 = iso_pt.call(0.52, 0.52, 16.5)
	var danc_se1: Vector2 = iso_pt.call(0.52, -0.52, 16.5)
	draw_line(danc_sw0, danc_sw1, Color("1b7570"), 1.8)
	draw_line(danc_sw1, danc_se1, Color("134e4a"), 1.8)

	# '杭眉亭' 미니 금빛 편액
	var sign_c: Vector2 = iso_pt.call(0.0, 0.52, 18.0)
	draw_rect(Rect2(sign_c - Vector2(6.0, 1.8), Vector2(12.0, 3.6)), Color("0f172a"))
	draw_rect(Rect2(sign_c - Vector2(6.0, 1.8), Vector2(12.0, 3.6)), Color("eab308"), false, 0.8)

	# 5. 2.5D 사모 기와지붕
	var _e_north: Vector2 = iso_pt.call(-0.90, -0.90, 16.5)
	var e_west: Vector2 = iso_pt.call(-0.90, 0.90, 16.5)
	var e_south: Vector2 = iso_pt.call(0.90, 0.90, 16.5)
	var e_east: Vector2 = iso_pt.call(0.90, -0.90, 16.5)
	var apex: Vector2 = iso_pt.call(0.0, 0.0, 29.5)

	FastDraw.poly(self, PackedVector2Array([e_west, apex, e_south]), Color("dbe4eb") if snow else Color("253346"))
	FastDraw.poly(self, PackedVector2Array([e_south, apex, e_east]), Color("cbd5e1") if snow else Color("141c2b"))

	# 기와 줄골
	var ridge_col := Color("cbd5dc") if snow else Color("384a62")
	for ri: int in range(1, 4):
		var frac: float = float(ri) * 0.25
		draw_line(apex, e_west.lerp(e_south, frac), ridge_col, 0.8)
		draw_line(apex, e_south.lerp(e_east, frac), ridge_col.darkened(0.15), 0.8)

	# 추녀마루
	var hip_col := Color("f8fafc") if snow else Color("64748b")
	draw_line(apex, e_west, hip_col, 1.5)
	draw_line(apex, e_south, hip_col, 1.6)
	draw_line(apex, e_east, hip_col, 1.5)

	draw_line(e_west, e_south, Color("f8fafc") if snow else Color("1e293b"), 1.6)
	draw_line(e_south, e_east, Color("f8fafc") if snow else Color("0f172a"), 1.6)

	# 꼭대기 백자 절병통
	draw_line(apex, apex - Vector2(0.0, 4.5), Color("94a3b8"), 1.2)
	FastDraw.circle(self, apex - Vector2(0.0, 2.5), 1.8, Color("f8fafc"))
	FastDraw.circle(self, apex - Vector2(0.0, 5.0), 1.2, Color("facc15"))


## 소나무 단품 렌더러
func _draw_pine_tree(p: Vector2, season: String) -> void:
	var col_leaf := Color("1e4725")
	var col_bark := Color("5e3019")
	if season == "겨울":
		col_leaf = Color("2a4e32")
	draw_line(p, p + Vector2(-1.0, -10.0), col_bark, 2.2)
	FastDraw.circle(self, p + Vector2(3.0, -11.0), 4.2, col_leaf)
	FastDraw.circle(self, p + Vector2(-4.0, -13.0), 4.6, col_leaf.lightened(0.08))
	FastDraw.circle(self, p + Vector2(1.0, -17.0), 5.0, col_leaf.lightened(0.15))
	if season == "겨울":
		FastDraw.circle(self, p + Vector2(1.0, -18.0), 3.0, Color(0.94, 0.96, 0.97, 0.8))


## ─────────────────────────────────────────────── 진휼소(賑恤所) 2x2 종합 구휼 복지 단지 렌더러
## rel: (0,0)=진휼청 본관, (1,0)=양곡 저장고(사창), (0,1)=취사 가마솥 마당(급식소), (1,1)=정문 삼문 및 배급 행렬
func _draw_jinhulso_part(rel: Vector2i, c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2) -> void:
	var season: String = band_master.current_season if band_master else current_season
	var snow: bool = season == "겨울"
	var ax: Vector2 = (p_e - p_n) * 0.5 # +x축 반벡터 (동남쪽)
	var ay: Vector2 = (p_w - p_n) * 0.5 # +y축 반벡터 (서남쪽)

	# 2.5D 아이소메트릭 로컬 투영 람다
	# u: 동서 축(-1.0 ~ 1.0, ax 방향), v: 남북 축(-1.0 ~ 1.0, ay 방향), h: 수직 높이(px)
	var iso := func(u_val: float, v_val: float, h_val: float = 0.0) -> Vector2:
		return c + ax * u_val + ay * v_val - Vector2(0.0, h_val)

	# 1. 2x2 단지 공통: 사계절 다진 황토 마당 기단
	var yard_col: Color = Color("edf2f7") if snow else Color("cfbe9e")
	FastDraw.poly(self, _diamond(c, 0.99), yard_col)
	FastDraw.polyline(self, PackedVector2Array(_diamond(c, 0.97)) + PackedVector2Array([_diamond(c, 0.97)[0]]), Color("cbd5e1") if snow else Color("a89675"), 1.0)

	# 화강암 박석 디딤돌 보행로 (정문에서 각 시설을 잇는 단아한 길)
	var paver_col: Color = Color("f1f5f9") if snow else Color("d6d0c4")
	if rel == Vector2i(1, 1):
		for pv: float in [-0.5, -0.1, 0.3, 0.7]:
			FastDraw.poly(self, _diamond(iso.call(0.0, pv, 0.0), 0.22), paver_col)
	elif rel == Vector2i(0, 1):
		for pu: float in [-0.4, 0.0, 0.4]:
			FastDraw.poly(self, _diamond(iso.call(pu, 0.5, 0.0), 0.20), paver_col)
	elif rel == Vector2i(1, 0):
		for pu2: float in [-0.5, -0.1, 0.3]:
			FastDraw.poly(self, _diamond(iso.call(pu2, 0.4, 0.0), 0.20), paver_col)
	elif rel == Vector2i(0, 0):
		for pv2: float in [0.4, 0.7]:
			FastDraw.poly(self, _diamond(iso.call(0.0, pv2, 0.0), 0.24), paver_col)

	# 2. 외곽 2.5D 입체 토포담 (흙돌담 + 기와지붕 캡)
	var draw_wall_seg := func(p0: Vector2, p1: Vector2) -> void:
		var wh: float = 6.5
		var q0: Vector2 = p0 - Vector2(0.0, wh)
		var q1: Vector2 = p1 - Vector2(0.0, wh)
		var wall_body_col: Color = Color("bca88a") if (p0 + p1).x * 0.5 >= c.x else Color("9e8a6e")
		FastDraw.poly(self, PackedVector2Array([p0, p1, q1, q0]), wall_body_col)
		draw_line(p0.lerp(q0, 0.3), p1.lerp(q1, 0.3), Color("6b543b"), 0.8)
		var roof_w_col: Color = Color("f8fafc") if snow else Color("2e333a")
		draw_line(q0, q1, roof_w_col, 2.4 if snow else 1.8)
		if snow:
			draw_line(q0 - Vector2(0.0, 1.0), q1 - Vector2(0.0, 1.0), Color("ffffff"), 1.2)

	if rel.y == 0:
		draw_wall_seg.call(p_w, p_n) # 북서쪽 외곽 담장
	if rel.x == 0:
		draw_wall_seg.call(p_s, p_w) # 남서쪽 외곽 담장
	if rel.x == 1 and rel.y == 0:
		draw_wall_seg.call(p_n, p_e) # 북동쪽 외곽 담장
	if rel == Vector2i(1, 1):
		draw_wall_seg.call(p_e, p_e.lerp(p_s, 0.32)) # 동남쪽 일부
		draw_wall_seg.call(p_s.lerp(p_w, 0.68), p_w) # 남서쪽 일부

	# 3. 4개 타일별 특화 시설 렌더링
	match rel:
		Vector2i(0, 0):
			# [본관 청사]: 화강암 2단 장대석 기단, 2.5D 개방형 대청, 붉은 기둥 홍주, 단청, 팔작기와지붕, [賑恤所] 현판, 집무 관원
			# A. 화강암 입체 기단 (Plinth)
			var b_h0: float = 0.0
			var b_h1: float = 4.5
			var b_top: PackedVector2Array = PackedVector2Array([
				iso.call(-0.76, -0.70, b_h1), iso.call(0.76, -0.70, b_h1),
				iso.call(0.76, 0.70, b_h1), iso.call(-0.76, 0.70, b_h1)
			])
			FastDraw.poly(self, b_top, Color("dcd6cb"))
			var b_sw: PackedVector2Array = PackedVector2Array([
				iso.call(-0.76, 0.70, b_h1), iso.call(0.76, 0.70, b_h1),
				iso.call(0.76, 0.70, b_h0), iso.call(-0.76, 0.70, b_h0)
			])
			FastDraw.poly(self, b_sw, Color("b0a89a"))
			var b_se: PackedVector2Array = PackedVector2Array([
				iso.call(0.76, -0.70, b_h1), iso.call(0.76, 0.70, b_h1),
				iso.call(0.76, 0.70, b_h0), iso.call(0.76, -0.70, b_h0)
			])
			FastDraw.poly(self, b_se, Color("857d72"))
			draw_line(iso.call(-0.76, 0.70, b_h1), iso.call(0.76, 0.70, b_h1), Color("eeeae0"), 1.0)

			# 정면 2단 화강암 돌계단
			for st: int in range(2):
				var st_v0: float = 0.70 + float(st) * 0.12
				var st_v1: float = st_v0 + 0.12
				var st_h: float = b_h1 - float(st + 1) * 2.2
				var st_poly: PackedVector2Array = PackedVector2Array([
					iso.call(-0.24, st_v0, st_h), iso.call(0.24, st_v0, st_h),
					iso.call(0.24, st_v1, st_h), iso.call(-0.24, st_v1, st_h)
				])
				FastDraw.poly(self, st_poly, Color("dcd6cb"))
				var st_front: PackedVector2Array = PackedVector2Array([
					iso.call(-0.24, st_v1, st_h), iso.call(0.24, st_v1, st_h),
					iso.call(0.24, st_v1, maxf(0.0, st_h - 2.2)), iso.call(-0.24, st_v1, maxf(0.0, st_h - 2.2))
				])
				FastDraw.poly(self, st_front, Color("a8a094"))

			# B. 우물마루 목재 대청 바닥 (h = 4.8)
			var floor_pts: PackedVector2Array = PackedVector2Array([
				iso.call(-0.68, -0.62, 4.8), iso.call(0.68, -0.62, 4.8),
				iso.call(0.68, 0.62, 4.8), iso.call(-0.68, 0.62, 4.8)
			])
			FastDraw.poly(self, floor_pts, Color("ba7d3c"))
			for k: int in range(1, 5):
				var ku: float = -0.68 + float(k) * 0.27
				draw_line(iso.call(ku, -0.62, 4.8), iso.call(ku, 0.62, 4.8), Color("8a5220"), 0.6)

			# C. 기둥 및 벽체 (h: 4.8..19.0)
			var p_base_h: float = 4.8
			var p_top_h: float = 19.0
			var cols_u: Array[float] = [-0.60, -0.20, 0.20, 0.60]

			# 후면 벽체(v = -0.58)
			var wall_back: PackedVector2Array = PackedVector2Array([
				iso.call(-0.62, -0.58, p_base_h), iso.call(0.62, -0.58, p_base_h),
				iso.call(0.62, -0.58, p_top_h - 2.0), iso.call(-0.62, -0.58, p_top_h - 2.0)
			])
			FastDraw.poly(self, wall_back, Color("f3ece0"))

			# 후면 기둥 4개
			for cu: float in cols_u:
				draw_line(iso.call(cu, -0.58, p_base_h), iso.call(cu, -0.58, p_top_h), Color("5c140e"), 1.8)

			# 좌측 협칸 창호문 (u: -0.60..-0.20, v = 0.0)
			var win_l: PackedVector2Array = PackedVector2Array([
				iso.call(-0.58, 0.0, p_base_h + 0.5), iso.call(-0.22, 0.0, p_base_h + 0.5),
				iso.call(-0.22, 0.0, p_top_h - 3.0), iso.call(-0.58, 0.0, p_top_h - 3.0)
			])
			FastDraw.poly(self, win_l, Color("faf7ee"))
			draw_line(iso.call(-0.40, 0.0, p_base_h + 0.5), iso.call(-0.40, 0.0, p_top_h - 3.0), Color("7c4d28"), 0.8)

			# 우측 협칸 창호문 (u: 0.20..0.60, v = 0.0)
			var win_r: PackedVector2Array = PackedVector2Array([
				iso.call(0.22, 0.0, p_base_h + 0.5), iso.call(0.58, 0.0, p_base_h + 0.5),
				iso.call(0.58, 0.0, p_top_h - 3.0), iso.call(0.22, 0.0, p_top_h - 3.0)
			])
			FastDraw.poly(self, win_r, Color("faf7ee"))
			draw_line(iso.call(0.40, 0.0, p_base_h + 0.5), iso.call(0.40, 0.0, p_top_h - 3.0), Color("7c4d28"), 0.8)

			# 중앙 어칸 대청 안쪽 음영 (u: -0.20..0.20)
			var okan: PackedVector2Array = PackedVector2Array([
				iso.call(-0.20, -0.50, p_base_h + 0.5), iso.call(0.20, -0.50, p_base_h + 0.5),
				iso.call(0.20, -0.50, p_top_h - 2.5), iso.call(-0.20, -0.50, p_top_h - 2.5)
			])
			FastDraw.poly(self, okan, Color(0.22, 0.16, 0.12, 0.90))

			# 집무 중인 진휼관 소품 (어칸 대청 내부)
			var desk_pt: Vector2 = iso.call(0.0, -0.20, p_base_h + 2.0)
			draw_rect(Rect2(desk_pt + Vector2(-6.0, -2.5), Vector2(12.0, 3.5)), Color("2c1d11"))
			draw_rect(Rect2(desk_pt + Vector2(-4.0, -3.5), Vector2(4.5, 2.5)), Color("2563eb"))
			draw_line(desk_pt + Vector2(-4.0, -2.2), desk_pt + Vector2(0.5, -2.2), Color("f8fafc"), 0.5)
			var off_pt: Vector2 = iso.call(0.0, -0.32, p_base_h + 3.0)
			FastDraw.circle(self, off_pt - Vector2(0.0, 8.0), 2.2, Color("1e3a8a"))
			draw_rect(Rect2(off_pt - Vector2(3.5, 10.0), Vector2(7.0, 2.0)), Color("0f172a"))
			FastDraw.circle(self, off_pt - Vector2(0.0, 5.5), 1.8, Color("fde047"))
			FastDraw.poly(self, PackedVector2Array([
				off_pt - Vector2(2.5, 4.0), off_pt + Vector2(2.5, 4.0),
				off_pt + Vector2(3.5, 0.0), off_pt - Vector2(3.5, 0.0)
			]), Color("1d4ed8"))
			draw_line(off_pt - Vector2(3.0, 2.0), off_pt + Vector2(3.0, 2.0), Color("f59e0b"), 0.9)

			# 전면 기둥 4본 (홍주, v = 0.58)
			for cu2: float in cols_u:
				var bp: Vector2 = iso.call(cu2, 0.58, p_base_h)
				var tp: Vector2 = iso.call(cu2, 0.58, p_top_h)
				draw_circle(bp, 1.8, Color("94a3b8"))
				draw_line(bp, tp, Color("94261e"), 2.4)
				draw_line(bp - Vector2(0.6, 0.0), tp - Vector2(0.6, 0.0), Color("b91c1c"), 0.8)

			# D. 창방 단청 띠 및 공포
			var dan_l: Vector2 = iso.call(-0.68, 0.58, p_top_h)
			var dan_r: Vector2 = iso.call(0.68, 0.58, p_top_h)
			draw_line(dan_l, dan_r, Color("0f766e"), 2.4)
			draw_line(dan_l - Vector2(0.0, 1.0), dan_r - Vector2(0.0, 1.0), Color("2dd4bf"), 0.8)
			for cu3: float in cols_u:
				var head_p: Vector2 = iso.call(cu3, 0.58, p_top_h)
				FastDraw.circle(self, head_p, 1.4, Color("dc2626"))

			# E. 날렵한 2.5D 팔작 기와지붕
			var eaves_h: float = p_top_h + 1.2
			var ridge_h: float = eaves_h + 14.5
			var r_l: Vector2 = iso.call(-0.55, 0.0, ridge_h)
			var r_r: Vector2 = iso.call(0.55, 0.0, ridge_h)

			var e_sw_l: Vector2 = iso.call(-0.95, 0.90, eaves_h) - Vector2(0.0, 3.5)
			var e_sw_ml: Vector2 = iso.call(-0.45, 0.90, eaves_h)
			var e_sw_c: Vector2 = iso.call(0.0, 0.90, eaves_h + 0.5)
			var e_sw_mr: Vector2 = iso.call(0.45, 0.90, eaves_h)
			var e_sw_r: Vector2 = iso.call(0.95, 0.90, eaves_h) - Vector2(0.0, 3.5)

			var roof_poly: PackedVector2Array = PackedVector2Array([
				r_l, r_r, e_sw_r, e_sw_mr, e_sw_c, e_sw_ml, e_sw_l
			])
			FastDraw.poly(self, roof_poly, Color("dbe4eb") if snow else Color("252d38"))

			for rki: int in range(8):
				var frk: float = float(rki) / 7.0
				var t_pt: Vector2 = r_l.lerp(r_r, frk)
				var b_pt: Vector2 = e_sw_l.lerp(e_sw_c, frk * 2.0) if frk <= 0.5 else e_sw_c.lerp(e_sw_r, (frk - 0.5) * 2.0)
				draw_line(t_pt, b_pt, Color("cbd5dc") if snow else Color("3d4653"), 0.9)

			var e_se_rear: Vector2 = iso.call(0.95, -0.90, eaves_h) - Vector2(0.0, 3.0)
			FastDraw.poly(self, PackedVector2Array([r_r, e_se_rear, e_sw_r]), Color("cbd5dc") if snow else Color("1a202c"))

			var gable_cen: Vector2 = r_r.lerp(e_se_rear.lerp(e_sw_r, 0.5), 0.45)
			FastDraw.poly(self, PackedVector2Array([
				r_r + Vector2(0.0, 1.8), gable_cen + Vector2(6.0, 4.5), gable_cen + Vector2(-4.0, 5.5)
			]), Color("f8fafc"))
			draw_line(r_r + Vector2(0.0, 1.8), gable_cen + Vector2(1.0, 5.0), Color("5c3a21"), 0.9)

			draw_line(r_l, r_r, Color("f8fafc"), 2.2)
			FastDraw.circle(self, r_l - Vector2(0.0, 1.6), 1.8, Color("0f172a"))
			FastDraw.circle(self, r_r - Vector2(0.0, 1.6), 1.8, Color("0f172a"))

			draw_line(e_sw_l, e_sw_c, Color("0f766e"), 1.3)
			draw_line(e_sw_c, e_sw_r, Color("0f766e"), 1.3)

			if snow:
				FastDraw.polyline(self, PackedVector2Array([e_sw_l, e_sw_ml, e_sw_c, e_sw_mr, e_sw_r]), Color("f8fafc", 0.96), 2.2)
				draw_line(e_sw_l, r_l, Color("f8fafc"), 1.6)
				draw_line(e_sw_r, r_r, Color("f8fafc"), 1.6)
				draw_line(e_se_rear, r_r, Color("f8fafc"), 1.6)

			# F. '賑恤所' 흑칠 금자 현판
			var plq_p: Vector2 = iso.call(0.0, 0.60, p_top_h - 1.5)
			draw_rect(Rect2(plq_p + Vector2(-11.0, -4.0), Vector2(22.0, 7.5)), Color("111827"))
			draw_rect(Rect2(plq_p + Vector2(-11.0, -4.0), Vector2(22.0, 7.5)), Color("eab308"), false, 0.9)
			draw_string(ThemeDB.fallback_font, plq_p + Vector2(-9.5, 2.0), "賑恤所", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color("fde047"))

		Vector2i(1, 0):
			# [양곡 창고]: 고상식 화강암 석축 기단, 목조 판벽 창고, 맞배 기와지붕, 마당 볏가마니 피라미드 적재, 저울대, 됫박
			var w_b_top: PackedVector2Array = PackedVector2Array([
				iso.call(-0.72, -0.65, 4.5), iso.call(0.72, -0.65, 4.5),
				iso.call(0.72, 0.40, 4.5), iso.call(-0.72, 0.40, 4.5)
			])
			FastDraw.poly(self, w_b_top, Color("d0c9bc"))
			var w_b_sw: PackedVector2Array = PackedVector2Array([
				iso.call(-0.72, 0.40, 4.5), iso.call(0.72, 0.40, 4.5),
				iso.call(0.72, 0.40, 0.0), iso.call(-0.72, 0.40, 0.0)
			])
			FastDraw.poly(self, w_b_sw, Color("9e968a"))
			var w_b_se: PackedVector2Array = PackedVector2Array([
				iso.call(0.72, -0.65, 4.5), iso.call(0.72, 0.40, 4.5),
				iso.call(0.72, 0.40, 0.0), iso.call(0.72, -0.65, 0.0)
			])
			FastDraw.poly(self, w_b_se, Color("7a7368"))
			for v_hole: float in [-0.35, 0.35]:
				var hp: Vector2 = iso.call(v_hole, 0.40, 2.2)
				draw_rect(Rect2(hp + Vector2(-3.0, -1.5), Vector2(6.0, 3.0)), Color("2c241c"))

			# 목조 판벽 창고 몸체
			var w_sw: PackedVector2Array = PackedVector2Array([
				iso.call(-0.68, 0.35, 17.0), iso.call(0.68, 0.35, 17.0),
				iso.call(0.68, 0.35, 4.5), iso.call(-0.68, 0.35, 4.5)
			])
			FastDraw.poly(self, w_sw, Color("b58e57"))
			var w_se: PackedVector2Array = PackedVector2Array([
				iso.call(0.68, -0.60, 17.0), iso.call(0.68, 0.35, 17.0),
				iso.call(0.68, 0.35, 4.5), iso.call(0.68, -0.60, 4.5)
			])
			FastDraw.poly(self, w_se, Color("7d5e34"))

			for wu: float in [-0.68, -0.22, 0.22, 0.68]:
				draw_line(iso.call(wu, 0.35, 4.5), iso.call(wu, 0.35, 17.0), Color("5a3d1e"), 1.8)
			draw_line(iso.call(-0.68, 0.35, 11.0), iso.call(0.68, 0.35, 11.0), Color("5a3d1e"), 1.4)

			# 창고 문과 철제 장석
			draw_line(iso.call(0.0, 0.35, 4.5), iso.call(0.0, 0.35, 13.0), Color("3d2612"), 1.2)
			var lock_p: Vector2 = iso.call(0.0, 0.35, 8.5)
			draw_rect(Rect2(lock_p + Vector2(-4.0, -1.5), Vector2(8.0, 3.0)), Color("1f2937"))
			FastDraw.circle(self, lock_p, 1.2, Color("d97706"))

			# 상부 빗살 환기창
			var vent_p: Vector2 = iso.call(0.0, 0.35, 14.5)
			draw_rect(Rect2(vent_p + Vector2(-6.0, -2.0), Vector2(12.0, 4.0)), Color("2c1d11"))
			for vi: int in range(4):
				var vx: float = -4.5 + float(vi) * 3.0
				draw_line(vent_p + Vector2(vx, -2.0), vent_p + Vector2(vx, 2.0), Color("8a5c30"), 0.8)

			# 창고 맞배 기와지붕
			var wr_eaves_h: float = 17.0
			var wr_ridge_h: float = wr_eaves_h + 12.0
			var wr_l: Vector2 = iso.call(-0.55, -0.15, wr_ridge_h)
			var wr_r: Vector2 = iso.call(0.55, -0.15, wr_ridge_h)

			var wr_sw_l: Vector2 = iso.call(-0.85, 0.55, wr_eaves_h)
			var wr_sw_r: Vector2 = iso.call(0.85, 0.55, wr_eaves_h)
			var wr_se_rear: Vector2 = iso.call(0.85, -0.85, wr_eaves_h)

			FastDraw.poly(self, PackedVector2Array([wr_l, wr_r, wr_sw_r, wr_sw_l]), Color("dbe4eb") if snow else Color("2c3542"))
			FastDraw.poly(self, PackedVector2Array([wr_r, wr_se_rear, wr_sw_r]), Color("cbd5dc") if snow else Color("1e242d"))

			for rki2: int in range(7):
				var frk2: float = float(rki2) / 6.0
				draw_line(wr_l.lerp(wr_r, frk2), wr_sw_l.lerp(wr_sw_r, frk2), Color("cbd5dc") if snow else Color("475569"), 0.8)

			draw_line(wr_l, wr_r, Color("f8fafc"), 2.2)
			if snow:
				draw_line(wr_sw_l, wr_sw_r, Color("f8fafc", 0.96), 2.0)
				draw_line(wr_sw_l, wr_l, Color("f8fafc"), 1.5)
				draw_line(wr_sw_r, wr_r, Color("f8fafc"), 1.5)
				draw_line(wr_se_rear, wr_r, Color("f8fafc"), 1.5)

			# 앞마당 볏가마니 피라미드 적재 더미
			var draw_bag := func(pos: Vector2, sz: Vector2, straw_c: Color) -> void:
				FastDraw.poly(self, PackedVector2Array([
					pos + Vector2(-sz.x * 0.5, -sz.y * 0.5), pos + Vector2(sz.x * 0.5, -sz.y * 0.5),
					pos + Vector2(sz.x * 0.5, sz.y * 0.5), pos + Vector2(-sz.x * 0.5, sz.y * 0.5)
				]), straw_c)
				draw_line(pos + Vector2(-sz.x * 0.5, 0.0), pos + Vector2(sz.x * 0.5, 0.0), Color("6b4c20"), 0.7)
				draw_line(pos + Vector2(-sz.x * 0.25, -sz.y * 0.5), pos + Vector2(-sz.x * 0.25, sz.y * 0.5), Color("6b4c20"), 0.7)
				draw_line(pos + Vector2(sz.x * 0.25, -sz.y * 0.5), pos + Vector2(sz.x * 0.25, sz.y * 0.5), Color("6b4c20"), 0.7)
				FastDraw.circle(self, pos + Vector2(-sz.x * 0.45, 0.0), 1.2, Color("e5c378"))

			var base_p: Vector2 = iso.call(-0.25, 0.75, 0.0)
			for bi: int in range(3):
				var bag_pt: Vector2 = base_p + Vector2(float(bi) * 8.0 - 8.0, float(bi) * 2.0 - 2.0)
				draw_bag.call(bag_pt, Vector2(8.5, 5.0), Color("c49a56"))
			for bi2: int in range(2):
				var bag_pt2: Vector2 = base_p + Vector2(float(bi2) * 8.0 - 4.0, float(bi2) * 2.0 - 5.5)
				draw_bag.call(bag_pt2, Vector2(8.5, 5.0), Color("d1a660"))
			var top_bag: Vector2 = base_p + Vector2(0.0, -9.0)
			draw_bag.call(top_bag, Vector2(8.5, 5.0), Color("dcb069"))

			# 흰 삼베 쌀자루
			var sack_p: Vector2 = base_p + Vector2(14.0, 1.0)
			FastDraw.circle(self, sack_p, 3.2, Color("f3ece0"))
			FastDraw.circle(self, sack_p + Vector2(3.5, -2.5), 2.8, Color("eae1cf"))
			draw_line(sack_p - Vector2(1.5, 2.5), sack_p + Vector2(1.5, 2.5), Color("8a6b42"), 0.8)

			# 대형 평점 저울 및 나무 됫박
			var sc_pt: Vector2 = iso.call(0.45, 0.70, 0.0)
			draw_line(sc_pt, sc_pt - Vector2(0.0, 13.0), Color("5c3a21"), 1.4)
			draw_line(sc_pt - Vector2(4.0, 0.0), sc_pt - Vector2(0.0, 13.0), Color("5c3a21"), 1.0)
			draw_line(sc_pt + Vector2(4.0, 0.0), sc_pt - Vector2(0.0, 13.0), Color("5c3a21"), 1.0)
			draw_line(sc_pt - Vector2(6.0, 11.5), sc_pt + Vector2(6.0, 11.5), Color("d97706"), 1.2)
			draw_line(sc_pt + Vector2(5.0, 11.5), sc_pt + Vector2(5.0, 15.5), Color("78350f"), 0.6)
			FastDraw.circle(self, sc_pt + Vector2(5.0, 16.0), 1.6, Color("b45309"))
			draw_rect(Rect2(sc_pt + Vector2(-8.0, -2.0), Vector2(4.5, 4.0)), Color("784c28"))
			FastDraw.circle(self, sc_pt + Vector2(-6.0, -2.5), 1.8, Color("fefefe"))

		Vector2i(0, 1):
			# [취사 가마솥 마당]: 통나무 4본 대형 삼베 차일 천막, 2구 무쇠 가마솥과 이글거리는 아궁이, 쌀죽 김 애니메이션, 주걱 든 취사군, 배식 평상
			var ch_h: float = 17.5
			var c_sw_l: Vector2 = iso.call(-0.75, 0.70, ch_h)
			var c_sw_r: Vector2 = iso.call(0.70, 0.70, ch_h)
			var c_se_rear: Vector2 = iso.call(0.70, -0.65, ch_h + 3.0)
			var c_sw_rear: Vector2 = iso.call(-0.75, -0.65, ch_h + 3.0)

			for pu_c: float in [-0.75, 0.70]:
				for pv_c: float in [-0.65, 0.70]:
					var ph_val: float = ch_h + (3.0 if pv_c < 0.0 else 0.0)
					draw_line(iso.call(pu_c, pv_c, 0.0), iso.call(pu_c, pv_c, ph_val), Color("5c3a21"), 1.6)

			var ch_poly: PackedVector2Array = PackedVector2Array([
				c_sw_rear, c_se_rear, c_se_rear.lerp(c_sw_r, 0.5) + Vector2(0.0, 1.2),
				c_sw_r, c_sw_r.lerp(c_sw_l, 0.5) + Vector2(0.0, 1.8), c_sw_l,
				c_sw_l.lerp(c_sw_rear, 0.5) + Vector2(0.0, 1.2)
			])
			FastDraw.poly(self, ch_poly, Color("f1ebd8") if not snow else Color("edf2f7"))
			draw_line(c_sw_rear, c_sw_r, Color("d5cbaf"), 1.0)
			draw_line(c_sw_l, c_se_rear, Color("d5cbaf"), 1.0)
			for rope_pt: Vector2 in [c_sw_l, c_sw_r]:
				draw_line(rope_pt, rope_pt + Vector2(0.0, 8.0), Color("8a6840"), 0.7)
			if snow:
				FastDraw.polyline(self, PackedVector2Array([c_sw_l, c_sw_r, c_se_rear]), Color("f8fafc"), 1.8)

			# 2구 무쇠 가마솥과 아궁이
			var k_cen: Vector2 = iso.call(0.0, -0.10, 0.0)
			var fur_pts: PackedVector2Array = PackedVector2Array([
				k_cen + Vector2(-15.0, -4.0), k_cen + Vector2(15.0, -4.0),
				k_cen + Vector2(13.0, 8.0), k_cen + Vector2(-13.0, 8.0)
			])
			FastDraw.poly(self, fur_pts, Color("4a392b"))

			for fx: float in [-8.0, 8.0]:
				var fire_p: Vector2 = k_cen + Vector2(fx, 4.0)
				FastDraw.circle(self, fire_p, 3.8, Color("1a120c"))
				FastDraw.circle(self, fire_p + Vector2(0.0, 0.5), 2.6, Color("dc2626"))
				FastDraw.circle(self, fire_p + Vector2(0.0, -0.5), 1.8, Color("ea580c"))
				FastDraw.circle(self, fire_p + Vector2(0.0, -1.2), 1.0, Color("fef08a"))

			for kx: float in [-8.0, 8.0]:
				var pot: Vector2 = k_cen + Vector2(kx, -2.5)
				FastDraw.circle(self, pot, 6.2, Color("1e1e1e"))
				FastDraw.circle(self, pot - Vector2(0.0, 0.8), 5.5, Color("383838"))
				FastDraw.circle(self, pot - Vector2(0.0, 1.2), 4.4, Color("fbf8ea"))
				FastDraw.circle(self, pot - Vector2(0.5, 1.8), 2.6, Color("f5eed6"))

			var lid_p: Vector2 = k_cen + Vector2(-8.0, -5.5)
			FastDraw.poly(self, PackedVector2Array([
				lid_p + Vector2(-5.0, 1.0), lid_p + Vector2(4.5, -2.0),
				lid_p + Vector2(3.5, -4.0), lid_p + Vector2(-5.5, -1.0)
			]), Color("6a4325"))
			FastDraw.circle(self, lid_p + Vector2(-0.5, -2.5), 1.0, Color("3d2311"))

			# 쌀죽 김 애니메이션 FX
			for ki: int in range(2):
				var pot_k: Vector2 = k_cen + Vector2(-8.0 if ki == 0 else 8.0, -4.0)
				for si: int in range(3):
					var s_phase: float = fmod(_anim * 1.5 + float(si) * 0.7 + float(ki) * 1.1, 2.2)
					var s_y: float = -4.0 - s_phase * 9.0
					var s_x: float = sin(s_phase * 2.8 + float(si)) * 2.5
					var s_r: float = 2.0 + s_phase * 2.2
					var s_alpha: float = clampf(0.65 - (s_phase / 2.2) * 0.65, 0.0, 0.65)
					FastDraw.circle(self, pot_k + Vector2(s_x, s_y), s_r, Color(1.0, 1.0, 1.0, s_alpha))

			# 주걱을 든 취사군
			var cook_p: Vector2 = k_cen + Vector2(16.0, 0.0)
			FastDraw.circle(self, cook_p - Vector2(0.0, 9.0), 2.0, Color("e0cfba"))
			draw_line(cook_p - Vector2(2.5, 9.5), cook_p + Vector2(2.5, 9.5), Color("3b82f6"), 1.0)
			FastDraw.poly(self, PackedVector2Array([
				cook_p - Vector2(2.5, 7.0), cook_p + Vector2(2.5, 7.0),
				cook_p + Vector2(3.5, -1.0), cook_p - Vector2(3.5, -1.0)
			]), Color("f5f5f4"))
			draw_line(cook_p - Vector2(1.5, -1.0), cook_p - Vector2(1.5, 5.0), Color("f5f5f4"), 1.6)
			draw_line(cook_p + Vector2(1.5, -1.0), cook_p + Vector2(1.5, 5.0), Color("f5f5f4"), 1.6)
			draw_line(cook_p - Vector2(2.0, 5.0), k_cen + Vector2(10.0, -1.5), Color("b45309"), 1.4)

			# 배식대 평상 및 구휼 사발 더미
			var tbl_p: Vector2 = iso.call(-0.15, 0.58, 0.0)
			draw_rect(Rect2(tbl_p + Vector2(-12.0, -3.0), Vector2(24.0, 4.5)), Color("8a572a"))
			draw_line(tbl_p + Vector2(-10.0, 1.5), tbl_p + Vector2(-10.0, 6.0), Color("5c3a1d"), 1.6)
			draw_line(tbl_p + Vector2(10.0, 1.5), tbl_p + Vector2(10.0, 6.0), Color("5c3a1d"), 1.6)
			for b_idx: int in range(3):
				var bowl_x: float = -8.0 + float(b_idx) * 8.0
				FastDraw.circle(self, tbl_p + Vector2(bowl_x, -4.0), 2.4, Color("6b3f1d"))
				FastDraw.circle(self, tbl_p + Vector2(bowl_x, -5.5), 2.2, Color("7c4a22"))
				FastDraw.circle(self, tbl_p + Vector2(bowl_x, -6.8), 2.0, Color("fef08a"))

			# 장작더미 및 옹기 물독
			var wood_p: Vector2 = iso.call(-0.60, 0.10, 0.0)
			for wi: int in range(4):
				var wy: float = float(wi) * 2.2
				draw_line(wood_p + Vector2(-5.0, wy - 3.0), wood_p + Vector2(5.0, wy - 4.5), Color("784c28"), 2.0)
			var jar_p: Vector2 = wood_p + Vector2(11.0, 0.0)
			FastDraw.circle(self, jar_p, 4.2, Color("4a2d18"))
			FastDraw.circle(self, jar_p - Vector2(0.0, 2.0), 3.2, Color("3b82f6"))

		Vector2i(1, 1):
			# [정문 및 배급 줄]: 위엄 있는 2.5D 솟을삼문, 높은 [賑] 황금빛 관청 깃발, 창을 든 순라군/포졸, 사발 든 백성 대기 행렬
			# A. 위엄 있는 2.5D 솟을삼문
			var gm_cols: Array[float] = [-0.40, -0.15, 0.15, 0.40]
			for gci: int in range(4):
				var gu_val: float = gm_cols[gci]
				var gh_val: float = 18.0 if (gci == 1 or gci == 2) else 14.0
				draw_line(iso.call(gu_val, 0.35, 0.0), iso.call(gu_val, 0.35, gh_val), Color("8a2e22"), 2.0)

			# 중앙 어칸 솟을지붕
			var cm_l: Vector2 = iso.call(-0.25, 0.35, 23.5)
			var cm_r: Vector2 = iso.call(0.25, 0.35, 23.5)
			var ce_l: Vector2 = iso.call(-0.28, 0.50, 18.0)
			var ce_r: Vector2 = iso.call(0.28, 0.50, 18.0)
			FastDraw.poly(self, PackedVector2Array([cm_l, cm_r, ce_r, ce_l]), Color("dbe4eb") if snow else Color("2c3542"))
			draw_line(cm_l, cm_r, Color("f8fafc"), 1.8)

			# 좌우 협칸 지붕
			FastDraw.poly(self, PackedVector2Array([
				iso.call(-0.52, 0.35, 19.0), iso.call(-0.22, 0.35, 19.0),
				iso.call(-0.24, 0.50, 14.0), iso.call(-0.54, 0.50, 14.0)
			]), Color("dbe4eb") if snow else Color("252d38"))
			FastDraw.poly(self, PackedVector2Array([
				iso.call(0.22, 0.35, 19.0), iso.call(0.52, 0.35, 19.0),
				iso.call(0.54, 0.50, 14.0), iso.call(0.24, 0.50, 14.0)
			]), Color("dbe4eb") if snow else Color("252d38"))

			if snow:
				draw_line(ce_l, ce_r, Color("f8fafc"), 1.8)
				draw_line(iso.call(-0.54, 0.50, 14.0), iso.call(-0.24, 0.50, 14.0), Color("f8fafc"), 1.6)
				draw_line(iso.call(0.24, 0.50, 14.0), iso.call(0.54, 0.50, 14.0), Color("f8fafc"), 1.6)

			# 열린 목조 대문짝
			var door_l: Vector2 = iso.call(-0.15, 0.35, 0.0)
			draw_line(door_l, door_l + Vector2(-3.5, -8.0), Color("5c3a21"), 1.8)
			var door_r: Vector2 = iso.call(0.15, 0.35, 0.0)
			draw_line(door_r, door_r + Vector2(3.5, -8.0), Color("5c3a21"), 1.8)

			# B. 웅장한 대형 [賑] 관청 깃발
			var f_base: Vector2 = iso.call(-0.55, 0.50, 0.0)
			draw_line(f_base, f_base - Vector2(0.0, 26.0), Color("2c1d11"), 2.0)
			FastDraw.circle(self, f_base - Vector2(0.0, 26.5), 1.6, Color("eab308"))
			var flag_poly: PackedVector2Array = PackedVector2Array([
				f_base - Vector2(0.0, 26.0),
				f_base - Vector2(15.0, 22.5),
				f_base - Vector2(0.0, 18.0)
			])
			FastDraw.poly(self, flag_poly, Color("f59e0b"))
			draw_line(f_base - Vector2(0.0, 26.0), f_base - Vector2(15.0, 22.5), Color("dc2626"), 1.0)
			draw_line(f_base - Vector2(15.0, 22.5), f_base - Vector2(0.0, 18.0), Color("dc2626"), 1.0)
			draw_string(ThemeDB.fallback_font, f_base - Vector2(10.0, 20.0), "賑", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("111827"))

			# C. 정문을 지키는 포졸
			var guard_p: Vector2 = iso.call(0.32, 0.55, 0.0)
			FastDraw.circle(self, guard_p - Vector2(0.0, 10.0), 2.2, Color("f5f5f4"))
			FastDraw.poly(self, PackedVector2Array([
				guard_p - Vector2(3.5, 11.5), guard_p + Vector2(3.5, 11.5),
				guard_p - Vector2(0.0, 15.0)
			]), Color("1f2937"))
			draw_line(guard_p - Vector2(0.0, 14.5), guard_p + Vector2(2.5, 12.0), Color("ef4444"), 1.0)
			FastDraw.poly(self, PackedVector2Array([
				guard_p - Vector2(2.5, 8.0), guard_p + Vector2(2.5, 8.0),
				guard_p + Vector2(3.5, 0.0), guard_p - Vector2(3.5, 0.0)
			]), Color("1e40af"))
			draw_line(guard_p - Vector2(1.5, 0.0), guard_p - Vector2(1.5, 5.0), Color("f5f5f4"), 1.4)
			draw_line(guard_p + Vector2(1.5, 0.0), guard_p + Vector2(1.5, 5.0), Color("f5f5f4"), 1.4)
			draw_line(guard_p + Vector2(4.0, 4.0), guard_p + Vector2(4.0, -14.0), Color("5c3a21"), 1.2)
			FastDraw.poly(self, PackedVector2Array([
				guard_p + Vector2(4.0, -17.0), guard_p + Vector2(2.5, -14.0), guard_p + Vector2(5.5, -14.0)
			]), Color("cbd5e1"))

			# D. 사발을 들고 배급을 기다리는 백성 대기 행렬 (4명)
			# 백성 1: 허리를 굽힌 노인
			var peo1: Vector2 = iso.call(-0.08, -0.05, 0.0)
			FastDraw.circle(self, peo1 - Vector2(0.0, 7.5), 1.8, Color("d1c2a5"))
			draw_line(peo1 - Vector2(1.0, 6.0), peo1 + Vector2(2.0, 0.0), Color("9e8b70"), 2.0)
			draw_line(peo1 + Vector2(1.0, 0.0), peo1 + Vector2(1.0, 4.0), Color("9e8b70"), 1.4)
			FastDraw.circle(self, peo1 + Vector2(-2.5, -2.5), 1.4, Color("fef08a"))

			# 백성 2: 아이를 안은 어머니
			var peo2: Vector2 = iso.call(-0.02, 0.18, 0.0)
			FastDraw.circle(self, peo2 - Vector2(0.0, 9.0), 2.0, Color("f5eedc"))
			FastDraw.circle(self, peo2 - Vector2(0.0, 10.5), 1.4, Color("1e293b"))
			FastDraw.poly(self, PackedVector2Array([
				peo2 - Vector2(2.2, 7.5), peo2 + Vector2(2.2, 7.5),
				peo2 + Vector2(3.5, 0.0), peo2 - Vector2(3.5, 0.0)
			]), Color("3b82f6"))
			FastDraw.circle(self, peo2 + Vector2(-2.2, -4.5), 1.3, Color("facc15"))

			# 백성 3: 댕기머리 어린아이
			var peo3: Vector2 = iso.call(0.10, 0.22, 0.0)
			FastDraw.circle(self, peo3 - Vector2(0.0, 5.5), 1.5, Color("f5eedc"))
			draw_line(peo3 - Vector2(0.0, 5.5), peo3 + Vector2(1.5, -2.5), Color("dc2626"), 1.0)
			FastDraw.poly(self, PackedVector2Array([
				peo3 - Vector2(1.6, 4.0), peo3 + Vector2(1.6, 4.0),
				peo3 + Vector2(2.2, 0.0), peo3 - Vector2(2.2, 0.0)
			]), Color("fde047"))
			FastDraw.circle(self, peo3 + Vector2(-2.0, -1.0), 1.2, Color("e5d2b1"))

			# 백성 4: 농민 장정
			var peo4: Vector2 = iso.call(0.0, 0.45, 0.0)
			FastDraw.circle(self, peo4 - Vector2(0.0, 9.5), 2.0, Color("e0cfba"))
			FastDraw.circle(self, peo4 - Vector2(0.0, 11.0), 1.2, Color("1f2937"))
			FastDraw.poly(self, PackedVector2Array([
				peo4 - Vector2(2.5, 7.5), peo4 + Vector2(2.5, 7.5),
				peo4 + Vector2(3.5, 0.0), peo4 - Vector2(3.5, 0.0)
			]), Color("e7e5e4"))
			draw_line(peo4 - Vector2(1.5, 0.0), peo4 - Vector2(1.5, 5.0), Color("e7e5e4"), 1.6)
			draw_line(peo4 + Vector2(1.5, 0.0), peo4 + Vector2(1.5, 5.0), Color("e7e5e4"), 1.6)
			FastDraw.circle(self, peo4 - Vector2(2.5, 2.5), 1.5, Color("fef08a"))


## 성곽 부속 시설의 성 안쪽(평지/순찰로) 방향 등각투영 2.5D 스크린 벡터 계산
func _get_inner_city_dir(x: int, y: int) -> Vector2:
	if grid == null or x < 0 or y < 0:
		return Vector2(0.5, 0.5).normalized()
	var best_d := Vector2.ZERO
	var best_score := -999.0
	for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		var nx := x + d.x
		var ny := y + d.y
		if not grid.in_bounds(nx, ny):
			continue
		var nt: Dictionary = grid.grid[ny][nx]
		var terr: String = nt.get("terrain", "")
		if terr == "outside":
			continue
		var score := 10.0
		var nb: String = nt.get("building", "")
		if nb in ["road", "stone_road"] or grid.is_patrol_road(nx, ny):
			score += 50.0
		elif not grid.is_wall_connector(nx, ny):
			score += 20.0
		if score > best_score:
			best_score = score
			best_d = Vector2(float(d.x), float(d.y))
	if best_d == Vector2.ZERO:
		best_d = Vector2(0, 1) # 기본값 남쪽(성 안쪽)
	return Vector2((best_d.x - best_d.y) * HW, (best_d.x + best_d.y) * HH).normalized()

## 성곽 부속 시설 진입 계단 (Access Stairs): 성 안쪽 방향 4단 화강암 석계단 + 디딤판 + 챌면 + 소맷돌
func _draw_access_stairs(c: Vector2, inner_dir: Vector2, stair_h: float = 10.0) -> void:
	var norm_dir: Vector2 = inner_dir.normalized()
	var perp_dir: Vector2 = Vector2(-norm_dir.y, norm_dir.x)
	var stair_w: float = 8.5 # 계단 반폭
	var num_steps: int = 4
	var step_length: float = 4.2
	var step_height: float = stair_h / float(num_steps)

	var start_pt: Vector2 = c + norm_dir * 8.0
	for i in range(num_steps):
		var t_start: Vector2 = start_pt + norm_dir * (float(i) * step_length)
		var t_end: Vector2 = start_pt + norm_dir * (float(i + 1) * step_length)
		var cur_h: float = stair_h - float(i) * step_height
		var nxt_h: float = stair_h - float(i + 1) * step_height

		# 디딤판 (Tread)
		var tread_pts := PackedVector2Array([
			t_start - perp_dir * stair_w - Vector2(0, cur_h),
			t_start + perp_dir * stair_w - Vector2(0, cur_h),
			t_end + perp_dir * stair_w - Vector2(0, cur_h),
			t_end - perp_dir * stair_w - Vector2(0, cur_h)
		])
		FastDraw.poly(self, tread_pts, Color("c8bda5"))
		FastDraw.polyline(self, PackedVector2Array([tread_pts[0], tread_pts[1], tread_pts[2], tread_pts[3], tread_pts[0]]), Color("7d725f"), 1.0)

		# 챌면 (Riser)
		var riser_pts := PackedVector2Array([
			t_end - perp_dir * stair_w - Vector2(0, cur_h),
			t_end + perp_dir * stair_w - Vector2(0, cur_h),
			t_end + perp_dir * stair_w - Vector2(0, nxt_h),
			t_end - perp_dir * stair_w - Vector2(0, nxt_h)
		])
		FastDraw.poly(self, riser_pts, Color("9b907a"))
		FastDraw.polyline(self, PackedVector2Array([riser_pts[0], riser_pts[1], riser_pts[2], riser_pts[3], riser_pts[0]]), Color("3a352f"), 1.0)

	# 양쪽 소맷돌 (난간석 Balustrade)
	var total_len: float = float(num_steps) * step_length
	var s_top: Vector2 = start_pt - Vector2(0, stair_h + 3.0)
	var s_bot: Vector2 = start_pt + norm_dir * total_len - Vector2(0, 3.0)
	for sign_w: float in [-1.0, 1.0]:
		var side_top: Vector2 = s_top + perp_dir * (stair_w * sign_w)
		var side_bot: Vector2 = s_bot + perp_dir * (stair_w * sign_w)
		draw_line(side_top, side_bot, Color("6f6452"), 2.4)
		draw_line(side_top + Vector2(0, 3.0), side_bot + Vector2(0, 3.0), Color("b3a78f"), 1.8)
		FastDraw.circle(self, side_bot, 2.0, Color("c8bda5"))
		FastDraw.circle(self, side_top, 2.0, Color("c8bda5"))

func _draw_seojangdae(c: Vector2, _p_n: Vector2, _p_e: Vector2, _p_s: Vector2, _p_w: Vector2, x: int = -1, y: int = -1, _t: Dictionary = {}) -> void:
	var wh := 14.0
	var base_poly := _diamond(c, 0.75)
	var deck_poly := _diamond(c - Vector2(0, wh), 0.75)
	_draw_stone_face(base_poly[2], base_poly[1], deck_poly[1], deck_poly[2], Color("8a8479"), Color("4a453e"), 2, 5)
	_draw_stone_face(base_poly[3], base_poly[2], deck_poly[2], deck_poly[3], Color("9e968b"), Color("4a453e"), 2, 5)
	FastDraw.poly(self, deck_poly, Color("54504a"))

	# 성 안쪽 방향 진입 계단
	if x >= 0 and y >= 0:
		var in_dir: Vector2 = _get_inner_city_dir(x, y)
		_draw_access_stairs(c, in_dir, wh)

	var pc := c - Vector2(0, wh)
	for dx in [-12, -4, 4, 12]:
		draw_rect(Rect2(pc + Vector2(dx - 1, -10), Vector2(2, 10)), Color("a82820"))
	draw_rect(Rect2(pc + Vector2(-14, -12), Vector2(28, 2)), Color("1a7060"))
	FastDraw.poly(self, PackedVector2Array([pc + Vector2(-17, -12), pc + Vector2(17, -12), pc + Vector2(12, -18), pc + Vector2(-12, -18)]), Color("2e343d"))

	for dx in [-8, 0, 8]:
		draw_rect(Rect2(pc + Vector2(dx - 1, -26), Vector2(2, 8)), Color("a82820"))
	var r2 := PackedVector2Array([pc + Vector2(-13, -26), pc + Vector2(13, -26), pc + Vector2(0, -35)])
	FastDraw.poly(self, r2, Color("22272e"))
	draw_line(pc + Vector2(-13, -26), pc + Vector2(0, -35), Color("e0ded8"), 1.5)
	draw_line(pc + Vector2(13, -26), pc + Vector2(0, -35), Color("e0ded8"), 1.5)

	# 펄럭이는 총지휘 장수기(수결 황룡기)
	var f_x := pc.x + 8
	var f_y := pc.y - 26
	draw_line(Vector2(f_x, f_y), Vector2(f_x, f_y - 22), Color("3d2a1a"), 2.0)
	var flag_wave := sin(_anim * 3.5) * 2.0
	FastDraw.poly(self, PackedVector2Array([
		Vector2(f_x, f_y - 22),
		Vector2(f_x + 14 + flag_wave, f_y - 17),
		Vector2(f_x, f_y - 12)
	]), Color("e8b01a"))
	# 장수 실루엣 (구선복 군관 지휘 연출)
	FastDraw.circle(self, pc + Vector2(-4, -15), 1.8, Color("141820")) # 벙거지 머리
	draw_rect(Rect2(pc + Vector2(-5.5, -13), Vector2(3.0, 5.0)), Color("1a4a6e")) # 푸른 철릭

func _draw_bongdon(c: Vector2, _p_n: Vector2, _p_e: Vector2, _p_s: Vector2, _p_w: Vector2, x: int = -1, y: int = -1, _t: Dictionary = {}) -> void:
	var wh := 12.0
	var base_poly := _diamond(c, 0.7)
	var deck_poly := _diamond(c - Vector2(0, wh), 0.7)
	_draw_stone_face(base_poly[2], base_poly[1], deck_poly[1], deck_poly[2], Color("3d3936"), Color("4a453e"), 2, 5)
	_draw_stone_face(base_poly[3], base_poly[2], deck_poly[2], deck_poly[3], Color("4d4844"), Color("4a453e"), 2, 5)
	FastDraw.poly(self, deck_poly, Color("58524c"))

	# 성 안쪽 방향 진입 계단
	if x >= 0 and y >= 0:
		var in_dir: Vector2 = _get_inner_city_dir(x, y)
		_draw_access_stairs(c, in_dir, wh)

	var pc := c - Vector2(0, wh)
	for i in range(5):
		var fx := pc.x - 14.0 + float(i) * 7.0
		var fy := pc.y
		draw_rect(Rect2(Vector2(fx - 2, fy - 18), Vector2(4, 18)), Color("383430"))
		draw_rect(Rect2(Vector2(fx - 3, fy - 21), Vector2(6, 3)), Color("544e48"))
		var anim_offset := sin(_anim * 2.0 + float(i)) * 2.0
		FastDraw.circle(self, Vector2(fx + anim_offset, fy - 25 - i * 1.5), 2.5, Color(0.9, 0.9, 0.9, 0.6))
		FastDraw.circle(self, Vector2(fx + anim_offset * 1.5, fy - 31 - i * 2.0), 3.5, Color(0.95, 0.95, 0.95, 0.4))
	# 봉수군(보초병) 실루엣
	FastDraw.circle(self, pc + Vector2(11, -3), 1.6, Color("1a1a1a"))
	draw_rect(Rect2(pc + Vector2(10, -1), Vector2(2.5, 4.0)), Color("7a2820"))

## [DEPRECATED] 구형 공심돈/포루 에셋 렌더러 - 신규 규격(_draw_gongsimdon3, _draw_poru2)으로 완전 대체됨
func _draw_gongsimdon(_c: Vector2, _p_n: Vector2, _p_e: Vector2, _p_s: Vector2, _p_w: Vector2, x: int = -1, y: int = -1, t: Dictionary = {}) -> void:
	if x >= 0 and y >= 0:
		if not t.has("gs3"):
			var base_el: float = float(t.get("elevation", 1.0))
			t["gs3"] = {"center": Vector2i(x, y), "axis": Vector2i(1, 0), "out": Vector2i(0, 1), "type": "seobuk", "elevation": base_el}
		_draw_gongsimdon3(t["gs3"])

func _draw_poru(_c: Vector2, _p_n: Vector2, _p_e: Vector2, _p_s: Vector2, _p_w: Vector2, x: int = -1, y: int = -1, t: Dictionary = {}) -> void:
	if x >= 0 and y >= 0:
		if not t.has("pr2"):
			var base_el: float = float(t.get("elevation", 1.0))
			t["pr2"] = {"start": Vector2i(x, y), "axis": Vector2i(1, 0), "out": Vector2i(0, 1), "type": "dong", "elevation": base_el}
		_draw_poru2(t["pr2"])

## 연무대(동장대): 지휘 대청마루, 월대 돌계단, 활쏘기 과녁 및 훈련병 상호작용
func _draw_yeonmudae(c: Vector2, _p_n: Vector2, _p_e: Vector2, _p_s: Vector2, _p_w: Vector2, x: int = -1, y: int = -1, _t: Dictionary = {}) -> void:
	var wh := 8.0
	var pc := c - Vector2(0, wh)
	FastDraw.poly(self, _diamond(c, 0.85), Color("8a8479"))
	FastDraw.poly(self, _diamond(c - Vector2(0, 3), 0.75), Color("9e988f"))
	FastDraw.poly(self, _diamond(pc, 0.65), Color("b0aaa0"))

	# 성 안쪽/마당 방향 진입 월대 돌계단
	var in_dir: Vector2 = _get_inner_city_dir(x, y) if (x >= 0 and y >= 0) else Vector2(0.5, 0.5)
	_draw_access_stairs(c, in_dir, wh)

	for col_x in [-16, -9, 0, 9, 16]:
		draw_rect(Rect2(Vector2(pc.x + col_x - 1, pc.y - 14), Vector2(2, 14)), Color("9e241c"))
	draw_rect(Rect2(Vector2(pc.x - 18, pc.y - 16), Vector2(36, 2)), Color("1a7260"))
	var rf := PackedVector2Array([
		Vector2(pc.x - 22, pc.y - 16),
		Vector2(pc.x + 22, pc.y - 16),
		Vector2(pc.x + 15, pc.y - 27),
		Vector2(pc.x - 15, pc.y - 27)
	])
	FastDraw.poly(self, rf, Color("262c35"))
	draw_line(Vector2(pc.x - 15, pc.y - 27), Vector2(pc.x + 15, pc.y - 27), Color("e8e6e0"), 2.0)

	# 1. 활쏘기 과녁판 (사정 사습터)
	var tgt_x := pc.x - 18
	var tgt_y := pc.y + 7
	FastDraw.circle(self, Vector2(tgt_x, tgt_y), 4.2, Color("e0ded8"))
	FastDraw.circle(self, Vector2(tgt_x, tgt_y), 2.8, Color("c22820"))
	FastDraw.circle(self, Vector2(tgt_x, tgt_y), 1.2, Color("e8b820"))
	draw_line(Vector2(tgt_x - 1.5, tgt_y - 1.0), Vector2(tgt_x + 3.5, tgt_y - 2.5), Color("2b1d14"), 1.2) # 과녁에 꽂힌 화살

	# 2. 마당 무예 훈련병 상호작용 (궁사 + 무예 검수 훈련 연출)
	# 사수(궁사): 과녁을 향해 활 시위를 당기는 모션
	var archer_p := pc + Vector2(10, 8)
	FastDraw.circle(self, archer_p - Vector2(0, 5), 1.6, Color("1a1815")) # 상투
	draw_rect(Rect2(archer_p.x - 1.5, archer_p.y - 4, 3, 5), Color("f5f5f0")) # 흰 저고리
	draw_rect(Rect2(archer_p.x - 1.5, archer_p.y - 2, 3, 3), Color("1a406c")) # 푸른 쾌자
	# 활과 화살 시위
	var draw_phase := fmod(_anim * 1.5, 3.0)
	var bow_pull := 2.0 if draw_phase > 1.2 else 0.5
	FastDraw.arc(self, archer_p + Vector2(-3, -2), 3.5, -PI * 0.4, PI * 0.4, 6, Color("5c3818"), 1.4)
	draw_line(archer_p + Vector2(-3, -4.5), archer_p + Vector2(-3 + bow_pull, -2), Color("dfdcd5"), 0.9)
	draw_line(archer_p + Vector2(-3, 0.5), archer_p + Vector2(-3 + bow_pull, -2), Color("dfdcd5"), 0.9)
	# 화살 궤적 (발사 순간)
	if draw_phase > 2.2:
		var arrow_t := (draw_phase - 2.2) / 0.8
		var arrow_head := (archer_p + Vector2(-3, -2)).lerp(Vector2(tgt_x, tgt_y), arrow_t)
		draw_line(arrow_head, arrow_head + Vector2(4, 1), Color("ffffff"), 1.2)

	# 검수(무예 수련병): 목검을 쥐고 대련하는 훈련병
	var swordsman_p := pc + Vector2(2, 14)
	FastDraw.circle(self, swordsman_p - Vector2(0, 5), 1.6, Color("1a1815"))
	draw_rect(Rect2(swordsman_p.x - 1.5, swordsman_p.y - 4, 3, 5), Color("f5f5f0"))
	draw_rect(Rect2(swordsman_p.x - 1.5, swordsman_p.y - 2, 3, 3), Color("8a2818")) # 붉은 쾌자
	var sword_swing := sin(_anim * 4.0) * 3.5
	draw_line(swordsman_p + Vector2(1, -2), swordsman_p + Vector2(6 + sword_swing, -6), Color("7a5024"), 1.6) # 목검

	# 군영 훈련 깃발
	var b_flag_x := pc.x + 20
	var b_flag_y := pc.y + 4
	draw_line(Vector2(b_flag_x, b_flag_y), Vector2(b_flag_x, b_flag_y - 18), Color("3d2a18"), 1.8)
	FastDraw.poly(self, PackedVector2Array([
		Vector2(b_flag_x, b_flag_y - 18),
		Vector2(b_flag_x + 9 + sin(_anim * 3.0) * 1.5, b_flag_y - 14),
		Vector2(b_flag_x, b_flag_y - 10)
	]), Color("1a628a"))

## ─────────────────────────────────────────────── 방화수류정(訪花隨柳亭)·용연(龍淵)
## PORT-TRACE [방화수류정·용연 입체 재설계]: 사용자 요청 "너무 평면적이다" — 화면에 사다리꼴을 겹쳐 쌓던 그림을
## 등각(아이소) 입체로 다시 그림. 실물 고증: 용연 가 용두바위 위에 화강암 석축 → 회색 전돌 기단(흰 十자 무늬)
## → 마루를 높인 누각(붉은 기둥·계자난간·띠살 분합문, 연못 쪽으로 내민 날개채는 사방이 트임) → 본채 팔작지붕과
## 날개채 팔작지붕이 十자로 엇갈림. 앞(연못 쪽)은 용연이 놓인 방향으로 자동으로 돌린다.
## 용연은 땅보다 낮게 파인 연못(먼 쪽 호안 안쪽 면이 보임) + 자연석 호안 + 둥근 섬과 소나무 + 물가 능수버들 + 계절별 수면.
const BH_GRANITE := Color("d2c7ae")
const BH_ROCK := Color("9a8f78")
const BH_BRICK := Color("857f76")
const BH_PILLAR := Color("a3342a")
const BH_DANCHEONG := Color("2e7d6b")
const BH_ROOF := Color("454b54")
const BH_WOOD := Color("6e4a2c")

## 2x2 안 국소 좌표(s=옆, f=연못 쪽, h=높이) → 화면
func _bh(C: Vector2, AX: Vector2, AY: Vector2, S: Vector2, F: Vector2, s: float, f: float, h: float) -> Vector2:
	return C + AX * (S.x * s + F.x * f) + AY * (S.y * s + F.y * f) - Vector2(0, h)

func _bh_rect(C: Vector2, AX: Vector2, AY: Vector2, S: Vector2, F: Vector2, s0: float, s1: float, f0: float, f1: float) -> PackedVector2Array:
	return PackedVector2Array([_bh(C, AX, AY, S, F, s0, f0, 0.0), _bh(C, AX, AY, S, F, s1, f0, 0.0), _bh(C, AX, AY, S, F, s1, f1, 0.0), _bh(C, AX, AY, S, F, s0, f1, 0.0)])

func _bh_poly(C: Vector2, AX: Vector2, AY: Vector2, S: Vector2, F: Vector2, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q: Vector2 in pts:
		out.append(_bh(C, AX, AY, S, F, q.x, q.y, 0.0))
	return out

## 다각형 변마다 [a, b, 바깥 법선(화면)] — 감긴 방향(부호 넓이)으로 바깥쪽을 정해 오목한 다각형도 맞다
func _bh_edges(base: PackedVector2Array) -> Array:
	var n := base.size()
	var area := 0.0
	for i in range(n):
		var p: Vector2 = base[i]
		var q: Vector2 = base[(i + 1) % n]
		area += p.x * q.y - q.x * p.y
	var out: Array = []
	for i in range(n):
		var a: Vector2 = base[i]
		var b: Vector2 = base[(i + 1) % n]
		var e := b - a
		if e.length() < 0.01:
			continue
		var nrm := Vector2(e.y, -e.x).normalized() if area > 0.0 else Vector2(-e.y, e.x).normalized()
		out.append([a, b, nrm])
	return out

## 바닥 다각형(화면 좌표, 높이 0 기준) 기둥: 화면 앞쪽을 향한 옆면만 뒤→앞 순으로(오른쪽을 향할수록 밝게), 그다음 윗면.
## 반환: 보이는 옆면 [[a, b, 법선]] — 줄눈·무늬를 덧그릴 때 씀. top.a == 0이면 윗면 생략.
func _bh_prism(base: PackedVector2Array, h0: float, h1: float, side: Color, top: Color) -> Array:
	var faces: Array = []
	for fc: Array in _bh_edges(base):
		if (fc[2] as Vector2).y > 0.02:
			faces.append(fc)
	faces.sort_custom(func(p, q): return ((p[0] as Vector2) + (p[1] as Vector2)).y < ((q[0] as Vector2) + (q[1] as Vector2)).y)
	var lo := Vector2(0, h0)
	var hi := Vector2(0, h1)
	for fc: Array in faces:
		var a: Vector2 = fc[0]
		var b: Vector2 = fc[1]
		var sh: float = 0.16 * (fc[2] as Vector2).x
		var col := side.lightened(sh) if sh > 0.0 else side.darkened(-sh)
		MarketArt.draw_safe_quad(self, a - lo, b - lo, b - hi, a - hi, col)
	if top.a > 0.0:
		var tp := PackedVector2Array()
		for p2: Vector2 in base:
			tp.append(p2 - hi)
		FastDraw.poly(self, tp, top)
	# PORT-TRACE [성곽 새 단장]: 보이는 면 외곽선
	for fc2: Array in faces:
		var a2: Vector2 = fc2[0]
		var b2: Vector2 = fc2[1]
		FastDraw.polyline(self, PackedVector2Array([a2 - hi, a2 - lo, b2 - lo, b2 - hi, a2 - hi]), FT_OUT, 0.8)
	return faces

## 보이는 옆면마다 돌·벽돌 줄눈: 가로 rows단 + 단마다 엇갈린 세로 줄눈(unit px 간격)
func _bh_courses(faces: Array, h0: float, h1: float, rows: int, unit: float, col: Color) -> void:
	for fc: Array in faces:
		var a: Vector2 = fc[0]
		var b: Vector2 = fc[1]
		var cols := maxi(1, int((b - a).length() / unit))
		for r in range(rows):
			var hb := lerpf(h0, h1, float(r) / float(rows))
			var ht := lerpf(h0, h1, float(r + 1) / float(rows))
			if r > 0:
				draw_line(a - Vector2(0, hb), b - Vector2(0, hb), col, 0.7)
			var off := 0.5 if r % 2 == 1 else 0.0
			for k in range(cols):
				var tt := (float(k) + off) / float(cols)
				if tt < 0.04:
					continue
				var p := a.lerp(b, tt)
				draw_line(p - Vector2(0, hb), p - Vector2(0, ht), col, 0.6)

func _bh_ell(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(12):
		var th := TAU * float(i) / 12.0
		pts.append(c + Vector2(cos(th) * rx, sin(th) * ry))
	FastDraw.poly(self, pts, col)

func _bh_grass(season: String) -> Color:
	match season:
		"봄": return Color("78a24e")
		"여름": return Color("5f8f3e")
		"가을": return Color("98904e")
		"겨울": return Color("dfe5e8")
	return Color("6a9a46")

## 계자난간 한 변(a·b는 높이 0 기준 화면점, h=마루 높이): 아래 궁판 + 난간동자 + 두 줄 난간대(위는 굵은 돌란대)
func _bh_rail(a: Vector2, b: Vector2, h: float) -> void:
	var lo := Vector2(0, h)
	MarketArt.draw_safe_quad(self, a - lo, b - lo, b - lo - Vector2(0, 2.5), a - lo - Vector2(0, 2.5), Color("7a2c20"))
	var n := maxi(2, int((b - a).length() / 5.0))
	for k in range(n + 1):
		var p := a.lerp(b, float(k) / float(n)) - lo
		draw_line(p, p - Vector2(0, 6.0), Color("8e3427"), 1.0)
	draw_line(a - lo - Vector2(0, 4.0), b - lo - Vector2(0, 4.0), Color("8e3427"), 0.9)
	draw_line(a - lo - Vector2(0, 6.5), b - lo - Vector2(0, 6.5), Color("4a1c14"), 1.5)

## 팔작지붕 한 점: 지붕 중심 uv(base)에서 긴 축 L·폭 축 W(uv 단위벡터)로 (l, w), 높이 h
func _bh_lw(C: Vector2, AX: Vector2, AY: Vector2, base: Vector2, L: Vector2, W: Vector2, l: float, w: float, h: float) -> Vector2:
	var uv := base + L * l + W * w
	return C + AX * uv.x + AY * uv.y - Vector2(0, h)

## 팔작지붕: 처마 반길이 el·반폭 ew(처마선은 가운데가 낮고 네 귀가 5px 치켜올라가며 바깥으로 살짝 뻗음 — 앙곡·안허리),
## 용마루 반길이 rl. 긴 지붕면 둘 + 끝 지붕면 둘을 화면 뒤쪽 면부터 그리고, 카메라 쪽 끝에 합각(세운 삼각 벽)을 얹는다.
func _bh_paljak(C: Vector2, AX: Vector2, AY: Vector2, base: Vector2, L: Vector2, W: Vector2, el: float, ew: float, rl: float, h_e: float, h_r: float, snow: bool) -> void:
	var col := Color("dfe5ea") if snow else FT_TILE
	var line_col := Color("b8c2cc") if snow else FT_TILE.darkened(0.3)
	var NS := 8
	# 처마선: 긴 변 두 개(w=-,+)와 짧은 변 두 개(l=-,+), 모두 귀에서 만난다
	var long_e: Array = [[], []] # [w-, w+] 각 NS+1점 (l: -el → +el)
	for si in range(2):
		var sg := -1.0 if si == 0 else 1.0
		for k in range(NS + 1):
			var l := lerpf(-el, el, float(k) / float(NS))
			var r := absf(l) / el
			(long_e[si] as Array).append(_bh_lw(C, AX, AY, base, L, W, l * (1.0 + 0.0), sg * (ew + 0.09 * pow(r, 3.0)), h_e + 5.0 * pow(r, 2.5)))
	var end_e: Array = [[], []] # [l-, l+] 각 NS+1점 (w: -ew → +ew)
	for ei in range(2):
		var sg2 := -1.0 if ei == 0 else 1.0
		for k in range(NS + 1):
			var w := lerpf(-ew, ew, float(k) / float(NS))
			var r2 := absf(w) / ew
			(end_e[ei] as Array).append(_bh_lw(C, AX, AY, base, L, W, sg2 * el, w * (1.0 + 0.09 * pow(r2, 3.0) / ew), h_e + 5.0 * pow(r2, 2.5)))
	var r0 := _bh_lw(C, AX, AY, base, L, W, -rl, 0.0, h_r)
	var r1 := _bh_lw(C, AX, AY, base, L, W, rl, 0.0, h_r)
	# 처마 두께(서까래 그늘): 처마선 전체를 3px 내린 어두운 판을 먼저
	var loop := PackedVector2Array()
	for p: Vector2 in long_e[0]:
		loop.append(p)
	for k in range(1, NS):
		loop.append((end_e[1] as Array)[k])
	for k in range(NS, -1, -1):
		loop.append((long_e[1] as Array)[k])
	for k in range(NS - 1, 0, -1):
		loop.append((end_e[0] as Array)[k])
	var under := PackedVector2Array()
	for p2: Vector2 in loop:
		under.append(p2 + Vector2(0, 3.0))
	FastDraw.poly(self, under, Color("1c2025"))
	# 지붕면 넷 — 향하는 방향(화면 y)이 작은 것(뒤)부터
	var planes: Array = []
	for si in range(2):
		var pts := PackedVector2Array()
		for p3: Vector2 in long_e[si]:
			pts.append(p3)
		pts.append(r1)
		pts.append(r0)
		planes.append({"pts": pts, "dir": W * (-1.0 if si == 0 else 1.0), "long": si})
	for ei in range(2):
		var pts2 := PackedVector2Array()
		for p4: Vector2 in end_e[ei]:
			pts2.append(p4)
		pts2.append(r0 if ei == 0 else r1)
		planes.append({"pts": pts2, "dir": L * (-1.0 if ei == 0 else 1.0), "long": -1})
	for pl: Dictionary in planes:
		var d: Vector2 = pl["dir"]
		pl["sd"] = (AX * d.x + AY * d.y).normalized()
	planes.sort_custom(func(p, q): return (p["sd"] as Vector2).y < (q["sd"] as Vector2).y)
	for pl: Dictionary in planes:
		var sd: Vector2 = pl["sd"]
		var shade: float = 0.20 * sd.y + 0.09 * sd.x
		var c2 := col.lightened(shade) if shade > 0.0 else col.darkened(-shade)
		FastDraw.poly(self, pl["pts"], c2)
		FastDraw.polyline(self, PackedVector2Array(Array(pl["pts"]) + [pl["pts"][0]]), FT_OUT, 0.8)
		var li: int = pl["long"]
		if li >= 0:
			# 기왓골: 처마에서 위(용마루 또는 추녀마루)로
			var sg3 := -1.0 if li == 0 else 1.0
			for k in range(1, 10):
				var l2 := lerpf(-el, el, float(k) / 10.0)
				var rr := absf(l2) / el
				var bot := _bh_lw(C, AX, AY, base, L, W, l2, sg3 * (ew + 0.09 * pow(rr, 3.0)), h_e + 5.0 * pow(rr, 2.5))
				var top: Vector2
				if absf(l2) <= rl:
					top = _bh_lw(C, AX, AY, base, L, W, l2, 0.0, h_r)
				else:
					var q2 := (absf(l2) - rl) / (el - rl)
					top = _bh_lw(C, AX, AY, base, L, W, l2, sg3 * ew * q2, lerpf(h_r, h_e + 5.0, q2))
				draw_line(bot, bot.lerp(top, 0.92), c2.darkened(0.13) if not snow else line_col, 0.6)
			# 처마 끝: 막새 선 + 서까래 끝 단청 점(카메라 쪽 처마만)
			if sd.y > 0.0:
				var arr: Array = long_e[li]
				for k in range(NS):
					draw_line(arr[k], arr[k + 1], Color("ffffff") if snow else c2.lightened(0.28), 2.0 if snow else 1.1)
				if not snow:
					for k in range(1, NS):
						FastDraw.circle(self, (arr[k] as Vector2) + Vector2(0, 2.2), 0.7, Color("d8a838") if k % 2 == 0 else BH_DANCHEONG)
	if snow:
		FastDraw.polyline(self, loop + PackedVector2Array([loop[0]]), Color("f8fafc", 0.95), 2.2)
	# 합각: 용마루 끝에 세운 삼각 벽(카메라 쪽 끝만) + 박공 흰 테
	var hg := h_e + (h_r - h_e) * 0.45
	var gw := ew * 0.55
	for ei in range(2):
		var sg4 := -1.0 if ei == 0 else 1.0
		var sdir := (AX * (L.x * sg4) + AY * (L.y * sg4))
		var g0 := _bh_lw(C, AX, AY, base, L, W, sg4 * rl, -gw, hg)
		var g1 := _bh_lw(C, AX, AY, base, L, W, sg4 * rl, gw, hg)
		var gt := _bh_lw(C, AX, AY, base, L, W, sg4 * rl, 0.0, h_r + 0.6)
		if sdir.y > 0.0:
			MarketArt.draw_safe_tri(self, g0, g1, gt, Color("7d3426"))
			draw_line(g0.lerp(gt, 0.5), g1.lerp(gt, 0.5), Color("a88a5a"), 0.6)
			FastDraw.circle(self, g0.lerp(g1, 0.5).lerp(gt, 0.45), 1.0, Color("e0b040"))
			draw_line(g0, gt, Color("3a2a22"), 1.0)
			draw_line(g1, gt, Color("3a2a22"), 1.0)
		# 추녀마루: 합각 아래 귀에서 처마 귀로 — 앞쪽 면에 닿은 것만
		for wi in range(2):
			var sgw := -1.0 if wi == 0 else 1.0
			var side_dir := (AX * (W.x * sgw) + AY * (W.y * sgw))
			if sdir.y <= 0.0 and side_dir.y <= 0.0:
				continue
			var gc := g0 if wi == 0 else g1
			var corner: Vector2 = (long_e[wi] as Array)[0 if ei == 0 else NS]
			draw_line(gc, corner, Color("1f242a"), 2.0)
			draw_line(gc, corner, Color("ffffff") if snow else Color("a2a9b0"), 2.0 if snow else 1.0)
			FastDraw.circle(self, corner - Vector2(0, 0.8), 1.2, Color("23282e")) # 토수·용두
	draw_line(r0 + Vector2(0, 0.6), r1 + Vector2(0, 0.6), Color("1f242a"), 3.0) # 용마루(그림자 + 얇은 양성바름)
	draw_line(r0 - Vector2(0, 0.4), r1 - Vector2(0, 0.4), Color("ffffff") if snow else Color("b8bec4"), 2.2 if snow else 1.6)
	FastDraw.circle(self, r0 - Vector2(0, 1.6), 1.9, Color("23282e")) # 취두
	FastDraw.circle(self, r1 - Vector2(0, 1.6), 1.9, Color("23282e"))

## 용연이 놓인 방향(2x2 기준 앵커에서 북/동/남/서). 없으면 성 밖 들판 쪽, 그것도 없으면 북쪽.
func _bh_pond_dir(anchor: Vector2i) -> Vector2i:
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for i in range(4):
		for k in range(1, 4):
			var p: Vector2i = anchor + dirs[i] * k
			if grid.in_bounds(p.x, p.y) and grid.grid[p.y][p.x]["building"] == "yongyeon":
				return dirs[i]
	for i in range(4):
		var p2: Vector2i = anchor + dirs[i]
		if grid.in_bounds(p2.x, p2.y) and grid.grid[p2.y][p2.x]["terrain"] == "outside":
			return dirs[i]
	return Vector2i(0, -1)

## 방화수류정(1x1) — 성곽 모서리에 걸터앉은 각루(PORT-TRACE [방화수류정 1x1]). 예전 세이브의 2x2 부지는 기준 칸에만 누각을 그리고
## 나머지 칸은 성벽 높이 석축 마당(성벽 위였던 칸) 또는 바위 바닥으로.
func _render_banghwasuryu(x: int, y: int, t: Dictionary, c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2) -> void:
	var anchor: Vector2i = t.get("site_anchor", Vector2i(x, y))
	if Vector2i(x, y) != anchor:
		if bool(t.get("bh_wall", false)):
			var blk := PackedVector2Array([p_n, p_e, p_s, p_w])
			var bf := _bh_prism(blk, 0.0, WALL_HEIGHT, FT_STONE, FT_WALK if current_season != "겨울" else Color("e4e9ee"))
			_bh_courses(bf, 0.0, WALL_HEIGHT, 3, 9.0, FT_MORTAR)
		else:
			FastDraw.poly(self, _diamond(c, 0.98), Color("8c8476"))
		return
	var F := Vector2(_bh_pond_dir(anchor))
	var S := Vector2(-F.y, F.x)
	# PORT-TRACE [방화수류정 성곽 위]: 사용자 요청 — "성곽에서 튀어나온 게 아니라 성곽 위에 그려봐". 이 칸은 이웃 성벽과 똑같이
	# 성벽(체성·여장, 곡선 이음)으로 그리고, 누각은 성 위 길 한가운데에 얹는다(국소 -1~1 = 칸의 0.6, 성벽 두께보다 조금 넓게).
	var front_m := _bh_wall_bulge(x, y, p_n, p_e, p_s, p_w)
	var CT := c - Vector2(0, WALL_HEIGHT)
	_bh_pavilion_top(CT, (p_e - p_n) * 0.36, (p_w - p_n) * 0.36, S, F, current_season == "겨울", 0.8, 17.0, 0.07)
	for mm: Array in front_m:
		_draw_wall_merlons(mm[0], mm[1], FT_TILE, current_season == "겨울", bool(mm[2]))

## PORT-TRACE [방화수류정 성곽 두터움]: 사용자 요청 — "성곽에서 튀어나온 느낌이 들면 안 된다. 성곽이 부드럽게 두터워지면서 건물이 자리잡게".
## 이웃 성벽과 맞닿는 이음목(변 가운데·대각 꼭짓점)에서는 성벽 두께 그대로, 칸 가운데로 갈수록 둥글게 불어나는 체성 하나로 그린다
## (이음목 양끝 점 + 가운데 둥근 고리 점들의 볼록 껍질). 뒤쪽 여장은 여기서, 앞쪽 여장은 누각을 그린 뒤 그리도록 돌려준다.
func _bh_wall_bulge(x: int, y: int, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2) -> Array:
	var hw := WALL_THICK_K
	var pts := PackedVector2Array()
	var R := 0.4
	for i in range(20):
		var th := TAU * float(i) / 20.0
		pts.append(Vector2(0.5, 0.5) + Vector2(cos(th), sin(th)) * R)
	var joints: Array = [] # [이음점, 그 변을 따라가는 단위벡터]
	var wn := grid.is_wall_connector(x, y - 1)
	var we := grid.is_wall_connector(x + 1, y)
	var ws := grid.is_wall_connector(x, y + 1)
	var ww := grid.is_wall_connector(x - 1, y)
	if wn:
		joints.append([Vector2(0.5, 0.0), Vector2(1, 0)])
	if we:
		joints.append([Vector2(1.0, 0.5), Vector2(0, 1)])
	if ws:
		joints.append([Vector2(0.5, 1.0), Vector2(1, 0)])
	if ww:
		joints.append([Vector2(0.0, 0.5), Vector2(0, 1)])
	if grid.is_wall_connector(x + 1, y - 1) and not we and not wn:
		joints.append([Vector2(1.0, 0.0), Vector2(1, 1).normalized()])
	if grid.is_wall_connector(x + 1, y + 1) and not we and not ws:
		joints.append([Vector2(1.0, 1.0), Vector2(1, -1).normalized()])
	if grid.is_wall_connector(x - 1, y + 1) and not ww and not ws:
		joints.append([Vector2(0.0, 1.0), Vector2(1, 1).normalized()])
	if grid.is_wall_connector(x - 1, y - 1) and not ww and not wn:
		joints.append([Vector2(0.0, 0.0), Vector2(1, -1).normalized()])
	var jpts: Array[Vector2] = []
	for j: Array in joints:
		var jp: Vector2 = j[0]
		var jd: Vector2 = j[1]
		jpts.append(jp - jd * hw)
		jpts.append(jp + jd * hw)
		# 이음목에서 조금 안쪽은 아직 성벽 두께 — 거기서부터 둥글게 불어난다
		var inward := (Vector2(0.5, 0.5) - jp).normalized()
		pts.append(jp + inward * 0.12 - jd * hw)
		pts.append(jp + inward * 0.12 + jd * hw)
	for q: Vector2 in jpts:
		pts.append(q)
	var hull := Geometry2D.convex_hull(pts) # 닫힌 목록(끝점 = 첫 점)
	if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
		hull.remove_at(hull.size() - 1)
	# 화면 좌표 + 반시계 판정(바깥 법선)
	var scr := PackedVector2Array()
	for u: Vector2 in hull:
		scr.append(_wall_uv(u, p_n, p_e, p_s, p_w))
	var up := Vector2(0, WALL_HEIGHT)
	var snow: bool = (band_master.current_season if band_master else current_season) == "겨울"
	var faces: Array = []
	var back_m: Array = []
	var front_m: Array = []
	var area := 0.0
	for i in range(scr.size()):
		area += scr[i].x * scr[(i + 1) % scr.size()].y - scr[(i + 1) % scr.size()].x * scr[i].y
	for i in range(hull.size()):
		var ua: Vector2 = hull[i]
		var ub: Vector2 = hull[(i + 1) % hull.size()]
		var a: Vector2 = scr[i]
		var b: Vector2 = scr[(i + 1) % scr.size()]
		var e := b - a
		var nrm := Vector2(e.y, -e.x).normalized() if area > 0.0 else Vector2(-e.y, e.x).normalized()
		# 이웃 성벽과 맞붙는 이음목 변(칸 경계 위)은 벽면·여장 없음
		var ja := false
		var jb := false
		for jq: Vector2 in jpts:
			ja = ja or ua.distance_to(jq) < 0.001
			jb = jb or ub.distance_to(jq) < 0.001
		if ja and jb and ua.distance_to(ub) < hw * 2.05:
			continue
		if nrm.y > 0.02:
			faces.append([a, b, nrm])
			front_m.append([a - up, b - up, nrm.x > 0.0])
		else:
			back_m.append([a - up, b - up, nrm.x > 0.0])
	faces.sort_custom(func(p, q): return ((p[0] as Vector2) + (p[1] as Vector2)).y < ((q[0] as Vector2) + (q[1] as Vector2)).y)
	for fc: Array in faces:
		var a2: Vector2 = fc[0]
		var b2: Vector2 = fc[1]
		_draw_stone_face(a2, b2, b2 - up, a2 - up, FT_STONE if (fc[2] as Vector2).x >= 0.0 else FT_STONE_D, FT_MORTAR, 3, maxi(1, int((b2 - a2).length() / 9.0)))
	var top := PackedVector2Array()
	for p2: Vector2 in scr:
		top.append(p2 - up)
	FastDraw.poly(self, top, Color("e4e9ee") if snow else FT_WALK)
	for mm: Array in back_m:
		_draw_wall_merlons(mm[0], mm[1], FT_TILE, snow, bool(mm[2]))
	return front_m

## PORT-TRACE [방화수류정 ㄱ자 누각]: 사용자 요청 — "ㄱ자로 꺾이고 북·동으로 툇마루가 튀어나온 복합 평면, 방주 18개, 여러 팔작지붕이 겹침,
## 석재와 전돌의 혼용, 바깥은 총안·현안의 요새·안쪽은 트인 누각, 성곽과 조화롭게 이어진 모습". 화성성역의궤·정리의궤의
## 동북각루 외도·내도를 따랐다:
## - 대(臺): 성벽 높이까지 모서리를 깎은 다각형 화강암 석축(아래 자연 암반 자락), 그 위 ㄱ자 부분만 한 단 더 올린 회색 전돌 띠(총안·현안).
##   ㄱ자 밖의 한 귀는 성 위 길 높이로 남겨 여장을 두르고, 거기서 붉은 나무 계단이 누마루로 오른다(내도). 성 안쪽 석축 면엔 홍예 암문.
## - 누각: 본채는 초록 문얼굴의 띠살 분합문으로 두르고, 용연 쪽 날개채·툇마루는 계자난간만 둘러 트였다. 붉은 방주 18개.
## - 지붕: 본채·날개채 팔작 + 동쪽 툇마루 덧처마가 겹치고, 본채 용마루 한가운데 절병통.
## 국소 좌표: s = 옆(동쪽 +), f = 용연 쪽(북쪽 +), 2x2 부지가 -1~1.
const BH_PAV_DECK := [Vector2(-0.82, -0.78), Vector2(1.06, -0.78), Vector2(1.06, 0.88), Vector2(0.18, 0.88), Vector2(0.18, 0.22), Vector2(-0.82, 0.22)]
const BH_PAV_POSTS := [
	Vector2(-0.78, -0.74), Vector2(-0.26, -0.74), Vector2(0.26, -0.74), Vector2(0.78, -0.74), # 본채 뒷줄
	Vector2(-0.78, -0.08), Vector2(-0.26, -0.08), Vector2(0.26, -0.08), Vector2(0.78, -0.08), # 본채 앞줄(툇마루와의 경계)
	Vector2(-0.78, 0.18), Vector2(-0.26, 0.18), # 북쪽 툇마루 끝
	Vector2(0.22, 0.18), Vector2(0.78, 0.34), Vector2(0.22, 0.84), Vector2(0.78, 0.84), # 용연 쪽으로 꺾인 날개채
	Vector2(1.02, -0.74), Vector2(1.02, -0.2), Vector2(1.02, 0.34), Vector2(1.02, 0.84)] # 동쪽 툇마루 끝
## 성벽 높이 석축(모서리 깎은 네모)과 그 위 전돌 대(ㄱ자, 모서리 깎음)
const BH_PAV_BASE := [Vector2(-0.98, -0.66), Vector2(-0.66, -0.98), Vector2(0.7, -0.98), Vector2(0.98, -0.7), Vector2(0.98, 0.7), Vector2(0.7, 0.98), Vector2(-0.7, 0.98), Vector2(-0.98, 0.7)]
const BH_PAV_TOWER := [Vector2(-0.82, -0.62), Vector2(-0.62, -0.82), Vector2(0.84, -0.82), Vector2(0.98, -0.66), Vector2(0.98, 0.66), Vector2(0.82, 0.86), Vector2(0.3, 0.86), Vector2(0.12, 0.68), Vector2(0.12, 0.32), Vector2(-0.64, 0.32), Vector2(-0.82, 0.14)]

## 국소 다각형(반시계)의 변마다 [국소 a, 국소 b, 국소 바깥 법선]
func _bh_local_edges(pts: Array) -> Array:
	var out: Array = []
	for i in range(pts.size()):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		out.append([a, b, Vector2(b.y - a.y, -(b.x - a.x)).normalized()])
	return out

func _bh_wall_pavilion(C0: Vector2, AX: Vector2, AY: Vector2, S: Vector2, F: Vector2, lift: float, season: String) -> void:
	var snow := season == "겨울"
	var TH := 5.0 # 전돌 대 높이(성 위 길보다 한 단 높게)
	var walk := Color("948872") if not snow else Color("e4e9ee")
	# ---------------------------------------------------------------- 1. 자연 암반 자락(밑동만 들쭉날쭉하게 드러남)
	var rock_pts: Array = []
	for i in range(16):
		var th := TAU * float(i) / 16.0
		var q := Vector2(cos(th), sin(th))
		var sq := q / maxf(absf(q.x), absf(q.y))
		rock_pts.append(sq.lerp(q, 0.3) * (1.0 + 0.05 * sin(3.0 * th + 0.7)))
	var rock_col := BH_ROCK if not snow else Color("dfe4e6")
	var rf := _bh_prism(_bh_poly(C0, AX, AY, S, F, rock_pts), 0.0, 4.0, rock_col, Color(0, 0, 0, 0))
	for fc: Array in rf:
		var m: Vector2 = (fc[0] as Vector2).lerp(fc[1], 0.5)
		_bh_ell(m - Vector2(0, 2.0), 3.0, 1.4, rock_col.darkened(0.25))
	# ---------------------------------------------------------------- 2. 성벽 높이 다각형 석축(체성과 같은 돌) + 성 안쪽 면 홍예 암문
	var base_l := _bh_local_edges(BH_PAV_BASE)
	var faces: Array = []
	for e: Array in base_l:
		var a := _bh(C0, AX, AY, S, F, (e[0] as Vector2).x, (e[0] as Vector2).y, 0.0)
		var b := _bh(C0, AX, AY, S, F, (e[1] as Vector2).x, (e[1] as Vector2).y, 0.0)
		var nl: Vector2 = e[2]
		var ns := (AX * (S.x * nl.x + F.x * nl.y) + AY * (S.y * nl.x + F.y * nl.y))
		if ns.y > 0.02:
			faces.append([a, b, ns, nl])
	faces.sort_custom(func(p, q): return ((p[0] as Vector2) + (p[1] as Vector2)).y < ((q[0] as Vector2) + (q[1] as Vector2)).y)
	var up := Vector2(0, lift)
	for fc2: Array in faces:
		var a2: Vector2 = fc2[0]
		var b2: Vector2 = fc2[1]
		var lit := (fc2[2] as Vector2).x >= 0.0
		_draw_stone_face(a2, b2, b2 - up, a2 - up, FT_STONE if lit else FT_STONE_D, FT_MORTAR, 3, maxi(2, int((b2 - a2).length() / 9.0)))
		var nl2: Vector2 = fc2[3]
		if nl2.y < -0.9 and (b2 - a2).length() > 12.0:
			# 홍예 암문: 둥근 머리 문 + 태극 문짝
			var gm := a2.lerp(b2, 0.5)
			var gw := 4.0
			var ap := PackedVector2Array([gm + Vector2(-gw, 0), gm + Vector2(gw, 0)])
			for k2 in range(9):
				var th3 := PI * float(k2) / 8.0
				ap.append(gm + Vector2(cos(th3) * gw, -9.0 - sin(th3) * gw))
			FastDraw.poly(self, PackedVector2Array([ap[0], ap[1]] + Array(ap.slice(2)).duplicate()), Color("7a2a20"))
			FastDraw.polyline(self, PackedVector2Array(Array(ap.slice(2)) + [ap[1], ap[0], ap[ap.size() - 1]]), FT_OUT, 0.8)
			FastDraw.circle(self, gm - Vector2(0, 7.0), 1.8, Color("e8d9a8"))
			FastDraw.circle(self, gm - Vector2(0.5, 7.4), 0.8, Color("2a4a8a"))
			FastDraw.circle(self, gm - Vector2(-0.5, 6.6), 0.8, Color("b03030"))
		draw_line(a2 - up, b2 - up, Color("d6cdb6") if not snow else Color("f4f7fa"), 1.0)
	var C := C0 - up
	FastDraw.poly(self, _bh_poly(C, AX, AY, S, F, BH_PAV_BASE), walk)
	# ---------------------------------------------------------------- 3. ㄱ자 전돌 대(총안·현안) — 그 밖의 한 귀는 성 위 길 + 여장 + 계단
	var tower_poly: PackedVector2Array = PackedVector2Array(BH_PAV_TOWER)
	var back_m: Array = []
	var front_m: Array = []
	for e2: Array in base_l:
		var mid: Vector2 = ((e2[0] as Vector2) + (e2[1] as Vector2)) * 0.5
		if Geometry2D.is_point_in_polygon(mid - (e2[2] as Vector2) * 0.25, tower_poly):
			continue # 전돌 대에 붙은 변
		var a3 := _bh(C, AX, AY, S, F, (e2[0] as Vector2).x, (e2[0] as Vector2).y, 0.0)
		var b3 := _bh(C, AX, AY, S, F, (e2[1] as Vector2).x, (e2[1] as Vector2).y, 0.0)
		var nl3: Vector2 = e2[2]
		var ns3 := (AX * (S.x * nl3.x + F.x * nl3.y) + AY * (S.y * nl3.x + F.y * nl3.y))
		(front_m if ns3.y > 0.02 else back_m).append([a3, b3, ns3.x > 0.0])
	for mm: Array in back_m:
		_draw_wall_merlons(mm[0], mm[1], FT_TILE, snow, bool(mm[2]))
	var tw_faces: Array = []
	for e3: Array in _bh_local_edges(BH_PAV_TOWER):
		var nl4: Vector2 = e3[2]
		var ns4 := (AX * (S.x * nl4.x + F.x * nl4.y) + AY * (S.y * nl4.x + F.y * nl4.y))
		if ns4.y > 0.02:
			tw_faces.append([_bh(C, AX, AY, S, F, (e3[0] as Vector2).x, (e3[0] as Vector2).y, 0.0), _bh(C, AX, AY, S, F, (e3[1] as Vector2).x, (e3[1] as Vector2).y, 0.0), ns4])
	tw_faces.sort_custom(func(p, q): return ((p[0] as Vector2) + (p[1] as Vector2)).y < ((q[0] as Vector2) + (q[1] as Vector2)).y)
	for fc3: Array in tw_faces:
		var a4: Vector2 = fc3[0]
		var b4: Vector2 = fc3[1]
		var bc := FT_BRICK if (fc3[2] as Vector2).x >= 0.0 else FT_BRICK_D
		MarketArt.draw_safe_quad(self, a4, b4, b4 - Vector2(0, TH), a4 - Vector2(0, TH), bc)
		for hh in range(2, int(TH), 2):
			draw_line(a4 - Vector2(0, float(hh)), b4 - Vector2(0, float(hh)), bc.darkened(0.16), 0.4)
		var nh := maxi(1, int((b4 - a4).length() / 8.0))
		for k3 in range(nh):
			var hp := a4.lerp(b4, (float(k3) + 0.5) / float(nh))
			if k3 % 3 == 1:
				MarketArt.draw_safe_quad(self, hp + Vector2(-0.8, 0.0), hp + Vector2(0.8, 0.0), hp - Vector2(-0.8, TH - 2.0), hp - Vector2(0.8, TH - 2.0), FT_DARK) # 현안
			else:
				FastDraw.poly(self, PackedVector2Array([hp - Vector2(1.2, TH * 0.55 + 1.1), hp - Vector2(-1.2, TH * 0.55 + 1.1), hp - Vector2(-1.2, TH * 0.55 - 1.1), hp - Vector2(1.2, TH * 0.55 - 1.1)]), FT_DARK) # 총안
		FastDraw.polyline(self, PackedVector2Array([a4, a4 - Vector2(0, TH), b4 - Vector2(0, TH), b4]), FT_OUT, 0.7)
	var CT := C - Vector2(0, TH)
	FastDraw.poly(self, _bh_poly(CT, AX, AY, S, F, BH_PAV_TOWER), Color("7d7468") if not snow else Color("e4e9ee"))

	# ---------------------------------------------------------------- 4. 누각
	_bh_pavilion_top(CT, AX, AY, S, F, snow, 0.86, 15.0, 0.04)

	# ---------------------------------------------------------------- 5. 앞쪽 여장 + 성 위 길에서 누마루로 오르는 붉은 나무 계단(ㄱ자 안쪽 귀)
	for mm2: Array in front_m:
		_draw_wall_merlons(mm2[0], mm2[1], FT_TILE, snow, bool(mm2[2]))
	# 계단: 성 안쪽(마당 쪽) 석축 면을 따라 땅에서 전돌 대 위까지(내도·항공 사진) — 그 면이 화면 앞을 볼 때만
	var inner_n := -(AX * F.x + AY * F.y)
	if inner_n.y > 0.02:
		var s0 := _bh(C0, AX, AY, S, F, -0.95, -1.1, 0.0)
		var s1 := _bh(C0, AX, AY, S, F, -0.3, -1.1, lift + TH + 1.5)
		var sw := (AX * F.x + AY * F.y) * 0.1
		MarketArt.draw_safe_quad(self, s0 - sw, s0 + sw, s1 + sw, s1 - sw, Color("8a5a36"))
		for k4 in range(1, 10):
			var tp := s0.lerp(s1, float(k4) / 10.0)
			draw_line(tp - sw, tp + sw, Color("5e3a22"), 0.8)
		draw_line(s0 - sw - Vector2(0, 4.0), s1 - sw - Vector2(0, 4.0), BH_PILLAR, 1.2) # 난간
		draw_line(s0 - sw, s0 - sw - Vector2(0, 4.0), BH_PILLAR, 1.2)
		FastDraw.polyline(self, PackedVector2Array([s0 + sw, s1 + sw, s1 - sw]), FT_OUT, 0.7)

## 누각 몸체(마루·난간·방주·초록 분합문·단청 띠·겹친 팔작지붕·절병통): CT = 마루 밑 바닥점, K = 바닥점 기준 축척,
## post_h = 기둥 높이(지붕 높이도 이에 비례), post_w = 기둥 반폭(국소 단위)
func _bh_pavilion_top(CT: Vector2, AX: Vector2, AY: Vector2, S: Vector2, F: Vector2, snow: bool, K: float, post_h: float, post_w: float) -> void:
	draw_set_transform_matrix(Transform2D(0.0, Vector2(K, K), 0.0, CT * (1.0 - K)))
	var FH := 2.0 # 마루 윗면(전돌 대 윗면 기준)
	var TOP := FH + post_h # 기둥머리
	var deck := _bh_poly(CT, AX, AY, S, F, BH_PAV_DECK)
	var edges := _bh_edges(deck)
	_bh_prism(deck, 0.0, FH, BH_WOOD.darkened(0.15), Color("9a7448") if not snow else Color("e8ecef"))
	var rail_back: Array = []
	var rail_front: Array = []
	for fc4: Array in edges:
		(rail_front if (fc4[2] as Vector2).y > 0.02 else rail_back).append(fc4)
	for fc5: Array in rail_back:
		_bh_rail(fc5[0], fc5[1], FH)
	var posts: Array = []
	for pp: Vector2 in BH_PAV_POSTS:
		posts.append([pp, _bh(CT, AX, AY, S, F, pp.x, pp.y, 0.0).y])
	posts.sort_custom(func(p, q): return float(p[1]) < float(q[1]))
	var core_y := _bh(CT, AX, AY, S, F, 0.0, -0.4, 0.0).y
	var core_drawn := false
	for pt: Array in posts:
		if not core_drawn and float(pt[1]) > core_y:
			_bh_core_green(CT, AX, AY, S, F, FH, TOP)
			core_drawn = true
		_bh_post(CT, AX, AY, S, F, pt[0], post_w, FH, TOP, BH_PILLAR, BH_PILLAR.lightened(0.22))
	if not core_drawn:
		_bh_core_green(CT, AX, AY, S, F, FH, TOP)
	rail_front.sort_custom(func(p, q): return ((p[0] as Vector2) + (p[1] as Vector2)).y < ((q[0] as Vector2) + (q[1] as Vector2)).y)
	for fc6: Array in rail_front:
		_bh_rail(fc6[0], fc6[1], FH)
	# 창방 단청 띠: 기둥머리를 잇는 ㄱ자 둘레(초록 바탕)
	var band := _bh_poly(CT, AX, AY, S, F, [Vector2(-0.78, -0.74), Vector2(1.02, -0.74), Vector2(1.02, 0.84), Vector2(0.22, 0.84), Vector2(0.22, 0.18), Vector2(-0.78, 0.18)])
	var bfaces: Array = []
	for fc7: Array in _bh_edges(band):
		if (fc7[2] as Vector2).y > 0.02:
			bfaces.append(fc7)
	bfaces.sort_custom(func(p, q): return ((p[0] as Vector2) + (p[1] as Vector2)).y < ((q[0] as Vector2) + (q[1] as Vector2)).y)
	for fc8: Array in bfaces:
		var q0 := (fc8[0] as Vector2) - Vector2(0, TOP - 0.5)
		var q1 := (fc8[1] as Vector2) - Vector2(0, TOP - 0.5)
		MarketArt.draw_safe_quad(self, q0, q1, q1 - Vector2(0, 3.5), q0 - Vector2(0, 3.5), BH_DANCHEONG)
		draw_line(q0, q1, Color("c0392b"), 1.0)
		var nd := maxi(2, int((q1 - q0).length() / 4.0))
		for k in range(1, nd):
			FastDraw.circle(self, q0.lerp(q1, float(k) / float(nd)) - Vector2(0, 1.8), 0.7, Color("f4d03f") if k % 2 == 0 else Color("e05a3a"))
	# 겹친 팔작지붕(화면 뒤쪽부터) + 절병통
	var roofs: Array = [
		[S * 0.12 + F * -0.42, S, F, 1.04, 0.52, 0.5, TOP + 2.0, TOP + post_h],
		[S * 0.62 + F * 0.42, F, S, 0.62, 0.5, 0.16, TOP + 1.5, TOP + post_h * 0.83],
		[S * 0.98 + F * 0.05, F, S, 0.95, 0.2, 0.7, TOP + 0.5, TOP + post_h * 0.27],
	]
	for r0: Array in roofs:
		var bv: Vector2 = r0[0]
		r0.append((AX * bv.x + AY * bv.y).y)
	roofs.sort_custom(func(p, q): return float(p[8]) < float(q[8]))
	for r1: Array in roofs:
		_bh_paljak(CT, AX, AY, r1[0], r1[1], r1[2], r1[3], r1[4], r1[5], r1[6], r1[7], snow)
	var mb: Vector2 = S * 0.12 + F * -0.42
	var fin := CT + AX * mb.x + AY * mb.y - Vector2(0, TOP + post_h)
	FastDraw.circle(self, fin - Vector2(0, 1.5), 2.2, Color("2a2e33"))
	FastDraw.circle(self, fin - Vector2(0, 4.2), 1.6, Color("3a3f45"))
	FastDraw.circle(self, fin - Vector2(0, 6.2), 1.1, Color("2a2e33"))
	draw_line(fin - Vector2(0, 6.5), fin - Vector2(0, 9.0), Color("2a2e33"), 0.8)
	draw_set_transform_matrix(Transform2D.IDENTITY)

## 본채 몸체: 초록 문얼굴의 띠살 분합문(창호지) — 의궤 그림의 초록 창살
func _bh_core_green(C: Vector2, AX: Vector2, AY: Vector2, S: Vector2, F: Vector2, h0: float, h1: float) -> void:
	var frame := Color("2f7a5a")
	var faces := _bh_prism(_bh_rect(C, AX, AY, S, F, -0.72, 0.72, -0.68, -0.14), h0, h1, Color("ece4cc"), Color(0, 0, 0, 0))
	for fc: Array in faces:
		var a: Vector2 = fc[0]
		var b: Vector2 = fc[1]
		var n := maxi(3, int((b - a).length() / 2.6))
		for k in range(1, n):
			var p := a.lerp(b, float(k) / float(n))
			draw_line(p - Vector2(0, h0 + 2.0), p - Vector2(0, h1 - 2.0), frame.lightened(0.25), 0.5) # 띠살
		for hh: float in [h0 + 1.0, lerpf(h0, h1, 0.5), h1 - 1.0]:
			draw_line(a - Vector2(0, hh), b - Vector2(0, hh), frame, 1.0)
		var doors := maxi(2, int((b - a).length() / 8.0))
		for k in range(doors + 1):
			var p2 := a.lerp(b, float(k) / float(doors))
			draw_line(p2 - Vector2(0, h0), p2 - Vector2(0, h1), frame.darkened(0.15), 1.2) # 문설주
		MarketArt.draw_safe_quad(self, a - Vector2(0, h0), b - Vector2(0, h0), b - Vector2(0, h0 + 3.0), a - Vector2(0, h0 + 3.0), frame) # 머름(초록 하인방)

## 네모 기둥(방주·장초석): 국소 위치 p, 반폭 hw, 높이 h0~h1 — 화면 앞쪽 두 면(밝은 면·그늘 면)
func _bh_post(C: Vector2, AX: Vector2, AY: Vector2, S: Vector2, F: Vector2, p: Vector2, hw: float, h0: float, h1: float, col: Color, lit_col: Color) -> void:
	var sq := _bh_poly(C, AX, AY, S, F, [p + Vector2(-hw, -hw), p + Vector2(hw, -hw), p + Vector2(hw, hw), p + Vector2(-hw, hw)])
	for fc: Array in _bh_edges(sq):
		var n: Vector2 = fc[2]
		if n.y <= 0.02:
			continue
		var a: Vector2 = fc[0]
		var b: Vector2 = fc[1]
		MarketArt.draw_safe_quad(self, a - Vector2(0, h0), b - Vector2(0, h0), b - Vector2(0, h1), a - Vector2(0, h1), lit_col if n.x > 0.0 else col)
	var c0 := (sq[0] + sq[2]) * 0.5
	draw_line(c0 - Vector2(0, h0), c0 - Vector2(0, h1), Color(0, 0, 0, 0.18), 0.5)

## 본채 몸체: 창호지 바른 띠살 분합문(화면 앞쪽 면만) + 처마 그늘
func _bh_core(C: Vector2, AX: Vector2, AY: Vector2, S: Vector2, F: Vector2, h0: float, h1: float) -> void:
	var faces := _bh_prism(_bh_rect(C, AX, AY, S, F, -0.56, 0.56, -0.50, 0.06), h0, h1, Color("e3d6b8"), Color(0, 0, 0, 0))
	for fc: Array in faces:
		var a: Vector2 = fc[0]
		var b: Vector2 = fc[1]
		var n := maxi(3, int((b - a).length() / 2.6))
		for k in range(1, n):
			var p := a.lerp(b, float(k) / float(n))
			draw_line(p - Vector2(0, h0 + 1.5), p - Vector2(0, h1 - 1.5), BH_WOOD.lightened(0.15), 0.5) # 띠살
		for hh: float in [h0 + 1.0, lerpf(h0, h1, 0.33), lerpf(h0, h1, 0.66), h1 - 1.0]:
			draw_line(a - Vector2(0, hh), b - Vector2(0, hh), BH_WOOD, 0.9)
		var doors := maxi(2, int((b - a).length() / 9.0))
		for k in range(doors + 1):
			var p2 := a.lerp(b, float(k) / float(doors))
			draw_line(p2 - Vector2(0, h0), p2 - Vector2(0, h1), BH_WOOD.darkened(0.2), 1.3) # 문설주
		MarketArt.draw_safe_quad(self, a - Vector2(0, h1 - 4.0), b - Vector2(0, h1 - 4.0), b - Vector2(0, h1), a - Vector2(0, h1), Color(0, 0, 0, 0.28)) # 처마 그늘

## 조선 소나무: 붉은 수피의 굽은 줄기 + 층층이 납작한 솔잎 구름(아래 진한 → 위 밝은), 겨울엔 눈 얹힘
func _bh_pine(p: Vector2, s: float, lean: float, season: String) -> void:
	_bh_ell(p + Vector2(3.0 * lean, 1.0), 10.0 * s, 3.5 * s, Color(0, 0, 0, 0.2))
	var bark := Color("7a4630")
	var k1 := p + Vector2(3.0 * lean, -9.0) * s
	var k2 := p + Vector2(-1.0 * lean, -18.0) * s
	var k3 := p + Vector2(4.0 * lean, -27.0) * s
	draw_line(p, k1, bark, 3.6 * s)
	draw_line(k1, k2, bark, 3.0 * s)
	draw_line(k2, k3, bark, 2.3 * s)
	draw_line(p + Vector2(0.8, 0), k1 + Vector2(0.8, 0), bark.lightened(0.28), 0.8)
	draw_line(k1 + Vector2(0.8, 0), k2 + Vector2(0.8, 0), bark.lightened(0.28), 0.8)
	var br := k2 + Vector2(-11.0 * lean, -2.0) * s
	draw_line(k1.lerp(k2, 0.6), br, bark, 1.8 * s)
	var br2 := k1.lerp(k2, 0.3) + Vector2(9.0 * lean, -3.0) * s
	draw_line(k1.lerp(k2, 0.3), br2, bark, 1.5 * s)
	var dark := Color("1d4528")
	var midc := Color("2d6236")
	var hi := Color("6aa250") if season == "봄" else Color("4a8448")
	var pads: Array = [[br, 7.5, 3.0], [br2, 6.5, 2.6], [k2 + Vector2(1.0 * lean, -3.0) * s, 7.0, 2.8], [k3 + Vector2(0, -2.0) * s, 8.5, 3.4]]
	for pd: Array in pads:
		var q: Vector2 = pd[0]
		var rx: float = float(pd[1]) * s
		var ry: float = float(pd[2]) * s
		_bh_ell(q + Vector2(0, 1.2), rx, ry, dark)
		_bh_ell(q + Vector2(0.4, -0.4), rx * 0.86, ry * 0.8, midc)
		_bh_ell(q + Vector2(0.9, -1.4), rx * 0.5, ry * 0.5, hi)
		if season == "겨울":
			_bh_ell(q + Vector2(0.3, -1.6), rx * 0.75, ry * 0.45, Color("f4f7fa"))

## 능수버들: 굽은 줄기 + 머리에서 땅 가까이 늘어진 실가지(계절색), 겨울엔 잎 없는 은회색 가지
func _bh_willow(p: Vector2, season: String) -> void:
	_bh_ell(p + Vector2(2, 1), 9.0, 3.5, Color(0, 0, 0, 0.18))
	var bark := Color("4b3b2b")
	draw_line(p, p + Vector2(-2, -11), bark, 3.2)
	draw_line(p + Vector2(-2, -11), p + Vector2(1, -21), bark, 2.4)
	draw_line(p + Vector2(-2, -11), p + Vector2(-8, -18), bark, 1.6)
	draw_line(p + Vector2(1, -21), p + Vector2(7, -24), bark, 1.4)
	var leaf: Color
	match season:
		"봄": leaf = Color("9acd52")
		"여름": leaf = Color("4f9a3c")
		"가을": leaf = Color("b8a840")
		_: leaf = Color("9aa4aa")
	var crown: Array[Vector2] = [Vector2(-9, -19), Vector2(-4, -24), Vector2(2, -25), Vector2(7, -23), Vector2(10, -18), Vector2(-1, -20)]
	if season != "겨울":
		for q: Vector2 in crown:
			_bh_ell(p + q, 5.0, 3.2, leaf.darkened(0.2))
	for i in range(crown.size()):
		var q2: Vector2 = crown[i]
		for k in range(3):
			var dx := float(k - 1) * 2.4
			var top := p + q2 + Vector2(dx, 0)
			var ln := 12.0 + float((i * 3 + k) % 4) * 2.0 + (q2.y + 25.0) * 0.4
			var mid := top + Vector2(dx * 0.3 + 1.0, ln * 0.5)
			var bot := top + Vector2(dx * 0.5 + 1.5, ln)
			draw_line(top, mid, leaf, 1.1 if season != "겨울" else 0.6)
			draw_line(mid, bot, leaf.lightened(0.12), 1.0 if season != "겨울" else 0.5)
	if season != "겨울":
		for q3: Vector2 in crown:
			_bh_ell(p + q3 + Vector2(0.5, -1.2), 3.2, 2.0, leaf.lightened(0.12))

## 용연(3x3): 3x3 가장 앞 칸에서 한 번에 그린다(나머지 칸은 잔디만)
func _render_yongyeon(x: int, y: int, t: Dictionary, c: Vector2, p_n: Vector2, p_e: Vector2, _p_s: Vector2, p_w: Vector2) -> void:
	var season := current_season
	var grass := _bh_grass(season)
	var mn := Vector2i(1 << 20, 1 << 20)
	var mx := Vector2i(-1, -1)
	var cnt := 0
	for pt in t.get("site_tiles", []):
		var q: Vector2i = pt
		if grid.in_bounds(q.x, q.y) and grid.grid[q.y][q.x].get("building", "") == "yongyeon":
			mn = Vector2i(mini(mn.x, q.x), mini(mn.y, q.y))
			mx = Vector2i(maxi(mx.x, q.x), maxi(mx.y, q.y))
			cnt += 1
	if cnt < 9 or mx - mn != Vector2i(2, 2):
		# 일부가 헐린 경우: 칸마다 물만
		FastDraw.poly(self, _diamond(c, 0.98), Color("24605a"))
		return
	# PORT-TRACE [용연 연못가]: 칸마다 잔디 덮개를 깔던 것을 없앰 — 땅은 둘레 들판과 같은 색·질감으로 이미 그려져 있고(_draw_tile),
	# 연못 둘레는 젖은 흙 띠만 살짝 두른다
	if Vector2i(x, y) != mx:
		return
	var ground := _get_tile_base_ground_color(x, y)
	var AX := p_e - p_n
	var AY := p_w - p_n
	var mid := mn + Vector2i(1, 1)
	var Cp := c + AX * float(mid.x - x) + AY * float(mid.y - y)
	var winter := season == "겨울"
	# 방화수류정이 있는 쪽(물에 비친 그림자를 그릴 방향)
	var pd := Vector2.ZERO
	for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		var pr: Vector2i = mid + d * 2
		if grid.in_bounds(pr.x, pr.y) and grid.grid[pr.y][pr.x]["building"] == "banghwasuryu":
			pd = Vector2(d)
			break
	var WD := 6.0 # 수면 깊이(px)
	var N := 28
	var shore: Array[Vector2] = []
	for i in range(N):
		var th := TAU * float(i) / float(N)
		var r := 1.2 + 0.07 * sin(2.0 * th + 0.6) + 0.05 * sin(3.0 * th + 1.9)
		shore.append(Vector2(cos(th), sin(th)) * r)
	var water: Color
	match season:
		"봄": water = Color("2f6f6a")
		"여름": water = Color("24605a")
		"가을": water = Color("2a5a66")
		_: water = Color("b7cbd6")
	var bank := ground.darkened(0.1) if season != "겨울" else Color("e8eef2").darkened(0.05)

	# 1) 연못가: 바깥으로 갈수록 들판 색에 녹아드는 젖은 흙 띠 두 겹
	for ring: Array in [[1.16, 0.04], [1.08, 0.1]]:
		var bank_pts := PackedVector2Array()
		for u: Vector2 in shore:
			bank_pts.append(_jq(Cp, AX, AY, u.x * float(ring[0]), u.y * float(ring[0]), 0.0))
		FastDraw.poly(self, bank_pts, ground.darkened(float(ring[1])) if not winter else Color("e8eef2").darkened(float(ring[1]) * 0.5))
	# 2) 먼 쪽 호안 안쪽 면(돌벽: 위는 마른 돌, 아래는 젖은 돌)
	for i in range(N):
		var a: Vector2 = shore[i]
		var b: Vector2 = shore[(i + 1) % N]
		var mu := (a + b) * 0.5
		if (_jq(Cp, AX, AY, mu.x * 1.1, mu.y * 1.1, 0.0) - _jq(Cp, AX, AY, mu.x, mu.y, 0.0)).y >= 0.0:
			continue
		var a0 := _jq(Cp, AX, AY, a.x, a.y, 0.0)
		var b0 := _jq(Cp, AX, AY, b.x, b.y, 0.0)
		MarketArt.draw_safe_quad(self, a0, b0, b0 + Vector2(0, WD * 0.5), a0 + Vector2(0, WD * 0.5), Color("9a9284"))
		MarketArt.draw_safe_quad(self, a0 + Vector2(0, WD * 0.5), b0 + Vector2(0, WD * 0.5), b0 + Vector2(0, WD), a0 + Vector2(0, WD), Color("5e584e"))
		draw_line(a0, a0 + Vector2(0, WD), Color("7a7366"), 0.6)
	# 3) 수면: 가장자리 → 가운데로 갈수록 깊고 어두운 물빛
	var wpts := PackedVector2Array()
	for u2: Vector2 in shore:
		wpts.append(_jq(Cp, AX, AY, u2.x, u2.y, -WD))
	FastDraw.poly(self, wpts, water)
	for sc: float in [0.72, 0.42]:
		var dp := PackedVector2Array()
		for u3: Vector2 in shore:
			dp.append(_jq(Cp, AX, AY, u3.x * sc - 0.08, u3.y * sc - 0.08, -WD))
		FastDraw.poly(self, dp, water.darkened(0.12 if sc > 0.5 else 0.22) if not winter else water.lightened(0.08 if sc > 0.5 else 0.14))
	# 하늘빛 반사 줄(화면 가로 방향 짧은 획)
	for hl: Vector2 in [Vector2(-0.7, -0.35), Vector2(-0.4, -0.75), Vector2(0.55, 0.1), Vector2(0.2, 0.7), Vector2(-0.75, 0.45)]:
		var hp := _jq(Cp, AX, AY, hl.x, hl.y, -WD)
		draw_line(hp + Vector2(-5, 0), hp + Vector2(5, 0), Color(1, 1, 1, 0.22 if not winter else 0.5), 1.0)
	if winter:
		# 살얼음 금
		for cr: Array in [[Vector2(-0.8, -0.2), Vector2(-0.3, 0.1), Vector2(-0.1, 0.6)], [Vector2(0.3, -0.8), Vector2(0.5, -0.3), Vector2(0.9, -0.1)]]:
			var cl := PackedVector2Array()
			for u4: Vector2 in cr:
				cl.append(_jq(Cp, AX, AY, u4.x, u4.y, -WD))
			FastDraw.polyline(self, cl, Color(1, 1, 1, 0.7), 0.8)
	# 물에 비친 방화수류정(누각이 연못 뒤편에 있을 때만 — 위아래 뒤집힌 바위·기둥·지붕 그림자)
	if pd != Vector2.ZERO and not winter:
		var B := _jq(Cp, AX, AY, pd.x * 0.98, pd.y * 0.98, -WD)
		if B.y < Cp.y:
			B.x = lerpf(B.x, Cp.x, 0.25)
			var rc := Color(0.04, 0.12, 0.14, 0.45)
			FastDraw.poly(self, PackedVector2Array([B + Vector2(-13, 0), B + Vector2(13, 0), B + Vector2(11, 4), B + Vector2(-11, 4)]), rc)
			for px: float in [-8.0, -3.0, 3.0, 8.0]:
				draw_line(B + Vector2(px, 4), B + Vector2(px, 10), Color(0.5, 0.15, 0.12, 0.35), 1.2)
			FastDraw.poly(self, PackedVector2Array([B + Vector2(-17, 10), B + Vector2(17, 10), B + Vector2(10, 17), B + Vector2(-10, 17)]), rc)
	# 4) 앞쪽 둑 턱: 수면이 앞쪽 호안 밖으로 삐져나온 부분을 둑 색으로 덮는다
	for i in range(N):
		var a5: Vector2 = shore[i]
		var b5: Vector2 = shore[(i + 1) % N]
		var mu5 := (a5 + b5) * 0.5
		if (_jq(Cp, AX, AY, mu5.x * 1.1, mu5.y * 1.1, 0.0) - _jq(Cp, AX, AY, mu5.x, mu5.y, 0.0)).y < 0.0:
			continue
		var a6 := _jq(Cp, AX, AY, a5.x, a5.y, 0.0)
		var b6 := _jq(Cp, AX, AY, b5.x, b5.y, 0.0)
		MarketArt.draw_safe_quad(self, a6, b6, b6 + Vector2(0, WD + 0.5), a6 + Vector2(0, WD + 0.5), bank)
	# 5) 연잎·연꽃(봄·여름), 가을엔 시든 잎과 떠 있는 낙엽
	if not winter:
		var pad_col := Color("3f7a3a") if season != "가을" else Color("7a6a34")
		for lu: Vector2 in [Vector2(-0.75, 0.35), Vector2(-0.6, 0.58), Vector2(-0.88, 0.1), Vector2(0.55, -0.72), Vector2(0.78, -0.45), Vector2(0.35, 0.82), Vector2(0.64, 0.6)]:
			var lp := _jq(Cp, AX, AY, lu.x, lu.y, -WD)
			_bh_ell(lp, 3.4, 1.8, pad_col)
			_bh_ell(lp + Vector2(-0.6, -0.4), 2.2, 1.0, pad_col.lightened(0.15))
			draw_line(lp, lp + Vector2(2.6, -1.0), pad_col.darkened(0.3), 0.6)
			if season == "여름" and int(absf(lu.x * 10.0)) % 2 == 1:
				draw_line(lp, lp - Vector2(0, 4), Color("4f7a3a"), 0.7)
				FastDraw.circle(self, lp - Vector2(0, 5), 1.8, Color("f2a0b8"))
				FastDraw.circle(self, lp - Vector2(0.4, 5.6), 0.9, Color("fde4ea"))
		if season == "가을":
			for fu: Vector2 in [Vector2(-0.3, -0.5), Vector2(0.1, 0.45), Vector2(0.6, -0.1), Vector2(-0.55, -0.1)]:
				FastDraw.circle(self, _jq(Cp, AX, AY, fu.x, fu.y, -WD), 1.0, Color("d0602a"))
	# 6) 호안 자연석(뒤 → 앞)
	var stones: Array = []
	for i in range(N):
		if i % 5 == 3:
			continue
		var su: Vector2 = shore[i] * 1.03
		stones.append([_jq(Cp, AX, AY, su.x, su.y, 0.0), 3.0 + fmod(float(i) * 1.7, 1.8), fmod(float(i) * 0.37, 0.2)])
	stones.sort_custom(func(p, q): return (p[0] as Vector2).y < (q[0] as Vector2).y)
	var stone_col := Color(0.64, 0.62, 0.57)
	for st: Array in stones:
		var sp: Vector2 = st[0]
		var sr: float = st[1]
		var sd: float = st[2]
		_bh_ell(sp + Vector2(0, 1.2), sr, sr * 0.6, stone_col.darkened(0.3 + sd))
		_bh_ell(sp, sr * 0.92, sr * 0.52, stone_col.darkened(sd))
		_bh_ell(sp + Vector2(-0.6, -0.6), sr * 0.45, sr * 0.25, stone_col.lightened(0.18) if not winter else Color("f4f7fa"))
	# 7) 둥근 섬: 물에서 솟은 자연석 옆면 + 잔디 동산
	var io := Vector2(0.08, 0.06)
	var isle := PackedVector2Array()
	for i in range(14):
		var th2 := TAU * float(i) / 14.0
		var rr := 0.36 + 0.03 * sin(3.0 * th2)
		isle.append(_jq(Cp, AX, AY, io.x + cos(th2) * rr, io.y + sin(th2) * rr, 0.0))
	_bh_prism(isle, -WD, 1.5, Color("8a8274"), grass)
	var dome := PackedVector2Array()
	for i in range(14):
		var th3 := TAU * float(i) / 14.0
		dome.append(_jq(Cp, AX, AY, io.x + cos(th3) * 0.22 - 0.03, io.y + sin(th3) * 0.22 - 0.03, 3.0))
	FastDraw.poly(self, dome, grass.lightened(0.1))
	_bh_ell(_jq(Cp, AX, AY, io.x + 0.2, io.y + 0.12, 2.0), 2.4, 1.4, Color("9a9284"))
	# 8) 나무: 섬 소나무 둘 + 둑의 능수버들(누각 반대편) — 화면 뒤 → 앞
	var trees: Array = []
	trees.append([_jq(Cp, AX, AY, io.x - 0.06, io.y + 0.04, 3.0), "pine", 1.0, -1.0])
	trees.append([_jq(Cp, AX, AY, io.x + 0.14, io.y - 0.12, 2.5), "pine", 0.75, 1.0])
	var ang0 := atan2(pd.y, pd.x) if pd != Vector2.ZERO else -PI * 0.5
	for da: float in [PI * 0.62, -PI * 0.62, PI]:
		var wa := ang0 + da
		trees.append([_jq(Cp, AX, AY, cos(wa) * 1.36, sin(wa) * 1.36, 0.5), "willow", 1.0, 1.0])
	trees.sort_custom(func(p, q): return (p[0] as Vector2).y < (q[0] as Vector2).y)
	for tree_elem: Array in trees:
		if str(tree_elem[1]) == "pine":
			_bh_pine(tree_elem[0], float(tree_elem[2]), float(tree_elem[3]), season)
		else:
			_bh_willow(tree_elem[0], season)

## PORT-TRACE [연무대 활터]: 성 밖 과녁 구역 한 칸 — 다진 흙 사로(射路). 가운데 줄은 밟혀 밝고 가장자리는 풀이 돋은 흙, 군데군데 자갈.
## 겨울엔 눈이 얇게 덮인다. (과녁·궁병은 연무대 장면에서 이 구역 위에 그려진다.)
func _draw_ym_range(x: int, y: int, c: Vector2) -> void:
	var h := absi(x * 73856093 ^ y * 19349663)
	var winter := current_season == "겨울"
	var dirt := Color("b7a67c") if not winter else Color("dfe3e5")
	var edge := Color("8a9a56") if not winter else Color("eef1f3")
	FastDraw.poly(self, _diamond(c, 1.0), edge)
	FastDraw.poly(self, _diamond(c, 0.9), dirt)
	FastDraw.poly(self, _diamond(c, 0.62), dirt.lightened(0.06))
	for i in range(4):
		var ox := float((h >> (i * 3)) % 25) - 12.0
		var oy := float((h >> (i * 2 + 1)) % 9) - 4.0
		FastDraw.circle(self, c + Vector2(ox, oy), 0.9, dirt.darkened(0.2))

## ─────────────────────────────────────────────── 저수지(작은 못)
## PORT-TRACE [저수지 도트 재그리기]: 사용자 요청 — "붕 떠 보이는 단순한 모양이라 지도에 안 어울린다". 예전엔 아틀라스 그림 한 장을 칸 위에
## 얹어 땅과 따로 놀았다. 이제 땅을 파낸 못으로 그린다: 수면은 땅보다 낮게 가라앉아 화면 뒤쪽 두 둑의 안쪽 흙벽(젖은 아랫단·돌 몇 개)이
## 보이고, 앞쪽 두 둑은 풀·돌 턱이 수면을 덮는다. 이웃한 못 칸과는 둑 없이 하나의 물로 이어지고, 둑 가의 물은 얕아 밝다.
## 갈대·부들, 연잎(봄·여름), 가을 낙엽, 겨울 얼음과 눈 쌓인 둑으로 계절을 나타낸다.
func _draw_reservoir_pond(x: int, y: int, c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2) -> void:
	var season := current_season
	var winter := season == "겨울"
	var h := absi(x * 73856093 ^ y * 19349663)
	var water: Color
	match season:
		"봄": water = Color("3c7f88")
		"여름": water = Color("2d6f7a")
		"가을": water = Color("3a6c74")
		_: water = Color("bcd6e2")
	var grass: Color
	match season:
		"봄": grass = Color("78a24e")
		"여름": grass = Color("5f8f3e")
		"가을": grass = Color("98904e")
		_: grass = Color("e4eaee")
	var earth := Color("6e5f48")
	var earth_wet := Color("463e30")
	# 둑이 있는 변(이웃이 못이 아닌 변): NE(p_n→p_e)·NW(p_w→p_n)는 화면 뒤쪽(안쪽 흙벽이 보임), SE(p_e→p_s)·SW(p_s→p_w)는 앞쪽(턱이 덮음)
	var bank_ne := not (grid.building_at(x, y - 1) in ["reservoir", "chukmanje"])
	var bank_nw := not (grid.building_at(x - 1, y) in ["reservoir", "chukmanje"])
	var bank_se := not (grid.building_at(x + 1, y) in ["reservoir", "chukmanje"])
	var bank_sw := not (grid.building_at(x, y + 1) in ["reservoir", "chukmanje"])
	var D := 5.5 # 수면이 땅보다 낮은 깊이(px)
	var L := 3.2 # 앞쪽 턱 높이

	# 1) 수면(칸 전체)
	FastDraw.poly(self, _diamond(c, 1.0), water)
	# 2) 둑 가의 얕은 물(밝은 띠)
	var edges: Array = [[p_n, p_e, bank_ne], [p_w, p_n, bank_nw], [p_e, p_s, bank_se], [p_s, p_w, bank_sw]]
	var shallow := water.lightened(0.2)
	shallow.a = 0.55
	for e: Array in edges:
		if bool(e[2]):
			var a: Vector2 = e[0]
			var b: Vector2 = e[1]
			FastDraw.poly(self, PackedVector2Array([a, b, b + (c - b) * 0.26, a + (c - a) * 0.26]), shallow)
	# 3) 물결·하늘빛 반사(칸마다 위치가 다르다)
	var rc := water.lightened(0.28)
	rc.a = 0.5
	for i in range(3):
		var ox := float((h >> (i * 4)) % 19) - 9.0
		var oy := float((h >> (i * 3 + 1)) % 7) - 3.0
		var w := 4.0 + float((h >> (i + 2)) % 4)
		draw_line(c + Vector2(ox - w, oy), c + Vector2(ox + w, oy), rc, 1.0)
	if winter:
		# 얼음: 가는 금
		var ic := Color(1, 1, 1, 0.7)
		draw_line(c + Vector2(-12, -2), c + Vector2(-2, 1), ic, 0.8)
		draw_line(c + Vector2(-2, 1), c + Vector2(4, 6), ic, 0.8)
		draw_line(c + Vector2(6, -5), c + Vector2(-2, 1), ic, 0.8)
	else:
		# 연잎(봄·여름)·낙엽(가을)
		if (h % 3) != 0:
			var lp := c + Vector2(float((h >> 5) % 21) - 10.0, float((h >> 8) % 9) - 4.0)
			if season == "가을":
				FastDraw.circle(self, lp, 1.0, Color("c8702a"))
				FastDraw.circle(self, lp + Vector2(5, 2), 0.9, Color("d49a30"))
			else:
				var pad := Color("3f7a3a")
				FastDraw.poly(self, PackedVector2Array([lp + Vector2(-3.5, 0), lp + Vector2(0, -1.7), lp + Vector2(3.5, 0), lp + Vector2(0, 1.7)]), pad)
				draw_line(lp, lp + Vector2(2.6, -0.6), earth_wet, 0.6)
				if season == "여름" and (h % 2) == 0:
					FastDraw.circle(self, lp + Vector2(-1.0, -1.6), 1.2, Color("f2a0b8"))

	# 4) 뒤쪽 두 둑의 안쪽 흙벽: 위는 마른 흙, 아래는 물에 젖은 흙 + 돌 + 풀이 늘어진 둑 마루 + 수면에 드리운 그림자
	for k in range(2):
		var e2: Array = edges[k]
		if not bool(e2[2]):
			continue
		var a2: Vector2 = e2[0]
		var b2: Vector2 = e2[1]
		var dn := Vector2(0, D)
		FastDraw.poly(self, PackedVector2Array([a2 + dn, b2 + dn, b2 + dn + Vector2(0, 3.0), a2 + dn + Vector2(0, 3.0)]), Color(0, 0, 0, 0.22)) # 둑 그림자
		FastDraw.poly(self, PackedVector2Array([a2, b2, b2 + dn * 0.55, a2 + dn * 0.55]), earth if not winter else Color("b8a890"))
		FastDraw.poly(self, PackedVector2Array([a2 + dn * 0.55, b2 + dn * 0.55, b2 + dn, a2 + dn]), earth_wet)
		draw_line(a2 + dn, b2 + dn, water.darkened(0.3), 1.0) # 물가선
		var cnt := 4
		for s in range(cnt):
			var f := (float(s) + 0.5) / float(cnt)
			var sp := a2.lerp(b2, f) + dn * (0.35 + 0.5 * float((h >> (s * 3 + k)) % 3) / 2.0)
			draw_line(sp, sp + Vector2(0, 2.0), earth_wet.darkened(0.2), 1.0) # 흙벽 결
			if (h >> (s + k * 2)) % 3 == 0:
				_pond_stone(sp + Vector2(0, 1.5), 2.0 + float(s % 2) * 0.6, winter)
		draw_line(a2, b2, grass, 2.0) # 둑 마루의 풀
		for s2 in range(5):
			var gp := a2.lerp(b2, (float(s2) + 0.5) / 5.0)
			draw_line(gp, gp + Vector2(0, 2.0 + float((h >> s2) % 2)), grass.darkened(0.12), 1.0) # 늘어진 풀

	# 5) 앞쪽 두 둑의 턱: 수면 가장자리를 덮는 풀둑 + 돌 쌓은 굽
	for k2 in range(2, 4):
		var e3: Array = edges[k2]
		if not bool(e3[2]):
			continue
		var a3: Vector2 = e3[0]
		var b3: Vector2 = e3[1]
		var up := Vector2(0, -L)
		FastDraw.poly(self, PackedVector2Array([a3, b3, b3 + up, a3 + up]), earth.lightened(0.05) if not winter else Color("cbbfae"))
		FastDraw.poly(self, PackedVector2Array([a3 + up, b3 + up, b3 + up * 1.7, a3 + up * 1.7]), grass)
		draw_line(a3 + up, b3 + up, earth_wet, 1.0) # 물과 맞닿는 선
		var cnt2 := 4
		for s3 in range(cnt2):
			var sp2 := a3.lerp(b3, (float(s3) + 0.5) / float(cnt2))
			if (h >> (s3 * 2 + k2)) % 2 == 0:
				_pond_stone(sp2 + Vector2(0, -1.2), 2.2 + float(s3 % 2) * 0.7, winter)

	# 6) 갈대·부들: 둑이 있는 변 몇 곳에 무리 지어
	var stem := Color("7a8a3a") if season != "겨울" else Color("a89c78")
	for k3 in range(4):
		var e4: Array = edges[k3]
		if not bool(e4[2]) or ((h >> (k3 * 2)) % 3) == 0:
			continue
		var a4: Vector2 = e4[0]
		var b4: Vector2 = e4[1]
		var f2 := 0.25 + 0.5 * float((h >> (k3 + 3)) % 5) / 4.0
		var base := a4.lerp(b4, f2) + (Vector2(0, D) if k3 < 2 else Vector2(0, -L))
		for r in range(4):
			var bx := base + Vector2(float(r) * 1.8 - 2.7, float(r % 2) * 0.8)
			var hh2 := 8.0 + float((h >> (r + k3)) % 5)
			var lean := (float(r) - 1.5) * 0.9
			draw_line(bx, bx + Vector2(lean, -hh2), stem, 1.0)
			if season in ["여름", "가을"] and r % 2 == 0:
				draw_line(bx + Vector2(lean, -hh2), bx + Vector2(lean, -hh2 - 2.6), Color("5a3a1c"), 1.8) # 부들 방망이
			elif season == "겨울":
				FastDraw.circle(self, bx + Vector2(lean, -hh2), 0.9, Color("f4f7fa"))

## 못가 돌: 윗면 밝고 아랫면 어두운 작은 자연석
func _pond_stone(p: Vector2, r: float, snow: bool) -> void:
	FastDraw.circle(self, p + Vector2(0, 0.8), r, Color("5e594f"))
	FastDraw.circle(self, p, r * 0.92, Color("8a857a"))
	FastDraw.circle(self, p + Vector2(-0.4, -0.5), r * 0.5, Color("b4afa2") if not snow else Color("f4f7fa"))

func _draw_building_slot(c: Vector2, slot_idx: int) -> void:
	if tex_buildings == null:
		return
	var col := slot_idx % 8
	var row := int(float(slot_idx) / 8.0)
	var src_rect := Rect2(col * 64, row * 64, 64, 64)
	var dest_rect := Rect2(c.x - 32.0, c.y - 48.0, 64.0, 64.0)
	draw_texture_rect_region(tex_buildings, dest_rect, src_rect)

func _draw_citizen(a: Dictionary) -> void:
	if tex_characters == null:
		return
	var gx := clampi(int(round(a["x"])), 0, grid.size - 1)
	var gy := clampi(int(round(a["y"])), 0, grid.size - 1)
	var elev: float = grid.grid[gy][gx]["elevation"] if grid.in_bounds(gx, gy) else 0.0
	var p := cell_center(a["x"], a["y"], elev)
	var ctype: String = a.get("type", "carrier")
	var char_row: int = CHAR_ROWS.get(ctype, 0)
	var frame: int = int(a.get("anim", 0.0)) % 4
	var src_rect := Rect2(frame * 32, char_row * 32, 32, 32)
	var dest_rect := Rect2(p.x - 16.0, p.y - 24.0, 32.0, 32.0)
	draw_texture_rect_region(tex_characters, dest_rect, src_rect)

## 전소된 폐허 (잿더미와 불탄 목재 잔해)
func _draw_ruin(c: Vector2, _p_n: Vector2, _p_e: Vector2, _p_s: Vector2, _p_w: Vector2) -> void:
	FastDraw.poly(self, _diamond(c, 0.75), Color("1f1d1a"))
	FastDraw.poly(self, _diamond(c, 0.55), Color("121110"))
	draw_line(c + Vector2(-8, -4), c + Vector2(6, 3), Color("292522"), 2.8)
	draw_line(c + Vector2(-4, 5), c + Vector2(7, -6), Color("3d3630"), 2.2)
	draw_line(c + Vector2(-9, 2), c + Vector2(-1, -7), Color("1f1d1a"), 2.0)
	var t_anim := Time.get_ticks_msec() / 1000.0
	FastDraw.circle(self, c + Vector2(sin(t_anim * 2.0) * 2.0, -8.0 - fmod(t_anim * 6.0, 10.0)), 1.5, Color(0.4, 0.4, 0.4, 0.45))

func _draw_service_marker(c: Vector2, col: Color, label: String) -> void:
	var base_poly := _diamond(c, 0.45)
	FastDraw.poly(self, base_poly, Color("3a352f"))
	var post_top := c + Vector2(0, -18)
	draw_line(c, post_top, Color("5c3a21"), 3.0)
	var flag_rect := Rect2(post_top.x - 7, post_top.y - 7, 14, 14)
	draw_rect(flag_rect, col)
	draw_rect(flag_rect, Color("d4af37"), false, 1.5)
	var font := ThemeDB.fallback_font
	if font:
		draw_string(font, post_top + Vector2(-5, 4), label, HORIZONTAL_ALIGNMENT_CENTER, 10, 11, Color.WHITE)

# ─────────────────────────────────────────────── 관아·옥사(2x2)
## PORT-TRACE [관아·옥사 2x2]: 한 단지 네 칸 — (0,0) 동헌(회색 기와, 대청이 마당 쪽으로 트임), (1,0) 원형 옥사
## (둥근 돌담 안 초가 옥방), (0,1) 재판 마당(형틀·곤장 거치대), (1,1) 솟을삼문. 바깥 모서리는 기와 얹은 담장.
## 사또·나졸·죄수 등 움직이는 사람은 CitizenLayer._draw_gwana_scenes가 그린다.
func _draw_gwana_part(x: int, y: int, anchor: Vector2i, c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2) -> void:
	var season: String = band_master.current_season if band_master else current_season
	var snow: bool = season == "겨울"
	var rel := Vector2i(x, y) - anchor
	var ax := (p_e - p_n) * 0.5 # +x 반벡터
	var ay := (p_w - p_n) * 0.5 # +y 반벡터
	var yard_col: Color = Color("edf2f7") if snow else (Color("cbbd98") if rel != Vector2i(1, 0) else Color("a89a78"))
	FastDraw.poly(self, PackedVector2Array([p_n, p_e, p_s, p_w]), yard_col)
	# 모서리: -y(p_n→p_e), +x(p_e→p_s), +y(p_s→p_w), -x(p_w→p_n)
	var edges: Array = [[Vector2i(0, -1), p_n, p_e], [Vector2i(1, 0), p_e, p_s], [Vector2i(0, 1), p_s, p_w], [Vector2i(-1, 0), p_w, p_n]]
	var back: Array = []
	var front: Array = []
	for e: Array in edges:
		var nr: Vector2i = rel + (e[0] as Vector2i)
		if nr.x >= 0 and nr.x <= 1 and nr.y >= 0 and nr.y <= 1:
			continue # 단지 안쪽 모서리
		var mid: Vector2 = ((e[1] as Vector2) + (e[2] as Vector2)) * 0.5
		if mid.y < c.y:
			back.append(e)
		else:
			front.append(e)
	for e: Array in back:
		_gwana_wall(e[1], e[2], snow)
	match rel:
		Vector2i(0, 0):
			# 동헌: 기단 + 대청(마당 쪽 +y로 트임) + 회색 기와 + 현판
			MarketArt.box(self, c, ax, ay, 0.8, 0.62, 0.0, 3.0, Color("b0aaa0"))
			var fr := MarketArt.box(self, c, ax, ay, 0.68, 0.5, 3.0, 14.0, MarketArt.WALL_PLASTER, true)
			MarketArt.roof(self, c, ax, ay, 0.92, 0.72, 0.5, 13.0, 23.0, MarketArt.ROOF_SLATE, false, snow)
			if fr.size() == 4:
				var sp := (fr[2] + fr[3]) * 0.5 + Vector2(0, -2)
				draw_rect(Rect2(sp + Vector2(-8, -4), Vector2(16, 6)), Color("2a2018"))
				draw_string(ThemeDB.fallback_font, sp + Vector2(-7, 1.5), "東軒", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color("f4d27a"))
		Vector2i(1, 0):
			# 원형 옥사: 둥근 돌담 뒤쪽 반 → 옥방(초가) → 앞쪽 반
			var ring := PackedVector2Array()
			for i in range(16):
				var ang := TAU * float(i) / 16.0
				ring.append(c + ax * cos(ang) * 0.82 + ay * sin(ang) * 0.82)
			var hut := c + ax * 0.0 + ay * -0.2
			for half in range(2):
				for i in range(16):
					var q0: Vector2 = ring[i]
					var q1: Vector2 = ring[(i + 1) % 16]
					var is_back := (q0.y + q1.y) * 0.5 < c.y
					if is_back != (half == 0):
						continue
					MarketArt.draw_safe_quad(self, q0, q1, q1 - Vector2(0, 9), q0 - Vector2(0, 9), Color("9a948a") if is_back else Color("b4ada0"))
					draw_line(q0 - Vector2(0, 9), q1 - Vector2(0, 9), Color("ffffff") if snow else Color("5a5650"), 1.8 if snow else 1.4)
				if half == 0:
					MarketArt.box(self, hut, ax, ay, 0.38, 0.26, 0.0, 8.0, Color("c8b48a"))
					# 옥방 창살
					var bar0 := MarketArt.P(hut, ax, ay, -0.3, 0.27, 2.0)
					for k in range(5):
						draw_line(bar0 + ax * 0.15 * float(k), bar0 + ax * 0.15 * float(k) - Vector2(0, 5), Color("3a2a1a"), 0.8)
					MarketArt.roof(self, hut, ax, ay, 0.5, 0.4, 0.15, 7.0, 13.0, MarketArt.THATCH, true, snow)
			# 옥문(앞쪽 담에 나무 문)
			var door := c + ay * 0.82
			draw_rect(Rect2(door + Vector2(-3, -8), Vector2(6, 8)), Color("5a3a20"))
			draw_line(door + Vector2(-3, -4), door + Vector2(3, -4), Color("2a1a0e"), 0.8)
		Vector2i(0, 1):
			# 재판 마당: 형틀(긴 나무 의자) + 곤장 거치대
			MarketArt.table(self, c, ax, ay, 0.05, 0.05, 0.35, 0.1, 3.5)
			var rack := MarketArt.P(c, ax, ay, -0.55, -0.4)
			draw_line(rack, rack - Vector2(0, 12), MarketArt.TIMBER, 1.2)
			draw_line(rack + Vector2(7, 0), rack + Vector2(7, -12), MarketArt.TIMBER, 1.2)
			draw_line(rack - Vector2(0, 11), rack + Vector2(7, -11), MarketArt.TIMBER, 1.0)
			for k in range(3):
				draw_line(rack + Vector2(1.5 + k * 2.0, -11), rack + Vector2(1.5 + k * 2.0, -2), Color("7a1f14"), 1.1)
		Vector2i(1, 1):
			# 솟을삼문(+y 모서리) + 홰나무
			var gm := (p_s + p_w) * 0.5
			MarketArt.box(self, gm, ax, ay, 0.5, 0.12, 0.0, 10.0, Color("8a3a2a"))
			MarketArt.roof(self, gm, ax, ay, 0.62, 0.24, 0.2, 9.0, 15.0, MarketArt.ROOF_SLATE, false, snow)
			var tree_pt := c + ax * 0.35 + ay * -0.35
			draw_line(tree_pt, tree_pt - Vector2(0, 12), Color("4a3422"), 2.4)
			if season == "겨울":
				draw_line(tree_pt - Vector2(0, 12), tree_pt - Vector2(6, 18), Color("4a3422"), 1.6)
				draw_line(tree_pt - Vector2(0, 12), tree_pt - Vector2(-5, 17), Color("4a3422"), 1.6)
				draw_line(tree_pt - Vector2(6, 18), tree_pt - Vector2(8, 22), Color("ffffff"), 1.4)
				draw_line(tree_pt - Vector2(-5, 17), tree_pt - Vector2(-7, 21), Color("ffffff"), 1.4)
				FastDraw.circle(self, tree_pt - Vector2(0, 15), 3.0, Color("f8fafc"))
			elif season == "가을":
				FastDraw.circle(self, tree_pt - Vector2(0, 17), 7.0, Color("d97706"))
				FastDraw.circle(self, tree_pt - Vector2(4, 21), 5.0, Color("eab308"))
			elif season == "봄":
				FastDraw.circle(self, tree_pt - Vector2(0, 17), 7.0, Color("65a30d"))
				FastDraw.circle(self, tree_pt - Vector2(4, 21), 5.0, Color("a3e635"))
			else:
				FastDraw.circle(self, tree_pt - Vector2(0, 17), 7.0, Color("3d7a35"))
				FastDraw.circle(self, tree_pt - Vector2(4, 21), 5.0, Color("4a8a3c"))
	for e: Array in front:
		if rel == Vector2i(1, 1) and (e[0] as Vector2i) == Vector2i(0, 1):
			continue # 삼문 자리
		_gwana_wall(e[1], e[2], snow)

func _gwana_wall(q0: Vector2, q1: Vector2, snow: bool = false) -> void:
	MarketArt.draw_safe_quad(self, q0, q1, q1 - Vector2(0, 7), q0 - Vector2(0, 7), Color("d8cfbc"))
	var cap_c: Color = Color("ffffff") if snow else MarketArt.ROOF_SLATE
	draw_line(q0 - Vector2(0, 7), q1 - Vector2(0, 7), cap_c, 2.2 if snow else 2.0)

## PORT-TRACE [수원 쇠전 3x3]: 사진(우시장 울타리 칸) 고증 — 흙바닥, 바깥 둘레 나무 울타리, 안쪽엔 소를 한 줄씩 매는
## 가로 말뚝 울타리 두 줄, 여물통, 구석(2,0)에 거래 끝나고 막걸리 마시는 초가 주막 평상. 소·사람은 CitizenLayer가 그린다.
## 바탕 그림 PNG(assets/sprites/buildings/cattle_market_3x3.png, 192x160)가 있으면 그 한 장을 3x3 맨 앞 칸에서 그린다(서당·서원과 같은 방식).
const CATTLE_PNG := "res://assets/sprites/buildings/cattle_market_3x3.png"
static var _cattle_png_state := 0 # 0 = 아직 확인 안 함, 1 = 있음, 2 = 없음

func _draw_cattle_yard_tile(x: int, y: int, rx: int, ry: int, c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2) -> void:
	var season_now: String = band_master.current_season if band_master else current_season
	var snow: bool = season_now == "겨울"
	if _cattle_png_state == 0:
		_cattle_png_state = 1 if (ResourceLoader.exists(CATTLE_PNG) or FileAccess.file_exists(ProjectSettings.globalize_path(CATTLE_PNG))) else 2
	if _cattle_png_state == 1:
		FastDraw.poly(self, PackedVector2Array([p_n, p_e, p_s, p_w]), Color("edf2f7") if snow else Color("9a8462"))
		if rx == 2 and ry == 2:
			var tex: Texture2D = SpriteCacheManager.get_seasonal_or_base_texture("buildings", "cattle_market_3x3", SeasonColorFilter.get_current_season_suffix(season_now), Vector2i(192, 160))
			if tex != null:
				var bc := cell_center(float(x - 2) + 1.5, float(y - 2) + 1.5, 1.0) # 3x3 한가운데(서당·서원과 같은 기준)
				var r := Rect2(bc.x - 96.0, bc.y + 48.0 - 160.0, 192.0, 160.0)
				draw_texture_rect(tex, r, false, SeasonColorFilter.get_current_tile_tint(season_now))
		return
	FastDraw.poly(self, PackedVector2Array([p_n, p_e, p_s, p_w]), Color("edf2f7") if snow else Color("9a8462"))
	var hsh := absi(x * 92821 + y * 68917)
	for i in range(5):
		var off := Vector2(float((hsh >> (i * 3)) % 25) - 12.0, float((hsh >> (i * 4 + 1)) % 11) - 5.0)
		FastDraw.circle(self, c + off, 0.9, Color("6e5a3a") if not snow else Color("cbd5e1")) # 쇠똥·발자국
	var ax := (p_e - p_n) * 0.5
	var ay := (p_w - p_n) * 0.5
	var fence := Color("7a5634")
	# 바깥 둘레 울타리: -y(p_n→p_e), +x(p_e→p_s), +y(p_s→p_w), -x(p_w→p_n)
	var edges: Array = [[ry == 0, p_n, p_e], [rx == 2, p_e, p_s], [ry == 2, p_s, p_w], [rx == 0, p_w, p_n]]
	for e: Array in edges:
		if not e[0]:
			continue
		var q0: Vector2 = e[1]
		var q1: Vector2 = e[2]
		for k in range(4):
			var q := q0.lerp(q1, float(k) / 3.0)
			draw_line(q, q - Vector2(0, 8), fence, 1.3)
		draw_line(q0 - Vector2(0, 7), q1 - Vector2(0, 7), Color("ffffff") if snow else fence, 1.4 if snow else 1.1)
		draw_line(q0 - Vector2(0, 3.5), q1 - Vector2(0, 3.5), fence, 0.9)
	if rx == 2 and ry == 0:
		# 주막 평상 + 초가 차양 + 막걸리 독
		MarketArt.table(self, c, ax, ay, 0.0, 0.2, 0.45, 0.3, 4.0)
		for su: float in [-0.6, 0.6]:
			draw_line(MarketArt.P(c, ax, ay, su, -0.5), MarketArt.P(c, ax, ay, su, -0.5, 13.0), MarketArt.TIMBER, 1.2)
		MarketArt.roof(self, c + ay * -0.3, ax, ay, 0.75, 0.45, 0.3, 12.0, 17.0, MarketArt.THATCH, true, snow)
		MarketArt.jars(self, MarketArt.P(c, ax, ay, -0.55, 0.55), 2)
		MarketArt.sign_flag(self, MarketArt.P(c, ax, ay, 0.8, 0.7), "酒", Color("f6efd8"))
		return
	# 안쪽 소 매는 말뚝 줄(가로) — 가운데 열(rx 0~1)에 두 줄
	if ry == 1 or ry == 2:
		var a0 := MarketArt.P(c, ax, ay, -0.95, -0.55)
		var a1 := MarketArt.P(c, ax, ay, 0.95, -0.55)
		for k in range(3):
			var q := a0.lerp(a1, float(k) / 2.0)
			draw_line(q, q - Vector2(0, 7), fence, 1.2)
		draw_line(a0 - Vector2(0, 6), a1 - Vector2(0, 6), Color("ffffff") if snow else fence, 1.3 if snow else 1.0)
	if rx == 0 and ry == 0:
		# 여물통 + 짚더미
		var trough_p := MarketArt.P(c, ax, ay, 0.0, 0.1)
		FastDraw.poly(self, PackedVector2Array([trough_p + ax * -0.5 + Vector2(0, -2), trough_p + ax * 0.5 + Vector2(0, -2), trough_p + ax * 0.5 + Vector2(0, -5), trough_p + ax * -0.5 + Vector2(0, -5)]), Color("6e4a2c"))
		draw_line(trough_p + ax * -0.45 + Vector2(0, -4.5), trough_p + ax * 0.45 + Vector2(0, -4.5), Color("d8b85a"), 1.4)
		FastDraw.circle(self, MarketArt.P(c, ax, ay, -0.5, -0.5, 3.0), 4.2, Color("d8b85a"))
	if rx == 1 and ry == 0:
		MarketArt.sign_flag(self, MarketArt.P(c, ax, ay, 0.0, -0.7), "牛", Color("f6efd8"))

## PORT-TRACE [화서문 어염시장]: 2x2 염전 소금 창고 — (0,0) 소금 곳간(회벽·기와, 앞이 트여 가마니 더미가 보임),
## (1,0) 기둥에 친 빗물 가림 차양 아래 가마니 더미, (0,1) 됫박질하는 평상 + 소금 자루, (1,1) 하얀 소금 무더기 + 대바구니.
func _draw_salt_store_tile(rx: int, ry: int, c: Vector2, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2) -> void:
	var snow: bool = (band_master.current_season if band_master else current_season) == "겨울"
	FastDraw.poly(self, PackedVector2Array([p_n, p_e, p_s, p_w]), Color("edf2f7") if snow else Color("c4b89a"))
	var ax := (p_e - p_n) * 0.5
	var ay := (p_w - p_n) * 0.5
	match Vector2i(rx, ry):
		Vector2i(0, 0):
			var fr := MarketArt.box(self, c, ax, ay, 0.72, 0.55, 0.0, 13.0, MarketArt.WALL_PLASTER, true)
			if fr.size() == 4:
				var b0 := (fr[0] + fr[1]) * 0.5
				for k in range(3):
					_salt_sacks(b0 + Vector2(-6 + k * 6, -1), 2)
			MarketArt.roof(self, c, ax, ay, 0.9, 0.72, 0.5, 12.0, 21.0, MarketArt.ROOF_RED, false, snow)
			MarketArt.sign_flag(self, MarketArt.P(c, ax, ay, 0.85, 0.75), "鹽", Color("f6efd8"))
		Vector2i(1, 0):
			var posts: Array[Vector2] = [MarketArt.P(c, ax, ay, -0.6, -0.5), MarketArt.P(c, ax, ay, 0.6, -0.5), MarketArt.P(c, ax, ay, -0.6, 0.5), MarketArt.P(c, ax, ay, 0.6, 0.5)]
			for q in posts.slice(0, 2):
				draw_line(q, q - Vector2(0, 12), MarketArt.TIMBER, 1.2)
			for k in range(4):
				_salt_sacks(MarketArt.P(c, ax, ay, -0.35 + 0.25 * float(k), 0.0), 3 if k % 2 == 0 else 2)
			for q in posts.slice(2, 4):
				draw_line(q, q - Vector2(0, 11), MarketArt.TIMBER, 1.2)
			# 빗물 가림 차양(누런 무명 천)
			MarketArt.draw_safe_quad(self, posts[0] - Vector2(0, 12), posts[1] - Vector2(0, 12), posts[3] - Vector2(0, 11), posts[2] - Vector2(0, 11), Color(0.9, 0.85, 0.7, 0.9))
			draw_line(posts[2] - Vector2(0, 11), posts[3] - Vector2(0, 11), Color("a8946a"), 1.0)
		Vector2i(0, 1):
			MarketArt.table(self, c, ax, ay, 0.0, -0.1, 0.4, 0.22, 4.0)
			_salt_sacks(MarketArt.P(c, ax, ay, -0.55, 0.45), 2)
			MarketArt.baskets(self, MarketArt.P(c, ax, ay, 0.55, 0.5), [Color("f8f8f4"), Color("f8f8f4")])
		Vector2i(1, 1):
			# 소금 무더기(흰 고깔) + 대바구니
			var mp := MarketArt.P(c, ax, ay, 0.0, 0.0)
			FastDraw.poly(self, PackedVector2Array([mp + Vector2(-14, 0), mp + Vector2(14, 0), mp + Vector2(0, -13)]), Color("f4f4ee"))
			FastDraw.poly(self, PackedVector2Array([mp + Vector2(0, -13), mp + Vector2(14, 0), mp + Vector2(4, 0)]), Color("dcdcd4"))
			MarketArt.baskets(self, MarketArt.P(c, ax, ay, 0.55, 0.55), [Color("f8f8f4"), Color("e8e0c8"), Color("f8f8f4")])
			draw_line(mp + Vector2(10, 2), mp + Vector2(16, -10), MarketArt.TIMBER, 1.0) # 소금 고무래

## 가마니(짚 섬) n개를 쌓은 더미 — 짚빛 몸통 + 위로 비치는 하얀 소금
func _salt_sacks(p: Vector2, n: int) -> void:
	for i in range(n):
		var q := p + Vector2((float(i % 2) - 0.5) * 5.0, -floorf(float(i) / 2.0) * 3.6 - float(i % 2) * 0.6)
		FastDraw.poly(self, PackedVector2Array([q + Vector2(-3.4, 0), q + Vector2(3.4, 0), q + Vector2(3, -3.8), q + Vector2(-3, -3.8)]), Color("d8c48a"))
		draw_line(q + Vector2(-3.2, -1.9), q + Vector2(3.2, -1.9), Color("a8904a"), 0.6)
		FastDraw.circle(self, q + Vector2(0, -3.9), 1.5, Color("fafaf6"))

# ─────────────────────────────────────────────── 종루(여민각) 2x2
## PORT-TRACE [종루(여민각) 2x2]: 실물 사진 고증 — 흰 화강암 석대 기단과 돌난간, 붉은 두리기둥 여덟, 초록 바탕 오방색 단청 띠,
## 처마 끝이 들린 모임지붕(회색 기와) 꼭대기의 절병통, 처마 아래 與民閣 현판, 사방이 트인 누각 가운데 걸린 범종과 당목.
## 네 칸 모두 박석 바닥을 깔고, 누각 전체는 가장 앞(깊이가 큰) 칸 (1,1)에서 한 번에 그린다 — 그 칸의 북쪽 꼭짓점 p_n이
## 2x2의 한가운데이고, 한 칸 벡터 AX(+x)·AY(+y)로 u,v ∈ [-1,1]이 2x2 전체다.
const JN_GRANITE := Color("e4e0d6")
const JN_PILLAR := Color("a8322a")
const JN_DANCHEONG := Color("2e7d6b")

func _jq(C: Vector2, AX: Vector2, AY: Vector2, u: float, v: float, h: float) -> Vector2:
	return C + AX * u + AY * v - Vector2(0, h)

func _draw_jongnu_part(rel: Vector2i, c: Vector2, p_n: Vector2, p_e: Vector2, p_w: Vector2) -> void:
	var snow: bool = (band_master.current_season if band_master else current_season) == "겨울"
	var pave_col: Color = Color("e8eef4") if snow else Color("c9c3b4")
	FastDraw.poly(self, _diamond(c, 0.98), pave_col)
	if rel != Vector2i(1, 1):
		return
	var C := p_n
	var AX := p_e - p_n
	var AY := p_w - p_n
	var base_h := 6.0
	# 1) 석대 기단(옆면) + 윗면
	MarketArt.box(self, C, AX, AY, 0.95, 0.95, 0.0, base_h, JN_GRANITE)
	var top_stone_col: Color = Color("edf2f7") if snow else Color("d6d0c2")
	MarketArt.draw_safe_quad(self, _jq(C, AX, AY, -0.95, -0.95, base_h), _jq(C, AX, AY, 0.95, -0.95, base_h), _jq(C, AX, AY, 0.95, 0.95, base_h), _jq(C, AX, AY, -0.95, 0.95, base_h), top_stone_col)
	# 기단 앞 돌계단(+y 쪽 가운데)
	for k in range(3):
		var sv := 0.95 + 0.06 * float(k + 1)
		var stair_col: Color = (Color("edf2f7") if snow else JN_GRANITE).darkened(0.05 * float(k))
		MarketArt.draw_safe_quad(self, _jq(C, AX, AY, -0.25, sv - 0.06, base_h - 2.0 * float(k + 1)), _jq(C, AX, AY, 0.25, sv - 0.06, base_h - 2.0 * float(k + 1)), _jq(C, AX, AY, 0.25, sv, base_h - 2.0 * float(k + 1)), _jq(C, AX, AY, -0.25, sv, base_h - 2.0 * float(k + 1)), stair_col)
	# 난간 네 변: [u0,v0,u1,v1]
	var rails: Array = [[-0.88, -0.88, 0.88, -0.88], [0.88, -0.88, 0.88, 0.88], [0.88, 0.88, -0.88, 0.88], [-0.88, 0.88, -0.88, -0.88]]
	var back_rails: Array = []
	var front_rails: Array = []
	for r: Array in rails:
		var mid := _jq(C, AX, AY, (float(r[0]) + float(r[2])) * 0.5, (float(r[1]) + float(r[3])) * 0.5, 0.0)
		(back_rails if mid.y < C.y else front_rails).append(r)
	for r: Array in back_rails:
		_jongnu_rail(C, AX, AY, r, base_h, false)
	# 2) 기둥 여덟(뒤쪽부터), 3) 범종·당목
	var pillars: Array = []
	for pu: float in [-0.62, 0.0, 0.62]:
		for pv: float in [-0.62, 0.0, 0.62]:
			if pu == 0.0 and pv == 0.0:
				continue
			pillars.append(Vector2(pu, pv))
	pillars.sort_custom(func(p, q): return _jq(C, AX, AY, p.x, p.y, 0.0).y < _jq(C, AX, AY, q.x, q.y, 0.0).y)
	var top_h := 40.0
	var bell_drawn := false
	for pp: Vector2 in pillars:
		var pb := _jq(C, AX, AY, pp.x, pp.y, base_h)
		if not bell_drawn and pb.y > C.y - base_h:
			_jongnu_bell(C, AX, AY, base_h, top_h)
			bell_drawn = true
		draw_line(pb, pb - Vector2(0, top_h - base_h), JN_PILLAR, 3.4)
		draw_line(pb + Vector2(-1.0, 0), pb - Vector2(1.0, top_h - base_h), JN_PILLAR.lightened(0.2), 0.8)
		FastDraw.circle(self, pb, 2.6, JN_GRANITE) # 주춧돌
	if not bell_drawn:
		_jongnu_bell(C, AX, AY, base_h, top_h)
	for r: Array in front_rails:
		_jongnu_rail(C, AX, AY, r, base_h, (r[1] as float) > 0.5 and (r[3] as float) > 0.5)
	# 4) 단청 띠(창방) — 기둥머리를 잇는 초록 띠 + 붉은·노란 점
	var ring: Array = [Vector2(-0.68, -0.68), Vector2(0.68, -0.68), Vector2(0.68, 0.68), Vector2(-0.68, 0.68)]
	for i in range(4):
		var a0: Vector2 = ring[i]
		var a1: Vector2 = ring[(i + 1) % 4]
		var q0 := _jq(C, AX, AY, a0.x, a0.y, top_h)
		var q1 := _jq(C, AX, AY, a1.x, a1.y, top_h)
		MarketArt.draw_safe_quad(self, q0, q1, q1 - Vector2(0, 5), q0 - Vector2(0, 5), JN_DANCHEONG)
		draw_line(q0, q1, Color("c0392b"), 1.0)
		for k in range(1, 6):
			FastDraw.circle(self, q0.lerp(q1, float(k) / 6.0) - Vector2(0, 2.5), 0.9, Color("f4d03f") if k % 2 == 0 else Color("e05a3a"))
	# 5) 모임지붕 + 들린 처마 끝 + 절병통
	MarketArt.roof(self, C, AX, AY, 1.02, 1.02, 0.02, top_h + 4.0, top_h + 30.0, Color("5a6068"), false, snow)
	for e: Vector2 in [Vector2(-1.02, -1.02), Vector2(1.02, -1.02), Vector2(1.02, 1.02), Vector2(-1.02, 1.02)]:
		var tip := _jq(C, AX, AY, e.x, e.y, top_h + 4.0)
		var out := (tip - C).normalized()
		draw_line(tip, tip + out * 4.0 - Vector2(0, 5), Color("3a4048"), 2.0)
		FastDraw.circle(self, tip + Vector2(0, 2), 1.3, JN_DANCHEONG)
		if snow:
			FastDraw.circle(self, tip + out * 3.5 - Vector2(0, 4.5), 1.4, Color("f8fafc"))
	var apex := C - Vector2(0, top_h + 30.0)
	for k in range(4):
		FastDraw.circle(self, apex - Vector2(0, 2.0 + 3.2 * float(k)), 3.0 - 0.5 * float(k), Color("2a2a2e"))
	if snow:
		FastDraw.circle(self, apex - Vector2(0, 15.0), 2.2, Color("f8fafc"))
	# 6) 현판 與民閣 — 화면 앞쪽 처마 아래
	var fm := _jq(C, AX, AY, 0.0, 0.68, top_h + 1.0)
	if _jq(C, AX, AY, 0.68, 0.0, 0.0).y > _jq(C, AX, AY, 0.0, 0.68, 0.0).y:
		fm = _jq(C, AX, AY, 0.68, 0.0, top_h + 1.0)
	draw_rect(Rect2(fm + Vector2(-12, -6), Vector2(24, 9)), Color("2a2018"))
	draw_rect(Rect2(fm + Vector2(-12, -6), Vector2(24, 9)), Color("d4af37"), false, 0.8)
	draw_string(ThemeDB.fallback_font, fm + Vector2(-10.5, 1.5), "與民閣", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("f4e8c8"))

## 돌난간 한 변: 난간동자(흰 기둥 머리 둥글게) + 위아래 두 줄 난간대. stair면 가운데(계단 자리)를 비운다.
func _jongnu_rail(C: Vector2, AX: Vector2, AY: Vector2, r: Array, base_h: float, stair: bool) -> void:
	var snow: bool = (band_master.current_season if band_master else current_season) == "겨울"
	var n := 7
	for k in range(n + 1):
		var tt := float(k) / float(n)
		var u := lerpf(float(r[0]), float(r[2]), tt)
		var v := lerpf(float(r[1]), float(r[3]), tt)
		if stair and absf(u) < 0.25:
			continue
		var q := _jq(C, AX, AY, u, v, base_h)
		draw_line(q, q - Vector2(0, 7), JN_GRANITE, 2.0)
		FastDraw.circle(self, q - Vector2(0, 7.5), 1.4, Color("f4f2ec"))
		if snow:
			FastDraw.circle(self, q - Vector2(0, 8.2), 1.1, Color("f8fafc"))
	for hh: float in [3.0, 6.0]:
		var rail_c: Color = Color("ffffff") if (snow and hh > 5.0) else Color("f0ece2")
		if stair:
			for seg: Array in [[-1.0, -0.25], [0.25, 1.0]]:
				var a0 := _jq(C, AX, AY, clampf(float(seg[0]), -0.88, 0.88) if absf(float(r[0]) - float(r[2])) > 0.1 else float(r[0]), float(r[1]), base_h + hh)
				var a1 := _jq(C, AX, AY, clampf(float(seg[1]), -0.88, 0.88) if absf(float(r[0]) - float(r[2])) > 0.1 else float(r[0]), float(r[1]), base_h + hh)
				draw_line(a0, a1, rail_c, 1.6 if (snow and hh > 5.0) else 1.4)
		else:
			draw_line(_jq(C, AX, AY, float(r[0]), float(r[1]), base_h + hh), _jq(C, AX, AY, float(r[2]), float(r[3]), base_h + hh), rail_c, 1.6 if (snow and hh > 5.0) else 1.4)

## 범종(청동, 아래로 벌어진 몸통·띠·당좌) + 용뉴 고리 + 옆에 두 줄로 매단 당목
func _jongnu_bell(C: Vector2, AX: Vector2, _AY: Vector2, base_h: float, top_h: float) -> void:
	var top := C - Vector2(0, top_h - 2.0)
	var b_top := C - Vector2(0, top_h - 9.0)
	var b_bot := C - Vector2(0, base_h + 5.0)
	draw_line(top, b_top, Color("3a3a3a"), 1.4)
	FastDraw.circle(self, b_top + Vector2(0, -1.5), 2.2, Color("4a5650")) # 용뉴
	var body := PackedVector2Array([b_top + Vector2(-5.5, 0), b_top + Vector2(5.5, 0), b_bot + Vector2(8.5, 0), b_bot + Vector2(-8.5, 0)])
	FastDraw.poly(self, body, Color("3e4a46"))
	FastDraw.poly(self, PackedVector2Array([b_top + Vector2(-5.5, 0), b_top + Vector2(-2.5, 0), b_bot + Vector2(-4, 0), b_bot + Vector2(-8.5, 0)]), Color("52605a"))
	for k: float in [0.15, 0.85]:
		var y := lerpf(b_top.y, b_bot.y, k)
		var w := lerpf(5.5, 8.5, k)
		draw_line(Vector2(C.x - w, y), Vector2(C.x + w, y), Color("6a7a72"), 1.0)
	FastDraw.circle(self, Vector2(C.x + 2.0, lerpf(b_top.y, b_bot.y, 0.6)), 1.6, Color("7a8a80")) # 당좌
	# 당목: 종 옆에 가로로 매단 통나무
	var lg := C + AX * 0.32 - Vector2(0, base_h + 14.0)
	var lg_dir := AX.normalized() * 9.0
	draw_line(lg - Vector2(0, top_h - base_h - 16.0), lg, Color("8a7a5a"), 0.7)
	draw_line(lg + lg_dir - Vector2(0, top_h - base_h - 16.0), lg + lg_dir, Color("8a7a5a"), 0.7)
	draw_line(lg - lg_dir * 0.3, lg + lg_dir * 1.2, Color("7a5634"), 3.0)

## ─────────────────────────────────────────────── 남수문(南水門)
## PORT-TRACE [남수문]: 실물 사진 고증 — 화홍문과 달리 누각이 없고, 흰 화강암 석축에 아홉 칸 무지개 홍예가 줄지어 뚫리고
## (물이 아치마다 갈라져 흘러나감), 그 위로 검은 전돌을 촘촘히 쌓은 여장(둥근 머리 타)과 총안·현안, 붉은 판문 세 짝.
## 칸마다 화강암 석축 몸체를 그리고, 구간의 가장 앞 칸에서 구간 전체 정면(홍예 9 + 전돌 여장)을 한 번에 그린다.
func _draw_namsumun(x: int, y: int, t: Dictionary) -> void:
	var lvl := 1.0
	var q_n := cell_center(x, y, lvl)
	var q_e := cell_center(x + 1, y, lvl)
	var q_s := cell_center(x + 1, y + 1, lvl)
	var q_w := cell_center(x, y + 1, lvl)
	var cq := (q_n + q_e + q_s + q_w) * 0.25
	var ce: Array = t.get("corner_elev", [1.0, 1.0, 1.0, 1.0])
	var water_avg: float = (float(ce[0]) + float(ce[1]) + float(ce[2]) + float(ce[3])) / 4.0
	var drop: float = maxf(0.0, cell_center(x, y, water_avg).y - cell_center(x, y, lvl).y)
	var down := Vector2(0, drop)
	var we := grid.is_wall_connector(x + 1, y)
	var ww := grid.is_wall_connector(x - 1, y)
	var wn := grid.is_wall_connector(x, y - 1)
	var ws := grid.is_wall_connector(x, y + 1)
	var along_x: bool = (we or ww) or not (wn or ws)
	var k := 0.34
	var frac := grid.wall_build_fraction(t)
	var done := frac >= 1.0
	var wh := WALL_HEIGHT * frac + drop
	# 석축 몸체: 구간 방향으로 칸을 꽉 채우는 긴 상자(두께 2k)
	var mid_n := (q_n + q_e) * 0.5
	var mid_e := (q_e + q_s) * 0.5
	var mid_s := (q_s + q_w) * 0.5
	var mid_w := (q_w + q_n) * 0.5
	var run_a: Vector2 = (mid_e - mid_w) * 0.5 if along_x else (mid_s - mid_n) * 0.5
	var side: Vector2 = (mid_s - mid_n) * 0.5 if along_x else (mid_e - mid_w) * 0.5
	var sk := side * (2.0 * k)
	var g := PackedVector2Array([cq - run_a - sk + down, cq + run_a - sk + down, cq + run_a + sk + down, cq - run_a + sk + down])
	var no_merlon: Array[bool] = [false, false, false, false]
	var faces: Array[bool] = [true, true, true, true]
	_draw_wall_block(g, faces, no_merlon, wh, Color("e6e2d8"), Color("c8c2b4"), Color("d8d2c4") if done else Color("a89c82"), Color("cfc4ab"), Color("454b54"))
	if not done:
		_draw_scaffold(g, wh)
		var span_uc := _get_water_wall_span(x, y, along_x)
		if span_uc.get("is_render_tile", false):
			var sc_center: Vector2 = span_uc.get("center_pivot", span_uc.get("center", cq))
			if sc_center == Vector2.ZERO:
				sc_center = cq
			draw_set_transform(sc_center, 0.0, Vector2.ONE)
			# [단일화 픽스] 현판은 WorldMarkerManager 노드로 일원화됨
			# _draw_gate_name_tag("[축조 중] 남수문 (南水門)", wh + 22.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var span := _get_water_wall_span(x, y, along_x)
	if not span.get("is_render_tile", false):
		return
	# 구간 전체 정면 선(L→R)
	var face_off: Vector2 = sk if sk.y >= 0.0 else -sk
	var st: Vector2i = span.get("start", Vector2i(x, y))
	var en: Vector2i = span.get("end", Vector2i(x, y))
	var c_st := (cell_center(st.x, st.y, lvl) + cell_center(st.x + 1, st.y + 1, lvl)) * 0.5
	var c_en := (cell_center(en.x, en.y, lvl) + cell_center(en.x + 1, en.y + 1, lvl)) * 0.5
	var L := c_st - run_a + face_off + down
	var R := c_en + run_a + face_off + down
	if L.x > R.x:
		var tmp := L
		L = R
		R = tmp
	var dirv := (R - L)
	var unit := dirv.normalized()
	# 1) 아홉 칸 홍예 + 아치마다 갈라져 흐르는 물살
	var n_arch := 9
	var cell_w := dirv.length() / float(n_arch)
	for i in range(n_arch):
		var b := L + dirv * ((float(i) + 0.5) / float(n_arch)) - Vector2(0, 1.0)
		_draw_gate_arch(b, unit * cell_w * 0.34, 2.0, minf(cell_w * 0.34, wh * 0.45))
		for s_i in range(3):
			var wy := b + Vector2(0, 2.5 + s_i * 2.5)
			draw_line(wy - unit * cell_w * 0.3, wy + unit * cell_w * 0.3, Color(0.88, 0.95, 1.0, 0.75 - s_i * 0.2), 1.4)
	var snow: bool = (band_master.current_season if band_master else current_season) == "겨울"
	# 2) 검은 전돌 여장(석축 위) — 앞면 띠 + 윗면 + 벽돌 줄눈
	var h0 := wh
	var h1 := wh + 11.0
	var back := -face_off * 2.0
	var top_color: Color = Color("dbe4eb") if snow else Color("454b54")
	MarketArt.draw_safe_quad(self, L - Vector2(0, h1), R - Vector2(0, h1), R - Vector2(0, h1) + back, L - Vector2(0, h1) + back, top_color)
	MarketArt.draw_safe_quad(self, L - Vector2(0, h0), R - Vector2(0, h0), R - Vector2(0, h1), L - Vector2(0, h1), Color("3b414a"))
	for row in range(1, 4):
		var hy := h0 + (h1 - h0) * float(row) / 4.0
		draw_line(L - Vector2(0, hy), R - Vector2(0, hy), Color("5a616b"), 0.5)
	# 3) 둥근 머리 타(여장 머리) + 총안(작은 구멍)·현안
	var n_mer := maxi(8, int(dirv.length() / 7.0))
	for i in range(n_mer):
		var m := L + dirv * ((float(i) + 0.5) / float(n_mer)) - Vector2(0, h1)
		draw_rect(Rect2(m + Vector2(-2.6, -3.5), Vector2(5.2, 3.5)), Color("3d434c"))
		FastDraw.circle(self, m + Vector2(0, -3.5), 2.6, Color("40464f"))
		if snow:
			FastDraw.circle(self, m + Vector2(0, -4.2), 1.5, Color("f8fafc"))
		draw_rect(Rect2(m + Vector2(-0.7, 3.0), Vector2(1.4, 1.6)), Color("0e0e10")) # 총안
	# 4) 붉은 판문(포혈 문짝) 세 짝
	for fpos: float in [0.22, 0.5, 0.78]:
		var dp := L + dirv * fpos - Vector2(0, h0 + 1.5)
		FastDraw.poly(self, PackedVector2Array([dp + Vector2(-2.6, 0), dp + Vector2(2.6, 0), dp + Vector2(2.6, -5), dp + Vector2(0, -6.6), dp + Vector2(-2.6, -5)]), Color("a8322a"))
		draw_line(dp + Vector2(0, 0), dp + Vector2(0, -6.2), Color("6a1a14"), 0.6)
	# 5) 현판 라벨 (전체 9칸 홍예 석축 중앙 상단)
	var namsu_center := (L + R) * 0.5
	var _ns_tag: String = "남수문 (南水門)"
	draw_set_transform(namsu_center, 0.0, Vector2.ONE)
	# [단일화 픽스] 현판은 WorldMarkerManager 노드로 일원화됨
	# _draw_gate_name_tag(ns_tag, h1 + 22.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ─────────────────────────────────────────────── 매향교(梅香橋)
## PORT-TRACE [매향교]: 옛 사진 고증 — 네모난 화강암 장대석을 층층이 쌓은 교각 사이로 네모난 수문이 뚫리고, 그 위에 넓적한
## 판석 상판을 얹은 평교. 교각 상류 쪽엔 물살을 가르는 마름모 분수(分水) 석축, 상판 양옆엔 돌난간과 엄지기둥(동자석).
## 칸마다 다리 방향(길이 이어진 축)을 따라 교각 둘(칸 양 끝) + 판석 + 난간을 그린다.
func _draw_maehyang(x: int, y: int, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2, c: Vector2) -> void:
	var ce := grid.is_road_connector(x + 1, y) or grid.is_road_connector(x - 1, y)
	var mid_n := (p_n + p_e) * 0.5
	var mid_e := (p_e + p_s) * 0.5
	var mid_s := (p_s + p_w) * 0.5
	var mid_w := (p_w + p_n) * 0.5
	var run: Vector2 = (mid_e - mid_w) * 0.5 if ce else (mid_s - mid_n) * 0.5  # 다리 진행 반벡터
	var side: Vector2 = (mid_s - mid_n) * 0.5 if ce else (mid_e - mid_w) * 0.5 # 다리 폭 반벡터
	if side.y < 0.0:
		side = -side # side는 화면 앞쪽
	var deck_h := 9.0
	var half_w := 0.55
	var granite := Color("d8d2c4")
	var granite_d := Color("aaa396")
	var shadow := Color("2a2a2e")
	# 1) 교각(칸 양 끝) — 장대석 층 + 분수 석축(상류 = 화면 뒤쪽)
	for u: float in [-0.85, 0.85]:
		var pc := c + run * u
		# 분수 석축(뒤쪽 마름모 뾰족이)
		var tip := pc - side * (half_w + 0.35)
		FastDraw.poly(self, PackedVector2Array([tip, pc - side * half_w + run * 0.13, pc - side * half_w + run * 0.13 - Vector2(0, deck_h - 2), tip - Vector2(0, deck_h - 4), pc - side * half_w - run * 0.13 - Vector2(0, deck_h - 2), pc - side * half_w - run * 0.13]), granite_d)
		# 교각 몸통(앞면)
		var a0 := pc - run * 0.13 + side * half_w
		var a1 := pc + run * 0.13 + side * half_w
		MarketArt.draw_safe_quad(self, a0, a1, a1 - Vector2(0, deck_h), a0 - Vector2(0, deck_h), granite)
		for k in range(1, 3):
			draw_line(a0 - Vector2(0, deck_h * float(k) / 3.0), a1 - Vector2(0, deck_h * float(k) / 3.0), granite_d, 0.7)
	# 2) 교각 사이 네모난 수문(어두운 구멍) + 흐르는 물
	var g0 := c - run * 0.72 + side * half_w
	var g1 := c + run * 0.72 + side * half_w
	MarketArt.draw_safe_quad(self, g0, g1, g1 - Vector2(0, deck_h - 1.5), g0 - Vector2(0, deck_h - 1.5), shadow)
	draw_line(g0 + Vector2(0, -1), g1 + Vector2(0, -1), Color(0.85, 0.93, 1.0, 0.7), 1.2)
	# 3) 판석 상판(윗면 + 앞 두께) — 판석 이음 줄
	var top: Array[Vector2] = [c - run - side * half_w, c + run - side * half_w, c + run + side * half_w, c - run + side * half_w]
	var up := Vector2(0, deck_h)
	MarketArt.draw_safe_quad(self, top[3] - up, top[2] - up, top[2] - up + Vector2(0, 2.5), top[3] - up + Vector2(0, 2.5), granite_d)
	MarketArt.draw_safe_quad(self, top[0] - up, top[1] - up, top[2] - up, top[3] - up, granite)
	for k in range(1, 4):
		var tt := float(k) / 4.0
		draw_line(top[0].lerp(top[1], tt) - up, top[3].lerp(top[2], tt) - up, granite_d, 0.7)
	# 4) 돌난간: 양옆 난간대 + 엄지기둥(칸 양 끝)·동자석
	for sgn: float in [-1.0, 1.0]:
		var r0 := c - run + side * half_w * sgn * 0.92 - up
		var r1 := c + run + side * half_w * sgn * 0.92 - up
		draw_line(r0 - Vector2(0, 4), r1 - Vector2(0, 4), Color("ece8de"), 1.6)
		for k in range(4):
			var q := r0.lerp(r1, (float(k) + 0.5) / 4.0)
			draw_line(q, q - Vector2(0, 4), Color("e2ddd0"), 1.4)
		if not grid._is_water_road(x - int(round(run.normalized().x)), y) or not grid._is_water_road(x + int(round(run.normalized().x)), y):
			for e: Vector2 in [r0, r1]:
				draw_line(e, e - Vector2(0, 7), Color("f0ece2"), 2.6) # 엄지기둥
				FastDraw.circle(self, e - Vector2(0, 7.5), 1.6, Color("f6f3ec"))

	# 5) 현판 라벨 (매향교 중앙 상단)
	if _is_maehyang_center_tile(x, y):
		draw_set_transform(c, 0.0, Vector2.ONE)
		# [단일화 픽스] 현판은 WorldMarkerManager 노드로 일원화됨
		# _draw_gate_name_tag("매향교 (梅香橋)", 24.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## 매향교 구간의 중앙 칸인지 검사
func _is_maehyang_center_tile(x: int, y: int) -> bool:
	var span_x: Array[Vector2i] = []
	var cx := x
	while grid.in_bounds(cx - 1, y) and grid.grid[y][cx - 1].get("is_maehyang", false):
		cx -= 1
	var px := cx
	while grid.in_bounds(px, y) and grid.grid[y][px].get("is_maehyang", false):
		span_x.append(Vector2i(px, y))
		px += 1
	if span_x.size() > 1:
		return Vector2i(x, y) == span_x[int(float(span_x.size()) / 2.0)]

	var span_y: Array[Vector2i] = []
	var cy := y
	while grid.in_bounds(x, cy - 1) and grid.grid[cy - 1][x].get("is_maehyang", false):
		cy -= 1
	var py := cy
	while grid.in_bounds(x, py) and grid.grid[py][x].get("is_maehyang", false):
		span_y.append(Vector2i(x, py))
		py += 1
	if span_y.size() > 1:
		return Vector2i(x, y) == span_y[int(float(span_y.size()) / 2.0)]
	return true

## 매화나무: 굽은 검은 가지 + 봄엔 분홍·흰 꽃이 가득, 여름·가을엔 초록 잎, 겨울엔 빈 가지에 흰 꽃망울 몇
func _draw_plum_tree(c: Vector2, x: int, y: int) -> void:
	var hsh := absi(x * 7919 + y * 104729)
	var base := c + Vector2(float(hsh % 9) - 4.0, 2.0)
	var trunk := Color("3a2a22")
	draw_line(base, base + Vector2(-2, -8), trunk, 2.4)
	draw_line(base + Vector2(-2, -8), base + Vector2(-8, -14), trunk, 1.6)
	draw_line(base + Vector2(-2, -8), base + Vector2(4, -16), trunk, 1.6)
	draw_line(base + Vector2(4, -16), base + Vector2(9, -18), trunk, 1.0)
	draw_line(base + Vector2(-8, -14), base + Vector2(-11, -19), trunk, 1.0)
	var pts: Array[Vector2] = [Vector2(-8, -15), Vector2(-11, -19), Vector2(-5, -17), Vector2(1, -15), Vector2(4, -17), Vector2(8, -18), Vector2(6, -21), Vector2(-2, -20), Vector2(2, -12), Vector2(-6, -11)]
	match current_season:
		"봄":
			var pink := hsh % 2 == 0
			for i in range(pts.size()):
				FastDraw.circle(self, base + pts[i], 2.2, Color("f4b8c8") if (pink and i % 3 != 0) else Color("fbf4f2"))
				FastDraw.circle(self, base + pts[i] + Vector2(1.5, 1.0), 1.4, Color("e888a8") if pink else Color("f8e8ec"))
		"겨울":
			for i in range(0, pts.size(), 3):
				FastDraw.circle(self, base + pts[i], 1.0, Color("f8f4f0"))
		_:
			for i in range(pts.size()):
				FastDraw.circle(self, base + pts[i], 2.4, Color("5a8a3a") if current_season == "여름" else Color("a8883a"))

# ─────────────────────────────────────────────── 2단계: 봉돈 4x1 · 서장대 2x2 · 영화정 2x2
## 묶음(site_tiles) 가운데 화면 가장 앞(깊이 x+y 최대, 같으면 x 최대) 칸 — 여러 칸 건물을 이 칸에서 한 번에 그린다
## PORT-TRACE [랜드마크 PNG 혼합]: 방향이 고정된 독립 랜드마크는 assets/sprites/buildings/lm_<이름>.png가 있으면
## 칸마다 바닥만 깔고 묶음의 가장 앞 칸에서 그림 한 장을 그린다(서당·서원과 같은 방식). 그림이 없으면 false → 기존 코드 그림.
## 크기 = [가로칸, 세로칸, 기준점에서 묶음 왼쪽 위까지 거리(site_tiles가 없을 때만 씀)], 캔버스 = 가로 (w+h)*32.
const LANDMARK_PNG := {
	"haenggung": [7, 7, -3, Vector2i(448, 320)],
	"hyanggyo": [4, 4, -1, Vector2i(256, 200)],
	"gwana": [2, 2, 0, Vector2i(128, 112)],
	"jongnu": [2, 2, 0, Vector2i(128, 112)],
	"jinhulso": [2, 2, 0, Vector2i(128, 112)],
}
static var _landmark_png_state := {} # 이름 → true(그림 있음)/false

func _landmark_png(key: String, x: int, y: int, anchor: Vector2i, p_n: Vector2, p_e: Vector2, p_s: Vector2, p_w: Vector2) -> bool:
	if not _landmark_png_state.has(key):
		var lp := "res://assets/sprites/buildings/lm_%s.png" % key
		_landmark_png_state[key] = ResourceLoader.exists(lp) or FileAccess.file_exists(ProjectSettings.globalize_path(lp)) # 편집기에서 가져오기 전이어도
	if not bool(_landmark_png_state[key]):
		return false
	var spec: Array = LANDMARK_PNG[key]
	var season_now: String = band_master.current_season if band_master else current_season
	var snow := season_now == "겨울"
	FastDraw.poly(self, PackedVector2Array([p_n, p_e, p_s, p_w]), Color("edf2f7") if snow else Color("cbbd98"))
	# 묶음 범위: 완공 때 저장된 칸 목록이 있으면 그것으로, 없으면 크기표로
	var x0 := anchor.x + int(spec[2])
	var y0 := anchor.y + int(spec[2])
	var x1 := x0 + int(spec[0]) - 1
	var y1 := y0 + int(spec[1]) - 1
	if grid.in_bounds(anchor.x, anchor.y):
		var st: Variant = grid.grid[anchor.y][anchor.x].get("site_tiles", null)
		if st is Array and not (st as Array).is_empty():
			x0 = 1 << 20
			y0 = 1 << 20
			x1 = -1
			y1 = -1
			for q: Vector2i in st:
				x0 = mini(x0, q.x)
				y0 = mini(y0, q.y)
				x1 = maxi(x1, q.x)
				y1 = maxi(y1, q.y)
	if x != x1 or y != y1:
		return true # 가장 앞 칸이 아니면 바닥만
	var size: Vector2i = spec[3]
	var tex: Texture2D = SpriteCacheManager.get_seasonal_or_base_texture("buildings", "lm_" + key, SeasonColorFilter.get_current_season_suffix(season_now), size)
	if tex == null:
		return true
	var w := float(x1 - x0 + 1)
	var h := float(y1 - y0 + 1)
	var bc := cell_center(float(x0) + w * 0.5, float(y0) + h * 0.5, 1.0)
	if _draw_fitted(tex, "lm_" + key, cell_center(float(x0), float(y1 + 1), 1.0), cell_center(float(x1 + 1), float(y0), 1.0), cell_center(float(x1 + 1), float(y1 + 1), 1.0), SeasonColorFilter.get_current_tile_tint(season_now)):
		return true
	var r := Rect2(bc.x - float(size.x) * 0.5, bc.y + (w + h) * 8.0 - float(size.y), float(size.x), float(size.y))
	draw_texture_rect(tex, r, false, SeasonColorFilter.get_current_tile_tint(season_now))
	return true

## PORT-TRACE [그림 땅에 맞추기]: 제미나이 그림은 바닥 마름모가 반듯한 2:1이 아니라(향교는 왼쪽 모서리가 9px 낮고 경사도 가파름)
## 사각형 그대로 붙이면 땅에서 비스듬히 들려 보였다. 그림 바닥의 세 모서리(왼쪽·오른쪽 끝의 가장 낮은 점, 가운데 맨 아래)를 재서
## 부지 땅의 세 꼭짓점(왼쪽·오른쪽·아래)에 정확히 맞추는 변환으로 그린다. 잰 값은 그림마다 한 번만.
static var _fit_anchor_cache := {}
func fit_anchors(key: String, tex: Texture2D) -> Array:
	if _fit_anchor_cache.has(key):
		return _fit_anchor_cache[key]
	var img := tex.get_image()
	var out: Array = []
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		var w := img.get_width()
		var h := img.get_height()
		var low := func(x: int) -> int:
			for yy in range(h - 1, -1, -1):
				if img.get_pixel(x, yy).a > 0.25:
					return yy
			return -1
		var lx := 0
		while lx < w - 1 and low.call(lx) < 0:
			lx += 1
		var rx := w - 1
		while rx > 0 and low.call(rx) < 0:
			rx -= 1
		var bx := int(float(w) / 2.0)
		out = [Vector2(lx, low.call(mini(lx + 1, w - 1))), Vector2(rx + 1, low.call(maxi(rx - 1, 0))), Vector2(bx, low.call(bx) + 1)]
	_fit_anchor_cache[key] = out
	return out

## 그림의 [왼쪽·오른쪽·아래] 바닥점을 화면의 fl·fr·fb로 보내는 변환(그림 좌표 → 화면). 잴 수 없으면 null
func fit_xf(key: String, tex: Texture2D, fl: Vector2, fr: Vector2, fb: Vector2) -> Variant:
	var an: Array = fit_anchors(key, tex)
	if an.size() < 3 or (an[2] as Vector2).y <= (an[0] as Vector2).y:
		return null
	var L: Vector2 = an[0]
	var R: Vector2 = an[1]
	var B: Vector2 = an[2]
	var src := Transform2D(R - L, B - L, L)
	var dst := Transform2D(fr - fl, fb - fl, fl)
	return dst * src.affine_inverse()

func _draw_fitted(tex: Texture2D, key: String, fl: Vector2, fr: Vector2, fb: Vector2, tint: Color, shadow: Color = Color(0, 0, 0, 0)) -> bool:
	var xf: Variant = fit_xf(key, tex, fl, fr, fb)
	if xf == null:
		return false
	if shadow.a > 0.0:
		draw_set_transform_matrix(Transform2D(0.0, Vector2(3.0, 4.0)) * (xf as Transform2D))
		draw_texture(tex, Vector2.ZERO, shadow)
	draw_set_transform_matrix(xf)
	draw_texture(tex, Vector2.ZERO, tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	return true

func _group_front_tile(anchor: Vector2i) -> Vector2i:
	if not grid.in_bounds(anchor.x, anchor.y):
		return anchor
	var tiles: Array = grid.grid[anchor.y][anchor.x].get("site_tiles", [anchor])
	var best: Vector2i = anchor
	for p: Vector2i in tiles:
		if p.x + p.y > best.x + best.y or (p.x + p.y == best.x + best.y and p.x > best.x):
			best = p
	return best

## 봉돈 로컬 좌표: u = 성벽을 따라 0~4칸, v = 성벽 가운데 줄에서 바깥쪽으로(칸 단위) → 화면 좌표
func _bd_pt(info: Dictionary, u: float, v: float, h: float = 0.0) -> Vector2:
	var s: Vector2i = info["start"]
	var d: Vector2i = info["axis"]
	var o: Vector2i = info["out"]
	var g := Vector2(s) + Vector2(0.5, 0.5) + Vector2(d) * (u - 0.5) + Vector2(o) * v
	if not info.has("elevation"):
		var el: float = float(grid.tile(s.x, s.y).get("elevation", 1.0)) if grid and grid.in_bounds(s.x, s.y) else 1.0
		info["elevation"] = el
	var elev: float = float(info["elevation"])
	return cell_center(g.x, g.y, elev) - Vector2(0, h)

const BD_H := 28.0
const BD_V0 := -0.42
const BD_V1 := 1.3

## 연조(굴뚝) 다섯의 꼭대기 화면 좌표 — CitizenLayer가 연기·봉화를 그릴 때 쓴다
func bongdon_chimney_tops(info: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var top_h: float = WALL_HEIGHT + BD_H
	for k in range(5):
		out.append(_bd_pt(info, 0.45 + 0.775 * float(k), 0.85, top_h + 14.0))
	return out

## PORT-TRACE [봉돈 4x1]: 고증 — 성벽 일부를 성 밖으로 내밀어 쌓은 벽돌 요새. 아래 화강암 기단 + 위 회흑색 전돌 몸체(줄눈),
## 바깥 세 변 여장(타·총안), 상부에 연조(봉수 굴뚝) 다섯을 한 줄로, 바깥 면 가운데 아궁이(불 넣는 홍예). 성벽 쪽 면에는 출입구.
func _draw_bongdon4(info: Dictionary) -> void:
	var snow: bool = (band_master.current_season if band_master else current_season) == "겨울"
	var um := 2.0
	var vm := (BD_V0 + BD_V1) * 0.5
	var cb := _bd_pt(info, um, vm)
	var A := _bd_pt(info, um + 1.0, vm) - cb
	var F := _bd_pt(info, um, vm + 1.0) - cb
	var bv := (BD_V1 - BD_V0) * 0.5
	# 1. 화강암 치대 기단: 성벽 높이(WALL_HEIGHT=18.0)와 100% 일치시켜 양옆 성벽 팔과 수평 연결
	_ft_tex_box(cb, A, F, 1.96, bv, 0.0, WALL_HEIGHT, false)
	# 2. 전돌 몸체: 성벽 상판(WALL_HEIGHT) 위로 솟아오른 벽돌 요새
	_ft_tex_box(cb, A, F, 1.96, bv, WALL_HEIGHT, WALL_HEIGHT + BD_H, true)
	var g: Array[Vector2] = [cb - A * 1.96 - F * bv, cb + A * 1.96 - F * bv, cb + A * 1.96 + F * bv, cb - A * 1.96 + F * bv]
	# 윗면
	var top_h := WALL_HEIGHT + BD_H
	var top_col: Color = Color("dbe3eb") if snow else Color("948872")
	MarketArt.draw_safe_quad(self, g[0] - Vector2(0, top_h), g[1] - Vector2(0, top_h), g[2] - Vector2(0, top_h), g[3] - Vector2(0, top_h), top_col)
	if snow:
		draw_line(g[0] - Vector2(0, top_h), g[1] - Vector2(0, top_h), Color("f8fafc"), 1.8)
		draw_line(g[1] - Vector2(0, top_h), g[2] - Vector2(0, top_h), Color("f8fafc"), 1.8)
	# 바깥 면 가운데 아궁이(홍예) + 성벽 쪽 출입문
	_draw_gate_arch(_bd_pt(info, 2.0, BD_V1, WALL_HEIGHT + 2.0), A.normalized() * 4.0, 2.0, 4.0)
	# 연조 다섯 (굴뚝)
	for k in range(5):
		var cc := _bd_pt(info, 0.45 + 0.775 * float(k), 0.85, top_h)
		draw_rect(Rect2(cc + Vector2(-3.2, -14), Vector2(6.4, 14)), Color("7a746c"))
		draw_rect(Rect2(cc + Vector2(-3.2, -14), Vector2(6.4, 14)), Color("3b2d22"), false, 0.6)
		for hh2 in range(3, 14, 3):
			draw_line(cc + Vector2(-3.2, -hh2), cc + Vector2(3.2, -hh2), Color("5f574c"), 0.5)
		var chimney_cap_col: Color = Color("f8fafc") if snow else Color("948872")
		draw_rect(Rect2(cc + Vector2(-4, -16.5), Vector2(8, 2.5)), chimney_cap_col)
		if snow:
			draw_line(cc + Vector2(-4, -16.5), cc + Vector2(4, -16.5), Color("ffffff"), 1.5)
		FastDraw.circle(self, cc + Vector2(0, -16.8), 1.6, Color("1a1816"))
	# 여장(바깥 세 변): 타 + 총안
	var edges: Array = [[0.0, BD_V1, 4.0, BD_V1], [0.0, BD_V0, 0.0, BD_V1], [4.0, BD_V0, 4.0, BD_V1]]
	for e: Array in edges:
		var e0 := _bd_pt(info, float(e[0]), float(e[1]), top_h)
		var e1 := _bd_pt(info, float(e[2]), float(e[3]), top_h)
		_draw_wall_merlons(e0, e1, FT_TILE, snow, ((e0 + e1) * 0.5).x >= cb.x)

## 바위 산정(서장대 터): 회색 바위 덩이 몇
func _draw_rock_outcrop(c: Vector2, x: int, y: int) -> void:
	var s: String = band_master.current_season if band_master else current_season
	var h := absi(x * 31 + y * 17)
	for k in range(3):
		var o := Vector2(float((h >> (k * 3)) % 21) - 10.0, float((h >> (k * 2 + 1)) % 9) - 4.0)
		var rock_col: Color = Color("dbe3eb") if s == "겨울" else (Color("8a867e") if k % 2 == 0 else Color("9e9a90"))
		FastDraw.poly(self, PackedVector2Array([c + o + Vector2(-6, 2), c + o + Vector2(6, 2), c + o + Vector2(4, -4), c + o + Vector2(-3, -5)]), rock_col)
		if s == "겨울":
			draw_line(c + o + Vector2(-3, -5), c + o + Vector2(4, -4), Color("f8fafc"), 1.6)
		elif s == "가을":
			FastDraw.circle(self, c + o + Vector2(5.0, 1.0), 1.2, Color("d97706"))

## PORT-TRACE [서장대 2x2 입체 재설계]: 고증 — 팔달산 정상 바위 위 화강암 장대석 기단(앞 돌계단) → 1층(사방이 트인 붉은 기둥·
## 계자난간, 둘레 단청 띠) → 1층 처마 지붕(우진각 치마) → 2층(더 좁은 마루·난간·창호 몸체, 전면 西將臺 금빛 편액) →
## 2층 팔작지붕(앙곡 처마·합각·취두) → 용마루 끝 수자기(帥). 오른쪽 아래로 길게 떨어지는 그림자, 기단 앞 횃불 걸이대 둘, 바로 옆 서노대.
## 편액은 지붕이 아니라 2층 몸체 벽(처마 바로 아래)에 붙인다.
func _draw_seojangdae2(p_n: Vector2, p_e: Vector2, p_w: Vector2, lift: float = 0.0) -> void:
	var C := p_n
	var AX := p_e - p_n
	var AY := p_w - p_n
	var S := Vector2(1, 0)
	var F := Vector2(0, 1)
	var pav := C + AX * -0.3 + AY * -0.3
	var nod := C + AX * 0.64 + AY * 0.62
	var snow: bool = (band_master.current_season if band_master else current_season) == "겨울"
	var draw_nod_first := nod.y < pav.y
	if lift > 0.0:
		# 성벽 위: 2x2 전체를 성벽 체성(화강암 성돌·성도 상판)으로 받치고, 그 위로 기단·누각을 올린다. 이웃 성벽 팔이 같은 높이로 이어진다.
		var blk := _bh_rect(C, AX, AY, S, F, -1.0, 1.0, -1.0, 1.0)
		var wf := _bh_prism(blk, 0.0, lift, Color("c8bda5"), Color("948872"))
		_bh_courses(wf, 0.0, lift, 3, 9.0, Color("6f6452"))
		for fc: Array in wf:
			draw_line((fc[0] as Vector2) - Vector2(0, lift), (fc[1] as Vector2) - Vector2(0, lift), Color("bfb39a"), 1.0)
		pav.y -= lift
		nod.y -= lift

	# 그림자: 기단·누각이 오른쪽 아래(화면 +x,+y)로 길게 드리운다
	var foot := _bh_rect(pav, AX, AY, S, F, -0.7, 0.7, -0.7, 0.7)
	for k in range(3):
		var off := Vector2(7.0 + float(k) * 7.0, 3.5 + float(k) * 3.5)
		var sh := PackedVector2Array()
		for q: Vector2 in foot:
			sh.append(q + off)
		FastDraw.poly(self, sh, Color(0, 0, 0, 0.13))

	if draw_nod_first:
		_draw_seonodae(nod, AX, AY)

	# 1. 화강암 장대석 기단 + 돌줄눈 + 윗모서리 햇빛, 앞(+v) 돌계단 3단
	var BASE_H := 9.0
	var bf := _bh_prism(foot, 0.0, BASE_H, BH_GRANITE, Color("cdc6b6"))
	_bh_courses(bf, 0.0, BASE_H, 3, 10.0, Color("9c9484"))
	for fc: Array in bf:
		draw_line((fc[0] as Vector2) - Vector2(0, BASE_H), (fc[1] as Vector2) - Vector2(0, BASE_H), Color("ebe6da"), 1.2)
		draw_line(fc[0], fc[1], Color("8a8272"), 1.0) # 땅에 닿는 어두운 선
	for j in range(2, -1, -1):
		var f0 := 0.7 + 0.11 * float(j)
		var hh := BASE_H - 3.0 * float(j + 1)
		MarketArt.draw_safe_quad(self, _bh(pav, AX, AY, S, F, -0.26, f0 + 0.11, hh), _bh(pav, AX, AY, S, F, 0.26, f0 + 0.11, hh), _bh(pav, AX, AY, S, F, 0.26, f0 + 0.11, hh - 3.0), _bh(pav, AX, AY, S, F, -0.26, f0 + 0.11, hh - 3.0), Color("b8b2a2")) # 챌판
		var tread_col: Color = Color("edf2f7") if snow else Color("d8d2c2")
		MarketArt.draw_safe_quad(self, _bh(pav, AX, AY, S, F, -0.26, f0, hh), _bh(pav, AX, AY, S, F, 0.26, f0, hh), _bh(pav, AX, AY, S, F, 0.26, f0 + 0.11, hh), _bh(pav, AX, AY, S, F, -0.26, f0 + 0.11, hh), tread_col) # 디딤판
		if snow:
			draw_line(_bh(pav, AX, AY, S, F, -0.26, f0, hh), _bh(pav, AX, AY, S, F, 0.26, f0, hh), Color("ffffff"), 1.2)
	# 기단 앞 횃불 걸이대 둘(야조 때 불을 밝힌다)
	for tsx: float in [-0.5, 0.5]:
		_sj_torch(_bh(pav, AX, AY, S, F, tsx, 0.86, 0.0))

	# 2. 1층(사방이 트인 마루): 기둥·난간·창방 단청 띠 → 3. 1층 처마 지붕(우진각 치마)
	_sj_tier(pav, AX, AY, 0.52, BASE_H, 27.0, 0.0)
	_bh_paljak(pav, AX, AY, Vector2.ZERO, S, F, 0.84, 0.84, 0.2, 27.5, 34.0, snow)

	# 4. 2층: 더 좁은 마루 + 창호 몸체(편액) + 난간·단청 띠 → 5. 2층 팔작지붕
	_sj_tier(pav, AX, AY, 0.4, 33.0, 49.0, 0.27)
	_bh_paljak(pav, AX, AY, Vector2.ZERO, S, F, 0.66, 0.58, 0.28, 51.0, 68.0, snow)

	# 6. 용마루 끝 수자기(帥): 장대 + 바람에 펄럭이는 큰 깃발
	var rt := _bh(pav, AX, AY, S, F, 0.28, 0.0, 68.0)
	draw_line(rt, rt - Vector2(0, 26.0), Color("3d2916"), 1.6)
	FastDraw.circle(self, rt - Vector2(0, 27.0), 1.6, Color("d4af37"))
	var fl := PackedVector2Array([rt - Vector2(0, 25.0), rt - Vector2(-14.0, 23.0), rt - Vector2(-13.0, 9.0), rt - Vector2(0, 11.0)])
	FastDraw.poly(self, fl, Color("d9a030"))
	FastDraw.polyline(self, PackedVector2Array(fl + PackedVector2Array([fl[0]])), Color("7a4a14"), 1.0)
	draw_string(ThemeDB.fallback_font, rt - Vector2(-3.5, 12.5), "帥", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("8a1f14"))

	if not draw_nod_first:
		_draw_seonodae(nod, AX, AY)

## 한 층: 마루(마루 두께+윗면) → 뒤 난간 → 뒤쪽 기둥 → (몸체: core_half>0이면 가운데 창호 벽) → 앞쪽 기둥 → 앞 난간 → 창방 단청 띠
func _sj_tier(pav: Vector2, AX: Vector2, AY: Vector2, half: float, h_floor: float, h_top: float, core_half: float) -> void:
	var S := Vector2(1, 0)
	var F := Vector2(0, 1)
	var deck := _bh_rect(pav, AX, AY, S, F, -half - 0.09, half + 0.09, -half - 0.09, half + 0.09)
	_bh_prism(deck, h_floor - 1.8, h_floor, Color("5c3a22"), Color("9a7448"))
	var rb: Array = []
	var rf: Array = []
	for fc: Array in _bh_edges(deck):
		if (fc[2] as Vector2).y > 0.02:
			rf.append(fc)
		else:
			rb.append(fc)
	for fc: Array in rb:
		_bh_rail(fc[0], fc[1], h_floor)
	var pil: Array[Vector2] = []
	for pu: float in [-half, 0.0, half]:
		for pv: float in [-half, 0.0, half]:
			if pu == 0.0 and pv == 0.0:
				continue
			pil.append(Vector2(pu, pv))
	pil.sort_custom(func(p, q): return _bh(pav, AX, AY, S, F, p.x, p.y, 0.0).y < _bh(pav, AX, AY, S, F, q.x, q.y, 0.0).y)
	var core_done := core_half <= 0.0
	for pp: Vector2 in pil:
		var pb := _bh(pav, AX, AY, S, F, pp.x, pp.y, h_floor)
		if not core_done and pb.y + h_floor > pav.y:
			_sj_core(pav, AX, AY, core_half, h_floor, h_top)
			core_done = true
		FastDraw.circle(self, pb, 1.9, BH_GRANITE) # 초석
		draw_line(pb, pb - Vector2(0, h_top - h_floor), BH_PILLAR, 2.8)
		draw_line(pb + Vector2(0.9, 0), pb + Vector2(0.9, -(h_top - h_floor)), BH_PILLAR.lightened(0.25), 0.8)
	if not core_done:
		_sj_core(pav, AX, AY, core_half, h_floor, h_top)
	for fc: Array in rf:
		_bh_rail(fc[0], fc[1], h_floor)
	# 창방 단청 띠(기둥머리를 잇는 초록 띠 + 붉은 선 + 노랑·주홍 점)
	var ring := _bh_rect(pav, AX, AY, S, F, -half, half, -half, half)
	var bfaces: Array = []
	for fc: Array in _bh_edges(ring):
		if (fc[2] as Vector2).y > 0.02:
			bfaces.append(fc)
	bfaces.sort_custom(func(p, q): return ((p[0] as Vector2) + (p[1] as Vector2)).y < ((q[0] as Vector2) + (q[1] as Vector2)).y)
	for fc: Array in bfaces:
		var a: Vector2 = fc[0]
		var b: Vector2 = fc[1]
		var q0 := a - Vector2(0, h_top - 0.5)
		var q1 := b - Vector2(0, h_top - 0.5)
		MarketArt.draw_safe_quad(self, q0, q1, q1 - Vector2(0, 4.5), q0 - Vector2(0, 4.5), BH_DANCHEONG)
		draw_line(q0, q1, Color("c0392b"), 1.0)
		var nd := maxi(2, int((b - a).length() / 4.0))
		for k in range(1, nd):
			FastDraw.circle(self, q0.lerp(q1, float(k) / float(nd)) - Vector2(0, 2.2), 0.8, Color("f4d03f") if k % 2 == 0 else Color("e05a3a"))

## 2층 몸체: 가운데 창호 벽(띠살 분합문). 전면(화면 앞쪽 가장 정면 면)에 西將臺 금빛 편액을 처마 바로 아래 벽에 붙인다
func _sj_core(pav: Vector2, AX: Vector2, AY: Vector2, half: float, h0: float, h1: float) -> void:
	var S := Vector2(1, 0)
	var F := Vector2(0, 1)
	var faces := _bh_prism(_bh_rect(pav, AX, AY, S, F, -half, half, -half, half), h0, h1, Color("e3d6b8"), Color(0, 0, 0, 0))
	var best: Array = []
	for fc: Array in faces:
		var a: Vector2 = fc[0]
		var b: Vector2 = fc[1]
		var n := maxi(3, int((b - a).length() / 2.6))
		for k in range(1, n):
			var p := a.lerp(b, float(k) / float(n))
			draw_line(p - Vector2(0, h0 + 1.5), p - Vector2(0, h1 - 5.5), BH_WOOD.lightened(0.15), 0.5) # 띠살
		for hh: float in [h0 + 1.0, lerpf(h0, h1, 0.3), lerpf(h0, h1, 0.6), h1 - 5.0]:
			draw_line(a - Vector2(0, hh), b - Vector2(0, hh), BH_WOOD, 0.9)
		var doors := maxi(2, int((b - a).length() / 9.0))
		for k in range(doors + 1):
			var p2 := a.lerp(b, float(k) / float(doors))
			draw_line(p2 - Vector2(0, h0), p2 - Vector2(0, h1 - 5.0), BH_WOOD.darkened(0.2), 1.3)
		MarketArt.draw_safe_quad(self, a - Vector2(0, h1 - 5.0), b - Vector2(0, h1 - 5.0), b - Vector2(0, h1), a - Vector2(0, h1), Color("5a4630")) # 상인방
		if best.is_empty() or (fc[2] as Vector2).y > (best[2] as Vector2).y:
			best = fc
	if not best.is_empty():
		var pc := ((best[0] as Vector2) + (best[1] as Vector2)) * 0.5 - Vector2(0, h1 - 2.5)
		draw_rect(Rect2(pc + Vector2(-11, -3.5), Vector2(22, 7)), Color("1a1410"))
		draw_rect(Rect2(pc + Vector2(-11, -3.5), Vector2(22, 7)), Color("d4af37"), false, 0.8)
		draw_string(ThemeDB.fallback_font, pc + Vector2(-9.5, 1.8), "西將臺", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color("f4d27a"))

## 횃불 걸이대: 쇠 장대 + 불 담는 광주리 + 불꽃
func _sj_torch(p: Vector2) -> void:
	draw_line(p, p - Vector2(0, 15.0), Color("3a3a3e"), 1.8)
	draw_line(p + Vector2(-2, 0), p + Vector2(2, 0), Color("3a3a3e"), 1.6)
	FastDraw.poly(self, PackedVector2Array([p + Vector2(-3.5, -15.0), p + Vector2(3.5, -15.0), p + Vector2(2.5, -11.5), p + Vector2(-2.5, -11.5)]), Color("4a4a50"))
	FastDraw.poly(self, PackedVector2Array([p + Vector2(-2.6, -15.0), p + Vector2(2.6, -15.0), p + Vector2(0, -22.0)]), Color(1.0, 0.45, 0.08, 0.95))
	FastDraw.poly(self, PackedVector2Array([p + Vector2(-1.4, -15.0), p + Vector2(1.4, -15.0), p + Vector2(0, -19.5)]), Color(1.0, 0.85, 0.3, 0.95))

## 서노대: 전돌 팔각 3단 + 꼭대기 쇠뇌
func _draw_seonodae(c: Vector2, AX: Vector2, AY: Vector2) -> void:
	var snow: bool = (band_master.current_season if band_master else current_season) == "겨울"
	for tier in range(3):
		var r := 0.36 - 0.08 * float(tier)
		var h0 := 5.0 * float(tier)
		var top := PackedVector2Array()
		var bot := PackedVector2Array()
		for i in range(8):
			var ang := TAU * (float(i) + 0.5) / 8.0
			var p := c + AX * cos(ang) * r + AY * sin(ang) * r
			bot.append(p - Vector2(0, h0))
			top.append(p - Vector2(0, h0 + 5.0))
		for i in range(8):
			var j := (i + 1) % 8
			if (bot[i].y + bot[j].y) * 0.5 >= (c.y - h0):
				MarketArt.draw_safe_quad(self, bot[i], bot[j], top[j], top[i], Color("8a847b") if i % 2 == 0 else Color("4e4a46"))
		var top_col: Color = Color("dbe3eb") if snow else Color("948872")
		FastDraw.poly(self, top, top_col)
		if snow:
			for i in range(8):
				var j := (i + 1) % 8
				if (top[i].y + top[j].y) * 0.5 >= (c.y - (h0 + 5.0)):
					draw_line(top[i], top[j], Color("f8fafc"), 1.2)
	var tp := c - Vector2(0, 15)
	draw_line(tp + Vector2(-5, 0), tp + Vector2(5, -2), Color("6e4a2c"), 1.6) # 쇠뇌 몸
	FastDraw.arc(self, tp + Vector2(3, -1), 4.0, -PI * 0.5 - 0.9, -PI * 0.5 + 0.9, 6, Color("3a2416"), 1.0)
	if snow:
		draw_line(tp + Vector2(-5, -1), tp + Vector2(5, -3), Color("f8fafc"), 1.0)

## PORT-TRACE [영화정 2x2]: 고증 — 만석거 북안의 유려한 관청형 누각(정면 3칸, 측면 2칸).
## 2단 화강암 장대석 높은 기단, 정면 돌계단, 붉은 목조 기둥(홍주), 계자난간, 격자 띠살 창호문,
## 청록 비취 단청, 하늘로 날렵하게 치켜올라간 팔작지붕 곡선 처마, '迎華亭' 금빛 현판.
## 2x2 부지 전체를 화강암 박석 마당, 뒤뜰 기와 꽃담, 봄 만개한 벚꽃나무 군락으로 조성.
func _draw_yeonghwajeong_part(rel: Vector2i, anchor: Vector2i, c: Vector2, p_n: Vector2, p_e: Vector2, p_w: Vector2) -> void:
	# ─────────────────────────────────────────────────────────────
	# 1. rel == (0, 0): 뒤뜰 북서쪽 정원 (사계절 잔디/설경 + 디딤돌 + 기와 꽃담 + 사계절 수목)
	# ─────────────────────────────────────────────────────────────
	if rel == Vector2i(0, 0):
		var lawn_col := Color("f1f5f9") if current_season == "겨울" else Color("74984c")
		FastDraw.poly(self, _diamond(c, 0.98), lawn_col)
		# 북서쪽 기와 꽃담 라인 (p_w ~ p_n)
		draw_line(p_w, p_n, Color("6e5a48"), 4.0)
		var wall_top_col := Color("f8fafc") if current_season == "겨울" else Color("2e333a")
		draw_line(p_w - Vector2(0, 3), p_n - Vector2(0, 3), wall_top_col, 2.2) # 기와 덮개 또는 눈
		# 화강암 디딤돌
		for off: Vector2 in [Vector2(-5.0, 2.0), Vector2(3.0, -3.0), Vector2(7.0, 5.0)]:
			FastDraw.poly(self, _diamond(c + off, 0.22), Color("cfcac0"))

		# 뒤뜰 사계절 수목 (봄 벚꽃, 여름 녹음, 가을 단풍, 겨울 설목)
		var tree_p := c + Vector2(-4.0, -6.0)
		match current_season:
			"봄":
				_draw_cherry_blossom_tree(tree_p, current_season, 1.25, anchor.x * 11 + 3)
				# 봄: 마당 개나리 화단 및 벚꽃잎 융단
				for i: int in range(5):
					FastDraw.circle(self, c + Vector2(-6.0 + float(i * 3), 4.0 + float(i % 3)), 1.1, Color(0.98, 0.74, 0.82, 0.85))
				FastDraw.circle(self, c + Vector2(2.0, 6.0), 1.5, Color("facc15")) # 개나리
				FastDraw.circle(self, c + Vector2(5.0, 5.0), 1.5, Color("f43f5e")) # 철쭉
			"여름":
				_draw_tree_zelkova(tree_p, current_season)
			"가을":
				_draw_tree_seasonal(tree_p, current_season, false) # 붉은 단풍나무
				# 마당 감나무 소품
				draw_line(c + Vector2(6.0, 2.0), c + Vector2(6.0, -4.0), Color("451a03"), 1.4)
				FastDraw.circle(self, c + Vector2(6.0, -6.0), 3.0, Color("a16207"))
				FastDraw.circle(self, c + Vector2(5.0, -6.0), 1.2, Color("ea580c")) # 주황색 감
				FastDraw.circle(self, c + Vector2(7.5, -5.0), 1.2, Color("ea580c"))
			"겨울":
				_draw_cherry_blossom_tree(tree_p, current_season, 1.25, anchor.x * 11 + 3)
				FastDraw.circle(self, tree_p - Vector2(0.0, 16.0), 3.5, Color("f8fafc", 0.9)) # 소복한 솜눈
		return

	# ─────────────────────────────────────────────────────────────
	# 2. rel == (1, 0): 뒤뜰 북동쪽 정원 (사계절 잔디/설경 + 박석 통로 + 측면 담장/협문)
	# ─────────────────────────────────────────────────────────────
	if rel == Vector2i(1, 0):
		var lawn_col2 := Color("f1f5f9") if current_season == "겨울" else Color("74984c")
		FastDraw.poly(self, _diamond(c, 0.98), lawn_col2)
		# 북동쪽 기와 담장 라인 (p_n ~ p_e)
		draw_line(p_n, p_e, Color("6e5a48"), 4.0)
		var wall_top_col2 := Color("f8fafc") if current_season == "겨울" else Color("2e333a")
		draw_line(p_n - Vector2(0, 3), p_e - Vector2(0, 3), wall_top_col2, 2.2)
		# 아담한 목조 협문 (일각문)
		var gate_p: Vector2 = p_n.lerp(p_e, 0.35)
		draw_line(gate_p, gate_p - Vector2(0, 9), Color("8a2e22"), 2.0)
		draw_line(gate_p + Vector2(5, 2), gate_p + Vector2(5, -7), Color("8a2e22"), 2.0)
		draw_line(gate_p - Vector2(2, 9), gate_p + Vector2(7, -7), Color("2b323c"), 2.4)
		if current_season == "겨울":
			draw_line(gate_p - Vector2(2, 10), gate_p + Vector2(7, -8), Color("f8fafc"), 1.8) # 문 지붕 눈
		# 박석 통로
		for off: Vector2 in [Vector2(-4.0, 3.0), Vector2(1.0, 5.0), Vector2(6.0, 7.0)]:
			FastDraw.poly(self, _diamond(c + off, 0.20), Color("cfcac0"))
		# 측면 정원 수목
		var side_tree_p := c + Vector2(6.0, -7.0)
		if current_season == "가을":
			_draw_tree_seasonal(side_tree_p, current_season, false)
		else:
			_draw_cherry_blossom_tree(side_tree_p, current_season, 1.15, anchor.y * 13 + 7)
		if current_season == "봄":
			for i: int in range(5):
				FastDraw.circle(self, c + Vector2(-4.0 + float(i * 3), 2.0 + float((i * 2) % 4)), 1.1, Color(0.98, 0.74, 0.82, 0.85))
		return

	# ─────────────────────────────────────────────────────────────
	# 3. rel == (0, 1): 앞마당 남서쪽 (화강암 박석 마당 + 전통 석등 + 사계절 조경)
	# ─────────────────────────────────────────────────────────────
	if rel == Vector2i(0, 1):
		var yard_col := Color("f1f5f9") if current_season == "겨울" else Color("cfcac0")
		FastDraw.poly(self, _diamond(c, 0.98), yard_col)
		FastDraw.polyline(self, PackedVector2Array(_diamond(c, 0.94)) + PackedVector2Array([_diamond(c, 0.94)[0]]), Color("b5afa5"), 1.0)
		# 박석 줄눈
		draw_line(p_w.lerp(p_n, 0.5), p_w.lerp(c, 0.5), Color("b5afa5"), 0.8)
		# 전통 화강암 석등
		var lt_p: Vector2 = c + Vector2(-6.0, 0.0)
		draw_rect(Rect2(lt_p + Vector2(-4.5, 3.0), Vector2(9.0, 3.0)), Color("9a9488")) # 하대석
		draw_rect(Rect2(lt_p + Vector2(-1.5, -3.0), Vector2(3.0, 6.0)), Color("beb8ac")) # 간주석
		draw_rect(Rect2(lt_p + Vector2(-3.5, -8.0), Vector2(7.0, 5.0)), Color("5a544c")) # 화사석
		FastDraw.circle(self, lt_p + Vector2(0.0, -5.5), 1.2, Color(1.0, 0.85, 0.35, 0.9)) # 화창 불빛
		FastDraw.poly(self, PackedVector2Array([
			lt_p + Vector2(-6.0, -8.0), lt_p + Vector2(6.0, -8.0),
			lt_p + Vector2(3.5, -12.0), lt_p + Vector2(-3.5, -12.0)
		]), Color("8a847a")) # 옥개석(지붕돌)
		FastDraw.circle(self, lt_p + Vector2(0.0, -13.0), 1.2, Color("beb8ac")) # 보주

		# 사계절 앞마당 연출
		match current_season:
			"봄":
				# 석등 주변 만개한 개나리와 진분홍 철쭉 화단
				FastDraw.circle(self, lt_p + Vector2(7.0, 2.0), 1.6, Color("facc15")) # 개나리
				FastDraw.circle(self, lt_p + Vector2(10.0, 1.0), 1.5, Color("f43f5e")) # 철쭉
				FastDraw.circle(self, lt_p + Vector2(8.5, 4.0), 1.4, Color("facc15"))
				for i: int in range(7):
					var petal_p: Vector2 = c + Vector2(-8.0 + float(i * 3), -3.0 + float((i * 4) % 9) - 4.0)
					FastDraw.circle(self, petal_p, 1.1, Color(0.98, 0.74, 0.82, 0.85))
			"가을":
				# 붉은 단풍잎과 노란 은행잎 낙엽 융단
				for i: int in range(6):
					var leaf_p: Vector2 = c + Vector2(-9.0 + float(i * 3.5), -2.0 + float((i * 5) % 8) - 3.0)
					var leaf_c: Color = Color("ea580c") if i % 2 == 0 else Color("eab308")
					FastDraw.circle(self, leaf_p, 1.2, leaf_c)
			"겨울":
				# 석등 옥개석에 소복이 쌓인 눈
				FastDraw.poly(self, PackedVector2Array([
					lt_p + Vector2(-6.0, -8.0), lt_p + Vector2(6.0, -8.0),
					lt_p + Vector2(3.5, -13.5), lt_p + Vector2(-3.5, -13.5)
				]), Color("f8fafc", 0.95))
				# 앞마당 아담한 눈사람
				var sm_pos := c + Vector2(7.0, 2.0)
				FastDraw.circle(self, sm_pos, 2.4, Color("f8fafc"))
				FastDraw.circle(self, sm_pos - Vector2(0.0, 3.5), 1.6, Color("ffffff"))
				draw_line(sm_pos - Vector2(0.0, 3.3), sm_pos + Vector2(1.2, -3.3), Color("ea580c"), 0.8)
		return

	# ─────────────────────────────────────────────────────────────
	# 4. rel == (1, 1): 앞마당 남동쪽 & 영화정 본각(메인 누각) 2.5D 아이소메트릭 웅장 렌더링
	# ─────────────────────────────────────────────────────────────
	# 바닥: 화강암 박석 마당
	FastDraw.poly(self, _diamond(c, 0.98), Color("cfcac0"))
	FastDraw.polyline(self, PackedVector2Array(_diamond(c, 0.94)) + PackedVector2Array([_diamond(c, 0.94)[0]]), Color("b5afa5"), 1.0)

	# [영화정 본각 중심 앵커]: 2x2 부지의 중심을 향해 균형 잡힌 앵커 좌표
	var pc: Vector2 = c + Vector2(-14.0, -8.0)

	# 2.5D 아이소메트릭 투영 좌표 변환 람다:
	# u: 남서->북동 축 (-1..1), v: 북서->남동 축 (-1..1), h: 수직 높이 (px)
	var iso_pt := func(u_val: float, v_val: float, h_val: float) -> Vector2:
		return pc + Vector2((u_val - v_val) * 32.0, (u_val + v_val) * 16.0 - h_val)

	# ─────────────────────────────────────────────────────────────
	# A. 화강암 2단 장대석 입체 기단 (Plinth)
	# ─────────────────────────────────────────────────────────────
	# 1단 하부 기단 (u: -0.95..0.95, v: -0.85..0.85, h: 0..5)
	var b1_top: PackedVector2Array = PackedVector2Array([
		iso_pt.call(-0.95, -0.85, 5.0), iso_pt.call(0.95, -0.85, 5.0),
		iso_pt.call(0.95, 0.85, 5.0), iso_pt.call(-0.95, 0.85, 5.0)
	])
	FastDraw.poly(self, b1_top, Color("beb8ac"))
	# 남서쪽 입체 벽면 (v = 0.85, 밝은 햇빛면)
	var b1_sw: PackedVector2Array = PackedVector2Array([
		iso_pt.call(-0.95, 0.85, 5.0), iso_pt.call(0.95, 0.85, 5.0),
		iso_pt.call(0.95, 0.85, 0.0), iso_pt.call(-0.95, 0.85, 0.0)
	])
	FastDraw.poly(self, b1_sw, Color("9e968a"))
	# 남동쪽 입체 벽면 (u = 0.95, 그늘진 음영면)
	var b1_se: PackedVector2Array = PackedVector2Array([
		iso_pt.call(0.95, -0.85, 5.0), iso_pt.call(0.95, 0.85, 5.0),
		iso_pt.call(0.95, 0.85, 0.0), iso_pt.call(0.95, -0.85, 0.0)
	])
	FastDraw.poly(self, b1_se, Color("7a7368"))
	draw_line(iso_pt.call(-0.95, 0.85, 5.0), iso_pt.call(0.95, 0.85, 5.0), Color("dcd6cb"), 1.2)
	draw_line(iso_pt.call(0.95, -0.85, 5.0), iso_pt.call(0.95, 0.85, 5.0), Color("a8a094"), 1.0)

	# 2단 상부 기단 (u: -0.82..0.82, v: -0.72..0.72, h: 5..9)
	var b2_top: PackedVector2Array = PackedVector2Array([
		iso_pt.call(-0.82, -0.72, 9.0), iso_pt.call(0.82, -0.72, 9.0),
		iso_pt.call(0.82, 0.72, 9.0), iso_pt.call(-0.82, 0.72, 9.0)
	])
	FastDraw.poly(self, b2_top, Color("dcd6cb"))
	# 남서쪽 상부 벽면
	var b2_sw: PackedVector2Array = PackedVector2Array([
		iso_pt.call(-0.82, 0.72, 9.0), iso_pt.call(0.82, 0.72, 9.0),
		iso_pt.call(0.82, 0.72, 5.0), iso_pt.call(-0.82, 0.72, 5.0)
	])
	FastDraw.poly(self, b2_sw, Color("a8a094"))
	# 남동쪽 상부 벽면
	var b2_se: PackedVector2Array = PackedVector2Array([
		iso_pt.call(0.82, -0.72, 9.0), iso_pt.call(0.82, 0.72, 9.0),
		iso_pt.call(0.82, 0.72, 5.0), iso_pt.call(0.82, -0.72, 5.0)
	])
	FastDraw.poly(self, b2_se, Color("857d72"))
	draw_line(iso_pt.call(-0.82, 0.72, 9.0), iso_pt.call(0.82, 0.72, 9.0), Color("eeeae0"), 1.2)

	# ─────────────────────────────────────────────────────────────
	# B. 정면 3단 화강암 마름모 돌계단 (남서쪽 v=0.72 중앙 u: -0.22..0.22)
	# ─────────────────────────────────────────────────────────────
	var stair_u0: float = -0.22
	var stair_u1: float = 0.22
	for st_idx: int in range(3):
		var st_v0: float = 0.72 + float(st_idx) * 0.08
		var st_v1: float = st_v0 + 0.08
		var st_h: float = 9.0 - float(st_idx + 1) * 2.8
		# 계단 상판 디딤면
		var st_poly: PackedVector2Array = PackedVector2Array([
			iso_pt.call(stair_u0, st_v0, st_h), iso_pt.call(stair_u1, st_v0, st_h),
			iso_pt.call(stair_u1, st_v1, st_h), iso_pt.call(stair_u0, st_v1, st_h)
		])
		FastDraw.poly(self, st_poly, Color("dcd6cb"))
		# 계단 챌면 (수직면)
		var st_face: PackedVector2Array = PackedVector2Array([
			iso_pt.call(stair_u0, st_v1, st_h), iso_pt.call(stair_u1, st_v1, st_h),
			iso_pt.call(stair_u1, st_v1, maxf(0.0, st_h - 2.8)), iso_pt.call(stair_u0, st_v1, maxf(0.0, st_h - 2.8))
		])
		FastDraw.poly(self, st_face, Color("9e968a"))
		draw_line(iso_pt.call(stair_u0, st_v1, st_h), iso_pt.call(stair_u1, st_v1, st_h), Color("eeeae0"), 1.0)

	# ─────────────────────────────────────────────────────────────
	# C. 우물마루 목재 대청 바닥 (h = 9.5)
	# ─────────────────────────────────────────────────────────────
	var floor_pts: PackedVector2Array = PackedVector2Array([
		iso_pt.call(-0.76, -0.66, 9.5), iso_pt.call(0.76, -0.66, 9.5),
		iso_pt.call(0.76, 0.66, 9.5), iso_pt.call(-0.76, 0.66, 9.5)
	])
	FastDraw.poly(self, floor_pts, Color("c08848"))
	# 우물마루 청판 줄눈
	for k: int in range(1, 6):
		var ku: float = -0.76 + float(k) * 0.25
		draw_line(iso_pt.call(ku, -0.66, 9.5), iso_pt.call(ku, 0.66, 9.5), Color("8e5c26"), 0.8)
	for m: int in range(1, 5):
		var mv: float = -0.66 + float(m) * 0.26
		draw_line(iso_pt.call(-0.76, mv, 9.5), iso_pt.call(0.76, mv, 9.5), Color("8e5c26"), 0.8)

	# ─────────────────────────────────────────────────────────────
	# D. 붉은 원형 목조 기둥 8개 (홍주 8본) 및 초석
	# ─────────────────────────────────────────────────────────────
	var col_u_list: Array[float] = [-0.64, -0.22, 0.22, 0.64]
	var pillar_h: float = 24.0 # 기둥 순수 높이
	var p_base_h: float = 9.5
	var p_top_h: float = p_base_h + pillar_h

	# 후면 기둥 4개 (v = -0.58)
	for cu_val: float in col_u_list:
		var bp_rear: Vector2 = iso_pt.call(cu_val, -0.58, p_base_h)
		var tp_rear: Vector2 = iso_pt.call(cu_val, -0.58, p_top_h)
		draw_circle(bp_rear, 1.6, Color("7a7368")) # 초석
		draw_line(bp_rear, tp_rear, Color("5c140e"), 2.2) # 음영 기둥

	# 내부 대청과 창호문 (후면과 전면 사이)
	# 좌측 협칸 창호문 (u: -0.64..-0.22, v: 0.0)
	var win1_p0: Vector2 = iso_pt.call(-0.62, 0.0, p_base_h + 1.0)
	var win1_p1: Vector2 = iso_pt.call(-0.24, 0.0, p_base_h + 1.0)
	var win1_p2: Vector2 = iso_pt.call(-0.24, 0.0, p_top_h - 3.0)
	var win1_p3: Vector2 = iso_pt.call(-0.62, 0.0, p_top_h - 3.0)
	FastDraw.poly(self, PackedVector2Array([win1_p0, win1_p1, win1_p2, win1_p3]), Color("fbf8f0")) # 창호지
	draw_line(win1_p0, win1_p1, Color("6a4325"), 1.2)
	draw_line(win1_p1, win1_p2, Color("6a4325"), 1.2)
	draw_line(win1_p2, win1_p3, Color("6a4325"), 1.2)
	draw_line(win1_p3, win1_p0, Color("6a4325"), 1.2)
	# 창호 띠살
	for lx: int in range(1, 4):
		var frac_x: float = float(lx) * 0.25
		draw_line(win1_p0.lerp(win1_p1, frac_x), win1_p3.lerp(win1_p2, frac_x), Color("8e5c26"), 0.6)

	# 우측 협칸 창호문 (u: 0.22..0.64, v: 0.0)
	var win2_p0: Vector2 = iso_pt.call(0.24, 0.0, p_base_h + 1.0)
	var win2_p1: Vector2 = iso_pt.call(0.62, 0.0, p_base_h + 1.0)
	var win2_p2: Vector2 = iso_pt.call(0.62, 0.0, p_top_h - 3.0)
	var win2_p3: Vector2 = iso_pt.call(0.24, 0.0, p_top_h - 3.0)
	FastDraw.poly(self, PackedVector2Array([win2_p0, win2_p1, win2_p2, win2_p3]), Color("fbf8f0"))
	draw_line(win2_p0, win2_p1, Color("6a4325"), 1.2)
	draw_line(win2_p1, win2_p2, Color("6a4325"), 1.2)
	draw_line(win2_p2, win2_p3, Color("6a4325"), 1.2)
	draw_line(win2_p3, win2_p0, Color("6a4325"), 1.2)
	for lx2: int in range(1, 4):
		var frac_x2: float = float(lx2) * 0.25
		draw_line(win2_p0.lerp(win2_p1, frac_x2), win2_p3.lerp(win2_p2, frac_x2), Color("8e5c26"), 0.6)

	# 중앙 어칸 대청 안쪽 들보 및 음영 (u: -0.22..0.22)
	var okan_poly: PackedVector2Array = PackedVector2Array([
		iso_pt.call(-0.22, -0.45, p_base_h + 0.5), iso_pt.call(0.22, -0.45, p_base_h + 0.5),
		iso_pt.call(0.22, -0.45, p_top_h - 3.0), iso_pt.call(-0.22, -0.45, p_top_h - 3.0)
	])
	FastDraw.poly(self, okan_poly, Color(0.20, 0.14, 0.10, 0.85)) # 깊은 어칸 음영

	# 전면 기둥 4개 (v = 0.58)
	for cu_val2: float in col_u_list:
		var bp_front: Vector2 = iso_pt.call(cu_val2, 0.58, p_base_h)
		var tp_front: Vector2 = iso_pt.call(cu_val2, 0.58, p_top_h)
		draw_circle(bp_front, 1.8, Color("94a3b8")) # 화강암 초석
		# 주칠 원통형 기둥 (몸체 + 하이라이트 + 음영)
		draw_line(bp_front, tp_front, Color("94261e"), 2.8)
		draw_line(bp_front - Vector2(0.8, 0.0), tp_front - Vector2(0.8, 0.0), Color("bc3c30"), 0.9)
		draw_line(bp_front + Vector2(0.8, 0.0), tp_front + Vector2(0.8, 0.0), Color("5c140e"), 0.8)

	# ─────────────────────────────────────────────────────────────
	# E. 궁궐/관청형 계자난간 (鷄子欄干)
	# ─────────────────────────────────────────────────────────────
	var rail_h: float = p_base_h + 4.5
	# 좌측 협칸 난간 (u: -0.72..-0.22, v = 0.64)
	draw_line(iso_pt.call(-0.72, 0.64, rail_h), iso_pt.call(-0.22, 0.64, rail_h), Color("991b1b"), 1.8)
	draw_line(iso_pt.call(-0.72, 0.64, rail_h - 2.5), iso_pt.call(-0.22, 0.64, rail_h - 2.5), Color("7f1d1d"), 1.2)
	for rxi: int in range(4):
		var ru: float = -0.72 + float(rxi) * 0.16
		draw_line(iso_pt.call(ru, 0.64, rail_h), iso_pt.call(ru, 0.64, rail_h - 3.0), Color("8f261e"), 1.1)

	# 우측 협칸 난간 (u: 0.22..0.72, v = 0.64)
	draw_line(iso_pt.call(0.22, 0.64, rail_h), iso_pt.call(0.72, 0.64, rail_h), Color("991b1b"), 1.8)
	draw_line(iso_pt.call(0.22, 0.64, rail_h - 2.5), iso_pt.call(0.72, 0.64, rail_h - 2.5), Color("7f1d1d"), 1.2)
	for rxi2: int in range(4):
		var ru2: float = 0.22 + float(rxi2) * 0.16
		draw_line(iso_pt.call(ru2, 0.64, rail_h), iso_pt.call(ru2, 0.64, rail_h - 3.0), Color("8f261e"), 1.1)

	# ─────────────────────────────────────────────────────────────
	# F. 창방·평방 다포 공포 및 화려한 청록/주홍 단청 (Dancheong)
	# ─────────────────────────────────────────────────────────────
	var dancheong_p0: Vector2 = iso_pt.call(-0.74, 0.58, p_top_h)
	var dancheong_p1: Vector2 = iso_pt.call(0.74, 0.58, p_top_h)
	draw_line(dancheong_p0, dancheong_p1, Color("1b7570"), 2.8) # 창방 청록 띠
	draw_line(dancheong_p0 - Vector2(0.0, 1.2), dancheong_p1 - Vector2(0.0, 1.2), Color("2dd4bf"), 1.0) # 하이라이트
	# 주홍색 머리초 포인트
	for cu_val3: float in col_u_list:
		var mp: Vector2 = iso_pt.call(cu_val3, 0.58, p_top_h)
		FastDraw.circle(self, mp, 1.5, Color("dc2626"))
		FastDraw.circle(self, mp - Vector2(0.0, 1.5), 1.0, Color("facc15")) # 소로 공포

	# ─────────────────────────────────────────────────────────────
	# G. 날렵하게 치켜올라간 2.5D 아이소메트릭 팔작지붕 (Paljak Roof)
	# ─────────────────────────────────────────────────────────────
	var eaves_h: float = p_top_h + 1.5
	var ridge_h: float = eaves_h + 16.0

	# 팔작지붕 용마루 (u: -0.65..0.65, v: 0.0, h: ridge_h)
	var ridge_l: Vector2 = iso_pt.call(-0.65, 0.0, ridge_h)
	var ridge_r: Vector2 = iso_pt.call(0.65, 0.0, ridge_h)

	# 전면(남서) 처마선 (u: -1.05..1.05, v: 0.95)
	# 버선코 처마 앙곡 반영: 양 끝은 위로 4px 솟구침
	var e_sw_l: Vector2 = iso_pt.call(-1.05, 0.95, eaves_h) - Vector2(0.0, 4.0)
	var e_sw_ml: Vector2 = iso_pt.call(-0.50, 0.95, eaves_h)
	var e_sw_c: Vector2 = iso_pt.call(0.0, 0.95, eaves_h + 0.5)
	var e_sw_mr: Vector2 = iso_pt.call(0.50, 0.95, eaves_h)
	var e_sw_r: Vector2 = iso_pt.call(1.05, 0.95, eaves_h) - Vector2(0.0, 4.0)

	# 전면 기와지붕 폴리곤 (남서 경사면)
	var roof_front_poly: PackedVector2Array = PackedVector2Array([
		ridge_l, ridge_r, e_sw_r, e_sw_mr, e_sw_c, e_sw_ml, e_sw_l
	])
	var is_winter: bool = (band_master.current_season if band_master else current_season) == "겨울"
	var roof_f_col: Color = Color("dbe4eb") if is_winter else Color("252d38")
	FastDraw.poly(self, roof_front_poly, roof_f_col) # 짙은 먹빛 암키와 또는 눈

	# 수키와 골 줄눈 (용마루에서 처마로 흐르는 기와골)
	for rki: int in range(9):
		var frac_rk: float = float(rki) / 8.0
		var r_top_pt: Vector2 = ridge_l.lerp(ridge_r, frac_rk)
		var r_bot_pt: Vector2
		if frac_rk <= 0.5:
			r_bot_pt = e_sw_l.lerp(e_sw_c, frac_rk * 2.0)
		else:
			r_bot_pt = e_sw_c.lerp(e_sw_r, (frac_rk - 0.5) * 2.0)
		draw_line(r_top_pt, r_bot_pt, Color("cbd5dc") if is_winter else Color("3d4653"), 1.0)

	# 측면(남동) 팔작 합각벽 및 박공 경사면
	# 우측 뒷처마 끝
	var e_se_rear: Vector2 = iso_pt.call(1.05, -0.95, eaves_h) - Vector2(0.0, 3.5)
	var roof_side_poly: PackedVector2Array = PackedVector2Array([
		ridge_r, e_se_rear, e_sw_r
	])
	var roof_s_col: Color = Color("cbd5dc") if is_winter else Color("1a202c")
	FastDraw.poly(self, roof_side_poly, roof_s_col) # 음영 지붕면 또는 눈

	# 팔작지붕 특유의 삼각형 합각벽 (Gable Wall: 백색 회벽 + 목조 살대)
	var gable_center: Vector2 = ridge_r.lerp(e_se_rear.lerp(e_sw_r, 0.5), 0.45)
	var gable_poly: PackedVector2Array = PackedVector2Array([
		ridge_r + Vector2(0.0, 2.0),
		gable_center + Vector2(7.0, 5.0),
		gable_center + Vector2(-5.0, 6.0)
	])
	FastDraw.poly(self, gable_poly, Color("f1f5f9")) # 백색 회벽
	draw_line(ridge_r + Vector2(0.0, 2.0), gable_center + Vector2(1.0, 5.5), Color("5c3a21"), 1.0) # 목조 중인방

	# 처마 끝 청록 부연 및 백색 막새기와 하이라이트
	draw_line(e_sw_l, e_sw_c, Color("1b7570"), 1.4)
	draw_line(e_sw_c, e_sw_r, Color("1b7570"), 1.4)
	draw_line(e_sw_l + Vector2(0.0, 0.8), e_sw_r + Vector2(0.0, 0.8), Color("475569"), 1.1)

	# 백회 양성바름 용마루 및 용머리 취두 (鷲頭)
	draw_line(ridge_l, ridge_r, Color("f8fafc"), 2.4)
	FastDraw.circle(self, ridge_l - Vector2(0.0, 1.8), 2.0, Color("0f172a")) # 좌측 취두
	FastDraw.circle(self, ridge_r - Vector2(0.0, 1.8), 2.0, Color("0f172a")) # 우측 취두

	# ─────────────────────────────────────────────────────────────
	# H. '迎華亭' 금빛 입체 편액 (Plaque)
	# ─────────────────────────────────────────────────────────────
	# 정면 어칸 처마 바로 아래 중심부 (u=0.0, v=0.62, h=p_top_h-2.0)
	var plaque_p: Vector2 = iso_pt.call(0.0, 0.62, p_top_h - 1.5)
	draw_rect(Rect2(plaque_p + Vector2(-12.0, -4.0), Vector2(24.0, 8.0)), Color("111827")) # 흑칠 바탕
	draw_rect(Rect2(plaque_p + Vector2(-12.0, -4.0), Vector2(24.0, 8.0)), Color("eab308"), false, 1.0) # 금빛 테두리
	draw_string(ThemeDB.fallback_font, plaque_p + Vector2(-10.5, 2.2), "迎華亭", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("fde047"))

	# ─────────────────────────────────────────────────────────────
	# I. 사계절 지붕 디테일 (겨울 눈 덮인 지붕·처마선, 봄 벚꽃비, 가을 단풍잎)
	# ─────────────────────────────────────────────────────────────
	var s_now: String = band_master.current_season if band_master else current_season
	match s_now:
		"겨울":
			# 2.5D 버선코 처마선 앙곡을 따르는 소복한 설경 라인
			FastDraw.polyline(self, PackedVector2Array([e_sw_l, e_sw_ml, e_sw_c, e_sw_mr, e_sw_r]), Color("f8fafc", 0.96), 2.4)
			draw_line(e_sw_l, ridge_l, Color("f8fafc"), 1.8)
			draw_line(e_sw_r, ridge_r, Color("f8fafc"), 1.8)
			draw_line(e_se_rear, ridge_r, Color("f8fafc"), 1.8)
		"봄":
			for bi: int in range(9):
				var frac_b: float = float(bi) / 8.0
				var b_pos: Vector2 = e_sw_l.lerp(e_sw_r, frac_b) + Vector2(float((bi * 5) % 9) - 4.0, float((bi * 3) % 7) + 2.0)
				FastDraw.circle(self, b_pos, 1.2, Color(1.0, 0.74, 0.83, 0.92))
		"가을":
			for gi: int in range(8):
				var frac_g: float = float(gi) / 7.0
				var g_pos: Vector2 = e_sw_l.lerp(e_sw_r, frac_g) + Vector2(float((gi * 4) % 8) - 3.5, float((gi * 3) % 6) + 1.5)
				var leaf_c: Color = Color("ea580c") if gi % 2 == 0 else Color("eab308")
				FastDraw.circle(self, g_pos, 1.2, leaf_c)

## 영화정이 바라볼 앞 방향(가장 가까운 만석거 칸 쪽, 4방향)
func yeonghwajeong_front(anchor: Vector2i) -> Vector2i:
	var cen := Vector2(anchor) + Vector2(1.0, 1.0)
	var best := Vector2.ZERO
	var bd := 1e9
	for dy in range(-6, 8):
		for dx in range(-6, 8):
			var q := anchor + Vector2i(dx, dy)
			if str(grid.building_at(q.x, q.y)).begins_with("manseokgeo"):
				var v := Vector2(q) + Vector2(0.5, 0.5) - cen
				if v.length() < bd:
					bd = v.length()
					best = v
	if best == Vector2.ZERO:
		return Vector2i(0, 1)
	if absf(best.x) >= absf(best.y):
		return Vector2i(1 if best.x > 0 else -1, 0)
	return Vector2i(0, 1 if best.y > 0 else -1)

# ─────────────────────────────────────────────── 3단계: 공심돈 3종(3x3) · 연무대(5x5)
## 공심돈 로컬 좌표: u = 성벽을 따라, v = 성벽 줄에서 바깥쪽으로(칸 단위), 가운데 칸 중심이 (0,0)
func gs_pt(info: Dictionary, u: float, v: float, h: float = 0.0) -> Vector2:
	var cpos: Vector2i = info["center"]
	var g := Vector2(cpos) + Vector2(0.5, 0.5) + Vector2(info["axis"] as Vector2i) * u + Vector2(info["out"] as Vector2i) * v
	if info.has("c2"):
		# PORT-TRACE [공심돈 2x2]: 성벽 두 칸 사이 + 바깥으로 반 칸쯤이 몸통 가운데
		g += Vector2(info["axis"] as Vector2i) * 0.5 * float(info["c2"]) + Vector2(info["out"] as Vector2i) * 0.25
	if not info.has("elevation"):
		var el: float = float(grid.tile(cpos.x, cpos.y).get("elevation", 1.0)) if grid and grid.in_bounds(cpos.x, cpos.y) else 1.0
		info["elevation"] = el
	var elev: float = float(info["elevation"])
	return cell_center(g.x, g.y, elev) - Vector2(0, h)

## 직사각 몸체(아래 화강암 + 위 전돌): u0~u1, v0~v1, 화강암 0~hg, 전돌 hg~ht
func _gs_box(info: Dictionary, u0: float, u1: float, v0: float, v1: float, hg: float, ht: float, brick: Color) -> Array[Vector2]:
	var um := (u0 + u1) * 0.5
	var vm := (v0 + v1) * 0.5
	var cb := gs_pt(info, um, vm)
	var A := gs_pt(info, um + 1.0, vm) - cb
	var F := gs_pt(info, um, vm + 1.0) - cb
	var bu := (u1 - u0) * 0.5
	var bv := (v1 - v0) * 0.5
	_ft_tex_box(cb, A, F, bu, bv, 0.0, hg, false)
	_ft_tex_box(cb, A, F, bu, bv, hg, ht, true)
	var g: Array[Vector2] = [cb - A * bu - F * bv, cb + A * bu - F * bv, cb + A * bu + F * bv, cb - A * bu + F * bv]
	for i in range(4):
		var q0: Vector2 = g[i]
		var q1: Vector2 = g[(i + 1) % 4]
		if (q0.y + q1.y) * 0.5 < cb.y:
			continue
		for hh in range(int(hg) + 4, int(ht), 4):
			draw_line(q0 - Vector2(0, hh), q1 - Vector2(0, hh), brick.darkened(0.25), 0.6)
	MarketArt.draw_safe_quad(self, g[0] - Vector2(0, ht), g[1] - Vector2(0, ht), g[2] - Vector2(0, ht), g[3] - Vector2(0, ht), brick.lightened(0.15))
	return g

## 바깥 면 총안·포안(줄지어 어두운 네모) + 붉은 판문
func _gs_face_details(info: Dictionary, u0: float, u1: float, v_face: float, rows: Array, doors: bool) -> void:
	for hh: float in rows:
		for k in range(5):
			var m := gs_pt(info, lerpf(u0, u1, (float(k) + 0.5) / 5.0), v_face, hh)
			draw_rect(Rect2(m + Vector2(-1.3, -1.6), Vector2(2.6, 3.2)), Color("141210"))
	if doors:
		for uu: float in [lerpf(u0, u1, 0.3), lerpf(u0, u1, 0.7)]:
			var dp := gs_pt(info, uu, v_face, 4.0)
			FastDraw.poly(self, PackedVector2Array([dp + Vector2(-3, 0), dp + Vector2(3, 0), dp + Vector2(3, -7), dp + Vector2(0, -9), dp + Vector2(-3, -7)]), Color("a8322a"))

## PORT-TRACE [공심돈 둥근 벽 재설계]: 사용자 요청 — 세 공심돈 모두 벽이 둥글고 위에 처마지붕을 얹은 모양(《화성성역의궤》 동북공심돈 외도·내도, 실물 사진).
## 아래는 화강석 밑동, 그 위로 벽돌을 층층이 쌓은 둥근 몸통(중간에 튀어나온 돌림띠), 몸통 바깥에는 작은 총안 줄과 대포를 내미는 포구(공격·감시),
## 아래쪽에 홍예 출입문. 꼭대기는 붉은 기둥 위로 넓은 팔각 처마지붕을 얹어 순찰 마루 전체를 덮는다 — 병졸은 처마 아래 여장 뒤로 가려져 다닌다.
## 종류별: 동북(소라각)은 가장 크고 높고, 서북은 중간, 남은 낮고 작다.
const GS_VC := 0.2

func gongsimdon_top_h(info: Dictionary) -> float:
	var k := 0.9 if info.has("c2") else 1.0
	match str(info["type"]):
		"dongbuk": return 46.0 * k
		"seobuk": return 40.0 * k
	return 34.0 * k

func gongsimdon_radius(info: Dictionary) -> float:
	var k := 0.68 if info.has("c2") else 1.0 # 2x2: 4대문보다 작게
	match str(info["type"]):
		"dongbuk": return 1.32 * k
		"seobuk": return 1.2 * k
	return 1.08 * k

## 포구(대포를 내미는 구멍) 화면 위치와 바깥 방향(화면에서 보이는 앞쪽 것만) — 포격 연출 위치
func gongsimdon_ports(info: Dictionary) -> Array:
	var out: Array = []
	var r := gongsimdon_radius(info)
	var H := gongsimdon_top_h(info)
	var cen := gs_pt(info, 0.0, GS_VC)
	var n := 28
	for i in range(1, n, 4):
		var ang := TAU * (float(i) + 0.5) / float(n)
		var base := gs_pt(info, cos(ang) * (r + 0.02), GS_VC + sin(ang) * (r + 0.02))
		if base.y < cen.y + 2.0:
			continue
		out.append({"p": base - Vector2(0, H * 0.42), "d": (base - cen).normalized()})
	return out

func _draw_gongsimdon3(info: Dictionary) -> void:
	var typ := str(info["type"])
	var r := gongsimdon_radius(info)
	var H := gongsimdon_top_h(info)
	var brick := Color("857f76") if typ == "dongbuk" else (Color("7a746c") if typ == "seobuk" else Color("827c73"))
	var snow := current_season == "겨울"
	var n := 28
	var ring := PackedVector2Array()
	for i in range(n):
		var a0 := TAU * float(i) / float(n)
		ring.append(gs_pt(info, cos(a0) * r, GS_VC + sin(a0) * r))
	var cen := gs_pt(info, 0.0, GS_VC)
	var foot := WALL_HEIGHT
	var H_total := foot + H - 8.0
	var mold := foot + (H - 8.0) * 0.5
	# 땅에 닿는 그림자
	var sh := PackedVector2Array()
	for q: Vector2 in ring:
		sh.append(cen + (q - cen) * 1.12 + Vector2(6, 4))
	FastDraw.poly(self, sh, Color(0, 0, 0, 0.22))
	# 땅에 붙는 돌 마당: 밑동 둘레에 넓은 박석 띠를 깔아 풀밭 위에 떠 보이지 않게 한다
	var apron := PackedVector2Array()
	for q2: Vector2 in ring:
		apron.append(cen + (q2 - cen) * 1.08) # 밑동 바로 둘레만(성 안 땅까지 덮으면 그 위 사람이 시설 위에 선 듯 보였다)
	FastDraw.poly(self, apron, Color("a89c82") if not snow else Color("c8ccd0"))
	var apron_in := PackedVector2Array()
	for q3: Vector2 in ring:
		apron_in.append(cen + (q3 - cen) * 1.03)
	FastDraw.poly(self, apron_in, Color("bfb39a") if not snow else Color("dfe3e6"))
	# 1. 둥근 몸통: 앞쪽 면만, 오른쪽이 밝다
	var door_i := 0
	var door_y := -1e9
	for i in range(n):
		var q0: Vector2 = ring[i]
		var q1: Vector2 = ring[(i + 1) % n]
		var my := (q0.y + q1.y) * 0.5
		if my < cen.y:
			continue
		var lit := clampf(0.55 + ((q0.x + q1.x) * 0.5 - cen.x) / (r * 60.0), 0.15, 1.0)
		var stone := Color("c8bda5").darkened(0.25 * (1.0 - lit))
		var br := brick.darkened(0.5 * (1.0 - lit)).lightened(0.04 * lit)
		MarketArt.draw_safe_quad(self, q0, q1, q1 - Vector2(0, foot), q0 - Vector2(0, foot), stone)
		MarketArt.draw_safe_quad(self, q0 - Vector2(0, foot), q1 - Vector2(0, foot), q1 - Vector2(0, H_total), q0 - Vector2(0, H_total), br)
		for hh in range(int(foot) + 3, int(H_total), 3):
			draw_line(q0 - Vector2(0, hh), q1 - Vector2(0, hh), br.darkened(0.32), 0.6)
		# 돌림띠(몸통 중간에 튀어나온 석재 띠)
		MarketArt.draw_safe_quad(self, q0 - Vector2(0, mold - 1.8), q1 - Vector2(0, mold - 1.8), q1 - Vector2(0, mold + 1.8), q0 - Vector2(0, mold + 1.8), stone.lightened(0.05))
		draw_line(q0 - Vector2(0, mold + 1.8), q1 - Vector2(0, mold + 1.8), stone.lightened(0.25), 0.7)
		if my > door_y:
			door_y = my
			door_i = i
	# 외곽선: 앞쪽 반 둘레의 밑·위와 좌우 끝 세로선
	var lx := ring[0]
	var rx2 := ring[0]
	for i4 in range(n):
		var u0: Vector2 = ring[i4]
		var u1: Vector2 = ring[(i4 + 1) % n]
		if (u0.y + u1.y) * 0.5 >= cen.y:
			draw_line(u0, u1, FT_OUT, 0.9)
			draw_line(u0 - Vector2(0, H_total), u1 - Vector2(0, H_total), FT_OUT, 0.9)
		if u0.x < lx.x:
			lx = u0
		if u0.x > rx2.x:
			rx2 = u0
	draw_line(lx, lx - Vector2(0, H_total), FT_OUT, 0.9)
	draw_line(rx2, rx2 - Vector2(0, H_total), FT_OUT, 0.9)
	# 2. 구멍: 큰 포구(대포 주둥이가 나옴, 4칸마다) + 작은 총안 두 줄(2칸 엇갈려)
	for i2 in range(n):
		var p0: Vector2 = ring[i2]
		var p1: Vector2 = ring[(i2 + 1) % n]
		if (p0.y + p1.y) * 0.5 < cen.y + 1.0:
			continue
		var m := (p0 + p1) * 0.5
		var outv := (m - cen).normalized()
		if i2 % 4 == 1:
			var pm := m - Vector2(0, foot + (H_total - foot) * 0.42)
			draw_rect(Rect2(pm + Vector2(-2.6, -2.8), Vector2(5.2, 5.6)), Color("141210"))
			draw_line(pm, pm + outv * 5.5, Color("2a2c30"), 2.8) # 포신
			FastDraw.circle(self, pm + outv * 5.5, 1.5, Color("0a0a0c"))
		elif i2 % 4 == 3:
			for hf: float in [0.27, 0.74]:
				var sm := m - Vector2(0, foot + (H_total - foot) * hf)
				draw_rect(Rect2(sm + Vector2(-1.2, -1.8), Vector2(2.4, 3.6)), Color("141210"))
	# 3. 홍예 출입문(앞쪽 가장 가까운 면)
	var dm := (ring[door_i] + ring[(door_i + 1) % n]) * 0.5
	var along := (ring[(door_i + 1) % n] - ring[door_i]).normalized() * 4.0
	_draw_gate_arch(dm, along, 3.0, 4.2)
	FastDraw.circle(self, dm + Vector2(0, -3.5), 3.0, Color("4a2c1a"))
	# 4. 꼭대기 갑판 + 둥근 여장
	var top := PackedVector2Array()
	for q2: Vector2 in ring:
		top.append(q2 - Vector2(0, H_total))
	FastDraw.poly(self, top, Color("948872"))
	for i3 in range(0, n, 2):
		var mm: Vector2 = top[i3]
		draw_rect(Rect2(mm + Vector2(-2.6, -4.6), Vector2(5.2, 4.6)), Color("736e66"))
		var merl_cap: Color = Color("f8fafc") if snow else Color("6a6560")
		draw_rect(Rect2(mm + Vector2(-2.6, -4.6), Vector2(5.2, 1.2)), merl_cap)
	# PORT-TRACE [공심돈 꼭대기 정자]: 의궤 동북공심돈 외도·실물 사진 — 처마지붕이 꼭대기 전체를 덮지 않고, 둥근 여장 안쪽
	# 가운데에 붉은 기둥의 작은 정자(팔각 지붕)만 얹혀 있다. 여장 둘레와 순찰 마루가 그대로 드러난다.
	var pav_r := r * 0.42
	# 5. 정자 붉은 기둥
	var pil: Array[Vector2] = []
	for k in range(8):
		var a2 := TAU * float(k) / 8.0 + TAU / 16.0
		pil.append(gs_pt(info, cos(a2) * pav_r * 0.85, GS_VC + sin(a2) * pav_r * 0.85, H_total))
	pil.sort_custom(func(u: Vector2, v: Vector2): return u.y < v.y)
	for pb: Vector2 in pil:
		draw_line(pb, pb - Vector2(0, 11.0), Color("a8322a"), 1.8)
		draw_line(pb + Vector2(0.6, 0), pb + Vector2(0.6, -11.0), Color("d0584a"), 0.6)
	# 6. 정자 팔각 지붕: 뒤쪽 면부터, 모서리가 살짝 치솟은 처마
	var roof_r := pav_r * 1.35
	var eave_h := H_total + 11.0
	var apex := gs_pt(info, 0.0, GS_VC, eave_h + 11.0)
	var eave: Array[Vector2] = []
	for k2 in range(8):
		var a3 := TAU * float(k2) / 8.0 + TAU / 16.0
		eave.append(gs_pt(info, cos(a3) * roof_r, GS_VC + sin(a3) * roof_r, eave_h + 3.0))
	var facets: Array = []
	for k3 in range(8):
		var e0: Vector2 = eave[k3]
		var e1: Vector2 = eave[(k3 + 1) % 8]
		facets.append({"e0": e0, "e1": e1, "y": (e0.y + e1.y) * 0.5, "x": (e0.x + e1.x) * 0.5})
	facets.sort_custom(func(u: Dictionary, v: Dictionary): return float(u["y"]) < float(v["y"]))
	var tile := Color("454b54")
	for ft: Dictionary in facets:
		var e0f: Vector2 = ft["e0"]
		var e1f: Vector2 = ft["e1"]
		var lit2 := clampf(0.55 + (float(ft["x"]) - cen.x) / (r * 60.0), 0.15, 1.0)
		var tc := tile.darkened(0.4 * (1.0 - lit2)).lightened(0.06 * lit2)
		# 처마 바로 아래 어두운 그늘
		FastDraw.poly(self, PackedVector2Array([e0f, e1f, e1f + Vector2(0, 3), e0f + Vector2(0, 3)]), Color("1c2025"))
		FastDraw.poly(self, PackedVector2Array([e0f, e1f, apex]), tc)
		# 기왓골
		for g in range(1, 4):
			var tt := float(g) / 6.0
			var bp := e0f.lerp(e1f, tt)
			draw_line(bp, bp.lerp(apex, 0.92), tc.darkened(0.25), 0.7)
		if snow:
			FastDraw.poly(self, PackedVector2Array([e0f.lerp(apex, 0.62), e1f.lerp(apex, 0.62), apex]), Color(0.96, 0.98, 1.0, 0.95))
			draw_line(e0f, e1f, Color("f8fafc", 0.96), 2.2)
		if float(ft["y"]) >= cen.y:
			draw_line(e0f + Vector2(0, 3), e1f + Vector2(0, 3), Color("2e8a6a"), 1.2) # 처마 단청 녹색 띠
			draw_line(e0f + Vector2(0, 4.5), e1f + Vector2(0, 4.5), Color("b83a2c"), 0.9)
	for e: Vector2 in eave:
		draw_line(e, apex, Color("ffffff") if snow else Color("d8d6d0"), 1.8 if snow else 1.3) # 추녀마루(흰 양성바름)
		FastDraw.circle(self, e - Vector2(0, 0.5), 1.4, Color("23282e"))
	FastDraw.circle(self, apex - Vector2(0, 2), 2.4, Color("23282e"))
	FastDraw.circle(self, apex - Vector2(0, 3.5), 1.4, Color("23282e")) # 절병통

func _gs_merlons(info: Dictionary, u0: float, u1: float, v0: float, v1: float, h: float) -> void:
	var edges: Array = [[u0, v1, u1, v1], [u1, v0, u1, v1], [u0, v0, u0, v1], [u0, v0, u1, v0]]
	for e: Array in edges:
		for k in range(6):
			var tt := (float(k) + 0.5) / 6.0
			var m := gs_pt(info, lerpf(float(e[0]), float(e[2]), tt), lerpf(float(e[1]), float(e[3]), tt), h)
			draw_rect(Rect2(m + Vector2(-2.4, -4.0), Vector2(4.8, 4.0)), Color("736e66"))

func _gs_soragak(info: Dictionary) -> void:
	var snow: bool = (band_master.current_season if band_master else current_season) == "겨울"
	var vc := 0.2
	var r := 1.3
	var H := 42.0
	var foot := WALL_HEIGHT
	var H_total := foot + H - 6.0
	var n := 20
	var ring := PackedVector2Array()
	for i in range(n):
		var ang := TAU * float(i) / float(n)
		ring.append(gs_pt(info, cos(ang) * r, vc + sin(ang) * r))
	var cen := gs_pt(info, 0.0, vc)
	# 화강암 밑동(0~WALL_HEIGHT) + 벽돌 원통(WALL_HEIGHT~H_total): 앞쪽 반만 면을 그린다
	for i in range(n):
		var q0: Vector2 = ring[i]
		var q1: Vector2 = ring[(i + 1) % n]
		if (q0.y + q1.y) * 0.5 < cen.y:
			continue
		var shade := clampf(0.5 + (q1.x - q0.x) * 0.02, 0.2, 0.8)
		MarketArt.draw_safe_quad(self, q0, q1, q1 - Vector2(0, foot), q0 - Vector2(0, foot), Color("c8bda5").darkened(0.15 * (1.0 - shade)))
		MarketArt.draw_safe_quad(self, q0 - Vector2(0, foot), q1 - Vector2(0, foot), q1 - Vector2(0, H_total), q0 - Vector2(0, H_total), Color("8a847b").darkened(0.25 * (1.0 - shade)))
		for hh in range(int(foot) + 4, int(H_total), 4):
			draw_line(q0 - Vector2(0, hh), q1 - Vector2(0, hh), Color("5f574c"), 0.5)
	# 꼭대기 원판 + 둥근 여장
	var top := PackedVector2Array()
	for q: Vector2 in ring:
		top.append(q - Vector2(0, H_total))
	FastDraw.poly(self, top, Color("e2e8f0") if snow else Color("948872"))
	for i in range(0, n, 2):
		var m: Vector2 = top[i]
		draw_rect(Rect2(m + Vector2(-2.2, -4.0), Vector2(4.4, 4.0)), Color("736e66"))
		if snow:
			draw_line(m + Vector2(-2.2, -4.0), m + Vector2(2.2, -4.0), Color("ffffff"), 1.2)
	# 나선 계단(바깥으로 감아 오르는 줄) — 앞쪽 반에서만 보이게
	var prev := Vector2.INF
	for k in range(61):
		var tt := float(k) / 60.0
		var ang2 := PI * 0.1 + tt * TAU * 1.5
		var hh2 := foot + tt * (H_total - foot - 2.0)
		var p := gs_pt(info, cos(ang2) * (r + 0.05), vc + sin(ang2) * (r + 0.05), hh2)
		var front := gs_pt(info, cos(ang2) * r, vc + sin(ang2) * r).y >= cen.y
		if prev != Vector2.INF and front:
			draw_line(prev, p, Color("d8d2c4"), 1.6)
		prev = p if front else Vector2.INF
	# 출입 홍예 + 꼭대기 망루
	_draw_gate_arch(gs_pt(info, 0.0, vc + r), (gs_pt(info, 1.0, vc + r) - gs_pt(info, 0.0, vc + r)).normalized() * 4.0, 3.0, 4.0)
	var A := gs_pt(info, 1.0, vc) - cen
	var F := gs_pt(info, 0.0, vc + 1.0) - cen
	_ft_box(cen, A, F, 0.35, 0.35, H_total, H_total + 8.0, Color("8a3a2a"))
	MarketArt.roof(self, cen, A, F, 0.5, 0.5, 0.05, H_total + 7.0, H_total + 16.0, Color("454b54"), false, snow)

## 연무대 로컬 좌표: r = 성벽과 나란히, f = 성벽 쪽으로(칸 단위), 가운데 칸 중심이 (0,0). 성벽 줄은 f = 3.
func ym_pt(info: Dictionary, r: float, f: float, h: float = 0.0) -> Vector2:
	var cpos: Vector2i = info["center"]
	var w: Vector2i = info["wall_dir"]
	var perp := Vector2(w.y, w.x)
	var g := Vector2(cpos) + Vector2(0.5, 0.5) + perp * r + Vector2(w) * f
	if not info.has("elevation"):
		var el: float = float(grid.tile(cpos.x, cpos.y).get("elevation", 1.0)) if grid and grid.in_bounds(cpos.x, cpos.y) else 1.0
		info["elevation"] = el
	var elev: float = float(info["elevation"])
	return cell_center(g.x, g.y, elev) - Vector2(0, h)

## PORT-TRACE [연무대 5x5]: 고증 — 성벽 반대쪽(뒤)에 화강석 3단 기단과 그 위 팔작지붕 대루(東將臺 현판), 둘레에 벽돌 사이로
## 구멍을 낸 영롱장, 가운데 훈련 광장(흙바닥·지휘 깃대), 성벽 쪽 끝은 국궁장 사대(과녁은 성 밖 — CitizenLayer가 그림).
func _draw_yeonmudae5(info: Dictionary) -> void:
	var snow: bool = (band_master.current_season if band_master else current_season) == "겨울"
	# 영롱장(뒤·양옆)
	var walls: Array = [[-2.45, -2.45, 2.45, -2.45], [-2.45, -2.45, -2.45, 1.2], [2.45, -2.45, 2.45, 1.2]]
	for wl: Array in walls:
		var a0 := ym_pt(info, float(wl[0]), float(wl[1]))
		var a1 := ym_pt(info, float(wl[2]), float(wl[3]))
		MarketArt.draw_safe_quad(self, a0, a1, a1 - Vector2(0, 9), a0 - Vector2(0, 9), Color("9a5a40"))
		var cap_col: Color = Color("f8fafc") if snow else MarketArt.ROOF_SLATE
		draw_line(a0 - Vector2(0, 9), a1 - Vector2(0, 9), cap_col, 2.0)
		var cnt := int(a0.distance_to(a1) / 7.0)
		for k in range(cnt):
			var m := a0.lerp(a1, (float(k) + 0.5) / float(maxi(1, cnt))) - Vector2(0, 5)
			FastDraw.poly(self, PackedVector2Array([m + Vector2(0, -2), m + Vector2(2, 0), m + Vector2(0, 2), m + Vector2(-2, 0)]), Color("e8dcc4"))
	# 3단 기단
	var tiers: Array = [[1.9, 0.85], [1.5, 0.65], [1.1, 0.5]]
	var bc := ym_pt(info, 0.0, -1.6)
	var A := ym_pt(info, 1.0, -1.6) - bc
	var F := ym_pt(info, 0.0, -0.6) - bc
	for i in range(3):
		var tier_data: Array = tiers[i]
		_ft_box(bc, A, F, float(tier_data[0]), float(tier_data[1]), 5.0 * float(i), 5.0 * float(i + 1), Color("d8d2c4").darkened(0.05 * float(i)))
		var bu := float(tier_data[0])
		var bv := float(tier_data[1])
		var top_t_col: Color = Color("edf2f7") if snow else Color("c4beb0")
		MarketArt.draw_safe_quad(self, bc - A * bu - F * bv - Vector2(0, 5.0 * float(i + 1)), bc + A * bu - F * bv - Vector2(0, 5.0 * float(i + 1)), bc + A * bu + F * bv - Vector2(0, 5.0 * float(i + 1)), bc - A * bu + F * bv - Vector2(0, 5.0 * float(i + 1)), top_t_col)
	# 앞 돌계단(광장 쪽)
	for k in range(3):
		var sv := 0.85 - 0.2 * float(k)
		var hh := 5.0 * float(k + 1)
		var st_col: Color = Color("edf2f7") if snow else Color("e4e0d6")
		MarketArt.draw_safe_quad(self, bc + F * sv - A * 0.25 - Vector2(0, hh), bc + F * sv + A * 0.25 - Vector2(0, hh), bc + F * (sv + 0.2) + A * 0.25 - Vector2(0, hh - 5.0), bc + F * (sv + 0.2) - A * 0.25 - Vector2(0, hh - 5.0), st_col)
	# 대루: 붉은 기둥 + 팔작지붕 + 현판
	var pav := bc
	var cols: Array = []
	for pu: float in [-0.9, -0.3, 0.3, 0.9]:
		for pv: float in [-0.4, 0.4]:
			cols.append(Vector2(pu, pv))
	cols.sort_custom(func(p, q): return (A * p.x + F * p.y).y < (A * q.x + F * q.y).y)
	for cp: Vector2 in cols:
		var b := pav + A * cp.x + F * cp.y - Vector2(0, 15)
		draw_line(b, b - Vector2(0, 13), Color("a8322a"), 2.4)
	MarketArt.roof(self, pav, A, F, 1.2, 0.68, 0.7, 27.0, 41.0, Color("454b54"), false, snow)
	var sp := pav + F * 0.5 - Vector2(0, 28)
	draw_rect(Rect2(sp + Vector2(-9, -3.5), Vector2(18, 6)), Color("1a1410"))
	draw_string(ThemeDB.fallback_font, sp + Vector2(-8, 1.5), "東將臺", HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color("f4d27a"))
	# 광장 지휘 깃대 + 사대(국궁장 쏘는 자리 줄)
	var fp := ym_pt(info, -1.9, 0.6)
	draw_line(fp, fp - Vector2(0, 30), Color("5c3a21"), 1.4)
	FastDraw.poly(self, PackedVector2Array([fp - Vector2(0, 30), fp + Vector2(12, -26), fp - Vector2(0, 22)]), Color("e8b820"))
	draw_line(ym_pt(info, -2.2, 2.2), ym_pt(info, 2.2, 2.2), Color("f4f0e4"), 1.2)

# ─────────────────────────────────────────────── 포루 4종(2x2)
## PORT-TRACE [포루 4종 재설계]: 북서포루(北西砲樓, 화포를 쏘는 공격형)·동북포루(東北鋪樓, 군사 대기·감시)·북포루(北鋪樓, 지형 특색)·남포루(南砲樓).
## 실물 사진처럼 성벽 밖으로 내민 석축 기단 위에 벽돌 몸통(총안·포안), 그 위로 창호를 단 누각과 깊은 처마지붕(팔작), 모서리 깃발.
const PORU_NAMES := {"bukseo": "北西砲樓", "dongbuk": "東北鋪樓", "buk": "北鋪樓", "nam": "南砲樓"}

## 옛 종류 이름(dong·seo·bukdong)을 4종으로 맞춘다
func poru_kind(info: Dictionary) -> String:
	match str(info.get("type", "")):
		"bukseo", "seo":
			return "bukseo"
		"dongbuk", "dong", "bukdong":
			return "dongbuk"
		"buk":
			return "buk"
	return "nam"

func poru_is_cannon(info: Dictionary) -> bool:
	return poru_kind(info) in ["bukseo", "nam"]

func poru_height(info: Dictionary) -> float:
	return 36.0 if poru_is_cannon(info) else 32.0

## 로컬 좌표: u = 성벽을 따라 0~2칸, v = 성벽 줄에서 바깥쪽(칸 단위)
func pr_pt(info: Dictionary, u: float, v: float, h: float = 0.0) -> Vector2:
	var s: Vector2i = info["start"]
	var g := Vector2(s) + Vector2(0.5, 0.5) + Vector2(info["axis"] as Vector2i) * (u - 0.5) + Vector2(info["out"] as Vector2i) * v
	if not info.has("elevation"):
		var el: float = float(grid.tile(s.x, s.y).get("elevation", 1.0)) if grid and grid.in_bounds(s.x, s.y) else 1.0
		info["elevation"] = el
	var elev: float = float(info["elevation"])
	return cell_center(g.x, g.y, elev) - Vector2(0, h)

## 포구(대포 주둥이) 화면 좌표들 — 공격형(砲樓)만. 감시·대기형(鋪樓)은 비어 있다.
func poru_muzzles(info: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if not poru_is_cannon(info):
		return out
	var base_h: float = WALL_HEIGHT
	var L := float(info.get("len", 2))
	for f: float in [0.25, 0.5, 0.75]:
		out.append(pr_pt(info, L * f, 1.6 if L > 1.5 else 1.45, base_h + 11.0))
	return out

func _draw_poru2(info: Dictionary) -> void:
	var typ := poru_kind(info)
	var cannon := poru_is_cannon(info)
	var tall := poru_height(info)
	var snow := current_season == "겨울"
	var brick := Color("7d776f") if typ == "nam" else (Color("736d66") if typ == "bukseo" else Color("7f7970"))
	# PORT-TRACE [포루 1x2]: len 1 = 성벽 한 칸 + 바깥 한 칸. 국소 -1~1이 몸통 둘레가 되도록 A(성벽 방향 반폭)·Fv(돌출 방향 반폭)를 잡는다
	# — 성벽 칸 안쪽 면(-0.25)에서 바깥 칸 끝(1.45)까지 바깥으로 길쭉한 직사각형(의궤 포루 외도).
	var L := float(info.get("len", 2))
	var cu := L * 0.5
	var hu := 0.48 if L < 1.5 else 1.0
	var cv := 0.6 if L < 1.5 else 0.55
	var hv := 0.85 if L < 1.5 else 1.0
	var cb := pr_pt(info, cu, cv)
	var A := pr_pt(info, cu + hu, cv) - cb
	var Fv := pr_pt(info, cu, cv + hv) - cb
	var S := Vector2(1, 0)
	var Fd := Vector2(0, 1)
	# 땅에 드리운 그림자
	var foot := _bh_rect(cb, A, Fv, S, Fd, -1.02, 1.02, -1.04, 1.04)
	for k in range(2):
		var sp := PackedVector2Array()
		for q: Vector2 in foot:
			sp.append(q + Vector2(6.0 + 6.0 * float(k), 3.0 + 3.0 * float(k)))
		FastDraw.poly(self, sp, Color(0, 0, 0, 0.13))
	# 땅에 붙는 박석 마당(바깥쪽으로 넉넉히)과 성벽이 닿는 양옆 석축 보강
	var apron_q := _bh_rect(cb, A, Fv, S, Fd, -1.18, 1.18, -1.0, 1.5)
	FastDraw.poly(self, apron_q, Color("a89c82") if not snow else Color("c8ccd0"))
	FastDraw.poly(self, _bh_rect(cb, A, Fv, S, Fd, -1.08, 1.08, -1.0, 1.3), Color("bfb39a") if not snow else Color("dfe3e6"))
	# 북포루: 지형 특색 — 바깥으로 비탈에 쌓은 막돌 축대와 바위
	if typ == "buk":
		for bq: Vector3 in [Vector3(-0.8, 1.35, 1.0), Vector3(0.0, 1.55, 0.8), Vector3(0.85, 1.4, 1.1), Vector3(-0.3, 1.7, 0.6)]:
			var bp := cb + A * bq.x + Fv * bq.y
			FastDraw.circle(self, bp + Vector2(0, 1), 8.0 * bq.z, Color("7d725f"))
			FastDraw.circle(self, bp, 7.0 * bq.z, Color("b3a78f"))
			FastDraw.circle(self, bp + Vector2(-1.5, -1.5), 3.4 * bq.z, Color("cfc4ab"))
	# 1. 화강석 기단 + 돌줄눈 (성벽 높이 WALL_HEIGHT=18.0과 100% 일치)
	var BASE_H := WALL_HEIGHT
	# 기단 돌빛은 성벽 체성과 같게 — 성벽에 다른 덩어리가 박힌 듯 보이지 않게
	var bf := _bh_prism(_bh_rect(cb, A, Fv, S, Fd, -0.98, 0.98, -1.0, 1.0), 0.0, BASE_H, FT_STONE, FT_STONE_D)
	_bh_courses(bf, 0.0, BASE_H, 3, 10.0, Color("6f6452"))
	for fc: Array in bf:
		draw_line((fc[0] as Vector2) - Vector2(0, BASE_H), (fc[1] as Vector2) - Vector2(0, BASE_H), Color("bfb39a"), 1.0)
	# 2. 벽돌 몸통 + 층마다 구멍
	var top_tall := BASE_H + tall - 12.0
	var rf := _bh_prism(_bh_rect(cb, A, Fv, S, Fd, -0.9, 0.9, -0.92, 0.92), BASE_H, top_tall, brick, brick.lightened(0.1))
	_bh_courses(rf, BASE_H, top_tall, 6, 4.0, brick.darkened(0.32))
	for fc2: Array in rf:
		var a: Vector2 = fc2[0]
		var b: Vector2 = fc2[1]
		# 돌림띠
		draw_line(a - Vector2(0, top_tall - 3.0), b - Vector2(0, top_tall - 3.0), Color("c9c3b6"), 1.6)
		if cannon:
			for k2 in range(3):
				var m := a.lerp(b, (float(k2) + 0.5) / 3.0) - Vector2(0, BASE_H + 11.0)
				draw_rect(Rect2(m + Vector2(-2.6, -2.8), Vector2(5.2, 5.6)), Color("121010"))
				var ov: Vector2 = (fc2[2] as Vector2)
				draw_line(m, m + ov * 5.0, Color("2a2c30"), 2.8)
				FastDraw.circle(self, m + ov * 5.0, 1.4, Color("0a0a0c"))
			for k3 in range(4):
				var m2 := a.lerp(b, (float(k3) + 0.5) / 4.0) - Vector2(0, BASE_H + 19.0)
				draw_rect(Rect2(m2 + Vector2(-1.1, -1.5), Vector2(2.2, 3.0)), Color("121010"))
		else:
			for lv: float in [BASE_H + 7.0, BASE_H + 15.0]:
				for k4 in range(4):
					var m3 := a.lerp(b, (float(k4) + 0.5) / 4.0) - Vector2(0, lv)
					draw_rect(Rect2(m3 + Vector2(-1.2, -1.5), Vector2(2.4, 3.0)), Color("121010"))
	# 현판은 벽돌 몸통 앞면 아래쪽에(지붕 위가 아니라 벽에)
	var best_face: Array = []
	for fc3: Array in rf:
		if best_face.is_empty() or (fc3[2] as Vector2).y > (best_face[2] as Vector2).y:
			best_face = fc3
	if not best_face.is_empty():
		var pm := ((best_face[0] as Vector2) + (best_face[1] as Vector2)) * 0.5 - Vector2(0, BASE_H + 4.0)
		draw_rect(Rect2(pm + Vector2(-13, -3.5), Vector2(26, 7)), Color("1a1410"))
		draw_rect(Rect2(pm + Vector2(-13, -3.5), Vector2(26, 7)), Color("d4af37"), false, 0.7)
		draw_string(ThemeDB.fallback_font, pm + Vector2(-11.5, 1.8), str(PORU_NAMES.get(typ, "砲樓")), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color("f4d27a"))
	# 3. 위층 누각: 붉은 틀에 창호(격자 창), 보라·청록 단청 처마
	var UP := 15.0
	var uf := _bh_prism(_bh_rect(cb, A, Fv, S, Fd, -0.76, 0.76, -0.74, 0.74), top_tall, top_tall + UP, Color("9a3a2c"), Color(0, 0, 0, 0))
	for fc4: Array in uf:
		var a2: Vector2 = fc4[0]
		var b2: Vector2 = fc4[1]
		var nw := 3
		for k5 in range(nw):
			var t0 := (float(k5) + 0.12) / float(nw)
			var t1 := (float(k5) + 0.88) / float(nw)
			var w0 := a2.lerp(b2, t0)
			var w1 := a2.lerp(b2, t1)
			MarketArt.draw_safe_quad(self, w0 - Vector2(0, top_tall + 2.5), w1 - Vector2(0, top_tall + 2.5), w1 - Vector2(0, top_tall + UP - 2.5), w0 - Vector2(0, top_tall + UP - 2.5), Color("efe4c8"))
			# 격자 살
			var wc := (w0 + w1) * 0.5
			draw_line(wc - Vector2(0, top_tall + 2.5), wc - Vector2(0, top_tall + UP - 2.5), Color("7a4a2a"), 0.7)
			draw_line(w0 - Vector2(0, top_tall + UP * 0.5), w1 - Vector2(0, top_tall + UP * 0.5), Color("7a4a2a"), 0.7)
		for kk in range(4):
			var pp := a2.lerp(b2, float(kk) / 3.0)
			draw_line(pp - Vector2(0, top_tall), pp - Vector2(0, top_tall + UP), Color("7a2418"), 1.4) # 기둥
	# 4. 팔작지붕
	if L < 1.5:
		# 1x2: 바깥으로 길쭉한 몸통 — 용마루도 바깥 방향으로(의궤 포루 외도)
		_bh_paljak(cb, A, Fv, Vector2.ZERO, Fd, S, 1.0, 0.98, 0.5, top_tall + UP + 3.0, top_tall + UP + 20.0, snow)
	else:
		_bh_paljak(cb, A, Fv, Vector2.ZERO, S, Fd, 1.0, 0.94, 0.4, top_tall + UP + 3.0, top_tall + UP + 26.0, snow)
	# 5. 모서리 깃발(대기·감시는 청색, 공격은 홍색)
	var flag_col := Color("2f67c0") if not cannon else Color("c0392b")
	for fq: Vector2 in [Vector2(-1.0, -0.95), Vector2(1.0, 0.95)]:
		var fp := cb + A * fq.x + Fv * fq.y - Vector2(0, BASE_H)
		draw_line(fp, fp - Vector2(0, 26), Color("5c3a21"), 1.6)
		FastDraw.poly(self, PackedVector2Array([fp - Vector2(0, 26), fp + Vector2(11, -22), fp - Vector2(0, 18)]), flag_col)

# ─────────────────────────────────────────────── 교육 기관: 서당 2x2 · 매곡서원 3x3 · 수원향교 4x4
## 공통: 로컬 (u, v) 칸 단위, C = 묶음 한가운데, v + 쪽이 앞(마당·대문)
func _edu_wall(C: Vector2, AX: Vector2, AY: Vector2, half: float, gate_gap: float, front: bool) -> void:
	var snow: bool = (band_master.current_season if band_master else current_season) == "겨울"
	var edges: Array = [[-half, -half, half, -half], [-half, -half, -half, half], [half, -half, half, half], [-half, half, half, half]]
	for e: Array in edges:
		var is_front := float(e[1]) == half and float(e[3]) == half
		if is_front != front:
			continue
		var segs: Array = [[float(e[0]), float(e[2])]]
		if is_front and gate_gap > 0.0:
			segs = [[-half, -gate_gap], [gate_gap, half]]
		for sg: Array in segs:
			var a0: Vector2 = C + AX * (float(sg[0]) if float(e[1]) == float(e[3]) else float(e[0])) + AY * (float(e[1]) if float(e[1]) == float(e[3]) else float(sg[0]))
			var a1: Vector2 = C + AX * (float(sg[1]) if float(e[1]) == float(e[3]) else float(e[2])) + AY * (float(e[3]) if float(e[1]) == float(e[3]) else float(sg[1]))
			MarketArt.draw_safe_quad(self, a0, a1, a1 - Vector2(0, 6), a0 - Vector2(0, 6), Color("ddd3bd"))
			var cap_col: Color = Color("f8fafc") if snow else MarketArt.ROOF_SLATE
			draw_line(a0 - Vector2(0, 6), a1 - Vector2(0, 6), cap_col, 2.0 if snow else 1.8)

func _edu_hall(c: Vector2, A: Vector2, F: Vector2, bu: float, bv: float, h: float, roof: Color, open_front: bool, thatch: bool = false) -> PackedVector2Array:
	var snow: bool = (band_master.current_season if band_master else current_season) == "겨울"
	MarketArt.box(self, c, A, F, bu + 0.05, bv + 0.05, 0.0, 2.5, Color("b8b0a0"))
	var fr := MarketArt.box(self, c, A, F, bu, bv, 2.5, h, MarketArt.WALL_PLASTER, open_front)
	MarketArt.roof(self, c, A, F, bu + 0.22, bv + 0.25, bu * 0.6, h - 1.0, h + 9.0, roof, thatch, snow)
	return fr

func _edu_plaque(fr: PackedVector2Array, text: String) -> void:
	if fr.size() != 4:
		return
	var sp := (fr[2] + fr[3]) * 0.5 + Vector2(0, -2)
	draw_rect(Rect2(sp + Vector2(-9, -3.5), Vector2(18, 6)), Color("1a1410"))
	draw_string(ThemeDB.fallback_font, sp + Vector2(-8, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color("f4d27a"))

## 서당: 김홍도 〈서당〉의 초가 서당 — 대청이 마당 쪽으로 트인 ㄱ 없는 일자 초가, 마당 앞 싸리 울타리
func _draw_seodang(C: Vector2, AX: Vector2, AY: Vector2) -> void:
	var snow: bool = (band_master.current_season if band_master else current_season) == "겨울"
	var fr := _edu_hall(C + AY * -0.4, AX, AY, 0.8, 0.4, 11.0, MarketArt.THATCH, true, true)
	_edu_plaque(fr, "書堂")
	for k in range(9):
		var q := C + AX * (-0.95 + 0.2375 * float(k)) + AY * 0.95
		draw_line(q, q - Vector2(0, 5), Color("8a6a3a"), 0.9)
	draw_line(C + AX * -0.95 + AY * 0.95 - Vector2(0, 3), C + AX * 0.95 + AY * 0.95 - Vector2(0, 3), Color("8a6a3a"), 0.7)
	if snow:
		draw_line(C + AX * -0.95 + AY * 0.95 - Vector2(0, 5.5), C + AX * 0.95 + AY * 0.95 - Vector2(0, 5.5), Color("f8fafc", 0.95), 1.2)

## 매곡서원: 뒤에 담을 두른 사당, 가운데 강당(梅谷書院), 앞 양옆 동재·서재, 모서리 작은 정자, 둘레 낮은 담장
func _draw_seowon(C: Vector2, AX: Vector2, AY: Vector2) -> void:
	var snow: bool = (band_master.current_season if band_master else current_season) == "겨울"
	_edu_wall(C, AX, AY, 1.45, 0.3, false)
	var sd := C + AY * -1.0
	MarketArt.box(self, sd, AX, AY, 0.42, 0.28, 0.0, 9.0, MarketArt.WALL_PLASTER)
	MarketArt.roof(self, sd, AX, AY, 0.58, 0.42, 0.25, 8.0, 15.0, MarketArt.ROOF_SLATE, false, snow)
	var fr := _edu_hall(C + AY * -0.05, AX, AY, 0.85, 0.36, 12.0, MarketArt.ROOF_SLATE, true)
	_edu_plaque(fr, "梅谷書院")
	for su: float in [-0.95, 0.95]:
		var dj := C + AX * su + AY * 0.75
		MarketArt.box(self, dj, AY, AX, 0.38, 0.22, 0.0, 9.0, MarketArt.WALL_PLASTER)
		MarketArt.roof(self, dj, AY, AX, 0.5, 0.36, 0.22, 8.0, 14.0, MarketArt.ROOF_SLATE, false, snow)
	var pv := C + AX * 1.05 + AY * -1.05
	for k in range(4):
		var ang := TAU * float(k) / 4.0 + PI * 0.25
		var q := pv + AX * cos(ang) * 0.18 + AY * sin(ang) * 0.18
		draw_line(q, q - Vector2(0, 9), Color("a8322a"), 1.2)
	MarketArt.roof(self, pv, AX, AY, 0.28, 0.28, 0.02, 8.0, 14.0, MarketArt.ROOF_SLATE, false, snow)
	_edu_wall(C, AX, AY, 1.45, 0.3, true)

## PORT-TRACE [수원향교 4x4]: 실제 수원향교 배치 — 남북 축을 따라 앞(남) 외삼문 → 명륜당(강학, 앞마당 좌우 동재·서재) →
## 내삼문 → 높은 기단 위 대성전(제향, 붉은 기둥·大成殿 현판). 둘레 담장, 앞에 홍살문. v + 쪽이 남(정면).
func _draw_hyanggyo_part(pos: Vector2i, anchor: Vector2i, c: Vector2) -> void:
	var s: String = band_master.current_season if band_master else current_season
	var snow: bool = s == "겨울"
	var yard_col: Color
	match s:
		"겨울": yard_col = Color("f1f5f9")
		"가을": yard_col = Color("dfd4b8")
		_: yard_col = Color("cfc09a")
	FastDraw.poly(self, _diamond(c, 0.99), yard_col)
	if s == "가을":
		# 가을철 은행나무 낙엽 융단 도트
		for leaf_k in range(4):
			var l_off := Vector2(float(leaf_k * 5 - 8), float((leaf_k * 3) % 7 - 3))
			FastDraw.circle(self, c + l_off, 1.2, Color("eab308"))
	var x0 := anchor.x - 1
	var y0 := anchor.y - 1
	if pos != Vector2i(x0 + 3, y0 + 3):
		return
	var C := cell_center(float(x0) + 2.0, float(y0) + 2.0, 1.0)
	var AX := cell_center(1.0, 0.0, 1.0) - cell_center(0.0, 0.0, 1.0)
	var AY := cell_center(0.0, 1.0, 1.0) - cell_center(0.0, 0.0, 1.0)

	# [수원향교 스마트 오리엔테이션 렌더링]
	# 타일에 저장된 facing_direction을 읽어 전방(입구) 축 FWD와 좌우 축 SIDE를 동적 회전
	var facing: String = "south"
	if grid and grid.in_bounds(anchor.x, anchor.y):
		facing = str(grid.grid[anchor.y][anchor.x].get("facing_direction", ""))
	if facing == "" and grid:
		var ft_tiles: Array[Vector2i] = grid.get_site_footprint(anchor.x, anchor.y, 4, 4)
		facing = grid.get_best_road_facing_direction(ft_tiles)
		if grid.in_bounds(anchor.x, anchor.y):
			grid.grid[anchor.y][anchor.x]["facing_direction"] = facing

	var FWD: Vector2 = AY
	var SIDE: Vector2 = AX
	match facing:
		"east":
			FWD = AX
			SIDE = -AY
		"north":
			FWD = -AY
			SIDE = -AX
		"west":
			FWD = -AX
			SIDE = AY
		_: # "south"
			FWD = AY
			SIDE = AX

	_edu_wall(C, SIDE, FWD, 1.95, 0.35, false)
	# 대성전(뒤, 높은 기단)
	var ds := C + FWD * -1.35
	MarketArt.box(self, ds, SIDE, FWD, 1.15, 0.5, 0.0, 6.0, Color("cfc9bc"))
	var dfr := MarketArt.box(self, ds, SIDE, FWD, 1.0, 0.4, 6.0, 18.0, Color("a8322a"))
	MarketArt.roof(self, ds, SIDE, FWD, 1.25, 0.65, 0.75, 17.0, 30.0, MarketArt.ROOF_SLATE, false, snow)
	_edu_plaque(dfr, "大成殿")
	# 내삼문
	var nm := C + FWD * -0.6
	MarketArt.box(self, nm, SIDE, FWD, 0.35, 0.1, 0.0, 8.0, Color("8a3a2a"))
	MarketArt.roof(self, nm, SIDE, FWD, 0.45, 0.2, 0.2, 7.0, 12.0, MarketArt.ROOF_SLATE, false, snow)
	# 동재·서재 + 명륜당
	for su: float in [-1.45, 1.45]:
		var dj := C + SIDE * su + FWD * 0.9
		MarketArt.box(self, dj, FWD, SIDE, 0.5, 0.25, 0.0, 9.0, MarketArt.WALL_PLASTER)
		MarketArt.roof(self, dj, FWD, SIDE, 0.62, 0.4, 0.3, 8.0, 15.0, MarketArt.ROOF_SLATE, false, snow)
	var mfr := _edu_hall(C + FWD * 0.2, SIDE, FWD, 1.15, 0.4, 13.0, MarketArt.ROOF_SLATE, true)
	_edu_plaque(mfr, "明倫堂")
	# 앞 담장 + 외삼문 + 홍살문
	_edu_wall(C, SIDE, FWD, 1.95, 0.35, true)
	var om := C + FWD * 1.95
	MarketArt.box(self, om, SIDE, FWD, 0.42, 0.12, 0.0, 9.0, Color("8a3a2a"))
	MarketArt.roof(self, om, SIDE, FWD, 0.55, 0.24, 0.25, 8.0, 14.0, MarketArt.ROOF_SLATE, false, snow)
	var hs := C + FWD * 2.4
	for su2: float in [-0.4, 0.4]:
		draw_line(hs + SIDE * su2, hs + SIDE * su2 - Vector2(0, 20), Color("c0392b"), 1.6)
	draw_line(hs + SIDE * -0.45 - Vector2(0, 18), hs + SIDE * 0.45 - Vector2(0, 18), Color("c0392b"), 1.4)
	if snow:
		draw_line(hs + SIDE * -0.45 - Vector2(0, 19), hs + SIDE * 0.45 - Vector2(0, 19), Color("f8fafc"), 1.4)
	for k in range(7):
		var q := hs + SIDE * (-0.35 + 0.1167 * float(k)) - Vector2(0, 18)
		draw_line(q, q - Vector2(0, 5), Color("c0392b"), 0.8)
		if snow:
			FastDraw.circle(self, q - Vector2(0, 5.5), 0.8, Color("f8fafc"))
