@tool
extends MarginContainer
class_name SalvagePointEditor

@export var data: SalvagePointData:
	set(val):
		data = val.duplicated()
		if not is_node_ready(): return
		salvage_point.data = data
		_set_to_data()

@onready var salvage_point: SalvagePoint = %SalvagePoint
@onready var sid: SpinBox = %SID
@onready var door: Door = %Door
@onready var door_scroll_container: ScrollContainer = %DoorScrollContainer
@onready var type_choice: ObjectGridChooser = %TypeChoice
@onready var type_label: Label = %TypeLabel

var editor_data: EditorData


func _init() -> void:
	data = SalvagePointData.new()

func _ready() -> void:
	salvage_point.data = data
	_set_to_data()
	sid.value_changed.connect(_update_salvage_point.unbind(1))
	type_choice.object_selected.connect(_update_salvage_point.unbind(1))

func _process(_delta: float) -> void:
	if not editor_data: return
	var salvaged_doors := editor_data.level_pack_data.state_data.salvaged_doors
	var current_sid := data.sid
	door_scroll_container.hide()
	if current_sid >= 0 and current_sid < salvaged_doors.size():
		if salvaged_doors[current_sid]:
			door_scroll_container.show()
			door.data = salvaged_doors[current_sid]
			assert(door.data.amount.is_equal_to(ComplexNumber.new_with(1, 0)))

var _setting_to_data := false
func _set_to_data() -> void:
	_setting_to_data = true
	sid.value = data.sid
	type_choice.selected_object = type_choice.get_child(1 if data.is_output else 0)
	_setting_to_data = false

func _update_salvage_point() -> void:
	type_label.text = "Output Point" if type_choice.selected_object.data.is_output else "Input Point" 
	if _setting_to_data: return
	data.sid = sid.value as int
	data.is_output = type_choice.selected_object.data.is_output
