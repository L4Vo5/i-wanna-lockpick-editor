extends Control
class_name LockpickEditor

@export var level: Level 
@export var side_container: TabContainer
@export var door_editor: DoorEditor
@export var key_editor: KeyEditor
@export var tile_editor: Control

@export var level_container: Control 

var selected = null

var mode := Enums.editor_modes.tilemap_edit

func _enter_tree() -> void:
	Global.in_level_editor = true

func _exit_tree() -> void:
	Global.in_level_editor = false

func _ready() -> void:
	Global.set_mode(Global.Modes.EDITOR)
	_update_mode()
	side_container.tab_changed.connect(_update_mode.unbind(1))

func _update_mode() -> void:
	mode = {
		door_editor: Enums.editor_modes.objects,
		key_editor: Enums.editor_modes.objects,
		tile_editor: Enums.editor_modes.tilemap_edit
	}[side_container.get_current_tab_control()]
	pass
