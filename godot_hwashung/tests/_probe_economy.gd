extends SceneTree
# 진단용(내보내기 제외: tests/_probe_*): slot_3(1801)을 불러와 방치하듯 달을 넘기며 국고·유지비·녹봉·등용 인원을 추적
# 실행: Godot --headless --path godot_hwashung -s res://tests/_probe_economy.gd

const FMM = preload("res://scripts/FacilityMaintenanceManager.gd")

func _hired(sim: SimulationCore) -> int:
	var n := 0
	for k in sim.retainers.keys():
		if bool(sim.retainers[k]):
			n += 1
	return n

func _init() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	for i in range(5):
		await process_frame
	var sim: SimulationCore = main.simulation_core
	var court: CourtSystem = main.court
	var grid: GameGrid = main.grid
	court.notice.connect(func(m: String):
		if m.contains("사직"):
			print("    (알림) ", m))
	sim.disaster_alert.connect(func(m: String):
		if m.contains("재정"):
			print("    (경보) ", m))
	print("불러오기: ", main._load_from_title(3), "  ", sim.current_year, "년 turn ", sim.turn)
	for m in range(1, 61):
		var g0 := sim.gold
		var up: Dictionary = FMM.calculate_turn_maintenance(grid, sim.population)
		main.turns._on_turn(sim.turn + 1, (m / 3) % 4, sim.current_year)
		for f in range(40):
			await process_frame
		if m <= 3 or m % 6 == 0 or _hired(sim) < 20:
			print("[%2d달] 국고 %10d (%+9d) | 유지비 %8d (배율 %.1f) | 녹봉 %6d | 인구 %8d | 등용 %d" % [m, sim.gold, sim.gold - g0, int(up["total_gold"]), float(up["multiplier"]), court.total_salary(), sim.population, _hired(sim)])
		if _hired(sim) == 0:
			print("→ 등용 인원 0명, 멈춤")
			break
	quit()
