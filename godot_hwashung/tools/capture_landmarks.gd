extends SceneTree

## 개편 건물(정부청사·경찰서·소방서·복지관·대학교·초중등학교·호수공원·군사기지·공화정 행궁) 지도 그림 확인용 캡처.
## 실행: Godot --path godot_hwashung --resolution 1600x900 --script res://tools/capture_landmarks.gd -- <저장 파일 경로> <저장폴더> [줌]
## 저장 파일은 읽기만 한다(근대화·개편은 저장 없이 상태만 켜서 찍는다). 건물마다 개편 전/후 한 장씩.

const TARGETS := [
	["gwana", "building"], ["patrol", "building"], ["firefighter", "building"], ["jinhulso", "building"],
	["hyanggyo", "building"], ["seodang", "plaza"], ["seowon", "plaza"], ["maegok_seowon", "plaza"],
	["chukmanje", "building"], ["manseokgeo", "building"], ["yeonmudae", "building"], ["haenggung", "building"],
]

func _init() -> void:
	call_deferred("_run")

func _wait(n: int) -> void:
	for i in range(n):
		await process_frame

func _shot(path: String, frames: int) -> void:
	await _wait(frames)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("captured ", path)

func _find(g: GameGrid, key: String, kind: String) -> Vector2i:
	for y in range(g.size):
		for x in range(g.size):
			var t: Dictionary = g.grid[y][x]
			if kind == "building":
				var b := String(t.get("building", ""))
				if b == key or (b == key + "_site" and t.get("site_anchor", Vector2i(-1, -1)) == Vector2i(x, y)):
					return Vector2i(x, y)
			elif t.has("plaza") and String((t["plaza"] as Dictionary).get("kind", "")) == key:
				var pl: Dictionary = t["plaza"]
				var n := int(pl["n"])
				return Vector2i(int(pl["x0"]) + n / 2, int(pl["y0"]) + n / 2)
	return Vector2i(-1, -1)

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var save_path: String = args[0]
	var out_dir: String = args[1]
	var zoom: float = float(args[2]) if args.size() > 2 else 1.4
	var only: String = args[3] if args.size() > 3 else "" # 이 건물만 찍기(예: firefighter)
	var no_people: bool = args.size() > 4 and args[4] == "nopeople" # 사람 레이어 숨기기(구운 지도만)
	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _wait(10)
	if main.intro_layer:
		main.intro_layer.intro_finished.emit()
		main._on_intro_finished()
	await _wait(5)
	main._on_start_new_game()
	await _wait(30)
	if not SaveSystem.load_game_from_path(save_path, main.simulation_core, main.grid, main.time_manager, main.quests):
		print("load failed")
		quit(1)
		return
	main.on_game_loaded()
	main.time_manager.set_speed(TimeManager.SpeedMode.PAUSE)
	await _wait(60)
	for cl: Node in root.find_children("*", "CanvasLayer", true, false):
		(cl as CanvasLayer).visible = false
	var g: GameGrid = main.grid
	if no_people and main.citizen_layer:
		main.citizen_layer.visible = false
	main.camera.zoom = Vector2(zoom, zoom)

	var spots := {}
	for tg in TARGETS:
		var p := _find(g, String(tg[0]), String(tg[1]))
		print("found ", tg[0], " ", p)
		if p.x >= 0 and (only == "" or only == String(tg[0])):
			spots[String(tg[0])] = p

	var mm: ModernizationManager = ModernizationManager.instance
	var um: UrbanEvolutionManager = UrbanEvolutionManager.instance
	mm.active = true
	um.stone_ratio = 1.0
	um.metro_ratio = 0.3
	um.apply_modern_tiles()
	await _wait(300)
	for k in spots:
		main.camera.global_position = main.city.cell_center(spots[k].x, spots[k].y, 1.0) + main.city.global_position
		await _shot(out_dir.path_join("lm_%s_0_before.png" % k), 20)

	for id in UrbanEvolutionManager.CIVIC_UPGRADES:
		um.civic_upgrades[id] = true
	for id in UrbanEvolutionManager.LAKE_PARKS:
		um.lake_parks[id] = true
	um.military_base = true
	um.haenggung_republic = true
	um.apply_landmark_tiles()
	var n := 0
	for y in range(g.size):
		for x in range(g.size):
			if g.grid[y][x].has("lm_modern"):
				n += 1
	print("landmark tiles ", n)
	await _wait(300)
	for k in spots:
		main.camera.global_position = main.city.cell_center(spots[k].x, spots[k].y, 1.0) + main.city.global_position
		await _shot(out_dir.path_join("lm_%s_1_after.png" % k), 20)
	quit(0)
