extends Resource
class_name LevelData

# has this level been loaded already? (no version check should be done)
var has_been_loaded := false
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
signal changed_goal_position
@export var goal_position := Vector2i(0, 0):
	set(val):
		if goal_position == val: return
		goal_position = val
		changed_goal_position.emit()
@export var custom_lock_arrangements := {}
## Just saves all positions for the tiles... I'll come up with something better later ok
# It's a dict so it's not absurdly inefficient to check for repeats when placing new ones
signal changed_tiles
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

func _init() -> void:
	changed_doors.connect(emit_changed)
	changed_keys.connect(emit_changed)
	changed_tiles.connect(emit_changed)
	changed_player_spawn_position.connect(emit_changed)
	changed_goal_position.connect(emit_changed)

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

var _fixable_invalid_reasons := {}
var _unfixable_invalid_reasons := {}
func add_invalid_reason(reason: StringName, fixable: bool) -> void:
	if fixable:
		_fixable_invalid_reasons[reason] = fixable
	else:
		_unfixable_invalid_reasons[reason] = fixable

# WAITING4GODOT: these can't be Array[String] ...
func get_fixable_invalid_reasons() -> Array:
	return _fixable_invalid_reasons.keys()

func get_unfixable_invalid_reasons() -> Array:
	return _unfixable_invalid_reasons.keys()

# Checks if the level is valid.
# if should_correct is true, corrects whatever invalid things it can.
func check_valid(should_correct: bool) -> void:
	_fixable_invalid_reasons.clear()
	_unfixable_invalid_reasons.clear()
	clear_outside_things()
	# TODO: Check collisions between things
	# etc...
	# Currently, weird sizes aren't allowed
	size = Vector2i(800, 608)
	# Clamp player spawn to the grid + inside the level
	var new_pos := player_spawn_position.clamp(Vector2i(14, 32), size - Vector2i(32 - 14, 0))
	new_pos -= Vector2i(14, 0)
	new_pos = player_spawn_position.snapped(Vector2i(32, 32))
	new_pos += Vector2i(14, 0)
	if player_spawn_position != new_pos:
		add_invalid_reason("Invalid player position.", true)
		if should_correct:
			player_spawn_position = new_pos
	for door in doors:
		door.check_valid(self, should_correct)
