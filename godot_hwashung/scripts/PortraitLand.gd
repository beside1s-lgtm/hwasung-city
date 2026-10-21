extends RefCounted
class_name PortraitLand

## 살피기 팝업의 지형(들판·산·하천·숲·잿더미)과 장소(도적 소굴·사대문·수리시설·관청) 도트 그림(80x80).
## 그 칸이 실제로 무엇인지에 딱 맞는 그림이 나오도록 따로 둔다.

const S := 80
const KEYS := ["plain", "mountain", "river", "forest", "burned", "bandit_camp", "bandit_camp_cleared", "gate_jangan", "gate_paldal", "gate_hwaseo",
	"gate_changryong", "reservoir", "chukmanje", "jinhulso", "firestation", "hyanggyo", "patrol_post", "paddy", "daeyu", "wild_boar"]

static func has(key: String) -> bool:
	return KEYS.has(key)

static func make(key: String) -> ImageTexture:
	var bg := PixelArt.new(S, S)
	var f := PixelArt.new(S, S)
	match key:
		"plain":
			_plain(bg, f)
		"mountain":
			_mountain(bg, f)
		"river":
			_river(bg, f)
		"forest":
			_forest(bg, f)
		"burned":
			_burned(bg, f)
		"bandit_camp":
			_bandit(bg, f, false)
		"bandit_camp_cleared":
			_bandit(bg, f, true)
		"gate_jangan", "gate_paldal", "gate_hwaseo", "gate_changryong":
			_gate(bg, f, key)
		"reservoir":
			_reservoir(bg, f, false)
		"chukmanje":
			_reservoir(bg, f, true)
		"jinhulso":
			_jinhulso(bg, f)
		"firestation":
			_firestation(bg, f)
		"hyanggyo":
			_hyanggyo(bg, f)
		"patrol_post":
			_patrol(bg, f)
		"paddy":
			_paddy(bg, f, false)
		"daeyu":
			_paddy(bg, f, true)
		"wild_boar":
			PortraitScenes.sky(bg, Color("a8cde8"), Color("e8f0dc"), 50)
			PortraitScenes.hills(bg, 46, 12.0, Color("7a9a78"), 3.0)
			PortraitScenes.grass(bg, 54, Color("78a458"), Color("4a7a3a"))
			PortraitScenes.pine(bg, 8, 54, 0.8)
			PortraitScenes.pine(bg, 72, 54, 0.7)
			_boar(f)
		_:
			return null
	var night := key.begins_with("bandit")
	f.outline(Color("0e0c14") if night else Color("1f1812"))
	return PortraitArt._finish(bg, f, Color("7a5835"), Color("c9b28b"))

# ─────────────────────────────────────────── 지형
static func _plain(bg: PixelArt, f: PixelArt) -> void:
	PortraitScenes.sky(bg, Color("8fc4ec"), Color("f4f0dc"), 44)
	PortraitScenes.cloud(bg, 8, 12, 1.0)
	PortraitScenes.cloud(bg, 48, 20, 0.8)
	PortraitScenes.hills(bg, 42, 7.0, Color("9ab890"), 0.9, 0.07)
	PortraitScenes.hills(bg, 46, 5.0, Color("86b070"), 2.2, 0.09)
	# 멀리서 가까이로 갈수록 짙고 거친 풀밭(원근 줄무늬)
	for y in range(44, 80):
		var t := float(y - 44) / 36.0
		for x in range(80):
			var thr: float = PixelArt.BAYER[y & 1][x & 1] * 0.18
			var band := 0.5 + 0.5 * sin(float(y) * (0.9 - t * 0.5) + float(x) * 0.02)
			var c := Color("a8cf72").lerp(Color("5a9a40"), clampf(t * 0.9 + thr, 0.0, 1.0))
			if band > 0.72:
				c = PixelArt.shade(c, 0.07)
			bg.px(x, y, c)
	# 들꽃과 풀포기
	var flowers := [Color("f8e060"), Color("f4a8c0"), Color("ffffff"), Color("b8a0e8")]
	for k in range(46):
		var fx := (k * 41 + 7) % 78
		var fy := 48 + (k * 23) % 30
		var sz := 1 if fy < 60 else 2
		bg.rect(fx, fy, sz, sz, flowers[k % 4])
		if fy > 62:
			bg.px(fx, fy + 2, Color("3a7a30"))
			bg.px(fx, fy + sz, Color("3a7a30"))
	for k in range(14):
		var gx := (k * 53 + 3) % 76
		var gy := 52 + (k * 19) % 26
		bg.line(gx, gy, gx - 1, gy - 3, Color("3f7a34"))
		bg.line(gx + 1, gy, gx + 2, gy - 3, Color("4a8a3a"))
	# 한 그루 큰 나무와 새, 희미한 농로
	PortraitScenes.round_tree(f, 62, 56, 8, Color("4a8a46"))
	PortraitScenes.pine(f, 12, 52, 0.9)
	for p in [Vector2i(22, 22), Vector2i(30, 17), Vector2i(60, 26)]:
		f.line(p.x - 2, p.y, p.x, p.y + 1, Color("2a2a30"))
		f.line(p.x, p.y + 1, p.x + 2, p.y, Color("2a2a30"))

static func _mountain(bg: PixelArt, f: PixelArt) -> void:
	PortraitScenes.sky(bg, Color("9cc4e8"), Color("f0ece0"), 50)
	PortraitScenes.cloud(bg, 52, 10, 0.8)
	PortraitScenes.hills(bg, 46, 18.0, Color("a8b8c0"), 0.4, 0.09) # 먼 산
	PortraitScenes.hills(bg, 54, 16.0, Color("7a9a88"), 2.2, 0.1)
	# 가운데 큰 암봉(기암괴석)
	f.spoly(PackedVector2Array([Vector2(8, 80), Vector2(14, 56), Vector2(24, 42), Vector2(32, 30), Vector2(40, 12), Vector2(46, 26), Vector2(54, 36), Vector2(66, 52), Vector2(74, 80)]), Color("8a8c84"), 0.24, -0.34)
	f.poly(PackedVector2Array([Vector2(40, 12), Vector2(46, 26), Vector2(54, 36), Vector2(48, 40), Vector2(44, 32), Vector2(40, 38), Vector2(38, 24)]), Color("6a6c66"))
	# 바위 결과 균열
	for k in [[30, 36, 36, 60], [44, 30, 50, 52], [22, 52, 28, 70], [56, 48, 62, 68], [38, 44, 40, 64]]:
		f.line(k[0], k[1], k[2], k[3], Color("5a5c56"))
	for k in range(9):
		f.line(18 + k * 6, 56 + (k % 3) * 6, 22 + k * 6, 58 + (k % 3) * 6, Color("a8aaa2"))
	# 비탈의 소나무와 활엽수
	PortraitScenes.pine(f, 10, 74, 0.9)
	PortraitScenes.pine(f, 22, 70, 0.8)
	PortraitScenes.pine(f, 66, 74, 1.0)
	PortraitScenes.pine(f, 56, 66, 0.7)
	PortraitScenes.round_tree(f, 74, 70, 6, Color("c8903a"))
	PortraitScenes.round_tree(f, 4, 66, 6, Color("5a9a4a"))
	# 산허리 안개
	for k in range(5):
		f.ell(14.0 + float(k) * 14.0, 62.0 + float(k % 2) * 4.0, 14.0, 3.0, Color(1, 1, 1, 0.45))

static func _river(bg: PixelArt, f: PixelArt) -> void:
	PortraitScenes.sky(bg, Color("9ccaee"), Color("f4f0e0"), 36)
	PortraitScenes.cloud(bg, 6, 8, 0.9)
	PortraitScenes.hills(bg, 36, 14.0, Color("8aa8a0"), 1.0, 0.08)
	PortraitScenes.grass(bg, 36, Color("86b45a"), Color("5a8844"))
	# 구불구불 흐르는 시내(위는 좁고 아래는 넓다)
	for y in range(36, 80):
		var t := float(y - 36) / 44.0
		var cx := 40.0 + sin(float(y) * 0.11) * (6.0 + t * 6.0)
		var half := 4.0 + t * 24.0
		for x in range(int(cx - half), int(cx + half) + 1):
			var th: float = PixelArt.BAYER[y & 1][x & 1] * 0.2
			var c := Color("7cc4ec").lerp(Color("3a86b8"), clampf(t * 0.8 + th * 0.5, 0.0, 1.0))
			bg.px(x, y, c)
		bg.px(int(cx - half) - 1, y, Color("c8b890")) # 모래톱
		bg.px(int(cx + half) + 1, y, Color("c8b890"))
		if (y * 7) % 11 == 0:
			var rx := int(cx - half * 0.5)
			bg.line(rx, y, rx + 4, y, Color(1, 1, 1, 0.7))
		if (y * 5) % 13 == 0:
			var rx2 := int(cx + half * 0.2)
			bg.line(rx2, y, rx2 + 3, y, Color(1, 1, 1, 0.55))
	# 하늘빛이 비친 물빛
	for k in range(6):
		bg.ell(40.0 + sin(float(k) * 2.0) * 10.0, 56.0 + float(k) * 4.0, 7.0, 1.2, Color(1, 1, 1, 0.22))
	PortraitScenes.willow(f, 10, 62)
	PortraitScenes.willow(f, 70, 56)
	PortraitScenes.willow(f, 66, 74)
	# 징검다리와 물가 돌
	for k in range(5):
		f.ell(28.0 + float(k) * 6.0, 66.0 + sin(float(k)) * 2.0, 3.2, 2.0, Color("b0aca0"))
	for p in [Vector2i(6, 74), Vector2i(14, 72), Vector2i(20, 77)]:
		f.ell(float(p.x), float(p.y), 3.0, 2.0, Color("9a968a"))
	# 청둥오리 두 마리와 백로
	f.ell(44, 52, 3.2, 1.8, Color("7a6a50"))
	f.ball(47, 50, 1.6, 1.6, Color("2a6a4a"))
	f.px(49, 50, Color("e8c040"))
	f.ell(52, 56, 3.2, 1.8, Color("8a7a60"))
	f.ball(55, 54, 1.6, 1.6, Color("2a6a4a"))
	f.px(57, 54, Color("e8c040"))
	f.line(24, 46, 24, 40, Color("f4f2ec"), 2)
	f.ball(24, 38, 1.8, 1.8, Color("f4f2ec"))
	f.px(26, 38, Color("e8c040"))
	f.ell(24, 47, 4, 2, Color("f4f2ec"))

static func _forest(bg: PixelArt, f: PixelArt) -> void:
	PortraitScenes.sky(bg, Color("a8d0e8"), Color("e8f0d8"), 40)
	PortraitScenes.hills(bg, 44, 12.0, Color("6a8a70"), 1.3)
	PortraitScenes.grass(bg, 46, Color("5a8a44"), Color("3a6a32"))
	# 햇살 줄기
	for k in range(4):
		var x0 := 20 + k * 14
		bg.poly(PackedVector2Array([Vector2(x0, 0), Vector2(x0 + 5, 0), Vector2(x0 + 18, 70), Vector2(x0 + 8, 70)]), Color(1, 0.98, 0.8, 0.13))
	# 줄기 붉은 소나무들(앞줄이 크다)
	var spots := [Vector3(10, 66, 1.3), Vector3(30, 60, 1.0), Vector3(52, 62, 1.2), Vector3(70, 58, 1.0), Vector3(20, 54, 0.8), Vector3(44, 52, 0.7), Vector3(62, 52, 0.7)]
	spots.sort_custom(func(a, b): return a.y < b.y)
	for p: Vector3 in spots:
		var h := int(26.0 * p.z)
		f.rect(int(p.x) - 1, int(p.y) - h, 3, h, Color("a85a38"))
		f.rect(int(p.x) - 1, int(p.y) - h, 1, h, Color("c87a50"))
		PortraitScenes.pine(f, int(p.x), int(p.y) - h + 14, 1.0 * p.z)
	# 고사리 덤불과 버섯, 숲속 사슴 한 마리
	for k in range(9):
		var fx := 4 + k * 9
		f.line(fx, 76, fx - 3, 70, Color("4a8a3a"))
		f.line(fx, 76, fx + 3, 70, Color("5a9a44"))
		f.line(fx, 76, fx, 69, Color("3a7a32"))
	f.ball(34, 74, 2, 1.6, Color("d8503a"))
	f.px(33, 73, Color("ffffff"))
	PortraitFolk._deer(f, 56, 76, 0.55)

static func _burned(bg: PixelArt, f: PixelArt) -> void:
	PortraitScenes.sky(bg, Color("5a5058"), Color("c8a888"), 52)
	PortraitScenes.hills(bg, 50, 10.0, Color("4a4448"), 2.3)
	for y in range(52, 80):
		for x in range(80):
			var thr: float = PixelArt.BAYER[y & 1][x & 1] * 0.16
			bg.px(x, y, Color("4a4038").lerp(Color("2a2420"), clampf(float(y - 52) / 28.0 + thr, 0.0, 1.0)))
	for k in range(30):
		bg.px((k * 37 + 5) % 78, 54 + (k * 13) % 24, Color("7a6a5c"))
	# 그을린 기둥·서까래·깨진 기와
	for p in [Vector3(14, 66, 22), Vector3(30, 70, 14), Vector3(50, 64, 26), Vector3(66, 70, 12)]:
		f.rect(int(p.x), int(p.y - p.z), 3, int(p.z), Color("2a2420"))
		f.rect(int(p.x), int(p.y - p.z), 1, int(p.z), Color("4a3a30"))
	f.line(14, 44, 32, 58, Color("2a2420"), 2)
	f.line(50, 38, 66, 58, Color("2a2420"), 2)
	for k in range(8):
		f.rect(8 + k * 9, 72 + (k % 3), 6, 2, Color("5a5a60"))
		f.px(10 + k * 9, 72 + (k % 3), Color("8a8a90"))
	# 아직 붉은 불씨와 연기
	for p in [Vector2i(22, 72), Vector2i(40, 74), Vector2i(58, 73)]:
		f.ball(float(p.x), float(p.y), 2.2, 1.6, Color("e8602a"))
		f.px(p.x, p.y - 1, Color("ffd060"))
	PortraitScenes.smoke(f, 24, 66, 5)
	PortraitScenes.smoke(f, 56, 62, 4)

# ─────────────────────────────────────────── 도적 소굴
static func _bandit(bg: PixelArt, f: PixelArt, cleared: bool) -> void:
	if cleared:
		PortraitScenes.sky(bg, Color("8fb4d8"), Color("e8dcc8"), 52)
	else:
		PortraitScenes.sky(bg, Color("2a2438"), Color("8a5a48"), 54)
		for k in range(10):
			bg.px((k * 29 + 7) % 78, (k * 11 + 3) % 24, Color("e8e0c0"))
	# 험한 바위 산자락
	PortraitScenes.hills(bg, 50, 16.0, Color("4a4a50") if not cleared else Color("6a7a70"), 1.0)
	for y in range(56, 80):
		for x in range(80):
			var thr: float = PixelArt.BAYER[y & 1][x & 1] * 0.2
			bg.px(x, y, (Color("5a4a3a") if not cleared else Color("8a7a58")).lerp(Color("2a2018") if not cleared else Color("5a4a30"), clampf(float(y - 56) / 24.0 + thr, 0.0, 1.0)))
	# 바위 더미
	f.spoly(PackedVector2Array([Vector2(0, 66), Vector2(6, 46), Vector2(18, 40), Vector2(28, 52), Vector2(30, 70)]), Color("5a5a60"), 0.2, -0.34)
	f.spoly(PackedVector2Array([Vector2(56, 70), Vector2(60, 50), Vector2(72, 42), Vector2(80, 54), Vector2(80, 72)]), Color("54545a"), 0.2, -0.34)
	# 거친 목책
	for k in range(7):
		var px_ := 4 + k * 11
		f.poly(PackedVector2Array([Vector2(px_, 72), Vector2(px_ + 3, 72), Vector2(px_ + 3, 60), Vector2(px_ + 1, 56), Vector2(px_, 60)]), Color("6a4a2c"))
	f.line(4, 66, 74, 66, Color("5a3a22"), 2)
	# 움막(토굴 위 볏짚과 억새를 엮은 원추형 토포 초막)
	if not cleared:
		# 1) 움막 흙벽 및 돌담 기단
		f.poly(PackedVector2Array([Vector2(10, 68), Vector2(40, 68), Vector2(38, 56), Vector2(12, 56)]), Color("4a3525"))
		f.line(10, 68, 40, 68, Color("2a1a10"), 1)
		# 2) 둥근 억새·이엉 지붕 (원추형 움막)
		f.spoly(PackedVector2Array([Vector2(6, 58), Vector2(25, 34), Vector2(44, 58)]), Color("7a5d38"), 0.18, -0.3)
		f.spoly(PackedVector2Array([Vector2(8, 57), Vector2(25, 34), Vector2(32, 57)]), Color("8f6f43"), 0.15, -0.2)
		# 지붕 볏짚단 결 및 새끼줄 묶음
		f.line(10, 52, 38, 52, Color("4a3620"))
		f.line(14, 44, 34, 44, Color("4a3620"))
		for k in range(5):
			f.line(9 + k * 7, 57, 25, 35, Color("9e7d4d"))
		# 3) 움막 입구 거적문 (어두운 내부와 멍석 채양)
		f.poly(PackedVector2Array([Vector2(19, 68), Vector2(29, 68), Vector2(27, 54), Vector2(21, 54)]), Color("140e0a"))
		f.poly(PackedVector2Array([Vector2(18, 54), Vector2(30, 54), Vector2(28, 50), Vector2(20, 50)]), Color("5c4228"))
		f.line(19, 68, 19, 54, Color("2b180d"), 1)
		f.line(29, 68, 29, 54, Color("2b180d"), 1)

		# 4) 우측 보조 가마니·약탈품 궤짝 및 가죽 건조대
		f.rect(45, 62, 8, 6, Color("4e3520")) # 보물 상자
		f.line(45, 62, 53, 62, Color("6d4c2e"), 1)
		f.line(45, 65, 53, 65, Color("24170e"), 1)
		f.ball(57.0, 64.0, 4.0, 3.0, Color("8f7347")) # 볏짚 가마니
		# 가죽 건조대
		f.line(62, 68, 62, 50, Color("3d2919"), 2)
		f.line(72, 68, 72, 50, Color("3d2919"), 2)
		f.line(60, 52, 74, 52, Color("4a321e"), 1)
		f.poly(PackedVector2Array([Vector2(63, 53), Vector2(71, 53), Vector2(70, 62), Vector2(64, 61)]), Color("9e5a23"))

		# 5) 거친 해골/도깨비 깃발
		f.line(75, 48, 75, 26, Color("212529"), 2)
		f.poly(PackedVector2Array([Vector2(75, 26), Vector2(64, 31), Vector2(75, 36)]), Color("1c1917"))
		f.px(70, 31, Color("b91c1c")) # 붉은 표식
	else:
		# 토벌된 상태: 무너진 움막 잔해, 불탄 잿더미와 장용영 승전 깃발, 군졸
		f.poly(PackedVector2Array([Vector2(8, 68), Vector2(24, 58), Vector2(42, 68)]), Color("4a3a2d"))
		f.line(12, 64, 30, 68, Color("24170d"), 2)
		f.line(20, 56, 38, 66, Color("1f140a"), 2)
		f.line(48, 68, 62, 62, Color("2b180d"), 2)
		PortraitScenes.flag(f, 40, 30, Color("c0392b"), 30)
		PortraitScenes.flag(f, 54, 36, Color("2f67c0"), 26)
		PortraitScenes.person(f, 30, 72, Color("224870"), "jeonlip")
		PortraitScenes.person(f, 48, 74, Color("6a2a2a"), "jeonlip")
		PortraitScenes.person(f, 62, 72, Color("224870"), "jeonlip")
		PortraitScenes.smoke(f, 18, 54, 3)
		return
	# 횃불 두 개와 모닥불(거친 밤 불빛)
	for tp in [Vector2i(36, 50), Vector2i(76, 62)]:
		f.line(tp.x, tp.y, tp.x, tp.y + 18, Color("5a3a22"), 2)
		f.ball(float(tp.x), float(tp.y) - 2.0, 3.0, 4.0, Color("f28a30"))
		f.ball(float(tp.x), float(tp.y) - 1.0, 1.6, 2.6, Color("ffe070"))
		bg.ell(float(tp.x), float(tp.y), 11.0, 11.0, Color(1.0, 0.7, 0.3, 0.16))
	f.ball(34, 74, 5, 3.4, Color("f28a30"))
	f.ball(34, 73, 3, 2.4, Color("ffd060"))
	f.line(28, 76, 40, 72, Color("5a3a22"), 2)
	f.line(28, 72, 40, 76, Color("5a3a22"), 2)
	PortraitScenes.smoke(f, 35, 68, 4)
	# 도적 둘(거친 모습: 헝클어진 머리·낡은 옷·칼)
	PortraitFolk.man(f, 52, 76, Color("6a5a48"), "none", Vector2i(-3, 3), Vector2i(6, -2))
	f.line(59, 62, 62, 74, Color("c8d0d8"))
	PortraitFolk.man(f, 14, 76, Color("5a4a40"), "headband_red", Vector2i(-2, 4), Vector2i(2, 4))

# ─────────────────────────────────────────── 사대문: 문마다 다른 모습
static func _gate(bg: PixelArt, f: PixelArt, key: String) -> void:
	var two := key in ["gate_jangan", "gate_paldal"]
	var big := key == "gate_paldal"
	match key:
		"gate_jangan":
			PortraitScenes.sky(bg, Color("8fb4d8"), Color("e8eef0"), 56)
			PortraitScenes.hills(bg, 44, 18.0, Color("7a90a4"), 0.5, 0.08) # 북쪽 광교산 줄기
		"gate_paldal":
			PortraitScenes.sky(bg, Color("a8d0ec"), Color("f2efe0"), 56)
			PortraitScenes.hills(bg, 46, 14.0, Color("6a8a70"), 2.0, 0.1)
			PortraitScenes.pine(bg, 8, 54, 0.9)
			PortraitScenes.pine(bg, 72, 54, 0.9)
		"gate_hwaseo":
			PortraitScenes.sky(bg, Color("e8905a"), Color("f8d8a0"), 56) # 서쪽: 저녁노을
			bg.ell(18, 40, 8, 8, Color("ffe8b0"))
			PortraitScenes.hills(bg, 46, 12.0, Color("5a4a5a"), 1.0)
		_:
			PortraitScenes.sky(bg, Color("f4b8a8"), Color("fcecc8"), 56) # 동쪽: 해돋이 분홍빛
			bg.ell(62, 44, 9, 9, Color("fff0c0"))
			PortraitScenes.hills(bg, 48, 10.0, Color("7a8a78"), 0.3)
	PortraitScenes.grass(bg, 62, Color("78a458"), Color("5a8844"))
	# 성벽과 육축(문 아래 석축)
	PortraitScenes.stone_wall(f, 0, 50, 80, 14, Color("a6a094"))
	for k in range(0, 80, 8):
		f.rect(k, 46, 5, 4, Color("8a8478"))
	var bx0 := 20
	var bx1 := 60
	var base_top := 36
	if big:
		bx0 = 16
		bx1 = 64
		base_top = 34
	if not two:
		bx0 = 24
		bx1 = 56
		base_top = 40
	PortraitScenes.stone_wall(f, bx0, base_top, bx1 - bx0, 28, Color("b0aa9e"))
	PortraitScenes.arch(f, 40, base_top + 12, 7 if two else 6, 16, Color("1c1814"))
	f.rect(36, base_top + 12, 8, 16, Color("5a3a22"))
	f.line(40, base_top + 12, 40, base_top + 27, Color("2a1a10"))
	# 옹성(문 앞을 에워싼 반원 성벽)
	if key == "gate_jangan" or key == "gate_paldal":
		f.ell(40, 66, 30 if big else 26, 8, Color("a6a094"))
		f.ell(40, 66, 27 if big else 23, 6, Color("8a8478"))
		PortraitScenes.arch(f, 40, 62, 5, 8, Color("1c1814"))
	elif key == "gate_hwaseo":
		f.spoly(PackedVector2Array([Vector2(24, 70), Vector2(24, 60), Vector2(10, 62), Vector2(6, 70)]), Color("a6a094"), 0.2, -0.3)
	else:
		f.spoly(PackedVector2Array([Vector2(56, 70), Vector2(56, 60), Vector2(70, 62), Vector2(74, 70)]), Color("a6a094"), 0.2, -0.3)
	# 문루
	var y0 := base_top - 12
	f.rect(bx0 + 4, y0, bx1 - bx0 - 8, 12, Color("efe8d8"))
	var n := int(float(bx1 - bx0 - 8) / 8.0)
	for k in range(n + 1):
		PortraitScenes.pillar(f, bx0 + 4 + k * 8, y0, 12)
	for k in range(n):
		PortraitScenes.lattice(f, bx0 + 7 + k * 8, y0 + 3, 5, 6)
	if two:
		PortraitScenes.tile_roof(f, bx0 - 2, bx1 + 2, y0 - 8, y0, Color("3c4650"))
		f.rect(bx0 + 8, y0 - 18, bx1 - bx0 - 16, 10, Color("efe8d8"))
		for k in range(int(float(bx1 - bx0 - 16) / 8.0) + 1):
			PortraitScenes.pillar(f, bx0 + 8 + k * 8, y0 - 18, 10)
		PortraitScenes.tile_roof(f, bx0 + 2, bx1 - 2, y0 - 26, y0 - 18, Color("464f5a"))
		PortraitScenes.flag(f, bx0 - 6, y0 - 4, Color("c0392b"), 22)
		PortraitScenes.flag(f, bx1 + 5, y0 - 4, Color("2f67c0"), 22)
		if big:
			PortraitScenes.flag(f, 40, y0 - 38, Color("e8c820"), 12)
			# 팔달문: 남문 앞 장터 차양과 짐을 진 사람들
			for k in range(3):
				f.rect(4 + k * 6, 72, 5, 3, [Color("c0392b"), Color("2f67c0"), Color("e8c040")][k])
				f.rect(52 + k * 7, 72, 5, 3, [Color("2ecc71"), Color("e8c040"), Color("8e44ad")][k])
		else:
			PortraitScenes.flag(f, 40, y0 - 38, Color("c0392b"), 12)
			# 장안문: 정문답게 성벽 위에 깃발이 줄지어 선다
			for fx in [4, 12, 68, 76]:
				PortraitScenes.flag(f, fx, 36, Color("c0392b") if fx < 40 else Color("2f67c0"), 14)
	else:
		PortraitScenes.tile_roof(f, bx0 - 2, bx1 + 2, y0 - 9, y0, Color("3c4650"))
		if key == "gate_hwaseo":
			# 서북공심돈이 곁에 선다
			f.ell(70, 66, 8, 3, Color("a6a094"))
			f.srect(62, 36, 16, 30, Color("5c5853"))
			PortraitScenes.tile_roof(f, 58, 82, 28, 38, Color("4d5762"))
			f.rect(66, 46, 3, 3, Color("141210"))
			f.rect(72, 52, 2, 3, Color("141210"))
		else:
			PortraitScenes.flag(f, bx1 + 6, y0 - 6, Color("c0392b"), 22)
			PortraitScenes.pine(f, 10, 62, 1.0)
	PortraitScenes.person(f, 40, 74, Color("6a2a2a"), "jeonlip")

# ─────────────────────────────────────────── 수리시설·관청·농경
static func _reservoir(bg: PixelArt, f: PixelArt, sunset: bool) -> void:
	if sunset:
		PortraitScenes.sky(bg, Color("f08a50"), Color("fcd8a0"), 38) # 서호낙조
		bg.ell(40, 34, 10, 10, Color("fff0c0"))
		PortraitScenes.hills(bg, 40, 10.0, Color("6a4a5a"), 0.8)
		PortraitScenes.water(bg, 0, 40, 80, 40, Color("f4b070"), Color("c86a58"))
		for k in range(6):
			bg.line(28 + k * 2, 44 + k * 4, 52 - k * 2, 44 + k * 4, Color(1, 0.95, 0.7, 0.7 - float(k) * 0.08))
	else:
		PortraitScenes.sky(bg, Color("9ccaee"), Color("f4f0e0"), 36)
		PortraitScenes.hills(bg, 36, 12.0, Color("8aa8a0"), 1.7)
		PortraitScenes.water(bg, 0, 38, 80, 42, Color("5aa2d0"), Color("2a6a9e"))
		# 연잎과 연꽃
		for k in range(8):
			var lx := 14 + (k * 23) % 56
			var ly := 54 + (k * 9) % 20
			f.ell(float(lx), float(ly), 4.0, 1.8, Color("3a8a4a"))
			if k % 3 == 0:
				f.ball(float(lx), float(ly) - 2.0, 1.8, 1.8, Color("f4a8c0"))
	# 둑과 버드나무, 정자
	f.spoly(PackedVector2Array([Vector2(0, 46), Vector2(80, 46), Vector2(80, 52), Vector2(0, 52)]), Color("8aae58") if not sunset else Color("6a5040"), 0.14, -0.2)
	PortraitScenes.willow(f, 10, 52)
	PortraitScenes.willow(f, 72, 52)
	for k in range(3):
		PortraitScenes.pillar(f, 30 + k * 10, 36, 11, Color("a8342a"))
	PortraitScenes.tile_roof(f, 24, 56, 26, 36, Color("3c4650") if not sunset else Color("3a3040"))
	f.rect(30, 44, 22, 2, Color("8a5a2a"))
	if sunset:
		PortraitScenes.person(f, 62, 52, Color("e8e0cc"), "gat")

static func _jinhulso(bg: PixelArt, f: PixelArt) -> void:
	PortraitScenes.sky(bg, Color("b8cce0"), Color("ece6d8"), 52)
	PortraitScenes.ground_path(bg, 56, Color("c8b898"))
	PortraitScenes.hall(f, 28, 70, 56, 1, Color("5a5048"), Color("e8dcc0"))
	# 큰 가마솥과 죽
	f.ball(24, 62, 10, 8, Color("2a2a30"))
	f.ell(24, 56, 9, 3, Color("e8dcb0"))
	f.rect(14, 64, 20, 3, Color("5a3a22"))
	PortraitScenes.smoke(f, 24, 52, 4)
	f.rect(44, 62, 8, 8, Color("c8b078")) # 쌀가마니
	f.rect(54, 62, 8, 8, Color("c8b078"))
	f.rect(44, 62, 8, 2, Color("a89058"))
	# 죽 한 그릇씩 받는 줄
	for k in range(4):
		PortraitFolk.man(f, 8 + k * 13, 78 + (k & 1) * 0, [Color("b8a888"), Color("9a8a70"), Color("c8b898"), Color("a8987a")][k], "topknot", Vector2i(3, 2), Vector2i(4, 0))
		f.rect(14 + k * 13 - 1, 76, 3, 1, Color("e8e0cc"))

static func _firestation(bg: PixelArt, f: PixelArt) -> void:
	PortraitScenes.sky(bg, Color("b8dcf0"), Color("f4efe0"), 52)
	PortraitScenes.ground_path(bg, 60, Color("cdbf9e"))
	PortraitScenes.hall(f, 16, 62, 64, 1, Color("3c4650"), Color("efe8d8"))
	# 물독·물통·갈고리·사다리·경종
	for k in range(3):
		f.ball(float(66 + k * 0), float(64 - k * 0), 6, 7, Color("7a5230"))
		break
	f.ell(66, 64, 7, 8, Color("7a5230"))
	f.ell(66, 58, 7, 2, Color("5aa0d0"))
	f.rect(6, 56, 4, 14, Color("8a6a40"))
	f.rect(12, 56, 4, 14, Color("8a6a40"))
	for k in range(4):
		f.line(6, 58 + k * 3, 15, 58 + k * 3, Color("a07a48"))
	f.line(60, 40, 72, 28, Color("5a626a"), 2) # 쇠갈고리
	f.line(72, 28, 72, 24, Color("5a626a"), 2)
	f.ball(44, 38, 4, 4, Color("d4af37")) # 경종
	f.line(44, 34, 44, 30, Color("5a3a22"))
	PortraitFolk.man(f, 24, 76, Color("224870"), "headband", Vector2i(4, -3), Vector2i(5, -2))
	f.rect(30, 70, 5, 5, Color("8a5a2a")) # 물통
	f.px(31, 70, Color("5aa0d0"))

static func _hyanggyo(bg: PixelArt, f: PixelArt) -> void:
	PortraitScenes.sky(bg, Color("b8d8ee"), Color("f4efe0"), 52)
	PortraitScenes.hills(bg, 46, 12.0, Color("8aae78"), 1.3)
	PortraitScenes.grass(bg, 60, Color("78a458"), Color("5a8844"))
	# 은행나무
	f.rect(8, 40, 4, 24, Color("5a3a22"))
	f.ball(10, 32, 12, 11, Color("e8c040"))
	f.ball(6, 28, 6, 5, Color("f4d860"))
	PortraitScenes.hall(f, 22, 66, 64, 1, Color("3c4650"), Color("efe8d8"))
	# 홍살문과 하마비
	f.rect(30, 58, 2, 8, Color("b22222"))
	f.rect(46, 58, 2, 8, Color("b22222"))
	f.rect(29, 56, 20, 2, Color("b22222"))
	f.rect(72, 52, 5, 14, Color("9a968a"))
	f.rect(72, 52, 5, 2, Color("b8b4a8"))
	PortraitScenes.person(f, 56, 74, Color("f0eee6"), "gat")

static func _patrol(bg: PixelArt, f: PixelArt) -> void:
	PortraitScenes.sky(bg, Color("5a6a9a"), Color("e8c8a0"), 56) # 해 질 녘
	PortraitScenes.ground_path(bg, 62, Color("b8a888"))
	PortraitScenes.hall(f, 14, 54, 64, 1, Color("3a4048"), Color("e0d8c4"))
	f.rect(60, 36, 12, 12, Color("a8342a")) # 신호 북
	f.ell(66, 36, 6, 2, Color("e8c860"))
	f.rect(62, 48, 2, 18, Color("5a3a22"))
	f.rect(68, 48, 2, 18, Color("5a3a22"))
	for p in [Vector2i(24, 76), Vector2i(48, 76)]:
		PortraitFolk.man(f, p.x, p.y, Color("6a2a2a"), "jeonlip", Vector2i(2, 2), Vector2i(7, -3))
		f.line(p.x + 9, p.y - 14, p.x + 9, p.y - 8, Color("5a3a22"))
		f.ball(float(p.x) + 9.0, float(p.y) - 6.0, 3, 3.6, Color("f28a30"))
		f.ball(float(p.x) + 9.0, float(p.y) - 6.0, 1.6, 2, Color("ffe070"))
		bg.ell(float(p.x) + 9.0, float(p.y) - 6.0, 10, 10, Color(1, 0.8, 0.4, 0.14))

static func _paddy(bg: PixelArt, f: PixelArt, grand: bool) -> void:
	if grand:
		PortraitScenes.sky(bg, Color("8fc4ec"), Color("f8ecc0"), 44)
	else:
		PortraitScenes.sky(bg, Color("a8d0ec"), Color("f0f0dc"), 44)
	PortraitScenes.hills(bg, 42, 12.0, Color("8aae78"), 0.6, 0.08)
	var c1 := Color("e8c040") if grand else Color("86c050")
	var c2 := Color("c8962a") if grand else Color("4a9a3a")
	# 논배미(원근으로 좁아지는 칸)와 논둑
	for y in range(44, 80):
		var t := float(y - 44) / 36.0
		for x in range(80):
			var thr: float = PixelArt.BAYER[y & 1][x & 1] * 0.16
			var c := c1.lerp(c2, clampf(t + thr * 0.8, 0.0, 1.0))
			if (y * 3 + x) % 9 == 0 or ((y + x * 2) % 13 == 0 and t > 0.3):
				c = PixelArt.shade(c, 0.1)
			bg.px(x, y, c)
	for k in range(4):
		var yy := 50 + k * 8 + k * k
		bg.line(0, yy, 80, yy, Color("8a6a40"))
		bg.line(0, yy - 1, 80, yy - 1, Color("a88a58"))
	for k in range(5):
		var xx := 10 + k * 16
		bg.line(xx, 44, xx - 10 + k * 5, 80, Color("8a6a40"))
	if grand:
		# 관개 수로와 풍년 벼단, 풍년 깃발
		f.poly(PackedVector2Array([Vector2(30, 56), Vector2(48, 56), Vector2(60, 80), Vector2(16, 80)]), Color("5aa2d0"))
		f.line(32, 60, 40, 60, Color(1, 1, 1, 0.8))
		f.line(28, 68, 38, 68, Color(1, 1, 1, 0.8))
		for k in range(4):
			f.poly(PackedVector2Array([Vector2(8 + k * 6, 76), Vector2(14 + k * 6, 76), Vector2(11 + k * 6, 66)]), Color("d8a830"))
			f.line(11 + k * 6, 66, 11 + k * 6, 76, Color("a87820"))
		PortraitScenes.flag(f, 68, 36, Color("c0392b"), 24)
		PortraitFolk.man(f, 58, 72, Color("e8e0cc"), "satgat", Vector2i(3, 3), Vector2i(4, 5))
	else:
		# 모내기하는 농부들
		PortraitFolk.man(f, 24, 70, Color("e8e0cc"), "satgat", Vector2i(3, 5), Vector2i(4, 6), Vector2i(-1, 5), Vector2i(2, 5))
		PortraitFolk.man(f, 52, 66, Color("c8d8c0"), "satgat", Vector2i(3, 5), Vector2i(4, 6), Vector2i(-1, 5), Vector2i(2, 5))
		f.ball(66, 72, 5, 3, Color("8a5a2a"))
		f.ell(12, 60, 5, 2, Color("5aa2d0"))
		PortraitScenes.round_tree(f, 72, 50, 6, Color("4a8a46"))

# ─────────────────────────────────────────── 멧돼지(곰처럼 보이지 않게: 긴 주둥이·송곳니·솟은 어깨·가는 다리·갈기)
static func _boar(f: PixelArt) -> void:
	var base := Color("5a4636")
	var dark := Color("2e2218")
	var gy := 66
	# 꼬리(위로 말린 짧은 꼬리)
	f.line(12, 40, 9, 36, dark, 2)
	f.px(9, 35, dark)
	# 뒷다리·앞다리: 가늘고 짧다(발굽)
	for lx: int in [18, 26, 50, 58]:
		var back: bool = lx < 40
		f.spoly(PackedVector2Array([Vector2(lx - 2, 50), Vector2(lx + 3, 50), Vector2(lx + 2, gy), Vector2(lx - 1, gy)]), PixelArt.shade(base, -0.12 if back else 0.0), 0.1, -0.3)
		f.rect(lx - 2, gy - 2, 5, 3, Color("1a1410"))
	# 몸통: 어깨가 높고 엉덩이가 낮은 쐐기 모양
	f.spoly(PackedVector2Array([Vector2(8, 52), Vector2(10, 40), Vector2(24, 36), Vector2(40, 28), Vector2(54, 26), Vector2(62, 34), Vector2(62, 52), Vector2(40, 56), Vector2(20, 56)]), base, 0.2, -0.32)
	# 등을 따라 곧추선 갈기털
	for k in range(14):
		var mx := 14 + k * 3
		var my := 38 - int(float(mx - 14) * 0.2) - (3 if mx > 36 else 0) - (1 if mx > 50 else 0)
		if mx > 52:
			my = 28 + (mx - 52)
		f.line(mx, my + 2, mx - 1, my - 3 - (k % 2), dark, 1)
	# 배와 털결
	f.ell(38, 54, 18, 3, Color("3a2c20"))
	for k in range(8):
		f.line(18 + k * 5, 44, 16 + k * 5, 50, Color("4a382a"))
	# 머리: 낮게 뻗은 긴 쐐기형 + 납작한 코끝(분문)
	f.spoly(PackedVector2Array([Vector2(56, 28), Vector2(66, 32), Vector2(78, 46), Vector2(77, 52), Vector2(66, 54), Vector2(58, 50)]), Color("65503e"), 0.18, -0.3)
	f.ell(77, 49, 3, 3.6, Color("8a6a5a"))
	f.px(76, 48, Color("1a1410"))
	f.px(77, 51, Color("1a1410"))
	# 아래턱에서 솟은 흰 송곳니
	f.poly(PackedVector2Array([Vector2(68, 52), Vector2(72, 53), Vector2(73, 46), Vector2(71, 47)]), Color("f4efe0"))
	# 작은 세모 귀, 작고 사나운 눈
	f.poly(PackedVector2Array([Vector2(56, 28), Vector2(58, 21), Vector2(62, 29)]), dark)
	f.rect(64, 36, 3, 2, Color("e8d8b0"))
	f.px(65, 36, Color("1a1410"))
	f.line(62, 34, 67, 36, dark) # 찌푸린 눈썹
	# 볼 쪽 흰 털
	f.line(60, 44, 66, 48, Color("a8927a"))
	f.line(60, 46, 65, 50, Color("a8927a"))
