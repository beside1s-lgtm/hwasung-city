extends SceneTree

# 신규 시스템 검증: 건축 추천 고증화, 4대문 순차 추천, 봉돈 성곽 연동, 국방시설 대역사, 만석거 북서 외곽, 둔전 8타일 & 농업 Life Simulation

func _init() -> void:
	print("=== 신규 시스템 통합 검증 시작 ===")
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	var grid: GameGrid = main.grid
	var sim: SimulationCore = main.simulation_core
	var quests: QuestSystem = main.quests
	var outside: OutsideSettlement = main.outside
	var citizens: CitizenManager = main.citizens

	# 1. 건축 추천 고증화 검증
	print("\n[검증 1] 화성행궁 추천 위치 고증화")
	var hg_hint: Vector2i = quests.find_hint_position("haenggung")
	print("  행궁 추천 위치: ", hg_hint)
	assert(hg_hint.x >= 18 and hg_hint.x <= 24 and hg_hint.y >= 28 and hg_hint.y <= 36, "행궁 추천 위치가 팔달산 동쪽 기슭 분지 평지 범위를 벗어남")
	print("  -> PASS: 화성행궁 고증 위치 추천 정상")

	print("\n[검증 2] 4대문 및 화홍문 순차 추천")
	var gate1_hint: Vector2i = quests.find_hint_position("gate")
	print("  1단계 성문 추천 위치 (장안문 기대): ", gate1_hint)
	assert(gate1_hint == Vector2i(26, 6), "첫 번째 성문 추천이 장안문(26, 6)이 아님")

	# 장안문 위치에 성문 건설
	grid.grid[6][26]["building"] = "gate"
	grid.grid[6][26].erase("wall_build")
	var gate2_hint: Vector2i = quests.find_hint_position("gate")
	print("  2단계 성문 추천 위치 (팔달문 기대): ", gate2_hint)
	assert(gate2_hint == Vector2i(16, 54), "두 번째 성문 추천이 팔달문(16, 54)이 아님")
	print("  -> PASS: 4대문 순차 추천 순환 정상")

	print("\n[검증 3] 봉돈 추천: 성곽 미완공 시 제한 및 완공 후 추천")
	var bg_hint_early: Vector2i = quests.find_hint_position("bongdon")
	print("  성곽 미완공 상태 봉돈 추천: ", bg_hint_early)
	assert(bg_hint_early == Vector2i(-1, -1), "성곽 미완공 시 봉돈 추천이 제한되지 않음")

	# 성곽 축조 (15칸 완공 성곽 배치)
	for i in range(15):
		var wx: int = 40 + (i % 5)
		var wy: int = 42 + int(i / 5)
		grid.grid[wy][wx]["building"] = "wall"
		grid.grid[wy][wx].erase("wall_build")
	var bg_hint_ready: Vector2i = quests.find_hint_position("bongdon")
	print("  성곽 연결 완공 후 봉돈 추천: ", bg_hint_ready)
	assert(bg_hint_ready != Vector2i(-1, -1), "성곽 완공 후에도 봉돈 추천이 되지 않음")
	print("  -> PASS: 봉돈 성곽 완공 조건 연동 정상")

	print("\n[검증 4] 국책대역사 국방시설 강화 및 성곽 부속 시설 자동 탑재")
	# 성곽이 전혀 없는 상태에서의 국방시설 착공 차단 검사
	var fresh_grid: GameGrid = GameGrid.new()
	root.add_child(fresh_grid)
	var blocked_res = sim.start_mega_project("defense_fortification", fresh_grid)
	print("  성곽 부재 시 착공 결과: ", blocked_res)
	assert(not blocked_res.get("success", true), "성곽 부재 시 착공이 차단되지 않음")
	assert("성곽을 먼저 축조해야 합니다" in blocked_res.get("msg", ""), "성곽 경고 메시지 불일치")
	fresh_grid.queue_free()

	# 성곽이 있을 때의 착공
	sim.gold = 10000
	sim.rice = 10000
	var success_res = sim.start_mega_project("defense_fortification", grid)
	print("  성곽 완공 상태 착공 결과: ", success_res)
	assert(success_res.get("success", false), "성곽 완공 상태에서 착공 실패")
	print("  -> PASS: 국방시설 대역사 유효성 검사 및 착공 정상")

	print("\n[검증 5] 만석거 대역사 생성 위치 북서 최외곽 검증")
	var manseok_proj: Dictionary = {}
	for p in sim.mega_projects:
		if p["id"] == "manseok_reservoir":
			manseok_proj = p
			break
	assert(not manseok_proj.is_empty(), "만석거 대역사가 없음")
	for tile in manseok_proj["target_tiles"]:
		assert(tile["x"] <= 14 and tile["y"] <= 6, "만석거 타일이 북서 최외곽 범위를 벗어나 도심 침범 가능성 있음: %s" % str(tile))
	print("  만석거 대상 타일 전부 북서 최외곽 확인 완료 (x <= 14, y <= 6)")
	print("  -> PASS: 만석거 북서 최외곽 배치 정상")

	print("\n[검증 6] 대유둔전 반경 8타일 확장 및 영농 Life Simulation 연출 검증")
	# 둔전 타일 4개 배치
	for k in range(4):
		var fx: int = 12 + k
		var fy: int = 4
		grid.grid[fy][fx]["zone"] = "agr"
		grid.grid[fy][fx]["building"] = "agr_1"
	citizens.current_season = "가을"
	# 시민 캐시 및 스폰 갱신
	citizens._roads_dirty = true
	citizens._refresh_caches()
	citizens._sync_spot_agents()

	var farmer_cnt: int = 0
	var ox_cnt: int = 0
	var cart_cnt: int = 0
	var scarecrow_cnt: int = 0
	var sparrow_cnt: int = 0

	for a in citizens.agents:
		match a.get("type", ""):
			"farmer": farmer_cnt += 1
			"ox_plow": ox_cnt += 1
			"farmer_cart": cart_cnt += 1
			"scarecrow": scarecrow_cnt += 1
			"sparrow_flock": sparrow_cnt += 1

	print("  스폰된 영농 에이전트 수:")
	print("    - 농민 (farmer): ", farmer_cnt)
	print("    - 소 쟁기질 (ox_plow): ", ox_cnt)
	print("    - 수레 농민 (farmer_cart): ", cart_cnt)
	print("    - 허수아비 (scarecrow): ", scarecrow_cnt)
	print("    - 가을 참새 떼 (sparrow_flock): ", sparrow_cnt)

	assert(farmer_cnt > 0, "농민이 스폰되지 않음")
	assert(ox_cnt > 0, "소 쟁기질 에이전트가 스폰되지 않음")
	assert(scarecrow_cnt > 0, "허수아비가 스폰되지 않음")
	assert(sparrow_cnt > 0, "가을 참새 떼가 스폰되지 않음")

	# 프레임 시뮬레이션 동작 검증
	citizens._process(0.1)
	print("  -> PASS: 영농 Life Simulation 에이전트 정상 스폰 및 구동")

	print("\n=== 모든 신규 시스템 검증 100% 통과 ===")
	quit(0)
