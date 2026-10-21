extends CanvasLayer
class_name EventManager

## [우선순위 이벤트 대기열(FIFO Queue) 및 순차 모달 엔진]
## 턴 전환 시 인재 발견, 재난, 친림 건의, 서연 추천, 비변사 시보 등 여러 이벤트 팝업이
## 한꺼번에 화면을 뒤덮거나 건물 배치 도중 오클릭을 유발하는 문제를 완벽히 차단합니다.
## 1. 우선순위 정렬: 재난(1) > 정무/친림/서연(2) > 인재/송사/딜레마(3) > 시보(4)
## 2. 플레이어 유휴(Idle) 감지: 배치/드래그/조작 중에는 보류, 유휴(0.4초) 시 1개씩 순차 팝업
## 3. 조작 가드: 모달 활성화 중 월드 클릭 및 카메라 팬 완전 차단

@warning_ignore("unused_signal")
signal event_enqueued(event_dict: Dictionary)
@warning_ignore("unused_signal")
signal event_started(event_dict: Dictionary)
@warning_ignore("unused_signal")
signal event_resolved(event_dict: Dictionary)
@warning_ignore("unused_signal")
signal queue_cleared
@warning_ignore("unused_signal")
signal location_view_requested(target_world_pos: Vector2)

const PRIORITY_CRITICAL: int = 1 # 화재/홍수 재난, 도적떼 공성전 침입
const PRIORITY_URGENT: int = 2   # 세자 서연 선택, 현륭원 친림 어명 건의
const PRIORITY_NORMAL: int = 3   # 인재(실학자/무관) 출현, 관아 송사 판결, 암행어사 딜레마
const PRIORITY_LOW: int = 4      # 비변사 시보 발간, 풍속 제보 단신

static var instance: EventManager = null

# 구선복의 난 등 고유/역사 이벤트 중복 발생 원천 차단 딕셔너리
var _triggered_unique_events: Dictionary = {}
var is_gu_seon_bok_resolved: bool = false

var event_queue: Array[Dictionary] = []
var is_displaying_event: bool = false
var current_event: Dictionary = {}
var _pump_delay_timer: float = 0.0
const SERIALIZE_COOLDOWN_DELAY: float = 5.0 # 사용자 종료 후 5초 뒤 다음 이벤트 생성 직렬화

var input_mgr: Node = null
var sim_ref: Node = null
var court_ref: Node = null
var grid_ref: Node = null

# UI 컨트롤러
var _backdrop_dimmer: ColorRect
var _scholar_popup: Control
var _disaster_popup: Control
var _royal_tomb_popup: Control
var _crown_prince_popup: Control
var _generic_center: CenterContainer
var _generic_modal: PanelContainer
var _generic_title: Label
var _generic_desc: Label
var _generic_btn_box: HBoxContainer

func _init() -> void:
	instance = self
	layer = 95 # 최상위 모달 계층

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_ui()
	_sync_viewport_sizes()
	if is_inside_tree() and get_viewport():
		get_viewport().size_changed.connect(_sync_viewport_sizes)

func _sync_viewport_sizes() -> void:
	if not is_inside_tree() or get_viewport() == null:
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	if vp_size.x > 0.0 and vp_size.y > 0.0:
		if _backdrop_dimmer:
			_backdrop_dimmer.size = vp_size
		if _generic_center:
			_generic_center.size = vp_size
		if _scholar_popup and _scholar_popup.has_method("_sync_viewport_size"):
			_scholar_popup._sync_viewport_size()
		if _disaster_popup and _disaster_popup.has_method("_sync_viewport_size"):
			_disaster_popup._sync_viewport_size()
		if _royal_tomb_popup and _royal_tomb_popup.has_method("_sync_viewport_size"):
			_royal_tomb_popup._sync_viewport_size()
		if _crown_prince_popup and _crown_prince_popup.has_method("_sync_viewport_size"):
			_crown_prince_popup._sync_viewport_size()

func _ensure_ui() -> void:
	if _backdrop_dimmer == null:
		_build_ui()

func _process(delta: float) -> void:
	if is_displaying_event:
		return

	if _pump_delay_timer > 0.0:
		_pump_delay_timer -= delta
		if _pump_delay_timer > 0.0:
			return

	if event_queue.is_empty():
		return

	if can_show_next_event():
		_pump_next_event()

## UI 컴포넌트 생성 및 모달 차단막 구축
func _build_ui() -> void:
	# 1. 화면 전체 마우스 클릭 차단막 (Modal Input Barrier)
	_backdrop_dimmer = ColorRect.new()
	_backdrop_dimmer.name = "BackgroundDimmer"
	_backdrop_dimmer.color = Color(0.04, 0.03, 0.02, 0.65)
	_backdrop_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop_dimmer.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop_dimmer)
	_backdrop_dimmer.visible = false

	# 2. 전용 팝업 인스턴스 구축
	var scholar_script = load("res://scripts/ScholarDiscoveryPopup.gd")
	if scholar_script:
		_scholar_popup = scholar_script.new()
		_scholar_popup.name = "ScholarDiscoveryPopup"
		if not _scholar_popup.popup_closed.is_connected(on_event_resolved):
			_scholar_popup.popup_closed.connect(on_event_resolved)
		add_child(_scholar_popup)

	var disaster_script = load("res://scripts/DisasterPopup.gd")
	if disaster_script:
		_disaster_popup = disaster_script.new()
		_disaster_popup.name = "DisasterPopup"
		if not _disaster_popup.popup_closed.is_connected(on_event_resolved):
			_disaster_popup.popup_closed.connect(on_event_resolved)
		if _disaster_popup.has_signal("location_view_requested"):
			_disaster_popup.connect("location_view_requested", func(pos: Vector2):
				location_view_requested.emit(pos)
			)
		add_child(_disaster_popup)

	var royal_tomb_script = load("res://scripts/RoyalTombVisitPopup.gd")
	if royal_tomb_script:
		_royal_tomb_popup = royal_tomb_script.new()
		_royal_tomb_popup.name = "RoyalTombVisitPopup"
		if not _royal_tomb_popup.popup_closed.is_connected(on_event_resolved):
			_royal_tomb_popup.popup_closed.connect(on_event_resolved)
		add_child(_royal_tomb_popup)

	var crown_prince_script = load("res://scripts/CrownPrinceEventPopup.gd")
	if crown_prince_script:
		_crown_prince_popup = crown_prince_script.new()
		_crown_prince_popup.name = "CrownPrinceEventPopup"
		if not _crown_prince_popup.popup_closed.is_connected(on_event_resolved):
			_crown_prince_popup.popup_closed.connect(on_event_resolved)
		add_child(_crown_prince_popup)

	# 3. 범용 선택지 모달 (암행어사 딜레마, 송사 등)
	_build_generic_modal()

func _build_generic_modal() -> void:
	_generic_center = CenterContainer.new()
	_generic_center.name = "GenericModalCenter"
	_generic_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_generic_center)

	_generic_modal = PanelContainer.new()
	_generic_modal.name = "GenericEventModal"
	_generic_modal.custom_minimum_size = Vector2(580, 380)
	_generic_modal.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("fffdf6")
	sb.border_color = Color("5c3a21")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 14
	sb.set_content_margin_all(22)
	_generic_modal.add_theme_stylebox_override("panel", sb)
	_generic_center.add_child(_generic_modal)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_generic_modal.add_child(vbox)

	_generic_title = Label.new()
	_generic_title.text = "사건 알림"
	_generic_title.add_theme_font_size_override("font_size", 18)
	_generic_title.add_theme_color_override("font_color", Color("8f1d1d"))
	vbox.add_child(_generic_title)

	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	_generic_desc = Label.new()
	_generic_desc.text = "설명 내용..."
	_generic_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_generic_desc.add_theme_font_size_override("font_size", 13)
	_generic_desc.add_theme_color_override("font_color", Color("1c1917"))
	_generic_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_generic_desc)

	_generic_btn_box = HBoxContainer.new()
	_generic_btn_box.alignment = BoxContainer.ALIGNMENT_END
	_generic_btn_box.add_theme_constant_override("separation", 10)
	vbox.add_child(_generic_btn_box)

	_generic_center.visible = false
	_generic_modal.visible = false

func _on_backdrop_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		get_viewport().set_input_as_handled()

## 외부 시스템 및 매니저 참조 주입
func setup(p_sim: Node, p_court: Node, p_grid: Node, p_input: Node = null) -> void:
	sim_ref = p_sim
	court_ref = p_court
	grid_ref = p_grid
	input_mgr = p_input

## 고유 이벤트 1회성 검사 (One-Shot Flag)
func can_trigger_event(event_id: String) -> bool:
	if _triggered_unique_events.has(event_id):
		return false
	if event_id in ["gu_seon_bok_dilemma", "conspiracy_dilemma"]:
		if is_gu_seon_bok_resolved:
			return false
		if sim_ref != null and "conspiracy_cooldown_turns" in sim_ref:
			return sim_ref.conspiracy_cooldown_turns <= 0 and not sim_ref.is_conspiracy_decision_pending
		return true
	return true

func mark_event_triggered(event_id: String) -> void:
	_triggered_unique_events[event_id] = true
	if event_id in ["gu_seon_bok", "gu_seonbok_rebellion", "gu_seon_bok_dilemma"]:
		is_gu_seon_bok_resolved = true

func is_event_triggered(event_id: String) -> bool:
	if event_id in ["gu_seon_bok_dilemma", "conspiracy_dilemma"]:
		return false
	if event_id in ["gu_seon_bok", "gu_seonbok_rebellion"] and is_gu_seon_bok_resolved:
		return true
	return _triggered_unique_events.has(event_id)

## 우선순위 FIFO 큐 적재 (우선순위 오름차순, 동일 우선순위는 도착 순서 유지)
func enqueue_event(event_dict: Dictionary) -> void:
	if not event_dict.has("priority"):
		event_dict["priority"] = PRIORITY_NORMAL
	if not event_dict.has("id"):
		event_dict["id"] = "event_%d_%d" % [Time.get_ticks_msec(), randi() % 1000]

	var insert_idx: int = event_queue.size()
	var ev_prio: int = int(event_dict["priority"])

	for i: int in range(event_queue.size()):
		var q_prio: int = int(event_queue[i].get("priority", PRIORITY_NORMAL))
		if q_prio > ev_prio:
			insert_idx = i
			break

	event_queue.insert(insert_idx, event_dict)
	emit_signal("event_enqueued", event_dict)

## 긴급 재난 이벤트 적재 (PRIORITY_CRITICAL = 1)
func enqueue_disaster(title_text: String, msg: String, damage_data: Dictionary = {}, target_pos: Vector2 = Vector2.ZERO) -> void:
	enqueue_event({
		"id": "disaster_%d" % Time.get_ticks_msec(),
		"type": "disaster",
		"priority": PRIORITY_CRITICAL,
		"title": title_text,
		"message": msg,
		"damage": damage_data,
		"target_pos": target_pos
	})

## 현륭원 친림 참배 건의 적재 (PRIORITY_URGENT = 2)
func enqueue_royal_tomb(court: CourtSystem = null, sim: SimulationCore = null) -> void:
	if court != null:
		court_ref = court
	if sim != null:
		sim_ref = sim

	enqueue_event({
		"id": "royal_tomb_%d" % Time.get_ticks_msec(),
		"type": "tomb_visit",
		"priority": PRIORITY_URGENT,
		"title": "현륭원 친림 참배 건의"
	})

## 세자 제왕학 서연 보고 적재 (PRIORITY_URGENT = 2)
func enqueue_crown_prince(prince_data: Dictionary) -> void:
	enqueue_event({
		"id": "crown_prince_%d" % Time.get_ticks_msec(),
		"type": "crown_prince",
		"priority": PRIORITY_URGENT,
		"data": prince_data
	})

## 인재 천거 상소 적재 (PRIORITY_NORMAL = 3)
func enqueue_scholar(cand: Dictionary) -> void:
	enqueue_event({
		"id": "scholar_%s_%d" % [cand.get("id", "cand"), Time.get_ticks_msec()],
		"type": "scholar",
		"priority": PRIORITY_NORMAL,
		"candidate": cand
	})

## 비변사 시보 신문 발행 적재 (PRIORITY_LOW = 4)
func enqueue_gazette(issue_num: int, target_popup: Node = null) -> void:
	enqueue_event({
		"id": "gazette_%d_%d" % [issue_num, Time.get_ticks_msec()],
		"type": "sibo",
		"priority": PRIORITY_LOW,
		"issue_num": issue_num,
		"target_popup": target_popup
	})

## 암행어사 딜레마 및 선택형 정책 사건 적재 (PRIORITY_NORMAL = 3)
func enqueue_dilemma(ev_data: Dictionary) -> void:
	enqueue_event({
		"id": "dilemma_%d" % Time.get_ticks_msec(),
		"type": "dilemma",
		"priority": PRIORITY_NORMAL,
		"title": ev_data.get("title", "암행어사 서면 보고"),
		"desc": ev_data.get("desc", ""),
		"choices": ev_data.get("choices", [])
	})

## 현재 다음 이벤트를 화면에 띄울 수 있는지 검사
func can_show_next_event() -> bool:
	if is_displaying_event:
		return false
	if event_queue.is_empty():
		return false

	# 1. 입력 매니저 유휴 상태 질의
	if input_mgr != null and input_mgr.is_player_busy():
		return false

	# 2. 건설 모드 또는 드래그 중인지 질의 (오토로드 없는 테스트 환경 대비 null-safe)
	if is_inside_tree():
		var bm: Node = get_node_or_null("/root/BuildManager")
		if bm != null and "is_building_mode" in bm and bm.is_building_mode:
			return false

	return true

## 큐에서 다음 이벤트를 꺼내어 화면에 표시 (단 1개만 실행)
func _pump_next_event() -> void:
	if event_queue.is_empty():
		return

	is_displaying_event = true
	current_event = event_queue.pop_front()
	emit_signal("event_started", current_event)
	_display_current_event()

## 이벤트 딕셔너리 데이터에 맞는 팝업 활성화
## [규약: 가운데 흰색 추천 팝업 전면 폐기 - 오직 길잡이 김판관 단일 체제로 일원화]
func _display_current_event() -> void:
	_ensure_ui()
	_sync_viewport_sizes()

	var ev_type: String = str(current_event.get("type", "generic"))

	match ev_type:
		"disaster":
			if not GameSettings.is_disaster_popup_enabled():
				if _backdrop_dimmer:
					_backdrop_dimmer.visible = false
				on_event_resolved()
				return
			if _backdrop_dimmer:
				_backdrop_dimmer.visible = true
			if _disaster_popup:
				var _raw_tpos = current_event.get("target_pos", Vector2.ZERO)
				var tpos: Vector2 = _raw_tpos if _raw_tpos is Vector2 else Vector2.ZERO
				_disaster_popup.show_disaster(
					str(current_event.get("title", "재난 경보")),
					str(current_event.get("message", "")),
					current_event.get("damage", {}),
					tpos
				)

		"sibo":
			if _backdrop_dimmer:
				_backdrop_dimmer.visible = true
			var target_popup: Node = current_event.get("target_popup", null)
			if target_popup != null and target_popup.has_method("show_latest"):
				if not target_popup.is_connected("closed", on_event_resolved):
					target_popup.connect("closed", on_event_resolved, CONNECT_ONE_SHOT)
				target_popup.call("show_latest")
			else:
				# 팝업 참조가 없으면 즉시 해결
				on_event_resolved()

		"scholar", "tomb_visit", "crown_prince", "dilemma":
			# 가운데 흰색 추천/이벤트 팝업은 전면 비활성화 (김판관 시스템으로 일원화)
			# 배경 암전 해제 및 즉시 다음 대기열로 진행
			if _backdrop_dimmer:
				_backdrop_dimmer.visible = false
			on_event_resolved()

		_:
			# 커스텀 콜러블 지원 (모달 없는 논리 처리 콜러블)
			if current_event.has("callable") and current_event["callable"] is Callable:
				current_event["callable"].call(func(): on_event_resolved())
			else:
				on_event_resolved()

## 범용 선택지 모달 표시
func _show_generic_dilemma(ev: Dictionary) -> void:
	_sync_viewport_sizes()
	_generic_title.text = str(ev.get("title", "조정 어명 사건"))
	_generic_desc.text = str(ev.get("desc", ev.get("message", "")))

	for ch: Node in _generic_btn_box.get_children():
		ch.queue_free()

	var choices: Array = ev.get("choices", [])
	if choices.is_empty():
		var ok_btn: Button = Button.new()
		ok_btn.text = "확인"
		ok_btn.custom_minimum_size = Vector2(100, 36)
		ok_btn.pressed.connect(on_event_resolved)
		_generic_btn_box.add_child(ok_btn)
	else:
		for ch_data in choices:
			var btn: Button = Button.new()
			btn.text = str(ch_data.get("text", "선택"))
			btn.custom_minimum_size = Vector2(120, 36)
			var eff_callable = ch_data.get("effect", null)
			btn.pressed.connect(func():
				if eff_callable != null and eff_callable is Callable:
					eff_callable.call()
				on_event_resolved()
			)
			_generic_btn_box.add_child(btn)

	if _generic_center:
		_generic_center.visible = true
	if _generic_modal:
		_generic_modal.visible = true

## 현재 팝업이 닫혔을 때 호출되어 다음 이벤트로의 순차 전이를 개시
func on_event_resolved(_arg = null) -> void:
	if not is_displaying_event:
		return

	_hide_all_modals()
	var resolved_ev: Dictionary = current_event
	current_event = {}
	is_displaying_event = false
	emit_signal("event_resolved", resolved_ev)

	# 이전 팝업이 사용자에 의해 종료된 후 5초 여백 딜레이 적용 (과부하 방지 직렬화)
	_pump_delay_timer = SERIALIZE_COOLDOWN_DELAY

## 모든 모달 창 및 차단막 숨김
func _hide_all_modals() -> void:
	if _backdrop_dimmer:
		_backdrop_dimmer.visible = false
	if _scholar_popup:
		_scholar_popup.visible = false
	if _disaster_popup:
		_disaster_popup.visible = false
	if _royal_tomb_popup:
		_royal_tomb_popup.visible = false
	if _crown_prince_popup:
		_crown_prince_popup.visible = false
	if _generic_center:
		_generic_center.visible = false
	if _generic_modal:
		_generic_modal.visible = false

## 현재 모달 팝업이 활성화되어 입력을 차단하고 있는지 여부
static func has_active_modal() -> bool:
	return instance != null and instance.is_displaying_event

## 대기열에 쌓인 이벤트 수
static func get_queue_size() -> int:
	return instance.event_queue.size() if instance != null else 0

## 대기열 강제 초기화
func clear_queue() -> void:
	event_queue.clear()
	emit_signal("queue_cleared")
