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

## If true, output points' doors will be loaded, if available.
@export var load_output_points := true

# makes it so the level doesn't set Global.current_level to itself
var dont_make_current := false

const DOOR := preload("res://level_elements/doors_locks/door.tscn")
const KEY := preload("res://level_elements/keys/key.tscn")
const ENTRY := preload("res://level_elements/entries/entry.tscn")
const SALVAGE_POINT := preload("res://level_elements/salvage_points/salvage_point.tscn")
const PLAYER := preload("res://level_elements/kid/kid.tscn")
const GOAL := preload("res://level_elements/goal/goal.tscn")

@onready var doors: Node2D = %Doors
@onready var keys: Node2D = %Keys
@onready var entries: Node2D = %Entries
@onready var salvage_points: Node2D = %SalvagePoints
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

var collision_system: CollisionSystem:
	get:
		return level_data.collision_system

var player: Kid
var goal: LevelGoal

var autorun_tween: Tween

# elements will have a duplicate of the data stored in level_data. this lets you find the original when needed.
var element_to_original_data := {}
var original_data_to_element := {}

@onready var level_element_type_to_container := {
	Enums.level_element_types.door: doors,
	Enums.level_element_types.key: keys,
	Enums.level_element_types.entry: entries,
	Enums.level_element_types.salvage_point: salvage_points,
}

# Updated when connecting the level_data
var level_element_type_to_level_data_array := {}

const LEVEL_ELEMENT_TO_SCENE := {
	Enums.level_element_types.door: DOOR,
	Enums.level_element_types.key: KEY,
	Enums.level_element_types.entry: ENTRY,
	Enums.level_element_types.salvage_point: SALVAGE_POINT,
};

var LEVEL_ELEMENT_CONNECT := {
	Enums.level_element_types.door: connect_door,
	Enums.level_element_types.key: connect_key
};

var LEVEL_ELEMENT_DISCONNECT := {
	Enums.level_element_types.door: disconnect_door,
	Enums.level_element_types.key: disconnect_key
};

## For selection system
var dont_update_collision_system: bool = false

func _unhandled_key_input(event: InputEvent) -> void:
	if not Global.is_playing: return
	if in_transition(): return
	if event.is_action_pressed(&"i-view"):
		logic.i_view = not logic.i_view
		i_view_sound_1.play()
		i_view_sound_2.play()
	elif event.is_action_pressed(&"restart"):
		gameplay_manager.reset()
	elif event.is_action_pressed(&"exit_level"):
		gameplay_manager.exit_level()
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
		Global.settings.is_autorun_on = !Global.settings.is_autorun_on
		var used: Sprite2D
		if Global.settings.is_autorun_on:
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
	
	var mouse_pos := get_local_mouse_position()
	var camera_rect := Rect2(camera.position, camera.get_viewport_rect().size)
	if not camera_rect.has_point(mouse_pos):
		hover_highlight.stop_adapting()

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
	level_data.regen_collision_system()
	
	for salvage_point: SalvagePoint in salvage_points.get_children():
		salvage_point.remove_door()
	
	# This initial stuff looks ugly for optimization's sake
	# (yes, it makes a measurable impact, specially on big levels)
	for type in Enums.level_element_types.values():
		assert(PerfManager.start("Level::reset (" + str(type) + ")"))

		var list: Array = level_element_type_to_level_data_array[type]
		var container: Node2D = level_element_type_to_container[type]

		var needed := list.size()
		var current := container.get_child_count()
		# redo the current ones
		for i in mini(needed, current):
			var node := container.get_child(i)
			var original_data = list[i]
			element_to_original_data[node] = original_data
			original_data_to_element[original_data] = node
			node.data = original_data.duplicated()
		# shave off the rest
		if current > needed:
			for _i in current - needed:
				var node := container.get_child(-1)
				_remove_element(node)
		# or add them
		else:
			for i in range(current, needed):
				_spawn_element(list[i])
		assert(PerfManager.end("Level::reset (" + str(type) + ")"))
	
	assert(PerfManager.start("Level::reset (tiles)"))
	tile_map.clear()
	for tile_coord in level_data.tiles:
		update_tile(tile_coord)
	assert(PerfManager.end("Level::reset (tiles)"))
	
	_spawn_goal()
	_spawn_player()
	if exclude_player:
		camera.enabled = false
	else:
		camera.enabled = true
		camera.make_current()
	
	logic.reset()
	
	update_mouseover()
	
	assert(PerfManager.end("Level::reset"))


func _connect_level_data() -> void:
	if not is_instance_valid(level_data): return
	level_element_type_to_level_data_array = {
		Enums.level_element_types.door: level_data.doors,
		Enums.level_element_types.key: level_data.keys,
		Enums.level_element_types.entry: level_data.entries,
		Enums.level_element_types.salvage_point: level_data.salvage_points,
	}
	# Must do this in case level data has no version
	level_data.check_valid(false)
	level_data.changed_player_spawn_position.connect(_update_player_spawn_position)
	_update_player_spawn_position()
	level_data.changed_goal_position.connect(_update_goal_position)
	_update_goal_position()

func _disconnect_level_data() -> void:
	if not is_instance_valid(level_data): return
	var amount = Global.fully_disconnect(self, level_data)
	assert(amount == 2)

func _update_player_spawn_position() -> void:
	if not is_node_ready(): return
	if not level_data: return
	player_spawn_point.visible = Global.in_level_editor
	player_spawn_point.position = level_data.player_spawn_position
	if not dont_update_collision_system:
		var id: int
		if level_data.elem_to_collision_system_id.has(&"player_spawn"):
			id = level_data.elem_to_collision_system_id[&"player_spawn"]
			collision_system.remove_rect(id)
		id = collision_system.add_rect(Rect2i(level_data.player_spawn_position - Vector2i(14, 32), Vector2i(32, 32)), &"player_spawn")
		level_data.elem_to_collision_system_id[&"player_spawn"] = id

func _update_goal_position() -> void:
	if not is_node_ready(): return
	if not level_data.has_goal:
		if is_instance_valid(goal):
			goal.queue_free()
	else:
		if not is_instance_valid(goal):
			_spawn_goal()
		goal.position = level_data.goal_position + Vector2i(16, 16)
	if not dont_update_collision_system:
		var id: int
		if level_data.elem_to_collision_system_id.has(&"goal"):
			id = level_data.elem_to_collision_system_id[&"goal"]
			collision_system.remove_rect(id)
		if level_data.has_goal:
			id = collision_system.add_rect(Rect2i(level_data.goal_position, Vector2i(32, 32)), &"goal")
			level_data.elem_to_collision_system_id[&"goal"] = id
		else:
			level_data.elem_to_collision_system_id.erase(&"goal")

func try_open_door(door: Door) -> void:
	logic.try_open_door(door)


# Editor functions

signal element_gui_input(event: InputEvent, node: Node, type: Enums.level_element_types)

func _input(event: InputEvent):
	if event is InputEventMouseMotion:
		update_mouseover()

func update_hover():
	var pos := get_local_mouse_position()
	var node := get_object_occupying(pos.floor())
	hover_highlight.adapt_to(node, true)

## Adds *something* to the level data. Returns null if it wasn't added
func add_element(data) -> Node:
	var type: Enums.level_element_types = data.level_element_type
	if is_space_occupied(data.get_rect()): return null
	if type == Enums.level_element_types.door:
		if not data.check_valid(level_data, true): return null
	var list: Array = level_element_type_to_level_data_array[type]
	if not data in list:
		list.push_back(data)
		
		var id := collision_system.add_rect(data.get_rect(), data)
		level_data.elem_to_collision_system_id[data] = id
		level_data.emit_changed()
	return _spawn_element(data)

## Makes *something* physically appear (doesn't check collisions)
func _spawn_element(data) -> Node:
	var type: Enums.level_element_types = data.level_element_type
	assert(PerfManager.start("Level::_spawn_element (%d)" % type))
	var node := NodePool.pool_node(LEVEL_ELEMENT_TO_SCENE[type])
	var dupe = data.duplicated()
	
	node.level = self
	node.data = dupe
	
	element_to_original_data[node] = data
	original_data_to_element[data] = node
	
	node.gui_input.connect(_on_element_gui_input.bind(node, type))
	if LEVEL_ELEMENT_CONNECT.has(type):
		LEVEL_ELEMENT_CONNECT[type].call(node)
	level_element_type_to_container[type].add_child(node)
	assert(PerfManager.end("Level::_spawn_element (%d)" % type))
	return node

## Removes *something* from the level data
func remove_element(node: Node) -> void:
	var type: Enums.level_element_types = node.level_element_type
	var original_data = element_to_original_data[node]
	var list: Array = level_element_type_to_level_data_array[type]
	var i := list.find(original_data)
	if i != -1:
		list.remove_at(i)
		
		var id: int = level_data.elem_to_collision_system_id[original_data]
		level_data.elem_to_collision_system_id.erase(original_data)
		collision_system.remove_rect(id)
	_remove_element(node)
	level_data.emit_changed()

func _remove_element(node: Node) -> void:
	var type: Enums.level_element_types = node.level_element_type
	node.get_parent().remove_child(node)
	
	var original_data = element_to_original_data[node]
	element_to_original_data.erase(node)
	original_data_to_element.erase(original_data)
	
	node.gui_input.disconnect(_on_element_gui_input.bind(node, type))
	if LEVEL_ELEMENT_DISCONNECT.has(type):
		LEVEL_ELEMENT_DISCONNECT[type].call(node)
	node.level = null
	
	NodePool.return_node(node)

## Moves *something*. Returns false if the move failed
func move_element(node: Node, new_position: Vector2i, update_collision_system: bool = true) -> bool:
	var type: Enums.level_element_types = node.level_element_type
	var original_data = element_to_original_data[node]
	var list: Array = level_element_type_to_level_data_array[type]
	var i := list.find(original_data)
	assert(i != -1)
	
	var rect := Rect2i(new_position, original_data.get_rect().size)
	if not is_space_occupied(rect, [], [original_data]):
		node.position = new_position
		original_data.position = new_position
		node.data.position = new_position
		
		if update_collision_system:
			var id: int = level_data.elem_to_collision_system_id[original_data]
			collision_system.remove_rect(id)
			id = collision_system.add_rect(original_data.get_rect(), original_data)
			level_data.elem_to_collision_system_id[original_data] = id
			level_data.emit_changed()
		return true
	else:
		return false

func place_player_spawn(coord: Vector2i) -> void:
	if is_space_occupied(Rect2i(coord, Vector2i(32, 32)), [], [&"player_spawn"]): return
	level_data.player_spawn_position = coord + Vector2i(14, 32)

func place_goal(coord: Vector2i) -> void:
	if is_space_occupied(Rect2i(coord, Vector2i(32, 32)), [], [&"goal"]): return
	level_data.goal_position = coord

func place_tile(tile_coord: Vector2i, update_collision_system: bool = true) -> void:
	if level_data.tiles.get(tile_coord): return
	if is_space_occupied(Rect2i(tile_coord * 32, Vector2i(32, 32)), [&"tiles"]): return
	level_data.tiles[tile_coord] = 1
	update_tile_and_neighbors(tile_coord)
	if update_collision_system:
		var id := collision_system.add_rect(Rect2i(tile_coord * 32, Vector2i(32, 32)), tile_coord)
		level_data.elem_to_collision_system_id[tile_coord] = id
		level_data.emit_changed()

## Removes a tile from the level data. Returns true if a tile was there.
func remove_tile(tile_coord: Vector2i, update_collision_system: bool = true) -> bool:
	if not level_data.tiles.has(tile_coord): return false
	level_data.tiles.erase(tile_coord)
	if update_collision_system:
		var id: int = level_data.elem_to_collision_system_id[tile_coord]
		level_data.elem_to_collision_system_id.erase(tile_coord)
		collision_system.remove_rect(id)
	var layer := 0
	tile_map.erase_cell(layer, tile_coord)
	level_data.emit_changed()
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
const NEIGHBORS_U := [Vector2i(-1, -1), Vector2i( 0, -1), Vector2i( 1, -1)]
const NEIGHBORS_D := [Vector2i(-1,  1), Vector2i( 0,  1), Vector2i( 1,  1)]
const NEIGHBORS_L := [Vector2i(-1, -1), Vector2i(-1,  0), Vector2i(-1,  1)]
const NEIGHBORS_R := [Vector2i( 1, -1), Vector2i( 1,  0), Vector2i( 1,  1)]
const NEIGHBOR_U := [Vector2i( 0, -1)]
const NEIGHBOR_D := [Vector2i( 0,  1)]
const NEIGHBOR_L := [Vector2i(-1,  0)]
const NEIGHBOR_R := [Vector2i( 1,  0)]

const TILE_LOOKUP_ORDER: Array = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1,  0),                  Vector2i(1,  0),
	Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1),
]

static var tiling_lookup := create_tiling_lookup()

static func create_tiling_lookup() -> PackedInt32Array:
	var array := PackedInt32Array()
	array.resize(256)
	for i in 256:
		var what_tile = get_autotiling_tile(i)
		array[i] = ((what_tile.x << 16) + what_tile.y)
	return array

static func count_tiles_bits(tiles: Array, bits: int) -> int:
	var count := 0
	var bit := 1
	for vec in TILE_LOOKUP_ORDER:
		if (bit & bits) != 0 and vec in tiles:
			count += 1
		bit *= 2
	return count

static func get_autotiling_tile(bits: int) -> Vector2i:
	var what_tile := Vector2i(1,1)
	var all_count := count_tiles_bits(NEIGHBORS_ALL, bits)
	var h_count := count_tiles_bits(NEIGHBORS_H, bits)
	var v_count := count_tiles_bits(NEIGHBORS_V, bits)
	if all_count == 8:
		what_tile = Vector2i(0, 0)
	elif h_count == 2 and v_count != 2:
		what_tile = Vector2i(0, 1)
		if count_tiles_bits(NEIGHBOR_U, bits) == 1:
			if count_tiles_bits(NEIGHBORS_U, bits) != 3:
				what_tile = Vector2i(1, 1)
		if count_tiles_bits(NEIGHBOR_D, bits) == 1:
			if count_tiles_bits(NEIGHBORS_D, bits) != 3:
				what_tile = Vector2i(1, 1)
	elif v_count == 2 and h_count != 2:
		what_tile = Vector2i(1, 0)
		if count_tiles_bits(NEIGHBOR_L, bits) == 1:
			if count_tiles_bits(NEIGHBORS_L, bits) != 3:
				what_tile = Vector2i(1, 1)
		if count_tiles_bits(NEIGHBOR_R, bits) == 1:
			if count_tiles_bits(NEIGHBORS_R, bits) != 3:
				what_tile = Vector2i(1, 1)
	return what_tile

## Autotiling!
func update_tile(tile_coord: Vector2i) -> void:
	if not level_data.tiles.get(tile_coord): return
	var layer := 0
	var id := 1
	var level_width: int = level_data.size.x / 32
	var level_height: int = level_data.size.y / 32
	
	var bits := 0
	var vec: Vector2i
	for i in TILE_LOOKUP_ORDER.size():
		vec = TILE_LOOKUP_ORDER[i] + tile_coord
		if level_data.tiles.get(vec) or vec.x < 0 or vec.y < 0 or vec.x >= level_width or vec.y >= level_height:
			bits |= 1 << i
	var what_tile := tiling_lookup[bits]
	tile_map.set_cell(layer, tile_coord, id, Vector2i(what_tile >> 16, what_tile & 0xFFFF))

func count_tiles(tiles: Array, offset: Vector2i) -> int:
	return tiles.reduce(
		func(acc:int, tile_coord: Vector2i) -> int:
			var add := (1 if level_data.tiles.get(tile_coord+offset) == true else 0)
			return acc + add
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
	if not level_data.has_goal:
		return
	goal = GOAL.instantiate()
	goal.position = level_data.goal_position + Vector2i(16, 16)
	goal.level = self
	goal_parent.add_child(goal)

## Returns true if there's a tile, door, key, entry, or player spawn position inside the given rect, or if the rect falls outside the level boundaries
func is_space_occupied(rect: Rect2i, exclusions: Array[String] = [], excluded_data := []) -> bool:
	if not is_space_inside(rect):
		return true
	# Currently the collision system accounts for doors, keys, entries, salvages, tiles, goal and player spawn
	if exclusions.is_empty() and excluded_data.is_empty():
		return collision_system.rect_has_collision_in_grid(rect)
	else:
		var dict: Dictionary = collision_system.get_rects_intersecting_rect_in_grid(rect)
		for id in dict.keys():
			var obj = collision_system.get_rect_data(id)
			if obj in excluded_data:
				continue
			if obj is Vector2i and not &"tiles" in exclusions:
				return true
			if obj is DoorData and not &"doors" in exclusions:
				return true
			if obj is KeyData and not &"keys" in exclusions:
				return true
			if obj is EntryData and not &"entries" in exclusions:
				return true
			if obj is SalvagePointData and not &"salvage_points" in exclusions:
				return true
	return false

## Returns the object at that position.
func get_object_occupying(pos: Vector2i) -> Node:
	var rect_ids := collision_system.get_rects_containing_point_in_grid(pos)
	for id in rect_ids:
		var obj = collision_system.get_rect_data(id)
		if original_data_to_element.has(obj):
			var element: Node = original_data_to_element[obj]
			# Invisible elements include: opened doors, picked up keys, and output points after spawning a door.
			if not element.visible:
				continue;
			return element;
	return null

## Returns true if there's not enough space to fit a salvage
## this cares about doors and tiles CURRENTLY in the level, not in the level data
# TODO: revamp
func is_salvage_blocked(rect: Rect2i, exclude: Door) -> bool:
	return is_space_occupied(rect, [&"salvage_points"], [element_to_original_data[exclude]])

## Returns true if the space is fully inside the level
func is_space_inside(rect: Rect2i) -> bool:
	return Rect2i(Vector2i.ZERO, level_data.size).encloses(rect)

func on_door_opened(_door: Door) -> void:
	update_mouseover()

func _on_door_changed_curse(_door: Door) -> void:
	update_mouseover()

func _on_key_picked_up(_key: KeyElement) -> void:
	update_mouseover()

func _on_element_gui_input(event: InputEvent, node: Node, type: Enums.level_element_types) -> void:
	element_gui_input.emit(event, node, type)

func _on_hover_adapted_to(_what: Node) -> void:
	update_mouseover()

func update_mouseover() -> void:
	update_hover()
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
	door.changed_curse.connect(_on_door_changed_curse.bind(door))

func disconnect_door(door: Door) -> void:
	door.changed_curse.disconnect(_on_door_changed_curse.bind(door))

func connect_key(key: KeyElement) -> void:
	key.picked_up.connect(_on_key_picked_up.bind(key))

func disconnect_key(key: KeyElement) -> void:
	key.picked_up.disconnect(_on_key_picked_up.bind(key))

func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		remove_all_pooled()
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		hover_highlight.stop_adapting()

func remove_all_pooled() -> void:
	for type in Enums.level_element_types.values():
		var container: Node2D = level_element_type_to_container[type]
		var c := container.get_children()
		c.reverse()
		for node in c:
			_remove_element(node)

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

func in_transition() -> bool:
	var transition := gameplay_manager.transition
	var stage = transition.animation_stage
	
	return stage == 0 or stage == 1
