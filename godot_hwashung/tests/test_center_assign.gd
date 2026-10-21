extends SceneTree

func _init() -> void:
	var c := CenterContainer.new()
	root.add_child(c)
	c.size = Vector2(1280, 1428)
	print("before: ", c.size)
	c.size = Vector2(1280, 720)
	print("after: ", c.size)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(580, 400)
	c.add_child(p)
	await process_frame
	print("with child: ", c.size, " p pos: ", p.position)
	quit(0)
