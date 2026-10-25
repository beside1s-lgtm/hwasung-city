extends RefCounted
class_name SaveSystem

## [조선 화성성역 실록 세이브/로드/삭제 시스템]
## user://saves/ 디렉토리에 각 슬롯별 치세 데이터를 JSON 포맷으로 저장, 로드, 삭제합니다.

const SAVE_DIR := "user://saves/"
const SLOTS: Array[int] = [1, 2, 3, 0]

## 로드 중 불필요한 시그널 및 엔딩 조기 트리거 방지 플래그
static var is_loading: bool = false

static func get_slot_title_prefix(slot_id: int) -> String:
	match slot_id:
		0: return "자동 저장 실록"
		_: return "실록 제%d권" % slot_id

## 자동 저장은 내부 번호가 0이지만 "제0권"이라 부르면 헷갈리므로 이름으로 부른다
static func get_slot_display_name(slot_id: int) -> String:
	match slot_id:
		0: return "자동 저장"
		_: return "제%d권" % slot_id

static func get_formatted_title(slot_id: int, save_info: Dictionary) -> String:
	var prefix := get_slot_title_prefix(slot_id)
	if save_info.is_empty():
		return "%s: 【비어 있는 기록 칸】" % prefix
	var raw_title := str(save_info.get("title", ""))
	if raw_title != "":
		if slot_id == 0 and raw_title.begins_with("실록 제0권"):
			# 예전 저장 파일 제목("실록 제0권 (자동 저장): …")도 새 이름으로 보여 준다
			return "자동 저장 실록" + raw_title.substr(raw_title.find(":"))
		return raw_title
	var y: int = int(save_info.get("year", 1789))
	var s_name: String = str(save_info.get("season", "봄"))
	return "%s: %d년 %s - %s" % [prefix, y, s_name, TimeManager.era_name(y)] # 1800년 엔딩 뒤는 순조 이후 연호

static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

static func get_slot_file_name(slot_id: int) -> String:
	match slot_id:
		0: return "autosave.json"
		1: return "slot_1.json"
		2: return "slot_2.json"
		3: return "slot_3.json"
		_: return "slot_%d.json" % slot_id

static func get_slot_path(slot_id: int) -> String:
	return SAVE_DIR + get_slot_file_name(slot_id)

## 해당 슬롯에 유효한 세이브 파일이 존재하는지 확인 (실제 월드 타일 데이터 포함 여부 검증)
static func has_save(slot_id: int) -> bool:
	_ensure_dir()
	var path := get_slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return false
	var info: Dictionary = get_save_info(slot_id)
	return not info.is_empty() and info.has("tiles")

## 세이브 파일 메타 요약 정보 읽기
static func get_save_info(slot_id: int) -> Dictionary:
	_ensure_dir()
	var path := get_slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return {}

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}

	var text := f.get_as_text()
	f.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		return {}

	var data: Dictionary = json.data as Dictionary
	return data

## 세이브 데이터 파일 실제 삭제
static func delete_save(slot_id: int) -> bool:
	_ensure_dir()
	var path := get_slot_path(slot_id)
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(path)
		return err == OK
	return false

## PORT-TRACE [저장 보강]: 예전엔 칸마다 건물 이름·구획·길 종류 등만 저장해, 불러오면 서장대 2x2·봉돈·공심돈·연무대·포루·행궁 7x7 같은
## 다칸 시설의 묶음 정보(site_anchor·site_tiles·sj2·bd4·gs3·ym5·pr2 …)와 성벽 위 표시, 민가·가게 모양, 놀이마당(plaza) 등이 사라졌다.
## 이 키들을 칸마다 "ext"로 함께 저장한다(JSON은 Vector2i를 못 담으므로 표시를 붙여 바꾼다).
const TILE_EXT_KEYS: Array[String] = [
	"sj2", "sj_wall", "bh_wall", "bd4", "gs3", "ym5", "ym_rng", "ym_range", "pr2", "site_anchor", "site_tiles",
	"wall_build", "wall_build_total", "bp_ticks", "bp_total", "is_hwahong", "is_namsu", "zone_build",
	"house_variant", "variant", "prosper", "trade", "trade_cat", "plaza", "hgroup",
	"gw_kind", "gw_prisoners", "gw_trial", "gw_trial_len", "irrigated", "is_manned", "staff_count",
]

static func _encode_tile_ext(t: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: String in TILE_EXT_KEYS:
		if t.has(k):
			out[k] = _enc(t[k])
	if str(t.get("building", "")) == "yongyeon":
		out["terrain"] = _enc(t.get("terrain", "outside")) # 용연은 인공 연못(물)로 바뀐 칸
	return out

static func _decode_tile_ext(cell: Dictionary, ext: Variant) -> void:
	if not (ext is Dictionary):
		return
	for k: String in (ext as Dictionary).keys():
		cell[k] = _dec((ext as Dictionary)[k])

static func _enc(v: Variant) -> Variant:
	if v is Vector2i:
		return {"_v2i": [(v as Vector2i).x, (v as Vector2i).y]}
	if v is Vector2:
		return {"_v2": [(v as Vector2).x, (v as Vector2).y]}
	if v is Array:
		var a: Array = []
		for e in (v as Array):
			a.append(_enc(e))
		return a
	if v is Dictionary:
		var d: Dictionary = {}
		for key in (v as Dictionary).keys():
			d[str(key)] = _enc((v as Dictionary)[key])
		return d
	return v

static func _dec(v: Variant) -> Variant:
	if v is Dictionary:
		var d: Dictionary = v
		if d.has("_v2i") and d.size() == 1:
			var p: Array = d["_v2i"]
			return Vector2i(int(p[0]), int(p[1]))
		if d.has("_v2") and d.size() == 1:
			var q: Array = d["_v2"]
			return Vector2(float(q[0]), float(q[1]))
		var o: Dictionary = {}
		for key in d.keys():
			o[key] = _dec(d[key])
		return o
	if v is Array:
		var a: Array = []
		for e in (v as Array):
			a.append(_dec(e))
		return a
	if v is float and is_equal_approx(v, roundf(v)) and absf(v) < 1.0e9:
		return int(v) # JSON은 정수도 실수로 읽는다 — 정수로 돌려 놓는다
	return v

## PORT-TRACE [저장 당시 그대로]: 불러오면 세율(탕평 조세)·세자 책봉/교육 단계·조정 상태(연구·호랑이·을묘원행 등)·
## 김판관이 이미 아뢴 조언 기록이 처음 값으로 돌아갔다(저장하지 않은 변수들). 항목을 하나씩 빠뜨리지 않도록 핵심 객체의
## 스크립트 변수(숫자·글·참거짓·목록·사전·좌표)를 통째로 담아 두고 불러올 때 그대로 되돌린다. 다른 객체를 가리키는 변수는 제외.
## 진행 중 연출(행차·화재·도적 침입 중 등)은 불러온 직후 멈춘 채 남지 않게 뺀다.
const SNAP_SKIP := {
	"sim": ["is_eulmyo_active", "is_time_frozen", "is_conspiracy_decision_pending", "fire_active", "bandit_active", "is_wartime_mobilized", "grid_ref", "last_maintenance_result"],
	"court": ["hired_scholars", "sim"],
}
const SNAP_ONLY := {
	"guide": ["_advice_seen", "_reported_unique_buildings", "_dismissed_affairs", "_pop_cap_seen_turn"],
	"time": ["current_year", "current_month", "current_day", "total_ticks", "last_season"],
}

static func _jsonable(v: Variant, depth: int = 0) -> bool:
	if depth > 8:
		return false
	match typeof(v):
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_NIL:
			return true
		TYPE_ARRAY:
			for e in (v as Array):
				if not _jsonable(e, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			for k in (v as Dictionary).keys():
				if not _jsonable((v as Dictionary)[k], depth + 1):
					return false
			return true
	return false

static func _snap_obj(o: Object, tag: String) -> Dictionary:
	var out := {}
	if o == null:
		return out
	var skip: Array = SNAP_SKIP.get(tag, [])
	var only: Array = SNAP_ONLY.get(tag, [])
	for pr: Dictionary in o.get_property_list():
		if (int(pr["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var nm := String(pr["name"])
		if nm in skip or (not only.is_empty() and not (nm in only)):
			continue
		var v: Variant = o.get(nm)
		if v is Object or not _jsonable(v):
			continue
		out[nm] = _enc(v)
	return out

static func _restore_obj(o: Object, d: Variant, tag: String) -> void:
	if o == null or not (d is Dictionary):
		return
	var skip: Array = SNAP_SKIP.get(tag, [])
	var names := {}
	for pr: Dictionary in o.get_property_list():
		if (int(pr["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			names[String(pr["name"])] = true
	for k in (d as Dictionary).keys():
		var nm := String(k)
		if nm in skip or not names.has(nm):
			continue
		var cur: Variant = o.get(nm)
		if cur is Object:
			continue
		var val: Variant = _dec((d as Dictionary)[k])
		match typeof(cur):
			TYPE_INT:
				if val is float or val is int or val is bool:
					o.set(nm, int(val))
			TYPE_FLOAT:
				if val is float or val is int:
					o.set(nm, float(val))
			TYPE_BOOL:
				o.set(nm, bool(val))
			TYPE_STRING:
				o.set(nm, str(val))
			TYPE_ARRAY:
				if val is Array:
					(cur as Array).assign(val) # 형 지정 배열도 원소를 맞춰 채운다
			TYPE_DICTIONARY:
				if val is Dictionary:
					var cd: Dictionary = cur
					if cd.is_typed():
						cd.clear()
						for kk in (val as Dictionary).keys():
							cd[kk] = (val as Dictionary)[kk]
					else:
						o.set(nm, val)
			_:
				if typeof(val) == typeof(cur) or cur == null:
					o.set(nm, val)

## 주 장면(Main) — 조정(court)·김판관 안내(tutorial)를 찾는다
static func _main_node() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	if tree.current_scene != null and "court" in tree.current_scene:
		return tree.current_scene
	for c in tree.root.get_children():
		if "court" in c and "tutorial" in c:
			return c
	return null

static func _build_snap(sim: SimulationCore, time_mgr: Object = null) -> Dictionary:
	var m := _main_node()
	var snap := {}
	if sim:
		snap["sim"] = _snap_obj(sim, "sim")
		snap["pop"] = _snap_obj(sim.pop_manager, "pop")
		snap["cpm"] = _snap_obj(sim.crown_prince_manager, "cpm")
	if m != null:
		snap["court"] = _snap_obj(m.get("court"), "court")
		snap["guide"] = _snap_obj(m.get("tutorial"), "guide")
		if time_mgr == null:
			time_mgr = m.get("time_manager")
	if time_mgr != null:
		snap["time"] = _snap_obj(time_mgr, "time")
	return snap

## 세자 교육도: 실제 진행 값(세자 교육 관리자)과 조정·통계 값 중 큰 것(예전엔 갱신 안 된 통계 값만 저장돼 0으로 남았다)
static func _prince_score(sim: SimulationCore) -> float:
	var v: float = float(CityStats.get_crown_prince_education())
	if sim and sim.crown_prince_manager:
		v = maxf(v, sim.crown_prince_manager.progress)
	var m := _main_node()
	if m != null and m.get("court") != null and "crown_prince" in m.get("court"):
		v = maxf(v, float((m.get("court").crown_prince as Dictionary).get("education", 0)))
	return v

## 현재 치세 상태를 슬롯에 저장
static var _path_override: String = ""

## 슬롯이 아닌 지정 경로로 저장 (1800년 클리어 보관본 등)
static func save_game_to_path(path: String, sim: SimulationCore, _grid: GameGrid = null) -> bool:
	_path_override = path
	var ok := save_game(0, sim, _grid)
	_path_override = ""
	return ok

## 지정 경로 저장본 불러오기 (근대화 세이브 테스트 등)
static func load_game_from_path(path: String, sim: SimulationCore, _grid: GameGrid = null, time_mgr: TimeManager = null, _quest_sys: Node = null) -> bool:
	_path_override = path
	var ok := load_game(0, sim, _grid, time_mgr, _quest_sys)
	_path_override = ""
	return ok

static func save_game(slot_id: int, sim: SimulationCore, _grid: GameGrid = null, _quest_sys: Node = null) -> bool:
	_ensure_dir()
	var path := _path_override if _path_override != "" else get_slot_path(slot_id)

	var s_names: Array[String] = ["봄", "여름", "가을", "겨울"]
	var s_name: String = s_names[sim.season_now()] if sim else "봄"
	var y: int = sim.current_year if sim else 1789

	var tiles_data: Array = []
	if _grid and _grid.grid.size() > 0:
		for ty in range(_grid.size):
			for tx in range(_grid.size):
				var t: Dictionary = _grid.grid[ty][tx]
				var b: String = t.get("building", "")
				var z: String = t.get("zone", "")
				var sf: String = t.get("surface", "normal")
				var uc: bool = t.get("under_construction", false)
				if b != "" or z != "" or sf != "normal" or uc:
					var ext: Dictionary = _encode_tile_ext(t)
					tiles_data.append({
						"x": tx, "y": ty,
						"b": b, "z": z, "sf": sf, "uc": uc,
						"rt": t.get("road_type", "dirt"),
						"lvl": t.get("level", 0),
						"bst": t.get("build_stage", 2),
						"gn": t.get("gate_name", ""),
						"cj": t.get("cheonju", false),
						"fid": t.get("facility_id", ""),
						"sbid": t.get("special_building_id", ""),
						"is_spec": t.get("is_special_building", false),
						"bt": int(t.get("building_type", 0)),
						"ir": bool(t.get("is_ruined", false)),
						"ext": ext
					})

	var data := {
		"slot": slot_id,
		"title": "%s: %d년 %s - %s" % [get_slot_title_prefix(slot_id), y, s_name, TimeManager.era_name(y)],
		"year": y,
		"season": s_name,
		"turn": sim.turn if sim else 1,
		"pop": sim.population if sim else 120,
		"total_population": sim.population if sim else 120,
		"tax_policy": int(sim.get_tax_policy()) if sim else 1,
		"haenggung_completed": sim.pop_manager.haenggung_completed if (sim and sim.pop_manager) else false,
		"haenggung_boost_applied": sim.pop_manager.haenggung_boost_applied if (sim and sim.pop_manager) else false,
		"ruined_houses": (sim.pop_manager.serialize().get("ruined_houses", []) as Array) if (sim and sim.pop_manager) else [],
		"active_houses": (sim.pop_manager.serialize().get("active_houses", []) as Array) if (sim and sim.pop_manager) else [],
		"gold": sim.gold if sim else 2500,
		"rice": sim.rice if sim else 1600,
		"loyalty": sim.loyalty if sim else 88,
		"authority": sim.authority if sim else 70,
		"royal_power": CityStats.get_royal_power(),
		"fortress": sim.fortress_progress if sim else 0,
		"flood_defense": sim.flood_defense if sim else 0,
		"flood_crisis_active": sim.flood_crisis_active if sim else false,
		"flood_crisis_turns_left": sim.flood_crisis_turns_left if sim else 0,
		"drought_active": sim.drought_active if sim else false,
		"plague_active": sim.plague_active if sim else false,
		"military": sim.military_power if sim else 70,
		"defense_power": sim.defense_power if sim else 1000,
		"defense_fatigue": sim.defense_fatigue if sim else 0,
		"repair_state": sim.repair_state.duplicate() if sim else {},
		"troop_roster": sim.troop_roster.duplicate() if sim else {},
		"academic": sim.academic if sim else 0,
		"academic_power": CityStats.get_academic_power(),
		"crown_prince_education": _prince_score(sim),
		"prince_edu_progress": _prince_score(sim),
		"current_researching": sim.tech_tree.current_researching if (sim and sim.tech_tree) else "",
		"research_status": int(sim.tech_tree.research_status) if (sim and sim.tech_tree) else 0,
		"prince_studying": bool(sim.tech_tree.prince_studying) if (sim and sim.tech_tree) else false,
		"tech_progress_dict": sim.tech_tree.tech_progress_dict.duplicate() if (sim and sim.tech_tree) else {},
		"tech_completed_dict": sim.tech_tree.tech_completed_dict.duplicate() if (sim and sim.tech_tree) else {},
		"hyeonryungwon_visits": CityStats.get_hyeonryungwon_visits(),
		"faction_balance_score": CityStats.get_faction_balance_score(),
		"fortress_defense_power": CityStats.get_fortress_defense_power(),
		"fortress_max_defense_power": CityStats.get_max_defense_power(),
		"defense_repair_bonus": CityStats.get_defense_repair_bonus(),
		"defense_damage_taken": CityStats.get_defense_damage_taken(),
		"military_attack_power": CityStats.get_military_attack_power(),
		"seojangdae_drill_bonus": CityStats.get_seojangdae_drill_bonus(),
		"seojangdae_drill_cd_months": sim.seojangdae_drill_cd_months if sim else 0,
		"boyuron": sim.boyuron if sim else false,
		"segi_policy": sim.segi_policy if sim else false,
		"jangyong_review_year": sim.jangyong_review_year if sim else 0,
		"retainers": sim.retainers.duplicate() if sim else {},
		"refugees": sim.refugees if sim else 0,
		"rebel_cd": sim.rebel_cd if sim else 0,
		"horde_cd": sim.horde_cd if sim else 0,
		"famine_active": sim.famine_active if sim else false,
		"demand_res": sim.demand_res if sim else 50,
		"demand_com": sim.demand_com if sim else 30,
		"demand_agr": sim.demand_agr if sim else 40,
		"mega_projects": sim.mega_projects.duplicate(true) if sim else [],
		"gates": _grid.gates.duplicate(true) if (_grid and "gates" in _grid) else {},
		"trial_data": sim.trial_manager.serialize() if (sim and "trial_manager" in sim and sim.trial_manager) else {},
		"bandit_data": sim.bandit_manager.serialize() if (sim and "bandit_manager" in sim and sim.bandit_manager) else {},
		"uigwe_data": sim.uigwe_manager.serialize() if (sim and "uigwe_manager" in sim and sim.uigwe_manager) else {},
		"academy_quiz_data": AcademyQuizManager.get_instance().serialize(),
		"modernization_data": ModernizationManager.instance.serialize() if ModernizationManager.instance else {},
		"urban_data": UrbanEvolutionManager.instance.serialize() if UrbanEvolutionManager.instance else {},
		"politics_data": ModernPoliticsManager.instance.serialize() if ModernPoliticsManager.instance else {},
		"difficulty_level": int(DifficultyManager.get_difficulty()),

		"conspiracy_stage": sim.conspiracy_stage if sim else 0,
		"conspiracy_cooldown_turns": sim.conspiracy_cooldown_turns if sim else 0,
		"purged_conspirators": sim.purged_conspirators.duplicate() if sim else {},
		"active_conspirator_id": sim.active_conspirator_id if sim else "",
		"active_conspirator_name": sim.active_conspirator_name if sim else "",
		"active_conspirator_title": sim.active_conspirator_title if sim else "",
		"is_eulmyo_completed": bool(sim.is_eulmyo_completed) if sim else false,
		"quest_data": _quest_sys.serialize() if (_quest_sys and _quest_sys.has_method("serialize")) else {},
		"state_snap": _build_snap(sim),
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"tiles": tiles_data
	}

	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	return true

## 슬롯의 저장 데이터를 읽어 게임 치세 복원
static func load_game(slot_id: int, sim: SimulationCore, _grid: GameGrid = null, time_mgr: TimeManager = null, _quest_sys: Node = null) -> bool:
	is_loading = true
	_ensure_dir()
	var path := _path_override if _path_override != "" else get_slot_path(slot_id)
	if not FileAccess.file_exists(path):
		is_loading = false
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		is_loading = false
		return false
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		is_loading = false
		return false
	var data: Dictionary = json.data as Dictionary
	if data == null or data.is_empty():
		is_loading = false
		return false

	var saved_diff: int = int(data.get("difficulty_level", DifficultyManager.Difficulty.EASY))
	DifficultyManager.set_difficulty(saved_diff)

	var snap: Dictionary = data.get("state_snap", {}) if data.get("state_snap", {}) is Dictionary else {}
	if sim and not snap.is_empty():
		_restore_obj(sim, snap.get("sim", {}), "sim")
		_restore_obj(sim.pop_manager, snap.get("pop", {}), "pop")
	if sim:
		# 지난 달 국고 변화는 불러온 뒤 첫 달부터 새로 잰다(이전 게임 값이 섞이지 않게)
		sim.gold_at_last_budget = -1
		sim.last_month_gold_delta = 0
		sim.recent_gold_deltas.clear()
		sim.turn = int(data.get("turn", 1))
		sim.current_year = int(data.get("year", 1789))
		sim.population = int(data.get("pop", 120))
		sim.gold = int(data.get("gold", 2500))
		sim.rice = int(data.get("rice", 1600))
		sim.loyalty = int(data.get("loyalty", 88))
		sim.authority = int(data.get("authority", data.get("royal_power", 70)))
		CityStats.set_royal_power(sim.authority)
		sim.fortress_progress = int(data.get("fortress", 0))
		sim.flood_defense = int(data.get("flood_defense", 0))
		sim.flood_crisis_active = bool(data.get("flood_crisis_active", false))
		sim.flood_crisis_turns_left = int(data.get("flood_crisis_turns_left", 0))
		sim.drought_active = bool(data.get("drought_active", false))
		sim.plague_active = bool(data.get("plague_active", false))
		sim.military_power = int(data.get("military", 70))
		sim.defense_power = int(data.get("defense_power", 1000))
		# PORT-TRACE [공성전]: 예전 저장 파일엔 없는 값 — 기본값으로 (최대 1000 상한 안전 클램프)
		sim.defense_fatigue = clampi(int(data.get("defense_fatigue", 0)), 0, 1000)
		sim.repair_state = data.get("repair_state", {"active": false, "type": "none", "turns_left": 0})
		if data.has("troop_roster") and not (data["troop_roster"] as Dictionary).is_empty():
			sim.troop_roster = (data.get("troop_roster", {}) as Dictionary).duplicate()
			if not sim.troop_roster.has("sasu") or int(sim.troop_roster.get("total", 0)) != sim.military_power:
				var mm := MilitaryManager.new()
				sim.troop_roster = mm.compute_roster(sim.military_power)
		else:
			# 구버전 세이브 호환 fallback: 기본 편제 60:15:15:10 비율 자동 산출
			var mm := MilitaryManager.new()
			sim.troop_roster = mm.compute_roster(sim.military_power)
		# PORT-TRACE [학문력·인재]: 예전 저장 파일엔 없음 — 학문력 0, 등용 상태는 저장된 것만 덮어씀
		sim.academic = int(data.get("academic", data.get("academic_power", 0)))
		CityStats.deserialize(data)
		if sim.tech_tree:
			sim.tech_tree.deserialize(data)
		if sim.crown_prince_manager:
			var p_score: float = float(data.get("prince_edu_progress", data.get("crown_prince_education", 0)))
			sim.crown_prince_manager.set_progress(p_score)
		sim.boyuron = bool(data.get("boyuron", false))
		sim.segi_policy = bool(data.get("segi_policy", false))
		sim.is_eulmyo_completed = bool(data.get("is_eulmyo_completed", false))
		if not sim.is_eulmyo_completed:
			var u_dat: Dictionary = data.get("uigwe_data", {})
			if u_dat.get("published_wonhaeng", false) or u_dat.get("wonhaeng_published", false):
				sim.is_eulmyo_completed = true
			elif int(data.get("year", 1789)) >= 1796 and int(data.get("gold", 0)) > 10000:
				sim.is_eulmyo_completed = true
		sim.jangyong_review_year = int(data.get("jangyong_review_year", 0))
		var saved_rt: Dictionary = data.get("retainers", {})
		for rk in saved_rt.keys():
			if sim.retainers.has(rk):
				sim.retainers[rk] = bool(saved_rt[rk])
		# PORT-TRACE [불러오면 인재 해제]: 등용 여부를 따로 기억하는 ScholarManager.hired_scholars는 저장되지 않아, 게임을 다시 켜고 불러오면
		# 비어 있었다(이 캐시만 보는 효과·조언은 "등용 안 됨"으로 판단). 반대로 다른 세이브를 불러오면 예전 캐시가 남았다 → 불러온 값으로 다시 채운다.
		ScholarManager.hired_scholars.clear()
		for rk2 in sim.retainers.keys():
			if bool(sim.retainers[rk2]):
				ScholarManager.hired_scholars[rk2] = true
		sim.refugees = int(data.get("refugees", 0))
		sim.rebel_cd = int(data.get("rebel_cd", 0))
		sim.horde_cd = int(data.get("horde_cd", 0))
		sim.famine_active = bool(data.get("famine_active", false))  # Null-safe fallback
		sim.seojangdae_drill_cd_months = int(data.get("seojangdae_drill_cd_months", 0))
		sim.demand_res = int(data.get("demand_res", 50))
		sim.demand_com = int(data.get("demand_com", 30))
		sim.demand_agr = int(data.get("demand_agr", 40))
		if data.has("mega_projects") and (data["mega_projects"] as Array).size() > 0:
			var saved_mp: Array = data.get("mega_projects", [])
			for sp in saved_mp:
				for p in sim.mega_projects:
					if p.get("id", "") == sp.get("id", ""):
						p["is_started"] = bool(sp.get("is_started", false))
						p["is_completed"] = bool(sp.get("is_completed", false))
						p["is_paused"] = bool(sp.get("is_paused", false))
						p["is_disabled"] = bool(sp.get("is_disabled", false))
						p["disabled_msg"] = str(sp.get("disabled_msg", ""))
						p["progress_turns"] = int(sp.get("progress_turns", sp.get("progress_ticks", 0)))
						p["progress_ticks"] = p["progress_turns"]
						p["progress_float"] = float(sp.get("progress_float", float(p["progress_turns"])))
		if sim.pop_manager:
			sim.pop_manager.deserialize(data)
			sim.population = sim.pop_manager.total_population
			if data.has("tax_policy") and snap.is_empty():
				sim.pop_manager.current_tax_policy = int(data.get("tax_policy", 1)) as PopulationManager.TaxPolicy
		if "trial_manager" in sim and sim.trial_manager and data.has("trial_data"):
			sim.trial_manager.deserialize(data.get("trial_data", {}))
		if "bandit_manager" in sim and sim.bandit_manager and data.has("bandit_data"):
			sim.bandit_manager.deserialize(data.get("bandit_data", {}))
		if "uigwe_manager" in sim and sim.uigwe_manager and data.has("uigwe_data"):
			sim.uigwe_manager.deserialize(data.get("uigwe_data", {}))
			# 로드 후 court.uigwe 동기화 — 역직렬화 시 court가 업데이트되지 않아
			# HaenggungSubBuildingPopup에서 미편찬으로 표시되는 버그 수정
			var court_ref_ss = sim.get("court_ref")
			if court_ref_ss != null and "uigwe" in court_ref_ss and court_ref_ss.uigwe is Dictionary:
				for uigwe_key: String in ["wonhaeng", "seongyeok"]:
					if sim.uigwe_manager.is_completed(uigwe_key):
						court_ref_ss.uigwe[uigwe_key] = true

		if ModernizationManager.instance:
			var md: Variant = data.get("modernization_data", {})
			ModernizationManager.instance.deserialize(md if md is Dictionary else {})
		if UrbanEvolutionManager.instance:
			var ud: Variant = data.get("urban_data", {})
			UrbanEvolutionManager.instance.deserialize(ud if ud is Dictionary else {})
		if ModernPoliticsManager.instance:
			var pd: Variant = data.get("politics_data", {})
			ModernPoliticsManager.instance.deserialize(pd if pd is Dictionary else {})
		if data.has("academy_quiz_data") and data["academy_quiz_data"] is Dictionary:
			AcademyQuizManager.get_instance().deserialize(data["academy_quiz_data"])

		sim.conspiracy_stage = int(data.get("conspiracy_stage", 0))
		sim.conspiracy_cooldown_turns = int(data.get("conspiracy_cooldown_turns", 0))
		sim.purged_conspirators = (data.get("purged_conspirators", {}) as Dictionary).duplicate()
		sim.active_conspirator_id = str(data.get("active_conspirator_id", ""))
		sim.active_conspirator_name = str(data.get("active_conspirator_name", ""))
		sim.active_conspirator_title = str(data.get("active_conspirator_title", ""))
		sim.is_conspiracy_decision_pending = false
		sim.state_updated.emit(sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)

	if time_mgr:
		var loaded_yr: int = int(data.get("year", 1789))
		time_mgr.current_year = loaded_yr
		var s_name: String = str(data.get("season", "봄"))
		var m_val: int = 1
		match s_name:
			"봄": m_val = 3
			"여름": m_val = 6
			"가을": m_val = 9
			"겨울": m_val = 12
		time_mgr.current_month = m_val
		time_mgr.current_day = 1
		var y_diff: int = maxi(0, loaded_yr - 1789)
		time_mgr.total_ticks = y_diff * 360 + (m_val - 1) * 30
		time_mgr.time_changed.emit(time_mgr.current_year, s_name, time_mgr.current_month, time_mgr.current_day)
		time_mgr.month_changed.emit(time_mgr.current_month)
		time_mgr.year_changed.emit(time_mgr.current_year)
		time_mgr.last_season = s_name  # 로드 직후 season_changed 오발동 방지
		time_mgr.season_changed.emit(s_name)

	if _grid and data.has("tiles"):
		var tiles_data: Array = data.get("tiles", [])
		for ty in range(_grid.size):
			for tx in range(_grid.size):
				var cell: Dictionary = _grid.grid[ty][tx]
				cell["building"] = ""
				cell["zone"] = ""
				cell["surface"] = "normal"
				cell["under_construction"] = false
				cell["level"] = 0
				cell.erase("cheonju")
				for ek: String in TILE_EXT_KEYS:
					cell.erase(ek)
		for td: Dictionary in tiles_data:
			var tx: int = int(td.get("x", -1))
			var ty: int = int(td.get("y", -1))
			if _grid.in_bounds(tx, ty):
				var cell: Dictionary = _grid.grid[ty][tx]
				cell["building"] = str(td.get("b", ""))
				cell["is_burned_wasteland"] = (cell["building"] == "burned_wasteland")
				cell["zone"] = str(td.get("z", ""))
				cell["surface"] = str(td.get("sf", "normal"))
				cell["under_construction"] = bool(td.get("uc", false))
				cell["road_type"] = str(td.get("rt", "dirt"))
				cell["level"] = int(td.get("lvl", 0))
				cell["build_stage"] = int(td.get("bst", 2))
				if td.has("gn"):
					cell["gate_name"] = str(td.get("gn", ""))
				if bool(td.get("cj", false)):
					cell["cheonju"] = true # 천주교당(예전 저장엔 없음)
				if td.has("fid") and str(td.get("fid", "")) != "":
					cell["facility_id"] = str(td.get("fid", ""))
					cell["special_building_id"] = str(td.get("sbid", cell["facility_id"]))
					cell["is_special_building"] = bool(td.get("is_spec", true))
					cell["building_type"] = int(td.get("bt", GameGrid.BuildingType.SPECIAL))
				cell["is_ruined"] = bool(td.get("ir", false))
				if td.has("ext"):
					_decode_tile_ext(cell, td["ext"])
					if cell.has("wall_build"):
						_grid.register_build_tile(tx, ty) # 공사 중이던 성곽·다칸 시설의 공정 이어 가기
		# [건설 데드락 세이브 복구] 기존 세이브에 수년간 비계로 묶여 있는 건물터 감지 및 자율 완공 큐 복구
		if data.has("gates") and (data["gates"] as Dictionary).size() > 0:
			_grid.gates = (data.get("gates", {}) as Dictionary).duplicate(true)
		_grid.get_four_gates_positions() # 동적 성문 재검색 및 gates 동기화
		ConstructionManager.on_game_loaded(_grid, sim)
		WaterStructureManager.auto_heal_structures(_grid)
		_grid.update_reservoir_positions()
		IrrigationManager.recalculate_irrigation(_grid, sim)
		# [맹지 가옥 정리 마이그레이션]: 도로 없는 맹지 방치 가옥 자연 정리 (둔전은 천수답으로 온전히 보존)
		DistrictSpawner.clean_isolated_outskirts(_grid, sim)
		_grid.recompute_infrastructure()
		_grid.recount_zone_counts()
		BuildingManager.sync_workshop_and_shop_counts(_grid)
		if sim and sim.pop_manager:
			sim.pop_manager.sync_housing_lists_from_grid(_grid)
			sim.population = sim.pop_manager.total_population
		if sim:
			sim.flood_defense = maxi(int(data.get("flood_defense", 0)), _grid.flood_defense)
		if _grid and sim:
			_grid.fortress_progress = sim.fortress_progress
		if _quest_sys and _quest_sys.has_method("deserialize"):
			_quest_sys.deserialize(data)
		var saved_def: int = int(data.get("fortress_defense_power", CityStats.get_fortress_defense_power()))
		if saved_def >= 500 and sim:
			# 방호력이 높은(500 이상) 정상 세이브의 경우 이전 전투에서 누적된 비정상 피로도 즉시 정화
			sim.defense_fatigue = mini(sim.defense_fatigue, maxi(0, 1000 - saved_def))
		var recalc_res: Dictionary = CityStats.recalculate_defense_and_attack(_grid, sim)
		var calc_def: int = int(recalc_res.get("defense", 0))
		var target_def: int = maxi(saved_def, calc_def)
		if target_def > 0:
			CityStats.set_fortress_defense_power(target_def)
			CityStats.base_fortress_defense_power = maxi(CityStats.base_fortress_defense_power, target_def)
			if CityStats.fortress_max_defense_power < target_def:
				CityStats.fortress_max_defense_power = target_def
		var saved_atk: int = int(data.get("military_attack_power", CityStats.get_military_attack_power()))
		var calc_atk: int = int(recalc_res.get("attack", 0))
		var target_atk: int = maxi(saved_atk, calc_atk)
		if target_atk > 0:
			CityStats.set_military_attack_power(target_atk)
		var recalc_acad: int = CityStats.recalculate_academic_power(_grid, sim.retainers if sim else {})
		var target_acad: int = maxi(int(data.get("academic_power", data.get("academic", 0))), recalc_acad)
		CityStats.set_academic_power(target_acad)
		if sim:
			sim.academic = target_acad
		_grid.heal_structure_overwrites() # 성벽이 덮어써 사라진 서장대 되살림
		_grid.shrink_legacy_banghwa() # 예전 2x2 방화수류정 → 1칸
		_grid.shrink_legacy_forts() # 예전 포루 2x2 → 1x2, 공심돈 3x3 → 2x2
		if sim:
			sim.sync_mega_projects_with_grid(_grid)
			sim.state_updated.emit(sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)
		_grid.emit_signal("grid_changed")

	if snap.is_empty():
		# 예전 저장(상태 묶음 없음): 직전 게임 값이 남지 않게 기본값에서 시작하고, 저장된 세자 교육도로 맞춘다
		var m0 := _main_node()
		var ps: float = float(data.get("prince_edu_progress", data.get("crown_prince_education", 0)))
		if sim:
			sim.tax_rate_land = 7
			sim.tax_rate_market = 7
			sim.tax_rate_military = 7
			if sim.crown_prince_manager:
				sim.crown_prince_manager.status = CrownPrinceEducationManager.EducationStatus.IDLE
				sim.crown_prince_manager.is_invested = ps > 0.0
				sim.crown_prince_manager.set_progress(ps)
		if m0 != null and m0.get("court") != null and "crown_prince" in m0.get("court"):
			m0.get("court").crown_prince = {"invested": ps > 0.0, "education": int(ps), "tutor": ""}
	if not snap.is_empty():
		var m := _main_node()
		if sim:
			_restore_obj(sim.crown_prince_manager, snap.get("cpm", {}), "cpm")
		if m != null:
			var court_o: Object = m.get("court")
			_restore_obj(court_o, snap.get("court", {}), "court")
			if court_o != null and "eulmyo" in court_o and court_o.eulmyo is Dictionary:
				court_o.eulmyo["active"] = false # 행차 연출은 이어 가지 않는다
			_restore_obj(m.get("tutorial"), snap.get("guide", {}), "guide")
		var tm: Object = time_mgr if time_mgr != null else (m.get("time_manager") if m != null else null)
		_restore_obj(tm, snap.get("time", {}), "time")
		if sim:
			sim.state_updated.emit(sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)

	is_loading = false
	return true

## 초기 샘플 실록 데이터 자동 생성 비활성화 (사용자가 삭제한 세이브 슬롯을 임의로 덮어쓰지 않음)
static func init_default_samples_if_needed() -> void:
	pass
