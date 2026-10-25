extends Node
class_name ModernPoliticsManager

## 근대화 시대 정치체제 (1897~)
## - 1897년: 왕조 국가를 유지할지, 현대 정치체제(대통령제)로 바꿀지 고른다.
##   · 왕조 유지 → 1년 뒤 조선 혁명 엔딩.
##   · 현대 정치체제 → 화성행궁이 대통령궁·국회·법원이 된다. 민심 60 이상이면 대통령으로 계속 통치,
##     60 미만이면 '국민에게 자리를 양보하다' 엔딩.
## - 대통령제: 정무(조세·서학 진흥·외교·관공서 개편·문화재 보수 등)를 직접 할 수 없고,
##   석 달마다 국회·행정 각부가 올리는 건의를 승인/반려한다. 조정 인재(학문 능력 합)가 많을수록 건의 수준이 높다
##   (비용이 싸고, 부실 건의가 줄고, 부실 건의를 미리 짚어 준다). 건설 도구와 인재 등용은 그대로 직접 한다.
## - 5년마다 선거: 민심 60 이상이면 연임/퇴임을 고르고, 60 미만이면 퇴임 엔딩.
## - 계엄령: 다시 직접 통치(독재)하지만 1년 뒤 정치적 파멸 엔딩.

const DECISION_YEAR := 1897
const TERM_YEARS := 5
const ELECTION_LOYALTY := 60
const PROPOSAL_PERIOD := 3
const MAX_PENDING := 4
const PROPOSAL_EXPIRE_TURNS := 6
const WELFARE_COST := 15000

const SYS_MONARCHY := "monarchy"
const SYS_REPUBLIC := "republic"
const SYS_DICTATOR := "dictator"

static var instance: ModernPoliticsManager = null

var sim: SimulationCore
var time_manager: TimeManager
var court: CourtSystem

var system: String = SYS_MONARCHY
var decided: bool = false
var decided_year: int = 0
var next_election: int = 0
var term_count: int = 0
var martial_year: int = 0
var pending: Array = []   # 건의 목록 [{...}]
var _next_id: int = 1
var last_result: String = ""

func _init() -> void:
	name = "ModernPoliticsManager"

func setup(s: SimulationCore, t: TimeManager, c: CourtSystem) -> void:
	sim = s
	time_manager = t
	court = c
	ModernPoliticsManager.instance = self
	if not sim.turn_advanced.is_connected(_on_turn):
		sim.turn_advanced.connect(_on_turn)

## 왕조가 끝났는가(현대 정치체제 전환 뒤 — 대통령제·계엄 통치). 세자·왕실 정무가 사라진다.
static func is_post_monarchy() -> bool:
	return instance != null and ModernizationManager.is_active() and instance.system != SYS_MONARCHY

static func is_presidential() -> bool:
	return instance != null and ModernizationManager.is_active() and instance.system == SYS_REPUBLIC

func system_label() -> String:
	if not ModernizationManager.is_active():
		return ""
	match system:
		SYS_REPUBLIC: return "대통령제 (%d선, 다음 선거 %d년)" % [term_count, next_election]
		SYS_DICTATOR: return "계엄 통치 (%d년 선포)" % martial_year
	return "왕조 국가" + (" (혁명 임박)" if decided else "")

func _mm() -> ModernizationManager:
	return ModernizationManager.instance

func _year() -> int:
	return time_manager.current_year if time_manager else sim.current_year

# ==================== 연간 사건 (ModernizationManager._yearly_events에서 호출) ====================

func yearly(y: int) -> void:
	var mm := _mm()
	if not decided and y >= DECISION_YEAR:
		mm.queue_event(_open_decision)
	elif decided and system == SYS_MONARCHY and y >= decided_year + 1:
		mm.queue_event(func(): _ending_panel("조선 혁명", "왕조를 지키려 했으나, 새 시대를 바라는 백성들이 들고일어났습니다.", "JOSEON_REVOLUTION"))
	elif system == SYS_DICTATOR and y >= martial_year + 1:
		mm.queue_event(func(): _ending_panel("정치적 파멸", "계엄 통치 1년, 거리마다 독재 타도의 함성이 울립니다.", "POLITICAL_RUIN"))
	elif system == SYS_REPUBLIC and y >= next_election:
		mm.queue_event(_open_election)

func _ending_panel(title: String, body: String, key: String) -> void:
	_mm()._show_emergency_panel(title, body, Color("7f1d1d"), func(): _mm()._end_with(key))

func _open_decision() -> void:
	var mm := _mm()
	var tm := time_manager
	if tm:
		tm.set_speed(TimeManager.SpeedMode.PAUSE)
	var layer := CanvasLayer.new()
	layer.layer = 96
	add_child(layer)
	var body := "1897년, 세계는 왕정에서 공화정과 입헌 정치로 바뀌어 가고 있습니다.\n오백 년 왕조를 이어 갈 것인가, 백성이 주인이 되는 현대 정치체제로 나아갈 것인가?\n\n· 현대 정치체제: 화성행궁이 대통령궁·국회·법원이 됩니다. 민심이 %d 이상이면 초대 대통령으로 통치를 이어 가고, 낮으면 자리에서 물러납니다. 대통령은 정무를 직접 하지 못하고 국회·행정 각부의 건의를 승인/반려합니다.\n· 왕조 유지: 지금처럼 직접 다스리지만, 새 시대를 바라는 백성의 뜻을 거스르게 됩니다.\n\n현재 민심: %d" % [ELECTION_LOYALTY, sim.loyalty]
	var panel := ModernizationManager._make_panel(layer, "⚖️ 1897 — 나라의 앞날", body, Color("b8860b"))
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	panel.get_meta("vbox").add_child(hb)
	var b_rep := Button.new()
	b_rep.text = "현대 정치체제로 전환"
	b_rep.custom_minimum_size = Vector2(180, 36)
	hb.add_child(b_rep)
	var b_mon := Button.new()
	b_mon.text = "왕조 국가 유지"
	b_mon.custom_minimum_size = Vector2(160, 36)
	hb.add_child(b_mon)
	b_rep.pressed.connect(func():
		layer.queue_free()
		decided = true
		decided_year = _year()
		if UrbanEvolutionManager.instance:
			UrbanEvolutionManager.instance.haenggung_republic = true
			UrbanEvolutionManager.instance.apply_landmark_tiles()
		if sim.loyalty >= ELECTION_LOYALTY:
			system = SYS_REPUBLIC
			term_count = 1
			next_election = decided_year + TERM_YEARS
			mm._refresh_panels()
			mm._show_emergency_panel("초대 대통령 취임", "화성행궁이 대통령궁·국회·법원으로 새로 태어났습니다.\n백성들의 지지(민심 %d)로 초대 대통령에 올랐습니다.\n\n이제 정무는 국회·행정 각부의 건의를 승인하거나 반려하여 이끕니다. 다음 선거는 %d년입니다." % [sim.loyalty, next_election], Color("15803d"), mm.after_event)
		else:
			_ending_panel("국민에게 자리를 양보하다", "현대 정치체제는 열렸지만, 백성들의 지지(민심 %d)를 얻지 못했습니다." % sim.loyalty, "YIELD_TO_PEOPLE")
	)
	b_mon.pressed.connect(func():
		layer.queue_free()
		decided = true
		decided_year = _year()
		system = SYS_MONARCHY
		mm._show_emergency_panel("왕조 유지", "오백 년 왕조를 이어 가기로 했습니다.\n그러나 저잣거리와 학교마다 새 시대를 바라는 목소리가 커지고 있습니다...", Color("b45309"), mm.after_event)
	)

func _open_election() -> void:
	var mm := _mm()
	if sim.loyalty < ELECTION_LOYALTY:
		_ending_panel("대통령 선거 — 낙선", "임기 %d년이 끝났습니다. 민심 %d — 국민은 새로운 지도자를 골랐습니다." % [TERM_YEARS, sim.loyalty], "YIELD_TO_PEOPLE")
		return
	if time_manager:
		time_manager.set_speed(TimeManager.SpeedMode.PAUSE)
	var layer := CanvasLayer.new()
	layer.layer = 96
	add_child(layer)
	var panel := ModernizationManager._make_panel(layer, "🗳️ 대통령 선거", "임기 %d년이 끝났습니다. 민심 %d로 국민이 다시 지지를 보냅니다.\n연임하여 통치를 이어 가시겠습니까, 아니면 국민에게 자리를 넘기시겠습니까?" % [TERM_YEARS, sim.loyalty], Color("1d4ed8"))
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)
	panel.get_meta("vbox").add_child(hb)
	var b_go := Button.new()
	b_go.text = "연임"
	b_go.custom_minimum_size = Vector2(140, 36)
	hb.add_child(b_go)
	var b_stop := Button.new()
	b_stop.text = "물러나기 (엔딩)"
	b_stop.custom_minimum_size = Vector2(160, 36)
	hb.add_child(b_stop)
	b_go.pressed.connect(func():
		layer.queue_free()
		term_count += 1
		next_election = _year() + TERM_YEARS
		mm._show_emergency_panel("연임", "%d선 대통령이 되었습니다. 다음 선거는 %d년입니다." % [term_count, next_election], Color("15803d"), mm.after_event)
	)
	b_stop.pressed.connect(func():
		layer.queue_free()
		mm._end_with("YIELD_TO_PEOPLE")
	)

## 계엄령: 직접 통치로 돌아가지만 1년 뒤 정치적 파멸
func declare_martial_law() -> void:
	if system != SYS_REPUBLIC:
		return
	system = SYS_DICTATOR
	martial_year = _year()
	pending.clear()
	sim.loyalty = maxi(0, sim.loyalty - 20)
	_mm()._refresh_panels()
	_mm().emit_signal("notice", "계엄령을 선포했습니다! 국회가 해산되고 다시 직접 통치합니다. 그러나 민심이 크게 흔들립니다. (민심 -20)", "🪖")

# ==================== 국정 건의 ====================

## 건의 수준(0~1): 등용한 인재들의 학문 능력 합 / 40
func staff_quality() -> float:
	var total := 0
	for id in CourtSystem.SCHOLARS:
		var sc: Dictionary = CourtSystem.SCHOLARS[id]
		if sim.retainers.get(sc["key"], false):
			total += int(sc["acad"])
	return clampf(float(total) / 40.0, 0.0, 1.0)

func quality_label() -> String:
	var q := staff_quality()
	return "상" if q >= 0.66 else ("중" if q >= 0.33 else "하")

func _on_turn(turn: int, _season: int, _year_i: int) -> void:
	if not is_presidential():
		return
	var cur := turn
	pending = pending.filter(func(p): return cur - int(p["turn"]) < PROPOSAL_EXPIRE_TURNS)
	if turn % PROPOSAL_PERIOD == 0:
		var n := 1 + (1 if randf() < 0.5 else 0)
		for i in range(n):
			if pending.size() >= MAX_PENDING:
				break
			var p := _make_proposal()
			if not p.is_empty():
				pending.append(p)
		if not pending.is_empty():
			_mm().emit_signal("notice", "국회·행정 각부의 건의가 올라왔습니다. [정무 → 📜 국정 건의]에서 승인하거나 반려하십시오.", "📜")

## 지금 할 수 있는 일 중에서 하나를 골라 건의로 만든다
func _make_proposal() -> Dictionary:
	var mm := _mm()
	var um: UrbanEvolutionManager = UrbanEvolutionManager.instance
	var opts: Array = []
	var unified: int = sim.tax_rate_land + sim.tax_rate_market + sim.tax_rate_military
	if unified > 9:
		opts.append({"kind": "tax_down", "source": "국회", "title": "통합세 인하 (%d%% → %d%%)" % [unified, unified - 3], "base": 0})
	if unified < 57:
		opts.append({"kind": "tax_up", "source": "재무부", "title": "통합세 인상 (%d%% → %d%%)" % [unified, unified + 3], "base": 0})
	if mm.current_field == "":
		for f in ModernizationManager.FIELDS + (ModernizationManager.MEDICAL_FIELDS if mm.medical_unlocked() else []):
			if not mm.field_done(f["id"]):
				opts.append({"kind": "research", "source": "학부", "title": "근대 과학 연구 착수: %s" % f["name"], "base": 0, "arg": f["id"]})
				break
	if mm.books_bought < ModernizationManager.MAX_BOOKS:
		opts.append({"kind": "books", "source": "학부", "title": "서양 서적 구입", "base": ModernizationManager.BOOK_COST})
	if mm.diplomacy_unlocked and mm.diplomacy_turns_left() == 0:
		opts.append({"kind": "summit", "source": "외부", "title": "국제외교 회담 개최", "base": 0})
		for nid in ModernDiplomacyData.NATIONS:
			if bool(mm.can_negotiate_alliance(nid)["ok"]):
				opts.append({"kind": "alliance", "source": "외부", "title": "%s과(와) 동맹 협상" % ModernDiplomacyData.nation_name(nid), "base": 0, "arg": nid})
				break
	if um != null and um.heritage_condition < 90.0:
		opts.append({"kind": "heritage", "source": "문화재청", "title": "화성 문화재 보수 (보존도 +%d)" % int(UrbanEvolutionManager.HERITAGE_RESTORE_STEP), "base": UrbanEvolutionManager.HERITAGE_RESTORE_COST})
	if um != null and um.upgrades_unlocked():
		for cid in UrbanEvolutionManager.CIVIC_UPGRADES:
			if not um.is_civic_upgraded(cid) and um.grid.count_completed(cid) > 0:
				var info: Dictionary = UrbanEvolutionManager.CIVIC_UPGRADES[cid]
				opts.append({"kind": "civic", "source": "내부", "title": "%s → %s 개편" % [info["old"], info["name"]], "base": int(info["cost"]), "arg": cid})
				break
		for lid in UrbanEvolutionManager.LAKE_PARKS:
			if not um.is_lake_park(lid) and um.grid.count_completed(lid) > 0:
				opts.append({"kind": "lake", "source": "내부", "title": "%s 조성" % UrbanEvolutionManager.LAKE_PARKS[lid]["name"], "base": UrbanEvolutionManager.LAKE_PARK_COST, "arg": lid})
				break
		if not um.water_project_started:
			opts.append({"kind": "water_project", "source": "내부", "title": "수도 연결 대공사 착공 (매달 %d냥 x %d달)" % [UrbanEvolutionManager.WATER_PROJECT_COST_PER_TURN, UrbanEvolutionManager.WATER_PROJECT_TURNS], "base": 0})
		if not um.wells_upgraded and um.grid.count_completed("well") > 0:
			opts.append({"kind": "wells", "source": "내부", "title": "우물 → 집수정 개편", "base": UrbanEvolutionManager.WELL_UPGRADE_COST})
		if not um.reservoirs_upgraded and um.grid.count_completed("reservoir") > 0:
			opts.append({"kind": "reservoirs", "source": "내부", "title": "저수지 → 생활용수 공급시설 개편", "base": UrbanEvolutionManager.RESERVOIR_UPGRADE_COST})
		for pk in UrbanEvolutionManager.PLAZA_UPGRADES:
			if not um.is_plaza_upgraded(pk) and not um.grid.list_plazas(pk).is_empty():
				var pinfo: Dictionary = UrbanEvolutionManager.PLAZA_UPGRADES[pk]
				opts.append({"kind": "plaza", "source": "내부", "title": "%s → %s 개편" % [pinfo["old"], pinfo["name"]], "base": int(pinfo["cost"]), "arg": pk})
				break
		if not um.military_base and um.grid.count_completed("yeonmudae") > 0:
			opts.append({"kind": "base", "source": "군부", "title": UrbanEvolutionManager.MILITARY_BASE_NAME + " 개편", "base": UrbanEvolutionManager.MILITARY_BASE_COST})
	opts.append({"kind": "welfare", "source": "국회", "title": "민생 복지 예산 편성 (민심 +5)", "base": WELFARE_COST})
	var p: Dictionary = opts[randi() % opts.size()]
	var q := staff_quality()
	p["id"] = _next_id
	_next_id += 1
	p["turn"] = sim.turn
	p["cost"] = int(round(float(p["base"]) * (1.3 - 0.5 * q))) # 인재가 뛰어날수록 비용이 싸다
	p["flawed"] = randf() < 0.5 * (1.0 - q)                     # 부실 건의: 효과가 줄고 민심이 깎인다
	p["flag"] = bool(p["flawed"]) and q >= 0.5                  # 뛰어난 인재는 부실을 미리 짚어 준다
	return p

func _charge(p: Dictionary) -> bool:
	if sim.gold < int(p["cost"]):
		last_result = "국고가 부족해 [%s]을(를) 집행하지 못했습니다. (%d냥 필요)" % [p["title"], int(p["cost"])]
		return false
	return true

## 승인: 건의를 집행한다. 개편·보수 함수는 기본 비용을 내므로 차액만 더하거나 돌려준다.
func approve(id: int) -> void:
	var p: Dictionary = _find(id)
	if p.is_empty() or not _charge(p):
		return
	var mm := _mm()
	var um: UrbanEvolutionManager = UrbanEvolutionManager.instance
	var ok := true
	var diff: int = int(p["cost"]) - int(p["base"])
	var kind := String(p["kind"])
	var uses_base := kind in ["books", "heritage", "civic", "lake", "base", "plaza", "wells", "reservoirs"]
	if uses_base:
		sim.gold -= diff # 인재 수준에 따른 차액을 먼저 정산(기본 비용은 각 함수가 낸다)
	match kind:
		"tax_down", "tax_up":
			var u: int = sim.tax_rate_land + sim.tax_rate_market + sim.tax_rate_military + (3 if p["kind"] == "tax_up" else -3)
			u = clampi(u, 3, 60)
			@warning_ignore("integer_division")
			sim.tax_rate_land = u / 3
			@warning_ignore("integer_division")
			sim.tax_rate_market = u / 3
			@warning_ignore("integer_division")
			sim.tax_rate_military = u / 3
		"research":
			ok = mm.start_field(String(p["arg"]))
		"books":
			ok = mm.buy_books()
		"summit":
			var r := mm.hold_summit()
			ok = not r.is_empty()
			if ok:
				mm.last_result = ("🤝 회담 성공! " if r["ok"] else "✖ ") + String(r["msg"])
		"alliance":
			mm.negotiate_alliance(String(p["arg"]), func(): pass)
		"heritage":
			ok = um.restore_heritage()
		"civic":
			ok = um.build_civic_upgrade(String(p["arg"]))
		"lake":
			ok = um.build_lake_park(String(p["arg"]))
		"base":
			ok = um.build_military_base()
		"plaza":
			ok = um.build_plaza_upgrade(String(p["arg"]))
		"water_project":
			ok = um.start_water_project()
		"wells":
			ok = um.upgrade_wells()
		"reservoirs":
			ok = um.upgrade_reservoirs()
		"welfare":
			sim.gold -= int(p["cost"])
			sim.loyalty = mini(100, sim.loyalty + (2 if p["flawed"] else 5))
	if uses_base and not ok:
		sim.gold += diff
	pending.erase(p)
	if not ok:
		last_result = "[%s]은(는) 지금 집행할 수 없어 폐기되었습니다." % p["title"]
		return
	if bool(p["flawed"]):
		sim.loyalty = maxi(0, sim.loyalty - 2)
		last_result = "✔ [%s] 승인 — 그러나 졸속으로 추진되어 잡음이 일었습니다. (민심 -2)" % p["title"]
	else:
		last_result = "✔ [%s] 승인·집행했습니다." % p["title"]

func reject(id: int) -> void:
	var p: Dictionary = _find(id)
	if p.is_empty():
		return
	pending.erase(p)
	if String(p["source"]) == "국회" and not bool(p["flawed"]):
		sim.loyalty = maxi(0, sim.loyalty - 1)
		last_result = "✖ 국회의 [%s] 건의를 반려했습니다. 국회와 갈등이 생겼습니다. (민심 -1)" % p["title"]
	else:
		last_result = "✖ [%s] 건의를 반려했습니다." % p["title"]

func _find(id: int) -> Dictionary:
	for p in pending:
		if int(p["id"]) == id:
			return p
	return {}

# ==================== 저장 ====================

func serialize() -> Dictionary:
	return {
		"system": system, "decided": decided, "decided_year": decided_year,
		"next_election": next_election, "term_count": term_count, "martial_year": martial_year,
		"pending": pending.duplicate(true), "next_id": _next_id,
	}

func deserialize(d: Dictionary) -> void:
	system = String(d.get("system", SYS_MONARCHY))
	decided = bool(d.get("decided", false))
	decided_year = int(d.get("decided_year", 0))
	next_election = int(d.get("next_election", 0))
	term_count = int(d.get("term_count", 0))
	martial_year = int(d.get("martial_year", 0))
	pending = (d.get("pending", []) as Array).duplicate(true) if d.get("pending", []) is Array else []
	_next_id = int(d.get("next_id", 1))
	last_result = ""
	for ch in get_children():
		if ch is CanvasLayer:
			ch.queue_free()
	if ModernizationManager.instance:
		ModernizationManager.instance._refresh_panels() # 불러온 정치체제에 맞게 정무 버튼(국정 건의·세자서연) 다시
