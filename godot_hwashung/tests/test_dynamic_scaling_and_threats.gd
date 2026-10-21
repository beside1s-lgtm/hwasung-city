extends SceneTree

const DifficultyManagerClass = preload("res://scripts/DifficultyManager.gd")
const CityStatsClass = preload("res://scripts/CityStats.gd")
const ResourceManagerClass = preload("res://scripts/ResourceManager.gd")
const SunlacheongManagerClass = preload("res://scripts/SunlacheongManager.gd")
const MarketDisputeEventClass = preload("res://scripts/MarketDisputeEvent.gd")
const MarketManagerClass = preload("res://scripts/MarketManager.gd")
const BanditManagerClass = preload("res://scripts/BanditManager.gd")
const SimulationCoreClass = preload("res://scripts/SimulationCore.gd")

func _init() -> void:
	print("=== [테스트 시작] 동적 난이도·성장 비례 위협 스케일링 엔진 및 민심 획득 감쇠 검증 ===")
	call_deferred("_run_tests")

func _run_tests() -> void:
	_test_population_crime_scaling()
	_test_security_deficit_penalties()
	_test_morale_drag_scaling()
	_test_wealth_paradox_bandit_scaling()
	_test_caravan_raid_losses_and_non_negative()
	_test_early_game_protection_rule()
	_test_simulation_core_turn_caching()

	print("=== [테스트 완료] 7대 Acceptance Criteria 전 항목 100% 통과! ===")
	quit(0)

## 1. 인구 10만 초과 비례 범죄율 및 상한선 검증
func _test_population_crime_scaling() -> void:
	print("[검증 1] 인구 10만 초과 비례 범죄율 및 상한선 검증...")

	# 인구 10만 이하: 추가 범죄율 0.0
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.NORMAL)
	assert(DifficultyManagerClass.get_crime_rate_modifier(50000) == 0.0, "인구 5만에서 추가 범죄율은 0이어야 함")
	assert(DifficultyManagerClass.get_crime_rate_modifier(100000) == 0.0, "인구 10만에서 추가 범죄율은 0이어야 함")

	# 인구 20만 (초과 10만 = 10단위)
	# 쉬움: 10 * 0.005 = 0.05 (+5%)
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.EASY)
	assert(is_equal_approx(DifficultyManagerClass.get_crime_rate_modifier(200000), 0.05), "쉬움 20만 범죄율 +5% 불일치")

	# 보통: 10 * 0.010 = 0.10 (+10%)
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.NORMAL)
	assert(is_equal_approx(DifficultyManagerClass.get_crime_rate_modifier(200000), 0.10), "보통 20만 범죄율 +10% 불일치")

	# 어려움: 10 * 0.015 = 0.15 (+15%)
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.HARD)
	assert(is_equal_approx(DifficultyManagerClass.get_crime_rate_modifier(200000), 0.15), "어려움 20만 범죄율 +15% 불일치")

	# 극단적 인구 (1,000,000명) 상한선 (Hard Cap) 검증
	# 쉬움 상한 +20% (0.20)
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.EASY)
	assert(is_equal_approx(DifficultyManagerClass.get_crime_rate_modifier(1000000), 0.20), "쉬움 범죄율 상한 20% 초과 오류")

	# 보통 상한 +30% (0.30)
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.NORMAL)
	assert(is_equal_approx(DifficultyManagerClass.get_crime_rate_modifier(1000000), 0.30), "보통 범죄율 상한 30% 초과 오류")

	# 어려움 상한 +40% (0.40)
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.HARD)
	assert(is_equal_approx(DifficultyManagerClass.get_crime_rate_modifier(1000000), 0.40), "어려움 범죄율 상한 40% 초과 오류")

	print("  - [PASS] 인구 비례 범죄율 및 Hard Cap 검증 성공")

## 2. 순라청 및 화성유수부 결핍 시 피해 증폭 검증
func _test_security_deficit_penalties() -> void:
	print("[검증 2] 순라청 및 화성유수부 결핍 시 피해 증폭 검증...")

	# 결핍 배율 확인
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.EASY)
	assert(is_equal_approx(DifficultyManagerClass.get_security_deficit_penalty_multiplier(), 1.0), "쉬움 결핍 배율 1.0 불일치")
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.NORMAL)
	assert(is_equal_approx(DifficultyManagerClass.get_security_deficit_penalty_multiplier(), 1.5), "보통 결핍 배율 1.5 불일치")
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.HARD)
	assert(is_equal_approx(DifficultyManagerClass.get_security_deficit_penalty_multiplier(), 2.0), "어려움 결핍 배율 2.0 불일치")

	# SunlacheongManager 인스턴스 테스트
	var sunla := SunlacheongManagerClass.new()
	var sim := SimulationCoreClass.new()
	sim.loyalty = 80
	var ev := MarketDisputeEventClass.new()
	ev.setup_event(1, MarketDisputeEventClass.DisputeType.BRAWL, Vector2i(10, 10))
	ev.assigned_officer_id = -1 # 미출동

	# 순라청 0개, 관아 정상 존재하는 경우 (순라청 결핍 테스트)
	sunla.patrol_stations.clear()
	sunla.gwana_positions = [Vector2i(20, 20)]

	# 보통 난이도: 민심 -3 (기본 2 * 1.5), 세수 -15%
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.NORMAL)
	sim.loyalty = 80
	sunla._on_dispute_failed(ev, sim)
	assert(sim.loyalty == 77, "보통 순라청 결핍 시 민심 3 감소 실패 (현재 %d)" % sim.loyalty)
	assert(is_equal_approx(MarketManagerClass.get_dispute_tax_multiplier(), 0.85), "보통 세수 -15% (0.85) 실패")

	# 어려움 난이도: 민심 -4 (기본 2 * 2.0), 세수 -20%
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.HARD)
	sim.loyalty = 80
	sunla._on_dispute_failed(ev, sim)
	assert(sim.loyalty == 76, "어려움 순라청 결핍 시 민심 4 감소 실패 (현재 %d)" % sim.loyalty)
	assert(is_equal_approx(MarketManagerClass.get_dispute_tax_multiplier(), 0.80), "어려움 세수 -20% (0.80) 실패")

	# 관아 부재 시: 추가 민심 -3 및 상업 전면 마비 (multiplier == 0.0)
	sunla.gwana_positions.clear() # 관아 없음
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.NORMAL)
	sim.loyalty = 80
	sunla._on_dispute_failed(ev, sim)
	# 민심: 80 - (3 + 3) = 74
	assert(sim.loyalty == 74, "관아 부재 시 추가 민심 -3 실패 (현재 %d)" % sim.loyalty)
	assert(MarketManagerClass.get_dispute_tax_multiplier() == 0.0, "관아 부재 시 상업 마비 (0.0) 실패")

	# 1턴 경과 시 정상 회복
	MarketManagerClass.dispute_penalty_turns = 0
	MarketManagerClass.is_market_paralyzed = false
	assert(MarketManagerClass.get_dispute_tax_multiplier() == 1.0, "페널티 종료 후 정상 세수 배율 복귀 실패")

	print("  - [PASS] 순라청/유수부 결핍 피해 배율 및 관아 상업 마비 검증 성공")

## 3. 도시 규모 및 난이도 연동 민심 획득 감쇠 (Morale Drag) 검증
func _test_morale_drag_scaling() -> void:
	print("[검증 3] 도시 규모 및 난이도 연동 민심 획득 감쇠 (Morale Drag) 검증...")

	# 인구 10만 이하: 기본 승수 그대로
	# 쉬움: 1.0, 보통: 0.85, 어려움: 0.70
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.EASY)
	assert(is_equal_approx(DifficultyManagerClass.get_morale_gain_multiplier(50000), 1.0), "쉬움 기본 승수 1.0 불일치")
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.NORMAL)
	assert(is_equal_approx(DifficultyManagerClass.get_morale_gain_multiplier(50000), 0.85), "보통 기본 승수 0.85 불일치")
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.HARD)
	assert(is_equal_approx(DifficultyManagerClass.get_morale_gain_multiplier(50000), 0.70), "어려움 기본 승수 0.70 불일치")

	# 인구 40만: 초과 30만 -> 감쇠율 = 30만 / 100만 = 0.30
	# 보통: 0.85 * (1.0 - 0.30) = 0.85 * 0.70 = 0.595
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.NORMAL)
	var mult_400k: float = DifficultyManagerClass.get_morale_gain_multiplier(400000)
	assert(is_equal_approx(mult_400k, 0.85 * 0.70), "보통 40만 인구 감쇠 불일치: %f" % mult_400k)

	# 100만 명 초과 시에도 감쇠율 최대 30% 상한 유지
	var mult_1m: float = DifficultyManagerClass.get_morale_gain_multiplier(1500000)
	assert(is_equal_approx(mult_1m, 0.85 * 0.70), "감쇠율 30%% 상한 유지 실패: %f" % mult_1m)

	# CityStats.calculate_morale_gain 검증 (기본 10점 획득 시)
	# 보통 10만 이하: 10 * 0.85 = 8.5 -> round(8.5) = 9
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.NORMAL)
	var gain_normal: int = CityStatsClass.calculate_morale_gain(10, 50000)
	assert(gain_normal == 9, "보통 인구 5만 민심 10점 획득 시 9점이어야 함: %d" % gain_normal)

	# 어려움 10만 이하: 10 * 0.70 = 7.0 -> 7
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.HARD)
	var gain_hard: int = CityStatsClass.calculate_morale_gain(10, 50000)
	assert(gain_hard == 7, "어려움 인구 5만 민심 10점 획득 시 7점이어야 함: %d" % gain_hard)

	# SimulationCore.add_morale 연동 검증
	var sim := SimulationCoreClass.new()
	sim.loyalty = 50
	sim.population = 50000
	sim.add_morale(10)
	assert(sim.loyalty == 57, "add_morale 적용 결과 57이어야 함: %d" % sim.loyalty)

	# 음수(패널티)는 감쇠 없이 그대로 차감되어야 함
	sim.add_morale(-5)
	assert(sim.loyalty == 52, "음수 민심 차감 시 감쇠 없이 차감되어야 함: %d" % sim.loyalty)

	print("  - [PASS] 민심 획득 감쇠(Morale Drag) 및 가산 함수 검증 성공")

## 4. 국부(금화·곡식 10만+) 비례 도적 스케일링 검증
func _test_wealth_paradox_bandit_scaling() -> void:
	print("[검증 4] 국부(금화·곡식 10만+) 비례 도적 스케일링 (부의 역설) 검증...")

	# 10만 이하: 초과 부 0 및 가산 확률 0.0%
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.NORMAL)
	assert(DifficultyManagerClass.get_threat_escalation(50000, 50000) == 0.0, "10만 이하 초과 가산 0%이어야 함")
	assert(DifficultyManagerClass.get_threat_escalation(100000, 100000) == 0.0, "10만 이하 초과 가산 0%이어야 함")

	# 금 15만, 곡 15만: W_excess = 5만 + 5만 = 10만 -> 2만 단위당 5단위
	# 쉬움: 5 * 0.005 = 0.025 (+2.5%)
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.EASY)
	assert(is_equal_approx(DifficultyManagerClass.get_threat_escalation(150000, 150000), 0.025), "쉬움 초과 부 가산 2.5% 불일치")

	# 보통: 5 * 0.010 = 0.050 (+5.0%)
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.NORMAL)
	assert(is_equal_approx(DifficultyManagerClass.get_threat_escalation(150000, 150000), 0.050), "보통 초과 부 가산 5.0% 불일치")

	# 어려움: 5 * 0.020 = 0.100 (+10.0%)
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.HARD)
	assert(is_equal_approx(DifficultyManagerClass.get_threat_escalation(150000, 150000), 0.100), "어려움 초과 부 가산 10.0% 불일치")

	# 최대 가산 확률 상한 25% (0.25) 검증
	assert(is_equal_approx(DifficultyManagerClass.get_threat_escalation(1000000, 1000000), 0.25), "위협 가산 상한 25% 초과 불가 검증 실패")

	print("  - [PASS] 국부 비례 도적 스폰 확률 가산 및 상한선 검증 성공")

## 5. 상단 약탈 시 초과 부 비례 추가 피해 및 음수 방어 검증
func _test_caravan_raid_losses_and_non_negative() -> void:
	print("[검증 5] 상단 약탈 시 초과 부 비례 추가 피해 및 음수 방어 검증...")

	var sim := SimulationCoreClass.new()
	sim.turn = 10
	sim.current_year = 1792
	sim.bandit_suppression_turns = 0

	# 1) 초과 부 없을 때 (금화 50,000, 곡식 50,000)
	sim.gold = 50000
	sim.rice = 50000
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.NORMAL)
	var losses_normal := BanditManagerClass.calculate_caravan_raid_losses(sim)
	assert(losses_normal["base_gold"] == 5000, "기본 약탈 금화 5000 불일치")
	assert(losses_normal["base_rice"] == 5000, "기본 약탈 곡식 5000 불일치")
	assert(losses_normal["extra_gold"] == 0, "초과 부 없으므로 추가 금화 약탈 0이어야 함")
	assert(losses_normal["extra_rice"] == 0, "초과 부 없으므로 추가 곡식 약탈 0이어야 함")

	# 2) 초과 부 있을 때: 금화 200,000 (초과 10만), 곡식 200,000 (초과 10만)
	# 보통: 초과분의 2% = 2,000냥/석 추가 약탈 -> 총 7,000냥/석
	sim.gold = 200000
	sim.rice = 200000
	var losses_excess := BanditManagerClass.calculate_caravan_raid_losses(sim)
	assert(losses_excess["extra_gold"] == 2000, "보통 추가 금화 2000 불일치: %d" % losses_excess["extra_gold"])
	assert(losses_excess["extra_rice"] == 2000, "보통 추가 곡식 2000 불일치: %d" % losses_excess["extra_rice"])
	assert(losses_excess["total_gold"] == 7000, "보통 총 금화 약탈 7000 불일치")
	assert(losses_excess["total_rice"] == 7000, "보통 총 곡식 약탈 7000 불일치")

	# 어려움: 초과분의 3% = 3,000냥/석 추가 약탈 -> 총 8,000냥/석
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.HARD)
	var losses_hard := BanditManagerClass.calculate_caravan_raid_losses(sim)
	assert(losses_hard["extra_gold"] == 3000, "어려움 추가 금화 3000 불일치: %d" % losses_hard["extra_gold"])
	assert(losses_hard["extra_rice"] == 3000, "어려움 추가 곡식 3000 불일치: %d" % losses_hard["extra_rice"])
	assert(losses_hard["total_gold"] == 8000, "어려움 총 금화 약탈 8000 불일치")

	# 3) 자원 부족 시 음수 방어 검증 (금화 2,000냥 보유 시 2,000냥만 털리고 0이 됨)
	sim.gold = 2000
	sim.rice = 1500
	var raid_res := BanditManagerClass.apply_caravan_raid(sim)
	assert(raid_res["success"] == true, "약탈 실행 실패")
	assert(sim.gold == 0, "금화 0 미만 음수 방어 실패: %d" % sim.gold)
	assert(sim.rice == 0, "곡식 0 미만 음수 방어 실패: %d" % sim.rice)

	print("  - [PASS] 상단 약탈 추가 피해 계산 및 자원 음수 방어 검증 성공")

## 6. 게임 시작 후 2년(8턴) 도적/약탈 면역 초반 보호 검증
func _test_early_game_protection_rule() -> void:
	print("[검증 6] 게임 시작 후 2년(8턴) 도적/약탈 면역 초반 보호 검증...")

	var sim := SimulationCoreClass.new()
	sim.turn = 4 # 1년차
	sim.current_year = 1789
	sim.gold = 300000 # 천문학적 부
	sim.rice = 300000

	# 어떤 난이도에서도 초반 2년(turn <= 8)에는 스폰 확률 0.0%
	for diff in [DifficultyManagerClass.Difficulty.EASY, DifficultyManagerClass.Difficulty.NORMAL, DifficultyManagerClass.Difficulty.HARD]:
		DifficultyManagerClass.set_difficulty(diff)
		var chance: float = BanditManagerClass.calculate_bandit_spawn_chance(sim, true)
		assert(chance == 0.0, "초반 2년 내 도적 스폰 확률은 반드시 0.0이어야 함 (난이도 %d)" % diff)

		var raid_res := BanditManagerClass.apply_caravan_raid(sim)
		assert(raid_res["protected"] == true, "초반 2년 내 상단 약탈은 면역 보호되어야 함")
		assert(sim.gold == 300000, "약탈 면역 중 자원 차감 발생 오류")

	print("  - [PASS] 초반 2년(8턴) 도적/약탈 면역 100% 보장 검증 성공")

## 7. SimulationCore 턴 정산 시 O(1) 캐싱 검증
func _test_simulation_core_turn_caching() -> void:
	print("[검증 7] SimulationCore 턴 정산 시 O(1) 캐싱 검증...")

	var sim := SimulationCoreClass.new()
	sim.turn = 10
	sim.population = 200000 # 20만 인구
	sim.gold = 150000       # 15만 금화
	sim.rice = 150000       # 15만 곡식
	sim.tax_rate_land = 4   # 총 세율 12%로 조세 저항 임계치(14%) 미만 유지
	sim.tax_rate_market = 4
	sim.tax_rate_military = 4
	DifficultyManagerClass.set_difficulty(DifficultyManagerClass.Difficulty.NORMAL)

	var res: Dictionary = sim.process_turn_economy()
	assert(res.has("dynamic_scaling"), "process_turn_economy 반환값에 dynamic_scaling 누락")

	var dyn: Dictionary = res["dynamic_scaling"]
	assert(is_equal_approx(dyn["crime_rate_bonus"], 0.10), "캐시된 범죄율 보너스 불일치: %f" % dyn["crime_rate_bonus"])
	assert(is_equal_approx(sim.cached_crime_rate_bonus, 0.10), "sim 변수 범죄율 캐시 불일치")
	assert(is_equal_approx(dyn["threat_escalation"], 0.05), "캐시된 위협 가산 확률 불일치: %f" % dyn["threat_escalation"])
	assert(is_equal_approx(sim.cached_threat_escalation, 0.05), "sim 변수 위협 캐시 불일치")

	print("  - [PASS] SimulationCore O(1) 턴 캐싱 연동 검증 성공")
