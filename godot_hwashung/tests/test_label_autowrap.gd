extends SceneTree

func _init() -> void:
	var l := Label.new()
	l.text = "전하, 계절이 무르익어 현륭원 친림 참배를 거행할 때가 되었사옵니다.\n거둥(行幸)을 거행하시어 효심의 가호를 받으시고 백성들의 충정을 결집하시겠습니까?"
	root.add_child(l)
	await process_frame
	print("without autowrap: ", l.get_combined_minimum_size())
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	await process_frame
	print("with autowrap: ", l.get_combined_minimum_size())
	quit(0)
