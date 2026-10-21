extends RefCounted
class_name JangyongyeongUnitEntity

## [장용영 요격 분대 FSM 및 교전 엔티티]
## 연무대(동장대)/서장대/행궁에서 출격하여 진격로 길목을 차단하는 정예 분대
## 1. 길목 요격 지점으로 긴급 전술 배치 (deploying)
## 2. 진격로 대기 및 방어선 형성 (standby_hold)
## 3. 적군 분대와 충돌 시 도트 교전 애니메이션 실행 (combat: 환도, 조총, 당파창, 피격 스파크)
## 4. 전투력 비교 판정:
##    - 아군 승리: 적군 궤멸, 승전보 알림 및 폐가 점진 재건
##    - 아군 패배: 방어선 와해 및 적군 행궁 직격 돌진 허용

enum UnitState {
	DEPLOYING = 0,
	STANDBY_HOLD = 1,
	COMBAT = 2,
	VICTORY = 3,
	DEFEATED = 4
}

const STATE_DEPLOYING: String = "deploying"
const STATE_STANDBY_HOLD: String = "standby_hold"
const STATE_COMBAT: String = "combat"
const STATE_VICTORY: String = "victory"
const STATE_DEFEATED: String = "defeated"

var squad_id: int = 0
var state: String = STATE_DEPLOYING
var pos: Vector2 = Vector2.ZERO
var speed: float = 1.65

var combat_power: int = 500
var hp: int = 500
var max_hp: int = 500

var spawn_base: Vector2i = Vector2i(24, 28)
var intercept_tile: Vector2i = Vector2i(-1, -1)
var target_enemy: EnemyMarcherEntity = null

var is_dead: bool = false
var is_special_entity: bool = true
var is_always_visible: bool = true
var state_timer: float = 0.0
var combat_elapsed: float = 0.0
var bubble_text: String = ""
var bubble_timer: float = 0.0

var members: Array[Dictionary] = [] # 4인 분대원: 깃발병(flag), 환도(blade), 조총(gunner), 당파창(spear)

func setup_unit(
	p_id: int,
	p_base_tile: Vector2i,
	p_intercept_tile: Vector2i,
	p_power: int = 500
) -> void:
	squad_id = p_id
	spawn_base = p_base_tile
	intercept_tile = p_intercept_tile
	combat_power = maxi(300, p_power)
	hp = maxi(300, p_power)
	max_hp = hp
	state = STATE_DEPLOYING
	pos = Vector2(float(spawn_base.x) + 0.5, float(spawn_base.y) + 0.5)
	speed = 1.65
	is_dead = false
	state_timer = 0.0
	combat_elapsed = 0.0

	# 분대원 4인 편성: 선두 깃발병, 환도 살수, 조총수, 당파창수
	members.clear()
	var w_types: Array[String] = ["flag", "blade", "gunner", "spear"]
	for i: int in range(4):
		var offset_vec := Vector2(
			cos(float(i) * 1.57) * 0.35,
			sin(float(i) * 1.57) * 0.25
		)
		members.append({
			"id": squad_id * 10 + i,
			"weapon_type": w_types[i],
			"is_flag_bearer": (i == 0),
			"offset": offset_vec,
			"state": "rush",
			"anim_phase": randf() * TAU
		})

	bubble_text = "장용영 군기를 올려라! 길목을 사수하라!"
	bubble_timer = 3.5

## 매 틱 업데이트
func update(delta: float, enemies: Array[EnemyMarcherEntity], defense_mgr: Variant = null) -> void:
	if is_dead:
		return

	state_timer += delta
	if bubble_timer > 0.0:
		bubble_timer = maxf(0.0, bubble_timer - delta)

	# 분대원 애니메이션 페이즈 갱신
	for m: Dictionary in members:
		m["anim_phase"] = float(m.get("anim_phase", 0.0)) + delta * 7.0

	match state:
		STATE_DEPLOYING:
			_update_deploying(delta, enemies)

		STATE_STANDBY_HOLD:
			_update_standby_hold(delta, enemies)

		STATE_COMBAT:
			_update_combat(delta, defense_mgr)

		STATE_VICTORY:
			_update_victory(delta)

		STATE_DEFEATED:
			_update_defeated(delta)

## 길목으로 출동
func _update_deploying(delta: float, enemies: Array[EnemyMarcherEntity]) -> void:
	# 이동 중 인근 적군 분대 탐색
	var close_enemy: EnemyMarcherEntity = _find_nearest_active_enemy(enemies, 1.6)
	if close_enemy != null:
		engage(close_enemy)
		return

	var dest_vec := Vector2(float(intercept_tile.x) + 0.5, float(intercept_tile.y) + 0.5)
	var to_dest: Vector2 = dest_vec - pos
	var dist: float = to_dest.length()

	if dist <= 0.4:
		state = STATE_STANDBY_HOLD
		state_timer = 0.0
		bubble_text = "이곳이 결전의 길목이다! 한 놈도 살려보내지 마라!"
		bubble_timer = 3.0
		for m: Dictionary in members:
			m["state"] = "standby"
	else:
		pos += to_dest.normalized() * speed * delta

## 길목 대기 및 방어선 유지
func _update_standby_hold(_delta: float, enemies: Array[EnemyMarcherEntity]) -> void:
	# 다가오는 적군 감지 (반경 2칸 이내)
	var close_enemy: EnemyMarcherEntity = _find_nearest_active_enemy(enemies, 2.2)
	if close_enemy != null:
		engage(close_enemy)

## 교전 모드: 3~4초간 교전 연출 후 승패 확정
func _update_combat(delta: float, defense_mgr: Variant) -> void:
	combat_elapsed += delta
	for m: Dictionary in members:
		m["state"] = "combat"

	if is_instance_valid(target_enemy) and not target_enemy.is_dead:
		target_enemy.state = EnemyMarcherEntity.STATE_COMBAT

	# 3.5초간 치열한 교전 애니메이션 재생 후 전투력 판정식 적용
	if combat_elapsed >= 3.5:
		_resolve_combat(defense_mgr)

## 승리 후 군영 복귀 및 즉시 디스폰
func _update_victory(delta: float) -> void:
	var base_vec := Vector2(float(spawn_base.x) + 0.5, float(spawn_base.y) + 0.5)
	var to_base: Vector2 = base_vec - pos
	if to_base.length() <= 0.6 or state_timer >= 5.0:
		is_dead = true
		if visual_node != null and is_instance_valid(visual_node):
			visual_node.queue_free()
			visual_node = null
	else:
		pos += to_base.normalized() * speed * 1.2 * delta

## 패배 시 와해
func _update_defeated(_delta: float) -> void:
	if state_timer >= 4.0:
		is_dead = true
		if visual_node != null and is_instance_valid(visual_node):
			visual_node.queue_free()
			visual_node = null

## 교전 시작 트리거
func engage(enemy: EnemyMarcherEntity) -> void:
	state = STATE_COMBAT
	state_timer = 0.0
	combat_elapsed = 0.0
	target_enemy = enemy
	bubble_text = "장용영의 칼을 받아라! 역적 놈들아!"
	bubble_timer = 3.0

	if is_instance_valid(target_enemy) and not target_enemy.is_dead:
		target_enemy.state = EnemyMarcherEntity.STATE_COMBAT
		target_enemy.bubble_text = "장용영 군사다! 뚫고 가자!"
		target_enemy.bubble_timer = 3.0

## 전투 결과 판정 (유효 방어력 vs 적군 공격력)
func _resolve_combat(defense_mgr: Variant) -> void:
	var enemy_atk: int = target_enemy.attack_power if (is_instance_valid(target_enemy) and not target_enemy.is_dead) else 500

	# 판정식: 장용영 방어력 >= 적군 공격력
	if combat_power >= enemy_atk:
		# 아군 승리
		state = STATE_VICTORY
		state_timer = 0.0
		bubble_text = "승전이오! 적의 무리가 완전히 궤멸되었소!"
		bubble_timer = 4.0
		for m: Dictionary in members:
			m["state"] = "victory"

		if is_instance_valid(target_enemy) and not target_enemy.is_dead:
			target_enemy.take_damage(9999) # 적군 전멸

		if defense_mgr != null and defense_mgr.has_method("_on_combat_finished"):
			defense_mgr._on_combat_finished(true)
	else:
		# 아군 패배 (방어선 붕괴)
		state = STATE_DEFEATED
		state_timer = 0.0
		bubble_text = "방어선이 뚫렸다... 행궁을 사수하라..."
		bubble_timer = 3.0
		for m: Dictionary in members:
			m["state"] = "defeated"

		if is_instance_valid(target_enemy) and not target_enemy.is_dead:
			# 적군은 살아남아 행궁으로 돌진
			target_enemy.state = EnemyMarcherEntity.STATE_INNER_MARCH
			target_enemy.bubble_text = "방어선이 무너졌다! 행궁으로 돌격!"
			target_enemy.bubble_timer = 3.0

		if defense_mgr != null and defense_mgr.has_method("_on_combat_finished"):
			defense_mgr._on_combat_finished(false)

func _find_nearest_active_enemy(enemies: Array[EnemyMarcherEntity], radius: float) -> EnemyMarcherEntity:
	var best: EnemyMarcherEntity = null
	var min_d: float = radius
	for e: EnemyMarcherEntity in enemies:
		if e == null or e.is_dead:
			continue
		var d: float = pos.distance_to(e.pos)
		if d < min_d:
			min_d = d
			best = e
	return best

func get_display_pos() -> Vector2:
	return pos

var visual_node: CitizenNPC = null

func get_or_create_visual(parent: Node2D) -> CitizenNPC:
	if visual_node == null:
		visual_node = CitizenNPC.new("jangyongyeong")
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
