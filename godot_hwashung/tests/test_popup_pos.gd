extends SceneTree

func _init() -> void:
	var canvas := CanvasLayer.new()
	root.add_child(canvas)

	var ctrl := Control.new()
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(ctrl)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 420)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280
	panel.offset_top = -210
	panel.offset_right = 280
	panel.offset_bottom = 210
	ctrl.add_child(panel)

	await process_frame
	await process_frame

	print("Viewport size: ", root.get_viewport().get_visible_rect().size)
	print("Ctrl size: ", ctrl.size)
	print("Panel position: ", panel.position)
	print("Panel global_position: ", panel.global_position)
	print("Panel size: ", panel.size)
	quit(0)
