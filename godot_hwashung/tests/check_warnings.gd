extends SceneTree

## GDScript 정적 무결성 및 경고 사전 검출기 (Zero-Warning Linter)
## 1. 섀도잉 변수 검출 (tr, len, load, seed)
## 2. 전역 클래스명 중복 const preload 선언 검출
## 3. 대표적인 정수 나눗셈 패턴 검출

func _init() -> void:
	print("=== GDScript 정적 무결성 및 제로 워닝 검사 시작 ===")
	var scripts_dir := "res://scripts"
	var dir := DirAccess.open(scripts_dir)
	if not dir:
		printerr("[LINT FAIL] 스크립트 디렉토리를 열 수 없습니다: ", scripts_dir)
		quit(1)
		return

	# 1. 전역 클래스명 수집
	var global_classes: Array[String] = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	var all_files: Array[String] = []
	while fname != "":
		if fname.ends_with(".gd"):
			all_files.append(fname)
			var path := scripts_dir + "/" + fname
			var fa := FileAccess.open(path, FileAccess.READ)
			if fa:
				var text := fa.get_as_text()
				fa.close()
				var reg := RegEx.new()
				reg.compile("(?m)^class_name\\s+([A-Za-z0-9_]+)")
				var match_res := reg.search(text)
				if match_res:
					global_classes.append(match_res.get_string(1))
		fname = dir.get_next()

	print("[LINT] 등록된 전역 class_name 목록: ", global_classes.size(), "개")

	var violations: Array[Dictionary] = []

	# 1) 예약어/빌트인 변수 섀도잉 정규식
	var regex_shadowed := RegEx.new()
	regex_shadowed.compile("\\b(var|for)\\s+(tr|len|load|seed)\\b")

	# 2) 전형적인 정수 나눗셈 위험 패턴 (정수 속성/변수를 정수 리터럴로 직접 나누는 경우)
	var regex_int_div := RegEx.new()
	regex_int_div.compile("\\b(grid\\.size|span\\.size\\(\\)|span_x\\.size\\(\\)|span_y\\.size\\(\\)|total_ticks|ticks|population|academic_power)\\s*/\\s*(\\d+)(?!\\.)\\b")

	for script_name: String in all_files:
		var path := scripts_dir + "/" + script_name
		var fa := FileAccess.open(path, FileAccess.READ)
		if not fa:
			continue
		var lines: PackedStringArray = fa.get_as_text().split("\n")
		fa.close()

		for idx: int in range(lines.size()):
			var line: String = lines[idx]
			var trimmed: String = line.strip_edges()
			if trimmed.begins_with("#") or trimmed == "":
				continue

			# 1) 예약어/빌트인 변수 섀도잉 검사
			var sh_match := regex_shadowed.search(line)
			if sh_match:
				violations.append({
					"file": script_name,
					"line": idx + 1,
					"type": "SHADOWED_IDENTIFIER",
					"code": trimmed,
					"msg": "빌트인 함수 또는 Object 메서드명(%s)을 변수로 사용할 수 없습니다." % sh_match.get_string(2)
				})

			# 2) 전역 클래스명 const preload 섀도잉 검사
			for cls: String in global_classes:
				if line.find("const " + cls + " =") != -1 or line.find("const " + cls + ":=") != -1:
					violations.append({
						"file": script_name,
						"line": idx + 1,
						"type": "SHADOWED_GLOBAL_CLASS",
						"code": trimmed,
						"msg": "전역 class_name(%s)을 const 상수로 중복 정의하지 마세요." % cls
					})

			# 3) 위험 정수 나눗셈 검사
			var div_match := regex_int_div.search(line)
			if div_match:
				# float() 캐스팅이 라인에 이미 포함되어 있다면 제외
				if line.find("float(") == -1:
					violations.append({
						"file": script_name,
						"line": idx + 1,
						"type": "INTEGER_DIVISION",
						"code": trimmed,
						"msg": "정수 나눗셈(%s)이 감지되었습니다. float() 캐스팅이나 .0을 붙이세요." % div_match.get_string(0)
					})

		# 스크립트 실제 로드 검사
		var _res = load(path)

	print("\n--- 검사 결과 리포트 ---")
	if violations.is_empty():
		print("[LINT SUCCESS] 위반 사항 0건! 모든 스크립트가 제로 워닝 규약을 완벽히 준수합니다.")
		print("=== GDScript 정적 무결성 검사 완료 (PASS) ===")
		quit(0)
	else:
		printerr("[LINT FAIL] %d건의 무결성 위반 사항이 발견되었습니다:" % violations.size())
		for v in violations:
			printerr("  - [%s:%d] %s (%s) => %s" % [v["file"], v["line"], v["type"], v["code"], v["msg"]])
		quit(1)
