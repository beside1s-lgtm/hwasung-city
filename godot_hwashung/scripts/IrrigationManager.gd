extends RefCounted
class_name IrrigationManager

## [수리 농업 인프라 엔진 - 일반 저수지 100개소 수혜 한도 및 만석거 특화 버프 매니저]
## 1. 일반 저수지(축만제 등) 1개소당 최대 100개소 대유둔전 관개 용량 부여
## 2. 만석거(萬石渠) 반경 15타일 이내 대유둔전 +10% 특화 풍작 버프 (총 110%)
## 3. 저수지 부재 또는 용량 초과 둔전 -10% 페널티 (총 90%, 게임 초기 1년/4턴 유예)
## 4. O(1) 타일 수리 상태 캐싱 및 거리 기반 우선 배정

enum IrrigationState {
	DROUGHT = 0,
	NORMAL = 1,
	MANSEOKGEO_BUFF = 2
}

const RESERVOIR_CAPACITY: int = 100
const MANSEOKGEO_RADIUS: float = 15.0

const MULTIPLIER_DROUGHT: float = 0.90
const MULTIPLIER_NORMAL: float = 1.00
const MULTIPLIER_BUFF: float = 1.10

# 실시간 집계 캐시 (HUD 및 통계용)
static var total_capacity: int = 0
static var irrigated_farms_count: int = 0
static var normal_farms_count: int = 0
static var manseokgeo_farms_count: int = 0
static var drought_farms_count: int = 0
static var total_farms_count: int = 0

## 수리 상태별 소출 배율 반환
static func get_yield_multiplier_by_state(state: int, is_grace_period: bool = false) -> float:
	match state:
		IrrigationState.MANSEOKGEO_BUFF:
			return MULTIPLIER_BUFF
		IrrigationState.NORMAL:
			return MULTIPLIER_NORMAL
		IrrigationState.DROUGHT:
			return MULTIPLIER_NORMAL if is_grace_period else MULTIPLIER_DROUGHT
		_:
			return MULTIPLIER_NORMAL

## 타일 딕셔너리 기반 소출 배율 반환
static func get_yield_multiplier(tile: Dictionary, is_grace_period: bool = false) -> float:
	var state: int = int(tile.get("irrigation_state", IrrigationState.DROUGHT))
	return get_yield_multiplier_by_state(state, is_grace_period)

## 상태별 살피기 및 툴팁 텍스트 반환
static func get_status_text(tile: Dictionary, is_grace_period: bool = false) -> String:
	var state: int = int(tile.get("irrigation_state", IrrigationState.DROUGHT))
	match state:
		IrrigationState.MANSEOKGEO_BUFF:
			return "[만석거 황금들녘: 풍작 효과 +10%]"
		IrrigationState.NORMAL:
			return "[수리 시설 혜택: 안정적 용수 공급]"
		IrrigationState.DROUGHT:
			if is_grace_period:
				return "[가뭄/용수 부족: 식량 생산 -10% (초반 유예 중)]"
			return "[가뭄/용수 부족: 식량 생산 -10%]"
		_:
			return "[일반 관개 (정상)]"

## 살피기 모달 본문용 고증 설명 텍스트 추가분
static func get_inspect_narrative_addition(tile: Dictionary, is_grace_period: bool = false) -> String:
	var state: int = int(tile.get("irrigation_state", IrrigationState.DROUGHT))
	match state:
		IrrigationState.MANSEOKGEO_BUFF:
			return "\n\n🌾 정조 대왕의 만석거 관개수로 덕분에 벼가 누렇게 익어갑니다! (+10%)"
		IrrigationState.NORMAL:
			return "\n\n💧 [수리 시설 혜택: 안정적 용수 공급으로 정상 소출을 유지합니다.]"
		IrrigationState.DROUGHT:
			if is_grace_period:
				return "\n\n⚠️ 알림: 신읍치 개간 초기(1년 유예)로 정상 생산 중이나, 저수지가 없으면 곧 가뭄 피해(-10%)를 입게 됩니다!"
			return "\n\n⚠️ 경고: 수리 시설 부족으로 생산량이 10% 감소 중입니다. 저수지를 축조하십시오!"
		_:
			return ""

## HUD 식량 툴팁용 수리 용량 현황 문자열
static func get_hud_capacity_string() -> String:
	return "총 저수지 수용량: 현재 %d / 최대 %d 개소 둔전 공급 중" % [irrigated_farms_count, total_capacity]

## [핵심 관개 배분 및 만석거 범위 판정 알고리즘]
## 저수지나 둔전이 신규 건설되거나 철거될 때 단 1회 호출되어 그리드 캐시 갱신
static func recalculate_irrigation(grid: GameGrid, _sim: SimulationCore = null) -> Dictionary:
	if grid == null:
		return {
			"total_capacity": 0,
			"total_farms": 0,
			"irrigated_farms": 0,
			"buff_farms": 0,
			"drought_farms": 0
		}

	# 1. 만석거 및 일반 저수지 시설 수집
	var manseokgeo_anchors: Array[Vector2i] = BuildingManager.get_buildings_by_type("MANSEOKGEO", grid)
	var reservoir_anchors: Array[Vector2i] = BuildingManager.get_buildings_by_type("RESERVOIR", grid)
	
	# 만석거 모든 타일 좌표 수집 (반경 거리 판정 정밀도 극대화)
	var manseokgeo_all_tiles: Array[Vector2i] = []
	var all_reservoir_tiles: Array[Vector2i] = []

	for y_idx: int in range(grid.size):
		for x_idx: int in range(grid.size):
			var c_tile: Dictionary = grid.grid[y_idx][x_idx]
			if c_tile.has("wall_build") or bool(c_tile.get("under_construction", false)):
				continue
			var b_name: String = str(c_tile.get("building", ""))
			var f_name: String = str(c_tile.get("facility_id", ""))
			if b_name in ["manseokgeo", "manseokgeo_site"] or f_name == "manseokgeo":
				manseokgeo_all_tiles.append(Vector2i(x_idx, y_idx))
				all_reservoir_tiles.append(Vector2i(x_idx, y_idx))
			elif b_name in ["reservoir", "chukmanje", "chukmanje_site"] or f_name in ["reservoir", "chukmanje"]:
				all_reservoir_tiles.append(Vector2i(x_idx, y_idx))

	var manseokgeo_count: int = manseokgeo_anchors.size()
	var normal_res_count: int = reservoir_anchors.size()
	total_capacity = (normal_res_count + manseokgeo_count) * RESERVOIR_CAPACITY

	# 2. 전체 둔전(대유둔전 및 경작지) 수집
	var all_farms: Array[Dictionary] = BuildingManager.get_all_farms(grid)
	total_farms_count = all_farms.size()

	if all_farms.is_empty():
		irrigated_farms_count = 0
		normal_farms_count = 0
		manseokgeo_farms_count = 0
		drought_farms_count = 0
		return {
			"total_capacity": total_capacity,
			"total_farms": 0,
			"irrigated_farms": 0,
			"buff_farms": 0,
			"drought_farms": 0
		}

	# 1단계: 만석거 주변 농지 우선 판정 (반경 15타일 이내)
	var buff_count: int = 0
	var non_buff_farms: Array[Dictionary] = []

	for farm_data: Dictionary in all_farms:
		var f_cell: Dictionary = farm_data["cell"]
		var f_pos: Vector2i = farm_data["pos"]
		var is_buffed: bool = false

		if not manseokgeo_all_tiles.is_empty():
			for m_tile: Vector2i in manseokgeo_all_tiles:
				if Vector2(f_pos).distance_to(Vector2(m_tile)) <= MANSEOKGEO_RADIUS:
					is_buffed = true
					break

		if is_buffed:
			f_cell["irrigation_state"] = IrrigationState.MANSEOKGEO_BUFF
			f_cell["irrigation_multiplier"] = MULTIPLIER_BUFF
			buff_count += 1
		else:
			f_cell["irrigation_state"] = IrrigationState.DROUGHT
			f_cell["irrigation_multiplier"] = MULTIPLIER_DROUGHT
			
			# 가장 가까운 저수지와의 거리 계산
			var min_dist: float = 999999.0
			for r_tile: Vector2i in all_reservoir_tiles:
				var dist_val: float = Vector2(f_pos).distance_to(Vector2(r_tile))
				if dist_val < min_dist:
					min_dist = dist_val
			farm_data["dist_to_res"] = min_dist
			non_buff_farms.append(farm_data)

	# 2단계: 나머지 둔전 중 저수지 총 용량 한도 내에서 NORMAL 배정
	# 저수지와의 거리가 가까운 둔전부터 우선 관개 혜택 배정
	var remaining_capacity: int = total_capacity - buff_count
	var normal_count: int = 0
	var drought_count: int = 0

	if remaining_capacity > 0 and not all_reservoir_tiles.is_empty():
		non_buff_farms.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["dist_to_res"]) < float(b["dist_to_res"])
		)

	for rem_farm: Dictionary in non_buff_farms:
		var r_cell: Dictionary = rem_farm["cell"]
		if remaining_capacity > 0 and not all_reservoir_tiles.is_empty():
			r_cell["irrigation_state"] = IrrigationState.NORMAL
			r_cell["irrigation_multiplier"] = MULTIPLIER_NORMAL
			remaining_capacity -= 1
			normal_count += 1
		else:
			r_cell["irrigation_state"] = IrrigationState.DROUGHT
			r_cell["irrigation_multiplier"] = MULTIPLIER_DROUGHT
			drought_count += 1

	manseokgeo_farms_count = buff_count
	normal_farms_count = normal_count
	irrigated_farms_count = buff_count + normal_count
	drought_farms_count = drought_count

	return {
		"total_capacity": total_capacity,
		"total_farms": total_farms_count,
		"irrigated_farms": irrigated_farms_count,
		"normal_farms": normal_farms_count,
		"buff_farms": manseokgeo_farms_count,
		"drought_farms": drought_farms_count
	}
