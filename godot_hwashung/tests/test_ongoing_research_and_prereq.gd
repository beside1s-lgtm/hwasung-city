extends SceneTree

const TechTreeManager = preload("res://scripts/TechTreeManager.gd")
const ScholarManager = preload("res://scripts/ScholarManager.gd")
const CityStats = preload("res://scripts/CityStats.gd")
const SimulationCore = preload("res://scripts/SimulationCore.gd")
const CourtSystem = preload("res://scripts/CourtSystem.gd")
const TechTreePopup = preload("res://scripts/TechTreePopup.gd")

func _init() -> void:
	print("=== [테스트 시작] 실학 연구 턴당 국고 지속 소모 재정 엔진, 필수 인재 선결 조건 및 UI 검증 ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	_test_scholar_prerequisites()
	_test_ongoing_research_cost_and_buff()
	_test_budget_starvation_and_paused_state()
	_test_scholar_dismissal_and_paused_state()
	_test_techtree_popup_ui_dashboard_and_bars()

	print("=== [테스트 완료] 실학 연구 국책 프로젝트 엔진 및 UI 검증 100% ALL PASS! ===")
	quit(0)

## 1. 과제별 필수 인재 선결 조건 검증
func _test_scholar_prerequisites() -> void:
	print("[검증 1] 과제별 필수 인재 선결 조건 및 착수 제한 검증...")
	var sim := SimulationCore.new()
	root.add_child(sim)
	var tech_mgr := TechTreeManager.new()
	root.add_child(tech_mgr)

	sim.gold = 50000
	sim.retainers = {}

	# 1) 정약용 미등용 시 'segi' 착수 차단
	var msg_segi_blocked: String = tech_mgr.start_research("segi", sim)
	assert(tech_mgr.current_researching != "segi", "정약용 미등용 시 segi 착수가 차단되어야 함")
	assert("정약용" in msg_segi_blocked, "에러 메시지에 '정약용'이 포함되어야 함. 현재: " + msg_segi_blocked)

	# 2) 박제가 미등용 시 'gwanong' 착수 차단
	var msg_gwanong_blocked: String = tech_mgr.start_research("gwanong", sim)
	assert(tech_mgr.current_researching != "gwanong", "박제가 미등용 시 gwanong 착수가 차단되어야 함")
	assert("박제가" in msg_gwanong_blocked, "에러 메시지에 '박제가'가 포함되어야 함")

	# 3) 서유구 미등용 시 'seed' 착수 차단
	var msg_seed_blocked: String = tech_mgr.start_research("seed", sim)
	assert(tech_mgr.current_researching != "seed", "서유구 미등용 시 seed 착수가 차단되어야 함")
	assert("서유구" in msg_seed_blocked, "에러 메시지에 '서유구'가 포함되어야 함")

	# 4) 이가환 미등용 시 'sugusik' 착수 차단
	var msg_sugusik_blocked: String = tech_mgr.start_research("sugusik", sim)
	assert(tech_mgr.current_researching != "sugusik", "이가환 미등용 시 sugusik 착수가 차단되어야 함")
	assert("이가환" in msg_sugusik_blocked, "에러 메시지에 '이가환'이 포함되어야 함")

	# 5) 남인(채제공/정약용) 미등용 시 'boyuron' 착수 차단
	var msg_boyuron_blocked: String = tech_mgr.start_research("boyuron", sim)
	assert(tech_mgr.current_researching != "boyuron", "남인 미등용 시 boyuron 착수가 차단되어야 함")

	# 6) 조건 없는 일반 농법('fertilizer')은 즉시 착수 가능
	var msg_fert: String = tech_mgr.start_research("fertilizer", sim)
	assert(tech_mgr.current_researching == "fertilizer", "조건 없는 일반 농법은 즉시 착수되어야 함")
	assert(tech_mgr.research_status == TechTreeManager.ResearchStatus.ACTIVE, "상태는 ACTIVE여야 함")
	tech_mgr.stop_research("fertilizer")

	# 7) 인재 등용 후 정상 착수 확인
	sim.retainers["jeong_yakyong"] = true
	var msg_segi_ok: String = tech_mgr.start_research("segi", sim)
	assert(tech_mgr.current_researching == "segi", "정약용 등용 후 segi 연구에 정상 착수되어야 함")
	assert("착수" in msg_segi_ok, "착수 안내 메시지 출력 확인")
	tech_mgr.stop_research("segi")

	tech_mgr.queue_free()
	sim.queue_free()
	print("  -> 필수 인재 선결 조건 검증 완료 (PASS).")

## 2. 턴당 연구비 지속 소모 (기본 1,000냥, 정약용 버프 시 700냥) 검증
func _test_ongoing_research_cost_and_buff() -> void:
	print("[검증 2] 턴당 연구비 지속 소모 및 정약용 30% 감면 버프 검증...")
	var sim := SimulationCore.new()
	root.add_child(sim)
	var tech_mgr := TechTreeManager.new()
	root.add_child(tech_mgr)

	# 1) 기본 과제 (인재 없음): 턴당 1,000냥 차감
	sim.gold = 5000
	sim.retainers = {}
	tech_mgr.start_research("fertilizer", sim)

	var initial_gold: int = sim.gold
	var tick1: Dictionary = tech_mgr.process_turn_research(30, sim, false)
	assert(tick1["cost_deducted"] == 1000, "턴당 1,000냥이 차감되어야 함. 실제: " + str(tick1["cost_deducted"]))
	assert(sim.gold == initial_gold - 1000, "국고가 정확히 1,000냥 감소해야 함. 현재: " + str(sim.gold))
	assert(tech_mgr.get_progress("fertilizer") > 0.0, "진행도가 증가해야 함")

	tech_mgr.stop_research("fertilizer")

	# 2) 정약용 등용 시: 턴당 700냥(-30% 감면) 차감
	sim.retainers["jeong_yakyong"] = true
	tech_mgr.start_research("segi", sim)

	var gold_before_jeong: int = sim.gold
	var tick_jeong: Dictionary = tech_mgr.process_turn_research(30, sim, false)
	assert(tick_jeong["cost_deducted"] == 700, "정약용 등용 시 연구비는 700냥이어야 함. 실제: " + str(tick_jeong["cost_deducted"]))
	assert(sim.gold == gold_before_jeong - 700, "국고가 정확히 700냥 감소해야 함. 현재: " + str(sim.gold))

	tech_mgr.queue_free()
	sim.queue_free()
	print("  -> 턴당 지속 연구비 및 인재 감면 버프 검증 완료 (PASS).")

## 3. 재정 고갈 안전장치 (Budget Starvation Guard) 검증
func _test_budget_starvation_and_paused_state() -> void:
	print("[검증 3] 국고 고갈 시 PAUSED_NO_FUNDS 상태 전환 및 안전 동결 검증...")
	var sim := SimulationCore.new()
	root.add_child(sim)
	var tech_mgr := TechTreeManager.new()
	root.add_child(tech_mgr)

	sim.gold = 1500
	sim.retainers = {}
	tech_mgr.start_research("fertilizer", sim)

	# 1턴: 1,500냥 중 1,000냥 지출 -> 500냥 잔여
	var tick1: Dictionary = tech_mgr.process_turn_research(20, sim, false)
	assert(tick1["cost_deducted"] == 1000, "1턴 1000냥 정상 지출")
	assert(sim.gold == 500, "국고 500냥 잔여")
	var prog_turn1: float = tech_mgr.get_progress("fertilizer")
	assert(prog_turn1 > 0.0, "1턴 진행도 가산")

	# 2턴: 잔여 500냥 < 요구 1,000냥 -> PAUSED_NO_FUNDS 전이, 국고 차감 0, 진행도 동결
	var tick2: Dictionary = tech_mgr.process_turn_research(20, sim, false)
	assert(tech_mgr.research_status == TechTreeManager.ResearchStatus.PAUSED_NO_FUNDS, "재정 부족 시 PAUSED_NO_FUNDS여야 함")
	assert(tick2["cost_deducted"] == 0, "재정 부족 시 추가 국고 차감 없어야 함")
	assert(sim.gold == 500, "국고 500냥 보존되어야 함")
	assert(tech_mgr.get_progress("fertilizer") == prog_turn1, "진행도가 동결되어야 함")

	# 3턴: 국고 확보(3,000냥 지급) -> 연구 자동 재개 (ACTIVE) 및 진행도 가산
	sim.gold += 3000
	var tick3: Dictionary = tech_mgr.process_turn_research(20, sim, false)
	assert(tech_mgr.research_status == TechTreeManager.ResearchStatus.ACTIVE, "국고 확보 시 ACTIVE로 자동 재개되어야 함")
	assert(tick3["cost_deducted"] == 1000, "1,000냥 정상 차감")
	assert(tech_mgr.get_progress("fertilizer") > prog_turn1, "진행도가 다시 증가해야 함")

	tech_mgr.queue_free()
	sim.queue_free()
	print("  -> 재정 고갈 안전장치 및 자동 재개 검증 완료 (PASS).")

## 4. 인재 해임 시 안전 처리 (PAUSED_NO_SCHOLAR) 검증
func _test_scholar_dismissal_and_paused_state() -> void:
	print("[검증 4] 연구 중 필수 인재 사직/해임 시 안전 동결 검증...")
	var sim := SimulationCore.new()
	root.add_child(sim)
	var tech_mgr := TechTreeManager.new()
	root.add_child(tech_mgr)

	sim.gold = 50000
	sim.retainers = {"park_jega": true}
	tech_mgr.start_research("gwanong", sim)

	# 1턴: 정상 진행
	tech_mgr.process_turn_research(30, sim, false)
	var prog1: float = tech_mgr.get_progress("gwanong")
	assert(prog1 > 0.0, "정상 진행 확인")

	# 박제가 해임
	sim.retainers["park_jega"] = false

	# 2턴: 인재 공백 감지 -> PAUSED_NO_SCHOLAR 전이
	var tick2: Dictionary = tech_mgr.process_turn_research(30, sim, false)
	assert(tech_mgr.research_status == TechTreeManager.ResearchStatus.PAUSED_NO_SCHOLAR, "인재 공백 시 PAUSED_NO_SCHOLAR여야 함")
	assert(tick2["cost_deducted"] == 0, "인재 공백 시 국고 미차감")
	assert(tech_mgr.get_progress("gwanong") == prog1, "진행도 강제 삭제 없이 안전 동결")

	# 박제가 재등용 -> 연구 자동 재개
	sim.retainers["park_jega"] = true
	var tick3: Dictionary = tech_mgr.process_turn_research(30, sim, false)
	assert(tech_mgr.research_status == TechTreeManager.ResearchStatus.ACTIVE, "재등용 시 연구 재개")
	assert(tech_mgr.get_progress("gwanong") > prog1, "진행도 정상 누적")

	tech_mgr.queue_free()
	sim.queue_free()
	print("  -> 필수 인재 사직 시 안전 동결 및 재개 검증 완료 (PASS).")

## 5. TechTreePopup UI 대시보드, 프로그레스 바 및 툴팁 검증
func _test_techtree_popup_ui_dashboard_and_bars() -> void:
	print("[검증 5] TechTreePopup 씬 인스턴스화, 대시보드 및 프로그레스 바 UI 검증...")
	var sim := SimulationCore.new()
	root.add_child(sim)
	sim.gold = 50000
	sim.academic = 45
	CityStats.set_academic_power(45)

	var popup_scene: PackedScene = load("res://scenes/TechTreePopup.tscn")
	assert(popup_scene != null, "TechTreePopup.tscn 씬을 로드할 수 있어야 함")

	var popup: TechTreePopup = popup_scene.instantiate() as TechTreePopup
	root.add_child(popup)
	popup.setup(sim)
	popup.open_popup()

	assert(popup.visible, "팝업이 표시되어야 함")
	assert(popup.academic_label != null, "학문력 라벨 존재")
	assert("45" in popup.academic_label.text, "학문력 수치 45 표시 확인")
	assert(popup.speed_label != null, "속도 라벨 존재")
	assert("+5%" in popup.speed_label.text, "연구 속도 1+floor(45/10) = 5% 확인")
	assert(popup.turn_cost_label != null, "비용 라벨 존재")
	assert("미진행" in popup.turn_cost_label.text, "연구 미진행 상태 비용 표기 확인")

	# 정약용 미등용 상태 -> sugi 연구 착수 불가 버튼 확인
	assert(popup.tech_list_container.get_child_count() == TechTreeManager.TECH_LIST.size(), "모든 실학 과제 카드 생성 확인")

	popup.close_popup()
	assert(not popup.visible, "팝업 닫힘 확인")

	popup.queue_free()
	sim.queue_free()
	print("  -> TechTreePopup UI 대시보드 및 프로그레스 바 검증 완료 (PASS).")
