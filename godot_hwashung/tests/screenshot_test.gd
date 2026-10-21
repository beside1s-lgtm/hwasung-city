extends SceneTree
# PORT-TRACE P11/P23/P24: 렌더 결과 PNG 저장 (창 모드 필요). 출력: godot_hwashung/shot.png
# 좌표는 P24 64x64 확장 지도(실제 답사 지도 기반, 입체 지형) 기준이다.
func _init() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var sim: SimulationCore = main.simulation_core
	sim.gold = 300000
	sim.rice = 80000
	var grid: GameGrid = main.grid
	var city: CityLayer = main.city
	city.current_tool = "gate"
	for key in ["north", "east", "south", "west"]:
		city._apply_at(main.trade.GATE_POINTS[key])
	city.current_tool = "seojangdae"
	city._apply_at(Vector2i(13, 29))
	city.current_tool = "office"
	city._apply_at(Vector2i(29, 32))
	city.current_tool = "road"
	for x in range(20, 50):
		if grid.tile(x, 32)["terrain"] == "plain": city._apply_at(Vector2i(x, 32))
	for y in range(10, 55):
		if grid.tile(29, y)["terrain"] == "plain": city._apply_at(Vector2i(29, y))
	city.current_tool = "zone_res"
	for x in range(24, 29):
		city._apply_at(Vector2i(x, 34))
	city.current_tool = "zone_com"
	for x in range(30, 35):
		city._apply_at(Vector2i(x, 30))
	city.current_tool = "well"
	city._apply_at(Vector2i(27, 33))
	sim.start_mega_project("manseok_reservoir")
	for i in range(20):
		main.turns._on_turn(i, i % 4, 1776 + i / 4)
	main.camera.position = Vector2(0, 320)
	main.camera.zoom = Vector2(0.6, 0.6)
	main.panels._modal.visible = false
	for i in range(30): await process_frame
	root.get_texture().get_image().save_png("res://shot.png")
	quit(0)
