extends RefCounted
class_name NpcSprites

const SpriteCacheManager = preload("res://scripts/autoload/SpriteCacheManager.gd")
## PORT-TRACE [NPC 도트 스프라이트 캐시]: 사용자 요청 — "도형을 붙여 놓은 모양"인 사람을 참고 그림(조선 인물 도트 시트)처럼.
## 외부 그림 파일은 쓰지 않는다: 처음 필요할 때 코드가 24x32 도트를 한 칸씩 찍어(머리·옷·갓·소품 → 면 음영 → 1px 외곽선
## → 발밑 그림자) 아틀라스에 구워 두고, 매 프레임에는 그 칸을 한 장씩 찍기만 한다(도형 수십 개를 그리던 것보다 싸다).
## 방향 4(앞-오른·앞-왼·뒤-오른·뒤-왼; 왼쪽은 오른쪽을 좌우 뒤집어 구움) × 걷기 4프레임. 한 줄 = 종류·색 변형·겨울옷 하나.
## 등각 지도에서 그리드 +x로 걸으면 화면 오른쪽 아래(앞-오른), +y는 왼쪽 아래(앞-왼), -y는 오른쪽 위(뒤-오른), -x는 왼쪽 위(뒤-왼).

const W := 24
const H := 32
const FOOT := Vector2(12, 30) # 칸 안에서 발 위치(= 에이전트 좌표)
const FRAMES := 4
const DIRS := 4
const MAX_ROWS := 320
const ROW_BLOCKS := 4 # 아틀라스 한 가로줄에 인물 줄 4개(텍스처가 너무 길어지지 않게)

const OUTLINE := Color("1e1712")
const SKIN := Color("efc49c")
const HAIR := Color("1c1612")
const EYE := Color("2a1a14")
const WHITE := Color("f1ede3")
const STRAW := Color("c9a86a")
const CLEAR := Color(0, 0, 0, 0)

static var _img: Image
static var _tex: ImageTexture
static var _ctex: CanvasTexture
static var _rows := {}
static var _next_row := 0
static var _c: Image # 지금 찍고 있는 한 칸
## PORT-TRACE [NPC 도트 스프라이트 3단계]: 장면 속 사람(축제 관람객·놀이마당·관아 등)은 옷 색이 제각각이라
## 기본 모양(base) + 색 세 가지로 그때그때 종류를 만든다(같은 조합은 한 번만 굽는다).
static var _custom := {}
## PORT-TRACE [작은 장면 인물]: 건물·마당 안 장면을 그리는 동안만 true — 같은 인물을 70% 크기로 다시 찍은 칸을 쓴다
## (큰 그림을 줄여 찍는 게 아니라, 색칠 단계에서 줄인 뒤 외곽선·음영·그림자를 작은 크기에 새로 입혀 도트가 선명).
static var small := false
const SMALL_K := 0.9 # PORT-TRACE [크기 통일]: 놀이마당·관아 등 장면 인물을 0.7배로 줄여 그리니 길 위 사람과 견줘 소인국 같았다
## 역사 인물은 눈에 띄게 조금만 크게(예전 0.84는 일반 0.70보다 20% 커서 거인처럼 보였다)
const NAMED_SCALE := 0.74
## PORT-TRACE [크기 통일 2]: 사용자 — "모든 NPC는 가장 작은 NPC(연 날리는 아이·낚시꾼)와 일반 NPC의 중간 크기가 알맞다,
## 그래야 길을 찾아 다니고 건물 안에서 일하는 것처럼 보인다". 어른 그림을 BODY_K배(0.70 → 약 0.55)로 줄인다. 아이는 그대로.
## 거리의 에이전트는 CitizenLayer가 발밑을 기준으로 그림 전체(소품 포함)를 BODY_K배로 줄여 그리므로 그동안 body_k = 1.
const BODY_K := 0.79
static var body_k := BODY_K
## 바깥에서 걸어 둔 그리기 변환(발밑 기준 축소) — 동작 그림이 변환을 풀 때 이것으로 되돌린다
static var base_xf := Transform2D.IDENTITY
## 앉거나 무릎 꿇은 동작 그림은 시트에서 너무 작게 잘려 들어갔다 → 서 있는 사람에 맞게 키움
const ACTION_K := {"npc_fisherman__fish": 1.25, "npc_peasant_woman__wash": 1.25}

static func set_xf(ci: CanvasItem, origin: Vector2, rot: float, scl: Vector2) -> void:
	ci.draw_set_transform_matrix(base_xf * Transform2D(rot, scl, 0.0, origin))

static func reset_xf(ci: CanvasItem) -> void:
	ci.draw_set_transform_matrix(base_xf)

## 어른 크기(0.55 넘는 배율)만 body_k로 줄인다 — 아이(0.52)는 그대로
static func adult_k(scale_val: float) -> float:
	return scale_val * body_k if scale_val > 0.55 else scale_val

static func custom_kind(base: String, top: Color, bottom: Color, acc: Color, extra: Dictionary = {}) -> String:
	var key := "c:%s:%s:%s:%s:%s" % [base, top.to_html(false), bottom.to_html(false), acc.to_html(false), str(extra)]
	if not _custom.has(key):
		_custom[key] = {"base": base, "top": top, "bottom": bottom, "acc": acc, "extra": extra}
	return key

## 종류별 색 변형(옷 위·아래·띠/고름). 같은 종류라도 id에 따라 다른 옷을 입는다.
const PALETTES := {
	"yangban": [["2f4f8a", "2f4f8a", "b8352a"], ["e8e4d8", "e8e4d8", "3a5aa0"], ["6a8caf", "6a8caf", "8a2a2a"], ["7a6a8a", "7a6a8a", "c8a040"]],
	"seonbi": [["dfe9ee", "dfe9ee", "3a5aa0"], ["bcd8d0", "bcd8d0", "2a4a7a"], ["f0ece0", "f0ece0", "6a3a3a"], ["c8d8e8", "c8d8e8", "3a3a6a"]],
	"hallyang": [["6a3a8a", "6a3a8a", "e0b040"], ["2f7a4a", "2f7a4a", "c83a5a"], ["a83a3a", "a83a3a", "3a6ab0"], ["3a5aa0", "3a5aa0", "e07a3a"]],
	"lady": [["e88aa0", "2e3a6a", "c8283a"], ["f0d070", "b8283a", "3a5aa0"], ["8acaa8", "5a3a7a", "c8283a"], ["f2eee4", "3a4a8a", "8a2a6a"]],
	"commoner_m": [["d8c8a0", "c8b890", "8a7a5a"], ["c0b090", "b0a080", "6a5a40"], ["e6e0d0", "d8d0c0", "8a7a5a"], ["a8a090", "9a9282", "5a5040"]],
	"commoner_w": [["e6dcc0", "8a7a5a", "a05a3a"], ["ece6d8", "6a7a8a", "8a3a3a"], ["d8c8a0", "7a5a3a", "6a5a40"], ["e0d8c8", "5a6a4a", "a05a3a"]],
	"merchant": [["8a6a48", "7a5a3a", "a07850"], ["6a5a48", "5a4a3a", "b08a58"], ["9a8060", "8a7050", "7a5a3a"], ["7a6a58", "6a5a48", "a08060"]],
	"porter": [["c8b890", "b0a080", "6e4a2c"], ["b0a080", "a09070", "6e4a2c"], ["d8ccb0", "c0b090", "6e4a2c"], ["a89878", "988868", "6e4a2c"]],
	"cheonmin": [["8a8478", "7a7468", "5a5448"], ["9a9080", "8a8070", "5a5448"], ["7a7468", "6a6458", "4a4438"], ["a09888", "908878", "5a5448"]],
	"jumo": [["6a8a4a", "2e3a6a", "c8283a"], ["8a6a9a", "3a3a5a", "c8283a"], ["c8a060", "4a3a5a", "8a2a2a"], ["5a8a8a", "3a3a6a", "c8283a"]],
	"soldier": [["2a3550", "a83228", "c8a040"], ["3a2a2a", "2a4a8a", "c8a040"], ["2a3550", "2a6a4a", "c8a040"], ["2a3550", "a83228", "c8a040"]],
	"official": [["2a4a9a", "2a4a9a", "1a1a1a"], ["a82a2a", "a82a2a", "1a1a1a"], ["3a7a5a", "3a7a5a", "1a1a1a"], ["2a4a9a", "2a4a9a", "1a1a1a"]],
	# PORT-TRACE [NPC 도트 스프라이트 2단계]: 아이·기생과 직업별 인물
	"gisaeng": [["5aa83a", "c8283a", "e0b040"], ["e88aa0", "3a4a8a", "c8283a"], ["f0d070", "8a2a6a", "c8283a"], ["8acaa8", "c8283a", "3a5aa0"]],
	"child_m": [["e6dcc0", "c8b890", "8a7a5a"], ["c8d8a0", "b0a080", "6a5a40"], ["d8c0c0", "a89070", "8a3a3a"], ["c0d0e0", "a0a8b0", "5a5040"]],
	"child_f": [["f0b8c8", "c8283a", "c8283a"], ["f0d070", "3a4a8a", "c8283a"], ["c8e0c0", "8a3a6a", "c8283a"], ["f2eee4", "b8283a", "3a5aa0"]],
	"jungin": [["7aa5b8", "7aa5b8", "2a4a6a"]],
	"ajeon": [["8e2a3a", "8e2a3a", "1a1a1a"]],
	"monk": [["8a8c8e", "7a7c7e", "b83b32"]],
	"butcher": [["5c4a3a", "4a3a2e", "3a281c"]],
	"hunter": [["ece8df", "3d312a", "5c3a21"]],
	"fireman": [["1f2937", "1f2937", "ef4444"]],
	"patrol": [["1864ab", "2a2a30", "c92a2a"]],
	"najol": [["2a2a30", "2a2a30", "a8322a"]],
	"trooper": [["1b2631", "3a3030", "b03a2e"], ["117864", "3a3030", "d4ac0d"], ["922b21", "3a3030", "3498db"], ["1d3557", "3a3030", "d90429"]],
	"bandit": [["2b221d", "2b221d", "c92a2a"]],
	"rebel": [["5a1e1a", "4a1a16", "d02a20"]],
	"horde": [["9a8a6a", "8a7a5a", "6a5a40"]],
	"militia": [["d4c7b0", "c4b8a0", "a93226"]],
	"traitor": [["17202a", "17202a", "34495e"]],
	"refugee": [["e8ecf0", "8a9ab0", "7a3a3a"]],
	"supply": [["f7f9f9", "2e4053", "78281f"]],
	"washer": [["f7f7f5", "1b375e", "8a2a3a"]],
	"fisher": [["ebe6dc", "d8d0c0", "8c663b"]],
	"farmer": [["d8ccb0", "c8bca0", "8a7a5a"], ["e6e0d0", "b8a888", "6a5a40"]],
	"artisan": [["c8b894", "b0a080", "6a5a40"]],
	"mason": [["dedad0", "c8c0b0", "8a7a6a"]],
	"laborer": [["3b4252", "3b4252", "6a5a40"]],
	"foreman": [["2e4a6e", "2e4a6e", "b8352a"]],
	"messenger": [["1b4478", "2a2a30", "d69a1e"]],
	"bearer": [["e8dcc4", "d8ccb0", "8a7a5a"], ["f0ece4", "d8d0c0", "6a5a40"]],
	"saposu": [["8a6a46", "5a4a38", "3a2a1a"]],
	"yusaeng": [["9ec0de", "9ec0de", "2e4a7a"]],
	"bobusang": [["d8ccb0", "c0b090", "b08a3a"]],
	"porter_e": [["c8b890", "b0a080", "6e4a2c"]],
	"simmani": [["c8bca0", "b0a488", "8a7a4a"]],
	"peddler_w": [["e8dcd0", "6a5a4a", "8a3a3a"]],
	"book_peddler": [["f2eee4", "d8d0c0", "2e4a7a"]],
	"prisoner": [["ece6d8", "ddd6c6", "8a6a3a"]],
	"pungmul": [["f2eee4", "f2eee4", "c0392b"], ["f2eee4", "f2eee4", "1f5fa8"], ["f2eee4", "f2eee4", "e8b820"], ["f2eee4", "f2eee4", "2e8b57"]],
	"named_jy": [["f7f7f5", "f7f7f5", "3a5aa0"]],
	"named_yu": [["d0e3d5", "d0e3d5", "2a6a4a"]],
	"painter": [["594432", "4a3a2a", "8a7a5a"]],
	"named_bau": [["e8e4d8", "8a7a6a", "695441"]],
	"general": [["2d3b4a", "8a2a20", "d4af37"]],
	"shopkeeper": [["f2eee4", "d8d0c0", "6a7a8a"]],
	"woodcutter": [["ebe6dc", "c8c0b0", "5e3c1d"]],
}

## 종류별 모양: 옷 형태, 쓰개, 신, 소품
const SHAPES := {
	"yangban": {"garment": "robe", "hat": "gat", "shoe": "black", "prop": ""},
	"seonbi": {"garment": "robe", "hat": "gat", "shoe": "black", "prop": "book"},
	"hallyang": {"garment": "robe", "hat": "gat", "shoe": "black", "prop": "fan", "rainbow": true},
	"lady": {"garment": "skirt", "hat": "gache", "shoe": "white", "prop": ""},
	"commoner_m": {"garment": "jacket", "hat": "topknot", "shoe": "straw", "prop": ""},
	"commoner_w": {"garment": "skirt", "hat": "scarf", "shoe": "white", "prop": "basket", "apron": true},
	"merchant": {"garment": "jacket", "hat": "paeraengi", "shoe": "straw", "prop": "pack"},
	"porter": {"garment": "jacket", "hat": "headband", "shoe": "straw", "prop": "jige"},
	"cheonmin": {"garment": "jacket", "hat": "messy", "shoe": "bare", "prop": "", "ragged": true},
	"jumo": {"garment": "skirt", "hat": "bun", "shoe": "white", "prop": "", "apron": true},
	"soldier": {"garment": "armor", "hat": "jeonrip", "shoe": "boot", "prop": "spear"},
	"official": {"garment": "dalyeong", "hat": "samo", "shoe": "boot", "prop": ""},
	"gisaeng": {"garment": "skirt", "hat": "gache", "shoe": "white", "prop": "gayageum"},
	"child_m": {"garment": "jacket", "hat": "kid_boy", "shoe": "straw", "prop": "", "child": true},
	"child_f": {"garment": "skirt", "hat": "braid", "shoe": "white", "prop": "", "child": true},
	"jungin": {"garment": "robe", "hat": "gat", "shoe": "black", "prop": "medbox"},
	"ajeon": {"garment": "robe", "hat": "tanggeon", "shoe": "black", "prop": "book"},
	"monk": {"garment": "robe", "hat": "satgat", "hat_col": "b89a6a", "shoe": "straw", "prop": "staff", "sash": true},
	"butcher": {"garment": "jacket", "hat": "headband", "shoe": "straw", "prop": "", "apron": true, "apron_acc": true},
	"hunter": {"garment": "jacket", "hat": "pae2", "shoe": "straw", "prop": "", "vest": true},
	"fireman": {"garment": "jacket", "hat": "hood", "shoe": "boot", "prop": "", "belt": true},
	"patrol": {"garment": "jacket", "hat": "jeonrip", "shoe": "boot", "prop": "", "vest": true},
	"najol": {"garment": "jacket", "hat": "jeonrip", "shoe": "boot", "prop": "", "vest": true},
	"trooper": {"garment": "cheollik", "hat": "felt", "shoe": "boot", "prop": "", "plume": true},
	"bandit": {"garment": "jacket", "hat": "mask", "shoe": "straw", "prop": "", "belt": true},
	"rebel": {"garment": "jacket", "hat": "redband", "shoe": "straw", "prop": "", "ragged": true},
	"horde": {"garment": "jacket", "hat": "headband", "shoe": "bare", "prop": "", "ragged": true},
	"militia": {"garment": "jacket", "hat": "redband", "shoe": "straw", "prop": "", "belt": true},
	"traitor": {"garment": "robe", "hat": "satgat", "hat_col": "34495e", "shoe": "black", "prop": ""},
	"refugee": {"garment": "skirt", "hat": "bun", "shoe": "white", "prop": ""},
	"supply": {"garment": "skirt", "hat": "scarf", "shoe": "white", "prop": ""},
	"washer": {"garment": "skirt", "hat": "bun", "shoe": "white", "prop": ""},
	"fisher": {"garment": "jacket", "hat": "satgat", "hat_col": "8c663b", "shoe": "straw", "prop": ""},
	"farmer": {"garment": "jacket", "hat": "straw", "shoe": "straw", "prop": ""},
	"artisan": {"garment": "jacket", "hat": "headband", "shoe": "straw", "prop": ""},
	"mason": {"garment": "jacket", "hat": "headband", "shoe": "straw", "prop": ""},
	"laborer": {"garment": "jacket", "hat": "headband", "shoe": "straw", "prop": ""},
	"foreman": {"garment": "robe", "hat": "gat", "shoe": "black", "prop": ""},
	"messenger": {"garment": "jacket", "hat": "felt", "shoe": "boot", "prop": ""},
	"bearer": {"garment": "jacket", "hat": "headband", "shoe": "straw", "prop": ""},
	"saposu": {"garment": "jacket", "hat": "felt", "shoe": "straw", "prop": ""},
	"yusaeng": {"garment": "robe", "hat": "yugeon", "shoe": "black", "prop": ""},
	"bobusang": {"garment": "jacket", "hat": "paeraengi", "shoe": "straw", "prop": "jige"},
	"porter_e": {"garment": "jacket", "hat": "headband", "shoe": "straw", "prop": "jige_e"},
	"simmani": {"garment": "jacket", "hat": "headband", "shoe": "straw", "prop": ""},
	"peddler_w": {"garment": "skirt", "hat": "bun", "shoe": "white", "prop": ""},
	"book_peddler": {"garment": "jacket", "hat": "paeraengi", "shoe": "straw", "prop": "pack"},
	"prisoner": {"garment": "jacket", "hat": "messy", "shoe": "bare", "prop": "", "ragged": true},
	"pungmul": {"garment": "jacket", "hat": "felt", "shoe": "straw", "prop": "", "sash": true},
	"named_jy": {"garment": "robe", "hat": "gat", "shoe": "black", "prop": ""},
	"named_yu": {"garment": "robe", "hat": "gat", "shoe": "black", "prop": ""},
	"painter": {"garment": "jacket", "hat": "tanggeon", "shoe": "straw", "prop": ""},
	"named_bau": {"garment": "jacket", "hat": "headband", "shoe": "straw", "prop": "", "vest": true},
	"general": {"garment": "armor", "hat": "helmet", "shoe": "boot", "prop": ""},
	"shopkeeper": {"garment": "jacket", "hat": "headband", "shoe": "straw", "prop": "", "apron": true, "apron_acc": true},
	"woodcutter": {"garment": "jacket", "hat": "headband", "shoe": "straw", "prop": ""},
}

## 장 보러 나온 백성(shopper) 무리: 평민이 가장 많고 양반·부녀·상인·선비·한량·천민·주모가 섞인다
const CROWD := ["commoner_m", "commoner_w", "commoner_m", "commoner_w", "yangban", "lady", "merchant", "seonbi", "hallyang", "cheonmin", "jumo", "commoner_m", "child_m", "child_f", "gisaeng"]

## 에이전트 종류 → 스프라이트 종류(""이면 아직 예전 그림)
static func kind_for(atype: String, id: int) -> String:
	match atype:
		"shopper":
			return CROWD[absi(id) % CROWD.size()]
		"carrier":
			return "porter"
		"merchant":
			return "merchant"
		"guard":
			return "soldier"
		# PORT-TRACE [거리 사람들의 정체성]: StreetLife 인물
		"drunkard":
			return "drunkard"
		"elder_m":
			return "grandpa"
		"elder_f":
			return "grandma"
		"child_m", "child_f":
			return atype
		"helper_m":
			return "commoner_m"
		"helper_f":
			return "commoner_w"
		"scholar":
			return "seonbi"
		"official":
			return "official"
	return ""

## 걷는 방향(그리드) → 0 앞-오른, 1 앞-왼, 2 뒤-오른, 3 뒤-왼
static func dir_of(a: Dictionary) -> int:
	var dv: Variant = a.get("dir", Vector2(1, 0))
	var d := Vector2(1, 0)
	if dv is Vector2:
		d = dv
	elif dv is Vector2i:
		d = Vector2(dv)
	var want: int
	if absf(d.x) >= absf(d.y):
		want = 0 if d.x >= 0.0 else 3
	else:
		want = 1 if d.y > 0.0 else 2
	# PORT-TRACE [도리도리]: 대각선으로 걸으면 두 축이 거의 같아 프레임마다 방향이 뒤집혔다 — 지금 방향이 여전히 가는 쪽과
	# 어긋나지 않고(그 축 성분의 부호가 맞음) 새 축이 뚜렷이(1.4배) 크지 않으면 지금 방향을 지킨다
	if a.has("_gd") and d.length_squared() > 0.0:
		var prev: int = int(a["_gd"])
		if prev != want:
			var along: float = [d.x, d.y, -d.y, -d.x][clampi(prev, 0, 3)]
			var other: float = absf(d.y) if prev == 0 or prev == 3 else absf(d.x)
			if along > 0.0 and other < along * 1.4:
				want = prev
	a["_gd"] = want
	return want

## 에이전트 하나를 발 위치 p에 그린다
static func draw_agent(ci: CanvasItem, p: Vector2, kind: String, a: Dictionary, winter: bool) -> void:
	var id := int(a.get("id", 0))
	var variant := floori(float(absi(id)) / float(CROWD.size())) % 4
	var frame := int(float(a.get("anim", 0.0))) % FRAMES
	var alpha: float = float(a.get("fade_alpha", 1.0))
	draw_kind(ci, p, _modern_kind(kind, a), variant, winter, dir_of(a), frame, "", alpha)

## 근대화 시대: 관공서·학교 개편에 맞는 근대 인물, 그리고 해마다 늘어나는 근대 복식 시민("m:<시트>").
## 근대 시트 그림 파일이 없으면 원래 그림 그대로.
const MODERN_POOLS := {
	"m": ["npc_modern_gentleman", "npc_modern_worker", "npc_modern_cyclist", "npc_modern_vendor"],
	"w": ["npc_modern_girl", "npc_modern_lady"],
	"child_m": ["npc_modern_student"],
	"child_f": ["npc_modern_schoolgirl"],
}
const FEMALE_KINDS := ["lady", "commoner_w", "maiden", "grandma"]
static func _modern_kind(kind: String, a: Dictionary) -> String:
	var um := UrbanEvolutionManager.instance
	if um == null or not UrbanEvolutionManager.is_active():
		return kind
	# 1) 학교 개편 뒤 학생·교사
	var by_type := um.modern_npc_for_type(String(a.get("type", "")))
	if by_type != "" and _has_sheet(by_type):
		return "m:" + by_type
	# 2) 관공서 개편 뒤 그 건물 사람(순라군 → 경찰 등)
	var sh := sheet_for(kind)
	if not sh.is_empty() and not bool(sh[1]):
		var mapped := um.modern_npc_sprite(String(sh[3]))
		if mapped != String(sh[3]) and _has_sheet(mapped):
			return "m:" + mapped
	# 3) 해마다 늘어나는 근대 복식 시민
	if not um.citizen_is_modern(str(a.get("id", 0))):
		return kind
	var pool_key := "m"
	if kind in ["child_m", "child_f"]:
		pool_key = kind
	elif kind in FEMALE_KINDS or kind.contains("_w") or kind.contains("woman"):
		pool_key = "w"
	var avail: Array = (MODERN_POOLS[pool_key] as Array).filter(func(x: String) -> bool: return _has_sheet(x))
	if avail.is_empty():
		return kind
	return "m:" + String(avail[absi(int(a.get("id", 0))) % avail.size()])

## PORT-TRACE [새 시트 교체 지점]: 옛 코드 인물 종류 → 새 48x48 시트. 색만 다른 인물(custom_kind "c:")은 색 대신
## 아래 묶음에서 키(색 조합)마다 다른 시트를 골라 구경꾼·아낙들이 같은 사람으로 줄지어 서지 않게 한다.
## 묶음 안에서 그림 파일이 있는 시트만 고른다(새 그림이 들어올수록 구경꾼이 자동으로 다양해짐 — 김홍도 장터처럼
## 할아버지·취객·아기 업은 아낙·머리에 인 아낙이 섞인다).
const KIND_POOLS := {
	"yangban": ["npc_yangban_scholar", "npc_hallyang", "npc_jeongisu", "npc_ajeon", "npc_physician"],
	"seonbi": ["npc_yangban_scholar", "npc_jeongisu", "npc_hallyang", "npc_ajeon"],
	"commoner_m": ["npc_farmer", "npc_cheonmin", "npc_bobusang", "npc_fisherman", "npc_artisan_blacksmith", "npc_grandpa", "npc_drunkard", "npc_porter", "npc_woodcutter", "npc_yeot_seller"],
	"bearer": ["npc_farmer", "npc_cheonmin", "npc_taekkyeon", "npc_porter", "npc_beater"],
	"painter": ["npc_farmer", "npc_jeongisu", "npc_cheonmin", "npc_grandpa"],
	"lady": ["npc_peasant_woman", "npc_yangban_lady", "npc_gisaeng", "npc_mother_baby", "npc_grandma", "npc_head_carrier"],
	# PORT-TRACE [그네 탄 할머니]: 그네·널뛰기 처녀(댕기머리)는 젊은 여인 그림에서만 고른다
	"maiden": ["npc_peasant_woman", "npc_yangban_lady", "npc_gisaeng", "npc_base_woman", "npc_base_woman2"],
	"commoner_w": ["npc_peasant_woman", "npc_yangban_lady", "npc_mother_baby", "npc_grandma", "npc_head_carrier", "npc_jumo"],
	"child_m": ["npc_child_boy"],
	"child_f": ["npc_child_girl"],
}
static var _sheet_cache := {}
static var _action_cache := {}

## 인물 종류 → [텍스처, 역사 인물?, 아이?, 시트 이름]. 새 시트가 없으면 빈 배열(옛 코드 그림)
static func sheet_for(kind: String) -> Array:
	if _sheet_cache.has(kind):
		return _sheet_cache[kind]
	var out: Array = []
	if kind.begins_with("named_") or SpriteCacheManager.NAMED_ID_ALIASES.has(kind):
		var t: Texture2D = SpriteCacheManager.get_named_character_texture(kind)
		if t != null:
			out = [t, true, false, kind if kind.begins_with("named_") else "named_" + kind]
	else:
		var sid := ""
		var base_k := kind
		if kind.begins_with("m:"): # 근대 복식 시트(_modern_kind)
			sid = kind.substr(2) if _has_sheet(kind.substr(2)) else ""
		elif KIND_TO_GENERIC_48.has(kind):
			sid = _first_sheet(KIND_TO_GENERIC_48[kind])
		elif kind.begins_with("c:"):
			var c_dict: Dictionary = _custom.get(kind, {})
			base_k = str(c_dict.get("base", "commoner_m"))
			if KIND_POOLS.has(base_k):
				var avail: Array = (KIND_POOLS[base_k] as Array).filter(func(x: String) -> bool: return _has_sheet(x))
				if not avail.is_empty():
					sid = String(avail[absi(kind.hash()) % avail.size()])
			elif KIND_TO_GENERIC_48.has(base_k):
				sid = _first_sheet(KIND_TO_GENERIC_48[base_k])
		if sid != "":
			var t2: Texture2D = SpriteCacheManager.get_npc_texture(sid)
			if t2 != null:
				out = [t2, false, base_k in ["child_m", "child_f"] or base_k.begins_with("child_") or sid.begins_with("npc_child") or sid == "npc_kite_flyer", sid]
	_sheet_cache[kind] = out
	return out

## 시트 그림 파일이 있는가(없는 새 이름이면 옛 그림으로 대체되도록 — get_npc_texture가 빈 그림을 굽지 않게 파일만 본다)
static var _has_cache := {}
static func _has_sheet(sid: String) -> bool:
	if not _has_cache.has(sid):
		_has_cache[sid] = AssetPaths.asset_exists("res://assets/sprites/npcs/%s.png" % sid)
	return bool(_has_cache[sid])

## 연결 값이 배열이면 [새 그림, 대체 그림…] 중 파일이 있는 첫 번째
static func _first_sheet(v: Variant) -> String:
	if v is Array:
		for x in v:
			if _has_sheet(String(x)):
				return String(x)
		return ""
	return String(v) if _has_sheet(String(v)) else ""

## 동작 그림(assets/sprites/npcs/actions/<이름>.png): 가로로 칸(48x48, 두 사람 그림 "_pair"는 96x48)을 이어 붙인 한 줄,
## 화면 왼쪽(아래)을 보는 그림 — face_right면 좌우로 뒤집어 그린다. 없으면 false.
static func action_texture(action_id: String) -> Texture2D:
	if _action_cache.has(action_id):
		return _action_cache[action_id]
	var tex: Texture2D = AssetPaths.load_asset_texture("res://assets/sprites/npcs/actions/%s.png" % action_id)
	_action_cache[action_id] = tex
	return tex

static func draw_action(ci: CanvasItem, p: Vector2, action_id: String, frame: int, face_right: bool, scale_val: float = 0.70, alpha: float = 1.0) -> bool:
	var tex := action_texture(action_id)
	if tex == null:
		return false
	var cw := 96.0 if action_id.ends_with("_pair") else 48.0
	var n := maxi(1, int(float(tex.get_width()) / cw))
	var src := Rect2(float(posmod(frame, n)) * cw, 0.0, cw, 48.0)
	scale_val = adult_k(scale_val) * float(ACTION_K.get(action_id, 1.0))
	if face_right:
		set_xf(ci, p, 0.0, Vector2(-scale_val, scale_val))
	else:
		set_xf(ci, p, 0.0, Vector2(scale_val, scale_val))
	ci.draw_texture_rect_region(tex, Rect2(-cw * 0.5, -42.0, cw, 48.0), src, Color(1, 1, 1, alpha))
	reset_xf(ci)
	return true

## 동작 그림 칸 수(없으면 0)
static func action_frames(action_id: String) -> int:
	var tex := action_texture(action_id)
	if tex == null:
		return 0
	return maxi(1, int(float(tex.get_width()) / (96.0 if action_id.ends_with("_pair") else 48.0)))

const KIND_TO_GENERIC_48: Dictionary = {
	# 천주교당 앞에서 무릎 꿇고 기도하는 교우(짐을 이지 않은 평복 차림)
	"believer_w": "npc_peasant_woman",
	"believer_old": "npc_grandma",
	"believer_m": "npc_cheonmin",
	"yangban": "npc_yangban_scholar",
	"seonbi": "npc_yangban_scholar",
	"yusaeng": "npc_yangban_scholar",
	"foreman": "npc_yangban_scholar",
	"lady": "npc_yangban_lady",
	"hallyang": "npc_hallyang",
	"gisaeng": "npc_gisaeng",
	"farmer": "npc_farmer",
	"laborer": "npc_farmer",
	"mason": "npc_farmer",
	"woodcutter": ["npc_woodcutter", "npc_farmer"],
	"fisher": "npc_fisherman",
	"fisherman": "npc_fisherman",
	"jeongisu": "npc_jeongisu",
	"messenger": ["npc_messenger", "npc_soldier"], # PORT-TRACE [파발마 전령 하반신]: 시트가 없어 옛 상반신만 그려져 말 위에 떠 보였다 — 전용 그림이 오기 전까지 군졸 그림
	"storyteller": "npc_jeongisu",
	"kite_flyer": "npc_kite_flyer",
	"kites": "npc_kite_flyer",
	"ssireum": "npc_ssireum",
	"ssireum_brawler": "npc_ssireum",
	"taekkyeon": "npc_taekkyeon",
	"taekkyeon_fighter": "npc_taekkyeon",
	"commoner_m": "npc_farmer",
	"commoner_w": "npc_peasant_woman",
	"jumo": ["npc_jumo", "npc_peasant_woman"],
	"washer": "npc_peasant_woman",
	"refugee": ["npc_refugee", "npc_peasant_woman"],
	"supply": ["npc_head_carrier", "npc_peasant_woman"],
	"merchant": "npc_bobusang",
	"bobusang": "npc_bobusang",
	"book_peddler": ["npc_book_peddler", "npc_bobusang"],
	"shopkeeper": "npc_bobusang",
	"artisan": "npc_artisan_blacksmith",
	"cheonmin": "npc_cheonmin",
	"butcher": ["npc_butcher", "npc_cheonmin"],
	"prisoner": "npc_cheonmin",
	"painter": "npc_farmer",
	"child_m": "npc_child_boy",
	"child_f": "npc_child_girl",
	"patrol": "npc_patrol",
	"najol": "npc_patrol",
	"fireman": ["npc_firefighter", "npc_patrol"],
	"soldier": "npc_soldier",
	"trooper": "npc_soldier",
	"militia": "npc_soldier",
	"general": "npc_soldier",
	"bandit": ["npc_bandit", "npc_thief"],
	"rebel": ["npc_bandit", "npc_thief"],
	"horde": ["npc_bandit", "npc_thief"],
	"traitor": ["npc_bandit", "npc_thief"],
	"brawler": "npc_brawler",
	"thief": "npc_thief",
	"porter": ["npc_porter", "npc_bobusang"],
	"porter_e": ["npc_porter", "npc_bobusang"],
	"bearer": ["npc_porter", "npc_farmer"],
	"jungin": ["npc_physician", "npc_yangban_scholar"],
	"ajeon": ["npc_ajeon", "npc_yangban_scholar"],
	"official": ["npc_ajeon", "npc_yangban_scholar"],
	"hunter": ["npc_hunter", "npc_farmer"],
	"saposu": ["npc_hunter", "npc_soldier"],
	"posu": "npc_soldier",
	"carrier": ["npc_porter", "npc_bobusang"],
	"pungmul": ["npc_pungmul_player", "npc_taekkyeon"],
	"simmani": ["npc_simmani", "npc_farmer"],
	"peddler_w": ["npc_head_carrier", "npc_peasant_woman"],
	"monk": ["npc_monk"],
	"beater": ["npc_beater", "npc_farmer"],
	"chakhogapsa": ["npc_chakhogapsa", "npc_soldier"],
	"champion": ["npc_champion", "npc_ssireum"],
	"drunkard": ["npc_drunkard", "npc_cheonmin"],
	"grandpa": ["npc_grandpa", "npc_farmer"],
	"grandma": ["npc_grandma", "npc_peasant_woman"],
	"yeot_seller": ["npc_yeot_seller", "npc_bobusang"],
	"tteok_seller": ["npc_tteok_seller", "npc_peasant_woman"],
	"fish_seller": ["npc_fish_seller", "npc_fisherman"],
	"medicine_seller": ["npc_medicine_seller", "npc_bobusang"],
	"physician": ["npc_physician", "npc_yangban_scholar"],
	"mother_baby": ["npc_mother_baby", "npc_peasant_woman"],
	"sasu": "npc_soldier",
	"salsu": "npc_soldier",
	"gipo": "npc_soldier",
}

## pose "cheer": 걷지 않고 서서 팔을 든 모습 — frame 0(내림)~3(머리 위로 번쩍)
static func draw_kind(ci: CanvasItem, p: Vector2, kind: String, variant: int, winter: bool, dir: int, frame: int, pose: String = "", alpha: float = 1.0) -> void:
	# 48x48 새 도트 시트(있으면) — 동작(pose)은 동작 그림 → 코드 변형 순으로
	var sh := sheet_for(kind)
	if not sh.is_empty():
		var g_tex: Texture2D = sh[0]
		var scale_val: float = NAMED_SCALE if bool(sh[1]) else (0.52 if bool(sh[2]) else 0.70)
		if small:
			scale_val *= SMALL_K
		var face_right := dir == 0 or dir == 2 # 게임 방향 0(+x)·2(-y) = 화면 오른쪽
		if pose != "" and draw_action(ci, p, String(sh[3]) + "__" + pose, frame, face_right, scale_val, alpha):
			return
		var dir_map: Array[int] = [1, 0, 3, 2]
		var iso_dir: int = dir_map[clampi(dir, 0, 3)]
		var iso_phase: int = clampi(frame, 0, 3) % 2
		var hop := 0.0
		if pose != "" and pose != "walk":
			# 동작 그림이 없을 때: 팔 든 정도(frame 0~3)를 들썩임으로(환호·춤), 걷는 칸은 쓰지 않음
			iso_phase = 0
			hop = float(clampi(frame, 0, 3)) * 1.2 * scale_val
		scale_val = adult_k(scale_val)
		var g_src := Rect2(float(iso_phase) * 48.0, float(iso_dir) * 48.0, 48.0, 48.0)
		var dest := Rect2(p.x - 24.0 * scale_val, p.y - 42.0 * scale_val - hop, 48.0 * scale_val, 48.0 * scale_val)
		ci.draw_texture_rect_region(g_tex, dest, g_src, Color(1.0, 1.0, 1.0, alpha))
		return

	var src := region(kind, variant, winter, dir, frame, pose)
	var mod := Color(1.0, 1.0, 1.0, alpha)
	ci.draw_texture_rect_region(_ctex, Rect2(p - FOOT * body_k, Vector2(W, H) * body_k), src, mod)

## 앉은 사람·말 탄 사람: 머리부터 허리 아래(rows줄)까지만 잘라 p(엉덩이 자리)에 붙여 그린다
static func draw_upper(ci: CanvasItem, p: Vector2, kind: String, variant: int, winter: bool, dir: int, rows: int = 24, frame: int = 0, pose: String = "", alpha: float = 1.0, cut: float = 32.0) -> void:
	# 48x48 새 도트 시트의 상체(앉은 사람): 앉은 동작 그림이 있으면 그것을 통째로
	var sh := sheet_for(kind)
	if not sh.is_empty():
		var g_tex: Texture2D = sh[0]
		var scale_val: float = NAMED_SCALE if bool(sh[1]) else (0.52 if bool(sh[2]) else 0.70)
		if draw_action(ci, p + Vector2(0, 6.0 * scale_val), String(sh[3]) + "__sit", frame, dir == 0 or dir == 2, scale_val * (SMALL_K if small else 1.0), alpha):
			return
		if small:
			scale_val *= SMALL_K
		var dir_map_u: Array[int] = [1, 0, 3, 2]
		var iso_dir_u: int = dir_map_u[clampi(dir, 0, 3)]
		var iso_phase_u: int = clampi(frame, 0, 3) % 2
		var cut_h: float = cut # 48칸 시트에서 위에서부터 잘라 쓰는 줄 수(32 = 허리, 35 = 엉덩이까지)
		scale_val = adult_k(scale_val)
		var g_src := Rect2(float(iso_phase_u) * 48.0, float(iso_dir_u) * 48.0, 48.0, cut_h)
		var dest := Rect2(p.x - 24.0 * scale_val, p.y - cut_h * scale_val, 48.0 * scale_val, cut_h * scale_val)
		var g_mod := Color(1.0, 1.0, 1.0, alpha)
		ci.draw_texture_rect_region(g_tex, dest, g_src, g_mod)
		return

	var src := region(kind, variant, winter, dir, frame, pose)
	var rr := rows + 2 if small else rows # 작은 인물은 허리가 아래쪽(26줄 안팎)에 있다
	src.size.y = rr
	var mod := Color(1.0, 1.0, 1.0, alpha)
	ci.draw_texture_rect_region(_ctex, Rect2(p - Vector2(FOOT.x, rr), Vector2(W, rr)), src, mod)

static func region(kind: String, variant: int, winter: bool, dir: int, frame: int, pose: String = "") -> Rect2:
	if _img == null:
		_img = Image.create_empty(W * DIRS * FRAMES * ROW_BLOCKS, H * ceili(float(MAX_ROWS) / float(ROW_BLOCKS)), false, Image.FORMAT_RGBA8)
		_tex = ImageTexture.create_from_image(_img)
		_ctex = CanvasTexture.new()
		_ctex.diffuse_texture = _tex
		_ctex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # 도트 흐림 방지
	var key := "%s|%d|%d|%s|%d" % [kind, variant, 1 if winter else 0, pose, 1 if small else 0]
	if not _rows.has(key):
		var row := _next_row
		if row >= MAX_ROWS:
			row = 0 # 넘치면 첫 줄 재사용(실제로는 종류×4×2 = 96줄이면 충분)
		else:
			_next_row += 1
		_build_row(row, kind, variant, winter, pose, small)
		_rows[key] = row
		_tex.update(_img)
	var r: int = _rows[key]
	return Rect2(_row_origin(r) + Vector2i((dir * FRAMES + frame) * W, 0), Vector2(W, H))

static func _row_origin(r: int) -> Vector2i:
	return Vector2i((r % ROW_BLOCKS) * W * DIRS * FRAMES, int(float(r) / float(ROW_BLOCKS)) * H)

# ---------------------------------------------------------------- 한 줄 굽기
static func _build_row(row: int, kind: String, variant: int, winter: bool, pose: String = "", sm: bool = false) -> void:
	var spec: Dictionary
	if _custom.has(kind):
		var cu: Dictionary = _custom[kind]
		spec = (SHAPES.get(String(cu["base"]).replace("maiden", "lady"), SHAPES["commoner_m"]) as Dictionary).duplicate()
		spec.merge(cu["extra"] as Dictionary, true)
		spec["top"] = cu["top"]
		spec["bottom"] = cu["bottom"]
		spec["accent"] = cu["acc"]
	else:
		spec = (SHAPES.get(kind, SHAPES["commoner_m"]) as Dictionary).duplicate()
		var pals: Array = PALETTES.get(kind, PALETTES["commoner_m"])
		var pal: Array = pals[variant % pals.size()]
		spec["top"] = Color(String(pal[0]))
		spec["bottom"] = Color(String(pal[1]))
		spec["accent"] = Color(String(pal[2]))
	spec["winter"] = winter
	spec["pose"] = pose
	var org := _row_origin(row)
	if winter and not kind in ["soldier", "official"]:
		spec["top"] = (spec["top"] as Color).darkened(0.08) # 솜 둔 겨울옷
	for back: bool in [false, true]:
		for f in range(FRAMES):
			_c = Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
			_paint(spec, back, f)
			if spec.get("child", false):
				_compress_child()
			if sm:
				_shrink()
			spec["small"] = sm
			_finish(spec)
			var d := 2 if back else 0
			_img.blit_rect(_c, Rect2i(0, 0, W, H), org + Vector2i((d * FRAMES + f) * W, 0))
			var m := _c.duplicate() as Image
			m.flip_x()
			_img.blit_rect(m, Rect2i(0, 0, W, H), org + Vector2i(((d + 1) * FRAMES + f) * W, 0))

## 아이: 머리(0~16줄)는 그대로 6줄 내리고, 몸(17~30줄)은 한 줄 걸러 8줄로 줄여 머리 큰 아이 몸집으로
static func _compress_child() -> void:
	var src := _c.duplicate() as Image
	_c.fill(CLEAR)
	for yy in range(0, 17):
		for xx in range(W):
			var col := src.get_pixel(xx, yy)
			if col.a > 0.0:
				_c.set_pixel(xx, yy + 6, col)
	var rows: Array[int] = [17, 19, 21, 23, 25, 27, 29, 30]
	for k in range(rows.size()):
		for xx in range(W):
			var col2 := src.get_pixel(xx, rows[k])
			if col2.a > 0.0:
				_c.set_pixel(xx, 23 + k, col2)

## 발 위치(12, 30)를 기준으로 70%로 줄여 다시 찍는다(가장 가까운 원래 점의 색)
static func _shrink() -> void:
	var src := _c.duplicate() as Image
	_c.fill(CLEAR)
	for yy in range(H):
		for xx in range(W):
			var sx := roundi(FOOT.x + (float(xx) - FOOT.x) / SMALL_K)
			var sy := roundi(FOOT.y + (float(yy) - FOOT.y) / SMALL_K)
			if sx < 0 or sx >= W or sy < 0 or sy >= H:
				continue
			var col := src.get_pixel(sx, sy)
			if col.a > 0.0:
				_c.set_pixel(xx, yy, col)

## 작은 인물이면 원래 좌표를 발 기준 70%로
static func _sm(x: int, y: int, sm: bool) -> Vector2i:
	if not sm:
		return Vector2i(x, y)
	return Vector2i(roundi(FOOT.x + (float(x) - FOOT.x) * SMALL_K), roundi(FOOT.y + (float(y) - FOOT.y) * SMALL_K))

static func _line(x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	var n := maxi(absi(x1 - x0), absi(y1 - y0))
	for i in range(n + 1):
		var tt := float(i) / float(maxi(1, n))
		_px(roundi(lerpf(x0, x1, tt)), roundi(lerpf(y0, y1, tt)), col)

# ---------------------------------------------------------------- 도트 찍기 도구
static func _px(x: int, y: int, col: Color) -> void:
	if x < 0 or x >= W or y < 0 or y >= H:
		return
	if col.a >= 0.999 or col.a <= 0.0:
		_c.set_pixel(x, y, col)
	else:
		_c.set_pixel(x, y, _c.get_pixel(x, y).blend(col))

static func _rect(x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	for yy in range(mini(y0, y1), maxi(y0, y1) + 1):
		for xx in range(mini(x0, x1), maxi(x0, x1) + 1):
			_px(xx, yy, col)

static func _hl(x0: int, x1: int, y: int, col: Color) -> void:
	_rect(x0, y, x1, y, col)

static func _vl(x: int, y0: int, y1: int, col: Color) -> void:
	_rect(x, y0, x, y1, col)

static func _solid(x: int, y: int) -> bool:
	return x >= 0 and x < W and y >= 0 and y < H and _c.get_pixel(x, y).a > 0.5

# ---------------------------------------------------------------- 인물 한 칸
## 앞(back=false)은 얼굴이 오른쪽 아래를 보고, 뒤(back=true)는 등을 보인다. 프레임 1·3은 한 발을 들고 몸이 1px 뜬다.
static func _paint(spec: Dictionary, back: bool, frame: int) -> void:
	var cheer := String(spec.get("pose", "")) == "cheer"
	var lvl := frame if cheer else 0 # 팔 든 정도(환호 자세)
	var o := -1 if frame % 2 == 1 and not cheer else 0 # 몸 들썩임
	var ll := 1 if frame == 1 and not cheer else 0 # 왼발 듦
	var lr := 1 if frame == 3 and not cheer else 0 # 오른발 듦
	var sw := (1 if frame == 1 else (-1 if frame == 3 else 0)) if not cheer else 0 # 팔 흔들기
	var top: Color = spec["top"]
	var bottom: Color = spec["bottom"]
	var acc: Color = spec["accent"]
	var garment: String = spec["garment"]
	var prop: String = spec["prop"]

	# 등짐·지게는 앞모습에선 몸 뒤로(먼저), 뒷모습에선 몸 위로(나중에)
	if not back:
		_back_prop(prop, acc, o, false)

	# 1) 다리·발
	var shoe := Color("2a2420")
	match String(spec["shoe"]):
		"white": shoe = WHITE
		"straw": shoe = STRAW
		"bare": shoe = SKIN.darkened(0.1)
		"boot": shoe = Color("1a1614")
	if garment == "jacket":
		_rect(8, 22 + o + 1, 15, 25, bottom)
		_rect(8, 26, 10, 27 - ll, bottom)
		_rect(13, 26, 15, 27 - lr, bottom)
		var cuff := WHITE if not spec.get("ragged", false) else bottom.darkened(0.15)
		_hl(8, 10, 28 - ll, cuff) # 행전
		_hl(13, 15, 28 - lr, cuff)
		_rect(8, 29 - ll, 10, 30 - ll, shoe)
		_rect(13, 29 - lr, 15, 30 - lr, shoe)
		if spec.get("ragged", false):
			_px(9, 25, bottom.darkened(0.3)) # 해진 기운 자국
			_px(14, 24, bottom.lightened(0.15))
	elif garment == "armor" or garment == "cheollik":
		_rect(9, 26, 10, 28 - ll, Color("3a3030"))
		_rect(13, 26, 14, 28 - lr, Color("3a3030"))
		_rect(8, 29 - ll, 10, 30 - ll, shoe)
		_rect(13, 29 - lr, 15, 30 - lr, shoe)
	else:
		_rect(9, 29 - ll, 10, 30 - ll, shoe)
		_rect(13, 29 - lr, 14, 30 - lr, shoe)

	# 2) 옷 몸통
	match garment:
		"jacket":
			_rect(8, 16 + o, 15, 22 + o, top)
			if spec.get("vest", false):
				if back:
					_rect(8, 16 + o, 15, 21 + o, acc)
				else:
					_rect(9, 17 + o, 14, 21 + o, acc) # 조끼·쾌자
			_hl(8, 15, 22 + o, acc if spec.get("belt", false) else top.darkened(0.2)) # 허리띠
			if not back:
				_collar(top, acc, o)
				if spec.get("apron", false):
					_rect(9, 20 + o, 14, 26, acc if spec.get("apron_acc", false) else WHITE.darkened(0.04)) # 앞치마
		"robe", "dalyeong":
			for r in range(16 + o, 29):
				var k := int(float(r - 16 - o) / 6.0)
				_hl(8 - k, 15 + k, r, top)
			if spec.get("rainbow", false):
				for r2 in range(25, 29):
					_hl(6, 17, r2, top.darkened(0.12))
			if garment == "robe":
				_hl(8, 15, 21 + o, acc) # 세조대
				if not back:
					_vl(12, 21 + o, 28, top.darkened(0.25)) # 앞섶
					_vl(14, 22 + o, 26 + o, acc) # 술
					_collar(top, acc, o)
				else:
					_vl(12, 23 + o, 28, top.darkened(0.25)) # 뒤트임
			else:
				# 단령: 둥근 깃 + 흉배 + 각대
				if not back:
					_px(10, 16 + o, top.darkened(0.35))
					_px(13, 16 + o, top.darkened(0.35))
					_hl(11, 12, 16 + o, WHITE)
				_rect(10, 18 + o, 13, 21 + o, Color("c8a040"))
				_rect(11, 19 + o, 12, 20 + o, Color("ece4cc")) # 학
				_hl(7, 16, 22 + o, Color("1a1a1a"))
				for gx: int in [8, 10, 13, 15]:
					_px(gx, 22 + o, Color("d4af37"))
		"skirt":
			_rect(8, 16 + o, 15, 19 + o, top)
			for r in range(20 + o, 30):
				var k2 := int(float(r - 20 - o) * 3.0 / 9.0)
				_hl(8 - k2, 15 + k2, r, bottom)
			for px in range(6, 18, 2):
				_vl(px, 23, 29, bottom.darkened(0.15)) # 치마 주름
			if spec.get("apron", false) and not back:
				_rect(9, 21 + o, 14, 27, WHITE.darkened(0.04)) # 행주치마
				_hl(9, 14, 21 + o, WHITE.darkened(0.15))
			if not back:
				_collar(top, acc, o)
				_vl(11, 18 + o, 22 + o, acc) # 긴 고름
				_px(10, 22 + o, acc)
		"cheollik":
			# 철릭: 무릎까지 오는 군복 + 전대
			for r in range(16 + o, 27):
				var k4 := int(float(r - 16 - o) / 5.0)
				_hl(8 - k4, 15 + k4, r, top)
			_hl(8, 15, 21 + o, acc)
			if not back:
				_vl(12, 22 + o, 26, top.darkened(0.25))
				_collar(top, acc, o)
		"armor":
			for r in range(16 + o, 27):
				var k3 := int(float(r - 16 - o) / 5.0)
				_hl(8 - k3, 15 + k3, r, top if r < 24 else bottom)
			for r in range(17 + o, 24, 2):
				for gx in range(8, 16, 2):
					_px(gx + (1 if r % 4 >= 2 else 0), r, acc) # 두정갑 징
			_hl(8, 15, 21 + o, Color("b8352a")) # 띠

	if spec.get("sash", false):
		# 가사·띠: 어깨에서 허리로 비스듬히
		if back:
			_line(9, 16 + o, 14, 22 + o, acc)
			_line(9, 17 + o, 14, 23 + o, acc)
		else:
			_line(14, 16 + o, 9, 22 + o, acc)
			_line(14, 17 + o, 9, 23 + o, acc)

	# 3) 팔(소매) — 프레임마다 한쪽씩 앞뒤로
	var sleeve: Color = top
	if garment == "armor":
		sleeve = bottom
	var wide := garment in ["robe", "dalyeong"]
	for side: int in [0, 1]:
		var s := -sw if side == 0 else sw
		var x0 := 6 if side == 0 else 16
		var x1 := 7 if side == 0 else 17
		if wide:
			x0 = 5 if side == 0 else 16
			x1 = 7 if side == 0 else 18
		var y1 := 21 + o + s + (2 if wide else 0)
		if lvl > 0:
			# 팔 들기: 소매가 어깨에서 위로(높이 들수록 바깥으로), 손은 맨 위
			var out := 1 if lvl >= 2 else 0
			var xa := x0 - out if side == 0 else x0 + out
			var xb := x1 - out if side == 0 else x1 + out
			var ty := 17 + o - lvl * 3
			_rect(xa, ty, xb, 20 + o, sleeve)
			_hl(xa, xb, ty - 1, SKIN)
			continue
		_rect(x0, 17 + o, x1, y1, sleeve)
		if spec.get("rainbow", false):
			var bands: Array[Color] = [Color("c8283a"), Color("f0c030"), Color("3a9a4a"), Color("3a5ab0"), Color("e070a0")]
			for bi in range(17 + o, y1 + 1):
				_hl(x0, x1, bi, bands[(bi - 17 - o) % bands.size()])
		else:
			_hl(x0, x1, y1, WHITE if garment in ["jacket", "skirt"] and not spec.get("ragged", false) else sleeve.darkened(0.2)) # 끝동
		_hl(x0 + (1 if wide else 0), x1 - (1 if wide else 0), y1 + 1, SKIN) # 손

	# 4) 머리
	var hy := 9 + o
	_rect(9, hy, 14, hy + 6, SKIN)
	for cpt: Vector2i in [Vector2i(9, hy), Vector2i(14, hy), Vector2i(9, hy + 6), Vector2i(14, hy + 6)]:
		_px(cpt.x, cpt.y, CLEAR)
	_hl(11, 12, hy + 7, SKIN.darkened(0.12)) # 목
	if not back:
		_hl(9, 14, hy, HAIR)
		if spec["hat"] in ["gache", "bun", "messy", "scarf"]:
			_hl(10, 13, hy + 1, HAIR)
		else:
			_hl(9, 10, hy + 1, HAIR)
		_vl(9, hy + 1, hy + 3, HAIR)
		_px(11, hy + 3, EYE)
		_px(13, hy + 3, EYE)
		_px(14, hy + 4, SKIN.darkened(0.12)) # 볼
		_px(12, hy + 5, SKIN.darkened(0.3)) # 입
		_px(10, hy + 3, SKIN.darkened(0.15)) # 귀
	else:
		_rect(9, hy, 14, hy + 5, HAIR)
		_px(9, hy + 3, SKIN.darkened(0.1))
		_px(14, hy + 3, SKIN.darkened(0.1))
	if spec["winter"] and spec["hat"] in ["topknot", "headband", "paeraengi", "gat", "messy"] and garment != "armor":
		_hl(9, 14, hy + 7, Color("7a5a4a")) # 털목도리
		_hl(10, 13, hy + 8, Color("6a4a3a"))

	# 5) 쓰개
	_hat(String(spec["hat"]), back, hy, spec["winter"], acc, spec)

	# 6) 손에 든 소품 / 뒷모습 등짐
	match prop:
		"gayageum":
			_line(4, 25 + o, 17, 15 + o, Color("8a5a30"))
			_line(5, 25 + o, 18, 15 + o, Color("8a5a30"))
			_line(4, 24 + o, 17, 14 + o, Color("e8d8a8")) # 줄
		"medbox":
			_rect(15, 19 + o, 18, 23 + o, Color("5c3a21"))
			_hl(15, 18, 20 + o, Color("d4af37"))
			if not back:
				_line(10, 16 + o, 15, 19 + o, Color("3a2616"))
		"book":
			_rect(16, 20 + o + sw, 18, 23 + o + sw, Color("e8dcc0"))
			_hl(16, 18, 20 + o + sw, Color("3a5a8a"))
		"fan":
			_rect(17, 17 + o, 20, 19 + o, WHITE)
			_vl(18, 17 + o, 19 + o, Color("b8a880"))
			_px(17, 20 + o, Color("6e4a2c"))
		"basket":
			_rect(3, 22 + o - sw, 6, 25 + o - sw, Color("a07040"))
			_hl(3, 6, 23 + o - sw, Color("7a5030"))
			_px(4, 21 + o - sw, Color("7a5030"))
			_px(5, 21 + o - sw, Color("7a5030"))
			_rect(4, 22 + o - sw, 5, 22 + o - sw, Color("d8a050")) # 담긴 것
	if back:
		_back_prop(prop, acc, o, true)

static func _collar(top: Color, acc: Color, o: int) -> void:
	# 저고리 깃: 오른쪽 어깨에서 왼쪽 아래로 + 흰 동정 + 고름
	_px(13, 16 + o, WHITE)
	_px(12, 17 + o, WHITE)
	_px(11, 18 + o, WHITE)
	_px(14, 17 + o, top.darkened(0.3))
	_px(13, 18 + o, top.darkened(0.3))
	_px(12, 19 + o, top.darkened(0.3))
	_px(11, 19 + o, acc)
	_px(11, 20 + o, acc)

static func _hat(hat: String, back: bool, hy: int, winter: bool, acc: Color, spec: Dictionary) -> void:
	var blk := Color("161210")
	match hat:
		"pae2":
			_hl(7, 16, hy - 1, Color("78593a"))
			_rect(10, hy - 3, 13, hy - 2, Color("5c4028"))
		"satgat":
			var sc := Color(String(spec.get("hat_col", "b89a6a")))
			_hl(4, 19, hy, sc)
			_hl(6, 17, hy - 1, sc)
			_hl(8, 15, hy - 2, sc.lightened(0.08))
			_hl(10, 13, hy - 3, sc.lightened(0.12))
			_hl(11, 12, hy - 4, sc.lightened(0.12))
			_hl(5, 18, hy + 1, sc.darkened(0.4))
		"felt":
			_hl(6, 17, hy - 1, blk)
			_rect(9, hy - 4, 14, hy - 2, blk)
			if spec.get("plume", false):
				_line(12, hy - 5, 14, hy - 8, Color(String(spec.get("plume_col", acc.to_html(false))))) # 상모 깃
		"hood":
			_rect(8, hy - 1, 15, hy + 2 if not back else hy + 5, Color("111827"))
			_hl(8, 15, hy + 2, Color("f59e0b"))
		"mask":
			_rect(8, hy - 1, 15, hy + 1, Color("212529"))
			if back:
				_rect(9, hy + 2, 14, hy + 5, Color("212529"))
			else:
				_rect(9, hy + 4, 14, hy + 5, Color("e03131")) # 붉은 복면
		"redband":
			_rect(11, hy - 3, 12, hy - 1, HAIR)
			_hl(9, 14, hy + 1, Color("d02a20"))
			if back:
				_vl(15, hy + 2, hy + 4, Color("d02a20"))
		"helmet":
			_rect(9, hy - 4, 14, hy, Color("1c242e"))
			_hl(10, 13, hy - 5, Color("1c242e"))
			_vl(8, hy, hy + 4, Color("2d3b4a")) # 드림
			_vl(15, hy, hy + 4, Color("2d3b4a"))
			_px(11, hy - 6, Color("d4af37"))
			_rect(11, hy - 9, 12, hy - 7, Color("cc2525")) # 붉은 상모
		"yugeon":
			_rect(10, hy - 4, 13, hy, blk)
			_px(9, hy, blk)
			_px(14, hy, blk)
		"tanggeon":
			_rect(10, hy - 3, 13, hy - 1, blk)
			_hl(9, 14, hy, Color("3a3230"))
		"kid_boy":
			_px(10, hy - 1, HAIR)
			_px(13, hy - 1, HAIR)
			_px(12, hy - 1, HAIR)
		"braid":
			if back:
				_vl(12, hy + 6, hy + 11, HAIR) # 땋은 머리
				_hl(11, 13, hy + 12, Color("c0392b")) # 댕기
			else:
				_px(11, hy, SKIN)
		"gat":
			_rect(10, hy - 5, 13, hy - 2, Color(0.09, 0.07, 0.06, 0.95)) # 대우
			_hl(10, 13, hy - 2, Color("3a3230"))
			_hl(5, 18, hy - 1, Color(0.09, 0.07, 0.06, 0.9)) # 양태
			_hl(7, 16, hy, Color(0.09, 0.07, 0.06, 0.55))
			if not back:
				_vl(10, hy + 4, hy + 6, Color("8a3a2a")) # 갓끈
		"straw":
			_hl(4, 19, hy - 1, STRAW)
			_hl(6, 17, hy - 2, STRAW)
			_hl(8, 15, hy - 3, STRAW.lightened(0.08))
			_hl(10, 13, hy - 4, STRAW.lightened(0.12))
			_hl(5, 18, hy, STRAW.darkened(0.35))
		"paeraengi":
			_hl(7, 16, hy - 1, Color("c8b07a"))
			_rect(10, hy - 3, 13, hy - 2, Color("b89a62"))
			_rect(14, hy - 4, 15, hy - 3, WHITE) # 목화송이
		"samo":
			_rect(9, hy - 4, 14, hy, blk)
			_hl(10, 13, hy - 5, blk)
			_hl(6, 8, hy - 3, blk) # 사모뿔
			_hl(15, 17, hy - 3, blk)
			_hl(9, 14, hy - 1, Color("3a3230"))
		"jeonrip":
			_hl(5, 18, hy - 1, blk)
			_rect(9, hy - 4, 14, hy - 2, blk)
			_px(11, hy - 5, Color("e0b040")) # 정자
			_rect(11, hy - 8, 12, hy - 6, Color("c8282a")) # 상모
			_px(13, hy - 7, Color("c8282a"))
		"gache":
			_rect(7, hy - 4, 16, hy, HAIR)
			_hl(8, 15, hy - 5, HAIR)
			_hl(8, 15, hy - 3, Color("3a2a22")) # 땋은 결
			_hl(8, 15, hy - 1, Color("3a2a22"))
			_px(16, hy - 2, Color("e0b040")) # 떨잠
			_px(7, hy - 2, acc)
		"scarf":
			_rect(9, hy - 1, 14, hy + 1, WHITE.darkened(0.05))
			_hl(10, 13, hy - 2, WHITE.darkened(0.05))
			if back:
				_rect(10, hy + 2, 13, hy + 3, WHITE.darkened(0.12))
		"bun":
			if back:
				_rect(10, hy + 3, 13, hy + 5, HAIR) # 쪽
				_hl(8, 15, hy + 4, Color("d8c070")) # 비녀
			else:
				_px(11, hy, SKIN) # 가르마
		"topknot":
			_rect(11, hy - 3, 12, hy - 1, HAIR) # 상투
			_hl(9, 14, hy + 1 if not back else hy + 2, Color("3a3230")) # 망건
		"headband":
			_rect(11, hy - 2, 12, hy - 1, HAIR)
			_hl(9, 14, hy + 1, WHITE) # 머릿수건
			if back:
				_px(15, hy + 2, WHITE)
		"messy":
			_hl(8, 15, hy - 1, HAIR)
			for sp: Vector2i in [Vector2i(8, hy + 2), Vector2i(15, hy + 1), Vector2i(10, hy - 2), Vector2i(13, hy - 2), Vector2i(8, hy + 4)]:
				_px(sp.x, sp.y, HAIR)
	if winter and hat in ["scarf", "bun"]:
		# 아얌: 검은 방한모 + 붉은 술
		_rect(9, hy - 1, 14, hy, Color("2a1e1e"))
		_hl(9, 14, hy + 1, Color("c8b8a0"))
		if back:
			_vl(12, hy + 2, hy + 5, Color("c8282a"))

static func _back_prop(prop: String, acc: Color, o: int, back: bool) -> void:
	match prop:
		"pack":
			if back:
				_rect(8, 15 + o, 15, 23 + o, acc)
				_vl(11, 15 + o, 23 + o, acc.darkened(0.25))
				_hl(8, 15, 19 + o, acc.darkened(0.25))
				_rect(11, 13 + o, 12, 14 + o, acc.darkened(0.1)) # 매듭
			else:
				_rect(7, 14 + o, 16, 21 + o, acc)
				_vl(9, 16 + o, 20 + o, Color("5a4030")) # 멜빵
				_vl(14, 16 + o, 20 + o, Color("5a4030"))
		"jige_e":
			var wd := Color("6e4a2c")
			if back:
				_vl(7, 8 + o, 28, wd)
				_vl(16, 8 + o, 28, wd)
				_hl(7, 16, 22 + o, wd)
				_hl(7, 16, 14 + o, wd)
			else:
				_vl(7, 8 + o, 17 + o, wd)
				_vl(16, 8 + o, 17 + o, wd)
		"jige":
			var wood := Color("6e4a2c")
			var load_col := Color("b8a070")
			if back:
				_rect(7, 6 + o, 16, 18 + o, load_col)
				for r in range(7 + o, 18 + o, 3):
					_hl(7, 16, r, load_col.darkened(0.2))
				_vl(7, 8 + o, 28, wood)
				_vl(16, 8 + o, 28, wood)
				_hl(7, 16, 22 + o, wood)
			else:
				_rect(7, 3 + o, 16, 10 + o, load_col)
				for r2 in range(4 + o, 10 + o, 3):
					_hl(7, 16, r2, load_col.darkened(0.2))
				_vl(7, 6 + o, 17 + o, wood)
				_vl(16, 6 + o, 17 + o, wood)

## 면 음영(왼쪽 가장자리 어둡게·오른쪽과 윗면 밝게) → 1px 외곽선 → 창(가는 소품) → 발밑 그림자
static func _finish(spec: Dictionary) -> void:
	var src := _c.duplicate() as Image
	for yy in range(H):
		for xx in range(W):
			var col := src.get_pixel(xx, yy)
			if col.a < 0.5:
				continue
			var lt := xx == 0 or src.get_pixel(xx - 1, yy).a < 0.5
			var rt := xx == W - 1 or src.get_pixel(xx + 1, yy).a < 0.5
			var up := yy == 0 or src.get_pixel(xx, yy - 1).a < 0.5
			if lt:
				col = col.darkened(0.22)
			elif rt:
				col = col.lightened(0.12)
			if up and not lt:
				col = col.lightened(0.08)
			_c.set_pixel(xx, yy, col)
	var solid := _c.duplicate() as Image
	for yy in range(H):
		for xx in range(W):
			if solid.get_pixel(xx, yy).a >= 0.5:
				continue
			var near := false
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := xx + d.x
				var ny := yy + d.y
				if nx >= 0 and nx < W and ny >= 0 and ny < H and solid.get_pixel(nx, ny).a >= 0.5:
					near = true
					break
			if near:
				_c.set_pixel(xx, yy, OUTLINE)
	var sm: bool = spec.get("small", false)
	if String(spec["prop"]) == "staff":
		var a0 := _sm(19, 4, sm)
		var a1 := _sm(19, 29, sm)
		_vl(a0.x, a0.y, a1.y, Color("4a3525"))
		var r0 := _sm(18, 2, sm)
		_rect(r0.x, r0.y, r0.x + 2, r0.y + 1, Color("d4af37")) # 육환장 고리
		var hp := _sm(18, 23, sm)
		_px(hp.x, hp.y, SKIN)
	if String(spec["prop"]) == "spear":
		var b0 := _sm(19, 2, sm)
		var b1 := _sm(19, 29, sm)
		_vl(b0.x, b0.y, b1.y, Color("6e4a2c"))
		_vl(b0.x, b0.y - 2, b0.y - 1, Color("d8dce0"))
		var t0 := _sm(18, 3, sm)
		_rect(t0.x, t0.y, t0.x + 2, t0.y + 1, Color("c8282a"))
		var hp2 := _sm(18, 23, sm)
		_px(hp2.x, hp2.y, SKIN)
	# 발밑 그림자(빈 칸에만)
	var srx := 4.6 if sm else 6.5
	for yy in range(29, 32):
		for xx in range(3, 21):
			var dx := (float(xx) - 11.5) / srx
			var dy := (float(yy) - 30.5) / 1.8
			if dx * dx + dy * dy <= 1.0 and _c.get_pixel(xx, yy).a < 0.1:
				_c.set_pixel(xx, yy, Color(0, 0, 0, 0.26))
