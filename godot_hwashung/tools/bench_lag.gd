extends SceneTree
## [디버그] 저장본을 불러와 렉이 나는 지점을 잰다(저장 파일은 읽기만).
##   Godot --path . --script res://tools/bench_lag.gd -- <저장 파일 경로>
## 화면 이동 · 계절 전환 · 칸 하나 바뀜(건설) · 턴 진행 때 프레임 시간(평균/최대 ms)을 출력한다.

var _last_us: int = 0

func _init() -> void:
	call_deferred("_run")

func _wait(n: int) -> void:
	for i in range(n):
		await process_frame

## n프레임 동안 프레임 간격을 재서 [평균, 최대, 50ms 넘은 횟수]
func _measure(n: int, step: Callable = Callable()) -> Array:
	var times: Array[float] = []
	_last_us = Time.get_ticks_usec()
	for i in range(n):
		if step.is_valid():
			step.call(i)
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append(float(now - _last_us) / 1000.0)
		if float(now - _last_us) / 1000.0 > 50.0 and OS.get_environment("BENCH_DETAIL") != "":
			print("BENCH     spike frame ", i, " total_ms=", float(now - _last_us) / 1000.0, " process_ms=", snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.1), " physics_ms=", snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.1), " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		_last_us = now
	var s: float = 0.0
	var mx: float = 0.0
	var spikes: int = 0
	for t: float in times:
		s += t
		mx = maxf(mx, t)
		if t > 50.0:
			spikes += 1
	return [snappedf(s / float(n), 0.1), snappedf(mx, 0.1), spikes]

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(10)
	if main.intro_layer:
		main.intro_layer.intro_finished.emit()
		main._on_intro_finished()
	await _wait(5)
	main._on_start_new_game()
	await _wait(30)
	var t0: int = Time.get_ticks_msec()
	if args.size() > 0:
		if not SaveSystem.load_game_from_path(args[0], main.simulation_core, main.grid, main.time_manager, main.quests):
			print("load failed")
			quit(1)
			return
		main.on_game_loaded()
	main.time_manager.set_speed(TimeManager.SpeedMode.PAUSE)
	print("BENCH load_call_ms ", Time.get_ticks_msec() - t0)
	print("BENCH after_load ", await _measure(240))
	var g: GameGrid = main.grid
	var city: CityLayer = main.city
	var baker: CityLayer = main.baker
	print("BENCH grid_size ", g.size)

	# 가운데로 카메라
	var cen := Vector2(g.size * 0.5, g.size * 0.5)
	main.camera.zoom = Vector2(1.0, 1.0)
	main.camera.global_position = city.cell_center(cen.x, cen.y, 1.0) + city.global_position
	await _wait(30)
	print("BENCH idle_zoom1 ", await _measure(120))

	# 화면 이동(카메라 패닝)
	var start: Vector2 = main.camera.global_position
	print("BENCH pan_zoom1 ", await _measure(180, func(i: int): main.camera.global_position = start + Vector2(i * 12.0, i * 4.0)))
	main.camera.zoom = Vector2(0.5, 0.5)
	await _wait(30)
	print("BENCH pan_zoom05 ", await _measure(180, func(i: int): main.camera.global_position = start + Vector2(-i * 20.0, i * 6.0)))
	main.camera.zoom = Vector2(1.0, 1.0)
	main.camera.global_position = start
	await _wait(30)

	# 함수별 비용
	var us: int = Time.get_ticks_usec()
	baker._update_vertex_colors()
	print("BENCH update_vertex_colors_ms ", (Time.get_ticks_usec() - us) / 1000.0)
	us = Time.get_ticks_usec()
	baker._update_depth_sort()
	print("BENCH update_depth_sort_ms ", (Time.get_ticks_usec() - us) / 1000.0)
	us = Time.get_ticks_usec()
	baker.prepare_bands()
	print("BENCH prepare_bands_ms ", (Time.get_ticks_usec() - us) / 1000.0)

	# 칸 하나 둘레만 꼭짓점 색 다시 계산(건설 때)
	us = Time.get_ticks_usec()
	baker.update_vertex_colors_around([Vector2i(int(cen.x), int(cen.y))])
	print("BENCH update_vertex_colors_around_ms ", (Time.get_ticks_usec() - us) / 1000.0)
	us = Time.get_ticks_usec()
	for ty: int in range(g.size):
		for tx: int in range(g.size):
			baker._get_tile_base_ground_color(tx, ty)
	print("BENCH base_ground_color_all_ms ", (Time.get_ticks_usec() - us) / 1000.0)
	us = Time.get_ticks_usec()
	for ty: int in range(g.size):
		for tx: int in range(g.size):
			var _h: int = g.grid[ty][tx].hash()
	print("BENCH tile_hash_all_ms ", (Time.get_ticks_usec() - us) / 1000.0)

	# 지도 전체 띠를 한 프레임에 다시 그릴 때(그리기 비용)
	var redraw_all := func(_i: int) -> void:
		if _i == 0:
			for band: CityLayer in main.bake_bands:
				if band != null:
					band.queue_redraw()
			for ch in main._chunks:
				(ch["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
	print("BENCH redraw_all_bands ", await _measure(20, redraw_all))
	us = Time.get_ticks_usec()
	main._do_rebake_world()
	print("BENCH do_rebake_world_nochange_ms ", (Time.get_ticks_usec() - us) / 1000.0)
	await _wait(30)

	# 계절 전환
	print("BENCH season_change ", await _measure(120, func(i: int): if i == 0: main.time_manager.season_changed.emit("가을")))
	var sw := 0
	main.time_manager.season_changed.emit("겨울")
	while main._season_swap:
		sw += 1
		await process_frame
	print("BENCH season_swap_frames ", sw)
	await _wait(30)

	# 칸 하나 바뀜: 단계별 시간
	await _wait(60)
	var cc := Vector2i(int(cen.x) + 2, int(cen.y) + 1)
	g.grid[cc.y][cc.x]["surface"] = "dirt" if g.grid[cc.y][cc.x].get("surface", "grass") != "dirt" else "grass"
	us = Time.get_ticks_usec()
	for conn: Dictionary in g.grid_changed.get_connections():
		var u2: int = Time.get_ticks_usec()
		var cb: Callable = conn["callable"]
		if cb.get_object() == main and cb.get_method() == "_rebake_world":
			continue
		cb.call()
		if (Time.get_ticks_usec() - u2) > 1000: print("BENCH   listener ", cb.get_object().get_class() if cb.get_object() else "?", " ", cb.get_object().get_script().resource_path.get_file() if cb.get_object() and cb.get_object().get_script() else "", " ", cb.get_method(), " ms=", (Time.get_ticks_usec() - u2) / 1000.0)
	print("BENCH grid_changed_listeners_ms ", (Time.get_ticks_usec() - us) / 1000.0)
	us = Time.get_ticks_usec()
	main._do_rebake_world()
	print("BENCH do_rebake_world_after_change_ms ", (Time.get_ticks_usec() - us) / 1000.0)
	print("BENCH after_change_frames ", await _measure(60))

	# 칸 하나 바뀜(건설과 같은 경로: grid_changed → 다시 굽기)
	print("BENCH tile_change ", await _measure(90, func(i: int):
		if i == 0:
			var c := Vector2i(int(cen.x), int(cen.y))
			g.grid[c.y][c.x]["surface"] = "dirt" if g.grid[c.y][c.x].get("surface", "grass") != "dirt" else "grass"
			g.grid_changed.emit()
			main._rebake_world()))

	# 턴 진행(보통 속도)
	main.time_manager.set_speed(TimeManager.SpeedMode.NORMAL)
	print("BENCH play_normal ", await _measure(600))
	main.time_manager.set_speed(TimeManager.SpeedMode.PAUSE)
	# 근대화 모드(저장 없이 상태만): 근대 그림 교체 비용
	var mm: ModernizationManager = ModernizationManager.instance
	var um: UrbanEvolutionManager = UrbanEvolutionManager.instance
	if mm and um:
		mm.active = true
		um.stone_ratio = 1.0
		um.metro_ratio = 0.3
		us = Time.get_ticks_usec()
		um.apply_modern_tiles()
		print("BENCH modern_apply_first_ms ", (Time.get_ticks_usec() - us) / 1000.0)
		print("BENCH modern_apply_frames ", await _measure(240))
		us = Time.get_ticks_usec()
		um.apply_modern_tiles()
		print("BENCH modern_apply_nochange_ms ", (Time.get_ticks_usec() - us) / 1000.0)
		us = Time.get_ticks_usec()
		um._on_turn(1, 0, 1821)
		print("BENCH modern_on_turn_ms ", (Time.get_ticks_usec() - us) / 1000.0)
		main.time_manager.set_speed(TimeManager.SpeedMode.NORMAL)
		print("BENCH modern_play_normal ", await _measure(600))
		main.time_manager.set_speed(TimeManager.SpeedMode.PAUSE)
	print("BENCH total_s ", (Time.get_ticks_msec() - t0) / 1000.0)
	quit(0)
