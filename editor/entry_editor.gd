@tool
extends MarginContainer
class_name EntryEditor

@export var entry_data: EntryData:
	set(val):
		entry_data = val.duplicated()
		if not is_node_ready(): await ready
		# TODO: Allow editing entrys in the level (currently not done to be consistent with door editing)
		entry.entry_data = entry_data
		_set_to_entry_data()
@onready var entry: Entry = %Entry
@onready var leads_to: SpinBox = %LeadsTo

func _set_to_entry_data() -> void:
	leads_to.value = entry_data.leads_to

func _ready() -> void:
	leads_to.value_changed.connect(_update_leads_to.unbind(1))

func _update_leads_to() -> void:
	entry_data.leads_to = leads_to.value
