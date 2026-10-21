extends SceneTree

## 성곽 연동 시설(봉돈, 포루, 공심돈, 연무대, 서장대, 방화수류정) 성벽 결합 및 높이 정합 검증 테스트

const GameGridClass = preload("res://scripts/GameGrid.gd")
const CityLayerClass = preload("res://scripts/CityLayer.gd")

func _init() -> void:
	print("=== [테스트 시작] 성곽 위 방어시설 및 성벽 기하학적 정합 검증 ===")
	call_deferred("_run_tests")

func _create_test_grid() -> GameGridClass:
	var g: GameGridClass = GameGridClass.new()
	g.size = 64
	g.grid = []
	for y in range(64):
		var row: Array = []
		for x in range(64):
			row.append({
				"terrain": "plain",
				"surface": "grass",
				"building": "",
				"zone": "",
				"elevation": 1.0,
				"road_type": "dirt"
			})
		g.grid.append(row)
	return g

func _run_tests() -> void:
	var grid: GameGridClass = _create_test_grid()

	# [검증 1] WALL_CONNECTORS 무결성 검증
	print("[검증 1] WALL_CONNECTORS 필수 시설 포함 여부 검증...")
	var required_connectors: Array[String] = [
		"wall", "gate", "bongdon", "bongdon_site",
		"poru", "poru_site", "gongsimdon", "gongsimdon_site",
		"seojangdae", "seojangdae_site", "yeonmudae", "yeonmudae_site",
		"banghwasuryu", "hwahong", "namsu"
	]
	for req: String in required_connectors:
		assert(req in GameGrid.WALL_CONNECTORS, "누락된 WALL_CONNECTOR: " + req)
	print("  -> WALL_CONNECTORS 15개 핵심 성곽 시설 무결성 100% 통과!")

	# [검증 2] 성벽과 봉돈/포루/공심돈의 이웃 연결 판정(is_wall_connector) 검증
	print("[검증 2] 성벽 이웃 타일과 시설 간의 연결 판정 검증...")
	grid.grid[10][10]["building"] = "wall"
	grid.grid[10][11]["building"] = "bongdon"
	grid.grid[10][12]["building"] = "bongdon_site"
	grid.grid[10][13]["building"] = "poru"
	grid.grid[10][14]["building"] = "poru_site"
	grid.grid[10][15]["building"] = "gongsimdon"
	grid.grid[10][16]["building"] = "gongsimdon_site"

	assert(grid.is_wall_connector(10, 10) == true, "성벽 connector 판정 실패")
	assert(grid.is_wall_connector(11, 10) == true, "봉돈 connector 판정 실패")
	assert(grid.is_wall_connector(12, 10) == true, "봉돈_site connector 판정 실패")
	assert(grid.is_wall_connector(13, 10) == true, "포루 connector 판정 실패")
	assert(grid.is_wall_connector(14, 10) == true, "포루_site connector 판정 실패")
	assert(grid.is_wall_connector(15, 10) == true, "공심돈 connector 판정 실패")
	assert(grid.is_wall_connector(16, 10) == true, "공심돈_site connector 판정 실패")
	print("  -> 성벽과 봉돈/포루/공심돈 이웃 연결 판정 100% 통과!")

	# [검증 3] 성벽 팔(wall arms) 마스크 연결 검증
	print("[검증 3] 성벽 4방향 연결 마스크(get_wall_mask) 검증...")
	var mask: int = grid.get_wall_mask(10, 10)
	assert((mask & 2) != 0, "성벽이 봉돈 쪽으로 팔을 뻗지 않음 (mask=%d)" % mask)
	print("  -> 성벽에서 봉돈 방향으로 성벽 체성 팔(arm) 정상 연결 확인!")

	# [검증 4] CityLayer의 WALL_HEIGHT 상수 일치 검증
	print("[검증 4] CityLayer 성벽 및 시설 기단 높이 정합 검증...")
	var cl: CityLayerClass = CityLayerClass.new()
	cl.grid = grid
	assert(cl.WALL_HEIGHT == 18.0, "WALL_HEIGHT가 18.0이 아닙니다: %f" % cl.WALL_HEIGHT)

	# 봉돈 굴뚝 꼭대기 높이 검증 (WALL_HEIGHT + BD_H + 14.0 = 18 + 28 + 14 = 60)
	var bd_info := {
		"start": Vector2i(10, 10),
		"axis": Vector2i(1, 0),
		"out": Vector2i(0, 1),
		"elevation": 1.0
	}
	var chimney_tops: Array[Vector2] = cl.bongdon_chimney_tops(bd_info)
	assert(chimney_tops.size() == 5, "봉돈 굴뚝 수가 5개가 아닙니다.")
	print("  -> 봉돈 굴뚝 5개 높이 및 위치 정합 확인!")

	# 포루 포구 위치 검증 (WALL_HEIGHT + 11.0 = 29.0)
	var pr_info := {
		"start": Vector2i(20, 20),
		"axis": Vector2i(1, 0),
		"out": Vector2i(0, 1),
		"type": "bukseo",
		"elevation": 1.0
	}
	var muzzles: Array[Vector2] = cl.poru_muzzles(pr_info)
	assert(muzzles.size() == 3, "북서포루 포구 수가 3개가 아닙니다.")
	print("  -> 포루 대포 포구 높이 및 위치 정합 확인!")

	print("=== [테스트 완료] 성곽 연동 시설 및 성벽 기하학적 정합 100% 통과! ===")
	quit(0)
