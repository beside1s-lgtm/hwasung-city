extends Node
class_name SunlacheongManager

## [순라청(巡邏廳) 도시 핵심 치안·방위 기관 컨트롤러]
## 1. 저잣거리 우발 범죄 및 분쟁 발생 시스템 (동시 1~2건 제한, 상점 3개소 이상 밀집, 민심 연동 빈도)
## 2. 순라군(포졸) FSM 출동 및 범죄자 관아 압송 (육모방망이 진압, 오라줄 포박, 화성유수부 압송)
## 3. 치안 골든타임(25초) 및 실패 페널티 (민심 -2, 저잣거리 세수 -10%, [치안 불안] 알림)
## 4. 도적떼 및 반란군 토벌 병력 동원 연동 (순라청당 국방력 +30, 도적 침입 시 약탈 25% 경감)

static var instance: SunlacheongManager = null

@warning_ignore("unused_signal")
signal dispute_occurred(event_type: String, pos: Vector2i)
@warning_ignore("unused_signal")
signal dispute_resolved(event_type: String, success: bool, pos: Vector2i)
@warning_ignore("unused_signal")
signal criminal_jailed(kind: String)
@warning_ignore("unused_signal")
signal security_alert(msg: String)

# 상수 정의
const MAX_CONCURRENT_DISPUTES: int = 2
const DISPUTE_CHECK_INTERVAL: float = 6.0
const GOLDEN_TIME_LIMIT: float = 15.0 # 치안 골든타임 15.0초 (싸움꾼 제자리 격투 15초 규격)
const CRIME_COOLDOWN_TIME: float = 40.0 # 사건 종료 후 최소 40초 쿨타임
const STUCK_LIMIT_SECONDS: float = 30.0

const OFFICERS_PER_STATION: int = 2

# 관리 상태 변수
var patrol_stations: Array[Vector2i] = []
var officer_pool: Array[PatrolOfficerNPC] = []
var active_events: Array[MarketDisputeEvent] = []
var active_criminals: Array[CriminalNPC] = []

var dispute_check_timer: float = 0.0
var crime_cooldown_timer: float = 0.0
var cleanup_check_timer: float = 0.0
var next_event_id: int = 1
var next_criminal_id: int = 1
var next_officer_id: int = 1

var gwana_positions: Array[Vector2i] = []
## PORT-TRACE [관아 하나로 온 고을]: 관아는 한 곳만 있어도 고을 전체를 맡는다(거리·반경 없음). 시보·송사·포졸이 이 값을 본다.
static var gwana_built: bool = false
static var gwana_anchor: Vector2i = Vector2i(-1, -1)
const NO_GWANA_CRIME_BONUS: float = 0.10 # 관아가 없으면 범죄 발생 +10%p
const PRISON_ESCAPE_CHANCE: float = 0.20 # 관아가 없거나 옥이 차면 압송한 죄인이 달아날 확률
const JAIL_CAPACITY: int = 6 # 관아 옥사 정원(CitizenManager gw_prisoners와 같다)
var _grid_ref: GameGrid = null
var _cm_ref: CitizenManager = null

func _init() -> void:
	instance = self

func _ready() -> void:
	instance = self

## 초기화 및 참조 동기화
func setup(grid: GameGrid) -> void:
	instance = self
	sync_stations_from_grid(grid)
	cleanup_stuck_crime_entities()

## 그리드에서 순라청 및 관아 위치 스캔 및 포졸 풀 동기화
func sync_stations_from_grid(grid: GameGrid) -> void:
	patrol_stations.clear()
	gwana_positions.clear()

	if grid == null or not (grid.grid is Array):
		return

	var g_size: int = grid.grid.size()
	for y: int in range(g_size):
		var row: Array = grid.grid[y]
		for x: int in range(row.size()):
			var cell: Dictionary = row[x]
			var bld: String = str(cell.get("building", ""))
			var under_c: bool = bool(cell.get("under_construction", false))
			if bld == "patrol" and not under_c:
				patrol_stations.append(Vector2i(x, y))
			elif bld == "gwana" and not under_c:
				gwana_positions.append(Vector2i(x, y))
	gwana_built = not gwana_positions.is_empty()
	gwana_anchor = gwana_positions[0] if gwana_built else Vector2i(-1, -1)

	# 순라청당 2명의 포졸 풀 유지 (순라청이 없더라도 관아/행궁이 있으면 최소 2명의 포졸을 기본 상시 대기)
	var base_station_count: int = patrol_stations.size()
	var fallback_pos: Vector2i = Vector2i(20, 20)
	if not gwana_positions.is_empty():
		fallback_pos = gwana_positions[0]
	elif not patrol_stations.is_empty():
		fallback_pos = patrol_stations[0]

	var target_officer_count: int = maxi(2 if not gwana_positions.is_empty() or not patrol_stations.is_empty() else 0, base_station_count * OFFICERS_PER_STATION)

	# 기존 대기 포졸들의 본거지(home_pos) 재배정
	for i in range(officer_pool.size()):
		var off: PatrolOfficerNPC = officer_pool[i]
		if not patrol_stations.is_empty():
			var st_idx: int = int(float(i) / float(OFFICERS_PER_STATION)) % patrol_stations.size()
			off.home_pos = patrol_stations[st_idx]
			if not off.is_active and off.state == PatrolOfficerNPC.OfficerState.IDLE_PATROL:
				off.x = float(off.home_pos.x) + 0.5
				off.y = float(off.home_pos.y) + 0.5
		elif not gwana_positions.is_empty():
			off.home_pos = fallback_pos
			if not off.is_active and off.state == PatrolOfficerNPC.OfficerState.IDLE_PATROL:
				off.x = float(off.home_pos.x) + 0.5
				off.y = float(off.home_pos.y) + 0.5

	while officer_pool.size() < target_officer_count:
		var st_pos: Vector2i = fallback_pos
		if not patrol_stations.is_empty():
			var st_idx: int = int(float(officer_pool.size()) / float(OFFICERS_PER_STATION)) % patrol_stations.size()
			st_pos = patrol_stations[st_idx]
		var officer := PatrolOfficerNPC.new()
		officer.setup_officer(next_officer_id, st_pos)
		next_officer_id += 1
		officer_pool.append(officer)

## 매 틱 업데이트 (Main/CitizenManager에서 호출)
func update_system(
	delta: float,
	sim: SimulationCore,
	grid: GameGrid,
	citizens: CitizenManager
) -> void:
	_grid_ref = grid
	_cm_ref = citizens
	# 0. 순라청 및 관아 위치 실시간 그리드 동기화 (새로 지어진 순라청 즉시 감지 및 반영)
	if grid != null:
		sync_stations_from_grid(grid)

	# 쿨타임 감소
	if crime_cooldown_timer > 0.0:
		crime_cooldown_timer -= delta

	# 10초마다 고착 엔티티 클린업
	cleanup_check_timer += delta
	if cleanup_check_timer >= 10.0:
		cleanup_check_timer = 0.0
		cleanup_stuck_crime_entities()

	# 1. 분쟁 발생 주기 점검
	dispute_check_timer += delta
	if dispute_check_timer >= DISPUTE_CHECK_INTERVAL:
		dispute_check_timer = 0.0
		_check_dispute_spawn(sim, grid, citizens)

	# 2. 활성 분쟁 이벤트 및 타이머 갱신
	_update_active_events(delta, sim, grid, citizens)

	# 3. 출동 순라군 FSM 업데이트
	_update_officers(delta, grid, citizens)

	# 4. 범죄자 FSM 업데이트
	_update_criminals(delta)


## 저잣거리 우발 분쟁/소매치기 발생 점검 (도둑 최대 1명, 싸움 최대 1건, 종료 후 40초 쿨타임)
func _check_dispute_spawn(
	sim: SimulationCore,
	grid: GameGrid,
	citizens: CitizenManager
) -> void:
	# 40초 쿨타임 검사
	if crime_cooldown_timer > 0.0:
		return

	# 동시 범죄 엄격 제한 (도둑 최대 1명, 싸움 최대 1건)
	var thief_count: int = 0
	var brawl_count: int = 0
	for ev: MarketDisputeEvent in active_events:
		if ev.state == MarketDisputeEvent.EventState.ACTIVE:
			if ev.event_type == MarketDisputeEvent.DisputeType.PICKPOCKET:
				thief_count += 1
			else:
				brawl_count += 1

	for c: CriminalNPC in active_criminals:
		if not c.is_dead:
			if c.kind == CriminalNPC.CriminalKind.PICKPOCKET:
				thief_count = maxi(thief_count, 1)
			else:
				brawl_count = maxi(brawl_count, 1)

	if thief_count >= 1 and brawl_count >= 1:
		return

	# 상점 목록 조회
	var shop_tiles: Array[Vector2i] = []
	if citizens != null and not citizens._shop_cache.is_empty():
		shop_tiles = citizens._shop_cache
	elif grid != null and grid.grid is Array:
		var g_size: int = grid.grid.size()
		for y: int in range(g_size):
			var row: Array = grid.grid[y]
			for x: int in range(row.size()):
				var b: String = str(row[x].get("building", ""))
				if b.begins_with("com_") or b == "market":
					shop_tiles.append(Vector2i(x, y))

	# 상점 3개소 이상 밀집 구역 조건
	if shop_tiles.size() < 3:
		return

	# 민심 연동 발생 확률 (민심 70 이상: 10%, 민심 40 이하: 35%)
	var cur_loyalty: int = sim.loyalty if sim != null else 70
	var spawn_chance: float = 0.10
	if cur_loyalty <= 40:
		spawn_chance = 0.35
	elif cur_loyalty < 70:
		var t_val: float = float(70 - cur_loyalty) / 30.0
		spawn_chance = lerpf(0.10, 0.35, t_val)

	# 인구 10만 초과 비례 범죄율 보너스 합산 및 하드캡(5% ~ 50%) 적용
	var cur_pop: int = sim.population if sim != null else 0
	var crime_bonus: float = DifficultyManager.get_crime_chance_bonus(cur_pop)
	# 고을에 관아가 하나도 없으면 범죄가 잦아진다(관아 하나면 온 고을이 덮인다)
	if gwana_positions.is_empty():
		crime_bonus += NO_GWANA_CRIME_BONUS
	spawn_chance = clampf(spawn_chance + crime_bonus, 0.05, 0.50)

	if randf() > spawn_chance:
		return

	# 발생 장소 선정 (상점 중 1곳)
	var spawn_loc: Vector2i = shop_tiles[randi() % shop_tiles.size()]

	# 이미 해당 위치에서 분쟁 중이면 스킵
	for ev: MarketDisputeEvent in active_events:
		if ev.location == spawn_loc and ev.state == MarketDisputeEvent.EventState.ACTIVE:
			return

	# 사건 유형 선정 (한쪽이 차 있으면 반대 유형만 발생)
	var ev_type: int
	if thief_count >= 1:
		ev_type = MarketDisputeEvent.DisputeType.BRAWL
	elif brawl_count >= 1:
		ev_type = MarketDisputeEvent.DisputeType.PICKPOCKET
	else:
		ev_type = MarketDisputeEvent.DisputeType.BRAWL if randf() < 0.5 else MarketDisputeEvent.DisputeType.PICKPOCKET

	# PORT-TRACE [취객·빈집]: 소매치기는 가게만이 아니라 비틀대는 취객의 주머니나 빈집도 턴다
	var theft_kind := "shop"
	if ev_type == MarketDisputeEvent.DisputeType.PICKPOCKET and citizens != null:
		var tg: Dictionary = citizens.street_theft_target()
		if not tg.is_empty():
			spawn_loc = tg["tile"]
			theft_kind = String(tg["kind"])

	# 이벤트 엔티티 생성
	var new_event := MarketDisputeEvent.new()
	new_event.setup_event(next_event_id, ev_type, spawn_loc, GOLDEN_TIME_LIMIT)
	next_event_id += 1
	active_events.append(new_event)

	# 범죄자 NPC 엔티티 생성
	var crm := CriminalNPC.new()
	var crm_kind: int = CriminalNPC.CriminalKind.DRUNK_BRAWLER if ev_type == MarketDisputeEvent.DisputeType.BRAWL else CriminalNPC.CriminalKind.PICKPOCKET
	crm.setup_criminal(next_criminal_id, crm_kind, spawn_loc, new_event.event_id, grid)
	if crm_kind == CriminalNPC.CriminalKind.PICKPOCKET:
		crm.set_theft_kind(theft_kind)
	crm.is_special_entity = true
	crm.is_always_visible = true
	SpecialEntityManager.register_special(crm)
	next_criminal_id += 1
	active_criminals.append(crm)

	emit_signal("dispute_occurred", "brawl" if ev_type == MarketDisputeEvent.DisputeType.BRAWL else "pickpocket", spawn_loc)

	# 출동 지시: 도둑은 목표 도주 성문 인근 순라청 우선 출동 및 다중 협공, 싸움꾼은 제자리 15초 현장 출동
	if ev_type == MarketDisputeEvent.DisputeType.PICKPOCKET:
		dispatch_police_for_thief(crm, crm.target_gate_pos, new_event)
	else:
		_dispatch_nearest_officer(new_event, grid)

## 도둑 전용 출동: 도둑의 목표 도주 성문(target_gate_pos) 근처 순라청 또는 현장에서 가장 유리한 순라청 선정 (다중 순라청 협공 포위망)
func dispatch_police_for_thief(thief_node: Variant, target_gate_pos: Vector2, event: MarketDisputeEvent = null) -> void:
	if thief_node == null:
		return
	var stations: Array[Vector2i] = patrol_stations
	if stations.is_empty():
		if not gwana_positions.is_empty():
			stations = gwana_positions
		else:
			return

	var best_station: Vector2i = stations[0]
	var best_score: float = 999999.0

	for st in stations:
		var st_pos := Vector2((float(st.x) - float(st.y)) * 32.0, (float(st.x) + float(st.y)) * 16.0)
		var dist_to_thief: float = st_pos.distance_to(thief_node.global_position)
		var dist_to_gate: float = st_pos.distance_to(target_gate_pos)

		# ★ 핵심: 도둑이 도망가는 성문 근처의 순라청에 가중치(0.65배 거리 보너스)를 부여하여
		# 성문 옆 순라청에서 포졸이 튀어나와 도둑의 탈출 길목을 정면으로 가로막게 함!
		var intercept_score: float = minf(dist_to_thief, dist_to_gate * 0.65)
		if intercept_score < best_score:
			best_score = intercept_score
			best_station = st

	var officer: PatrolOfficerNPC = spawn_or_assign_patrol_officer(best_station)
	if officer == null:
		return

	var speed_mult: float = clampf(1.0 + (float(stations.size()) * 0.45), 1.0, 3.0)
	var ev_id: int = event.event_id if event != null else -1
	officer.start_arrest_mission(thief_node, best_station, 1.65 * speed_mult, ev_id)
	if event != null:
		event.assigned_officer_id = officer.id

	# ★ 다중 순라청 협공: 순라청이 2개소 이상이면 성문 길목 차단 외에 도둑 후방 추격 포졸도 함께 출동시켜 포위망 형성!
	if stations.size() >= 2:
		var second_station: Vector2i = stations[0]
		var best_d2: float = 999999.0
		for st2 in stations:
			if st2 == best_station:
				continue
			var st_pos2 := Vector2((float(st2.x) - float(st2.y)) * 32.0, (float(st2.x) + float(st2.y)) * 16.0)
			var d2: float = st_pos2.distance_to(thief_node.global_position)
			if d2 < best_d2:
				best_d2 = d2
				second_station = st2
		var wing_officer: PatrolOfficerNPC = spawn_or_assign_patrol_officer(second_station)
		if wing_officer != null:
			wing_officer.start_arrest_mission(thief_node, second_station, 1.65 * speed_mult, ev_id)

## 가용 포졸 할당 또는 신규 포졸 스폰
func spawn_or_assign_patrol_officer(station_tile: Vector2i) -> PatrolOfficerNPC:
	for off: PatrolOfficerNPC in officer_pool:
		if not off.is_active and off.state == PatrolOfficerNPC.OfficerState.IDLE_PATROL:
			off.home_pos = station_tile
			off.x = float(station_tile.x) + 0.5
			off.y = float(station_tile.y) + 0.5
			return off

	var officer := PatrolOfficerNPC.new()
	officer.setup_officer(next_officer_id, station_tile)
	next_officer_id += 1
	officer_pool.append(officer)
	return officer

## 고착/박제된 노드 및 만료된 범죄 엔티티 일괄 정리
func cleanup_stuck_crime_entities() -> void:
	var rem_crm: Array[CriminalNPC] = []
	for c in active_criminals:
		if c.is_dead or c.lifetime >= 35.0:
			c.resolve_and_remove()
			rem_crm.append(c)
	for rc in rem_crm:
		active_criminals.erase(rc)

	var rem_ev: Array[MarketDisputeEvent] = []
	for ev in active_events:
		if ev.state != MarketDisputeEvent.EventState.ACTIVE or ev.elapsed_time >= 35.0:
			rem_ev.append(ev)
	for re in rem_ev:
		active_events.erase(re)

## 가장 가까운 대기 포졸 2인 1조 배정 및 신속 출동
func _dispatch_nearest_officer(event: MarketDisputeEvent, _grid: GameGrid) -> void:
	# PORT-TRACE [싸움꾼 안 잡음]: 예전엔 놀고 있는 포졸이 풀에 있을 때만 보냈다 — 풀은 도둑 출동 때만 채워져 싸움에는 거의
	# 아무도 오지 않았다. 도둑과 같이, 현장에서 가장 가까운 순라청(없으면 관아)에서 포졸을 불러내 잡으러 보낸다(2인 1조).
	var target_crm: CriminalNPC = null
	for c: CriminalNPC in active_criminals:
		if c.event_id == event.event_id:
			target_crm = c
			break
	if target_crm == null:
		return
	var stations: Array[Vector2i] = patrol_stations if not patrol_stations.is_empty() else gwana_positions
	if stations.is_empty():
		return
	var ev_p := Vector2(event.location)
	var order: Array[Vector2i] = stations.duplicate()
	order.sort_custom(func(p1: Vector2i, p2: Vector2i) -> bool: return Vector2(p1).distance_to(ev_p) < Vector2(p2).distance_to(ev_p))
	var spd: float = clampf(1.0 + float(stations.size()) * 0.45, 1.0, 3.0) * 1.65
	var lead: PatrolOfficerNPC = spawn_or_assign_patrol_officer(order[0])
	if lead == null:
		return
	lead.start_arrest_mission(target_crm, order[0], spd, event.event_id)
	event.assigned_officer_id = lead.id
	var wing: PatrolOfficerNPC = spawn_or_assign_patrol_officer(order[mini(1, order.size() - 1)])
	if wing != null and wing != lead:
		wing.start_arrest_mission(target_crm, order[mini(1, order.size() - 1)], spd, event.event_id)

## 활성 분쟁 이벤트 갱신 및 골든타임 만료 처리
func _update_active_events(
	delta: float,
	sim: SimulationCore,
	_grid: GameGrid,
	_citizens: CitizenManager
) -> void:
	var to_remove: Array[MarketDisputeEvent] = []

	for ev: MarketDisputeEvent in active_events:
		if ev.state == MarketDisputeEvent.EventState.ACTIVE:
			if ev.event_type == MarketDisputeEvent.DisputeType.PICKPOCKET:
				# 도둑 사건: 도둑 엔티티 상태와 실시간 동기화하여 조기 강제 실패 차단
				var target_crm: CriminalNPC = null
				for crm: CriminalNPC in active_criminals:
					if crm.event_id == ev.event_id:
						target_crm = crm
						break

				# 1. 도둑이 이미 포박/압송/수감되었거나 사망한 경우 -> 치안 성공으로 즉시 마감
				if target_crm != null and (target_crm.state in [CriminalNPC.CriminalState.ARRESTED, CriminalNPC.CriminalState.ESCORTED, CriminalNPC.CriminalState.JAILED] or target_crm.is_dead):
					ev.state = MarketDisputeEvent.EventState.SUPPRESSED
					continue

				# 2. 도둑이 실제로 성문/탈출점에 도달해 도주 성공했거나(is_arrestable == false 및 SWAGGER_HOME), 절대 타임아웃(28초) 초과 시 실패
				if (target_crm != null and not target_crm.is_arrestable) or ev.time_left <= 0.0:
					_on_dispute_failed(ev, sim)
					to_remove.append(ev)
					continue

				ev.time_left -= delta
				ev.elapsed_time += delta
			else:
				var res: Dictionary = ev.tick(delta)
				if int(res.get("state", 0)) == MarketDisputeEvent.EventState.FAILED:
					# 치안 골든타임 실패 페널티 발동!
					_on_dispute_failed(ev, sim)
					to_remove.append(ev)
		elif ev.state == MarketDisputeEvent.EventState.COMPLETED or ev.state == MarketDisputeEvent.EventState.FAILED:
			to_remove.append(ev)

	for rem_ev: MarketDisputeEvent in to_remove:
		active_events.erase(rem_ev)

## 치안 골든타임 실패 처리 (시간 초과 또는 순라군 미도착)
func _on_dispute_failed(ev: MarketDisputeEvent, sim: SimulationCore) -> void:
	# 1. 난이도 확인: 쉬움(EASY) 난이도에서는 기존 밸런스 100% 보존 (민심 -2, 세수 -10%)
	var cur_diff: DifficultyManager.Difficulty = DifficultyManager.get_difficulty()
	var is_easy: bool = (cur_diff == DifficultyManager.Difficulty.EASY)

	# 2. 순라청 및 순라군 결핍 검사 (관할 순라군 부재 또는 순라청 0개소)
	var is_patrol_deficit: bool = patrol_stations.is_empty() or ev.assigned_officer_id < 0
	var penalty_mult: float = 1.0
	if not is_easy and is_patrol_deficit:
		penalty_mult = DifficultyManager.get_security_deficit_penalty_multiplier()

	# 3. 화성유수부(관아) 부재 검사 (미완공/미설치 시 수습 불가) — 행궁은 관아를 대신하지 않는다
	var has_gwana: bool = not gwana_positions.is_empty()

	var gwana_deficit_penalty: int = 0
	var is_paralyzed: bool = false
	if not is_easy and not has_gwana:
		gwana_deficit_penalty = 3 # 관아 부재로 수습 불가 추가 민심 -3
		is_paralyzed = true       # 해당 구역 1턴간 상업 마비

	# 4. 민심 피해 차감 (순라청 결핍 배율 및 관아 부재 패널티 합산)
	var base_loyalty_loss: int = int(round(2.0 * penalty_mult))
	var total_loyalty_loss: int = base_loyalty_loss + gwana_deficit_penalty
	
	# 치안 실패 시 피해 10배 확대 (금전, 식량, 인구 유출, 추가 민심 타격)
	var gold_loss: int = 0
	var rice_loss: int = 0
	var pop_loss: int = 0
	if sim != null:
		gold_loss = maxi(200, int(float(sim.gold) * 0.05)) # 금전 유출
		rice_loss = maxi(100, int(float(sim.rice) * 0.04)) # 식량 약탈/소모
		pop_loss = maxi(15, int(float(sim.population) * 0.02)) # 불안으로 인한 인구 이탈
		total_loyalty_loss = maxi(total_loyalty_loss, 6) # 민심 최소 6 이상 급락
		
		sim.gold = maxi(0, sim.gold - gold_loss)
		sim.rice = maxi(0, sim.rice - rice_loss)
		sim.population = maxi(10, sim.population - pop_loss)
		sim.loyalty = maxi(0, sim.loyalty - total_loyalty_loss)

	# 5. 저잣거리 1턴간 세수 감소 페널티 적용 (기본 10% * 배율, 관아 부재 시 마비)
	var tax_loss_rate: float = clampf(0.10 * penalty_mult, 0.10, 0.50)
	MarketManager.apply_dispute_penalty(tax_loss_rate, is_paralyzed)

	# 6. 범죄자 미체포 성공 연출 발동 (도둑 팔자걸음 귀가 / 싸움꾼 승리 포즈 및 피해자 후송)
	for crm: CriminalNPC in active_criminals:
		if crm.event_id == ev.event_id:
			crm.on_crime_succeeded_unchecked()

	# 7. 배정되었던 포졸이 있다면 추격 포기 및 순라청 복귀 ("놓쳤구만! 순라청을 더 늘려야겠어!")
	if ev.assigned_officer_id >= 0:
		for off: PatrolOfficerNPC in officer_pool:
			if off.id == ev.assigned_officer_id:
				off.on_target_escaped()


	# 8. 비변사 / 치안 경보 알림 발령
	var alert_text: String = ""
	if not has_gwana and not is_easy:
		alert_text = "[치안 붕괴] 관아 부재 및 순라군 미도착으로 저잣거리 대참사! (금화 -%d, 곡식 -%d, 인구 -%d, 민심 -%d)" % [gold_loss, rice_loss, pop_loss, total_loyalty_loss]
	elif is_patrol_deficit and not is_easy:
		alert_text = "[치안 참사 경보] 순라청 부재로 범죄가 걷잡을 수 없이 확산되었습니다! (금화 -%d, 곡식 -%d, 인구 -%d, 민심 -%d)" % [gold_loss, rice_loss, pop_loss, total_loyalty_loss]
	else:
		alert_text = "[치안 방치 참사] 30초 내 순라군이 미도달하여 피해가 10배 확대되었습니다! (금화 -%d냥, 곡식 -%d석, 인구 -%d명, 민심 -%d)" % [gold_loss, rice_loss, pop_loss, total_loyalty_loss]

	emit_signal("security_alert", alert_text)
	emit_signal("dispute_resolved", "brawl" if ev.event_type == MarketDisputeEvent.DisputeType.BRAWL else "pickpocket", false, ev.location)
	crime_cooldown_timer = CRIME_COOLDOWN_TIME # 사건 종료 후 최소 40초 쿨타임 발동

## 순라군 FSM 업데이트
func _update_officers(delta: float, grid: GameGrid, citizens: CitizenManager) -> void:
	var gw_pos: Vector2i = _get_best_gwana_pos(citizens)

	for off: PatrolOfficerNPC in officer_pool:
		if not off.is_active:
			continue

		var tick_res: Dictionary = off.update(delta)

		# 1. 분쟁 현장 도착
		if bool(tick_res.get("reached_target", false)):
			var ev: MarketDisputeEvent = _find_event(off.target_event_id)
			if ev == null and off.target_crime_node != null and "event_id" in off.target_crime_node:
				ev = _find_event(int(off.target_crime_node.event_id))
			if ev != null and ev.state == MarketDisputeEvent.EventState.ACTIVE:
				ev.state = MarketDisputeEvent.EventState.SUPPRESSED
				ev.is_officer_arrived = true
				off.state = PatrolOfficerNPC.OfficerState.SUPPRESS
				off.bubble_text = "물러서라! 순라군이 진압한다!"
				off.bubble_timer = 2.5

				# 해당 사건 범죄자 체포 상태 전이
				for crm: CriminalNPC in active_criminals:
					if crm.event_id == ev.event_id:
						crm.state = CriminalNPC.CriminalState.ARRESTED
						crm.bubble_text = "으악! 살려주시오!"
						crm.bubble_timer = 2.0

		# 2. 진압 완료 (육모방망이 액션 종료 후 분기)
		if bool(tick_res.get("suppress_done", false)):
			var ev2: MarketDisputeEvent = _find_event(off.target_event_id)
			if ev2 == null and off.target_crime_node != null and "event_id" in off.target_crime_node:
				ev2 = _find_event(int(off.target_crime_node.event_id))
			if ev2 != null:
				_resolve_dispute_success(ev2, off, gw_pos, grid)

		# 3. 관아 정문 도착 (압송 완료)
		if bool(tick_res.get("reached_gwana", false)):
			# 결박된 범죄자 관아 옥사로 입고 및 디스폰
			for crm: CriminalNPC in active_criminals:
				if crm.tied_officer_id == off.id:
					crm.state = CriminalNPC.CriminalState.JAILED
					crm.is_dead = true
					emit_signal("criminal_jailed", "pickpocket")

			# 포졸은 순라청으로 복귀
			var ret_path: Array[Vector2i] = _find_grid_path(Vector2i(int(off.x), int(off.y)), off.home_pos, grid)
			off.return_to_base(ret_path)

## 진압 성공 처리 (도둑·난동꾼 모두 오라줄 결박 후 화성유수부 관아 압송 완성)
func _resolve_dispute_success(
	ev: MarketDisputeEvent,
	off: PatrolOfficerNPC,
	gw_pos: Vector2i,
	grid: GameGrid
) -> void:
	ev.state = MarketDisputeEvent.EventState.COMPLETED
	crime_cooldown_timer = CRIME_COOLDOWN_TIME # 사건 해결 후 최소 40초 쿨타임 발동

	# 민심 +1 상승
	CityStats.add_morale(1)
	if instance != null and CourtSystem.SCHOLARS != null:
		var sim_node: SimulationCore = null
		if Engine.has_singleton("SimulationCore"):
			sim_node = Engine.get_singleton("SimulationCore")
		if sim_node != null:
			sim_node.loyalty = mini(100, sim_node.loyalty + 1)

	var target_crm: CriminalNPC = null
	for crm: CriminalNPC in active_criminals:
		if crm.event_id == ev.event_id:
			target_crm = crm
			crm.state = CriminalNPC.CriminalState.ESCORTED
			crm.tied_officer_id = off.id
			if ev.event_type == MarketDisputeEvent.DisputeType.BRAWL:
				crm.bubble_text = "술이 원수요... 관아에서 죗값을 치르겠소..."
			else:
				crm.bubble_text = "이놈의 손목을 원망해야지... 흑흑"
			crm.bubble_timer = 4.0

	var escort_path: Array[Vector2i] = _find_grid_path(Vector2i(int(off.x), int(off.y)), gw_pos, grid)
	off.start_escort(ev.event_id, gw_pos, escort_path, target_crm)
	emit_signal("dispute_resolved", "brawl" if ev.event_type == MarketDisputeEvent.DisputeType.BRAWL else "pickpocket", true, ev.location)

## 범죄자 엔티티 갱신
func _update_criminals(delta: float) -> void:
	var dead_list: Array[CriminalNPC] = []

	for crm: CriminalNPC in active_criminals:
		var leader_pos := Vector2.ZERO
		if crm.state == CriminalNPC.CriminalState.ESCORTED and crm.tied_officer_id >= 0:
			for off: PatrolOfficerNPC in officer_pool:
				if off.id == crm.tied_officer_id:
					leader_pos = Vector2(off.x, off.y)
					break

		crm.update(delta, leader_pos)
		if crm.is_dead:
			dead_list.append(crm)

	for dc: CriminalNPC in dead_list:
		active_criminals.erase(dc)

## 이벤트 ID로 이벤트 검색
func _find_event(e_id: int) -> MarketDisputeEvent:
	for ev: MarketDisputeEvent in active_events:
		if ev.event_id == e_id:
			return ev
	return null

## 압송한 죄인이 관아(관아가 없으면 순라청)에 닿았다. 관아가 없거나 옥이 가득 찼으면 20% 확률로 오랏줄을 풀고
## 다시 도둑이 되어 달아난다(true). 아니면 관아 마당에서 문초한 뒤 옥에 가둔다.
func on_prisoner_delivered(crm: CriminalNPC) -> bool:
	if crm == null or crm.is_dead or not (crm.state in [CriminalNPC.CriminalState.ARRESTED, CriminalNPC.CriminalState.ESCORTED]):
		return false
	var no_gwana: bool = gwana_positions.is_empty()
	var full: bool = not no_gwana and _jail_full()
	if (no_gwana or full) and randf() < PRISON_ESCAPE_CHANCE:
		_prisoner_escape(crm, no_gwana)
		return true
	if not no_gwana and _cm_ref != null:
		var here := Vector2i(int(floor(crm.x)), int(floor(crm.y)))
		var best: Vector2i = gwana_positions[0]
		for gw: Vector2i in gwana_positions:
			if absi(gw.x - here.x) + absi(gw.y - here.y) < absi(best.x - here.x) + absi(best.y - here.y):
				best = gw
		_cm_ref._start_trial(best, "thief") # 문초가 끝나면 옥사(gw_prisoners)에 갇힌다
	return false

## 고을의 관아 옥사가 모두 찼나
func _jail_full() -> bool:
	if _grid_ref == null:
		return false
	for gw: Vector2i in gwana_positions:
		if _grid_ref.in_bounds(gw.x, gw.y) and int(_grid_ref.grid[gw.y][gw.x].get("gw_prisoners", 0)) < JAIL_CAPACITY:
			return false
	return true

## 탈옥: 죄인이 그 자리에서 다시 도둑이 되어 성문(또는 성 밖)으로 달아나고, 새 도둑 사건으로 포졸이 다시 쫓는다
func _prisoner_escape(crm: CriminalNPC, no_gwana: bool) -> void:
	var tile := Vector2i(int(floor(crm.x)), int(floor(crm.y)))
	var ev := MarketDisputeEvent.new()
	ev.setup_event(next_event_id, MarketDisputeEvent.DisputeType.PICKPOCKET, tile, GOLDEN_TIME_LIMIT)
	next_event_id += 1
	active_events.append(ev)
	crm.kind = CriminalNPC.CriminalKind.PICKPOCKET
	crm.event_id = ev.event_id
	crm.tied_officer_id = -1
	crm.lifetime = 0.0
	crm.speed = 2.0
	crm.is_dead = false
	crm.target_gate_pos = BuildingManager.get_thief_escape_target_world_pos(crm.global_position, _grid_ref)
	crm.home_target_pos = crm.target_gate_pos
	crm._start_swagger_escape()
	crm.has_loot_sack = false
	crm.merchant_x = crm.x - 0.3
	crm.merchant_y = crm.y
	crm.victim_bubble = ""
	crm.bubble_text = "오랏줄이 풀렸다! 걸음아 날 살려라!"
	crm.bubble_timer = 3.0
	if no_gwana:
		emit_signal("security_alert", "[탈옥] 고을에 관아가 없어 가둘 곳을 찾던 죄인이 오랏줄을 풀고 달아났습니다! 관아를 지으십시오.")
	else:
		emit_signal("security_alert", "[탈옥] 관아 옥사가 가득 차 미처 가두지 못한 죄인이 오랏줄을 풀고 달아났습니다!")
	dispatch_police_for_thief(crm, crm.target_gate_pos, ev)

## 가장 가까운 관아 위치 조회
func _get_best_gwana_pos(citizens: CitizenManager) -> Vector2i:
	if citizens != null and not citizens._gwana_cache.is_empty():
		return citizens._gwana_cache[0]
	if not gwana_positions.is_empty():
		return gwana_positions[0]
	return Vector2i(20, 20)

## 단순 그리드 경로 생성 (쓰로틀링 A* 또는 직선 맨해튼 경로)
func _find_grid_path(start: Vector2i, dest: Vector2i, _grid: GameGrid) -> Array[Vector2i]:
	if PatrolOfficerNPC.path_provider.is_valid():
		var pp: Array[Vector2i] = PatrolOfficerNPC.path_provider.call(start, dest)
		if not pp.is_empty():
			return pp
	var result_path: Array[Vector2i] = []
	var cur: Vector2i = start

	var max_steps: int = 60
	var steps: int = 0

	while cur != dest and steps < max_steps:
		steps += 1
		var dx: int = dest.x - cur.x
		var dy: int = dest.y - cur.y

		if absi(dx) >= absi(dy) and dx != 0:
			cur.x += 1 if dx > 0 else -1
		elif dy != 0:
			cur.y += 1 if dy > 0 else -1
		else:
			break

		result_path.append(cur)

	return result_path

## 순라청 개수 기반 출동 속도 산출 (순라청 개수 비례 1.0 + count * 0.4, 최대 3.0배)
func get_patrol_dispatch_speed() -> float:
	var count: int = patrol_stations.size()
	return clampf(1.0 + (float(count) * 0.4), 1.0, 3.0)


## 특정 위치에서 가장 가까운 순라청(또는 관아 fallback) 위치 반환
func get_nearest_patrol_station(pos: Vector2i) -> Vector2i:
	if not patrol_stations.is_empty():
		var best_station: Vector2i = patrol_stations[0]
		var best_d: float = Vector2(best_station).distance_to(Vector2(pos))
		for i in range(1, patrol_stations.size()):
			var st: Vector2i = patrol_stations[i]
			var d: float = Vector2(st).distance_to(Vector2(pos))
			if d < best_d:
				best_d = d
				best_station = st
		return best_station
	elif not gwana_positions.is_empty():
		return gwana_positions[0]
	return Vector2i(20, 20)

## 순라청 1개소당 기본 도시 국방력 +30 기여 계산
func get_patrol_defense_power() -> int:
	return patrol_stations.size() * 30

## 도적 침입 시 순라군 요격 방어 활성화 여부
func is_patrol_defending() -> bool:
	return not patrol_stations.is_empty() and not officer_pool.is_empty()

