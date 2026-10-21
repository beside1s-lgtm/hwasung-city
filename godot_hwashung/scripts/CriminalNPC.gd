extends RefCounted
class_name CriminalNPC

## [범죄자 및 저잣거리 분쟁 NPC 엔티티]
## 1. 범죄자 종류:
##    - DRUNK_BRAWLER: 저잣거리 상인과 멱살잡이하는 취객 난동범 (제자리 15초 유지)
##    - PICKPOCKET: 보따리를 훔쳐 4대문으로 도주하는 소매치기 도둑 (성문 밖 탈출 전까지 상시 체포 가능)
## 2. 상태 머신:
##    - DISPUTING: 분쟁/도둑질 현장에서 난동 (싸움꾼 15초, 도둑 4초 훔치기)
##    - FLEEING: 도주 중
##    - ARRESTED: 포졸에게 곤봉 제압 또는 오라줄 결박
##    - ESCORTED: 포졸의 뒤를 따라 관아 옥사로 압송 중
##    - DISPERSED: 실패/훈방 후 자연 해산
##    - JAILED: 관아 옥사 수감 (완전 종료)
##    - SWAGGER_HOME: 도둑 성문 도주 중 (팔자걸음 + 장물 보따리 + "세상 살기 편하구만" + 성문 전까지 체포 가능)
##    - BOAST_AND_CARRY: 싸움꾼 미체포 시 가해자 우쭐 만세 포즈(2초) + 피해자 쓰러져 부축꾼 후송(4초)
##    - RETURNING_HOME: 싸움꾼 가해자 팔자걸음 귀가 (3.5초 후 100% 소멸)

enum CriminalKind {
	DRUNK_BRAWLER = 0,
	PICKPOCKET = 1
}

enum CriminalState {
	DISPUTING = 0,
	FLEEING = 1,
	ARRESTED = 2,
	ESCORTED = 3,
	DISPERSED = 4,
	JAILED = 5,
	SWAGGER_HOME = 6,
	BOAST_AND_CARRY = 7,
	RETURNING_HOME = 8
}

var id: int = 0
var kind: CriminalKind = CriminalKind.DRUNK_BRAWLER
var state: CriminalState = CriminalState.DISPUTING

var x: float = 0.0
var y: float = 0.0
var from_tile: Vector2i = Vector2i.ZERO
var to_tile: Vector2i = Vector2i.ZERO
var spawn_tile: Vector2i = Vector2i.ZERO

var speed: float = 1.0
var bubble_text: String = ""
var bubble_timer: float = 0.0
var anim_timer: float = 0.0
var is_dead: bool = false
var is_special_entity: bool = true
var is_always_visible: bool = true

var tied_officer_id: int = -1
var event_id: int = -1

var merchant_x: float = 0.0
var merchant_y: float = 0.0
var victim_bubble: String = ""
var victim_bubble_timer: float = 0.0
var punch_intensity: float = 0.0

# 미체포 승자/탈출 전용 상태 변수
var is_arrestable: bool = true # 성문 밖으로 나가기 전까지 내내 true 유지!
var is_escaping_victoriously: bool = false
var crime_timer: float = 15.0 # 싸움꾼 제자리 15.0초
var steal_prep_timer: float = 4.0 # 도둑 훔치는 시간 4.0초
var walk_anim_time: float = 0.0
var boast_timer: float = 2.0 # 2.0초간 의기양양 포즈
var return_home_timer: float = 3.5 # 3.5초간 귀가 후 100% 소멸
var victim_carry_timer: float = 5.0 # 쓰러져 1초 누움 + 4초 후송 후 100% 소멸
var flee_elapsed: float = 0.0
var lifetime: float = 0.0

var home_target_pos: Vector2 = Vector2.ZERO
var target_gate_pos: Vector2 = Vector2.ZERO
var has_loot_sack: bool = false

var swagger_rotation: float = 0.0
var swagger_offset_y: float = 0.0
var swagger_scale: Vector2 = Vector2.ONE

var victim_rotation: float = 0.0
var victim_offset_y: float = 0.0
var victim_carried_away_done: bool = false
var carrier_active: bool = false
var carrier_pos: Vector2 = Vector2.ZERO
var clinic_pos: Vector2 = Vector2.ZERO

var visual_node: Node2D = null
## PORT-TRACE [취객·빈집]: 소매치기가 턴 곳("shop" 가게 / "house" 빈집 / "drunk" 취객), 싸움에서 맞는 쪽이 취객인가
var target_kind := "shop"
var victim_drunk := false

const MAX_FLEE_TIME: float = 28.0 # 도둑 성문 도주 안전 타임아웃
const MAX_LIFETIME: float = 35.0  # 고아/박제 방지 절대 라이프타임

var global_position: Vector2:
	get:
		return Vector2((float(x) - float(y)) * 32.0, (float(x) + float(y)) * 16.0)
	set(val):
		x = (val.x / 32.0 + val.y / 16.0) / 2.0
		y = (val.y / 16.0 - val.x / 32.0) / 2.0

## 포졸 현장 도착 시 즉시 호출 (즉시 행패 중단 및 포박 상태 전이)
func on_police_arrived() -> void:
	if not is_arrestable:
		return # 이미 성문 밖으로 탈출 성공했으면 체포 불가
	punch_intensity = 0.0
	state = CriminalState.ARRESTED
	bubble_text = "포박되었습니다! 아이쿠 잘못했습니다!"
	bubble_timer = 3.0
	victim_bubble = "포졸 나으리, 고맙습니다!"
	victim_bubble_timer = 2.5
	has_loot_sack = false
	swagger_rotation = 0.0
	swagger_offset_y = 0.0
	swagger_scale = Vector2.ONE

## 골든타임 내 포졸 미도착 시 호출 (범죄 성공 및 고유 승자 액션 개시)
func on_crime_succeeded_unchecked() -> void:
	if state in [CriminalState.ARRESTED, CriminalState.ESCORTED, CriminalState.JAILED]:
		return
	punch_intensity = 0.0

	if kind == CriminalKind.PICKPOCKET:
		_start_swagger_escape()
	else:
		_on_brawl_timer_expired_without_police()

func _start_swagger_escape() -> void:
	state = CriminalState.SWAGGER_HOME
	is_arrestable = true # 성문 밖으로 나가기 전까지 상시 체포 가능!
	is_escaping_victoriously = true
	has_loot_sack = true
	bubble_text = "세상 살기 편하구만"
	bubble_timer = 3.5 # 3.5초 후 자연 소멸 (무한 영구 박제 차단)
	walk_anim_time = 0.0
	flee_elapsed = 0.0

func _on_brawl_timer_expired_without_police() -> void:
	state = CriminalState.BOAST_AND_CARRY
	is_arrestable = false
	is_escaping_victoriously = true
	boast_timer = 2.0
	return_home_timer = 3.5
	victim_carry_timer = 5.0
	walk_anim_time = 0.0
	CityStats.add_morale(-2)

	# 1. 맞은 사람(피해자): 바닥에 쓰러짐 (90도 회전) + 들것/부축꾼 스폰 (최대 4초 후 완전 삭제)
	victim_rotation = 90.0
	victim_offset_y = 8.0
	victim_bubble = "아이구, 사람 죽네..."
	victim_bubble_timer = 3.5
	carrier_active = true
	carrier_pos = Vector2(merchant_x, merchant_y)
	clinic_pos = BuildingManager.get_random_house_or_exit_pos(global_position)
	victim_carried_away_done = false

	# 2. 때린 사람(가해자): 2.0초간 의기양양 포즈 및 대사 출력 (3.0초 후 자동 소멸)
	bubble_text = "나한테 까불지 말라고 했지, 상대도 안 되는 게"
	bubble_timer = 3.0

## 관아 도착 또는 소멸 시 죄인 노드/데이터 완전 삭제 및 사건 종료
func resolve_and_remove() -> void:
	is_dead = true
	punch_intensity = 0.0
	bubble_text = ""
	victim_bubble = ""
	carrier_active = false
	if visual_node != null and is_instance_valid(visual_node):
		visual_node.queue_free()
		visual_node = null

func setup_criminal(
	c_id: int,
	c_kind: CriminalKind,
	start_pos: Vector2i,
	ev_id: int = -1,
	grid: GameGrid = null
) -> void:
	id = c_id
	kind = c_kind
	spawn_tile = start_pos
	from_tile = start_pos
	to_tile = start_pos
	event_id = ev_id
	x = float(start_pos.x) + 0.6
	y = float(start_pos.y) + 0.5
	merchant_x = float(start_pos.x) + 0.25
	merchant_y = float(start_pos.y) + 0.5
	is_dead = false
	is_arrestable = true
	is_escaping_victoriously = false
	crime_timer = 15.0 # 싸움꾼 15초 — 순라청이 많을수록 포졸이 빨리 와서 잡는다(설계 의도)
	steal_prep_timer = 4.0 # 도둑 4.0초
	walk_anim_time = 0.0
	boast_timer = 2.0
	return_home_timer = 3.5
	victim_carry_timer = 5.0
	flee_elapsed = 0.0
	lifetime = 0.0
	state = CriminalState.DISPUTING
	anim_timer = 0.0
	punch_intensity = 0.0
	has_loot_sack = false
	swagger_rotation = 0.0
	swagger_offset_y = 0.0
	swagger_scale = Vector2.ONE
	victim_rotation = 0.0
	victim_offset_y = 0.0
	victim_carried_away_done = false
	carrier_active = false

	if kind == CriminalKind.DRUNK_BRAWLER:
		speed = 0.6
		# 왈패의 주된 표적은 주막에서 나온 취객
		victim_drunk = randf() < 0.7
		if victim_drunk:
			bubble_text = ["어디서 술 냄새 풍기며 어깨를 쳐! 이 주정뱅이가!", "이놈, 술 취했다고 눈에 뵈는 게 없느냐!"][randi() % 2]
			victim_bubble = "딸꾹… 내가 뭘 어쨌다고 이러시오…"
		else:
			bubble_text = "네 이놈! 주막 술값을 깎아달라는데 감히!"
			victim_bubble = "영업 방해 말고 썩 물러가시오!"
		bubble_timer = 3.0
		victim_bubble_timer = 3.0
	else:
		speed = 2.0
		bubble_text = "이 비단 보따리는 이제 내 것이다!"
		bubble_timer = 2.5
		victim_bubble = "아이고 내 물건! 소매치기다!"
		victim_bubble_timer = 3.0
		# 탈출 목표 좌표 선정: 성 밖 스폰이거나 성문 미완공 시 길 없는 외곽/야산으로 도망, 성내+성문 완공 시 성문으로 도망
		target_gate_pos = BuildingManager.get_thief_escape_target_world_pos(global_position, grid)
		home_target_pos = target_gate_pos

func update(delta: float, leader_pos: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	# 절대 라이프타임(35초) 검사: 고아/박제 원천 차단
	lifetime += delta
	if lifetime >= MAX_LIFETIME:
		resolve_and_remove()
		return

	anim_timer += delta
	if bubble_timer > 0.0:
		bubble_timer -= delta
	if victim_bubble_timer > 0.0:
		victim_bubble_timer -= delta

	match state:
		CriminalState.DISPUTING:
			if kind == CriminalKind.DRUNK_BRAWLER:
				crime_timer -= delta
				if crime_timer <= 0.0:
					on_crime_succeeded_unchecked()
					return

				# 상인과 뒤엉켜 주먹질 및 멱살잡이 (제자리 15초 유지)
				var fight_cycle: float = sin(anim_timer * 9.0)
				punch_intensity = absf(sin(anim_timer * 12.0))
				x = float(spawn_tile.x) + 0.55 + fight_cycle * 0.18
				y = float(spawn_tile.y) + 0.5 + cos(anim_timer * 8.0) * 0.08
				merchant_x = float(spawn_tile.x) + 0.3 - fight_cycle * 0.12
				merchant_y = float(spawn_tile.y) + 0.5 - cos(anim_timer * 8.0) * 0.06
				if int(anim_timer * 2.0) % 4 == 0 and bubble_timer <= 0.0:
					bubble_text = "덤벼라! 한 판 붙자!" if not victim_drunk else "술 깨게 해 주마, 이놈!"
					bubble_timer = 2.5
				elif int(anim_timer * 2.0) % 4 == 2 and victim_bubble_timer <= 0.0:
					victim_bubble = "포졸 나으리! 여기 왈패 좀 잡아가시오!" if not victim_drunk else "아이고, 사람 살려! 딸꾹!"
					victim_bubble_timer = 2.5
			else:
				# 소매치기: 상점 좌판에서 물건 훔치기 4초 진행
				punch_intensity = 0.0
				steal_prep_timer -= delta
				x = float(spawn_tile.x) + 0.35 + sin(anim_timer * 4.0) * 0.1
				merchant_x = float(spawn_tile.x) + 0.2
				merchant_y = float(spawn_tile.y) + 0.5

				if steal_prep_timer <= 0.0:
					# 4초 후 장물 보따리를 메고 4대문을 향해 도주 개시!
					_start_swagger_escape()

		CriminalState.FLEEING, CriminalState.SWAGGER_HOME:
			flee_elapsed += delta
			walk_anim_time += delta

			# 팔자걸음(Swagger Walk) 고유 애니메이션: 좌우 뒤뚱거림 + 어깨 바운스 + 배 내밀기
			swagger_rotation = sin(walk_anim_time * 10.0) * 11.0
			swagger_offset_y = -absf(cos(walk_anim_time * 10.0)) * 4.5
			swagger_scale = Vector2(1.08, 0.95)

			# 목표 성문을 향해 질주 (성문 밖으로 나가기 전까지 is_arrestable = true)
			global_position = global_position.move_toward(target_gate_pos, (speed * 0.85 * 30.0) * delta)

			# 피해 상인이 헐레벌떡 뒤를 쫓음
			var cur_p := global_position
			var cur_m := Vector2((merchant_x - merchant_y) * 32.0, (merchant_x + merchant_y) * 16.0)
			var m_target := cur_p + Vector2(-16.0, 0.0)
			var m_new := cur_m.move_toward(m_target, (speed * 0.6 * 30.0) * delta)
			merchant_x = (m_new.x / 32.0 + m_new.y / 16.0) / 2.0
			merchant_y = (m_new.y / 16.0 - m_new.x / 32.0) / 2.0

			# 포졸에게 안 잡히고 성문에 도달하거나 도주 제한 시간 초과 시 탈출 성공!
			if global_position.distance_to(target_gate_pos) <= 20.0 or flee_elapsed >= MAX_FLEE_TIME:
				is_arrestable = false
				CityStats.add_morale(-2)
				resolve_and_remove()

		CriminalState.BOAST_AND_CARRY:
			walk_anim_time += delta
			# 가해자: 제자리에서 가슴을 펴고 두 팔을 들며 우쭐대는 의기양양 포즈
			var pulse: float = 1.0 + sin(walk_anim_time * 12.0) * 0.12
			swagger_scale = Vector2(pulse, pulse)
			swagger_offset_y = -absf(sin(walk_anim_time * 8.0)) * 6.0
			swagger_rotation = 0.0

			# 피해자: 부축받으며 인근 민가 방향으로 실려 나감
			_move_victim_and_carriers_to_clinic(delta)

			boast_timer -= delta
			if boast_timer <= 0.0:
				state = CriminalState.RETURNING_HOME
				home_target_pos = BuildingManager.get_random_house_or_exit_pos(global_position)

		CriminalState.RETURNING_HOME:
			walk_anim_time += delta
			return_home_timer -= delta

			# 가해자: 의기양양한 팔자걸음으로 자기 집으로 걸어감
			swagger_rotation = sin(walk_anim_time * 9.0) * 9.0
			swagger_offset_y = -absf(cos(walk_anim_time * 9.0)) * 4.0
			swagger_scale = Vector2(1.06, 0.96)
			global_position = global_position.move_toward(home_target_pos, (speed * 0.9 * 30.0) * delta)

			# 피해자 후송 계속 진행
			_move_victim_and_carriers_to_clinic(delta)

			# 3.5초 경과 또는 집 도달 시 100% 영구 삭제
			if return_home_timer <= 0.0 or global_position.distance_to(home_target_pos) < 16.0:
				resolve_and_remove()

		CriminalState.ARRESTED:
			punch_intensity = 0.0
			swagger_rotation = 0.0
			swagger_offset_y = 0.0
			swagger_scale = Vector2.ONE

		CriminalState.ESCORTED:
			# 포졸 뒤를 오라줄로 묶여 따라감
			if leader_pos != Vector2.ZERO:
				var target_point := leader_pos - Vector2(0.4, 0.0)
				var cur_point := Vector2(x, y)
				var dist: float = cur_point.distance_to(target_point)
				if dist > 0.1:
					var dir: Vector2 = (target_point - cur_point).normalized()
					var step: float = minf(dist, speed * delta * 1.2)
					x += dir.x * step
					y += dir.y * step

		CriminalState.DISPERSED:
			x += 1.0 * speed * delta
			if anim_timer > 3.0:
				is_dead = true

func _move_victim_and_carriers_to_clinic(delta: float) -> void:
	if victim_carried_away_done:
		return

	victim_carry_timer -= delta
	if victim_carry_timer > 4.0:
		return # 쓰러져 누운 채 들것꾼을 기다림
	var cur_m := Vector2(merchant_x, merchant_y)
	var clinic_tx: float = (clinic_pos.x / 32.0 + clinic_pos.y / 16.0) / 2.0
	var clinic_ty: float = (clinic_pos.y / 16.0 - clinic_pos.x / 32.0) / 2.0
	var target_t := Vector2(clinic_tx, clinic_ty)
	var dist: float = cur_m.distance_to(target_t)

	if dist < 0.35 or victim_carry_timer <= 0.0:
		victim_carried_away_done = true
		carrier_active = false
		victim_bubble = ""
	else:
		var dir: Vector2 = (target_t - cur_m).normalized()
		merchant_x += dir.x * 0.85 * delta
		merchant_y += dir.y * 0.85 * delta
		carrier_pos = Vector2(merchant_x, merchant_y)

## 에이전트 딕셔너리 변환 (CitizenManager / CitizenLayer 호환)
## 소매치기가 턴 곳에 맞춰 대사를 바꾼다
func set_theft_kind(k: String) -> void:
	target_kind = k
	match k:
		"house":
			bubble_text = "빈집이라더니 장롱에 엽전이 가득하구나!"
			victim_bubble = "아이고, 도둑이야! 우리 집 장롱을 털어 갔어요!"
		"drunk":
			bubble_text = "취한 놈 주머니 터는 건 식은 죽 먹기지."
			victim_bubble = ""

func to_agent_dict() -> Dictionary:
	var state_str: String = "disputing"
	match state:
		CriminalState.DISPUTING: state_str = "disputing"
		CriminalState.FLEEING: state_str = "fleeing"
		CriminalState.ARRESTED: state_str = "arrested"
		CriminalState.ESCORTED: state_str = "escorted"
		CriminalState.DISPERSED: state_str = "dispersed"
		CriminalState.JAILED: state_str = "jailed"
		CriminalState.SWAGGER_HOME: state_str = "swagger_home"
		CriminalState.BOAST_AND_CARRY: state_str = "boast_and_carry"
		CriminalState.RETURNING_HOME: state_str = "returning_home"

	var kind_str: String = "drunk_brawler" if kind == CriminalKind.DRUNK_BRAWLER else "pickpocket"

	return {
		"id": id,
		"type": "criminal_npc",
		"x": x,
		"y": y,
		"from_tile": from_tile,
		"to_tile": to_tile,
		"home_tile": spawn_tile,
		"progress": 0.0,
		"dir": Vector2.RIGHT if sin(anim_timer) >= 0.0 else Vector2.LEFT,
		"speed": speed,
		"anim": anim_timer,
		"state": state_str,
		"hp": 2,
		"is_dead": is_dead,
		"is_special": true,
		"is_always_visible": true,
		"bubble_text": bubble_text if (bubble_timer > 0.0) else "",
		"bubble_timer": bubble_timer,
		"victim_x": merchant_x,
		"victim_y": merchant_y,
		"victim_bubble": victim_bubble if (victim_bubble_timer > 0.0) else "",
		"punch_intensity": punch_intensity,
		"crime_kind": kind_str,
		"extra": {
			"victim_kind": ("drunk" if victim_drunk else "merchant") if kind == CriminalKind.DRUNK_BRAWLER else target_kind,
			"criminal_kind": kind_str,
			"event_id": event_id,
			"tied_officer_id": tied_officer_id,
			"merchant_x": merchant_x,
			"merchant_y": merchant_y,
			"victim_bubble": victim_bubble if (victim_bubble_timer > 0.0) else "",
			"punch_intensity": punch_intensity,
			"swagger_rot": swagger_rotation,
			"swagger_y": swagger_offset_y,
			"swagger_scale": swagger_scale,
			"has_loot_sack": has_loot_sack,
			"victim_rot": victim_rotation,
			"victim_y": victim_offset_y,
			"carrier_active": carrier_active and not victim_carried_away_done,
			"victim_done": victim_carried_away_done,
			"carry_left": victim_carry_timer,
			"clinic_x": (clinic_pos.x / 32.0 + clinic_pos.y / 16.0) / 2.0,
			"clinic_y": (clinic_pos.y / 16.0 - clinic_pos.x / 32.0) / 2.0,
			"carrier_x": carrier_pos.x,
			"carrier_y": carrier_pos.y,
			"is_boasting": (state == CriminalState.BOAST_AND_CARRY)
		}
	}
