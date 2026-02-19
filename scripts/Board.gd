extends Node2D
class_name Board

signal score_gained(points: int)
signal moves_used(remaining: int)
signal message(text: String)
signal game_over(won: bool)

enum State {
	IDLE,
	SELECTED,
	SWAPPING,
	CHECKING,
	CLEARING,
	GRAVITY,
	REFILL,
	GAME_OVER
}

@export var width: int = 8
@export var height: int = 8
@export var cell_size: int = 64
@export var kinds: int = 6

@export var start_moves: int = 25
@export var target_score: int = 5000

@export var piece_scene: PackedScene = preload("res://scenes/Piece.tscn")

@onready var pieces_layer: Node2D = $Pieces

var state: State = State.IDLE
var grid: Array = [] # grid[x][y] -> Piece or null

var moves_left: int
var score: int

var selected: Piece = null
var swap_a: Piece = null
var swap_b: Piece = null
var hint_timer: Timer
var hint_tween: Tween = null

func _ready() -> void:
	new_game()
	_start_hint_timer()

func _start_hint_timer() -> void:
	hint_timer = Timer.new()
	hint_timer.wait_time = 10.0
	hint_timer.one_shot = false
	hint_timer.autostart = true
	add_child(hint_timer)
	hint_timer.timeout.connect(_on_hint_timer_timeout)

func _on_hint_timer_timeout() -> void:
	if state != State.IDLE:
		return
	_show_hint_swap_animation()

func new_game() -> void:
	_clear_all()
	moves_left = start_moves
	score = 0
	emit_signal("moves_used", moves_left)
	emit_signal("score_gained", 0)
	emit_signal("message", "Match 3+ to score!")

	_init_grid()
	_fill_without_initial_matches()

	state = State.IDLE

func configure(moves: int, target: int) -> void:
	start_moves = moves
	target_score = target

func _clear_all() -> void:
	for c in pieces_layer.get_children():
		c.queue_free()
	grid.clear()
	selected = null
	swap_a = null
	swap_b = null

func _init_grid() -> void:
	grid = []
	for x in width:
		var col := []
		for y in height:
			col.append(null)
		grid.append(col)

func board_to_world(x: int, y: int) -> Vector2:
	return Vector2(x * cell_size + cell_size/2.0, y * cell_size + cell_size/2.0)

func world_to_board(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / cell_size)), int(floor(pos.y / cell_size)))

func _spawn_piece(x: int, y: int, k: int) -> Piece:
	var p: Piece = piece_scene.instantiate()
	pieces_layer.add_child(p)
	p.grid_x = x
	p.grid_y = y
	p.size_px = cell_size
	p.set_kind(k)
	p.position = board_to_world(x, y)
	return p

func _fill_without_initial_matches() -> void:
	for y in height:
		for x in width:
			var k := _random_kind_avoiding_match(x, y)
			var p := _spawn_piece(x, y, k)
			grid[x][y] = p

func _random_kind_avoiding_match(x: int, y: int) -> int:
	var attempts := 0
	while attempts < 50:
		var k := randi() % kinds
		if not _would_make_match(x, y, k):
			return k
		attempts += 1
	return randi() % kinds

func _would_make_match(x: int, y: int, k: int) -> bool:
	# left-left
	if x >= 2:
		var a: Piece = grid[x-1][y]
		var b: Piece = grid[x-2][y]
		if a and b and a.kind == k and b.kind == k:
			return true
	# up-up
	if y >= 2:
		var a2: Piece = grid[x][y-1]
		var b2: Piece = grid[x][y-2]
		if a2 and b2 and a2.kind == k and b2.kind == k:
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if state == State.GAME_OVER:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if state == State.IDLE or state == State.SELECTED:
			_handle_click(get_global_mouse_position())

func _handle_click(global_pos: Vector2) -> void:
	var local_pos := to_local(global_pos)
	var b := world_to_board(local_pos)
	if b.x < 0 or b.x >= width or b.y < 0 or b.y >= height:
		return

	var p: Piece = grid[b.x][b.y]
	if p == null:
		return

	if state == State.IDLE:
		selected = p
		state = State.SELECTED
		_pulse(p)
		return

	# state == SELECTED
	if p == selected:
		selected = null
		state = State.IDLE
		emit_signal("message", "Selection cleared.")
		return

	if _are_adjacent(selected, p):
		if moves_left <= 0:
			emit_signal("message", "No moves left.")
			return
		swap_a = selected
		swap_b = p
		selected = null
		_consume_move()
		_begin_swap()
	else:
		selected = p
		_pulse(p)
		# no selection message

func _consume_move() -> void:
	moves_left -= 1
	emit_signal("moves_used", moves_left)

func _are_adjacent(a: Piece, b: Piece) -> bool:
	return (abs(a.grid_x - b.grid_x) + abs(a.grid_y - b.grid_y)) == 1

func _pulse(p: Piece) -> void:
	var t := create_tween()
	t.tween_property(p, "scale", Vector2(1.08, 1.08), 0.06)
	t.tween_property(p, "scale", Vector2(1, 1), 0.06)

# ---------------- FSM TRANSITIONS ----------------

func _begin_swap() -> void:
	state = State.SWAPPING
	_swap_pieces_in_grid(swap_a, swap_b)
	_animate_to_cell(swap_a)
	_animate_to_cell(swap_b)

	# wait until both reach destination
	await get_tree().create_timer(0.14).timeout
	state = State.CHECKING
	_check_after_swap()

func _check_after_swap() -> void:
	var matches := _find_all_matches()
	if matches.is_empty():
		# revert swap
		emit_signal("message", "No match — reverted.")
		state = State.SWAPPING
		_swap_pieces_in_grid(swap_a, swap_b)
		_animate_to_cell(swap_a)
		_animate_to_cell(swap_b)
		await get_tree().create_timer(0.14).timeout
		swap_a = null
		swap_b = null
		state = State.IDLE
		_check_end()
		return

	# resolve cascades
	await _resolve_loop()
	swap_a = null
	swap_b = null
	state = State.IDLE
	_check_end()

func _swap_pieces_in_grid(a: Piece, b: Piece) -> void:
	var ax := a.grid_x
	var ay := a.grid_y
	var bx := b.grid_x
	var by := b.grid_y

	grid[ax][ay] = b
	grid[bx][by] = a

	a.grid_x = bx; a.grid_y = by
	b.grid_x = ax; b.grid_y = ay

func _animate_to_cell(p: Piece) -> void:
	var t := create_tween()
	t.tween_property(p, "position", board_to_world(p.grid_x, p.grid_y), 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _resolve_loop() -> void:
	while true:
		state = State.CHECKING
		var matches := _find_all_matches()
		if matches.is_empty():
			return

		state = State.CLEARING
		var cleared := matches.size()
		var points := cleared * 100
		score += points
		emit_signal("score_gained", points)
		emit_signal("message", "")
		await _clear_matches(matches)

		state = State.GRAVITY
		await _apply_gravity()

		state = State.REFILL
		await _refill()

		await get_tree().create_timer(0.05).timeout

# ---------------- MATCH / CLEAR / GRAVITY / REFILL ----------------

func _find_all_matches() -> Array:
	var matched := {}

	# horizontal
	for y in height:
		var run_kind := -1
		var run: Array[Piece] = []
		for x in width:
			var p: Piece = grid[x][y]
			var k := p.kind if p else -999
			if p != null and k == run_kind:
				run.append(p)
			else:
				if run.size() >= 3:
					for rp in run: matched[rp] = true
				run_kind = k
				run = []
				if p != null: run.append(p)
		if run.size() >= 3:
			for rp2 in run: matched[rp2] = true

	# vertical
	for x in width:
		var run_kind2 := -1
		var run2: Array[Piece] = []
		for y in height:
			var p2: Piece = grid[x][y]
			var k2 := p2.kind if p2 else -999
			if p2 != null and k2 == run_kind2:
				run2.append(p2)
			else:
				if run2.size() >= 3:
					for rp3 in run2: matched[rp3] = true
				run_kind2 = k2
				run2 = []
				if p2 != null: run2.append(p2)
		if run2.size() >= 3:
			for rp4 in run2: matched[rp4] = true

	var out: Array[Piece] = []
	for k in matched.keys():
		out.append(k as Piece)
	return out

func _clear_matches(matches: Array[Piece]) -> void:
	for p in matches:
		grid[p.grid_x][p.grid_y] = null
		var t := create_tween()
		t.tween_property(p, "scale", Vector2(0.2, 0.2), 0.10)
		t.tween_property(p, "modulate:a", 0.0, 0.10)
		t.finished.connect(func(): p.queue_free())
	await get_tree().create_timer(0.22).timeout

func _apply_gravity() -> void:
	for x in width:
		var write_y := height - 1
		for y in range(height - 1, -1, -1):
			var p: Piece = grid[x][y]
			if p != null:
				if y != write_y:
					grid[x][write_y] = p
					grid[x][y] = null
					p.grid_y = write_y
					_animate_to_cell(p)
				write_y -= 1
	await get_tree().create_timer(0.16).timeout

func _refill() -> void:
	for x in width:
		for y in height:
			if grid[x][y] == null:
				var k := randi() % kinds
				var p := _spawn_piece(x, y, k)
				grid[x][y] = p
				# spawn above and drop
				p.position = board_to_world(x, -2)
				_animate_to_cell(p)
	await get_tree().create_timer(0.18).timeout

func _check_end() -> void:
	if score >= target_score:
		state = State.GAME_OVER
		emit_signal("message", "🎉 You win! Target reached.")
		emit_signal("game_over", true)
	elif moves_left <= 0:
		state = State.GAME_OVER
		emit_signal("message", "😵 Out of moves! Try again.")
		emit_signal("game_over", false)

# -------- Hint (still non-AI) --------
func find_hint_swap() -> Dictionary:
	if state != State.IDLE and state != State.SELECTED:
		return {}
	for y in height:
		for x in width:
			var p: Piece = grid[x][y]
			if p == null:
				continue
			if x + 1 < width:
				var q: Piece = grid[x+1][y]
				if q and _swap_would_match(p, q):
					return {"a": p, "b": q}
			if y + 1 < height:
				var r: Piece = grid[x][y+1]
				if r and _swap_would_match(p, r):
					return {"a": p, "b": r}
	return {}

func show_hint() -> bool:
	var hint := find_hint_swap()
	if hint.is_empty():
		return false
	var a: Piece = hint["a"]
	var b: Piece = hint["b"]
	if a == null or b == null:
		return false
	_show_hint_swap_animation(a, b)
	return true

func _show_hint_swap_animation(a: Piece = null, b: Piece = null) -> void:
	if a == null or b == null:
		var hint := find_hint_swap()
		if hint.is_empty():
			return
		a = hint["a"]
		b = hint["b"]
	if a == null or b == null:
		return
	if hint_tween and hint_tween.is_running():
		hint_tween.kill()
	var pos_a := a.position
	var pos_b := b.position
	hint_tween = create_tween()
	hint_tween.tween_property(a, "position", pos_b, 0.12)
	hint_tween.parallel().tween_property(b, "position", pos_a, 0.12)
	hint_tween.tween_property(a, "position", pos_a, 0.12)
	hint_tween.parallel().tween_property(b, "position", pos_b, 0.12)

func _swap_would_match(a: Piece, b: Piece) -> bool:
	var ak := a.kind
	var bk := b.kind
	a.kind = bk
	b.kind = ak
	var ok := not _find_all_matches().is_empty()
	a.kind = ak
	b.kind = bk
	a._update_visual()
	b._update_visual()
	return ok
