extends SceneTree

## [화면 확대 축소 무관 목적 행동 NPC 및 장면 상시 노출 검증 테스트]
## 서당, 놀이판, 세시풍속, 네임드, 특수상황, 군사훈련, 전투, 도둑과 병졸, 화재진압은 항상 보이고,
## 단순 농부, 단순 배회 백성, 상인만 원거리 축소 시 줄어드는지 검증합니다.

func _init() -> void:
	print("=== 목적 행동 NPC 상시 노출 및 일반 배경 NPC 축소 검증 시작 ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var root_node := Node2D.new()
	root_node.name = "TestRoot"
	root.add_child(root_node)

	var cl := CitizenLayer.new()
	root_node.add_child(cl)

	# -------------------------------------------------------------
	# 1. _is_special_or_event_entity 판정 무결성 전수 검증
	# -------------------------------------------------------------
	print("\n[TEST 1] _is_special_or_event_entity 카테고리별 판정 검증")

	# A. 항상 보여야 하는 대상들
	var purpose_agents: Array[Dictionary] = [
		{"type": "named_jeong_yakyong", "desc": "네임드 인물"},
		{"type": "seodang_teacher", "desc": "서당 훈장"},
		{"type": "seodang_student", "desc": "서당 학동"},
		{"type": "yusaeng", "desc": "향교/서원 유생"},
		{"type": "scholar", "desc": "선비/학자"},
		{"type": "ssireum", "desc": "단오 씨름꾼"},
		{"type": "juldagi", "desc": "줄다리기 무리"},
		{"type": "taekkyeon", "desc": "택견꾼"},
		{"type": "talchum", "desc": "탈춤 광대"},
		{"type": "kites", "desc": "연날리기"},
		{"type": "paengi", "desc": "팽이치기 아이"},
		{"type": "neolttwigi", "desc": "널뛰기"},
		{"type": "swing", "desc": "그네"},
		{"type": "sandang", "is_plaza_event": true, "desc": "사당패 광대"},
		{"type": "pungmul_band", "desc": "풍물패"},
		{"type": "bull_parade", "desc": "우시장 소 퍼레이드"},
		{"type": "nongak", "desc": "농악대"},
		{"type": "stretcher", "desc": "가마/상여"},
		{"type": "jangyongyeong_soldier", "desc": "장용영 정규군"},
		{"type": "patrol_soldier", "desc": "순라청 포졸"},
		{"type": "patrol_officer", "desc": "순라 장교"},
		{"type": "posu", "desc": "조총 포수"},
		{"type": "sasu", "desc": "궁병 사수"},
		{"type": "salsu", "desc": "살수 창검병"},
		{"type": "gipo", "desc": "기포병"},
		{"type": "official_rider", "desc": "파발마 전령"},
		{"type": "monk_soldier", "desc": "승군 의승"},
		{"type": "volunteer_militia", "desc": "의병/민병대"},
		{"type": "bandit", "desc": "도적"},
		{"type": "rebel", "desc": "반란군"},
		{"type": "thief", "desc": "도둑"},
		{"type": "pickpocket", "desc": "소매치기"},
		{"type": "brawler", "desc": "난동꾼"},
		{"type": "firefighter_soldier", "desc": "멸화군 소방수"},
		{"type": "bucket_volunteer", "desc": "의용 소방대"},
		{"type": "fire_panic", "desc": "화재 대피 백성"},
		{"type": "flood_sandbag", "desc": "수해 방재대"},
		{"type": "flood_refugee", "desc": "수해 피난민"},
		{"type": "tiger", "desc": "팔달산 호랑이"},
		{"type": "wolf", "desc": "승냥이"},
		{"type": "hunter", "desc": "사냥꾼"},
		{"type": "saposu", "desc": "착호 사포수"},
		{"type": "chakhogapsa", "desc": "착호갑사"},
		{"type": "drowning", "desc": "수원천 익수자"},
		{"type": "rescuer", "desc": "구조대원"},
		{"type": "jeongisu", "desc": "전기수"},
		{"type": "commoner", "is_drill": true, "desc": "군사훈련 참여 백성"},
		{"type": "commoner", "state": "arrested", "desc": "압송 중인 죄수"},
		{"type": "commoner", "state": "combat", "desc": "교전 중인 의병"},
		{"type": "child_male", "activity_type": "JOB_CHILD_TOP", "desc": "팽이치기 아이"},
		{"type": "child_female", "activity_type": "JOB_CHILD_JEGI", "desc": "제기차기 아이"}
	]

	for pa: Dictionary in purpose_agents:
		var is_special: bool = cl._is_special_or_event_entity(pa)
		assert(is_special == true, "목적 행동 에이전트(%s, type=%s)는 반드시 특수 개체로 판정되어야 합니다." % [pa["desc"], pa["type"]])
		print("  -> [PASS] 목적 행동 상시 노출 대상: %s (%s)" % [pa["desc"], pa["type"]])

	# B. 줄어들어야 하는 단순 반복/배경 대상들
	var background_agents: Array[Dictionary] = [
		{"type": "farmer", "desc": "단순 농부"},
		{"type": "merchant", "desc": "단순 상인"},
		{"type": "merchant_silk", "desc": "비단 상인"},
		{"type": "bobusang", "desc": "보부상"},
		{"type": "shopper", "desc": "장터 행인"},
		{"type": "carrier", "desc": "짐꾼"},
		{"type": "commoner", "desc": "단순 배회 백성"},
		{"type": "citizen_male", "desc": "일반 남성 주민"},
		{"type": "citizen_female", "desc": "일반 여성 주민"},
		{"type": "elder_male", "desc": "단순 노인"}
	]

	for ba: Dictionary in background_agents:
		var is_special: bool = cl._is_special_or_event_entity(ba)
		assert(is_special == false, "단순 배경 에이전트(%s, type=%s)는 특수 개체가 아니어야 하며 원거리 축소 시 줄어들어야 합니다." % [ba["desc"], ba["type"]])
		print("  -> [PASS] 원거리 축소 대상: %s (%s)" % [ba["desc"], ba["type"]])

	# -------------------------------------------------------------
	# 2. SpecialEntityManager 무결성 검증
	# -------------------------------------------------------------
	print("\n[TEST 2] SpecialEntityManager 검증")
	assert(SpecialEntityManager.is_special_type("seodang") == true, "서당은 특수 타입이어야 합니다.")
	assert(SpecialEntityManager.is_special_type("ssireum") == true, "씨름은 특수 타입이어야 합니다.")
	assert(SpecialEntityManager.is_special_type("firefighter") == true, "멸화군은 특수 타입이어야 합니다.")
	assert(SpecialEntityManager.is_special_type("jangyongyeong") == true, "장용영은 특수 타입이어야 합니다.")
	assert(SpecialEntityManager.is_special_type("patrol_soldier") == true, "순라군은 특수 타입이어야 합니다.")
	assert(SpecialEntityManager.is_special_type("farmer") == false, "농부는 특수 타입이 아니어야 합니다.")
	assert(SpecialEntityManager.is_special_type("merchant") == false, "상인은 특수 타입이 아니어야 합니다.")
	assert(SpecialEntityManager.is_special_type("commoner") == false, "일반 백성은 특수 타입이 아니어야 합니다.")
	print("  -> [PASS] SpecialEntityManager 타입 분류 검증 완료")

	print("\n=== [ALL PASS] 목적 행동 NPC 상시 노출 및 배경 NPC 축소 모든 검증 통과! ===")
	quit()
