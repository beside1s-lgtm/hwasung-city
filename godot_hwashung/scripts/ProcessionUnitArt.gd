extends RefCounted
class_name ProcessionUnitArt

const SpriteCacheManager = preload("res://scripts/autoload/SpriteCacheManager.gd")

## [을묘원행반차도(乙卯園幸反次圖) 고증 도트 스프라이트 렌더러]
## - 조선 후기 반차도 및 화성능행도 병풍(서장대성조도) 실록 회화 고증
## - 기존 백성 NPC(NpcSprites, 24x32px) 및 동물(AnimalSprites, 44x44px) 화풍 100% 동기화
## - 1px 검은 외곽선(OUTLINE), 전통 한복/갑주 팔레트, 2프레임 행진/연주/사격 애니메이션
## - 아틀라스 텍스처 베이킹 및 오브젝트 풀링으로 런타임 드로우콜 최소화

const W_HUMAN := 24
const H_HUMAN := 32
const FOOT_HUMAN := Vector2(12, 30)

const W_HORSE := 44
const H_HORSE := 44
const FOOT_HORSE := Vector2(22, 41)

const W_PALANQUIN := 64
const H_PALANQUIN := 44
const FOOT_PALANQUIN := Vector2(32, 40)

# 정조 대왕 전용 대형 규격 (일반 유닛 대비 확연한 스케일과 위엄)
const W_KING_HORSE := 56
const H_KING_HORSE := 56
const FOOT_KING_HORSE := Vector2(28, 52)

const W_KING_HUMAN := 32
const H_KING_HUMAN := 44
const FOOT_KING_HUMAN := Vector2(16, 40)

const H_CELL := 56 # 아틀라스 최대 행 높이 (정조 기마 56px 수용)

const OUTLINE := Color("1e1712")
const SKIN := Color("efc49c")
const HAIR := Color("1c1612")
const WHITE := Color("f1ede3")
const GOLD := Color("d4af37")
const RED_LACQUER := Color("8b0000") # 주칠
const JADE := Color("388e8e")        # 옥색 차양
const BLUE_CHELLIK := Color("243356")# 남색 철릭
const YELLOW_CHWITA := Color("f39c12")# 황초령
const FELT_BLACK := Color("1c1815")  # 벙거지/전립
const STRAW := Color("c9a86a")
const CLEAR := Color(0, 0, 0, 0)

static var _img: Image
static var _tex: ImageTexture
static var _ctex: CanvasTexture
static var _rows: Dictionary = {}
static var _next_row: int = 0
static var _c: Image

const MAX_ROWS: int = 48
const FRAMES: int = 4 # 최대 4프레임 활쏘기/춤사위/행진 모션
const DIRS: int = 4   # 0 앞-오른, 1 앞-왼, 2 뒤-오른, 3 뒤-왼
const PARADE_ROLE_MAP: Dictionary = {
	"jeongjo_king": "parade_king",
	"hyegyeong_palanquin": "parade_royal_carriage",
	"gyeonggi_governor": "parade_cavalry",
	"lead_cavalry": "parade_cavalry",
	"royal_guard_horse": "parade_cavalry",
	"royal_band": "parade_musician",
	"chwita": "parade_musician",
	"chwitadae": "parade_musician",
	"standard_bearer": "parade_flag_bearer",
	"flag_bearer": "parade_flag_bearer",
	"escort_infantry": "npc_soldier",
}

## 렌더링 진입점: 유닛 종류, 위치, 방향, 프레임, 알파
static func draw_unit(
	ci: CanvasItem,
	pos: Vector2,
	role: String,
	dir: int,
	frame: int,
	alpha: float = 1.0,
	is_drill: bool = false
) -> void:
	# 48x48 어가행렬 고품질 스프라이트 시트 우선 검사
	var p_key: String = String(PARADE_ROLE_MAP.get(role, ""))
	if p_key != "":
		var p_tex: Texture2D = SpriteCacheManager.get_npc_texture(p_key)
		if p_tex != null:
			var d_clamped: int = clampi(dir, 0, 3)
			var f_clamped: int = clampi(frame, 0, 3)
			var src := Rect2(float(f_clamped) * 48.0, float(d_clamped) * 48.0, 48.0, 48.0)
			var dest := Rect2(pos.x - 24.0, pos.y - 43.0, 48.0, 48.0)
			var p_mod := Color(1.0, 1.0, 1.0, alpha)
			ci.draw_texture_rect_region(p_tex, dest, src, p_mod)
			return

	if _img == null:
		_init_atlas()

	var is_palanquin: bool = (role == "hyegyeong_palanquin")
	var is_horse: bool = role in ["jeongjo_king", "gyeonggi_governor", "lead_cavalry", "royal_guard_horse"]

	var key: String = "%s|%s" % [role, "drill" if is_drill else "march"]
	if not _rows.has(key):
		_build_role_row(role, is_drill)

	var row_idx: int = int(_rows.get(key, 0))

	var w: int = W_HUMAN
	var h: int = H_HUMAN
	var foot: Vector2 = FOOT_HUMAN
	var shadow_rx: float = 6.0
	var shadow_ry: float = 3.0

	if is_palanquin:
		w = W_PALANQUIN
		h = H_PALANQUIN
		foot = FOOT_PALANQUIN
		shadow_rx = 18.0
		shadow_ry = 6.0
	elif role == "jeongjo_king":
		if is_drill:
			w = W_KING_HUMAN
			h = H_KING_HUMAN
			foot = FOOT_KING_HUMAN
			shadow_rx = 9.0
			shadow_ry = 4.5
		else:
			w = W_KING_HORSE
			h = H_KING_HORSE
			foot = FOOT_KING_HORSE
			shadow_rx = 16.0
			shadow_ry = 6.0
	elif role == "jeongjo_archery":
		w = W_KING_HUMAN
		h = H_KING_HUMAN
		foot = FOOT_KING_HUMAN
		shadow_rx = 9.0
		shadow_ry = 4.5
	elif is_horse:
		w = W_HORSE
		h = H_HORSE
		foot = FOOT_HORSE
		shadow_rx = 12.0
		shadow_ry = 5.0

	var f: int = posmod(frame, FRAMES)
	var d: int = clampi(dir, 0, DIRS - 1)
	var src_x: int = (d * FRAMES + f) * w
	var src_y: int = row_idx * H_CELL # 최대 높이 56px 단위 행 배치
	var src_rect: Rect2 = Rect2(src_x, src_y, w, h)

	# 발밑 그림자
	ci.draw_ellipse(pos + Vector2(0, 1), shadow_rx, shadow_ry, Color(0, 0, 0, 0.28 * alpha))

	# 본체 스프라이트
	var mod: Color = Color(1.0, 1.0, 1.0, alpha)
	ci.draw_texture_rect_region(_ctex, Rect2(pos - foot, Vector2(w, h)), src_rect, mod)

static func _init_atlas() -> void:
	var total_w: int = W_PALANQUIN * DIRS * FRAMES # 64 * 4 * 4 = 1024
	var total_h: int = H_CELL * MAX_ROWS          # 56 * 48 = 2688
	_img = Image.create_empty(total_w, total_h, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)
	_ctex = CanvasTexture.new()
	_ctex.diffuse_texture = _tex
	_ctex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

static func _build_role_row(role: String, is_drill: bool) -> void:
	if _img == null:
		_init_atlas()
	var key: String = "%s|%s" % [role, "drill" if is_drill else "march"]
	if _rows.has(key): return
	var row: int = _next_row
	_next_row += 1
	_rows[key] = row

	var is_palanquin: bool = (role == "hyegyeong_palanquin")
	var is_horse: bool = role in ["jeongjo_king", "gyeonggi_governor", "lead_cavalry", "royal_guard_horse"]

	var w: int = W_HUMAN
	var h: int = H_HUMAN
	if is_palanquin:
		w = W_PALANQUIN
		h = H_PALANQUIN
	elif role == "jeongjo_king":
		if is_drill:
			w = W_KING_HUMAN
			h = H_KING_HUMAN
		else:
			w = W_KING_HORSE
			h = H_KING_HORSE
	elif role == "jeongjo_archery":
		w = W_KING_HUMAN
		h = H_KING_HUMAN
	elif is_horse:
		w = W_HORSE
		h = H_HORSE

	for d in range(DIRS):
		for f in range(FRAMES):
			_c = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
			_paint_frame(role, d, f, is_drill, w, h)
			_add_outline(w, h)
			var dest_pos := Vector2i((d * FRAMES + f) * w, row * H_CELL)
			_img.blit_rect(_c, Rect2i(0, 0, w, h), dest_pos)

	_tex.update(_img)

# -----------------------------------------------------------------------------
# 픽셀 페인팅 루틴
# -----------------------------------------------------------------------------
static func _paint_frame(role: String, dir: int, frame: int, is_drill: bool, w: int, h: int) -> void:
	var _is_back: bool = (dir == 2 or dir == 3)
	var is_left: bool = (dir == 1 or dir == 3)

	match role:
		"hyegyeong_palanquin":
			_paint_palanquin(dir, frame % 2, w, h)
		"jeongjo_king":
			if is_drill:
				_paint_king_drill(dir, frame % 2, w, h)
			else:
				_paint_king_horse(dir, frame % 2, w, h)
		"jeongjo_archery":
			_paint_jeongjo_archery(dir, frame, w, h)
		"archery_target":
			_paint_archery_target(dir, frame, w, h)
		"gyeonggi_governor", "lead_cavalry", "royal_guard_horse":
			_paint_cavalry(role, dir, frame % 2, w, h)
		"chwita":
			_paint_chwita(dir, frame % 2, w, h)
		"posu":
			_paint_posu(dir, frame % 2, is_drill, w, h)
		"salsu":
			_paint_salsu(dir, frame % 2, is_drill, w, h)
		"sasu":
			_paint_sasu(dir, frame % 2, is_drill, w, h)
		"gipo":
			_paint_gipo(dir, frame % 2, is_drill, w, h)
		"royal_flag":
			_paint_flag_bearer(dir, frame % 2, w, h)
		"chae_jegong", "minister":
			_paint_official(role, dir, frame % 2, w, h)
		"court_lady":
			_paint_court_lady(dir, frame % 2, w, h)
		"palanquin_bearer":
			_paint_bearer(dir, frame % 2, w, h)
		"gyeokjaeng_citizen":
			_paint_gyeokjaeng(dir, frame % 2, w, h)
		"sangeon_scholar":
			_paint_sangeon(dir, frame % 2, w, h)
		"court_dancer":
			_paint_court_dancer(dir, frame, w, h)
		"elder_citizen":
			_paint_elder(dir, frame % 2, w, h)
		"spectator_bow":
			_paint_spectator_bow(dir, frame % 2, w, h)
		"spectator_prostrate":
			_paint_spectator_prostrate(dir, frame % 2, w, h)
		"spectator_cheer":
			_paint_spectator_cheer(dir, frame % 2, w, h)
		_:
			_paint_soldier_generic(dir, frame % 2, w, h)

	if is_left:
		_c.flip_x()

# -----------------------------------------------------------------------------
# 세부 유닛 도트 구현
# -----------------------------------------------------------------------------

## 1. 혜경궁 홍씨 자궁가마 (64x44 복합 도트 유닛)
## - 붉은 주칠 지붕, 금빛 옥구슬, 옥색/남색 차양 휘장, 금빛 가마채, 앞뒤 가마 호위 별감 2인
static func _paint_palanquin(_dir: int, frame: int, _w: int, _h: int) -> void:
	var bob: int = 1 if frame == 1 else 0

	# A. 가마채 (앞뒤로 길게 뻗은 채)
	_line(4, 26 + bob, 60, 26 + bob, Color("966d3b"), 2)
	_line(2, 26 + bob, 4, 26 + bob, GOLD, 2)
	_line(60, 26 + bob, 62, 26 + bob, GOLD, 2)

	# B. 가마 몸통 (주칠 홍색 + 옥색 차양 창문)
	_rect(18, 14 + bob, 46, 33 + bob, RED_LACQUER)
	_rect(20, 16 + bob, 44, 31 + bob, RED_LACQUER.lightened(0.15))
	# 옥색 차양 휘장
	_rect(24, 18 + bob, 40, 26 + bob, JADE)
	_line(24, 27 + bob, 40, 27 + bob, GOLD, 1) # 술(장식)
	# 하단 주칠 격자 난간
	_rect(22, 29 + bob, 42, 32 + bob, Color("5c0000"))

	# C. 지붕 (화려한 조선 팔작지붕 곡선 주칠)
	_line(15, 14 + bob, 49, 14 + bob, RED_LACQUER, 2)
	_line(17, 12 + bob, 47, 12 + bob, RED_LACQUER, 2)
	_line(21, 10 + bob, 43, 10 + bob, RED_LACQUER.lightened(0.1), 2)
	_line(25, 8 + bob, 39, 8 + bob, RED_LACQUER.lightened(0.2), 2)
	# 처마 끝 금빛 들림
	_px(14, 13 + bob, GOLD)
	_px(50, 13 + bob, GOLD)
	# 지붕 위 보주 (황금 옥구슬)
	_rect(30, 5 + bob, 34, 7 + bob, GOLD)
	_px(32, 4 + bob, Color("fff275"))

	# D. 앞뒤 가마꾼/별감 (노란 철릭 + 패랭이/초립)
	# 앞 별감 (x = 10, y = 24)
	_paint_mini_bearer(10, 24 + bob, frame == 0)
	# 뒤 별감 (x = 54, y = 24)
	_paint_mini_bearer(54, 24 + bob, frame == 1)

static func _paint_mini_bearer(x: int, y: int, leg_f: bool) -> void:
	# 머리 및 립
	_rect(x - 2, y - 12, x + 2, y - 9, SKIN)
	_line(x - 4, y - 13, x + 4, y - 13, FELT_BLACK, 1)
	_rect(x - 2, y - 15, x + 2, y - 14, FELT_BLACK)
	# 노란 철릭
	_rect(x - 3, y - 8, x + 3, y - 2, YELLOW_CHWITA)
	_line(x - 3, y - 5, x + 3, y - 5, RED_LACQUER, 1) # 홍색 전대
	# 다리 (2프레임 교차)
	if leg_f:
		_line(x - 2, y - 1, x - 3, y + 5, WHITE, 2)
		_line(x + 1, y - 1, x + 2, y + 4, WHITE, 2)
	else:
		_line(x - 2, y - 1, x - 1, y + 4, WHITE, 2)
		_line(x + 1, y - 1, x + 3, y + 5, WHITE, 2)

## 2. 정조 대왕 기마 (56x56 대형 유닛, 《원행을묘정리의궤》 반차도 완벽 고증)
## - 늠름한 백마(황금 마구, 호피 안장 깔개 다래)
## - 진홍 철릭 융복(戎服) + 가슴/어깨 황금 오조룡보(五爪龍補) + 황금 옥대 + 별운검
## - 흑립 융모 전립 + 황금 옥개 + 청록빛 옥공작령(玉孔雀翎) 깃털 휘날림 + 황금 등채(지휘봉)
static func _paint_king_horse(_dir: int, frame: int, _w: int, _h: int) -> void:
	var bob: int = 1 if frame == 1 else 0

	# A. 늠름한 백마(명마) 바디 (56x56 규격)
	var hx: int = 28
	var hy: int = 33 + bob

	# 백마 다리 4개 (2프레임 당당한 행진)
	var horse_col := Color("f8fafc")
	var horse_shade := Color("cbd5e1")
	if frame == 0:
		_line(hx - 11, hy + 5, hx - 14, hy + 18, horse_shade, 3) # 뒷다리 외측
		_line(hx - 5, hy + 5, hx - 2, hy + 17, horse_col, 3)    # 뒷다리 내측
		_line(hx + 7, hy + 5, hx + 4, hy + 18, horse_shade, 3)  # 앞다리 내측
		_line(hx + 13, hy + 5, hx + 16, hy + 16, horse_col, 3)  # 앞다리 외측 (발 높이 듦)
	else:
		_line(hx - 11, hy + 5, hx - 8, hy + 17, horse_col, 3)
		_line(hx - 5, hy + 5, hx - 11, hy + 18, horse_shade, 3)
		_line(hx + 7, hy + 5, hx + 11, hy + 17, horse_col, 3)
		_line(hx + 13, hy + 5, hx + 8, hy + 18, horse_shade, 3)

	# 말굽 (검은 흑단 굽)
	_rect(hx - 15, hy + 17, hx - 12, hy + 18, FELT_BLACK)
	_rect(hx + 14, hy + 16, hx + 17, hy + 17, FELT_BLACK)

	# 백마 몸통 (근육질 입체감)
	_ell(hx, hy, 16, 8, horse_col)
	_ell(hx, hy + 2, 14, 6, horse_shade)
	_ell(hx - 10, hy - 1, 8, 8, horse_col) # 엉덩이
	_ell(hx + 9, hy - 1, 8, 8, horse_col)  # 가슴
	# 우아한 아치형 목과 늠름한 머리
	_line(hx + 9, hy - 2, hx + 18, hy - 13, horse_col, 7)
	_ell(hx + 20, hy - 13, 6, 5, horse_col)
	_rect(hx + 17, hy - 19, hx + 20, hy - 16, horse_col) # 쫑긋한 귀
	# 은빛 물결 갈기
	_line(hx + 8, hy - 4, hx + 16, hy - 15, Color("e2e8f0"), 2)
	# 풍성한 백색 말꼬리
	_line(hx - 16, hy, hx - 22, hy + 12, Color("e2e8f0"), 3)

	# 황금 굴레와 주홍 마구 술 장식
	_line(hx + 16, hy - 15, hx + 23, hy - 12, GOLD, 1)
	_px(hx + 19, hy - 10, RED_LACQUER)

	# B. 호피(호랑이 가죽) 안장 깔개 다래 & 황금 안장
	# 황갈색 호피 바탕
	_rect(hx - 9, hy - 8, hx + 9, hy - 1, Color("d97706"))
	# 호랑이 가죽 흑갈색 점박이 얼룩무늬 고증
	_px(hx - 6, hy - 6, Color("451a03"))
	_px(hx - 3, hy - 4, Color("451a03"))
	_px(hx + 2, hy - 6, Color("451a03"))
	_px(hx + 6, hy - 4, Color("451a03"))
	_line(hx - 9, hy, hx + 9, hy, GOLD, 1) # 안장 하단 황금 술

	# C. 정조 대왕 좌정 (진홍 철릭 융복 + 황금 오조룡보)
	var kx: int = 28
	var ky: int = 21 + bob

	# 진홍빛 철릭 융복
	_rect(kx - 6, ky - 9, kx + 6, ky + 1, Color("a81818"))
	_rect(kx - 5, ky - 8, kx + 5, ky, Color("c92a2a")) # 하이라이트
	# 양 소매
	_rect(kx - 8, ky - 7, kx - 6, ky - 2, Color("a81818"))
	_rect(kx + 6, ky - 7, kx + 8, ky - 2, Color("a81818"))

	# 가슴과 어깨의 황금 오조룡보 (五爪龍補)
	_rect(kx - 3, ky - 6, kx + 3, ky - 2, GOLD)
	_px(kx, ky - 4, Color("fff275"))
	_px(kx - 2, ky - 3, Color("fff275"))
	_px(kx + 2, ky - 3, Color("fff275"))
	_px(kx - 6, ky - 6, GOLD) # 어깨 용보
	_px(kx + 6, ky - 6, GOLD)

	# 황금 옥대 (허리띠 & 옥판 장식)
	_line(kx - 6, ky - 1, kx + 6, ky - 1, GOLD, 2)
	_px(kx - 3, ky - 1, JADE)
	_px(kx + 3, ky - 1, JADE)

	# 허리춤 왕의 보검 (별운검)
	_line(kx - 7, ky - 2, kx - 12, ky + 5, Color("cbd5e1"), 2)
	_px(kx - 7, ky - 2, GOLD) # 코등이

	# 정조 대왕 얼굴 (위엄 있는 성군의 안색과 수염)
	_rect(kx - 4, ky - 16, kx + 4, ky - 10, SKIN)
	_line(kx - 2, ky - 10, kx + 2, ky - 10, HAIR, 1) # 단정한 흑수염
	_px(kx + 1, ky - 13, HAIR) # 눈
	_px(kx + 1, ky - 11, SKIN.darkened(0.25)) # 콧날

	# 흑립 융모 전립 (검은 털모자 전립)
	_line(kx - 7, ky - 17, kx + 7, ky - 17, FELT_BLACK, 2)
	_rect(kx - 4, ky - 21, kx + 4, ky - 18, FELT_BLACK)
	_rect(kx - 1, ky - 23, kx + 1, ky - 22, GOLD) # 정수리 황금 옥개

	# 옥공작령(玉孔雀翎) 청록빛 깃털 휘날림
	_line(kx, ky - 23, kx - 7, ky - 27, Color("008080"), 2)
	_px(kx - 7, ky - 28, GOLD)
	_px(kx - 8, ky - 27, Color("00ffff"))

	# 오른손 황금 등채 (지휘봉)
	_line(kx + 6, ky - 5, kx + 13, ky - 12, GOLD, 2)
	_line(kx + 13, ky - 12, kx + 16, ky - 9, RED_LACQUER, 1) # 붉은 채찍 술

## 3. 정조 대왕 서장대 지휘 (32x44 대형 규격, 진홍 철릭 융복 + 등채 지휘)
static func _paint_king_drill(_dir: int, frame: int, _w: int, _h: int) -> void:
	var cx: int = 16
	var cy: int = 24

	# 진홍 철릭 융복 몸통
	_rect(cx - 6, cy - 10, cx + 6, cy + 1, Color("a81818"))
	_rect(cx - 5, cy - 9, cx + 5, cy, Color("c92a2a"))
	# 가슴과 어깨 황금 오조룡보
	_rect(cx - 3, cy - 7, cx + 3, cy - 3, GOLD)
	_px(cx, cy - 5, Color("fff275"))
	_px(cx - 6, cy - 7, GOLD)
	_px(cx + 6, cy - 7, GOLD)
	# 황금 옥대
	_line(cx - 6, cy - 1, cx + 6, cy - 1, GOLD, 2)
	_px(cx - 3, cy - 1, JADE)
	_px(cx + 3, cy - 1, JADE)

	# 하체 철릭 주름치마
	_rect(cx - 6, cy + 2, cx + 6, cy + 9, Color("a81818"))
	_line(cx - 5, cy + 5, cx + 5, cy + 5, Color("8b0000"), 1)
	# 흑단 신발(목화)
	_line(cx - 3, cy + 10, cx - 3, cy + 13, FELT_BLACK, 2)
	_line(cx + 3, cy + 10, cx + 3, cy + 13, FELT_BLACK, 2)

	# 얼굴 및 수염
	_rect(cx - 4, cy - 17, cx + 4, cy - 11, SKIN)
	_line(cx - 2, cy - 11, cx + 2, cy - 11, HAIR, 1)
	_px(cx + 1, cy - 14, HAIR)

	# 흑립 전립 & 옥공작령
	_line(cx - 7, cy - 18, cx + 7, cy - 18, FELT_BLACK, 2)
	_rect(cx - 4, cy - 22, cx + 4, cy - 19, FELT_BLACK)
	_rect(cx - 1, cy - 24, cx + 1, cy - 23, GOLD)
	_line(cx, cy - 24, cx - 6, cy - 28, Color("008080"), 2)
	_px(cx - 6, cy - 29, GOLD)

	# 오른손 등채 지휘 2프레임 역동 모션
	if frame == 0:
		# 등채를 높이 치켜들어 전군 주목 호령
		_line(cx + 6, cy - 6, cx + 12, cy - 15, GOLD, 2)
		_px(cx + 12, cy - 16, RED_LACQUER)
	else:
		# 등채를 전방 아래로 힘차게 휘두르며 발포/돌격 명령!
		_line(cx + 6, cy - 3, cx + 15, cy - 6, GOLD, 2)
		_line(cx + 15, cy - 6, cx + 17, cy - 3, RED_LACQUER, 2)

## 4. 선도 기병 / 경기감사 / 근위 기병 (44x44)
static func _paint_cavalry(role: String, _dir: int, frame: int, _w: int, _h: int) -> void:
	var bob: int = 1 if frame == 1 else 0
	var h_col := Color("5c3a21") if role != "gyeonggi_governor" else Color("8a5a32")
	_paint_horse_base(h_col, h_col.darkened(0.4), frame)

	# 기수 복식 (경기감사는 청색 관복, 기병은 철릭+전립)
	var rx: int = 22
	var ry: int = 17 + bob
	var robe_col := Color("1f5fa8") if role == "gyeonggi_governor" else BLUE_CHELLIK
	_rect(rx - 4, ry - 7, rx + 4, ry, robe_col)
	_line(rx - 4, ry - 3, rx + 4, ry - 3, YELLOW_CHWITA, 1)

	# 머리 및 전립
	_rect(rx - 3, ry - 13, rx + 3, ry - 8, SKIN)
	_line(rx - 5, ry - 14, rx + 4, ry - 14, FELT_BLACK, 1)
	_rect(rx - 3, ry - 16, rx + 3, ry - 15, FELT_BLACK)
	_line(rx, ry - 17, rx, ry - 20, Color("e74c3c"), 1) # 전립 깃

	# 기병 환도 / 경기감사 지휘채
	_line(rx + 4, ry - 4, rx + 8, ry - 8, Color("bdc3c7"), 1)

## 5. 황초령 취타대 (24x32, 노란 철릭 + 꿩깃 + 악기 연주 2프레임)
static func _paint_chwita(_dir: int, frame: int, _w: int, _h: int) -> void:
	var cx: int = 12
	var cy: int = 18

	# 황초령 (노란 철릭)
	_rect(cx - 4, cy - 6, cx + 4, cy + 4, YELLOW_CHWITA)
	_line(cx - 4, cy - 1, cx + 4, cy - 1, Color("1f4068"), 2) # 남색 전대
	# 다리 (2프레임 걷기)
	if frame == 0:
		_line(cx - 2, cy + 5, cx - 3, cy + 11, WHITE, 2)
		_line(cx + 2, cy + 5, cx + 3, cy + 10, WHITE, 2)
	else:
		_line(cx - 2, cy + 5, cx - 1, cy + 10, WHITE, 2)
		_line(cx + 2, cy + 5, cx + 4, cy + 11, WHITE, 2)

	# 머리 및 초립(꿩깃)
	_rect(cx - 3, cy - 12, cx + 3, cy - 7, SKIN)
	_line(cx - 5, cy - 13, cx + 5, cy - 13, STRAW, 1)
	_rect(cx - 3, cy - 16, cx + 3, cy - 14, STRAW)
	_line(cx + 2, cy - 16, cx + 6, cy - 20, Color("c0392b"), 1) # 붉은 꿩깃

	# 황금 나발 연주 (2프레임 치켜들기)
	if frame == 0:
		_line(cx + 3, cy - 4, cx + 10, cy - 8, GOLD, 2)
		_rect(cx + 9, cy - 10, cx + 11, cy - 6, GOLD) # 나발 구경
	else:
		_line(cx + 3, cy - 4, cx + 11, cy - 10, GOLD, 2)
		_rect(cx + 10, cy - 12, cx + 12, cy - 8, GOLD)

## 6. 장용영 포수 (24x32, 조총 2열 교대 사격 및 행진)
static func _paint_posu(_dir: int, frame: int, is_drill: bool, _w: int, _h: int) -> void:
	var cx: int = 12
	var cy: int = 18

	# 철릭 복식 (남색 + 붉은 소매)
	_rect(cx - 4, cy - 6, cx + 4, cy + 4, BLUE_CHELLIK)
	_line(cx - 4, cy - 1, cx + 4, cy - 1, RED_LACQUER, 1) # 전대

	if is_drill:
		# 2열 교대 사격 모션: 0 = 무릎 쏴 정밀 조준, 1 = 일제 격발 사격 및 연막
		if frame == 0:
			# 무릎 꿇은 낮은 자세
			_rect(cx - 4, cy + 5, cx + 4, cy + 9, BLUE_CHELLIK)
			_line(cx - 2, cy + 9, cx - 4, cy + 11, FELT_BLACK, 2)
			# 머리 및 벙거지
			_rect(cx - 3, cy - 11, cx + 3, cy - 6, SKIN)
			_line(cx - 5, cy - 12, cx + 5, cy - 12, FELT_BLACK, 1)
			_rect(cx - 3, cy - 15, cx + 3, cy - 13, FELT_BLACK)
			# 견착 조준 조총
			_line(cx - 1, cy - 3, cx + 10, cy - 3, Color("3e2723"), 2)
			_line(cx + 5, cy - 3, cx + 12, cy - 3, Color("7f8c8d"), 1)
		else:
			# 서서 쏴 격발 자세
			_line(cx - 2, cy + 5, cx - 2, cy + 11, WHITE, 2)
			_line(cx + 2, cy + 5, cx + 3, cy + 10, WHITE, 2)
			# 머리
			_rect(cx - 3, cy - 12, cx + 3, cy - 7, SKIN)
			_line(cx - 5, cy - 13, cx + 5, cy - 13, FELT_BLACK, 1)
			_rect(cx - 3, cy - 16, cx + 3, cy - 14, FELT_BLACK)
			# 조총 및 격발 화염
			_line(cx - 1, cy - 4, cx + 10, cy - 4, Color("3e2723"), 2)
			_line(cx + 5, cy - 4, cx + 12, cy - 4, Color("7f8c8d"), 1)
			# 총구 화염 및 자욱한 연막
			_rect(cx + 13, cy - 5, cx + 15, cy - 3, Color("fff176"))
			_px(cx + 16, cy - 4, Color("ff7043"))
			_ell(cx + 18, cy - 5, 3, 2, Color(0.95, 0.95, 0.95, 0.85))
	else:
		# 행진 자세
		if frame == 0:
			_line(cx - 2, cy + 5, cx - 3, cy + 11, WHITE, 2)
			_line(cx + 2, cy + 5, cx + 3, cy + 10, WHITE, 2)
		else:
			_line(cx - 2, cy + 5, cx - 1, cy + 10, WHITE, 2)
			_line(cx + 2, cy + 5, cx + 4, cy + 11, WHITE, 2)
		_rect(cx - 3, cy - 12, cx + 3, cy - 7, SKIN)
		_line(cx - 5, cy - 13, cx + 5, cy - 13, FELT_BLACK, 1)
		_rect(cx - 3, cy - 16, cx + 3, cy - 14, FELT_BLACK)
		# 어깨 메어총 행진
		_line(cx + 2, cy - 14, cx + 5, cy + 2, Color("3e2723"), 2)
		_line(cx + 2, cy - 16, cx + 3, cy - 14, Color("7f8c8d"), 1)

## 7. 장용영 살수 (24x32, 당파창 방어 진형 및 돌격 찌르기)
static func _paint_salsu(_dir: int, frame: int, is_drill: bool, _w: int, _h: int) -> void:
	var cx: int = 12
	var cy: int = 18

	_rect(cx - 4, cy - 6, cx + 4, cy + 4, Color("1b2631"))
	_line(cx - 4, cy - 1, cx + 4, cy - 1, GOLD, 1)

	if is_drill:
		if frame == 0:
			# 중단세 방어 진법
			_line(cx - 2, cy + 5, cx - 3, cy + 10, WHITE, 2)
			_line(cx + 2, cy + 5, cx + 3, cy + 10, WHITE, 2)
			_rect(cx - 3, cy - 12, cx + 3, cy - 7, SKIN)
			_line(cx - 5, cy - 13, cx + 5, cy - 13, FELT_BLACK, 1)
			_rect(cx - 3, cy - 16, cx + 3, cy - 14, FELT_BLACK)
			# 당파창 45도 세움
			_line(cx + 1, cy + 4, cx + 9, cy - 12, Color("795548"), 2)
			_line(cx + 7, cy - 13, cx + 11, cy - 11, Color("bdc3c7"), 1)
			_line(cx + 9, cy - 15, cx + 11, cy - 12, Color("bdc3c7"), 1)
		else:
			# 역동적 전방 런지 찌르기!
			_line(cx - 4, cy + 5, cx - 6, cy + 11, WHITE, 2)
			_line(cx + 2, cy + 5, cx + 6, cy + 9, WHITE, 2)
			_rect(cx - 2, cy - 11, cx + 4, cy - 6, SKIN)
			_line(cx - 4, cy - 12, cx + 6, cy - 12, FELT_BLACK, 1)
			_rect(cx - 2, cy - 15, cx + 4, cy - 13, FELT_BLACK)
			# 수평 힘찬 찌르기 및 창끝 은빛 궤적
			_line(cx - 2, cy - 2, cx + 11, cy - 4, Color("795548"), 2)
			_line(cx + 10, cy - 7, cx + 10, cy - 1, Color("bdc3c7"), 1)
			_line(cx + 11, cy - 4, cx + 14, cy - 4, Color("bdc3c7"), 2)
			_px(cx + 15, cy - 4, Color.WHITE) # 섬광
	else:
		if frame == 0:
			_line(cx - 2, cy + 5, cx - 3, cy + 11, WHITE, 2)
			_line(cx + 2, cy + 5, cx + 3, cy + 10, WHITE, 2)
		else:
			_line(cx - 2, cy + 5, cx - 1, cy + 10, WHITE, 2)
			_line(cx + 2, cy + 5, cx + 4, cy + 11, WHITE, 2)
		_rect(cx - 3, cy - 12, cx + 3, cy - 7, SKIN)
		_line(cx - 5, cy - 13, cx + 5, cy - 13, FELT_BLACK, 1)
		_rect(cx - 3, cy - 16, cx + 3, cy - 14, FELT_BLACK)
		# 곧게 세운 당파창 행진
		_line(cx + 3, cy - 16, cx + 3, cy + 6, Color("795548"), 2)
		_line(cx + 1, cy - 15, cx + 5, cy - 15, Color("bdc3c7"), 1)
		_line(cx + 3, cy - 18, cx + 3, cy - 15, Color("bdc3c7"), 1)

## 8. 장용영 사수 (24x32, 각궁 곡사 조준 및 행진)
static func _paint_sasu(_dir: int, frame: int, is_drill: bool, _w: int, _h: int) -> void:
	var cx: int = 12
	var cy: int = 18

	_rect(cx - 4, cy - 6, cx + 4, cy + 4, Color("117864"))
	_line(cx - 4, cy - 1, cx + 4, cy - 1, RED_LACQUER, 1)

	if is_drill:
		if frame == 0:
			# 화살 매김 장전
			_line(cx - 2, cy + 5, cx - 3, cy + 10, WHITE, 2)
			_line(cx + 2, cy + 5, cx + 3, cy + 10, WHITE, 2)
			_rect(cx - 3, cy - 12, cx + 3, cy - 7, SKIN)
			_line(cx - 5, cy - 13, cx + 5, cy - 13, FELT_BLACK, 1)
			_rect(cx - 3, cy - 16, cx + 3, cy - 14, FELT_BLACK)
			# 각궁 세움
			_line(cx + 3, cy - 12, cx + 7, cy - 2, Color("8d6e63"), 2)
			_line(cx + 7, cy - 2, cx + 3, cy + 5, Color("8d6e63"), 2)
			# 등 뒤 화살통
			_line(cx - 5, cy - 10, cx - 3, cy - 2, Color("5d4037"), 2)
		else:
			# 하늘 향해 각궁 만개 곡사 조준
			_line(cx - 3, cy + 5, cx - 4, cy + 11, WHITE, 2)
			_line(cx + 2, cy + 5, cx + 4, cy + 10, WHITE, 2)
			_rect(cx - 2, cy - 13, cx + 4, cy - 8, SKIN)
			_line(cx - 4, cy - 14, cx + 5, cy - 14, FELT_BLACK, 1)
			_rect(cx - 2, cy - 17, cx + 4, cy - 15, FELT_BLACK)
			# 팽팽하게 당겨진 각궁과 시위
			_line(cx + 5, cy - 14, cx + 10, cy - 6, Color("8d6e63"), 2)
			_line(cx + 10, cy - 6, cx + 6, cy + 2, Color("8d6e63"), 2)
			_line(cx + 5, cy - 14, cx - 1, cy - 6, WHITE, 1)
			_line(cx - 1, cy - 6, cx + 6, cy + 2, WHITE, 1)
			_line(cx - 2, cy - 6, cx + 11, cy - 6, Color("f39c12"), 1) # 장전된 화살
	else:
		if frame == 0:
			_line(cx - 2, cy + 5, cx - 3, cy + 11, WHITE, 2)
			_line(cx + 2, cy + 5, cx + 3, cy + 10, WHITE, 2)
		else:
			_line(cx - 2, cy + 5, cx - 1, cy + 10, WHITE, 2)
			_line(cx + 2, cy + 5, cx + 4, cy + 11, WHITE, 2)
		_rect(cx - 3, cy - 12, cx + 3, cy - 7, SKIN)
		_line(cx - 5, cy - 13, cx + 5, cy - 13, FELT_BLACK, 1)
		_rect(cx - 3, cy - 16, cx + 3, cy - 14, FELT_BLACK)
		_line(cx + 2, cy - 12, cx + 6, cy - 2, Color("8d6e63"), 2)

## 9. 장용영 기포병 (24x32, 불랑기포 모포 장전 및 포격 화염)
static func _paint_gipo(_dir: int, frame: int, is_drill: bool, _w: int, _h: int) -> void:
	var cx: int = 12
	var cy: int = 18

	# 포병 복식 (적갈색 철릭 + 흑립)
	_rect(cx - 4, cy - 6, cx + 4, cy + 4, Color("78281f"))
	_line(cx - 4, cy - 1, cx + 4, cy - 1, GOLD, 1)

	if is_drill:
		# 청동 불랑기포 모포 (포가 및 포신)
		_line(cx - 3, cy + 6, cx - 5, cy + 12, Color("3e2723"), 2) # 포가 삼각대
		_line(cx + 4, cy + 6, cx + 6, cy + 12, Color("3e2723"), 2)
		# 청동 포신
		_line(cx - 2, cy + 2, cx + 9, cy - 1, Color("b7950b"), 3)

		if frame == 0:
			# 자포(탄약통) 장전 포수 모션
			_rect(cx - 5, cy - 10, cx - 1, cy - 5, SKIN)
			_rect(cx - 5, cy - 13, cx - 1, cy - 11, FELT_BLACK)
			_line(cx - 3, cy - 4, cx - 1, cy + 1, Color("b7950b"), 2) # 자포 들고 삽입
		else:
			# 횃불 점화 및 포구 포격 화염 폭풍!
			_rect(cx - 6, cy - 8, cx - 2, cy - 3, SKIN)
			_line(cx - 4, cy - 2, cx - 1, cy + 1, Color("e67e22"), 2) # 점화선 닿음
			# 포구 화염 (적/황/백)
			_ell(cx + 12, cy - 2, 4, 3, Color("f39c12"))
			_ell(cx + 14, cy - 2, 2, 2, Color("fff176"))
			_px(cx + 16, cy - 2, Color.WHITE)
			# 자욱한 후폭풍 연막
			_ell(cx + 11, cy - 6, 3, 3, Color(0.9, 0.9, 0.9, 0.75))
			_ell(cx + 6, cy - 5, 2, 2, Color(0.8, 0.8, 0.8, 0.6))
	else:
		# 기포병 행진
		_paint_posu(_dir, frame, false, _w, _h)

## 10. 어기수 (황룡기/봉황기)
static func _paint_flag_bearer(_dir: int, frame: int, _w: int, _h: int) -> void:
	var cx: int = 12
	var cy: int = 18

	_rect(cx - 4, cy - 6, cx + 4, cy + 4, YELLOW_CHWITA)
	_line(cx - 4, cy - 1, cx + 4, cy - 1, RED_LACQUER, 1)

	if frame == 0:
		_line(cx - 2, cy + 5, cx - 3, cy + 11, WHITE, 2)
		_line(cx + 2, cy + 5, cx + 3, cy + 10, WHITE, 2)
	else:
		_line(cx - 2, cy + 5, cx - 1, cy + 10, WHITE, 2)
		_line(cx + 2, cy + 5, cx + 4, cy + 11, WHITE, 2)

	_rect(cx - 3, cy - 12, cx + 3, cy - 7, SKIN)
	_line(cx - 5, cy - 13, cx + 5, cy - 13, FELT_BLACK, 1)
	_rect(cx - 3, cy - 16, cx + 3, cy - 14, FELT_BLACK)

	# 긴 깃대와 펄럭이는 황룡 어기
	_line(cx + 2, cy - 22, cx + 2, cy + 8, Color("8d6e63"), 2)
	_px(cx + 2, cy - 23, GOLD)
	# 깃발 면 (2프레임 펄럭임)
	var flag_w: int = 8 if frame == 0 else 7
	_rect(cx + 4, cy - 21, cx + 4 + flag_w, cy - 13, GOLD)
	_rect(cx + 5, cy - 20, cx + 3 + flag_w, cy - 14, RED_LACQUER)

## 11. 조정 대신 (체제공 등)
static func _paint_official(role: String, _dir: int, frame: int, _w: int, _h: int) -> void:
	var cx: int = 12
	var cy: int = 18
	var col := Color("27ae60") if role == "chae_jegong" else Color("16a085")

	_rect(cx - 4, cy - 7, cx + 4, cy + 5, col)
	_rect(cx - 2, cy - 3, cx + 2, cy, GOLD) # 흉배
	_line(cx - 4, cy + 1, cx + 4, cy + 1, RED_LACQUER, 1) # 품대

	if frame == 0:
		_line(cx - 2, cy + 6, cx - 3, cy + 11, FELT_BLACK, 2)
		_line(cx + 2, cy + 6, cx + 3, cy + 10, FELT_BLACK, 2)
	else:
		_line(cx - 2, cy + 6, cx - 1, cy + 10, FELT_BLACK, 2)
		_line(cx + 2, cy + 6, cx + 4, cy + 11, FELT_BLACK, 2)

	_rect(cx - 3, cy - 13, cx + 3, cy - 8, SKIN)
	# 사모 (양옆 날개)
	_rect(cx - 3, cy - 17, cx + 3, cy - 14, FELT_BLACK)
	_line(cx - 6, cy - 15, cx + 6, cy - 15, FELT_BLACK, 1)

## 12. 호위 상궁
static func _paint_court_lady(_dir: int, frame: int, _w: int, _h: int) -> void:
	var cx: int = 12
	var cy: int = 18

	# 당의 (자줏빛) + 치마 (남청색)
	_rect(cx - 4, cy - 7, cx + 4, cy - 1, Color("8e44ad"))
	_rect(cx - 5, cy, cx + 5, cy + 8, Color("2c3e50"))

	if frame == 0:
		_line(cx - 2, cy + 9, cx - 2, cy + 11, WHITE, 2)
		_line(cx + 2, cy + 9, cx + 2, cy + 10, WHITE, 2)
	else:
		_line(cx - 2, cy + 9, cx - 2, cy + 10, WHITE, 2)
		_line(cx + 2, cy + 9, cx + 2, cy + 11, WHITE, 2)

	_rect(cx - 3, cy - 13, cx + 3, cy - 8, SKIN)
	# 가체 (풍성한 머리)
	_rect(cx - 4, cy - 17, cx + 4, cy - 14, HAIR)
	_px(cx, cy - 16, Color("e74c3c")) # 댕기/비녀

## 13. 가마꾼
static func _paint_bearer(_dir: int, frame: int, _w: int, _h: int) -> void:
	var cx: int = 12
	var cy: int = 18

	_rect(cx - 4, cy - 6, cx + 4, cy + 4, WHITE)
	_line(cx - 4, cy - 1, cx + 4, cy - 1, STRAW, 1)

	if frame == 0:
		_line(cx - 2, cy + 5, cx - 3, cy + 11, WHITE, 2)
		_line(cx + 2, cy + 5, cx + 3, cy + 10, WHITE, 2)
	else:
		_line(cx - 2, cy + 5, cx - 1, cy + 10, WHITE, 2)
		_line(cx + 2, cy + 5, cx + 4, cy + 11, WHITE, 2)

	_rect(cx - 3, cy - 12, cx + 3, cy - 7, SKIN)
	_line(cx - 5, cy - 13, cx + 5, cy - 13, STRAW, 1)
	_rect(cx - 2, cy - 15, cx + 2, cy - 14, STRAW)

static func _paint_soldier_generic(dir: int, frame: int, w: int, h: int) -> void:
	_paint_posu(dir, frame, false, w, h)

## 13. 격쟁(擊錚) 백성 (24x32, 흰 무명옷 + 상투 + 꽹과리/징 치는 모션)
static func _paint_gyeokjaeng(_dir: int, frame: int, _w: int, _h: int) -> void:
	var cx: int = 12
	var cy: int = 19
	var bob: int = 1 if frame == 1 else 0

	# 흰 무명 저고리 & 바지
	_rect(cx - 3, cy - 6 + bob, cx + 3, cy + 1 + bob, WHITE)
	_line(cx - 3, cy - 2 + bob, cx + 3, cy - 2 + bob, Color("34495e"), 1) # 남색 허리띠
	# 바지 & 다리 (역동적으로 뛰어들어온 포즈)
	if frame == 0:
		_line(cx - 2, cy + 2 + bob, cx - 4, cy + 8 + bob, WHITE, 2)
		_line(cx + 2, cy + 2 + bob, cx + 3, cy + 7 + bob, WHITE, 2)
	else:
		_line(cx - 2, cy + 2 + bob, cx - 2, cy + 8 + bob, WHITE, 2)
		_line(cx + 2, cy + 2 + bob, cx + 5, cy + 8 + bob, WHITE, 2)

	# 머리 (상투 & 댕기/머리띠)
	_rect(cx - 3, cy - 12 + bob, cx + 3, cy - 7 + bob, SKIN)
	_px(cx + 1, cy - 9 + bob, HAIR) # 눈
	_rect(cx - 1, cy - 15 + bob, cx + 1, cy - 13 + bob, HAIR) # 상투
	_line(cx - 3, cy - 11 + bob, cx + 3, cy - 11 + bob, Color("c0392b"), 1) # 붉은 머리띠

	# 왼손: 꽹과리 (황금빛 징)
	_ell(cx - 5, cy - 3 + bob, 4, 4, GOLD)
	_rect(cx - 6, cy - 4 + bob, cx - 4, cy - 2 + bob, Color("f39c12")) # 징 중앙 배꼽
	_line(cx - 5, cy - 7 + bob, cx - 5, cy - 4 + bob, Color("c0392b"), 1) # 징 끈

	# 오른손 & 꽹과리 채 (2프레임 타격 애니메이션)
	if frame == 0:
		# 채를 어깨 위로 번쩍 치켜든 준비 모션
		_line(cx + 3, cy - 4 + bob, cx + 7, cy - 11 + bob, Color("8b5a2b"), 2)
		_rect(cx + 6, cy - 13 + bob, cx + 8, cy - 11 + bob, WHITE) # 솜방망이 머리
	else:
		# 꽹과리를 힘차게 내리쳐 '쨍!' 울리는 타격 모션
		_line(cx + 2, cy - 3 + bob, cx - 3, cy - 3 + bob, Color("8b5a2b"), 2)
		_rect(cx - 4, cy - 4 + bob, cx - 2, cy - 2 + bob, WHITE)
		# 타격 금빛 스파크/충격파
		_px(cx - 7, cy - 6 + bob, GOLD)
		_px(cx - 2, cy - 6 + bob, GOLD)
		_px(cx - 8, cy + bob, Color("fff275"))
		_px(cx - 1, cy + bob, Color("fff275"))

## 14. 상언(上言) 유생/백성 (24x32, 옥색 도포 + 유건 + 두루마리 상소문 받쳐 든 부복 모션)
static func _paint_sangeon(_dir: int, frame: int, _w: int, _h: int) -> void:
	var cx: int = 12
	var cy: int = 21 # 꿇어앉은 낮은 자세
	var bob: int = 1 if frame == 1 else 0

	# 옥색 도포 (단정히 꿇어앉은 자세)
	_rect(cx - 5, cy - 6 + bob, cx + 5, cy + 4 + bob, Color("7ea8be"))
	_line(cx - 5, cy - 2 + bob, cx + 5, cy - 2 + bob, Color("2c3e50"), 1) # 세조대 허리끈
	# 무릎 꿇은 하체
	_rect(cx - 6, cy + 5 + bob, cx + 6, cy + 8 + bob, Color("6b94a8"))

	# 머리 및 유건 (검은 복건/유건)
	_rect(cx - 3, cy - 12 + bob, cx + 3, cy - 7 + bob, SKIN)
	_rect(cx - 3, cy - 15 + bob, cx + 3, cy - 13 + bob, FELT_BLACK) # 유건 윗부분
	_line(cx - 4, cy - 12 + bob, cx + 4, cy - 12 + bob, FELT_BLACK, 1)

	# 두 팔을 앞으로 정중히 뻗어 올린 자태
	_line(cx - 3, cy - 4 + bob, cx - 2, cy - 9 + bob, Color("7ea8be"), 2)
	_line(cx + 3, cy - 4 + bob, cx + 2, cy - 9 + bob, Color("7ea8be"), 2)

	# 상소문 (두루마리 흰 한지 + 주홍 매듭실)
	_line(cx - 6, cy - 10 + bob, cx + 6, cy - 10 + bob, WHITE, 2)
	_rect(cx - 7, cy - 11 + bob, cx - 6, cy - 9 + bob, Color("c9a86a")) # 두루마리 축
	_rect(cx + 6, cy - 11 + bob, cx + 7, cy - 9 + bob, Color("c9a86a"))
	_px(cx, cy - 10 + bob, RED_LACQUER) # 붉은 봉인 매듭

## 15. 궁중 정재 여령(女伶) 무용수 (24x32, 봉수당 진찬연 연화대무/선유락 도트 댄스)
static func _paint_court_dancer(_dir: int, frame: int, _w: int, _h: int) -> void:
	var cx: int = 12
	var cy: int = 18
	var bob: int = 1 if frame == 1 else 0

	# 풍성한 주홍/다홍 비단 치마 (A라인)
	_rect(cx - 5, cy + 2 + bob, cx + 5, cy + 8 + bob, Color("c0392b"))
	_rect(cx - 4, cy + 1 + bob, cx + 4, cy + 3 + bob, Color("e74c3c"))
	# 노란 삼당당의 (저고리)
	_rect(cx - 4, cy - 6 + bob, cx + 4, cy + 1 + bob, Color("f1c40f"))
	_line(cx - 4, cy - 1 + bob, cx + 4, cy - 1 + bob, Color("8e44ad"), 1) # 보라빛 고름

	# 머리: 화관(족두리, 금빛/홍옥 장식)
	_rect(cx - 3, cy - 12 + bob, cx + 3, cy - 7 + bob, SKIN)
	_px(cx + 1, cy - 9 + bob, HAIR)
	_rect(cx - 3, cy - 15 + bob, cx + 3, cy - 13 + bob, FELT_BLACK) # 얹은머리
	_rect(cx - 1, cy - 17 + bob, cx + 1, cy - 15 + bob, GOLD)       # 금빛 화관
	_px(cx, cy - 16 + bob, RED_LACQUER)                             # 옥구슬

	# 오색 한삼(汗衫)을 휘날리는 2프레임 춤사위 모션
	if frame == 0:
		# 오른팔 하늘 위, 왼팔 아래로 우아하게 휘날림
		_line(cx + 3, cy - 5 + bob, cx + 8, cy - 12 + bob, WHITE, 2)
		_line(cx + 7, cy - 13 + bob, cx + 9, cy - 15 + bob, Color("3498db"), 2) # 청색 한삼 끝
		_line(cx - 3, cy - 3 + bob, cx - 7, cy + 2 + bob, WHITE, 2)
		_line(cx - 7, cy + 3 + bob, cx - 8, cy + 5 + bob, RED_LACQUER, 2)       # 홍색 한삼 끝
	else:
		# 왼팔 하늘 위, 오른팔 아래로 턴하며 교차하는 모션
		_line(cx - 3, cy - 5 + bob, cx - 8, cy - 12 + bob, WHITE, 2)
		_line(cx - 7, cy - 13 + bob, cx - 9, cy - 15 + bob, Color("3498db"), 2)
		_line(cx + 3, cy - 3 + bob, cx + 7, cy + 2 + bob, WHITE, 2)
		_line(cx + 7, cy + 3 + bob, cx + 8, cy + 5 + bob, RED_LACQUER, 2)

## 16. 낙남헌 양로연 고을 노인 (24x32, 미색 도포 + 백발수염 + 비단 구장 鳩杖 지팡이)
static func _paint_elder(_dir: int, frame: int, _w: int, _h: int) -> void:
	var cx: int = 12
	var cy: int = 19
	var bob: int = 1 if frame == 1 else 0

	# 미색/상아색 백모 도포
	_rect(cx - 4, cy - 6 + bob, cx + 4, cy + 4 + bob, Color("ede8df"))
	_line(cx - 4, cy - 1 + bob, cx + 4, cy - 1 + bob, Color("27ae60"), 1) # 옥색 띠
	# 도포 치락 & 버선/혜
	_line(cx - 2, cy + 5 + bob, cx - 2, cy + 8 + bob, WHITE, 2)
	_line(cx + 2, cy + 5 + bob, cx + 2, cy + 8 + bob, WHITE, 2)

	# 머리: 탕건/망건 & 풍성한 백발 수염
	_rect(cx - 3, cy - 12 + bob, cx + 3, cy - 7 + bob, SKIN)
	_px(cx + 1, cy - 10 + bob, HAIR)
	_rect(cx - 3, cy - 15 + bob, cx + 3, cy - 13 + bob, FELT_BLACK) # 탕건
	# 백발 턱수염 (가슴까지 풍성히 내려옴)
	_rect(cx - 1, cy - 7 + bob, cx + 1, cy - 2 + bob, WHITE)
	_px(cx, cy - 1 + bob, WHITE)

	# 오른손: 비단 구장(鳩杖 - 비둘기 머리 장식 지팡이)
	_line(cx + 5, cy - 11 + bob, cx + 5, cy + 8 + bob, Color("8b5a2b"), 2) # 명아주 지팡이
	_rect(cx + 4, cy - 13 + bob, cx + 7, cy - 11 + bob, GOLD)             # 황금 비둘기 조각
	_line(cx + 4, cy - 10 + bob, cx + 6, cy - 8 + bob, JADE, 1)            # 옥색 비단 술 리본

## 17. 연도 도열 백성 - 읍(揖) 모션 (24x32, 두 손을 모아 공손히 허리 숙임)
static func _paint_spectator_bow(_dir: int, frame: int, _w: int, _h: int) -> void:
	var cx: int = 12
	var cy: int = 20
	var bob: int = 1 if frame == 1 else 0

	# 평민 백성 복식 (연옥색 저고리 & 흰 바지)
	_rect(cx - 3, cy - 6 + bob, cx + 3, cy + 1 + bob, Color("d5e1df"))
	_line(cx - 2, cy + 2 + bob, cx - 2, cy + 8 + bob, WHITE, 2)
	_line(cx + 2, cy + 2 + bob, cx + 2, cy + 8 + bob, WHITE, 2)

	# 머리 (상투 & 패랭이)
	_rect(cx - 3, cy - 12 + bob, cx + 3, cy - 7 + bob, SKIN)
	_line(cx - 4, cy - 13 + bob, cx + 4, cy - 13 + bob, STRAW, 1)
	_rect(cx - 2, cy - 15 + bob, cx + 2, cy - 14 + bob, STRAW)

	# 공손히 읍(揖)한 두 손 (가슴 앞에 모음)
	_rect(cx - 2, cy - 4 + bob, cx + 2, cy - 2 + bob, SKIN)
	_line(cx - 4, cy - 5 + bob, cx - 2, cy - 3 + bob, Color("d5e1df"), 2)
	_line(cx + 4, cy - 5 + bob, cx + 2, cy - 3 + bob, Color("d5e1df"), 2)

## 18. 연도 도열 백성 - 부복(俯伏) 모션 (24x32, 바닥에 엎드려 큰절)
static func _paint_spectator_prostrate(_dir: int, _frame: int, _w: int, _h: int) -> void:
	var cx: int = 12
	var cy: int = 22 # 땅바닥에 바짝 엎드린 형태

	# 바닥에 엎드린 몸통 및 도포/저고리
	_rect(cx - 6, cy - 3, cx + 6, cy + 4, Color("dbe3de"))
	# 땅에 닿은 머리 및 갓/상투
	_rect(cx - 2, cy - 5, cx + 2, cy - 2, SKIN)
	_rect(cx - 3, cy - 7, cx + 3, cy - 5, FELT_BLACK) # 머리
	# 땅을 짚은 양손
	_rect(cx - 7, cy + 1, cx - 5, cy + 3, SKIN)
	_rect(cx + 5, cy + 1, cx + 7, cy + 3, SKIN)

## 19. 연도 도열 백성 - 환호(歡呼) 모션 (24x32, 양손을 번쩍 들고 만세)
static func _paint_spectator_cheer(_dir: int, frame: int, _w: int, _h: int) -> void:
	var cx: int = 12
	var cy: int = 19
	var bob: int = 1 if frame == 1 else 0

	# 밝은 한복 저고리 (여성/남성 환호)
	_rect(cx - 3, cy - 6 + bob, cx + 3, cy + 1 + bob, Color("f39c12"))
	_line(cx - 2, cy + 2 + bob, cx - 3, cy + 8 + bob, WHITE, 2)
	_line(cx + 2, cy + 2 + bob, cx + 3, cy + 8 + bob, WHITE, 2)

	# 머리
	_rect(cx - 3, cy - 12 + bob, cx + 3, cy - 7 + bob, SKIN)
	_px(cx + 1, cy - 9 + bob, HAIR)
	_rect(cx - 1, cy - 14 + bob, cx + 1, cy - 13 + bob, HAIR)

	# 양손을 머리 위로 번쩍 치켜든 만세 모션
	if frame == 0:
		_line(cx - 4, cy - 5 + bob, cx - 7, cy - 13 + bob, Color("f39c12"), 2)
		_px(cx - 7, cy - 14 + bob, SKIN)
		_line(cx + 4, cy - 5 + bob, cx + 7, cy - 13 + bob, Color("f39c12"), 2)
		_px(cx + 7, cy - 14 + bob, SKIN)
	else:
		_line(cx - 4, cy - 5 + bob, cx - 6, cy - 15 + bob, Color("f39c12"), 2)
		_px(cx - 6, cy - 16 + bob, SKIN)
		_line(cx + 4, cy - 5 + bob, cx + 6, cy - 15 + bob, Color("f39c12"), 2)
		_px(cx + 6, cy - 16 + bob, SKIN)

## 20. 정조 대왕 득중정 활쏘기 모션 (32x44 대형 규격, 진홍 철릭 융복 + 4프레임 신궁 고증)
static func _paint_jeongjo_archery(_dir: int, frame: int, _w: int, _h: int) -> void:
	var cx: int = 16
	var cy: int = 24
	var f: int = frame % 4

	# 진홍 철릭 융복
	_rect(cx - 6, cy - 10, cx + 6, cy + 1, Color("a81818"))
	_rect(cx - 5, cy - 9, cx + 5, cy, Color("c92a2a"))
	# 가슴과 어깨 황금 오조룡보
	_rect(cx - 3, cy - 7, cx + 3, cy - 3, GOLD)
	_px(cx, cy - 5, Color("fff275"))
	_px(cx - 6, cy - 7, GOLD)
	_px(cx + 6, cy - 7, GOLD)
	# 황금 옥대
	_line(cx - 6, cy - 1, cx + 6, cy - 1, GOLD, 2)
	_px(cx - 3, cy - 1, JADE)
	_px(cx + 3, cy - 1, JADE)

	# 하체 철릭 주름치마 & 목화 신발
	_rect(cx - 6, cy + 2, cx + 6, cy + 9, Color("a81818"))
	_line(cx - 5, cy + 5, cx + 5, cy + 5, Color("8b0000"), 1)
	_line(cx - 3, cy + 10, cx - 3, cy + 13, FELT_BLACK, 2)
	_line(cx + 3, cy + 10, cx + 3, cy + 13, FELT_BLACK, 2)

	# 얼굴 및 수염
	_rect(cx - 4, cy - 17, cx + 4, cy - 11, SKIN)
	_line(cx - 2, cy - 11, cx + 2, cy - 11, HAIR, 1)
	_px(cx + 1, cy - 14, HAIR)

	# 흑립 전립 & 옥공작령
	_line(cx - 7, cy - 18, cx + 7, cy - 18, FELT_BLACK, 2)
	_rect(cx - 4, cy - 22, cx + 4, cy - 19, FELT_BLACK)
	_rect(cx - 1, cy - 24, cx + 1, cy - 23, GOLD)
	_line(cx, cy - 24, cx - 6, cy - 28, Color("008080"), 2)
	_px(cx - 6, cy - 29, GOLD)

	# 4프레임 활쏘기 모션
	match f:
		0: # 1) 장전 (각궁을 세우고 화살 깃을 시위에 매김)
			_line(cx + 6, cy - 14, cx + 9, cy - 4, Color("8b5a2b"), 2)
			_line(cx + 9, cy - 4, cx + 6, cy + 6, Color("8b5a2b"), 2)
			_line(cx + 6, cy - 14, cx + 6, cy + 6, WHITE, 1) # 시위
			_line(cx - 3, cy - 6, cx + 8, cy - 6, Color("f39c12"), 2) # 매긴 화살
			_px(cx - 4, cy - 6, WHITE) # 깃
		1: # 2) 만개 (활시위를 귀밑 뺨까지 팽팽하게 당긴 신궁의 위엄)
			_line(cx + 5, cy - 6, cx + 13, cy - 6, Color("a81818"), 2) # 앞으로 뻗은 왼팔
			# 힘껏 휜 각궁
			_line(cx + 13, cy - 16, cx + 11, cy - 6, Color("8b5a2b"), 2)
			_line(cx + 11, cy - 6, cx + 13, cy + 4, Color("8b5a2b"), 2)
			# 당겨진 시위
			_line(cx + 13, cy - 16, cx - 3, cy - 6, WHITE, 1)
			_line(cx - 3, cy - 6, cx + 13, cy + 4, WHITE, 1)
			# 조준된 화살대 및 촉
			_line(cx - 4, cy - 6, cx + 14, cy - 6, Color("fff275"), 2)
			_px(cx + 14, cy - 6, Color("e74c3c")) # 화살촉
		2: # 3) 방사 (시위 발사! 반동과 황금/주황 섬광)
			_line(cx + 11, cy - 15, cx + 10, cy + 4, WHITE, 1)
			_line(cx + 12, cy - 15, cx + 10, cy - 6, Color("8b5a2b"), 2)
			_line(cx + 10, cy - 6, cx + 12, cy + 4, Color("8b5a2b"), 2)
			# 발사 섬광 픽셀 FX
			_px(cx + 14, cy - 7, Color.WHITE)
			_px(cx + 15, cy - 6, Color("fff275"))
			_px(cx + 16, cy - 6, Color("f39c12"))
			_px(cx + 14, cy - 5, Color.WHITE)
		3: # 4) 명중 확인 (활을 살짝 내리고 위엄 있게 응시)
			_line(cx + 5, cy - 10, cx + 8, cy + 2, Color("8b5a2b"), 2)
			_line(cx + 5, cy - 10, cx + 5, cy + 2, WHITE, 1)
			_line(cx - 5, cy - 2, cx - 3, cy + 2, GOLD, 2) # 왼손 허리춤 옥대 짚음

## 21. 과녁판 (24x32, 웅후/포후 삼각대 + 홍심 동심원 + 화살 꽂힘)
static func _paint_archery_target(_dir: int, frame: int, _w: int, _h: int) -> void:
	var cx: int = 12
	var cy: int = 17
	var f: int = frame % 4

	# 삼각 받침대 (목재 다리 3본)
	_line(cx - 5, cy + 5, cx - 8, cy + 12, Color("5c3a21"), 2)
	_line(cx + 5, cy + 5, cx + 8, cy + 12, Color("5c3a21"), 2)
	_line(cx, cy + 5, cx, cy + 13, Color("3e2723"), 2)

	# 둥근 과녁판 (흑/청/백/적 동심원)
	_ell(cx, cy - 3, 9, 9, Color("1c1815"))       # 흑색 테두리
	_ell(cx, cy - 3, 7, 7, Color("2980b9"))       # 청색 고리
	_ell(cx, cy - 3, 5, 5, WHITE)                 # 백색 고리
	_ell(cx, cy - 3, 3, 3, Color("c0392b"))       # 홍심 (붉은 심)
	_px(cx, cy - 3, GOLD)                         # 황금 정중앙

	# 프레임에 따라 연속으로 꽂히는 화살들
	if f >= 1:
		# 첫 번째 살 (홍심 우상단 꽂힘)
		_line(cx - 5, cy - 8, cx - 1, cy - 4, Color("f39c12"), 1)
		_px(cx - 6, cy - 9, WHITE)
	if f >= 2:
		# 두 번째 살 (홍심 좌하단 꽂힘)
		_line(cx + 5, cy - 7, cx + 1, cy - 3, Color("f39c12"), 1)
		_px(cx + 6, cy - 8, WHITE)
	if f >= 3:
		# 세 번째 살 (홍심 정중앙 백발백중 꽂힘)
		_line(cx - 4, cy + 2, cx, cy - 3, Color("f39c12"), 1)
		_px(cx - 5, cy + 3, WHITE)
		# 명중 스파크
		_px(cx, cy - 4, Color("fff275"))
		_px(cx + 1, cy - 2, Color("fff275"))

## 공용 말 베이스 드로잉 (44x44)
static func _paint_horse_base(col: Color, mane: Color, frame: int) -> void:
	var hx: int = 22
	var hy: int = 25
	# 다리 4개 (2프레임 걷기)
	if frame == 0:
		_line(hx - 8, hy + 4, hx - 10, hy + 14, col.darkened(0.2), 2)
		_line(hx - 4, hy + 4, hx - 2, hy + 13, col, 2)
		_line(hx + 5, hy + 4, hx + 3, hy + 14, col.darkened(0.2), 2)
		_line(hx + 9, hy + 4, hx + 11, hy + 13, col, 2)
	else:
		_line(hx - 8, hy + 4, hx - 6, hy + 13, col, 2)
		_line(hx - 4, hy + 4, hx - 8, hy + 14, col.darkened(0.2), 2)
		_line(hx + 5, hy + 4, hx + 8, hy + 13, col, 2)
		_line(hx + 9, hy + 4, hx + 6, hy + 14, col.darkened(0.2), 2)

	# 몸통 타원
	_ell(hx, hy, 12, 6, col)
	# 엉덩이 & 가슴
	_ell(hx - 8, hy - 1, 6, 6, col)
	_ell(hx + 7, hy - 1, 6, 6, col)
	# 목과 머리
	_line(hx + 8, hy - 2, hx + 13, hy - 10, col, 5)
	_ell(hx + 14, hy - 10, 5, 4, col)
	_rect(hx + 12, hy - 15, hx + 14, hy - 13, col) # 귀
	# 갈기
	_line(hx + 7, hy - 4, hx + 11, hy - 12, mane, 2)
	# 꼬리
	_line(hx - 12, hy, hx - 15, hy + 8, mane, 2)

# -----------------------------------------------------------------------------
# 기본 픽셀 조작 및 외곽선 유틸리티
# -----------------------------------------------------------------------------
static func _px(x: int, y: int, col: Color) -> void:
	if x < 0 or x >= _c.get_width() or y < 0 or y >= _c.get_height():
		return
	if col.a >= 0.99:
		_c.set_pixel(x, y, col)
	else:
		_c.set_pixel(x, y, _c.get_pixel(x, y).blend(col))

static func _rect(x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	for yy in range(mini(y0, y1), maxi(y0, y1) + 1):
		for xx in range(mini(x0, x1), maxi(x0, x1) + 1):
			_px(xx, yy, col)

static func _line(x0: int, y0: int, x1: int, y1: int, col: Color, thick: int = 1) -> void:
	var n: int = maxi(absi(x1 - x0), absi(y1 - y0))
	for i in range(n + 1):
		var tt: float = float(i) / float(maxi(1, n))
		var x: int = roundi(lerpf(float(x0), float(x1), tt))
		var y: int = roundi(lerpf(float(y0), float(y1), tt))
		_px(x, y, col)
		if thick >= 2: _px(x + 1, y, col)
		if thick >= 3: _px(x, y + 1, col)

static func _ell(cx: int, cy: int, rx: int, ry: int, col: Color) -> void:
	for yy in range(cy - ry, cy + ry + 1):
		for xx in range(cx - rx, cx + rx + 1):
			var dx: float = float(xx - cx) / float(maxi(1, rx))
			var dy: float = float(yy - cy) / float(maxi(1, ry))
			if dx * dx + dy * dy <= 1.0:
				_px(xx, yy, col)

## 투명한 가장자리에 1px 검은 외곽선(OUTLINE) 둘러 도트 정돈
static func _add_outline(w: int, h: int) -> void:
	var solid: Array[Vector2i] = []
	for y in range(h):
		for x in range(w):
			if _c.get_pixel(x, y).a > 0.1:
				solid.append(Vector2i(x, y))

	for p: Vector2i in solid:
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0: continue
				var nx: int = p.x + dx
				var ny: int = p.y + dy
				if nx >= 0 and nx < w and ny >= 0 and ny < h:
					if _c.get_pixel(nx, ny).a < 0.1:
						_c.set_pixel(nx, ny, OUTLINE)
