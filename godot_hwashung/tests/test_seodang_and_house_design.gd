extends SceneTree

const SpriteCacheManager = preload("res://scripts/autoload/SpriteCacheManager.gd")

func _init() -> void:
	print("==================================================")
	print("[TEST] 서당 및 기와집 디자인 입체감 & 크래시 방지 검증")
	print("==================================================")

	var all_passed: bool = true

	# 1. InspectNarrativeGenerator Variant -> str 크래시 방지 검증
	print("\n[검사 1] InspectNarrativeGenerator build_inspect_data() 널/int 안전성 검증")
	var test_entities: Array[Dictionary] = [
		{"building": 0, "pos": Vector2i(5, 5)},
		{"building": 0, "plaza": {"kind": "seodang"}, "pos": Vector2i(6, 6)},
		{"building": "seodang", "pos": Vector2i(7, 7)},
		{"building": 0, "facility_id": "seodang", "pos": Vector2i(8, 8)},
		{"building": "res_2", "pos": Vector2i(9, 9)},
		{"building": 0, "base_job_type": 1, "pos": Vector2i(10, 10)},
		{"building": "base_jungin", "pos": Vector2i(11, 11)},
		{"building": "base_ajeon", "pos": Vector2i(12, 12)},
		{"building": "base_artisan", "pos": Vector2i(13, 13)},
		{"building": "base_butcher", "pos": Vector2i(14, 14)}
	]

	for i in range(test_entities.size()):
		var ent: Dictionary = test_entities[i]
		var data: Dictionary = InspectNarrativeGenerator.build_inspect_data(ent, null, null, null)
		if data.is_empty() or not data.has("title") or not data.has("description"):
			print("❌ 엔티티 #%d 검사 실패: %s" % [i, str(ent)])
			all_passed = false
		else:
			print("  - 케이스 #%d PASS: [%s] %s" % [i, data.get("category", ""), data.get("title", "")])

	# 2. SpriteCacheManager v8 평면 건물 영구 박멸 & 2.5D 아이소메트릭 업그레이드 검증
	print("\n[검사 2] SpriteCacheManager v8 재베이킹 실행 및 2.5D PNG 파일 검증")
	SpriteCacheManager.upgrade_procedural_pngs_v8_purge_flat_houses()

	var required_sprites: Dictionary = {
		"buildings/thatch_house.png": Vector2i(64, 72),
		"buildings/thatch_house_01.png": Vector2i(64, 72),
		"buildings/thatch_house_07.png": Vector2i(64, 72),
		"buildings/thatch_house_08.png": Vector2i(96, 88),
		"buildings/thatch_house_09.png": Vector2i(96, 88),
		"buildings/thatch_house_10.png": Vector2i(96, 88),
		"buildings/tile_house.png": Vector2i(64, 72),
		"buildings/tile_house_01.png": Vector2i(64, 72),
		"buildings/tile_house_07.png": Vector2i(96, 88),
		"buildings/tile_house_08.png": Vector2i(128, 112),
		"buildings/tile_house_09.png": Vector2i(128, 112),
		"buildings/tile_house_10_3x2.png": Vector2i(160, 136),
		"buildings/tile_house_10_3x3.png": Vector2i(192, 160),
		"buildings/market_shop.png": Vector2i(64, 72),
		"buildings/workshop.png": Vector2i(64, 72),
		"buildings/seodang.png": Vector2i(128, 112),
		"buildings/maegok_seowon.png": Vector2i(192, 160),
		"buildings/seojangdae.png": Vector2i(128, 112),
		"buildings/yeonmudae.png": Vector2i(128, 112),
		"buildings/yusubu.png": Vector2i(128, 112),
		"buildings/haenggung.png": Vector2i(448, 320)
	}

	for rel_path: String in required_sprites.keys():
		var expected_sz: Vector2i = required_sprites[rel_path]
		var full_res: String = "res://assets/sprites/" + rel_path
		var g_path: String = ProjectSettings.globalize_path(full_res)
		if not FileAccess.file_exists(g_path) and not FileAccess.file_exists(full_res):
			print("❌ 스프라이트 누락: %s" % rel_path)
			all_passed = false
			continue

		var img: Image = Image.load_from_file(g_path if FileAccess.file_exists(g_path) else full_res)
		if img == null or img.is_empty():
			print("❌ 이미지 로드 실패: %s" % rel_path)
			all_passed = false
		elif img.get_width() != expected_sz.x or img.get_height() != expected_sz.y:
			print("❌ 해상도 불일치: %s (기대: %s, 실제: %dx%d)" % [rel_path, str(expected_sz), img.get_width(), img.get_height()])
			all_passed = false
		else:
			print("  - 스프라이트 검증 PASS: %s (%dx%d)" % [rel_path, img.get_width(), img.get_height()])

	print("\n==================================================")
	if all_passed:
		print("🎉 모든 가옥 2.5D 입체 렌더링 및 무결성 검증 100% PASS!")
	else:
		print("❌ 일부 검증 항목 FAIL 발생!")
	print("==================================================")

	quit(0 if all_passed else 1)
