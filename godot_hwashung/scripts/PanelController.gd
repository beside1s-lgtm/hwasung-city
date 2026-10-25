extends CanvasLayer
class_name PanelController

const SpriteCacheManager = preload("res://scripts/autoload/SpriteCacheManager.gd")

## 조선 의궤 및 심시티 2000 스타일 하단 도크 바 & 한지 모달 시스템

signal tool_selected(tool: String)
signal undo_requested
signal intro_video_requested
signal title_screen_requested

var sim: SimulationCore
var grid: GameGrid
var court: CourtSystem
var trade: TradeSystem
var turns: TurnSystem
var hud: HUDController
var quests: Node
var outside: Node
var citizens: CitizenManager
var time_manager: TimeManager
var audio: AudioSystem
var music: MusicManager
var royal_procession: RoyalProcessionManager
var city: CityLayer
var camera: CameraController
var bibyeonsa_sibo: BibyeonsaSiboPopup = null
var trial_manager: TrialManager
var seojangdae_popup: SeojangdaePopup = null
var yajo_minigame: YajoMiniGamePopup = null
var yeonmudae_popup: YeonmudaePopup = null
var yeonmudae_minigame: YeonmudaeMiniGamePopup = null
var ubongo_wall_repair: UbongoWallRepairPopup = null
var _unconn_wall_idx: int = 0

var _modal_backdrop: ColorRect
var _modal: PanelContainer
var _title: Label
var _body: VBoxContainer
var _builder: Callable
# PORT-TRACE [성문 명명 입력 버그]: 시뮬레이션 틱마다(state_updated) 열린 모달을 다시 그리는데, 입력창이 있는
# 성문 명명 모달까지 다시 그려 LineEdit가 매번 새로 만들어지며 입력이 지워졌다. 입력 모달은 새로고침하지 않는다.
var _modal_no_refresh := false
# PORT-TRACE [섬세한 지형 편집]: 지형 붓 크기(반경 0=1칸, 1=3칸, 2=5칸)와 산 쌓기/깎기 높이 단위(1단, ½단).
# CityLayer가 지형 붓을 칠할 때 이 값을 읽는다. 기본은 1칸·1단 — 낮은 언덕을 한 칸씩 다듬을 수 있게.
var terrain_brush_radius: int = 0
var terrain_step: float = 1.0
var _terrain_size_btn: Button
var _terrain_step_btn: Button
# PORT-TRACE [성문 명명 대기열]: 한 번에 성문 여러 개를 지으면 명명 요청이 연달아 와서 창 하나를 덮어써
# 마지막 문만 이름을 받았다. 요청을 대기열에 쌓아 두고 한 창을 닫으면(확정/닫기) 다음 문의 창을 연다.
# gate_info_provider(Main에서 city.get_gate_info_for_pos 연결)가 있으면 차례가 왔을 때 추천 이름을 다시
# 계산해, 앞 문에 방금 붙인 이름이 뒤 문 추천에 또 나오지 않게 한다.
var _gate_naming_queue: Array[Vector2i] = []
var _gate_naming_active := false
var _gate_naming_pos := Vector2i(-1, -1)
var gate_info_provider: Callable

# 상단 어명 교지 배너
var _banner_panel: PanelContainer
var _banner_label: Label
var _banner_sub_label: Label
var _banner_btn: Button
var _banner_hint_btn: Button

# 하단 도크 바 및 서브 도크
var _dock_panel: PanelContainer
var _public_popup: PanelContainer
var _public_category: String = "admin"
var _public_items_hb: HBoxContainer = null
var _public_tab_btns: Dictionary = {}
var _terrain_popup: PanelContainer # PORT-TRACE [지형 편집]: 평지/산/물 붓 서브 도크
var _policy_popup: PanelContainer  # PORT-TRACE [조정·정무]: 비변사/조세/인재/포호/도적/왕실의례 서브 도크
var _dock_policy_btn: Button
var _policy_bandit_btn: Button
var _policy_btns: Dictionary = {} # action_id -> Button (근대화 시대 이름 교체용)
var _policy_tiger_btn: Button
var _active_tool_id: String = "inspect"
var _dock_buttons: Dictionary = {} # tool_id -> Button

# 조세 편집 임시 값
var _temp_tax_land: int = 7
var _temp_tax_market: int = 7
var _temp_tax_military: int = 7

func setup(s: SimulationCore, g: GameGrid, c: CourtSystem, t: TradeSystem, ts: TurnSystem, h: HUDController, q: Node = null, o: Node = null) -> void:
	sim = s
	grid = g
	court = c
	trade = t
	turns = ts
	hud = h
	quests = q
	outside = o

	_temp_tax_land = sim.tax_rate_land
	_temp_tax_market = sim.tax_rate_market
	_temp_tax_military = sim.tax_rate_military

	_build_quest_banner()
	_build_public_popup()
	_build_terrain_popup()
	_build_policy_popup()
	_build_dock_bar()
	_build_modal()

	# 상단 HUD의 퀵 액션 요청 연결
	if hud:
		hud.quick_action_requested.connect(open_action_modal)
		hud.tool_selected.connect(select_tool)

	turns.turn_report.connect(_on_turn_report)
	court.notice.connect(func(m): hud._show_toast(m, "📜"))
	sim.state_updated.connect(func(_a, _b, _c, _d, _e):
		_refresh_menu_buttons()
		_refresh_policy_buttons()
	)

	if quests:
		quests.quest_completed.connect(func(qdata):
			var r: Dictionary = qdata.get("reward", {})
			hud._show_toast(r.get("msg", "어명 교지를 완수하셨습니다!"), "👑")
		)
		quests.quest_updated.connect(_update_quest_banner)
		quests.all_quests_completed.connect(func():
			if _banner_label:
				_banner_label.text = "모든 어명 교지를 완수하셨습니다!"
			if _banner_sub_label:
				_banner_sub_label.text = "수원화성을 굳건히 수호하여 융성한 번영을 이루십시오."
			if _banner_btn:
				_banner_btn.visible = false
		)
		quests.ending_triggered.connect(func(edata):
			show_ending_modal(edata.get("title", "대단원"), edata.get("story", ""))
		)
		_update_quest_banner(quests.get_current_quest())

	select_tool("inspect")

# ------------------------------------------------------------ 상단 어명 배너 (붉은색 지정 영역: 2pt 확대)
func _build_quest_banner() -> void:
	_banner_panel = PanelContainer.new()
	_banner_panel.offset_left = 14.0
	_banner_panel.offset_top = 114.0
	_banner_panel.offset_right = 620.0
	_banner_panel.offset_bottom = 180.0

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.06, 0.96)
	sb.border_color = Color(0.85, 0.62, 0.12, 0.95) # 황금 테두리
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 6
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_banner_panel.add_theme_stylebox_override("panel", sb)
	add_child(_banner_panel)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_panel.add_child(hb)

	var icon_lbl := Label.new()
	icon_lbl.text = "📜"
	icon_lbl.add_theme_font_size_override("font_size", 22)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(icon_lbl)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)

	_banner_label = Label.new()
	_banner_label.text = "제1교지: 화성행궁 건립"
	_banner_label.add_theme_color_override("font_color", Color(0.99, 0.88, 0.38))
	_banner_label.add_theme_font_size_override("font_size", 14)
	_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_banner_label)

	_banner_sub_label = Label.new()
	_banner_sub_label.text = "임금이 머무실 화성행궁을 넓은 평지에 세워 신도시의 기틀을 마련하십시오."
	_banner_sub_label.add_theme_color_override("font_color", Color(0.88, 0.85, 0.78))
	_banner_sub_label.add_theme_font_size_override("font_size", 12)
	_banner_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_sub_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_banner_sub_label)

	_banner_btn = Button.new()
	_banner_btn.text = "행궁 터 잡기"
	_banner_btn.custom_minimum_size = Vector2(104, 38)
	_banner_btn.add_theme_font_size_override("font_size", 13)
	_banner_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var b_norm := StyleBoxFlat.new()
	b_norm.bg_color = Color(0.50, 0.12, 0.08, 1.0) # 단청 붉은색
	b_norm.border_color = Color(0.96, 0.65, 0.10, 1.0)
	b_norm.set_border_width_all(1)
	b_norm.set_corner_radius_all(4)
	b_norm.set_content_margin_all(6)
	_banner_btn.add_theme_stylebox_override("normal", b_norm)

	var b_hov := b_norm.duplicate()
	b_hov.bg_color = Color(0.65, 0.18, 0.12, 1.0)
	b_hov.border_color = Color(1.0, 0.88, 0.35, 1.0)
	b_hov.set_border_width_all(2)
	_banner_btn.add_theme_stylebox_override("hover", b_hov)

	var b_press := b_norm.duplicate()
	b_press.bg_color = Color(0.38, 0.08, 0.05, 1.0)
	_banner_btn.add_theme_stylebox_override("pressed", b_press)

	_banner_btn.add_theme_color_override("font_color", Color(0.99, 0.95, 0.75))
	_banner_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.60))

	hb.add_child(_banner_btn)

	# PORT-TRACE [퀘스트 위치 추천]: "초등학생이 하는 게임이니 친절한 안내가 필요하다"는 요청 —
	# 짓는 방법(도구 선택)뿐 아니라 "어디에" 지으면 좋을지도 카메라를 옮겨 보여준다.
	_banner_hint_btn = Button.new()
	_banner_hint_btn.text = "📍 위치 보기"
	_banner_hint_btn.custom_minimum_size = Vector2(88, 38)
	_banner_hint_btn.add_theme_font_size_override("font_size", 13)
	_banner_hint_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var h_norm := StyleBoxFlat.new()
	h_norm.bg_color = Color(0.10, 0.22, 0.32, 1.0)
	h_norm.border_color = Color(0.45, 0.75, 0.95, 1.0)
	h_norm.set_border_width_all(1)
	h_norm.set_corner_radius_all(4)
	h_norm.set_content_margin_all(6)
	_banner_hint_btn.add_theme_stylebox_override("normal", h_norm)
	var h_hov := h_norm.duplicate()
	h_hov.bg_color = Color(0.14, 0.32, 0.44, 1.0)
	h_hov.border_color = Color(0.65, 0.90, 1.0, 1.0)
	h_hov.set_border_width_all(2)
	_banner_hint_btn.add_theme_stylebox_override("hover", h_hov)
	_banner_hint_btn.add_theme_color_override("font_color", Color(0.90, 0.97, 1.0))
	_banner_hint_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))

	hb.add_child(_banner_hint_btn)

func _update_quest_banner(q: Dictionary) -> void:
	if not _banner_label:
		return
	if q.is_empty():
		_banner_label.text = "모든 어명 교지를 완수하셨습니다!"
		if _banner_sub_label:
			_banner_sub_label.text = "수원화성을 굳건히 수호하여 융성한 번영을 이루십시오."
		if _banner_btn:
			_banner_btn.visible = false
		if _banner_hint_btn:
			_banner_hint_btn.visible = false
		return

	_banner_label.text = q.get("title", "어명 교지")
	if _banner_sub_label:
		_banner_sub_label.text = q.get("desc", "")

	var qid: String = q.get("id", "")
	var tid: String = q.get("tool", "")
	var pos := Vector2i(-1, -1)
	if quests and quests.has_method("find_hint_position"):
		pos = quests.find_hint_position(qid)

	if _banner_btn:
		_banner_btn.visible = true
		_banner_btn.text = q.get("btn_text", "터 잡기")
		for conn in _banner_btn.pressed.get_connections():
			_banner_btn.pressed.disconnect(conn.callable)
		_banner_btn.pressed.connect(func():
			# 1. 특수 선행 조건 검사 (봉돈은 완공된 성곽 필요)
			if qid == "bongdon" and grid != null and grid.count_completed("wall") == 0:
				select_tool("wall")
				if hud:
					hud._show_toast("봉돈은 완공된 성곽 위에만 축조할 수 있습니다! 먼저 [화성성곽]을 쌓아주세요.", "🧱")
				return
			if tid != "":
				select_tool(tid)
			# 2. 추천 위치 자동 점프 및 가이드 토스트 발화
			if pos.x >= 0 and hud:
				hud.jump_to_grid(pos)
				hud._show_toast("추천 위치로 이동했습니다. 이곳에 건설하십시오!", "📍")
			elif hud:
				hud._show_toast("[%s] 도구가 선택되었습니다. 원하는 위치에 건설하십시오." % q.get("title", ""), "🔨")
		)

	# PORT-TRACE [퀘스트 위치 추천]: 어디에 지으면 좋을지 실시간으로 찾아 카메라를 옮겨준다.
	# 후보를 못 찾으면(예: 부지가 꽉 참) 버튼을 숨겨 혼란을 주지 않는다.
	if _banner_hint_btn:
		_banner_hint_btn.visible = pos.x >= 0
		for conn in _banner_hint_btn.pressed.get_connections():
			_banner_hint_btn.pressed.disconnect(conn.callable)
		if pos.x >= 0:
			_banner_hint_btn.pressed.connect(func():
				if tid != "":
					select_tool(tid)
				if hud:
					hud.jump_to_grid(pos)
					hud._show_toast("추천 위치로 이동했습니다. 이곳에 건설하십시오!", "📍")
			)

# ------------------------------------------------------------ 관청·공공 서브 도크 팝업 (3대 하위메뉴 탭)
const PUBLIC_CATEGORIES := {
	"admin": {
		"name": "🏛️ 행정시설",
		"items": [
			["👑", "화성행궁", "haenggung"],
			["⚖️", "수원유수부\n관아", "gwana"],
			["🚨", "순라청", "patrol"],
			["🧯", "멸화군", "firefighter"],
			["🏫", "수원향교(성 밖)", "hyanggyo"],
			["💧", "우물·수로", "well"],
			["🍲", "진휼소\n(2x2 구휼)", "jinhulso"],
		]
	},
	"military": {
		"name": "⚔️ 군사시설",
		"items": [
			["🏯", "서장대", "seojangdae"],
			["🔥", "봉돈", "bongdon"],
			["💥", "포루", "poru"],
			["🛡️", "공심돈", "gongsimdon"],
			["🏹", "연무대", "yeonmudae"],
			["🌸", "방화수류정\n(용연)", "banghwasuryu"],
		]
	},
	"agriculture": {
		"name": "🌾 농업시설",
		"items": [
			["💧", "만석거\n(영화정 포함)", "manseokgeo"],
			["🌾", "축만제\n(서호 당주)", "chukmanje"],
			["🌊", "작은 저수지", "reservoir"],
			["🛡️", "석축제방", "levee"],
		]
	}
}

func _build_public_popup() -> void:
	_public_popup = PanelContainer.new()
	_public_popup.visible = false
	_public_popup.anchor_left = 0.5
	_public_popup.anchor_right = 0.5
	_public_popup.anchor_top = 1.0
	_public_popup.anchor_bottom = 1.0
	_public_popup.offset_left = -265.0
	_public_popup.offset_right = 265.0
	_public_popup.offset_top = -196.0
	_public_popup.offset_bottom = -82.0
	_public_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.05, 0.98)
	sb.border_color = Color(0.75, 0.50, 0.22, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.7)
	sb.shadow_size = 10
	sb.set_content_margin_all(6)
	_public_popup.add_theme_stylebox_override("panel", sb)
	add_child(_public_popup)

	var root_vb := VBoxContainer.new()
	root_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vb.add_theme_constant_override("separation", 6)
	_public_popup.add_child(root_vb)

	# 1. 상단 3대 카테고리 탭 (행정시설 / 군사시설 / 농업시설)
	var tab_hb := HBoxContainer.new()
	tab_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_hb.add_theme_constant_override("separation", 6)
	root_vb.add_child(tab_hb)

	_public_tab_btns.clear()
	for cat_key: String in ["admin", "military", "agriculture"]:
		var cat_data: Dictionary = PUBLIC_CATEGORIES[cat_key]
		var tab_btn := Button.new()
		tab_btn.text = str(cat_data["name"])
		tab_btn.custom_minimum_size = Vector2(160, 26)
		tab_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tab_btn.pressed.connect(func(): _show_public_category(cat_key))
		tab_hb.add_child(tab_btn)
		_public_tab_btns[cat_key] = tab_btn

	# 2. 하단 선택된 카테고리의 시설 카드 버튼 컨테이너
	_public_items_hb = HBoxContainer.new()
	_public_items_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	_public_items_hb.add_theme_constant_override("separation", 6)
	root_vb.add_child(_public_items_hb)

	_show_public_category(_public_category)

func _show_public_category(cat_id: String) -> void:
	_public_category = cat_id
	if not PUBLIC_CATEGORIES.has(cat_id) or _public_items_hb == null:
		return

	# 탭 버튼 스타일 갱신
	for k: String in _public_tab_btns:
		var tb: Button = _public_tab_btns[k]
		var is_sel: bool = (k == cat_id)
		var tsb := StyleBoxFlat.new()
		tsb.bg_color = Color(0.35, 0.16, 0.08, 0.95) if is_sel else Color(0.16, 0.12, 0.09, 0.85)
		tsb.border_color = Color(0.95, 0.75, 0.25, 0.95) if is_sel else Color(0.4, 0.3, 0.2, 0.6)
		tsb.set_border_width_all(1)
		tsb.set_corner_radius_all(4)
		tsb.content_margin_top = 2
		tsb.content_margin_bottom = 2
		tb.add_theme_stylebox_override("normal", tsb)
		tb.add_theme_stylebox_override("hover", tsb)
		tb.add_theme_stylebox_override("pressed", tsb)
		tb.add_theme_color_override("font_color", Color("fef3c7") if is_sel else Color("a8a29e"))

	# 기존 아이템 제거 및 _dock_buttons 캐시 정리
	for c_key: String in PUBLIC_CATEGORIES:
		var c_data: Dictionary = PUBLIC_CATEGORIES[c_key]
		var c_items: Array = c_data.get("items", [])
		for ci in c_items:
			var c_tid: String = str(ci[2])
			if _dock_buttons.has(c_tid):
				_dock_buttons.erase(c_tid)

	for ch in _public_items_hb.get_children():
		ch.queue_free()

	# 신규 아이템 생성
	var cat_data: Dictionary = PUBLIC_CATEGORIES[cat_id]
	var items: Array = cat_data["items"]
	for pt in items:
		var lbl_txt := str(pt[1])
		var um_w: UrbanEvolutionManager = UrbanEvolutionManager.instance
		if um_w != null and UrbanEvolutionManager.is_active(): # 근대 수도체제 이름
			if str(pt[2]) == "well" and um_w.wells_upgraded:
				lbl_txt = "집수정"
			elif str(pt[2]) == "reservoir" and um_w.reservoirs_upgraded:
				lbl_txt = "생활용수\n공급시설"
		var btn := _create_dock_card_btn(_public_items_hb, str(pt[0]), lbl_txt, str(pt[2]), false)
		_dock_buttons[str(pt[2])] = btn
		var is_act: bool = (_active_tool_id == str(pt[2]))
		_apply_card_btn_styles(btn, is_act)

# ------------------------------------------------------------ 지형 편집 서브 도크 팝업
## PORT-TRACE [지형 편집]: 사용자 요청 — "산의 정상 위치가 실제랑 다르고 행궁 자리도 애매하고
## 하천도 실제와 달라서" 직접 지형을 그릴 수 있게 해달라는 요청. generate_map.py를 다시 돌리지
## 않고도 게임 안에서 평지/산/물 붓으로 지형을 다시 그린다(GameGrid.paint_terrain 참고).
func _build_terrain_popup() -> void:
	_terrain_popup = PanelContainer.new()
	_terrain_popup.visible = false
	_terrain_popup.anchor_left = 0.5
	_terrain_popup.anchor_right = 0.5
	_terrain_popup.anchor_top = 1.0
	_terrain_popup.anchor_bottom = 1.0
	_terrain_popup.offset_left = -410.0
	_terrain_popup.offset_right = 410.0
	_terrain_popup.offset_top = -158.0
	_terrain_popup.offset_bottom = -82.0
	_terrain_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.05, 0.98)
	sb.border_color = Color(0.75, 0.50, 0.22, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.7)
	sb.shadow_size = 10
	sb.set_content_margin_all(6)
	_terrain_popup.add_theme_stylebox_override("panel", sb)
	add_child(_terrain_popup)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 6)
	_terrain_popup.add_child(hb)

	# PORT-TRACE [지형 편집 세분화 & 자연 지표면 브러시]:
	# 평지, 산, 물뿐 아니라 풀밭, 돌밭, 흙바닥, 흙밭, 우거진 숲 브러시 지원
	var terra_tools := [
		["🟢", "평지 붓", "terra_plain"],
		["⛰️", "산 쌓기", "terra_mountain"],
		["⛏️", "산 깎기", "terra_mountain_down"],
		["💧", "얕은 여울", "terra_water_shallow"],
		["🌊", "물 붓(보통)", "terra_water"],
		["🌀", "깊은 물", "terra_water_deep"],
		["🌿", "풀밭 붓", "terra_grass"],
		["🪨", "돌밭 붓", "terra_rocky"],
		["🍂", "흙바닥 붓", "terra_dirt"],
		["🌾", "흙밭 붓", "terra_field"],
		["🌲", "우거진 숲", "terra_forest"],
	]
	for tt in terra_tools:
		var btn := _create_dock_card_btn(hb, tt[0], tt[1], tt[2], false)
		_dock_buttons[tt[2]] = btn

	# 붓 크기·높이 단위 전환 버튼(누를 때마다 바뀜)
	_terrain_size_btn = _create_action_card_btn(hb, "🖌️", "붓 1칸", func():
		terrain_brush_radius = (terrain_brush_radius + 1) % 3
		_set_card_label(_terrain_size_btn, "붓 %d칸" % (terrain_brush_radius * 2 + 1))
		if hud:
			hud._show_toast("지형 붓 크기: %d x %d칸" % [terrain_brush_radius * 2 + 1, terrain_brush_radius * 2 + 1], "🖌️")
	, Color(0.18, 0.14, 0.08), false)
	_terrain_step_btn = _create_action_card_btn(hb, "📏", "높이 1단", func():
		terrain_step = 0.5 if terrain_step >= 1.0 else 1.0
		_set_card_label(_terrain_step_btn, "높이 1단" if terrain_step >= 1.0 else "높이 ½단")
		if hud:
			hud._show_toast("산 쌓기·깎기 한 번에 %s씩 오르내립니다." % ("1단" if terrain_step >= 1.0 else "½단"), "📏")
	, Color(0.18, 0.14, 0.08), false)

	# PORT-TRACE [지형 저장]: 개발자가 인게임 붓으로 그린 지형을 모든 플레이어의
	# 새 기본값으로 저장한다(terrain_data.json 덮어쓰기, 기존 파일은 .backup.json으로 보존).
	_create_action_card_btn(hb, "💾", "지형 저장", func():
		if grid == null:
			return
		var res: Dictionary = grid.export_terrain_data()
		if hud:
			hud._show_toast(res.get("msg", ""), "💾" if res.get("success", false) else "❌")
	, Color(0.10, 0.10, 0.18), false)

# ------------------------------------------------------------ 서브 도크 상호 배타 토글 헬퍼
func _toggle_popup(target: PanelContainer) -> void:
	var cur_vis: bool = target.visible if target else false
	if _public_popup: _public_popup.visible = false
	if _terrain_popup: _terrain_popup.visible = false
	if _policy_popup: _policy_popup.visible = false
	if target:
		target.visible = not cur_vis

# ------------------------------------------------------------ 조정·정무 서브 도크 팝업
func _build_policy_popup() -> void:
	_policy_popup = PanelContainer.new()
	_policy_popup.visible = false
	_policy_popup.anchor_left = 0.5
	_policy_popup.anchor_right = 0.5
	_policy_popup.anchor_top = 1.0
	_policy_popup.anchor_bottom = 1.0
	_policy_popup.offset_left = -460.0
	_policy_popup.offset_right = 460.0
	_policy_popup.offset_top = -158.0
	_policy_popup.offset_bottom = -82.0
	_policy_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.05, 0.98)
	sb.border_color = Color(0.75, 0.50, 0.22, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.7)
	sb.shadow_size = 10
	sb.set_content_margin_all(6)
	_policy_popup.add_theme_stylebox_override("panel", sb)
	add_child(_policy_popup)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 6)
	_policy_popup.add_child(hb)

	var policy_items := [
		["📰", "비변사 시보", "newspaper"],
		["⚖️", "호조 조세", "tax"],
		["👥", "조정 인재", "court"],
		["🐅", "포호 대책", "tiger"],
		["⚔️", "도적 토벌", "bandit"],
		["👑", "세자서연", "crown_prince"],
		["🌸", "현륭원", "hyoryungwon"],
		["🥁", "을묘원행", "eulmyo"],
		["🤝", "삼남 교역", "trade"],
		["📖", "실학 연구", "research"],
	]

	for item in policy_items:
		var icon_txt: String = item[0]
		var lbl_txt: String = item[1]
		var action_id: String = item[2]
		var btn := _create_action_card_btn(hb, icon_txt, lbl_txt, func():
			if _policy_popup:
				_policy_popup.visible = false
			open_action_modal(_policy_action(action_id))
		, Color(0.18, 0.12, 0.08), false)
		_policy_btns[action_id] = btn
		if action_id == "bandit":
			_policy_bandit_btn = btn
		elif action_id == "tiger":
			_policy_tiger_btn = btn

## 근대화 시대에는 [실학 연구] 자리가 [서학 진흥], [삼남 교역] 자리가 [외교]가 된다.
const PRESIDENT_BLOCKED := ["tax", "research", "west_promo", "trade", "diplomacy", "tiger", "bandit", "crown_prince", "hyoryungwon", "eulmyo", "wall_repair", "water_works"]

## PORT-TRACE [1800년 뒤 세자 추천]: 세자서연이 닫혔는가(1800년 엔딩으로 순조 즉위 뒤, 현대 정치체제 전환 뒤)
func _prince_closed() -> bool:
	var yr: int = time_manager.current_year if time_manager != null else (sim.current_year if sim != null else 1789)
	return CrownPrinceEducationManager.prince_affairs_closed(yr)

## 정무 메뉴의 [세자서연] 버튼: 세자서연이 닫혔으면 숨긴다(정무 메뉴를 열 때마다 다시 본다 — 1800년은 메뉴를 연 채로도 넘어오므로)
func _refresh_prince_btn() -> void:
	var prince_btn: Button = _policy_btns.get("crown_prince")
	if prince_btn != null:
		prince_btn.visible = not _prince_closed()

func _policy_action(action_id: String) -> String:
	if ModernPoliticsManager.is_presidential() and action_id in ["research", "trade"]:
		return "proposals"
	if ModernizationManager.is_active():
		if action_id == "research":
			return "west_promo"
		if action_id == "trade":
			return "diplomacy"
	return action_id

func refresh_modern_labels() -> void:
	var modern := ModernizationManager.is_active()
	var table := {
		"research": ["🔬", "서학 진흥"] if modern else ["📖", "실학 연구"],
		"trade": ["🌐", "외교"] if modern else ["🤝", "삼남 교역"],
	}
	if ModernPoliticsManager.is_presidential():
		table["research"] = ["📜", "국정 건의"]
		table["trade"] = ["🏛️", "대통령 집무"]
	# 1800년 엔딩(순조 즉위) 뒤나 현대 정치체제로 바뀌면 세자 관련 정무(세자서연)를 없앤다
	# 하단 메뉴바: 홍예성문 → 하수처리시설(근대화 시대)
	var gate_btn: Button = _dock_buttons.get("gate")
	if gate_btn != null and gate_btn.get_child_count() > 0:
		var gvb := gate_btn.get_child(0)
		(gvb.get_child(0) as Label).text = "🚰" if modern else "⛩️"
		(gvb.get_child(1) as Label).text = "하수처리" if modern else "홍예성문"
	_refresh_prince_btn()
	for id in table:
		var b: Button = _policy_btns.get(id)
		if b == null or b.get_child_count() == 0:
			continue
		var vb := b.get_child(0)
		(vb.get_child(0) as Label).text = table[id][0]
		(vb.get_child(1) as Label).text = table[id][1]

# ------------------------------------------------------------ 하단 도크 바 (최하단 메인 메뉴바 - 붉은색 지정 영역: 2pt 확대)
func _build_dock_bar() -> void:
	_dock_panel = PanelContainer.new()
	_dock_panel.anchor_left = 0.0
	_dock_panel.anchor_right = 1.0
	_dock_panel.anchor_top = 1.0
	_dock_panel.anchor_bottom = 1.0
	_dock_panel.offset_top = -78.0
	_dock_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.06, 0.04, 0.98) # 짙은 옻칠 목재 프레임
	sb.border_color = Color(0.40, 0.25, 0.12, 0.95)
	sb.border_width_top = 2
	sb.shadow_color = Color(0, 0, 0, 0.85)
	sb.shadow_size = 12
	sb.set_content_margin_all(5)
	_dock_panel.add_theme_stylebox_override("panel", sb)
	add_child(_dock_panel)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 6)
	_dock_panel.add_child(hb)

	# 1. 🔍 살피기
	_dock_buttons["inspect"] = _create_dock_card_btn(hb, "🔍", "살피기", "inspect", true)
	# 2. 🛣️ 흙길 (삼남토로)
	_dock_buttons["road"] = _create_dock_card_btn(hb, "🛣️", "흙길", "road", true)
	# 2-1. 🏛️ 박석길 (포장대로)
	_dock_buttons["stone_road"] = _create_dock_card_btn(hb, "🏛️", "박석길", "stone_road", true)
	# 3. 🧱 화성성곽
	_dock_buttons["wall"] = _create_dock_card_btn(hb, "🧱", "화성성곽", "wall", true)
	# 4. ⛩️ 홍예성문
	_dock_buttons["gate"] = _create_dock_card_btn(hb, "⛩️", "홍예성문", "gate", true)
	# 5. 🏡 방·리 (주거)
	_dock_buttons["zone_res"] = _create_dock_card_btn(hb, "🏡", "방·리", "zone_res", true)
	# 6. 🏪 저잣거리 (상업)
	_dock_buttons["zone_com"] = _create_dock_card_btn(hb, "🏪", "저잣거리", "zone_com", true)
	# 7. 🌾 대유둔전 (농업)
	_dock_buttons["zone_agr"] = _create_dock_card_btn(hb, "🌾", "대유둔전", "zone_agr", true)
	# 7-1. 🔥 공방 (야조소·와소 작업장) — PORT-TRACE [공방 구획]
	_dock_buttons["zone_ind"] = _create_dock_card_btn(hb, "🔥", "공방", "zone_ind", true)

	# 8. 🏛️ 관청·공공 토글 버튼 (서브 도크 연동)
	_create_action_card_btn(hb, "🏛️", "관청·공공", func():
		_toggle_popup(_public_popup)
	, Color(0.18, 0.12, 0.08), true)

	# 8-1. 🗺️ 지형편집 토글 버튼 (평지/산/물 붓 — 서브 도크 연동)
	_create_action_card_btn(hb, "🗺️", "지형편집", func():
		_toggle_popup(_terrain_popup)
	, Color(0.10, 0.16, 0.10), true)

	# 9. 🏗️ 국책대역사 모달 버튼
	_create_action_card_btn(hb, "🏗️", "국책대역사", func():
		if _public_popup: _public_popup.visible = false
		if _terrain_popup: _terrain_popup.visible = false
		if _policy_popup: _policy_popup.visible = false
		open_action_modal("mega_projects")
	, Color(0.26, 0.10, 0.08), true)

	# 10. 📜 조정·정무 서브 도크 버튼 (비변사/조세/인재/포호/도적/왕실의례 통합)
	_dock_policy_btn = _create_action_card_btn(hb, "📜", "조정·정무", func():
		_refresh_prince_btn()
		_toggle_popup(_policy_popup)
	, Color(0.18, 0.12, 0.08), true)

	# 11. ↩️ 되돌리기 버튼 (실행 취소 / Undo)
	_create_action_card_btn(hb, "↩️", "되돌리기", func():
		undo_requested.emit()
	, Color(0.20, 0.14, 0.10), true)

func select_tool(tool_id: String) -> void:
	if tool_id == "gate" and ModernizationManager.is_active():
		tool_id = "sewage" # 근대화 시대: 홍예성문 자리 = 하수처리시설
	_active_tool_id = tool_id
	emit_signal("tool_selected", tool_id)
	if hud:
		hud.set_selected_tool(tool_id)

	# 버튼 활성 스타일 갱신
	var stale_keys: Array = []
	for tid in _dock_buttons:
		var b_val = _dock_buttons[tid]
		if not is_instance_valid(b_val):
			stale_keys.append(tid)
			continue
		var b: Button = b_val as Button
		if b:
			var is_act: bool = (String(tid) == tool_id)
			_apply_card_btn_styles(b, is_act)

	for stale_tid in stale_keys:
		_dock_buttons.erase(stale_tid)

	# 선택 완료 후 서브 도크 닫기
	if _public_popup:
		_public_popup.visible = false
	if _terrain_popup:
		_terrain_popup.visible = false
	if _policy_popup:
		_policy_popup.visible = false

func _create_dock_card_btn(parent: Node, icon_txt: String, label_txt: String, tool_id: String, is_main_dock: bool = false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(68, 66) if is_main_dock else Vector2(64, 66)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(func(): select_tool(tool_id))

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 2)
	b.add_child(vb)

	var ic := Label.new()
	ic.text = icon_txt
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ic.add_theme_font_size_override("font_size", 18)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(ic)

	var lb := Label.new()
	var formatted_txt: String = label_txt
	if not formatted_txt.contains("\n") and (formatted_txt.contains("(") or formatted_txt.contains("（")):
		formatted_txt = formatted_txt.replace(" (", "\n(").replace("(", "\n(").replace("（", "\n（")
	lb.text = formatted_txt
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lb.add_theme_color_override("font_color", Color(0.95, 0.90, 0.82))
	var font_sz: int = (12 if formatted_txt.contains("\n") else 13) if is_main_dock else (11 if formatted_txt.contains("\n") else 12)
	lb.add_theme_font_size_override("font_size", font_sz)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(lb)

	_apply_card_btn_styles(b, false)

	parent.add_child(b)
	return b

## 카드 버튼의 이름 글자(아이콘 아래 줄)를 바꾼다
func _set_card_label(b: Button, txt: String) -> void:
	var labels := b.find_children("*", "Label", true, false)
	if not labels.is_empty():
		var formatted: String = txt
		if not formatted.contains("\n") and (formatted.contains("(") or formatted.contains("（")):
			formatted = formatted.replace(" (", "\n(").replace("(", "\n(").replace("（", "\n（")
		(labels[labels.size() - 1] as Label).text = formatted

func _create_action_card_btn(parent: Node, icon_txt: String, label_txt: String, cb: Callable, bg_color: Color = Color(0.16, 0.11, 0.07), is_main_dock: bool = false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(68, 66) if is_main_dock else Vector2(64, 66)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 2)
	b.add_child(vb)

	var ic := Label.new()
	ic.text = icon_txt
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ic.add_theme_font_size_override("font_size", 18)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(ic)

	var lb := Label.new()
	var act_txt: String = label_txt
	if not act_txt.contains("\n") and (act_txt.contains("(") or act_txt.contains("（")):
		act_txt = act_txt.replace(" (", "\n(").replace("(", "\n(").replace("（", "\n（")
	lb.text = act_txt
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lb.add_theme_color_override("font_color", Color(0.95, 0.90, 0.82))
	var font_sz: int = (12 if act_txt.contains("\n") else 13) if is_main_dock else (11 if act_txt.contains("\n") else 12)
	lb.add_theme_font_size_override("font_size", font_sz)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(lb)

	# Normal
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = Color(0.40, 0.26, 0.14, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", sb)

	# Hover
	var h_sb := sb.duplicate()
	h_sb.bg_color = bg_color.lightened(0.2)
	h_sb.border_color = Color(0.98, 0.85, 0.35)
	h_sb.set_border_width_all(2)
	b.add_theme_stylebox_override("hover", h_sb)

	parent.add_child(b)
	return b

func _apply_card_btn_styles(b: Button, is_active: bool) -> void:
	if is_active:
		var active_sb := StyleBoxFlat.new()
		active_sb.bg_color = Color(0.60, 0.11, 0.11, 1.0) # 단청 주홍 액티브
		active_sb.border_color = Color(0.98, 0.75, 0.14, 1.0) # 황금 테두리
		active_sb.set_border_width_all(2)
		active_sb.set_corner_radius_all(6)
		active_sb.shadow_color = Color(0.98, 0.75, 0.14, 0.5)
		active_sb.shadow_size = 8
		b.add_theme_stylebox_override("normal", active_sb)
		b.add_theme_stylebox_override("hover", active_sb)
		b.add_theme_stylebox_override("pressed", active_sb)
	else:
		var normal_sb := StyleBoxFlat.new()
		normal_sb.bg_color = Color(0.16, 0.11, 0.07, 0.96)
		normal_sb.border_color = Color(0.38, 0.24, 0.13, 0.85)
		normal_sb.set_border_width_all(1)
		normal_sb.set_corner_radius_all(4)
		b.add_theme_stylebox_override("normal", normal_sb)

		var hover_sb := normal_sb.duplicate()
		hover_sb.bg_color = Color(0.26, 0.18, 0.12, 1.0)
		hover_sb.border_color = Color(0.98, 0.85, 0.35, 1.0)
		hover_sb.set_border_width_all(2)
		b.add_theme_stylebox_override("hover", hover_sb)

		var press_sb := normal_sb.duplicate()
		press_sb.bg_color = Color(0.10, 0.07, 0.04, 1.0)
		b.add_theme_stylebox_override("pressed", press_sb)

# ------------------------------------------------------------ 퀵 액션 모달 오픈 라우터
func open_action_modal(action_id: String) -> void:
	if action_id == "crown_prince" and _prince_closed():
		return # 1800년 엔딩(순조 즉위) 뒤·현대 정치체제 전환 뒤에는 세자서연 없음
	# 대통령제: 정무는 직접 못 하고 국회·행정 각부의 건의를 승인/반려한다
	if ModernPoliticsManager.is_presidential() and action_id in PRESIDENT_BLOCKED:
		action_id = "proposals"
	match action_id:
		"proposals": _open("국정 건의 (국회·행정 각부)", _build_proposals)
		"water_works": _open("근대 수도체제", _build_water_works)
		"newspaper": _open("비변사 시보", _build_newspaper)
		"mega_projects": _open("국책 대역사 청원", _build_projects)
		"tax":
			_open("근대 통합 세제" if ModernizationManager.is_active() else "호조(戶曹) 탕평 조세 조율", _build_tax)
			_modal_no_refresh = true
		"tiger": _open("포호(捕虎) 대책", _build_tiger)
		"crown_prince": _open("시강원 세자서연", _build_prince)
		"hyoryungwon": _open("화산 현륭원 친림", _build_hyoryungwon)
		"eulmyo": _open("을묘년 화성 원행", _build_eulmyo)
		"trade": _open("삼남로 교역", _build_trade)
		"court": _open("규장각 및 조정 인사", _build_retainers)
		"uigwe":
			_close_modal()
			open_uigwe_popup()
		"research": _open("실학 연구", _build_research)
		"west_promo": _open("서학 진흥 (근대 과학 연구)", _build_west_promo)
		"diplomacy": _open("국제외교 회담", _build_diplomacy)
		"bandit": _open("화적(도적) 소탕 및 소굴 토벌", _build_bandit)
		"trial":
			_close_modal()
			if trial_manager:
				trial_manager.open_trial_ui()
		"gwana": _open("화성유수부 동헌 관아", _build_gwana_hub)
		"wall_repair": _open("문화재 보수 및 성곽 방호" if ModernizationManager.is_active() else "성곽 보수 및 사대문 방호 체제", _build_wall_repair)
		"seojangdae_drill": _open("서장대 연례 야간 군사 훈련 (야조)", _build_seojangdae_drill)
		"yeonmudae_drill": _open("연무대 장용영 군사 훈련 (무예 사열)", _build_yeonmudae_drill)
		"stat_gold": _open("국고(금) — 재정 작업", _build_stat_hub.bind("gold"))
		"stat_rice": _open("군량미 — 식량 작업", _build_stat_hub.bind("rice"))
		"stat_pop": _open("인구 — 신도시 작업", _build_stat_hub.bind("pop"))
		"stat_loyalty": _open("민심 — 백성 마음 작업", _build_stat_hub.bind("loyalty"))
		"stat_authority": _open("왕권·국방 — 조정 작업", _build_stat_hub.bind("authority"))
		"stat_flood": _open("치수 방재율 — 수원천 작업", _build_stat_hub.bind("flood"))
		"game_settings": _open_game_settings_modal()
		"intro_video": emit_signal("intro_video_requested")
		"title_screen": emit_signal("title_screen_requested")

## 상단 지표(국고·군량·인구·민심·왕권·치수)를 눌렀을 때: 지금 수치와 올리는 방법, 바로 할 수 있는 작업 버튼
func _build_stat_hub(kind: String) -> void:
	_clear_body()
	var info := _stat_hub_info(kind)
	var head := Label.new()
	head.text = "%s   %s" % [info["icon"], info["value"]]
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", Color("7c2d12"))
	_body.add_child(head)
	var why := Label.new()
	why.text = String(info["why"])
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.add_theme_color_override("font_color", Color("1c1917"))
	_body.add_child(why)
	var sep := HSeparator.new()
	_body.add_child(sep)
	var ttl := Label.new()
	ttl.text = "바로 할 수 있는 일"
	ttl.add_theme_color_override("font_color", Color("57534e"))
	_body.add_child(ttl)
	for act: Dictionary in info["actions"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_body.add_child(row)
		var b := Button.new()
		b.text = String(act["label"])
		b.custom_minimum_size = Vector2(190, 34)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var kind_a: String = String(act["kind"])
		var target_a: String = String(act["target"])
		b.pressed.connect(func():
			if kind_a == "tool":
				_close_modal()
				select_tool(target_a)
				if hud:
					hud._show_toast("도구를 골랐습니다. 지도에서 알맞은 곳을 눌러 짓습니다.", "🔨")
			else:
				open_action_modal(target_a)
		)
		row.add_child(b)
		var d := Label.new()
		d.text = String(act["desc"])
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		d.add_theme_color_override("font_color", Color("44403c"))
		d.add_theme_font_size_override("font_size", 12)
		row.add_child(d)

func _stat_hub_info(kind: String) -> Dictionary:
	match kind:
		"gold":
			return {"icon": "🪙 국고", "value": "%s냥" % _fmt_num(sim.gold),
				"why": "국고는 호조가 걷는 세금(결작세·시전세·군포세)과 저잣거리·교역의 관세로 쌓이고, 대역사 공사비와 인재 녹봉으로 나갑니다.\n세율을 올리면 금은 늘지만 민심이 떨어지고 백성의 수요가 줄어듭니다.\n현재 세율: 결작세 %d%% · 시전세 %d%% · 군포세 %d%%" % [sim.tax_rate_land, sim.tax_rate_market, sim.tax_rate_military],
				"actions": [
					{"label": "⚖️ 호조 조세 조율", "kind": "modal", "target": "tax", "desc": "세 가지 세율을 1~20%로 조절합니다."},
					{"label": "🏬 저잣거리(상업 구획)", "kind": "tool", "target": "zone_com", "desc": "가게가 늘수록 시전세가 늘어납니다."},
					{"label": "🛣️ 삼남로 교역", "kind": "modal", "target": "trade", "desc": "4대문 교역로가 열리면 관세가 들어옵니다."},
					{"label": "🏗️ 국책 대역사", "kind": "modal", "target": "mega_projects", "desc": "큰 공사의 비용과 진행 상황을 봅니다."},
				]}
		"rice":
			return {"icon": "🌾 군량미", "value": "%s석" % _fmt_num(sim.rice),
				"why": "군량미는 둔전(논)의 소출과 교역으로 쌓이고, 백성과 군사의 끼니·대역사 일꾼에게 쓰입니다.\n물이 닿는 둔전일수록 소출이 크고, 도로로 성문과 이어져야 운송 손실이 없습니다.",
				"actions": [
					{"label": "🌾 둔전(농업 구획)", "kind": "tool", "target": "zone_agr", "desc": "논을 일구어 소출을 늘립니다."},
					{"label": "💧 만석거(저수지)", "kind": "tool", "target": "manseokgeo", "desc": "물을 가두어 가뭄에도 둔전이 마르지 않게 합니다."},
					{"label": "🛣️ 삼남로 교역", "kind": "modal", "target": "trade", "desc": "교역로를 열어 곡물을 들여옵니다."},
					{"label": "📖 실학 연구", "kind": "modal", "target": "research", "desc": "구황작물·농법 연구로 소출을 올립니다."},
				]}
		"pop":
			return {"icon": "👥 인구", "value": "%s명" % _fmt_num(sim.population),
				"why": "인구는 민가(주거 구획)가 늘고 민심이 높으며 먹을 것이 넉넉할 때 늘어납니다.\n민가가 우물·화재 대비·구휼 시설과 가까울수록 안전해 더 많은 백성이 모입니다.\n대조선 문예 부흥(참 결말)에는 인구 100만 돌파가 필요합니다. 현재 %.1f%%" % (float(sim.population) / float(EndingManager.RENAISSANCE_MIN_POP) * 100.0),
				"actions": [
					{"label": "🏠 방·리(주거 구획)", "kind": "tool", "target": "zone_res", "desc": "민가를 지어 백성이 살 곳을 늘립니다."},
					{"label": "🪣 우물", "kind": "tool", "target": "well", "desc": "물을 길어 민가를 살기 좋게 합니다."},
					{"label": "🧯 멸화군", "kind": "tool", "target": "firefighter", "desc": "화재로부터 민가를 지킵니다."},
					{"label": "🍲 진휼소", "kind": "tool", "target": "jinhulso", "desc": "굶주린 백성이 떠나지 않게 구제합니다."},
				]}
		"loyalty":
			return {"icon": "❤️ 민심", "value": "%d%%" % sim.loyalty,
				"why": "민심은 세금이 가볍고 먹고살 만하며 나라가 안전할 때 오릅니다.\n세율이 높거나 재해·도적이 닥치면 떨어지고, 45% 아래로 내려가면 인구가 줄고 소요가 일어납니다.",
				"actions": [
					{"label": "⚖️ 조세 낮추기", "kind": "modal", "target": "tax", "desc": "세율을 낮추면 민심이 오릅니다."},
					{"label": "🙏 현륭원 친림", "kind": "modal", "target": "hyoryungwon", "desc": "효심을 보여 민심과 왕권을 올립니다."},
					{"label": "🍲 진휼소", "kind": "tool", "target": "jinhulso", "desc": "흉년에 굶주린 백성을 구제합니다."},
					{"label": "🗡️ 도적 소탕", "kind": "modal", "target": "bandit", "desc": "도적을 토벌해 치안을 지킵니다."},
				]}
		"authority":
			return {"icon": "👑 왕권·국방", "value": "%d" % sim.authority,
				"why": "왕권은 조정의 믿음직한 인재와 효심·의례(현륭원 친림, 을묘원행)로 오르고, 간신 등용과 세도·반정 움직임으로 떨어집니다.\n25 아래로 내려가면 사대부의 반정(실권 결말)이 일어날 수 있습니다.",
				"actions": [
					{"label": "👥 조정 인사", "kind": "modal", "target": "court", "desc": "믿을 만한 인재를 등용하고 간신을 물립니다."},
					{"label": "🙏 현륭원 친림", "kind": "modal", "target": "hyoryungwon", "desc": "해마다 참배하면 왕권이 오릅니다."},
					{"label": "🎉 을묘년 화성 원행", "kind": "modal", "target": "eulmyo", "desc": "1795년 대행사로 왕권과 민심을 크게 올립니다."},
					{"label": "👑 세자서연", "kind": "modal", "target": "crown_prince", "desc": "세자를 가르쳐 후계를 튼튼히 합니다."},
				].filter(func(act: Dictionary) -> bool: return not (act["target"] == "crown_prince" and _prince_closed()))}
		"flood":
			if ModernizationManager.is_active() and UrbanEvolutionManager.instance:
				var wum: UrbanEvolutionManager = UrbanEvolutionManager.instance
				return {"icon": "🚰 치수·상하수도", "value": "방재율 %d%% · 상하수도 보급률 %d%%" % [sim.flood_defense, wum.water_supply_rate()],
					"why": "근대 수도체제: 집수정·생활용수 공급시설·하수처리시설의 영향권 안에 든 가옥·상점 비율이 상하수도 보급률입니다. 영향권 밖에는 물방울이 뜨고, 물방울이 없으면 100%%입니다. 수도 연결 대공사를 마치면 영향권이 1.5배로 넓어집니다.\n보급률 50%% 이상이면 매달 민심 +1(100%%면 +2), 1945년 결산의 도시화 점수에도 들어갑니다. 홍수에 대비하는 치수 방재율(제방)은 그대로입니다.",
					"actions": [
						{"label": "🏗️ 수도 연결 대공사", "kind": "modal", "target": "water_works", "desc": "수원 시내 전체에 수도관을 묻는 큰 공사입니다." + ("(완공)" if wum.water_project_done() else "")},
						{"label": "🪣 우물 → 집수정", "kind": "modal", "target": "water_works", "desc": "마을 우물을 깨끗한 물을 모으는 집수정으로 바꿉니다." + ("(완료)" if wum.wells_upgraded else "")},
						{"label": "💧 저수지 → 생활용수 공급시설", "kind": "modal", "target": "water_works", "desc": "저수지 물을 걸러 집집마다 보내는 시설로 바꿉니다." + ("(완료)" if wum.reservoirs_upgraded else "")},
						{"label": "🚰 하수처리시설", "kind": "tool", "target": "sewage", "desc": "더러운 물을 걸러 수원천을 깨끗하게 지킵니다. (2x2, 매달 10,000냥 x 3달)"},
						{"label": "🧱 제방 쌓기", "kind": "tool", "target": "levee", "desc": "수원천 둑을 한 칸씩 직접 쌓습니다(홍수 대비)."},
					]}
			return {"icon": "🌊 치수 방재율", "value": "%d%%" % sim.flood_defense,
				"why": "수원천이 불어나는 장마철에 논밭과 민가를 지키는 힘입니다.\n석축 제방을 쌓고 수문(화홍문·남수문)과 저수지(만석거)를 지을수록 올라갑니다.",
				"actions": [
					{"label": "🏗️ 석축 제방 대역사", "kind": "modal", "target": "mega_projects", "desc": "수원천 양안 제방을 한꺼번에 쌓는 큰 공사입니다."},
					{"label": "🧱 제방 쌓기", "kind": "tool", "target": "levee", "desc": "수원천 둑을 한 칸씩 직접 쌓습니다."},
					{"label": "💧 저수지", "kind": "tool", "target": "reservoir", "desc": "물을 가두어 홍수의 힘을 덜어 냅니다."},
					{"label": "🌉 홍예성문(수문)", "kind": "tool", "target": "gate", "desc": "수원천 위에 수문을 세워 물길을 다스립니다."},
				]}
	return {"icon": "", "value": "", "why": "", "actions": []}

func _fmt_num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return ("-" if n < 0 else "") + out

var tech_tree_popup: TechTreePopup = null
var crown_prince_popup: CrownPrincePopup = null
var uigwe_popup: UigwePopup = null

func open_tech_tree_popup() -> void:
	if tech_tree_popup == null:
		var scene: PackedScene = load("res://scenes/TechTreePopup.tscn")
		if scene != null:
			tech_tree_popup = scene.instantiate() as TechTreePopup
			add_child(tech_tree_popup)
			tech_tree_popup.setup(sim, court)
	if tech_tree_popup != null:
		tech_tree_popup.open_popup()

func open_crown_prince_popup() -> void:
	if _prince_closed():
		return # 1800년 엔딩(순조 즉위) 뒤에는 세자 집무실도 없음
	if crown_prince_popup == null:
		var scene: PackedScene = load("res://scenes/CrownPrincePopup.tscn")
		if scene != null:
			crown_prince_popup = scene.instantiate() as CrownPrincePopup
			add_child(crown_prince_popup)
			crown_prince_popup.setup(sim, court)
	if crown_prince_popup != null:
		crown_prince_popup.open_popup()

func open_uigwe_popup() -> void:
	if uigwe_popup == null:
		var scene: PackedScene = load("res://scenes/UigwePopup.tscn")
		if scene != null:
			uigwe_popup = scene.instantiate() as UigwePopup
			add_child(uigwe_popup)
			uigwe_popup.setup(sim, court)
	if uigwe_popup != null:
		uigwe_popup.open_popup()


## PORT-TRACE [클릭 씹힘 수정]: 사용자 제보 — "국책 대역사 착공 버튼을 눌렀는데 바로 반응하지 않고 한참 뒤에
## 진행된다". 열린 창은 게임 하루(틱)마다 내용을 통째로 지우고 새로 만드는데(1배속 초당 1번, 3배속 초당 3번),
## 마우스를 누른 뒤 떼기 전에 버튼이 새 버튼으로 바뀌면 그 클릭이 버려져 여러 번 눌러야 했다.
## 이제 클릭하는 중이거나 마우스가 창 안의 버튼 위에 있으면 새로 만들기를 미뤘다가, 손을 떼거나 버튼에서
## 벗어나면 그때 한 번 반영한다.
var _modal_refresh_pending := false
var _restore_scroll_v := -1

func _refresh_menu_buttons() -> void:
	if not (_modal.visible if _modal else false) or _modal_no_refresh:
		return
	if _modal_busy_with_pointer():
		_modal_refresh_pending = true
		return
	_modal_refresh_pending = false
	if not _builder.is_valid():
		return # 만들 내용이 아직 정해지지 않은 상태(불러오기 직후 등)에서는 다시 만들지 않는다
	# 다시 만들면 스크롤이 맨 위로 튀어(조정 인사처럼 긴 목록) 누르려던 버튼이 커서 밑에서 사라졌다 — 위치 유지
	var sc := _body.get_parent() as ScrollContainer
	var keep_v := sc.scroll_vertical if sc else 0
	_builder.call()
	if sc and keep_v > 0:
		sc.scroll_vertical = keep_v
		_restore_scroll_v = keep_v # 새 내용의 크기가 잡힌 다음 프레임에 한 번 더 맞춘다

func _modal_busy_with_pointer() -> bool:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return true
	var hov := get_viewport().gui_get_hovered_control()
	return hov != null and (hov is BaseButton or hov is Range) and _modal.is_ancestor_of(hov)

func _process(_delta: float) -> void:
	if _restore_scroll_v >= 0:
		var sc := _body.get_parent() as ScrollContainer
		if sc:
			sc.scroll_vertical = _restore_scroll_v
		_restore_scroll_v = -1
	if _modal_refresh_pending:
		_flush_modal_refresh()

func _flush_modal_refresh() -> void:
	if _modal_refresh_pending and not _modal_busy_with_pointer():
		_refresh_menu_buttons()

func _refresh_policy_buttons() -> void:
	if sim == null:
		return
	if _policy_bandit_btn:
		if sim.bandit_active:
			_policy_bandit_btn.modulate = Color(1.0, 0.35, 0.35)
		elif sim.bandit_suppression_cooldown > 0.0:
			_policy_bandit_btn.modulate = Color(0.65, 0.95, 0.70)
		else:
			_policy_bandit_btn.modulate = Color.WHITE

	if _dock_policy_btn:
		if sim.bandit_active:
			_dock_policy_btn.modulate = Color(1.0, 0.45, 0.45)
		else:
			_dock_policy_btn.modulate = Color.WHITE

func is_modal_open() -> bool:
	return (_modal != null and _modal.visible) or (_modal_backdrop != null and _modal_backdrop.visible)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_modal_open():
				_close_modal()
				get_viewport().set_input_as_handled()
			elif _public_popup and _public_popup.visible:
				_public_popup.visible = false
				get_viewport().set_input_as_handled()
			elif _terrain_popup and _terrain_popup.visible:
				_terrain_popup.visible = false
				get_viewport().set_input_as_handled()
			elif _policy_popup and _policy_popup.visible:
				_policy_popup.visible = false
				get_viewport().set_input_as_handled()

# ------------------------------------------------------------ 모달 골격 (닥종이 한지 베이지 & 옻칠 목재 프레임)
func _build_modal() -> void:
	# 1. 배경 어둡게 덮는 딤 오버레이
	_modal_backdrop = ColorRect.new()
	_modal_backdrop.visible = false
	_modal_backdrop.color = Color(0, 0, 0, 0.65)
	_modal_backdrop.anchor_right = 1.0
	_modal_backdrop.anchor_bottom = 1.0
	_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_modal()
	)
	add_child(_modal_backdrop)

	# 2. 메인 모달 윈도우 (충분한 너비 840px로 확장하여 가로 스크롤 및 버튼 잘림 원천 방지)
	_modal = PanelContainer.new()
	_modal.visible = false
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.anchor_left = 0.5
	_modal.anchor_top = 0.5
	_modal.anchor_right = 0.5
	_modal.anchor_bottom = 0.5
	_modal.offset_left = -420.0
	_modal.offset_top = -240.0
	_modal.offset_right = 420.0
	_modal.offset_bottom = 240.0
	_modal.custom_minimum_size = Vector2(840, 480)
	add_child(_modal)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fef3c7") # 닥종이 한지 베이지
	sb.border_color = Color("451a03") # 옻칠 목재 프레임 테두리
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.7)
	sb.shadow_size = 18
	sb.set_content_margin_all(14)
	_modal.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_modal.add_child(vb)

	# 제목 표시줄: 단청 주색 패널과 금박 텍스트 + 우측 상단 닫기 [✕] 버튼
	var title_panel := PanelContainer.new()
	var t_sb := StyleBoxFlat.new()
	t_sb.bg_color = Color("991b1b") # 단청 주홍
	t_sb.set_content_margin_all(8)
	t_sb.set_corner_radius_all(4)
	title_panel.add_theme_stylebox_override("panel", t_sb)
	vb.add_child(title_panel)

	var title_hb := HBoxContainer.new()
	title_panel.add_child(title_hb)

	var title_spacer := Control.new()
	title_spacer.custom_minimum_size = Vector2(28, 0)
	title_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_hb.add_child(title_spacer)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_color_override("font_color", Color("fef08a")) # 금박 글씨
	_title.add_theme_font_size_override("font_size", 17)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_hb.add_child(_title)

	var top_close_btn := Button.new()
	top_close_btn.text = "✕"
	top_close_btn.custom_minimum_size = Vector2(28, 28)
	top_close_btn.tooltip_text = "닫기 (Esc 글쇠)"
	top_close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var tc_sb := StyleBoxFlat.new()
	tc_sb.bg_color = Color(0.18, 0.05, 0.05, 0.8)
	tc_sb.border_color = Color(0.98, 0.85, 0.35, 0.8)
	tc_sb.set_border_width_all(1)
	tc_sb.set_corner_radius_all(4)
	top_close_btn.add_theme_stylebox_override("normal", tc_sb)
	var tc_hsb := tc_sb.duplicate()
	tc_hsb.bg_color = Color(0.85, 0.15, 0.15, 1.0)
	tc_hsb.border_color = Color(1.0, 1.0, 0.6)
	top_close_btn.add_theme_stylebox_override("hover", tc_hsb)
	top_close_btn.add_theme_color_override("font_color", Color("fef08a"))
	top_close_btn.pressed.connect(_close_modal)
	title_hb.add_child(top_close_btn)

	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(810, 340)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vb.add_child(sc)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	sc.add_child(_body)

	# 하단 닫기 버튼: 붉은 인장 도장 낙관 스타일
	var btn_hb := HBoxContainer.new()
	btn_hb.alignment = BoxContainer.ALIGNMENT_END
	vb.add_child(btn_hb)

	var close_btn := Button.new()
	close_btn.text = "閉 (닫기)"
	close_btn.custom_minimum_size = Vector2(110, 36)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var c_sb := StyleBoxFlat.new()
	c_sb.bg_color = Color("991b1b")
	c_sb.border_color = Color("451a03")
	c_sb.set_border_width_all(2)
	c_sb.set_corner_radius_all(4)
	c_sb.set_content_margin_all(6)
	close_btn.add_theme_stylebox_override("normal", c_sb)

	var c_hsb := c_sb.duplicate()
	c_hsb.bg_color = Color(0.75, 0.15, 0.15, 1.0)
	c_hsb.border_color = Color(0.98, 0.85, 0.35)
	close_btn.add_theme_stylebox_override("hover", c_hsb)

	close_btn.add_theme_color_override("font_color", Color("fef08a"))
	close_btn.pressed.connect(_close_modal)
	btn_hb.add_child(close_btn)

func _open(title: String, builder: Callable) -> void:
	# 이름을 받는 중인 성문 창이 다른 창에 가려지면, 그 문을 대기열 맨 앞에 되돌려 나중에 다시 묻는다
	if _gate_naming_active:
		_gate_naming_active = false
		_gate_naming_queue.push_front(_gate_naming_pos)
	_clear_body()
	_title.text = title
	_builder = builder
	_modal_no_refresh = false
	_modal_backdrop.visible = true
	_modal.visible = true
	_builder.call()

func _close_modal() -> void:
	_modal_backdrop.visible = false
	_modal.visible = false
	if _gate_naming_active:
		_gate_naming_active = false
		_open_next_gate_naming()

func _clear_body() -> void:
	for c in _body.get_children():
		c.queue_free()

# ------------------------------------------------------------ 홍예성문 사용자 명명 모달
func open_gate_naming_modal(pos: Vector2i, default_name: String, desc: String, suggestions: Array) -> void:
	if _gate_naming_active:
		if not (pos in _gate_naming_queue):
			_gate_naming_queue.append(pos)
		return
	_show_gate_naming(pos, default_name, desc, suggestions)

func _show_gate_naming(pos: Vector2i, default_name: String, desc: String, suggestions: Array) -> void:
	var title := "어명: 신축 홍예성문(城門) 명명"
	if not _gate_naming_queue.is_empty():
		title += " — 뒤에 %d곳 더" % _gate_naming_queue.size()
	_open(title, func():
		_build_gate_naming(pos, default_name, desc, suggestions)
	)
	_modal_no_refresh = true
	_gate_naming_active = true
	_gate_naming_pos = pos

func _open_next_gate_naming() -> void:
	while not _gate_naming_queue.is_empty():
		var pos: Vector2i = _gate_naming_queue.pop_front()
		if not grid.in_bounds(pos.x, pos.y) or grid.grid[pos.y][pos.x]["building"] != "gate":
			continue # 그 사이 철거·되돌리기된 문은 건너뛴다
		if gate_info_provider.is_valid():
			var info: Dictionary = gate_info_provider.call(pos)
			_show_gate_naming(pos, info["default_name"], info["desc"], info["suggestions"])
		else:
			_show_gate_naming(pos, "새 성문", "", [])
		return

func _build_gate_naming(pos: Vector2i, default_name: String, desc: String, suggestions: Array) -> void:
	_clear_body()

	var info_lbl := Label.new()
	info_lbl.text = "성곽과 삼남대로가 교차하는 길목에 웅장한 홍예성문(虹霓城門)이 세워졌습니다.\n성문의 이름을 친히 지어 현판을 하사하십시오."
	info_lbl.add_theme_color_override("font_color", Color("451a03"))
	info_lbl.add_theme_font_size_override("font_size", 14)
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(info_lbl)

	# 고증 안내 박스
	var hist_box := PanelContainer.new()
	var h_sb := StyleBoxFlat.new()
	h_sb.bg_color = Color(0.94, 0.90, 0.82, 1.0)
	h_sb.border_color = Color(0.65, 0.50, 0.35, 1.0)
	h_sb.set_border_width_all(1)
	h_sb.set_corner_radius_all(4)
	h_sb.set_content_margin_all(8)
	hist_box.add_theme_stylebox_override("panel", h_sb)
	_body.add_child(hist_box)

	var hist_lbl := Label.new()
	hist_lbl.text = "역사적 배경 및 고증:\n" + desc
	hist_lbl.add_theme_color_override("font_color", Color("2a1a08"))
	hist_lbl.add_theme_font_size_override("font_size", 12)
	hist_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hist_box.add_child(hist_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "실제 추천 성문 이름 (누르면 자동 입력):"
	sub_lbl.add_theme_color_override("font_color", Color("78350f"))
	sub_lbl.add_theme_font_size_override("font_size", 12)
	_body.add_child(sub_lbl)

	var edit := LineEdit.new()
	edit.text = default_name
	edit.custom_minimum_size = Vector2(300, 36)
	edit.add_theme_font_size_override("font_size", 15)

	var sugg_hb := HBoxContainer.new()
	sugg_hb.add_theme_constant_override("separation", 6)
	_body.add_child(sugg_hb)

	for s_name in suggestions:
		var btn := Button.new()
		btn.text = s_name
		btn.custom_minimum_size = Vector2(90, 30)
		btn.add_theme_font_size_override("font_size", 12)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func():
			edit.text = s_name
		)
		sugg_hb.add_child(btn)

	var input_lbl := Label.new()
	input_lbl.text = "성문 현판명 입력:"
	input_lbl.add_theme_color_override("font_color", Color("451a03"))
	input_lbl.add_theme_font_size_override("font_size", 13)
	_body.add_child(input_lbl)

	_body.add_child(edit)
	edit.grab_focus()
	edit.select_all()

	var confirm_btn := Button.new()
	confirm_btn.text = "현판 하사 (성문 명명 확정)"
	confirm_btn.custom_minimum_size = Vector2(180, 38)
	confirm_btn.add_theme_font_size_override("font_size", 13)
	confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var warn_lbl := Label.new()
	warn_lbl.add_theme_color_override("font_color", Color("b91c1c"))
	warn_lbl.add_theme_font_size_override("font_size", 12)
	warn_lbl.visible = false
	_body.add_child(warn_lbl)

	var c_fn := func():
		var final_name := edit.text.strip_edges()
		if final_name == "":
			final_name = default_name
		# 같은 이름의 성문이 두 개 생기지 않게 막는다(괄호 앞 한글 이름 기준)
		var base := CityLayer.gate_base_name(final_name)
		for yy in range(grid.size):
			for xx in range(grid.size):
				if Vector2i(xx, yy) == pos:
					continue
				var gt: Dictionary = grid.grid[yy][xx]
				if gt["building"] == "gate" and CityLayer.gate_base_name(gt.get("gate_name", "")) == base:
					warn_lbl.text = "'%s'은(는) 이미 (%d,%d) 성문의 이름입니다. 다른 이름을 지어 주세요." % [base, xx, yy]
					warn_lbl.visible = true
					edit.grab_focus()
					return
		if grid.in_bounds(pos.x, pos.y):
			grid.grid[pos.y][pos.x]["gate_name"] = final_name
			if final_name.contains("장안"):
				grid.update_gate_position("jangan", pos)
			elif final_name.contains("팔달"):
				grid.update_gate_position("paldal", pos)
			elif final_name.contains("화서"):
				grid.update_gate_position("hwaseo", pos)
			elif final_name.contains("창룡"):
				grid.update_gate_position("changryong", pos)
			elif final_name.contains("화홍"):
				grid.update_gate_position("hwahong", pos)
			elif final_name.contains("남수"):
				grid.update_gate_position("namsu", pos)
			grid.emit_signal("grid_changed")
			if sim:
				sim.sync_mega_projects_with_grid(grid)
		_close_modal()
		if hud:
			hud._show_toast("[%s] 현판이 성문에 높이 걸렸습니다!" % final_name, "⛩️")
		# 월드 마커 등록 연동 (지붕 처마 상단 단일 현판 배치)
		var main_node: Node = get_parent()
		if main_node and "world_markers" in main_node and main_node.world_markers != null:
			var wpos: Vector2 = Vector2.ZERO
			if "city" in main_node and main_node.city != null:
				wpos = main_node.city.cell_center(float(pos.x) + 0.5, float(pos.y) + 0.5)
			var norm_id: String = WorldMarkerManager.normalize_building_id("gate_%d_%d" % [pos.x, pos.y], final_name)
			wpos.y -= WorldMarkerManager.get_roof_offset_y(norm_id, final_name)
			main_node.world_markers.register_signboard(norm_id, wpos, final_name)
	confirm_btn.pressed.connect(c_fn)
	edit.text_submitted.connect(func(_t): c_fn.call())
	_body.add_child(confirm_btn)

## 수원천 수문(남수문, 화홍문) 어제 현판 하사 축하 모달
func open_water_gate_signboard_modal(facility_id: String, fac_name: String) -> void:
	_open("어명: [어제 현판 하사]", func():
		_build_water_gate_signboard(facility_id, fac_name)
	)

func _build_water_gate_signboard(facility_id: String, fac_name: String) -> void:
	_clear_body()

	var celebr_lbl := Label.new()
	celebr_lbl.text = "【어제 현판 하사】\n정조 대왕께서 %s의 현판을 친히 내리셨습니다!" % fac_name
	celebr_lbl.add_theme_color_override("font_color", Color("78350f"))
	celebr_lbl.add_theme_font_size_override("font_size", 15)
	celebr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	celebr_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(celebr_lbl)

	# 고증 안내 박스
	var hist_box := PanelContainer.new()
	var h_sb := StyleBoxFlat.new()
	h_sb.bg_color = Color(0.96, 0.93, 0.86, 1.0)
	h_sb.border_color = Color("b45309")
	h_sb.set_border_width_all(2)
	h_sb.set_corner_radius_all(6)
	h_sb.set_content_margin_all(10)
	hist_box.add_theme_stylebox_override("panel", h_sb)
	_body.add_child(hist_box)

	var hist_desc := ""
	if facility_id == "namsu_mun":
		hist_desc = "수원천 남쪽 하류에 축조된 남수문(南水門)은 평시에는 물길을 터 백성의 수해를 막고, 유사시에는 웅장한 포루와 함께 화성의 남쪽 수로를 철통같이 방어하는 군사 요새입니다.\n정조 대왕께서 남수문의 위용을 치하하며 친히 어제 현판을 하사하셨습니다."
	elif facility_id == "hwahong_mun":
		hist_desc = "수원천 북쪽 상류에 7개의 무지개 홍예문으로 세워진 화홍문(華虹門)은 격류를 다스려 일곱 줄기 무지개 물보라를 일으키는 '화홍일민(華虹日觀)'의 절경이자, 북쪽 수로를 굳게 지키는 수문입니다.\n정조 대왕께서 화홍문의 빼어남과 견고함을 기리며 어제 현판을 내리셨습니다."
	else:
		hist_desc = "수원천의 중심을 잇는 석교에 정조 대왕께서 친히 현판을 하사하시어 백성들의 통행과 화성 행차의 길을 밝히셨습니다."

	var hist_lbl := Label.new()
	hist_lbl.text = "조선왕조실록 및 화성성역의궤 고증:\n\n" + hist_desc
	hist_lbl.add_theme_color_override("font_color", Color("292524"))
	hist_lbl.add_theme_font_size_override("font_size", 13)
	hist_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hist_box.add_child(hist_lbl)

	# 혜택 안내
	var benefit_lbl := Label.new()
	benefit_lbl.text = "• 국방 효과: 성 방호력(체력/내구도) +10 상승 (화적 침입 시 방어막 작동)\n• 치수 효과: 수원천 수해 방재력 대폭 증가"
	benefit_lbl.add_theme_color_override("font_color", Color("166534"))
	benefit_lbl.add_theme_font_size_override("font_size", 12)
	_body.add_child(benefit_lbl)

	var confirm_btn := Button.new()
	confirm_btn.text = "어제 현판 봉안 및 확인 (성 방호력 +10)"
	confirm_btn.custom_minimum_size = Vector2(220, 38)
	confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	confirm_btn.pressed.connect(_close_modal)
	_body.add_child(confirm_btn)

# ------------------------------------------------------------ 각 모달 빌더들
func _build_retainers() -> void:
	_clear_body()
	var desc := Label.new()
	desc.text = "규장각 실학자와 관료를 등용하여 성역을 추진하십시오. (등용/해임)"
	desc.add_theme_color_override("font_color", Color("1c1917"))
	_body.add_child(desc)

	# 규장각 의궤 편찬으로 가는 길(1796년 이후 원행을묘정리의궤·화성성역의궤)
	var ug_btn := Button.new()
	ug_btn.text = "📚 규장각 의궤 편찬 (원행을묘정리의궤·화성성역의궤)"
	ug_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ug_btn.pressed.connect(func(): open_action_modal("uigwe"))
	_body.add_child(ug_btn)

	# PORT-TRACE [인재 랜덤 풀·녹봉·학문력]: 고정 목록 대신 — 학문력 게이지, 이번에 나타난 후보(김판관 평·녹봉),
	# 조정에 있는 인재(실제 능력·녹봉·해임), 녹봉 합계. 후보의 실제 능력은 등용해야 드러난다(김판관 평은 틀릴 수 있음).
	var ac_lbl := Label.new()
	ac_lbl.text = "📖 학문력 %d / 100   ·   김판관 천거 정확도 %d%%   ·   녹봉 합계 매달 %d냥   ·   연구 비용 할인 %d%%" % [sim.academic, int(court.recommend_accuracy()), court.total_salary(), 100 - int(round(float(court.research_cost(100))))]
	ac_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ac_lbl.add_theme_color_override("font_color", Color("5a2d0c"))
	_body.add_child(ac_lbl)
	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.value = sim.academic
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	_body.add_child(bar)
	# PORT-TRACE [서학 디버프]: 천주교당 현황 (무예 사열은 연무대에서 거행)
	if west:
		var wl := Label.new()
		var nch: int = west.chapels().size()
		wl.text = "✝ 천주교당 %d곳 — %s" % [nch, ("왕권 -%d/달 (보유론·서기수용론 연구로 해소)" % mini(3, nch)) if (nch > 0 and west.debuff_active()) else "왕권 감소 없음"]
		wl.add_theme_color_override("font_color", Color("7a1f14") if (nch > 0 and west.debuff_active()) else Color("1e5a2a"))
		_body.add_child(wl)
	var h1 := Label.new()
	h1.text = "── 이번에 나타난 인재 후보 (%d) ──" % court.candidates.size()
	h1.add_theme_color_override("font_color", Color("7a1f14"))
	_body.add_child(h1)
	if court.candidates.is_empty():
		var none := Label.new()
		none.text = "아직 천거된 인재가 없습니다. 학문력과 교육 시설이 높을수록 자주, 더 뛰어난 인재가 나타납니다."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.add_theme_color_override("font_color", Color("57534e"))
		_body.add_child(none)
	for c: Dictionary in court.candidates:
		var cid: String = c["id"]
		var info: Dictionary = CourtSystem.SCHOLARS[cid]
		var hb := HBoxContainer.new()
		_body.add_child(hb)
		# 48x48 고품질 도트 초상화
		var p_icon := TextureRect.new()
		p_icon.custom_minimum_size = Vector2(40, 40)
		p_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		p_icon.texture = SpriteCacheManager.get_named_character_texture(cid, true)
		hb.add_child(p_icon)
		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.scroll_active = false
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if ThemeManager.get_base_font():
			rtl.add_theme_font_override("normal_font", ThemeManager.get_base_font())
		if ThemeManager.get_title_font():
			rtl.add_theme_font_override("bold_font", ThemeManager.get_title_font())
		rtl.add_theme_font_size_override("normal_font_size", 14)
		rtl.add_theme_font_size_override("bold_font_size", 16)
		rtl.add_theme_color_override("default_color", Color("1c1917"))
		var s_salary: int = court.get_scholar_salary(cid) if court != null else CourtSystem.calculate_scholar_salary(int(info["salary"]))
		rtl.text = "[b][color=#1d4ed8]%s[/color][/b] — 녹봉 매달 %d냥 (%d개월 뒤 떠남)\n  김판관: \"%s\"" % [info["name"], s_salary, int(c["turns"]), c["praise"]]
		hb.add_child(rtl)
		var btn := Button.new()
		btn.text = "등용"
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func():
			var msg := court.hire_candidate(cid)
			if hud and msg != "":
				hud._show_toast(msg, "📜")
			sim.emit_signal("state_updated", sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)
			_builder.call()
		)
		hb.add_child(btn)
	var h2 := Label.new()
	h2.text = "── 조정에 있는 인재 ──"
	h2.add_theme_color_override("font_color", Color("7a1f14"))
	_body.add_child(h2)
	for sid in CourtSystem.SCHOLARS:
		var s_info: Dictionary = CourtSystem.SCHOLARS[sid]
		if not sim.retainers.get(s_info["key"], false):
			continue
		var hb2 := HBoxContainer.new()
		_body.add_child(hb2)
		# 48x48 고품질 도트 초상화
		var p_icon2 := TextureRect.new()
		p_icon2.custom_minimum_size = Vector2(40, 40)
		p_icon2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		p_icon2.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		p_icon2.texture = SpriteCacheManager.get_named_character_texture(sid, true)
		hb2.add_child(p_icon2)
		var rtl2 := RichTextLabel.new()
		rtl2.bbcode_enabled = true
		rtl2.fit_content = true
		rtl2.scroll_active = false
		rtl2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rtl2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if ThemeManager.get_base_font():
			rtl2.add_theme_font_override("normal_font", ThemeManager.get_base_font())
		if ThemeManager.get_title_font():
			rtl2.add_theme_font_override("bold_font", ThemeManager.get_title_font())
		rtl2.add_theme_font_size_override("normal_font_size", 14)
		rtl2.add_theme_font_size_override("bold_font_size", 16)
		rtl2.add_theme_color_override("default_color", Color("1c1917"))
		var s_salary2: int = court.get_scholar_salary(sid) if court != null else CourtSystem.calculate_scholar_salary(int(s_info["salary"]))
		rtl2.text = "[%s급] [b][color=#1d4ed8]%s[/color][/b] — %s (녹봉 매달 %d냥)" % [s_info["grade"], s_info["name"], s_info["desc"], s_salary2]
		hb2.add_child(rtl2)
		var b2 := Button.new()
		b2.text = "해임"
		b2.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var sid2: String = sid
		b2.pressed.connect(func():
			var msg2 := court.dismiss_scholar(sid2)
			if hud and msg2 != "":
				hud._show_toast(msg2, "📜")
			_builder.call()
		)
		hb2.add_child(b2)

## PORT-TRACE [시기별 추천·의궤 편찬]: 원행을묘정리의궤·화성성역의궤 편찬
func _build_uigwe() -> void:
	_clear_body()
	var desc := Label.new()
	desc.text = "규장각에서 나라의 큰일을 그림과 글로 자세히 기록한 책, 의궤(儀軌)를 펴냅니다.\n학문력 연동 장기 국책 사업으로 개편된 규장각 의궤 편찬 도감 창을 열 수 있습니다."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color("1c1917"))
	_body.add_child(desc)

	var launch_btn := Button.new()
	launch_btn.text = "📖 규장각 의궤 편찬 국책 창 열기"
	launch_btn.custom_minimum_size = Vector2(0, 38)
	launch_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	launch_btn.pressed.connect(func():
		_close_modal()
		open_uigwe_popup()
	)
	_body.add_child(launch_btn)
	_body.add_child(HSeparator.new())

	for u: Dictionary in CourtSystem.UIGWE_LIST:
		var uid: String = u["id"]
		var done: bool = court.uigwe.get(uid, false)
		if sim and sim.uigwe_manager:
			done = done or sim.uigwe_manager.is_completed(uid)
		var why: String = court.uigwe_block_reason(uid)
		var hb := HBoxContainer.new()
		_body.add_child(hb)
		var lbl := Label.new()
		lbl.text = "[%s] %s — %s (금 %d냥)" % ["간행 완료" if done else ("편찬 가능" if why == "" else "대기"), u["name"], u["desc"], int(u["cost"])]
		if not done and why != "":
			lbl.text += "\n  ※ " + why
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", Color("1c1917"))
		hb.add_child(lbl)
		var btn := Button.new()
		btn.text = "간행됨" if done else "편찬"
		btn.disabled = done or why != ""
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func():
			_close_modal()
			open_uigwe_popup()
		)
		hb.add_child(btn)

func _build_research() -> void:
	_clear_body()

	var tech_mgr: TechTreeManager = sim.tech_tree if sim != null else null
	var acad_power: int = CityStats.get_academic_power()
	if acad_power == 0 and sim != null and sim.academic > 0:
		acad_power = sim.academic

	var research_speed: int = 1 + clampi(int(float(acad_power) / 10.0), 0, 9)

	var is_jeong_hired: bool = false
	if sim != null and "retainers" in sim and sim.retainers is Dictionary:
		is_jeong_hired = ScholarManager.has_scholar("jeong_yakyong", sim.retainers)

	var cur_id: String = tech_mgr.current_researching if tech_mgr != null else ""
	var cur_status: int = tech_mgr.research_status if tech_mgr != null else TechTreeManager.ResearchStatus.IDLE

	var ongoing_cost: int = 0
	if cur_id != "" and tech_mgr != null:
		if cur_status == TechTreeManager.ResearchStatus.ACTIVE:
			ongoing_cost = tech_mgr.get_research_turn_cost(cur_id, sim)

	# 1. 상단 대시보드 박스
	var dash_panel := PanelContainer.new()
	var dash_sb := StyleBoxFlat.new()
	dash_sb.bg_color = Color(0.92, 0.90, 0.84, 0.95)
	dash_sb.border_color = Color(0.78, 0.74, 0.65, 1.0)
	dash_sb.set_border_width_all(1)
	dash_sb.set_corner_radius_all(6)
	dash_sb.set_content_margin_all(10)
	dash_panel.add_theme_stylebox_override("panel", dash_sb)
	_body.add_child(dash_panel)

	var dash_vbox := VBoxContainer.new()
	dash_vbox.add_theme_constant_override("separation", 6)
	dash_panel.add_child(dash_vbox)

	var stat_hbox := HBoxContainer.new()
	stat_hbox.add_theme_constant_override("separation", 16)
	dash_vbox.add_child(stat_hbox)

	var acad_lbl := Label.new()
	acad_lbl.text = "🏛️ 도시 총 학문력: %d / 100" % acad_power
	acad_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acad_lbl.add_theme_color_override("font_color", Color("15803d"))
	stat_hbox.add_child(acad_lbl)

	var speed_lbl := Label.new()
	speed_lbl.text = "⚡ 연구 속도: 매달 +%d%%" % research_speed
	speed_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_lbl.add_theme_color_override("font_color", Color("0369a1"))
	stat_hbox.add_child(speed_lbl)

	var cost_lbl := Label.new()
	cost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ongoing_cost > 0:
		cost_lbl.text = "💰 연구 재정: 매달 -%d냥" % ongoing_cost
		cost_lbl.add_theme_color_override("font_color", Color("b91c1c"))
	elif cur_status == TechTreeManager.ResearchStatus.PAUSED_NO_FUNDS:
		cost_lbl.text = "💰 연구 재정: 재정 부족 일시 정지"
		cost_lbl.add_theme_color_override("font_color", Color("ea580c"))
	elif cur_status == TechTreeManager.ResearchStatus.PAUSED_NO_SCHOLAR:
		cost_lbl.text = "💰 연구 재정: 인재 공백 일시 정지"
		cost_lbl.add_theme_color_override("font_color", Color("ea580c"))
	else:
		cost_lbl.text = "💰 연구 재정: 매달 0냥 (미진행)"
		cost_lbl.add_theme_color_override("font_color", Color("4b5563"))
	stat_hbox.add_child(cost_lbl)

	var buff_lbl := Label.new()
	if is_jeong_hired:
		buff_lbl.text = "✨ [적용 효과: 다산 정약용 — 연구비 30% 감면 적용 중 -> 매달 700냥]"
		buff_lbl.add_theme_color_override("font_color", Color("15803d"))
	else:
		buff_lbl.text = "📜 [적용 효과: 없음 — 기본 연구비 매달 1,000냥 소모]"
		buff_lbl.add_theme_color_override("font_color", Color("6b7280"))
	dash_vbox.add_child(buff_lbl)

	# 2. 과제 목록
	for res: Dictionary in CourtSystem.RESEARCH_LIST:
		var rid: String = str(res.get("id", ""))
		var rname: String = str(res.get("name", ""))
		var rdesc: String = str(res.get("desc", ""))
		var done: bool = bool(court.research.get(rid, false)) or (tech_mgr != null and tech_mgr.is_completed(rid))
		var is_active: bool = (cur_id == rid)
		var progress_val: float = tech_mgr.get_progress(rid) if tech_mgr != null else 0.0

		var prereq: Dictionary = tech_mgr.check_scholar_prerequisite(rid, sim) if tech_mgr != null else {"satisfied": true, "name": ""}
		var prereq_sat: bool = bool(prereq.get("satisfied", true))
		var req_name: String = str(prereq.get("name", ""))

		var item_panel := PanelContainer.new()
		var p_sb := StyleBoxFlat.new()
		p_sb.set_corner_radius_all(6)
		p_sb.set_content_margin_all(8)

		if done:
			p_sb.bg_color = Color(0.93, 0.96, 0.93, 0.95)
			p_sb.border_color = Color("15803d")
			p_sb.set_border_width_all(1)
		elif is_active:
			if cur_status == TechTreeManager.ResearchStatus.PAUSED_NO_FUNDS or cur_status == TechTreeManager.ResearchStatus.PAUSED_NO_SCHOLAR:
				p_sb.bg_color = Color(0.99, 0.93, 0.90, 0.95)
				p_sb.border_color = Color("ea580c")
				p_sb.set_border_width_all(2)
			else:
				p_sb.bg_color = Color(0.92, 0.96, 0.98, 0.95)
				p_sb.border_color = Color("0284c7")
				p_sb.set_border_width_all(2)
		else:
			p_sb.bg_color = Color(0.98, 0.97, 0.94, 0.95)
			p_sb.border_color = Color(0.82, 0.79, 0.72, 1.0)
			p_sb.set_border_width_all(1)

		item_panel.add_theme_stylebox_override("panel", p_sb)
		_body.add_child(item_panel)

		var card_vbox := VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 4)
		item_panel.add_child(card_vbox)

		var top_hb := HBoxContainer.new()
		card_vbox.add_child(top_hb)

		var title_lbl := Label.new()
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if done:
			title_lbl.text = "[완료] " + rname
			title_lbl.add_theme_color_override("font_color", Color("15803d"))
		elif is_active:
			title_lbl.text = "[연구 중] " + rname
			title_lbl.add_theme_color_override("font_color", Color("0369a1"))
		else:
			title_lbl.text = "[미연구] " + rname
			title_lbl.add_theme_color_override("font_color", Color("1f2937"))
		top_hb.add_child(title_lbl)

		# 우측 버튼 분기
		if done:
			var done_btn := Button.new()
			done_btn.text = "완료됨"
			done_btn.disabled = true
			done_btn.custom_minimum_size = Vector2(120, 32)
			top_hb.add_child(done_btn)
		elif is_active:
			var stop_btn := Button.new()
			stop_btn.text = "연구 중단"
			stop_btn.custom_minimum_size = Vector2(120, 32)
			stop_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			stop_btn.pressed.connect(func():
				if tech_mgr != null:
					tech_mgr.stop_research(rid)
				sim.emit_signal("state_updated", sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)
				_builder.call()
			)
			top_hb.add_child(stop_btn)
		else:
			var start_btn := Button.new()
			start_btn.custom_minimum_size = Vector2(140, 32)
			if not prereq_sat:
				start_btn.text = "[🔒 %s 필요]" % req_name
				start_btn.disabled = true
				start_btn.tooltip_text = "조정에서 [%s]을(를) 등용해야 착수할 수 있습니다." % req_name
			else:
				var cost_preview: int = 700 if is_jeong_hired else 1000
				start_btn.text = "연구 착수 (매달 %d냥)" % cost_preview
				start_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				start_btn.pressed.connect(func():
					var msg: String = court.buy_research(rid)
					if hud != null and msg != "":
						hud._show_toast(msg, "📚")
					sim.emit_signal("state_updated", sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)
					_builder.call()
				)
			top_hb.add_child(start_btn)

		var desc_lbl := Label.new()
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_color_override("font_color", Color("4b5563"))
		if not done and not prereq_sat:
			desc_lbl.text = "필수 인재: %s 필요 | %s" % [req_name, rdesc]
		else:
			desc_lbl.text = rdesc
		card_vbox.add_child(desc_lbl)

		# 프로그레스 바 및 부가 정보
		if is_active or (progress_val > 0.0 and not done):
			var pb := ProgressBar.new()
			pb.min_value = 0.0
			pb.max_value = 100.0
			pb.value = progress_val
			pb.custom_minimum_size = Vector2(0, 18)
			pb.show_percentage = false

			var pb_fill := StyleBoxFlat.new()
			pb_fill.set_corner_radius_all(3)
			var is_paused_funds: bool = (is_active and cur_status == TechTreeManager.ResearchStatus.PAUSED_NO_FUNDS)
			var is_paused_scholar: bool = (is_active and cur_status == TechTreeManager.ResearchStatus.PAUSED_NO_SCHOLAR)

			if is_paused_funds or is_paused_scholar:
				pb_fill.bg_color = Color("ea580c")
			else:
				pb_fill.bg_color = Color("0284c7")
			pb.add_theme_stylebox_override("fill", pb_fill)
			card_vbox.add_child(pb)

			var status_hb := HBoxContainer.new()
			card_vbox.add_child(status_hb)

			var prog_txt := Label.new()
			prog_txt.text = "%d%% (매달 +%d%%)" % [int(progress_val), research_speed]
			prog_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			prog_txt.add_theme_color_override("font_color", Color("1e293b"))
			status_hb.add_child(prog_txt)

			var eta_turns: int = int(ceil(float(100.0 - progress_val) / float(maxi(1, research_speed))))
			var eta_txt := Label.new()
			var cost_display: int = 700 if is_jeong_hired else 1000
			eta_txt.text = "비용: 매달 %d냥 소모 중 | 잔여 예상 시간: 약 %d개월" % [cost_display, eta_turns]
			eta_txt.add_theme_color_override("font_color", Color("475569"))
			status_hb.add_child(eta_txt)

			if is_paused_funds:
				var warn_f := Label.new()
				warn_f.text = "⚠️ [재정 부족으로 연구 일시 정지 (매달 %d냥 필요)]" % cost_display
				warn_f.add_theme_color_override("font_color", Color("dc2626"))
				card_vbox.add_child(warn_f)
			elif is_paused_scholar:
				var warn_s := Label.new()
				warn_s.text = "⚠️ [필수 인재(%s) 공백으로 연구 정체 (인재 재등용 필요)]" % req_name
				warn_s.add_theme_color_override("font_color", Color("ea580c"))
				card_vbox.add_child(warn_s)


func _build_projects() -> void:
	if sim and grid:
		sim.sync_mega_projects_with_grid(grid)
	_clear_body()
	var desc := Label.new()
	desc.text = "정조 대왕의 주요 국책 대역사(만석거, 제방, 4대 권역 성곽, 국방 강화) 착공 현황입니다. (성곽 대역사는 12개월, 행궁은 4개월 기준)"
	desc.add_theme_color_override("font_color", Color("1c1917"))
	_body.add_child(desc)

	for p in sim.mega_projects:
		var row := PanelContainer.new()
		var r_sb := StyleBoxFlat.new()
		var is_comp: bool = bool(p["is_completed"])
		var is_off: bool = bool(p.get("is_disabled", false))
		var is_start: bool = bool(p["is_started"])
		var is_paused: bool = bool(p.get("is_paused", false))
		r_sb.bg_color = Color(0.98, 0.96, 0.90, 0.95) if not is_comp else Color(0.92, 0.96, 0.92, 0.95)
		r_sb.border_color = Color("d97706") if is_paused else (Color("991b1b") if is_start else (Color("15803d") if is_comp else Color("78716c")))
		r_sb.set_border_width_all(1)
		r_sb.set_corner_radius_all(4)
		r_sb.set_content_margin_all(8)
		row.add_theme_stylebox_override("panel", r_sb)
		_body.add_child(row)

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		row.add_child(hb)

		var info_vb := VBoxContainer.new()
		info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vb.add_theme_constant_override("separation", 2)
		hb.add_child(info_vb)

		var b_turns: int = int(p.get("base_turns", p.get("base_ticks", 12)))
		var p_turns: int = int(p.get("progress_turns", p.get("progress_ticks", 0)))
		var status = "비활성(직접 건설)" if is_off else "완공" if is_comp else ("일시정지(%d/%d개월)" % [p_turns, b_turns] if is_paused else ("진행중(%d/%d개월)" % [p_turns, b_turns] if is_start else "미착공"))
		var title_lbl := Label.new()
		title_lbl.text = "[%s] %s" % [status, p["name"]]
		title_lbl.add_theme_color_override("font_color", Color("1c1917"))
		title_lbl.add_theme_font_size_override("font_size", 15)
		info_vb.add_child(title_lbl)

		var raw_gold: int = int(p.get("cost_per_turn_gold", p.get("cost_per_tick_gold", 0)))
		var raw_rice: int = int(p.get("cost_per_turn_rice", p.get("cost_per_tick_rice", 0)))
		var eff_gold: int = int(ceil(raw_gold * (0.75 if sim.retainers.get("chae_jegong", false) else 1.0) * (0.80 if sim.retainers.get("kim_bau", false) else 1.0)))
		var eff_rice: int = int(ceil(raw_rice * (0.75 if sim.retainers.get("chae_jegong", false) else 1.0) * (0.80 if sim.retainers.get("kim_bau", false) else 1.0)))

		var cost_lbl := Label.new()
		cost_lbl.text = "공사 소요: %d개월 | 매달 부담: 금 %d냥, 곡 %d석" % [b_turns, eff_gold, eff_rice]
		if sim.retainers.get("jeong_yakyong", false) or sim.retainers.get("kim_bau", false) or sim.retainers.get("chae_jegong", false):
			cost_lbl.text += " (인재 할인·가속 적용)"
		cost_lbl.add_theme_color_override("font_color", Color("57534e"))
		cost_lbl.add_theme_font_size_override("font_size", 13)
		info_vb.add_child(cost_lbl)

		if is_paused:
			var pause_lbl := Label.new()
			pause_lbl.text = "⚠️ 재정/군량 부족으로 공사 일시 중단 (금 %d냥, 곡 %d석 필요) - 국고 확충 시 자동 재개" % [eff_gold, eff_rice]
			pause_lbl.add_theme_color_override("font_color", Color("b45309"))
			pause_lbl.add_theme_font_size_override("font_size", 12)
			info_vb.add_child(pause_lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(86, 32)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		if is_off:
			btn.text = "비활성"
			btn.disabled = true
			var off_lbl := Label.new()
			off_lbl.text = str(p.get("disabled_msg", "직접 지으신 시설이 있어 이 대역사는 쓰지 않습니다."))
			off_lbl.add_theme_color_override("font_color", Color("57534e"))
			off_lbl.add_theme_font_size_override("font_size", 12)
			info_vb.add_child(off_lbl)
		elif is_comp:
			btn.text = "완공됨"
			btn.disabled = true
		elif is_paused:
			btn.text = "재정부족"
			btn.disabled = true
			var btn_pb := StyleBoxFlat.new()
			btn_pb.bg_color = Color("78350f")
			btn_pb.border_color = Color("d97706")
			btn_pb.set_border_width_all(1)
			btn_pb.set_corner_radius_all(4)
			btn_pb.set_content_margin_all(4)
			btn.add_theme_stylebox_override("disabled", btn_pb)
			btn.add_theme_color_override("font_color", Color("fef3c7"))
		elif is_start:
			btn.text = "공사중"
			btn.disabled = true
		else:
			btn.text = "착공(發注)"
			btn.disabled = false
			var btn_sb := StyleBoxFlat.new()
			btn_sb.bg_color = Color("991b1b")
			btn_sb.border_color = Color("451a03")
			btn_sb.set_border_width_all(1)
			btn_sb.set_corner_radius_all(4)
			btn_sb.set_content_margin_all(4)
			btn.add_theme_stylebox_override("normal", btn_sb)
			var btn_hsb := btn_sb.duplicate() as StyleBoxFlat
			btn_hsb.bg_color = Color(0.75, 0.15, 0.15, 1.0)
			btn_hsb.border_color = Color(0.98, 0.85, 0.35)
			btn.add_theme_stylebox_override("hover", btn_hsb)
			btn.add_theme_color_override("font_color", Color("fef08a"))

		var pid = p["id"]
		btn.pressed.connect(func():
			var r = sim.start_mega_project(pid, grid)
			var succ: bool = bool(r.get("success", false))
			hud._show_toast(r.get("msg", ""), "🏗️" if succ else "⚠️")
			_builder.call()
		)
		hb.add_child(btn)

## PORT-TRACE [조정·인재 다운 버그]: 아래 세자서연·현륭원·포호·을묘 모달도 조정 모달과 같은
## 원인(CourtSystem에 없는 court.prince / invest_crown_prince / solve_eulmyo_petition /
## study_level 키, 없는 호랑이 대응 선택지)으로 누르면 멈췄다. 실제 API로 맞추고, 결과 메시지를
## 토스트로 보여준다(예전엔 반환값을 버려서 실패해도 아무 반응이 없었다).
func _court_action(msg: String, icon: String, close_after: bool = false) -> void:
	if hud and msg != "":
		hud._show_toast(msg, icon)
	if close_after:
		_close_modal()
	else:
		_builder.call()

func _build_prince() -> void:
	_clear_body()
	var desc := Label.new()
	var cur_score: float = sim.crown_prince_manager.progress if (sim != null and sim.crown_prince_manager != null) else float(court.crown_prince.get("education", 0))
	var stage_idx: int = CrownPrinceData.get_stage_by_score(cur_score)
	desc.text = "시강원 세자서연 (제왕학 교육)\n현재 단계: %s (진척도 %d%%)\n매달 학문력에 따라 진척되며 국고(난이도별 2,000냥~)가 지출됩니다." % [
		CrownPrinceData.get_stage_badge(stage_idx),
		int(cur_score)
	]
	desc.add_theme_color_override("font_color", Color("1c1917"))
	_body.add_child(desc)

	var hb := HBoxContainer.new()
	_body.add_child(hb)

	var pop_btn := Button.new()
	pop_btn.text = "👑 세자 경연 집무실 열기 (상세 초상화)"
	pop_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pop_btn.pressed.connect(func():
		_close_modal()
		open_crown_prince_popup()
	)
	hb.add_child(pop_btn)

	var pr: Dictionary = court.crown_prince
	if not pr.get("invested", true):
		var b1 := Button.new()
		b1.text = "채제공 스승 책봉(금 300냥)"
		b1.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b1.pressed.connect(func(): _court_action(court.invest_prince("chae_jegong"), "👑"))
		hb.add_child(b1)
		var b2 := Button.new()
		b2.text = "정약용 스승 책봉(금 300냥)"
		b2.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b2.pressed.connect(func(): _court_action(court.invest_prince("jeong_yakyong"), "👑"))
		hb.add_child(b2)
	else:
		var sb := Button.new()
		sb.text = "제왕학 서연 시작/진행"
		sb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		sb.pressed.connect(func(): _court_action(court.study_prince(), "📖"))
		hb.add_child(sb)

func _build_hyoryungwon() -> void:
	_clear_body()
	var desc := Label.new()
	desc.text = "화산 현륭원 사도세자 묘역을 참배하여 왕실 효심을 밝히고 백성 민심을 수습합니다."
	desc.add_theme_color_override("font_color", Color("1c1917"))
	_body.add_child(desc)

	var cost_info: Dictionary = TombVisitManager.get_tomb_visit_cost()
	var need_gold: int = int(cost_info.get("gold", 2000))
	var need_rice: int = int(cost_info.get("rice", 1000))
	var cur_gold: int = sim.gold if sim != null else 0
	var cur_rice: int = sim.rice if sim != null else 0
	var already_visited: bool = court.hyoryungwon.get("visited", false) if court != null else false
	var can_afford: bool = cur_gold >= need_gold and cur_rice >= need_rice

	var status_box := PanelContainer.new()
	var sb_flat := StyleBoxFlat.new()
	sb_flat.set_corner_radius_all(6)
	sb_flat.set_content_margin_all(10)
	sb_flat.bg_color = Color("faf8f5")
	sb_flat.border_color = Color("d6cbb8")
	sb_flat.set_border_width_all(1)
	status_box.add_theme_stylebox_override("panel", sb_flat)
	_body.add_child(status_box)

	var status_vbox := VBoxContainer.new()
	status_vbox.add_theme_constant_override("separation", 6)
	status_box.add_child(status_vbox)

	var cost_lbl := Label.new()
	cost_lbl.text = "소요 비용: 금화 %d냥, 군량미 %d석\n현재 국고: 금화 %d냥, 군량미 %d석\n누적 친림 횟수: %d회" % [
		need_gold, need_rice, cur_gold, cur_rice,
		court.hyeonryungwon_visits if court != null else 0
	]
	cost_lbl.add_theme_color_override("font_color", Color("44403c"))
	cost_lbl.add_theme_font_size_override("font_size", 13)
	status_vbox.add_child(cost_lbl)

	if already_visited:
		var done_lbl := Label.new()
		done_lbl.text = "금년도 현륭원 친림 참배를 이미 거행하셨습니다. (내년 봄에 다시 거행 가능)"
		done_lbl.add_theme_color_override("font_color", Color("15803d"))
		done_lbl.add_theme_font_size_override("font_size", 12)
		status_vbox.add_child(done_lbl)
	elif not can_afford:
		var warn_lbl := Label.new()
		var lack_gold: int = maxi(0, need_gold - cur_gold)
		var lack_rice: int = maxi(0, need_rice - cur_rice)
		var lack_msg := ""
		if lack_gold > 0 and lack_rice > 0:
			lack_msg = "금화 %d냥 및 군량미 %d석 부족" % [lack_gold, lack_rice]
		elif lack_gold > 0:
			lack_msg = "금화 %d냥 부족" % lack_gold
		else:
			lack_msg = "군량미 %d석 부족" % lack_rice
		warn_lbl.text = "국고 또는 군량이 부족하여 친림 참배를 거행할 수 없습니다. (%s)" % lack_msg
		warn_lbl.add_theme_color_override("font_color", Color("b91c1c"))
		warn_lbl.add_theme_font_size_override("font_size", 12)
		status_vbox.add_child(warn_lbl)

	var btn := Button.new()
	if already_visited:
		btn.text = "금년도 참배 완료"
		btn.disabled = true
	elif not can_afford:
		btn.text = "참배 거행 불가 (국고/군량 부족)"
		btn.disabled = true
	else:
		btn.text = "친림 참배 거행 (민심 +20, 왕권 +15)"
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func():
			var res_msg := court.visit_hyoryungwon()
			_court_action(res_msg, "🙏")
		)
	_body.add_child(btn)

func _build_tiger() -> void:
	_clear_body()
	var desc := Label.new()
	if court.tiger.get("active", false):
		desc.text = "팔달산 호환 발생! 호랑이를 어떻게 물리칠지 정하십시오."
	else:
		desc.text = "지금은 호랑이가 나타나지 않았습니다. (호환이 생기면 이곳에서 대응합니다)"
	desc.add_theme_color_override("font_color", Color("1c1917"))
	_body.add_child(desc)
	if not court.tiger.get("active", false):
		return
	var hb := HBoxContainer.new()
	_body.add_child(hb)
	var opts: Array = [
		["착호군 급파(군사력 60·군량 100석)", "army"],
		["산지 개간(금 180냥)", "clear"],
		["명포수 현상금(금 80냥, 실패할 수도)", "bounty"],
	]
	for o: Array in opts:
		var b := Button.new()
		b.text = o[0]
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var choice: String = o[1]
		b.pressed.connect(func(): _court_action(court.resolve_tiger(choice), "🐯", true))
		hb.add_child(b)

func _build_eulmyo() -> void:
	_clear_body()
	var desc := Label.new()
	desc.add_theme_color_override("font_color", Color("1c1917"))

	if sim and sim.is_eulmyo_completed:
		desc.text = "《원행을묘정리의궤》 대역사가 성대히 완수되었습니다.\n정조 대왕과 혜경궁 홍씨의 8일간 화성 행차로 조선의 왕권(100점 확정)이 드높아졌습니다."
		_body.add_child(desc)
		return

	if sim and sim.is_eulmyo_active:
		desc.text = "1795년 을묘원행 국책 대서사가 현재 화성 전역에서 성대히 거행 중입니다!\n진찬연, 양로연, 신풍루 사미, 서장대 야조, 화성 별시가 순차적으로 진행됩니다."
		_body.add_child(desc)
		return

	desc.text = "1795년(정조 19년) 혜경궁 홍씨의 회갑을 기념하는 조선 최대의 능행차 국책 대기록입니다.\n아래의 8대 발동 조건을 모두 충족하면 국책 대서사를 거행할 수 있습니다."
	_body.add_child(desc)

	var check: Dictionary = RoyalProcessionManager.can_trigger_eulmyo_event(sim, grid)
	var details: Dictionary = check.get("details", {})

	var cond_box := VBoxContainer.new()
	cond_box.add_theme_constant_override("separation", 4)
	_body.add_child(cond_box)

	var items: Array[Array] = [
		["왕권 지표 (50 이상)", "현재: %d" % (sim.authority if sim else 0), bool(details.get("authority_ok", false))],
		["민심 지표 (80 이상)", "현재: %d" % (sim.loyalty if sim else 0), bool(details.get("loyalty_ok", false))],
		["성곽 완성도 (사대문 폐곡선 100%)", "현재: %d%%" % (sim.fortress_progress if sim else 0), bool(details.get("fortress_ok", false))],
		["사대문 완공 (장안·팔달·화서·창룡문)", "사대문 완비", bool(details.get("gates_ok", false))],
		["도로망 (외곽-장안문-행궁 연결)", "사통팔달 연결", bool(details.get("road_connected_ok", false))],
		["행궁 진입 도로 (박석길 포장)", "박석길 완비", bool(details.get("paved_road_ok", false))],
		["국고 금화 (200,000냥 이상)", "현재: %s냥" % String.num_int64(sim.gold if sim else 0), bool(details.get("gold_ok", false))],
		["군량 식량 (200,000석 이상)", "현재: %s석" % String.num_int64(sim.rice if sim else 0), bool(details.get("rice_ok", false))],
		["3대 인재 등용 (체제공·정약용·김홍도)", "조정 출사", bool(details.get("retainers_ok", false))]
	]

	for item: Array in items:
		var hb := HBoxContainer.new()
		var ok: bool = bool(item[2])
		var lbl_name := Label.new()
		lbl_name.text = "• " + String(item[0]) + ": " + String(item[1])
		lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_name.add_theme_color_override("font_color", Color("2c3e50") if ok else Color("8b0000"))
		hb.add_child(lbl_name)

		var lbl_status := Label.new()
		lbl_status.text = "[달성]" if ok else "[미달]"
		lbl_status.add_theme_color_override("font_color", Color("1b5e20") if ok else Color("b71c1c"))
		hb.add_child(lbl_status)
		cond_box.add_child(hb)

	var can_trig: bool = bool(check.get("can_trigger", false))
	var btn := Button.new()
	btn.text = "1795년 을묘원행 국책 대서사 거행 (발동)" if can_trig else "을묘원행 발동 조건 미달"
	btn.disabled = not can_trig
	btn.custom_minimum_size = Vector2(0, 38)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_trig else Control.CURSOR_ARROW
	btn.pressed.connect(func():
		if royal_procession:
			var success: bool = royal_procession.start_eulmyo_event(sim, grid, citizens, time_manager, hud, self, city)
			if success:
				_close_modal()
	)
	_body.add_child(btn)

func _build_tax() -> void:
	_modal_no_refresh = true
	_clear_body()
	# PORT-TRACE [불러오면 세율 7%]: 임시 세율을 게임 시작 때 한 번만 복사해 두어, 저장을 불러온 뒤 이 창을 열면
	# 7% 막대가 나오고 [적용]이 불러온 세율(예: 1%)을 7%로 덮어썼다 — 창을 열 때마다 실제 세율에서 다시 가져온다.
	_temp_tax_land = sim.tax_rate_land
	_temp_tax_market = sim.tax_rate_market
	_temp_tax_military = sim.tax_rate_military
	var desc := Label.new()
	desc.text = "호조 탕평 조세 조율 (1~20%). 세율이 낮으면 백성 유입과 수요가 급증합니다."
	desc.add_theme_color_override("font_color", Color("1c1917"))
	_body.add_child(desc)

	# 3대 조세 총합 및 조세 저항선 경고 박스
	var summary_box := PanelContainer.new()
	var s_sb := StyleBoxFlat.new()
	s_sb.set_corner_radius_all(6)
	s_sb.set_content_margin_all(8)
	s_sb.bg_color = Color(0.96, 0.94, 0.90, 1.0)
	s_sb.border_color = Color("b45309")
	s_sb.set_border_width_all(1)
	summary_box.add_theme_stylebox_override("panel", s_sb)
	_body.add_child(summary_box)

	var sum_vbox := VBoxContainer.new()
	sum_vbox.add_theme_constant_override("separation", 4)
	summary_box.add_child(sum_vbox)

	var total_tax_lbl := Label.new()
	total_tax_lbl.add_theme_font_size_override("font_size", 14)
	sum_vbox.add_child(total_tax_lbl)

	var warning_lbl := Label.new()
	warning_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning_lbl.add_theme_font_size_override("font_size", 12)
	sum_vbox.add_child(warning_lbl)

	var workshop_buff_lbl := Label.new()
	workshop_buff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	workshop_buff_lbl.add_theme_font_size_override("font_size", 12)
	workshop_buff_lbl.add_theme_color_override("font_color", Color("1e40af"))
	sum_vbox.add_child(workshop_buff_lbl)

	var update_tax_ui := func():
		var sum_tax: int = _temp_tax_land + _temp_tax_market + _temp_tax_military
		var pop: int = sim.population if sim != null else 0
		var threshold: float = TaxManager.get_tax_threshold_for_population(pop)
		var is_resisting: bool = TaxManager.is_tax_resistance_active(pop, float(sum_tax))

		total_tax_lbl.text = ("📊 근대 통합세: %d%%  |  현재 인구: %s명 (저항 한계선: %s)" if ModernizationManager.is_active() else "📊 3대 조세 총합: %d%%  |  현재 인구: %s명 (저항 한계선: %s)") % [
			sum_tax,
			str(pop),
			("%d%%" % int(threshold)) if threshold <= 20.0 else "없음 (10만 미만)"
		]

		var total_shops: int = BuildingManager.active_market_shop_count
		var total_ws: int = BuildingManager.active_workshop_count
		var cov_shops: int = mini(total_shops, total_ws * 10)
		workshop_buff_lbl.text = "⚒️ %s" % WorkshopManager.get_market_buff_tooltip_text(cov_shops, total_shops)

		if is_resisting:
			var penalty: float = (float(sum_tax) - threshold) * 0.5
			warning_lbl.text = "⚠️ [조세 저항선 초과] 세금 부담이 임계치(%d%%)를 초과하여 매달 인구의 %.1f%%가 유출됩니다!" % [
				int(threshold), penalty
			]
			warning_lbl.add_theme_color_override("font_color", Color("b91c1c"))
			total_tax_lbl.add_theme_color_override("font_color", Color("991b1b"))
		else:
			if sum_tax == 21:
				warning_lbl.text = "⚖️ [시장 균형] 3대 조세 총합이 21%로 시장의 인구부양력이 안정적으로 유지됩니다."
				warning_lbl.add_theme_color_override("font_color", Color("166534"))
			elif sum_tax < 21:
				warning_lbl.text = "✨ [시장 활성화] 조세 총합이 21% 미만으로 시장의 인구부양력이 매달 상승합니다."
				warning_lbl.add_theme_color_override("font_color", Color("15803d"))
			else:
				warning_lbl.text = "📉 [상업 위축] 조세 총합이 21% 초과로 시장의 인구부양력이 매달 점진적으로 감소합니다."
				warning_lbl.add_theme_color_override("font_color", Color("c2410c"))
			total_tax_lbl.add_theme_color_override("font_color", Color("1c1917"))

	if ModernizationManager.is_active():
		# 근대화 시대: 3대 조세를 '근대 통합세' 하나로. 통합 세율 = 세 세목의 합(3~60%)이며
		# 안에서는 세 세목에 똑같이 나눠 넣으므로 세수·수요·조세 저항선 계산은 본편과 같다.
		desc.text = "근대 통합 세제: 토지세·영업세·군포세를 하나로 통합했습니다 (3~60%). 세율이 낮으면 인구 유입과 수요가 늘어납니다."
		var unified: int = clampi(int(round(float(_temp_tax_land + _temp_tax_market + _temp_tax_military) / 3.0)) * 3, 3, 60)
		_temp_tax_land = unified / 3
		_temp_tax_market = unified / 3
		_temp_tax_military = unified / 3
		var hb := HBoxContainer.new()
		_body.add_child(hb)
		var lbl := Label.new()
		lbl.text = "근대 통합세: %d%%" % unified
		lbl.custom_minimum_size = Vector2(180, 0)
		lbl.add_theme_color_override("font_color", Color("1c1917"))
		hb.add_child(lbl)
		var sld := HSlider.new()
		sld.min_value = 3
		sld.max_value = 60
		sld.step = 3
		sld.value = unified
		sld.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sld.value_changed.connect(func(v: float):
			lbl.text = "근대 통합세: %d%%" % int(v)
			_temp_tax_land = int(v) / 3
			_temp_tax_market = int(v) / 3
			_temp_tax_military = int(v) / 3
			update_tax_ui.call()
		)
		hb.add_child(sld)
	else:
		_add_tax_slider("결작세(토지/농업): %d%%", _temp_tax_land, func(v):
			_temp_tax_land = v
			update_tax_ui.call()
		)
		_add_tax_slider("시전세(상업/점포): %d%%", _temp_tax_market, func(v):
			_temp_tax_market = v
			update_tax_ui.call()
		)
		_add_tax_slider("군포세(호포/국방): %d%%", _temp_tax_military, func(v):
			_temp_tax_military = v
			update_tax_ui.call()
		)

	update_tax_ui.call()

	var apply_btn := Button.new()
	apply_btn.text = "호조 조세 윤허(적용)"
	apply_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	apply_btn.pressed.connect(func():
		sim.tax_rate_land = _temp_tax_land
		sim.tax_rate_market = _temp_tax_market
		sim.tax_rate_military = _temp_tax_military
		hud._show_toast("호조 탕평 조세가 조정되었습니다.", "⚖️")
		_close_modal()
	)
	_body.add_child(apply_btn)

func _add_tax_slider(title_fmt: String, cur_val: int, setter: Callable) -> void:
	var hb := HBoxContainer.new()
	_body.add_child(hb)
	var lbl := Label.new()
	lbl.text = title_fmt % cur_val
	lbl.custom_minimum_size = Vector2(180, 0)
	lbl.add_theme_color_override("font_color", Color("1c1917"))
	hb.add_child(lbl)
	var sld := HSlider.new()
	sld.min_value = 1
	sld.max_value = 20
	sld.value = cur_val
	sld.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sld.value_changed.connect(func(v: float):
		lbl.text = title_fmt % int(v)
		setter.call(int(v))
	)
	hb.add_child(sld)

func _build_newspaper() -> void:
	if bibyeonsa_sibo != null:
		_close_modal()
		bibyeonsa_sibo.show_latest()
		return

	_clear_body()
	var art: Dictionary = NewspaperSystem.generate(sim, grid, "")
	var headline := Label.new()
	headline.text = "【%s】 %s" % [art.get("dateStr", ""), art.get("headline", "")]
	headline.add_theme_color_override("font_color", Color("991b1b"))
	headline.add_theme_font_size_override("font_size", 16)
	_body.add_child(headline)

	var content := Label.new()
	content.text = art["body"]
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_theme_color_override("font_color", Color("1c1917"))
	_body.add_child(content)

# ------------------------------------------------------------ 근대화 시대: 서학 진흥 / 외교
func _modern_label(text: String, col: Color = Color("1c1917")) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", col)
	_body.add_child(l)
	return l

func _modern_button(text: String, enabled: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(0, 30)
	b.pressed.connect(func():
		cb.call()
		if _title.text.begins_with("서학"):
			_build_west_promo()
		else:
			_build_diplomacy()
	)
	_body.add_child(b)
	return b

func _build_west_promo() -> void:
	_clear_body()
	var mm: ModernizationManager = ModernizationManager.instance
	if mm == null or not mm.active:
		return
	_modern_label("🔬 서학 진척도: %d / 100     ⚡ 연구 속도: %.1f배 (최대 %d배)" % [mm.western_progress(), mm.speed_mult(), int(ModernizationManager.MAX_SPEED_MULT)], Color("0369a1"))
	var cost_txt := "💰 연구 재정: 매달 -%d냥" % ModernizationManager.RESEARCH_TURN_COST if mm.current_field != "" else "💰 연구 재정: 매달 0냥 (미진행)"
	if mm.research_paused:
		cost_txt = "💰 연구 재정: 국고 부족으로 일시 정지"
	_modern_label(cost_txt, Color("b91c1c") if mm.current_field != "" else Color("4b5563"))
	_modern_label("서학 진척도는 아래 다섯 분야 게이지의 평균입니다. 연구를 착수한 분야만 매달 찹니다.
서양 서적과 해외 유학은 진척도를 직접 올리지 않고 연구 속도를 높입니다.", Color("57534e"))

	_modern_label("
【근대 과학 연구】", Color("7c2d12"))
	for f: Dictionary in ModernizationManager.FIELDS:
		var fid: String = f["id"]
		var pv: float = float(mm.field_progress.get(fid, 0.0))
		var state := "[완료] " if mm.field_done(fid) else ("[연구 중] " if mm.current_field == fid else "")
		_modern_label("%s%s — %s  (완료 효과: %s)" % [state, f["name"], f["desc"], f["effect"]], Color("15803d") if mm.field_done(fid) else Color("1c1917"))
		var bar := ProgressBar.new()
		bar.max_value = 100.0
		bar.value = pv
		bar.custom_minimum_size = Vector2(0, 14)
		_body.add_child(bar)
		if not mm.field_done(fid) and mm.current_field != fid:
			_modern_button("착수 (매달 %d냥)" % ModernizationManager.RESEARCH_TURN_COST, true, func(): mm.start_field(fid))

	_modern_label("
【서양 서적 구입】 %d / %d권 — 권당 연구 속도 +%.1f배" % [mm.books_bought, ModernizationManager.MAX_BOOKS, ModernizationManager.BOOK_BONUS], Color("7c2d12"))
	_modern_button("서적 구입 (%d냥)" % ModernizationManager.BOOK_COST, mm.books_bought < ModernizationManager.MAX_BOOKS and sim.gold >= ModernizationManager.BOOK_COST, mm.buy_books)

	_modern_label("
【해외 유학】 %d / %d명 — %d개월 뒤 돌아오면 학문 능력×%.1f배만큼 연구 속도가 빨라집니다." % [mm.students.size(), ModernizationManager.MAX_STUDENTS, ModernizationManager.STUDY_TURNS, ModernizationManager.STUDY_ABILITY_FACTOR], Color("7c2d12"))
	for k in mm.students:
		var st: Dictionary = mm.students[k]
		if mm.is_studying(k):
			_modern_label("  ✈ %s — 유학 중 (%d개월 남음)" % [st.get("name", k), int(st["return_turn"]) - sim.turn])
		else:
			_modern_label("  🎓 %s — 귀국 (속도 +%.1f배)" % [st.get("name", k), float(st["acad"]) * ModernizationManager.STUDY_ABILITY_FACTOR], Color("15803d"))
	if mm.students.size() < ModernizationManager.MAX_STUDENTS:
		for c: Dictionary in mm.study_candidates():
			if mm.students.has(c["key"]):
				continue
			var ck: String = c["key"]
			var cn: String = c["name"]
			var ca: int = c["acad"]
			_modern_button("%s 유학 보내기 (학문 %d → +%.1f배, %d냥)" % [cn, ca, ca * ModernizationManager.STUDY_ABILITY_FACTOR, ModernizationManager.STUDY_COST], sim.gold >= ModernizationManager.STUDY_COST, func(): mm.send_abroad(ck, cn, ca))

## 근대 수도체제: 수도 연결 대공사·집수정·생활용수 공급시설 (석조 전환 뒤)
func _build_water_works() -> void:
	_clear_body()
	var um: UrbanEvolutionManager = UrbanEvolutionManager.instance
	if um == null or not ModernizationManager.is_active():
		return
	_modern_label("🚰 상하수도 보급률: %d%%  — 집수정·생활용수 공급시설·하수처리시설의 영향권 밖 가옥·상점에 물방울이 뜹니다. 물방울이 없으면 100%%." % um.water_supply_rate(), Color("0369a1"))
	if not um.upgrades_unlocked():
		_modern_label("🔒 석조 전환이 끝나야 근대 수도 공사를 할 수 있습니다. (진행 %d%%)" % int(um.stone_ratio * 100.0), Color("7c2d12"))
		return
	_modern_label("\n【수도 연결 대공사】 매달 %d냥씩 %d달. 끝나면 모든 수도 시설의 영향권이 1.5배로 넓어집니다. 국고가 모자란 달은 공사가 멈춥니다." % [UrbanEvolutionManager.WATER_PROJECT_COST_PER_TURN, UrbanEvolutionManager.WATER_PROJECT_TURNS], Color("7c2d12"))
	if um.water_project_done():
		_modern_label("✓ 완공", Color("15803d"))
	elif um.water_project_started:
		var bar := ProgressBar.new()
		bar.max_value = UrbanEvolutionManager.WATER_PROJECT_TURNS
		bar.value = um.water_project_done_turns
		bar.custom_minimum_size = Vector2(0, 14)
		_body.add_child(bar)
	else:
		_modern_water_btn("🏗️ 착공", true, func(): um.start_water_project())
	_modern_label("\n【우물 → 집수정】 도시의 우물을 모두 집수정으로 바꿉니다. (%d냥)" % UrbanEvolutionManager.WELL_UPGRADE_COST, Color("7c2d12"))
	if um.wells_upgraded:
		_modern_label("✓ 완료", Color("15803d"))
	else:
		_modern_water_btn("🪣 개편", grid.count_completed("well") > 0 and sim.gold >= UrbanEvolutionManager.WELL_UPGRADE_COST, func(): um.upgrade_wells())
	_modern_label("\n【저수지 → 생활용수 공급시설】 저수지 물을 걸러 집집마다 보냅니다. (%d냥)" % UrbanEvolutionManager.RESERVOIR_UPGRADE_COST, Color("7c2d12"))
	if um.reservoirs_upgraded:
		_modern_label("✓ 완료", Color("15803d"))
	else:
		_modern_water_btn("💧 개편", grid.count_completed("reservoir") > 0 and sim.gold >= UrbanEvolutionManager.RESERVOIR_UPGRADE_COST, func(): um.upgrade_reservoirs())
	_modern_label("\n【하수처리시설】 하단 메뉴바의 [🚰 하수처리](옛 홍예성문 자리)로 2x2 부지에 짓습니다. 반경 %d칸이 영향권입니다. (지은 곳 %d)" % [int(UrbanEvolutionManager.SEWAGE_RADIUS), grid.count_completed("sewage")], Color("57534e"))

func _modern_water_btn(text: String, enabled: bool, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(0, 30)
	b.pressed.connect(func():
		cb.call()
		_build_water_works()
	)
	_body.add_child(b)

## 대통령제: 국회·행정 각부 건의 승인/반려 + 계엄령
func _build_proposals() -> void:
	_clear_body()
	var pol: ModernPoliticsManager = ModernPoliticsManager.instance
	if pol == null:
		return
	_modern_label("⚖️ %s     📋 건의 수준: %s (등용한 인재의 학문 능력이 높을수록 비용이 싸고 부실 건의가 줄어듭니다)" % [pol.system_label(), pol.quality_label()], Color("1d4ed8"))
	_modern_label("대통령은 정무를 직접 하지 않고, 석 달마다 올라오는 건의를 승인하거나 반려합니다. 건의는 여섯 달이 지나면 폐기됩니다.\n국회 건의를 반려하면 국회와 갈등이 생깁니다. 길·구역 건설과 인재 등용은 그대로 직접 합니다.", Color("57534e"))
	if pol.last_result != "":
		_modern_label(pol.last_result, Color("15803d"))
	if pol.pending.is_empty():
		_modern_label("\n지금 올라온 건의가 없습니다.", Color("4b5563"))
	for p: Dictionary in pol.pending.duplicate():
		var pid := int(p["id"])
		var cost_txt := ("비용 %d냥" % int(p["cost"])) if int(p["cost"]) > 0 else "비용 없음"
		var warn := "   ⚠ 검토 의견: 준비가 덜 된 졸속 건의로 보입니다." if bool(p["flag"]) else ""
		_modern_label("\n[%s] %s — %s%s" % [p["source"], p["title"], cost_txt, warn], Color("b45309") if bool(p["flag"]) else Color("1c1917"))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		_body.add_child(hb)
		var ba := Button.new()
		ba.text = "승인"
		ba.custom_minimum_size = Vector2(90, 28)
		ba.disabled = sim.gold < int(p["cost"])
		ba.pressed.connect(func():
			pol.approve(pid)
			_build_proposals()
		)
		hb.add_child(ba)
		var br := Button.new()
		br.text = "반려"
		br.custom_minimum_size = Vector2(90, 28)
		br.pressed.connect(func():
			pol.reject(pid)
			_build_proposals()
		)
		hb.add_child(br)
	_modern_label("\n【계엄령】 국회를 해산하고 다시 직접 통치합니다. 민심 -20, 그리고 1년 뒤 정치적 파멸을 맞습니다.", Color("7f1d1d"))
	var bm := Button.new()
	bm.text = "🪖 계엄령 선포"
	bm.pressed.connect(func():
		pol.declare_martial_law()
		_close_modal()
	)
	_body.add_child(bm)

func _build_diplomacy() -> void:
	_clear_body()
	var mm: ModernizationManager = ModernizationManager.instance
	if mm == null or not mm.active:
		return
	if not mm.diplomacy_unlocked:
		_modern_label("🔒 국제외교는 열강의 첫 침공을 격퇴하면 열립니다.
성곽 방호, 장용영·신식군대, 순라청으로 국방력을 키워 침공에 대비하십시오.", Color("7c2d12"))
		return
	var allies_txt := ", ".join(mm.allies.map(func(a): return ModernDiplomacyData.nation_name(a))) if not mm.allies.is_empty() else "없음"
	_modern_label("🕊️ 외교 신뢰도: %d / %d     ⚔️ 올해 침공 확률: %d%%     🤝 동맹국(%d/%d): %s" % [mm.trust, ModernizationManager.MAX_TRUST, int(round(mm.invasion_chance() * 100.0)), mm.allies.size(), ModernizationManager.MAX_ALLIES, allies_txt], Color("7c2d12"))
	_modern_label("\n【국제외교 회담】 열강 10개국 가운데 한 나라의 사절을 사대문에서 맞이합니다. (3달에 1회, 성공하면 신뢰도 +1)")
	_modern_label("🤝 성공률 %d%%  (서학 진척도 %d, 학문력 %d)" % [int(round(mm.diplomacy_success_rate() * 100.0)), mm.western_progress(), CityStats.get_academic_power()], Color("1d4ed8"))
	_modern_label("보상: 차관 20,000냥 / 신식 무기(국방 +50) / 근대화 가속(연구 속도 +1배) 중 하나", Color("57534e"))
	if mm.last_result != "":
		_modern_label(mm.last_result, Color("15803d"))
	var left := mm.diplomacy_turns_left()
	_modern_button("회담 개최" if left == 0 else "다음 회담까지 %d개월" % left, left == 0, func():
		var r := mm.hold_summit()
		if not r.is_empty():
			mm.last_result = ("🤝 회담 성공! " if r["ok"] else "✖ ") + String(r["msg"])
	)

	_modern_label("\n【동맹 협상】 신뢰도 10이면 나라를 골라 협상합니다. 상대의 요구에 모두 알맞게 답해야 맺어집니다.\n최대 %d개국, 연합국과 추축국은 함께 맺을 수 없습니다. 동맹국은 침략받을 때 원군 %d을 보내 주고, 동맹국이 침략받으면 파병을 요청합니다." % [ModernizationManager.MAX_ALLIES, ModernizationManager.ALLY_REINFORCEMENT], Color("57534e"))
	for bloc in ["allies", "axis"]:
		_modern_label("— %s —" % ModernDiplomacyData.BLOC_NAMES[bloc], Color("1d4ed8"))
		for nid in ModernDiplomacyData.NATIONS:
			if ModernDiplomacyData.bloc_of(nid) != bloc:
				continue
			var n_id: String = nid
			var chk: Dictionary = mm.can_negotiate_alliance(n_id)
			var label := "%s — %s" % [ModernDiplomacyData.nation_name(n_id), "✓ 동맹 중" if n_id in mm.allies else ("동맹 협상" if chk["ok"] else String(chk["why"]))]
			_modern_button(label, bool(chk["ok"]), func(): mm.negotiate_alliance(n_id, func(): _build_diplomacy()))

func _build_trade() -> void:
	_clear_body()
	var desc := Label.new()
	desc.text = "4대문 교역로 현황 (대문 자리에 길이나 성문이 닿아야 개통, 성문이면 관세 2배)"
	desc.add_theme_color_override("font_color", Color("1c1917"))
	_body.add_child(desc)

	# PORT-TRACE [모달 다운 버그]: 없는 trade.routes를 읽어 멈췄다. 실제로는 ROUTES 상수 +
	# route_connected_state / route_gated_state 로 상태를 들고 있다.
	for r: Dictionary in TradeSystem.ROUTES:
		var key: String = r["key"]
		var connected: bool = trade.route_connected_state.get(key, false)
		var gated: bool = trade.route_gated_state.get(key, false)
		var status := "성문 개통(관세 2배)" if gated else ("길 개통" if connected else "단절")
		var res_name := "금" if r["resource"] == "gold" else "쌀"
		var lbl := Label.new()
		lbl.text = "[%s] %s — 매달 %s %d" % [status, r["name"], res_name, int(r["amount"]) * (2 if gated else 1)]
		lbl.add_theme_color_override("font_color", Color("1c1917"))
		_body.add_child(lbl)

	# 구분선
	var sep := HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 8)
	_body.add_child(sep)

	# 곡식(식량) 구매 및 환곡 상업 기능
	var market_title := Label.new()
	market_title.text = "🌾 삼남 상업 및 환곡(還穀) 곡식 매입·판매"
	market_title.add_theme_color_override("font_color", Color("991b1b"))
	market_title.add_theme_font_size_override("font_size", 14)
	_body.add_child(market_title)

	if sim:
		var status_lbl := Label.new()
		status_lbl.text = sim.get_rice_market_status()
		status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status_lbl.add_theme_color_override("font_color", Color("1c1917"))
		_body.add_child(status_lbl)

		var cur_price: int = sim.get_rice_market_price_per_100()
		var hb_buy := HBoxContainer.new()
		hb_buy.add_theme_constant_override("separation", 10)
		_body.add_child(hb_buy)

		var buy_amounts: Array[int] = [100, 300, 500]
		for amt: int in buy_amounts:
			var cost: int = int(ceil(float(amt) / 100.0 * float(cur_price)))
			var btn := Button.new()
			btn.text = "곡식 %d석 (금 %d냥)" % [amt, cost]
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.pressed.connect(func():
				var res: Dictionary = sim.buy_rice(amt)
				if hud:
					hud._show_toast(res.get("msg", ""), "🌾" if res.get("success", false) else "⚠️")
				_builder.call()
			)
			hb_buy.add_child(btn)

		# 곡식이 넘치고 금이 모자랄 때: 곳간 곡식을 내다 팔아 금으로 바꾼다(사는 값의 80%)
		var sell_price: int = sim.get_rice_sell_price_per_100()
		var sell_lbl := Label.new()
		sell_lbl.text = "곡식 팔기 — 100석당 금 %d냥 (보유 곡식 %d석)" % [sell_price, sim.rice]
		sell_lbl.add_theme_color_override("font_color", Color("1c1917"))
		_body.add_child(sell_lbl)
		var hb_sell := HBoxContainer.new()
		hb_sell.add_theme_constant_override("separation", 10)
		_body.add_child(hb_sell)
		for s_amt: int in [10000, 100000, 1000000]:
			var s_income: int = int(floor(float(s_amt) / 100.0 * float(sell_price)))
			var s_btn := Button.new()
			s_btn.text = "곡식 %d석 팔기 (금 %d냥)" % [s_amt, s_income]
			s_btn.disabled = sim.rice < s_amt
			s_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			s_btn.pressed.connect(func():
				var res: Dictionary = sim.sell_rice(s_amt)
				if hud:
					hud._show_toast(res.get("msg", ""), "🪙" if res.get("success", false) else "⚠️")
				_builder.call()
			)
			hb_sell.add_child(s_btn)

func _build_outside() -> void:
	_clear_body()
	var desc := Label.new()
	desc.text = "성저(城底) 및 대유둔전 실태: 성곽 바깥에 정착한 유민들의 민정과 외곽 둔전 현황입니다."
	desc.add_theme_color_override("font_color", Color("1c1917"))
	_body.add_child(desc)
	if outside:
		var st_lbl := Label.new()
		st_lbl.text = "• 성 밖 자연발생 민가·저자: %d개소" % outside.settlements.size()
		st_lbl.add_theme_color_override("font_color", Color("1c1917"))
		_body.add_child(st_lbl)

	if grid:
		var log_info: Dictionary = grid.check_dunjian_logistics()
		var dunjian_lbl := Label.new()
		var gate_cnt: int = int(log_info.get("gates", 0))
		var conn_farms: int = int(log_info.get("connected", 0))
		var total_farms: int = int(log_info.get("total", 0))
		var ratio_pct: int = int(float(log_info.get("ratio", 0.0)) * 100.0)

		var log_status_str := "성문 및 도로망 완전 개통 (물류 가산 +25%)"
		if gate_cnt == 0:
			log_status_str = "성문 미개통 (성벽 차단으로 운송 지연 손실 -55%)"
		elif ratio_pct < 50:
			log_status_str = "도로망 단절 (운송 손실 발생)"
		elif ratio_pct < 90:
			log_status_str = "물류 부분 개통 (%d%%)" % ratio_pct

		dunjian_lbl.text = "• 외곽 둔전: 총 %d필지 (성내 직통 운송: %d필지 / %d%%)\n• 연결 성문: %d개소\n• 물류 운송 상태: %s" % [
			total_farms, conn_farms, ratio_pct, gate_cnt, log_status_str
		]
		dunjian_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dunjian_lbl.add_theme_color_override("font_color", Color("1c1917"))
		_body.add_child(dunjian_lbl)

func _build_bandit() -> void:
	_clear_body()

	var desc := Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color("1c1917"))
	_body.add_child(desc)

	var baek_hired: bool = sim.retainers.get("baek_dongsu", false) if sim else false

	if baek_hired:
		desc.text = "【야뇌 백동수 수호 중】\n장용영 무예 총관 백동수가 영지 내 치안을 철통같이 방비하고 있습니다. 화적 떼가 감히 침범하지 못합니다. (도적 침략 100% 완전 차단됨)"
		var ok_btn := Button.new()
		ok_btn.text = "확인"
		ok_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ok_btn.pressed.connect(_close_modal)
		_body.add_child(ok_btn)
		return

	var b_mgr: BanditManager = sim.bandit_manager if (sim and "bandit_manager" in sim and sim.bandit_manager) else (citizens.bandit_mgr if citizens else null)

	if sim and sim.bandit_active:
		desc.text = "🚨 【긴급 사태: 화적(도적) 떼 출몰】\n도적 떼가 영지 내 가옥에 불을 지르고 쌀가마와 금화를 약탈하고 있습니다!\n(피해: 매초 금화, 식량, 민심 지속 감소)"

		var hb_act := HBoxContainer.new()
		_body.add_child(hb_act)

		var has_patrol: bool = false
		if citizens:
			has_patrol = not citizens._patrol_cache.is_empty()

		if has_patrol:
			var dispatch_btn := Button.new()
			dispatch_btn.text = "🚨 순라군 긴급 출동 (도적 요격 및 체포)"
			dispatch_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			dispatch_btn.pressed.connect(func():
				if citizens:
					citizens.dispatch_patrol_squad()
				_close_modal()
			)
			hb_act.add_child(dispatch_btn)
		else:
			var warn := Label.new()
			warn.text = "※ 순라청(치안 시설)이 없어 즉시 요격할 수 없습니다! 도적들이 20초간 약탈 후 소굴로 퇴각합니다. 속히 순라청을 건설하십시오."
			warn.add_theme_color_override("font_color", Color("b91c1c"))
			warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_body.add_child(warn)
	else:
		var camps_list: Array[Dictionary] = b_mgr.camps if b_mgr != null else []
		var cd_turns: int = b_mgr.subjugation_cooldown_turns if b_mgr != null else 0
		var cost_dict: Dictionary = DifficultyManager.get_bandit_subjugation_cost()
		var req_gold: int = int(cost_dict.get("gold", 1000))
		var req_rice: int = int(cost_dict.get("rice", 1000))
		var cur_gold: int = ResourceManager.get_gold(sim)
		var cur_rice: int = ResourceManager.get_rice(sim)
		var ally_power: int = BanditManager.calculate_ally_combat_power(sim, grid)

		if camps_list.is_empty():
			desc.text = "【화성유수부 치안 정탐 보고】\n현재 성곽 외곽에 활성화된 도적 소굴이 없습니다. 영지의 치안이 평온하게 유지되고 있습니다.\n(성곽 외부 감시 중 · 아군 총 군사력: %d)" % ally_power
		else:
			var total_power: int = b_mgr.get_total_camp_combat_power()
			var highest_power: int = 0
			for c: Dictionary in camps_list:
				highest_power = maxi(highest_power, int(c.get("combat_power", 0)))

			desc.text = "【화성 성곽 외곽 도적 소굴 현황 (총 %d개소)】\n성 밖 험지에 화적들이 소굴을 틀고 세력을 불리고 있습니다. 방치 시 보부상단과 성내 민가를 약탈하고 화성을 함락시킬 위험이 있습니다!\n- 활성 소굴 수: %d / 3개 (최고 전투력: %d / 총합: %d)\n- 아군 유수부 군사력: %d (장용영 + 서장대 + 순라청)\n- 출동 비용: 금 %d냥, 쌀 %d석 (난이도 배율 적용)\n- 출동 규약: 1년(4개월)에 1회만 출동 가능 (잔여 기다림: %d개월)" % [
				camps_list.size(), camps_list.size(), highest_power, total_power, ally_power, req_gold, req_rice, cd_turns
			]

		var hb_sub := HBoxContainer.new()
		_body.add_child(hb_sub)

		var sub_btn := Button.new()
		sub_btn.text = "🛡️ 도적떼 토벌 출동 (금 %d냥, 쌀 %d석)" % [req_gold, req_rice]
		sub_btn.custom_minimum_size = Vector2(0, 36)
		sub_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		if camps_list.is_empty():
			sub_btn.disabled = true
			sub_btn.tooltip_text = "토벌할 도적 소굴이 없습니다."
		elif cd_turns > 0:
			sub_btn.disabled = true
			sub_btn.tooltip_text = "올해는 이미 유수부 토벌대를 출동시켰습니다. (다시 출동까지 %d개월)" % cd_turns
		elif cur_gold < req_gold or cur_rice < req_rice:
			sub_btn.disabled = true
			sub_btn.tooltip_text = "출동 군자금이 부족합니다. (보유: 금 %d냥, 쌀 %d석)" % [cur_gold, cur_rice]

		sub_btn.pressed.connect(func():
			if b_mgr:
				var res: Dictionary = b_mgr.dispatch_yusubu_subjugation(sim, grid)
				var msg: String = str(res.get("msg", ""))
				if bool(res.get("victory", false)):
					hud._show_toast(msg, "⚔️")
					if audio:
						audio.play("coin")
				else:
					hud._show_toast(msg, "⚠️")
				_close_modal()
		)
		hb_sub.add_child(sub_btn)

func _build_gwana_hub() -> void:
	_clear_body()

	var desc := Label.new()
	desc.text = "【화성유수부 동헌 (공형청)】\n사또가 송사를 듣고 억울한 죄인을 신문하며, 도적 소탕과 호환 방비를 총괄하는 관아입니다."
	desc.add_theme_color_override("font_color", Color("1c1917"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(desc)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_body.add_child(vb)

	var has_pending: bool = trial_manager != null and trial_manager.has_pending_trial()

	# 1. 송사 판결 버튼
	var trial_btn := Button.new()
	trial_btn.custom_minimum_size = Vector2(0, 36)
	trial_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if has_pending:
		trial_btn.text = "⚖️ [원옥 친국] 백성의 억울한 송사 판결하기 (새 송사 당도!)"
		var t_sb := StyleBoxFlat.new()
		t_sb.bg_color = Color("8f1d1d")
		t_sb.border_color = Color("e0a030")
		t_sb.set_border_width_all(2)
		t_sb.set_corner_radius_all(4)
		trial_btn.add_theme_stylebox_override("normal", t_sb)
		trial_btn.add_theme_color_override("font_color", Color("ffffff"))
	else:
		trial_btn.text = "⚖️ [원옥 기록] 공형청 송사 기록 열람 (이번 계절 판결 완료됨)"
	trial_btn.pressed.connect(func():
		_close_modal()
		if trial_manager:
			trial_manager.open_trial_ui()
	)
	vb.add_child(trial_btn)

	# 2. 도적 토벌 버튼
	var bandit_btn := Button.new()
	bandit_btn.text = "⚔️ [치안 방비] 화적(도적) 소탕 및 소굴 토벌 대책"
	bandit_btn.custom_minimum_size = Vector2(0, 36)
	bandit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bandit_btn.pressed.connect(func():
		open_action_modal("bandit")
	)
	vb.add_child(bandit_btn)

	# 3. 포호 대책 버튼
	var tiger_btn := Button.new()
	tiger_btn.text = "🐅 [포호책] 팔달산 호환(맹호) 방비 및 퇴치 결단"
	tiger_btn.custom_minimum_size = Vector2(0, 36)
	tiger_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tiger_btn.pressed.connect(func():
		open_action_modal("tiger")
	)
	vb.add_child(tiger_btn)

func _on_turn_report(rep: Dictionary) -> void:
	if not hud:
		return
	# 계절 결산 알림: 정산은 달마다, 알림은 계절이 끝날 때 석 달 치를 모아 한 번
	if GameSettings.is_settlement_popup_enabled() and bool(rep.get("season_end", false)):
		var sum: Dictionary = rep.get("season_sum", {})
		var log_status: String = rep.get("logistics_status", "")
		var maint_g: int = int(sum.get("maintenance_gold", 0))
		var maint_r: int = int(sum.get("maintenance_rice", 0))
		var maint_str: String = ""
		if maint_g > 0 or maint_r > 0:
			maint_str = " | 운영비: -%d냥, -%d석" % [maint_g, maint_r]
		var msg: String = "%s %s 결산: 세입 +%d냥, 쌀 +%d석%s (인구 %d명)" % [
			TimeManager.era_name(int(rep.get("ended_year", rep.get("year", 1776)))), rep.get("ended_season", "봄"), # 1800년 엔딩 뒤는 순조 이후 연호
			int(sum.get("tax_income", 0)), int(sum.get("harvest", 0)),
			maint_str, rep.get("population", 0)
		]
		if log_status != "":
			msg += " | %s" % log_status
		hud._show_toast(msg, "🌾")
	# PORT-TRACE [경량화 감사]: turn_report 시그니처가 리팩터되며 끊겨 있던 암행어사 딜레마
	# 팝업(3개월마다 발생, NewspaperSystem.dilemma_pool)을 되살렸다. 결산 알림 설정과는 따로 간다.
	if rep.get("dilemma", false) and sim:
		if EventManager.instance != null:
			var pool := NewspaperSystem.dilemma_pool(sim)
			if not pool.is_empty():
				var ev: Dictionary = pool[randi() % pool.size()]
				if ev.get("id", "") in ["conspiracy_dilemma", "gu_seon_bok_dilemma"]:
					sim.is_conspiracy_decision_pending = true
				EventManager.instance.enqueue_dilemma(ev)
		else:
			_show_dilemma()

func _show_dilemma() -> void:
	var pool := NewspaperSystem.dilemma_pool(sim)
	if pool.is_empty():
		return
	var ev: Dictionary = pool[randi() % pool.size()]
	if sim != null and ev.get("id", "") in ["conspiracy_dilemma", "gu_seon_bok_dilemma"]:
		sim.is_conspiracy_decision_pending = true
	_open(ev.get("title", "암행어사 서면 보고"), func():
		_clear_body()
		var desc := Label.new()
		desc.text = ev.get("desc", "")
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_color_override("font_color", Color("1c1917"))
		_body.add_child(desc)
		for ch in ev.get("choices", []):
			var eff: Callable = ch["effect"]
			var b := Button.new()
			b.text = ch.get("text", "선택")
			b.pressed.connect(func():
				var result_msg: String = eff.call()
				_close_modal()
				hud._show_toast(result_msg, "📜")
				sim.emit_signal("state_updated", sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)
			)
			_body.add_child(b)
	)

func show_ending_modal(title_text: String, story_text: String) -> void:
	_title.text = "대단원: %s" % title_text
	_clear_body()
	var st := Label.new()
	st.text = story_text
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	st.add_theme_color_override("font_color", Color("1c1917"))
	_body.add_child(st)
	_modal_backdrop.visible = true
	_modal.visible = true

func show_named_npc_modal(npc_data: Dictionary) -> void:
	var nid: String = npc_data.get("named_id", "")
	var ninfo: Dictionary = CitizenManager.named_info(nid)
	var title_str: String = "화성 명인 열전: %s" % [ninfo.get("name", npc_data.get("name", "인물"))]

	_open(title_str, func():
		_clear_body()

		var hb_hdr := HBoxContainer.new()
		hb_hdr.add_theme_constant_override("separation", 12)
		_body.add_child(hb_hdr)

		var p_tex: Texture2D = InspectNarrativeGenerator.get_portrait(nid)
		if p_tex != null:
			var p_frame := PanelContainer.new()
			var p_sb := StyleBoxFlat.new()
			p_sb.bg_color = Color("f7f3e8")
			p_sb.border_color = Color("b39268")
			p_sb.set_border_width_all(2)
			p_sb.set_corner_radius_all(6)
			p_sb.set_content_margin_all(2)
			p_frame.add_theme_stylebox_override("panel", p_sb)
			hb_hdr.add_child(p_frame)

			var p_rect := TextureRect.new()
			p_rect.custom_minimum_size = Vector2(68, 68)
			p_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			p_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			p_rect.texture = p_tex
			if p_tex.get_width() >= 96 or p_tex.get_height() >= 96:
				p_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			else:
				p_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			p_frame.add_child(p_rect)
		else:
			var ic := Label.new()
			ic.text = ninfo.get("icon", "📜")
			ic.add_theme_font_size_override("font_size", 32)
			hb_hdr.add_child(ic)

		var vb_name := VBoxContainer.new()
		vb_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb_hdr.add_child(vb_name)

		var lb_name := Label.new()
		lb_name.text = ninfo.get("name", npc_data.get("name", "인물"))
		lb_name.add_theme_font_size_override("font_size", 19)
		lb_name.add_theme_color_override("font_color", Color("8f1d1d"))
		vb_name.add_child(lb_name)

		var lb_title := Label.new()
		lb_title.text = "%s  |  %s" % [ninfo.get("title", ""), ninfo.get("role_tag", "")]
		lb_title.add_theme_font_size_override("font_size", 13)
		lb_title.add_theme_color_override("font_color", Color("4a3b2c"))
		vb_name.add_child(lb_title)

		_body.add_child(HSeparator.new())

		var btext: String = npc_data.get("bubble_text", "")
		if btext == "":
			var lines: Array = ninfo.get("lines", [])
			if not lines.is_empty():
				btext = lines[0]

		var quote_box := PanelContainer.new()
		var q_sb := StyleBoxFlat.new()
		q_sb.bg_color = Color("fffdf5")
		q_sb.border_color = Color("8c7352")
		q_sb.set_border_width_all(1)
		q_sb.set_corner_radius_all(4)
		q_sb.set_content_margin_all(8)
		quote_box.add_theme_stylebox_override("panel", q_sb)
		_body.add_child(quote_box)

		var lb_quote := Label.new()
		lb_quote.text = "💬 \"%s\"" % btext
		lb_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lb_quote.add_theme_color_override("font_color", Color("241b12"))
		lb_quote.add_theme_font_size_override("font_size", 14)
		quote_box.add_child(lb_quote)

		var sec_lbl := Label.new()
		sec_lbl.text = "【 인물 소개 및 역사적 활약 】"
		sec_lbl.add_theme_font_size_override("font_size", 14)
		sec_lbl.add_theme_color_override("font_color", Color("3d2816"))
		_body.add_child(sec_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = ninfo.get("desc", "정조 대 화성 축성과 번영에 기여한 핵심 인물입니다.")
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_color_override("font_color", Color("2b2621"))
		desc_lbl.add_theme_font_size_override("font_size", 13)
		_body.add_child(desc_lbl)

		var act_lbl := Label.new()
		act_lbl.text = "📍 현재 동향: %s" % ninfo.get("activity", "화성 도읍 내에서 임무를 수행 중입니다.")
		act_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		act_lbl.add_theme_color_override("font_color", Color("1b4478"))
		act_lbl.add_theme_font_size_override("font_size", 12)
		_body.add_child(act_lbl)

		_body.add_child(HSeparator.new())

		var btn_close := Button.new()
		btn_close.text = "살펴보기 완료"
		btn_close.custom_minimum_size = Vector2(0, 36)
		btn_close.pressed.connect(_close_modal)
		_body.add_child(btn_close)
	)

# ============================================================ 게임 시스템 설정 모달 (System Settings)

func _open_game_settings_modal() -> void:
	_open("⚙️ 화성성역 환경 설정", _build_game_settings)
	_modal_no_refresh = true

## 성곽 보수 창(_build_wall_repair)이 쓰는 카드 — 설정 카드와 같은 모양(안에 "VBox")
func _create_card(title_txt: String) -> PanelContainer:
	return _create_settings_card(title_txt)

func _create_settings_card(title_txt: String) -> PanelContainer:
	var card := PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.97, 0.94, 0.88, 1.0) # 밝은 닥종이 베이지
	csb.border_color = Color("8c7352") # 옻칠 테두리
	csb.set_border_width_all(1)
	csb.set_corner_radius_all(6)
	csb.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", csb)

	var vb := VBoxContainer.new()
	vb.name = "VBox"
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	var head_lbl := Label.new()
	head_lbl.text = title_txt
	head_lbl.add_theme_color_override("font_color", Color("78350f"))
	head_lbl.add_theme_font_size_override("font_size", 14)
	vb.add_child(head_lbl)

	return card

func _apply_settings_btn_style(btn: Button, bg_col: Color, border_col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", sb)

	var hsb := sb.duplicate()
	hsb.bg_color = bg_col.lightened(0.2)
	hsb.border_color = Color(0.98, 0.85, 0.35)
	hsb.set_border_width_all(2)
	btn.add_theme_stylebox_override("hover", hsb)

	var psb := sb.duplicate()
	psb.bg_color = bg_col.darkened(0.2)
	btn.add_theme_stylebox_override("pressed", psb)

	btn.add_theme_color_override("font_color", Color(0.98, 0.95, 0.85))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.7))
	btn.add_theme_font_size_override("font_size", 12)

func _on_settings_toast(msg: String) -> void:
	if hud:
		hud._show_toast(msg, "⚙️")

func _build_game_settings() -> void:
	_clear_body()

	var desc_lbl := Label.new()
	desc_lbl.text = "화성성역의 치세 환경, 실록 보존(저장/불러오기) 및 풍악(음향)을 조율합니다."
	desc_lbl.add_theme_color_override("font_color", Color("451a03"))
	desc_lbl.add_theme_font_size_override("font_size", 13)
	_body.add_child(desc_lbl)

	# 1~7. 통일된 환경설정 카드 집합 (화면, 사운드, 시보, 김판관, 현장 바로가기, 재난 팝업, 결산 알림)
	GameSettings.build_unified_settings_cards(_body, Callable(self, "_on_settings_toast"), Callable(self, "_build_game_settings"))

	# 8. 치세 실록 보존 (저장하기 - Save)
	var save_card := _create_settings_card("치세 실록 보존 (기록 저장)")
	_body.add_child(save_card)
	var save_box := save_card.get_node("VBox") as VBoxContainer

	var save_desc := Label.new()
	save_desc.text = "현재의 고을 배치, 성곽 석축, 국고, 군량 및 치세 진행 상황을 실록 권에 기록합니다."
	save_desc.add_theme_color_override("font_color", Color("57534e"))
	save_desc.add_theme_font_size_override("font_size", 12)
	save_box.add_child(save_desc)

	var save_slots_hb := HBoxContainer.new()
	save_slots_hb.add_theme_constant_override("separation", 10)
	save_box.add_child(save_slots_hb)

	for slot_idx: int in SaveSystem.SLOTS:
		var slot_p := PanelContainer.new()
		slot_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sp_sb := StyleBoxFlat.new()
		sp_sb.bg_color = Color(0.96, 0.92, 0.84, 0.95)
		sp_sb.border_color = Color("8c7353")
		sp_sb.set_border_width_all(1)
		sp_sb.set_corner_radius_all(4)
		sp_sb.set_content_margin_all(8)
		slot_p.add_theme_stylebox_override("panel", sp_sb)
		save_slots_hb.add_child(slot_p)

		var slot_vb := VBoxContainer.new()
		slot_vb.add_theme_constant_override("separation", 4)
		slot_p.add_child(slot_vb)

		var s_info: Dictionary = SaveSystem.get_save_info(slot_idx)
		var s_has: bool = SaveSystem.has_save(slot_idx) and not s_info.is_empty()

		var title_l := Label.new()
		title_l.text = SaveSystem.get_slot_title_prefix(slot_idx)
		title_l.add_theme_color_override("font_color", Color("1c1917"))
		title_l.add_theme_font_size_override("font_size", 12 if slot_idx == 0 else 13)
		slot_vb.add_child(title_l)

		var info_l := Label.new()
		if s_has:
			info_l.text = "%d년 %s [%d개월째]\n인구 %d | %s" % [
				int(s_info.get("year", 1776)), str(s_info.get("season", "봄")),
				int(s_info.get("turn", 1)), int(s_info.get("pop", 120)),
				str(s_info.get("timestamp", "")).left(10)
			]
		else:
			info_l.text = "【빈 기록 칸】\n새로 기록 가능"
		info_l.add_theme_color_override("font_color", Color("78716c"))
		info_l.add_theme_font_size_override("font_size", 11)
		slot_vb.add_child(info_l)

		var s_btn := Button.new()
		s_btn.text = "💾 %s에 저장" % SaveSystem.get_slot_display_name(slot_idx)
		s_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_apply_settings_btn_style(s_btn, Color(0.18, 0.12, 0.08), Color(0.75, 0.55, 0.25))
		s_btn.pressed.connect(func():
			var ok := SaveSystem.save_game(slot_idx, sim, grid, quests)
			if ok:
				if hud: hud._show_toast("%s에 치세가 무사히 보존되었습니다!" % SaveSystem.get_slot_title_prefix(slot_idx), "💾")
				if audio: audio.play("coin")
				_build_game_settings()
			else:
				if hud: hud._show_toast("실록 보존에 실패했습니다.", "❌")
		)
		slot_vb.add_child(s_btn)

	# 3. 치세 실록 계승 (불러오기 - Load)
	var load_card := _create_settings_card("📜 치세 실록 계승 (기록 불러오기)")
	_body.add_child(load_card)
	var load_box := load_card.get_node("VBox") as VBoxContainer

	var load_desc := Label.new()
	load_desc.text = "보존된 실록 권을 불러와 과거의 치세 및 축성 상태를 복원합니다."
	load_desc.add_theme_color_override("font_color", Color("57534e"))
	load_desc.add_theme_font_size_override("font_size", 12)
	load_box.add_child(load_desc)

	var load_slots_hb := HBoxContainer.new()
	load_slots_hb.add_theme_constant_override("separation", 10)
	load_box.add_child(load_slots_hb)

	for slot_idx: int in SaveSystem.SLOTS:
		var slot_p := PanelContainer.new()
		slot_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sp_sb := StyleBoxFlat.new()
		sp_sb.bg_color = Color(0.96, 0.92, 0.84, 0.95)
		sp_sb.border_color = Color("8c7353")
		sp_sb.set_border_width_all(1)
		sp_sb.set_corner_radius_all(4)
		sp_sb.set_content_margin_all(8)
		slot_p.add_theme_stylebox_override("panel", sp_sb)
		load_slots_hb.add_child(slot_p)

		var slot_vb := VBoxContainer.new()
		slot_vb.add_theme_constant_override("separation", 4)
		slot_p.add_child(slot_vb)

		var s_info: Dictionary = SaveSystem.get_save_info(slot_idx)
		var s_has: bool = SaveSystem.has_save(slot_idx) and not s_info.is_empty()

		var title_l := Label.new()
		title_l.text = SaveSystem.get_slot_title_prefix(slot_idx)
		title_l.add_theme_color_override("font_color", Color("1c1917"))
		title_l.add_theme_font_size_override("font_size", 12 if slot_idx == 0 else 13)
		slot_vb.add_child(title_l)

		var info_l := Label.new()
		if s_has:
			info_l.text = "%d년 %s [%d개월째]\n인구 %d명 | 국고 %d냥" % [
				int(s_info.get("year", 1776)), str(s_info.get("season", "봄")),
				int(s_info.get("turn", 1)), int(s_info.get("pop", 120)),
				int(s_info.get("gold", 2500))
			]
		else:
			info_l.text = "【기록 없음】\n불러올 수 없음"
		info_l.add_theme_color_override("font_color", Color("78716c"))
		info_l.add_theme_font_size_override("font_size", 11)
		slot_vb.add_child(info_l)

		var btn_box := HBoxContainer.new()
		btn_box.add_theme_constant_override("separation", 4)
		slot_vb.add_child(btn_box)

		var l_btn := Button.new()
		l_btn.text = "📂 불러오기"
		l_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l_btn.disabled = not s_has
		l_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if s_has else Control.CURSOR_ARROW
		_apply_settings_btn_style(l_btn, Color(0.12, 0.18, 0.28) if s_has else Color(0.3, 0.3, 0.3), Color(0.4, 0.65, 0.95) if s_has else Color(0.5, 0.5, 0.5))
		l_btn.pressed.connect(func():
			_show_load_confirm(slot_idx)
		)
		btn_box.add_child(l_btn)

		if s_has:
			var del_slot_btn := Button.new()
			del_slot_btn.text = "🗑️ 파기"
			del_slot_btn.custom_minimum_size = Vector2(50, 0)
			del_slot_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			_apply_settings_btn_style(del_slot_btn, Color(0.35, 0.10, 0.08), Color(0.85, 0.30, 0.25))
			del_slot_btn.pressed.connect(func():
				_show_delete_save_confirm(slot_idx)
			)
			btn_box.add_child(del_slot_btn)

	# 4. 새 게임 시작 & 게임 종료 (시스템 제어)
	var sys_card := _create_settings_card("⚙️ 치세 다스리기 (새 치세 / 치세 마치기)")
	_body.add_child(sys_card)
	var sys_box := sys_card.get_node("VBox") as VBoxContainer

	var sys_btn_hb := HBoxContainer.new()
	sys_btn_hb.add_theme_constant_override("separation", 12)
	sys_box.add_child(sys_btn_hb)

	# 새 게임 버튼
	var new_game_btn := Button.new()
	new_game_btn.text = "🔄 새 치세 시작"
	new_game_btn.custom_minimum_size = Vector2(160, 36)
	new_game_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_settings_btn_style(new_game_btn, Color(0.35, 0.12, 0.08), Color(0.95, 0.50, 0.20))
	new_game_btn.pressed.connect(_show_new_game_confirm)
	sys_btn_hb.add_child(new_game_btn)

	# 게임 종료 버튼
	var exit_btn := Button.new()
	exit_btn.text = "🚪 치세 마치기"
	exit_btn.custom_minimum_size = Vector2(160, 36)
	exit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_settings_btn_style(exit_btn, Color(0.20, 0.10, 0.10), Color(0.70, 0.30, 0.30))
	exit_btn.pressed.connect(_show_exit_confirm)
	sys_btn_hb.add_child(exit_btn)

func _show_new_game_confirm() -> void:
	_clear_body()

	var card := _create_settings_card("⚠️ 새 치세 시작 확인")
	_body.add_child(card)
	var box := card.get_node("VBox") as VBoxContainer

	var warn_lbl := Label.new()
	warn_lbl.text = "정말로 새로운 치세를 시작하시겠습니까?\n\n현재 저장되지 않은 모든 축성 및 재정 기록은 사라지며,\n정조 원년(1776) 봄으로 새롭게 판이 시작됩니다."
	warn_lbl.add_theme_color_override("font_color", Color("7f1d1d"))
	warn_lbl.add_theme_font_size_override("font_size", 14)
	warn_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(warn_lbl)

	var btn_hb := HBoxContainer.new()
	btn_hb.add_theme_constant_override("separation", 12)
	box.add_child(btn_hb)

	var confirm_btn := Button.new()
	confirm_btn.text = "🔄 확인 (새 치세 시작)"
	confirm_btn.custom_minimum_size = Vector2(180, 36)
	confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_settings_btn_style(confirm_btn, Color(0.45, 0.12, 0.08), Color(0.98, 0.40, 0.20))
	confirm_btn.pressed.connect(func():
		_close_modal()
		get_tree().reload_current_scene()
	)
	btn_hb.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "돌아가기"
	cancel_btn.custom_minimum_size = Vector2(120, 36)
	cancel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_settings_btn_style(cancel_btn, Color(0.25, 0.20, 0.16), Color(0.55, 0.45, 0.35))
	cancel_btn.pressed.connect(_build_game_settings)
	btn_hb.add_child(cancel_btn)

func _show_load_confirm(slot_id: int) -> void:
	_clear_body()

	var slot_title := SaveSystem.get_slot_title_prefix(slot_id)
	var card := _create_settings_card("📜 %s 불러오기 확인" % slot_title)
	_body.add_child(card)
	var box := card.get_node("VBox") as VBoxContainer

	var s_info: Dictionary = SaveSystem.get_save_info(slot_id)
	var warn_lbl := Label.new()
	warn_lbl.text = "%s의 기록을 불러와 치세를 계승하시겠습니까?\n\n【선택된 기록】\n%s\n인구 %d명 | 국고 %d냥 | 군량 %d석 | 성곽 %d%%\n\n⚠️ 현재 진행 중인 상태는 실록 내용으로 덮어씌워집니다." % [
		slot_title,
		SaveSystem.get_formatted_title(slot_id, s_info),
		int(s_info.get("pop", 120)), int(s_info.get("gold", 2500)),
		int(s_info.get("rice", 1600)), int(s_info.get("fortress", 0))
	]
	warn_lbl.add_theme_color_override("font_color", Color("1e3a8a"))
	warn_lbl.add_theme_font_size_override("font_size", 13)
	warn_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(warn_lbl)

	var btn_hb := HBoxContainer.new()
	btn_hb.add_theme_constant_override("separation", 12)
	box.add_child(btn_hb)

	var confirm_btn := Button.new()
	confirm_btn.text = "📂 불러오기 실행"
	confirm_btn.custom_minimum_size = Vector2(160, 36)
	confirm_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_settings_btn_style(confirm_btn, Color(0.12, 0.22, 0.38), Color(0.40, 0.70, 0.98))
	confirm_btn.pressed.connect(func():
		var ok := SaveSystem.load_game(slot_id, sim, grid, time_manager, quests)
		if ok:
			_close_modal()
			var main_node: Node = get_parent()
			if main_node and main_node.has_method("on_game_loaded"):
				main_node.on_game_loaded()
			elif main_node and main_node.has_method("sync_all_world_markers"):
				main_node.sync_all_world_markers()
			if hud: hud._show_toast("%s의 기록을 성공적으로 복원했습니다!" % slot_title, "📜")
			if audio: audio.play("season")
		else:
			if hud: hud._show_toast("실록 복원에 실패했습니다.", "❌")
	)
	btn_hb.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "돌아가기"
	cancel_btn.custom_minimum_size = Vector2(120, 36)
	cancel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_settings_btn_style(cancel_btn, Color(0.25, 0.20, 0.16), Color(0.55, 0.45, 0.35))
	cancel_btn.pressed.connect(_build_game_settings)
	btn_hb.add_child(cancel_btn)

func _show_delete_save_confirm(slot_id: int) -> void:
	_clear_body()

	var slot_title := SaveSystem.get_slot_title_prefix(slot_id)
	var card := _create_settings_card("🗑️ %s 영구 파기 확인" % slot_title)
	_body.add_child(card)
	var box := card.get_node("VBox") as VBoxContainer

	var s_info: Dictionary = SaveSystem.get_save_info(slot_id)
	var warn_lbl := Label.new()
	warn_lbl.text = "%s의 기록을 영구히 파기하시겠습니까?\n\n【파기 대상 기록】\n%s\n인구 %d명 | 국고 %d냥\n\n⚠️ 파기된 실록 기록은 절대 복구할 수 없습니다." % [
		slot_title,
		SaveSystem.get_formatted_title(slot_id, s_info),
		int(s_info.get("pop", 120)), int(s_info.get("gold", 2500))
	]
	warn_lbl.add_theme_color_override("font_color", Color("7f1d1d"))
	warn_lbl.add_theme_font_size_override("font_size", 13)
	warn_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(warn_lbl)

	var btn_hb := HBoxContainer.new()
	btn_hb.add_theme_constant_override("separation", 12)
	box.add_child(btn_hb)

	var confirm_del_btn := Button.new()
	confirm_del_btn.text = "🗑️ 영구 파기 (삭제)"
	confirm_del_btn.custom_minimum_size = Vector2(160, 36)
	confirm_del_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_settings_btn_style(confirm_del_btn, Color(0.45, 0.12, 0.08), Color(0.95, 0.30, 0.25))
	confirm_del_btn.pressed.connect(func():
		var ok := SaveSystem.delete_save(slot_id)
		if ok:
			if hud: hud._show_toast("%s 기록이 영구히 파기되었습니다." % slot_title, "🗑️")
			if audio: audio.play("coin")
		else:
			if hud: hud._show_toast("실록 기록 삭제에 실패했습니다.", "❌")
		_build_game_settings()
	)
	btn_hb.add_child(confirm_del_btn)

	var cancel_btn2 := Button.new()
	cancel_btn2.text = "취소 (돌아가기)"
	cancel_btn2.custom_minimum_size = Vector2(120, 36)
	cancel_btn2.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_settings_btn_style(cancel_btn2, Color(0.25, 0.20, 0.16), Color(0.55, 0.45, 0.35))
	cancel_btn2.pressed.connect(_build_game_settings)
	btn_hb.add_child(cancel_btn2)

func _show_exit_confirm() -> void:
	_clear_body()

	var card := _create_settings_card("🚪 치세 마치기 확인")
	_body.add_child(card)
	var box := card.get_node("VBox") as VBoxContainer

	var warn_lbl := Label.new()
	warn_lbl.text = "화성성역을 종료하시겠습니까?\n\n저장하지 않은 진행 내역은 사라질 수 있으므로\n종료 전에 실록에 보존되었는지 확인하십시오."
	warn_lbl.add_theme_color_override("font_color", Color("451a03"))
	warn_lbl.add_theme_font_size_override("font_size", 13)
	box.add_child(warn_lbl)

	var btn_hb := HBoxContainer.new()
	btn_hb.add_theme_constant_override("separation", 12)
	box.add_child(btn_hb)

	var title_btn := Button.new()
	title_btn.text = "🏠 첫 화면으로"
	title_btn.custom_minimum_size = Vector2(150, 36)
	title_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_settings_btn_style(title_btn, Color(0.25, 0.16, 0.11), Color(0.85, 0.65, 0.35))
	title_btn.pressed.connect(func():
		_close_modal()
		emit_signal("title_screen_requested")
	)
	btn_hb.add_child(title_btn)

	var quit_btn := Button.new()
	quit_btn.text = "❌ 화성성역 완전히 끝내기"
	quit_btn.custom_minimum_size = Vector2(150, 36)
	quit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_settings_btn_style(quit_btn, Color(0.40, 0.10, 0.10), Color(0.85, 0.30, 0.30))
	quit_btn.pressed.connect(func():
		if OS.has_feature("web"):
			_close_modal()
			emit_signal("title_screen_requested")
		else:
			get_tree().quit()
	)
	btn_hb.add_child(quit_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "돌아가기"
	cancel_btn.custom_minimum_size = Vector2(100, 36)
	cancel_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_settings_btn_style(cancel_btn, Color(0.25, 0.20, 0.16), Color(0.55, 0.45, 0.35))
	cancel_btn.pressed.connect(_build_game_settings)
	btn_hb.add_child(cancel_btn)

# ------------------------------------------------------------ 성곽 보수 및 사대문 방호 체제 모달
func _build_wall_repair() -> void:
	_clear_body()
	if not grid or not sim:
		return
	# 근대화 시대: 문화재 보수(문화재 보존도)
	var um: UrbanEvolutionManager = UrbanEvolutionManager.instance
	if ModernizationManager.is_active() and um != null:
		var hc := int(round(um.heritage_condition))
		_modern_label("🏯 화성 문화재 보존도: %d%%  — 성곽·사대문·수문·군사시설·행궁은 해마다 조금씩 낡고(-%.1f), 침공·반란·전쟁 때 크게 부서집니다.\n보존도는 1945년 결산 점수의 30%%를 차지합니다." % [hc, UrbanEvolutionManager.HERITAGE_DECAY_PER_YEAR], Color("7c2d12"))
		var bar := ProgressBar.new()
		bar.max_value = 100.0
		bar.value = um.heritage_condition
		bar.custom_minimum_size = Vector2(0, 14)
		_body.add_child(bar)
		var rb := Button.new()
		rb.text = "🧱 문화재 보수 (금 %d냥, 보존도 +%d)" % [UrbanEvolutionManager.HERITAGE_RESTORE_COST, int(UrbanEvolutionManager.HERITAGE_RESTORE_STEP)]
		rb.disabled = hc >= 100 or sim.gold < UrbanEvolutionManager.HERITAGE_RESTORE_COST
		rb.pressed.connect(func():
			if um.restore_heritage():
				hud._show_toast("석수와 목수들이 성곽과 문루를 보수했습니다. (문화재 보존도 +%d)" % int(UrbanEvolutionManager.HERITAGE_RESTORE_STEP), "🧱")
			_build_wall_repair()
		)
		_body.add_child(rb)

	var sg: SiegeSystem = citizens.siege if citizens else null
	var cur_def: int = sg.defense_power() if sg else 1000
	var fatigue: int = sim.defense_fatigue
	var damage_taken: int = CityStats.get_defense_damage_taken()
	var cur_defense_stat: int = CityStats.get_fortress_defense_power()
	var max_defense_stat: int = CityStats.get_max_defense_power()
	var cur_attack_stat: int = CityStats.get_military_attack_power()
	var drill_bonus: int = CityStats.get_seojangdae_drill_bonus()
	var has_bau_or_lee: bool = sim.retainers.get("kim_bau", false) or sim.retainers.get("lee_seonggil", false) or sim.retainers.get("jeong_yakyong", false)

	var loop_res: Dictionary = grid.wall_loop_validator.validate_loop(grid)
	var is_loop_closed: bool = bool(loop_res.get("is_closed_loop", false))

	# 0. 김판관(보좌관) 맞춤형 정무 브리핑 카드
	var card_advice := _create_card("판관 김종수(金鍾秀)의 성곽 방호 및 수축 상소")
	_body.add_child(card_advice)
	var box_advice := card_advice.get_node("VBox") as VBoxContainer

	var advice_text := ""
	if damage_taken > 0 or fatigue > 0:
		advice_text = "전하! 지난 도적 침구(侵寇)와 치열한 공방전으로 인해 성곽 일부가 훼손되고 방호력이 %d만큼 감소하였사옵니다.\n" % maxi(damage_taken, fatigue)
		advice_text += "방치할 시 민심이 동요하고 재침략의 화를 면치 못하오니, 즉각 '긴급 땜질'을 명하시거나 '수축 대역사'를 일으켜 복구하셔야 하옵니다."
		if has_bau_or_lee:
			advice_text += "\n[명장 지원]: 등용된 장인(김바우·이성길)의 지휘로 긴급 보수 비용이 20% 절감되고 회복량이 30% 증강(390 회복)되옵니다!"
		else:
			advice_text += "\n[조언]: 규장각에서 석수장 김바우나 도편수 이성길을 등용하시면 보수 비용과 공기를 크게 절감할 수 있사옵니다."
	elif not is_loop_closed:
		advice_text = "전하, 아직 성곽 둘레가 온전히 이어지지 않아 사대문 폐곡선이 완성되지 못하였사옵니다.\n"
		advice_text += "단절된 구간으로 도적과 맹수가 침입할 수 있사오니, '미완성 지점 확인'을 통하여 끊어진 성곽 구간을 점검하시고 조속히 완공하시길 청하옵니다."
	else:
		advice_text = "전하! 사대문과 성곽이 빈틈없는 폐곡선(완공도 %d%%)을 이루어 철옹성 같은 방호 태세를 자랑하고 있사옵니다!\n" % grid.fortress_progress
		advice_text += "평시에도 방심하지 마시고 서장대 야조 군사 훈련을 거행하시어 군사들의 사기를 드높이시옵소서."

	var advice_lbl := Label.new()
	advice_lbl.text = advice_text
	advice_lbl.add_theme_color_override("font_color", Color("451a03"))
	advice_lbl.add_theme_font_size_override("font_size", 12)
	advice_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box_advice.add_child(advice_lbl)

	# 1. 상단 현황 카드: 방호력 및 군사 공격력 현황
	var card_def := _create_card("성 방호력(내구도) 및 장용영 군사 공격력 현황")
	_body.add_child(card_def)
	var box_def := card_def.get_node("VBox") as VBoxContainer

	var def_lbl := Label.new()
	def_lbl.text = "• 성 방호력(체력/내구도): %d / %d (완공도 %d%%, 보수 누적 +%d, 피해/피로 -%d)\n• 장용영 군사 공격력: %d (야조 훈련 가산: +%d)" % [
		cur_defense_stat, max_defense_stat, grid.fortress_progress, CityStats.defense_repair_bonus, maxi(damage_taken, fatigue), cur_attack_stat, drill_bonus
	]
	def_lbl.add_theme_color_override("font_color", Color("451a03"))
	def_lbl.add_theme_font_size_override("font_size", 13)
	box_def.add_child(def_lbl)

	# 상태 경고
	var status_text := ""
	if cur_def <= 400 or cur_defense_stat <= 200:
		status_text = "⚠️ 긴급 경고: 성곽 일부가 무너져 내렸습니다! 방치 시 민심이 급락하고 침략 위험이 치솟습니다."
	elif cur_def <= 700 or damage_taken > 0:
		status_text = "⚠️ 주의: 성벽 곳곳에 심각한 균열과 그을음이 발생했습니다. 조속한 보수가 필요합니다."
	elif cur_def < 1000 or cur_defense_stat < max_defense_stat:
		status_text = "ℹ️ 성곽에 경미한 손상이 누적되어 있습니다."
	else:
		status_text = "✨ 성곽이 완벽한 방호 태세를 유지하고 있습니다."

	var status_lbl := Label.new()
	status_lbl.text = status_text
	status_lbl.add_theme_color_override("font_color", Color("a93226") if (cur_def < 700 or damage_taken > 0) else Color("1e8449"))
	status_lbl.add_theme_font_size_override("font_size", 12)
	box_def.add_child(status_lbl)

	# 2. 사대문 폐곡선(Closed Loop) 연결 검증 카드
	var card_loop := _create_card("사대문 폐곡선 연결 검증")
	_body.add_child(card_loop)
	var box_loop := card_loop.get_node("VBox") as VBoxContainer

	var loop_lbl := Label.new()
	loop_lbl.text = loop_res.get("tooltip_message", "사대문 연결 상태 확인 중...")
	loop_lbl.add_theme_color_override("font_color", Color("1e8449") if is_loop_closed else Color("b03a2e"))
	loop_lbl.add_theme_font_size_override("font_size", 12)
	loop_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box_loop.add_child(loop_lbl)

	# 성곽 미완성 끊김 구간 탐색 버튼 (폐곡선 미완성 시 표시)
	var unconn_points: Array[Vector2i] = grid.wall_loop_validator.find_unconnected_wall_points(grid)
	if not is_loop_closed and not unconn_points.is_empty():
		var hb_unconn := HBoxContainer.new()
		hb_unconn.add_theme_constant_override("separation", 8)
		box_loop.add_child(hb_unconn)

		var btn_unconn := Button.new()
		btn_unconn.text = "🔍 미완성 지점 확인 (%d곳)" % unconn_points.size()
		btn_unconn.custom_minimum_size = Vector2(180, 32)
		btn_unconn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_apply_settings_btn_style(btn_unconn, Color(0.45, 0.18, 0.12), Color(0.95, 0.75, 0.45))
		btn_unconn.pressed.connect(func():
			var target_idx: int = _unconn_wall_idx % unconn_points.size()
			var target_pt: Vector2i = unconn_points[target_idx]
			_unconn_wall_idx += 1
			_close_modal()
			var elev: float = float(grid.grid[target_pt.y][target_pt.x].get("elevation", 0.0)) if grid.in_bounds(target_pt.x, target_pt.y) else 0.0
			var w_pos := Vector2((float(target_pt.x) - float(target_pt.y)) * 32.0, (float(target_pt.x) + float(target_pt.y)) * 16.0 - elev * 12.0)
			if city and city.has_method("cell_center"):
				w_pos = city.cell_center(float(target_pt.x) + 0.5, float(target_pt.y) + 0.5, elev)
			if camera:
				camera.focus_on_coordinate(w_pos, true, 0.8)
			if city:
				city.show_wall_guide(target_pt, 5.0)
			if hud:
				hud._show_toast("성곽 미완성 지점 (%d, %d) 확인 (총 %d곳 중 %d번째)" % [target_pt.x, target_pt.y, unconn_points.size(), target_idx + 1], "🔍")
		)
		hb_unconn.add_child(btn_unconn)

		var lbl_hint := Label.new()
		lbl_hint.text = "단추를 누르면 끊어진 성곽 자리로 화면이 옮겨 가고 붉은 표시가 나타납니다."
		lbl_hint.add_theme_color_override("font_color", Color("78350f"))
		lbl_hint.add_theme_font_size_override("font_size", 11)
		hb_unconn.add_child(lbl_hint)

	# 3. 보수 공사 3-Track 메커니즘 조작 카드
	var card_actions := _create_card("성곽 보수 공사 결단 (세 갈래: 긴급땜질 / 대역사 / 직접보수)")
	_body.add_child(card_actions)
	var box_actions := card_actions.get_node("VBox") as VBoxContainer

	# Track 1: 긴급 땜질 보수
	var hb_em := HBoxContainer.new()
	hb_em.add_theme_constant_override("separation", 8)
	box_actions.add_child(hb_em)

	var has_em_buff: bool = has_bau_or_lee
	var em_cost_g: int = 480 if has_em_buff else 600
	var em_cost_r: int = 240 if has_em_buff else 300
	var em_rec: int = 390 if has_em_buff else 300
	var actual_damage: int = maxi(damage_taken, fatigue)
	var needs_repair: bool = actual_damage > 0
	var has_res: bool = (sim != null and sim.gold >= em_cost_g and sim.rice >= em_cost_r)
	var can_em_repair: bool = needs_repair and has_res

	var em_desc := Label.new()
	var em_status_desc: String = "⚠️ 현재 침략 누적 피해: -%d (즉시 응급 복구 권장)" % actual_damage if needs_repair else "✨ 현재 성곽에 침략 피해가 없어 긴급 땜질이 필요하지 않습니다."
	em_desc.text = "긴급 땜질 보수 (비상 응급 복구)\n• 설명: 도적이나 외적 침공으로 성벽이 파손되어 방호력 피해가 발생했을 때 비상 자재를 투입하여 방호력을 즉시 복구합니다.\n• 비용: 금 %d냥, 곡 %d석 | 효과: 방호력 %d 즉시 회복%s\n• 상태: %s" % [
		em_cost_g, em_cost_r, em_rec, " [김바우/이성길 혜택 적용: 비용 -20%, 회복 +30%]" if has_em_buff else "", em_status_desc
	]
	em_desc.add_theme_color_override("font_color", Color("451a03"))
	em_desc.add_theme_font_size_override("font_size", 12)
	em_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_em.add_child(em_desc)

	var btn_em := Button.new()
	btn_em.text = "🪵 긴급 땜질" if needs_repair else "🪵 땜질 불필요 (온전함)"
	btn_em.custom_minimum_size = Vector2(140, 36)
	btn_em.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_em_repair else Control.CURSOR_ARROW
	_apply_settings_btn_style(btn_em, Color(0.35, 0.22, 0.12) if can_em_repair else Color(0.25, 0.25, 0.25), Color(0.85, 0.65, 0.35) if can_em_repair else Color(0.55, 0.55, 0.55))
	btn_em.disabled = not can_em_repair
	if not needs_repair:
		btn_em.tooltip_text = "현재 성곽에 침략 피해가 없어 긴급 땜질을 진행할 필요가 없습니다."
	elif not has_res:
		btn_em.tooltip_text = "자금 또는 군량이 부족합니다 (필요: 금 %d냥, 곡 %d석)." % [em_cost_g, em_cost_r]
	else:
		btn_em.tooltip_text = "비상 자재를 투입하여 침략 피해 %d을(를) 즉시 복구합니다." % mini(actual_damage, em_rec)
	btn_em.pressed.connect(func():
		if sg and can_em_repair:
			var res: Dictionary = sg.emergency_repair()
			if res.get("success", false):
				sim.emit_signal("state_updated", sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)
				_build_wall_repair()
	)
	hb_em.add_child(btn_em)

	# Track 2: 수축(修築) 대역사 발주
	var hb_grand := HBoxContainer.new()
	hb_grand.add_theme_constant_override("separation", 8)
	box_actions.add_child(hb_grand)

	var has_buff: bool = has_bau_or_lee
	var grand_cost_g: int = 210 if has_buff else 300
	var grand_cost_r: int = 140 if has_buff else 200
	var grand_rec: int = 150 if has_buff else 100

	var grand_desc := Label.new()
	grand_desc.text = "수축(修築) 대역사 (정밀 보수)\n매달 비용: 금 %d냥, 곡 %d석 | 매달 방호력 +%d 점진 회복%s" % [
		grand_cost_g, grand_cost_r, grand_rec, " [정약용/김바우 혜택 적용: 비용 -30%, 회복 +50%]" if has_buff else ""
	]
	grand_desc.add_theme_color_override("font_color", Color("451a03"))
	grand_desc.add_theme_font_size_override("font_size", 12)
	grand_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_grand.add_child(grand_desc)

	var is_repair_active: bool = bool(sg.repair_state.get("active", false)) if sg else false
	var btn_grand := Button.new()
	btn_grand.text = "🛑 대역사 중단" if is_repair_active else "🏗️ 수축 발주"
	btn_grand.custom_minimum_size = Vector2(110, 32)
	btn_grand.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_settings_btn_style(btn_grand, Color(0.20, 0.28, 0.35) if not is_repair_active else Color(0.40, 0.15, 0.15), Color(0.70, 0.85, 0.95))
	btn_grand.pressed.connect(func():
		if sg:
			if is_repair_active:
				sg.cancel_grand_repair()
			else:
				sg.start_grand_repair()
			_build_wall_repair()
	)
	hb_grand.add_child(btn_grand)

	# Track 3: 직접 보수 — 석축 우봉고 퍼즐 미니게임
	var hb_ubongo := HBoxContainer.new()
	hb_ubongo.add_theme_constant_override("separation", 8)
	box_actions.add_child(hb_ubongo)

	var ubongo_desc := Label.new()
	ubongo_desc.text = "직접 보수 (성돌 맞추기)\n• 비용: 긴급 땜질과 동일 (금 %d냥, 곡 %d석)\n• 성돌 조각(3→4→5개)을 직접 맞춰 쌓는 세 판짜리 성돌 맞추기에 도전!\n• 성공 수: 3개(+200%%) | 2개(+100%%) | 1개(+10%%) | 전패(-10%%)" % [
		em_cost_g, em_cost_r
	]
	ubongo_desc.add_theme_color_override("font_color", Color("1e3a5f"))
	ubongo_desc.add_theme_font_size_override("font_size", 12)
	ubongo_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_ubongo.add_child(ubongo_desc)

	var btn_ubongo := Button.new()
	btn_ubongo.text = "🧱 직접 보수\n(솜씨 겨루기 도전)"
	btn_ubongo.custom_minimum_size = Vector2(120, 52)
	btn_ubongo.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_em_repair else Control.CURSOR_ARROW
	_apply_settings_btn_style(btn_ubongo, Color(0.07, 0.25, 0.40) if can_em_repair else Color(0.25, 0.25, 0.25), Color(0.55, 0.80, 0.95) if can_em_repair else Color(0.55, 0.55, 0.55))
	btn_ubongo.disabled = not can_em_repair
	if not needs_repair:
		btn_ubongo.tooltip_text = "현재 성곽에 침략 피해가 없어 보수가 필요하지 않습니다."
	elif not has_res:
		btn_ubongo.tooltip_text = "자금 또는 군량이 부족합니다 (필요: 금 %d냥, 곡 %d석)." % [em_cost_g, em_cost_r]
	else:
		btn_ubongo.tooltip_text = "긴급 땜질과 동일한 비용으로 성돌 맞추기에 도전! 성공할수록 보수 효과가 최대 +200%% 증폭됩니다."
	btn_ubongo.pressed.connect(func():
		if sg == null or not can_em_repair:
			return
		# 긴급 땜질과 동일한 비용 차감 (deduct_quick_repair_cost 역할)
		if sim.gold < em_cost_g or sim.rice < em_cost_r:
			return
		sim.gold -= em_cost_g
		sim.rice -= em_cost_r
		sim.emit_signal("state_updated", sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)
		_close_modal()
		# 우봉고 미니게임 팝업 열기
		if ubongo_wall_repair != null:
			ubongo_wall_repair.open_ubongo_puzzle(em_rec, time_manager)
	)
	hb_ubongo.add_child(btn_ubongo)


	# 4. 민·군 합동 방어 태세 카드
	var card_mob := _create_card("민·군 합동 방어 체제 (전시 총동원)")
	_body.add_child(card_mob)
	var box_mob := card_mob.get_node("VBox") as VBoxContainer

	var mob_branch_text := ""
	if sim.loyalty >= 70 and sim.authority >= 60:
		mob_branch_text = "🛡️ 결사항전 단합 태세 (민심 %d%%, 왕권 %d): 백성과 상인이 일치단결하여 민병대로 출전(공방 +30%% 효과), 부녀자 보급 지원으로 피해 20%% 경감!" % [sim.loyalty, sim.authority]
	elif sim.loyalty < 40 or sim.authority < 30:
		mob_branch_text = "⚠️ 배신 및 내통 위험 (민심 %d%%, 왕권 %d): 민심 이반으로 주민 30~50%%가 동원을 거부하며, 변절자가 성문을 몰래 열어 젖힐 위험이 매우 높습니다!" % [sim.loyalty, sim.authority]
	else:
		mob_branch_text = "⚔️ 일반 방어 태세 (민심 %d%%, 왕권 %d): 상인과 주민이 의병으로 참전하며 부녀자가 주먹밥과 물동이를 보급합니다." % [sim.loyalty, sim.authority]

	var mob_lbl := Label.new()
	mob_lbl.text = mob_branch_text
	mob_lbl.add_theme_color_override("font_color", Color("451a03"))
	mob_lbl.add_theme_font_size_override("font_size", 12)
	box_mob.add_child(mob_lbl)

	# 5. 장용영 정예 군사 훈련 2칸 분할 (좌: 서장대 야조 / 우: 연무대 무예 사열)
	var hb_drills := HBoxContainer.new()
	hb_drills.add_theme_constant_override("separation", 10)
	hb_drills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(hb_drills)

	# [좌측 칸]: 서장대 연례 야간 군사 훈련 (야조: 夜操)
	var card_sj := _create_card("서장대 연례 야간 군사 훈련 (야조: 夜操)")
	card_sj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_drills.add_child(card_sj)
	var box_sj := card_sj.get_node("VBox") as VBoxContainer

	var has_sj: bool = grid.count_completed("seojangdae") > 0
	var cd_months_sj: int = sim.seojangdae_drill_cd_months
	var drill_b: int = CityStats.get_seojangdae_drill_bonus()
	var cur_atk: int = CityStats.get_military_attack_power()
	var drill_cost_sj: Dictionary = DifficultyManager.get_seojangdae_drill_cost()
	var cost_g_sj: int = int(drill_cost_sj.get("gold", 2000))
	var cost_r_sj: int = int(drill_cost_sj.get("rice", 1000))

	var drill_info_sj := Label.new()
	drill_info_sj.text = "• 서장대(사령부) 완공: %s\n• 현재 공격력: %d (야조 누적: +%d / 최대 1000)\n• 훈련 비용: 금 %s냥, 곡 %s석 | 주기: 1년(12개월)에 1회\n• 효과: 성곽 야경 횃불 점등, 공격력 영구 +50, 왕권 +5, 민심 +3" % [
		"완공됨" if has_sj else "미완공 (서장대 필요)", cur_atk, drill_b, _fmt_num(cost_g_sj), _fmt_num(cost_r_sj)
	]
	drill_info_sj.add_theme_color_override("font_color", Color("451a03"))
	drill_info_sj.add_theme_font_size_override("font_size", 12)
	drill_info_sj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box_sj.add_child(drill_info_sj)

	var hb_btn_sj := HBoxContainer.new()
	hb_btn_sj.add_theme_constant_override("separation", 8)
	box_sj.add_child(hb_btn_sj)

	var btn_sj := Button.new()
	if not has_sj:
		btn_sj.text = "🏯 서장대 미완공 (훈련 불가)"
		btn_sj.disabled = true
	elif cd_months_sj > 0:
		btn_sj.text = "✓ 올해 야조 완료 (%d개월 후 가능)" % cd_months_sj
		btn_sj.disabled = true
	elif sim.gold < cost_g_sj or sim.rice < cost_r_sj:
		btn_sj.text = "⚠️ 자금/군량 부족 (금 %s, 곡 %s 필요)" % [_fmt_num(cost_g_sj), _fmt_num(cost_r_sj)]
		btn_sj.disabled = true
	else:
		btn_sj.text = "🔥 서장대 야조 군사 훈련 거행"
		btn_sj.disabled = false
	btn_sj.custom_minimum_size = Vector2(0, 36)
	btn_sj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_sj.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not btn_sj.disabled else Control.CURSOR_ARROW
	_apply_settings_btn_style(btn_sj, Color(0.18, 0.28, 0.18) if not btn_sj.disabled else Color(0.25, 0.25, 0.25), Color(0.70, 0.95, 0.70) if not btn_sj.disabled else Color(0.55, 0.55, 0.55))

	btn_sj.pressed.connect(func():
		if seojangdae_popup != null:
			_close_modal()
			seojangdae_popup.open_seojangdae_popup()
		else:
			var res: Dictionary = sim.execute_seojangdae_drill(grid, citizens)
			if res.get("success", false):
				if hud:
					hud._show_toast(res.get("msg", "야조 훈련 완료!"), "🔥")
				if audio:
					audio.play("yajo")
				_build_wall_repair()
			else:
				if hud:
					hud._show_toast(res.get("msg", "훈련 실패"), "⚠️")
	)
	hb_btn_sj.add_child(btn_sj)

	# [우측 칸]: 연무대 장용영 무예 사열 (동장대 훈련)
	var card_ym := _create_card("연무대 장용영 무예 사열 (동장대 훈련)")
	card_ym.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_drills.add_child(card_ym)
	var box_ym := card_ym.get_node("VBox") as VBoxContainer

	var has_ym: bool = grid.count_completed("yeonmudae") > 0
	var cd_months_ym: int = sim.yeonmudae_drill_cd_months
	var drill_cost_ym: Dictionary = DifficultyManager.get_yeonmudae_drill_cost()
	var cost_g_ym: int = int(drill_cost_ym.get("gold", 2000))
	var cost_r_ym: int = int(drill_cost_ym.get("rice", 2000))

	var drill_info_ym := Label.new()
	drill_info_ym.text = "• 연무대(동장대) 완공: %s\n• 현재 공격력: %d\n• 훈련 비용: 금 %s냥, 곡 %s석 | 주기: 1년(12개월)에 1회\n• 효과: 무예24반 사열, 공격력 +40, 군사력 +5, 왕권 +5, 민심 +3" % [
		"완공됨" if has_ym else "미완공 (연무대 필요)", cur_atk, _fmt_num(cost_g_ym), _fmt_num(cost_r_ym)
	]
	drill_info_ym.add_theme_color_override("font_color", Color("451a03"))
	drill_info_ym.add_theme_font_size_override("font_size", 12)
	drill_info_ym.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box_ym.add_child(drill_info_ym)

	var hb_btn_ym := HBoxContainer.new()
	hb_btn_ym.add_theme_constant_override("separation", 8)
	box_ym.add_child(hb_btn_ym)

	var btn_ym := Button.new()
	if not has_ym:
		btn_ym.text = "🏹 연무대 미완공 (사열 불가)"
		btn_ym.disabled = true
	elif cd_months_ym > 0:
		btn_ym.text = "✓ 올해 사열 완료 (%d개월 후 가능)" % cd_months_ym
		btn_ym.disabled = true
	elif sim.gold < cost_g_ym or sim.rice < cost_r_ym:
		btn_ym.text = "⚠️ 자금/군량 부족 (금 %s, 곡 %s 필요)" % [_fmt_num(cost_g_ym), _fmt_num(cost_r_ym)]
		btn_ym.disabled = true
	else:
		btn_ym.text = "⚔️ 장용영 무예 사열 거행"
		btn_ym.disabled = false
	btn_ym.custom_minimum_size = Vector2(0, 36)
	btn_ym.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_ym.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not btn_ym.disabled else Control.CURSOR_ARROW
	_apply_settings_btn_style(btn_ym, Color(0.15, 0.24, 0.35) if not btn_ym.disabled else Color(0.25, 0.25, 0.25), Color(0.65, 0.85, 0.95) if not btn_ym.disabled else Color(0.55, 0.55, 0.55))

	btn_ym.pressed.connect(func():
		if yeonmudae_popup != null:
			_close_modal()
			yeonmudae_popup.open_yeonmudae_popup()
		else:
			var res: Dictionary = sim.execute_yeonmudae_drill(grid, 1.0)
			if res.get("success", false):
				if hud:
					hud._show_toast(res.get("msg", "무예 사열 완료!"), "⚔️")
				if audio:
					audio.play("yajo")
				_build_wall_repair()
			else:
				if hud:
					hud._show_toast(res.get("msg", "사열 실패"), "⚠️")
	)
	hb_btn_ym.add_child(btn_ym)

# ------------------------------------------------------------ 서장대 연례 군사 훈련 전용 모달
func _build_seojangdae_drill() -> void:
	_clear_body()

	var desc_lbl := Label.new()
	desc_lbl.text = "【서장대(華城壯臺) 연례 야간 군사 훈련: 야조(夜操)】\n정조 대왕께서 친히 서장대에 올라 성곽 둘레의 횃불과 청사초롱을 밝히고, 장용영 정예군에게 야간 진법 조련과 군사 훈련을 하명합니다."
	desc_lbl.add_theme_color_override("font_color", Color("78350f"))
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(desc_lbl)

	var card := _create_card("훈련 조건 및 보상")
	_body.add_child(card)
	var box := card.get_node("VBox") as VBoxContainer

	var has_sj: bool = grid.count_completed("seojangdae") > 0 if grid else false
	var cd_months: int = sim.seojangdae_drill_cd_months if sim else 0
	var drill_b: int = CityStats.get_seojangdae_drill_bonus()
	var cur_atk: int = CityStats.get_military_attack_power()
	var drill_cost: Dictionary = DifficultyManager.get_military_drill_cost()
	var cost_gold: int = int(drill_cost.get("gold", 2000))
	var cost_rice: int = int(drill_cost.get("rice", 1000))

	var drill_state_desc: String = "【훈련 가능】 1년(12개월)에 단 1회 가능"
	if cd_months > 0:
		drill_state_desc = "【올해 야조 실시 완료】 (다음 훈련까지 %d개월 남음)" % cd_months

	var stat_lbl := Label.new()
	stat_lbl.text = "• 서장대 건립 여부: %s\n• 현재 장용영 총 공격력: %d\n• 야조 훈련 누적 성장 가산: +%d (최대 +1000)\n• 훈련 상태: %s\n• 필요 소모: 금화 %s냥, 군량 %s석 (난이도 배율 적용)\n• 즉시 보상: 성곽 야경 횃불 점등, 공격력 영구 +50, 왕권 +5, 민심 +3" % [
		"완공됨" if has_sj else "미완공 (서장대를 먼저 건설하십시오)", cur_atk, drill_b, drill_state_desc,
		_fmt_num(cost_gold), _fmt_num(cost_rice)
	]
	stat_lbl.add_theme_color_override("font_color", Color("292524"))
	stat_lbl.add_theme_font_size_override("font_size", 13)
	stat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(stat_lbl)

	var btn_hb := HBoxContainer.new()
	btn_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hb.add_theme_constant_override("separation", 10)
	_body.add_child(btn_hb)

	var auto_btn := Button.new()
	var manual_btn := Button.new()

	if not has_sj:
		auto_btn.text = "서장대 미완공 (훈련 불가)"
		auto_btn.disabled = true
		manual_btn.text = "서장대 미완공 (훈련 불가)"
		manual_btn.disabled = true
	elif cd_months > 0:
		auto_btn.text = "올해 야조 실시 완료 (%d개월 후)" % cd_months
		auto_btn.disabled = true
		manual_btn.text = "올해 야조 실시 완료 (%d개월 후)" % cd_months
		manual_btn.disabled = true
	elif sim and (sim.gold < cost_gold or sim.rice < cost_rice):
		auto_btn.text = "자금/군량 부족"
		auto_btn.disabled = true
		manual_btn.text = "자금/군량 부족"
		manual_btn.disabled = true
	else:
		auto_btn.text = "자동 시행 (기본 효과 100%)"
		auto_btn.disabled = false
		manual_btn.text = "친림 지휘 (솜씨 겨루기: 80% ~ 120%)"
		manual_btn.disabled = false

	auto_btn.custom_minimum_size = Vector2(230, 40)
	auto_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_settings_btn_style(auto_btn, Color(0.18, 0.28, 0.18), Color(0.70, 0.95, 0.70))

	manual_btn.custom_minimum_size = Vector2(250, 40)
	manual_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_settings_btn_style(manual_btn, Color(0.28, 0.20, 0.15), Color(0.95, 0.85, 0.50))

	auto_btn.pressed.connect(func():
		var res: Dictionary = sim.execute_seojangdae_drill(grid, citizens, 1.0)
		if res.get("success", false):
			if hud:
				hud._show_toast(res.get("msg", "야조 훈련 완료!"), "🔥")
			if audio:
				audio.play("yajo")
			_close_modal()
		else:
			if hud:
				hud._show_toast(res.get("msg", "훈련 실패"), "⚠️")
	)

	manual_btn.pressed.connect(func():
		_close_modal()
		if seojangdae_popup != null:
			seojangdae_popup._on_manual_drill_pressed()
		elif yajo_minigame != null and sim != null:
			var pay_res: Dictionary = sim.pay_seojangdae_drill_cost(grid)
			if pay_res.get("success", false):
				yajo_minigame.start_yajo_minigame(time_manager)
	)

	btn_hb.add_child(auto_btn)
	btn_hb.add_child(manual_btn)

# ------------------------------------------------------------ 연무대 무예 사열 군사 훈련 전용 모달
func _build_yeonmudae_drill() -> void:
	_clear_body()

	var desc_lbl := Label.new()
	desc_lbl.text = "【연무대(練武臺 동장대) 장용영 무예 사열 훈련】\n정조 대왕께서 연무대에 임어하여 장용영 군사들의 창검술과 궁술을 사열하고 군기를 진작합니다."
	desc_lbl.add_theme_color_override("font_color", Color("78350f"))
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(desc_lbl)

	var card := _create_card("훈련 조건 및 보상")
	_body.add_child(card)
	var box := card.get_node("VBox") as VBoxContainer

	var has_ym: bool = grid.count_completed("yeonmudae") > 0 if grid else false
	var cd_months: int = sim.yeonmudae_drill_cd_months if sim else 0
	var drill_cost: Dictionary = DifficultyManager.get_yeonmudae_drill_cost()
	var cost_gold: int = int(drill_cost.get("gold", 2000))
	var cost_rice: int = int(drill_cost.get("rice", 2000))

	var drill_state_desc: String = "【사열 가능】 1년(12개월)에 단 1회 가능"
	if cd_months > 0:
		drill_state_desc = "【올해 사열 실시 완료】 (다음 사열까지 %d개월 남음)" % cd_months

	var stat_lbl := Label.new()
	stat_lbl.text = "• 연무대 건립 여부: %s\n• 현재 장용영 총 공격력: %d\n• 훈련 상태: %s\n• 필요 소모: 금화 %s냥, 군량 %s석 (난이도 배율 적용)\n• 즉시 보상: 장용영 공격력 영구 +40, 국방력 +5, 왕권 +5(백동수 +8), 민심 +3" % [
		"완공됨" if has_ym else "미완공 (연무대를 먼저 건설하십시오)",
		CityStats.get_military_attack_power(),
		drill_state_desc,
		_fmt_num(cost_gold),
		_fmt_num(cost_rice)
	]
	stat_lbl.add_theme_color_override("font_color", Color("292524"))
	stat_lbl.add_theme_font_size_override("font_size", 13)
	stat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(stat_lbl)

	var btn_hb := HBoxContainer.new()
	btn_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hb.add_theme_constant_override("separation", 10)
	_body.add_child(btn_hb)

	var can_drill: bool = (has_ym and cd_months <= 0 and sim != null and sim.gold >= cost_gold and sim.rice >= cost_rice)

	var auto_btn := Button.new()
	auto_btn.custom_minimum_size = Vector2(240, 40)
	auto_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_settings_btn_style(auto_btn, Color(0.18, 0.28, 0.18), Color(0.70, 0.95, 0.70))

	var manual_btn := Button.new()
	manual_btn.custom_minimum_size = Vector2(260, 40)
	manual_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_settings_btn_style(manual_btn, Color(0.28, 0.20, 0.15), Color(0.95, 0.85, 0.50))

	if not has_ym:
		auto_btn.text = "연무대 미완공 (훈련 불가)"
		auto_btn.disabled = true
		manual_btn.text = "연무대 미완공 (훈련 불가)"
		manual_btn.disabled = true
	elif cd_months > 0:
		auto_btn.text = "올해 사열 완료 (%d개월 후)" % cd_months
		auto_btn.disabled = true
		manual_btn.text = "올해 사열 완료 (%d개월 후)" % cd_months
		manual_btn.disabled = true
	elif not can_drill:
		auto_btn.text = "자금/군량 부족"
		auto_btn.disabled = true
		manual_btn.text = "자금/군량 부족"
		manual_btn.disabled = true
	else:
		auto_btn.text = "자동 시행 (기본 효과 100%)"
		auto_btn.disabled = false
		manual_btn.text = "직접 훈련 (활쏘기: 80% ~ 120%)"
		manual_btn.disabled = false

	auto_btn.pressed.connect(func():
		var res: Dictionary = sim.execute_yeonmudae_drill(grid, 1.0)
		if res.get("success", false):
			if hud:
				hud._show_toast(res.get("msg", "무예 사열 훈련 완료!"), "🎯")
			if audio:
				audio.play("select")
			_close_modal()
		else:
			if hud:
				hud._show_toast(res.get("msg", "사열 훈련 실패"), "⚠️")
	)

	manual_btn.pressed.connect(func():
		var pay_res: Dictionary = sim.pay_yeonmudae_drill_cost(grid)
		if not pay_res.get("success", false):
			if hud:
				hud._show_toast(str(pay_res.get("msg", "비용 차감 실패")), "⚠️")
			return
		_close_modal()
		if yeonmudae_minigame != null:
			yeonmudae_minigame.start_yeonmudae_minigame(time_manager)
		elif yeonmudae_popup != null and yeonmudae_popup.yeonmudae_minigame != null:
			yeonmudae_popup.yeonmudae_minigame.start_yeonmudae_minigame(time_manager)
		else:
			var fb_res: Dictionary = sim.apply_yeonmudae_drill_rewards(grid, 1.0)
			if hud:
				hud._show_toast(str(fb_res.get("msg", "무예 사열 훈련 완료!")), "🎯")
	)

	btn_hb.add_child(auto_btn)
	btn_hb.add_child(manual_btn)

var west: WesternLearning # PORT-TRACE [서학 디버프]: Main이 연결
