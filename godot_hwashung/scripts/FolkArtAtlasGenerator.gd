class_name FolkArtAtlasGenerator
extends RefCounted

## 김홍도 풍속화 풍 흑백/담채 도트 일러스트 아틀라스 생성기
## folk_art_sheet.png를 절차적으로 생성하고 아틀라스 텍스처를 캐싱합니다.

const ATLAS_PATH := "res://assets/illustrations/folk_art/folk_art_sheet.png"
const CELL_SIZE := 80
const GRID_COLS := 4
const GRID_ROWS := 3

const KEYS := [
	"swing",          # 그네 타는 아낙
	"tavern",         # 국밥 먹는 주막
	"hunting_bear",   # 포수와 호랑이/곰
	"geojunggi",      # 거중기와 석수
	"ssireum",        # 씨름과 군중
	"seojangdae_guard", # 서장대와 군사
	"scholars",       # 책 읽는 선비들
	"gwana_conflict", # 관아 앞 실랑이
	"procession",     # 능행차 반차도
	"market",         # 번화한 저잣거리
	"blacksmith",     # 대장간
	"fishing"         # 수원천 낚시
]

static var _atlas_texture: Texture2D = null
static var _atlas_sub_textures: Dictionary = {}

static func ensure_atlas_generated() -> void:
	if AssetPaths.asset_exists(ATLAS_PATH):
		return
	generate_and_save_atlas()

static func generate_and_save_atlas() -> void:
	var total_w: int = CELL_SIZE * GRID_COLS
	var total_h: int = CELL_SIZE * GRID_ROWS
	var img: Image = Image.create(total_w, total_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for idx in range(KEYS.size()):
		var key: String = KEYS[idx]
		var col: int = idx % GRID_COLS
		var row: int = int(float(idx) / float(GRID_COLS))
		var sub_img: Image = _render_illustration_image(key)
		if sub_img != null:
			img.blit_rect(sub_img, Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(col * CELL_SIZE, row * CELL_SIZE))

	var save_path := "res://assets/illustrations/folk_art/folk_art_sheet.png"
	var err := img.save_png(save_path)
	if err != OK:
		# 절대 경로 폴백
		img.save_png("godot_hwashung/assets/illustrations/folk_art/folk_art_sheet.png")

static func get_art_texture(key: String) -> Texture2D:
	if _atlas_sub_textures.has(key):
		return _atlas_sub_textures[key]

	if _atlas_texture == null:
		if not AssetPaths.asset_exists(ATLAS_PATH):
			generate_and_save_atlas()
		if AssetPaths.asset_exists(ATLAS_PATH):
			_atlas_texture = load(ATLAS_PATH)
		else:
			# 메모리 직접 렌더링
			var direct_img: Image = _render_illustration_image(key)
			if direct_img != null:
				var direct_tex := ImageTexture.create_from_image(direct_img)
				_atlas_sub_textures[key] = direct_tex
				return direct_tex

	var idx: int = KEYS.find(key)
	if idx < 0:
		idx = 0

	var col: int = idx % GRID_COLS
	var row: int = int(float(idx) / float(GRID_COLS))
	var region := Rect2(float(col * CELL_SIZE), float(row * CELL_SIZE), float(CELL_SIZE), float(CELL_SIZE))

	var atlas_tex := AtlasTexture.new()
	atlas_tex.atlas = _atlas_texture
	atlas_tex.region = region
	_atlas_sub_textures[key] = atlas_tex
	return atlas_tex

static func _render_illustration_image(key: String) -> Image:
	var bg := PixelArt.new(CELL_SIZE, CELL_SIZE)
	var f := PixelArt.new(CELL_SIZE, CELL_SIZE)

	# 김홍도 풍속화 느낌의 먹선 + 은은한 담채 한지 톤
	var paper_ink_bg := Color("f5eedc")
	var paper_wash := Color("ebe0c6")
	bg.rect(0, 0, CELL_SIZE, CELL_SIZE, paper_ink_bg)
	for y in range(CELL_SIZE):
		if y % 3 == 0:
			bg.line(0, y, CELL_SIZE, y, paper_wash)

	match key:
		"swing":
			# 단원 김홍도 '단오' 그네 타는 아낙
			PortraitScenes.hills(bg, 50, 14.0, Color("929d84"), 1.2)
			PortraitScenes.grass(bg, 58, Color("9fa882"), Color("7a8264"))
			f.rect(36, 4, 6, 62, Color("5a4436"))
			f.ball(38, 8, 16, 8, Color("627456"))
			f.line(48, 10, 52, 52, Color("8b3d32"), 1)
			f.line(54, 10, 58, 52, Color("8b3d32"), 1)
			f.rect(48, 52, 12, 3, Color("c2a67e"))
			PortraitFolk.woman(f, 54, 52, Color("b24a3b"), "braid", Vector2i(-4, -6), Vector2i(4, -6))
		"tavern":
			# 주막에서 장터국밥 먹는 백성과 주모
			PortraitScenes.hills(bg, 46, 12.0, Color("9da892"), 0.5)
			PortraitScenes.ground_path(bg, 54, Color("dcd0b8"))
			PortraitScenes.hall(f, 22, 54, 56, 1)
			# 평상 및 국밥 그릇
			f.rect(26, 56, 28, 8, Color("8c6a46"))
			f.rect(30, 52, 8, 4, Color("e4ded0")) # 사발
			f.rect(42, 52, 8, 4, Color("e4ded0"))
			f.ball(34, 50, 2, 2, Color("944228")) # 국밥
			f.ball(46, 50, 2, 2, Color("944228"))
			PortraitFolk.man(f, 20, 68, Color("4a627a"), "gat", Vector2i(4, -2), Vector2i(6, -4))
			PortraitFolk.woman(f, 60, 68, Color("8a5242"), "bun", Vector2i(-4, -3), Vector2i(3, -2))
		"hunting_bear":
			# 포수와 호랑이/광교산 곰
			PortraitScenes.hills(bg, 46, 14.0, Color("7a8870"), 2.2)
			PortraitScenes.grass(bg, 56, Color("889674"), Color("5a664e"))
			PortraitScenes.pine(bg, 68, 58, 1.0)
			PortraitFolk.man(f, 18, 70, Color("6a5a4a"), "satgat", Vector2i(7, -5), Vector2i(-1, -4))
			f.line(26, 56, 30, 68, Color("5a422e"), 2) # 조총
			# 곰/호랑이
			f.ell(54, 60, 14, 10, Color("342a26"))
			f.ball(46, 54, 6, 6, Color("342a26"))
			f.ball(43, 52, 2, 2, Color("201a16"))
		"geojunggi":
			# 정약용의 거중기와 석수
			PortraitScenes.hills(bg, 44, 10.0, Color("909a86"), 1.0)
			PortraitScenes.ground_path(bg, 54, Color("cfc3a6"))
			# 거중기 삼각 목재 프레임
			f.line(22, 70, 36, 16, Color("68482c"), 3)
			f.line(50, 70, 36, 16, Color("68482c"), 3)
			f.line(26, 48, 46, 48, Color("68482c"), 2)
			# 도르래와 밧줄
			f.ball(36, 20, 4, 4, Color("423224"))
			f.ball(36, 42, 4, 4, Color("423224"))
			f.line(36, 22, 36, 52, Color("c8b082"), 1)
			# 매달린 성돌
			f.rect(30, 52, 12, 10, Color("888a8c"))
			f.rect(31, 53, 10, 8, Color("adb0b2"))
			PortraitFolk.man(f, 14, 70, Color("506048"), "headband", Vector2i(5, -4), Vector2i(6, -2))
			PortraitFolk.man(f, 62, 70, Color("dcd2be"), "topknot", Vector2i(-5, -4), Vector2i(-4, 2))
		"ssireum":
			# 단원 김홍도 '씨름'
			PortraitScenes.hills(bg, 44, 12.0, Color("929d84"), 0.8)
			bg.ell(40, 66, 38, 10, Color("e2d4ae"))
			for k in range(3):
				PortraitFolk.man(f, 10 + k * 8, 54, Color("ebe3d4"), "topknot")
				PortraitFolk.man(f, 54 + k * 8, 54, Color("d4c6a6"), "gat")
			PortraitFolk.man(f, 33, 66, Color("345c8c"), "none", Vector2i(5, 2), Vector2i(7, -2))
			PortraitFolk.man(f, 46, 66, Color("b24436"), "none", Vector2i(-7, 0), Vector2i(-5, 3))
		"seojangdae_guard":
			# 서장대 누각과 보초 군사
			PortraitScenes.hills(bg, 40, 16.0, Color("6f7f6a"), 1.8)
			PortraitScenes.hall(f, 24, 46, 52, 2)
			PortraitScenes.flag(f, 16, 22, Color("2f568a"), 20)
			PortraitFolk.man(f, 38, 68, Color("2a4468"), "jeonlip", Vector2i(3, -4), Vector2i(5, -8))
			f.line(45, 64, 45, 42, Color("684a28"), 1) # 창
			f.poly(PackedVector2Array([Vector2(45, 38), Vector2(47, 43), Vector2(43, 43)]), Color("b8c0c8"))
		"scholars":
			# 서당/서원에서 책 읽는 유생들
			PortraitScenes.hills(bg, 46, 10.0, Color("909a86"), 0.4)
			PortraitScenes.ground_path(bg, 52, Color("d6c8a4"))
			PortraitScenes.tile_roof(bg, 4, 26, 24, 44, Color("3a424a"))
			bg.rect(6, 38, 20, 14, Color("efe8d8"))
			# 서안(책상)과 책
			f.rect(34, 58, 22, 6, Color("6c4a2c"))
			f.rect(38, 54, 8, 4, Color("386292")) # 파란 책
			f.rect(48, 54, 7, 4, Color("e4ded0"))
			PortraitFolk.man(f, 24, 68, Color("3a5a78"), "gat", Vector2i(4, -3), Vector2i(6, -2))
			PortraitFolk.man(f, 64, 68, Color("dcd4c0"), "gat", Vector2i(-5, -2), Vector2i(-3, -3))
		"gwana_conflict":
			# 관아 앞 유생과 포졸의 실랑이
			PortraitScenes.hills(bg, 46, 10.0, Color("8a9680"), 0.2)
			PortraitScenes.hall(f, 26, 44, 48, 1)
			# 포졸과 양반
			PortraitFolk.man(f, 24, 68, Color("2d4668"), "jeonlip", Vector2i(4, -5), Vector2i(5, 2))
			f.line(18, 62, 34, 62, Color("9a4436"), 2) # 육모방망이/포승줄
			PortraitFolk.man(f, 50, 68, Color("d6cbb2"), "gat", Vector2i(-5, -6), Vector2i(-2, -4))
		"procession":
			# 정조 대왕 을묘원행 반차도 행렬
			PortraitScenes.hills(bg, 44, 10.0, Color("88967c"), 1.2)
			PortraitScenes.ground_path(bg, 52, Color("cfc3a6"))
			PortraitScenes.flag(f, 12, 24, Color("d4a024"), 22) # 황룡기
			PortraitScenes.flag(f, 22, 28, Color("b2382c"), 18)
			PortraitFolk.man(f, 32, 66, Color("b2382c"), "helmet", Vector2i(3, -4), Vector2i(4, 3))
			PortraitFolk.man(f, 44, 66, Color("2d4e78"), "jeonlip", Vector2i(2, -3), Vector2i(3, 2))
			# 임금 가마/말
			f.rect(52, 48, 16, 12, Color("9a2824"))
			f.rect(54, 46, 12, 3, Color("d8a834"))
		"market":
			# 번화한 팔달문 밖 저잣거리
			PortraitScenes.hills(bg, 44, 10.0, Color("909a86"), 0.3)
			PortraitScenes.ground_path(bg, 54, Color("d8cca8"))
			PortraitScenes.tile_roof(bg, 2, 30, 22, 38, Color("424650"))
			# 난전 차일(천막)
			f.poly(PackedVector2Array([Vector2(32, 38), Vector2(58, 38), Vector2(52, 48), Vector2(26, 48)]), Color("e8deb8"))
			f.line(26, 48, 26, 68, Color("7a5632"), 1)
			f.line(52, 48, 52, 68, Color("7a5632"), 1)
			# 좌판 물품들
			f.rect(30, 58, 18, 6, Color("8a6642"))
			f.ball(34, 56, 3, 3, Color("c84232")) # 옹기/비단
			f.ball(42, 56, 3, 3, Color("3a6692"))
			PortraitFolk.man(f, 20, 70, Color("4a6652"), "satgat", Vector2i(4, -3), Vector2i(2, 2))
			PortraitFolk.man(f, 62, 70, Color("d8cca8"), "topknot", Vector2i(-4, -2), Vector2i(2, 2))
		"blacksmith":
			# 대장간의 야철 장인
			PortraitScenes.hills(bg, 46, 10.0, Color("848c7c"), 0.5)
			PortraitScenes.ground_path(bg, 54, Color("cfc3a6"))
			f.rect(32, 52, 16, 14, Color("4a423a")) # 화덕
			f.ball(40, 50, 4, 4, Color("e85428")) # 불꽃
			f.ball(40, 48, 2, 2, Color("f8c438"))
			f.rect(52, 60, 10, 8, Color("282c32")) # 모루
			PortraitFolk.man(f, 24, 70, Color("d8cfbe"), "headband", Vector2i(6, -4), Vector2i(4, 2))
			PortraitFolk.man(f, 66, 70, Color("7a4a32"), "none", Vector2i(-5, -6), Vector2i(-3, -2))
			f.line(60, 56, 54, 60, Color("242628"), 2) # 쇠망치
		"fishing":
			# 수원천 낚시
			PortraitScenes.hills(bg, 44, 14.0, Color("8a9678"), 2.7)
			PortraitScenes.grass(bg, 50, Color("84966e"), Color("5c6e4e"))
			PortraitScenes.water(bg, 0, 60, CELL_SIZE, 20, Color("6a96b2"), Color("386280"))
			PortraitFolk.man(f, 18, 60, Color("7a8c6a"), "satgat", Vector2i(5, 3), Vector2i(9, 0))
			f.line(26, 54, 58, 30, Color("7a562c"))
			f.line(58, 30, 58, 62, Color("e8e0c8"))
			f.ball(58, 62, 1.6, 1.6, Color("b83224"))
		_:
			PortraitScenes.sky(bg, Color("b8dcf0"), Color("f4efe0"), 52)

	# 전통 붓글씨 느낌의 먹선 아웃라인
	f.outline(Color("26201a"))

	# 한지 질감 텍스처와 인쇄 먹선 합성
	bg.blit(f)

	# 은은한 먹 번짐 외곽 사각 테두리
	var border_col := Color("4a3c2c")
	bg.rect(0, 0, CELL_SIZE, 1, border_col)
	bg.rect(0, CELL_SIZE - 1, CELL_SIZE, 1, border_col)
	bg.rect(0, 0, 1, CELL_SIZE, border_col)
	bg.rect(CELL_SIZE - 1, 0, 1, CELL_SIZE, border_col)

	var tex: ImageTexture = ImageTexture.create_from_image(bg.img)
	return tex.get_image()
