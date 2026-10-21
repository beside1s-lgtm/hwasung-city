extends SceneTree

## 11종(+5종 보완) 세시풍속·민속놀이 살피기(Inspect) 역사 고증 이야기꾼 해설 시스템 전수 검증

var log_file: FileAccess

func _log(msg: String) -> void:
	print(msg)
	if log_file:
		log_file.store_line(msg)
		log_file.flush()

func _init() -> void:
	log_file = FileAccess.open("res://test_folklore_inspect_result.txt", FileAccess.WRITE)
	_log("=== [검증 시작] 11종 세시풍속·민속놀이 살피기 역사 고증 시스템 검증 ===")
	call_deferred("_run_verification")

func _run_verification() -> void:
	var total_passed: int = 0
	var total_tests: int = 0

	# -------------------------------------------------------------------------
	# 1. 11종 세시풍속 + 5종 추가 세시풍속 텍스트 딕셔너리 및 20자 4줄 규격 전수 검증
	# -------------------------------------------------------------------------
	_log("\n[TEST 1] 16종 세시풍속 해설 텍스트 규격 및 포트레이트 검증")
	var expected_activities: Array[String] = [
		"ACTIVITY_JWIBULNORI",
		"ACTIVITY_SEOKJEON",
		"ACTIVITY_KITE_FLYING",
		"ACTIVITY_SSIREUM_CHAMPION",
		"ACTIVITY_GANGGANGSULLAE",
		"ACTIVITY_LION_DANCE",
		"ACTIVITY_NEOLTTWIGI",
		"ACTIVITY_SWINGING",
		"ACTIVITY_YARD_GAMES",
		"ACTIVITY_NAMSADANG",
		"ACTIVITY_JEONJISU",
		"ACTIVITY_PUNGMUL",
		"ACTIVITY_SSIREUM",
		"ACTIVITY_TALCHUM",
		"ACTIVITY_PAENGI",
		"ACTIVITY_TAEKKYEON"
	]

	for act_key: String in expected_activities:
		total_tests += 1
		var entity: Dictionary = {
			"kind": "folklore",
			"activity_type": act_key
		}
		var data: Dictionary = InspectNarrativeGenerator.build_inspect_data(entity)
		if data.get("category", "") != "folklore":
			_log("[FAIL] %s: category가 folklore가 아님 (%s)" % [act_key, data.get("category", "")])
			continue

		var title: String = String(data.get("title", ""))
		var desc: String = String(data.get("description", ""))
		var tex = data.get("texture", null)

		if title == "":
			_log("[FAIL] %s: 타이틀 누락" % act_key)
			continue

		var lines: PackedStringArray = desc.split("\n")
		if lines.size() != 4:
			_log("[FAIL] %s: 4줄 규격 불일치 (현재 %d줄)" % [act_key, lines.size()])
			continue

		var total_chars: int = desc.replace("\n", "").length()
		if total_chars < 65 or total_chars > 120:
			_log("[FAIL] %s: 글자수 범위 초과 (%d자, 권장 70~100자)" % [act_key, total_chars])
			continue

		if tex == null:
			_log("[FAIL] %s: 초상화 텍스처 누락" % act_key)
			continue

		_log("  [PASS] %s -> 타이틀: '%s' | 줄수: %d | 글자수: %d자" % [act_key, title, lines.size(), total_chars])
		total_passed += 1

	# -------------------------------------------------------------------------
	# 2. 별칭 및 소문자 정규화(Normalization) O(1) 검증
	# -------------------------------------------------------------------------
	_log("\n[TEST 2] 세시풍속 활동 키 정규화(Normalization) 검증")
	var alias_tests: Dictionary = {
		"jwibul": "ACTIVITY_JWIBULNORI",
		"seokjeon": "ACTIVITY_SEOKJEON",
		"kite": "ACTIVITY_KITE_FLYING",
		"kites": "ACTIVITY_KITE_FLYING",
		"bull_parade": "ACTIVITY_SSIREUM_CHAMPION",
		"ganggang": "ACTIVITY_GANGGANGSULLAE",
		"lion": "ACTIVITY_LION_DANCE",
		"neolttwigi": "ACTIVITY_NEOLTTWIGI",
		"swing": "ACTIVITY_SWINGING",
		"kids": "ACTIVITY_YARD_GAMES",
		"juldagi": "ACTIVITY_NAMSADANG",
		"jeongisu": "ACTIVITY_JEONJISU",
		"pungmul": "ACTIVITY_PUNGMUL",
		"ssireum": "ACTIVITY_SSIREUM",
		"talchum": "ACTIVITY_TALCHUM",
		"paengi": "ACTIVITY_PAENGI",
		"taekkyeon": "ACTIVITY_TAEKKYEON"
	}

	for raw_key: String in alias_tests.keys():
		total_tests += 1
		var expected: String = alias_tests[raw_key]
		var normalized: String = InspectNarrativeGenerator.normalize_activity_key(raw_key)
		if normalized == expected:
			_log("  [PASS] normalize_activity_key('%s') == '%s'" % [raw_key, normalized])
			total_passed += 1
		else:
			_log("  [FAIL] normalize_activity_key('%s') == '%s' (기대: '%s')" % [raw_key, normalized, expected])

	# -------------------------------------------------------------------------
	# 3. Main 씬 로드 및 인게임 CityLayer 세시풍속 타일 피킹 연동 검증
	# -------------------------------------------------------------------------
	_log("\n[TEST 3] Main 씬 및 CityLayer 세시풍속 살피기(Inspect) 통합 검증")
	var main_scene = load("res://scenes/Main.tscn")
	if not main_scene:
		_log("[FAIL] Main.tscn 로드 실패")
		quit(1)
		return

	var main = main_scene.instantiate()
	root.add_child(main)

	for _i in range(5):
		await process_frame

	var city_layer: CityLayer = main.city
	var citizen_layer: CitizenLayer = main.citizen_layer
	var festivals: FestivalSystem = main.festivals
	var inspect_popup: InspectPopup = main.inspect_popup

	if not city_layer or not inspect_popup or not festivals:
		_log("[FAIL] 필수 컴포넌트(city, inspect_popup, festivals) 바인딩 누락")
		quit(1)
		return

	# A. FestivalSystem의 scenes에 모의 놀이판 등록 후 CityLayer._show_inspect 테스트
	_log("\n  (3-A) FestivalSystem 놀이판 클릭 판정 검증")
	festivals.scenes.clear()
	festivals.scenes.append({
		"kind": "seokjeon",
		"center": Vector2(10.5, 10.5),
		"other_pos": Vector2(12.5, 10.5),
		"n": 2,
		"seed": 123
	})
	festivals.scenes.append({
		"kind": "ssireum",
		"center": Vector2(20.5, 20.5),
		"n": 2,
		"seed": 456
	})
	festivals.scenes.append({
		"kind": "jwibul",
		"center": Vector2(30.5, 30.5),
		"n": 2,
		"seed": 789
	})

	# 1) 석전 놀이판 좌표 (10, 10) 클릭
	total_tests += 1
	city_layer._show_inspect(Vector2i(10, 10))
	if inspect_popup._title_label and inspect_popup._title_label.text.contains("석전"):
		_log("  [PASS] 석전 판정 성공: '%s'" % inspect_popup._title_label.text)
		total_passed += 1
	else:
		_log("  [FAIL] 석전 판정 실패: '%s'" % (inspect_popup._title_label.text if inspect_popup._title_label else "null"))

	# 2) 석전 맞은편 제방 좌표 (12, 10) 클릭
	total_tests += 1
	city_layer._show_inspect(Vector2i(12, 10))
	if inspect_popup._title_label and inspect_popup._title_label.text.contains("석전"):
		_log("  [PASS] 석전 맞은편 제방 판정 성공: '%s'" % inspect_popup._title_label.text)
		total_passed += 1
	else:
		_log("  [FAIL] 석전 맞은편 제방 판정 실패")

	# 3) 씨름 놀이판 좌표 (20, 20) 클릭
	total_tests += 1
	city_layer._show_inspect(Vector2i(20, 20))
	if inspect_popup._title_label and inspect_popup._title_label.text.contains("씨름"):
		_log("  [PASS] 단오 씨름판 판정 성공: '%s'" % inspect_popup._title_label.text)
		total_passed += 1
	else:
		_log("  [FAIL] 씨름판 판정 실패: '%s'" % (inspect_popup._title_label.text if inspect_popup._title_label else "null"))

	# 4) 쥐불놀이 판 좌표 (30, 30) 클릭
	total_tests += 1
	city_layer._show_inspect(Vector2i(30, 30))
	if inspect_popup._title_label and inspect_popup._title_label.text.contains("쥐불"):
		_log("  [PASS] 쥐불놀이 판정 성공: '%s'" % inspect_popup._title_label.text)
		total_passed += 1
	else:
		_log("  [FAIL] 쥐불놀이 판정 실패")

	# B. CitizenLayer 상설 마당 스팟 판정 검증
	_log("\n  (3-B) 상설 마당 스팟 (전기수, 그네/널뛰기, 아이들 마당) 검증")
	# 전기수 스팟 주입
	citizen_layer._jeongisu_spot = Vector2(15.5, 15.5)
	total_tests += 1
	city_layer._show_inspect(Vector2i(15, 15))
	if inspect_popup._title_label and inspect_popup._title_label.text.contains("전기수"):
		_log("  [PASS] 전기수 이야기판 판정 성공: '%s'" % inspect_popup._title_label.text)
		total_passed += 1
	else:
		_log("  [FAIL] 전기수 이야기판 판정 실패")

	# 그네/널뛰기 마당 주입 (여름철 -> 그네)
	city_layer.current_season = "여름"
	citizen_layer._play_yards = [{"x0": 25, "y0": 25}]
	total_tests += 1
	city_layer._show_inspect(Vector2i(25, 25))
	if inspect_popup._title_label and inspect_popup._title_label.text.contains("그네"):
		_log("  [PASS] 단오 그네 마당 판정 성공: '%s'" % inspect_popup._title_label.text)
		total_passed += 1
	else:
		_log("  [FAIL] 그네 마당 판정 실패: '%s'" % (inspect_popup._title_label.text if inspect_popup._title_label else "null"))

	# 널뛰기 마당 주입 (아래쪽 칸 y0+1)
	total_tests += 1
	city_layer._show_inspect(Vector2i(25, 26))
	if inspect_popup._title_label and inspect_popup._title_label.text.contains("널뛰기"):
		_log("  [PASS] 널뛰기 마당 판정 성공: '%s'" % inspect_popup._title_label.text)
		total_passed += 1
	else:
		_log("  [FAIL] 널뛰기 마당 판정 실패: '%s'" % (inspect_popup._title_label.text if inspect_popup._title_label else "null"))

	# 골목길 아이들 마당 주입
	citizen_layer._kid_yards = [{"x0": 35, "y0": 35}]
	total_tests += 1
	city_layer._show_inspect(Vector2i(35, 35))
	if inspect_popup._title_label and (inspect_popup._title_label.text.contains("딱지") or inspect_popup._title_label.text.contains("제기")):
		_log("  [PASS] 골목길 아이들 마당 판정 성공: '%s'" % inspect_popup._title_label.text)
		total_passed += 1
	else:
		_log("  [FAIL] 골목길 아이들 마당 판정 실패")

	# C. 퍼레이드 워커 (bull_parade, pungmul_band) 검증
	_log("\n  (3-C) 축제 퍼레이드 워커 살피기 태깅 검증")
	total_tests += 1
	var walker_entity: Dictionary = {
		"kind": "npc",
		"type": "bull_parade",
		"activity_type": "ACTIVITY_SSIREUM_CHAMPION"
	}
	var walker_data: Dictionary = InspectNarrativeGenerator.build_inspect_data(walker_entity)
	if walker_data.get("title", "").contains("천하장사"):
		_log("  [PASS] 황소 천하장사 워커 판정 성공: '%s'" % walker_data.get("title", ""))
		total_passed += 1
	else:
		_log("  [FAIL] 황소 천하장사 워커 판정 실패")

	total_tests += 1
	var pungmul_entity: Dictionary = {
		"kind": "npc",
		"type": "pungmul_band",
		"activity_type": "ACTIVITY_PUNGMUL"
	}
	var pungmul_data: Dictionary = InspectNarrativeGenerator.build_inspect_data(pungmul_entity)
	if pungmul_data.get("title", "").contains("풍물"):
		_log("  [PASS] 풍물패 워커 판정 성공: '%s'" % pungmul_data.get("title", ""))
		total_passed += 1
	else:
		_log("  [FAIL] 풍물패 워커 판정 실패")

	# -------------------------------------------------------------------------
	# 최종 결과 요약
	# -------------------------------------------------------------------------
	_log("\n=======================================================")
	_log("전체 테스트: %d | 통과: %d | 실패: %d" % [total_tests, total_passed, total_tests - total_passed])
	if total_passed == total_tests:
		_log(">>> [ALL PASS] 모든 세시풍속 살피기 시스템 검증을 완벽히 통과했습니다! <<<")
		_log("=======================================================")
		quit(0)
	else:
		_log(">>> [SOME FAILED] 일부 테스트가 실패했습니다. <<<")
		_log("=======================================================")
		quit(1)
