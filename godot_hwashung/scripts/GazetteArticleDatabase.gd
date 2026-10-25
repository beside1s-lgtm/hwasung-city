class_name GazetteArticleDatabase
extends RefCounted

## 비변사 한글 시보 기사 데이터베이스 및 상태 매칭 엔진
## PORT-TRACE [비변사시보 기사 150]: 기사 본문은 GazetteArticles(상황·계절·조정·재난·가십 각 30). 여기서는 지금 게임 상태에 맞는
## 기사를 고른다 — 1면: 벌어진 재난 > 두드러진 도시 상황 > 조정 일 / 우측: 계절 · 조정(또는 재난) · 가십. 최근 실린 기사는 피한다.
## 그림: assets/illustrations/gazette/<기사 id>.png가 있으면 그것, 없으면 기사에 적힌 풍속화(FolkArtAtlasGenerator)로.

const KOREAN_YEAR_CYCLE := [
	"기유(己酉)", "경술(庚戌)", "신해(辛亥)", "임자(壬子)",
	"계축(癸丑)", "갑인(甲寅)", "을묘(乙卯)", "병진(丙辰)",
	"정사(丁巳)", "무오(戊午)", "기미(己未)", "경신(庚申)"
]
const SEASON_KEYS := ["spring", "summer", "autumn", "winter"]
const SEASON_NAMES := ["봄", "여름", "가을", "겨울"]
const POOL_LABEL := {"state": "시국", "season": "세시풍속", "court": "조정 소식", "disaster": "재난 대처", "gossip": "저잣거리 소식"}
const RECENT_MAX := 40
const NO_GWANA_POP := 800 # 관아 없이 이 인구를 넘으면 "관아가 없어 불안" 기사
static var _recent: Array[String] = []

## 신문 발행 호수 데이터 구조체 생성 및 반환
static func get_current_gazette_edition(sim: SimulationCore, grid: GameGrid, issue_num: int = 1) -> Dictionary:
	var year: int = sim.current_year if sim != null else 1789
	var king_year: int = max(1, year - 1776 + 1)
	var ganji_idx: int = posmod(year - 1789, KOREAN_YEAR_CYCLE.size())
	var ganji_str: String = KOREAN_YEAR_CYCLE[ganji_idx]
	# 시보는 계절이 끝나며 나온다 — 호 이름은 지난달(끝난 계절)
	var si: int = SimulationCore.season_of_month(posmod(sim.month_now() - 2, 12) + 1) if sim != null else 0
	var header_date := "%s(%s) %s호 | 제 %d호 | 수원유수부 발행 | 정가: 무료 배포" % [TimeManager.era_name(year), ganji_str, SEASON_NAMES[si], issue_num] # 1800년 엔딩 뒤는 순조 이후 연호

	var f := _flags(sim, grid)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("gazette_%d_%d" % [issue_num, sim.turn if sim != null else 0])

	# 1면: 벌어진 재난 → 두드러진 도시 상황 → 조정 일 → 아무 상황
	var main := _pick(GazetteArticles.DISASTER, f, rng, "disaster", true)
	# 관아 없이 고을이 커졌으면 그 소식이 1면에 실린다
	if main.is_empty() and bool(f.get("no_gwana", false)):
		var ng: Array = GazetteArticles.STATE.filter(func(a: Dictionary) -> bool: return String(a.get("c", "")) == "no_gwana")
		main = _pick(ng, f, rng, "state", true)
	if main.is_empty():
		main = _pick(GazetteArticles.STATE, f, rng, "state", true)
	if main.is_empty():
		main = _pick(GazetteArticles.COURT, f, rng, "court", true)
	if main.is_empty():
		main = _pick(GazetteArticles.STATE, f, rng, "state", false)
	var sub1 := _pick(GazetteArticles.SEASON, f, rng, "season", false)
	var sub2: Dictionary
	if String(main.get("pool", "")) == "court":
		sub2 = _pick(GazetteArticles.DISASTER, f, rng, "disaster", false)
	else:
		sub2 = _pick(GazetteArticles.COURT, f, rng, "court", false)
	var sub3 := _pick(GazetteArticles.GOSSIP, f, rng, "gossip", false)

	return {
		"header_date": header_date,
		"issue_num": issue_num,
		"year": year,
		"king_year": king_year,
		"ganji": ganji_str,
		"main": main,
		"sub1": sub1,
		"sub2": sub2,
		"sub3": sub3
	}

## 새 기사 그림 이름 → 그림이 아직 없을 때 대신 쓸 기존 풍속화
const ART_FALLBACK := {"flood": "fishing", "fire": "blacksmith", "famine_relief": "market", "plague_doctor": "scholars",
	"bandit_raid": "hunting_bear", "rebel_arrest": "gwana_conflict", "prince_study": "scholars", "uigwe_book": "scholars",
	"night_drill": "seojangdae_guard", "archery": "ssireum", "exam": "scholars", "lantern_festival": "swing",
	"harvest": "ssireum", "kimjang": "tavern", "snow_play": "ssireum", "ghost_gossip": "tavern"}

static func _load_png(p: String) -> Texture2D:
	if ResourceLoader.exists(p):
		return load(p) as Texture2D
	if FileAccess.file_exists(AssetPaths.disk_path(p)):
		var img := Image.load_from_file(AssetPaths.disk_path(p))
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null

## 기사에 쓸 그림: 기사 전용(gazette/<기사 id>.png) → 그림 이름(gazette/<그림 이름>.png) → 기존 풍속화
static func art_texture(d: Dictionary) -> Texture2D:
	var aid := String(d.get("id", ""))
	var key := String(d.get("art_key", "market"))
	for nm: String in [aid, key]:
		if nm != "":
			var t := _load_png("res://assets/illustrations/gazette/%s.png" % nm)
			if t != null:
				return t
	return FolkArtAtlasGenerator.get_art_texture(String(ART_FALLBACK.get(key, key)))

## 지금 게임 상태 → 조건 이름별 참/거짓
static func _flags(sim: SimulationCore, grid: GameGrid) -> Dictionary:
	var f := {"any": true}
	if sim == null:
		return f
	f["loyal_high"] = sim.loyalty >= 75
	f["loyal_low"] = sim.loyalty < 40
	f["riot"] = sim.loyalty < 30
	f["auth_high"] = sim.authority >= 80
	f["auth_low"] = sim.authority < 40
	f["def_high"] = sim.defense_power >= 800
	f["def_low"] = sim.defense_power < 400
	var camps := false
	if sim.bandit_manager != null and "camps" in sim.bandit_manager:
		camps = not (sim.bandit_manager.camps as Array).is_empty()
	f["bandit"] = sim.bandit_active or camps
	f["rebel"] = int(sim.conspiracy_stage) > 0
	f["pop_big"] = sim.population >= 1500
	f["pop_small"] = sim.population < 300
	f["no_gwana"] = not SunlacheongManager.gwana_built and sim.population >= NO_GWANA_POP
	f["rich"] = sim.gold >= 20000
	f["poor"] = sim.gold < 500
	f["rice_low"] = sim.rice < 400
	var fort: int = int(grid.fortress_progress) if grid != null and "fortress_progress" in grid else 0
	f["fort_done"] = fort >= 100
	f["fort_building"] = fort < 100
	var season_i: int = SimulationCore.season_of_month(posmod(sim.month_now() - 2, 12) + 1)
	f[SEASON_KEYS[season_i]] = true
	var hired := 0
	for k in sim.retainers.keys():
		if bool(sim.retainers[k]):
			hired += 1
	f["retainers_many"] = hired >= 10
	f["retainers_few"] = hired < 5
	if sim.tech_tree != null:
		var pe: float = float(sim.tech_tree.prince_edu_progress)
		f["prince_edu"] = pe > 0.0 and pe < 100.0
		f["prince_done"] = pe >= 100.0
		f["research_on"] = sim.tech_tree.current_researching != ""
		var done := 0
		for k2 in sim.tech_tree.tech_completed_dict.keys():
			if bool(sim.tech_tree.tech_completed_dict[k2]):
				done += 1
		f["research_done"] = done >= 3
	f["eulmyo_done"] = sim.is_eulmyo_completed
	f["eulmyo_soon"] = not sim.is_eulmyo_completed and sim.current_year >= 1793 and sim.current_year <= 1795
	if sim.uigwe_manager != null and sim.uigwe_manager.has_method("is_completed"):
		f["uigwe_done"] = sim.uigwe_manager.is_completed("wonhaeng") or sim.uigwe_manager.is_completed("seongyeok")
	f["academic_high"] = sim.academic >= 60
	f["flood"] = sim.flood_crisis_active
	f["fire"] = sim.fire_active
	f["famine"] = sim.famine_active
	f["plague"] = sim.plague_active
	f["drought"] = sim.drought_turns_left > 0
	return f

## 조건에 맞는 기사 하나(최근 실린 것은 피함). specific_only면 "any"가 아닌(지금 상황에 꼭 맞는) 기사만.
static func _pick(pool: Array, f: Dictionary, rng: RandomNumberGenerator, pool_name: String, specific_only: bool) -> Dictionary:
	var fit: Array = []
	var fit_any: Array = []
	for a: Dictionary in pool:
		var c := String(a.get("c", "any"))
		if not bool(f.get(c, false)):
			continue
		if c == "any":
			fit_any.append(a)
		else:
			fit.append(a)
	var cands: Array = fit if specific_only else (fit if (not fit.is_empty() and rng.randf() < 0.6) else fit + fit_any)
	if cands.is_empty():
		return {}
	var fresh := cands.filter(func(a: Dictionary) -> bool: return not _recent.has(String(a["id"])))
	if fresh.is_empty():
		fresh = cands
	var pick: Dictionary = fresh[rng.randi() % fresh.size()]
	_recent.append(String(pick["id"]))
	while _recent.size() > RECENT_MAX:
		_recent.pop_front()
	return {
		"id": pick["id"],
		"pool": pool_name,
		"category": POOL_LABEL.get(pool_name, "소식"),
		"headline": pick.get("h", ""),
		"subhead": pick.get("s", ""),
		"body": pick.get("b", ""),
		"interview": pick.get("i", ""),
		"art_key": pick.get("a", "market"),
	}
