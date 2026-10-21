extends SceneTree

## [2단계 가시성 LOD(400칸/300칸), 백그라운드 연속성 및 특수 개체 상시 노출 무결성 검증]

func _init() -> void:
	print("=== [TEST] 2단계 LOD(400칸/300칸) & 백그라운드 연속성 & 특수 개체 상시 노출 검증 시작 ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var root_node := Node2D.new()
	root_node.name = "TestRoot"
	root.add_child(root_node)

	var cm := CitizenManager.new()
	cm.name = "CitizenManager"
	var grid := GameGrid.new()
	root_node.add_child(grid)
	cm.grid = grid
	root_node.add_child(cm)

	# -------------------------------------------------------------
	# 1. 상수 및 임계치 검증
	# -------------------------------------------------------------
	print("[TEST 1] LOD 임계치 상수 검증")
	assert(CitizenManager.TILE_LIMIT_NPC_VISIBLE == 400, "TILE_LIMIT_NPC_VISIBLE must be 400")
	assert(CitizenManager.TILE_LIMIT_BUBBLE_VISIBLE == 300, "TILE_LIMIT_BUBBLE_VISIBLE must be 300")
	print("  -> TILE_LIMIT_NPC_VISIBLE = 400, TILE_LIMIT_BUBBLE_VISIBLE = 300 (PASS)")

	# -------------------------------------------------------------
	# 2. 일반 시민 NPC 생성 및 백그라운드 활동 연속성(No Freeze / No Respawn) 검증
	# -------------------------------------------------------------
	print("[TEST 2] 백그라운드 활동 연속성(No Freeze) 검증")
	var normal_npc := CitizenNPC.new("citizen_male")
	normal_npc.name = "NormalCitizen"
	normal_npc.global_position = Vector2(100.0, 100.0)
	normal_npc.move_speed = 2.0
	normal_npc.active_path = [Vector2i(5, 5), Vector2i(10, 10)]
	normal_npc.path_index = 0
	root_node.add_child(normal_npc)
	cm.register_npc(normal_npc)

	var initial_pos: Vector2 = normal_npc.global_position
	# 줌아웃 상태(원거리 조감, 타일 수 > 400) 시뮬레이션:
	# PROCESS_MODE_DISABLED가 적용되지 않아야 하며, update_logical_activity에 의해 위치가 이동해야 함
	CameraLODController.current_zoom = 0.3 # 400칸 초과 줌아웃
	CameraLODController.test_override_rect = Rect2(-2000.0, -2000.0, 4000.0, 4000.0)

	cm._process(0.5)

	print("DEBUG: visible_tiles = ", cm.get_visible_tile_count(), ", normal_npc.visible = ", normal_npc.visible, ", is_special = ", normal_npc.is_special())
	# PROCESS_MODE_DISABLED가 아니어야 함
	assert(normal_npc.process_mode != Node.PROCESS_MODE_DISABLED, "NPC must NOT be disabled on zoom out")
	# 원거리(>400칸)에서는 일반 시민 숨김 처리 (visible = false)
	assert(normal_npc.visible == false, "Normal NPC should be invisible when tiles > 400")
	# 하지만 백그라운드 논리 이동은 계속되어 위치가 갱신되어야 함!
	assert(normal_npc.global_position != initial_pos, "Normal NPC must continue moving in background")
	print("  -> 백그라운드 활동 연속성 확인: process_mode 유지 및 논리 좌표 이동 정상 (PASS)")

	# -------------------------------------------------------------
	# 3. 2단계 가시성 LOD (<=400칸 본체 노출, <=300칸 말풍선 노출) 검증
	# -------------------------------------------------------------
	print("[TEST 3] 2단계 가시성 LOD (400칸 본체 / 300칸 말풍선) 검증")
	normal_npc.show_speech_bubble("안녕하세요 수원화성입니다!")
	assert(normal_npc.has_active_dialogue == true, "Dialogue must be active")

	# (1) 350칸 뷰 (<= 400칸, > 300칸): 본체는 보이고 말풍선은 숨김
	# 뷰포트 1280x720, 줌 1.2 -> cols: 1280/(64*1.2) = 17, rows: 720/(32*1.2) = 19 -> 17*19 = 323칸
	CameraLODController.current_zoom = 1.2
	CameraLODController.test_override_rect = Rect2(normal_npc.global_position - Vector2(200, 200), Vector2(400, 400))
	var tile_count_350: int = cm.get_visible_tile_count()
	# 300초과 400이하 범위 확인
	cm._process(0.1)

	if tile_count_350 <= CitizenManager.TILE_LIMIT_NPC_VISIBLE:
		assert(normal_npc.visible == true, "Normal NPC must be visible when tiles <= 400")
		if tile_count_350 > CitizenManager.TILE_LIMIT_BUBBLE_VISIBLE:
			assert(normal_npc.speech_bubble_node.visible == false, "Bubble must be hidden when tiles > 300")
			print("  -> 300~400칸 구간: 본체 visible = true, 말풍선 visible = false (PASS)")

	# (2) 200칸 뷰 (<= 300칸): 본체와 말풍선 모두 보임
	# 줌 2.0 -> cols: 11, rows: 12 -> 132칸 <= 300
	CameraLODController.current_zoom = 2.0
	CameraLODController.test_override_rect = Rect2(normal_npc.global_position - Vector2(200, 200), Vector2(400, 400))
	cm._process(0.1)
	assert(normal_npc.visible == true, "Normal NPC must be visible when tiles <= 300")
	assert(normal_npc.speech_bubble_node.visible == true, "Bubble must be visible when tiles <= 300")
	print("  -> <=300칸 구간: 본체 visible = true, 말풍선 visible = true (PASS)")

	# -------------------------------------------------------------
	# 4. 특수 개체 상시 노출 (Zoom Culling 완전 면제) 검증
	# -------------------------------------------------------------
	print("[TEST 4] 특수 개체 상시 노출 (Zoom Culling 면제) 검증")
	# 줌아웃 (타일 수 > 400칸, 줌 0.2)
	CameraLODController.current_zoom = 0.2
	CameraLODController.test_override_rect = Rect2(-3000, -3000, 6000, 6000)

	# 4-1. 순라청 포졸 (PatrolOfficerNPC)
	var officer := PatrolOfficerNPC.new()
	officer.setup_officer(1, Vector2i(10, 10))
	officer.dispatch(101, Vector2i(20, 20), [Vector2i(10, 10), Vector2i(15, 15), Vector2i(20, 20)], 2.0)
	assert(SpecialEntityManager.is_special_entity(officer) == true, "Patrol officer must be special entity")
	var off_vis := officer.get_or_create_visual(root_node)
	cm.register_special_entity(off_vis)
	off_vis.show_speech_bubble("순라군 출동이다!")
	cm._process(0.1)
	assert(off_vis.visible == true, "Officer must remain visible even when zoom > 400 tiles")
	assert(off_vis.speech_bubble_node.visible == true, "Officer bubble must remain visible regardless of zoom")
	print("  -> 순라군 포졸: 줌아웃 시에도 본체 및 말풍선 상시 노출 (PASS)")

	# 4-2. 도둑 / 소매치기 (CriminalNPC)
	var thief := CriminalNPC.new()
	thief.setup_criminal(1, CriminalNPC.CriminalKind.PICKPOCKET, Vector2i(15, 15), 101)
	assert(SpecialEntityManager.is_special_entity(thief) == true, "Thief must be special entity")
	assert(SpecialEntityManager.is_special_entity(thief.to_agent_dict()) == true, "Thief dict must be special entity")
	print("  -> 소매치기 도둑: 특수 개체 판정 확인 (PASS)")

	# 4-3. 도적떼 (BanditEntity)
	var bandit := BanditEntity.new()
	bandit.setup_bandit(1, Vector2i(5, 5), Vector2i(25, 25), Vector2i(4, 8), BanditEntity.Mode.OUTSKIRTS)
	assert(SpecialEntityManager.is_special_entity(bandit) == true, "Bandit must be special entity")
	var bandit_dict := bandit.to_agent_dict()
	assert(SpecialEntityManager.is_special_entity(bandit_dict) == true, "Bandit dict must be special entity")
	print("  -> 도적떼: 특수 개체 판정 확인 (PASS)")

	# 4-4. 반란군 (EnemyMarcherEntity)
	var rebel := EnemyMarcherEntity.new()
	rebel.kind = "rebel"
	assert(SpecialEntityManager.is_special_entity(rebel) == true, "Rebel must be special entity")
	var rebel_vis := rebel.get_or_create_visual(root_node)
	assert(rebel_vis.is_special() == true, "Rebel visual must be special entity")
	print("  -> 반란군: 특수 개체 판정 확인 (PASS)")

	# 4-5. 세시풍속 활동 시민 (SeasonalCustomManager 연동)
	var custom_npc := CitizenNPC.new("citizen_female")
	custom_npc.name = "CustomCitizen"
	root_node.add_child(custom_npc)
	cm.register_npc(custom_npc)
	SeasonalCustomManager.tag_custom_actor(custom_npc, "ssireum")
	custom_npc.show_speech_bubble("단오 씨름 구경가세!")
	assert(custom_npc.is_participating_in_custom() == true, "Must be participating in custom")
	assert(custom_npc.is_special() == true, "Must be special entity")
	cm._process(0.1)
	assert(custom_npc.visible == true, "Custom NPC must remain visible on zoom out")
	assert(custom_npc.speech_bubble_node.visible == true, "Custom NPC bubble must remain visible on zoom out")
	print("  -> 세시풍속 활동 시민: 줌아웃 시에도 본체 및 말풍선 상시 노출 (PASS)")

	# 4-6. 호랑이 & 맹수
	var tiger_dict: Dictionary = {
		"type": "tiger",
		"state": "prowl",
		"bubble_text": "어흥!",
		"x": 10.0, "y": 10.0
	}
	assert(SpecialEntityManager.is_special_entity(tiger_dict) == true, "Tiger dict must be special entity")
	print("  -> 호랑이: 특수 개체 판정 확인 (PASS)")

	print("\n=== [ALL PASS] 2단계 가시성 LOD & 백그라운드 연속성 & 특수 개체 상시 노출 모든 검증 완료! ===")
	quit(0)
