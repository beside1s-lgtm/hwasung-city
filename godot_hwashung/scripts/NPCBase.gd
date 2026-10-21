extends RefCounted
class_name NPCBase

## [조선 후기 6대 신분·직업군 베이스 시스템 & 오브젝트 풀링 & 순환 FSM]
## 중인(기술관/의원), 관아 아전(향리/이방), 축성 장인(도편수/석수),
## 보부상(객주), 승군(호국승), 백정(도축/가죽공)

enum JobType {
	COMMONER = 0,     # 일반 백성/상민 (기본값)
	JUNGIN = 1,       # 중인 (의원/역관)
	AJEOUN = 2,       # 관아 아전 (향리/이방)
	ARTISAN = 3,      # 축성 장인 (도편수/석수)
	BOBUSANG = 4,     # 보부상 (객주)
	MONK_SOLDIER = 5, # 승군 (호국 의승)
	BUTCHER = 6       # 백정 (도축/가죽공)
}

enum FSMState {
	IDLE,
	WORK,
	PATROL,
	ROAM,
	TRAVEL,
	REST
}

const JOB_TYPE_NAMES := {
	JobType.COMMONER: "일반 백성",
	JobType.JUNGIN: "중인 (기술관/의원)",
	JobType.AJEOUN: "아전 (향리/이방)",
	JobType.ARTISAN: "전문 장인 (석수/목수)",
	JobType.BOBUSANG: "보부상 (부보상/객주)",
	JobType.MONK_SOLDIER: "승군 (호국 의승)",
	JobType.BUTCHER: "백정 (도축/가죽공)"
}

const JOB_STRING_MAP := {
	"commoner": JobType.COMMONER,
	"shopper": JobType.COMMONER,
	"farmer": JobType.COMMONER,
	"carrier": JobType.COMMONER,
	"jungin": JobType.JUNGIN,
	"physician": JobType.JUNGIN,
	"ajeon": JobType.AJEOUN,
	"ajeoun": JobType.AJEOUN,
	"artisan": JobType.ARTISAN,
	"artisan_master": JobType.ARTISAN,
	"bobusang": JobType.BOBUSANG,
	"monk_soldier": JobType.MONK_SOLDIER,
	"butcher": JobType.BUTCHER
}

# 오브젝트 풀 (Object Pool)
static var _pool: Array[Dictionary] = []
const MAX_POOL_SIZE: int = 120

## 풀에서 에이전트 딕셔너리 인출 (없으면 신규 생성)
static func acquire_agent(id: int, job_type: int, start_pos: Vector2i, name_str: String = "") -> Dictionary:
	var ag: Dictionary
	if not _pool.is_empty():
		ag = _pool.pop_back()
		ag.clear()
	else:
		ag = {}

	var type_str: String = "commoner"
	match job_type:
		JobType.JUNGIN: type_str = "jungin"
		JobType.AJEOUN: type_str = "ajeon"
		JobType.ARTISAN: type_str = "artisan"
		JobType.BOBUSANG: type_str = "bobusang"
		JobType.MONK_SOLDIER: type_str = "monk_soldier"
		JobType.BUTCHER: type_str = "butcher"
		_: type_str = "commoner"

	ag["id"] = id
	ag["job_type"] = job_type
	ag["type"] = type_str
	ag["npc_name"] = name_str
	ag["x"] = float(start_pos.x) + 0.5
	ag["y"] = float(start_pos.y) + 0.5
	ag["from_tile"] = start_pos
	ag["to_tile"] = start_pos
	ag["home_tile"] = start_pos
	ag["progress"] = 1.0
	ag["dir"] = Vector2.RIGHT
	ag["speed"] = 1.0
	ag["anim"] = randf() * 4.0
	ag["fsm_state"] = FSMState.IDLE
	ag["state"] = "work"
	ag["state_timer"] = randf_range(4.0, 8.0)
	ag["is_spot"] = false
	ag["is_named"] = false
	ag["is_wild"] = false
	ag["is_professional"] = true
	ag["bubble_text"] = ""
	ag["bubble_timer"] = 0.0
	ag["waypoints"] = []
	ag["waypoint_index"] = 0
	ag["extra"] = {}
	ag["is_dead"] = false

	# 직업별 기본 속도 차등화
	match job_type:
		JobType.JUNGIN: ag["speed"] = 0.85
		JobType.AJEOUN: ag["speed"] = 0.95
		JobType.ARTISAN: ag["speed"] = 0.80
		JobType.BOBUSANG: ag["speed"] = 1.20
		JobType.MONK_SOLDIER: ag["speed"] = 1.05
		JobType.BUTCHER: ag["speed"] = 0.90
		_: ag["speed"] = 1.0

	return ag

## 사용 완료된 에이전트 풀로 반환
static func release_agent(ag: Dictionary) -> void:
	if _pool.size() < MAX_POOL_SIZE:
		ag["is_dead"] = true
		ag.clear()
		_pool.append(ag)

## 세이브/로드 시 job_type 안전 검증 및 복원
static func safe_job_type(raw_val: Variant) -> int:
	if raw_val is int:
		var ival: int = raw_val as int
		if ival >= JobType.COMMONER and ival <= JobType.BUTCHER:
			return ival
	elif raw_val is String:
		var sval: String = (raw_val as String).to_lower()
		if JOB_STRING_MAP.has(sval):
			return JOB_STRING_MAP[sval]
	return JobType.COMMONER

## 뷰포트 오프스크린 컬링 검사 (화면 밖 연산 동결용)
static func is_in_viewport(screen_pos: Vector2, view_rect: Rect2, margin: float = 64.0) -> bool:
	var expanded: Rect2 = view_rect.grow(margin)
	return expanded.has_point(screen_pos)
