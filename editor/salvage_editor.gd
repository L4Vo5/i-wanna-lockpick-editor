@tool
extends MarginContainer
class_name SalvagePointEditor

@export var salvage_point_data: SalvagePointData:
	set(val):
		salvage_point_data = val.duplicated()
		if not is_node_ready(): await ready
		salvage_point.salvage_point_data = salvage_point_data
		_set_to_salvage_point_data()

@onready var salvage_point: SalvagePoint = %SalvagePoint
@onready var sid: SpinBox = %SID
@onready var type: OptionButton = %TypeChoice

func _init() -> void:
	salvage_point_data = SalvagePointData.new()

func _ready() -> void:
	type.clear()
	type.add_item("Input Point")
	type.add_item("Output Point")
	_set_to_salvage_point_data()
	sid.value_changed.connect(_update_salvage_point.unbind(1))
	type.item_selected.connect(_update_salvage_point.unbind(1))

var _setting_to_data := false
func _set_to_salvage_point_data() -> void:
	_setting_to_data = true
	sid.value = salvage_point_data.sid
	type.selected = 1 if salvage_point_data.is_output else 0
	_setting_to_data = false

func _update_salvage_point() -> void:
	if _setting_to_data: return
	salvage_point_data.sid = sid.value as int
	salvage_point_data.is_output = type.selected == 1