extends Node

# ============================================================
#  ADAPTIVEDIFFCULTY.GD
#  More aggressive adjustments so the player can actually
#  feel the difference between Easy and Hard.
# ============================================================

# Factor weights (must sum to 1.0)
const W_WIN_RATE    = 0.40
const W_MOVES_EFF   = 0.25
const W_HINT_USAGE  = 0.20
const W_WIN_STREAK  = 0.15

# Wider adjustment ranges so the effect is actually noticeable
const MOVES_BONUS_MAX  = 7      # struggling player gets +7 moves
const MOVES_MALUS_MAX  = 4      # skilled player loses 4 moves
const TARGET_MIN_MULT  = 0.70   # target can go DOWN 30% for weak players
const TARGET_MAX_MULT  = 1.35   # target can go UP 35% for strong players
const HINT_DELAY_MIN   = 4.0    # hint fires in 4s for struggling players
const HINT_DELAY_MAX   = 30.0   # hint fires in 30s for skilled players

# ── Main function: call this in Main.gd at level start ──────
func get_adapted_level(base_level):
	var d = compute_difficulty_score()

	var moves_delta  = int(lerp(float(MOVES_BONUS_MAX), float(-MOVES_MALUS_MAX), d))
	var final_moves  = max(5, int(base_level["moves"]) + moves_delta)

	var target_mult  = lerp(TARGET_MIN_MULT, TARGET_MAX_MULT, d)
	var final_target = int(float(int(base_level["target"])) * target_mult)

	var hint_delay   = lerp(HINT_DELAY_MIN, HINT_DELAY_MAX, d)

	return {
		"moves":       final_moves,
		"target":      final_target,
		"hint_delay":  hint_delay,
		"difficulty":  d,
	}

# Returns a label for the current difficulty band
func get_label():
	var d = compute_difficulty_score()
	if   d < 0.25: return "Sehr leicht"
	elif d < 0.45: return "Leicht"
	elif d < 0.60: return "Mittel"
	elif d < 0.78: return "Schwer"
	else:          return "Experte"

# Returns difficulty as 0–100 for a progress bar style display
func get_difficulty_percent():
	return int(compute_difficulty_score() * 100.0)

# ── Core algorithm ──────────────────────────────────────────
func compute_difficulty_score():
	var p = GameState.player_profile

	# Only apply meaningful adjustments after at least 2 sessions
	# so the first level always starts neutral
	if int(p["total_sessions"]) < 2:
		return 0.5

	var f_win    = float(p["win_rate"])
	var f_moves  = 1.0 - float(p["avg_moves_ratio"])
	var f_hints  = 1.0 - float(p["hint_usage_rate"])
	var streak   = clamp(float(int(p["consecutive_wins"])) / 4.0, 0.0, 1.0)

	var score = (f_win   * W_WIN_RATE
			+    f_moves  * W_MOVES_EFF
			+    f_hints  * W_HINT_USAGE
			+    streak   * W_WIN_STREAK)

	return clamp(score, 0.0, 1.0)
