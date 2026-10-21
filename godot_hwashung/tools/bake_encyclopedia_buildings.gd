extends SceneTree

# bake_encyclopedia_buildings.gd
# 16대 화성 건축물의 2.5D 아이소메트릭 게임상 이미지를 백과사전 카드(256x256 PNG)로 베이킹

const OUT_DIR := "res://assets/encyclopedia/"
const CARD_SIZE := 256

func _init() -> void:
	print("=== 역사도감 16대 건축물 2.5D 아이소메트릭 카드 베이킹 시작 ===")
	call_deferred("_bake_all")

func _bake_all() -> void:
	var buildings: Array[Dictionary] = [
		{"id": "haenggung", "src": "res://assets/sprites/buildings/haenggung.png", "scale": 0.52},
		{"id": "seojangdae", "src": "res://assets/sprites/buildings/seojangdae.png", "scale": 1.4},
		{"id": "yeonmudae", "src": "res://assets/sprites/buildings/yeonmudae.png", "scale": 1.4},
		{"id": "seodang", "src": "res://assets/sprites/buildings/seodang.png", "scale": 1.4},
		{"id": "hyanggyo", "src": "res://assets/sprites/buildings/maegok_seowon.png", "scale": 1.15},
		{"id": "patrol", "src": "res://assets/sprites/buildings/yusubu.png", "scale": 1.4},
		{"id": "jinhulso", "src": "res://assets/sprites/buildings/tile_house_10_3x2.png", "scale": 1.25},
		{"id": "jangmadang", "src": "res://assets/sprites/buildings/market_shop.png", "scale": 1.6},
	]

	# 1. 기존 스프라이트 기반 건물 8종
	for b in buildings:
		var card: Image = _create_card_from_sprite(b["src"], float(b["scale"]))
		_save_image(card, OUT_DIR + b["id"] + ".png")
		print("[BAKE] 건축물 스프라이트 완료: %s" % b["id"])

	# 2. 절차적 랜드마크 (만석거, 축만제)
	_bake_procedural_lake("manseokgeo", "manseokgeo")
	_bake_procedural_lake("chukmanje", "chukmanje")

	# 3. 사대문 (장안문 2.5D 웅장한 성문)
	_bake_gate("sadaemun")

	# 4. 화홍문 (일곱 무지개 수문)
	_bake_hwahongmun("hwahongmun")

	# 5. 남수문 (아홉 무지개 수문)
	_bake_namsumun("namsumun")

	# 6. 종루 (여민각 범종 누각)
	_bake_jongnu("jongnu")

	# 7. 우시장 (팔달문 쇠전)
	_bake_usijang("usijang")

	# 8. 멸화군 (소방 감시 망루)
	_bake_firefighter("firefighter")

	print("=== 16대 건축물 베이킹 완료 ===")
	quit(0)

func _create_card_base() -> Image:
	var img := Image.create(CARD_SIZE, CARD_SIZE, false, Image.FORMAT_RGBA8)
	# 은은하고 따뜻한 전통 고서지/한지 그라데이션 배경
	for y in range(CARD_SIZE):
		var t: float = float(y) / float(CARD_SIZE)
		var c := Color("231c16").lerp(Color("362a22"), t)
		for x in range(CARD_SIZE):
			img.set_pixel(x, y, c)

	# 내부 미색 비단 바탕 패널
	var pad: int = 8
	var in_w: int = CARD_SIZE - pad * 2
	for y in range(pad, pad + in_w):
		var ty: float = float(y - pad) / float(in_w)
		for x in range(pad, pad + in_w):
			var tx: float = float(x - pad) / float(in_w)
			# 중앙이 살짝 밝은 부드러운 빛
			var d: float = Vector2(tx - 0.5, ty - 0.5).length()
			var base_c := Color("f7f1e3").lerp(Color("ede1cc"), clampf(d * 1.2, 0.0, 1.0))
			img.set_pixel(x, y, base_c)

	# 은은한 테두리
	for i in range(pad, pad + in_w):
		img.set_pixel(i, pad, Color("c9a050"))
		img.set_pixel(i, pad + in_w - 1, Color("c9a050"))
		img.set_pixel(pad, i, Color("c9a050"))
		img.set_pixel(pad + in_w - 1, i, Color("c9a050"))

	return img

func _create_card_from_sprite(src_path: String, scale_factor: float) -> Image:
	var card := _create_card_base()
	var gpath := ProjectSettings.globalize_path(src_path)
	if not FileAccess.file_exists(gpath):
		print("[WARN] 스프라이트 없음: %s" % src_path)
		return card

	var s_img := Image.new()
	s_img.load(gpath)
	if s_img.is_empty():
		return card

	var target_w := int(float(s_img.get_width()) * scale_factor)
	var target_h := int(float(s_img.get_height()) * scale_factor)
	if target_w <= 0 or target_h <= 0:
		return card

	s_img.resize(target_w, target_h, Image.INTERPOLATE_NEAREST)

	# 카드 정중앙 아래쪽에 안착
	var dest_x := (CARD_SIZE - target_w) / 2
	var dest_y := (CARD_SIZE - target_h) / 2 + 10
	dest_y = clampi(dest_y, 14, CARD_SIZE - target_h - 14)

	# 블렌딩 복사
	for sy in range(s_img.get_height()):
		var dy: int = dest_y + sy
		if dy < 0 or dy >= CARD_SIZE:
			continue
		for sx in range(s_img.get_width()):
			var dx: int = dest_x + sx
			if dx < 0 or dx >= CARD_SIZE:
				continue
			var col: Color = s_img.get_pixel(sx, sy)
			if col.a > 0.05:
				_blend_pixel(card, dx, dy, col)

	return card

func _blend_pixel(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or x >= img.get_width() or y < 0 or y >= img.get_height():
		return
	if col.a >= 0.99:
		img.set_pixel(x, y, col)
	else:
		var bg: Color = img.get_pixel(x, y)
		var out_c := Color(
			bg.r * (1.0 - col.a) + col.r * col.a,
			bg.g * (1.0 - col.a) + col.g * col.a,
			bg.b * (1.0 - col.a) + col.b * col.a,
			1.0
		)
		img.set_pixel(x, y, out_c)

func _save_image(img: Image, res_path: String) -> void:
	var gpath := ProjectSettings.globalize_path(res_path)
	img.save_png(gpath)

func _bake_procedural_lake(out_id: String, landmark_key: String) -> void:
	var card := _create_card_base()
	var lake_img := Image.create(180, 140, false, Image.FORMAT_RGBA8)
	lake_img.fill(Color(0, 0, 0, 0))
	ProceduralIsoArtist.paint_landmark(lake_img, Vector2(180, 140), landmark_key)

	var dest_x: int = (CARD_SIZE - 180) / 2
	var dest_y: int = (CARD_SIZE - 140) / 2 + 8
	for sy in range(140):
		for sx in range(180):
			var col: Color = lake_img.get_pixel(sx, sy)
			if col.a > 0.05:
				_blend_pixel(card, dest_x + sx, dest_y + sy, col)
	_save_image(card, OUT_DIR + out_id + ".png")
	print("[BAKE] 호수 완료: %s" % out_id)

func _bake_gate(out_id: String) -> void:
	var card := _create_card_base()
	var g_img := Image.create(192, 160, false, Image.FORMAT_RGBA8)
	g_img.fill(Color(0, 0, 0, 0))
	var o := Vector2(96, 120)
	var tw: float = 140.0
	var th: float = 70.0

	# 1. 화강암 석축 기단
	ProceduralIsoArtist.draw_iso_ground(g_img, o, tw, th, Color("94a3b8"), Color("475569"), 6.0)
	ProceduralIsoArtist.draw_iso_box(g_img, o, -0.7, 0.7, -0.6, 0.6, 0.0, 32.0, Color("94a3b8"), Color("94a3b8"), Color("64748b"), tw, th, true)

	# 2. 무지개 홍예문 아치 구멍
	ProceduralIsoArtist.draw_iso_box(g_img, o, -0.22, 0.22, 0.45, 0.62, 0.0, 20.0, Color("1e1b18"), Color("1e1b18"), Color("0f172a"), tw, th, false)

	# 3. 2층 웅장한 목조 문루
	# 1층 문루
	ProceduralIsoArtist.draw_iso_box(g_img, o, -0.55, 0.55, -0.45, 0.45, 32.0, 50.0, Color("dc2626"), Color("dc2626"), Color("991b1b"), tw, th, true, Color("5c3a21"), true)
	ProceduralIsoArtist.draw_iso_roof(g_img, o, -0.62, 0.62, -0.52, 0.52, 49.0, 68.0, Color("1e293b"), Color("f8fafc"), false, tw, th)
	# 2층 문루
	ProceduralIsoArtist.draw_iso_box(g_img, o, -0.42, 0.42, -0.35, 0.35, 68.0, 84.0, Color("dc2626"), Color("dc2626"), Color("991b1b"), tw, th, true, Color("5c3a21"), true)
	ProceduralIsoArtist.draw_iso_roof(g_img, o, -0.50, 0.50, -0.42, 0.42, 83.0, 106.0, Color("1e293b"), Color("f8fafc"), false, tw, th)

	var dest_x: int = (CARD_SIZE - 192) / 2
	var dest_y: int = (CARD_SIZE - 160) / 2 + 10
	for sy in range(160):
		for sx in range(192):
			var col: Color = g_img.get_pixel(sx, sy)
			if col.a > 0.05:
				_blend_pixel(card, dest_x + sx, dest_y + sy, col)
	_save_image(card, OUT_DIR + out_id + ".png")
	print("[BAKE] 성문 완료: %s" % out_id)

func _bake_hwahongmun(out_id: String) -> void:
	var card := _create_card_base()
	var g_img := Image.create(192, 150, false, Image.FORMAT_RGBA8)
	g_img.fill(Color(0, 0, 0, 0))
	var o := Vector2(96, 110)
	var tw: float = 144.0
	var th: float = 72.0

	# 1. 맑은 수원천 물결
	ProceduralIsoArtist.draw_iso_ground(g_img, o, tw * 1.1, th * 1.1, Color("0284c7"), Color("0369a1"))
	# 2. 화강암 7연 무지개 수문 석축
	ProceduralIsoArtist.draw_iso_box(g_img, o, -0.85, 0.85, -0.4, 0.4, 0.0, 24.0, Color("94a3b8"), Color("94a3b8"), Color("64748b"), tw, th, true)
	# 7개 홍예 아치 수문
	for i in range(7):
		var u: float = -0.72 + float(i) * 0.24
		ProceduralIsoArtist.draw_iso_box(g_img, o, u - 0.08, u + 0.08, 0.25, 0.42, 0.0, 14.0, Color("082f49"), Color("082f49"), Color("0369a1"), tw, th, false)
	# 3. 수문 위 아름다운 화홍문 누각
	ProceduralIsoArtist.draw_iso_box(g_img, o, -0.55, 0.55, -0.3, 0.3, 24.0, 42.0, Color("dc2626"), Color("dc2626"), Color("991b1b"), tw, th, true, Color("5c3a21"), true)
	ProceduralIsoArtist.draw_iso_roof(g_img, o, -0.65, 0.65, -0.38, 0.38, 41.0, 68.0, Color("1e293b"), Color("f8fafc"), false, tw, th)

	var dest_x: int = (CARD_SIZE - 192) / 2
	var dest_y: int = (CARD_SIZE - 150) / 2 + 10
	for sy in range(150):
		for sx in range(192):
			var col: Color = g_img.get_pixel(sx, sy)
			if col.a > 0.05:
				_blend_pixel(card, dest_x + sx, dest_y + sy, col)
	_save_image(card, OUT_DIR + out_id + ".png")
	print("[BAKE] 화홍문 완료: %s" % out_id)

func _bake_namsumun(out_id: String) -> void:
	var card := _create_card_base()
	var g_img := Image.create(192, 150, false, Image.FORMAT_RGBA8)
	g_img.fill(Color(0, 0, 0, 0))
	var o := Vector2(96, 110)
	var tw: float = 148.0
	var th: float = 74.0

	# 1. 수원천 하류 물결
	ProceduralIsoArtist.draw_iso_ground(g_img, o, tw * 1.1, th * 1.1, Color("0284c7"), Color("075985"))
	# 2. 아홉 무지개 수문 석축
	ProceduralIsoArtist.draw_iso_box(g_img, o, -0.9, 0.9, -0.4, 0.4, 0.0, 22.0, Color("94a3b8"), Color("94a3b8"), Color("64748b"), tw, th, true)
	# 9개 홍예 아치
	for i in range(9):
		var u: float = -0.78 + float(i) * 0.195
		ProceduralIsoArtist.draw_iso_box(g_img, o, u - 0.065, u + 0.065, 0.25, 0.42, 0.0, 13.0, Color("082f49"), Color("082f49"), Color("0369a1"), tw, th, false)
	# 3. 남수문 상부 포루 (벽돌 방어 포루)
	ProceduralIsoArtist.draw_iso_box(g_img, o, -0.4, 0.4, -0.3, 0.3, 22.0, 44.0, Color("475569"), Color("475569"), Color("334155"), tw, th, true)
	ProceduralIsoArtist.draw_iso_roof(g_img, o, -0.48, 0.48, -0.38, 0.38, 43.0, 64.0, Color("1e293b"), Color("f8fafc"), false, tw, th)

	var dest_x: int = (CARD_SIZE - 192) / 2
	var dest_y: int = (CARD_SIZE - 150) / 2 + 10
	for sy in range(150):
		for sx in range(192):
			var col: Color = g_img.get_pixel(sx, sy)
			if col.a > 0.05:
				_blend_pixel(card, dest_x + sx, dest_y + sy, col)
	_save_image(card, OUT_DIR + out_id + ".png")
	print("[BAKE] 남수문 완료: %s" % out_id)

func _bake_jongnu(out_id: String) -> void:
	var card := _create_card_base()
	var g_img := Image.create(160, 140, false, Image.FORMAT_RGBA8)
	g_img.fill(Color(0, 0, 0, 0))
	var o := Vector2(80, 105)
	var tw: float = 110.0
	var th: float = 55.0

	# 1. 장대석 기단
	ProceduralIsoArtist.draw_iso_ground(g_img, o, tw, th, Color("cbd5e1"), Color("64748b"), 4.0)
	# 2. 1층 기둥
	ProceduralIsoArtist.draw_iso_box(g_img, o, -0.6, 0.6, -0.6, 0.6, 0.0, 16.0, Color("5c3a21"), Color("5c3a21"), Color("3f2412"), tw, th, false)
	# 3. 2층 누각 및 범종
	ProceduralIsoArtist.draw_iso_box(g_img, o, -0.5, 0.5, -0.5, 0.5, 16.0, 36.0, Color("dc2626"), Color("dc2626"), Color("991b1b"), tw, th, true, Color("5c3a21"), true)
	# 범종 (황동빛)
	ProceduralIsoArtist.draw_circle_img(g_img, o - Vector2(0, 24), 8.0, Color("b45309"))
	ProceduralIsoArtist.draw_circle_img(g_img, o - Vector2(1, 25), 6.5, Color("f59e0b"))
	# 4. 팔작지붕
	ProceduralIsoArtist.draw_iso_roof(g_img, o, -0.65, 0.65, -0.65, 0.65, 35.0, 60.0, Color("1e293b"), Color("f8fafc"), false, tw, th)

	var dest_x: int = (CARD_SIZE - 160) / 2
	var dest_y: int = (CARD_SIZE - 140) / 2 + 10
	for sy in range(140):
		for sx in range(160):
			var col: Color = g_img.get_pixel(sx, sy)
			if col.a > 0.05:
				_blend_pixel(card, dest_x + sx, dest_y + sy, col)
	_save_image(card, OUT_DIR + out_id + ".png")
	print("[BAKE] 종루 완료: %s" % out_id)

func _bake_usijang(out_id: String) -> void:
	var card := _create_card_base()
	var g_img := Image.create(160, 140, false, Image.FORMAT_RGBA8)
	g_img.fill(Color(0, 0, 0, 0))
	var o := Vector2(80, 105)
	var tw: float = 120.0
	var th: float = 60.0

	# 1. 흙바닥 장터 마당
	ProceduralIsoArtist.draw_iso_ground(g_img, o, tw, th, Color("d4b483"), Color("997a48"), 4.0)
	# 2. 목조 울타리와 짚더미
	ProceduralIsoArtist.draw_rect_img(g_img, Rect2(o - Vector2(40, 25), Vector2(80, 3)), Color("78350f"))
	ProceduralIsoArtist.draw_circle_img(g_img, o - Vector2(25, 20), 8.0, Color("eab308")) # 짚더미
	# 3. 우시장 튼튼한 황소 도트
	var p_ox := o + Vector2(4, -8)
	ProceduralIsoArtist.draw_ellipse_img(g_img, p_ox, 14.0, 9.0, Color("78350f")) # 몸통
	ProceduralIsoArtist.draw_circle_img(g_img, p_ox - Vector2(12, 4), 6.0, Color("9a3412")) # 머리
	ProceduralIsoArtist.draw_circle_img(g_img, p_ox - Vector2(15, 8), 2.2, Color("fef08a")) # 뿔
	ProceduralIsoArtist.draw_rect_img(g_img, Rect2(p_ox + Vector2(-8, 6), Vector2(3, 8)), Color("451a03")) # 다리
	ProceduralIsoArtist.draw_rect_img(g_img, Rect2(p_ox + Vector2(6, 6), Vector2(3, 8)), Color("451a03"))

	var dest_x: int = (CARD_SIZE - 160) / 2
	var dest_y: int = (CARD_SIZE - 140) / 2 + 10
	for sy in range(140):
		for sx in range(160):
			var col: Color = g_img.get_pixel(sx, sy)
			if col.a > 0.05:
				_blend_pixel(card, dest_x + sx, dest_y + sy, col)
	_save_image(card, OUT_DIR + out_id + ".png")
	print("[BAKE] 우시장 완료: %s" % out_id)

func _bake_firefighter(out_id: String) -> void:
	var card := _create_card_base()
	var g_img := Image.create(160, 150, false, Image.FORMAT_RGBA8)
	g_img.fill(Color(0, 0, 0, 0))
	var o := Vector2(80, 115)
	var tw: float = 110.0
	var th: float = 55.0

	# 1. 석축 기단
	ProceduralIsoArtist.draw_iso_ground(g_img, o, tw, th, Color("94a3b8"), Color("64748b"), 4.0)
	# 2. 멸화군 본채 (소방 관청)
	ProceduralIsoArtist.draw_iso_box(g_img, o, -0.6, 0.1, -0.5, 0.4, 0.0, 20.0, Color("5c3a21"), Color("fdfbf7"), Color("cbd5e1"), tw, th, true)
	ProceduralIsoArtist.draw_iso_roof(g_img, o, -0.68, 0.18, -0.58, 0.48, 19.0, 42.0, Color("1e293b"), Color("f8fafc"), false, tw, th)
	# 3. 높은 소방 망루 (화재 감시탑)
	var p_tower := o + Vector2(30, -5)
	ProceduralIsoArtist.draw_line_img(g_img, p_tower - Vector2(10, 0), p_tower - Vector2(6, 60), Color("5c3a21"), 2.0)
	ProceduralIsoArtist.draw_line_img(g_img, p_tower + Vector2(10, 0), p_tower + Vector2(6, 60), Color("5c3a21"), 2.0)
	ProceduralIsoArtist.draw_line_img(g_img, p_tower - Vector2(8, 25), p_tower + Vector2(8, 25), Color("5c3a21"), 1.6)
	ProceduralIsoArtist.draw_line_img(g_img, p_tower - Vector2(7, 45), p_tower + Vector2(7, 45), Color("5c3a21"), 1.6)
	# 망루 상단 관측소 및 경종
	ProceduralIsoArtist.draw_rect_img(g_img, Rect2(p_tower - Vector2(12, 65), Vector2(24, 8)), Color("78350f"))
	ProceduralIsoArtist.draw_circle_img(g_img, p_tower - Vector2(0, 68), 3.0, Color("dc2626")) # 경종

	var dest_x: int = (CARD_SIZE - 160) / 2
	var dest_y: int = (CARD_SIZE - 150) / 2 + 10
	for sy in range(150):
		for sx in range(160):
			var col: Color = g_img.get_pixel(sx, sy)
			if col.a > 0.05:
				_blend_pixel(card, dest_x + sx, dest_y + sy, col)
	_save_image(card, OUT_DIR + out_id + ".png")
	print("[BAKE] 멸화군 완료: %s" % out_id)
