extends RefCounted
class_name JangyongyeongTroop

## [장용영 정예 요격 부대 엔티티]
## 1. 출동 트리거:
##    - 도적 침입 발생 즉시 화성행궁 본궁 및 군영에서 5~10명 정예 부대 편성
##    - 깃발병(군기)을 선두로 환도와 창을 장비하고 긴급 행군
## 2. 교전 메커니즘:
##    - 도적 무리와 조우 시 정지하고 백병전(칼싸움/타격) 전개
##    - 초당 피해량 = 장용영 총 공격력 / 5
## 3. 전과 처리:
##    - 도적 제압 시 포박(arrested)하여 화성유수부 관아(옥사)로 압송
##    - 작전 완료 후 거소(행궁/군영)로 복귀(return) 및 디스폰

enum State {
	DEPLOY = 0,    # 도적 위치를 향해 신속 출동 행군
	COMBAT = 1,    # 도적과 조우하여 백병전(칼싸움) 전개
	ESCORT = 2,    # 포박된 도적을 관아 옥사로 압송
	RETURN = 3     # 작전 완수 후 행궁/군영으로 복귀
}

var id: int = 0
var state: State = State.DEPLOY
var x: float = 0.0
var y: float = 0.0
var from_tile: Vector2i = Vector2i.ZERO
var to_tile: Vector2i = Vector2i.ZERO
var home_base: Vector2i = Vector2i.ZERO
var target_pos: Vector2i = Vector2i.ZERO

var speed: float = 1.6
var hp: int = 10
var is_dead: bool = false
var is_special_entity: bool = true
var is_always_visible: bool = true
var is_flag_bearer: bool = false # 선두 깃발병 여부

var state_timer: float = 0.0
var bubble_text: String = ""
var bubble_timer: float = 0.0

func setup_troop(
	t_id: int,
	spawn_pos: Vector2i,
	target_p: Vector2i,
	flag_bearer: bool = false
) -> void:
	id = t_id
	from_tile = spawn_pos
	to_tile = target_p
	home_base = spawn_pos
	target_pos = target_p
	x = float(spawn_pos.x) + 0.5
	y = float(spawn_pos.y) + 0.5
	speed = 1.65
	hp = 10
	is_dead = false
	is_flag_bearer = flag_bearer
	state = State.DEPLOY
	
	if is_flag_bearer:
		bubble_text = "장용영 정예군 출동! 역적 화적 떼를 소탕하라!"
		bubble_timer = 4.0
	else:
		bubble_text = "어명을 받들라! 한 놈도 살려보내지 마라!"
		bubble_timer = 3.2

## CitizenManager.agents 딕셔너리 호환 변환
func to_agent_dict() -> Dictionary:
	var state_str: String = "rush"
	match state:
		State.DEPLOY: state_str = "rush"
		State.COMBAT: state_str = "combat"
		State.ESCORT: state_str = "escort"
		State.RETURN: state_str = "return"

	return {
		"id": id,
		"type": "jangyongyeong_soldier",
		"x": x,
		"y": y,
		"from_tile": from_tile,
		"to_tile": to_tile,
		"home_tile": home_base,
		"progress": 0.0,
		"dir": Vector2.RIGHT,
		"speed": speed,
		"anim": randf() * 4.0,
		"state": state_str,
		"hp": hp,
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
			"is_flag_bearer": is_flag_bearer,
			"target_tile": target_pos,
			"entity_ref": self
		}
	}

func sync_from_agent_dict(dict: Dictionary) -> void:
	x = float(dict.get("x", x))
	y = float(dict.get("y", y))
	hp = int(dict.get("hp", hp))
	is_dead = bool(dict.get("is_dead", is_dead))
	bubble_text = String(dict.get("bubble_text", bubble_text))
	bubble_timer = float(dict.get("bubble_timer", bubble_timer))
	var st_str: String = String(dict.get("state", "rush"))
	match st_str:
		"rush": state = State.DEPLOY
		"combat": state = State.COMBAT
		"escort": state = State.ESCORT
		"return": state = State.RETURN
