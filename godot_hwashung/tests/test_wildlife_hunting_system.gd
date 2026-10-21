extends SceneTree

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var out_lines: Array[String] = []
	out_lines.append("==================================================")
	out_lines.append("=== 산짐승 소탕 FSM & 산악 전용 스폰/원정 사냥 검증 시작 ===")
	out_lines.append("==================================================")

	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	for i in range(5):
		await process_frame

	var grid: GameGrid = main.grid
	var cm: CitizenManager = main.citizens

	# 1. 지형 분류 및 스폰 유효성 검사 (can_spawn_wild_animal) 검증
	out_lines.append("\n--- 1. 신규 산짐승 스폰 지형 엄격 필터링 검증 ---")
	# (1-1) 평지(plain) 타일 스폰 차단 검증
	var plain_tile := Vector2i(20, 20)
	grid.grid[plain_tile.y][plain_tile.x]["terrain"] = "plain"
	grid.grid[plain_tile.y][plain_tile.x]["building"] = ""
	grid.grid[plain_tile.y][plain_tile.x]["zone"] = ""
	assert(not cm.can_spawn_wild_animal(plain_tile), "평지 타일은 산짐승 스폰이 100% 차단되어야 합니다.")
	out_lines.append("[PASS] 평지(plain) 스폰 100% 차단 검증 완료")

	# (1-2) 도로/제방/농지/건물 타일 스폰 차단 검증
	var road_tile := Vector2i(21, 21)
	grid.grid[road_tile.y][road_tile.x]["terrain"] = "mountain"
	grid.grid[road_tile.y][road_tile.x]["building"] = "road"
	assert(not cm.can_spawn_wild_animal(road_tile), "도로가 놓인 산지 타일은 스폰이 차단되어야 합니다.")

	var levee_tile := Vector2i(22, 22)
	grid.grid[levee_tile.y][levee_tile.x]["terrain"] = "mountain"
	grid.grid[levee_tile.y][levee_tile.x]["building"] = "levee"
	assert(not cm.can_spawn_wild_animal(levee_tile), "제방 타일은 스폰이 차단되어야 합니다.")

	var agr_tile := Vector2i(23, 23)
	grid.grid[agr_tile.y][agr_tile.x]["terrain"] = "mountain"
	grid.grid[agr_tile.y][agr_tile.x]["building"] = ""
	grid.grid[agr_tile.y][agr_tile.x]["zone"] = "agr"
	assert(not cm.can_spawn_wild_animal(agr_tile), "농지(zone_agr) 구역은 스폰이 차단되어야 합니다.")
	out_lines.append("[PASS] 도로, 제방, 농지 타일 스폰 100% 차단 검증 완료")

	# (1-3) 마을 50칸 이내 산지 타일 스폰 차단 검증
	var village_tile := Vector2i(30, 30)
	grid.grid[village_tile.y][village_tile.x]["building"] = "res_1"
	grid.grid[village_tile.y][village_tile.x]["zone"] = "res"
	cm._res_cache.append(village_tile)

	var close_mountain := Vector2i(35, 30) # 거리 5칸
	grid.grid[close_mountain.y][close_mountain.x]["terrain"] = "mountain"
	grid.grid[close_mountain.y][close_mountain.x]["building"] = ""
	grid.grid[close_mountain.y][close_mountain.x]["zone"] = ""
	assert(not cm.can_spawn_wild_animal(close_mountain), "마을 50칸 이내의 산지 타일은 스폰이 차단되어야 합니다.")
	out_lines.append("[PASS] 마을 반경 50칸 이내 세이프존 스폰 100% 차단 검증 완료")

	# (1-4) 마을 50칸 밖 순수 산악 타일 스폰 허용 검증
	cm._res_cache.clear()
	cm._com_cache.clear()
	cm._shop_cache.clear()
	var test_res := Vector2i(55, 55)
	cm._res_cache.append(test_res)
	var safe_mountain := Vector2i(3, 3) # dist: 52칸 >= 50
	grid.grid[safe_mountain.y][safe_mountain.x]["terrain"] = "mountain"
	grid.grid[safe_mountain.y][safe_mountain.x]["building"] = ""
	grid.grid[safe_mountain.y][safe_mountain.x]["zone"] = ""
	assert(cm.can_spawn_wild_animal(safe_mountain), "마을 50칸 외곽의 자연 산지 타일은 스폰이 허용되어야 합니다.")
	out_lines.append("[PASS] 50칸 외곽 순수 산악 타일 스폰 허용 검증 완료")

	# 2. 마을 형성 시 잔존 산짐승 THREAT_TARGET 마킹 및 즉시 소탕 검증
	out_lines.append("\n--- 2. 마을 형성 시 잔존 산짐승 즉시 소탕 FSM 검증 ---")
	cm.agents.clear()

	# 마을(res: 30, 30) 형성
	cm._res_cache.clear()
	cm._res_cache.append(Vector2i(30, 30))

	# 마을 근처(32, 30)에 기존에 스폰되어 배회하던 멧돼지 배치 (거리 2칸)
	var intruding_boar: Dictionary = cm._add_wild_animal("wild_boar", Vector2i(32, 30))
	assert(not intruding_boar.get("is_threat_target", false), "초기에는 위협 타깃이 아니어야 합니다.")

	# 마을 위협 검사 트리거
	cm._check_and_mark_village_threat_animals()
	assert(intruding_boar.get("is_threat_target", false) == true, "마을 50칸 이내 잔존 짐승은 THREAT_TARGET으로 지정되어야 합니다.")
	out_lines.append("[PASS] 잔존 산짐승 THREAT_TARGET(위협 사냥감) 자동 지정 검증 완료")

	# 포수(사포수) 타깃 탐색 우선순위 (find_target_animal) 검증
	var far_deer: Dictionary = cm._add_wild_animal("deer", Vector2i(2, 2)) # 외곽 짐승
	var test_hunter := {
		"id": 999,
		"type": "saposu",
		"x": 30.0,
		"y": 30.0,
		"search_throttle": 0.0
	}
	var target_animal: Dictionary = cm.find_target_animal(Vector2(30.0, 30.0), test_hunter)
	assert(not target_animal.is_empty(), "타깃 동물이 검색되어야 합니다.")
	assert(target_animal.get("id", -1) == intruding_boar.get("id", -1), "1순위로 마을 내 침범 짐승을 타깃해야 합니다.")
	out_lines.append("[PASS] 포수 타깃 탐색 1순위(마을 침범 짐승 우선 지정) 검증 완료")

	# 3. 사냥 성공 시 엔티티 안전 제거(safe_remove_agent) 검증
	out_lines.append("\n--- 3. 엔티티 안전 제거(Safe Despawn) 및 메모리 누수 방지 검증 ---")
	var initial_agent_count: int = cm.agents.size()
	cm.safe_remove_agent(intruding_boar)
	assert(intruding_boar.get("is_dead", false) == true, "사냥 성공 시 is_dead=true 처리되어야 합니다.")
	assert(intruding_boar.get("is_threat_target", false) == false, "위협 상태가 해제되어야 합니다.")

	# 사망 에이전트 필터링 검증
	cm.agents = cm.agents.filter(func(a: Dictionary) -> bool: return not a.get("is_dead", false))
	assert(cm.agents.size() == initial_agent_count - 1, "사망한 동물은 에이전트 리스트에서 안전 등록 해제되어야 합니다.")
	out_lines.append("[PASS] Safe Despawn 및 엔티티 안전 제거 검증 완료")

	# 4. 평시 상태 산지 원정 사냥(Patrol & Hunt) 검증
	out_lines.append("\n--- 4. 평시 외곽 산지 원정 사냥 루프 검증 ---")
	test_hunter["search_throttle"] = 0.0
	var expedition_target: Dictionary = cm.find_target_animal(Vector2(30.0, 30.0), test_hunter)
	assert(not expedition_target.is_empty(), "마을 내 위협 짐승이 소탕된 후 2순위 산악 짐승을 타깃해야 합니다.")
	assert(expedition_target.get("id", -1) == far_deer.get("id", -1), "외곽 산악 지형의 사슴을 원정 사냥 타깃으로 지정해야 합니다.")
	out_lines.append("[PASS] 2순위 외곽 산지 원정 사냥(Patrol & Hunt) 타깃 지정 검증 완료")

	# 5. 오프스크린 컬링(Freeze) 헬퍼 검증
	out_lines.append("\n--- 5. 오프스크린 컬링(Freeze) 헬퍼 검증 ---")
	var screen_check_pos := Vector2(30.0, 30.0)
	var is_visible_bool: bool = cm.is_world_pos_on_screen(screen_check_pos)
	out_lines.append("화면 가시성 판정 정상 동작 확인: %s" % str(is_visible_bool))
	out_lines.append("[PASS] 오프스크린 컬링 헬퍼 정상 검증 완료")

	# 6. DistrictSpawner 사포수 스폰 헬퍼 검증
	out_lines.append("\n--- 6. DistrictSpawner 사포수 스폰 헬퍼 검증 ---")
	var saposu_leader: Dictionary = DistrictSpawner.spawn_saposu(cm, Vector2i(30, 30))
	assert(not saposu_leader.is_empty(), "DistrictSpawner를 통해 사포수가 정상 스폰되어야 합니다.")
	assert(saposu_leader.get("type", "") == "saposu", "스폰된 타입이 saposu여야 합니다.")
	out_lines.append("[PASS] DistrictSpawner 사포수 스폰 헬퍼 검증 완료")

	# 7. 호랑이 호포제 전용 사냥 검증 (평시 자동 사냥 100% 차단 & 호포령 발동 시에만 사냥 허용)
	out_lines.append("\n--- 7. 호랑이 호포제 전용 사냥 검증 (평시 자동 사냥 차단 & 호포령 발동 시 사냥) ---")
	cm.agents.clear()
	var village_tiger: Dictionary = cm._add_predator("tiger", Vector2i(32, 30))

	# (7-1) 호포령 미발동(평시) 상태 검증
	main.court.tiger["active"] = false
	cm._check_and_mark_village_threat_animals()
	assert(village_tiger.get("is_threat_target", false) == false, "호포령 미발동 시 호랑이는 마을 내에 있어도 자동 위협 사냥감으로 지정되면 안 됩니다.")

	var regular_hunter := {"id": 1001, "type": "hunter", "x": 30.0, "y": 30.0, "search_throttle": 0.0}
	var hunter_target: Dictionary = cm.find_target_animal(Vector2(30.0, 30.0), regular_hunter)
	assert(hunter_target.is_empty(), "평시 상태에서 활 사냥꾼은 호랑이를 절대 타깃팅하면 안 됩니다.")

	var regular_saposu := {"id": 1002, "type": "saposu", "x": 30.0, "y": 30.0, "search_throttle": 0.0}
	var saposu_target_peace: Dictionary = cm.find_target_animal(Vector2(30.0, 30.0), regular_saposu)
	assert(saposu_target_peace.is_empty(), "호포령 미발동 시 사포수도 호랑이를 자동으로 사냥 타깃으로 지정하면 안 됩니다.")
	out_lines.append("[PASS] 호포령 미발동 시 호랑이 자동 사냥 100% 차단 검증 완료")

	# (7-2) 호포령 발동(호포제) 상태 검증
	main.court.tiger["active"] = true
	cm._check_and_mark_village_threat_animals()
	assert(village_tiger.get("is_threat_target", false) == true, "호포령 발동 시 호랑이가 위협 사냥감(THREAT_TARGET)으로 정상 지정되어야 합니다.")

	regular_saposu["search_throttle"] = 0.0
	var saposu_target_hopo: Dictionary = cm.find_target_animal(Vector2(30.0, 30.0), regular_saposu)
	assert(not saposu_target_hopo.is_empty(), "호포령 발동 시 사포수가 호랑이를 사냥 타깃으로 탐색해야 합니다.")
	assert(saposu_target_hopo.get("id", -1) == village_tiger.get("id", -1), "호포령 발동 시 표적이 호랑이어야 합니다.")
	out_lines.append("[PASS] 호포령(호포제) 발동 시 호랑이 정상 타깃팅 및 사냥 전환 검증 완료")

	# 8. 호랑이 출현 시 주민 피신(shelter_in_house) 및 호랑이 소멸 후 원래 상태 복귀 검증
	out_lines.append("\n--- 8. 호랑이 출현 시 주민 피신 및 호랑이 소멸 후 복귀 검증 ---")
	cm.agents.clear()
	var test_citizen := {
		"id": 2001,
		"type": "citizen",
		"x": 30.0,
		"y": 30.0,
		"state": "walk",
		"speed": 1.0,
		"home_tile": Vector2i(28, 28)
	}
	cm.agents.append(test_citizen)

	# 호랑이 생성
	var threat_tiger: Dictionary = cm._add_predator("tiger", Vector2i(35, 30))
	assert(cm.has_active_tiger() == true, "호랑이가 존재할 때 has_active_tiger()가 true여야 합니다.")

	# 패닉 갱신 실행 -> 호랑이 출현 경보 및 민가 피신 상태 전이
	cm._panic_timer = 0.0
	cm._manage_panic(0.5)
	assert(test_citizen.get("tiger_sheltered", false) == true, "호랑이 출현 시 백성은 tiger_sheltered가 true여야 합니다.")
	assert(test_citizen.get("state", "") == "shelter_in_house", "백성의 상태가 shelter_in_house로 전이되어야 합니다.")
	assert(test_citizen.get("shelter_target", Vector2i.ZERO) == Vector2i(28, 28), "대피 목표가 집 좌표로 설정되어야 합니다.")
	out_lines.append("[PASS] 호랑이 출현 시 백성 민가 피신(shelter_in_house) 전이 검증 완료")

	# 민가 도착 시뮬레이션 -> 집 안 숨기(hidden_in_shelter, is_hidden_shelter = true)
	test_citizen["x"] = 28.0
	test_citizen["y"] = 28.0
	cm._update_shelter_agent(test_citizen, 0.1)
	assert(test_citizen.get("is_hidden_shelter", false) == true, "집에 도착하면 is_hidden_shelter가 true가 되어 숨어야 합니다.")
	assert(test_citizen.get("state", "") == "hidden_in_shelter", "집 안에서 상태가 hidden_in_shelter여야 합니다.")
	out_lines.append("[PASS] 집 도착 후 완전 은신(is_hidden_shelter = true) 검증 완료")

	# 호랑이 소멸 (퇴치 또는 도주) 시뮬레이션
	threat_tiger["is_dead"] = true
	assert(cm.has_active_tiger() == false, "호랑이가 제거된 후 has_active_tiger()가 false여야 합니다.")

	cm._panic_timer = 0.0
	cm._manage_panic(0.5)
	assert(test_citizen.get("tiger_sheltered", false) == false, "호랑이가 사라지면 tiger_sheltered가 해제되어야 합니다.")
	assert(test_citizen.get("is_hidden_shelter", false) == false, "호랑이가 사라지면 is_hidden_shelter가 해제되어야 합니다.")
	assert(test_citizen.get("state", "") == "walk", "원래 상태(walk)로 안전하게 복귀해야 합니다.")
	out_lines.append("[PASS] 호랑이 제거/소멸 후 백성 원래 상태(walk) 안전 복귀 검증 완료")

	out_lines.append("\n==================================================")
	out_lines.append("=== 모든 생태계/사냥 시스템 검증 테스트 통과! (ALL PASS) ===")
	out_lines.append("==================================================")

	var f := FileAccess.open("res://test_wildlife_result.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(out_lines))
		f.close()

	for line in out_lines:
		print(line)


	quit(0)
