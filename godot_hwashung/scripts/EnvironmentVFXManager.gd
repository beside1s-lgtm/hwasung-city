extends Node2D
class_name EnvironmentVFXManager

const SpriteCacheManager = preload("res://scripts/autoload/SpriteCacheManager.gd")

## [환경 VFX 매니저: 굴뚝 연기 파티클 풀링 & 수변 물결 LOD 제어]
## 민가/공방 굴뚝 연기를 CPUParticles2D 오브젝트 풀(최대 150개 하드캡)로 관리하며,
## 카메라 LOD 3단계에 따라 방출량(LOD 0: 6개, LOD 1: 3개, LOD 2: 0개 정지)을 통제합니다.

const MAX_PARTICLES_HARD_CAP := 150
var _particle_pool: Array[CPUParticles2D] = []
var _active_emitters: Dictionary = {} # tile_pos (Vector2i) -> CPUParticles2D

var grid: GameGrid = null
var city: CityLayer = null
var current_lod: int = CameraLODController.LODLevel.MEDIUM

var _smoke_texture: Texture2D = null
var _ripple_texture: Texture2D = null

func setup(g: GameGrid, c: CityLayer) -> void:
	grid = g
	city = c
	z_index = 920 # PORT-TRACE [을묘원행 안 보임]: 지형·건물 조각 그림(z 10~76) 위에 오도록 — 예전 값은 조각에 덮였다

	_smoke_texture = SpriteCacheManager.get_or_create_texture("vfx", "smoke_puff", Vector2i(16, 16))
	_ripple_texture = SpriteCacheManager.get_or_create_texture("vfx", "water_ripple", Vector2i(64, 32))

	_init_pool()

	if CameraLODController.instance != null:
		CameraLODController.instance.lod_changed.connect(_on_lod_changed)
		current_lod = CameraLODController.get_lod()

func _init_pool() -> void:
	for i in range(MAX_PARTICLES_HARD_CAP):
		var p := CPUParticles2D.new()
		p.name = "Smoke_%d" % i
		p.texture = _smoke_texture
		p.emitting = false
		p.amount = 6
		p.lifetime = 2.2
		p.preprocess = 0.5
		p.speed_scale = 1.0
		p.explosiveness = 0.0
		p.randomness = 0.3
		p.direction = Vector2(0.3, -1.0)
		p.spread = 25.0
		p.gravity = Vector2(4.0, -12.0)
		p.initial_velocity_min = 12.0
		p.initial_velocity_max = 24.0
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.3
		p.color = Color(0.9, 0.9, 0.92, 0.75)
		add_child(p)
		_particle_pool.append(p)

func _on_lod_changed(new_lod: int) -> void:
	current_lod = new_lod
	_apply_lod_to_all_emitters()

func _apply_lod_to_all_emitters() -> void:
	match current_lod:
		CameraLODController.LODLevel.HIGH:
			for p in _active_emitters.values():
				p.amount = 6
				p.emitting = true
		CameraLODController.LODLevel.MEDIUM:
			for p in _active_emitters.values():
				p.amount = 3
				p.emitting = true
		CameraLODController.LODLevel.LOW:
			for p in _active_emitters.values():
				p.emitting = false

## 카메라 뷰포트 컬링 및 굴뚝 파티클 갱신 (매 프레임)
func _process(_delta: float) -> void:
	if grid == null or city == null:
		return

	if current_lod == CameraLODController.LODLevel.LOW:
		# LOD 2: 원거리 조감에서는 파티클 연산 전면 정지
		for p in _active_emitters.values():
			if p.emitting:
				p.emitting = false
		return

	var cam_rect: Rect2 = CameraLODController.get_active_camera_world_rect().grow(48.0)

	# 활성 에미터 카메라 뷰포트 컬링
	for p: CPUParticles2D in _active_emitters.values():
		var in_view: bool = cam_rect.has_point(p.global_position)
		if p.emitting != in_view:
			p.emitting = in_view

## 가옥 및 공방 굴뚝 위치에 연기 에미터 바인딩
func register_chimney(tile_pos: Vector2i, world_pos: Vector2) -> void:
	if _active_emitters.has(tile_pos):
		return
	if _active_emitters.size() >= MAX_PARTICLES_HARD_CAP:
		return

	# 풀에서 비활성 파티클 인출
	for p: CPUParticles2D in _particle_pool:
		if not p.emitting and not _active_emitters.values().has(p):
			p.global_position = world_pos + Vector2(0, -32.0)
			_active_emitters[tile_pos] = p
			p.amount = 6 if current_lod == CameraLODController.LODLevel.HIGH else 3
			p.emitting = current_lod != CameraLODController.LODLevel.LOW
			break

func unregister_chimney(tile_pos: Vector2i) -> void:
	if _active_emitters.has(tile_pos):
		var p: CPUParticles2D = _active_emitters[tile_pos]
		p.emitting = false
		_active_emitters.erase(tile_pos)

func clear_all_chimneys() -> void:
	for p: CPUParticles2D in _active_emitters.values():
		p.emitting = false
	_active_emitters.clear()

func get_active_emitter_count() -> int:
	var count: int = 0
	for p: CPUParticles2D in _active_emitters.values():
		if p.emitting:
			count += 1
	return count
