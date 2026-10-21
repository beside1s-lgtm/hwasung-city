extends SceneTree

func _init() -> void:
	var canvas := CanvasLayer.new()
	root.add_child(canvas)

	# 테스트 3: CenterContainer 사용
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 360)
	center.add_child(panel)

	await process_frame
	await process_frame

	print("CenterContainer size: ", center.size)
	print("Panel position: ", panel.position)
	print("Panel size: ", panel.size)

	# 테스트 4: add_child 후 CenterContainer의 size를 get_viewport_rect().size 로 맞추기
	var center2 := CenterContainer.new()
	canvas.add_child(center2)
	center2.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panel2 := PanelContainer.new()
	panel2.custom_minimum_size = Vector2(580, 360)
	center2.add_child(panel2)

	await process_frame
	print("Center2 (add_child 후) size: ", center2.size)
	print("Panel2 position: ", panel2.position)

	# 테스트 5: size = get_viewport().get_visible_rect().size 명시 설정
	center2.size = root.get_viewport().get_visible_rect().size
	await process_frame
	print("Center2 (size 명시 후) size: ", center2.size)
	print("Panel2 position: ", panel2.position)

	quit(0)
