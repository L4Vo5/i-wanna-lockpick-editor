@tool
extends MarginContainer
class_name SalvagePointEditor

@export var data: SalvagePointData:
	set(val):
		data = val.duplicated()
		if not is_node_ready(): await ready
		salvage_point.data = data
		_set_to_data()

@onready var salvage_point: SalvagePoint = %SalvagePoint
@onready var sid: SpinBox = %SID
@onready var type: OptionButton = %TypeChoice

func _init() -> void:
	data = SalvagePointData.new()

func _ready() -> void:
	type.clear()
	type.add_item("Input Point")
	type.add_item("Output Point")
	_set_to_data()
	sid.value_changed.connect(_update_salvage_point.unbind(1))
	type.item_selected.connect(_update_salvage_point.unbind(1))

var _setting_to_data := false
func _set_to_data() -> void:
	_setting_to_data = true
	sid.value = data.sid
	type.selected = 1 if data.is_output else 0
	_setting_to_data = false

func _update_salvage_point() -> void:
	if _setting_to_data: return
	data.sid = sid.value as int
	data.is_output = type.selected == 1
