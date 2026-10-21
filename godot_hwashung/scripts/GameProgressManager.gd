extends RefCounted
class_name GameProgressManager
## PORT-TRACE [역사 사전 퍼즐 영구 해금]: 인게임 세이브와 따로, user://encyclopedia_puzzle.save 에 퍼즐 조각 해금 기록을 저장한다.
## 새 게임을 시작하거나 다시 켜도 해금된 조각이 그대로 남는다. 오토로드 대신 정적 클래스로 두어 어디서든
## GameProgressManager.unlock_puzzle_piece(category, piece_id) 한 줄로 부를 수 있다.
## category = PuzzleData 판 id("people" / "buildings" / "life"), piece_id = 조각 id.

const SAVE_PATH := "user://encyclopedia_puzzle.save"

static var _loaded := false
static var _pieces: Dictionary = {}      # "people:chae_jegong" → {"year": 발견한 해(서력), "ts": 시각}
static var _boards_done: Dictionary = {} # 판 id → 완성 연출을 이미 보았는가
static var _all_clear_seen := false
static var current_year: int = 1789      # Main이 턴마다 갱신(발견 시점 표시용)
static var listeners: Array[Callable] = [] # 새 조각이 해금될 때 (key: String, piece_name: String) 로 알림

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		var d: Dictionary = parsed
		if d.get("pieces") is Dictionary:
			_pieces = d["pieces"]
		if d.get("boards_done") is Dictionary:
			_boards_done = d["boards_done"]
		_all_clear_seen = bool(d.get("all_clear_seen", false))
		# 판의 조각 수가 늘어난 경우: 더는 완성 상태가 아니면 축하 기록을 지워 다시 완성했을 때 연출이 나오게 한다
		for bd: Dictionary in PuzzleData.BOARDS:
			var bid_m: String = String(bd["id"])
			if bool(_boards_done.get(bid_m, false)) and unlocked_count(bid_m) < PuzzleData.pieces_of(bid_m).size():
				_boards_done[bid_m] = false
				_all_clear_seen = false

static func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"pieces": _pieces, "boards_done": _boards_done, "all_clear_seen": _all_clear_seen}, "  "))
	f.close()

## 조각이 맞춰졌는가
static func is_unlocked(category: String, piece_id: String) -> bool:
	_ensure()
	return _pieces.has(PuzzleData.piece_key(category, piece_id))

## 발견한 해(서력). 없으면 0
static func found_year(category: String, piece_id: String) -> int:
	_ensure()
	var k := PuzzleData.piece_key(category, piece_id)
	return int((_pieces[k] as Dictionary).get("year", 0)) if _pieces.has(k) else 0

## 조각을 영구 해금한다. 새로 해금했으면 true. 알 수 없는 조각 id는 무시한다.
static func unlock_puzzle_piece(category: String, piece_id: String, year: int = 0) -> bool:
	_ensure()
	var k := PuzzleData.piece_key(category, piece_id)
	if _pieces.has(k):
		return false
	var nm := ""
	for pc: Dictionary in PuzzleData.pieces_of(category):
		if String(pc["id"]) == piece_id:
			nm = String(pc["name"])
	if nm == "":
		return false
	_pieces[k] = {"year": year if year > 0 else current_year, "ts": int(Time.get_unix_time_from_system())}
	_save()
	for cb: Callable in listeners:
		if cb.is_valid():
			cb.call(k, nm)
	return true

static func unlocked_count(category: String) -> int:
	_ensure()
	var n := 0
	for pc: Dictionary in PuzzleData.pieces_of(category):
		if _pieces.has(PuzzleData.piece_key(category, String(pc["id"]))):
			n += 1
	return n

static func is_board_complete(category: String) -> bool:
	return unlocked_count(category) >= PuzzleData.pieces_of(category).size()

static func all_boards_complete() -> bool:
	for b: Dictionary in PuzzleData.BOARDS:
		if bool(b.get("bonus", false)):
			continue # 엔딩 모음은 덤이라 올클리어 조건에 넣지 않는다(13개 엔딩을 다 봐야 하므로)
		if not is_board_complete(String(b["id"])):
			return false
	return true

## 아직 축하 연출을 보지 못한 완성 판 id 목록
static func pending_board_celebrations() -> Array[String]:
	_ensure()
	var out: Array[String] = []
	for b: Dictionary in PuzzleData.BOARDS:
		var id := String(b["id"])
		if is_board_complete(id) and not bool(_boards_done.get(id, false)):
			out.append(id)
	return out

static func mark_board_celebrated(category: String) -> void:
	_ensure()
	_boards_done[category] = true
	_save()

static func all_clear_pending() -> bool:
	_ensure()
	return all_boards_complete() and not _all_clear_seen

static func mark_all_clear_seen() -> void:
	_ensure()
	_all_clear_seen = true
	_save()

# ---------------------------------------------------------------- 인게임 훅
const RETAINER_PIECES: Array[String] = ["chae_jegong", "jeong_yakyong", "kim_hongdo", "sim_hwanji", "hong_inhan", "kim_josun",
	"park_jega", "lee_deokmu", "seo_yugu", "jeong_beomjo", "lee_gahwan", "yu_deukgong"]

## 지도를 훑어 완공된 시설·특화 부지에 해당하는 [화성 건축물] 조각을 해금하고, 등용된 인재의 [역사 인물] 조각도 해금한다.
## 턴이 끝날 때, 시설이 완공될 때, 게임을 불러올 때 부른다(칸 4,096개를 한 번 훑는 정도로 가볍다).
static func scan(grid: GameGrid, sim: SimulationCore = null) -> void:
	if sim != null:
		current_year = int(sim.current_year)
		# [역사 인물] 조각은 등용만으로는 맞춰지지 않는다 — 지도에 나타난 그 인물을 [살피기]로 눌러야 한다(on_inspect_named)
	if grid == null or grid.grid.is_empty():
		return
	var found := {}
	var com := 0
	for row in grid.grid:
		for t: Dictionary in row:
			if t.has("wall_build") or bool(t.get("under_construction", false)):
				continue
			var b: String = String(t.get("building", ""))
			if b != "":
				if b.begins_with("haenggung"):
					found["haenggung"] = true
				elif b.begins_with("seojangdae"):
					found["seojangdae"] = true
				elif b.begins_with("yeonmudae"):
					found["yeonmudae"] = true
				elif b.begins_with("manseokgeo"):
					found["manseokgeo"] = true
				elif b.begins_with("chukmanje"):
					found["chukmanje"] = true
				elif b == "patrol":
					found["patrol"] = true
				elif b == "firefighter":
					found["firefighter"] = true
				elif b == "jinhulso":
					found["jinhulso"] = true
				elif b.begins_with("hyanggyo"):
					found["hyanggyo"] = true
				elif b.begins_with("jongnu"):
					found["jongnu"] = true
				elif b == "gate":
					found["sadaemun"] = true
				elif b == "namsu":
					found["namsumun"] = true
				elif b.begins_with("com_"):
					com += 1
			if t.get("is_hwahong", false):
				found["hwahongmun"] = true
			if t.get("is_namsu", false):
				found["namsumun"] = true
			if t.has("plaza"):
				match String((t["plaza"] as Dictionary).get("kind", "")):
					"cattle":
						found["usijang"] = true
					"seodang":
						found["seodang"] = true
					"market":
						found["jangmadang"] = true
	if com >= 6:
		found["jangmadang"] = true # 저잣거리 가게가 여럿 들어선 장마당
	for pid: String in found:
		unlock_puzzle_piece("buildings", pid)

## 살피기: 지도에 나타난 네임드 인물(등용 인재) — 이때만 [역사 인물] 조각이 맞춰진다
static func on_inspect_named(named_id: String) -> void:
	if named_id == "baek_dongsoo":
		named_id = "baek_dongsu"
	unlock_puzzle_piece("people", named_id)

## 살피기: 보행 에이전트(type)
static func on_inspect_agent(a_type: String) -> void:
	match a_type:
		"farmer", "ox_plow", "farmer_cart":
			unlock_puzzle_piece("life", "farmer_ox")
		"mason", "geojunggi", "nongno", "yuheonggeo", "foreman":
			unlock_puzzle_piece("life", "mason")
		"artisan", "artisan_master":
			unlock_puzzle_piece("life", "smith")
		"bobusang", "book_peddler", "fish_peddler", "salt_porter":
			unlock_puzzle_piece("life", "bobusang")
		"washer":
			unlock_puzzle_piece("life", "washer")
		"catholic":
			unlock_puzzle_piece("life", "catholic")
		"posu", "sasu", "salsu", "gipo", "chakhogapsa", "saposu", "militia":
			unlock_puzzle_piece("life", "jangyong_drill")
		"horse_messenger":
			unlock_puzzle_piece("life", "pabal")
		"official_rider", "palanquin", "gov_cart":
			unlock_puzzle_piece("life", "wonhaeng")
		"pungmul_band":
			unlock_puzzle_piece("life", "namsadang")
		"bull_parade":
			unlock_puzzle_piece("life", "ssireum_parade")

## 살피기: 세시풍속·민속놀이 장면(ACTIVITY_*)
static func on_inspect_activity(act: String) -> void:
	match act:
		"ACTIVITY_JWIBULNORI":
			unlock_puzzle_piece("life", "jwibul")
		"ACTIVITY_SEOKJEON":
			unlock_puzzle_piece("life", "seokjeon")
		"ACTIVITY_KITE_FLYING":
			unlock_puzzle_piece("life", "kite")
		"ACTIVITY_SSIREUM", "ACTIVITY_SSIREUM_CHAMPION":
			unlock_puzzle_piece("life", "ssireum_parade")
		"ACTIVITY_GANGGANGSULLAE":
			unlock_puzzle_piece("life", "ganggang")
		"ACTIVITY_LION_DANCE":
			unlock_puzzle_piece("life", "lion_dance")
		"ACTIVITY_NEOLTTWIGI":
			unlock_puzzle_piece("life", "neolttwigi")
		"ACTIVITY_SWINGING":
			unlock_puzzle_piece("life", "swing")
		"ACTIVITY_YARD_GAMES":
			unlock_puzzle_piece("life", "yard_games")
		"ACTIVITY_NAMSADANG", "ACTIVITY_PUNGMUL":
			unlock_puzzle_piece("life", "namsadang")
		"ACTIVITY_JEONJISU":
			unlock_puzzle_piece("life", "jeongisu")
