extends SceneTree

func _init() -> void:
	print("=== [검증 시작] 축만제·진휼소 부지 규격 및 공공시설 하위메뉴 탭·기근 민심 검증 ===")
	
	# 1. SITE_BUILDINGS 규격 검증
	var cm_site: Dictionary = GameGrid.SITE_BUILDINGS.get("chukmanje", {})
	assert(cm_site.get("w") == 6 and cm_site.get("h") == 6, "축만제 부지 6x6 불일치")
	assert(cm_site.get("turns") == 8, "축만제 공기 8턴 불일치")
	assert(cm_site["cost_per_turn"]["gold"] == 260 and cm_site["cost_per_turn"]["rice"] == 110, "축만제 턴당 비용 불일치")
	print("  - [PASS] 축만제 6x6 부지, 공기 8턴, 만석거 동일 비용(2,080냥/880석) 검증 성공")

	var jh_site: Dictionary = GameGrid.SITE_BUILDINGS.get("jinhulso", {})
	assert(jh_site.get("w") == 2 and jh_site.get("h") == 2, "진휼소 부지 2x2 불일치")
	assert(jh_site.get("turns") == 2, "진휼소 공기 2턴 불일치")
	assert(jh_site["cost_per_turn"]["gold"] == 2500 and jh_site["cost_per_turn"]["rice"] == 2500, "진휼소 턴당 비용 불일치")
	print("  - [PASS] 진휼소 2x2 부지, 총 비용 5,000냥 / 5,000석 검증 성공")

	# 2. COST_MAP 검증
	assert(GameGrid.COST_MAP["jinhulso"]["gold"] == 5000 and GameGrid.COST_MAP["jinhulso"]["rice"] == 5000, "진휼소 COST_MAP 불일치")
	assert(GameGrid.COST_MAP["chukmanje"]["gold"] == 2080 and GameGrid.COST_MAP["chukmanje"]["rice"] == 880, "축만제 COST_MAP 불일치")
	print("  - [PASS] COST_MAP 축만제 및 진휼소 원가 일치 검증 성공")

	# 3. 하위메뉴 카테고리 구성 검증
	assert(PanelController.PUBLIC_CATEGORIES.has("admin"), "행정시설 탭 누락")
	assert(PanelController.PUBLIC_CATEGORIES.has("military"), "군사시설 탭 누락")
	assert(PanelController.PUBLIC_CATEGORIES.has("agriculture"), "농업시설 탭 누락")
	print("  - [PASS] 공공시설 3대 하위메뉴 탭(행정/군사/농업) 카테고리 분류 검증 성공")

	# 4. 기근 시 진휼소 부재 민심 대폭 하락 검증
	var sim := SimulationCore.new()
	sim.population = 10000
	sim.rice = 0
	sim.loyalty = 80
	# 진휼소 없음
	sim._process_monthly_budget()
	assert(sim.loyalty == 65, "진휼소 부재 시 기근 민심 15 하락 불일치: %d" % sim.loyalty)
	print("  - [PASS] 진휼소 부재 시 기근 상황 민심 대폭 하락(-15) 검증 성공")

	print("=== [검증 완료] 모든 항목 100% 정상 통과! ===")
	quit(0)
