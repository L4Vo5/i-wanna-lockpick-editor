@tool
extends MarginContainer

signal changed_arrangement
@export var lock_data: LockData:
	set(val):
		if lock_data == val: return
		_disconnect_lock_data()
		lock_data = val
		_connect_lock_data()

@onready var option_button: OptionButton = %OptionButton

func _ready() -> void:
	option_button.item_selected.connect(_on_item_selected)

func _on_item_selected(idx: int) -> void:
	if not is_instance_valid(lock_data): return
	if lock_data.lock_arrangement == idx - 1 : return
	lock_data.lock_arrangement = idx - 1
	changed_arrangement.emit()

func _connect_lock_data() -> void:
	if not is_instance_valid(lock_data): return
	lock_data.changed_magnitude.connect(_update_options)
	lock_data.changed_lock_arrangement.connect(_set_option)
	if not is_node_ready(): await ready
	_update_options()
	_set_option()

func _disconnect_lock_data() -> void:
	if not is_instance_valid(lock_data): return
	lock_data.changed_magnitude.disconnect(_update_options)
	lock_data.changed_lock_arrangement.disconnect(_set_option)

# TODO: Make sure it's updated when new custom arrangements are added? also test for custom arrangements lol since those don't even work yet
func _update_options() -> void:
	option_button.clear()
	option_button.add_item("Number")
	if not is_instance_valid(lock_data): return
	var current := 0
	while true:
		var arr = Rendering.get_lock_arrangement(lock_data.magnitude, current)
		if arr == null:
			break
		else:
			option_button.add_item("Arrangement " + str(current))
		current += 1
	_set_option()

# Sets option to whatever the lock has
func _set_option() -> void:
	if not is_instance_valid(lock_data): return
	if option_button.selected == lock_data.lock_arrangement + 1: return
	option_button.selected = lock_data.lock_arrangement + 1
	changed_arrangement.emit()
