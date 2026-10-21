extends SceneTree

const CourtSystem = preload("res://scripts/CourtSystem.gd")
const SimulationCore = preload("res://scripts/SimulationCore.gd")
const ScholarDiscoveryPopup = preload("res://scripts/ScholarDiscoveryPopup.gd")

func _init() -> void:
	print("=== [테스트 시작] ScholarDiscoveryPopup 및 CourtSystem.hire_scholar 연동 무결성 검증 ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var root_node := Node.new()
	root.add_child(root_node)

	var sim := SimulationCore.new()
	sim.gold = 10000 # 충분한 국고
	sim.authority = 50
	sim.academic = 30
	root_node.add_child(sim)

	var court := CourtSystem.new()
	root_node.add_child(court)
	court.setup(sim)

	# [검증 1] CourtSystem.has_method("hire_scholar") 검증
	print("[검증 1] CourtSystem.hire_scholar 메서드 존재 및 호출 검증...")
	assert(court.has_method("hire_scholar"), "CourtSystem에 hire_scholar 메서드가 반드시 존재해야 함")
	assert(court.has_method("hire_candidate"), "CourtSystem에 hire_candidate 메서드가 존재해야 함")

	var hire_msg: String = court.hire_scholar("jeong")
	assert(hire_msg != "", "hire_scholar('jeong') 반환 메시지가 비어있지 않아야 함: " + hire_msg)
	assert(sim.retainers.get("jeong_yakyong", false) == true, "정약용(jeong) 등용 시 retainers['jeong_yakyong']이 true여야 함")
	print("  -> CourtSystem.hire_scholar 직접 호출 성공: ", hire_msg)

	# [검증 2] ScholarDiscoveryPopup UI를 통한 등용 검증
	print("[검증 2] ScholarDiscoveryPopup._on_hire_pressed 호출 및 시그널 방출 검증...")
	var popup := ScholarDiscoveryPopup.new()
	root_node.add_child(popup)

	var signal_received: Array[String] = []
	popup.scholar_hired.connect(func(sid: String):
		signal_received.append(sid)
	)

	# 채제공 후보 표시
	var cand_chae := {
		"id": "chae",
		"name": "번암 채제공",
		"role": "남인 영수",
		"salary": 300,
		"praise": "조정의 큰 기둥이옵니다."
	}
	popup.show_candidate(cand_chae, court, sim)
	assert(popup.visible == true, "show_candidate 후 popup.visible은 true여야 함")

	# 등용 버튼 클릭 이벤트 발화
	popup._on_hire_pressed()

	assert(popup.visible == false, "등용 후 팝업이 닫혀야 함")
	assert(signal_received.size() == 1 and signal_received[0] == "chae", "scholar_hired 시그널이 'chae'로 방출되어야 함")
	assert(sim.retainers.get("chae_jegong", false) == true, "채제공(chae) 등용 시 retainers['chae_jegong']이 true여야 함")
	print("  -> ScholarDiscoveryPopup 등용 동작 및 시그널 방출 성공!")

	# [검증 3] court == null, sim만 있을 때의 Fallback 검증
	print("[검증 3] court == null 일 때 sim_ref fallback 등용 검증...")
	var cand_park := {
		"id": "park",
		"name": "초정 박제가",
		"role": "북학파"
	}
	popup.show_candidate(cand_park, null, sim)
	popup._on_hire_pressed()
	assert(sim.retainers.get("park_jega", false) == true, "court == null 일 때도 retainers['park_jega']이 true여야 함")
	print("  -> court == null fallback 등용 검증 성공!")

	# [검증 4] 장인 full key(kim_bau) 등용 매핑 호환성 검증
	print("[검증 4] 장인 식별자(kim_bau) 호환 등용 검증...")
	var msg_bau: String = court.hire_scholar("kim_bau")
	assert(sim.retainers.get("kim_bau", false) == true, "kim_bau 키로 hire_scholar 호출 시 등용 성공해야 함")
	print("  -> 장인 식별자 호환 등용 성공: ", msg_bau)

	root_node.queue_free()
	print("=== [테스트 완료] 모든 ScholarDiscoveryPopup 및 hire_scholar 연동 검증 100% 통과! ===")
	quit(0)
