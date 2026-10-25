extends SceneTree

const SpriteCacheManager = preload("res://scripts/autoload/SpriteCacheManager.gd")

## [단위 테스트] NPC 스프라이트 시트 전면 개편 — 대각선 4방향 2모션 보행, 직업별 11종 고유 특수 액션, 신분·성별·연령 다양성 및 FSM 검증

func _init() -> void:
	print("\n=== [TEST] NPC 스프라이트 시트 및 애니메이션 FSM 검증 시작 ===")
	_run_tests()
	quit()

func _run_tests() -> void:
	_test_sprite_cache_sheets()
	_test_citizen_npc_directional_walk()
	_test_citizen_npc_job_actions()
	_test_citizen_manager_diversity()
	_test_patrol_officer_and_special()
	print("\n=== [TEST PASS] 모든 NPC 스프라이트 시트 및 FSM 검증 성공! ===\n")

## 1. 최신 48x48 표준 NPC 스프라이트 및 캐시 검증
func _test_sprite_cache_sheets() -> void:
	print("\n--- 1. 최신 48x48 표준 NPC 스프라이트 등록 및 캐시 검증 ---")
	var scm: Node = SpriteCacheManager.instance
	if scm == null:
		scm = SpriteCacheManager.new()
		root.add_child(scm)

	var std_assets: Array[String] = [
		"npc_artisan_blacksmith", "npc_farmer", "npc_bobusang", "npc_soldier"
	]
	for a_id: String in std_assets:
		var p_tex: String = "res://assets/sprites/npcs/%s.png" % a_id
		assert(ResourceLoader.exists(p_tex) or FileAccess.file_exists(SpriteCacheManager.disk_path(p_tex)), "표준 NPC 텍스처 미존재: %s" % a_id)
	print("[PASS] 최신 48x48 표준 NPC 스프라이트 등록 검증 완료!")

## 2. 대각선 4방향 계산 및 2모션 보행 FSM 검증
func _test_citizen_npc_directional_walk() -> void:
	print("\n--- 2. 대각선 4방향 계산 및 2모션 보행 사이클 검증 ---")
	var npc := CitizenNPC.new("commoner_male")
	npc._setup_nodes()

	# 방향별 프레임 계산 검증
	# UP_LEFT (row 0: frame 0, 1)
	npc.direction = CitizenNPC.WalkDirection.UP_LEFT
	npc.behavior_state = CitizenNPC.NPCBehaviorState.WALKING
	npc.current_frame = 0
	npc._apply_directional_sprite_frame()
	assert(npc.sprite.frame == 0, "UP_LEFT frame 0 실패 (실제: %d)" % npc.sprite.frame)
	npc.current_frame = 1
	npc._apply_directional_sprite_frame()
	assert(npc.sprite.frame == 1, "UP_LEFT frame 1 실패 (실제: %d)" % npc.sprite.frame)

	# UP_RIGHT (row 1: frame 2, 3)
	npc.direction = CitizenNPC.WalkDirection.UP_RIGHT
	npc.current_frame = 0
	npc._apply_directional_sprite_frame()
	assert(npc.sprite.frame == 2, "UP_RIGHT frame 0 실패 (실제: %d)" % npc.sprite.frame)
	npc.current_frame = 1
	npc._apply_directional_sprite_frame()
	assert(npc.sprite.frame == 3, "UP_RIGHT frame 1 실패 (실제: %d)" % npc.sprite.frame)

	# DOWN_LEFT (row 2: frame 4, 5)
	npc.direction = CitizenNPC.WalkDirection.DOWN_LEFT
	npc.current_frame = 0
	npc._apply_directional_sprite_frame()
	assert(npc.sprite.frame == 4, "DOWN_LEFT frame 0 실패 (실제: %d)" % npc.sprite.frame)
	npc.current_frame = 1
	npc._apply_directional_sprite_frame()
	assert(npc.sprite.frame == 5, "DOWN_LEFT frame 1 실패 (실제: %d)" % npc.sprite.frame)

	# DOWN_RIGHT (row 3: frame 6, 7)
	npc.direction = CitizenNPC.WalkDirection.DOWN_RIGHT
	npc.current_frame = 0
	npc._apply_directional_sprite_frame()
	assert(npc.sprite.frame == 6, "DOWN_RIGHT frame 0 실패 (실제: %d)" % npc.sprite.frame)
	npc.current_frame = 1
	npc._apply_directional_sprite_frame()
	assert(npc.sprite.frame == 7, "DOWN_RIGHT frame 1 실패 (실제: %d)" % npc.sprite.frame)

	# 이동 중 대각선 방향 자동 추적 검증
	npc.global_position = Vector2(100.0, 100.0)
	npc.active_path = [Vector2i(2, 5)] # 목적지 월드 좌표 계산
	npc.path_index = 0
	npc._advance_along_path(0.01)
	assert(npc.behavior_state == CitizenNPC.NPCBehaviorState.WALKING, "이동 중 상태가 WALKING이어야 함")

	# 시간 경과에 따른 2모션 애니메이션 루프 검증
	npc.update_visual_animation(0.20, true)
	assert(npc.current_frame == 0 or npc.current_frame == 1, "보행 프레임 순환 오류")

	npc.free()
	print("[PASS] 대각선 4방향 2모션 보행 FSM 정상 작동 확인!")

## 3. 공방 장인 8종, 상인 8종, 신분 12대 계층 고유 특수 액션 애니메이션 FSM 검증
func _test_citizen_npc_job_actions() -> void:
	print("\n--- 3. 공방 장인 8종, 상인 8종, 신분 12대 계층 고유 특수 액션 FSM 검증 ---")
	var jobs: Array[String] = [
		# 공방 장인 8종
		"JOB_BLACKSMITH_FORGE", "JOB_POTTER_WHEEL", "JOB_CARPENTER_PLANE",
		"JOB_WEAVER_LOOM", "JOB_LEATHER_CUT", "JOB_MASON_CHISEL",
		"JOB_PAPER_SCOOP", "JOB_FOUNDRY_POUR",
		# 저잣거리 상인 8종
		"JOB_SILK_DISPLAY", "JOB_FISH_OFFER", "JOB_HERB_WEIGH",
		"JOB_FRUIT_HAWK", "JOB_BOOK_RECITE", "JOB_BRASS_POLISH",
		"JOB_TAVERN_SERVE", "JOB_CATTLE_BARGAIN",
		# 신분 12대 계층
		"JOB_YANGBAN_FAN", "JOB_YANGBAN_SMILE", "JOB_ELDER_BEARD", "JOB_ELDER_CANE",
		"JOB_CHILD_TOP", "JOB_CHILD_JEGI", "JOB_COMMONER_REST", "JOB_COMMONER_BASKET",
		"JOB_ELDER_PIPE", "JOB_ELDER_BACK", "JOB_CHILD_PEBBLE", "JOB_CHILD_FLOWER",
		# 기타 직업
		"JOB_BUILDER_CONSTRUCT", "JOB_BRAWL_FIGHT", "JOB_FISHER_FISH",
		"JOB_MILITARY_DRILL", "JOB_POLICE_PATROL", "JOB_FIRE_EXTINGUISH",
		"JOB_COOK_KITCHEN", "JOB_DRUNK_STAGGER", "JOB_THIEF_STEAL"
	]
	var npc := CitizenNPC.new("merchant_silk")
	npc._setup_nodes()

	for j_act: String in jobs:
		npc.set_job_action(j_act)
		assert(npc.behavior_state == CitizenNPC.NPCBehaviorState.PERFORMING_JOB, "%s 설정 시 상태가 PERFORMING_JOB이어야 함" % j_act)
		assert(npc.job_action_type == j_act, "job_action_type 불일치: %s" % j_act)

		# 특수 액션 프레임 (8 ~ 11) 검증
		for f_idx: int in range(4):
			npc.current_frame = f_idx
			npc._apply_job_action_sprite_frame()
			assert(npc.sprite.frame == 8 + f_idx, "특수 액션 프레임 매핑 오류: %s (프레임: %d, 실제: %d)" % [j_act, 8 + f_idx, npc.sprite.frame])

	npc.free()
	print("[PASS] 고유 특수 액션 %d종 4프레임 FSM(frame 8~11) 정상 작동 확인!" % jobs.size())

## 4. CitizenManager의 신분 12대 직교 계층 다양성 및 업종 매핑 검증
func _test_citizen_manager_diversity() -> void:
	print("\n--- 4. CitizenManager 신분 12대 직교 계층 및 업종별 장인/상인 스폰 헬퍼 검증 ---")
	var mgr := CitizenManager.new()

	# 12대 완전 직교 프로필 생성 검증 (100회 표본)
	var classes_found: Dictionary = {}
	var age_groups_found: Dictionary = {}
	var types_found: Dictionary = {}
	for _i: int in range(150):
		var p: Dictionary = mgr.get_random_citizen_profile()
		var s_cls: String = String(p["social_class"])
		var a_grp: String = String(p["age_group"])
		var t_id: String = String(p["type"])
		classes_found[s_cls] = int(classes_found.get(s_cls, 0)) + 1
		age_groups_found[a_grp] = int(age_groups_found.get(a_grp, 0)) + 1
		types_found[t_id] = int(types_found.get(t_id, 0)) + 1

	assert(classes_found.has("commoner"), "상민 프로필 누락")
	assert(classes_found.has("yangban"), "양반 프로필 누락")
	assert(age_groups_found.has("adult"), "성인 연령군 누락")
	assert(age_groups_found.has("elder"), "노인 연령군 누락")
	assert(age_groups_found.has("child"), "어린이 연령군 누락")
	print("신분 표본 집계 (150회):", classes_found)
	print("연령군 표본 집계 (150회):", age_groups_found)

	# 업종별 고유 장인/상인 헬퍼 검증 (★ 팔달문 우시장 엄수)
	assert(CitizenManager.get_artisan_type_for_trade("smith") == "artisan_blacksmith", "대장간 장인 매핑 실패")
	assert(CitizenManager.get_artisan_type_for_trade("onggi") == "artisan_potter", "옹기가마 장인 매핑 실패")
	assert(CitizenManager.get_artisan_type_for_trade("silk") == "artisan_weaver", "방직 장인 매핑 실패")
	assert(CitizenManager.get_merchant_type_for_trade("silk") == "merchant_silk", "비단전 상인 매핑 실패")
	assert(CitizenManager.get_merchant_type_for_trade("fish") == "merchant_fish", "어물전 상인 매핑 실패")
	assert(CitizenManager.get_merchant_type_for_trade("cattle") == "merchant_cattle", "★ 팔달문 우시장 거간꾼 매핑 실패")

	# spawn_citizen_node 헬퍼 검증
	var yangban_npc: CitizenNPC = mgr.spawn_citizen_node("yangban_male", Vector2i(5, 5))
	assert(yangban_npc.npc_type_id == "yangban_male", "양반 남성 스폰 실패")
	assert(yangban_npc.job_action_type == "JOB_YANGBAN_FAN", "양반 부채질 액션 누락")

	var child_npc: CitizenNPC = mgr.spawn_citizen_node("child_yangban_m", Vector2i(6, 6))
	assert(child_npc.job_action_type == "JOB_CHILD_TOP", "어린이 팽이치기 액션 누락")

	var smith_npc: CitizenNPC = mgr.spawn_citizen_node("artisan_blacksmith", Vector2i(7, 7))
	assert(smith_npc.job_action_type == "JOB_BLACKSMITH_FORGE", "대장장이 모루 액션 누락")

	var cattle_npc: CitizenNPC = mgr.spawn_citizen_node("merchant_cattle", Vector2i(8, 8))
	assert(cattle_npc.job_action_type == "JOB_CATTLE_BARGAIN", "우시장 거간꾼 액션 누락")

	mgr.unregister_npc(yangban_npc)
	mgr.unregister_npc(child_npc)
	mgr.unregister_npc(smith_npc)
	mgr.unregister_npc(cattle_npc)
	yangban_npc.free()
	child_npc.free()
	smith_npc.free()
	cattle_npc.free()
	mgr.free()
	print("[PASS] 신분 12대 직교 다양성 프로필 및 업종별 장인/상인 스폰 헬퍼 정상 작동 확인!")

## 5. PatrolOfficerNPC 및 SpecialEntityManager 연동 검증
func _test_patrol_officer_and_special() -> void:
	print("\n--- 5. PatrolOfficerNPC 및 SpecialEntityManager 연동 검증 ---")
	var officer := PatrolOfficerNPC.new()
	officer.setup_officer(1, Vector2i(20, 20))
	var dummy_parent := Node2D.new()

	var vis: CitizenNPC = officer.get_or_create_visual(dummy_parent)
	assert(vis != null, "포졸 visual_node 생성 실패")
	assert(vis.job_action_type == "JOB_POLICE_PATROL", "포졸 초기 액션이 JOB_POLICE_PATROL이어야 함")
	assert(vis.is_special_entity == true, "포졸은 특수 개체여야 함")

	# 출동 시 보행 전환 검증
	officer.state = PatrolOfficerNPC.OfficerState.DISPATCH
	officer.update_visual_step(0.016)
	assert(vis.behavior_state == CitizenNPC.NPCBehaviorState.WALKING, "출동 시 상태가 WALKING이어야 함")

	# 순찰 대기 시 특수 액션 복귀 검증
	officer.state = PatrolOfficerNPC.OfficerState.IDLE_PATROL
	officer.update_visual_step(0.016)
	assert(vis.behavior_state == CitizenNPC.NPCBehaviorState.PERFORMING_JOB, "순찰 대기 시 상태가 PERFORMING_JOB이어야 함")

	# SpecialEntityManager 식별자 검증
	assert(SpecialEntityManager.is_special_type("patrol_officer"), "patrol_officer 특수 개체 판정 실패")
	assert(SpecialEntityManager.is_special_type("JOB_POLICE_PATROL"), "JOB_POLICE_PATROL 특수 개체 판정 실패")
	assert(SpecialEntityManager.is_special_type("yangban_male"), "yangban_male 특수 개체 판정 실패")
	assert(SpecialEntityManager.is_special_type("brawler"), "brawler 특수 개체 판정 실패")

	vis.free()
	dummy_parent.free()
	print("[PASS] PatrolOfficerNPC FSM 및 SpecialEntityManager 연동 정상 작동 확인!")
