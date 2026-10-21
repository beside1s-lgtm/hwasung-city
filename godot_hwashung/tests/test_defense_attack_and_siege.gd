extends SceneTree

const CityStatsClass = preload("res://scripts/CityStats.gd")
const BuildingManagerClass = preload("res://scripts/BuildingManager.gd")
const WaterStructureManagerClass = preload("res://scripts/WaterStructureManager.gd")
const DisasterManagerClass = preload("res://scripts/DisasterManager.gd")
const GameGridClass = preload("res://scripts/GameGrid.gd")
const SimulationCoreClass = preload("res://scripts/SimulationCore.gd")
const WorldMarkerManagerClass = preload("res://scripts/WorldMarkerManager.gd")
const SaveSystemClass = preload("res://scripts/SaveSystem.gd")

func _init() -> void:
	print("=== [테스트 시작] 성 방호력·군사 공격력 수치 연동, 수문 현판 하사, 서장대 야조 및 공방전 시스템 검증 ===")
	call_deferred("_run_tests")

func _create_test_grid() -> GameGridClass:
	var g := GameGridClass.new()
	g.size = 64
	g.grid = []
	for y in range(64):
		var row: Array = []
		for x in range(64):
			row.append({
				"terrain": "plain",
				"surface": "grass",
				"building": "",
				"zone": "",
				"elevation": 0.0,
				"road_type": "dirt"
			})
		g.grid.append(row)
	return g

func _run_tests() -> void:
	_test_defense_power_addition_rules()
	_test_attack_power_addition_rules()
	_test_water_structure_signboard_bestowal()
	_test_seojangdae_annual_drill_system()
	_test_siege_defense_combat_loop()
	_test_save_load_auto_heal_integrity()

	print("=== [테스트 완료] 성 방호력·공격력·수문현판·야조훈련·공방전 6대 전 항목 100% 통과! ===")
	quit(0)

## 1. 방어 시설별 성 방호력(체력/내구도) 합산 규칙 검증
func _test_defense_power_addition_rules() -> void:
	print("[검증 1] 방어 시설별 성 방호력 합산 공식 검증...")
	CityStatsClass.reset_to_defaults()
	assert(CityStatsClass.get_fortress_defense_power() == 0, "초기 방호력은 0이어야 함")

	var grid := _create_test_grid()
	var sim := SimulationCoreClass.new()

	# 성곽 완공도 100% -> 방호력 +50
	grid.fortress_progress = 100
	CityStatsClass.recalculate_defense_and_attack(grid, sim)
	var p50: int = CityStatsClass.get_fortress_defense_power()
	assert(p50 == 50, "성곽 100%% 완공 시 방호력 50점이어야 함 (실제: %d)" % p50)

	# 사대문 1개소 추가 -> +15 (총 65)
	grid.grid[10][10]["building"] = "gate"
	grid.grid[10][10]["site_anchor"] = Vector2i(10, 10)
	CityStatsClass.recalculate_defense_and_attack(grid, sim)
	var p65: int = CityStatsClass.get_fortress_defense_power()
	assert(p65 == 65, "성문 1개소 추가 시 방호력 65여야 함 (실제: %d)" % p65)

	# 수문 2개소 (화홍문, 남수문) 추가 -> 각각 +10 (총 +20 -> 85)
	grid.grid[5][10]["building"] = "wall"
	grid.grid[5][10]["is_hwahong"] = true
	grid.grid[20][10]["building"] = "wall"
	grid.grid[20][10]["is_namsu"] = true
	CityStatsClass.recalculate_defense_and_attack(grid, sim)
	var p85: int = CityStatsClass.get_fortress_defense_power()
	assert(p85 == 85, "수문 2개소 추가 시 방호력 85여야 함 (실제: %d)" % p85)

	# 포루 1개소(+8) 및 공심돈 1개소(+8) 추가 -> +16 (총 101)
	grid.grid[8][8]["building"] = "poru"
	grid.grid[8][8]["site_anchor"] = Vector2i(8, 8)
	grid.grid[12][12]["building"] = "gongsimdon"
	grid.grid[12][12]["site_anchor"] = Vector2i(12, 12)
	CityStatsClass.recalculate_defense_and_attack(grid, sim)
	var p101: int = CityStatsClass.get_fortress_defense_power()
	assert(p101 == 101, "포루/공심돈 추가 시 방호력 101이어야 함 (실제: %d)" % p101)

	# 치성 1개소(+3) 및 암문 1개소(+3) 추가 -> +6 (총 107)
	grid.grid[6][6]["building"] = "chiseong"
	grid.grid[6][6]["site_anchor"] = Vector2i(6, 6)
	grid.grid[7][7]["building"] = "ammun"
	grid.grid[7][7]["site_anchor"] = Vector2i(7, 7)
	CityStatsClass.recalculate_defense_and_attack(grid, sim)
	var p107: int = CityStatsClass.get_fortress_defense_power()
	assert(p107 == 107, "치성/암문 추가 시 방호력 107이어야 함 (실제: %d)" % p107)

	print("  - [PASS] 방어 시설별 방호력 누적 합산 규칙 검증 성공 (최종 방호력: %d)" % p107)

## 2. 군사 지휘·치안 시설별 군사 공격력(격퇴력) 합산 규칙 검증
func _test_attack_power_addition_rules() -> void:
	print("[검증 2] 군사 지휘·치안 시설별 군사 공격력 합산 공식 검증...")
	CityStatsClass.reset_to_defaults()
	assert(CityStatsClass.get_military_attack_power() == 0, "초기 공격력은 0이어야 함")

	var grid := _create_test_grid()
	var sim := SimulationCoreClass.new()

	# 행궁 미완공 상태 -> 공격력 0
	CityStatsClass.recalculate_defense_and_attack(grid, sim)
	assert(CityStatsClass.get_military_attack_power() == 0, "행궁 미완공 시 공격력 0이어야 함")

	# 화성행궁 완공 -> 기본 공격력 500 부여
	sim.haenggung_completed = true
	grid.grid[30][30]["building"] = "haenggung"
	grid.grid[30][30]["site_anchor"] = Vector2i(30, 30)
	CityStatsClass.recalculate_defense_and_attack(grid, sim)
	var a500: int = CityStatsClass.get_military_attack_power()
	assert(a500 == 500, "행궁 완공 시 장용영 기본 공격력 500 부여되어야 함 (실제: %d)" % a500)

	# 서장대 완공 -> +150 (총 650)
	grid.grid[25][25]["building"] = "seojangdae"
	grid.grid[25][25]["site_anchor"] = Vector2i(25, 25)
	CityStatsClass.recalculate_defense_and_attack(grid, sim)
	var a650: int = CityStatsClass.get_military_attack_power()
	assert(a650 == 650, "서장대 완공 시 공격력 650이어야 함 (실제: %d)" % a650)

	# 순라청 2개소 완공 -> 개소당 +50 -> +100 (총 750)
	grid.grid[15][15]["building"] = "patrol"
	grid.grid[15][15]["site_anchor"] = Vector2i(15, 15)
	grid.grid[16][16]["building"] = "patrol"
	grid.grid[16][16]["site_anchor"] = Vector2i(16, 16)
	CityStatsClass.recalculate_defense_and_attack(grid, sim)
	var a750: int = CityStatsClass.get_military_attack_power()
	assert(a750 == 750, "순라청 2개소 추가 시 공격력 750이어야 함 (실제: %d)" % a750)

	# 연무대(장용영 군영) 1개소 완공 -> +80 (총 830)
	grid.grid[22][22]["building"] = "yeonmudae"
	grid.grid[22][22]["site_anchor"] = Vector2i(22, 22)
	CityStatsClass.recalculate_defense_and_attack(grid, sim)
	var a830: int = CityStatsClass.get_military_attack_power()
	assert(a830 == 830, "연무대 추가 시 공격력 830이어야 함 (실제: %d)" % a830)

	print("  - [PASS] 군사 시설별 공격력 누적 합산 규칙 검증 성공 (최종 공격력: %d)" % a830)

## 3. 수원천 남수문·화홍문 현판 하사 이벤트 및 월드 마커 검증
func _test_water_structure_signboard_bestowal() -> void:
	print("[검증 3] 남수문·화홍문 현판 하사 시그널 및 월드 마커 등록 검증...")
	var grid := _create_test_grid()
	var wm := WorldMarkerManagerClass.new()

	var bestowed_signals: Array[Dictionary] = []
	grid.water_gate_signboard_bestowed.connect(func(fac_id: String, fac_name: String, pos: Vector2i):
		bestowed_signals.append({"id": fac_id, "name": fac_name, "pos": pos})
		wm.register_marker(fac_id, fac_name, Vector2(pos.x * 32, pos.y * 16))
	)

	# 1) 화홍문 (수원천 북쪽 y < size/2) 축조
	var hw_y: int = 10
	var hw_x: int = 20
	grid.grid[hw_y][hw_x]["terrain"] = "water"
	grid.grid[hw_y][hw_x]["building"] = "wall"

	var hw_res: Dictionary = WaterStructureManagerClass.on_wall_cross_river(grid, hw_x, hw_y)
	assert(hw_res.get("facility_id", "") == "hwahong_mun", "화홍문 facility_id 불일치")
	assert(bestowed_signals.size() == 1, "화홍문 축조 시 water_gate_signboard_bestowed 시그널 발생해야 함")
	assert(bestowed_signals[0]["id"] == "hwahong_mun", "시그널 facility_id 불일치")
	assert(wm.get_marker("hwahong_mun") != null, "WorldMarkerManager에 화홍문 현판이 등록되어야 함")
	assert(wm.get_marker("hwahong_mun").gate_name.contains("화홍문"), "현판 명칭에 '화홍문' 포함되어야 함")

	# 2) 남수문 (수원천 남쪽 y >= size/2) 축조
	var ns_y: int = 45
	var ns_x: int = 20
	grid.grid[ns_y][ns_x]["terrain"] = "water"
	grid.grid[ns_y][ns_x]["building"] = "wall"

	var ns_res: Dictionary = WaterStructureManagerClass.on_wall_cross_river(grid, ns_x, ns_y)
	assert(ns_res.get("facility_id", "") == "namsu_mun", "남수문 facility_id 불일치")
	assert(bestowed_signals.size() == 2, "남수문 축조 시 water_gate_signboard_bestowed 시그널 발생해야 함")
	assert(bestowed_signals[1]["id"] == "namsu_mun", "시그널 facility_id 불일치")
	assert(wm.get_marker("namsu_mun") != null, "WorldMarkerManager에 남수문 현판이 등록되어야 함")
	assert(wm.get_marker("namsu_mun").gate_name.contains("남수문"), "현판 명칭에 '남수문' 포함되어야 함")

	wm.clear_all_markers()
	print("  - [PASS] 수문 현판 하사 시그널 및 월드 마커 등록 검증 성공")

## 4. 서장대 연례 군사 훈련 (야조: 夜操) 시스템 검증
func _test_seojangdae_annual_drill_system() -> void:
	print("[검증 4] 서장대 연례 야조 군사 훈련 인터랙션 검증...")
	CityStatsClass.reset_to_defaults()
	var grid := _create_test_grid()
	var sim := SimulationCoreClass.new()

	sim.gold = 5000
	sim.rice = 3000
	sim.authority = 50
	sim.loyalty = 60
	sim.seojangdae_drill_cd_months = 0

	# 1) 서장대 미완공 시 훈련 실패
	var fail_res: Dictionary = sim.execute_seojangdae_drill(grid, null)
	assert(fail_res["success"] == false, "서장대 미완공 시 훈련이 거부되어야 함")

	# 서장대 완공
	grid.grid[15][15]["building"] = "seojangdae"
	grid.grid[15][15]["site_anchor"] = Vector2i(15, 15)
	CityStatsClass.recalculate_defense_and_attack(grid, sim)
	var atk_before: int = CityStatsClass.get_military_attack_power()

	# 2) 정상 훈련 실시
	var succ_res: Dictionary = sim.execute_seojangdae_drill(grid, null)
	assert(succ_res["success"] == true, "서장대 완공 및 자원 충족 시 훈련 성공해야 함: %s" % succ_res.get("msg", ""))
	assert(sim.gold == 3000, "금화 2,000냥 소모 확인 (현재: %d)" % sim.gold)
	assert(sim.rice == 2000, "군량 1,000석 소모 확인 (현재: %d)" % sim.rice)
	assert(sim.authority == 55, "왕권 +5 상승 확인 (현재: %d)" % sim.authority)
	assert(sim.loyalty == 63, "민심 +3 상승 확인 (현재: %d)" % sim.loyalty)
	assert(sim.seojangdae_drill_cd_months == 12, "12개월 쿨다운 부여 확인")
	assert(CityStatsClass.get_seojangdae_drill_bonus() == 50, "야조 훈련 공격력 영구 +50 증가 확인")
	assert(CityStatsClass.get_military_attack_power() == atk_before + 50, "총 공격력 50 증가 확인")

	# 3) 쿨다운 중 중복 훈련 시도 차단
	var cd_res: Dictionary = sim.execute_seojangdae_drill(grid, null)
	assert(cd_res["success"] == false, "쿨다운 중에는 훈련이 거부되어야 함")

	print("  - [PASS] 서장대 연례 야조 훈련 자원 소모, 쿨다운, 영구 공격력 증강 검증 성공")

## 5. 공방전(Siege Defense) 메커니즘 검증 (방어력 버티기 + 공격력 격퇴)
func _test_siege_defense_combat_loop() -> void:
	print("[검증 5] 공방전 (도적 공격력 vs 성 방호력 흡수 & 장용영 반격) 틱 루프 검증...")
	CityStatsClass.reset_to_defaults()
	var sim := SimulationCoreClass.new()
	sim.gold = 1000
	sim.rice = 1000

	# 방호력 100 세팅, 아군 공격력 600 세팅
	CityStatsClass.set_fortress_defense_power(100)
	CityStatsClass.set_military_attack_power(600)

	var dm := DisasterManagerClass.new()
	dm.start_siege_combat(500, 500) # 도적 공격력 500, 체력 500

	# 1라운드 모의 전투 실행
	var round1: Dictionary = DisasterManagerClass.simulate_combat_round(100, 600, 500, 500)
	assert(round1["absorbed"] == true, "성 방호력이 남아있어 도적 공격을 흡수해야 함")
	assert(round1["new_defense"] == 50, "방호력 50 차감되어 50 남아야 함 (실제: %d)" % round1["new_defense"])
	assert(round1["new_bandit_hp"] == 380, "아군 공격력 600에 의해 도적 체력 120 차감되어 380 남아야 함 (실제: %d)" % round1["new_bandit_hp"])

	# 지속 틱 처리: dm.process_combat_tick (1.0초 틱 시뮬레이션)
	var tick1: Dictionary = dm.process_combat_tick(1.0, sim, null)
	assert(tick1["defense_absorbed"] == true, "성 방호력이 피해 흡수 확인")
	assert(sim.gold == 1000 and sim.rice == 1000, "방호력이 흡수하는 동안 민가/국고 약탈 없어야 함")

	# 추가 틱 누적하여 도적 체력 완전 소진 시 격퇴 성공 검증
	for i in range(10):
		if not dm.is_combat_active:
			break
		dm.process_combat_tick(1.0, sim, null)

	assert(dm.is_combat_active == false, "도적 체력 소진으로 전투 종료되어야 함")
	assert(dm.bandit_hp <= 0, "도적 체력 0 이하 소탕 확인")
	assert(sim.bandit_active == false, "도적 침략 해제 확인")

	print("  - [PASS] 공방전 성 방호력 버티기 및 장용영 군사 공격력 격퇴 메커니즘 검증 성공")

## 6. 세이브/로드 호환성 및 Auto-Heal 검증
func _test_save_load_auto_heal_integrity() -> void:
	print("[검증 6] 세이브/로드 호환성 및 Auto-Heal 검증...")
	CityStatsClass.reset_to_defaults()
	CityStatsClass.set_military_attack_power(550)
	CityStatsClass.set_seojangdae_drill_bonus(100)
	CityStatsClass.set_fortress_defense_power(75)

	var s_data: Dictionary = CityStatsClass.serialize()
	assert(s_data["military_attack_power"] == 550, "직렬화 공격력 일치")
	assert(s_data["seojangdae_drill_bonus"] == 100, "직렬화 훈련 보너스 일치")
	assert(s_data["fortress_defense_power"] == 75, "직렬화 방호력 일치")

	# 역직렬화 검증
	CityStatsClass.reset_to_defaults()
	CityStatsClass.deserialize(s_data)
	assert(CityStatsClass.get_military_attack_power() == 550, "역직렬화 공격력 복원 일치")
	assert(CityStatsClass.get_seojangdae_drill_bonus() == 100, "역직렬화 훈련 보너스 복원 일치")
	assert(CityStatsClass.get_fortress_defense_power() == 75, "역직렬화 방호력 복원 일치")

	# 구버전 세이브 (필드 누락) Null-safe Fallback 검증
	var old_data: Dictionary = {}
	CityStatsClass.deserialize(old_data)
	assert(CityStatsClass.get_military_attack_power() == 0, "구버전 누락 시 기본값 0 복원")
	assert(CityStatsClass.get_seojangdae_drill_bonus() == 0, "구버전 누락 시 기본값 0 복원")

	print("  - [PASS] 세이브/로드 역호환 및 Auto-Heal 검증 성공")
