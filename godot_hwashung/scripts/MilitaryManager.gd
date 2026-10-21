extends RefCounted
class_name MilitaryManager

## [조선 후기 삼수병(포수·사수·살수) 및 기포병 편제 관리 시스템]
## 포수 60% : 사수 15% : 살수 15% : 기포병 10% 엄격 고증 편제
## 평시: 연무대·행궁·서장대·사대문 순시 및 사열 훈련
## 전시: 병종별 전술 앵커 배치 (포수-성벽/포루 일제사격, 사수-곡사궁술, 살수-성문백병전, 기포병-외곽기동타격)
## 성능 최적화: 그룹 웨이포인트 기반 이동 및 오브젝트 풀링 (총구 화염/백색 연막/화살)

const RATIO_POSU: float = 0.60  # 포수 (조총병)
const RATIO_SASU: float = 0.15  # 사수 (궁병)
const RATIO_SALSU: float = 0.15 # 살수 (근접 창검병)
const RATIO_GIPO: float = 0.10  # 기포병 (기마 화포/총병)

var troop_roster: Dictionary = {
	"total": 20,
	"posu": 12,
	"sasu": 3,
	"salsu": 3,
	"gipo": 2
}

## 서장대 야조 미니게임 성공 횟수(0~10회)에 따른 추가 보너스 비율 (-20% ~ +20%)
static func calculate_yajo_drill_bonus_pct(success_count: int) -> int:
	var s: int = clampi(success_count, 0, 10)
	return (s - 5) * 4

## 서장대 야조 미니게임 성공 횟수에 따른 최종 훈련 배율 (0.80x ~ 1.20x)
static func calculate_yajo_drill_multiplier(success_count: int) -> float:
	var pct: int = calculate_yajo_drill_bonus_pct(success_count)
	return 1.0 + float(pct) / 100.0

## 연무대 군사 훈련 미니게임 성공 횟수(0~10회)에 따른 추가 보너스 비율 (-20% ~ +20%)
static func calculate_yeonmudae_drill_bonus_pct(success_count: int) -> int:
	var s: int = clampi(success_count, 0, 10)
	return (s - 5) * 4

## 연무대 군사 훈련 미니게임 성공 횟수에 따른 최종 훈련 배율 (0.80x ~ 1.20x)
static func calculate_yeonmudae_drill_multiplier(success_count: int) -> float:
	var pct: int = calculate_yeonmudae_drill_bonus_pct(success_count)
	return 1.0 + float(pct) / 100.0

var is_wartime: bool = false
var _military_agents: Array[int] = [] # 에이전트 ID 목록
var _saved_peace_anchors: Dictionary = {} # agent_id -> Vector2i (평시 순시 거점)

# 발사체 및 VFX 오브젝트 풀 (GC 렉 원천 차단)
const MAX_POOL_SIZE := 30
var smoke_pool: Array[Dictionary] = []
var arrow_pool: Array[Dictionary] = []
var flash_pool: Array[Dictionary] = []

func _init() -> void:
	_init_pools()

func _init_pools() -> void:
	smoke_pool.clear()
	arrow_pool.clear()
	flash_pool.clear()
	for i in range(MAX_POOL_SIZE):
		smoke_pool.append({"active": false, "x": 0.0, "y": 0.0, "life": 0.0, "max_life": 1.2, "size": 3.0})
		arrow_pool.append({"active": false, "from_x": 0.0, "from_y": 0.0, "to_x": 0.0, "to_y": 0.0, "progress": 0.0, "arc_h": 12.0})
		flash_pool.append({"active": false, "x": 0.0, "y": 0.0, "life": 0.0, "max_life": 0.2})

## 국방력 수치(military_power)에 따라 정규군 편제 수 산출
func compute_roster(mil_power: int) -> Dictionary:
	var total_count: int = clampi(int(float(mil_power) * 0.25), 10, 40)
	var n_posu: int = int(round(float(total_count) * RATIO_POSU))
	var n_sasu: int = int(round(float(total_count) * RATIO_SASU))
	var n_salsu: int = int(round(float(total_count) * RATIO_SALSU))
	var n_gipo: int = maxi(1, total_count - n_posu - n_sasu - n_salsu)

	troop_roster = {
		"total": total_count,
		"posu": n_posu,
		"sasu": n_sasu,
		"salsu": n_salsu,
		"gipo": n_gipo
	}
	return troop_roster

## 평시 정규군 스폰 및 배치
func spawn_regular_army(citizens: CitizenManager, grid: GameGrid, sim: SimulationCore) -> void:
	var mil_p: int = sim.military_power if sim else 70
	compute_roster(mil_p)
	_military_agents.clear()
	_saved_peace_anchors.clear()

	# 평시 거점 수집: 행궁 주변 및 순라청 배회 전면 배제!
	# 오직 연무대(동장대), 서장대, 사대문 초소에만 소수 정위치 경비 배치
	var waypoints: Array[Vector2i] = []
	for y: int in range(grid.size):
		for x: int in range(grid.size):
			var t: Dictionary = grid.grid[y][x]
			var b: String = str(t.get("building", ""))
			if b in ["yeonmudae", "seojangdae", "gate"] and not t.has("wall_build"):
				waypoints.append(Vector2i(x, y))

	if waypoints.is_empty():
		return # 연무대/서장대/성문이 없으면 평시 병사 스폰하지 않음

	# 평시에는 각 거점당 1~2명만 소수 정지 배치 (연무대/서장대 앞 정위치 경비)
	var max_guards: int = mini(waypoints.size() * 2, 6)
	var troop_types: Array[String] = ["posu", "salsu", "sasu", "posu", "salsu", "sasu"]

	for i in range(max_guards):
		var btype: String = troop_types[i % troop_types.size()]
		var anchor: Vector2i = waypoints[i % waypoints.size()]
		var spawn_pos: Vector2i = anchor + (Vector2i(1, 0) if (i % 2 == 1) else Vector2i(0, 1))
		spawn_pos = Vector2i(clampi(spawn_pos.x, 0, grid.size - 1), clampi(spawn_pos.y, 0, grid.size - 1))

		var ag: Dictionary = citizens._add_road_agent(btype, spawn_pos)
		var aid: int = int(ag.get("id", -1))
		_military_agents.append(aid)
		_saved_peace_anchors[aid] = spawn_pos

		ag["military_unit"] = true
		ag["btype"] = btype
		ag["peace_anchor"] = spawn_pos
		ag["is_static_guard"] = true
		ag["state"] = "peace_guard"
		ag["patrol_timer"] = 999.0 # 무의미한 배회 금지
		ag["speed"] = 0.95

		match btype:
			"posu":
				ag["bubble_text"] = "초소를 삼엄히 경비한다."
			"sasu":
				ag["bubble_text"] = "성곽 일대를 주시하고 있다."
			"salsu":
				ag["bubble_text"] = "정위치를 사수하며 경계한다."
			"gipo":
				ag["bubble_text"] = "초소를 지키고 있다."
		ag["bubble_timer"] = 3.0

## 전시 전술 배치 (공성전 발생 시 병종별 전술 앵커 배정)
func deploy_wartime(citizens: CitizenManager, grid: GameGrid, target_gate: Vector2i) -> void:
	is_wartime = true

	# 전술 앵커 수집
	var wall_anchors: Array[Vector2i] = []   # 포수용 (성벽 위, 포루, 공심돈)
	var high_anchors: Array[Vector2i] = []   # 사수용 (서장대, 연무대, 성문 상부)
	var gate_anchors: Array[Vector2i] = []   # 살수용 (성문 안쪽, 최전방)
	var outside_anchors: Array[Vector2i] = []# 기포병용 (성 밖 평야 기동로)

	for y: int in range(grid.size):
		for x: int in range(grid.size):
			var t: Dictionary = grid.grid[y][x]
			if t.has("wall_build"):
				continue
			var b: String = str(t.get("building", ""))
			var terr: String = str(t.get("terrain", "plain"))

			if b in ["wall", "poru", "gongsimdon", "gongsimdon_wall"]:
				wall_anchors.append(Vector2i(x, y))
			elif b in ["seojangdae", "yeonmudae", "gate"]:
				high_anchors.append(Vector2i(x, y))

			if terr == "outside" and (b == "" or b == "road"):
				if absi(x - target_gate.x) + absi(y - target_gate.y) in range(4, 12):
					outside_anchors.append(Vector2i(x, y))

	# 성문 안쪽 살수 앵커
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var np: Vector2i = target_gate + d
		if grid.in_bounds(np.x, np.y):
			gate_anchors.append(np)

	if wall_anchors.is_empty(): wall_anchors.append(target_gate)
	if high_anchors.is_empty(): high_anchors.append(target_gate)
	if gate_anchors.is_empty(): gate_anchors.append(target_gate)
	if outside_anchors.is_empty(): outside_anchors.append(Vector2i(1, int(float(grid.size) / 2.0)))

	# 정규군 유닛별 전시 전술 FSM 전환
	var posu_idx := 0
	var sasu_idx := 0
	var salsu_idx := 0
	var gipo_idx := 0

	for a: Dictionary in citizens.agents:
		if not a.get("military_unit", false) or a.get("is_dead", false):
			continue

		var btype: String = str(a.get("btype", "posu"))
		match btype:
			"posu":
				# 포수: 성곽 여장 및 포루 배치 -> 조총 일제 사격
				var tpos: Vector2i = wall_anchors[posu_idx % wall_anchors.size()]
				posu_idx += 1
				a["state"] = "wartime_posu"
				a["target_pos"] = tpos
				a["reload_timer"] = randf_range(1.5, 3.5)
				a["bubble_text"] = "조총 일제 사격 준비! 점화하라!"
				a["bubble_timer"] = 3.5
			"sasu":
				# 사수: 성곽 상부 및 고지대 배치 -> 곡사 궁술 견제
				var tpos2: Vector2i = high_anchors[sasu_idx % high_anchors.size()]
				sasu_idx += 1
				a["state"] = "wartime_sasu"
				a["target_pos"] = tpos2
				a["draw_timer"] = randf_range(1.0, 2.5)
				a["bubble_text"] = "곡사로 쏘아라! 성벽 아래 놈들을 궤멸시켜라!"
				a["bubble_timer"] = 3.5
			"salsu":
				# 살수: 성문 안쪽 최전방 요격 -> 백병전
				var tpos3: Vector2i = gate_anchors[salsu_idx % gate_anchors.size()]
				salsu_idx += 1
				a["state"] = "wartime_salsu"
				a["target_pos"] = tpos3
				a["bubble_text"] = "당파창을 세우고 돌파하는 놈들을 베어라!"
				a["bubble_timer"] = 3.5
			"gipo":
				# 기포병: 성 밖 평야 출격 -> 적 측면 기동 급습
				var tpos4: Vector2i = outside_anchors[gipo_idx % outside_anchors.size()]
				gipo_idx += 1
				a["state"] = "wartime_gipo"
				a["target_pos"] = tpos4
				a["flank_dir"] = 1.0 if gipo_idx % 2 == 0 else -1.0
				a["fire_timer"] = randf_range(2.0, 4.0)
				a["bubble_text"] = "기마 화포 출격! 적의 후방과 측면을 들이쳐라!"
				a["bubble_timer"] = 4.0

## 종전 및 평시 상태 롤백 (정규군 100% 원직/원거점 복귀)
func stand_down(citizens: CitizenManager) -> void:
	is_wartime = false

	for a: Dictionary in citizens.agents:
		if not a.get("military_unit", false) or a.get("is_dead", false):
			continue

		var aid: int = int(a.get("id", -1))
		var orig_anchor: Vector2i = _saved_peace_anchors.get(aid, Vector2i(int(a.get("x", 0)), int(a.get("y", 0))))

		a["state"] = "peace_patrol"
		a["target_pos"] = orig_anchor
		a["peace_anchor"] = orig_anchor
		a["bubble_text"] = "싸움이 끝났으니 진형을 정비하고 순시로 복귀하자."
		a["bubble_timer"] = 3.0

## 매 틱 정규군 FSM 및 발사체 연산
func update(citizens: CitizenManager, delta: float, target_siege_pos: Vector2i) -> void:
	# 발사체 및 VFX 풀 업데이트
	_update_pools(delta)

	if citizens == null:
		return

	for a: Dictionary in citizens.agents:
		if not a.get("military_unit", false) or a.get("is_dead", false):
			continue

		var btype: String = str(a.get("btype", "posu"))
		var state: String = str(a.get("state", "peace_patrol"))
		var _cur := Vector2(float(a["x"]), float(a["y"]))

		if not is_wartime or state == "peace_patrol":
			# 평시: 순시 및 훈련 FSM
			_update_peace_unit(a, citizens, delta)
		else:
			# 전시: 병종별 전술 FSM
			match btype:
				"posu":
					_update_wartime_posu(a, citizens, delta, target_siege_pos)
				"sasu":
					_update_wartime_sasu(a, citizens, delta, target_siege_pos)
				"salsu":
					_update_wartime_salsu(a, citizens, delta, target_siege_pos)
				"gipo":
					_update_wartime_gipo(a, citizens, delta, target_siege_pos)

## 평시 유닛 정위치 경비 루프: 평시에는 맵의 상점이나 행궁 주변을 배회하지 않고 초소 정위치 정지 경비
func _update_peace_unit(a: Dictionary, citizens: CitizenManager, delta: float) -> void:
	var anchor: Vector2i = a.get("peace_anchor", Vector2i(int(a["x"]), int(a["y"])))
	var cur := Vector2(float(a["x"]), float(a["y"]))
	var goal := Vector2(float(anchor.x) + 0.5, float(anchor.y) + 0.5)

	# 초소 정위치에서 이탈했을 경우에만 초소로 복귀
	if cur.distance_to(goal) > 0.4:
		citizens._move_agent_towards(a, goal, delta, float(a.get("speed", 0.95)))
	else:
		# 정위치 정지 경비 모션
		a["anim"] = float(a.get("anim", 0.0)) + delta * 1.5

## 전시 포수: 성벽 위 배치, 장전 후 일제 사격 (화염 + 백색 연기)
func _update_wartime_posu(a: Dictionary, citizens: CitizenManager, delta: float, enemy_pos: Vector2i) -> void:
	var tpos: Vector2i = a.get("target_pos", enemy_pos)
	var cur := Vector2(float(a["x"]), float(a["y"]))
	var goal := Vector2(float(tpos.x) + 0.5, float(tpos.y) + 0.5)

	if cur.distance_to(goal) > 0.4:
		citizens._move_agent_towards(a, goal, delta, float(a.get("speed", 0.95)))
	else:
		# 사격 FSM
		var rtimer: float = float(a.get("reload_timer", 0.0)) - delta
		a["reload_timer"] = rtimer
		if rtimer <= 0.0:
			a["reload_timer"] = randf_range(2.0, 4.0)
			# 조총 발사 이펙트
			spawn_flash(cur.x, cur.y - 0.4)
			spawn_smoke(cur.x, cur.y - 0.4)
			citizens.emit_signal("sfx", "gunfire")
			a["bubble_text"] = "탕! 장전 완료, 다음 열 발사!"
			a["bubble_timer"] = 2.0

## 전시 사수: 고지대 곡사 궁술
func _update_wartime_sasu(a: Dictionary, citizens: CitizenManager, delta: float, enemy_pos: Vector2i) -> void:
	var tpos: Vector2i = a.get("target_pos", enemy_pos)
	var cur := Vector2(float(a["x"]), float(a["y"]))
	var goal := Vector2(float(tpos.x) + 0.5, float(tpos.y) + 0.5)

	if cur.distance_to(goal) > 0.4:
		citizens._move_agent_towards(a, goal, delta, float(a.get("speed", 0.95)))
	else:
		var dtimer: float = float(a.get("draw_timer", 0.0)) - delta
		a["draw_timer"] = dtimer
		if dtimer <= 0.0:
			a["draw_timer"] = randf_range(1.5, 3.0)
			var target_v := Vector2(float(enemy_pos.x) + 0.5 + randf_range(-1, 1), float(enemy_pos.y) + 0.5 + randf_range(-1, 1))
			spawn_arrow(cur.x, cur.y - 0.5, target_v.x, target_v.y)
			citizens.emit_signal("sfx", "bow")

## 전시 살수: 성문 안쪽 최전방 백병전
func _update_wartime_salsu(a: Dictionary, citizens: CitizenManager, delta: float, enemy_pos: Vector2i) -> void:
	var tpos: Vector2i = a.get("target_pos", enemy_pos)
	var cur := Vector2(float(a["x"]), float(a["y"]))
	var goal := Vector2(float(tpos.x) + 0.5, float(tpos.y) + 0.5)

	if cur.distance_to(goal) > 0.3:
		citizens._move_agent_towards(a, goal, delta, float(a.get("speed", 1.05)))
	else:
		# 백병전 휘두름 애니메이션
		a["anim"] = float(a.get("anim", 0.0)) + delta * 6.0

## 전시 기포병: 성 밖 평야 출격 기동 사격 (Flanking)
func _update_wartime_gipo(a: Dictionary, citizens: CitizenManager, delta: float, enemy_pos: Vector2i) -> void:
	var cur := Vector2(float(a["x"]), float(a["y"]))
	var ft: float = float(a.get("fire_timer", 0.0)) - delta
	a["fire_timer"] = ft

	# 적 주변을 원형 또는 좌우로 기동
	var fdir: float = float(a.get("flank_dir", 1.0))
	var offset := Vector2(fdir * 3.5, sin(Time.get_ticks_msec() * 0.002) * 2.0)
	var patrol_dest := Vector2(float(enemy_pos.x) + 0.5, float(enemy_pos.y) + 0.5) + offset

	citizens._move_agent_towards(a, patrol_dest, delta, float(a.get("speed", 1.35)))

	if ft <= 0.0:
		a["fire_timer"] = randf_range(2.5, 4.5)
		spawn_flash(cur.x, cur.y - 0.5)
		spawn_smoke(cur.x, cur.y - 0.5)
		citizens.emit_signal("sfx", "gunfire")
		a["bubble_text"] = "기마 화포 일제 격발!"
		a["bubble_timer"] = 2.0

# ------------------------------------------------------------ 오브젝트 풀링 (Object Pooling)
func spawn_smoke(x: float, y: float) -> void:
	for p: Dictionary in smoke_pool:
		if not p["active"]:
			p["active"] = true
			p["x"] = x
			p["y"] = y
			p["life"] = 0.0
			p["size"] = randf_range(3.0, 5.0)
			return

func spawn_arrow(fx: float, fy: float, tx: float, ty: float) -> void:
	for a: Dictionary in arrow_pool:
		if not a["active"]:
			a["active"] = true
			a["from_x"] = fx
			a["from_y"] = fy
			a["to_x"] = tx
			a["to_y"] = ty
			a["progress"] = 0.0
			return

func spawn_flash(x: float, y: float) -> void:
	for f: Dictionary in flash_pool:
		if not f["active"]:
			f["active"] = true
			f["x"] = x
			f["y"] = y
			f["life"] = 0.0
			return

func _update_pools(delta: float) -> void:
	for p: Dictionary in smoke_pool:
		if p["active"]:
			p["life"] = float(p["life"]) + delta
			if float(p["life"]) >= float(p["max_life"]):
				p["active"] = false

	for a: Dictionary in arrow_pool:
		if a["active"]:
			a["progress"] = float(a["progress"]) + delta * 1.5
			if float(a["progress"]) >= 1.0:
				a["active"] = false

	for f: Dictionary in flash_pool:
		if f["active"]:
			f["life"] = float(f["life"]) + delta
			if float(f["life"]) >= float(f["max_life"]):
				f["active"] = false
