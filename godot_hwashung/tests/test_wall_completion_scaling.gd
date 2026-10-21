extends SceneTree

const GameGridClass = preload("res://scripts/GameGrid.gd")
const WallLoopValidatorClass = preload("res://scripts/WallLoopValidator.gd")

func _init() -> void:
	print("=== [테스트 시작] 성곽 축성 % 사대문 구간별 25% 및 단절 칸당 0.25% 감점 검증 ===")
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
				"elevation": 0.0,
				"road_type": "dirt"
			})
		g.grid.append(row)
	return g

func _run_tests() -> void:
	_test_initial_state_zero_percent()
	_test_single_segment_connection_25_percent()
	_test_two_segments_connection_50_percent()
	_test_three_segments_connection_75_percent()
	_test_all_four_segments_100_percent()
	_test_missing_gap_penalty_scaling()
	_test_custom_non_national_project_path()

	print("=== [테스트 완료] 성곽 축성 % 사대문 구간별 25% 및 단절 칸당 0.25% 감점 100% 검증 통과! ===")
	quit(0)

## 1. 사대문 및 성벽이 없는 초기 상태에서 성곽 완공도 = 0%
func _test_initial_state_zero_percent() -> void:
	print("[검증 1] 초기 상태 (성문 없음, 성벽 없음) 완공도 0% 검증...")
	var grid: GameGridClass = _create_test_grid()
	var validator: WallLoopValidatorClass = WallLoopValidatorClass.new()

	var res: Dictionary = validator.validate_loop(grid, true)
	assert(int(res.get("validated_progress", -1)) == 0, "초기 상태에서는 완공도가 0이어야 함")
	assert(not bool(res.get("is_closed_loop", true)), "초기 상태는 폐곡선이 아니어야 함")
	print("  -> 초기 상태 0% 검증 통과!")

## 2. 1개 구간 (장안문 <-> 화서문) 완전 연결 시 정확히 25% 달성
func _test_single_segment_connection_25_percent() -> void:
	print("[검증 2] 1개 구간 (장안문 <-> 화서문) 완전 연결 시 25% 검증...")
	var grid: GameGridClass = _create_test_grid()
	var validator: WallLoopValidatorClass = WallLoopValidatorClass.new()

	# 장안문(30, 20), 화서문(20, 30)
	grid.grid[20][30]["building"] = "gate"
	grid.grid[20][30]["gate_name"] = "장안문"

	grid.grid[30][20]["building"] = "gate"
	grid.grid[30][20]["gate_name"] = "화서문"

	# 장안문(30, 20)에서 코너(20, 20)를 거쳐 화서문(20, 30)까지 성벽 연결
	for x in range(20, 31):
		if x != 30:
			grid.grid[20][x]["building"] = "wall"
	for y in range(20, 31):
		if y != 30:
			grid.grid[y][20]["building"] = "wall"

	var res: Dictionary = validator.validate_loop(grid, true)
	var prog: int = int(res.get("validated_progress", 0))
	var seg_scores: Dictionary = res.get("segment_scores", {})
	print("  -> nw 구간 점수: ", seg_scores.get("nw", 0.0), "%, 총 완공도: ", prog, "%")

	assert(int(round(float(seg_scores.get("nw", 0.0)))) == 25, "서북 구간 점수가 25%여야 함")
	assert(prog == 25, "1개 구간 완공 시 총 완공도는 정확히 25%여야 함")
	assert(not bool(res.get("is_closed_loop", false)), "4개 문 미연결이므로 폐곡선은 미완성이어야 함")
	print("  -> 1개 구간 연결 시 정확히 25% 달성 검증 통과!")

## 3. 2개 구간 (장안-화서, 화서-팔달) 연결 시 50% 달성
func _test_two_segments_connection_50_percent() -> void:
	print("[검증 3] 2개 구간 (서북, 서남) 연결 시 50% 검증...")
	var grid: GameGridClass = _create_test_grid()
	var validator: WallLoopValidatorClass = WallLoopValidatorClass.new()

	grid.grid[20][30]["building"] = "gate"
	grid.grid[20][30]["gate_name"] = "장안문"
	grid.grid[30][20]["building"] = "gate"
	grid.grid[30][20]["gate_name"] = "화서문"
	grid.grid[40][30]["building"] = "gate"
	grid.grid[40][30]["gate_name"] = "팔달문"

	# 1) 장안 - 화서 (20,20 경유)
	for x in range(20, 31):
		if x != 30: grid.grid[20][x]["building"] = "wall"
	for y in range(20, 31):
		if y != 30: grid.grid[y][20]["building"] = "wall"

	# 2) 화서 - 팔달 (20,40 경유)
	for y in range(30, 41):
		if y != 30: grid.grid[y][20]["building"] = "wall"
	for x in range(20, 31):
		if x != 30: grid.grid[40][x]["building"] = "wall"

	var res: Dictionary = validator.validate_loop(grid, true)
	var prog: int = int(res.get("validated_progress", 0))
	assert(prog == 50, "2개 구간 연결 시 완공도는 50이어야 함, 현재: " + str(prog))
	print("  -> 2개 구간 연결 시 50% 달성 검증 통과!")

## 4. 3개 구간 연결 시 75% 달성
func _test_three_segments_connection_75_percent() -> void:
	print("[검증 4] 3개 구간 연결 시 75% 검증...")
	var grid: GameGridClass = _create_test_grid()
	var validator: WallLoopValidatorClass = WallLoopValidatorClass.new()

	grid.grid[20][30]["building"] = "gate"
	grid.grid[20][30]["gate_name"] = "장안문"
	grid.grid[30][20]["building"] = "gate"
	grid.grid[30][20]["gate_name"] = "화서문"
	grid.grid[40][30]["building"] = "gate"
	grid.grid[40][30]["gate_name"] = "팔달문"
	grid.grid[30][40]["building"] = "gate"
	grid.grid[30][40]["gate_name"] = "창룡문"

	# 1) 서북 (20,20 경유)
	for x in range(20, 31):
		if x != 30: grid.grid[20][x]["building"] = "wall"
	for y in range(20, 31):
		if y != 30: grid.grid[y][20]["building"] = "wall"

	# 2) 서남 (20,40 경유)
	for y in range(30, 41):
		if y != 30: grid.grid[y][20]["building"] = "wall"
	for x in range(20, 31):
		if x != 30: grid.grid[40][x]["building"] = "wall"

	# 3) 동남 (40,40 경유)
	for x in range(30, 41):
		if x != 30: grid.grid[40][x]["building"] = "wall"
	for y in range(30, 41):
		if y != 30: grid.grid[y][40]["building"] = "wall"

	var res: Dictionary = validator.validate_loop(grid, true)
	var prog: int = int(res.get("validated_progress", 0))
	print("  -> 3개 구간 연결 디버그: seg_scores=", res.get("segment_scores", {}), " prog=", prog)
	assert(prog == 75, "3개 구간 연결 시 완공도는 75여야 함, 현재: " + str(prog))
	print("  -> 3개 구간 연결 시 75% 달성 검증 통과!")

## 5. 4개 문 모두 연결 시 정확히 100%
func _test_all_four_segments_100_percent() -> void:
	print("[검증 5] 4개 문 모두 연결 시 100% 검증...")
	var grid: GameGridClass = _create_test_grid()
	var validator: WallLoopValidatorClass = WallLoopValidatorClass.new()

	grid.grid[20][30]["building"] = "gate"
	grid.grid[20][30]["gate_name"] = "장안문"
	grid.grid[30][20]["building"] = "gate"
	grid.grid[30][20]["gate_name"] = "화서문"
	grid.grid[40][30]["building"] = "gate"
	grid.grid[40][30]["gate_name"] = "팔달문"
	grid.grid[30][40]["building"] = "gate"
	grid.grid[30][40]["gate_name"] = "창룡문"

	for x in range(20, 41):
		if x != 30:
			grid.grid[20][x]["building"] = "wall"
			grid.grid[40][x]["building"] = "wall"
	for y in range(20, 41):
		if y != 30:
			grid.grid[y][20]["building"] = "wall"
			grid.grid[y][40]["building"] = "wall"

	var res: Dictionary = validator.validate_loop(grid, true)
	var prog: int = int(res.get("validated_progress", 0))
	assert(bool(res.get("is_closed_loop", false)), "4개 문이 모두 연결되었으므로 폐곡선이어야 함")
	assert(prog == 100, "4개 문 모두 연결 시 완공도는 100이어야 함, 현재: " + str(prog))
	print("  -> 4개 문 모두 연결 시 정확히 100% 검증 통과!")

## 6. 중간에 끊긴 곳이 있을 때 한 칸당 0.25%씩 부족하게 산출되는지 검증
func _test_missing_gap_penalty_scaling() -> void:
	print("[검증 6] 단절된 빈 칸당 0.25%씩 부족 산출 검증...")
	var grid: GameGridClass = _create_test_grid()
	var validator: WallLoopValidatorClass = WallLoopValidatorClass.new()

	# 더 넓은 그리드(y: 10..50, x: 10..50)로 지름길 간섭 원천 배제
	# 장안문(30, 10), 팔달문(30, 50), 화서문(10, 30), 창룡문(50, 30)
	grid.grid[10][30]["building"] = "gate"
	grid.grid[10][30]["gate_name"] = "장안문"
	grid.grid[50][30]["building"] = "gate"
	grid.grid[50][30]["gate_name"] = "팔달문"
	grid.grid[30][10]["building"] = "gate"
	grid.grid[30][10]["gate_name"] = "화서문"
	grid.grid[30][50]["building"] = "gate"
	grid.grid[30][50]["gate_name"] = "창룡문"

	# 서북: (10,10) 경유
	for x in range(10, 31):
		if x != 30: grid.grid[10][x]["building"] = "wall"
	for y in range(10, 31):
		if y != 30: grid.grid[y][10]["building"] = "wall"

	# 서남: (10,50) 경유
	for y in range(30, 51):
		if y != 30: grid.grid[y][10]["building"] = "wall"
	for x in range(10, 31):
		if x != 30: grid.grid[50][x]["building"] = "wall"

	# 동남: (50,50) 경유
	for x in range(30, 51):
		if x != 30: grid.grid[50][x]["building"] = "wall"
	for y in range(30, 51):
		if y != 30: grid.grid[y][50]["building"] = "wall"

	# 동북: (50,10) 경유
	for y in range(10, 30):
		grid.grid[y][50]["building"] = "wall"
	for x in range(30, 51):
		if x != 30: grid.grid[10][x]["building"] = "wall"

	# 6-A. 1칸 구멍: (10, 40) 비움 (gap = 1)
	grid.grid[10][40]["building"] = ""
	var res1: Dictionary = validator.validate_loop(grid, true)
	var float_prog1: float = float(res1.get("float_progress", 0.0))
	var prog1: int = int(res1.get("validated_progress", 0))
	var seg_ne1: float = float((res1.get("segment_scores", {}) as Dictionary).get("ne", 0.0))
	print("  -> 1칸 결손: 동북 점수=", seg_ne1, "%, 총 float=", float_prog1, "%, 표기 prog=", prog1, "%")
	assert(is_equal_approx(seg_ne1, 24.75), "1칸 단절 시 동북 구간은 24.75여야 함")
	assert(is_equal_approx(float_prog1, 99.75), "1칸 단절 시 총합은 99.75여야 함")
	assert(prog1 == 99, "1칸 단절 시 표기 완공도는 99여야 함")
	assert(not bool(res1.get("is_closed_loop", false)), "1칸 끊겼으므로 폐곡선 미완성")

	# 6-B. 4칸 구멍: (10, 39..42) 비움 (gap = 4)
	grid.grid[10][39]["building"] = ""
	grid.grid[10][40]["building"] = ""
	grid.grid[10][41]["building"] = ""
	grid.grid[10][42]["building"] = ""
	var res4: Dictionary = validator.validate_loop(grid, true)
	var float_prog4: float = float(res4.get("float_progress", 0.0))
	var prog4: int = int(res4.get("validated_progress", 0))
	var seg_ne4: float = float((res4.get("segment_scores", {}) as Dictionary).get("ne", 0.0))
	print("  -> 4칸 결손: 동북 점수=", seg_ne4, "%, 총 float=", float_prog4, "%, 표기 prog=", prog4, "%")
	assert(is_equal_approx(seg_ne4, 24.0), "4칸 단절 시 동북 구간은 24.0여야 함")
	assert(is_equal_approx(float_prog4, 99.0), "4칸 단절 시 총합은 99.0여야 함")
	assert(prog4 == 99, "4칸 단절 시 표기 완공도는 99여야 함")

	# 6-C. 8칸 구멍: (10, 37..44) 비움 (gap = 8)
	for x in range(37, 45):
		grid.grid[10][x]["building"] = ""
	var res8: Dictionary = validator.validate_loop(grid, true)
	var float_prog8: float = float(res8.get("float_progress", 0.0))
	var prog8: int = int(res8.get("validated_progress", 0))
	var seg_ne8: float = float((res8.get("segment_scores", {}) as Dictionary).get("ne", 0.0))
	print("  -> 8칸 결손: 동북 점수=", seg_ne8, "%, 총 float=", float_prog8, "%, 표기 prog=", prog8, "%")
	assert(is_equal_approx(seg_ne8, 23.0), "8칸 단절 시 동북 구간은 23.0여야 함")
	assert(is_equal_approx(float_prog8, 98.0), "8칸 단절 시 총합은 98.0여야 함")
	assert(prog8 == 98, "8칸 단절 시 표기 완공도는 98여야 함")

	print("  -> 단절 칸당 0.25% 감점 스케일링 검증 통과!")

## 7. 국책대역사 좌표와 일치하지 않는 사용자 임의 경로라도 정상 판정 검증
func _test_custom_non_national_project_path() -> void:
	print("[검증 7] 국책대역사 고정 좌표 탈피 & 임의 경로 축성 검증...")
	var grid: GameGridClass = _create_test_grid()
	var validator: WallLoopValidatorClass = WallLoopValidatorClass.new()

	# 마름모 형태의 임의 경로 사대문 배치
	# 북: (30, 10), 남: (30, 50), 서: (10, 30), 동: (50, 30)
	grid.grid[10][30]["building"] = "gate"
	grid.grid[10][30]["gate_name"] = "장안문"
	grid.grid[50][30]["building"] = "gate"
	grid.grid[50][30]["gate_name"] = "팔달문"
	grid.grid[30][10]["building"] = "gate"
	grid.grid[30][10]["gate_name"] = "화서문"
	grid.grid[30][50]["building"] = "gate"
	grid.grid[30][50]["gate_name"] = "창룡문"

	# 서북 대각선 연결 (10,30) ~ (30,10)
	for i in range(1, 20):
		grid.grid[10 + i][30 - i]["building"] = "wall"

	# 서남 대각선 연결 (30,10) ~ (50,30)
	for i in range(1, 20):
		grid.grid[30 + i][10 + i]["building"] = "wall"

	# 동남 대각선 연결 (50,30) ~ (30,50)
	for i in range(1, 20):
		grid.grid[50 - i][30 + i]["building"] = "wall"

	# 동북 대각선 연결 (30,50) ~ (10,30)
	for i in range(1, 20):
		grid.grid[30 - i][50 - i]["building"] = "wall"

	var res: Dictionary = validator.validate_loop(grid, true)
	var prog: int = int(res.get("validated_progress", 0))
	assert(bool(res.get("is_closed_loop", false)), "임의 마름모 경로도 4개 문이 연결되었으므로 폐곡선이어야 함")
	assert(prog == 100, "임의 경로 완공도 100이어야 함, 현재: " + str(prog))
	print("  -> 국책대역사 좌표 무관 임의 경로 축성 100% 완공 검증 통과!")
