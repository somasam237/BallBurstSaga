extends Node
class_name AIAdvisor

# Evaluates the best swap on the board using a simple heuristic:
# - prefer swaps that create larger matches
# - prefer swaps that trigger cascades (simulated cheaply)
# This is classic game AI (rule-based), not ML.

func best_move(board: Board) -> Dictionary:
	var best := {"score": -1, "a": null, "b": null}

	for y in range(board.height):
		for x in range(board.width):
			var p: Piece = board.grid[x][y]
			if p == null:
				continue

			# test right neighbor
			if x + 1 < board.width:
				var q: Piece = board.grid[x + 1][y]
				if q != null:
					var s := _score_swap(board, p, q)
					if s > best["score"]:
						best = {"score": s, "a": p, "b": q}

			# test down neighbor
			if y + 1 < board.height:
				var r: Piece = board.grid[x][y + 1]
				if r != null:
					var s2 := _score_swap(board, p, r)
					if s2 > best["score"]:
						best = {"score": s2, "a": p, "b": r}

	if best["a"] == null:
		return {}
	return best

func _score_swap(board: Board, a: Piece, b: Piece) -> int:
	# Virtual swap in grid (no animations)
	board._virtual_swap(a, b)
	var matches := board._find_all_matches()
	var base := matches.size()
	# revert
	board._virtual_swap(a, b)

	if base <= 0:
		return -1

	# Heuristic: bigger matches are better, and central moves slightly better
	var center_bonus := 0
	var cx := board.width / 2.0
	var cy := board.height / 2.0
	center_bonus = int(10 - (abs(a.grid_x - cx) + abs(a.grid_y - cy)))

	return base * 100 + center_bonus
