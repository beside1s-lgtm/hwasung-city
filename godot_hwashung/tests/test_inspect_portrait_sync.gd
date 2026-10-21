extends SceneTree

# test_inspect_portrait_sync.gd
# 살피기(InspectPopup) 및 명인 열전 모달에 새로 제작된 인물화 프로필이 정상 반영되는지 검증

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("=== 살피기 팝업 인물 프로필 이미지 동기화 검증 시작 ===")

	# 1. InspectNarrativeGenerator.get_portrait 조회 검증
	var test_nids: Array[String] = ["hong_daeyong", "chae_jegong", "jeong_yakyong", "baek_dongsu", "kim_hongdo"]
	for nid: String in test_nids:
		var tex: Texture2D = InspectNarrativeGenerator.get_portrait(nid)
		if tex == null:
			push_error("[FAIL] get_portrait 텍스처 null 반환: %s" % nid)
			quit(1)
			return
		print("[PASS] get_portrait 성공: %s -> 크기: %s" % [nid, str(tex.get_size())])

	# 2. InspectPopup 모달 내 텍스처 반영 검증
	var popup: InspectPopup = InspectPopup.new()
	root.add_child(popup)
	await process_frame
	await process_frame

	var entity_hong: Dictionary = {
		"is_named": true,
		"named_id": "hong_daeyong",
		"name": "홍대용"
	}
	var narrative: Dictionary = InspectNarrativeGenerator.build_inspect_data(entity_hong)
	var title_text: String = String(narrative.get("title", ""))
	var desc_text: String = String(narrative.get("description", ""))
	var tex_obj: Texture2D = narrative.get("texture", null) as Texture2D

	popup.open_inspect(title_text, desc_text, tex_obj)
	await process_frame

	var p_rect: TextureRect = popup.get_node_or_null("_panel/HBoxContainer/VBoxContainer/PanelContainer/TextureRect") as TextureRect
	if p_rect == null:
		# 내부 필드로 접근
		p_rect = popup._portrait_rect

	if p_rect == null or p_rect.texture == null:
		push_error("[FAIL] InspectPopup 내 _portrait_rect 에 텍스처가 정상 할당되지 않음")
		popup.queue_free()
		quit(1)
		return

	print("[PASS] InspectPopup에 홍대용 프로필 이미지 탑재 확인: 크기=%s, filter=%s" % [
		str(p_rect.texture.get_size()),
		"LINEAR" if p_rect.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR else "NEAREST"
	])

	popup.queue_free()
	print("=== 살피기 팝업 프로필 동기화 테스트 통과 (ALL PASS) ===")
	quit(0)
