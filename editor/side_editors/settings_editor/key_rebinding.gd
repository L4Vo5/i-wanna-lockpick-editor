@tool
extends VBoxContainer

@export var actions: Array[KeyRebindAction]

@onready var reset_keybinds := %ResetKeybinds

func _ready() -> void:
	for action in actions:
		var label := Label.new()
		label.text = action.label + ": "
		label.tooltip_text = action.tooltip
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		
		var button := KeyRebindButton.new()
		button.action_name = action.action_name
		button.default_bind = action.default_bind
		
		action.rebinder = button
		
		var events := InputMap.action_get_events(action.action_name)
		action.default_bind = events[0]
		if Global.settings.key_rebinds.has(action.action_name):
			InputMap.action_erase_events(action.action_name)
			InputMap.action_add_event(action.action_name, Global.settings.key_rebinds[action.action_name])
		
		var hbox := HBoxContainer.new()
		hbox.add_child(label)
		hbox.add_child(button)
		add_child(hbox)
	reset_keybinds.pressed.connect(_on_reset_keybinds)

func _on_reset_keybinds() -> void:
	for action in actions:
		InputMap.action_erase_events(action.action_name)
		InputMap.action_add_event(action.action_name, action.default_bind)
		
		# update text
		var button := action.rebinder
		button.waiting_for_input = button.waiting_for_input
	Global.settings.key_rebinds.clear()
	Global.settings.queue_save()
