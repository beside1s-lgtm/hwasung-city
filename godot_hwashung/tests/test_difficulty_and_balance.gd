extends SceneTree

const DifficultyManager = preload("res://scripts/DifficultyManager.gd")
const GameGridClass = preload("res://scripts/GameGrid.gd")
const SimulationCoreClass = preload("res://scripts/SimulationCore.gd")
const TimeManagerClass = preload("res://scripts/TimeManager.gd")
const SaveSystemClass = preload("res://scripts/SaveSystem.gd")
const StartGamePopupClass = preload("res://scripts/StartGamePopup.gd")
const CourtSystemClass = preload("res://scripts/CourtSystem.gd")
const PopulationManagerClass = preload("res://scripts/PopulationManager.gd")

func _init() -> void:
	print("=== [테스트 시작] 초기 게임 난이도 및 경제·인구 연동 밸런스 시스템 검증 ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	_test_difficulty_manager_constants()
	_test_easy_difficulty_balance()
	_test_normal_difficulty_balance()
	_test_hard_difficulty_balance()
	_test_gamegrid_zone_caching_and_limits()
	_test_seasonal_maintenance_and_salary()
	_test_start_game_popup_ui()
	_test_save_load_difficulty_integrity()
	_test_salary_and_tax_multipliers()

	print("=== [테스트 완료] 난이도 선택 UI 및 경제·인구 연동 밸런스 9대 전 항목 100% 통과! ===")
	quit(0)

## 1. DifficultyManager 기본 상수 및 이름 검증
func _test_difficulty_manager_constants() -> void:
	print("[검증 1] DifficultyManager 기본 상수 및 API 검증...")
	assert(DifficultyManager.Difficulty.EASY == 0, "EASY enum 값 0 불일치")
	assert(DifficultyManager.Difficulty.NORMAL == 1, "NORMAL enum 값 1 불일치")
	assert(DifficultyManager.Difficulty.HARD == 2, "HARD enum 값 2 불일치")
	
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.EASY)
	assert(DifficultyManager.get_difficulty() == DifficultyManager.Difficulty.EASY, "기본 난이도 설정 실패")
	assert(DifficultyManager.get_difficulty_name().contains("쉬움"), "난이도 한글 명칭 오류")
	print("  - [PASS] 기본 상수 및 명칭 검증 성공")

## 2. 쉬움 (Easy) 난이도 밸런스 검증 (기존 수치 100% 보존)
func _test_easy_difficulty_balance() -> void:
	print("[검증 2] 쉬움(태평성대) 기존 밸런스 100% 역호환 보존 검증...")
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.EASY)
	
	# 기본 비용 배율 1.0
	assert(DifficultyManager.get_cost_multiplier() == 1.0, "쉬움 배율은 1.0이어야 함")
	
	# 박석길 건설비: 기존 비용 (gold 35, rice 5) 보존
	var dirt_cost: Dictionary = {"gold": 20, "rice": 0}
	var stone_cost: Dictionary = DifficultyManager.get_stone_road_cost(dirt_cost)
	assert(stone_cost["gold"] == 35 and stone_cost["rice"] == 5, "쉬움 박석길 비용 불일치: %s" % str(stone_cost))
	
	# 상점 스폰: 민가 수와 무관하게 항상 true
	assert(DifficultyManager.can_spawn_shop(0, 0) == true, "쉬움에서는 민가 0이어도 상점 생성 가능해야 함")
	assert(DifficultyManager.can_spawn_shop(1, 100) == true, "쉬움에서는 상점 수 제한이 없어야 함")
	
	# 둔전 한도: 무제한 (999999)
	assert(DifficultyManager.get_farm_capacity_limit(0) >= 999999, "쉬움 둔전 한도 무제한이어야 함")
	assert(DifficultyManager.get_farm_capacity_limit(1) >= 999999, "쉬움 둔전 한도 무제한이어야 함")
	
	# 구휼미: 인구에 관계없이 500석 고정
	assert(DifficultyManager.get_relief_food_cost(500) == 500, "쉬움 구휼미 500석이어야 함")
	assert(DifficultyManager.get_relief_food_cost(15000) == 500, "쉬움 구휼미 고인구에서도 500석이어야 함")
	assert(DifficultyManager.get_relief_food_cost(30000) == 500, "쉬움 구휼미 500석 고정이어야 함")
	
	# 유지비 및 녹봉 없음 (0.0 / 0), 관리 녹봉 배율 1.0, 세수 배율 1.0
	assert(DifficultyManager.get_public_maintenance_rate() == 0.0, "쉬움 유지비는 0이어야 함")
	assert(DifficultyManager.get_retainer_salary() == 0, "쉬움 녹봉은 0이어야 함")
	assert(is_equal_approx(DifficultyManager.get_retainer_salary_multiplier(), 1.0), "쉬움 관리 녹봉 배율은 1.0이어야 함")
	assert(is_equal_approx(DifficultyManager.get_tax_multiplier(), 1.0), "쉬움 세수 배율은 1.0이어야 함")
	
	# 성벽 노임 없음
	var wall_labor: Dictionary = DifficultyManager.get_wall_labor_cost()
	assert(wall_labor["gold"] == 0 and wall_labor["rice"] == 0, "쉬움 성벽 노임은 0이어야 함")
	
	# 재해 페널티 기본 (20%)
	assert(is_equal_approx(DifficultyManager.get_disaster_penalty("drought"), 0.20), "쉬움 가뭄 페널티 20%")
	assert(is_equal_approx(DifficultyManager.get_disaster_penalty("fire"), 0.20), "쉬움 화재 페널티 20%")
	print("  - [PASS] 쉬움 밸런스 검증 성공")

## 3. 보통 (Normal) 난이도 밸런스 검증 (역사적 고증)
func _test_normal_difficulty_balance() -> void:
	print("[검증 3] 보통(성역의 고난) 역사적 고증 경제·인구 밸런스 검증...")
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.NORMAL)
	
	# 배율 2.0
	assert(DifficultyManager.get_cost_multiplier() == 2.0, "보통 배율은 2.0이어야 함")
	
	# 박석길 건설비 = 흙길(gold 20)의 정확히 3배 (gold 60, rice 0)
	var dirt_cost: Dictionary = {"gold": 20, "rice": 0}
	var stone_cost: Dictionary = DifficultyManager.get_stone_road_cost(dirt_cost)
	assert(stone_cost["gold"] == 60 and stone_cost["rice"] == 0, "보통 박석길 비용은 흙길의 정확히 3배(60냥)이어야 함: %s" % str(stone_cost))
	
	# 상점 스폰 제한: 민가 0이면 차단, 민가 1개소당 최대 2개소
	assert(DifficultyManager.can_spawn_shop(0, 0) == false, "민가 0개소 시 상점 스폰 차단 실패")
	assert(DifficultyManager.can_spawn_shop(1, 0) == true, "민가 1, 상점 0 시 스폰 허용 실패")
	assert(DifficultyManager.can_spawn_shop(1, 1) == true, "민가 1, 상점 1 시 스폰 허용 실패")
	assert(DifficultyManager.can_spawn_shop(1, 2) == false, "민가 1, 상점 2 시 추가 스폰 차단 실패 (한도 2개)")
	assert(DifficultyManager.can_spawn_shop(2, 3) == true, "민가 2, 상점 3 시 스폰 허용 실패 (한도 4개)")
	assert(DifficultyManager.can_spawn_shop(2, 4) == false, "민가 2, 상점 4 시 추가 스폰 차단 실패")
	
	# 둔전 경작 제한: 민가 1개소당 최대 30칸
	assert(DifficultyManager.get_farm_capacity_limit(0) == 0, "민가 0 시 경작 한도 0이어야 함")
	assert(DifficultyManager.get_farm_capacity_limit(1) == 30, "민가 1 시 경작 한도 30칸이어야 함")
	assert(DifficultyManager.get_farm_capacity_limit(3) == 90, "민가 3 시 경작 한도 90칸이어야 함")
	
	# 인구 비례 구휼미 증액: 500 * max(1, 10^(floor(pop / 10000)))
	assert(DifficultyManager.get_relief_food_cost(100) == 500, "인구 100명: 500석")
	assert(DifficultyManager.get_relief_food_cost(9999) == 500, "인구 9,999명: 500석")
	assert(DifficultyManager.get_relief_food_cost(10000) == 5000, "인구 10,000명: 5,000석 (10배)")
	assert(DifficultyManager.get_relief_food_cost(19999) == 5000, "인구 19,999명: 5,000석")
	assert(DifficultyManager.get_relief_food_cost(20000) == 50000, "인구 20,000명: 50,000석 (100배)")
	
	# 공공기관 유지비 20%, 인재 계절 녹봉 200냥, 관리 녹봉 2배, 세수 30% 감액(0.70x)
	assert(is_equal_approx(DifficultyManager.get_public_maintenance_rate(), 0.20), "공공기관 계절 유지비 20%이어야 함")
	assert(DifficultyManager.get_retainer_salary() == 200, "인재 계절 녹봉 200냥이어야 함")
	assert(is_equal_approx(DifficultyManager.get_retainer_salary_multiplier(), 2.0), "보통 관리 녹봉 쉬움의 2배이어야 함")
	assert(is_equal_approx(DifficultyManager.get_tax_multiplier(), 0.70), "보통 세수 배율 0.70(30% 감액)이어야 함")
	
	# 성벽 1칸 축조 시 추가 노임: 금화 50냥, 식량 20석
	var wall_labor: Dictionary = DifficultyManager.get_wall_labor_cost()
	assert(wall_labor["gold"] == 50 and wall_labor["rice"] == 20, "보통 성벽 추가 노임 금 50, 곡 20 불일치: %s" % str(wall_labor))
	
	# 재해 생산 급감: 가뭄/홍수 70%, 화재 80%
	assert(is_equal_approx(DifficultyManager.get_disaster_penalty("drought"), 0.70), "보통 가뭄/홍수 70% 감소")
	assert(is_equal_approx(DifficultyManager.get_disaster_penalty("flood"), 0.70), "보통 홍수 70% 감소")
	assert(is_equal_approx(DifficultyManager.get_disaster_penalty("fire"), 0.80), "보통 화재 세수 80% 감소")
	print("  - [PASS] 보통 밸런스 검증 성공")

## 4. 어려움 (Hard) 난이도 밸런스 검증 (보통 대비 10% 추가 할증)
func _test_hard_difficulty_balance() -> void:
	print("[검증 4] 어려움(위기의 조선) 보통 대비 10% 추가 할증 밸런스 검증...")
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.HARD)
	
	# 기본 비용 배율 3.0
	assert(is_equal_approx(DifficultyManager.get_cost_multiplier(), 3.0), "어려움 배율 3.0x 불일치")
	
	# 박석길 건설비 = 흙길(20냥)의 3.3배 = 66냥
	var dirt_cost: Dictionary = {"gold": 20, "rice": 0}
	var stone_cost: Dictionary = DifficultyManager.get_stone_road_cost(dirt_cost)
	assert(stone_cost["gold"] == 66 and stone_cost["rice"] == 0, "어려움 박석길 비용 66냥(3.3배) 불일치: %s" % str(stone_cost))
	
	# 성벽 축성 노임: 금화 55냥, 식량 22석 (50*1.1, 20*1.1)
	var wall_labor: Dictionary = DifficultyManager.get_wall_labor_cost()
	assert(wall_labor["gold"] == 55 and wall_labor["rice"] == 22, "어려움 성벽 노임 금 55, 곡 22 불일치: %s" % str(wall_labor))
	
	# 구휼미: 보통 요구량 * 1.1 (550석, 5,500석, 55,000석)
	assert(DifficultyManager.get_relief_food_cost(5000) == 550, "어려움 인구 5천 구휼미 550석 불일치: %d" % DifficultyManager.get_relief_food_cost(5000))
	assert(DifficultyManager.get_relief_food_cost(10000) == 5500, "어려움 인구 1만 구휼미 5,500석 불일치: %d" % DifficultyManager.get_relief_food_cost(10000))
	assert(DifficultyManager.get_relief_food_cost(20000) == 55000, "어려움 인구 2만 구휼미 55,000석 불일치: %d" % DifficultyManager.get_relief_food_cost(20000))
	
	# 공공기관 계절 유지비 22%, 인재 계절 녹봉 300냥, 관리 녹봉 3배, 세수 40% 감액(0.60x)
	assert(is_equal_approx(DifficultyManager.get_public_maintenance_rate(), 0.22), "어려움 유지비 22% 불일치")
	assert(DifficultyManager.get_retainer_salary() == 300, "어려움 녹봉 300냥 불일치")
	assert(is_equal_approx(DifficultyManager.get_retainer_salary_multiplier(), 3.0), "어려움 관리 녹봉 쉬움의 3배이어야 함")
	assert(is_equal_approx(DifficultyManager.get_tax_multiplier(), 0.60), "어려움 세수 배율 0.60(40% 감액)이어야 함")
	
	# 재해 페널티: 가뭄/홍수 80%, 화재 90%
	assert(is_equal_approx(DifficultyManager.get_disaster_penalty("drought"), 0.80), "어려움 가뭄 식량 -80%")
	assert(is_equal_approx(DifficultyManager.get_disaster_penalty("fire"), 0.90), "어려움 화재 세수 -90%")
	print("  - [PASS] 어려움 밸런스 검증 성공")

## 5. GameGrid O(1) 캐싱 및 develop_and_harvest 연동 검증
func _test_gamegrid_zone_caching_and_limits() -> void:
	print("[검증 5] GameGrid O(1) 캐싱 및 건축/수확 한도 검증...")
	var grid: GameGrid = GameGridClass.new()
	root.add_child(grid)
	
	grid.recount_zone_counts()
	var init_houses: int = grid.houses_count
	var init_shops: int = grid.shops_count
	var init_farms: int = grid.farms_count
	
	# O(1) 카운팅 델타 테스트
	grid._update_zone_count_delta("", "res_1")
	assert(grid.houses_count == init_houses + 1, "houses_count 증가 실패")
	grid._update_zone_count_delta("res_1", "")
	assert(grid.houses_count == init_houses, "houses_count 감소 실패")
	
	grid._update_zone_count_delta("", "com_1")
	assert(grid.shops_count == init_shops + 1, "shops_count 증가 실패")
	grid._update_zone_count_delta("com_1", "")
	assert(grid.shops_count == init_shops, "shops_count 감소 실패")
	
	grid._update_zone_count_delta("", "agr_1")
	assert(grid.farms_count == init_farms + 1, "farms_count 증가 실패")
	grid._update_zone_count_delta("agr_1", "")
	assert(grid.farms_count == init_farms, "farms_count 감소 실패")
	
	# get_tool_cost 난이도별 반환값 검증
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.NORMAL)
	var stone_c: Dictionary = grid.get_tool_cost("stone_road", 10, 10)
	assert(stone_c["gold"] == 60 and stone_c["rice"] == 0, "GameGrid 보통 박석길 비용 60냥 불일치: %s" % str(stone_c))
	
	var wall_c: Dictionary = grid.get_tool_cost("wall", 10, 10)
	assert(wall_c["gold"] == 2000 and wall_c["rice"] == 1000, "GameGrid 보통 성벽 비용(2,000/1,000) 불일치: %s" % str(wall_c))
	
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.HARD)
	var wall_hard_c: Dictionary = grid.get_tool_cost("wall", 10, 10)
	assert(wall_hard_c["gold"] == 3000 and wall_hard_c["rice"] == 1500, "GameGrid 어려움 성벽 비용(3,000/1,500) 불일치: %s" % str(wall_hard_c))
	
	grid.queue_free()
	print("  - [PASS] GameGrid O(1) 캐싱 및 비용 연동 검증 성공")

## 6. SimulationCore 공공기관 계절 유지비 & 인재 녹봉 정산 검증
func _test_seasonal_maintenance_and_salary() -> void:
	print("[검증 6] SimulationCore 공공기관 유지비 및 인재 녹봉 분기 일괄 정산 검증...")
	var sim: SimulationCore = SimulationCoreClass.new()
	var grid: GameGrid = GameGridClass.new()
	root.add_child(sim)
	root.add_child(grid)
	
	# 쉬움 난이도: 유지비 및 녹봉 0원
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.EASY)
	sim.gold = 5000
	sim.retainers["jeong_yakyong"] = true
	var res_easy: Dictionary = sim.process_seasonal_maintenance(grid)
	assert(res_easy["total"] == 0, "쉬움에서는 유지비와 녹봉이 0이어야 함: %s" % str(res_easy))
	assert(sim.gold == 5000, "쉬움 국고 차감 없어야 함")
	
	# 보통 난이도: 인재 2명 (200 * 2 = 400냥) + 행궁 1개소(기본비용 500냥 * 20% = 100냥)
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.NORMAL)
	sim.retainers["chae_jegong"] = true # 총 2명
	grid.grid[20][20]["building"] = "haenggung" # 공공기관 타일 1개 배치
	
	var res_norm: Dictionary = sim.process_seasonal_maintenance(grid)
	assert(res_norm["success"] == true, "보통 정산 성공 플래그 실패")
	assert(res_norm["retainer_salaries"] == 400, "보통 인재 2명 녹봉 400냥 불일치: %d" % res_norm["retainer_salaries"])
	assert(res_norm["facility_maintenance"] >= 100, "보통 행궁 유지비 100냥 이상이어야 함: %d" % res_norm["facility_maintenance"])
	assert(sim.gold == 5000 - res_norm["total"], "국고 차감액 불일치")
	
	# 국고 부족 디버프 테스트
	sim.gold = 10 # 정산액보다 턱없이 부족
	var res_deficit: Dictionary = sim.process_seasonal_maintenance(grid)
	assert(res_deficit["success"] == false, "국고 부족 시 실패 플래그여야 함")
	assert(res_deficit["deficit"] == true, "결손 플래그 true여야 함")
	assert(sim.gold == 0, "국고 부족 시 금화는 0이 되어야 함")
	assert(sim.loyalty < 88, "국고 부족 시 민심 디버프 적용되어야 함")
	
	sim.queue_free()
	grid.queue_free()
	print("  - [PASS] 공공기관 계절 유지비 & 녹봉 정산 검증 성공")

## 7. StartGamePopup UI 컴포넌트 생성 및 모달 바인딩 검증
func _test_start_game_popup_ui() -> void:
	print("[검증 7] StartGamePopup UI 생성 및 난이도 선택 이벤트 검증...")
	var popup: CanvasLayer = StartGamePopupClass.new() as CanvasLayer
	root.add_child(popup)
	
	assert(popup.root_control != null, "StartGamePopup root_control 생성 실패")
	assert(popup.modal_panel != null, "StartGamePopup modal_panel 생성 실패")
	
	var chosen_diff: Array[int] = [-1]
	popup.difficulty_selected.connect(func(d: int): chosen_diff[0] = d)
	
	# 어려움 선택 시뮬레이션
	popup._on_difficulty_chosen(DifficultyManager.Difficulty.HARD)
	assert(chosen_diff[0] == DifficultyManager.Difficulty.HARD, "difficulty_selected 시그널 전달 실패")
	assert(DifficultyManager.get_difficulty() == DifficultyManager.Difficulty.HARD, "DifficultyManager 난이도 변경 실패")
	
	popup.queue_free()
	print("  - [PASS] StartGamePopup 모달 UI 및 시그널 바인딩 검증 성공")

## 8. SaveSystem 세이브/로드 시 난이도 영구 보존 및 역호환 검증
func _test_save_load_difficulty_integrity() -> void:
	print("[검증 8] SaveSystem 난이도 영구 저장/복원 및 역호환성 검증...")
	var sim: SimulationCore = SimulationCoreClass.new()
	var grid: GameGrid = GameGridClass.new()
	var tm: TimeManager = TimeManagerClass.new()
	root.add_child(sim)
	root.add_child(grid)
	root.add_child(tm)
	
	# 보통 난이도로 세이브
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.NORMAL)
	var save_ok: bool = SaveSystem.save_game(98, sim, grid)
	assert(save_ok == true, "슬롯 98 저장 실패")
	
	# 난이도 변경 후 로드로 복원 테스트
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.EASY)
	assert(DifficultyManager.get_difficulty() == DifficultyManager.Difficulty.EASY, "임시 변경 실패")
	
	var load_ok: bool = SaveSystem.load_game(98, sim, grid, tm)
	assert(load_ok == true, "슬롯 98 로드 실패")
	assert(DifficultyManager.get_difficulty() == DifficultyManager.Difficulty.NORMAL, "세이브 로드 후 보통 난이도 복원 실패: %d" % DifficultyManager.get_difficulty())
	
	# 레거시 세이브 데이터 역호환 테스트 (difficulty_level 필드 누락 시 EASY 복원)
	var legacy_data: Dictionary = {
		"slot": 97, "year": 1789, "turn": 1, "pop": 120, "gold": 2500, "rice": 1600
	}
	var f := FileAccess.open(SaveSystem.get_slot_path(97), FileAccess.WRITE)
	f.store_string(JSON.stringify(legacy_data))
	f.close()
	
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.HARD)
	SaveSystem.load_game(97, sim, grid, tm)
	assert(DifficultyManager.get_difficulty() == DifficultyManager.Difficulty.EASY, "레거시 세이브 로드 시 기본값 EASY(0) 복원 실패: %d" % DifficultyManager.get_difficulty())
	
	# 임시 파일 정리
	SaveSystem.delete_save(98)
	SaveSystem.delete_save(97)
	
	sim.queue_free()
	grid.queue_free()
	tm.queue_free()
	print("  - [PASS] 세이브/로드 난이도 영구 보존 및 역호환성 검증 성공")

## 9. 난이도별 관리 녹봉 2배/3배 및 세수 30%/40% 감액 공식 검증
func _test_salary_and_tax_multipliers() -> void:
	print("[검증 9] 난이도별 관리 녹봉(보통 2배, 어려움 3배) 및 세수 감액(보통 -30%, 어려움 -40%) 검증...")
	var court: CourtSystem = CourtSystemClass.new()
	var sim: SimulationCore = SimulationCoreClass.new()
	court.sim = sim
	var pop_mgr: PopulationManager = PopulationManagerClass.new(10000)

	# 1. 쉬움 난이도: 관리 녹봉 1.0x, 세수 1.0x
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.EASY)
	assert(court.get_scholar_salary("jeong") == 500, "쉬움 정약용 녹봉 500냥 불일치: %d" % court.get_scholar_salary("jeong"))
	assert(CourtSystem.calculate_scholar_salary(300) == 300, "쉬움 300냥 녹봉 불일치")
	assert(pop_mgr.calculate_seasonal_tax(10000) == 1500, "쉬움 계절 세수 1,500냥 불일치: %d" % pop_mgr.calculate_seasonal_tax(10000))

	# 2. 보통 난이도: 관리 녹봉 쉬움의 2배(2.0x), 세수 30% 감액(0.70x)
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.NORMAL)
	assert(court.get_scholar_salary("jeong") == 1000, "보통 정약용 녹봉 1,000냥(2배) 불일치: %d" % court.get_scholar_salary("jeong"))
	assert(CourtSystem.calculate_scholar_salary(300) == 600, "보통 300냥 녹봉 2배(600) 불일치")
	assert(pop_mgr.calculate_seasonal_tax(10000) == 1050, "보통 계절 세수 1,050냥(1500 * 0.70) 불일치: %d" % pop_mgr.calculate_seasonal_tax(10000))

	# 3. 어려움 난이도: 관리 녹봉 쉬움의 3배(3.0x), 세수 40% 감액(0.60x)
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.HARD)
	assert(court.get_scholar_salary("jeong") == 1500, "어려움 정약용 녹봉 1,500냥(3배) 불일치: %d" % court.get_scholar_salary("jeong"))
	assert(CourtSystem.calculate_scholar_salary(300) == 900, "어려움 300냥 녹봉 3배(900) 불일치")
	assert(pop_mgr.calculate_seasonal_tax(10000) == 900, "어려움 계절 세수 900냥(1500 * 0.60) 불일치: %d" % pop_mgr.calculate_seasonal_tax(10000))

	# 쉬움으로 복원
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.EASY)
	court.queue_free()
	sim.queue_free()
	print("  - [PASS] 난이도별 관리 녹봉(2배/3배) 및 세수 감액(30%/40%) 검증 성공")

