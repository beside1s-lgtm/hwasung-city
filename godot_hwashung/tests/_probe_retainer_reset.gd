extends SceneTree
# 진단용(내보내기 제외: tests/_probe_*): slot_3을 불러와 3명 해임 후 달을 넘기며 등용 인재가 언제·왜 사라지는지 추적
# 실행: Godot --headless --path godot_hwashung -s res://tests/_probe_retainer_reset.gd

var _prev: Dictionary = {}
var sim: SimulationCore
var court: CourtSystem

func _hired() -> Array:
	var out: Array = []
	for k in sim.retainers.keys():
		if bool(sim.retainers[k]):
			out.append(k)
	out.sort()
	return out

func _check(tag: String) -> void:
	var lost: Array = []
	for k in _prev.keys():
		if bool(_prev[k]) and not bool(sim.retainers.get(k, false)):
			lost.append(k)
	var h := _hired()
	print("[%s] 등용 %d명 | 국고 %d | 학문력 %d | 왕권 %d%s" % [tag, h.size(), sim.gold, sim.academic, sim.authority, ("  ▶ 사라짐: " + str(lost)) if not lost.is_empty() else ""])
	_prev = sim.retainers.duplicate()

func _quiet() -> void:
	var lost: Array = []
	for k in _prev.keys():
		if bool(_prev[k]) and not bool(sim.retainers.get(k, false)):
			lost.append(k)
	if not lost.is_empty():
		_check("변화")

func _init() -> void:
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	for i in range(5):
		await process_frame
	sim = main.simulation_core
	court = main.court
	court.notice.connect(func(m: String):
		if not m.begins_with("저잣거리 가게"):
			print("    (알림) ", m))

	var ok: bool = main._load_from_title(3)
	print("slot_3 불러오기: ", ok, "  ", sim.current_year, "년 turn ", sim.turn)
	_prev = sim.retainers.duplicate()
	_check("불러온 직후")
	print("    등용 명단: ", _hired())
	for i in range(30):
		await process_frame
	_check("30프레임 뒤")

	for sid: String in ["jeong_beomjo", "yu", "musoe"]:
		print("    해임: ", court.dismiss_scholar(sid))
		_check("해임 " + sid)
	for i in range(30):
		await process_frame
	_check("해임 후 30프레임")

	for m in range(1, 41):
		main.turns._on_turn(sim.turn + 1, (m / 3) % 4, sim.current_year)
		for f in range(40):
			await process_frame
		if m % 6 == 0:
			_check("%d달 뒤" % m)
		else:
			_quiet()
	print("남은 명단: ", _hired())
	quit()
