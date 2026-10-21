extends SceneTree

## [검증 스크립트: 거점 건물 다이렉트 인터랙션 및 화성행궁 세부 전각 정무 연동 검증]

func _init() -> void:
	print("=== [테스트 시작] 거점 건물 다이렉트 인터랙션 및 화성행궁 전각 정무 매핑 검증 ===")
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
	var panels: PanelController = main.panels
	var inspect_popup: InspectPopup = main.inspect_popup
	var haenggung_popup: HaenggungSubBuildingPopup = main.haenggung_popup
	var building_interaction: BuildingInteractionManager = main.building_interaction
	var city: CityLayer = main.city

	# =========================================================================
	print("[검증 1] BuildingData & BuildingEntity 정무 액션 매핑 및 을묘원행 제외 검증...")
	# =========================================================================
	var sj_actions := BuildingData.get_available_royal_actions("seojangdae")
	assert(sj_actions.has("seojangdae_drill"), "서장대 액션 누락")
	assert(not sj_actions.has("eulmyo"), "을묘원행이 수동 액션 목록에 포함됨 (위반)")

	var ym_actions := BuildingData.get_available_royal_actions("yeonmudae")
	assert(ym_actions.has("yeonmudae_drill"), "연무대 액션 누락")
	assert(not ym_actions.has("eulmyo"), "을묘원행이 수동 액션 목록에 포함됨 (위반)")

	var gw_actions := BuildingData.get_available_royal_actions("gwana")
	assert(gw_actions.has("tiger") and gw_actions.has("bandit"), "관아 액션 누락")
	assert(not gw_actions.has("eulmyo"), "을묘원행이 수동 액션 목록에 포함됨 (위반)")

	var hg_actions := BuildingData.get_available_royal_actions("haenggung")
	assert(hg_actions.has("haenggung_court"), "행궁 액션 누락")
	assert(not hg_actions.has("eulmyo"), "을묘원행이 수동 액션 목록에 포함됨 (위반)")

	var oegyu_actions := BuildingData.get_available_royal_actions("oegyujanggak")
	assert(oegyu_actions.has("research") and oegyu_actions.has("uigwe"), "외규장각 액션 누락")

	var naknam_actions := BuildingData.get_available_royal_actions("nangnamheon")
	assert(naknam_actions.has("court"), "낙남헌 액션 누락")

	var jeongni_actions := BuildingData.get_available_royal_actions("jeongniso")
	assert(jeongni_actions.has("hyoryungwon"), "정리소 액션 누락")

	var hg_entity := BuildingEntity.new(Vector2i(14, 29), "haenggung")
	assert(hg_entity.sub_buildings.size() == 3, "행궁 서브 전각 3종 누락")
	print("  -> [PASS] 거점 건물 및 전각 매핑, 을묘원행 제외 검증 완료.")

	# =========================================================================
	print("[검증 2] 서장대 다이렉트 인터랙션 및 야조훈련 액션 버튼 검증...")
	# =========================================================================
	inspect_popup.open_inspect("서장대 (華城壯臺)", "군사 지휘소", null)
	assert(inspect_popup.visible, "서장대 살피기 팝업 오픈 실패")
	var sj_btn_found := false
	for child in inspect_popup._action_buttons_container.get_children():
		var btn: Button = child as Button
		if btn and btn.text.contains("야조훈련"):
			sj_btn_found = true
			break
	assert(sj_btn_found, "서장대 살피기 팝업 내 야조훈련 버튼 누락")
	inspect_popup.close_inspect()
	print("  -> [PASS] 서장대 야조훈련 퀵 버튼 표시 확인 완료.")

	# =========================================================================
	print("[검증 3] 연무대 다이렉트 인터랙션 및 장용영 군사훈련 액션 버튼 검증...")
	# =========================================================================
	inspect_popup.open_inspect("동장대 연무대", "군사 훈련장", null)
	assert(inspect_popup.visible, "연무대 살피기 팝업 오픈 실패")
	var ym_btn_found := false
	for child in inspect_popup._action_buttons_container.get_children():
		var btn: Button = child as Button
		if btn and btn.text.contains("군사훈련 사열"):
			ym_btn_found = true
			break
	assert(ym_btn_found, "연무대 살피기 팝업 내 군사훈련 버튼 누락")
	inspect_popup.close_inspect()
	print("  -> [PASS] 연무대 군사훈련 퀵 버튼 표시 확인 완료.")

	# =========================================================================
	print("[검증 4] 화성유수부 관아 다이렉트 인터랙션 및 호포책·도적토벌 버튼 검증...")
	# =========================================================================
	inspect_popup.open_inspect("화성유수부 동헌 (관아)", "수원 관아", null)
	assert(inspect_popup.visible, "관아 살피기 팝업 오픈 실패")
	var tiger_btn_found := false
	var bandit_btn_found := false
	for child in inspect_popup._action_buttons_container.get_children():
		var btn: Button = child as Button
		if btn:
			if btn.text.contains("호포책"):
				tiger_btn_found = true
			elif btn.text.contains("도적떼 토벌"):
				bandit_btn_found = true
	assert(tiger_btn_found, "관아 호포책 버튼 누락")
	assert(bandit_btn_found, "관아 도적떼 토벌 버튼 누락")
	inspect_popup.close_inspect()
	print("  -> [PASS] 화성유수부 관아 2종 퀵 버튼 표시 확인 완료.")

	# =========================================================================
	print("[검증 5] 화성행궁 본궁 타일 클릭 시 세부 전각(외규장각·낙남헌·정리소) 모달 오픈 검증...")
	# =========================================================================
	var hg_cell_pos := Vector2i(14, 29)
	grid.grid[hg_cell_pos.y][hg_cell_pos.x]["building"] = "haenggung"
	grid.grid[hg_cell_pos.y][hg_cell_pos.x]["under_construction"] = false

	# CityLayer _show_inspect 호출
	city._show_inspect(hg_cell_pos)
	assert(haenggung_popup.visible, "행궁 타일 클릭 시 HaenggungSubBuildingPopup 오픈 실패")

	# 전각 선택 버튼 존재 여부
	assert(haenggung_popup._btn_oegyu != null, "외규장각 실학 연구 버튼 누락")
	assert(haenggung_popup._btn_uigwe != null, "외규장각 의궤 편찬 버튼 누락")
	assert(haenggung_popup._btn_naknam != null, "낙남헌 인재 등용 버튼 누락")
	assert(haenggung_popup._btn_jeongni != null, "정리소 현륭원 친림 버튼 누락")
	assert(haenggung_popup._btn_inspect != null, "행궁 살피기 버튼 누락")

	haenggung_popup.close_popup()
	assert(not haenggung_popup.visible, "행궁 팝업 닫기 실패")
	print("  -> [PASS] 화성행궁 전각 선택 모달 및 버튼 바인딩 확인 완료.")

	# =========================================================================
	print("[검증 6] 난이도 배율 및 자원 소모량 일원화 검증...")
	# =========================================================================
	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.EASY)
	var easy_drill_cost := DifficultyManager.get_military_drill_cost()
	var easy_tomb_cost := DifficultyManager.get_tomb_visit_cost()
	assert(int(easy_drill_cost["gold"]) == 2000 and int(easy_drill_cost["rice"]) == 1000, "EASY 훈련 비용 불일치")
	assert(int(easy_tomb_cost["gold"]) == 2000 and int(easy_tomb_cost["rice"]) == 1000, "EASY 참배 비용 불일치")

	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.NORMAL)
	var normal_drill_cost := DifficultyManager.get_military_drill_cost()
	var normal_tomb_cost := DifficultyManager.get_tomb_visit_cost()
	assert(int(normal_drill_cost["gold"]) == 4000 and int(normal_drill_cost["rice"]) == 2000, "NORMAL 훈련 비용 불일치 (2배)")
	assert(int(normal_tomb_cost["gold"]) == 4000 and int(normal_tomb_cost["rice"]) == 2000, "NORMAL 참배 비용 불일치 (2배)")

	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.HARD)
	var hard_drill_cost := DifficultyManager.get_military_drill_cost()
	var hard_tomb_cost := DifficultyManager.get_tomb_visit_cost()
	assert(int(hard_drill_cost["gold"]) == 6000 and int(hard_drill_cost["rice"]) == 3000, "HARD 훈련 비용 불일치 (3배)")
	assert(int(hard_tomb_cost["gold"]) == 6000 and int(hard_tomb_cost["rice"]) == 3000, "HARD 참배 비용 불일치 (3배)")

	DifficultyManager.set_difficulty(DifficultyManager.Difficulty.EASY)
	print("  -> [PASS] 난이도 배율 보통(x2), 어려움(x3) 소모량 산출 검증 완료.")

	# =========================================================================
	print("[검증 7] RoyalCourtManager 컨트롤러를 통한 정무 모달 트리거 검증...")
	# =========================================================================
	# 7-1. 서장대 야조훈련
	RoyalCourtManager.execute_seojangdae_drill(panels)
	assert(panels._modal.visible, "서장대 야조훈련 모달 오픈 실패")
	panels._close_modal()

	# 7-2. 연무대 군사훈련
	RoyalCourtManager.execute_yeonmudae_drill(panels)
	assert(panels._modal.visible, "연무대 사열훈련 모달 오픈 실패")
	panels._close_modal()

	# 7-3. 화성유수부 호포책 / 도적토벌
	RoyalCourtManager.execute_gwana_action("tiger", panels)
	assert(panels._modal.visible, "호포책 모달 오픈 실패")
	panels._close_modal()

	RoyalCourtManager.execute_gwana_action("bandit", panels)
	assert(panels._modal.visible, "도적토벌 모달 오픈 실패")
	panels._close_modal()

	# 7-4. 외규장각 실학연구 / 의궤편찬
	RoyalCourtManager.execute_oegyujanggak_action("research", panels)
	assert(panels._modal.visible, "실학연구 모달 오픈 실패")
	panels._close_modal()

	RoyalCourtManager.execute_oegyujanggak_action("uigwe", panels)
	assert(panels._modal.visible or (panels.uigwe_popup != null and panels.uigwe_popup.visible), "의궤편찬 모달 또는 팝업 오픈 실패")
	if panels.uigwe_popup and panels.uigwe_popup.visible:
		panels.uigwe_popup.close_popup()
	panels._close_modal()

	# 7-5. 낙남헌 인재등용
	RoyalCourtManager.execute_nangnamheon_action(panels)
	assert(panels._modal.visible, "인재등용 모달 오픈 실패")
	panels._close_modal()

	# 7-6. 정리소 현륭원친림
	RoyalCourtManager.execute_jeongniso_action(panels)
	assert(panels._modal.visible, "현륭원친림 모달 오픈 실패")
	panels._close_modal()

	print("  -> [PASS] RoyalCourtManager 및 PanelController 양방향 연동 검증 완료.")

	# =========================================================================
	print("[검증 8] 우클릭 취소 시 전각 팝업 및 살피기 팝업 닫기 검증...")
	# =========================================================================
	haenggung_popup.open_haenggung_popup()
	assert(haenggung_popup.visible, "행궁 팝업 오픈 실패")
	main.cancel_current_selection()
	assert(not haenggung_popup.visible, "우클릭 취소 시 행궁 팝업 닫기 실패")
	print("  -> [PASS] 우클릭 취소 핸들러 연동 검증 완료.")

	print("\n=== [테스트 성공] 모든 거점 건물 다이렉트 인터랙션 및 전각 정무 연동 검증 ALL PASS! ===")
	main.queue_free()
	for f in range(2):
		await process_frame
	quit(0)
