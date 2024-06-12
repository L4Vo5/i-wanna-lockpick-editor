@tool
extends Control
class_name SalvagePoint

static var level_element_type := Enums.level_element_types.salvage

@export var salvage_point_data: SalvagePointData:
	set(val):
		if salvage_point_data == val: return
		_disconnect_salvage_point_data()
		salvage_point_data = val
		_connect_salvage_point_data()

var level: Level
var level_pack_state: LevelPackStateData

var door: Door = null
@export var door_error = false
@export var door_error_size = false

@export var active = false
@export var ignore_position = false

@onready var sprite: Sprite2D = %Sprite
@onready var number: Label = %Number
@onready var snd_salvage_prep: AudioStreamPlayer = %SalvagePrep
@onready var collision: Area2D = %Collision
@onready var outline: Panel = %Outline

func _ready() -> void:
	collision.area_entered.connect(_on_touched)
	update_visual()

func prep_output_step_1() -> void:
	if not salvage_point_data.is_output:
		return
	var sid := salvage_point_data.sid
	if sid < 0 or sid >= level_pack_state.salvaged_doors.size():
		door = null
		return
	var new_door_data := level_pack_state.salvaged_doors[sid]
	if new_door_data == null:
		return
	new_door_data = new_door_data.duplicated()
	
	var new_position := Vector2()
	new_position.x = position.x + 16 - new_door_data.size.x / 2
	new_position.y = position.y + 32 - new_door_data.size.y

	new_door_data.position = new_position
	new_door_data.glitch_color = Enums.colors.glitch
	new_door_data.amount.set_to(1, 0)
	new_door_data.sid = sid
	door = level._spawn_element(new_door_data, Enums.level_element_types.door)
	door_error = false

func prep_output_step_2() -> void:
	if not salvage_point_data.is_output:
		return
	if door != null and level.is_salvage_blocked(door.door_data.get_rect(), door):
		door_error = true
		door_error_size = door.door_data.size

func prep_output_step_3() -> void:
	if not salvage_point_data.is_output:
		return
	if door != null and door_error:
		level.remove_element(door, Enums.level_element_types.door)
		door = null
	if door != null:
		hide()

func remove_door() -> void:
	if door != null:
		level.remove_element(door, Enums.level_element_types.door)
		door = null
	door_error = false
	show()

func _on_touched(_who: Node2D) -> void:
	if not active: return
	if not is_instance_valid(salvage_point_data): return
	if salvage_point_data.is_output: return
	if level.logic.active_salvage != self:
		snd_salvage_prep.play()
		level.logic.start_undo_action()
		level.logic.undo_redo.add_undo_property(level.logic, &"active_salvage", level.logic.active_salvage)
		level.logic.undo_redo.add_do_property(level.logic, &"active_salvage", self)
		level.logic.active_salvage = self
		level.logic.end_undo_action()

func _connect_salvage_point_data() -> void:
	if not is_instance_valid(salvage_point_data): return
	salvage_point_data.changed.connect(update_visual)
	update_visual()
	show()
	if not is_node_ready(): return

func _disconnect_salvage_point_data() -> void:
	if is_instance_valid(salvage_point_data):
		salvage_point_data.changed.disconnect(update_visual)

func _process(delta) -> void:
	update_visual()

func update_visual() -> void:
	if not is_node_ready(): return
	if not is_instance_valid(salvage_point_data): return
	if not ignore_position:
		position = salvage_point_data.position
	var mod: Color
	outline.hide()
	if salvage_point_data.is_output:
		if door_error:
			sprite.frame = 2
			mod = Rendering.salvage_point_error_output_color
			outline.position.x = 16 - door_error_size.x / 2
			outline.position.y = 32 - door_error_size.y
			outline.size = door_error_size
			outline.show()
		else:
			sprite.frame = 1
			mod = Rendering.salvage_point_output_color
	else:
		if active and level.logic.active_salvage == self:
			mod = Rendering.salvage_point_active_input_color
		else:
			mod = Rendering.salvage_point_input_color
		sprite.frame = 0
	
	sprite.modulate = mod
	if outline.visible:
		outline.modulate = mod
	number.text = str(salvage_point_data.sid)

func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		var mod := Color.WHITE
		sprite.modulate = mod
		if outline.visible:
			outline.modulate = mod

func get_mouseover_text() -> String:
	return salvage_point_data.get_mouseover_text(door_error)
