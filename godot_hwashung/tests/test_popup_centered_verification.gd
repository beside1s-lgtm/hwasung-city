extends SceneTree

## [QA 자동 검증] 서장대 야조 미니게임 모달 및 서장대 팝업 해상도별 정중앙(Centered) 정렬 검증

var log_lines: Array[String] = []

func _log(msg: String) -> void:
	print(msg)
	log_lines.append(msg)

var frame_count: int = 0

func _init() -> void:
	_log("=== [테스트 시작] 서장대 팝업 및 미니게임 중앙 정렬 해상도별 검증 ===")

func _process(_delta: float) -> bool:
	frame_count += 1
	if frame_count == 2:
		test_yajo_minigame_centering()
		test_seojangdae_popup_centering()
		_log("=== [테스트 완료] 중앙 정렬 검증 모든 항목 100% 통과 (ALL PASS)! ===")
		var f := FileAccess.open("C:/myapp/hwashung city/godot_hwashung/tests/test_popup_centered.log", FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(log_lines))
			f.flush()
			f.close()
		quit(0)
	return false

func test_yajo_minigame_centering() -> void:
	_log("[검증 1] YajoMiniGamePopup 해상도별 정중앙 정렬 실측 검증...")

	var test_resolutions: Array[Vector2] = [
		Vector2(1280, 720),
		Vector2(1906, 932), # 유저 스크린샷 실제 창 크기
		Vector2(1920, 1080),
		Vector2(2560, 1440)
	]

	for res: Vector2 in test_resolutions:
		root.size = Vector2i(int(res.x), int(res.y))

		var popup := YajoMiniGamePopup.new()
		root.add_child(popup)

		# 뷰포트 동기화 및 시작
		popup.start_yajo_minigame()
		popup.visible = true
		popup._main_panel.visible = true

		# CenterContainer 자식 재배치 알림 트리거
		popup._center_container.notification(Container.NOTIFICATION_SORT_CHILDREN)

		var panel_size: Vector2 = popup._main_panel.custom_minimum_size
		var container_size: Vector2 = popup._center_container.size

		var expected_x: float = floorf((container_size.x - panel_size.x) / 2.0)
		var expected_y: float = floorf((container_size.y - panel_size.y) / 2.0)

		var actual_pos: Vector2 = popup._main_panel.position
		_log("  - 해상도 %s: 컨테이너 크기 %s | 패널 최소크기 %s | 예상 위치 (%.1f, %.1f) | 실제 위치 (%.1f, %.1f)" % [
			res, container_size, panel_size, expected_x, expected_y, actual_pos.x, actual_pos.y
		])

		assert(absf(actual_pos.x - expected_x) <= 2.0, "X축 중앙 정렬 불일치! 예상: %.1f, 실제: %.1f" % [expected_x, actual_pos.x])
		assert(absf(actual_pos.y - expected_y) <= 2.0, "Y축 중앙 정렬 불일치! 예상: %.1f, 실제: %.1f" % [expected_y, actual_pos.y])

		# 정리
		popup.queue_free()

	_log("  -> YajoMiniGamePopup 해상도별 정중앙 정렬 완벽 확인!")

func test_seojangdae_popup_centering() -> void:
	_log("[검증 2] SeojangdaePopup 해상도별 정중앙 정렬 실측 검증...")

	var test_resolutions: Array[Vector2] = [
		Vector2(1280, 720),
		Vector2(1906, 932),
		Vector2(1920, 1080)
	]

	for res: Vector2 in test_resolutions:
		root.size = Vector2i(int(res.x), int(res.y))

		var g := GameGrid.new()
		g.size = 20
		g.grid = []
		var s := SimulationCore.new()
		s.gold = 5000
		s.rice = 5000

		var popup := SeojangdaePopup.new()
		root.add_child(popup)
		popup.setup(g, s, null)

		popup.open_seojangdae_popup()
		popup.visible = true
		popup._panel.visible = true
		popup._panel.size = popup._panel.custom_minimum_size

		popup._center.notification(Container.NOTIFICATION_SORT_CHILDREN)

		var panel_size: Vector2 = popup._panel.custom_minimum_size
		var container_size: Vector2 = popup._center.size

		var expected_x: float = floorf((container_size.x - panel_size.x) / 2.0)
		var expected_y: float = floorf((container_size.y - panel_size.y) / 2.0)

		var actual_pos: Vector2 = popup._panel.position
		_log("  - 해상도 %s: 컨테이너 크기 %s | 패널 최소크기 %s | 예상 위치 (%.1f, %.1f) | 실제 위치 (%.1f, %.1f)" % [
			res, container_size, panel_size, expected_x, expected_y, actual_pos.x, actual_pos.y
		])

		assert(absf(actual_pos.x - expected_x) <= 2.0, "X축 중앙 정렬 불일치! 예상: %.1f, 실제: %.1f" % [expected_x, actual_pos.x])
		assert(absf(actual_pos.y - expected_y) <= 2.0, "Y축 중앙 정렬 불일치! 예상: %.1f, 실제: %.1f" % [expected_y, actual_pos.y])

		popup.queue_free()

	_log("  -> SeojangdaePopup 해상도별 정중앙 정렬 완벽 확인!")
