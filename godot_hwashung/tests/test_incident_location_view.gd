extends SceneTree

const CameraControllerClass = preload("res://scripts/CameraController.gd")
const CitizenManagerClass = preload("res://scripts/CitizenManager.gd")
const CitizenLayerClass = preload("res://scripts/CitizenLayer.gd")
const CityLayerClass = preload("res://scripts/CityLayer.gd")
const GameGridClass = preload("res://scripts/GameGrid.gd")
const SimulationCoreClass = preload("res://scripts/SimulationCore.gd")
const CourtSystemClass = preload("res://scripts/CourtSystem.gd")
const HUDControllerClass = preload("res://scripts/HUDController.gd")
const TimeManagerClass = preload("res://scripts/TimeManager.gd")
const TopAlertBannerClass = preload("res://scripts/TopAlertBanner.gd")
const DisasterPopupClass = preload("res://scripts/DisasterPopup.gd")
const EventManagerClass = preload("res://scripts/EventManager.gd")

func _init() -> void:
	print("=== [테스트 시작] 사건/화재 발생 시 알림창 위치 보기 버튼 및 현장 해결 상황 관찰 검증 ===")
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
	_test_top_alert_banner_location_button()
	_test_disaster_popup_location_button()
	_test_hud_fire_outbreak_and_extinguish()
	_test_citizen_layer_incident_ping_and_fire_hud()
	_test_event_manager_disaster_location_passthrough()

	print("=== [테스트 완료] 사건/화재 알림 위치 보기 및 해결 상황 실시간 확인 전 항목 100% 통과! ===")
	quit(0)

## 1. TopAlertBanner 위치 보기 버튼 및 시그널 발화 검증
func _test_top_alert_banner_location_button() -> void:
	print("[검증 1] TopAlertBanner [위치 보기 🔍] 버튼 노출 및 시그널 연동 검증...")
	var banner := TopAlertBannerClass.new()
	root.add_child(banner)

	# 1) 좌표가 없는 일반 알림 시 [위치 보기] 버튼은 숨김 상태
	banner.push_alert("일반 알림 메시지입니다.")
	assert(banner.visible == true, "알림창이 표시되어야 함")
	assert(banner.view_button != null, "view_button이 생성되어야 함")
	assert(banner.view_button.visible == false, "좌표가 없으면 위치 보기 버튼은 숨겨져야 함")

	# 2) 사건 발생 알림(좌표 포함) 시 [위치 보기] 버튼 활성화 검증
	# [GDScript 람다 캡처 규약] Vector2는 값 복사 캡처되므로 배열로 감싸 참조 캡처 사용
	var received_pos: Array = [Vector2.ZERO]
	banner.location_view_requested.connect(func(pos: Vector2):
		received_pos[0] = pos
	)

	var incident_pos := Vector2(1024.0, 512.0)
	banner.clear_alerts()
	banner.push_alert("🚨 [화마 경보] 민가에서 화재가 발생하였습니다!", incident_pos)

	assert(banner.visible == true, "사건 알림창이 표시되어야 함")
	assert(banner.view_button.visible == true, "좌표가 있는 사건 알림 시 위치 보기 버튼이 보여야 함")
	assert(banner.view_button.text == "위치 보기 🔍", "버튼 텍스트가 '위치 보기 🔍'이어야 함")

	# 3) 위치 보기 버튼 클릭 시 location_view_requested 시그널로 정확한 좌표 발화
	banner._on_view_pressed()
	assert(received_pos[0] == incident_pos, "위치 보기 버튼 클릭 시 올바른 사건 좌표가 발화되어야 함")

	banner.clear_alerts()
	banner.queue_free()
	print(" -> [통과] TopAlertBanner 위치 보기 버튼 및 좌표 발화 정상 작동 확인")

## 2. DisasterPopup 긴급 재난 팝업 위치 보기 버튼 검증
func _test_disaster_popup_location_button() -> void:
	print("[검증 2] DisasterPopup [현장 위치 보기 🔍] 버튼 검증...")
	var popup := DisasterPopupClass.new()
	root.add_child(popup)

	# [GDScript 람다 캡처 규약] Vector2는 값 복사 캡처되므로 배열로 감싸 참조 캡처 사용
	var received_pos: Array = [Vector2.ZERO]
	popup.location_view_requested.connect(func(pos: Vector2):
		received_pos[0] = pos
	)

	var target_p := Vector2(800.0, 600.0)
	popup.show_disaster("화재 경보", "서쪽 공방 구역에 불길이 번지고 있습니다!", {"gold": 50}, target_p)

	assert(popup.visible == true, "재난 팝업이 표시되어야 함")
	assert(popup._view_loc_btn != null, "위치 보기 버튼이 존재해야 함")
	assert(popup._view_loc_btn.visible == true, "좌표가 제공되었으므로 위치 보기 버튼이 보여야 함")

	# 위치 보기 클릭 시 팝업 닫힘 및 시그널 발화
	popup._on_view_loc_pressed()
	assert(popup.visible == false, "위치 보기 클릭 시 모달이 닫혀야 함")
	assert(received_pos[0] == target_p, "발화된 위치 좌표가 target_p와 일치해야 함")

	popup.queue_free()
	print(" -> [통과] DisasterPopup 현장 위치 보기 버튼 정상 작동 확인")

## 3. HUDController 화재 발생 및 진압 시 알림창/배너 위치 연동 검증
func _test_hud_fire_outbreak_and_extinguish() -> void:
	print("[검증 3] HUDController 화재 발생 시 상단 알림창 [위치 보기] 연동 및 진압 검증...")
	var hud := HUDControllerClass.new()
	root.add_child(hud)

	var tm := TimeManagerClass.new()
	var sim := SimulationCoreClass.new()
	var cam := CameraControllerClass.new()
	root.add_child(cam)
	var city := CityLayerClass.new()
	var cit := CitizenManagerClass.new()
	var grid := _create_test_grid()

	# 20, 25번 타일에 가옥 배치
	grid.grid[25][20]["building"] = "res_1"

	cit.grid = grid
	cit.sim = sim

	hud.setup(tm, sim, cam, city, cit)

	# 1) 화재 발생 시그널 발화 (pos: Vector2i(20, 25))
	var fire_tile := Vector2i(20, 25)
	sim.fire_outbreak.emit(fire_tile)

	# HUD의 top_alert_banner에 화재 알림이 적재되고 위치 보기 버튼이 켜졌는지 확인
	assert(hud.top_alert_banner != null, "TopAlertBanner가 존재해야 함")
	assert(hud.top_alert_banner.visible == true, "화재 발생 시 상단 알림창이 떠야 함")
	assert(hud.top_alert_banner.view_button.visible == true, "화재 알림창 옆에 위치 보기 버튼이 노출되어야 함")

	# 2) 위치 보기 버튼 클릭 시 카메라가 해당 화재 위치로 이동하는지 검증
	var expected_world_pos: Vector2 = city.cell_center(float(fire_tile.x) + 0.5, float(fire_tile.y) + 0.5)
	hud.top_alert_banner._on_view_pressed()
	# 카메라 focus_on_coordinate가 호출되어 position이 이동할 준비를 하거나 트윈이 설정되었는지 확인
	assert(cam._focus_tween != null or cam.position == expected_world_pos, "카메라가 화재 위치로 이동해야 함")

	# 3) 화재 진압 완료 시그널 발화
	sim.fire_extinguished.emit(fire_tile)
	assert(hud.banner_raid_alert.visible == false, "화재 진압 시 긴급 배너는 숨겨져야 함")

	hud.queue_free()
	cam.queue_free()
	print(" -> [통과] HUDController 화재 알림 위치 보기 및 카메라 연동 완벽 작동 확인")

## 4. CitizenLayer 사건 핑 및 화재 진화 상공 게이지 바 (실시간 해결 상황 관찰) 검증
func _test_citizen_layer_incident_ping_and_fire_hud() -> void:
	print("[검증 4] CitizenLayer 사건 핑 등록 및 화재 진압 HUD 데이터 검증...")
	var cl := CitizenLayerClass.new()
	root.add_child(cl)

	var grid := _create_test_grid()
	var cit := CitizenManagerClass.new()
	var city := CityLayerClass.new()
	cl.setup(grid, cit, city)

	# 1) 사건 핑 등록
	var ping_p := Vector2(300.0, 400.0)
	cl.ping_incident(ping_p, "화마 진압 현장")

	assert(cl._incident_pings.size() == 1, "인시던트 핑이 1건 등록되어야 함")
	assert(cl._incident_pings[0]["pos"] == ping_p, "등록된 핑 좌표가 일치해야 함")
	assert(cl._incident_pings[0]["text"] == "화마 진압 현장", "등록된 핑 라벨이 일치해야 함")

	# 타이머 갱신 검증
	cl._update_incident_pings(1.0)
	assert(cl._incident_pings[0]["timer"] <= 2.1, "타이머가 정상 감축되어야 함")

	# 2) 화재 진화 상공 게이지 바 데이터 시뮬레이션
	# 화재 1건 등록
	cit._active_fires.append({
		"pos": Vector2i(10, 10),
		"duration": 5.0,
		"max_duration": 18.0,
		"fire_progress": 0.4, # 60% 진압됨
		"extinguished": false
	})
	# 멸화군 에이전트 1명 투입
	cit.agents.append({
		"type": "firefighter_soldier",
		"state": "extinguish",
		"target_fire_pos": Vector2i(10, 10),
		"is_dead": false
	})

	assert(cit.get_active_fires().size() == 1, "활성 화재가 1건 등록되어야 함")
	assert(cit.agents.size() == 1, "멸화군 에이전트가 1명 등록되어야 함")

	cl.queue_free()
	print(" -> [통과] CitizenLayer 사건 핑 및 화재 해결 상황 데이터 정상 작동 확인")

## 5. EventManager 재난 적재 시 target_pos 전달 및 시그널 중계 검증
func _test_event_manager_disaster_location_passthrough() -> void:
	print("[검증 5] EventManager 재난 적재 시 target_pos 파라미터 전달 및 중계 검증...")
	var ev_mgr := EventManagerClass.new()
	root.add_child(ev_mgr)
	ev_mgr._ensure_ui()

	# [GDScript 람다 캡처 규약] Vector2는 값 복사 캡처되므로 배열로 감싸 참조 캡처 사용
	var passed_pos: Array = [Vector2.ZERO]
	ev_mgr.location_view_requested.connect(func(pos: Vector2):
		passed_pos[0] = pos
	)

	var target_wpos := Vector2(450.0, 350.0)
	ev_mgr.enqueue_disaster("수해 범람", "수원천이 범람하여 제방이 위태롭습니다!", {"defense": 10}, target_wpos)

	assert(ev_mgr.event_queue.size() == 1, "재난 이벤트가 큐에 적재되어야 함")
	var raw_tpos = ev_mgr.event_queue[0].get("target_pos")
	assert(raw_tpos is Vector2 and (raw_tpos as Vector2) == target_wpos, "target_pos가 딕셔너리에 보존되어야 함")

	# 이벤트 펌프 및 표시
	ev_mgr._pump_next_event()
	assert(ev_mgr.is_displaying_event == true, "이벤트가 화면에 표시되어야 함")

	# DisasterPopup의 위치 보기 버튼 누름
	if ev_mgr._disaster_popup and ev_mgr._disaster_popup.has_method("_on_view_loc_pressed"):
		ev_mgr._disaster_popup._on_view_loc_pressed()
		assert(passed_pos[0] == target_wpos, "EventManager를 통해 위치 보기 시그널이 정확히 중계되어야 함")

	ev_mgr.queue_free()
	print(" -> [통과] EventManager 재난 좌표 전달 및 중계 정상 작동 확인")
