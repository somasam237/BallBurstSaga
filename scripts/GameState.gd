extends Node

# ============================================================
#  GAMESTATE.GD  –  Autoload singleton
#  Stores levels, saves progress, and keeps the player
#  performance profile used by AdaptiveDifficulty.
# ============================================================

# 10 levels – these are the BASE values.
# AdaptiveDifficulty will quietly tweak moves and target
# at runtime depending on how the player is doing.
var levels = [
	{ "moves": 22, "target": 4000  },  # Level  1
	{ "moves": 20, "target": 6000  },  # Level  2
	{ "moves": 20, "target": 8000  },  # Level  3
	{ "moves": 18, "target": 10000 },  # Level  4
	{ "moves": 18, "target": 12000 },  # Level  5
	{ "moves": 16, "target": 14000 },  # Level  6
	{ "moves": 16, "target": 16000 },  # Level  7
	{ "moves": 15, "target": 18000 },  # Level  8
	{ "moves": 14, "target": 20000 },  # Level  9
	{ "moves": 13, "target": 24000 },  # Level 10
]

var current_level_index = 0
const SAVE_PATH = "user://save.cfg"

# ── Player performance profile ──────────────────────────────
# These values are updated after every level using an
# Exponential Moving Average (EMA) so the AI gradually
# tracks changes in player skill over many sessions.
var player_profile = {
	"win_rate":            0.5,   # rolling win probability  0.0–1.0
	"avg_moves_ratio":     0.7,   # avg fraction of moves consumed
	"hint_usage_rate":     0.3,   # avg hint reliance  0.0–1.0
	"consecutive_wins":    0,     # current win streak
	"consecutive_losses":  0,     # current loss streak
	"total_sessions":      0,     # total levels attempted
}

# How fast the EMA reacts to new data.
# 0.3 = 30% from latest result, 70% from accumulated history.
const EMA_ALPHA = 0.3

# ============================================================
#  LIFECYCLE
# ============================================================

func _ready():
	_load_progress()

# ============================================================
#  SAVE / LOAD
# ============================================================

func _load_progress():
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return

	current_level_index = int(cfg.get_value("progress", "current_level_index", 0))
	current_level_index = clamp(current_level_index, 0, levels.size() - 1)

	player_profile["win_rate"]           = float(cfg.get_value("profile", "win_rate",           0.5))
	player_profile["avg_moves_ratio"]    = float(cfg.get_value("profile", "avg_moves_ratio",    0.7))
	player_profile["hint_usage_rate"]    = float(cfg.get_value("profile", "hint_usage_rate",    0.3))
	player_profile["consecutive_wins"]   = int(  cfg.get_value("profile", "consecutive_wins",   0))
	player_profile["consecutive_losses"] = int(  cfg.get_value("profile", "consecutive_losses", 0))
	player_profile["total_sessions"]     = int(  cfg.get_value("profile", "total_sessions",     0))

func load_progress():
	_load_progress()

func _save_progress():
	var cfg = ConfigFile.new()
	cfg.set_value("progress", "current_level_index", current_level_index)
	cfg.set_value("profile",  "win_rate",            player_profile["win_rate"])
	cfg.set_value("profile",  "avg_moves_ratio",     player_profile["avg_moves_ratio"])
	cfg.set_value("profile",  "hint_usage_rate",     player_profile["hint_usage_rate"])
	cfg.set_value("profile",  "consecutive_wins",    player_profile["consecutive_wins"])
	cfg.set_value("profile",  "consecutive_losses",  player_profile["consecutive_losses"])
	cfg.set_value("profile",  "total_sessions",      player_profile["total_sessions"])
	cfg.save(SAVE_PATH)

# ============================================================
#  LEVEL ACCESS
# ============================================================

func level_count():
	return levels.size()

func get_level(index):
	return levels[clamp(index, 0, levels.size() - 1)]

func get_current_level():
	return get_level(current_level_index)

func get_current_level_index():
	return current_level_index

func set_current_level(index):
	current_level_index = clamp(index, 0, levels.size() - 1)
	_save_progress()

func has_next_level():
	return current_level_index + 1 < levels.size()

func advance_level():
	if has_next_level():
		current_level_index += 1
		_save_progress()

# ============================================================
#  PLAYER PROFILE UPDATE  (called by Main.gd after each level)
# ============================================================

# won         – true if player reached the target score
# moves_used  – how many swaps the player actually made
# total_moves – the moves budget that was given
# hints_used  – how many times the player pressed Hint
func record_level_result(won, moves_used, total_moves, hints_used):
	player_profile["total_sessions"] = int(player_profile["total_sessions"]) + 1

	# Win rate EMA
	var win_sample = 1.0 if won else 0.0
	player_profile["win_rate"] = _ema(float(player_profile["win_rate"]), win_sample)

	# Move efficiency EMA  (0.0 = used no moves, 1.0 = used all moves)
	var moves_ratio = float(moves_used) / float(max(total_moves, 1))
	player_profile["avg_moves_ratio"] = _ema(float(player_profile["avg_moves_ratio"]), moves_ratio)

	# Hint usage EMA  (normalised: 3+ hints → 1.0)
	var hint_sample = clamp(float(hints_used) / 3.0, 0.0, 1.0)
	player_profile["hint_usage_rate"] = _ema(float(player_profile["hint_usage_rate"]), hint_sample)

	# Streaks
	if won:
		player_profile["consecutive_wins"]   = int(player_profile["consecutive_wins"]) + 1
		player_profile["consecutive_losses"] = 0
	else:
		player_profile["consecutive_losses"] = int(player_profile["consecutive_losses"]) + 1
		player_profile["consecutive_wins"]   = 0

	_save_progress()

func _ema(old_val, sample):
	return EMA_ALPHA * sample + (1.0 - EMA_ALPHA) * old_val
