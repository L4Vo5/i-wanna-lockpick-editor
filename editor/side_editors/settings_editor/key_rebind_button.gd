@tool
extends Button
class_name KeyRebindButton

@export var action_name: StringName

var default_bind: InputEvent

var waiting_for_input: bool = false:
	set(val):
		waiting_for_input = val
		if val:
			text = WAITING_FOR_INPUT_TEXT
		else:
			text = name_from_input_map()

const WAITING_FOR_INPUT_TEXT: String = "Press a key ..."

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	text = WAITING_FOR_INPUT_TEXT
	var new_size := get_combined_minimum_size()
	custom_minimum_size = new_size
	
	waiting_for_input = waiting_for_input
	focus_exited.connect(_on_focus_exited)

func _on_focus_exited() -> void:
	waiting_for_input = false

func _input(event: InputEvent) -> void:
	if waiting_for_input:
		if event is InputEventKey:
			InputMap.action_erase_events(action_name)
			InputMap.action_add_event(action_name, event)
			Global.settings.key_rebinds[action_name] = event
			Global.settings.queue_save()
			release_focus()
			waiting_for_input = false

func _pressed() -> void:
	grab_focus()
	waiting_for_input = true

func name_from_input_map() -> String:
	var events := InputMap.action_get_events(action_name)
	if events.is_empty():
		return "(None)"
	return events[0].as_text()
