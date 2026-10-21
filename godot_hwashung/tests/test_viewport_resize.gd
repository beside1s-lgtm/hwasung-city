extends SceneTree

func _init() -> void:
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	await process_frame

	var vp := root.get_viewport()

	# 방법 A: add_child 전에 set_anchors_preset(PRESET_FULL_RECT)
	var ctrlA := Control.new()
	ctrlA.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrlA.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ctrlA.grow_vertical = Control.GROW_DIRECTION_BOTH
	canvas.add_child(ctrlA)

	# 방법 B: size_changed 시그널로 Viewport 크기 동기화
	var centerD := CenterContainer.new()
	canvas.add_child(centerD)
	var sync_size = func():
		centerD.size = vp.get_visible_rect().size
	sync_size.call()
	vp.size_changed.connect(sync_size)

	var pD := PanelContainer.new()
	pD.custom_minimum_size = Vector2(580, 360)
	centerD.add_child(pD)

	await process_frame
	await process_frame

	print("Viewport visible_rect: ", vp.get_visible_rect())
	print("CtrlA size: ", ctrlA.size)
	print("CenterD size: ", centerD.size, " pD pos: ", pD.position)

	# 뷰포트 크기가 변경되는 시뮬레이션
	vp.size = Vector2i(2386, 1202)
	await process_frame
	await process_frame

	print("\n--- 뷰포트 변경 후 (2386 x 1202) ---")
	print("Viewport visible_rect: ", vp.get_visible_rect())
	print("CtrlA size: ", ctrlA.size)
	print("CenterD size: ", centerD.size, " pD pos: ", pD.position)

	quit(0)
