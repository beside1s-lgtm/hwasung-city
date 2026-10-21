extends RefCounted
class_name PortraitPeople

## 살피기 팝업의 인물 도트 초상(80x80). 얼굴·모자·수염·옷깃·들고 있는 물건을 조합해 인물마다 다르게 그린다.
## PortraitArt._finish 에서 둥근 틀 안으로 잘라 낸다.

const S := 80
const INK := Color("1a1410")

# 인물 사양 — 키는 InspectNarrativeGenerator의 초상 키와 같다.
# bg: [안쪽, 바깥, 테두리, 띠]  robe: 겉옷  collar: round/cross/plain/armor/monk  trim: 깃 장식
# hat: samo/gat/jeongja/jeonlip/helmet/iksun/pyeongnang/satgat/furcap/topknot/headband/monk/pyeongjeong
# face: eyes(normal/narrow/big/stern/sleepy) brows(flat/angry/soft/white/worry) mouth(smile/flat/open/frown)
# stache(none/thin/bushy/long)  beard(none/goatee/short/full/white/stubble)  age(0~2)  skin  lean
# items: back(뒤)·front(앞)에 그릴 물건 이름들
const SPECS := {
	"jeongjo": {"bg": ["f9e6a8", "7a1c1c", "c9a227", "e8c860"], "robe": "a31f1f", "collar": "round", "trim": "e0b83a", "hat": "iksun",
		"face": {"eyes": "normal", "brows": "flat", "mouth": "flat", "stache": "thin", "beard": "short", "age": 1}, "emblem": "dragon"},
	"jeong_yakyong": {"bg": ["eaf2f8", "9db6cc", "4a6a8a", "8aa8c4"], "robe": "4a709c", "collar": "cross", "trim": "f2efe6", "hat": "jeongja",
		"face": {"eyes": "narrow", "brows": "soft", "mouth": "smile", "stache": "thin", "beard": "goatee", "age": 0, "lean": true}, "items": ["blueprint"]},
	"chae_jegong": {"bg": ["fbeedd", "c9a07a", "7a4a2a", "b8906a"], "robe": "b22222", "collar": "round", "trim": "d4af37", "hat": "samo",
		"face": {"eyes": "sleepy", "brows": "white", "mouth": "flat", "stache": "long", "beard": "white", "age": 2}, "items": ["hol"]},
	"kim_hongdo": {"bg": ["f6efe0", "d8c7a0", "6a5030", "b49a6a"], "robe": "96724f", "collar": "cross", "trim": "e8dcc4", "hat": "gat",
		"face": {"eyes": "narrow", "brows": "soft", "mouth": "smile", "stache": "thin", "beard": "none", "age": 1}, "items": ["brush"]},
	"kim_bau": {"bg": ["f3ead6", "cdb88a", "6a5030", "a89066"], "robe": "c2b49d", "collar": "plain", "trim": "efe8d8", "hat": "headband", "skin": "d9a578",
		"face": {"eyes": "normal", "brows": "angry", "mouth": "smile", "stache": "bushy", "beard": "stubble", "age": 1}, "items": ["hammer"]},
	"jo_simtae": {"bg": ["efe6dc", "7a8aa4", "2a3a5a", "8a9ab4"], "robe": "224870", "collar": "round", "trim": "c9a227", "hat": "jeonlip",
		"face": {"eyes": "stern", "brows": "angry", "mouth": "frown", "stache": "bushy", "beard": "short", "age": 1}},
	"gu_seonbok": {"bg": ["eceae4", "8a8e94", "3a3f46", "9aa0a8"], "robe": "4a5058", "collar": "armor", "trim": "d4af37", "hat": "helmet", "skin": "e0b48c",
		"face": {"eyes": "stern", "brows": "angry", "mouth": "frown", "stache": "bushy", "beard": "full", "age": 1}},
	"baek_dongsoo": {"bg": ["eee6e6", "5a4a4a", "2a2020", "8a7070"], "robe": "232826", "collar": "cross", "trim": "b22222", "hat": "headband_red",
		"face": {"eyes": "stern", "brows": "angry", "mouth": "flat", "stache": "thin", "beard": "stubble", "age": 0, "lean": true}, "items": ["sword"]},
	"merchant": {"bg": ["f6ecd4", "d8b878", "7a5a2a", "c9a860"], "robe": "7a9a68", "collar": "plain", "trim": "efe6d0", "hat": "pyeongnang",
		"face": {"eyes": "normal", "brows": "soft", "mouth": "smile", "stache": "thin", "beard": "none", "age": 1}, "items": ["abacus"]},
	"patrol_soldier": {"bg": ["eee8de", "8a7a6a", "3a2a20", "a09080"], "robe": "6a2a2a", "collar": "round", "trim": "c9a227", "hat": "jeonlip",
		"face": {"eyes": "stern", "brows": "angry", "mouth": "flat", "stache": "bushy", "beard": "none", "age": 0}, "items": ["spear"]},
	"farmer": {"bg": ["f2f0d8", "b8c888", "5a7a3a", "9ab878"], "robe": "e8e0cc", "collar": "plain", "trim": "d6ccb4", "hat": "satgat", "skin": "d6a070",
		"face": {"eyes": "normal", "brows": "flat", "mouth": "smile", "stache": "none", "beard": "stubble", "age": 1}, "items": ["hoe"]},
	"scholar": {"bg": ["f8f6ee", "c8d0dc", "4a5a7a", "9aa8c0"], "robe": "f0eee6", "collar": "cross", "trim": "2a2a3a", "hat": "gat",
		"face": {"eyes": "narrow", "brows": "soft", "mouth": "flat", "stache": "thin", "beard": "goatee", "age": 0, "lean": true}, "items": ["book"]},
	"artisan": {"bg": ["f3ead6", "c4b496", "5a4a30", "a49470"], "robe": "8a7a64", "collar": "plain", "trim": "d8ccb0", "hat": "headband", "skin": "dba87c",
		"face": {"eyes": "normal", "brows": "angry", "mouth": "smile", "stache": "none", "beard": "stubble", "age": 1}, "items": ["hammer"]},
	"woodcutter": {"bg": ["eaf0dc", "9ab07a", "4a6a30", "86a068"], "robe": "9a8a6a", "collar": "plain", "trim": "d0c4a0", "hat": "headband", "skin": "d6a070",
		"face": {"eyes": "normal", "brows": "flat", "mouth": "smile", "stache": "none", "beard": "stubble", "age": 1}, "items": ["axe", "jige"]},
	"hunter": {"bg": ["f0eada", "9a8a74", "4a3a28", "b0a088"], "robe": "7a5a3a", "collar": "plain", "trim": "d8c8a0", "hat": "furcap", "skin": "d6a070",
		"face": {"eyes": "narrow", "brows": "angry", "mouth": "flat", "stache": "none", "beard": "stubble", "age": 1}, "items": ["bow"]},
	"commoner": {"bg": ["f7f0e0", "dcd0b4", "7a5a38", "c4b490"], "robe": "efe9da", "collar": "plain", "trim": "d4cab4", "hat": "topknot",
		"face": {"eyes": "normal", "brows": "soft", "mouth": "smile", "stache": "none", "beard": "none", "age": 0}},
	"jungin": {"bg": ["eef0f0", "98a8b0", "3a5060", "88a0ac"], "robe": "58728a", "collar": "cross", "trim": "e8e8ea", "hat": "gat",
		"face": {"eyes": "narrow", "brows": "flat", "mouth": "flat", "stache": "thin", "beard": "goatee", "age": 1}, "items": ["abacus"]},
	"ajeon": {"bg": ["f0ece4", "a0987e", "4a4430", "b0a890"], "robe": "3e6a6a", "collar": "cross", "trim": "e8e4d8", "hat": "pyeongjeong",
		"face": {"eyes": "narrow", "brows": "flat", "mouth": "smile", "stache": "thin", "beard": "none", "age": 0}, "items": ["ledger"]},
	"bobusang": {"bg": ["f6eede", "cab88e", "6a5430", "b49c70"], "robe": "8a7a5a", "collar": "plain", "trim": "d8cca8", "hat": "pyeongnang", "skin": "d6a070",
		"face": {"eyes": "normal", "brows": "soft", "mouth": "smile", "stache": "none", "beard": "stubble", "age": 1}, "items": ["bundle"]},
	"monk_soldier": {"bg": ["ece8dc", "8a8a78", "3a3a2a", "a0a08c"], "robe": "7a7a6a", "collar": "monk", "trim": "c8b890", "hat": "monk", "skin": "dcae86",
		"face": {"eyes": "stern", "brows": "angry", "mouth": "flat", "stache": "none", "beard": "none", "age": 1}, "items": ["staff", "beads"]},
	# --- 등용 가능한 인재(CourtSystem.SCHOLARS) 초상: 지도에 나타나는 네임드 NPC와 같은 인물 ---
	"park_jiwon": {"bg": ["f0ecdc", "a8b8c8", "3a4a6a", "90a0b8"], "robe": "5a6e8a", "collar": "cross", "trim": "efe9dc", "hat": "gat",
		"face": {"eyes": "narrow", "brows": "soft", "mouth": "smile", "stache": "long", "beard": "short", "age": 2}, "items": ["book"]},
	"hong_daeyong": {"bg": ["eaf0f4", "7a9ab8", "2a4a6a", "8aaac8"], "robe": "3a5a6a", "collar": "cross", "trim": "efe9dc", "hat": "jeongja",
		"face": {"eyes": "narrow", "brows": "soft", "mouth": "smile", "stache": "thin", "beard": "goatee", "age": 1}, "items": ["blueprint"]},
	"lee_deokmu": {"bg": ["eef0e4", "a8b498", "4a5a3a", "98a888"], "robe": "8a9a8a", "collar": "cross", "trim": "efe9dc", "hat": "gat",
		"face": {"eyes": "sleepy", "brows": "worry", "mouth": "flat", "stache": "thin", "beard": "none", "age": 1, "lean": true}, "items": ["book"]},
	"park_jega": {"bg": ["f6efdc", "c8b488", "6a5030", "b8a070"], "robe": "7a6a4a", "collar": "cross", "trim": "efe9dc", "hat": "gat",
		"face": {"eyes": "normal", "brows": "flat", "mouth": "smile", "stache": "thin", "beard": "goatee", "age": 0}, "items": ["bundle"]},
	"lee_gahwan": {"bg": ["eef0f6", "8a98c8", "2a3a7a", "98a8d0"], "robe": "2a4a9a", "collar": "round", "trim": "d4af37", "hat": "samo",
		"face": {"eyes": "narrow", "brows": "flat", "mouth": "flat", "stache": "thin", "beard": "short", "age": 1}, "items": ["blueprint"]},
	"kim_josun": {"bg": ["eef4ec", "88b498", "2a5a3a", "98c4a8"], "robe": "3a7a5a", "collar": "round", "trim": "d4af37", "hat": "samo",
		"face": {"eyes": "soft", "brows": "soft", "mouth": "smile", "stache": "thin", "beard": "short", "age": 1}, "items": ["hol"]},
	"yu_deukgong": {"bg": ["f0f4e8", "a8c498", "4a6a3a", "98b488"], "robe": "7a9a7a", "collar": "cross", "trim": "efe9dc", "hat": "gat",
		"face": {"eyes": "normal", "brows": "soft", "mouth": "smile", "stache": "thin", "beard": "none", "age": 0}, "items": ["book"]},
	"kim_jeonghui": {"bg": ["f8f6ee", "c8d0dc", "3a5aa0", "9aa8c8"], "robe": "e8e4d8", "collar": "cross", "trim": "3a5aa0", "hat": "gat",
		"face": {"eyes": "narrow", "brows": "angry", "mouth": "smile", "stache": "none", "beard": "none", "age": 0, "lean": true}, "items": ["brush"]},
	"seo_yugu": {"bg": ["f0f4e0", "98c078", "3a6a2a", "88b068"], "robe": "5a8a4a", "collar": "cross", "trim": "efe9dc", "hat": "gat",
		"face": {"eyes": "normal", "brows": "flat", "mouth": "smile", "stache": "none", "beard": "short", "age": 1}, "items": ["hoe"]},
	"jeong_beomjo": {"bg": ["fbeedd", "c9a07a", "7a4a2a", "b8906a"], "robe": "a82a2a", "collar": "round", "trim": "d4af37", "hat": "samo",
		"face": {"eyes": "sleepy", "brows": "white", "mouth": "flat", "stache": "long", "beard": "white", "age": 2}, "items": ["hol"]},
	"lee_seonggil": {"bg": ["f3ead6", "cdb88a", "6a5030", "a89066"], "robe": "8a6a4a", "collar": "plain", "trim": "d8ccb0", "hat": "headband", "skin": "d6a070",
		"face": {"eyes": "normal", "brows": "angry", "mouth": "smile", "stache": "bushy", "beard": "stubble", "age": 1}, "items": ["hammer"]},
	"musoe": {"bg": ["f2e6e0", "b49a8a", "5a3a30", "a48676"], "robe": "5c4a3a", "collar": "plain", "trim": "c8c0aa", "hat": "headband", "skin": "d0a078", "apron": true,
		"face": {"eyes": "stern", "brows": "angry", "mouth": "flat", "stache": "bushy", "beard": "stubble", "age": 1}, "items": ["knife"]},
	"hong_gukyeong": {"bg": ["f6e8e0", "c88a7a", "7a2a1a", "d89a8a"], "robe": "a82a2a", "collar": "round", "trim": "d4af37", "hat": "samo",
		"face": {"eyes": "stern", "brows": "angry", "mouth": "frown", "stache": "thin", "beard": "none", "age": 0, "lean": true}, "items": ["sword"]},
	"hong_inhan": {"bg": ["eeeaf4", "9a8ac0", "3a2a6a", "a898c8"], "robe": "3a3a6a", "collar": "round", "trim": "d4af37", "hat": "samo",
		"face": {"eyes": "normal", "brows": "flat", "mouth": "smile", "stache": "bushy", "beard": "short", "age": 2}, "items": ["abacus"]},
	"lee_gigyeong": {"bg": ["ecedf0", "8a9aaa", "2a3a4a", "9aaaba"], "robe": "34495e", "collar": "cross", "trim": "efe9dc", "hat": "gat",
		"face": {"eyes": "stern", "brows": "angry", "mouth": "frown", "stache": "thin", "beard": "goatee", "age": 1, "lean": true}, "items": ["book"]},
	"sim_hwanji": {"bg": ["ececf0", "7a7a8a", "2a2a3a", "8a8a9a"], "robe": "3a3a4a", "collar": "round", "trim": "b8b8c8", "hat": "samo",
		"face": {"eyes": "sleepy", "brows": "white", "mouth": "flat", "stache": "long", "beard": "white", "age": 2}, "items": ["hol"]},
	"yu_hanji": {"bg": ["f2f4ec", "b0c8b8", "4a6a5a", "a0b8a8"], "robe": "d0e3d5", "collar": "cross", "trim": "2a6a4a", "hat": "gat",
		"face": {"eyes": "narrow", "brows": "soft", "mouth": "smile", "stache": "thin", "beard": "goatee", "age": 1}, "items": ["brush"]},
	# --- 장 보러 나온 백성들(NpcSprites 종류와 1:1): 옷 색은 pal(NpcSprites.PALETTES)의 변형 번호로 정해진다 ---
	"yangban_m": {"pal": "yangban", "bg": ["f4efe0", "9aa4b8", "3a4a6a", "8a98b0"], "robe": "2f4f8a", "collar": "cross", "trim": "efe9dc", "hat": "gat",
		"face": {"eyes": "narrow", "brows": "flat", "mouth": "flat", "stache": "thin", "beard": "goatee", "age": 1, "lean": true}},
	"hallyang": {"pal": "hallyang", "bg": ["f8eedc", "c8a0b8", "6a3a5a", "b888a8"], "robe": "6a3a8a", "collar": "cross", "trim": "e0b040", "hat": "gat",
		"face": {"eyes": "narrow", "brows": "soft", "mouth": "smile", "stache": "thin", "beard": "none", "age": 0}, "items": ["fan"]},
	"official_m": {"pal": "official", "bg": ["eef0f4", "8a98b8", "2a3a6a", "98a8c8"], "robe": "2a4a9a", "collar": "round", "trim": "d4af37", "hat": "samo",
		"face": {"eyes": "stern", "brows": "flat", "mouth": "flat", "stache": "thin", "beard": "short", "age": 1}},
	"porter": {"pal": "porter", "bg": ["f3ead6", "cdb88a", "6a5030", "a89066"], "robe": "c8b890", "collar": "plain", "trim": "d8ccb0", "hat": "headband", "skin": "d6a070",
		"face": {"eyes": "normal", "brows": "flat", "mouth": "smile", "stache": "none", "beard": "stubble", "age": 1}, "items": ["jige"]},
	"cheonmin": {"pal": "cheonmin", "bg": ["ece6d8", "a8a090", "4a4438", "98907e"], "robe": "8a8478", "collar": "plain", "trim": "b0a898", "hat": "messy", "skin": "d0a078", "ragged": true,
		"face": {"eyes": "sleepy", "brows": "worry", "mouth": "flat", "stache": "none", "beard": "stubble", "age": 1}},
	"child_m": {"pal": "child_m", "bg": ["fdf4e0", "e8d098", "8a6a30", "d0b878"], "robe": "e6dcc0", "collar": "plain", "trim": "f6f0e0", "hat": "kid_boy", "child": true,
		"face": {"eyes": "big", "brows": "soft", "mouth": "smile", "stache": "none", "beard": "none", "age": 0}},
	"commoner_w": {"pal": "commoner_w", "female": true, "bg": ["fbf0e0", "e0c4a0", "8a5a38", "d0b090"], "robe": "e6dcc0", "skirt": "8a7a5a", "collar": "hanbok", "trim": "f6f0e0", "hat": "scarf",
		"face": {"eyes": "soft", "brows": "soft", "mouth": "smile", "stache": "none", "beard": "none", "age": 0}, "items": ["basket"]},
	"lady": {"pal": "lady", "female": true, "bg": ["fbeef0", "e0a8b8", "8a3a5a", "d498a8"], "robe": "e88aa0", "skirt": "2e3a6a", "collar": "hanbok", "trim": "f6f0e0", "hat": "jangot",
		"face": {"eyes": "soft", "brows": "soft", "mouth": "smile", "stache": "none", "beard": "none", "age": 1}},
	"jumo": {"pal": "jumo", "female": true, "bg": ["f6eede", "d8b888", "7a5a30", "c4a470"], "robe": "6a8a4a", "skirt": "2e3a6a", "collar": "hanbok", "trim": "f6f0e0", "hat": "bun_w", "apron": true,
		"face": {"eyes": "soft", "brows": "flat", "mouth": "smile", "stache": "none", "beard": "none", "age": 1}},
	"gisaeng": {"pal": "gisaeng", "female": true, "bg": ["fdeaf0", "d890b0", "7a2a58", "cc80a4"], "robe": "5aa83a", "skirt": "c8283a", "collar": "hanbok", "trim": "f6f0e0", "hat": "gache",
		"face": {"eyes": "soft", "brows": "soft", "mouth": "smile", "stache": "none", "beard": "none", "age": 0}, "items": ["gayageum"]},
	"child_f": {"pal": "child_f", "female": true, "child": true, "bg": ["fff0f4", "f0b8c8", "a04a68", "e0a0b4"], "robe": "f0b8c8", "skirt": "c8283a", "collar": "hanbok", "trim": "f6f0e0", "hat": "braid_w",
		"face": {"eyes": "big", "brows": "soft", "mouth": "smile", "stache": "none", "beard": "none", "age": 0}},
	"butcher": {"bg": ["f2e6e0", "b49a8a", "5a3a30", "a48676"], "robe": "e6e0d2", "collar": "plain", "trim": "c8c0aa", "hat": "pyeongnang", "skin": "d4a078",
		"face": {"eyes": "stern", "brows": "angry", "mouth": "frown", "stache": "bushy", "beard": "stubble", "age": 1}, "items": ["knife"], "apron": true},
	# --- 유수부 원옥 친국·송사 전용 인물 초상 (죄인, 아전, 비장) ---
	"criminal": {"bg": ["ece6d8", "a89880", "5a4430", "988870"], "robe": "c4bca8", "collar": "plain", "trim": "a8a090", "hat": "messy", "skin": "d0a078", "ragged": true,
		"face": {"eyes": "sleepy", "brows": "worry", "mouth": "flat", "stache": "none", "beard": "stubble", "age": 1}},
	"ajeon_investigator": {"bg": ["f0ece4", "a0987e", "4a4430", "b0a890"], "robe": "3e6a6a", "collar": "cross", "trim": "e8e4d8", "hat": "pyeongjeong",
		"face": {"eyes": "narrow", "brows": "flat", "mouth": "smile", "stache": "thin", "beard": "none", "age": 0}, "items": ["ledger"]},
	"bijiang": {"bg": ["efe8de", "8a7a6a", "3a2a20", "a09080"], "robe": "7a3030", "collar": "round", "trim": "c9a227", "hat": "jeonlip",
		"face": {"eyes": "stern", "brows": "angry", "mouth": "flat", "stache": "bushy", "beard": "short", "age": 1}, "items": ["hol"]},
}

static func has(key: String) -> bool:
	return SPECS.has(key.split("#")[0])

## key 뒤에 "#번호"를 붙이면 옷 색 변형(NpcSprites 팔레트 번호)을 쓴다. 예: "lady#2"
static func make(key: String) -> ImageTexture:
	var parts := key.split("#")
	var base := String(parts[0])
	var variant := int(parts[1]) if parts.size() > 1 else 0
	var sp: Dictionary = (SPECS[base] as Dictionary).duplicate(true)
	if sp.has("pal") and NpcSprites.PALETTES.has(String(sp["pal"])):
		var pal: Array = NpcSprites.PALETTES[String(sp["pal"])]
		var col: Array = pal[variant % pal.size()]
		sp["robe"] = col[0]
		if bool(sp.get("female", false)):
			sp["skirt"] = col[1]
			sp["tie"] = col[2]
		elif base == "official_m":
			sp["trim"] = col[2]

	var bgc: Array = sp["bg"]
	var bg := PixelArt.new(S, S)
	bg.medallion(Color(bgc[0]), Color(bgc[1]), Color(bgc[2]), Color(bgc[3]))
	var fig := PixelArt.new(S, S)
	var items: Array = sp.get("items", [])
	# 뒤에 세운 물건(창·지게·활·칼·삽 따위)
	for it: String in items:
		_item_back(fig, it)
	_body(fig, sp)
	var head := PixelArt.new(S, S)
	_head(head, sp)
	fig.blit(head, 0, 3)
	for it2: String in items:
		_item_front(fig, it2, sp)
	return PortraitArt._finish(bg, fig, Color(bgc[2]), Color(bgc[3]))

# ─────────────────────────────────────────── 몸
static func _body(f: PixelArt, sp: Dictionary) -> void:
	var robe := Color(sp["robe"])
	var trim := Color(sp["trim"])
	var skin := Color(sp.get("skin", "f6d8b8" if bool(sp.get("female", false)) else "f1c9a0"))
	var skin_sh := PixelArt.shade(skin, -0.2)
	var col := String(sp["collar"])
	var body := PackedVector2Array([Vector2(4, 80), Vector2(8, 65), Vector2(18, 57), Vector2(62, 57), Vector2(72, 65), Vector2(76, 80)])
	if col == "armor":
		body = PackedVector2Array([Vector2(2, 80), Vector2(5, 62), Vector2(16, 55), Vector2(64, 55), Vector2(75, 62), Vector2(78, 80)])
	if bool(sp.get("child", false)):
		body = PackedVector2Array([Vector2(12, 80), Vector2(15, 68), Vector2(24, 62), Vector2(56, 62), Vector2(65, 68), Vector2(68, 80)])
	var base_col := Color(String(sp.get("skirt", sp["robe"]))) if col == "hanbok" else robe
	f.spoly(body, base_col, 0.16, -0.32)
	# 목
	f.rect(35, 48, 10, 13, skin_sh)
	f.rect(35, 48, 3, 13, skin)
	match col:
		"round":
			f.ell(40, 61, 10, 5, PixelArt.shade(robe, -0.38))
			f.ell(40, 59.5, 7, 3.5, skin_sh)
			for i in range(-9, 10):
				var yy := 61 + int(float(i * i) / 22.0)
				f.px(40 + i, yy, trim)
				f.px(40 + i, yy + 1, PixelArt.shade(trim, -0.2))
		"cross":
			f.poly(PackedVector2Array([Vector2(31, 58), Vector2(49, 58), Vector2(40, 74)]), Color("efe9dc"))
			f.line(31, 58, 40, 73, trim, 2)
			f.line(49, 58, 41, 73, trim, 2)
			f.line(31, 58, 40, 73, PixelArt.shade(trim, -0.2), 1)
			f.px(40, 74, PixelArt.shade(robe, -0.4))
			f.rect(36, 70, 8, 2, PixelArt.shade(robe, -0.35)) # 고름
		"plain":
			f.poly(PackedVector2Array([Vector2(33, 58), Vector2(47, 58), Vector2(40, 68)]), PixelArt.shade(trim, 0.2))
			f.line(33, 58, 40, 68, trim, 2)
			f.line(47, 58, 40, 68, trim, 2)
			# 허리띠
			f.rect(8, 76, 64, 3, PixelArt.shade(robe, -0.35))
		"armor":
			f.ell(40, 60, 11, 5, PixelArt.shade(robe, -0.4))
			f.ell(40, 59, 8, 3.6, skin_sh)
			# 어깨 견갑과 쇠미늘
			f.ell(12, 62, 9, 6, PixelArt.shade(robe, 0.1))
			f.ell(68, 62, 9, 6, PixelArt.shade(robe, -0.12))
			for r in range(4):
				for c in range(8):
					f.rect(14 + c * 6 + (r & 1) * 3, 66 + r * 4, 5, 3, PixelArt.shade(robe, 0.06 if (c + r) % 2 == 0 else -0.14))
			f.rect(6, 63, 68, 2, trim)
		"hanbok":
			# 짧은 저고리 + 치마(허리 위로 치켜 입은 한복): 동정, 길게 늘어진 고름
			var skirt_c := Color(String(sp.get("skirt", "8a7a5a")))
			var tie := Color(String(sp.get("tie", "c8283a")))
			f.spoly(PackedVector2Array([Vector2(10, 74), Vector2(14, 63), Vector2(23, 57), Vector2(57, 57), Vector2(66, 63), Vector2(70, 74), Vector2(60, 71), Vector2(20, 71)]), robe, 0.16, -0.3)
			f.line(14, 70, 66, 70, PixelArt.shade(skirt_c, -0.3))
			for k in range(9):
				f.line(8 + k * 8, 72, 4 + k * 9, 80, PixelArt.shade(skirt_c, -0.2))
			f.poly(PackedVector2Array([Vector2(31, 58), Vector2(49, 58), Vector2(40, 67)]), Color("f4f0e6"))
			f.line(31, 58, 40, 67, trim, 2)
			f.line(49, 58, 41, 67, trim, 2)
			f.poly(PackedVector2Array([Vector2(40, 66), Vector2(35, 72), Vector2(36, 79), Vector2(41, 71)]), tie)
			f.poly(PackedVector2Array([Vector2(41, 66), Vector2(47, 71), Vector2(46, 78), Vector2(41, 70)]), PixelArt.shade(tie, -0.2))
			f.rect(39, 65, 3, 3, PixelArt.shade(tie, 0.15))
		"monk":
			f.poly(PackedVector2Array([Vector2(30, 58), Vector2(50, 58), Vector2(40, 72)]), PixelArt.shade(robe, 0.22))
			f.line(30, 58, 40, 72, PixelArt.shade(robe, -0.3), 2)
			f.line(50, 58, 41, 72, PixelArt.shade(robe, -0.3), 2)
			# 가사 한 자락
			f.spoly(PackedVector2Array([Vector2(10, 66), Vector2(30, 60), Vector2(46, 80), Vector2(8, 80)]), Color("b3702a"), 0.14, -0.28)
	if bool(sp.get("ragged", false)):
		# 해진 옷: 덧댄 천 조각과 찢어진 소매
		f.rect(20, 68, 5, 4, PixelArt.shade(robe, 0.2))
		f.rect(50, 72, 6, 3, PixelArt.shade(robe, -0.25))
		f.rect(36, 63, 4, 3, PixelArt.shade(robe, 0.18))
		for k in range(6):
			f.px(8 + k * 12, 79, Color(0, 0, 0, 0))
			f.px(9 + k * 12, 78, Color(0, 0, 0, 0))
	if sp.get("emblem", "") == "dragon":
		f.ball(40, 72, 7, 6, Color("e0b83a"))
		f.ell(40, 72, 4, 3, Color("a31f1f"))
		f.px(40, 71, Color("f6d870"))
		for pp in [Vector2i(31, 68), Vector2i(49, 68), Vector2i(31, 76), Vector2i(49, 76)]:
			f.rect(pp.x, pp.y, 3, 3, Color("e0b83a"))
	if bool(sp.get("apron", false)):
		f.spoly(PackedVector2Array([Vector2(24, 66), Vector2(56, 66), Vector2(60, 80), Vector2(20, 80)]), Color("d8d0bc"), 0.1, -0.2)
		f.px(30, 72, Color("9e2a22"))
		f.px(31, 73, Color("9e2a22"))
		f.px(48, 70, Color("9e2a22"))
		f.px(36, 76, Color("b0332a"))
		f.px(42, 75, Color("9e2a22"))

# ─────────────────────────────────────────── 머리
static func _head(h: PixelArt, sp: Dictionary) -> void:
	var fc: Dictionary = sp["face"]
	var skin := Color(sp.get("skin", "f6d8b8" if bool(sp.get("female", false)) else "f1c9a0"))
	var skin_sh := PixelArt.shade(skin, -0.2)
	var ink := Color("231a14")
	var lean := bool(fc.get("lean", false))
	var age := int(fc.get("age", 0))
	var rx := 11.5 if lean else 12.5
	var hair := Color("26201c")
	var gray := age >= 2
	var hcol := Color("e9e7e2") if gray else hair
	var hat := String(sp["hat"])
	# 머리 모양
	h.soft_ball(40, 35, rx, 14.5, skin)
	if lean:
		h.poly(PackedVector2Array([Vector2(31, 42), Vector2(49, 42), Vector2(42, 51), Vector2(38, 51)]), skin)
	h.soft_ball(40 - rx - 0.5, 37, 2.0, 3.2, skin)
	h.soft_ball(40 + rx + 0.5, 37, 2.0, 3.2, skin)
	h.px(int(40 - rx - 1), 37, skin_sh)
	h.px(int(40 + rx), 37, skin_sh)
	if hat == "monk":
		# 삭발한 머리 + 윗머리 광택
		h.soft_ball(40, 27, rx - 0.5, 8, PixelArt.shade(skin, -0.02))
		h.px(35, 21, PixelArt.shade(skin, 0.35))
		h.px(36, 20, PixelArt.shade(skin, 0.35))
		h.px(34, 22, PixelArt.shade(skin, 0.25))
		for p in [Vector2i(36, 25), Vector2i(41, 24), Vector2i(45, 26)]:
			h.px(p.x, p.y, Color("a07858")) # 계인(戒印)
	# 눈
	var eyes := String(fc.get("eyes", "normal"))
	for ex in [34, 46]:
		match eyes:
			"narrow":
				h.rect(ex - 2, 36, 5, 2, Color("fbf8ee"))
				h.rect(ex - 1, 36, 3, 2, ink)
				h.rect(ex - 3, 35, 7, 1, Color("1a1410"))
			"big":
				h.rect(ex - 2, 35, 5, 5, Color("fbf8ee"))
				h.rect(ex - 1, 36, 3, 3, ink)
				h.px(ex - 1, 36, Color.WHITE)
			"stern":
				h.rect(ex - 2, 36, 5, 3, Color("fbf8ee"))
				h.rect(ex - 1, 36, 3, 3, ink)
				h.rect(ex - 3, 35, 7, 1, Color("1a1410"))
				h.px(ex + (3 if ex > 40 else -3), 36, Color("1a1410"))
			"soft":
				h.rect(ex - 2, 36, 5, 3, Color("fbf8ee"))
				h.rect(ex - 1, 36, 3, 3, ink)
				h.px(ex - 1, 36, Color.WHITE)
				h.rect(ex - 3, 35, 7, 1, Color("2a1a14"))
				h.px(ex + (3 if ex > 40 else -3), 36, Color("2a1a14"))
			"sleepy":
				h.rect(ex - 2, 37, 5, 2, Color("fbf8ee"))
				h.rect(ex - 1, 37, 3, 2, ink)
				h.rect(ex - 3, 36, 7, 1, PixelArt.shade(skin, -0.45))
			_:
				h.rect(ex - 1, 35, 3, 4, ink)
				h.px(ex - 1, 35, Color.WHITE)
				h.rect(ex - 2, 34, 5, 1, Color("5a4030"))
	# 눈썹
	var bc := Color("e8e6e0") if gray else Color("30241c")
	match String(fc.get("brows", "flat")):
		"angry":
			h.line(29, 30, 36, 33, bc, 2)
			h.line(44, 33, 51, 30, bc, 2)
		"soft":
			h.line(30, 32, 36, 31, bc)
			h.line(44, 31, 50, 32, bc)
		"white":
			h.line(29, 31, 36, 33, bc, 2)
			h.line(44, 33, 51, 31, bc, 2)
		"worry":
			h.line(30, 33, 36, 30, bc)
			h.line(44, 30, 50, 33, bc)
		_:
			h.line(30, 32, 36, 32, bc, 2)
			h.line(44, 32, 50, 32, bc, 2)
	# 코
	h.px(40, 40, skin_sh)
	h.px(40, 41, skin_sh)
	h.px(41, 41, skin_sh)
	h.px(39, 39, PixelArt.shade(skin, 0.3))
	# 입
	var mc := Color("7a2a20")
	match String(fc.get("mouth", "flat")):
		"smile":
			h.line(37, 45, 39, 47, mc)
			h.line(39, 47, 41, 47, mc)
			h.line(41, 47, 43, 45, mc)
		"open":
			h.rect(37, 45, 6, 4, mc)
			h.rect(38, 45, 4, 1, Color("f6f0e0"))
		"frown":
			h.line(37, 47, 43, 47, mc)
			h.px(36, 48, mc)
			h.px(44, 48, mc)
		_:
			h.line(37, 46, 43, 46, mc)
	if bool(sp.get("female", false)):
		h.rect(38, 46, 5, 1, Color("c8403a"))
		h.rect(39, 47, 3, 1, Color("d85a52"))
		h.rect(29, 41, 4, 3, Color(1.0, 0.55, 0.55, 0.38)) # 연지
		h.rect(48, 41, 4, 3, Color(1.0, 0.55, 0.55, 0.38))
	# 주름과 볼
	if age >= 1:
		h.line(35, 29, 45, 29, PixelArt.shade(skin, -0.1))
		h.px(30, 38, PixelArt.shade(skin, -0.14))
		h.px(50, 38, PixelArt.shade(skin, -0.14))
	if age >= 2:
		h.line(34, 27, 46, 27, PixelArt.shade(skin, -0.12))
		h.line(33, 42, 35, 45, PixelArt.shade(skin, -0.14))
		h.line(47, 42, 45, 45, PixelArt.shade(skin, -0.14))
	# 수염
	var st := String(fc.get("stache", "none"))
	var bd := String(fc.get("beard", "none"))
	if st == "thin":
		h.line(32, 43, 38, 42, hcol)
		h.line(48, 43, 42, 42, hcol)
		h.px(31, 44, hcol)
		h.px(49, 44, hcol)
	elif st == "bushy":
		h.spoly(PackedVector2Array([Vector2(31, 42), Vector2(39, 41), Vector2(39, 44), Vector2(32, 46)]), hcol)
		h.spoly(PackedVector2Array([Vector2(49, 42), Vector2(41, 41), Vector2(41, 44), Vector2(48, 46)]), hcol)
	elif st == "long":
		h.spoly(PackedVector2Array([Vector2(30, 42), Vector2(39, 41), Vector2(39, 44), Vector2(28, 49)]), hcol)
		h.spoly(PackedVector2Array([Vector2(50, 42), Vector2(41, 41), Vector2(41, 44), Vector2(52, 49)]), hcol)
	match bd:
		"goatee":
			h.poly(PackedVector2Array([Vector2(37, 48), Vector2(43, 48), Vector2(41, 58), Vector2(40, 60), Vector2(39, 58)]), hcol)
		"short":
			h.ball(40, 51, 6, 4.5, hcol)
			h.rect(36, 47, 8, 2, hcol)
		"full":
			h.ball(40, 51, 10.5, 7.5, hcol)
			h.rect(30, 44, 20, 5, hcol)
			h.line(37, 46, 43, 46, mc)
		"white":
			h.poly(PackedVector2Array([Vector2(31, 45), Vector2(49, 45), Vector2(47, 56), Vector2(42, 63), Vector2(38, 63), Vector2(33, 56)]), Color("ecebe6"))
			for k in range(5):
				h.px(36 + k * 2, 55 + (k & 1), Color("c4c2bc"))
			h.line(37, 46, 43, 46, mc)
		"stubble":
			for k in range(14):
				h.px(31 + (k * 5) % 19, 45 + (k * 3) % 6, PixelArt.shade(skin, -0.3))
	# 모자·머리카락
	_hat(h, sp, hcol)

static func _hat(h: PixelArt, sp: Dictionary, hcol: Color) -> void:
	var hat := String(sp["hat"])
	var black := Color("1c1c26")
	match hat:
		"samo":
			h.spoly(PackedVector2Array([Vector2(30, 21), Vector2(7, 20), Vector2(7, 23), Vector2(30, 25)]), Color("14141b"))
			h.spoly(PackedVector2Array([Vector2(50, 21), Vector2(73, 20), Vector2(73, 23), Vector2(50, 25)]), Color("14141b"))
			h.spoly(PackedVector2Array([Vector2(30, 28), Vector2(31, 13), Vector2(35, 8), Vector2(45, 8), Vector2(49, 13), Vector2(50, 28)]), black, 0.3, -0.2)
			h.rect(29, 25, 22, 3, Color("2e2e3c"))
			h.rect(29, 25, 22, 1, Color("b89a40"))
		"iksun":
			# 익선관: 둥근 관과 뒤로 솟은 두 날개
			h.spoly(PackedVector2Array([Vector2(33, 12), Vector2(20, 6), Vector2(18, 10), Vector2(30, 20)]), Color("14141b"))
			h.spoly(PackedVector2Array([Vector2(47, 12), Vector2(60, 6), Vector2(62, 10), Vector2(50, 20)]), Color("14141b"))
			h.line(20, 6, 33, 12, Color("c9a227"))
			h.line(60, 6, 47, 12, Color("c9a227"))
			h.spoly(PackedVector2Array([Vector2(30, 28), Vector2(30, 13), Vector2(35, 8), Vector2(45, 8), Vector2(50, 13), Vector2(50, 28)]), black, 0.3, -0.2)
			h.rect(29, 25, 22, 3, Color("3a3a48"))
			h.rect(29, 25, 22, 1, Color("e0b83a"))
			h.ball(40, 15, 2.5, 2.5, Color("e0b83a"))
		"gat":
			# 갓: 넓은 챙과 높은 모자, 늘어진 갓끈
			h.ell(40, 24, 21, 5.5, Color("22222c"))
			h.ell(40, 23, 21, 4.5, Color("33333f"))
			h.spoly(PackedVector2Array([Vector2(32, 24), Vector2(33, 9), Vector2(47, 9), Vector2(48, 24)]), black, 0.28, -0.22)
			h.ell(40, 9, 7, 2, Color("3a3a48"))
			_strings(h, Color("a0452a"))
		"jeongja":
			h.spoly(PackedVector2Array([Vector2(30, 28), Vector2(30, 14), Vector2(34, 14), Vector2(34, 9), Vector2(40, 12), Vector2(46, 9), Vector2(46, 14), Vector2(50, 14), Vector2(50, 28)]), black, 0.26, -0.22)
			h.rect(30, 24, 20, 4, Color("2a2a38"))
			h.rect(30, 24, 20, 1, Color("5a5a6a"))
		"pyeongjeong":
			h.spoly(PackedVector2Array([Vector2(30, 28), Vector2(30, 12), Vector2(50, 12), Vector2(50, 28)]), black, 0.26, -0.22)
			h.rect(30, 12, 20, 2, Color("3a3a48"))
			h.rect(30, 25, 20, 3, Color("2a2a38"))
			h.line(30, 20, 50, 20, Color("2a2a38"))
		"jeonlip":
			# 전립: 챙이 넓은 군모, 붉은 상모와 끈
			h.ell(40, 25, 20, 5, Color("2a2420"))
			h.ell(40, 24, 20, 4, Color("3a322c"))
			h.ball(40, 19, 12.5, 9, Color("2a2a30"))
			h.ell(40, 24, 13, 2, Color("8e2a2a"))
			h.ball(40, 9, 3.2, 3.2, Color("c0392b"))
			for k in range(5):
				h.line(40, 10, 38 + k * 1, 4 + (k & 1), Color("e04a38"))
			_strings(h, Color("c0392b"))
		"helmet":
			h.ball(40, 22, 14, 11, Color("747c86"))
			h.rect(26, 24, 28, 4, Color("565e68"))
			h.rect(26, 24, 28, 1, Color("d4af37"))
			h.poly(PackedVector2Array([Vector2(39, 4), Vector2(41, 4), Vector2(42, 12), Vector2(38, 12)]), Color("b8c0c8"))
			h.ball(40, 5, 2.4, 2.4, Color("c0392b"))
			h.spoly(PackedVector2Array([Vector2(27, 28), Vector2(30, 28), Vector2(30, 44), Vector2(26, 38)]), Color("565e68"))
			h.spoly(PackedVector2Array([Vector2(53, 28), Vector2(50, 28), Vector2(50, 44), Vector2(54, 38)]), Color("565e68"))
		"pyeongnang":
			# 패랭이: 대나무 챙 모자(상인·보부상·백정)
			h.ell(40, 23, 19, 4.5, Color("c8a868"))
			h.ell(40, 22, 19, 3.5, Color("dcc080"))
			h.spoly(PackedVector2Array([Vector2(31, 23), Vector2(33, 11), Vector2(47, 11), Vector2(49, 23)]), Color("d0b070"), 0.2, -0.24)
			for k in range(6):
				h.line(33 + k * 3, 11, 31 + k * 3, 23, Color("b09050"))
			_strings(h, Color("a03a2a"))
			h.rect(31, 12, 18, 2, Color("a03a2a"))
		"satgat":
			# 삿갓: 넓고 납작한 원뿔 삿갓
			h.spoly(PackedVector2Array([Vector2(40, 6), Vector2(66, 28), Vector2(14, 28)]), Color("d4b878"), 0.2, -0.26)
			for k in range(7):
				h.line(40, 8, 17 + k * 7, 27, Color("b89858"))
			h.line(15, 28, 65, 28, Color("9a7a3a"))
			_strings(h, Color("a03a2a"))
		"furcap":
			# 털모자(귀덮개)
			h.ball(40, 22, 14, 10, Color("8a6a46"))
			h.ball(28, 36, 4.5, 6, Color("7a5a3a"))
			h.ball(52, 36, 4.5, 6, Color("7a5a3a"))
			h.rect(27, 25, 26, 3, Color("c8b088"))
			for k in range(8):
				h.px(28 + k * 3, 16 + (k * 7) % 6, Color("b89a70"))
		"topknot":
			# 상투와 망건
			h.ell(40, 24, 12.7, 6, hcol)
			h.rect(28, 25, 24, 3, Color("8a6a48"))
			h.rect(28, 25, 24, 1, Color("a88a60"))
			h.ball(40, 14, 4.5, 4.5, hcol)
			h.rect(38, 17, 4, 3, Color("a04a2a")) # 동곳
		"headband":
			h.ell(40, 24, 12.7, 6, hcol)
			h.ball(40, 14, 4.5, 4.5, hcol)
			var bandc := Color("b22222") if String(sp["hat"]) == "headband_red" else Color("efe6d4")
			h.rect(27, 25, 26, 3, bandc)
			h.px(53, 26, bandc)
			h.px(54, 27, bandc)
			h.px(54, 28, bandc)
		"headband_red":
			h.ell(40, 24, 12.7, 6, hcol)
			h.ball(40, 14, 4.5, 4.5, hcol)
			h.rect(27, 25, 26, 3, Color("c02a22"))
			h.line(53, 26, 58, 33, Color("c02a22"))
			h.line(52, 27, 56, 36, Color("a02018"))
		"scarf":
			# 머릿수건: 쪽 찐 머리 위로 흰 천을 둘러 묶었다
			h.ell(40, 25, 12.8, 6.5, hcol)
			h.spoly(PackedVector2Array([Vector2(27, 27), Vector2(29, 15), Vector2(40, 10), Vector2(51, 15), Vector2(53, 27), Vector2(40, 22)]), Color("f1ede3"), 0.1, -0.2)
			h.line(30, 24, 50, 24, Color("d8d2c4"))
			h.ball(28, 26, 3.4, 3.0, Color("e8e2d4"))
			h.ball(52, 26, 3.4, 3.0, Color("e8e2d4"))
		"jangot":
			# 장옷: 양반댁 부녀가 외출할 때 머리에서 어깨로 길게 덮어쓰는 천
			h.ell(40, 25, 12.8, 6.5, hcol)
			h.spoly(PackedVector2Array([Vector2(20, 52), Vector2(22, 24), Vector2(31, 10), Vector2(49, 10), Vector2(58, 24), Vector2(60, 52), Vector2(53, 40), Vector2(52, 30), Vector2(28, 30), Vector2(27, 40)]), Color("5fa57e"), 0.16, -0.3)
			h.line(31, 11, 49, 11, Color("8cc8a4"))
			h.line(28, 30, 52, 30, Color("3f7a5c"))
		"gache":
			# 큰머리(가체): 높게 틀어 올린 머리에 떨잠·비녀·붉은 댕기
			h.ell(40, 25, 13, 7, hcol)
			h.ball(40, 14, 16, 8, hcol)
			h.ball(40, 8, 10, 5, hcol)
			h.line(22, 14, 58, 14, Color("e0b83a"), 1)
			h.ball(22, 14, 2, 2, Color("c0392b"))
			h.ball(58, 14, 2, 2, Color("c0392b"))
			h.ball(40, 6, 2.2, 2.2, Color("57c0a8"))
			h.ball(31, 10, 1.8, 1.8, Color("e8c860"))
			h.ball(49, 10, 1.8, 1.8, Color("e8c860"))
			h.line(26, 20, 24, 40, Color("c0392b"), 2)
		"bun_w":
			# 쪽머리: 가운데 가르마, 목덜미 쪽 위로 비녀
			h.ell(40, 25, 12.8, 6.5, hcol)
			h.line(40, 19, 40, 24, PixelArt.shade(hcol, 0.45))
			h.ball(40, 16, 6, 4.5, hcol)
			h.line(31, 15, 49, 15, Color("e0b83a"), 1)
			h.px(31, 15, Color("c0392b"))
		"braid_w":
			# 두 갈래 땋은 머리와 붉은 댕기
			h.ell(40, 25, 12.8, 6.5, hcol)
			h.rect(30, 27, 20, 2, hcol)
			h.line(28, 28, 25, 50, hcol, 3)
			h.line(52, 28, 55, 50, hcol, 3)
			h.rect(23, 49, 4, 3, Color("c0392b"))
			h.rect(53, 49, 4, 3, Color("c0392b"))
		"kid_boy":
			# 아이의 짧은 상투와 앞머리, 붉은 댕기
			h.ell(40, 24, 12.7, 6, hcol)
			h.rect(30, 27, 20, 2, hcol)
			h.ball(40, 15, 3.6, 3.6, hcol)
			h.rect(39, 17, 3, 2, Color("c0392b"))
		"messy":
			# 헝클어진 머리
			h.ell(40, 24, 13, 7, hcol)
			for k in range(9):
				var sx := 29 + k * 3
				h.line(sx, 22, sx - 1 + (k % 3), 14 + (k * 5) % 5, hcol)
		"monk":
			pass

## 모자 끈: 귀 옆으로 내려와 턱 밑에서 맺는다
static func _strings(h: PixelArt, c: Color) -> void:
	h.line(26, 26, 26, 43, c)
	h.line(26, 43, 34, 51, c)
	h.line(54, 26, 54, 43, c)
	h.line(54, 43, 46, 51, c)
	h.px(26, 41, Color("e8c860"))
	h.px(54, 41, Color("e8c860"))

# ─────────────────────────────────────────── 물건
static func skin_hand(sp: Dictionary) -> Color:
	return Color(sp.get("skin", "f6d8b8" if bool(sp.get("female", false)) else "f1c9a0"))

static func _hand(f: PixelArt, x: int, y: int, sp: Dictionary) -> void:
	f.soft_ball(x, y, 3.2, 2.8, Color(sp.get("skin", "f6d8b8" if bool(sp.get("female", false)) else "f1c9a0")))

static func _item_back(f: PixelArt, it: String) -> void:
	match it:
		"spear":
			f.line(68, 80, 68, 8, Color("7a5230"), 2)
			f.poly(PackedVector2Array([Vector2(68, 0), Vector2(71, 10), Vector2(68, 12), Vector2(65, 10)]), Color("b8c0c8"))
			f.rect(65, 12, 7, 2, Color("b22222"))
			f.px(66, 14, Color("b22222"))
			f.px(70, 14, Color("b22222"))
		"hoe":
			f.line(70, 80, 62, 20, Color("8a6a40"), 2)
			f.poly(PackedVector2Array([Vector2(56, 18), Vector2(66, 18), Vector2(68, 24), Vector2(58, 26)]), Color("6a727a"))
		"axe":
			f.line(68, 80, 60, 22, Color("8a6a40"), 2)
			f.poly(PackedVector2Array([Vector2(52, 18), Vector2(62, 16), Vector2(62, 28), Vector2(54, 26)]), Color("7a828a"))
			f.px(53, 20, Color("c8d0d8"))
		"bow":
			var pts := PackedVector2Array()
			for k in range(13):
				var t := float(k) / 12.0
				pts.append(Vector2(8.0 - sin(t * PI) * 6.0, 14.0 + t * 54.0))
			for k in range(pts.size() - 1):
				f.line(int(pts[k].x), int(pts[k].y), int(pts[k + 1].x), int(pts[k + 1].y), Color("6a4a2a"), 2)
			f.line(8, 14, 8, 68, Color("e8e0c8"))
		"jige":
			# 지게와 땔나무 단
			f.line(10, 76, 12, 26, Color("7a5a38"), 2)
			f.line(22, 76, 18, 30, Color("7a5a38"), 2)
			for k in range(6):
				f.line(8 + k * 2, 26, 6 + k * 3, 8 + (k & 1) * 3, Color("8a6a40" if k % 2 == 0 else "6a4a2a"), 2)
			f.rect(8, 22, 14, 3, Color("a89060"))
		"sword":
			f.line(10, 80, 66, 22, Color("c8d0d8"), 2)
			f.line(10, 80, 66, 22, Color("e8f0f8"), 1)
			f.line(8, 82, 14, 76, Color("d4af37"), 3)
		"staff":
			f.line(68, 80, 68, 10, Color("7a5230"), 2)
			f.ell(68, 9, 4, 4, Color("c8a040"))
			f.ell(68, 9, 2, 2, Color("ece4cc"))
			f.px(68, 15, Color("c8a040"))
		"bundle":
			f.ball(13, 53, 10, 9, Color("c8b078"))
			f.rect(10, 42, 6, 3, Color("a89060"))
			f.line(9, 44, 18, 50, Color("8a7040"))
		_:
			pass

static func _item_front(f: PixelArt, it: String, sp: Dictionary) -> void:
	match it:
		"hammer":
			f.line(17, 78, 24, 54, Color("7a5230"), 3)
			f.rect(18, 48, 12, 7, Color("5a626a"))
			f.rect(18, 48, 12, 2, Color("9aa2aa"))
			_hand(f, 18, 72, sp)
		"brush":
			f.line(63, 78, 58, 50, Color("8a6a40"), 2)
			f.poly(PackedVector2Array([Vector2(56, 52), Vector2(60, 52), Vector2(59, 44), Vector2(57, 44)]), Color("1a1a1a"))
			f.px(57, 45, Color("5a5a5a"))
			f.rect(10, 68, 12, 10, Color("e8e0cc")) # 두루마리 화폭
			f.rect(10, 68, 12, 1, Color("8a6a3a"))
			f.px(14, 73, Color("2a6a4a"))
			f.px(17, 71, Color("4a7a9a"))
			_hand(f, 62, 74, sp)
		"scroll":
			f.rect(22, 70, 36, 6, Color("efe6c8"))
			f.rect(20, 69, 3, 8, Color("8a6a3a"))
			f.rect(57, 69, 3, 8, Color("8a6a3a"))
		"book":
			f.rect(50, 62, 14, 16, Color("2a4a7a"))
			f.rect(50, 62, 2, 16, Color("1a3260"))
			f.rect(63, 63, 1, 14, Color("f2ead0"))
			for k in range(4):
				f.px(54, 64 + k * 4, Color("e8dcb8"))
			_hand(f, 58, 76, sp)
		"blueprint":
			f.rect(42, 62, 26, 16, Color("cfe0ee"))
			f.rect(42, 62, 26, 1, Color("5a7a9a"))
			f.rect(42, 77, 26, 1, Color("5a7a9a"))
			for k in range(1, 6):
				f.px(42 + k * 4, 70, Color("5a7a9a"))
				f.line(42 + k * 4, 64, 42 + k * 4, 75, Color("9ab8d0"))
			f.rect(46, 66, 8, 6, Color("5a7a9a"))
			f.rect(47, 67, 6, 4, Color("cfe0ee"))
			f.line(56, 66, 64, 74, Color("5a7a9a"))
			_hand(f, 44, 76, sp)
		"hol":
			f.spoly(PackedVector2Array([Vector2(56, 62), Vector2(61, 60), Vector2(63, 76), Vector2(58, 78)]), Color("f0ead6"), 0.1, -0.25)
			_hand(f, 59, 72, sp)
		"abacus":
			f.rect(46, 62, 20, 13, Color("6a4a2a"))
			f.rect(48, 64, 16, 9, Color("d8c08a"))
			for r in range(3):
				f.line(48, 65 + r * 3, 63, 65 + r * 3, Color("8a6a3a"))
				for c in range(5):
					f.rect(49 + c * 3, 64 + r * 3, 2, 2, Color("2a2018"))
			_hand(f, 46, 76, sp)
		"ledger":
			f.rect(46, 62, 18, 14, Color("e8dcb8"))
			f.rect(46, 62, 18, 2, Color("8a6a3a"))
			for k in range(4):
				f.line(49, 67 + k * 2, 61, 67 + k * 2, Color("8a7a5a"))
			f.rect(60, 70, 3, 3, Color("b22222"))
			_hand(f, 48, 77, sp)
		"knife":
			f.poly(PackedVector2Array([Vector2(60, 56), Vector2(68, 60), Vector2(62, 74), Vector2(58, 72)]), Color("c8d0d8"))
			f.line(60, 57, 59, 72, Color("eef4fa"))
			f.rect(57, 72, 5, 6, Color("5a3a22"))
			_hand(f, 59, 77, sp)
		"fan":
			var fp := PackedVector2Array()
			fp.append(Vector2(56, 78))
			for k in range(9):
				var ang := deg_to_rad(-160.0 + float(k) * 17.5)
				fp.append(Vector2(56.0 + cos(ang) * 18.0, 78.0 + sin(ang) * 18.0))
			f.poly(fp, Color("f4ecd0"))
			for k in range(1, 9):
				var ang2 := deg_to_rad(-160.0 + float(k) * 17.5)
				f.line(56, 78, int(56.0 + cos(ang2) * 18.0), int(78.0 + sin(ang2) * 18.0), Color("b89a6a"))
			f.ball(56, 78, 2.4, 2.4, skin_hand(sp))
		"basket":
			f.ell(17, 74, 11, 5, Color("c8a868"))
			f.ell(17, 72, 11, 3, Color("a88848"))
			for k in range(5):
				f.ball(float(11 + k * 3), float(68 + (k & 1)), 2.4, 2.4, Color("4a9a40") if k % 2 == 0 else Color("7ac060"))
			f.ball(16, 78, 3, 2.4, skin_hand(sp))
		"gayageum":
			f.poly(PackedVector2Array([Vector2(4, 73), Vector2(76, 68), Vector2(77, 76), Vector2(6, 80)]), Color("8a5a2a"))
			f.poly(PackedVector2Array([Vector2(6, 73), Vector2(75, 69), Vector2(76, 71), Vector2(6, 75)]), Color("b88a52"))
			for k in range(12):
				var gx := 10 + k * 5
				var y_off := int(float(k * 5) / 12.0)
				f.line(gx, 74 - y_off, gx + 1, 78 - y_off, Color("f4efe0"))
			f.ball(30, 79, 3, 2.4, skin_hand(sp))
		"beads":
			for k in range(11):
				var t := float(k) / 10.0
				var bx := 29.0 + t * 22.0
				var by := 61.0 + sin(t * PI) * 12.0
				f.ball(bx, by, 1.9, 1.9, Color("6a3a22"))
			f.ball(40, 76, 2.4, 2.4, Color("8a4a2a"))
		_:
			pass
