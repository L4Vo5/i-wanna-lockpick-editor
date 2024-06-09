@tool
extends MarginContainer
class_name SalvagePointEditor

@export var salvage_point_data: SalvagePointData:
	set(val):
		salvage_point_data = val.duplicated()
		if not is_node_ready(): await ready
		_set_to_salvage_point_data()
@onready var sid: SpinBox = %SID
@onready var is_output: CheckBox = %IsOutput

func _init() -> void:
	if not is_instance_valid(salvage_point_data):
		salvage_point_data = SalvagePointData.new()

func _ready() -> void:
	_set_to_salvage_point_data()
	sid.value_changed.connect(_update_salvage_point)
	is_output.pressed.connect(_update_salvage_point)

func _set_to_salvage_point_data() -> void:
	sid.value = salvage_point_data.sid
	is_output.button_pressed = salvage_point_data.is_output

func _update_salvage_point() -> void:
	salvage_point_data.sid = sid.value as int
	salvage_point_data.is_output = is_output.button_pressed
