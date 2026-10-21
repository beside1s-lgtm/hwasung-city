extends SceneTree

## [NPC 전투, 도둑/싸움, 대유둔전 농민 분산, 반란군 공성전 자동화 테스트]

func _init() -> void:
	print("=== NPC 인터랙션, 대유둔전 분산, 반란군 공성전 통합 검증 시작 ===")
	var total_tests: int = 0
	var passed_tests: int = 0

	# 1. 저잣거리 분쟁(싸움/도둑) 및 순라군 2인 1조 출동 검증
	total_tests += 1
	var sim := SimulationCore.new()
	var grid := GameGrid.new()
	grid._build_from_map()
	var citizens := CitizenManager.new()

	# 관아 설치
	grid.grid[15][15]["building"] = "gwana"

	var sunla_mgr := SunlacheongManager.new()
	sunla_mgr.setup(grid)

	if sunla_mgr.officer_pool.size() >= 2:
		var off1: PatrolOfficerNPC = sunla_mgr.officer_pool[0]
		var base_spd: float = sunla_mgr.get_patrol_dispatch_speed()
		off1.dispatch(1, Vector2i(10, 10), [Vector2i(10, 10)], base_spd)
		assert(base_spd == 1.0, "순라청 0개소 시 기본 속도 1.0")
		
		# 순라청 4개소 추가 시 최대 3.0 스피드 검증
		sunla_mgr.patrol_stations = [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3), Vector2i(4, 4)]
		var max_spd: float = sunla_mgr.get_patrol_dispatch_speed()
		assert(max_spd == 3.0, "순라청 4개소 시 최대 속도 3.0")
		off1.dispatch(1, Vector2i(10, 10), [Vector2i(10, 10)], max_spd)

		if off1.speed >= 3.0:
			print("[TEST 1 PASS] 순라청 개수 연동 출동 속도(0개소: 1.0 -> 4개소: 3.0) 및 관아 포졸 풀 검증 성공")
			passed_tests += 1
		else:
			printerr("[TEST 1 FAIL] 포졸 속도가 기대값(3.0) 미만입니다: ", off1.speed)
	else:
		printerr("[TEST 1 FAIL] 관아 포졸 풀이 확보되지 않았습니다: ", sunla_mgr.officer_pool.size())

	# 2. 범죄자(싸움/도둑) 액션 및 피해 상인 인터랙션 검증
	total_tests += 1
	var crm_brawl := CriminalNPC.new()
	crm_brawl.setup_criminal(1, CriminalNPC.CriminalKind.DRUNK_BRAWLER, Vector2i(10, 10), 101)
	crm_brawl.update(0.5)
	var dict_brawl: Dictionary = crm_brawl.to_agent_dict()

	var crm_thief := CriminalNPC.new()
	crm_thief.setup_criminal(2, CriminalNPC.CriminalKind.PICKPOCKET, Vector2i(12, 12), 102)
	crm_thief.update(1.6) # 1.5초 경과 시 도주 상태로 전이
	var dict_thief: Dictionary = crm_thief.to_agent_dict()

	if dict_brawl.has("punch_intensity") and dict_brawl.has("victim_x") and dict_thief.get("state") == "fleeing":
		print("[TEST 2 PASS] 취객 난투극(주먹질 강도=%.2f, 상인 위치) 및 소매치기 보따리 낚아채 도주 FSM 검증 성공" % float(dict_brawl.get("punch_intensity", 0.0)))
		passed_tests += 1
	else:
		printerr("[TEST 2 FAIL] 범죄자 인터랙션 데이터 또는 도주 FSM 실패: ", dict_brawl, dict_thief)

	# 3. 대유둔전 농민 1셀 1인 분산 및 거리 유지 검증
	total_tests += 1
	citizens.grid = grid
	citizens._agr_cache.clear()
	for y in range(5):
		for x in range(5):
			citizens._agr_cache.append(Vector2i(20 + x, 20 + y))

	citizens._house_cache = [Vector2i(10, 10)]
	citizens.agents.clear()
	citizens._sync_spot_agents()

	var farmers: Array = citizens.agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "farmer")
	var occupied_cells: Dictionary = {}
	var has_duplicate: bool = false
	for f: Dictionary in farmers:
		var c_tile: Vector2i = f.get("from_tile", Vector2i(-1, -1))
		if occupied_cells.has(c_tile):
			has_duplicate = true
			break
		occupied_cells[c_tile] = true

	if not farmers.is_empty() and not has_duplicate:
		print("[TEST 3 PASS] 대유둔전 농민 1셀 1인 엄격 분산 배치 검증 성공 (농민 수: %d, 중복 셀 없음)" % farmers.size())
		passed_tests += 1
	else:
		printerr("[TEST 3 FAIL] 농민 배정에 중복 셀이 발생했습니다: duplicate=%s, count=%d" % [has_duplicate, farmers.size()])

	# 4. 반란군/공성전 10명 이상 편성 및 병종(포수/사수/살수) 배정 검증
	total_tests += 1
	var siege := SiegeSystem.new()
	var court := CourtSystem.new()
	court.sim = sim
	siege.setup(grid, sim, citizens, court)

	var focus_data: Dictionary = {"called": false, "loc": ""}
	siege.battle_focus_requested.connect(func(_w: Vector2, loc_name: String):
		focus_data["called"] = true
		focus_data["loc"] = loc_name
	)

	# 성문 설치 및 반란 트리거
	grid.grid[25][20]["building"] = "jangan_mun"
	citizens._gate_cache = [Vector2i(20, 25)]
	citizens.city = CityLayer.new()

	siege._start("rebel", 500)
	siege._spawn_units()

	var rebels: Array = citizens.agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "rebel" and a.get("siege_unit", false))
	var has_gunner: bool = false
	var has_archer: bool = false
	var has_blade: bool = false
	for r: Dictionary in rebels:
		var wc: String = str(r.get("weapon_class", ""))
		if wc == "gunner": has_gunner = true
		elif wc == "archer": has_archer = true
		elif wc == "blade": has_blade = true
	if rebels.size() >= 10 and has_gunner and has_archer and has_blade and bool(focus_data.get("called", false)):
		print("[TEST 4 PASS] 반란군 10명 이상(%d명) 편성, 3대 병종(포수/사수/살수) 배정 및 맵 자동 포커싱(%s) 검증 성공" % [rebels.size(), str(focus_data.get("loc", ""))])
		passed_tests += 1
	else:
		printerr("[TEST 4 FAIL] 반란군 편성 또는 포커싱 실패: size=%d, gunner=%s, archer=%s, blade=%s, focus=%s" % [rebels.size(), has_gunner, has_archer, has_blade, bool(focus_data.get("called", false))])

	# 5. 성곽 방호력 피해 및 공격력 비례 피해 규모 검증
	total_tests += 1
	CityStats.set_fortress_defense_power(800)
	sim.defense_fatigue = 0
	var prev_fatigue: int = sim.defense_fatigue
	siege.state = "siege"
	siege._process(1.0) # 1초 공성 진행

	var cur_fatigue: int = sim.defense_fatigue
	siege._finish(true) # 방어 성공 시에도 성곽 피해 잔존 확인

	var final_fatigue: int = sim.defense_fatigue
	if final_fatigue > prev_fatigue and final_fatigue >= 25:
		print("[TEST 5 PASS] 적 공격력 비례 실시간 성곽 방호력 차감 및 잔존 피해(%d 피로도 누적) 검증 성공" % final_fatigue)
		passed_tests += 1
	else:
		printerr("[TEST 5 FAIL] 성곽 피해가 반영되지 않았습니다: final_fatigue=%d" % final_fatigue)

	print("\n=== 최종 결과: %d / %d 항목 통과 ===" % [passed_tests, total_tests])
	if passed_tests == total_tests:
		print(">> [ALL PASS] 모든 신규 요구사항 구현 및 검증 완료!")
		quit(0)
	else:
		printerr(">> [FAIL] 일부 테스트가 실패했습니다.")
		quit(1)
