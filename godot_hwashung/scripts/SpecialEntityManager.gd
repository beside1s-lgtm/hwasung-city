extends RefCounted
class_name SpecialEntityManager

## [특수 개체 및 위기/이벤트 엔티티 가시성 관리자]
## 줌 상태(가시 타일 수 > 400칸 원거리 조감)와 무관하게 항상 화면에 표시(visible = true)되고
## 상태 아이콘 및 말풍선이 상시 노출(set_bubble_enabled(true))되어야 하는 특수 엔티티 식별 및 플래그 관리.
##
## 상시 노출 대상 엔티티:
## 1. 세시풍속 / 축제: 단오 씨름꾼, 줄다리기 무리, 정월대보름/추석 놀이패, 어가행렬, 농악대, 지신밟기 풍물패
## 2. 치안 / 범죄: 소매치기(도둑), 저잣거리 싸움꾼(난동꾼), 출동/압송 중인 순라청 포졸
## 3. 군사 / 외적 위협: 도적떼 소굴 및 습격대, 반란군 분대, 열강 침입군, 교전 중인 장용영 군사
## 4. 야생 맹수 & 사냥: 팔달산/외곽 출몰 호랑이, 승냥이, 착호갑사, 사포수, 활 사냥꾼

const SPECIAL_TYPES: Array[String] = [
	# 치안 및 범죄
	"thief", "pickpocket", "brawler", "criminal", "criminal_npc",
	"patrol_officer", "patrol_soldier", "officer", "sunla", "guard",
	# 적 / 도적 / 반란 / 침략
	"bandit", "horde", "rebel", "invader",
	# 정규군 및 군사
	"jangyongyeong", "jangyongyeong_soldier", "military_guard", "soldier",
	"monk_soldier", "volunteer_militia", "militia", "official_rider",
	"posu", "sasu", "salsu", "gipo", "drill",
	# 맹수 및 사냥 / 포호책
	"tiger", "wolf", "predator",
	"hunter", "saposu", "chakhogapsa", "torch_bearer", "bait", "marksman",
	# 세시풍속 및 민속놀이
	"pungmul", "pungmul_band", "bull_parade", "stretcher", "procession",
	"royal_procession", "custom", "festival_walker", "festival",
	"ssireum", "juldagi", "taekkyeon", "talchum", "seokjeon", "ganggang",
	"kites", "paengi", "jwibul", "nongak", "sandang", "neolttwigi", "swing",
	# 서당 및 교육
	"seodang", "seowon", "hyanggyo", "seodang_teacher", "seodang_student", "scholar", "yusaeng",
	# 화재진압 및 수해 방재
	"firefighter", "firefighter_soldier", "bucket_volunteer", "volunteer_bucket",
	"fire_panic", "flood_sandbag", "flood_refugee",
	# 특수상황 (익수, 전기수 등)
	"drowning", "rescuer", "jeongisu",
	# 직업별 고유 특수 액션 FSM (놀이, 훈련, 전투, 진압 등)
	"JOB_BRAWL_FIGHT", "JOB_MILITARY_DRILL", "JOB_POLICE_PATROL", "JOB_FIRE_EXTINGUISH",
	"JOB_THIEF_STEAL", "JOB_CHILD_TOP", "JOB_CHILD_JEGI", "JOB_CHILD_PEBBLE", "JOB_CHILD_FLOWER",
	"JOB_BOOK_RECITE"
]

static var _special_registry: Array = []

static func register_special(entity: Variant) -> void:
	if entity != null and not _special_registry.has(entity):
		_special_registry.append(entity)
	mark_special(entity)

static func unregister_special(entity: Variant) -> void:
	if entity != null:
		_special_registry.erase(entity)

## 타입 식별자가 특수 개체 유형인지 판별
static func is_special_type(type_id: String) -> bool:
	if type_id in SPECIAL_TYPES:
		return true
	for st_type: String in SPECIAL_TYPES:
		if type_id.begins_with(st_type):
			return true
	return false

## 딕셔너리 기반 에이전트(CitizenManager.agents)가 특수 개체인지 판별
static func is_special_agent(ag: Dictionary) -> bool:
	if bool(ag.get("is_special_entity", false)) or bool(ag.get("is_always_visible", false)):
		return true
	if bool(ag.get("festival", false)) or bool(ag.get("custom", false)) or bool(ag.get("is_custom", false)) or bool(ag.get("is_plaza_event", false)):
		return true
	if bool(ag.get("is_named", false)) or bool(ag.get("is_drill", false)) or bool(ag.get("drill", false)):
		return true
	if bool(ag.get("is_procession", false)) or bool(ag.get("procession", false)) or bool(ag.get("trip", false)):
		return true
	if bool(ag.get("is_firefighter", false)) or bool(ag.get("is_fire_volunteer", false)) or bool(ag.get("is_flood_worker", false)):
		return true
	if bool(ag.get("is_criminal", false)) or bool(ag.get("is_patrol", false)) or bool(ag.get("is_bandit", false)):
		return true
	if bool(ag.get("is_rebel", false)) or bool(ag.get("is_combat", false)):
		return true
	var t_str: String = str(ag.get("type", ""))
	if t_str.begins_with("named_") or t_str.begins_with("procession_"):
		return true
	if is_special_type(t_str):
		return true
	var act_str: String = str(ag.get("activity_type", ""))
	if act_str != "" and is_special_type(act_str):
		return true
	var st_str: String = str(ag.get("state", ""))
	if st_str in ["arrested", "escorted", "dispatch", "suppress", "combat", "attack_wall", "firing", "triumph_march", "drowning", "saved", "rescue", "drill"]:
		return true
	return false

## 노드 기반 엔티티가 특수 개체인지 판별
static func is_special_node(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if "is_special_entity" in node and bool(node.get("is_special_entity")):
		return true
	if "is_always_visible" in node and bool(node.get("is_always_visible")):
		return true
	if node.has_method("is_special_entity") and bool(node.call("is_special_entity")):
		return true
	if node.has_method("is_participating_in_custom") and bool(node.call("is_participating_in_custom")):
		return true
	if _special_registry.has(node):
		return true
	return false

## 범용 엔티티(Dictionary, Node, Object) 특수 개체 판별
static func is_special_entity(entity: Variant) -> bool:
	if entity is Dictionary:
		return is_special_agent(entity)
	elif entity is Node:
		return is_special_node(entity)
	elif entity is Object and is_instance_valid(entity):
		if "is_special_entity" in entity and bool(entity.get("is_special_entity")):
			return true
		if "is_always_visible" in entity and bool(entity.get("is_always_visible")):
			return true
	return false

## 대상 엔티티에 특수 개체 상시 표시 플래그 부여
static func mark_special(entity: Variant) -> void:
	if entity is Dictionary:
		entity["is_special_entity"] = true
		entity["is_always_visible"] = true
	elif entity is Object and is_instance_valid(entity):
		if "is_special_entity" in entity:
			entity.set("is_special_entity", true)
		if "is_always_visible" in entity:
			entity.set("is_always_visible", true)
		if entity.has_method("set_custom_participation"):
			entity.call("set_custom_participation", true)
