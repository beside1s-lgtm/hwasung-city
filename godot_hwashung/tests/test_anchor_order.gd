extends SceneTree

func _init() -> void:
	var canvas := CanvasLayer.new()
	root.add_child(canvas)

	# 케이스 1: Control (DisasterPopup 형태)
	var ctrl := Control.new()
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(ctrl)

	# 케이스 2: ColorRect (Overlay 형태)
	var crect := ColorRect.new()
	crect.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(crect)

	await process_frame
	await process_frame

	print("Ctrl size: ", ctrl.size)
	print("ColorRect size: ", crect.size)

	# 이제 씬에 붙은 후 set_anchors_preset을 호출하는 경우:
	var ctrl2 := Control.new()
	canvas.add_child(ctrl2)
	ctrl2.set_anchors_preset(Control.PRESET_FULL_RECT)

	await process_frame
	print("Ctrl2 (add_child 먼저 한 후 set_anchors_preset) size: ", ctrl2.size)

	quit(0)
