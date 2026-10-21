extends SceneTree

func _init() -> void:
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	await process_frame

	var vp := root.get_viewport()

	# 실험 1: anchors를 PRESET_TOP_LEFT로 하고 size = vp_size 설정
	var ctrl1 := Control.new()
	canvas.add_child(ctrl1)
	ctrl1.size = vp.get_visible_rect().size
	var center1 := CenterContainer.new()
	ctrl1.add_child(center1)
	center1.size = ctrl1.size
	var p1 := PanelContainer.new()
	p1.custom_minimum_size = Vector2(580, 360)
	center1.add_child(p1)

	await process_frame
	await process_frame

	print("Center1 size: ", center1.size, " p1 pos: ", p1.position)

	# 실험 2: CenterContainer 자체를 CanvasLayer에 바로 넣고 size = vp_size
	var center2 := CenterContainer.new()
	canvas.add_child(center2)
	center2.size = vp.get_visible_rect().size
	var p2 := PanelContainer.new()
	p2.custom_minimum_size = Vector2(580, 360)
	center2.add_child(p2)

	await process_frame
	await process_frame

	print("Center2 size: ", center2.size, " p2 pos: ", p2.position)

	quit(0)
