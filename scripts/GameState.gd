extends Node

# Simple hardcoded levels for MVP.
var levels := [
	{"moves": 20, "target": 3000},
	{"moves": 22, "target": 4500},
	{"moves": 25, "target": 6000},
]

var current_level_index: int = 0

func level_count() -> int:
	return levels.size()

func get_level(index: int) -> Dictionary:
	return levels[clamp(index, 0, levels.size() - 1)]

func set_current_level(index: int) -> void:
	current_level_index = clamp(index, 0, levels.size() - 1)

func get_current_level() -> Dictionary:
	return get_level(current_level_index)

func has_next_level() -> bool:
	return current_level_index + 1 < levels.size()

func advance_level() -> void:
	if has_next_level():
		current_level_index += 1
