extends SceneTree
# 진단용(내보내기 제외: tests/_probe_*): 최저 세율에서 달마다 국고·유지비·체납 여부를 본다
# 실행: Godot --headless --path godot_hwashung -s res://tests/_probe_month_detail.gd

func _init() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	for i in range(5):
		await process_frame
	var sim: SimulationCore = main.simulation_core
	print("불러오기: ", main._load_from_title(0))
	main.time_manager.set_speed(TimeManager.SpeedMode.PAUSE)
	sim.tax_rate_land = 1
	sim.tax_rate_market = 1
	sim.tax_rate_military = 1
	sim.gold = 5000000
	for m in range(1, 13):
		var g0 := sim.gold
		main.time_manager.advance_months(1)
		for f in range(30):
			await process_frame
		var mr: Dictionary = sim.last_maintenance_result
		print("[%2d달] 인구 %7d | 국고 %9d (%+9d) | 유지비 %8d 체납 %s (못 낸 돈 %d)" % [m, sim.population, sim.gold, sim.gold - g0, int(mr.get("total_gold", -1)), str(mr.get("deficit_gold", "?")), int(mr.get("shortage_gold", 0))])
	for adv: Dictionary in main.tutorial._collect_affairs_advices():
		if String(adv.get("key", "")).begins_with("affair_finance"):
			print("(김판관 prio ", adv["prio"], ") [", adv["title"], "] ", String(adv["text"]).replace("
", " / "))
	quit()
