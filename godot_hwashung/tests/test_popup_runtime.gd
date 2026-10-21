extends SceneTree

func _init() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)

	await process_frame
	await process_frame

	var em = main.event_manager
	em.enqueue_disaster("화재 발생", "민가에 불이 났습니다!")
	em._pump_next_event()

	await process_frame
	await process_frame

	var dp = em._disaster_popup
	var panel = dp._panel

	print("Viewport visible_rect: ", root.get_viewport().get_visible_rect())
	print("DisasterPopup visible: ", dp.visible)
	print("DisasterPopup size: ", dp.size)
	print("DisasterPopup position: ", dp.position)
	print("DisasterPopup global_position: ", dp.global_position)
	print("DisasterPopup anchors: left=", dp.anchor_left, " top=", dp.anchor_top, " right=", dp.anchor_right, " bottom=", dp.anchor_bottom)
	print("Panel visible: ", panel.visible)
	print("Panel size: ", panel.size)
	print("Panel position: ", panel.position)
	print("Panel global_position: ", panel.global_position)
	print("Panel offset: left=", panel.offset_left, " top=", panel.offset_top, " right=", panel.offset_right, " bottom=", panel.offset_bottom)
	print("Panel anchors: left=", panel.anchor_left, " top=", panel.anchor_top, " right=", panel.anchor_right, " bottom=", panel.anchor_bottom)

	quit(0)
