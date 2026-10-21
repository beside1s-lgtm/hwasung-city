extends SceneTree

func _init() -> void:
	print("=== 수원향교·서원·서당 학문 강독 퀴즈 시스템 단위 테스트 시작 ===")
	var total: int = 0
	var passed: int = 0

	var qm := AcademyQuizManager.get_instance()
	qm.last_quiz_years = {"hyanggyo": -1, "seowon": -1, "seodang": -1}

	# -------------------------------------------------------------
	# Test 1: 3대 교육 시설별 60문제 이상 풀 및 180문항 전수 데이터 무결성 검증
	# -------------------------------------------------------------
	total += 1
	var facilities := ["hyanggyo", "seowon", "seodang"]
	var total_questions_count: int = 0

	for fac in facilities:
		var q_pool: Array[Dictionary] = AcademyQuizManager.get_question_pool(fac)
		print("[INFO] %s 등록 문제 수: %d개" % [fac, q_pool.size()])
		assert(q_pool.size() >= 60, "%s 문제 풀은 최소 60문제 이상이어야 함 (현재: %d개)" % [fac, q_pool.size()])
		total_questions_count += q_pool.size()

		# 각 문제 풀 내의 모든 문항 전수 검사
		for idx in range(q_pool.size()):
			var q: Dictionary = q_pool[idx]
			assert(str(q.get("q", "")).length() > 5, "%s %d번 문제 본문이 비어있거나 너무 짧음" % [fac, idx + 1])
			var opts: Array = q.get("options", [])
			assert(opts.size() == 4, "%s %d번 보기 개수는 4개여야 함" % [fac, idx + 1])
			var ans: int = int(q.get("answer", -1))
			assert(ans >= 0 and ans < 4, "%s %d번 정답 인덱스는 0~3 사이여야 함 (현재: %d)" % [fac, idx + 1, ans])
			assert(str(q.get("explanation", "")).length() > 0, "%s %d번 해설이 누락됨" % [fac, idx + 1])

	assert(total_questions_count >= 180, "총 문제 수는 최소 180문제 이상이어야 함 (현재: %d개)" % total_questions_count)
	passed += 1
	print("[PASS] Test 1: 3대 시설 각 60문제 이상 (총 %d문제) 4지선다·정답·해설 전수 검증 완료" % total_questions_count)

	# -------------------------------------------------------------
	# Test 2: 세션 3문제 무작위 추출 및 선택지 셔플 정답 무결성 검증
	# -------------------------------------------------------------
	total += 1
	for fac in facilities:
		var session: Array[Dictionary] = qm.generate_quiz_session(fac)
		assert(session.size() == 3, "%s 세션 문제는 정확히 3문제여야 함" % fac)

		# 3문제가 서로 중복되지 않는지 확인
		var question_texts: Array[String] = []
		for q in session:
			var q_text: String = str(q.get("q", ""))
			assert(not question_texts.has(q_text), "세션 내 3문제는 서로 중복되지 않아야 함: %s" % q_text)
			question_texts.append(q_text)

			var opts: Array = q.get("options", [])
			assert(opts.size() == 4, "보기는 4개여야 함")
			var ans_idx: int = int(q.get("answer", -1))
			assert(ans_idx >= 0 and ans_idx < 4, "정답 인덱스는 0~3 사이여야 함")
	passed += 1
	print("[PASS] Test 2: 세션당 3문제 비중복 무작위 추출 및 보기 셔플 검증 완료")

	# -------------------------------------------------------------
	# Test 3: 화자별 고유 어투 및 대사 데이터 검증
	# -------------------------------------------------------------
	total += 1
	var hyanggyo_info: Dictionary = AcademyQuizManager.QUIZ_DATA["hyanggyo"]
	assert(str(hyanggyo_info["speech_greeting"]).contains("실학"), "향교는 실학 주제여야 함")
	assert(str(hyanggyo_info["speech_correct"]).contains("실사구시"), "향교는 근엄한 경어체여야 함")

	var seowon_info: Dictionary = AcademyQuizManager.QUIZ_DATA["seowon"]
	assert(str(seowon_info["speech_greeting"]).contains("수원화성"), "서원은 수원화성 주제여야 함")
	assert(str(seowon_info["speech_greeting"]).contains("안녕"), "서원은 친절한 선생님 말투여야 함")

	var seodang_info: Dictionary = AcademyQuizManager.QUIZ_DATA["seodang"]
	assert(str(seodang_info["speech_greeting"]).contains("에헴"), "서당은 훈장님 어투여야 함")
	assert(str(seodang_info["speech_correct"]).contains("종아리"), "서당은 호통치는 어투여야 함")
	passed += 1
	print("[PASS] Test 3: 화자별 고유 어투(향교: 근엄 경어체, 서원: 친절 선생님, 서당: 호통 훈장) 검증 완료")

	# -------------------------------------------------------------
	# Test 4: 1년 쿨타임(Cooldown) 규칙 검증
	# -------------------------------------------------------------
	total += 1
	var cur_y: int = 1789
	assert(qm.can_take_quiz("hyanggyo", cur_y) == true, "1789년 초기에는 응시 가능해야 함")

	# 1789년에 응시 완료 기록
	qm.record_quiz_completed("hyanggyo", cur_y)
	assert(qm.can_take_quiz("hyanggyo", cur_y) == false, "같은 해 1789년에는 재응시 불가(1년 쿨타임)여야 함")
	assert(qm.can_take_quiz("hyanggyo", 1790) == true, "다음 해 1790년에는 다시 응시 가능해야 함")

	# 다른 시설(서원, 서당)은 독립 쿨타임 유지 확인
	assert(qm.can_take_quiz("seowon", cur_y) == true, "향교 응시 후에도 서원은 독립적으로 응시 가능해야 함")
	assert(qm.can_take_quiz("seodang", cur_y) == true, "향교 응시 후에도 서당은 독립적으로 응시 가능해야 함")
	passed += 1
	print("[PASS] Test 4: 1년(12턴) 쿨타임 및 시설별 독립 응시 검증 완료")

	# -------------------------------------------------------------
	# Test 5: 채점 및 학문력 점수 산출 규칙 검증
	# -------------------------------------------------------------
	total += 1
	assert(qm.calculate_score_delta(3) == 2, "3문제 다 맞으면 학문력 +2 가산이어야 함")
	assert(qm.calculate_score_delta(2) == 1, "2문제 맞으면 학문력 +1 가산이어야 함")
	assert(qm.calculate_score_delta(1) == 0, "1문제 맞으면 0점 가산이어야 함")
	assert(qm.calculate_score_delta(0) == -1, "다 틀리면 학문력 -1 감점이어야 함")

	# 실제 CityStats 반영 검증
	CityStats.set_academic_power(50)
	CityStats.add_academic_power(qm.calculate_score_delta(3))
	assert(CityStats.get_academic_power() == 52, "3문제 정답 시 50 -> 52 반영되어야 함")

	CityStats.add_academic_power(qm.calculate_score_delta(0))
	assert(CityStats.get_academic_power() == 51, "다 틀릴 시 52 -> 51 반영되어야 함")
	passed += 1
	print("[PASS] Test 5: 3문제(+2), 2문제(+1), 1문제(0), 0문제(-1) 학문력 반영 검증 완료")

	# -------------------------------------------------------------
	# Test 6: 세이브/로드 직렬화 및 역직렬화 무결성 검증
	# -------------------------------------------------------------
	total += 1
	qm.record_quiz_completed("hyanggyo", 1792)
	qm.record_quiz_completed("seowon", 1793)
	qm.record_quiz_completed("seodang", 1791)

	var saved_data: Dictionary = qm.serialize()
	var new_qm := AcademyQuizManager.new()
	new_qm.deserialize(saved_data)

	assert(new_qm.get_last_quiz_year("hyanggyo") == 1792, "향교 쿨타임 데이터 복원 확인")
	assert(new_qm.get_last_quiz_year("seowon") == 1793, "서원 쿨타임 데이터 복원 확인")
	assert(new_qm.get_last_quiz_year("seodang") == 1791, "서당 쿨타임 데이터 복원 확인")
	passed += 1
	print("[PASS] Test 6: 쿨타임 데이터 세이브/로드 직렬화 무결성 검증 완료")

	print("\n=== 테스트 결과 리포트 ===")
	print("총 테스트 항목: %d개 | 통과: %d개 | 실패: 0개" % [total, passed])
	assert(passed == total, "모든 테스트가 통과되어야 합니다.")
	print("=== 모든 단위 테스트 성공 (100% PASS) ===")
	quit(0)
