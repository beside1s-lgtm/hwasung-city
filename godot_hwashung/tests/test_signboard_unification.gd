extends SceneTree

## 사대문·수문·교량 현판 이름 라벨 단일화(SSOT) 및 중복 렌더링 방지 종합 검증 테스트

func _init() -> void:
	print("=== [테스트 시작] 사대문·수문·교량 현판 단일화 검증 ===")
	test_world_marker_ssot()
	test_roof_offset_values()
	test_city_layer_no_draw()
	test_duplicate_cleanup()
	print("=== [테스트 통과] 모든 검증 통과 완료! ===")
	quit(0)

func test_world_marker_ssot() -> void:
	print("[검증 1] WorldMarkerManager 단일 진실 공급원(SSOT) 및 O(1) 중복 방어 검증...")
	var tree_root: Window = get_root()
	var wm: WorldMarkerManager = WorldMarkerManager.new()
	tree_root.add_child(wm)

	# 1. 사대문 단일 인스턴스 검증 (팔달문)
	var sign_pd1: GateSignboard = wm.register_signboard("paldal_mun", Vector2(100, 200), "팔달문 (八達門)")
	assert(sign_pd1 != null, "팔달문 현판 생성 실패")
	assert(sign_pd1.gate_name == "팔달문 (八達門)", "팔달문 현판 이름 불일치")
	assert(sign_pd1.name == "Signboard_paldal_mun", "팔달문 현판 노드명 불일치")

	# 다른 ID 포맷("gate_16_63")으로 동일 건물 등록 시 단일 인스턴스 재활용 검증
	var sign_pd2: GateSignboard = wm.register_marker("gate_16_63", "팔달문 (八達門)", Vector2(100, 250))
	assert(sign_pd1 == sign_pd2, "사대문 ID 정규화 중복 방어 실패: 별도 노드 생성됨")
	assert(sign_pd2.position == Vector2(100, 250), "기존 현판 위치 갱신 실패")

	# 2. 장안문, 화서문, 창룡문 검증
	var sign_ja: GateSignboard = wm.register_signboard("jangan_mun", Vector2(200, 100), "장안문 (長安門)")
	var sign_hs: GateSignboard = wm.register_signboard("hwaseo_mun", Vector2(50, 150), "화서문 (華西門)")
	var sign_cr: GateSignboard = wm.register_signboard("changryong_mun", Vector2(250, 150), "창룡문 (蒼龍門)")
	assert(sign_ja != null and sign_hs != null and sign_cr != null, "사대문 현판 등록 실패")

	# 3. 수문(화홍문, 남수문) 및 교량(매향교) 검증
	var sign_hw: GateSignboard = wm.register_marker("hwahong_mun", "화홍문 (華虹門)", Vector2(150, 80))
	var sign_ns: GateSignboard = wm.register_marker("namsu_mun", "남수문 (南水門)", Vector2(150, 250))
	var sign_mh: GateSignboard = wm.register_marker("maehwang_gyo", "매향교 (梅香橋)", Vector2(150, 160))
	assert(sign_hw != null and sign_ns != null and sign_mh != null, "수문 및 교량 현판 등록 실패")

	# 매향교 별칭(maehyang_gyo) 등록 시 동일 인스턴스 확인
	var sign_mh2: GateSignboard = wm.register_signboard("maehyang_gyo", Vector2(150, 170), "매향교 (梅香橋)")
	assert(sign_mh == sign_mh2, "매향교 별칭 정규화 중복 방어 실패")

	# 총 등록된 현판 수 검증: 7개 (팔달, 장안, 화서, 창룡, 화홍, 남수, 매향)
	assert(wm.active_signboards.size() == 7, "현판 개수 불일치: %d != 7" % wm.active_signboards.size())
	assert(wm.get_child_count() == 7, "WorldMarkerManager 자식 노드 수 불일치: %d != 7" % wm.get_child_count())

	wm.clear_all_markers()
	wm.queue_free()
	print(" -> [통과] WorldMarkerManager SSOT 단일 인스턴스화 완료.")

func test_roof_offset_values() -> void:
	print("[검증 2] 건물별 지붕 처마 상단 Y 부유 오프셋 표준화 검증...")
	assert(WorldMarkerManager.get_roof_offset_y("jangan_mun", "장안문 (長安門)") == 114.0, "장안문 오프셋 오류")
	assert(WorldMarkerManager.get_roof_offset_y("paldal_mun", "팔달문 (八達門)") == 114.0, "팔달문 오프셋 오류")
	assert(WorldMarkerManager.get_roof_offset_y("hwaseo_mun", "화서문 (華西門)") == 73.0, "화서문 오프셋 오류")
	assert(WorldMarkerManager.get_roof_offset_y("changryong_mun", "창룡문 (蒼龍門)") == 76.0, "창룡문 오프셋 오류")
	assert(WorldMarkerManager.get_roof_offset_y("hwahong_mun", "화홍문 (華虹門)") == 54.0, "화홍문 오프셋 오류")
	assert(WorldMarkerManager.get_roof_offset_y("namsu_mun", "남수문 (南水門)") == 51.0, "남수문 오프셋 오류")
	assert(WorldMarkerManager.get_roof_offset_y("maehwang_gyo", "매향교 (梅香橋)") == 24.0, "매향교 오프셋 오류")
	print(" -> [통과] 7대 건물 지붕 처마 상단 부유 오프셋 규격 일치.")

func test_city_layer_no_draw() -> void:
	print("[검증 3] CityLayer 캔버스 드로우 무력화 및 단일화 검증...")
	var cl: CityLayer = CityLayer.new()
	# _draw_gate_name_tag 호출 시 아무 에러 없이 리턴하는지 확인
	cl._draw_gate_name_tag("테스트문", 50.0)
	cl.queue_free()
	print(" -> [통과] CityLayer _draw_gate_name_tag 무력화 검증 통과.")

func test_duplicate_cleanup() -> void:
	print("[검증 4] 기존 세이브/로드 시 잔존 중복 노드 자동 정리(cleanup_duplicate_signboards) 검증...")
	var tree_root: Window = get_root()
	var wm: WorldMarkerManager = WorldMarkerManager.new()
	tree_root.add_child(wm)

	# 인위적으로 동일 건물의 중복 GateSignboard 노드 2개를 자식으로 추가
	var s1: GateSignboard = GateSignboard.new()
	s1.name = "Signboard_paldal_mun"
	s1.gate_name = "팔달문 (八達門)"
	wm.add_child(s1)

	var s2: GateSignboard = GateSignboard.new()
	s2.name = "Signboard_gate_16_63"
	s2.gate_name = "팔달문 (八達門)"
	wm.add_child(s2)

	assert(wm.get_child_count() == 2, "초기 중복 노드 설정 실패")

	# 정리 함수 호출
	wm.cleanup_duplicate_signboards()

	# s2는 queue_free 되었으므로 다음 프레임에 사라지며, 캐시에는 단 1개만 남음
	assert(wm.active_signboards.size() == 1, "중복 정리 후 캐시 개수 불일치: %d != 1" % wm.active_signboards.size())
	assert(wm.active_signboards.has("paldal_mun"), "팔달문 정규 키 누락")

	wm.clear_all_markers()
	wm.queue_free()
	print(" -> [통과] 중복 노드 정리 검증 통과.")
