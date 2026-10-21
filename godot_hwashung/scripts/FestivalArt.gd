extends RefCounted
class_name FestivalArt

## PORT-TRACE [장마당·세시풍속]: 놀이판 그림. 놀이판 하나 = 관람객 고리 + 연희자 몇 명을 시간 t 하나로
## 움직이는 통합 애니메이션 루프(개별 NPC 연산 없음). 참고 도판: 김홍도풍 장터 그림, 남사당 버나·줄타기,
## 단오 씨름판, 택견 시범, 연날리기, 석전 삽화, 줄다리기·풍물 사진.
## 그리는 순서: 관람객 뒷줄(화면 위쪽) → 연희자 → 관람객 앞줄. 모두 FastDraw(묶음 그리기)로.

const SKIN := Color("e6bf98")
const WHITE := Color("f2eee4")
const GAT := Color("1a1a1a")

static func draw_all(ci: CanvasItem, fs: FestivalSystem, city: CityLayer, grid: GameGrid) -> void:
	var t := fs.anim_t
	for sc in fs.scenes:
		var cpos: Vector2 = sc["center"]
		var tx := clampi(int(cpos.x), 0, grid.size - 1)
		var ty := clampi(int(cpos.y), 0, grid.size - 1)
		var c := city.cell_center(cpos.x, cpos.y, grid.grid[ty][tx]["elevation"])
		var n := float(sc["n"])
		# PORT-TRACE [장마당 관람객 겹침]: 2x2 장마당에서 관람객 고리가 너무 작아 앞뒤 줄이 포개졌다 —
		# 고리를 장마당 크기에 맞춰 넓히고(0.42 → 0.55), 관람객 수는 고리 둘레에 맞춰 정한다(crowd).
		var rx := 32.0 * n * 0.55
		var ry := rx * 0.5
		var rand_seed: int = int(sc["seed"])
		match String(sc["kind"]):
			"pungmul": _pungmul(ci, c, rx, ry, t, rand_seed)
			"taekkyeon": _taekkyeon(ci, c, rx, ry, t, rand_seed)
			"ssireum": _ssireum(ci, c, rx, ry, t, rand_seed)
			"talchum": _talchum(ci, c, rx, ry, t, rand_seed)
			"ganggang": _ganggang(ci, c, rx, ry, t, rand_seed)
			"juldagi": _juldagi(ci, c, rx, ry, t, rand_seed)
			"kites": _kites(ci, c, rx, ry, t, rand_seed)
			"seokjeon": _seokjeon(ci, c, city, sc, t, grid)
			"paengi": _paengi(ci, c, t)
			"jwibul": _jwibul(ci, c, t)
	for fr in fs.fires:
		var fp: Vector2i = fr["pos"]
		_flames(ci, city.cell_center(float(fp.x) + 0.5, float(fp.y) + 0.5, grid.grid[fp.y][fp.x]["elevation"]), t)

## PORT-TRACE [동작 그림]: 동작 그림(assets/sprites/npcs/actions/<aid>.png)이 있으면 t로 칸을 돌려 그리고 true.
## 없으면 false — 장면은 예전 코드 그림(새 인물 시트 + 들썩임·덧그림)으로 그린다.
static func _act(ci: CanvasItem, p: Vector2, aid: String, t: float, fps: float, face_right: bool, sc: float = 0.70) -> bool:
	var n := NpcSprites.action_frames(aid)
	if n <= 0:
		return false
	return NpcSprites.draw_action(ci, p, aid, int(t * fps) % n, face_right, sc)

# ---------------------------------------------------------------- 사람 한 명
## robe: 옷 색, hat: 0 없음 / 1 갓 / 2 흰 머리띠 / 3 상모(풍물), arm: 팔 들기(0~1), sash: 띠 색(투명이면 없음)
static func person(ci: CanvasItem, p: Vector2, robe: Color, hat: int = 1, arm: float = 0.0, sash: Color = Color(0, 0, 0, 0), s: float = 1.0, dir: int = 0) -> void:
	# PORT-TRACE [NPC 도트 스프라이트 3단계]: 장면 속 사람도 도트 인물로. hat 1=갓 쓴 도포, 0=상투 평민, 2=머릿수건, 3=탕건.
	# s < 0.9는 아이. arm(0~1)은 팔 든 정도 → 환호 자세 프레임. 띠(sash)가 있으면 허리띠 색.
	var base := "yangban"
	match hat:
		0: base = "commoner_m"
		2: base = "bearer"
		3: base = "painter"
	if s < 0.9:
		base = "child_m"
	var acc := sash if sash.a > 0.0 else (Color("b8352a") if hat == 1 else robe.darkened(0.25))
	var extra := {}
	if sash.a > 0.0 and base != "yangban":
		extra = {"belt": true}
	var key := NpcSprites.custom_kind(base, robe, robe.darkened(0.06), acc, extra)
	NpcSprites.draw_kind(ci, p, key, 0, false, dir, clampi(roundi(arm * 3.0), 0, 3), "cheer")

## 여인(치마저고리). braid면 댕기 땋은 처녀, 아니면 쪽 찐 아낙. arms(0~1) = 팔 든 정도
static func woman(ci: CanvasItem, p: Vector2, jeogori: Color, chima: Color, braid: bool, arms: float = 0.0, dir: int = 0) -> void:
	var key := NpcSprites.custom_kind("maiden" if braid else "lady", jeogori, chima, Color("c0392b"), {"hat": "braid" if braid else "bun"})
	NpcSprites.draw_kind(ci, p, key, 0, false, dir, clampi(roundi(arms * 3.0), 0, 3), "cheer")

## 둥글게 둘러선 관람객(뒷줄/앞줄 따로). 환호하듯 팔을 들썩인다.
static func crowd(ci: CanvasItem, c: Vector2, rx: float, ry: float, count: int, t: float, seed_val: int, front: bool) -> void:
	# 사람 폭보다 넉넉한 간격(15px)이 되도록 둘레에 맞춰 인원을 줄인다(요청 인원이 상한)
	var perimeter := TAU * sqrt((rx * rx + ry * ry) * 0.5)
	var gap := 16.0 if not NpcSprites.sheet_for("commoner_m").is_empty() else 15.0 # 새 48px 그림(줄인 크기) 폭
	count = clampi(mini(count, int(perimeter / gap)), 4, 16)
	var robes: Array[Color] = [WHITE, Color("dfe6ee"), Color("e8dcc4"), Color("b9c8d6"), WHITE, Color("f0d8d8")]
	for i in range(count):
		var ang := TAU * float(i) / float(count) + float(seed_val % 7) * 0.1
		var sn := sin(ang)
		if (sn > 0.0) != front:
			continue
		var p := c + Vector2(cos(ang) * rx, sn * ry)
		var cheer := maxf(0.0, sin(t * 4.0 + float(i) * 1.7))
		# 구경꾼 = 조합 백성(흰옷·여러 모자·수염·체형), 환호하면 들썩. 바탕 그림이 없으면 예전 그림
		var pv := PeopleVariety.pick(seed_val * 31 + i * 7 + 3)
		var face := 0 if cos(ang) < 0.0 else 1 # 판 가운데를 보게
		if not front:
			face += 2
		if PeopleVariety.draw(ci, p - Vector2(0, cheer * 2.0), pv, face, 0, 1.0, NpcSprites.SMALL_K if NpcSprites.small else 1.0):
			continue
		person(ci, p, robes[(i + seed_val) % robes.size()], 1 if (i + seed_val) % 3 != 0 else 2, cheer * 0.8)

# ---------------------------------------------------------------- 봄
static func _pungmul(ci: CanvasItem, c: Vector2, rx: float, ry: float, t: float, seed_val: int) -> void:
	crowd(ci, c, rx * 1.15, ry * 1.15, 14, t, seed_val, false)
	var sashes: Array[Color] = [Color("c0392b"), Color("1f5fa8"), Color("e8b820"), Color("c0392b"), Color("1f5fa8"), Color("2e8b57")]
	var items: Array = []
	for i in range(6):
		var ang := t * 0.7 + TAU * float(i) / 6.0
		items.append({"p": c + Vector2(cos(ang) * rx * 0.62, sin(ang) * ry * 0.62), "i": i})
	items.sort_custom(func(u, v): return (u["p"] as Vector2).y < (v["p"] as Vector2).y)
	for it in items:
		var p: Vector2 = it["p"]
		var i: int = it["i"]
		var hop := absf(sin(t * 6.0 + float(i))) * 2.0
		if _act(ci, p, "act_pungmul_sangmo", t + float(i) * 0.25, 6.0, (p - c).x < 0.0):
			continue # 상모 돌리는 동작 그림(끈·꽹과리 포함)
		person(ci, p - Vector2(0, hop), WHITE, 3, 0.4, sashes[i])
		# 상모 끈이 빙빙
		var ang2 := t * 9.0 + float(i)
		ci.draw_line(p - Vector2(0, 27 + hop), p - Vector2(0, 27 + hop) + Vector2(cos(ang2) * 11.0, sin(ang2) * 4.0), WHITE, 1.0)
		# 꽹과리(금색 원)·장구(가로 막대)
		if i % 2 == 0:
			FastDraw.circle(ci, p + Vector2(6, -11 - hop), 2.4, Color("e0b040"))
		else:
			ci.draw_line(p + Vector2(-6, -9 - hop), p + Vector2(6, -9 - hop), Color("9a2a20"), 3.0)
	# 가운데 사자: 털북숭이 몸 + 붉은 얼굴, 들썩들썩
	var _bob := sin(t * 5.0) * 2.0
	if not _act(ci, c, "act_lion_dance_pair", t, 4.0, sin(t * 0.4) > 0.0):
		AnimalSprites.draw(ci, c, "lion", int(t * 5.0), sin(t * 0.4) > 0.0) # 사자춤(도트)
	crowd(ci, c, rx * 1.15, ry * 1.15, 14, t, seed_val, true)

static func _taekkyeon(ci: CanvasItem, c: Vector2, rx: float, ry: float, t: float, seed_val: int) -> void:
	crowd(ci, c, rx, ry, 12, t, seed_val, false)
	for side: float in [-1.0, 1.0]:
		var p := c + Vector2(side * rx * 0.28, 0)
		var phase := sin(t * 3.0 + (0.0 if side < 0 else PI))
		var face_dir: int = 0 if side < 0 else 1
		var kick_frame: int = int(t * 3.0 + (0.0 if side < 0 else 2.0)) % 4
		NpcSprites.draw_kind(ci, p, "taekkyeon", 0, false, face_dir, kick_frame, "kick")
		if NpcSprites.action_frames("npc_taekkyeon__kick") == 0:
			# 동작 그림이 없을 때: 높이 차기(발) 액션 선
			var kick := maxf(0.0, phase)
			ci.draw_line(p + Vector2(side * 1.5, -3), p + Vector2(side * (4.0 + kick * 8.0), -3.0 - kick * 10.0), WHITE, 1.8)
	crowd(ci, c, rx, ry, 12, t, seed_val, true)

# ---------------------------------------------------------------- 여름
static func _ssireum(ci: CanvasItem, c: Vector2, rx: float, ry: float, t: float, seed_val: int) -> void:
	# 상품 황소는 관람객 고리 바깥 뒤편에 매어 둔다(관람객과 겹치지 않게 맨 먼저 그림)
	_prize_bull(ci, c + Vector2(rx * 0.35, -ry * 1.45))
	crowd(ci, c, rx * 1.1, ry * 1.1, 14, t, seed_val, false)
	# 모래판(팔각)
	var oct := PackedVector2Array()
	for i in range(8):
		var ang := TAU * (float(i) + 0.5) / 8.0
		oct.append(c + Vector2(cos(ang) * rx * 0.62, sin(ang) * ry * 0.62))
	FastDraw.poly(ci, oct, Color("ead9a8"))
	FastDraw.polyline(ci, oct + PackedVector2Array([oct[0]]), Color("b89a5a"), 1.2)
	# 두 장사가 맞붙어 기우뚱
	var sway := sin(t * 2.2) * 2.5
	if _act(ci, c + Vector2(sway, 0), "act_ssireum_pair", t, 1.5, int(t / 2.7) % 2 == 0):
		crowd(ci, c, rx * 1.1, ry * 1.1, 14, t, seed_val, true)
		return # 두 장사가 맞붙어 들고 메치는 동작 그림
	for side: float in [-1.0, 1.0]:
		var p := c + Vector2(side * 5.0 + sway, 0)
		var face_dir: int = 0 if side < 0 else 1
		var step_frame: int = int(t * 2.2) % 2
		# 48x48 상의 탈의 구릿빛 씨름장사 고품질 스프라이트 렌더링
		NpcSprites.draw_kind(ci, p, "ssireum", 0, false, face_dir, step_frame, "cheer")
	crowd(ci, c, rx * 1.1, ry * 1.1, 14, t, seed_val, true)

static func _prize_bull(ci: CanvasItem, bp: Vector2) -> void:
	AnimalSprites.draw(ci, bp, "ox", 0, true, Color("8a5a32")) # 상품 황소(도트) + 등의 꽃장식
	for k in range(4):
		FastDraw.circle(ci, bp + Vector2(-6 + k * 4.0, -21), 1.5, [Color("c0392b"), Color("e8b820"), Color("2e8b57"), Color("1f5fa8")][k])

static func _talchum(ci: CanvasItem, c: Vector2, rx: float, ry: float, t: float, seed_val: int) -> void:
	crowd(ci, c, rx, ry, 12, t, seed_val, false)
	for side: float in [-1.0, 1.0]:
		var p := c + Vector2(side * rx * 0.25 + sin(t * 1.5 + side) * 3.0, 0)
		var robe := Color("e8b820") if side < 0 else Color("2e8b57")
		var wave := sin(t * 3.5 + side * 1.3)
		if _act(ci, p, "act_talchum", t + side, 3.0, side < 0.0):
			continue # 탈춤 동작 그림(탈·한삼 포함)
		person(ci, p, robe, 0, 0.5 + wave * 0.5)
		# 탈(흰 얼굴 + 붉은 볼) + 긴 한삼 소매
		var fy := -21.0 if not NpcSprites.sheet_for("commoner_m").is_empty() else -18.0 # 새 그림은 얼굴이 조금 더 위
		FastDraw.circle(ci, p + Vector2(0.5, fy), 4.2, WHITE) # 탈
		FastDraw.circle(ci, p + Vector2(-1.4, fy + 1.2), 0.9, Color("e05050"))
		FastDraw.circle(ci, p + Vector2(2.4, fy + 1.2), 0.9, Color("e05050"))
		ci.draw_line(p + Vector2(-1.0, fy - 1.0), p + Vector2(0.2, fy - 1.0), Color("1a1a1a"), 0.8)
		ci.draw_line(p + Vector2(1.2, fy - 1.0), p + Vector2(2.4, fy - 1.0), Color("1a1a1a"), 0.8)
		var hand_y := -9.0 - (0.5 + wave * 0.5) * 9.0
		ci.draw_line(p + Vector2(-6.5, hand_y), p + Vector2(-13, hand_y + 4 - wave * 6.0), WHITE, 1.8) # 한삼 소매
		ci.draw_line(p + Vector2(6.5, hand_y), p + Vector2(13, hand_y + 4 + wave * 6.0), WHITE, 1.8)
	crowd(ci, c, rx, ry, 12, t, seed_val, true)

static func _seokjeon(ci: CanvasItem, c: Vector2, city: CityLayer, sc: Dictionary, t: float, grid: GameGrid = null) -> void:
	var other: Vector2
	if sc.has("other_pos") and grid != null and city != null:
		var opos: Vector2 = sc["other_pos"]
		var otx := clampi(int(opos.x), 0, grid.size - 1)
		var oty := clampi(int(opos.y), 0, grid.size - 1)
		var elev: float = grid.grid[oty][otx].get("elevation", 1.0)
		other = city.cell_center(opos.x, opos.y, elev)
	else:
		var wd: Vector2 = sc.get("dir", Vector2(1, 0))
		var o := city.cell_center(0.0, 0.0) if city else Vector2.ZERO
		other = city.cell_center(wd.x * 2.4, wd.y * 2.4) - o + c if city else c + wd * 40.0

	var sides: Array = [[c, Color("e8dcc4")], [other, Color("c9d6e2")]]
	for gi in range(2):
		var gp: Vector2 = sides[gi][0]
		var face_dir: int = 0 if gi == 0 else 1
		for k in range(4):
			var p := gp + Vector2(float(k) * 9.0 - 13.5, float(k % 2) * 3.0)
			person(ci, p, sides[gi][1], 2, maxf(0.0, sin(t * 3.0 + float(k) + float(gi) * 1.5)), Color(0, 0, 0, 0), 1.0, face_dir)
	# 날아가는 돌(포물선)
	for k in range(3):
		var ph := fmod(t * 0.6 + float(k) / 3.0, 1.0)
		var from: Vector2 = c if k % 2 == 0 else other
		var to: Vector2 = other if k % 2 == 0 else c
		var p2 := from.lerp(to, ph) - Vector2(0, 16.0 + sin(ph * PI) * 24.0)
		FastDraw.circle(ci, p2, 1.6, Color("7a756c"))

# ---------------------------------------------------------------- 가을
static func _ganggang(ci: CanvasItem, c: Vector2, rx: float, ry: float, t: float, seed_val: int) -> void:
	# PORT-TRACE [강강술래 자리]: 원이 장마당을 꽉 채워 구경꾼 설 자리가 없었다 → 일곱 명, 작은 원(0.72), 뒤·앞 둘레에 구경꾼
	crowd(ci, c, rx * 1.3, ry * 1.3, 10, t, seed_val, false)
	# 횃불 네 개
	for k in range(4):
		var ang := TAU * (float(k) + 0.5) / 4.0
		var tp := c + Vector2(cos(ang) * rx * 0.98, sin(ang) * ry * 0.98)
		ci.draw_line(tp, tp - Vector2(0, 14), Color("5c3a21"), 1.4)
		var fl := 1.0 + sin(t * 12.0 + float(k)) * 0.25
		FastDraw.circle(ci, tp - Vector2(0, 16), 2.6 * fl, Color("f08a24"))
		FastDraw.circle(ci, tp - Vector2(0, 17), 1.4 * fl, Color("ffe07a"))
	# 손 맞잡고 도는 아낙들(치마 색이 번갈아) — 옆 사람과 맞잡은 손을 잇는 끈 같은 팔 선(둥근 고리)
	var gr := 0.72 # 원 반지름(놀이판 대비)
	const ND := 7
	for k in range(ND):
		var a1 := -t * 0.9 + TAU * float(k) / float(ND)
		var a2 := a1 + TAU / float(ND)
		ci.draw_line(c + Vector2(cos(a1) * rx * gr, sin(a1) * ry * gr - 11.0), c + Vector2(cos(a2) * rx * gr, sin(a2) * ry * gr - 11.0), Color(0.95, 0.85, 0.75, 0.8), 1.0)
	var skirts: Array[Color] = [Color("e88aa8"), Color("2e8b57"), Color("c0392b"), Color("f4f0e4"), Color("8e44ad")]
	var items: Array = []
	for i in range(ND):
		var ang2 := -t * 0.9 + TAU * float(i) / float(ND)
		items.append({"p": c + Vector2(cos(ang2) * rx * gr, sin(ang2) * ry * gr), "i": i})
	items.sort_custom(func(u, v): return (u["p"] as Vector2).y < (v["p"] as Vector2).y)
	for it in items:
		var p: Vector2 = it["p"]
		var i: int = it["i"]
		var skirt: Color = skirts[i % skirts.size()]
		if _act(ci, p, "act_ganggang", t + float(i) * 0.5, 4.0, (p - c).y > 0.0):
			continue
		woman(ci, p, Color("f4f0e4"), skirt, false, 0.34) # 손 맞잡고 도는 강강술래
	crowd(ci, c, rx * 1.3, ry * 1.3, 10, t, seed_val, true)

static func _juldagi(ci: CanvasItem, c: Vector2, rx: float, ry: float, t: float, seed_val: int) -> void:
	crowd(ci, c, rx * 1.1, ry * 1.1, 14, t, seed_val, false)
	var a := c + Vector2(-rx * 0.7, 0)
	var b := c + Vector2(rx * 0.7, 0)
	var h := 26.0
	for p: Vector2 in [a, b]:
		ci.draw_line(p + Vector2(-3, 0), p - Vector2(0, h), Color("6e4a2c"), 1.4)
		ci.draw_line(p + Vector2(3, 0), p - Vector2(0, h), Color("6e4a2c"), 1.4)
	ci.draw_line(a - Vector2(0, h), b - Vector2(0, h), Color("e8dcb0"), 1.0)
	# 어름사니: 부채 들고 줄 위를 오가며 통통
	var ph := (sin(t * 0.7) + 1.0) * 0.5
	var bounce := absf(sin(t * 4.0)) * 4.0
	var pp := a.lerp(b, 0.15 + ph * 0.7) - Vector2(0, h + bounce)
	if not _act(ci, pp, "act_rope_walker", t, 3.0, sin(t * 0.7) < 0.0):
		person(ci, pp, WHITE, 2, 1.0, Color("c0392b"))
		FastDraw.poly(ci, PackedVector2Array([pp + Vector2(6, -23), pp + Vector2(12, -27), pp + Vector2(13, -20)]), Color("e8453a"))
	crowd(ci, c, rx * 1.1, ry * 1.1, 14, t, seed_val, true)

# ---------------------------------------------------------------- 겨울
static func _kites(ci: CanvasItem, c: Vector2, rx: float, ry: float, t: float, seed_val: int) -> void:
	var cols: Array[Color] = [Color("c0392b"), Color("1f5fa8"), Color("e8b820")]
	for i in range(3):
		var p := c + Vector2((float(i) - 1.0) * rx * 0.55, float(i % 2) * ry * 0.4)
		var step_frame: int = int(t * 2.0 + float(i)) % 2
		NpcSprites.draw_kind(ci, p, "kite_flyer", i, true, 0, int(t * 1.5 + float(i)) % 4 if NpcSprites.action_frames("npc_kite_flyer__fly") > 0 else step_frame, "fly")
		var hand := p + (Vector2(4, -15) if not NpcSprites.sheet_for("kite_flyer").is_empty() else Vector2(6, -23)) # 새 그림(아이 0.52배)의 손 높이
		var kp: Vector2
		if i == 2:
			# 연싸움 끝에 실이 끊어진 연 — 하늘로 멀리 날아가다 사라지고 다시 띄운다
			var cyc := fmod(t * 0.12 + float(seed_val % 10) * 0.1, 1.0)
			kp = hand + Vector2(20.0 + cyc * 70.0, -50.0 - cyc * 60.0)
			if cyc < 0.15:
				ci.draw_line(hand, kp, Color(1, 1, 1, 0.6), 0.6)
			var fade := 1.0 - cyc
			var kc: Color = cols[i]
			kc.a = fade
			_kite(ci, kp, kc, t)
			continue
		kp = hand + Vector2(14.0 + sin(t * 1.1 + float(i)) * 6.0, -50.0 - float(i) * 8.0 + sin(t * 1.7 + float(i)) * 4.0)
		ci.draw_line(hand, kp, Color(1, 1, 1, 0.6), 0.6)
		_kite(ci, kp, cols[i], t)

static func _kite(ci: CanvasItem, p: Vector2, col: Color, t: float) -> void:
	FastDraw.poly(ci, PackedVector2Array([p + Vector2(0, -6), p + Vector2(5, 0), p + Vector2(0, 6), p + Vector2(-5, 0)]), col)
	FastDraw.circle(ci, p, 1.6, Color(1, 1, 1, col.a))
	ci.draw_line(p + Vector2(0, 6), p + Vector2(sin(t * 3.0) * 3.0, 14), Color(col.r, col.g, col.b, col.a * 0.8), 0.8)

static func _paengi(ci: CanvasItem, c: Vector2, t: float) -> void:
	# 얼음판(밝은 결) 위 팽이 셋 + 채찍질하는 아이들
	FastDraw.poly(ci, PackedVector2Array([c + Vector2(-18, 0), c + Vector2(0, -8), c + Vector2(18, 0), c + Vector2(0, 8)]), Color(0.85, 0.93, 1.0, 0.5))
	for i in range(3):
		var tp := c + Vector2((float(i) - 1.0) * 9.0, float(i % 2) * 3.0)
		FastDraw.poly(ci, PackedVector2Array([tp, tp + Vector2(-2.5, -3), tp + Vector2(2.5, -3)]), Color("8a5a32"))
		var ang := t * 20.0 + float(i)
		ci.draw_line(tp + Vector2(0, -3), tp + Vector2(cos(ang) * 2.5, -3 + sin(ang) * 0.8), Color("c0392b"), 1.0)
		var kid := tp + Vector2(5, 2)
		if _act(ci, kid, "act_paengi", t + float(i), 4.0, false, 0.52):
			continue
		person(ci, kid, Color("c9d6e2") if i != 1 else Color("e88aa8"), 0, 0.5 + sin(t * 6.0 + float(i)) * 0.5, Color(0, 0, 0, 0), 0.8)
		ci.draw_line(kid + Vector2(-3.5, -9), tp + Vector2(1, -2), Color("6e4a2c"), 0.7)

static func _jwibul(ci: CanvasItem, c: Vector2, t: float) -> void:
	for i in range(3):
		var p := c + Vector2((float(i) - 1.0) * 13.0, float(i % 2) * 3.0)
		if _act(ci, p, "act_jwibul", t + float(i) * 0.7, 6.0, i % 2 == 0, 0.52):
			continue # 불 깡통을 돌리는 동작 그림(불똥 포함)
		person(ci, p, Color("c9d6e2"), 0, 0.9, Color(0, 0, 0, 0), 0.85)
		var hand := p + Vector2(6, -17)
		var ang := t * 7.0 + float(i) * 2.0
		for k in range(4):
			var a2 := ang - float(k) * 0.35
			var fp := hand + Vector2(cos(a2) * 8.0, sin(a2) * 8.0)
			FastDraw.circle(ci, fp, 2.0 - float(k) * 0.4, Color(1.0, 0.55 - float(k) * 0.1, 0.1, 1.0 - float(k) * 0.22))
		ci.draw_line(hand, hand + Vector2(cos(ang) * 8.0, sin(ang) * 8.0), Color("4a3422"), 0.7)

static func _flames(ci: CanvasItem, p: Vector2, t: float) -> void:
	for k in range(4):
		var off := Vector2(float(k) * 5.0 - 7.5, 0)
		var hgt := 8.0 + sin(t * 10.0 + float(k) * 1.7) * 3.0
		FastDraw.poly(ci, PackedVector2Array([p + off + Vector2(-3, 0), p + off + Vector2(3, 0), p + off + Vector2(0, -hgt)]), Color("f05a1a"))
		FastDraw.poly(ci, PackedVector2Array([p + off + Vector2(-1.5, 0), p + off + Vector2(1.5, 0), p + off + Vector2(0, -hgt * 0.6)]), Color("ffd040"))
	for k in range(3):
		var sp := p + Vector2(sin(t + float(k)) * 4.0, -14.0 - float(k) * 6.0 - fmod(t * 6.0, 6.0))
		FastDraw.circle(ci, sp, 3.0 + float(k), Color(0.4, 0.4, 0.42, 0.35))
