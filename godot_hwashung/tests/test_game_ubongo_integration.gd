extends SceneTree

func _init() -> void:
	print("=== [실제 게임 런타임 통합 검증 시작] ===")
	call_deferred("_run_test")

func _run_test() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)

	await process_frame
	await process_frame
	await process_frame

	print("[1] Main 씬 및 서브시스템 로드 확인:")
	assert(main.ubongo_wall_repair != null, "main.ubongo_wall_repair 인스턴스 존재 확인")
	assert(main.panels.ubongo_wall_repair != null, "panels.ubongo_wall_repair 연결 확인")
	print("  -> Main.gd와 PanelController 간 ubongo_wall_repair 연동 성공!")

	print("[2] 성곽 보수 모달 열기 시뮬레이션:")
	main.panels.open_action_modal("wall_repair")
	await process_frame
	await process_frame

	assert(main.panels._modal.visible == true, "성곽 보수 패널 오픈 확인")
	print("  -> 성곽 보수 모달(3-Track) 정상 오픈 확인!")

	print("[3] 성곽 보수 창에서 [직접 보수] 미니게임 진입 시뮬레이션:")
	# 방호력 피해 및 금화 설정
	main.simulation_core.gold = 50000
	main.simulation_core.rice = 50000
	CityStats.defense_damage_taken = 200
	main.simulation_core.defense_fatigue = 200
	var dmg_before: int = CityStats.get_defense_damage_taken()
	print("  -> 초기 피해도 설정: %d" % dmg_before)

	# 직접 보수 미니게임 호출
	var base_restore: int = 300
	main.ubongo_wall_repair.open_ubongo_puzzle(base_restore, main.time_manager)
	await process_frame
	await process_frame

	assert(main.ubongo_wall_repair.visible == true, "우봉고 미니게임 모달 가시화 확인")
	assert(main.ubongo_wall_repair._round_active == true, "1라운드 활성화 확인")
	assert(main.ubongo_wall_repair._board_w >= 2, "보드 너비 정상 확인: %d" % main.ubongo_wall_repair._board_w)
	print("  -> 우봉고 팝업 정상 가시화 및 1라운드(너비 %d) 가동 확인!" % main.ubongo_wall_repair._board_w)

	print("[4] 스페이스바 완성 확인 및 라운드 클리어 시뮬레이션:")
	# 1라운드 성공
	main.ubongo_wall_repair._on_round_success()
	assert(main.ubongo_wall_repair._result_center.visible == true, "라운드 1 결과창 표시 확인")
	print("  -> 1라운드 성공 오버레이 정상 팝업 확인!")

	# [다음 라운드] 버튼 클릭
	main.ubongo_wall_repair._on_result_btn_pressed()
	assert(main.ubongo_wall_repair._current_round == 1, "2라운드 진입 확인")
	assert(main.ubongo_wall_repair._round_active == true, "2라운드 진행 상태 확인")
	print("  -> 2라운드(4조각) 진입 성공!")

	# 2라운드 성공
	main.ubongo_wall_repair._on_round_success()
	main.ubongo_wall_repair._on_result_btn_pressed()
	assert(main.ubongo_wall_repair._current_round == 2, "3라운드 진입 확인")
	print("  -> 3라운드(5조각) 진입 성공!")

	# 3라운드 성공 (3/3 만점)
	main.ubongo_wall_repair._on_round_success()
	main.ubongo_wall_repair._on_result_btn_pressed()

	# 최종 결산 확인
	assert(main.ubongo_wall_repair._result_btn.text == "보수 완료 및 복귀", "최종 확인 버튼 텍스트 확인")
	print("  -> 3/3 만점 최종 결산 확인 완료!")

	dmg_before = CityStats.get_defense_damage_taken()
	# 보수 완료 및 복귀 버튼 클릭
	main.ubongo_wall_repair._on_finish_confirmed()
	await process_frame
	await process_frame

	var dmg_after: int = CityStats.get_defense_damage_taken()
	print("  -> 보수 적용 결과: 피해도 %d -> %d (방호력 대폭 회복)" % [dmg_before, dmg_after])
	assert(dmg_after < dmg_before, "방호력 피해도가 정상적으로 복구되어야 함")
	assert(main.ubongo_wall_repair.visible == false, "미니게임 팝업 닫힘 확인")

	print("=== [실제 게임 런타임 통합 검증 100% 통과!] ===")
	quit(0)
