extends Node
class_name TimeManager

## 심시티 스타일 일시정지 가능한 실시간 및 틱 기반 계절 캘린더 시스템
## [Single Source of Truth]: 게임 시작 시점 1789년(기유년) 1월 고정 및 누적 틱 기반 연도/월 일원화 연산
signal time_changed(year: int, season: String, month: int, day: int)
signal season_changed(season: String)
signal speed_changed(speed_mode: int)
signal simulation_tick(tick_count: int)
signal year_changed(current_year: int)
signal month_changed(current_month: int)

enum SpeedMode { PAUSE = 0, NORMAL = 1, FAST = 2, ULTRA = 3 }

@export var current_speed: SpeedMode = SpeedMode.NORMAL
@export var base_tick_interval: float = 1.0 # 1배속 기준 1초에 1틱(1일)

const START_YEAR: int = 1789 # 수원 신읍치 조성 및 팔달산 천도 착수 연도 (정조 13년, 기유년)
const START_MONTH: int = 1   # 1월

var current_year: int = START_YEAR
var current_month: int = START_MONTH
var current_day: int = 1
var total_ticks: int = 0
var last_season: String = "겨울" # 1월은 겨울

var tick_accumulator: float = 0.0

const SEASONS: Array[String] = ["봄", "여름", "가을", "겨울"]

func _ready() -> void:
	last_season = get_current_season()
	emit_signal("time_changed", current_year, last_season, current_month, current_day)
	emit_signal("month_changed", current_month)
	emit_signal("year_changed", current_year)
	emit_signal("speed_changed", int(current_speed))

func _process(delta: float) -> void:
	if current_speed == SpeedMode.PAUSE:
		return

	tick_accumulator += delta * speed_factor()
	var step: float = base_tick_interval
	while tick_accumulator >= step:
		tick_accumulator -= step
		_advance_one_tick()

func _advance_one_tick() -> void:
	total_ticks += 1
	var old_month: int = current_month
	var old_year: int = current_year

	# 1개월 = 30일(30틱) 압축 시뮬레이션
	# Single Source of Truth: 누적 개월 수 기반 연도/월 계산식 일원화
	var total_months: int = int(float(total_ticks) / 30.0)
	current_day = (total_ticks % 30) + 1
	current_month = ((START_MONTH - 1 + total_months) % 12) + 1
	current_year = START_YEAR + int(float(START_MONTH - 1 + total_months) / 12.0)

	var cur_season: String = get_current_season()
	emit_signal("simulation_tick", total_ticks)
	emit_signal("time_changed", current_year, cur_season, current_month, current_day)

	if current_month != old_month:
		emit_signal("month_changed", current_month)

	if current_year != old_year:
		emit_signal("year_changed", current_year)

	if cur_season != last_season:
		last_season = cur_season
		emit_signal("season_changed", cur_season)

## PORT-TRACE [배속 연동]: 사용자 요청 — 정지(0x)/보통(1x)/빠르게(2x)/매우 빠르게(3x)
func speed_factor() -> float:
	match current_speed:
		SpeedMode.PAUSE: return 0.0
		SpeedMode.FAST: return 2.0
		SpeedMode.ULTRA: return 3.0
	return 1.0

func set_speed(mode: SpeedMode) -> void:
	current_speed = mode
	emit_signal("speed_changed", int(current_speed))

func toggle_pause() -> void:
	if current_speed == SpeedMode.PAUSE:
		set_speed(SpeedMode.NORMAL)
	else:
		set_speed(SpeedMode.PAUSE)

func advance_day(days: int = 1) -> void:
	for i: int in range(days):
		_advance_one_tick()

func advance_months(months: int = 1) -> void:
	advance_day(months * 30)

func advance_year(years: int = 1) -> void:
	advance_day(years * 360)

func skip_to_year(target_year: int) -> void:
	if target_year <= current_year:
		return
	var diff_years: int = target_year - current_year
	advance_year(diff_years)

## 근대화 시대 진입: 틱을 하나씩 돌리지 않고 해당 연도 1월 1일로 바로 넘어간다.
func jump_to_year(target_year: int) -> void:
	if target_year <= current_year:
		return
	total_ticks = (target_year - START_YEAR) * 360
	current_day = 1
	current_month = 1
	current_year = target_year
	tick_accumulator = 0.0
	var cur_season: String = get_current_season()
	emit_signal("time_changed", current_year, cur_season, current_month, current_day)
	emit_signal("month_changed", current_month)
	emit_signal("year_changed", current_year)
	if cur_season != last_season:
		last_season = cur_season
		emit_signal("season_changed", cur_season)

func get_total_months() -> int:
	return int(float(total_ticks) / 30.0)

func get_current_season() -> String:
	# 3,4,5월 = 봄 / 6,7,8월 = 여름 / 9,10,11월 = 가을 / 12,1,2월 = 겨울
	if current_month in [3, 4, 5]: return "봄"
	elif current_month in [6, 7, 8]: return "여름"
	elif current_month in [9, 10, 11]: return "가을"
	else: return "겨울"

func get_era_string() -> String:
	return "%s %s %d월 %d일" % [era_label(current_year), get_current_season(), current_month, current_day]

## PORT-TRACE [1800년 뒤 연호]: 사용자 요청 — "1800년 엔딩 뒤 상단 연호를 정조 N년 대신 순조 N년으로(1803 → 순조 3년)".
## 1800년 엔딩(정조 승하·순조 즉위) 뒤로는 실제 왕위 계승을 따른다. 즉위한 해는 '즉위년', 이듬해가 원년(유년칭원).
## 대한제국 때는 연호(광무·융희), 1910년 뒤나 현대 정치체제(왕조 끝)에서는 서기 연도만.
const REIGNS_AFTER_1800 := [
	# [이름, 원년의 앞해(즉위한 해), 마지막 해]
	["순조", 1800, 1834],
	["헌종", 1834, 1849],
	["철종", 1849, 1863],
	["고종", 1863, 1896],
	["광무", 1896, 1906],
	["융희", 1906, 1910],
]

## "정조 14년(1789)", "순조 즉위년(1800)", "순조 3년(1803)", "광무 원년(1897)", "1915년"
static func era_label(year: int) -> String:
	var en := era_name(year)
	return en if en == "%d년" % year else "%s(%d)" % [en, year]

## 괄호 속 서기 연도 없이: "정조 14년", "순조 즉위년", "순조 3년", "1915년"(왕조가 없으면 서기 연도만)
static func era_name(year: int) -> String:
	var after_ending := year > 1800 or (year == 1800 and EndingManager.instance != null and EndingManager.instance.ending_triggered_flag)
	if not after_ending:
		return "정조 %d년" % (year - 1776 + 1)
	if ModernPoliticsManager.is_post_monarchy() or year > 1910:
		return "%d년" % year
	if year == 1800:
		return "순조 즉위년"
	for r: Array in REIGNS_AFTER_1800:
		if year <= int(r[2]):
			var n: int = year - int(r[1])
			return "%s %s" % [r[0], "원년" if n == 1 else "%d년" % n]
	return "%d년" % year
