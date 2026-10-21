extends RefCounted
class_name PopulationManager

## [정조의 화성 신도시 인구 유입책, 가옥-인구 동적 수용량, 폐허 순환 및 복지·세제 정책 매니저]
## Single Source of Truth: 화성 신도시 인구 역학(Population Dynamics) 전담 엔진

# 1. 세율 정책 (Tax Policy)
enum TaxPolicy {
	EXEMPT = 0,   # 감면책 (정조의 이주 장려책): 민심 +15, 계절 인구 증가율 +2.0%p, 세수 계수 0.5배
	STANDARD = 1, # 표준세 (일반 균역/호포): 민심 0, 계절 인구 증가율 0.0%p, 세수 계수 1.0배
	HARSH = 2     # 가혹세 (가혹한 징세): 민심 -25, 계절 인구 증가율 -2.5%p, 세수 계수 1.5배
}

# 2. 인구 및 수용량 상수
const HAENGGUNG_BASE_CAPACITY: int = 6000      # 화성행궁 완공 시 자체 기본 주거 수용량
const HAENGGUNG_BOOST_POPULATION: int = 6000   # 화성행궁 완공 즉시 유입 인구
const HOUSE_CAPACITY: int = 100               # 정상 가옥(초가집/기와집) 1채당 최대 수용 인구

# 3. 5대 복지·수리 시설 효과 상수
# 1) 만석거: 민심 +5, 인구 증가율 +0.8%p
const WELFARE_MANSEOK_LOYALTY: int = 5
const WELFARE_MANSEOK_RATE: float = 0.008

# 2) 축만제: 민심 +5, 인구 증가율 +0.8%p
const WELFARE_CHUKMAN_LOYALTY: int = 5
const WELFARE_CHUKMAN_RATE: float = 0.008

# 3) 순라청: 민심 +4, 인구 증가율 +0.6%p
const WELFARE_PATROL_LOYALTY: int = 4
const WELFARE_PATROL_RATE: float = 0.006

# 4) 멸화군 관사: 민심 +4, 인구 증가율 +0.6%p
const WELFARE_FIREFIGHTER_LOYALTY: int = 4
const WELFARE_FIREFIGHTER_RATE: float = 0.006

# 5) 진휼소: 민심 +6, 인구 증가율 +1.0%p
const WELFARE_JINHULSO_LOYALTY: int = 6
const WELFARE_JINHULSO_RATE: float = 0.010

# 4. 상태 변수
var total_population: int = 120
var current_tax_policy: TaxPolicy = TaxPolicy.STANDARD
var haenggung_completed: bool = false
var haenggung_boost_applied: bool = false

# 5. O(1) 가옥 캐싱 리스트
var active_houses_list: Array[Vector2i] = []
var ruined_houses_list: Array[Vector2i] = []

# 시그널
signal population_changed(new_pop: int, delta: int)
signal housing_occupancy_updated(active_count: int, ruined_count: int, total_capacity: int)
signal tax_policy_changed(new_policy: TaxPolicy)
signal haenggung_boost_triggered(added_pop: int, new_total: int)

func _init(initial_pop: int = 120) -> void:
	total_population = maxi(0, initial_pop)
	current_tax_policy = TaxPolicy.STANDARD
	haenggung_completed = false
	haenggung_boost_applied = false
	active_houses_list.clear()
	ruined_houses_list.clear()

# ==================== 세율 정책 API ====================

func set_tax_policy(policy: TaxPolicy) -> void:
	if current_tax_policy != policy:
		current_tax_policy = policy
		tax_policy_changed.emit(current_tax_policy)

func get_tax_policy() -> TaxPolicy:
	return current_tax_policy

func get_tax_policy_name() -> String:
	match current_tax_policy:
		TaxPolicy.EXEMPT: return "감면책 (정조의 이주 장려)"
		TaxPolicy.STANDARD: return "표준세 (일반 균역/호포)"
		TaxPolicy.HARSH: return "가혹세 (가혹한 징세)"
		_: return "표준세"

func get_tax_policy_loyalty_effect() -> int:
	match current_tax_policy:
		TaxPolicy.EXEMPT: return 15
		TaxPolicy.STANDARD: return 0
		TaxPolicy.HARSH: return -25
		_: return 0

func get_tax_policy_growth_rate_effect() -> float:
	match current_tax_policy:
		TaxPolicy.EXEMPT: return 0.020    # +2.0%p
		TaxPolicy.STANDARD: return 0.000  # +0.0%p
		TaxPolicy.HARSH: return -0.025   # -2.5%p
		_: return 0.0

func get_tax_rate_multiplier() -> float:
	match current_tax_policy:
		TaxPolicy.EXEMPT: return 0.5
		TaxPolicy.STANDARD: return 1.0
		TaxPolicy.HARSH: return 1.5
		_: return 1.0

# ==================== 5대 복지·수리 시설 연동 ====================

## 그리드 또는 시뮬레이션 상태에서 5대 복지 시설 보유 현황 평가
func evaluate_welfare_facilities(grid_ref = null, sim_ref = null) -> Dictionary:
	var result: Dictionary = {
		"manseokgeo": false,
		"chukmanje": false,
		"patrol": false,
		"firefighter": false,
		"jinhulso": false
	}
	
	if sim_ref != null and "mega_projects" in sim_ref:
		for p: Dictionary in sim_ref.mega_projects:
			if p.get("id", "") == "manseok_reservoir" and bool(p.get("is_completed", false)):
				result["manseokgeo"] = true
				break
	
	if grid_ref != null and "grid" in grid_ref:
		var g_size: int = int(grid_ref.size)
		for y: int in range(g_size):
			for x: int in range(g_size):
				var cell: Dictionary = grid_ref.grid[y][x]
				var b: String = str(cell.get("building", ""))
				if b in ["manseokgeo", "manseokgeo_site"]:
					result["manseokgeo"] = true
				elif b == "chukmanje":
					result["chukmanje"] = true
				elif b == "patrol":
					result["patrol"] = true
				elif b == "firefighter":
					result["firefighter"] = true
				elif b == "jinhulso":
					result["jinhulso"] = true
	
	return result

## 5대 복지 시설의 총 민심 가산치 및 인구 증가율 가산치 계산
func get_welfare_effects(welfare_status: Dictionary) -> Dictionary:
	var loyalty_bonus: int = 0
	var rate_bonus: float = 0.0
	
	if bool(welfare_status.get("manseokgeo", false)):
		loyalty_bonus += WELFARE_MANSEOK_LOYALTY
		rate_bonus += WELFARE_MANSEOK_RATE
	if bool(welfare_status.get("chukmanje", false)):
		loyalty_bonus += WELFARE_CHUKMAN_LOYALTY
		rate_bonus += WELFARE_CHUKMAN_RATE
	if bool(welfare_status.get("patrol", false)):
		loyalty_bonus += WELFARE_PATROL_LOYALTY
		rate_bonus += WELFARE_PATROL_RATE
	if bool(welfare_status.get("firefighter", false)):
		loyalty_bonus += WELFARE_FIREFIGHTER_LOYALTY
		rate_bonus += WELFARE_FIREFIGHTER_RATE
	if bool(welfare_status.get("jinhulso", false)):
		loyalty_bonus += WELFARE_JINHULSO_LOYALTY
		rate_bonus += WELFARE_JINHULSO_RATE
		
	return {
		"loyalty_bonus": loyalty_bonus,
		"growth_rate_bonus": rate_bonus
	}

# ==================== 계절 인구 증가율 & 세수 공식 ====================

## 계절별 인구 증가율 산출 (0.0% ~ 5.0% clampf, 가혹세/민심 파탄 시 역성장 허용)
## 공식: 기본(1.0%) + 세금 효과 + sum(복지시설 효과) + ((민심 - 50) / 50) * 1.0%
func calculate_seasonal_growth_rate(loyalty: int, welfare_status: Dictionary) -> float:
	var base_rate: float = 0.010 # 기본 증가율 1.0%
	var tax_rate_effect: float = get_tax_policy_growth_rate_effect()
	var welfare_effects: Dictionary = get_welfare_effects(welfare_status)
	var welfare_rate_bonus: float = float(welfare_effects.get("growth_rate_bonus", 0.0))
	
	# 민심 연동 증가율: ((민심 - 50) / 50) * 1.0%
	var loyalty_effect: float = (float(loyalty - 50) / 50.0) * 0.010
	
	var raw_rate: float = base_rate + tax_rate_effect + welfare_rate_bonus + loyalty_effect
	
	# 가혹세이거나 극단적 민심 파탄(민심 20 미만)인 경우 역성장(인구 순감소) 허용
	if current_tax_policy == TaxPolicy.HARSH or loyalty < 20:
		# 하한을 -5.0% (-0.05), 상한을 +5.0% (0.05)로 제한
		return clampf(raw_rate, -0.050, 0.050)
	else:
		# 일반 상황에서는 최소 0.0% ~ 최대 5.0% 엄격 통제
		return clampf(raw_rate, 0.0, 0.050)

## 계절 정산 시 인구 비례 세수 공식
## 계절 세수 = floor(현재 인구 * 0.15 * 세율 계수 * 난이도 세수 계수) 냥
func calculate_seasonal_tax(pop: int = -1) -> int:
	var target_pop: int = total_population if pop < 0 else pop
	var tax_multiplier: float = get_tax_rate_multiplier()
	var diff_tax_mult: float = DifficultyManager.get_tax_multiplier()
	return int(floor(float(target_pop) * 0.15 * tax_multiplier * diff_tax_mult))

# ==================== 화성행궁 완공 부스팅 ====================

## 화성행궁 완공 시 1회 발화되는 인구 6,000명 즉시 유입 및 기본 수용량 인정
func on_haenggung_completed() -> Dictionary:
	haenggung_completed = true
	if not haenggung_boost_applied:
		haenggung_boost_applied = true
		total_population += HAENGGUNG_BOOST_POPULATION
		haenggung_boost_triggered.emit(HAENGGUNG_BOOST_POPULATION, total_population)
		population_changed.emit(total_population, HAENGGUNG_BOOST_POPULATION)
		return {
			"applied": true,
			"added_pop": HAENGGUNG_BOOST_POPULATION,
			"total_pop": total_population,
			"msg": "화성행궁 완공으로 장용영 외영 군사와 가족, 행정 관료 6,000명이 화성 신도시로 즉각 입주하였습니다!"
		}
	return {
		"applied": false,
		"added_pop": 0,
		"total_pop": total_population,
		"msg": "이미 행궁 입주가 완료되었습니다."
	}

# ==================== 가옥 수용량 및 [정상 가옥 ↔ 폐허] 라이프사이클 ====================

## 총 주거 수용 한계치 (Capacity) = 6000(행궁 완공 시) + (활성 가옥 수 * 100)
func get_total_housing_capacity() -> int:
	var base_cap: int = HAENGGUNG_BASE_CAPACITY if haenggung_completed else 0
	return base_cap + (active_houses_list.size() * HOUSE_CAPACITY)

## 가옥 등록 (새로 건설 시)
func register_house_tile(pos: Vector2i, is_ruined: bool = false) -> void:
	if is_ruined:
		if not (pos in ruined_houses_list):
			ruined_houses_list.append(pos)
		if pos in active_houses_list:
			active_houses_list.erase(pos)
	else:
		if not (pos in active_houses_list):
			active_houses_list.append(pos)
		if pos in ruined_houses_list:
			ruined_houses_list.erase(pos)

## 가옥 제거 (철거 시)
func unregister_house_tile(pos: Vector2i) -> void:
	if pos in active_houses_list:
		active_houses_list.erase(pos)
	if pos in ruined_houses_list:
		ruined_houses_list.erase(pos)

## 전체 그리드 순회 후 O(1) 캐싱 리스트 동기화 (초기 로드/세이브 로드 시 1회 호출)
func sync_housing_lists_from_grid(grid_ref) -> void:
	active_houses_list.clear()
	ruined_houses_list.clear()
	if grid_ref == null or not ("grid" in grid_ref):
		return
		
	var g_size: int = int(grid_ref.size)
	for y: int in range(g_size):
		for x: int in range(g_size):
			var cell: Dictionary = grid_ref.grid[y][x]
			var b: String = str(cell.get("building", ""))
			if b.begins_with("res"):
				var pos := Vector2i(x, y)
				if bool(cell.get("is_ruined", false)):
					ruined_houses_list.append(pos)
				else:
					active_houses_list.append(pos)

## 계절 정산 시 인구 대비 가옥 수용량 일괄 검사 및 [정상 가옥 ↔ 폐허] 배칭 업데이트
## 비파괴적 전환: 타일 삭제 없이 is_ruined 플래그만 변경
func update_housing_occupancy(grid_ref) -> Dictionary:
	var base_cap: int = HAENGGUNG_BASE_CAPACITY if haenggung_completed else 0
	var needed_house_pop: int = maxi(0, total_population - base_cap)
	# 가옥당 100명 수용
	var needed_active_houses: int = int(ceil(float(needed_house_pop) / float(HOUSE_CAPACITY)))
	
	var ruined_now: Array[Vector2i] = []
	var restored_now: Array[Vector2i] = []
	
	# 1. 인구 감소로 인한 폐허화: 현재 활성 가옥이 필요한 수량보다 많을 때
	if active_houses_list.size() > needed_active_houses:
		var excess_count: int = active_houses_list.size() - needed_active_houses
		for _i: int in range(excess_count):
			if active_houses_list.is_empty():
				break
			var target_pos: Vector2i = active_houses_list.pop_back()
			ruined_houses_list.append(target_pos)
			ruined_now.append(target_pos)
			if grid_ref != null and "grid" in grid_ref:
				grid_ref.grid[target_pos.y][target_pos.x]["is_ruined"] = true

	# 2. 인구 증가로 인한 복원: 현재 활성 가옥이 부족하고 기존 폐허가 존재할 때
	elif active_houses_list.size() < needed_active_houses:
		var shortage_count: int = needed_active_houses - active_houses_list.size()
		var restore_count: int = mini(shortage_count, ruined_houses_list.size())
		for _i: int in range(restore_count):
			if ruined_houses_list.is_empty():
				break
			var restore_pos: Vector2i = ruined_houses_list.pop_back()
			active_houses_list.append(restore_pos)
			restored_now.append(restore_pos)
			if grid_ref != null and "grid" in grid_ref:
				grid_ref.grid[restore_pos.y][restore_pos.x]["is_ruined"] = false

	var total_cap: int = get_total_housing_capacity()
	housing_occupancy_updated.emit(active_houses_list.size(), ruined_houses_list.size(), total_cap)
	
	return {
		"ruined_count": ruined_now.size(),
		"restored_count": restored_now.size(),
		"active_houses": active_houses_list.size(),
		"ruined_houses": ruined_houses_list.size(),
		"total_capacity": total_cap,
		"ruined_tiles": ruined_now,
		"restored_tiles": restored_now
	}

# ==================== 계절 틱 처리 ====================

## SimulationCore의 계절 전환 시 호출되어 인구 갱신 및 세수 반환
func process_seasonal_tick(current_loyalty: int, grid_ref, sim_ref) -> Dictionary:
	var welfare_status: Dictionary = evaluate_welfare_facilities(grid_ref, sim_ref)
	var growth_rate: float = calculate_seasonal_growth_rate(current_loyalty, welfare_status)

	# [기근 차단] 식량 고갈(famine_active) 시 인구 자연 증가 전면 차단
	if sim_ref != null and ("famine_active" in sim_ref and bool(sim_ref.famine_active)):
		growth_rate = minf(growth_rate, 0.0)

	var natural_delta: int = int(round(float(total_population) * growth_rate))
	var old_pop: int = total_population

	# [조세 저항선 평가] 인구 규모별 3대 조세 합계 임계치 초과 시 자연 증가 차단 및 인구 유출
	var total_tax: float = TaxManager.get_total_tax_rate(sim_ref)
	var pop_res: Dictionary = CityStats.update_population(total_population, natural_delta, total_tax)
	var delta_pop: int = int(pop_res.get("delta", natural_delta))
	total_population = int(pop_res.get("new_population", total_population))

	if delta_pop != 0:
		population_changed.emit(total_population, delta_pop)
		
	# 가옥 점유 및 폐허 배칭 업데이트
	var occupancy_res: Dictionary = update_housing_occupancy(grid_ref)
	
	# 계절 세수 계산
	var seasonal_tax: int = calculate_seasonal_tax(total_population)
	
	return {
		"old_population": old_pop,
		"new_population": total_population,
		"delta_population": delta_pop,
		"growth_rate": growth_rate,
		"seasonal_tax": seasonal_tax,
		"occupancy": occupancy_res,
		"welfare_status": welfare_status
	}

# ==================== 직렬화 / 역직렬화 (SaveSystem 연동) ====================

func serialize() -> Dictionary:
	var ruined_coords: Array = []
	for p: Vector2i in ruined_houses_list:
		ruined_coords.append({"x": p.x, "y": p.y})
	var active_coords: Array = []
	for p: Vector2i in active_houses_list:
		active_coords.append({"x": p.x, "y": p.y})
		
	return {
		"total_population": total_population,
		"tax_policy": int(current_tax_policy),
		"haenggung_completed": haenggung_completed,
		"haenggung_boost_applied": haenggung_boost_applied,
		"ruined_houses": ruined_coords,
		"active_houses": active_coords
	}

func deserialize(data: Dictionary) -> void:
	total_population = maxi(0, int(data.get("total_population", data.get("pop", 120))))
	current_tax_policy = int(data.get("tax_policy", TaxPolicy.STANDARD)) as TaxPolicy
	haenggung_completed = bool(data.get("haenggung_completed", false))
	haenggung_boost_applied = bool(data.get("haenggung_boost_applied", false))
	
	ruined_houses_list.clear()
	var ruined_data: Array = data.get("ruined_houses", [])
	for item: Dictionary in ruined_data:
		ruined_houses_list.append(Vector2i(int(item.get("x", 0)), int(item.get("y", 0))))
		
	active_houses_list.clear()
	var active_data: Array = data.get("active_houses", [])
	for item: Dictionary in active_data:
		active_houses_list.append(Vector2i(int(item.get("x", 0)), int(item.get("y", 0))))
