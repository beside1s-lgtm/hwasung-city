extends SceneTree

func _init() -> void:
	var c := CenterContainer.new()
	c.size = Vector2(1280, 720)
	root.add_child(c)

	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(580, 400)
	c.add_child(p)

	var v := VBoxContainer.new()
	p.add_child(v)

	var l := Label.new()
	l.text = "전하, 계절이 무르익어 현륭원 친림 참배를 거행할 때가 되었사옵니다.\n거둥(行幸)을 거행하시어 효심의 가호를 받으시고 백성들의 충정을 결집하시겠습니까?"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(520, 40)
	v.add_child(l)

	await process_frame
	await process_frame

	print("p size: ", p.size, " p pos: ", p.position)
	print("l min_size: ", l.get_combined_minimum_size())
	quit(0)
