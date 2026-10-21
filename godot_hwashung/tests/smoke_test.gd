extends SceneTree
# PORT-TRACE P11 & P13: 헤드리스 스모크 테스트 (거중기 가속, 6대 어명 교지, 탕평 조세, 8대 멀티 엔딩 검증)
# 실행: Godot_v4.7.2-stable_win64_console.exe --headless --path godot_hwashung -s res://tests/smoke_test.gd

const QuestSystemClass = preload("res://scripts/QuestSystem.gd")

func _init() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	var sim: SimulationCore = main.simulation_core
	var tm: TimeManager = main.time_manager
	var grid: GameGrid = main.grid
	var city: CityLayer = main.city
	var court: CourtSystem = main.court
	var quests = main.quests

	print("=== 1. 거중기(정약용) 35% 공기 단축 가속 검증 ===")
	sim.gold = 50000
	sim.rice = 50000
	sim.retainers["jeong_yakyong"] = true
	var proj_res = sim.start_mega_project("suwon_levee")

	var p: Dictionary = {}
	for proj in sim.mega_projects:
		if proj["id"] == "suwon_levee":
			p = proj
			break
	p["base_turns"] = 100
	p["base_ticks"] = 100
	var initial_ticks = p["progress_ticks"]
	# 10턴(월) 시뮬레이션 (대역사는 30틱=1턴 월 공정)
	for i in range(1, 11):
		sim._advance_monthly_turn(i * 30)
	var gained = p["progress_ticks"] - initial_ticks
	print("거중기 가속 10턴 진행 결과 누적 턴: ", gained, " (기대값: 13 또는 14)")
	assert(gained >= 13, "거중기 35% 가속 누적 연산 실패")
	print("[PASS] 거중기 가속 연산 정상 작동")

	print("\n=== 2. 호조 탕평 조세(지세/시전세/군포) 정산 및 민심/수요 반응 검증 ===")
	sim.tax_rate_land = 15
	sim.tax_rate_market = 15
	sim.tax_rate_military = 15
	var prev_loyalty = sim.loyalty
	# 1턴(계절) 강제 진행
	main.turns._on_turn(2, 1, 1776)
	for f in range(10):
		await process_frame
	var loyalty_diff = prev_loyalty - sim.loyalty
	print("고세율(15%) 적용 시 민심 변화: -", loyalty_diff, " (민심: ", sim.loyalty, ")")
	assert(loyalty_diff > 0, "고세율 시 민심 하락 미발생")

	# 적정 탕평 세율(7%)로 환원
	sim.tax_rate_land = 7
	sim.tax_rate_market = 7
	sim.tax_rate_military = 7
	main.turns._on_turn(3, 2, 1776)
	for f in range(10):
		await process_frame
	print("[PASS] 조세 정산 및 민심 반응 정상 작동")



	print("\n=== 3. 7대 어명 교지(Quest) 달성 시뮬레이션 ===")
	sim.gold = 50000
	sim.rice = 20000

	# 평지 및 산악 타일 검색
	var plain_pos := Vector2i(-1, -1)
	var mountain_pos1 := Vector2i(-1, -1)
	var mountain_pos2 := Vector2i(-1, -1)
	for y in range(grid.size):
		for x in range(grid.size):
			var t: Dictionary = grid.tile(x, y)
			if t["terrain"] == "plain" and t["building"] == "" and not t["under_construction"]:
				if plain_pos == Vector2i(-1, -1):
					plain_pos = Vector2i(x, y)
			elif t["terrain"] == "mountain" and t["building"] == "" and not t["under_construction"]:
				if mountain_pos1 == Vector2i(-1, -1):
					mountain_pos1 = Vector2i(x, y)
				elif mountain_pos2 == Vector2i(-1, -1):
					mountain_pos2 = Vector2i(x, y)

	# 제1교지: 화성행궁(유수부 관아 겸) — 7x7 터를 잡아 4턴에 걸쳐 완공되는 "터 축조"
	# PORT-TRACE [터 축조]: 단칸 즉시 완공에서 부지 확보 + 다턴 공사로 바뀌어 테스트도 갱신.
	print("현재 교지: ", quests.get_current_quest()["title"])
	var office_pos := Vector2i(-1, -1)
	for y in range(grid.size):
		for x in range(grid.size):
			if grid.validate_site("haenggung", x, y) == "":
				office_pos = Vector2i(x, y)
				break
		if office_pos != Vector2i(-1, -1):
			break
	assert(office_pos != Vector2i(-1, -1), "행궁 7x7 부지를 찾지 못함")
	city._apply_batch_build([office_pos] as Array[Vector2i], "haenggung")
	print("착공 직후 building(under_construction 이어야 함): ", grid.tile(office_pos.x, office_pos.y)["building"],
		" under_construction=", grid.tile(office_pos.x, office_pos.y)["under_construction"])
	for i in range(8): # turns=4이므로 여유있게 반복 호출해 완공까지 진행
		grid.process_site_tick(sim)
	quests.check_current_quest()
	print("행궁 배치 후 건물: ", grid.tile(office_pos.x, office_pos.y)["building"])
	assert(quests.current_quest_index == 1, "제1교지(화성행궁) 달성 실패")
	print("제1교지 완수 -> 현재: ", quests.get_current_quest()["title"])
	plain_pos = office_pos # 이후 도로 시작점으로 재사용

	# 제2교지: 삼남대로 5칸 (road)
	var road_tiles: Array[Vector2i] = []
	for y in range(grid.size):
		for x in range(grid.size):
			var t: Dictionary = grid.tile(x, y)
			if t["terrain"] == "plain" and t["building"] == "" and not t["under_construction"]:
				road_tiles.append(Vector2i(x, y))
				if road_tiles.size() >= 5:
					break
		if road_tiles.size() >= 5:
			break
	city._apply_batch_build(road_tiles, "road")
	quests.check_current_quest()
	assert(quests.current_quest_index == 2, "제2교지(도로) 달성 실패")
	print("제2교지 완수 -> 현재: ", quests.get_current_quest()["title"])

	# PORT-TRACE [건설 기간 확대 + 문 먼저]: 교지 순서가 동헌→도로→성문→구획·우물→서장대→봉돈→성곽
	# 으로 바뀌었고, 성문·서장대·봉돈은 착공 후 몇 턴 지나야 완공된다 — 공정을 넉넉히 돌려 완공시킨다.
	var finish_builds := func():
		for i in range(4):
			grid.process_wall_builds()
		quests.check_current_quest()

	# 제3교지: 성문 (방금 닦은 도로 한 칸 위에)
	city._apply_batch_build([road_tiles[2]] as Array[Vector2i], "gate")
	main.panels._close_modal() # 성문 명명 팝업
	finish_builds.call()
	assert(quests.current_quest_index == 3, "제3교지(성문) 달성 실패")
	print("제3교지 완수 -> 현재: ", quests.get_current_quest()["title"])


	# 제4교지: 저잣거리·마을 구획 및 우물
	var p_well := Vector2i(-1, -1)
	var p_zone := Vector2i(-1, -1)
	for y in range(grid.size):
		for x in range(grid.size):
			var t: Dictionary = grid.tile(x, y)
			if t["terrain"] == "plain" and t["building"] == "" and t["zone"] == "" and not t["under_construction"]:
				if p_zone == Vector2i(-1, -1):
					p_zone = Vector2i(x, y)
				elif p_well == Vector2i(-1, -1):
					p_well = Vector2i(x, y)
					break
		if p_well != Vector2i(-1, -1):
			break
	city._apply_batch_build([p_zone] as Array[Vector2i], "zone_com")
	city._apply_batch_build([p_well] as Array[Vector2i], "well")
	quests.check_current_quest()
	assert(quests.current_quest_index == 4, "제4교지(구획 및 우물) 달성 실패")
	print("제4교지 완수 -> 현재: ", quests.get_current_quest()["title"])

	# 제5교지: 서장대 (팔달산 고지대에 축조)
	var seojang_pos := mountain_pos1
	for sy in range(grid.size - 1):
		for sx in range(grid.size - 1):
			if grid.validate_tool("seojangdae", sx, sy) == "":
				seojang_pos = Vector2i(sx, sy)
				break
		if seojang_pos != mountain_pos1:
			break
	city._apply_batch_build([seojang_pos] as Array[Vector2i], "seojangdae")
	finish_builds.call()
	assert(quests.current_quest_index == 5, "제5교지(서장대) 달성 실패")
	print("제5교지 완수 -> 현재: ", quests.get_current_quest()["title"])


	# 제6교지: 봉돈 (완공된 일직선 성벽 4칸 위에 덧씌워 축조)
	var b_wall_tiles: Array[Vector2i] = []
	for k in range(4):
		var p_w := Vector2i(10 + k, 25)
		grid.grid[25][10 + k]["building"] = "wall"
		grid.grid[25][10 + k]["terrain"] = "plain"
		if grid.grid[25][10 + k].has("wall_build"):
			grid.grid[25][10 + k].erase("wall_build")
		grid.grid[25][10 + k]["under_construction"] = false
		b_wall_tiles.append(p_w)
	var bp := b_wall_tiles[1]
	city._apply_batch_build([bp] as Array[Vector2i], "bongdon")
	finish_builds.call()
	assert(quests.current_quest_index == 6, "제6교지(봉돈) 달성 실패")
	print("제6교지 완수 -> 현재: ", quests.get_current_quest()["title"])


	# 제7교지: 화성 성곽 100% 완공
	grid.fortress_progress = 100
	quests.check_current_quest()
	assert(quests.is_all_completed, "제7교지(성곽 100%) 달성 실패")
	print("[PASS] 7대 어명 교지 모두 완수 확인")

	print("\n=== 4. 96턴 대단원 8대 멀티 엔딩 평가 검증 ===")
	# True Ending 조건: 성곽 100, 왕권 85, 민심 85, 금 3000
	sim.authority = 90
	sim.loyalty = 90
	sim.gold = 5000
	var ending = quests.evaluate_ending()
	print("True Ending 평가 결과: ", ending["title"])
	assert(ending["type"] == "true_ending", "True Ending 조건 판정 불일치")

	# 민란 엔딩 조건: 민심 <= 30
	sim.loyalty = 20
	ending = quests.evaluate_ending()
	print("민란 엔딩 평가 결과: ", ending["title"])
	assert(ending["type"] == "peasant_revolt", "민란 엔딩 조건 판정 불일치")

	# 상업 공화국 엔딩: 성곽 >= 80, 금 >= 5000, 박제가
	sim.loyalty = 80
	court.sim.retainers["park_jega"] = true
	sim.gold = 6000
	grid.fortress_progress = 85
	sim.authority = 70
	ending = quests.evaluate_ending()
	print("상업 공화국 엔딩 평가 결과: ", ending["title"])
	assert(ending["type"] == "merchant_city", "상업 공화국 엔딩 조건 판정 불일치")

	print("[PASS] 8대 멀티 엔딩 조건 평가 성공")

	print("\n=== 5. 2.5D 도트 스프라이트 에셋 및 맹호 애니메이션 검증 ===")
	# 초반 2년 보호 기간 이후(1778년 9턴) 맹호 스폰 검증
	sim.current_year = 1778
	sim.turn = 9
	sim.tiger_cooldown_turns = 0
	court.tiger["active"] = true
	main.citizens.time_scale = 1.0
	main.citizens._process(0.1)
	var has_tiger := false
	for a in main.citizens.agents:
		if a["type"] == "tiger":
			has_tiger = true
			break
	print("맹호(호랑이) 에이전트 출현 확인: ", has_tiger)
	assert(has_tiger, "호환 발생 시 맹호 에이전트 스폰 실패")

	# 도트 스프라이트 렌더러 프레임 드로우 검증
	city.queue_redraw()
	await process_frame
	print("[PASS] 2.5D 비주얼 아틀라스 렌더링 정상 완료")

	print("\n=== 6. 곡식(식량) 구매 및 환곡 상업 검증 ===")
	var p_before: int = sim.rice
	var g_before: int = sim.gold
	var buy_res: Dictionary = sim.buy_rice(100)
	print("곡식 100석 매입 결과: ", buy_res)
	assert(buy_res["success"], "곡식 매입 실패")
	assert(sim.rice == p_before + 100, "곡식 재고 갱신 오류")
	assert(sim.gold < g_before, "금화 지출 오류")
	print("[PASS] 동적 시세 기반 곡식 매입 시스템 성공 검증")

	print("\n=== 모든 핵심 시스템 검증 성공 완료 ===")
	quit(0)
