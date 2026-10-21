extends SceneTree

## [v8 48x48 도트 캐릭터 아키텍처 베이킹 및 파일 생성 검증 테스트]

const SpriteCacheManager = preload("res://scripts/autoload/SpriteCacheManager.gd")
const CharacterPixelArtist = preload("res://scripts/rendering/CharacterPixelArtist.gd")

func _init() -> void:
	print("=== v8 48x48 도트 캐릭터 베이킹 검증 시작 ===")

	# 1. v8 강제 베이킹 실행
	SpriteCacheManager.upgrade_procedural_pngs_v8_joseon_48x48_named26()

	# 2. 네임드 26인 파일 생성 확인
	var named_dir := "res://assets/sprites/npcs/named/"
	var named_global := ProjectSettings.globalize_path(named_dir)
	print("[TEST] 네임드 디렉토리 경로: ", named_global)

	var missing_named: Array[String] = []
	for nid: String in CharacterPixelArtist.NAMED_PRESETS.keys():
		var sheet_path := named_dir + nid + ".png"
		var front_path := named_dir + nid + "_front.png"
		var g_sheet := ProjectSettings.globalize_path(sheet_path)
		var g_front := ProjectSettings.globalize_path(front_path)

		if not FileAccess.file_exists(g_sheet) and not FileAccess.file_exists(sheet_path):
			missing_named.append(nid + ".png")
		if not FileAccess.file_exists(g_front) and not FileAccess.file_exists(front_path):
			missing_named.append(nid + "_front.png")

	if missing_named.is_empty():
		print("[TEST SUCCESS] 네임드 26인 전원 시트 및 프론트 PNG 정상 생성 완료! (총 %d개 캐릭터)" % CharacterPixelArtist.NAMED_PRESETS.size())
	else:
		printerr("[TEST FAIL] 누락된 네임드 파일: ", missing_named)
		quit(1)
		return

	# 3. 일반 백성 15종 및 행렬 5종 파일 생성 확인
	var npcs_dir := "res://assets/sprites/npcs/"
	var missing_generic: Array[String] = []
	for gid: String in CharacterPixelArtist.GENERIC_PRESETS.keys():
		var p := npcs_dir + gid + ".png"
		var gp := ProjectSettings.globalize_path(p)
		if not FileAccess.file_exists(gp) and not FileAccess.file_exists(p):
			missing_generic.append(gid + ".png")

	for pid: String in CharacterPixelArtist.PARADE_PRESETS.keys():
		var p := npcs_dir + pid + ".png"
		var gp := ProjectSettings.globalize_path(p)
		if not FileAccess.file_exists(gp) and not FileAccess.file_exists(p):
			missing_generic.append(pid + ".png")

	if missing_generic.is_empty():
		print("[TEST SUCCESS] 일반 백성 15종 및 을묘원행 5종 시트 PNG 정상 생성 완료!")
	else:
		printerr("[TEST FAIL] 누락된 일반/행렬 파일: ", missing_generic)
		quit(1)
		return

	# 4. 텍스처 로드 및 규격 검증 (정조 및 채제공)
	var jeongjo_tex: Texture2D = SpriteCacheManager.get_named_character_texture("named_jeongjo")
	if jeongjo_tex != null:
		print("[TEST SUCCESS] 정조 대왕 시트 텍스처 로드 성공! 크기: ", jeongjo_tex.get_width(), "x", jeongjo_tex.get_height())
		assert(jeongjo_tex.get_width() == 96 and jeongjo_tex.get_height() == 192, "시트 규격은 96x192여야 합니다.")
	else:
		printerr("[TEST FAIL] 정조 대왕 텍스처 로드 실패")
		quit(1)
		return

	var front_tex: Texture2D = SpriteCacheManager.get_named_character_texture("named_chae_jegong", true)
	if front_tex != null:
		print("[TEST SUCCESS] 채제공 정면 텍스처 로드 성공! 크기: ", front_tex.get_width(), "x", front_tex.get_height())
		assert(front_tex.get_width() == 48 and front_tex.get_height() == 48, "정면 규격은 48x48이어야 합니다.")
	else:
		printerr("[TEST FAIL] 채제공 정면 텍스처 로드 실패")
		quit(1)
		return

	print("=== v8 48x48 도트 캐릭터 검증 전체 통과 (ALL PASS) ===")
	quit(0)
