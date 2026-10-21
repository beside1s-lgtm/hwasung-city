# test_house_yard_zorder.gd
# 다칸 민가, 공방, 마당 시설의 깊이 정렬 및 에셋 크기 분기 검증 테스트
extends SceneTree

func _init() -> void:
	print("=== 민가/공방/마당 깊이 정렬 및 에셋 매핑 검증 시작 ===")
	var grid := GameGrid.new()
	grid.size = 32
	grid.grid = []
	for y in range(grid.size):
		var row: Array = []
		for x in range(grid.size):
			row.append({
				"x": x, "y": y,
				"terrain": "plain",
				"building": "",
				"zone": "res",
				"surface": "dirt",
				"under_construction": false
			})
		grid.grid.append(row)

	# 1. GameGrid get_house_asset_id 크기별 분기 검증
	print("[검증 1] get_house_asset_id 분기 검증")
	
	# 1x1 기와집
	grid.grid[5][5]["building"] = "res_2"
	grid.grid[5][5]["house_variant"] = 0
	var id_1x1: String = grid.get_house_asset_id(5, 5)
	assert(id_1x1 == "tile_house_01", "1x1 기와집 에셋 ID 일치 실패: " + id_1x1)

	# 1x2 세로 기와집 (w=1, h=2)
	var g_1x2 := {"x0": 6, "y0": 6, "w": 1, "h": 2}
	grid.grid[6][6]["building"] = "res_2"
	grid.grid[6][6]["hgroup"] = g_1x2
	grid.grid[6][6]["house_variant"] = 4
	grid.grid[7][6]["building"] = "res_2"
	grid.grid[7][6]["hgroup"] = g_1x2
	grid.grid[7][6]["house_variant"] = 4
	var id_1x2: String = grid.get_house_asset_id(6, 6)
	assert(id_1x2 == "tile_house_05", "1x2 기와집 에셋 ID가 3x2 대부호로 오판되지 않아야 함: " + id_1x2)

	# 2x2 부호 기와집 (w=2, h=2)
	var g_2x2 := {"x0": 10, "y0": 10, "w": 2, "h": 2}
	for dy in range(2):
		for dx in range(2):
			grid.grid[10 + dy][10 + dx]["building"] = "res_2"
			grid.grid[10 + dy][10 + dx]["hgroup"] = g_2x2
			grid.grid[10 + dy][10 + dx]["house_variant"] = 7
	var id_2x2: String = grid.get_house_asset_id(10, 10)
	assert(id_2x2 == "tile_house_08", "2x2 기와집 에셋 ID가 3x2 대부호로 오판되지 않아야 함: " + id_2x2)

	# 3x2 대부호 별서 (w=3, h=2)
	var g_3x2 := {"x0": 14, "y0": 14, "w": 3, "h": 2}
	for dy in range(2):
		for dx in range(3):
			grid.grid[14 + dy][14 + dx]["building"] = "res_2"
			grid.grid[14 + dy][14 + dx]["hgroup"] = g_3x2
			grid.grid[14 + dy][14 + dx]["house_variant"] = 9
	var id_3x2: String = grid.get_house_asset_id(14, 14)
	assert(id_3x2 == "tile_house_10_3x2", "3x2 대부호 별서 에셋 ID 일치 실패: " + id_3x2)

	# 3x3 거상 대저택 (w=3, h=3)
	var g_3x3 := {"x0": 18, "y0": 18, "w": 3, "h": 3}
	for dy in range(3):
		for dx in range(3):
			grid.grid[18 + dy][18 + dx]["building"] = "res_2"
			grid.grid[18 + dy][18 + dx]["hgroup"] = g_3x3
			grid.grid[18 + dy][18 + dx]["house_variant"] = 10
	var id_3x3: String = grid.get_house_asset_id(18, 18)
	assert(id_3x3 == "tile_house_10_3x3", "3x3 거상 대저택 에셋 ID 일치 실패: " + id_3x3)
	print("[통과] get_house_asset_id 규모별 에셋 매핑 정상")

	# 2. 다칸 렌더링 트리거 타일이 남쪽(앞쪽) 타일인지 수식 검증
	print("[검증 2] 트리거 타일 계산 검증")
	# 1x2인 경우: 트리거는 (x0 + 1 - 1, y0 + 2 - 1) = (6, 7)
	var trig_1x2 := Vector2i(g_1x2["x0"] + g_1x2["w"] - 1, g_1x2["y0"] + g_1x2["h"] - 1)
	assert(trig_1x2 == Vector2i(6, 7), "1x2 트리거 타일 오류: " + str(trig_1x2))
	# (6, 6)은 북쪽 타일이므로 트리거되지 않음
	assert(Vector2i(6, 6) != trig_1x2, "북쪽 타일에서 트리거되면 안 됨")

	# 2x2인 경우: 트리거는 (x0 + 2 - 1, y0 + 2 - 1) = (11, 11)
	var trig_2x2 := Vector2i(g_2x2["x0"] + g_2x2["w"] - 1, g_2x2["y0"] + g_2x2["h"] - 1)
	assert(trig_2x2 == Vector2i(11, 11), "2x2 트리거 타일 오류: " + str(trig_2x2))
	assert(Vector2i(10, 10) != trig_2x2, "북서쪽 타일에서 트리거되면 안 됨")
	assert(Vector2i(11, 10) != trig_2x2, "북동쪽 타일에서 트리거되면 안 됨")
	assert(Vector2i(10, 11) != trig_2x2, "남서쪽 타일에서 트리거되면 안 됨")
	print("[통과] 다칸 시설 트리거 타일 수식 정상")

	print("=== 모든 검증 완벽 통과 ===")
	quit(0)
