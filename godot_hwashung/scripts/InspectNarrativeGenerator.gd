extends RefCounted
class_name InspectNarrativeGenerator

const SpriteCacheManager = preload("res://scripts/autoload/SpriteCacheManager.gd")

## 수원화성 살피기(Inspect) 동적 스토리텔링 생성기
## 네임드 NPC 고증 일러스트 매핑 및 20자 규격 (건물 4줄, 네임드 3~4줄, NPC/동물 2줄) 텍스트 자동 조합
## 방리 세부 시설, 저잣거리 상점가 위치/업종별, NPC FSM 행동 상태별, 특수 건물 고증 전면 개편

# ------------------------------------------------------------ 0. 11종 세시풍속 및 민속놀이 역사 고증 이야기꾼 해설 딕셔너리
const FOLKLORE_NARRATIVES: Dictionary = {
	"ACTIVITY_JWIBULNORI": {
		"title": "논둑을 밝히는 쥐불놀이",
		"description": "정월 대보름을 맞아 액을 쫓으려 쥐불을 놓았지요.\n잡초를 태워 해충 알을 없애고 풍년을 기원했는데,\n가끔 불이 번져 관아 멸화군이 출동하기도 했지만\n밤하늘을 수놓는 불꽃 원은 최고의 볼거리였답니다!",
		"portrait": "jwibul",
		"category": "folklore"
	},
	"ACTIVITY_SEOKJEON": {
		"title": "기백을 겨루는 정월 석전",
		"description": "개천을 사이에 두고 돌을 던져 편을 가르는 놀이지요.\n다치는 사람이 속출할 만큼 거칠고 사나웠지만,\n이 기개로 외적을 물리치던 유서 깊은 풍속이랍니다.\n상무 정신을 기르라며 나라에서도 권장했지요!",
		"portrait": "seokjeon",
		"category": "folklore"
	},
	"ACTIVITY_KITE_FLYING": {
		"title": "액운을 띄워 보내는 연날리기",
		"description": "새해 첫 보름날 온갖 액운을 연에 적어 띄웠지요.\n하늘 높이 연을 올린 뒤 줄을 탁 끊어 날려 보내면\n한 해의 모든 재앙이 훨훨 날아간다고 믿었답니다.\n바람을 가르는 방패연의 날갯짓이 참 시원하지요?",
		"portrait": "kite",
		"category": "folklore"
	},
	"ACTIVITY_SSIREUM_CHAMPION": {
		"title": "황소를 탄 단오 천하장사",
		"description": "단오 씨름판에서 쟁쟁한 장사들을 꺾은 영웅이랍니다!\n상으로 받은 늠름한 황소 등에 올라타 풍악을 울리니\n온 동네 백성들이 꽃가루를 뿌리며 환호하지요.\n고된 농사일을 잊게 해주는 가슴 벅찬 잔치였답니다.",
		"portrait": "bull_parade",
		"category": "folklore"
	},
	"ACTIVITY_GANGGANGSULLAE": {
		"title": "달빛 아래 도는 추석 강강술래",
		"description": "휘영청 밝은 한가위 보름달 아래 손을 맞잡았지요.\n아낙들이 발을 구르고 노래하며 둥글게 원을 그리니\n풍요로운 수확의 기쁨이 온 고을에 넘쳐난답니다.\n임진왜란 때 의병의 기세를 떨치던 춤이기도 하지요!",
		"portrait": "ganggang",
		"category": "folklore"
	},
	"ACTIVITY_LION_DANCE": {
		"title": "잡귀를 몰아내는 북청 사자춤",
		"description": "방울을 딸랑이며 덩실덩실 춤추는 신령한 사자랍니다!\n사나운 사자의 탈과 몸짓으로 마을 잡귀를 쫓아내고\n백성들의 무병장수를 빌어주는 신명 나는 놀이지요.\n사자 입에 머리를 넣으면 액을 면한다 믿었답니다.",
		"portrait": "lion",
		"category": "folklore"
	},
	"ACTIVITY_NEOLTTWIGI": {
		"title": "담장 너머를 엿보는 널뛰기",
		"description": "짚단을 괸 널빤지 양끝에서 번갈아 발을 구르지요!\n담장 안에 갇혀 지내던 규수들이 하늘 높이 솟구쳐\n바깥세상을 시원하게 구경하던 유일한 낙이었답니다.\n발끝이 허공을 찰 때마다 오색 치맛자락이 곱지요.",
		"portrait": "neolttwigi",
		"category": "folklore"
	},
	"ACTIVITY_SWINGING": {
		"title": "푸른 숲을 가르는 단오 그네",
		"description": "수릿날 창포물에 머리 감고 높은 그네에 올랐지요.\n하늘에 닿을 듯 치솟아 오르며 여름 더위를 쫓아내고\n가장 높이 뛴 아낙에게 놋대야나 거울을 주었답니다.\n새처럼 허공을 가르는 모습이 신선처럼 어여쁘지요!",
		"portrait": "swing",
		"category": "folklore"
	},
	"ACTIVITY_YARD_GAMES": {
		"title": "골목길 딱지치기와 제기차기",
		"description": "돌멩이로 비석을 치고 엽전을 싼 제기를 차며 놉니다!\n동네 아이들이 편을 갈라 해 질 녘까지 뛰놀다 보면\n어머니의 \"밥 먹어라!\" 부르는 소리가 들려왔지요.\n구김살 없이 자라는 아이들이 바로 수원의 미래랍니다.",
		"portrait": "kids",
		"category": "folklore"
	},
	"ACTIVITY_NAMSADANG": {
		"title": "줄을 타고 버나를 돌리는 남사당패",
		"description": "장터를 떠돌며 서민들의 한과 시름을 달래주는 광대지요!\n공중에서 아슬아슬 줄을 타고 대접을 뱅뱅 돌리며\n부패한 벼슬아치를 풍자하여 배꼽을 잡게 만든답니다.\n북과 징 소리에 묵은 체증이 싹 내려가는 기분이지요!",
		"portrait": "namsadang",
		"category": "folklore"
	},
	"ACTIVITY_JEONJISU": {
		"title": "이야기보따리를 푸는 전기수",
		"description": "소설을 맛깔나게 읽어주는 조선 최고의 이야기꾼이지요!\n가장 긴장되는 대목에서 딱 입을 닫고 뜸을 들이면\n애가 탄 청중들이 엽전을 짤랑짤랑 던져주었답니다.\n목소리 하나로 장터 백성들을 울리고 웃기는 재주꾼이죠!",
		"portrait": "jeongisu",
		"category": "folklore"
	},
	# 추가 고증 세시풍속 (보완)
	"ACTIVITY_PUNGMUL": {
		"title": "온 마을을 울리는 지신밟기 풍물패",
		"description": "꽹과리와 징, 장구와 북을 치며 고을 지신을 밟지요!\n집집마다 돌며 잡귀를 쫓고 풍년과 다복을 빌어주니\n주인장이 술과 밥을 내어 풍물패를 융숭히 대접했답니다.\n상모를 빙빙 돌리는 재담에 온 동네가 들썩들썩하지요!",
		"portrait": "pungmul",
		"category": "folklore"
	},
	"ACTIVITY_SSIREUM": {
		"title": "모래판 위의 용호상박 단오 씨름",
		"description": "단오 명절에 건장한 장정들이 샅바를 단단히 맸지요!\n모래판에 먼지를 날리며 들배지기와 안다리를 거니\n누가 이길지 손에 땀을 쥐며 백성들이 환호한답니다.\n우승자는 황소를 타고 금의환향하는 영예를 누렸지요!",
		"portrait": "ssireum",
		"category": "folklore"
	},
	"ACTIVITY_TALCHUM": {
		"title": "양반을 풍자하는 신명 탈춤",
		"description": "익살스러운 탈을 쓰고 긴 한삼 소매를 너울거리며\n거드름 피우는 양반의 위선을 속 시원히 꼬집지요!\n말뚝이의 걸쭉한 재담에 백성들의 웃음보가 터지며\n쌓였던 설움과 시름을 한바탕 춤사위로 털어낸답니다!",
		"portrait": "talchum",
		"category": "folklore"
	},
	"ACTIVITY_PAENGI": {
		"title": "겨울 얼음판의 팽이치기",
		"description": "추운 겨울 꽁꽁 언 수원천 얼음판 위에 모였지요!\n나무를 깎아 만든 팽이에 명주실 채찍을 힘껏 치면\n얼음 위를 쌩쌩 돌며 멈출 줄 모르고 회전한답니다.\n추위도 잊은 채 팽이싸움을 벌이는 아이들이 정겹지요!",
		"portrait": "paengi",
		"category": "folklore"
	},
	"ACTIVITY_TAEKKYEON": {
		"title": "이크 에크! 유연한 택견 겨루기",
		"description": "능청구수하게 품을 밟으며 발길질을 주고받지요!\n상대를 해치지 않고 발로 턱을 차거나 넘어뜨리니\n예의와 화합을 중시하는 우리 고유의 무예랍니다.\n유연하면서도 번개 같은 공격에 감탄이 절로 나오지요!",
		"portrait": "taekkyeon",
		"category": "folklore"
	}
}

const ACTIVITY_KEY_MAP: Dictionary = {
	"activity_jwibulnori": "ACTIVITY_JWIBULNORI",
	"jwibul": "ACTIVITY_JWIBULNORI",
	"jwibulnori": "ACTIVITY_JWIBULNORI",
	"activity_seokjeon": "ACTIVITY_SEOKJEON",
	"seokjeon": "ACTIVITY_SEOKJEON",
	"activity_kite_flying": "ACTIVITY_KITE_FLYING",
	"kite": "ACTIVITY_KITE_FLYING",
	"kites": "ACTIVITY_KITE_FLYING",
	"kite_flying": "ACTIVITY_KITE_FLYING",
	"activity_ssireum_champion": "ACTIVITY_SSIREUM_CHAMPION",
	"bull_parade": "ACTIVITY_SSIREUM_CHAMPION",
	"ssireum_champion": "ACTIVITY_SSIREUM_CHAMPION",
	"activity_ganggangsullae": "ACTIVITY_GANGGANGSULLAE",
	"ganggang": "ACTIVITY_GANGGANGSULLAE",
	"ganggangsullae": "ACTIVITY_GANGGANGSULLAE",
	"activity_lion_dance": "ACTIVITY_LION_DANCE",
	"lion": "ACTIVITY_LION_DANCE",
	"lion_dance": "ACTIVITY_LION_DANCE",
	"activity_neolttwigi": "ACTIVITY_NEOLTTWIGI",
	"neolttwigi": "ACTIVITY_NEOLTTWIGI",
	"activity_swinging": "ACTIVITY_SWINGING",
	"swing": "ACTIVITY_SWINGING",
	"swinging": "ACTIVITY_SWINGING",
	"activity_yard_games": "ACTIVITY_YARD_GAMES",
	"yard_games": "ACTIVITY_YARD_GAMES",
	"kids": "ACTIVITY_YARD_GAMES",
	"kids_play": "ACTIVITY_YARD_GAMES",
	"playing": "ACTIVITY_YARD_GAMES",
	"activity_namsadang": "ACTIVITY_NAMSADANG",
	"namsadang": "ACTIVITY_NAMSADANG",
	"juldagi": "ACTIVITY_NAMSADANG",
	"sandang": "ACTIVITY_NAMSADANG",
	"activity_jeonjisu": "ACTIVITY_JEONJISU",
	"activity_jeongisu": "ACTIVITY_JEONJISU",
	"jeongisu": "ACTIVITY_JEONJISU",
	"jeonjisu": "ACTIVITY_JEONJISU",
	"activity_pungmul": "ACTIVITY_PUNGMUL",
	"pungmul": "ACTIVITY_PUNGMUL",
	"pungmul_band": "ACTIVITY_PUNGMUL",
	"activity_ssireum": "ACTIVITY_SSIREUM",
	"ssireum": "ACTIVITY_SSIREUM",
	"activity_talchum": "ACTIVITY_TALCHUM",
	"talchum": "ACTIVITY_TALCHUM",
	"activity_paengi": "ACTIVITY_PAENGI",
	"paengi": "ACTIVITY_PAENGI",
	"activity_taekkyeon": "ACTIVITY_TAEKKYEON",
	"taekkyeon": "ACTIVITY_TAEKKYEON",
}

static func normalize_activity_key(raw_key: String) -> String:
	var clean: String = raw_key.strip_edges()
	if clean == "":
		return ""
	if FOLKLORE_NARRATIVES.has(clean):
		return clean
	var lk: String = clean.to_lower()
	if ACTIVITY_KEY_MAP.has(lk):
		return str(ACTIVITY_KEY_MAP[lk])
	return ""

const KOREAN_FACILITY_NAMES: Dictionary = {
	"gwana": "화성유수부 동헌 (관아)",
	"gwana_site": "화성유수부 동헌 (관아)",
	"res_1": "소박한 서민 초가집",
	"res_2": "단정한 살림 기와집 (여염집)",
	"res_3": "고급 사대부 기와집",
	"seowon": "화성 유학 서원 (書院)",
	"maegok_seowon": "화성 유학 서원 (書院)",
	"seodang": "동네 서당 (글방)",
	"guesthouse": "화성 우하 객사",
	"factory": "관영 장인 공방",
	"yeonghwajeong": "화성 영화정 (迎華亭)",
	"yeonghwajeong_site": "화성 영화정 (迎華亭)",
	"hyeminseo": "고을 혜민서",
	"cattle": "수원 우시장 (쇠전)",
	"play": "방리 마당놀이 터 (풍물마당)",
	"kids": "골목 안 동네 놀이터"
}

const KOREAN_NAMES: Dictionary = {
	# 관아 및 행정
	"gwana": "화성유수부 동헌 (관아)",
	"gwana_site": "화성유수부 동헌 (관아)",
	"res_1": "소박한 서민 초가집",
	"res_2": "단정한 살림 기와집 (여염집)",
	"res_3": "고급 사대부 기와집",
	"seowon": "화성 유학 서원 (書院)",

	# 성곽 및 방어 시설
	"wall": "체성 성곽",
	"fort": "화성 요새",
	"gate": "사대문",
	"poru": "화성 포루",
	"dongporu": "동포루",
	"seoporu": "서포루",
	"bukporu": "북포루",
	"namporu": "남포루",
	"gongsimdon": "화성 공심돈",
	"dongbuk_gongsimdon": "동북공심돈",
	"seobuk_gongsimdon": "서북공심돈",
	"bongdon": "화성 봉돈",
	"beacon": "화성 봉돈",
	"seojangdae": "화성 서장대",
	"dongjangdae": "동장대 연무대",
	"yeonmudae": "동장대 연무대",
	"banghwasuryujeong": "동북각루 방화수류정",
	"dongbuk_gakru": "동북각루 방화수류정",
	"hwahongmun": "화홍문 북수문",
	"buksumun": "화홍문 북수문",
	"hwahong_mun": "화성 화홍문 (華虹門)",
	"namsumun": "화성 남수문",
	"namsu_mun": "화성 남수문 (南水門)",
	"maehwang_gyo": "수원천 매향교 (梅香橋)",
	"maehyang_gyo": "수원천 매향교 (梅香橋)",
	"patrol": "순라청",
	"firefighter": "멸화군 수성소",

	# 도시 인프라 및 상업/문화
	"jongnu": "화성 십자로 종루",
	"jongnu_site": "화성 십자로 종루",
	"bell_tower": "화성 십자로 종루",
	"haenggung": "화성행궁",
	"haenggung_site": "화성행궁",
	"market": "화성 저잣거리",
	"seodang": "고을 훈장님 서당",
	"hyanggyo": "수원향교",
	"reservoir": "만석거",
	"chukmanje": "축만제 (서호)",
	"jinhulso": "진휼소",
	"embankment": "수원천 석축제방",
	"levee": "수원천 석축제방",
	"dike": "수원천 석축제방",
	"road": "주간선 도로",
	"street": "주간선 도로",
	"stone_road": "화성 박석길",
	"road_dirt": "흙길",
	"road_stone": "박석길",

	# 방리 세부 시설
	"cattle": "수원 우시장",
	"cattle_market": "수원 우시장",
	"play": "마당놀이 터",
	"kids": "골목 놀이터",
	"market_stall": "난전 장터",
	"agr_1": "화성 외곽 둔전 (일반 논배미)",
	"agr_2": "대유둔전 (관개 대농장)",
	"zone_agr": "대유둔전 경작 구역",

	# 특수 공공 시설
	"guesthouse": "화성 우하 객사",
	"factory": "관영 장인 공방",
	"yeonghwajeong": "화성 영화정 (迎華亭)",
	"yeonghwajeong_site": "화성 영화정 (迎華亭)",
	"hyeminseo": "고을 혜민서",

	# 여러 칸 구조물의 부위와 터
	"banghwasuryu": "동북각루 방화수류정",
	"yongyeon": "용연 (龍淵)",
	"yeonmudae_site": "연무대 연병장",
	"yeonmudae_range": "연무대 활터",
	"seojangdae_site": "화성 서장대",
	"bongdon_site": "화성 봉돈",
	"poru_site": "화성 포루",
	"gongsimdon_site": "화성 공심돈",
	"gongsimdon_wall": "화성 공심돈",
	"manseokgeo": "만석거 (萬石渠)",
	"manseokgeo_site": "만석거 (萬石渠)",
	"chukmanje_site": "축만제 (祝萬堤)",
	"hyanggyo_site": "수원향교 (水原鄕校)",
	"canal": "대유평 관개 수로",
	"well": "마을 공동 우물",
	"hwahong": "화홍문 (華虹門)",
	"ind_1": "수공업 공방",
	"ind_2": "큰 수공업 공방",

	# 지형
	"plain": "너른 들판",
	"mountain": "팔달산",
	"water": "수원천",
	"forest": "소나무 숲",
	"burned_wasteland": "화재 전소지"
}

static func get_korean_name(key: String, fallback: String = "화성 시설") -> String:
	var k: String = key.to_lower().strip_edges()
	if KOREAN_FACILITY_NAMES.has(k):
		return str(KOREAN_FACILITY_NAMES[k])
	if KOREAN_NAMES.has(k):
		return str(KOREAN_NAMES[k])
	if KOREAN_NAMES.has(key):
		return str(KOREAN_NAMES[key])

	# 패턴 기반 한글 fallback (Zero-English Fallback)
	if k.begins_with("res_"):
		if k == "res_1": return "소박한 서민 초가집"
		if k == "res_2": return "단정한 살림 기와집 (여염집)"
		if k == "res_3": return "고급 사대부 기와집"
		return "조선 백성의 민가"
	elif k.begins_with("com_"):
		return "화성 저잣거리 상점"
	elif k.begins_with("ind_"):
		return "화성 관영 공방"
	elif k.contains("gwana"):
		return "화성유수부 동헌 (관아)"
	elif k.contains("seowon"):
		return "화성 유학 서원 (書院)"
	elif k.contains("seodang"):
		return "고을 훈장님 서당 (글방)"
	elif k.contains("site"):
		return "화성 공공 시설"

	# 영문 식별자가 그대로 노출되지 않도록 영문 알파벳 포함 여부 검사
	var has_alpha: bool = false
	for i in range(key.length()):
		var code: int = key.unicode_at(i)
		if (code >= 65 and code <= 90) or (code >= 97 and code <= 122):
			has_alpha = true
			break
	if has_alpha:
		var fb_has_alpha: bool = false
		for j in range(fallback.length()):
			var fcode: int = fallback.unicode_at(j)
			if (fcode >= 65 and fcode <= 90) or (fcode >= 97 and fcode <= 122):
				fb_has_alpha = true
				break
		if fb_has_alpha or fallback.is_empty():
			return "화성 시설"
		return fallback
	return key if key != "" else fallback

static var PORTRAITS: Dictionary = {}
static var _is_cached: bool = false
static var _encyclopedia_cache: Dictionary = {}

const ENCYCLOPEDIA_ALIAS_MAP: Dictionary = {
	# 1. 인물 24종 및 별칭
	"baek_dongsoo": "baek_dongsu",
	"baek_dongsu": "baek_dongsu",
	"kim_pankwan": "kim_pangwan",
	"kim_pangwan": "kim_pangwan",
	"kim_jeonghee": "kim_jeonghui",
	"kim_jeonghui": "kim_jeonghui",
	"sim_hwanji": "sim_hwanji",
	"shim_hwanji": "sim_hwanji",
	"yi_deokmu": "lee_deokmu",
	"lee_deokmu": "lee_deokmu",
	"yi_gahwan": "lee_gahwan",
	"lee_gahwan": "lee_gahwan",
	"yi_gigyeong": "lee_gigyeong",
	"lee_gigyeong": "lee_gigyeong",
	"yi_seonggil": "lee_seonggil",
	"lee_seonggil": "lee_seonggil",
	"gu_seon_bok": "gu_seonbok",
	"gu_seonbok": "gu_seonbok",
	"chae_jegong": "chae_jegong",
	"jeong_yakyong": "jeong_yakyong",
	"kim_hongdo": "kim_hongdo",
	"hong_inhan": "hong_inhan",
	"kim_josun": "kim_josun",
	"park_jega": "park_jega",
	"seo_yugu": "seo_yugu",
	"jeong_beomjo": "jeong_beomjo",
	"yu_deukgong": "yu_deukgong",
	"park_jiwon": "park_jiwon",
	"hong_daeyong": "hong_daeyong",
	"hong_gukyeong": "hong_gukyeong",
	"jo_simtae": "jo_simtae",
	"kim_bau": "kim_bau",
	"musoe": "musoe",
	"yu_hanji": "yu_hanji",

	# 2. 건물 16종 및 별칭
	"haenggung": "haenggung",
	"haenggung_site": "haenggung",
	"seojangdae": "seojangdae",
	"yeonmudae": "yeonmudae",
	"yeonmudae_site": "yeonmudae",
	"yeonmudae_range": "yeonmudae",
	"dongjangdae": "yeonmudae",
	"manseokgeo": "manseokgeo",
	"manseokgeo_site": "manseokgeo",
	"reservoir": "manseokgeo",
	"chukmanje": "chukmanje",
	"patrol": "patrol",
	"patrol_post": "patrol",
	"firefighter": "firefighter",
	"firestation": "firefighter",
	"jinhulso": "jinhulso",
	"hyeminseo": "jinhulso",
	"hyanggyo": "hyanggyo",
	"hyanggyo_site": "hyanggyo",
	"seowon": "hyanggyo",
	"maegok_seowon": "hyanggyo",
	"gate": "sadaemun",
	"gate_jangan": "sadaemun",
	"gate_paldal": "sadaemun",
	"gate_hwaseo": "sadaemun",
	"gate_changryong": "sadaemun",
	"sadaemun": "sadaemun",
	"hwahongmun": "hwahongmun",
	"hwahong_mun": "hwahongmun",
	"buksumun": "hwahongmun",
	"namsumun": "namsumun",
	"namsu_mun": "namsumun",
	"jongnu": "jongnu",
	"jongnu_site": "jongnu",
	"bell_tower": "jongnu",
	"usijang": "usijang",
	"cattle": "usijang",
	"cattle_market": "usijang",
	"seodang": "seodang",
	"market": "jangmadang",
	"jangmadang": "jangmadang",
	"market_plaza": "jangmadang",
	"shop": "jangmadang",
	"shop_silk": "jangmadang",
	"shop_fish": "jangmadang",
	"shop_rice": "jangmadang",
	"shop_smith": "smith",
	"shop_jumak": "jangmadang",
	"commercial": "jangmadang",

	# 3. 세시풍속 / 백성의 생활상 20종 및 별칭
	"jwibul": "jwibul",
	"activity_jwibulnori": "jwibul",
	"jwibulnori": "jwibul",
	"seokjeon": "seokjeon",
	"activity_seokjeon": "seokjeon",
	"kite": "kite",
	"kites": "kite",
	"kite_flying": "kite",
	"activity_kite_flying": "kite",
	"bull_parade": "ssireum_parade",
	"ssireum_champion": "ssireum_parade",
	"activity_ssireum_champion": "ssireum_parade",
	"ssireum": "ssireum_parade",
	"activity_ssireum": "ssireum_parade",
	"ssireum_parade": "ssireum_parade",
	"ganggang": "ganggang",
	"ganggangsullae": "ganggang",
	"activity_ganggangsullae": "ganggang",
	"lion": "lion_dance",
	"lion_dance": "lion_dance",
	"activity_lion_dance": "lion_dance",
	"neolttwigi": "neolttwigi",
	"activity_neolttwigi": "neolttwigi",
	"swing": "swing",
	"swinging": "swing",
	"activity_swinging": "swing",
	"kids": "yard_games",
	"kids_play": "yard_games",
	"playing": "yard_games",
	"yard_games": "yard_games",
	"activity_yard_games": "yard_games",
	"paengi": "yard_games",
	"activity_paengi": "yard_games",
	"play": "yard_games",
	"play_yard": "yard_games",
	"namsadang": "namsadang",
	"juldagi": "namsadang",
	"sandang": "namsadang",
	"activity_namsadang": "namsadang",
	"pungmul": "namsadang",
	"activity_pungmul": "namsadang",
	"talchum": "namsadang",
	"activity_talchum": "namsadang",
	"taekkyeon": "ssireum_parade",
	"activity_taekkyeon": "ssireum_parade",
	"jeongisu": "jeongisu",
	"jeonjisu": "jeongisu",
	"activity_jeongisu": "jeongisu",
	"activity_jeonjisu": "jeongisu",
	"farmer_ox": "farmer_ox",
	"farmer": "farmer_ox",
	"ox": "farmer_ox",
	"paddy": "farmer_ox",
	"daeyu": "farmer_ox",
	"mason": "mason",
	"stonemason": "mason",
	"smith": "smith",
	"blacksmith": "smith",
	"bobusang": "bobusang",
	"washer": "washer",
	"washing": "washer",
	"wash": "washer",
	"catholic": "catholic",
	"cheonju": "catholic",
	"jangyong_drill": "jangyong_drill",
	"drill": "jangyong_drill",
	"jangyongyeong": "jangyong_drill",
	"pabal": "pabal",
	"pabalma": "pabal",
	"wonhaeng": "wonhaeng",
	"royal_procession": "wonhaeng",
	"parade": "wonhaeng",
	"procession": "wonhaeng",
}

static func _get_encyclopedia_portrait(key: String) -> Texture2D:
	if _encyclopedia_cache.has(key):
		return _encyclopedia_cache[key] as Texture2D

	var candidate_keys: Array[String] = []
	if ENCYCLOPEDIA_ALIAS_MAP.has(key):
		var mapped_key: String = str(ENCYCLOPEDIA_ALIAS_MAP[key])
		candidate_keys.append(mapped_key)
	if not (key in candidate_keys):
		candidate_keys.append(key)

	for k in candidate_keys:
		for ext in [".png", ".jpg", ".jpeg", ".webp"]:
			var res_p: String = "res://assets/encyclopedia/" + k + ext
			if ResourceLoader.exists(res_p):
				var tex: Texture2D = load(res_p) as Texture2D
				if tex != null:
					_encyclopedia_cache[key] = tex
					return tex
			var gpath: String = ProjectSettings.globalize_path(res_p)
			if FileAccess.file_exists(gpath):
				var img: Image = Image.new()
				var err: Error = img.load(gpath)
				if err == OK and not img.is_empty():
					var itex: ImageTexture = ImageTexture.create_from_image(img)
					_encyclopedia_cache[key] = itex
					return itex

	_encyclopedia_cache[key] = null
	return null

## 시설마다 따로 넣은 사진(assets/encyclopedia/<키>.jpg 등)이 있으면 그것, 없으면 공통 그림.
## 별칭표를 거치지 않고 파일 이름 그대로만 찾는다(예: gate_jangan.jpg가 없으면 sadaemun.jpg로).
static func portrait_pref(specific: Array, generic: String) -> Texture2D:
	for k: String in specific:
		var ck := "@" + k
		if _encyclopedia_cache.has(ck):
			if _encyclopedia_cache[ck] != null:
				return _encyclopedia_cache[ck] as Texture2D
			continue
		var found: Texture2D = null
		for ext in [".png", ".jpg", ".jpeg", ".webp"]:
			var res_p: String = "res://assets/encyclopedia/" + k + ext
			if ResourceLoader.exists(res_p):
				found = load(res_p) as Texture2D
			elif FileAccess.file_exists(ProjectSettings.globalize_path(res_p)):
				var img := Image.load_from_file(ProjectSettings.globalize_path(res_p))
				if img != null and not img.is_empty():
					found = ImageTexture.create_from_image(img)
			if found != null:
				break
		_encyclopedia_cache[ck] = found
		if found != null:
			return found
	return get_portrait(generic)

## ============================================================ 1. 초상화/대표 일러스트 캐싱 및 O(1) 조회
static func get_portrait(key: String) -> Texture2D:
	# 새로 제작된 고화질 프로필/인물화(encyclopedia) 최우선 조회
	var enc_tex: Texture2D = _get_encyclopedia_portrait(key)
	if enc_tex != null:
		return enc_tex

	# 48x48 네임드 26인 고유 초상화 우선 조회
	var named_tex: Texture2D = SpriteCacheManager.get_named_character_texture(key, true)
	if named_tex != null:
		return named_tex

	_ensure_cache()
	if key == "kim_pankwan":
		return PortraitArt.make(key) # 김판관은 학문력에 따라 모습이 바뀌므로 캐시 밖에서 매번 조회
	if PORTRAITS.has(key):
		return PORTRAITS[key]
	var dot: ImageTexture = PortraitArt.make(key) # 새로 늘린 그림(지형·장소 등)은 필요할 때 만든다
	if dot != null:
		PORTRAITS[key] = dot
		return dot
	# Fallback 기본 초상화
	if PORTRAITS.has("commoner"):
		return PORTRAITS["commoner"]
	return null

## 성문 이름에 맞는 문 그림(문마다 모습이 다르다)
static func _gate_portrait_key(gate_name: String) -> String:
	if gate_name.begins_with("장안문"):
		return "gate_jangan"
	if gate_name.begins_with("팔달문"):
		return "gate_paldal"
	if gate_name.begins_with("화서문"):
		return "gate_hwaseo"
	if gate_name.begins_with("창룡문"):
		return "gate_changryong"
	return "gate"

static func _ensure_cache() -> void:
	if _is_cached and not PORTRAITS.is_empty():
		return
	_generate_all_portraits()
	_is_cached = true

static func _generate_all_portraits() -> void:
	# 96x96 규격의 전통 한지풍 고품질 절차적 픽셀 아트 텍스처 생성
	PORTRAITS["jeongjo"] = _make_portrait("jeongjo")
	PORTRAITS["jeong_yakyong"] = _make_portrait("jeong_yakyong")
	PORTRAITS["chae_jegong"] = _make_portrait("chae_jegong")
	PORTRAITS["kim_hongdo"] = _make_portrait("kim_hongdo")
	PORTRAITS["kim_pankwan"] = _make_portrait("kim_pankwan")
	PORTRAITS["kim_bau"] = _make_portrait("kim_bau")
	PORTRAITS["jo_simtae"] = _make_portrait("jo_simtae")
	PORTRAITS["gu_seonbok"] = _make_portrait("gu_seonbok")
	PORTRAITS["baek_dongsoo"] = _make_portrait("baek_dongsoo")
	PORTRAITS["baek_dongsu"] = PORTRAITS["baek_dongsoo"]

	# 건설 현장
	PORTRAITS["construction"] = _make_portrait("construction")

	# 주거 민가
	PORTRAITS["house_thatched"] = _make_portrait("house_thatched")
	PORTRAITS["house_tile"] = _make_portrait("house_tile")

	# 일반 보행 NPC
	PORTRAITS["merchant"] = _make_portrait("merchant")
	PORTRAITS["patrol_soldier"] = _make_portrait("patrol_soldier")
	PORTRAITS["farmer"] = _make_portrait("farmer")
	PORTRAITS["scholar"] = _make_portrait("scholar")
	PORTRAITS["artisan"] = _make_portrait("artisan")
	PORTRAITS["woodcutter"] = _make_portrait("woodcutter")
	PORTRAITS["hunter"] = _make_portrait("hunter")
	PORTRAITS["commoner"] = _make_portrait("commoner")

	# 야생 동물
	PORTRAITS["tiger"] = _make_portrait("tiger")
	PORTRAITS["wolf"] = _make_portrait("wolf")
	PORTRAITS["wild_boar"] = _make_portrait("wild_boar")
	PORTRAITS["deer"] = _make_portrait("deer")
	PORTRAITS["crane"] = _make_portrait("crane")
	PORTRAITS["rabbit"] = _make_portrait("rabbit")

	# 주요 공공 시설 및 특수 건물
	PORTRAITS["haenggung"] = _make_portrait("haenggung")
	PORTRAITS["gate"] = _make_portrait("gate")
	PORTRAITS["wall"] = _make_portrait("wall")
	PORTRAITS["fort"] = _make_portrait("fort")
	PORTRAITS["market"] = _make_portrait("market")
	PORTRAITS["facility"] = _make_portrait("facility")
	PORTRAITS["jongnu"] = _make_portrait("jongnu")
	PORTRAITS["seojangdae"] = _make_portrait("seojangdae")
	PORTRAITS["banghwasuryujeong"] = _make_portrait("banghwasuryujeong")
	PORTRAITS["hwahongmun"] = _make_portrait("hwahongmun")
	PORTRAITS["hwahong_mun"] = PORTRAITS["hwahongmun"]
	PORTRAITS["namsumun"] = _make_portrait("namsumun")
	PORTRAITS["namsu_mun"] = PORTRAITS["namsumun"]
	PORTRAITS["maehwang_gyo"] = _make_portrait("maehwang_gyo")
	PORTRAITS["maehyang_gyo"] = PORTRAITS["maehwang_gyo"]
	PORTRAITS["gongsimdon"] = _make_portrait("gongsimdon")
	PORTRAITS["bongdon"] = _make_portrait("bongdon")
	PORTRAITS["poru"] = _make_portrait("poru")
	PORTRAITS["yeonmudae"] = _make_portrait("yeonmudae")
	PORTRAITS["embankment"] = _make_portrait("embankment")
	PORTRAITS["road"] = _make_portrait("road")

	# 방리 세부 시설
	PORTRAITS["cattle"] = _make_portrait("cattle")
	PORTRAITS["play"] = _make_portrait("play")
	PORTRAITS["kids"] = _make_portrait("kids")
	PORTRAITS["seodang"] = _make_portrait("seodang")
	PORTRAITS["seowon"] = _make_portrait("seowon")

	# 저잣거리 상점
	PORTRAITS["shop_silk"] = _make_portrait("shop_silk")
	PORTRAITS["shop_fish"] = _make_portrait("shop_fish")
	PORTRAITS["shop_rice"] = _make_portrait("shop_rice")
	PORTRAITS["shop_smith"] = _make_portrait("shop_smith")
	PORTRAITS["shop_jumak"] = _make_portrait("shop_jumak")

	# NPC FSM 행동 상태
	PORTRAITS["seokjeon"] = _make_portrait("seokjeon")
	PORTRAITS["ssireum"] = _make_portrait("ssireum")
	PORTRAITS["kite"] = _make_portrait("kite")
	PORTRAITS["firefighting"] = _make_portrait("firefighting")
	PORTRAITS["hunting"] = _make_portrait("hunting")
	PORTRAITS["playing"] = _make_portrait("playing")
	PORTRAITS["washing"] = _make_portrait("washing")
	PORTRAITS["fishing"] = _make_portrait("fishing")
	PORTRAITS["cheering"] = _make_portrait("cheering")
	PORTRAITS["training"] = _make_portrait("training")

	# 조선 후기 6대 신분·직업군 고증 초상화
	PORTRAITS["jungin"] = _make_portrait("jungin")
	PORTRAITS["ajeon"] = _make_portrait("ajeon")
	PORTRAITS["bobusang"] = _make_portrait("bobusang")
	PORTRAITS["monk_soldier"] = _make_portrait("monk_soldier")
	PORTRAITS["butcher"] = _make_portrait("butcher")

	# 세시풍속 및 일상 민속놀이 전용 고증 초상화
	PORTRAITS["jwibul"] = _make_portrait("jwibul")
	PORTRAITS["bull_parade"] = _make_portrait("bull_parade")
	PORTRAITS["ganggang"] = _make_portrait("ganggang")
	PORTRAITS["lion"] = _make_portrait("lion")
	PORTRAITS["neolttwigi"] = _make_portrait("neolttwigi")
	PORTRAITS["swing"] = _make_portrait("swing")
	PORTRAITS["namsadang"] = _make_portrait("namsadang")
	PORTRAITS["jeongisu"] = _make_portrait("jeongisu")
	PORTRAITS["pungmul"] = _make_portrait("pungmul")
	PORTRAITS["talchum"] = _make_portrait("talchum")
	PORTRAITS["paengi"] = _make_portrait("paengi")
	PORTRAITS["taekkyeon"] = _make_portrait("taekkyeon")

	# 신규 직업군 전용 거점 건물 일러스트
	PORTRAITS["base_jungin"] = _make_portrait("base_jungin")
	PORTRAITS["base_ajeon"] = _make_portrait("base_ajeon")
	PORTRAITS["base_artisan"] = _make_portrait("base_artisan")
	PORTRAITS["base_butcher"] = _make_portrait("base_butcher")

## ============================================================ 2. 픽셀 일러스트 절차적 생성 엔진
static func _make_portrait(key: String) -> ImageTexture:
	# 새 도트 그림이 있는 키는 그것을 쓴다(PortraitArt), 없으면 아래 옛 그림
	var dot: ImageTexture = PortraitArt.make(key)
	if dot != null:
		return dot
	var sz: int = 96
	var img: Image = Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# 1. 둥근 크림색 전통 한지 바탕
	var cx: int = int(float(sz) / 2.0)
	var cy: int = int(float(sz) / 2.0)
	var rad: int = int(float(sz) / 2.0) - 4
	_fill_circle(img, cx, cy, rad, Color("fffdf5"))
	_draw_circle_border(img, cx, cy, rad, Color("7a5835"), 2)
	_draw_circle_border(img, cx, cy, rad - 3, Color("c9b28b"), 1)

	# 2. 키별 고유 실루엣/복식 렌더링
	match key:
		"jeongjo":
			_fill_rect(img, 24, 52, 48, 38, Color("9e1c1c")) # 붉은 곤룡포
			_fill_circle(img, cx, 66, 11, Color("d4af37"))   # 황금 원형 가슴 용보
			_fill_circle(img, cx, 66, 7, Color("b89628"))
			_fill_circle(img, cx, 40, 14, Color("f3cfad"))   # 용안 (얼굴)
			_fill_rect(img, cx - 11, 20, 22, 14, Color("141414")) # 익선관 몸체
			_fill_circle(img, cx - 13, 16, 6, Color("1a1a1a"))    # 익선관 날개 좌
			_fill_circle(img, cx + 13, 16, 6, Color("1a1a1a"))    # 익선관 날개 우
			_fill_rect(img, cx - 7, 43, 14, 3, Color("2a1a10"))   # 단정한 수염

		"jeong_yakyong":
			_fill_rect(img, 24, 52, 48, 38, Color("4a709c")) # 푸른 도포
			_fill_rect(img, cx - 12, 54, 24, 18, Color("f5edd6")) # 도면/책
			_fill_circle(img, cx, 38, 13, Color("f2cfad"))   # 얼굴
			_fill_rect(img, cx - 10, 18, 20, 12, Color("1a1a1a")) # 정자관
			_draw_circle_border(img, cx - 5, 37, 4, Color("8b5a2b"), 1)
			_draw_circle_border(img, cx + 5, 37, 4, Color("8b5a2b"), 1)
			_fill_rect(img, cx - 2, 37, 4, 1, Color("8b5a2b"))

		"chae_jegong":
			_fill_rect(img, 24, 50, 48, 40, Color("b22222")) # 붉은 조복
			_fill_circle(img, cx, 38, 13, Color("f0cdab"))   # 얼굴
			_fill_rect(img, cx - 9, 16, 18, 14, Color("d4af37")) # 금관조복 모자
			_fill_circle(img, cx, 44, 8, Color("fafafa"))    # 백발 수염
			_fill_rect(img, cx - 2, 54, 5, 22, Color("f0ece1")) # 홀(笏)

		"kim_hongdo":
			_fill_rect(img, 24, 52, 48, 38, Color("96724f")) # 갈색 두루마기
			_fill_circle(img, cx, 40, 13, Color("ecc29a"))
			_fill_circle(img, cx, 26, 15, Color("222222"))   # 화원 모자
			_draw_line(img, 56, 48, 72, 70, Color("4a3219"), 3) # 붓대
			_fill_circle(img, 74, 72, 4, Color("111111"))    # 붓끝 먹물

		"kim_pankwan":
			_fill_rect(img, 24, 52, 48, 38, Color("2f6b4f")) # 초록 단령
			_fill_rect(img, cx - 9, 56, 18, 14, Color("1d3b6e")) # 흉배
			_fill_circle(img, cx, 63, 3, Color("fafafa"))    # 백학 흉배
			_fill_circle(img, cx, 40, 13, Color("f2cfa6"))
			_fill_circle(img, cx, 24, 11, Color("141414"))   # 사모
			_fill_rect(img, cx - 22, 22, 12, 4, Color("141414"))
			_fill_rect(img, cx + 10, 22, 12, 4, Color("141414"))

		"kim_bau":
			_fill_rect(img, 24, 52, 48, 38, Color("c2b49d")) # 삼베 옷
			_fill_circle(img, cx, 38, 14, Color("dca578"))   # 구릿빛 얼굴
			_fill_rect(img, cx - 11, 21, 22, 6, Color("2a2a2a")) # 머리띠
			_draw_line(img, 22, 68, 42, 48, Color("5c4033"), 4) # 망치 자루
			_fill_rect(img, 18, 64, 12, 8, Color("4a4e51"))  # 쇠망치 머리

		"jo_simtae":
			_fill_rect(img, 24, 52, 48, 38, Color("224870")) # 철릭
			_fill_circle(img, cx, 40, 13, Color("eec59f"))
			_fill_circle(img, cx, 25, 16, Color("141414"))   # 전립 챙
			_fill_circle(img, cx + 2, 16, 5, Color("b22222")) # 붉은 상모

		"gu_seonbok":
			_fill_rect(img, 24, 50, 48, 40, Color("343a40")) # 쇠갑옷
			_fill_rect(img, cx - 14, 56, 28, 4, Color("d4af37")) # 금속 띠
			_fill_circle(img, cx, 40, 12, Color("e5ba95"))
			_fill_rect(img, cx - 10, 18, 20, 14, Color("495057")) # 투구
			_fill_circle(img, cx, 14, 4, Color("b22222"))    # 투구 깃털

		"baek_dongsoo":
			_fill_rect(img, 26, 52, 44, 38, Color("1f2421")) # 흑단 쾌자
			_fill_circle(img, cx, 38, 13, Color("ecc29a"))
			_fill_rect(img, cx - 12, 28, 24, 4, Color("b22222")) # 붉은 머리끈
			_draw_line(img, 22, 76, 74, 24, Color("7f8c8d"), 3) # 환도 칼날

		"construction":
			_fill_rect(img, 20, 62, 56, 18, Color("7f8c8d")) # 주춧돌
			_draw_line(img, 24, 20, 24, 75, Color("8b5a2b"), 3) # 비계 기둥 좌
			_draw_line(img, 72, 20, 72, 75, Color("8b5a2b"), 3) # 비계 기둥 우
			_draw_line(img, 18, 36, 78, 36, Color("a06d3b"), 2) # 가로 통나무
			_draw_line(img, 18, 52, 78, 52, Color("a06d3b"), 2)
			_fill_circle(img, cx, 28, 6, Color("4a4e51"))    # 거중기 도르래

		"house_thatched":
			_fill_circle(img, cx, 44, 28, Color("d4a359"))   # 볏짚 지붕
			_fill_rect(img, 28, 48, 40, 26, Color("bfa181")) # 흙벽
			_fill_rect(img, 42, 56, 12, 18, Color("5c3a21")) # 사립문
			_fill_circle(img, cx - 10, 32, 5, Color("e67e22")) # 지붕 위 박

		"house_tile":
			_fill_rect(img, 24, 50, 48, 26, Color("f4ede2")) # 흰 회벽
			_draw_line(img, 14, 46, 82, 46, Color("2c3e50"), 8) # 기와 처마
			_draw_line(img, 20, 38, 76, 38, Color("1a252f"), 10) # 기와 본체
			_fill_rect(img, 42, 54, 12, 22, Color("6e4225")) # 대청문

		"jongnu":
			# 십자로 종루: 2층 팔작 누각과 황동 대종
			_fill_rect(img, 28, 56, 40, 24, Color("8e2a2a")) # 단청 붉은 기둥
			_draw_line(img, 16, 52, 80, 52, Color("2c3e50"), 6) # 1층 처마
			_draw_line(img, 18, 34, 78, 34, Color("1a252f"), 8) # 2층 지붕
			_fill_circle(img, cx, 64, 8, Color("d4af37"))   # 황동 대종
			_fill_circle(img, cx, 64, 5, Color("b89628"))

		"seojangdae":
			# 서장대: 팔달산 바위 위 2층 누각과 장원 깃발
			_fill_rect(img, 22, 66, 52, 16, Color("7f8c8d")) # 팔달산 암반
			_fill_rect(img, 30, 46, 36, 22, Color("8e2a2a")) # 1층 누각
			_draw_line(img, 18, 42, 78, 42, Color("2c3e50"), 6)
			_draw_line(img, 22, 28, 74, 28, Color("1a252f"), 8)
			_draw_line(img, 72, 16, 72, 40, Color("f1c40f"), 3) # 황룡 깃발

		"banghwasuryujeong":
			# 방화수류정: 연못 용연과 십자형 지붕 누각
			_fill_circle(img, cx, 76, 18, Color("3498db"))   # 용연 연못
			_fill_rect(img, 30, 46, 36, 22, Color("795548")) # 누각 기둥
			_draw_line(img, 16, 40, 80, 40, Color("1a252f"), 8) # 정자 지붕
			_fill_circle(img, 70, 60, 8, Color("2ecc71"))    # 버드나무

		"hwahongmun", "namsumun", "hwahong_mun", "namsu_mun":
			# 홍예 수문: 7연 홍예와 수문 위 누각
			_fill_rect(img, 20, 56, 56, 24, Color("95a5a6")) # 석축
			_fill_circle(img, 32, 68, 7, Color("2980b9"))    # 홍예 1
			_fill_circle(img, cx, 68, 7, Color("2980b9"))    # 홍예 2
			_fill_circle(img, 64, 68, 7, Color("2980b9"))    # 홍예 3
			_draw_line(img, 18, 48, 78, 48, Color("2c3e50"), 8) # 누각 지붕

		"maehwang_gyo", "maehyang_gyo":
			# 매향교: 화강암 석교와 홍예/분수석축, 천변 버드나무와 매화
			_fill_rect(img, 12, 58, 72, 14, Color("d8d2c4")) # 화강암 상판
			_draw_line(img, 10, 56, 86, 56, Color("6a665e"), 3) # 돌난간 두겁석
			_fill_circle(img, 30, 72, 8, Color("2980b9"))    # 석교 홍예 아치 1
			_fill_circle(img, 66, 72, 8, Color("2980b9"))    # 석교 홍예 아치 2
			_fill_rect(img, 42, 66, 12, 16, Color("8a8478")) # 중앙 장대석 교각
			_fill_circle(img, 18, 48, 7, Color("e91e63"))    # 매화꽃 봉오리
			_fill_circle(img, 78, 48, 8, Color("2ecc71"))    # 능수버들

		"gongsimdon":
			# 공심돈: 원통형 벽돌 돈대와 총안
			_fill_rect(img, 28, 36, 40, 44, Color("5d6d7e")) # 전축 벽돌 탑
			_draw_line(img, 24, 34, 72, 34, Color("2c3e50"), 6)
			_fill_rect(img, 34, 46, 6, 6, Color("17202a"))   # 총안 좌
			_fill_rect(img, 56, 46, 6, 6, Color("17202a"))   # 총안 우
			_fill_rect(img, 45, 60, 6, 6, Color("17202a"))   # 총안 중앙

		"bongdon":
			# 봉돈: 5개 벽돌 굴뚝 화두와 피어오르는 연기
			_fill_rect(img, 20, 58, 56, 22, Color("7f8c8d")) # 석축 받침
			for bi in range(5):
				var bx: int = 24 + bi * 10
				_fill_rect(img, bx, 44, 7, 16, Color("5d6d7e")) # 굴뚝
			_fill_circle(img, cx, 30, 8, Color("ecf0f1"))    # 백색 연기

		"poru":
			# 포루: 성벽 돌출 3층 누각과 화포 포구
			_fill_rect(img, 26, 44, 44, 38, Color("4a4e51")) # 검은 벽돌 돈대
			_draw_line(img, 20, 40, 76, 40, Color("1a252f"), 8)
			_fill_circle(img, cx, 58, 6, Color("111111"))    # 포구
			_draw_line(img, cx - 2, 58, cx + 8, 58, Color("d35400"), 3) # 화포 총열

		"yeonmudae":
			# 연무대: 넓은 연병장과 과녁
			_fill_rect(img, 20, 52, 56, 28, Color("ecf0f1"))
			_draw_line(img, 18, 46, 78, 46, Color("2c3e50"), 8)
			_fill_circle(img, 70, 66, 8, Color("c0392b"))    # 과녁 홍심
			_fill_circle(img, 70, 66, 4, Color("f1c40f"))

		"embankment":
			# 수원천 석축제방: 촘촘한 화강암 축대와 물결
			_fill_rect(img, 18, 46, 60, 36, Color("95a5a6")) # 석축 둑
			_fill_rect(img, 18, 66, 60, 16, Color("2980b9")) # 흐르는 물
			_draw_line(img, 18, 46, 78, 46, Color("7f8c8d"), 4) # 둑길

		"road":
			# 주간선 박석길: 반듯한 석판 도로
			_fill_rect(img, 24, 20, 48, 60, Color("bdc3c7"))
			_draw_line(img, 36, 20, 36, 80, Color("95a5a6"), 2)
			_draw_line(img, 60, 20, 60, 80, Color("95a5a6"), 2)
			_draw_line(img, 24, 40, 72, 40, Color("95a5a6"), 2)
			_draw_line(img, 24, 60, 72, 60, Color("95a5a6"), 2)

		"cattle":
			# 수원 우시장: 늠름한 황소와 마구간
			_fill_rect(img, 26, 46, 44, 30, Color("b9770e")) # 황소 몸통
			_fill_circle(img, 34, 42, 12, Color("b9770e"))   # 황소 머리
			_draw_line(img, 28, 34, 24, 26, Color("2c3e50"), 3) # 뿔 좌
			_draw_line(img, 38, 34, 42, 26, Color("2c3e50"), 3) # 뿔 우
			_fill_circle(img, 30, 42, 2, Color("111111"))

		"play":
			# 마당놀이: 상모와 풍물 장구
			_fill_circle(img, cx, 44, 14, Color("f2cfad"))   # 광대
			_fill_circle(img, cx, 30, 8, Color("111111"))    # 벙거지
			_draw_line(img, cx, 24, cx + 18, 16, Color("fafafa"), 3) # 상모 백선
			_fill_rect(img, 34, 60, 28, 16, Color("b03a2e")) # 장구

		"kids":
			# 골목 놀이터: 제기와 팽이
			_fill_circle(img, 36, 42, 10, Color("ecc29a"))   # 아이
			_fill_rect(img, 30, 52, 14, 22, Color("3498db")) # 색동옷
			_fill_circle(img, 64, 66, 8, Color("e67e22"))    # 팽이
			_fill_rect(img, 56, 42, 10, 10, Color("f1c40f")) # 제기 털

		"seodang":
			# 훈장님 서당: 서책과 훈장님 갓, 회초리
			_fill_rect(img, 26, 52, 44, 32, Color("ecf0f1")) # 도포
			_fill_circle(img, cx, 38, 12, Color("f2cfad"))
			_fill_rect(img, cx - 10, 18, 20, 12, Color("141414")) # 갓
			_fill_rect(img, 34, 64, 20, 12, Color("34495e")) # 서책
			_draw_line(img, 62, 54, 76, 40, Color("5c4033"), 2) # 회초리

		"shop_silk":
			# 포목전: 비단 필
			_fill_rect(img, 24, 40, 48, 38, Color("dfb15b"))
			_fill_rect(img, 28, 48, 40, 8, Color("9b59b6"))  # 보라 비단
			_fill_rect(img, 28, 58, 40, 8, Color("e74c3c"))  # 홍색 비단
			_fill_rect(img, 28, 68, 40, 8, Color("3498db"))  # 청색 비단

		"shop_fish":
			# 어물전: 조기와 생선
			_fill_rect(img, 24, 46, 48, 34, Color("bfa181"))
			_draw_line(img, 28, 56, 68, 56, Color("5d4037"), 2) # 엮은 새끼줄
			_fill_circle(img, 36, 64, 6, Color("bdc3c7"))    # 물고기 1
			_fill_circle(img, 50, 64, 6, Color("bdc3c7"))    # 물고기 2
			_fill_circle(img, 64, 64, 6, Color("bdc3c7"))    # 물고기 3

		"shop_rice":
			# 싸전: 쌀가마니와 됫박
			_fill_circle(img, 38, 62, 12, Color("d4a359"))   # 볏짚 가마니
			_fill_circle(img, 58, 62, 12, Color("d4a359"))
			_fill_rect(img, 42, 46, 14, 12, Color("8b5a2b")) # 됫박
			_fill_rect(img, 44, 48, 10, 4, Color("fafafa"))  # 하얀 쌀

		"shop_smith":
			# 대장간: 화로와 쇠모루
			_fill_rect(img, 26, 52, 44, 30, Color("34495e"))
			_fill_circle(img, 40, 60, 10, Color("e74c3c"))   # 이글거리는 불
			_fill_circle(img, 40, 60, 5, Color("f39c12"))
			_fill_rect(img, 54, 58, 16, 12, Color("2c3e50")) # 쇠모루

		"shop_jumak":
			# 주막: 탁주와 국밥
			_fill_rect(img, 24, 46, 48, 34, Color("bfa181")) # 평상
			_fill_circle(img, 40, 58, 8, Color("ecf0f1"))    # 막걸리 사발
			_fill_circle(img, 56, 58, 9, Color("7f8c8d"))    # 뚝배기 국밥

		"seokjeon", "ssireum", "kite", "firefighting", "hunting", "playing", "washing", "fishing", "cheering", "training":
			# NPC FSM 고유 행동 실루엣
			_fill_rect(img, 28, 52, 40, 38, Color("2980b9"))
			_fill_circle(img, cx, 40, 13, Color("ecc29a"))
			_fill_circle(img, cx, 25, 14, Color("1c2833"))
			match key:
				"ssireum":
					_fill_rect(img, 32, 60, 32, 8, Color("c0392b")) # 샅바
				"kite":
					_fill_rect(img, 62, 24, 14, 18, Color("f1c40f")) # 연
				"firefighting":
					_fill_rect(img, 54, 56, 16, 16, Color("3498db")) # 물통
				"hunting":
					_draw_line(img, 24, 76, 72, 36, Color("2c3e50"), 3) # 총열
				"washing":
					_fill_rect(img, 34, 64, 28, 14, Color("ecf0f1")) # 빨랫감
				"fishing":
					_draw_line(img, 26, 76, 68, 22, Color("5d4037"), 2) # 낚싯대
				"cheering":
					_fill_circle(img, cx - 12, 34, 4, Color("ecc29a")) # 번쩍 든 손
					_fill_circle(img, cx + 12, 34, 4, Color("ecc29a"))
				_:
					_fill_rect(img, 54, 58, 12, 12, Color("7f8c8d"))

		"jwibul":
			# 정월 대보름 쥐불놀이: 밤하늘 속 불꽃 원
			_fill_circle(img, cx, 46, 26, Color("1a2530")) # 밤하늘
			_draw_circle_border(img, cx, 46, 20, Color("f39c12"), 3) # 불꽃 궤적
			_draw_circle_border(img, cx, 46, 14, Color("e74c3c"), 2)
			_fill_circle(img, cx + 14, 46, 5, Color("f1c40f")) # 쥐불 깡통
			_fill_circle(img, cx - 14, 46, 3, Color("e67e22"))

		"bull_parade":
			# 단오 천하장사 행진: 황소 등 위의 장사
			_fill_rect(img, 24, 48, 48, 30, Color("b9770e")) # 황소
			_fill_circle(img, cx, 36, 12, Color("e6bf98"))   # 장사 머리
			_fill_rect(img, 36, 44, 24, 8, Color("c0392b"))  # 붉은 샅바
			_fill_circle(img, cx - 12, 30, 4, Color("e6bf98")) # 만세 팔
			_fill_circle(img, cx + 12, 30, 4, Color("e6bf98"))

		"ganggang":
			# 한가위 강강술래: 보름달과 손잡은 아낙들
			_fill_circle(img, cx, 28, 16, Color("f1c40f")) # 보름달
			_fill_rect(img, 20, 50, 18, 32, Color("e88aa8")) # 분홍 치마
			_fill_rect(img, 58, 50, 18, 32, Color("2e8b57")) # 초록 치마
			_fill_circle(img, 29, 44, 8, Color("ecc29a"))
			_fill_circle(img, 67, 44, 8, Color("ecc29a"))
			_draw_line(img, 37, 48, 59, 48, Color("f4f0e4"), 3) # 맞잡은 손

		"lion":
			# 북청 사자춤: 황금빛 털과 붉은 사자 탈
			_fill_circle(img, cx, 42, 22, Color("d35400")) # 사자 머리
			_fill_circle(img, cx, 42, 16, Color("c0392b")) # 붉은 얼굴
			_fill_circle(img, cx - 8, 38, 4, Color("f1c40f")) # 번뜩이는 눈
			_fill_circle(img, cx + 8, 38, 4, Color("f1c40f"))
			_fill_rect(img, cx - 10, 48, 20, 8, Color("ffffff")) # 이빨

		"neolttwigi":
			# 설날·단오 널뛰기: 짚단과 솟구치는 오색 치마
			_fill_circle(img, cx, 74, 10, Color("d4a359")) # 짚단
			_draw_line(img, 18, 70, 78, 56, Color("8b5a2b"), 4) # 널빤지
			_fill_rect(img, 60, 26, 18, 28, Color("3498db")) # 솟구친 치마
			_fill_circle(img, 69, 20, 8, Color("ecc29a"))

		"swing":
			# 단오 그네: 높은 나무 기둥과 치솟는 붉은 치마
			_draw_line(img, 26, 14, 26, 82, Color("5c3a21"), 3) # 기둥 좌
			_draw_line(img, 70, 14, 70, 82, Color("5c3a21"), 3) # 기둥 우
			_draw_line(img, 22, 18, 74, 18, Color("5c3a21"), 3) # 가로대
			_draw_line(img, 34, 18, 46, 56, Color("d8c49a"), 2) # 그네 줄
			_draw_line(img, 62, 18, 54, 56, Color("d8c49a"), 2)
			_fill_rect(img, 42, 52, 16, 26, Color("c0392b")) # 붉은 치마
			_fill_circle(img, 50, 46, 8, Color("ecc29a"))

		"namsadang":
			# 유랑 남사당패: 외줄 타기와 붉은 부채
			_draw_line(img, 10, 66, 86, 66, Color("d8c49a"), 3) # 외줄
			_fill_rect(img, cx - 8, 36, 16, 28, Color("fafafa")) # 흰옷 광대
			_fill_circle(img, cx, 30, 9, Color("ecc29a"))
			_fill_circle(img, cx + 16, 28, 9, Color("e74c3c")) # 붉은 부채

		"jeongisu":
			# 저잣거리 전기수: 돗자리 위 고소설 서책과 이야기꾼
			_fill_rect(img, 18, 68, 60, 16, Color("c8b27a")) # 돗자리
			_fill_rect(img, 32, 42, 32, 28, Color("2980b9")) # 푸른 도포
			_fill_circle(img, cx, 34, 10, Color("ecc29a"))
			_fill_rect(img, cx - 9, 18, 18, 12, Color("17202a")) # 갓
			_fill_rect(img, 28, 56, 14, 10, Color("2e4a7a")) # 펼친 고소설 책
			_fill_rect(img, 42, 56, 14, 10, Color("fdfefe"))

		"pungmul":
			# 풍물패: 상모 백선과 꽹과리/장구
			_fill_rect(img, 32, 46, 32, 32, Color("fafafa")) # 흰 옷
			_fill_circle(img, cx, 36, 10, Color("ecc29a"))
			_fill_circle(img, cx, 24, 7, Color("111111"))   # 상모 벙거지
			_draw_line(img, cx, 18, cx + 22, 12, Color("fafafa"), 3) # 백선
			_fill_circle(img, cx + 14, 52, 8, Color("f1c40f")) # 꽹과리

		"talchum":
			# 탈춤 마당: 흰 얼굴 붉은 볼 탈과 너울거리는 한삼 소매
			_fill_circle(img, cx, 36, 14, Color("ffffff")) # 하얀 탈
			_fill_circle(img, cx - 5, 38, 3, Color("e74c3c")) # 연지
			_fill_circle(img, cx + 5, 38, 3, Color("e74c3c"))
			_fill_rect(img, 30, 52, 36, 30, Color("e67e22")) # 주황 저고리
			_draw_line(img, 24, 56, 12, 44, Color("ffffff"), 4) # 한삼 좌
			_draw_line(img, 72, 56, 84, 44, Color("ffffff"), 4) # 한삼 우

		"paengi":
			# 얼음판 팽이치기: 얼음판과 나무 팽이
			_fill_rect(img, 16, 56, 64, 26, Color("d4e6f1")) # 얼음판
			_fill_circle(img, cx, 58, 12, Color("8b5a2b"))  # 팽이 윗면
			_draw_line(img, cx, 58, cx, 70, Color("5c3a21"), 3) # 팽이 축
			_draw_line(img, 68, 34, 54, 60, Color("a04000"), 2) # 채찍 줄

		"taekkyeon":
			# 택견: 날렵하게 솟구친 발차기
			_fill_rect(img, 28, 48, 28, 30, Color("fafafa")) # 흰 무명 옷
			_fill_circle(img, 42, 36, 10, Color("ecc29a"))
			_fill_rect(img, 32, 56, 24, 6, Color("2980b9"))  # 푸른 띠
			_draw_line(img, 52, 60, 78, 32, Color("fafafa"), 5) # 날렵한 발차기

		"merchant":
			_fill_rect(img, 28, 52, 40, 38, Color("c8d6af"))
			_fill_circle(img, cx, 40, 13, Color("ecc29a"))
			_fill_circle(img, cx, 26, 16, Color("bfa181"))   # 패랭이
			_fill_rect(img, 60, 44, 16, 28, Color("9b59b6")) # 비단 봇짐

		"patrol_soldier":
			_fill_rect(img, 28, 52, 40, 38, Color("2980b9"))
			_fill_circle(img, cx, 40, 13, Color("ecc29a"))
			_fill_circle(img, cx, 25, 15, Color("1c2833"))   # 벙거지
			_draw_line(img, 68, 20, 68, 80, Color("5d4037"), 3)
			_fill_rect(img, 66, 14, 5, 8, Color("bdc3c7"))

		"farmer":
			_fill_rect(img, 28, 52, 40, 38, Color("ded7c8"))
			_fill_circle(img, cx, 40, 13, Color("e0a97d"))
			_fill_circle(img, cx, 24, 18, Color("bfa181"))   # 삿갓
			_draw_line(img, 24, 76, 72, 38, Color("5d4037"), 3)

		"scholar":
			_fill_rect(img, 28, 52, 40, 38, Color("7fb3d5"))
			_fill_circle(img, cx, 40, 13, Color("f2cfad"))
			_fill_rect(img, cx - 9, 20, 18, 14, Color("17202a")) # 유건
			_fill_rect(img, 32, 60, 16, 12, Color("fdfefe")) # 서책

		"artisan":
			_fill_rect(img, 28, 52, 40, 38, Color("8d6e63"))
			_fill_circle(img, cx, 40, 13, Color("d7a17a"))
			_fill_rect(img, cx - 11, 23, 22, 5, Color("3e2723"))
			_fill_rect(img, 56, 56, 16, 10, Color("5d4037"))

		"commoner":
			_fill_rect(img, 28, 52, 40, 38, Color("f5f5f0"))
			_fill_circle(img, cx, 40, 13, Color("ecc29a"))
			_fill_circle(img, cx, 24, 6, Color("2c3e50"))

		"tiger":
			_fill_circle(img, cx, cy, 26, Color("e67e22"))
			_fill_circle(img, cx - 20, cy - 18, 7, Color("d35400"))
			_fill_circle(img, cx + 20, cy - 18, 7, Color("d35400"))
			_fill_circle(img, cx - 9, cy - 2, 4, Color("f1c40f"))
			_fill_circle(img, cx + 9, cy - 2, 4, Color("f1c40f"))
			_draw_line(img, cx - 6, cy - 14, cx + 6, cy - 14, Color("111111"), 2)
			_draw_line(img, cx, cy - 18, cx, cy - 10, Color("111111"), 2)
			_fill_circle(img, cx, cy + 10, 6, Color("ffffff"))

		"deer":
			_fill_circle(img, cx, cy + 4, 18, Color("ba7a44"))
			_fill_circle(img, cx - 6, cy + 2, 3, Color("17202a"))
			_fill_circle(img, cx + 6, cy + 2, 3, Color("17202a"))
			_draw_line(img, cx - 8, cy - 8, cx - 18, cy - 26, Color("6e4726"), 3)
			_draw_line(img, cx + 8, cy - 8, cx + 18, cy - 26, Color("6e4726"), 3)

		"wild_boar":
			_fill_circle(img, cx, cy, 24, Color("4a3728"))
			_fill_circle(img, cx, cy + 6, 12, Color("6b4f3b"))
			_fill_circle(img, cx - 8, cy - 2, 3, Color("17202a"))
			_fill_circle(img, cx + 8, cy - 2, 3, Color("17202a"))
			_draw_line(img, cx - 9, cy + 12, cx - 13, cy + 4, Color("fafafa"), 2)
			_draw_line(img, cx + 9, cy + 12, cx + 13, cy + 4, Color("fafafa"), 2)

		"crane":
			_fill_circle(img, cx, cy + 2, 18, Color("fdfefe"))
			_fill_circle(img, cx, cy - 14, 5, Color("c0392b"))
			_fill_circle(img, cx - 5, cy - 6, 2, Color("17202a"))
			_fill_circle(img, cx + 5, cy - 6, 2, Color("17202a"))
			_draw_line(img, cx, cy, cx, cy + 22, Color("d4ac0d"), 3)

		"rabbit":
			_fill_circle(img, cx, cy + 8, 16, Color("fdfefe"))
			_fill_rect(img, cx - 8, cy - 20, 6, 22, Color("fdfefe"))
			_fill_rect(img, cx + 2, cy - 20, 6, 22, Color("fdfefe"))
			_fill_circle(img, cx - 5, cy + 6, 2, Color("c0392b"))
			_fill_circle(img, cx + 5, cy + 6, 2, Color("c0392b"))

		"wolf":
			_fill_circle(img, cx, cy, 22, Color("7f8c8d"))
			_fill_rect(img, cx - 14, cy - 18, 6, 12, Color("566573"))
			_fill_rect(img, cx + 8, cy - 18, 6, 12, Color("566573"))
			_fill_circle(img, cx - 7, cy - 2, 3, Color("f39c12"))

		"haenggung", "gate", "wall", "fort", "market", "facility", "seowon":
			_fill_rect(img, 20, 52, 56, 28, Color("ecf0f1"))
			_draw_line(img, 10, 48, 86, 48, Color("2c3e50"), 8)
			_draw_line(img, 18, 38, 78, 38, Color("1a252f"), 10)
			_fill_rect(img, 38, 56, 20, 24, Color("c0392b"))
			_fill_circle(img, cx, 30, 4, Color("d4af37"))

		"jungin":
			_fill_rect(img, 28, 52, 40, 38, Color("7aa5b8"))
			_fill_circle(img, cx, 40, 13, Color("f2cfad"))
			_fill_circle(img, cx, 24, 15, Color("1a1a1a"))
			_fill_rect(img, cx - 8, 14, 16, 12, Color("1a1a1a"))
			_fill_rect(img, 54, 56, 16, 14, Color("5c3a21"))
			_draw_line(img, 54, 62, 70, 62, Color("d4af37"), 1)
			_draw_line(img, 32, 62, 40, 72, Color("c2a649"), 2)

		"ajeon":
			_fill_rect(img, 28, 52, 40, 38, Color("8e2a3a"))
			_fill_circle(img, cx, 40, 13, Color("ecc29a"))
			_fill_circle(img, cx, 25, 14, Color("222222"))
			_fill_rect(img, 36, 56, 24, 16, Color("f4eedb"))
			_draw_line(img, 40, 61, 56, 61, Color("222222"), 1)
			_draw_line(img, 40, 66, 56, 66, Color("222222"), 1)

		"bobusang":
			_fill_rect(img, 28, 52, 40, 38, Color("d8ccb0"))
			_fill_circle(img, cx, 40, 13, Color("dca578"))
			_fill_circle(img, cx, 25, 15, Color("8a6a3a"))
			_fill_circle(img, cx - 11, 23, 4, Color("ffffff"))
			_fill_circle(img, cx + 11, 23, 4, Color("ffffff"))
			_fill_rect(img, 14, 48, 16, 26, Color("b08a3a"))
			_draw_circle_border(img, 22, 61, 8, Color("6a4a20"), 1)

		"monk_soldier":
			_fill_rect(img, 28, 52, 40, 38, Color("8a8c8e"))
			_draw_line(img, 34, 52, 62, 85, Color("b83b32"), 4)
			_fill_circle(img, cx, 40, 13, Color("eec59f"))
			_draw_line(img, 20, 26, 76, 26, Color("a68252"), 3)
			_draw_line(img, 24, 26, cx, 14, Color("a68252"), 3)
			_draw_line(img, 72, 26, cx, 14, Color("a68252"), 3)
			_draw_line(img, 68, 30, 68, 86, Color("4a3525"), 2)
			_fill_circle(img, 68, 28, 4, Color("d4af37"))

		"butcher":
			_fill_rect(img, 28, 52, 40, 38, Color("5c4a3a"))
			_fill_rect(img, 34, 58, 28, 28, Color("3a281c"))
			_fill_circle(img, cx, 40, 13, Color("d7a17a"))
			_fill_rect(img, cx - 11, 24, 22, 5, Color("9e3d32"))
			_fill_rect(img, 56, 54, 16, 20, Color("8a523a"))
			_draw_line(img, 32, 68, 42, 60, Color("cccccc"), 3)

		"base_jungin":
			_draw_line(img, 16, 36, 80, 36, Color("2c3e50"), 8)
			_draw_line(img, 24, 32, 72, 32, Color("1a252f"), 4)
			_fill_rect(img, 24, 42, 48, 38, Color("dfb15b"))
			_fill_rect(img, 32, 52, 14, 18, Color("4a7c59"))
			_fill_rect(img, 52, 56, 16, 14, Color("795548"))
			_fill_circle(img, 60, 50, 4, Color("fdfefe"))

		"base_ajeon":
			_draw_line(img, 14, 34, 82, 34, Color("34495e"), 8)
			_fill_rect(img, 22, 40, 52, 42, Color("ecf0f1"))
			_fill_rect(img, 32, 46, 32, 22, Color("5d4037"))
			_fill_rect(img, 38, 52, 20, 10, Color("fffdf5"))
			_fill_rect(img, 40, 68, 26, 12, Color("2c1a0e"))

		"base_artisan":
			_draw_line(img, 16, 36, 80, 36, Color("a08050"), 8)
			_fill_rect(img, 24, 42, 48, 40, Color("8d6e63"))
			_fill_rect(img, 28, 54, 20, 16, Color("bdc3c7"))
			_fill_rect(img, 52, 58, 16, 12, Color("2c3e50"))
			_fill_circle(img, 64, 52, 4, Color("c0392b"))

		"base_butcher":
			_fill_circle(img, cx, 34, 24, Color("d4ac0d"))
			_fill_rect(img, 24, 44, 48, 38, Color("876445"))
			_draw_line(img, 20, 52, 76, 52, Color("5d4037"), 2)
			_fill_rect(img, 30, 54, 16, 20, Color("8a3324"))
			_fill_rect(img, 50, 54, 16, 20, Color("a93226"))

		_:
			_fill_rect(img, 28, 52, 40, 38, Color("f5f5f0"))
			_fill_circle(img, cx, 40, 13, Color("ecc29a"))

	return ImageTexture.create_from_image(img)

static func _fill_circle(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	var sz: int = img.get_width()
	for y: int in range(maxi(0, cy - r), mini(sz, cy + r + 1)):
		for x: int in range(maxi(0, cx - r), mini(sz, cx + r + 1)):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
				img.set_pixel(x, y, col)

static func _draw_circle_border(img: Image, cx: int, cy: int, r: int, col: Color, w: int = 1) -> void:
	var sz: int = img.get_width()
	var r_in: int = r - w
	for y: int in range(maxi(0, cy - r), mini(sz, cy + r + 1)):
		for x: int in range(maxi(0, cx - r), mini(sz, cx + r + 1)):
			var d2: int = (x - cx) * (x - cx) + (y - cy) * (y - cy)
			if d2 <= r * r and d2 >= r_in * r_in:
				img.set_pixel(x, y, col)

static func _fill_rect(img: Image, x0: int, y0: int, w: int, h: int, col: Color) -> void:
	var sz: int = img.get_width()
	for y: int in range(maxi(0, y0), mini(sz, y0 + h)):
		for x: int in range(maxi(0, x0), mini(sz, x0 + w)):
			img.set_pixel(x, y, col)

static func _draw_line(img: Image, x0: int, y0: int, x1: int, y1: int, col: Color, width: int = 1) -> void:
	var dx: float = float(x1 - x0)
	var dy: float = float(y1 - y0)
	var steps: int = maxi(1, int(maxf(absf(dx), absf(dy))))
	var hw: int = int(float(width) / 2.0)
	for i: int in range(steps + 1):
		var px: int = int(roundf(float(x0) + dx * (float(i) / float(steps))))
		var py: int = int(roundf(float(y0) + dy * (float(i) / float(steps))))
		_fill_rect(img, px - hw, py - hw, width, width, col)

## ============================================================ 2.5 걸어 다니는 백성의 "실제 모습" 기준 프로필
## 팝업은 그려진 모습(NpcSprites 종류: 성별·신분·옷)과 같은 사람을 보여 준다. 에이전트 id로 이름·옷 색 변형이 고정된다.
## female: 여성 / name: given(이름만)·honor(성+존칭)·mrs(성씨 마님)·kid(아이 이름)
const NPC_PROFILES := {
	"yangban": {"role": "양반", "portrait": "yangban_m", "female": false, "name": "honor", "honor": ["생원", "진사", "영감"],
		"descs": ["고운 도포 자락을 여미고 갓끈을 매만지며\n체면을 차린 걸음으로 느긋이 거닙니다.", "비단 도포에 갓을 반듯이 쓰고\n장터의 물정을 둘러보며 거닙니다."]},
	"seonbi": {"role": "선비", "portrait": "scholar", "female": false, "name": "honor", "honor": ["수재", "도령"],
		"descs": ["서책을 옆에 끼고 사색에 잠겨\n성리학의 구절을 읊조리며 걷습니다.", "정갈한 도포 차림으로 글을 구상하며\n향교로 향하는 길을 오갑니다."]},
	"hallyang": {"role": "한량", "portrait": "hallyang", "female": false, "name": "honor", "honor": ["서방", "도령"],
		"descs": ["화려한 빛깔 도포에 부채를 살랑이며\n장터와 기방을 기웃거리는 풍류객입니다."]},
	"lady": {"role": "양반댁 부인", "portrait": "lady", "female": true, "name": "mrs",
		"descs": ["장옷으로 얼굴을 살짝 가리고 나들이를 나와\n조심스런 걸음으로 장터를 둘러봅니다.", "비단 저고리에 장옷을 두르고\n몸가짐을 곱게 하며 길을 걷습니다."]},
	# PORT-TRACE [거리 사람들의 정체성]: 취객·노인
	"drunkard": {"role": "취객", "portrait": "commoner", "female": false, "name": "given",
		"descs": ["주막에서 막걸리를 거나하게 걸치고
얼굴이 불콰해진 채 갈지자로 걷습니다.", "외상 술값 걱정은 내일로 미루고
흥얼흥얼 노랫가락을 뽑아 댑니다."]},
	"grandpa": {"role": "할아버지", "portrait": "commoner", "female": false, "name": "given",
		"descs": ["허리는 굽었어도 눈빛은 형형한 노인이
손주에게 옛이야기를 들려줍니다.", "곰방대를 허리춤에 차고
손주 손을 잡고 천천히 걷습니다."]},
	"grandma": {"role": "할머니", "portrait": "commoner_w", "female": true, "name": "given",
		"descs": ["쪽 찐 흰머리에 무명 치마를 입은 할머니가
손주를 살뜰히 챙기며 걷습니다.", "주름진 손으로 손주 옷고름을 여며 주며
장 구경을 나섰습니다."]},
	"commoner_m": {"role": "평민 사내", "portrait": "commoner", "female": false, "name": "given",
		"descs": ["무명 저고리 차림으로 짐을 챙겨\n장 볼 거리를 헤아리며 길을 갑니다.", "상투에 망건을 쓰고 부지런히 걸으며\n오늘 벌이를 궁리합니다."]},
	"commoner_w": {"role": "평민 아낙", "portrait": "commoner_w", "female": true, "name": "given",
		"descs": ["머릿수건을 두르고 광주리를 끼고\n찬거리를 사러 장터로 발길을 옮깁니다.", "무명 저고리에 치마를 걷어 올리고\n집안 살림에 쓸 물건을 둘러봅니다."]},
	"merchant": {"role": "상인", "portrait": "merchant", "female": false, "name": "given",
		"descs": ["패랭이를 쓰고 봇짐을 둘러메고\n장터 손님들과 흥정을 벌이러 갑니다."]},
	"porter": {"role": "짐꾼", "portrait": "porter", "female": false, "name": "given",
		"descs": ["지게 가득 짐을 지고 땀을 흘리며\n저잣거리와 성문 사이를 오갑니다."]},
	"cheonmin": {"role": "천민", "portrait": "cheonmin", "female": false, "name": "given",
		"descs": ["해진 옷에 맨발로 허드렛일을 찾아\n고단한 걸음을 옮기는 천민입니다."]},
	"jumo": {"role": "주모", "portrait": "jumo", "female": true, "name": "given",
		"descs": ["앞치마를 두르고 쪽을 찐 주막 안주인이\n술과 국밥 재료를 장만하러 나왔습니다."]},
	"gisaeng": {"role": "기생", "portrait": "gisaeng", "female": true, "name": "given",
		"descs": ["곱게 틀어 올린 머리에 비단 한복을 입고\n가야금 연주 자리로 향합니다."]},
	"child_m": {"role": "사내아이", "portrait": "child_m", "female": false, "name": "kid",
		"descs": ["상투도 없는 짧은 머리로 동무를 찾아\n신나게 뛰어다니는 개구쟁이입니다."]},
	"child_f": {"role": "계집아이", "portrait": "child_f", "female": true, "name": "kid",
		"descs": ["붉은 댕기를 나풀거리며 동무들과\n골목을 종종걸음으로 오가는 아이입니다."]},
	"soldier": {"role": "장용영 군졸", "portrait": "patrol_soldier", "female": false, "name": "given",
		"descs": ["전립을 쓰고 창을 곧게 쥐고서\n성안 곳곳을 살피며 순찰합니다."]},
	"official": {"role": "관원", "portrait": "official_m", "female": false, "name": "honor", "honor": ["나리", "서리"],
		"descs": ["푸른 단령에 사모를 쓰고 공문을 들고\n관아와 성곽을 오가며 일을 봅니다."]},
	"washer": {"role": "빨래하는 아낙", "portrait": "commoner_w", "female": true, "name": "given",
		"descs": ["빨랫감을 이고 수원천으로 나와\n방망이질로 묵은 때를 두드립니다."]},
	"fisher": {"role": "낚시꾼", "portrait": "fishing", "female": false, "name": "given",
		"descs": ["삿갓을 쓰고 낚싯대를 메고\n물가에서 한가롭게 세월을 낚습니다."]},
	"mason": {"role": "석공", "portrait": "artisan", "female": false, "name": "given",
		"descs": ["정과 망치를 들고 성돌을 다듬으며\n쌓을 자리를 가늠합니다."]},
	"foreman": {"role": "도편수", "portrait": "scholar", "female": false, "name": "given",
		"descs": ["공사 현장을 두루 살피며 일꾼들에게\n쌓는 순서와 방법을 일러 줍니다."]},
}

## 이 에이전트가 화면에서 실제로 어떤 모습(스프라이트 종류)으로 그려지는가
static func npc_sprite_kind(entity: Dictionary) -> String:
	var atype := str(entity.get("type", ""))
	var k := NpcSprites.kind_for(atype, int(entity.get("id", 0)))
	if k != "":
		return k
	return atype if NPC_PROFILES.has(atype) else ""

## 성별·신분에 맞는 이름(에이전트 id로 고정)
static func npc_name(profile: Dictionary, id: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("npc_name_%d" % id)
	var fams: Array[String] = ["김", "이", "박", "최", "정", "강", "조", "윤", "장", "임", "한", "오", "신"]
	var male: Array[String] = ["돌쇠", "개똥이", "만복이", "삼돌이", "바우", "칠성이", "덕만이", "갑돌이", "막손이", "차돌이", "길손이", "봉구", "달수", "춘식이"]
	var female: Array[String] = ["분이", "순덕이", "복순이", "옥이", "말순이", "점순이", "끝순이", "봉선이", "영춘이", "막내", "연이", "귀덕이"]
	var kid_m: Array[String] = ["똘이", "막내", "꺽정이", "동이", "바둑이", "쇠돌이"]
	var kid_f: Array[String] = ["꽃분이", "봉이", "순이", "달래", "복실이", "곱단이"]
	var fam: String = fams[rng.randi() % fams.size()]
	var is_f: bool = bool(profile.get("female", false))
	match str(profile.get("name", "given")):
		"honor":
			var hs: Array = profile.get("honor", ["생원"])
			var hv: String = str(hs[rng.randi() % hs.size()])
			return "%s %s" % [fam, hv]
		"mrs":
			return "%s씨" % fam
		"kid":
			return kid_f[rng.randi() % kid_f.size()] if is_f else kid_m[rng.randi() % kid_m.size()]
	return fam + (female[rng.randi() % female.size()] if is_f else male[rng.randi() % male.size()])

## 프로필로 팝업 내용을 채운다
static func apply_npc_profile(out: Dictionary, prof: Dictionary, entity: Dictionary) -> void:
	var id := int(entity.get("id", 0))
	var variant := floori(float(absi(id)) / float(NpcSprites.CROWD.size())) % 4
	var key := str(prof["portrait"])
	if PortraitPeople.has(key):
		key = "%s#%d" % [key, variant]
	var nm := npc_name(prof, id)
	var _gender := "여성" if bool(prof.get("female", false)) else "남성"
	if str(prof.get("name", "")) == "kid":
		_gender = "여자아이" if bool(prof.get("female", false)) else "남자아이"
	out["category"] = "npc"
	out["title"] = "%s %s" % [str(prof["role"]), nm]
	out["texture"] = get_portrait(key)
	var ds: Array = prof["descs"]
	out["description"] = str(ds[absi(id) % ds.size()])

## ============================================================ 2.6 여러 칸 구조물·세부 시설 (종류·부위까지 정확한 이름과 설명)
const GONGSIMDON_INFO := {
	"dongbuk": {"title": "동북공심돈 (東北空心墩)", "desc": "창룡문 북쪽 성벽에 솟은 3층 원형 망루로 소라각이라 불립니다.\n속이 빈 벽돌 몸통 안에서 군사가 돌아 오르며\n포구와 총안으로 밖을 살피고 사격하는 감시탑이자 포대입니다.\n성곽 가운데 가장 높고 독창적이라 정조께서도 극찬하셨습니다."},
	"seobuk": {"title": "서북공심돈 (西北空心墩)", "desc": "화서문 곁 팔달산 북쪽 성벽에 선 벽돌 공심돈.\n둥근 몸통에 총안을 뚫고 처마 지붕으로 덮어\n병졸이 처마 아래에서 비를 피하며 순찰합니다.\n포구로 적의 접근을 감시하고 공격하는 서쪽의 눈입니다."},
	"nam": {"title": "남공심돈 (南空心墩)", "desc": "남쪽 성벽 가까이 쌓은 낮고 작은 공심돈.\n벽돌 몸통의 아래 홍예문으로 오르내리며\n윗마루에서 포구와 총안으로 남쪽 평야를 살핍니다.\n팔달문 일대를 지키는 남쪽 방어의 요충입니다."},
}
const PORU_INFO := {
	"bukseo": {"title": "북서포루 (北西砲樓)", "desc": "성벽 바깥으로 내밀어 쌓은 공격형 포루(砲樓).\n석축 기단 위 벽돌 몸통에 포안이 뚫려 있어\n성벽에 붙는 적에게 화포를 쏘아 격퇴합니다.\n위층 누각은 깊은 처마의 팔작지붕을 얹었습니다."},
	"dongbuk": {"title": "동북포루 (東北鋪樓)", "desc": "화성의 포루(鋪樓)는 군사가 머물며 지키는 누각.\n화포를 쏘는 포루(砲樓)와 달리 대기와 감시가 맡은 일로\n성 밖을 살피다 위급하면 곧 알리는 초소입니다.\n창호를 단 위층에서 병졸이 쉬며 경계를 섭니다."},
	"buk": {"title": "북포루 (北鋪樓)", "desc": "북쪽 지형을 따라 비탈에 걸쳐 쌓은 포루(鋪樓).\n바위와 축대의 높낮이를 살려 지어 모양이 독특하며\n군사가 머무르며 북쪽 들판을 감시하는 초소입니다.\n포구는 없고 창호 달린 누각이 올라앉았습니다."},
	"nam": {"title": "남포루 (南砲樓)", "desc": "남쪽 성벽 바깥으로 돌출한 공격형 포루(砲樓).\n석축 위 벽돌 몸통의 포안에서 화포를 겨누어\n팔달문과 남수문 방면으로 접근하는 적을 막습니다.\n깊은 처마 아래 붉은 기둥의 누각이 얹혔습니다."},
}

## 상태줄·기본 이름용: 구조물 터 코드를 본 건물 코드로(연무대 연병장·활터는 따로 둔다)
static func canonical_building(code: String) -> String:
	if code in ["yeonmudae_site", "yeonmudae_range", "yeonmudae"]:
		return code
	var c := code
	if c.ends_with("_site"):
		c = c.trim_suffix("_site")
	elif c.ends_with("_wall"):
		c = c.trim_suffix("_wall")
	match c:
		"banghwasuryu":
			return "banghwasuryujeong"
		"hwahong":
			return "hwahongmun"
	return c

## 구조물 한 칸을 눌렀을 때: 어느 부위인지·어떤 종류인지까지 맞춘 팝업. 해당 없으면 빈 사전.
static func structure_inspect(raw_code: String, entity: Dictionary) -> Dictionary:
	var out := {"category": "building"}
	# 연무대: 본관 건물·연병장(훈련장)·활터(사격장)가 모두 연무대다
	if raw_code in ["yeonmudae", "yeonmudae_site", "yeonmudae_range"] or entity.has("ym5") or entity.has("ym_rng"):
		if entity.has("ym_rng") or raw_code == "yeonmudae_range":
			out["title"] = "연무대 활터 (사격장)"
			out["description"] = "연무대에 딸린 성 밖의 활쏘기 마당입니다.\n성 쪽에서 쏘면 먼 과녁에 화살이 꽂히며\n그 사이에는 민가나 논이 들어서지 못하게 비워 둡니다.\n장용영 무사들이 기량을 겨루는 연무대의 일부입니다."
		elif raw_code == "yeonmudae":
			out["title"] = "동장대 연무대 (東將臺 練武臺)"
			out["description"] = "넓은 연병장을 갖춘 장용영 군사들의 훈련장.\n활쏘기와 창검술, 조총 사격을 연마하며\n정예 무사를 양성하는 무예의 산실이자\n동쪽 성곽을 방어하는 군사 기지입니다."
		else:
			out["title"] = "연무대 연병장 (훈련장)"
			out["description"] = "연무대 본관 앞에 펼쳐진 넓은 박석 훈련 마당.\n장용영 군사들이 진법과 창검술을 익히고\n사열을 받으며 늠름한 무예를 닦는 곳입니다.\n동장대와 함께 연무대의 한 몸을 이룹니다."
		out["texture"] = get_portrait("yeonmudae")
		return out
	if entity.has("gs3") or (raw_code != "gongsimdon" and raw_code.begins_with("gongsimdon")):
		var gtype := str((entity.get("gs3", {}) as Dictionary).get("type", "nam"))
		var gi: Dictionary = GONGSIMDON_INFO.get(gtype, GONGSIMDON_INFO["nam"])
		out["title"] = str(gi["title"])
		out["description"] = str(gi["desc"])
		out["texture"] = portrait_pref(["gongsimdon_" + gtype], "gongsimdon")
		return out
	if entity.has("pr2") or (raw_code != "poru" and raw_code.begins_with("poru")):
		var ptype := str((entity.get("pr2", {}) as Dictionary).get("type", "nam"))
		var pi: Dictionary = PORU_INFO.get(ptype, PORU_INFO["nam"])
		out["title"] = str(pi["title"])
		out["description"] = str(pi["desc"])
		out["texture"] = portrait_pref(["poru_" + ptype], "poru")
		return out
	match raw_code:
		"banghwasuryu":
			out["title"] = "동북각루 방화수류정 (訪花隨柳亭)"
			out["description"] = "수원천 벼랑 위에 날아갈 듯 앉은 정자.\n꽃을 찾고 버들을 따라 노닌다는 뜻의 이름으로\n적을 감시하는 각루이자 연못 용연과 어우러진\n화성 건축의 빼어난 조형미를 뽐냅니다."
			out["texture"] = get_portrait("banghwasuryujeong")
			return out
		"yongyeon":
			out["title"] = "용연 (龍淵)"
			out["description"] = "방화수류정 아래 바위 벼랑에 안긴 작은 연못.\n물에 비친 정자와 버드나무가 한 폭의 그림이라\n수원팔경 가운데 방화수류의 절경을 이룹니다.\n용이 살았다는 전설이 전해집니다."
			out["texture"] = get_portrait("banghwasuryujeong")
			return out
		"manseokgeo", "manseokgeo_site":
			out["title"] = "만석거 (萬石渠)"
			out["description"] = "성 북쪽에 쌓은 큰 저수지로 대유평을 적십니다.\n물을 가두어 가뭄에도 논에 물을 대니\n해마다 만 석의 소출을 바라는 이름 그대로\n수리 사업의 첫걸음이 된 시설입니다."
			out["texture"] = get_portrait("reservoir")
			return out
		"canal":
			out["title"] = "대유평 관개 수로"
			out["description"] = "저수지의 물을 논밭으로 실어 나르는 도랑.\n수로가 닿는 둔전은 가뭄에도 물이 마르지 않아\n소출이 크게 늘고 해마다 풍년을 기약합니다."
			out["texture"] = get_portrait("daeyu")
			return out
		"well":
			out["title"] = "마을 공동 우물"
			out["description"] = "아낙들이 물을 긷고 소식을 나누는 동네 우물.\n두레박 소리가 아침저녁으로 울리며\n불이 나면 가장 먼저 물동이를 나르는 곳입니다."
			out["texture"] = get_portrait("washing")
			return out
		"guesthouse":
			out["title"] = "화성 객사 (客舍)"
			out["description"] = "관원과 사신이 묵어가는 관아의 숙소.\n임금의 위패를 모신 전각을 두고 예를 올리며\n먼 길 온 손님을 맞아 고을의 체면을 세웁니다."
			out["texture"] = get_portrait("base_ajeon")
			return out
		"factory":
			out["title"] = "관영 장인 공방"
			out["description"] = "나라에서 운영하는 장인들의 작업장.\n기와와 벽돌, 쇠못과 연장을 만들어 대며\n성곽 축조에 쓰이는 물자를 꾸준히 댑니다."
			out["texture"] = get_portrait("base_artisan")
			return out
		"yeonghwajeong", "yeonghwajeong_site":
			out["title"] = "영화정 (迎華亭)"
			out["description"] = "만석거 남쪽 둑에 세운 작은 누정입니다.\n농사를 살피러 온 관원이 쉬어 가고\n저수지의 물빛과 들판을 바라보는 자리입니다."
			out["texture"] = get_portrait("reservoir")
			return out
		"hyeminseo":
			out["title"] = "혜민서 (惠民署)"
			out["description"] = "가난한 백성에게 약을 베푸는 의료 관청.\n의원이 병자를 살피고 약재를 나누어 주니\n역병이 돌 때 고을의 큰 의지가 됩니다."
			out["texture"] = get_portrait("base_jungin")
			return out
		"ind_1", "ind_2":
			out["title"] = "수공업 공방" if raw_code == "ind_1" else "큰 수공업 공방"
			out["description"] = "대장장이와 옹기장이가 물건을 만드는 작업장.\n만든 물건은 저잣거리에 나가 팔리며\n공방이 커질수록 성곽에 쓸 자재도 넉넉해집니다."
			out["texture"] = get_portrait("base_artisan")
			return out
	return {}

## ============================================================ 3. 조선 상민/백성 무작위 성명 생성기
static func generate_commoner_name() -> String:
	var family_names: Array[String] = ["김", "이", "박", "최", "정", "강", "조", "윤", "장", "임", "한", "오", "신"]
	var given_names: Array[String] = [
		"돌쇠", "개똥이", "만복이", "삼돌이", "바우", "칠성이",
		"덕만이", "갑돌이", "막손이", "풍석이", "차돌이", "길손이",
		"봉구", "마당쇠", "득칠이", "달수", "춘식이", "분이", "순덕이"
	]
	var fn: String = family_names[randi() % family_names.size()]
	var gn: String = given_names[randi() % given_names.size()]
	return fn + gn

## ============================================================ 4. 동적 내러티브 종합 생성기 (build_inspect_data)
## 규격 준수:
## - 건물 / 건설 현장 / 특수 시설: 한 줄당 약 20자 내외, 총 4줄 (70~90자)
## - 네임드 NPC: 한 줄당 약 20자 내외, 총 3~4줄 (60~80자)
## - 일반 NPC / 행동 상태 / 동물: 한 줄당 약 20자 내외, 총 2줄 (35~45자)
static func build_inspect_data(entity: Dictionary, sim: SimulationCore = null, grid: GameGrid = null, citizens: CitizenManager = null) -> Dictionary:
	var kind: String = entity.get("kind", "")
	var out: Dictionary = {
		"title": "화성 명소",
		"description": "수원 화성의 평온한 땅입니다.\n새로운 역사가 시작될 터전입니다.",
		"texture": get_portrait("commoner"),
		"category": "default"
	}

	# ------------------------------------------------------------ 0. 11종 세시풍속 및 민속놀이 특수 행동 최우선 매핑!
	var act_candidate: String = str(entity.get("activity_type", entity.get("action_state", entity.get("current_activity", ""))))
	if act_candidate == "":
		var raw_act_type: String = str(entity.get("type", ""))
		var raw_act_state: String = str(entity.get("state", entity.get("action", entity.get("task", ""))))
		var cand_norm: String = normalize_activity_key(raw_act_type)
		if cand_norm != "":
			act_candidate = cand_norm
		else:
			cand_norm = normalize_activity_key(raw_act_state)
			if cand_norm != "":
				act_candidate = cand_norm
	else:
		act_candidate = normalize_activity_key(act_candidate)

	if act_candidate != "" and FOLKLORE_NARRATIVES.has(act_candidate):
		var f_data: Dictionary = FOLKLORE_NARRATIVES[act_candidate]
		out["category"] = "folklore"
		out["title"] = str(f_data.get("title", "세시풍속 민속놀이"))
		out["description"] = str(f_data.get("description", ""))
		out["texture"] = get_portrait(str(f_data.get("portrait", "commoner")))
		return out

	# ------------------------------------------------------------ A. 역사적 네임드 NPC
	if kind == "named_npc" or entity.get("is_named", false) or entity.has("named_id"):
		var nid: String = entity.get("named_id", entity.get("id", ""))
		out["category"] = "named_npc"
		# 등용 인재 17인 + 유한지: 이름·직함·설명·초상을 인물 명세에서
		var nmi: Dictionary = CitizenManager.named_info(nid)
		if NamedNpcs.has(nid) or (nid == "yu_hanji" and not nmi.is_empty()):
			out["title"] = "[%s] %s" % [str(nmi.get("title", "")), str(nmi.get("name", ""))]
			out["texture"] = get_portrait(nid)
			out["description"] = "%s\n%s" % [str(nmi.get("desc", "")), str(nmi.get("activity", ""))]
			return out
		match nid:
			"jeongjo", "king":
				out["title"] = "[조선 제22대 국왕] 정조 대왕 (正祖大王)"
				out["texture"] = get_portrait("jeongjo")
				out["description"] = "어질고 위엄 있는 눈빛으로 성곽을 굽어살핍니다.\n\"백성이 편안해야 나라가 바로 서는 법이다.\"\n아버지 사도세자를 기리며 개혁에 몰두합니다.\n화성 행차 준비로 친위부대를 직접 점검합니다."
			"jeong_yakyong":
				out["title"] = "[실학자·수원화성 설계자] 정약용 (丁若鏞)"
				out["texture"] = get_portrait("jeong_yakyong")
				out["description"] = "《기기도설》을 펼쳐두고 거중기 도면을 살핍니다.\n벽돌 굽는 전유 기술과 성곽 설계를 고민하며\n공사 비용과 인부들의 노역을 줄이고자 합니다.\n서학의 과학기술을 조선의 실정에 맞게 다듬습니다."
			"kim_hongdo":
				out["title"] = "[도화서 화원·단원] 김홍도 (金弘道)"
				out["texture"] = get_portrait("kim_hongdo")
				out["description"] = "붓과 먹을 들고 화성의 풍경을 화폭에 담습니다.\n일하는 석수와 밭 가는 농민의 땀방울을 관찰하며\n정조 대왕께 바칠 성역 의궤도를 준비 중입니다.\n익살스럽고 생생한 백성들의 표정을 스케치합니다."
			"chae_jegong":
				out["title"] = "[영의정·화성성역 총리사] 채제공 (蔡濟恭)"
				out["texture"] = get_portrait("chae_jegong")
				out["description"] = "조정의 원로로서 백성을 아끼며 공역을 총괄합니다.\n\"품삯을 후하게 주어야 일꾼들이 힘을 낸다.\"\n모립제의 모범을 세워 민심을 보듬고자 애쓰며\n임금님의 뜻을 받들어 성역을 굳건히 이끕니다."
			"kim_pankwan", "advisor":
				out["title"] = "[수원부 판관·축성 길잡이] 김판관 (金判官)"
				out["texture"] = get_portrait("kim_pankwan")
				out["description"] = "초록 관복을 바르게 여미고 신시의 정무를 살핍니다.\n\"성곽과 길이 곧아야 고을이 번창하는 법이오.\"\n고을 백성들의 고충을 듣고 관아에 보고하며\n축성 역사가 차질 없이 진행되도록 안내합니다."
			"kim_bau":
				out["title"] = "[수석 석공 명장] 석수 김바우 (金바우)"
				out["texture"] = get_portrait("kim_bau")
				out["description"] = "정질 소리가 맑게 울리는 팔달산 아래의 명장.\n거대한 화강암을 자로 잰 듯 반듯하게 깎아내며\n천 년을 버틸 옹골찬 성곽의 뼈대를 세웁니다.\n돌에 새겨진 정성은 세월이 흘러도 변치 않습니다."
			"jo_simtae":
				out["title"] = "[수원부사·화성 감동당상] 조심태 (趙心泰)"
				out["texture"] = get_portrait("jo_simtae")
				out["description"] = "말을 타고 공사 구간을 주야로 순시하는 수령.\n자재 수급과 인부들의 끼니를 꼼꼼히 챙기며\n수원천 치수와 석축 공사를 진두지휘합니다.\n고을의 발전과 백성의 평안을 위해 헌신합니다."
			"gu_seonbok":
				out["title"] = "[훈련대장·장용영 군사 지휘관] 구선복 (具善復)"
				out["texture"] = get_portrait("gu_seonbok")
				out["description"] = "갑주를 차려입고 성곽 방어진지를 점검합니다.\n\"군율이 서야 외적과 도적의 침탈을 막아낸다.\"\n조총수와 창검병의 훈련을 엄하게 독려하며\n도성의 방패가 될 화성의 안보를 지켜냅니다."
			"baek_dongsoo":
				out["title"] = "[장용영 무관·조선제일검] 백동수 (白東脩)"
				out["texture"] = get_portrait("baek_dongsoo")
				out["description"] = "단단한 기개로 《무예도보통지》를 연마합니다.\n조총과 당파, 월도를 자유자재로 지휘하며\n장용영 장병들에게 실전 무예를 전수합니다.\n백성을 위협하는 도적 무리를 일격에 소탕합니다."
			_:
				var dname: String = entity.get("name", "고을의 명인")
				out["title"] = "[화성 명인] %s" % dname
				out["texture"] = get_portrait("commoner")
				out["description"] = "화성 성역의 역사에 동참하는 뜻깊은 인물입니다.\n각자의 자리에서 맡은 바 소임을 다하며\n정조 대왕의 원대한 개혁을 묵묵히 뒷받침합니다.\n훗날 성역의궤에 그 이름이 길이 빛날 것입니다."
		return out

	# ------------------------------------------------------------ A-2. 수원천 특수 구조물 (남수문, 화홍문, 매향교) 최우선 판정
	var fac_id: String = entity.get("facility_id", entity.get("special_building_id", ""))
	if fac_id == "namsu_mun" or (fac_id == "" and entity.get("is_namsu", false)):
		out["category"] = "special_building"
		out["title"] = "화성 남수문 (南水門)"
		out["texture"] = get_portrait("namsumun")
		out["description"] = "수원천 하류에 아홉 개 홍예를 틀어 올린 수문.\n평시에는 물길을 틔워 도심의 범람을 막고\n유사시에는 군사들이 머무는 방어 요새입니다.\n단단한 화강암 축조가 돋보이는 군사 시설입니다."
		return out
	elif fac_id == "hwahong_mun" or (fac_id == "" and entity.get("is_hwahong", false)):
		out["category"] = "special_building"
		out["title"] = "화성 화홍문 (華虹門)"
		out["texture"] = get_portrait("hwahongmun")
		out["description"] = "일곱 개의 수문을 통해 시원한 물보라가 뿜어지며\n누각 아래로 무지개가 피어나는 아름다운 북수문.\n적을 감시하는 포루와 수문 기능을 겸비하여\n수원팔경 중 으뜸인 화홍포설의 절경을 이룹니다."
		return out
	elif fac_id in ["maehwang_gyo", "maehyang_gyo"] or (fac_id == "" and entity.get("is_maehyang", false)):
		out["category"] = "special_building"
		out["title"] = "수원천 매향교 (梅香橋)"
		out["texture"] = get_portrait("maehwang_gyo")
		out["description"] = "화성 중심 가로와 행궁, 장터를 잇는 주요 돌다리.\n백성들과 수레가 끊임없이 물길을 건너다니며\n수원천의 맑은 물결과 버드나무가 어우러져\n도심 교통과 유통의 동맥 역할을 담당합니다."
		return out

	# ------------------------------------------------------------ B. 건설 중인 부지
	if entity.get("under_construction", false) or kind == "construction":
		var raw_b_name: String = entity.get("building_name", entity.get("building", "국책 대역사"))
		var b_name: String = get_korean_name(raw_b_name, raw_b_name)
		out["category"] = "construction"
		out["title"] = "%s 건설 현장" % b_name
		out["texture"] = get_portrait("construction")
		out["description"] = "장인들이 땀을 흘리며 주춧돌을 다듬습니다.\n정조 대왕께서 하사하신 탕약을 마시며\n완공될 웅장한 누각을 기대하고 있습니다.\n품삯이 후하여 인부들의 사기가 높습니다."
		return out

	# ------------------------------------------------------------ C. 신규 6대 직업군 거점 건물 (20자 4줄)
	var base_jt: int = -1
	var assigned_agent: Dictionary = {}
	if entity.has("base_job_type"):
		base_jt = int(entity["base_job_type"])
	elif entity.get("is_base", false) and entity.has("job_type"):
		base_jt = int(entity["job_type"])
	elif str(entity.get("building", "")) == "base_jungin" or str(entity.get("building_type", "")) == "base_jungin":
		base_jt = 1
	elif str(entity.get("building", "")) == "base_ajeon" or str(entity.get("building_type", "")) == "base_ajeon":
		base_jt = 2
	elif str(entity.get("building", "")) == "base_artisan" or str(entity.get("building_type", "")) == "base_artisan":
		base_jt = 3
	elif str(entity.get("building", "")) == "base_butcher" or str(entity.get("building_type", "")) == "base_butcher":
		base_jt = 6
	elif citizens != null and ("agents" in citizens) and entity.has("pos"):
		var t_pos: Vector2i = entity["pos"]
		for ag: Variant in citizens.agents:
			if ag is Dictionary:
				var a_dict: Dictionary = ag as Dictionary
				if a_dict.get("is_professional", false) and a_dict.get("home_tile", Vector2i(-1, -1)) == t_pos:
					base_jt = int(a_dict.get("job_type", 0))
					assigned_agent = a_dict
					break

	if base_jt in [1, 2, 3, 6]:
		out["category"] = "professional_base"
		var prof_name: String = ""
		if not assigned_agent.is_empty():
			prof_name = str(assigned_agent.get("npc_name", ""))
		elif entity.has("npc_name"):
			prof_name = str(entity["npc_name"])
		elif citizens != null and citizens.has_method("generate_npc_name"):
			prof_name = citizens.generate_npc_name(base_jt)
		else:
			match base_jt:
				1: prof_name = "의원 유태석"
				2: prof_name = "호방 김득원"
				3: prof_name = "도편수 이성길"
				6: prof_name = "가죽공 무쇠"

		match base_jt:
			1: # 중인 (의원/약방 - 20자 4줄)
				out["title"] = "%s의 약방 가옥" % prof_name
				out["texture"] = get_portrait("base_jungin")
				out["description"] = "처마 밑 건조대가 약초 향을 풍깁니다.\n맥을 짚고 의서를 보며 병을 돌보느라\n밤낮없이 행궁과 약방을 오갑니다.\n실사구시 의술로 백성을 살핍니다."
				return out
			2: # 아전 (이방/호방 - 20자 4줄)
				out["title"] = "화성유수부 %s의 가택" % prof_name
				out["texture"] = get_portrait("base_ajeon")
				out["description"] = "장부와 먹이 놓인 실용적 기와집.\n둔전의 소출과 세금을 정밀히 계산하며\n수령의 명을 받들어 행정을 폅니다.\n빈틈없는 솜씨로 신망을 얻습니다."
				return out
			3: # 전문 장인 (석수장/도편수 - 20자 4줄)
				out["title"] = "%s의 공방 채" % prof_name
				out["texture"] = get_portrait("base_artisan")
				out["description"] = "마당에 화강암과 먹줄이 놓였습니다.\n거중기로 웅장한 성곽을 쌓아 올리며\n나라에서 넉넉한 품삯을 받습니다.\n어명에 최고의 기술로 보답합니다."
				return out
			6: # 백정 (가죽공 - 20자 4줄)
				out["title"] = "%s의 외곽 움막" % prof_name
				out["texture"] = get_portrait("base_butcher")
				out["description"] = "마당에 무두질한 가죽이 널렸습니다.\n포수들이 사냥한 맹수를 손질하여\n군영의 북과 갑옷 재료로 바칩니다.\n천대를 묵묵한 손기술로 견딥니다."
				return out

	# ------------------------------------------------------------ D. 방리(마을) 세부 시설 (우시장, 마당놀이, 놀이터, 서당) 최우선 분기!
	var plaza_dict: Dictionary = entity.get("plaza", {}) if entity.get("plaza") is Dictionary else {}
	var plaza_kind: String = str(entity.get("plaza_kind", plaza_dict.get("kind", "")))
	var fac_type: String = str(entity.get("facility_type", ""))
	var b_code_check: String = str(entity.get("building", ""))

	if plaza_kind == "cattle" or fac_type == "cattle" or kind == "cattle" or b_code_check in ["cattle", "cattle_market"]:
		out["category"] = "facility"
		out["title"] = "수원 우시장 (쇠전)"
		out["texture"] = get_portrait("cattle")
		out["description"] = "정조 대왕의 둔전 경영과 권농 정책으로\n전국 최대 규모로 성장한 수원 소시장.\n질 좋은 황소가 팔도 각지에서 모여들어\n화성 경제와 우하장터 번영을 이끕니다."
		return out
	elif plaza_kind == "play" or fac_type == "play" or kind == "play" or b_code_check in ["play", "play_yard"]:
		out["category"] = "facility"
		out["title"] = "방리 마당놀이 터 (풍물마당)"
		out["texture"] = get_portrait("play")
		out["description"] = "신명 나는 꽹과리와 북소리가 울려 퍼지며\n고단한 노역을 잊게 하는 백성들의 쉼터.\n줄타기와 탈춤 판이 신명 나게 벌어져\n온 마을 사람이 어우러져 흥을 돋웁니다."
		return out
	elif plaza_kind == "kids" or fac_type == "kids" or kind == "kids" or b_code_check in ["kids", "playground"]:
		out["category"] = "facility"
		out["title"] = "골목 안 동네 놀이터"
		out["texture"] = get_portrait("kids")
		out["description"] = "초가지붕 골목길에 아이들의 웃음소리가\n해 질 녘까지 끊이지 않는 정겨운 공간.\n제기차기와 자치기, 팽이치기를 즐기며\n동네 아이들이 티 없이 자라납니다."
		return out
	elif plaza_kind == "seodang" or fac_type == "seodang" or kind == "seodang" or b_code_check == "seodang" or fac_id == "seodang" or entity.get("special_type", "") == "seodang":
		out["category"] = "facility"
		out["title"] = "동네 서당 (글방)"
		out["texture"] = get_portrait("seodang")
		out["description"] = "훈장님의 쩌렁쩌렁한 글 읽는 소리와 함께\n학동들이 《천자문》과 《소학》을 익힙니다.\n예절과 인의예지의 도리를 가슴에 새기며\n훗날 고을을 빛낼 동량으로 자라납니다."
		return out
	elif plaza_kind in ["seowon", "maegok_seowon"] or fac_type in ["seowon", "maegok_seowon"] or kind in ["seowon", "maegok_seowon"] or b_code_check in ["seowon", "maegok_seowon"] or fac_id in ["seowon", "maegok_seowon"] or str(entity.get("special_type", "")) in ["seowon", "maegok_seowon"] or str(entity.get("type_id", "")) in ["seowon", "maegok_seowon"] or str(entity.get("special_building_id", "")) in ["seowon", "maegok_seowon"]:
		out["category"] = "special_building"
		out["title"] = "화성 유학 서원 (書院)"
		out["texture"] = get_portrait("seowon")
		out["description"] = "선현의 위패를 모시고 유학을 강론하는 서원.\n유생들이 성리학과 경전을 깊이 탐구하며\n의리와 절개를 다지는 배움의 전당입니다.\n낭랑한 글 읽는 소리가 사방에 울립니다."
		return out
	elif plaza_kind == "market" or fac_type == "market_plaza" or b_code_check == "plaza":
		out["category"] = "facility"
		out["title"] = "저잣거리 난전 마당"
		out["texture"] = get_portrait("market")
		out["description"] = "멍석을 깐 보따리 상인과 광대패가 어우러져\n흥겨운 풍물 소리와 흥정이 가득한 열린 마당.\n팔도에서 모여든 길손들이 잠시 목을 축이며\n화성 저잣거리의 생동하는 활기를 꽃피웁니다."
		return out

	# ------------------------------------------------------------ E. 저잣거리 상점 (성문 위치별 & 업종별 특성화)
	var is_market_shop: bool = entity.get("zone", "") == "com" or b_code_check in ["market", "shop", "commercial"] or entity.has("trade") or entity.get("is_market", false) or kind == "market"
	if is_market_shop:
		out["category"] = "market"
		var trade_type: String = str(entity.get("trade", entity.get("shop_type", "")))
		var pos_v: Vector2i = entity.get("pos", Vector2i(-1, -1))
		var total_shops: int = BuildingManager.active_market_shop_count
		var total_ws: int = BuildingManager.active_workshop_count
		var cov_shops: int = mini(total_shops, total_ws * 10)
		var buff_suffix: String = "\n%s" % WorkshopManager.get_market_buff_tooltip_text(cov_shops, total_shops)

		# 업종별 우선 매핑
		match trade_type:
			"silk", "fabric":
				out["title"] = "화성 저잣거리 포목전 (비단전)"
				out["texture"] = get_portrait("shop_silk")
				out["description"] = "팔도에서 올라온 명주와 무명이 가득한 전각.\n혼례를 앞둔 처자와 양반들이 찾아와\n고운 빛깔의 옷감을 고르며 흥정하니\n화려한 비단 결이 거리를 환히 밝힙니다." + buff_suffix
				return out
			"fish", "seafood":
				out["title"] = "화성 저잣거리 어물전"
				out["texture"] = get_portrait("shop_fish")
				out["description"] = "서해 남양포구에서 갓 실어온 생선과 건어물.\n자반고등어와 조기, 마른오징어가 산더미라\n비릿하면서도 구수한 바다 향을 풍기며\n알뜰한 밥상을 차리는 손길을 부릅니다." + buff_suffix
				return out
			"rice", "grain":
				out["title"] = "화성 저잣거리 싸전 (미곡상)"
				out["texture"] = get_portrait("shop_rice")
				out["description"] = "만석거 너른 둔전에서 거둔 햇벼와 쌀가마.\n말과 됫박으로 정직하게 양을 달아 팔며\n풍년의 기쁨이 쌀알마다 하얗게 묻어나\n고을 백성의 끼니를 든든히 지킵니다." + buff_suffix
				return out
			"smith", "iron":
				out["title"] = "화성 저잣거리 대장간"
				out["texture"] = get_portrait("shop_smith")
				out["description"] = "벌건 풀무불과 묵직한 쇠망치 소리의 현장.\n성곽 축성에 쓸 쇠못과 정, 농사용 쟁기를\n달구고 담금질하여 단단히 벼려내니\n장인의 땀방울이 명품 쇠붙이를 낳습니다." + buff_suffix
				return out
			"jumak", "inn":
				out["title"] = "화성 저잣거리 주막 (객주)"
				out["texture"] = get_portrait("shop_jumak")
				out["description"] = "먼 길을 걸어온 나그네와 보부상의 쉼터.\n구수한 국밥과 시원한 탁주 한 사발에\n여독을 풀고 팔도 소식을 나누며 쉬어가니\n신시의 인정이 술잔마다 넘쳐납니다." + buff_suffix
				return out

		# 성문 위치별 매핑
		if pos_v.y > 38: # 팔달문 앞 (삼남대로 남쪽 상업지)
			out["title"] = "팔달문 앞 삼남대로 상가"
			out["texture"] = get_portrait("market")
			out["description"] = "삼남대로를 잇는 남쪽 관문의 최대 상업지.\n호남과 영남의 풍부한 미곡과 물산이 모여\n도매 상인들이 밤낮없이 거래를 트며\n화성의 풍요로운 상권을 이끌어갑니다." + buff_suffix
			return out
		elif pos_v.y >= 0 and pos_v.y < 18: # 장안문 앞 (북쪽 한양 관문)
			out["title"] = "장안문 앞 왕도 물류 상가"
			out["texture"] = get_portrait("market")
			out["description"] = "한양 도성과 통하는 북쪽 정문의 번화가.\n경강상인과 역마가 줄지어 오가며\n고급 비단과 서책, 약재가 유통되는\n왕도와 화성을 잇는 핵심 물류 기지입니다." + buff_suffix
			return out
		elif (pos_v.x >= 0 and pos_v.x < 18) or pos_v.x > 38: # 창룡문 / 화서문 외곽 난전
			out["title"] = "성문 외곽 둔전 난전 거리"
			out["texture"] = get_portrait("market")
			out["description"] = "성 밖 둔전과 산야를 잇는 외곽의 난전.\n싱싱한 농산물과 짚신, 농기구가 부려져\n장터 마당에 빼곡히 늘어서며\n소박한 백성들의 알찬 장터를 엽니다." + buff_suffix
			return out
		else:
			out["title"] = "화성 저잣거리 (시전 상가)"
			out["texture"] = get_portrait("market")
			out["description"] = "삼남 대로의 물자가 모여드는 번화한 장터.\n비단과 옹기, 쌀과 소금이 활발히 거래되며\n전국의 보부상들이 흥정을 벌이는 중심지로\n통공 정책에 상업이 만개합니다." + buff_suffix
			return out

	# ------------------------------------------------------------ F. 화성 특수 건물 및 주요 공공 시설 (한글 정식 명칭 및 4줄 고증)
	var is_residential_building: bool = b_code_check.begins_with("res_") or entity.get("zone", "") == "res"
	if b_code_check != "" and not is_residential_building:
		out["category"] = "building"
		# 여러 칸 구조물(연무대·공심돈·포루 …)은 종류·부위까지 정확한 이름과 설명으로
		var detail := structure_inspect(b_code_check, entity)
		if not detail.is_empty():
			for dk in detail:
				out[dk] = detail[dk]
			return out
		b_code_check = canonical_building(b_code_check) # 터(_site)·성벽 연결칸(_wall)도 본 건물로 본다
		match b_code_check:
			"gwana", "gwana_site":
				out["title"] = "화성유수부 동헌 (관아)"
				out["texture"] = get_portrait("base_ajeon")
				out["description"] = "화성의 행정과 군정을 총괄하는 관아 건물.\n유수와 판관이 공무를 보며 송사를 다루고\n호적과 둔전 세금을 엄정히 관리합니다.\n청렴한 다스림으로 고을 질서를 세웁니다."
				return out
			"seowon", "maegok_seowon":
				out["title"] = "화성 유학 서원 (書院)"
				out["texture"] = get_portrait("seowon")
				out["description"] = "선현의 위패를 모시고 유학을 강론하는 서원.\n유생들이 성리학과 경전을 깊이 탐구하며\n의리와 절개를 다지는 배움의 전당입니다.\n낭랑한 글 읽는 소리가 사방에 울립니다."
				return out
			"jongnu", "jongnu_site", "bell_tower":
				out["title"] = "화성 십자로 종루 (鐘樓)"
				out["texture"] = get_portrait("jongnu")
				out["description"] = "화성 중심 가로가 교차하는 십자로 누각.\n종을 울려 성문을 여닫고 시각을 알리며\n상업 거리의 중심축을 잡는 상징적 건물로\n도심의 질서와 치안을 통제하는 기준점입니다."
				return out
			"seojangdae":
				out["title"] = "화성 서장대 (西將臺)"
				out["texture"] = get_portrait("seojangdae")
				out["description"] = "팔달산 정상에서 성 안팎을 호령하는 누각.\n정조 대왕께서 군사 훈련을 직접 지휘하셨고\n사방 백 리를 한눈에 살피는 지휘소로\n장용영 군사들의 늠름한 기개가 서렸습니다."
				return out
			"banghwasuryujeong", "dongbuk_gakru":
				out["title"] = "동북각루 방화수류정 (訪花隨柳亭)"
				out["texture"] = get_portrait("banghwasuryujeong")
				out["description"] = "수원천 벼랑 위에 날아갈 듯 앉은 정자.\n적을 감시하는 군사 요충지인 동시에\n연못 용연과 어우러져 한 폭의 그림을 이루며\n조선 건축의 빼어난 조형미를 뽐냅니다."
				return out
			"hwahong_mun":
				out["title"] = "화성 화홍문 (華虹門)"
				out["texture"] = get_portrait("hwahongmun")
				out["description"] = "일곱 개의 수문을 통해 시원한 물보라가 뿜어지며\n누각 아래로 무지개가 피어나는 아름다운 북수문.\n적을 감시하는 포루와 수문 기능을 겸비하여\n수원팔경 중 으뜸인 화홍포설의 절경을 이룹니다."
				return out
			"hwahongmun", "buksumun":
				out["title"] = "화홍문 북수문 (華虹門)"
				out["texture"] = get_portrait("hwahongmun")
				out["description"] = "수원천 물길 위에 세워진 일곱 홍예석교.\n쏟아지는 물보라가 무지개를 피워 올리며\n수문 위 누각은 적을 막는 요새가 되니\n치수와 방어가 결합된 걸작입니다."
				return out
			"namsu_mun":
				out["title"] = "화성 남수문 (南水門)"
				out["texture"] = get_portrait("namsumun")
				out["description"] = "수원천 하류에 아홉 개 홍예를 틀어 올린 수문.\n평시에는 물길을 틔워 도심의 범람을 막고\n유사시에는 군사들이 머무는 방어 요새입니다.\n단단한 화강암 축조가 돋보이는 군사 시설입니다."
				return out
			"namsumun":
				out["title"] = "화성 남수문 (南水門)"
				out["texture"] = get_portrait("namsumun")
				out["description"] = "수원천 하류에 축조된 남수문의 아홉 홍예.\n도성을 빠져나가는 물길을 부드럽게 다스리며\n성벽과 포루가 연결된 굳건한 방어선으로\n외적의 수로 침투를 빈틈없이 차단합니다."
				return out
			"maehwang_gyo", "maehyang_gyo":
				out["title"] = "수원천 매향교 (梅香橋)"
				out["texture"] = get_portrait("maehwang_gyo")
				out["description"] = "화성 중심 가로와 행궁, 장터를 잇는 주요 돌다리.\n백성들과 수레가 끊임없이 물길을 건너다니며\n수원천의 맑은 물결과 버드나무가 어우러져\n도심 교통과 유통의 동맥 역할을 담당합니다."
				return out
			"gongsimdon", "dongbuk_gongsimdon", "seobuk_gongsimdon":
				out["title"] = "화성 공심돈 (空心墩)"
				out["texture"] = get_portrait("gongsimdon")
				out["description"] = "성벽 안쪽을 비워 벽돌로 쌓아 올린 돈대.\n3층 내부에서 총포와 화살을 쏘아대며\n적의 접근을 입체적으로 섬멸하는 요새로\n정조 대왕께서도 극찬하신 독창적 시설입니다."
				return out
			"bongdon", "beacon":
				out["title"] = "화성 봉돈 (烽墩)"
				out["texture"] = get_portrait("bongdon")
				out["description"] = "다섯 개 굴뚝으로 축조된 통신 요새.\n연기와 불빛으로 도성의 안위를 전하며\n평시엔 하나, 위급 시엔 다섯을 올려\n나라의 위난을 행궁에 알리는 보루입니다."
				return out
			"poru", "dongporu", "seoporu", "bukporu", "namporu":
				out["title"] = "화성 포루 (砲樓)"
				out["texture"] = get_portrait("poru")
				out["description"] = "성벽 바깥으로 돌출시켜 쌓은 포루 누각.\n화포를 숨겨두고 사방의 적을 포격하여\n성벽에 붙으려는 적병을 격퇴하니\n조선의 뛰어난 화약 기술이 깃들었습니다."
				return out
			"yeonmudae", "dongjangdae":
				out["title"] = "동장대 연무대 (東將臺 練武臺)"
				out["texture"] = get_portrait("yeonmudae")
				out["description"] = "넓은 연병장을 갖춘 장용영 군사들의 훈련장.\n활쏘기와 창검술, 조총 사격을 연마하며\n정예 무사를 양성하는 무예의 산실이자\n동쪽 성곽을 방어하는 군사 기지입니다."
				return out
			"embankment", "levee", "dike":
				out["title"] = "수원천 석축제방 (石築堤防)"
				out["texture"] = get_portrait("embankment")
				out["description"] = "수원천 범람을 막고자 쌓은 돌 제방.\n장마철 거센 물살에도 민가를 지켜내며\n제방 위 둑길은 백성의 안전한 통행로로\n도심 치수의 든든한 방패가 됩니다."
				return out
			"road", "street", "stone_road":
				var pos_r: Vector2i = entity.get("pos", Vector2i(-1, -1))
				var border_k: String = str(entity.get("border_gate", entity.get("gate_kind", "")))
				if border_k == "" and grid != null and pos_r.x >= 0:
					var b_conns: Dictionary = grid.check_border_road_connections()
					for gk: String in b_conns.keys():
						if b_conns[gk].get("connected", false) and b_conns[gk].get("border_tile") == pos_r:
							border_k = gk
							break

				if border_k != "":
					match border_k:
						"jangan":
							out["title"] = "이정표: 「한양(漢陽)으로 가는 길」"
							out["texture"] = get_portrait("road")
							out["description"] = "장안문 북쪽 도로가 외부와 이어진 관도.\n국왕의 능행차로이자 한양 조정 직통로로\n공문서와 고급 수공업품이 오가며\n화성을 왕도와 잇는 핵심 대동맥입니다."
							return out
						"paldal":
							out["title"] = "이정표: 「삼남대로 / 현륭원(융릉)으로 가는 길」"
							out["texture"] = get_portrait("road")
							out["description"] = "팔달문 남쪽 도로가 외부와 이어진 관도.\n삼남으로 뻗어 현륭원으로 향하는 길로\n각지의 곡물과 우마가 줄지어 들어오며\n전국 보부상들이 쉼 없이 왕래합니다."
							return out
						"changryong":
							out["title"] = "이정표: 「광주 / 동해로 가는 길」"
							out["texture"] = get_portrait("road")
							out["description"] = "창룡문 동쪽 도로가 외부와 이어진 관도.\n남한산성과 광주 내륙을 잇는 길목으로\n양질의 목재와 땔감, 도자기가 유입되어\n화성 축성과 연료 공급을 뒷받침합니다."
							return out
						"hwaseo":
							out["title"] = "이정표: 「남양만 / 서해 갯벌로 가는 길」"
							out["texture"] = get_portrait("road")
							out["description"] = "화서문 서쪽 도로가 외부와 이어진 관도.\n남양만과 안산 포구로 통하는 어염로로\n서해의 천일염과 신선한 어물이 들어와\n백성들의 밥상을 풍요롭게 채워줍니다."
							return out

				out["title"] = "화성 주간선 도로 (박석길)"
				out["texture"] = get_portrait("road")
				out["description"] = "사대문과 종루를 잇는 간선도로.\n박석을 깔아 비가 와도 질퍽이지 않고\n수레와 가마가 안전하게 통행하는\n신시 물류와 행정의 대동맥입니다."
				return out
			"haenggung", "haenggung_site":
				var prince_score: float = sim.crown_prince_manager.progress if (sim != null and sim.crown_prince_manager != null) else 50.0
				var p_stage: int = CrownPrinceData.get_stage_by_score(prince_score)
				out["title"] = "화성행궁 (봉수당 및 세자 시강원)"
				var prince_tex: Texture2D = CrownPrinceData.get_portrait_texture(p_stage)
				out["texture"] = prince_tex if prince_tex != null else get_portrait("haenggung")
				out["description"] = "정조 대왕의 어명으로 시강원 서연이 열리는 궁궐.\n현재 세자: %s (진척 %d%%)\n\"%s\"\n군주의 위엄과 효심이 깃든 화성의 심장부입니다." % [
					CrownPrinceData.get_stage_title(p_stage),
					int(prince_score),
					CrownPrinceData.get_stage_quote(p_stage)
				]
				return out
			"gate":
				var gname: String = entity.get("gate_name", "홍예성문")
				out["title"] = "%s (사대문)" % gname
				out["texture"] = portrait_pref([_gate_portrait_key(gname)], "gate")
				out["description"] = "견고한 화강암 홍예석과 웅장한 문루의 조화.\n옹성과 벽돌 총안이 침략군을 사방에서 에워싸며\n삼남과 한양을 잇는 물류의 중심 관문으로\n밤낮으로 순라군이 철통같이 방비하고 있습니다."
				return out
			"wall":
				out["title"] = "화성 체성 성곽 (城郭)"
				out["texture"] = get_portrait("wall")
				out["description"] = "정약용의 《성설》에 따라 축조된 불멸의 방벽.\n화강암 지대석 위에 정교한 규석을 층층이 쌓아\n외적의 포격에도 무너지지 않는 요새를 완성했습니다.\n백성을 보호하는 든든한 울타리이자 나라의 보루입니다."
				return out
			"patrol":
				out["title"] = "순라청 (巡邏廳)"
				out["texture"] = get_portrait("patrol_post")
				out["description"] = "고을의 치안과 야간 통금을 책임지는 방위 관청.\n장용영 군병들이 조총과 환도를 차고 출동하며\n도적 무리와 흉악범을 엄정하게 소탕하여\n백성들이 안심하고 생업에 종사할 수 있게 지킵니다."
				return out
			"firefighter":
				out["title"] = "멸화군 수성소 (滅火軍)"
				out["texture"] = get_portrait("firestation")
				out["description"] = "화재를 감시하고 신속히 진화하는 전문 소방대.\n물통과 쇠갈고리, 방수포를 상시 비치해두어\n민가의 연기만 피어올라도 즉시 출동하여\n불길이 성내로 번지는 재앙을 미연에 방지합니다."
				return out
			"reservoir":
				out["title"] = "화성 저수지 (수리 시설)"
				out["texture"] = get_portrait("reservoir")
				out["description"] = "대유둔전의 가뭄을 막기 위해 축조된 인공 저수지.\n물길을 다스려 메마른 들판을 옥토로 탈바꿈시키며\n해마다 만 석의 쌀을 수확하는 풍요의 원천입니다.\n연꽃과 버드나무가 어우러져 경관 또한 빼어납니다."
				return out
			"chukmanje":
				out["title"] = "축만제 (祝萬堤)"
				out["texture"] = get_portrait("chukmanje")
				out["description"] = "화성 서쪽에 축조된 대규모 인공 수리 저수지.\n풍부한 농업용수를 공급하여 흉년을 막고\n수리 시설의 기틀을 다져 신도시의 식량을 보장합니다.\n서호낙조의 아름다운 풍광을 자랑하는 명소입니다."
				return out
			"jinhulso":
				out["title"] = "진휼소 (賑恤所)"
				out["texture"] = get_portrait("jinhulso")
				out["description"] = "기근이나 재난 시 굶주린 빈민을 구제하는 복지 관청.\n비축한 곡식을 무상 배급하고 죽을 쑤어 나누며\n가난한 백성들이 유민이 되지 않도록 보살핍니다.\n목민관의 따뜻한 온정이 깃든 화성의 복지 기관입니다."
				return out
			"hyanggyo":
				out["title"] = "수원향교 (水原鄕校)"
				out["texture"] = get_portrait("hyanggyo")
				out["description"] = "공자와 성현들의 위패를 모신 유학의 전당.\n대성전에서 제향을 올리고 명륜당에서 강독하며\n선비정신과 실사구시의 학통을 계승하는 명소입니다.\n선비들의 꼿꼿한 기개가 화성을 맑게 비춥니다."
				return out
			"agr_1":
				out["category"] = "facility"
				out["texture"] = get_portrait("paddy")
				var is_grace_1: bool = (sim != null and FarmManager.is_grace_period(sim))
				var irr_tag_1: String = IrrigationManager.get_status_text(entity, is_grace_1)
				var irr_narr_1: String = IrrigationManager.get_inspect_narrative_addition(entity, is_grace_1)
				out["title"] = "화성 외곽 둔전 %s" % irr_tag_1
				out["description"] = "성 밖 비옥한 대지에 개간된 백성들의 논.\n봄날 모내기부터 가을 황금빛 벼이삭까지\n농민들이 굵은 땀방울로 농사를 지어\n신도시의 든든한 양식을 길러냅니다." + irr_narr_1
				return out
			"agr_2":
				out["category"] = "facility"
				out["texture"] = get_portrait("daeyu")
				var is_grace_2: bool = (sim != null and FarmManager.is_grace_period(sim))
				var irr_tag_2: String = IrrigationManager.get_status_text(entity, is_grace_2)
				var irr_narr_2: String = IrrigationManager.get_inspect_narrative_addition(entity, is_grace_2)
				out["title"] = "대유둔전 %s" % irr_tag_2
				out["description"] = "정조 대왕께서 만석거를 축조하여 일군 국영 둔전.\n사통팔달 수로로 물길을 대어 가뭄을 모르고\n가을이면 만 석의 황금 벼가 풍성히 일렁이며\n장용영 군량과 국고의 기틀을 세웁니다." + irr_narr_2
				return out
			_:
				var kname: String = get_korean_name(b_code_check, "화성 시설")
				out["title"] = "%s" % kname
				out["texture"] = get_portrait("facility")
				out["description"] = "신시 발전을 위해 정성스레 세워진 시설입니다.\n백성들의 편의와 고을 번영을 위해 운영되며\n도시가 확장될수록 더 큰 활기를 불어넣습니다.\n관리와 장인들의 손길이 닿아 단단히 서 있습니다."
				return out

	# ------------------------------------------------------------ G. 주거 민가 (초가집 / 기와집 / 폐허)
	if kind == "house" or entity.get("is_house", false) or b_code_check.begins_with("res_") or entity.get("zone", "") == "res":
		out["category"] = "house"
		if bool(entity.get("cheonju", false)):
			var is_c_researched: bool = false
			if sim != null and ("tech_tree" in sim) and sim.tech_tree != null:
				is_c_researched = sim.tech_tree.has_researched("boyuron", sim) and sim.tech_tree.has_researched("segi", sim)
			elif sim != null:
				is_c_researched = bool(sim.boyuron and sim.segi_policy)

			if is_c_researched:
				out["title"] = "천주교당 (서학 비공식 집회소)"
				out["texture"] = get_portrait("house_thatched")
				out["description"] = "하늘의 주님을 공경하며 모이는 서학 집회소.\n조정의 포용 정책으로 유학과 기술이 조화되어\n신자들이 안심하고 나라와 임금을 위해 기도하며\n이웃 사랑과 평등의 도리를 실천합니다."
			else:
				out["title"] = "의심스러운 민가 (비밀 서학 집회소)"
				out["texture"] = get_portrait("house_thatched")
				out["description"] = "금지된 사학 서책을 숨겨두고 모이는 비밀 거처.\n보수 유림들의 상소와 관헌의 눈길을 피해\n밤마다 촛불을 켜고 은밀히 교리를 나눕니다.\n순라군의 불심검문에 긴장감이 감돕니다."
			return out

		if bool(entity.get("is_ruined", false)):
			out["title"] = "잡초 우거진 빈집 (폐허)"
			out["texture"] = get_portrait("house_thatched")
			out["description"] = "인구 유출과 곤궁으로 거주민이 떠나버린 빈집입니다.\n기둥 서까래가 주저앉고 마당에 잡초만 무성합니다.\n세율을 감면하고 고을이 다시 번영하여 인구가 늘면\n새 백성이 입주하여 온기 도는 집으로 복원됩니다."
			return out

		var prosper_val: int = int(entity.get("prosper", 0))
		if b_code_check == "res_2" or prosper_val == 2:
			out["title"] = "단정한 살림 기와집 (여염집)"
			out["texture"] = get_portrait("house_tile")
			out["description"] = "정갈하게 기와를 얹은 중인과 상인의 민가.\n안마당에 장독대가 가지런히 놓여 있고\n신도시 번영 속에 평온한 일상을 누립니다.\n화목한 웃음소리가 담장 너머 전해집니다."
			return out
		elif b_code_check == "res_3" or prosper_val >= 3:
			out["title"] = "고급 사대부 기와집"
			out["texture"] = get_portrait("house_tile")
			out["description"] = "솟을대문과 사랑채를 갖춘 사대부 가택.\n서재에서 경전과 실학 서적을 강독하며\n화성 신도시의 문풍과 선비정신을 이끕니다.\n풍류와 학문이 깃든 품격 있는 공간입니다."
			return out

		# 일반 초가집 및 시뮬레이션 민심 연동
		out["title"] = "소박한 서민 초가집"
		out["texture"] = get_portrait("house_thatched")

		var loyalty: int = sim.loyalty if sim else 65
		var is_drought: bool = false
		if sim != null and "disaster_state" in sim:
			is_drought = (sim.disaster_state == "drought")

		if sim != null and (is_drought or loyalty < 45):
			out["description"] = "메마른 가뭄에 장독대가 비어 시름이 찹니다.\n흉년으로 끼니를 잇기 어려워 한숨만 쉬며\n나라에서 구휼미가 나오기만을 기다립니다.\n관아의 정책에 원망의 목소리가 높습니다."
		elif sim != null and loyalty >= 70:
			out["description"] = "지붕 위 박이 풍성하게 익어가는 평화로운 집.\n대유둔전의 소출이 풍족하여 웃음이 넘치고\n임금님의 은덕에 감사하며 잔치를 엽니다.\n새참을 나누는 이웃들의 표정이 밝습니다."
		else:
			out["description"] = "볏짚 지붕을 얹은 백성들의 포근한 보금자리.\n농사와 축성 노역을 마친 일꾼들이 모여\n저녁을 지으며 고단함을 달래는 집입니다.\n정조 대왕의 어진 은덕에 감사하며 삽니다."
		return out

	# ------------------------------------------------------------ H. 야생 동물
	var atype: String = entity.get("type", entity.get("animal_type", ""))
	if entity.get("is_wild", false) or atype in ["tiger", "wolf", "wild_boar", "deer", "crane", "rabbit"]:
		out["category"] = "animal"
		match atype:
			"tiger":
				out["title"] = "팔달산 맹호 (호랑이)"
				out["texture"] = get_portrait("tiger")
				out["description"] = "산속에서 내려와 먹잇감을 노려보며\n조용한 숲길을 매섭게 배회하고 있습니다."
			"deer":
				out["title"] = "야생 꽃사슴"
				out["texture"] = get_portrait("deer")
				out["description"] = "수원천 맑은 물가에서 목을 축이며\n사람들의 발소리에 귀를 쫑긋 세웁니다."
			"wild_boar":
				out["title"] = "산기슭 멧돼지"
				out["texture"] = get_portrait("wild_boar")
				out["description"] = "팔달산 기슭의 덤불을 거칠게 헤집으며\n먹을 만한 나무뿌리를 찾아 헤맵니다."
			"crane":
				out["title"] = "천변 백로 (두루미)"
				out["texture"] = get_portrait("crane")
				out["description"] = "수원천 얕은 여울에 우아하게 내려앉아\n물살 속 작은 물고기를 살피고 있습니다."
			"rabbit":
				out["title"] = "들판 산토끼"
				out["texture"] = get_portrait("rabbit")
				out["description"] = "초원 풀잎 뒤에서 귀를 쫑긋거리며\n이슬 맺힌 풀잎을 오물오물 갉아먹습니다."
			"wolf":
				out["title"] = "야생 승냥이 (늑대)"
				out["texture"] = get_portrait("wolf")
				out["description"] = "바위 뒤에 웅크려 날카로운 눈을 번뜩이며\n무리 지어 산골짜기를 기웃거립니다."
			_:
				out["title"] = "야생 산짐승"
				out["texture"] = get_portrait("deer")
				out["description"] = "화성의 자연 품속에서 평화롭게 뛰놀며\n계절의 변화를 온몸으로 느끼고 있습니다."
		return out

	# ------------------------------------------------------------ I. 일반 보행 NPC (FSM 현재 행동 최우선 매핑!)
	if kind == "npc" or entity.has("speed") or entity.has("state") or entity.has("type") or entity.has("job_type"):
		out["category"] = "npc"
		var n_name: String = str(entity.get("npc_name", "")) if entity.get("npc_name", "") != "" else generate_commoner_name()
		var j_type: int = int(entity.get("job_type", -1))
		var fsm_state: String = str(entity.get("state", entity.get("action", entity.get("task", entity.get("motion", "")))))
		var atype_chk: String = entity.get("type", "")

		# 0) 익수/물놀이/천주교 신자 상황 맞춤형 최우선 매핑
		if atype_chk == "water_play" or fsm_state in ["swimming", "water_play"] or entity.get("is_swimming", false):
			out["title"] = "수원천에서 물놀이 중인 아이"
			out["texture"] = get_portrait("kids")
			out["description"] = "물에 빠진 것 같지만 시원하게 물놀이 중입니다!\n더위를 식히며 멱을 감고 있으니 신경 쓰지 마셔요.\n동무들과 물장구를 치며 노는 것이 제일 즐겁습니다.\n조금만 더 놀다가 해가 지면 집으로 돌아갈게요!"
			return out
		elif atype_chk == "drowning" or fsm_state == "drowning" or entity.get("is_drowning", false):
			out["title"] = "물에 빠져 허우적대는 백성"
			out["texture"] = get_portrait("commoner")
			out["description"] = "어푸푸... 어푸푸! 사람 살려... 살려주시오!\n발을 헛디뎌 깊은 소용돌이에 빠지고 말았사옵니다!\n숨이 차오르고 눈앞이 아득하니 제발 건져주소서!\n동무들아, 밧줄을 던져다오... 어푸푸!"
			return out
		elif atype_chk == "catholic" or entity.get("is_catholic", false):
			var is_cat_researched: bool = false
			if sim != null and ("tech_tree" in sim) and sim.tech_tree != null:
				is_cat_researched = sim.tech_tree.has_researched("boyuron", sim) and sim.tech_tree.has_researched("segi", sim)
			elif sim != null:
				is_cat_researched = bool(sim.boyuron and sim.segi_policy)

			if is_cat_researched:
				out["title"] = "천주교 신자 (서학 유생)"
				out["texture"] = get_portrait("scholar")
				out["description"] = "하늘의 주님께서 우리 성상 임금님을 굽어살피십니다.\n임금님의 덕치와 서양의 바른 학문이 함께 빛나니\n백성 모두가 형제처럼 평등하게 살아갈 것입니다.\n나라와 주상 전하를 위해 매일 기도를 올립니다."
			else:
				out["title"] = "[사학 죄인 체포]"
				out["texture"] = get_portrait("patrol_soldier")
				out["description"] = "금지된 사학을 믿던 신자가 관헌을 보고 도주하다 붙잡혀 관아로 압송되었습니다."
			return out

		# ① NPC FSM 행동 상태 기반 동적 사연 최우선 매핑 (20자 2줄)
		match fsm_state:
			"seokjeon":
				out["title"] = "%s (석전 놀이 중)" % n_name
				out["texture"] = get_portrait("seokjeon")
				out["description"] = "편을 갈라 날렵하게 돌을 던지며\n담력을 기르고 풍년을 기원하는 상민입니다."
				return out
			"ssireum":
				out["title"] = "%s (씨름 겨루기 중)" % n_name
				out["texture"] = get_portrait("ssireum")
				out["description"] = "샅바를 굳게 부여잡고 온 힘을 다해\n들배지기 기술로 상대를 넘기려 합니다."
				return out
			"kite":
				out["title"] = "%s (연날리기 중)" % n_name
				out["texture"] = get_portrait("kite")
				out["description"] = "높고 푸른 가을 하늘 위로 방패연을 띄우며\n액운을 날려 보내고 안녕을 빕니다."
				return out
			"firefighting", "bucket", "volunteer":
				out["title"] = "%s (화재 진압 중)" % n_name
				out["texture"] = get_portrait("firefighting")
				out["description"] = "불길을 잡기 위해 물동이를 번쩍 들고\n매캐한 연기 속을 용감하게 뛰어듭니다."
				return out
			"hunting":
				out["title"] = "%s (맹수 사냥 중)" % n_name
				out["texture"] = get_portrait("hunting")
				out["description"] = "화승총을 조심스레 장전하고 숨을 죽여\n산기슭의 맹수 발자국을 뒤쫓고 있습니다."
				return out
			"playing", "play", "kids_play":
				out["title"] = "%s (골목 놀이 중)" % n_name
				out["texture"] = get_portrait("playing")
				out["description"] = "골목 어귀에서 동무들과 옹기종기 모여\n제기차기와 팽이치기 놀이에 푹 빠졌습니다."
				return out
			"washing", "wash":
				out["title"] = "%s (수원천 빨래 중)" % n_name
				out["texture"] = get_portrait("washing")
				out["description"] = "방망이로 묵은 때를 시원하게 두드리며\n흐르는 맑은 수원천 물에 무명을 헹굽니다."
				return out
			"fishing", "fish":
				out["title"] = "%s (물가 낚시 중)" % n_name
				out["texture"] = get_portrait("fishing")
				out["description"] = "잔잔한 물가에 낚싯대를 드리우고 앉아\n세월을 낚듯 여유로운 한때를 즐깁니다."
				return out
			"cheering", "procession":
				out["title"] = "%s (어가 환호 중)" % n_name
				out["texture"] = get_portrait("cheering")
				out["description"] = "정조 대왕의 어가를 보며 만세를 부르고\n성군의 은혜에 감격하여 눈물을 흘립니다."
				return out
			"training", "drill":
				out["title"] = "%s (군사 훈련 중)" % n_name
				out["texture"] = get_portrait("training")
				out["description"] = "지휘관의 구령에 맞춰 당파와 환도를 휘두르며\n일사불란하게 진법 훈련에 몰두합니다."
				return out

		# ② 전문 직업군 6종 매핑 (20자 2줄)
		if j_type == 4 or atype == "bobusang":
			out["title"] = n_name
			out["texture"] = get_portrait("bobusang")
			out["description"] = "팔도의 특산품을 지고 성문을 넘어\n저잣거리 난전으로 바삐 이동합니다."
			return out
		elif j_type == 5 or atype == "monk_soldier":
			out["title"] = n_name
			out["texture"] = get_portrait("monk_soldier")
			out["description"] = "정조 대왕의 효심 깃든 용주사를 받들며\n목탁 대신 창을 쥐고 성곽을 순시합니다."
			return out
		elif j_type == 1 or atype in ["jungin", "physician"]:
			out["title"] = n_name
			out["texture"] = get_portrait("jungin")
			out["description"] = "침통과 약첩을 챙겨 위급한 환자를 위해\n민가의 좁은 골목길을 빠르게 걸어갑니다."
			return out
		elif j_type == 2 or atype in ["ajeon", "ajeoun"]:
			out["title"] = n_name
			out["texture"] = get_portrait("ajeon")
			out["description"] = "관아의 명을 적은 공문을 품에 넣고\n둔전 관리관을 만나러 길을 서두릅니다."
			return out
		elif j_type == 3 or atype in ["artisan", "artisan_master"]:
			out["title"] = n_name
			out["texture"] = get_portrait("artisan")
			out["description"] = "먹줄과 망치를 챙겨 성벽 보수를 위해\n채석장과 공방 채를 바쁘게 오갑니다."
			return out
		elif j_type == 6 or atype == "butcher":
			out["title"] = n_name
			out["texture"] = get_portrait("butcher")
			out["description"] = "손질한 짐승 가죽과 고기를 짊어지고\n저잣거리 피혁전으로 발길을 재촉합니다."
			return out

		# ②-2 화면에 그려진 실제 모습(성별·신분·옷)과 같은 사람으로 보여 준다
		var spr_kind := npc_sprite_kind(entity)
		if spr_kind != "" and NPC_PROFILES.has(spr_kind):
			apply_npc_profile(out, NPC_PROFILES[spr_kind], entity)
			return out

		# ③ 일반 직업군 fallback 매핑 (20자 2줄)
		match atype:
			"merchant":
				out["title"] = "저잣거리 상인 %s" % n_name
				out["texture"] = get_portrait("merchant")
				out["description"] = "한양에서 떼어온 비단을 펼치며\n장터 손님들과 흥정을 벌이고 있습니다."
			"patrol_soldier", "guard":
				out["title"] = "장용영 순라군 %s" % n_name
				out["texture"] = get_portrait("patrol_soldier")
				out["description"] = "성벽 주변의 거동 수상자를 감시하며\n창을 굳게 쥐고 순찰에 집중합니다."
			"farmer":
				out["title"] = "대유둔전 농민 %s" % n_name
				out["texture"] = get_portrait("farmer")
				out["description"] = "호미를 들고 논두렁의 잡초를 뽑으며\n가을날의 풍성한 수확을 기원합니다."
			"scholar", "yusaeng":
				out["title"] = "수원향교 유생 %s" % n_name
				out["texture"] = get_portrait("scholar")
				out["description"] = "논어 책을 옆에 끼고 발걸음을 옮기며\n성리학의 깊은 도리를 되새깁니다."
			"artisan", "mason", "carpenter", "artisan_master":
				out["title"] = "축성 장인 %s" % n_name
				out["texture"] = get_portrait("artisan")
				out["description"] = "먹줄을 퉁기고 대패질을 부지런히 놀리며\n성곽에 쓸 튼튼한 목재를 가다듬습니다."
			"woodcutter":
				out["title"] = "나무꾼 %s" % n_name
				out["texture"] = get_portrait("woodcutter")
				out["description"] = "지게 가득 마른 장작을 짊어지고\n휘파람을 불며 저잣거리로 향합니다."
			"hunter", "saposu":
				out["title"] = "산포수 %s" % n_name
				out["texture"] = get_portrait("hunter")
				out["description"] = "화승총을 어깨에 메고 산세를 살피며\n마을을 위협하는 맹수를 추적합니다."
			_:
				out["title"] = "화성 백성 %s" % n_name
				out["texture"] = get_portrait("commoner")
				out["description"] = "정조 대왕의 신시에서 삶의 터전을 일구며\n평화로운 하루를 부지런히 보냅니다."
		return out

	# ------------------------------------------------------------ I-2. 대유둔전 경작 구역 (zone_agr)
	if entity.get("zone", "") == "agr":
		out["category"] = "facility"
		out["texture"] = get_portrait("paddy")
		var is_grace_z: bool = (sim != null and FarmManager.is_grace_period(sim))
		var irr_tag_z: String = IrrigationManager.get_status_text(entity, is_grace_z)
		var irr_narr_z: String = IrrigationManager.get_inspect_narrative_addition(entity, is_grace_z)
		out["title"] = "대유둔전 개간지 %s" % irr_tag_z
		out["description"] = "성 밖 외곽에 구획된 대유둔전 개간지입니다.\n만석거와 저수지의 맑은 물길을 끌어들여\n비옥한 농토로 가꾸어 나갈 풍요의 터전입니다.\n도로와 성문이 연결되면 군량의 보고가 됩니다." + irr_narr_z
		return out

	# ------------------------------------------------------------ J. 미개발 자연 지형
	var terr: String = entity.get("terrain", "plain")
	out["category"] = "terrain"
	match terr:
		"mountain":
			out["title"] = "팔달산 산악 지대"
			out["texture"] = get_portrait("mountain")
			out["description"] = "우뚝 솟은 팔달산의 울창한 수목과 기암괴석.\n화성 서쪽을 감싸 안는 천혜의 자연 방벽으로\n산 정상 서장대에서 신시 전체를 조망할 수 있습니다.\n성곽 축성에 쓰일 단단한 화강암의 보고이기도 합니다."
		"water":
			out["title"] = "수원천 맑은 물줄기"
			out["texture"] = get_portrait("river")
			out["description"] = "광교산에서 발원하여 도성을 가로지르는 맑은 내.\n아낙들이 빨래하고 아이들이 멱감는 정겨운 풍경과\n북수문 화홍문의 일곱 홍예를 적시며 흘러갑니다.\n견고한 석축 제방이 쌓여 홍수 걱정 없이 흐릅니다."
		"forest":
			out["title"] = "울창한 소나무 숲"
			out["texture"] = get_portrait("forest")
			out["description"] = "솔향기 그윽한 조선 고유의 소나무 군락지.\n사계절 푸른 절개로 산세를 든든히 지키며\n꽃사슴과 산토끼가 평화롭게 서식하는 숲입니다.\n벌채를 엄격히 금하여 푸르름을 보존하고 있습니다."
		"burned_wasteland":
			out["title"] = "화재 전소지 (황무지)"
			out["texture"] = get_portrait("burned")
			out["description"] = "화마가 휩쓸고 지나간 안타까운 잿더미 터전.\n까맣게 그을린 목재와 흩어진 기와 잔해가 남아\n백성들의 땀방울 어린 복구의 손길을 기다립니다.\n철거 도구로 잔해를 치운 뒤 새 역사를 세워야 합니다."
		_:
			out["title"] = "화성 고을의 너른 벌판"
			out["texture"] = get_portrait("plain")
			out["description"] = "비옥한 황토와 따스한 햇살이 내리쬐는 들판.\n도로를 닦고 둔전을 개간하기에 더없이 좋은 터전으로\n새로운 백성들이 정착할 날을 기다리고 있습니다.\n장차 조선 제일의 개혁 신시로 피어날 땅입니다."
	return out
