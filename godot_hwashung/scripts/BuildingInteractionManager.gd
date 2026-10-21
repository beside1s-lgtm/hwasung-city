extends Node
class_name BuildingInteractionManager

## [거점 건물 다이렉트 인터랙션 및 클릭 이벤트 핸들러]
## - GameGrid.world_to_grid() $O(1)$ 그리드 셀 기반 피킹
## - 화성행궁 클릭 시 전각 선택 서브 패널(HaenggungSubBuildingPopup) 호출
## - 서장대, 연무대, 화성유수부(관아) 클릭 시 살피기 창 내 정무 집행 버튼 주입
## - 을묘원행은 자동 발동 이벤트이므로 수동 집행 목록에서 엄격히 제외

var grid: GameGrid
var sim: SimulationCore
var panels: PanelController
var inspect_popup: InspectPopup
var haenggung_popup: HaenggungSubBuildingPopup
var seojangdae_popup: SeojangdaePopup
var yeonmudae_popup: YeonmudaePopup

func setup(p_grid: GameGrid, p_sim: SimulationCore, p_panels: PanelController, p_inspect: InspectPopup, p_haenggung: HaenggungSubBuildingPopup, p_seojangdae: SeojangdaePopup = null, p_yeonmudae: YeonmudaePopup = null) -> void:
	grid = p_grid
	sim = p_sim
	panels = p_panels
	inspect_popup = p_inspect
	haenggung_popup = p_haenggung
	seojangdae_popup = p_seojangdae
	yeonmudae_popup = p_yeonmudae

## 월드 좌표 기준 건물 인터랙션 처리 (O(1) 피킹)
func handle_world_click(world_pos: Vector2) -> bool:
	if grid == null:
		return false
	var cell_pos: Vector2i = grid.world_to_grid(world_pos)
	return handle_cell_click(cell_pos)

## 그리드 셀 좌표 기준 건물 인터랙션 처리
func handle_cell_click(c: Vector2i) -> bool:
	if grid == null or not grid.in_bounds(c.x, c.y):
		return false

	var cell: Dictionary = grid.tile(c.x, c.y)
	var b: String = str(cell.get("building", ""))
	var fac_id: String = str(cell.get("facility_id", ""))

	# 1. 화성행궁 본궁 영역 클릭 판정 (haenggung 또는 haenggung_site)
	var is_haenggung: bool = (b == "haenggung" or b == "haenggung_site" or fac_id.begins_with("haenggung"))
	if is_haenggung:
		if haenggung_popup != null:
			haenggung_popup.open_haenggung_popup(cell)
			return true

	# 2. 서장대, 연무대, 화성유수부 관아 판정
	var building_type: String = ""
	if b == "seojangdae" or fac_id == "seojangdae" or cell.has("sj2"):
		building_type = "seojangdae"
		if seojangdae_popup != null:
			seojangdae_popup.open_seojangdae_popup()
			return true
	elif b == "yeonmudae" or fac_id == "yeonmudae" or cell.has("ym5"):
		building_type = "yeonmudae"
		if yeonmudae_popup != null:
			yeonmudae_popup.open_yeonmudae_popup()
			return true
	elif b in ["gwana", "gwana_site"] or fac_id in ["gwana", "gwana_site"]:
		building_type = "gwana"

	if building_type != "":
		# 거점 건물의 경우 살피기 팝업과 정무 집행 인터랙션을 수행
		return true

	return false

## 건물이 특수 관공서/행궁인지 여부 판정
func is_special_royal_building(c: Vector2i) -> bool:
	if grid == null or not grid.in_bounds(c.x, c.y):
		return false
	var cell: Dictionary = grid.tile(c.x, c.y)
	var b: String = str(cell.get("building", ""))
	var fac_id: String = str(cell.get("facility_id", ""))
	if b.begins_with("haenggung") or fac_id.begins_with("haenggung"):
		return true
	if b in ["seojangdae", "yeonmudae", "gwana", "gwana_site"] or fac_id in ["seojangdae", "yeonmudae", "gwana"]:
		return true
	if cell.has("sj2") or cell.has("ym5"):
		return true
	return false

static func get_interactions_for_building(b_id: String, trial_mgr = null) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	if b_id.begins_with("haenggung"):
		res.append({"action": "oegyujanggak", "name": "외규장각"})
		res.append({"action": "nangnamheon", "name": "낙남헌"})
		res.append({"action": "jeongniso", "name": "정리소"})
	elif b_id == "seojangdae":
		res.append({"action": "drill_seojangdae", "name": "서장대 야조훈련"})
	elif b_id == "yeonmudae":
		res.append({"action": "drill_yeonmudae", "name": "장용영 군사훈련"})
	elif b_id in ["gwana", "gwana_site"]:
		var has_trial: bool = trial_mgr != null and trial_mgr.has_method("has_pending_trial") and trial_mgr.has_pending_trial()
		res.append({
			"id": "trial",
			"action": "open_trial",
			"name": "백성의 억울한 송사 친국·명판결" if has_trial else "공형청 송사 기록 열람",
			"badge": "새 송사" if has_trial else ""
		})
		res.append({"id": "bandit", "action": "subjugate_bandit", "name": "도적떼 토벌 출동"})
		res.append({"id": "tiger", "action": "policy_tiger", "name": "포호책 시행"})
	return res
