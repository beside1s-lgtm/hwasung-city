extends SceneTree

func _init() -> void:
	print("--- 타이틀 배경 이미지 하단 중복 아이콘 클린업 시작 ---")
	var img := Image.load_from_file("res://assets/title_screen.original.jpg")
	if img == null or img.is_empty():
		print("이미지 로드 실패!")
		quit(1)
		return

	var w := img.get_width()
	var h := img.get_height()
	print("이미지 해상도: ", w, "x", h)

	# 1. 좌하단 영역 클린업 (톱니바퀴 아이콘 제거)
	# 아이콘 위치: x: 18 ~ 70, y: 492 ~ 542
	# 바로 위쪽(y: 440~490)의 기와 지붕 텍스처 및 우측(x: 72~120)의 처마 텍스처를 샘플링하여 자연스럽게 블렌딩
	for y in range(490, 544):
		for x in range(16, 72):
			# 가장자리로부터의 거리 비율
			var edge_dist_x: float = minf(float(x - 16), float(72 - x)) / 28.0
			var edge_dist_y: float = minf(float(y - 490), float(544 - y)) / 27.0
			var border_weight: float = clampf(minf(edge_dist_x, edge_dist_y), 0.0, 1.0)

			# 상단 기와 텍스처 샘플링 (y - 50 위치)
			var sample_y: int = y - 48
			var src_col_top: Color = img.get_pixel(x, sample_y)

			# 우측 텍스처 샘플링 (x + 55 위치)
			var sample_x: int = clampi(x + 56, 0, w - 1)
			var src_col_right: Color = img.get_pixel(sample_x, y)

			# 혼합
			var blend_col := src_col_top.lerp(src_col_right, 0.4)

			# 테두리 페더링 (외곽 원본과 부드러운 연결)
			var orig_col: Color = img.get_pixel(x, y)
			var final_col := orig_col.lerp(blend_col, border_weight)
			img.set_pixel(x, y, final_col)

	# 2. 우하단 영역 클린업 (스피커 아이콘 제거)
	# 아이콘 위치: x: 950 ~ 1006, y: 492 ~ 542
	# 좌측(x: 894~950, y: 492~542)의 관복 및 성벽 텍스처를 자연스럽게 확장 블렌딩
	for y in range(490, 544):
		for x in range(948, 1008):
			var edge_dist_x: float = minf(float(x - 948), float(1008 - x)) / 30.0
			var edge_dist_y: float = minf(float(y - 490), float(544 - y)) / 27.0
			var border_weight: float = clampf(minf(edge_dist_x, edge_dist_y), 0.0, 1.0)

			# 좌측 텍스처 샘플링 (x - 56 위치)
			var sample_x: int = clampi(x - 56, 0, w - 1)
			var src_col_left: Color = img.get_pixel(sample_x, y)

			# 상단 텍스처 샘플링 (y - 48 위치)
			var sample_y: int = clampi(y - 48, 0, h - 1)
			var src_col_top: Color = img.get_pixel(x, sample_y)

			var blend_col := src_col_left.lerp(src_col_top, 0.35)

			var orig_col: Color = img.get_pixel(x, y)
			var final_col := orig_col.lerp(blend_col, border_weight)
			img.set_pixel(x, y, final_col)

	# 3. 미세 스무딩 필터 (3x3 박스 블러)를 해당 영역에 적용하여 노이즈 제거
	var smoothed := img.duplicate() as Image
	for y in range(492, 542):
		for x in range(18, 70):
			var avg := Color(0, 0, 0, 0)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					avg += img.get_pixel(x + dx, y + dy)
			smoothed.set_pixel(x, y, avg / 9.0)

	for y in range(492, 542):
		for x in range(950, 1006):
			var avg := Color(0, 0, 0, 0)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					avg += img.get_pixel(x + dx, y + dy)
			smoothed.set_pixel(x, y, avg / 9.0)

	# 4. 저장 (JPG 고화질 0.95)
	var err := smoothed.save_jpg("res://assets/title_screen.jpg", 0.95)
	if err == OK:
		print("[성공] assets/title_screen.jpg 클린업 저장 완료!")
	else:
		print("[오류] 저장 실패: ", err)

	quit(0)
