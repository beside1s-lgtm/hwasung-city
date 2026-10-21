extends RefCounted
class_name FortressWallManager

## [수원화성 성곽·성문 인프라 및 보수 관리 모듈]
## 1. 성곽 신규 축성 및 파손 보수 자원 소모량 SSOT
## 2. 사대문·암문·수문 1개소 건립 비용 SSOT
## 3. 난이도별 배율(DifficultyManager.get_cost_multiplier())을 연동하여 정확한 지출 산출

## 쉬움(EASY) 기준 원가 상수
const BASE_WALL_BUILD_COST: Dictionary = {
	"gold": 1000,
	"rice": 500
}

const BASE_WALL_REPAIR_COST: Dictionary = {
	"gold": 500,
	"rice": 250
}

const BASE_GATE_BUILD_COST: Dictionary = {
	"gold": 2000,
	"rice": 1500
}

## 성곽 1칸 신규 건설 비용 (난이도 배율 반영)
static func get_wall_build_cost() -> Dictionary:
	return DifficultyManager.get_wall_build_cost()

## 성곽 1칸 파손 보수 비용 (난이도 배율 반영)
static func get_wall_repair_cost() -> Dictionary:
	return DifficultyManager.get_wall_repair_cost()

## 성문(사대문, 암문, 수문) 1개소 건립 비용 (난이도 배율 반영)
static func get_gate_build_cost() -> Dictionary:
	return DifficultyManager.get_gate_build_cost()

## 건물 ID가 성문류(사대문/암문/수문)인지 판정
static func is_gate_structure(building_id: String) -> bool:
	return building_id in [
		"gate", "jangan", "paldal", "hwaseo", "changryong",
		"hwahong", "namsu_mun", "ammun", "floodgate"
	] or building_id.ends_with("_gate") or building_id.ends_with("_mun")

## 성벽 타일 파손 여부 판정
static func is_wall_damaged(tile: Dictionary) -> bool:
	return bool(tile.get("is_damaged", false)) or bool(tile.get("damaged", false)) or int(tile.get("wall_health", 100)) < 100

## 성벽 타일 1칸 보수 수행
static func repair_wall_tile(grid: GameGrid, x: int, y: int, sim: SimulationCore = null) -> Dictionary:
	if grid == null or not grid.in_bounds(x, y):
		return {"success": false, "msg": "유효하지 않은 좌표입니다."}

	var tile: Dictionary = grid.grid[y][x]
	var bld: String = str(tile.get("building", ""))
	if bld != "wall" and not bld.begins_with("wall"):
		return {"success": false, "msg": "성벽 칸이 아닙니다."}

	var cost: Dictionary = get_wall_repair_cost()
	var gold_cost: int = int(cost["gold"])
	var rice_cost: int = int(cost["rice"])

	if sim != null:
		if sim.gold < gold_cost or sim.rice < rice_cost:
			return {
				"success": false,
				"msg": "보수 자원이 부족합니다. (필요: 금 %d냥, 곡 %d석)" % [gold_cost, rice_cost]
			}
		sim.gold -= gold_cost
		sim.rice -= rice_cost
		sim.emit_signal("state_updated", sim.gold, sim.rice, sim.population, sim.loyalty, sim.flood_defense)

	tile["is_damaged"] = false
	tile["damaged"] = false
	tile["wall_health"] = 100
	var changed_tiles: Array[Vector2i] = [Vector2i(x, y)]
	grid.emit_signal("grid_tiles_changed", changed_tiles)

	return {
		"success": true,
		"cost": cost,
		"msg": "성곽 칸(%d, %d)을 보수했습니다. (금 -%d냥, 곡 -%d석)" % [x, y, gold_cost, rice_cost]
	}
