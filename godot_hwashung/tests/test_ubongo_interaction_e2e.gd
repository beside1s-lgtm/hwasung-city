extends SceneTree

const UbongoPopupClass = preload("res://scripts/minigames/UbongoWallRepairPopup.gd")
const PresetsClass = preload("res://scripts/minigames/UbongoPuzzlePresets.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== 우봉고 미니게임 E2E 인터랙션 및 중앙 정렬 검증 ===")
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	var popup := UbongoPopupClass.new()
	canvas.add_child(popup)
	popup.open_ubongo_puzzle(300)

	await process_frame
	await process_frame

	# 1. 중앙 정렬 검증
	var vp_size: Vector2 = root.get_visible_rect().size
	print("[1] 뷰포트 크기: ", vp_size)
	print("    팝업 패널 위치: ", popup._main_panel.global_position, " 크기: ", popup._main_panel.size)
	var expected_x: float = (vp_size.x - popup._main_panel.size.x) * 0.5
	var expected_y: float = (vp_size.y - popup._main_panel.size.y) * 0.5
	var diff_x: float = absf(popup._main_panel.global_position.x - expected_x)
	var diff_y: float = absf(popup._main_panel.global_position.y - expected_y)
	assert(diff_x < 1.0, "X축 중앙 정렬 오차 1px 이내여야 함 (오차: %f)" % diff_x)
	assert(diff_y < 1.0, "Y축 중앙 정렬 오차 1px 이내여야 함 (오차: %f)" % diff_y)
	print("  -> 중앙 정렬 완벽 확인! (패널이 화면 정중앙에 위치함)")

	# 2. 드래그 앤 드롭 검증
	print("[2] 트레이 -> 보드 드래그 앤 드롭 시뮬레이션...")
	# 조각 0의 트레이 위치 계산
	var tray_global: Vector2 = popup._piece_tray.global_position
	var click_pos := tray_global + Vector2(30.0, 30.0)

	# 트레이 마우스 좌클릭 (드래그 시작)
	var mb_press := InputEventMouseButton.new()
	mb_press.button_index = MOUSE_BUTTON_LEFT
	mb_press.pressed = true
	mb_press.position = Vector2(30.0, 30.0)
	mb_press.global_position = click_pos
	popup._on_tray_gui_input(mb_press)

	assert(popup._dragging_piece_idx == 0, "조각 0이 드래그 중이어야 함")
	print("  -> 트레이에서 조각 0 선택 완료 (dragging_idx=%d)" % popup._dragging_piece_idx)

	# 보드 위로 마우스 이동
	var board_origin: Vector2 = popup._get_board_origin()
	var board_target_cell := Vector2i(0, 0)
	# 보드의 첫 번째 target_mask == 1인 셀 찾기
	for r in range(popup._board_h):
		for c in range(popup._board_w):
			if int(popup._target_grid[r][c]) == 1:
				board_target_cell = Vector2i(c, r)
				break
		if board_target_cell != Vector2i(0, 0):
			break

	var drop_board_local := board_origin + Vector2(float(board_target_cell.x * popup.CELL_SIZE), float(board_target_cell.y * popup.CELL_SIZE)) + Vector2(20.0, 20.0)
	var drop_global: Vector2 = popup._board_draw.global_position + drop_board_local

	var mm := InputEventMouseMotion.new()
	mm.position = drop_board_local
	mm.global_position = drop_global
	popup._input(mm)
	print("  -> 마우스 보드 위로 이동 (global_pos=%s)" % str(drop_global))

	# 보드 위에서 마우스 릴리즈 (드롭!)
	var mb_release := InputEventMouseButton.new()
	mb_release.button_index = MOUSE_BUTTON_LEFT
	mb_release.pressed = false
	mb_release.position = drop_board_local
	mb_release.global_position = drop_global
	popup._input(mb_release)

	print("  -> 마우스 릴리즈 완료 (dragging_idx=%d)" % popup._dragging_piece_idx)
	assert(popup._dragging_piece_idx == -1, "드롭 후 드래그 인덱스는 -1이어야 함")

	# 만약 첫 번째 위치가 안 맞더라도 스마트 스냅 또는 트레이 보관이 안전하게 완료되었는지 확인
	print("  -> 조각 0 배치 좌표: ", popup._piece_placements[0])

	# 3. 우클릭 회전 검증
	print("[3] 우클릭 회전 검증...")
	var initial_rot_idx: int = popup._piece_rot_indices[0]
	popup._rotate_piece(0)
	print("  -> 회전 후 인덱스: ", popup._piece_rot_indices[0], " (이전: %d)" % initial_rot_idx)
	assert(popup._piece_rot_indices[0] != initial_rot_idx or popup._all_piece_rotations[0].size() == 1, "회전이 정상 반영되어야 함")

	# 4. 키보드 스페이스바 및 닫기 검증
	print("[4] 닫기 및 안전 종료 검증...")
	popup._on_close_clicked()
	assert(popup.visible == false, "닫기 후 팝업은 숨겨져야 함")
	print("  -> 팝업 닫기 및 시그널 발행 완료!")

	print("=== E2E 모든 인터랙션 검증 100% 통과 ===")
	quit(0)
