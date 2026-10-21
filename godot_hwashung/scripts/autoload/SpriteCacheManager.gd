extends Node

## [스프라이트 캐시 및 PNG 자동 덤프 싱글톤]
## 외부 PNG가 존재하면 최우선 로드하여 VRAM에 캐싱하고,
## 미존재 시 절차적 이미지 생성 후 res://assets/sprites/ 하위에 .png 파일로 자동 덤프(저장)하여
## 사용자가 직접 도트 이미지를 수정할 수 있도록 지원합니다.

static var instance: SpriteCacheManager = null
static var _texture_cache: Dictionary = {}
const BASE_DIR := "res://assets/sprites/"
const SPRITE_CACHE_VERSION := "v8_joseon_48x48_named26_outline"

func _init() -> void:
	instance = self

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
	instance = self
	_ensure_directories()
	upgrade_procedural_pngs_v2()
	upgrade_procedural_pngs_v3()
	upgrade_procedural_pngs_v4()
	upgrade_procedural_pngs_v4_iso()
	upgrade_procedural_pngs_v5_npc()
	upgrade_procedural_pngs_v6_iso()
	upgrade_procedural_pngs_v7_iso_houses()
	upgrade_procedural_pngs_v8_purge_flat_houses()
	upgrade_procedural_pngs_v8_joseon_48x48_named26()
	upgrade_procedural_pngs_v9_pure_png_lakes_and_shops()
	preload_and_dump_all_standards()

static func _ensure_directories() -> void:
	for sub: String in ["buildings", "buildings_modern", "terrain", "npcs", "npcs/named", "ui", "vfx"]:
		var dir_path: String = BASE_DIR + sub
		var global_dir: String = ProjectSettings.globalize_path(dir_path)
		if not DirAccess.dir_exists_absolute(global_dir):
			DirAccess.make_dir_recursive_absolute(global_dir)
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)

## [v2 고디테일 업그레이드] 기와골/주춧돌/단청/사계절 둔전/수변 자갈 고해상도 픽셀 PNG 1회 자동 재생성
static func upgrade_procedural_pngs_v2() -> void:
	var marker_path: String = BASE_DIR + ".v2_done"
	var global_marker: String = ProjectSettings.globalize_path(marker_path)
	if FileAccess.file_exists(global_marker) or FileAccess.file_exists(marker_path):
		return

	var b_upgrades: Dictionary = {
		"thatch_house": Vector2i(64, 64),
		"tile_house": Vector2i(64, 64),
		"market_shop": Vector2i(64, 64),
		"workshop": Vector2i(64, 64),
		"yusubu": Vector2i(128, 128),
		"seojangdae": Vector2i(128, 128),
		"yeonmudae": Vector2i(128, 128),
		"haenggung": Vector2i(448, 448)
	}
	for b_id: String in b_upgrades.keys():
		_force_dump_texture("buildings", b_id, b_upgrades[b_id])

	var t_upgrades: Dictionary = {
		"farm_spring": Vector2i(64, 32),
		"farm_summer": Vector2i(64, 32),
		"farm_autumn": Vector2i(64, 32),
		"farm_winter": Vector2i(64, 32),
		"farm_normal": Vector2i(64, 32),
		"edge_wall_rock": Vector2i(64, 32),
		"edge_stream_pebbles": Vector2i(64, 32),
		"edge_road_dust": Vector2i(64, 32)
	}
	for t_id: String in t_upgrades.keys():
		_force_dump_texture("terrain", t_id, t_upgrades[t_id])

	var fa := FileAccess.open(global_marker, FileAccess.WRITE)
	if fa:
		fa.store_string("v2_upgraded")
		fa.close()
	else:
		var fa2 := FileAccess.open(marker_path, FileAccess.WRITE)
		if fa2:
			fa2.store_string("v2_upgraded")
			fa2.close()

## [v3 LOD 및 VFX 업그레이드] NPC 4프레임 보행 시트, 소품, 그림자, 군중 마커, 연기, 물결 PNG 1회 자동 생성
static func upgrade_procedural_pngs_v3() -> void:
	var marker_path: String = BASE_DIR + ".v3_done"
	var global_marker: String = ProjectSettings.globalize_path(marker_path)
	if FileAccess.file_exists(global_marker) or FileAccess.file_exists(marker_path):
		return

	var npc_upgrades: Dictionary = {
		"citizen_male_sheet": Vector2i(128, 48),
		"citizen_female_sheet": Vector2i(128, 48),
		"patrol_officer_sheet": Vector2i(128, 48),
		"prop_pack_luggage": Vector2i(16, 16),
		"npc_shadow": Vector2i(24, 12)
	}
	for n_id: String in npc_upgrades.keys():
		_force_dump_texture("npcs", n_id, npc_upgrades[n_id])

	var vfx_upgrades: Dictionary = {
		"crowd_marker": Vector2i(32, 32),
		"smoke_puff": Vector2i(16, 16),
		"water_ripple": Vector2i(64, 32)
	}
	for v_id: String in vfx_upgrades.keys():
		_force_dump_texture("vfx", v_id, vfx_upgrades[v_id])

	var fa := FileAccess.open(global_marker, FileAccess.WRITE)
	if fa:
		fa.store_string("v3_upgraded")
		fa.close()
	else:
		var fa2 := FileAccess.open(marker_path, FileAccess.WRITE)
		if fa2:
			fa2.store_string("v3_upgraded")
			fa2.close()

## [v4 무손실 SubViewport 복원 및 정사각형 아티팩트 제거]
## 우물 원본 CanvasItem 드로잉을 SubViewport로 캡처하여 고품질 투명 PNG로 저장하고,
## 길가/물가에 사각형 얼룩을 남기던 edge_*.png들을 완전 투명 PNG로 덮어써서 갱신.
static func upgrade_procedural_pngs_v4() -> void:
	var marker_path: String = BASE_DIR + ".v4_done"
	var global_marker: String = ProjectSettings.globalize_path(marker_path)
	if FileAccess.file_exists(global_marker) or FileAccess.file_exists(marker_path):
		return

	# 1. 기존 불량 PNG 파일 삭제 (우물 및 경계 오버레이)
	for fname: String in ["buildings/well.png", "terrain/edge_stream_pebbles.png", "terrain/edge_road_dust.png", "terrain/edge_wall_rock.png"]:
		var p: String = BASE_DIR + fname
		var gp: String = ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(gp):
			DirAccess.remove_absolute(gp)
		elif FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
		_texture_cache.erase(fname.trim_suffix(".png"))

	# 2. 우물 원본 CanvasItem 드로잉 -> SubViewport 캡처 투명 PNG 생성
	bake_canvas_draw_to_png("buildings", "well", Vector2i(64, 64), draw_well_original, true)

	# 3. 투명화된 지형 경계 텍스처 덤프 (사각 얼룩 영구 방지)
	for t_id: String in ["edge_stream_pebbles", "edge_road_dust", "edge_wall_rock"]:
		_force_dump_texture("terrain", t_id, Vector2i(64, 32))

	var fa4 := FileAccess.open(global_marker, FileAccess.WRITE)
	if fa4:
		fa4.store_string("v4_upgraded")
		fa4.close()
	else:
		var fa4_2 := FileAccess.open(marker_path, FileAccess.WRITE)
		if fa4_2:
			fa4_2.store_string("v4_upgraded")
			fa4_2.close()

## [v4 ISO Masterpiece 업그레이드]
## 가옥 20종, 상점 20종(우시장 보존), 공방 13종, 특수공간 5종, 랜드마크 4종을 2.5D 아이소메트릭으로 일괄 베이킹
static func upgrade_procedural_pngs_v4_iso() -> void:
	var marker_path: String = BASE_DIR + ".v4_iso_masterpiece_done"
	var global_marker: String = ProjectSettings.globalize_path(marker_path)
	if FileAccess.file_exists(global_marker) or FileAccess.file_exists(marker_path):
		return

	# 1. 초가집 10종
	for i: int in range(7):
		var id_s: String = "thatch_house_%02d" % (i + 1)
		bake_direct_iso_image("buildings", id_s, Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_thatch_house").bind(i), true)
	for i: int in range(7, 10):
		var id_s: String = "thatch_house_%02d" % (i + 1)
		bake_direct_iso_image("buildings", id_s, Vector2i(96, 88), Callable(ProceduralIsoArtist, "paint_thatch_house").bind(i), true)

	# 2. 기와집 10종
	for i: int in range(4):
		var id_s: String = "tile_house_%02d" % (i + 1)
		bake_direct_iso_image("buildings", id_s, Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_tile_house").bind(i), true)
	for i: int in range(4, 7):
		var id_s: String = "tile_house_%02d" % (i + 1)
		bake_direct_iso_image("buildings", id_s, Vector2i(96, 88), Callable(ProceduralIsoArtist, "paint_tile_house").bind(i), true)
	for i: int in range(7, 9):
		var id_s: String = "tile_house_%02d" % (i + 1)
		bake_direct_iso_image("buildings", id_s, Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_tile_house").bind(i), true)
	bake_direct_iso_image("buildings", "tile_house_10_3x2", Vector2i(160, 136), Callable(ProceduralIsoArtist, "paint_tile_house").bind(9), true)
	bake_direct_iso_image("buildings", "tile_house_10_3x3", Vector2i(192, 160), Callable(ProceduralIsoArtist, "paint_tile_house").bind(10), true)

	# 3. 상점 20종 (팔달문 우시장 09_paldal_cattle_market 포함)
	for i: int in range(20):
		var id_s: String = "market_shop_%02d" % (i + 1)
		bake_direct_iso_image("buildings", id_s, Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_market_shop").bind(i), true)

	# 4. 공방 13종
	var ws_small: Array[String] = ["ws_1x1_carpenter", "ws_1x1_bamboo", "ws_1x1_hanji", "ws_1x1_metalcraft", "ws_1x1_leather"]
	for k: String in ws_small:
		bake_direct_iso_image("buildings", k, Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_workshop").bind(k), true)

	var ws_mid: Array[String] = ["ws_2x1_blacksmith", "ws_2x1_dyeing", "ws_2x1_stonemason", "ws_2x1_tile_kiln", "ws_2x1_shoemaker"]
	for k: String in ws_mid:
		bake_direct_iso_image("buildings", k, Vector2i(96, 88), Callable(ProceduralIsoArtist, "paint_workshop").bind(k), true)

	var ws_large: Array[String] = ["ws_2x2_ceramics", "ws_2x2_lumber_machinery"]
	for k: String in ws_large:
		bake_direct_iso_image("buildings", k, Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_workshop").bind(k), true)

	bake_direct_iso_image("buildings", "ws_3x3_royal_arsenal", Vector2i(192, 160), Callable(ProceduralIsoArtist, "paint_workshop").bind("ws_3x3_royal_arsenal"), true)

	# 5. 방·리 특수 공동체 공간 5종
	bake_direct_iso_image("buildings", "seodang", Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_special_facility").bind("seodang"), true)
	bake_direct_iso_image("buildings", "maegok_seowon", Vector2i(192, 160), Callable(ProceduralIsoArtist, "paint_special_facility").bind("maegok_seowon"), true)
	bake_direct_iso_image("buildings", "women_play_yard", Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_special_facility").bind("women_play_yard"), true)
	bake_direct_iso_image("buildings", "children_play_yard", Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_special_facility").bind("children_play_yard"), true)
	bake_direct_iso_image("buildings", "well", Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_special_facility").bind("well"), true)

	# 6. 핵심 랜드마크 4종
	bake_direct_iso_image("buildings", "haenggung", Vector2i(448, 320), Callable(ProceduralIsoArtist, "paint_landmark").bind("haenggung"), true)
	bake_direct_iso_image("buildings", "seojangdae", Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_landmark").bind("seojangdae"), true)
	bake_direct_iso_image("buildings", "yeonmudae", Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_landmark").bind("yeonmudae"), true)
	bake_direct_iso_image("buildings", "yusubu", Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_landmark").bind("yusubu"), true)

	# 7. 기본 호환 에셋 업데이트 (thatch_house, tile_house, market_shop, workshop)
	bake_direct_iso_image("buildings", "thatch_house", Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_thatch_house").bind(0), true)
	bake_direct_iso_image("buildings", "tile_house", Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_tile_house").bind(0), true)
	bake_direct_iso_image("buildings", "market_shop", Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_market_shop").bind(0), true)
	bake_direct_iso_image("buildings", "workshop", Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_workshop").bind("ws_1x1_carpenter"), true)

	var fa := FileAccess.open(global_marker, FileAccess.WRITE)
	if fa:
		fa.store_string("v4_iso_masterpiece_upgraded")
		fa.close()
	else:
		var fa2 := FileAccess.open(marker_path, FileAccess.WRITE)
		if fa2:
			fa2.store_string("v4_iso_masterpiece_upgraded")
			fa2.close()

## [v5 NPC 전면 개편] 대각선 4방향 2모션 보행 + 공방 장인 8종 + 저잣거리 상인 8종 + 신분·성별·연령 12대 계층 스프라이트 시트 (64x288, 12프레임)
static func upgrade_procedural_pngs_v5_npc() -> void:
	var marker_path: String = BASE_DIR + ".v5_npc_detailed_diversity_done"
	var global_marker: String = ProjectSettings.globalize_path(marker_path)
	if FileAccess.file_exists(global_marker) or FileAccess.file_exists(marker_path):
		return

	var npc_v5_upgrades: Dictionary = {
		# 1. 신분·성별·연령 12대 완전 직교 계층 시트
		"yangban_male_sheet": Vector2i(64, 288),
		"yangban_female_sheet": Vector2i(64, 288),
		"elder_yangban_m_sheet": Vector2i(64, 288),
		"elder_yangban_f_sheet": Vector2i(64, 288),
		"child_yangban_m_sheet": Vector2i(64, 288),
		"child_yangban_f_sheet": Vector2i(64, 288),
		"commoner_male_sheet": Vector2i(64, 288),
		"commoner_female_sheet": Vector2i(64, 288),
		"elder_commoner_m_sheet": Vector2i(64, 288),
		"elder_commoner_f_sheet": Vector2i(64, 288),
		"child_commoner_m_sheet": Vector2i(64, 288),
		"child_commoner_f_sheet": Vector2i(64, 288),
		# 구버전 호환 식별자
		"citizen_male_sheet": Vector2i(64, 288),
		"citizen_female_sheet": Vector2i(64, 288),
		"elder_male_sheet": Vector2i(64, 288),
		"elder_female_sheet": Vector2i(64, 288),
		"child_male_sheet": Vector2i(64, 288),
		"child_female_sheet": Vector2i(64, 288),

		# 2. 고증 공방 장인 8종 시트
		"artisan_sheet": Vector2i(64, 288),
		"artisan_blacksmith_sheet": Vector2i(64, 288),
		"artisan_potter_sheet": Vector2i(64, 288),
		"artisan_carpenter_sheet": Vector2i(64, 288),
		"artisan_weaver_sheet": Vector2i(64, 288),
		"artisan_leather_sheet": Vector2i(64, 288),
		"artisan_mason_sheet": Vector2i(64, 288),
		"artisan_paper_sheet": Vector2i(64, 288),
		"artisan_foundry_sheet": Vector2i(64, 288),

		# 3. 저잣거리 상인 8종 시트 (★ 팔달문 우시장 거간꾼 포함)
		"merchant_sheet": Vector2i(64, 288),
		"merchant_silk_sheet": Vector2i(64, 288),
		"merchant_fish_sheet": Vector2i(64, 288),
		"merchant_herb_sheet": Vector2i(64, 288),
		"merchant_fruit_sheet": Vector2i(64, 288),
		"merchant_book_sheet": Vector2i(64, 288),
		"merchant_brass_sheet": Vector2i(64, 288),
		"merchant_tavern_sheet": Vector2i(64, 288),
		"merchant_cattle_sheet": Vector2i(64, 288),

		# 4. 기타 도시 직업 및 군사 10종
		"builder_sheet": Vector2i(64, 288),
		"brawler_sheet": Vector2i(64, 288),
		"fisherman_sheet": Vector2i(64, 288),
		"soldier_sheet": Vector2i(64, 288),
		"jangyongyeong_sheet": Vector2i(64, 288),
		"patrol_officer_sheet": Vector2i(64, 288),
		"firefighter_sheet": Vector2i(64, 288),
		"cook_sheet": Vector2i(64, 288),
		"drunkard_sheet": Vector2i(64, 288),
		"thief_sheet": Vector2i(64, 288),
	}
	for n_id: String in npc_v5_upgrades.keys():
		_force_dump_texture("npcs", n_id, npc_v5_upgrades[n_id])

	var fa := FileAccess.open(global_marker, FileAccess.WRITE)
	if fa:
		fa.store_string("v5_npc_detailed_diversity_upgraded")
		fa.close()
	else:
		var fa2 := FileAccess.open(marker_path, FileAccess.WRITE)
		if fa2:
			fa2.store_string("v5_npc_detailed_diversity_upgraded")
			fa2.close()

## [v6 ISO Fixed 업그레이드]
## 공방 13종, 가옥 20종의 기단(석축) -> 벽면 -> 지붕 온전한 순서 및 처마 돌출 비율 보정으로 지붕만 뜨는 현상 박멸
static func upgrade_procedural_pngs_v6_iso() -> void:
	var marker_path: String = BASE_DIR + ".v6_iso_fixed_done"
	var global_marker: String = ProjectSettings.globalize_path(marker_path)
	if FileAccess.file_exists(global_marker) or FileAccess.file_exists(marker_path):
		return

	# 기존 잘못 구워진 공방 및 가옥 PNG 캐시 제거
	_texture_cache.clear()

	# 1. 초가집 10종
	for i: int in range(7):
		var id_s: String = "thatch_house_%02d" % (i + 1)
		bake_direct_iso_image("buildings", id_s, Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_thatch_house").bind(i), true)
	for i: int in range(7, 10):
		var id_s: String = "thatch_house_%02d" % (i + 1)
		bake_direct_iso_image("buildings", id_s, Vector2i(96, 88), Callable(ProceduralIsoArtist, "paint_thatch_house").bind(i), true)

	# 2. 기와집 10종
	for i: int in range(4):
		var id_s: String = "tile_house_%02d" % (i + 1)
		bake_direct_iso_image("buildings", id_s, Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_tile_house").bind(i), true)
	for i: int in range(4, 7):
		var id_s: String = "tile_house_%02d" % (i + 1)
		bake_direct_iso_image("buildings", id_s, Vector2i(96, 88), Callable(ProceduralIsoArtist, "paint_tile_house").bind(i), true)
	for i: int in range(7, 9):
		var id_s: String = "tile_house_%02d" % (i + 1)
		bake_direct_iso_image("buildings", id_s, Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_tile_house").bind(i), true)
	bake_direct_iso_image("buildings", "tile_house_10_3x2", Vector2i(160, 136), Callable(ProceduralIsoArtist, "paint_tile_house").bind(9), true)
	bake_direct_iso_image("buildings", "tile_house_10_3x3", Vector2i(192, 160), Callable(ProceduralIsoArtist, "paint_tile_house").bind(10), true)

	# 3. 공방 13종
	var ws_small: Array[String] = ["ws_1x1_carpenter", "ws_1x1_bamboo", "ws_1x1_hanji", "ws_1x1_metalcraft", "ws_1x1_leather"]
	for k: String in ws_small:
		bake_direct_iso_image("buildings", k, Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_workshop").bind(k), true)

	var ws_mid: Array[String] = ["ws_2x1_blacksmith", "ws_2x1_dyeing", "ws_2x1_stonemason", "ws_2x1_tile_kiln", "ws_2x1_shoemaker"]
	for k: String in ws_mid:
		bake_direct_iso_image("buildings", k, Vector2i(96, 88), Callable(ProceduralIsoArtist, "paint_workshop").bind(k), true)

	var ws_large: Array[String] = ["ws_2x2_ceramics", "ws_2x2_lumber_machinery"]
	for k: String in ws_large:
		bake_direct_iso_image("buildings", k, Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_workshop").bind(k), true)

	bake_direct_iso_image("buildings", "ws_3x3_royal_arsenal", Vector2i(192, 160), Callable(ProceduralIsoArtist, "paint_workshop").bind("ws_3x3_royal_arsenal"), true)

	# 4. 기본 호환 에셋
	bake_direct_iso_image("buildings", "thatch_house", Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_thatch_house").bind(0), true)
	bake_direct_iso_image("buildings", "tile_house", Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_tile_house").bind(0), true)
	bake_direct_iso_image("buildings", "workshop", Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_workshop").bind("ws_1x1_carpenter"), true)

	var fa := FileAccess.open(global_marker, FileAccess.WRITE)
	if fa:
		fa.store_string("v6_iso_fixed_upgraded")
		fa.close()
	else:
		var fa2 := FileAccess.open(marker_path, FileAccess.WRITE)
		if fa2:
			fa2.store_string("v6_iso_fixed_upgraded")
			fa2.close()

## [v7 ISO Masterpiece Houses & Seodang 업그레이드]
## 다주칸 기둥(Columns), 툇마루(Toetmaru), 머름, 띠살 창호문, 오픈 대청마루, 입체 기단과 지붕 처마 그림자가 적용된
## 정통 2.5D 한옥 기와집 10종 및 서당/서원을 일괄 재베이킹하여 평면성 및 벽체 실종 버그를 원천 박멸
static func upgrade_procedural_pngs_v7_iso_houses() -> void:
	var marker_path: String = BASE_DIR + ".v7_iso_houses_done"
	var global_marker: String = ProjectSettings.globalize_path(marker_path)
	if FileAccess.file_exists(global_marker) or FileAccess.file_exists(marker_path):
		return

	# 1. 기존 불량/평면 기와집 및 서당 PNG 파일 안전 제거
	var obsolete_files: Array[String] = [
		"buildings/tile_house.png",
		"buildings/seodang.png",
		"buildings/maegok_seowon.png"
	]
	for idx: int in range(10):
		obsolete_files.append("buildings/tile_house_%02d.png" % (idx + 1))
	obsolete_files.append("buildings/tile_house_10_3x2.png")
	obsolete_files.append("buildings/tile_house_10_3x3.png")

	for fname: String in obsolete_files:
		var p: String = BASE_DIR + fname
		var gp: String = ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(gp):
			DirAccess.remove_absolute(gp)
		elif FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
		var ckey: String = fname.trim_suffix(".png")
		_texture_cache.erase(ckey)

	# 2. 기와집 10종 재베이킹
	for i: int in range(4):
		var id_s: String = "tile_house_%02d" % (i + 1)
		bake_direct_iso_image("buildings", id_s, Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_tile_house").bind(i), true)
	for i: int in range(4, 7):
		var id_s: String = "tile_house_%02d" % (i + 1)
		bake_direct_iso_image("buildings", id_s, Vector2i(96, 88), Callable(ProceduralIsoArtist, "paint_tile_house").bind(i), true)
	for i: int in range(7, 9):
		var id_s: String = "tile_house_%02d" % (i + 1)
		bake_direct_iso_image("buildings", id_s, Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_tile_house").bind(i), true)
	bake_direct_iso_image("buildings", "tile_house_10_3x2", Vector2i(160, 136), Callable(ProceduralIsoArtist, "paint_tile_house").bind(9), true)
	bake_direct_iso_image("buildings", "tile_house_10_3x3", Vector2i(192, 160), Callable(ProceduralIsoArtist, "paint_tile_house").bind(10), true)

	# 3. 기본 호환 tile_house (2.5D 아이소메트릭으로 완전 전환)
	bake_direct_iso_image("buildings", "tile_house", Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_tile_house").bind(0), true)

	# 4. 서당 및 매곡서원 재베이킹
	bake_direct_iso_image("buildings", "seodang", Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_special_facility").bind("seodang"), true)
	bake_direct_iso_image("buildings", "maegok_seowon", Vector2i(192, 160), Callable(ProceduralIsoArtist, "paint_special_facility").bind("maegok_seowon"), true)

	var fa := FileAccess.open(global_marker, FileAccess.WRITE)
	if fa:
		fa.store_string("v7_iso_houses_upgraded")
		fa.close()
	else:
		var fa2 := FileAccess.open(marker_path, FileAccess.WRITE)
		if fa2:
			fa2.store_string("v7_iso_houses_upgraded")
			fa2.close()

## [v8 평면 건물 에셋 영구 박멸 및 2.5D 아이소메트릭 전면 일원화]
## 과거 2D 평면 벽체/정면창호/수평기단으로 덤프되어 남아있던 thatch_house_08~10, thatch_house,
## tile_house, market_shop, workshop, haenggung, seojangdae, yeonmudae, yusubu 등 평면 PNG를
## 디스크 상에서 전수 강제 삭제하고, ProceduralIsoArtist의 정통 2.5D 아이소메트릭 입체 도트로 100% 완전 재베이킹
static func upgrade_procedural_pngs_v8_purge_flat_houses() -> void:
	var marker_path: String = BASE_DIR + ".v8_purge_flat_houses_done"
	var global_marker: String = ProjectSettings.globalize_path(marker_path)
	if FileAccess.file_exists(global_marker) or FileAccess.file_exists(marker_path):
		return

	# 1. 디스크 상의 모든 레거시 평면 및 불량 건물 PNG 전수 안전 제거
	var purge_targets: Array[String] = [
		"buildings/thatch_house.png",
		"buildings/tile_house.png",
		"buildings/market_shop.png",
		"buildings/workshop.png",
		"buildings/haenggung.png",
		"buildings/seojangdae.png",
		"buildings/yeonmudae.png",
		"buildings/yusubu.png",
		"buildings/seodang.png",
		"buildings/maegok_seowon.png",
		"buildings/well.png",
		"buildings/women_play_yard.png",
		"buildings/children_play_yard.png"
	]
	for idx: int in range(10):
		purge_targets.append("buildings/thatch_house_%02d.png" % (idx + 1))
		purge_targets.append("buildings/tile_house_%02d.png" % (idx + 1))
	purge_targets.append("buildings/tile_house_10_3x2.png")
	purge_targets.append("buildings/tile_house_10_3x3.png")

	for idx: int in range(20):
		purge_targets.append("buildings/market_shop_%02d.png" % (idx + 1))

	var all_ws: Array[String] = [
		"ws_1x1_carpenter", "ws_1x1_bamboo", "ws_1x1_hanji", "ws_1x1_metalcraft", "ws_1x1_leather",
		"ws_2x1_blacksmith", "ws_2x1_dyeing", "ws_2x1_stonemason", "ws_2x1_tile_kiln", "ws_2x1_shoemaker",
		"ws_2x2_ceramics", "ws_2x2_lumber_machinery", "ws_3x3_royal_arsenal"
	]
	for w_key: String in all_ws:
		purge_targets.append("buildings/%s.png" % w_key)

	for fname: String in purge_targets:
		var p: String = BASE_DIR + fname
		var gp: String = ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(gp):
			DirAccess.remove_absolute(gp)
		elif FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
		var ckey: String = fname.trim_suffix(".png")
		_texture_cache.erase(ckey)

	_texture_cache.clear()

	# 2. 초가집 10종 2.5D 재베이킹 (01~07: 1x1, 08~10: 2x1 합필 부농 초가)
	for i: int in range(7):
		var id_s: String = "thatch_house_%02d" % (i + 1)
		bake_direct_iso_image("buildings", id_s, Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_thatch_house").bind(i), true)
	for i: int in range(7, 10):
		var id_s: String = "thatch_house_%02d" % (i + 1)
		bake_direct_iso_image("buildings", id_s, Vector2i(96, 88), Callable(ProceduralIsoArtist, "paint_thatch_house").bind(i), true)
	bake_direct_iso_image("buildings", "thatch_house", Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_thatch_house").bind(0), true)

	# 3. 기와집 10종 2.5D 재베이킹
	for i: int in range(4):
		var id_s: String = "tile_house_%02d" % (i + 1)
		bake_direct_iso_image("buildings", id_s, Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_tile_house").bind(i), true)
	for i: int in range(4, 7):
		var id_s: String = "tile_house_%02d" % (i + 1)
		bake_direct_iso_image("buildings", id_s, Vector2i(96, 88), Callable(ProceduralIsoArtist, "paint_tile_house").bind(i), true)
	for i: int in range(7, 9):
		var id_s: String = "tile_house_%02d" % (i + 1)
		bake_direct_iso_image("buildings", id_s, Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_tile_house").bind(i), true)
	bake_direct_iso_image("buildings", "tile_house_10_3x2", Vector2i(160, 136), Callable(ProceduralIsoArtist, "paint_tile_house").bind(9), true)
	bake_direct_iso_image("buildings", "tile_house_10_3x3", Vector2i(192, 160), Callable(ProceduralIsoArtist, "paint_tile_house").bind(10), true)
	bake_direct_iso_image("buildings", "tile_house", Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_tile_house").bind(0), true)

	# 4. 상점 20종 2.5D 재베이킹
	for i: int in range(20):
		var id_s: String = "market_shop_%02d" % (i + 1)
		bake_direct_iso_image("buildings", id_s, Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_market_shop").bind(i), true)
	bake_direct_iso_image("buildings", "market_shop", Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_market_shop").bind(0), true)

	# 5. 공방 13종 2.5D 재베이킹
	var ws_small: Array[String] = ["ws_1x1_carpenter", "ws_1x1_bamboo", "ws_1x1_hanji", "ws_1x1_metalcraft", "ws_1x1_leather"]
	for k: String in ws_small:
		bake_direct_iso_image("buildings", k, Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_workshop").bind(k), true)

	var ws_mid: Array[String] = ["ws_2x1_blacksmith", "ws_2x1_dyeing", "ws_2x1_stonemason", "ws_2x1_tile_kiln", "ws_2x1_shoemaker"]
	for k: String in ws_mid:
		bake_direct_iso_image("buildings", k, Vector2i(96, 88), Callable(ProceduralIsoArtist, "paint_workshop").bind(k), true)

	var ws_large: Array[String] = ["ws_2x2_ceramics", "ws_2x2_lumber_machinery"]
	for k: String in ws_large:
		bake_direct_iso_image("buildings", k, Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_workshop").bind(k), true)

	bake_direct_iso_image("buildings", "ws_3x3_royal_arsenal", Vector2i(192, 160), Callable(ProceduralIsoArtist, "paint_workshop").bind("ws_3x3_royal_arsenal"), true)
	bake_direct_iso_image("buildings", "workshop", Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_workshop").bind("ws_1x1_carpenter"), true)

	# 6. 특수 공동체 시설 5종 2.5D 재베이킹
	bake_direct_iso_image("buildings", "seodang", Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_special_facility").bind("seodang"), true)
	bake_direct_iso_image("buildings", "maegok_seowon", Vector2i(192, 160), Callable(ProceduralIsoArtist, "paint_special_facility").bind("maegok_seowon"), true)
	bake_direct_iso_image("buildings", "women_play_yard", Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_special_facility").bind("women_play_yard"), true)
	bake_direct_iso_image("buildings", "children_play_yard", Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_special_facility").bind("children_play_yard"), true)
	bake_direct_iso_image("buildings", "well", Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_special_facility").bind("well"), true)

	# 7. 핵심 랜드마크 4종 2.5D 재베이킹
	bake_direct_iso_image("buildings", "haenggung", Vector2i(448, 320), Callable(ProceduralIsoArtist, "paint_landmark").bind("haenggung"), true)
	bake_direct_iso_image("buildings", "seojangdae", Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_landmark").bind("seojangdae"), true)
	bake_direct_iso_image("buildings", "yeonmudae", Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_landmark").bind("yeonmudae"), true)
	bake_direct_iso_image("buildings", "yusubu", Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_landmark").bind("yusubu"), true)

	var fa := FileAccess.open(global_marker, FileAccess.WRITE)
	if fa:
		fa.store_string("v8_purge_flat_houses_upgraded")
		fa.close()
	else:
		var fa2 := FileAccess.open(marker_path, FileAccess.WRITE)
		if fa2:
			fa2.store_string("v8_purge_flat_houses_upgraded")
			fa2.close()

## [v9 48x48 조선시대 45도 아이소메트릭 네임드 26인 & 일반 백성 & 세시풍속 5종 전면 베이킹]
static func upgrade_procedural_pngs_v8_joseon_48x48_named26() -> void:
	var marker_path: String = BASE_DIR + ".v9_joseon_48x48_custom_npcs_outline_done"
	var global_marker: String = ProjectSettings.globalize_path(marker_path)
	if FileAccess.file_exists(global_marker) or FileAccess.file_exists(marker_path):
		return

	print("[PixelArtist] 45도 아이소메트릭 고품질 도트 캐릭터(세시풍속 5종 포함) 전면 재베이킹 시작...")

	# 1. 네임드 26인 전원 베이킹 (96x192 45도 4방향 시트 및 48x48 정면 단일 프레임)
	for nid: String in CharacterPixelArtist.NAMED_PRESETS.keys():
		var spec: Dictionary = CharacterPixelArtist.NAMED_PRESETS[nid]
		# 45도 4방향 x 2프레임 = 96x192 시트
		var sheet_img: Image = CharacterPixelArtist.create_full_isometric_sheet(spec)
		save_direct_image("npcs/named", nid, sheet_img)
		# 48x48 45도 얼짱 각도 단일 프레임 (UI 초상화 및 프리뷰용)
		var front_img: Image = CharacterPixelArtist.render_isometric_frame(spec, JoseonCharDef.IsoDir.DOWN_LEFT, 0)
		save_direct_image("npcs/named", nid + "_front", front_img)

	# 1-1. 네임드 별칭(Alias) 파일 매핑 저장
	for alias_k: String in NAMED_ID_ALIASES.keys():
		var target_nid: String = NAMED_ID_ALIASES[alias_k]
		if CharacterPixelArtist.NAMED_PRESETS.has(target_nid):
			var spec: Dictionary = CharacterPixelArtist.NAMED_PRESETS[target_nid]
			var sheet_img: Image = CharacterPixelArtist.create_full_isometric_sheet(spec)
			save_direct_image("npcs/named", alias_k, sheet_img)
			var front_img: Image = CharacterPixelArtist.render_isometric_frame(spec, JoseonCharDef.IsoDir.DOWN_LEFT, 0)
			save_direct_image("npcs/named", alias_k + "_front", front_img)

	# 2. 일반 백성 및 세시풍속 20종 베이킹
	for gid: String in CharacterPixelArtist.GENERIC_PRESETS.keys():
		var gspec: Dictionary = CharacterPixelArtist.GENERIC_PRESETS[gid]
		var g_sheet: Image = CharacterPixelArtist.create_full_isometric_sheet(gspec)
		save_direct_image("npcs", gid, g_sheet)
		var g_front: Image = CharacterPixelArtist.render_isometric_frame(gspec, JoseonCharDef.IsoDir.DOWN_LEFT, 0)
		save_direct_image("npcs", gid + "_front", g_front)

	# 3. 을묘원행 행렬 5종 베이킹
	for pid: String in CharacterPixelArtist.PARADE_PRESETS.keys():
		var pspec: Dictionary = CharacterPixelArtist.PARADE_PRESETS[pid]
		var p_sheet: Image = CharacterPixelArtist.create_full_isometric_sheet(pspec)
		save_direct_image("npcs", pid, p_sheet)
		var p_front: Image = CharacterPixelArtist.render_isometric_frame(pspec, JoseonCharDef.IsoDir.DOWN_LEFT, 0)
		save_direct_image("npcs", pid + "_front", p_front)

	# 4. 레거시 식별자 호환성 매핑 베이킹
	var legacy_maps: Dictionary = {
		"citizen_male_sheet": CharacterPixelArtist.GENERIC_PRESETS["npc_farmer"],
		"citizen_female_sheet": CharacterPixelArtist.GENERIC_PRESETS["npc_peasant_woman"],
		"patrol_officer_sheet": CharacterPixelArtist.GENERIC_PRESETS["npc_patrol"],
		"soldier_sheet": CharacterPixelArtist.GENERIC_PRESETS["npc_soldier"],
		"jangyongyeong_sheet": CharacterPixelArtist.GENERIC_PRESETS["npc_soldier"],
		"merchant_sheet": CharacterPixelArtist.GENERIC_PRESETS["npc_bobusang"],
		"brawler_sheet": CharacterPixelArtist.GENERIC_PRESETS["npc_ssireum"],
		"fisherman_sheet": CharacterPixelArtist.GENERIC_PRESETS["npc_fisherman"],
		"thief_sheet": CharacterPixelArtist.GENERIC_PRESETS["npc_thief"],
		"yangban_male_sheet": CharacterPixelArtist.GENERIC_PRESETS["npc_yangban_scholar"],
		"yangban_female_sheet": CharacterPixelArtist.GENERIC_PRESETS["npc_yangban_lady"]
	}
	for lk: String in legacy_maps.keys():
		var lspec: Dictionary = legacy_maps[lk]
		var l_sheet: Image = CharacterPixelArtist.create_full_isometric_sheet(lspec)
		save_direct_image("npcs", lk, l_sheet)

	var fa := FileAccess.open(global_marker, FileAccess.WRITE)
	if fa:
		fa.store_string("v9_joseon_48x48_custom_npcs_outline_done")
		fa.close()
	else:
		var fa2 := FileAccess.open(marker_path, FileAccess.WRITE)
		if fa2:
			fa2.store_string("v9_joseon_48x48_custom_npcs_outline_done")
			fa2.close()

## [v9 만석거/축만제 및 상점/공방 순수 PNG 단일 드로우콜 전면 연동]
## 다른 건물 파편 침범 및 체커보드 아티팩트를 원천 박멸하고,
## 하단 마름모 꼭짓점이 100% 온전하게 보존되는 순수 2.5D 아이소메트릭 독립 래스터라이저로 전수 재베이킹
## PORT-TRACE [새 그림 보호]: 예전엔 게임을 켤 때마다 아래 상점·공방·놀이마당 PNG를 코드 그림으로 강제로 다시 구워
## art_ingest로 넣은 새 그림을 덮어썼다. 이제 파일이 없을 때만 굽고, 있으면 그 파일을 읽어 쓴다.
static func _bake_iso_if_missing(category: String, asset_id: String, canvas_size: Vector2i, painter_callable: Callable, _force: bool = true) -> Texture2D:
	var file_path: String = "%s%s/%s.png" % [BASE_DIR, category, asset_id]
	var global_path: String = ProjectSettings.globalize_path(file_path)
	var actual: String = global_path if FileAccess.file_exists(global_path) else file_path
	if FileAccess.file_exists(actual):
		var img := Image.load_from_file(actual)
		if img != null and not img.is_empty():
			var tex := ImageTexture.create_from_image(img)
			_texture_cache["%s/%s" % [category, asset_id]] = tex
			return tex
	return bake_direct_iso_image(category, asset_id, canvas_size, painter_callable, true)

static func upgrade_procedural_pngs_v9_pure_png_lakes_and_shops() -> void:
	# 1. 만석거 및 축만제 6x6 고화질 PNG (448x320) 캐시 워밍업
	for lake_id: String in ["manseokgeo", "chukmanje"]:
		var fpath: String = "%sbuildings/%s.png" % [BASE_DIR, lake_id]
		var gpath: String = ProjectSettings.globalize_path(fpath)
		var actual_path: String = gpath if FileAccess.file_exists(gpath) else fpath
		if FileAccess.file_exists(actual_path):
			var img := Image.load_from_file(actual_path)
			if img != null and not img.is_empty():
				var tex := ImageTexture.create_from_image(img)
				_texture_cache["buildings/%s" % lake_id] = tex
				for sfx: String in ["_spring", "_summer", "_autumn", "_winter"]:
					# PORT-TRACE [호수 겨울 빙판]: 계절판 그림(<이름>_winter.png 등)이 있으면 그 계절은 기본 그림으로 덮어 두지 않는다
					if ResourceLoader.exists("%sbuildings/%s%s.png" % [BASE_DIR, lake_id, sfx]):
						continue
					_texture_cache["buildings/%s%s" % [lake_id, sfx]] = tex

	# 2. 저잣거리 상점 20종 독립 2.5D 전용 베이킹 (외곽 침범/하단 잘림 원천 차단)
	for s_idx: int in range(20):
		var shop_id: String = "market_shop_%02d" % (s_idx + 1)
		_bake_iso_if_missing("buildings", shop_id, Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_market_shop").bind(s_idx), true)
	_bake_iso_if_missing("buildings", "market_shop", Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_market_shop").bind(0), true)

	# 3. 공방 13종 독립 2.5D 전용 베이킹
	var ws_small: Array[String] = ["ws_1x1_carpenter", "ws_1x1_bamboo", "ws_1x1_hanji", "ws_1x1_metalcraft", "ws_1x1_leather"]
	for k: String in ws_small:
		_bake_iso_if_missing("buildings", k, Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_workshop").bind(k), true)

	var ws_mid: Array[String] = ["ws_2x1_blacksmith", "ws_2x1_dyeing", "ws_2x1_stonemason", "ws_2x1_tile_kiln", "ws_2x1_shoemaker"]
	for k: String in ws_mid:
		_bake_iso_if_missing("buildings", k, Vector2i(96, 88), Callable(ProceduralIsoArtist, "paint_workshop").bind(k), true)

	var ws_large: Array[String] = ["ws_2x2_ceramics", "ws_2x2_lumber_machinery"]
	for k: String in ws_large:
		_bake_iso_if_missing("buildings", k, Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_workshop").bind(k), true)

	_bake_iso_if_missing("buildings", "ws_3x3_royal_arsenal", Vector2i(192, 160), Callable(ProceduralIsoArtist, "paint_workshop").bind("ws_3x3_royal_arsenal"), true)
	_bake_iso_if_missing("buildings", "workshop", Vector2i(64, 72), Callable(ProceduralIsoArtist, "paint_workshop").bind("ws_1x1_carpenter"), true)

	# 4. 놀이마당 2종 (바닥 없는 100% 투명 배경 소품 에셋)
	_bake_iso_if_missing("buildings", "women_play_yard", Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_special_facility").bind("women_play_yard"), true)
	_bake_iso_if_missing("buildings", "children_play_yard", Vector2i(128, 112), Callable(ProceduralIsoArtist, "paint_special_facility").bind("children_play_yard"), true)

## [직접 생성된 Image를 PNG 파일로 저장하고 캐싱하는 헬퍼]
static func save_direct_image(category: String, asset_id: String, img: Image) -> Texture2D:
	var cache_key: String = "%s/%s" % [category, asset_id]
	var file_path: String = "%s%s/%s.png" % [BASE_DIR, category, asset_id]
	var global_path: String = ProjectSettings.globalize_path(file_path)

	var pdir: String = global_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(pdir):
		DirAccess.make_dir_recursive_absolute(pdir)
	var s_err: Error = img.save_png(global_path)
	if s_err != OK:
		var _err2: Error = img.save_png(file_path)
	var final_tex := ImageTexture.create_from_image(img)
	_texture_cache[cache_key] = final_tex
	return final_tex

const NAMED_ID_ALIASES: Dictionary = {
	"gu_seonbok": "named_gu_seon_bok",
	"named_gu_seonbok": "named_gu_seon_bok",
	"lee_deokmu": "named_yi_deokmu",
	"named_lee_deokmu": "named_yi_deokmu",
	"shim_hwanji": "named_sim_hwanji",
	"named_shim_hwanji": "named_sim_hwanji",
	"hong_inhan": "named_hwang_inhan",
	"named_hong_inhan": "named_hwang_inhan",
	"kim_myeongsin": "named_yi_gigyeong",
	"named_kim_myeongsin": "named_yi_gigyeong",
	"lee_seonggil": "named_yi_seonggil",
	"named_lee_seonggil": "named_yi_seonggil",
	"kim_bau": "named_kim_bau",
	"jeong_yakyong": "named_jeong_yakyong",
	"chae_jegong": "named_chae_jegong",
	"jo_simtae": "named_jo_simtae",
	"kim_hongdo": "named_kim_hongdo",
	"yu_hanji": "named_yu_hanji",
	"park_jega": "named_park_jega",
	"yu_deukgong": "named_yu_deukgong",
	"seo_yugu": "named_seo_yugu",
	"park_jiwon": "named_park_jiwon",
	"hong_daeyong": "named_hong_daeyong",
	"yi_gahwan": "named_yi_gahwan",
	"jeong_beomjo": "named_jeong_beomjo",
	"kim_jeonghee": "named_kim_jeonghee",
	"kim_josun": "named_kim_josun",
	"hong_gukyeong": "named_hong_gukyeong",
	"baek_dongsu": "named_baek_dongsu",
	"musoe": "named_musoe",
	"kim_pangwan": "named_kim_pangwan",
	"jeongjo": "named_jeongjo",
}

## [네임드 캐릭터 텍스처 조회 헬퍼]
static func get_named_character_texture(named_id: String, front_only: bool = false) -> Texture2D:
	var target_id: String = named_id
	if NAMED_ID_ALIASES.has(named_id):
		target_id = NAMED_ID_ALIASES[named_id]
	elif NAMED_ID_ALIASES.has(named_id.trim_prefix("named_")):
		target_id = NAMED_ID_ALIASES[named_id.trim_prefix("named_")]
	else:
		target_id = "named_" + named_id.trim_prefix("named_")

	var asset_key: String = target_id + ("_front" if front_only else "")
	var cache_key: String = "npcs/named/" + asset_key
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key]
	var file_path: String = "%snpcs/named/%s.png" % [BASE_DIR, asset_key]
	var global_path: String = ProjectSettings.globalize_path(file_path)
	if FileAccess.file_exists(global_path) or FileAccess.file_exists(file_path):
		var img := Image.new()
		var err := img.load(global_path if FileAccess.file_exists(global_path) else file_path)
		if err == OK:
			var tex := ImageTexture.create_from_image(img)
			_texture_cache[cache_key] = tex
			return tex
	# 폴백: 실시간 베이킹
	if CharacterPixelArtist.NAMED_PRESETS.has(target_id):
		var spec: Dictionary = CharacterPixelArtist.NAMED_PRESETS[target_id]
		if front_only:
			var front_img: Image = CharacterPixelArtist.render_isometric_frame(spec, JoseonCharDef.IsoDir.DOWN_LEFT, 0)
			return save_direct_image("npcs/named", asset_key, front_img)
		else:
			var sheet_img: Image = CharacterPixelArtist.create_full_isometric_sheet(spec)
			return save_direct_image("npcs/named", asset_key, sheet_img)
	return null

## [일반/치안/군사/행렬 NPC 텍스처 조회 헬퍼]
static func get_npc_texture(npc_id: String, front_only: bool = false) -> Texture2D:
	var asset_key: String = npc_id + ("_front" if front_only else "")
	var cache_key: String = "npcs/" + asset_key
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key]
	var file_path: String = "%snpcs/%s.png" % [BASE_DIR, asset_key]
	var global_path: String = ProjectSettings.globalize_path(file_path)
	if FileAccess.file_exists(global_path) or FileAccess.file_exists(file_path):
		var img := Image.new()
		var err := img.load(global_path if FileAccess.file_exists(global_path) else file_path)
		if err == OK:
			var tex := ImageTexture.create_from_image(img)
			_texture_cache[cache_key] = tex
			return tex
	# 프리셋에서 직접 조회
	if CharacterPixelArtist.GENERIC_PRESETS.has(npc_id):
		var gspec: Dictionary = CharacterPixelArtist.GENERIC_PRESETS[npc_id]
		if front_only:
			var front_img: Image = CharacterPixelArtist.render_isometric_frame(gspec, JoseonCharDef.IsoDir.DOWN_LEFT, 0)
			return save_direct_image("npcs", asset_key, front_img)
		else:
			var sheet_img: Image = CharacterPixelArtist.create_full_isometric_sheet(gspec)
			return save_direct_image("npcs", asset_key, sheet_img)
	elif CharacterPixelArtist.PARADE_PRESETS.has(npc_id):
		var pspec: Dictionary = CharacterPixelArtist.PARADE_PRESETS[npc_id]
		if front_only:
			var front_img: Image = CharacterPixelArtist.render_isometric_frame(pspec, JoseonCharDef.IsoDir.DOWN_LEFT, 0)
			return save_direct_image("npcs", asset_key, front_img)
		else:
			var sheet_img: Image = CharacterPixelArtist.create_full_isometric_sheet(pspec)
			return save_direct_image("npcs", asset_key, sheet_img)
	return null

## [2.5D 아이소메트릭 순수 픽셀 도트 래스터라이저 직행 베이커]
## 뷰포트나 디스플레이 서버 의존성 없이 Image에 직접 그려서 PNG로 즉시 저장
static func bake_direct_iso_image(category: String, asset_id: String, canvas_size: Vector2i, painter_callable: Callable, force_overwrite: bool = true) -> Texture2D:
	var cache_key: String = "%s/%s" % [category, asset_id]
	var file_path: String = "%s%s/%s.png" % [BASE_DIR, category, asset_id]
	var global_path: String = ProjectSettings.globalize_path(file_path)

	if not force_overwrite and _texture_cache.has(cache_key):
		return _texture_cache[cache_key]

	var img := Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	painter_callable.call(img, Vector2(canvas_size))

	var pdir: String = global_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(pdir):
		DirAccess.make_dir_recursive_absolute(pdir)
	var s_err: Error = img.save_png(global_path)
	if s_err != OK:
		var _err2: Error = img.save_png(file_path)
	var final_tex := ImageTexture.create_from_image(img)
	_texture_cache[cache_key] = final_tex
	return final_tex

## [원본 CanvasItem 드로잉 -> 투명 PNG 무손실 변환기]
## 원본 _draw() 코드를 투명 SubViewport에 정확히 1회 그려서 캡처한 뒤 .png 파일로 저장
static func bake_canvas_draw_to_png(category: String, asset_id: String, canvas_size: Vector2i, original_draw_callable: Callable, force_overwrite: bool = false) -> Texture2D:
	var cache_key: String = "%s/%s" % [category, asset_id]
	var file_path: String = "%s%s/%s.png" % [BASE_DIR, category, asset_id]
	var global_path: String = ProjectSettings.globalize_path(file_path)

	# 강제 복구 모드가 아니고 정상 PNG가 이미 있으면 즉시 로드
	if not force_overwrite and _texture_cache.has(cache_key):
		return _texture_cache[cache_key]
	if not force_overwrite and (FileAccess.file_exists(global_path) or FileAccess.file_exists(file_path)):
		var actual_path: String = global_path if FileAccess.file_exists(global_path) else file_path
		var img := Image.load_from_file(actual_path)
		if img != null and not img.is_empty():
			var tex := ImageTexture.create_from_image(img)
			_texture_cache[cache_key] = tex
			return tex

	# 원본 CanvasItem._draw() 로직을 투명 SubViewport에 정확히 1회 그려서 캡처
	var vp := SubViewport.new()
	vp.size = canvas_size
	vp.transparent_bg = true
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE

	var drawer := Node2D.new()
	drawer.draw.connect(func():
		original_draw_callable.call(drawer, Vector2(canvas_size))
	)
	vp.add_child(drawer)

	if instance != null and is_instance_valid(instance) and instance.is_inside_tree():
		instance.add_child(vp)
	elif Engine.get_main_loop() is SceneTree and (Engine.get_main_loop() as SceneTree).root != null:
		(Engine.get_main_loop() as SceneTree).root.add_child(vp)

	# 렌더링 서버가 뷰포트를 그릴 때까지 대기 후 Image 추출
	RenderingServer.force_draw(false)
	var captured_img: Image = null
	if DisplayServer.get_name() != "headless":
		var vp_tex := vp.get_texture()
		if vp_tex != null:
			captured_img = vp_tex.get_image()
	vp.queue_free()

	# 헤드리스 모드이거나 뷰포트 캡처 부재 시 정교한 도트 아트로 폴백
	if captured_img == null or captured_img.is_empty():
		captured_img = Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
		captured_img.fill(Color(0, 0, 0, 0))
		if asset_id == "well":
			_paint_well_dot_art(captured_img, canvas_size.x, canvas_size.y)
		else:
			_paint_iso_fallback_image(captured_img, category, asset_id, canvas_size.x, canvas_size.y)

	if captured_img != null and not captured_img.is_empty():
		var pdir: String = global_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(pdir):
			DirAccess.make_dir_recursive_absolute(pdir)
		var s_err: Error = captured_img.save_png(global_path)
		if s_err != OK:
			var _err2: Error = captured_img.save_png(file_path)
		var final_tex := ImageTexture.create_from_image(captured_img)
		_texture_cache[cache_key] = final_tex
		return final_tex

	return null

## [우물 원본 디자인 2D CanvasItem 드로잉]
## 팔각/원형 화강암 돌담 테두리, 맑은 물면, 나무 기둥 2개, 도르래/두레박, 맞배 기와 지붕
static func draw_well_original(ci: CanvasItem, size: Vector2) -> void:
	var wc := Vector2(size.x * 0.5, size.y * 0.68)

	# 1. 우물 바닥 그림자 (은은한 타원)
	ci.draw_circle(wc + Vector2(1.0, 1.0), 9.0, Color(0.1, 0.1, 0.1, 0.35))

	# 2. 화강암 팔각/원형 돌담 테두리
	ci.draw_circle(wc + Vector2(0, -2.0), 8.5, Color("64748b")) # 외곽 화강암
	ci.draw_circle(wc + Vector2(0, -2.5), 7.8, Color("94a3b8")) # 밝은 석재
	ci.draw_arc(wc + Vector2(0, -2.0), 8.5, 0.0, TAU, 16, Color("334155"), 1.2) # 돌담 음영 윤곽선

	# 돌담 줄눈/블록 마름모 분할선
	for i in range(8):
		var ang: float = float(i) * TAU / 8.0
		var p_inner := wc + Vector2(cos(ang) * 5.2, sin(ang) * 5.2 - 2.5)
		var p_outer := wc + Vector2(cos(ang) * 8.5, sin(ang) * 8.5 - 2.0)
		ci.draw_line(p_inner, p_outer, Color("475569"), 1.0)

	# 3. 우물 안쪽 맑은 물면 (원근 타원 깊이감)
	ci.draw_circle(wc + Vector2(0, -3.2), 5.2, Color("0f172a")) # 깊은 우물 바닥 그림자
	ci.draw_circle(wc + Vector2(0, -3.8), 4.5, Color("0284c7")) # 맑은 수원천 지하수
	ci.draw_circle(wc + Vector2(1.0, -4.2), 2.2, Color("38bdf8", 0.85)) # 물빛 하이라이트

	# 4. 좌우 목재 지지 기둥 2개
	var col_timber := Color("78350f")
	var col_timber_light := Color("b45309")
	var col_timber_dark := Color("451a03")
	# 좌측 기둥
	ci.draw_line(wc + Vector2(-7.5, -2.0), wc + Vector2(-7.5, -18.0), col_timber_dark, 2.2)
	ci.draw_line(wc + Vector2(-7.5, -2.0), wc + Vector2(-7.5, -18.0), col_timber, 1.6)
	ci.draw_line(wc + Vector2(-8.0, -2.0), wc + Vector2(-8.0, -18.0), col_timber_light, 0.8)
	# 우측 기둥
	ci.draw_line(wc + Vector2(7.5, -2.0), wc + Vector2(7.5, -18.0), col_timber_dark, 2.2)
	ci.draw_line(wc + Vector2(7.5, -2.0), wc + Vector2(7.5, -18.0), col_timber, 1.6)
	ci.draw_line(wc + Vector2(7.0, -2.0), wc + Vector2(7.0, -18.0), col_timber_light, 0.8)

	# 가로 대들보/도르래 축
	ci.draw_line(wc + Vector2(-9.0, -18.0), wc + Vector2(9.0, -18.0), col_timber_dark, 2.4)
	ci.draw_line(wc + Vector2(-8.5, -18.0), wc + Vector2(8.5, -18.0), col_timber, 1.8)

	# 5. 도르래 휠, 밧줄 및 두레박 버킷
	# 도르래 바퀴
	ci.draw_circle(wc + Vector2(0.0, -17.5), 2.2, Color("334155"))
	ci.draw_circle(wc + Vector2(0.0, -17.5), 1.4, Color("94a3b8"))
	# 삼베 밧줄
	ci.draw_line(wc + Vector2(1.2, -17.5), wc + Vector2(1.2, -8.5), Color("fde68a"), 0.9)
	# 두레박 나무 버킷
	var bucket_rect := Rect2(wc + Vector2(-1.0, -9.5), Vector2(4.5, 4.0))
	ci.draw_rect(bucket_rect, Color("57300a"))
	ci.draw_rect(Rect2(bucket_rect.position, Vector2(bucket_rect.size.x, 1.0)), Color("92400e"))
	ci.draw_line(bucket_rect.position + Vector2(0.0, 2.0), bucket_rect.position + Vector2(bucket_rect.size.x, 2.0), Color("d97706"), 0.6)

	# 6. 상부 맞배형 작은 기와 지붕 (처마 곡선 + 수막새)
	var roof_pts := PackedVector2Array([
		wc + Vector2(-12.5, -17.0),
		wc + Vector2(0.0, -24.5),
		wc + Vector2(12.5, -17.0),
		wc + Vector2(11.0, -15.5),
		wc + Vector2(0.0, -22.5),
		wc + Vector2(-11.0, -15.5)
	])
	ci.draw_colored_polygon(roof_pts, Color("1e293b")) # 먹기와 본체
	# 기와 골 음영
	ci.draw_line(wc + Vector2(-6.0, -21.0), wc + Vector2(-7.5, -16.5), Color("475569"), 1.2)
	ci.draw_line(wc + Vector2(0.0, -24.0), wc + Vector2(0.0, -18.0), Color("94a3b8"), 1.0)
	ci.draw_line(wc + Vector2(6.0, -21.0), wc + Vector2(7.5, -16.5), Color("475569"), 1.2)
	# 용마루 / 수막새
	ci.draw_line(wc + Vector2(-13.0, -16.8), wc + Vector2(13.0, -16.8), Color("334155"), 1.4)
	ci.draw_circle(wc + Vector2(0.0, -24.5), 1.5, Color("e2e8f0"))

## [헤드리스/더미 렌더러 안전용 정밀 우물 도트 아트 래스터라이저]
static func _paint_well_dot_art(img: Image, w: int, h: int) -> void:
	var mid_x: int = int(float(w) * 0.5)
	var base_y: int = int(float(h) * 0.68)

	var col_shadow := Color(0.1, 0.1, 0.1, 0.35)
	var col_stone_dark := Color("475569")
	var col_stone_mid := Color("64748b")
	var col_stone_light := Color("94a3b8")
	var col_water_deep := Color("0f172a")
	var col_water_mid := Color("0284c7")
	var col_water_hi := Color("38bdf8")
	var col_wood := Color("78350f")
	var col_wood_light := Color("b45309")
	var col_wood_dark := Color("451a03")
	var col_rope := Color("fde68a")
	var col_bucket := Color("57300a")
	var col_giwa := Color("1e293b")
	var col_giwa_hi := Color("475569")
	var col_ridge := Color("94a3b8")

	# 1. 우물 바닥 그림자 (타원)
	for y: int in range(base_y - 3, base_y + 4):
		for x: int in range(mid_x - 11, mid_x + 13):
			var dx: float = float(x - mid_x) / 11.0
			var dy: float = float(y - base_y) / 3.5
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, col_shadow)

	# 2. 화강암 돌담 테두리 및 맑은 물면
	for y: int in range(base_y - 8, base_y + 3):
		for x: int in range(mid_x - 10, mid_x + 11):
			var dx: float = float(x - mid_x) / 9.5
			var dy: float = float(y - (base_y - 2)) / 5.2
			var dist_sq: float = dx * dx + dy * dy
			if dist_sq <= 1.0:
				if dist_sq > 0.52:
					# 돌담 테두리
					var seed_stone: int = (x * 7 + y * 13) % 4
					if seed_stone == 0:
						img.set_pixel(x, y, col_stone_light)
					elif seed_stone == 1:
						img.set_pixel(x, y, col_stone_mid)
					else:
						img.set_pixel(x, y, col_stone_dark)
				elif dist_sq > 0.28:
					# 우물 내부 깊은 음영
					img.set_pixel(x, y, col_water_deep)
				else:
					# 맑은 수원천 지하수
					if x >= mid_x - 1 and y <= base_y - 3:
						img.set_pixel(x, y, col_water_hi)
					else:
						img.set_pixel(x, y, col_water_mid)

	# 3. 좌우 목재 기둥
	for y: int in range(base_y - 18, base_y - 2):
		# 좌측 기둥
		img.set_pixel(mid_x - 8, y, col_wood_dark)
		img.set_pixel(mid_x - 7, y, col_wood)
		# 우측 기둥
		img.set_pixel(mid_x + 7, y, col_wood)
		img.set_pixel(mid_x + 8, y, col_wood_dark)

	# 가로 대들보
	for x: int in range(mid_x - 9, mid_x + 10):
		img.set_pixel(x, base_y - 18, col_wood_light)
		img.set_pixel(x, base_y - 17, col_wood_dark)

	# 4. 도르래, 삼베 밧줄, 두레박 버킷
	img.set_pixel(mid_x, base_y - 16, col_stone_dark)
	img.set_pixel(mid_x, base_y - 17, col_stone_light)
	for y: int in range(base_y - 15, base_y - 8):
		img.set_pixel(mid_x + 1, y, col_rope)

	for y: int in range(base_y - 9, base_y - 5):
		for x: int in range(mid_x - 1, mid_x + 4):
			img.set_pixel(x, y, col_bucket)
	img.set_pixel(mid_x + 1, base_y - 10, col_wood_light)

	# 5. 상부 맞배형 기와 지붕
	for y: int in range(base_y - 25, base_y - 16):
		var dy_roof: float = float(base_y - 17 - y) / 8.0
		var half_w: int = int(14.0 * (1.0 - dy_roof * 0.45))
		for x: int in range(mid_x - half_w, mid_x + half_w + 1):
			if (x - mid_x) % 3 == 0:
				img.set_pixel(x, y, col_giwa_hi)
			else:
				img.set_pixel(x, y, col_giwa)

	# 용마루
	for x: int in range(mid_x - 7, mid_x + 8):
		img.set_pixel(x, base_y - 25, col_ridge)

## [헤드리스/뷰포트 부재 시 정교한 2.5D 아이소메트릭 도트 폴백]
static func _paint_iso_fallback_image(img: Image, _category: String, asset_id: String, w: int, h: int) -> void:
	var sz := Vector2(float(w), float(h))
	if asset_id.begins_with("thatch"):
		var idx: int = 0
		if asset_id.contains("_"):
			idx = int(asset_id.split("_")[-1]) - 1
		ProceduralIsoArtist.paint_thatch_house(img, sz, maxi(0, idx))
	elif asset_id.begins_with("tile"):
		var idx: int = 0
		if asset_id == "tile_house_10_3x2":
			idx = 9
		elif asset_id == "tile_house_10_3x3":
			idx = 10
		elif asset_id.contains("_"):
			idx = int(asset_id.split("_")[-1]) - 1
		ProceduralIsoArtist.paint_tile_house(img, sz, maxi(0, idx))
	elif asset_id.begins_with("market_shop"):
		var idx: int = 0
		if asset_id.contains("_"):
			idx = int(asset_id.split("_")[-1]) - 1
		ProceduralIsoArtist.paint_market_shop(img, sz, maxi(0, idx))
	elif asset_id.begins_with("ws_") or asset_id == "workshop":
		ProceduralIsoArtist.paint_workshop(img, sz, asset_id)
	elif asset_id == "well":
		ProceduralIsoArtist.paint_well(img, sz)
	elif asset_id in ["seodang", "maegok_seowon", "women_play_yard", "children_play_yard"]:
		ProceduralIsoArtist.paint_special_facility(img, sz, asset_id)
	elif asset_id in ["haenggung", "seojangdae", "yeonmudae", "yusubu"]:
		ProceduralIsoArtist.paint_landmark(img, sz, asset_id)
	else:
		ProceduralIsoArtist.paint_tile_house(img, sz, 0)

static func _force_dump_texture(category: String, asset_id: String, size: Vector2i) -> void:
	var file_path: String = "%s%s/%s.png" % [BASE_DIR, category, asset_id]
	var global_path: String = ProjectSettings.globalize_path(file_path)
	var generated_img: Image = _create_standard_art_image(category, asset_id, size)
	var pdir: String = global_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(pdir):
		DirAccess.make_dir_recursive_absolute(pdir)
	var save_err: Error = generated_img.save_png(global_path)
	if save_err != OK:
		var _err2: Error = generated_img.save_png(file_path)
	var tex: ImageTexture = ImageTexture.create_from_image(generated_img)
	_texture_cache["%s/%s" % [category, asset_id]] = tex

## 외부 PNG가 있으면 로드하고, 없으면 fallback_draw_callable(size: Vector2i) -> Image로 이미지를 만들어 PNG로 저장 후 반환
static func get_or_create_texture(
	category: String,
	asset_id: String,
	size: Vector2i,
	fallback_draw_callable: Callable = Callable()
) -> Texture2D:
	var cache_key: String = "%s/%s" % [category, asset_id]
	if _texture_cache.has(cache_key):
		var cached_tex: Texture2D = _texture_cache[cache_key] as Texture2D
		if cached_tex != null:
			return cached_tex

	var file_path: String = "%s%s/%s.png" % [BASE_DIR, category, asset_id]
	var global_path: String = ProjectSettings.globalize_path(file_path)

	# 1. 사용자가 넣은 PNG 파일이나 이미 추출된 PNG가 존재하면 즉시 로드
	if ResourceLoader.exists(file_path):
		var loaded_tex: Texture2D = load(file_path) as Texture2D
		if loaded_tex != null:
			if size.x > 0 and size.y > 0 and (loaded_tex.get_width() != size.x or loaded_tex.get_height() != size.y):
				_force_dump_texture(category, asset_id, size)
				return _texture_cache[cache_key]
			_texture_cache[cache_key] = loaded_tex
			return loaded_tex
	elif FileAccess.file_exists(global_path) or FileAccess.file_exists(file_path):
		var target_path: String = global_path if FileAccess.file_exists(global_path) else file_path
		var img: Image = Image.load_from_file(target_path)
		if img != null and not img.is_empty():
			if size.x > 0 and size.y > 0 and (img.get_width() != size.x or img.get_height() != size.y):
				_force_dump_texture(category, asset_id, size)
				return _texture_cache[cache_key]
			var file_tex: ImageTexture = ImageTexture.create_from_image(img)
			_texture_cache[cache_key] = file_tex
			return file_tex

	# 2. PNG 파일이 아직 없으면 기본 템플릿 이미지를 생성하고 디스크에 .png로 자동 저장 (사용자 수정용)
	var generated_img: Image = null
	if fallback_draw_callable.is_valid():
		var res_obj: Variant = fallback_draw_callable.call(size)
		if res_obj is Image:
			generated_img = res_obj as Image

	if generated_img == null or generated_img.is_empty():
		generated_img = _create_standard_art_image(category, asset_id, size)

	# 에디터 및 개발/런타임 환경에서 실제 폴더에 PNG 파일로 추출하여 사용자가 바로 고칠 수 있게 함
	var pdir: String = global_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(pdir):
		DirAccess.make_dir_recursive_absolute(pdir)
	var save_err: Error = generated_img.save_png(global_path)
	if save_err != OK:
		var _err2: Error = generated_img.save_png(file_path)

	var tex: ImageTexture = ImageTexture.create_from_image(generated_img)
	_texture_cache[cache_key] = tex
	return tex

## 계절별 PNG 오버라이드 지원 (O(1) 순수 메모리 캐시 및 디스크 I/O 원천 차단)
static func get_seasonal_or_base_texture(
	category: String,
	base_id: String,
	season_suffix: String,
	size: Vector2i,
	fallback_draw_callable: Callable = Callable()
) -> Texture2D:
	var lookup_key: String = "%s/%s%s" % [category, base_id, season_suffix]
	if _texture_cache.has(lookup_key):
		return _texture_cache[lookup_key] as Texture2D

	if season_suffix != "":
		var seasonal_id: String = "%s%s" % [base_id, season_suffix]
		var file_path: String = "%s%s/%s.png" % [BASE_DIR, category, seasonal_id]
		var global_path: String = ProjectSettings.globalize_path(file_path)
		if ResourceLoader.exists(file_path) or FileAccess.file_exists(global_path) or FileAccess.file_exists(file_path):
			var s_tex: Texture2D = get_or_create_texture(category, seasonal_id, size, fallback_draw_callable)
			_texture_cache[lookup_key] = s_tex
			return s_tex

	var base_tex: Texture2D = get_or_create_texture(category, base_id, size, fallback_draw_callable)
	_texture_cache[lookup_key] = base_tex
	return base_tex

## 표준 필수 에셋 사전 검사 및 자동 추출(Dump)
static func preload_and_dump_all_standards() -> void:
	_ensure_directories()
	# 1. 전통 건물 (buildings)
	var std_buildings: Dictionary = {
		"thatch_house": Vector2i(64, 72),
		"tile_house": Vector2i(64, 72),
		"market_shop": Vector2i(64, 72),
		"workshop": Vector2i(64, 72),
		"well": Vector2i(64, 72),
		"seojangdae": Vector2i(128, 112),
		"yeonmudae": Vector2i(128, 112),
		"yusubu": Vector2i(128, 112),
		"haenggung": Vector2i(448, 320),
		"manseokgeo": Vector2i(448, 320),
		"chukmanje": Vector2i(448, 320)
	}
	for b_id: String in std_buildings.keys():
		var b_size: Vector2i = std_buildings[b_id]
		var base_tex: Texture2D = get_or_create_texture("buildings", b_id, b_size)
		for sfx: String in ["", "_spring", "_summer", "_autumn", "_winter"]:
			var lookup_k: String = "buildings/%s%s" % [b_id, sfx]
			if not _texture_cache.has(lookup_k) and (sfx == "" or not ResourceLoader.exists("%sbuildings/%s%s.png" % [BASE_DIR, b_id, sfx])):
				_texture_cache[lookup_k] = base_tex

	# 2. 근대 건물 (buildings_modern)
	var std_modern: Dictionary = {
		"stone_building": Vector2i(64, 64),
		"modern_highrise": Vector2i(128, 128),
		"factory": Vector2i(128, 128),
		"villa": Vector2i(64, 64),
		"haenggung_modern": Vector2i(448, 448)
	}
	for m_id: String in std_modern.keys():
		var m_size: Vector2i = std_modern[m_id]
		var m_tex: Texture2D = get_or_create_texture("buildings_modern", m_id, m_size)
		for sfx: String in ["", "_spring", "_summer", "_autumn", "_winter"]:
			var lookup_k: String = "buildings_modern/%s%s" % [m_id, sfx]
			if not _texture_cache.has(lookup_k):
				_texture_cache[lookup_k] = m_tex

	# 3. 지형/도로 (terrain)
	var std_terrain: Dictionary = {
		"dirt_road": Vector2i(64, 32),
		"stone_road": Vector2i(64, 32),
		"tram_track": Vector2i(64, 32),
		"asphalt_road": Vector2i(64, 32),
		"farm_normal": Vector2i(64, 32),
		"reservoir": Vector2i(64, 32),
		"farm_spring": Vector2i(64, 32),
		"farm_summer": Vector2i(64, 32),
		"farm_autumn": Vector2i(64, 32),
		"farm_winter": Vector2i(64, 32),
		"edge_wall_rock": Vector2i(64, 32),
		"edge_stream_pebbles": Vector2i(64, 32),
		"edge_road_dust": Vector2i(64, 32)
	}
	for t_id: String in std_terrain.keys():
		var t_size: Vector2i = std_terrain[t_id]
		get_or_create_texture("terrain", t_id, t_size)

	# 4. NPC/유닛 (npcs)
	var std_npcs: Dictionary = {
		"citizen_male": Vector2i(32, 48),
		"citizen_female": Vector2i(32, 48),
		"patrol_officer": Vector2i(32, 48),
		"thief": Vector2i(32, 48),
		"jangyongyeong": Vector2i(32, 48),
		"bandit": Vector2i(32, 48),
		"tram": Vector2i(64, 48),
		"classic_car": Vector2i(64, 48),
		# 1. 신분·성별·연령 12대 완전 직교 계층 시트 (64x288)
		"yangban_male_sheet": Vector2i(64, 288),
		"yangban_female_sheet": Vector2i(64, 288),
		"elder_yangban_m_sheet": Vector2i(64, 288),
		"elder_yangban_f_sheet": Vector2i(64, 288),
		"child_yangban_m_sheet": Vector2i(64, 288),
		"child_yangban_f_sheet": Vector2i(64, 288),
		"commoner_male_sheet": Vector2i(64, 288),
		"commoner_female_sheet": Vector2i(64, 288),
		"elder_commoner_m_sheet": Vector2i(64, 288),
		"elder_commoner_f_sheet": Vector2i(64, 288),
		"child_commoner_m_sheet": Vector2i(64, 288),
		"child_commoner_f_sheet": Vector2i(64, 288),
		# 구버전 호환 식별자
		"citizen_male_sheet": Vector2i(64, 288),
		"citizen_female_sheet": Vector2i(64, 288),
		"elder_male_sheet": Vector2i(64, 288),
		"elder_female_sheet": Vector2i(64, 288),
		"child_male_sheet": Vector2i(64, 288),
		"child_female_sheet": Vector2i(64, 288),

		# 2. 고증 공방 장인 8종 시트 (64x288)
		"artisan_sheet": Vector2i(64, 288),
		"artisan_blacksmith_sheet": Vector2i(64, 288),
		"artisan_potter_sheet": Vector2i(64, 288),
		"artisan_carpenter_sheet": Vector2i(64, 288),
		"artisan_weaver_sheet": Vector2i(64, 288),
		"artisan_leather_sheet": Vector2i(64, 288),
		"artisan_mason_sheet": Vector2i(64, 288),
		"artisan_paper_sheet": Vector2i(64, 288),
		"artisan_foundry_sheet": Vector2i(64, 288),

		# 3. 저잣거리 상인 8종 시트 (★ 팔달문 우시장 거간꾼 포함, 64x288)
		"merchant_sheet": Vector2i(64, 288),
		"merchant_silk_sheet": Vector2i(64, 288),
		"merchant_fish_sheet": Vector2i(64, 288),
		"merchant_herb_sheet": Vector2i(64, 288),
		"merchant_fruit_sheet": Vector2i(64, 288),
		"merchant_book_sheet": Vector2i(64, 288),
		"merchant_brass_sheet": Vector2i(64, 288),
		"merchant_tavern_sheet": Vector2i(64, 288),
		"merchant_cattle_sheet": Vector2i(64, 288),

		# 4. 기타 도시 직업 및 군사 10종 시트 (64x288)
		"builder_sheet": Vector2i(64, 288),
		"brawler_sheet": Vector2i(64, 288),
		"fisherman_sheet": Vector2i(64, 288),
		"soldier_sheet": Vector2i(64, 288),
		"jangyongyeong_sheet": Vector2i(64, 288),
		"patrol_officer_sheet": Vector2i(64, 288),
		"firefighter_sheet": Vector2i(64, 288),
		"cook_sheet": Vector2i(64, 288),
		"drunkard_sheet": Vector2i(64, 288),
		"thief_sheet": Vector2i(64, 288),
		"prop_pack_luggage": Vector2i(16, 16),
		"npc_shadow": Vector2i(24, 12)
	}
	for n_id: String in std_npcs.keys():
		var n_size: Vector2i = std_npcs[n_id]
		get_or_create_texture("npcs", n_id, n_size)

	# 5. UI 아이콘 및 모달 (ui)
	var std_ui: Dictionary = {
		"icon_gold": Vector2i(24, 24),
		"icon_grain": Vector2i(24, 24),
		"icon_pop": Vector2i(24, 24),
		"icon_loyalty": Vector2i(24, 24),
		"icon_royal": Vector2i(24, 24),
		"modal_frame": Vector2i(64, 64)
	}
	for u_id: String in std_ui.keys():
		var u_size: Vector2i = std_ui[u_id]
		get_or_create_texture("ui", u_id, u_size)

	# 6. 환경 VFX 및 군중 마커 (vfx)
	var std_vfx: Dictionary = {
		"crowd_marker": Vector2i(32, 32),
		"smoke_puff": Vector2i(16, 16),
		"water_ripple": Vector2i(64, 32)
	}
	for v_id: String in std_vfx.keys():
		var v_size: Vector2i = std_vfx[v_id]
		get_or_create_texture("vfx", v_id, v_size)

## 고품질 조선 시대 및 근대 도트 픽셀 아트 래스터라이저
static func _create_standard_art_image(category: String, asset_id: String, size: Vector2i) -> Image:
	var w: int = maxi(16, size.x)
	var h: int = maxi(16, size.y)
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	match category:
		"buildings":
			if asset_id == "well":
				var w_tex: Texture2D = bake_canvas_draw_to_png("buildings", "well", size, draw_well_original)
				if w_tex is ImageTexture:
					var c_img: Image = (w_tex as ImageTexture).get_image()
					if c_img != null and not c_img.is_empty():
						return c_img
			_paint_iso_fallback_image(img, "buildings", asset_id, w, h)
		"buildings_modern":
			_paint_modern_building(img, asset_id, w, h)
		"terrain":
			_paint_terrain_tile(img, asset_id, w, h)
		"npcs":
			_paint_npc_sprite(img, asset_id, w, h)
		"ui":
			_paint_ui_asset(img, asset_id, w, h)
		"vfx":
			_paint_vfx_asset(img, asset_id, w, h)
		_:
			_paint_generic_placeholder(img, asset_id, w, h)

	return img

## [정통 2.5D 아이소메트릭 건물 렌더러 위임 함수 (구형 평면 드로잉 완전 박멸)]
static func _paint_traditional_building(img: Image, id: String, w: int, h: int) -> void:
	_paint_iso_fallback_image(img, "buildings", id, w, h)

static func _paint_modern_building(img: Image, _id: String, w: int, h: int) -> void:
	var col_wall := Color("85929e")
	var col_win := Color("2c3e50")
	var col_glass := Color("85c1e9")
	var mid_x: int = int(float(w) * 0.5)
	var bw: int = int(float(w) * 0.38)
	var top_y: int = int(float(h) * 0.15)
	var bot_y: int = int(float(h) * 0.88)

	for y: int in range(top_y, bot_y):
		for x: int in range(mid_x - bw, mid_x + bw):
			img.set_pixel(x, y, col_wall)

	for y: int in range(top_y + 8, bot_y - 8, 8):
		for x: int in range(mid_x - bw + 6, mid_x + bw - 6, 8):
			for wy: int in range(y, y + 5):
				for wx: int in range(x, x + 5):
					if wy < h and wx < w:
						img.set_pixel(wx, wy, col_glass if (wx + wy) % 2 == 0 else col_win)

	_apply_outline(img, w, h, Color("1b2631"))

static func _paint_terrain_tile(img: Image, id: String, w: int, h: int) -> void:
	var mid_x: float = float(w) * 0.5
	var mid_y: float = float(h) * 0.5

	match id:
		"farm_spring":
			# 물 찬 논바닥(하늘빛 수면) + 연녹색 모내기 모 도트 격자
			var col_water := Color("5b8ab0")
			var col_mud := Color("544b3d")
			var col_sprout := Color("84cc16")
			var col_sprout_tip := Color("bef264")
			var col_ridge := Color("78350f")
			for y: int in range(h):
				for x: int in range(w):
					var dx: float = absf(float(x) + 0.5 - mid_x) / (float(w) * 0.5)
					var dy: float = absf(float(y) + 0.5 - mid_y) / (float(h) * 0.5)
					if dx + dy <= 0.98:
						if dx + dy > 0.88:
							img.set_pixel(x, y, col_ridge)
						else:
							var is_sprout: bool = (x % 7 == 3) and (y % 5 == 2)
							if is_sprout:
								img.set_pixel(x, y, col_sprout)
								if y - 1 >= 0:
									img.set_pixel(x, y - 1, col_sprout_tip)
							else:
								var wave: float = sin(float(x) * 0.4 + float(y) * 0.6) * 0.05
								img.set_pixel(x, y, col_water.lerp(col_mud, 0.35 + wave))

		"farm_summer":
			# 짙푸른 녹음의 우거진 벼이랑과 고랑
			var col_rice_dark := Color("15803d")
			var col_rice_mid := Color("16a34a")
			var col_rice_light := Color("4ade80")
			var col_ridge_s := Color("451a03")
			for y: int in range(h):
				for x: int in range(w):
					var dx: float = absf(float(x) + 0.5 - mid_x) / (float(w) * 0.5)
					var dy: float = absf(float(y) + 0.5 - mid_y) / (float(h) * 0.5)
					if dx + dy <= 0.98:
						if dx + dy > 0.90:
							img.set_pixel(x, y, col_ridge_s)
						else:
							var furrow: int = (x + y) % 4
							if furrow == 0:
								img.set_pixel(x, y, col_rice_dark)
							elif furrow == 1 or furrow == 2:
								img.set_pixel(x, y, col_rice_mid)
							else:
								img.set_pixel(x, y, col_rice_light)

		"farm_autumn":
			# 황금빛 벼 이삭 물결
			var col_gold_deep := Color("b45309")
			var col_gold_mid := Color("d97706")
			var col_gold_bright := Color("fbbf24")
			var col_gold_tip := Color("fef08a")
			var col_ridge_a := Color("713f12")
			for y: int in range(h):
				for x: int in range(w):
					var dx: float = absf(float(x) + 0.5 - mid_x) / (float(w) * 0.5)
					var dy: float = absf(float(y) + 0.5 - mid_y) / (float(h) * 0.5)
					if dx + dy <= 0.98:
						if dx + dy > 0.90:
							img.set_pixel(x, y, col_ridge_a)
						else:
							var pat: int = (x * 3 + y * 7) % 5
							if pat == 0:
								img.set_pixel(x, y, col_gold_tip)
							elif pat == 1 or pat == 2:
								img.set_pixel(x, y, col_gold_bright)
							elif pat == 3:
								img.set_pixel(x, y, col_gold_mid)
							else:
								img.set_pixel(x, y, col_gold_deep)

		"farm_winter":
			# 눈 덮인 논두렁과 볏짚 밑동
			var col_snow := Color("f1f5f9")
			var col_snow_shadow := Color("cbd5e1")
			var col_stubble := Color("78716c")
			var col_frozen_earth := Color("57534e")
			for y: int in range(h):
				for x: int in range(w):
					var dx: float = absf(float(x) + 0.5 - mid_x) / (float(w) * 0.5)
					var dy: float = absf(float(y) + 0.5 - mid_y) / (float(h) * 0.5)
					if dx + dy <= 0.98:
						if dx + dy > 0.88:
							img.set_pixel(x, y, col_snow_shadow)
						else:
							var is_stubble: bool = (x % 6 == 3) and (y % 4 == 2)
							if is_stubble:
								img.set_pixel(x, y, col_stubble)
								if y - 1 >= 0:
									img.set_pixel(x, y - 1, col_frozen_earth)
							else:
								var grain: float = ((x * 11 + y * 17) % 3) * 0.05
								img.set_pixel(x, y, col_snow.darkened(grain))

		"edge_wall_rock", "edge_stream_pebbles", "edge_road_dust":
			# 길가·물가 사각형 아티팩트 방지를 위해 완전 투명 처리 (Zero Square Artifacts)
			img.fill(Color(0, 0, 0, 0))
			return

		_:
			var col_fill := Color("c2b280") # 흙길
			if id == "stone_road":
				col_fill = Color("8c8c88")
			elif id == "tram_track":
				col_fill = Color("786c58")
			elif id == "asphalt_road":
				col_fill = Color("383b40")
			elif id == "farm_normal":
				col_fill = Color("5c8a42")
			elif id == "reservoir":
				col_fill = Color("2e6f9e")

			for y: int in range(h):
				for x: int in range(w):
					var dx: float = absf(float(x) + 0.5 - mid_x) / (float(w) * 0.5)
					var dy: float = absf(float(y) + 0.5 - mid_y) / (float(h) * 0.5)
					if dx + dy <= 0.98:
						var grain: float = ((x * 13 + y * 29) % 7) * 0.02
						var final_col: Color = col_fill.lightened(grain)
						if id == "tram_track" and absf(float(y) - mid_y) < 3.0:
							final_col = Color("333333") if (x % 4 == 0) else Color("silver")
						elif id == "stone_road" and ((x % 6 == 0) or (y % 4 == 0)):
							final_col = col_fill.darkened(0.25)
						img.set_pixel(x, y, final_col)

	_apply_outline(img, w, h, Color(0.12, 0.12, 0.12, 0.85))

static func _paint_npc_sprite(img: Image, id: String, w: int, h: int) -> void:
	if id.ends_with("_sheet"):
		if h >= 288:
			_paint_npc_sheet_12frame(img, id, w, h)
		else:
			_paint_npc_sheet(img, id, w, h)
		return
	elif id == "prop_pack_luggage":
		_paint_prop_pack_luggage(img, w, h)
		return
	elif id == "npc_shadow":
		_paint_npc_shadow(img, w, h)
		return

	_paint_npc_single_frame(img, id, w, h, 0, 0, 0, 0)
	_apply_outline(img, w, h, Color("1a1410"))

## 12프레임 대각선 4방향 2모션 보행 + 직업별 고유 특수 액션 시트 렌더러 (64x288: 32x48 x 12프레임)
static func _paint_npc_sheet_12frame(img: Image, id: String, w: int, h: int) -> void:
	var base_id: String = id.trim_suffix("_sheet")

	var col_skin := Color("efc49c")
	var col_hair := Color("1c1612")
	var col_cloth_top := Color("e2d9c8")
	var col_cloth_bot := Color("c8b890")
	var col_belt := Color("8a7a5a")
	var col_hat := Color("1c1612")
	var hat_type := "sangtu"
	var is_female := false
	var is_child := false
	var is_elder := false
	var is_yangban := false

	match base_id:
		# 1. 신분·성별·연령 12대 완전 직교 계층
		"yangban_male":
			col_cloth_top = Color("7c3aed") # 자줏빛 명주 도포
			col_cloth_bot = Color("1e3a8a") # 남색 명주 바지
			col_belt = Color("facc15")      # 황금 세조대
			col_hat = Color("0f172a")       # 흑립 갓
			hat_type = "gat"
			is_yangban = true
		"yangban_female":
			col_cloth_top = Color("fef08a") # 연노랑 명주 저고리
			col_cloth_bot = Color("1e3a8a") # 남색 명주 치마
			col_belt = Color("dc2626")      # 진홍 깃/고름
			hat_type = "gache"
			is_female = true
			is_yangban = true
		"elder_yangban_m":
			col_skin = Color("d4b08c")
			col_hair = Color("f8fafc")      # 순백발
			col_cloth_top = Color("f8fafc") # 백색 순백 명주 두루마기
			col_cloth_bot = Color("cbd5e1") # 담회색 명주 바지
			col_belt = Color("334155")      # 흑단 세조대
			hat_type = "gat"
			is_elder = true
			is_yangban = true
		"elder_yangban_f":
			col_skin = Color("d4b08c")
			col_hair = Color("f8fafc")      # 순백 쪽머리
			col_cloth_top = Color("99f6e4") # 옥색 누비 저고리
			col_cloth_bot = Color("334155") # 청회색 명주 치마
			col_belt = Color("991b1b")      # 자주색 고름
			hat_type = "jjok"
			is_elder = true
			is_female = true
			is_yangban = true
		"child_yangban_m":
			col_cloth_top = Color("38bdf8") # 벽청색 비단 도포
			col_cloth_bot = Color("facc15") # 황금색 조끼/바지
			col_belt = Color("e11d48")      # 진홍 허리띠
			hat_type = "bokgeon"            # 검은 호건/복건
			is_child = true
			is_yangban = true
		"child_yangban_f":
			col_cloth_top = Color("f472b6") # 연분홍 색동 저고리
			col_cloth_bot = Color("e11d48") # 진홍 명주 치마
			col_belt = Color("fde047")      # 노랑 배자
			hat_type = "daenggi_yangban"    # 긴 비단 댕기
			is_child = true
			is_female = true
			is_yangban = true

		"commoner_male", "citizen_male":
			col_cloth_top = Color("e2d9c8") # 미색 무명 저고리
			col_cloth_bot = Color("c8b890") # 잿빛 삼베 바지
			col_belt = Color("8a7a5a")      # 갈색 띠
			hat_type = "sangtu"
		"commoner_female", "citizen_female":
			col_cloth_top = Color("d8c8a0") # 옥색/무명 저고리
			col_cloth_bot = Color("475569") # 짙은 남색 무명 치마
			col_belt = Color("991b1b")      # 붉은 띠
			hat_type = "jjok"
			is_female = true
		"elder_commoner_m", "elder_male":
			col_skin = Color("d4b08c")
			col_hair = Color("e2e8f0")      # 희끗한 수염
			col_cloth_top = Color("e2e8f0") # 투박한 잿빛 무명 도포
			col_cloth_bot = Color("64748b") # 어두운 무명 바지
			col_belt = Color("8a7a5a")      # 짚 띠
			hat_type = "paeraengi_elder"
			is_elder = true
		"elder_commoner_f", "elder_female":
			col_skin = Color("d4b08c")
			col_hair = Color("e2e8f0")
			col_cloth_top = Color("cbd5e1") # 빛바랜 무명 저고리
			col_cloth_bot = Color("475569") # 어두운 잿빛 치마
			col_belt = Color("64748b")
			hat_type = "jjok"
			is_elder = true
			is_female = true
		"child_commoner_m", "child_male":
			col_cloth_top = Color("7dd3fc") # 연하늘 무명 홑저고리
			col_cloth_bot = Color("ca8a04") # 갈색 무명 반바지
			col_belt = Color("ea580c")
			hat_type = "dongja"
			is_child = true
		"child_commoner_f", "child_female":
			col_cloth_top = Color("fbcfe8") # 연분홍 무명 저고리
			col_cloth_bot = Color("475569") # 남색 무명 치마
			col_belt = Color("38bdf8")
			hat_type = "daenggi"
			is_child = true
			is_female = true

		# 2. 고증 공방 장인 8종
		"artisan_blacksmith":
			col_cloth_top = Color("7f1d1d") # 검붉은 가죽 앞치마
			col_cloth_bot = Color("451a03") # 짙은 갈색 바지
			col_belt = Color("dc2626")      # 붉은 허리띠
			hat_type = "towel_red"
		"artisan_potter":
			col_cloth_top = Color("78716c") # 흙 묻은 회갈색 작업복
			col_cloth_bot = Color("57534e") # 짙은 흙색 바지
			col_belt = Color("a8a29e")
			hat_type = "towel"
		"artisan_carpenter":
			col_cloth_top = Color("0d9488") # 청록색 쾌자
			col_cloth_bot = Color("d6d3d1") # 삼베 작업복 바지
			col_belt = Color("047857")
			hat_type = "towel"
		"artisan_weaver":
			col_cloth_top = Color("38bdf8") # 쪽빛 무명 배자
			col_cloth_bot = Color("1e3a8a") # 남치마
			col_belt = Color("f43f5e")
			hat_type = "jjok"
			is_female = true
		"artisan_leather":
			col_cloth_top = Color("854d0e") # 두꺼운 갈색 가죽 앞치마
			col_cloth_bot = Color("3f2e1a") # 짙은 암갈색 바지
			col_belt = Color("713f12")
			hat_type = "towel_brown"
		"artisan_mason":
			col_cloth_top = Color("52525b") # 돌가루 묻은 짙은 무명옷
			col_cloth_bot = Color("3f3f46") # 회색 바지
			col_belt = Color("e4e4e7")      # 백색 띠
			hat_type = "towel_white"
		"artisan_paper":
			col_cloth_top = Color("f1f5f9") # 걷어 올린 백색 무명
			col_cloth_bot = Color("a8a29e") # 젖지 않는 무명 바지
			col_belt = Color("0284c7")      # 맑은 쪽빛 허리띠
			hat_type = "sangtu"
		"artisan_foundry":
			col_cloth_top = Color("18181b") # 짙은 먹색 열기 차단 쾌자
			col_cloth_bot = Color("27272a") # 짙은 회색 바지
			col_belt = Color("ea580c")      # 주황색 내열 띠
			hat_type = "hood_foundry"
		"artisan":
			col_cloth_top = Color("b45309")
			col_cloth_bot = Color("78350f")
			col_belt = Color("dc2626")
			hat_type = "towel"

		# 3. 저잣거리 상인 8종 (★ 팔달문 우시장 거간꾼 포함)
		"merchant_silk":
			col_cloth_top = Color("047857") # 자주/청록 명주 배자
			col_cloth_bot = Color("1e3a8a") # 남색 명주 바지
			col_belt = Color("f59e0b")      # 화려한 금빛 세조대
			hat_type = "paeraengi_fine"
			is_yangban = true
		"merchant_fish":
			col_cloth_top = Color("64748b") # 어물전 무명 저고리
			col_cloth_bot = Color("1e40af") # 파란 방수 앞치마/바지
			col_belt = Color("0284c7")
			hat_type = "towel"
		"merchant_herb":
			col_cloth_top = Color("cbd5e1") # 정갈한 연회색 도포
			col_cloth_bot = Color("1e293b") # 짙은 먹색 바지
			col_belt = Color("1e3a8a")      # 청색 세조대
			hat_type = "yugeon"
			is_yangban = true
		"merchant_fruit":
			col_cloth_top = Color("d97706") # 밝은 황토색 저고리
			col_cloth_bot = Color("92400e") # 갈색 무명 바지
			col_belt = Color("f59e0b")
			hat_type = "paeraengi"
		"merchant_book":
			col_cloth_top = Color("0f766e") # 정갈한 옥색 도포
			col_cloth_bot = Color("134e4a") # 짙은 청록 바지
			col_belt = Color("f8fafc")      # 백색 세조대
			hat_type = "yugeon"
			is_yangban = true
		"merchant_brass":
			col_cloth_top = Color("f1f5f9") # 깨끗한 백색 무명 저고리
			col_cloth_bot = Color("64748b") # 회색 바지
			col_belt = Color("ca8a04")      # 황동색 띠
			hat_type = "paeraengi"
		"merchant_tavern":
			col_cloth_top = Color("e11d48") # 다홍빛 주모 저고리
			col_cloth_bot = Color("1e3a8a") # 남색 치마
			col_belt = Color("f8fafc")      # 하얀 행주치마 끈
			hat_type = "towel_red"
			is_female = true
		"merchant_cattle":
			col_cloth_top = Color("854d0e") # 거친 삼베 조끼
			col_cloth_bot = Color("451a03") # 흙먼지 묻은 바지
			col_belt = Color("713f12")      # 굵은 새끼줄 띠
			hat_type = "satgat"
		"merchant":
			col_cloth_top = Color("0d9488")
			col_cloth_bot = Color("0f766e")
			col_belt = Color("f59e0b")
			hat_type = "paeraengi"

		# 4. 기타 직업 및 군사
		"builder":
			col_cloth_top = Color("a8a29e")
			col_cloth_bot = Color("78716c")
			col_belt = Color("57534e")
			hat_type = "towel"
		"brawler":
			col_cloth_top = Color("451a03")
			col_cloth_bot = Color("292524")
			col_belt = Color("b91c1c")
			hat_type = "towel"
		"fisherman":
			col_cloth_top = Color("ca8a04")
			col_cloth_bot = Color("a16207")
			col_belt = Color("713f12")
			hat_type = "satgat"
		"soldier", "jangyongyeong":
			col_cloth_top = Color("991b1b")
			col_cloth_bot = Color("1e293b")
			col_belt = Color("facc15")
			hat_type = "jeonlip"
		"patrol_officer":
			col_cloth_top = Color("1d4ed8")
			col_cloth_bot = Color("1e293b")
			col_belt = Color("eab308")
			hat_type = "jeonlip"
		"firefighter":
			col_cloth_top = Color("334155")
			col_cloth_bot = Color("1e293b")
			col_belt = Color("0284c7")
			hat_type = "hood"
		"cook":
			col_cloth_top = Color("dc2626")
			col_cloth_bot = Color("1e3a8a")
			col_belt = Color("f8fafc")
			hat_type = "towel"
			is_female = true
		"drunkard":
			col_cloth_top = Color("94a3b8")
			col_cloth_bot = Color("64748b")
			col_belt = Color("f43f5e")
			hat_type = "gat"
		"thief", "bandit":
			col_cloth_top = Color("0f172a")
			col_cloth_bot = Color("0f172a")
			col_belt = Color("334155")
			hat_type = "hood"

	for fi: int in range(12):
		var col_idx: int = fi % 2
		var row_idx: int = int(float(fi) / 2.0)
		var ox: int = col_idx * 32
		var oy: int = row_idx * 48
		_paint_single_char_frame(img, base_id, fi, ox, oy, col_skin, col_hair, col_cloth_top, col_cloth_bot, col_belt, col_hat, hat_type, is_female, is_child, is_elder, is_yangban)

	_apply_outline(img, w, h, Color("1a1410"))

static func _paint_single_char_frame(img: Image, base_id: String, fi: int, ox: int, oy: int, col_skin: Color, col_hair: Color, col_cloth_top: Color, col_cloth_bot: Color, col_belt: Color, col_hat: Color, hat_type: String, is_female: bool, is_child: bool, is_elder: bool, is_yangban: bool = false) -> void:
	var mid_x: int = ox + 16
	var y_shift: int = 8 if is_child else 0
	var bob: int = -1 if (fi % 2 == 1 and fi < 8) else 0
	var is_back: bool = (fi < 4)
	var is_left: bool = (fi == 0 or fi == 1 or fi == 4 or fi == 5)
	var img_w: int = img.get_width()
	var img_h: int = img.get_height()

	# 1. 갓 / 헤어 / 모자
	match hat_type:
		"gat":
			var rim_y: int = oy + y_shift + 13 + bob
			for rx: int in range(mid_x - 8, mid_x + 9):
				if rx >= 0 and rx < img_w and rim_y >= 0 and rim_y < img_h:
					img.set_pixel(rx, rim_y, col_hat)
			for hy: int in range(oy + y_shift + 6 + bob, oy + y_shift + 13 + bob):
				for hx: int in range(mid_x - 4, mid_x + 5):
					if hx >= 0 and hx < img_w and hy >= 0 and hy < img_h:
						img.set_pixel(hx, hy, col_hat)
			if not is_back:
				var str_y_end: int = oy + y_shift + 22 + bob
				for sy: int in range(oy + y_shift + 14 + bob, str_y_end):
					if sy >= 0 and sy < img_h:
						if mid_x - 3 >= 0 and mid_x - 3 < img_w:
							img.set_pixel(mid_x - 3, sy, Color("0f172a"))
						if mid_x + 3 >= 0 and mid_x + 3 < img_w:
							img.set_pixel(mid_x + 3, sy, Color("0f172a"))
		"jeonlip":
			var j_rim_y: int = oy + y_shift + 12 + bob
			for rx: int in range(mid_x - 7, mid_x + 8):
				if rx >= 0 and rx < img_w and j_rim_y >= 0 and j_rim_y < img_h:
					img.set_pixel(rx, j_rim_y, Color("18181b"))
			for hy: int in range(oy + y_shift + 7 + bob, oy + y_shift + 12 + bob):
				for hx: int in range(mid_x - 4, mid_x + 5):
					if hx >= 0 and hx < img_w and hy >= 0 and hy < img_h:
						img.set_pixel(hx, hy, Color("18181b"))
			for fy: int in range(oy + y_shift + 3 + bob, oy + y_shift + 7 + bob):
				if mid_x + 3 >= 0 and mid_x + 3 < img_w and fy >= 0 and fy < img_h:
					img.set_pixel(mid_x + 3, fy, Color("ef4444"))
		"satgat":
			for sy: int in range(oy + y_shift + 5 + bob, oy + y_shift + 13 + bob):
				var spread: int = int(float(sy - (oy + y_shift + 5 + bob)) * 1.1)
				for sx: int in range(mid_x - spread, mid_x + spread + 1):
					if sx >= 0 and sx < img_w and sy >= 0 and sy < img_h:
						img.set_pixel(sx, sy, Color("ca8a04"))
		"gache":
			for gy: int in range(oy + y_shift + 6 + bob, oy + y_shift + 14 + bob):
				for gx: int in range(mid_x - 6, mid_x + 7):
					if gx >= 0 and gx < img_w and gy >= 0 and gy < img_h:
						img.set_pixel(gx, gy, col_hair)
			var pin_y: int = oy + y_shift + 8 + bob
			for px: int in range(mid_x - 5, mid_x + 6):
				if px >= 0 and px < img_w and pin_y >= 0 and pin_y < img_h:
					img.set_pixel(px, pin_y, Color("34d399")) # 비취 비녀
		"bokgeon": # 양반 남아 검은 호건/복건
			for hy: int in range(oy + y_shift + 6 + bob, oy + y_shift + 14 + bob):
				for hx: int in range(mid_x - 5, mid_x + 6):
					if hx >= 0 and hx < img_w and hy >= 0 and hy < img_h:
						img.set_pixel(hx, hy, Color("0f172a"))
			if is_back:
				for ty: int in range(oy + y_shift + 14 + bob, oy + y_shift + 22 + bob):
					for tx: int in range(mid_x - 2, mid_x + 3):
						if tx >= 0 and tx < img_w and ty >= 0 and ty < img_h:
							img.set_pixel(tx, ty, Color("0f172a"))
			else:
				var gold_y: int = oy + y_shift + 10 + bob
				if gold_y >= 0 and gold_y < img_h and mid_x >= 0 and mid_x < img_w:
					img.set_pixel(mid_x, gold_y, Color("facc15")) # 이마 금박 장식
		"yugeon": # 사대부/유생/서책상/약재상 유건
			for hy: int in range(oy + y_shift + 7 + bob, oy + y_shift + 13 + bob):
				for hx: int in range(mid_x - 4, mid_x + 5):
					if hx >= 0 and hx < img_w and hy >= 0 and hy < img_h:
						img.set_pixel(hx, hy, Color("18181b"))
			# 양쪽 각진 뿔
			var horn_y: int = oy + y_shift + 5 + bob
			if horn_y >= 0 and horn_y < img_h:
				if mid_x - 3 >= 0 and mid_x - 3 < img_w:
					img.set_pixel(mid_x - 3, horn_y, Color("18181b"))
				if mid_x + 3 >= 0 and mid_x + 3 < img_w:
					img.set_pixel(mid_x + 3, horn_y, Color("18181b"))
		"paeraengi", "paeraengi_fine", "paeraengi_elder": # 패랭이
			var p_rim_y: int = oy + y_shift + 12 + bob
			var p_col: Color = Color("451a03") if hat_type == "paeraengi_fine" else Color("a16207")
			for rx: int in range(mid_x - 6, mid_x + 7):
				if rx >= 0 and rx < img_w and p_rim_y >= 0 and p_rim_y < img_h:
					img.set_pixel(rx, p_rim_y, p_col)
			for hy: int in range(oy + y_shift + 8 + bob, oy + y_shift + 12 + bob):
				for hx: int in range(mid_x - 3, mid_x + 4):
					if hx >= 0 and hx < img_w and hy >= 0 and hy < img_h:
						img.set_pixel(hx, hy, p_col)
		"daenggi_yangban": # 양반 여아 긴 명주 댕기
			for dy: int in range(oy + y_shift + 7 + bob, oy + y_shift + 14 + bob):
				for dx: int in range(mid_x - 4, mid_x + 5):
					if dx >= 0 and dx < img_w and dy >= 0 and dy < img_h:
						img.set_pixel(dx, dy, col_hair)
			if is_back:
				for ry: int in range(oy + y_shift + 14 + bob, oy + y_shift + 32 + bob):
					if mid_x >= 0 and mid_x < img_w and ry >= 0 and ry < img_h:
						img.set_pixel(mid_x, ry, Color("e11d48")) # 긴 진홍 댕기
						if ry % 4 == 0:
							img.set_pixel(mid_x, ry, Color("facc15")) # 금박 장식
			else:
				var rib_y: int = oy + y_shift + 8 + bob
				if rib_y >= 0 and rib_y < img_h and mid_x >= 0 and mid_x < img_w:
					img.set_pixel(mid_x, rib_y, Color("facc15"))
		"daenggi":
			for dy: int in range(oy + y_shift + 7 + bob, oy + y_shift + 14 + bob):
				for dx: int in range(mid_x - 4, mid_x + 5):
					if dx >= 0 and dx < img_w and dy >= 0 and dy < img_h:
						img.set_pixel(dx, dy, col_hair)
			if is_back:
				for ry: int in range(oy + y_shift + 14 + bob, oy + y_shift + 26 + bob):
					if mid_x >= 0 and mid_x < img_w and ry >= 0 and ry < img_h:
						img.set_pixel(mid_x, ry, Color("e11d48"))
		"dongja":
			for d_top_y: int in range(oy + y_shift + 5 + bob, oy + y_shift + 8 + bob):
				if mid_x - 4 >= 0 and mid_x - 4 < img_w and d_top_y >= 0 and d_top_y < img_h:
					img.set_pixel(mid_x - 4, d_top_y, col_hair)
				if mid_x + 4 >= 0 and mid_x + 4 < img_w and d_top_y >= 0 and d_top_y < img_h:
					img.set_pixel(mid_x + 4, d_top_y, col_hair)
			for hy: int in range(oy + y_shift + 8 + bob, oy + y_shift + 14 + bob):
				for hx: int in range(mid_x - 4, mid_x + 5):
					if hx >= 0 and hx < img_w and hy >= 0 and hy < img_h:
						img.set_pixel(hx, hy, col_hair)
		"hood", "hood_foundry":
			var hood_col: Color = Color("18181b") if hat_type == "hood_foundry" else col_hat
			for hy: int in range(oy + y_shift + 6 + bob, oy + y_shift + 14 + bob):
				for hx: int in range(mid_x - 5, mid_x + 6):
					if hx >= 0 and hx < img_w and hy >= 0 and hy < img_h:
						img.set_pixel(hx, hy, hood_col)
		"towel", "towel_red", "towel_white", "towel_brown":
			for hy: int in range(oy + y_shift + 7 + bob, oy + y_shift + 14 + bob):
				for hx: int in range(mid_x - 4, mid_x + 5):
					if hx >= 0 and hx < img_w and hy >= 0 and hy < img_h:
						img.set_pixel(hx, hy, col_hair)
			var band_y: int = oy + y_shift + 12 + bob
			var band_col: Color = col_belt
			if hat_type == "towel_red":
				band_col = Color("dc2626")
			elif hat_type == "towel_white":
				band_col = Color("f8fafc")
			elif hat_type == "towel_brown":
				band_col = Color("78350f")
			for bx: int in range(mid_x - 5, mid_x + 6):
				if bx >= 0 and bx < img_w and band_y >= 0 and band_y < img_h:
					img.set_pixel(bx, band_y, band_col)
		"jjok":
			for hy: int in range(oy + y_shift + 7 + bob, oy + y_shift + 14 + bob):
				for hx: int in range(mid_x - 4, mid_x + 5):
					if hx >= 0 and hx < img_w and hy >= 0 and hy < img_h:
						img.set_pixel(hx, hy, col_hair)
			if is_back:
				var bun_y: int = oy + y_shift + 13 + bob
				for by: int in range(bun_y, bun_y + 3):
					for bx: int in range(mid_x - 2, mid_x + 3):
						if bx >= 0 and bx < img_w and by >= 0 and by < img_h:
							img.set_pixel(bx, by, col_hair)
				# 옥비녀 / 은비녀
				var pin_col: Color = Color("34d399") if is_yangban else Color("cbd5e1")
				if bun_y >= 0 and bun_y < img_h:
					for px: int in range(mid_x - 4, mid_x + 5):
						if px >= 0 and px < img_w:
							img.set_pixel(px, bun_y + 1, pin_col)
		_:
			for sty: int in range(oy + y_shift + 5 + bob, oy + y_shift + 8 + bob):
				for stx: int in range(mid_x - 1, mid_x + 2):
					if stx >= 0 and stx < img_w and sty >= 0 and sty < img_h:
						img.set_pixel(stx, sty, col_hair)
			for hy: int in range(oy + y_shift + 8 + bob, oy + y_shift + 14 + bob):
				for hx: int in range(mid_x - 4, mid_x + 5):
					if hx >= 0 and hx < img_w and hy >= 0 and hy < img_h:
						img.set_pixel(hx, hy, col_hair)

	# 2. 얼굴
	for fy: int in range(oy + y_shift + 14 + bob, oy + y_shift + 21 + bob):
		for fx: int in range(mid_x - 4, mid_x + 5):
			if fx >= 0 and fx < img_w and fy >= 0 and fy < img_h:
				if not is_back:
					img.set_pixel(fx, fy, col_skin)
				else:
					img.set_pixel(fx, fy, col_hair)

	if not is_back:
		var eye_y: int = oy + y_shift + 17 + bob
		if eye_y >= 0 and eye_y < img_h:
			if is_left:
				if mid_x - 2 >= 0 and mid_x - 2 < img_w:
					img.set_pixel(mid_x - 2, eye_y, Color("1c1612"))
			else:
				if mid_x + 2 >= 0 and mid_x + 2 < img_w:
					img.set_pixel(mid_x + 2, eye_y, Color("1c1612"))

		if is_elder:
			for by: int in range(oy + y_shift + 19 + bob, oy + y_shift + 23 + bob):
				for bx: int in range(mid_x - 2, mid_x + 3):
					if bx >= 0 and bx < img_w and by >= 0 and by < img_h:
						img.set_pixel(bx, by, Color("f8fafc"))

		if base_id == "thief" or base_id == "bandit":
			for my: int in range(oy + y_shift + 18 + bob, oy + y_shift + 21 + bob):
				for mx: int in range(mid_x - 4, mid_x + 5):
					if mx >= 0 and mx < img_w and my >= 0 and my < img_h:
						img.set_pixel(mx, my, Color("0f172a"))

		if base_id == "drunkard":
			var cheek_y: int = oy + y_shift + 18 + bob
			if cheek_y >= 0 and cheek_y < img_h:
				if mid_x - 3 >= 0 and mid_x - 3 < img_w:
					img.set_pixel(mid_x - 3, cheek_y, Color("fb7185"))
				if mid_x + 3 >= 0 and mid_x + 3 < img_w:
					img.set_pixel(mid_x + 3, cheek_y, Color("fb7185"))

	# 3. 상의
	var top_h: int = 7 if is_female else 12
	if is_child:
		top_h = 6 if is_female else 9
	for ty: int in range(oy + y_shift + 21 + bob, oy + y_shift + 21 + top_h + bob):
		for tx: int in range(mid_x - 6, mid_x + 7):
			if tx >= 0 and tx < img_w and ty >= 0 and ty < img_h:
				img.set_pixel(tx, ty, col_cloth_top)

	var belt_y: int = oy + y_shift + 21 + top_h - 1 + bob
	for bx: int in range(mid_x - 5, mid_x + 6):
		if bx >= 0 and bx < img_w and belt_y >= 0 and belt_y < img_h:
			img.set_pixel(bx, belt_y, col_belt)

	# 4. 하의 및 다리
	if is_female:
		var skirt_bottom: int = oy + y_shift + 42 + bob
		for sy: int in range(belt_y + 1, skirt_bottom):
			var s_spread: int = 5 + int(float(sy - belt_y) * 0.25)
			for sx: int in range(mid_x - s_spread, mid_x + s_spread + 1):
				if sx >= 0 and sx < img_w and sy >= 0 and sy < img_h:
					img.set_pixel(sx, sy, col_cloth_bot)
	else:
		var leg_r_shift: int = 0
		var leg_l_shift: int = 0
		if fi < 8:
			if fi % 2 == 0:
				leg_r_shift = 2
				leg_l_shift = -2
			else:
				leg_r_shift = -2
				leg_l_shift = 2

		var pant_bottom: int = oy + y_shift + 43 + bob
		for py: int in range(belt_y + 1, pant_bottom):
			var leg_prog: float = float(py - belt_y) / float(maxi(1, pant_bottom - belt_y))
			var r_s: int = int(float(leg_r_shift) * leg_prog)
			var l_s: int = int(float(leg_l_shift) * leg_prog)
			for px: int in range(mid_x - 5, mid_x + 6):
				var draw_x: int = px
				if px < mid_x:
					draw_x += l_s
				elif px > mid_x:
					draw_x += r_s
				if draw_x >= 0 and draw_x < img_w and py >= 0 and py < img_h:
					img.set_pixel(draw_x, py, col_cloth_bot)

	# 5. 신발
	var shoe_y: int = oy + y_shift + 43 + bob
	if shoe_y >= 0 and shoe_y < img_h:
		var col_shoe: Color = Color("1e293b") if (is_yangban or hat_type in ["gat", "jeonlip", "bokgeon"]) else Color("92400e")
		for sx: int in range(mid_x - 4, mid_x - 1):
			if sx >= 0 and sx < img_w:
				img.set_pixel(sx, shoe_y, col_shoe)
		for sx: int in range(mid_x + 2, mid_x + 5):
			if sx >= 0 and sx < img_w:
				img.set_pixel(sx, shoe_y, col_shoe)

	# 6. 특수 액션 및 직업 소품 (지팡이 등)
	if is_elder:
		var cane_x: int = mid_x + 6
		var cane_col: Color = Color("1c1917") if is_yangban else Color("78350f")
		for cy: int in range(oy + y_shift + 22 + bob, oy + y_shift + 44 + bob):
			if cane_x >= 0 and cane_x < img_w and cy >= 0 and cy < img_h:
				img.set_pixel(cane_x, cy, cane_col)
		if is_yangban: # 옥구슬 손잡이
			var top_cy: int = oy + y_shift + 21 + bob
			if cane_x >= 0 and cane_x < img_w and top_cy >= 0 and top_cy < img_h:
				img.set_pixel(cane_x, top_cy, Color("34d399"))

	if fi >= 8:
		var act_step: int = fi - 8
		_paint_job_action_prop(img, base_id, act_step, mid_x, oy + y_shift + bob, img_w, img_h)

static func _paint_job_action_prop(img: Image, base_id: String, step: int, mid_x: int, base_y: int, img_w: int, img_h: int) -> void:
	match base_id:
		# 1. 고증 공방 장인 8종
		"artisan_blacksmith", "artisan":
			var anvil_x: int = mid_x + 6
			for ay: int in range(base_y + 32, base_y + 38):
				for ax: int in range(anvil_x - 3, anvil_x + 4):
					if ax >= 0 and ax < img_w and ay >= 0 and ay < img_h:
						img.set_pixel(ax, ay, Color("475569"))
			var h_x: int = mid_x + 6
			var h_y: int = base_y + 18
			if step == 1:
				h_y = base_y + 30
				if h_x + 2 < img_w and h_y - 2 >= 0:
					img.set_pixel(h_x + 2, h_y - 2, Color("fef08a")) # 튀는 불꽃
					if h_x + 3 < img_w and h_y - 3 >= 0:
						img.set_pixel(h_x + 3, h_y - 3, Color("f97316"))
			elif step == 2:
				h_y = base_y + 22
			elif step == 3:
				h_x = mid_x - 3
				h_y = base_y + 16
			for hy: int in range(h_y - 1, h_y + 2):
				for hx: int in range(h_x - 1, h_x + 2):
					if hx >= 0 and hx < img_w and hy >= 0 and hy < img_h:
						img.set_pixel(hx, hy, Color("94a3b8"))

		"artisan_potter": # 도예공/옹기장 (물레 돌리기 & 흙 빚기)
			# 바닥 회전 물레 받침
			var wheel_x: int = mid_x + 6
			for wy: int in range(base_y + 35, base_y + 38):
				for wx: int in range(wheel_x - 4, wheel_x + 5):
					if wx >= 0 and wx < img_w and wy >= 0 and wy < img_h:
						img.set_pixel(wx, wy, Color("57534e"))
			# 물레 위 도자기/옹기 형태 (step에 따라 형태가 솟아오름)
			var pot_h: int = 3 + step * 2
			for py: int in range(base_y + 35 - pot_h, base_y + 35):
				var pot_w: int = 2 if py < base_y + 35 - (pot_h - 2) else 3
				for px: int in range(wheel_x - pot_w, wheel_x + pot_w + 1):
					if px >= 0 and px < img_w and py >= 0 and py < img_h:
						img.set_pixel(px, py, Color("a16207"))
			# 흙을 매만지는 양손
			var hand_y: int = base_y + 35 - pot_h + 1
			if hand_y >= 0 and hand_y < img_h:
				if wheel_x - 3 >= 0 and wheel_x - 3 < img_w:
					img.set_pixel(wheel_x - 3, hand_y, Color("efc49c"))
				if wheel_x + 3 >= 0 and wheel_x + 3 < img_w:
					img.set_pixel(wheel_x + 3, hand_y, Color("efc49c"))

		"artisan_carpenter": # 목수/소목장 (대패질 & 대패밥)
			# 작업대 위 목재 기둥
			for my: int in range(base_y + 31, base_y + 36):
				for mx: int in range(mid_x + 2, mid_x + 13):
					if mx >= 0 and mx < img_w and my >= 0 and my < img_h:
						img.set_pixel(mx, my, Color("854d0e"))
			# 대패 본체 (앞뒤로 밀고 당김)
			var plane_x: int = mid_x + 4 + step * 2
			var plane_y: int = base_y + 29
			for ply: int in range(plane_y, plane_y + 2):
				for plx: int in range(plane_x - 2, plane_x + 3):
					if plx >= 0 and plx < img_w and ply >= 0 and ply < img_h:
						img.set_pixel(plx, ply, Color("d97706"))
			# 대패 날리는 톱밥/대패밥 파티클
			if step >= 1:
				var chip_y: int = base_y + 26
				if plane_x + 3 < img_w and chip_y >= 0 and chip_y < img_h:
					img.set_pixel(plane_x + 3, chip_y, Color("fef08a"))
				if plane_x + 4 < img_w and chip_y - 2 >= 0 and chip_y - 2 < img_h:
					img.set_pixel(plane_x + 4, chip_y - 2, Color("fef08a"))

		"artisan_weaver": # 방직공/길쌈 (베틀 & 북 넘기기)
			# 베틀 사각 틀
			for by: int in range(base_y + 26, base_y + 38):
				if mid_x + 3 >= 0 and mid_x + 3 < img_w and by >= 0 and by < img_h:
					img.set_pixel(mid_x + 3, by, Color("78350f"))
				if mid_x + 11 >= 0 and mid_x + 11 < img_w and by >= 0 and by < img_h:
					img.set_pixel(mid_x + 11, by, Color("78350f"))
			# 날실 및 명주 원단
			for wy: int in range(base_y + 28, base_y + 35):
				for wx: int in range(mid_x + 4, mid_x + 11):
					if wx >= 0 and wx < img_w and wy >= 0 and wy < img_h:
						img.set_pixel(wx, wy, Color("38bdf8") if wy > base_y + 31 else Color("e2e8f0"))
			# 좌우로 오가는 북(shuttle)
			var shuttle_x: int = mid_x + 4 + (step % 4) * 2
			var shuttle_y: int = base_y + 30
			if shuttle_x >= 0 and shuttle_x < img_w and shuttle_y >= 0 and shuttle_y < img_h:
				img.set_pixel(shuttle_x, shuttle_y, Color("b45309"))

		"artisan_leather": # 가죽공/갖바치 (가죽 무두질 & 가죽칼 재단)
			# 가죽 작업 평판
			for ly: int in range(base_y + 32, base_y + 37):
				for lx: int in range(mid_x + 3, mid_x + 12):
					if lx >= 0 and lx < img_w and ly >= 0 and ly < img_h:
						img.set_pixel(lx, ly, Color("78350f"))
			# 반달형 가죽칼
			var knife_x: int = mid_x + 5 + step * 2
			var knife_y: int = base_y + 28
			for ky: int in range(knife_y - 1, knife_y + 3):
				if knife_x >= 0 and knife_x < img_w and ky >= 0 and ky < img_h:
					img.set_pixel(knife_x, ky, Color("e2e8f0"))
			if knife_x + 1 < img_w and knife_y + 1 < img_h:
				img.set_pixel(knife_x + 1, knife_y + 1, Color("e2e8f0"))

		"artisan_mason": # 석수/석공 (정 & 쇠메 돌 깎기)
			# 화강암 석재 블록
			for sy: int in range(base_y + 30, base_y + 38):
				for sx: int in range(mid_x + 4, mid_x + 12):
					if sx >= 0 and sx < img_w and sy >= 0 and sy < img_h:
						img.set_pixel(sx, sy, Color("94a3b8"))
			# 정(chisel)
			for cy: int in range(base_y + 26, base_y + 31):
				if mid_x + 7 >= 0 and mid_x + 7 < img_w and cy >= 0 and cy < img_h:
					img.set_pixel(mid_x + 7, cy, Color("334155"))
			# 쇠메(망치) 타격 및 파편
			var mallet_y: int = base_y + 20 if step == 1 else base_y + 25
			for my: int in range(mallet_y, mallet_y + 2):
				for mx: int in range(mid_x + 6, mid_x + 10):
					if mx >= 0 and mx < img_w and my >= 0 and my < img_h:
						img.set_pixel(mx, my, Color("64748b"))
			if step == 2: # 타격 시 튀는 흰 돌가루
				if mid_x + 5 >= 0 and base_y + 28 >= 0:
					img.set_pixel(mid_x + 5, base_y + 28, Color("f8fafc"))
				if mid_x + 9 < img_w and base_y + 27 >= 0:
					img.set_pixel(mid_x + 9, base_y + 27, Color("f8fafc"))

		"artisan_paper": # 한지 장인 (지통 수조 & 한지발 물질 뜨기)
			# 지통 수조 (물빛)
			for ty: int in range(base_y + 33, base_y + 39):
				for tx: int in range(mid_x + 2, mid_x + 13):
					if tx >= 0 and tx < img_w and ty >= 0 and ty < img_h:
						img.set_pixel(tx, ty, Color("0284c7") if (ty > base_y + 34 and tx > mid_x + 2 and tx < mid_x + 12) else Color("78350f"))
			# 한지발 틀 (step에 따라 물 빼며 기울기)
			var mold_y: int = base_y + 30 if step >= 2 else base_y + 34
			for mx: int in range(mid_x + 4, mid_x + 11):
				if mx >= 0 and mx < img_w and mold_y >= 0 and mold_y < img_h:
					img.set_pixel(mx, mold_y, Color("f8fafc") if step == 3 else Color("ca8a04"))

		"artisan_foundry": # 주물장/화기 (거푸집 & 도가니 쇳물 붓기)
			# 총포/주물 거푸집
			for fy: int in range(base_y + 32, base_y + 39):
				for fx: int in range(mid_x + 6, mid_x + 13):
					if fx >= 0 and fx < img_w and fy >= 0 and fy < img_h:
						img.set_pixel(fx, fy, Color("27272a"))
			# 도가니 집게 & 주황빛 쇳물
			var ladle_y: int = base_y + 24 if step >= 1 else base_y + 20
			for ly: int in range(ladle_y, ladle_y + 3):
				for lx: int in range(mid_x + 3, mid_x + 7):
					if lx >= 0 and lx < img_w and ly >= 0 and ly < img_h:
						img.set_pixel(lx, ly, Color("ea580c"))
			if step >= 1: # 거푸집 구멍으로 쏟아지는 쇳물 줄기
				for sy: int in range(ladle_y + 3, base_y + 33):
					if mid_x + 6 >= 0 and mid_x + 6 < img_w and sy >= 0 and sy < img_h:
						img.set_pixel(mid_x + 6, sy, Color("facc15"))

		# 2. 저잣거리 상인 8종
		"merchant_silk": # 비단전 상인 (비단 필 펼치기)
			var silk_x: int = mid_x + 3
			var silk_y: int = base_y + 24
			match step:
				0: # 품에 안은 비단 두루마리
					for py: int in range(silk_y - 2, silk_y + 4):
						for px: int in range(silk_x, silk_x + 3):
							if px >= 0 and px < img_w and py >= 0 and py < img_h:
								img.set_pixel(px, py, Color("e11d48"))
				1, 2: # 촤르륵 펼친 화려한 금빛/자주 비단
					for py: int in range(silk_y - 1, silk_y + 6):
						for px: int in range(silk_x, silk_x + 7):
							if px >= 0 and px < img_w and py >= 0 and py < img_h:
								var c: Color = Color("facc15") if (px + py) % 2 == 0 else Color("e11d48")
								img.set_pixel(px, py, c)
				3: # 단정하게 접으며 권유
					for py: int in range(silk_y, silk_y + 4):
						for px: int in range(silk_x + 1, silk_x + 5):
							if px >= 0 and px < img_w and py >= 0 and py < img_h:
								img.set_pixel(px, py, Color("facc15"))

		"merchant_fish": # 어물전 상인 (굴비 두름 들어올리기)
			# 어물 도마
			for dy: int in range(base_y + 34, base_y + 38):
				for dx: int in range(mid_x + 3, mid_x + 9):
					if dx >= 0 and dx < img_w and dy >= 0 and dy < img_h:
						img.set_pixel(dx, dy, Color("78350f"))
			# 엮은 굴비 두름
			var fish_y: int = base_y + 16 if (step == 1 or step == 2) else base_y + 26
			for fy: int in range(fish_y, fish_y + 7):
				if mid_x + 6 >= 0 and mid_x + 6 < img_w and fy >= 0 and fy < img_h:
					img.set_pixel(mid_x + 6, fy, Color("ca8a04")) # 엮은 새끼줄
				if fy % 2 == 0:
					if mid_x + 5 >= 0 and mid_x + 5 < img_w and fy >= 0 and fy < img_h:
						img.set_pixel(mid_x + 5, fy, Color("cbd5e1")) # 은빛 조기
					if mid_x + 7 < img_w and fy >= 0 and fy < img_h:
						img.set_pixel(mid_x + 7, fy, Color("cbd5e1"))

		"merchant_herb": # 약재상 (약저울 눈금 맞추기 & 약첩)
			var scale_y: int = base_y + 18
			var scale_x: int = mid_x + 6
			# 천칭대 (가로 막대)
			for sx: int in range(scale_x - 3, scale_x + 4):
				if sx >= 0 and sx < img_w and scale_y >= 0 and scale_y < img_h:
					img.set_pixel(sx, scale_y, Color("facc15"))
			# 매단 접시 & 눈금 추
			var tip_y: int = scale_y + 3 if step >= 2 else scale_y + 2
			if scale_x - 3 >= 0 and tip_y < img_h:
				img.set_pixel(scale_x - 3, tip_y, Color("ca8a04"))
			if scale_x + 3 < img_w and tip_y < img_h:
				img.set_pixel(scale_x + 3, tip_y, Color("ca8a04"))
			# 한지 약첩
			if step == 3:
				for py: int in range(base_y + 28, base_y + 32):
					for px: int in range(mid_x + 4, mid_x + 8):
						if px >= 0 and px < img_w and py >= 0 and py < img_h:
							img.set_pixel(px, py, Color("f8fafc"))

		"merchant_fruit": # 청과상 (과일 바구니 높이 들어 호객)
			var b_y: int = base_y + 14 if (step == 1 or step == 2) else base_y + 26
			var b_x: int = mid_x + 5
			# 바구니
			for by: int in range(b_y + 2, b_y + 6):
				for bx: int in range(b_x - 3, b_x + 4):
					if bx >= 0 and bx < img_w and by >= 0 and by < img_h:
						img.set_pixel(bx, by, Color("78350f"))
			# 붉은 사과 & 노란 참외
			for ay: int in range(b_y, b_y + 3):
				for ax: int in range(b_x - 2, b_x + 3):
					if ax >= 0 and ax < img_w and ay >= 0 and ay < img_h:
						img.set_pixel(ax, ay, Color("ef4444") if (ax + ay) % 2 == 0 else Color("facc15"))

		"merchant_book": # 서책상 (서책 펼치고 낭독/권유)
			var bk_x: int = mid_x + 4
			var bk_y: int = base_y + 22
			# 푸른 표지의 옛 서책
			for by: int in range(bk_y - 2, bk_y + 4):
				for bx: int in range(bk_x - 2, bk_x + 4):
					if bx >= 0 and bx < img_w and by >= 0 and by < img_h:
						img.set_pixel(bx, by, Color("1d4ed8"))
			# 펼쳐진 하얀 내지 (step 1, 2일 때)
			if step == 1 or step == 2:
				for py: int in range(bk_y - 1, bk_y + 3):
					for px: int in range(bk_x - 1, bk_x + 3):
						if px >= 0 and px < img_w and py >= 0 and py < img_h:
							img.set_pixel(px, py, Color("f8fafc"))
							if px == bk_x and py == bk_y:
								img.set_pixel(px, py, Color("0f172a")) # 글줄

		"merchant_brass": # 놋그릇/유기전 (방짜유기 닦기 & 반짝임)
			var bowl_x: int = mid_x + 5
			var bowl_y: int = base_y + 26
			# 황금빛 놋그릇 주발
			for by: int in range(bowl_y - 2, bowl_y + 3):
				for bx: int in range(bowl_x - 3, bowl_x + 4):
					if bx >= 0 and bx < img_w and by >= 0 and by < img_h:
						img.set_pixel(bx, by, Color("facc15"))
			# 닦는 흰 헝겊
			var cloth_x: int = bowl_x + (step % 2) * 2 - 1
			if cloth_x >= 0 and cloth_x < img_w and bowl_y >= 0 and bowl_y < img_h:
				img.set_pixel(cloth_x, bowl_y, Color("f8fafc"))
			# 반짝임 스파크 (step 3)
			if step == 3:
				var spk_x: int = bowl_x + 3
				var spk_y: int = bowl_y - 3
				if spk_x < img_w and spk_y >= 0:
					img.set_pixel(spk_x, spk_y, Color("fef08a"))

		"merchant_tavern": # 주막 주모 (탁주 주전자 & 사발 나르기)
			# 호리병 주전자
			var pot_x: int = mid_x + 5
			var pot_y: int = base_y + 22
			for py: int in range(pot_y, pot_y + 4):
				for px: int in range(pot_x - 1, pot_x + 2):
					if px >= 0 and px < img_w and py >= 0 and py < img_h:
						img.set_pixel(px, py, Color("d97706"))
			# 막걸리 사발
			var cup_y: int = base_y + 26
			var cup_x: int = mid_x + 6
			if cup_x < img_w and cup_y < img_h:
				img.set_pixel(cup_x, cup_y, Color("f8fafc"))
			if step == 1 or step == 2: # 따르는 하얀 막걸리 줄기
				for fy: int in range(pot_y + 3, cup_y):
					if pot_x + 1 < img_w and fy < img_h:
						img.set_pixel(pot_x + 1, fy, Color("f8fafc"))

		"merchant_cattle": # 팔달문 우시장 거간꾼 (황소 고삐 잡고 흥정)
			# 늠름한 황소 머리와 뿔 (우시장 고유 기믹 보존)
			var bull_x: int = mid_x + 8
			var bull_y: int = base_y + 28
			for by: int in range(bull_y - 4, bull_y + 4):
				for bx: int in range(bull_x - 3, bull_x + 4):
					if bx >= 0 and bx < img_w and by >= 0 and by < img_h:
						img.set_pixel(bx, by, Color("78350f"))
			# 황소 뿔
			if bull_x - 3 >= 0 and bull_y - 5 >= 0:
				img.set_pixel(bull_x - 3, bull_y - 5, Color("e2e8f0"))
			if bull_x + 3 < img_w and bull_y - 5 >= 0:
				img.set_pixel(bull_x + 3, bull_y - 5, Color("e2e8f0"))
			# 손에 쥔 굵은 동아줄 고삐 (step에 따라 흔듦)
			var rope_mid_y: int = base_y + 24 + (step % 2)
			for rx: int in range(mid_x + 2, bull_x - 1):
				if rx >= 0 and rx < img_w and rope_mid_y >= 0 and rope_mid_y < img_h:
					img.set_pixel(rx, rope_mid_y, Color("a16207"))

		"merchant": # 기본 호객 상인
			var prop_x: int = mid_x + 4
			var prop_y: int = base_y + 24
			match step:
				0: prop_y = base_y + 24
				1: prop_x = mid_x + 7; prop_y = base_y + 26
				2: prop_x = mid_x; prop_y = base_y + 12
				3: prop_x = mid_x + 2; prop_y = base_y + 28
			for py: int in range(prop_y - 2, prop_y + 3):
				for px: int in range(prop_x - 2, prop_x + 3):
					if px >= 0 and px < img_w and py >= 0 and py < img_h:
						img.set_pixel(px, py, Color("f59e0b"))

		# 3. 신분·연령·성별 12대 계층 고유 특수 액션
		"yangban_male": # 양반 남성 (합죽선 부채질)
			var fan_y: int = base_y + 22
			var fan_x: int = mid_x + 4
			var fan_span: int = 1 + (step % 3)
			for fx: int in range(fan_x, fan_x + fan_span + 1):
				for fy: int in range(fan_y - fan_span, fan_y + 1):
					if fx >= 0 and fx < img_w and fy >= 0 and fy < img_h:
						img.set_pixel(fx, fy, Color("f8fafc"))

		"yangban_female": # 양반 여성 (고운 손수건 & 옷소매 가리기)
			var hank_x: int = mid_x + 3
			var hank_y: int = base_y + 20 if (step % 2 == 1) else base_y + 24
			for hy: int in range(hank_y - 1, hank_y + 2):
				for hx: int in range(hank_x - 1, hank_x + 2):
					if hx >= 0 and hx < img_w and hy >= 0 and hy < img_h:
						img.set_pixel(hx, hy, Color("f472b6"))

		"elder_yangban_m": # 노인 양반 (흰 수염 쓰다듬기)
			var hand_y: int = base_y + 22 if step >= 1 else base_y + 25
			if mid_x >= 0 and mid_x < img_w and hand_y >= 0 and hand_y < img_h:
				img.set_pixel(mid_x, hand_y, Color("efc49c"))

		"elder_yangban_f": # 노인 양반 여성 (지팡이 고쳐 짚기)
			var c_shift: int = (step % 2)
			var c_x: int = mid_x + 6 + c_shift
			if c_x < img_w and base_y + 22 < img_h:
				img.set_pixel(c_x, base_y + 22, Color("34d399"))

		"child_yangban_m": # 양반 남아 (전통 줄팽이 치기)
			var top_x: int = mid_x + 6
			var top_y: int = base_y + 38
			for ty: int in range(top_y, top_y + 3):
				for tx: int in range(top_x - 1, top_x + 2):
					if tx >= 0 and tx < img_w and ty >= 0 and ty < img_h:
						img.set_pixel(tx, ty, Color("b45309"))

		"child_yangban_f": # 양반 여아 (꽃제기 차기)
			var jegi_y: int = base_y + 32 - (step % 3) * 3
			var jegi_x: int = mid_x + 5
			if jegi_x < img_w and jegi_y >= 0 and jegi_y < img_h:
				img.set_pixel(jegi_x, jegi_y, Color("facc15"))
				if jegi_y - 1 >= 0:
					img.set_pixel(jegi_x, jegi_y - 1, Color("e11d48"))

		"commoner_male", "citizen_male": # 상민 남성 (이마 땀 닦기 & 기지개)
			if step >= 1:
				var hand_sw_y: int = base_y + 16
				if mid_x - 2 >= 0 and mid_x - 2 < img_w and hand_sw_y >= 0 and hand_sw_y < img_h:
					img.set_pixel(mid_x - 2, hand_sw_y, Color("efc49c"))

		"commoner_female", "citizen_female": # 상민 여성 (광주리 이고 손인사)
			var bas_y: int = base_y + 12
			for bx: int in range(mid_x - 4, mid_x + 5):
				if bx >= 0 and bx < img_w and bas_y >= 0 and bas_y < img_h:
					img.set_pixel(bx, bas_y, Color("78350f"))

		"elder_commoner_m", "elder_male": # 노인 상민 (긴 곰방대 담뱃대)
			var pipe_y: int = base_y + 20
			for px: int in range(mid_x + 1, mid_x + 7):
				if px >= 0 and px < img_w and pipe_y >= 0 and pipe_y < img_h:
					img.set_pixel(px, pipe_y, Color("78350f"))
			if step >= 2: # 모락모락 담배 연기
				var smk_y: int = base_y + 16
				if mid_x + 7 < img_w and smk_y >= 0:
					img.set_pixel(mid_x + 7, smk_y, Color(0.9, 0.9, 0.9, 0.7))

		"elder_commoner_f", "elder_female": # 노인 상민 여성 (지팡이 짚고 허리 두드리기)
			var fist_y: int = base_y + 26
			if mid_x - 3 >= 0 and mid_x - 3 < img_w and fist_y >= 0 and fist_y < img_h:
				img.set_pixel(mid_x - 3, fist_y, Color("efc49c"))

		"child_commoner_m", "child_male": # 상민 남아 (돌 던지기)
			var pebble_x: int = mid_x + 4 + step * 2
			var pebble_y: int = base_y + 36 - step
			if pebble_x < img_w and pebble_y >= 0 and pebble_y < img_h:
				img.set_pixel(pebble_x, pebble_y, Color("78716c"))

		"child_commoner_f", "child_female": # 상민 여아 (방울꽃 흔들기)
			var flw_x: int = mid_x + 4
			var flw_y: int = base_y + 24 + (step % 2) * 2
			if flw_x < img_w and flw_y >= 0 and flw_y < img_h:
				img.set_pixel(flw_x, flw_y, Color("facc15"))

		# 4. 기타 직업 및 군사
		"builder":
			if step == 0 or step == 1:
				for lx: int in range(mid_x - 8, mid_x + 9):
					var ly: int = base_y + 20 + int(float(lx - mid_x) * 0.4)
					if lx >= 0 and lx < img_w and ly >= 0 and ly < img_h:
						img.set_pixel(lx, ly, Color("78350f"))
			else:
				for py: int in range(base_y + 22, base_y + 42):
					if mid_x + 6 >= 0 and mid_x + 6 < img_w and py >= 0 and py < img_h:
						img.set_pixel(mid_x + 6, py, Color("a8a29e"))
				var ham_y: int = base_y + 18 if step == 2 else base_y + 23
				for hx: int in range(mid_x + 4, mid_x + 9):
					if hx >= 0 and hx < img_w and ham_y >= 0 and ham_y < img_h:
						img.set_pixel(hx, ham_y, Color("64748b"))
		"brawler":
			var fist_x: int = mid_x + 4
			var fist_y: int = base_y + 24
			match step:
				1: fist_x = mid_x + 8; fist_y = base_y + 23
				2: fist_x = mid_x + 4; fist_y = base_y + 26
				3: fist_x = mid_x + 6; fist_y = base_y + 18
			for fy: int in range(fist_y - 1, fist_y + 2):
				for fx: int in range(fist_x - 1, fist_x + 2):
					if fx >= 0 and fx < img_w and fy >= 0 and fy < img_h:
						img.set_pixel(fx, fy, Color("efc49c"))
		"fisherman":
			var pole_end_x: int = mid_x + 10
			var pole_end_y: int = base_y + 36
			if step == 1:
				pole_end_y = base_y + 38
			elif step == 2:
				pole_end_x = mid_x + 4
				pole_end_y = base_y + 12
			elif step == 3:
				pole_end_x = mid_x + 6
				pole_end_y = base_y + 14
				for fy: int in range(base_y + 20, base_y + 24):
					for fx: int in range(mid_x + 5, mid_x + 8):
						if fx >= 0 and fx < img_w and fy >= 0 and fy < img_h:
							img.set_pixel(fx, fy, Color("cbd5e1"))
			for t: int in range(12):
				var lx: int = mid_x + 3 + int(float(pole_end_x - (mid_x + 3)) * (float(t) / 11.0))
				var ly: int = base_y + 24 + int(float(pole_end_y - (base_y + 24)) * (float(t) / 11.0))
				if lx >= 0 and lx < img_w and ly >= 0 and ly < img_h:
					img.set_pixel(lx, ly, Color("854d0e"))
		"soldier", "jangyongyeong":
			var blade_x: int = mid_x + 6
			var blade_y: int = base_y + 28
			match step:
				0: blade_x = mid_x + 5; blade_y = base_y + 28
				1: blade_x = mid_x; blade_y = base_y + 8
				2: blade_x = mid_x + 8; blade_y = base_y + 24
				3: blade_x = mid_x + 9; blade_y = base_y + 26
			for by: int in range(blade_y - 3, blade_y + 4):
				if blade_x >= 0 and blade_x < img_w and by >= 0 and by < img_h:
					img.set_pixel(blade_x, by, Color("e2e8f0"))
		"patrol_officer":
			var spear_x: int = mid_x + 6
			var spear_y_top: int = base_y + 6
			if step == 2:
				spear_x = mid_x + 8
				spear_y_top = base_y + 12
			for sy: int in range(spear_y_top, base_y + 43):
				if spear_x >= 0 and spear_x < img_w and sy >= 0 and sy < img_h:
					img.set_pixel(spear_x, sy, Color("64748b"))
			for hx: int in range(spear_x - 2, spear_x + 3):
				if hx >= 0 and hx < img_w and spear_y_top >= 0 and spear_y_top < img_h:
					img.set_pixel(hx, spear_y_top, Color("cbd5e1"))
		"firefighter":
			var bucket_y: int = base_y + 10 if step == 0 else base_y + 24
			for by: int in range(bucket_y, bucket_y + 6):
				for bx: int in range(mid_x + 2, mid_x + 9):
					if bx >= 0 and bx < img_w and by >= 0 and by < img_h:
						img.set_pixel(bx, by, Color("78350f"))
			if step == 2:
				for wy: int in range(base_y + 22, base_y + 32):
					var wx: int = mid_x + 8 + (wy - (base_y + 22))
					if wx >= 0 and wx < img_w and wy >= 0 and wy < img_h:
						img.set_pixel(wx, wy, Color("38bdf8"))
						if wx + 1 < img_w:
							img.set_pixel(wx + 1, wy, Color("0284c7"))
		"cook":
			for ky: int in range(base_y + 30, base_y + 38):
				for kx: int in range(mid_x + 4, mid_x + 11):
					if kx >= 0 and kx < img_w and ky >= 0 and ky < img_h:
						img.set_pixel(kx, ky, Color("1e293b"))
			if step == 1:
				for sy: int in range(base_y + 24, base_y + 29):
					if mid_x + 7 >= 0 and mid_x + 7 < img_w and sy >= 0 and sy < img_h:
						img.set_pixel(mid_x + 7, sy, Color(0.85, 0.85, 0.85, 0.6))
		"drunkard":
			var bottle_x: int = mid_x + 5
			var bottle_y: int = base_y + 24
			if step == 1:
				bottle_x = mid_x + 1
				bottle_y = base_y + 17
			elif step >= 2:
				bottle_x = mid_x + 6
				bottle_y = base_y + 34
			for by: int in range(bottle_y - 2, bottle_y + 3):
				for bx: int in range(bottle_x - 1, bottle_x + 2):
					if bx >= 0 and bx < img_w and by >= 0 and by < img_h:
						img.set_pixel(bx, by, Color("d97706"))
		"thief", "bandit":
			var bag_x: int = mid_x - 4
			var bag_y: int = base_y + 24
			if step == 3:
				bag_x = mid_x - 6
				bag_y = base_y + 20
			for by: int in range(bag_y - 2, bag_y + 3):
				for bx: int in range(bag_x - 2, bag_x + 3):
					if bx >= 0 and bx < img_w and by >= 0 and by < img_h:
						img.set_pixel(bx, by, Color("f8fafc"))
		_:
			pass

## 4프레임 보행 애니메이션 시트 렌더러 (구버전 호환용 128x48)
static func _paint_npc_sheet(img: Image, id: String, w: int, h: int) -> void:
	var base_id: String = id.trim_suffix("_sheet")
	var frame_offsets: Array = [
		[2, -2, -1, 1, 0],   # Frame 0: 오른발 앞
		[0, 0, 0, 0, -1],    # Frame 1: 중간 전이
		[-2, 2, 1, -1, 0],   # Frame 2: 왼발 앞
		[0, 0, 0, 0, -1]     # Frame 3: 중간 전이
	]
	for fi: int in range(4):
		var ox: int = fi * 32
		var off_data: Array = frame_offsets[fi]
		_paint_npc_single_frame(img, base_id, 32, h, ox, int(off_data[0]), int(off_data[1]), int(off_data[4]))
	_apply_outline(img, w, h, Color("1a1410"))

static func _paint_npc_single_frame(img: Image, id: String, frame_w: int, h: int, offset_x: int, leg_r_off: int, leg_l_off: int, bob: int) -> void:
	var col_skin := Color("efc49c")
	var col_hair := Color("1c1612")
	var col_cloth_top := Color("d8c8a0")
	var col_cloth_bot := Color("c8b890")

	if id == "patrol_officer":
		col_cloth_top = Color("1864ab") # 포졸 청색
		col_cloth_bot = Color("2a2a30")
	elif id == "thief" or id == "bandit":
		col_cloth_top = Color("2b221d") # 흑의
		col_cloth_bot = Color("2b221d")
	elif id == "jangyongyeong":
		col_cloth_top = Color("922b21") # 장용영 적색
		col_cloth_bot = Color("1b2631")
	elif id == "citizen_female":
		col_cloth_top = Color("e88aa0") # 분홍 저고리
		col_cloth_bot = Color("2e3a6a") # 남치마

	var mid_x: int = offset_x + int(float(frame_w) * 0.5)

	# 1. 갓 / 헤어
	for y: int in range(6 + bob, 14 + bob):
		for x: int in range(mid_x - 7, mid_x + 8):
			if id == "citizen_male" or id == "patrol_officer" or id == "jangyongyeong":
				if y == 13 + bob or (absi(x - mid_x) < 4 and y >= 7 + bob):
					if x >= 0 and x < img.get_width() and y >= 0 and y < h:
						img.set_pixel(x, y, col_hair)
			else:
				if absi(x - mid_x) < 5:
					if x >= 0 and x < img.get_width() and y >= 0 and y < h:
						img.set_pixel(x, y, col_hair)

	# 2. 얼굴
	for y: int in range(14 + bob, 21 + bob):
		for x: int in range(mid_x - 4, mid_x + 5):
			if x >= 0 and x < img.get_width() and y >= 0 and y < h:
				img.set_pixel(x, y, col_skin)
	if mid_x - 2 >= 0 and 17 + bob < h:
		img.set_pixel(mid_x - 2, 17 + bob, col_hair)
	if mid_x + 2 < img.get_width() and 17 + bob < h:
		img.set_pixel(mid_x + 2, 17 + bob, col_hair)

	# 3. 상의
	for y: int in range(21 + bob, 33 + bob):
		for x: int in range(mid_x - 6, mid_x + 7):
			if x >= 0 and x < img.get_width() and y >= 0 and y < h:
				img.set_pixel(x, y, col_cloth_top)

	# 4. 하의 및 다리
	for y: int in range(33 + bob, 43 + bob):
		var y_progress: float = float(y - (33 + bob)) / 10.0
		var r_shift: int = int(float(leg_r_off) * y_progress)
		var l_shift: int = int(float(leg_l_off) * y_progress)
		for x: int in range(mid_x - 5, mid_x + 6):
			if x < mid_x:
				var px: int = x + l_shift
				if px >= 0 and px < img.get_width() and y >= 0 and y < h:
					img.set_pixel(px, y, col_cloth_bot)
			elif x > mid_x:
				var px: int = x + r_shift
				if px >= 0 and px < img.get_width() and y >= 0 and y < h:
					img.set_pixel(px, y, col_cloth_bot)
			elif y < 38 + bob:
				if x >= 0 and x < img.get_width() and y >= 0 and y < h:
					img.set_pixel(x, y, col_cloth_bot)

	# 5. 신발
	for x: int in range(mid_x - 4 + leg_l_off, mid_x - 1 + leg_l_off):
		if x >= 0 and x < img.get_width() and 43 + bob < h:
			img.set_pixel(x, 43 + bob, col_hair)
	for x: int in range(mid_x + 2 + leg_r_off, mid_x + 5 + leg_r_off):
		if x >= 0 and x < img.get_width() and 43 + bob < h:
			img.set_pixel(x, 43 + bob, col_hair)

## 보부상 지게/짐 보따리 소품 (16x16)
static func _paint_prop_pack_luggage(img: Image, w: int, h: int) -> void:
	var col_wood := Color("78350f")
	var col_bag := Color("fef08a")
	var col_cloth := Color("f8fafc")
	var col_rope := Color("92400e")

	# 1. 지게 나무 다리
	for y: int in range(6, h - 2):
		if 3 < w and y < h: img.set_pixel(3, y, col_wood)
		if 12 < w and y < h: img.set_pixel(12, y, col_wood)

	# 2. 봇짐 뭉치
	for y: int in range(2, 11):
		for x: int in range(4, 12):
			var b_col: Color = col_cloth if y % 2 == 0 else col_bag
			if x == 7 or y == 6:
				b_col = col_rope
			img.set_pixel(x, y, b_col)

	_apply_outline(img, w, h, Color("1a1410"))

## 발밑 반투명 먹색 타원 그림자 (24x12)
static func _paint_npc_shadow(img: Image, w: int, h: int) -> void:
	var mid_x: float = float(w) * 0.5
	var mid_y: float = float(h) * 0.5
	var rx: float = float(w) * 0.44
	var ry: float = float(h) * 0.38
	for y: int in range(h):
		for x: int in range(w):
			var dx: float = (float(x) + 0.5 - mid_x) / rx
			var dy: float = (float(y) + 0.5 - mid_y) / ry
			var dist_sq: float = dx * dx + dy * dy
			if dist_sq <= 1.0:
				var alpha: float = clampf(0.42 * (1.0 - dist_sq * 0.65), 0.08, 0.45)
				img.set_pixel(x, y, Color(0.06, 0.06, 0.08, alpha))

## 환경 VFX 에셋 렌더러 (vfx/smoke_puff, water_ripple, crowd_marker)
static func _paint_vfx_asset(img: Image, id: String, w: int, h: int) -> void:
	match id:
		"smoke_puff":
			# 부드러운 수묵 원형 연기 파티클 (16x16)
			var mid_x: float = float(w) * 0.5
			var mid_y: float = float(h) * 0.5
			var max_r: float = float(w) * 0.44
			for y: int in range(h):
				for x: int in range(w):
					var d: float = Vector2(float(x) + 0.5 - mid_x, float(y) + 0.5 - mid_y).length()
					if d <= max_r:
						var falloff: float = 1.0 - (d / max_r)
						var alpha: float = clampf(0.85 * falloff * falloff, 0.0, 0.85)
						img.set_pixel(x, y, Color(0.88, 0.88, 0.90, alpha))

		"water_ripple":
			# 수원천 2.5D 수면 잔물결 오버레이 (64x32)
			var mid_x: float = float(w) * 0.5
			var mid_y: float = float(h) * 0.5
			var col_ripple_hi := Color(0.90, 0.96, 1.0, 0.55)
			var col_ripple_mid := Color(0.65, 0.85, 0.95, 0.35)
			for y: int in range(h):
				for x: int in range(w):
					var dx: float = absf(float(x) + 0.5 - mid_x) / (float(w) * 0.5)
					var dy: float = absf(float(y) + 0.5 - mid_y) / (float(h) * 0.5)
					if dx + dy <= 0.95:
						var wave_pattern: int = (x + y * 2) % 10
						if wave_pattern == 0:
							img.set_pixel(x, y, col_ripple_hi)
						elif wave_pattern == 1 or wave_pattern == 9:
							img.set_pixel(x, y, col_ripple_mid)

		"crowd_marker":
			# 원거리 조감 저잣거리 군중 밀집도 마커 (32x32)
			var mid_x: float = float(w) * 0.5
			var mid_y: float = float(h) * 0.5
			var col_rim := Color("b45309")
			var col_rim_hi := Color("fbbf24")
			var col_bg := Color(0.12, 0.16, 0.24, 0.88)
			var col_silhouette := Color("f8fafc")
			var col_gat := Color("1c1917")

			for y: int in range(h):
				for x: int in range(w):
					var d: float = Vector2(float(x) + 0.5 - mid_x, float(y) + 0.5 - mid_y).length()
					if d <= 14.5:
						if d >= 12.5:
							img.set_pixel(x, y, col_rim_hi if y < int(mid_y) else col_rim)
						else:
							img.set_pixel(x, y, col_bg)

			# 중앙 군중 실루엣 (3인의 백성 도트)
			for x: int in range(12, 20):
				img.set_pixel(x, 11, col_gat)
			for y: int in range(9, 12):
				for x: int in range(14, 18):
					img.set_pixel(x, y, col_gat)
			for y: int in range(12, 16):
				for x: int in range(14, 18):
					img.set_pixel(x, y, col_silhouette)
			for y: int in range(16, 23):
				for x: int in range(12, 20):
					img.set_pixel(x, y, col_silhouette)

			# 좌측 인물
			for y: int in range(13, 16):
				for x: int in range(8, 12):
					img.set_pixel(x, y, col_gat)
			for y: int in range(16, 22):
				for x: int in range(7, 13):
					img.set_pixel(x, y, col_silhouette.darkened(0.2))

			# 우측 인물
			for y: int in range(13, 16):
				for x: int in range(20, 24):
					img.set_pixel(x, y, col_gat)
			for y: int in range(16, 22):
				for x: int in range(19, 25):
					img.set_pixel(x, y, col_silhouette.darkened(0.2))

		_:
			_paint_generic_placeholder(img, id, w, h)

static func _paint_generic_placeholder(img: Image, _label_key: String, _w: int, _h: int) -> void:
	# 사각형 테두리와 불투명 배경색을 전면 제거하고 완전 투명 이미지로 폴백 (Zero Square Artifacts)
	img.fill(Color(0, 0, 0, 0))

static func _apply_outline(img: Image, w: int, h: int, outline_col: Color) -> void:
	var temp := img.duplicate()
	for y: int in range(h):
		for x: int in range(w):
			if temp.get_pixel(x, y).a > 0.1:
				for dy: int in [-1, 0, 1]:
					for dx: int in [-1, 0, 1]:
						var nx: int = x + dx
						var ny: int = y + dy
						if nx >= 0 and nx < w and ny >= 0 and ny < h:
							if temp.get_pixel(nx, ny).a <= 0.05:
								img.set_pixel(nx, ny, outline_col)

static func _paint_ui_asset(img: Image, id: String, w: int, h: int) -> void:
	match id:
		"icon_gold":
			# 상평통보 엽전: w x h (24x24) 원형 테두리 + 내부 사각 구멍
			var cx: float = float(w) * 0.5
			var cy: float = float(h) * 0.5
			var r_out: float = float(mini(w, h)) * 0.42
			var r_in: float = float(mini(w, h)) * 0.16
			var col_coin := Color("d4af37")
			var col_shadow := Color("996515")
			var col_rim := Color("543d0e")
			for y: int in range(h):
				for x: int in range(w):
					var d: float = Vector2(float(x) - cx, float(y) - cy).length()
					var in_hole: bool = absf(float(x) - cx) < r_in and absf(float(y) - cy) < r_in
					if d <= r_out and not in_hole:
						if d > r_out - 1.5 or absf(float(x) - cx) >= r_in - 1.0 and absf(float(y) - cy) >= r_in - 1.0:
							img.set_pixel(x, y, col_rim)
						elif float(y) > cy:
							img.set_pixel(x, y, col_shadow)
						else:
							img.set_pixel(x, y, col_coin)
		"icon_grain":
			# 벼 이삭 실루엣: 줄기와 황금빛 볏알 알곡들
			var col_stem := Color("4d7c0f")
			var col_grain := Color("eab308")
			var col_rim := Color("1c1917")
			var cx_grain: int = int(float(w) * 0.5)
			for y: int in range(int(float(h) * 0.2), int(float(h) * 0.9)):
				var sx: int = cx_grain + int(sin(float(y) * 0.2) * 2.0)
				if sx >= 0 and sx < w:
					img.set_pixel(sx, y, col_stem)
				if y % 3 == 0:
					for dx: int in [-3, -2, 2, 3]:
						var g_x: int = sx + dx
						if g_x >= 0 and g_x < w and y - 1 >= 0 and y - 1 < h:
							img.set_pixel(g_x, y - 1, col_grain)
							img.set_pixel(g_x, y, col_grain)
			_apply_outline(img, w, h, col_rim)
		"icon_pop":
			# 백성 두상: 갓(검정) + 얼굴(살구) + 옷깃(청색)
			var col_hat := Color("1c1917")
			var col_skin := Color("fed7aa")
			var col_robe := Color("38bdf8")
			var cx_pop: int = int(float(w) * 0.5)
			# 갓양태
			for x: int in range(cx_pop - 7, cx_pop + 8):
				if x >= 0 and x < w:
					img.set_pixel(x, int(float(h) * 0.25), col_hat)
			# 갓대
			for y: int in range(int(float(h) * 0.12), int(float(h) * 0.25)):
				for x: int in range(cx_pop - 3, cx_pop + 4):
					if x >= 0 and x < w and y >= 0 and y < h:
						img.set_pixel(x, y, col_hat)
			# 얼굴
			for y: int in range(int(float(h) * 0.29), int(float(h) * 0.55)):
				for x: int in range(cx_pop - 4, cx_pop + 5):
					if x >= 0 and x < w and y >= 0 and y < h:
						img.set_pixel(x, y, col_skin)
			# 눈
			if cx_pop - 2 >= 0 and int(float(h) * 0.4) < h:
				img.set_pixel(cx_pop - 2, int(float(h) * 0.4), col_hat)
			if cx_pop + 2 < w and int(float(h) * 0.4) < h:
				img.set_pixel(cx_pop + 2, int(float(h) * 0.4), col_hat)
			# 옷깃
			for y: int in range(int(float(h) * 0.58), int(float(h) * 0.9)):
				for x: int in range(cx_pop - 7, cx_pop + 8):
					if x >= 0 and x < w and y >= 0 and y < h:
						img.set_pixel(x, y, col_robe)
			_apply_outline(img, w, h, col_hat)
		"icon_loyalty":
			# 충성 / 민심: 단청 붉은빛 하트 실루엣
			var col_heart := Color("ef4444")
			var col_hi := Color("fca5a5")
			var col_rim := Color("1e1b4b")
			var cx_loy: float = float(w) * 0.5
			var cy_loy: float = float(h) * 0.48
			for y: int in range(h):
				for x: int in range(w):
					var nx: float = (float(x) - cx_loy) / (float(w) * 0.38)
					var ny: float = -(float(y) - cy_loy) / (float(h) * 0.38)
					var eq: float = pow(nx * nx + ny * ny - 1.0, 3.0) - nx * nx * pow(ny, 3.0)
					if eq <= 0.0:
						if ny > 0.2 and nx < -0.1:
							img.set_pixel(x, y, col_hi)
						else:
							img.set_pixel(x, y, col_heart)
			_apply_outline(img, w, h, col_rim)
		"icon_royal":
			# 왕권 / 국방: 황금 왕관 및 보주 문양
			var col_gold := Color("fbbf24")
			var col_gem := Color("a855f7")
			var col_rim := Color("451a03")
			var cx_roy: int = int(float(w) * 0.5)
			# 기단부
			for y: int in range(int(float(h) * 0.65), int(float(h) * 0.85)):
				for x: int in range(cx_roy - 8, cx_roy + 9):
					if x >= 0 and x < w and y >= 0 and y < h:
						img.set_pixel(x, y, col_gold)
			# 중앙 보옥
			for y: int in range(int(float(h) * 0.7), int(float(h) * 0.8)):
				for x: int in range(cx_roy - 2, cx_roy + 3):
					if x >= 0 and x < w and y >= 0 and y < h:
						img.set_pixel(x, y, col_gem)
			# 3갈래 첨탑
			for y: int in range(int(float(h) * 0.25), int(float(h) * 0.65)):
				if y >= 0 and y < h:
					img.set_pixel(cx_roy, y, col_gold)
					if cx_roy - 6 >= 0 and y + 3 < h:
						img.set_pixel(cx_roy - 6, y + 3, col_gold)
					if cx_roy + 6 < w and y + 3 < h:
						img.set_pixel(cx_roy + 6, y + 3, col_gold)
					if y < int(float(h) * 0.35):
						if cx_roy - 1 >= 0:
							img.set_pixel(cx_roy - 1, y, col_gold)
						if cx_roy + 1 < w:
							img.set_pixel(cx_roy + 1, y, col_gold)
			_apply_outline(img, w, h, col_rim)
		"modal_frame":
			# 모달 프레임 64x64 (한지 바탕, 옻칠 고동 테두리, 내벽 금선)
			var col_bg := Color("f5f0e6")
			var col_border := Color("2d1810")
			var col_gold_line := Color("d4af37")
			for y: int in range(h):
				for x: int in range(w):
					if x < 4 or x >= w - 4 or y < 4 or y >= h - 4:
						img.set_pixel(x, y, col_border)
					elif x == 5 or x == w - 6 or y == 5 or y == h - 6:
						img.set_pixel(x, y, col_gold_line)
					else:
						img.set_pixel(x, y, col_bg)
		_:
			_paint_generic_placeholder(img, id, w, h)

## 사용자가 PNG 파일을 수정한 뒤 런타임에 즉시 새로고침할 때 호출
static func reload_all_textures() -> void:
	_texture_cache.clear()
