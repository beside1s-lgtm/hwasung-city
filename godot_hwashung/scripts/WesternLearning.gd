extends Node
class_name WesternLearning

## PORT-TRACE [서학 디버프·보유론·서기수용론]: 사용자 요청(서학·최적화 명세 2단계) —
##  · 서학 성향 인재(정약용·홍대용, CourtSystem.PROFILE.western)가 조정에 있으면 매 턴 30% 확률로 방·리의 초가·기와집 하나가
##    '천주교당(비공식 집회소)'이 된다(t["cheonju"], 서학 인재 수 x2, 최대 4곳).
##  · 천주교당이 있는 동안 보수파 상소·사상 혼란으로 매 턴 왕권 -1(곳당, 최대 -3).
##  · 해소 1(왕권 회복 행동): 현륭원 참배·을묘원행 격쟁 판결(기존), 장용영 무예 사열(새, 1년 1번), 정통 유학 인재 등용(왕권 +3).
##  · 해소 2(연구, 영구): 보유론(補儒論) — 왕권 감소 소멸, 민심 +1/턴, 학문력 +5.
##    서기수용론(西器受容論) — 왕권 감소 무효, 서학 인재가 있으면 연구 비용 추가 -30%, 대역사 비용 -20%.
## 기존 턴 진행 로직과 분리된 독립 리스너(sim.turn_advanced)로만 동작한다.

signal notice(text: String, icon: String)

var grid: GameGrid
var sim: SimulationCore
var court: CourtSystem
const ORTHODOX := ["chae", "lee_deokmu", "yu_deukgong", "seo", "yu"] # 정통 유학(주자학) 성향 — 등용 시 왕권 +3

func setup(g: GameGrid, s: SimulationCore, c: CourtSystem) -> void:
	grid = g
	sim = s
	court = c
	sim.turn_advanced.connect(_on_turn)

func western_hired() -> int:
	var n := 0
	for id in CourtSystem.SCHOLARS:
		if court.is_western(id) and sim.retainers.get(CourtSystem.SCHOLARS[id]["key"], false):
			n += 1
	return n

func chapels() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(grid.size):
		for x in range(grid.size):
			if grid.grid[y][x].get("cheonju", false):
				if str(grid.grid[y][x]["building"]).begins_with("res_"):
					out.append(Vector2i(x, y))
				else:
					grid.grid[y][x].erase("cheonju") # 집이 헐렸으면 집회소도 사라짐
	return out

func debuff_active() -> bool:
	return not (sim.boyuron or sim.segi_policy)

func _on_turn(_turn: int, _season: int, _year: int) -> void:
	var nw := western_hired()
	var ch := chapels()
	if nw > 0 and ch.size() < mini(4, nw * 2) and randf() < 0.3:
		var houses: Array[Vector2i] = []
		for y in range(grid.size):
			for x in range(grid.size):
				var t: Dictionary = grid.grid[y][x]
				if (t["building"] == "res_1" or t["building"] == "res_2") and not t.has("hgroup") and not t.get("cheonju", false):
					houses.append(Vector2i(x, y))
		if not houses.is_empty():
			var h: Vector2i = houses[randi() % houses.size()]
			grid.grid[h.y][h.x]["cheonju"] = true
			ch.append(h)
			var ch_tiles: Array[Vector2i] = [h]
			grid.emit_signal("grid_tiles_changed", ch_tiles)
			grid.emit_signal("grid_changed")
			if debuff_active():
				emit_signal("notice", "서학을 따르는 백성들이 민가에 몰래 모이는 천주교당(집회소)이 생겼습니다. 보수 유림의 상소가 빗발쳐 왕권이 흔들립니다! (보유론·서기수용론 연구, 왕권 강화 행동으로 다스리십시오)", "✝")
			else:
				emit_signal("notice", "민가에 천주교당(집회소)이 생겼으나, 조정의 서학 수용 방침으로 큰 동요는 없습니다.", "✝")
	if not ch.is_empty() and debuff_active():
		sim.authority = maxi(0, sim.authority - mini(3, ch.size()))
	if sim.boyuron:
		sim.loyalty = mini(100, sim.loyalty + 1)

## 장용영 무예 사열 — 1년에 한 번, 금 200, 왕권 +5(장용영 총관 백동수가 있으면 +8)
func review_jangyongyeong() -> String:
	if sim.jangyong_review_year == sim.current_year:
		return "올해는 이미 장용영 무예 사열을 마쳤습니다."
	if sim.gold < 200:
		return "사열에 쓸 국고(금 200)가 부족합니다."
	sim.gold -= 200
	sim.jangyong_review_year = sim.current_year
	var gain := 8 if sim.retainers.get("baek_dongsu", false) else 5
	sim.authority = mini(100, sim.authority + gain)
	sim.emit_signal("state_updated", sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)
	return "장용영 군사들이 무예24기를 펼치는 사열을 받았습니다. 국왕의 위엄이 섰습니다! (왕권 +%d)" % gain
