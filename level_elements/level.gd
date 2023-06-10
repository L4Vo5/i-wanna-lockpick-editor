extends Node2D
class_name Level

signal changed_glitch_color
var glitch_color := Enums.colors.glitch:
	set(val):
		if glitch_color == val: return
		glitch_color = val
		changed_glitch_color.emit()

@export var level_data: LevelData = null:
	set(val):
		if level_data == val: return
		_disconnect_level_data()
		level_data = val
		_connect_level_data()

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

# Some code might depend on these complex numbers' changed signals, so don't change them to new numbers pls
var key_counts := {
	Enums.colors.glitch: ComplexNumber.new(),
	Enums.colors.black: ComplexNumber.new(),
	Enums.colors.white: ComplexNumber.new(),
	Enums.colors.pink: ComplexNumber.new(),
	Enums.colors.orange: ComplexNumber.new(),
	Enums.colors.purple: ComplexNumber.new(),
	Enums.colors.cyan: ComplexNumber.new(),
	Enums.colors.red: ComplexNumber.new(),
	Enums.colors.green: ComplexNumber.new(),
	Enums.colors.blue: ComplexNumber.new(),
	Enums.colors.brown: ComplexNumber.new(),
	Enums.colors.pure: ComplexNumber.new(),
	Enums.colors.master: ComplexNumber.new(),
	Enums.colors.stone: ComplexNumber.new(),
}
# This function call was made to ensure that. it'll run every frame and double check that the objects don't change
const ENSURE_KEY_COUNTS := true
var star_keys := {
	Enums.colors.glitch: false,
	Enums.colors.black: false,
	Enums.colors.white: false,
	Enums.colors.pink: false,
	Enums.colors.orange: false,
	Enums.colors.purple: false,
	Enums.colors.cyan: false,
	Enums.colors.red: false,
	Enums.colors.green: false,
	Enums.colors.blue: false,
	Enums.colors.brown: false,
	Enums.colors.pure: false,
	Enums.colors.master: false,
	Enums.colors.stone: false,
}
# Not really a setter, just used for undo/redo
func set_star_key(color: Enums.colors, val: bool) -> void:
	star_keys[color] = val


const DOOR := preload("res://level_elements/doors_locks/door.tscn")
const KEY := preload("res://level_elements/keys/key.tscn")
const PLAYER := preload("res://level_elements/kid/kid.tscn")
const GOAL := preload("res://level_elements/goal/goal.tscn")

@onready var doors: Node2D = %Doors
@onready var keys: Node2D = %Keys
@onready var tile_map: TileMap = %TileMap
@onready var player_spawn_point: Sprite2D = %PlayerSpawnPoint
@onready var debris_parent: Node2D = %DebrisParent
@onready var i_view_sound_1: AudioStreamPlayer = %IView1
@onready var i_view_sound_2: AudioStreamPlayer = %IView2
@onready var undo_sound: AudioStreamPlayer = %Undo
@onready var autorun_sound: AudioStreamPlayer = %Autorun
@onready var autorun_off: Sprite2D = %AutorunOff
@onready var autorun_on: Sprite2D = %AutorunOn

@onready var hover_highlight: HoverHighlight = %HoverHighlight
var hovering_over: Node:
	get:
		return hover_highlight.current_obj

# undo/redo actions should be handled somewhere in here, too
var undo_redo: GoodUndoRedo

var player: Kid
var goal: LevelGoal
signal changed_i_view
var i_view := false:
	set(val):
		if i_view == val: return
		i_view = val
		changed_i_view.emit()

var is_autorun_on := false
var autorun_tween: Tween

# multiplier to how many times doors should try to be opened/copied
# useful for levels with a lot of door copies
var door_multiplier := 1

# will be true if level data hasn't changed
var can_soft_reset := false


func _init() -> void:
	undo_redo = GoodUndoRedo.new()
	if ENSURE_KEY_COUNTS:
		_ensure_key_counts()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"i-view") and not event.is_echo():
		if Global.is_playing:
			i_view = not i_view
			i_view_sound_1.play()
			i_view_sound_2.play()
	elif event.is_action_pressed(&"restart") and not event.is_echo():
		reset()
	elif event.is_action_pressed(&"undo"): # echos are allowed
		undo.call_deferred()
	# TODO: Make redo work properly (bugs related to standing on doors?)
#	elif event.is_action(&"redo") and event.is_pressed():
#		if not Global.is_playing: return
#		undo_redo.redo()
	elif event.is_action_pressed(&"savestate"):
		if not Global.is_playing: return
		start_undo_action()
		end_undo_action()
	elif event.is_action_pressed(&"autorun") and not event.is_echo():
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

var last_player_undo: Callable
var last_saved_player_undo: Callable
func _physics_process(_delta: float) -> void:
	if is_instance_valid(player):
		if player.on_floor:
			last_player_undo = player.get_undo_action()

# force_hard_reset is for benchmarking purposes
func reset(force_hard_reset := false) -> void:
	if not is_node_ready(): return
	assert(PerfManager.start("Level::reset"))
	
	if true:
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
#			key.original_key_data = level_data.keys[i]
#			key.door_data = key.original_key_data
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
		
		assert(PerfManager.end("Level::reset (keys)"))
		tile_map.clear()
		for tile_coord in level_data.tiles:
			_spawn_tile(tile_coord)
		
		_spawn_goal()
		_spawn_player()
		
	
#	if can_soft_reset and not force_hard_reset:
#		soft_reset()
#	else:
#		hard_reset()
	
	glitch_color = Enums.colors.glitch
	
	for color in key_counts.keys():
		key_counts[color].set_to(0, 0)
	for color in star_keys.keys():
		star_keys[color] = false
	
	undo_redo.clear_history()
	i_view = false
	is_autorun_on = false
	
	can_soft_reset = true
	assert(PerfManager.end("Level::reset"))
#	PerfManager.print_report()
#	PerfManager.clear()

# Hard resets by erasing and respawning everything
func hard_reset() -> void:
	if not is_node_ready(): return
		
	assert(PerfManager.start("Level::hard_reset"))
	# Clear everything
	assert(PerfManager.start("Level::hard_reset (clearing)"))
	# deleting the children in revere is faster than in the normal order
	# AND faster than queue_freeing the doors/keys variables
	remove_all_pooled()
#	var c
#	c = keys.get_children()
#	c.reverse()
#	for key in c:
#		keys.remove_child(key)
#		key.queue_free()
	
	tile_map.clear()
	assert(PerfManager.end("Level::hard_reset (clearing)"))
	
	# Spawn everything
#	var i := doors.get_index()
#	remove_child(doors)
	for door_data in level_data.doors:
		_spawn_door(door_data)
#	add_child(doors)
#	move_child(doors, i)
#	i = keys.get_index()
#	remove_child(keys)
	for key_data in level_data.keys:
		_spawn_key(key_data)
#	add_child(keys)
#	move_child(keys, i)
	for tile_coord in level_data.tiles:
		_spawn_tile(tile_coord)
	_spawn_goal()
	_spawn_player()
	assert(PerfManager.end("Level::hard_reset"))

func soft_reset() -> void:
	if not is_node_ready(): return
	if not can_soft_reset:
		reset()
		return
	assert(PerfManager.start("Level::soft_reset"))
	
	# update doors and keys
	for door in doors.get_children():
		door.door_data = door.get_meta(&"original_door_data").duplicated()
	for key in keys.get_children():
		key.key_data = key.get_meta(&"original_key_data").duplicated()
	
	# (tilemap stays as it is)
	
	# technically should just reposition the player and goal
	# this will kill and respawn them. not bad for performance tho since they're individual objects
	_spawn_goal()
	_spawn_player()
	
	assert(PerfManager.end("Level::soft_reset"))

func _connect_level_data() -> void:
	if not is_instance_valid(level_data): return
	# Must do this in case level data has no version
	level_data.check_version()
	level_data.check_valid()
	level_data.changed_player_spawn_position.connect(_update_player_spawn_position)
	_update_player_spawn_position()
	level_data.changed_goal_position.connect(_update_goal_position)
	_update_goal_position()
	level_data.changed_doors.connect(emit_signal.bind(&"changed_doors"))
	level_data.changed_keys.connect(emit_signal.bind(&"changed_keys"))
	# not actually needed, since when it changes on editor level reflects the changes always
#	level_data.changed.connect(set.bind(&"can_soft_reset", false))
	can_soft_reset = false
	reset()

func _disconnect_level_data() -> void:
	if not is_instance_valid(level_data): return
	var amount = Global.fully_disconnect(self, level_data)
	assert(amount == 4)
	can_soft_reset = false

func _update_player_spawn_position() -> void:
	if not is_node_ready(): return
	player_spawn_point.visible = Global.in_level_editor
	player_spawn_point.position = level_data.player_spawn_position

func _update_goal_position() -> void:
	if not is_node_ready(): return
	goal.position = level_data.goal_position + Vector2i(16, 16)

# Editor functions

signal door_clicked(event: InputEventMouseButton, door: Door)
signal key_clicked(event: InputEventMouseButton, key: Key)

## Adds a door to the level data. Returns null if it wasn't added
func add_door(door_data: DoorData) -> Door:
	if is_space_occupied(door_data.get_rect()): return null
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
	door.set_meta(&"original_door_data", door_data)
	connect_door(door)
	assert(PerfManager.start("Level::_spawn_door (adding child)"))
	doors.add_child(door)
	assert(PerfManager.end("Level::_spawn_door (adding child)"))
	assert(PerfManager.end("Level::_spawn_door"))
	return door

## Removes a door from the level data
func remove_door(door: Door) -> void:
	var pos := level_data.doors.find(door.get_meta(&"original_door_data"))
	assert(pos != -1)
	level_data.doors.remove_at(pos)
	doors.remove_child(door)
	disconnect_door(door)
#	door.queue_free()
	NodePool.return_node(door)
	level_data.changed_doors.emit()

## Moves a given door. Returns false if the move failed
func move_door(door: Door, new_position: Vector2i) -> bool:
	var door_data: DoorData = door.get_meta(&"original_door_data")
	var i := level_data.doors.find(door_data)
	assert(i != -1)
	assert(door_data.get_rect() == Rect2i(door_data.position, door_data.get_rect().size))
	var rect := Rect2i(new_position, door_data.get_rect().size)
	if not is_space_occupied(rect, [], [door_data]):
		door_data.position = new_position
		door.door_data.position = new_position
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
	_spawn_tile(tile_coord)

func _spawn_tile(tile_coord: Vector2i) -> void:
	var layer := 0
	var id := 1
	var what_tile := Vector2i(1,1)
	tile_map.set_cell(layer, tile_coord, id, what_tile)

## Removes a tile from the level data. Returns true if a tile was there.
func remove_tile(tile_coord: Vector2i) -> bool:
	if not level_data.tiles.has(tile_coord): return false
	level_data.tiles.erase(tile_coord)
	var layer := 0
	tile_map.erase_cell(layer, tile_coord)
	return true

func _spawn_player() -> void:
	if is_instance_valid(player):
		remove_child(player)
		player.queue_free()
		player = null
	Global.is_playing = not exclude_player
	if exclude_player: return
	player = PLAYER.instantiate()
	player.position = level_data.player_spawn_position
	add_child(player)
	
	undo_redo.start_action()
	undo_redo.add_undo_method(player.get_undo_action())
	undo_redo.commit_action()

func _spawn_goal() -> void:
	if is_instance_valid(goal):
		remove_child(goal)
		goal.queue_free()
	goal = GOAL.instantiate()
	goal.position = level_data.goal_position + Vector2i(16, 16)
	add_child(goal)

## Returns true if there's a tile, door, key, or player spawn position inside the given rect, or if the rect falls outside the level boundaries
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

func _on_door_clicked(event: InputEventMouseButton, door: Door):
	door_clicked.emit(event, door)

func _on_key_clicked(event: InputEventMouseButton, key: Key):
	key_clicked.emit(event, key)

func _on_door_mouse_entered(door: Door) -> void:
	hover_highlight.adapt_to(door)

func _on_door_mouse_exited(door: Door) -> void:
	hover_highlight.stop_adapting_to(door)

func _on_key_mouse_entered(key: Key) -> void:
	hover_highlight.adapt_to(key)

func _on_key_mouse_exited(key: Key) -> void:
	hover_highlight.stop_adapting_to(key)

func add_debris_child(debris: Node) -> void:
	debris_parent.add_child(debris)

func _ensure_key_counts():
	var original_key_counts = key_counts.duplicate()
	if not is_node_ready(): await ready
	while true:
		for color in original_key_counts:
			assert(key_counts[color] == original_key_counts[color])
		if not is_node_ready() or is_queued_for_deletion() or not is_instance_valid(get_tree()):
			push_warning("warning: stopped ensuring key counts for this level")
			return
		await get_tree().physics_frame

## A key, door, or anything else can call these functions to ensure that the undo_redo object is ready for writing
func start_undo_action() -> void:
	if last_player_undo == last_saved_player_undo:
		if undo_redo.get_action_count() > 1:
			undo_redo.start_merge_last()
			return
	undo_redo.start_action()
	
	undo_redo.add_do_method(last_player_undo)
	undo_redo.add_undo_method(last_player_undo)
	last_saved_player_undo = last_player_undo

## This is called after start_undo_action to finish the action
func end_undo_action() -> void:
	undo_redo.commit_action(false)
	# WAITING4GODOT: let me null callables damn it
#	last_saved_player_undo = func(): pass

# For legal reasons this should happen in a deferred call, so it's at the end of the frame and everything that happens in this frame had time to record their undo calls
func undo() -> void:
	if not Global.is_playing: return
	undo_sound.play()
	undo_redo.undo()
	last_player_undo = player.get_undo_action()
	if undo_redo.get_last_action() == -1:
		undo_redo._last_action = 0

func connect_door(door: Door) -> void:
	door.clicked.connect(_on_door_clicked.bind(door))
	door.mouse_entered.connect(_on_door_mouse_entered.bind(door))
	door.mouse_exited.connect(_on_door_mouse_exited.bind(door))

func disconnect_door(door: Door) -> void:
	door.clicked.disconnect(_on_door_clicked.bind(door))
	door.mouse_entered.disconnect(_on_door_mouse_entered.bind(door))
	door.mouse_exited.disconnect(_on_door_mouse_exited.bind(door))

func connect_key(key: Key) -> void:
	key.clicked.connect(_on_key_clicked.bind(key))
	key.mouse_entered.connect(_on_key_mouse_entered.bind(key))
	key.mouse_exited.connect(_on_key_mouse_exited.bind(key))

func disconnect_key(key: Key) -> void:
	key.clicked.disconnect(_on_key_clicked.bind(key))
	key.mouse_entered.disconnect(_on_key_mouse_entered.bind(key))
	key.mouse_exited.disconnect(_on_key_mouse_exited.bind(key))

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
