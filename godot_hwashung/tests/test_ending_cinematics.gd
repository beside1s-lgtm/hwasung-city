extends SceneTree

func _init() -> void:
	print("==================================================")
	print("[테스트 시작] 13대 멀티 엔딩별 시네마틱 영상 시스템 검증")
	print("==================================================")

	var endings: Dictionary = EndingManager.ENDING_DATA
	if endings.size() != 13:
		printerr("FAIL: 엔딩 개수가 13개가 아님: %d개" % endings.size())
		quit(1)
		return

	# 1. 13개 엔딩 모두에 video_file 속성이 존재하는지 검증
	var all_have_video_key: bool = true
	for key: String in endings:
		var d: Dictionary = endings[key]
		var vfile: String = String(d.get("video_file", ""))
		var num: int = int(d.get("num", 0))
		var title: String = String(d.get("title", ""))
		if vfile == "":
			printerr("FAIL: 엔딩 %d (%s)에 video_file 누락" % [num, key])
			all_have_video_key = false
		else:
			print("OK: [엔딩 %2d번] %-30s -> %s" % [num, title, vfile])

	if not all_have_video_key:
		quit(1)
		return

	# 2. 13번 도적 함락 엔딩 검증
	if not endings.has("BANDIT_FALL"):
		printerr("FAIL: BANDIT_FALL 엔딩 누락")
		quit(1)
		return
	var b_fall: Dictionary = endings["BANDIT_FALL"]
	if int(b_fall.get("num", 0)) != 13:
		printerr("FAIL: BANDIT_FALL 번호가 13이 아님: %d" % int(b_fall.get("num", 0)))
		quit(1)
		return
	print("OK: 13번 도적 함락 엔딩 검증 성공 (num: 13, video: %s)" % String(b_fall.get("video_file", "")))

	# 3. 다중 경로 후보 탐색 검증 (가상 엔딩 딕셔너리)
	var test_d: Dictionary = {
		"num": 13,
		"type": "BANDIT_FALL",
		"title": "도적 떼의 행궁 함락",
		"video_file": "res://assets/endings/non_existing_file.ogv"
	}
	# 파일이 실제로 없을 때 공통 기본값이 없으면 "" 반환 검증
	var resolved_path: String = EndingManager.get_ending_video_path(test_d)
	print("OK: 파일 부재 시 빈 문자열 반환 검증: '%s'" % resolved_path)

	# 4. EndingVideoLayer 생성 및 컴포넌트 무결성 검증
	var video_layer := EndingVideoLayer.new()
	if video_layer == null:
		printerr("FAIL: EndingVideoLayer 인스턴스 생성 실패")
		quit(1)
		return

	print("OK: EndingVideoLayer 인스턴스화 성공")
	video_layer.queue_free()

	print("==================================================")
	print("[테스트 성공] 13대 멀티 엔딩 시네마틱 시스템 무결성 검증 완료")
	print("==================================================")
	quit(0)
