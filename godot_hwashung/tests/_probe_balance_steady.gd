extends SceneTree
# 진단용(내보내기 제외: tests/_probe_*): 세율별로 인구가 상한에 자리 잡은 뒤 1년 동안의 국고 수지를 잰다
# 실행: Godot --headless --path godot_hwashung -s res://tests/_probe_balance_steady.gd

func _months(main: Node, n: int) -> void:
	for m in range(n):
		main.time_manager.advance_months(1)
		for f in range(30):
			await process_frame

func _init() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	for i in range(5):
		await process_frame
	var sim: SimulationCore = main.simulation_core
	print("불러오기: ", main._load_from_title(0), "  인구 ", sim.population)
	main.time_manager.set_speed(TimeManager.SpeedMode.PAUSE)
	for t: int in [1, 2, 3]:
		sim.gold = 50000000
		sim.tax_rate_land = t
		sim.tax_rate_market = t
		sim.tax_rate_military = t
		sim.gold = maxi(sim.gold, 5000000) # 측정 중 국고가 바닥나 벌칙이 끼지 않게
		var settled := 0
		for k in range(16): # 석 달씩, 최대 4년
			await _months(main, 3)
			settled += 3
			var cap: int = int(sim.pop_manager.last_pop_cap.get("cap", 0))
			if cap > 0 and absi(sim.population - cap) <= cap / 50:
				break
		# 국고를 늘 넉넉히 채워 둔 채(체납이 끼지 않게) 달마다 변화를 더한다 = 진짜 수지
		var total := 0
		for mm in range(12):
			sim.gold = 50000000
			var gm := sim.gold
			await _months(main, 1)
			total += sim.gold - gm
		var g0 := sim.gold - total
		var pc: Dictionary = sim.pop_manager.last_pop_cap
		print("세율 합 %2d%% | %2d달 뒤 자리 잡음 | 인구 %7d (상한 %7d: 세율 %7d · 생산력 %7d) | 1년 국고 %+10d (달 평균 %+8d)" % [t * 3, settled, sim.population, int(pc.get("cap", 0)), int(pc.get("tax_cap", 0)), int(pc.get("prod_cap", 0)), sim.gold - g0, (sim.gold - g0) / 12])
		for adv: Dictionary in main.tutorial._collect_affairs_advices():
			if String(adv.get("key", "")).begins_with("affair_finance"):
				print("    (김판관) ", String(adv["text"]).split("\n")[0], " / ", String(adv["text"]).split("\n")[1])
	quit()
