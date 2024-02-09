extends Resource
class_name LevelData


# currently only emitted by level when a door is placed or removed
signal changed_doors
@export var doors: Array[DoorData] = []
# currently only emitted by level when a key is placed or removed
signal changed_keys
@export var keys: Array[KeyData] = []
signal changed_entries
@export var entries: Array[EntryData] = []
const SMALLEST_SIZE := Vector2i(800, 608)
signal changed_size
@export var size := SMALLEST_SIZE:
	set(val):
		if size == val: return
		size = val
		changed_size.emit()
signal changed_player_spawn_position
@export var player_spawn_position := Vector2i(398, 304):
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
## If the level uses custom lock arrangements, they'll be here
@export var custom_lock_arrangements := {}
## Just saves all positions for the tiles... I'll come up with something better later ok
# It's a dict so that it's not absurdly inefficient to check for repeats when placing new ones
signal changed_tiles
@export var tiles := {}
## Name of the level, used when standing in front of an entry that leads to it
# TODO: both the entry thing, and make it also show when entering the level ?
@export var name := "":
	set(val):
		if name == val: return
		name = val
		changed.emit()
## Title of the level, for example "Level 4-1" or "Page 3"
@export var title := "":
	set(val):
		if title == val: return
		title = val
		changed.emit()

## DEPRECATED
## KEPT FOR COMPATIBILITY (for now?)
@export var author := "":
	set(val):
		if author == val: return
		author = val
		changed.emit()
## DEPRECATED
## KEPT FOR COMPATIBILITY (for now?)
@export var editor_version: String

func _init() -> void:
	changed_doors.connect(emit_changed)
	changed_keys.connect(emit_changed)
	changed_entries.connect(emit_changed)
	changed_tiles.connect(emit_changed)
	changed_player_spawn_position.connect(emit_changed)
	changed_goal_position.connect(emit_changed)

## Deletes stuff outside the level boundary
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

# Only the keys are used. values are true for fixable and false for unfixable
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
	
	if size.x < SMALLEST_SIZE.x or size.y < SMALLEST_SIZE.y:
		add_invalid_reason(&"Level size is too small.", true)
		if should_correct:
			size.x = maxi(SMALLEST_SIZE.x, size.x)
			size.y = maxi(SMALLEST_SIZE.y, size.y)
	if size != size.snapped(Vector2i(32, 32)):
		add_invalid_reason(&"Level size isn't a multiple of 32x32.", true)
		if should_correct:
			size = size.snapped(Vector2i(32, 32))
	
	# Make sure player spawn is aligned to the grid + inside the level
	const PLAYER_SPAWN_OFFSET := Vector2i(14, 32)
	print("player_spawn_position: " + str(player_spawn_position))
	var new_pos := player_spawn_position
	# offset so it's presumably inside the grid
	new_pos -= PLAYER_SPAWN_OFFSET
	# clamp to grid and level size
	new_pos = new_pos.snapped(Vector2i(16, 16))
	new_pos = new_pos.clamp(Vector2i.ZERO, size - Vector2i(32, 32))
	# put it back
	new_pos += PLAYER_SPAWN_OFFSET
	# if the position was initially correct, it shouldn't have changed
	if player_spawn_position != new_pos:
		print("Oh noo invalid!")
		add_invalid_reason("Invalid player position.", true)
		if should_correct:
			player_spawn_position = new_pos
	for door in doors:
		door.check_valid(self, should_correct)
func get_screenshot() -> Image:
	var viewport := SubViewport.new()
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var vpc := SubViewportContainer.new()
	# TODO: No.
	vpc.position = Vector2(INF, INF)
	viewport.size = size
	vpc.size = viewport.size
	vpc.add_child(viewport)
	Engine.get_main_loop().root.add_child(vpc)
	
	var lvl: Level = preload("res://level_elements/level.tscn").instantiate()
	lvl.exclude_player = true
	lvl.pack_data = LevelPackData.make_from_level(duplicate())
	viewport.add_child(lvl)
	
	await RenderingServer.frame_post_draw 
	var img := viewport.get_texture().get_image()
	vpc.free()
	return img

