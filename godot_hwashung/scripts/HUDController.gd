extends CanvasLayer
class_name HUDController

const SpriteCacheManager = preload("res://scripts/autoload/SpriteCacheManager.gd")

## 조선 의궤 및 심시티 2000 완벽 이식 HUD 컨트롤러

signal quick_action_requested(action_name: String)
signal tool_selected(tool_id: String)
signal pan_toggle_requested
signal zoom_in_requested
signal zoom_out_requested
signal center_view_requested

var panel_controller: Node = null # 성곽 방호력 표시를 누르면 성곽 보수 창을 연다(순환 참조 방지 위해 Node 타입 지정)
var time_manager: TimeManager
var simulation_core: SimulationCore
var camera: CameraController
var city_layer: CityLayer
var citizen_manager: CitizenManager = null
var citizen_layer: Node = null

# 상단 긴급 경보 배너 및 화면 외곽 위험 지시 마커
var banner_raid_alert: PanelContainer = null
var label_raid_alert: Label = null
var btn_jump_battle: Button = null
var edge_battle_marker: PanelContainer = null
var label_edge_marker: Label = null
var _current_battle_world_pos: Vector2 = Vector2.ZERO
var _current_battle_loc_name: String = ""
var _is_battle_active: bool = false

# 상단 알림 및 기근 배너 스택 (절대 겹침 방지 VBoxContainer)
var top_alert_stack: VBoxContainer = null
var banner_famine: PanelContainer = null
var label_famine: Label = null
var famine_dismissed: bool = false
var famine_last_turn: int = -1

# 좌측 하단 계절 베이킹 인디케이터
var panel_baking_indicator: PanelContainer = null
var label_baking_indicator: Label = null
var _baking_tween: Tween = null

# 상단 헤더 요소들
var top_bar: PanelContainer
var label_season: Label
var bar_res: ProgressBar
var bar_com: ProgressBar
var bar_agr: ProgressBar

var label_gold: Label
var label_rice: Label
var label_pop: Label
var label_loyalty: Label
var label_authority: Label
var label_flood: Label
var label_fortress: Label
var panel_fortress: PanelContainer

var _last_stat_values: Dictionary = {}
var _stat_tweens: Dictionary = {}
var _base_stat_colors: Dictionary = {}

var btn_pause: Button
var btn_normal: Button
var btn_fast: Button
var btn_ultra: Button

var btn_tiger: Button
var btn_crown: Button
var btn_hyoryung: Button
var btn_eulmyo: Button
var btn_bandit: Button

# 좌측 상단 도구 상태 바
var tool_bar_panel: PanelContainer
var tool_bar_icon: Label
var tool_bar_title: Label
var tool_bar_desc: Label

# 우측 상단 나침반 및 뷰포트 컨트롤
var compass_panel: PanelContainer
var compass_label: Label
var btn_pan: Button
var btn_demolish: Button

# 상단 중앙 토스트 배너 & 10초 큐 배너
var toast_panel: PanelContainer
var toast_label: Label
var toast_tween: Tween
var top_alert_banner: TopAlertBanner = null


const TOOL_INFOS := {
	"inspect": {"icon": "🔍", "name": "살피기", "desc": "토지의 풍수지리와 건물의 사연을 살핍니다."},
	"road": {"icon": "🛣️", "name": "흙길(삼남로)", "desc": "마차와 수레가 오가는 자연스러운 황토 흙길입니다."},
	"stone_road": {"icon": "🏛️", "name": "박석길", "desc": "궁궐과 성문 앞 대로에 화강암 판석을 정갈하게 깐 포장도로입니다. (보통 난이도 시 흙길의 10배 비용)"},
	"wall": {"icon": "🧱", "name": "화성성곽", "desc": "석재와 전돌을 혼합하여 견고한 방어 성벽을 축조합니다."},
	"gate": {"icon": "⛩️", "name": "홍예성문", "desc": "장안문/팔달문 등 대외 관세를 징수하고 치안을 통제합니다."},
	"well": {"icon": "💧", "name": "우물·수로", "desc": "백성들에게 맑은 물을 공급하고 화재에 대비합니다."},
	"zone_res": {"icon": "🏡", "name": "방·리(민가)", "desc": "초가삼간 터를 구획하여 유민들을 정착시킵니다."},
	"zone_com": {"icon": "🏪", "name": "저잣거리(상업)", "desc": "난전과 시전을 허하여 상업 번영을 촉진합니다."},
	"zone_agr": {"icon": "🌾", "name": "대유둔전(농업)", "desc": "국영 농경지입니다. 성 밖 외곽 들판에만 개간할 수 있으며(성내 건설 불가), 조건 충족 시 성 밖에 자동 구획됩니다. 성문 및 도로망으로 연결되어야 군량이 국고로 원활히 환수됩니다."},
	"zone_ind": {"icon": "🔥", "name": "공방(작업장)", "desc": "축성용 쇠를 녹이는 야조소·기와 굽는 와소 부지입니다. 매연과 불 때문에 수원천변이나 성 밖 외곽에 두는 것이 제격입니다."},
	"terra_plain": {"icon": "🟢", "name": "평지 붓", "desc": "지형을 평평하게 고릅니다. (셀당 금화 1,000냥 소모)"},
	"terra_mountain": {"icon": "⛰️", "name": "산 쌓기", "desc": "흙과 돌을 쌓아 산과 언덕을 올립니다. (셀당 금화 1,000냥 소모)"},
	"terra_mountain_down": {"icon": "⛏️", "name": "산 깎기", "desc": "산과 언덕을 깎아 평탄화합니다. (셀당 금화 1,000냥 소모)"},
	"terra_water_shallow": {"icon": "💧", "name": "얕은 여울", "desc": "걸어서 건널 수 있는 얕은 물길을 조성합니다. (셀당 금화 1,000냥 소모)"},
	"terra_water": {"icon": "🌊", "name": "물 붓(보통)", "desc": "수원천 및 하천 물길을 조성합니다. (셀당 금화 1,000냥 소모)"},
	"terra_water_deep": {"icon": "🌀", "name": "깊은 물", "desc": "배로만 건널 수 있는 깊은 수역을 팝니다. (셀당 금화 1,000냥 소모)"},
	"terra_grass": {"icon": "🌿", "name": "풀밭 가꾸기", "desc": "싱그러운 풀과 들꽃이 자라나는 풀밭으로 다듬습니다. (셀당 금화 1,000냥 소모)"},
	"terra_rocky": {"icon": "🪨", "name": "돌밭 조성", "desc": "화강암 자갈과 바위가 흩뿌려진 거친 돌밭을 만듭니다. (셀당 금화 1,000냥 소모)"},
	"terra_dirt": {"icon": "🍂", "name": "흙바닥 붓", "desc": "자연스러운 마사토와 황토 흙바닥으로 정돈합니다. (셀당 금화 1,000냥 소모)"},
	"terra_field": {"icon": "🌾", "name": "흙밭 개간", "desc": "농작물을 재배할 수 있는 반듯한 이랑진 흙밭을 만듭니다. (셀당 금화 1,000냥 소모)"},
	"terra_forest": {"icon": "🌲", "name": "우거진 숲 식수", "desc": "소나무와 활엽수, 붉은 단풍이 어우러진 울창한 숲을 가꿉니다. (셀당 금화 1,000냥 소모)"},
	"patrol": {"icon": "🚨", "name": "순라청(치안)", "desc": "포졸을 순찰시켜 범죄와 화적 떼를 소탕합니다."},
	"firefighter": {"icon": "🧯", "name": "멸화군(소방)", "desc": "초가 화재를 신속히 진압하는 방화 부대입니다."},
	# PORT-TRACE [행궁≠관아]: 행궁은 관아를 대신하지 않는다 — 송사·옥사·치안은 따로 지은 관아(2x2)가 맡는다
	"haenggung": {"icon": "👑", "name": "화성행궁", "desc": "임금의 거처. 신풍루·봉수당·장락당·낙남헌 등 여러 전각이 모인 7×7칸 궁궐로, 넉 달에 걸쳐 짓습니다."},
	"seojangdae": {"icon": "🏯", "name": "서장대", "desc": "팔달산 정상에 우뚝 솟은 군사 총지휘소입니다."},
	"bongdon": {"icon": "🔥", "name": "봉돈(봉수대)", "desc": "위급 상황을 한양 조정에 즉시 알리는 군영 통신망입니다."},
	"gongsimdon": {"icon": "🛡️", "name": "공심돈(전돌 요새)", "desc": "성벽에 결합된 3층 벽돌 요새로, 총안과 포구를 갖춰 적의 접근을 원거리에서 저지합니다."},
	"poru": {"icon": "💥", "name": "포루(화포 포대)", "desc": "치성 위에 불랑기포와 대포를 설치한 강력한 화력 지원 거점입니다."},
	"yeonmudae": {"icon": "🏹", "name": "연무대(동장대)", "desc": "장용영 군사들을 조련하고 활쏘기를 사열하는 군사 지휘 훈련장입니다."},
	"banghwasuryu": {"icon": "🌸", "name": "방화수류정·용연", "desc": "성곽 모서리에 걸터앉은 1칸 각루와 성 밖 3x3 용연 연못이 맞닿은 일체형 복합 구조물입니다. ㄱ자 누각과 겹친 팔작지붕선의 백미입니다."},
	"yongyeon": {"icon": "🌿", "name": "용연·방화수류정", "desc": "방화수류정(2x2)과 맞닿은 3x3 인공연못 복합 구조물입니다. 섬(당주)과 소나무, 버드나무가 어우러집니다."},
	"hwahong": {"icon": "🌉", "name": "화홍문(북수문)", "desc": "수원천을 가로지르는 4x1 수문교입니다. 일곱 홍예 석축 중앙에 균형 잡힌 단청 문루가 당당히 올라섭니다."},
	"levee": {"icon": "🛡️", "name": "석축제방", "desc": "수원천 범람을 방지하는 영구 석축 호안 제방입니다."},
	"reservoir": {"icon": "🌊", "name": "저수지(작은 못)", "desc": "성 안·성 밖 들판에 못을 팝니다. 가까운 둔전까지 수로가 저절로 뚫려 물을 댑니다."},
	# PORT-TRACE [만석거 6x6]: 예전엔 이 이름표가 한 칸짜리 "reservoir"에 붙어 있었다 — 실제
	# 만석거(6x6 규모, 부지 축조)는 별도 도구 "manseokgeo"로 분리했다.
	"manseokgeo": {"icon": "💧", "name": "만석거(萬石渠)", "desc": "정조가 축조한 화성 최대의 저수지. 6x6 규모의 큰 부지를 잡아 여러 달에 걸쳐 완공됩니다. 성 밖 들판에도 지을 수 있고, 완공되면 주변 둔전으로 수로가 저절로 뚫립니다."},
	"chukmanje": {"icon": "🌾", "name": "축만제(祝萬堤·서호)", "desc": "정조가 축조한 화성 서쪽의 대형 저수지(서호). 6x6 부지 축조로 만석거와 동일한 공기와 비용이 소요되며, 호수 한가운데 푸른 인공섬(당주)이 떠 있는 수려한 서호낙조의 명소입니다. 주변 둔전에 풍부한 관개 용수를 공급합니다. (5대 복지 시설)"},
	"jinhulso": {"icon": "🍲", "name": "진휼소(賑恤所) 2x2", "desc": "2x2 규모의 관영 구휼 복지 종합 단지 (금화 5,000냥, 군량 5,000석). 흉년과 수해 등 재난 발생 시 굶주린 백성들에게 따뜻한 쌀죽을 배급하여 민심 붕괴(-15%)를 방어합니다. 부재 시 기근 대처 불가로 민심이 대폭 하락합니다. (5대 복지 시설)"},
	"hyanggyo": {"icon": "🏫", "name": "수원향교(水原鄕校) 4x4", "desc": "성곽 바깥 평지, 성문과 길로 곧장 이어진 자리에만 세웁니다. 외삼문·명륜당·대성전이 남북으로 늘어서고, 매달 금 500·쌀 500을 쓰는 대신 민심 +1, 학문력 +1, 연구 비용 -15%, 인재 출현 확률 +20%."},
	"yeonghwajeong": {"icon": "🏞️", "name": "영화정(迎華亭) 2x2", "desc": "만석거가 완공된 뒤 그 둑 곁(3칸 안)에 세우는 관청형 정자입니다. 대청마루·온돌방·행랑채가 ㄱ자로 붙어 만석거 수면을 바라보고, 관개 둔전의 소출을 늘립니다."},
	"gwana": {"icon": "⚖️", "name": "관아·옥사(2x2)", "desc": "사또가 송사를 듣고 죄인을 문초하는 동헌과 둥근 옥사가 한 담장 안에 있는 2x2 관아입니다. 붙잡힌 화적·좀도둑이 압송돼 와 재판받고 옥에 갇힙니다. 한 곳만 지어도 온 고을의 송사와 치안을 맡으며, 없으면 범죄가 늘고 송사를 열 수 없고 죄인이 달아나기도 합니다."},
	"demolish": {"icon": "🚜", "name": "쇠괭이(철거)", "desc": "기존 건축물이나 구획을 헐어 터를 비웁니다."}
}

func setup(tm: TimeManager, sim: SimulationCore, cam: CameraController = null, city: CityLayer = null, cit: CitizenManager = null) -> void:
	time_manager = tm
	simulation_core = sim
	camera = cam
	city_layer = city
	citizen_manager = cit

	_build_ui()

	if citizen_manager:
		if not citizen_manager.bandit_battle_started.is_connected(show_raid_alert_banner):
			citizen_manager.bandit_battle_started.connect(show_raid_alert_banner)
		if not citizen_manager.bandit_battle_ended.is_connected(func(_rep): hide_raid_alert_banner()):
			citizen_manager.bandit_battle_ended.connect(func(_rep): hide_raid_alert_banner())

	if time_manager:
		if not time_manager.time_changed.is_connected(_on_time_changed):
			time_manager.time_changed.connect(_on_time_changed)
		if not time_manager.speed_changed.is_connected(_on_speed_changed):
			time_manager.speed_changed.connect(_on_speed_changed)
		_on_time_changed(time_manager.current_year, time_manager.get_current_season(), time_manager.current_month, time_manager.current_day)

	if simulation_core:
		if not simulation_core.state_updated.is_connected(_on_state_updated):
			simulation_core.state_updated.connect(_on_state_updated)
		if not simulation_core.project_completed.is_connected(_on_project_completed):
			simulation_core.project_completed.connect(_on_project_completed)
		if not simulation_core.disaster_alert.is_connected(_on_disaster_alert):
			simulation_core.disaster_alert.connect(_on_disaster_alert)
		if not simulation_core.fire_outbreak.is_connected(Callable(self, "_on_fire_outbreak")):
			simulation_core.fire_outbreak.connect(Callable(self, "_on_fire_outbreak"))
		if not simulation_core.fire_extinguished.is_connected(Callable(self, "_on_fire_extinguished")):
			simulation_core.fire_extinguished.connect(Callable(self, "_on_fire_extinguished"))
		_on_state_updated(simulation_core.gold, simulation_core.rice, simulation_core.population, simulation_core.loyalty, simulation_core.flood_defense)

	if city_layer:
		if not city_layer.map_baking_started.is_connected(_on_map_baking_started):
			city_layer.map_baking_started.connect(_on_map_baking_started)
		if not city_layer.map_baking_completed.is_connected(_on_map_baking_completed):
			city_layer.map_baking_completed.connect(_on_map_baking_completed)

	set_selected_tool("inspect")

func _on_map_baking_started() -> void:
	if panel_baking_indicator == null:
		return
	if _baking_tween != null and _baking_tween.is_valid():
		_baking_tween.kill()
	panel_baking_indicator.visible = true
	_baking_tween = create_tween()
	_baking_tween.tween_property(panel_baking_indicator, "modulate:a", 1.0, 0.25)

func _on_map_baking_completed() -> void:
	if panel_baking_indicator == null:
		return
	if _baking_tween != null and _baking_tween.is_valid():
		_baking_tween.kill()
	_baking_tween = create_tween()
	_baking_tween.tween_property(panel_baking_indicator, "modulate:a", 0.0, 0.35)
	_baking_tween.tween_callback(func():
		if panel_baking_indicator != null:
			panel_baking_indicator.visible = false
	)

func _on_project_completed(_p_name: String) -> void:
	# 대역사 완공 보고는 김판관(TutorialGuide)이 전담하므로 HUD 토스트는 출력하지 않음
	pass

## 사건 발생(화재, 도적 침입, 맹호 습격, 수해 홍수, 기근 등) 전용 상단 팝업창 호출
func push_incident_alert(msg: String, target_world_pos: Vector2 = Vector2.ZERO) -> void:
	if top_alert_banner != null:
		top_alert_banner.push_alert(msg, target_world_pos)
	else:
		_show_toast(msg, "🚨")

## 이전 호환용 메서드: 정무 조언 및 완료 보고는 차단하고 사건 발생만 상단 팝업창으로 전달
func push_top_alert(msg: String, target_world_pos: Vector2 = Vector2.ZERO) -> void:
	# 정무 관련 조언과 모든 완료 보고는 김판관이 전담하므로 상단 팝업 배너에서 완전 배제
	for keyword: String in ["초야 인재", "인재 출현", "등용 가능", "호포책", "현륭원 친림", "서장대 훈련", "완공", "완수", "대역사", "실학 연구", "세자서연", "어명"]:
		if keyword in msg and not ("습격" in msg or "침입" in msg or "약탈" in msg):
			return
	push_incident_alert(msg, target_world_pos)

func _on_disaster_alert(msg: String) -> void:
	push_incident_alert(msg)

func _on_fire_outbreak(pos: Vector2i) -> void:
	var w_pos := Vector2.ZERO
	if city_layer != null:
		var elev: float = 0.0
		if citizen_manager != null and citizen_manager.grid != null and citizen_manager.grid.in_bounds(pos.x, pos.y):
			elev = float(citizen_manager.grid.grid[pos.y][pos.x].get("elevation", 0.0))
		w_pos = city_layer.cell_center(float(pos.x) + 0.5, float(pos.y) + 0.5, elev)

	var loc_desc: String = "민가 구역"
	if citizen_manager != null and citizen_manager.grid != null and citizen_manager.grid.in_bounds(pos.x, pos.y):
		var b_name: String = String(citizen_manager.grid.grid[pos.y][pos.x].get("building", ""))
		loc_desc = "공방 구역" if b_name.begins_with("ind") else ("저잣거리 상가" if b_name.begins_with("com") else "민가")

	show_fire_alert_banner(w_pos, loc_desc)
	push_incident_alert("🚨 [화마(火魔) 경보] %s에서 화재가 발생하였습니다! 멸화군을 파견하여 진화하십시오!" % loc_desc, w_pos)

func _on_fire_extinguished(pos: Vector2i) -> void:
	var w_pos := Vector2.ZERO
	if city_layer != null:
		var elev: float = 0.0
		if citizen_manager != null and citizen_manager.grid != null and citizen_manager.grid.in_bounds(pos.x, pos.y):
			elev = float(citizen_manager.grid.grid[pos.y][pos.x].get("elevation", 0.0))
		w_pos = city_layer.cell_center(float(pos.x) + 0.5, float(pos.y) + 0.5, elev)

	hide_fire_alert_banner()
	push_incident_alert("🚒 [화마 진압 완수] 멸화군과 백성들이 힘을 합쳐 화마를 완전히 진압하였습니다!", w_pos)

## 화재 긴급 경보 배너 표시
func show_fire_alert_banner(world_pos: Vector2, location_desc: String) -> void:
	_current_battle_loc_name = location_desc
	_current_battle_world_pos = world_pos
	if label_raid_alert:
		label_raid_alert.text = "🚨 [화마 발생] %s에서 화재가 발생하였습니다! 멸화군이 진화 중입니다!" % location_desc
	if banner_raid_alert:
		banner_raid_alert.visible = true

## 화재 긴급 경보 배너 숨김
func hide_fire_alert_banner() -> void:
	if not _is_battle_active:
		if banner_raid_alert:
			banner_raid_alert.visible = false
		if edge_battle_marker:
			edge_battle_marker.visible = false

## 긴급 경보 배너 표시 및 좌표 등록
func show_raid_alert_banner(world_pos: Vector2, location_name: String) -> void:
	_is_battle_active = true
	_current_battle_loc_name = location_name
	_current_battle_world_pos = world_pos
	if label_raid_alert:
		label_raid_alert.text = "🚨 [변란 발생] %s에서 반란군과 장용영의 교전이 벌어졌습니다!" % location_name
	if banner_raid_alert:
		banner_raid_alert.visible = true
	push_incident_alert("🚨 [변란 발생] %s에서 반란군과 장용영의 교전이 벌어졌습니다!" % location_name, world_pos)
	# 최초 1회 카메라 자동 포커스 (0.8초 CUBIC 보간)
	if camera != null and world_pos != Vector2.ZERO:
		camera.focus_on_coordinate(world_pos, true)

## 긴급 경보 배너 숨김
func hide_raid_alert_banner() -> void:
	_is_battle_active = false
	if banner_raid_alert:
		banner_raid_alert.visible = false
	if edge_battle_marker:
		edge_battle_marker.visible = false

## 화면 외곽 마커 위치 계산
func _update_edge_marker_position() -> void:
	if camera == null or edge_battle_marker == null:
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = vp_size * 0.5
	var target_screen: Vector2 = (_current_battle_world_pos - camera.position) * camera.zoom.x + center
	var dir: Vector2 = (target_screen - center).normalized()

	var margin: float = 40.0
	var min_x: float = margin
	var max_x: float = vp_size.x - margin - 80.0
	var min_y: float = margin + 50.0
	var max_y: float = vp_size.y - margin - 30.0

	var t_x: float = INF
	var t_y: float = INF
	if dir.x > 0.001:
		t_x = (max_x - center.x) / dir.x
	elif dir.x < -0.001:
		t_x = (min_x - center.x) / dir.x
	if dir.y > 0.001:
		t_y = (max_y - center.y) / dir.y
	elif dir.y < -0.001:
		t_y = (min_y - center.y) / dir.y
	var t_min: float = minf(t_x, t_y)
	var clamp_pos: Vector2 = center + dir * t_min
	clamp_pos.x = clampf(clamp_pos.x, min_x, max_x)
	clamp_pos.y = clampf(clamp_pos.y, min_y, max_y)
	edge_battle_marker.position = clamp_pos

## 상단 긴급 경보 배너 및 외곽 위험 지시 마커 UI 생성
func _build_raid_alert_ui() -> void:
	banner_raid_alert = PanelContainer.new()
	banner_raid_alert.name = "RaidAlertBanner"
	banner_raid_alert.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner_raid_alert.mouse_filter = Control.MOUSE_FILTER_STOP

	var b_sb := StyleBoxFlat.new()
	b_sb.bg_color = Color(0.38, 0.08, 0.08, 0.96)
	b_sb.border_color = Color(0.95, 0.45, 0.15, 0.95)
	b_sb.set_border_width_all(1)
	b_sb.set_corner_radius_all(6)
	b_sb.shadow_size = 6
	b_sb.shadow_color = Color(0, 0, 0, 0.6)
	b_sb.content_margin_left = 10
	b_sb.content_margin_right = 8
	b_sb.content_margin_top = 4
	b_sb.content_margin_bottom = 4
	banner_raid_alert.add_theme_stylebox_override("panel", b_sb)
	banner_raid_alert.visible = false
	if top_alert_stack != null:
		top_alert_stack.add_child(banner_raid_alert)
	else:
		add_child(banner_raid_alert)

	var b_hb := HBoxContainer.new()
	b_hb.add_theme_constant_override("separation", 8)
	banner_raid_alert.add_child(b_hb)

	label_raid_alert = Label.new()
	label_raid_alert.text = "[변란 발생] 팔달문 외곽에서 반란군과 장용영의 교전이 벌어졌습니다!"
	label_raid_alert.add_theme_color_override("font_color", Color(1.0, 0.92, 0.8))
	label_raid_alert.add_theme_font_size_override("font_size", 12)
	label_raid_alert.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_hb.add_child(label_raid_alert)

	btn_jump_battle = Button.new()
	btn_jump_battle.text = "위치 보기 🔍"
	btn_jump_battle.add_theme_font_size_override("font_size", 12)
	btn_jump_battle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var j_sb := StyleBoxFlat.new()
	j_sb.bg_color = Color(0.65, 0.15, 0.15, 0.9)
	j_sb.border_color = Color(1.0, 0.75, 0.3, 0.9)
	j_sb.set_border_width_all(1)
	j_sb.set_corner_radius_all(4)
	j_sb.content_margin_left = 6
	j_sb.content_margin_right = 6
	j_sb.content_margin_top = 2
	j_sb.content_margin_bottom = 2
	btn_jump_battle.add_theme_stylebox_override("normal", j_sb)
	btn_jump_battle.pressed.connect(func():
		if camera != null and _current_battle_world_pos != Vector2.ZERO:
			camera.focus_on_coordinate(_current_battle_world_pos, true)
			if city_layer != null and city_layer.has_method("ping_incident"):
				city_layer.call("ping_incident", _current_battle_world_pos, _current_battle_loc_name)
	)
	b_hb.add_child(btn_jump_battle)

	var btn_close := Button.new()
	btn_close.text = "✕"
	btn_close.add_theme_font_size_override("font_size", 11)
	btn_close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var c_sb := StyleBoxFlat.new()
	c_sb.bg_color = Color(0.2, 0.05, 0.05, 0.8)
	c_sb.set_corner_radius_all(3)
	c_sb.content_margin_left = 4
	c_sb.content_margin_right = 4
	btn_close.add_theme_stylebox_override("normal", c_sb)
	btn_close.pressed.connect(func(): banner_raid_alert.visible = false)
	b_hb.add_child(btn_close)

	edge_battle_marker = PanelContainer.new()
	var m_sb := StyleBoxFlat.new()
	m_sb.bg_color = Color(0.85, 0.12, 0.12, 0.95)
	m_sb.border_color = Color(1.0, 0.9, 0.35, 1.0)
	m_sb.set_border_width_all(1)
	m_sb.set_corner_radius_all(10)
	m_sb.shadow_size = 5
	m_sb.shadow_color = Color(0, 0, 0, 0.6)
	m_sb.content_margin_left = 8
	m_sb.content_margin_right = 8
	m_sb.content_margin_top = 3
	m_sb.content_margin_bottom = 3
	edge_battle_marker.add_theme_stylebox_override("panel", m_sb)
	edge_battle_marker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	edge_battle_marker.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if camera != null and _current_battle_world_pos != Vector2.ZERO:
				camera.focus_on_coordinate(_current_battle_world_pos, true)
	)
	label_edge_marker = Label.new()
	label_edge_marker.text = "⚔️ 적 출몰!"
	label_edge_marker.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	label_edge_marker.add_theme_font_size_override("font_size", 11)
	label_edge_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge_battle_marker.add_child(label_edge_marker)
	edge_battle_marker.visible = false
	add_child(edge_battle_marker)


func _build_top_alert_stack() -> void:
	top_alert_stack = VBoxContainer.new()
	top_alert_stack.name = "TopAlertStack"
	# 화면 우측 상단 고정 — 왼쪽 살피기/김판관 패널과의 겹침 방지
	top_alert_stack.anchor_left = 1.0
	top_alert_stack.anchor_right = 1.0
	top_alert_stack.offset_left = -400.0   # 패널 너비 400px
	top_alert_stack.offset_right = -12.0   # 우측 여백 12px
	top_alert_stack.offset_top = 56.0      # HUD 헤더 아래
	top_alert_stack.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top_alert_stack.size_flags_horizontal = Control.SIZE_SHRINK_END
	top_alert_stack.add_theme_constant_override("separation", 6)
	top_alert_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_alert_stack)

func _build_ui() -> void:
	for ch in get_children():
		ch.queue_free()

	_build_top_bar()
	_build_top_alert_stack()
	_build_raid_alert_ui()
	_build_famine_alert_ui()
	_build_toast_banner()
	_build_tool_status_bar()
	_build_compass_controls()
	_build_baking_indicator_ui()

## 좌측 하단 계절 베이킹 인디케이터 UI 생성
func _build_baking_indicator_ui() -> void:
	panel_baking_indicator = PanelContainer.new()
	panel_baking_indicator.name = "BakingIndicatorPanel"
	panel_baking_indicator.anchor_left = 0.0
	panel_baking_indicator.anchor_top = 1.0
	panel_baking_indicator.anchor_right = 0.0
	panel_baking_indicator.anchor_bottom = 1.0
	panel_baking_indicator.offset_left = 16.0
	panel_baking_indicator.offset_bottom = -16.0
	panel_baking_indicator.offset_right = 260.0
	panel_baking_indicator.offset_top = -54.0

	var b_sb := StyleBoxFlat.new()
	b_sb.bg_color = Color(0.12, 0.10, 0.08, 0.90)
	b_sb.border_color = Color(0.72, 0.62, 0.45, 0.85)
	b_sb.set_border_width_all(1)
	b_sb.set_corner_radius_all(6)
	b_sb.shadow_size = 4
	b_sb.shadow_color = Color(0, 0, 0, 0.5)
	b_sb.content_margin_left = 12
	b_sb.content_margin_right = 12
	b_sb.content_margin_top = 6
	b_sb.content_margin_bottom = 6
	panel_baking_indicator.add_theme_stylebox_override("panel", b_sb)
	panel_baking_indicator.visible = false
	panel_baking_indicator.modulate.a = 0.0
	panel_baking_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel_baking_indicator)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_baking_indicator.add_child(hb)

	label_baking_indicator = Label.new()
	label_baking_indicator.text = "🖌️ 화성 계절 풍광 갱신 중..."
	label_baking_indicator.add_theme_color_override("font_color", Color(0.92, 0.88, 0.80))
	label_baking_indicator.add_theme_font_size_override("font_size", 13)
	label_baking_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(label_baking_indicator)

# ------------------------------------------------------------ 상단 HUD 헤더 바
func _build_top_bar() -> void:
	top_bar = PanelContainer.new()
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.offset_left = 8.0
	top_bar.offset_right = -8.0
	top_bar.offset_top = 3.0
	top_bar.offset_bottom = 49.0
	top_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.07, 0.05, 0.97) # 옻칠 목재 다크
	sb.border_color = Color(0.45, 0.30, 0.15, 0.95)
	sb.border_width_bottom = 2
	sb.shadow_color = Color(0, 0, 0, 0.7)
	sb.shadow_size = 8
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	top_bar.add_theme_stylebox_override("panel", sb)
	add_child(top_bar)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.add_theme_constant_override("separation", 8)
	top_bar.add_child(hbox)

	# 1. 연호/계절 뱃지 (단청 붉은색 캡슐)
	var badge_panel := PanelContainer.new()
	var b_sb := StyleBoxFlat.new()
	b_sb.bg_color = Color(0.50, 0.10, 0.10, 1.0) # 단청 주홍
	b_sb.border_color = Color(0.85, 0.60, 0.05, 1.0) # 금박 테두리
	b_sb.set_border_width_all(1)
	b_sb.set_corner_radius_all(12)
	b_sb.content_margin_left = 9
	b_sb.content_margin_right = 9
	b_sb.content_margin_top = 3
	b_sb.content_margin_bottom = 3
	badge_panel.add_theme_stylebox_override("panel", b_sb)
	hbox.add_child(badge_panel)

	label_season = Label.new()
	label_season.text = "🌸 정조 원년(1776) 봄 [1개월째]"
	label_season.add_theme_color_override("font_color", Color(0.99, 0.94, 0.54)) # 금박 황색
	label_season.add_theme_font_size_override("font_size", 13)
	label_season.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_panel.add_child(label_season)

	# 1-1. 난이도 뱃지
	var diff_badge := PanelContainer.new()
	var d_sb := StyleBoxFlat.new()
	var cur_diff: DifficultyManager.Difficulty = DifficultyManager.get_difficulty()
	var diff_col: Color = Color(0.1, 0.45, 0.2, 1.0)
	match cur_diff:
		DifficultyManager.Difficulty.NORMAL: diff_col = Color(0.1, 0.3, 0.6, 1.0)
		DifficultyManager.Difficulty.HARD: diff_col = Color(0.65, 0.15, 0.15, 1.0)
	d_sb.bg_color = diff_col
	d_sb.border_color = Color(0.85, 0.70, 0.35, 0.9)
	d_sb.set_border_width_all(1)
	d_sb.set_corner_radius_all(10)
	d_sb.content_margin_left = 7
	d_sb.content_margin_right = 7
	d_sb.content_margin_top = 2
	d_sb.content_margin_bottom = 2
	diff_badge.add_theme_stylebox_override("panel", d_sb)
	diff_badge.tooltip_text = DifficultyManager.get_difficulty_desc()
	hbox.add_child(diff_badge)

	var label_diff := Label.new()
	label_diff.text = DifficultyManager.get_difficulty_name().split(" ")[0]
	label_diff.add_theme_color_override("font_color", Color(0.99, 0.95, 0.8))
	label_diff.add_theme_font_size_override("font_size", 12)
	diff_badge.add_child(label_diff)

	# 2. 심시티 2000 R-C-A 3색 수직 막대
	var rca_box := PanelContainer.new()
	var r_sb := StyleBoxFlat.new()
	r_sb.bg_color = Color(0.07, 0.05, 0.03, 0.95)
	r_sb.border_color = Color(0.48, 0.32, 0.16, 0.9)
	r_sb.set_border_width_all(1)
	r_sb.set_corner_radius_all(4)
	r_sb.content_margin_left = 5
	r_sb.content_margin_right = 5
	r_sb.content_margin_top = 2
	r_sb.content_margin_bottom = 2
	rca_box.add_theme_stylebox_override("panel", r_sb)
	rca_box.tooltip_text = "주거·상업·농업 구획 수요 지수 (누르면 호조 조세 조율)"
	rca_box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	rca_box.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			quick_action_requested.emit("tax")
	)
	hbox.add_child(rca_box)

	var rca_hb := HBoxContainer.new()
	rca_hb.add_theme_constant_override("separation", 5)
	rca_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rca_box.add_child(rca_hb)

	bar_res = _create_rci_bar(rca_hb, "주", Color(0.06, 0.72, 0.51))
	bar_com = _create_rci_bar(rca_hb, "상", Color(0.06, 0.65, 0.91))
	bar_agr = _create_rci_bar(rca_hb, "농", Color(0.96, 0.62, 0.07))

	# 좌측과 중앙 상태바 사이 여백 스페이서
	var spacer1 := Control.new()
	spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(spacer1)

	# 3. 중앙 상태바 (국고/군량/인구/민심/왕권/치수/성곽)
	var res_hb := HBoxContainer.new()
	res_hb.add_theme_constant_override("separation", 8)
	res_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(res_hb)

	label_gold = _create_res_label(res_hb, "🪙", "2,500", Color(0.99, 0.88, 0.28), "상평통보 국고", "stat_gold", "icon_gold")

	# 군량미 + [교역] 미니 버튼 (붉은색 지정 영역: 2pt 확대)
	var rice_hb := HBoxContainer.new()
	rice_hb.add_theme_constant_override("separation", 4)
	rice_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	res_hb.add_child(rice_hb)
	label_rice = _create_res_label(rice_hb, "🌾", "1,600", Color(0.52, 0.94, 0.67), "군량미", "stat_rice", "icon_grain")
	var btn_trade := Button.new()
	btn_trade.text = "교역"
	btn_trade.custom_minimum_size = Vector2(36, 24)
	btn_trade.add_theme_font_size_override("font_size", 12)
	btn_trade.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ThemeManager.bind_button_micro_interaction(btn_trade)
	var t_sb := StyleBoxFlat.new()
	t_sb.bg_color = Color(0.06, 0.35, 0.20, 0.9)
	t_sb.border_color = Color(0.15, 0.65, 0.40, 0.9)
	t_sb.set_border_width_all(1)
	t_sb.set_corner_radius_all(3)
	t_sb.content_margin_left = 5
	t_sb.content_margin_right = 5
	t_sb.content_margin_top = 2
	t_sb.content_margin_bottom = 2
	btn_trade.add_theme_stylebox_override("normal", t_sb)
	var t_hsb = t_sb.duplicate()
	t_hsb.border_color = Color(0.98, 0.85, 0.35)
	btn_trade.add_theme_stylebox_override("hover", t_hsb)
	btn_trade.pressed.connect(func(): quick_action_requested.emit("trade"))
	rice_hb.add_child(btn_trade)

	label_pop = _create_res_label(res_hb, "👥", "120", Color(0.49, 0.83, 0.99), "화성 신도시 인구", "stat_pop", "icon_pop")
	label_loyalty = _create_res_label(res_hb, "❤️", "88%", Color(0.99, 0.64, 0.69), "백성 충성도", "stat_loyalty", "icon_loyalty")
	label_authority = _create_res_label(res_hb, "👑", "70", Color(0.85, 0.71, 0.99), "왕권 및 국방력", "stat_authority", "icon_royal")
	label_flood = _create_res_label(res_hb, "🌊", "0%", Color(0.37, 0.92, 0.83), "수원천 치수 방재율 (석축제방, 수문, 만석거 축조 시 상승)", "stat_flood")

	# 성곽 완공도 패널
	var fort_panel := PanelContainer.new()
	var f_sb := StyleBoxFlat.new()
	f_sb.bg_color = Color(0.07, 0.05, 0.04, 0.9)
	f_sb.border_color = Color(0.49, 0.34, 0.20, 0.8)
	f_sb.set_border_width_all(1)
	f_sb.set_corner_radius_all(3)
	f_sb.content_margin_left = 5
	f_sb.content_margin_right = 5
	f_sb.content_margin_top = 2
	f_sb.content_margin_bottom = 2
	fort_panel.add_theme_stylebox_override("panel", f_sb)
	fort_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	fort_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	fort_panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var pc = panel_controller
			if not pc and get_parent() and get_parent().has_node("Panels"):
				pc = get_parent().get_node("Panels")
			if pc and pc.has_method("open_action_modal"):
				pc.open_action_modal("wall_repair")
	)
	res_hb.add_child(fort_panel)
	panel_fortress = fort_panel

	var fort_hb := HBoxContainer.new()
	fort_hb.add_theme_constant_override("separation", 3)
	fort_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fort_panel.add_child(fort_hb)
	var fort_icon := Label.new()
	fort_icon.text = "🏯"
	fort_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fort_hb.add_child(fort_icon)
	label_fortress = Label.new()
	label_fortress.text = "0%"
	label_fortress.add_theme_color_override("font_color", Color(0.98, 0.80, 0.08))
	label_fortress.add_theme_font_size_override("font_size", 13)
	label_fortress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fort_hb.add_child(label_fortress)

	# 상태바와 우측 게임 설정 사이 여백 스페이서
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(spacer2)

	# 4. 우측: 게임 시스템 설정 (⚙️ 게임 설정, 🎬 인트로, 🏠 타이틀 - 붉은색 지정 영역: 2pt 확대)
	var settings_hb := HBoxContainer.new()
	settings_hb.add_theme_constant_override("separation", 4)
	hbox.add_child(settings_hb)

	_create_quick_btn(settings_hb, "⚙️ 환경 설정", Color(0.25, 0.16, 0.11), Color(0.85, 0.65, 0.35), "game_settings")
	_create_quick_btn(settings_hb, "🎬 첫 영상", Color(0.20, 0.16, 0.28), Color(0.65, 0.55, 0.85), "intro_video")
	_create_quick_btn(settings_hb, "🏠 첫 화면", Color(0.18, 0.12, 0.08), Color(0.85, 0.65, 0.35), "title_screen")

	# 구분자
	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(4, 20)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(sep)

	# 5. 우측 끝: 배속 제어 버튼 묶음 (붉은색 지정 영역: 2pt 확대)
	var speed_hb := HBoxContainer.new()
	speed_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	speed_hb.add_theme_constant_override("separation", 2)
	hbox.add_child(speed_hb)

	btn_pause = _create_speed_btn(speed_hb, "❚❚", 0)
	btn_normal = _create_speed_btn(speed_hb, "▶", 1)
	btn_fast = _create_speed_btn(speed_hb, "▶▶", 2)
	btn_ultra = _create_speed_btn(speed_hb, "▶▶▶", 3)
	btn_normal.modulate = Color(1.0, 0.85, 0.40)

# ------------------------------------------------------------ 좌측 상단 도구 상태 바 (붉은색 지정 영역: 2pt 확대)
func _build_tool_status_bar() -> void:
	tool_bar_panel = PanelContainer.new()
	tool_bar_panel.offset_left = 14.0
	tool_bar_panel.offset_top = 56.0
	tool_bar_panel.offset_right = 360.0
	tool_bar_panel.offset_bottom = 108.0
	tool_bar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.07, 0.05, 0.94)
	sb.border_color = Color(0.43, 0.27, 0.14, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	tool_bar_panel.add_theme_stylebox_override("panel", sb)
	add_child(tool_bar_panel)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tool_bar_panel.add_child(hb)

	tool_bar_icon = Label.new()
	tool_bar_icon.text = "🔍"
	tool_bar_icon.add_theme_font_size_override("font_size", 22)
	tool_bar_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(tool_bar_icon)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)

	tool_bar_title = Label.new()
	tool_bar_title.text = "살피기"
	tool_bar_title.add_theme_color_override("font_color", Color(0.99, 0.85, 0.40))
	tool_bar_title.add_theme_font_size_override("font_size", 14)
	tool_bar_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tool_bar_title)

	tool_bar_desc = Label.new()
	tool_bar_desc.text = "가운데 바퀴를 누른 채 끌어 지도 이동, 바퀴를 굴려 확대·축소"
	tool_bar_desc.add_theme_color_override("font_color", Color(0.80, 0.76, 0.70))
	tool_bar_desc.add_theme_font_size_override("font_size", 12)
	tool_bar_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tool_bar_desc)

# ------------------------------------------------------------ 우측 상단 플로팅 나침반 & 뷰포트 조작 패널 (붉은색 지정 영역: 2pt 확대)
func _build_compass_controls() -> void:
	compass_panel = PanelContainer.new()
	# 우측 하단 고정 — 알림 배너와 겹치지 않도록 하단 바 바로 위 배치
	compass_panel.anchor_left = 1.0
	compass_panel.anchor_right = 1.0
	compass_panel.anchor_top = 1.0
	compass_panel.anchor_bottom = 1.0
	compass_panel.offset_left = -190.0
	compass_panel.offset_right = -14.0
	compass_panel.offset_top = -166.0   # 하단 바(~56px) + 패널 높이(~96px) + 여백(14px)
	compass_panel.offset_bottom = -70.0  # 하단 바 높이(~56px) + 여백(14px)
	compass_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	compass_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.10, 0.08, 0.95)
	sb.border_color = Color(0.48, 0.32, 0.18, 0.95)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 6
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	compass_panel.add_theme_stylebox_override("panel", sb)
	add_child(compass_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	compass_panel.add_child(vb)

	# 고정 시점 방위 표시 (4방향 회전 제거: 남동쪽에서 북서쪽을 바라보는 단일 시점)
	compass_label = Label.new()
	compass_label.text = "▲ 서·팔달산 / ▼ 동·창룡문"
	compass_label.tooltip_text = "고정 시점: 성의 남동쪽 외곽에서 북서쪽을 바라봅니다."
	compass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass_label.add_theme_color_override("font_color", Color(0.99, 0.85, 0.40))
	compass_label.add_theme_font_size_override("font_size", 12)
	compass_label.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(compass_label)

	# 카메라 제어 버튼 행 (✋, +, -, 🎯, 🚜)
	var cam_hb := HBoxContainer.new()
	cam_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	cam_hb.add_theme_constant_override("separation", 4)
	vb.add_child(cam_hb)

	btn_pan = _create_cam_icon_btn(cam_hb, "✋", "화면 이동", func(): pan_toggle_requested.emit())
	_create_cam_icon_btn(cam_hb, "+", "확대", func(): zoom_in_requested.emit())
	_create_cam_icon_btn(cam_hb, "-", "축소", func(): zoom_out_requested.emit())
	_create_cam_icon_btn(cam_hb, "🎯", "중앙 복귀", func(): center_view_requested.emit())
	btn_demolish = _create_cam_icon_btn(cam_hb, "🚜", "철거 불도저", func(): tool_selected.emit("demolish"), Color(0.45, 0.12, 0.08))

# ------------------------------------------------------------ 기근(Famine) 경보 배너
func _build_famine_alert_ui() -> void:
	banner_famine = PanelContainer.new()
	banner_famine.name = "FamineAlertBanner"
	banner_famine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner_famine.mouse_filter = Control.MOUSE_FILTER_STOP

	var f_sb := StyleBoxFlat.new()
	f_sb.bg_color = Color(0.50, 0.22, 0.04, 0.97)
	f_sb.border_color = Color(1.0, 0.70, 0.10, 0.97)
	f_sb.set_border_width_all(2)
	f_sb.set_corner_radius_all(6)
	f_sb.shadow_size = 8
	f_sb.shadow_color = Color(0, 0, 0, 0.7)
	f_sb.content_margin_left = 12
	f_sb.content_margin_right = 8
	f_sb.content_margin_top = 4
	f_sb.content_margin_bottom = 4
	banner_famine.add_theme_stylebox_override("panel", f_sb)
	banner_famine.visible = false
	if top_alert_stack != null:
		top_alert_stack.add_child(banner_famine)
	else:
		add_child(banner_famine)

	var f_hb := HBoxContainer.new()
	f_hb.add_theme_constant_override("separation", 8)
	banner_famine.add_child(f_hb)

	label_famine = Label.new()
	label_famine.text = "[기근 발생] 식량이 바닥나 백성들이 굶주리고 흩어지고 있습니다!"
	label_famine.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	label_famine.add_theme_font_size_override("font_size", 12)
	label_famine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_famine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f_hb.add_child(label_famine)

	var btn_close_famine := Button.new()
	btn_close_famine.text = "✕"
	btn_close_famine.add_theme_font_size_override("font_size", 11)
	btn_close_famine.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var fc_sb := StyleBoxFlat.new()
	fc_sb.bg_color = Color(0.25, 0.10, 0.02, 0.85)
	fc_sb.set_corner_radius_all(3)
	fc_sb.content_margin_left = 4
	fc_sb.content_margin_right = 4
	btn_close_famine.add_theme_stylebox_override("normal", fc_sb)
	btn_close_famine.pressed.connect(func():
		famine_dismissed = true
		banner_famine.visible = false
	)
	f_hb.add_child(btn_close_famine)

# ------------------------------------------------------------ 토스트 배너
func _build_toast_banner() -> void:
	top_alert_banner = TopAlertBanner.new()
	top_alert_banner.name = "TopAlertBanner"
	top_alert_banner.location_view_requested.connect(_on_location_view_requested)
	if top_alert_stack != null:
		top_alert_stack.add_child(top_alert_banner)
	else:
		add_child(top_alert_banner)

	toast_panel = PanelContainer.new()
	toast_panel.visible = false
	# 우측 하단 영역 — TopAlertStack 바로 아래 위치 (스택과 겹치지 않도록 offset_top 여유)
	toast_panel.anchor_left = 1.0
	toast_panel.anchor_right = 1.0
	toast_panel.offset_left = -400.0
	toast_panel.offset_right = -12.0
	toast_panel.offset_top = 56.0
	toast_panel.offset_bottom = 96.0
	toast_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.45, 0.11, 0.08, 0.96) # 단청 붉은색
	sb.border_color = Color(0.96, 0.62, 0.07, 1.0) # 황금 테두리
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.7)
	sb.shadow_size = 8
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	toast_panel.add_theme_stylebox_override("panel", sb)
	add_child(toast_panel)

	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_color", Color.WHITE)
	toast_label.add_theme_font_size_override("font_size", 13)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_child(toast_label)

func _on_location_view_requested(world_pos: Vector2) -> void:
	if not GameSettings.is_incident_goto_enabled():
		return
	if camera != null and world_pos != Vector2.ZERO:
		camera.focus_on_coordinate(world_pos, true)
	if citizen_layer != null and citizen_layer.has_method("ping_incident"):
		citizen_layer.call("ping_incident", world_pos, "사건 현장")

func _show_toast(msg: String, icon: String = "📢") -> void:
	var full_msg := "%s %s" % [icon, msg] if icon != "" else msg
	if not toast_label or not toast_panel:
		return
	toast_label.text = full_msg
	toast_panel.visible = true
	toast_panel.modulate.a = 1.0
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(2.5)
	toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.5)
	toast_tween.tween_callback(func():
		if toast_panel:
			toast_panel.visible = false
	)

# ------------------------------------------------------------ 도구 상태 업데이트
func set_selected_tool(tool_id: String) -> void:
	if not tool_bar_icon or not tool_bar_title or not tool_bar_desc:
		return
	var info: Dictionary = TOOL_INFOS.get(tool_id, {"icon": "🛠️", "name": "%s 도구" % tool_id, "desc": "화성 신도시를 건설합니다."})
	tool_bar_icon.text = info.get("icon", "🛠️")
	tool_bar_title.text = info.get("name", tool_id)
	tool_bar_desc.text = info.get("desc", "")

# ------------------------------------------------------------ 데이터 업데이트 바인딩
func _on_time_changed(year: int, season: String, _month: int, _day: int) -> void:
	var reign = year - 1776 + 1
	var turn_num = simulation_core.turn if simulation_core else 1
	var s_icon = "🌸"
	if season == "여름": s_icon = "☀️"
	elif season == "가을": s_icon = "🍁"
	elif season == "겨울": s_icon = "❄️"

	if label_season:
		label_season.text = "%s 정조 %d년(%d) %s [%d개월째]" % [s_icon, reign, year, season, turn_num]

## PORT-TRACE [자원 실시간 동기화]: 사용자 제보 — "헤더의 금화/식량이 실제 보유량과 다르고, 건설 즉시
## 차감이 안 보인다". 비용을 빼는 곳(터 착공·조정 명령·교역·세자서연 등)이 여러 곳이라 일부는
## state_updated 신호를 보내지 않았고, 특히 일시정지 중에는 틱 신호도 없어 헤더가 옛 값에 머물렀다.
## 신호에만 기대지 않고 매 프레임 실제 값을 읽어, 달라졌을 때만 라벨을 고친다(비용 거의 0).
var _last_res_sig := ""

func _process(_delta: float) -> void:
	# 교전 위치 추적 및 화면 외곽 위험 지시 마커 갱신
	if _is_battle_active and citizen_manager != null and citizen_manager.is_bandit_battle_active():
		_current_battle_world_pos = citizen_manager.get_current_battle_world_pos()
		if camera != null:
			var in_view: bool = camera.is_world_pos_in_view(_current_battle_world_pos)
			if not in_view:
				if edge_battle_marker:
					edge_battle_marker.visible = true
					_update_edge_marker_position()
			else:
				if edge_battle_marker:
					edge_battle_marker.visible = false
	else:
		if edge_battle_marker and edge_battle_marker.visible:
			edge_battle_marker.visible = false

	if simulation_core == null:
		return
	var s := simulation_core
	# 기근 배너 자동 표시/숨김 (턴 단위 ✕ 닫기 리셋)
	var cur_turn: int = s.turn if "turn" in s else 1
	if cur_turn != famine_last_turn:
		famine_last_turn = cur_turn
		famine_dismissed = false
	if banner_famine:
		var is_famine: bool = bool(s.famine_active) if "famine_active" in s else false
		banner_famine.visible = is_famine and not famine_dismissed
	var sig := "%d|%d|%d|%d|%d|%d|%d" % [s.gold, s.rice, s.population, s.loyalty, s.flood_defense, s.authority, s.fortress_progress]
	if sig != _last_res_sig:
		_last_res_sig = sig
		_on_state_updated(s.gold, s.rice, s.population, s.loyalty, s.flood_defense)

func _on_speed_changed(mode: int) -> void:
	btn_pause.modulate = Color(1.0, 0.85, 0.4) if mode == 0 else Color.WHITE
	btn_normal.modulate = Color(1.0, 0.85, 0.4) if mode == 1 else Color.WHITE
	btn_fast.modulate = Color(1.0, 0.85, 0.4) if mode == 2 else Color.WHITE
	btn_ultra.modulate = Color(1.0, 0.85, 0.4) if mode == 3 else Color.WHITE

func _on_state_updated(gold: int, rice: int, pop: int, loyalty: int, flood_defense: int) -> void:
	if label_gold:
		_check_and_flash_stat("gold", label_gold, gold)
		label_gold.text = _format_num(gold)
	if label_rice:
		_check_and_flash_stat("rice", label_rice, rice)
		label_rice.text = _format_num(rice)
		var p_hb: Node = label_rice.get_parent()
		if p_hb is Control:
			var irr_str: String = IrrigationManager.get_hud_capacity_string()
			(p_hb as Control).tooltip_text = "군량미\n%s\n(누르면 관련 작업 열기)" % irr_str
	if label_pop:
		_check_and_flash_stat("pop", label_pop, pop)
		label_pop.text = _format_num(pop)
	if label_loyalty:
		_check_and_flash_stat("loyalty", label_loyalty, loyalty)
		label_loyalty.text = "%d%%" % loyalty
	if label_authority:
		var auth: int = simulation_core.authority if simulation_core else 70
		_check_and_flash_stat("authority", label_authority, auth)
		label_authority.text = str(auth)
	if label_flood: label_flood.text = "%d%%" % flood_defense
	var def_power: int = CityStats.get_fortress_defense_power()
	var atk_power: int = CityStats.get_military_attack_power()
	if label_fortress: label_fortress.text = "%d%% (방호 %d)" % [simulation_core.fortress_progress, def_power]
	if panel_fortress:
		var base_tip: String = "성곽 완공도 %d%%" % simulation_core.fortress_progress
		if city_layer and city_layer.grid and city_layer.grid.wall_loop_validator:
			var loop_res: Dictionary = city_layer.grid.wall_loop_validator.validate_loop(city_layer.grid)
			base_tip = loop_res.get("tooltip_message", base_tip)
		var ws_cnt: int = BuildingManager.active_workshop_count
		var turn_num: int = simulation_core.turn if simulation_core != null else 1
		var ws_status: String = ""
		if ws_cnt <= 0:
			if turn_num <= WorkshopManager.GRACE_PERIOD_TURNS:
				ws_status = "• 무기 조달: 🛡️ 건립 유예 중 (공방 0개 / 4개월까지 보호)"
			else:
				ws_status = "• 무기 조달: ⚠️ [결핍] 공방 전무 (군사력 -50% 감산)"
		else:
			var buff_pct: float = WorkshopManager.get_military_buff_percent(ws_cnt, turn_num)
			ws_status = "• 무기 조달: ⚒️ 공방 %d개소 가동 중 (+%.2f%% 군사력 가산)" % [ws_cnt, buff_pct]

		panel_fortress.tooltip_text = "%s\n• 성 방호력(체력/내구도): %d점\n• 장용영 군사 공격력: %d점\n%s\n(누르면 성곽 보수 및 서장대 야조 훈련 결단)" % [
			base_tip, def_power, atk_power, ws_status
		]

	# 도적 침략 및 소굴 토벌 버튼 시각 상태 업데이트
	if btn_bandit and simulation_core:
		if simulation_core.bandit_active:
			btn_bandit.text = "🚨 화적 소탕!"
			btn_bandit.modulate = Color(1.0, 0.35, 0.35)
		elif simulation_core.bandit_suppression_cooldown > 0.0:
			btn_bandit.text = "🛡️ 소굴 진압됨"
			btn_bandit.modulate = Color(0.65, 0.95, 0.70)
		else:
			btn_bandit.text = "⚔️ 도적 토벌"
			btn_bandit.modulate = Color.WHITE

	# R-C-A 수요 바 게이지 업데이트
	if bar_res: bar_res.value = clamp((simulation_core.demand_res + 100) / 2.0, 5.0, 100.0)
	if bar_com:
		bar_com.value = clamp((simulation_core.demand_com + 100) / 2.0, 5.0, 100.0)
		var total_s: int = BuildingManager.active_market_shop_count
		var total_w: int = BuildingManager.active_workshop_count
		var cov_s: int = mini(total_s, total_w * 10)
		bar_com.tooltip_text = "상업 수요\n%s" % WorkshopManager.get_market_buff_tooltip_text(cov_s, total_s)
	if bar_agr: bar_agr.value = clamp((simulation_core.demand_agr + 100) / 2.0, 5.0, 100.0)

# ------------------------------------------------------------ 헬퍼 함수들
func _create_rci_bar(parent: Node, label_txt: String, fill_color: Color) -> ProgressBar:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(vb)

	var pbar := ProgressBar.new()
	pbar.custom_minimum_size = Vector2(8, 26)
	pbar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	pbar.show_percentage = false
	pbar.value = 50.0
	pbar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0.11, 0.08, 0.06, 1.0)
	bg_sb.border_color = Color(0.35, 0.24, 0.15, 1.0)
	bg_sb.set_border_width_all(1)
	pbar.add_theme_stylebox_override("background", bg_sb)

	var fg_sb := StyleBoxFlat.new()
	fg_sb.bg_color = fill_color
	pbar.add_theme_stylebox_override("fill", fg_sb)
	vb.add_child(pbar)

	var l := Label.new()
	l.text = label_txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", fill_color)
	l.add_theme_font_size_override("font_size", 9)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(l)

	return pbar

func _create_quick_btn(parent: Node, text: String, bg_color: Color, border_color: Color, action_id: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 13)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_button_styles(b, bg_color, border_color)
	ThemeManager.bind_button_micro_interaction(b)
	b.pressed.connect(func(): quick_action_requested.emit(action_id))
	parent.add_child(b)
	return b

func _apply_button_styles(b: Button, bg_color: Color, border_color: Color) -> void:
	# Normal
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	b.add_theme_stylebox_override("normal", sb)

	# Hover
	var h_sb := StyleBoxFlat.new()
	h_sb.bg_color = bg_color.lightened(0.25)
	h_sb.border_color = Color(0.98, 0.85, 0.35) # 황금 테두리 강조
	h_sb.set_border_width_all(2)
	h_sb.set_corner_radius_all(4)
	h_sb.content_margin_left = 6
	h_sb.content_margin_right = 6
	h_sb.content_margin_top = 4
	h_sb.content_margin_bottom = 4
	b.add_theme_stylebox_override("hover", h_sb)

	# Pressed
	var p_sb := StyleBoxFlat.new()
	p_sb.bg_color = bg_color.darkened(0.2)
	p_sb.border_color = Color(0.98, 0.85, 0.35)
	p_sb.set_border_width_all(2)
	p_sb.set_corner_radius_all(4)
	p_sb.content_margin_left = 6
	p_sb.content_margin_right = 6
	p_sb.content_margin_top = 5
	p_sb.content_margin_bottom = 3
	b.add_theme_stylebox_override("pressed", p_sb)

	b.add_theme_color_override("font_color", Color(0.98, 0.94, 0.85))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.55))

func _create_res_label(parent: Node, icon: String, val: String, color: Color, tooltip: String, action: String = "", ui_icon_id: String = "") -> Label:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.tooltip_text = tooltip
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(hb)
	if action != "":
		# 누르면 이 지표와 관련된 작업 팝업(PanelController 'stat_*')이 열린다
		hb.tooltip_text = tooltip + "\n(누르면 관련 작업 열기)"
		hb.mouse_filter = Control.MOUSE_FILTER_STOP
		hb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hb.mouse_entered.connect(func(): hb.modulate = Color(1.35, 1.25, 1.05))
		hb.mouse_exited.connect(func(): hb.modulate = Color.WHITE)
		hb.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				quick_action_requested.emit(action)
		)

	var icon_loaded: bool = false
	if ui_icon_id != "":
		var tex: Texture2D = SpriteCacheManager.get_or_create_texture("ui", ui_icon_id, Vector2i(24, 24))
		if tex != null:
			var tex_rect := TextureRect.new()
			tex_rect.texture = tex
			tex_rect.custom_minimum_size = Vector2(20, 20)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(tex_rect)
			icon_loaded = true

	if not icon_loaded:
		var ic := Label.new()
		ic.text = icon
		ic.add_theme_font_size_override("font_size", 13)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(ic)

	var l := Label.new()
	l.text = val
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 16)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(l)

	if action != "":
		_base_stat_colors[action] = color
	return l

func _check_and_flash_stat(stat_key: String, label: Label, new_val: int) -> void:
	if label == null:
		return
	if not _last_stat_values.has(stat_key):
		_last_stat_values[stat_key] = new_val
		return

	var old_val: int = int(_last_stat_values[stat_key])
	if new_val == old_val:
		return

	_last_stat_values[stat_key] = new_val

	# 수치 증감에 따른 0.3초 마이크로 플래시 (#2E8B57 증가, #C3423F 감소)
	var flash_col: Color = Color("2E8B57") if new_val > old_val else Color("C3423F")
	label.add_theme_color_override("font_color", flash_col)

	var old_tw: Tween = _stat_tweens.get(stat_key) as Tween
	if old_tw != null and old_tw.is_running():
		old_tw.kill()

	var base_col: Color = _base_stat_colors.get("stat_" + stat_key, Color.WHITE)
	var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "theme_override_colors/font_color", base_col, 0.3)
	_stat_tweens[stat_key] = tw

func _create_speed_btn(parent: Node, txt: String, mode: int) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(34, 28)
	b.tooltip_text = ["일시정지 (0배속)", "보통 (1배속)", "빠르게 (2배속)", "매우 빠르게 (3배속)"][clampi(mode, 0, 3)]
	b.add_theme_font_size_override("font_size", 12)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_button_styles(b, Color(0.18, 0.12, 0.08), Color(0.48, 0.32, 0.18))
	ThemeManager.bind_button_micro_interaction(b)
	b.pressed.connect(func():
		if time_manager:
			time_manager.set_speed(mode as TimeManager.SpeedMode)
	)
	parent.add_child(b)
	return b

func _create_cam_icon_btn(parent: Node, icon_txt: String, tooltip: String, cb: Callable, bg_color: Color = Color(0.20, 0.14, 0.10)) -> Button:
	var b := Button.new()
	b.text = icon_txt
	b.tooltip_text = tooltip
	b.custom_minimum_size = Vector2(32, 30)
	b.add_theme_font_size_override("font_size", 13)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_button_styles(b, bg_color, Color(0.55, 0.38, 0.22))
	ThemeManager.bind_button_micro_interaction(b)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _format_num(val: int) -> String:
	return str(val)

## 특정 그리드 좌표로 카메라 부드럽게 이동
func jump_to_grid(cell_pos: Vector2i, smooth: bool = true) -> void:
	if camera == null:
		return
	var w_pos := Vector2.ZERO
	if city_layer != null and city_layer.has_method("cell_center"):
		# 산 위(서장대 등)로 갈 때 높이만큼 화면이 위로 솟아 있으므로 그 칸의 고도를 반영해 정확히 가운데에 비춘다
		var jelev := 0.0
		var jg: Variant = city_layer.get("grid")
		if jg != null and jg.has_method("in_bounds") and jg.in_bounds(cell_pos.x, cell_pos.y):
			jelev = float(jg.grid[cell_pos.y][cell_pos.x].get("elevation", 0.0))
		w_pos = city_layer.cell_center(float(cell_pos.x) + 0.5, float(cell_pos.y) + 0.5, jelev)
	else:
		w_pos = Vector2((float(cell_pos.x) - float(cell_pos.y)) * 32.0, (float(cell_pos.x) + float(cell_pos.y)) * 16.0)
	camera.focus_on_coordinate(w_pos, smooth, 0.8)
