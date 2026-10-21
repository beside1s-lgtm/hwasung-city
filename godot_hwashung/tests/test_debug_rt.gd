extends SceneTree

func _init() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main: Node = main_scene.instantiate()
	root.add_child(main)

	await process_frame
	await process_frame

	var em: EventManager = main.event_manager
	var vp := root.get_viewport()

	vp.size = Vector2i(1280, 720)
	await process_frame
	await process_frame

	em.enqueue_royal_tomb(main.court, main.simulation_core)
	em._pump_next_event()
	await process_frame
	await process_frame

	var rt = em._royal_tomb_popup
	print("vp rect: ", vp.get_visible_rect())
	print("rt.size: ", rt.size)
	print("rt._center.size: ", rt._center.size)
	print("rt._panel.size: ", rt._panel.size)
	print("rt._panel.position: ", rt._panel.position)
	print("rt._panel.global_position: ", rt._panel.global_position)

	quit(0)
