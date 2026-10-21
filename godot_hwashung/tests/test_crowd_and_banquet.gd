extends SceneTree

## [을묘원행 연도 백성 도열, 격쟁/상언 돌발 인터랙션 및 봉수당진찬연·양로연 종합 단위 테스트]

func _init() -> void:
	print("=== [테스트 시작] 연도 백성 도열, 격쟁/상언 FSM 및 봉수당·낙남헌 고증 행사 검증 ===")

	test_new_dot_sprites()
	test_crowd_spectators_generation_and_transitions()
	test_petition_fsm_and_deadlock_prevention()
	test_bongsu_and_naknam_banquets()
	test_eulmyo_road_continuity_and_lock()
	test_yeonmudae_archery_phase_and_target_mechanics()

	print("=== [테스트 완료] 모든 항목 100% 통과 (ALL PASS)! ===")
	quit(0)

## 1. ProcessionUnitArt 신규 고증 도트 스프라이트 등록 및 렌더러 검증
func test_new_dot_sprites() -> void:
	print("[검증 1] 신규 고증 도트 스프라이트 7종(격쟁, 상언, 궁중여령, 고을노인, 도열백성 3종) 검증...")

	var new_roles: Array[String] = [
		"gyeokjaeng_citizen",
		"sangeon_scholar",
		"court_dancer",
		"elder_citizen",
		"spectator_bow",
		"spectator_prostrate",
		"spectator_cheer"
	]

	for r: String in new_roles:
		ProcessionUnitArt._build_role_row(r, false)
		var key: String = "%s|march" % r
		assert(ProcessionUnitArt._rows.has(key), "신규 도트 스프라이트 등록 실패: %s" % r)

	print("  -> 신규 도트 스프라이트 7종 아틀라스 베이킹 정상 통과.")

## 2. 연도(沿道) 백성 도열 풀링 및 거리 기반 동적 전이 검증
func test_crowd_spectators_generation_and_transitions() -> void:
	print("[검증 2] 연도 백성 도열 풀링 및 동적 환호/부복 전이 검증...")

	var win: Window = root
	var grid := GameGrid.new()
	win.add_child(grid)
	grid._build_from_map()

	# 도로 포설
	for y in range(5, 30):
		grid.grid[y][26]["building"] = "road"

	var rp := RoyalProcessionManager.new()
	win.add_child(rp)
	rp.grid = grid

	# 테스트용 웨이포인트 30개 생성
	rp.waypoints.clear()
	for y in range(5, 30):
		rp.waypoints.append(rp._cell_to_world(26.0, float(y)))

	rp._build_spectator_crowd()

	assert(rp.crowd_spectators.size() > 0, "도열 백성이 생성되지 않았습니다.")
	print("  -> 도열 백성 %d명 안전 배치 완료." % rp.crowd_spectators.size())

	# 도열 백성이 도로 타일 위에 스폰되지 않았는지 엄격 검증
	for sp: Dictionary in rp.crowd_spectators:
		var gp: Vector2i = sp.get("grid_pos", Vector2i(-1, -1))
		assert(grid.in_bounds(gp.x, gp.y), "그리드 범위를 벗어난 백성 존재")
		var cell: Dictionary = grid.grid[gp.y][gp.x]
		assert(cell.get("building", "") != "road", "도로 한가운데에 백성이 도열되었습니다(통행 방해 버그)!")

	# 정조 대왕 접근 시 동적 상태 전이 검증
	var dummy_king_pos: Vector2 = rp.crowd_spectators[0]["pos"] + Vector2(10.0, 10.0) # 근접 거리
	rp.procession_units = [
		{"role": "jeongjo_king", "pos": dummy_king_pos, "visible": true}
	]

	rp._update_spectators(0.1)

	var close_sp: Dictionary = rp.crowd_spectators[0]
	assert(close_sp.get("role", "") in ["spectator_prostrate", "spectator_cheer"], "정조 대왕 근접 시 부복 또는 환호로 전이되지 않았습니다: %s" % close_sp.get("role", ""))

	rp.queue_free()
	grid.queue_free()
	print("  -> 도열 백성 배치 무결성 및 동적 반응 검증 성공.")

## 3. 격쟁 & 상언 돌발 이벤트 FSM 및 데드락 방지 타이머 검증
func test_petition_fsm_and_deadlock_prevention() -> void:
	print("[검증 3] 격쟁/상언 돌발 이벤트 FSM 및 데드락 방지 자가회복 검증...")

	var win: Window = root
	var rp := RoyalProcessionManager.new()
	win.add_child(rp)

	var sim := SimulationCore.new()
	win.add_child(sim)
	sim.loyalty = 70
	sim.gold = 500000
	sim.rice = 500000
	sim.authority = 80
	rp.sim = sim

	rp.waypoints = [
		Vector2(100.0, 100.0),
		Vector2(200.0, 150.0),
		Vector2(300.0, 200.0)
	]
	rp.lead_distance_traveled = 50.0

	# 1) 격쟁 FSM 개시
	rp._start_petition_fsm("gyeokjaeng")
	assert(rp.petition_fsm == RoyalProcessionManager.PetitionFSM.RUNNING_IN, "격쟁 FSM 시작 상태 오류")
	assert(rp.petition_actor.get("role", "") == "gyeokjaeng_citizen", "격쟁 백성 역할군 매핑 오류")

	# 0.8초 경과 후 DIALOGUE 전이 및 정조 어명 발화 검증
	rp._update_petition_fsm(0.85)
	assert(rp.petition_fsm == RoyalProcessionManager.PetitionFSM.DIALOGUE, "DIALOGUE 상태 전이 실패")
	assert(rp.king_speech_text != "", "정조 대왕 어명 대사가 생성되지 않았습니다.")

	# 플레이어 미입력 시 4초 후 자동 윤허(데드락 방지) 검증
	rp._petition_auto_timer = 0.05
	rp._is_modal_open = true
	rp._update_petition_fsm(0.1)
	assert(rp.petition_fsm == RoyalProcessionManager.PetitionFSM.RESOLVING, "자동 진행 가드로 해결되지 않았습니다.")

	# 감격 후 물러서기(STEPPING_BACK) 및 완료(NONE) 전이 검증
	rp._update_petition_fsm(0.85)
	assert(rp.petition_fsm == RoyalProcessionManager.PetitionFSM.STEPPING_BACK, "STEPPING_BACK 전이 실패")

	rp._update_petition_fsm(0.85)
	assert(rp.petition_fsm == RoyalProcessionManager.PetitionFSM.NONE, "FSM 완료 및 행렬 재개 실패")

	rp.queue_free()
	sim.queue_free()
	print("  -> 격쟁/상언 FSM 4단계 라이프사이클 및 데드락 방지 자가 진행 검증 성공.")

## 4. 화성행궁 봉수당 진찬연 & 낙남헌 양로연 고증 수치 및 자원 변동 검증
func test_bongsu_and_naknam_banquets() -> void:
	print("[검증 4] 봉수당 진찬연 및 낙남헌 양로연 의례 고증 수치 검증...")

	var win: Window = root
	var rp := RoyalProcessionManager.new()
	win.add_child(rp)

	var sim := SimulationCore.new()
	win.add_child(sim)
	sim.loyalty = 60
	sim.authority = 50
	sim.rice = 50000
	sim.gold = 30000
	rp.sim = sim

	# 봉수당 진찬연 (민심 +15, 왕권 +10)
	rp.current_phase = RoyalProcessionManager.Phase.CEREMONY_BONGSU
	rp.phase_timer = 6.1
	rp._update_ceremony_bongsu(0.1)

	assert(sim.loyalty == 75, "봉수당 진찬연 민심 보너스 실패: %d (기대: 75)" % sim.loyalty)
	assert(sim.authority == 60, "봉수당 진찬연 왕권 보너스 실패: %d (기대: 60)" % sim.authority)
	assert(rp.current_phase == RoyalProcessionManager.Phase.CEREMONY_NAKNAM, "낙남헌 양로연으로 단계 전이 실패")

	# 낙남헌 양로연 (식량 -2,000석, 금화 -1,000냥, 민심 +20)
	rp.phase_timer = 6.1
	rp._update_ceremony_naknam(0.1)

	assert(sim.rice == 48000, "낙남헌 양로연 식량 차감 실패: %d (기대: 48000)" % sim.rice)
	assert(sim.gold == 29000, "낙남헌 양로연 금화 차감 실패: %d (기대: 29000)" % sim.gold)
	assert(sim.loyalty == 95, "낙남헌 양로연 민심 보너스 실패: %d (기대: 95)" % sim.loyalty)
	assert(rp.current_phase == RoyalProcessionManager.Phase.CEREMONY_SINPUNG, "신풍루 사미로 단계 전이 실패")

	rp.queue_free()
	sim.queue_free()
	print("  -> 봉수당 진찬연 및 낙남헌 양로연 고증 의례 자원 및 지표 변동 검증 성공.")

## 5. 도로 연결 필수 조건화 및 가옥 관통 차단 검증
func test_eulmyo_road_continuity_and_lock() -> void:
	print("[검증 5] 도로 연결 필수 조건화 및 행궁 축조 검증...")

	var win: Window = root
	var grid := GameGrid.new()
	win.add_child(grid)
	grid._build_from_map()

	var sim := SimulationCore.new()
	win.add_child(sim)
	sim.loyalty = 90
	sim.authority = 90
	sim.gold = 500000
	sim.rice = 500000
	sim.retainers["chae_jegong"] = true
	sim.retainers["jeong_yakyong"] = true
	sim.retainers["kim_hongdo"] = true

	# A. 화성행궁 미축조 상태 검증
	var v_no_palace: Dictionary = RoyalProcessionManager.verify_eulmyo_road_continuity(grid)
	assert(not v_no_palace.get("ok", false), "행궁이 없는데 도로 연속성이 통과되었습니다.")
	assert("화성행궁" in v_no_palace.get("error_msg", ""), "행궁 미축조 에러 메시지 불일치: %s" % v_no_palace.get("error_msg", ""))

	# B. 행궁 배치 및 도로 단절 상태 검증
	var h_pos := Vector2i(22, 32)
	grid.grid[h_pos.y][h_pos.x]["building"] = "haenggung"
	grid.grid[h_pos.y][h_pos.x]["site_anchor"] = h_pos
	grid.grid[h_pos.y][h_pos.x + 3]["building"] = "haenggung" # 신풍루 위치

	var v_broken: Dictionary = RoyalProcessionManager.verify_eulmyo_road_continuity(grid)
	assert(not v_broken.get("ok", false), "도로가 끊겼는데 연속성이 통과되었습니다.")
	assert("도로가 연결되지 않았습니다" in v_broken.get("error_msg", ""), "도로 단절 에러 메시지 불일치: %s" % v_broken.get("error_msg", ""))

	# C. 장안문(26, 6) -> 신풍루(25, 32) -> 팔달문(26, 46) 도로 연결
	var sp_pos := Vector2i(25, 32)
	for y in range(6, 47):
		grid.grid[y][25]["building"] = "road"
		grid.grid[y][25]["road_type"] = "dirt"
	grid.grid[6][26]["building"] = "gate" # 장안문
	grid.grid[6][25]["building"] = "road"
	grid.grid[46][26]["building"] = "gate" # 팔달문
	grid.grid[46][25]["building"] = "road"

	# 박석길 미포장 검증
	var v_no_stone: Dictionary = RoyalProcessionManager.verify_eulmyo_road_continuity(grid)
	assert(not v_no_stone.get("ok", false), "박석길이 없는데 도로 연속성이 통과되었습니다.")
	assert("박석길" in v_no_stone.get("error_msg", ""), "박석길 미포장 에러 메시지 불일치: %s" % v_no_stone.get("error_msg", ""))

	# 신풍루 앞 박석길 포장
	grid.grid[sp_pos.y][sp_pos.x]["road_type"] = "stone"

	# 최종 연속성 성공 검증
	var v_ok: Dictionary = RoyalProcessionManager.verify_eulmyo_road_continuity(grid)
	assert(v_ok.get("ok", false), "모든 도로 및 박석길 연결 후에도 실패: %s" % v_ok.get("error_msg", ""))

	# can_trigger_eulmyo_event 결합 검증 (성곽 및 사대문 완공 조건 추가 설정)
	sim.fortress_progress = 100
	grid.grid[13][10]["building"] = "gate" # 화서문
	grid.grid[13][10]["gate_name"] = "화서문 (hwaseo)"
	grid.grid[29][45]["building"] = "gate" # 창룡문
	grid.grid[29][45]["gate_name"] = "창룡문 (changryong)"
	grid.grid[6][26]["gate_name"] = "장안문 (jangan)"
	grid.grid[46][26]["gate_name"] = "팔달문 (paldal)"

	var trig_res: Dictionary = RoyalProcessionManager.can_trigger_eulmyo_event(sim, grid)
	assert(trig_res.get("can_trigger", false), "모든 조건 충족 후 발동 실패: %s" % str(trig_res.get("reasons", [])))

	grid.queue_free()
	sim.queue_free()
	print("  -> 도로망 연결 필수 조건화 및 행궁 축조 검증 성공.")

## 6. 연무대 활쏘기 사열(YEONMUDAE_ARCHERY) 페이즈 및 과녁판 검증
func test_yeonmudae_archery_phase_and_target_mechanics() -> void:
	print("[검증 6] 연무대 활쏘기 사열 페이즈 및 득중정 과녁판 명중 검증...")

	var win: Window = root
	var rp := RoyalProcessionManager.new()
	win.add_child(rp)

	var sim := SimulationCore.new()
	win.add_child(sim)
	sim.military_power = 50
	sim.authority = 70
	sim.defense_power = 200
	rp.sim = sim

	var grid := GameGrid.new()
	win.add_child(grid)
	grid._build_from_map()
	rp.grid = grid

	# 1) 연무대 미완공 시 활쏘기 사열 스킵 검증 (서장대 야조 -> 별시 직행)
	rp.yeonmudae_pos = Vector2i(-1, -1)
	rp.current_phase = RoyalProcessionManager.Phase.SEOJANGDAE_YAJO
	rp.phase_timer = 8.1
	rp._update_seojangdae_yajo(0.1)
	assert(rp.current_phase == RoyalProcessionManager.Phase.BYEOLSI_EXAM, "연무대 미완공 시 별시로 직행하지 않았습니다.")

	# 2) 연무대 완공 시 활쏘기 사열(YEONMUDAE_ARCHERY) 전이 검증
	sim.military_power = 50
	rp.yeonmudae_pos = Vector2i(45, 20)
	rp.current_phase = RoyalProcessionManager.Phase.SEOJANGDAE_YAJO
	rp.phase_timer = 8.1
	rp._update_seojangdae_yajo(0.1)
	assert(rp.current_phase == RoyalProcessionManager.Phase.YEONMUDAE_ARCHERY, "연무대 완공 시 YEONMUDAE_ARCHERY로 전이 실패")

	# 3) 연무대 활쏘기 8초 경과 후 국방력/왕권 보너스 및 별시 전이 검증 (50 + 25(야조) + 15(활쏘기) = 90)
	rp.phase_timer = 8.1
	rp._update_yeonmudae_archery(0.1)
	assert(sim.military_power == 90, "연무대 사열 국방력 보너스 실패: %d (기대: 90)" % sim.military_power)
	assert(sim.authority == 75, "연무대 사열 왕권 보너스 실패: %d (기대: 75)" % sim.authority)
	assert(rp.current_phase == RoyalProcessionManager.Phase.BYEOLSI_EXAM, "활쏘기 완료 후 별시로 전이 실패")

	# 4) 정조 활쏘기(jeongjo_archery) 및 과녁(archery_target) 4프레임 도트 아틀라스 등록 검증
	ProcessionUnitArt._build_role_row("jeongjo_archery", true)
	ProcessionUnitArt._build_role_row("archery_target", true)
	assert(ProcessionUnitArt._rows.has("jeongjo_archery|drill"), "정조 활쏘기 아틀라스 등록 누락")
	assert(ProcessionUnitArt._rows.has("archery_target|drill"), "과녁판 아틀라스 등록 누락")

	rp.queue_free()
	sim.queue_free()
	grid.queue_free()
	print("  -> 연무대 활쏘기 사열 페이즈 및 득중정 과녁판 명중 검증 성공.")
