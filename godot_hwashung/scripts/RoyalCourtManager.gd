extends RefCounted
class_name RoyalCourtManager

## [조정·정무 기능 통합 컨트롤러 (DRY 원칙 SSOT)]
## 거점 건물 클릭(다이렉트 인터랙션), 행궁 전각 선택 모달, 하단 도크 바에서 호출되는
## 모든 국가 정무/훈련/연구/참배/인재/치안 집행 로직을 단일 창구화

static func open_court_action(action_id: String, panels: PanelController) -> void:
	if panels == null:
		return
	# 을묘원행은 조건 충족 시 자동 발동되므로 수동 오픈에서 제외
	if action_id == "eulmyo":
		return
	panels.open_action_modal(action_id)

## 서장대 야조훈련 실행
static func execute_seojangdae_drill(panels: PanelController) -> void:
	if panels != null:
		panels.open_action_modal("seojangdae_drill")

## 연무대 장용영 군사훈련 실행
static func execute_yeonmudae_drill(panels: PanelController) -> void:
	if panels != null:
		panels.open_action_modal("yeonmudae_drill")

## 화성유수부 관아 (호포책/도적토벌) 허브 또는 세부 모달 실행
static func execute_gwana_action(sub_action: String, panels: PanelController) -> void:
	if panels == null:
		return
	if sub_action == "tiger":
		panels.open_action_modal("tiger")
	elif sub_action == "bandit":
		panels.open_action_modal("bandit")
	else:
		panels.open_action_modal("gwana")

## 화성행궁 외규장각 (실학 연구 / 의궤 편찬)
static func execute_oegyujanggak_action(sub_action: String, panels: PanelController) -> void:
	if panels == null:
		return
	if sub_action == "uigwe":
		panels.open_action_modal("uigwe")
	else:
		panels.open_action_modal("research")

## 화성행궁 낙남헌 (인재 등용)
static func execute_nangnamheon_action(panels: PanelController) -> void:
	if panels != null:
		panels.open_action_modal("court")

## 화성행궁 정리소 (현륭원 친림 참배)
static func execute_jeongniso_action(panels: PanelController) -> void:
	if panels != null:
		panels.open_action_modal("hyoryungwon")
