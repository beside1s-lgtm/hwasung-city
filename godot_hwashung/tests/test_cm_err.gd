extends SceneTree
func _init() -> void:
	var s: Variant = ResourceLoader.load("res://scripts/NewspaperSystem.gd", "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	print("LOAD RESULT: ", s)
	quit()
