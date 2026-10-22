extends SceneTree

## 공방(수공업 구획) 살피기(Inspect) 팝업 단위 테스트
## - D-2 분기에서 각 공방 종류가 올바른 타이틀로 판별되는지 검증
## - 저잣거리(com) 존은 여전히 "저잣거리" 분기로 처리되는지 역회귀 확인

func _init() -> void:
	print("=== 공방 살피기 단위 테스트 시작 ===")
	var _gen := InspectNarrativeGenerator.new()

	var all_pass: bool = true

	# ── 테스트 케이스 정의 ──────────────────────────────────────────────
	# [entity 딕셔너리, 기대값(타이틀에 포함될 문자열), 케이스 이름]
	var test_cases: Array[Dictionary] = [
		{
			"entity": {"zone": "ind", "building": "ind_1", "ws_asset_id": "ws_1x1_leather", "trade": "leather"},
			"expect":  "가죽",
			"name":    "가죽 공방"
		},
		{
			"entity": {"zone": "ind", "building": "ind_1", "ws_asset_id": "ws_2x1_blacksmith", "trade": "smith"},
			"expect":  "대장간",
			"name":    "야조소 대장간"
		},
		{
			"entity": {"zone": "ind", "building": "ind_1", "ws_asset_id": "ws_1x1_carpenter", "trade": "carpenter"},
			"expect":  "목공",
			"name":    "목공방"
		},
		{
			"entity": {"zone": "ind", "building": "ind_1", "ws_asset_id": "ws_2x1_stonemason", "trade": "stonemason"},
			"expect":  "석재",
			"name":    "석재 가공소"
		},
		{
			"entity": {"zone": "ind", "building": "ind_1", "ws_asset_id": "ws_2x1_dyeing", "trade": "dyeing"},
			"expect":  "염색",
			"name":    "천연 염색 공방"
		},
		{
			"entity": {"zone": "ind", "building": "ind_1", "ws_asset_id": "ws_1x1_metalcraft", "trade": "brass"},
			"expect":  "방짜",
			"name":    "방짜유기 공방"
		},
		{
			"entity": {"zone": "ind", "building": "ind_1", "ws_asset_id": "ws_2x2_ceramics", "trade": "onggi"},
			"expect":  "옹기",
			"name":    "전통 옹기 가마"
		},
		{
			"entity": {"zone": "ind", "building": "ind_1", "ws_asset_id": "ws_2x1_tile_kiln", "trade": "tile_kiln"},
			"expect":  "와요",
			"name":    "와요 기와·벽돌 가마소"
		},
		{
			"entity": {"zone": "ind", "building": "ind_1", "ws_asset_id": "ws_1x1_bamboo", "trade": "bamboo"},
			"expect":  "죽세",
			"name":    "죽세 공방"
		},
		{
			"entity": {"zone": "ind", "building": "ind_1", "ws_asset_id": "ws_1x1_hanji", "trade": "hanji"},
			"expect":  "한지",
			"name":    "한지 공방"
		},
		{
			"entity": {"zone": "ind", "building": "ind_1", "ws_asset_id": "ws_2x1_shoemaker", "trade": "shoe"},
			"expect":  "갖신",
			"name":    "갖신방"
		},
		{
			"entity": {"zone": "ind", "building": "ind_1", "ws_asset_id": "ws_2x2_lumber_machinery", "trade": ""},
			"expect":  "축성",
			"name":    "축성 기계 공방"
		},
		{
			"entity": {"zone": "ind", "building": "ind_1", "ws_asset_id": "ws_3x3_royal_arsenal", "trade": ""},
			"expect":  "군기",
			"name":    "군기시"
		},
		# 공방이지만 ws_asset_id 없는 경우 → 포괄 fallback
		{
			"entity": {"zone": "ind", "building": "ind_1", "trade": "gat"},
			"expect":  "갓방",
			"name":    "갓방 (trade only)"
		},
		# ── 역회귀: com 존 저잣거리는 여전히 저잣거리 분기로 처리 ──
		{
			"entity": {"zone": "com", "building": "com_1", "trade": "smith"},
			"expect":  "저잣거리",
			"name":    "[역회귀] 저잣거리 대장간 (com 존)"
		},
	]

	for tc: Dictionary in test_cases:
		var tc_entity: Dictionary = tc["entity"]
		var tc_expect: String     = tc["expect"]
		var tc_name: String       = tc["name"]
		var result: Dictionary = InspectNarrativeGenerator.build_inspect_data(tc_entity)
		var title: String = str(result.get("title", ""))
		if title.contains(tc_expect):
			print("  [PASS] %s => \"%s\"" % [tc_name, title])
		else:
			printerr("  [FAIL] %s => 기대: \"%s\" 포함, 실제: \"%s\"" % [tc_name, tc_expect, title])
			all_pass = false

	print("\n--- 테스트 결과 ---")
	if all_pass:
		print("[SUCCESS] 공방 살피기 전체 %d건 PASS" % test_cases.size())
		print("=== 공방 살피기 단위 테스트 완료 (PASS) ===")
		quit(0)
	else:
		printerr("[FAIL] 일부 테스트 실패")
		quit(1)
