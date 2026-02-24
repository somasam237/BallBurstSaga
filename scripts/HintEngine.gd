extends RefCounted
class_name HintEngine

static func find_classic_hint(kind_grid: Array, width: int, height: int) -> Dictionary:
	for y in range(height):
		for x in range(width):
			if x + 1 < width and _swap_score(kind_grid, x, y, x + 1, y) > 0:
				return {"x1": x, "y1": y, "x2": x + 1, "y2": y}
			if y + 1 < height and _swap_score(kind_grid, x, y, x, y + 1) > 0:
				return {"x1": x, "y1": y, "x2": x, "y2": y + 1}
	return {}

static func find_best_hint(kind_grid: Array, width: int, height: int) -> Dictionary:
	var best := {}
	var best_score := 0

	for y in range(height):
		for x in range(width):
			if x + 1 < width:
				var score_h := _swap_score(kind_grid, x, y, x + 1, y)
				if score_h > best_score:
					best_score = score_h
					best = {"x1": x, "y1": y, "x2": x + 1, "y2": y, "score": score_h}
			if y + 1 < height:
				var score_v := _swap_score(kind_grid, x, y, x, y + 1)
				if score_v > best_score:
					best_score = score_v
					best = {"x1": x, "y1": y, "x2": x, "y2": y + 1, "score": score_v}

	return best

static func _swap_score(kind_grid: Array, x1: int, y1: int, x2: int, y2: int) -> int:
	var test_grid := _copy_grid(kind_grid, kind_grid.size(), kind_grid[0].size())
	var temp: int = int(test_grid[x1][y1])
	test_grid[x1][y1] = test_grid[x2][y2]
	test_grid[x2][y2] = temp
	return _count_matches(test_grid, test_grid.size(), test_grid[0].size())

static func _copy_grid(kind_grid: Array, width: int, height: int) -> Array:
	var out: Array = []
	for x in range(width):
		var col: Array = []
		for y in range(height):
			col.append(kind_grid[x][y])
		out.append(col)
	return out

static func _count_matches(kind_grid: Array, width: int, height: int) -> int:
	var matched := {}

	for y in range(height):
		var run_kind := -1
		var run: Array = []
		for x in range(width):
			var k: int = int(kind_grid[x][y])
			if k == run_kind:
				run.append(Vector2i(x, y))
			else:
				if run.size() >= 3:
					for p in run:
						matched[p] = true
				run_kind = k
				run = [Vector2i(x, y)]
		if run.size() >= 3:
			for p2 in run:
				matched[p2] = true

	for x in range(width):
		var run_kind2 := -1
		var run2: Array = []
		for y in range(height):
			var k2: int = int(kind_grid[x][y])
			if k2 == run_kind2:
				run2.append(Vector2i(x, y))
			else:
				if run2.size() >= 3:
					for p3 in run2:
						matched[p3] = true
				run_kind2 = k2
				run2 = [Vector2i(x, y)]
		if run2.size() >= 3:
			for p4 in run2:
				matched[p4] = true

	return matched.size()
