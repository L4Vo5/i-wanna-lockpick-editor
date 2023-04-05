extends Node2D
class_name Level

signal changed_glitch_color
@export var glitch_color := Enums.colors.glitch:
	set(val):
		if glitch_color == val: return
		glitch_color = val
		changed_glitch_color.emit()
@export var level_data := LevelData.new()
# Some code might depend on these complex numbers' changed signals, so don't change them to new numbers pls
@export var key_counts := {
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
@export var star_keys := {
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

# undo/redo actions should be handled somewhere in here, too

var player: Kid
signal changed_i_view
var i_view := false

# multiplier to how many times doors should try to be opened/copied
# useful for levels with a lot of door copies
var door_multiplier := 1

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action(&"i-view") and event.is_pressed() and not event.is_echo():
		i_view = not i_view
		changed_i_view.emit()

var player_spawn_point: Sprite2D
func _ready() -> void:
	
	Global.current_level = self
	
	player_spawn_point = Sprite2D.new()
	player_spawn_point.texture = preload("res://editor/player_spawnpoint.png")
	player_spawn_point.position = level_data.player_spawn_position
	level_data.changed_player_spawn_position.connect(
		func():
			player_spawn_point.position = level_data.player_spawn_position
	)
	player_spawn_point.centered = false
	player_spawn_point.offset = Vector2i(-13, -34)
	player_spawn_point.visible = not Global.in_level_editor
	add_child(player_spawn_point)
	
	player = preload("res://level_elements/kid/kid.tscn").instantiate()
	player.position = level_data.player_spawn_position
	add_child(player)

const DOOR := preload("res://level_elements/doors_locks/door.tscn")
const KEY := preload("res://level_elements/keys/key.tscn")

# Editor functions

signal door_clicked(event: InputEventMouseButton, door: Door)
signal key_clicked(event: InputEventMouseButton, key: Key)

func add_door(door_data: DoorData) -> Door:
	var door := DOOR.instantiate()
	if not door_data in level_data.doors:
		level_data.doors.push_back(door_data)
	door.door_data = door_data
	door.clicked.connect(_on_door_clicked.bind(door))
	add_child(door)
	return door

func remove_door(door: Door) -> void:
	level_data.doors.erase(door.door_data)
	door.queue_free()

func add_key(key_data: KeyData) -> Key:
	var key := KEY.instantiate()
	key.key_data = key_data
	key.clicked.connect(_on_key_clicked.bind(key))
	add_child(key)
	return key

func remove_key(key: Key) -> void:
	level_data.keys.erase(key.key_data)
	key.queue_free()

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
