extends SceneTree

func _init() -> void:
	print("=== 세이브 슬롯 일치성 및 SSOT 단위 검증 시작 ===")

	# 1. SaveSystem.SLOTS 검증
	assert(SaveSystem.SLOTS.size() == 4, "SaveSystem.SLOTS의 크기는 4여야 합니다.")
	assert(SaveSystem.SLOTS == [1, 2, 3, 0], "SaveSystem.SLOTS는 [1, 2, 3, 0]이어야 합니다.")
	print("[PASS] SaveSystem.SLOTS 상수 정의 일치 ([1, 2, 3, 0])")

	# 2. get_slot_title_prefix & get_slot_display_name 검증
	assert(SaveSystem.get_slot_title_prefix(1) == "실록 제1권", "슬롯 1 접두사 불일치")
	assert(SaveSystem.get_slot_title_prefix(2) == "실록 제2권", "슬롯 2 접두사 불일치")
	assert(SaveSystem.get_slot_title_prefix(3) == "실록 제3권", "슬롯 3 접두사 불일치")
	assert(SaveSystem.get_slot_title_prefix(0) == "실록 제0권 (자동 저장)", "슬롯 0 접두사 불일치")

	assert(SaveSystem.get_slot_display_name(1) == "제1권", "슬롯 1 표시명 불일치")
	assert(SaveSystem.get_slot_display_name(0) == "제0권 (자동 저장)", "슬롯 0 표시명 불일치")
	print("[PASS] 슬롯별 명칭 및 접두사 검증 성공")

	# 3. get_formatted_title 검증
	var empty_info: Dictionary = {}
	var title_empty_0: String = SaveSystem.get_formatted_title(0, empty_info)
	var title_empty_1: String = SaveSystem.get_formatted_title(1, empty_info)
	assert(title_empty_0 == "실록 제0권 (자동 저장): 【비어 있는 기록 슬롯】", "빈 슬롯 0 타이틀 불일치")
	assert(title_empty_1 == "실록 제1권: 【비어 있는 기록 슬롯】", "빈 슬롯 1 타이틀 불일치")

	# 구버전 세이브 호환 (autosave에 "실록 제0권: ..."으로 저장된 데이터)
	var legacy_auto_info := {
		"title": "실록 제0권: 1800년 봄 - 정조 25년",
		"year": 1800,
		"season": "봄"
	}
	var formatted_legacy := SaveSystem.get_formatted_title(0, legacy_auto_info)
	assert(formatted_legacy == "실록 제0권 (자동 저장): 1800년 봄 - 정조 25년", "구버전 슬롯 0 보정 실패: %s" % formatted_legacy)

	# 신규 세이브 타이틀
	var new_auto_info := {
		"title": "실록 제0권 (자동 저장): 1800년 봄 - 정조 25년",
		"year": 1800,
		"season": "봄"
	}
	var formatted_new := SaveSystem.get_formatted_title(0, new_auto_info)
	assert(formatted_new == "실록 제0권 (자동 저장): 1800년 봄 - 정조 25년", "신규 슬롯 0 보정 실패")
	print("[PASS] 구버전/신버전/빈 슬롯 get_formatted_title 검증 성공")

	# 4. 실제 디스크에 존재하는 세이브 슬롯 검증
	var has_0: bool = SaveSystem.has_save(0)
	var has_1: bool = SaveSystem.has_save(1)
	print("디스크 세이브 검사 -> 슬롯 0(autosave): %s, 슬롯 1: %s" % [has_0, has_1])
	if has_0:
		var info_0 := SaveSystem.get_save_info(0)
		print("슬롯 0 타이틀: %s" % SaveSystem.get_formatted_title(0, info_0))
	if has_1:
		var info_1 := SaveSystem.get_save_info(1)
		print("슬롯 1 타이틀: %s" % SaveSystem.get_formatted_title(1, info_1))

	print("=== 모든 슬롯 일치성 검증 완료 (SUCCESS) ===")
	quit(0)
