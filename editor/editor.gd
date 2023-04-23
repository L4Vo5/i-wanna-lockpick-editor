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
@export var save_button: Button
@export var save_as_button: Button
@export var load_button: Button
@export var level_path_displayer: LineEdit
@export var more_options: MenuButton

@export var file_dialog: FileDialog

var selected = null

var data := EditorData.new()

func _enter_tree() -> void:
	Global.in_level_editor = true

func _exit_tree() -> void:
	Global.in_level_editor = false

func _ready() -> void:
	Global.set_mode(Global.Modes.EDITOR)
	_update_mode()
	
	data.level_data = level.level_data
	data.door_editor = door_editor
	data.key_editor = key_editor
	
	level_container.editor_data = data
	level_properties_editor.editor_data = data
	
	side_container.tab_changed.connect(_update_mode.unbind(1))
	play_button.pressed.connect(_on_play_pressed)
	
	save_button.pressed.connect(save_level)
	save_as_button.pressed.connect(_on_save_as_pressed)
	load_button.pressed.connect(_on_load_pressed)
	
	data.changed_level_path.connect(_update_level_path)
	_update_level_path()
	
	level_path_displayer.tooltip_text = "The current level's path"
	
	file_dialog.add_filter("*.res", "Binary Resource (smaller)")
	file_dialog.add_filter("*.tres", "Text Resource (somewhat readable)")
	file_dialog.file_selected.connect(_on_file_selected)
	
	var popup_menu := more_options.get_popup()
	popup_menu.add_item("Open Level Files Location")
	popup_menu.add_item("More extra options coming soon? xD")
	popup_menu.index_pressed.connect(_on_more_options_selected)
	

func _update_mode() -> void:
	var tab_editor := side_container.get_current_tab_control()
	data.tilemap_edit = tab_editor == tile_editor
	data.doors = tab_editor == door_editor
	data.keys = tab_editor == key_editor
	data.level_properties = tab_editor == level_properties_editor
	data.objects = tab_editor == door_editor or tab_editor == key_editor

func _on_play_pressed() -> void:
	save_level()
	data.is_playing = not data.is_playing
	data.disable_editing = data.is_playing
	level.exclude_player = not data.is_playing
	side_container.visible = not data.disable_editing
	play_button.text = ["Play", "Stop"][data.is_playing as int]
	
	level.reset()
	play_button.release_focus()
	grab_focus()

func save_level() -> void:
	if not Global.in_editor:
		if not data.is_playing:
			ResourceSaver.save(data.level_data)

func _update_level_path() -> void:
	level_path_displayer.text = data.level_data.resource_path

func _on_save_as_pressed() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.popup_centered_ratio(0.9)

func _on_load_pressed() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.popup_centered_ratio(0.9)

func _on_file_selected(path: String) -> void:
	match file_dialog.file_mode:
		FileDialog.FILE_MODE_SAVE_FILE:
			# Save
			data.level_data.resource_path = path
			save_level()
		FileDialog.FILE_MODE_OPEN_FILE:
			# Open
			var res := load(path)
			var valid := (res != null) and (res is LevelData)
			if valid:
				data.level_data = res

func _on_more_options_selected(idx: int) -> void:
	var popup_menu := more_options.get_popup()
	match popup_menu.get_item_text(idx):
		"Open Level Files Location":
			var file_access := FileAccess.open("user://default_level.tres", FileAccess.READ)
			OS.shell_open(ProjectSettings.globalize_path("user://"))
		"More extra options coming soon? xD":
			pass
		_:
			assert(false)
