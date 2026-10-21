extends RefCounted
class_name BanditEntity

## [지능형 도적 침략 엔티티]
## 1. 왕권(Royal Power) 기반 AI 분기:
##    - 왕권 >= 30: 생계형 외곽 약탈 모드 (MODE_OUTSKIRTS) -> 외곽 민가 2~3채 약탈 후 도주
##    - 왕권 < 30: 반란/정권 전복 행궁 직격 모드 (MODE_ASSAULT_PALACE) -> 행궁 본궁을 향해 맹렬히 진격
## 2. 경로 장애물 돌파 (attack_wall):
##    - 성곽/성문 접촉 시 성벽 타격 (초당 성 방호력 차감). 방호력 0 도달 시 성내 난입
## 3. 실시간 약탈 (raid):
##    - 경로상 민가/상점 약탈 (일시적 is_looted 상태, 불꽃/연기 연출, 국고/식량 유출)
## 4. 교전 및 결과:
##    - 장용영 군사와 조우 시 백병전(combat)
##    - 체력 소진 시 포박(arrested)되어 관아로 압송

enum Mode {
	OUTSKIRTS = 0,       # 왕권 30 이상: 외곽 민가/농경지 생계형 약탈
	ASSAULT_PALACE = 1   # 왕권 30 미만: 반란 및 화성행궁 본궁 직격
}

enum State {
	MARCH = 0,          # 목표를 향해 진격
	ATTACK_WALL = 1,    # 성곽/성문 타격 (성 방호력 차감)
	RAID = 2,           # 민가/상점 약탈 (is_looted 설정)
	COMBAT = 3,         # 장용영 군사와 칼싸움
	ARRESTED = 4,       # 제압되어 포승줄에 결박됨
	RETREAT = 5,        # 소굴 또는 맵 밖으로 퇴각
	PALACE_BREACH = 6   # 행궁 본궁 점거 (도시 함락)
}

var id: int = 0
var mode: Mode = Mode.OUTSKIRTS
var state: State = State.MARCH

var x: float = 0.0
var y: float = 0.0
var from_tile: Vector2i = Vector2i.ZERO
var to_tile: Vector2i = Vector2i.ZERO
var target_tile: Vector2i = Vector2i.ZERO
var home_camp: Vector2i = Vector2i(4, 8)

var speed: float = 1.15
var hp: int = 4
var max_hp: int = 4
var is_dead: bool = false
var is_special_entity: bool = true
var is_always_visible: bool = true

var state_timer: float = 0.0
var bubble_text: String = ""
var bubble_timer: float = 0.0
var flame_anim: float = 0.0
var torch_swing: float = 0.0

var raided_houses_count: int = 0
var max_raid_targets: int = 2

## 초기화
func setup_bandit(
	b_id: int,
	spawn_pos: Vector2i,
	target_pos: Vector2i,
	camp_pos: Vector2i,
	b_mode: Mode,
	init_hp: int = 4
) -> void:
	id = b_id
	mode = b_mode
	state = State.MARCH
	from_tile = spawn_pos
	to_tile = spawn_pos
	target_tile = target_pos
	home_camp = camp_pos
	x = float(spawn_pos.x) + 0.5
	y = float(spawn_pos.y) + 0.5
	hp = init_hp
	max_hp = init_hp
	is_dead = false
	raided_houses_count = 0
	max_raid_targets = 2 if mode == Mode.OUTSKIRTS else 999
	flame_anim = randf() * TAU
	
	if mode == Mode.OUTSKIRTS:
		bubble_text = "외곽 민가를 털고 어서 튀자!"
	else:
		bubble_text = "왕실의 권위는 땅에 떨어졌다! 행궁을 점령하라!"
	bubble_timer = 3.5

## 딕셔너리 호환 변환 (CitizenManager.agents와 완전 상호운용)
func to_agent_dict() -> Dictionary:
	var state_str: String = "march"
	match state:
		State.MARCH: state_str = "march"
		State.ATTACK_WALL: state_str = "attack_wall"
		State.RAID: state_str = "raid"
		State.COMBAT: state_str = "combat"
		State.ARRESTED: state_str = "arrested"
		State.RETREAT: state_str = "retreat"
		State.PALACE_BREACH: state_str = "palace_breach"

	return {
		"id": id,
		"type": "bandit",
		"x": x,
		"y": y,
		"from_tile": from_tile,
		"to_tile": to_tile,
		"home_tile": home_camp,
		"progress": 0.0,
		"dir": Vector2.RIGHT,
		"speed": speed,
		"anim": randf() * 4.0,
		"state": state_str,
		"hp": hp,
		"max_hp": max_hp,
		"is_dead": is_dead,
		"state_timer": state_timer,
		"is_spot": false,
		"is_named": false,
		"is_wild": false,
		"is_special": true,
		"is_always_visible": true,
		"bubble_text": bubble_text,
		"bubble_timer": bubble_timer,
		"extra": {
			"flame_anim": flame_anim,
			"torch_swing": torch_swing,
			"target_tile": target_tile,
			"mode": int(mode),
			"entity_ref": self
		}
	}

## 딕셔너리에서 상태 역동기화
func sync_from_agent_dict(dict: Dictionary) -> void:
	x = float(dict.get("x", x))
	y = float(dict.get("y", y))
	hp = int(dict.get("hp", hp))
	is_dead = bool(dict.get("is_dead", is_dead))
	bubble_text = String(dict.get("bubble_text", bubble_text))
	bubble_timer = float(dict.get("bubble_timer", bubble_timer))
	var st_str: String = String(dict.get("state", "march"))
	match st_str:
		"march": state = State.MARCH
		"attack_wall": state = State.ATTACK_WALL
		"raid": state = State.RAID
		"combat": state = State.COMBAT
		"arrested": state = State.ARRESTED
		"retreat": state = State.RETREAT
		"palace_breach": state = State.PALACE_BREACH
