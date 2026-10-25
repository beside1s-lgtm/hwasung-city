extends RefCounted
class_name CityStats

## [수원화성 도시 통계 및 12대 멀티 엔딩 평가 핵심 지표]
## Single Source of Truth: 전역 도시 핵심 지표 및 상태 관리

# 5대 핵심 평가 지표 + 국방 시스템 (성 방호력 및 군사 공격력)
static var crown_prince_education: int = 0   # 세자 교육도 (0 ~ 100, 초기값 0)
static var hyeonryungwon_visits: int = 0      # 현륭원 친림 횟수 (0회 시작, 참배 시마다 +1)
static var faction_balance_score: int = 50    # 정파 탕평도 (0 ~ 100, 초기값 50)
static var fortress_defense_power: int = 0    # 성곽 현재 방호력 (체력/내구도, 초기값 0)
static var fortress_max_defense_power: int = 0# 성곽 최대 방호력 (기본 점수 + 시설 + 수축 보수)
static var base_fortress_defense_power: int = 0# 성곽 순수 기본 방호력 (공방 승수 적용 전 SSOT 모수)
static var military_workshop_multiplier: float = 1.0 # 공방 수량에 따른 군사력 승수 (0.50 ~ 1.05)
static var current_workshop_count: int = 0     # 현재 가동 중인 공방 수
static var current_game_turn: int = 1          # 현재 게임 턴 수
static var defense_repair_bonus: int = 0      # 수축(修築) 대역사 보수 누적치
static var defense_damage_taken: int = 0      # 외적/도적 침략 피해도 (누적 차감치)
static var academic_power: int = 0            # 도시 학문력 (0 ~ 100, 초기값 0)
static var military_attack_power: int = 0     # 군사 공격력 (장용영 소탕 격퇴력, 기본 0, 행궁 완공 시 500)
static var seojangdae_drill_bonus: int = 0    # 서장대 연례 야조 훈련 누적 공격력 보너스 (회당 +50, 최대 1000)
static var royal_power: int = 50              # 왕권 수치 (0 ~ 100, 30 미만 시 도적 행궁 직격 반란 모드 발동)

# 인스턴스 멤버 변수 (인스턴스로 사용 시에도 안전하게 접근 가능)
var prince_education: int = 0
var wonhaeng_visits: int = 0
var faction_balance: int = 50
var fortress_defense: int = 0
var academic_score: int = 0
var military_attack: int = 0
var seojangdae_bonus: int = 0
var royal_power_val: int = 50

func _init() -> void:
	sync_from_static()

## 인스턴스 변수를 static 변수와 동기화
func sync_from_static() -> void:
	prince_education = crown_prince_education
	wonhaeng_visits = hyeonryungwon_visits
	faction_balance = faction_balance_score
	fortress_defense = fortress_defense_power
	academic_score = academic_power
	military_attack = military_attack_power
	seojangdae_bonus = seojangdae_drill_bonus
	royal_power_val = royal_power

## 인스턴스 변수를 static 변수로 반영
func sync_to_static() -> void:
	crown_prince_education = prince_education
	hyeonryungwon_visits = wonhaeng_visits
	faction_balance_score = faction_balance
	fortress_defense_power = fortress_defense
	academic_power = academic_score
	military_attack_power = military_attack
	seojangdae_drill_bonus = seojangdae_bonus
	royal_power = royal_power_val

# ==================== 핵심 지표 Static Accessors ====================

static func get_royal_power() -> int:
	return royal_power

static func set_royal_power(val: int) -> void:
	royal_power = clampi(val, 0, 100)

static func add_royal_power(delta: int) -> int:
	royal_power = clampi(royal_power + delta, 0, 100)
	return royal_power

static func get_crown_prince_education() -> int:
	return crown_prince_education

static func set_crown_prince_education(val: int) -> void:
	crown_prince_education = clampi(val, 0, 100)

static func add_crown_prince_education(delta: int) -> int:
	crown_prince_education = clampi(crown_prince_education + delta, 0, 100)
	return crown_prince_education

static func get_hyeonryungwon_visits() -> int:
	return hyeonryungwon_visits

static func set_hyeonryungwon_visits(val: int) -> void:
	hyeonryungwon_visits = maxi(0, val)

static func add_hyeonryungwon_visit() -> int:
	hyeonryungwon_visits += 1
	return hyeonryungwon_visits

static func get_faction_balance_score() -> int:
	return faction_balance_score

static func set_faction_balance_score(val: int) -> void:
	faction_balance_score = clampi(val, 0, 100)

static func get_fortress_defense_power() -> int:
	return fortress_defense_power

## 공방 수량 및 턴에 따른 군사력 승수(Multiplier) 반환
static func get_workshop_military_multiplier(ws_count: int = -1, turn: int = -1) -> float:
	var w: int = ws_count if ws_count >= 0 else BuildingManager.active_workshop_count
	var t: int = turn if turn >= 1 else current_game_turn
	return WorkshopManager.get_military_multiplier(w, t)

## 기본 방호력(BaseDef)에 공방 승수를 곱한 최종 군사력 산출 (복리 버그 방지)
static func calculate_total_defense_power(base_def: int, ws_count: int = -1, turn: int = -1) -> int:
	var mult: float = get_workshop_military_multiplier(ws_count, turn)
	return int(round(float(base_def) * mult))

## 현재 공방 수량과 턴을 반영한 최종 방호력 반환
static func get_total_defense_power(ws_count: int = -1, turn: int = -1) -> int:
	return calculate_total_defense_power(base_fortress_defense_power, ws_count, turn)

static func get_base_defense_power() -> int:
	return base_fortress_defense_power

static func get_military_workshop_multiplier() -> float:
	return military_workshop_multiplier

static func get_max_defense_power() -> int:
	return fortress_max_defense_power

static func get_defense_damage_taken() -> int:
	return defense_damage_taken

static func get_defense_repair_bonus() -> int:
	return defense_repair_bonus

static func set_fortress_defense_power(val: int) -> void:
	fortress_defense_power = maxi(0, val)
	base_fortress_defense_power = maxi(base_fortress_defense_power, fortress_defense_power)
	if fortress_defense_power > fortress_max_defense_power:
		fortress_max_defense_power = fortress_defense_power
	defense_damage_taken = maxi(0, fortress_max_defense_power - fortress_defense_power)

static func add_fortress_defense_power(delta: int) -> int:
	fortress_defense_power = maxi(0, fortress_defense_power + delta)
	defense_damage_taken = maxi(0, fortress_max_defense_power - fortress_defense_power)
	return fortress_defense_power

## 도적/외적 침략으로 인한 성벽 방호력 피해 적용
static func apply_defense_damage(amount: int, sim = null) -> void:
	defense_damage_taken = mini(fortress_max_defense_power, defense_damage_taken + amount)
	fortress_defense_power = maxi(0, fortress_max_defense_power - defense_damage_taken)
	if sim != null:
		if "defense_fatigue" in sim:
			sim.defense_fatigue = defense_damage_taken
		if "defense_damage_taken" in sim:
			sim.defense_damage_taken = defense_damage_taken

## 긴급 땜질 보수로 피해도 즉각 회복 (최대 회복량 반환)
static func apply_emergency_repair(amount: int, sim = null) -> int:
	var restored: int = mini(defense_damage_taken, amount)
	defense_damage_taken = maxi(0, defense_damage_taken - amount)
	fortress_defense_power = maxi(0, fortress_max_defense_power - defense_damage_taken)
	if sim != null:
		if "defense_fatigue" in sim:
			sim.defense_fatigue = defense_damage_taken
		if "defense_damage_taken" in sim:
			sim.defense_damage_taken = defense_damage_taken
	return restored

## 수축(修築) 대역사 진행 시 보수 누적치 가산
static func add_repair_bonus(amount: int, sim = null) -> void:
	if defense_repair_bonus < 1000:
		var bonus_add: int = mini(amount, 1000 - defense_repair_bonus)
		defense_repair_bonus += bonus_add
		fortress_max_defense_power += bonus_add
	if defense_damage_taken > 0:
		defense_damage_taken = maxi(0, defense_damage_taken - amount)
	fortress_defense_power = maxi(0, fortress_max_defense_power - defense_damage_taken)
	if sim != null:
		if "defense_repair_bonus" in sim:
			sim.defense_repair_bonus = defense_repair_bonus
		if "defense_fatigue" in sim:
			sim.defense_fatigue = defense_damage_taken
		if "defense_damage_taken" in sim:
			sim.defense_damage_taken = defense_damage_taken

static func get_academic_power() -> int:
	return academic_power

static func set_academic_power(val: int) -> void:
	academic_power = clampi(val, 0, 100)

static func add_academic_power(delta: int) -> int:
	academic_power = clampi(academic_power + delta, 0, 100)
	return academic_power

static func get_military_attack_power() -> int:
	return military_attack_power

static func set_military_attack_power(val: int) -> void:
	military_attack_power = maxi(0, val)

static func add_military_attack_power(delta: int) -> int:
	military_attack_power = maxi(0, military_attack_power + delta)
	return military_attack_power

static func get_seojangdae_drill_bonus() -> int:
	return seojangdae_drill_bonus

static func set_seojangdae_drill_bonus(val: int) -> void:
	seojangdae_drill_bonus = clampi(val, 0, 1000)

static func add_seojangdae_drill_bonus(delta: int) -> int:
	seojangdae_drill_bonus = clampi(seojangdae_drill_bonus + delta, 0, 1000)
	return seojangdae_drill_bonus

## 모든 지표를 기본값으로 초기화
static func reset_to_defaults() -> void:
	crown_prince_education = 0
	hyeonryungwon_visits = 0
	faction_balance_score = 50
	fortress_defense_power = 0
	fortress_max_defense_power = 0
	base_fortress_defense_power = 0
	defense_repair_bonus = 0
	defense_damage_taken = 0
	military_workshop_multiplier = 1.0
	current_workshop_count = 0
	current_game_turn = 1
	academic_power = 0
	military_attack_power = 0
	seojangdae_drill_bonus = 0

## 직렬화용 딕셔너리 생성
static func serialize() -> Dictionary:
	return {
		"crown_prince_education": crown_prince_education,
		"hyeonryungwon_visits": hyeonryungwon_visits,
		"faction_balance_score": faction_balance_score,
		"fortress_defense_power": fortress_defense_power,
		"base_fortress_defense_power": base_fortress_defense_power,
		"fortress_max_defense_power": fortress_max_defense_power,
		"defense_repair_bonus": defense_repair_bonus,
		"defense_damage_taken": defense_damage_taken,
		"current_workshop_count": current_workshop_count,
		"academic_power": academic_power,
		"military_attack_power": military_attack_power,
		"seojangdae_drill_bonus": seojangdae_drill_bonus,
		"royal_power": royal_power
	}

## 역직렬화 (Null-Safe Fallback 보장)
static func deserialize(data: Dictionary) -> void:
	crown_prince_education = clampi(int(data.get("crown_prince_education", 0)), 0, 100)
	hyeonryungwon_visits = maxi(0, int(data.get("hyeonryungwon_visits", 0)))
	faction_balance_score = clampi(int(data.get("faction_balance_score", 50)), 0, 100)
	fortress_defense_power = maxi(0, int(data.get("fortress_defense_power", 0)))
	base_fortress_defense_power = maxi(0, int(data.get("base_fortress_defense_power", fortress_defense_power)))
	fortress_max_defense_power = maxi(0, int(data.get("fortress_max_defense_power", fortress_defense_power)))
	defense_repair_bonus = maxi(0, int(data.get("defense_repair_bonus", 0)))
	defense_damage_taken = maxi(0, int(data.get("defense_damage_taken", 0)))
	current_workshop_count = maxi(0, int(data.get("current_workshop_count", 0)))
	academic_power = clampi(int(data.get("academic_power", data.get("academic", 0))), 0, 100)
	military_attack_power = maxi(0, int(data.get("military_attack_power", 0)))
	seojangdae_drill_bonus = clampi(int(data.get("seojangdae_drill_bonus", 0)), 0, 1000)
	royal_power = clampi(int(data.get("royal_power", data.get("authority", 70))), 0, 100)

# ==================== 탕평도 계산 로직 (무정파 장인 100% 제외) ====================
## 등용된 사대부 인재들의 정파(노론, 소론, 남인, 북학파) 비율에 따른 탕평도 계산 (0 ~ 100)
## 석수장 김바우, 도편수 이성길, 가죽공 무쇠 등 무정파 현장 장인은 분모에서 원천 제외됨
static func calculate_faction_balance_from_retainers(retainers: Dictionary) -> int:
	var score_float: float = ScholarManager.calculate_faction_balance(retainers)
	return int(round(score_float))

# ==================== 학문력(0~100점) 정밀 산출 공식 ====================
## 학문력 = 수원향교(+20점/개소) + 서당(+1점/개소) + 등용 사대부 인재 기여점수 (무정파 장인은 0점)
## 최소 0점에서 최대 100점 범위로 clamp
static func recalculate_academic_power(grid, retainers: Dictionary) -> int:
	var edu_score: int = 0

	# 1. 교육 시설 점수 산출
	if grid != null:
		var hyanggyo_count: int = 0
		var plaza_seodangs: int = 0
		if grid.has_method("list_plazas"):
			plaza_seodangs = grid.list_plazas("seodang").size()

		var tile_seodangs: int = 0
		if "grid" in grid and grid.grid is Array:
			var g_size: int = grid.grid.size()
			for y: int in range(g_size):
				var row: Array = grid.grid[y]
				for x: int in range(row.size()):
					var cell: Dictionary = row[x]
					var b: String = str(cell.get("building", ""))
					if b == "hyanggyo":
						hyanggyo_count += 1
					elif b == "seodang":
						tile_seodangs += 1

		var total_seodangs: int = maxi(plaza_seodangs, tile_seodangs)
		# 수원향교 1개소당 +20점, 서당 1개소당 +1점
		edu_score = (hyanggyo_count * 20) + (total_seodangs * 1)

	# 2. 조정 인재 기여 점수 합산 (김바우 등 무정파 장인은 0점)
	var scholar_score: int = ScholarManager.get_scholars_academic_power(retainers)

	var total: int = clampi(edu_score + scholar_score, 0, 100)
	academic_power = total
	return academic_power

# ==================== 국방 시스템: 성 방호력 및 군사 공격력 정밀 산출 공식 ====================
## [방어 시설별 성 방호력(체력/내구도) 합산 규칙]
## - 성곽(체성): 완공도 비율에 따라 최대 +50 (예: 100% 완공 시 50)
## - 사대문 (장안·팔달·창룡·화서): 각 개소당 +15
## - 수문 (화홍문, 남수문): 각 개소당 +10
## - 포루(砲樓) 및 공심돈: 각 개소당 +8
## - 치성 및 암문: 각 개소당 +3
##
## [군사 지휘·치안 시설별 군사 공격력(격퇴력) 합산 규칙]
## - 화성행궁 완공 (장용영 외영 5,000명 주둔): 기본 공격력 500 부여
## - 서장대 (화성장대 사령부): 공격력 +150
## - 순라청: 개소당 공격력 +50
## - 장용영 군영/훈련원 (연무대 등): 개소당 공격력 +80
## - 서장대 연례 군사 훈련(야조): 훈련 1회당 +50 상승 (최대 1000, 해마다 1월 -50 — 연무대 사열도 같은 몫에 쌓인다)
static func recalculate_defense_and_attack(grid, sim = null) -> Dictionary:
	var def_power: int = 0
	var atk_power: int = 0

	if grid == null:
		fortress_defense_power = def_power
		military_attack_power = atk_power
		return {"defense": def_power, "attack": atk_power}

	# 1. 성곽 완공도 비율 반영 (최대 +50)
	var f_prog: int = 0
	if grid != null and "fortress_progress" in grid:
		f_prog = int(grid.fortress_progress)
	var wall_score: int = int(round(clampf(float(f_prog), 0.0, 100.0) * 0.5))
	def_power += wall_score

	# 2. 그리드 전수 집계 (방어 시설 및 지휘 치안 시설)
	var gate_count: int = 0
	var poru_gongsim_count: int = 0
	var chiseong_ammun_count: int = 0
	var patrol_count: int = 0
	var drill_count: int = 0
	var has_seojangdae: bool = false
	var has_haenggung: bool = false
	var has_hwahong: bool = false
	var has_namsu: bool = false

	# 다칸 시설 앵커 중복 카운트 방지
	var counted_anchors: Dictionary = {}

	if "grid" in grid and grid.grid is Array:
		var g_size: int = grid.grid.size()
		for y: int in range(g_size):
			var row: Array = grid.grid[y]
			for x: int in range(row.size()):
				var cell: Dictionary = row[x]
				# 공사 중(wall_build, under_construction)인 미완공 타일은 제외
				if cell.has("wall_build") or bool(cell.get("under_construction", false)):
					continue

				var b: String = str(cell.get("building", ""))
				var anchor: Vector2i = cell.get("site_anchor", Vector2i(x, y))
				var pos_key: String = "%d_%d" % [anchor.x, anchor.y]

				# 수문 판정 (화홍문/남수문)
				if bool(cell.get("is_hwahong", false)) or str(cell.get("facility_id", "")) == "hwahong_mun" or b == "hwahong":
					has_hwahong = true
				if bool(cell.get("is_namsu", false)) or str(cell.get("facility_id", "")) == "namsu_mun":
					has_namsu = true

				# 사대문 (각 개소당 +15)
				if b == "gate":
					if not counted_anchors.has("gate_" + pos_key):
						counted_anchors["gate_" + pos_key] = true
						gate_count += 1
				# 포루 및 공심돈 (각 개소당 +8)
				elif b == "poru":
					if not counted_anchors.has("poru_" + pos_key):
						counted_anchors["poru_" + pos_key] = true
						poru_gongsim_count += 1
				elif b in ["gongsimdon", "gongsimdon_wall"]:
					if not counted_anchors.has("gongsim_" + pos_key):
						counted_anchors["gongsim_" + pos_key] = true
						poru_gongsim_count += 1
				# 치성 및 암문 (각 개소당 +3)
				elif b in ["chiseong", "ammun"]:
					if not counted_anchors.has("chiseong_" + pos_key):
						counted_anchors["chiseong_" + pos_key] = true
						chiseong_ammun_count += 1
				# 지휘/치안 시설: 화성행궁
				elif b == "haenggung":
					has_haenggung = true
				# 서장대
				elif b == "seojangdae":
					has_seojangdae = true
				# 순라청 (개소당 +50)
				elif b == "patrol":
					if not counted_anchors.has("patrol_" + pos_key):
						counted_anchors["patrol_" + pos_key] = true
						patrol_count += 1
				# 장용영 군영/훈련원 (연무대 등, 개소당 +80)
				elif b == "yeonmudae":
					if not counted_anchors.has("yeonmudae_" + pos_key):
						counted_anchors["yeonmudae_" + pos_key] = true
						drill_count += 1

	# sim 객체 보정 및 수축 보수/피해도 동기화
	if sim != null:
		if "haenggung_completed" in sim and bool(sim.haenggung_completed):
			has_haenggung = true
		if "defense_repair_bonus" in sim and sim.defense_repair_bonus > 0:
			defense_repair_bonus = int(sim.defense_repair_bonus)
		if "defense_fatigue" in sim and sim.defense_fatigue > 0:
			sim.defense_fatigue = clampi(int(sim.defense_fatigue), 0, 1000)
			defense_damage_taken = int(sim.defense_fatigue)

	# 수문 개소 합산 (화홍문 +10, 남수문 +10)
	var water_gate_count: int = (1 if has_hwahong else 0) + (1 if has_namsu else 0)

	# 방호력 최종 합산: 총 성 방호력 = 성곽 기본 점수(최대 50) + 시설 추가분 + 수축 보수 누적치 - 피해도
	var facilities_score: int = (gate_count * 15) + (water_gate_count * 10) + (poru_gongsim_count * 8) + (chiseong_ammun_count * 3)
	fortress_max_defense_power = wall_score + facilities_score + defense_repair_bonus
	defense_damage_taken = clampi(defense_damage_taken, 0, fortress_max_defense_power)
	base_fortress_defense_power = maxi(0, fortress_max_defense_power - defense_damage_taken)

	# 공방 수량 및 턴 기반 군사력 승수 산출
	var ws_count: int = BuildingManager.active_workshop_count
	var turn: int = int(sim.turn) if sim != null and "turn" in sim else current_game_turn
	current_workshop_count = ws_count
	current_game_turn = turn

	var mult: float = get_workshop_military_multiplier(ws_count, turn)
	military_workshop_multiplier = mult

	# 최종 방호력: 기본 방호력 * 공방 승수 (0개 시 0.50배, 1개 이상 시 1.0 + min(0.05, count * 0.0025))
	fortress_defense_power = calculate_total_defense_power(base_fortress_defense_power, ws_count, turn)

	# 공격력 최종 합산
	var base_attack: int = 500 if has_haenggung else 0
	var seojangdae_attack: int = 150 if has_seojangdae else 0
	var patrol_attack: int = patrol_count * 50
	var drill_attack: int = drill_count * 80
	var drill_bonus: int = seojangdae_drill_bonus

	var base_atk_total: int = base_attack + seojangdae_attack + patrol_attack + drill_attack + drill_bonus
	military_attack_power = maxi(0, int(round(float(base_atk_total) * mult)))

	var patrol_def_power: int = patrol_count * 30

	return {
		"defense": fortress_defense_power,
		"attack": military_attack_power,
		"base_defense": base_fortress_defense_power,
		"base_attack": base_atk_total,
		"workshop_multiplier": mult,
		"workshop_count": ws_count,
		"wall_score": wall_score,
		"gate_count": gate_count,
		"water_gate_count": water_gate_count,
		"poru_gongsim_count": poru_gongsim_count,
		"chiseong_ammun_count": chiseong_ammun_count,
		"has_haenggung": has_haenggung,
		"has_seojangdae": has_seojangdae,
		"patrol_count": patrol_count,
		"patrol_defense_power": patrol_def_power,
		"drill_count": drill_count,
		"drill_bonus": drill_bonus
	}

## 순라청 개수 기반 도시 국방력 기여치 계산 (개소당 +30)
static func get_patrol_military_bonus(patrol_count: int) -> int:
	return patrol_count * 30

## 아군 총 전투력 산출: 기본 군사력 + (순라청 개수 * 30) + 장용영 훈련치
static func calculate_total_military_power(base_power: int, patrol_count: int, drill_bonus: int = 0) -> int:
	return base_power + (patrol_count * 30) + drill_bonus

# ==================== 성 방호력 계산 로직 (하위 호환 래퍼) ====================
## 기존 시뮬레이션 및 엔딩 평가 호환성을 위해 recalculate_defense_and_attack 결과를 반환
static func calculate_fortress_defense_power_from_grid(fortress_progress: int, grid_data: Array, _military_power: int = 70) -> int:
	var progress_part: float = clampf(float(fortress_progress), 0.0, 100.0) * 0.5

	var defense_score: int = int(round(progress_part))
	var has_hw: bool = false
	var has_ns: bool = false
	var counted: Dictionary = {}

	if not grid_data.is_empty():
		var size_y: int = grid_data.size()
		for ty: int in range(size_y):
			var row: Array = grid_data[ty]
			var size_x: int = row.size()
			for tx: int in range(size_x):
				var cell: Dictionary = row[tx]
				if cell.has("wall_build") or bool(cell.get("under_construction", false)):
					continue
				var b: String = str(cell.get("building", ""))
				var a: Vector2i = cell.get("site_anchor", Vector2i(tx, ty))
				var k: String = "%d_%d" % [a.x, a.y]

				if bool(cell.get("is_hwahong", false)) or str(cell.get("facility_id", "")) == "hwahong_mun" or b == "hwahong":
					has_hw = true
				if bool(cell.get("is_namsu", false)) or str(cell.get("facility_id", "")) == "namsu_mun":
					has_ns = true

				if b == "gate" and not counted.has("gate_" + k):
					counted["gate_" + k] = true
					defense_score += 15
				elif b in ["poru", "gongsimdon", "gongsimdon_wall"] and not counted.has("poru_" + k):
					counted["poru_" + k] = true
					defense_score += 8
				elif b in ["chiseong", "ammun"] and not counted.has("chiseong_" + k):
					counted["chiseong_" + k] = true
					defense_score += 3

	if has_hw: defense_score += 10
	if has_ns: defense_score += 10

	var ws_cnt: int = BuildingManager.active_workshop_count
	var mult: float = get_workshop_military_multiplier(ws_cnt, current_game_turn)
	return maxi(0, int(round(float(defense_score) * mult)))

# ==================== 인구 갱신 및 조세 저항선 평가 ====================
## 인구 규모별 조세 저항선 임계치 초과 여부를 검사하고 인구 증감 반영
## 임계치 초과 시: 자연 증가 중단 및 (조세 총합 - 임계치) * 0.5% 비율로 유출(감소)
## 임계치 이하 시: 정상 증가율 또는 기본 변화량 반영
## pop_cap(>0): 인구 상한 — 넘으면 늘지 않고, 이미 넘어 있으면 초과분의 1/4씩 떠나 상한으로 돌아온다
static func update_population(cur_pop: int, natural_delta: int, total_tax_rate: float, pop_cap: int = -1) -> Dictionary:
	var threshold: float = TaxManager.get_tax_threshold_for_population(cur_pop)
	var is_resisting: bool = TaxManager.is_tax_resistance_active(cur_pop, total_tax_rate)

	var final_delta: int = 0
	var penalty_rate: float = 0.0

	if is_resisting:
		# 자연 증가 전면 차단 및 인구 유출 발생
		penalty_rate = (total_tax_rate - threshold) * 0.005
		var loss: int = int(round(float(cur_pop) * penalty_rate))
		loss = maxi(1, loss) # 저항 발동 시 최소 1명 감소
		final_delta = -loss
	else:
		final_delta = natural_delta

	var at_cap := false
	if pop_cap > 0:
		if cur_pop > pop_cap:
			# 상한보다 많으면 일자리·집을 못 구한 백성이 떠난다(초과분의 1/4씩, 최소 1명)
			final_delta = mini(final_delta, -maxi(1, int(round(float(cur_pop - pop_cap) * 0.25))))
			at_cap = true
		elif cur_pop + final_delta >= pop_cap:
			final_delta = pop_cap - cur_pop
			at_cap = true

	var new_pop: int = maxi(0, cur_pop + final_delta)
	return {
		"old_population": cur_pop,
		"new_population": new_pop,
		"delta": final_delta,
		"is_resisting": is_resisting,
		"threshold": threshold,
		"penalty_rate": penalty_rate,
		"at_cap": at_cap
	}

# ==================== 민심 획득 감쇠(Morale Drag) 및 가산 시스템 ====================
## 인구 규모 및 난이도에 따른 실제 민심 획득량 계산
## 실제 획득량 = 기본 획득치 * 난이도 기본 승수 * (1.0 - 인구 감쇠율)
## base_amount > 0 일 때 최소 1은 보장(라운딩 후 0이라도 1), base_amount <= 0 이면 감쇠 없이 그대로 반환
static func calculate_morale_gain(base_amount: int, population: int) -> int:
	if base_amount <= 0:
		return base_amount
	var mult: float = DifficultyManager.get_morale_gain_multiplier(population)
	var effective: int = int(round(float(base_amount) * mult))
	return maxi(1, effective)

## 민심 가산 및 갱신 함수 (SSOT 연동)
## - amount > 0: 난이도 및 인구 감쇠 공식 적용 후 가산
## - amount < 0: 재난/패널티이므로 감쇠 없이 그대로 차감
static func add_morale(amount: int, sim = null, population: int = -1) -> int:
	var target_sim = sim
	if target_sim == null and Engine.has_singleton("SimulationCore"):
		target_sim = Engine.get_singleton("SimulationCore")

	var pop: int = population
	if pop < 0 and target_sim != null and "population" in target_sim:
		pop = int(target_sim.population)
	if pop < 0:
		pop = 0

	var delta: int = amount
	if amount > 0:
		delta = calculate_morale_gain(amount, pop)

	if target_sim != null and "loyalty" in target_sim:
		target_sim.loyalty = clampi(int(target_sim.loyalty) + delta, 0, 100)
		return int(target_sim.loyalty)

	return delta
