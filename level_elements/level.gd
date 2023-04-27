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


const DOOR := preload("res://level_elements/doors_locks/door.tscn")
const KEY := preload("res://level_elements/keys/key.tscn")
const PLAYER := preload("res://level_elements/kid/kid.tscn")
const GOAL := preload("res://level_elements/goal/goal.tscn")

@onready var doors: Node2D = %Doors
@onready var keys: Node2D = %Keys
@onready var tile_map: TileMap = %TileMap
@onready var player_spawn_point: Sprite2D = %PlayerSpawnPoint
@onready var debris_parent: Node2D = %DebrisParent

# undo/redo actions should be handled somewhere in here, too

var player: Kid
var goal: LevelGoal
signal changed_i_view
var i_view := false

# multiplier to how many times doors should try to be opened/copied
# useful for levels with a lot of door copies
var door_multiplier := 1

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action(&"i-view") and event.is_pressed() and not event.is_echo():
		i_view = not i_view
		changed_i_view.emit()
	if event.is_action(&"restart") and event.is_pressed():
		reset()

var is_ready := false
func _ready() -> void:
	is_ready = true
	Global.current_level = self
	reset()
	_update_player_spawn_position()


func reset() -> void:
	if not is_ready: return
	# Clear everything
	for child in doors.get_children():
		child.queue_free()
	for key in keys.get_children():
		key.queue_free()
	glitch_color = Enums.colors.glitch
	for color in key_counts.keys():
		key_counts[color].set_to(0, 0)
	for color in star_keys.keys():
		star_keys[color] = false
	i_view = false
	tile_map.clear()
	
	# Spawn everything
	# Player has to go first so the last one is deleted before objects are spawned
	for door_data in level_data.doors:
		_spawn_door(door_data)
	for key_data in level_data.keys:
		_spawn_key(key_data)
	for tile_coord in level_data.tiles:
		_spawn_tile(tile_coord)
	_spawn_goal()
	_spawn_player()

func _connect_level_data() -> void:
	if not is_instance_valid(level_data): return
	# Must do this in case level data has no version
	level_data.check_version()
	level_data.check_valid()
	level_data.changed_player_spawn_position.connect(_update_player_spawn_position)
	_update_player_spawn_position()
	level_data.changed_goal_position.connect(_update_goal_position)
	_update_goal_position()
	reset()

func _disconnect_level_data() -> void:
	if not is_instance_valid(level_data): return
	level_data.changed_player_spawn_position.disconnect(_update_player_spawn_position)

func _update_player_spawn_position() -> void:
	if not is_ready: return
	player_spawn_point.visible = Global.in_level_editor
	player_spawn_point.position = level_data.player_spawn_position

func _update_goal_position() -> void:
	if not is_ready: return
	goal.position = level_data.goal_position + Vector2i(16, 16)

# Editor functions

signal door_clicked(event: InputEventMouseButton, door: Door)
signal key_clicked(event: InputEventMouseButton, key: Key)

## Adds a door to the level data
func add_door(door_data: DoorData) -> Door:
	if is_space_occupied(door_data.get_rect()): return
	if not door_data in level_data.doors:
		level_data.doors.push_back(door_data)
	return _spawn_door(door_data)

func _spawn_door(door_data: DoorData) -> Door:
	var door := DOOR.instantiate()
	door.door_data = door_data.duplicated()
	door.set_meta(&"original_door_data", door_data)
	door.clicked.connect(_on_door_clicked.bind(door))
	doors.add_child(door)
	return door

## Removes a door from the level data
func remove_door(door: Door) -> void:
	level_data.doors.erase(door.get_meta(&"original_door_data"))
	door.queue_free()

## Adds a key to the level data
func add_key(key_data: KeyData) -> Key:
	if is_space_occupied(key_data.get_rect()): return
	if not key_data in level_data.keys:
		level_data.keys.push_back(key_data)
	return _spawn_key(key_data)

func _spawn_key(key_data: KeyData) -> Key:
	var key := KEY.instantiate()
	key.key_data = key_data.duplicated()
	key.set_meta(&"original_key_data", key_data)
	key.clicked.connect(_on_key_clicked.bind(key))
	keys.add_child(key)
	return key

## Removes a key from the level data
func remove_key(key: Key) -> void:
	level_data.keys.erase(key.get_meta(&"original_key_data"))
	key.queue_free()

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
	if exclude_player: return
	player = PLAYER.instantiate()
	player.position = level_data.player_spawn_position
	add_child(player)

func _spawn_goal() -> void:
	if is_instance_valid(goal):
		remove_child(goal)
		goal.queue_free()
	goal = GOAL.instantiate()
	goal.position = level_data.goal_position + Vector2i(16, 16)
	add_child(goal)

## Returns true if there's a tile, door, key, or player spawn position inside the given rect
# TODO: Optimize this obviously. mainly tiles OBVIOUSLY
func is_space_occupied(rect: Rect2i, exclusions: Array[String] = []) -> bool:
	if not &"doors" in exclusions:
		for door in level_data.doors:
			if door.get_rect().intersects(rect):
				return true
	if not &"keys" in exclusions:
		for key in level_data.keys:
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

func _on_door_clicked(event: InputEventMouseButton, door: Door):
	door_clicked.emit(event, door)

func _on_key_clicked(event: InputEventMouseButton, key: Key):
	key_clicked.emit(event, key)

func get_doors() -> Array[Door]:
	var arr: Array[Door] = []
	for child in get_children():
		if child is Door:
			arr.push_back(child)
	return arr

func add_debris_child(debris: Node) -> void:
	debris_parent.add_child(debris)
