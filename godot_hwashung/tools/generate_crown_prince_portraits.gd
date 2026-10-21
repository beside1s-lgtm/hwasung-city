extends SceneTree

const S := 80
const INK := Color("1a1410")

func _init() -> void:
	print("Generating Crown Prince 6-stage portraits...")
	_generate_all()
	print("All 6 portraits generated successfully!")
	quit(0)

func _finish(bg: PixelArt, fig: PixelArt, edge: Color, ring: Color) -> Image:
	fig.outline(INK)
	bg.blit(fig)
	var cx := float(S) * 0.5
	var cy := float(S) * 0.5
	var r := float(S) * 0.5 - 1.0
	for yy in range(S):
		for xx in range(S):
			var dx := float(xx) + 0.5 - cx
			var dy := float(yy) + 0.5 - cy
			var d := sqrt(dx * dx + dy * dy)
			if d > r:
				bg.px(xx, yy, Color(0, 0, 0, 0))
			elif d > r - 1.2:
				bg.px(xx, yy, edge)
			elif d > r - 2.4 and d <= r - 1.8:
				bg.px(xx, yy, ring)
	return bg.img

func _make_bg(c_in: Color, c_out: Color) -> PixelArt:
	var bg := PixelArt.new(S, S)
	var cx := float(S) * 0.5
	var cy := float(S) * 0.5
	var r := float(S) * 0.5
	for yy in range(S):
		for xx in range(S):
			var dx := float(xx) + 0.5 - cx
			var dy := float(yy) + 0.5 - cy
			var t := clampf(sqrt(dx * dx + dy * dy) / r, 0.0, 1.0)
			bg.px(xx, yy, c_in.lerp(c_out, t))
	return bg

func _generate_all() -> void:
	# 1단계: 유아 (0~20점)
	# 헐렁한 큰 곤룡포, 삐뚤어진 익선관, 장난기 넘치고 칭얼거리는 표정
	var bg1 := _make_bg(Color("fdf6e2"), Color("e6c875"))
	var fig1 := PixelArt.new(S, S)
	# 헐렁한 큰 곤룡포 (어깨 축 쳐짐)
	var body1 := PackedVector2Array([Vector2(6, 80), Vector2(10, 68), Vector2(20, 62), Vector2(60, 62), Vector2(70, 68), Vector2(74, 80)])
	fig1.spoly(body1, Color("9e2a2b"), 0.2, -0.3)
	fig1.ell(40, 64, 12, 6, Color("7a1c1d"))
	fig1.ell(40, 63, 8, 4, Color("fcd5b4"))
	# 아기 용포 깃
	fig1.line(30, 64, 50, 64, Color("e0b83a"), 2)
	# 아기 얼굴 (통통한 볼, 맑고 장난기 어린 눈)
	fig1.soft_ball(40, 42, 13.5, 13.0, Color("fce2cb"))
	# 연지곤지 볼
	fig1.rect(28, 44, 4, 3, Color(1.0, 0.6, 0.6, 0.45))
	fig1.rect(48, 44, 4, 3, Color(1.0, 0.6, 0.6, 0.45))
	# 눈: 호기심 어린 큰 눈
	for ex in [34, 46]:
		fig1.rect(ex - 1, 40, 4, 4, INK)
		fig1.px(ex, 40, Color.WHITE)
		fig1.px(ex + 1, 41, Color.WHITE)
	# 입: 칭얼거리듯 살짝 벌린 입
	fig1.rect(38, 49, 4, 3, Color("b23b3b"))
	fig1.px(39, 49, Color("ffeef0"))
	# 삐뚤어진 익선관 (왼쪽으로 기울어짐)
	fig1.spoly(PackedVector2Array([Vector2(26, 26), Vector2(28, 12), Vector2(34, 9), Vector2(46, 12), Vector2(50, 29), Vector2(32, 29)]), Color("1c1c24"), 0.3, -0.2)
	# 삐뚤어진 관 날개
	fig1.spoly(PackedVector2Array([Vector2(25, 14), Vector2(14, 10), Vector2(12, 14), Vector2(23, 20)]), Color("14141b"))
	fig1.spoly(PackedVector2Array([Vector2(44, 15), Vector2(58, 8), Vector2(59, 12), Vector2(48, 20)]), Color("14141b"))
	fig1.line(14, 10, 25, 14, Color("e0b83a"))
	fig1.line(58, 8, 44, 15, Color("e0b83a"))
	fig1.rect(28, 26, 24, 2, Color("e0b83a"))
	var img1 := _finish(bg1, fig1, Color("b89a40"), Color("e0b83a"))
	img1.save_png("res://assets/portraits/crown_prince/stage_01.png")

	# 2단계: 어린이 (21~40점)
	# 단정해진 아동용 배자, 똘망똘망한 큰 눈, 호기심 어린 시선, 붓을 쥐고 있음
	var bg2 := _make_bg(Color("edf7ed"), Color("a3cfbb"))
	var fig2 := PixelArt.new(S, S)
	var body2 := PackedVector2Array([Vector2(8, 80), Vector2(12, 66), Vector2(22, 59), Vector2(58, 59), Vector2(68, 66), Vector2(72, 80)])
	fig2.spoly(body2, Color("2d6a4f"), 0.18, -0.25)
	# 배자 깃 및 동정
	fig2.poly(PackedVector2Array([Vector2(32, 60), Vector2(48, 60), Vector2(40, 72)]), Color("f8f9fa"))
	fig2.line(32, 60, 40, 72, Color("d8f3dc"), 2)
	fig2.line(48, 60, 40, 72, Color("d8f3dc"), 2)
	# 붓 들고 있음 (앞쪽)
	fig2.line(55, 62, 65, 52, Color("8b5a2b"), 2)
	fig2.rect(64, 50, 3, 4, Color("222222"))
	# 어린이 얼굴
	fig2.soft_ball(40, 38, 12.5, 13.0, Color("fce5d0"))
	# 총명하고 똘망똘망한 눈
	for ex in [34, 46]:
		fig2.rect(ex - 2, 36, 5, 5, Color("ffffff"))
		fig2.rect(ex - 1, 37, 3, 4, INK)
		fig2.px(ex - 1, 37, Color.WHITE)
	# 부드러운 눈썹
	fig2.line(31, 33, 37, 33, Color("402d20"), 2)
	fig2.line(43, 33, 49, 33, Color("402d20"), 2)
	# 방긋 웃는 입
	fig2.line(37, 45, 43, 45, Color("b23b3b"))
	fig2.px(36, 44, Color("b23b3b"))
	fig2.px(44, 44, Color("b23b3b"))
	# 단정한 아동 복건/호건
	fig2.spoly(PackedVector2Array([Vector2(28, 28), Vector2(30, 15), Vector2(36, 11), Vector2(44, 11), Vector2(50, 15), Vector2(52, 28)]), Color("1b263b"), 0.25, -0.2)
	fig2.rect(28, 26, 24, 3, Color("e0a96d"))
	var img2 := _finish(bg2, fig2, Color("2d6a4f"), Color("74c69d"))
	img2.save_png("res://assets/portraits/crown_prince/stage_02.png")

	# 3단계: 사춘기 (41~60점)
	# 키가 훌쩍 자람, 찡그린 진지한 눈매, 고뇌하는 표정
	var bg3 := _make_bg(Color("f4ede4"), Color("b08968"))
	var fig3 := PixelArt.new(S, S)
	var body3 := PackedVector2Array([Vector2(6, 80), Vector2(10, 64), Vector2(20, 56), Vector2(60, 56), Vector2(70, 64), Vector2(74, 80)])
	fig3.spoly(body3, Color("415a77"), 0.2, -0.28)
	# 옷깃
	fig3.poly(PackedVector2Array([Vector2(31, 57), Vector2(49, 57), Vector2(40, 72)]), Color("e0e1dd"))
	fig3.line(31, 57, 40, 72, Color("778da9"), 2)
	fig3.line(49, 57, 40, 72, Color("778da9"), 2)
	# 얼굴: 소년~청년 과도기 날렵한 턱선
	fig3.soft_ball(40, 36, 11.5, 14.0, Color("f7d6b5"))
	fig3.poly(PackedVector2Array([Vector2(32, 42), Vector2(48, 42), Vector2(42, 50), Vector2(38, 50)]), Color("f7d6b5"))
	# 눈: 진지하고 고뇌하는 눈매
	for ex in [34, 46]:
		fig3.rect(ex - 2, 35, 5, 3, Color("ffffff"))
		fig3.rect(ex - 1, 35, 3, 3, INK)
		fig3.rect(ex - 3, 34, 6, 1, Color("251b14"))
	# 미간 찌푸린 눈썹
	fig3.line(30, 32, 37, 34, Color("251b14"), 2)
	fig3.line(43, 34, 50, 32, Color("251b14"), 2)
	fig3.line(39, 32, 41, 34, Color("c49a75")) # 미간 주름
	# 굳게 다문 입술
	fig3.line(37, 45, 43, 45, Color("8d3b3b"))
	# 청년 유생 모자 (정자관)
	fig3.spoly(PackedVector2Array([Vector2(30, 27), Vector2(30, 14), Vector2(34, 14), Vector2(34, 9), Vector2(40, 12), Vector2(46, 9), Vector2(46, 14), Vector2(50, 14), Vector2(50, 27)]), Color("1c1c24"), 0.26, -0.22)
	fig3.rect(30, 23, 20, 4, Color("2a2a38"))
	var img3 := _finish(bg3, fig3, Color("5c4033"), Color("b08968"))
	img3.save_png("res://assets/portraits/crown_prince/stage_03.png")

	# 4단계: 청년 (61~80점)
	# 늠름한 체구, 단단한 자세, 칠성검/병법서, 무관/문관 조화
	var bg4 := _make_bg(Color("ebf2fa"), Color("468faf"))
	var fig4 := PixelArt.new(S, S)
	# 듬직하고 넓은 어깨, 무복/철릭
	var body4 := PackedVector2Array([Vector2(4, 80), Vector2(8, 62), Vector2(18, 54), Vector2(62, 54), Vector2(72, 62), Vector2(76, 80)])
	fig4.spoly(body4, Color("1d3557"), 0.2, -0.3)
	# 붉은 전대/술띠
	fig4.rect(8, 72, 64, 4, Color("e63946"))
	# 어깨 뒤로 비치는 칠성검 손잡이
	fig4.line(20, 60, 12, 42, Color("d4af37"), 3)
	fig4.rect(10, 40, 6, 4, Color("e63946"))
	# 얼굴: 늠름하고 당당함
	fig4.soft_ball(40, 35, 12.0, 14.5, Color("f5cfab"))
	# 눈: 형형한 무장의 눈빛
	for ex in [34, 46]:
		fig4.rect(ex - 2, 34, 5, 3, Color("ffffff"))
		fig4.rect(ex - 1, 34, 3, 3, INK)
		fig4.px(ex, 34, Color("61a5c2"))
		fig4.rect(ex - 3, 33, 6, 1, INK)
	# 호기찬 기상의 눈썹 (올라간 눈썹)
	fig4.line(29, 31, 37, 30, Color("1f1610"), 2)
	fig4.line(43, 30, 51, 31, Color("1f1610"), 2)
	# 굳센 입매
	fig4.line(36, 44, 44, 44, Color("7a2828"), 2)
	# 늠름한 융복 전립 (붉은 상모)
	fig4.ell(40, 24, 20, 5, Color("202028"))
	fig4.ball(40, 18, 12, 8, Color("252530"))
	fig4.ball(40, 9, 3.5, 3.5, Color("e63946")) # 붉은 상모
	fig4.line(40, 10, 35, 4, Color("ffb703"))
	fig4.line(40, 10, 45, 5, Color("ffb703"))
	var img4 := _finish(bg4, fig4, Color("1d3557"), Color("457b9d"))
	img4.save_png("res://assets/portraits/crown_prince/stage_04.png")

	# 5단계: 책벌레 (81~99점)
	# 은테 수정 안경 착용, 깊은 지혜의 온화한 눈빛, 두루마리 책을 든 학자적 면모
	var bg5 := _make_bg(Color("fdfbf7"), Color("b5a886"))
	var fig5 := PixelArt.new(S, S)
	var body5 := PackedVector2Array([Vector2(6, 80), Vector2(10, 63), Vector2(19, 55), Vector2(61, 55), Vector2(70, 63), Vector2(74, 80)])
	fig5.spoly(body5, Color("3d5a80"), 0.22, -0.32)
	# 옥색 깃
	fig5.poly(PackedVector2Array([Vector2(32, 56), Vector2(48, 56), Vector2(40, 71)]), Color("e0fbfc"))
	fig5.line(32, 56, 40, 71, Color("98c1d9"), 2)
	fig5.line(48, 56, 40, 71, Color("98c1d9"), 2)
	# 얼굴
	fig5.soft_ball(40, 35, 12.0, 14.0, Color("f7d7b7"))
	# 은테 수정 안경 (정조의 안경 고증)
	# 안경 알 2개
	fig5.rect(31, 33, 7, 6, Color(0.7, 0.85, 0.95, 0.35))
	fig5.circle_ring(34, 36, 4, Color("c0c0c8"))
	fig5.rect(43, 33, 7, 6, Color(0.7, 0.85, 0.95, 0.35))
	fig5.circle_ring(46, 36, 4, Color("c0c0c8"))
	# 안경 코다리
	fig5.line(38, 35, 42, 35, Color("c0c0c8"), 2)
	# 안경 너머 온화하고 깊은 눈
	for ex in [34, 46]:
		fig5.rect(ex - 1, 35, 3, 3, INK)
		fig5.px(ex, 35, Color.WHITE)
	# 지적인 눈썹
	fig5.line(30, 30, 37, 30, Color("201610"), 2)
	fig5.line(43, 30, 50, 30, Color("201610"), 2)
	# 온화한 미소
	fig5.line(37, 45, 43, 45, Color("7a2b2b"))
	fig5.px(36, 44, Color("7a2b2b"))
	fig5.px(44, 44, Color("7a2b2b"))
	# 유려한 관모 (사모/갓 형태 학자관)
	fig5.spoly(PackedVector2Array([Vector2(30, 26), Vector2(31, 12), Vector2(35, 8), Vector2(45, 8), Vector2(49, 12), Vector2(50, 26)]), Color("191924"), 0.3, -0.2)
	fig5.rect(29, 23, 22, 3, Color("2d2d3a"))
	# 두루마리 책 (손에 쥠)
	fig5.rect(60, 60, 6, 16, Color("f4f1de"))
	fig5.line(60, 60, 66, 60, Color("e07a5f"), 2)
	fig5.line(60, 76, 66, 76, Color("e07a5f"), 2)
	var img5 := _finish(bg5, fig5, Color("293241"), Color("98c1d9"))
	img5.save_png("res://assets/portraits/crown_prince/stage_05.png")

	# 6단계: 성인 군주 (100점 완성)
	# 찬란한 황금빛 붉은 곤룡포, 단정하고 위엄 있는 정통 익선관, 완성형 성군
	var bg6 := _make_bg(Color("fff3b0"), Color("9e2a2b"))
	var fig6 := PixelArt.new(S, S)
	var body6 := PackedVector2Array([Vector2(4, 80), Vector2(8, 62), Vector2(18, 54), Vector2(62, 54), Vector2(72, 62), Vector2(76, 80)])
	fig6.spoly(body6, Color("9e2a2b"), 0.22, -0.32)
	# 붉은 곤룡포 가슴 황금 보 (오조룡보)
	fig6.ball(40, 71, 8, 7, Color("ffd166"))
	fig6.ell(40, 71, 5, 4, Color("801a1a"))
	fig6.px(40, 70, Color("fff3b0"))
	for pp in [Vector2i(30, 67), Vector2i(50, 67), Vector2i(30, 75), Vector2i(50, 75)]:
		fig6.rect(pp.x, pp.y, 4, 3, Color("ffd166"))
	# 목과 동정
	fig6.ell(40, 58, 11, 5, Color("7a1919"))
	fig6.ell(40, 56.5, 7, 3.5, Color("f7d5b5"))
	fig6.line(30, 58, 50, 58, Color("ffd166"), 2)
	# 당당하고 인자한 성인 군주 얼굴
	fig6.soft_ball(40, 34, 12.5, 14.5, Color("f7d5b5"))
	# 눈: 깊고 위엄 있는 성군의 눈
	for ex in [34, 46]:
		fig6.rect(ex - 2, 33, 5, 3, Color("ffffff"))
		fig6.rect(ex - 1, 33, 3, 3, INK)
		fig6.px(ex, 33, Color.WHITE)
		fig6.rect(ex - 3, 32, 6, 1, INK)
	# 짙고 곧은 제왕의 눈썹
	fig6.line(29, 29, 37, 29, Color("1f1610"), 2)
	fig6.line(43, 29, 51, 29, Color("1f1610"), 2)
	# 단정한 콧날과 입술
	fig6.px(40, 38, Color("dca87d"))
	fig6.px(40, 39, Color("dca87d"))
	fig6.line(37, 43, 43, 43, Color("701c1c"), 2)
	# 엷고 단정한 군주의 수염
	fig6.line(33, 41, 37, 40, Color("1f1610"))
	fig6.line(47, 41, 43, 40, Color("1f1610"))
	fig6.ball(40, 48, 4, 3, Color("1f1610"))
	# 위엄 있는 정통 익선관
	# 좌우 매미 날개
	fig6.spoly(PackedVector2Array([Vector2(32, 11), Vector2(18, 4), Vector2(16, 8), Vector2(29, 18)]), Color("14141b"))
	fig6.spoly(PackedVector2Array([Vector2(48, 11), Vector2(62, 4), Vector2(64, 8), Vector2(51, 18)]), Color("14141b"))
	fig6.line(18, 4, 32, 11, Color("ffd166"), 2)
	fig6.line(62, 4, 48, 11, Color("ffd166"), 2)
	# 관 본체
	fig6.spoly(PackedVector2Array([Vector2(29, 26), Vector2(30, 11), Vector2(35, 6), Vector2(45, 6), Vector2(50, 11), Vector2(51, 26)]), Color("1c1c24"), 0.3, -0.2)
	fig6.rect(29, 23, 23, 3, Color("3a3a48"))
	fig6.rect(29, 23, 23, 1, Color("ffd166"))
	fig6.ball(40, 13, 3.0, 3.0, Color("ffd166"))
	var img6 := _finish(bg6, fig6, Color("9e2a2b"), Color("ffd166"))
	img6.save_png("res://assets/portraits/crown_prince/stage_06.png")
