@tool
extends Node
class_name CharacterPixelArtist

## [48x48 조선시대 45도 아이소메트릭 고품질 픽셀아트 캐릭터 엔진]
## 레퍼런스(BOBUSANG SPRITE SHEET 48x48) 스타일 100% 반영:
## - 45도 대각선 4방향 (DOWN_LEFT, DOWN_RIGHT, UP_LEFT, UP_RIGHT)
## - 2프레임 유기적 보행 (WALK_1, WALK_2)
## - 컴팩트한 28~30px 키 비율 (타일맵과 완벽한 스케일 조화)
## - V넥 사선 동정, 둥근 갓 챙, 옷고름, 4단계 셀 셰이딩, 1px 다크 외곽선

const P = preload("res://scripts/rendering/JoseonPalette.gd")
const CharDef = preload("res://scripts/resources/JoseonCharDef.gd")

const WIDTH: int = 48
const HEIGHT: int = 48

## 26인 네임드 마스터 프리셋 정의
const NAMED_PRESETS: Dictionary = {
	"named_jeongjo": {
		"name": "정조 (이산)", "role": "국왕",
		"headgear": CharDef.HeadgearType.IKSEONGWAN, "h_pal": "black",
		"skin": "fair", "beard": CharDef.BeardType.NONE, "beard_col": Color("#222222"),
		"garment": "royal_red", "has_dragon": true, "has_rank": false,
		"prop": "royal_sword"
	},
	"named_chae_jegong": {
		"name": "채제공", "role": "영의정",
		"headgear": CharDef.HeadgearType.OSAMO_HIGH, "h_pal": "black",
		"skin": "elder", "beard": CharDef.BeardType.THICK_WHITE, "beard_col": Color("#f4f0ea"),
		"garment": "officer_red", "has_dragon": false, "has_rank": true,
		"prop": "hol"
	},
	"named_jeong_yakyong": {
		"name": "정약용", "role": "실학자",
		"headgear": CharDef.HeadgearType.HEUNGLIP, "h_pal": "black",
		"skin": "fair", "beard": CharDef.BeardType.THIN_MUSTACHE, "beard_col": Color("#222222"),
		"garment": "scholar_teal", "has_dragon": false, "has_rank": false,
		"prop": "blueprint"
	},
	"named_jo_simtae": {
		"name": "조심태", "role": "화성유수",
		"headgear": CharDef.HeadgearType.JEONRIP_RED, "h_pal": "red_felt",
		"skin": "worker", "beard": CharDef.BeardType.SHORT_BEARD, "beard_col": Color("#25201b"),
		"garment": "military_navy", "has_dragon": false, "has_rank": false,
		"prop": "baton"
	},
	"named_park_jega": {
		"name": "박제가", "role": "북학파 실학자",
		"headgear": CharDef.HeadgearType.HEUNGLIP, "h_pal": "black",
		"skin": "normal", "beard": CharDef.BeardType.THIN_MUSTACHE, "beard_col": Color("#222222"),
		"garment": "scholar_navy", "has_dragon": false, "has_rank": false,
		"prop": "book_pack"
	},
	"named_yi_deokmu": {
		"name": "이덕무", "role": "규장각 검서관",
		"headgear": CharDef.HeadgearType.YUGEON, "h_pal": "black",
		"skin": "fair", "beard": CharDef.BeardType.NONE, "beard_col": Color("#222222"),
		"garment": "scholar_white", "has_dragon": false, "has_rank": false,
		"prop": "books"
	},
	"named_yu_deukgong": {
		"name": "유득공", "role": "역사학자",
		"headgear": CharDef.HeadgearType.HEUNGLIP, "h_pal": "black",
		"skin": "normal", "beard": CharDef.BeardType.THIN_MUSTACHE, "beard_col": Color("#222222"),
		"garment": "scholar_sage", "has_dragon": false, "has_rank": false,
		"prop": "map"
	},
	"named_seo_yugu": {
		"name": "서유구", "role": "농학자",
		"headgear": CharDef.HeadgearType.JEONGJAGWAN, "h_pal": "black",
		"skin": "normal", "beard": CharDef.BeardType.MEDIUM_BEARD, "beard_col": Color("#333333"),
		"garment": "scholar_amber", "has_dragon": false, "has_rank": false,
		"prop": "rice"
	},
	"named_park_jiwon": {
		"name": "박지원", "role": "북학파 대가",
		"headgear": CharDef.HeadgearType.HEUNGLIP, "h_pal": "black",
		"skin": "weathered", "beard": CharDef.BeardType.FULL_BEARD, "beard_col": Color("#26201b"),
		"garment": "scholar_brown", "has_dragon": false, "has_rank": false,
		"prop": "pipe"
	},
	"named_hong_daeyong": {
		"name": "홍대용", "role": "천문학자",
		"headgear": CharDef.HeadgearType.JEONGJAGWAN, "h_pal": "black",
		"skin": "fair", "beard": CharDef.BeardType.THIN_MUSTACHE, "beard_col": Color("#222222"),
		"garment": "scholar_indigo", "has_dragon": false, "has_rank": false,
		"prop": "sphere"
	},
	"named_yi_gahwan": {
		"name": "이가환", "role": "공조판서",
		"headgear": CharDef.HeadgearType.OSAMO, "h_pal": "black",
		"skin": "elder", "beard": CharDef.BeardType.MEDIUM_BEARD, "beard_col": Color("#333333"),
		"garment": "officer_red", "has_dragon": false, "has_rank": true,
		"prop": "ruler"
	},
	"named_jeong_beomjo": {
		"name": "정범조", "role": "대제학",
		"headgear": CharDef.HeadgearType.OSAMO, "h_pal": "black",
		"skin": "elder", "beard": CharDef.BeardType.THICK_WHITE, "beard_col": Color("#e8e2d8"),
		"garment": "officer_blue", "has_dragon": false, "has_rank": true,
		"prop": "scroll"
	},
	"named_kim_hongdo": {
		"name": "김홍도", "role": "도화서 화원",
		"headgear": CharDef.HeadgearType.HEUNGLIP, "h_pal": "black",
		"skin": "normal", "beard": CharDef.BeardType.THIN_MUSTACHE, "beard_col": Color("#222222"),
		"garment": "painter_cream", "has_dragon": false, "has_rank": false,
		"prop": "brush"
	},
	"named_kim_jeonghee": {
		"name": "김정희", "role": "추사 서예가",
		"headgear": CharDef.HeadgearType.JEONGJAGWAN, "h_pal": "black",
		"skin": "fair", "beard": CharDef.BeardType.NONE, "beard_col": Color("#222222"),
		"garment": "scholar_pure", "has_dragon": false, "has_rank": false,
		"prop": "big_brush"
	},
	"named_yu_hanji": {
		"name": "유한지", "role": "예서 명필",
		"headgear": CharDef.HeadgearType.HEUNGLIP, "h_pal": "black",
		"skin": "elder", "beard": CharDef.BeardType.THICK_WHITE, "beard_col": Color("#ece8e1"),
		"garment": "scholar_purple", "has_dragon": false, "has_rank": false,
		"prop": "scroll"
	},
	"named_sim_hwanji": {
		"name": "심환지", "role": "벽파 영수",
		"headgear": CharDef.HeadgearType.OSAMO, "h_pal": "black",
		"skin": "elder", "beard": CharDef.BeardType.LONG_BLACK, "beard_col": Color("#181412"),
		"garment": "officer_dark", "has_dragon": false, "has_rank": true,
		"prop": "secret"
	},
	"named_hwang_inhan": {
		"name": "홍인한", "role": "권신 외척",
		"headgear": CharDef.HeadgearType.OSAMO, "h_pal": "black",
		"skin": "weathered", "beard": CharDef.BeardType.MEDIUM_BEARD, "beard_col": Color("#222222"),
		"garment": "officer_navy", "has_dragon": false, "has_rank": true,
		"prop": "scroll"
	},
	"named_kim_josun": {
		"name": "김조순", "role": "시파 중신",
		"headgear": CharDef.HeadgearType.OSAMO, "h_pal": "black",
		"skin": "fair", "beard": CharDef.BeardType.NONE, "beard_col": Color("#222222"),
		"garment": "officer_teal", "has_dragon": false, "has_rank": true,
		"prop": "jade"
	},
	"named_yi_gigyeong": {
		"name": "이기경", "role": "보수 유생",
		"headgear": CharDef.HeadgearType.OSAMO, "h_pal": "black",
		"skin": "normal", "beard": CharDef.BeardType.THIN_MUSTACHE, "beard_col": Color("#222222"),
		"garment": "officer_dark", "has_dragon": false, "has_rank": false,
		"prop": "scroll"
	},
	"named_hong_gukyeong": {
		"name": "홍국영", "role": "세도 권신",
		"headgear": CharDef.HeadgearType.HEUNGLIP, "h_pal": "black",
		"skin": "fair", "beard": CharDef.BeardType.THIN_MUSTACHE, "beard_col": Color("#222222"),
		"garment": "noble_violet", "has_dragon": false, "has_rank": false,
		"prop": "seal"
	},
	"named_baek_dongsu": {
		"name": "백동수", "role": "무예 총관",
		"headgear": CharDef.HeadgearType.JEONRIP_RED, "h_pal": "red_felt",
		"skin": "worker", "beard": CharDef.BeardType.SHORT_BEARD, "beard_col": Color("#1e1a17"),
		"garment": "armor_blue", "has_dragon": false, "has_rank": false,
		"prop": "sword"
	},
	"named_gu_seon_bok": {
		"name": "구선복", "role": "훈련대장",
		"headgear": CharDef.HeadgearType.IRON_HELMET, "h_pal": "iron",
		"skin": "weathered", "beard": CharDef.BeardType.FULL_BEARD, "beard_col": Color("#181412"),
		"garment": "armor_iron", "has_dragon": false, "has_rank": false,
		"prop": "glaive"
	},
	"named_kim_bau": {
		"name": "김바우", "role": "수석 석공 명장",
		"headgear": CharDef.HeadgearType.HEADBAND, "h_pal": "straw",
		"skin": "worker", "beard": CharDef.BeardType.STUBBLE, "beard_col": Color("#333333"),
		"garment": "artisan_earth", "has_dragon": false, "has_rank": false,
		"prop": "hammer"
	},
	"named_yi_seonggil": {
		"name": "이성길", "role": "도편수",
		"headgear": CharDef.HeadgearType.PAERAENGI, "h_pal": "straw",
		"skin": "worker", "beard": CharDef.BeardType.SHORT_BEARD, "beard_col": Color("#28221c"),
		"garment": "carpenter_blue", "has_dragon": false, "has_rank": false,
		"prop": "saw"
	},
	"named_musoe": {
		"name": "무쇠", "role": "군수 가죽공",
		"headgear": CharDef.HeadgearType.HEADBAND, "h_pal": "black",
		"skin": "weathered", "beard": CharDef.BeardType.SHORT_BEARD, "beard_col": Color("#181412"),
		"garment": "leather_dark", "has_dragon": false, "has_rank": false,
		"prop": "knife"
	},
	"named_kim_pangwan": {
		"name": "김판관", "role": "수원부 판관",
		"headgear": CharDef.HeadgearType.OSAMO, "h_pal": "black",
		"skin": "fair", "beard": CharDef.BeardType.THIN_MUSTACHE, "beard_col": Color("#222222"),
		"garment": "officer_azure", "has_dragon": false, "has_rank": true,
		"prop": "ledger"
	}
}

## 일반 백성 15종 프리셋
const GENERIC_PRESETS: Dictionary = {
	"npc_yangban_scholar": {
		"headgear": CharDef.HeadgearType.HEUNGLIP, "h_pal": "black",
		"skin": "normal", "beard": CharDef.BeardType.THIN_MUSTACHE, "beard_col": Color("#222222"),
		"garment": "scholar_teal", "has_dragon": false, "has_rank": false, "prop": "fan"
	},
	"npc_yangban_lady": {
		"headgear": CharDef.HeadgearType.GACHE, "h_pal": "black",
		"skin": "fair", "beard": CharDef.BeardType.NONE, "beard_col": Color.BLACK,
		"garment": "lady_pastel", "has_dragon": false, "has_rank": false, "prop": "none"
	},
	"npc_hallyang": {
		"headgear": CharDef.HeadgearType.HEUNGLIP, "h_pal": "black",
		"skin": "fair", "beard": CharDef.BeardType.NONE, "beard_col": Color.BLACK,
		"garment": "scholar_purple", "has_dragon": false, "has_rank": false, "prop": "fan"
	},
	"npc_gisaeng": {
		"headgear": CharDef.HeadgearType.GACHE, "h_pal": "black",
		"skin": "fair", "beard": CharDef.BeardType.NONE, "beard_col": Color.BLACK,
		"garment": "gisaeng_vivid", "has_dragon": false, "has_rank": false, "prop": "none"
	},
	"npc_farmer": {
		"headgear": CharDef.HeadgearType.SATGAT, "h_pal": "straw",
		"skin": "worker", "beard": CharDef.BeardType.STUBBLE, "beard_col": Color("#3a3028"),
		"garment": "farmer_rough", "has_dragon": false, "has_rank": false, "prop": "none"
	},
	"npc_peasant_woman": {
		"headgear": CharDef.HeadgearType.SCARF, "h_pal": "straw",
		"skin": "normal", "beard": CharDef.BeardType.NONE, "beard_col": Color.BLACK,
		"garment": "commoner_hemp", "has_dragon": false, "has_rank": false, "prop": "none"
	},
	"npc_bobusang": {
		"headgear": CharDef.HeadgearType.PAERAENGI, "h_pal": "straw",
		"skin": "worker", "beard": CharDef.BeardType.SHORT_BEARD, "beard_col": Color("#28221c"),
		"garment": "bobusang_blue", "has_dragon": false, "has_rank": false, "prop": "jige"
	},
	"npc_artisan_blacksmith": {
		"headgear": CharDef.HeadgearType.HEADBAND, "h_pal": "straw",
		"skin": "weathered", "beard": CharDef.BeardType.STUBBLE, "beard_col": Color("#201a14"),
		"garment": "artisan_earth", "has_dragon": false, "has_rank": false, "prop": "hammer"
	},
	"npc_cheonmin": {
		"headgear": CharDef.HeadgearType.TOPKNOT, "h_pal": "black",
		"skin": "weathered", "beard": CharDef.BeardType.NONE, "beard_col": Color.BLACK,
		"garment": "commoner_hemp", "has_dragon": false, "has_rank": false, "prop": "none"
	},
	"npc_child_boy": {
		"headgear": CharDef.HeadgearType.NONE, "h_pal": "black",
		"skin": "fair", "beard": CharDef.BeardType.NONE, "beard_col": Color.BLACK,
		"garment": "scholar_teal", "has_dragon": false, "has_rank": false, "prop": "none"
	},
	"npc_child_girl": {
		"headgear": CharDef.HeadgearType.NONE, "h_pal": "black",
		"skin": "fair", "beard": CharDef.BeardType.NONE, "beard_col": Color.BLACK,
		"garment": "lady_pastel", "has_dragon": false, "has_rank": false, "prop": "none"
	},
	"npc_patrol": {
		"headgear": CharDef.HeadgearType.JEONRIP, "h_pal": "black",
		"skin": "normal", "beard": CharDef.BeardType.THIN_MUSTACHE, "beard_col": Color("#222222"),
		"garment": "patrol_blue", "has_dragon": false, "has_rank": false, "prop": "baton"
	},
	"npc_soldier": {
		"headgear": CharDef.HeadgearType.JEONRIP, "h_pal": "black",
		"skin": "worker", "beard": CharDef.BeardType.SHORT_BEARD, "beard_col": Color("#222222"),
		"garment": "soldier_guard", "has_dragon": false, "has_rank": false, "prop": "sword"
	},
	"npc_thief": {
		"headgear": CharDef.HeadgearType.HEADBAND, "h_pal": "black",
		"skin": "weathered", "beard": CharDef.BeardType.STUBBLE, "beard_col": Color("#1a1512"),
		"garment": "officer_dark", "has_dragon": false, "has_rank": false, "prop": "none"
	},
	"npc_brawler": {
		"headgear": CharDef.HeadgearType.TOPKNOT, "h_pal": "black",
		"skin": "weathered", "beard": CharDef.BeardType.SHORT_BEARD, "beard_col": Color("#1a1512"),
		"garment": "artisan_earth", "has_dragon": false, "has_rank": false, "prop": "none"
	},
	"npc_jeongisu": {
		"headgear": CharDef.HeadgearType.HEUNGLIP, "h_pal": "black",
		"skin": "fair", "beard": CharDef.BeardType.THIN_MUSTACHE, "beard_col": Color("#222222"),
		"garment": "scholar_white", "has_dragon": false, "has_rank": false, "prop": "book_fan"
	},
	"npc_fisherman": {
		"headgear": CharDef.HeadgearType.SATGAT, "h_pal": "straw",
		"skin": "weathered", "beard": CharDef.BeardType.STUBBLE, "beard_col": Color("#3a3028"),
		"garment": "fisherman_cloth", "has_dragon": false, "has_rank": false, "prop": "fishing_rod"
	},
	"npc_kite_flyer": {
		"headgear": CharDef.HeadgearType.HEADBAND, "h_pal": "gold",
		"skin": "fair", "beard": CharDef.BeardType.NONE, "beard_col": Color.BLACK,
		"garment": "kite_boy", "has_dragon": false, "has_rank": false, "prop": "kite_spool"
	},
	"npc_ssireum": {
		"headgear": CharDef.HeadgearType.TOPKNOT, "h_pal": "black",
		"skin": "weathered", "beard": CharDef.BeardType.STUBBLE, "beard_col": Color("#1a1512"),
		"garment": "ssireum_satba", "has_dragon": false, "has_rank": false, "prop": "satba"
	},
	"npc_taekkyeon": {
		"headgear": CharDef.HeadgearType.HEADBAND, "h_pal": "straw",
		"skin": "worker", "beard": CharDef.BeardType.NONE, "beard_col": Color.BLACK,
		"garment": "taekkyeon_white", "has_dragon": false, "has_rank": false, "prop": "taekkyeon_belt"
	}
}

## 을묘원행 어가행렬 5종 프리셋
const PARADE_PRESETS: Dictionary = {
	"parade_king": {
		"headgear": CharDef.HeadgearType.JEONRIP_RED, "h_pal": "red_felt",
		"skin": "fair", "beard": CharDef.BeardType.NONE, "beard_col": Color("#222222"),
		"garment": "royal_red", "has_dragon": true, "has_rank": false, "prop": "royal_sword"
	},
	"parade_royal_carriage": {
		"headgear": CharDef.HeadgearType.GACHE, "h_pal": "black",
		"skin": "fair", "beard": CharDef.BeardType.NONE, "beard_col": Color.BLACK,
		"garment": "lady_pastel", "has_dragon": false, "has_rank": false, "prop": "none"
	},
	"parade_cavalry": {
		"headgear": CharDef.HeadgearType.JEONRIP, "h_pal": "black",
		"skin": "worker", "beard": CharDef.BeardType.SHORT_BEARD, "beard_col": Color("#222222"),
		"garment": "armor_blue", "has_dragon": false, "has_rank": false, "prop": "sword"
	},
	"parade_musician": {
		"headgear": CharDef.HeadgearType.JEONRIP, "h_pal": "straw",
		"skin": "normal", "beard": CharDef.BeardType.NONE, "beard_col": Color.BLACK,
		"garment": "scholar_amber", "has_dragon": false, "has_rank": false, "prop": "none"
	},
	"parade_flag_bearer": {
		"headgear": CharDef.HeadgearType.JEONRIP, "h_pal": "black",
		"skin": "worker", "beard": CharDef.BeardType.NONE, "beard_col": Color.BLACK,
		"garment": "soldier_guard", "has_dragon": false, "has_rank": false, "prop": "baton"
	}
}

# ==============================================================================
# 45도 아이소메트릭 스프라이트 시트 및 단일 프레임 생성기
# ==============================================================================

## 45도 4방향 x 2프레임 = 96x192 스프라이트 시트 생성
## (가로 96px: 48 * 2프레임, 세로 192px: 48 * 4방향)
static func create_full_isometric_sheet(char_spec: Dictionary) -> Image:
	var sheet := Image.create(WIDTH * 2, HEIGHT * 4, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))

	var dirs: Array[int] = [
		CharDef.IsoDir.DOWN_LEFT,
		CharDef.IsoDir.DOWN_RIGHT,
		CharDef.IsoDir.UP_LEFT,
		CharDef.IsoDir.UP_RIGHT
	]
	var phases: Array[int] = [
		CharDef.AnimPhase.WALK_FRAME_1,
		CharDef.AnimPhase.WALK_FRAME_2
	]

	for y in range(dirs.size()):
		for x in range(phases.size()):
			var frame_img: Image = render_isometric_frame(char_spec, dirs[y], phases[x])
			sheet.blit_rect(frame_img, Rect2i(0, 0, WIDTH, HEIGHT), Vector2i(x * WIDTH, y * HEIGHT))

	return sheet

## 단일 48x48 45도 아이소메트릭 프레임 렌더링
static func render_isometric_frame(char_spec: Dictionary, dir: int, phase: int) -> Image:
	var img := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var skin_key: String = String(char_spec.get("skin", "normal"))
	var skin_pal: Dictionary = P.SKIN_TONES.get(skin_key, P.SKIN_TONES["normal"])

	var g_key: String = String(char_spec.get("garment", "scholar_teal"))
	var g_pal: Dictionary = P.GARMENTS.get(g_key, P.GARMENTS["scholar_teal"])

	var h_type: int = int(char_spec.get("headgear", CharDef.HeadgearType.HEUNGLIP))
	var h_key: String = String(char_spec.get("h_pal", "black"))
	var h_pal: Dictionary = P.HEADGEAR_COLORS.get(h_key, P.HEADGEAR_COLORS["black"])

	var beard_type: int = int(char_spec.get("beard", CharDef.BeardType.NONE))
	var beard_col: Color = Color(char_spec.get("beard_col", Color("#222222")))

	var has_dragon: bool = bool(char_spec.get("has_dragon", false))
	var has_rank: bool = bool(char_spec.get("has_rank", false))
	var prop: String = String(char_spec.get("prop", "none"))

	# 1. 45도 투영 2:1 타원 그림자 (24, 42 중심)
	_draw_isometric_shadow(img, Vector2i(24, 42))

	# 2. 등 뒤 소품 (등짐/지게/쇠메/낚싯대/방패연 등 - 뒷방향일 땐 나중에, 앞방향일 땐 등 뒤에 먼저)
	var is_back: bool = (dir == CharDef.IsoDir.UP_LEFT or dir == CharDef.IsoDir.UP_RIGHT)
	if not is_back and prop in ["jige", "hammer", "books", "fishing_rod", "kite_spool"]:
		_draw_prop_behind(img, dir, phase, prop)

	# 3. 하체 & 발 (바지, 대님, 짚신/목화)
	_draw_iso_feet_and_legs(img, dir, phase, g_pal)

	# 4. 상체 의복 (도포/단령 몸통, V넥 동정, 옷고름, 주름)
	_draw_iso_torso(img, dir, phase, g_pal, has_dragon, has_rank)

	# 5. 소매 및 손
	_draw_iso_arms(img, dir, phase, g_pal, skin_pal)

	# 6. 얼굴 & 귀 & 이목구비
	_draw_iso_face(img, dir, skin_pal)

	# 7. 수염
	if beard_type != CharDef.BeardType.NONE and not is_back:
		_draw_iso_beard(img, dir, beard_type, beard_col)

	# 8. 관모 (갓/오사모/익선관/전립 등)
	_draw_iso_headgear(img, dir, h_type, h_pal)

	# 9. 앞쪽 소품 (등짐이 뒤를 향할 때, 또는 손에 든 소품)
	if is_back and prop in ["jige", "hammer", "books"]:
		_draw_prop_behind(img, dir, phase, prop)
	elif is_back and prop in ["fishing_rod", "kite_spool"]:
		_draw_prop_behind(img, dir, phase, prop)
		_draw_prop_front(img, dir, phase, prop)
	elif prop not in ["none", ""]:
		_draw_prop_front(img, dir, phase, prop)

	# 10. ★ 1px 다크 차콜 외곽선 (#1E1B18) 바깥쪽 둘러치기 ★
	_apply_crisp_1px_dark_outline(img)

	return img

# ==============================================================================
# 유기적인 45도 곡선 픽셀 렌더러 서브루틴
# ==============================================================================

## 1. 2:1 타원 그림자 (발밑 투영)
static func _draw_isometric_shadow(img: Image, center: Vector2i) -> void:
	var rx: int = 9
	var ry: int = 4
	for dy in range(-ry, ry + 1):
		for dx in range(-rx, rx + 1):
			var norm: float = (float(dx * dx) / float(rx * rx)) + (float(dy * dy) / float(ry * ry))
			if norm <= 1.0:
				var px: int = center.x + dx
				var py: int = center.y + dy
				if px >= 0 and px < WIDTH and py >= 0 and py < HEIGHT:
					var cur: Color = img.get_pixel(px, py)
					var alpha_fade: float = (1.0 - norm * 0.4) * 0.35
					img.set_pixel(px, py, cur.blend(Color(0.0, 0.0, 0.0, alpha_fade)))

## 2. 하체 및 발 (바지/도포 하단 + 대님 + 버선코)
static func _draw_iso_feet_and_legs(img: Image, dir: int, phase: int, g_pal: Dictionary) -> void:
	var is_left: bool = (dir == CharDef.IsoDir.DOWN_LEFT or dir == CharDef.IsoDir.UP_LEFT)
	var is_back: bool = (dir == CharDef.IsoDir.UP_LEFT or dir == CharDef.IsoDir.UP_RIGHT)

	# 보행에 따른 발 오프셋
	var step: int = 1 if phase == CharDef.AnimPhase.WALK_FRAME_1 else -1

	# 도포 하단 치맛자락 (y=32 ~ 38, A라인 곡선)
	for y in range(32, 38):
		var span: int = int(float(y - 32) * 0.6) + 5
		for x in range(24 - span, 25 + span):
			var t: float = float(x - (24 - span)) / float(span * 2)
			var col: Color = g_pal["mid"]
			if is_left:
				col = g_pal["hl"] if t < 0.35 else (g_pal["mid"] if t < 0.75 else g_pal["sh"])
			else:
				col = g_pal["sh"] if t < 0.3 else (g_pal["mid"] if t < 0.7 else g_pal["hl"])
			if is_back:
				col = col.blend(g_pal["sh"])
			img.set_pixel(x, y, col)

	# 도포 주름 세로선
	img.set_pixel(22, 34, g_pal["deep"])
	img.set_pixel(22, 35, g_pal["deep"])
	img.set_pixel(26, 35, g_pal["sh"])
	img.set_pixel(26, 36, g_pal["deep"])

	# 바지 대님과 버선/신발 (y=38 ~ 41)
	var shoe_col: Color = Color("#f4eee1") # 백색 버선
	var sole_col: Color = Color("#8a6e4b") # 미투리/짚신 바닥

	# 왼발
	var lx: int = 21 - (step if is_left else 0)
	var ly: int = 39 + (0 if phase == 0 else 1)
	img.set_pixel(lx, ly, shoe_col)
	img.set_pixel(lx + 1, ly, shoe_col)
	img.set_pixel(lx - 1, ly + 1, sole_col)
	img.set_pixel(lx, ly + 1, sole_col)

	# 오른발
	var rx: int = 26 + (step if not is_left else 0)
	var ry: int = 39 + (1 if phase == 0 else 0)
	img.set_pixel(rx, ry, shoe_col)
	img.set_pixel(rx + 1, ry, shoe_col)
	img.set_pixel(rx, ry + 1, sole_col)
	img.set_pixel(rx + 1, ry + 1, sole_col)

## 3. 상체 의복 (V넥 동정, 옷고름, 흉배, 용보, 4단계 주름)
static func _draw_iso_torso(img: Image, dir: int, _phase: int, g_pal: Dictionary, has_dragon: bool, has_rank: bool) -> void:
	var is_left: bool = (dir == CharDef.IsoDir.DOWN_LEFT or dir == CharDef.IsoDir.UP_LEFT)
	var is_back: bool = (dir == CharDef.IsoDir.UP_LEFT or dir == CharDef.IsoDir.UP_RIGHT)

	# 가슴 및 허리 몸통 (y=22 ~ 32, 폭 약 12~14px)
	for y in range(22, 33):
		var w: int = 5 + int(float(y - 22) * 0.25)
		for x in range(24 - w, 25 + w):
			var norm: float = float(x - (24 - w)) / float(w * 2)
			var c: Color = g_pal["mid"]
			if is_left:
				c = g_pal["hl"] if norm < 0.4 else (g_pal["mid"] if norm < 0.8 else g_pal["sh"])
			else:
				c = g_pal["sh"] if norm < 0.25 else (g_pal["mid"] if norm < 0.7 else g_pal["hl"])
			if is_back:
				# 등판 주름
				if absi(x - 24) <= 1:
					c = g_pal["sh"]
			img.set_pixel(x, y, c)

	# 허리 세조대 / 옥대 (y=29)
	var belt_c: Color = g_pal.get("belt", g_pal["sh"])
	for bx in range(19, 30):
		img.set_pixel(bx, 29, belt_c)
	img.set_pixel(24, 29, Color("#ffffff") if has_dragon else g_pal.get("trim", belt_c)) # 옥대 버클

	# 앞면 디테일 (V넥 동정 + 옷고름 + 흉배/용보)
	if not is_back:
		var is_bare_chest: bool = (g_pal.get("trim", Color.TRANSPARENT) == Color("#1d4ed8") and g_pal.get("belt", Color.TRANSPARENT) == Color("#dc2626"))
		if is_bare_chest:
			# 씨름꾼 상체: 흰 동정 대신 구릿빛 근육 명암과 샅바
			img.set_pixel(23, 23, g_pal["deep"])
			img.set_pixel(24, 24, g_pal["deep"])
			img.set_pixel(25, 23, g_pal["deep"])
			img.set_pixel(24, 27, g_pal["deep"]) # 배꼽
			# 샅바 허리 장식
			for sx in range(21, 28):
				img.set_pixel(sx, 29, Color("#1d4ed8"))
				img.set_pixel(sx, 30, Color("#dc2626") if sx % 2 == 0 else Color("#1d4ed8"))
		else:
			var collar_c: Color = Color("#ffffff") # 흰색 동정
			# 45도 사선 V넥 (오른쪽 섶이 왼쪽 위로)
			if is_left:
				img.set_pixel(23, 21, collar_c)
				img.set_pixel(24, 22, collar_c)
				img.set_pixel(25, 23, collar_c)
				img.set_pixel(23, 22, g_pal["deep"]) # 옷깃 주름
				# 옷고름 (y=24~27 사선)
				img.set_pixel(25, 24, g_pal.get("trim", Color("#8b0000")))
				img.set_pixel(26, 25, g_pal.get("trim", Color("#8b0000")))
				img.set_pixel(26, 26, g_pal.get("trim", Color("#8b0000")))
			else:
				img.set_pixel(25, 21, collar_c)
				img.set_pixel(24, 22, collar_c)
				img.set_pixel(23, 23, collar_c)
				img.set_pixel(25, 22, g_pal["deep"])
				img.set_pixel(23, 24, g_pal.get("trim", Color("#8b0000")))
				img.set_pixel(22, 25, g_pal.get("trim", Color("#8b0000")))
				img.set_pixel(22, 26, g_pal.get("trim", Color("#8b0000")))

		# 가슴 중앙 흉배 / 오조룡보
		if has_dragon:
			# 황금빛 둥근 용보 (정조)
			var gold: Color = Color("#f59e0b")
			var gold_hl: Color = Color("#fef08a")
			for dy in range(3):
				for dx in range(3):
					img.set_pixel(23 + dx, 25 + dy, gold)
			img.set_pixel(24, 26, gold_hl)
		elif has_rank:
			# 사각 백학/호랑이 흉배 (채제공, 김판관 등)
			var rank_bg: Color = Color("#f1f5f9")
			var rank_fg: Color = Color("#0f172a")
			for dy in range(3):
				for dx in range(4):
					img.set_pixel(22 + dx, 25 + dy, rank_bg)
			img.set_pixel(23, 26, rank_fg)
			img.set_pixel(24, 26, rank_fg)

## 4. 소매 및 손 (원통형 4단계 명암)
static func _draw_iso_arms(img: Image, dir: int, phase: int, g_pal: Dictionary, skin_pal: Dictionary) -> void:
	var is_left: bool = (dir == CharDef.IsoDir.DOWN_LEFT or dir == CharDef.IsoDir.UP_LEFT)
	var arm_swing: int = 1 if phase == CharDef.AnimPhase.WALK_FRAME_1 else -1

	# 앞쪽 팔 (더 크게 노출)
	var fx: int = 17 if is_left else 29
	var fy: int = 24 + arm_swing
	for dy in range(5):
		for dx in range(3):
			var c: Color = g_pal["hl"] if is_left else g_pal["sh"]
			if dx == 1: c = g_pal["mid"]
			img.set_pixel(fx + dx, fy + dy, c)
	# 손끝 살구색
	img.set_pixel(fx + 1, fy + 5, skin_pal["mid"])

	# 뒤쪽 팔 (작게 노출)
	var bx: int = 28 if is_left else 17
	var by: int = 23 - arm_swing
	for dy in range(4):
		for dx in range(2):
			img.set_pixel(bx + dx, by + dy, g_pal["deep"])
	img.set_pixel(bx, by + 4, skin_pal["sh"])

## 5. 얼굴 & 귀 & 이목구비 (45도 곡선형, 둥근 턱선)
static func _draw_iso_face(img: Image, dir: int, skin_pal: Dictionary) -> void:
	var is_left: bool = (dir == CharDef.IsoDir.DOWN_LEFT or dir == CharDef.IsoDir.UP_LEFT)
	var is_back: bool = (dir == CharDef.IsoDir.UP_LEFT or dir == CharDef.IsoDir.UP_RIGHT)

	# 얼굴 베이스 (y=15 ~ 21, 폭 9px)
	for y in range(15, 22):
		var w: int = 4
		if y == 15 or y == 21: w = 3 # 둥근 이마와 턱선
		for x in range(24 - w, 25 + w):
			var t: float = float(x - (24 - w)) / float(w * 2)
			var c: Color = skin_pal["mid"]
			if is_left:
				c = skin_pal["hl"] if t < 0.4 else (skin_pal["mid"] if t < 0.8 else skin_pal["sh"])
			else:
				c = skin_pal["sh"] if t < 0.25 else (skin_pal["mid"] if t < 0.7 else skin_pal["hl"])
			img.set_pixel(x, y, c)

	# 뒷모습일 때는 뒷머리 상투만
	if is_back:
		var hair_c: Color = Color("#1e1712")
		for y in range(16, 21):
			for x in range(22, 27):
				img.set_pixel(x, y, hair_c)
		return

	# 귀 노출 (뒤쪽 귀가 살짝 드러남)
	var ear_x: int = 28 if is_left else 19
	img.set_pixel(ear_x, 18, skin_pal["sh"])
	img.set_pixel(ear_x, 19, skin_pal["deep"])

	# 눈매 (45도 각도: 가까운 쪽 눈 2px, 먼 쪽 눈 1px)
	var eye_c: Color = Color("#1a1512")
	if is_left:
		# 왼쪽 눈 (가까움)
		img.set_pixel(22, 17, eye_c)
		img.set_pixel(23, 17, eye_c)
		# 오른쪽 눈 (멂)
		img.set_pixel(26, 17, eye_c)
		# 코 (살짝 왼쪽으로 1px 돌출 그림자)
		img.set_pixel(23, 19, skin_pal["deep"])
		# 입술
		img.set_pixel(23, 20, Color("#b97375"))
	else:
		# 왼쪽 눈 (멂)
		img.set_pixel(22, 17, eye_c)
		# 오른쪽 눈 (가까움)
		img.set_pixel(25, 17, eye_c)
		img.set_pixel(26, 17, eye_c)
		# 코
		img.set_pixel(25, 19, skin_pal["deep"])
		# 입술
		img.set_pixel(24, 20, Color("#b97375"))

## 6. 수염 (45도 턱선을 따라 떨어짐)
static func _draw_iso_beard(img: Image, dir: int, beard_type: int, beard_col: Color) -> void:
	var is_left: bool = (dir == CharDef.IsoDir.DOWN_LEFT or dir == CharDef.IsoDir.UP_LEFT)
	var ox: int = -1 if is_left else 1

	match beard_type:
		CharDef.BeardType.THIN_MUSTACHE: # 얇은 콧수염
			img.set_pixel(23 + ox, 19, beard_col)
			img.set_pixel(24 + ox, 19, beard_col)
		CharDef.BeardType.SHORT_BEARD: # 단정한 턱수염
			img.set_pixel(23 + ox, 19, beard_col)
			img.set_pixel(24 + ox, 19, beard_col)
			img.set_pixel(23, 21, beard_col)
			img.set_pixel(24, 21, beard_col)
		CharDef.BeardType.MEDIUM_BEARD: # 학자 턱수염
			for y in range(20, 23):
				for x in range(22, 26):
					img.set_pixel(x, y, beard_col)
		CharDef.BeardType.THICK_WHITE, CharDef.BeardType.FULL_BEARD, CharDef.BeardType.LONG_BLACK: # 노재상/무장 풍성한 수염
			for y in range(20, 25):
				var w: int = 2 + (25 - y)
				for x in range(24 - w, 25 + w):
					if x >= 20 and x <= 28:
						img.set_pixel(x, y, beard_col)
		CharDef.BeardType.STUBBLE: # 거친 구레나룻
			img.set_pixel(22, 20, beard_col)
			img.set_pixel(25, 20, beard_col)

## 7. 관모 (갓, 오사모, 익선관, 전립, 패랭이, 삿갓 등 - 45도 타원 챙)
static func _draw_iso_headgear(img: Image, dir: int, headgear: int, h_pal: Dictionary) -> void:
	var is_back: bool = (dir == CharDef.IsoDir.UP_LEFT or dir == CharDef.IsoDir.UP_RIGHT)

	match headgear:
		CharDef.HeadgearType.HEUNGLIP, CharDef.HeadgearType.PAERAENGI, CharDef.HeadgearType.SATGAT:
			# 1) 타원형 넓은 챙 (y=15~16, 폭 18px 타원)
			var brim_col: Color = h_pal["sh"] if headgear == CharDef.HeadgearType.HEUNGLIP else h_pal["mid"]
			var brim_hl: Color = h_pal["hl"]
			for x in range(15, 34):
				var dist: float = absf(float(x - 24)) / 9.5
				if dist <= 1.0:
					img.set_pixel(x, 15, brim_hl if x < 24 else brim_col)
					img.set_pixel(x, 16, h_pal["deep"])

			# 2) 원통형 갓 총모자 / 패랭이 둥근 모자알 (y=9 ~ 14, 폭 8px)
			for y in range(10, 15):
				var mw: int = 3 if headgear != CharDef.HeadgearType.SATGAT else int(float(y - 9) * 1.5)
				for x in range(24 - mw, 25 + mw):
					var c: Color = h_pal["mid"]
					if x < 24: c = h_pal["hl"]
					elif x > 25: c = h_pal["sh"]
					img.set_pixel(x, y, c)

			# 갓끈 (앞모습일 때만 턱 아래로 늘어짐)
			if not is_back and headgear == CharDef.HeadgearType.HEUNGLIP:
				img.set_pixel(21, 18, Color("#1e1712"))
				img.set_pixel(22, 20, Color("#1e1712"))
				img.set_pixel(26, 18, Color("#1e1712"))
				img.set_pixel(25, 20, Color("#1e1712"))

		CharDef.HeadgearType.OSAMO, CharDef.HeadgearType.OSAMO_HIGH:
			# 오사모 몸체 (y=10 ~ 15)
			for y in range(10, 15):
				for x in range(21, 28):
					var c: Color = h_pal["mid"]
					if x < 24: c = h_pal["hl"]
					elif x > 25: c = h_pal["sh"]
					img.set_pixel(x, y, c)
			# 양쪽 뿔 (사모 양익 - 45도 대각선 날개)
			img.set_pixel(18, 12, h_pal["deep"])
			img.set_pixel(19, 12, h_pal["mid"])
			img.set_pixel(20, 13, h_pal["sh"])
			img.set_pixel(28, 13, h_pal["sh"])
			img.set_pixel(29, 12, h_pal["mid"])
			img.set_pixel(30, 12, h_pal["deep"])

		CharDef.HeadgearType.IKSEONGWAN:
			# 익선관 몸체 (y=9 ~ 15)
			for y in range(10, 15):
				for x in range(21, 28):
					img.set_pixel(x, y, h_pal["mid"] if x >= 24 else h_pal["hl"])
			# 위쪽 2개의 날개(각)
			img.set_pixel(22, 8, h_pal["hl"])
			img.set_pixel(22, 9, h_pal["mid"])
			img.set_pixel(26, 8, h_pal["sh"])
			img.set_pixel(26, 9, h_pal["mid"])

		CharDef.HeadgearType.JEONRIP, CharDef.HeadgearType.JEONRIP_RED:
			# 전립 둥근 챙과 모자알
			for x in range(17, 32):
				img.set_pixel(x, 15, h_pal["deep"])
			for y in range(11, 15):
				for x in range(22, 27):
					img.set_pixel(x, y, h_pal["mid"])
			# 상모 / 상투 꼭지 (붉은 술)
			img.set_pixel(24, 10, Color("#ef4444") if headgear == CharDef.HeadgearType.JEONRIP_RED else Color("#eab308"))
			img.set_pixel(25, 10, Color("#b91c1c") if headgear == CharDef.HeadgearType.JEONRIP_RED else Color("#ca8a04"))

		CharDef.HeadgearType.JEONGJAGWAN, CharDef.HeadgearType.YUGEON:
			# 학자 유건 / 3단 정자관 (산 모양 뫼 산(山)자)
			for y in range(11, 15):
				for x in range(21, 28):
					img.set_pixel(x, y, h_pal["mid"])
			img.set_pixel(22, 9, h_pal["hl"])
			img.set_pixel(24, 8, h_pal["hl"])
			img.set_pixel(26, 9, h_pal["sh"])

		CharDef.HeadgearType.HEADBAND:
			# 땀수건 머리띠 (y=15~16)
			var band_c: Color = h_pal["hl"]
			for x in range(20, 29):
				img.set_pixel(x, 15, band_c)
			# 매듭 끈
			img.set_pixel(28, 16, band_c)
			img.set_pixel(29, 17, band_c)

		CharDef.HeadgearType.GACHE:
			# 부인 풍성한 가체 (y=12~16, 둥근 머리)
			for y in range(13, 17):
				for x in range(19, 30):
					img.set_pixel(x, y, Color("#181412"))
			img.set_pixel(24, 13, Color("#dc2626")) # 붉은 댕기/비녀

## 8. 등 뒤 소품 (보부상 지게, 책 더미, 쇠메 등)
static func _draw_prop_behind(img: Image, dir: int, phase: int, prop: String) -> void:
	var is_left: bool = (dir == CharDef.IsoDir.DOWN_LEFT or dir == CharDef.IsoDir.UP_LEFT)
	var is_back: bool = (dir == CharDef.IsoDir.UP_LEFT or dir == CharDef.IsoDir.UP_RIGHT)
	var bob: int = 1 if phase == CharDef.AnimPhase.WALK_FRAME_1 else 0

	match prop:
		"jige":
			# ★ 보부상 지게 및 2단 봇짐 (레퍼런스 완벽 재현) ★
			var jx: int = 24 + (3 if is_left else -3)
			var jy: int = 17 + bob
			# 나무 프레임 (갈색)
			var wood: Color = Color("#78350f")
			var wood_sh: Color = Color("#451a03")
			for y in range(jy, jy + 14):
				img.set_pixel(jx - 5, y, wood)
				img.set_pixel(jx + 4, y, wood_sh)

			# 윗단 봇짐 (황토/오렌지 보따리)
			for by in range(jy + 1, jy + 6):
				for bx in range(jx - 4, jx + 4):
					img.set_pixel(bx, by, Color("#ea580c") if bx < jx else Color("#c2410c"))

			# 아랫단 봇짐 (초록/올리브 보따리)
			for by in range(jy + 6, jy + 11):
				for bx in range(jx - 4, jx + 4):
					img.set_pixel(bx, by, Color("#65a30d") if bx < jx else Color("#4d7c0f"))

			# 지게 멜빵 끈 (어깨에 두름)
			if not is_back:
				img.set_pixel(21, 23, Color("#ffffff"))
				img.set_pixel(22, 24, Color("#ffffff"))
				img.set_pixel(26, 23, Color("#ffffff"))
				img.set_pixel(25, 24, Color("#ffffff"))

		"hammer":
			# 석수 김바우 거대한 쇠메 (망치)
			var hx: int = 27 if is_left else 19
			for i in range(12):
				img.set_pixel(hx - i, 16 + i, Color("#5c3a21")) # 자루
			# 쇠뭉치
			for dy in range(4):
				for dx in range(4):
					img.set_pixel(hx - 1 + dx, 15 + dy, Color("#475569"))

		"fishing_rod":
			# 낚시꾼 등 뒤 긴 대나무 낚싯대 및 파닥거리는 물고기 꿰미
			var rod_col: Color = Color("#78350f") # 대나무 낚싯대
			var rod_hl: Color = Color("#b45309")
			var r_base_x: int = 24 + (4 if is_left else -4)
			var r_top_x: int = 24 + (-9 if is_left else 9)
			# 대각선 낚싯대 (y=8 ~ 32)
			for i in range(25):
				var ry: int = 8 + i
				var rx: int = int(lerpf(float(r_top_x), float(r_base_x), float(i) / 24.0))
				if rx >= 0 and rx < WIDTH and ry >= 0 and ry < HEIGHT:
					img.set_pixel(rx, ry, rod_hl if i < 8 else rod_col)
			# 낚싯줄 및 은빛 물고기 꿰미
			var fish_x: int = r_top_x + (-3 if is_left else 3)
			var fish_y: int = 14 + bob
			for fy in range(fish_y, fish_y + 4):
				for fx in range(fish_x - 1, fish_x + 2):
					if fx >= 0 and fx < WIDTH and fy >= 0 and fy < HEIGHT:
						img.set_pixel(fx, fy, Color("#38bdf8") if fy == fish_y else Color("#e2e8f0"))
			if fish_x >= 0 and fish_x < WIDTH and (fish_y + 4) < HEIGHT:
				img.set_pixel(fish_x, fish_y + 4, Color("#0284c7")) # 물고기 꼬리

		"kite_spool":
			# 연날리기: 하늘 높이 떠 있는 오색 태극 방패연 (가운데 둥근 구멍)
			var k_center_x: int = 24 + (10 if is_left else -10)
			var k_center_y: int = 7 + bob
			# 방패연 사각 몸체 (폭 7px, 높이 9px)
			for ky in range(k_center_y - 4, k_center_y + 5):
				for kx in range(k_center_x - 3, k_center_x + 4):
					if kx >= 0 and kx < WIDTH and ky >= 0 and ky < HEIGHT:
						var dist_k: float = sqrt(float((kx - k_center_x) * (kx - k_center_x) + (ky - k_center_y) * (ky - k_center_y)))
						if dist_k < 1.3:
							continue # 방패연 가운데 바람구멍(방구멍)
						var col_k: Color = Color("#f8fafc") # 백색 창호지 한지
						if ky < k_center_y - 1:
							col_k = Color("#ef4444") # 상단 붉은 머리
						elif kx < k_center_x:
							col_k = Color("#3b82f6") # 좌측 청색
						elif kx > k_center_x:
							col_k = Color("#eab308") # 우측 황색
						img.set_pixel(kx, ky, col_k)
			# 연꼬리 (아래로 흩날리는 2가닥 꼬리)
			if (k_center_y + 5) < HEIGHT:
				if (k_center_x - 2) >= 0 and (k_center_x - 2) < WIDTH:
					img.set_pixel(k_center_x - 2, k_center_y + 5, Color("#ef4444"))
				if (k_center_x + 2) >= 0 and (k_center_x + 2) < WIDTH:
					img.set_pixel(k_center_x + 2, k_center_y + 5, Color("#3b82f6"))
			if (k_center_y + 6) < HEIGHT:
				if (k_center_x - 3) >= 0 and (k_center_x - 3) < WIDTH:
					img.set_pixel(k_center_x - 3, k_center_y + 6, Color("#ef4444"))
				if (k_center_x + 3) >= 0 and (k_center_x + 3) < WIDTH:
					img.set_pixel(k_center_x + 3, k_center_y + 6, Color("#3b82f6"))

## 9. 앞쪽 소품 (지팡이, 설계도, 홀, 붓, 검 등)
static func _draw_prop_front(img: Image, dir: int, _phase: int, prop: String) -> void:
	var is_left: bool = (dir == CharDef.IsoDir.DOWN_LEFT or dir == CharDef.IsoDir.UP_LEFT)

	match prop:
		"jige":
			# 보부상 지팡이 (손에 쥠)
			var sx: int = 16 if is_left else 31
			for y in range(24, 42):
				img.set_pixel(sx, y, Color("#78350f"))

		"blueprint":
			# 정약용 거중기 설계도 두루마리와 붓
			var bx: int = 18 if is_left else 28
			img.set_pixel(bx, 28, Color("#fef08a"))
			img.set_pixel(bx + 1, 28, Color("#fef08a"))
			img.set_pixel(bx + 1, 27, Color("#1e293b")) # 붓대

		"hol":
			# 채제공 상아 홀 (양손으로 받듦)
			img.set_pixel(24, 25, Color("#fffbeb"))
			img.set_pixel(24, 26, Color("#fef3c7"))
			img.set_pixel(24, 27, Color("#fde68a"))

		"royal_sword", "sword":
			# 환도 / 어검 (허리춤)
			var kx: int = 28 if is_left else 18
			img.set_pixel(kx, 29, Color("#d97706")) # 코등이
			img.set_pixel(kx + 1, 30, Color("#cbd5e1")) # 칼집
			img.set_pixel(kx + 2, 31, Color("#94a3b8"))

		"baton":
			# 지휘 등채
			var tx: int = 18 if is_left else 29
			img.set_pixel(tx, 27, Color("#dc2626"))
			img.set_pixel(tx, 28, Color("#d97706"))

		"ledger":
			# 김판관 공문 장부
			var lx: int = 19 if is_left else 27
			img.set_pixel(lx, 27, Color("#3b82f6"))
			img.set_pixel(lx + 1, 27, Color("#ffffff"))
			img.set_pixel(lx, 28, Color("#1d4ed8"))

		"book_fan":
			# 전기수: 한 손에 펼친 서책, 한 손에 접부채
			var bk_x: int = 18 if is_left else 28
			for by in range(25, 29):
				for bx in range(bk_x - 1, bk_x + 3):
					if bx >= 0 and bx < WIDTH and by >= 0 and by < HEIGHT:
						var b_col: Color = Color("#1e3a8a") if (bx == bk_x - 1 or bx == bk_x + 2) else Color("#fef3c7")
						img.set_pixel(bx, by, b_col)
			var fn_x: int = 28 if is_left else 18
			for i in range(4):
				var fy: int = 25 + i
				var fx: int = fn_x + (i if is_left else -i)
				if fx >= 0 and fx < WIDTH and fy >= 0 and fy < HEIGHT:
					img.set_pixel(fx, fy, Color("#d97706") if i < 2 else Color("#ffffff"))

		"fishing_rod":
			# 낚시꾼: 손에 쥔 대나무 낚싯대 손잡이
			var h_x: int = 17 if is_left else 29
			img.set_pixel(h_x, 26, Color("#451a03"))
			img.set_pixel(h_x, 27, Color("#78350f"))

		"kite_spool":
			# 연날리기: 양손으로 쥔 육각 나무 얼레(실타래) 및 연실
			var sp_x: int = 20 if is_left else 26
			for dy in range(3):
				for dx in range(3):
					var px: int = sp_x + dx - 1
					var py: int = 26 + dy
					if px >= 0 and px < WIDTH and py >= 0 and py < HEIGHT:
						img.set_pixel(px, py, Color("#ef4444") if (dx == 1 and dy == 1) else Color("#78350f"))
			img.set_pixel(sp_x, 25, Color("#ffffff"))
			img.set_pixel(sp_x, 24, Color("#f1f5f9"))

		"satba":
			# 씨름장사: 허리와 허벅지에 맨 청/홍 샅바 매듭
			var sb_x: int = 24 + (2 if is_left else -2)
			for sy in range(29, 34):
				if (sb_x - 1) >= 0 and (sb_x - 1) < WIDTH and sy < HEIGHT:
					img.set_pixel(sb_x - 1, sy, Color("#1d4ed8"))
				if sb_x >= 0 and sb_x < WIDTH and sy < HEIGHT:
					img.set_pixel(sb_x, sy, Color("#dc2626"))
				if (sb_x + 1) >= 0 and (sb_x + 1) < WIDTH and sy < HEIGHT:
					img.set_pixel(sb_x + 1, sy, Color("#991b1b"))

		"taekkyeon_belt":
			# 택견꾼: 품밟기용 감청색/진홍색 쾌자 띠 매듭 및 대님
			var tk_x: int = 24 + (-2 if is_left else 2)
			for ty in range(29, 36):
				if tk_x >= 0 and tk_x < WIDTH and ty < HEIGHT:
					img.set_pixel(tk_x, ty, Color("#1e3a8a"))
				if (tk_x + (1 if is_left else -1)) >= 0 and (tk_x + (1 if is_left else -1)) < WIDTH and ty < HEIGHT:
					img.set_pixel(tk_x + (1 if is_left else -1), ty, Color("#dc2626") if ty < 32 else Color("#172554"))

# ==============================================================================
# ★ 핵심 퀄리티 패스: 1px 다크 차콜 외곽선 (#1E1B18) ★
# ==============================================================================

## 불투명 픽셀의 바깥쪽 테두리에만 1px 외곽선을 정밀 둘러치기
static func _apply_crisp_1px_dark_outline(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var outline_pixels: Array[Vector2i] = []

	# 1. 외곽 후보 픽셀 탐색 (불투명 픽셀의 인접 빈 픽셀)
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.1:
				# 4방향 이웃 확인
				for off in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
					var nx: int = x + off.x
					var ny: int = y + off.y
					if nx >= 0 and nx < w and ny >= 0 and ny < h:
						if img.get_pixel(nx, ny).a <= 0.05:
							outline_pixels.append(Vector2i(nx, ny))

	# 2. 외곽선 칠하기 (중복 방지)
	for pt: Vector2i in outline_pixels:
		img.set_pixel(pt.x, pt.y, P.OUTLINE_COLOR)
