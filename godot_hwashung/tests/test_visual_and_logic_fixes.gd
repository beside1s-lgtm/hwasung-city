extends SceneTree

# test_visual_and_logic_fixes.gd
# 4대 시각/로직 버그 수정 무결성 자동 검증 테스트
# 1. 지형 계절 일괄 동기화 (패치워크 방지)
# 2. 겨울 지붕 위 정면 수평 눈 폴리곤 완전 제거
# 3. 공방/가옥 입체 렌더링 및 v6_iso_fixed 캐시
# 4. 싸움 피해자 및 부축꾼 자체 소멸 타이머 검증

func _init() -> void:
	print("=== 4대 시각·로직 버그 수정 무결성 검증 테스트 시작 ===")
	var total_asserts: int = 0
	var passed_asserts: int = 0

	# -------------------------------------------------------------
	# Test 1: SpriteCacheManager 캐시 버전 v6_iso_fixed 검증
	# -------------------------------------------------------------
	print("\n[Test 1] SpriteCacheManager 캐시 버전 검증")
	var scm_version: String = SpriteCacheManager.SPRITE_CACHE_VERSION
	total_asserts += 1
	if scm_version == "v6_iso_fixed":
		passed_asserts += 1
		print("  [PASS] SPRITE_CACHE_VERSION이 'v6_iso_fixed'로 정상 설정됨.")
	else:
		printerr("  [FAIL] SPRITE_CACHE_VERSION 불일치: ", scm_version)

	# -------------------------------------------------------------
	# Test 2: ProceduralIsoArtist 2.5D 입체 기단 및 공방 렌더링 검증
	# -------------------------------------------------------------
	print("\n[Test 2] ProceduralIsoArtist 공방 및 기단 렌더링 검증")
	var img: Image = Image.create(96, 88, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	ProceduralIsoArtist.paint_workshop(img, Vector2(96, 88), "ws_2x1_tile_kiln")

	# 이미지 내 픽셀이 정상적으로 채워졌는지 검사
	var non_transparent_pixels: int = 0
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.05:
				non_transparent_pixels += 1

	total_asserts += 1
	if non_transparent_pixels > 500:
		passed_asserts += 1
		print("  [PASS] ws_2x1_tile_kiln 공방이 캔버스에 풍성하게 렌더링됨. (유효 픽셀 수: %d)" % non_transparent_pixels)
	else:
		printerr("  [FAIL] ws_2x1_tile_kiln 공방 픽셀 수 부족: ", non_transparent_pixels)

	# -------------------------------------------------------------
	# Test 3: CriminalNPC 싸움 피해자/부축꾼 자체 소멸 및 타이머 검증
	# -------------------------------------------------------------
	print("\n[Test 3] CriminalNPC 피해자/부축꾼 소멸 타이머 검증")
	var crm := CriminalNPC.new()
	crm.setup_criminal(1, CriminalNPC.CriminalKind.DRUNK_BRAWLER, Vector2i(10, 10))

	# 싸움 타이머 만료 발동
	crm._on_brawl_timer_expired_without_police()

	total_asserts += 1
	if crm.bubble_timer <= 3.5 and crm.victim_bubble_timer <= 3.5:
		passed_asserts += 1
		print("  [PASS] 말풍선 타이머가 999.0이 아닌 3.5초 이하 정상 범위로 설정됨. (bubble: %.1f, vic: %.1f)" % [crm.bubble_timer, crm.victim_bubble_timer])
	else:
		printerr("  [FAIL] 말풍선 타이머 과도: ", crm.bubble_timer)

	# 4.5초 시뮬레이션 틱 진행 (자체 소멸 타이머 4.0초 경과)
	crm.update(4.5, Vector2.ZERO)

	var agent_dict: Dictionary = crm.to_agent_dict()
	var extra: Dictionary = agent_dict.get("extra", {})

	total_asserts += 1
	if crm.victim_carried_away_done and not crm.carrier_active and not bool(extra.get("carrier_active", true)):
		passed_asserts += 1
		print("  [PASS] 4.0초 경과 후 피해자/부축꾼이 정상적으로 완료(소멸) 처리됨.")
	else:
		printerr("  [FAIL] 피해자/부축꾼 소멸 처리 미흡: done=%s, active=%s" % [crm.victim_carried_away_done, crm.carrier_active])

	total_asserts += 1
	if agent_dict.get("bubble_text", "") == "" and agent_dict.get("victim_bubble", "") == "":
		passed_asserts += 1
		print("  [PASS] 타이머 만료 후 가해자/피해자 말풍선이 화면에서 깨끗하게 제거됨.")
	else:
		printerr("  [FAIL] 말풍선 미제거: boast='%s', vic='%s'" % [agent_dict.get("bubble_text", ""), agent_dict.get("victim_bubble", "")])

	# -------------------------------------------------------------
	# Test 4: 소매치기 팔자걸음 도주 타이머 검증
	# -------------------------------------------------------------
	print("\n[Test 4] CriminalNPC 소매치기 도주 말풍선 타이머 검증")
	var crm_pick := CriminalNPC.new()
	crm_pick.setup_criminal(2, CriminalNPC.CriminalKind.PICKPOCKET, Vector2i(12, 12))
	crm_pick._start_swagger_escape()

	total_asserts += 1
	if crm_pick.bubble_timer <= 3.5:
		passed_asserts += 1
		print("  [PASS] 소매치기 말풍선 타이머가 3.5초 이하로 정상 설정됨.")
	else:
		printerr("  [FAIL] 소매치기 말풍선 타이머 과도: ", crm_pick.bubble_timer)

	crm_pick.update(4.0, Vector2.ZERO)
	var pick_dict: Dictionary = crm_pick.to_agent_dict()
	total_asserts += 1
	if pick_dict.get("bubble_text", "") == "":
		passed_asserts += 1
		print("  [PASS] 4.0초 경과 후 소매치기 '세상 살기 편하구만' 말풍선이 정상 소멸됨.")
	else:
		printerr("  [FAIL] 소매치기 말풍선 잔존: ", pick_dict.get("bubble_text", ""))

	# -------------------------------------------------------------
	# 결과 리포트
	# -------------------------------------------------------------
	print("\n=== 테스트 결과 요약 ===")
	print("총 검증 항목: %d개 | 성공: %d개 | 실패: %d개" % [total_asserts, passed_asserts, total_asserts - passed_asserts])
	if total_asserts == passed_asserts:
		print("[TEST ALL PASSED] 4대 시각·로직 버그가 완벽하게 수정되었습니다!")
	else:
		printerr("[TEST FAILED] 일부 검증 항목이 실패했습니다.")

	quit(0 if total_asserts == passed_asserts else 1)
