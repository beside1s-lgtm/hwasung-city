extends RefCounted
class_name BrawlerNPC

## [저잣거리 싸움꾼/취객 난동범 고유 FSM 엔티티]
## 15초 제자리 격투 -> 미체포 시 피해자 들것 후송 및 가해자 귀가 후 100% 영구 소멸

enum BrawlResultState {
	FIGHTING = 0,
	ARRESTED = 1,
	BOAST_AND_CARRY = 2,
	RETURNING_HOME = 3
}

var result_state: BrawlResultState = BrawlResultState.FIGHTING
var is_arrestable: bool = true
var is_escaping_victoriously: bool = false
var boast_timer: float = 2.0 # 2.0초간 의기양양 포즈
var return_home_timer: float = 3.5 # 3.5초간 귀가 이동 후 100% 소멸
var anim_t: float = 0.0
var base_speed: float = 1.6
var crime_timer: float = 15.0 # 제자리 15.0초 유지
var lifetime: float = 0.0

var winner_pos: Vector2 = Vector2.ZERO
var loser_pos: Vector2 = Vector2.ZERO
var winner_home_pos: Vector2 = Vector2.ZERO
var clinic_target_pos: Vector2 = Vector2.ZERO

var winner_bubble: String = ""
var loser_bubble: String = ""

var winner_scale: Vector2 = Vector2.ONE
var winner_rot: float = 0.0
var winner_y: float = 0.0

var loser_rot: float = 0.0
var loser_y: float = 0.0

var victim_carried_away_done: bool = false
var is_dead: bool = false
var event_id: int = -1

const MAX_LIFETIME: float = 35.0 # 고아 방지 하드 라이프타임

func setup(start_pos: Vector2, ev_id: int = -1) -> void:
	winner_pos = start_pos + Vector2(10.0, 0.0)
	loser_pos = start_pos + Vector2(-10.0, 0.0)
	event_id = ev_id
	result_state = BrawlResultState.FIGHTING
	is_arrestable = true
	is_escaping_victoriously = false
	boast_timer = 2.0
	return_home_timer = 3.5
	anim_t = 0.0
	crime_timer = 15.0 # 제자리 15.0초
	lifetime = 0.0
	winner_bubble = "덤벼라! 한 판 붙자!"
	loser_bubble = "포졸 나으리! 여기 주정뱅이 좀 잡아가시오!"
	victim_carried_away_done = false
	is_dead = false

func update(delta: float) -> void:
	if is_dead:
		return

	lifetime += delta
	if lifetime >= MAX_LIFETIME:
		resolve_and_remove()
		return

	anim_t += delta

	match result_state:
		BrawlResultState.FIGHTING:
			crime_timer -= delta
			winner_y = sin(anim_t * 12.0) * 3.0
			loser_y = -sin(anim_t * 12.0) * 2.5
			if crime_timer <= 0.0:
				_on_brawl_timer_expired_without_police()

		BrawlResultState.BOAST_AND_CARRY:
			# 가해자: 제자리에서 가슴을 펴고 두 팔을 들며 우쭐대는 의기양양 포즈 애니메이션
			var pulse: float = 1.0 + sin(anim_t * 12.0) * 0.12
			winner_scale = Vector2(pulse, pulse)
			winner_y = -absf(sin(anim_t * 8.0)) * 6.0
			winner_rot = 0.0

			# 피해자: 부축받으며 인근 민가 방향으로 실려 나감
			_move_victim_and_carriers_to_clinic(delta)

			boast_timer -= delta
			if boast_timer <= 0.0:
				result_state = BrawlResultState.RETURNING_HOME
				winner_home_pos = BuildingManager.get_random_house_or_exit_pos(winner_pos)

		BrawlResultState.RETURNING_HOME:
			return_home_timer -= delta
			# 가해자: 의기양양한 팔자걸음으로 자기 집으로 걸어감
			winner_rot = sin(anim_t * 9.0) * 9.0
			winner_y = -absf(cos(anim_t * 9.0)) * 4.0
			winner_scale = Vector2(1.06, 0.96)
			winner_pos = winner_pos.move_toward(winner_home_pos, (base_speed * 0.9 * 30.0) * delta)

			# 피해자 후송 계속 진행
			_move_victim_and_carriers_to_clinic(delta)

			# 3.5초 이동 경과 또는 집 도달 시 100% 안전 소멸
			if return_home_timer <= 0.0 or winner_pos.distance_to(winner_home_pos) < 16.0:
				resolve_and_remove()

		BrawlResultState.ARRESTED:
			winner_rot = 0.0
			winner_scale = Vector2.ONE

func _on_brawl_timer_expired_without_police() -> void:
	result_state = BrawlResultState.BOAST_AND_CARRY
	is_arrestable = false
	is_escaping_victoriously = true
	CityStats.add_morale(-2)

	# 1. 맞은 사람(피해자): 바닥에 쓰러짐 (90도 회전) + 들것/부축꾼 스폰
	loser_rot = 90.0
	loser_y = 8.0
	loser_bubble = "아이구, 사람 죽네..."
	clinic_target_pos = BuildingManager.get_random_house_or_exit_pos(loser_pos)
	victim_carried_away_done = false

	# 2. 때린 사람(가해자): 의기양양 포즈 시작 및 고유 대사 출력
	winner_bubble = "나한테 까불지 말라고 했지, 상대도 안 되는 게"
	boast_timer = 2.0
	return_home_timer = 3.5

func _move_victim_and_carriers_to_clinic(delta: float) -> void:
	if victim_carried_away_done:
		return
	loser_pos = loser_pos.move_toward(clinic_target_pos, (base_speed * 0.8 * 25.0) * delta)
	if loser_pos.distance_to(clinic_target_pos) < 16.0:
		victim_carried_away_done = true
		loser_bubble = ""

func on_police_arrived() -> void:
	if not is_arrestable:
		return
	result_state = BrawlResultState.ARRESTED
	winner_bubble = "포박되었습니다! 아이쿠 잘못했습니다!"
	loser_bubble = "포졸 나으리, 고맙습니다!"

func resolve_and_remove() -> void:
	is_dead = true
	winner_bubble = ""
	loser_bubble = ""
