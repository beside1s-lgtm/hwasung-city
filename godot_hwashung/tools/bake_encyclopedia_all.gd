extends SceneTree

# bake_encyclopedia_all.gd
# 역사도감 24대 인물 및 20대 생활상 백과사전 카드(256x256 PNG) 직행 베이커

const OUT_DIR := "res://assets/encyclopedia/"
const CARD_SIZE := 256

func _init() -> void:
	print("=== 역사도감 인물 및 생활상 카드 베이킹 시작 ===")
	call_deferred("_bake_all")

func _bake_all() -> void:
	_bake_people()
	_bake_life()
	print("=== 역사도감 인물 및 생활상 카드 베이킹 완료 ===")
	quit(0)

# =============================================================================
# 공통 카드 베이스 생성 (전통 한지 / 비단 표구 256x256)
# =============================================================================
func _create_card_base(theme_bg: Color = Color("f6f0e2"), border_col: Color = Color("c9a050")) -> Image:
	var img := Image.create(CARD_SIZE, CARD_SIZE, false, Image.FORMAT_RGBA8)
	# 외곽 짙은 고서지/단청 먹색 테두리
	for y in range(CARD_SIZE):
		var t: float = float(y) / float(CARD_SIZE)
		var c := Color("1e1713").lerp(Color("2c221b"), t)
		for x in range(CARD_SIZE):
			img.set_pixel(x, y, c)

	# 내부 고급 비단 캔버스
	var pad: int = 8
	var in_w: int = CARD_SIZE - pad * 2
	for y in range(pad, pad + in_w):
		var ty: float = float(y - pad) / float(in_w)
		for x in range(pad, pad + in_w):
			var tx: float = float(x - pad) / float(in_w)
			var d: float = Vector2(tx - 0.5, ty - 0.5).length()
			var base_c := theme_bg.lerp(theme_bg.darkened(0.12), clampf(d * 1.1, 0.0, 1.0))
			img.set_pixel(x, y, base_c)

	# 품격 있는 금장 테두리 선
	for i in range(pad, pad + in_w):
		img.set_pixel(i, pad, border_col)
		img.set_pixel(i, pad + in_w - 1, border_col)
		img.set_pixel(pad, i, border_col)
		img.set_pixel(pad + in_w - 1, i, border_col)
		img.set_pixel(i, pad + 1, border_col.lightened(0.2))
		img.set_pixel(pad + 1, i, border_col.lightened(0.2))

	return img

func _blend_pixel(img: Image, x: int, y: int, col: Color) -> void:
	if x < 0 or x >= img.get_width() or y < 0 or y >= img.get_height():
		return
	if col.a >= 0.99:
		img.set_pixel(x, y, col)
	elif col.a > 0.02:
		var bg: Color = img.get_pixel(x, y)
		var a: float = col.a
		var out_c := Color(
			bg.r * (1.0 - a) + col.r * a,
			bg.g * (1.0 - a) + col.g * a,
			bg.b * (1.0 - a) + col.b * a,
			1.0
		)
		img.set_pixel(x, y, out_c)

func _save_image(img: Image, res_path: String) -> void:
	var gpath := ProjectSettings.globalize_path(res_path)
	img.save_png(gpath)

# =============================================================================
# 1. 24대 인물 카드 베이킹
# =============================================================================
func _bake_people() -> void:
	var people_map: Dictionary = {
		"kim_hongdo": {"src": "named_kim_hongdo_front.png", "bg": Color("fbf5e6"), "title": "단원 김홍도"},
		"sim_hwanji": {"src": "named_sim_hwanji_front.png", "bg": Color("fdf2e9"), "title": "만포 심환지"},
		"hong_inhan": {"src": "named_hong_inhan_front.png", "bg": Color("fcf0ea"), "title": "좌의정 홍인한"},
		"kim_josun": {"src": "named_kim_josun_front.png", "bg": Color("f4f6fb"), "title": "풍고 김조순"},
		"park_jega": {"src": "named_park_jega_front.png", "bg": Color("f5f7f2"), "title": "초정 박제가"},
		"seo_yugu": {"src": "named_seo_yugu_front.png", "bg": Color("f7f9f2"), "title": "풍석 서유구"},
		"jeong_beomjo": {"src": "named_jeong_beomjo_front.png", "bg": Color("faf7f2"), "title": "해좌 정범조"},
		"lee_gahwan": {"src": "named_yi_gahwan_front.png", "bg": Color("f3f4f8"), "title": "정헌 이가환"},
		"yu_deukgong": {"src": "named_yu_deukgong_front.png", "bg": Color("f5f6f8"), "title": "영재 유득공"},
		"park_jiwon": {"src": "named_park_jiwon_front.png", "bg": Color("faf6ef"), "title": "연암 박지원"},
		"kim_jeonghui": {"src": "named_kim_jeonghee_front.png", "bg": Color("f7f5f8"), "title": "추사 김정희"},
		"lee_gigyeong": {"src": "named_yi_gigyeong_front.png", "bg": Color("fbf3ee"), "title": "벽파 이기경"},
		"hong_gukyeong": {"src": "named_hong_gukyeong_front.png", "bg": Color("fef0eb"), "title": "도승지 홍국영"},
		"gu_seonbok": {"src": "named_gu_seonbok_front.png", "bg": Color("f5f2ee"), "title": "어영대장 구선복"},
		"kim_bau": {"src": "named_kim_bau_front.png", "bg": Color("f5f2ea"), "title": "석수 김바우"},
		"lee_seonggil": {"src": "named_lee_seonggil_front.png", "bg": Color("f7f4ed"), "title": "도편수 이성길"},
		"musoe": {"src": "named_musoe_front.png", "bg": Color("f5eee7"), "title": "가죽공 무쇠"},
		"yu_hanji": {"src": "named_yu_hanji_front.png", "bg": Color("f6f4f8"), "title": "명필 유한지"},
	}

	for pid: String in people_map:
		var target_path: String = OUT_DIR + pid + ".png"
		var target_jpg: String = OUT_DIR + pid + ".jpg"
		# 이미 고화질 실사 AI 이미지가 있는 경우(chae_jegong, jeong_yakyong, jo_simtae, hong_daeyong, baek_dongsu, lee_deokmu)는 보존
		if FileAccess.file_exists(ProjectSettings.globalize_path(target_jpg)):
			print("[PEOPLE SKIP] 실사 AI 초상화 존재: %s" % pid)
			continue

		var info: Dictionary = people_map[pid]
		var card: Image = _create_card_base(info["bg"], Color("c9a050"))
		var sprite_path: String = "res://assets/sprites/npcs/named/" + str(info["src"])
		var gpath := ProjectSettings.globalize_path(sprite_path)
		if not FileAccess.file_exists(gpath):
			print("[PEOPLE WARN] 스프라이트 없음: %s" % sprite_path)
			continue

		var s_img := Image.new()
		s_img.load(gpath)
		if s_img.is_empty():
			continue

		# 48x48 캐릭터를 삼국지 장수 흉상 풍으로 3.8배(182x182) 확대하여 정중앙 배치
		var scale_w: int = int(float(s_img.get_width()) * 3.8)
		var scale_h: int = int(float(s_img.get_height()) * 3.8)
		s_img.resize(scale_w, scale_h, Image.INTERPOLATE_NEAREST)

		var dest_x: int = (CARD_SIZE - scale_w) / 2
		var dest_y: int = (CARD_SIZE - scale_h) / 2 + 10

		# 부드러운 인물 후광 타원
		ProceduralIsoArtist.draw_ellipse_img(card, Vector2(CARD_SIZE * 0.5, CARD_SIZE * 0.5 + 4), 62.0, 72.0, Color(0, 0, 0, 0.08))
		ProceduralIsoArtist.draw_ellipse_img(card, Vector2(CARD_SIZE * 0.5, CARD_SIZE * 0.5 + 2), 52.0, 60.0, Color(1, 1, 1, 0.45))

		for sy in range(s_img.get_height()):
			var dy: int = dest_y + sy
			if dy < 10 or dy >= CARD_SIZE - 10:
				continue
			for sx in range(s_img.get_width()):
				var dx: int = dest_x + sx
				if dx < 10 or dx >= CARD_SIZE - 10:
					continue
				var col: Color = s_img.get_pixel(sx, sy)
				if col.a > 0.05:
					_blend_pixel(card, dx, dy, col)

		# 하단 명패 띠 (삼국지 장수 열전 풍 한글 이름 띠)
		var name_box_y: int = CARD_SIZE - 32
		ProceduralIsoArtist.draw_rect_img(card, Rect2(12, name_box_y, CARD_SIZE - 24, 20), Color(0.12, 0.08, 0.05, 0.88))
		ProceduralIsoArtist.draw_line_img(card, Vector2(12, name_box_y), Vector2(CARD_SIZE - 12, name_box_y), Color("c9a050"), 1.2)
		ProceduralIsoArtist.draw_line_img(card, Vector2(12, name_box_y + 19), Vector2(CARD_SIZE - 12, name_box_y + 19), Color("c9a050"), 1.2)

		_save_image(card, target_path)
		print("[PEOPLE BAKE] 인물 초상화 완성: %s" % pid)

# =============================================================================
# 2. 20대 생활상 풍속화 카드 베이킹
# =============================================================================
func _bake_life() -> void:
	var life_items: Array[String] = [
		"jwibul", "seokjeon", "kite", "ssireum_parade", "ganggang",
		"lion_dance", "neolttwigi", "swing", "yard_games", "namsadang",
		"jeongisu", "farmer_ox", "mason", "smith", "bobusang",
		"washer", "catholic", "jangyong_drill", "pabal", "wonhaeng"
	]

	for lid in life_items:
		var card := _bake_single_life(lid)
		_save_image(card, OUT_DIR + lid + ".png")
		print("[LIFE BAKE] 생활상 풍속화 완성: %s" % lid)

func _bake_single_life(lid: String) -> Image:
	var card := _create_card_base(Color("faf4e8"), Color("b45309"))
	var c := Vector2(CARD_SIZE * 0.5, CARD_SIZE * 0.58)

	match lid:
		"jwibul": # 쥐불놀이: 겨울 밤하늘 원형 불꽃 궤적
			ProceduralIsoArtist.draw_rect_img(card, Rect2(10, 10, CARD_SIZE - 20, CARD_SIZE - 20), Color("0f172a"))
			ProceduralIsoArtist.draw_ellipse_img(card, c + Vector2(0, 15), 90.0, 35.0, Color("1e293b"))
			# 쥐불 원형 궤적 (황금/주황 불꽃)
			for ang_i in range(36):
				var rad: float = float(ang_i) * (PI * 2.0 / 36.0)
				var r: float = 38.0 + sin(rad * 4.0) * 4.0
				var p := c + Vector2(cos(rad) * r, sin(rad) * r * 0.75 - 15.0)
				ProceduralIsoArtist.draw_circle_img(card, p, 3.2, Color("f97316"))
				ProceduralIsoArtist.draw_circle_img(card, p, 1.8, Color("fef08a"))

		"seokjeon": # 석전: 양편 대치와 날아가는 돌멩이
			ProceduralIsoArtist.draw_iso_ground(card, c, 180.0, 90.0, Color("d4b483"), Color("997a48"), 5.0)
			# 좌우 진영 사람 도트
			ProceduralIsoArtist.draw_ellipse_img(card, c + Vector2(-45, -5), 18.0, 10.0, Color("1d4ed8"))
			ProceduralIsoArtist.draw_ellipse_img(card, c + Vector2(45, -5), 18.0, 10.0, Color("b91c1c"))
			# 공중 포물선 돌멩이
			for i in range(5):
				var t: float = float(i) / 4.0
				var p := Vector2(-35.0 + t * 70.0, c.y - 10.0 - sin(t * PI) * 28.0)
				ProceduralIsoArtist.draw_circle_img(card, p, 2.5, Color("475569"))

		"kite": # 연날리기: 높은 하늘의 방패연과 실패
			ProceduralIsoArtist.draw_rect_img(card, Rect2(10, 10, CARD_SIZE - 20, CARD_SIZE - 20), Color("38bdf8"))
			ProceduralIsoArtist.draw_circle_img(card, Vector2(190, 50), 22.0, Color("fef08a", 0.6)) # 태양
			# 방패연 (다이아몬드 + 태극)
			var kp := Vector2(128, 90)
			var r_pts: Array[Vector2] = [kp + Vector2(0, -32), kp + Vector2(26, 0), kp + Vector2(0, 32), kp + Vector2(-26, 0)]
			ProceduralIsoArtist.fill_quad(card, r_pts[0], r_pts[1], r_pts[2], r_pts[3], Color("ffffff"))
			ProceduralIsoArtist.draw_circle_img(card, kp, 11.0, Color("dc2626"))
			ProceduralIsoArtist.draw_circle_img(card, kp + Vector2(0, 2), 7.0, Color("2563eb"))
			# 연줄
			ProceduralIsoArtist.draw_line_img(card, kp + Vector2(0, 32), Vector2(60, 210), Color("ffffff", 0.8), 1.2)

		"ssireum_parade": # 천하장사 행진: 꽃단 황소와 장사
			ProceduralIsoArtist.draw_iso_ground(card, c, 180.0, 90.0, Color("d4b483"), Color("997a48"), 5.0)
			# 황소
			var bp := c + Vector2(0, -10)
			ProceduralIsoArtist.draw_ellipse_img(card, bp, 32.0, 18.0, Color("78350f"))
			ProceduralIsoArtist.draw_circle_img(card, bp - Vector2(24, 8), 12.0, Color("9a3412"))
			ProceduralIsoArtist.draw_circle_img(card, bp - Vector2(30, 16), 4.5, Color("fef08a")) # 뿔
			# 꽃목걸이
			for k in range(5):
				ProceduralIsoArtist.draw_circle_img(card, bp - Vector2(16 - float(k * 4), 6), 3.0, Color("ef4444"))
			# 타고 있는 천하장사
			ProceduralIsoArtist.draw_ellipse_img(card, bp - Vector2(2, 24), 11.0, 14.0, Color("dc2626"))
			ProceduralIsoArtist.draw_circle_img(card, bp - Vector2(2, 36), 6.5, Color("fbcfe8"))

		"ganggang": # 강강술래: 한가위 보름달과 손잡은 원무
			ProceduralIsoArtist.draw_rect_img(card, Rect2(10, 10, CARD_SIZE - 20, CARD_SIZE - 20), Color("0f172a"))
			# 거대한 황금 보름달
			ProceduralIsoArtist.draw_circle_img(card, Vector2(128, 70), 38.0, Color("fef08a"))
			# 손잡고 도는 원무 8명
			for i in range(10):
				var ang: float = float(i) * (PI * 2.0 / 10.0)
				var p := Vector2(128.0 + cos(ang) * 58.0, 160.0 + sin(ang) * 26.0)
				ProceduralIsoArtist.draw_circle_img(card, p - Vector2(0, 10), 4.5, Color("fbcfe8"))
				ProceduralIsoArtist.draw_ellipse_img(card, p, 6.0, 9.0, Color("ffffff") if (i % 2 == 0) else Color("38bdf8"))

		"lion_dance": # 북청 사자춤: 화려한 사자탈과 풍물
			ProceduralIsoArtist.draw_iso_ground(card, c, 180.0, 90.0, Color("d4b483"), Color("997a48"), 4.0)
			var lp := c + Vector2(0, -18)
			# 황금빛 북청 사자탈
			ProceduralIsoArtist.draw_ellipse_img(card, lp, 34.0, 20.0, Color("eab308"))
			ProceduralIsoArtist.draw_circle_img(card, lp - Vector2(22, 6), 14.0, Color("ca8a04"))
			# 사자 눈과 갈기
			ProceduralIsoArtist.draw_circle_img(card, lp - Vector2(26, 10), 4.0, Color("dc2626"))
			ProceduralIsoArtist.draw_circle_img(card, lp - Vector2(27, 10), 2.0, Color("fef08a"))
			for mk in range(7):
				ProceduralIsoArtist.draw_circle_img(card, lp - Vector2(12 - float(mk * 5), 14), 4.5, Color("b45309"))

		"neolttwigi": # 널뛰기: 공중으로 솟구친 한복 여인
			ProceduralIsoArtist.draw_iso_ground(card, c, 180.0, 90.0, Color("d4b483"), Color("997a48"), 4.0)
			# 널빤지와 짚단
			ProceduralIsoArtist.draw_line_img(card, c - Vector2(50, 10), c + Vector2(50, -2), Color("b45309"), 3.5)
			ProceduralIsoArtist.draw_circle_img(card, c - Vector2(0, 6), 8.0, Color("78350f"))
			# 공중 도약 아낙 (무지개 치맛자락)
			var jp := c - Vector2(45, 52)
			ProceduralIsoArtist.draw_ellipse_img(card, jp, 10.0, 18.0, Color("ef4444"))
			ProceduralIsoArtist.draw_circle_img(card, jp - Vector2(0, 16), 5.5, Color("fbcfe8"))
			# 반대편 아낙 (착지)
			var lp2 := c + Vector2(45, -12)
			ProceduralIsoArtist.draw_ellipse_img(card, lp2, 9.0, 15.0, Color("22c55e"))
			ProceduralIsoArtist.draw_circle_img(card, lp2 - Vector2(0, 13), 5.0, Color("fbcfe8"))

		"swing": # 그네뛰기: 높은 그네와 펄럭이는 치마
			ProceduralIsoArtist.draw_rect_img(card, Rect2(10, 10, CARD_SIZE - 20, CARD_SIZE - 20), Color("86efac"))
			# 그네 기둥 2개
			ProceduralIsoArtist.draw_line_img(card, Vector2(70, 210), Vector2(85, 40), Color("5c3a21"), 3.0)
			ProceduralIsoArtist.draw_line_img(card, Vector2(186, 210), Vector2(171, 40), Color("5c3a21"), 3.0)
			ProceduralIsoArtist.draw_line_img(card, Vector2(80, 42), Vector2(176, 42), Color("5c3a21"), 3.0)
			# 그넷줄과 날아오른 처녀
			var sp_girl := Vector2(150, 110)
			ProceduralIsoArtist.draw_line_img(card, Vector2(128, 42), sp_girl, Color("fde68a"), 1.6)
			ProceduralIsoArtist.draw_ellipse_img(card, sp_girl + Vector2(6, 4), 12.0, 20.0, Color("ec4899"))
			ProceduralIsoArtist.draw_circle_img(card, sp_girl - Vector2(0, 8), 6.0, Color("fbcfe8"))

		"yard_games": # 골목 아이들: 말뚝박기
			ProceduralIsoArtist.draw_iso_ground(card, c, 180.0, 90.0, Color("d4b483"), Color("997a48"), 4.0)
			# 말뚝 기둥 아이
			ProceduralIsoArtist.draw_ellipse_img(card, c - Vector2(25, 20), 8.0, 16.0, Color("3b82f6"))
			ProceduralIsoArtist.draw_circle_img(card, c - Vector2(25, 34), 6.0, Color("fbcfe8"))
			# 허리 숙인 아이
			ProceduralIsoArtist.draw_ellipse_img(card, c - Vector2(8, 12), 14.0, 8.0, Color("eab308"))
			# 뛰어오르는 아이
			ProceduralIsoArtist.draw_ellipse_img(card, c + Vector2(15, 22), 8.0, 14.0, Color("ef4444"))
			ProceduralIsoArtist.draw_circle_img(card, c + Vector2(15, 34), 5.5, Color("fbcfe8"))

		"namsadang": # 남사당패: 줄타기 어름사니
			ProceduralIsoArtist.draw_rect_img(card, Rect2(10, 10, CARD_SIZE - 20, CARD_SIZE - 20), Color("e0f2fe"))
			# 외줄
			ProceduralIsoArtist.draw_line_img(card, Vector2(20, 150), Vector2(236, 120), Color("78350f"), 2.4)
			# 줄 위 어름사니 (부채와 도약)
			var tp := Vector2(128, 110)
			ProceduralIsoArtist.draw_ellipse_img(card, tp, 8.0, 15.0, Color("ffffff"))
			ProceduralIsoArtist.draw_circle_img(card, tp - Vector2(0, 14), 5.5, Color("fbcfe8"))
			# 흰 부채
			ProceduralIsoArtist.draw_circle_img(card, tp - Vector2(12, 10), 7.0, Color("fef08a"))

		"jeongisu": # 전기수: 이야기꾼과 둘러앉은 청중
			ProceduralIsoArtist.draw_iso_ground(card, c, 180.0, 90.0, Color("d4b483"), Color("997a48"), 4.0)
			# 돗자리 위의 이야기꾼
			var jp2 := c - Vector2(0, 18)
			ProceduralIsoArtist.draw_rect_img(card, Rect2(jp2 - Vector2(25, 10), Vector2(50, 20)), Color("ca8a04"))
			ProceduralIsoArtist.draw_ellipse_img(card, jp2 - Vector2(0, 8), 9.0, 14.0, Color("1e293b"))
			ProceduralIsoArtist.draw_circle_img(card, jp2 - Vector2(0, 20), 5.5, Color("fbcfe8"))
			# 펼친 소설책
			ProceduralIsoArtist.draw_rect_img(card, Rect2(jp2 + Vector2(-6, -2), Vector2(12, 6)), Color("ffffff"))
			# 둘러앉은 갓 쓴 청중들
			for ang_k in range(5):
				var pos_q := c + Vector2(-38.0 + float(ang_k * 19), 10)
				ProceduralIsoArtist.draw_circle_img(card, pos_q, 5.0, Color("0f172a"))

		"farmer_ox": # 둔전 농부와 소: 쟁기질
			ProceduralIsoArtist.draw_iso_ground(card, c, 180.0, 90.0, Color("65a30d"), Color("4d7c0f"), 4.0)
			# 쟁기 끄는 황소
			var ox_p := c - Vector2(15, 10)
			ProceduralIsoArtist.draw_ellipse_img(card, ox_p, 28.0, 16.0, Color("78350f"))
			ProceduralIsoArtist.draw_circle_img(card, ox_p - Vector2(20, 6), 10.0, Color("9a3412"))
			# 뒤따르는 농부 (삼베옷 + 삿갓)
			var fm_p := c + Vector2(30, -18)
			ProceduralIsoArtist.draw_ellipse_img(card, fm_p, 8.0, 15.0, Color("fef3c7"))
			ProceduralIsoArtist.draw_circle_img(card, fm_p - Vector2(0, 12), 7.0, Color("d97706")) # 삿갓

		"mason": # 성곽 석수: 돌 쪼는 석공
			ProceduralIsoArtist.draw_iso_ground(card, c, 180.0, 90.0, Color("94a3b8"), Color("64748b"), 4.0)
			# 네모난 화강암 성돌
			ProceduralIsoArtist.draw_rect_img(card, Rect2(c - Vector2(25, 20), Vector2(30, 20)), Color("cbd5e1"))
			# 정과 망치를 든 다부진 석수
			var ms_p := c + Vector2(18, -16)
			ProceduralIsoArtist.draw_ellipse_img(card, ms_p, 9.0, 16.0, Color("475569"))
			ProceduralIsoArtist.draw_circle_img(card, ms_p - Vector2(0, 14), 5.5, Color("fbcfe8"))
			# 튀는 돌가루 스파크
			ProceduralIsoArtist.draw_circle_img(card, c - Vector2(8, 16), 2.5, Color("fef08a"))

		"smith": # 대장간: 불꽃과 모루 망치질
			ProceduralIsoArtist.draw_iso_ground(card, c, 180.0, 90.0, Color("334155"), Color("1e293b"), 4.0)
			# 대장간 화로 (붉은 잉걸불)
			ProceduralIsoArtist.draw_circle_img(card, c - Vector2(25, 12), 16.0, Color("dc2626"))
			ProceduralIsoArtist.draw_circle_img(card, c - Vector2(25, 12), 9.0, Color("fef08a"))
			# 쇠모루
			ProceduralIsoArtist.draw_rect_img(card, Rect2(c + Vector2(-5, -15), Vector2(20, 15)), Color("0f172a"))
			# 대장장이 (망치 타격)
			var sm_p := c + Vector2(25, -20)
			ProceduralIsoArtist.draw_ellipse_img(card, sm_p, 9.0, 16.0, Color("b45309"))
			ProceduralIsoArtist.draw_circle_img(card, sm_p - Vector2(0, 14), 5.5, Color("fbcfe8"))

		"bobusang": # 보부상: 패랭이 모자에 봇짐
			ProceduralIsoArtist.draw_iso_ground(card, c, 180.0, 90.0, Color("d4b483"), Color("997a48"), 4.0)
			var bs_p := c + Vector2(0, -18)
			# 등 뒤 거대한 봇짐
			ProceduralIsoArtist.draw_ellipse_img(card, bs_p + Vector2(10, 4), 16.0, 20.0, Color("ffffff"))
			# 보부상 몸통
			ProceduralIsoArtist.draw_ellipse_img(card, bs_p, 9.0, 16.0, Color("3b82f6"))
			# 목화송이 달린 패랭이 모자
			ProceduralIsoArtist.draw_circle_img(card, bs_p - Vector2(0, 14), 8.0, Color("78350f"))
			ProceduralIsoArtist.draw_circle_img(card, bs_p - Vector2(0, 17), 3.0, Color("ffffff")) # 목화송이
			# 지팡이
			ProceduralIsoArtist.draw_line_img(card, bs_p - Vector2(8, 0), bs_p - Vector2(12, -25), Color("5c3a21"), 1.8)

		"washer": # 빨래터 아낙: 맑은 냇가와 방망이
			ProceduralIsoArtist.draw_iso_ground(card, c, 180.0, 90.0, Color("0284c7"), Color("0369a1"), 4.0)
			# 빨랫돌
			ProceduralIsoArtist.draw_ellipse_img(card, c + Vector2(-10, -5), 18.0, 10.0, Color("94a3b8"))
			# 하얀 빨랫감
			ProceduralIsoArtist.draw_circle_img(card, c + Vector2(-10, -7), 7.0, Color("ffffff"))
			# 방망이질하는 아낙
			var ws_p := c + Vector2(15, -16)
			ProceduralIsoArtist.draw_ellipse_img(card, ws_p, 9.0, 15.0, Color("f472b6"))
			ProceduralIsoArtist.draw_circle_img(card, ws_p - Vector2(0, 14), 5.5, Color("fbcfe8"))

		"catholic": # 천주교 신자: 촛불 아래 은밀한 기도
			ProceduralIsoArtist.draw_rect_img(card, Rect2(10, 10, CARD_SIZE - 20, CARD_SIZE - 20), Color("0f172a"))
			# 중앙 촛불
			var cp := c - Vector2(0, 10)
			ProceduralIsoArtist.draw_rect_img(card, Rect2(cp - Vector2(2, -4), Vector2(4, 16)), Color("ffffff"))
			ProceduralIsoArtist.draw_circle_img(card, cp - Vector2(0, 8), 5.0, Color("f97316"))
			ProceduralIsoArtist.draw_circle_img(card, cp - Vector2(0, 8), 2.5, Color("fef08a"))
			# 기도하는 신자들 실루엣
			ProceduralIsoArtist.draw_ellipse_img(card, cp + Vector2(-28, 12), 12.0, 18.0, Color("1e293b"))
			ProceduralIsoArtist.draw_ellipse_img(card, cp + Vector2(28, 12), 12.0, 18.0, Color("1e293b"))

		"jangyong_drill": # 장용영 군사훈련: 조총과 창검
			ProceduralIsoArtist.draw_iso_ground(card, c, 180.0, 90.0, Color("d4b483"), Color("997a48"), 4.0)
			# 조총 발사 연막
			ProceduralIsoArtist.draw_circle_img(card, c - Vector2(30, 25), 14.0, Color("f1f5f9", 0.7))
			# 장용영 군사 2명 (붉은 쾌자 + 벙거지)
			for mi in range(2):
				var mp := c + Vector2(-18.0 + float(mi * 36), -16)
				ProceduralIsoArtist.draw_ellipse_img(card, mp, 8.0, 16.0, Color("b91c1c"))
				ProceduralIsoArtist.draw_circle_img(card, mp - Vector2(0, 14), 6.0, Color("1e1b18")) # 벙거지
				# 조총/장창
				ProceduralIsoArtist.draw_line_img(card, mp, mp - Vector2(16, 18), Color("5c3a21"), 1.8)

		"pabal": # 파발마: 질주하는 파발과 붉은 깃발
			ProceduralIsoArtist.draw_iso_ground(card, c, 180.0, 90.0, Color("d4b483"), Color("997a48"), 4.0)
			var pb_p := c + Vector2(0, -14)
			# 달리는 말
			ProceduralIsoArtist.draw_ellipse_img(card, pb_p, 30.0, 16.0, Color("5c3a21"))
			ProceduralIsoArtist.draw_circle_img(card, pb_p - Vector2(22, 10), 10.0, Color("451a03"))
			# 파발 전령과 붉은 깃발
			ProceduralIsoArtist.draw_ellipse_img(card, pb_p - Vector2(2, 16), 8.0, 12.0, Color("2563eb"))
			ProceduralIsoArtist.draw_line_img(card, pb_p - Vector2(2, 16), pb_p - Vector2(8, 42), Color("78350f"), 1.6)
			ProceduralIsoArtist.draw_circle_img(card, pb_p - Vector2(14, 42), 7.0, Color("dc2626")) # 붉은 깃발

		"wonhaeng": # 을묘원행 행렬: 황금빛 임금 어가와 일산
			ProceduralIsoArtist.draw_iso_ground(card, c, 180.0, 90.0, Color("d4b483"), Color("997a48"), 4.0)
			var wh_p := c + Vector2(0, -16)
			# 붉은 황금 일산 (임금의 양산)
			ProceduralIsoArtist.draw_circle_img(card, wh_p - Vector2(0, 30), 18.0, Color("dc2626"))
			ProceduralIsoArtist.draw_circle_img(card, wh_p - Vector2(0, 30), 12.0, Color("facc15"))
			ProceduralIsoArtist.draw_line_img(card, wh_p - Vector2(0, 30), wh_p, Color("78350f"), 2.2)
			# 어가 가마
			ProceduralIsoArtist.draw_rect_img(card, Rect2(wh_p - Vector2(18, 12), Vector2(36, 22)), Color("b91c1c"))
			ProceduralIsoArtist.draw_circle_img(card, wh_p - Vector2(0, 8), 6.0, Color("fef08a"))

	return card
