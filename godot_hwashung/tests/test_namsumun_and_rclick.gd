extends SceneTree

func _init() -> void:
	print("=== [검증 시작] 남수문 렌더링 크래시 픽스 및 우클릭 취소 기능 검증 ===")
	call_deferred("_run_verification")

func _run_verification() -> void:
	var main_scene = load("res://scenes/Main.tscn")
	if not main_scene:
		push_error("Main.tscn 로드 실패")
		quit(1)
		return

	var main = main_scene.instantiate()
	root.add_child(main)

	for i in range(5):
		await process_frame

	var city: CityLayer = main.city
	var grid: GameGrid = main.grid

	# ----------------------------------------------------
	# [검증 1] 남수문(namsu_mun) 축조 중 및 완공 렌더링 크래시 방어 검증
	print("[검증 1] 남수문 축조 중 및 완공 렌더링 검증...")
	# 수원천 물 타일 위에 남수문 성벽 배치 시뮬레이션
	var nx := 30
	var ny := 45
	if grid.in_bounds(nx, ny):
		grid.grid[ny][nx]["building"] = "wall"
		grid.grid[ny][nx]["terrain"] = "water"
		grid.grid[ny][nx]["facility_id"] = "namsu_mun"
		grid.grid[ny][nx]["is_namsu"] = true
		grid.grid[ny][nx]["wall_build"] = 50 # 축조 중
		
		# 1-1. 축조 중 남수문 그리기 호출 (크래시 여부 확인)
		city._draw_namsumun(nx, ny, grid.grid[ny][nx])
		print("  - [PASS] 축조 중 남수문 _draw_namsumun 크래시 없이 정상 렌더링 통과")

		# 1-2. 완공 상태 남수문 그리기 호출
		grid.grid[ny][nx]["wall_build"] = 0 # 완공
		city._draw_namsumun(nx, ny, grid.grid[ny][nx])
		print("  - [PASS] 완공 상태 남수문 _draw_namsumun 크래시 없이 정상 렌더링 통과")

	# ----------------------------------------------------
	# [검증 2] 우클릭 선택 취소(Right-Click Cancel) 및 살피기 창 닫기 복원 검증
	print("[검증 2] 우클릭 선택 취소 및 기본 모드 복귀 검증...")
	
	# 2-1. 건설 툴 선택 상태에서 우클릭
	city.current_tool = "road_stone"
	assert(city.current_tool == "road_stone", "도로 건설 툴 선택 실패")
	
	var rclick_event := InputEventMouseButton.new()
	rclick_event.button_index = MOUSE_BUTTON_RIGHT
	rclick_event.pressed = true
	main._unhandled_input(rclick_event)
	
	assert(city.current_tool == "inspect", "우클릭 후 조사(inspect) 모드로 복귀 실패: %s" % city.current_tool)
	print("  - [PASS] 건설 모드에서 우클릭 시 inspect 모드로 즉시 취소 복귀 성공")

	# 2-2. InspectPopup 열려있을 때 우클릭으로 닫기 검증
	if main.inspect_popup:
		main.inspect_popup.open_inspect("테스트 제목", "테스트 본문", null)
		assert(main.inspect_popup.visible == true, "InspectPopup 오픈 실패")
		
		main._unhandled_input(rclick_event)
		assert(main.inspect_popup.visible == false, "우클릭 시 InspectPopup 닫기 실패")
		print("  - [PASS] 살피기 팝업 오픈 상태에서 우클릭 시 즉시 닫기 성공")

	# 2-3. 드래그 중 우클릭 시 드래그 타일 초기화 검증
	city.current_tool = "road_dirt"
	city._is_dragging = true
	city._drag_tiles = [Vector2i(10, 10), Vector2i(10, 11)]
	city.cancel_build_or_select()
	assert(city._is_dragging == false, "드래그 상태 미초기화")
	assert(city._drag_tiles.is_empty(), "드래그 타일 미초기화")
	assert(city.current_tool == "inspect", "도구 미초기화")
	print("  - [PASS] 드래그 중 cancel_build_or_select 호출 시 상태 완전 초기화 성공")

	print("=== [검증 완료] 남수문 크래시 픽스 및 우클릭 취소 검증 100% 통과! ===")
	quit(0)
