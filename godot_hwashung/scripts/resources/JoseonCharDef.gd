extends Resource
class_name JoseonCharDef

## [조선시대 45도 아이소메트릭 캐릭터 정의 리소스]

# 45도 대각선 뷰(Isometric) 4방향 엄격 적용
enum IsoDir {
	DOWN_LEFT = 0,  # 좌하단 (South-West)
	DOWN_RIGHT = 1, # 우하단 (South-East)
	UP_LEFT = 2,    # 좌상단 (North-West)
	UP_RIGHT = 3    # 우상단 (North-East)
}

# 보행 애니메이션 (방향당 2프레임 교차)
enum AnimPhase {
	WALK_FRAME_1 = 0, # 왼발 전진 / 옷깃 펄럭임 A
	WALK_FRAME_2 = 1  # 오른발 전진 / 옷깃 펄럭임 B
}

enum BodyType {
	YOUNG_MALE = 0,
	MIDDLE_MALE = 1,
	ELDER_MALE = 2,
	MUSCULAR_MALE = 3,
	FEMALE_YOUNG = 4,
	FEMALE_MIDDLE = 5,
	CHILD = 6
}

enum HeadgearType {
	NONE = 0,
	TOPKNOT = 1,
	HEUNGLIP = 2,        # 흑립 (갓)
	OSAMO = 3,           # 오사모 (관리)
	OSAMO_HIGH = 4,      # 1품 당상관 높은 오사모
	IKSEONGWAN = 5,      # 익선관 (국왕)
	JEONRIP = 6,         # 전립 (무관/포졸)
	JEONRIP_RED = 7,     # 붉은 상모 전립 (지휘관)
	JEONGJAGWAN = 8,     # 정자관 (학자)
	YUGEON = 9,          # 유건 (선비)
	HEADBAND = 10,       # 땀수건 머리띠 (석수/장인)
	PAERAENGI = 11,      # 패랭이 (보부상/목수)
	SATGAT = 12,         # 삿갓
	GACHE = 13,          # 가체 (부인/기생)
	SCARF = 14,          # 머리수건 (아낙)
	IRON_HELMET = 15     # 철제 투구 (무장)
}

enum BeardType {
	NONE = 0,
	STUBBLE = 1,
	THIN_MUSTACHE = 2,
	SHORT_BEARD = 3,
	MEDIUM_BEARD = 4,
	FULL_BEARD = 5,
	THICK_WHITE = 6,
	LONG_BLACK = 7
}

enum PropLocation {
	NONE = 0,
	HAND_R = 1,
	HAND_L = 2,
	BOTH_HANDS = 3,
	BACK = 4,
	WAIST = 5
}

@export var asset_id: String = ""
@export var character_name: String = ""
@export var body_type: BodyType = BodyType.MIDDLE_MALE
@export var headgear: HeadgearType = HeadgearType.HEUNGLIP
@export var beard: BeardType = BeardType.NONE
@export var garment_palette: String = "scholar_teal"
@export var has_rank_badge: bool = false
@export var has_dragon_bo: bool = false
@export var prop_id: String = ""
@export var prop_location: PropLocation = PropLocation.NONE
