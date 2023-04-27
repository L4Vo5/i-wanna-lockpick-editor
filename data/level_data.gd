extends Resource
class_name LevelData

# has this level been loaded already? (no version check should be done)
var has_been_loaded := false
# DEPRECATED. Delete soon!
@export var version: String:
	set(val):
		version = val
		check_version()
@export var num_version: int = 1
# Just in case it's needed
@export var editor_version: String

@export var doors: Array[DoorData] = []
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
@export var level_name := ""
# For easier saving
var file_path := ""

func clear_outside_things() -> void:
	var amount_deleted := 0
	# tiles
	var deleted_ones := []
	for key in tiles.keys():
		var pos = key * Vector2i(32, 32)
		if pos.x < 0 or pos.y < 0 or pos.x + 32 > size.x or pos.y > size.y + 32:
			deleted_ones.push_back(key)
	for pos in deleted_ones:
		assert(tiles.erase(pos) == true)
	
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

# For my own reference lol
const VERSIONS_LIST := [
	"0.0.1.0",
	"0.0.1.1",
	"0.0.1.2",
	"0.0.2.0", # Current
]
# Versions that are fully compatible with the current one
const COMPATIBLE_VERSIONS := [
	"0.0.1.0",
	"0.0.1.1",
	"0.0.1.2",
	"0.0.2.0", # Current
]
func check_version() -> void:
	if has_been_loaded: return
	has_been_loaded = true
	return
	print("loading from version %s" % version)
	if version == "" or version == null:
		printerr("Why is this level being set to a null version?")
		breakpoint
		version = Global.game_version
	match version.naturalnocasecmp_to(Global.game_version):
		-1: # made in older version
			print("Loading a level from older version \"%s\"" % version)
			if version in COMPATIBLE_VERSIONS:
				version = Global.game_version
			else:
				pass # currently unhandled
		0:
			pass
		1: # made in newer version
			var error_text := \
"""This level was made in version %s.
You're on version %s.
There's currently no plan to try to handle this.
Please install the new version.
The application will now be closed.""" % [version, Global.game_version]
			Global.fatal_error(error_text, Vector2i(500, 200))

# Checks if the level is valid, and fixes any invalidness
func check_valid() -> void:
	clear_outside_things()
	# TODO: Check collisions between things
	# TODO: Check locks not overlapping eachother + not outside door
	# etc...
	# Currently, weird sizes aren't allowed
	size = Vector2i(800, 608)
	# Clamp player spawn to the grid + inside the level
	player_spawn_position = player_spawn_position.clamp(Vector2i(14, 32), size - Vector2i(32 - 14, 0))
	player_spawn_position -= Vector2i(14, 0)
	player_spawn_position = player_spawn_position.snapped(Vector2i(32, 32))
	player_spawn_position += Vector2i(14, 0)
