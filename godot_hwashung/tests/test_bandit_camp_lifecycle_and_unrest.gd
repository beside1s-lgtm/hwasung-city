extends SceneTree

func _create_test_grid() -> GameGrid:
	var g := GameGrid.new()
	g.size = 64
	g.grid = []
	for y in range(64):
		var row: Array = []
		for x in range(64):
			# 외곽 험지(산지, 숲, 성 밖) 구성
			var ter: String = "outside"
			if (x < 10 or x > 50) and (y < 10 or y > 50):
				ter = "mountain"
			elif (x < 15 or x > 45) and (y < 15 or y > 45):
				ter = "forest"
			row.append({
				"terrain": ter,
				"surface": "grass",
				"building": "",
				"zone": "",
				"elevation": 0.0,
				"road_type": "dirt"
			})
		g.grid.append(row)
	return g

func _init() -> void:
	print("\n=== [테스트 시작] 도적 소굴 소탕 시 완전 소멸 및 민심 흉흉 시 동적 다중 스폰 검증 ===")

	var grid := _create_test_grid()
	var sim := SimulationCore.new()
	var citizens := CitizenManager.new()
	citizens.sim = sim
	citizens.grid = grid
	var b_mgr := BanditManager.new()
	b_mgr.init_outer_tiles(grid)
	citizens.bandit_mgr = b_mgr
	sim.bandit_manager = b_mgr

	# -------------------------------------------------------------------------
	# [검증 1] 초기 상태: 소굴이 없을 때 기본 소굴 0개 및 get_bandit_camp_pos() == (-1, -1) 검증
	# -------------------------------------------------------------------------
	print("[검증 1] 소굴 0개 시 맵 상 잔존 소굴 없음 검증...")
	assert(b_mgr.camps.is_empty(), "초기 소굴 수는 0개여야 함")
	var initial_camp_pos: Vector2i = citizens.get_bandit_camp_pos()
	assert(initial_camp_pos.x == -1 and initial_camp_pos.y == -1, "소굴이 없으면 (-1, -1)을 반환해야 함 (더 이상 고정 4,8에 잔존하지 않음)")
	print("  - 소굴 0개 시 고정 잔존 버그 차단 검증 통과")

	# -------------------------------------------------------------------------
	# [검증 2] 민심 흉흉 시 (loyalty <= 35) 성 밖 여기저기에 소굴 동적 스폰 검증
	# -------------------------------------------------------------------------
	print("[검증 2] 민심 흉흉 시 성 밖 여기저기 동적 소굴 스폰 검증...")
	sim.current_year = 1792 # 4년차 (보호기간 2년 종료)
	sim.turn = 13 # 봄
	sim.loyalty = 30 # 민심 흉흉
	sim.bandit_suppression_turns = 0

	# 턴 진행 -> 민심 흉흉으로 인한 소굴 스폰
	var turn_res: Dictionary = b_mgr.process_turn(sim, grid)
	assert(turn_res.get("camp_spawned", false) or b_mgr.camps.size() > 0, "민심 흉흉 시 소굴이 생성되어야 함")
	assert(b_mgr.camps.size() >= 1, "최소 1개 이상의 소굴이 생성됨 확인")

	# 다음 턴 (민심 20 극도 흉흉) -> 성 밖 다른 방면에 추가 스폰 ("여기저기 생김")
	sim.turn = 14
	sim.loyalty = 20
	b_mgr.process_turn(sim, grid)
	assert(b_mgr.camps.size() >= 2, "민심 극도 악화 시 성 밖에 복수의 소굴이 생성되어야 함 (현재: %d개)" % b_mgr.camps.size())

	# 소굴 위치 분산 검사 (서로 다른 좌표)
	var pos1: Vector2i = b_mgr.camps[0]["pos"]
	var pos2: Vector2i = b_mgr.camps[1]["pos"]
	assert(pos1 != pos2, "생성된 소굴들은 서로 다른 성 밖 위치에 분산되어야 함 (pos1: %s, pos2: %s)" % [pos1, pos2])
	print("  - 민심 흉흉 시 성 밖 여기저기 동적 스폰 (%d개소 분산 생성) 검증 통과" % b_mgr.camps.size())

	# -------------------------------------------------------------------------
	# [검증 3] 도적 침략 요격 성공 시 침략 소굴 즉시 완전 소멸 검증
	# -------------------------------------------------------------------------
	print("[검증 3] 도적 침공 격퇴/소탕 시 발원 소굴 즉시 파괴·소멸 검증...")
	var camp_count_before: int = b_mgr.camps.size()
	var target_camp_pos: Vector2i = b_mgr.camps[0]["pos"]
	b_mgr.bandit_camp_pos = target_camp_pos

	# finish_raid(true) -> 장용영의 승리 및 도적 전원 소탕
	var raid_finish_res: Dictionary = b_mgr.finish_raid(true, sim, grid, citizens)
	assert(raid_finish_res.get("repelled", false), "도적 격퇴 성공")
	assert(b_mgr.camps.size() == camp_count_before - 1, "격퇴 시 침략 소굴이 camps에서 즉시 제거되어야 함 (이전: %d -> 현재: %d)" % [camp_count_before, b_mgr.camps.size()])

	# 제거된 소굴 위치 검사
	for c: Dictionary in b_mgr.camps:
		assert(c.get("pos", Vector2i(-1, -1)) != target_camp_pos, "파괴된 소굴은 더 이상 목록에 존재하지 않아야 함")
	print("  - 도적 침공 격퇴 시 침략 소굴 완전 파괴 및 목록 제거 검증 통과")

	# -------------------------------------------------------------------------
	# [검증 4] 남은 소굴 수원유수부 토벌 출동으로 소탕 시 완전 소멸 검증
	# -------------------------------------------------------------------------
	print("[검증 4] 수원유수부 토벌대로 잔여 소굴 소탕 시 완전 소멸 검증...")
	sim.military_power = 900
	sim.gold = 5000
	sim.rice = 5000
	b_mgr.subjugation_cooldown_turns = 0

	while not b_mgr.camps.is_empty():
		var pre_cnt: int = b_mgr.camps.size()
		var sub_res: Dictionary = b_mgr.dispatch_yusubu_subjugation(sim, grid)
		assert(sub_res.get("victory", false), "아군 압도적 군사력으로 토벌 승리")
		assert(b_mgr.camps.size() == pre_cnt - 1, "토벌 성공 시 소굴 1개씩 완전 소멸")
		b_mgr.subjugation_cooldown_turns = 0 # 연속 테스트용

	assert(b_mgr.camps.is_empty(), "모든 소굴 소탕 후 camps 목록이 비어있어야 함 (0개)")
	var final_camp_pos: Vector2i = citizens.get_bandit_camp_pos()
	assert(final_camp_pos.x == -1 and final_camp_pos.y == -1, "모두 소탕된 후 맵에 소굴 좌표가 남지 않아야 함")
	print("  - 잔여 소굴 전원 소탕 및 맵 상 0개 클린 상태 검증 통과")

	# -------------------------------------------------------------------------
	# [검증 5] CitizenManager _end_bandit_raid(repelled: true) 연동 소멸 검증
	# -------------------------------------------------------------------------
	print("[검증 5] CitizenManager 격퇴 시 bandit_mgr 소굴 연동 소멸 검증...")
	b_mgr._spawn_bandit_camp(grid)
	assert(b_mgr.camps.size() == 1, "테스트용 소굴 1개 생성")
	citizens._end_bandit_raid(true)
	assert(b_mgr.camps.is_empty(), "CitizenManager 격퇴 종료 시에도 소굴이 즉시 제거되어야 함")
	print("  - CitizenManager 소굴 연동 소멸 검증 통과")

	print("\n=== [테스트 완료] 도적 소굴 소탕 시 완전 소멸 및 민심 흉흉 시 동적 다중 스폰 5대 항목 100% 통과! ===")
	quit(0)
