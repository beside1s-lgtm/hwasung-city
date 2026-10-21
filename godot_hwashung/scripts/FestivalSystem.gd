extends Node
class_name FestivalSystem

## PORT-TRACE [장마당·세시풍속]: 사용자 요청 — 계절마다 장마당(공터)에 민속놀이 판이 열리게(봄 풍물·사자놀이·
## 택견, 여름 단오 씨름·탈춤·석전, 가을 강강술래·남사당 줄타기, 겨울 연날리기·팽이·쥐불놀이).
## 성능 원칙(사용자 명시): 놀이판마다 개별 NPC 인공지능을 돌리지 않는다. 계절이 바뀌는 순간에만 어떤
## 판을 어디에 열지 한 번 정해 scenes 목록에 넣고, 그림은 CitizenLayer가 "공연장 하나 = 관람객·연희자
## 수십 명을 한 번에 그리는 애니메이션 루프"(FestivalArt)로 처리한다. 틱마다 하는 일은 예약된 사건
## (석전 부상자, 씨름 장사 퍼레이드, 쥐불 번짐)의 카운트다운뿐이다. 판 위를 실제로 걸어 다니는 사람은
## 풍물패 길놀이·황소 퍼레이드·들것 세 종류뿐(CitizenManager 도로 이동 재사용).

signal notice(msg: String, icon: String)

var grid: GameGrid
var sim: SimulationCore
var citizens: CitizenManager

## {kind, center: Vector2(타일 좌표), n, seed, dir: Vector2(물 방향, 석전·팽이)}
var scenes: Array = []
## 쥐불이 번진 칸 {pos: Vector2i, ttl: int(틱)}
var fires: Array = []
var _events: Array = [] # {ticks, kind, data}
var anim_t := 0.0

const SEASON_EVENTS := {
	"봄": ["pungmul", "taekkyeon"],
	"여름": ["ssireum", "talchum"],
	"가을": ["ganggang", "juldagi"],
	"겨울": ["kites", "kites"],
}
const EVENT_NAMES := {
	"pungmul": "지신밟기 풍물놀이·사자놀이", "taekkyeon": "택견 겨루기",
	"ssireum": "단오 씨름판", "talchum": "탈춤 마당", "seokjeon": "석전(돌싸움)",
	"ganggang": "대동제 강강술래", "juldagi": "남사당패 줄타기",
	"kites": "연날리기", "paengi": "얼음판 팽이치기", "jwibul": "쥐불놀이",
}

func setup(g: GameGrid, s: SimulationCore, c: CitizenManager) -> void:
	grid = g
	sim = s
	citizens = c

func _process(delta: float) -> void:
	anim_t += delta * (citizens.time_scale if citizens else 1.0)

## 계절이 바뀌는 순간 1회: 어떤 놀이판을 어디에 열지 정한다
func on_season_changed(season: String) -> void:
	scenes.clear()
	fires.clear()
	_events.clear()
	var names: Array[String] = []
	var plazas: Array = grid.list_plazas()
	if plazas.is_empty() and grid != null:
		# 저잣거리 공터가 아직 없으면 행궁 신풍루 앞마당이나 도로변 트인 평지를 대체 앵커로 활용
		var haenggung_pos := BuildingManager.get_building_pos("haenggung", grid)
		if haenggung_pos.x >= 0:
			var front_pos := haenggung_pos + Vector2i(4, 0) # 신풍루 앞마당
			plazas.append({"x0": front_pos.x, "y0": front_pos.y, "n": 2, "center": Vector2(front_pos) + Vector2(1.0, 1.0)})
		elif citizens and not citizens._roads_cache.is_empty():
			var rp: Vector2i = citizens._roads_cache[0]
			plazas.append({"x0": rp.x, "y0": rp.y, "n": 2, "center": Vector2(rp) + Vector2(1.0, 1.0)})

	var kinds: Array = SEASON_EVENTS.get(season, [])
	var kite_spots: Array[Vector2i] = []
	for i in range(mini(plazas.size(), 3)):
		var pl: Dictionary = plazas[i]
		var kind: String = kinds[i % kinds.size()]
		if kind == "kites":
			# PORT-TRACE [연날리기 물가 제한]: 사용자 요청 — 연날리기는 장마당이 아니라 수원천·만석거 등 물가 3칸 안의
			# 트인 빈 땅에서만. 마땅한 물가가 없으면 그 판은 열지 않는다.
			var ks := _waterfront_open_spot(kite_spots)
			if ks.x < 0:
				continue
			kite_spots.append(ks)
			scenes.append({"kind": kind, "center": Vector2(ks) + Vector2(0.5, 0.5), "n": 2, "seed": randi() % 1000, "plaza": ks})
		else:
			scenes.append({"kind": kind, "center": pl["center"], "n": int(pl["n"]), "seed": randi() % 1000, "plaza": Vector2i(int(pl["x0"]), int(pl["y0"]))})
		if not (EVENT_NAMES[kind] in names):
			names.append(EVENT_NAMES[kind])
	var banks: Array = citizens._water_banks_cache if citizens else []
	match season:
		"봄":
			# 지신밟기 풍물패 길놀이: 꽹과리·장구 치며 장터 길을 돈다
			if citizens and not citizens._roads_cache.is_empty():
				var start: Vector2i = citizens._front_road_of(Vector2i(int(plazas[0]["x0"]), int(plazas[0]["y0"]))) if not plazas.is_empty() else citizens._roads_cache[0]
				citizens.spawn_festival_walker("pungmul_band", start, 70.0, "덩더쿵 덩더쿵! 지신 밟세~")
		"여름":
			var seokjeon_pairs: Array = citizens._seokjeon_pairs_cache if citizens else []
			if not seokjeon_pairs.is_empty():
				# 제방(levee)이 포함된 쌍을 우선적으로 필터링
				var levee_pairs: Array = seokjeon_pairs.filter(func(pr: Dictionary) -> bool:
					var b_a: Vector2i = pr["bank_a"]
					var b_b: Vector2i = pr["bank_b"]
					return (grid.grid[b_a.y][b_a.x].get("building", "") == "levee" or grid.grid[b_b.y][b_b.x].get("building", "") == "levee")
				)
				var chosen_pair: Dictionary = levee_pairs[randi() % levee_pairs.size()] if not levee_pairs.is_empty() else seokjeon_pairs[randi() % seokjeon_pairs.size()]
				var pa: Vector2i = chosen_pair["bank_a"]
				var pb: Vector2i = chosen_pair["bank_b"]
				# 물 안쪽 타일 스폰 차단 엄격 검증
				assert(grid.grid[pa.y][pa.x].get("terrain", "") != "water", "Seokjeon bank_a must not be water")
				assert(grid.grid[pb.y][pb.x].get("terrain", "") != "water", "Seokjeon bank_b must not be water")
				scenes.append({
					"kind": "seokjeon",
					"center": Vector2(pa) + Vector2(0.5, 0.5),
					"other_pos": Vector2(pb) + Vector2(0.5, 0.5),
					"n": 2,
					"seed": randi() % 1000,
					"dir": chosen_pair["dir"]
				})
				names.append(EVENT_NAMES["seokjeon"])
				_events.append({"ticks": randi_range(12, 30), "kind": "injury", "data": pa})
			elif not banks.is_empty():
				var b: Dictionary = banks[randi() % banks.size()]
				var bp: Vector2i = b["pos"]
				if grid.grid[bp.y][bp.x].get("terrain", "") != "water":
					scenes.append({"kind": "seokjeon", "center": Vector2(bp) + Vector2(0.5, 0.5), "n": 2, "seed": randi() % 1000, "dir": b["water_dir"]})
					names.append(EVENT_NAMES["seokjeon"])
					_events.append({"ticks": randi_range(12, 30), "kind": "injury", "data": bp})
			for sc in scenes:
				if sc["kind"] == "ssireum":
					_events.append({"ticks": randi_range(20, 40), "kind": "winner_parade", "data": sc["plaza"]})
					break
		"겨울":
			if not banks.is_empty():
				var b2: Dictionary = banks[randi() % banks.size()]
				var wd: Vector2 = b2["water_dir"]
				scenes.append({"kind": "paengi", "center": Vector2(b2["pos"]) + Vector2(0.5, 0.5) + wd * 0.9, "n": 2, "seed": randi() % 1000, "dir": wd})
				names.append(EVENT_NAMES["paengi"])
			if citizens and not citizens._agr_cache.is_empty():
				var fp: Vector2i = citizens._agr_cache[randi() % citizens._agr_cache.size()]
				scenes.append({"kind": "jwibul", "center": Vector2(fp) + Vector2(0.5, 0.5), "n": 2, "seed": randi() % 1000, "field": fp})
				names.append(EVENT_NAMES["jwibul"])
				if randf() < 0.35:
					_events.append({"ticks": randi_range(10, 30), "kind": "jwibul_fire", "data": fp})
	if not names.is_empty():
		var lead := {"봄": "봄을 맞아", "여름": "단오를 맞아", "가을": "풍년을 맞아", "겨울": "동지·대보름을 맞아"}
		emit_signal("notice", "%s %s 판이 열렸습니다!" % [lead.get(season, ""), ", ".join(names)], "🎊")

## 틱마다: 예약 사건 카운트다운과 불 끄기만(가벼움)
func on_tick(_t: int) -> void:
	if _events.is_empty() and fires.is_empty():
		return
	var keep: Array = []
	for e in _events:
		e["ticks"] = int(e["ticks"]) - 1
		if int(e["ticks"]) <= 0:
			_fire_event(e)
		else:
			keep.append(e)
	_events = keep
	var keep_f: Array = []
	for fr in fires:
		fr["ttl"] = int(fr["ttl"]) - 1
		if int(fr["ttl"]) > 0:
			keep_f.append(fr)
	fires = keep_f

func _fire_event(e: Dictionary) -> void:
	match String(e["kind"]):
		"injury":
			# 석전 부상자: 약방(있으면) 또는 행궁·순라청으로 들것에 실려 간다
			var from: Vector2i = e["data"]
			var to := _find_tile(func(t: Dictionary) -> bool: return t.get("trade", "") == "herb")
			var where := "약방"
			if to.x < 0:
				to = _find_tile(func(t: Dictionary) -> bool: return String(t["building"]).begins_with("haenggung"))
				where = "관아(행궁)"
			if to.x < 0:
				return
			if citizens:
				citizens.spawn_patient(from, "석전") # 가까운 약방(없으면 행궁)으로 들것 후송·치료
			emit_signal("notice", "석전에서 돌에 맞아 다친 사람이 생겨 %s(으)로 들것에 실려 갑니다." % where, "🩹")
		"winner_parade":
			var pl: Vector2i = e["data"]
			if citizens and not citizens._roads_cache.is_empty():
				citizens.spawn_festival_walker("bull_parade", citizens._front_road_of(pl), 55.0, "천하장사 납시오!")
				emit_signal("notice", "씨름판 장사가 상으로 받은 황소를 타고 장터를 한 바퀴 돕니다!", "🐂")
		"jwibul_fire":
			var fp: Vector2i = e["data"]
			var has_ff := _find_tile(func(t: Dictionary) -> bool: return t["building"] == "firefighter", fp, 10).x >= 0
			if has_ff:
				fires.append({"pos": fp, "ttl": 6})
				emit_signal("notice", "쥐불이 논두렁 볏짚에 번졌으나 멸화군이 곧 출동해 껐습니다.", "🧯")
			else:
				fires.append({"pos": fp, "ttl": 18})
				if sim:
					sim.rice = maxi(0, sim.rice - 40)
				emit_signal("notice", "쥐불이 번져 볏짚 더미가 탔습니다! (곡식 -40석) 멸화군을 두면 막을 수 있습니다.", "🔥")

## 조건에 맞는 타일(center 기준 반경 radius 안, radius<0이면 지도 전체)
func _find_tile(pred: Callable, center: Vector2i = Vector2i(-1, -1), radius: int = -1) -> Vector2i:
	for y in range(grid.size):
		for x in range(grid.size):
			if radius >= 0 and absi(x - center.x) + absi(y - center.y) > radius:
				continue
			if pred.call(grid.grid[y][x]):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

## 물(water) 3칸 안의 트인 빈 땅(건물·구획·공터 없는 평지, 주변 3x3 중 6칸 이상 비어 있음). used와 4칸 이상 떨어진 곳.
func _waterfront_open_spot(used: Array[Vector2i]) -> Vector2i:
	if citizens == null or citizens._water_banks_cache.is_empty():
		return Vector2i(-1, -1)
	var banks: Array = citizens._water_banks_cache.duplicate()
	banks.shuffle()
	for b: Dictionary in banks.slice(0, 40):
		var bp: Vector2i = b["pos"]
		for r in range(0, 4):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if maxi(absi(dx), absi(dy)) != r:
						continue
					var q := bp + Vector2i(dx, dy)
					if not _open_ground(q) or not _near_water(q, 3):
						continue
					var far := true
					for u: Vector2i in used:
						if absi(u.x - q.x) + absi(u.y - q.y) < 4:
							far = false
					if not far:
						continue
					var open_n := 0
					for ny in range(-1, 2):
						for nx in range(-1, 2):
							if _open_ground(q + Vector2i(nx, ny)):
								open_n += 1
					if open_n >= 6:
						return q
	return Vector2i(-1, -1)

func _open_ground(q: Vector2i) -> bool:
	if not grid.in_bounds(q.x, q.y):
		return false
	var t: Dictionary = grid.grid[q.y][q.x]
	return t["building"] == "" and t["zone"] == "" and not t.has("plaza") and t["terrain"] in ["plain", "outside"]

func _near_water(q: Vector2i, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if grid.in_bounds(q.x + dx, q.y + dy) and grid.grid[q.y + dy][q.x + dx]["terrain"] == "water":
				return true
	return false
