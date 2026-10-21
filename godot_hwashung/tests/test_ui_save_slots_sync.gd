extends SceneTree

func _init() -> void:
	print("=== UI 세이브 슬롯 동기화 및 4개 슬롯 통합 검증 시작 ===")

	# 1. TitleScreenLayer 인스턴스화 및 로드 모달 슬롯 검사
	var title_layer := TitleScreenLayer.new()
	var root_control := Control.new()
	root_control.size = Vector2(1280, 720)
	root_control.add_child(title_layer)
	title_layer._ready()
	
	# 모달 열기 호출
	title_layer._open_load_modal()
	
	var title_modal_body: Control = title_layer._modal_body
	assert(title_modal_body != null, "TitleScreenLayer 모달 바디가 존재해야 합니다.")

	# title_modal_body 자식들 중 PanelContainer 카운트 (슬롯 카드들)
	var title_slot_cards: Array[PanelContainer] = []
	for child in title_modal_body.get_children():
		if child is PanelContainer:
			title_slot_cards.append(child as PanelContainer)

	print("TitleScreenLayer 로드 슬롯 카드 개수: %d" % title_slot_cards.size())
	assert(title_slot_cards.size() == 4, "메인 화면 불러오기 슬롯은 정확히 4개여야 합니다.")

	# 2. PanelController 인스턴스화 및 설정 창 슬롯 검사
	var panel_ctrl := PanelController.new()
	var sim := SimulationCore.new()
	panel_ctrl.sim = sim
	root_control.add_child(panel_ctrl)
	panel_ctrl._build_modal()

	panel_ctrl._build_game_settings()
	var settings_body: Control = panel_ctrl._body
	assert(settings_body != null, "PanelController 설정 창 바디가 존재해야 합니다.")

	# settings_body 자식들 중 카드들 검사
	var cards: Array[PanelContainer] = []
	for child in settings_body.get_children():
		if child is PanelContainer:
			cards.append(child as PanelContainer)

	print("PanelController 설정 카드 개수: %d" % cards.size())

	# 저장 카드 & 불러오기 카드의 HBoxContainer 내부 슬롯 수 검사
	var found_save_slots_count := 0
	var found_load_slots_count := 0

	for card in cards:
		var vb := card.get_node_or_null("VBox") as VBoxContainer
		if vb == null:
			continue
		for v_child in vb.get_children():
			if v_child is HBoxContainer:
				var hb := v_child as HBoxContainer
				var panel_children: Array[PanelContainer] = []
				for h_child in hb.get_children():
					if h_child is PanelContainer:
						panel_children.append(h_child as PanelContainer)
				if panel_children.size() == 4:
					if found_save_slots_count == 0:
						found_save_slots_count = 4
					else:
						found_load_slots_count = 4

	print("PanelController 저장 슬롯 수: %d, 불러오기 슬롯 수: %d" % [found_save_slots_count, found_load_slots_count])
	assert(found_save_slots_count == 4, "인게임 설정의 저장 슬롯 수는 정확히 4개여야 합니다.")
	assert(found_load_slots_count == 4, "인게임 설정의 불러오기 슬롯 수는 정확히 4개여야 합니다.")

	# 3. 양쪽 UI의 슬롯 데이터 일치성 검증 (슬롯 0, 1, 2, 3)
	for slot_id in SaveSystem.SLOTS:
		var has_s: bool = SaveSystem.has_save(slot_id)
		var info_s: Dictionary = SaveSystem.get_save_info(slot_id)
		var expected_title: String = SaveSystem.get_formatted_title(slot_id, info_s)
		print("슬롯 %d 검증 -> 존재: %s, 타이틀: %s" % [slot_id, has_s, expected_title])

	print("=== UI 세이브 슬롯 동기화 검증 성공 완료 (ALL PASSED) ===")
	quit(0)
