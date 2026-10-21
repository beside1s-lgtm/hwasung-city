extends RefCounted
class_name FacilityMaintenanceManager

## [공공시설 턴당 운영자금 및 유지비 관리 엔진]
## 모든 공공시설, 성곽 방어시설, 관아, 수리시설, 도로망의 턴(월)당 금화 및 곡식 운영자금을 정밀 산출
## 난이도(쉬움: 1.0x, 보통: 1.2x, 어려움: 1.3x) 및 인구 규모(행궁)에 따라 차등 적용

## 쉬움(EASY) 기준 턴당 기본 소모량 테이블 (1개소 또는 지정 단위당)
const BASE_MAINTENANCE_TABLE: Dictionary = {
	# 관공서 및 군사 지휘 시설
	"haenggung": {"gold": 100, "rice": 0, "name": "화성행궁", "dynamic_pop": true},
	"gwana": {"gold": 2000, "rice": 2000, "name": "유수부 관아"},
	"seojangdae": {"gold": 2000, "rice": 2000, "name": "서장대"},
	"yeonmudae": {"gold": 2000, "rice": 2000, "name": "연무대"},
	"patrol": {"gold": 500, "rice": 500, "name": "순라청"},
	"firefighter": {"gold": 500, "rice": 500, "name": "멸화군"},
	"jinhulso": {"gold": 500, "rice": 500, "name": "진휼소"},

	# 성곽 관문 및 방어 시설
	"gate": {"gold": 2000, "rice": 0, "name": "사대문"},
	"hwahong": {"gold": 1000, "rice": 0, "name": "화홍문"},
	"namsu": {"gold": 1000, "rice": 0, "name": "남수문"},
	"bongdon": {"gold": 2000, "rice": 0, "name": "봉돈"},
	"poru": {"gold": 2000, "rice": 0, "name": "포루"},
	"gongsimdon": {"gold": 2000, "rice": 0, "name": "공심돈"},
	"banghwasuryu": {"gold": 2000, "rice": 0, "name": "방화수류정"},
	"chiseong": {"gold": 500, "rice": 0, "name": "치성"},
	"ammun": {"gold": 500, "rice": 0, "name": "암문"},

	# 수리 및 도시 기반 시설
	"manseokgeo": {"gold": 2000, "rice": 2000, "name": "만석거"},
	"chukmanje": {"gold": 2000, "rice": 2000, "name": "축만제"},
	"reservoir": {"gold": 500, "rice": 500, "name": "저수지"},
	"well": {"gold": 500, "rice": 0, "name": "우물"},

	# 교육 및 의료/문화 시설
	"hyanggyo": {"gold": 1000, "rice": 500, "name": "수원향교"},
	"seodang": {"gold": 300, "rice": 100, "name": "서당"},
	"hyeminseo": {"gold": 500, "rice": 500, "name": "혜민서"},
	"jongnu": {"gold": 500, "rice": 0, "name": "종루(여민각)"},
	"yeonghwajeong": {"gold": 500, "rice": 0, "name": "영화정"}
}

## 난이도별 공공시설 운영자금 배율 반환 (SSOT)
## - 쉬움: 1.0배
## - 보통: 1.2배 (+20%)
## - 어려움: 1.3배 (+30%)
static func get_maintenance_multiplier() -> float:
	var diff: DifficultyManager.Difficulty = DifficultyManager.get_difficulty()
	match diff:
		DifficultyManager.Difficulty.EASY:
			return 1.0
		DifficultyManager.Difficulty.NORMAL:
			return 1.20
		DifficultyManager.Difficulty.HARD:
			return 1.30
		_:
			return 1.0

## 행궁 인구 비례 턴당 금화 소모량 계산 (쉬움 기준)
## - 인구 1,000명 미만: 100냥으로 시작
## - 인구 1,000명 이상: 1,000명 증가마다 1,000냥씩 추가 소모 (예: 10,000명일 때 10,000냥)
static func calculate_haenggung_base_gold(population: int) -> int:
	if population < 1000:
		return 100
	var thousands: int = int(floor(float(population) / 1000.0))
	return thousands * 1000

## 전체 그리드 순회(O(N))를 통해 완공된 공공시설, 도로, 성문 현황 집계 및 유지비 총액 계산
static func calculate_turn_maintenance(grid: GameGrid, population: int) -> Dictionary:
	var mult: float = get_maintenance_multiplier()
	var counts: Dictionary = {}
	for k: String in BASE_MAINTENANCE_TABLE.keys():
		counts[k] = 0

	var dirt_road_count: int = 0
	var stone_road_count: int = 0
	var levee_count: int = 0

	if grid != null and "grid" in grid:
		var g_size: int = int(grid.size)
		var visited_anchors: Dictionary = {}

		# 사대문 별도 감지 (장안, 팔달, 화서, 창룡)
		var gates_map: Dictionary = grid.get_four_gates_positions()
		var four_gates_count: int = 0
		var gate_anchors_seen: Dictionary = {}
		for g_key: String in ["jangan", "paldal", "hwaseo", "changryong"]:
			var gp: Vector2i = gates_map.get(g_key, Vector2i(-1, -1))
			if gp.x >= 0 and gp.y >= 0 and grid.in_bounds(gp.x, gp.y):
				var cell_g: Dictionary = grid.grid[gp.y][gp.x]
				if not bool(cell_g.get("under_construction", false)) and not cell_g.has("wall_build"):
					if cell_g.get("building", "") == "gate":
						four_gates_count += 1
						gate_anchors_seen[gp] = true

		counts["gate"] = four_gates_count

		for y: int in range(g_size):
			for x: int in range(g_size):
				var cell: Dictionary = grid.grid[y][x]
				if cell.has("wall_build") or bool(cell.get("under_construction", false)):
					continue

				var b: String = str(cell.get("building", ""))
				var fac: String = str(cell.get("facility_id", ""))

				# 도로 및 제방 (타일 개수 단위)
				if b == "road":
					dirt_road_count += 1
					continue
				elif b == "stone_road":
					stone_road_count += 1
					continue
				elif b == "levee":
					levee_count += 1
					continue

				# 단일 타일 성곽 방어시설
				if b == "bongdon":
					counts["bongdon"] = int(counts["bongdon"]) + 1
					continue
				elif b == "poru":
					counts["poru"] = int(counts["poru"]) + 1
					continue
				elif b == "gongsimdon":
					counts["gongsimdon"] = int(counts["gongsimdon"]) + 1
					continue
				elif b == "chiseong":
					counts["chiseong"] = int(counts["chiseong"]) + 1
					continue
				elif b == "ammun":
					counts["ammun"] = int(counts["ammun"]) + 1
					continue
				elif b == "well":
					counts["well"] = int(counts["well"]) + 1
					continue
				elif b == "seodang":
					counts["seodang"] = int(counts["seodang"]) + 1
					continue
				elif b == "hyeminseo":
					counts["hyeminseo"] = int(counts["hyeminseo"]) + 1
					continue
				elif b == "patrol":
					counts["patrol"] = int(counts["patrol"]) + 1
					continue
				elif b == "firefighter":
					counts["firefighter"] = int(counts["firefighter"]) + 1
					continue
				elif b == "reservoir":
					counts["reservoir"] = int(counts["reservoir"]) + 1
					continue

				# 사대문 외 추가 일반 성문 타일 감지
				if b == "gate":
					var cur_pos := Vector2i(x, y)
					if not gate_anchors_seen.has(cur_pos):
						gate_anchors_seen[cur_pos] = true
						counts["gate"] = int(counts["gate"]) + 1
					continue

				# 다칸 복합 건물 (site_anchor 기준으로 1개소만 카운트)
				var anchor_pos: Vector2i = cell.get("site_anchor", Vector2i(x, y))
				if visited_anchors.has(anchor_pos):
					continue
				visited_anchors[anchor_pos] = true

				if b.begins_with("haenggung") or fac == "haenggung":
					counts["haenggung"] = int(counts["haenggung"]) + 1
				elif b.begins_with("gwana") or fac == "gwana":
					counts["gwana"] = int(counts["gwana"]) + 1
				elif b.begins_with("seojangdae") or fac == "seojangdae" or cell.has("sj2"):
					counts["seojangdae"] = int(counts["seojangdae"]) + 1
				elif b.begins_with("yeonmudae") or fac == "yeonmudae" or cell.has("ym5"):
					counts["yeonmudae"] = int(counts["yeonmudae"]) + 1
				elif b.begins_with("manseokgeo") or fac == "manseokgeo":
					counts["manseokgeo"] = int(counts["manseokgeo"]) + 1
				elif b.begins_with("chukmanje") or fac == "chukmanje":
					counts["chukmanje"] = int(counts["chukmanje"]) + 1
				elif b.begins_with("jinhulso") or fac == "jinhulso":
					counts["jinhulso"] = int(counts["jinhulso"]) + 1
				elif b.begins_with("banghwasuryu") or fac == "banghwasuryu":
					counts["banghwasuryu"] = int(counts["banghwasuryu"]) + 1
				elif b.begins_with("hwahong") or fac == "hwahong":
					counts["hwahong"] = int(counts["hwahong"]) + 1
				elif b.begins_with("namsu") or fac == "namsu":
					counts["namsu"] = int(counts["namsu"]) + 1
				elif b.begins_with("hyanggyo") or fac == "hyanggyo":
					counts["hyanggyo"] = int(counts["hyanggyo"]) + 1
				elif b.begins_with("jongnu") or fac == "jongnu":
					counts["jongnu"] = int(counts["jongnu"]) + 1
				elif b.begins_with("yeonghwajeong") or fac == "yeonghwajeong":
					counts["yeonghwajeong"] = int(counts["yeonghwajeong"]) + 1

	# 비용 총액 및 세부 내역 계산
	var details: Dictionary = {}
	var total_gold: int = 0
	var total_rice: int = 0

	for fac_key: String in BASE_MAINTENANCE_TABLE.keys():
		var fac_info: Dictionary = BASE_MAINTENANCE_TABLE[fac_key]
		var cnt: int = int(counts.get(fac_key, 0))
		if cnt <= 0:
			continue

		var b_gold: int = int(fac_info["gold"])
		var b_rice: int = int(fac_info["rice"])

		# 행궁 인구 비례 특수 산출
		if bool(fac_info.get("dynamic_pop", false)):
			b_gold = calculate_haenggung_base_gold(population)

		var gold_cost: int = int(round(float(b_gold * cnt) * mult))
		var rice_cost: int = int(round(float(b_rice * cnt) * mult))

		total_gold += gold_cost
		total_rice += rice_cost

		details[fac_key] = {
			"name": str(fac_info["name"]),
			"count": cnt,
			"gold": gold_cost,
			"rice": rice_cost
		}

	# 흙길: 10개당 1냥
	if dirt_road_count > 0:
		var dirt_base_gold: int = int(ceil(float(dirt_road_count) / 10.0))
		var dirt_gold: int = int(round(float(dirt_base_gold) * mult))
		total_gold += dirt_gold
		details["road"] = {
			"name": "흙길",
			"count": dirt_road_count,
			"gold": dirt_gold,
			"rice": 0
		}

	# 박석길: 10개당 5냥
	if stone_road_count > 0:
		var stone_base_gold: int = int(ceil(float(stone_road_count) / 10.0)) * 5
		var stone_gold: int = int(round(float(stone_base_gold) * mult))
		total_gold += stone_gold
		details["stone_road"] = {
			"name": "박석길",
			"count": stone_road_count,
			"gold": stone_gold,
			"rice": 0
		}

	# 석축제방: 10개당 5냥
	if levee_count > 0:
		var levee_base_gold: int = int(ceil(float(levee_count) / 10.0)) * 5
		var levee_gold: int = int(round(float(levee_base_gold) * mult))
		total_gold += levee_gold
		details["levee"] = {
			"name": "석축제방",
			"count": levee_count,
			"gold": levee_gold,
			"rice": 0
		}

	return {
		"total_gold": total_gold,
		"total_rice": total_rice,
		"multiplier": mult,
		"details": details,
		"counts": counts,
		"dirt_road_count": dirt_road_count,
		"stone_road_count": stone_road_count,
		"levee_count": levee_count
	}

## 매 턴(월) 실행: 공공시설 운영자금 차감 및 체납 시 페널티 적용
static func apply_turn_maintenance(sim: SimulationCore, grid: GameGrid) -> Dictionary:
	if sim == null:
		return {"total_gold": 0, "total_rice": 0, "deficit_gold": false, "deficit_rice": false}

	var m_res: Dictionary = calculate_turn_maintenance(grid, sim.population)
	var req_gold: int = int(m_res["total_gold"])
	var req_rice: int = int(m_res["total_rice"])

	var deficit_gold: bool = false
	var deficit_rice: bool = false

	# 1. 금화 정산
	if req_gold > 0:
		if sim.gold >= req_gold:
			sim.gold -= req_gold
		else:
			# 국고 고갈 체납 페널티
			deficit_gold = true
			var _shortage_gold: int = req_gold - sim.gold
			sim.gold = 0
			sim.loyalty = maxi(0, sim.loyalty - 6)
			sim.authority = maxi(0, sim.authority - 4)
			sim.emit_signal("disaster_alert", "🚨 [재정 비상] 국고가 고갈되어 공공시설 운영자금이 체납되었습니다! 관리와 군사들의 사기가 꺾이고 민심이 하락합니다. (민심 -6, 왕권 -4)")

	# 2. 곡식(군량) 정산
	if req_rice > 0:
		if sim.rice >= req_rice:
			sim.rice -= req_rice
		else:
			# 군량 고갈 체납 페널티 (기근 및 관아 배급 중단)
			deficit_rice = true
			var _shortage_rice: int = req_rice - sim.rice
			sim.rice = 0
			sim.loyalty = maxi(0, sim.loyalty - 8)
			sim.emit_signal("disaster_alert", "🌾 [군량 고갈] 군량미가 바닥나 순라군과 관공서 양곡 지급이 중단되었습니다! (민심 -8)")

	m_res["deficit_gold"] = deficit_gold
	m_res["deficit_rice"] = deficit_rice
	return m_res
