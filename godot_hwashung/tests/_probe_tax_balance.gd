extends SceneTree
# 진단용(내보내기 제외: tests/_probe_*): 인구·세율 조합마다 한 달 수입과 유지비를 재어 균형점을 찾는다
# 실행: Godot --headless --path godot_hwashung -s res://tests/_probe_tax_balance.gd

const FMM = preload("res://scripts/FacilityMaintenanceManager.gd")

func _init() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	for i in range(5):
		await process_frame
	var sim: SimulationCore = main.simulation_core
	var grid: GameGrid = main.grid
	print("불러오기: ", main._load_from_title(3))
	var base_rice := sim.rice
	print("세율합 | 인구      | 한 달 국고 변화 | 유지비(행궁 포함) | 녹봉")
	for pop: int in [300000, 500000, 700000, 1000000]:
		for t: int in [1, 2, 3, 5]:
			sim.tax_rate_land = t
			sim.tax_rate_market = t
			sim.tax_rate_military = t
			sim.population = pop
			sim.pop_manager.total_population = pop
			sim.rice = base_rice
			sim.gold = 50000000
			sim.loyalty = 90
			var up: Dictionary = FMM.calculate_turn_maintenance(grid, pop)
			var g0 := sim.gold
			main.turns._on_turn(sim.turn + 1, 1, sim.current_year)
			for f in range(40):
				await process_frame
			print("%4d%% | %9d | %+14d | %16d | %5d" % [t * 3, pop, sim.gold - g0, int(up["total_gold"]), main.court.total_salary()])
	quit()
