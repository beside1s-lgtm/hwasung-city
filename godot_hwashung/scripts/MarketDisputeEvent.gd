extends RefCounted
class_name MarketDisputeEvent

## [저잣거리 우발 범죄 및 분쟁 이벤트 엔티티]
## 1. 분쟁 유형:
##    - BRAWL: 상인-취객 간 난동(다툼). 상인과 취객 머리 위 [싸움] 아이콘 점멸.
##    - PICKPOCKET: 소매치기 발각. 도둑 NPC가 보따리를 낚아채 도주하며 머리 위 [도둑] 아이콘 표시.
## 2. 골든타임 게이지 (기본 25.0초) 작동:
##    - 제한 시간 내 순라군 도착 시 진압 성공 (민심 +1, 상업 안정 유지).
##    - 제한 시간 초과 시 치안 실패 (민심 -2, 저잣거리 세수 -10%, 분노 해산).

enum DisputeType {
	BRAWL = 0,       # 저잣거리 난동/다툼
	PICKPOCKET = 1   # 소매치기 발각
}

const CRIME_DURATION: float = 15.0 # 치안 골든타임 15.0초 (싸움꾼 제자리 격투 15초 규격)
const THIEF_DURATION: float = 28.0 # 도둑 성문 추격전 안전 골든타임 28.0초


enum EventState {
	ACTIVE = 0,      # 분쟁 진행 중 (골든타임 카운트다운)
	SUPPRESSED = 1,  # 순라군에 의해 제압 성공
	FAILED = 2,      # 골든타임 초과로 치안 실패
	COMPLETED = 3    # 사후 처리(훈방 또는 관아 압송) 완료
}

var event_id: int = 0
var event_type: DisputeType = DisputeType.BRAWL
var state: EventState = EventState.ACTIVE

var location: Vector2i = Vector2i.ZERO # 발생 저잣거리 타일
var merchant_pos: Vector2 = Vector2.ZERO # 상인 위치
var criminal_pos: Vector2 = Vector2.ZERO # 범죄자 위치

var time_left: float = CRIME_DURATION
var max_time: float = CRIME_DURATION
var elapsed_time: float = 0.0


var assigned_officer_id: int = -1
var is_officer_arrived: bool = false
var suppress_timer: float = 0.0

var brawl_anim_timer: float = 0.0
var speech_bubble: String = ""
var speech_timer: float = 0.0

## 초기화
func setup_event(
	p_id: int,
	p_type: DisputeType,
	p_loc: Vector2i,
	p_max_time: float = -1.0
) -> void:
	event_id = p_id
	event_type = p_type
	location = p_loc
	var default_t: float = THIEF_DURATION if p_type == DisputeType.PICKPOCKET else CRIME_DURATION
	var chosen_t: float = p_max_time if p_max_time > 0.0 else default_t
	max_time = chosen_t
	time_left = chosen_t
	elapsed_time = 0.0
	state = EventState.ACTIVE

	assigned_officer_id = -1
	is_officer_arrived = false
	suppress_timer = 0.0
	brawl_anim_timer = 0.0

	var center_x: float = float(p_loc.x) + 0.5
	var center_y: float = float(p_loc.y) + 0.5
	merchant_pos = Vector2(center_x - 0.25, center_y)
	criminal_pos = Vector2(center_x + 0.25, center_y)

	if event_type == DisputeType.BRAWL:
		speech_bubble = "내 물건값을 당장 내놓으시오!"
		speech_timer = 3.5
	else:
		speech_bubble = "소매치기다! 내 보따리 잡아라!"
		speech_timer = 3.5

## 틱 업데이트 (골든타임 감소 및 애니메이션)
func tick(delta: float) -> Dictionary:
	if state != EventState.ACTIVE:
		return {"state": state, "time_left": time_left}

	time_left -= delta
	elapsed_time += delta
	brawl_anim_timer += delta


	if speech_timer > 0.0:
		speech_timer -= delta
		if speech_timer <= 0.0:
			if event_type == DisputeType.BRAWL:
				speech_bubble = "주막 술값을 깎아주지 않으면 가만 안 두겠소!" if int(brawl_anim_timer) % 2 == 0 else "관아에 고변하기 전에 썩 물러가시오!"
				speech_timer = 4.0
			else:
				speech_bubble = "게 섰거라, 도둑놈아!" if int(brawl_anim_timer) % 2 == 0 else "도둑이야! 보따리 찾아주시오!"
				speech_timer = 4.0

	# 골든타임 초과 시 치안 실패
	if time_left <= 0.0:
		time_left = 0.0
		state = EventState.FAILED
		speech_bubble = "순라군은 대체 어디서 무엇을 하는가!"
		speech_timer = 4.0
		return {"state": state, "time_left": 0.0, "reason": "timeout"}

	return {"state": state, "time_left": time_left}

## 골든타임 진행도 (0.0 ~ 1.0)
func get_time_ratio() -> float:
	if max_time <= 0.0:
		return 0.0
	return clampf(time_left / max_time, 0.0, 1.0)
