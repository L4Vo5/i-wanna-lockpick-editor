extends Resource
class_name LevelData

@export var doors: Array[DoorData] = []
@export var keys: Array[KeyData] = []
@export var size := Vector2(800, 608)
signal changed_player_spawn_position
@export var player_spawn_position := Vector2(400, 304):
	set(val):
		if player_spawn_position == val: return
		player_spawn_position = val
		changed_player_spawn_position.emit()
		changed.emit()
