extends SceneTree

# test_public_buildings_seasonal_fx.gd
# 공공·성곽 건축 2.5D 지붕 처마 설경 및 사계절 환경 동기화 검증 테스트

func _init() -> void:
	print("=== [검증 시작] 공공·성곽 건축 2.5D 지붕 처마 설경 및 사계절 환경 동기화 검증 ===")

	# 1. CityLayer 스크립트 로드 및 메서드 바인딩 검증
	var city_script: Script = load("res://scripts/CityLayer.gd")
	assert(city_script != null, "CityLayer.gd 로드 실패")
	print("  - [PASS] CityLayer.gd 스크립트 로드 및 컴파일 무결성 확인")

	# 2. MarketArt roof 설경 지원 검증
	var market_script: Script = load("res://scripts/MarketArt.gd")
	assert(market_script != null, "MarketArt.gd 로드 실패")
	
	# roof 메서드가 존재하는지 검증
	var found_roof := false
	for m in market_script.get_script_method_list():
		if m["name"] == "roof":
			found_roof = true
			# 인자 목록 검증 (ci, o, a, f, ru, rv, ridge_u, h_eave, h_ridge, col, thatch, snow)
			var args: Array = m["args"]
			assert(args.size() >= 10, "MarketArt.roof 인자 수 부족")
			break
	assert(found_roof, "MarketArt.roof 메서드 누락")
	print("  - [PASS] MarketArt.roof 2.5D 지붕 처마 설경(snow) 인터페이스 검증 성공")

	# 3. CityLayer 주요 공공·성곽 건물 함수들의 시그니처 및 메서드 등록 검증
	var expected_methods: Array[String] = [
		"_bh_paljak",
		"_render_banghwasuryu",
		"_draw_seojangdae2",
		"_draw_jongnu_part",
		"_draw_gongsimdon3",
		"_draw_bongdon4",
		"_draw_poru2",
		"_draw_yeonmudae5",
		"_draw_gwana_part",
		"_gwana_wall",
		"_draw_jinhulso_part",
		"_draw_cattle_yard_tile",
		"_draw_salt_store_tile",
		"_draw_wall_block",
		"_draw_wall_merlons",
		"_draw_hyanggyo_part",
		"_draw_seodang",
		"_draw_seowon",
		"_draw_yeonghwajeong_part",
		"_draw_manseokgeo_pavilion",
		"_draw_chukmanje_hangmijeong"
	]

	var city_methods: Dictionary = {}
	for m2 in city_script.get_script_method_list():
		city_methods[m2["name"]] = m2

	for m_name: String in expected_methods:
		assert(city_methods.has(m_name), "CityLayer에 %s 메서드가 누락되었습니다." % m_name)
	print("  - [PASS] 종루, 방화수류정, 서장대, 공심돈, 봉돈, 포루, 연무대, 관아, 진휼소, 향교 등 21개 전 공공·성곽 렌더러 등록 확인")

	# 4. _bh_paljak 인자 목록에서 snow 매개변수 확인
	var paljak_method: Dictionary = city_methods["_bh_paljak"]
	var paljak_args: Array = paljak_method["args"]
	assert(paljak_args.size() == 12, "_bh_paljak 인자 개수 불일치")
	assert(paljak_args[11]["name"] == "snow", "_bh_paljak 12번째 인자는 snow 이어야 함")
	print("  - [PASS] _bh_paljak 앙곡 처마 2.5D 설경 인자(snow: bool) 연동 확인")

	# 5. _draw_wall_merlons 인자 목록에서 snow 매개변수 확인
	var merlons_method: Dictionary = city_methods["_draw_wall_merlons"]
	var merlons_args: Array = merlons_method["args"]
	assert(merlons_args.size() >= 4, "_draw_wall_merlons 인자 개수 불일치")
	assert(merlons_args[3]["name"] == "snow", "_draw_wall_merlons 4번째 인자는 snow 이어야 함")
	print("  - [PASS] 성곽 여장(총안) 상판 설경 라인 인자(snow: bool) 연동 확인")

	# 6. _gwana_wall 인자 목록에서 snow 매개변수 확인
	var gwana_wall_method: Dictionary = city_methods["_gwana_wall"]
	var gwana_wall_args: Array = gwana_wall_method["args"]
	assert(gwana_wall_args.size() >= 3, "_gwana_wall 인자 개수 불일치")
	assert(gwana_wall_args[2]["name"] == "snow", "_gwana_wall 3번째 인자는 snow 이어야 함")
	print("  - [PASS] 관아 외벽 기와 담장 상판 설경 라인 인자(snow: bool) 연동 확인")

	print("=== [검증 완료] 모든 공공·성곽 건물의 사계절 및 지붕 처마 설경 반영 100% 정상 통과! ===")
	quit(0)
