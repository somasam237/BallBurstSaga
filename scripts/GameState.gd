extends Node

# Simple hardcoded levels for MVP.
var levels := [
	{"moves": 20, "target": 8000},
	{"moves": 22, "target": 11000},
	{"moves": 25, "target": 14000},
]

var current_level_index: int = 0
const SAVE_PATH := "user://save.cfg"

func _ready() -> void:
	_load_progress()

func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		return
	current_level_index = int(cfg.get_value("progress", "current_level_index", current_level_index))
	current_level_index = clamp(current_level_index, 0, levels.size() - 1)

func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "current_level_index", current_level_index)
	cfg.save(SAVE_PATH)

func level_count() -> int:
	return levels.size()

func get_level(index: int) -> Dictionary:
	return levels[clamp(index, 0, levels.size() - 1)]

func set_current_level(index: int) -> void:
	current_level_index = clamp(index, 0, levels.size() - 1)
	_save_progress()

func get_current_level() -> Dictionary:
	return get_level(current_level_index)

func get_current_level_index() -> int:
	return current_level_index

func has_next_level() -> bool:
	return current_level_index + 1 < levels.size()

func advance_level() -> void:
	if has_next_level():
		current_level_index += 1
		_save_progress()
