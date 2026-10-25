class_name ThemeManager
extends RefCounted

## 전역 전통 서체 및 타이포그래피 시스템
## 기본 본문 서체: 궁서체 (gungsuh.ttf)
## 강조 및 타이틀 서체: 휴먼옛체 (human_old.ttf)
## 도장/관인 서체: hunminjeongeum.ttf
## (yangjae_injang.ttf는 이 파일과 내용이 똑같은 사본이라 내보내기에서 빼고 한 벌만 쓴다)

const FONT_BASE_PATH := "res://assets/fonts/gungsuh.ttf"
const FONT_TITLE_PATH := "res://assets/fonts/human_old.ttf"
const FONT_SEAL_PATH := "res://assets/fonts/hunminjeongeum.ttf"
const FONT_HUNMIN_PATH := "res://assets/fonts/hunminjeongeum.ttf"
const FONT_FALLBACK_PATH := "res://assets/fonts/neodgm.ttf"

static var font_base: Font = null
static var font_title: Font = null
static var font_seal: Font = null
static var _initialized: bool = false

static func initialize_fonts() -> void:
	if _initialized:
		return
	_initialized = true

	font_base = _load_font_safe(FONT_BASE_PATH)
	font_title = _load_font_safe(FONT_TITLE_PATH)
	font_seal = _load_font_safe(FONT_SEAL_PATH)

	# 기본 fallback 세팅
	if font_base == null:
		font_base = _load_font_safe(FONT_FALLBACK_PATH)
	if font_title == null:
		font_title = font_base
	if font_seal == null:
		font_seal = _load_font_safe(FONT_HUNMIN_PATH)
		if font_seal == null:
			font_seal = font_title

static func _load_font_safe(path: String) -> Font:
	if ResourceLoader.exists(path):
		var f = load(path)
		if f is Font:
			return f
	return null

static func get_base_font() -> Font:
	initialize_fonts()
	return font_base

static func get_title_font() -> Font:
	initialize_fonts()
	return font_title

static func get_seal_font() -> Font:
	initialize_fonts()
	return font_seal

## 컨트롤 노드에 본문 궁서체 테마 적용
static func apply_base_font(control: Control, font_size: int = -1) -> void:
	var f: Font = get_base_font()
	if f != null:
		control.add_theme_font_override("font", f)
	if font_size > 0:
		control.add_theme_font_size_override("font_size", font_size)

## 컨트롤 노드에 제목 휴먼옛체 테마 적용
static func apply_title_font(control: Control, font_size: int = -1) -> void:
	var f: Font = get_title_font()
	if f != null:
		control.add_theme_font_override("font", f)
	if font_size > 0:
		control.add_theme_font_size_override("font_size", font_size)

## 컨트롤 노드에 도장/인장 양재인장체 테마 적용
static func apply_seal_font(control: Control, font_size: int = -1) -> void:
	var f: Font = get_seal_font()
	if f != null:
		control.add_theme_font_override("font", f)
	if font_size > 0:
		control.add_theme_font_size_override("font_size", font_size)

# 타이포그래피 표준 위계
const FONT_SIZE_TITLE: int = 22
const FONT_SIZE_SUBTITLE: int = 18
const FONT_SIZE_BODY: int = 16
const FONT_SIZE_BUTTON: int = 15
const FONT_SIZE_CAPTION: int = 13

## 버튼 중심축(pivot_offset) 보정 및 호버 마이크로 인터랙션 트윈 적용
static func bind_button_micro_interaction(btn: Button, hover_scale: float = 1.05) -> void:
	if btn == null:
		return
	if btn.size != Vector2.ZERO:
		btn.pivot_offset = btn.size * 0.5
	else:
		btn.resized.connect(func(): btn.pivot_offset = btn.size * 0.5, CONNECT_ONE_SHOT)

	var holder: Dictionary = {"tween": null}

	btn.mouse_entered.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw: Tween = holder.get("tween") as Tween
		if tw != null and tw.is_running():
			tw.kill()
		tw = btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(hover_scale, hover_scale), 0.15)
		holder["tween"] = tw
	)

	btn.mouse_exited.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw: Tween = holder.get("tween") as Tween
		if tw != null and tw.is_running():
			tw.kill()
		tw = btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.15)
		holder["tween"] = tw
	)

