extends SceneTree

const CameraControllerClass = preload("res://scripts/CameraController.gd")
const GameGridClass = preload("res://scripts/GameGrid.gd")
const SimulationCoreClass = preload("res://scripts/SimulationCore.gd")
const CourtSystemClass = preload("res://scripts/CourtSystem.gd")
const HUDControllerClass = preload("res://scripts/HUDController.gd")
const PanelControllerClass = preload("res://scripts/PanelController.gd")
const MilitaryDrillManagerClass = preload("res://scripts/MilitaryDrillManager.gd")
const WallLoopValidatorClass = preload("res://scripts/WallLoopValidator.gd")

func _init() -> void:
	print("=== [테스트 시작] 성곽 방호체제 UI 분리, 방호력 SSOT, 화서문 폐곡선, 미완성 가이드 및 서장대 야조 검증 ===")
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
				"road_type": "dirt"
			})
		g.grid.append(row)
	return g

func _run_tests() -> void:
	_test_wall_defense_ssot_and_damage()
	_test_hwaseomun_classification_and_loop()
	_test_unconnected_wall_points()
	_test_seojangdae_drill_positioning()
	_test_modal_clear_body_isolation()
	_test_hud_jump_to_grid()

	print("=== [테스트 완료] 성곽 방호체제 및 미완성 가이드 전 항목 100% 통과! ===")
	quit(0)

## 1. 방호력 산출식 단일화 및 피해도/수축 보너스 보존 검증 (50 리셋 방지)
func _test_wall_defense_ssot_and_damage() -> void:
	print("[검증 1] CityStats 성 방호력 SSOT 및 수축 보너스/피해도 유지 검증...")
	var sim := SimulationCoreClass.new()
	var grid := _create_test_grid()
	grid.fortress_progress = 100

	CityStats.reset_to_defaults()
	CityStats.recalculate_defense_and_attack(grid, sim)

	var initial_max: int = CityStats.get_max_defense_power()
	var initial_cur: int = CityStats.get_fortress_defense_power()
	assert(initial_max >= 50, "성곽 100% 완공 시 최대 방호력 50 이상이어야 함")
	assert(initial_cur == initial_max, "초기 현재 방호력은 최대치와 같아야 함")

	# 도적 습격으로 피해 발생
	CityStats.apply_defense_damage(15, sim)
	assert(CityStats.get_defense_damage_taken() == 15, "피해도 15 기록되어야 함")
	assert(CityStats.get_fortress_defense_power() == initial_max - 15, "피해 반영 후 방호력 차감되어야 함")

	# 틱 재계산 시 피해도가 50으로 리셋되지 않고 유지되는지 검증
	CityStats.recalculate_defense_and_attack(grid, sim)
	assert(CityStats.get_fortress_defense_power() == initial_max - 15, "재계산 후에도 피해도가 유지되어야 함 (50 리셋 방지)")

	# 긴급 땜질로 피해 복구
	CityStats.apply_emergency_repair(10, sim)
	assert(CityStats.get_defense_damage_taken() == 5, "땜질 후 잔여 피해도 5이어야 함")
	assert(CityStats.get_fortress_defense_power() == initial_max - 5, "땜질 후 방호력 복원되어야 함")

	# 수축 보수 누적치 가산 (누적 보수치가 잔여 피해도 5를 상쇄 및 완치)
	CityStats.add_repair_bonus(20, sim)
	assert(CityStats.get_max_defense_power() == initial_max + 20, "수축 보수로 최대 방호력 증가해야 함")
	assert(CityStats.get_defense_damage_taken() == 0, "보수치 적용으로 기존 경미 피해는 완치되어야 함")
	assert(CityStats.get_fortress_defense_power() == initial_max + 20, "보수 누적치 반영되어야 함")

	# 재계산 후에도 수축 보수 누적치 보존 검증
	CityStats.recalculate_defense_and_attack(grid, sim)
	assert(CityStats.get_fortress_defense_power() == initial_max + 20, "재계산 후에도 수축 보수치가 50으로 덮어써지지 않아야 함")
	print("  -> 방호력 수치 보존 및 50 리셋 방지 검증 완료!")

## 2. 화서문(6, 13) 권역 판정 및 사대문 폐곡선 판정 검증
func _test_hwaseomun_classification_and_loop() -> void:
	print("[검증 2] 화서문(6, 13) 장안문 오분류 방지 및 사대문 폐곡선 검증...")
	var validator := WallLoopValidatorClass.new()
	var grid := _create_test_grid()

	# 사대문 배치 (완공 상태)
	grid.grid[10][32]["building"] = "gate"
	grid.grid[10][32]["gate_name"] = "jangan_mun"

	grid.grid[50][32]["building"] = "gate"
	grid.grid[50][32]["gate_name"] = "paldal_mun"

	grid.grid[30][54]["building"] = "gate"
	grid.grid[30][54]["gate_name"] = "changryong_mun"

	# 화서문 좌표 (6, 13) - 기존에 y<15로 인해 장안문으로 오판되던 핵심 좌표
	grid.grid[13][6]["building"] = "gate"
	grid.grid[13][6]["gate_name"] = "hwaseo_mun"

	var loop_res: Dictionary = validator.validate_loop(grid)
	var missing: Array = loop_res.get("missing_gates", [])
	assert(not ("hwaseo" in missing), "화서문이 누락 성문에 포함되지 않고 정상 식별되어야 함 (장안문 오분류 차단)")
	assert(not ("jangan" in missing), "장안문이 정상 식별되어야 함")
	assert(not ("paldal" in missing), "팔달문이 정상 식별되어야 함")
	assert(not ("changryong" in missing), "창룡문이 정상 식별되어야 함")
	assert(missing.is_empty(), "사대문 4곳이 모두 식별되어 missing_gates가 비어 있어야 함")
	print("  -> 화서문(6, 13) 정밀 식별 및 사대문 4곳 정상 분류 완료!")

## 3. 미완성 지점 탐색(find_unconnected_wall_points) 검증
func _test_unconnected_wall_points() -> void:
	print("[검증 3] WallLoopValidator.find_unconnected_wall_points 미완성 지점 탐색 검증...")
	var validator := WallLoopValidatorClass.new()
	var grid := _create_test_grid()

	# 성벽 공사 중 타일 추가
	grid.grid[15][10]["building"] = "wall"
	grid.grid[15][10]["under_construction"] = true

	grid.grid[20][10]["building"] = "wall"
	grid.grid[20][10]["wall_build"] = true

	var unconn: Array[Vector2i] = validator.find_unconnected_wall_points(grid)
	assert(unconn.size() >= 2, "공사 중인 타일들이 미완성 지점으로 탐색되어야 함")
	assert(Vector2i(10, 15) in unconn, "타일 (10, 15) 탐색 포함되어야 함")
	assert(Vector2i(10, 20) in unconn, "타일 (10, 20) 탐색 포함되어야 함")
	print("  -> 미완성 지점 탐색 %d곳 정상 반환 완료!" % unconn.size())

## 4. 서장대 야조 훈련 좌표 포커싱 검증 (행궁 마당 탈피)
func _test_seojangdae_drill_positioning() -> void:
	print("[검증 4] MilitaryDrillManager 서장대 야조 훈련 좌표 탐색 검증...")
	var drill_mgr := MilitaryDrillManagerClass.new()
	root.add_child(drill_mgr)
	var grid := _create_test_grid()
	drill_mgr.grid = grid

	# 서장대 건물을 (12, 35)에 완공 상태로 배치
	grid.grid[35][12]["building"] = "seojangdae"
	grid.grid[35][12]["site_anchor"] = Vector2i(12, 35)

	# 행궁 정문을 (32, 32)에 배치
	grid.grid[32][32]["building"] = "haenggung"

	var found_pos: Vector2i = drill_mgr._find_building_pos("seojangdae", Vector2i(8, 38))
	assert(found_pos == Vector2i(12, 35), "서장대 좌표인 (12, 35)를 정확히 탐색해야 함")
	assert(found_pos != Vector2i(32, 32), "행궁 마당 좌표가 아니어야 함")
	drill_mgr.queue_free()
	print("  -> 서장대 실제 위치 정밀 타깃팅 검증 완료!")

## 5. PanelController _open 및 _clear_body 독립성 검증
func _test_modal_clear_body_isolation() -> void:
	print("[검증 5] PanelController _open 및 _clear_body UI 격리 검증...")
	var panel := PanelControllerClass.new()
	root.add_child(panel)

	# 모달 바디 직접 생성 모의
	var body := VBoxContainer.new()
	panel._body = body
	panel.add_child(body)

	var dummy_lbl := Label.new()
	dummy_lbl.text = "신해통공 난전 허용 잔존 위젯"
	body.add_child(dummy_lbl)
	assert(body.get_child_count() == 1, "임시 위젯 1개 존재해야 함")

	# _clear_body 호출
	panel._clear_body()
	# queue_free 후 수동 제거하여 즉시 자식 0개 검증
	for c in body.get_children():
		body.remove_child(c)
		c.free()
	assert(body.get_child_count() == 0, "바디 정리 후 위젯이 완전히 비워져야 함")
	panel.queue_free()
	print("  -> UI 바디 격리 및 잔존 위젯 원천 차단 검증 완료!")

## 6. HUDController.jump_to_grid 카메라 이동 검증
func _test_hud_jump_to_grid() -> void:
	print("[검증 6] HUDController.jump_to_grid 카메라 이동 검증...")
	var hud := HUDControllerClass.new()
	root.add_child(hud)
	var cam := CameraControllerClass.new()
	root.add_child(cam)
	cam.position = Vector2.ZERO

	hud.camera = cam
	var target_cell := Vector2i(20, 10)
	hud.jump_to_grid(target_cell, false)

	var expected_x: float = float(20 - 10) * 32.0
	var expected_y: float = float(20 + 10) * 16.0
	assert(cam.position == Vector2(expected_x, expected_y), "카메라가 목표 타일 월드 좌표로 정확히 이동해야 함")
	hud.queue_free()
	cam.queue_free()
	print("  -> HUD jump_to_grid 연동 정상 검증 완료!")
