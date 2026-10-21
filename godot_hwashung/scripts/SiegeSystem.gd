extends Node
class_name SiegeSystem

## PORT-TRACE [공성전]: 사용자 요청(생태계 확장 명세 3단계) —
##  · 성 방호력(최대 1000) = 성곽 완성도x400 + 군사시설x30 + 장용영 300 + 군포세 가감 - 피로도
##  · 반란군: 왕권이 낮으면(30 미만) 파발 전령 + 김판관 전면 경고 뒤 12명 정규 부대가 행궁을 향해 진격. 공격력은 민심·왕권에
##    반비례(최대 900). 성벽이 없으면 행궁 직격, 성벽이 있으면 성문 앞에서 사다리·충차 공성.
##  · 도적떼(민란): 민심이 낮아(40 미만) 성을 떠난 유민이 쌓이면 산채가 커져 10명이 읍내·성문 습격. 공격력 = 유민 x5(최대 500).
##    막아내면 그만큼 방호력에 피로도가 쌓이고(턴마다 25씩 회복), 반란군·도적떼 모두 방어에 실패하면 게임 오버.
## 성능 원칙(사용자 명시): 부대원마다 A*를 돌리지 않는다 — 목표(성문 또는 행궁 정문) 기준 흐름장(BFS 거리표)을 사건마다 1회
## 계산해 전원이 공유하고, 각자는 이웃 네 칸 중 거리가 작은 칸으로만 걷는다. 상태 판정은 0.25초마다.

signal alert(kind: String, text: String)    # 전면 경고(김판관)
signal notice(text: String, icon: String)   # 토스트
signal game_over(reason: String)
@warning_ignore("unused_signal")
signal battle_focus_requested(world_pos: Vector2, loc_name: String) # 맵 자동 포커싱 요청

var grid: GameGrid
var sim: SimulationCore
var citizens: CitizenManager
var court: CourtSystem

var mobilization: MobilizationManager = MobilizationManager.new()
var is_wartime_mobilized: bool = false
var repair_state: Dictionary = {
	"active": false,
	"type": "none",
	"turns_left": 0
}

## 사건 상태: "" / "warning" / "march" / "siege"
var state := ""
var kind := ""            # "rebel" / "horde"
var attack := 0
var defense_at_start := 0
var target := Vector2i(-1, -1)  # 흐름장 목표(성문 또는 행궁 정문)
var walled := false
var t := 0.0               # 상태 경과 시간
var _field := PackedInt32Array()
var _tick := 0.0
var _patient_t := 0.0
const SIEGE_LEN := 20.0
const MILITARY := ["seojangdae", "bongdon", "gongsimdon", "poru", "yeonmudae", "patrol"]

func setup(g: GameGrid, s: SimulationCore, c: CitizenManager, ct: CourtSystem) -> void:
	grid = g
	sim = s
	citizens = c
	court = ct
	sim.turn_advanced.connect(_on_turn)

# ---------------------------------------------------------------- 성 방호력
func military_count() -> int:
	var n := 0
	for y in range(grid.size):
		for x in range(grid.size):
			var t2: Dictionary = grid.grid[y][x]
			var b: String = t2["building"]
			if b in MILITARY and not t2.has("wall_build") and t2.get("site_anchor", Vector2i(x, y)) == Vector2i(x, y):
				n += 1
	return n

## 그림(매 프레임)에서도 부르므로 1초 동안은 지난 값을 재사용
var _def_cache := -1
var _def_ms := -10000
func defense_power() -> int:
	var now := Time.get_ticks_msec()
	if _def_cache >= 0 and now - _def_ms < 1000:
		return _def_cache
	_def_ms = now
	_def_cache = _compute_defense()
	return _def_cache

func _compute_defense() -> int:
	var stat_def: float = float(CityStats.get_fortress_defense_power()) * 5.0
	var wall := clampf(float(grid.fortress_progress) / 100.0, 0.0, 1.0) * 400.0
	var mil := float(mini(military_count(), 10)) * 30.0
	# 화성행궁 완공 및 장용영 외영 주둔 시 군사 공격력(기본 500 등)을 방어력 판정 모수로 50% 가산 반영
	var atk_def_bonus: float = float(CityStats.get_military_attack_power()) * 0.5
	var jang := 300.0 if sim.retainers.get("baek_dongsu", false) else 0.0
	jang += 100.0 if sim.retainers.get("jeong_yakyong", false) else 0.0 # 정약용 축성 설계로 방호력 강화
	var tax := clampf((float(grid.policy.get("tax_military", 7)) - 7.0) * 20.0, -100.0, 100.0)
	if sim.retainers.get("sim_hwanji", false):
		tax = maxf(tax, 0.0) # 심환지: 군포세 저항 감소 — 낮은 군포세 감점이 없다
	var calc_val := maxf(stat_def, wall + mil) + atk_def_bonus
	var fatigue: int = clampi(sim.defense_fatigue if sim else 0, 0, 1000)
	var base_defense := int(calc_val + jang + tax) - fatigue

	# 전시 민·군 합동 방어 체제 버프 및 배신 패널티
	if is_wartime_mobilized and mobilization:
		if mobilization.current_branch == MobilizationManager.LoyaltyBranch.UNITED_RESISTANCE:
			base_defense = int(float(base_defense) * mobilization.combat_buff)
		elif mobilization.betrayed_gate.x >= 0:
			base_defense -= 200 # 변절자의 성문 개방으로 인한 방호력 급락

	return clampi(base_defense, 0, 1000)

# ---------------------------------------------------------------- 보수 공사 2-Track 메커니즘
## 긴급 땜질 보수: 일시불 소모로 방호력 즉시 회복 (김바우/이성길 등용 시 비용 -20%, 회복량 +30%)
func emergency_repair() -> Dictionary:
	var actual_damage: int = maxi(CityStats.get_defense_damage_taken(), sim.defense_fatigue if sim else 0)
	if actual_damage <= 0:
		var no_need_msg := "성곽이 온전하여 긴급 땜질 보수가 필요하지 않습니다."
		emit_signal("notice", no_need_msg, "✨")
		return {"success": false, "message": no_need_msg}

	var jeong_bau_lee: bool = sim.retainers.get("jeong_yakyong", false) or sim.retainers.get("kim_bau", false) or sim.retainers.get("lee_seonggil", false)
	var cost_gold: int = 480 if jeong_bau_lee else 600
	var cost_rice: int = 240 if jeong_bau_lee else 300
	var restore_amt: int = 390 if jeong_bau_lee else 300

	if sim.gold < cost_gold or sim.rice < cost_rice:
		var err_msg := "긴급 보수 자금/군량 부족 (필요: 금 %d냥, 곡 %d석)" % [cost_gold, cost_rice]
		emit_signal("notice", err_msg, "⚠️")
		return {"success": false, "message": err_msg}

	sim.gold -= cost_gold
	sim.rice -= cost_rice
	var actual_restored: int = CityStats.apply_emergency_repair(restore_amt, sim)
	sim.defense_fatigue = maxi(0, sim.defense_fatigue - restore_amt)
	_def_cache = -1
	emit_signal("notice", "성곽 긴급 땜질 보수 완료! 방호력 %d이 즉시 회복되었습니다 (금 -%d냥, 곡 -%d석)%s." % [
		restore_amt, cost_gold, cost_rice, " [김바우/이성길 혜택 적용]" if jeong_bau_lee else ""
	], "🪵")
	return {"success": true, "message": "긴급 땜질 보수 완료", "restored": actual_restored}

## 수축(修築) 대역사 발주: 턴당 회복 100(인재 등용 시 150), 턴당 소모 금 300/곡 200(인재 시 금 210/곡 140)
func start_grand_repair() -> Dictionary:
	repair_state["active"] = true
	repair_state["type"] = "grand"
	repair_state["turns_left"] = 6
	if sim != null and "repair_state" in sim:
		sim.repair_state = repair_state.duplicate()
	emit_signal("notice", "성곽 수축(修築) 대역사를 발주했습니다. 석수와 목수들이 비계를 설치하고 정밀 보수를 진행합니다.", "🏗️")
	return {"success": true, "message": "수축 대역사 발주"}

func cancel_grand_repair() -> void:
	repair_state["active"] = false
	repair_state["type"] = "none"
	repair_state["turns_left"] = 0
	if sim != null and "repair_state" in sim:
		sim.repair_state = repair_state.duplicate()
	emit_signal("notice", "성곽 수축 대역사가 중단되었습니다.", "🛑")

# ---------------------------------------------------------------- 턴마다 발생 판정
func _on_turn(_turn: int, _season: int, year: int) -> void:
	# 1. 기본 피로도 자연 회복 (턴당 25)
	sim.defense_fatigue = maxi(0, sim.defense_fatigue - 25)

	# 2. 수축(修築) 대역사 진행 처리
	if repair_state.get("active", false) and str(repair_state.get("type", "")) == "grand":
		var jeong_or_bau: bool = sim.retainers.get("jeong_yakyong", false) or sim.retainers.get("kim_bau", false) or sim.retainers.get("lee_seonggil", false)
		var cost_gold: int = 210 if jeong_or_bau else 300
		var cost_rice: int = 140 if jeong_or_bau else 200
		var restore_amt: int = 150 if jeong_or_bau else 100

		if sim.gold >= cost_gold and sim.rice >= cost_rice:
			sim.gold -= cost_gold
			sim.rice -= cost_rice
			CityStats.add_repair_bonus(restore_amt, sim)
			sim.defense_fatigue = maxi(0, sim.defense_fatigue - restore_amt)
			_def_cache = -1
			var t_left: int = int(repair_state.get("turns_left", 6)) - 1
			repair_state["turns_left"] = t_left
			if sim != null and "repair_state" in sim:
				sim.repair_state = repair_state.duplicate()
			emit_signal("notice", "성곽 수축 대역사 진행: 방호력 +%d 회복 (소모: 금 -%d냥, 곡 -%d석, 잔여: %d개월)%s" % [
				restore_amt, cost_gold, cost_rice, maxi(0, t_left), " [김바우/이성길 혜택 적용]" if jeong_or_bau else ""
			], "🔨")
			if t_left <= 0 or (sim.defense_fatigue <= 0 and CityStats.get_defense_damage_taken() <= 0):
				repair_state["active"] = false
				repair_state["turns_left"] = 0
				if sim != null and "repair_state" in sim:
					sim.repair_state = repair_state.duplicate()
				emit_signal("notice", "성곽 수축 대역사 완공! 화성 성곽이 본래의 견고함을 되찾았습니다.", "✨")
		else:
			repair_state["active"] = false
			repair_state["turns_left"] = 0
			if sim != null and "repair_state" in sim:
				sim.repair_state = repair_state.duplicate()
			emit_signal("notice", "재정/군량 부족으로 성곽 수축 대역사가 중단되었습니다.", "⚠️")

	# 3. 방치 패널티: 방호력이 500 미만인 상태로 방치되면 민심 매 턴 1 지속 감소
	var cur_defense := defense_power()
	if cur_defense < 500:
		sim.loyalty = maxi(0, sim.loyalty - 1)
		emit_signal("notice", "성곽 파손이 방치되어 백성들이 불안에 떨고 있습니다 (민심 -1%, 침략 위험 증가).", "⚠️")

	# 매 턴 침략 쿨다운 1 차감 (성곽 상태와 무관하게 공통 적용)
	sim.rebel_cd = maxi(0, sim.rebel_cd - 1)
	sim.horde_cd = maxi(0, sim.horde_cd - 1)
	if sim.loyalty < 40:
		sim.refugees += maxi(1, int(float(sim.population) * 0.03)) # 민심이 떠나 성을 등지는 유민
	elif sim.refugees > 0:
		sim.refugees = maxi(0, sim.refugees - 5)
	if state != "" or year < 1791 or (sim != null and sim.turn <= 8):
		return
	if sim.authority < 30 and sim.rebel_cd == 0 and randf() < 0.5:
		var atk: int = RebellionManager.calculate_rebel_siege_atk(sim)
		_start("rebel", atk)
	elif sim.loyalty < 30 and sim.refugees >= 20 and sim.horde_cd == 0 and randf() < 0.4:
		var atk: int = BanditManager.calculate_bandit_siege_atk(sim)
		_start("horde", atk)

func _start(k: String, atk: int) -> void:
	kind = k
	attack = atk
	defense_at_start = defense_power()
	walled = (grid.fortress_progress >= 50) or (not citizens._gate_cache.is_empty())
	t = 0.0

	# 1. 목표 지점 선제 결정 (성문이 있으면 성문을 1차 방어선으로, 없을 때만 행궁 본궁으로)
	var start := _spawn_point()
	if not citizens._gate_cache.is_empty():
		var best: Vector2i = citizens._gate_cache[0]
		for g: Vector2i in citizens._gate_cache:
			if absi(g.x - start.x) + absi(g.y - start.y) < absi(best.x - start.x) + absi(best.y - start.y):
				best = g
		target = best
	else:
		target = citizens._haenggung_gate if citizens._haenggung_gate.x >= 0 else Vector2i(int(float(grid.size) / 2.0), int(float(grid.size) / 2.0))

	if k == "rebel":
		state = "warning"
		# 파발 전령이 성문을 지나 행궁으로 질주
		if not citizens._gate_cache.is_empty() and citizens._haenggung_gate.x >= 0:
			citizens._spawn_trip("horse_messenger", citizens._gate_cache[randi() % citizens._gate_cache.size()], citizens._haenggung_gate, "급보요! 반란군이 쳐들어옵니다!")
		emit_signal("alert", "rebel", "전하, 급보이옵니다!\n왕권이 흔들린 틈을 타 군사 반란이 일어났습니다. 정규 무장 부대가 행궁을 차지하려 진격해 옵니다!\n반란군 공격력 %d  대  우리 성 방호력 %d\n%s" % [attack, defense_at_start, "성곽이 완성되어 성문에서 막아 낼 수 있습니다." if walled else "성곽이 없어 행궁이 바로 공격받습니다!"])
	else:
		state = "march"
		_spawn_units()
		emit_signal("notice", "민심을 잃고 성을 떠난 유민들이 도적떼(민란)가 되어 몰려옵니다! 도적떼 공격력 %d 대 성 방호력 %d" % [attack, defense_at_start], "🔥")

	# 공격 목표 지점으로 카메라 자동 포커싱 요청
	_request_camera_focus()

# ---------------------------------------------------------------- 부대 생성·흐름장
func _spawn_units() -> void:
	var start := _spawn_point()
	if not citizens._gate_cache.is_empty():
		var best: Vector2i = citizens._gate_cache[0]
		for g: Vector2i in citizens._gate_cache:
			if absi(g.x - start.x) + absi(g.y - start.y) < absi(best.x - start.x) + absi(best.y - start.y):
				best = g
		target = best
	else:
		target = citizens._haenggung_gate if citizens._haenggung_gate.x >= 0 else Vector2i(int(float(grid.size) / 2.0), int(float(grid.size) / 2.0))
	_build_field(target)
	_request_camera_focus()

	# 최소 10명 이상의 무장 부대 (포수, 사수, 살수 병종 배정)
	var n := 14 if kind == "rebel" else 12
	for i in range(n):
		var p := start + Vector2i(randi_range(-1, 1), randi_range(-1, 1))
		p = Vector2i(clampi(p.x, 0, grid.size - 1), clampi(p.y, 0, grid.size - 1))
		var ag := citizens._add_road_agent(kind, p)
		ag["siege_unit"] = true
		SpecialEntityManager.mark_special(ag)
		ag["speed"] = 0.85 if kind == "rebel" else 0.95
		ag["slot"] = i

		# 병종 3종 배정: 포수(gunner), 사수(archer), 살수(blade)
		var w_class: String = "gunner" if i % 3 == 0 else ("archer" if i % 3 == 1 else "blade")
		ag["weapon_class"] = w_class
		ag["attack_power"] = maxi(10, int(float(attack) / float(n)))

		if i == 0:
			ag["bubble_text"] = "포를 쏘고 성벽을 부숴라! 진격!" if kind == "rebel" else "곡식을 털어라! 관아를 부숴라!"
			ag["bubble_timer"] = 4.0

	# 전시 비상 체제 총동원 트리거 (상인/주민 의병 전환 및 부녀자 보급대)
	if mobilization and not is_wartime_mobilized:
		var _mob_res: Dictionary = mobilization.mobilize(citizens, grid, sim, target)
		is_wartime_mobilized = true
		_def_cache = -1
		if mobilization.current_branch == MobilizationManager.LoyaltyBranch.UNITED_RESISTANCE:
			emit_signal("notice", "백성과 상인들이 일치단결하여 결사항전의 뜻으로 성벽 방어선에 집결했습니다! (의병/민병대 공방 +30%)", "🛡️")
		elif mobilization.current_branch == MobilizationManager.LoyaltyBranch.TREASON_BETRAYAL:
			if mobilization.betrayed_gate.x >= 0:
				emit_signal("notice", "경고! 민심 이반으로 변절한 무리가 성문을 몰래 열어 젖혔습니다! 방호력이 급락합니다!", "⚠️")
			else:
				emit_signal("notice", "민심과 왕권이 땅에 떨어져 백성들의 동원 거부와 탈영이 속출하고 있습니다!", "⚠️")
		else:
			emit_signal("notice", "도시 전체가 전시 비상 체제로 전환되어 상인과 주민들이 방어선으로 출동합니다.", "⚔️")

	# 조선 후기 정규군(삼수병: 포수·사수·살수, 기포병) 전술 배치
	if citizens and citizens.military_mgr:
		citizens.military_mgr.deploy_wartime(citizens, grid, target)

	# 장용영 정예 요격 부대(칼잡이, 깃발병) 긴급 요격 출동
	if citizens:
		citizens.dispatch_jangyongyeong_squad(target)

func _spawn_point() -> Vector2i:
	if grid.logistics:
		var rts: Array = grid.logistics.connected_routes()
		if not rts.is_empty():
			return (rts[randi() % rts.size()] as Dictionary)["end"]
	var cam := citizens.get_bandit_camp_pos() if kind == "horde" else Vector2i(-1, -1)
	if cam.x >= 0 and grid.in_bounds(cam.x, cam.y):
		return cam
	return Vector2i(1, int(float(grid.size) / 2.0))

## 목표에서 거꾸로 BFS — 걸을 수 있는 칸(성문 포함)만, 목표 칸 자체는 항상 포함
func _build_field(goal: Vector2i) -> void:
	var sz := grid.size
	_field.resize(sz * sz)
	_field.fill(-1)
	if not grid.in_bounds(goal.x, goal.y):
		return
	var q: Array[Vector2i] = [goal]
	_field[goal.y * sz + goal.x] = 0
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		var dc := _field[c.y * sz + c.x]
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if not grid.in_bounds(n.x, n.y) or _field[n.y * sz + n.x] >= 0:
				continue
			if not citizens._tile_walkable(grid.grid[n.y][n.x]):
				continue
			_field[n.y * sz + n.x] = dc + 1
			q.append(n)

func _field_at(p: Vector2i) -> int:
	if not grid.in_bounds(p.x, p.y) or _field.is_empty():
		return -1
	return _field[p.y * grid.size + p.x]

## CitizenManager가 부대원("rebel"/"horde")마다 부른다: 흐름장 따라 한 걸음(공성 중엔 목표 둘레에 진을 치고 공격 동작)
func update_unit(a: Dictionary, delta: float) -> void:
	if state == "" or state == "warning":
		if state == "":
			a["is_dead"] = true
		return
	if a.get("routed", false):
		# 패주: 목표 반대쪽으로 흩어지며 사라짐
		a["ttl"] = float(a.get("ttl", 6.0)) - delta
		if float(a["ttl"]) <= 0.0:
			a["is_dead"] = true
			return
		var cur0 := Vector2(float(a["x"]), float(a["y"]))
		var away := (cur0 - Vector2(target) - Vector2(0.5, 0.5)).normalized()
		citizens._move_agent_towards(a, cur0 + away * 3.0, delta, 1.4) # 패주도 성벽·건물은 넘지 않는다
		return
	var cur := Vector2(float(a["x"]), float(a["y"]))
	var ct := Vector2i(int(floor(cur.x)), int(floor(cur.y)))
	var goal := Vector2(target) + Vector2(0.5, 0.5)
	var ring := 1.3 + float(int(a.get("slot", 0)) % 4) * 0.35
	if state == "siege" or cur.distance_to(goal) <= ring:
		a["sieging"] = true
		return
	var dc := _field_at(ct)
	var next := goal
	if dc > 0:
		var best := dc
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v := _field_at(ct + d)
			if v >= 0 and v < best:
				best = v
				next = Vector2(ct + d) + Vector2(0.5, 0.5)
	var dv := next - cur
	var dist := dv.length()
	if dist > 0.02:
		var step: float = minf(float(a.get("speed", 0.8)) * delta, dist)
		a["x"] = cur.x + dv.x / dist * step
		a["y"] = cur.y + dv.y / dist * step
		a["dir"] = dv / dist

# ---------------------------------------------------------------- 진행
func _process(delta: float) -> void:
	if state == "" or citizens == null:
		return
	var ts: float = citizens.time_scale
	if ts <= 0.0:
		return
	delta *= ts
	t += delta
	match state:
		"warning":
			if t >= 12.0:
				state = "march"
				t = 0.0
				_spawn_units()
				emit_signal("notice", "반란군이 진격을 시작했습니다! (공격력 %d)" % attack, "⚔️")
		"march":
			_tick -= delta
			if _tick > 0.0:
				return
			_tick = 0.25
			var n_units := 0
			var n_arrived := 0
			for a: Dictionary in citizens.agents:
				if a.get("siege_unit", false) and not a.get("is_dead", false):
					n_units += 1
					if a.get("sieging", false):
						n_arrived += 1
			if n_units == 0:
				_finish(true)
				return
			if n_arrived * 2 >= n_units or t > 120.0:
				state = "siege"
				t = 0.0
				_patient_t = 3.0
				emit_signal("notice", ("성문 앞에서 공성전이 벌어집니다! 사다리와 충차가 성문을 두드립니다!" if walled else "행궁이 직접 공격받고 있습니다!"), "🏯")
		"siege":
			_patient_t -= delta
			if _patient_t <= 0.0:
				_patient_t = 6.0
				citizens.spawn_patient(target, "공성")
				citizens.emit_signal("sfx", "scream")

			# 공격력에 비례한 실시간 성곽 방호력/피로도 피해
			var real_damage_per_sec: float = maxf(2.0, float(attack) * 0.04)
			var tick_dmg: int = maxi(1, int(real_damage_per_sec * delta))
			var cur_stat_def: int = CityStats.get_fortress_defense_power()
			if cur_stat_def > 0:
				CityStats.apply_defense_damage(tick_dmg, sim)
			sim.defense_fatigue = clampi(sim.defense_fatigue, 0, 1000)
			_def_cache = -1

			# 장용영 및 정규군 아군 공격력에 의한 적 공성부대 반격 및 체력 차감
			var ally_atk: int = CityStats.get_military_attack_power()
			var atk_counter_dmg: int = maxi(2, int(float(ally_atk) * 0.08 * delta))
			attack = maxi(0, attack - atk_counter_dmg)

			var atk_bonus_spd: float = 1.0 + float(ally_atk) / 400.0
			if attack <= 0 or t * atk_bonus_spd >= SIEGE_LEN:
				# 아군 군사 공격력이 적 공격력을 전멸시켰거나, 방호력이 적 잔여 공격력 이상이면 격퇴 성공
				var cur_def := defense_power()
				_finish(attack <= 0 or cur_def >= attack or (cur_def + int(float(ally_atk) / 2.0)) >= attack)

## 방어 성공/실패
func _finish(won: bool) -> void:
	for a: Dictionary in citizens.agents:
		if a.get("siege_unit", false):
			if won:
				a["routed"] = true
				a["ttl"] = 6.0
				a["sieging"] = false
			else:
				a["is_dead"] = true
	var k := kind
	var atk := attack

	# 부녀자 보급 라인 유지 시 방호력 감소율(피로도 누적) 20% 경감 버프 적용
	if won and mobilization and mobilization.supply_mitigation_ratio > 0.0:
		atk = int(float(atk) * (1.0 - mobilization.supply_mitigation_ratio))

	# 전시 총동원 해제 및 상인/주민 NPC 원래 가옥/상점 롤백
	if mobilization:
		mobilization.demobilize(citizens)
	if citizens and citizens.military_mgr:
		citizens.military_mgr.stand_down(citizens)
	is_wartime_mobilized = false
	_def_cache = -1

	state = ""
	if court:
		court.academic_hit(6 if k == "rebel" else 4, "반란") # PORT-TRACE [학문력]: 전란으로 학문력 차감
	if won:
		# 아무리 작은 규모의 적군이라도 성곽에 확실한 피해를 입힘 (공격력 비례 피해 잔존)
		var residual_damage: int = maxi(15, int(float(atk) * 0.25))
		sim.defense_fatigue += residual_damage
		CityStats.apply_defense_damage(int(float(residual_damage) * 0.2), sim)
		_def_cache = -1

		if k == "horde":
			sim.refugees = 0
			sim.horde_cd = 6
			emit_signal("notice", "도적떼를 격퇴했습니다! 격전으로 성 방호력이 %d 깎였습니다(수축 보수 필요)." % residual_damage, "🛡️")
		else:
			sim.rebel_cd = 8
			sim.authority = mini(100, sim.authority + 10)
			emit_signal("notice", "반란군을 격퇴했습니다! 치열한 공방으로 성곽에 %d 피해가 발생했습니다. (왕권 +10)" % residual_damage, "🛡️")
	else:
		var fail_reason: String = ("반란군(공격력 %d)이 성 방호력을 넘어 행궁을 점령했습니다." % atk) if k == "rebel" else ("도적떼(공격력 %d)가 성을 함락하고 읍내를 불태웠습니다." % atk)
		emit_signal("game_over", fail_reason)
		if EndingManager.instance != null:
			var end_key: String = "COUP_DETAT" if k == "rebel" else "BANDIT_FALL"
			EndingManager.instance.trigger_fall_of_city_ending(end_key)

## 불러오기·다시 하기 때 진행 중 사건 정리
func reset() -> void:
	state = ""
	for a: Dictionary in citizens.agents:
		if a.get("siege_unit", false):
			a["is_dead"] = true
	if mobilization:
		mobilization.demobilize(citizens)
	if citizens and citizens.military_mgr:
		citizens.military_mgr.stand_down(citizens)
	is_wartime_mobilized = false
	_def_cache = -1

## 카메라 자동 포커싱 요청 헬퍼
func _request_camera_focus() -> void:
	if grid == null or not grid.in_bounds(target.x, target.y):
		return
	var elev: float = grid.grid[target.y][target.x].get("elevation", 0.0)
	var w_pos := Vector2.ZERO
	if citizens != null and citizens.city != null and citizens.city.ref_layer != null:
		w_pos = citizens.city.cell_center(float(target.x) + 0.5, float(target.y) + 0.5, elev)
	else:
		# 아이소메트릭 그리드 기본 계산 폴백 (타일 너비 64, 높이 32 기준)
		var gx: float = float(target.x) + 0.5
		var gy: float = float(target.y) + 0.5
		w_pos = Vector2((gx - gy) * 32.0, (gx + gy) * 16.0 - elev * 8.0)

	var loc_name: String = _get_target_location_name(target)
	battle_focus_requested.emit(w_pos, loc_name)

func _get_target_location_name(tg: Vector2i) -> String:
	if not grid.in_bounds(tg.x, tg.y):
		return "화성 성곽"
	var bld: String = str(grid.grid[tg.y][tg.x].get("building", ""))
	if bld == "jangan_mun": return "장안문(북문)"
	elif bld == "paldal_mun": return "팔달문(남문)"
	elif bld == "hwaseo_mun": return "화서문(서문)"
	elif bld == "changryong_mun": return "창룡문(동문)"
	elif bld.begins_with("haenggung") or tg == citizens._haenggung_gate: return "화성행궁 정문"
	elif bld == "gate": return "화성 성문"
	return "화성 방어선"
