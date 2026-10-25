extends Node
class_name TurnSystem

# PORT-TRACE: src/core/GameState.ts advanceTurn (구획 발전, 수확, 교역, 국책사업 결과 반영)
# SimulationCore(틱 기반 월 예산/계절 재해)는 보존하고, 이 노드는 "턴당 추가 항목"만 더한다.
# 이식 로그: docs/godot_port_log.md 항목 P8

## PORT-TRACE [경량화 감사]: 예전엔 (article: Dictionary, dilemma: bool) 2개 인자를 내보냈으나,
## PanelController._on_turn_report(rep: Dictionary)가 인자 1개짜리 요약 딕셔너리로 리팩터되면서
## 시그니처가 어긋나 매 턴마다 "Method expected 1 argument(s), but called with 2" 런타임 에러가
## 발생하고 있었다(암행어사 딜레마 팝업도 그 여파로 완전히 죽어 있었음). 단일 dict로 통일하고
## dilemma 트리거를 되살렸다.
signal turn_report(rep: Dictionary)
signal site_completed(building: String) # PORT-TRACE [터 축조]: 행궁/동헌 등 다칸 터 완공 알림

var sim: SimulationCore
var grid: GameGrid
var court: CourtSystem
var trade: TradeSystem
var outside: OutsideSettlement # PORT-TRACE P25: 성 밖 자연발생 취락
var audio: AudioSystem # PORT-TRACE P20: 턴 경과(season)/대역사 완공(coin) 효과음

var latest_article: Dictionary = {}
## PORT-TRACE [계절 결산]: 정산은 달마다 하지만 결산 알림은 계절이 끝날 때 석 달 치를 모아 한 번 낸다
var _season_acc: Dictionary = {"tax_income": 0, "harvest": 0, "maintenance_gold": 0, "maintenance_rice": 0}

func setup(s: SimulationCore, g: GameGrid, c: CourtSystem, t: TradeSystem, o: OutsideSettlement = null) -> void:
	sim = s
	grid = g
	court = c
	trade = t
	outside = o
	sim.turn_advanced.connect(_on_turn)
	sim.project_started.connect(_on_project_started)
	sim.project_finished.connect(_on_project_finished)
	# 맵에 이미 설치된 건축물과 국책 대역사 동기화
	sim.sync_mega_projects_with_grid(grid)
	# 시작 시 이미 착공 상태인 대역사의 비계 표시
	for p in sim.mega_projects:
		# PORT-TRACE [제방 연속화]: 수원천 제방은 고정 8칸 대신 실제 물길 양안 전체를 대상으로
		if p["id"] == "suwon_levee":
			var bank: Array = grid.river_levee_targets()
			if not bank.is_empty():
				p["target_tiles"] = bank
		if p["is_started"]:
			grid.set_construction(p["target_tiles"], true)
	latest_article = NewspaperSystem.generate(sim, grid, "")

func _project(id: String) -> Dictionary:
	for p in sim.mega_projects:
		if p["id"] == id:
			return p
	return {}

func _on_project_started(id: String) -> void:
	var p := _project(id)
	if not p.is_empty():
		# PORT-TRACE [제방 연속화]: 착공 시점의 물길·빈 땅 기준으로 다시 잡는다(그사이 강변에 지은
		# 건물을 제방으로 덮어쓰지 않도록).
		if id == "suwon_levee":
			var bank: Array = grid.river_levee_targets()
			if not bank.is_empty():
				p["target_tiles"] = bank
		grid.set_construction(p["target_tiles"], true)

func _on_project_finished(id: String) -> void:
	var p := _project(id)
	if not p.is_empty():
		grid.complete_targets(p["target_tiles"])
		grid.place_project_structures(p.get("structures", [])) # 성곽 대역사에 딸린 공심돈·포루
		grid.recompute_infrastructure(sim.retainers["jeong_yakyong"])
		sim.flood_defense = max(sim.flood_defense, grid.flood_defense)
		if audio: audio.play("coin")

var _is_processing_turn: bool = false

func process_turn() -> void:
	if _is_processing_turn:
		return
	_is_processing_turn = true
	var cur_turn: int = sim.turn if sim else 0
	var season_idx: int = sim.season_now() if sim else 0
	var cur_yr: int = sim.current_year if sim else 1789
	await _execute_turn_stepped(cur_turn, season_idx, cur_yr)

func _on_turn(turn: int, season_index: int, year: int) -> void:
	if _is_processing_turn:
		return
	_is_processing_turn = true
	await _execute_turn_stepped(turn, season_index, year)

## 턴 계산을 다음 프레임으로 넘긴다. 그 프레임의 무거운 일 차례(GameGrid.frame_claim)는 턴 계산이 먼저 차지해,
## 지도가 바뀌어 생기는 다시 계산(시민 길 정보·가림막·지도 굽기)은 턴이 끝난 뒤 프레임마다 하나씩 한다.
func _next_frame() -> void:
	if is_inside_tree():
		await get_tree().process_frame
		GameGrid.frame_take()

func _execute_turn_stepped(turn: int, season_index: int, year: int) -> void:
	GameGrid.frame_take()
	# 1단계: 축조 공정 및 교역 진행
	for completed_building in grid.process_site_tick(sim):
		emit_signal("site_completed", completed_building)
	var wall_done: Dictionary = grid.process_wall_builds()
	if int(wall_done["gate"]) > 0:
		emit_signal("site_completed", "gate")
	if int(wall_done["wall"]) > 0:
		emit_signal("site_completed", "wall")
	for b in wall_done.get("others", []):
		emit_signal("site_completed", b)

	# [자율 완공 시뮬레이션 엔진 연동]
	# 인부 도달 여부와 무관하게 매 턴 모든 공사 중 타일에 자율 진행도(+20%~+35%)를 누적하고, 6턴 이상 정체 시 강제 완공
	var self_completed: Array[Vector2i] = ConstructionManager.process_turn(grid, sim)
	var reported_this_turn: Dictionary = {}
	for cp: Vector2i in self_completed:
		if grid.in_bounds(cp.x, cp.y):
			var cb: String = grid.grid[cp.y][cp.x].get("building", "")
			if cb != "":
				# 일반 민가/상점/농지/공방 구획 및 도로는 김판관 완료 보고 대상에서 제외
				if cb.begins_with("res") or cb.begins_with("com") or cb.begins_with("agr") or cb.begins_with("ind") or cb in ["road", "stone_road", "canal"]:
					continue
				var norm_cb: String = cb
				if norm_cb.ends_with("_site"):
					norm_cb = norm_cb.trim_suffix("_site")
				elif norm_cb.ends_with("_range"):
					norm_cb = norm_cb.trim_suffix("_range")
				elif norm_cb.ends_with("_wall"):
					norm_cb = norm_cb.trim_suffix("_wall")
				if not reported_this_turn.has(norm_cb):
					reported_this_turn[norm_cb] = true
					emit_signal("site_completed", norm_cb)

	# [건설 교착 해소]: 부지(active_sites) 및 wall_build 비계 분산 검사
	if turn % 2 == 1:
		var stall_done: Array = grid.check_stalled_construction()
		for sb: String in stall_done:
			if sb != "" and not reported_this_turn.has(sb):
				reported_this_turn[sb] = true
				emit_signal("site_completed", sb)

	# [국책 대역사 건축물 동기화]: 완공된 건물에 상응하는 대역사 자동 완료 전환
	if sim:
		sim.sync_mega_projects_with_grid(grid)

	var trade_res := trade.apply_turn()

	await _next_frame()

	# 2단계: 민심/정책 적용 및 구획 발전/수확
	grid.set_flood_crisis(sim.flood_crisis_active)
	grid.set_disasters(sim.drought_active, sim.flood_crisis_active, sim.fire_active)
	grid.set_policy(sim.loyalty, sim.tax_rate_market, sim.tax_rate_land, sim.tax_rate_military, sim.population)
	var y: Dictionary = await grid.develop_and_harvest(sim.demand_res, sim.demand_com, sim.demand_agr, court.hyoryungwon["blessing"], is_inside_tree())
	if int(y.get("shops_closed", 0)) > 0:
		# 실제 까닭만 알린다(예전엔 입지가 나빠 문 닫은 가게도 늘 "시전세가 무겁거나"로 알려 세율을 낮춰도 헷갈렸다)
		var why: Array[String] = []
		if int(y.get("shops_closed_tax", 0)) > 0:
			why.append("시전세가 무거워 %d곳" % int(y["shops_closed_tax"]))
		if int(y.get("shops_closed_unrest", 0)) > 0:
			why.append("민심이 흉흉하여 %d곳" % int(y["shops_closed_unrest"]))
		if int(y.get("shops_closed_site", 0)) > 0:
			why.append("길에서 멀거나 성 밖 외진 자리라 장사가 안 되어 %d곳" % int(y["shops_closed_site"]))
		court.emit_signal("notice", "저잣거리 가게가 문을 닫거나 규모를 줄였습니다: %s." % ", ".join(why))
	y["gold"] += trade_res["gold"]

	# 3단계: 둔전 농업 생산 및 성문 물류 세입 다변수 산출
	# PORT-TRACE [렉: 턴 정산 멈칫]: 구획 발전 마지막 줄들, 관개 다시 계산(20ms 남짓), 농업 산출(10ms 남짓)을 프레임마다 나눈다
	await _next_frame()
	IrrigationManager.recalculate_irrigation(grid, sim)
	await _next_frame()
	var agri: Dictionary = calculate_agricultural_production(season_index, false)
	y["rice"] = agri["net_income"] + trade_res["rice"]

	await _next_frame()

	# 4단계: 조정 효과 및 조세 세수 산출
	var adj := court.apply_turn_effects(y)
	sim.gold += adj["gold"]
	sim.rice = max(0, sim.rice + adj["rice"])
	# [인구 상한] 구획 발전으로 늘어나는 인구도 상한(세율·생산력 중 작은 쪽)을 넘지 않는다(줄어드는 쪽은 그대로)
	var add_pop: int = int(adj["pop"])
	if add_pop > 0:
		var cap_now: int = int(TaxManager.get_population_cap(TaxManager.get_total_tax_rate(sim), grid)["cap"])
		add_pop = clampi(cap_now - sim.population, 0, add_pop)
	sim.population += add_pop

	var base_gold: int = adj["gold"]
	var base_rice: int = adj["rice"]
	var tax_mult: float = DifficultyManager.get_tax_multiplier()
	var tax_market: int = int(floor(float(base_gold) * (float(sim.tax_rate_market) / 7.0) * tax_mult))
	var tax_land: int = int(floor((float(base_rice) * 0.2) * (float(sim.tax_rate_land) / 7.0) * tax_mult))
	var tax_military: int = int(floor((float(sim.population) * 0.5) * (float(sim.tax_rate_military) / 7.0) * tax_mult))
	sim.gold += (tax_market + tax_land + tax_military)

	# [경제 동역학 엔진 연동] 조세 저항선 평가, 2년차 등급별 차등 세수 징수 및 21% 기준 시장 부양력 동역학
	var econ_res: Dictionary = sim.process_turn_economy(grid)
	var diff_tax_info: Dictionary = econ_res.get("diff_tax", {})
	var diff_tax_amt: int = int(diff_tax_info.get("total_tax", 0))

	var avg_tax: float = (sim.tax_rate_land + sim.tax_rate_market + sim.tax_rate_military) / 3.0
	if avg_tax > 10.0:
		sim.loyalty = max(0, sim.loyalty - int(round(avg_tax - 10.0)))
	elif avg_tax < 7.0:
		sim.loyalty = min(100, sim.loyalty + int(round(7.0 - avg_tax)))

	sim.demand_res = clampi(sim.demand_res - int(round((sim.tax_rate_land - 7) * 1.5)) - int(round((sim.tax_rate_military - 7) * 1.2)), -100, 100)
	sim.demand_com = clampi(sim.demand_com - int(round((sim.tax_rate_market - 7) * 2.0)), -100, 100)
	sim.demand_agr = clampi(sim.demand_agr - int(round((sim.tax_rate_land - 7) * 1.5)), -100, 100)

	# [점진적 실학 연구 & 세자 제왕학 서연 엔진]
	if sim and sim.tech_tree:
		var has_lee_deokmu: bool = bool(sim.retainers.get("lee_deokmu", false))
		var acad_power: int = CityStats.get_academic_power()
		if acad_power == 0 and sim.academic > 0:
			acad_power = sim.academic
		var res_tick: Dictionary = sim.tech_tree.process_turn_research(acad_power, sim, has_lee_deokmu)
		if res_tick.get("research_completed", "") != "":
			var comp_id: String = str(res_tick["research_completed"])
			if court:
				court.research[comp_id] = true
				# 영문 ID 대신 한글 연구명을 조회하여 표시
				var comp_name: String = comp_id
				for t_entry: Dictionary in TechTreeManager.TECH_LIST:
					if str(t_entry.get("id", "")) == comp_id:
						comp_name = str(t_entry.get("name", comp_id))
						break
				court.emit_signal("notice", "실학 연구 [%s]이(가) 완수되었습니다!" % comp_name)
		if bool(res_tick.get("prince_completed", false)) and not ModernPoliticsManager.is_post_monarchy():
			if court:
				court.crown_prince["education"] = 100
				court.emit_signal("notice", "경축: 세자께서 제왕학 서연을 완수하셨습니다!")


	await _next_frame()


	# 5단계: 인프라 재연산, 외곽 취락 확장 및 최종 턴 리포트 발행
	grid.recompute_infrastructure(sim.retainers["jeong_yakyong"])
	sim.flood_defense = max(sim.flood_defense, grid.flood_defense)
	# PORT-TRACE [렉: 턴 정산 멈칫]: 인프라 재연산(30ms 남짓)과 외곽 취락 확장(20ms 남짓)을 한 프레임에 몰지 않는다
	await _next_frame()

	if outside:
		outside.grow()
		sim.loyalty += outside.unrest_delta()
		await _next_frame() # 외곽 확장(30ms 남짓)과 신문·턴 보고를 한 프레임에 몰지 않는다

	sim.loyalty = clampi(sim.loyalty, 0, 100)
	sim.authority = clampi(sim.authority, 0, 100)
	sim.emit_signal("state_updated", sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)
	var ev := ""
	if court.milestones["wonhaeng1789"] and year == 1789:
		ev = "wonhaeng1789"
	elif court.milestones["eulmyo1795"] and year == 1795:
		ev = "eulmyo1795"
	latest_article = NewspaperSystem.generate(sim, grid, ev)
	if audio: audio.play("season")
	var season_names := ["봄", "여름", "가을", "겨울"]
	
	var log_desc: String = "성문 물류 완비 (효율 125%)"
	if agri.get("gates_connected", 0) == 0:
		log_desc = "성문 미개통 (운송 지연 손실 55%)"
	elif agri.get("logistics_ratio", 1.0) < 0.5:
		log_desc = "도로 단절 (운송 손실 발생)"
	elif agri.get("logistics_ratio", 1.0) < 0.9:
		log_desc = "물류 부분 개통 (효율 %d%%)" % int(agri.get("logistics_eff", 1.0) * 100.0)

	var maint_g: int = int(sim.last_maintenance_result.get("total_gold", 0)) if sim else 0
	var maint_r: int = int(sim.last_maintenance_result.get("total_rice", 0)) if sim else 0

	# 석 달 치 결산 누적 — 이번 턴이 새 계절의 첫 달이면 끝난 계절 결산을 함께 싣는다
	_season_acc["tax_income"] = int(_season_acc["tax_income"]) + tax_market + tax_land + tax_military + diff_tax_amt
	_season_acc["harvest"] = int(_season_acc["harvest"]) + int(adj["rice"])
	_season_acc["maintenance_gold"] = int(_season_acc["maintenance_gold"]) + maint_g
	_season_acc["maintenance_rice"] = int(_season_acc["maintenance_rice"]) + maint_r
	var month_now: int = sim.month_now() if sim else 1
	var season_end: bool = month_now in [3, 6, 9, 12]
	var ended_si: int = SimulationCore.season_of_month(posmod(month_now - 2, 12) + 1)
	var season_rep: Dictionary = _season_acc.duplicate()
	if season_end:
		_season_acc = {"tax_income": 0, "harvest": 0, "maintenance_gold": 0, "maintenance_rice": 0}

	emit_signal("turn_report", {
		"season_end": season_end, "season_sum": season_rep,
		"ended_season": season_names[ended_si], "ended_year": year,
		"turn": turn, "year": year, "season": season_names[season_index],
		"tax_income": tax_market + tax_land + tax_military + diff_tax_amt,
		"harvest": adj["rice"], "population": sim.population,
		"maintenance_gold": maint_g,
		"maintenance_rice": maint_r,
		"agri_gross": agri.get("gross_yield", 0),
		"agri_net": agri.get("net_income", 0),
		"logistics_ratio": agri.get("logistics_ratio", 0.0),
		"logistics_status": log_desc,
		"dilemma": turn % 3 == 0, "article": latest_article,
	})

	# 2년마다 가을이 끝날 때(12월이 시작될 때) 비변사 한글 시보 발간 — 1790·1792·… 가을호
	# 호수는 Main이 지난 호 수에 이어 매긴다(0 = 다음 호)
	if month_now == 12 and posmod(year - 1790, 2) == 0:
		sim.emit_signal("gazette_published", 0, year, "가을")

	# 지난 턴 끝 → 이번 턴 끝 사이 국고 변화(= 한 달 수지, 김판관 재정 조언용). 불러온 직후 첫 턴은 기준만 잡는다.
	if sim.gold_at_last_budget >= 0:
		sim.last_month_gold_delta = sim.gold - sim.gold_at_last_budget
		# 계절 세수가 석 달에 한 번 몰려 들어오므로 조언은 최근 석 달 합으로 판단한다
		sim.recent_gold_deltas.append(sim.last_month_gold_delta)
		if sim.recent_gold_deltas.size() > 3:
			sim.recent_gold_deltas.pop_front()
	sim.gold_at_last_budget = sim.gold

	# [규약] 현륭원 친림 참배 어명 건의는 길잡이 김판관(TutorialGuide) 단일 창구로 일원화 (중복 팝업 배제)
	_is_processing_turn = false
	if grid:
		grid.emit_signal("grid_changed")

## [PORT-TRACE 다변수 농업 생산 및 성문 물류 세입 산출]
## FarmManager를 통해 수리 농업 인프라 엔진(IrrigationManager) 및 사계절/물류 결합 정산
func calculate_agricultural_production(season_index: int, refresh_irrigation: bool = true) -> Dictionary:
	return FarmManager.calculate_harvest(grid, sim, season_index, refresh_irrigation)
