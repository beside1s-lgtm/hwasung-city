extends RefCounted
class_name EnemyMarcherEntity

## [적군 분대 이동 및 공격 FSM 엔티티]
## 3~5명의 전투원으로 구성된 적군 분대(화적 떼 / 반란군) 추상화 객체
## 1. 성 밖 스폰 -> 가장 가까운 성문/성곽으로 이동 (outer_march)
## 2. 성문 타격 및 성벽 돌파 (attack_wall)
## 3. 성내 도로망을 따라 화성행궁 본궁으로 진격 (inner_march)
## 4. 진격로 반경 1칸 내 상점/민가 실시간 약탈 및 폐가화 (RUINED)
## 5. 장용영 요격 분대와 조우 시 교전 (combat)
## 6. 화성행궁 본궁 도달 시 함락 엔딩 발화 (palace_breach)

enum MarcherState {
	OUTER_MARCH = 0,
	ATTACK_WALL = 1,
	INNER_MARCH = 2,
	COMBAT = 3,
	PALACE_BREACH = 4,
	ROUTED = 5,
	ARRESTED = 6
}

const STATE_OUTER_MARCH: String = "outer_march"
const STATE_ATTACK_WALL: String = "attack_wall"
const STATE_INNER_MARCH: String = "inner_march"
const STATE_COMBAT: String = "combat"
const STATE_PALACE_BREACH: String = "palace_breach"
const STATE_ROUTED: String = "routed"
const STATE_ARRESTED: String = "arrested"

var squad_id: int = 0
var kind: String = "bandit" # "bandit" or "rebel"
var state: String = STATE_OUTER_MARCH
var pos: Vector2 = Vector2.ZERO
var speed: float = 1.25

var attack_power: int = 500
var hp: int = 500
var max_hp: int = 500

var spawn_tile: Vector2i = Vector2i.ZERO
var gate_tile: Vector2i = Vector2i(-1, -1)
var haenggung_tile: Vector2i = Vector2i(14, 29)

var march_path: Array[Vector2i] = []
var path_index: int = 0

var is_dead: bool = false
var is_special_entity: bool = true
var is_always_visible: bool = true
var state_timer: float = 0.0
var wall_attack_timer: float = 0.0
var loot_cooldown: float = 0.0
var bubble_text: String = ""
var bubble_timer: float = 0.0

var members: Array[Dictionary] = [] # 3~5인 분대원 스프라이트 정보
var looted_tiles_cache: Dictionary = {}

func setup_marcher(
	p_id: int,
	p_start_tile: Vector2i,
	p_gate_tile: Vector2i,
	p_palace_tile: Vector2i,
	p_atk: int = 500,
	p_kind: String = "bandit"
) -> void:
	squad_id = p_id
	spawn_tile = p_start_tile
	gate_tile = p_gate_tile
	haenggung_tile = p_palace_tile
	attack_power = maxi(500, p_atk)
	hp = maxi(500, p_atk)
	max_hp = hp
	kind = p_kind
	state = STATE_OUTER_MARCH
	pos = Vector2(float(spawn_tile.x) + 0.5, float(spawn_tile.y) + 0.5)
	speed = 1.10 if kind == "rebel" else 1.25
	path_index = 0
	is_dead = false
	looted_tiles_cache.clear()

	# 분대원 4인 편성: 포수(gunner), 사수(archer), 살수(blade), 창수(spear)
	members.clear()
	var w_types: Array[String] = ["gunner", "archer", "blade", "spear"]
	for i: int in range(4):
		var offset_vec := Vector2(
			cos(float(i) * 1.57) * 0.35,
			sin(float(i) * 1.57) * 0.25
		)
		members.append({
			"id": squad_id * 10 + i,
			"weapon_type": w_types[i % w_types.size()],
			"offset": offset_vec,
			"state": "march",
			"anim_phase": randf() * TAU
		})

	bubble_text = "성문을 부수고 행궁으로 진격하라!" if kind == "rebel" else "곡식을 털고 관아를 불태워라!"
	bubble_timer = 3.5

## 매 틱 FSM 업데이트
func update(delta: float, grid: GameGrid, sim: SimulationCore, defense_mgr: Variant = null) -> void:
	if is_dead:
		return

	state_timer += delta
	if bubble_timer > 0.0:
		bubble_timer = maxf(0.0, bubble_timer - delta)

	if loot_cooldown > 0.0:
		loot_cooldown = maxf(0.0, loot_cooldown - delta)

	# 분대원 애니메이션 갱신
	for m: Dictionary in members:
		m["anim_phase"] = float(m.get("anim_phase", 0.0)) + delta * 6.0

	var _cur_tile := Vector2i(int(floor(pos.x)), int(floor(pos.y)))
	var defense_val: int = CityStats.get_fortress_defense_power()

	match state:
		STATE_OUTER_MARCH:
			_update_outer_march(delta, grid, defense_val)

		STATE_ATTACK_WALL:
			_update_attack_wall(delta, grid, sim, defense_val)

		STATE_INNER_MARCH:
			_update_inner_march(delta, grid, sim, defense_mgr)

		STATE_COMBAT:
			_update_combat(delta)

		STATE_PALACE_BREACH:
			_update_palace_breach(delta, defense_mgr)

		STATE_ROUTED:
			_update_routed(delta)

		STATE_ARRESTED:
			speed = 0.0

## 성 밖 진격: 가장 가까운 성문 또는 성벽으로 이동
func _update_outer_march(delta: float, grid: GameGrid, defense_val: int) -> void:
	var target_dest: Vector2i = gate_tile if gate_tile.x >= 0 else haenggung_tile
	var dest_vec := Vector2(float(target_dest.x) + 0.5, float(target_dest.y) + 0.5)
	var to_dest: Vector2 = dest_vec - pos
	var dist: float = to_dest.length()

	# 성문/성벽 접촉 판정 (거리 1.2칸 이내이거나 성곽 방호력이 있는 경우)
	if dist <= 1.25 and defense_val > 0:
		state = STATE_ATTACK_WALL
		state_timer = 0.0
		wall_attack_timer = 0.0
		bubble_text = "성문을 뚫어라! 충차를 들이받아라!" if kind == "rebel" else "성벽을 무너뜨려라!"
		bubble_timer = 3.0
		for m: Dictionary in members:
			m["state"] = "attack_wall"
		return

	if dist <= 1.25 and defense_val <= 0:
		# 성벽 방호력이 0이면 즉시 성내 진입
		_transition_to_inner_march(grid)
		return

	# 이동
	var dir_norm: Vector2 = to_dest.normalized()
	pos += dir_norm * speed * delta

## 성문/성벽 타격 및 방호력 차감
func _update_attack_wall(delta: float, grid: GameGrid, sim: SimulationCore, defense_val: int) -> void:
	wall_attack_timer += delta

	# 성 방호력 초당 지속 차감
	if wall_attack_timer >= 0.5:
		wall_attack_timer = 0.0
		var dmg: int = maxi(5, int(round(float(attack_power) * 0.08)))
		CityStats.apply_defense_damage(dmg, sim)

	if defense_val <= 0:
		_transition_to_inner_march(grid)
		bubble_text = "성문이 뚫렸다! 행궁으로 돌격하라!"
		bubble_timer = 3.0

## 성내 도로망 진격 전환 (A* 사전 계산 경로 탑재)
func _transition_to_inner_march(grid: GameGrid) -> void:
	state = STATE_INNER_MARCH
	state_timer = 0.0
	for m: Dictionary in members:
		m["state"] = "march"

	var cur_tile := Vector2i(int(floor(pos.x)), int(floor(pos.y)))
	if grid != null:
		march_path = grid.find_march_path_to_haenggung(cur_tile)
	else:
		march_path = [haenggung_tile]
	path_index = 0

## 성내 도로망 진격 및 경로 상 건물 폐가화(Ruins)
func _update_inner_march(delta: float, grid: GameGrid, sim: SimulationCore, defense_mgr: Variant) -> void:
	var cur_tile := Vector2i(int(floor(pos.x)), int(floor(pos.y)))

	# 진격로 반경 1칸 내의 건물/상점/농지 실시간 약탈 및 폐가화 (RUINED)
	if loot_cooldown <= 0.0:
		loot_cooldown = 0.4
		_loot_surrounding_tiles(cur_tile, grid, sim)

	# 행궁 중심점 도달 검사
	var palace_vec := Vector2(float(haenggung_tile.x) + 0.5, float(haenggung_tile.y) + 0.5)
	if pos.distance_to(palace_vec) <= 1.8:
		state = STATE_PALACE_BREACH
		state_timer = 0.0
		bubble_text = "행궁을 함락했다! 우리가 새 주인이로다!"
		bubble_timer = 5.0
		for m: Dictionary in members:
			m["state"] = "palace_breach"
		if defense_mgr != null and defense_mgr.has_method("_trigger_palace_fall"):
			defense_mgr._trigger_palace_fall()
		return

	# A* 경로 추종
	if path_index < march_path.size():
		var next_tile: Vector2i = march_path[path_index]
		var next_vec := Vector2(float(next_tile.x) + 0.5, float(next_tile.y) + 0.5)
		var to_next: Vector2 = next_vec - pos
		var d_next: float = to_next.length()

		if d_next <= 0.35:
			path_index += 1
		else:
			pos += to_next.normalized() * speed * delta
	else:
		# 경로 종료 시 행궁으로 직격
		var to_palace: Vector2 = palace_vec - pos
		if to_palace.length() > 0.1:
			pos += to_palace.normalized() * speed * delta

## 진격로 반경 1타일 내 건물 폐가화 (Non-destructive)
func _loot_surrounding_tiles(center: Vector2i, grid: GameGrid, sim: SimulationCore) -> void:
	if grid == null:
		return

	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var tp := Vector2i(center.x + dx, center.y + dy)
			if not grid.in_bounds(tp.x, tp.y) or looted_tiles_cache.has(tp):
				continue

			var cell: Dictionary = grid.grid[tp.y][tp.x]
			var bld: String = str(cell.get("building", ""))
			var is_target: bool = (bld.begins_with("res_") or bld.begins_with("com_") or bld.begins_with("ind_") or bld.begins_with("agr_"))

			if is_target:
				looted_tiles_cache[tp] = true
				BuildingManager.ruin_building_at(tp, grid, sim)
				bubble_text = "불을 질러라! 남김없이 약탈하라!"
				bubble_timer = 2.5

## 교전 업데이트 (장용영 분대와 충돌 시)
func _update_combat(_delta: float) -> void:
	for m: Dictionary in members:
		m["state"] = "combat"
	if state_timer >= 3.5 and hp <= 0:
		is_dead = true

func _update_palace_breach(_delta: float, defense_mgr: Variant) -> void:
	if defense_mgr != null and defense_mgr.has_method("_trigger_palace_fall"):
		defense_mgr._trigger_palace_fall()

func _update_routed(delta: float) -> void:
	var flee_dir := (pos - Vector2(float(haenggung_tile.x), float(haenggung_tile.y))).normalized()
	pos += flee_dir * speed * 1.5 * delta
	if state_timer >= 5.0:
		is_dead = true

func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	if hp <= 0:
		state = STATE_ROUTED
		state_timer = 0.0
		bubble_text = "장용영의 칼날이 너무 섭뜩하다! 퇴각하라!"
		bubble_timer = 3.0
		for m: Dictionary in members:
			m["state"] = "routed"

func get_display_pos() -> Vector2:
	return pos

var visual_node: CitizenNPC = null

func get_or_create_visual(parent: Node2D) -> CitizenNPC:
	if visual_node == null:
		var t_id: String = "bandit" if kind == "bandit" else "thief"
		visual_node = CitizenNPC.new(t_id)
		visual_node.is_special_entity = true
		visual_node.is_always_visible = true
		parent.add_child(visual_node)
	return visual_node

func update_visual_step(delta: float) -> void:
	if visual_node != null:
		visual_node.update_visual_step(delta)

func update_logical_step_throttled(delta: float) -> void:
	if visual_node != null:
		visual_node.update_logical_step_throttled(delta)
