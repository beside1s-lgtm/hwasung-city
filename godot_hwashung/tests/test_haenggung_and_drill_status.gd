extends SceneTree

## [검증 스크립트: 화성행궁 어전 정무 진행/완료 상태 표시 및 서장대·연무대 연례 훈련 쿨타임 표시 검증]

func _init() -> void:
	print("=== [테스트 시작] 화성행궁 어전 정무 상태 및 서장대·연무대 연례 훈련 상태 검증 ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var main_scene = load("res://scenes/Main.tscn")
	if not main_scene:
		printerr("Main.tscn 로드 실패")
		quit(1)
		return

	var main = main_scene.instantiate()
	root.add_child(main)

	for i in range(5):
		await process_frame

	var grid: GameGrid = main.grid
	var sim: SimulationCore = main.simulation_core
	var court: CourtSystem = main.court
	var panels: PanelController = main.panels
	var inspect_popup: InspectPopup = main.inspect_popup
	var haenggung_popup: HaenggungSubBuildingPopup = main.haenggung_popup

	# =========================================================================
	print("[검증 1] 화성행궁 초기 상태에서 전각별 뱃지 및 설명 렌더링 검증...")
	# =========================================================================
	haenggung_popup.open_haenggung_popup()
	assert(haenggung_popup.visible, "화성행궁 팝업 오픈 실패")

	# 1) 외규장각 연구 초기 상태
	assert(haenggung_popup._btn_oegyu.text.contains("완료"), "외규장각 연구 버튼 완료 수 텍스트 누락")

	# 2) 외규장각 의궤 편찬 초기 상태
	assert(haenggung_popup._btn_uigwe.text.contains("미편찬") or haenggung_popup._btn_uigwe.text.contains("권"), "의궤 편찬 상태 텍스트 누락")

	# 3) 낙남헌 인재 등용 초기 상태
	assert(haenggung_popup._btn_naknam.text.contains("등용"), "인재 등용 상태 텍스트 누락")

	# 4) 정리소 현륭원 참배 초기 상태 (미참배)
	assert(haenggung_popup._btn_jeongni.text.contains("금년 미참배"), "정리소 금년 미참배 뱃지 누락")

	# 5) 봉수당 세자 서연 초기 상태
	assert(haenggung_popup._btn_prince.text.contains("서연"), "세자 서연 상태 텍스트 누락")

	haenggung_popup.close_popup()
	print("  -> [PASS] 초기 어전 정무 5대 전각 상태 뱃지 표시 확인 완료.")

	# =========================================================================
	print("[검증 2] 현륭원 친림 참배 수행 후 '올해 참배 완료' 동적 반영 검증...")
	# =========================================================================
	# 현륭원 참배 강제 수행 상태 시뮬레이션
	court.hyoryungwon["visited"] = true
	CityStats.add_hyeonryungwon_visit()
	court.hyeonryungwon_visits = CityStats.get_hyeonryungwon_visits()

	haenggung_popup.open_haenggung_popup()
	assert(haenggung_popup._btn_jeongni.text.contains("올해 참배 완료"), "참배 후 '올해 참배 완료' 뱃지 미반영: %s" % haenggung_popup._btn_jeongni.text)
	assert(haenggung_popup._btn_jeongni.text.contains("누적"), "참배 누적 횟수 미표시")
	haenggung_popup.close_popup()
	print("  -> [PASS] 현륭원 참배 후 '올해 참배 완료' 뱃지 동적 반영 확인 완료.")

	# =========================================================================
	print("[검증 3] 실학 연구 진행 중 및 완료 시 외규장각 뱃지 동적 반영 검증...")
	# =========================================================================
	var tech_mgr: TechTreeManager = sim.tech_tree as TechTreeManager
	if tech_mgr:
		tech_mgr.current_researching = "goguma"
		tech_mgr.tech_progress_dict["goguma"] = 45.0
		haenggung_popup.open_haenggung_popup()
		assert(haenggung_popup._btn_oegyu.text.contains("연구 중") or haenggung_popup._btn_oegyu.text.contains("진행"), "연구 중 뱃지 미반영: %s" % haenggung_popup._btn_oegyu.text)
		haenggung_popup.close_popup()

		# 전체 연구 완료 테스트
		for t in TechTreeManager.TECH_LIST:
			tech_mgr.tech_completed_dict[t["id"]] = true
		tech_mgr.current_researching = ""
		haenggung_popup.open_haenggung_popup()
		assert(haenggung_popup._btn_oegyu.text.contains("연구 완수") or haenggung_popup._btn_oegyu.text.contains("완수"), "연구 완수 뱃지 미반영: %s" % haenggung_popup._btn_oegyu.text)
		haenggung_popup.close_popup()
	print("  -> [PASS] 실학 연구 진행 중 및 전 과제 완수 뱃지 동적 반영 확인 완료.")

	# =========================================================================
	print("[검증 4] 의궤 편찬 완수 시 뱃지 동적 반영 검증...")
	# =========================================================================
	court.uigwe["wonhaeng"] = true
	court.uigwe["seongyeok"] = true
	haenggung_popup.open_haenggung_popup()
	assert(haenggung_popup._btn_uigwe.text.contains("편찬 완수"), "의궤 편찬 완수 뱃지 미반영: %s" % haenggung_popup._btn_uigwe.text)
	haenggung_popup.close_popup()
	print("  -> [PASS] 의궤 편찬 완수 뱃지 동적 반영 확인 완료.")

	# =========================================================================
	print("[검증 5] 세자 제왕학 서연 100% 완수 시 뱃지 동적 반영 검증...")
	# =========================================================================
	CityStats.set_crown_prince_education(100)
	haenggung_popup.open_haenggung_popup()
	assert(haenggung_popup._btn_prince.text.contains("제왕학 완수"), "세자 제왕학 완수 뱃지 미반영: %s" % haenggung_popup._btn_prince.text)
	haenggung_popup.close_popup()
	print("  -> [PASS] 세자 제왕학 완수 뱃지 동적 반영 확인 완료.")

	# =========================================================================
	print("[검증 6] 서장대 야조 쿨타임 중 살피기 팝업 및 패널 '올해 야조 실시 완료' 검증...")
	# =========================================================================
	grid.grid[29][6]["building"] = "seojangdae"
	grid.grid[29][6]["under_construction"] = false
	sim.seojangdae_drill_cd_months = 8
	inspect_popup.open_inspect("서장대 (華城壯臺)", "군사 지휘소", null)
	var found_sj_done := false
	for child in inspect_popup._action_buttons_container.get_children():
		var btn: Button = child as Button
		if btn and btn.text.contains("올해 야조 실시 완료"):
			found_sj_done = true
			assert(btn.text.contains("8개월"), "남은 쿨다운 개월 수 미포함: %s" % btn.text)
			break
	assert(found_sj_done, "서장대 쿨타임 중 '올해 야조 실시 완료' 버튼 누락")
	inspect_popup.close_inspect()

	# 패널 모달에서도 확인
	panels.open_action_modal("seojangdae_drill")
	assert(panels._modal.visible, "서장대 모달 오픈 실패")
	var found_modal_btn := false
	for b in panels._body.find_children("*", "Button", true, false):
		var btn_node: Button = b as Button
		if btn_node and btn_node.text.contains("올해 야조 실시 완료"):
			found_modal_btn = true
			assert(btn_node.disabled, "쿨다운 중 실행 버튼이 활성화되어 있음")
			break
	assert(found_modal_btn, "서장대 모달 내 '올해 야조 실시 완료' 버튼 미표시")
	panels._close_modal()
	print("  -> [PASS] 서장대 쿨타임 중 살피기 및 모달 '올해 야조 실시 완료' 검증 완료.")

	# =========================================================================
	print("[검증 7] 연무대 무예 사열 쿨타임 중 살피기 팝업 및 패널 '올해 사열 실시 완료' 검증...")
	# =========================================================================
	grid.grid[20][38]["building"] = "yeonmudae"
	grid.grid[20][38]["under_construction"] = false
	sim.yeonmudae_drill_cd_months = 10
	inspect_popup.open_inspect("동장대 연무대", "군사 훈련장", null)
	var found_ym_done := false
	for child in inspect_popup._action_buttons_container.get_children():
		var btn: Button = child as Button
		if btn and btn.text.contains("올해 사열 실시 완료"):
			found_ym_done = true
			assert(btn.text.contains("10개월"), "남은 쿨다운 개월 수 미포함: %s" % btn.text)
			break
	assert(found_ym_done, "연무대 쿨타임 중 '올해 사열 실시 완료' 버튼 누락")
	inspect_popup.close_inspect()

	# 패널 모달에서도 확인
	panels.open_action_modal("yeonmudae_drill")
	assert(panels._modal.visible, "연무대 모달 오픈 실패")
	var found_ym_modal_btn := false
	for b in panels._body.find_children("*", "Button", true, false):
		var btn_node: Button = b as Button
		if btn_node and btn_node.text.contains("올해 사열 실시 완료"):
			found_ym_modal_btn = true
			assert(btn_node.disabled, "쿨다운 중 실행 버튼이 활성화되어 있음")
			break
	assert(found_ym_modal_btn, "연무대 모달 내 '올해 사열 실시 완료' 버튼 미표시")
	panels._close_modal()
	print("  -> [PASS] 연무대 쿨타임 중 살피기 및 모달 '올해 사열 실시 완료' 검증 완료.")

	print("\n=== [테스트 성공] 모든 화성행궁 상태 표시 및 훈련 쿨타임 고증 검증 ALL PASS! ===")
	quit(0)
