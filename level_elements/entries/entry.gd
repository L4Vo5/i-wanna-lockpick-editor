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
	print("[S] %s: Enter. Should go to %d" % [self, entry_data.leads_to])

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
