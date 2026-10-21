extends Node
class_name SiegeDefenseManager

## [화성행궁 종심 방어 및 전술 길목 차단 전투 체계 총괄 매니저]
## 1. 화성행궁 최종 목표 타깃팅 및 경로 이동 (A* Pathfinding):
##    - 도적/반란군의 최종 목적지를 화성행궁 본궁(7x7)으로 고정
##    - 성곽과 성문 저지선 타격/돌파 후 성내 도로망을 따라 행궁으로 진격
## 2. 장용영 군대의 길목 배치 및 실시간 교전 애니메이션:
##    - 연무대/서장대/행궁에서 출격한 장용영 군대가 진격로 길목에 방어선 형성
##    - 적군과 접촉 시 도트 교전 애니메이션(칼, 창, 조총, 화약 연막) 실행
##    - 전투력 비교 판정: 승리 시 적군 궤멸 및 승전보, 패배 시 방어선 붕괴 및 행궁 돌진
## 3. 진격로 약탈 및 민가/저잣거리 폐가화(Ruins) 동역학:
##    - 적군이 지나가는 경로의 상점과 민가는 즉시 불타는 폐가(RUINED)로 전환
##    - 진압되기 전까지 세수/식량 0 및 도시 전체 인구 -1% 유출
##    - 진압 완료 후 2~3턴에 걸쳐 본래 건물로 점진 복구/재건
## 4. 적군 최소 공격력 500 상향 및 스케일링 공식 엄격 보장

@warning_ignore("unused_signal")
signal battle_started(kind: String, attack_power: int, ally_power: int, location: Vector2i)
@warning_ignore("unused_signal")
signal combat_engaged(location: Vector2i)
@warning_ignore("unused_signal")
signal battle_resolved(victory: bool, msg: String)
@warning_ignore("unused_signal")
signal palace_breached(enemy_kind: String)

static var instance: SiegeDefenseManager = null
static var is_active_invasion: bool = false
static var is_under_attack: bool = false

var sim: SimulationCore = null
var grid: GameGrid = null
var citizens: CitizenManager = null
var time_mgr: TimeManager = null

var is_battle_active: bool = false
var battle_kind: String = "bandit" # "bandit" or "rebel"
var enemy_attack_power: int = 500
var ally_defense_power: int = 500

var enemy_squads: Array[EnemyMarcherEntity] = []
var ally_squads: Array[JangyongyeongUnitEntity] = []

var haenggung_palace_pos: Vector2i = Vector2i(14, 29)
var active_gate_pos: Vector2i = Vector2i(-1, -1)
var bottleneck_pos: Vector2i = Vector2i(-1, -1)

var combat_elapsed: float = 0.0
var is_combat_ongoing_flag: bool = false
var current_combat_world_pos: Vector2 = Vector2.ZERO

func _init() -> void:
	name = "SiegeDefenseManager"
	process_mode = Node.PROCESS_MODE_ALWAYS
	SiegeDefenseManager.instance = self

func setup(s: SimulationCore, g: GameGrid, c: CitizenManager, tm: TimeManager) -> void:
	sim = s
	grid = g
	citizens = c
	time_mgr = tm
	SiegeDefenseManager.instance = self
	if grid != null:
		haenggung_palace_pos = grid.find_haenggung_center()

## 침공 및 종심 방어전 개시
func start_invasion(kind_str: String = "bandit", force_atk: int = -1) -> Dictionary:
	if is_battle_active:
		return {"active": true, "msg": "이미 교전이 진행 중입니다."}

	is_battle_active = true
	SiegeDefenseManager.is_active_invasion = true
	SiegeDefenseManager.is_under_attack = true
	battle_kind = kind_str
	combat_elapsed = 0.0
	is_combat_ongoing_flag = false
	enemy_squads.clear()
	ally_squads.clear()

	# 1. 행궁 본궁 중심점 탐색
	if grid != null:
		haenggung_palace_pos = grid.find_haenggung_center()

	# 2. 적군 공격력 산출 (최소 500 상한 보장)
	if force_atk > 0:
		enemy_attack_power = maxi(500, force_atk)
	elif battle_kind == "rebel":
		enemy_attack_power = RebellionManager.calculate_rebel_siege_atk(sim)
	else:
		enemy_attack_power = BanditManager.calculate_bandit_siege_atk(sim)

	# 3. 장용영 유효 방어력 산출
	ally_defense_power = BanditManager.calculate_ally_combat_power(sim, grid)
	if CityStats.get_military_attack_power() > ally_defense_power:
		ally_defense_power = CityStats.get_military_attack_power()

	# 4. 스폰 지점 및 최근접 성문/성곽 탐색
	var spawn_tile := _find_enemy_spawn_tile()
	active_gate_pos = _find_closest_gate(spawn_tile)

	# 5. 성문 -> 화성행궁 본궁 A* 진격 경로 사전 계산
	var inner_path: Array[Vector2i] = []
	if grid != null:
		inner_path = grid.find_march_path_to_haenggung(active_gate_pos)
	else:
		inner_path = [haenggung_palace_pos]

	# 6. 전술 길목(Bottleneck) 요격 지점 선정 (경로의 40~50% 지점 교차로)
	bottleneck_pos = _find_bottleneck_tile(inner_path)

	# 7. 적군 분대 인스턴싱 (1~2개 분대, 분대당 4명)
	var squad_count: int = 1 if enemy_attack_power <= 650 else 2
	for sq_idx: int in range(squad_count):
		var marcher := EnemyMarcherEntity.new()
		var marcher_spawn: Vector2i = spawn_tile + Vector2i(sq_idx * 2, sq_idx)
		marcher.setup_marcher(
			100 + sq_idx,
			marcher_spawn,
			active_gate_pos,
			haenggung_palace_pos,
			enemy_attack_power,
			battle_kind
		)
		marcher.march_path = inner_path
		enemy_squads.append(marcher)

	# 8. 장용영 요격 분대 인스턴싱 (연무대/서장대/행궁에서 길목으로 출동)
	var troop_base: Vector2i = _find_troop_base_tile()
	for tr_idx: int in range(squad_count):
		var squad := JangyongyeongUnitEntity.new()
		var tr_spawn: Vector2i = troop_base + Vector2i(tr_idx * 2, tr_idx)
		squad.setup_unit(
			200 + tr_idx,
			tr_spawn,
			bottleneck_pos,
			ally_defense_power
		)
		ally_squads.append(squad)

	# 9. 카메라 포커스 및 HUD 알림
	var loc_name: String = "화성 외곽 방어선"
	if active_gate_pos.x >= 0 and grid != null:
		var b_name: String = str(grid.grid[active_gate_pos.y][active_gate_pos.x].get("building", ""))
		if b_name != "":
			loc_name = "%s 앞 방어선" % b_name

	current_combat_world_pos = _tile_to_world(bottleneck_pos)
	emit_signal("battle_started", battle_kind, enemy_attack_power, ally_defense_power, bottleneck_pos)

	if citizens != null:
		citizens.bandit_battle_started.emit(current_combat_world_pos, loc_name)

	return {
		"kind": battle_kind,
		"enemy_atk": enemy_attack_power,
		"ally_def": ally_defense_power,
		"gate": active_gate_pos,
		"bottleneck": bottleneck_pos
	}

func _process(delta: float) -> void:
	if not is_battle_active:
		return

	# 일시정지 상태 확인
	if time_mgr != null and time_mgr.current_speed == TimeManager.SpeedMode.PAUSE:
		return

	var all_enemies_dead: bool = true
	var any_combat: bool = false

	# 적군 분대 업데이트
	for e: EnemyMarcherEntity in enemy_squads:
		if e == null or e.is_dead:
			continue
		all_enemies_dead = false
		e.update(delta, grid, sim, self)
		if e.state == EnemyMarcherEntity.STATE_COMBAT:
			any_combat = true
			current_combat_world_pos = _tile_to_world(Vector2i(int(floor(e.pos.x)), int(floor(e.pos.y))))

	# 장용영 요격 분대 업데이트
	for a: JangyongyeongUnitEntity in ally_squads:
		if a == null or a.is_dead:
			continue
		a.update(delta, enemy_squads, self)
		if a.state == JangyongyeongUnitEntity.STATE_COMBAT:
			any_combat = true

	is_combat_ongoing_flag = any_combat

	# 모든 적군 소멸 시 승리 처리
	if all_enemies_dead and not enemy_squads.is_empty():
		_on_combat_finished(true)

## 교전 종결 처리 (아군 승리 vs 패배)
func _on_combat_finished(victory: bool) -> void:
	if not is_battle_active:
		return

	is_battle_active = false
	SiegeDefenseManager.is_active_invasion = false
	SiegeDefenseManager.is_under_attack = false
	is_combat_ongoing_flag = false

	if victory:
		# 승리: 적군 소멸 및 전리품/민심 상승, 폐가 복구 개시
		var restored: int = 0
		if grid != null:
			restored = BuildingManager.restore_ruined_buildings(grid, sim)

		if sim != null:
			sim.loyalty = mini(100, sim.loyalty + 5)
			sim.bandit_active = false
			sim.bandit_suppression_turns = 24 # 2년(24개월)간 안전 보장

		var msg: String = "⚔️ [장용영 승전보] 장용영 정예군이 적의 진격을 완벽히 저지하고 궤멸시켰습니다! (민심 +5, 피해 건물 %d개소 재건 개시)" % restored
		emit_signal("battle_resolved", true, msg)

		if citizens != null:
			citizens.bandit_battle_ended.emit(true)
	else:
		# 패배: 장용영 방어선 붕괴, 적군이 행궁으로 돌진하도록 허용
		var msg_loss: String = "⚠️ [방어선 붕괴] 장용영 요격선이 뚫려 적군이 화성행궁 본궁을 향해 쇄도하고 있습니다!"
		emit_signal("battle_resolved", false, msg_loss)

## 화성행궁 본궁 도달 시 도시 함락 엔딩 시퀀스 강제 발화
func _trigger_palace_fall() -> void:
	if not is_battle_active:
		return

	is_battle_active = false
	SiegeDefenseManager.is_active_invasion = false
	SiegeDefenseManager.is_under_attack = false
	is_combat_ongoing_flag = false

	print_debug("[SiegeDefenseManager] 적군 화성행궁 본궁 타일 도달 확인 -> 함락 엔딩 트리거!")

	# 시뮬레이션 일시 정지
	if time_mgr != null:
		time_mgr.set_speed(TimeManager.SpeedMode.PAUSE)

	emit_signal("palace_breached", battle_kind)

	var ending_key: String = "FALLEN_TO_BANDITS"
	if battle_kind == "rebel":
		var royal_val: int = CityStats.get_royal_power()
		if sim != null:
			royal_val = sim.authority
		ending_key = "COUP_DETAT" if royal_val < 20 else "FALLEN_CITY"

	EndingManager.trigger_ending(ending_key)

## 전술 길목(Bottleneck) 탐색: 진격 경로의 중간 교차로 또는 행궁 앞 진입로
func _find_bottleneck_tile(path: Array[Vector2i]) -> Vector2i:
	if path.is_empty():
		return haenggung_palace_pos
	if path.size() <= 2:
		return path[0]

	# 경로의 40~50% 지점을 길목으로 지정
	var mid_idx: int = int(float(path.size()) * 0.45)
	mid_idx = clampi(mid_idx, 0, path.size() - 1)
	return path[mid_idx]

## 스폰 지점에서 가장 가까운 성문 탐색
func _find_closest_gate(from_pt: Vector2i) -> Vector2i:
	if citizens != null and not citizens._gate_cache.is_empty():
		var best: Vector2i = citizens._gate_cache[0]
		var min_d: int = 9999
		for g: Vector2i in citizens._gate_cache:
			var d: int = absi(g.x - from_pt.x) + absi(g.y - from_pt.y)
			if d < min_d:
				min_d = d
				best = g
		return best

	# 성문 캐시가 없는 경우 맵 중심 기준 4대문 기본 좌표
	return Vector2i(32, 10)

## 적군 스폰 지점 탐색
func _find_enemy_spawn_tile() -> Vector2i:
	if citizens != null:
		var camp: Vector2i = citizens.get_bandit_camp_pos()
		if camp.x >= 0 and grid != null and grid.in_bounds(camp.x, camp.y):
			return camp
	return Vector2i(2, 8)

## 장용영 출동 기지 (연무대, 서장대, 행궁, 순라청 우선)
func _find_troop_base_tile() -> Vector2i:
	if grid != null:
		var ym := grid.find_building_anchor("yeonmudae")
		if ym.x >= 0: return ym
		var sj := grid.find_building_anchor("seojangdae")
		if sj.x >= 0: return sj
		var pt := grid.find_building_anchor("patrol")
		if pt.x >= 0: return pt
	return haenggung_palace_pos

## 타일 좌표를 월드 좌표로 변환
func _tile_to_world(t_pos: Vector2i) -> Vector2:
	if citizens != null and citizens.city != null:
		var elev: float = 0.0
		if grid != null and grid.in_bounds(t_pos.x, t_pos.y):
			elev = float(grid.grid[t_pos.y][t_pos.x].get("elevation", 0.0))
		return citizens.city.cell_center(float(t_pos.x) + 0.5, float(t_pos.y) + 0.5, elev)
	return Vector2((float(t_pos.x) - float(t_pos.y)) * 32.0, (float(t_pos.x) + float(t_pos.y)) * 16.0)

func is_combat_ongoing() -> bool:
	return is_combat_ongoing_flag

func get_active_combat_point() -> Vector2:
	return current_combat_world_pos

func get_enemy_squads() -> Array[EnemyMarcherEntity]:
	return enemy_squads

func get_ally_squads() -> Array[JangyongyeongUnitEntity]:
	return ally_squads
