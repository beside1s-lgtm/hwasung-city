extends RefCounted
class_name PeopleVariety
## PORT-TRACE [백성 조합(종이 인형)]: 김홍도 풍속화의 거리처럼 흰옷 입은 백성들이 저마다 다른 모자·수염·체형으로 다니게 한다.
## 한 사람씩 그리지 않고 "바탕 인물 시트(48x48, 4방향×2걸음) + 옷 빛깔 물들이기 + 체형 배율 + 모자 + 수염"을 사람 id로
## 고정 조합한다. 모자·수염은 코드 도트로 머리 위치(시트 칸마다 자동 탐지)에 씌운다. 그림 파일을 더 만들 필요가 없다.
## 바탕 인물은 npc_base_*(모자 없는 흰옷 바탕, 나중에 받으면) → 지금 있는 시트 순으로 쓴다.
const SpriteCacheManager = preload("res://scripts/autoload/SpriteCacheManager.gd")

## 바탕: [후보 시트들, 종류] — 종류: man 상투 튼 어른 남자, youth 댕기머리 총각, old 노인, woman 아낙, boy 아이
const BASES := [
	[["npc_base_man", "npc_cheonmin"], "man"],
	[["npc_base_man2", "npc_brawler", "npc_cheonmin"], "man"],
	[["npc_base_youth", "npc_cheonmin"], "youth"],
	[["npc_base_old", "npc_grandpa", "npc_cheonmin"], "old"],
	[["npc_base_woman", "npc_peasant_woman"], "woman"],
	[["npc_base_woman2", "npc_peasant_woman"], "woman"],
	[["npc_base_boy", "npc_child_boy"], "boy"],
]
## 모자를 쓰지 않은(맨상투·댕기·쪽 찐) 바탕 시트 — 이 밖의 시트(삿갓 쓴 농부 등)는 이미 모자가 있어 덧씌우지 않는다
const BAREHEAD := ["npc_base_man", "npc_base_man2", "npc_base_youth", "npc_base_old", "npc_base_woman", "npc_base_woman2", "npc_base_boy",
	"npc_cheonmin", "npc_brawler", "npc_grandpa", "npc_child_boy", "npc_peasant_woman"]
const BASE_WEIGHTS := [6, 5, 3, 3, 3, 1, 2] # 거리엔 어른 남자가 많고 아낙·아이는 적게
## 모자(사람 종류별로 쓸 수 있는 것, 앞이 자주)
const HATS := {
	"man": ["gat", "gat", "gat", "paeraengi", "paeraengi", "satgat", "jisatgat", "chorip", "tanggeon", "banggeon", "headband", "galmo", "baengnip", "yugeon", "none", "none", "none", "none", "none"], # 맨상투 약 4분의 1
	"youth": ["none", "none", "none", "chorip", "headband"],
	"old": ["gat", "tanggeon", "tanggeon", "banggeon", "jeongjagwan", "gat", "none"],
	"woman": ["none", "none", "scarf", "scarf"],
	"boy": ["none"],
}
const BEARDS := {"man": ["none", "mustache", "mustache", "goatee", "full"], "old": ["white", "white", "white_long"], "youth": ["none"], "woman": ["none"], "boy": ["none"]}
## 옷 빛깔(김홍도 풍속화의 흰옷과 옅은 물빛)
const TINTS := [Color(1, 1, 1), Color(1, 1, 1), Color(1, 1, 1), Color(0.97, 0.94, 0.86), Color(0.86, 0.86, 0.84), Color(0.82, 0.88, 0.95), Color(0.95, 0.88, 0.74), Color(0.86, 0.92, 0.82)]

static var _tinted := {}   # "시트|색" → Texture2D
static var _anchors := {}  # 시트 → [칸별 [머리 꼭대기 y, 가운데 x, 머리 폭]] (8칸: 행 0~3 × 열 0~1)

static func _has(sid: String) -> bool:
	return FileAccess.file_exists(ProjectSettings.globalize_path("res://assets/sprites/npcs/%s.png" % sid))

static func _rng(id: int, salt: int) -> int:
	return absi(hash(id * 7919 + salt * 104729))

## 사람 id → 조합(고정)
static func pick(id: int) -> Dictionary:
	var total := 0
	for w in BASE_WEIGHTS:
		total += int(w)
	var r := _rng(id, 1) % total
	var bi := 0
	for i in BASE_WEIGHTS.size():
		r -= int(BASE_WEIGHTS[i])
		if r < 0:
			bi = i
			break
	var cands: Array = BASES[bi][0]
	var sid := ""
	for c in cands:
		if _has(String(c)):
			sid = String(c)
			break
	var kind: String = BASES[bi][1]
	var hats: Array = HATS[kind]
	var beards: Array = BEARDS[kind]
	var child := kind == "boy"
	var hat := String(hats[_rng(id, 2) % hats.size()])
	if not (sid in BAREHEAD) or (sid == "npc_peasant_woman" and hat == "scarf"):
		hat = "none"
	return {
		"sheet": sid, "kind": kind,
		"hat": hat,
		"beard": String(beards[_rng(id, 3) % beards.size()]),
		"tint": TINTS[_rng(id, 4) % TINTS.size()] if kind != "woman" or _rng(id, 9) % 2 == 0 else TINTS[0],
		"sx": (0.97 + float(_rng(id, 5) % 7) * 0.012) if child else (0.86 + float(_rng(id, 5) % 11) * 0.03), # 날씬 0.86 ~ 뚱뚱 1.16
		"sy": (0.97 + float(_rng(id, 6) % 5) * 0.015) if child else (0.92 + float(_rng(id, 6) % 9) * 0.02), # 작음 0.92 ~ 큼 1.08
		"scale": 0.52 if child else 0.70,
	}

## 흰옷(밝고 채도 낮은 칸)만 물들인 시트
static func _tinted_tex(sid: String, tint: Color) -> Texture2D:
	var key := "%s|%s" % [sid, tint.to_html(false)]
	if _tinted.has(key):
		return _tinted[key]
	var base: Texture2D = SpriteCacheManager.get_npc_texture(sid)
	if base == null:
		return null
	if tint.is_equal_approx(Color(1, 1, 1)):
		_tinted[key] = base
		_measure(sid, base)
		return base
	var img := base.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var mx := maxf(c.r, maxf(c.g, c.b))
			var mn := minf(c.r, minf(c.g, c.b))
			if mx > 0.62 and mx - mn < 0.12: # 흰·회색 옷감
				img.set_pixel(x, y, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a))
	var tex := ImageTexture.create_from_image(img)
	_tinted[key] = tex
	_measure(sid, base)
	return tex

## 칸마다 머리 꼭대기·가운데·폭(모자 씌울 자리)
static func _measure(sid: String, tex: Texture2D) -> void:
	if _anchors.has(sid):
		return
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var out: Array = []
	for row in 4:
		for col in 2:
			var ox := col * 48
			var oy := row * 48
			var top := -1
			for y in 48:
				var n := 0
				for x in 48:
					if img.get_pixel(ox + x, oy + y).a > 0.5:
						n += 1
				if n >= 3:
					top = y
					break
			if top < 0:
				out.append([10.0, 24.0, 10.0])
				continue
			var x0 := 48
			var x1 := -1
			for y in range(top, mini(top + 7, 48)):
				for x in 48:
					if img.get_pixel(ox + x, oy + y).a > 0.5:
						x0 = mini(x0, x)
						x1 = maxi(x1, x)
			out.append([float(top), (float(x0) + float(x1)) * 0.5 + 0.5, float(maxi(6, x1 - x0 + 1))])
	_anchors[sid] = out

## 그리기: p = 발 위치, dir = 게임 방향 0~3, frame = 걸음 칸, v = pick() 결과
static func draw(ci: CanvasItem, p: Vector2, v: Dictionary, dir: int, frame: int, alpha: float = 1.0, small_k: float = 1.0) -> bool:
	var sid: String = v.get("sheet", "")
	if sid == "":
		return false
	var tex := _tinted_tex(sid, v["tint"])
	if tex == null:
		return false
	var dir_map: Array[int] = [1, 0, 3, 2]
	var row: int = dir_map[clampi(dir, 0, 3)]
	var col: int = clampi(frame, 0, 3) % 2
	var s: float = NpcSprites.adult_k(float(v["scale"])) * small_k
	var sx: float = s * float(v["sx"])
	var sy: float = s * float(v["sy"])
	ci.draw_texture_rect_region(tex, Rect2(p.x - 24.0 * sx, p.y - 42.0 * sy, 48.0 * sx, 48.0 * sy), Rect2(col * 48, row * 48, 48, 48), Color(1, 1, 1, alpha))
	var an: Array = (_anchors.get(sid, []) as Array)
	if an.is_empty():
		return true
	var a: Array = an[row * 2 + col]
	var head := Vector2(p.x + (float(a[1]) - 24.0) * sx, p.y + (float(a[0]) - 42.0) * sy) # 머리 꼭대기 가운데
	var hw: float = float(a[2]) * sx # 머리 폭(화면 px)
	var front := row < 2
	if front:
		_beard(ci, head, hw, String(v["beard"]), alpha, row == 1)
	_hat(ci, head, hw, String(v["hat"]), alpha)
	return true

# ---------------------------------------------------------------- 수염(앞모습)
static func _beard(ci: CanvasItem, head: Vector2, hw: float, kind: String, alpha: float, face_right: bool) -> void:
	if kind == "none":
		return
	var fx := head.x + (hw * 0.12 if face_right else -hw * 0.12) # 3/4 얼굴이 향한 쪽
	var chin := Vector2(fx, head.y + hw * 0.95)
	var dark := Color(0.12, 0.1, 0.09, alpha)
	var white := Color(0.95, 0.94, 0.9, alpha)
	match kind:
		"mustache":
			ci.draw_line(chin + Vector2(-hw * 0.18, -hw * 0.22), chin + Vector2(hw * 0.18, -hw * 0.22), dark, 1.0)
		"goatee":
			ci.draw_line(chin + Vector2(-hw * 0.15, -hw * 0.22), chin + Vector2(hw * 0.15, -hw * 0.22), dark, 0.9)
			ci.draw_line(chin + Vector2(0, -hw * 0.05), chin + Vector2(0, hw * 0.18), dark, 1.2)
		"full":
			ci.draw_colored_polygon(PackedVector2Array([chin + Vector2(-hw * 0.2, -hw * 0.2), chin + Vector2(hw * 0.2, -hw * 0.2), chin + Vector2(0, hw * 0.18)]), dark)
		"white":
			ci.draw_colored_polygon(PackedVector2Array([chin + Vector2(-hw * 0.16, -hw * 0.18), chin + Vector2(hw * 0.16, -hw * 0.18), chin + Vector2(0, hw * 0.2)]), white)
		"white_long":
			ci.draw_colored_polygon(PackedVector2Array([chin + Vector2(-hw * 0.17, -hw * 0.18), chin + Vector2(hw * 0.17, -hw * 0.18), chin + Vector2(0, hw * 0.4)]), white)

# ---------------------------------------------------------------- 모자(머리 꼭대기 가운데 기준)
static func _hat(ci: CanvasItem, h: Vector2, hw: float, kind: String, alpha: float) -> void:
	if kind == "none":
		return
	var ol := Color(0.08, 0.07, 0.06, alpha)
	match kind:
		"gat", "baengnip", "chorip":
			# 넓은 챙(얇은 타원) + 둥근 기둥 모자통. 갓은 검은 말총이라 챙이 비친다
			var col := Color(0.07, 0.07, 0.07, 0.82 * alpha) if kind == "gat" else (Color("e2d3a8", alpha) if kind == "baengnip" else Color("c9a463", alpha))
			var by := h.y + hw * 0.32
			_ellipse(ci, Vector2(h.x, by), hw * 0.85, hw * 0.2, col, ol)
			var cw := hw * 0.34
			var ch := hw * 0.62
			ci.draw_colored_polygon(PackedVector2Array([Vector2(h.x - cw, by), Vector2(h.x + cw, by), Vector2(h.x + cw * 0.9, by - ch), Vector2(h.x - cw * 0.9, by - ch)]), col)
			ci.draw_polyline(PackedVector2Array([Vector2(h.x - cw, by), Vector2(h.x - cw * 0.9, by - ch), Vector2(h.x + cw * 0.9, by - ch), Vector2(h.x + cw, by)]), ol, 1.0)
			ci.draw_line(Vector2(h.x - hw * 0.3, by), Vector2(h.x - hw * 0.25, by + hw * 0.9), Color(0.1, 0.1, 0.1, 0.6 * alpha), 0.7) # 갓끈
		"paeraengi":
			var by2 := h.y + hw * 0.3
			_ellipse(ci, Vector2(h.x, by2), hw * 0.82, hw * 0.22, Color("9a7344", alpha), ol)
			_ellipse(ci, Vector2(h.x, by2 - hw * 0.22), hw * 0.42, hw * 0.3, Color("ad8550", alpha), ol)
		"satgat":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(h.x - hw * 0.8, h.y + hw * 0.4), Vector2(h.x, h.y - hw * 0.32), Vector2(h.x + hw * 0.8, h.y + hw * 0.4), Vector2(h.x, h.y + hw * 0.52)]), Color("b07a45", alpha))
			ci.draw_polyline(PackedVector2Array([Vector2(h.x - hw * 0.8, h.y + hw * 0.4), Vector2(h.x, h.y - hw * 0.32), Vector2(h.x + hw * 0.8, h.y + hw * 0.4), Vector2(h.x, h.y + hw * 0.52), Vector2(h.x - hw * 0.8, h.y + hw * 0.4)]), ol, 1.0)
		"jisatgat":
			_ellipse(ci, Vector2(h.x, h.y + hw * 0.32), hw * 0.9, hw * 0.24, Color("dcae5c", alpha), ol)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(h.x - hw * 0.5, h.y + hw * 0.2), Vector2(h.x, h.y - hw * 0.1), Vector2(h.x + hw * 0.5, h.y + hw * 0.2)]), Color("3a3028", alpha))
		"galmo":
			# 갓 위에 쓰는 기름종이 비 가리개(원뿔)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(h.x - hw * 0.75, h.y + hw * 0.42), Vector2(h.x, h.y - hw * 0.75), Vector2(h.x + hw * 0.75, h.y + hw * 0.42)]), Color("e3bf6a", alpha))
			ci.draw_polyline(PackedVector2Array([Vector2(h.x - hw * 0.75, h.y + hw * 0.42), Vector2(h.x, h.y - hw * 0.75), Vector2(h.x + hw * 0.75, h.y + hw * 0.42)]), ol, 1.0)
			ci.draw_line(Vector2(h.x - hw * 0.25, h.y - hw * 0.3), Vector2(h.x - hw * 0.45, h.y + hw * 0.4), Color("b8933f", alpha), 0.8)
			ci.draw_line(Vector2(h.x + hw * 0.25, h.y - hw * 0.3), Vector2(h.x + hw * 0.45, h.y + hw * 0.4), Color("b8933f", alpha), 0.8)
		"tanggeon":
			ci.draw_rect(Rect2(h.x - hw * 0.42, h.y - hw * 0.18, hw * 0.84, hw * 0.45), Color(0.08, 0.08, 0.08, 0.78 * alpha))
			ci.draw_rect(Rect2(h.x - hw * 0.42, h.y - hw * 0.18, hw * 0.84, hw * 0.45), ol, false, 0.8)
		"banggeon":
			ci.draw_rect(Rect2(h.x - hw * 0.45, h.y - hw * 0.42, hw * 0.9, hw * 0.7), Color(0.1, 0.1, 0.1, 0.8 * alpha))
			ci.draw_rect(Rect2(h.x - hw * 0.45, h.y - hw * 0.42, hw * 0.9, hw * 0.7), ol, false, 0.8)
		"jeongjagwan":
			for k in 2:
				var yy := h.y + hw * 0.15 - float(k) * hw * 0.32
				var wv := hw * (0.55 - float(k) * 0.1)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(h.x - wv, yy), Vector2(h.x - wv * 0.7, yy - hw * 0.34), Vector2(h.x, yy - hw * 0.2), Vector2(h.x + wv * 0.7, yy - hw * 0.34), Vector2(h.x + wv, yy)]), Color(0.08, 0.08, 0.08, 0.85 * alpha))
		"yugeon":
			ci.draw_rect(Rect2(h.x - hw * 0.42, h.y - hw * 0.3, hw * 0.84, hw * 0.55), Color("2e3230", alpha))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(h.x - hw * 0.42, h.y - hw * 0.3), Vector2(h.x - hw * 0.7, h.y - hw * 0.45), Vector2(h.x - hw * 0.42, h.y - hw * 0.05)]), Color("2e3230", alpha))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(h.x + hw * 0.42, h.y - hw * 0.3), Vector2(h.x + hw * 0.7, h.y - hw * 0.45), Vector2(h.x + hw * 0.42, h.y - hw * 0.05)]), Color("2e3230", alpha))
		"headband":
			ci.draw_line(Vector2(h.x - hw * 0.5, h.y + hw * 0.32), Vector2(h.x + hw * 0.5, h.y + hw * 0.32), Color(0.96, 0.95, 0.9, alpha), maxf(1.2, hw * 0.16))
		"scarf":
			# 아낙의 흰 머릿수건
			ci.draw_colored_polygon(PackedVector2Array([Vector2(h.x - hw * 0.55, h.y + hw * 0.45), Vector2(h.x - hw * 0.45, h.y - hw * 0.05), Vector2(h.x + hw * 0.45, h.y - hw * 0.05), Vector2(h.x + hw * 0.55, h.y + hw * 0.45)]), Color(0.96, 0.95, 0.9, alpha))

static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, ol: Color) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		var ang := TAU * float(i) / 14.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	ci.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	ci.draw_polyline(pts, ol, 0.8)
