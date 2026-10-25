extends SceneTree
## [테스트] 근대화 시대 세이브·불러오기와 1875·1876 사건이 겹치거나 빠지지 않는지 실제 게임으로 확인한다.
##   Godot --headless --path godot_hwashung --script res://tools/test_modern_save.gd
## 사용자 저장 슬롯은 건드리지 않는다(user://_test_modern_*.json 임시 파일, 1800 보관본은 백업 후 되돌림).

const CLEARED := "user://save_1800_cleared.json"
const T1 := "user://_test_modern_1.json"
const T2 := "user://_test_modern_2.json"

var main: Node
var fails := 0

func _init() -> void:
	call_deferred("_run")

func _wait(n: int) -> void:
	for i in range(n):
		await process_frame

func _check(cond: bool, what: String) -> void:
	print(("  ✔ " if cond else "  ✖ ") + what)
	if not cond:
		fails += 1

func _save(path: String) -> bool:
	return SaveSystem.save_game_to_path(path, main.simulation_core, main.grid)

func _load(path: String) -> bool:
	var ok: bool = SaveSystem.load_game_from_path(path, main.simulation_core, main.grid, main.time_manager, main.quests)
	if ok:
		main.on_game_loaded()
	return ok

func _quiz() -> DiplomacyQuizPopup:
	for n in root.find_children("*", "", true, false):
		if n is DiplomacyQuizPopup and not n.is_queued_for_deletion():
			return n
	return null

func _advance_to_january(year: int) -> void:
	var tm: TimeManager = main.time_manager
	while tm.current_year < year or tm.current_month != 1:
		tm.advance_months(1)
	await _wait(2)

func _run() -> void:
	main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(10)
	if main.intro_layer:
		main.intro_layer.intro_finished.emit()
		main._on_intro_finished()
	await _wait(5)
	main._on_start_new_game()
	await _wait(60)
	var backup := ""
	if FileAccess.file_exists(CLEARED):
		backup = FileAccess.get_file_as_string(CLEARED)

	var mm: ModernizationManager = ModernizationManager.instance
	var um: UrbanEvolutionManager = UrbanEvolutionManager.instance
	var pol: ModernPoliticsManager = ModernPoliticsManager.instance
	var tm: TimeManager = main.time_manager

	print("[1] 1820 근대화 진입")
	mm.start_modernization()
	await _wait(5)
	_check(mm.active and tm.current_year == 1820, "근대화 활성, 1820년 (현재 %d년)" % tm.current_year)
	_check(FileAccess.file_exists(CLEARED), "1800 보관본 저장됨")

	print("[2] 저장 → 값 바꾸기 → 불러오기")
	mm.trust = 7
	mm.allies = ["usa", "britain"]
	mm.field_progress = {"gunnery": 40.0}
	um.heritage_condition = 73.5
	um.stone_ratio = 0.42
	pol.system = ModernPoliticsManager.SYS_MONARCHY
	_check(_save(T1), "저장 성공")
	mm.trust = 0
	mm.allies = []
	mm.field_progress = {}
	um.heritage_condition = 100.0
	um.stone_ratio = 0.0
	_check(_load(T1), "불러오기 성공")
	_check(mm.active, "불러온 뒤 근대화 유지")
	_check(mm.trust == 7 and mm.allies.size() == 2, "신뢰도·동맹 복원 (%d, %s)" % [mm.trust, str(mm.allies)])
	_check(is_equal_approx(float(mm.field_progress.get("gunnery", 0.0)), 40.0), "연구 게이지 복원")
	_check(is_equal_approx(um.heritage_condition, 73.5) and is_equal_approx(um.stone_ratio, 0.42), "문화재 보존도·석조 전환 복원")

	print("[3] 1875 일본 대규모 침공 (국방력을 넉넉히 줘서 승리 경로)")
	mm.modern_weapon_bonus = 6000
	tm.jump_to_year(1874)
	main.simulation_core.current_year = 1874
	main.simulation_core.turn = tm.get_total_months() + 1
	mm.last_year_event = 1874
	await _advance_to_january(1875)
	_check(mm.japan_1875_done, "1875 침공을 막아 냄 → japan_1875_done")
	_check(mm._emergency_layer != null and is_instance_valid(mm._emergency_layer), "비변사 비상 보고 창이 뜸")
	_check(_save(T2), "보고 창이 뜬 채로 저장")
	_check(_load(T2), "불러오기")
	await _wait(2)
	_check(mm.japan_1875_done and mm.last_year_event == 1875, "불러온 뒤에도 1875 처리 완료 상태")
	tm.advance_months(1)
	await _wait(2)
	_check(mm._event_queue.is_empty(), "다음 달에 1875 사건이 다시 열리지 않음")

	print("[4] 1876 강화도 회담: 문답 중 저장·불러오기 → 이듬해 다시 열림")
	await _advance_to_january(1876)
	var q := _quiz()
	_check(q != null, "1876 회담 문답 창이 열림")
	_check(not mm.treaty_1876_done, "문답이 끝나기 전에는 완료 표시 없음")
	_check(_save(T2), "문답 도중 저장")
	_check(_load(T2), "불러오기")
	await _wait(2)
	_check(_quiz() == null, "불러오면 문답 창은 닫힘")
	await _advance_to_january(1877)
	q = _quiz()
	_check(q != null, "1877년 정초에 회담이 다시 열림")
	if q != null:
		var trust_before := mm.trust
		q.piece_per_question = "" # 테스트가 사용자의 역사 사전 진행을 바꾸지 않게
		q.piece_on_finish = ""
		for i in range(ModernDiplomacyData.TREATY_1876.size()):
			q._answer(int(ModernDiplomacyData.TREATY_1876[q._idx]["c"]))
			if q._idx < ModernDiplomacyData.TREATY_1876.size():
				q._show_question()
		q._finish(true)
		await _wait(2)
		_check(mm.treaty_1876_done, "문답 10개 모두 맞힘 → 회담 타결")
		_check(mm.trust == mini(10, trust_before + 1), "외교 신뢰도 +1")

	print("[5] 1945 결산 점수")
	print("  문화재 %d · 도시화 %d · 학문 %d · 동맹 %d → %d점 → %s" % [mm.metric_heritage(), mm.metric_urban(), mm.metric_academic(), mm.metric_alliance(), mm.final_score(), mm.final_ending_key()])

	# 정리
	for p in [T1, T2]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	if backup != "":
		var f := FileAccess.open(CLEARED, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	elif FileAccess.file_exists(CLEARED):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CLEARED))
	print("결과: %s (실패 %d)" % ["통과" if fails == 0 else "실패", fails])
	quit(fails)
