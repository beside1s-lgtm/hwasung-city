extends Node2D
class_name WorldMarkerManager

## 월드 현판 및 마커 관리자 (사대문, 남수문, 화홍문, 매향교 등)
## GateSignboard 씬 인스턴스화 및 상공 부유 위치 동기화, LOD 컬링 일원화 관리 (Single Source of Truth)

const GateSignboardScene: PackedScene = preload("res://scenes/GateSignboard.tscn")

## 동일 건물 중복 생성 방지 캐시 (ID -> GateSignboard)
var active_signboards: Dictionary = {}

## 하위 호환용 프로퍼티 별칭
@warning_ignore("unused_private_class_variable")
var _markers: Dictionary:
	get:
		return active_signboards
	set(v):
		active_signboards = v

func _ready() -> void:
	z_index = 1050 # 최상단 렌더링(사람 위, 말풍선 아래) # PORT-TRACE [을묘원행 안 보임]: 지형·건물 조각 그림(z 10~76) 위에 오도록 — 예전 값은 조각에 덮였다
	cleanup_duplicate_signboards()

## 건물 식별자 정규화 (사대문, 수문, 교량 ID 단일화)
static func normalize_building_id(raw_id: String, display_name: String = "") -> String:
	var lower_id: String = raw_id.to_lower()
	var dname: String = display_name
	if lower_id.contains("jangan") or dname.contains("장안문"):
		return "jangan_mun"
	elif lower_id.contains("paldal") or dname.contains("팔달문"):
		return "paldal_mun"
	elif lower_id.contains("hwaseo") or dname.contains("화서문"):
		return "hwaseo_mun"
	elif lower_id.contains("changryong") or lower_id.contains("changnyong") or dname.contains("창룡문"):
		return "changryong_mun"
	elif lower_id.contains("hwahong") or dname.contains("화홍문"):
		return "hwahong_mun"
	elif lower_id.contains("namsu") or dname.contains("남수문"):
		return "namsu_mun"
	elif lower_id.contains("maehwang") or lower_id.contains("maehyang") or dname.contains("매향교"):
		return "maehwang_gyo"
	return raw_id

## 건물별 지붕 처마 상단 Y 부유 오프셋 (center.y - roof_offset_y)
static func get_roof_offset_y(normalized_id: String, display_name: String = "") -> float:
	match normalized_id:
		"jangan_mun":
			return 114.0
		"paldal_mun":
			return 114.0
		"hwaseo_mun":
			return 92.0 # 문 그림 1.6배
		"changryong_mun":
			return 92.0
		"hwahong_mun":
			return 54.0
		"namsu_mun":
			return 51.0
		"maehwang_gyo":
			return 24.0
		_:
			if normalized_id.begins_with("gate_") or display_name.contains("문"):
				return 88.0 # 이름 없는 문 1.35배
			return 0.0

## 현판 등록 또는 갱신 (SSOT 단일 인스턴스 보장)
func register_signboard(building_id: String, world_pos: Vector2, display_name: String) -> GateSignboard:
	var norm_id: String = normalize_building_id(building_id, display_name)

	# 1. 캐시에 유효한 기존 노드가 있으면 위치와 이름만 갱신 후 반환 (중복 생성 O(1) 차단)
	if active_signboards.has(norm_id) and is_instance_valid(active_signboards[norm_id]):
		var existing: GateSignboard = active_signboards[norm_id] as GateSignboard
		existing.position = world_pos
		if display_name != "":
			existing.setup(display_name)
		return existing

	# 2. 씬 트리에 중복/잔존 노드가 있는지 방어 검사하여 정리
	var found_in_tree: GateSignboard = null
	var target_node_name: String = "Signboard_" + norm_id
	for child: Node in get_children():
		if not is_instance_valid(child):
			continue
		if child is GateSignboard:
			# 특수 건물(sp_) 현판은 이름이 같아도(서당 여러 곳) 따로 둔다
			if child.name == target_node_name or (display_name != "" and not building_id.begins_with("sp_") and (child as GateSignboard).gate_name == display_name):
				if found_in_tree == null:
					found_in_tree = child as GateSignboard
				else:
					child.queue_free() # 2개 이상 중복된 기존 노드 즉시 안전 제거

	if found_in_tree != null:
		found_in_tree.position = world_pos
		if display_name != "":
			found_in_tree.setup(display_name)
		active_signboards[norm_id] = found_in_tree
		return found_in_tree

	# 3. 신규 단일 노드 인스턴스화
	var signboard: GateSignboard = null
	if GateSignboardScene != null:
		signboard = GateSignboardScene.instantiate() as GateSignboard
	else:
		signboard = GateSignboard.new()

	signboard.name = target_node_name
	signboard.setup(display_name)
	signboard.position = world_pos
	add_child(signboard)
	active_signboards[norm_id] = signboard
	return signboard

## 이전 호출부 호환용 register_marker 래퍼
func register_marker(id: String, korean_name: String, world_pos: Vector2) -> GateSignboard:
	return register_signboard(id, world_pos, korean_name)

## 기존 세이브 로드 시 맵에 남아있을 수 있는 중복 현판 노드 전수 검출 및 안전 정리
func cleanup_duplicate_signboards() -> void:
	var seen_ids: Dictionary = {} # norm_id -> GateSignboard
	for child: Node in get_children():
		if not is_instance_valid(child):
			continue
		if not (child is GateSignboard):
			continue

		var s_node: GateSignboard = child as GateSignboard
		var raw_name: String = str(s_node.name).trim_prefix("Signboard_")
		var norm_id: String = normalize_building_id(raw_name, s_node.gate_name)

		if seen_ids.has(norm_id):
			# 이미 존재하는 동일 건물 현판이면 즉시 중복 노드 삭제
			child.queue_free()
		else:
			seen_ids[norm_id] = s_node
			active_signboards[norm_id] = s_node

## 특정 현판 제거
func remove_marker(id: String) -> void:
	var norm_id: String = normalize_building_id(id)
	if active_signboards.has(norm_id):
		var sign_node: Variant = active_signboards[norm_id]
		if is_instance_valid(sign_node):
			sign_node.queue_free()
		active_signboards.erase(norm_id)

## 특정 현판 조회
func get_marker(id: String) -> GateSignboard:
	var norm_id: String = normalize_building_id(id)
	var sign_node: Variant = active_signboards.get(norm_id, null)
	if is_instance_valid(sign_node) and sign_node is GateSignboard:
		return sign_node as GateSignboard
	return null

## 전체 현판 초기화
func clear_all_markers() -> void:
	for id: String in active_signboards.keys():
		var sign_node: Variant = active_signboards[id]
		if is_instance_valid(sign_node):
			sign_node.queue_free()
	active_signboards.clear()

	# 자식 노드 중 잔여 노드 전수 안전 제거
	for child in get_children():
		if is_instance_valid(child):
			child.queue_free()
