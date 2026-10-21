extends SceneTree

func _init() -> void:
	print("=== 세이브 데이터 시스템 단위 검증 시작 ===")
	SaveSystem.init_default_samples_if_needed()

	# 1. 샘플 슬롯 존재 검증
	var has_slot1: bool = SaveSystem.has_save(1)
	var has_slot2: bool = SaveSystem.has_save(2)
	print("슬롯 1 존재: %s, 슬롯 2 존재: %s" % [has_slot1, has_slot2])
	assert(has_slot1, "슬롯 1이 존재해야 합니다.")
	assert(has_slot2, "슬롯 2가 존재해야 합니다.")

	# 2. 슬롯 1 정보 읽기 검증
	var info1: Dictionary = SaveSystem.get_save_info(1)
	print("슬롯 1 정보: %s" % info1.get("title", ""))
	assert(info1.has("gold"), "슬롯 1에 gold 필드가 있어야 합니다.")

	# 3. 임의 슬롯(99) 생성 및 삭제 사이클 검증
	var path99: String = SaveSystem.get_slot_path(99)
	var f := FileAccess.open(path99, FileAccess.WRITE)
	assert(f != null, "슬롯 99 파일 생성 실패")
	var test_data := {
		"slot": 99,
		"title": "실록 제99권: 테스트 치세 기록",
		"year": 1794,
		"season": "가을",
		"gold": 9999,
		"rice": 8888
	}
	f.store_string(JSON.stringify(test_data, "  "))
	f.close()

	assert(SaveSystem.has_save(99), "슬롯 99 존재 확인 실패")
	var read99: Dictionary = SaveSystem.get_save_info(99)
	assert(read99.get("gold") == 9999, "슬롯 99 내용 불일치")
	print("[PASS] 슬롯 99 생성 및 읽기 검증 성공")

	# 4. 슬롯 99 삭제 검증
	var del_ok: bool = SaveSystem.delete_save(99)
	assert(del_ok, "슬롯 99 삭제 실패")
	assert(not SaveSystem.has_save(99), "삭제 후 슬롯 99가 존재하지 않아야 합니다.")
	var empty_info: Dictionary = SaveSystem.get_save_info(99)
	assert(empty_info.is_empty(), "삭제 후 정보는 비어있어야 합니다.")
	print("[PASS] 슬롯 99 파일 실제 삭제 및 초기화 검증 성공")

	print("=== 모든 세이브 시스템 검증 성공 완료 ===")
	quit(0)
