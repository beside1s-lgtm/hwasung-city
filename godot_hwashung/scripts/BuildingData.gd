extends RefCounted
class_name BuildingData

## [건물 유형 및 조정·정무 액션 매핑 마스터 데이터]
## - 각 거점 건물 및 전각별 실행 가능한 정무 기능 목록(available_royal_actions) 정의
## - 을묘원행은 조건 충족 시 자동 발동되므로 수동 실행 액션 목록에서 엄격히 제외

const ROYAL_ACTIONS: Dictionary = {
	"seojangdae": ["seojangdae_drill"],
	"yeonmudae": ["yeonmudae_drill"],
	"gwana": ["tiger", "bandit"],
	"gwana_site": ["tiger", "bandit"],
	"haenggung": ["haenggung_court"],
	"haenggung_site": ["haenggung_court"],
	# 세부 전각 매핑 (행궁 내부 전각)
	"oegyujanggak": ["research", "uigwe"],
	"nangnamheon": ["court"],
	"naknamheon": ["court"],
	"jeongniso": ["hyoryungwon"]
}

## 건물 식별자별 가능한 정무 액션 목록 반환
static func get_available_royal_actions(building_id: String) -> Array[String]:
	var act_list: Array[String] = []
	var raw_list = ROYAL_ACTIONS.get(building_id, [])
	for act in raw_list:
		var s_act: String = str(act)
		if s_act != "eulmyo": # 을묘원행 수동 실행 완전 제외 보장
			act_list.append(s_act)
	return act_list

## 건물이 조정·정무 집행 가능한 거점 건물인지 여부 판정
static func has_royal_action(building_id: String) -> bool:
	return not get_available_royal_actions(building_id).is_empty()
