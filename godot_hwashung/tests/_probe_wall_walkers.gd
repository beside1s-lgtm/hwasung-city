extends SceneTree
# 진단용(내보내기 제외: tests/_probe_*): 자동 저장을 불러와 성곽 칸 위에 서 있는 민간인(군사 아닌 사람)을 센다
# 실행: Godot --headless --path godot_hwashung -s res://tests/_probe_wall_walkers.gd

const WALLISH := ["wall", "gate", "banghwasuryu", "poru", "gongsimdon", "gongsimdon_wall", "bongdon", "seojangdae"]

func _init() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	for i in range(5):
		await process_frame
	var cm: CitizenManager = main.citizens
	var grid: GameGrid = main.grid
	print("불러오기: ", main._load_from_title(0))
	var seen := {}
	for step in range(20):
		for f in range(30):
			await process_frame
		for a: Dictionary in cm.agents:
			var x := int(floor(float(a["x"])))
			var y := int(floor(float(a["y"])))
			if not grid.in_bounds(x, y):
				continue
			var b: String = str(grid.grid[y][x].get("building", ""))
			if b in WALLISH:
				var ty: String = str(a.get("type", ""))
				seen[ty + "@" + b] = int(seen.get(ty + "@" + b, 0)) + 1
	var keys := seen.keys()
	keys.sort_custom(func(p, q): return int(seen[p]) > int(seen[q]))
	print("성곽류 칸 위에서 본 사람(종류@칸, 20번 관측 누적):")
	for k in keys:
		print("  ", k, "  ", seen[k])
	quit()
