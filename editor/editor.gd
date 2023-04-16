extends Control
class_name LockpickEditor

@export var level: Level 
@export var side_container: TabContainer
@export var door_editor: DoorEditor
@export var key_editor: KeyEditor
@export var tile_editor: Control
@export var level_properties_editor: LevelPropertiesEditor

@export var level_container: LevelContainer

@export var play_button: Button

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
	data.level_data = level.level_data
	level_container.editor_data = data
	level_properties_editor.editor_data = data
	play_button.pressed.connect(_on_play_pressed)

func _update_mode() -> void:
	var tab_editor := side_container.get_current_tab_control()
	data.tilemap_edit = tab_editor == tile_editor
	data.doors = tab_editor == door_editor
	data.keys = tab_editor == key_editor
	data.level_properties = tab_editor == level_properties_editor
	data.objects = tab_editor == door_editor or tab_editor == key_editor

func _on_play_pressed() -> void:
	data.is_playing = not data.is_playing
	data.disable_editing = data.is_playing
	level.exclude_player = not data.is_playing
	side_container.visible = not data.disable_editing
	play_button.text = ["Play", "Stop"][data.is_playing as int]
	level.reset()
	play_button.release_focus()
	grab_focus()
