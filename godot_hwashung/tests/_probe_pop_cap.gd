extends SceneTree
# 진단용(내보내기 제외: tests/_probe_*): 자동 저장(인구 142만)을 불러와 인구 상한·국고 변화·김판관 재정 조언을 확인
# 실행: Godot --headless --path godot_hwashung -s res://tests/_probe_pop_cap.gd

func _run(main: Node, label: String, tax: int, months: int) -> void:
	var sim: SimulationCore = main.simulation_core
	sim.tax_rate_land = tax
	sim.tax_rate_market = tax
	sim.tax_rate_military = tax
	print("== ", label, " (세율 합 ", tax * 3, "%)")
	for m in range(1, months + 1):
		main.time_manager.advance_months(1) # 실제 시계: 월 예산·계절 인구·턴이 모두 돈다
		for f in range(40):
			await process_frame
		var pc: Dictionary = sim.pop_manager.last_pop_cap
		if true:
			print("  [%2d달] 인구 %8d | 상한 %8d (세율 %7d · 생산력 %7d)%s | 국고 %9d (%+8d/달)" % [m, sim.population, int(pc.get("cap", 0)), int(pc.get("tax_cap", 0)), int(pc.get("prod_cap", 0)), " 한계" if bool(pc.get("at_cap", false)) else "", sim.gold, sim.last_month_gold_delta])
	for adv: Dictionary in main.tutorial._collect_affairs_advices():
		var k := String(adv.get("key", ""))
		if k.begins_with("affair_finance") or k.begins_with("affair_pop_cap"):
			print("  (김판관) [", adv["title"], "] ", String(adv["text"]).replace("\n", " / "))

func _init() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	for i in range(5):
		await process_frame
	print("불러오기: ", main._load_from_title(0), "  인구 ", main.simulation_core.population)
	main.time_manager.set_speed(TimeManager.SpeedMode.PAUSE) # 실시간 시계는 멈추고 advance_months로만 진행
	await _run(main, "자동 저장 그대로 1%씩", 1, 12)
	await _run(main, "2%씩으로 올림", 2, 12)
	quit()
