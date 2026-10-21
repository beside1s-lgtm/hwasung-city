extends SceneTree

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("=== HistoryEncyclopediaLayer 버튼 제거 검증 테스트 시작 ===")
	var layer: HistoryEncyclopediaLayer = HistoryEncyclopediaLayer.new()
	root.add_child(layer)

	await process_frame
	await process_frame

	# 레이어 하위의 모든 Button 검사
	var found_hidden_video_btn: bool = false
	var buttons: Array[Button] = []
	_collect_buttons(layer, buttons)

	print("[TEST] 검사된 버튼 총 개수: %d" % buttons.size())
	for btn: Button in buttons:
		print("  - 발견된 버튼: [%s]" % btn.text)
		if "숨겨진" in btn.text or "실록" in btn.text:
			found_hidden_video_btn = true
			print("[ERROR] 여전히 숨겨진 영상 관련 버튼이 존재함: %s" % btn.text)

	if not found_hidden_video_btn:
		print("[PASS] 숨겨진 수원화성 실록 비디오 감상 버튼이 정상적으로 제거되었습니다.")
	else:
		push_error("[FAIL] 숨겨진 수원화성 실록 비디오 감상 버튼이 남아있습니다.")
		quit(1)
		return

	# 전체화면/완성 영상 감상 버튼은 유지되는지 검증
	var found_fullscreen_btn: bool = false
	for btn: Button in buttons:
		if "전체화면" in btn.text or "완성 영상" in btn.text:
			found_fullscreen_btn = true
			print("[PASS] 기존 완성/전체화면 감상 버튼 정상 유지 확인: %s" % btn.text)
			break

	if not found_fullscreen_btn:
		push_error("[FAIL] 완성 영상/전체화면 감상 버튼이 누락되었습니다.")
		quit(1)
		return

	layer.queue_free()
	print("=== HistoryEncyclopediaLayer 버튼 제거 검증 테스트 통과 (ALL PASS) ===")
	quit(0)

func _collect_buttons(node: Node, out_buttons: Array[Button]) -> void:
	if node is Button:
		out_buttons.append(node as Button)
	for child: Node in node.get_children():
		_collect_buttons(child, out_buttons)
