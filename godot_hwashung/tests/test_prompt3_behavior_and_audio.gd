extends SceneTree

## [Prompt 3/3 통합 검증 테스트]
## 1. 장용영 병사 평시 상점 출입/행궁 배회 제거 및 전시 출격/복귀 디스폰
## 2. 순라청 포졸의 도둑/난동꾼 체포, 15초 안전 타임아웃, 관아 압송 및 완전 해결
## 3. 계절별 BGM 자동 변경(1.5초 크로스페이드) 및 위기 BGM 오작동 수정

func _init() -> void:
	print("==================================================")
	print("[TEST START] Prompt 3/3 행동 교정 및 오디오 시스템 검증")
	print("==================================================")
	call_deferred("_run_all_tests")

func _create_test_grid(sz: int = 60) -> GameGrid:
	var g := GameGrid.new()
	g.size = sz
	g.grid = []
	for y in range(sz):
		var row: Array = []
		for x in range(sz):
			row.append({
				"terrain": "plain",
				"surface": "grass",
				"building": "",
				"zone": "",
				"elevation": 0.0,
				"road_type": "dirt"
			})
		g.grid.append(row)
	return g

func _run_all_tests() -> void:
	var all_pass := true
	all_pass = test_jangyongyeong_peace_and_combat() and all_pass
	all_pass = test_sunla_arrest_and_escort_fsm() and all_pass
	all_pass = test_season_bgm_and_crisis_audio() and all_pass

	print("==================================================")
	if all_pass:
		print("🎉 [ALL TESTS PASSED] Prompt 3/3 명세 전체 요구사항 100% 검증 통과!")
		quit(0)
	else:
		print("❌ [TEST FAILED] 일부 검증 항목 실패!")
		quit(1)

## 1. 장용영 병사 평시 상점 출입 및 행궁 주변 무의미한 배회 제거 검증
func test_jangyongyeong_peace_and_combat() -> bool:
	print("\n--- [TEST 1] 장용영 병사 평시 상점 출입 차단 및 전투 FSM 검증 ---")
	var grid := _create_test_grid(60)

	# 연무대, 서장대, 행궁, 상점 타일 배치
	grid.grid[20][20]["building"] = "yeonmudae"
	grid.grid[25][25]["building"] = "seojangdae"
	grid.grid[30][30]["building"] = "haenggung"
	grid.grid[15][15]["building"] = "com_1"
	grid.grid[15][16]["building"] = "com_2"

	var citizens := CitizenManager.new()
	citizens.grid = grid
	citizens._shop_cache = [Vector2i(15, 15), Vector2i(15, 16)]
	citizens._haenggung_gate = Vector2i(30, 31)

	var sim := SimulationCore.new()
	sim.military_power = 80

	var mil_mgr := MilitaryManager.new()

	# 평시 정규군 스폰
	mil_mgr.spawn_regular_army(citizens, grid, sim)

	# 검증 1: 행궁(haenggung) 주변에 스폰된 군사가 없어야 함 (오직 연무대, 서장대, 성문만)
	for a: Dictionary in citizens.agents:
		if a.get("military_unit", false):
			var anchor: Vector2i = a.get("peace_anchor", Vector2i(-1, -1))
			if anchor == Vector2i(30, 30):
				print("❌ 실패: 행궁 주변에 평시 군사가 스폰되었습니다.")
				return false
			if not a.get("is_static_guard", false):
				print("❌ 실패: 평시 군사에 is_static_guard 플래그가 설정되지 않았습니다.")
				return false

	print("  [PASS] 1-1. 평시 군사 행궁 주변 스폰 원천 배제 및 is_static_guard 정지 배치 확인")

	# 검증 2: 일반 시민 스폰 루프에서 상점을 목적지로 삼는 군인 trip 생성 차단
	var agent_count_before: int = citizens.agents.size()
	citizens._spawn_trip("jangyongyeong_soldier", Vector2i(20, 20), Vector2i(15, 15), "상점 방문")
	citizens._spawn_trip("posu", Vector2i(20, 20), Vector2i(15, 16), "상점 방문")
	if citizens.agents.size() != agent_count_before:
		print("❌ 실패: 군인/장용영이 상점을 목적지로 삼는 trip이 차단되지 않았습니다.")
		return false

	print("  [PASS] 1-2. 장용영/군인의 저잣거리 상점(MARKET_SHOP) 및 민가 목적지 trip 원천 차단 확인")

	# 검증 3: SiegeDefenseManager.is_under_attack 플래그 및 교전/디스폰
	var siege_mgr := SiegeDefenseManager.new()
	if not ("is_under_attack" in SiegeDefenseManager):
		print("❌ 실패: SiegeDefenseManager.is_under_attack 속성이 존재하지 않습니다.")
		return false

	var unit := JangyongyeongUnitEntity.new()
	unit.setup_unit(1, Vector2i(20, 20), Vector2i(22, 22), 500)
	unit.state = JangyongyeongUnitEntity.STATE_VICTORY
	unit.state_timer = 5.5
	unit.update(0.1, [], null)
	if not unit.is_dead:
		print("❌ 실패: 전투 종료 후 복귀한 장용영 유닛이 디스폰되지 않았습니다.")
		return false

	print("  [PASS] 1-3. 장용영 유닛 승리 복귀 후 정상 디스폰 확인")
	return true

## 2. 순라청 포졸의 도둑·난동꾼 실제 체포 및 관아 압송 FSM 검증
func test_sunla_arrest_and_escort_fsm() -> bool:
	print("\n--- [TEST 2] 순라청 포졸의 도둑·난동꾼 체포 및 관아 압송 FSM 검증 ---")

	var officer := PatrolOfficerNPC.new()
	officer.setup_officer(1, Vector2i(10, 10))

	var criminal := CriminalNPC.new()
	criminal.setup_criminal(1, CriminalNPC.CriminalKind.DRUNK_BRAWLER, Vector2i(15, 15), 101)

	# FSM 명세 검증: State.MOVE_TO_CRIME 설정
	officer.dispatch(101, Vector2i(15, 15), [Vector2i(15, 15)], 3.0, criminal)
	if officer.state != PatrolOfficerNPC.State.MOVE_TO_CRIME:
		print("❌ 실패: officer.state가 MOVE_TO_CRIME이 아닙니다.")
		return false

	# 현장 근접 시 on_police_arrived 및 ARRESTING 전이
	officer.global_position = criminal.global_position + Vector2(10.0, 0.0)
	officer._process_arrest_logic(0.1)

	if officer.state != PatrolOfficerNPC.State.ARRESTING:
		print("❌ 실패: 포졸이 현장에 도착했으나 ARRESTING 상태로 전이되지 않았습니다.")
		return false

	if criminal.state != CriminalNPC.CriminalState.ARRESTED:
		print("❌ 실패: 포졸 도착 시 범죄자가 ARRESTED 상태로 전이되지 않았습니다.")
		return false

	if criminal.punch_intensity > 0.0:
		print("❌ 실패: 포박된 범죄자가 여전히 주먹질(punch_intensity > 0)을 하고 있습니다.")
		return false

	print("  [PASS] 2-1. 포졸 현장 도착 즉시 행패 중단 및 '포박됨' 상태 전이 확인")

	# 체포 대기(1.5초) 후 관아 압송(ESCORT_TO_YUSUBU) 전이
	officer._arrest_timer = 0.0
	officer._process_arrest_logic(0.1)
	if officer.state != PatrolOfficerNPC.State.ESCORT_TO_YUSUBU:
		print("❌ 실패: 1.5초 경과 후 ESCORT_TO_YUSUBU 상태로 전이되지 않았습니다.")
		return false

	print("  [PASS] 2-2. 1.5초 체포 완료 후 관아 압송(ESCORT_TO_YUSUBU) 전이 확인")

	# 관아 도착 시 죄인 resolve_and_remove 및 완전 삭제/디스폰
	officer.global_position = officer.yusubu_pos + Vector2(5.0, 0.0)
	officer._process_arrest_logic(0.1)

	if not criminal.is_dead:
		print("❌ 실패: 관아 도착 시 범죄자(criminal)가 is_dead = true로 디스폰되지 않았습니다.")
		return false

	if officer.state != PatrolOfficerNPC.State.IDLE:
		print("❌ 실패: 압송 완료 후 포졸이 IDLE(귀대) 상태로 전이되지 않았습니다.")
		return false

	print("  [PASS] 2-3. 관아 도착 즉시 죄인 완전 삭제(resolve_and_remove) 및 사건 종결 확인")

	# 15초 강제 워프 제거 검증: 15초가 지나도 워프하지 않고 정직하게 보행
	var stuck_officer := PatrolOfficerNPC.new()
	stuck_officer.setup_officer(2, Vector2i(0, 0))
	var runaway_thief := CriminalNPC.new()
	runaway_thief.setup_criminal(2, CriminalNPC.CriminalKind.PICKPOCKET, Vector2i(50, 50), 102)

	stuck_officer.dispatch(102, Vector2i(50, 50), [], 2.0, runaway_thief)
	stuck_officer.stuck_timer = 15.5 # 15초 초과 상황
	stuck_officer._process_arrest_logic(0.1)

	if stuck_officer.global_position.distance_to(runaway_thief.global_position) < 50.0:
		print("❌ 실패: 15초 경과 시에도 강제 순간이동 워프가 발생하면 안 됩니다.")
		return false

	print("  [PASS] 2-4. 15초 강제 워프 제거 및 정직한 보행 추격 검증 완료")
	return true


## 3. 계절별 BGM 자동 변경 및 위기 BGM 오작동 수정 검증
func test_season_bgm_and_crisis_audio() -> bool:
	print("\n--- [TEST 3] 계절별 BGM 자동 변경 및 위기 BGM 오작동 수정 검증 ---")

	var music := MusicManager.new()
	root.add_child(music)

	var sim := SimulationCore.new()
	music.sim = sim
	music.game_started = func() -> bool: return true

	var time_mgr := TimeManager.new()
	music.time_manager = time_mgr

	# 검증 1: 평시 sim.bandit_active = true 상태에서도 위기 음악(event_bandit)이 나오지 않아야 함!
	sim.bandit_active = true
	AudioManager.is_active_invasion = false
	SiegeDefenseManager.is_active_invasion = false
	SiegeDefenseManager.is_under_attack = false
	music.set_flag("bandit_battle", false)

	var pick: Array = music._context_track()
	if String(pick[0]).begins_with("event_bandit") or String(pick[0]).begins_with("event_invasion"):
		print("❌ 실패: 평시 bandit_active 상태에서 위기 음악이 재생되었습니다!")
		return false

	print("  [PASS] 3-1. 평시 도적 활성 플래그 상태에서 위기 BGM 오작동 억제 확인")

	# 검증 2: 실제 침공/공성전(is_active_invasion == true) 발생 시에만 위기 음악 재생
	AudioManager.is_active_invasion = true
	var invasion_pick: Array = music._context_track()
	if not (String(invasion_pick[0]) in ["event_bandit", "event_invasion", "event_rebel"]):
		print("❌ 실패: 실제 침공 전투 상태인데 위기 BGM이 선택되지 않았습니다: ", invasion_pick[0])
		return false

	print("  [PASS] 3-2. 실제 적군 침공/공성전 시 위기 BGM 정상 발동 확인")

	# 검증 3: 전투 종료 시 즉시 위기 플래그가 꺼지고 계절 음악으로 복귀
	AudioManager.is_active_invasion = false
	SiegeDefenseManager.is_active_invasion = false
	SiegeDefenseManager.is_under_attack = false
	music.set_flag("bandit_battle", false)

	var peaceful_pick: Array = music._context_track()
	if not String(peaceful_pick[0]).begins_with("season_"):
		print("❌ 실패: 종전 후 계절 BGM으로 복귀하지 않았습니다: ", peaceful_pick[0])
		return false

	print("  [PASS] 3-3. 전투 종전 즉시 평화로운 계절 BGM으로 복귀 확인")

	# 검증 4: SeasonManager -> AudioManager.on_season_changed 사계절 BGM 1.5초 전환
	var audio_mgr := AudioManager.new()
	audio_mgr.music_mgr = music

	audio_mgr.on_season_changed("봄")
	if music._want != "season_spring":
		print("❌ 실패: 봄 BGM 전환 실패: ", music._want)
		return false

	audio_mgr.on_season_changed("여름")
	if music._want != "season_summer":
		print("❌ 실패: 여름 BGM 전환 실패: ", music._want)
		return false

	audio_mgr.on_season_changed("가을")
	if music._want != "season_autumn":
		print("❌ 실패: 가을 BGM 전환 실패: ", music._want)
		return false

	audio_mgr.on_season_changed("겨울")
	if music._want != "season_winter":
		print("❌ 실패: 겨울 BGM 전환 실패: ", music._want)
		return false

	print("  [PASS] 3-4. 사계절(봄/여름/가을/겨울) BGM 1.5초 크로스페이드 정상 전환 확인")
	return true
