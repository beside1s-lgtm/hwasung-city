extends SceneTree

# test_encyclopedia_illustrations.gd
# 역사도감 60종 전 항목(인물 24, 건축 16, 생활 20) 상세 창 일러스트 탑재 및 한자 미노출 전수 검증

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("=== 역사도감 60종 상세 일러스트 전수 검증 시작 ===")
	var modal: PuzzleDetailModal = PuzzleDetailModal.new()
	root.add_child(modal)

	await process_frame
	await process_frame

	var categories: Array[String] = ["people", "buildings", "life"]
	var total_checked: int = 0
	var success_count: int = 0
	var failed_items: Array[String] = []

	for cat_id: String in categories:
		var board: Dictionary = PuzzleData.board(cat_id)
		var pieces: Array = PuzzleData.pieces_of(cat_id)
		print("\n--- 카테고리 검사: [%s] (%d개) ---" % [board.get("title", cat_id), pieces.size()])

		for p_raw in pieces:
			var piece: Dictionary = p_raw as Dictionary
			var pid: String = String(piece.get("id", ""))
			var pname: String = String(piece.get("name", ""))
			total_checked += 1

			modal.show_piece(board, piece, null, Rect2())

			# _illust_box 내부의 TextureRect 검사
			var tex_rect: TextureRect = _find_texture_rect(modal)
			if tex_rect == null or tex_rect.texture == null:
				print("[FAIL] 텍스처 미할당: %s (%s)" % [pid, pname])
				failed_items.append(pid)
				continue

			# TextureRect 하위에 과거의 큰 한자 Label이나 shade ColorRect가 없는지 검사
			var has_hanja_overlay: bool = false
			for ch: Node in tex_rect.get_children():
				if ch is ColorRect or ch is Label:
					has_hanja_overlay = true
					break

			if has_hanja_overlay:
				print("[FAIL] 한자 오버레이가 여전히 노출됨: %s (%s)" % [pid, pname])
				failed_items.append(pid)
			else:
				success_count += 1
				# 정상 로드 확인 로그 (몇 개씩 샘플 출력)
				if total_checked % 5 == 1 or total_checked == 60:
					print("  [PASS] %s (%s) -> 텍스처 크기: %s, 한자 오버레이 없음" % [
						pid, pname, str(tex_rect.texture.get_size())
					])

	print("\n=== 검증 결과 ===")
	print("총 검사 항목: %d개" % total_checked)
	print("성공 항목: %d개" % success_count)
	print("실패 항목: %d개" % failed_items.size())

	if failed_items.is_empty():
		print("[ALL PASS] 60종 모든 역사도감 항목에 일러스트가 정상 탑재되었으며 한자 표시가 완벽히 제거되었습니다!")
		modal.queue_free()
		quit(0)
	else:
		push_error("[TEST FAILED] 일부 항목 일러스트 누락: %s" % str(failed_items))
		modal.queue_free()
		quit(1)

func _find_texture_rect(node: Node) -> TextureRect:
	if node is TextureRect:
		return node as TextureRect
	for ch: Node in node.get_children():
		var found := _find_texture_rect(ch)
		if found != null:
			return found
	return null
