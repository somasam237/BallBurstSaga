extends Node2D
class_name Board

signal score_gained(points: int)
signal moves_used(remaining: int)
signal message(text: String)
signal game_over(won: bool)
signal big_match_happened(count, center_pos)  # fired when 4+ pieces match

enum State {
	IDLE, SELECTED, SWAPPING, CHECKING, CLEARING, GRAVITY, REFILL, GAME_OVER
}

@export var width:        int = 8
@export var height:       int = 8
@export var cell_size:    int = 64
@export var kinds:        int = 6
@export var start_moves:  int = 25
@export var target_score: int = 5000

@export var piece_scene: PackedScene = preload("res://scenes/Piece.tscn")

@onready var pieces_layer: Node2D = $Pieces

var state      = State.IDLE
var grid       = []
var moves_left = 0
var score      = 0
var selected   = null
var swap_a     = null
var swap_b     = null
var hint_timer = null
var hint_tween = null

# ── Combo tracking (reset each swap, counts cascades) ──
var _combo_count = 0

# ============================================================
#  LIFECYCLE
# ============================================================

func _ready():
	new_game()
	_start_hint_timer()

func _start_hint_timer():
	hint_timer            = Timer.new()
	hint_timer.wait_time  = 10.0
	hint_timer.one_shot   = false
	hint_timer.autostart  = true
	add_child(hint_timer)
	hint_timer.timeout.connect(_on_hint_timer_timeout)

func _on_hint_timer_timeout():
	if state != State.IDLE:
		return
	_show_hint_swap_animation()

# ============================================================
#  GAME CONTROL
# ============================================================

func new_game():
	_clear_all()
	moves_left   = start_moves
	score        = 0
	_combo_count = 0
	emit_signal("moves_used",   moves_left)
	emit_signal("score_gained", 0)
	emit_signal("message",      "Match 3+ to score!")
	_init_grid()
	_fill_without_initial_matches()
	state = State.IDLE

func configure(moves, target):
	start_moves  = moves
	target_score = target

func _clear_all():
	for c in pieces_layer.get_children():
		c.queue_free()
	grid.clear()
	selected = null
	swap_a   = null
	swap_b   = null

func _init_grid():
	grid = []
	for x in width:
		var col = []
		for y in height:
			col.append(null)
		grid.append(col)

# ============================================================
#  COORDINATE HELPERS
# ============================================================

func board_to_world(x, y):
	return Vector2(x * cell_size + cell_size / 2.0,
				   y * cell_size + cell_size / 2.0)

func world_to_board(pos):
	return Vector2i(int(floor(pos.x / cell_size)),
					int(floor(pos.y / cell_size)))

# ============================================================
#  PIECE SPAWNING
# ============================================================

func _spawn_piece(x, y, k):
	var p = piece_scene.instantiate()
	pieces_layer.add_child(p)
	p.grid_x  = x
	p.grid_y  = y
	p.size_px = cell_size
	p.set_kind(k)
	p.position = board_to_world(x, y)
	return p

func _fill_without_initial_matches():
	for y in height:
		for x in width:
			var k = _random_kind_avoiding_match(x, y)
			grid[x][y] = _spawn_piece(x, y, k)

func _random_kind_avoiding_match(x, y):
	var attempts = 0
	while attempts < 50:
		var k = randi() % kinds
		if not _would_make_match(x, y, k):
			return k
		attempts += 1
	return randi() % kinds

func _would_make_match(x, y, k):
	if x >= 2:
		var a = grid[x-1][y]
		var b = grid[x-2][y]
		if a and b and a.kind == k and b.kind == k:
			return true
	if y >= 2:
		var a2 = grid[x][y-1]
		var b2 = grid[x][y-2]
		if a2 and b2 and a2.kind == k and b2.kind == k:
			return true
	return false

# ============================================================
#  INPUT
# ============================================================

func _unhandled_input(event):
	if state == State.GAME_OVER:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if state == State.IDLE or state == State.SELECTED:
			_handle_click(get_global_mouse_position())

func _handle_click(global_pos):
	var local_pos = to_local(global_pos)
	var b         = world_to_board(local_pos)
	if b.x < 0 or b.x >= width or b.y < 0 or b.y >= height:
		return
	var p = grid[b.x][b.y]
	if p == null:
		return

	if state == State.IDLE:
		selected = p
		state    = State.SELECTED
		_pulse(p)
		return

	if p == selected:
		selected = null
		state    = State.IDLE
		emit_signal("message", "Selection cleared.")
		return

	if _are_adjacent(selected, p):
		if moves_left <= 0:
			emit_signal("message", "No moves left.")
			return
		swap_a       = selected
		swap_b       = p
		selected     = null
		_combo_count = 0   # reset combo for this new swap
		_consume_move()
		_begin_swap()
	else:
		selected = p
		_pulse(p)

func _consume_move():
	moves_left -= 1
	emit_signal("moves_used", moves_left)

func _are_adjacent(a, b):
	return (abs(a.grid_x - b.grid_x) + abs(a.grid_y - b.grid_y)) == 1

func _pulse(p):
	var t = create_tween()
	t.tween_property(p, "scale", Vector2(1.08, 1.08), 0.06)
	t.tween_property(p, "scale", Vector2(1, 1),        0.06)

# ============================================================
#  FSM
# ============================================================

func _begin_swap():
	state = State.SWAPPING
	_swap_pieces_in_grid(swap_a, swap_b)
	_animate_to_cell(swap_a)
	_animate_to_cell(swap_b)
	await get_tree().create_timer(0.14).timeout
	state = State.CHECKING
	_check_after_swap()

func _check_after_swap():
	var matches = _find_all_matches()
	if matches.is_empty():
		emit_signal("message", "No match — reverted.")
		state = State.SWAPPING
		_swap_pieces_in_grid(swap_a, swap_b)
		_animate_to_cell(swap_a)
		_animate_to_cell(swap_b)
		await get_tree().create_timer(0.14).timeout
		swap_a = null
		swap_b = null
		state  = State.IDLE
		_check_end()
		return
	await _resolve_loop()
	swap_a = null
	swap_b = null
	state  = State.IDLE
	_check_end()

func _swap_pieces_in_grid(a, b):
	var ax = a.grid_x;  var ay = a.grid_y
	var bx = b.grid_x;  var by = b.grid_y
	grid[ax][ay] = b;   grid[bx][by] = a
	a.grid_x = bx;      a.grid_y = by
	b.grid_x = ax;      b.grid_y = ay

# Virtual swap used by AIAdvisor – swaps kind values only, no grid update
func _virtual_swap(a, b):
	var tmp = a.kind
	a.kind  = b.kind
	b.kind  = tmp

func _animate_to_cell(p):
	var t = create_tween()
	t.tween_property(p, "position", board_to_world(p.grid_x, p.grid_y), 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _resolve_loop():
	while true:
		state       = State.CHECKING
		var matches = _find_all_matches()
		if matches.is_empty():
			return

		_combo_count += 1
		state   = State.CLEARING
		var cnt = matches.size()
		var pts = cnt * 100

		# Combo bonus: each cascade after the first doubles the points
		if _combo_count > 1:
			pts = int(pts * (1.0 + (_combo_count - 1) * 0.5))

		score += pts
		emit_signal("score_gained", pts)

		# ── Fire match animations before clearing ──
		var center = _get_match_center(matches)
		_play_match_animation(matches, cnt, center)

		if cnt >= 4:
			emit_signal("big_match_happened", cnt, center)
			emit_signal("message", _combo_label(cnt))
		elif _combo_count > 1:
			emit_signal("message", "Combo x" + str(_combo_count) + "!")
		else:
			emit_signal("message", "")

		await _clear_matches(matches)
		state = State.GRAVITY
		await _apply_gravity()
		state = State.REFILL
		await _refill()
		await get_tree().create_timer(0.05).timeout

func _combo_label(cnt):
	if cnt >= 7: return "🔥 INCREDIBLE! x" + str(cnt)
	if cnt >= 6: return "💥 AMAZING! x" + str(cnt)
	if cnt >= 5: return "⚡ SUPER! x"   + str(cnt)
	return            "✨ GREAT! x"     + str(cnt)

# ============================================================
#  MATCH ANIMATIONS  (Candy Crush style)
# ============================================================

# Compute the average world position of a set of matched pieces
func _get_match_center(matches):
	var sum = Vector2.ZERO
	for p in matches:
		sum += board_to_world(p.grid_x, p.grid_y)
	return sum / float(matches.size())

# Main entry point – decides which animation to play
func _play_match_animation(matches, count, center_world):
	if count >= 4:
		_spawn_big_match_burst(matches, count, center_world)
	else:
		_spawn_small_stars(matches)

# ── Small star pop for 3-match ──────────────────────────────
func _spawn_small_stars(matches):
	for p in matches:
		var world_pos = board_to_world(p.grid_x, p.grid_y)
		_spawn_floating_text("⭐", world_pos, Color(1.0, 0.9, 0.2), 0.7)

# ── Big explosion burst for 4+ match ────────────────────────
func _spawn_big_match_burst(matches, count, center_world):
	# 1. Flash ring at center
	_spawn_flash_ring(center_world)

	# 2. Star burst from every matched piece
	var star_icons = ["⭐", "✨", "💫", "🌟"]
	for p in matches:
		var world_pos = board_to_world(p.grid_x, p.grid_y)
		var icon      = star_icons[randi() % star_icons.size()]
		_spawn_floating_text(icon, world_pos, Color(1.0, 0.85, 0.1), 1.0)

	# 3. Big combo label at center
	var combo_colors = [Color(1,0.3,0.8), Color(0.3,1,0.5), Color(1,0.8,0), Color(0.3,0.7,1)]
	var col = combo_colors[randi() % combo_colors.size()]
	_spawn_floating_text(_combo_label(count), center_world, col, 1.3, true)

	# 4. Shake the pieces in the match group
	for p in matches:
		_shake_piece(p)

# ── Spawn a Label that floats upward then fades out ─────────
# big = true makes the label larger and more dramatic
func _spawn_floating_text(text, world_pos, color, scale_mult = 1.0, big = false):
	var lbl        = Label.new()
	lbl.text       = text
	lbl.add_theme_font_size_override("font_size", 28 if big else 18)
	lbl.add_theme_color_override("font_color", color)
	lbl.position   = world_pos - Vector2(20, 20)
	lbl.z_index    = 200
	pieces_layer.add_child(lbl)

	var rand_x     = randf_range(-30.0, 30.0)
	var target_pos = world_pos + Vector2(rand_x, -90.0 * scale_mult)
	var duration   = 0.7 + scale_mult * 0.3

	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(lbl, "position", target_pos, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(lbl, "modulate:a", 0.0, duration * 0.8)\
		.set_delay(duration * 0.3)\
		.set_trans(Tween.TRANS_SINE)
	# Scale pop
	lbl.scale = Vector2(0.5, 0.5)
	t.tween_property(lbl, "scale", Vector2(scale_mult, scale_mult), 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Auto-free after animation completes
	t.finished.connect(func():
		if is_instance_valid(lbl):
			lbl.queue_free()
)


# ── Circular flash ring that expands and fades ───────────────
func _spawn_flash_ring(center_world):
	# We fake the ring with 8 small star Labels placed in a circle
	var ring_icons = ["✨", "💥", "⭐", "🌟", "✨", "💥", "⭐", "🌟"]
	for i in 8:
		var angle  = (TAU / 8.0) * i
		var radius = 10.0
		var offset = Vector2(cos(angle), sin(angle)) * radius
		var pos    = center_world + offset

		var lbl        = Label.new()
		lbl.text       = ring_icons[i]
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.position   = pos
		lbl.z_index    = 199
		pieces_layer.add_child(lbl)

		var end_pos = center_world + Vector2(cos(angle), sin(angle)) * 70.0
		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(lbl, "position", end_pos, 0.4)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(lbl, "modulate:a", 0.0, 0.4)\
			.set_trans(Tween.TRANS_SINE)
		t.chain().tween_callback(func(): lbl.queue_free())

# ── Quick shake on a piece node ──────────────────────────────
func _shake_piece(p):
	if not is_instance_valid(p):
		return
	var origin = p.position
	var t      = create_tween()
	t.tween_property(p, "position", origin + Vector2(-6, 0), 0.04)
	t.tween_property(p, "position", origin + Vector2( 6, 0), 0.04)
	t.tween_property(p, "position", origin + Vector2(-4, 0), 0.04)
	t.tween_property(p, "position", origin,                  0.04)

# ============================================================
#  MATCH / CLEAR / GRAVITY / REFILL
# ============================================================

func _find_all_matches():
	var matched = {}
	for y in height:
		var run_kind = -1
		var run      = []
		for x in width:
			var p = grid[x][y]
			var k = p.kind if p else -999
			if p != null and k == run_kind:
				run.append(p)
			else:
				if run.size() >= 3:
					for rp in run: matched[rp] = true
				run_kind = k
				run      = []
				if p != null: run.append(p)
		if run.size() >= 3:
			for rp2 in run: matched[rp2] = true

	for x in width:
		var run_kind2 = -1
		var run2      = []
		for y in height:
			var p2 = grid[x][y]
			var k2 = p2.kind if p2 else -999
			if p2 != null and k2 == run_kind2:
				run2.append(p2)
			else:
				if run2.size() >= 3:
					for rp3 in run2: matched[rp3] = true
				run_kind2 = k2
				run2      = []
				if p2 != null: run2.append(p2)
		if run2.size() >= 3:
			for rp4 in run2: matched[rp4] = true

	var out = []
	for k in matched.keys():
		out.append(k)
	return out

func _clear_matches(matches):
	for p in matches:
		grid[p.grid_x][p.grid_y] = null
		var t = create_tween()
		t.tween_property(p, "scale",      Vector2(0.2, 0.2), 0.10)
		t.tween_property(p, "modulate:a", 0.0,               0.10)
		t.finished.connect(func(): p.queue_free())
	await get_tree().create_timer(0.22).timeout

func _apply_gravity():
	for x in width:
		var write_y = height - 1
		for y in range(height - 1, -1, -1):
			var p = grid[x][y]
			if p != null:
				if y != write_y:
					grid[x][write_y] = p
					grid[x][y]       = null
					p.grid_y         = write_y
					_animate_to_cell(p)
				write_y -= 1
	await get_tree().create_timer(0.16).timeout

func _refill():
	for x in width:
		for y in height:
			if grid[x][y] == null:
				var k = randi() % kinds
				var p = _spawn_piece(x, y, k)
				grid[x][y] = p
				p.position = board_to_world(x, -2)
				_animate_to_cell(p)
	await get_tree().create_timer(0.18).timeout

func _check_end():
	if score >= target_score:
		state = State.GAME_OVER
		emit_signal("message",   "🎉 You win! Target reached.")
		emit_signal("game_over", true)
	elif moves_left <= 0:
		state = State.GAME_OVER
		emit_signal("message",   "😵 Out of moves! Try again.")
		emit_signal("game_over", false)

# ============================================================
#  HINT SYSTEM  (AIAdvisor still works – unchanged)
# ============================================================

func find_hint_swap():
	if state != State.IDLE and state != State.SELECTED:
		return {}
	for y in height:
		for x in width:
			var p = grid[x][y]
			if p == null:
				continue
			if x + 1 < width:
				var q = grid[x+1][y]
				if q and _swap_would_match(p, q):
					return {"a": p, "b": q}
			if y + 1 < height:
				var r = grid[x][y+1]
				if r and _swap_would_match(p, r):
					return {"a": p, "b": r}
	return {}

func show_hint():
	var hint = find_hint_swap()
	if hint.is_empty():
		return false
	var a = hint["a"]
	var b = hint["b"]
	if a == null or b == null:
		return false
	_show_hint_swap_animation(a, b)
	return true

func _show_hint_swap_animation(a = null, b = null):
	if a == null or b == null:
		var hint = find_hint_swap()
		if hint.is_empty():
			return
		a = hint["a"]
		b = hint["b"]
	if a == null or b == null:
		return
	if hint_tween and hint_tween.is_running():
		hint_tween.kill()
	var pos_a  = a.position
	var pos_b  = b.position
	hint_tween = create_tween()
	hint_tween.tween_property(a, "position", pos_b, 0.12)
	hint_tween.parallel().tween_property(b, "position", pos_a, 0.12)
	hint_tween.tween_property(a, "position", pos_a, 0.12)
	hint_tween.parallel().tween_property(b, "position", pos_b, 0.12)

func _swap_would_match(a, b):
	var ak = a.kind;  var bk = b.kind
	a.kind = bk;      b.kind = ak
	var ok = not _find_all_matches().is_empty()
	a.kind = ak;      b.kind = bk
	a._update_visual()
	b._update_visual()
	return ok
