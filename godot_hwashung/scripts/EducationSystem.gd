extends Node
class_name EducationSystem

## PORT-TRACE [교육 기관 3종]: 사용자 요청(인재·학문력 명세 2단계) —
##  · 서당(2x2): 방·리 구획에 가옥 100채당 1곳꼴로 저절로 생김. 하나마다 학문력 +1/턴(영구 누적).
##  · 매곡서원(3x3): 도시에 하나. 서당이 3곳 생긴 뒤, 박석길로 둘러싸인 방·리 구획에 3x3 빈터가 있으면 턴마다 30% 확률로 생김. 유지비 0,
##    인재 출현 확률 +20%.
##  · 수원향교(4x4): 플레이어가 성 밖 + 성문과 길로 이어진 자리에 짓는다. 매 턴 금 500·쌀 500 유지비(모자라면 그 턴 운영 중단),
##    운영 중이면 민심 +1·학문력 +1/턴, 연구 비용 -15%, 인재 출현 확률 +20%. 유생들이 성문과 향교를 오간다.
## 성능 원칙(사용자 명시): 자리 찾기·효과 계산은 턴이 넘어갈 때 한 번만. 유생 왕래만 14초마다 한 명.

signal notice(text: String, icon: String)

var grid: GameGrid
var sim: SimulationCore
var court: CourtSystem
var citizens: CitizenManager
var hyanggyo_active := false
var _hg_anchor := Vector2i(-1, -1)
var _yusaeng_t := 6.0
var _yusaeng_flip := false

func setup(g: GameGrid, s: SimulationCore, c: CourtSystem, cm: CitizenManager) -> void:
	grid = g
	sim = s
	court = c
	citizens = cm
	sim.turn_advanced.connect(_on_turn)

func _on_turn(_turn: int, _season: int, _year: int) -> void:
	var um: UrbanEvolutionManager = UrbanEvolutionManager.instance
	var houses := 0
	_hg_anchor = Vector2i(-1, -1)
	for y in range(grid.size):
		for x in range(grid.size):
			var b: String = grid.grid[y][x]["building"]
			if b.begins_with("res_"):
				houses += 1
			elif b == "hyanggyo":
				_hg_anchor = Vector2i(x, y)
	# 서당: 가옥 100채당 1곳(한 턴에 하나씩 채움)
	var seodangs: int = grid.list_plazas("seodang").size()
	if seodangs < int(float(houses) / 100.0):
		var p := grid.allocate_edu_site("seodang", 2, 0, true)
		if p.x >= 0:
			seodangs += 1
			if citizens != null and citizens.has_method("spawn_seodang_students"):
				citizens.spawn_seodang_students(p)
			if um != null and um.has_university():
				emit_signal("notice", "동네에 초등학교가 문을 열었습니다! (학문력 +1/달)", "🏫")
			else:
				emit_signal("notice", "마을 아이들이 모여 글을 배우는 서당이 문을 열었습니다! (학문력 +1/달)", "📖")
	# 매곡서원: 하나뿐, 박석길 1칸 이상 인접한 방리(흙길 방리도 허용)
	var has_seowon: bool = not grid.list_plazas("seowon").is_empty()
	# 근대화 시대 수원 대학교 개편 뒤: 서당=초등학교, 서원=중등학교. 중등학교는 초등학교 5곳당 1곳(한 턴에 하나씩)
	if um != null and um.has_university():
		var seowons: int = grid.list_plazas("seowon").size()
		@warning_ignore("integer_division")
		if seowons < seodangs / UrbanEvolutionManager.SECONDARY_PER_ELEMENTARY:
			var ms := grid.allocate_edu_site("seowon", 3, 0, true)
			if ms.x < 0:
				ms = grid.allocate_edu_site("seowon", 3, 0, true, true)
			if ms.x >= 0:
				has_seowon = true
				emit_signal("notice", "초등학교 졸업생을 받을 중등학교가 새로 문을 열었습니다! (초등학교 %d곳 → 중등학교 %d곳)" % [seodangs, seowons + 1], "🏫")
	# PORT-TRACE [서원 조건]: 사용자 — 서당이 3곳 생긴 뒤에 서원 1곳(도시에 하나뿐은 그대로)
	if not has_seowon and seodangs >= 3 and randf() < 0.3:
		# need_stone=1: 박석길 1칸 이상, allow_huts=true: 초가집 자리도 헐고 확보
		# PORT-TRACE [서원 안 생김]: 방리가 기와집으로 꽉 차면 3x3 빈터·초가 자리가 없어 영영 안 생겼다 → 차례로 조건을 푼다
		var sw := grid.allocate_edu_site("seowon", 3, 1, true)
		if sw.x < 0:
			sw = grid.allocate_edu_site("seowon", 3, 1, true, true)
		if sw.x < 0:
			sw = grid.allocate_edu_site("seowon", 3, 0, true, true)
		if sw.x >= 0:
			has_seowon = true
			emit_signal("notice", "박석길 방리에 선비들이 매곡서원(梅谷書院)을 세웠습니다! (인재 출현 확률 +20%)", "🏛️")
	# 수원향교 유지비
	hyanggyo_active = false
	if _hg_anchor.x >= 0:
		if sim.gold >= 500 and sim.rice >= 500:
			sim.gold -= 500
			sim.rice -= 500
			hyanggyo_active = true
		else:
			emit_signal("notice", "수원향교 유지비(금 500·쌀 500)가 모자라 이번 철엔 강학과 제향이 멈췄습니다.", "⚠")
	# 효과
	var new_acad := CityStats.recalculate_academic_power(grid, sim.retainers if sim else {})
	sim.academic = new_acad
	if hyanggyo_active:
		sim.loyalty = mini(100, sim.loyalty + 1)
	court.talent_bonus = (0.2 if has_seowon else 0.0) + (0.2 if hyanggyo_active else 0.0)
	court.research_bonus = 0.15 if hyanggyo_active else 0.0


## 향교가 운영 중이면 14초마다 유생 하나가 성문 ↔ 향교를 오간다(최대 3명)
func _process(delta: float) -> void:
	if not hyanggyo_active or citizens == null or _hg_anchor.x < 0 or citizens._gate_cache.is_empty():
		return
	_yusaeng_t -= delta * citizens.time_scale
	if _yusaeng_t > 0.0:
		return
	_yusaeng_t = 14.0
	var live := 0
	for a: Dictionary in citizens.agents:
		if a.get("type", "") == "yusaeng":
			live += 1
	if live >= 3:
		return
	var gate: Vector2i = citizens._gate_cache[0]
	for g: Vector2i in citizens._gate_cache:
		if absi(g.x - _hg_anchor.x) + absi(g.y - _hg_anchor.y) < absi(gate.x - _hg_anchor.x) + absi(gate.y - _hg_anchor.y):
			gate = g
	_yusaeng_flip = not _yusaeng_flip
	if _yusaeng_flip:
		citizens._spawn_trip("yusaeng", gate, _hg_anchor, "명륜당에 강학 들으러 왔소.")
	else:
		citizens._spawn_trip("yusaeng", _hg_anchor, gate, "")
