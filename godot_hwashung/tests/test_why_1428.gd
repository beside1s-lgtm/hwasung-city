extends SceneTree

func _init() -> void:
	var rt = load("res://scripts/RoyalTombVisitPopup.gd").new()
	root.add_child(rt)
	await process_frame
	await process_frame

	var vbox = rt._panel.get_child(0)
	var desc_lbl = vbox.get_child(3)
	desc_lbl.custom_minimum_size = Vector2(520, 0)
	await process_frame

	print("AFTER custom_minimum_size:")
	print("desc_lbl min_size: ", desc_lbl.get_combined_minimum_size())
	print("vbox min_size: ", vbox.get_combined_minimum_size())
	print("panel min_size: ", rt._panel.get_combined_minimum_size())
	print("center min_size: ", rt._center.get_combined_minimum_size())

	quit(0)
