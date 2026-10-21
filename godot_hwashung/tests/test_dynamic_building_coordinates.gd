extends SceneTree

const GameGridClass = preload("res://scripts/GameGrid.gd")
const SimulationCoreClass = preload("res://scripts/SimulationCore.gd")
const BuildingManagerClass = preload("res://scripts/BuildingManager.gd")
const SaveSystemClass = preload("res://scripts/SaveSystem.gd")

func _init() -> void:
	print("=== [테스트 시작] 건축물 동적 좌표 갱신 및 사용자 임의 위치 건축 연동 검증 ===")
	call_deferred("_run_tests")

func _create_test_grid() -> GameGridClass:
	var g := GameGridClass.new()
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
				"road_type": "dirt",
				"under_construction": false
			})
		g.grid.append(row)
	return g

func _find_project(sim: SimulationCoreClass, pid: String) -> Dictionary:
	for p in sim.mega_projects:
		if str(p.get("id", "")) == pid:
			return p
	return {}

func _run_tests() -> void:
	_test_custom_location_buildings_detected()
	_test_custom_location_gates_detected()
	_test_mega_projects_auto_complete_with_custom_locations()
	_test_save_load_custom_locations()

	print("=== [테스트 완료] 건축물 동적 좌표 갱신 및 임의 위치 건축 연동 전 항목 100% 통과! ===")
	quit(0)

## 1. 사용자가 기본 고증 좌표가 아닌 임의의 위치에 건축물을 직접 지었을 때, 시스템이 해당 위치로 동적 갱신하는지 검증
func _test_custom_location_buildings_detected() -> void:
	print("[검증 1] 임의의 위치에 주요 건물 직접 축조 시 동적 좌표 갱신 검증...")
	var grid := _create_test_grid()

	# 1) 화성행궁을 (35, 35)에 직접 건설
	grid.grid[35][35]["building"] = "haenggung"
	grid.grid[35][35]["under_construction"] = false
	var h_pos: Vector2i = grid.get_facility_pos("haenggung")
	assert(h_pos == Vector2i(35, 35), "사용자가 지은 행궁 좌표 (35, 35)가 정확히 동적 반영되어야 함")
	assert(BuildingManagerClass.get_building_center_pos("haenggung_yard", grid) == Vector2i(35, 35), "행궁 마당 중심점도 (35, 35)여야 함")
	assert(BuildingManagerClass.get_building_center_pos("haenggung_sinpungru", grid) == Vector2i(38, 35), "신풍루 위치도 동적 오프셋 적용되어야 함")

	# 2) 화성유수부 동헌(관아)을 (35, 30)에 직접 건설
	grid.grid[30][35]["building"] = "gwana"
	grid.grid[30][35]["under_construction"] = false
	var gw_pos: Vector2i = grid.get_facility_pos("gwana")
	assert(gw_pos == Vector2i(35, 30), "사용자가 지은 관아 좌표 (35, 30)가 동적 반영되어야 함")

	# 3) 만석거를 (15, 10)에 직접 건설
	grid.grid[10][15]["building"] = "manseokgeo"
	grid.grid[10][15]["under_construction"] = false
	var ms_pos: Vector2i = grid.get_facility_pos("manseokgeo")
	assert(ms_pos == Vector2i(15, 10), "사용자가 지은 만석거 좌표 (15, 10)가 동적 반영되어야 함")

	# 4) 서장대를 (40, 15)에 직접 건설
	grid.grid[15][40]["building"] = "seojangdae"
	grid.grid[15][40]["under_construction"] = false
	var sj_pos: Vector2i = grid.get_facility_pos("seojangdae")
	assert(sj_pos == Vector2i(40, 15), "사용자가 지은 서장대 좌표 (40, 15)가 동적 반영되어야 함")
	assert(BuildingManagerClass.get_building_center_pos("seojangdae", grid) == Vector2i(40, 15), "서장대 중심점도 (40, 15)여야 함")

	# 5) 연무대를 (45, 25)에 직접 건설
	grid.grid[25][45]["building"] = "yeonmudae"
	grid.grid[25][45]["under_construction"] = false
	var ym_pos: Vector2i = grid.get_facility_pos("yeonmudae")
	assert(ym_pos == Vector2i(45, 25), "사용자가 지은 연무대 좌표 (45, 25)가 동적 반영되어야 함")

	print("[검증 1 통과] 사용자가 지은 임의 위치의 행궁·관아·만석거·서장대·연무대 좌표가 동적으로 완벽 인식됨.")

## 2. 사용자가 임의의 위치에 사대문과 수문을 직접 짓고 명명했을 때, 해당 문의 좌표가 동적으로 변경되는지 검증
func _test_custom_location_gates_detected() -> void:
	print("[검증 2] 임의의 위치에 사대문 및 수문 축조 시 동적 좌표 갱신 검증...")
	var grid := _create_test_grid()

	# 1) 장안문을 (30, 8)에 설치하고 명명
	grid.grid[8][30]["building"] = "gate"
	grid.grid[8][30]["gate_name"] = "장안문 (長安門)"
	grid.grid[8][30]["under_construction"] = false

	# 2) 팔달문을 (25, 58)에 설치하고 명명
	grid.grid[58][25]["building"] = "gate"
	grid.grid[58][25]["gate_name"] = "팔달문 (八達門)"
	grid.grid[58][25]["under_construction"] = false

	# 3) 화서문을 (10, 20)에 설치하고 명명
	grid.grid[20][10]["building"] = "gate"
	grid.grid[20][10]["gate_name"] = "화서문 (華西門)"
	grid.grid[20][10]["under_construction"] = false

	# 4) 창룡문을 (55, 35)에 설치하고 명명
	grid.grid[35][55]["building"] = "gate"
	grid.grid[35][55]["gate_name"] = "창룡문 (蒼龍門)"
	grid.grid[35][55]["under_construction"] = false

	# 5) 화홍문(북수문)을 (40, 10)에 설치
	grid.grid[10][40]["building"] = "hwahong"
	grid.grid[10][40]["under_construction"] = false

	# 6) 남수문을 (35, 50)에 설치
	grid.grid[50][35]["building"] = "namsu"
	grid.grid[50][35]["under_construction"] = false

	# 동적 사대문 맵 조회
	var g_map: Dictionary = grid.get_four_gates_positions()
	assert(g_map["jangan"] == Vector2i(30, 8), "장안문 좌표가 (30, 8)로 동적 갱신되어야 함")
	assert(g_map["paldal"] == Vector2i(25, 58), "팔달문 좌표가 (25, 58)로 동적 갱신되어야 함")
	assert(g_map["hwaseo"] == Vector2i(10, 20), "화서문 좌표가 (10, 20)로 동적 갱신되어야 함")
	assert(g_map["changryong"] == Vector2i(55, 35), "창룡문 좌표가 (55, 35)로 동적 갱신되어야 함")

	# get_gate_pos 검증
	assert(grid.get_gate_pos("jangan") == Vector2i(30, 8), "get_gate_pos(jangan)이 (30, 8) 반환해야 함")
	assert(grid.get_gate_pos("paldal") == Vector2i(25, 58), "get_gate_pos(paldal)이 (25, 58) 반환해야 함")
	assert(grid.get_gate_pos("hwaseo") == Vector2i(10, 20), "get_gate_pos(hwaseo)이 (10, 20) 반환해야 함")
	assert(grid.get_gate_pos("changryong") == Vector2i(55, 35), "get_gate_pos(changryong)이 (55, 35) 반환해야 함")
	assert(grid.get_gate_pos("hwahong") == Vector2i(40, 10), "get_gate_pos(hwahong)이 (40, 10) 반환해야 함")
	assert(grid.get_gate_pos("namsu") == Vector2i(35, 50), "get_gate_pos(namsu)이 (35, 50) 반환해야 함")

	print("[검증 2 통과] 사용자가 지은 사대문 및 수문의 위치가 gates 딕셔너리와 시스템 전반에 완벽히 동적 반영됨.")

## 3. 사용자가 임의의 위치에 건축했을 때 국책 대역사가 해당 건물을 정상 인식하여 자동 완공으로 전환되는지 검증
func _test_mega_projects_auto_complete_with_custom_locations() -> void:
	print("[검증 3] 임의 위치 건축 시 국책 대역사 자동 완료 및 2중 건축 방지 검증...")
	var sim := SimulationCoreClass.new()
	var grid := _create_test_grid()

	# 기본 역사적 좌표가 아닌 다른 위치들에 각각 시설 구축
	grid.grid[35][35]["building"] = "haenggung"
	grid.grid[30][35]["building"] = "gwana"
	grid.grid[10][15]["building"] = "manseokgeo"
	grid.grid[15][40]["building"] = "seojangdae"
	grid.grid[8][30]["building"] = "gate"
	grid.grid[8][30]["gate_name"] = "장안문"
	grid.grid[35][55]["building"] = "gate"
	grid.grid[35][55]["gate_name"] = "창룡문"
	grid.grid[58][25]["building"] = "gate"
	grid.grid[58][25]["gate_name"] = "팔달문"

	for y in range(grid.size):
		for x in range(grid.size):
			grid.grid[y][x]["under_construction"] = false

	# 동기화 실행
	sim.sync_mega_projects_with_grid(grid)

	# 1) 대역사들이 고정 좌표가 아님에도 모두 완료 처리되었는지 검증
	var p_haeng := _find_project(sim, "haenggung_palace")
	assert(bool(p_haeng.get("is_completed", false)), "임의 위치 행궁(35, 35)으로도 대역사 완공되어야 함")

	var p_gwana := _find_project(sim, "gwana_office")
	assert(bool(p_gwana.get("is_completed", false)), "임의 위치 관아(35, 30)로도 대역사 완공되어야 함")

	var p_manseok := _find_project(sim, "manseok_reservoir")
	assert(bool(p_manseok.get("is_completed", false)), "임의 위치 만석거(15, 10)로도 대역사 완공되어야 함")

	var p_paldal_fort := _find_project(sim, "paldal_fortress")
	assert(bool(p_paldal_fort.get("is_completed", false)), "임의 위치 서장대(40, 15)로도 대역사 완공되어야 함")

	var p_hwahong_north := _find_project(sim, "hwahong_north")
	assert(bool(p_hwahong_north.get("is_completed", false)), "임의 위치 장안문(30, 8)으로도 대역사 완공되어야 함")

	var p_changryong := _find_project(sim, "changryong_east")
	assert(bool(p_changryong.get("is_completed", false)), "임의 위치 창룡문(55, 35)으로도 대역사 완공되어야 함")

	var p_namsu_south := _find_project(sim, "namsu_south")
	assert(bool(p_namsu_south.get("is_completed", false)), "임의 위치 팔달문(25, 58)으로도 대역사 완공되어야 함")

	# 2) 원래 고정 좌표(예: 22, 32)에 엉뚱하게 건물이 중복 생성되지 않았는지 확인
	assert(str(grid.grid[32][22]["building"]) == "", "원래 고정 좌표 (22, 32)에는 건물이 덮어씌워지지 않아야 함")
	assert(str(grid.grid[28][22]["building"]) == "", "원래 고정 좌표 (22, 28)에는 건물이 덮어씌워지지 않아야 함")
	assert(str(grid.grid[2][8]["building"]) == "", "원래 고정 좌표 (8, 2)에는 건물이 덮어씌워지지 않아야 함")

	print("[검증 3 통과] 고정 좌표 탈피 완벽 작동: 임의 위치 건축물이 대역사를 완료시키며 원래 고정 좌표 덮어쓰기 없음.")

## 4. 세이브/로드 시 사용자가 변경한 동적 건축물 좌표가 유지되는지 검증
func _test_save_load_custom_locations() -> void:
	print("[검증 4] 세이브/로드 시 사용자가 변경한 동적 좌표 복원 검증...")
	var sim := SimulationCoreClass.new()
	var grid := _create_test_grid()

	# 새 좌표에 장안문과 팔달문, 행궁 배치
	grid.grid[8][30]["building"] = "gate"
	grid.grid[8][30]["gate_name"] = "장안문 (長安門)"
	grid.grid[58][25]["building"] = "gate"
	grid.grid[58][25]["gate_name"] = "팔달문 (八達門)"
	grid.grid[35][35]["building"] = "haenggung"

	grid.update_gate_position("jangan", Vector2i(30, 8))
	grid.update_gate_position("paldal", Vector2i(25, 58))

	# 저장
	var save_ok: bool = SaveSystemClass.save_game(98, sim, grid)
	assert(save_ok, "슬롯 98 저장 성공해야 함")

	# 새 인스턴스로 로드
	var new_sim := SimulationCoreClass.new()
	var new_grid := _create_test_grid()
	var load_ok: bool = SaveSystemClass.load_game(98, new_sim, new_grid)
	assert(load_ok, "슬롯 98 로드 성공해야 함")

	# 로드 후 동적 좌표가 그대로 복원되었는지 검증
	assert(new_grid.get_gate_pos("jangan") == Vector2i(30, 8), "로드 후 장안문 좌표 (30, 8) 유지되어야 함")
	assert(new_grid.get_gate_pos("paldal") == Vector2i(25, 58), "로드 후 팔달문 좌표 (25, 58) 유지되어야 함")
	assert(new_grid.get_facility_pos("haenggung") == Vector2i(35, 35), "로드 후 행궁 좌표 (35, 35) 유지되어야 함")

	SaveSystemClass.delete_save(98)
	print("[검증 4 통과] 세이브/로드 시 동적 좌표 정상 복원 확인.")
