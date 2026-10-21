extends SceneTree

## [수리 농업 인프라 엔진 및 만석거 특화 버프 테스트]
## 1. 저수지 부재 시 1년 후 -10% 페널티 및 초기 유예 검증
## 2. 일반 저수지 1개소당 100개소 대유둔전 관개(100% 정상) 검증
## 3. 만석거 반경 15타일 이내 대유둔전 +10% 특화 버프(110%) 검증
## 4. 저수지 용량 초과 시 거리 기반 우선순위 및 초과 둔전 -10% 페널티 검증
## 5. 실시간 완공/철거 시 재정산 및 살피기/HUD 텍스트 검증

func _init() -> void:
	print("=== [TEST START] 수리 농업 인프라 엔진 및 만석거 버프 테스트 ===")
	run_tests()
	quit(0)

func assert_true(condition: bool, msg: String) -> void:
	if not condition:
		printerr("[FAIL] %s" % msg)
		quit(1)
	else:
		print("[PASS] %s" % msg)

func assert_almost_equal(a: float, b: float, epsilon: float, msg: String) -> void:
	if absf(a - b) > epsilon:
		printerr("[FAIL] %s (Expected %f, got %f)" % [msg, b, a])
		quit(1)
	else:
		print("[PASS] %s" % msg)

func run_tests() -> void:
	var grid: GameGrid = GameGrid.new()
	grid.size = 40
	grid.grid = []
	for y in range(grid.size):
		var row: Array = []
		for x in range(grid.size):
			row.append({
				"x": x, "y": y,
				"terrain": "outside",
				"building": "",
				"zone": "",
				"surface": "normal",
				"under_construction": false
			})
		grid.grid.append(row)

	var sim: SimulationCore = SimulationCore.new()
	sim.turn = 1 # 1년차(유예 기간)

	# -------------------------------------------------------------------------
	# [테스트 1]: 저수지 부재 상태에서 초기 1년 유예 및 1년 후 가뭄 페널티(-10%) 검증
	# -------------------------------------------------------------------------
	print("\n--- Test 1: 저수지 부재 상태와 초기 1년 유예 기간 검증 ---")
	# 성 밖 평지에 둔전 5개 배치
	for i in range(5):
		var fx: int = 5 + i
		var fy: int = 5
		grid.grid[fy][fx]["terrain"] = "outside"
		grid.grid[fy][fx]["building"] = "agr_1"

	var stat1: Dictionary = IrrigationManager.recalculate_irrigation(grid, sim)
	assert_true(stat1["total_capacity"] == 0, "저수지 없을 때 총 용량은 0이어야 함")
	assert_true(stat1["total_farms"] == 5, "전체 둔전 수는 5개이어야 함")
	assert_true(stat1["drought_farms"] == 5, "저수지가 없으므로 모든 둔전은 가뭄(DROUGHT) 상태여야 함")

	var test_cell: Dictionary = grid.grid[5][5]
	assert_true(int(test_cell.get("irrigation_state", -1)) == IrrigationManager.IrrigationState.DROUGHT, "타일 상태가 DROUGHT여야 함")
	
	# 초기 1년차(turn <= 4): 유예 기간 적용으로 배율 1.0 (정상 소출)
	var mult_grace: float = FarmManager.get_irrigation_multiplier(test_cell, FarmManager.is_grace_period(sim))
	assert_almost_equal(mult_grace, 1.00, 0.001, "초기 1년(유예)에는 저수지 없어도 정상 1.00 배율 유지")

	# 1년 경과 후(turn = 5): 유예 기간 종료로 -10% 페널티(0.90 배율) 적용
	sim.turn = 5
	var mult_penalty: float = FarmManager.get_irrigation_multiplier(test_cell, FarmManager.is_grace_period(sim))
	assert_almost_equal(mult_penalty, 0.90, 0.001, "1년 경과 후 저수지 부재 시 정확히 0.90 (-10%) 페널티 적용")

	# 살피기 및 툴팁 텍스트 검증
	var tip_text: String = IrrigationManager.get_status_text(test_cell, false)
	assert_true(tip_text.contains("가뭄/용수 부족: 식량 생산 -10%"), "툴팁에 가뭄/용수 부족 -10% 명시")
	var narr_add: String = IrrigationManager.get_inspect_narrative_addition(test_cell, false)
	assert_true(narr_add.contains("⚠️ 경고: 수리 시설 부족으로 생산량이 10% 감소 중입니다"), "살피기 경고 문구 확인")

	# -------------------------------------------------------------------------
	# [테스트 2]: 일반 저수지 1개 축조 시 최대 100개소 대유둔전 정상 관개(100%) 검증
	# -------------------------------------------------------------------------
	print("\n--- Test 2: 일반 저수지 1개당 100개소 관개 용량 검증 ---")
	# 맵을 깨끗이 비운 후 (20, 20)에 일반 저수지 1개 설치
	for y in range(40):
		for x in range(40):
			grid.grid[y][x]["building"] = ""
			grid.grid[y][x]["zone"] = ""
			grid.grid[y][x].erase("irrigation_state")
			grid.grid[y][x].erase("facility_id")

	grid.grid[20][20]["building"] = "reservoir"
	grid.grid[20][20]["facility_id"] = "reservoir"

	# 저수지 (20, 20) 주변부터 나선형/거리순으로 120개 둔전 배치
	var farm_points: Array[Vector2i] = []
	for r in range(1, 30):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var px: int = 20 + dx
				var py: int = 20 + dy
				if px >= 0 and px < 40 and py >= 0 and py < 40:
					var pt := Vector2i(px, py)
					if not (pt in farm_points) and pt != Vector2i(20, 20):
						farm_points.append(pt)
						if farm_points.size() >= 120:
							break
			if farm_points.size() >= 120:
				break
		if farm_points.size() >= 120:
			break

	for pt in farm_points:
		grid.grid[pt.y][pt.x]["terrain"] = "outside"
		grid.grid[pt.y][pt.x]["building"] = "agr_1"

	var stat2: Dictionary = IrrigationManager.recalculate_irrigation(grid, sim)
	assert_true(stat2["total_capacity"] == 100, "일반 저수지 1개 용량은 정확히 100이어야 함 (실제: %d)" % stat2["total_capacity"])
	assert_true(stat2["total_farms"] == 120, "전체 둔전 수는 120개여야 함 (실제: %d)" % stat2["total_farms"])
	assert_true(stat2["normal_farms"] == 100, "관개 혜택을 받는 둔전은 정확히 100개여야 함 (실제: %d)" % stat2["normal_farms"])
	assert_true(stat2["drought_farms"] == 20, "용량 초과로 가뭄 페널티를 받는 둔전은 정확히 20개여야 함 (실제: %d)" % stat2["drought_farms"])

	# 거리 기반 우선 배정 검증: 저수지 바로 옆 (20, 21)은 NORMAL, 100개 초과 외곽 둔전은 DROUGHT
	var near_cell: Dictionary = grid.grid[20][21]
	assert_true(int(near_cell.get("irrigation_state", -1)) == IrrigationManager.IrrigationState.NORMAL, "저수지 인근 둔전은 NORMAL이어야 함")
	assert_almost_equal(FarmManager.get_irrigation_multiplier(near_cell, false), 1.00, 0.001, "정상 관개 둔전은 1.00 배율")

	var far_pt: Vector2i = farm_points[119] # 가장 먼 120번째 둔전
	var far_cell_2: Dictionary = grid.grid[far_pt.y][far_pt.x]
	assert_true(int(far_cell_2.get("irrigation_state", -1)) == IrrigationManager.IrrigationState.DROUGHT, "용량 초과 원거리 둔전은 DROUGHT여야 함")
	assert_almost_equal(FarmManager.get_irrigation_multiplier(far_cell_2, false), 0.90, 0.001, "용량 초과 둔전은 0.90 (-10%) 페널티 적용")

	# -------------------------------------------------------------------------
	# [테스트 3]: 만석거(萬石渠) 축조 시 반경 15타일 이내 +10% 특화 버프 검증
	# -------------------------------------------------------------------------
	print("\n--- Test 3: 만석거 반경 15타일 이내 +10% 특화 버프 검증 ---")
	# (20, 20)의 일반 저수지를 지우고, (20, 20) 자리에 만석거 설치
	grid.grid[20][20]["building"] = "manseokgeo"
	grid.grid[20][20]["facility_id"] = "manseokgeo"
	grid.grid[20][20]["site_anchor"] = Vector2i(20, 20)

	var stat3: Dictionary = IrrigationManager.recalculate_irrigation(grid, sim)
	assert_true(stat3["total_capacity"] == 100, "만석거 1개 용량은 100이어야 함")
	assert_true(stat3["buff_farms"] > 0, "만석거 반경 15타일 내 특화 버프 농지가 존재해야 함")

	# 만석거 바로 옆 둔전 (20, 21) -> 거리 1.0 -> MANSEOKGEO_BUFF 확인
	var buffed_cell: Dictionary = grid.grid[20][21]
	assert_true(int(buffed_cell.get("irrigation_state", -1)) == IrrigationManager.IrrigationState.MANSEOKGEO_BUFF, "만석거 인접 둔전은 MANSEOKGEO_BUFF여야 함")
	var buff_mult: float = FarmManager.get_irrigation_multiplier(buffed_cell, false)
	assert_almost_equal(buff_mult, 1.10, 0.001, "만석거 인접 둔전은 정확히 1.10 (+10%) 풍작 버프")

	# 만석거 버프 텍스트 검증
	var buff_tip: String = IrrigationManager.get_status_text(buffed_cell, false)
	assert_true(buff_tip.contains("만석거 황금들녘: 풍작 버프 +10%"), "툴팁에 만석거 풍작 버프 +10% 확인")
	var buff_narr: String = IrrigationManager.get_inspect_narrative_addition(buffed_cell, false)
	assert_true(buff_narr.contains("정조 대왕의 만석거 관개수로 덕분에 벼가 누렇게 익어갑니다! (+10%)"), "살피기 만석거 찬사 문구 확인")

	# -------------------------------------------------------------------------
	# [테스트 4]: 저수지 철거 및 실시간 재정산 검증
	# -------------------------------------------------------------------------
	print("\n--- Test 4: 저수지 철거 및 실시간 재정산 검증 ---")
	grid.apply_tool("demolish", 20, 20)
	var stat4: Dictionary = IrrigationManager.recalculate_irrigation(grid, sim)
	assert_true(stat4["total_capacity"] == 0, "만석거 철거 후 저수지 용량은 0이어야 함")
	assert_true(stat4["buff_farms"] == 0, "철거 후 만석거 버프 농지는 0개여야 함")
	assert_true(stat4["drought_farms"] == 120, "철거 후 모든 둔전(120개)이 가뭄 상태로 전이되어야 함")

	# -------------------------------------------------------------------------
	# [테스트 5]: HUD 수용량 문자열 검증
	# -------------------------------------------------------------------------
	print("\n--- Test 5: HUD 수용량 문자열 검증 ---")
	# 저수지 2개 설치 (용량 200, 둔전이 없는 (0, 0)과 (39, 39)에 설치)
	grid.grid[0][0]["building"] = "reservoir"
	grid.grid[0][0]["facility_id"] = "reservoir"
	grid.grid[39][39]["building"] = "reservoir"
	grid.grid[39][39]["facility_id"] = "reservoir"
	IrrigationManager.recalculate_irrigation(grid, sim)

	var hud_str: String = IrrigationManager.get_hud_capacity_string()
	print("HUD 문자열: %s" % hud_str)
	assert_true(hud_str.contains("최대 200 개소 둔전 공급 중"), "HUD에 최대 200 개소 공급 표기 확인")
	assert_true(hud_str.contains("현재 120 / 최대 200"), "HUD에 현재 120개 둔전 전체 관개 표기 확인")

	# -------------------------------------------------------------------------
	# [테스트 6]: FarmManager 식량 수확 정산 위임 무결성 검증
	# -------------------------------------------------------------------------
	print("\n--- Test 6: FarmManager.calculate_harvest 무결성 검증 ---")
	# 도로 연결성을 위해 둔전 주변에 도로 1칸 설치
	grid.grid[19][21]["building"] = "road"
	var harvest_res: Dictionary = FarmManager.calculate_harvest(grid, sim, 2) # 가을(대풍)
	assert_true(harvest_res.has("gross_yield"), "gross_yield 키가 존재해야 함")
	assert_true(harvest_res.has("net_income"), "net_income 키가 존재해야 함")
	assert_true(int(harvest_res["gross_yield"]) > 0, "가을 수확기 소출이 0보다 커야 함")
	print("가을 총 수확량: %d석, 세입 환수: %d석" % [harvest_res["gross_yield"], harvest_res["net_income"]])

	print("\n=== [ALL TESTS PASSED] 모든 수리 농업 인프라 엔진 테스트 통과! ===")
