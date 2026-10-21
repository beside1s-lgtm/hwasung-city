extends RefCounted
class_name StreetLife
## PORT-TRACE [거리 사람들의 정체성]: 사용자 — "시민들이 고유의 정체성을 가지고 행동과 말을 해야 한다. 취객은 주정을 부리고
## 쓰러져 부축을 받아 집으로 가거나 왈패의 폭력·소매치기의 표적이 되고, 노인은 아이와 짝지어 대화하고 도움을 주고받으며,
## 여성은 여성의 말씨, 신분·직업마다 맞는 말투를 써야 한다."
## - 취객(drunkard): 주막 앞에서 나와 비틀비틀 집으로. 주정을 부리다 가끔 길에 쓰러지면 근처 집에서 이웃(남·녀)이 나와
##   일으켜 부축해 집까지 데려다준다. 소매치기의 표적(StreetLife.theft_target)이 되기도 한다.
## - 노인과 아이: 할아버지·할머니가 손주와 나란히 걸으며 말을 주고받고(옛이야기·길 조심·엿), 아이는 짐을 들어 드리거나 부축한다.
## - 길손(일반 보행자): 성별·나이·신분에 맞는 혼잣말·인사(가끔).
## - 살피기 팝업: activity_of()가 지금 하는 일을 한 줄로(InspectNarrativeGenerator가 붙여 보여 줌).

const MAX_DRUNK := 2
const MAX_PAIRS := 2
static var _timer := 0.0

const L := {
	"drunk_walk": ["끄윽~ 주모, 한 잔만 더!", "달이 두 개로구나, 허허허… 딸꾹!", "내가 왕년에 말이여~ 성돌을 번쩍번쩍!", "외상이오, 외상! 내일 갚는다니까!", "집이… 이쪽이던가, 저쪽이던가?", "세상만사 다 술 한 잔이면 그만이여~"],
	"drunk_fall": ["어이쿠… 땅이 벌떡 일어나네…", "에구구, 여기서 한숨 자고 가세… 쿨…", "아이고, 다리가 내 말을 안 듣는구먼…"],
	"drunk_helped": ["놔, 놔라… 나 하나도 안 취했어!", "자네가 제일이여… 딸꾹…", "집사람한테는… 비밀이오, 알았지?"],
	"drunk_home": ["다녀왔소오~ 딸꾹!", "쉿… 조용히 들어가야지…"],
	"drunk_robbed": ["어라? 내 엽전 꾸러미 어디 갔어? 딸꾹!", "아이고, 술값이 몽땅 없어졌네!"],
	"helper_m": ["어허, 이 사람아! 또 이 지경인가. 일어나게.", "내 어깨에 기대게, 집까지 데려다줌세.", "어이쿠, 무겁기도 하지. 술을 좀 줄이게나."],
	"helper_f": ["아이고 이 양반아, 또 곤드레만드레가 되셨구려!", "남부끄러워라… 어서 일어나 집에 가십시다.", "에그머니, 길바닥에서 이게 무슨 꼴이래요."],
	"elder_m": ["얘야, 길 건널 땐 좌우를 잘 살피거라.", "옛날 옛적, 호랑이 담배 먹던 시절에 말이다…", "이 할애비가 엿 하나 사 주마.", "글은 하루라도 거르면 안 되느니라.", "허허, 우리 손주 다리가 제법 튼튼하구나."],
	"elder_f": ["아가, 넘어질라. 천천히 가자꾸나.", "우리 강아지, 배고프지 않으냐?", "할미가 집에 가서 떡 쪄 주마.", "에그, 옷고름 풀렸다. 이리 오너라."],
	"child_m": ["할아버지, 그 보따리 제가 들게요!", "할아버지, 저건 무슨 새예요?", "할아버지 손 꼭 잡을게요!", "호랑이 얘기 또 해 주세요!"],
	"child_f": ["할머니, 천천히 오세요!", "할머니, 제가 부축해 드릴게요.", "할머니 떡은 세상에서 제일 맛있어요!", "할머니, 저 꽃 좀 보세요!"],
	"rest_m": ["에구, 허리야. 좀 쉬었다 가자꾸나.", "얘야, 이 할애비 숨 좀 돌리자."],
	"rest_child_m": ["할아버지, 여기 앉으세요. 제가 다리 주물러 드릴게요.", "할아버지, 제 어깨 짚으세요!"],
	"rest_child_f": ["할머니, 여기 앉으세요. 제가 다리 주물러 드릴게요.", "할머니, 제 어깨 짚으세요!"],
	"woman": ["오늘 장에 갈치가 싸다지요?", "아이고, 빨래 걷어야 하는데 큰일이네.", "얘, 저 비단 고운 것 좀 보구려.", "날씨 한번 좋기도 하네요.", "우리 집 양반은 또 주막에 갔나 봐요.", "애들 저녁밥 지으러 서둘러 가야지요."],
	"lady": ["얘, 서두르지 말거라. 체면이 있느니라.", "곱게 수놓은 보자기를 사 가야겠구나.", "규방 일이 많아 걸음이 바쁘구나."],
	"man": ["올해 농사는 잘될 것 같구먼.", "장에 소 한 마리 팔러 가는 길이여.", "허허, 날씨 좋다!", "품삯 받았으니 막걸리 한 사발 해야지.", "성 쌓는 일에 품 팔러 가세."],
	"yangban": ["에헴! 길을 비키거라.", "오늘은 향교에 들러 글을 읽어야겠군.", "세상이 어수선할수록 몸가짐을 바로 해야지.", "허허, 고을 인심이 넉넉하구먼."],
	"elder_alone_m": ["에구, 허리야… 나이는 못 속이는구먼.", "젊을 땐 성돌도 번쩍 들었는데 말이여.", "손주 놈 엿 사다 줘야지."],
	"elder_alone_f": ["아이고, 다리야. 쑤시는구먼.", "손주 보러 가는 길이라오.", "장에 가서 참기름 한 병 사야지."],
	"child": ["같이 놀자~!", "엄마가 일찍 들어오랬는데…", "술래잡기 할 사람 여기 붙어라!", "엿장수다, 엿장수 온다!"],
}

static func _pick(key: String) -> String:
	var arr: Array = L[key]
	return String(arr[randi() % arr.size()])

static func _say(a: Dictionary, text: String, sec: float = 3.2) -> void:
	a["bubble_text"] = text
	a["bubble_timer"] = sec
	a["last_line"] = text

# ---------------------------------------------------------------- 스폰
static func update(cm: CitizenManager, delta: float) -> void:
	_timer += delta
	if _timer < 3.0:
		return
	_timer = 0.0
	if cm._roads_set.is_empty() or cm._res_cache.is_empty():
		return
	var n_drunk := 0
	var n_pair := 0
	for a: Dictionary in cm.agents:
		match String(a.get("sl_role", "")):
			"drunk":
				n_drunk += 1
			"elder":
				n_pair += 1
	if n_drunk < MAX_DRUNK and randf() < 0.3:
		_spawn_drunk(cm)
	if n_pair < MAX_PAIRS and randf() < 0.3:
		_spawn_pair(cm)

static func _new_agent(cm: CitizenManager, type: String, tile: Vector2i, role: String) -> Dictionary:
	var ag := {"id": cm._next_agent_id, "type": type, "x": float(tile.x) + 0.5, "y": float(tile.y) + 0.5,
		"from_tile": tile, "to_tile": tile, "progress": 1.0, "dir": Vector2.RIGHT, "speed": 0.5, "anim": randf() * 4.0,
		"state": "walk", "state_timer": 0.0, "bubble_text": "", "bubble_timer": 0.0, "extra": {}, "is_dead": false,
		"street_folk": true, "sl_role": role, "talk_t": randf_range(2.0, 5.0)}
	cm._next_agent_id += 1
	cm.agents.append(ag)
	return ag

static func _home_tile(cm: CitizenManager) -> Vector2i:
	return cm._res_cache[randi() % cm._res_cache.size()]

static func _spawn_drunk(cm: CitizenManager) -> void:
	# 주막·국밥집 앞에서 나온다(없으면 아무 가게 앞, 그것도 없으면 아무 집 앞) — 길에 닿은 곳만
	var taverns: Array[Vector2i] = []
	var shops: Array[Vector2i] = cm._shop_cache.duplicate()
	shops.shuffle()
	for sp: Vector2i in shops:
		if cm._trade_at(sp) in ["jumak", "gukbap"]:
			taverns.append(sp)
	var start := Vector2i(-1, -1)
	for cand: Vector2i in taverns + shops:
		var fr := cm._front_road_of(cand)
		if cm._roads_set.has(fr):
			start = fr
			break
	if start.x < 0:
		return
	var home := _home_tile(cm)
	var d := _new_agent(cm, "drunkard", start, "drunk")
	d["state"] = "stagger"
	d["speed"] = 0.32
	d["extra"] = {"home": home}
	d["activity_desc"] = "주막에서 거나하게 마시고 비틀비틀 집으로 가는 중"
	_say(d, _pick("drunk_walk"))

static func _spawn_pair(cm: CitizenManager) -> void:
	var start := Vector2i(-1, -1)
	for k in range(10):
		var fr := cm._front_road_of(_home_tile(cm))
		if cm._roads_set.has(fr):
			start = fr
			break
	if start.x < 0:
		return
	var goal: Vector2i = cm._market_plaza_cache[randi() % cm._market_plaza_cache.size()] if (not cm._market_plaza_cache.is_empty() and randf() < 0.6) else _home_tile(cm)
	var male := randf() < 0.5
	var e := _new_agent(cm, "elder_m" if male else "elder_f", start, "elder")
	e["speed"] = 0.33
	e["extra"] = {"goal": goal}
	e["activity_desc"] = ("할아버지가" if male else "할머니가") + " 손주 손을 잡고 " + ("장 구경 가는 길" if cm._market_plaza_cache.has(goal) else "이웃집 마실 가는 길")
	var boy := randf() < 0.5
	var c := _new_agent(cm, "child_m" if boy else "child_f", start, "child")
	c["extra"] = {"partner": int(e["id"])}
	c["activity_desc"] = ("할아버지" if male else "할머니") + "를 모시고 나란히 걷는 손주"
	(e["extra"] as Dictionary)["partner"] = int(c["id"])
	_say(e, _pick("elder_m" if male else "elder_f"))

# ---------------------------------------------------------------- 갱신
static func _find(cm: CitizenManager, id: int) -> Dictionary:
	for a: Dictionary in cm.agents:
		if int(a.get("id", -1)) == id and not a.get("is_dead", false):
			return a
	return {}

static func _arrived(cm: CitizenManager, a: Dictionary, goal_t: Vector2i) -> bool:
	var cur := Vector2(float(a["x"]), float(a["y"]))
	if cur.distance_to(Vector2(goal_t) + Vector2(0.5, 0.5)) < 0.5:
		return true
	return cm._entry_for(goal_t) == Vector2i(int(floor(cur.x)), int(floor(cur.y)))

static func update_agent(cm: CitizenManager, a: Dictionary, delta: float) -> void:
	a["talk_t"] = float(a.get("talk_t", 0.0)) - delta
	match String(a.get("sl_role", "")):
		"drunk":
			_upd_drunk(cm, a, delta)
		"helper":
			_upd_helper(cm, a, delta)
		"elder":
			_upd_elder(cm, a, delta)
		"child":
			_upd_child(cm, a, delta)
		"rescuer":
			# 구조를 마치면(state "walk") 잠시 숨을 고르고 집으로(사라짐)
			a["state_timer"] = float(a.get("state_timer", 0.0)) + delta
			if float(a["state_timer"]) > 4.0:
				a["is_dead"] = true
		_:
			a["is_dead"] = true

static func _upd_drunk(cm: CitizenManager, a: Dictionary, delta: float) -> void:
	var ex: Dictionary = a["extra"]
	var home: Vector2i = ex.get("home", Vector2i.ZERO)
	a["age"] = float(a.get("age", 0.0)) + delta
	if float(a["age"]) > 150.0:
		a["is_dead"] = true # 길이 끊겨 못 가면 오래 머물지 않는다
		return
	match String(a.get("state", "")):
		"stagger":
			if _arrived(cm, a, home):
				_say(a, _pick("drunk_home"))
				a["is_dead"] = true
				return
			var sp := 0.18 + 0.22 * absf(sin(float(a["anim"]) * 0.35)) # 갈지자: 빨랐다 느렸다
			cm._move_agent_towards(a, Vector2(home) + Vector2(0.5, 0.5), delta, sp)
			if float(a["talk_t"]) <= 0.0 and float(a.get("bubble_timer", 0.0)) <= 0.0:
				_say(a, _pick("drunk_walk"))
				a["talk_t"] = randf_range(6.0, 10.0)
			if randf() < delta * 0.035 and float(a["age"]) > 8.0 and not ex.has("fell"):
				ex["fell"] = true
				a["state"] = "fallen"
				a["state_timer"] = 28.0
				a["activity_desc"] = "술에 곯아떨어져 길바닥에 쓰러져 있음 — 이웃이 부축하러 오는 중"
				_say(a, _pick("drunk_fall"), 3.5)
				_call_helper(cm, a)
		"fallen":
			a["state_timer"] = float(a["state_timer"]) - delta
			if float(a["state_timer"]) <= 0.0:
				a["state"] = "stagger" # 아무도 안 오면 스스로 일어나 다시 비틀
				a["activity_desc"] = "겨우 일어나 다시 비틀비틀 집으로 가는 중"
				_say(a, "에구구… 일어나야지… 딸꾹.")
		"helped":
			if _arrived(cm, a, home):
				_say(a, _pick("drunk_home"))
				a["is_dead"] = true
				var hp := _find(cm, int(ex.get("helper", -1)))
				if not hp.is_empty():
					_say(hp, "다 왔소. 이제 들어가 푹 주무시오.")
					hp["is_dead"] = true
				return
			cm._move_agent_towards(a, Vector2(home) + Vector2(0.5, 0.5), delta, 0.26)
			if float(a["talk_t"]) <= 0.0 and float(a.get("bubble_timer", 0.0)) <= 0.0:
				_say(a, _pick("drunk_helped"))
				a["talk_t"] = randf_range(7.0, 11.0)

static func _call_helper(cm: CitizenManager, d: Dictionary) -> void:
	# 가까운 집에서 이웃이 나온다
	var cur := Vector2i(int(floor(float(d["x"]))), int(floor(float(d["y"]))))
	var start := Vector2i(-1, -1)
	var bd := 1e9
	for h: Vector2i in cm._res_cache:
		var dd := float(absi(h.x - cur.x) + absi(h.y - cur.y))
		if dd < bd and dd >= 2.0 and dd <= 14.0:
			var fr := cm._front_road_of(h)
			if cm._roads_set.has(fr):
				bd = dd
				start = fr
	if start.x < 0:
		# 가까운 집이 없으면 지나가던 길손이 — 쓰러진 곳에서 몇 칸 떨어진 길에서
		for r in range(3, 7):
			for dv: Vector2i in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r)]:
				if start.x < 0 and cm._roads_set.has(cur + dv):
					start = cur + dv
	if start.x < 0:
		return
	var female := randf() < 0.5
	var hp := _new_agent(cm, "helper_f" if female else "helper_m", start, "helper")
	hp["state"] = "come"
	hp["speed"] = 0.85
	hp["extra"] = {"target": int(d["id"])}
	hp["activity_desc"] = "길에 쓰러진 취객을 일으키러 달려가는 " + ("아낙" if female else "이웃 사내")
	(d["extra"] as Dictionary)["helper"] = int(hp["id"])

static func _upd_helper(cm: CitizenManager, a: Dictionary, delta: float) -> void:
	var d := _find(cm, int((a["extra"] as Dictionary).get("target", -1)))
	if d.is_empty():
		a["is_dead"] = true
		return
	var dp := Vector2(float(d["x"]), float(d["y"]))
	var female := String(a["type"]) == "helper_f"
	match String(a.get("state", "")):
		"come":
			var cur := Vector2(float(a["x"]), float(a["y"]))
			if cur.distance_to(dp) < 0.55:
				a["state"] = "support"
				d["state"] = "helped"
				d["activity_desc"] = "이웃의 부축을 받아 집으로 가는 취객"
				a["activity_desc"] = "취객을 부축해 집까지 데려다주는 " + ("아낙" if female else "이웃 사내")
				_say(a, _pick("helper_f" if female else "helper_m"), 3.5)
				d["talk_t"] = 2.5
			elif String(d.get("state", "")) != "fallen":
				a["is_dead"] = true # 취객이 혼자 일어나 가 버림
			else:
				cm._move_agent_towards(a, dp, delta, 0.85)
		"support":
			# 취객 옆(진행 방향의 오른쪽)에 붙어 같이 걷는다
			var dv: Vector2 = d.get("dir", Vector2.RIGHT)
			var side := Vector2(-dv.y, dv.x).normalized() * 0.3
			a["x"] = dp.x + side.x
			a["y"] = dp.y + side.y
			a["dir"] = dv
			a["anim"] = d.get("anim", 0.0)
			if float(a["talk_t"]) <= 0.0 and float(a.get("bubble_timer", 0.0)) <= 0.0 and float(d.get("bubble_timer", 0.0)) <= 0.0:
				_say(a, _pick("helper_f" if female else "helper_m"))
				a["talk_t"] = randf_range(9.0, 14.0)

static func _upd_elder(cm: CitizenManager, a: Dictionary, delta: float) -> void:
	var ex: Dictionary = a["extra"]
	var goal: Vector2i = ex.get("goal", Vector2i.ZERO)
	var male := String(a["type"]) == "elder_m"
	a["age"] = float(a.get("age", 0.0)) + delta
	var kid := _find(cm, int(ex.get("partner", -1)))
	if _arrived(cm, a, goal) or float(a["age"]) > 160.0 or kid.is_empty():
		a["is_dead"] = true
		if not kid.is_empty():
			kid["is_dead"] = true
		return
	if String(a.get("state", "")) == "rest":
		a["state_timer"] = float(a["state_timer"]) - delta
		if float(a["state_timer"]) <= 0.0:
			a["state"] = "walk"
			_say(a, "허허, 고맙구나. 이제 가자꾸나." if male else "아이고, 우리 강아지 덕에 살았다. 가자꾸나.")
		return
	cm._move_agent_towards(a, Vector2(goal) + Vector2(0.5, 0.5), delta, 0.3)
	if float(a["talk_t"]) <= 0.0 and float(a.get("bubble_timer", 0.0)) <= 0.0 and float(kid.get("bubble_timer", 0.0)) <= 0.0:
		a["talk_t"] = randf_range(9.0, 14.0)
		if randf() < 0.25:
			a["state"] = "rest"
			a["state_timer"] = 4.0
			_say(a, _pick("rest_m") if male else "아이고, 다리야. 좀 쉬었다 가자.")
			kid["reply_t"] = 1.8
			kid["reply"] = _pick("rest_child_m" if male else "rest_child_f")
		else:
			_say(a, _pick("elder_m" if male else "elder_f"))
			kid["reply_t"] = 3.2
			kid["reply"] = _pick("child_m" if male else "child_f")

static func _upd_child(cm: CitizenManager, a: Dictionary, delta: float) -> void:
	var e := _find(cm, int((a["extra"] as Dictionary).get("partner", -1)))
	if e.is_empty():
		a["is_dead"] = true
		return
	# 노인 왼쪽에 붙어 손잡고 걷는다(쉬는 동안엔 노인을 마주 봄)
	var dv: Vector2 = e.get("dir", Vector2.RIGHT)
	var side := Vector2(dv.y, -dv.x).normalized() * 0.28
	a["x"] = float(e["x"]) + side.x
	a["y"] = float(e["y"]) + side.y
	a["dir"] = dv if String(e.get("state", "")) != "rest" else -side
	a["anim"] = float(e.get("anim", 0.0)) * 1.4
	a["state"] = "rest" if String(e.get("state", "")) == "rest" else "walk"
	if a.has("reply_t"):
		a["reply_t"] = float(a["reply_t"]) - delta
		if float(a["reply_t"]) <= 0.0:
			_say(a, String(a.get("reply", "")))
			a.erase("reply_t")

## 물에 빠진 사람 곁에 걸어 다니는 백성이 없을 때: 물가에서 가장 가까운 길에서 백성이 뛰어온다
static func spawn_rescuer(cm: CitizenManager, bank: Vector2i, target_id: int) -> Dictionary:
	var start := Vector2i(-1, -1)
	var bd := 1e9
	for r in range(1, 9):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := bank + Vector2i(dx, dy)
				if cm._roads_set.has(q):
					var dd := float(absi(dx) + absi(dy))
					if dd < bd:
						bd = dd
						start = q
		if start.x >= 0:
			break
	if start.x < 0:
		start = bank
	var male := randf() < 0.6
	var rs := _new_agent(cm, "helper_m" if male else "helper_f", start, "rescuer")
	rs["state"] = "rescuing"
	rs["rescue_target_id"] = target_id
	rs["rescue_bank_pt"] = bank
	rs["rescue_time"] = 3.5
	rs["activity_desc"] = "물에 빠진 사람을 건지러 물가로 달려가는 " + ("사내" if male else "아낙")
	_say(rs, "사람 살려! 내가 가오!" if male else "에그머니, 사람이 빠졌네! 내가 갈게요!", 2.5)
	return rs

# ---------------------------------------------------------------- 길손 혼잣말
## 일반 보행자에게 가끔(약 30초에 한 번) 성별·나이·신분에 맞는 한마디
static func chatter(a: Dictionary, delta: float) -> void:
	if float(a.get("bubble_timer", 0.0)) > 0.0 or not bool(a.get("in_view", false)):
		return
	if randf() > delta * 0.033:
		return
	var t := String(a.get("type", ""))
	var key := ""
	if t.begins_with("child"):
		key = "child"
	elif t.begins_with("elder"):
		key = "elder_alone_f" if (t.ends_with("_f") or t.ends_with("female")) else "elder_alone_m"
	elif t == "yangban_female":
		key = "lady"
	elif t == "yangban_male":
		key = "yangban"
	elif t.ends_with("female") or t.ends_with("_f") or t == "lady":
		key = "woman"
	elif t in ["commoner_male", "shopper", "commoner", "farmer", "carrier"] or t.ends_with("male"):
		key = "man"
	if key == "":
		return
	_say(a, _pick(key), 3.0)

# ---------------------------------------------------------------- 소매치기 표적
## 소매치기가 털 곳: 비틀대는 취객(40%) → 집(빈집털이 30%) → 그 밖엔 가게(빈 사전 = 원래대로 가게)
static func theft_target(cm: CitizenManager) -> Dictionary:
	var r := randf()
	if r < 0.4:
		var drunks: Array = cm.agents.filter(func(a: Dictionary) -> bool: return String(a.get("sl_role", "")) == "drunk" and String(a.get("state", "")) == "stagger" and not (a["extra"] as Dictionary).has("robbed"))
		if not drunks.is_empty():
			var d: Dictionary = drunks[randi() % drunks.size()]
			(d["extra"] as Dictionary)["robbed"] = true
			_say(d, _pick("drunk_robbed"), 3.5)
			d["activity_desc"] = "소매치기에게 엽전 꾸러미를 털린 취객"
			return {"tile": Vector2i(int(floor(float(d["x"]))), int(floor(float(d["y"])))), "kind": "drunk"}
	if r < 0.7 and not cm._res_cache.is_empty():
		var h: Vector2i = cm._res_cache[randi() % cm._res_cache.size()]
		return {"tile": h, "kind": "house"}
	return {}

# ---------------------------------------------------------------- 살피기: 지금 하는 일
const ACT_BY_TYPE := {
	"shopkeeper": "가게 앞 판매대에서 손님을 부르며 물건을 팔고 있음",
	"artisan": "공방에서 물건을 만들고 있음",
	"porter": "공방 물건을 지게에 지고 가게로 나르는 중",
	"washer": "수원천 빨래터에서 방망이질하는 중",
	"fisher": "물가 바위에 앉아 낚싯대를 드리운 중",
	"farmer": "논밭을 돌보는 중",
	"ox_plow": "소에 쟁기를 매어 논을 가는 중",
	"farmer_cart": "수레에 곡식을 싣고 가는 중",
	"woodcutter": "산에서 나무를 해 지게에 지고 오는 중",
	"hunter": "활을 메고 짐승을 쫓는 사냥꾼",
	"saposu": "조총을 멘 포수 — 산짐승을 쫓는 중",
	"patrol_soldier": "성안을 순찰하는 포졸",
	"horse_messenger": "급한 소식을 싣고 달리는 파발",
	"bobusang": "봇짐을 지고 장터를 오가는 보부상",
	"salt_porter": "서해 소금 짐을 지고 오는 지게꾼",
	"ox_driver": "소를 몰고 쇠전으로 가는 소장수",
	"catholic": "몰래 모여 기도하는 천주교 교우",
}
const PRO_STATE := {"work": "자기 일터에서 일하는 중", "rest": "잠시 숨을 돌리는 중", "travel": "다른 일터로 가는 중", "patrol": "순찰을 도는 중"}

static func activity_of(a: Dictionary) -> String:
	var s := String(a.get("activity_desc", ""))
	if s != "":
		return s
	var t := String(a.get("type", ""))
	if t == "criminal_npc":
		match String(a.get("state", "")):
			"disputing":
				return "행패를 부리는 중" if String(a.get("crime_kind", "")) != "pickpocket" else "남의 물건을 슬쩍하는 중"
			"fleeing", "swagger_home":
				return "장물을 품고 성문 쪽으로 달아나는 중"
			"arrested", "escorted":
				return "포졸에게 붙잡혀 관아로 끌려가는 중"
	if ACT_BY_TYPE.has(t):
		return ACT_BY_TYPE[t]
	if int(a.get("job_type", 0)) != 0:
		return PRO_STATE.get(String(a.get("state", "")), "")
	if bool(a.get("trip", false)):
		return "볼일을 보러 길을 가는 중"
	return ""
