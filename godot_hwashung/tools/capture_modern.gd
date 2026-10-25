extends SceneTree
## [디버그] 저장본을 불러와 근대화 전 · 석조 전환 100% · 대도시화 60% 화면을 찍는다.
##   Godot --path . --script res://tools/capture_modern.gd -- <저장 파일 경로> <저장폴더> [줌]
## 저장 파일은 읽기만 한다(근대화는 저장 없이 상태만 켜서 찍는다).

func _init() -> void:
	call_deferred("_run")

func _wait(n: int) -> void:
	for i in range(n):
		await process_frame

func _shot(path: String) -> void:
	await _wait(300) # 분할 재굽기(프레임당 정해진 칸 수)가 지도 전체를 다 그릴 때까지
	root.get_viewport().get_texture().get_image().save_png(path)
	print("captured ", path)

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var save_path: String = args[0]
	var out_dir: String = args[1]
	var zoom: float = float(args[2]) if args.size() > 2 else 1.6
	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(10)
	if main.intro_layer:
		main.intro_layer.intro_finished.emit()
		main._on_intro_finished()
	await _wait(5)
	main._on_start_new_game()
	await _wait(30)
	if not SaveSystem.load_game_from_path(save_path, main.simulation_core, main.grid, main.time_manager, main.quests):
		print("load failed")
		quit(1)
		return
	main.on_game_loaded()
	main.time_manager.set_speed(TimeManager.SpeedMode.PAUSE)
	await _wait(60)
	# 가옥·상점·공방이 가장 많은 곳으로 카메라
	var g: GameGrid = main.grid
	var sum := Vector2.ZERO
	var n := 0
	var counts := {"res": 0, "com": 0, "ind": 0}
	for y in range(g.size):
		for x in range(g.size):
			var b: String = String(g.grid[y][x].get("building", ""))
			for k in counts:
				if b.begins_with(k + "_"):
					counts[k] += 1
					sum += Vector2(x, y)
					n += 1
	print("buildings ", counts)
	var cen := sum / maxf(1.0, float(n))
	main.camera.zoom = Vector2(zoom, zoom)
	main.camera.global_position = main.city.cell_center(cen.x, cen.y, 1.0) + main.city.global_position
	for cl: Node in root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	await _shot(out_dir.path_join("modern_0_before.png"))

	var mm: ModernizationManager = ModernizationManager.instance
	var um: UrbanEvolutionManager = UrbanEvolutionManager.instance
	mm.active = true
	um.stone_ratio = 1.0
	um.metro_ratio = 0.0
	um.apply_modern_tiles()
	var mod := 0
	for y in range(g.size):
		for x in range(g.size):
			if g.grid[y][x].has("modern_id"):
				mod += 1
	print("stone tiles ", mod)
	await _shot(out_dir.path_join("modern_1_stone.png"))

	um.metro_ratio = 0.6
	um.apply_modern_tiles()
	var metro := {}
	for y in range(g.size):
		for x in range(g.size):
			var id := String(g.grid[y][x].get("modern_id", ""))
			if id != "":
				metro[id] = int(metro.get(id, 0)) + 1
	print("metro sprites ", metro)
	await _shot(out_dir.path_join("modern_2_metro.png"))
	quit(0)
