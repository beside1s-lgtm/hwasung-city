extends SceneTree

func _init() -> void:
	print("==================================================")
	print("[TEST] Procession & Drill Visual Upgrade Verification")
	print("==================================================")

	var all_ok := true

	# 1. ProcessionUnitArt 아틀라스 수동 초기화 및 행 등록
	ProcessionUnitArt._init_atlas()

	var test_roles: Array[Dictionary] = [
		{"role": "jeongjo_king", "drill": false},
		{"role": "jeongjo_king", "drill": true},
		{"role": "jeongjo_archery", "drill": true},
		{"role": "posu", "drill": true},
		{"role": "salsu", "drill": true},
		{"role": "sasu", "drill": true},
		{"role": "gipo", "drill": true}
	]

	for tr: Dictionary in test_roles:
		var r: String = String(tr["role"])
		var is_d: bool = bool(tr["drill"])
		ProcessionUnitArt._build_role_row(r, is_d)

	# 2. 아틀라스 이미지 크기 및 텍스처 무결성 검증
	if ProcessionUnitArt._img == null:
		print("FAIL: ProcessionUnitArt atlas image is null")
		all_ok = false
	else:
		var img_w: int = ProcessionUnitArt._img.get_width()
		var img_h: int = ProcessionUnitArt._img.get_height()
		print("Atlas Dimensions: %dx%d (Expected: 1024x2688)" % [img_w, img_h])
		if img_w != 1024 or img_h != 2688:
			print("FAIL: Atlas dimension mismatch! Expected 1024x2688, got %dx%d" % [img_w, img_h])
			all_ok = false
		else:
			print("PASS: Atlas dimension is correct (1024x2688)")

	# 3. 정조 대왕 전용 규격 상수 검증
	if ProcessionUnitArt.W_KING_HORSE != 56 or ProcessionUnitArt.H_KING_HORSE != 56:
		print("FAIL: King horse size is not 56x56")
		all_ok = false
	else:
		print("PASS: King horse size is 56x56 (W_KING_HORSE=56, H_KING_HORSE=56)")

	if ProcessionUnitArt.W_KING_HUMAN != 32 or ProcessionUnitArt.H_KING_HUMAN != 44:
		print("FAIL: King human drill size is not 32x44")
		all_ok = false
	else:
		print("PASS: King human drill size is 32x44 (W_KING_HUMAN=32, H_KING_HUMAN=44)")

	# 4. 등록된 아틀라스 키 및 비어있지 않은 픽셀 검증
	for tr: Dictionary in test_roles:
		var r: String = String(tr["role"])
		var is_d: bool = bool(tr["drill"])
		var key: String = "%s|%s" % [r, "drill" if is_d else "march"]
		if not ProcessionUnitArt._rows.has(key):
			print("FAIL: Missing atlas row for key: %s" % key)
			all_ok = false
		else:
			var row_idx: int = int(ProcessionUnitArt._rows[key])
			# 아틀라스 행의 첫 번째 프레임 중심 픽셀에 색상이 채워져 있는지 확인
			var sample_x: int = 16
			var sample_y: int = row_idx * ProcessionUnitArt.H_CELL + 20
			var pixel_found: bool = false
			for sy in range(row_idx * ProcessionUnitArt.H_CELL, (row_idx + 1) * ProcessionUnitArt.H_CELL):
				for sx in range(0, 32):
					if ProcessionUnitArt._img.get_pixel(sx, sy).a > 0.1:
						pixel_found = true
						break
				if pixel_found: break

			if pixel_found:
				print("PASS: %s row %d successfully painted with solid pixels" % [key, row_idx])
			else:
				print("FAIL: %s row %d is completely empty/transparent!" % [key, row_idx])
				all_ok = false

	# 5. RoyalProcessionManager 인스턴스화 및 세팅 확인
	var rpm := RoyalProcessionManager.new()
	rpm.haenggung_pos = Vector2i(20, 20)
	rpm.naknam_pos = Vector2i(18, 20)
	rpm.sinpungru_pos = Vector2i(23, 20)
	rpm.seojangdae_pos = Vector2i(10, 15)
	rpm.yeonmudae_pos = Vector2i(35, 15)
	rpm.phase_timer = 2.5
	if rpm.haenggung_pos.x == 20:
		print("PASS: RoyalProcessionManager instantiated successfully")

	rpm.free()

	if all_ok:
		print("==================================================")
		print("ALL CHECKS PASSED: Procession & Drill Upgrade Complete!")
		print("==================================================")
		quit(0)
	else:
		print("==================================================")
		print("FAIL: Some checks failed!")
		print("==================================================")
		quit(1)
