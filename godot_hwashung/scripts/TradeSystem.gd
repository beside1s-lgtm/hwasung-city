extends Node
class_name TradeSystem

# PORT-TRACE: src/core/GameState.ts checkTradeSystem + advanceTurn 교역 블록, trade state
# 이식 로그: docs/godot_port_log.md 항목 P4, P22 (동서남북 4대 교역로 개별 구현)
## TS 원본은 "지도 가장자리에 도로가 닿았는가"라는 단일 불리언만 판정했다. 참조 설계문서
## (docs/simcity2000_reference_architecture.md)의 "외곽 경계 도달 시 한양/호남/영남/남양만
## 포구와 연결"이라는 서술을 실제로 4방향 개별 교역로로 구현한다.
## PORT-TRACE P23: 지도가 실제 화성 답사 지도 기준 고정 영토로 바뀌면서 성곽이 더 이상 지도
## 가장자리(x/y=0 또는 size-1)에 닿지 않는다. 이제는 실제 4대문 좌표(GameGrid의
## generate_map.py GATES와 반드시 일치)를 통과해야 교역이 열린다.

signal route_connected(key: String, name: String)
signal route_disconnected(key: String, name: String)

var grid: GameGrid
var sim: SimulationCore
var citizens: CitizenManager

var auto_buy_rice: bool = true
var total_imported_rice: int = 0
var active_merchants: int = 0

## 하위호환: 기존 UI/테스트가 참조하는 전체 연결 여부 요약
var trade_connected: bool = false
var has_border_gate: bool = false

## 실제 화성 4대문 좌표 (generate_map.py의 GATES와 반드시 일치시킬 것)
## PORT-TRACE P24: 64x64 확장 지도 좌표로 갱신 (generate_map.py GATES와 반드시 동기화)
const GATE_POINTS := {
	"north": Vector2i(26, 6),   # 장안문 -> 한양 조운로
	"east": Vector2i(48, 29),   # 창룡문 -> 영남대로
	"south": Vector2i(16, 54),  # 팔달문 -> 호남 삼남대로
	"west": Vector2i(6, 13),    # 화서문 -> 남양만 포구 해로
}

const ROUTES := [
	{"key": "north", "name": "장안문 - 한양 조운로(북)", "resource": "gold", "amount": 120},
	{"key": "south", "name": "팔달문 - 호남 삼남대로(남)", "resource": "rice", "amount": 130},
	{"key": "east", "name": "창룡문 - 영남대로(동)", "resource": "gold", "amount": 110},
	{"key": "west", "name": "화서문 - 남양만 포구 해로(서)", "resource": "rice", "amount": 120},
]

var route_connected_state := {"north": false, "south": false, "east": false, "west": false}
var route_gated_state := {"north": false, "south": false, "east": false, "west": false}
var route_border_points := {"north": Vector2i(-1, -1), "south": Vector2i(-1, -1), "east": Vector2i(-1, -1), "west": Vector2i(-1, -1)}

func setup(g: GameGrid, s: SimulationCore, c: CitizenManager) -> void:
	grid = g
	sim = s
	citizens = c

## 도로 타일 여부 검사 (일반 도로, 박석길, 다리, 제방 등)
func _is_trade_road(x: int, y: int) -> bool:
	if grid == null or not grid.in_bounds(x, y):
		return false
	var t: Dictionary = grid.grid[y][x]
	var b: String = t.get("building", "")
	return b in ["road", "stone_road", "gate", "bridge", "levee"] or t.get("is_bridge", false)

## 사대문에서 맵 최외곽 가장자리 경계까지의 거의 직선(편차 +-3칸 이내) 연속 도로 연결 BFS 검사
func _check_straight_road_to_border(key: String, pt: Vector2i) -> Dictionary:
	if grid == null or not grid.in_bounds(pt.x, pt.y):
		return {"connected": false, "border_pt": Vector2i(-1, -1)}

	if not _is_trade_road(pt.x, pt.y):
		return {"connected": false, "border_pt": Vector2i(-1, -1)}

	var sz: int = grid.size
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [pt]
	visited[pt] = true

	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]

	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()

		# 맵 최외곽 경계 도달 확인
		match key:
			"north":
				if curr.y == 0:
					return {"connected": true, "border_pt": curr}
			"south":
				if curr.y == sz - 1:
					return {"connected": true, "border_pt": curr}
			"east":
				if curr.x == sz - 1:
					return {"connected": true, "border_pt": curr}
			"west":
				if curr.x == 0:
					return {"connected": true, "border_pt": curr}

		for d: Vector2i in dirs:
			var nxt := curr + d
			if not grid.in_bounds(nxt.x, nxt.y):
				continue
			if visited.has(nxt):
				continue

			# 거의 직선(주 방향 전진 및 수직 편차 +-3칸 이내) 기하학 검사
			match key:
				"north":
					if nxt.y > pt.y or absi(nxt.x - pt.x) > 3:
						continue
				"south":
					if nxt.y < pt.y or absi(nxt.x - pt.x) > 3:
						continue
				"east":
					if nxt.x < pt.x or absi(nxt.y - pt.y) > 3:
						continue
				"west":
					if nxt.x > pt.x or absi(nxt.y - pt.y) > 3:
						continue

			if not _is_trade_road(nxt.x, nxt.y):
				continue

			visited[nxt] = true
			queue.append(nxt)

	return {"connected": false, "border_pt": Vector2i(-1, -1)}

## 즉시 재판정: 사대문과 맵 외곽 경계 사이 도로망 연결 상태를 검사하여 교역로를 즉시 개통/단절한다.
## 관문(gate)을 지으면 정식 통관(관세 2배), 도로(road)만 뚫으면 밀수 경로(왕권 소폭 하락)로 취급한다.
func check_routes() -> void:
	if grid == null:
		return
	var any_connected := false
	var any_gated := false
	for r in ROUTES:
		var key: String = r["key"]
		var pt: Vector2i = GATE_POINTS[key]
		var t_gate: Dictionary = grid.grid[pt.y][pt.x]
		var b: String = t_gate.get("building", "")
		var gated: bool = b == "gate" and not t_gate.has("wall_build")

		var res: Dictionary = _check_straight_road_to_border(key, pt)
		var connected: bool = res["connected"]
		var border_pt: Vector2i = res["border_pt"]
		route_border_points[key] = border_pt

		var was_connected: bool = route_connected_state[key]
		route_connected_state[key] = connected
		route_gated_state[key] = gated

		if connected and not was_connected:
			emit_signal("route_connected", key, r["name"])
			if sim and sim.has_signal("notice"):
				sim.emit_signal("notice", "[교역로 개통] " + r["name"] + "이 연결되어 상단과 물자가 유입됩니다!")
			if citizens and citizens.agents.size() < 35:
				citizens.spawn_trade_caravan(border_pt, pt)
				active_merchants += 1
		elif was_connected and not connected:
			emit_signal("route_disconnected", key, r["name"])
			if sim and sim.has_signal("notice"):
				sim.emit_signal("notice", "[교역로 단절] " + r["name"] + " 도로가 끊겼습니다.")

		any_connected = any_connected or connected
		any_gated = any_gated or gated
	trade_connected = any_connected
	has_border_gate = any_gated

## 턴당 교역 효과: 연결된 방향마다 개별 자원 유입/유출. 관문이 있으면 배가, 없으면 밀수로 왕권 손실.
func apply_turn() -> Dictionary:
	check_routes()
	var add_gold := 0
	var add_rice := 0
	for r in ROUTES:
		var key: String = r["key"]
		if not route_connected_state[key]:
			continue
		var amt: int = r["amount"]
		if route_gated_state[key]:
			amt *= 2
			sim.authority = min(100, sim.authority + 1)
		else:
			sim.authority = max(0, sim.authority - 1)
			sim.demand_com = min(100, sim.demand_com + 6)
		if r["resource"] == "gold":
			add_gold += amt
		else:
			add_rice += amt

		# 활성 교역로를 통해 타국/타지역 보부상 및 짐수레 마차 정기 유입
		var b_pt: Vector2i = route_border_points.get(key, Vector2i(-1, -1))
		if citizens and b_pt.x >= 0 and citizens.agents.size() < 35:
			citizens.spawn_trade_caravan(b_pt, GATE_POINTS[key])

	if sim.rice < 100 and auto_buy_rice and sim.gold >= 200:
		sim.gold -= 200
		sim.rice += 250
		total_imported_rice += 250
	return {"gold": add_gold, "rice": add_rice}
