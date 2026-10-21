extends RefCounted
class_name ThiefNPC

## [소매치기/도둑 NPC 고유 FSM 엔티티]
## 범행(4초) 후 목표 성문 선정 -> 성문까지 팔자걸음 도주 -> 성문 도착 전까지 상시 체포 가능
## 성문 밖 탈출 성공 시 "세상 살기 편하구만" 대사 출력 후 디스폰

enum ThiefState {
	STEALING = 0,
	FLEEING_TO_GATE = 1,
	ARRESTED = 2,
	SWAGGER_HOME = 3 # 하위 호환성 유지
}

var state: ThiefState = ThiefState.STEALING
var is_arrestable: bool = true # 성문 밖으로 나가기 전까지 내내 true 유지!
var is_escaping_victoriously: bool = false
var steal_prep_timer: float = 4.0 # 현장에서 물건 훔치는 시간 4초
var crime_timer: float = 4.0
var walk_anim_time: float = 0.0
var flee_elapsed: float = 0.0
var lifetime: float = 0.0

var base_speed: float = 2.0
var flee_speed: float = 2.0
var global_position: Vector2 = Vector2.ZERO
var target_gate_pos: Vector2 = Vector2.ZERO
var home_target_pos: Vector2 = Vector2.ZERO
var bubble_text: String = ""
var is_loot_sack_visible: bool = false
var is_dead: bool = false

var sprite_rotation_degrees: float = 0.0
var sprite_position_y: float = 0.0
var sprite_scale: Vector2 = Vector2.ONE
var event_id: int = -1

const MAX_FLEE_TIME: float = 28.0 # 성문 도주 안전 타임아웃
const MAX_LIFETIME: float = 35.0  # 고아/고착 방지 하드 라이프타임

func setup(p_id: int, start_pos: Vector2, ev_id: int = -1, grid: GameGrid = null) -> void:
	global_position = start_pos
	event_id = ev_id
	state = ThiefState.STEALING
	is_arrestable = true
	is_escaping_victoriously = false
	steal_prep_timer = 4.0
	crime_timer = 4.0
	walk_anim_time = 0.0
	flee_elapsed = 0.0
	lifetime = 0.0
	bubble_text = "이 비단 보따리는 이제 내 것이다!"
	is_loot_sack_visible = false
	is_dead = false

	# 1. 스폰 즉시 목표 탈출 좌표(성 밖 스폰이거나 성문 미완공 시 외곽 경계/야산, 성내+성문 완공 시 성문) 선정
	target_gate_pos = BuildingManager.get_thief_escape_target_world_pos(global_position, grid)
	home_target_pos = target_gate_pos

	# 2. 순라청 매니저에 도둑 위치와 목표 도주 성문 좌표를 함께 전달하여 성문 인근 순라청 출동 요청!
	if SunlacheongManager.instance != null:
		SunlacheongManager.instance.dispatch_police_for_thief(self, target_gate_pos)

func update(delta: float) -> void:
	if is_dead:
		return

	lifetime += delta
	if lifetime >= MAX_LIFETIME:
		_on_escaped_through_gate()
		return

	match state:
		ThiefState.STEALING:
			steal_prep_timer -= delta
			crime_timer -= delta
			_play_stealing_motion(delta)
			if steal_prep_timer <= 0.0:
				_begin_flee_to_gate()

		ThiefState.FLEEING_TO_GATE, ThiefState.SWAGGER_HOME:
			flee_elapsed += delta
			walk_anim_time += delta

			# 팔자걸음(Swagger Walk) 고유 애니메이션: 좌우 뒤뚱거림 + 어깨 바운스 + 배 내밀기
			sprite_rotation_degrees = sin(walk_anim_time * 10.0) * 11.0
			sprite_position_y = -absf(cos(walk_anim_time * 10.0)) * 4.5
			sprite_scale = Vector2(1.08, 0.95)

			# 목표 성문을 향해 이동 (성문 밖으로 나가기 전까지 is_arrestable = true 유지되어 포졸이 닿으면 체포됨)
			global_position = global_position.move_toward(target_gate_pos, (flee_speed * 0.85 * 30.0) * delta)

			# 포졸에게 안 잡히고 성문에 도착하거나 제한 시간 초과 시 탈출 성공!
			if global_position.distance_to(target_gate_pos) <= 20.0 or flee_elapsed >= MAX_FLEE_TIME:
				_on_escaped_through_gate()

		ThiefState.ARRESTED:
			# 포졸에게 붙잡힌 상태: 팔자걸음 즉시 멈추고 포졸을 따라 관아로 압송됨
			sprite_rotation_degrees = 0.0
			sprite_position_y = 0.0
			sprite_scale = Vector2.ONE

func _play_stealing_motion(delta: float) -> void:
	walk_anim_time += delta
	sprite_position_y = sin(walk_anim_time * 6.0) * 2.0

func _begin_flee_to_gate() -> void:
	state = ThiefState.FLEEING_TO_GATE
	is_arrestable = true # 성문 도주 중에도 상시 체포 가능!
	is_escaping_victoriously = true
	is_loot_sack_visible = true # 훔친 보따리 착용
	bubble_text = "세상 살기 편하구만"

func _on_escaped_through_gate() -> void:
	if not is_arrestable:
		return
	is_arrestable = false
	CityStats.add_morale(-2) # 성문 밖 도주 허용 시 치안 페널티
	resolve_and_remove()

func on_police_arrived() -> void:
	if not is_arrestable:
		return
	state = ThiefState.ARRESTED
	bubble_text = "포박되었습니다! 아이쿠 잘못했습니다!"
	is_loot_sack_visible = false

func resolve_and_remove() -> void:
	is_dead = true
	bubble_text = ""
	is_loot_sack_visible = false
