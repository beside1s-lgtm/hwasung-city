extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene = load("res://scenes/Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var ubongo = main.ubongo_wall_repair
	print("ubongo parent: ", ubongo.get_parent().name, " (class: ", ubongo.get_parent().get_class(), ")")
	print("ubongo size: ", ubongo.size, " pos: ", ubongo.position)
	print("ubongo _main_center size: ", ubongo._main_center.size, " pos: ", ubongo._main_center.position)
	print("ubongo _main_panel size: ", ubongo._main_panel.size, " pos: ", ubongo._main_panel.position, " global_pos: ", ubongo._main_panel.global_position)
	print("viewport size: ", root.get_viewport().get_visible_rect().size)
	quit(0)
