extends SceneTree

func _init() -> void:
	print("--- GameSettings 단위 테스트 시작 ---")
	GameSettings.ensure_loaded()

	# 1. 초기값 및 토글 테스트
	var old_fs := GameSettings.is_fullscreen()
	GameSettings.toggle_fullscreen()
	assert(GameSettings.is_fullscreen() != old_fs, "fullscreen 토글 실패")
	GameSettings.set_fullscreen(old_fs) # 복원

	var old_judge := GameSettings.is_judge_advice_enabled()
	GameSettings.toggle_judge_advice()
	assert(GameSettings.is_judge_advice_enabled() != old_judge, "judge advice 토글 실패")
	GameSettings.set_judge_advice_enabled(old_judge)

	# 2. 스크립트 정상 로드 검사
	var scripts := [
		"res://scripts/GameSettings.gd",
		"res://scripts/Main.gd",
		"res://scripts/TitleScreenLayer.gd",
		"res://scripts/PanelController.gd",
		"res://scripts/TutorialGuide.gd",
		"res://scripts/DisasterPopup.gd",
		"res://scripts/TopAlertBanner.gd",
		"res://scripts/HUDController.gd",
		"res://scripts/EventManager.gd"
	]
	for s_path in scripts:
		var res = load(s_path)
		assert(res != null, "스크립트 로드 실패: " + s_path)

	print("[테스트 성공] 모든 설정 로직 및 스크립트 무결성 검증 완료!")
	quit(0)
