extends Node2D
class_name MilitaryDrillManager

## [서장대 야조 및 연무대 군사훈련 시각 연출 및 카메라 포커스 엔진]
## - 화성능행도 병풍(서장대성조도, 득중정어사도) 고증 기반
## - 연 1회 서장대 야조 / 연무대 사열 훈련 발동 시 카메라 1.0초 부드러운 자동 이동
## - 유저 입력 시 카메라 제어권 즉각 반환 (Interruption Safety)
## - 정조 대왕(황금 갑주와 등채 지휘) 및 장용영 군사들의 일사불란한 조총 일제 사격(백색 연막 FX)
## - 국궁 일제 사격(포물선 화살 비행) 및 성곽 횃불 명멸 연출

signal drill_started(drill_type: String)
signal drill_completed(drill_type: String)

enum DrillType {
	NONE = 0,
	SEOJANGDAE_YAJO = 1, # 서장대 야간 군사 훈련
	YEONMUDAE_DRILL = 2  # 연무대(동장대) 주간 무예 사열
}

var current_drill: DrillType = DrillType.NONE
## CitizenLayer가 읽는 진행 중 훈련(연무대 훈련 장면을 CitizenLayer가 직접 그리게 하려고)
static var active_kind: int = 0
## 지휘관: 을묘원행 때만 정조, 평시에는 외장용영 대장 백동수
var _royal_cmd: bool = false
var _ym_scene: bool = false
var drill_timer: float = 0.0
var drill_duration: float = 8.0

# 외부 참조 객체
var sim: SimulationCore = null
var grid: GameGrid = null
var camera: CameraController = null
var hud: HUDController = null
var city_layer: CityLayer = null

# 훈련 중심 타일 및 월드 좌표
var drill_tile_pos: Vector2i = Vector2i(6, 29)
var drill_world_pos: Vector2 = Vector2.ZERO

# 야간 효과 및 횃불
var night_alpha: float = 0.0
var _torch_flicker: float = 1.0
var _cannon_flash: float = 0.0
var _target_night_alpha: float = 0.0

# 연막 및 발사체 오브젝트 풀 (GC 렉 원천 방지)
const MAX_SMOKE: int = 32
const MAX_ARROWS: int = 16
var smoke_pool: Array[Dictionary] = []
var arrow_pool: Array[Dictionary] = []

# 훈련 병사 엔티티 풀
var drill_troops: Array[Dictionary] = []

func _init() -> void:
	name = "MilitaryDrillManager"
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 905 # PORT-TRACE [을묘원행 안 보임]: 지형·건물 조각 그림(z 10~76) 위에 오도록 — 예전 값은 조각에 덮였다
	_init_vfx_pools()

func _init_vfx_pools() -> void:
	smoke_pool.clear()
	for i in range(MAX_SMOKE):
		smoke_pool.append({
			"active": false,
			"pos": Vector2.ZERO,
			"vel": Vector2.ZERO,
			"life": 0.0,
			"max_life": 1.2,
			"radius": 4.0,
			"alpha": 0.0
		})

	arrow_pool.clear()
	for i in range(MAX_ARROWS):
		arrow_pool.append({
			"active": false,
			"from": Vector2.ZERO,
			"to": Vector2.ZERO,
			"progress": 0.0,
			"speed": 1.4,
			"arc_h": 22.0
		})

func setup(
	s_core: SimulationCore,
	g_grid: GameGrid,
	cam: CameraController = null,
	h_hud: HUDController = null,
	c_layer: CityLayer = null
) -> void:
	sim = s_core
	grid = g_grid
	camera = cam
	hud = h_hud
	city_layer = c_layer

## =========================================================================
## 1. 서장대 야간 군사 훈련 (야조: 夜操) 시작
## =========================================================================
func start_seojangdae_drill(is_royal_procession: bool = false) -> bool:
	if current_drill != DrillType.NONE:
		return false

	current_drill = DrillType.SEOJANGDAE_YAJO
	active_kind = DrillType.SEOJANGDAE_YAJO
	_royal_cmd = is_royal_procession or (sim != null and sim.is_eulmyo_active)
	drill_timer = 0.0
	drill_duration = 8.5
	_target_night_alpha = 0.72
	night_alpha = 0.0

	# 서장대 위치 식별 (실제 서장대 완공 건물 좌표 우선, 부재 시 팔달산 산지 정상 좌표)
	var actual_sj: Vector2i = BuildingManager.get_building_pos("seojangdae", grid)
	if actual_sj.x >= 0:
		drill_tile_pos = actual_sj
	else:
		drill_tile_pos = _find_paldal_mountain_peak(Vector2i(6, 29))

	var tile_elev: float = 3.0
	_sj_n = 1
	if grid and grid.in_bounds(drill_tile_pos.x, drill_tile_pos.y):
		tile_elev = float(grid.grid[drill_tile_pos.y][drill_tile_pos.x].get("elevation", 3.0))
		if grid.grid[drill_tile_pos.y][drill_tile_pos.x].has("sj2"):
			_sj_n = 2
	_sj_elev = tile_elev
	var half: float = float(_sj_n) * 0.5
	drill_world_pos = _cell_to_world(float(drill_tile_pos.x) + half, float(drill_tile_pos.y) + half, tile_elev)

	# 카메라 1.0초 자동 부드러운 패닝 (서장대로 이동)
	if camera:
		camera.focus_on_coordinate(drill_world_pos, true, 1.0)

	_setup_seojangdae_troops()
	emit_signal("drill_started", "SEOJANGDAE_YAJO")

	if hud and not is_royal_procession:
		hud._show_toast("서장대 야조 개시! 횃불을 밝히고 %s의 지휘 아래 장용영 야간 조련이 시작됩니다." % ("정조 대왕" if _royal_cmd else "외장용영 대장 백동수"), "⚔️")

	queue_redraw()
	return true

## =========================================================================
## 2. 연무대(동장대) 주간 무예 사열 훈련 시작
## =========================================================================
func start_yeonmudae_drill() -> bool:
	if current_drill != DrillType.NONE:
		return false

	current_drill = DrillType.YEONMUDAE_DRILL
	active_kind = DrillType.YEONMUDAE_DRILL
	_royal_cmd = sim != null and sim.is_eulmyo_active
	drill_timer = 0.0
	drill_duration = 7.5
	_target_night_alpha = 0.0
	night_alpha = 0.0

	# 연무대 위치 식별
	drill_tile_pos = _find_building_pos("yeonmudae", Vector2i(38, 20))
	drill_world_pos = _cell_to_world(float(drill_tile_pos.x), float(drill_tile_pos.y), 1.0)
	# 새 연무대(ym5)는 CitizenLayer가 광장 진법·사대 궁병 장면을 그린다 — 여기서는 카메라만 그 가운데로
	_ym_scene = false
	if grid and city_layer and city_layer.has_method("ym_pt"):
		for y in range(grid.size):
			for x in range(grid.size):
				var cell: Dictionary = grid.grid[y][x]
				if cell.has("ym5") and not cell.has("wall_build"):
					drill_world_pos = city_layer.ym_pt(cell["ym5"], 0.0, 0.6)
					_ym_scene = true
					break
			if _ym_scene:
				break

	# 카메라 1.0초 자동 부드러운 패닝
	if camera:
		camera.focus_on_coordinate(drill_world_pos, true, 1.0)

	_setup_yeonmudae_troops()
	emit_signal("drill_started", "YEONMUDAE_DRILL")

	if hud:
		hud._show_toast("연무대 무예 사열 거행! 장용영 군사들이 연병장에서 국궁 일제 사격과 창검술을 연마합니다.", "🏹")

	queue_redraw()
	return true

## =========================================================================
## 3. 병사 배치 구축 (서장대 / 연무대)
## =========================================================================
var _sj_n: int = 1
var _sj_elev: float = 3.0

## 서장대 앞자락(화면 앞쪽 모서리)에 지휘관, 그 앞에 조총 포수 2열 3명, 양 옆 변을 따라 살수 넷.
## 타일 좌표로 잡아 서장대 크기(1x1·2x2)와 산 높이에 맞춘다.
func _sj_pt(gx: float, gy: float) -> Vector2:
	return _cell_to_world(float(drill_tile_pos.x) + gx, float(drill_tile_pos.y) + gy, _sj_elev)

func _setup_seojangdae_troops() -> void:
	drill_troops.clear()
	var n: float = float(_sj_n)
	# 1) 지휘관 — 누각 앞 기단 모서리에서 등채를 들고 지휘
	drill_troops.append({"role": "commander", "pos": _sj_pt(n + 0.15, n + 0.15), "dir": 1})
	# 2) 조총 포수 6명 — 앞마당 2열 횡대
	for row in range(2):
		for col in range(3):
			var lat := (float(col) - 1.0) * 0.38
			var dep := 0.55 + float(row) * 0.32
			drill_troops.append({
				"role": "posu",
				"pos": _sj_pt(n + dep + lat, n + dep - lat),
				"dir": 1 if col != 0 else 0,
				"volley_delay": float(col) * 0.25 + float(row) * 0.5
			})
	# 3) 살수(당파창) 4명 — 서장대 양 옆 변
	for i in range(4):
		var along := 0.25 + float(i % 2) * 0.45 * n
		if i < 2:
			drill_troops.append({"role": "salsu", "pos": _sj_pt(n + 0.35, along), "dir": 0})
		else:
			drill_troops.append({"role": "salsu", "pos": _sj_pt(along, n + 0.35), "dir": 1})

func _setup_yeonmudae_troops() -> void:
	drill_troops.clear()
	if _ym_scene:
		return
	var base_p: Vector2 = drill_world_pos

	# 1) 사열 군관
	drill_troops.append({
		"role": "lead_cavalry",
		"pos": base_p + Vector2(-28.0, 4.0),
		"is_drill": true,
		"dir": 0
	})

	# 2) 국궁 사수 4명 (사대 앞 도열)
	for i in range(4):
		var sy: float = -12.0 + float(i) * 10.0
		drill_troops.append({
			"role": "sasu",
			"pos": base_p + Vector2(-12.0, sy),
			"is_drill": true,
			"dir": 0,
			"shoot_timer": float(i) * 0.4
		})

	# 3) 살수 창검 훈련 4명
	for i in range(4):
		var my: float = -10.0 + float(i) * 12.0
		drill_troops.append({
			"role": "salsu",
			"pos": base_p + Vector2(18.0, my),
			"is_drill": true,
			"dir": 1
		})

## =========================================================================
## 4. 메인 프로세스 루프
## =========================================================================
func _process(delta: float) -> void:
	if current_drill == DrillType.NONE:
		return

	drill_timer += delta

	# 야간 오버레이 보간
	if current_drill == DrillType.SEOJANGDAE_YAJO:
		night_alpha = move_toward(night_alpha, _target_night_alpha, delta * 0.35)
		_torch_flicker = sin(drill_timer * 11.0) * 0.18 + 0.82
		_cannon_flash = maxf(0.0, _cannon_flash - delta * 2.5)

		# 1.6초 주기 조총 일제 사격 및 백색 연막 FX 분출
		if fmod(drill_timer, 1.6) < delta:
			_fire_musket_volley()

		# 3.2초 주기 신포 발사 섬광
		if fmod(drill_timer, 3.2) < delta:
			_cannon_flash = 1.0
	else:
		# 연무대 훈련: 1.2초 주기 화살 발사(새 연무대는 CitizenLayer가 궁병·화살을 그린다)
		if not _ym_scene and fmod(drill_timer, 1.2) < delta:
			_shoot_arrow_volley()

	_update_vfx_particles(delta)

	# 훈련 종료 판정
	if drill_timer >= drill_duration:
		_finish_drill()

	queue_redraw()

func _fire_musket_volley() -> void:
	for troop: Dictionary in drill_troops:
		if troop.get("role", "") == "posu":
			var p: Vector2 = troop.get("pos", Vector2.ZERO) + Vector2(12.0, -4.0)
			_spawn_smoke(p)

func _shoot_arrow_volley() -> void:
	for troop: Dictionary in drill_troops:
		if troop.get("role", "") == "sasu":
			var from_p: Vector2 = troop.get("pos", Vector2.ZERO) + Vector2(6.0, -3.0)
			var to_p: Vector2 = from_p + Vector2(randf_range(50.0, 70.0), randf_range(-15.0, 15.0)) # 과녁 방향
			_spawn_arrow(from_p, to_p)

func _spawn_smoke(pos: Vector2) -> void:
	for s: Dictionary in smoke_pool:
		if not s["active"]:
			s["active"] = true
			s["pos"] = pos
			s["vel"] = Vector2(randf_range(2.0, 8.0), randf_range(-6.0, -2.0))
			s["life"] = 0.0
			s["max_life"] = randf_range(1.0, 1.4)
			s["radius"] = randf_range(3.5, 6.0)
			s["alpha"] = 0.85
			break

func _spawn_arrow(from_p: Vector2, to_p: Vector2) -> void:
	for arr: Dictionary in arrow_pool:
		if not arr["active"]:
			arr["active"] = true
			arr["from"] = from_p
			arr["to"] = to_p
			arr["progress"] = 0.0
			arr["speed"] = randf_range(1.2, 1.6)
			arr["arc_h"] = randf_range(18.0, 26.0)
			break

func _update_vfx_particles(delta: float) -> void:
	# 연막 파티클
	for s: Dictionary in smoke_pool:
		if not s["active"]: continue
		s["life"] += delta
		if s["life"] >= s["max_life"]:
			s["active"] = false
		else:
			var t: float = float(s["life"]) / float(s["max_life"])
			s["pos"] += Vector2(s["vel"]) * delta
			s["radius"] += delta * 6.0 # 피어오르며 뭉게뭉게 커짐
			s["alpha"] = (1.0 - t) * 0.8

	# 화살 투사체
	for arr: Dictionary in arrow_pool:
		if not arr["active"]: continue
		arr["progress"] += delta * float(arr["speed"])
		if arr["progress"] >= 1.0:
			arr["active"] = false

func _finish_drill() -> void:
	var finished_type: String = "SEOJANGDAE_YAJO" if current_drill == DrillType.SEOJANGDAE_YAJO else "YEONMUDAE_DRILL"
	current_drill = DrillType.NONE
	active_kind = 0
	night_alpha = 0.0
	_target_night_alpha = 0.0
	drill_troops.clear()

	emit_signal("drill_completed", finished_type)

	if hud:
		if finished_type == "SEOJANGDAE_YAJO":
			hud._show_toast("서장대 야조 훈련 성료! 성곽 방호력과 장용영 군사들의 사기가 극에 달했습니다.", "🛡️")
		else:
			hud._show_toast("연무대 무예 사열 성료! 일사불란한 궁술과 창검술로 국방력이 한층 강화되었습니다.", "🎯")

## =========================================================================
## 5. 2.5D 시각 연출 (_draw)
## =========================================================================
func _draw() -> void:
	if current_drill == DrillType.NONE:
		return

	var anim_frame: int = int(drill_timer * 4.0) % 2

	# 1. 서장대 야조 시 횃불 및 신포 섬광
	if current_drill == DrillType.SEOJANGDAE_YAJO:
		_draw_torches_and_cannons()

	# 2. 훈련 병사 — 도시 NPC와 같은 48칸 도트(NpcSprites). 화면 아래쪽(앞)부터가 아니라 위쪽부터 그려 앞사람이 뒷사람을 가린다
	var order: Array = drill_troops.duplicate()
	order.sort_custom(func(a1: Dictionary, b1: Dictionary) -> bool: return Vector2(a1["pos"]).y < Vector2(b1["pos"]).y)
	var winter: bool = city_layer != null and city_layer.current_season == "겨울"
	for troop: Dictionary in order:
		_draw_troop(troop, anim_frame, winter)

	# 3. 백색 화약 연막 FX 파티클
	for s: Dictionary in smoke_pool:
		if not s["active"]: continue
		var p: Vector2 = s["pos"]
		var rad: float = float(s["radius"])
		var a: float = float(s["alpha"])
		draw_circle(p, rad, Color(0.95, 0.95, 0.95, a))
		draw_circle(p + Vector2(2.0, -1.0), rad * 0.7, Color(0.85, 0.85, 0.85, a * 0.8))

	# 4. 국궁 화살 투사체 (포물선 궤적)
	for arr: Dictionary in arrow_pool:
		if not arr["active"]: continue
		var prog: float = float(arr["progress"])
		var from_p: Vector2 = arr["from"]
		var to_p: Vector2 = arr["to"]
		var current_p: Vector2 = from_p.lerp(to_p, prog)
		# 2차 곡선 고도 오프셋
		var arc_offset: float = sin(prog * PI) * float(arr["arc_h"])
		var draw_p: Vector2 = current_p - Vector2(0.0, arc_offset)

		# 화살 날개와 촉 선
		var tip_dir: Vector2 = (to_p - from_p).normalized()
		var tail_p: Vector2 = draw_p - tip_dir * 5.0
		draw_line(tail_p, draw_p, Color("8d6e63"), 1.2)
		draw_circle(draw_p, 1.0, Color("e0e0e0")) # 촉

func _draw_troop(troop: Dictionary, frame: int, winter: bool) -> void:
	var r: String = String(troop.get("role", "soldier"))
	var p: Vector2 = troop.get("pos", Vector2.ZERO)
	var d: int = int(troop.get("dir", 0))
	var face: float = 1.0 if (d == 0 or d == 2) else -1.0
	match r:
		"commander", "lead_cavalry":
			if _royal_cmd:
				ProcessionUnitArt.draw_unit(self, p, "jeongjo_king", d, frame, 1.0, true)
				return
			NpcSprites.draw_kind(self, p, "baek_dongsu", 0, winter, d, 0)
			# 등채(지휘봉)를 4초마다 치켜든다 + 수기(手旗)
			var up := 0.5 + 0.5 * sin(drill_timer * 2.2)
			var hand := p + Vector2(4.5 * face, -15.0)
			draw_line(hand, hand + Vector2(5.0 * face, -6.0 - up * 6.0), Color("5c3a21"), 1.2)
			var fp := p + Vector2(-6.0 * face, -4.0)
			draw_line(fp, fp + Vector2(0, -26), Color("3a2a1a"), 1.0)
			FastDraw.poly(self, PackedVector2Array([fp + Vector2(0, -26), fp + Vector2(-9.0 * face, -23.0 + sin(drill_timer * 3.0)), fp + Vector2(0, -19)]), Color("c0392b"))
		"posu":
			NpcSprites.draw_kind(self, p, "posu", 0, winter, d, 0)
			var mz := p + Vector2(4.0 * face, -13.0)
			draw_line(mz - Vector2(3.0 * face, -2.0), mz + Vector2(9.0 * face, -1.0), Color("3a2a1a"), 1.3) # 조총
		"salsu":
			NpcSprites.draw_kind(self, p, "salsu", 0, winter, d, frame)
			var hp := p + Vector2(3.5 * face, -12.0)
			var thrust := maxf(0.0, sin(drill_timer * 4.0)) * 4.0
			draw_line(hp + Vector2(-2.0 * face, 6.0), hp + Vector2((6.0 + thrust) * face, -12.0), Color("6a4a2a"), 1.0)
			draw_line(hp + Vector2((6.0 + thrust) * face, -12.0), hp + Vector2((7.5 + thrust) * face, -16.0), Color("b0b0b0"), 1.2) # 당파 날
		"sasu":
			NpcSprites.draw_kind(self, p, "sasu", 0, winter, d, 0)
			FastDraw.arc(self, p + Vector2(5.0 * face, -14.0), 5.0, -PI * 0.5 - 1.0, -PI * 0.5 + 1.0, 6, Color("3a2416"), 1.1)
		_:
			NpcSprites.draw_kind(self, p, "soldier", 0, winter, d, frame)

func _draw_torches_and_cannons() -> void:
	var base_p: Vector2 = drill_world_pos
	# 서장대 누각 좌우 횃불
	draw_circle(base_p + Vector2(-18.0, -22.0), 4.5 * _torch_flicker, Color("ff4500"))
	draw_circle(base_p + Vector2(-18.0, -22.0), 2.5 * _torch_flicker, Color("ffa500"))
	draw_circle(base_p + Vector2(18.0, -22.0), 4.5 * _torch_flicker, Color("ff4500"))
	draw_circle(base_p + Vector2(18.0, -22.0), 2.5 * _torch_flicker, Color("ffa500"))

	# 성곽 라인 횃불열 6개소
	for i in range(6):
		var fx: float = base_p.x - 50.0 + float(i) * 20.0
		var fy: float = base_p.y - 8.0
		draw_circle(Vector2(fx, fy), 3.5 * _torch_flicker, Color("ff5722"))
		draw_circle(Vector2(fx, fy), 1.8 * _torch_flicker, Color("ffeb3b"))

	# 신포 대포 일제 사격 섬광
	if _cannon_flash > 0.05:
		draw_circle(base_p + Vector2(0.0, -12.0), 38.0 * _cannon_flash, Color(1.0, 1.0, 0.7, _cannon_flash * 0.75))
		draw_circle(base_p + Vector2(20.0, -16.0), 22.0 * _cannon_flash, Color(0.9, 0.9, 0.9, _cannon_flash * 0.6))

## =========================================================================
## 6. 보조 유틸리티 함수
## =========================================================================
func _find_building_pos(b_type: String, fallback: Vector2i) -> Vector2i:
	if grid == null or grid.grid.is_empty():
		return fallback

	for y in range(grid.size):
		for x in range(grid.size):
			var b: String = str(grid.grid[y][x].get("building", ""))
			if b == b_type:
				return Vector2i(x, y)
	return fallback

func _cell_to_world(x: float, y: float, elev: float = 0.0) -> Vector2:
	if city_layer != null and city_layer.has_method("cell_center"):
		return city_layer.cell_center(x, y, elev)
	# Isometric 기본 공식
	return Vector2((x - y) * 32.0, (x + y) * 16.0 - elev * 12.0)

func _find_paldal_mountain_peak(fallback: Vector2i) -> Vector2i:
	if grid == null or grid.grid.is_empty():
		return fallback
	var best := fallback
	var max_elev: float = -1.0
	for y: int in range(grid.size):
		for x: int in range(mini(20, grid.size)):
			var cell: Dictionary = grid.grid[y][x]
			if str(cell.get("terrain", "")) == "mountain":
				var e: float = float(cell.get("elevation", 0.0))
				if e > max_elev:
					max_elev = e
					best = Vector2i(x, y)
	return best
