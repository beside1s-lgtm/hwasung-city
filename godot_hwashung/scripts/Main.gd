extends Node2D

@onready var time_manager: TimeManager = $TimeManager
@onready var simulation_core: SimulationCore = $SimulationCore
@onready var hud: HUDController = $HUD
@onready var camera: CameraController = $Camera2D
@onready var map_loader: TiledMapLoader = $TiledMapLoader

# PORT-TRACE P10: TS 기능 이식 모듈 (docs/godot_port_log.md). 씬 파일 수정 없이 코드로 생성한다.
var grid: GameGrid
var citizens: CitizenManager
var court: CourtSystem
var trade: TradeSystem
var turns: TurnSystem
var outside: OutsideSettlement # PORT-TRACE P25: 성 밖 자연발생 취락
var city: CityLayer
var panels: PanelController
var quests: Node
var music: MusicManager # 배경음악(상황별 곡 전환)
var audio: AudioSystem # PORT-TRACE P20: src/core/AudioSystem.ts 이식
var tutorial: TutorialGuide
## 타이틀 화면에서 '새 게임' 선택 시 기존 인게임 상태 완전 초기화 재부팅 플래그
static var is_restarting_as_new_game: bool = false
var intro_layer: IntroVideoLayer = null
var title_screen: TitleScreenLayer = null
var inspect_popup: InspectPopup = null
var trial_manager: TrialManager = null
var trial_popup: TrialPopup = null
var royal_procession: RoyalProcessionManager = null
var military_drill: MilitaryDrillManager = null
var ending_manager: EndingManager = null
var world_markers: WorldMarkerManager = null
var bibyeonsa_sibo: BibyeonsaSiboPopup = null
var haenggung_popup: HaenggungSubBuildingPopup = null
var seojangdae_popup: SeojangdaePopup = null
var yajo_minigame: YajoMiniGamePopup = null
var yeonmudae_popup: YeonmudaePopup = null
var yeonmudae_minigame: YeonmudaeMiniGamePopup = null
var ubongo_wall_repair: UbongoWallRepairPopup = null
var building_interaction: BuildingInteractionManager = null
var event_manager: EventManager = null
var input_manager: InputManager = null
var siege_defense: SiegeDefenseManager = null
var _is_game_started: bool = false
var ambience: BuildingAmbience = null # 타이틀 화면 동안은 소리를 끈다
var season_color_filter: SeasonColorFilter = null
var cam_lod_controller: CameraLODController = null
var env_vfx_manager: EnvironmentVFXManager = null

# PORT-TRACE [텍스처 베이크]: 정적 지형/건물을 SubViewport에 한 번 구워 Sprite2D로 표시하고
# (world_viewport/baker/world_sprite), 실제로 움직이는 시민만 CitizenLayer가 매 프레임 그린다.
# city는 여전히 입력·건설·Undo·지형 편집 로직 전체를 담당하지만 화면에는 보이지 않는다
# (invisible = 그리기 비용 0, 하지만 _unhandled_input은 그대로 받는다).
var world_viewport: SubViewport
var baker: CityLayer
var festivals: FestivalSystem
var bake_bands: Array[CityLayer] = [] # PORT-TRACE [렉 해결: 띠 굽기]: 깊이 띠별로 따로 그리는 CityLayer들
var _tile_hashes: PackedInt64Array = PackedInt64Array()
var _baked_season: String = ""
var _pending_bands := {} # 다시 그려야 할 띠 번호(프레임당 BAND_COST_PER_FRAME만큼씩 처리)
## 한 프레임에 다시 그릴 띠 분량: 바닥 칸 1, 건물 칸 3으로 센다(바닥 칸 그리기 ≈ 0.04ms, 건물 칸 ≈ 0.12ms → 프레임당 약 8ms)
const BAND_COST_PER_FRAME := 200
var _season_swap := false # 계절 전환 중: 띠를 나눠 그리는 동안 화면 조각은 이전 계절 그림 그대로 둔다
var _swap_vp_queue: Array = [] # 계절 전환 뒤 화면 밖 조각(프레임마다 몇 개씩 다시 렌더링)
const SWAP_VP_PER_FRAME := 2
var world_sprite: Sprite2D
var citizen_layer: CitizenLayer
const WORLD_BAKE_PAD := 220.0
const WORLD_BAKE_MIN_ELEV := -3.0
const WORLD_BAKE_MAX_ELEV := 9.0

var _world_bounds_cached: Rect2 = Rect2()
var _world_bounds_dirty: bool = true
## PORT-TRACE [성능: 조각 굽기]: 측정(건물 ~1000채) — 띠를 다시 그릴 때마다 지도 전체 크기 SubViewport 하나를 통째로 다시
## 렌더링해 프레임당 ~60ms가 고정으로 들었다(띠를 얇게 해도 그대로). 깊이 CHUNK_DEPTH줄씩 끊은 가로 띠 모양 조각마다
## SubViewport+Sprite를 따로 두고(띠 = 화면 y가 같은 대각선 줄이라 조각은 가로 띠), 바뀐 띠가 든 조각만 다시 렌더링한다.
## 조각의 경계 상자는 그 띠들의 실제 칸 위치 + 높은 지형·지붕 여유로 잡고, 앞 조각 스프라이트가 뒤 조각 위에 그려진다.
const CHUNK_DEPTH := 4
var _chunks: Array = [] # [{vp: SubViewport, sprite: Sprite2D, b0: int, b1: int, rect: Rect2}]
var _rebake_requested: bool = false
var _rebake_retry := false # 다시 굽기가 이번 프레임 차례(GameGrid.frame_claim)를 못 받아 다음 프레임에 다시 할 것
var _season_apply_pending := "" # 지형을 바꿔 줄 새 계절(차례를 받으면 _apply_seasonal_terrain_globally)

func _ready() -> void:
	GameSettings.ensure_loaded()
	GameSettings.apply_all()

	# 틱 시뮬레이션 연동
	time_manager.simulation_tick.connect(simulation_core.on_simulation_tick)

	# 카메라 초기 위치: 맵 중심 (PORT-TRACE [경량화 감사]: P24에서 64x64로 확장된 뒤
	# 갱신되지 않았던 옛 20그리드 좌표(0,320) 버그를 CameraController.reset_view()와 함께 수정)
	camera.position = Vector2(0, 1024)
	camera.zoom = Vector2(1.2, 1.2)

	_setup_port_modules()

	# HUD 연동 (카메라 및 도시 레이어와 신호 연결)
	hud.setup(time_manager, simulation_core, camera, city, citizens)
	hud.zoom_in_requested.connect(camera.zoom_in)
	hud.zoom_out_requested.connect(camera.zoom_out)
	hud.center_view_requested.connect(camera.reset_view)

	# 반란/도적 침입 및 교전 발생 시 카메라 자동 포커스 및 HUD 경보 배너 연동
	citizens.bandit_battle_started.connect(func(w_pos: Vector2, loc_name: String):
		camera.focus_on_coordinate(w_pos, true)
		hud.show_raid_alert_banner(w_pos, loc_name)
	)
	citizens.bandit_battle_ended.connect(func(repelled: bool):
		hud.hide_raid_alert_banner()
		var res_msg := "⚔️ [승전보] 장용영 정예군이 도적 떼를 완전히 소탕하고 격퇴했습니다! (2년간 평온)" if repelled else "⚠️ [약탈 피해] 도적 떼가 민가를 약탈하고 퇴각했습니다."
		hud.push_top_alert(res_msg)
	)

	# 사계절 변화(봄, 여름, 가을, 겨울) 맵 텍스처 및 시민 복식 동기화
	season_color_filter = SeasonColorFilter.new()
	season_color_filter.name = "WorldSeasonFilter"
	add_child(season_color_filter)

	city.current_season = time_manager.get_current_season()
	citizens.current_season = time_manager.get_current_season()
	season_color_filter.current_season = time_manager.get_current_season()
	season_color_filter.color = SeasonColorFilter.get_current_world_tint(time_manager.get_current_season())

	time_manager.season_changed.connect(func(s: String):
		city.current_season = s
		citizens.current_season = s
		if season_color_filter:
			season_color_filter.transition_to_season(s, 1.0)
		# [계절 전환 지형 동기화] 맵 전체 지형 및 밴드 0ms 동시 전환 (패치워크 영구 방지)
		# PORT-TRACE [렉: 계절 바뀌는 달 멈칫]: 지형 계절 색 다시 계산(30ms 남짓)이 그 달 턴 정산 첫 프레임과 겹쳐 멈칫했다 →
		# 턴 계산이 끝난 뒤 무거운 일 차례(GameGrid.frame_claim)를 받아 _process에서 바꾼다(그동안 계절 색 필터가 먼저 바뀐다)
		_season_apply_pending = s
		# 계절 운영 유지비 및 인재 녹봉 정산
		var res: Dictionary = simulation_core.process_seasonal_maintenance(grid)
		if res.get("total", 0) > 0 and not res.get("deficit", false):
			var msg: String = "계절 운영비: 공공기관 유지비 %d냥, 인재 녹봉 %d냥이 지출되었습니다." % [int(res["facility_maintenance"]), int(res["retainer_salaries"])]
			if hud:
				hud._show_toast(msg, "🪙")

		# 계절 인구 역학, 가옥-폐허 순환 동기화 및 인구 비례 세수 입고
		var pop_res: Dictionary = simulation_core.process_seasonal_population(grid)
		var tax_inc: int = int(pop_res.get("seasonal_tax", 0))
		var delta_p: int = int(pop_res.get("delta_population", 0))
		if tax_inc > 0 and hud:
			var pop_msg: String = "계절 정산: 세수 %d냥 입고 (인구 변동 %s%d명)" % [tax_inc, ("+" if delta_p >= 0 else ""), delta_p]
			hud._show_toast(pop_msg, "🪙")
	)

	# 초기 성곽 완공도 갱신
	simulation_core.update_fortress(grid)
	city.city_changed.connect(func(): simulation_core.update_fortress(grid))

	print("Hwashung City Tycoon: Godot 4 Real-time Core initialized.")

	if is_restarting_as_new_game:
		is_restarting_as_new_game = false
		_is_game_started = true
		_release_world()
		if tutorial and not tutorial._advice_seen.get("intro_done", false):
			tutorial.start_intro()
		if audio:
			audio.play("season")
		return

	# 인트로·타이틀 화면에서는 세상이 흐르지 않는다(시간·시민·건물 소리 정지). 새 게임을 눌러야 시작한다.
	_hold_world()

	# 타이틀 화면 레이어 사전 구축 (인트로 종료 시 크로스페이드로 즉시 전환)
	_setup_title_screen()

	# PORT-TRACE [화성성역 인트로 영상]: 게임 시작 시 정조 대왕과 화성성역 오프닝 시네마틱 재생
	play_intro_video()

## 화성성역 인트로 영상 재생
func play_intro_video() -> void:
	if has_node("IntroVideoLayer"):
		return
	if music:
		music.set_flag("intro", true)
	intro_layer = IntroVideoLayer.new()
	intro_layer.name = "IntroVideoLayer"
	add_child(intro_layer)
	intro_layer.intro_finished.connect(_on_intro_finished)

func _on_intro_finished() -> void:
	intro_layer = null
	if music:
		music.set_flag("intro", false)
	if not _is_game_started:
		# 게임 시작 전: 인트로 레이어의 페이드아웃으로 타이틀 화면이 이미 자연스럽게 드러나 있음
		if not title_screen:
			_setup_title_screen()

## 시간을 멈추고 건물 소리를 끈다(타이틀·인트로)
func _hold_world() -> void:
	if time_manager:
		time_manager.set_speed(TimeManager.SpeedMode.PAUSE)
	if ambience:
		ambience.active = false

## 게임이 실제로 시작될 때 시간을 흐르게 한다
func _release_world() -> void:
	if time_manager:
		time_manager.set_speed(TimeManager.SpeedMode.NORMAL)
	if ambience:
		ambience.active = true

## 타이틀 화면 구축
func _setup_title_screen() -> void:
	if has_node("TitleScreenLayer"):
		return
	title_screen = TitleScreenLayer.new()
	title_screen.name = "TitleScreenLayer"
	title_screen.audio_sys = audio
	add_child(title_screen)
	title_screen.start_new_game.connect(_on_start_new_game)
	title_screen.load_handler = _load_from_title
	# 인트로 영상 뒤에서 대기하므로 완전 불투명(1.0)으로 즉시 활성화
	if title_screen.root_control:
		title_screen.root_control.modulate.a = 1.0
	title_screen.visible = true

## 타이틀 화면에서 새 게임 시작 시 호출
func _on_start_new_game() -> void:
	if _has_game_progress():
		is_restarting_as_new_game = true
		CityStats.reset_to_defaults()
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
		return
	_is_game_started = true
	if music:
		music.clear_ending()
	_release_world()
	title_screen = null
	if tutorial and not tutorial._advice_seen.get("intro_done", false):
		tutorial.start_intro()
	if audio:
		audio.play("season")

func _has_game_progress() -> bool:
	if simulation_core and (simulation_core.turn > 1 or simulation_core.current_year > 1789 or simulation_core.gold != 2500):
		return true
	if grid and grid.fortress_progress > 0:
		return true
	return _is_game_started

## 저장을 불러온 직후 공통 정리(타이틀 이어하기·게임 중 불러오기·패배 후 되돌리기)
func on_game_loaded() -> void:
	if citizens:
		citizens.force_full_refresh()
	if ending_manager:
		ending_manager.sync_after_load()
	if tutorial:
		tutorial.sync_after_load()
	sync_all_world_markers()
	if festivals != null and time_manager != null:
		# 로드 완료 후 다음 프레임에 안전하게 호출 (즉시 호출 시 내부 상태 미준비 크래시 방지)
		festivals.call_deferred("on_season_changed", time_manager.get_current_season())

## 타이틀 [이어하기]: 저장 슬롯을 실제로 불러온다. 성공하면 true(타이틀은 알아서 닫힌다).
func _load_from_title(slot: int) -> bool:
	if siege:
		siege.reset()
	if not SaveSystem.load_game(slot, simulation_core, grid, time_manager, quests):
		return false
	_is_game_started = true
	if music:
		music.clear_ending()
	title_screen = null
	on_game_loaded()
	_release_world() # 불러온 시각부터 시간을 다시 흐르게 한다(튜토리얼 인트로는 새 게임에서만)
	if hud:
		hud._show_toast("실록의 기록을 성공적으로 복원했습니다!", "📜")
	if audio:
		audio.play("season")
	return true

## 인게임에서 타이틀 화면으로 나가기
func open_title_screen() -> void:
	_is_game_started = false
	if music:
		music.clear_ending()
	_hold_world()
	_setup_title_screen()
	if title_screen:
		title_screen.show_title_screen(0.7)

func _setup_port_modules() -> void:
	audio = AudioSystem.new()
	audio.name = "AudioSystem"
	add_child(audio)

	grid = GameGrid.new()
	grid.name = "GameGrid"
	add_child(grid) # _ready에서 Tiled 맵 기반 지형 구성

	court = CourtSystem.new()
	court.name = "CourtSystem"
	add_child(court)
	court.setup(simulation_core)

	input_manager = InputManager.new()
	input_manager.name = "InputManager"
	input_manager.camera = camera
	add_child(input_manager)

	cam_lod_controller = CameraLODController.new()
	cam_lod_controller.name = "CameraLODController"
	add_child(cam_lod_controller)
	CameraLODController.register_camera(camera)

	env_vfx_manager = EnvironmentVFXManager.new()
	env_vfx_manager.name = "EnvironmentVFXManager"
	add_child(env_vfx_manager)
	env_vfx_manager.setup(grid, city)

	event_manager = EventManager.new()
	event_manager.name = "EventManager"
	event_manager.setup(simulation_core, court, grid, input_manager)
	add_child(event_manager)
	event_manager.location_view_requested.connect(func(w_pos: Vector2):
		if camera != null and w_pos != Vector2.ZERO:
			camera.focus_on_coordinate(w_pos, true)
		if citizen_layer != null and citizen_layer.has_method("ping_incident"):
			citizen_layer.call("ping_incident", w_pos, "재난 현장")
	)

	court.scholar_appeared.connect(func(_cand: Dictionary):
		# [이분화 원칙] 인재 출현 및 등용 관련 정무 조언은 김판관(TutorialGuide)이 전담
		pass
	)

	citizens = CitizenManager.new()
	citizens.name = "CitizenManager"
	add_child(citizens)
	citizens.setup(grid, court, simulation_core)
	if citizens.sunla_manager != null:
		citizens.sunla_manager.dispute_occurred.connect(func(ev_type: String, pos: Vector2i):
			var w_pos := city.cell_center(float(pos.x) + 0.5, float(pos.y) + 0.5)
			var msg := "🚨 [저잣거리 분쟁] 취객 난투극이 발생했습니다! 순라군이 출동합니다." if ev_type == "brawl" else "🚨 [치안 비상] 소매치기 사건이 발생했습니다! 순라군이 추적합니다."
			hud.push_top_alert(msg, w_pos)
		)
		citizens.sunla_manager.dispute_resolved.connect(func(ev_type: String, success: bool, pos: Vector2i):
			var w_pos := city.cell_center(float(pos.x) + 0.5, float(pos.y) + 0.5)
			var msg := ""
			if success:
				msg = "⚖️ [치안 확립] 순라군이 %s 범인을 성공적으로 체포하여 관아로 압송했습니다!" % ("싸움꾼" if ev_type == "brawl" else "소매치기")
			else:
				msg = "⚠️ [범인 도주] 순라군 미도착으로 범인이 도주하여 저잣거리에 혼란이 발생했습니다!"
			hud.push_top_alert(msg, w_pos)
		)
	citizens.predator_attacked.connect(func(w_pos: Vector2, atype: String):
		var msg := "🚨 [호환(虎患) 경보] 팔달산 맹호가 민가를 습격했습니다! 포호책(포호 대책)을 결단하십시오!" if atype == "tiger" else "🚨 [맹수 습격] 팔달산 승냥이가 가축을 습격했습니다!"
		hud.push_top_alert(msg, w_pos)
	)
	# PORT-TRACE [배속 연동]: 정지/1x/2x/3x에 맞춰 시민·동물 이동과 애니메이션 속도도 함께 바뀐다.
	citizens.time_scale = time_manager.speed_factor()
	time_manager.speed_changed.connect(func(_m: int): citizens.time_scale = time_manager.speed_factor())

	# 도적 시스템 매니저 초기화 및 시뮬레이션 연결
	var b_mgr: BanditManager = citizens.bandit_mgr
	if b_mgr == null:
		b_mgr = BanditManager.new()
		citizens.bandit_mgr = b_mgr
	b_mgr.init_outer_tiles(grid)
	simulation_core.bandit_manager = b_mgr

	trade = TradeSystem.new()
	trade.name = "TradeSystem"
	add_child(trade)
	trade.setup(grid, simulation_core, citizens)
	# PORT-TRACE P22: 턴을 기다리지 않고 국경 도로 완성 즉시 교역 연결을 알린다.
	trade.route_connected.connect(func(_k, p_name: String): hud._show_toast("%s 방면 교역로가 개통되었습니다! 물자 유입이 시작됩니다." % p_name); audio.play("coin"))
	trade.route_disconnected.connect(func(_k, p_name: String): hud._show_toast("%s 방면 교역로가 끊겼습니다." % p_name))

	outside = OutsideSettlement.new()
	outside.name = "OutsideSettlement"
	add_child(outside)
	outside.setup(grid, simulation_core)

	turns = TurnSystem.new()
	turns.name = "TurnSystem"
	add_child(turns)
	turns.setup(simulation_core, grid, court, trade, outside)
	turns.audio = audio
	grid.pop_manager = simulation_core.pop_manager
	if simulation_core.pop_manager:
		simulation_core.pop_manager.sync_housing_lists_from_grid(grid)
	# PORT-TRACE [터 축조]: 행궁/동헌 등 주요 건물 완공 알림 (김판관 전담 보고)
	turns.site_completed.connect(func(building: String):
		if tutorial != null:
			tutorial.report_building_completed(building)
		audio.play("coin")
		if building == "haenggung":
			simulation_core.trigger_haenggung_completion(grid)
		elif building == "patrol":
			simulation_core.military_power += 30
	)
	simulation_core.project_skipped.connect(func(_pid: String, msg: String):
		hud._show_toast(msg, "📜")
	)
	# PORT-TRACE [역사 사전 퍼즐 도감]: 새 조각 발견 알림 + 턴마다 시설·인재 해금 점검
	GameProgressManager.listeners.clear()
	GameProgressManager.listeners.append(func(key: String, nm: String):
		hud._show_toast("🧩 역사 사전 조각 발견! — %s" % nm, "🧩")
		var cat: String = key.get_slice(":", 0)
		if GameProgressManager.is_board_complete(cat):
			hud._show_toast("🎉 [%s] 조각판이 완성되었습니다! 첫 화면의 역사 사전에서 확인하세요." % String(PuzzleData.board(cat).get("title", "")), "🎉")
	)
	GameProgressManager.scan(grid, simulation_core)
	turns.turn_report.connect(func(_r2): GameProgressManager.scan(grid, simulation_core))
	turns.turn_report.connect(func(_rep):
		if _rebake_requested:
			_do_rebake_world()
	)

	city = CityLayer.new()
	city.name = "CityLayer"
	add_child(city)
	var ref_layer: TileMapLayer = null
	for ch in map_loader.get_children():
		if ch is TileMapLayer:
			ref_layer = ch
			break
	city.setup(grid, simulation_core, citizens, ref_layer)
	if input_manager != null:
		input_manager.city = city
	city.audio = audio
	citizens.city = city # 시민 매니저에 도시 레이어 참조 연결 (월드 좌표 계산용)
	# PORT-TRACE [건물 단독 확대 효과음]: 확대해서 특수 건물 하나만 보일 때만 그 건물 소리(디바운스 0.2초)
	ambience = BuildingAmbience.new()
	ambience.name = "BuildingAmbience"
	add_child(ambience)
	ambience.setup(grid, camera, city, audio)
	city.tool_message.connect(hud._show_toast)
	city.tile_inspected.connect(hud._show_toast)
	city.city_changed.connect(trade.check_routes) # PORT-TRACE P22: 건설 즉시 교역로 재판정

	world_markers = WorldMarkerManager.new()
	world_markers.name = "WorldMarkerManager"
	add_child(world_markers)
	grid.water_gate_signboard_bestowed.connect(_on_water_gate_signboard_bestowed)

	_setup_world_baker(ref_layer)

	# PORT-TRACE [장마당·세시풍속]: 계절이 바뀌는 순간에만 놀이판을 정하고(FestivalSystem), 그림은
	# CitizenLayer가 놀이판 단위로 한 번에 그린다. 틱마다는 예약 사건 카운트다운만.
	festivals = FestivalSystem.new()
	festivals.name = "FestivalSystem"
	add_child(festivals)
	festivals.setup(grid, simulation_core, citizens)
	if citizen_layer != null:
		citizen_layer.festivals = festivals # PORT-TRACE [놀이판 연결 누락]: 시민 레이어가 먼저 만들어지면 아래(810줄) 연결이 null이라 놀이판이 그려지지 않았다
	festivals.notice.connect(func(m: String, icon: String): hud._show_toast(m, icon))
	grid.logistics.notice.connect(func(m: String, icon: String): hud._show_toast(m, icon)) # 사대문 길 개통 알림
	time_manager.season_changed.connect(festivals.on_season_changed)
	# PORT-TRACE [포루 포격 훈련]: 해마다 봄(새해) 다섯 포루 일제 화포 사격 훈련 + 포성
	time_manager.season_changed.connect(func(s: String):
		if s == "봄" and citizens.start_cannon_drill():
			hud._show_toast("새해 화포 사격 훈련! 포루마다 포탄을 장전하고 심지에 불을 붙입니다.", "💥")
	)
	citizens.cannon_fired.connect(func(): audio.play_limited("cannon"))
	citizens.sfx.connect(func(kind: String): audio.play_limited(kind)) # 조총·포효·비명(동시 3개·0.1초 제한)
	# PORT-TRACE [공성전]: 성 방호력·반란군/도적떼 공성·게임 오버
	siege = SiegeSystem.new()
	siege.name = "SiegeSystem"
	add_child(siege)
	siege.setup(grid, simulation_core, citizens, court)
	citizens.siege = siege
	siege.notice.connect(func(m: String, icon: String): hud._show_toast(m, icon))
	siege.alert.connect(func(_k: String, text: String):
		if tutorial:
			tutorial.show_alert(text)
		else:
			hud._show_toast(text, "⚠")
	)
	siege.game_over.connect(_on_game_over)
	siege.battle_focus_requested.connect(func(w_pos: Vector2, loc_name: String):
		camera.focus_on_coordinate(w_pos, true)
		hud.show_raid_alert_banner(w_pos, loc_name)
	)
	# PORT-TRACE [교육 기관 3종]: 서당·매곡서원 자동 생성, 수원향교 유지비·효과, 유생 왕래
	var edu := EducationSystem.new()
	edu.name = "EducationSystem"
	add_child(edu)
	edu.setup(grid, simulation_core, court, citizens)
	edu.notice.connect(func(m: String, icon: String): hud._show_toast(m, icon))
	# PORT-TRACE [서학 디버프·보유론·서기수용론]: 천주교당 발생·왕권 감소(독립 리스너), 장용영 사열
	var west := WesternLearning.new()
	west.name = "WesternLearning"
	add_child(west)
	west.setup(grid, simulation_core, court)
	west.notice.connect(func(m: String, icon: String): hud._show_toast(m, icon))
	if panels:
		panels.west = west
	# PORT-TRACE [서장대 야조]: 1789년(현륭원 원행) 이후 해마다 가을 원행 때 정조 대왕 행차 — 서장대 야간 군사 조련
	time_manager.season_changed.connect(func(s: String):
		if s == "가을" and time_manager.current_year >= 1789 and citizens.start_yajo():
			hud._show_toast("정조 대왕 화성 행차! 서장대에서 야조(夜操)가 열려 횃불과 청사초롱이 밝혀지고 오방기 신호로 진법을 펼칩니다.", "🏯")
			audio.play("yajo")
	)
	# PORT-TRACE [종루(여민각) 2x2]: 매달 초하루(계절이 바뀌는 날 포함) 종루 타종 — 범종 소리 + 주변 활력
	time_manager.time_changed.connect(func(_y: int, _s: String, _m: int, d: int):
		if d == 1 and citizens.ring_bell():
			audio.play("bell")
	)
	# 행궁 앞 박석 십자로가 열리는 순간 종루 자동 착공(지도가 바뀐 뒤 한 번, 다음 프레임에)
	grid.grid_changed.connect(func():
		if not _jongnu_check_pending:
			_jongnu_check_pending = true
			call_deferred("_check_jongnu")
	)
	time_manager.simulation_tick.connect(festivals.on_tick)
	# citizen_layer.festivals는 citizen_layer 생성 직후(아래)에서 할당됨

	quests = QuestSystem.new()
	quests.name = "QuestSystem"
	add_child(quests)
	quests.setup(grid, simulation_core, court)
	quests.quest_completed.connect(func(_q): audio.play("coin"))
	quests.ending_triggered.connect(func(_e): audio.play("season"))

	panels = PanelController.new()
	panels.name = "Panels"
	add_child(panels)
	panels.setup(simulation_core, grid, court, trade, turns, hud, quests, outside)
	panels.time_manager = time_manager
	panels.audio = audio
	panels.citizens = citizens
	panels.west = get_node_or_null("WesternLearning") as WesternLearning # 조정 창이 서학 모듈보다 늦게 만들어질 때
	hud.panel_controller = panels # 상단 성곽 방호력 표시 → 성곽 보수 창
	panels.tool_selected.connect(func(t): city.current_tool = t)
	city.tool_selected.connect(panels.select_tool)
	panels.undo_requested.connect(city.undo)
	city.gate_naming_requested.connect(panels.open_gate_naming_modal)
	panels.gate_info_provider = city.get_gate_info_for_pos # 대기 중인 문 차례에 추천 이름 재계산
	city.named_npc_inspected.connect(panels.show_named_npc_modal)
	panels.intro_video_requested.connect(play_intro_video)
	panels.title_screen_requested.connect(open_title_screen)
	panels.camera = camera
	panels.city = city

	# PORT-TRACE [튜토리얼·길잡이]: 게임 시작 인사 + 어명 교지 순서 안내(길잡이 김판관)
	tutorial = TutorialGuide.new()
	tutorial.name = "TutorialGuide"
	add_child(tutorial)
	tutorial.setup(quests, panels, hud, time_manager, simulation_core, court, grid, false)

	city.panels = panels
	city.tutorial = tutorial

	# PORT-TRACE [살피기 동적 내러티브]: 20자 규격 스토리텔링 및 고증 초상화 전용 팝업
	inspect_popup = InspectPopup.new()
	inspect_popup.name = "InspectPopup"
	add_child(inspect_popup)
	city.inspect_popup = inspect_popup

	# 화성유수부 원옥(寃獄) 친국·명판결 시스템 매니저 및 전용 모달 팝업
	trial_manager = TrialManager.new()
	trial_manager.name = "TrialManager"
	add_child(trial_manager)
	trial_manager.setup(simulation_core, audio)

	trial_popup = TrialPopup.new()
	trial_popup.name = "TrialPopup"
	add_child(trial_popup)
	trial_popup.trial_manager = trial_manager
	trial_manager.trial_popup = trial_popup

	simulation_core.trial_manager = trial_manager
	panels.trial_manager = trial_manager
	inspect_popup.trial_manager = trial_manager
	inspect_popup.panels = panels

	# 화성행궁 세부 전각(외규장각·낙남헌·정리소) 정무 선택 모달 인스턴스화
	haenggung_popup = HaenggungSubBuildingPopup.new()
	haenggung_popup.name = "HaenggungSubBuildingPopup"
	haenggung_popup.panels = panels
	haenggung_popup.court = court
	haenggung_popup.sim = simulation_core
	haenggung_popup.inspect_popup = inspect_popup
	add_child(haenggung_popup)
	city.haenggung_sub_building_popup = haenggung_popup
	haenggung_popup.inspect_requested.connect(func():
		var h_pos := BuildingManager.get_building_pos("haenggung", grid)
		if h_pos.x >= 0 and h_pos.y >= 0:
			city._show_inspect(h_pos, true)
	)

	# 서장대 야조 미니게임 모달 (최상위 CanvasLayer)
	var yajo_canvas := CanvasLayer.new()
	yajo_canvas.name = "YajoMiniGameCanvas"
	yajo_canvas.layer = 95
	add_child(yajo_canvas)

	yajo_minigame = YajoMiniGamePopup.new()
	yajo_minigame.name = "YajoMiniGamePopup"
	yajo_canvas.add_child(yajo_minigame)

	# 서장대 전용 정무 및 연례 야조 훈련 모달
	seojangdae_popup = SeojangdaePopup.new()
	seojangdae_popup.name = "SeojangdaePopup"
	seojangdae_popup.setup(grid, simulation_core, citizens, hud, audio, time_manager, yajo_minigame)
	add_child(seojangdae_popup)

	inspect_popup.seojangdae_popup = seojangdae_popup
	panels.seojangdae_popup = seojangdae_popup
	panels.yajo_minigame = yajo_minigame

	# 연무대 활쏘기 미니게임 모달 (최상위 CanvasLayer)
	var yeonmudae_canvas := CanvasLayer.new()
	yeonmudae_canvas.name = "YeonmudaeMiniGameCanvas"
	yeonmudae_canvas.layer = 95
	add_child(yeonmudae_canvas)

	yeonmudae_minigame = YeonmudaeMiniGamePopup.new()
	yeonmudae_minigame.name = "YeonmudaeMiniGamePopup"
	yeonmudae_canvas.add_child(yeonmudae_minigame)

	# 연무대 전용 무예 사열 및 훈련 모달
	yeonmudae_popup = YeonmudaePopup.new()
	yeonmudae_popup.name = "YeonmudaePopup"
	yeonmudae_popup.setup(grid, simulation_core, citizens, hud, audio, time_manager, yeonmudae_minigame)
	add_child(yeonmudae_popup)

	inspect_popup.yeonmudae_popup = yeonmudae_popup
	panels.yeonmudae_popup = yeonmudae_popup
	panels.yeonmudae_minigame = yeonmudae_minigame

	# 성곽 직접 보수 우봉고 퍼즐 미니게임 모달 (최상위 CanvasLayer)
	var ubongo_canvas := CanvasLayer.new()
	ubongo_canvas.name = "UbongoWallRepairCanvas"
	ubongo_canvas.layer = 95
	add_child(ubongo_canvas)

	ubongo_wall_repair = UbongoWallRepairPopup.new()
	ubongo_wall_repair.name = "UbongoWallRepairPopup"
	ubongo_canvas.add_child(ubongo_wall_repair)

	## 퍼즐 완료 시그널 처리: 성공 수에 따라 방호력 회복 적용
	ubongo_wall_repair.minigame_completed.connect(func(success_count: int, base_restore: int):
		if siege == null:
			return
		var multipliers: Array[float] = [0.90, 1.10, 2.00, 3.00]
		var mult: float = multipliers[clampi(success_count, 0, 3)]
		var final_restore: int = int(float(base_restore) * mult)
		var actual: int = CityStats.apply_emergency_repair(final_restore, simulation_core)
		simulation_core.defense_fatigue = maxi(0, simulation_core.defense_fatigue - final_restore)
		siege._def_cache = -1
		var result_desc := ""
		if success_count == 3:
			result_desc = "완벽한 석축! 방호력 %d 회복 (+200%% 가산)" % actual
		elif success_count == 2:
			result_desc = "훌륭한 솜씨! 방호력 %d 회복 (+100%% 가산)" % actual
		elif success_count == 1:
			result_desc = "한 판 성공. 방호력 %d 회복 (+10%% 가산)" % actual
		else:
			result_desc = "아쉽지만 패배. 방호력 %d 회복 (-10%% 감산 적용)" % actual
		if hud:
			hud._show_toast("🧱 석축 보수 완료! %s" % result_desc, "🧱")
		simulation_core.emit_signal("state_updated", simulation_core.gold, simulation_core.rice, simulation_core.population, simulation_core.loyalty, simulation_core.flood_defense)
	)

	panels.ubongo_wall_repair = ubongo_wall_repair

	# 거점 건물 다이렉트 인터랙션 매니저
	building_interaction = BuildingInteractionManager.new()
	building_interaction.name = "BuildingInteractionManager"
	building_interaction.setup(grid, simulation_core, panels, inspect_popup, haenggung_popup, seojangdae_popup, yeonmudae_popup)
	add_child(building_interaction)
	city.building_interaction_manager = building_interaction

	# 수원향교·서원·서당 학문 강독 퀴즈 모달 인스턴스화
	var quiz_popup := AcademyQuizPopup.new()
	quiz_popup.name = "AcademyQuizPopup"
	add_child(quiz_popup)


	trial_manager.notice.connect(func(m: String, icon: String):
		if hud:
			hud._show_toast(m, icon)
	)

	# 비변사 시보 (備邊司 時報) 한글 신문 팝업 인스턴스화
	bibyeonsa_sibo = BibyeonsaSiboPopup.new()
	bibyeonsa_sibo.name = "BibyeonsaSiboPopup"
	add_child(bibyeonsa_sibo)
	bibyeonsa_sibo.setup(simulation_core, grid)
	panels.bibyeonsa_sibo = bibyeonsa_sibo

	simulation_core.gazette_published.connect(func(issue_in: int, _y: int, _s: String):
		var issue_num: int = issue_in if issue_in > 0 else bibyeonsa_sibo.edition_history.size() + 1
		bibyeonsa_sibo.publish_edition(issue_num)
		if GameSettings.is_auto_show_gazette():
			if event_manager != null:
				event_manager.enqueue_gazette(issue_num, bibyeonsa_sibo)
			else:
				bibyeonsa_sibo.show_latest()
		else:
			if hud:
				hud._show_toast("새 신문 도착: 비변사 시보 제%d호가 발행되었습니다! (정책 창에서 열람)" % issue_num, "📰")
			if audio:
				audio.play("coin")
	)

	# 1795년 을묘원행 국책 대서사 및 능행차 시뮬레이션 매니저
	royal_procession = RoyalProcessionManager.new()
	royal_procession.name = "RoyalProcessionManager"
	add_child(royal_procession)
	royal_procession.setup(simulation_core, grid, citizens, time_manager, hud, panels, city, camera)
	panels.royal_procession = royal_procession
	panels.city = city

	# 서장대 야조 및 연무대 사열 군사훈련 매니저
	military_drill = MilitaryDrillManager.new()
	military_drill.name = "MilitaryDrillManager"
	add_child(military_drill)
	military_drill.setup(simulation_core, grid, camera, hud, city)
	simulation_core.military_drill_manager = military_drill

	# 1800년 정조 승하 및 화성 완성도 기반 멀티 엔딩 시스템 매니저
	ending_manager = EndingManager.new()
	ending_manager.name = "EndingManager"
	add_child(ending_manager)
	ending_manager.setup(simulation_core, grid, time_manager, court, hud)

	# 1820 근대화 시대 (11·12번 엔딩 이후 포스트 엔드게임)
	var modernization := ModernizationManager.new()
	add_child(modernization)
	modernization.setup(simulation_core, grid, time_manager, court)
	modernization.notice.connect(func(m: String, icon: String): hud._show_toast(m, icon))
	var urban := UrbanEvolutionManager.new()
	add_child(urban)
	urban.setup(simulation_core, grid, time_manager)
	var politics := ModernPoliticsManager.new()
	add_child(politics)
	politics.setup(simulation_core, time_manager, court)
	add_child(ModernHUD.new())

	# 화성행궁 종심 방어 및 전술 길목 차단 전투 체계 매니저
	siege_defense = SiegeDefenseManager.new()
	siege_defense.name = "SiegeDefenseManager"
	add_child(siege_defense)
	siege_defense.setup(simulation_core, grid, citizens, time_manager)
	_setup_music()

	# 기건설된 사대문/남수문/화홍문/매향교 현판 마커 단일화 동기화
	sync_all_world_markers()

## 배경음악: 계절·특수상황·엔딩에 따라 곡이 바뀐다(곡 목록은 assets/music/MUSIC_GUIDE.md)
func _setup_music() -> void:
	if music != null:
		return
	music = MusicManager.new()
	music.name = "MusicManager"
	add_child(music)
	music.sim = simulation_core
	music.siege = siege
	music.time_manager = time_manager
	music.court = court
	music.game_started = func() -> bool: return _is_game_started
	music.set_flag("intro", intro_layer != null)

	var season_mgr: SeasonManager = SeasonManager.instance
	if season_mgr == null:
		season_mgr = SeasonManager.new()
		season_mgr.name = "SeasonManager"
		add_child(season_mgr)

	var audio_mgr: AudioManager = AudioManager.instance
	if audio_mgr == null:
		audio_mgr = AudioManager.new()
		audio_mgr.name = "AudioManager"
		add_child(audio_mgr)
	audio_mgr.music_mgr = music

	# 사계절 BGM 자동 전환 연결 (명세 규격)
	if not season_mgr.season_changed.is_connected(audio_mgr.on_season_changed):
		season_mgr.season_changed.connect(audio_mgr.on_season_changed)
	if time_manager != null and not time_manager.season_changed.is_connected(season_mgr.set_season):
		time_manager.season_changed.connect(season_mgr.set_season)
	if time_manager != null and not time_manager.season_changed.is_connected(music.on_season_changed):
		time_manager.season_changed.connect(music.on_season_changed)

	citizens.bandit_battle_started.connect(func(_w: Vector2, _n: String):
		AudioManager.is_active_invasion = true
		music.set_flag("bandit_battle", true)
	)
	citizens.bandit_battle_ended.connect(func(_r: bool):
		AudioManager.is_active_invasion = false
		music.set_flag("bandit_battle", false)
		music.switch_to_season_bgm()
	)

	if siege_defense != null:
		siege_defense.battle_started.connect(func(_k: String, _ea: int, _ad: int, _loc: Vector2i):
			AudioManager.is_active_invasion = true
			music.set_flag("bandit_battle", true)
		)
		siege_defense.battle_resolved.connect(func(_v: bool, _m: String):
			AudioManager.is_active_invasion = false
			music.set_flag("bandit_battle", false)
			music.switch_to_season_bgm()
		)

	ending_manager.ending_triggered.connect(func(_d: Dictionary): music.begin_ending())
	ending_manager.ending_popup_shown.connect(music.play_ending)
	if panels:
		panels.music = music

func _setup_world_baker(ref_layer: TileMapLayer) -> void:
	# 1. 정적 지형/건물을 실제로 그리는 두 번째 CityLayer 인스턴스(시민 없음, 항상 지도 전체를 그림)
	# PORT-TRACE [렉 해결: 띠 굽기]: baker는 이제 그리지 않는 "마스터"(정점 색·깊이 정렬 계산 전용)이고,
	# 실제 그림은 깊이 띠마다 하나씩 만든 bake_bands가 나눠 그린다(_do_rebake_world에서 바뀐 띠만 다시 그림).
	baker = CityLayer.new()
	baker.name = "WorldBaker"
	baker.auto_redraw = false
	baker.setup(grid, simulation_core, null, ref_layer)

	world_viewport = SubViewport.new()
	world_viewport.name = "WorldViewport"
	world_viewport.transparent_bg = true
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(world_viewport)
	world_viewport.add_child(baker) # 뷰포트 안이라 마우스 입력을 받지 않는다(중복 건설 방지), 숨김이라 그리지도 않는다
	baker.visible = false
	world_viewport.size = Vector2i(2, 2)
	world_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED # 마스터(baker)만 담는다 — 그리지 않음
	var nb: int = baker.band_count()
	var per := maxi(1, int(float(CHUNK_DEPTH) / CityLayer.BAND_DEPTH))
	var b0 := 0
	while b0 < nb:
		var b1 := mini(nb - 1, b0 + per - 1)
		var vp := SubViewport.new()
		vp.name = "WorldChunk%d" % _chunks.size()
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		vp.size = Vector2i(2, 2)
		add_child(vp)
		# 2. 구워진 조각 텍스처를 실제 화면(카메라 영향권)에 표시하는 스프라이트(앞 조각일수록 나중에 — 위에 그려짐)
		var spr := Sprite2D.new()
		spr.name = "WorldSprite%d" % _chunks.size()
		spr.centered = false
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # 픽셀아트 흐림 방지
		spr.z_index = 10 + _chunks.size() * 2
		add_child(spr)
		spr.texture = vp.get_texture()
		_chunks.append({"vp": vp, "sprite": spr, "b0": b0, "b1": b1, "rect": Rect2()})
		for bi in range(b0, b1 + 1):
			# 같은 띠 안에서는 예전 그리기 순서(y 오름차순 = x 내림차순)를 지키도록 x가 큰 토막부터 노드를 만든다
			for s in range(CityLayer.BAND_SEGS - 1, -1, -1):
				var band := CityLayer.new()
				band.name = "BakeBand%d_%d" % [bi, s]
				band.auto_redraw = false
				band.band_master = baker
				band.band_index = bi
				band.band_seg = s
				band.setup(grid, simulation_core, null, ref_layer)
				vp.add_child(band)
				var nid := bi * CityLayer.BAND_SEGS + s
				while bake_bands.size() <= nid:
					bake_bands.append(null)
				bake_bands[nid] = band
		b0 = b1 + 1
	world_sprite = _chunks[0]["sprite"] # 예전 코드와의 호환(존재 확인용)

	# PORT-TRACE [물빛 찰랑임]: 만석거·축만제·용연의 움직이는 윤슬과 흔들리는 나룻배(못이 구워진 조각 바로 위에)
	var water_fx := WaterFXLayer.new()
	water_fx.name = "WaterFXLayer"
	add_child(water_fx)
	var per_w := per
	water_fx.setup(grid, baker, func(tp: Vector2i) -> int: return 10 + int(float(baker.band_of(tp.x, tp.y)) / float(per_w)) * 2)

	# 3. 움직이는 시민/커서/드래그 미리보기 — 이 레이어만 매 프레임 다시 그린다
	citizen_layer = CitizenLayer.new()
	citizen_layer.name = "CitizenLayer"
	add_child(citizen_layer)
	citizen_layer.setup(grid, citizens, city)
	citizen_layer.setup_chunks(_chunks.size(), CHUNK_DEPTH, CityLayer.BAND_DEPTH)
	city.citizen_layer = citizen_layer
	citizen_layer.festivals = festivals  # festivals 연동 (초기화 후 안전 시점)
	if festivals != null and time_manager != null:
		festivals.on_season_changed(time_manager.get_current_season())
	if hud != null:
		hud.citizen_layer = citizen_layer

	city.visible = false # 로직/입력은 그대로 담당하되 화면에는 그리지 않음(baker+sprite가 대신 보여줌)

	grid.grid_changed.connect(_rebake_world)
	city.city_changed.connect(_rebake_world)
	# PORT-TRACE [단계별 건설]: 날(틱)마다 공정률을 올리고, 공정 단계가 바뀐 때만 지도를 다시 굽는다.
	time_manager.simulation_tick.connect(grid.on_build_tick)
	grid.construction_progressed.connect(_rebake_world)
	turns.turn_report.connect(_on_turn_completed_rebake)
	_rebake_world()

## PORT-TRACE [텍스처 베이크]: 지도 전체(및 붓으로 칠할 수 있는 고도 범위)를 담는 사각형을
## 계산해 SubViewport 크기/위치를 맞춘다. 시점이 고정이므로 최초 1회만 계산된다.
func _compute_world_bounds() -> Rect2:
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	var gs := float(grid.size)
	for corner in [Vector2(0, 0), Vector2(gs, 0), Vector2(0, gs), Vector2(gs, gs)]:
		for e in [WORLD_BAKE_MIN_ELEV, WORLD_BAKE_MAX_ELEV]:
			var p: Vector2 = city.cell_center(corner.x, corner.y, e)
			min_p.x = minf(min_p.x, p.x)
			min_p.y = minf(min_p.y, p.y)
			max_p.x = maxf(max_p.x, p.x)
			max_p.y = maxf(max_p.y, p.y)
	var pad := Vector2(WORLD_BAKE_PAD, WORLD_BAKE_PAD)
	return Rect2(min_p - pad, (max_p - min_p) + pad * 2.0)

## 건설/철거/지형 편집 등 지도가 실제로 바뀔 때 호출 (프레임 내 중복 호출 단일 병합 디바운스)
var siege: SiegeSystem
var _game_over_layer: GameOverLayer

## 화성 함락 — 시간을 멈추고 시네마틱 엔딩 및 패배 결산 시퀀스 가동
func _on_game_over(reason: String) -> void:
	time_manager.set_speed(TimeManager.SpeedMode.PAUSE)
	if audio:
		audio.play("error")
	if EndingManager.instance != null:
		var end_key: String = "BANDIT_FALL"
		if reason.contains("반란") or reason.contains("사대부"):
			end_key = "COUP_DETAT"
		EndingManager.instance.trigger_fall_of_city_ending(end_key)
	else:
		if _game_over_layer == null:
			_game_over_layer = GameOverLayer.new()
			_game_over_layer.name = "GameOverLayer"
			add_child(_game_over_layer)
			_game_over_layer.load_latest.connect(_load_latest_save)
		_game_over_layer.show_game_over(reason, _latest_slot() >= 0)

## 가장 최근에 저장된 슬롯(자동 저장 0 포함), 없으면 -1
func _latest_slot() -> int:
	var best := -1
	var best_ts := ""
	for sl: int in [0, 1, 2, 3]:
		if SaveSystem.has_save(sl):
			var ts: String = str(SaveSystem.get_save_info(sl).get("timestamp", ""))
			if best < 0 or ts > best_ts:
				best = sl
				best_ts = ts
	return best

func _load_latest_save() -> void:
	var sl := _latest_slot()
	if sl < 0:
		return
	if siege != null:
		siege.reset()
	if SaveSystem.load_game(sl, simulation_core, grid, time_manager, quests):
		hud._show_toast("마지막 기록(실록)으로 되돌아갔습니다.", "📜")
		on_game_loaded()
	time_manager.set_speed(TimeManager.SpeedMode.NORMAL)

var _jongnu_check_pending := false
func _check_jongnu() -> void:
	_jongnu_check_pending = false
	if grid.try_start_jongnu(simulation_core):
		hud._show_toast("행궁 신풍루 앞 박석 십자로가 열렸습니다! 조정에서 종루(여민각) 2x2를 착공합니다.", "🔔")
	# PORT-TRACE [남수문]: 수원천 남쪽을 성곽이 가로질러 동·서 성벽이 이어지는 순간 남수문 자동 축조
	# PORT-TRACE [매향교]: 행궁 앞 동서 큰길이 수원천을 건너는 순간 석교 매향교로
	if not grid.detect_maehyang().is_empty():
		hud._show_toast("행궁 앞 동서 큰길이 수원천을 건넜습니다! 화강암 석교 매향교(梅香橋)가 놓이고 천변에 매화를 심습니다.", "🌸")
		citizens.maehyang_open = true
	if not grid.detect_namsu().is_empty():
		hud._show_toast("수원천 남쪽에서 동·서 성곽이 이어졌습니다! 아홉 칸 홍예 남수문(南水門)을 축조합니다.", "🌊")

## [계절 전환 지형 동기화] PORT-TRACE [렉: 계절 전환 0.5초 멈춤]: 지도 전체 띠를 한 프레임에 다시 그리던 것을
## 프레임마다 나눠 그리고(그동안 화면 조각은 이전 계절 그림 그대로), 다 그리면 화면에 보이는 조각을 한 프레임에
## 함께 바꾼다(계절이 섞인 조각보가 보이지 않음). 화면 밖 조각은 그 뒤 몇 프레임에 나눠 다시 렌더링한다.
func _apply_seasonal_terrain_globally(s: String) -> void:
	if baker:
		baker.current_season = s
		baker._vertex_colors_dirty = true
		baker._depth_order_dirty = true
		baker.prepare_bands()
	_baked_season = s
	_swap_vp_queue.clear()
	# 띠의 계절은 _flush_bands가 그릴 차례에 바꾼다(여기서 바꾸면 계절 setter가 모든 띠를 이번 프레임에 다시 그려 멈칫)
	for bi in range(bake_bands.size()):
		if bake_bands[bi] != null:
			_pending_bands[bi] = true
	_season_swap = not _pending_bands.is_empty() and not _chunks.is_empty()
	_flush_bands()

## 계절 전환 마무리: 화면에 보이는 조각은 지금 한꺼번에, 나머지는 _swap_vp_queue로 나눠 다시 렌더링
func _swap_chunks() -> void:
	_swap_vp_queue.clear()
	for ch in _chunks:
		var vp: SubViewport = ch.get("vp") as SubViewport
		if vp == null:
			continue
		if _chunk_on_screen(ch):
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		else:
			_swap_vp_queue.append(ch)

func _chunk_on_screen(ch: Dictionary) -> bool:
	var spr: Sprite2D = ch.get("sprite") as Sprite2D
	if spr == null or not spr.is_inside_tree():
		return true
	return (spr.get_global_transform_with_canvas() * spr.get_rect()).intersects(get_viewport().get_visible_rect())

func _rebake_world() -> void:
	if _rebake_requested:
		return
	_rebake_requested = true
	call_deferred("_do_rebake_world")

func _do_rebake_world() -> void:
	if not (baker and world_viewport and world_sprite):
		_rebake_requested = false
		return
	# 턴 연산 진행 중(비동기 프레임 분할)이면 턴 완료 후 일괄 1회만 베이크하도록 대기 (데드락 방지)
	if turns and turns._is_processing_turn:
		_rebake_requested = false
		if not turns.turn_report.is_connected(_on_turn_completed_rebake):
			turns.turn_report.connect(_on_turn_completed_rebake, CONNECT_ONE_SHOT)
		return
	# PORT-TRACE [렉: 턴 정산 멈칫]: 바뀐 칸 찾기(지도 전체 해시)와 띠 다시 그리기도 시민 길 정보·가림막 다시 만들기와
	# 한 프레임에 겹치지 않게 차례를 받는다. 이번 프레임이 이미 쓰였으면 다음 프레임 _process에서 다시.
	# 계절 지형 전환이 기다리는 중이면 그것부터(여기서 먼저 그리면 계절이 띠마다 따로 바뀌어 얼룩진다)
	if _season_apply_pending != "" or not GameGrid.frame_claim():
		_rebake_retry = true
		return
	_rebake_retry = false
	_rebake_requested = false
	baker.current_season = city.current_season
	if citizen_layer:
		citizen_layer.current_season = city.current_season

	# 뷰포트 크기와 배치는 최초 1회만 계산하여 거대 VRAM 텍스처 재할당 방지
	var relaid := false
	if _world_bounds_dirty or _world_bounds_cached.size == Vector2.ZERO:
		_world_bounds_cached = _compute_world_bounds()
		_world_bounds_dirty = false
		_tall_sig_v = _tall_sig()
		_layout_chunks()
		relaid = true
	else:
		var tsig := _tall_sig()
		if tsig != _tall_sig_v:
			_tall_sig_v = tsig
			_layout_chunks()
			relaid = true

	# 특수 건물이 새로 서거나 헐리면 현판도 다시
	if _special_marker_sig() != _marker_sig:
		sync_all_world_markers()
	# 바뀐 타일만 찾아 그 띠만 다시 그린다. 계절 변경 시에는 전체 띠 일괄 갱신.
	var season_changed := _baked_season != city.current_season
	var full := (_tile_hashes.size() != grid.size * grid.size) or season_changed or relaid
	_baked_season = city.current_season
	var dirty := {}
	var changed: Array[Vector2i] = []
	var site_stage := {}
	for site in grid.active_sites:
		var st := GameGrid.build_stage(grid.site_fraction(site))
		for pt in site["tiles"]:
			site_stage[pt] = st
	if _tile_hashes.size() != grid.size * grid.size:
		_tile_hashes.resize(grid.size * grid.size)
	for y in range(grid.size):
		for x in range(grid.size):
			var h: int = grid.grid[y][x].hash()
			var pk := Vector2i(x, y)
			if site_stage.has(pk):
				h = h * 31 + int(site_stage[pk]) + 1
			var i := y * grid.size + x
			if h != _tile_hashes[i]:
				_tile_hashes[i] = h
				changed.append(Vector2i(x, y))
				if not full:
					# PORT-TRACE [성능: 다시 그릴 범위]: 띠·토막은 각자 따로 구운 그림이고 겹치는 순서는 노드 순서로 고정이라,
					# 앞쪽 띠까지 다시 그릴 필요가 없다. 바뀐 칸과 그 칸을 보고 모양이 바뀌는 이웃 8칸(길·성벽 이음, 앞면 방향)이
					# 실제로 그려지는 띠·토막만 다시 그린다(문은 band_of가 +2.5 띠로 옮겨 줌).
					for ny in range(maxi(0, y - 1), mini(grid.size, y + 2)):
						for nx in range(maxi(0, x - 1), mini(grid.size, x + 2)):
							dirty[baker.band_of(nx, ny) * CityLayer.BAND_SEGS + CityLayer.seg_of(nx, grid.size)] = true
	# PORT-TRACE [렉: 건설 멈칫]: 칸 몇 개만 바뀌었으면 그 둘레 꼭짓점 색만 다시 센다(전체 다시 그리기 때는 prepare_bands가 전부)
	if not full and baker._vertex_colors_dirty:
		if changed.is_empty():
			baker._vertex_colors_dirty = false # 바뀐 칸이 없으면 꼭짓점 색도 그대로
		elif changed.size() <= grid.size * grid.size / 8: # 많이 바뀌었으면(불러오기 등) 전체 계산이 더 빠르다
			baker.update_vertex_colors_around(changed)
	baker.prepare_bands()
	for bi in range(bake_bands.size()):
		if full or dirty.has(bi):
			_pending_bands[bi] = true
	_flush_bands()

## PORT-TRACE [렉 해결: 나눠 굽기]: 계절이 바뀌어 지도 전체(띠 수백 개)를 다시 그려야 할 때도 한 프레임에
## 몰지 않고 프레임마다 BAND_COST_PER_FRAME 분량씩 나눠 그린다. 한 번에 그리면 멈칫했다.
func _process(_delta: float) -> void:
	if _season_apply_pending != "" and GameGrid.frame_claim():
		var ns := _season_apply_pending
		_season_apply_pending = ""
		_apply_seasonal_terrain_globally(ns) # 띠 첫 묶음도 그 안에서 그린다
	elif _rebake_retry:
		_rebake_retry = false
		_do_rebake_world() # 바뀐 띠 첫 묶음도 그 안에서 그린다
	elif not _pending_bands.is_empty():
		_flush_bands()
	if not _swap_vp_queue.is_empty():
		# 계절 전환 뒤 화면 밖 조각: 화면에 들어온 조각은 바로, 나머지는 프레임마다 몇 개씩
		var n := 0
		for ch in _swap_vp_queue.duplicate():
			if n < SWAP_VP_PER_FRAME or _chunk_on_screen(ch):
				_swap_vp_queue.erase(ch)
				var vp: SubViewport = ch.get("vp") as SubViewport
				if vp != null:
					vp.render_target_update_mode = SubViewport.UPDATE_ONCE
				n += 1

func _flush_bands() -> void:
	if _pending_bands.is_empty() or _chunks.is_empty():
		return
	var keys: Array = _pending_bands.keys()
	keys.sort()
	var weight := 0
	var touched := {}
	for bi in keys:
		if weight >= BAND_COST_PER_FRAME:
			break
		_pending_bands.erase(bi)
		if bi >= 0 and bi < bake_bands.size() and bake_bands[bi] != null:
			var node: CityLayer = bake_bands[bi]
			node.current_season = _baked_season if _baked_season != "" else city.current_season
			node.queue_redraw()
			var band_i: int = node.band_index
			touched[int(float(band_i) / float(maxi(1, int(float(CHUNK_DEPTH) / CityLayer.BAND_DEPTH))))] = true
			if band_i < baker._band_tiles.size():
				for pt in baker._band_tiles[band_i]:
					if CityLayer.seg_of(pt.x, grid.size) == node.band_seg:
						weight += 3 if grid.grid[pt.y][pt.x]["building"] != "" else 1
			weight += 1
	if _season_swap:
		# 계절 전환 중에는 다 그릴 때까지 화면 조각을 이전 계절 그대로 두었다가 한꺼번에 바꾼다
		if _pending_bands.is_empty():
			_season_swap = false
			_swap_chunks()
			_update_chimneys()
		return
	# 바뀐 띠가 든 조각만 다시 렌더링
	for ci in touched.keys():
		if ci < _chunks.size():
			(_chunks[ci]["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
	if _pending_bands.is_empty():
		_update_chimneys()

## 불을 사용하는 공방(대장간·가마·도예·무기창) 및 주막 굴뚝 위치를 환경 VFX 매니저에 등록
func _update_chimneys() -> void:
	if env_vfx_manager == null or grid == null or city == null:
		return
	env_vfx_manager.clear_all_chimneys()
	var registered_count: int = 0
	# 불을 사용하는 대표 공방 5종: 대장간, 기와가마, 도예가마, 금속공예, 군기시(무기창)
	const FIRE_WORKSHOPS: Array[String] = [
		"ws_2x1_blacksmith", "ws_2x1_tile_kiln", "ws_2x2_ceramics", 
		"ws_1x1_metalcraft", "ws_3x3_royal_arsenal"
	]
	for y: int in range(grid.size):
		for x: int in range(grid.size):
			var b: String = grid.grid[y][x].get("building", "")
			var has_fire: bool = false
			# 1. 공방: 화덕/가마를 사용하는 공방만 등록
			if b in ["ind_1", "ind_2"]:
				var ws_id: String = grid.get_workshop_asset_id(x, y)
				if ws_id in FIRE_WORKSHOPS:
					has_fire = true
			# 2. 상점: 가마솥 국밥과 술을 끓이는 주막(15번)만 등록
			elif b in ["com_1", "com_2"]:
				var s_id: String = grid.get_shop_asset_id(x, y)
				if s_id == "market_shop_15":
					has_fire = true

			if has_fire:
				var elev: float = grid.grid[y][x].get("elevation", 1.0)
				var wp: Vector2 = city.cell_center(float(x) + 0.5, float(y) + 0.5, elev)
				env_vfx_manager.register_chimney(Vector2i(x, y), wp)
				registered_count += 1
				if registered_count >= EnvironmentVFXManager.MAX_PARTICLES_HARD_CAP:
					return

## 조각마다 경계 상자: 그 띠들의 칸 중심(최저·최고 고도) 범위 + 좌우 반 칸·위 지붕 여유·아래 반 칸
## 키 큰 한 장 그림(묶음 가장 앞 칸에서 그림)의 높이 — 아니면 0
const TALL_SPRITES := {"haenggung": 330.0, "haenggung_site": 330.0, "manseokgeo": 235.0, "manseokgeo_site": 235.0, "chukmanje": 235.0, "chukmanje_site": 235.0, "hyanggyo": 210.0, "hyanggyo_site": 210.0}
func _tall_sprite_h(x: int, y: int) -> float:
	var t: Dictionary = grid.grid[y][x]
	var b: String = t.get("building", "")
	if not TALL_SPRITES.has(b):
		return 0.0
	var a: Vector2i = t.get("site_anchor", Vector2i(x, y))
	if Vector2i(x, y) != city._group_front_tile(a):
		return 0.0
	return float(TALL_SPRITES[b])

## 키 큰 그림의 위치 목록(바뀌면 조각 경계를 다시 잡는다)
func _tall_sig() -> int:
	var h := 0
	for y in range(grid.size):
		for x in range(grid.size):
			if TALL_SPRITES.has(grid.grid[y][x].get("building", "")) and _tall_sprite_h(x, y) > 0.0:
				h = h * 31 + y * 1000 + x + 1
	return h
var _tall_sig_v := -1

func _layout_chunks() -> void:
	var per := maxi(1, int(float(CHUNK_DEPTH) / CityLayer.BAND_DEPTH))
	var sz: int = grid.size
	for ci in range(_chunks.size()):
		var ch: Dictionary = _chunks[ci]
		var mn := Vector2(INF, INF)
		var mx := Vector2(-INF, -INF)
		for y in range(sz):
			for x in range(sz):
				var bi: int = baker.band_of(x, y)
				if bi < int(ch["b0"]) or bi > int(ch["b1"]):
					continue
				for e: float in [WORLD_BAKE_MIN_ELEV, WORLD_BAKE_MAX_ELEV]:
					var pc: Vector2 = city.cell_center(float(x) + 0.5, float(y) + 0.5, e)
					mn = Vector2(minf(mn.x, pc.x), minf(mn.y, pc.y))
					mx = Vector2(maxf(mx.x, pc.x), maxf(mx.y, pc.y))
		if mn.x == INF:
			mn = _world_bounds_cached.position
			mx = mn + Vector2(2, 2)
		# PORT-TRACE [큰 그림 잘림]: 행궁·만석거처럼 키 큰 한 장 그림은 묶음 가장 앞 칸(이 조각)에서 그리므로, 그 그림 꼭대기까지 조각에 담는다
		var top_y: float = mn.y - 120.0
		for y in range(sz):
			for x in range(sz):
				var tall: float = _tall_sprite_h(x, y)
				if tall <= 0.0:
					continue
				var bi3: int = baker.band_of(x, y)
				if bi3 < int(ch["b0"]) or bi3 > int(ch["b1"]):
					continue
				var bot: Vector2 = city.cell_center(float(x) + 1.0, float(y) + 1.0, float(grid.grid[y][x].get("elevation", 1.0)))
				top_y = minf(top_y, bot.y - tall - 8.0)
		var r := Rect2(Vector2(mn.x - (CityLayer.HW + 40.0), top_y), Vector2((mx.x - mn.x) + (CityLayer.HW + 40.0) * 2.0, mx.y - top_y + CityLayer.HH * 2.0 + 30.0))
		ch["rect"] = r
		var vp: SubViewport = ch["vp"]
		vp.size = Vector2i(ceili(r.size.x), ceili(r.size.y))
		(ch["sprite"] as Sprite2D).position = r.position
		for bi2 in range(int(ch["b0"]), int(ch["b1"]) + 1):
			for s3 in range(CityLayer.BAND_SEGS):
				var nid2 := bi2 * CityLayer.BAND_SEGS + s3
				if nid2 < bake_bands.size() and bake_bands[nid2] != null:
					bake_bands[nid2].position = -r.position
	if per <= 0:
		return

func _on_turn_completed_rebake(_rep: Dictionary = {}) -> void:
	_rebake_requested = false
	_rebake_world()

## 마우스 우클릭 선택/건설 취소 핸들러
func cancel_current_selection() -> void:
	# 1. 인스펙터/살피기 팝업 및 행궁 전각 팝업, 학문 퀴즈 팝업 닫기
	if inspect_popup and inspect_popup.visible:
		inspect_popup.close_inspect()
	if haenggung_popup and haenggung_popup.visible:
		haenggung_popup.close_popup()
	if seojangdae_popup and seojangdae_popup.visible:
		seojangdae_popup.close_seojangdae_popup()
	if yeonmudae_popup and yeonmudae_popup.visible:
		yeonmudae_popup.close_yeonmudae_popup()
	if AcademyQuizPopup.instance and AcademyQuizPopup.instance.visible:
		AcademyQuizPopup.instance.close_quiz()


	# 2. 건설 도구 초기화 (조사/inspect 모드로 복귀) 및 마우스 드래그/프리뷰 취소
	if city:
		city.cancel_build_or_select()
	if panels and panels.has_method("select_tool"):
		panels.select_tool("inspect")

	# 3. 카메라 팬 중지
	if camera:
		camera.is_panning = false

## 입력 이벤트 핸들러: 우클릭 취소 복원 및 개발 테스트용 디버그 단축키 연동
func _unhandled_input(event: InputEvent) -> void:
	# 마우스 우클릭 취소(Deselect / Cancel)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_current_selection()
		get_viewport().set_input_as_handled()
		return

	if not event is InputEventKey or not (event as InputEventKey).is_pressed() or (event as InputEventKey).is_echo():
		return

	var key_ev: InputEventKey = event as InputEventKey
	match key_ev.keycode:
		KEY_F7:
			if military_drill:
				military_drill.start_seojangdae_drill(false)
				if hud:
					hud._show_toast("시험: 서장대 야조 군사훈련 연출 즉시 가동", "⚔️")
		KEY_F8:
			if time_manager:
				time_manager.advance_year(1)
				if hud:
					hud._show_toast("시험: 1년을 강제 경과시켰습니다. (현재: %d년)" % time_manager.current_year, "⏩")
				print("[디버그 F8] 1년 강제 스킵 실행. 현재 연도: %d년 %d월" % [time_manager.current_year, time_manager.current_month])
		KEY_F9:
			if royal_procession:
				var ok: bool = royal_procession.check_eulmyo_conditions()
				if ok:
					royal_procession.start_eulmyo_event(simulation_core, grid, citizens, time_manager, hud, panels, city, camera)
				elif hud:
					hud._show_toast("시험: 을묘원행 발동 조건 미달 (기록창 확인)", "⚠️")
		KEY_F10:
			if time_manager and ending_manager:
				time_manager.skip_to_year(1800)
				ending_manager.check_ending_trigger()
				if hud:
					hud._show_toast("시험: 1800년으로 시간 도약 및 정조 승하 결말 판정 가동", "👑")
		KEY_F11:
			GameSettings.toggle_fullscreen()
			get_viewport().set_input_as_handled()

## 수원천 수문(남수문, 화홍문) 및 교량(매향교) 현판 하사 이벤트 처리
func _on_water_gate_signboard_bestowed(facility_id: String, fac_name: String, center_pos: Vector2i) -> void:
	if world_markers != null and city != null:
		var norm_id: String = WorldMarkerManager.normalize_building_id(facility_id, fac_name)
		var offset_y: float = WorldMarkerManager.get_roof_offset_y(norm_id, fac_name)
		var wpos: Vector2 = city.cell_center(float(center_pos.x) + 0.5, float(center_pos.y) + 0.5)
		wpos.y -= offset_y
		world_markers.register_signboard(norm_id, wpos, fac_name)
	if panels != null and panels.has_method("open_water_gate_signboard_modal"):
		panels.open_water_gate_signboard_modal(facility_id, fac_name)
	if hud != null:
		hud._show_toast("[어제 현판 하사] 정조 대왕께서 %s의 현판을 친히 내리셨습니다!" % fac_name, "⛩️")
	if audio != null:
		audio.play("coin")

## 세이브 로드 시 또는 초기화 시 기건설된 사대문/남수문/화홍문/매향교 현판 마커 복구 (Auto-Heal 및 중복 정리)
func sync_all_world_markers() -> void:
	if world_markers == null or grid == null or city == null:
		return

	# 기존 중복/잔여 마커 전수 정리
	world_markers.clear_all_markers()

	var hwahong_tiles: Array[Vector2i] = []
	var namsu_tiles: Array[Vector2i] = []
	var maehyang_tiles: Array[Vector2i] = []
	var gate_tiles: Dictionary = {} # norm_id -> {"tile": Vector2i, "name": String}

	for y: int in range(grid.size):
		for x: int in range(grid.size):
			var t: Dictionary = grid.grid[y][x]
			var fac_id: String = str(t.get("facility_id", ""))
			if bool(t.get("is_hwahong", false)) or fac_id == "hwahong_mun":
				hwahong_tiles.append(Vector2i(x, y))
			elif bool(t.get("is_namsu", false)) or fac_id == "namsu_mun":
				namsu_tiles.append(Vector2i(x, y))
			elif bool(t.get("is_maehyang", false)) or fac_id == "maehwang_gyo":
				maehyang_tiles.append(Vector2i(x, y))
			elif t.get("building", "") == "gate":
				var g_name: String = str(t.get("gate_name", ""))
				if g_name != "":
					var norm_id: String = WorldMarkerManager.normalize_building_id("gate_%d_%d" % [x, y], g_name)
					gate_tiles[norm_id] = {"tile": Vector2i(x, y), "name": g_name}

	# 1. 화홍문 단일 현판 등록 (다중 타일 중앙 상단)
	if not hwahong_tiles.is_empty():
		var center_v: Vector2 = Vector2.ZERO
		for pt: Vector2i in hwahong_tiles:
			center_v += city.cell_center(float(pt.x) + 0.5, float(pt.y) + 0.5)
		center_v /= float(hwahong_tiles.size())
		center_v.y -= WorldMarkerManager.get_roof_offset_y("hwahong_mun", WaterStructureManager.NAME_HWAHONG)
		world_markers.register_signboard("hwahong_mun", center_v, WaterStructureManager.NAME_HWAHONG)

	# 2. 남수문 단일 현판 등록 (다중 타일 중앙 상단)
	if not namsu_tiles.is_empty():
		var center_v: Vector2 = Vector2.ZERO
		for pt: Vector2i in namsu_tiles:
			center_v += city.cell_center(float(pt.x) + 0.5, float(pt.y) + 0.5)
		center_v /= float(namsu_tiles.size())
		center_v.y -= WorldMarkerManager.get_roof_offset_y("namsu_mun", WaterStructureManager.NAME_NAMSU)
		world_markers.register_signboard("namsu_mun", center_v, WaterStructureManager.NAME_NAMSU)

	# 3. 매향교 단일 현판 등록 (다중 타일 중앙 상단)
	if not maehyang_tiles.is_empty():
		var center_v: Vector2 = Vector2.ZERO
		for pt: Vector2i in maehyang_tiles:
			center_v += city.cell_center(float(pt.x) + 0.5, float(pt.y) + 0.5)
		center_v /= float(maehyang_tiles.size())
		center_v.y -= WorldMarkerManager.get_roof_offset_y("maehwang_gyo", WaterStructureManager.NAME_MAEHWANG)
		world_markers.register_signboard("maehwang_gyo", center_v, WaterStructureManager.NAME_MAEHWANG)

	# 4. 사대문 및 성문 단일 현판 등록 (건물 지붕 처마 상단)
	for gid: String in gate_tiles.keys():
		var info: Dictionary = gate_tiles[gid]
		var pt: Vector2i = info["tile"]
		var g_name: String = info["name"]
		var c_pos: Vector2 = city.cell_center(float(pt.x) + 0.5, float(pt.y) + 0.5)
		c_pos.y -= WorldMarkerManager.get_roof_offset_y(gid, g_name)
		world_markers.register_signboard(gid, c_pos, g_name)

	# 5. PORT-TRACE [특수 건물 현판]: 퀴즈(서원·서당·향교)·훈련(서장대·연무대)·정무(행궁·관아)를 보는 곳을 지도에서 찾기 쉽게
	for sb: Dictionary in _special_marker_list():
		world_markers.register_signboard(String(sb["id"]), sb["pos"], String(sb["name"]))
	_marker_sig = _special_marker_sig()

## 특수 건물 현판 목록: [{id, name, pos(현판 자리)}]
const SPECIAL_MARKERS := {
	"haenggung": ["화성행궁", 175.0], "gwana": ["유수부 관아", 80.0], "hyanggyo": ["수원향교", 120.0],
	"seojangdae": ["서장대", 95.0], "yeonmudae": ["연무대", 70.0],
}
func _special_marker_list() -> Array:
	var out: Array = []
	for y: int in range(grid.size):
		for x: int in range(grid.size):
			var t: Dictionary = grid.grid[y][x]
			var b: String = str(t.get("building", ""))
			if not SPECIAL_MARKERS.has(b) or t.get("under_construction", false):
				continue
			var tiles: Array = t.get("site_tiles", [Vector2i(x, y)])
			if tiles.is_empty():
				tiles = [Vector2i(x, y)]
			var cen := Vector2.ZERO
			for q: Vector2i in tiles:
				cen += city.cell_center(float(q.x) + 0.5, float(q.y) + 0.5, float(grid.grid[q.y][q.x].get("elevation", 1.0)))
			cen /= float(tiles.size())
			var spec: Array = SPECIAL_MARKERS[b]
			out.append({"id": "sp_%s_%d_%d" % [b, x, y], "name": _marker_name(String(spec[0])), "pos": cen - Vector2(0, float(spec[1]))})
	for kind: String in ["seowon", "seodang"]:
		for pl: Dictionary in grid.list_plazas(kind):
			var n := float(pl["n"])
			var c2 := city.cell_center(float(pl["x0"]) + n * 0.5, float(pl["y0"]) + n * 0.5, 1.0)
			out.append({"id": "sp_%s_%d_%d" % [kind, int(pl["x0"]), int(pl["y0"])], "name": _marker_name("매곡서원" if kind == "seowon" else "서당"), "pos": c2 - Vector2(0, 92.0 if kind == "seowon" else 66.0)})
	return out

## 근대화 시대에 개편한 건물은 현판도 근대 이름(정부청사·수원 대학교·초등학교 등). 살피기 창 제목과 같은 규칙
func _marker_name(n: String) -> String:
	return UrbanEvolutionManager.instance.modern_title(n) if UrbanEvolutionManager.instance else n

var _marker_sig := ""
func _special_marker_sig() -> String:
	var sig := ""
	for sb: Dictionary in _special_marker_list():
		sig += String(sb["id"]) + "=" + String(sb["name"]) + ";" # 이름이 바뀌어도(개편) 현판을 다시 단다
	return sig
