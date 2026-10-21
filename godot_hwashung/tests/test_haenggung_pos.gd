extends SceneTree

func _init() -> void:
	var h_scene = load("res://scripts/HaenggungSubBuildingPopup.gd")
	var h = h_scene.new()
	root.add_child(h)

	var t_scene = load("res://scripts/TrialPopup.gd")
	var t = t_scene.new()
	root.add_child(t)

	await process_frame
	await process_frame

	print("Haenggung _panel pos: ", h._panel.position, " global_pos: ", h._panel.global_position)
	print("Trial _panel pos: ", t._panel.position, " global_pos: ", t._panel.global_position)

	quit(0)
