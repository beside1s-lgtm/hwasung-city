extends Node
class_name CameraLODController

## [카메라 줌 3단계 LOD 제어 및 브로드캐스터]
## 카메라 줌 배율을 감시하여 히스테리시스(여유폭 0.05) 기반으로 LOD 단계를 산출하고,
## 시민 NPC 스프라이트, 굴뚝 연기 파티클, 하천 물결 오버레이의 디테일 단계를 일괄 제어합니다.

enum LODLevel {
	HIGH = 0,   ## 근거리 상세 (Zoom >= 1.5)
	MEDIUM = 1, ## 중거리 표준 (0.8 <= Zoom < 1.5)
	LOW = 2     ## 원거리 조감 (Zoom < 0.8)
}

@warning_ignore("unused_signal")
signal lod_changed(new_lod: int)

static var instance: CameraLODController = null
static var current_lod: int = LODLevel.MEDIUM
static var current_zoom: float = 1.0
static var active_camera: CameraController = null
static var test_override_rect: Rect2 = Rect2()

const HYSTERESIS: float = 0.05

func _init() -> void:
	instance = self

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

static func register_camera(cam: CameraController) -> void:
	active_camera = cam
	if cam != null and instance != null:
		instance.check_zoom_lod(cam.zoom.x)

static func get_lod() -> int:
	return current_lod

## 현재 활성 카메라의 월드 영역 반환
static func get_active_camera_world_rect() -> Rect2:
	if test_override_rect.size != Vector2.ZERO:
		return test_override_rect
	if active_camera != null and is_instance_valid(active_camera):
		var vp_size: Vector2 = active_camera.get_viewport_rect().size
		var zx: float = maxf(0.01, active_camera.zoom.x)
		var world_size: Vector2 = vp_size / zx
		var top_left: Vector2 = active_camera.position - world_size * 0.5
		return Rect2(top_left, world_size)
	return Rect2(-1000.0, -1000.0, 2000.0, 2000.0)

## 줌 배율에 따른 LOD 단계 판정 및 히스테리시스 방어
func check_zoom_lod(zoom_val: float) -> void:
	current_zoom = zoom_val
	var prev_lod: int = current_lod
	var new_lod: int = prev_lod

	match prev_lod:
		LODLevel.HIGH:
			if zoom_val < 0.8 - HYSTERESIS:
				new_lod = LODLevel.LOW
			elif zoom_val < 1.5 - HYSTERESIS:
				new_lod = LODLevel.MEDIUM
		LODLevel.MEDIUM:
			if zoom_val >= 1.5 + HYSTERESIS:
				new_lod = LODLevel.HIGH
			elif zoom_val < 0.8 - HYSTERESIS:
				new_lod = LODLevel.LOW
		LODLevel.LOW:
			if zoom_val >= 1.5 + HYSTERESIS:
				new_lod = LODLevel.HIGH
			elif zoom_val >= 0.8 + HYSTERESIS:
				new_lod = LODLevel.MEDIUM

	if new_lod != prev_lod:
		current_lod = new_lod
		lod_changed.emit(new_lod)
