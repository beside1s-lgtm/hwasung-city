extends SceneTree

func _init() -> void:
	print("=== [TEST] 우물(Well) 무손실 PNG 및 지형 투명성 검증 시작 ===")
	call_deferred("_run_test")

func _run_test() -> void:
	# 1. well.png 파일 검증
	var well_path := "res://assets/sprites/buildings/well.png"
	var global_well_path: String = ProjectSettings.globalize_path(well_path)
	if not FileAccess.file_exists(global_well_path) and not FileAccess.file_exists(well_path):
		printerr("[FAIL] well.png 파일이 디스크에 존재하지 않음!")
		quit(1)
		return

	var well_img := Image.load_from_file(global_well_path if FileAccess.file_exists(global_well_path) else well_path)
	if well_img == null or well_img.is_empty():
		printerr("[FAIL] well.png 이미지 로드 실패 또는 비어있음!")
		quit(1)
		return

	print("[PASS] well.png 로드 성공: 해상도 = ", well_img.get_size())
	if well_img.get_size() != Vector2i(64, 64):
		printerr("[FAIL] well.png 규격 불일치 (기대값: 64x64, 실제값: ", well_img.get_size(), ")")
		quit(1)
		return

	# 배경이 투명한지(0,0 픽셀 알파 0) 확인
	var corner_col: Color = well_img.get_pixel(0, 0)
	print("[INFO] well.png 좌상단 모서리 색상: ", corner_col)
	if corner_col.a != 0.0:
		printerr("[FAIL] well.png 모서리가 투명하지 않음 (알파값: ", corner_col.a, ")")
		quit(1)
		return

	# 중앙 우물 영역에 유효한 픽셀(불투명 픽셀)이 존재하는지 확인
	var opaque_pixels: int = 0
	for y: int in range(well_img.get_height()):
		for x: int in range(well_img.get_width()):
			if well_img.get_pixel(x, y).a > 0.1:
				opaque_pixels += 1

	print("[INFO] well.png 유효 불투명 픽셀 수: ", opaque_pixels)
	if opaque_pixels < 50:
		printerr("[FAIL] well.png 유효 픽셀 수 부족 (내용 없음): ", opaque_pixels)
		quit(1)
		return

	# 2. edge_*.png 지형 오버레이 투명화 검증 (사각 아티팩트 방지)
	for edge_name: String in ["edge_road_dust", "edge_stream_pebbles", "edge_wall_rock"]:
		var edge_path: String = "res://assets/sprites/terrain/%s.png" % edge_name
		var gp: String = ProjectSettings.globalize_path(edge_path)
		if FileAccess.file_exists(gp) or FileAccess.file_exists(edge_path):
			var e_img := Image.load_from_file(gp if FileAccess.file_exists(gp) else edge_path)
			var non_transparent: int = 0
			for y: int in range(e_img.get_height()):
				for x: int in range(e_img.get_width()):
					if e_img.get_pixel(x, y).a > 0.0:
						non_transparent += 1
			print("[INFO] 지형 오버레이 ", edge_name, " 비투명 픽셀 수: ", non_transparent)
			if non_transparent > 0:
				printerr("[FAIL] ", edge_name, "에 불투명 픽셀이 남아 있어 사각 아티팩트 유발 위험!")
				quit(1)
				return
		print("[PASS] ", edge_name, " 완전 투명화 확인")

	print("=== [TEST SUCCESS] 우물 디자인 복원 및 사각 아티팩트 제거 검증 완료 ===")
	quit(0)
