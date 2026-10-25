extends SceneTree
# 진단용(내보내기 제외: tests/_probe_*): 그림 파일이 없을 때 쓰이는 코드 그림(대체 그림)을 임시 폴더에 PNG로 뽑는다.
# 실행: Godot --headless --path godot_hwashung -s res://tests/_probe_fallback_art.gd -- <출력 폴더>

const SCM = preload("res://scripts/autoload/SpriteCacheManager.gd")

func _init() -> void:
	var out_dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://probe"
	var ids: Array = [["seodang", Vector2i(128, 112)], ["maegok_seowon", Vector2i(192, 160)], ["workshop", Vector2i(64, 72)],
		["ws_2x1_dyeing", Vector2i(96, 88)], ["ws_2x2_ceramics", Vector2i(128, 112)], ["ws_3x3_royal_arsenal", Vector2i(192, 160)],
		["hyanggyo", Vector2i(128, 112)], ["guesthouse", Vector2i(128, 112)], ["unknown_x", Vector2i(128, 112)]]
	for e: Array in ids:
		var img: Image = SCM._create_standard_art_image("buildings", String(e[0]), e[1])
		var p: String = out_dir.path_join(String(e[0]) + ".png")
		print(e[0], " -> ", img.save_png(p), " ", p)
	quit()
