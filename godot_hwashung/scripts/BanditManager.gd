extends RefCounted
class_name BanditManager

## [왕권 연동 도적 침입 및 장용영 요격 공방전 오케스트레이터]
## 1. 왕권 수치 연동 AI 분기:
##    - 왕권 >= 30: AI_STATE_RAID_OUTSKIRTS (외곽 민가 2~3채 약탈 후 도주)
##    - 왕권 < 30: AI_STATE_ASSAULT_PALACE (화성행궁 본궁을 최종 목표로 직격 진격)
## 2. 장애물 돌파 및 성벽 타격:
##    - 성곽/성문 접촉 시 attack_wall 상태로 성 방호력 초당 차감 (방호력 0 시 성내 난입)
## 3. 실시간 약탈:
##    - 경로상 민가/상점에 is_looted 부여 (비파괴적, 불꽃/연기 연출, 국고/식량 유출)
## 4. 장용영 요격 및 교전:
##    - 행궁/군영에서 정예 분대 5~10명 긴급 출동
##    - 0.2초 틱 스로틀링 교전: 초당 도적 피해량 = (장용영 총 공격력) / 5
## 5. 결과 라이프사이클:
##    - 승리: 도적 체력 0 도달 시 포박 후 관아 옥사로 압송 (prisoner_escort), 민심 +5, 8턴 평온 버프
##    - 패배: 방호력 소진 및 도적이 행궁 본궁 도달 시 EndingManager 호출하여 게임 오버

const AI_STATE_RAID_OUTSKIRTS: String = "outskirts"
const AI_STATE_ASSAULT_PALACE: String = "assault_palace"

const DEFAULT_BANDIT_SIEGE_HP: int = 500
const DEFAULT_BANDIT_SIEGE_ATK: int = 500
const INITIAL_BANDIT_SIEGE_ATK: int = 500
const COMBAT_TICK_RATE: float = 0.2 # 0.2초 스로틀링 틱

## 민심 연동 도적 침공 공격력 산출
## 기본 최소 공격력 500 보장 및 스케일링 공식:
## 도적 전투력 = 500 + max(0, 50 - 민심) * 8 + (방치 연수 * 25)
static func calculate_bandit_siege_atk(sim: SimulationCore, years_ignored: int = 0) -> int:
	if sim == null:
		return INITIAL_BANDIT_SIEGE_ATK
	var loy: int = clampi(sim.loyalty, 0, 100)
	var loy_deficit: int = maxi(0, 50 - loy)
	var ignored_y: int = years_ignored
	if ignored_y <= 0 and ("turn" in sim):
		ignored_y = maxi(0, int(float(sim.turn) / 4.0))
	var atk: int = INITIAL_BANDIT_SIEGE_ATK + (loy_deficit * 8) + (ignored_y * 25)
	return maxi(500, atk)

var is_raid_active: bool = false
var raid_mode: String = AI_STATE_RAID_OUTSKIRTS
var bandit_siege_hp: int = 500
var bandit_siege_max_hp: int = 500
var bandit_siege_atk: int = 300

var raid_duration: float = 0.0
var combat_tick_timer: float = 0.0
var wall_attack_tick_timer: float = 0.0

var primary_target: Vector2i = Vector2i.ZERO
var haenggung_palace_pos: Vector2i = Vector2i(24, 28)
var bandit_camp_pos: Vector2i = Vector2i(4, 8)

var bandits: Array[BanditEntity] = []
var troops: Array[JangyongyeongTroop] = []

var captured_count: int = 0
var looted_tiles: Dictionary = {} # {Vector2i: float (남은 시간)}

## [동적 도적 소굴 및 유수부 토벌 상태 관리]
var camps: Array[Dictionary] = [] # [{ "id": int, "pos": Vector2i, "combat_power": int, "age_turns": int }]
var outer_empty_tiles: Array[Vector2i] = [] # 성곽 외부 공터 캐시
var subjugation_cooldown_turns: int = 0 # 유수부 출동 쿨다운(개월) — 출동 시 12 → 1년에 1회 출동
var loot_immune_turns: int = 0 # 약탈 후 1년(12개월) 면역 타이머
var siege_warning_turns: int = 0 # 도적 총전투력 > 국방력 * 1.5 상태 방치 개월 수
var last_spawn_year: int = -1 # 연간 최대 1회 스폰 가드
var next_camp_id: int = 1

func has_active_bandits() -> bool:
	return is_raid_active or bandits.size() > 0 or camps.size() > 0

## 침입 시작
func start_raid(
	sim: SimulationCore,
	grid: GameGrid,
	citizens: CitizenManager,
	force_mode: String = ""
) -> Dictionary:
	is_raid_active = true
	raid_duration = 0.0
	combat_tick_timer = 0.0
	wall_attack_tick_timer = 0.0
	captured_count = 0
	bandit_siege_hp = DEFAULT_BANDIT_SIEGE_HP
	bandit_siege_max_hp = DEFAULT_BANDIT_SIEGE_HP
	bandit_siege_atk = calculate_bandit_siege_atk(sim)
	bandits.clear()
	troops.clear()

	# 행궁 중심점 탐색
	haenggung_palace_pos = _find_haenggung_pos(grid, citizens)
	if not camps.is_empty():
		bandit_camp_pos = camps[0].get("pos", Vector2i(4, 8))
	elif citizens != null:
		var cp: Vector2i = citizens.get_bandit_camp_pos()
		bandit_camp_pos = cp if cp.x >= 0 else Vector2i(4, 8)
	else:
		bandit_camp_pos = Vector2i(4, 8)

	# 1. 왕권 수치 검사 (30 이상 vs 30 미만)
	var royal_val: int = CityStats.get_royal_power()
	if sim:
		royal_val = sim.authority

	if force_mode != "":
		raid_mode = force_mode
	else:
		raid_mode = AI_STATE_RAID_OUTSKIRTS if royal_val >= 30 else AI_STATE_ASSAULT_PALACE

	# 2. 목표 지점 결정
	if raid_mode == AI_STATE_RAID_OUTSKIRTS:
		primary_target = _find_outskirts_target(grid, citizens)
	else:
		primary_target = haenggung_palace_pos

	# 3. 도적/반란군 엔티티 스폰 (10명 이상 편성)
	var bandit_mode_enum: int = BanditEntity.Mode.OUTSKIRTS if raid_mode == AI_STATE_RAID_OUTSKIRTS else BanditEntity.Mode.ASSAULT_PALACE
	var bandit_count: int = 10 if raid_mode == AI_STATE_RAID_OUTSKIRTS else 14
	for i in range(bandit_count):
		var b_entity := BanditEntity.new()
		var sp_offset := Vector2i(randi_range(-1, 1), randi_range(-1, 1))
		var sp := bandit_camp_pos + sp_offset
		b_entity.setup_bandit(1000 + i, sp, primary_target, bandit_camp_pos, bandit_mode_enum, 4)
		SpecialEntityManager.mark_special(b_entity)
		bandits.append(b_entity)
		if citizens:
			var ag_dict: Dictionary = b_entity.to_agent_dict()
			# 병종 배정: 화포/조총(gunner), 활(archer), 칼/창(blade)
			var w_type: String = "gunner" if i % 3 == 0 else ("archer" if i % 3 == 1 else "blade")
			ag_dict["weapon_type"] = w_type
			SpecialEntityManager.mark_special(ag_dict)
			citizens.agents.append(ag_dict)

	# 4. 장용영 정예 요격 부대 출동 (10~12명 편성, 조총/활/환도 삼수병 편제)
	var troop_base: Vector2i = _find_troop_spawn_base(grid, citizens)
	var troop_count: int = 10 if raid_mode == AI_STATE_RAID_OUTSKIRTS else 12
	for j in range(troop_count):
		var t_entity := JangyongyeongTroop.new()
		var tr_offset := Vector2i(randi_range(-1, 1), randi_range(-1, 1))
		var tr_sp := troop_base + tr_offset
		t_entity.setup_troop(2000 + j, tr_sp, primary_target, j == 0) # 0번은 선두 깃발병
		SpecialEntityManager.mark_special(t_entity)
		troops.append(t_entity)
		if citizens:
			var tr_dict: Dictionary = t_entity.to_agent_dict()
			var tw_type: String = "gunner" if j % 3 == 0 else ("archer" if j % 3 == 1 else "blade")
			tr_dict["weapon_type"] = tw_type
			SpecialEntityManager.mark_special(tr_dict)
			citizens.agents.append(tr_dict)

	if sim:
		sim.bandit_active = true
		sim.bandit_raid_started.emit(primary_target)
	if citizens:
		var battle_wpos: Vector2 = citizens.get_current_battle_world_pos()
		var loc_name: String = citizens.get_current_battle_location_name()
		citizens.bandit_battle_started.emit(battle_wpos, loc_name)

	var alert_msg: String = ""
	if raid_mode == AI_STATE_RAID_OUTSKIRTS:
		alert_msg = "화적 떼가 외곽 민가와 둔전을 약탈하러 출몰했습니다! 장용영 군사가 출동합니다."
	else:
		alert_msg = "비상 경보: 왕권 실추를 틈타 대규모 반란 도적 떼가 화성행궁 본궁을 향해 맹렬히 진격하고 있습니다!"

	return {
		"mode": raid_mode,
		"royal_power": royal_val,
		"target": primary_target,
		"bandit_count": bandit_count,
		"troop_count": troop_count,
		"msg": alert_msg
	}

## 틱 업데이트 (0.2초 스로틀링)
func update_raid(delta: float, sim: SimulationCore, grid: GameGrid, citizens: CitizenManager) -> Dictionary:
	if not is_raid_active:
		return {"active": false}

	raid_duration += delta
	combat_tick_timer += delta
	wall_attack_tick_timer += delta

	# 약탈 타일 타이머 관리
	_update_looted_tiles(delta, grid)

	# 0.2초 주기 교전 및 FSM 연산
	if combat_tick_timer < COMBAT_TICK_RATE:
		return {
			"active": true,
			"mode": raid_mode,
			"bandit_hp": bandit_siege_hp,
			"defense_power": CityStats.get_fortress_defense_power()
		}

	combat_tick_timer = 0.0

	var current_defense: int = CityStats.get_fortress_defense_power()
	var ally_attack: int = CityStats.get_military_attack_power()

	# 활성 도적 및 장용영 에이전트 조회
	var live_bandits: Array[Dictionary] = []
	var live_troops: Array[Dictionary] = []
	if citizens:
		live_bandits = citizens.agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "bandit" and not a.get("is_dead", false))
		live_troops = citizens.agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "jangyongyeong_soldier" and not a.get("is_dead", false))

	if live_bandits.is_empty():
		return finish_raid(true, sim, grid, citizens)

	# 도적 무리 중심점 계산
	var _bandit_center := Vector2.ZERO
	for b in live_bandits:
		_bandit_center += Vector2(float(b.get("x", 0.0)), float(b.get("y", 0.0)))
	if not live_bandits.is_empty():
		_bandit_center /= float(live_bandits.size())

	# 1. 도적 이동 및 상태 전이
	var any_reached_palace: bool = false
	var is_attacking_wall: bool = false

	for b: Dictionary in live_bandits:
		var bx: float = float(b.get("x", 0.0))
		var by: float = float(b.get("y", 0.0))
		var b_pos := Vector2(bx, by)
		var b_tile := Vector2i(int(bx), int(by))
		var b_state: String = String(b.get("state", "march"))

		# 성벽 접촉 및 통과 저지 검사
		if raid_mode == AI_STATE_ASSAULT_PALACE and current_defense > 0:
			var dist_to_wall: bool = _is_near_wall_or_gate(b_tile, grid)
			if dist_to_wall:
				is_attacking_wall = true
				b["state"] = "attack_wall"
				b["bubble_text"] = "성벽을 부숴라! 방호벽을 무너뜨려라!"
				b["bubble_timer"] = 2.0

		if b_state == "attack_wall" and current_defense <= 0:
			# 성 방호력이 0이 되어 성벽 돌파
			b["state"] = "march"
			b["bubble_text"] = "성벽이 뚫렸다! 행궁으로 돌격하라!"
			b["bubble_timer"] = 3.0

		# 이동 경로상 민가/상점 약탈 (비파괴적)
		if b_state in ["march", "attack_wall"]:
			if grid != null and grid.in_bounds(b_tile.x, b_tile.y):
				var t_dict: Dictionary = grid.grid[b_tile.y][b_tile.x]
				var b_type: String = String(t_dict.get("building", ""))
				if (b_type.begins_with("res_") or b_type.begins_with("com_")) and not t_dict.get("is_looted", false):
					_loot_tile(b_tile, grid, sim)
					b["state"] = "raid"
					b["state_timer"] = 2.5
					b["bubble_text"] = "불을 질러라! 쌀가마를 털어라!"
					b["bubble_timer"] = 3.0

		# 행궁 본궁 도달 검사
		if raid_mode == AI_STATE_ASSAULT_PALACE:
			var palace_vec := Vector2(float(haenggung_palace_pos.x) + 0.5, float(haenggung_palace_pos.y) + 0.5)
			if b_pos.distance_to(palace_vec) <= 1.5:
				any_reached_palace = true
				b["state"] = "palace_breach"
				b["bubble_text"] = "행궁을 함락했다! 우리가 새 주인이로다!"
				b["bubble_timer"] = 4.0

		# 외곽 모드 약탈 완료 후 퇴각
		if raid_mode == AI_STATE_RAID_OUTSKIRTS:
			var tgt_vec := Vector2(float(primary_target.x) + 0.5, float(primary_target.y) + 0.5)
			if b_pos.distance_to(tgt_vec) <= 1.2:
				if b_state != "retreat":
					_loot_tile(primary_target, grid, sim)
					b["state"] = "retreat"
					b["bubble_text"] = "두둑이 챙겼으니 어서 도망치자!"
					b["bubble_timer"] = 3.5

	# 2. 성 방호력 차감 (도적의 공세: 공격력에 정비례하여 성 방호력 및 피로도 누적)
	if is_attacking_wall and current_defense > 0:
		var def_damage: int = maxi(6, int(round(float(bandit_siege_atk) * 0.12 * COMBAT_TICK_RATE)))
		CityStats.apply_defense_damage(def_damage, sim)

	# 3. 장용영 군사의 요격 및 교전 (초당 아군 공격력 / 5)
	# 0.2초 틱당 피해량 = (ally_attack / 5) * 0.2 = ally_attack / 25
	var in_combat: bool = false
	for troop: Dictionary in live_troops:
		var tx: float = float(troop.get("x", 0.0))
		var ty: float = float(troop.get("y", 0.0))
		var tr_pos := Vector2(tx, ty)

		# 가장 가까운 도적 탐색
		var min_dist: float = 999.0
		var target_b: Dictionary = {}
		for b: Dictionary in live_bandits:
			var b_pos := Vector2(float(b.get("x", 0.0)), float(b.get("y", 0.0)))
			var dist: float = tr_pos.distance_to(b_pos)
			if dist < min_dist:
				min_dist = dist
				target_b = b

		if min_dist <= 1.5 and not target_b.is_empty():
			in_combat = true
			troop["state"] = "combat"
			target_b["state"] = "combat"
			troop["bubble_text"] = "장용영의 칼을 받아라!"
			troop["bubble_timer"] = 2.0
		elif min_dist > 1.5 and not target_b.is_empty():
			# 도적을 향해 이동 유도
			var dir_vec: Vector2 = (Vector2(float(target_b.get("x", 0.0)), float(target_b.get("y", 0.0))) - tr_pos).normalized()
			troop["x"] = tx + dir_vec.x * float(troop.get("speed", 1.6)) * COMBAT_TICK_RATE
			troop["y"] = ty + dir_vec.y * float(troop.get("speed", 1.6)) * COMBAT_TICK_RATE
			troop["state"] = "rush"

	if in_combat:
		var tick_damage: int = maxi(5, int(round(float(ally_attack) / 25.0)))
		bandit_siege_hp = maxi(0, bandit_siege_hp - tick_damage)

	# 4. 승패 최종 판정
	# 승리 조건: 도적 체력 0 도달
	if bandit_siege_hp <= 0:
		return finish_raid(true, sim, grid, citizens)

	# 패배 조건: 행궁 본궁 도달 및 방호력 0 (행궁 함락 게임 오버)
	if any_reached_palace and CityStats.get_fortress_defense_power() <= 0:
		return finish_raid(false, sim, grid, citizens)

	return {
		"active": true,
		"mode": raid_mode,
		"bandit_hp": bandit_siege_hp,
		"defense_power": CityStats.get_fortress_defense_power(),
		"in_combat": in_combat
	}

## 침입 종료 처리
func finish_raid(repelled: bool, sim: SimulationCore, _grid: GameGrid, citizens: CitizenManager) -> Dictionary:
	is_raid_active = false
	if sim:
		sim.bandit_active = false
		sim.bandit_raid_ended.emit(repelled)
	if citizens:
		citizens.bandit_battle_ended.emit(repelled)

	if repelled:
		# 승리: 도적 포박 및 관아 압송 연출
		if citizens:
			var live_bandits: Array[Dictionary] = citizens.agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "bandit" and not a.get("is_dead", false))
			for b: Dictionary in live_bandits:
				b["state"] = "arrested"
				b["bubble_text"] = "살려주시오! 잘못했소!"
				b["bubble_timer"] = 3.5
				# 관아로 압송
				var b_pos := Vector2i(int(b.get("x", 0.0)), int(b.get("y", 0.0)))
				citizens.capture_criminal(b_pos, "bandit")
				b["is_dead"] = true

			var live_troops: Array[Dictionary] = citizens.agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "jangyongyeong_soldier")
			for troop: Dictionary in live_troops:
				troop["state"] = "return"
				troop["bubble_text"] = "도적 떼를 모두 진압했다! 군영으로 복귀한다!"
				troop["bubble_timer"] = 3.5

		# 침공해온 도적들의 근거지 소굴 소탕 및 제거
		var destroyed_camp_name: String = ""
		if not camps.is_empty():
			var rm_idx: int = -1
			for ci: int in range(camps.size()):
				var cp: Vector2i = camps[ci].get("pos", Vector2i(-1, -1))
				if cp == bandit_camp_pos or (absi(cp.x - bandit_camp_pos.x) <= 2 and absi(cp.y - bandit_camp_pos.y) <= 2):
					rm_idx = ci
					break
			if rm_idx == -1:
				rm_idx = 0
			var d_camp: Dictionary = camps[rm_idx]
			destroyed_camp_name = str(d_camp.get("name", "도적 소굴"))
			camps.remove_at(rm_idx)

		if sim:
			sim.loyalty = mini(100, sim.loyalty + 5)
			sim.bandit_suppression_turns = 24 # 2년(24개월) 안전 보장
			sim.notify_bandit_camp_subjugated()
		BuildingManager.restore_ruined_buildings(_grid, sim)

		var success_msg: String = "[토포 성공] 장용영 군사들이 침입한 도적 떼를 완벽히 진압하여 관아로 압송하였습니다!"
		if destroyed_camp_name != "":
			success_msg = "[토벌 대승] 침입한 화적 떼를 전원 소탕하고 놈들의 근거지(%s)를 완전히 불태워 파괴하였습니다! (민심 +5)" % destroyed_camp_name

		return {
			"active": false,
			"repelled": true,
			"msg": success_msg
		}
	else:
		# 패배: 행궁 함락 -> EndingManager 즉각 호출 게임 오버!
		print_debug("[BanditManager] 도적의 화성행궁 본궁 점거 확인: 도시 함락 엔딩 시퀀스 가동")
		EndingManager.trigger_ending("FALLEN_TO_BANDITS")

		return {
			"active": false,
			"repelled": false,
			"msg": "[도시 함락] 화적 떼가 화성행궁을 점거하여 도시가 함락되었습니다."
		}

## 성벽/성문 인접 여부 판정
func _is_near_wall_or_gate(pos: Vector2i, grid: GameGrid) -> bool:
	if grid == null or not grid.in_bounds(pos.x, pos.y):
		return false
	var dirs := [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 0)]
	for d in dirs:
		var np: Vector2i = pos + d
		if grid.in_bounds(np.x, np.y):
			var bld: String = String(grid.grid[np.y][np.x].get("building", ""))
			if bld == "wall" or bld == "gate" or bld.begins_with("floodgate"):
				return true
	return false

## 행궁 중심 타일 찾기
func _find_haenggung_pos(grid: GameGrid, citizens: CitizenManager) -> Vector2i:
	if citizens and citizens.get("_haenggung_gate") != null:
		var hg: Vector2i = citizens._haenggung_gate
		if hg.x >= 0 and hg.y >= 0:
			return hg
	if grid:
		for y in range(grid.size):
			for x in range(grid.size):
				if String(grid.grid[y][x].get("building", "")).begins_with("haenggung"):
					return Vector2i(x, y)
	return Vector2i(24, 28)

## 외곽 목표 타일 찾기
func _find_outskirts_target(grid: GameGrid, citizens: CitizenManager) -> Vector2i:
	if citizens:
		var res_c: Array = citizens._res_cache
		if not res_c.is_empty():
			# 맵 경계에 가장 가까운 민가 선택
			var best_p: Vector2i = res_c[0]
			var min_dist: int = 999
			for p: Vector2i in res_c:
				var edge_d: int = mini(mini(p.x, grid.size - 1 - p.x), mini(p.y, grid.size - 1 - p.y))
				if edge_d < min_dist:
					min_dist = edge_d
					best_p = p
			return best_p
	return Vector2i(10, 10)

## 장용영 출동 기지 찾기
func _find_troop_spawn_base(grid: GameGrid, citizens: CitizenManager) -> Vector2i:
	if citizens and not citizens._patrol_cache.is_empty():
		return citizens._patrol_cache[0]
	return _find_haenggung_pos(grid, citizens)

## 도적 토벌 출동 시 아군 총 전투력 산출: 기본 군사력 + (순라청 개수 * 30) + 장용영 훈련치
static func calculate_ally_combat_power(sim: SimulationCore, grid: GameGrid) -> int:
	var base_mil: int = sim.military_power if sim != null else 70
	var patrol_cnt: int = 0
	if grid != null and grid.grid is Array:
		var g_size: int = grid.grid.size()
		for y: int in range(g_size):
			var row: Array = grid.grid[y]
			for x: int in range(row.size()):
				var cell: Dictionary = row[x]
				if str(cell.get("building", "")) == "patrol" and not cell.get("under_construction", false):
					patrol_cnt += 1
	var drill_bonus: int = CityStats.get_seojangdae_drill_bonus()
	return base_mil + (patrol_cnt * 30) + drill_bonus

## 타일 약탈 (비파괴적)
func _loot_tile(pos: Vector2i, grid: GameGrid, sim: SimulationCore) -> void:
	if grid == null or not grid.in_bounds(pos.x, pos.y) or not (grid.grid is Array) or grid.grid.is_empty():
		return
	if pos.y >= grid.grid.size() or pos.x >= grid.grid[pos.y].size():
		return
	var t: Dictionary = grid.grid[pos.y][pos.x]
	t["is_looted"] = true
	t["looted_timer"] = 25.0
	looted_tiles[pos] = 25.0
	BuildingManager.ruin_building_at(pos, grid, sim)

	# 순라청 및 순라군 요격 방어선 확인 (피해 규모 25% 경감)
	var has_patrol_defense: bool = false
	if grid != null and grid.grid is Array:
		var g_size: int = grid.grid.size()
		for y: int in range(g_size):
			var row: Array = grid.grid[y]
			for x: int in range(row.size()):
				if str(row[x].get("building", "")) == "patrol" and not row[x].get("under_construction", false):
					has_patrol_defense = true
					break
			if has_patrol_defense:
				break

	if sim:
		var gold_loss: int = 25
		var rice_loss: int = 15
		if has_patrol_defense:
			# 순라군 요격으로 약탈 피해 25% 경감
			gold_loss = int(round(float(gold_loss) * 0.75))
			rice_loss = int(round(float(rice_loss) * 0.75))

		sim.gold = maxi(0, sim.gold - gold_loss)
		sim.rice = maxi(0, sim.rice - rice_loss)
		sim.loyalty = maxi(0, sim.loyalty - 1)

## 약탈 타일 타이머 관리
func _update_looted_tiles(delta: float, grid: GameGrid) -> void:
	if looted_tiles.is_empty():
		return
	var expired: Array[Vector2i] = []
	for p: Vector2i in looted_tiles.keys():
		var rem: float = float(looted_tiles[p]) - delta
		if rem <= 0.0:
			expired.append(p)
			if grid != null and grid.in_bounds(p.x, p.y):
				grid.grid[p.y][p.x]["is_looted"] = false
		else:
			looted_tiles[p] = rem
	for exp_p: Vector2i in expired:
		looted_tiles.erase(exp_p)

# -------------------------------------------------------------------------
# 국부(금화·곡식 10만+) 비례 도적·반란 위협 스케일링 ("부의 역설")
# -------------------------------------------------------------------------

## 도적 스폰 확률 산출 (가을 턴 가산 및 국부 10만+ 비례 가산, 최대 40% Hard Cap)
static func calculate_bandit_spawn_chance(sim: SimulationCore, is_autumn: bool = false) -> float:
	if sim == null:
		return 0.0

	# 초반 2년(8턴) 도적/약탈 면역 및 토벌 후 평온 버프 검사 (1789년 시작 기준 1791년 이전 또는 turn <= 8)
	if sim.current_year < 1791 or sim.turn <= 8:
		return 0.0
	if sim.bandit_suppression_turns > 0 or sim.bandit_suppression_cooldown > 0.0:
		return 0.0

	# 기본 스폰 확률 (가을 15%, 평상시 5%)
	var base_chance: float = 0.15 if is_autumn else 0.05
	var g: int = ResourceManager.get_gold(sim)
	var r: int = ResourceManager.get_rice(sim)
	var wealth_bonus: float = DifficultyManager.get_threat_escalation(g, r) # 최대 25%

	# 불합리한 사망 루프 방지를 위한 최대 40% (0.40) Hard Cap 적용
	return clampf(base_chance + wealth_bonus, 0.0, 0.40)

## 가을 도적 소굴 스폰 확률 검사 (ResourceManager 초과 재화 연동)
static func check_autumn_bandit_spawn(sim: SimulationCore) -> bool:
	if sim == null:
		return false
	var chance: float = calculate_bandit_spawn_chance(sim, true)
	if chance <= 0.0:
		return false
	return randf() < chance

## 상단 습격 시 약탈 손실량 정산 (기본 5,000전/5,000석 + 초과 재화의 2%~3%)
static func calculate_caravan_raid_losses(sim: SimulationCore) -> Dictionary:
	var cur_gold: int = ResourceManager.get_gold(sim)
	var cur_rice: int = ResourceManager.get_rice(sim)

	var base_gold_loss: int = mini(cur_gold, 5000)
	var base_rice_loss: int = mini(cur_rice, 5000)

	var excess_gold: int = ResourceManager.get_excess_gold(sim)
	var excess_rice: int = ResourceManager.get_excess_rice(sim)

	var loot_rate: float = DifficultyManager.get_excess_loot_rate() # 보통 2%, 어려움 3%
	var extra_gold_loss: int = int(floor(float(excess_gold) * loot_rate))
	var extra_rice_loss: int = int(floor(float(excess_rice) * loot_rate))

	var total_gold_loss: int = mini(cur_gold, base_gold_loss + extra_gold_loss)
	var total_rice_loss: int = mini(cur_rice, base_rice_loss + extra_rice_loss)

	return {
		"base_gold": base_gold_loss,
		"base_rice": base_rice_loss,
		"extra_gold": extra_gold_loss,
		"extra_rice": extra_rice_loss,
		"total_gold": total_gold_loss,
		"total_rice": total_rice_loss,
		"has_wealth_penalty": (extra_gold_loss > 0 or extra_rice_loss > 0)
	}

## 상단 약탈 실행 (초반 2년 보호 및 음수 방어 적용)
static func apply_caravan_raid(sim: SimulationCore) -> Dictionary:
	if sim == null:
		return {"success": false, "protected": false}

	# 초반 2년(8턴) 도적 및 약탈 완전 면역 (1789년 시작 기준 1791년 이전 또는 turn <= 8)
	if sim.current_year < 1791 or sim.turn <= 24 or sim.bandit_suppression_turns > 0:
		return {"success": false, "protected": true}

	var losses: Dictionary = calculate_caravan_raid_losses(sim)
	var g_loss: int = int(losses.get("total_gold", 0))
	var r_loss: int = int(losses.get("total_rice", 0))

	# 국고에서 차감 (음수 원천 차단)
	if g_loss > 0:
		ResourceManager.deduct_gold(g_loss, sim)
	if r_loss > 0:
		ResourceManager.deduct_rice(r_loss, sim)

	var has_wealth_penalty: bool = bool(losses.get("has_wealth_penalty", false))
	if has_wealth_penalty and sim.has_signal("disaster_alert"):
		sim.emit_signal("disaster_alert", "⚠️ [표적이 된 풍요] 화성의 풍요로운 재화가 소문이 나 도적들의 습격이 한층 거세졌습니다!")

	return {
		"success": true,
		"protected": false,
		"losses": losses,
		"gold_loss": g_loss,
		"rice_loss": r_loss
	}

# =========================================================================
# [신규] 동적 도적 생태계 코어 (소굴 스폰·성장·약탈 FSM·유수부 토벌·공성전 엔딩)
# =========================================================================

## 외곽 공터 타일 사전 캐싱 (O(1) 스폰 추출)
func init_outer_tiles(grid: GameGrid) -> void:
	outer_empty_tiles.clear()
	if grid == null or grid.grid.is_empty():
		return
	var g_size: int = grid.grid.size()
	for y: int in range(g_size):
		var row: Array = grid.grid[y]
		for x: int in range(row.size()):
			var cell: Dictionary = row[x]
			var t_type: String = str(cell.get("terrain", ""))
			var b_type: String = str(cell.get("building", ""))
			# 성곽 외부이면서 건물이 없고 물/성벽이 아닌 곳
			if t_type == "outside" and b_type == "":
				outer_empty_tiles.append(Vector2i(x, y))

## 전체 소굴 총 전투력 합산
func get_total_camp_combat_power() -> int:
	var total: int = 0
	for c: Dictionary in camps:
		total += int(c.get("combat_power", 0))
	return total

## 소굴 목록 직렬화 (세이브/로드)
func serialize() -> Dictionary:
	return {
		"camps": camps.duplicate(true),
		"subjugation_cooldown_turns": subjugation_cooldown_turns,
		"loot_immune_turns": loot_immune_turns,
		"siege_warning_turns": siege_warning_turns,
		"last_spawn_year": last_spawn_year,
		"next_camp_id": next_camp_id
	}

const CAMP_NAMES: Array[String] = [
	"광교산 배후 산채",
	"팔달산 서북 외곽 은신처",
	"독산성 인근 화적 토굴",
	"지지대 험로 소굴",
	"칠보산 암석 막사",
	"서호 갈대밭 화적 야영지"
]

## 소굴 목록 역직렬화 (세이브/로드)
func deserialize(data: Dictionary) -> void:
	camps.clear()
	var saved_camps: Array = data.get("camps", [])
	for c in saved_camps:
		if c is Dictionary:
			var pos_val = c.get("pos", Vector2i(4, 8))
			var camp_pos: Vector2i = Vector2i(4, 8)
			if pos_val is Vector2i:
				camp_pos = pos_val
			elif pos_val is Dictionary:
				camp_pos = Vector2i(int(pos_val.get("x", 4)), int(pos_val.get("y", 8)))
			camps.append({
				"id": int(c.get("id", 1)),
				"pos": camp_pos,
				"combat_power": int(c.get("combat_power", 150)),
				"age_turns": int(c.get("age_turns", 0)),
				"name": str(c.get("name", "도적 소굴"))
			})
	subjugation_cooldown_turns = int(data.get("subjugation_cooldown_turns", 0))
	loot_immune_turns = int(data.get("loot_immune_turns", 0))
	siege_warning_turns = int(data.get("siege_warning_turns", 0))
	last_spawn_year = int(data.get("last_spawn_year", -1))
	next_camp_id = int(data.get("next_camp_id", 1))

## 특정 위치 인근의 소굴 제거 (소탕 시 호출)
func remove_camp_at(pos: Vector2i) -> bool:
	if camps.is_empty():
		return false
	var target_idx: int = -1
	var min_dist: int = 999
	for i: int in range(camps.size()):
		var cp: Vector2i = camps[i].get("pos", Vector2i(-1, -1))
		var d: int = absi(cp.x - pos.x) + absi(cp.y - pos.y)
		if d <= 2 and d < min_dist:
			min_dist = d
			target_idx = i
	if target_idx != -1:
		camps.remove_at(target_idx)
		return true
	if pos.x < 0 or pos.y < 0:
		camps.remove_at(0)
		return true
	return false

## 특정 ID의 소굴 제거
func remove_camp_by_id(camp_id: int) -> bool:
	for i: int in range(camps.size()):
		if int(camps[i].get("id", -1)) == camp_id:
			camps.remove_at(i)
			return true
	return false

## 전투력이 가장 높은 소굴 제거
func remove_top_camp() -> Dictionary:
	if camps.is_empty():
		return {}
	var max_idx: int = 0
	var max_p: int = -1
	for i: int in range(camps.size()):
		var p: int = int(camps[i].get("combat_power", 0))
		if p > max_p:
			max_p = p
			max_idx = i
	var removed: Dictionary = camps[max_idx]
	camps.remove_at(max_idx)
	return removed

## 특정 위치 인근의 소굴 조회
func get_camp_at(pos: Vector2i) -> Dictionary:
	for c: Dictionary in camps:
		var cp: Vector2i = c.get("pos", Vector2i(-1, -1))
		if absi(cp.x - pos.x) <= 1 and absi(cp.y - pos.y) <= 1:
			return c
	return {}

## 수원유수부 토벌 출동
func dispatch_yusubu_subjugation(sim: SimulationCore, grid: GameGrid) -> Dictionary:
	if camps.is_empty():
		return {"success": false, "reason": "no_camps", "msg": "현재 토벌할 도적 소굴이 없습니다."}

	if subjugation_cooldown_turns > 0:
		return {
			"success": false,
			"reason": "cooldown",
			"msg": "수원유수부 토벌대는 1년에 1회만 출동할 수 있습니다. (다시 출동까지 %d개월)" % subjugation_cooldown_turns
		}

	var cost_dict: Dictionary = DifficultyManager.get_bandit_subjugation_cost()
	var req_gold: int = int(cost_dict.get("gold", 1000))
	var req_rice: int = int(cost_dict.get("rice", 1000))

	var cur_gold: int = ResourceManager.get_gold(sim)
	var cur_rice: int = ResourceManager.get_rice(sim)

	if cur_gold < req_gold or cur_rice < req_rice:
		return {
			"success": false,
			"reason": "lack_resources",
			"msg": "토벌 출동 군자금이 부족합니다! (필요: 금 %d냥, 쌀 %d석 / 보유: 금 %d냥, 쌀 %d석)" % [
				req_gold, req_rice, cur_gold, cur_rice
			]
		}

	# 자원 소모 및 1년 쿨다운(3턴) 적용 (이번 턴 소모 + 3턴 대기 = 총 4턴/1년)
	ResourceManager.deduct_gold(req_gold, sim)
	ResourceManager.deduct_rice(req_rice, sim)
	subjugation_cooldown_turns = 12

	# 대상 소굴: 전투력이 가장 높은 곳
	var target_idx: int = -1
	var max_power: int = -1
	for i: int in range(camps.size()):
		var p: int = int(camps[i].get("combat_power", 0))
		if p > max_power:
			max_power = p
			target_idx = i

	var ally_power: int = calculate_ally_combat_power(sim, grid)
	if ally_power >= max_power:
		# 승리: 소굴 격멸
		var destroyed_camp: Dictionary = camps[target_idx]
		camps.remove_at(target_idx)
		if sim:
			sim.add_morale(5)
			sim.notify_bandit_camp_subjugated()
		# 소굴 격멸 후 시즈 경고 리셋 검사
		if camps.is_empty() or float(get_total_camp_combat_power()) <= float(ally_power) * 1.5:
			siege_warning_turns = 0

		return {
			"success": true,
			"victory": true,
			"camp": destroyed_camp,
			"ally_power": ally_power,
			"enemy_power": max_power,
			"msg": "⚔️ [토벌 대승] 수원유수부 정예군이 도적 소굴(전투력 %d)을 완전 소탕했습니다! (민심 +5)" % max_power
		}
	else:
		# 패배: 소굴 유지, 자원/출동 기회만 소모
		return {
			"success": true,
			"victory": false,
			"ally_power": ally_power,
			"enemy_power": max_power,
			"msg": "⚠️ [토벌 실패] 아군 군사력(%d)이 도적들의 기세(%d)를 꺾지 못했습니다! (요구 군사력: %d)" % [
				ally_power, max_power, max_power
			]
		}

## 매 턴 경제 정산 끝부분에 호출되는 턴 처리 루프
func process_turn(sim: SimulationCore, grid: GameGrid, trade: TradeSystem = null) -> Dictionary:
	var res: Dictionary = {
		"camp_spawned": false,
		"camps_count": camps.size(),
		"raid_occurred": false,
		"raid_stage": 0,
		"siege_warning": false,
		"siege_ending": false
	}

	if sim == null:
		return res

	# 쿨다운 차감
	if subjugation_cooldown_turns > 0:
		subjugation_cooldown_turns -= 1
	if loot_immune_turns > 0:
		loot_immune_turns -= 1

	# 백동수 등용 여부 확인
	var baek_hired: bool = bool(sim.retainers.get("baek_dongsu", false)) if sim.retainers else false

	# 초반 2년(24개월) 유예 기간 검사 (1789년 시작 기준 1791년 이전 또는 turn <= 24)
	var is_early_game_protected: bool = (sim.current_year < 1791 or sim.turn <= 24)

	# 1. 도적 소굴 스폰 조건 판정 (민심이 흉흉할 때 성 밖에 여기저기 생성)
	if not is_early_game_protected and not baek_hired and sim.bandit_suppression_turns <= 0:
		var is_autumn: bool = (sim.season_now() == 2)
		var loy: int = sim.loyalty

		# 민심 45 이하 시 스폰 검사 (민심이 흉흉할수록 확률과 최대 스폰 수 대폭 증가, 상한 3개)
		if loy <= 45 and camps.size() < 3:
			var spawn_chance: float = 0.40
			var max_spawns_this_turn: int = 1

			if loy <= 25:
				# 민심 극도 파탄 (민란 직전): 스폰 확률 100%, 턴당 최대 2개 동시 출현
				spawn_chance = 1.0
				max_spawns_this_turn = 2
			elif loy <= 35:
				# 민심 흉흉: 스폰 확률 70% (가을 90%), 턴당 최대 1~2개 출현
				spawn_chance = 0.90 if is_autumn else 0.70
				max_spawns_this_turn = 2 if (camps.is_empty() and randf() < 0.6) else 1
			else:
				# 민심 동요 (36~45): 스폰 확률 40% (가을 60%)
				spawn_chance = 0.60 if is_autumn else 0.40
				max_spawns_this_turn = 1

			var spawned_count: int = 0
			for _s in range(max_spawns_this_turn):
				if camps.size() >= 3:
					break
				if randf() < spawn_chance:
					var sc: Dictionary = _spawn_bandit_camp(grid)
					if not sc.is_empty():
						spawned_count += 1
						res["camp_spawned"] = true

			if spawned_count > 0:
				last_spawn_year = sim.current_year
				if sim.has_signal("disaster_alert"):
					if camps.size() >= 2:
						sim.emit_signal("disaster_alert", "🚨 [도적 창궐] 민심이 흉흉해진 틈을 타 성 밖 외곽 험지 여기저기에 화적 떼가 소굴을 틀고 세력을 불리고 있습니다! (현재 활성 소굴: %d개소)" % camps.size())
					else:
						sim.emit_signal("disaster_alert", "🚨 [도적 발호] 민심이 동요하자 성 밖 외곽 험지에 화적들의 새 소굴이 들어섰습니다!")

	# 2. 방치 시 기존 소굴 전투력 성장 (+25 누적, 최대 500)
	for c: Dictionary in camps:
		var cur_p: int = int(c.get("combat_power", 150))
		cur_p = mini(500, cur_p + 25)
		c["combat_power"] = cur_p
		c["age_turns"] = int(c.get("age_turns", 0)) + 1

	res["camps_count"] = camps.size()
	res["total_combat_power"] = get_total_camp_combat_power()

	# 3. 2단계 약탈 FSM (소굴이 1개 이상 존재할 때)
	if not camps.is_empty() and not is_early_game_protected and not baek_hired:
		if loot_immune_turns <= 0:
			# 랜덤 확률로 약탈 발생 (예: 50% 확률)
			if randf() < 0.50:
				var total_power: int = get_total_camp_combat_power()
				var is_stage_2: bool = (camps.size() >= 2 or total_power >= 400)
				_execute_raid(is_stage_2, sim, grid, trade)
				loot_immune_turns = 12 # 약탈 발생 후 1년(12개월) 확정 면역
				res["raid_occurred"] = true
				res["raid_stage"] = 2 if is_stage_2 else 1

	# 4. 공성전 발발 및 도적 함락 엔딩 검사
	# 총합 전투력 > 도시 국방력 * 1.5 상태로 한 계절(경고 뒤 석 달) 넘게 방치 시
	var ally_power: int = calculate_ally_combat_power(sim, grid)
	var total_camp_power: int = get_total_camp_combat_power()
	if not camps.is_empty() and float(total_camp_power) > float(ally_power) * 1.5 and not baek_hired:
		siege_warning_turns += 1
		if siege_warning_turns == 1:
			# 첫 달: 긴급 경고 발화
			res["siege_warning"] = true
			if sim.has_signal("disaster_alert"):
				sim.emit_signal("disaster_alert", "🚨 [변방 비상] 도적떼가 세력을 규합해 수원화성을 향해 진격하고 있습니다! (다음 계절까지 국방력을 증강하지 않으면 성이 함락됩니다!)")
		elif siege_warning_turns >= 4:
			# 경고 뒤 석 달(한 계절) 방치: 도적 함락 엔딩 발화
			res["siege_ending"] = true
			if EndingManager.instance != null:
				EndingManager.instance.trigger_fall_of_city_ending("BANDIT_FALL")
			elif sim.has_signal("disaster_alert"):
				sim.emit_signal("disaster_alert", "🚨 [수원화성 함락] 도적 떼의 총공격으로 화성이 함락되었습니다!")
	else:
		siege_warning_turns = 0

	return res

## 소굴 스폰 내부 함수 ("성 밖에 여기저기 험지 분산 생성")
func _spawn_bandit_camp(grid: GameGrid) -> Dictionary:
	if outer_empty_tiles.is_empty() and grid != null:
		init_outer_tiles(grid)

	if camps.size() >= 3:
		return {}

	var chosen_pos := Vector2i(4, 8)
	var candidates: Array[Vector2i] = []

	if not outer_empty_tiles.is_empty() and grid != null:
		for p: Vector2i in outer_empty_tiles:
			# 기존 소굴들과의 거리 검사 (최소 5칸 이상 이격하여 '여기저기' 분산)
			var too_close: bool = false
			for c: Dictionary in camps:
				var cp: Vector2i = c.get("pos", Vector2i(-1, -1))
				if cp.x >= 0 and (absi(cp.x - p.x) + absi(cp.y - p.y)) < 5:
					too_close = true
					break
			if too_close:
				continue

			if grid.in_bounds(p.x, p.y):
				var cell: Dictionary = grid.grid[p.y][p.x]
				var b_type: String = str(cell.get("building", ""))
				var z_type: String = str(cell.get("zone", ""))
				var t_type: String = str(cell.get("terrain", ""))
				if b_type != "" or z_type != "" or t_type == "water":
					continue

				# 도로 바로 옆은 배제 (은신처 보호)
				var near_road: bool = false
				for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
					var np: Vector2i = p + d
					if grid.in_bounds(np.x, np.y):
						var nb: String = str(grid.grid[np.y][np.x].get("building", ""))
						if nb == "road" or nb == "stone_road" or nb == "wall":
							near_road = true
							break
				if near_road:
					continue

				candidates.append(p)

		if not candidates.is_empty():
			var rugged_cands: Array[Vector2i] = []
			for cand: Vector2i in candidates:
				var ter: String = str(grid.grid[cand.y][cand.x].get("terrain", ""))
				if ter == "mountain" or ter == "forest":
					rugged_cands.append(cand)
			if not rugged_cands.is_empty():
				chosen_pos = rugged_cands[randi() % rugged_cands.size()]
			else:
				chosen_pos = candidates[randi() % candidates.size()]
		elif not outer_empty_tiles.is_empty():
			chosen_pos = outer_empty_tiles[randi() % outer_empty_tiles.size()]

	var name_idx: int = (next_camp_id - 1) % CAMP_NAMES.size()
	var camp_name: String = CAMP_NAMES[name_idx]

	var new_camp: Dictionary = {
		"id": next_camp_id,
		"pos": chosen_pos,
		"combat_power": 150,
		"age_turns": 0,
		"name": camp_name
	}
	next_camp_id += 1
	camps.append(new_camp)
	return new_camp

## 약탈 실행 내부 함수
func _execute_raid(is_stage_2: bool, sim: SimulationCore, grid: GameGrid, trade: TradeSystem) -> void:
	# 자원 강탈 (기본 금 5,000 / 곡 5,000 하한선 0 방어)
	var cur_gold: int = ResourceManager.get_gold(sim)
	var cur_rice: int = ResourceManager.get_rice(sim)
	var gold_loss: int = mini(cur_gold, 5000)
	var rice_loss: int = mini(cur_rice, 5000)

	if gold_loss > 0:
		ResourceManager.deduct_gold(gold_loss, sim)
	if rice_loss > 0:
		ResourceManager.deduct_rice(rice_loss, sim)

	if not is_stage_2:
		# 1단계 (상단 습격): 상업 거래 1턴 마비
		if trade != null:
			trade.trade_connected = false
		if sim.has_signal("disaster_alert"):
			sim.emit_signal("disaster_alert", "🚨 [상단 습격] 사대문 교역로를 오가던 보부상단이 도적 떼의 기습을 받아 금 %d전, 곡식 %d석을 강탈당하고 상업 거래가 마비되었습니다!" % [
				gold_loss, rice_loss
			])
	else:
		# 2단계 (성내 침입): 민심 -10 급락, 일반 가옥 1~2채 일시 파손
		sim.add_morale(-10)
		_damage_inner_houses(grid, 2)
		if sim.has_signal("disaster_alert"):
			sim.emit_signal("disaster_alert", "🚨 [성내 침입 약탈] 거대화된 도적 떼가 성내로 난입해 민가를 방화하고 금 %d전, 곡식 %d석을 약탈했습니다! (민심 -10)" % [
				gold_loss, rice_loss
			])

## 성내 일반 가옥 파손 연출
func _damage_inner_houses(grid: GameGrid, count: int) -> void:
	if grid == null or grid.grid.is_empty():
		return
	var damaged: int = 0
	var g_size: int = grid.grid.size()
	for y: int in range(g_size):
		var row: Array = grid.grid[y]
		for x: int in range(row.size()):
			var cell: Dictionary = row[x]
			var b_type: String = str(cell.get("building", ""))
			if b_type in ["res_1", "res_2", "res_3", "house"]:
				cell["is_looted"] = true
				cell["looted_timer"] = 30.0
				looted_tiles[Vector2i(x, y)] = 30.0
				damaged += 1
				if damaged >= count:
					return
