class_name GameSettings
extends RefCounted

## 게임 설정 및 환경 변수 영구 보존(Persistence) 단일 공급원 (SSOT)
## user://settings.cfg 에 안전하게 설정값을 저장 및 로드하고 게임 전역에 실시간 동기화합니다.

const SETTINGS_PATH := "user://settings.cfg"

# --- 설정 상태 변수 ---
static var fullscreen: bool = false
static var sound_enabled: bool = true
static var master_volume: float = 0.8
static var music_volume: float = 0.7
static var auto_show_gazette: bool = true
static var judge_advice_enabled: bool = true
static var incident_goto_enabled: bool = true
static var disaster_popup_enabled: bool = true
static var settlement_popup_enabled: bool = true

static var _loaded: bool = false

# --- 1. 전체화면 (Fullscreen) ---
static func is_fullscreen() -> bool:
	ensure_loaded()
	return fullscreen

static func set_fullscreen(enabled: bool) -> void:
	ensure_loaded()
	fullscreen = enabled
	_apply_fullscreen()
	save_settings()

static func toggle_fullscreen() -> void:
	ensure_loaded()
	set_fullscreen(not fullscreen)

static func _apply_fullscreen() -> void:
	var cur_mode := DisplayServer.window_get_mode()
	var target_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if cur_mode != target_mode:
		DisplayServer.window_set_mode(target_mode)

# --- 2. 사운드 On/Off (소리) ---
static func is_sound_enabled() -> bool:
	ensure_loaded()
	return sound_enabled

static func set_sound_enabled(enabled: bool) -> void:
	ensure_loaded()
	sound_enabled = enabled
	_apply_sound()
	save_settings()

static func toggle_sound() -> void:
	ensure_loaded()
	set_sound_enabled(not sound_enabled)

static func _apply_sound() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_mute(master_bus, not sound_enabled)

# --- 3. 주 음량 (Master Volume) ---
static func get_master_volume() -> float:
	ensure_loaded()
	return master_volume

static func set_master_volume(vol: float) -> void:
	ensure_loaded()
	master_volume = clampf(vol, 0.0, 1.0)
	_apply_master_volume()
	save_settings()

static func _apply_master_volume() -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		var safe_vol := maxf(master_volume, 0.0001)
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(safe_vol))

# --- 4. 배경음악 크기 (Music Volume) ---
static func get_music_volume() -> float:
	ensure_loaded()
	return music_volume

static func set_music_volume(vol: float) -> void:
	ensure_loaded()
	music_volume = clampf(vol, 0.0, 1.0)
	_apply_music_volume()
	save_settings()

static func _apply_music_volume() -> void:
	if MusicManager.instance != null:
		MusicManager.instance.set_volume(music_volume, false)
	var music_bus := AudioServer.get_bus_index("Music")
	if music_bus >= 0:
		var safe_vol := maxf(music_volume, 0.0001)
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(safe_vol))

# --- 5. 비변사 자동 팝업 On/Off ---
static func is_auto_show_gazette() -> bool:
	ensure_loaded()
	return auto_show_gazette

static func set_auto_show_gazette(enabled: bool) -> void:
	ensure_loaded()
	auto_show_gazette = enabled
	save_settings()

static func toggle_auto_show_gazette() -> void:
	ensure_loaded()
	set_auto_show_gazette(not auto_show_gazette)

# --- 6. 김판관 조언 On/Off ---
static func is_judge_advice_enabled() -> bool:
	ensure_loaded()
	return judge_advice_enabled

static func set_judge_advice_enabled(enabled: bool) -> void:
	ensure_loaded()
	judge_advice_enabled = enabled
	save_settings()

static func toggle_judge_advice() -> void:
	ensure_loaded()
	set_judge_advice_enabled(not judge_advice_enabled)

# --- 7. 사건 현장 바로가기 On/Off ---
static func is_incident_goto_enabled() -> bool:
	ensure_loaded()
	return incident_goto_enabled

static func set_incident_goto_enabled(enabled: bool) -> void:
	ensure_loaded()
	incident_goto_enabled = enabled
	save_settings()

static func toggle_incident_goto() -> void:
	ensure_loaded()
	set_incident_goto_enabled(not incident_goto_enabled)

# --- 8. 사건 및 재난 팝업 On/Off ---
static func is_disaster_popup_enabled() -> bool:
	ensure_loaded()
	return disaster_popup_enabled

static func set_disaster_popup_enabled(enabled: bool) -> void:
	ensure_loaded()
	disaster_popup_enabled = enabled
	save_settings()

static func toggle_disaster_popup() -> void:
	ensure_loaded()
	set_disaster_popup_enabled(not disaster_popup_enabled)

# --- 9. 결산보고 팝업 On/Off ---
static func is_settlement_popup_enabled() -> bool:
	ensure_loaded()
	return settlement_popup_enabled

static func set_settlement_popup_enabled(enabled: bool) -> void:
	ensure_loaded()
	settlement_popup_enabled = enabled
	save_settings()

static func toggle_settlement_popup() -> void:
	ensure_loaded()
	set_settlement_popup_enabled(not settlement_popup_enabled)

# --- 영구 보존(Persistence) 로드 및 저장 ---
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	load_settings()

static func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err == OK:
		fullscreen = bool(cfg.get_value("display", "fullscreen", false))
		sound_enabled = bool(cfg.get_value("audio", "sound_enabled", true))
		master_volume = clampf(float(cfg.get_value("audio", "master_volume", 0.8)), 0.0, 1.0)
		music_volume = clampf(float(cfg.get_value("audio", "music_volume", 0.7)), 0.0, 1.0)
		auto_show_gazette = bool(cfg.get_value("gazette", "auto_show", true))
		judge_advice_enabled = bool(cfg.get_value("gameplay", "judge_advice", true))
		incident_goto_enabled = bool(cfg.get_value("gameplay", "incident_goto", true))
		disaster_popup_enabled = bool(cfg.get_value("gameplay", "disaster_popup", true))
		settlement_popup_enabled = bool(cfg.get_value("gameplay", "settlement_popup", true))
	else:
		fullscreen = false
		sound_enabled = true
		master_volume = 0.8
		music_volume = 0.7
		auto_show_gazette = true
		judge_advice_enabled = true
		incident_goto_enabled = true
		disaster_popup_enabled = true
		settlement_popup_enabled = true

static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH) # 기존 데이터 보존
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("audio", "sound_enabled", sound_enabled)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("gazette", "auto_show", auto_show_gazette)
	cfg.set_value("gameplay", "judge_advice", judge_advice_enabled)
	cfg.set_value("gameplay", "incident_goto", incident_goto_enabled)
	cfg.set_value("gameplay", "disaster_popup", disaster_popup_enabled)
	cfg.set_value("gameplay", "settlement_popup", settlement_popup_enabled)
	cfg.save(SETTINGS_PATH)

static func apply_all() -> void:
	ensure_loaded()
	_apply_fullscreen()
	_apply_sound()
	_apply_master_volume()
	_apply_music_volume()

# --- 공통 UI 카드 및 버튼 스타일 헬퍼 ---
static func create_settings_card(title_txt: String) -> PanelContainer:
	var card := PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.97, 0.94, 0.88, 1.0) # 밝은 닥종이 베이지
	csb.border_color = Color("8c7352") # 옻칠 테두리
	csb.set_border_width_all(1)
	csb.set_corner_radius_all(6)
	csb.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", csb)

	var vb := VBoxContainer.new()
	vb.name = "VBox"
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	var head_lbl := Label.new()
	head_lbl.text = title_txt
	head_lbl.add_theme_color_override("font_color", Color("78350f"))
	head_lbl.add_theme_font_size_override("font_size", 14)
	vb.add_child(head_lbl)

	return card

static func apply_settings_btn_style(btn: Button, is_on: bool) -> void:
	var bg_col: Color = Color(0.12, 0.28, 0.15) if is_on else Color(0.28, 0.12, 0.10)
	var border_col: Color = Color(0.35, 0.85, 0.45) if is_on else Color(0.85, 0.45, 0.35)

	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", sb)

	var hsb: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
	hsb.bg_color = bg_col.lightened(0.2)
	hsb.border_color = Color(0.98, 0.85, 0.35)
	hsb.set_border_width_all(2)
	btn.add_theme_stylebox_override("hover", hsb)

	var psb: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
	psb.bg_color = bg_col.darkened(0.2)
	btn.add_theme_stylebox_override("pressed", psb)

	btn.add_theme_color_override("font_color", Color(0.98, 0.95, 0.85))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.7))
	btn.add_theme_font_size_override("font_size", 12)

static func reset_to_defaults() -> void:
	fullscreen = false
	sound_enabled = true
	master_volume = 0.8
	music_volume = 0.7
	auto_show_gazette = true
	judge_advice_enabled = true
	incident_goto_enabled = true
	disaster_popup_enabled = true
	settlement_popup_enabled = true
	apply_all()
	save_settings()

static func apply_neutral_btn_style(btn: Button) -> void:
	var bg_col: Color = Color(0.28, 0.25, 0.22)
	var border_col: Color = Color(0.60, 0.52, 0.42)

	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", sb)

	var hsb: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
	hsb.bg_color = bg_col.lightened(0.2)
	hsb.border_color = Color(0.98, 0.85, 0.35)
	hsb.set_border_width_all(2)
	btn.add_theme_stylebox_override("hover", hsb)

	var psb: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
	psb.bg_color = bg_col.darkened(0.2)
	btn.add_theme_stylebox_override("pressed", psb)

	btn.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.7))
	btn.add_theme_font_size_override("font_size", 12)

## 메인 화면과 본 게임 모두에서 사용하는 100% 통일된 환경설정 카드 집합 빌더
## 한 줄에 4개의 On/Off 버튼을 GridContainer로 정렬하여 컴팩트하고 직관적인 레이아웃 제공
static func build_unified_settings_cards(container: Control, toast_fn: Callable = Callable(), on_rebuild: Callable = Callable()) -> void:
	ensure_loaded()

	# 1. 풍악 및 음향 음량 조율 카드 (주 음량 & 배경음악 가로 2열 나란히 배치)
	var sound_card := create_settings_card("풍악 및 현장 음향 음량 조율")
	container.add_child(sound_card)
	var sound_box := sound_card.get_node("VBox") as VBoxContainer

	var vol_hb := HBoxContainer.new()
	vol_hb.add_theme_constant_override("separation", 24)
	sound_box.add_child(vol_hb)

	# 1-1. 주 음량 (Master)
	var master_hb := HBoxContainer.new()
	master_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	master_hb.add_theme_constant_override("separation", 10)
	vol_hb.add_child(master_hb)

	var master_lbl := Label.new()
	master_lbl.text = "주 음량 (Master):"
	master_lbl.add_theme_color_override("font_color", Color("57534e"))
	master_lbl.add_theme_font_size_override("font_size", 12)
	master_hb.add_child(master_lbl)

	var master_sl := HSlider.new()
	master_sl.min_value = 0.0
	master_sl.max_value = 1.0
	master_sl.step = 0.05
	master_sl.value = get_master_volume()
	master_sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	master_sl.custom_minimum_size = Vector2(120, 24)
	master_sl.value_changed.connect(func(v: float):
		set_master_volume(v)
	)
	master_hb.add_child(master_sl)

	# 1-2. 배경음악 크기 (BGM)
	var music_hb := HBoxContainer.new()
	music_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_hb.add_theme_constant_override("separation", 10)
	vol_hb.add_child(music_hb)

	var music_lbl := Label.new()
	music_lbl.text = "배경음악 (BGM):"
	music_lbl.add_theme_color_override("font_color", Color("57534e"))
	music_lbl.add_theme_font_size_override("font_size", 12)
	music_hb.add_child(music_lbl)

	var music_sl := HSlider.new()
	music_sl.min_value = 0.0
	music_sl.max_value = 1.0
	music_sl.step = 0.05
	music_sl.value = get_music_volume()
	music_sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_sl.custom_minimum_size = Vector2(120, 24)
	music_sl.value_changed.connect(func(v: float):
		set_music_volume(v)
	)
	music_hb.add_child(music_sl)

	# 2. 치세 환경 및 알림 설정 카드 (한 줄에 4개씩 GridContainer 배치)
	var toggle_card := create_settings_card("치세 환경 및 알림 설정 (한 줄 4개 배치)")
	container.add_child(toggle_card)
	var toggle_box := toggle_card.get_node("VBox") as VBoxContainer

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle_box.add_child(grid)

	# 2-1. 화면 모드 (전체화면 / 창모드)
	var is_fs := is_fullscreen()
	var btn_screen := Button.new()
	btn_screen.text = "화면: 전체화면 [ON]" if is_fs else "화면: 창모드 [OFF]"
	btn_screen.tooltip_text = "전체화면 또는 창모드로 전환합니다. [F11] 키로도 상시 전환할 수 있습니다."
	btn_screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_screen.custom_minimum_size = Vector2(150, 44)
	btn_screen.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	apply_settings_btn_style(btn_screen, is_fs)
	btn_screen.pressed.connect(func():
		toggle_fullscreen()
		if toast_fn.is_valid():
			toast_fn.call("화면 모드가 %s으로 전환되었습니다." % ("전체화면" if is_fullscreen() else "창모드"))
		if on_rebuild.is_valid():
			on_rebuild.call()
	)
	grid.add_child(btn_screen)

	# 2-2. 음향 출력 (소리 On/Off)
	var snd_on := is_sound_enabled()
	var btn_sound := Button.new()
	btn_sound.text = "소리: 켜짐 [ON]" if snd_on else "소리: 음소거 [OFF]"
	btn_sound.tooltip_text = "배경 국악 풍악 및 축성 효과음 출력을 켜거나 음소거합니다."
	btn_sound.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_sound.custom_minimum_size = Vector2(150, 44)
	btn_sound.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	apply_settings_btn_style(btn_sound, snd_on)
	btn_sound.pressed.connect(func():
		toggle_sound()
		if toast_fn.is_valid():
			toast_fn.call("음향이 %s되었습니다." % ("활성화" if is_sound_enabled() else "음소거"))
		if on_rebuild.is_valid():
			on_rebuild.call()
	)
	grid.add_child(btn_sound)

	# 2-3. 비변사 시보 발간 알림 (격년 8턴)
	var is_auto_gaz := is_auto_show_gazette()
	var btn_gaz := Button.new()
	btn_gaz.text = "시보 팝업: 켜짐 [ON]" if is_auto_gaz else "시보 팝업: 꺼짐 [OFF]"
	btn_gaz.tooltip_text = "매 2년(8턴) 주기 가을 턴 종료 시 발행되는 비변사 한글 시보의 화면 자동 팝업 여부"
	btn_gaz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_gaz.custom_minimum_size = Vector2(150, 44)
	btn_gaz.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	apply_settings_btn_style(btn_gaz, is_auto_gaz)
	btn_gaz.pressed.connect(func():
		toggle_auto_show_gazette()
		if toast_fn.is_valid():
			toast_fn.call("비변사 시보 자동 팝업이 %s되었습니다." % ("활성화" if is_auto_show_gazette() else "해제"))
		if on_rebuild.is_valid():
			on_rebuild.call()
	)
	grid.add_child(btn_gaz)

	# 2-4. 길잡이 김판관 정무 조언
	var is_judge_on := is_judge_advice_enabled()
	var btn_judge := Button.new()
	btn_judge.text = "김판관 조언: 켜짐 [ON]" if is_judge_on else "김판관 조언: 꺼짐 [OFF]"
	btn_judge.tooltip_text = "수원부 길잡이 김판관의 튜토리얼, 정무 조언, 어명 교지 및 완공 보고 자동 팝업 여부"
	btn_judge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_judge.custom_minimum_size = Vector2(150, 44)
	btn_judge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	apply_settings_btn_style(btn_judge, is_judge_on)
	btn_judge.pressed.connect(func():
		toggle_judge_advice()
		if toast_fn.is_valid():
			toast_fn.call("김판관 정무 조언 자동 알림이 %s되었습니다." % ("활성화" if is_judge_advice_enabled() else "차단"))
		if on_rebuild.is_valid():
			on_rebuild.call()
	)
	grid.add_child(btn_judge)

	# 2-5. 사건 현장 바로가기 (위치 보기 버튼)
	var is_goto_on := is_incident_goto_enabled()
	var btn_goto := Button.new()
	btn_goto.text = "현장 바로가기: 켜짐 [ON]" if is_goto_on else "현장 바로가기: 꺼짐 [OFF]"
	btn_goto.tooltip_text = "화재, 도적 침입 등 사건 발생 시 알림창에 [현장 위치 보기] 버튼 표시 및 카메라 이동 여부"
	btn_goto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_goto.custom_minimum_size = Vector2(150, 44)
	btn_goto.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	apply_settings_btn_style(btn_goto, is_goto_on)
	btn_goto.pressed.connect(func():
		toggle_incident_goto()
		if toast_fn.is_valid():
			toast_fn.call("사건 현장 바로가기 기능이 %s되었습니다." % ("활성화" if is_incident_goto_enabled() else "비활성화"))
		if on_rebuild.is_valid():
			on_rebuild.call()
	)
	grid.add_child(btn_goto)

	# 2-6. 긴급 사건 및 재난 경보 팝업
	var is_disaster_on := is_disaster_popup_enabled()
	var btn_disaster := Button.new()
	btn_disaster.text = "재난 팝업: 켜짐 [ON]" if is_disaster_on else "재난 팝업: 꺼짐 [OFF]"
	btn_disaster.tooltip_text = "화재, 수해, 공성 침략 등 긴급 재난 발생 시 상단 알림 배너 및 중앙 긴급 경보 모달 팝업 표시 여부"
	btn_disaster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_disaster.custom_minimum_size = Vector2(150, 44)
	btn_disaster.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	apply_settings_btn_style(btn_disaster, is_disaster_on)
	btn_disaster.pressed.connect(func():
		toggle_disaster_popup()
		if toast_fn.is_valid():
			toast_fn.call("긴급 재난 경보 팝업이 %s되었습니다." % ("활성화" if is_disaster_popup_enabled() else "차단"))
		if on_rebuild.is_valid():
			on_rebuild.call()
	)
	grid.add_child(btn_disaster)

	# 2-7. 계절 결산 실록 보고 알림
	var is_settle_on := is_settlement_popup_enabled()
	var btn_settle := Button.new()
	btn_settle.text = "결산 알림: 켜짐 [ON]" if is_settle_on else "결산 알림: 꺼짐 [OFF]"
	btn_settle.tooltip_text = "매 계절(봄·여름·가을·겨울) 턴 종료 시 국고 세입, 군량 수확 및 인구 변동 결산 알림 메시지 표시 여부"
	btn_settle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_settle.custom_minimum_size = Vector2(150, 44)
	btn_settle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	apply_settings_btn_style(btn_settle, is_settle_on)
	btn_settle.pressed.connect(func():
		toggle_settlement_popup()
		if toast_fn.is_valid():
			toast_fn.call("계절 결산 알림이 %s되었습니다." % ("활성화" if is_settlement_popup_enabled() else "숨김"))
		if on_rebuild.is_valid():
			on_rebuild.call()
	)
	grid.add_child(btn_settle)

	# 2-8. 전체 설정 초기화 (기본값 복원)
	var btn_reset := Button.new()
	btn_reset.text = "기본값 복원"
	btn_reset.tooltip_text = "모든 화면, 음향, 알림 설정을 초기 기본 상태로 복원합니다."
	btn_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_reset.custom_minimum_size = Vector2(150, 44)
	btn_reset.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	apply_neutral_btn_style(btn_reset)
	btn_reset.pressed.connect(func():
		reset_to_defaults()
		if toast_fn.is_valid():
			toast_fn.call("모든 게임 설정이 초기 기본값으로 복원되었습니다.")
		if on_rebuild.is_valid():
			on_rebuild.call()
	)
	grid.add_child(btn_reset)
