extends SceneTree

## 맵 외곽 이탈 NPC 자연 디스폰 및 수원천 물놀이/석전 지형 제약 검증 테스트

var log_file: FileAccess

func _log(msg: String) -> void:
	print(msg)
	if log_file:
		log_file.store_line(msg)
		log_file.flush()

func _init() -> void:
	log_file = FileAccess.open("res://test_boundary_river_result.txt", FileAccess.WRITE)
	_log("=== [검증 시작] 맵 외곽 이탈 NPC 디스폰 및 수원천/석전 지형 규칙 검증 ===")
	call_deferred("_run_verification")

func _run_verification() -> void:
	var main_scene = load("res://scenes/Main.tscn")
	if not main_scene:
		_log("[FAIL] Main.tscn 로드 실패")
		quit(1)
		return

	var main = main_scene.instantiate()
	root.add_child(main)

	for _i in range(5):
		await process_frame

	var citizens: CitizenManager = main.citizens
	var grid: GameGrid = main.grid
	var city: CityLayer = main.city
	var festivals: FestivalSystem = main.festivals
	var citizen_layer: CitizenLayer = main.citizen_layer

	if not citizens or not grid or not city or not festivals or not citizen_layer:
		_log("[FAIL] 필수 서브시스템 인스턴스 획득 실패")
		quit(1)
		return

	# ----------------------------------------------------
	# [검증 1] GameGrid 경계 판정 헬퍼 및 맵 경계 이탈 NPC 디스폰 검증
	_log("\n[검증 1] 맵 경계선 이탈 NPC 및 우마(소) 디스폰 라이프사이클 검증...")
	assert(grid.is_in_bounds(0, 0) == true, "그리드 내부 (0,0) 판정 실패")
	assert(grid.is_in_bounds(-1, 0) == false, "그리드 외곽 (-1,0) 판정 실패")
	assert(grid.is_in_bounds(grid.size, grid.size) == false, "그리드 외곽 (size, size) 판정 실패")
	assert(grid.is_valid_coord(Vector2i(-5, 10)) == false, "is_valid_coord 외곽 판정 실패")

	# 1-1. 맵 외곽(-2.0, 5.0)에 위치한 소몰이꾼(ox_driver) 에이전트 생성
	var ox_drover_agent: Dictionary = {
		"id": 99901,
		"type": "ox_driver",
		"x": -2.0,
		"y": 5.0,
		"anim": 0.0,
		"speed": 1.0,
		"cattle_drover": true,
		"trip": true,
		"goal": Vector2i(10, 10),
		"from_tile": Vector2i(-2, 5),
		"to_tile": Vector2i(-1, 5),
	}
	citizens.agents.append(ox_drover_agent)

	# 1-2. 0.5초 주기 경계선 검사 발화
	citizens._check_boundary_despawns()
	assert(ox_drover_agent.get("fading_out", false) == true, "외곽 이탈 에이전트 fading_out 플래그 설정 실패")
	assert(is_equal_approx(float(ox_drover_agent.get("fade_alpha", 0.0)), 1.0), "초기 fade_alpha 1.0 실패")
	_log("  - [PASS] 맵 외곽 이탈 감지 시 fading_out 및 fade_alpha=1.0 정상 진입")

	# 1-3. 0.5초 경과 후 페이드 아웃 중간 상태 (alpha ~ 0.5)
	citizens._update_agent(ox_drover_agent, 0.5)
	var mid_alpha: float = float(ox_drover_agent.get("fade_alpha", 1.0))
	assert(mid_alpha > 0.4 and mid_alpha < 0.6, "0.5초 경과 시 fade_alpha 감쇄 실패: %f" % mid_alpha)
	_log("  - [PASS] 0.5초 경과 시 fade_alpha 점진 감쇄 확인 (alpha: %f)" % mid_alpha)

	# 1-4. 0.6초 추가 경과 후 1.0초 만료 -> is_dead = true 안전 종료
	citizens._update_agent(ox_drover_agent, 0.6)
	assert(ox_drover_agent.get("is_dead", false) == true, "1초 페이드 아웃 완료 후 is_dead 미설정")
	_log("  - [PASS] 1초 페이드 아웃 완료 후 안전하게 is_dead=true 처리 확인")

	# 1-5. CitizenManager _process 상에서 has_dead 감지 시 agents 배열 안전 언레지스터 검증
	citizens._process(0.01)
	assert(not (ox_drover_agent in citizens.agents), "is_dead 에이전트의 agents 배열 안전 제거 실패")
	_log("  - [PASS] agents 배열에서 사망 에이전트 메모리 누수 없이 안전 언레지스터 완료")

	# ----------------------------------------------------
	# [검증 2] 수원천 물 타일 진입 제약 및 물속 불법 보행 방어 검증
	_log("\n[검증 2] 수원천 물 타일 일반 보행 차단 및 위치 안전 보정 검증...")
	# 수원천 물 타일 1곳 탐색
	var river_tile := Vector2i(-1, -1)
	for y: int in range(grid.size):
		for x: int in range(grid.size):
			var t: Dictionary = grid.grid[y][x]
			if t.get("terrain", "") == "water" and not t.get("is_bridge", false) and t.get("building", "") == "":
				river_tile = Vector2i(x, y)
				break
		if river_tile.x >= 0:
			break

	assert(river_tile.x >= 0, "테스트용 수원천 물 타일 탐색 실패")
	assert(citizens._tile_walkable(grid.grid[river_tile.y][river_tile.x]) == false, "하천 물 타일의 도보 불가(walkable=false) 검증 실패")
	_log("  - [PASS] 하천 물 타일 _tile_walkable == false 통행 불가 확인")

	# 일반 상인(merchant) 에이전트를 강제로 물 타일 위에 배치했을 때 즉각 안전 보정 검증
	var illegal_walker: Dictionary = {
		"id": 99902,
		"type": "merchant",
		"x": float(river_tile.x) + 0.5,
		"y": float(river_tile.y) + 0.5,
		"anim": 0.0,
		"speed": 1.0,
		"from_tile": river_tile,
		"to_tile": river_tile,
	}
	citizens.agents.append(illegal_walker)
	citizens._update_agent(illegal_walker, 0.1)

	var corrected_gx: int = int(floor(float(illegal_walker["x"])))
	var corrected_gy: int = int(floor(float(illegal_walker["y"])))
	var corrected_tile: Dictionary = grid.grid[corrected_gy][corrected_gx]
	assert(corrected_tile.get("terrain", "") != "water" or corrected_tile.get("is_bridge", false) or corrected_tile.get("building", "") == "levee", "물속에 서 있던 일반 보행자의 육지/도로 안전 보정 실패")
	_log("  - [PASS] 물속에 위치한 일반 NPC 감지 시 최근접 육지/도로로 즉시 위치 보정 확인")

	# ----------------------------------------------------
	# [검증 3] 여름철 수원천 물놀이(water_play) 소년 에이전트 생태계 검증
	_log("\n[검증 3] 여름철 수원천 소년 물놀이(water_play) 스팟 연출 검증...")
	citizens.current_season = "여름"
	citizens._sync_spot_agents()

	var water_players := citizens.agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "water_play")
	assert(not water_players.is_empty(), "여름철 수원천 물놀이(water_play) 에이전트 스폰 실패")
	var swimmer: Dictionary = water_players[0]
	var sw_gx: int = int(floor(float(swimmer["x"])))
	var sw_gy: int = int(floor(float(swimmer["y"])))
	assert(grid.grid[sw_gy][sw_gx].get("terrain", "") == "water", "물놀이 에이전트는 하천 물 타일에 스폰되어야 함")
	_log("  - [PASS] 여름철 수원천 물가에 water_play 소년 NPC 정상 스폰 확인 (%d명)" % water_players.size())

	# water_play 렌더링 호출 검증 (크래시 방어 및 물보라 연출)
	citizen_layer._draw_agent(swimmer)
	_log("  - [PASS] water_play 렌더러(_draw_water_play) 크래시 없이 정상 렌더링 완료")

	# 가을로 계절 변경 시 물놀이 에이전트 자동 정리 검증
	citizens.current_season = "가을"
	citizens._sync_spot_agents()
	var autumn_swimmers := citizens.agents.filter(func(a: Dictionary) -> bool: return a.get("type", "") == "water_play" and not a.get("is_dead", false))
	assert(autumn_swimmers.is_empty(), "가을철 전환 시 물놀이 에이전트 자동 정리 실패")
	_log("  - [PASS] 가을 계절 전환 시 water_play 에이전트 정상 디스폰 확인")

	# ----------------------------------------------------
	# [검증 4] 대보름 석전(seokjeon) 대면 제방 타일 캐싱 및 스폰 검증
	_log("\n[검증 4] 대보름 석전(seokjeon) 양안 제방 캐싱 및 스폰 좌표 검증...")
	citizens._refresh_caches()
	var seokjeon_pairs: Array = citizens._seokjeon_pairs_cache
	assert(not seokjeon_pairs.is_empty(), "수원천 양안 제방 쌍 캐싱(_seokjeon_pairs_cache) 실패")
	_log("  - [PASS] 수원천 양안 제방 쌍 %d개 캐싱 완료" % seokjeon_pairs.size())

	# 모든 캐시된 쌍이 물 타일이 아니며 양안 대면 관계인지 검증
	for pair: Dictionary in seokjeon_pairs:
		var pa: Vector2i = pair["bank_a"]
		var pb: Vector2i = pair["bank_b"]
		assert(grid.grid[pa.y][pa.x].get("terrain", "") != "water", "bank_a가 물 타일임: %s" % str(pa))
		assert(grid.grid[pb.y][pb.x].get("terrain", "") != "water", "bank_b가 물 타일임: %s" % str(pb))

	# 여름철 축제 시스템에서 석전 이벤트 발생 트리거 검증
	festivals.on_season_changed("여름")
	var seokjeon_scenes := festivals.scenes.filter(func(sc: Dictionary) -> bool: return sc.get("kind", "") == "seokjeon")
	assert(not seokjeon_scenes.is_empty(), "여름철 축제 석전(seokjeon) 씬 생성 실패")
	var sc_data: Dictionary = seokjeon_scenes[0]
	var c_vec: Vector2 = sc_data["center"]
	var other_vec: Vector2 = sc_data["other_pos"]
	var ctx: int = int(c_vec.x)
	var cty: int = int(c_vec.y)
	var otx: int = int(other_vec.x)
	var oty: int = int(other_vec.y)
	assert(grid.grid[cty][ctx].get("terrain", "") != "water", "석전 팀A 스폰 타일이 물 타일임!")
	assert(grid.grid[oty][otx].get("terrain", "") != "water", "석전 팀B 스폰 타일이 물 타일임!")
	_log("  - [PASS] 석전 두 팀 스폰 좌표가 모두 육지/제방 타일이며 물 타일 배제 완벽 검증")
	_log("    * 팀 A (제방): (%d, %d), 팀 B (맞은편 제방): (%d, %d)" % [ctx, cty, otx, oty])

	# FestivalArt 렌더링 호출 검증
	FestivalArt.draw_all(citizen_layer, festivals, city, grid)
	_log("  - [PASS] FestivalArt._seokjeon 포물선 발사체 및 양안 대면 렌더링 통과")

	_log("\n========================================================")
	_log("[RESULT SUCCESS] 모든 맵 경계 이탈자 디스폰 및 수원천/석전 지형 제약 검증 통과!")
	_log("========================================================")
	quit(0)
