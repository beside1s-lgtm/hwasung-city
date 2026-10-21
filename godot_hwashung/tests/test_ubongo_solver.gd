extends SceneTree

const PresetsClass = preload("res://scripts/minigames/UbongoPuzzlePresets.gd")

func _init() -> void:
	call_deferred("_solve_all")

func _solve_all() -> void:
	print("Checking solvability of 3-piece puzzles...")
	for i in range(PresetsClass.PUZZLES_3_PIECES.size()):
		var p: Dictionary = PresetsClass.PUZZLES_3_PIECES[i]
		var sol := solve_puzzle(p)
		if not sol:
			print("FAIL 3P_", i+1, " id=", p.id)
	print("Checking solvability of 4-piece puzzles...")
	for i in range(PresetsClass.PUZZLES_4_PIECES.size()):
		var p: Dictionary = PresetsClass.PUZZLES_4_PIECES[i]
		var sol := solve_puzzle(p)
		if not sol:
			print("FAIL 4P_", i+1, " id=", p.id)
	print("Checking solvability of 5-piece puzzles...")
	for i in range(PresetsClass.PUZZLES_5_PIECES.size()):
		var p: Dictionary = PresetsClass.PUZZLES_5_PIECES[i]
		var sol := solve_puzzle(p)
		if not sol:
			print("FAIL 5P_", i+1, " id=", p.id)
	print("All checks completed!")
	quit(0)

func get_rotations(shape: Array) -> Array:
	var res := []
	var cur := shape
	for r in range(4):
		if not has_shape(res, cur):
			res.append(cur)
		cur = rot90(cur)
	var flipped := flip_h(shape)
	cur = flipped
	for r in range(4):
		if not has_shape(res, cur):
			res.append(cur)
		cur = rot90(cur)
	return res

func has_shape(arr: Array, s: Array) -> bool:
	for existing in arr:
		if same_shape(existing, s):
			return true
	return false

func same_shape(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for r in range(a.size()):
		if (a[r] as Array).size() != (b[r] as Array).size():
			return false
		for c in range((a[r] as Array).size()):
			if a[r][c] != b[r][c]:
				return false
	return true

func rot90(s: Array) -> Array:
	var h: int = s.size()
	var w: int = (s[0] as Array).size()
	var out := []
	for c in range(w):
		var row := []
		for r in range(h - 1, -1, -1):
			row.append(s[r][c])
		out.append(row)
	return out

func flip_h(s: Array) -> Array:
	var out := []
	for r in range(s.size()):
		var row := []
		var w: int = (s[r] as Array).size()
		for c in range(w - 1, -1, -1):
			row.append(s[r][c])
		out.append(row)
	return out

func solve_puzzle(p: Dictionary) -> bool:
	var pieces: Array = p.pieces
	var mask: Array = p.target_mask
	var h: int = mask.size()
	var w: int = (mask[0] as Array).size()
	var grid := []
	for r in range(h):
		var row := []
		for c in range(w):
			row.append(0)
		grid.append(row)
	
	var piece_rots := []
	for pid in pieces:
		var base_s: Array = PresetsClass.PIECE_SHAPES[pid]
		piece_rots.append(get_rotations(base_s))
	
	return backtrack(0, pieces, piece_rots, mask, grid, h, w)

func backtrack(idx: int, pieces: Array, piece_rots: Array, mask: Array, grid: Array, h: int, w: int) -> bool:
	if idx >= pieces.size():
		return true
	var rots: Array = piece_rots[idx]
	var pid: int = pieces[idx]
	for shape in rots:
		var sh: int = shape.size()
		var sw: int = (shape[0] as Array).size()
		for tr in range(h - sh + 1):
			for tc in range(w - sw + 1):
				if can_place(shape, tr, tc, mask, grid, h, w):
					place(shape, tr, tc, grid, pid)
					if backtrack(idx + 1, pieces, piece_rots, mask, grid, h, w):
						return true
					unplace(shape, tr, tc, grid)
	return false

func can_place(shape: Array, tr: int, tc: int, mask: Array, grid: Array, h: int, w: int) -> bool:
	for r in range(shape.size()):
		for c in range((shape[r] as Array).size()):
			if shape[r][c] == 1:
				if tr + r >= h or tc + c >= w:
					return false
				if mask[tr + r][tc + c] != 1:
					return false
				if grid[tr + r][tc + c] != 0:
					return false
	return true

func place(shape: Array, tr: int, tc: int, grid: Array, pid: int) -> void:
	for r in range(shape.size()):
		for c in range((shape[r] as Array).size()):
			if shape[r][c] == 1:
				grid[tr + r][tc + c] = pid

func unplace(shape: Array, tr: int, tc: int, grid: Array) -> void:
	for r in range(shape.size()):
		for c in range((shape[r] as Array).size()):
			if shape[r][c] == 1:
				grid[tr + r][tc + c] = 0
