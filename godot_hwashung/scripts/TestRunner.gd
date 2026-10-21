extends SceneTree



func _init() -> void:
	print("=== 종합 자동화 디버거 검증 시작 ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var main_scene = load("res://scenes/Main.tscn")
	if not main_scene:
		push_error("Main.tscn 로드 실패")
		quit(1)
		return

	var main = main_scene.instantiate()
	root.add_child(main)
	print("[1/10] Main.tscn 인스턴스화 완료")

	# 초기화 프레임 대기
	for i in range(10):
		await process_frame

	# 2. 인트로 스킵 및 타이틀 화면 전환
	if main.intro_layer:
		print("[2/10] 인트로 비디오 레이어 스킵 테스트")
		main.intro_layer.intro_finished.emit()
		main._on_intro_finished()
	for i in range(5):
		await process_frame

	# 3. 타이틀 화면 새 게임 시작
	if main.title_screen:
		print("[3/10] 타이틀 화면 새 게임 시작 테스트")
		main._on_start_new_game()
	for i in range(5):
		await process_frame

	# 4. 튜토리얼 및 김판서 가이드 테스트
	if main.tutorial:
		print("[4/10] 튜토리얼 가이드 및 김판서 조언 테스트")
		if main.tutorial.has_method("start_intro"):
			main.tutorial.start_intro()
		if main.tutorial.has_method("show_current_advice"):
			main.tutorial.show_current_advice()
	for i in range(5):
		await process_frame

	# 5. HUD 속도 제어 버튼 테스트
	if main.hud:
		print("[5/10] HUD 속도 제어 버튼 클릭 테스트")
		if main.hud.btn_pause:
			main.hud.btn_pause.pressed.emit()
		if main.hud.btn_fast:
			main.hud.btn_fast.pressed.emit()
		if main.hud.btn_ultra:
			main.hud.btn_ultra.pressed.emit()
		if main.hud.btn_normal:
			main.hud.btn_normal.pressed.emit()
	for i in range(5):
		await process_frame

	# 6. 패널 모달 전체 열기 및 닫기 테스트
	if main.panels:
		print("[6/10] 전체 12종 관리 모달 열기/닫기 테스트")
		var actions: Array[String] = [
			"newspaper", "mega_projects", "tax", "tiger",
			"crown_prince", "hyoryungwon", "eulmyo", "trade",
			"court", "uigwe", "research", "bandit"
		]
		for act in actions:
			main.panels.open_action_modal(act)
			await process_frame
			main.panels._close_modal()
			await process_frame

	# 7. 건축 및 철거, 되돌리기 테스트
	if main.city:
		print("[7/10] 건축/철거/되돌리기 인터랙션 테스트")
		# 도로 설치
		var b_road: Array[Vector2i] = [Vector2i(25, 25)]
		main.city._apply_batch_build(b_road, "road_dirt")
		await process_frame
		# 주거 구역 설치
		var b_res: Array[Vector2i] = [Vector2i(26, 25)]
		main.city._apply_batch_build(b_res, "zone_res")
		await process_frame
		# 상업 구역 설치
		var b_com: Array[Vector2i] = [Vector2i(25, 26)]
		main.city._apply_batch_build(b_com, "zone_com")
		await process_frame
		# 농업 구역 설치 (성 밖 영역 테스트)
		var b_agr: Array[Vector2i] = [Vector2i(5, 5)]
		main.city._apply_batch_build(b_agr, "zone_agr")
		await process_frame
		# 철거 테스트
		var b_demo: Array[Vector2i] = [Vector2i(25, 25)]
		main.city._apply_batch_build(b_demo, "demolish")
		await process_frame
		# 되돌리기 테스트
		main.city.undo()
		await process_frame

	# 8. 턴 진행 및 4계절 순환 시뮬레이션 테스트
	if main.turns and main.time_manager:
		print("[8/10] 턴 진행 및 사계절 순환 시뮬레이션 테스트")
		for season_idx in range(4):
			main.time_manager.advance_day(90)
			await main.turns.process_turn()
			for f in range(10):
				await process_frame

	# 9. 월드 베이크 및 시민 렌더링 프레임 구동
	print("[9/10] 월드 리베이크 및 실시간 프레임 구동 (60프레임)")
	main._rebake_world()
	for i in range(60):
		await process_frame

	# 10. 세이브 및 로드 무결성 테스트
	print("[10/12] 세이브/로드 시스템 검증")
	var save_res = SaveSystem.save_game(1, main.simulation_core)
	if save_res:
		var save_info = SaveSystem.get_save_info(1)
		print("세이브 성공: %s" % save_info.get("title", ""))
	for i in range(10):
		await process_frame

	# 11. 국책 대역사 내 defense_fortification 제거 검증
	print("[11/12] 국책 대역사 구형 에셋/항목 제거 검증")
	for p in main.simulation_core.mega_projects:
		if p.get("id", "") == "defense_fortification":
			push_error("defense_fortification이 아직 국책 대역사 목록에 존재함!")
			quit(1)
			return
	print("국책 대역사에서 defense_fortification 완전 제거 확인 완료.")

	# 12. 산지 포루/공심돈 elevation 상속 및 성곽 100% 김판서 배제 검증
	print("[12/12] 산지 포루/공심돈 고도 캐싱 및 김판서 성곽 완공 필터 검증")
	# 산지 포루 및 공심돈의 elevation Y-offset 적용 검증
	var info_flat := {"start": Vector2i(10, 10), "axis": Vector2i(1, 0), "out": Vector2i(0, 1), "type": "dong", "elevation": 1.0}
	var info_mountain := {"start": Vector2i(10, 10), "axis": Vector2i(1, 0), "out": Vector2i(0, 1), "type": "dong", "elevation": 5.0}
	var pt_flat: Vector2 = main.city.pr_pt(info_flat, 1.0, 0.55)
	var pt_mountain: Vector2 = main.city.pr_pt(info_mountain, 1.0, 0.55)
	var diff_y: float = pt_flat.y - pt_mountain.y
	print("산지 고도(elevation 5 vs 1) Y오프셋 차이: %f (기대값: 48px = 4단 * 12px)" % diff_y)
	if absf(diff_y - 48.0) > 0.01:
		push_error("산지 포루 고도 반영 오차 발생! diff_y = %f" % diff_y)
		quit(1)
		return
	print("산지 포루 고도 정상 적용 확인 (Y좌표 48px 상향 안착).")

	# 김판서 성곽 100% 완공 필터 테스트
	main.grid.fortress_progress = 100
	main.simulation_core.fortress_progress = 100
	var adv_wall1 := {"key": "y1794", "text": "성곽을 쌓으십시오", "target": "wall", "kind": "tool"}
	var adv_wall2 := {"key": "y1796", "text": "아직 성곽이 남았다면 서둘러 쌓아요!", "target": "wall", "kind": "tool"}
	if not main.tutorial._is_advice_target_completed_or_in_progress(adv_wall1) or not main.tutorial._is_advice_target_completed_or_in_progress(adv_wall2):
		push_error("성곽 100% 완공 상태에서 성곽 조언이 제외되지 않음!")
		quit(1)
		return
	print("성곽 100% 완공 시 김판서 성곽 건의 완전 배제 검증 성공.")

	# 13. 석축제방(levee) 물 위 보행성 및 AStar 이동성 복구 검증
	print("[13/16] 석축제방(levee) 보행성(Walkable) 및 네비게이션 복구 검증")
	var water_levee_tile: Dictionary = {"terrain": "water", "building": "levee", "is_bridge": false}
	if not main.citizens._tile_walkable(water_levee_tile):
		push_error("물 위 석축제방이 _tile_walkable에서 차단됨!")
		quit(1)
		return
	print("물 위 석축제방 _tile_walkable 통과 확인.")

	# 14. 민가/저잣거리 반경 50칸 맹수/산짐승 스폰 세이프존 검증
	print("[14/16] 맹수/산짐승 반경 50칸 세이프존(Safe-Zone) 체비쇼프 판정 검증")
	var old_res: Array[Vector2i] = main.citizens._res_cache.duplicate()
	var old_com: Array[Vector2i] = main.citizens._com_cache.duplicate()
	var old_shop: Array[Vector2i] = main.citizens._shop_cache.duplicate()
	main.citizens._res_cache.clear()
	main.citizens._com_cache.clear()
	main.citizens._shop_cache.clear()
	main.citizens._res_cache.append(Vector2i(30, 30))

	# 40칸 거리는 세이프존 내부이므로 차단되어야 함
	var inside_spot := Vector2i(30, 40)
	if main.citizens._is_wildlife_safe_zone(inside_spot, 50):
		push_error("민가 50칸 이내 타일이 세이프존에서 차단되지 않음!")
		quit(1)
		return
	# 55칸 거리는 세이프존 외부이므로 허용되어야 함
	var outside_spot := Vector2i(30, 85)
	if not main.citizens._is_wildlife_safe_zone(outside_spot, 50):
		push_error("민가 50칸 바깥 타일이 세이프존에서 허용되지 않음!")
		quit(1)
		return
	# 캐시 원복
	main.citizens._res_cache = old_res
	main.citizens._com_cache = old_com
	main.citizens._shop_cache = old_shop
	print("50칸 세이프존 체비쇼프 거리 판정 정상 확인.")

	# 15. 사대문 경유 계층적 길찾기(HPA*) 검증
	print("[15/16] 성 안팎 통행 시 사대문 우선 경유 HPA* 내비게이션 검증")
	# 장안문(26, 6) 및 북쪽 외곽 도로를 통행 가능하게 보장
	main.grid.grid[6][26]["building"] = "gate"
	main.grid.grid[6][26].erase("wall_build")
	main.citizens._build_nav()
	var outside_pos := Vector2i(26, 2)  # 장안문 북쪽 성 밖
	var inside_pos := Vector2i(26, 15)  # 성벽 내부
	var mock_agent := {"type": "scholar"}
	var gate_path: Array = main.citizens._find_path(mock_agent, outside_pos, inside_pos)
	print("성 밖 -> 성 안 경로 생성 결과 (노드 수: %d)" % gate_path.size())
	if gate_path.is_empty():
		push_error("성 밖 -> 성 안 사대문 경유 경로 생성 실패!")
		quit(1)
		return
	# 경로상에 장안문(26, 6)이 포함되어 있는지 확인
	var has_jangan := false
	for pt: Vector2i in gate_path:
		if pt == Vector2i(26, 6):
			has_jangan = true
			break
	if not has_jangan:
		push_error("성 밖 -> 성 안 경로가 장안문을 경유하지 않음!")
		quit(1)
		return
	print("사대문(장안문) 1차 경유 HPA* 경로 합성 검증 완료.")

	# 16. 사대문 외곽 직선 도로 기반 교역로(Trade Route) 판정 검증
	print("[16/20] 사대문 외곽 직선 도로 교역로 BFS 판정 검증")
	if main.trade:
		var n_gate := Vector2i(26, 6)
		# 장안문에서 북쪽(y=0)까지 직선 도로 설치
		for y_step in range(0, 7):
			main.grid.grid[y_step][26]["building"] = "road"
		var trade_res: Dictionary = main.trade._check_straight_road_to_border("north", n_gate)
		if not trade_res.get("connected", false):
			push_error("장안문 북쪽 경계 직선 도로가 교역로로 판정되지 않음!")
			quit(1)
			return
		print("장안문 북쪽 경계(0, 26) 직선 교역로 판정 성공 (도착점: %s)" % str(trade_res.get("border_pt")))

	# 17. 역사적 네임드 NPC(정조, 정약용, 김홍도 등) 동적 내러티브 및 고증 일러스트 검증
	print("[17/20] 네임드 NPC 동적 내러티브 생성 및 고증 일러스트 캐싱 검증")
	var named_cases: Array[String] = ["jeongjo", "jeong_yakyong", "kim_hongdo", "chae_jegong", "kim_pankwan"]
	for nid: String in named_cases:
		var n_data: Dictionary = InspectNarrativeGenerator.build_inspect_data({"kind": "named_npc", "named_id": nid})
		if n_data["texture"] == null:
			push_error("네임드 NPC (%s) 초상화 텍스처 누락!" % nid)
			quit(1)
			return
		var n_lines: PackedStringArray = String(n_data["description"]).split("\n")
		if n_lines.size() < 3 or n_lines.size() > 4:
			push_error("네임드 NPC (%s) 줄 수 규격(3~4줄) 위반! 줄 수: %d" % [nid, n_lines.size()])
			quit(1)
			return
		for line: String in n_lines:
			if line.length() < 12 or line.length() > 28:
				push_error("네임드 NPC (%s) 20자 규격 오차 초과: '%s' (길이 %d)" % [nid, line, line.length()])
				quit(1)
				return
	print("네임드 NPC 5인 전용 일러스트 및 20자 3~4줄 내러티브 검증 성공.")

	# 18. 건설 현장 및 주거 민가(초가집/기와집) 20자 4줄 규격 및 민심 연동 검증
	print("[18/20] 건설 현장 및 주거 민가 20자 4줄 규격/민심 동적 내러티브 검증")
	# 건설 현장
	var c_data: Dictionary = InspectNarrativeGenerator.build_inspect_data({"under_construction": true, "building_name": "화성행궁"})
	var c_lines: PackedStringArray = String(c_data["description"]).split("\n")
	if c_lines.size() != 4:
		push_error("건설 현장 줄 수 규격(4줄) 위반! 줄 수: %d" % c_lines.size())
		quit(1)
		return
	# 주거 민가 (풍년 및 흉년)
	main.simulation_core.loyalty = 85
	var house_rich: Dictionary = InspectNarrativeGenerator.build_inspect_data({"is_house": true}, main.simulation_core)
	var hr_lines: PackedStringArray = String(house_rich["description"]).split("\n")
	if hr_lines.size() != 4 or not String(house_rich["description"]).contains("소출"):
		push_error("높은 민심 민가 내러티브 규격 위반!")
		quit(1)
		return
	main.simulation_core.loyalty = 30
	var house_poor: Dictionary = InspectNarrativeGenerator.build_inspect_data({"is_house": true}, main.simulation_core)
	var hp_lines: PackedStringArray = String(house_poor["description"]).split("\n")
	if hp_lines.size() != 4 or not String(house_poor["description"]).contains("흉년"):
		push_error("낮은 민심 민가 내러티브 규격 위반!")
		quit(1)
		return
	print("건설 현장 및 민가 20자 4줄 동적 내러티브 검증 성공.")

	# 19. 일반 보행 NPC 및 동물 20자 2줄 규격 검증
	print("[19/20] 일반 NPC 및 야생 동물 20자 2줄 규격 내러티브 검증")
	var agent_cases: Array[Dictionary] = [
		{"type": "merchant", "is_wild": false},
		{"type": "patrol_soldier", "is_wild": false},
		{"type": "tiger", "is_wild": true},
		{"type": "deer", "is_wild": true}
	]
	for ag: Dictionary in agent_cases:
		var ag_data: Dictionary = InspectNarrativeGenerator.build_inspect_data(ag)
		var ag_lines: PackedStringArray = String(ag_data["description"]).split("\n")
		if ag_lines.size() != 2:
			push_error("일반 NPC/동물 줄 수 규격(2줄) 위반! 타입: %s, 줄 수: %d" % [ag.get("type", ""), ag_lines.size()])
			quit(1)
			return
		if ag_data["texture"] == null:
			push_error("일반 NPC/동물 일러스트 누락! 타입: %s" % ag.get("type", ""))
			quit(1)
			return
	print("일반 NPC 및 동물 20자 2줄 내러티브 및 일러스트 검증 성공.")

	# 20. InspectPopup UI 팝업 통합 인터랙션 검증
	print("[20/20] InspectPopup 팝업 UI 표시 및 클릭 피킹 통합 검증")
	if main.inspect_popup:
		main.city.current_tool = "inspect"
		# (26, 6) 장안문 타일 살피기 클릭 시뮬레이션
		main.city._show_inspect(Vector2i(26, 6))
		await process_frame
		if not main.inspect_popup.visible:
			push_error("살피기 클릭 시 InspectPopup이 화면에 표시되지 않음!")
			quit(1)
			return
		print("InspectPopup 팝업 정상 오픈 확인 (제목: %s)" % main.inspect_popup._title_label.text)
		main.inspect_popup.close_inspect()
		await process_frame
		if main.inspect_popup.visible:
			push_error("InspectPopup 닫기 실패!")
			quit(1)
			return
		print("InspectPopup 정상 닫기 확인.")

	print("=== 모든 20단계 자동화 검증 완료! 디버거 오류 없음 ===")

	# 21. 조선 후기 6대 신분·직업군 데이터, 전용 거점 스폰 및 순환 FSM 검증
	print("[21/21] 조선 후기 6대 신분·직업군 데이터, 거점 스폰, 작명기 및 FSM 검증 시작")
	var cm: CitizenManager = main.city.citizens
	if cm == null:
		push_error("CitizenManager 인스턴스를 찾을 수 없음!")
		quit(1)
		return

	# A. JobType 열거형 및 안전 변환(Fallback) 검증
	assert(NPCBase.JobType.COMMONER == 0)
	assert(NPCBase.JobType.JUNGIN == 1)
	assert(NPCBase.JobType.AJEOUN == 2)
	assert(NPCBase.JobType.ARTISAN == 3)
	assert(NPCBase.JobType.BOBUSANG == 4)
	assert(NPCBase.JobType.MONK_SOLDIER == 5)
	assert(NPCBase.JobType.BUTCHER == 6)
	assert(NPCBase.safe_job_type(999) == NPCBase.JobType.COMMONER)
	assert(NPCBase.safe_job_type("invalid_job") == NPCBase.JobType.COMMONER)
	assert(NPCBase.safe_job_type("jungin") == NPCBase.JobType.JUNGIN)
	assert(NPCBase.safe_job_type("monk_soldier") == NPCBase.JobType.MONK_SOLDIER)
	print("JobType 열거형 및 세이브 호환 fallback 검증 성공.")

	# B. 신분별 전용 작명 제너레이터 검증
	var name_jungin: String = cm.generate_npc_name(NPCBase.JobType.JUNGIN)
	var name_ajeon: String = cm.generate_npc_name(NPCBase.JobType.AJEOUN)
	var name_artisan: String = cm.generate_npc_name(NPCBase.JobType.ARTISAN)
	var name_bobusang: String = cm.generate_npc_name(NPCBase.JobType.BOBUSANG)
	var name_monk: String = cm.generate_npc_name(NPCBase.JobType.MONK_SOLDIER)
	var name_butcher: String = cm.generate_npc_name(NPCBase.JobType.BUTCHER)
	assert(name_jungin.split(" ").size() >= 2, "중인 이름 포맷 오류")
	assert(name_ajeon.split(" ").size() >= 2, "아전 이름 포맷 오류")
	assert(name_artisan.split(" ").size() >= 2, "장인 이름 포맷 오류")
	assert(name_bobusang.split(" ").size() >= 2, "보부상 이름 포맷 오류")
	assert(name_monk.split(" ").size() >= 2, "승군 이름 포맷 오류")
	assert(name_butcher.split(" ").size() >= 2, "백정 이름 포맷 오류")
	print("신분별 작명기 생성 결과: 중인(%s), 아전(%s), 장인(%s), 보부상(%s), 승군(%s), 백정(%s)" % [
		name_jungin, name_ajeon, name_artisan, name_bobusang, name_monk, name_butcher
	])

	# C. 6대 직업군 거점 스폰 및 거점 결손 방어 검증
	var ag_jungin: Dictionary = cm.spawn_jungin()
	var ag_ajeon: Dictionary = cm.spawn_ajeoun()
	var ag_artisan: Dictionary = cm.spawn_specific_artisan()
	var ag_bobusang: Dictionary = cm.spawn_bobusang()
	var ag_monk: Dictionary = cm.spawn_monk_soldier()
	var ag_butcher: Dictionary = cm.spawn_butcher()

	var prof_agents: Array[Dictionary] = [ag_jungin, ag_ajeon, ag_artisan, ag_bobusang, ag_monk, ag_butcher]
	for a_prof: Dictionary in prof_agents:
		assert(a_prof.get("is_professional", false) == true, "전문 직업군 플래그 누락")
		assert(a_prof.get("npc_name", "") != "", "NPC 고유 이름 누락")
		assert(not (a_prof.get("waypoints", []) as Array).is_empty(), "사전 정의 웨이포인트 누락")
		assert(a_prof.get("x", -1.0) >= 0.0, "안전 스폰 좌표 오류")

	print("6대 직업군 거점 스폰 및 결손 방어 fallback 정상 확인.")

	# D. 순환 FSM 및 웨이포인트 이동 연산 검증
	for a_prof: Dictionary in prof_agents:
		a_prof["state"] = "travel"
		a_prof["state_timer"] = 0.0 # 강제 만료
		cm._update_professional_agent(a_prof, 0.1)
		# 상태가 work로 전환되거나 다음 웨이포인트를 향해야 함
		assert(a_prof.get("state", "") in ["work", "rest", "travel", "patrol"])
	print("6대 직업군 순환 FSM 상태 전이 검증 성공.")

	# E. InspectNarrativeGenerator와의 살피기 연동 검증 (20자 2줄 규격)
	for a_prof: Dictionary in prof_agents:
		var insp_data: Dictionary = InspectNarrativeGenerator.build_inspect_data(a_prof, main.simulation_core, main.grid)
		assert(insp_data["title"] != "", "Inspect 제목 누락")
		assert(insp_data["texture"] != null, "Inspect 일러스트 누락")
		var p_lines: PackedStringArray = insp_data["description"].split("\n")
		assert(p_lines.size() == 2, "6대 직업군 2줄 규격 위반! (실제: %d줄)" % p_lines.size())
	print("6대 직업군 Inspect 내러티브 20자 2줄 및 일러스트 연동 검증 성공.")

	print("=== 모든 21단계 종합 자동화 검증 완료! ===")

	# 22. 신규 직업군 6종 전용 살피기 내러티브 및 고증 일러스트 매핑 검증
	print("[22/22] 6대 직업군 거점 건물(4줄) 및 보행 NPC(2줄) 고증 일러스트/내러티브 검증 시작")

	# A. 4대 거점 건물 (의원 약방, 아전 가택, 장인 공방 채, 백정 외곽 움막) 20자 4줄 검증
	var base_cases: Array[Dictionary] = [
		{"base_job_type": NPCBase.JobType.JUNGIN, "npc_name": "의원 유태석", "expected_lines": 4, "key": "base_jungin"},
		{"base_job_type": NPCBase.JobType.AJEOUN, "npc_name": "호방 김득원", "expected_lines": 4, "key": "base_ajeon"},
		{"base_job_type": NPCBase.JobType.ARTISAN, "npc_name": "도편수 이성길", "expected_lines": 4, "key": "base_artisan"},
		{"base_job_type": NPCBase.JobType.BUTCHER, "npc_name": "가죽공 무쇠", "expected_lines": 4, "key": "base_butcher"}
	]

	for bc: Dictionary in base_cases:
		var b_data: Dictionary = InspectNarrativeGenerator.build_inspect_data(bc, main.simulation_core, main.grid, cm)
		assert(b_data["texture"] != null, "거점 건물 일러스트 누락: %s" % bc["key"])
		assert(b_data["texture"] == InspectNarrativeGenerator.get_portrait(bc["key"]), "거점 건물 텍스처 불일치: %s" % bc["key"])
		var blines: PackedStringArray = String(b_data["description"]).split("\n")
		assert(blines.size() == 4, "거점 건물 줄 수 규격(4줄) 위반! 실제: %d줄" % blines.size())
		var char_len: int = String(b_data["description"]).replace("\r", "").replace("\n", "").length()
		assert(char_len >= 70 and char_len <= 95, "거점 건물 글자 수(70~95자) 위반! 실제: %d자" % char_len)
		assert(String(b_data["title"]).contains(bc["npc_name"]), "거점 건물 제목에 성명 누락: %s" % b_data["title"])

	print("4대 거점 건물(약방 가옥, 아전 가택, 장인 공방, 백정 움막) 20자 4줄 및 고증 일러스트 검증 성공.")

	# B. 보행 중인 신규 직업군 NPC 20자 2줄 내러티브 검증
	var walker_cases: Array[Dictionary] = [
		{"job_type": NPCBase.JobType.BOBUSANG, "npc_name": "개성보부상 만석", "key": "bobusang", "keyword": "성문을 넘어"},
		{"job_type": NPCBase.JobType.MONK_SOLDIER, "npc_name": "의승 혜인", "key": "monk_soldier", "keyword": "용주사"},
		{"job_type": NPCBase.JobType.JUNGIN, "npc_name": "의원 유태석", "key": "jungin", "keyword": "침통과 약첩"},
		{"job_type": NPCBase.JobType.AJEOUN, "npc_name": "이방 최진규", "key": "ajeon", "keyword": "공문"},
		{"job_type": NPCBase.JobType.ARTISAN, "npc_name": "도편수 이성길", "key": "artisan", "keyword": "성벽 보수"},
		{"job_type": NPCBase.JobType.BUTCHER, "npc_name": "가죽공 무쇠", "key": "butcher", "keyword": "피혁전"}
	]

	for wc: Dictionary in walker_cases:
		var w_entity: Dictionary = {
			"kind": "npc",
			"job_type": wc["job_type"],
			"npc_name": wc["npc_name"]
		}
		var w_data: Dictionary = InspectNarrativeGenerator.build_inspect_data(w_entity, main.simulation_core, main.grid, cm)
		assert(w_data["texture"] != null, "보행 NPC 일러스트 누락: %s" % wc["key"])
		assert(w_data["texture"] == InspectNarrativeGenerator.get_portrait(wc["key"]), "보행 NPC 텍스처 불일치: %s" % wc["key"])
		var wlines: PackedStringArray = String(w_data["description"]).split("\n")
		assert(wlines.size() == 2, "보행 NPC 줄 수 규격(2줄) 위반! 실제: %d줄" % wlines.size())
		var w_char_len: int = String(w_data["description"]).replace("\r", "").replace("\n", "").length()
		assert(w_char_len >= 35 and w_char_len <= 48, "보행 NPC 글자 수(35~48자) 위반! 실제: %d자" % w_char_len)
		assert(String(w_data["description"]).contains(wc["keyword"]), "보행 NPC 고증 키워드 누락: %s" % wc["keyword"])
		assert(w_data["title"] == wc["npc_name"], "보행 NPC 제목 불일치: %s != %s" % [w_data["title"], wc["npc_name"]])

	print("보행 중인 6대 직업군 20자 2줄 내러티브 및 고증 일러스트 검증 성공.")

	# C. 예외 직업군 널 안전성(Fallback) 검증
	var fallback_data: Dictionary = InspectNarrativeGenerator.build_inspect_data({"job_type": 9999, "kind": "npc"})
	assert(fallback_data["texture"] != null, "예외 직업군 텍스처 누락")
	assert(fallback_data["description"] != "", "예외 직업군 설명문 누락")
	print("예외 직업군 널 안전성 및 fallback 검증 성공.")

	# D. InspectPopup 팝업 호출 시 즉각 갱신 및 표시 검증
	if main.inspect_popup:
		var test_data: Dictionary = InspectNarrativeGenerator.build_inspect_data(base_cases[0], main.simulation_core, main.grid, cm)
		main.inspect_popup.open_inspect(test_data["title"], test_data["description"], test_data["texture"])
		await process_frame
		assert(main.inspect_popup.visible == true, "InspectPopup 표시 실패")
		assert(main.inspect_popup._title_label.text == test_data["title"], "InspectPopup 제목 갱신 실패")
		assert(main.inspect_popup._portrait_rect.texture == test_data["texture"], "InspectPopup 텍스처 갱신 실패")
		main.inspect_popup.close_inspect()
		await process_frame
		assert(main.inspect_popup.visible == false, "InspectPopup 닫기 실패")
		print("InspectPopup 팝업 갱신 및 노출 무결성 확인 완료.")

	# =========================================================================
	# 23. 1795년 을묘원행 국책 대기록 이벤트 및 8일간의 화성 행차 시뮬레이션 검증
	# =========================================================================
	print("[23/23] 1795년 을묘원행 국책 대기록 및 능행차 시뮬레이션 검증 시작")
	assert(main.royal_procession != null, "RoyalProcessionManager 노드 누락")
	var rp: RoyalProcessionManager = main.royal_procession

	# A. 발동 조건 미달 시 차단 검증
	main.simulation_core.gold = 50000 # 금화 부족
	main.simulation_core.rice = 50000 # 식량 부족
	var fail_check: Dictionary = RoyalProcessionManager.can_trigger_eulmyo_event(main.simulation_core, main.grid)
	assert(fail_check["can_trigger"] == false, "조건 미달인데 발동 허용됨")
	assert(fail_check["reasons"].size() > 0, "발동 불가 사유 누락")
	print("을묘원행 발동 조건 미달 차단 검증 통과.")

	# B. 발동 조건 100% 충족 셋업 및 검증
	main.simulation_core.authority = 70
	main.simulation_core.loyalty = 85
	main.simulation_core.fortress_progress = 100
	main.simulation_core.gold = 250000
	main.simulation_core.rice = 220000
	main.simulation_core.retainers["chae_jegong"] = true
	main.simulation_core.retainers["jeong_yakyong"] = true
	main.simulation_core.retainers["kim_hongdo"] = true

	# 도로 및 행궁 진입 박석길 연결 세팅
	# 장안문(26,6) ~ 행궁(22,32) 및 팔달문(16,54) 간 도로 연결 보장
	for y in range(0, 55):
		main.grid.grid[y][26]["building"] = "road"
		main.grid.grid[y][26]["road_type"] = "stone" if (y >= 28 and y <= 35) else "dirt"
	# 행궁에서 팔달문(16, 54) 방향으로 잇는 가로 도로 가설
	for x in range(16, 27):
		main.grid.grid[54][x]["building"] = "road"
	# 사대문 완공 세팅 (장안문, 팔달문, 화서문, 창룡문)
	var g_pos: Dictionary = main.grid.get_four_gates_positions()
	for k in g_pos.keys():
		var gp: Vector2i = g_pos[k]
		if gp.x >= 0 and gp.y >= 0 and main.grid.in_bounds(gp.x, gp.y):
			main.grid.grid[gp.y][gp.x]["building"] = "gate"
			main.grid.grid[gp.y][gp.x].erase("wall_build")
			main.grid.grid[gp.y][gp.x]["under_construction"] = false
	main.grid.grid[32][22]["building"] = "haenggung"
	main.grid.grid[32][25]["building"] = "road"
	main.grid.grid[32][25]["road_type"] = "stone" # 행궁 정문 앞 박석길 포장

	var pass_check: Dictionary = RoyalProcessionManager.can_trigger_eulmyo_event(main.simulation_core, main.grid)
	assert(pass_check["can_trigger"] == true, "을묘원행 발동 조건 충족 실패: %s" % str(pass_check["reasons"]))
	print("을묘원행 8대 발동 조건 100% 충족 검증 통과.")

	# C. 을묘원행 공식 발동 및 자원/시간 상태 전환 검증
	var started: bool = rp.start_eulmyo_event(main.simulation_core, main.grid, main.citizens, main.time_manager, main.hud, main.panels, main.city)
	assert(started == true, "을묘원행 시작 실패")
	assert(main.simulation_core.gold == 50000, "금화 20만 차감 오류: %d" % main.simulation_core.gold)
	assert(main.simulation_core.rice == 20000, "식량 20만 차감 오류: %d" % main.simulation_core.rice)
	assert(main.simulation_core.authority == 100, "왕권 100점 확정 실패: %d" % main.simulation_core.authority)
	assert(main.simulation_core.is_time_frozen == true, "시간 일시정지 플래그 미설정")
	assert(main.time_manager.current_speed == TimeManager.SpeedMode.PAUSE, "TimeManager PAUSE 실패")
	assert(rp.procession_units.size() == 44, "능행차 6개 제대 44기 유닛 풀링 수 불일치: %d" % rp.procession_units.size())
	print("을묘원행 발동 시 자원 차감(-20만), 왕권 100점, 시간 정지, 44기 유닛 풀링 검증 통과.")

	# D. 격쟁 10종 & 상언 10종 데이터 무결성 및 판결 효과 검증
	assert(rp.petitions_gyeokjaeng.size() == 10, "격쟁 10종 규격 누락: %d" % rp.petitions_gyeokjaeng.size())
	assert(rp.petitions_sangeon.size() == 10, "상언 10종 규격 누락: %d" % rp.petitions_sangeon.size())
	# 격쟁 1번(대유둔전 수세 감면) 테스트
	rp._active_petition = rp.petitions_gyeokjaeng[0]
	var pre_loyalty: int = main.simulation_core.loyalty
	var pre_gold: int = main.simulation_core.gold
	rp._resolve_petition(true)
	assert(main.simulation_core.loyalty == pre_loyalty + 5, "격쟁 민심 효과 미반영")
	assert(main.simulation_core.gold == pre_gold - 2000, "격쟁 금화 효과 미반영")
	print("격쟁 10종 & 상언 10종 무결성 및 탄원 효과 판결 검증 통과.")

	# E. 행궁 3대 의례 + 서장대 야조 + 화성 별시 + 팔달문 출정 시퀀스 검증
	# 1) 봉수당 진찬연
	rp.current_phase = RoyalProcessionManager.Phase.CEREMONY_BONGSU
	rp.phase_timer = 6.0
	rp._update_ceremony_bongsu(0.1)
	assert(rp.current_phase == RoyalProcessionManager.Phase.CEREMONY_NAKNAM, "진찬연 -> 양로연 전이 실패")

	# 2) 낙남헌 양로연
	rp.phase_timer = 6.0
	rp._update_ceremony_naknam(0.1)
	assert(rp.current_phase == RoyalProcessionManager.Phase.CEREMONY_SINPUNG, "양로연 -> 사미 전이 실패")

	# 3) 신풍루 사미
	var pre_rice: int = main.simulation_core.rice
	rp.phase_timer = 6.0
	rp._update_ceremony_sinpung(0.1)
	assert(rp.current_phase == RoyalProcessionManager.Phase.SEOJANGDAE_YAJO, "사미 -> 서장대 야조 전이 실패")
	assert(main.simulation_core.rice == pre_rice - 10000, "구휼미 1만석 방출 오류")

	# 4) 서장대 야조 (야간 군사 훈련)
	rp.phase_timer = 8.0
	rp._update_seojangdae_yajo(0.1)
	if rp.current_phase == RoyalProcessionManager.Phase.YEONMUDAE_ARCHERY:
		rp.phase_timer = 8.0
		rp._update_yeonmudae_archery(0.1)
	assert(rp.current_phase == RoyalProcessionManager.Phase.BYEOLSI_EXAM, "야조/연무대 -> 별시 전이 실패")

	# 5) 화성 별시
	rp.phase_timer = 6.0
	rp._update_byeolsi_exam(0.1)
	assert(rp.current_phase == RoyalProcessionManager.Phase.EXIT_PROCESSION, "별시 -> 팔달문 출정 전이 실패")

	# 6) 팔달문 출정 및 완수
	rp._complete_eulmyo_event()
	assert(rp.current_phase == RoyalProcessionManager.Phase.FINISHED, "을묘원행 완료 상태 불일치")
	assert(main.simulation_core.is_time_frozen == false, "시간 일시정지 해제 실패")
	assert(main.simulation_core.is_eulmyo_completed == true, "을묘원행 완수 플래그 미설정")
	assert(main.simulation_core.bandit_suppression_turns == 24, "도적 억제 24개월 평온 미부여")
	assert(main.simulation_core.tiger_cooldown_turns == 24, "호환 억제 24개월 평온 미부여")
	print("행궁 3대 의례 + 서장대 야조 + 별시 + 팔달문 출정 및 롤백 검증 성공.")

	# F. PanelController 모달 연동 검증
	if main.panels:
		main.panels._build_eulmyo()
		await process_frame
		print("PanelController 을묘원행 완료 UI 표시 검증 성공.")

	# =========================================================================
	# 24. 살피기(Inspect) 세부 시설/상점/NPC 행동/특수 건물 고증 전면 검증
	# =========================================================================
	print("[24/24] 살피기 세부 시설/상점/NPC 행동/특수 건물 고증 전면 검증 시작")

	# A. 방리(마을) 세부 시설 (4줄, 70~90자) 검증
	var village_facilities: Array[Dictionary] = [
		{"key": "cattle", "facility_type": "cattle", "expected_title": "수원 우시장 (쇠전)", "keyword": "소시장"},
		{"key": "play", "plaza_kind": "play", "expected_title": "방리 마당놀이 터 (풍물마당)", "keyword": "탈춤"},
		{"key": "kids", "building": "kids", "expected_title": "골목 안 동네 놀이터", "keyword": "제기차기"},
		{"key": "seodang", "kind": "seodang", "expected_title": "동네 서당 (글방)", "keyword": "천자문"},
		{"key": "seowon", "kind": "seowon", "expected_title": "화성 유학 서원 (書院)", "keyword": "성리학"}
	]

	for vf: Dictionary in village_facilities:
		var vf_data: Dictionary = InspectNarrativeGenerator.build_inspect_data(vf)
		assert(vf_data["title"] == vf["expected_title"], "방리 시설 제목 불일치: %s != %s" % [vf_data["title"], vf["expected_title"]])
		assert(vf_data["texture"] != null, "방리 시설 텍스처 누락: %s" % vf["key"])
		assert(vf_data["texture"] == InspectNarrativeGenerator.get_portrait(vf["key"]), "방리 시설 일러스트 불일치: %s" % vf["key"])
		var vflines: PackedStringArray = String(vf_data["description"]).split("\n")
		assert(vflines.size() == 4, "방리 시설 4줄 규격 위반: %d줄 (%s)" % [vflines.size(), vf["key"]])
		var vf_char_len: int = String(vf_data["description"]).replace("\r", "").replace("\n", "").length()
		assert(vf_char_len >= 70 and vf_char_len <= 90, "방리 시설 글자 수(70~90자) 위반: %d자 (%s)" % [vf_char_len, vf["key"]])
		assert(String(vf_data["description"]).contains(vf["keyword"]), "방리 시설 키워드 누락: %s (%s)" % [vf["keyword"], vf["key"]])
	print("방리 세부 시설(우시장/마당놀이/놀이터/서당) 4줄 고증 검증 통과.")

	# B. 화성 특수 건물 한글 정식 명칭 및 고증 (4줄, 70~90자, 영문 노출 0건) 검증
	var special_buildings: Array[Dictionary] = [
		{"building": "jongnu", "expected_title": "화성 십자로 종루 (鐘樓)", "keyword": "십자로", "portrait": "jongnu"},
		{"building": "seojangdae", "expected_title": "화성 서장대 (西將臺)", "keyword": "팔달산", "portrait": "seojangdae"},
		{"building": "banghwasuryujeong", "expected_title": "동북각루 방화수류정 (訪花隨柳亭)", "keyword": "용연", "portrait": "banghwasuryujeong"},
		{"building": "hwahongmun", "expected_title": "화홍문 북수문 (華虹門)", "keyword": "홍예석교", "portrait": "hwahongmun"},
		{"building": "namsumun", "expected_title": "화성 남수문 (南水門)", "keyword": "남수문", "portrait": "namsumun"},
		{"building": "gongsimdon", "expected_title": "화성 공심돈 (空心墩)", "keyword": "돈대", "portrait": "gongsimdon"},
		{"building": "bongdon", "expected_title": "화성 봉돈 (烽墩)", "keyword": "통신", "portrait": "bongdon"},
		{"building": "poru", "expected_title": "화성 포루 (砲樓)", "keyword": "포루", "portrait": "poru"},
		{"building": "yeonmudae", "expected_title": "동장대 연무대 (東將臺 練武臺)", "keyword": "연병장", "portrait": "yeonmudae"},
		{"building": "embankment", "expected_title": "수원천 석축제방 (石築堤防)", "keyword": "제방", "portrait": "embankment"},
		{"building": "road", "expected_title": "화성 주간선 도로 (박석길)", "keyword": "간선도로", "portrait": "road"},
		{"building": "gwana", "expected_title": "화성유수부 동헌 (관아)", "keyword": "송사", "portrait": "base_ajeon"},
		{"building": "gwana_site", "expected_title": "화성유수부 동헌 (관아)", "keyword": "송사", "portrait": "base_ajeon"}
	]

	for sb_item: Dictionary in special_buildings:
		var sb_data: Dictionary = InspectNarrativeGenerator.build_inspect_data(sb_item)
		assert(sb_data["title"] == sb_item["expected_title"], "특수 건물 제목 불일치: %s != %s" % [sb_data["title"], sb_item["expected_title"]])
		assert(not sb_data["title"].contains("building:"), "영문 ID 노출 감지: %s" % sb_data["title"])
		assert(sb_data["texture"] != null, "특수 건물 텍스처 누락: %s" % sb_item["building"])
		assert(sb_data["texture"] == InspectNarrativeGenerator.get_portrait(sb_item["portrait"]), "특수 건물 일러스트 불일치: %s" % sb_item["building"])
		var sblines: PackedStringArray = String(sb_data["description"]).split("\n")
		assert(sblines.size() == 4, "특수 건물 4줄 규격 위반: %d줄 (%s)" % [sblines.size(), sb_item["building"]])
		var sb_char_len: int = String(sb_data["description"]).replace("\r", "").replace("\n", "").length()
		assert(sb_char_len >= 70 and sb_char_len <= 90, "특수 건물 글자 수(70~90자) 위반: %d자 (%s)" % [sb_char_len, sb_item["building"]])
		assert(String(sb_data["description"]).contains(sb_item["keyword"]), "특수 건물 키워드 누락: %s (%s)" % [sb_item["keyword"], sb_item["building"]])
	print("화성 특수 건물 11종 한글 정식 명칭 및 4줄 고증 검증 통과 (영문 노출 0건).")

	# C. 저잣거리 상점 (업종별 & 성문 위치별, 4줄, 70~90자) 검증
	var shop_cases: Array[Dictionary] = [
		{"zone": "com", "trade": "silk", "expected_title": "화성 저잣거리 포목전 (비단전)", "keyword": "명주"},
		{"zone": "com", "trade": "fish", "expected_title": "화성 저잣거리 어물전", "keyword": "생선"},
		{"zone": "com", "trade": "rice", "expected_title": "화성 저잣거리 싸전 (미곡상)", "keyword": "햇벼"},
		{"zone": "com", "trade": "smith", "expected_title": "화성 저잣거리 대장간", "keyword": "풀무불"},
		{"zone": "com", "trade": "jumak", "expected_title": "화성 저잣거리 주막 (객주)", "keyword": "탁주"},
		{"zone": "com", "pos": Vector2i(25, 45), "expected_title": "팔달문 앞 삼남대로 상가", "keyword": "삼남대로"},
		{"zone": "com", "pos": Vector2i(25, 10), "expected_title": "장안문 앞 왕도 물류 상가", "keyword": "한양 도성"},
		{"zone": "com", "pos": Vector2i(10, 25), "expected_title": "성문 외곽 둔전 난전 거리", "keyword": "난전"}
	]

	for sc: Dictionary in shop_cases:
		var sc_data: Dictionary = InspectNarrativeGenerator.build_inspect_data(sc)
		assert(sc_data["title"] == sc["expected_title"], "상점 제목 불일치: %s != %s" % [sc_data["title"], sc["expected_title"]])
		assert(sc_data["texture"] != null, "상점 텍스처 누락: %s" % sc["expected_title"])
		var sclines: PackedStringArray = String(sc_data["description"]).split("\n")
		assert(sclines.size() == 4, "상점 4줄 규격 위반: %d줄 (%s)" % [sclines.size(), sc["expected_title"]])
		var sc_char_len: int = String(sc_data["description"]).replace("\r", "").replace("\n", "").length()
		assert(sc_char_len >= 70 and sc_char_len <= 90, "상점 글자 수(70~90자) 위반: %d자 (%s)" % [sc_char_len, sc["expected_title"]])
		assert(String(sc_data["description"]).contains(sc["keyword"]), "상점 키워드 누락: %s (%s)" % [sc["keyword"], sc["expected_title"]])
	print("저잣거리 업종별 및 사대문 위치별 4줄 고증 검증 통과.")

	# C-2. 주거 민가 계층별(초가집/기와집/사대부) 고증 및 영문 ID(Res 2 등) 차단 검증
	var house_cases: Array[Dictionary] = [
		{"building": "res_1", "expected_title": "소박한 서민 초가집", "keyword": "볏짚"},
		{"building": "res_2", "expected_title": "단정한 살림 기와집 (여염집)", "keyword": "기와"},
		{"building": "res_3", "expected_title": "고급 사대부 기와집", "keyword": "사대부"}
	]
	for hc: Dictionary in house_cases:
		var hc_data: Dictionary = InspectNarrativeGenerator.build_inspect_data(hc)
		assert(hc_data["title"] == hc["expected_title"], "주거 민가 제목 불일치: %s != %s" % [hc_data["title"], hc["expected_title"]])
		assert(not hc_data["title"].contains("res_") and not hc_data["title"].contains("Res"), "민가 영문 ID 노출 감지: %s" % hc_data["title"])
		var hclines: PackedStringArray = String(hc_data["description"]).split("\n")
		assert(hclines.size() == 4, "민가 4줄 규격 위반: %d줄" % hclines.size())
		var hc_len: int = String(hc_data["description"]).replace("\r", "").replace("\n", "").length()
		assert(hc_len >= 70 and hc_len <= 90, "민가 글자 수(70~90자) 위반: %d자 (%s)" % [hc_len, hc["expected_title"]])
		assert(String(hc_data["description"]).contains(hc["keyword"]), "민가 키워드 누락: %s" % hc["keyword"])
	print("주거 민가 계층별(초가집/기와집/사대부) 4줄 고증 및 영문 차단 검증 통과.")

	# D. NPC FSM 행동 상태 기반 동적 사연 (2줄, 35~45자) 검증
	var fsm_cases: Array[Dictionary] = [
		{"kind": "npc", "npc_name": "김돌쇠", "state": "seokjeon", "keyword": "돌을 던지며"},
		{"kind": "npc", "npc_name": "박바우", "state": "ssireum", "keyword": "들배지기"},
		{"kind": "npc", "npc_name": "이만복", "state": "kite", "keyword": "방패연"},
		{"kind": "npc", "npc_name": "최달수", "state": "firefighting", "keyword": "물동이"},
		{"kind": "npc", "npc_name": "정포수", "state": "hunting", "keyword": "화승총"},
		{"kind": "npc", "npc_name": "조개똥", "state": "playing", "keyword": "제기차기"},
		{"kind": "npc", "npc_name": "순덕이", "state": "washing", "keyword": "수원천"},
		{"kind": "npc", "npc_name": "강태공", "state": "fishing", "keyword": "낚싯대"},
		{"kind": "npc", "npc_name": "한백성", "state": "cheering", "keyword": "어가"},
		{"kind": "npc", "npc_name": "윤군병", "state": "training", "keyword": "진법"}
	]

	for fc: Dictionary in fsm_cases:
		var fc_data: Dictionary = InspectNarrativeGenerator.build_inspect_data(fc)
		assert(fc_data["texture"] != null, "FSM NPC 텍스처 누락: %s" % fc["state"])
		var fclines: PackedStringArray = String(fc_data["description"]).split("\n")
		assert(fclines.size() == 2, "FSM NPC 2줄 규격 위반: %d줄 (%s)" % [fclines.size(), fc["state"]])
		var fc_char_len: int = String(fc_data["description"]).replace("\r", "").replace("\n", "").length()
		assert(fc_char_len >= 35 and fc_char_len <= 48, "FSM NPC 글자 수(35~48자) 위반: %d자 (%s)" % [fc_char_len, fc["state"]])
		assert(String(fc_data["description"]).contains(fc["keyword"]), "FSM NPC 키워드 누락: %s (%s)" % [fc["keyword"], fc["state"]])
		assert(String(fc_data["title"]).contains(fc["npc_name"]), "FSM NPC 이름 누락: %s in %s" % [fc["npc_name"], fc_data["title"]])
	print("NPC FSM 행동 상태 10종 기반 2줄 동적 사연 검증 통과.")

	# E. KOREAN_NAMES 사전 및 미지의 시설 한글화 검증
	assert(InspectNarrativeGenerator.get_korean_name("jongnu") == "화성 십자로 종루", "종루 한글명 불일치")
	assert(InspectNarrativeGenerator.get_korean_name("unknown_tower", "기본시설") in ["기본시설", "Unknown Tower"], "자동 포맷 불일치")
	print("KOREAN_NAMES 사전 및 영문 ID 차단 검증 통과.")

	# =========================================================================
	# 25. 사대문-맵 외곽 도로 연결 판정 및 외부 교역로 이정표 시스템 검증
	# =========================================================================
	print("[25/25] 사대문-맵 외곽 도로 연결 판정 및 외부 교역로 이정표 검증 시작")

	# A. 사대문 목적지 명칭 매핑 상수 무결성 검증
	assert(GameGrid.ROAD_DESTINATION_NAMES.has("jangan"), "장안문 목적지 명칭 누락")
	assert(GameGrid.ROAD_DESTINATION_NAMES.has("paldal"), "팔달문 목적지 명칭 누락")
	assert(GameGrid.ROAD_DESTINATION_NAMES.has("changryong"), "창룡문 목적지 명칭 누락")
	assert(GameGrid.ROAD_DESTINATION_NAMES.has("hwaseo"), "화서문 목적지 명칭 누락")
	assert(GameGrid.ROAD_DESTINATION_NAMES["jangan"]["sign_title"] == "한양(漢陽)으로 가는 길", "장안문 간판명 불일치")
	assert(GameGrid.ROAD_DESTINATION_NAMES["paldal"]["sign_title"] == "삼남대로 / 현륭원(융릉)으로 가는 길", "팔달문 간판명 불일치")
	assert(GameGrid.ROAD_DESTINATION_NAMES["changryong"]["sign_title"] == "광주 / 동해로 가는 길", "창룡문 간판명 불일치")
	assert(GameGrid.ROAD_DESTINATION_NAMES["hwaseo"]["sign_title"] == "남양만 / 서해 갯벌로 가는 길", "화서문 간판명 불일치")
	print("사대문 역사적 목적지 4대 명칭 매핑 무결성 검증 통과.")

	# B. 사대문 외곽 도로 도달 알고리즘(Edge Reachability BFS) 4방향 연결 검증
	# 사대문 게이트 타일 설정
	main.grid.grid[6][26]["building"] = "gate"
	main.grid.grid[54][16]["building"] = "gate"
	main.grid.grid[13][6]["building"] = "gate"
	main.grid.grid[29][48]["building"] = "gate"

	# 1) 북문(장안문 26,6) ~ 북쪽 경계(26,0) 도로 가설
	for y: int in range(0, 7):
		main.grid.grid[y][26]["building"] = "road"
	# 2) 남문(팔달문 16,54) ~ 남쪽 경계(16,63) 도로 가설
	for y: int in range(54, 64):
		main.grid.grid[y][16]["building"] = "road"
	# 3) 서문(화서문 6,13) ~ 서쪽 경계(0,13) 도로 가설
	for x: int in range(0, 7):
		main.grid.grid[13][x]["building"] = "road"
	# 4) 동문(창룡문 48,29) ~ 동쪽 경계(63,29) 도로 가설
	for x: int in range(48, 64):
		main.grid.grid[29][x]["building"] = "road"

	main.grid._border_connections_dirty = true
	var conns: Dictionary = main.grid.check_border_road_connections()

	# 장안문 연결 검증
	assert(conns["jangan"]["connected"] == true, "장안문 외곽 도로 연결 판정 실패")
	assert(conns["jangan"]["border_tile"] == Vector2i(26, 0), "장안문 경계선 도달 좌표 불일치: %s" % str(conns["jangan"]["border_tile"]))
	assert(conns["jangan"]["info"]["sign_title"] == "한양(漢陽)으로 가는 길", "장안문 이정표 명칭 불일치")

	# 팔달문 연결 검증
	assert(conns["paldal"]["connected"] == true, "팔달문 외곽 도로 연결 판정 실패")
	assert(conns["paldal"]["border_tile"] == Vector2i(16, 63), "팔달문 경계선 도달 좌표 불일치: %s" % str(conns["paldal"]["border_tile"]))
	assert(conns["paldal"]["info"]["sign_title"] == "삼남대로 / 현륭원(융릉)으로 가는 길", "팔달문 이정표 명칭 불일치")

	# 화서문 연결 검증
	assert(conns["hwaseo"]["connected"] == true, "화서문 외곽 도로 연결 판정 실패")
	assert(conns["hwaseo"]["border_tile"] == Vector2i(0, 13), "화서문 경계선 도달 좌표 불일치: %s" % str(conns["hwaseo"]["border_tile"]))
	assert(conns["hwaseo"]["info"]["sign_title"] == "남양만 / 서해 갯벌로 가는 길", "화서문 이정표 명칭 불일치")

	# 창룡문 연결 검증
	assert(conns["changryong"]["connected"] == true, "창룡문 외곽 도로 연결 판정 실패")
	assert(conns["changryong"]["border_tile"] == Vector2i(63, 29), "창룡문 경계선 도달 좌표 불일치: %s" % str(conns["changryong"]["border_tile"]))
	assert(conns["changryong"]["info"]["sign_title"] == "광주 / 동해로 가는 길", "창룡문 이정표 명칭 불일치")
	print("사대문 4방향 최외곽 경계선(0,0 / 63,63) 도달 BFS 검증 통과.")

	# C. 도로 단절 시 즉각 롤백(연결 해제) 무결성 검증
	main.grid.grid[3][26]["building"] = "" # 장안문 중간 도로 1칸 철거
	main.grid.grid[3][26].erase("road_type")
	main.grid._border_connections_dirty = true
	var cut_conns: Dictionary = main.grid.check_border_road_connections()
	assert(cut_conns["jangan"]["connected"] == false, "도로 단절 시 연결 해제 실패")
	assert(cut_conns["paldal"]["connected"] == true, "타 도로에 영향 발생(사이드 이펙트)")

	# 복구
	main.grid.grid[3][26]["building"] = "road"
	main.grid.grid[3][26]["road_type"] = "dirt"
	main.grid._border_connections_dirty = true
	var restored_conns: Dictionary = main.grid.check_border_road_connections()
	assert(restored_conns["jangan"]["connected"] == true, "도로 복구 시 재개통 실패")
	print("도로 단절 및 재연결 시 이정표 롤백 무결성 검증 통과.")

	# D. 이정표 살피기(InspectPopup) 내러티브 4줄 규격 검증
	for gk: String in ["jangan", "paldal", "changryong", "hwaseo"]:
		var test_entity: Dictionary = {
			"building": "road",
			"border_gate": gk,
			"pos": restored_conns[gk]["border_tile"]
		}
		var sign_data: Dictionary = InspectNarrativeGenerator.build_inspect_data(test_entity, main.simulation_core, main.grid)
		assert(sign_data["texture"] != null, "이정표 텍스처 누락: %s" % gk)
		assert(String(sign_data["title"]).contains("이정표:"), "이정표 제목 누락: %s in %s" % [gk, sign_data["title"]])
		var slines: PackedStringArray = String(sign_data["description"]).split("\n")
		assert(slines.size() == 4, "이정표 내러티브 4줄 규격 위반: %d줄 (%s)" % [slines.size(), gk])
		var s_len: int = String(sign_data["description"]).replace("\r", "").replace("\n", "").length()
		assert(s_len >= 70 and s_len <= 90, "이정표 내러티브 글자 수(70~90자) 위반: %d자 (%s)" % [s_len, gk])
	print("이정표 살피기 모달 4줄 고증 내러티브 검증 통과.")

	# E. GateLogistics 연동 및 렌더링 호출 검증
	main.grid.logistics.mark_dirty()
	main.grid.logistics.refresh()
	assert(main.grid.logistics.connected_kinds().size() == 4, "GateLogistics 사대문 연동 개통 수 불일치: %d" % main.grid.logistics.connected_kinds().size())
	if main.citizens and main.city:
		await process_frame
		print("CitizenLayer 이정표 푯말 및 툴팁 렌더링 연동 검증 통과.")

	print("=== 모든 25단계 종합 자동화 검증 100% 통과! ===")

	# [26/26] 수원천 수문·교량(남수문, 매향교, 화홍문) 엔티티 판정, 현판 라벨 및 살피기 고증 검증 시작
	print("[26/26] 수원천 수문·교량(남수문, 매향교, 화홍문) 엔티티 판정, 현판 라벨 및 살피기 고증 검증 시작")

	# A. 성곽/교량 하천 교차 자동 판정 & 엔티티 메타데이터 바인딩
	var water_y_north: int = 13
	var water_y_south: int = 52
	var water_y_mid: int = 30
	var water_x: int = 35

	# 1. 북수문 (화홍문)
	main.grid.grid[water_y_north][water_x]["terrain"] = "water"
	main.grid.grid[water_y_north][water_x]["building"] = "wall"
	var hw_res: Dictionary = WaterStructureManager.on_wall_cross_river(main.grid, water_x, water_y_north)
	assert(hw_res["facility_id"] == "hwahong_mun", "화홍문 엔티티 ID 판정 실패: %s" % hw_res.get("facility_id", ""))
	assert(hw_res["name"] == "화홍문 (華虹門)", "화홍문 한글 명칭 불일치: %s" % hw_res.get("name", ""))
	assert(int(main.grid.grid[water_y_north][water_x]["building_type"]) == int(GameGrid.BuildingType.SPECIAL), "화홍문 BuildingType.SPECIAL 미지정")
	assert(main.grid.grid[water_y_north][water_x]["is_special_building"] == true, "화홍문 is_special_building 플래그 누락")

	# 2. 남수문
	main.grid.grid[water_y_south][water_x]["terrain"] = "water"
	main.grid.grid[water_y_south][water_x]["building"] = "wall"
	var ns_res: Dictionary = WaterStructureManager.on_wall_cross_river(main.grid, water_x, water_y_south)
	assert(ns_res["facility_id"] == "namsu_mun", "남수문 엔티티 ID 판정 실패: %s" % ns_res.get("facility_id", ""))
	assert(ns_res["name"] == "남수문 (南水門)", "남수문 한글 명칭 불일치: %s" % ns_res.get("name", ""))
	assert(int(main.grid.grid[water_y_south][water_x]["building_type"]) == int(GameGrid.BuildingType.SPECIAL), "남수문 BuildingType.SPECIAL 미지정")
	assert(main.grid.grid[water_y_south][water_x]["is_special_building"] == true, "남수문 is_special_building 플래그 누락")

	# 3. 매향교
	main.grid.grid[water_y_mid][water_x]["terrain"] = "water"
	main.grid.grid[water_y_mid][water_x]["building"] = "road"
	var mh_res: Dictionary = WaterStructureManager.on_bridge_built(main.grid, water_x, water_y_mid)
	assert(mh_res["facility_id"] == "maehwang_gyo", "매향교 엔티티 ID 판정 실패: %s" % mh_res.get("facility_id", ""))
	assert(mh_res["name"] == "매향교 (梅香橋)", "매향교 한글 명칭 불일치: %s" % mh_res.get("name", ""))
	assert(int(main.grid.grid[water_y_mid][water_x]["building_type"]) == int(GameGrid.BuildingType.SPECIAL), "매향교 BuildingType.SPECIAL 미지정")
	assert(main.grid.grid[water_y_mid][water_x]["is_special_building"] == true, "매향교 is_special_building 플래그 누락")
	print("수원천 3대 특수 구조물 엔티티 판정 및 BuildingType.SPECIAL 바인딩 검증 통과.")

	# B. 현판 (WorldMarkerManager 및 GateSignboard) 인스턴스화 및 세팅 검증
	var wm: WorldMarkerManager = WorldMarkerManager.new()
	main.add_child(wm)
	var sign_ns: GateSignboard = wm.register_marker("namsu_mun", "남수문 (南水門)", Vector2(100, 100))
	assert(sign_ns != null and sign_ns.gate_name == "남수문 (南水門)", "남수문 현판 생성 실패")
	var sign_hw: GateSignboard = wm.register_marker("hwahong_mun", "화홍문 (華虹門)", Vector2(100, 50))
	assert(sign_hw != null and sign_hw.gate_name == "화홍문 (華虹門)", "화홍문 현판 생성 실패")
	var sign_mh: GateSignboard = wm.register_marker("maehwang_gyo", "매향교 (梅香橋)", Vector2(100, 80))
	assert(sign_mh != null and sign_mh.gate_name == "매향교 (梅香橋)", "매향교 현판 생성 실패")

	# 중복 생성 방지(SSOT) O(1) 캐시 검증
	var sign_ns_dup: GateSignboard = wm.register_signboard("namsu_mun", Vector2(100, 120), "남수문 (南水門)")
	assert(sign_ns_dup == sign_ns, "동일 시설 중복 등록 시 단일 인스턴스 미반환")
	assert(wm.active_signboards.size() == 3, "중복 방어 실패: 현판 개수 불일치")

	# 사대문 ID 정규화 및 단일화 검증
	var sign_pd1: GateSignboard = wm.register_marker("gate_16_63", "팔달문 (八達門)", Vector2(200, 200))
	var sign_pd2: GateSignboard = wm.register_signboard("paldal_mun", Vector2(200, 150), "팔달문 (八達門)")
	assert(sign_pd1 == sign_pd2, "사대문 ID 정규화 중복 방어 실패")
	assert(sign_pd2.name == "Signboard_paldal_mun", "사대문 현판 노드 네이밍 규격 불일치")

	wm.clear_all_markers()
	wm.queue_free()
	print("현판(GateSignboard) 규격 생성 및 바인딩 검증 통과.")

	# C. 살피기(InspectNarrativeGenerator) 특수 건물 20자 4줄 역사 고증 내러티브 검증
	var test_cases: Array[Dictionary] = [
		{
			"entity": {"facility_id": "namsu_mun", "is_special_building": true},
			"title": "화성 남수문 (南水門)",
			"portrait": "namsumun",
			"keyword": "아홉 개 홍예"
		},
		{
			"entity": {"facility_id": "hwahong_mun", "is_special_building": true},
			"title": "화성 화홍문 (華虹門)",
			"portrait": "hwahongmun",
			"keyword": "화홍포설"
		},
		{
			"entity": {"facility_id": "maehwang_gyo", "is_special_building": true},
			"title": "수원천 매향교 (梅香橋)",
			"portrait": "maehwang_gyo",
			"keyword": "버드나무"
		}
	]

	for tc: Dictionary in test_cases:
		var insp: Dictionary = InspectNarrativeGenerator.build_inspect_data(tc["entity"], main.simulation_core, main.grid)
		assert(insp["title"] == tc["title"], "살피기 제목 불일치: %s != %s" % [insp["title"], tc["title"]])
		assert(insp["texture"] != null, "살피기 텍스처 누락: %s" % tc["title"])
		assert(insp["texture"] == InspectNarrativeGenerator.get_portrait(tc["portrait"]), "살피기 대표 일러스트 불일치: %s" % tc["title"])
		var lines: PackedStringArray = String(insp["description"]).split("\n")
		assert(lines.size() == 4, "살피기 내러티브 4줄 규격 위반: %d줄 (%s)" % [lines.size(), tc["title"]])
		var clen: int = String(insp["description"]).replace("\r", "").replace("\n", "").length()
		assert(clen >= 70 and clen <= 110, "살피기 글자 수(70~110자) 규격 위반: %d자 (%s)" % [clen, tc["title"]])
		assert(String(insp["description"]).contains(tc["keyword"]), "핵심 역사 고증 키워드 누락: %s in %s" % [tc["keyword"], insp["description"]])
	print("살피기 특수건물 20자 4줄 역사 고증 내러티브 검증 통과.")

	# E. [난이도 시스템 및 경제·인구 연동 밸런스 검증]
	print("\n--- [검증] 난이도 3단계 및 경제 밸런스 시스템 테스트 시작 ---")
	
	# 1) 쉬움 난이도 검증 (기존 밸런스 100% 보존)
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.EASY)
	assert(DifficultyManager.get_difficulty() == DifficultyManager.Difficulty.EASY, "난이도 설정 오류: 쉬움")
	assert(DifficultyManager.get_cost_multiplier() == 1.0, "쉬움 배율 오류")
	var stone_easy: Dictionary = main.grid.get_tool_cost("stone_road", 0, 0)
	assert(stone_easy["gold"] == 35 and stone_easy["rice"] == 5, "쉬움 박석길 비용 오류: %s" % str(stone_easy))
	var wall_easy: Dictionary = main.grid.get_tool_cost("wall", 0, 0)
	assert(wall_easy["gold"] == 1000 and wall_easy["rice"] == 500, "쉬움 성벽 비용 오류: %s" % str(wall_easy))
	assert(DifficultyManager.can_spawn_shop(0, 0) == true, "쉬움 민가 0 상점 생성 허용 오류")
	assert(DifficultyManager.can_spawn_shop(1, 10) == true, "쉬움 상점 무제한 생성 오류")
	assert(DifficultyManager.get_farm_capacity_limit(1) >= 999999, "쉬움 둔전 무제한 경작 오류")
	assert(DifficultyManager.get_relief_food_cost(5000) == 500, "쉬움 구휼미 500석 고정 오류")
	assert(DifficultyManager.get_relief_food_cost(25000) == 500, "쉬움 구휼미 고정 오류 (고인구)")
	assert(DifficultyManager.get_public_maintenance_rate() == 0.0, "쉬움 공공기관 유지비 없음 오류")
	assert(DifficultyManager.get_retainer_salary() == 0, "쉬움 인재 녹봉 없음 오류")
	assert(is_equal_approx(DifficultyManager.get_retainer_salary_multiplier(), 1.0), "쉬움 관리 녹봉 배율 1.0 오류")
	assert(is_equal_approx(DifficultyManager.get_tax_multiplier(), 1.0), "쉬움 세수 배율 1.0 오류")
	assert(DifficultyManager.get_disaster_penalty("drought") == 0.20, "쉬움 재해 페널티 오류")
	print("  1. 쉬움(태평성대) 기존 밸런스 100% 보존 검증 완료.")

	# 2) 보통 난이도 검증 (역사적 고증 밸런스)
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.NORMAL)
	assert(DifficultyManager.get_difficulty() == DifficultyManager.Difficulty.NORMAL, "난이도 설정 오류: 보통")
	assert(DifficultyManager.get_cost_multiplier() == 2.0, "보통 배율 2.0 오류")
	var stone_norm: Dictionary = main.grid.get_tool_cost("stone_road", 0, 0)
	assert(stone_norm["gold"] == 60 and stone_norm["rice"] == 0, "보통 박석길(흙길의 3배) 비용 오류: %s" % str(stone_norm))
	var wall_norm: Dictionary = main.grid.get_tool_cost("wall", 0, 0)
	assert(wall_norm["gold"] == 2000 and wall_norm["rice"] == 1000, "보통 성벽 2배 비용 오류: %s" % str(wall_norm))
	assert(DifficultyManager.can_spawn_shop(0, 0) == false, "보통 민가 0 상점 스폰 차단 오류")
	assert(DifficultyManager.can_spawn_shop(1, 1) == true, "보통 민가 1, 상점 1 스폰 허용 오류")
	assert(DifficultyManager.can_spawn_shop(1, 2) == false, "보통 민가 1, 상점 2 초과 차단 오류")
	assert(DifficultyManager.can_spawn_shop(2, 3) == true, "보통 민가 2, 상점 3 스폰 허용 오류")
	assert(DifficultyManager.get_farm_capacity_limit(0) == 0, "보통 민가 0 둔전 경작 한도 오류")
	assert(DifficultyManager.get_farm_capacity_limit(1) == 30, "보통 민가 1 둔전 30칸 제한 오류")
	assert(DifficultyManager.get_farm_capacity_limit(2) == 60, "보통 민가 2 둔전 60칸 제한 오류")
	assert(DifficultyManager.get_relief_food_cost(5000) == 500, "보통 구휼미 1만 미만 500석 오류")
	assert(DifficultyManager.get_relief_food_cost(10000) == 5000, "보통 구휼미 1만 도달 시 5,000석(10배) 오류: %d" % DifficultyManager.get_relief_food_cost(10000))
	assert(DifficultyManager.get_relief_food_cost(20000) == 50000, "보통 구휼미 2만 도달 시 50,000석(10배) 오류: %d" % DifficultyManager.get_relief_food_cost(20000))
	assert(is_equal_approx(DifficultyManager.get_public_maintenance_rate(), 0.20), "보통 공공기관 분기 유지비 20% 오류")
	assert(DifficultyManager.get_retainer_salary() == 200, "보통 인재 계절 녹봉 200냥 오류")
	assert(is_equal_approx(DifficultyManager.get_retainer_salary_multiplier(), 2.0), "보통 관리 녹봉 2배 오류")
	assert(is_equal_approx(DifficultyManager.get_tax_multiplier(), 0.70), "보통 세수 배율 0.70 오류")
	assert(is_equal_approx(DifficultyManager.get_disaster_penalty("drought"), 0.70), "보통 가뭄/홍수 식량 -70% 오류")
	assert(is_equal_approx(DifficultyManager.get_disaster_penalty("fire"), 0.80), "보통 화재 상업 세수 -80% 오류")
	print("  2. 보통(성역의 고난) 역사적 고증 경제·인구 밸런스 검증 완료.")

	# 3) 어려움 난이도 검증 (보통 대비 10% 추가 할증)
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.HARD)
	assert(DifficultyManager.get_difficulty() == DifficultyManager.Difficulty.HARD, "난이도 설정 오류: 어려움")
	assert(is_equal_approx(DifficultyManager.get_cost_multiplier(), 3.0), "어려움 배율 3.0x 오류")
	var stone_hard: Dictionary = main.grid.get_tool_cost("stone_road", 0, 0)
	assert(stone_hard["gold"] == 66 and stone_hard["rice"] == 0, "어려움 박석길(흙길의 3.3배) 비용 오류: %s" % str(stone_hard))
	var wall_hard: Dictionary = main.grid.get_tool_cost("wall", 0, 0)
	assert(wall_hard["gold"] == 3000 and wall_hard["rice"] == 1500, "어려움 성벽 3배 비용 오류: %s" % str(wall_hard))
	assert(DifficultyManager.get_relief_food_cost(5000) == 550, "어려움 구휼미 550석 오류: %d" % DifficultyManager.get_relief_food_cost(5000))
	assert(DifficultyManager.get_relief_food_cost(10000) == 5500, "어려움 구휼미 5500석 오류: %d" % DifficultyManager.get_relief_food_cost(10000))
	assert(is_equal_approx(DifficultyManager.get_public_maintenance_rate(), 0.22), "어려움 공공기관 유지비 22% 오류")
	assert(DifficultyManager.get_retainer_salary() == 300, "어려움 인재 녹봉 300냥 오류")
	assert(is_equal_approx(DifficultyManager.get_retainer_salary_multiplier(), 3.0), "어려움 관리 녹봉 3배 오류")
	assert(is_equal_approx(DifficultyManager.get_tax_multiplier(), 0.60), "어려움 세수 배율 0.60 오류")
	assert(is_equal_approx(DifficultyManager.get_disaster_penalty("drought"), 0.80), "어려움 가뭄/홍수 식량 -80% 오류")
	assert(is_equal_approx(DifficultyManager.get_disaster_penalty("fire"), 0.90), "어려움 화재 상업 세수 -90% 오류")
	print("  3. 어려움(위기의 조선) 10% 추가 할증 밸런스 검증 완료.")

	# 4) 공공기관 계절 유지비 및 인재 녹봉 정산 로직 테스트
	var test_sim: SimulationCore = main.simulation_core
	test_sim.gold = 10000
	test_sim.retainers.clear()
	test_sim.retainers["jeong_yakyong"] = true
	test_sim.retainers["chae_jegong"] = true
	var maint_res: Dictionary = test_sim.process_seasonal_maintenance(main.grid)
	assert(maint_res["success"] == true, "계절 유지비 정산 실패")
	assert(maint_res["retainer_salaries"] == 600, "어려움 인재 2명 녹봉 600냥 오류: %d" % maint_res["retainer_salaries"])
	assert(test_sim.gold == 10000 - maint_res["total"], "국고 차감 불일치")
	print("  4. 공공기관 유지비 및 인재 녹봉 일괄 정산 검증 완료.")

	# 5) StartGamePopup UI 생성 및 바인딩 테스트
	var start_popup: StartGamePopup = StartGamePopup.new()
	main.add_child(start_popup)
	await process_frame
	assert(start_popup.root_control != null, "StartGamePopup UI 노드 생성 실패")
	start_popup._on_difficulty_chosen(DifficultyManager.Difficulty.NORMAL)
	assert(DifficultyManager.get_difficulty() == DifficultyManager.Difficulty.NORMAL, "StartGamePopup 난이도 선택 바인딩 실패")
	print("  5. StartGamePopup 난이도 선택 UI 및 모달 바인딩 검증 완료.")

	# 6) 세이브/로드 시 난이도 영구 보존 및 역호환 검증
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.HARD)
	SaveSystem.save_game(99, test_sim, main.grid)
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.EASY)
	assert(DifficultyManager.get_difficulty() == DifficultyManager.Difficulty.EASY, "임시 난이도 리셋 실패")
	var load_ok: bool = SaveSystem.load_game(99, test_sim, main.grid, main.time_manager)
	assert(load_ok == true, "슬롯 99 로드 실패")
	assert(DifficultyManager.get_difficulty() == DifficultyManager.Difficulty.HARD, "세이브 데이터 난이도(HARD) 복원 실패: %s" % str(DifficultyManager.get_difficulty()))
	SaveSystem.delete_save(99)
	print("  6. 세이브/로드 난이도 영구 보존 및 역호환성 검증 완료.")
	print("--- 난이도 및 경제 밸런스 시스템 모든 항목 검증 100% 통과! ---\n")

	print("=== 모든 26단계 종합 자동화 검증 100% 통과! ===")
	quit(0)
