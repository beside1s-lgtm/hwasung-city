extends SceneTree

const UbongoPopupClass = preload("res://scripts/minigames/UbongoWallRepairPopup.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	var popup := UbongoPopupClass.new()
	canvas.add_child(popup)
	
	# If anchors are 0, setting size directly does not trigger anchor warning
	var vp_size: Vector2 = root.get_visible_rect().size
	popup.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	popup.size = vp_size
	popup._backdrop.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	popup._backdrop.size = vp_size
	popup._main_center.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	popup._main_center.size = vp_size
	
	popup.open_ubongo_puzzle(300)
	await process_frame
	await process_frame
	print("Viewport size: ", vp_size)
	print("Popup size: ", popup.size, " pos: ", popup.position)
	print("Main center size: ", popup._main_center.size, " pos: ", popup._main_center.position)
	print("Main panel size: ", popup._main_panel.size, " pos: ", popup._main_panel.position, " global_pos: ", popup._main_panel.global_position)
	quit(0)
