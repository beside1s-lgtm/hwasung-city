extends SceneTree
## [디버그] 새 게임을 시작해 계절마다 지도 화면을 찍는다.
##   Godot --path . --script res://tools/capture_terrain.gd -- <저장폴더> [줌]

func _init() -> void:
	call_deferred("_run")

func _wait(n: int) -> void:
	for i in range(n):
		await process_frame

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var zoom: float = float(args[1]) if args.size() > 1 else 2.0
	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(10)
	if main.intro_layer:
		main.intro_layer.intro_finished.emit()
		main._on_intro_finished()
	await _wait(5)
	main._on_start_new_game()
	await _wait(180)
	for n: Node in root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false  # UI 가리기
	main.camera.zoom = Vector2(zoom, zoom)
	if OS.get_environment("CAPTURE_FARM") != "":  # 화면 가운데에 논(agr 구역) 8x8을 깔아 본다
		var cc: Vector2i = main.city.world_to_cell(main.city.get_global_transform_with_canvas().affine_inverse() * Vector2(root.get_viewport().get_visible_rect().size * 0.5))
		for fy: int in range(cc.y - 4, cc.y + 4):
			for fx: int in range(cc.x - 4, cc.x + 4):
				if main.city.grid.in_bounds(fx, fy) and main.city.grid.grid[fy][fx].get("terrain", "") != "water":
					main.city.grid.grid[fy][fx]["zone"] = "agr"
					main.city.grid.grid[fy][fx]["building"] = ""
	if OS.get_environment("CAPTURE_LOAD_SUMMER") != "":  # 세이브 불러오기처럼: 계절 전환 신호 없이 여름으로 바꾸고 지도만 다시 굽기
		main.city.current_season = "여름"
		main._rebake_world()
		await _wait(30)
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("load_summer.png"))
		print("captured load_summer")
		quit(0)
		return
	var t0: int = Time.get_ticks_msec()
	for s: String in ["봄", "여름", "가을", "겨울"]:
		main.city.current_season = s
		main._apply_seasonal_terrain_globally(s)
		var mid_saved := false
		while main._season_swap: # 띠를 나눠 그리는 동안(화면은 이전 계절 그대로여야 함)
			await process_frame
			if not mid_saved and OS.get_environment("CAPTURE_MID") != "":
				mid_saved = true
				await _wait(10)
				root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("mid_%s.png" % s))
		await _wait(30)
		var img: Image = root.get_viewport().get_texture().get_image()
		img.save_png(out_dir.path_join("season_%s.png" % s))
		print("captured ", s, " fps=", Engine.get_frames_per_second())
	if args.size() > 2:  # 화면 좌표의 칸 정보: x,y;x,y...
		var xf: Transform2D = main.city.get_global_transform_with_canvas().affine_inverse()
		for pair: String in args[2].split(";"):
			var sp: PackedStringArray = pair.split(",")
			var cell: Vector2i = main.city.world_to_cell(xf * Vector2(float(sp[0]), float(sp[1])))
			if main.city.grid.in_bounds(cell.x, cell.y):
				var t: Dictionary = main.city.grid.grid[cell.y][cell.x]
				print(pair, " ", cell, " surf=", t.get("surface", ""), " terr=", t.get("terrain", ""), " zone=", t.get("zone", ""), " b=", t.get("building", ""), " elev=", t.get("elevation", 0))
	print("total ms ", Time.get_ticks_msec() - t0)
	quit(0)
