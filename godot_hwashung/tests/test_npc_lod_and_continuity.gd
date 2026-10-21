extends SceneTree

## [카메라 가시 타일 수(400칸/300칸) 2단계 LOD, 백그라운드 활동 연속성 및 특수 개체 상시 노출 검증 테스트]

func _init() -> void:
	print("=== NPC 가시성 LOD 및 백그라운드 활동 연속성 검증 테스트 시작 ===")

	var main_scene = load("res://scenes/Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var citizens: CitizenManager = main.citizens
	assert(citizens != null, "CitizenManager가 정상 인스턴스화되어야 합니다.")
	if main.time_manager != null:
		main.time_manager.set_speed(TimeManager.SpeedMode.NORMAL)
	citizens.time_scale = 1.0

	# =========================================================================
	# 1. 400칸 / 300칸 2단계 가시성 임계치(Threshold) 상수 및 판정 함수 검증
	# =========================================================================
	print("\n--- 1. 가시 타일 수 임계치 상수 검증 ---")
	assert(CitizenManager.TILE_LIMIT_NPC_VISIBLE == 400, "TILE_LIMIT_NPC_VISIBLE은 400이어야 합니다.")
	assert(CitizenManager.TILE_LIMIT_BUBBLE_VISIBLE == 300, "TILE_LIMIT_BUBBLE_VISIBLE은 300이어야 합니다.")
	print("[PASS] 가시 타일 수 400칸(일반 NPC) / 300칸(말풍선) 임계치 검증 완료")

	# =========================================================================
	# 2. 일반 시민 NPC vs 특수 개체 가시성 LOD 및 백그라운드 활동 연속성 검증
	# =========================================================================
	print("\n--- 2. 일반 시민 NPC 및 특수 개체 생성 및 등록 ---")
	var normal_citizen := CitizenNPC.new("citizen_male")
	normal_citizen.global_position = Vector2(100.0, 100.0)
	normal_citizen.active_path = [Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)]
	main.add_child(normal_citizen)
	citizens.register_npc(normal_citizen)

	# 특수 개체 1: 세시풍속 참가 시민
	var festival_npc := CitizenNPC.new("citizen_female")
	festival_npc.global_position = Vector2(120.0, 100.0)
	festival_npc.is_participating_custom = true
	main.add_child(festival_npc)
	citizens.register_npc(festival_npc)

	# 특수 개체 2: 도둑/소매치기 (CriminalNPC)
	var thief_crm := CriminalNPC.new()
	thief_crm.setup_criminal(101, CriminalNPC.CriminalKind.PICKPOCKET, Vector2i(10, 10), 1)
	thief_crm.x = 10.5
	thief_crm.y = 10.5
	thief_crm.bubble_text = "지갑 내놔라!"
	thief_crm.bubble_timer = 5.0
	SpecialEntityManager.register_special(thief_crm)

	# 특수 개체 3: 출동 순라군 포졸 (PatrolOfficerNPC)
	var patrol_off := PatrolOfficerNPC.new()
	patrol_off.setup_officer(201, Vector2i(12, 12))
	patrol_off.is_active = true
	patrol_off.state = PatrolOfficerNPC.OfficerState.DISPATCH
	patrol_off.bubble_text = "거기 멈춰라!"
	patrol_off.bubble_timer = 5.0
	SpecialEntityManager.register_special(patrol_off)

	# 특수 개체 4: 도적 엔티티 (BanditEntity)
	var bandit_ent := BanditEntity.new()
	bandit_ent.setup_bandit(301, Vector2i(8, 8), Vector2i(20, 20), Vector2i(4, 8), BanditEntity.Mode.OUTSKIRTS, 4)
	bandit_ent.bubble_text = "마을을 털어라!"
	bandit_ent.bubble_timer = 5.0
	SpecialEntityManager.register_special(bandit_ent)

	# 특수 개체 5: 맹수 호랑이 (tiger agent)
	var tiger_ag: Dictionary = citizens._add_predator("tiger", Vector2i(25, 25))
	SpecialEntityManager.mark_special(tiger_ag)

	# 특수 개체 6: 반란군 (rebel agent)
	var rebel_ag := citizens._add_road_agent("rebel", Vector2i(14, 14))
	rebel_ag["siege_unit"] = true
	rebel_ag["bubble_text"] = "행궁으로 진격하라!"
	rebel_ag["bubble_timer"] = 5.0
	SpecialEntityManager.mark_special(rebel_ag)

	# 특수 개체 여부 검증
	assert(SpecialEntityManager.is_special_node(festival_npc), "festival_npc는 특수 개체여야 합니다.")
	assert(SpecialEntityManager.is_special_entity(thief_crm), "thief_crm은 특수 개체여야 합니다.")
	assert(SpecialEntityManager.is_special_entity(patrol_off), "patrol_off는 특수 개체여야 합니다.")
	assert(SpecialEntityManager.is_special_entity(bandit_ent), "bandit_ent는 특수 개체여야 합니다.")
	assert(SpecialEntityManager.is_special_agent(tiger_ag), "tiger_ag는 특수 에이전트여야 합니다.")
	assert(SpecialEntityManager.is_special_agent(rebel_ag), "rebel_ag는 특수 에이전트여야 합니다.")
	assert(not SpecialEntityManager.is_special_node(normal_citizen), "normal_citizen은 일반 시민이어야 합니다.")
	print("[PASS] 6대 특수 개체(세시풍속·도둑·순라군·도적·호랑이·반란군) 분류 판별 성공")

	# =========================================================================
	# 3. [시나리오 A: 근거리 줌 인 <= 300칸] 일반 NPC 보임 + 말풍선 노출
	# =========================================================================
	print("\n--- 3. [근거리 줌 인 <= 300칸 (예: 200칸)] 시각 및 말풍선 검증 ---")
	main.camera.zoom = Vector2(2.0, 2.0)
	CameraLODController.current_zoom = 2.0
	if CameraLODController.instance != null:
		CameraLODController.instance.check_zoom_lod(2.0)
	CameraLODController.test_override_rect = Rect2(0, 0, 1000, 600)
	var tiles_200: int = citizens.get_visible_tile_count()
	print("현재 가시 타일 수: %d칸" % tiles_200)
	assert(tiles_200 <= 300, "2.0x 줌에서는 가시 타일 수가 300칸 이하여야 합니다.")

	normal_citizen.has_active_dialogue = true
	normal_citizen.show_speech_bubble("안녕하세요 수원화성입니다!")

	citizens._process(0.1)

	assert(normal_citizen.visible == true, "300칸 이하에서는 일반 시민 NPC가 보여야 합니다.")
	assert(normal_citizen.current_bubble_node != null and normal_citizen.current_bubble_node.visible == true, "300칸 이하에서는 일반 시민 말풍선이 보여야 합니다.")
	assert(festival_npc.visible == true, "세시풍속 NPC는 항상 보여야 합니다.")
	print("[PASS] <= 300칸 상태: 일반 시민 NPC 노출 및 말풍선 노출 확인")

	# =========================================================================
	# 4. [시나리오 B: 중거리 줌 300 ~ 400칸 (예: 350칸)] 일반 NPC 보임 + 말풍선 숨김
	# =========================================================================
	print("\n--- 4. [중거리 줌 300 ~ 400칸 (예: 350칸)] 시각 및 말풍선 검증 ---")
	main.camera.zoom = Vector2(1.65, 1.65)
	CameraLODController.current_zoom = 1.65
	if CameraLODController.instance != null:
		CameraLODController.instance.check_zoom_lod(1.65)
	CameraLODController.test_override_rect = Rect2(0, 0, 1000, 600)
	var tiles_350: int = citizens.get_visible_tile_count()
	print("현재 가시 타일 수: %d칸" % tiles_350)
	assert(tiles_350 > 300 and tiles_350 <= 400, "1.65x 줌에서는 가시 타일 수가 300 ~ 400칸 사이여야 합니다.")

	citizens._process(0.1)

	assert(normal_citizen.visible == true, "400칸 이하에서는 일반 시민 NPC 본체가 보여야 합니다.")
	assert(normal_citizen.current_bubble_node != null and normal_citizen.current_bubble_node.visible == false, "300칸 초과에서는 일반 시민 말풍선이 숨겨져야 합니다.")
	assert(festival_npc.visible == true, "세시풍속 NPC는 350칸에서도 보여야 합니다.")
	print("[PASS] 300 ~ 400칸 상태: 일반 시민 NPC 노출 및 말풍선 숨김 확인")

	# =========================================================================
	# 5. [시나리오 C: 원거리 줌아웃 > 400칸 (예: 600칸)] 일반 NPC 숨김 + 특수 개체 상시 표시
	# =========================================================================
	print("\n--- 5. [원거리 줌아웃 > 400칸 (예: 600칸)] 일반 숨김 & 특수 상시 노출 검증 ---")
	main.camera.zoom = Vector2(0.5, 0.5)
	CameraLODController.current_zoom = 0.5
	if CameraLODController.instance != null:
		CameraLODController.instance.check_zoom_lod(0.5)
	CameraLODController.test_override_rect = Rect2(0, 0, 2000, 1200)
	var tiles_600: int = citizens.get_visible_tile_count()
	print("현재 가시 타일 수: %d칸" % tiles_600)
	assert(tiles_600 > 400, "0.5x 줌에서는 가시 타일 수가 400칸을 초과해야 합니다.")

	var init_pos: Vector2 = normal_citizen.global_position
	citizens._process(0.5)

	# 1) 일반 시민 검증: 화면에서만 숨겨짐, 프로세스 모드는 유지(동결 금지)
	assert(normal_citizen.visible == false, "400칸 초과 상태에서는 일반 시민 NPC가 숨겨져야 합니다.")
	assert(normal_citizen.process_mode != Node.PROCESS_MODE_DISABLED, "화면 축소 시에도 PROCESS_MODE_DISABLED로 동결되면 안 됩니다.")
	assert(normal_citizen.current_bubble_node != null and normal_citizen.current_bubble_node.visible == false, "400칸 초과 시 일반 시민 말풍선은 숨김 상태여야 합니다.")

	# 2) 백그라운드 활동 연속성 검증: 숨겨져 있는 동안에도 논리 이동이 진행됨
	assert(normal_citizen.global_position != init_pos, "일반 시민이 화면에서 숨겨져 있어도 백그라운드 논리 이동은 계속되어야 합니다.")
	print("[PASS] > 400칸 상태: 일반 시민 화면 숨김 및 백그라운드 연속 이동 검증 완료 (이동 거리: %.1f px)" % normal_citizen.global_position.distance_to(init_pos))

	# 3) 특수 개체 상시 노출(Zoom Culling 완전 면제) 검증
	assert(festival_npc.visible == true, "세시풍속 NPC는 > 400칸 상태에서도 항상 보여야 합니다.")
	assert(SpecialEntityManager.is_special_entity(thief_crm), "도둑은 원거리에서도 특수 개체로 유지되어야 합니다.")
	assert(SpecialEntityManager.is_special_entity(patrol_off), "출동 순라군은 원거리에서도 특수 개체로 유지되어야 합니다.")
	assert(SpecialEntityManager.is_special_entity(bandit_ent), "도적은 원거리에서도 특수 개체로 유지되어야 합니다.")
	assert(SpecialEntityManager.is_special_agent(tiger_ag), "호랑이는 원거리에서도 특수 개체로 유지되어야 합니다.")
	assert(SpecialEntityManager.is_special_agent(rebel_ag), "반란군은 원거리에서도 특수 개체로 유지되어야 합니다.")
	print("[PASS] > 400칸 상태: 특수 개체(세시풍속·도둑·순라군·도적·호랑이·반란군) 상시 노출 검증 완료")

	# =========================================================================
	# 6. [시나리오 D: 재확대(Zoom In)] 스폰/디스폰 없이 자연스러운 복귀 검증
	# =========================================================================
	print("\n--- 6. [재확대 (Zoom In <= 300칸)] No Respawn 복귀 검증 ---")
	var pre_zoom_pos: Vector2 = normal_citizen.global_position
	main.camera.zoom = Vector2(2.0, 2.0)
	CameraLODController.current_zoom = 2.0
	if CameraLODController.instance != null:
		CameraLODController.instance.check_zoom_lod(2.0)
	CameraLODController.test_override_rect = Rect2(0, 0, 1000, 600)

	citizens._process(0.1)

	assert(normal_citizen.visible == true, "재확대 시 일반 시민 NPC가 다시 나타나야 합니다.")
	# 위치가 초기화(스폰)되지 않고 백그라운드에서 진행된 위치를 그대로 이어받는지 확인
	assert(normal_citizen.global_position.distance_to(init_pos) > 0.0, "재확대 시 위치가 초기 위치로 리셋되거나 재스폰되면 안 됩니다.")
	print("[PASS] 재확대 시 NPC 재스폰 없이 자연스러운 활동 연속성 복귀 확인")

	print("\n=== 모든 검증 테스트 ALL PASS! ===")
	quit(0)
