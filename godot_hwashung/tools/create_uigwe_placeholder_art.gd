extends SceneTree

## 의궤 뷰어용 고증풍 기본 일러스트/표지 텍스처 생성기
func _init() -> void:
	print("=== 의궤 텍스처 생성 시작 ===")
	_generate_wonhaeng_image()
	_generate_hwaseong_image()
	print("=== 의궤 텍스처 생성 완료 ===")
	quit(0)

func _generate_wonhaeng_image() -> void:
	var w: int = 640
	var h: int = 440
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	# 비단/한지 고풍스러운 황갈색 바탕 (#E8D8B0)
	img.fill(Color("e8d8b0"))
	
	# 외곽 비단 자수 테두리 (짙은 자주색/남색 #2A1B28)
	var border_c := Color("3b232e")
	var gold_c := Color("c59b27")
	
	for y in range(h):
		for x in range(w):
			# 비단 장정 좌측 띠
			if x < 40:
				img.set_pixel(x, y, border_c)
			elif x < 44 or x > w - 16 or y < 16 or y > h - 16:
				img.set_pixel(x, y, gold_c)
			elif x < 48 or x > w - 20 or y < 20 or y > h - 20:
				img.set_pixel(x, y, border_c)
			
			# 놋쇠 정(못) 4군데
			if x >= 18 and x <= 26:
				if (y >= 40 and y <= 48) or (y >= 140 and y <= 148) or (y >= 280 and y <= 288) or (y >= 380 and y <= 388):
					img.set_pixel(x, y, gold_c)

	# 중앙 내지 영역 미세 음영
	for y in range(40, h - 40):
		for x in range(80, w - 40):
			var cur := img.get_pixel(x, y)
			# 미세 한지 질감 노이즈
			var n: float = ((x * 13 + y * 17) % 19) * 0.003
			img.set_pixel(x, y, Color(cur.r - n, cur.g - n, cur.b - n, 1.0))
			
			# 붉은 제목 제첨 테두리
			if x >= 120 and x <= 220 and y >= 60 and y <= 380:
				if x == 120 or x == 220 or y == 60 or y == 380 or x == 121 or x == 219 or y == 61 or y == 379:
					img.set_pixel(x, y, Color("8f1d1d"))
				elif (x > 122 and x < 218 and y > 62 and y < 378):
					img.set_pixel(x, y, Color("fcf9f2"))

	var path := "res://assets/images/uigwe_wonhaeng.png"
	img.save_png(ProjectSettings.globalize_path(path))
	print("저장 완료: ", path)

func _generate_hwaseong_image() -> void:
	var w: int = 640
	var h: int = 440
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	
	# 화성성역의궤 고풍스러운 옥색/초록 비단 바탕 (#D8E2DC)
	img.fill(Color("d2dcd6"))
	
	# 외곽 짙은 녹색/감색 비단 장정 (#1E302D)
	var border_c := Color("1b2a26")
	var gold_c := Color("cba135")
	
	for y in range(h):
		for x in range(w):
			if x < 40:
				img.set_pixel(x, y, border_c)
			elif x < 44 or x > w - 16 or y < 16 or y > h - 16:
				img.set_pixel(x, y, gold_c)
			elif x < 48 or x > w - 20 or y < 20 or y > h - 20:
				img.set_pixel(x, y, border_c)
			
			if x >= 18 and x <= 26:
				if (y >= 40 and y <= 48) or (y >= 140 and y <= 148) or (y >= 280 and y <= 288) or (y >= 380 and y <= 388):
					img.set_pixel(x, y, gold_c)

	for y in range(40, h - 40):
		for x in range(80, w - 40):
			var cur := img.get_pixel(x, y)
			var n: float = ((x * 19 + y * 23) % 23) * 0.003
			img.set_pixel(x, y, Color(cur.r - n, cur.g - n, cur.b - n, 1.0))
			
			# 청색 제목 제첨 테두리
			if x >= 120 and x <= 220 and y >= 60 and y <= 380:
				if x == 120 or x == 220 or y == 60 or y == 380 or x == 121 or x == 219 or y == 61 or y == 379:
					img.set_pixel(x, y, Color("1d3557"))
				elif (x > 122 and x < 218 and y > 62 and y < 378):
					img.set_pixel(x, y, Color("fcf9f2"))

	var path := "res://assets/images/uigwe_hwaseong.png"
	img.save_png(ProjectSettings.globalize_path(path))
	print("저장 완료: ", path)
