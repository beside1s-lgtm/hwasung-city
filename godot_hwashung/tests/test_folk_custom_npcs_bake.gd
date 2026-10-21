extends SceneTree

## [세시풍속 5종(전기수, 낚시꾼, 연날리기, 씨름장사, 택견꾼) 도트 캐릭터 베이킹 및 규격 검증 테스트]

const SpriteCacheManager = preload("res://scripts/autoload/SpriteCacheManager.gd")
const CharacterPixelArtist = preload("res://scripts/rendering/CharacterPixelArtist.gd")
const NpcSprites = preload("res://scripts/NpcSprites.gd")

func _init() -> void:
	print("=== 세시풍속 5종 도트 캐릭터 베이킹 및 규격 검증 시작 ===")

	# 1. 베이킹 실행
	SpriteCacheManager.upgrade_procedural_pngs_v8_joseon_48x48_named26()

	# 2. 5대 세시풍속 프리셋 확인
	var folk_keys: Array[String] = [
		"npc_jeongisu",
		"npc_fisherman",
		"npc_kite_flyer",
		"npc_ssireum",
		"npc_taekkyeon"
	]

	var npcs_dir := "res://assets/sprites/npcs/"
	for fid: String in folk_keys:
		assert(CharacterPixelArtist.GENERIC_PRESETS.has(fid), "GENERIC_PRESETS에 %s 프리셋이 존재해야 합니다." % fid)
		var sheet_path := npcs_dir + fid + ".png"
		var front_path := npcs_dir + fid + "_front.png"
		var g_sheet := ProjectSettings.globalize_path(sheet_path)
		var g_front := ProjectSettings.globalize_path(front_path)

		var sheet_exists: bool = FileAccess.file_exists(g_sheet) or FileAccess.file_exists(sheet_path)
		var front_exists: bool = FileAccess.file_exists(g_front) or FileAccess.file_exists(front_path)
		assert(sheet_exists, "%s 시트 파일이 디스크에 생성되어야 합니다." % fid)
		assert(front_exists, "%s 프론트 파일이 디스크에 생성되어야 합니다." % fid)

		# 텍스처 로드 및 규격 검증 (96x192 시트, 48x48 프론트)
		var tex: Texture2D = SpriteCacheManager.get_npc_texture(fid)
		assert(tex != null, "%s 텍스처 로드 성공해야 함" % fid)
		assert(tex.get_width() == 96 and tex.get_height() == 192, "%s 시트 규격은 96x192여야 합니다 (실제: %dx%d)" % [fid, tex.get_width(), tex.get_height()])
		print("[TEST SUCCESS] %s 48x48 아이소메트릭 시트 검증 통과 (96x192)" % fid)

	# 3. NpcSprites 매핑 검증
	var kinds_to_check: Dictionary = {
		"fisher": "npc_fisherman",
		"fisherman": "npc_fisherman",
		"jeongisu": "npc_jeongisu",
		"kite_flyer": "npc_kite_flyer",
		"kites": "npc_kite_flyer",
		"ssireum": "npc_ssireum",
		"taekkyeon": "npc_taekkyeon"
	}
	for k: String in kinds_to_check.keys():
		assert(NpcSprites.KIND_TO_GENERIC_48.has(k), "NpcSprites에 %s 매핑이 존재해야 합니다." % k)
		assert(NpcSprites.KIND_TO_GENERIC_48[k] == kinds_to_check[k], "%s 매핑 대상이 %s 여야 합니다." % [k, kinds_to_check[k]])
		print("[TEST SUCCESS] NpcSprites '%s' -> '%s' 매핑 검증 완료" % [k, kinds_to_check[k]])

	print("=== 세시풍속 5종 도트 캐릭터 검증 전체 통과 (ALL PASS) ===")
	quit(0)
