extends Node2D
class_name CitizenNPC

const SpriteCacheManager = preload("res://scripts/autoload/SpriteCacheManager.gd")

## [경량화 스프라이트 기반 NPC 엔티티 노드]
## _draw()를 전면 폐지하고 자식 Sprite2D와 VRAM 캐시 텍스처를 단일 참조합니다.
## 카메라 가시 타일 수(400칸 / 300칸) 기준 2단계 가시성 LOD 적용:
## - 400칸 이하: 일반 시민 NPC 본체 노출 및 스프라이트 애니메이션 갱신
## - 300칸 이하: 일반 시민 NPC 말풍선(대사) 노출
## - 특수 개체(세시풍속, 도둑, 도적, 반란군, 호랑이, 순라군, 장용영): 타일 수 무관 상시 표시
## - 백그라운드 활동 연속성 보장: 줌 상태나 화면 밖 여부와 무관하게 논리 좌표 이동은 상시 실행

enum WalkDirection { UP_LEFT = 0, UP_RIGHT = 1, DOWN_LEFT = 2, DOWN_RIGHT = 3 }
enum NPCBehaviorState { IDLE = 0, WALKING = 1, PERFORMING_JOB = 2 }

@export var npc_type_id: String = "citizen_male"
@export var is_special_entity: bool = false
@export var is_always_visible: bool = false
@export var is_participating_custom: bool = false

var direction: WalkDirection = WalkDirection.DOWN_RIGHT
var behavior_state: NPCBehaviorState = NPCBehaviorState.IDLE
var job_action_type: String = "NONE"

var anim_timer: float = 0.0
var current_frame: int = 0

var has_active_dialogue: bool = false
var speech_bubble_node: Control = null

func set_custom_participation(participating: bool = true) -> void:
	is_participating_custom = participating
	if participating:
		is_special_entity = true
		is_always_visible = true

var sprite: Sprite2D = null
var prop_sprite: Sprite2D = null
var shadow_sprite: Sprite2D = null

var logic_throttle_timer: float = 0.0
const THROTTLE_INTERVAL: float = 0.5

var current_grid_pos: Vector2 = Vector2.ZERO
var target_grid_pos: Vector2 = Vector2.ZERO
var move_progress: float = 1.0
var move_speed: float = 1.0
var anim_phase: float = 0.0
var current_bubble_node: Control = null

var active_path: Array[Vector2i] = []
var path_index: int = 0
var daily_schedule_timer: float = 0.0

func _init(p_type: String = "citizen_male") -> void:
	npc_type_id = p_type

func _ready() -> void:
	_setup_nodes()
	if is_special():
		SpecialEntityManager.register_special(self)

func _setup_nodes() -> void:
	# 1. 발밑 그림자 노드 (LOD 0 전용)
	if shadow_sprite == null:
		shadow_sprite = Sprite2D.new()
		shadow_sprite.name = "Shadow"
		shadow_sprite.centered = true
		shadow_sprite.position = Vector2(0, 0)
		shadow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shadow_sprite.texture = SpriteCacheManager.get_or_create_texture("npcs", "npc_shadow", Vector2i(24, 12))
		add_child(shadow_sprite)

	# 2. 본체 8프레임 (45도 대각선 4방향 x 2모션 보행) 스프라이트
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite"
		sprite.centered = true
		sprite.offset = Vector2(0, -18.0) # 발 위치 (24, 42) 기준 앵커링
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.hframes = 2
		sprite.vframes = 4
		sprite.frame = 0
		add_child(sprite)

	# 3. 소품/지게 보따리 노드 (LOD 0 전용)
	if prop_sprite == null:
		prop_sprite = Sprite2D.new()
		prop_sprite.name = "Prop"
		prop_sprite.centered = true
		prop_sprite.position = Vector2(0, -22.0)
		prop_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		prop_sprite.texture = SpriteCacheManager.get_or_create_texture("npcs", "prop_pack_luggage", Vector2i(16, 16))
		add_child(prop_sprite)

	_update_texture()

func set_npc_type(p_type: String) -> void:
	if npc_type_id != p_type:
		npc_type_id = p_type
		_update_texture()

func set_job_action(p_action: String) -> void:
	job_action_type = p_action
	if p_action != "" and p_action != "NONE":
		behavior_state = NPCBehaviorState.PERFORMING_JOB
	else:
		behavior_state = NPCBehaviorState.IDLE

func _update_texture() -> void:
	if sprite != null:
		var sheet_id: String = npc_type_id + "_sheet"
		var tex: Texture2D = SpriteCacheManager.get_npc_texture(sheet_id)
		if tex == null:
			tex = SpriteCacheManager.get_or_create_texture("npcs", sheet_id, Vector2i(96, 192))
		sprite.texture = tex
		sprite.hframes = 2
		sprite.vframes = 4
		_apply_directional_sprite_frame()

## 유효 이동 경로 존재 여부 검사
func has_valid_path() -> bool:
	return not active_path.is_empty() and path_index < active_path.size()

## 경로를 따른 논리 이동 전진 (순수 수학 연산 및 대각선 4방향 자동 추적)
func _advance_along_path(delta: float) -> void:
	if not has_valid_path():
		if behavior_state == NPCBehaviorState.WALKING:
			behavior_state = NPCBehaviorState.PERFORMING_JOB if (job_action_type != "" and job_action_type != "NONE") else NPCBehaviorState.IDLE
		return
	var dest_tile: Vector2i = active_path[path_index]
	var dest_world := Vector2(
		(float(dest_tile.x) - float(dest_tile.y)) * 32.0,
		(float(dest_tile.x) + float(dest_tile.y)) * 16.0
	)
	var dir: Vector2 = (dest_world - global_position).normalized()
	if dir.length_squared() > 0.01:
		behavior_state = NPCBehaviorState.WALKING
		if dir.y < 0.0:
			direction = WalkDirection.UP_LEFT if dir.x <= 0.0 else WalkDirection.UP_RIGHT
		else:
			direction = WalkDirection.DOWN_LEFT if dir.x <= 0.0 else WalkDirection.DOWN_RIGHT

	var step: float = move_speed * 48.0 * delta
	if global_position.distance_to(dest_world) <= maxf(step, 4.0):
		global_position = dest_world
		path_index += 1
		if path_index >= active_path.size():
			behavior_state = NPCBehaviorState.PERFORMING_JOB if (job_action_type != "" and job_action_type != "NONE") else NPCBehaviorState.IDLE
	else:
		global_position += dir * step

## 일상 스케줄 결정 및 대기 처리
func _decide_next_daily_schedule(delta: float) -> void:
	daily_schedule_timer += delta
	if daily_schedule_timer >= 5.0:
		daily_schedule_timer = 0.0
		if behavior_state == NPCBehaviorState.WALKING and not has_valid_path():
			behavior_state = NPCBehaviorState.PERFORMING_JOB if (job_action_type != "" and job_action_type != "NONE") else NPCBehaviorState.IDLE

## 줌 상태와 무관하게 항상 돌아가는 가벼운 백그라운드 일상 시뮬레이션
func update_logical_activity(delta: float) -> void:
	if has_valid_path():
		_advance_along_path(delta)
	else:
		_decide_next_daily_schedule(delta)
	update_simulation_logic(delta)

## 화면에 보일 때(<= 400칸 & 카메라 내부)만 돌아가는 스프라이트 연출 및 FSM
func update_visual_animation(delta: float, is_in_high_lod: bool = true) -> void:
	if not is_in_high_lod:
		return

	anim_timer += delta
	var frame_interval: float = 0.18 if behavior_state == NPCBehaviorState.WALKING else 0.3

	if anim_timer >= frame_interval:
		anim_timer = 0.0

		match behavior_state:
			NPCBehaviorState.WALKING:
				current_frame = (current_frame + 1) % 2
				_apply_directional_sprite_frame()
			NPCBehaviorState.PERFORMING_JOB:
				current_frame = (current_frame + 1) % _get_job_max_frames(job_action_type)
				_apply_job_action_sprite_frame()
			NPCBehaviorState.IDLE:
				current_frame = 0
				_apply_directional_sprite_frame()

	# 말풍선 위치 실시간 동기화
	if speech_bubble_node != null and is_instance_valid(speech_bubble_node):
		speech_bubble_node.global_position = global_position + Vector2(0.0, -32.0)
	elif current_bubble_node != null and is_instance_valid(current_bubble_node):
		current_bubble_node.global_position = global_position + Vector2(0.0, -32.0)

func _apply_directional_sprite_frame() -> void:
	if sprite == null or sprite.hframes < 2 or sprite.vframes < 4:
		return
	var row_map: Array[int] = [2, 3, 0, 1] # WalkDirection (0:UP_LEFT, 1:UP_RIGHT, 2:DOWN_LEFT, 3:DOWN_RIGHT) -> 시트 행 (0:DL, 1:DR, 2:UL, 3:UR)
	var row_offset: int = row_map[clampi(int(direction), 0, 3)]
	sprite.frame = (row_offset * 2) + (current_frame % 2)

func _apply_job_action_sprite_frame() -> void:
	if sprite == null or sprite.hframes < 2 or sprite.vframes < 4:
		return
	var row_map: Array[int] = [2, 3, 0, 1]
	var row_offset: int = row_map[clampi(int(direction), 0, 3)]
	sprite.frame = (row_offset * 2) + (current_frame % 2)

func _get_job_max_frames(_action: String) -> int:
	return 2

## 300칸 이하(또는 특수 개체)일 때만 말풍선 UI 활성화
func set_bubble_enabled(enabled: bool) -> void:
	var can_show: bool = enabled and has_active_dialogue
	if is_special():
		can_show = has_active_dialogue

	if speech_bubble_node != null and is_instance_valid(speech_bubble_node):
		speech_bubble_node.visible = can_show
	if current_bubble_node != null and is_instance_valid(current_bubble_node):
		current_bubble_node.visible = can_show

## 세시풍속 참여 여부 판정
func is_participating_in_custom() -> bool:
	return is_participating_custom

## 특수 개체 여부 판정
func is_special() -> bool:
	return is_special_entity or is_always_visible or is_participating_custom or SpecialEntityManager.is_special_entity(self)

## 시뮬레이션 논리 이동 (LOD 및 화면 여부와 무관하게 100% 정상 가동)
func update_simulation_logic(delta: float) -> void:
	anim_phase += delta
	move_progress = minf(1.0, move_progress + delta * move_speed)

## LOD 단계별 시각 디테일 차등 갱신
func apply_lod_visuals(current_lod: int, delta: float) -> void:
	match current_lod:
		0: # [LOD 0: 근거리 상세] 전체 애니메이션 + 소품 + 그림자
			visible = true
			if sprite != null:
				sprite.visible = true
				update_visual_animation(delta, true)
				sprite.offset.y = -20.0 + sin(anim_phase * 8.0) * 1.5
			if prop_sprite != null:
				prop_sprite.visible = true
				prop_sprite.position.y = -22.0 + sin(anim_phase * 8.0) * 1.5
			if shadow_sprite != null:
				shadow_sprite.visible = true

		1: # [LOD 1: 중거리 표준] 2모션 보행 + 소품/그림자 숨김
			visible = true
			if sprite != null:
				sprite.visible = true
				update_visual_animation(delta, true)
				sprite.offset.y = -20.0
			if prop_sprite != null:
				prop_sprite.visible = false
			if shadow_sprite != null:
				shadow_sprite.visible = false

		2: # [LOD 2: 원거리 조감] 개별 스프라이트 컬링 (특수 개체는 유지)
			if is_special():
				visible = true
				if sprite != null:
					sprite.visible = true
					update_visual_animation(delta, true)
					sprite.offset.y = -20.0
			else:
				visible = false
				if sprite != null:
					sprite.visible = false
				if prop_sprite != null:
					prop_sprite.visible = false
				if shadow_sprite != null:
					shadow_sprite.visible = false

## 화면 밖 (Off-Screen): 0.5초마다 논리 갱신 스로틀링 (CPU 절약)
func update_logical_step_throttled(delta: float) -> void:
	logic_throttle_timer += delta
	if logic_throttle_timer >= THROTTLE_INTERVAL:
		logic_throttle_timer -= THROTTLE_INTERVAL
		update_simulation_logic(THROTTLE_INTERVAL)

## 화면 안 (In-View): 현재 LOD 단계에 맞춰 시각 디테일 갱신
func update_visual_step(delta: float) -> void:
	var lod: int = CameraLODController.get_lod()
	apply_lod_visuals(lod, delta)

## [400칸 뷰 전용 시각 & 말풍선 통합 갱신]
func update_visual_and_bubble(delta: float) -> void:
	apply_lod_visuals(0, delta)
	if speech_bubble_node != null and is_instance_valid(speech_bubble_node):
		speech_bubble_node.global_position = global_position + Vector2(0.0, -32.0)
	elif current_bubble_node != null and is_instance_valid(current_bubble_node):
		current_bubble_node.global_position = global_position + Vector2(0.0, -32.0)

## [말풍선 풀 연동 표시]
func show_speech_bubble(text: String, name_tag: String = "", duration: float = 3.0) -> void:
	if current_bubble_node != null:
		hide_speech_bubble()
	var mgr := _find_citizen_manager()
	if mgr != null and mgr.has_method("acquire_speech_bubble"):
		var b_variant: Variant = mgr.call("acquire_speech_bubble", self, text, name_tag, duration)
		if b_variant is Control:
			current_bubble_node = b_variant as Control
			speech_bubble_node = current_bubble_node
			has_active_dialogue = true

## [말풍선 풀 반납 및 숨김]
func hide_speech_bubble() -> void:
	has_active_dialogue = false
	if current_bubble_node != null:
		var mgr := _find_citizen_manager()
		if mgr != null and mgr.has_method("release_speech_bubble"):
			mgr.call("release_speech_bubble", current_bubble_node)
		elif current_bubble_node.has_method("clear_data"):
			current_bubble_node.call("clear_data")
		current_bubble_node = null
	speech_bubble_node = null

var citizen_manager_ref: Node = null

func _exit_tree() -> void:
	hide_speech_bubble()
	if is_special():
		SpecialEntityManager.unregister_special(self)

func _find_citizen_manager() -> Node:
	if citizen_manager_ref != null and is_instance_valid(citizen_manager_ref):
		return citizen_manager_ref
	var cur: Node = get_parent()
	while cur != null:
		if cur.get_class() == "CitizenManager" or cur.name == "CitizenManager" or cur.has_method("acquire_speech_bubble"):
			citizen_manager_ref = cur
			return cur
		if cur.has_node("CitizenManager"):
			citizen_manager_ref = cur.get_node("CitizenManager")
			return citizen_manager_ref
		cur = cur.get_parent()
	return null
