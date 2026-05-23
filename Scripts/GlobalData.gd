extends Node

@export var levels: Array[LevelData] = []

var current_level_index: int = 0

func get_current_level() -> LevelData:
	return levels[current_level_index]

func is_last_level() -> bool:
	return current_level_index >= levels.size() - 1

func next_level():
	current_level_index += 1