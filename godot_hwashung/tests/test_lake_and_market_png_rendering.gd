extends SceneTree

const SpriteCacheMgr = preload("res://scripts/autoload/SpriteCacheManager.gd")

func _init() -> void:
	print("=== 만석거/축만제 및 상점/공방 PNG 에셋 무결성 검증 시작 ===")

	var scm: Node = SpriteCacheMgr.new()
	root.add_child(scm)
	scm._ready()

	# 1. 만석거 및 축만제 6x6 PNG 텍스처 검증
	var mg_tex: Texture2D = SpriteCacheMgr.get_seasonal_or_base_texture("buildings", "manseokgeo", "", Vector2i(448, 320))
	assert(mg_tex != null, "만석거 텍스처가 null입니다.")
	assert(mg_tex.get_width() == 448 and mg_tex.get_height() == 320, "만석거 텍스처 규격이 448x320이 아닙니다: %dx%d" % [mg_tex.get_width(), mg_tex.get_height()])
	print("[PASS] 만석거 6x6 고화질 PNG 텍스처 로드 성공 (448x320)")

	var cm_tex: Texture2D = SpriteCacheMgr.get_seasonal_or_base_texture("buildings", "chukmanje", "", Vector2i(448, 320))
	assert(cm_tex != null, "축만제 텍스처가 null입니다.")
	assert(cm_tex.get_width() == 448 and cm_tex.get_height() == 320, "축만제 텍스처 규격이 448x320이 아닙니다: %dx%d" % [cm_tex.get_width(), cm_tex.get_height()])
	print("[PASS] 축만제 6x6 고화질 PNG 텍스처 로드 성공 (448x320)")

	# 2. 저잣거리 상점 20종 PNG 텍스처 검증
	for i: int in range(20):
		var s_id: String = "market_shop_%02d" % (i + 1)
		var s_tex: Texture2D = SpriteCacheMgr.get_seasonal_or_base_texture("buildings", s_id, "", Vector2i(64, 72))
		assert(s_tex != null, "%s 텍스처가 null입니다." % s_id)
		assert(s_tex.get_width() == 64 and s_tex.get_height() == 72, "%s 규격 불일치: %dx%d" % [s_id, s_tex.get_width(), s_tex.get_height()])
	print("[PASS] 저잣거리 상점 20종 PNG 텍스처 전수 로드 성공 (각 64x72)")

	# 3. 공방 13종 PNG 텍스처 검증
	var ws_specs: Dictionary = {
		"ws_1x1_carpenter": Vector2i(64, 72),
		"ws_1x1_bamboo": Vector2i(64, 72),
		"ws_1x1_hanji": Vector2i(64, 72),
		"ws_1x1_metalcraft": Vector2i(64, 72),
		"ws_1x1_leather": Vector2i(64, 72),
		"ws_2x1_blacksmith": Vector2i(96, 88),
		"ws_2x1_dyeing": Vector2i(96, 88),
		"ws_2x1_stonemason": Vector2i(96, 88),
		"ws_2x1_tile_kiln": Vector2i(96, 88),
		"ws_2x1_shoemaker": Vector2i(96, 88),
		"ws_2x2_ceramics": Vector2i(128, 112),
		"ws_2x2_lumber_machinery": Vector2i(128, 112),
		"ws_3x3_royal_arsenal": Vector2i(192, 160)
	}
	for ws_id: String in ws_specs.keys():
		var target_sz: Vector2i = ws_specs[ws_id]
		var w_tex: Texture2D = SpriteCacheMgr.get_seasonal_or_base_texture("buildings", ws_id, "", target_sz)
		assert(w_tex != null, "%s 텍스처가 null입니다." % ws_id)
		assert(w_tex.get_width() == target_sz.x and w_tex.get_height() == target_sz.y, "%s 규격 불일치: %dx%d (기대값: %dx%d)" % [ws_id, w_tex.get_width(), w_tex.get_height(), target_sz.x, target_sz.y])
	print("[PASS] 공방 13종 고품질 PNG 텍스처 전수 로드 성공")

	scm.queue_free()
	print("=== 모든 검증 완료: ALL PASS ===")
	quit()
