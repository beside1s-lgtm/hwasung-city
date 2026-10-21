extends RefCounted
class_name PatrolOfficerNPC

## [순라군(포졸) 치안 출동 및 관아 압송 FSM]
## 1. FSM 상태 머신:
##    - IDLE_PATROL: 평시 순라청 대기 및 주변 순찰
##    - DISPATCH: 저잣거리 분쟁 현장으로 신속 출동
##    - SUPPRESS: 곤봉(육모방망이) 제압 (난동 훈방 / 소매치기 오라줄 포박)
##    - ESCORT_TO_YUSUBU: 결박된 죄인을 화성유수부 관아 옥사로 도보 호송/압송
##    - RETURN_HOME: 임무 완수 후 순라청으로 복귀
## 2. 길찾기 교착(Stuck) 방지:
##    - 30초 이상 고착 시 강제 순간이동 또는 완료/복귀 루틴 수행
## 3. 오브젝트 풀링 지원:
##    - 순라청 귀환 시 풀에 반환되어 재사용됨

enum State {
	IDLE = 0,
	MOVE_TO_CRIME = 1,
	ARRESTING = 2,
	ESCORT_TO_YUSUBU = 3
}

enum OfficerState {
	IDLE_PATROL = 0,
	DISPATCH = 1,
	SUPPRESS = 2,
	ESCORT_TO_YUSUBU = 3,
	RETURN_HOME = 4
}

var id: int = 0
var state: int = OfficerState.IDLE_PATROL

var x: float = 0.0
var y: float = 0.0
var home_pos: Vector2i = Vector2i.ZERO
var target_pos: Vector2i = Vector2i.ZERO
var gwana_pos: Vector2i = Vector2i.ZERO
var yusubu_pos: Vector2 = Vector2.ZERO

var target_crime_node: Variant = null
var _arrest_timer: float = 1.5
var is_special_entity: bool = true
var is_always_visible: bool = true

var speed: float = 1.65 # 출동 시 신속 이동
var move_speed: float:
	get:
		return speed * 40.0
	set(val):
		speed = val / 40.0

var global_position: Vector2:
	get:
		return Vector2((float(x) - float(y)) * 32.0, (float(x) + float(y)) * 16.0)
	set(val):
		x = (val.x / 32.0 + val.y / 16.0) / 2.0
		y = (val.y / 16.0 - val.x / 32.0) / 2.0
var path: Array[Vector2i] = []
var path_index: int = 0
## 길 우선 길찾기(CitizenManager가 넣어 준다): (출발 칸, 도착 칸) → 칸 목록
static var path_provider: Callable = Callable()
var _repath_t: float = 0.0
var _path_dest: Vector2i = Vector2i(-999, -999)

## 압송 목적지: 관아(고을에 하나면 거기로). 관아가 없으면 포졸의 순라청으로 끌고 간다(행궁은 관아를 대신하지 않는다).
func _escort_dest_world() -> Vector2:
	var t: Vector2i = SunlacheongManager.gwana_anchor if SunlacheongManager.gwana_built else home_pos
	return Vector2((float(t.x) - float(t.y)) * 32.0, (float(t.x) + float(t.y)) * 16.0)

## 길 끝(목표 건물의 입구 칸)에 닿았는가
func _path_done() -> bool:
	return _path_dest.x > -999 and (_arrived or (not path.is_empty() and path_index >= path.size()))

func _tile_of_world(p: Vector2) -> Vector2i:
	return Vector2i(int(floor((p.x / 32.0 + p.y / 16.0) / 2.0)), int(floor((p.y / 16.0 - p.x / 32.0) / 2.0)))

## 목표 칸까지 길을 따라 걷는다(목표가 바뀌거나 1초마다 다시 잡음). 길 끝(입구)에 닿으면 멈춘다 — 건물 속으로 곧장 들어가지 않게.
var _arrived := false
func _walk_to_tile(dest: Vector2i, fallback_world: Vector2, delta: float) -> void:
	if not path_provider.is_valid():
		global_position = global_position.move_toward(fallback_world, move_speed * delta)
		return
	_repath_t -= delta
	var finished := _path_done()
	if dest != _path_dest or (_repath_t <= 0.0 and not finished):
		_repath_t = 1.0
		_path_dest = dest
		path = path_provider.call(Vector2i(int(floor(x)), int(floor(y))), dest)
		path_index = 0
		_arrived = path.is_empty() # 이미 입구에 있거나 길이 없음 — 그 자리에서 마친다
	if not path.is_empty() and path_index < path.size():
		_move_along_path(delta)

var target_event_id: int = -1
var tied_criminal_id: int = -1
var is_active: bool = false # 풀링 활성화 여부

var stuck_timer: float = 0.0
var _last_stuck_pos: Vector2 = Vector2.ZERO
var _local_stuck_timer: float = 0.0
var state_timer: float = 0.0
var suppress_timer: float = 0.0

var bubble_text: String = ""
var bubble_timer: float = 0.0
var anim_timer: float = 0.0

func setup_officer(p_id: int, p_home: Vector2i) -> void:
	id = p_id
	home_pos = p_home
	x = float(p_home.x) + 0.5
	y = float(p_home.y) + 0.5
	state = OfficerState.IDLE_PATROL
	is_active = false
	target_event_id = -1
	tied_criminal_id = -1
	path.clear()
	path_index = 0
	stuck_timer = 0.0
	state_timer = 0.0
	suppress_timer = 0.0
	bubble_text = ""
	bubble_timer = 0.0

## 출동 지시
func dispatch(ev_id: int, ev_loc: Vector2i, p_path: Array[Vector2i], custom_speed: float = 3.0, crime_node: Variant = null) -> void:
	is_active = true
	target_event_id = ev_id
	target_pos = ev_loc
	target_crime_node = crime_node
	state = State.MOVE_TO_CRIME
	speed = clampf(custom_speed, 1.0, 3.0)
	stuck_timer = 0.0
	state_timer = 0.0
	path = p_path
	path_index = 0
	bubble_text = "관군 긴급 출동이다! 길을 비켜라!"
	bubble_timer = 3.5

## 도둑 요격 및 긴급 체포 출동 임무 개시
func start_arrest_mission(crime_target: Variant, station_tile: Vector2i, p_speed: float, p_event_id: int = -1) -> void:
	is_active = true
	target_crime_node = crime_target
	target_event_id = p_event_id
	home_pos = station_tile
	x = float(station_tile.x) + 0.5
	y = float(station_tile.y) + 0.5
	state = State.MOVE_TO_CRIME
	_path_dest = Vector2i(-999, -999)
	_arrived = false
	path = []
	speed = clampf(p_speed, 1.0, 3.0)
	stuck_timer = 0.0
	state_timer = 0.0
	bubble_text = "관군 긴급 출동이다! 게 섰거라!"
	bubble_timer = 3.5
	is_special_entity = true
	is_always_visible = true
	SpecialEntityManager.register_special(self)

## 관아 압송 지시
func start_escort(crm_id: int, gw_pos: Vector2i, p_path: Array[Vector2i], crime_node: Variant = null) -> void:
	state = State.ESCORT_TO_YUSUBU
	tied_criminal_id = crm_id
	if crime_node != null:
		target_crime_node = crime_node
	gwana_pos = gw_pos
	yusubu_pos = _escort_dest_world()
	speed = 0.95 # 압송 시 죄인과 함께 보행
	stuck_timer = 0.0
	state_timer = 0.0
	path = p_path
	path_index = 0
	bubble_text = "오랏줄을 받아라! 관아 옥사로 가자!"
	bubble_timer = 3.5

## 순라청 귀대
func _return_to_station() -> void:
	target_crime_node = null
	state = State.IDLE
	reset_to_idle()

## 범죄자 도주 성공/시간 만료 시 추격 포기 및 순라청 복귀
func on_target_escaped() -> void:
	target_crime_node = null
	_return_to_station()
	bubble_text = "놓쳤구만! 순라청을 더 늘려야겠어!"
	bubble_timer = 3.0



## 순라청 복귀 지시
func return_to_base(p_path: Array[Vector2i]) -> void:
	state = OfficerState.RETURN_HOME
	tied_criminal_id = -1
	target_event_id = -1
	target_crime_node = null
	speed = 1.2
	stuck_timer = 0.0
	state_timer = 0.0
	path = p_path
	path_index = 0
	bubble_text = "치안 유지 완료! 순라청으로 귀대한다."
	bubble_timer = 2.5

## 풀 초기화 (순라청 복귀 완료)
func reset_to_idle() -> void:
	state = State.IDLE
	is_active = false
	target_event_id = -1
	tied_criminal_id = -1
	target_crime_node = null
	x = float(home_pos.x) + 0.5
	y = float(home_pos.y) + 0.5
	path.clear()
	path_index = 0
	stuck_timer = 0.0
	state_timer = 0.0
	bubble_text = ""
	bubble_timer = 0.0

## 도둑·난동꾼 체포 및 관아 압송 전용 FSM 루틴 (명세 규격)
func _process_arrest_logic(delta: float) -> void:
	match state:
		State.MOVE_TO_CRIME:
			stuck_timer += delta
			if not is_instance_valid(target_crime_node) or ("is_dead" in target_crime_node and bool(target_crime_node.is_dead)):
				_return_to_station()
				return

			# 범죄자가 이미 체포 불가능(시간 초과로 도주 성공) 상태인지 확인
			if "is_arrestable" in target_crime_node and not bool(target_crime_node.is_arrestable):
				on_target_escaped()
				return

			# 범죄 현장으로 실제 발걸음(경로) 이동 — 길을 따라(건물을 뚫고 가지 않게)
			_walk_to_tile(_tile_of_world(target_crime_node.global_position), target_crime_node.global_position, delta)
			if global_position.distance_to(target_crime_node.global_position) <= 36.0 or _path_done():
				state = State.ARRESTING
				_arrest_timer = 1.5
				stuck_timer = 0.0
				target_crime_node.on_police_arrived() # 즉시 행패 중단 및 '포박됨' 표시!
				bubble_text = "물러서라! 순라군이 진압한다!"
				bubble_timer = 2.5

		State.ARRESTING:
			_arrest_timer -= delta
			if _arrest_timer <= 0.0:
				state = State.ESCORT_TO_YUSUBU
				stuck_timer = 0.0
				yusubu_pos = _escort_dest_world()
				bubble_text = "오랏줄을 받아라! 관아 옥사로 가자!"
				bubble_timer = 3.5

		State.ESCORT_TO_YUSUBU:
			stuck_timer += delta
			# 함께 끌고 가던 죄인이 (다른 포졸 손에서) 오랏줄을 풀고 달아났으면 다시 쫓는다
			if is_instance_valid(target_crime_node) and "state" in target_crime_node \
					and int(target_crime_node.state) in [CriminalNPC.CriminalState.SWAGGER_HOME, CriminalNPC.CriminalState.FLEEING]:
				state = State.MOVE_TO_CRIME
				path.clear()
				path_index = 0
				_path_dest = Vector2i(-999, -999)
				bubble_text = "저놈이 달아난다! 게 섰거라!"
				bubble_timer = 2.5
				return
			# 포졸이 관아로 이동할 때 죄인도 포졸 뒤를 바짝 따라감 — 길을 따라
			_walk_to_tile(_tile_of_world(yusubu_pos), yusubu_pos, delta)
			if is_instance_valid(target_crime_node):
				target_crime_node.global_position = global_position + Vector2(-14.0, 0.0)

			# 관아 도착 시 죄인 디스폰 및 사건 완전 종료!
			if global_position.distance_to(yusubu_pos) < 24.0 or _path_done():
				# 관아가 없거나 옥이 가득 찼으면 죄인이 달아날 수 있다(SunlacheongManager가 판정)
				if is_instance_valid(target_crime_node) and SunlacheongManager.instance != null \
						and SunlacheongManager.instance.on_prisoner_delivered(target_crime_node):
					target_crime_node = null
					_return_to_station()
					return
				if is_instance_valid(target_crime_node):
					target_crime_node.resolve_and_remove() # 범죄자 노드 완전 삭제
				CityStats.add_morale(1)
				_return_to_station()

## 매 프레임 업데이트
func update(delta: float) -> Dictionary:
	anim_timer += delta
	state_timer += delta
	if bubble_timer > 0.0:
		bubble_timer -= delta

	var result := {
		"officer_id": id,
		"state": state,
		"reached_target": false,
		"reached_gwana": false,
		"reached_home": false,
		"stuck_healed": false
	}

	# crime_node 연동 시 명세 FSM 최우선 수행
	if target_crime_node != null and is_instance_valid(target_crime_node):
		var prev_st: int = state
		_process_arrest_logic(delta)
		result["state"] = state
		if state == State.ARRESTING or (prev_st == State.MOVE_TO_CRIME and state == State.ARRESTING):
			result["reached_target"] = true
		if state == State.ESCORT_TO_YUSUBU and prev_st == State.ARRESTING:
			result["suppress_done"] = true
		if state == State.IDLE and prev_st == State.ESCORT_TO_YUSUBU:
			result["reached_gwana"] = true
			result["reached_home"] = true
		return result

	match state:
		OfficerState.IDLE_PATROL:
			# 순라청 주변 배회
			x = float(home_pos.x) + 0.5 + sin(anim_timer * 1.5) * 0.15
			y = float(home_pos.y) + 0.5 + cos(anim_timer * 1.2) * 0.1

		OfficerState.DISPATCH:
			stuck_timer += delta
			_move_along_path(delta)

			# 목표 지점 도착 검사
			var target_vec := Vector2(float(target_pos.x) + 0.5, float(target_pos.y) + 0.5)
			if Vector2(x, y).distance_to(target_vec) <= 0.6 or path_index >= path.size():
				result["reached_target"] = true

			# 30초 초과 길찾기 교착(Stuck) 방지 -> 강제 순간이동
			if stuck_timer >= 30.0:
				x = target_vec.x
				y = target_vec.y
				result["reached_target"] = true
				result["stuck_healed"] = true
				stuck_timer = 0.0

		OfficerState.SUPPRESS:
			# 진압 액션 (육모방망이 휘두르기 및 포위 제압)
			suppress_timer += delta
			x += sin(anim_timer * 14.0) * 0.04 * delta
			y += cos(anim_timer * 12.0) * 0.04 * delta
			if suppress_timer >= 2.0:
				suppress_timer = 0.0
				result["suppress_done"] = true

		OfficerState.ESCORT_TO_YUSUBU:
			stuck_timer += delta
			_move_along_path(delta)

			# 관아 정문 도착 검사
			var gwana_vec := Vector2(float(gwana_pos.x) + 0.5, float(gwana_pos.y) + 0.5)
			if Vector2(x, y).distance_to(gwana_vec) <= 0.8 or path_index >= path.size():
				result["reached_gwana"] = true

			# 30초 Stuck 자가치유
			if stuck_timer >= 30.0:
				x = gwana_vec.x
				y = gwana_vec.y
				result["reached_gwana"] = true
				result["stuck_healed"] = true
				stuck_timer = 0.0

		OfficerState.RETURN_HOME:
			stuck_timer += delta
			_move_along_path(delta)

			# 순라청 복귀 도착 검사
			var home_vec := Vector2(float(home_pos.x) + 0.5, float(home_pos.y) + 0.5)
			if Vector2(x, y).distance_to(home_vec) <= 0.6 or path_index >= path.size():
				result["reached_home"] = true
				reset_to_idle()

			# 30초 Stuck 복귀 치유
			if stuck_timer >= 30.0:
				reset_to_idle()
				result["reached_home"] = true
				result["stuck_healed"] = true

	return result

## 경로를 따라 타일 이동
func _move_along_path(delta: float) -> void:
	if path.is_empty() or path_index >= path.size():
		return

	var cur_pos := Vector2(x, y)
	if cur_pos.distance_to(_last_stuck_pos) < 0.05:
		_local_stuck_timer += delta
	else:
		_last_stuck_pos = cur_pos
		_local_stuck_timer = 0.0

	# 3초 이상 동일 위치에 고착된 경우 다음 웨이포인트로 보간/스킵 (Anti-Stuck 규약)
	if _local_stuck_timer >= 3.0:
		_local_stuck_timer = 0.0
		path_index += 1
		if path_index < path.size():
			x = float(path[path_index].x) + 0.5
			y = float(path[path_index].y) + 0.5
			_last_stuck_pos = Vector2(x, y)
			return

	if path_index >= path.size():
		return

	var current_dest: Vector2i = path[path_index]
	var dest_vec := Vector2(float(current_dest.x) + 0.5, float(current_dest.y) + 0.5)
	var dist: float = cur_pos.distance_to(dest_vec)

	if dist <= 0.15:
		path_index += 1
		if path_index < path.size():
			dest_vec = Vector2(float(path[path_index].x) + 0.5, float(path[path_index].y) + 0.5)
			var dir_next: Vector2 = (dest_vec - cur_pos).normalized()
			x += dir_next.x * speed * delta
			y += dir_next.y * speed * delta
	else:
		var dir: Vector2 = (dest_vec - cur_pos).normalized()
		x += dir.x * speed * delta
		y += dir.y * speed * delta

var _face_prev := Vector2(-9999.0, -9999.0)
var _face_v := Vector2(1.0, 0.0)

## 실제로 움직인 쪽(격자 좌표). 멈춰 있으면 마지막으로 가던 쪽을 그대로 본다.
func _facing_vec() -> Vector2:
	var cur := Vector2(x, y)
	if _face_prev.x > -9000.0:
		var dv := cur - _face_prev
		if dv.length() > 0.004:
			_face_v = dv.normalized()
	_face_prev = cur
	return _face_v

## 에이전트 딕셔너리 변환 (CitizenManager / CitizenLayer 호환)
func to_agent_dict() -> Dictionary:
	var state_str: String = "patrol"
	match state:
		OfficerState.IDLE_PATROL: state_str = "patrol_wall"
		OfficerState.DISPATCH: state_str = "dispatch"
		OfficerState.SUPPRESS: state_str = "suppress"
		OfficerState.ESCORT_TO_YUSUBU: state_str = "escort"
		OfficerState.RETURN_HOME: state_str = "return"

	return {
		"id": id,
		"type": "patrol_soldier",
		"x": x,
		"y": y,
		"from_tile": home_pos,
		"to_tile": target_pos if state == OfficerState.DISPATCH else home_pos,
		"home_tile": home_pos,
		"progress": 0.0,
		"dir": _facing_vec(), # PORT-TRACE [포졸 도리도리]: 예전엔 sin(시간)으로 좌우를 번갈아 내보내 제자리에서 고개를 돌렸다
		"speed": speed,
		"anim": anim_timer,
		"state": state_str,
		"hp": 5,
		"is_dead": false,
		"is_special": true,
		"is_always_visible": true,
		"bubble_text": bubble_text if bubble_timer > 0.0 else "",
		"bubble_timer": bubble_timer,
		"extra": {
			"officer_state": state_str,
			"target_event_id": target_event_id,
			"tied_criminal_id": tied_criminal_id,
			"is_routine": (state == OfficerState.IDLE_PATROL)
		}
	}

var visual_node: CitizenNPC = null

func get_or_create_visual(parent: Node2D) -> CitizenNPC:
	if visual_node == null:
		visual_node = CitizenNPC.new("patrol_officer")
		visual_node.is_special_entity = true
		visual_node.is_always_visible = true
		visual_node.set_job_action("JOB_POLICE_PATROL")
		parent.add_child(visual_node)
	return visual_node

func update_visual_step(delta: float) -> void:
	if visual_node != null:
		visual_node.global_position = global_position
		if state in [OfficerState.DISPATCH, OfficerState.ESCORT_TO_YUSUBU, OfficerState.RETURN_HOME]:
			visual_node.behavior_state = CitizenNPC.NPCBehaviorState.WALKING
		else:
			visual_node.set_job_action("JOB_POLICE_PATROL")
		visual_node.update_visual_step(delta)

func update_logical_step_throttled(delta: float) -> void:
	if visual_node != null:
		visual_node.global_position = global_position
		visual_node.update_logical_step_throttled(delta)
