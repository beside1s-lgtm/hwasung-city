extends SceneTree

## 근대화 시대(1820~1945) 밸런스 점검 — 게임을 띄우지 않고 공식만으로 수천 번 돌려 숫자를 본다.
## 실행: Godot --headless --path godot_hwashung --script res://tools/modern_balance_sim.gd
## 공식은 ModernizationManager·UrbanEvolutionManager의 상수를 그대로 읽는다(값을 바꾸면 결과도 바뀜).
## 가정(시나리오별): 시작 국방력(성곽+장용영+순라청), 해마다 늘리는 국방력, 문화재 보수 횟수, 외교 성공률.
## 신뢰도 10이 되면 3년에 한 나라꼴로 동맹을 맺는다고 본다(동맹 1국당 원군 500).

const RUNS := 2000

const SCENARIOS := [
	{"name": "약한 도시(국방 600, +5/년, 보수 없음)", "def0": 600, "def_per_year": 5, "restore_per_year": 0, "dipl_rate": 0.45, "accel": 1.0},
	{"name": "보통 도시(국방 1000, +15/년, 보수 2년에 1번)", "def0": 1000, "def_per_year": 15, "restore_per_year": 0.5, "dipl_rate": 0.60, "accel": 4.0},
	{"name": "강한 도시(국방 1500, +25/년, 해마다 보수)", "def0": 1500, "def_per_year": 25, "restore_per_year": 1.0, "dipl_rate": 0.80, "accel": 8.0},
]

func _init() -> void:
	print("=== 근대화 시대 밸런스 점검 (%d회씩) ===" % RUNS)
	for sc: Dictionary in SCENARIOS:
		_run(sc)
	print("\n[석조 전환 100%%에 걸리는 해] 가속 점수 0: %d년, 3: %d년, 6: %d년, 10: %d년 (그 뒤 대도시화도 같은 속도)" % [_years_to_full(0.0), _years_to_full(3.0), _years_to_full(6.0), _years_to_full(10.0)])
	print("[침공 확률] 신뢰도 0: %d%%, 5: %d%%, 10: %d%%" % [int(_chance(0) * 100), int(_chance(5) * 100), int(_chance(10) * 100)])
	quit()

func _chance(trust: int) -> float:
	return 0.50 - 0.045 * float(trust)

func _years_to_full(score: float) -> int:
	return int(ceil(100.0 / (1.0 + score)))

func _run(sc: Dictionary) -> void:
	var survived := 0
	var died_1875 := 0
	var invasions_total := 0
	var heritage_sum := 0.0
	var trust_at_1875 := 0.0
	var first_unlock_sum := 0.0
	for r in range(RUNS):
		var defense: float = sc["def0"]
		var trust := 0
		var unlocked := false
		var heritage := 100.0
		var alive := true
		var unlock_year := 0
		var allies := 0
		for y in range(ModernizationManager.START_YEAR + 1, ModernizationManager.FINAL_YEAR):
			defense += float(sc["def_per_year"])
			heritage -= UrbanEvolutionManager.HERITAGE_DECAY_PER_YEAR
			if randf() < float(sc["restore_per_year"]):
				heritage = minf(100.0, heritage + UrbanEvolutionManager.HERITAGE_RESTORE_STEP)
			var atk := -1.0
			var mult := 1.0
			if y == ModernizationManager.JAPAN_INVASION_YEAR:
				mult = 2.0
				atk = (400.0 + (y - 1820) * 15.0 + randf_range(-30, 30)) * mult
				trust_at_1875 += trust
			elif y != ModernizationManager.JAPAN_TREATY_YEAR and randf() < _chance(trust):
				atk = 400.0 + (y - 1820) * 15.0 + randf_range(-30, 30)
			if atk > 0.0:
				invasions_total += 1
				if defense + allies * ModernizationManager.ALLY_REINFORCEMENT >= atk:
					heritage -= ModernizationManager.INVASION_HERITAGE_DAMAGE * mult
					if not unlocked:
						unlocked = true
						unlock_year = y
				else:
					alive = false
					if y == ModernizationManager.JAPAN_INVASION_YEAR:
						died_1875 += 1
					break
			if unlocked:
				for i in range(4): # 3달에 한 번 회담
					if randf() < float(sc["dipl_rate"]):
						trust = mini(10, trust + 1)
			if trust >= 10 and allies < ModernizationManager.MAX_ALLIES and randf() < 0.33: # 신뢰도 10이면 3년에 한 나라꼴로 동맹(문답 성공 가정)
				allies += 1
			heritage = maxf(0.0, heritage)
		if alive:
			survived += 1
			heritage_sum += heritage
		first_unlock_sum += unlock_year
	print("\n▶ %s" % sc["name"])
	print("  1945까지 생존 %.1f%%, 1875 일본 침공에서 멸망 %.1f%%, 평균 침공 %.1f회" % [survived * 100.0 / RUNS, died_1875 * 100.0 / RUNS, float(invasions_total) / RUNS])
	print("  외교 해금 평균 %d년, 1875년 평균 신뢰도 %.1f, 생존 시 1945 문화재 보존도 평균 %.0f%%" % [int(first_unlock_sum / RUNS), trust_at_1875 / RUNS, heritage_sum / maxf(1.0, survived)])
