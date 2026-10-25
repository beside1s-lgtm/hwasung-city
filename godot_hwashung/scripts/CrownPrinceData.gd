extends RefCounted
class_name CrownPrinceData

## [왕세자(순조) 6단계 성장 비주얼, 대사 및 보너스 데이터]
## 세자 경연(왕세자 교육) 진척도(0~100점)에 따른 캐릭터 외형·성장 FSM 데이터 정의

const STAGE_PORTRAIT_PATHS: Array[String] = [
	"res://assets/portraits/crown_prince/stage_01.png",
	"res://assets/portraits/crown_prince/stage_02.png",
	"res://assets/portraits/crown_prince/stage_03.png",
	"res://assets/portraits/crown_prince/stage_04.png",
	"res://assets/portraits/crown_prince/stage_05.png",
	"res://assets/portraits/crown_prince/stage_06.png"
]

const STAGE_TITLES: Array[String] = [
	"유아 세자",
	"어린이 세자",
	"사춘기 학생 세자",
	"청년 세자",
	"책벌레 세자",
	"성인 군주"
]

const STAGE_TITLE_BADGES: Array[String] = [
	"[제1단계: 헐렁한 곤룡포의 유아 세자]",
	"[제2단계: 호기심 가득한 어린이 세자]",
	"[제3단계: 고뇌와 사색의 학생 세자]",
	"[제4단계: 문무를 겸비한 청년 세자]",
	"[제5단계: 안경을 쓴 지적인 책벌레 세자]",
	"[제6단계: 위풍당당한 완성형 성인 군주]"
]

const STAGE_DESCRIPTIONS: Array[String] = [
	"몸에 맞지 않는 헐렁한 큰 곤룡포에 삐뚤빼뚤 얹어진 익선관, 장난기 넘치는 어린 세자입니다.",
	"단정해진 아동용 배자를 입고 똘망똘망한 눈망울로 호기심 가득하게 붓을 쥐고 있습니다.",
	"키가 훌쩍 자라 진지한 눈매로 팔짱을 끼고 고뇌하며 성현의 도를 탐구하는 사춘기 세자입니다.",
	"늠름한 체구와 곧은 자세로 칠성검과 병법서를 갖춘 듬직한 문무겸비의 청년 세자입니다.",
	"은테 수정 안경을 착용하고 온화하고 깊은 눈빛으로 규장각 서책을 탐독하는 학자형 세자입니다.",
	"찬란한 황금빛 곤룡포와 위엄 있는 익선관을 갖춘 성군의 자애로움과 결단력이 완성된 군주입니다."
]

const STAGE_QUOTES: Array[String] = [
	"아바마마, 글공부는 너무 지루하옵니다... 나비 잡으러 가도 되옵니까?",
	"소자, 논어의 한 구절을 깨쳤사옵니다! 백성을 사랑하는 마음이 무엇입니까?",
	"옛 성현의 말씀이 오늘날 백성들의 고통을 어찌 다 구제한단 말입니까...",
	"북벌과 부국강병은 한 몸이옵니다. 장용영 군사들을 친히 사열하겠나이다.",
	"정조 대왕의 뜻을 받들어 규장각의 모든 서책을 섭렵하여 화성을 빛내겠나이다.",
	"백성이 나라의 근본이요, 군주는 그 근본을 섬기는 종이라. 탕탕평평의 치세를 열겠노라!"
]

const STAGE_BUFF_TEXTS: Array[String] = [
	"-",
	"민심 +2",
	"연구속도 +3%",
	"도시 국방력 +50",
	"학문력 +10",
	"민심 +15, 왕권 +20"
]

## 캐싱된 초상화 텍스처 딕셔너리
static var _portrait_cache: Dictionary = {}

## 초상화 텍스처 사전 로딩 (O(1) 캐시)
static func get_portrait_texture(stage_index: int) -> Texture2D:
	var idx: int = clampi(stage_index, 0, 5)
	if _portrait_cache.has(idx):
		return _portrait_cache[idx]
	# PORT-TRACE [세자 초상 안 보임]: 그림 파일이 .jpg로 들어와 .png 경로를 못 찾았다 → png·jpg·webp 모두 찾는다
	var base: String = STAGE_PORTRAIT_PATHS[idx].get_basename()
	for ext: String in [".png", ".jpg", ".jpeg", ".webp"]:
		var path: String = base + ext
		var tex: Texture2D = null
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
		elif FileAccess.file_exists(AssetPaths.disk_path(path)):
			var img := Image.load_from_file(AssetPaths.disk_path(path))
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
		if tex != null:
			_portrait_cache[idx] = tex
			return tex
	return null

## 점수(0.0 ~ 100.0)에 따른 단계 인덱스(0 ~ 5) 반환
## - 0: 0~20점 (유아)
## - 1: 21~40점 (어린이)
## - 2: 41~60점 (사춘기)
## - 3: 61~80점 (청년)
## - 4: 81~99점 (책벌레)
## - 5: 100점 (성인 군주)
static func get_stage_by_score(score: float) -> int:
	if score >= 100.0:
		return 5
	elif score >= 81.0:
		return 4
	elif score >= 61.0:
		return 3
	elif score >= 41.0:
		return 2
	elif score >= 21.0:
		return 1
	else:
		return 0

static func get_stage_title(stage_idx: int) -> String:
	var idx: int = clampi(stage_idx, 0, 5)
	return STAGE_TITLES[idx]

static func get_stage_badge(stage_idx: int) -> String:
	var idx: int = clampi(stage_idx, 0, 5)
	return STAGE_TITLE_BADGES[idx]

static func get_stage_quote(stage_idx: int) -> String:
	var idx: int = clampi(stage_idx, 0, 5)
	return STAGE_QUOTES[idx]

static func get_stage_description(stage_idx: int) -> String:
	var idx: int = clampi(stage_idx, 0, 5)
	return STAGE_DESCRIPTIONS[idx]

static func get_stage_buff_text(stage_idx: int) -> String:
	var idx: int = clampi(stage_idx, 0, 5)
	return STAGE_BUFF_TEXTS[idx]
