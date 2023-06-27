extends Resource
class_name LevelData

# has this level been loaded already? (no version check should be done)
var has_been_loaded := false
@export var num_version: int = SaveLoad.LATEST_FORMAT
# Just in case it's needed
@export var editor_version: String

# currently only emitted by level when a door is placed or removed
signal changed_doors
@export var doors: Array[DoorData] = []
# currently only emitted by level when a key is placed or removed
signal changed_keys
@export var keys: Array[KeyData] = []
@export var size := Vector2i(800, 608)
signal changed_player_spawn_position
@export var player_spawn_position := Vector2i(400, 304):
	set(val):
		if player_spawn_position == val: return
		player_spawn_position = val
		changed_player_spawn_position.emit()
		changed.emit()
signal changed_goal_position
@export var goal_position := Vector2i(0, 0):
	set(val):
		if goal_position == val: return
		goal_position = val
		changed_goal_position.emit()
		changed.emit()
@export var custom_lock_arrangements := {}
## Just saves all positions for the tiles... I'll come up with something better later ok
# It's a dict so it's not absurdly inefficient to check for repeats when placing new ones
@export var tiles := {}
@export var name := "":
	set(val):
		if name == val: return
		name = val
		changed.emit()
@export var author := "":
	set(val):
		if author == val: return
		author = val
		changed.emit()
# For easier saving
var file_path := "":
	set(val):
		if file_path == val: return
		file_path = val
		changed.emit()

func clear_outside_things() -> void:
	var amount_deleted := 0
	# tiles
	var deleted_ones := []
	for key in tiles.keys():
		var pos = key * Vector2i(32, 32)
		if pos.x < 0 or pos.y < 0 or pos.x + 32 > size.x or pos.y + 32 > size.y:
			deleted_ones.push_back(key)
	for pos in deleted_ones:
		var worked := tiles.erase(pos)
		assert(worked == true)
	
	amount_deleted += deleted_ones.size()
	# doors
	deleted_ones.clear()
	for door in doors:
		var max = door.position + door.size
		if door.position.x < 0 or door.position.y < 0 or max.x > size.x or max.y > size.y:
			deleted_ones.push_back(door)
	for door in deleted_ones:
		doors.erase(door)
	amount_deleted += deleted_ones.size()
	# keys
	deleted_ones.clear()
	for key in keys:
		var max = key.position + Vector2i(32, 32)
		if key.position.x < 0 or key.position.y < 0 or max.x > size.x or max.y > size.y:
			deleted_ones.push_back(key)
	for key in deleted_ones:
		keys.erase(key)
	amount_deleted += deleted_ones.size()
	if amount_deleted != 0:
		print("deleted %d outside things" % amount_deleted)

# Checks if the level is valid, and fixes any invalidness
func check_valid() -> void:
	clear_outside_things()
	# TODO: Check collisions between things
	# TODO: Check locks not overlapping eachother + not outside door
	# etc...
	# Currently, weird sizes aren't allowed
	size = Vector2i(800, 608)
	# Clamp player spawn to the grid + inside the level
	var original_pos := player_spawn_position
	player_spawn_position = player_spawn_position.clamp(Vector2i(14, 32), size - Vector2i(32 - 14, 0))
	player_spawn_position -= Vector2i(14, 0)
	player_spawn_position = player_spawn_position.snapped(Vector2i(32, 32))
	player_spawn_position += Vector2i(14, 0)
	if player_spawn_position != original_pos:
		push_warning("WARNING: Invalid player position. Corrected.")
	# Doors shouldn't have a count of 0
	for door in doors:
		if door.amount.is_zero():
			push_warning("WARNING: Door had count 0. Corrected.")
			door.amount.set_real_part(1)
