extends Node
class_name QuestSystem

# PORT-TRACE: src/core/GameState.ts (quests: 6대 교지), src/domain/HistoryEvents.ts (evaluateEnding: 8대 엔딩)
# 이식 로그: docs/godot_port_log.md 항목 P13

signal quest_completed(quest: Dictionary)
signal quest_updated(current_quest: Dictionary)
signal all_quests_completed
signal ending_triggered(ending_data: Dictionary)

const QUESTS := [
	{
		# PORT-TRACE [행궁=동헌]: 실제로 화성행궁이 수원유수부의 관아(동헌)를 겸했으므로 첫 교지를
		# 별도 동헌이 아니라 화성행궁 건립으로 바꿨다.
		"id": "haenggung",
		"title": "제1교지: 화성행궁 건립",
		"desc": "임금의 거처인 화성행궁을 넓은 평지(7×7칸)에 세우십시오. 송사와 치안은 따로 지을 관아(2×2)가 맡습니다.",
		"tool": "haenggung",
		"btn_text": "행궁 터 잡기",
		"reward": {"gold": 300, "rice": 150, "loyalty": 5, "authority": 5, "msg": "화성행궁이 완공되었습니다! (+금 300, +쌀 150, 민심·왕권 +5)"}
	},
	{
		"id": "road",
		"title": "제2교지: 삼남대로 5칸 개설",
		"desc": "행궁 앞으로 이어지는 큰길(삼남대로)을 끌어서 물류망을 뚫으십시오.",
		"tool": "road",
		"btn_text": "도로 닦기",
		"reward": {"gold": 150, "rice": 50, "loyalty": 0, "authority": 0, "msg": "삼남대로가 뚫려 보부상과 유민들이 모여듭니다! (+금 150, +쌀 50)"}
	},
	# PORT-TRACE [문 먼저]: 사용자 요청 — "실제 화성 축성 때 문을 먼저 만들었다는 기록이 있다. 길이
	# 뚫리고 문이 생긴 뒤 저잣거리가 형성되고 그 뒤로 사람이 다녀야 한다". 도로 다음에 성문 교지를
	# 넣고, 마을·저잣거리 교지를 그 바로 뒤로 당겼다(서장대·봉돈 같은 군사 시설은 그 뒤).
	{
		"id": "gate",
		"title": "제3교지: 성문(城門) 먼저 세우기",
		"desc": "화성 축성은 사대문부터 시작했습니다. 삼남대로가 지나는 길목에 [홍예성문]을 세우십시오.",
		"tool": "gate",
		"btn_text": "성문 세우기",
		"reward": {"gold": 200, "rice": 50, "loyalty": 5, "authority": 0, "msg": "성문이 서서 사람과 물자가 드나들 길목이 열렸습니다! (+금 200, +쌀 50, 민심 +5%)"}
	},
	{
		"id": "civil_zoning",
		"title": "제4교지: 저잣거리·마을과 공동 우물 조성",
		"desc": "성문 안쪽 길가에 저잣거리(상업)와 방·리(주거), 둔전(농업) 구획을 지정하고 우물을 파십시오.",
		"tool": "well",
		"btn_text": "우물 파기",
		"reward": {"gold": 300, "rice": 200, "loyalty": 0, "authority": 0, "msg": "백성들이 정착하고 신도시가 활기를 띱니다! (+금 300, +쌀 200)"}
	},
	{
		"id": "seojangdae",
		"title": "제5교지: 팔달산 서장대(西將臺) 축조",
		"desc": "팔달산 정상에 군사 총지휘소 [서장대]를 축조하십시오.",
		"tool": "seojangdae",
		"btn_text": "서장대 축조",
		"reward": {"gold": 150, "rice": 0, "loyalty": 5, "authority": 0, "msg": "서장대가 세워져 팔달산 정상에서 사방을 감제합니다! (+금 150, 민심 +5%)"}
	},
	{
		"id": "bongdon",
		"title": "제6교지: 화성 봉돈(烽墩) 축조",
		"desc": "성곽이나 성문 바로 옆에 위급을 알리는 5연 굴뚝 [봉돈]을 축조하십시오. (실제 화성처럼 성곽 동쪽 능선에 위치)",
		"tool": "bongdon",
		"btn_text": "봉돈 축조",
		"reward": {"gold": 150, "rice": 0, "loyalty": 5, "authority": 0, "msg": "봉돈이 축조되어 주야간 군사 통신망이 완비되었습니다! (+금 150, 민심 +5%)"}
	},
	{
		"id": "wall_build",
		"title": "제7교지: 화성 성곽 축조 및 완공",
		"desc": "화성 성곽을 둘러치고 24년 내에 100% 완공을 달성하십시오.",
		"tool": "wall",
		"btn_text": "성곽 축조",
		"reward": {"gold": 1000, "rice": 0, "loyalty": 0, "authority": 30, "msg": "축하하옵니다! 수원화성 성곽이 완벽히 완공되었습니다! (+금 1000, 왕권 +30)"}
	}
]

var current_quest_index: int = 0
var is_all_completed: bool = false
var ending_shown: bool = false
var completed_quests: Dictionary = {}

func is_quest_completed(qid: String) -> bool:
	if completed_quests.get(qid, "") in ["COMPLETED", "ARCHIVED"]:
		return true
	for i in range(current_quest_index):
		if i < QUESTS.size() and QUESTS[i]["id"] == qid:
			return true
	return false

var grid: GameGrid
var sim: SimulationCore
var court: CourtSystem

func setup(g: GameGrid, s: SimulationCore, c: CourtSystem) -> void:
	grid = g
	sim = s
	court = c
	grid.grid_changed.connect(check_current_quest)
	sim.turn_advanced.connect(_on_turn_advanced)
	emit_signal("quest_updated", get_current_quest())

func get_current_quest() -> Dictionary:
	if current_quest_index < QUESTS.size():
		return QUESTS[current_quest_index]
	return {}

const GATE_ORDER := [
	{"id": "jangan", "name": "장안문(북문)", "pos": Vector2i(26, 6)},
	{"id": "paldal", "name": "팔달문(남문)", "pos": Vector2i(16, 54)},
	{"id": "hwaseo", "name": "화서문(서문)", "pos": Vector2i(6, 13)},
	{"id": "changryong", "name": "창룡문(동문)", "pos": Vector2i(48, 29)},
	{"id": "hwahong", "name": "화홍문(북수문)", "pos": Vector2i(35, 6)},
]

func _is_gate_constructed_or_started(g: Dictionary) -> bool:
	if grid == null:
		return false
	var gp: Vector2i = g.get("pos", Vector2i(-1, -1))
	var gname: String = g.get("name", "")
	var g_short: String = gname.split("(")[0].strip_edges()

	# 1. 맵 전체에서 해당 성문 이름으로 명명된 문이 있는지 확인
	for y in range(grid.size):
		for x in range(grid.size):
			var t: Dictionary = grid.grid[y][x]
			if t.get("building", "") == "gate":
				var t_name: String = t.get("gate_name", "")
				if t_name != "" and g_short != "" and (g_short in t_name):
					return true

	# 2. 고증 좌표 반경 3타일 내에 성문(gate) 또는 화홍문이 존재하는지 확인
	if gp.x >= 0 and gp.y >= 0:
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var nx := gp.x + dx
				var ny := gp.y + dy
				if grid.in_bounds(nx, ny):
					var t: Dictionary = grid.grid[ny][nx]
					var b: String = t.get("building", "")
					if b == "gate" or (g.get("id", "") == "hwahong" and (t.get("is_hwahong", false) or b == "hwahong")):
						return true
	return false

## PORT-TRACE [퀘스트 위치 추천]: "초등학생이 하는 게임이니 친절한 안내가 필요하다"는 요청 —
## 좌표를 고정으로 박아두지 않고(지형이 붓으로 바뀔 수 있으므로) 매번 실제로 지을 수 있는
## 자리를 찾아 추천한다. 못 찾으면 Vector2i(-1,-1)을 돌려주고, 호출부는 버튼을 숨긴다.
func find_hint_position(quest_id: String) -> Vector2i:
	match quest_id:
		"haenggung":
			# 팔달산 동쪽 기슭 완만한 평지 7x7의 가운데 칸 (14, 29)
			var anchor := Vector2i(14, 29)
			if grid.validate_site("haenggung", anchor.x, anchor.y) == "":
				return anchor
			return _find_closest_valid_site("haenggung", anchor)
		"road":
			# 행궁 부지 바로 옆 빈 평지(행궁 앞길)
			return _find_first(func(x, y):
				var t: Dictionary = grid.tile(x, y)
				return t["terrain"] == "plain" and t["building"] == "" and not t["under_construction"] and (grid.has_neighbor(x, y, "haenggung_site") or grid.has_neighbor(x, y, "haenggung"))
			)
		"gate":
			# 사대문 및 수문 순차 추천: 장안문 -> 팔달문 -> 화서문 -> 창룡문 -> 화홍문
			for g in GATE_ORDER:
				if _is_gate_constructed_or_started(g):
					continue
				var gp: Vector2i = g["pos"]
				if grid.in_bounds(gp.x, gp.y):
					if grid.validate_tool("gate", gp.x, gp.y) == "":
						return gp
					# 고증 좌표 바로 옆(길 위)에 세울 수 있는지 탐색
					for d: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
						var np: Vector2i = gp + d
						if grid.in_bounds(np.x, np.y) and grid.validate_tool("gate", np.x, np.y) == "":
							return np
			# 이미 사대문이 다 섰거나 특별한 경우, 기존 도로 중 가능한 자리
			return _find_first(func(x, y):
				var t: Dictionary = grid.tile(x, y)
				return t["building"] == "road" and t["terrain"] != "outside" and grid.validate_tool("gate", x, y) == ""
			)
		"seojangdae":
			# 팔달산 정상 바위 2x2 (왼쪽 위 칸 5, 28 — 고도 최고점)
			var sj_pos := Vector2i(5, 28)
			if grid.validate_tool("seojangdae", sj_pos.x, sj_pos.y) == "":
				return sj_pos
			return _find_closest_valid_tool("seojangdae", sj_pos)
		"bongdon":
			# 성곽이 미완공된 상태에서는 추천 제한
			if grid.count_completed("wall") == 0:
				return Vector2i(-1, -1)
			# 고증 위치: 동남 구릉 능선 (42, 44) 부근
			var bg_pos := Vector2i(42, 44)
			if grid.validate_tool("bongdon", bg_pos.x, bg_pos.y) == "":
				return bg_pos
			return _find_closest_valid_tool("bongdon", bg_pos)
		"manseokgeo":
			# 성 밖 북서 최외곽 (10, 4) 부근
			var mg_pos := Vector2i(10, 4)
			if grid.validate_site("manseokgeo", mg_pos.x, mg_pos.y) == "":
				return mg_pos
			return _find_closest_valid_site("manseokgeo", mg_pos)
		"civil_zoning":
			return _find_first(func(x, y):
				var t: Dictionary = grid.tile(x, y)
				return t["terrain"] == "plain" and t["building"] == "" and t["zone"] == "" and not t["under_construction"]
			)
		_:
			return Vector2i(-1, -1)

func _find_closest_valid_site(site_type: String, target: Vector2i) -> Vector2i:
	# 타겟 주변 국소 반경 우선 탐색 (심시티 2000급 경량화: 4,096칸 전수조사 대신 근접 반경 즉시 반환)
	for r in range(0, 16):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var x: int = target.x + dx
				var y: int = target.y + dy
				if grid.in_bounds(x, y) and grid.validate_site(site_type, x, y) == "":
					return Vector2i(x, y)
	return target

func _find_closest_valid_tool(tool_name: String, target: Vector2i) -> Vector2i:
	# 타겟 주변 국소 반경 우선 탐색
	for r in range(0, 16):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var x: int = target.x + dx
				var y: int = target.y + dy
				if grid.in_bounds(x, y) and grid.validate_tool(tool_name, x, y) == "":
					return Vector2i(x, y)
	return target

func _find_first(pred: Callable) -> Vector2i:
	for y in range(grid.size):
		for x in range(grid.size):
			if pred.call(x, y):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

## PORT-TRACE [퀘스트 자동 정리]: 사용자 요청 — "이미 완료된 과제(예: 국책대역사로 장안문 완공)는 '알겠어요'를 반복해 누르게
## 하지 말고 조건 충족 즉시 완료 처리 후 목록에서 영구히 사라지게, 이미 지은 것을 김판관이 다시 제안하지 않게".
## 이제 조건이 이미 채워진 교지가 여러 개면 한 번에 차례로 모두 완료(보상 지급)하고 다음 미완료 교지로 넘어간다.
func check_current_quest() -> void:
	var guard := 0
	while not is_all_completed and current_quest_index < QUESTS.size() and guard < QUESTS.size():
		guard += 1
		if not _complete_if_satisfied():
			break

func _is_satisfied(q: Dictionary) -> bool:
	var success := false
	match q["id"]:
		"haenggung":
			success = grid.has_site_started("haenggung") or grid.count_completed("haenggung") > 0
		"road":
			# PORT-TRACE P25: 성 밖 옛 간선로(사전 배치)는 제외 — 플레이어가 성 안에 직접 놓은 도로만 인정
			success = grid.count_buildings_inside("road") >= 5
		# 착공(부지 지정/공사 중)된 시점에 즉시 달성 처리하여 다음 추천 단계로 전환
		"gate":
			success = grid.count_buildings("gate") > 0 or _gate_megaproject_active()
		"seojangdae":
			success = grid.count_buildings("seojangdae") > 0
		"bongdon":
			success = grid.count_buildings("bongdon") > 0
		"civil_zoning":
			var has_well := grid.count_buildings("well") > 0
			var has_zone := grid.has_any_zone() or grid.count_buildings("res") > 0 or grid.count_buildings("com") > 0 or grid.count_buildings("agr") > 0
			success = has_well and has_zone
		"wall_build":
			var loop_ok: bool = grid.is_wall_loop_completed() if grid and grid.has_method("is_wall_loop_completed") else false
			var sim_wall_ok: bool = (sim != null and sim.fortress_progress >= 100)
			success = (grid.fortress_progress >= 100) or (loop_ok and grid.fortress_progress >= 99) or sim_wall_ok
	return success

## 국책대역사로 성문(장안문·팔달문 등)을 착공했거나 완공했으면 성문 교지도 이룬 것으로 본다
func _gate_megaproject_active() -> bool:
	for p in sim.mega_projects:
		if String(p.get("id", "")) in ["hwahong_north", "namsu_south", "changryong_east", "paldal_fortress"] and (p.get("is_started", false) or p.get("is_completed", false)):
			return true
	return false

func _complete_if_satisfied() -> bool:
	var q: Dictionary = QUESTS[current_quest_index]
	var success := _is_satisfied(q)
	if success:
		var r: Dictionary = DifficultyManager.get_quest_reward(q.get("reward", {}))
		var gold_reward: int = int(r.get("gold", 0))
		var rice_reward: int = int(r.get("rice", 0))
		sim.gold += gold_reward
		sim.rice += rice_reward
		sim.loyalty = min(100, sim.loyalty + r.get("loyalty", 0))
		sim.authority = min(100, sim.authority + r.get("authority", 0))
		sim.emit_signal("state_updated", sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)
		completed_quests[q["id"]] = "COMPLETED"
		var completed_q_info: Dictionary = q.duplicate()
		completed_q_info["reward"] = r
		emit_signal("quest_completed", completed_q_info)
		current_quest_index += 1
		if current_quest_index >= QUESTS.size():
			is_all_completed = true
			emit_signal("all_quests_completed")
			emit_signal("quest_updated", {})
		else:
			emit_signal("quest_updated", get_current_quest())
	return success

func serialize() -> Dictionary:
	return {
		"current_quest_index": current_quest_index,
		"is_all_completed": is_all_completed,
		"completed_quests": completed_quests.duplicate()
	}

func deserialize(data: Dictionary) -> void:
	if data.has("quest_data") and data["quest_data"] is Dictionary:
		var qd: Dictionary = data["quest_data"]
		current_quest_index = int(qd.get("current_quest_index", 0))
		is_all_completed = bool(qd.get("is_all_completed", false))
		completed_quests = (qd.get("completed_quests", {}) as Dictionary).duplicate()
	elif data.has("current_quest_index"):
		current_quest_index = int(data.get("current_quest_index", 0))
		is_all_completed = bool(data.get("is_all_completed", false))
		completed_quests = (data.get("completed_quests", {}) as Dictionary).duplicate()
	else:
		# 구버전 세이브 마이그레이션: 1800년 이후이거나 성곽 100%이면 모든 어명 완수 처리
		var yr: int = int(data.get("year", 1789))
		var fort: int = int(data.get("fortress", 0))
		if yr >= 1800 or fort >= 100:
			current_quest_index = QUESTS.size()
			is_all_completed = true
			for q_item in QUESTS:
				completed_quests[q_item["id"]] = "COMPLETED"
	if is_all_completed:
		emit_signal("quest_updated", {})
	else:
		emit_signal("quest_updated", get_current_quest())

func _on_turn_advanced(turn: int, _season_index: int, _year: int) -> void:
	check_current_quest()
	if turn >= 96 and not ending_shown:
		ending_shown = true
		var end_data := evaluate_ending()
		emit_signal("ending_triggered", end_data)

## TS의 HistoryEvents.evaluateEnding 8대 멀티 엔딩 완벽 이식
func evaluate_ending() -> Dictionary:
	var fortress := grid.fortress_progress
	var loyalty := sim.loyalty
	var authority := sim.authority
	var gold := sim.gold
	var military := sim.military_power

	if fortress >= 100 and authority >= 85 and loyalty >= 85 and gold >= 3000:
		return {
			"type": "true_ending",
			"title": "자강(自强)의 신조선",
			"story": "수원화성이 난공불락의 개혁 요새로 완벽히 완공되었습니다! 탕평책과 상공업 부흥이 확고히 뿌리내려, 정조 사후에도 권문세족의 세도정치가 발붙이지 못하고 조선은 동아시아 최고의 근대 문명국가로 도약합니다."
		}
	elif fortress >= 80 and gold >= 5000 and court.is_hired("park"):
		return {
			"type": "merchant_city",
			"title": "동방의 상업 공화국",
			"story": "신해통공과 삼남대로 교역의 성공으로 화성은 청나라와 왜를 잇는 거대 상업 메트로폴리스가 되었습니다. 상인과 중인 계층이 의회를 주도하며 경제 중심의 새로운 역사를 개창합니다."
		}
	elif fortress >= 100 and military >= 300 and court.is_hired("baek"):
		return {
			"type": "military_bastion",
			"title": "철혈의 군사 요새",
			"story": "정예 장용외영과 팔달산 서장대, 완벽한 포루·치성이 북방과 해안을 철통 수호합니다. 훗날 외세의 침략을 압도적으로 격퇴하는 자주 국방의 보루가 완성되었습니다."
		}
	elif fortress >= 90 and court.research["seed"] and court.research["gwanong"]:
		return {
			"type": "cultural_renaissance",
			"title": "문예부흥의 시대",
			"story": "규장각 실학과 만석거 관개, 《화성성역의궤》가 완비되어 세계에서 가장 아름답고 과학적인 성곽 도시로 유네스코 세계문화유산의 금자탑을 쌓았습니다."
		}
	elif loyalty <= 30:
		return {
			"type": "peasant_revolt",
			"title": "민란과 잿더미",
			"story": "가혹한 부역과 군량 부족으로 굶주린 백성들이 횃불을 들고 봉기했습니다. 공사 중이던 화성은 화염에 휩싸이고 정조의 원대한 개혁은 잿더미가 되었습니다."
		}
	elif gold < 0 or court.is_hired("hong"):
		return {
			"type": "oligarchy_puppet",
			"title": "세도 가문의 손아귀",
			"story": "무리한 차관과 세도가와의 타협으로 화성의 모든 이권이 노론 척신들에게 넘어갔습니다. 정조 승하 후 안동 김씨의 세도정치가 60년간 조선을 집어삼킵니다."
		}
	elif fortress >= 100:
		return {
			"type": "historical_ending",
			"title": "미완의 개혁",
			"story": "웅장하고 수려한 수원화성은 우뚝 섰으나, 정조의 갑작스러운 승하와 함께 수구 세력이 득세하며 역사 그대로 세도정치의 소용돌이로 흘러갑니다."
		}
	else:
		return {
			"type": "failed_project",
			"title": "모래 위의 누각",
			"story": "24년의 세월이 흘렀으나 화성은 미완성으로 방치되었습니다. 낭비된 국고와 피폐해진 민심 속에 개혁 군주의 웅지는 역사 속으로 스러져 갑니다."
		}
