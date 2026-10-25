extends RefCounted
class_name GateLogistics

## PORT-TRACE [사대문 물류]: 사용자 요청 — "각 성문에서 지도 밖으로 이어지는 길이 개통되면 끝자락에 이정표·안내를
## 띄우고, 문마다 역사적 배후지에 맞는 물자가 들어와 성문 안쪽에 전문 시장이 서고, 문마다 다른 운반꾼이 들어와
## 특화 시장 → 십자로 시전으로 물건을 나르며, 사대문이 모두 이어지면 시전 번영 보너스".
## 성능 원칙(사용자 명시): 개통 여부·십자로 위치는 지도가 바뀐 뒤 처음 물을 때 한 번만 계산(_dirty)한다.
## 계산 = 성문마다 성 밖 길을 따라가는 작은 BFS(최대 600칸) + 길 칸 훑기 1회. 틱마다 하는 일은 없다.

@warning_ignore("unused_signal")
signal notice(msg: String, icon: String)

const INFO := {
	"jangan": {"gate": "장안문", "dir": "북쪽 대로", "dest": "한양 도성(경복궁·조정) 방면", "sign": "한양(漢陽)으로 가는 길",
		"info": "한양으로 통하는 관도. 왕실 능행차로", "goods": "공문서 · 한양 고급 수공업품 · 서책",
		"market": "지전·서책방·비단·유기 시전(기와 점포)"},
	"paldal": {"gate": "팔달문", "dir": "남쪽 대로", "dest": "삼남대로(충청·전라·경상) · 현륭원 방면", "sign": "삼남대로 / 현륭원(융릉)으로 가는 길",
		"info": "삼남 각지로 뻗은 큰길. 전국 보부상 왕래", "goods": "곡물 · 소(가축) · 삼베·무명 · 삼남 특산물",
		"market": "쇠전(우시장)·싸전·포목전·주막·객주 거리"},
	"hwaseo": {"gate": "화서문", "dir": "서쪽 대로", "dest": "남양만·안산 포구(서해안) 방면", "sign": "남양만 / 서해 갯벌로 가는 길",
		"info": "서해 뱃길과 이어지는 어염로(魚鹽路)", "goods": "천일염(소금) · 어물 · 젓갈",
		"market": "소금전·어물전·젓갈전·옹기 난전"},
	"changryong": {"gate": "창룡문", "dir": "동쪽 대로", "dest": "광주·용인·이천 산간 내륙 방면", "sign": "광주 / 동해로 가는 길",
		"info": "동부 산간으로 통하는 길목", "goods": "목재 · 땔감(숯) · 도자기 · 약초",
		"market": "목재전·장작전·약방 + 대장간(연무대 군수 보급)"},
}
const KINDS := ["jangan", "paldal", "hwaseo", "changryong"]
## 성문 특화 시장 업종(작은 가게 / 큰 가게 / 공방)
const MARKET_SMALL := {
	"jangan": ["paper", "book", "silk", "yugi"],
	"paldal": ["cattle", "rice", "cotton", "ramie"],
	"hwaseo": ["salt", "fish", "jeotgal", "pottery"],
	"changryong": ["lumber", "firewood", "herb"],
}
const MARKET_BIG := {
	"jangan": ["book", "silk", "yugi", "gaekju"],
	"paldal": ["cattle", "rice", "jumak", "gaekju"],
	"hwaseo": ["fish", "jeotgal", "salt", "pottery"],
	"changryong": ["lumber", "herb", "firewood"],
}
const MARKET_WORKSHOP := {
	"jangan": ["hanji", "brush"],
	"hwaseo": ["onggi"],
	"changryong": ["smith", "bow"],
}
const MARKET_RADIUS := 6 # 성문에서 이 거리(맨해튼) 안의 성 안 가게가 특화 시장
const HUB_RADIUS := 5    # 십자로 시전 반경

var grid: GameGrid
## [{kind, gate: Vector2i, end: Vector2i, connected: bool}]
var routes: Array = []
## 십자로 시전(성 안 가게가 가장 많이 모인 교차로). 없으면 (-1,-1)
var hub := Vector2i(-1, -1)
var _dirty := true
var _first := true
var _announced := {}

func mark_dirty() -> void:
	_dirty = true

func refresh() -> void:
	if not _dirty or grid == null:
		return
	_dirty = false
	routes.clear()
	var g := grid.grid
	var sz := grid.size
	var roads: Array[Vector2i] = []
	var found_gates: Dictionary = {}
	for y: int in range(sz):
		for x: int in range(sz):
			var b: String = String(g[y][x]["building"])
			if b == "gate" and not g[y][x].has("wall_build"):
				var gp := Vector2i(x, y)
				var end := _trace_outward(gp)
				var k: String = _kind_of(gp, end)
				found_gates[k] = true
				routes.append({"kind": k, "gate": gp, "end": end, "connected": end.x >= 0})
			elif b in ["road", "stone_road"]:
				roads.append(Vector2i(x, y))

	# 사대문 기본 위치 fallback (그리드에 명시적 gate 타일이 없는 초기 상태 대응)
	if grid.has_method("get_four_gates_positions"):
		var four_gates: Dictionary = grid.get_four_gates_positions()
		for fk: String in ["jangan", "paldal", "changryong", "hwaseo"]:
			if not found_gates.has(fk):
				var fg_pos: Vector2i = four_gates[fk]
				if fg_pos.x >= 0 and grid.in_bounds(fg_pos.x, fg_pos.y):
					var end := _trace_outward(fg_pos)
					if end.x >= 0:
						routes.append({"kind": fk, "gate": fg_pos, "end": end, "connected": true})
						found_gates[fk] = true

	hub = _find_hub(roads)
	# 새로 개통된 길 알림(게임을 불러온 직후 첫 계산은 조용히)
	var kinds_now := connected_kinds()
	for k: String in kinds_now:
		if not _announced.has(k):
			_announced[k] = true
			if not _first:
				var inf: Dictionary = INFO[k]
				call_deferred("emit_signal", "notice", "%s 밖 %s가 지도 끝까지 이어졌습니다 — %s에서 %s이(가) 들어옵니다. (세입 +2%%)" % [inf["gate"], inf["dir"], inf["dest"], inf["goods"]], "🪧")
	if kinds_now.size() == 4 and not _announced.has("all"):
		_announced["all"] = true
		if not _first:
			call_deferred("emit_signal", "notice", "사대문 물류망 완성! 사방의 물자가 십자로 시전으로 모여 상업 번영도가 크게 오르고 세입이 +2% 더 늡니다. (교역로 세입 합계 +10%)", "🏮")
	for k2 in _announced.keys():
		if k2 != "all" and not (k2 in kinds_now):
			_announced.erase(k2) # 길이 끊기면 다시 이어질 때 또 알린다
	if kinds_now.size() < 4:
		_announced.erase("all")
	_first = false

## 성문 → 성 밖 길을 따라 지도 가장자리에 닿으면 그 칸, 아니면 (-1,-1)
func _trace_outward(gp: Vector2i) -> Vector2i:
	var sz: int = grid.size
	var seen: Dictionary = {gp: true}
	var q: Array[Vector2i] = [gp]
	var head: int = 0
	while head < q.size() and head < 1200:
		var c: Vector2i = q[head]
		head += 1
		if c != gp and (c.x == 0 or c.x == sz - 1 or c.y == 0 or c.y == sz - 1):
			return c
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n) or not grid.in_bounds(n.x, n.y):
				continue
			if not grid.is_walkable_road_tile(n.x, n.y):
				continue
			seen[n] = true
			q.append(n)
	return Vector2i(-1, -1)

## 현판 이름이 사대문이면 그대로, 아니면 바깥 길이 닿은 지도 가장자리(없으면 지도 중심에서 본 방향)로 정한다
func _kind_of(gp: Vector2i, end: Vector2i) -> String:
	var gn := String(grid.grid[gp.y][gp.x].get("gate_name", ""))
	for k: String in KINDS:
		if gn.begins_with(INFO[k]["gate"]):
			return k
	var sz := grid.size
	var d: Vector2 = Vector2(end - gp) if end.x >= 0 else Vector2(gp) - Vector2(sz, sz) * 0.5
	if absf(d.x) > absf(d.y):
		return "changryong" if d.x > 0 else "hwaseo"
	return "paldal" if d.y > 0 else "jangan"

func _find_hub(roads: Array[Vector2i]) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_s := 2 # 가게 셋 이상 모인 곳만
	for r: Vector2i in roads:
		var shops := 0
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				if absi(dx) + absi(dy) > 3:
					continue
				if String(grid.building_at(r.x + dx, r.y + dy)).begins_with("com"):
					shops += 1
		if shops < 3:
			continue
		var deg := 0
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if grid.building_at(r.x + d.x, r.y + d.y) == "road":
				deg += 1
		var s := shops + (6 if deg >= 4 else (3 if deg == 3 else 0)) + (2 if grid.is_stone_road(r.x, r.y) else 0)
		if s > best_s:
			best_s = s
			best = r
	return best

func connected_kinds() -> Array:
	var out: Array = []
	for r: Dictionary in routes:
		if r["connected"] and not (r["kind"] in out):
			out.append(r["kind"])
	return out

func all_connected() -> bool:
	refresh()
	return connected_kinds().size() == 4

func connected_routes() -> Array:
	refresh()
	return routes.filter(func(r: Dictionary) -> bool: return r["connected"])

## 이 칸이 개통된 성문의 특화 시장(성 안, 성문 MARKET_RADIUS 안)이면 그 문 종류, 아니면 ""
func market_kind_at(x: int, y: int) -> String:
	refresh()
	if grid == null or not grid.in_bounds(x, y):
		return ""
	if grid.grid[y][x]["terrain"] == "outside":
		return ""
	var best := ""
	var bd := MARKET_RADIUS + 1
	for r: Dictionary in routes:
		if not r["connected"]:
			continue
		var gp: Vector2i = r["gate"]
		var d := absi(gp.x - x) + absi(gp.y - y)
		if d < bd:
			bd = d
			best = r["kind"]
	return best

func pool_for(kind: String, b: String) -> Array:
	if b.begins_with("ind"):
		return MARKET_WORKSHOP.get(kind, [])
	return MARKET_BIG[kind] if b == "com_2" else MARKET_SMALL[kind]

## 물류 공급도(0~7): 개통된 성문 6칸 안 +2, 12칸 안 +1(성문 합계 최대 3), 사대문이 모두 이어졌으면 십자로 시전 반경 안 +4
func supply_at(x: int, y: int) -> int:
	refresh()
	var s := 0
	for r: Dictionary in routes:
		if not r["connected"]:
			continue
		var gp: Vector2i = r["gate"]
		var d := absi(gp.x - x) + absi(gp.y - y)
		if d <= MARKET_RADIUS:
			s += 2
		elif d <= MARKET_RADIUS * 2:
			s += 1
	s = mini(s, 3)
	if hub.x >= 0 and absi(hub.x - x) + absi(hub.y - y) <= HUB_RADIUS and connected_kinds().size() == 4:
		s += 4
	return s
