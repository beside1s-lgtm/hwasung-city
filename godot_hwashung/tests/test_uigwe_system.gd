extends SceneTree

const UigweManager = preload("res://scripts/UigweManager.gd")
const UigweViewerModal = preload("res://scripts/UigweViewerModal.gd")
const UigwePopup = preload("res://scripts/UigwePopup.gd")
const CourtSystem = preload("res://scripts/CourtSystem.gd")
const SimulationCore = preload("res://scripts/SimulationCore.gd")
const SaveSystem = preload("res://scripts/SaveSystem.gd")
const DifficultyManager = preload("res://scripts/DifficultyManager.gd")
const CityStats = preload("res://scripts/CityStats.gd")

func _init() -> void:
	print("=== [테스트 시작] 규장각 의궤 편찬 국책 게이지 FSM 및 도감 뷰어 시스템 전수 검증 ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	_test_progress_rate_formula()
	_test_prerequisites_check()
	_test_turn_processing_and_financial_pause()
	_test_viewer_modal_and_catalog()
	_test_save_load_serialization()

	print("=== [테스트 완료] 규장각 의궤 편찬 국책 FSM 및 도감 뷰어 시스템 모든 검증 100% 통과! ===")
	quit(0)

## 1. 학문력(0~100) 연동 턴당 진행률 산출식 검증
func _test_progress_rate_formula() -> void:
	print("[검증 1] 학문력 연동 턴당 진행률 선형 보간 공식 검증...")
	var mgr := UigweManager.new()

	# 학문력 0: 턴당 1.25% (80턴 = 20년 소요)
	var rate_0: float = mgr.calculate_turn_rate(0)
	assert(is_equal_approx(rate_0, 1.25), "학문력 0일 때 턴당 1.25%이어야 함. 실제: " + str(rate_0))

	# 학문력 50: 턴당 13.125% (약 7.6턴 소요)
	var rate_50: float = mgr.calculate_turn_rate(50)
	assert(is_equal_approx(rate_50, 13.125), "학문력 50일 때 턴당 13.125%이어야 함. 실제: " + str(rate_50))

	# 학문력 100: 턴당 25.0% (4턴 = 1년 소요)
	var rate_100: float = mgr.calculate_turn_rate(100)
	assert(is_equal_approx(rate_100, 25.0), "학문력 100일 때 턴당 25.0%이어야 함. 실제: " + str(rate_100))

	mgr.queue_free()
	print(" -> [성공] 학문력 0/50/100 턴당 진행률 공식 검증 통과.")

## 2. 기존 선행 조건(연도, 을묘원행, 채제공/정약용, 성곽 축성률) 검증
func _test_prerequisites_check() -> void:
	print("[검증 2] 역사적 선행 해금 조건(1795/1796년, 을묘원행, 인재 등용, 성곽) 검증...")
	var mgr := UigweManager.new()
	var court := CourtSystem.new()
	var sim := SimulationCore.new()
	sim.court_ref = court

	# 1789년 초기: 원행을묘정리의궤, 화성성역의궤 모두 미해금
	sim.current_year = 1789
	court.current_year = 1789
	var prereq_wonhaeng := mgr.check_prerequisites("wonhaeng", court, sim)
	assert(not prereq_wonhaeng["satisfied"], "1789년에는 원행을묘의궤 착수 불가해야 함")

	var prereq_hwaseong := mgr.check_prerequisites("seongyeok", court, sim)
	assert(not prereq_hwaseong["satisfied"], "1789년에는 화성성역의궤 착수 불가해야 함")

	# 원행을묘정리의궤 해금 테스트: 1795년 이후 + 을묘원행 완수
	sim.current_year = 1795
	court.current_year = 1795
	court.milestones["eulmyo1795"] = true
	var prereq_wonhaeng_ok := mgr.check_prerequisites("wonhaeng", court, sim)
	assert(prereq_wonhaeng_ok["satisfied"], "1795년 및 을묘원행 완료 시 원행을묘의궤 편찬 가능해야 함")

	# 화성성역의궤 해금 테스트: 1796년 이후 + 채제공/정약용 등용 + 성곽 80% 이상
	sim.current_year = 1796
	court.current_year = 1796
	sim.fortress_progress = 85
	sim.retainers["chae_jegong"] = true
	sim.retainers["jeong_yakyong"] = true
	var prereq_hwaseong_ok := mgr.check_prerequisites("seongyeok", court, sim)
	assert(prereq_hwaseong_ok["satisfied"], "1796년, 성곽 80%+, 채제공/정약용 등용 시 화성성역의궤 편찬 가능해야 함")

	mgr.queue_free()
	court.queue_free()
	sim.queue_free()
	print(" -> [성공] 역사적 선행 해금 조건 검증 통과.")

## 3. 턴 정산, 연간 비용 차감 및 국고 부족 시 PAUSED 안전 동결 검증
func _test_turn_processing_and_financial_pause() -> void:
	print("[검증 3] 턴 정산, 연간 5,000냥 분할 비용 차감 및 국고 부족 시 안전 PAUSED 검증...")
	var mgr := UigweManager.new()
	var court := CourtSystem.new()
	var sim := SimulationCore.new()
	sim.court_ref = court
	sim.gold = 10000 # 충분한 국고
	sim.current_year = 1795
	court.current_year = 1795
	court.milestones["eulmyo1795"] = true

	# 원행을묘의궤 착수
	var start_res := mgr.start_compilation("wonhaeng", sim, court)
	assert(start_res["success"], "원행을묘의궤 착수 성공해야 함")
	assert(mgr.get_status("wonhaeng") == UigweManager.UigweStatus.COMPILING, "상태는 COMPILING이어야 함")

	# 학문력 100 설정 -> 턴당 +25.0%
	var res1 := mgr.process_turn(sim, 100, court)
	assert(is_equal_approx(mgr.get_progress("wonhaeng"), 25.0), "1턴 후 진행률 25.0%이어야 함. 실제: " + str(mgr.get_progress("wonhaeng")))
	var paid_cost: int = int(res1["wonhaeng"]["cost_paid"])
	assert(paid_cost == 1250, "기본 난이도에서 턴당 1,250냥 정산되어야 함. 실제: " + str(paid_cost))
	assert(sim.gold == 10000 - 1250, "국고가 차감되어야 함")

	# 국고 고갈 상황 연출 (국고 0)
	sim.gold = 0
	mgr.process_turn(sim, 100, court)
	assert(mgr.get_status("wonhaeng") == UigweManager.UigweStatus.PAUSED, "재정 부족 시 PAUSED로 안전 전이되어야 함")
	assert(is_equal_approx(mgr.get_progress("wonhaeng"), 25.0), "진행률은 깎이지 않고 25.0%로 보존되어야 함")

	# 국고 재충전 및 재개
	sim.gold = 50000
	var resume_res := mgr.resume_compilation("wonhaeng", sim)
	assert(resume_res["success"], "재개 성공해야 함")
	assert(mgr.get_status("wonhaeng") == UigweManager.UigweStatus.COMPILING, "상태가 COMPILING으로 복귀해야 함")

	# 나머지 3턴 진행하여 100% 완공 검증
	mgr.process_turn(sim, 100, court) # 50%
	mgr.process_turn(sim, 100, court) # 75%
	mgr.process_turn(sim, 100, court) # 100% 완공
	assert(mgr.get_status("wonhaeng") == UigweManager.UigweStatus.COMPLETED, "100% 도달 시 COMPLETED 상태여야 함")
	assert(mgr.is_completed("wonhaeng"), "is_completed 반환값 true여야 함")
	assert(court.uigwe.get("wonhaeng", false), "CourtSystem의 의궤 완공 플래그도 동기화되어야 함")

	mgr.queue_free()
	court.queue_free()
	sim.queue_free()
	print(" -> [성공] 턴 정산, 비용 차감, PAUSED 동결 및 100% 완공 검증 통과.")

## 4. 의궤 도감 열람 뷰어 모달 데이터 바인딩 검증
func _test_viewer_modal_and_catalog() -> void:
	print("[검증 4] 의궤 뷰어 모달(사진/100자 해설) 데이터 바인딩 검증...")
	var viewer_scene: PackedScene = load("res://scenes/UigweViewerModal.tscn")
	assert(viewer_scene != null, "UigweViewerModal.tscn 씬이 존재해야 함")
	var viewer = viewer_scene.instantiate() as UigweViewerModal

	# 원행을묘정리의궤 열람
	viewer.open_viewer("wonhaeng")
	assert(viewer.visible, "뷰어가 열려야 함")
	var desc_wonhaeng: String = UigweManager.UIGWE_DATA["wonhaeng"]["description"]
	assert(desc_wonhaeng.length() >= 70 and desc_wonhaeng.length() <= 150, "원행을묘 해설문은 100자 내외여야 함: %d자" % desc_wonhaeng.length())

	# 화성성역의궤 열람
	viewer.open_viewer("seongyeok")
	var desc_hwaseong: String = UigweManager.UIGWE_DATA["seongyeok"]["description"]
	assert(desc_hwaseong.length() >= 70 and desc_hwaseong.length() <= 150, "화성성역 해설문은 100자 내외여야 함: %d자" % desc_hwaseong.length())

	viewer.close_viewer()
	assert(not viewer.visible, "뷰어 닫기 시 invisible이어야 함")
	viewer.queue_free()
	print(" -> [성공] 의궤 뷰어 모달 데이터 바인딩 및 100자 해설 검증 통과.")

## 5. 세이브/로드 직렬화 및 역직렬화 무결성 검증
func _test_save_load_serialization() -> void:
	print("[검증 5] 의궤 편찬 데이터 세이브/로드 직렬화 및 역직렬화 무결성 검증...")
	var mgr := UigweManager.new()
	mgr.set_progress("wonhaeng", 45.5)
	mgr.set_status("wonhaeng", UigweManager.UigweStatus.COMPILING)
	mgr.set_progress("seongyeok", 100.0)
	mgr.set_status("seongyeok", UigweManager.UigweStatus.COMPLETED)

	var saved_data := mgr.serialize()
	assert(saved_data.has("items"), "직렬화 데이터에 items 키가 있어야 함")
	assert(is_equal_approx(saved_data["items"]["wonhaeng"]["progress"], 45.5), "원행을묘 진행도 보존 확인")
	assert(saved_data["items"]["seongyeok"]["status"] == UigweManager.UigweStatus.COMPLETED, "화성성역 상태 보존 확인")

	# 신규 인스턴스에 복원
	var loaded_mgr := UigweManager.new()
	loaded_mgr.deserialize(saved_data)
	assert(is_equal_approx(loaded_mgr.get_progress("wonhaeng"), 45.5), "복원 후 진행도 45.5% 일치 확인")
	assert(loaded_mgr.get_status("wonhaeng") == UigweManager.UigweStatus.COMPILING, "복원 후 상태 일치 확인")
	assert(loaded_mgr.is_completed("seongyeok"), "복원 후 완공 상태 일치 확인")

	mgr.queue_free()
	loaded_mgr.queue_free()
	print(" -> [성공] 세이브/로드 직렬화 및 복원 검증 통과.")
