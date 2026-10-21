extends SceneTree

const UbongoPopupClass = preload("res://scripts/minigames/UbongoWallRepairPopup.gd")

func _init() -> void:
	call_deferred("_run_capture")

func _run_capture() -> void:
	var popup := UbongoPopupClass.new()
	root.add_child(popup)
	popup._ready()
	popup.open_ubongo_puzzle(300)

	await process_frame
	await process_frame
	await process_frame

	var img: Image = root.get_texture().get_image()
	if img != null:
		var save_err := img.save_png("c:/myapp/hwashung city/ubongo_ingame_captured.png")
		print("Screenshot saved to ubongo_ingame_captured.png (err=%d)" % save_err)

	quit(0)
