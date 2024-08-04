@tool
extends Control
class_name SalvagePoint

static var level_element_type := Enums.LevelElementTypes.SalvagePoint

@export var data: SalvagePointData:
	set(val):
		if data == val: return
		_disconnect_data()
		data = val
		_connect_data()

var level: Level:
	set(val):
		level = val
		if not is_instance_valid(val): return
var level_pack_state: LevelPackStateData:
	get:
		if level and level.gameplay_manager:
			return level.gameplay_manager.pack_state
		return null

@export var ignore_position := false
@export var hide_number := false:
	set(val):
		hide_number = val
		if number:
			number.visible = not hide_number

@onready var sprite: Sprite2D = %Sprite
@onready var number: Label = %Number
@onready var snd_salvage_prep: AudioStreamPlayer = %SalvagePrep
@onready var collision: Area2D = %Collision
@onready var outline: Panel = %Outline

func _ready() -> void:
	collision.area_entered.connect(_on_touched)
	update_visual()
	number.visible = not hide_number

func _on_touched(_who: Node2D) -> void:
	if not is_instance_valid(level): return
	if not is_instance_valid(data): return
	if data.is_output: return
	if level.logic.active_salvage != self:
		snd_salvage_prep.play()
		level.logic.start_undo_action()
		level.logic.undo_redo.add_undo_property(level.logic, &"active_salvage", level.logic.active_salvage)
		level.logic.undo_redo.add_do_property(level.logic, &"active_salvage", self)
		level.logic.active_salvage = self
		level.logic.end_undo_action()

func _connect_data() -> void:
	if not is_instance_valid(data): return
	data.changed.connect(update_visual)
	update_visual()
	show()
	if not is_node_ready(): return

func _disconnect_data() -> void:
	if is_instance_valid(data):
		data.changed.disconnect(update_visual)

func _process(_delta) -> void:
	update_visual()

func update_visual() -> void:
	if not is_node_ready(): return
	if not is_instance_valid(data): return
	assert(PerfManager.start("SalvagePoint::update_visual"))
	if not ignore_position:
		position = data.position
	var mod: Color
	outline.hide()
	if data.is_output:
		if data.error_rect != Rect2i():
			sprite.frame = 2
			mod = Rendering.salvage_point_error_output_color
			outline.position = data.error_rect.position
			outline.size = data.error_rect.size
			outline.show()
		else:
			sprite.frame = 1
			mod = Rendering.salvage_point_output_color
	else:
		if is_instance_valid(level) and level.logic.active_salvage == self:
			mod = Rendering.salvage_point_active_input_color
		else:
			mod = Rendering.salvage_point_input_color
		sprite.frame = 0
	
	sprite.modulate = mod
	if outline.visible:
		outline.modulate = mod
	number.text = str(data.sid)
	assert(PerfManager.end("SalvagePoint::update_visual"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		var mod := Color.WHITE
		sprite.modulate = mod
		if outline.visible:
			outline.modulate = mod

func get_mouseover_text() -> String:
	return data.get_mouseover_text()
