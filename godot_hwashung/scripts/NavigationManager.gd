extends Node
class_name NavigationManager

## [A* 길찾기 프레임 예산 스케줄러 & 비동기 경로 분산 처리 엔진]
## 수백 명의 NPC 및 군사/도적이 동시에 경로를 탐색하여 발생하는 CPU 스파이크를 방지하기 위해
## 프레임당 길찾기 연산을 최대 4회(MAX_PATHS_PER_FRAME)로 제한하는 큐 스케줄러입니다.

static var instance: NavigationManager = null

var _path_request_queue: Array[Dictionary] = []
const MAX_PATHS_PER_FRAME: int = 4

var astar_grid: AStarGrid2D = null

func _init() -> void:
	if instance == null:
		instance = self

func _ready() -> void:
	if instance == null:
		instance = self

## 비동기 경로 요청 등록
func request_path_async(requester: Variant, start_pos: Vector2i, end_pos: Vector2i, callback: Callable) -> void:
	_path_request_queue.append({
		"requester": requester,
		"start": start_pos,
		"end": end_pos,
		"callback": callback
	})

func _process(_delta: float) -> void:
	process_path_queue(MAX_PATHS_PER_FRAME)

## 프레임당 최대 4회 경로 계산 처리
func process_path_queue(limit: int = MAX_PATHS_PER_FRAME) -> void:
	var processed: int = 0
	while not _path_request_queue.is_empty() and processed < limit:
		var req: Dictionary = _path_request_queue.pop_front()
		var req_node: Variant = req.get("requester", null)
		var cb: Callable = req.get("callback", Callable())

		var valid_requester: bool = true
		if req_node is Object:
			valid_requester = is_instance_valid(req_node)

		if valid_requester and cb.is_valid():
			var path: PackedVector2Array = calculate_astar_path(req["start"], req["end"])
			cb.call(path)
		processed += 1

## A* 경로 계산
func calculate_astar_path(start_pos: Vector2i, end_pos: Vector2i) -> PackedVector2Array:
	if astar_grid != null and astar_grid.is_in_boundsv(start_pos) and astar_grid.is_in_boundsv(end_pos):
		return astar_grid.get_point_path(start_pos, end_pos)
	
	# 간단한 맨해튼/체비쇼프 선형 폴백 경로
	var res := PackedVector2Array()
	res.append(Vector2(start_pos))
	res.append(Vector2(end_pos))
	return res
