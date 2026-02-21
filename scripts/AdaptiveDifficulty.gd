extends Node

# ============================================================
#  ADAPTIVEDIFFCULTY.GD
#
#  This script computes a "difficulty score" D between 0 and 1
#  based on how the player has been performing, then uses D
#  to adjust 3 things before each level starts:
#
#    1. MOVES ALLOWED
#       D close to 0 (struggling) → player gets up to +4 extra moves
#       D close to 1 (skilled)    → player gets up to -3 fewer moves
#
#    2. TARGET SCORE
#       D close to 0 → target is multiplied by 0.82 (lower bar)
#       D close to 1 → target is multiplied by 1.18 (higher bar)
#
#    3. HINT DELAY
#       D close to 0 → auto-hint fires after only 5 seconds
#       D close to 1 → auto-hint fires after 25 seconds
#
#  The player never sees any of this. The game simply feels
#  naturally easier or harder based on their history.
# ============================================================


# ── How much each factor influences the difficulty score ──
# These four weights must add up to 1.0.
const W_WIN_RATE    = 0.40   # biggest signal: are you winning?
const W_MOVES_EFF   = 0.25   # do you finish with moves to spare?
const W_HINT_USAGE  = 0.20   # do you need hints often?
const W_WIN_STREAK  = 0.15   # have you been winning lately?

# ── Boundaries for each adjusted parameter ──
const MOVES_BONUS_MAX  = 4     # max extra moves for a struggling player
const MOVES_MALUS_MAX  = 3     # max moves removed for a skilled player
const TARGET_MIN_MULT  = 0.82  # target score multiplied by this at minimum
const TARGET_MAX_MULT  = 1.18  # target score multiplied by this at maximum
const HINT_DELAY_MIN   = 5.0   # seconds before auto-hint (easy mode)
const HINT_DELAY_MAX   = 25.0  # seconds before auto-hint (hard mode)


# ============================================================
#  MAIN FUNCTION  –  call this in Main.gd at level start
# ============================================================

# Takes the raw level dict {"moves": X, "target": Y}
# Returns a new dict with adjusted values + hint_delay + score D.
func get_adapted_level(base_level):
	var d = _compute_difficulty_score()

	# lerp(a, b, t) returns  a + t*(b-a)
	# At D=0: lerp gives the EASY side. At D=1: gives the HARD side.

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


# Returns a simple label for the current difficulty band.
# You can show this in the HUD if you want.
func get_label():
	var d = _compute_difficulty_score()
	if   d < 0.30: return "Easy"
	elif d < 0.55: return "Medium"
	elif d < 0.75: return "Hard"
	else:          return "Expert"


# ============================================================
#  DIFFICULTY SCORE CALCULATION  (private)
# ============================================================

# Reads the player_profile from GameState and returns D in [0, 1].
# Higher D  →  the AI thinks the player is skilled  →  harder parameters.
func _compute_difficulty_score():
	var p = GameState.player_profile

	# Factor 1: win_rate is already 0–1 from the EMA
	var f_win = float(p["win_rate"])

	# Factor 2: a player who uses fewer moves is more efficient (stronger)
	# avg_moves_ratio is 0.0 (used no moves) to 1.0 (used all moves)
	# So efficiency = 1 - ratio
	var f_moves = 1.0 - float(p["avg_moves_ratio"])

	# Factor 3: a player who rarely uses hints is stronger
	var f_hints = 1.0 - float(p["hint_usage_rate"])

	# Factor 4: win streak, capped at 5 consecutive wins = 1.0
	var streak = clamp(float(int(p["consecutive_wins"])) / 5.0, 0.0, 1.0)

	var score = (f_win   * W_WIN_RATE
			+    f_moves  * W_MOVES_EFF
			+    f_hints  * W_HINT_USAGE
			+    streak   * W_WIN_STREAK)

	return clamp(score, 0.0, 1.0)
