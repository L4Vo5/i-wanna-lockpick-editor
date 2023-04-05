extends Control
class_name LockpickEditor

@export var level: Level 
@export var side_container: TabContainer
@export var door_editor: DoorEditor
@export var key_editor: KeyEditor
@export var tile_editor: Control

@export var level_container: LevelContainer 

var selected = null

var data := EditorData.new()

func _enter_tree() -> void:
	Global.in_level_editor = true

func _exit_tree() -> void:
	Global.in_level_editor = false

func _ready() -> void:
	Global.set_mode(Global.Modes.EDITOR)
	_update_mode()
	side_container.tab_changed.connect(_update_mode.unbind(1))
	level_container.editor_data = data


func _update_mode() -> void:
	var tab_editor := side_container.get_current_tab_control()
	data.tilemap_edit = tab_editor == tile_editor
	data.doors = tab_editor == door_editor
	data.keys = tab_editor == key_editor
	data.objects = tab_editor == door_editor or tab_editor == key_editor
