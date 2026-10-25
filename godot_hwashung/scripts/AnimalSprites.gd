extends RefCounted
class_name AnimalSprites
const SpriteCacheManager = preload("res://scripts/autoload/SpriteCacheManager.gd")
## PORT-TRACE [동물·장비 도트 스프라이트]: 사람(NpcSprites)과 같은 방식 — 코드가 44x44 도트를 찍어(몸통·다리·머리 → 위 밝게/아래
## 어둡게 → 1px 외곽선 → 발밑 그림자) 아틀라스에 굽고, 매 프레임엔 칸 하나만 찍는다. 외부 그림 파일 없음.
## 동물은 오른쪽을 보는 옆모습 4프레임(다리 교차·깡충·쪼기), 왼쪽은 좌우 뒤집기. 한 줄 = 종류 + 몸 색 하나.
## 장비(거중기·녹로·유형거)는 프레임이 동작 단계(돌 들어 올리기·붐 회전·바퀴 회전).

const W := 44
const H := 44
const FOOT := Vector2(22, 41)
const FRAMES := 4
const MAX_ROWS := 64
const OUTLINE := Color("1e1712")
const CLEAR := Color(0, 0, 0, 0)

static var _img: Image
static var _tex: ImageTexture
static var _ctex: CanvasTexture
static var _rows := {}
static var _next_row := 0
static var _c: Image
## PORT-TRACE [작은 장면 동물]: 건물·마당 안 장면(아이 놀이터의 강아지, 쇠전의 소)을 그리는 동안만 true — 70%로 다시 찍은 칸
static var small := false
const SMALL_K := 0.9 # 사람(NpcSprites.SMALL_K)과 같게

## kind: deer crane boar rabbit wolf tiger dog ox horse lion sparrow scarecrow bait marksman geojunggi nongno yuheonggeo
## col: 몸 색(소·말·개처럼 색이 여럿인 종류만, 나머지는 무시). right=false면 왼쪽을 본다.
## PORT-TRACE [동물 새 그림]: assets/sprites/npcs/animal_<종류>.png(사람과 같은 96x192 시트)가 있으면 옆모습(앞 두 줄)을 쓴다.
const ANIMAL_SHEETS := {"tiger": "animal_tiger", "boar": "animal_boar", "deer": "animal_deer", "wolf": "animal_wolf", "rabbit": "animal_rabbit",
	"dog": "animal_dog", "ox": "animal_ox", "horse": "animal_horse", "crane": "animal_crane"}
const ANIMAL_SCALE := {"tiger": 0.95, "horse": 0.85, "ox": 0.85, "deer": 0.8, "crane": 0.75, "boar": 0.75, "wolf": 0.75, "dog": 0.7, "rabbit": 0.6}
static var _sheet_tex := {}

static func _animal_tex(kind: String) -> Texture2D:
	if not ANIMAL_SHEETS.has(kind):
		return null
	if not _sheet_tex.has(kind):
		var sid: String = ANIMAL_SHEETS[kind]
		_sheet_tex[kind] = SpriteCacheManager.get_npc_texture(sid) if AssetPaths.asset_exists("res://assets/sprites/npcs/%s.png" % sid) else null
	return _sheet_tex[kind]

static func draw(ci: CanvasItem, p: Vector2, kind: String, frame: int, right: bool = true, col: Color = Color(0, 0, 0, 0), alpha: float = 1.0) -> void:
	var stex := _animal_tex(kind)
	if stex != null:
		var sc: float = float(ANIMAL_SCALE.get(kind, 0.75)) * (SMALL_K if small else 1.0) * NpcSprites.body_k
		var srcs := Rect2(float(posmod(frame, 2)) * 48.0, 48.0 if right else 0.0, 48.0, 48.0) # 0줄 = 왼쪽(아래)을 봄, 1줄 = 오른쪽
		ci.draw_texture_rect_region(stex, Rect2(p.x - 24.0 * sc, p.y - 42.0 * sc, 48.0 * sc, 48.0 * sc), srcs, Color(1.0, 1.0, 1.0, alpha))
		return
	var src := region(kind, col, frame, right)
	var mod := Color(1.0, 1.0, 1.0, alpha)
	ci.draw_texture_rect_region(_ctex, Rect2(p - FOOT * NpcSprites.body_k, Vector2(W, H) * NpcSprites.body_k), src, mod)

## PORT-TRACE [동물 네 방향]: 게임 방향 dir(0=+x 화면 오른쪽 아래, 1=+y 왼쪽 아래, 2=-y 오른쪽 위, 3=-x 왼쪽 위)으로.
## 새 그림 시트는 사람과 같이 0줄 앞-왼쪽, 1줄 앞-오른쪽, 2줄 뒤-왼쪽, 3줄 뒤-오른쪽 — 위로 갈 땐 엉덩이(뒷모습)가 보인다.
## 말의 뒷모습 둘째 칸은 옆모습으로 잘못 그려져 있어 첫 칸 + 1px 들썩임으로 걷는다. 시트가 없으면 옛 옆모습.
static func draw_dir(ci: CanvasItem, p: Vector2, kind: String, frame: int, dir: int, col: Color = Color(0, 0, 0, 0), alpha: float = 1.0) -> void:
	var stex := _animal_tex(kind)
	if stex == null:
		draw(ci, p, kind, frame, dir == 0 or dir == 2, col, alpha)
		return
	var sc: float = float(ANIMAL_SCALE.get(kind, 0.75)) * (SMALL_K if small else 1.0) * NpcSprites.body_k
	var row: int = [1, 0, 3, 2][clampi(dir, 0, 3)]
	var colm := posmod(frame, 2)
	var bob := 0.0
	if row >= 2 and kind == "horse":
		bob = float(colm)
		colm = 0
	var srcs := Rect2(float(colm) * 48.0, float(row) * 48.0, 48.0, 48.0)
	ci.draw_texture_rect_region(stex, Rect2(p.x - 24.0 * sc, p.y - 42.0 * sc - bob, 48.0 * sc, 48.0 * sc), srcs, Color(1.0, 1.0, 1.0, alpha))

static func region(kind: String, col: Color, frame: int, right: bool) -> Rect2:
	if _img == null:
		_img = Image.create_empty(W * FRAMES * 2, H * MAX_ROWS, false, Image.FORMAT_RGBA8)
		_tex = ImageTexture.create_from_image(_img)
		_ctex = CanvasTexture.new()
		_ctex.diffuse_texture = _tex
		_ctex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var key := "%s|%s|%d" % [kind, col.to_html(false) if col.a > 0.0 else "-", 1 if small else 0]
	if not _rows.has(key):
		var row := _next_row
		if row >= MAX_ROWS:
			row = 0
		else:
			_next_row += 1
		_build_row(row, kind, col, small)
		_rows[key] = row
		_tex.update(_img)
	var r: int = _rows[key]
	return Rect2(((0 if right else FRAMES) + posmod(frame, FRAMES)) * W, r * H, W, H)

static func _build_row(row: int, kind: String, col: Color, sm: bool = false) -> void:
	for f in range(FRAMES):
		_c = Image.create_empty(W, H, false, Image.FORMAT_RGBA8)
		_paint(kind, col, f)
		if sm:
			_shrink()
		_finish(kind, sm)
		_img.blit_rect(_c, Rect2i(0, 0, W, H), Vector2i(f * W, row * H))
		var m := _c.duplicate() as Image
		m.flip_x()
		_img.blit_rect(m, Rect2i(0, 0, W, H), Vector2i((FRAMES + f) * W, row * H))

# ---------------------------------------------------------------- 도구
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

static func _line(x0: int, y0: int, x1: int, y1: int, col: Color, thick: int = 1) -> void:
	var n := maxi(absi(x1 - x0), absi(y1 - y0))
	for i in range(n + 1):
		var tt := float(i) / float(maxi(1, n))
		var x := roundi(lerpf(x0, x1, tt))
		var y := roundi(lerpf(y0, y1, tt))
		_px(x, y, col)
		if thick >= 2:
			_px(x + 1, y, col)
		if thick >= 3:
			_px(x, y + 1, col)

static func _ell(cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	for yy in range(floori(cy - ry), ceili(cy + ry) + 1):
		for xx in range(floori(cx - rx), ceili(cx + rx) + 1):
			var dx := (float(xx) + 0.5 - cx) / rx
			var dy := (float(yy) + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				_px(xx, yy, col)

## 다리 한 쌍(먼 다리 먼저 어둡게). x = 엉덩이/어깨 자리, top = 몸통 아래, ph = 걸음 위상, thick = 굵기
static func _leg(x: int, top: int, ph: int, col: Color, thick: int, hoof: Color) -> void:
	var sw: int = [0, 2, 0, -2][posmod(ph, 4)]
	var lift := 1 if posmod(ph, 4) == 1 else 0
	_line(x, top, x + sw, 40 - lift, col, thick)
	_rect(x + sw, 40 - lift, x + sw + thick - 1, 40 - lift, hoof)

# ---------------------------------------------------------------- 그리기
static func _paint(kind: String, col: Color, f: int) -> void:
	match kind:
		"deer":
			var b := Color("b87637")
			var bob := 1 if f % 2 == 1 else 0
			_leg(16, 30, f + 2, b.darkened(0.3), 1, Color("3a2416"))
			_leg(28, 30, f, b.darkened(0.3), 1, Color("3a2416"))
			_ell(22, 27 - bob, 10, 4.5, b)
			_ell(22, 29 - bob, 8, 2, Color("e8dec8")) # 흰 배
			_leg(18, 30, f, b.darkened(0.1), 1, Color("3a2416"))
			_leg(30, 30, f + 2, b.darkened(0.1), 1, Color("3a2416"))
			for sp: Vector2i in [Vector2i(17, 25), Vector2i(21, 24), Vector2i(25, 25), Vector2i(19, 27)]:
				_px(sp.x, sp.y - bob, Color("f4ecd8")) # 꽃사슴 반점
			_line(30, 25 - bob, 33, 16 - bob, b, 3) # 목
			_ell(34.5, 15 - bob, 3.5, 2.2, b.lightened(0.05))
			_px(38, 15 - bob, Color("2a1a14")) # 코
			_px(35, 14 - bob, Color("1a1a1a")) # 눈
			_px(32, 12 - bob, b) # 귀
			_px(31, 12 - bob, b)
			_line(33, 12 - bob, 31, 5 - bob, Color("5c3a1e")) # 뿔
			_line(32, 9 - bob, 29, 7 - bob, Color("5c3a1e"))
			_line(31, 6 - bob, 33, 3 - bob, Color("5c3a1e"))
			_px(12, 25 - bob, Color("f4ecd8")) # 꼬리
		"crane":
			var peck: int = [0, 2, 4, 2][f]
			_line(20, 31, 20, 40, Color("2c2c2c"))
			_line(23, 31, 24, 40, Color("2c2c2c"))
			_ell(22, 26, 8, 4.5, Color("fbfbfb"))
			_ell(15, 26, 4, 3, Color("1f1f1f")) # 검은 꽁지깃
			_line(28, 24, 30, 16 + peck, Color("f7f7f7"), 2) # 긴 목
			_line(30, 16 + peck, 30, 10 + peck, Color("1f1f1f"), 2) # 목 검은 깃
			_ell(31, 9 + peck, 2.5, 2, Color("fbfbfb"))
			_px(31, 7 + peck, Color("d92027")) # 붉은 정수리
			_px(30, 7 + peck, Color("d92027"))
			_line(33, 9 + peck, 38, 10 + peck, Color("c8a040")) # 부리
			_px(32, 8 + peck, Color("1a1a1a"))
		"boar":
			var bc := Color("3b291d")
			_leg(15, 32, f + 2, bc.darkened(0.3), 2, Color("1a120c"))
			_leg(27, 32, f, bc.darkened(0.3), 2, Color("1a120c"))
			_ell(21, 29, 10, 5.5, bc)
			_line(13, 23, 26, 22, Color("1a120c"), 2) # 억센 갈기
			_leg(17, 32, f, bc, 2, Color("1a120c"))
			_leg(29, 32, f + 2, bc, 2, Color("1a120c"))
			_ell(32, 29, 4, 3.5, bc.lightened(0.05)) # 머리
			_rect(35, 29, 38, 31, Color("4a3526")) # 주둥이
			_px(38, 30, Color("2b1e16"))
			_line(35, 32, 36, 28, Color("f0ebe1")) # 엄니
			_px(32, 27, Color("e8c040"))
			_rect(30, 25, 31, 26, bc) # 귀
			_px(10, 27, bc) # 꼬리
		"rabbit":
			var hop: int = [0, 2, 4, 2][f]
			var y0 := 36 - hop
			_ell(21, y0, 4.5, 3.2, Color("f4f4f0"))
			_ell(25, y0 - 3, 2.6, 2.4, Color("fcfcfc"))
			_line(24, y0 - 5, 23, y0 - 11, Color("f4f4f0"), 2) # 귀
			_line(25, y0 - 9, 25, y0 - 6, Color("f5b8c4"))
			_px(26, y0 - 3, Color("d93850")) # 눈
			_px(16, y0 - 1, Color("ffffff"))
			_rect(18, y0 + 2, 20, y0 + 3, Color("e8e8e0")) # 뒷발
		"wolf":
			var wc := Color("595652")
			_leg(15, 30, f + 2, wc.darkened(0.35), 1, Color("2b2927"))
			_leg(27, 30, f, wc.darkened(0.35), 1, Color("2b2927"))
			_ell(21, 27, 9, 4, wc)
			_ell(21, 29, 7, 1.6, Color("8a8682"))
			_line(14, 23, 27, 23, Color("2b2927")) # 등 갈기
			_leg(17, 30, f, wc, 2, Color("2b2927"))
			_leg(29, 30, f + 2, wc, 2, Color("2b2927"))
			_line(12, 26, 7, 31, Color("474441"), 2) # 꼬리
			_ell(32, 24, 3.5, 2.8, wc) # 머리
			_line(34, 25, 38, 26, wc, 2) # 주둥이
			_px(38, 26, Color("1a1a1a"))
			_line(30, 21, 30, 18, Color("383634")) # 귀
			_line(32, 21, 32, 19, Color("383634"))
			_px(33, 23, Color("fca311")) # 노란 눈
		"tiger":
			var tc := Color("d96b14")
			_leg(13, 29, f + 2, tc.darkened(0.3), 2, Color("faf6ee"))
			_leg(28, 29, f, tc.darkened(0.3), 2, Color("faf6ee"))
			_ell(21, 26, 12, 5.5, tc)
			_ell(21, 29, 10, 2, Color("faf6ee")) # 흰 배
			for sx in range(12, 31, 3):
				_line(sx, 21, sx - 1, 26, Color("171412")) # 줄무늬
			_leg(15, 29, f, tc, 3, Color("faf6ee"))
			_leg(30, 29, f + 2, tc, 3, Color("faf6ee"))
			_line(9, 25, 5, 20, tc, 2) # 꼬리
			_line(5, 20, 7, 16, tc, 2)
			_px(7, 15, Color("171412"))
			_ell(35, 22, 4.5, 4, tc) # 머리
			_ell(37, 24.5, 2.5, 1.6, Color("faf6ee")) # 흰 턱
			_rect(32, 17, 33, 18, tc) # 귀
			_px(32, 17, Color("171412"))
			_hl3(34, 36, 20, Color("171412")) # 이마 王
			_px(35, 19, Color("171412"))
			_px(37, 21, Color("ffd166")) # 눈
			_px(39, 23, Color("2a1a14"))
		"dog":
			var dc := col if col.a > 0.0 else Color("f2eee4")
			var hop2 := 1 if f % 2 == 1 else 0
			_leg(17, 36 - hop2, f + 2, dc.darkened(0.3), 1, dc.darkened(0.4))
			_leg(25, 36 - hop2, f, dc.darkened(0.3), 1, dc.darkened(0.4))
			_ell(21, 34 - hop2, 6, 3, dc)
			_leg(18, 36 - hop2, f, dc.darkened(0.1), 1, dc.darkened(0.4))
			_leg(26, 36 - hop2, f + 2, dc.darkened(0.1), 1, dc.darkened(0.4))
			_ell(28, 30 - hop2, 3, 2.6, dc) # 머리
			_rect(30, 31 - hop2, 32, 32 - hop2, dc) # 주둥이
			_px(32, 31 - hop2, Color("1a1a1a"))
			_px(29, 29 - hop2, Color("1a1a1a"))
			_line(27, 28 - hop2, 27, 26 - hop2, dc.darkened(0.15)) # 귀
			_line(15, 33 - hop2, 13, 29 - hop2 - (f % 2), dc) # 흔드는 꼬리
		"ox":
			var oc := col if col.a > 0.0 else Color("8a5a32")
			_leg(14, 28, f + 2, oc.darkened(0.35), 2, Color("2a1a10"))
			_leg(28, 28, f, oc.darkened(0.35), 2, Color("2a1a10"))
			_ell(21, 24, 11, 6, oc)
			_ell(18, 21, 6, 2, oc.lightened(0.08)) # 등
			_leg(16, 28, f, oc, 3, Color("2a1a10"))
			_leg(30, 28, f + 2, oc, 3, Color("2a1a10"))
			_line(10, 21, 8, 31, oc.darkened(0.2)) # 꼬리
			_rect(7, 31, 8, 32, oc.darkened(0.45))
			_ell(35, 22, 4, 3.5, oc) # 머리
			_ell(38, 24, 2.2, 1.8, Color("d8a888")) # 코
			_px(38, 25, Color("a83232")) # 코뚜레
			_px(36, 21, Color("1a1a1a"))
			_line(33, 19, 31, 16, Color("e8e0c8")) # 뿔
			_line(36, 19, 37, 16, Color("e8e0c8"))
			_rect(32, 20, 33, 21, oc.darkened(0.15)) # 귀
		"horse":
			var hc := col if col.a > 0.0 else Color("8a5a32")
			var mane := hc.darkened(0.5)
			_leg(14, 26, f + 2, hc.darkened(0.35), 2, Color("2a2420"))
			_leg(29, 26, f, hc.darkened(0.35), 2, Color("2a2420"))
			_ell(22, 22, 11, 5.5, hc)
			_leg(16, 26, f, hc, 2, Color("2a2420"))
			_leg(31, 26, f + 2, hc, 2, Color("2a2420"))
			_line(30, 19, 34, 10, hc, 3) # 목
			_line(29, 18, 32, 9, mane, 1) # 갈기
			_ell(36, 10, 3, 2.3, hc) # 머리
			_line(37, 11, 40, 14, hc, 2) # 콧등
			_px(36, 9, Color("1a1a1a"))
			_rect(33, 6, 34, 7, hc) # 귀
			_line(11, 19, 7, 30, mane, 2) # 꼬리
			_rect(18, 16, 25, 18, Color("8a2a20")) # 안장
			_hl3(18, 25, 19, Color("d4af37"))
		"lion":
			# 사자춤: 두 사람이 쓴 금빛 털북숭이 사자(흰 바지 다리 넷) + 붉은 탈 머리, 들썩
			var bob2: int = [0, 2, 0, 1][f]
			for lx: int in [12, 17, 26, 31]:
				var s: int = [0, 1, 0, -1][posmod(f + lx, 4)]
				_rect(lx + s, 34, lx + s + 1, 40, Color("f2eee4"))
				_rect(lx + s, 40, lx + s + 1, 40, Color("1e1712"))
			_ell(21, 27 - bob2, 13, 8, Color("e8b84a"))
			for k in range(9, 35, 2):
				_line(k, 31 - bob2, k + (k % 3) - 1, 35 - bob2, Color("c89830")) # 늘어진 털
			for k2 in range(10, 33, 4):
				_px(k2, 22 - bob2, Color("f8d870"))
			_ell(36, 22 - bob2, 6, 5.5, Color("c0392b")) # 탈 머리
			_rect(34, 19 - bob2, 35, 20 - bob2, Color("ffffff")) # 눈
			_rect(38, 19 - bob2, 39, 20 - bob2, Color("ffffff"))
			_px(35, 20 - bob2, Color("1a1a1a"))
			_px(39, 20 - bob2, Color("1a1a1a"))
			_hl3(34, 40, 25 - bob2, Color("f4f0e4")) # 이빨
			_ell(36, 15 - bob2, 6, 2, Color("2e8b57")) # 갈기 장식
		"sparrow":
			var up := f % 2 == 0
			for b2: Vector2i in [Vector2i(10, 18), Vector2i(24, 12), Vector2i(17, 24), Vector2i(31, 20), Vector2i(6, 8), Vector2i(20, 4)]:
				var dy := 1 if (b2.x + f) % 3 == 0 else 0
				_rect(b2.x, b2.y + dy, b2.x + 2, b2.y + 1 + dy, Color("6b4226"))
				_px(b2.x + 1, b2.y + 1 + dy, Color("d1c2ae"))
				_px(b2.x + 3, b2.y + dy, Color("e0a526"))
				if up:
					_px(b2.x - 1, b2.y - 1 + dy, Color("54321b"))
					_px(b2.x + 2, b2.y - 1 + dy, Color("54321b"))
				else:
					_px(b2.x - 1, b2.y + 2 + dy, Color("54321b"))
					_px(b2.x + 2, b2.y + 2 + dy, Color("54321b"))
		"scarecrow":
			# PORT-TRACE [허수아비 새 단장]: 노랑·파랑 만화풍이 주변 도트와 따로 놀았다 → 바랜 흰 헌 저고리에 새끼줄 띠,
			# 짚 다발 머리에 숯으로 그린 눈코, 낡은 삿갓, 소매 끝·치마 밑으로 삐져나온 짚(바람에 살랑).
			var wd: int = [0, 1, 0, -1][f]
			var straw := Color("c2a564")
			var straw_d := Color("957a3e")
			var cloth := Color("d3ccb8")
			var cloth_d := Color("aaa28c")
			_rect(21, 24, 22, 42, Color("5a3c22")) # 기둥
			_rect(21, 40, 22, 42, Color("3e2814"))
			_line(9 + wd, 21, 34 + wd, 21, Color("5a3c22"), 1) # 팔 막대
			_rect(10 + wd, 19, 16, 23, cloth) # 소매
			_rect(27, 19, 33 + wd, 23, cloth_d)
			for q in [[9, 19], [9, 22], [8, 21]]:
				_px(int(q[0]) + wd * 2, int(q[1]), straw) # 소매 끝 짚
			for q2 in [[34, 19], [34, 22], [35, 21]]:
				_px(int(q2[0]) + wd * 2, int(q2[1]), straw_d)
			_rect(16, 19, 27, 31, cloth) # 헌 저고리
			_rect(24, 19, 27, 31, cloth_d)
			_line(19, 19, 21, 23, Color("8a826e"), 1) # 깃
			_line(24, 19, 22, 23, Color("8a826e"), 1)
			_rect(18, 25, 20, 27, Color("b8ae94")) # 기운 자국
			_rect(16, 28, 27, 28, Color("7a5a30")) # 새끼줄 띠
			for k in range(16, 28, 2):
				_line(k, 31, k + wd, 35, straw if k % 4 == 0 else straw_d) # 치마 밑 짚
			_ell(21.5, 15, 3.6, 3.4, straw) # 짚 다발 머리
			_line(19, 13, 19, 17, straw_d, 1)
			_line(24, 13, 24, 17, straw_d, 1)
			_px(20, 14, Color("2a2420")) # 숯 눈
			_px(23, 14, Color("2a2420"))
			_line(20, 17, 23, 17, Color("5a4030"), 1) # 입
			_rect(13, 11, 30, 11, straw_d) # 낡은 삿갓
			_rect(15, 10, 28, 10, Color("a88c50"))
			_rect(17, 9, 26, 9, straw)
			_rect(19, 8, 24, 8, Color("cdb37a"))
			_px(21, 7, Color("cdb37a"))
			_px(22, 7, Color("cdb37a"))
		"bait":
			_rect(13, 34, 31, 40, Color("5c4033")) # 덫 틀
			_line(13, 34, 22, 28, Color("4a3020"), 2)
			_line(31, 34, 22, 28, Color("4a3020"), 2)
			_ell(21, 36, 5, 2.5, Color("a71d2a")) # 고깃덩이
			_line(25, 36, 30, 35, Color("f4edea"), 2) # 뼈
		"marksman":
			# 바위 뒤에 엎드려 조준하는 명포수(털모자·털조끼·긴 조총)
			_ell(30, 36, 7, 5, Color("6c757d")) # 은신 바위
			_ell(24, 38, 4, 3, Color("495057"))
			_rect(8, 34, 22, 38, Color("5c4033")) # 엎드린 몸
			_rect(8, 37, 22, 38, Color("3a2a20"))
			_rect(6, 36, 8, 38, Color("3a3030")) # 발
			_ell(24, 33, 3, 2.8, Color("efc49c")) # 얼굴
			_ell(23, 31, 3.5, 2.2, Color("2b1e16")) # 털모자(휘양)
			_line(22, 34, 40, 32, Color("212529"), 2) # 조총
			_line(16, 35, 22, 34, Color("6e4a2c"), 2) # 개머리
			_px(30, 33, Color("e8602a")) # 화승 불씨
			if f % 2 == 1:
				_px(41, 31, Color("ffd060"))
		"geojunggi":
			# 거중기: A자 기둥 둘 + 꼭대기 도르래 넷 + 양옆 물레, 줄에 매달린 돌이 프레임마다 오르내림
			var wood := Color("6e3f1e")
			_line(6, 41, 17, 6, wood, 2)
			_line(37, 41, 26, 6, wood, 2)
			_rect(14, 4, 29, 6, Color("3d210c"))
			_line(10, 26, 33, 26, Color("7a4a24"), 2)
			for k in range(4):
				_rect(16 + k * 3, 7, 17 + k * 3, 8, Color("dedad2"))
			_ell(5, 35, 4, 4, Color("4a2d14")) # 물레
			_ell(38, 35, 4, 4, Color("4a2d14"))
			_line(5, 31, 5, 39, Color("b0936d"))
			_line(38, 31 + f, 38, 39 - f, Color("b0936d"))
			var sy := 14 + (3 - f) * 4
			_line(18, 8, 18, sy, Color("c9b895"))
			_line(25, 8, 25, sy, Color("c9b895"))
			_rect(15, sy, 28, sy + 7, Color("969088")) # 들어 올리는 돌
			_rect(15, sy + 6, 28, sy + 7, Color("7a746c"))
			_line(21, sy, 21, sy + 7, Color("c9b895"))
		"nongno":
			# 녹로: 가운데 돛대 + 받침 다리, 붐이 프레임마다 좌우로 돌며 돌을 매달고 옮긴다
			var wd2 := Color("4a2e16")
			_rect(21, 6, 22, 41, wd2)
			_line(12, 41, 21, 24, Color("5e3c1f"), 2)
			_line(31, 41, 22, 24, Color("5e3c1f"), 2)
			var tipx: int = 22 + [-12, -4, 4, 12][f]
			_line(22, 8, tipx, 3, Color("3b210e"), 2)
			_rect(tipx - 1, 3, tipx, 4, Color("d1cbbe"))
			_line(tipx, 5, tipx, 16, Color("c7b593"))
			_rect(tipx - 3, 16, tipx + 3, 21, Color("8c8579"))
			_ell(21.5, 37, 3, 3, Color("4a2d14")) # 감는 물레
		"yuheonggeo":
			# 유형거: 바퀴 둘(살이 돌아감) + 짐틀 위 큰 돌
			for wx: int in [11, 33]:
				_ell(wx, 35, 5.5, 5.5, Color("4a2f18"))
				_ell(wx, 35, 3.5, 3.5, Color("7a5229"))
				var ang := float(f) * PI * 0.25
				_line(wx, 35, wx + roundi(cos(ang) * 4.0), 35 + roundi(sin(ang) * 4.0), Color("3d2612"))
				_line(wx, 35, wx - roundi(cos(ang) * 4.0), 35 - roundi(sin(ang) * 4.0), Color("3d2612"))
			_rect(5, 28, 39, 30, Color("634224")) # 짐틀
			_line(39, 29, 43, 31, Color("634224"), 2) # 손잡이
			_rect(11, 18, 33, 27, Color("948e83")) # 큰 돌
			_rect(11, 18, 33, 19, Color("b0aa9e"))

## 발 위치(22, 41)를 기준으로 70%로 줄여 다시 찍는다
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

static func _hl3(x0: int, x1: int, y: int, col: Color) -> void:
	_rect(x0, y, x1, y, col)

## 위 밝게·아래 어둡게 → 1px 외곽선 → 발밑 그림자
static func _finish(kind: String, sm: bool = false) -> void:
	var src := _c.duplicate() as Image
	for yy in range(H):
		for xx in range(W):
			var col := src.get_pixel(xx, yy)
			if col.a < 0.5:
				continue
			var up := yy == 0 or src.get_pixel(xx, yy - 1).a < 0.5
			var dn := yy == H - 1 or src.get_pixel(xx, yy + 1).a < 0.5
			if up:
				col = col.lightened(0.14)
			elif dn:
				col = col.darkened(0.22)
			_c.set_pixel(xx, yy, col)
	var solid := _c.duplicate() as Image
	for yy in range(H):
		for xx in range(W):
			if solid.get_pixel(xx, yy).a >= 0.5:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := xx + d.x
				var ny := yy + d.y
				if nx >= 0 and nx < W and ny >= 0 and ny < H and solid.get_pixel(nx, ny).a >= 0.5:
					_c.set_pixel(xx, yy, OUTLINE)
					break
	if kind == "sparrow":
		return
	var rx := 13.0 if kind in ["tiger", "ox", "horse", "lion", "geojunggi", "yuheonggeo"] else (9.0 if kind in ["deer", "boar", "wolf", "marksman", "nongno", "bait", "scarecrow"] else 6.0)
	if sm:
		rx *= SMALL_K
	for yy in range(39, 44):
		for xx in range(W):
			var dx := (float(xx) + 0.5 - 22.0) / rx
			var dy := (float(yy) + 0.5 - 41.5) / 2.0
			if dx * dx + dy * dy <= 1.0 and _c.get_pixel(xx, yy).a < 0.1:
				_c.set_pixel(xx, yy, Color(0, 0, 0, 0.24))
