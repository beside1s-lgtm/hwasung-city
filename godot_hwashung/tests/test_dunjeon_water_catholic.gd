extends SceneTree

## 대유둔전 농민·소 이동 루프, 물속 NPC(물놀이 vs 익수), 천주교 신자 실학 연구 FSM 전용 헤드리스 테스트
func _init() -> void:
	print("=== 대유둔전 / 물속 NPC / 천주교 신자 FSM 검증 시작 ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var main_scene = load("res://scenes/Main.tscn")
	if not main_scene:
		printerr("Main.tscn 로드 실패")
		quit(1)
		return

	var main = main_scene.instantiate()
	root.add_child(main)

	for i in range(10):
		await process_frame

	if main.intro_layer:
		main.intro_layer.intro_finished.emit()
		main._on_intro_finished()
	for i in range(5):
		await process_frame

	if main.title_screen:
		main._on_start_new_game()
	for i in range(10):
		await process_frame

	var citizens: CitizenManager = main.citizens
	var grid: GameGrid = main.grid
	var sim: SimulationCore = main.simulation_core
	var tech_mgr: TechTreeManager = sim.tech_tree

	var total_tests: int = 0
	var passed_tests: int = 0

	# ------------------------------------------------------------
	# [테스트 1] 농민 내비게이션 및 FREE_ROAMERS 등록 검증
	# ------------------------------------------------------------
	total_tests += 1
	if "farmer" in CitizenManager.FREE_ROAMERS:
		print("[PASS] 농민(farmer)이 FREE_ROAMERS에 등록되어 논/밭 관통 통행 보장됨.")
		passed_tests += 1
	else:
		printerr("[FAIL] farmer가 FREE_ROAMERS에 등록되지 않았습니다.")

	# ------------------------------------------------------------
	# [테스트 2] 농민 스폰 시 2~3개 둔전 순회 타깃 및 귀가 디스폰 검증
	# ------------------------------------------------------------
	total_tests += 1
	# 둔전 및 가옥 타일 명시적 배치 후 캐시 동기화
	grid.grid[20][20]["building"] = "agr_1"
	grid.grid[20][21]["building"] = "agr_1"
	grid.grid[20][22]["building"] = "agr_1"
	grid.grid[19][20]["building"] = "res_1"
	citizens._refresh_caches()
	citizens._sync_spot_agents()

	var farmers: Array = citizens.agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "farmer")
	if not farmers.is_empty():
		var fa: Dictionary = farmers[0]
		var extra: Dictionary = fa.get("extra", {})
		var targets: Array = extra.get("field_targets", [])
		if targets.size() >= 1 and targets.size() <= 3:
			print("[PASS] 농민에게 둔전 순회 타깃(%d곳)이 정상 할당되었습니다." % targets.size())
			passed_tests += 1
		else:
			printerr("[FAIL] 농민 순회 타깃 할당 오류: %s" % str(targets))
	else:
		printerr("[FAIL] 농민 에이전트 스폰 실패.")

	# 귀가 도착 시 디스폰 검증
	total_tests += 1
	if not farmers.is_empty():
		var test_f: Dictionary = farmers[0]
		var f_extra: Dictionary = test_f.get("extra", {})
		var h_pos: Vector2i = f_extra.get("home", Vector2i(20, 20))
		f_extra["phase"] = "to_home"
		f_extra["home"] = h_pos
		test_f["x"] = float(h_pos.x) + 0.5
		test_f["y"] = float(h_pos.y) + 0.5
		citizens._update_agent(test_f, 0.1)
		if test_f.get("is_dead", false):
			print("[PASS] 농민이 가옥 문 앞 도달 시 떨림 없이 집 안으로 들어가 안전하게 디스폰(is_dead=true)됨.")
			passed_tests += 1
		else:
			printerr("[FAIL] 농민 가옥 도달 디스폰 실패: is_dead != true")

	# ------------------------------------------------------------
	# [테스트 3] 물놀이(water_play) vs 익수(drowning) 살피기 대사 분기 검증
	# ------------------------------------------------------------
	total_tests += 1
	var swimmer_entity: Dictionary = {
		"type": "water_play",
		"state": "swimming"
	}
	var sw_data: Dictionary = InspectNarrativeGenerator.build_inspect_data(swimmer_entity, sim, grid, citizens)
	if sw_data["title"] == "수원천에서 물놀이 중인 아이" and "멱을 감고 있으니" in sw_data["description"]:
		print("[PASS] 물놀이(water_play) 20자 4줄 고증 대사 정상 반환.")
		passed_tests += 1
	else:
		printerr("[FAIL] 물놀이 살피기 대사 불일치: %s" % str(sw_data))

	total_tests += 1
	var drown_entity: Dictionary = {
		"type": "drowning",
		"state": "drowning"
	}
	var dr_data: Dictionary = InspectNarrativeGenerator.build_inspect_data(drown_entity, sim, grid, citizens)
	if dr_data["title"] == "물에 빠져 허우적대는 백성" and "어푸푸" in dr_data["description"] and "밧줄을 던져다오" in dr_data["description"]:
		print("[PASS] 익수(drowning) 20자 4줄 위기 대사 정상 반환.")
		passed_tests += 1
	else:
		printerr("[FAIL] 익수 살피기 대사 불일치: %s" % str(dr_data))

	# ------------------------------------------------------------
	# [테스트 4] 익수자 구조자(rescuer) FSM 연동 검증
	# ------------------------------------------------------------
	total_tests += 1
	# 수원천 물 타일 위치 탐색 및 인접 육지 타일 확보
	var w_pt := Vector2i(-1, -1)
	var land_pt := Vector2i(-1, -1)
	for y: int in range(grid.size):
		for x: int in range(grid.size):
			if grid.grid[y][x].get("terrain", "") == "water":
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = Vector2i(x, y) + d
					if grid.in_bounds(n.x, n.y) and grid.grid[n.y][n.x].get("terrain", "") != "water":
						w_pt = Vector2i(x, y)
						land_pt = n
						break
			if w_pt.x >= 0:
				break
		if w_pt.x >= 0:
			break

	var dr_agent: Dictionary = {
		"id": 9991,
		"type": "drowning",
		"is_spot": true,
		"x": float(w_pt.x) + 0.5,
		"y": float(w_pt.y) + 0.5,
		"state": "drowning",
		"drown_timer": 30.0,
		"rescuer_id": -1,
		"bank_pt": land_pt
	}
	var rescuer_agent: Dictionary = {
		"id": 9992,
		"type": "commoner",
		"x": float(land_pt.x) + 0.5,
		"y": float(land_pt.y) + 0.5,
		"state": "walk"
	}
	citizens.agents.append(dr_agent)
	citizens.agents.append(rescuer_agent)

	citizens._update_agent(dr_agent, 0.1)
	if dr_agent.get("rescuer_id", -1) == 9992 and rescuer_agent.get("state", "") == "rescuing":
		print("[PASS] 반경 4타일 이내 육지 백성이 구조자(rescuer)로 정상 지정됨.")
		rescuer_agent["rescue_time"] = 0.0
		citizens._update_agent(rescuer_agent, 0.1)
		if dr_agent.get("state", "") == "saved" and "콜록콜록" in dr_agent.get("bubble_text", ""):
			print("[PASS] 구조 완료 후 익수자가 물 밖으로 끌어올려져 안도(saved) 상태로 전이됨.")
			passed_tests += 1
		else:
			printerr("[FAIL] 구조 완료 전이 실패: %s" % str(dr_agent))
	else:
		printerr("[FAIL] 구조자 지정 실패: rescuer_id=%d, state=%s" % [dr_agent.get("rescuer_id", -1), rescuer_agent.get("state", "")])

	# ------------------------------------------------------------
	# [테스트 5] 천주교 신자 실학 연구(보유론·서기수용론) 연동 FSM 검증
	# ------------------------------------------------------------
	total_tests += 1
	var catholic_agent: Dictionary = {
		"id": 9995,
		"type": "catholic",
		"x": 20.5,
		"y": 20.5,
		"state": "idle"
	}
	citizens.agents.append(catholic_agent)

	# 5-1. 연구 미완료 상태: 도주 및 체포 연출
	var cat_res_unres: Dictionary = citizens.trigger_catholic_interaction(catholic_agent)
	if not cat_res_unres["researched"] and cat_res_unres["title"] == "[사학 죄인 체포]" and catholic_agent.get("state", "") == "fleeing":
		print("[PASS] 연구 미완료 시 신자가 혼비백산 도주(fleeing)하며 [사학 죄인 체포]로 분기됨.")
		passed_tests += 1
	else:
		printerr("[FAIL] 연구 미완료 분기 오류: %s" % str(cat_res_unres))

	total_tests += 1
	# 5-2. 연구 완료 상태: 당당한 신앙 고백 모드
	tech_mgr.complete_research_instantly("boyuron", sim)
	tech_mgr.complete_research_instantly("segi", sim)

	var has_boyuron: bool = tech_mgr.has_researched("boyuron", sim)
	var has_segi: bool = tech_mgr.has_researched("seogi_suyong", sim)
	if has_boyuron and has_segi:
		print("[PASS] TechTreeManager.has_researched 별칭('seogi_suyong' -> 'segi') 및 연구 완료 판정 성공.")
		var cat_res_done: Dictionary = citizens.trigger_catholic_interaction(catholic_agent)
		if cat_res_done["researched"] and cat_res_done["title"] == "천주교 신자 (서학 유생)" and catholic_agent.get("state", "") == "prayer":
			print("[PASS] 연구 완료 후 당당한 신앙 고백 및 합장 기도(prayer) 모드 전환 확인.")
			passed_tests += 1
		else:
			printerr("[FAIL] 연구 완료 분기 오류: %s" % str(cat_res_done))
	else:
		printerr("[FAIL] has_researched 판정 실패: boyuron=%s, segi=%s" % [str(has_boyuron), str(has_segi)])

	print("\n=== 검증 리포트 ===")
	print("총 테스트 항목: %d개, 성공: %d개" % [total_tests, passed_tests])
	if total_tests == passed_tests:
		print(">>> 모든 대유둔전/물속NPC/천주교 신자 FSM 검증이 100% 통과되었습니다! <<<")
	else:
		printerr(">>> 일부 테스트 항목 실패! <<<")

	quit(0 if total_tests == passed_tests else 1)
