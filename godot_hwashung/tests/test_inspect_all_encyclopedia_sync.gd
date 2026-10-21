extends SceneTree

# test_inspect_all_encyclopedia_sync.gd
# 살피기(InspectPopup)에서 인물, 건물 16종, 세시풍속/생활상 20종 모두 encyclopedia 파일이 반환되는지 전수 검증

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("=== 살피기 팝업 인물·건물·세시풍속 encyclopedia 전수 동기화 검증 시작 ===")

	var test_suites: Dictionary = {
		"인물 6종 (대표)": [
			"hong_daeyong", "chae_jegong", "jeong_yakyong", "baek_dongsu", "kim_hongdo", "sim_hwanji"
		],
		"건물 16종": [
			"haenggung", "seojangdae", "yeonmudae", "manseokgeo", "chukmanje",
			"patrol", "firefighter", "jinhulso", "hyanggyo", "gate",
			"hwahongmun", "namsumun", "jongnu", "cattle", "seodang", "market"
		],
		"세시풍속 및 생활상 20종": [
			"jwibul", "seokjeon", "kite", "bull_parade", "ganggang",
			"lion", "neolttwigi", "swing", "kids", "namsadang",
			"jeongisu", "farmer", "mason", "smith", "bobusang",
			"washer", "catholic", "drill", "pabal", "wonhaeng"
		]
	}

	var total_count: int = 0
	var success_count: int = 0
	var failed_keys: Array[String] = []

	for category: String in test_suites:
		var keys: Array = test_suites[category]
		print("\n--- 검사 카테고리: [%s] (%d개) ---" % [category, keys.size()])
		for k_raw in keys:
			var key: String = String(k_raw)
			total_count += 1
			var tex: Texture2D = InspectNarrativeGenerator.get_portrait(key)
			if tex == null:
				print("[FAIL] 텍스처 null 반환: %s" % key)
				failed_keys.append(key)
				continue

			var sz := tex.get_size()
			# encyclopedia 파일은 256x256 이상 (기존 48x48이나 80x80이 아님)
			if sz.x >= 200 and sz.y >= 200:
				success_count += 1
				print("  [PASS] %s -> 텍스처 크기: %s (encyclopedia 이미지 매핑 성공)" % [key, str(sz)])
			else:
				print("[FAIL] encyclopedia 에셋이 아닌 저해상도 텍스처: %s -> 크기: %s" % [key, str(sz)])
				failed_keys.append(key)

	print("\n=== 검증 종합 결과 ===")
	print("총 검사 키: %d개" % total_count)
	print("성공 키: %d개" % success_count)
	print("실패 키: %d개" % failed_keys.size())

	if failed_keys.is_empty():
		print("[ALL PASS] 인물, 건물 16종, 세시풍속 20종 모두 godot_hwashung/assets/encyclopedia/ 에셋으로 살피기 연동 완료!")
		quit(0)
	else:
		push_error("[TEST FAILED] 연동 실패 키: %s" % str(failed_keys))
		quit(1)
