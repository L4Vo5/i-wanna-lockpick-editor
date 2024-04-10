extends Node2D
class_name Level
## Level scene. Handles the playing (and displaying) of a single level.
## (Actually handles the whole progression through a LevelPack)
## For performance reasons, it's far easier to keep a Level and change its level_data than to instance a new Level.


var gameplay_manager: GameplayManager
@onready var logic: LevelLogic = %LevelLogic

signal changed_level_data
var level_data: LevelData = null:
	set(val):
		if level_data == val: return
		_disconnect_level_data()
		level_data = val
		_connect_level_data()
		changed_level_data.emit()

## If true, the level will be rendered as usual, but no player will be spawned.
@export var exclude_player := false:
	set(val):
		if exclude_player == val: return
		exclude_player = val
		_spawn_player()

# makes it so the level doesn't set Global.current_level to itself
var dont_make_current := false

# echo of some of the level data's signals, since it's easier for other objects to hook into the level object which is less likely to change
signal changed_doors
signal changed_keys



const DOOR := preload("res://level_elements/doors_locks/door.tscn")
const KEY := preload("res://level_elements/keys/key.tscn")
const ENTRY := preload("res://level_elements/entries/entry.tscn")
const PLAYER := preload("res://level_elements/kid/kid.tscn")
const GOAL := preload("res://level_elements/goal/goal.tscn")

@onready var doors: Node2D = %Doors
@onready var keys: Node2D = %Keys
@onready var entries: Node2D = %Entries
@onready var player_parent: Node2D = %PlayerParent
@onready var goal_parent: Node2D = %GoalParent
@onready var tile_map: TileMap = %TileMap
@onready var player_spawn_point: Sprite2D = %PlayerSpawnPoint
@onready var debris_parent: Node2D = %DebrisParent
@onready var i_view_sound_1: AudioStreamPlayer = %IView1
@onready var i_view_sound_2: AudioStreamPlayer = %IView2
@onready var undo_sound: AudioStreamPlayer = %Undo
@onready var autorun_sound: AudioStreamPlayer = %Autorun
@onready var autorun_off: Sprite2D = %AutorunOff
@onready var autorun_on: Sprite2D = %AutorunOn
@onready var camera: Camera2D = %LevelCamera
#@onready var camera_dragger: Node2D = $CameraDragger

@onready var hover_highlight: HoverHighlight = %HoverHighlight
var hovering_over: Node:
	get:
		return hover_highlight.current_obj
@onready var mouseover: Node2D = %Mouseover


var player: Kid
var goal: LevelGoal

var is_autorun_on := false
var autorun_tween: Tween

func _unhandled_key_input(event: InputEvent) -> void:
	if not Global.is_playing: return
	if event.is_action_pressed(&"i-view"):
		logic.i_view = not logic.i_view
		i_view_sound_1.play()
		i_view_sound_2.play()
	elif event.is_action_pressed(&"restart"):
		gameplay_manager.reset()
	elif event.is_action_pressed(&"undo", true):
		undo.call_deferred()
	# TODO: Make redo work properly (bugs related to standing on doors?)
#	elif event.is_action(&"redo") and event.is_pressed():
#		if not Global.is_playing: return
#		undo_redo.redo()
	elif event.is_action_pressed(&"savestate", true):
		undo_sound.pitch_scale = 0.5
		undo_sound.play()
		logic.start_undo_action()
		logic.end_undo_action()
	elif event.is_action_pressed(&"autorun"):
		is_autorun_on = !is_autorun_on
		var used: Sprite2D
		if is_autorun_on:
			autorun_sound.pitch_scale = 1
			autorun_off.hide()
			used = autorun_on
		else:
			autorun_sound.pitch_scale = 0.7
			autorun_on.hide()
			used = autorun_off
		autorun_sound.play()
		if is_instance_valid(autorun_tween):
			autorun_tween.kill()
		autorun_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		used.show()
		used.modulate.a = 0
		
		autorun_tween.tween_property(used, "modulate:a", 1, 0.1)
		autorun_tween.tween_interval(0.5)
		autorun_tween.tween_property(used, "modulate:a", 0, 0.5)

func _ready() -> void:
	if not dont_make_current:
		Global.current_level = self
	reset()
	_update_player_spawn_position()
	hover_highlight.adapted_to.connect(_on_hover_adapted_to)
	hover_highlight.stopped_adapting.connect(_on_hover_adapted_to.bind(null))
	logic.level = self

func _physics_process(_delta: float) -> void:
	adjust_camera()

# For legal reasons this should happen in a deferred call, so it's at the end of the frame and everything that happens in this frame had time to record their undo calls
func undo() -> void:
	if not Global.is_playing: return
	undo_sound.pitch_scale = 0.6
	undo_sound.play()
	logic.undo()
	update_mouseover()

## Resets the current level (when pressing r)
## Also used for starting it for the first time
func reset() -> void:
	if not is_node_ready(): return
	if not level_data: return
	assert(PerfManager.start("Level::reset"))
	
	# This initial stuff looks ugly for optimization's sake
	# (yes, it makes a measurable impact, specially on big levels)
	assert(PerfManager.start("Level::reset (doors)"))
	var needed_doors := level_data.doors.size()
	var current_doors := doors.get_child_count()
	# redo the current ones
	for i in mini(needed_doors, current_doors):
		var door := doors.get_child(i)
		door.original_door_data = level_data.doors[i]
		door.door_data = door.original_door_data.duplicated()
	# shave off the rest
	if current_doors > needed_doors:
		for _i in current_doors - needed_doors:
			var door := doors.get_child(-1)
			doors.remove_child(door)
			disconnect_door(door)
			NodePool.return_node(door)
	# or add them
	else:
		for i in range(current_doors, needed_doors):
			_spawn_door(level_data.doors[i])
	assert(PerfManager.end("Level::reset (doors)"))
	
	assert(PerfManager.start("Level::reset (keys)"))
	var needed_keys := level_data.keys.size()
	var current_keys := keys.get_child_count()
	
	# redo the current ones
	for i in mini(needed_keys, current_keys):
		var key := keys.get_child(i)
		key.set_meta(&"original_key_data", level_data.keys[i])
		key.key_data = level_data.keys[i].duplicated()
	# shave off the rest
	if current_keys > needed_keys:
		for _i in current_keys - needed_keys:
			var key := keys.get_child(-1)
			keys.remove_child(key)
			disconnect_key(key)
			NodePool.return_node(key)
	# or add them
	else:
		for i in range(current_keys, needed_keys):
			_spawn_key(level_data.keys[i])
	
	# Not gonna optimize entires rn. You shouldn't have that many anyways
	for child in entries.get_children():
		child.free()
	for entry in level_data.entries:
		_spawn_entry(entry)
	
	assert(PerfManager.end("Level::reset (keys)"))
	
	assert(PerfManager.start("Level::reset (tiles)"))
	tile_map.clear()
	for tile_coord in level_data.tiles:
		_spawn_tile(tile_coord, false)
	assert(PerfManager.end("Level::reset (tiles)"))
	
	_spawn_goal()
	_spawn_player()
	if exclude_player:
		camera.enabled = false
	else:
		camera.enabled = true
		camera.make_current()
	
	update_mouseover()
	
	is_autorun_on = false
	
	logic.reset()
	
	assert(PerfManager.end("Level::reset"))


func _connect_level_data() -> void:
	if not is_instance_valid(level_data): return
	# Must do this in case level data has no version
	level_data.check_valid(false)
	level_data.changed_player_spawn_position.connect(_update_player_spawn_position)
	_update_player_spawn_position()
	level_data.changed_goal_position.connect(_update_goal_position)
	_update_goal_position()
	level_data.changed_doors.connect(emit_signal.bind(&"changed_doors"))
	level_data.changed_keys.connect(emit_signal.bind(&"changed_keys"))
	reset()

func _disconnect_level_data() -> void:
	if not is_instance_valid(level_data): return
	var amount = Global.fully_disconnect(self, level_data)
	assert(amount == 4)

func _update_player_spawn_position() -> void:
	if not is_node_ready(): return
	if not level_data: return
	player_spawn_point.visible = Global.in_level_editor
	player_spawn_point.position = level_data.player_spawn_position

func _update_goal_position() -> void:
	if not is_node_ready(): return
	if not is_instance_valid(goal): return
	goal.position = level_data.goal_position + Vector2i(16, 16)

func try_open_door(door: Door) -> void:
	logic.try_open_door(door)


# Editor functions

signal door_gui_input(event: InputEvent, door: Door)
signal key_gui_input(event: InputEvent, key: Key)
signal entry_gui_input(event: InputEvent, entry: Entry)

## Adds a door to the level data. Returns null if it wasn't added
func add_door(door_data: DoorData) -> Door:
	if is_space_occupied(door_data.get_rect()): return null
	if not door_data.check_valid(level_data, true): return null
	if not door_data in level_data.doors:
		level_data.doors.push_back(door_data)
		level_data.changed_doors.emit()
	return _spawn_door(door_data)

## Makes a door physically appear (doesn't check collisions)
func _spawn_door(door_data: DoorData) -> Door:
	assert(PerfManager.start("Level::_spawn_door"))
	assert(PerfManager.start("Level::_spawn_door (instantiating)"))
	var door: Door = NodePool.pool_node(DOOR)
#	var door := DOOR.instantiate()
	assert(PerfManager.end("Level::_spawn_door (instantiating)"))
	var dd := door_data.duplicated()
	door.door_data = dd
	door.original_door_data = door_data
	connect_door(door)
	assert(PerfManager.start("Level::_spawn_door (adding child)"))
	doors.add_child(door)
	assert(PerfManager.end("Level::_spawn_door (adding child)"))
	assert(PerfManager.end("Level::_spawn_door"))
	return door

## Removes a door from the level data
func remove_door(door: Door) -> void:
	var pos := level_data.doors.find(door.original_door_data)
	assert(pos != -1)
	level_data.doors.remove_at(pos)
	doors.remove_child(door)
	disconnect_door(door)
#	door.queue_free()
	NodePool.return_node(door)
	level_data.changed_doors.emit()

## Moves a given door. Returns false if the move failed
func move_door(door: Door, new_position: Vector2i) -> bool:
	var door_data: DoorData = door.original_door_data
	var i := level_data.doors.find(door_data)
	assert(i != -1)
	assert(door_data.get_rect() == Rect2i(door_data.position, door_data.get_rect().size))
	var rect := Rect2i(new_position, door_data.get_rect().size)
	if not is_space_occupied(rect, [], [door_data]):
		door_data.position = new_position
		door.door_data.position = new_position
		level_data.changed_doors.emit()
		return true
	else:
		return false

## Adds a key to the level data. Returns null if it wasn't added
func add_key(key_data: KeyData) -> Key:
	if is_space_occupied(key_data.get_rect()): return null
	if not key_data in level_data.keys:
		level_data.keys.push_back(key_data)
		level_data.changed_keys.emit()
	return _spawn_key(key_data)

## Makes a key physically appear (doesn't check collisions)
func _spawn_key(key_data: KeyData) -> Key:
	var key: Key = NodePool.pool_node(KEY)
	key.key_data = key_data.duplicated()
	key.set_meta(&"original_key_data", key_data)
	connect_key(key)
	key.level = self
	keys.add_child(key)
	return key

## Removes a key from the level data
func remove_key(key: Key) -> void:
	var i := level_data.keys.find(key.get_meta(&"original_key_data"))
	assert(i != -1)
	level_data.keys.remove_at(i)
	keys.remove_child(key)
	disconnect_key(key)
	key.queue_free()
	level_data.changed_keys.emit()

## Moves a given key. Returns false if the move failed
func move_key(key: Key, new_position: Vector2i) -> bool:
	var key_data: KeyData = key.get_meta(&"original_key_data")
	var i := level_data.keys.find(key_data)
	assert(i != -1)
	assert(key_data.get_rect() == Rect2i(key_data.position, key_data.get_rect().size))
	var rect := Rect2i(new_position, key_data.get_rect().size)
	if not is_space_occupied(rect, [], [key_data]):
		key_data.position = new_position
		key.key_data.position = new_position
		level_data.changed_keys.emit()
		return true
	else:
		return false


## Adds an entry to the level data. Returns null if it wasn't added
func add_entry(entry_data: EntryData) -> Entry:
	if is_space_occupied(entry_data.get_rect()): return null
	if not entry_data in level_data.entries:
		level_data.entries.push_back(entry_data)
		level_data.changed_entries.emit()
	return _spawn_entry(entry_data)

## Makes an entry physically appear (doesn't check collisions)
func _spawn_entry(entry_data: EntryData) -> Entry:
	var entry: Entry = NodePool.pool_node(ENTRY)
	entry.entry_data = entry_data.duplicated()
	entry.set_meta(&"original_entry_data", entry_data)
	connect_entry(entry)
	entry.level = self
	assert(gameplay_manager.pack_data)
	entry.pack_data = gameplay_manager.pack_data
	entries.add_child(entry)
	return entry

## Removes an entry from the level data
func remove_entry(entry: Entry) -> void:
	var i := level_data.entries.find(entry.get_meta(&"original_entry_data"))
	assert(i != -1)
	level_data.entries.remove_at(i)
	entries.remove_child(entry)
	disconnect_entry(entry)
	entry.queue_free()
	level_data.changed_entries.emit()

## Moves a given entry. Returns false if the move failed
func move_entry(entry: Entry, new_position: Vector2i) -> bool:
	var entry_data: EntryData = entry.get_meta(&"original_entry_data")
	var i := level_data.entries.find(entry_data)
	assert(i != -1)
	assert(entry_data.get_rect() == Rect2i(entry_data.position, entry_data.get_rect().size))
	var rect := Rect2i(new_position, entry_data.get_rect().size)
	if not is_space_occupied(rect, [], [entry_data]):
		entry_data.position = new_position
		entry.entry_data.position = new_position
		level_data.changed_entries.emit()
		return true
	else:
		return false

func place_player_spawn(coord: Vector2i) -> void:
	if is_space_occupied(Rect2i(coord, Vector2i(32, 32)), [&"player_spawn"]): return
	level_data.player_spawn_position = coord + Vector2i(14, 32)

func place_goal(coord: Vector2i) -> void:
	if is_space_occupied(Rect2i(coord, Vector2i(32, 32)), [&"goal"]): return
	level_data.goal_position = coord

func place_tile(tile_coord: Vector2i) -> void:
	if level_data.tiles.has(tile_coord): return
	if is_space_occupied(Rect2i(tile_coord * 32, Vector2i(32, 32)), [&"tiles"]): return
	level_data.tiles[tile_coord] = true
	_spawn_tile(tile_coord, true)
	level_data.changed_tiles.emit()

func _spawn_tile(tile_coord: Vector2i, also_update_neighbors: bool) -> void:
	var layer := 0
	var id := 1
	var what_tile := Vector2i(1,1)
	tile_map.set_cell(layer, tile_coord, id, what_tile)
	if also_update_neighbors:
		update_tile_and_neighbors(tile_coord)
	else:
		update_tile(tile_coord)

## Removes a tile from the level data. Returns true if a tile was there.
func remove_tile(tile_coord: Vector2i) -> bool:
	if not level_data.tiles.has(tile_coord): return false
	level_data.tiles.erase(tile_coord)
	var layer := 0
	tile_map.erase_cell(layer, tile_coord)
	level_data.changed_tiles.emit()
	update_tile_and_neighbors(tile_coord)
	return true

func update_tile_and_neighbors(center_tile_coord: Vector2i) -> void:
	for x in [-1, 0, 1]:
		for y in [-1, 0, 1]:
			update_tile(center_tile_coord + Vector2i(x, y))

const NEIGHBORS_ALL := [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1,  0),                  Vector2i(1,  0),
	Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1),
]
const NEIGHBORS_V := [Vector2i(0, -1), Vector2i(0, 1)]
const NEIGHBORS_H := [Vector2i(-1, 0), Vector2i(1, 0)]

## Autotiling!
func update_tile(tile_coord: Vector2i) -> void:
	if not level_data.tiles.get(tile_coord) == true: return
	var layer := 0
	var id := 1
	var what_tile := Vector2i(1,1)
	var neighbor_count := 0
	var all_count := count_tiles(NEIGHBORS_ALL, tile_coord)
	var h_count := count_tiles(NEIGHBORS_H, tile_coord)
	var v_count := count_tiles(NEIGHBORS_V, tile_coord)
	if all_count == 8:
		what_tile = Vector2i(0, 0)
	elif h_count == 2 and v_count != 2:
		what_tile = Vector2i(0, 1)
	elif v_count == 2 and h_count != 2:
		what_tile = Vector2i(1, 0)
	tile_map.set_cell(layer, tile_coord, id, what_tile)

func count_tiles(tiles: Array, offset: Vector2i) -> int:
	return tiles.reduce(func(acc:int, tile_coord: Vector2i) -> int:
		return acc + 1 if level_data.tiles.get(tile_coord+offset) == true else 0
		, 0)

func _spawn_player() -> void:
	if is_instance_valid(player):
		player_parent.remove_child(player)
		player.queue_free()
		player = null
	Global.is_playing = not exclude_player
	if exclude_player: return
	player = PLAYER.instantiate()
	player.position = level_data.player_spawn_position
	player_parent.add_child(player)
	player.level = self
	immediately_adjust_camera.call_deferred()

func _spawn_goal() -> void:
	if is_instance_valid(goal):
		goal_parent.remove_child(goal)
		goal.queue_free()
	goal = GOAL.instantiate()
	goal.position = level_data.goal_position + Vector2i(16, 16)
	goal.level = self
	goal_parent.add_child(goal)

## Returns true if there's a tile, door, key, entry, or player spawn position inside the given rect, or if the rect falls outside the level boundaries
# TODO: Optimize this obviously. mainly tiles OBVIOUSLY
func is_space_occupied(rect: Rect2i, exclusions: Array[String] = [], excluded_objects: Array[Object] = []) -> bool:
	if not is_space_inside(rect):
		return true
	if not &"doors" in exclusions:
		for door in level_data.doors:
			if door in excluded_objects: continue
			if door.get_rect().intersects(rect):
				return true
	if not &"keys" in exclusions:
		for key in level_data.keys:
			if key in excluded_objects: continue
			if key.get_rect().intersects(rect):
				return true
	if not &"entries" in exclusions:
		for entry in level_data.entries:
			if entry in excluded_objects: continue
			if entry.get_rect().intersects(rect):
				return true
	if not &"goal" in exclusions:
		if Rect2i((level_data.goal_position), Vector2i(32, 32)).intersects(rect):
			return true
	if not &"player_spawn" in exclusions:
		var spawn_pos := (level_data.player_spawn_position - Vector2i(14, 32))
		if Rect2i(spawn_pos, Vector2i(32, 32)).intersects(rect):
			return true
	if not &"tiles" in exclusions:
		for tile_pos in level_data.tiles:
			if Rect2i(tile_pos * 32, Vector2i(32, 32)).intersects(rect):
				return true
	return false

## Returns true if the space is fully inside the level
func is_space_inside(rect: Rect2i) -> bool:
	return Rect2i(Vector2i.ZERO, level_data.size).encloses(rect)

func on_door_opened(_door: Door) -> void:
	update_mouseover()

func _on_door_changed_curse(_door: Door) -> void:
	update_mouseover()

func _on_key_picked_up(_key: Key) -> void:
	update_mouseover()

func _on_door_gui_input(event: InputEvent, door: Door) -> void:
	door_gui_input.emit(event, door)

func _on_key_gui_input(event: InputEvent, key: Key) -> void:
	key_gui_input.emit(event, key)

func _on_entry_gui_input(event: InputEvent, entry: Entry) -> void:
	entry_gui_input.emit(event, entry)

func _on_door_mouse_entered(door: Door) -> void:
	hover_highlight.adapt_to(door)

func _on_door_mouse_exited(door: Door) -> void:
	hover_highlight.stop_adapting_to(door)

func _on_key_mouse_entered(key: Key) -> void:
	hover_highlight.adapt_to(key)

func _on_key_mouse_exited(key: Key) -> void:
	hover_highlight.stop_adapting_to(key)

func _on_entry_mouse_entered(entry: Entry) -> void:
	hover_highlight.adapt_to(entry)

func _on_entry_mouse_exited(entry: Entry) -> void:
	hover_highlight.stop_adapting_to(entry)

func _on_hover_adapted_to(_what: Node) -> void:
	update_mouseover()

func update_mouseover() -> void:
	mouseover.hide()
	var obj := hover_highlight.current_obj
	if obj:
		if obj.has_method("get_mouseover_text"):
			mouseover.text = obj.get_mouseover_text()
			mouseover.show()
		else:
			printerr("object %s doesn't have get_mouseover_text method" % obj)

func add_debris_child(debris: Node) -> void:
	debris_parent.add_child(debris)



func connect_door(door: Door) -> void:
	door.gui_input.connect(_on_door_gui_input.bind(door))
	door.mouse_entered.connect(_on_door_mouse_entered.bind(door))
	door.mouse_exited.connect(_on_door_mouse_exited.bind(door))
	door.changed_curse.connect(_on_door_changed_curse.bind(door))
	door.level = self

func disconnect_door(door: Door) -> void:
	door.gui_input.disconnect(_on_door_gui_input.bind(door))
	door.mouse_entered.disconnect(_on_door_mouse_entered.bind(door))
	door.mouse_exited.disconnect(_on_door_mouse_exited.bind(door))
	door.changed_curse.disconnect(_on_door_changed_curse.bind(door))
	door.level = null

func connect_key(key: Key) -> void:
	key.gui_input.connect(_on_key_gui_input.bind(key))
	key.mouse_entered.connect(_on_key_mouse_entered.bind(key))
	key.mouse_exited.connect(_on_key_mouse_exited.bind(key))
	key.picked_up.connect(_on_key_picked_up.bind(key))

func disconnect_key(key: Key) -> void:
	key.gui_input.disconnect(_on_key_gui_input.bind(key))
	key.mouse_entered.disconnect(_on_key_mouse_entered.bind(key))
	key.mouse_exited.disconnect(_on_key_mouse_exited.bind(key))
	key.picked_up.disconnect(_on_key_picked_up.bind(key))

func connect_entry(entry: Entry) -> void:
	entry.gui_input.connect(_on_entry_gui_input.bind(entry))
	entry.mouse_entered.connect(_on_entry_mouse_entered.bind(entry))
	entry.mouse_exited.connect(_on_entry_mouse_exited.bind(entry))

func disconnect_entry(entry: Entry) -> void:
	entry.gui_input.disconnect(_on_entry_gui_input.bind(entry))
	entry.mouse_entered.disconnect(_on_entry_mouse_entered.bind(entry))
	entry.mouse_exited.disconnect(_on_entry_mouse_exited.bind(entry))

func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		remove_all_pooled()

func remove_all_pooled() -> void:
	var c := doors.get_children()
	c.reverse()
	for door in c:
		doors.remove_child(door)
		disconnect_door(door)
		NodePool.return_node(door)
	c = keys.get_children()
	c.reverse()
	for key in c:
		keys.remove_child(key)
		disconnect_key(key)
		NodePool.return_node(key)

func limit_camera() -> void:
	var limit := Vector2(
		level_data.size.x - get_viewport_rect().size.x
		, level_data.size.y - get_viewport_rect().size.y
	)
	# custom clamp in case limit goes under 0
	# TODO
	camera.position.x = minf(camera.position.x, limit.x)
	camera.position.x = maxf(camera.position.x, 0)
	camera.position.y = minf(camera.position.y, limit.y)
	camera.position.y = maxf(camera.position.y, 0)
	#camera.position = camera.position.clamp(Vector2(0, 0), limit)

func adjust_camera() -> void:
	if not is_instance_valid(player): return
	camera.position = player.position - get_viewport_rect().size / 2
	limit_camera()

func immediately_adjust_camera() -> void:
	if not is_instance_valid(player): return
	adjust_camera()
	camera.reset_smoothing()

func get_camera_position() -> Vector2:
	return camera.position
