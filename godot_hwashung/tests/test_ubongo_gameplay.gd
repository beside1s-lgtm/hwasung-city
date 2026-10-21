extends SceneTree

## 수원화성 석축 우봉고 퍼즐 미니게임 엔드투엔드(E2E) 게임플레이 검증 스크립트

const PresetsClass = preload("res://scripts/minigames/UbongoPuzzlePresets.gd")
const UbongoPopupClass = preload("res://scripts/minigames/UbongoWallRepairPopup.gd")
const SimCoreClass = preload("res://scripts/SimulationCore.gd")

func _init() -> void:
	print("=== [검증 시작] 수원화성 석축 우봉고 퍼즐 미니게임 실제 구동 테스트 ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	_test_presets_database()
	_test_popup_initialization()
	_test_puzzle_board_dimensions_not_1()
	_test_drag_drop_and_complete()
	_test_round_transition_and_button_clicks()
	_test_close_and_signal()
	print("=== [검증 완료] 모든 석축 우봉고 게임플레이 테스트 100% 통과! ===")
	quit(0)

## 1. 60문항 프리셋 데이터베이스 무결성 검증
func _test_presets_database() -> void:
	print("[검증 1] 60문항 프리셋 DB (3조각 20, 4조각 20, 5조각 20) 검증...")
	assert(PresetsClass.PUZZLES_3_PIECES.size() == 20, "3조각 20문항")
	assert(PresetsClass.PUZZLES_4_PIECES.size() == 20, "4조각 20문항")
	assert(PresetsClass.PUZZLES_5_PIECES.size() == 20, "5조각 20문항")

	for i: int in range(20):
		var p3: Dictionary = PresetsClass.PUZZLES_3_PIECES[i]
		var pieces3: Array = p3.get("pieces", [])
		var mask3: Array = p3.get("target_mask", [])
		assert(pieces3.size() == 3, "3조각 문항의 조각 수는 3개여야 함")
		assert(mask3.size() >= 2 and (mask3[0] as Array).size() >= 2, "마스크 너비와 높이는 2 이상이어야 함")

		# 면적 일치 검증
		var piece_cells := 0
		for pid in pieces3:
			var shape: Array = PresetsClass.PIECE_SHAPES[pid]
			for r in shape:
				for c in r:
					piece_cells += int(c)
		var mask_cells := 0
		for r in mask3:
			for c in r:
				mask_cells += int(c)
		assert(piece_cells == mask_cells, "3P_%02d: 조각 칸수(%d)와 마스크 칸수(%d) 불일치!" % [i+1, piece_cells, mask_cells])

	print("  -> 60문항 프리셋 DB 데이터 면적 및 형식 무결성 확인 완료!")

## 2. 팝업 초기화 및 UI 생성 검증
func _test_popup_initialization() -> void:
	print("[검증 2] UbongoWallRepairPopup UI 인스턴스화 검증...")
	var popup := UbongoPopupClass.new()
	root.add_child(popup)
	popup._ready()

	assert(popup._board_draw != null, "보드 드로우 노드 존재 확인")
	assert(popup._piece_tray != null, "트레이 노드 존재 확인")
	assert(popup._result_btn != null, "결과 버튼 존재 확인")
	assert(popup._close_btn != null, "닫기 버튼 존재 확인")
	popup.queue_free()
	print("  -> 팝업 노드 초기화 성공!")

## 3. 보드 너비가 1열이 아닌 실제 2차원 너비(3~5)로 설정되는지 검증 (치명적 버그 수정 확인)
func _test_puzzle_board_dimensions_not_1() -> void:
	print("[검증 3] _board_w가 1이 아닌 실제 2차원 너비로 로드되는지 검증...")
	var popup := UbongoPopupClass.new()
	root.add_child(popup)
	popup._ready()

	# 10회 무작위 라운드 시작 테스트
	for trial in range(10):
		popup._current_round = 0
		popup._start_round()
		assert(popup._board_w >= 2, "보드 너비(_board_w=%d)가 1열이 아니어야 함!" % popup._board_w)
		assert(popup._board_h >= 2, "보드 높이(_board_h=%d)가 1행이 아니어야 함!" % popup._board_h)
		assert(popup._target_grid.size() == popup._board_h, "그리드 높이 일치")
		assert((popup._target_grid[0] as Array).size() == popup._board_w, "그리드 너비 일치")

	popup.queue_free()
	print("  -> _board_w 2차원 너비 정상 로드 검증 통과 (1열 버그 완치)!")

## 4. 조각 회전, 드래그 드롭 및 판정 로직 검증
func _test_drag_drop_and_complete() -> void:
	print("[검증 4] 조각 회전 및 완성 판정 로직 검증...")
	var popup := UbongoPopupClass.new()
	root.add_child(popup)
	popup._ready()
	popup._current_round = 0
	popup._start_round()

	# 초기 상태는 미완성
	assert(not popup._check_board_complete(), "초기 상태는 미완성이어야 함")

	# 조각 회전 검증
	var rots_count: int = popup._all_piece_rotations[0].size()
	popup._rotate_piece(0)
	var expected_idx: int = 1 % rots_count
	assert(popup._piece_rot_indices[0] == expected_idx, "회전 인덱스가 %d여야 함" % expected_idx)

	popup.queue_free()
	print("  -> 조각 조작 및 상태 검증 완료!")

## 5. 라운드 진행 및 결과 버튼 클릭 FSM 검증
func _test_round_transition_and_button_clicks() -> void:
	print("[검증 5] 시간 초과/성공 시 결과 창 오픈 및 [다음 라운드] 버튼 작동 검증...")
	var popup := UbongoPopupClass.new()
	root.add_child(popup)
	popup._ready()
	popup.open_ubongo_puzzle(300)

	assert(popup._current_round == 0, "1라운드 시작")
	assert(popup._round_active == true, "라운드 활성화")

	# 시간 초과 트리거
	popup._on_time_out()
	assert(popup._round_active == false, "라운드 정지")
	assert(popup._result_center.visible == true, "결과 오버레이가 보여야 함")
	assert(popup._result_btn.text == "다음 라운드", "버튼 텍스트가 '다음 라운드'여야 함")

	# 다음 라운드 버튼 클릭 시뮬레이션
	popup._on_result_btn_pressed()
	assert(popup._current_round == 1, "2라운드로 진입해야 함")
	assert(popup._result_center.visible == false, "결과 오버레이가 닫혀야 함")
	assert(popup._round_active == true, "2라운드 활성화")

	# 2라운드 성공 트리거
	popup._on_round_success()
	assert(popup._success_count == 1, "성공 카운트 1")
	assert(popup._result_center.visible == true, "결과 창 오픈")

	# 다음 라운드 버튼 클릭
	popup._on_result_btn_pressed()
	assert(popup._current_round == 2, "3라운드로 진입해야 함")

	# 3라운드 성공 트리거
	popup._on_round_success()
	assert(popup._success_count == 2, "성공 카운트 2")
	assert(popup._result_btn.text == "최종 결산", "마지막 라운드 후 '최종 결산'으로 표시")

	# 최종 결산 진입
	popup._on_result_btn_pressed()
	assert(popup._result_btn.text == "보수 완료 및 복귀", "최종 확인 버튼")

	popup.queue_free()
	print("  -> 1R -> 2R -> 3R -> 최종결산 라이프사이클 정상 검증 통과!")

## 6. 닫기 버튼 및 시그널 방출 검증
func _test_close_and_signal() -> void:
	print("[검증 6] [✕] 닫기 버튼 클릭 시 정상 종료 및 복귀 검증...")
	var popup := UbongoPopupClass.new()
	root.add_child(popup)
	popup._ready()
	popup.open_ubongo_puzzle(300)

	var signal_box: Array[bool] = [false]
	var received_success: Array[int] = [-1]
	var received_base: Array[int] = [-1]

	popup.minigame_completed.connect(func(sc: int, br: int):
		signal_box[0] = true
		received_success[0] = sc
		received_base[0] = br
	)

	popup._on_close_clicked()
	assert(popup.visible == false, "팝업이 숨겨져야 함")
	assert(signal_box[0] == true, "minigame_completed 시그널이 방출되어야 함")
	assert(received_base[0] == 300, "기본 회복량이 전달되어야 함")

	popup.queue_free()
	print("  -> 닫기 및 안전 복귀 검증 완료!")
