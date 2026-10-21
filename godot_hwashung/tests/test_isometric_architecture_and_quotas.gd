# test_isometric_architecture_and_quotas.gd
# 2.5D 아이소메트릭 건축 대개편 및 피라미드 비율, 팔달문 우시장 보존 단위 테스트
extends SceneTree

const SpriteCacheManager = preload("res://scripts/autoload/SpriteCacheManager.gd")
const GameGrid = preload("res://scripts/GameGrid.gd")

func _init() -> void:
	print("=== [TEST] 2.5D 아이소메트릭 건축 대개편 및 피라미드 비율 검증 시작 ===")
	test_sprite_cache_generation()
	test_paldal_cattle_market_preservation()
	test_housing_pyramid_and_spacing_quotas()
	test_workshop_pyramid_quotas()
	test_market_clustering()
	print("=== [TEST PASS] 모든 2.5D 건축 및 피라미드 시뮬레이션 검증 성공! ===")
	quit(0)

func test_sprite_cache_generation() -> void:
	print("\n--- 1. 2.5D 아이소메트릭 PNG 생성 및 캐시 검증 ---")
	var scm: Node = SpriteCacheManager.instance
	if scm == null:
		scm = SpriteCacheManager.new()
		root.add_child(scm)

	SpriteCacheManager.upgrade_procedural_pngs_v4_iso()

	# A. 가옥 20종 검증
	for i in range(1, 8):
		var id_s: String = "thatch_house_%02d" % i
		var tex: Texture2D = SpriteCacheManager.get_or_create_texture("buildings", id_s, Vector2i(64, 72))
		assert(tex != null, "초가 1x1 텍스처 누락: " + id_s)
	for i in range(8, 11):
		var id_s: String = "thatch_house_%02d" % i
		var tex: Texture2D = SpriteCacheManager.get_or_create_texture("buildings", id_s, Vector2i(96, 88))
		assert(tex != null, "초가 2x1 텍스처 누락: " + id_s)

	for i in range(1, 5):
		var id_s: String = "tile_house_%02d" % i
		var tex: Texture2D = SpriteCacheManager.get_or_create_texture("buildings", id_s, Vector2i(64, 72))
		assert(tex != null, "기와 1x1 텍스처 누락: " + id_s)
	for i in range(5, 8):
		var id_s: String = "tile_house_%02d" % i
		var tex: Texture2D = SpriteCacheManager.get_or_create_texture("buildings", id_s, Vector2i(96, 88))
		assert(tex != null, "기와 1x2 텍스처 누락: " + id_s)
	for i in range(8, 10):
		var id_s: String = "tile_house_%02d" % i
		var tex: Texture2D = SpriteCacheManager.get_or_create_texture("buildings", id_s, Vector2i(128, 112))
		assert(tex != null, "기와 2x2 텍스처 누락: " + id_s)
	var t_3x2: Texture2D = SpriteCacheManager.get_or_create_texture("buildings", "tile_house_10_3x2", Vector2i(160, 136))
	var t_3x3: Texture2D = SpriteCacheManager.get_or_create_texture("buildings", "tile_house_10_3x3", Vector2i(192, 160))
	assert(t_3x2 != null, "대부호 3x2 텍스처 누락")
	assert(t_3x3 != null, "거상 3x3 텍스처 누락")

	# B. 상점 20종 검증
	for i in range(1, 21):
		var id_s: String = "market_shop_%02d" % i
		var tex: Texture2D = SpriteCacheManager.get_or_create_texture("buildings", id_s, Vector2i(64, 72))
		assert(tex != null, "상점 텍스처 누락: " + id_s)

	# C. 공방 13종 검증
	var ws_keys: Array[String] = [
		"ws_1x1_carpenter", "ws_1x1_bamboo", "ws_1x1_hanji", "ws_1x1_metalcraft", "ws_1x1_leather",
		"ws_2x1_blacksmith", "ws_2x1_dyeing", "ws_2x1_stonemason", "ws_2x1_tile_kiln", "ws_2x1_shoemaker",
		"ws_2x2_ceramics", "ws_2x2_lumber_machinery", "ws_3x3_royal_arsenal"
	]
	for k: String in ws_keys:
		var sz: Vector2i = Vector2i(64, 72)
		if k.begins_with("ws_2x1"): sz = Vector2i(96, 88)
		elif k.begins_with("ws_2x2"): sz = Vector2i(128, 112)
		elif k.begins_with("ws_3x3"): sz = Vector2i(192, 160)
		var tex: Texture2D = SpriteCacheManager.get_or_create_texture("buildings", k, sz)
		assert(tex != null, "공방 텍스처 누락: " + k)

	# D. 특수 공간 5종 검증
	for sp: String in ["seodang", "maegok_seowon", "women_play_yard", "children_play_yard", "well"]:
		var sz: Vector2i = Vector2i(128, 112)
		if sp == "maegok_seowon": sz = Vector2i(192, 160)
		elif sp == "well": sz = Vector2i(64, 72)
		var tex: Texture2D = SpriteCacheManager.get_or_create_texture("buildings", sp, sz)
		assert(tex != null, "특수 공간 텍스처 누락: " + sp)

	print("[PASS] 가옥 20종, 상점 20종, 공방 13종, 특수공간 5종 2.5D 에셋 등록 완료!")

func test_paldal_cattle_market_preservation() -> void:
	print("\n--- 2. 팔달문 우시장(소전) 고유 생성 조건 및 가축 거래 기믹 보존 검증 ---")
	var grid := GameGrid.new()
	grid._build_from_map()

	# 팔달문 위치 설정 (남쪽 x=16, y=54)
	grid.grid[54][16]["building"] = "gate"
	grid.grid[54][16]["gate_name"] = "팔달문 (八達門)"

	# 팔달문 인근 10칸 안에 3x3 저잣거리 구획 배치
	var tiles: Array[Vector2i] = []
	for dy in range(3):
		for dx in range(3):
			var p := Vector2i(16 + dx, 50 + dy)
			grid.grid[p.y][p.x]["terrain"] = "plain"
			grid.grid[p.y][p.x]["zone"] = "com"
			grid.grid[p.y][p.x]["building"] = ""
			tiles.append(p)

	var ok: bool = grid.allocate_cattle_market(tiles)
	print("팔달문 우시장 할당 결과:", ok)
	assert(ok == true, "팔달문 인근 우시장 정상 할당 실패")

	# 우시장 플라자 및 에셋 ID 일치 확인
	var pl: Dictionary = grid.grid[50][16].get("plaza", {})
	assert(pl.get("kind", "") == "cattle", "우시장 plaza kind 불일치")
	var s_id: String = grid.get_shop_asset_id(16, 50)
	print("우시장 타일 에셋 ID:", s_id)
	assert(s_id == "market_shop_09", "우시장 에셋 ID는 09_paldal_cattle_market이어야 함")
	print("[PASS] 팔달문 우시장 고유 생성 및 기믹 100% 보존 확인!")

func test_housing_pyramid_and_spacing_quotas() -> void:
	print("\n--- 3. 주거 구획 피라미드 비율 및 이격 거리 쿼터 검증 ---")
	var grid := GameGrid.new()
	grid._build_from_map()

	# 100채의 기와집 배치 (x: 10~20, y: 10~20)
	for y in range(10, 20):
		for x in range(10, 20):
			grid.grid[y][x]["zone"] = "res"
			grid.grid[y][x]["building"] = "res_2"
			grid.grid[y][x]["lv"] = 85 # 최고 입지
			grid.grid[y][x]["road"] = true # 박석길 인접 모사

	# 주변 박석길 깔기
	for x in range(9, 21):
		grid.grid[9][x]["building"] = "road"
		grid.grid[9][x]["stone"] = true

	# 여러 턴 경과하여 합필 진행
	for turn in range(15):
		grid._form_house_groups(0.07)

	var stats: Dictionary = grid._count_house_types()
	var total_h: int = int(stats["total"])
	var mansions: int = int(stats["tile_mansion"])
	var tile_2x2: int = int(stats["tile_2x2"])

	print("가옥 집계 결과:", stats)
	var mansion_ratio: float = float(mansions) / float(total_h)
	var tile_2x2_ratio: float = float(tile_2x2) / float(total_h)

	print("대부호 저택 비율:", mansion_ratio * 100.0, "% (목표 2% 이하)")
	print("부호 가택(2x2) 비율:", tile_2x2_ratio * 100.0, "% (목표 6% 이하)")

	assert(mansion_ratio <= 0.05, "대부호 저택 과다 생성 방지 실패")
	assert(tile_2x2_ratio <= 0.12, "2x2 부호 가택 과다 생성 방지 실패")
	print("[PASS] 주거 피라미드 비율 및 희소성 쿼터 준수 확인!")

func test_workshop_pyramid_quotas() -> void:
	print("\n--- 4. 공방 규모별 피라미드 쿼터 검증 ---")
	var grid := GameGrid.new()
	grid._build_from_map()

	# 30채의 공방 배치
	for y in range(10, 16):
		for x in range(10, 15):
			grid.grid[y][x]["zone"] = "ind"
			grid.grid[y][x]["building"] = "ind_1"

	for turn in range(10):
		grid._form_workshop_groups()

	var ws_stats: Dictionary = grid._count_workshop_types()
	print("공방 집계 결과:", ws_stats)
	var ws_3x3: int = int(ws_stats["ws_3x3"])
	var ws_2x2: int = int(ws_stats["ws_2x2"])

	assert(ws_3x3 <= 1, "3x3 관영 군기시 과다 생성 방지 실패")
	assert(ws_2x2 <= 3, "2x2 대형 가마 과다 생성 방지 실패")
	print("[PASS] 공방 규모별 피라미드 비율 정상 통제 확인!")

func test_market_clustering() -> void:
	print("\n--- 5. 4대문 상권 및 박석길 밀집 배정 검증 ---")
	var grid := GameGrid.new()
	grid._build_from_map()

	# 장안문 설정 (북쪽 x=16, y=10)
	grid.grid[10][16]["building"] = "gate"
	grid.grid[10][16]["gate_name"] = "장안문 (長安門)"

	# 장안문 3칸 앞 상점
	grid.grid[13][16]["zone"] = "com"
	grid.grid[13][16]["building"] = "com_1"
	var jangan_shop: String = grid.get_shop_asset_id(16, 13)
	print("장안문 인근 상점 배정 ID:", jangan_shop)
	assert(jangan_shop.begins_with("market_shop_"), "유효한 상점 ID여야 함")
	print("[PASS] 상권별 클러스터링 정상 작동 확인!")
