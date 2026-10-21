extends SceneTree

const CameraControllerClass = preload("res://scripts/CameraController.gd")
const CitizenManagerClass = preload("res://scripts/CitizenManager.gd")
const CitizenLayerClass = preload("res://scripts/CitizenLayer.gd")
const CityLayerClass = preload("res://scripts/CityLayer.gd")
const GameGridClass = preload("res://scripts/GameGrid.gd")
const SimulationCoreClass = preload("res://scripts/SimulationCore.gd")
const CourtSystemClass = preload("res://scripts/CourtSystem.gd")
const HUDControllerClass = preload("res://scripts/HUDController.gd")
const BanditManagerClass = preload("res://scripts/BanditManager.gd")

func _init() -> void:
	print("=== [테스트 시작] 반란/전투 카메라 포커스 이동, 경보 배너, 외곽 마커 및 백병전 비주얼 검증 ===")
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
	_test_camera_focus_and_unlock()
	_test_citizen_manager_battle_tracking()
	_test_hud_raid_banner_and_edge_marker()
	_test_citizen_layer_combat_visuals()

	print("=== [테스트 완료] 카메라 포커스·경보배너·외곽마커·백병전 비주얼 전 항목 100% 통과! ===")
	quit(0)

## 1. 카메라 포커스 및 조작 락 방지 검증
func _test_camera_focus_and_unlock() -> void:
	print("[검증 1] CameraController 포커스 이동 및 조작 락 방지 검증...")
	var cam := CameraControllerClass.new()
	root.add_child(cam)
	cam.position = Vector2(0, 0)
	cam.zoom = Vector2(1.0, 1.0)

	# 1) 즉시 이동 (smooth = false)
	var target_pos := Vector2(500, 300)
	cam.focus_on_coordinate(target_pos, false)
	assert(cam.position == target_pos, "카메라 즉시 이동 실패")

	# 2) 뷰포트 내/외 판정 검증
	assert(cam.is_world_pos_in_view(Vector2(500, 300)), "타겟이 뷰포트 내에 있어야 함")
	assert(not cam.is_world_pos_in_view(Vector2(5000, 3000)), "원거리 좌표는 뷰포트 바깥이어야 함")

	# 3) 부드러운 이동 (smooth = true) 및 수동 조작 트윈 해제 검증
	cam.focus_on_coordinate(Vector2(1000, 1000), true)
	assert(cam._focus_tween != null and cam._focus_tween.is_valid(), "포커스 트윈이 생성되어야 함")

	# 수동 조작 시 트윈 즉시 중단 검증
	cam.stop_focus_tween()
	assert(cam._focus_tween == null, "stop_focus_tween 후 트윈이 null이어야 함")

	cam.queue_free()
	print("  - [PASS] 카메라 포커스 이동 및 수동 조작 락 방지 검증 완료")

## 2. CitizenManager 교전 위치 추적 및 시그널 검증
func _test_citizen_manager_battle_tracking() -> void:
	print("[검증 2] CitizenManager 교전 위치 추적 및 시그널 검증...")
	var grid := _create_test_grid()
	var sim := SimulationCoreClass.new()
	var court := CourtSystemClass.new()
	var cm := CitizenManagerClass.new()
	root.add_child(cm)
	cm.setup(grid, court, sim)

	var signal_data := {
		"received": false,
		"wpos": Vector2.ZERO,
		"loc": ""
	}

	cm.bandit_battle_started.connect(func(wpos: Vector2, loc: String):
		signal_data["received"] = true
		signal_data["wpos"] = wpos
		signal_data["loc"] = loc
	)

	# 도적 침략 시작 발화
	cm._start_bandit_raid()
	assert(cm.is_bandit_battle_active(), "도적 침략이 활성화되어야 함")
	assert(signal_data["received"], "bandit_battle_started 시그널이 발화되어야 함")
	assert(signal_data["loc"] != "", "교전 지역 명칭이 비어있지 않아야 함: %s" % signal_data["loc"])

	# 교전 좌표 계산 검증
	var battle_pos: Vector2 = cm.get_current_battle_world_pos()
	assert(battle_pos != Vector2.ZERO, "교전 위치 좌표가 유효해야 함")

	# 침략 종료 검증
	var end_data := {"received": false}
	cm.bandit_battle_ended.connect(func(_rep: bool):
		end_data["received"] = true
	)
	cm._end_bandit_raid(true)
	assert(not cm.is_bandit_battle_active(), "도적 침략이 비활성화되어야 함")
	assert(end_data["received"], "bandit_battle_ended 시그널이 발화되어야 함")

	cm.queue_free()
	print("  - [PASS] CitizenManager 교전 위치 추적 및 시그널 검증 완료")

## 3. HUDController 상단 경보 배너 및 외곽 마커 검증
func _test_hud_raid_banner_and_edge_marker() -> void:
	print("[검증 3] HUDController 상단 긴급 경보 배너 및 외곽 마커 검증...")
	var hud := HUDControllerClass.new()
	root.add_child(hud)
	var cam := CameraControllerClass.new()
	root.add_child(cam)
	var sim := SimulationCoreClass.new()
	var tm := TimeManager.new()

	hud.setup(tm, sim, cam)

	# 1) 배너 표시 검증
	var test_wpos := Vector2(1200, 800)
	hud.show_raid_alert_banner(test_wpos, "팔달문 외곽")
	assert(hud._is_battle_active == true, "배틀 활성 플래그가 true여야 함")
	assert(hud.banner_raid_alert != null and hud.banner_raid_alert.visible == true, "경보 배너가 보여야 함")
	assert(hud.label_raid_alert != null and "팔달문 외곽" in hud.label_raid_alert.text, "라벨에 지역명이 포함되어야 함")

	# 2) 위치 이동 버튼 동작 검증
	cam.position = Vector2(0, 0)
	hud.btn_jump_battle.pressed.emit()
	# 트윈 또는 카메라 좌표 갱신 확인
	assert(cam.position != Vector2.ZERO or (cam._focus_tween != null and cam._focus_tween.is_valid()), "위치 보기 클릭 시 카메라가 포커싱되어야 함")

	# 3) 화면 외곽 마커 계산 검증
	hud._update_edge_marker_position()
	assert(hud.edge_battle_marker != null, "외곽 마커가 생성되어 있어야 함")

	# 4) 배너 닫기 검증
	hud.hide_raid_alert_banner()
	assert(hud._is_battle_active == false, "배틀 활성 플래그가 false여야 함")
	assert(hud.banner_raid_alert.visible == false, "경보 배너가 숨겨져야 함")
	assert(hud.edge_battle_marker.visible == false, "외곽 마커가 숨겨져야 함")

	hud.queue_free()
	cam.queue_free()
	print("  - [PASS] HUDController 상단 경보 배너 및 외곽 마커 검증 완료")

## 4. CitizenLayer 백병전 비주얼 및 게이지 렌더링 검증
func _test_citizen_layer_combat_visuals() -> void:
	print("[검증 4] CitizenLayer 백병전 흙먼지 및 교전 게이지 렌더링 검증...")
	var grid := _create_test_grid()
	var sim := SimulationCoreClass.new()
	var court := CourtSystemClass.new()
	var cm := CitizenManagerClass.new()
	root.add_child(cm)
	cm.setup(grid, court, sim)

	var cl := CitizenLayerClass.new()
	root.add_child(cl)
	cl.setup(grid, cm, null)

	assert(cl.z_index == 10, "CitizenLayer z_index는 10이어야 함")
	assert(cl.y_sort_enabled == true, "CitizenLayer y_sort_enabled는 true여야 함")

	# 교전 에이전트 등록 후 드로우 함수 예외 없는지 호출 검증
	cm._bandit_raid_active = true
	cm._bandit_siege_hp = 350
	var ag_b: Dictionary = {
		"id": 1, "type": "bandit", "x": 10.0, "y": 10.0, "state": "combat", "is_dead": false
	}
	var ag_t: Dictionary = {
		"id": 2, "type": "jangyongyeong_soldier", "x": 10.5, "y": 10.2, "state": "combat", "is_dead": false
	}
	cm.agents.append(ag_b)
	cm.agents.append(ag_t)

	# 내부 렌더 헬퍼 직접 호출하여 크래시 없는지 검증
	cl._draw_combat_dust_clouds()
	cl._draw_battle_status_hud()

	cm.queue_free()
	cl.queue_free()
	print("  - [PASS] CitizenLayer 백병전 흙먼지 및 교전 게이지 렌더링 검증 완료")
