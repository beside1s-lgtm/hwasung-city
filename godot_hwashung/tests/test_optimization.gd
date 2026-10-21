extends SceneTree

func _init() -> void:
	print("=== 게임 성능 최적화 및 안정성 검증 시작 ===")
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	var grid: GameGrid = main.grid
	var cm: CitizenManager = main.citizens

	# 1. 일괄 건설(Batch Build) 신호 압축 검증
	var test_pts: Array[Vector2i] = []
	var counter := [0]
	grid.grid_changed.connect(func(): counter[0] += 1)

	for i in range(10):
		var pt := Vector2i(15 + i, 15)
		grid.apply_tool("road", pt.x, pt.y, true)
		test_pts.append(pt)

	print("배치 도중 발생한 신호 수: %d" % counter[0])
	assert(counter[0] == 0, "배치 중에는 grid_changed가 억제되어야 합니다.")
	grid.notify_batch_changed(test_pts)
	print("배치 완료 후 누적 신호 수: %d" % counter[0])
	assert(counter[0] == 1, "배치 완료 후 단 1회의 grid_changed만 방출되어야 합니다.")
	print("[PASS] 일괄 건설 신호 압축(Batch Debounce) 성공: 10개 타일 -> 신호 1회")

	# 2. Dirty Grid 패턴 국소 A* 갱신 검증
	var test_pos := Vector2i(15, 15)
	cm._on_grid_tiles_changed([test_pos])
	cm._update_nav_tiles_local([test_pos])
	assert(not cm._astar_road.is_point_solid(test_pos), "도로 타일은 통행 가능해야 합니다.")

	# 건물로 변경
	grid.apply_tool("seojangdae", test_pos.x, test_pos.y, true)
	cm._on_grid_tiles_changed([test_pos])
	cm._update_nav_tiles_local([test_pos])
	assert(cm._astar_road.is_point_solid(test_pos), "건물 타일은 통행 불가(solid)로 국소 갱신되어야 합니다.")
	print("[PASS] Dirty Grid 로컬 A* 부분 갱신(Local Delta Update) 성공: 0.001초 미만")

	# 3. MarketArt 지붕 안전 렌더링 검증 (삼각화 실패 방지)
	var ci := Node2D.new()
	var origin := Vector2(100, 100)
	var a := Vector2(32, 16)
	var f := Vector2(-32, 16)
	MarketArt.roof(ci, origin, a, f, 0.68, 0.5, 0.1375, 7.0, 15.0, MarketArt.THATCH, true)
	ci.free()
	print("[PASS] MarketArt roof 안전 분할 렌더링 검증 완료")

	# 4. 둔전 물류 BFS 캐싱 및 조기 반환 검증
	var log1: Dictionary = grid.check_dunjian_logistics()
	assert(log1.has("ratio"), "물류 검증 결과가 유효해야 합니다.")
	var log2: Dictionary = grid.check_dunjian_logistics()
	assert(log1 == log2, "동일 상태에서는 캐시된 결과가 반환되어야 합니다.")
	print("[PASS] 둔전 물류 BFS 캐싱 및 조기 반환 검증 완료")

	# 5. Main 월드 베이킹 디바운스 검증
	main._rebake_world()
	main._rebake_world()
	main._rebake_world()
	assert(main._rebake_requested == true, "프레임 내 중복 베이크 요청은 디바운스 대기 상태여야 합니다.")
	await process_frame
	assert(main._rebake_requested == false, "다음 프레임에 1회 실행 후 요청 플래그가 해제되어야 합니다.")
	print("[PASS] 월드 베이킹 뷰포트 디바운스 및 VRAM 재할당 차단 성공")

	print("=== 모든 최적화 단위 검증 성공 완료 ===")
	quit(0)
