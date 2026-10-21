extends SceneTree

func _init() -> void:
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	await process_frame

	var vp := root.get_viewport()

	# 모의 DisasterPopup 구조
	var popup_ctrl := Control.new()
	popup_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_ctrl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup_ctrl.grow_vertical = Control.GROW_DIRECTION_BOTH
	canvas.add_child(popup_ctrl)

	popup_ctrl.size = vp.get_visible_rect().size
	vp.size_changed.connect(func():
		popup_ctrl.size = vp.get_visible_rect().size
	)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	popup_ctrl.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 360)
	center.add_child(panel)

	await process_frame
	await process_frame

	print("[초기 해상도 1280x1280]")
	print("Viewport size: ", vp.get_visible_rect().size)
	print("PopupCtrl size: ", popup_ctrl.size)
	print("Center size: ", center.size)
	print("Panel pos: ", panel.position, " global_pos: ", panel.global_position)

	# 2386x1202 해상도 변경 시뮬레이션
	vp.size = Vector2i(2386, 1202)
	await process_frame
	await process_frame

	print("\n[변경 해상도 2386x1202]")
	print("Viewport size: ", vp.get_visible_rect().size)
	print("PopupCtrl size: ", popup_ctrl.size)
	print("Center size: ", center.size)
	print("Panel pos: ", panel.position, " global_pos: ", panel.global_position)

	# 1586x752 해상도 변경 시뮬레이션
	vp.size = Vector2i(1586, 752)
	await process_frame
	await process_frame

	print("\n[변경 해상도 1586x752]")
	print("Viewport size: ", vp.get_visible_rect().size)
	print("PopupCtrl size: ", popup_ctrl.size)
	print("Center size: ", center.size)
	print("Panel pos: ", panel.position, " global_pos: ", panel.global_position)

	quit(0)
