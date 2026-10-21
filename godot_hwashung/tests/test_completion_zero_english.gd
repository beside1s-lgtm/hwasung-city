extends SceneTree

func _init() -> void:
	print("=== [TEST START] 완공 보고 Zero-English 전수 검증 ===")
	var total_tests: int = 0
	var pass_count: int = 0

	var guide := TutorialGuide.new()
	var sim := SimulationCore.new()
	guide.sim = sim
	guide._build_ui()

	# 검사 함수: title 및 text에 영문 알파벳이 존재하는지 체크
	var check_zero_english = func(b_key: String, expected_name: String) -> bool:
		guide.report_building_completed(b_key)
		var page_text: String = guide._page_lbl.text
		var body_text: String = guide._text_lbl.text
		var has_eng: bool = false
		for i in range(page_text.length()):
			var c: int = page_text.unicode_at(i)
			if (c >= 65 and c <= 90) or (c >= 97 and c <= 122):
				has_eng = true
				break
		for i in range(body_text.length()):
			var c2: int = body_text.unicode_at(i)
			if (c2 >= 65 and c2 <= 90) or (c2 >= 97 and c2 <= 122):
				has_eng = true
				break
		var name_match: bool = expected_name in page_text
		return not has_eng and name_match

	# 1. 연무대 및 변종 키값 검증
	total_tests += 1
	guide._reported_unique_buildings.clear()
	if check_zero_english.call("yeonmudae", "연무대"):
		print("[PASS] Test 1: 'yeonmudae' 완공 보고 한글화 정상 (연무대)")
		pass_count += 1
	else:
		printerr("[FAIL] Test 1: 'yeonmudae' 한글화 실패: ", guide._page_lbl.text)

	total_tests += 1
	guide._reported_unique_buildings.clear()
	if check_zero_english.call("yeonmudae_site", "연무대"):
		print("[PASS] Test 2: 'yeonmudae_site' 완공 보고 한글화 정상 (연무대)")
		pass_count += 1
	else:
		printerr("[FAIL] Test 2: 'yeonmudae_site' 한글화 실패: ", guide._page_lbl.text)

	total_tests += 1
	guide._reported_unique_buildings.clear()
	if check_zero_english.call("dongjangdae", "연무대"):
		print("[PASS] Test 3: 'dongjangdae' 완공 보고 한글화 정상 (연무대)")
		pass_count += 1
	else:
		printerr("[FAIL] Test 3: 'dongjangdae' 한글화 실패: ", guide._page_lbl.text)

	# 2. 방화수류정 및 변종 키값 검증
	total_tests += 1
	guide._reported_unique_buildings.clear()
	if check_zero_english.call("banghwasuryu", "방화수류정"):
		print("[PASS] Test 4: 'banghwasuryu' 완공 보고 한글화 정상 (방화수류정)")
		pass_count += 1
	else:
		printerr("[FAIL] Test 4: 'banghwasuryu' 한글화 실패: ", guide._page_lbl.text)

	total_tests += 1
	guide._reported_unique_buildings.clear()
	if check_zero_english.call("banghwasuryujeong", "방화수류정"):
		print("[PASS] Test 5: 'banghwasuryujeong' 완공 보고 한글화 정상 (방화수류정)")
		pass_count += 1
	else:
		printerr("[FAIL] Test 5: 'banghwasuryujeong' 한글화 실패: ", guide._page_lbl.text)

	total_tests += 1
	guide._reported_unique_buildings.clear()
	if check_zero_english.call("dongbuk_gakru", "방화수류정"):
		print("[PASS] Test 6: 'dongbuk_gakru' 완공 보고 한글화 정상 (방화수류정)")
		pass_count += 1
	else:
		printerr("[FAIL] Test 6: 'dongbuk_gakru' 한글화 실패: ", guide._page_lbl.text)

	# 3. 일반 구획 타일 완공 보고 필터링 검증
	total_tests += 1
	guide._mode = "step"
	guide.report_building_completed("res_1")
	guide.report_building_completed("com_1")
	guide.report_building_completed("agr_1")
	if guide._mode == "step":
		print("[PASS] Test 7: 일반 구획(res_1, com_1, agr_1) 완공 보고 호출 무시 정상")
		pass_count += 1
	else:
		printerr("[FAIL] Test 7: 일반 구획 완공 보고가 필터링되지 않음")

	# 4. 미등록 영문 키값 유입 시 Zero-English 강제 fallback 검증
	total_tests += 1
	if check_zero_english.call("unknown_mystic_facility_xyz", "화성 시설"):
		print("[PASS] Test 8: 미등록 영문 키값 '화성 시설'로 Zero-English fallback 정상")
		pass_count += 1
	else:
		printerr("[FAIL] Test 8: 미등록 키값 영문 누출: ", guide._page_lbl.text)

	# 5. 국책 대역사 완공 보고 영문 ID 및 보상 메시지 입력 시 프로젝트명 역조회 검증
	total_tests += 1
	guide.report_mega_project_completed("changryong_east")
	var page_p1: String = guide._page_lbl.text
	if "창룡문 권역 동성곽 대역사" in page_p1:
		print("[PASS] Test 9: 국책 대역사 ID('changryong_east') 완공 보고 정상 매핑 확인")
		pass_count += 1
	else:
		printerr("[FAIL] Test 9: 국책 대역사 ID 매핑 실패: ", page_p1)

	total_tests += 1
	var reward_sample: String = "창룡문과 동성곽이 우뚝 솟아 동부 방어선이 완전 연결되었습니다! 동북공심돈과 동북포루도 함께 세워졌습니다!"
	guide.report_mega_project_completed(reward_sample)
	var page_p2: String = guide._page_lbl.text
	if "창룡문 권역 동성곽 대역사" in page_p2:
		print("[PASS] Test 10: 국책 대역사 reward_msg 유입 시 프로젝트명 역조회 및 완공 보고 정상 확인")
		pass_count += 1
	else:
		printerr("[FAIL] Test 10: 국책 대역사 reward_msg 역조회 실패: ", page_p2)

	print("\n--- 검사 결과 통계 ---")
	print("총 테스트 항목: %d / 성공: %d / 실패: %d" % [total_tests, pass_count, total_tests - pass_count])
	if pass_count == total_tests:
		print("=== [TEST PASS] 완공 보고 Zero-English 100% 무결성 검증 완료! ===")
	else:
		printerr("=== [TEST FAIL] 일부 테스트 실패 ===")

	guide.queue_free()
	quit(0 if pass_count == total_tests else 1)
