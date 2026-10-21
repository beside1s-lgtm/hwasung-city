extends SceneTree

const GameGridClass = preload("res://scripts/GameGrid.gd")
const SimulationCoreClass = preload("res://scripts/SimulationCore.gd")
const SaveSystemClass = preload("res://scripts/SaveSystem.gd")

func _init() -> void:
	print("=== [테스트 시작] 국책 대역사 건축물 자동 완공 전환 및 재정 부족 일시정지/재개 검증 ===")
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
	_test_building_auto_completes_mega_projects()
	_test_prevent_duplicate_construction_and_overwrite()
	_test_budget_shortage_pause_and_resume_fsm()
	_test_save_load_mega_project_state()

	print("=== [테스트 완료] 국책 대역사 자동 완공 및 일시정지 FSM 전 항목 100% 통과! ===")
	quit(0)

## 1. 각 주요 건물(서장대, 장안문, 화서문, 창룡문, 팔달문, 화홍문, 남수문, 만석거, 제방, 행궁, 관아) 완공 시 대역사 자동 완료 검증
func _test_building_auto_completes_mega_projects() -> void:
	print("[검증 1] 건축물 완공 시 국책 대역사 자동 완료 전환 검증...")

	# 1) 만석거 완공 -> manseok_reservoir 완료
	var sim1 := SimulationCoreClass.new()
	var grid1 := _create_test_grid()
	grid1.grid[2][8]["building"] = "manseokgeo"
	grid1.grid[2][8]["under_construction"] = false
	sim1.sync_mega_projects_with_grid(grid1)
	var p_manseok := _find_project(sim1, "manseok_reservoir")
	assert(bool(p_manseok.get("is_completed", false)), "만석거 본체 완공 시 manseok_reservoir 대역사가 완료되어야 함")
	assert(not bool(p_manseok.get("is_started", false)), "완료된 대역사는 is_started가 false여야 함")

	# 2) 제방 4개 완공 -> suwon_levee 완료
	var sim2 := SimulationCoreClass.new()
	var grid2 := _create_test_grid()
	for i in range(4):
		grid2.grid[20 + i][29]["building"] = "levee"
		grid2.grid[20 + i][29]["under_construction"] = false
	sim2.sync_mega_projects_with_grid(grid2)
	var p_levee := _find_project(sim2, "suwon_levee")
	assert(bool(p_levee.get("is_completed", false)), "제방 4개소 완공 시 suwon_levee 대역사가 완료되어야 함")

	# 3) 서장대 완공 -> paldal_fortress 완료
	var sim3 := SimulationCoreClass.new()
	var grid3 := _create_test_grid()
	grid3.grid[29][13]["building"] = "seojangdae"
	grid3.grid[29][13]["under_construction"] = false
	sim3.sync_mega_projects_with_grid(grid3)
	var p_paldal := _find_project(sim3, "paldal_fortress")
	assert(bool(p_paldal.get("is_completed", false)), "서장대 완공 시 paldal_fortress 대역사가 완료되어야 함")

	# 4) 화서문(6, 13) 완공 -> paldal_fortress 완료
	var sim4 := SimulationCoreClass.new()
	var grid4 := _create_test_grid()
	grid4.grid[13][6]["building"] = "gate"
	grid4.grid[13][6]["under_construction"] = false
	sim4.sync_mega_projects_with_grid(grid4)
	var p_hwaseo := _find_project(sim4, "paldal_fortress")
	assert(bool(p_hwaseo.get("is_completed", false)), "화서문 완공 시 paldal_fortress 대역사가 완료되어야 함")

	# 5) 장안문(26, 6) 완공 -> hwahong_north 완료
	var sim5 := SimulationCoreClass.new()
	var grid5 := _create_test_grid()
	grid5.grid[6][26]["building"] = "gate"
	grid5.grid[6][26]["under_construction"] = false
	sim5.sync_mega_projects_with_grid(grid5)
	var p_jangan := _find_project(sim5, "hwahong_north")
	assert(bool(p_jangan.get("is_completed", false)), "장안문 완공 시 hwahong_north 대역사가 완료되어야 함")

	# 6) 화홍문(35, 13) 완공 -> hwahong_north 완료
	var sim6 := SimulationCoreClass.new()
	var grid6 := _create_test_grid()
	grid6.grid[13][35]["building"] = "hwahong"
	grid6.grid[13][35]["under_construction"] = false
	sim6.sync_mega_projects_with_grid(grid6)
	var p_hwahong := _find_project(sim6, "hwahong_north")
	assert(bool(p_hwahong.get("is_completed", false)), "화홍문 완공 시 hwahong_north 대역사가 완료되어야 함")

	# 7) 창룡문(48, 29) 완공 -> changryong_east 완료
	var sim7 := SimulationCoreClass.new()
	var grid7 := _create_test_grid()
	grid7.grid[29][48]["building"] = "gate"
	grid7.grid[29][48]["under_construction"] = false
	sim7.sync_mega_projects_with_grid(grid7)
	var p_chang := _find_project(sim7, "changryong_east")
	assert(bool(p_chang.get("is_completed", false)), "창룡문 완공 시 changryong_east 대역사가 완료되어야 함")

	# 8) 팔달문(16, 54) 완공 -> namsu_south 완료
	var sim8 := SimulationCoreClass.new()
	var grid8 := _create_test_grid()
	grid8.grid[54][16]["building"] = "gate"
	grid8.grid[54][16]["under_construction"] = false
	sim8.sync_mega_projects_with_grid(grid8)
	var p_paldal_gate := _find_project(sim8, "namsu_south")
	assert(bool(p_paldal_gate.get("is_completed", false)), "팔달문 완공 시 namsu_south 대역사가 완료되어야 함")

	# 9) 남수문(29, 54) 완공 -> namsu_south 완료
	var sim9 := SimulationCoreClass.new()
	var grid9 := _create_test_grid()
	grid9.grid[54][29]["building"] = "namsu"
	grid9.grid[54][29]["under_construction"] = false
	sim9.sync_mega_projects_with_grid(grid9)
	var p_namsu := _find_project(sim9, "namsu_south")
	assert(bool(p_namsu.get("is_completed", false)), "남수문 완공 시 namsu_south 대역사가 완료되어야 함")

	# 10) 행궁(22, 32) 완공 -> haenggung_palace 완료
	var sim10 := SimulationCoreClass.new()
	var grid10 := _create_test_grid()
	grid10.grid[32][22]["building"] = "haenggung"
	grid10.grid[32][22]["under_construction"] = false
	sim10.sync_mega_projects_with_grid(grid10)
	var p_haeng := _find_project(sim10, "haenggung_palace")
	assert(bool(p_haeng.get("is_completed", false)), "행궁 완공 시 haenggung_palace 대역사가 완료되어야 함")

	# 11) 관아(22, 28) 완공 -> gwana_office 완료
	var sim11 := SimulationCoreClass.new()
	var grid11 := _create_test_grid()
	grid11.grid[28][22]["building"] = "gwana"
	grid11.grid[28][22]["under_construction"] = false
	sim11.sync_mega_projects_with_grid(grid11)
	var p_gwana := _find_project(sim11, "gwana_office")
	assert(bool(p_gwana.get("is_completed", false)), "관아 완공 시 gwana_office 대역사가 완료되어야 함")

	print("[검증 1 통과] 모든 주요 시설에 대해 국책 대역사가 정확하게 자동 완료로 전환됨 확인.")

## 2. 2중 건축 방지 및 기존 완공 시설 보존 검증
func _test_prevent_duplicate_construction_and_overwrite() -> void:
	print("[검증 2] 2중 건축 방지 및 기존 완공 시설 보존 검증...")
	var sim := SimulationCoreClass.new()
	var grid := _create_test_grid()

	# 서장대가 이미 완공된 상태
	grid.grid[29][13]["building"] = "seojangdae"
	grid.grid[29][13]["under_construction"] = false

	# 서성곽 타일 중 하나에 포루(상위 방어시설)가 이미 설치된 상태
	grid.grid[30][6]["building"] = "poru"
	grid.grid[30][6]["under_construction"] = false

	# 동기화 수행
	sim.sync_mega_projects_with_grid(grid)

	# 1) 이미 완공된 사업 착공 시도 차단 검증
	var res: Dictionary = sim.start_mega_project("paldal_fortress", grid)
	assert(not bool(res.get("success", false)), "이미 완공된 서장대 대역사는 착공이 거부되어야 함")
	assert(str(res.get("msg", "")) == "이미 완공된 사업입니다.", "완공 거부 메시지 일치 확인")

	# 2) set_construction으로 비계를 씌우려 해도 이미 완공된 포루나 서장대에는 비계가 씌워지지 않아야 함
	# (대역사에 포함되지 않은 순수 빈 타일 (50, 50)에는 정상적으로 비계가 씌워져야 함)
	grid.set_construction([
		{"x": 13, "y": 29, "building": "seojangdae"},
		{"x": 6, "y": 30, "building": "wall"},
		{"x": 50, "y": 50, "building": "wall"}
	], true)
	assert(not bool(grid.grid[29][13].get("under_construction", false)), "완공된 서장대에는 비계가 씌워지지 않아야 함")
	assert(not bool(grid.grid[30][6].get("under_construction", false)), "상위 방어시설 포루에는 비계가 씌워지지 않아야 함")
	assert(bool(grid.grid[50][50].get("under_construction", false)), "순수 빈 타일에는 정상적으로 비계가 씌워져야 함")

	# 3) complete_targets를 호출해도 포루나 서장대가 'wall'로 다운그레이드되거나 덮어쓰이지 않아야 함
	grid.complete_targets([
		{"x": 13, "y": 29, "building": "seojangdae"},
		{"x": 6, "y": 30, "building": "wall"},
		{"x": 50, "y": 50, "building": "wall"}
	])
	assert(str(grid.grid[29][13]["building"]) == "seojangdae", "기존 서장대 건물이 훼손되지 않고 보존되어야 함")
	assert(str(grid.grid[30][6]["building"]) == "poru", "기존 포루 건물이 'wall'로 강등되지 않고 보존되어야 함")
	assert(str(grid.grid[50][50]["building"]) == "wall", "빈 타일은 정상적으로 'wall'로 완공되어야 함")

	print("[검증 2 통과] 2중 건축 차단 및 기존 시설 보존 무결성 확인.")

## 3. 재정 부족 시 일시 멈춤(Pause) 및 자동 속개(Resume) FSM 검증
func _test_budget_shortage_pause_and_resume_fsm() -> void:
	print("[검증 3] 재정 부족 시 일시 멈춤 및 자동 속개 FSM 검증...")
	var sim := SimulationCoreClass.new()
	sim.gold = 10000
	sim.rice = 5000

	# 1) 대역사 착공
	var start_res := sim.start_mega_project("changryong_east")
	assert(bool(start_res.get("success", false)), "창룡문 대역사 착공 성공해야 함")
	var p_chang := _find_project(sim, "changryong_east")
	assert(bool(p_chang.get("is_started", false)), "is_started가 true여야 함")
	assert(not bool(p_chang.get("is_paused", false)), "착공 직후에는 is_paused가 false여야 함")

	var paused_emitted: Array[String] = []
	var resumed_emitted: Array[String] = []
	sim.project_paused.connect(func(pid: String, msg: String): paused_emitted.append(pid + ":" + msg))
	sim.project_resumed.connect(func(pid: String, msg: String): resumed_emitted.append(pid + ":" + msg))

	# 1턴 정상 진행
	sim._process_mega_projects()
	assert(int(p_chang.get("progress_turns", 0)) == 1, "정상 진행 시 1턴 누적되어야 함")
	assert(not bool(p_chang.get("is_paused", false)), "자원 충분 시 is_paused는 false여야 함")

	# 2) 재정 고갈 (금화 0, 군량 0)
	sim.gold = 0
	sim.rice = 0

	# 턴 공정 실행 -> 자원 부족으로 일시 멈춤(Pause) 전이
	sim._process_mega_projects()
	assert(bool(p_chang.get("is_paused", false)), "자원 부족 시 is_paused가 true로 전이되어야 함")
	assert(int(p_chang.get("progress_turns", 0)) == 1, "일시 멈춤 시 진행도가 증가하지 않고 1로 동결되어야 함")
	assert(paused_emitted.size() == 1, "project_paused 시그널이 1회 발화되어야 함")

	# 추가 턴 진행 시에도 계속 일시 멈춤 상태 유지 (시그널 중복 발화 없이 동결)
	sim._process_mega_projects()
	assert(bool(p_chang.get("is_paused", false)), "자원 미해결 시 일시 멈춤 유지")
	assert(int(p_chang.get("progress_turns", 0)) == 1, "진행도 계속 1로 동결")
	assert(paused_emitted.size() == 1, "시그널 중복 발화 없이 1회 유지")

	# 3) 재정 확보 (국고 확충)
	sim.gold = 50000
	sim.rice = 20000

	# 턴 공정 실행 -> 자동 속개(Resume) 전이 및 공정 진행
	sim._process_mega_projects()
	assert(not bool(p_chang.get("is_paused", false)), "자원 확보 시 is_paused가 false로 해제되어야 함")
	assert(int(p_chang.get("progress_turns", 0)) == 2, "공사 재개 후 진행도가 2로 정상 누적되어야 함")
	assert(resumed_emitted.size() == 1, "project_resumed 시그널이 1회 발화되어야 함")

	print("[검증 3 통과] 재정 부족 일시정지 및 국고 확충 자동 속개 FSM 정상 작동 확인.")

## 4. 세이브/로드 호환성 및 대역사 상태 복원 검증
func _test_save_load_mega_project_state() -> void:
	print("[검증 4] 세이브/로드 대역사 상태 및 일시정지 복원 검증...")
	var sim := SimulationCoreClass.new()
	sim.gold = 50000
	sim.rice = 20000
	var grid := _create_test_grid()

	# 창룡문 착공 후 3턴 진행 및 일시정지 설정
	sim.start_mega_project("changryong_east", grid)
	var p_chang := _find_project(sim, "changryong_east")
	p_chang["progress_turns"] = 3
	p_chang["progress_ticks"] = 3
	p_chang["is_paused"] = true

	# 슬롯 99에 저장
	var save_ok: bool = SaveSystemClass.save_game(99, sim, grid)
	assert(save_ok, "슬롯 99 저장 성공해야 함")

	# 새로운 시뮬레이션 및 그리드 인스턴스로 로드
	var new_sim := SimulationCoreClass.new()
	var new_grid := _create_test_grid()
	var load_ok: bool = SaveSystemClass.load_game(99, new_sim, new_grid)
	assert(load_ok, "슬롯 99 로드 성공해야 함")

	var loaded_p := _find_project(new_sim, "changryong_east")
	assert(bool(loaded_p.get("is_started", false)), "로드 후 is_started 상태 복원 확인")
	assert(bool(loaded_p.get("is_paused", false)), "로드 후 is_paused 상태 복원 확인")
	assert(int(loaded_p.get("progress_turns", 0)) == 3, "로드 후 progress_turns 3 복원 확인")

	# 테스트 슬롯 삭제
	SaveSystemClass.delete_save(99)
	print("[검증 4 통과] 세이브/로드 시 대역사 진행도 및 일시정지 상태 복원 확인.")
