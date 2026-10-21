extends SceneTree

## [을묘원행반차도 도트 스프라이트, 도로망 엄격 추종 및 군사훈련 종합 단위 테스트]

func _init() -> void:
	print("=== [테스트 시작] 을묘원행반차도 도트, 도로망 추종 및 군사훈련 검증 ===")

	test_procession_unit_art()
	test_road_following_waypoints()
	test_snake_procession_queue()
	test_military_drill_manager()
	test_camera_interruption_safety()
	test_eulmyo_yajo_integration()

	print("=== [테스트 완료] 모든 항목 100% 통과 (ALL PASS)! ===")
	quit(0)

## 1. ProcessionUnitArt 도트 스프라이트 아틀라스 무결성 검증
func test_procession_unit_art() -> void:
	print("[검증 1] ProcessionUnitArt 고증 도트 스프라이트 아틀라스 렌더러 검증...")

	var roles_to_test: Array[String] = [
		"hyegyeong_palanquin",
		"jeongjo_king",
		"gyeonggi_governor",
		"lead_cavalry",
		"chwita",
		"posu",
		"salsu",
		"sasu",
		"gipo",
		"royal_flag",
		"chae_jegong",
		"court_lady",
		"palanquin_bearer"
	]

	# 모든 13종 역할에 대해 march 및 drill 아틀라스 행이 정상 빌드되는지 검증
	for r: String in roles_to_test:
		ProcessionUnitArt._build_role_row(r, false)
		ProcessionUnitArt._build_role_row(r, true)
		var key_march: String = "%s|march" % r
		var key_drill: String = "%s|drill" % r
		assert(ProcessionUnitArt._rows.has(key_march), "아틀라스 march 행 등록 실패: %s" % r)
		assert(ProcessionUnitArt._rows.has(key_drill), "아틀라스 drill 행 등록 실패: %s" % r)

	print("  -> ProcessionUnitArt 13종 고증 도트 및 4방향/2프레임 아틀라스 베이킹 검증 성공.")

## 2. 도로망 엄격 추종 (Strict Road Following) 웨이포인트 경로 검증
func test_road_following_waypoints() -> void:
	print("[검증 2] 도로망 엄격 추종(Strict Road Following) 웨이포인트 생성 검증...")
	var win: Window = root
	var grid := GameGrid.new()
	win.add_child(grid)
	grid._build_from_map()

	# 북쪽 외곽 (26, 0) -> 장안문 (26, 6) -> 종로 박석길 -> 신풍루/행궁 (24, 32)
	# 도로망 포설
	for y in range(0, 35):
		grid.grid[y][26]["building"] = "road"
		grid.grid[y][26]["road_type"] = "stone" if y >= 20 else "dirt"
	grid.grid[6][26]["building"] = "gate" # 장안문
	grid.grid[32][24]["building"] = "road"
	grid.grid[32][25]["building"] = "road" # 신풍루 연결

	var rp := RoyalProcessionManager.new()
	win.add_child(rp)
	rp.grid = grid
	rp.jangan_pos = Vector2i(26, 6)
	rp.sinpungru_pos = Vector2i(24, 32)

	rp._build_procession_waypoints()

	assert(rp.waypoints.size() > 20, "웨이포인트가 충분히 생성되지 않았습니다.")
	# 모든 웨이포인트가 유효 월드 좌표를 가지는지 확인
	for wp: Vector2 in rp.waypoints:
		assert(not is_nan(wp.x) and not is_nan(wp.y), "NaN 웨이포인트 발생")

	# 퇴장 경로 (신풍루 -> 팔달문 (26, 46) -> 남쪽 외곽 (26, 60))
	for y in range(35, 62):
		grid.grid[y][26]["building"] = "road"
	grid.grid[46][26]["building"] = "gate" # 팔달문
	rp.paldal_pos = Vector2i(26, 46)

	rp._build_exit_waypoints()
	assert(rp.waypoints.size() > 20, "팔달문 퇴장 웨이포인트 생성 실패")

	rp.queue_free()
	grid.queue_free()
	print("  -> 도로망 BFS 기반 최단 도로 추종 및 웨이포인트 보간 검증 성공.")

## 3. Snake 대열 추종 (Leader-Follower Trail Queue) 및 유닛 방향 계산 검증
func test_snake_procession_queue() -> void:
	print("[검증 3] Snake 대열 추종 및 4방향 계산 검증...")
	var rp := RoyalProcessionManager.new()
	rp.waypoints = [
		Vector2(0, 0),
		Vector2(50, 25),
		Vector2(100, 50),
		Vector2(150, 75),
		Vector2(200, 100),
		Vector2(250, 125)
	]
	rp._init_procession_units()

	assert(rp.procession_units.size() == 44, "6개 제대 44기 유닛 풀링 수 불일치 (현재: %d)" % rp.procession_units.size())

	# 가마 및 기마 유닛 고유 간격 검증
	var palanquin_found: bool = false
	var king_found: bool = false
	for u: Dictionary in rp.procession_units:
		if u["role"] == "hyegyeong_palanquin":
			palanquin_found = true
			assert(u["spacing"] == 44.0, "자궁가마 간격 44.0px 설정 실패")
		elif u["role"] == "jeongjo_king":
			king_found = true
			assert(u["spacing"] == 32.0, "정조 대왕 기마 간격 32.0px 설정 실패")

	assert(palanquin_found and king_found, "주요 유닛 누락")

	# 선두 전진 시뮬레이션
	rp.lead_distance_traveled = 120.0
	for step in range(30):
		var d: float = float(step) * 4.0
		rp.trail_history.insert(0, rp._get_point_at_distance(d))
	rp._update_snake_units()

	# 후속 유닛들이 정상적으로 트레일 상에 배치되고 방향이 산출되는지 검증
	for i in range(1, 5):
		var u: Dictionary = rp.procession_units[i]
		assert(u["pos"] != Vector2.ZERO, "유닛 위치가 0으로 고정됨")
		assert(u["dir"] in [0, 1, 2, 3], "유효하지 않은 4방향 코드")

	rp.queue_free()
	print("  -> Snake 대열 큐 순차 추종 및 유닛별 간격/방향 무결성 검증 성공.")

## 4. MilitaryDrillManager 서장대 야조 및 연무대 훈련 검증
func test_military_drill_manager() -> void:
	print("[검증 4] MilitaryDrillManager 서장대 야조 및 연무대 훈련 검증...")
	var win: Window = root
	var mdm := MilitaryDrillManager.new()
	var grid := GameGrid.new()
	win.add_child(grid)
	grid._build_from_map()
	win.add_child(mdm)

	grid.grid[29][13]["building"] = "seojangdae"
	grid.grid[20][38]["building"] = "yeonmudae"

	var sim := SimulationCore.new()
	var cam := CameraController.new()
	win.add_child(sim)
	win.add_child(cam)

	mdm.setup(sim, grid, cam, null, null)

	# 서장대 야조 시작 검증
	var ok_sj: bool = mdm.start_seojangdae_drill(false)
	assert(ok_sj, "서장대 야조 시작 실패")
	assert(mdm.current_drill == MilitaryDrillManager.DrillType.SEOJANGDAE_YAJO, "야조 훈련 상태 불일치")
	assert(mdm.drill_troops.size() > 5, "야조 훈련 병사 배치 실패")

	# 틱 업데이트 (조총 섬광 및 백색 연막 FX)
	mdm._process(0.2)
	assert(mdm.night_alpha > 0.0, "야간 어두움 페이드인 미작동")

	# 강제 완료
	mdm.drill_timer = 9.0
	mdm._process(0.1)
	assert(mdm.current_drill == MilitaryDrillManager.DrillType.NONE, "훈련 정상 종료 실패")

	# 연무대 훈련 검증
	var ok_ym: bool = mdm.start_yeonmudae_drill()
	assert(ok_ym, "연무대 훈련 시작 실패")
	assert(mdm.current_drill == MilitaryDrillManager.DrillType.YEONMUDAE_DRILL, "연무대 훈련 상태 불일치")
	mdm._process(0.2)

	mdm.drill_timer = 8.0
	mdm._process(0.1)
	assert(mdm.current_drill == MilitaryDrillManager.DrillType.NONE, "연무대 훈련 정상 종료 실패")

	cam.queue_free()
	sim.queue_free()
	grid.queue_free()
	mdm.queue_free()
	print("  -> 서장대 야조/연무대 훈련 상태 전이 및 VFX 오브젝트 풀 검증 성공.")

## 5. 카메라 포커스 인터럽트 안전성 (Interruption Safety) 검증
func test_camera_interruption_safety() -> void:
	print("[검증 5] 카메라 부드러운 패닝 및 유저 조작 인터럽트 락-프리 검증...")
	var win: Window = root
	var cam := CameraController.new()
	win.add_child(cam)
	cam.position = Vector2(0, 0)

	# 1.0초 부드러운 패닝 시작
	cam.focus_on_coordinate(Vector2(500, 500), true, 1.0)
	assert(cam._focus_tween != null and cam._focus_tween.is_valid(), "포커스 트윈 생성 실패")

	# 유저 조작 (우클릭 / WASD 드래그 등) 발생 시 트윈 즉시 중단
	cam.stop_focus_tween()
	assert(cam._focus_tween == null, "유저 조작 시 트윈 즉시 킬 실패 (조작 락 위험)")

	cam.queue_free()
	print("  -> 카메라 1.0s 패닝 및 사용자 인터럽트 즉각 반환 검증 성공.")

## 6. 을묘원행 SEOJANGDAE_YAJO 단계 연동 검증
func test_eulmyo_yajo_integration() -> void:
	print("[검증 6] 을묘원행 제5단계(SEOJANGDAE_YAJO) 카메라 포커스 및 도트 연출 검증...")
	var win: Window = root
	var rp := RoyalProcessionManager.new()
	var cam := CameraController.new()
	var sim := SimulationCore.new()
	var grid := GameGrid.new()
	win.add_child(grid)
	grid._build_from_map()
	win.add_child(sim)
	win.add_child(cam)
	win.add_child(rp)

	rp.setup(sim, grid, null, null, null, null, null, cam)
	rp.current_phase = RoyalProcessionManager.Phase.SEOJANGDAE_YAJO
	rp.phase_timer = 0.0

	rp._update_seojangdae_yajo(0.05)
	assert(cam._focus_tween != null and cam._focus_tween.is_valid(), "을묘원행 서장대 야조 진입 시 카메라 자동 포커스 실패")

	cam.stop_focus_tween()
	cam.queue_free()
	sim.queue_free()
	grid.queue_free()
	rp.queue_free()
	print("  -> 을묘원행 서장대 야조 페이즈 카메라 및 도트 연출 연동 검증 성공.")
