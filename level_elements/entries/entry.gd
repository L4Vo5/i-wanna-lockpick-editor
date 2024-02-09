@tool
extends Control
class_name Entry

@export var entry_data: EntryData:
	set(val):
		if entry_data == val: return
		_disconnect_entry_data()
		entry_data = val
		_connect_entry_data()
var level: Level
@export var ignore_position := false

func enter() -> void:
	if entry_data.leads_to == -1: return
	level.transition_to_level.call_deferred(entry_data.leads_to)

func update_position() -> void:
	if not ignore_position:
		position = entry_data.position

func _disconnect_entry_data() -> void:
	if not is_instance_valid(entry_data): return
	entry_data.changed.disconnect(update_position)

func _connect_entry_data() -> void:
	if not is_instance_valid(entry_data): return
	entry_data.changed.connect(update_position)
	update_position()
