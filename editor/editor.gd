extends Control
class_name LockpickEditor

@export var level: Level 
@export var right_dock: MarginContainer
@export var side_tabs: TabContainer
@export var door_editor: DoorEditor
@export var key_editor: KeyEditor
@export var tile_editor: Control
@export var level_properties_editor: LevelPropertiesEditor

@export var level_container: LevelContainer

@export var play_button: Button
@export var save_button: Button
@export var save_as_button: Button
@export var load_button: Button
@export var load_from_clipboard_button: Button
@export var level_path_displayer: LineEdit
@export var more_options: MenuButton

@export var file_dialog: FileDialog

var data := EditorData.new()

func _enter_tree() -> void:
	Global.in_level_editor = true

func _exit_tree() -> void:
	Global.in_level_editor = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("play"):
		_on_play_pressed()
		accept_event()

func _ready() -> void:
	DirAccess.make_dir_absolute("user://levels")
	file_dialog.current_dir = "levels"
	# WAITING4GODOT: workaround for https://github.com/godotengine/godot/issues/79052
	file_dialog.dialog_close_on_escape = false
	move_levels("user://", "user://levels")
	Global.set_mode(Global.Modes.EDITOR)
	_update_mode()
	
	data.level_data = level.level_data
	data.level = level
	data.door_editor = door_editor
	data.key_editor = key_editor
	data.side_tabs = side_tabs
	
	data.side_tab_doors = door_editor
	data.side_tab_keys = key_editor
	data.side_tab_tile = tile_editor
	data.side_tab_level = level_properties_editor
	
	level_container.editor_data = data
	level_properties_editor.editor_data = data
	
	side_tabs.tab_changed.connect(_update_mode.unbind(1))
	play_button.pressed.connect(_on_play_pressed)
	
	save_button.pressed.connect(_on_save_pressed)
	save_as_button.pressed.connect(_on_save_as_pressed)
	load_button.pressed.connect(_on_load_pressed)
	load_from_clipboard_button.pressed.connect(_on_load_from_clipboard_pressed)
	
	level_path_displayer.tooltip_text = "The current level's path"
	
	file_dialog.add_filter("*.lvl", "Level file")
	file_dialog.add_filter("*.png", "Level file (image)")
	file_dialog.file_selected.connect(_on_file_selected)
	
	var popup_menu := more_options.get_popup()
	popup_menu.add_item("Open Level Files Location")
	popup_menu.add_item("More extra options coming soon? xD")
	popup_menu.index_pressed.connect(_on_more_options_selected)
	
	_update_level_path_display()

func _update_mode() -> void:
	var tab_editor := side_tabs.get_current_tab_control()
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
	right_dock.visible = not data.disable_editing
	data.danger_highlight.stop_adapting()
	data.hover_highlight.stop_adapting()
	data.selected_highlight.stop_adapting()
	play_button.text = ["Play", "Stop"][data.is_playing as int]
	
	level.reset()
	play_button.release_focus()
	# fix for things staying focused when playing
	set_focus_mode(Control.FOCUS_ALL)
	grab_focus()
	set_focus_mode(Control.FOCUS_NONE)

func save_level() -> void:
	if not Global.in_editor:
		if not data.is_playing:
			var path := data.level_data.file_path
			if path == "":
				path = data.level_data.resource_path
			var ext := path.get_extension()
			if ext in ["res", "tres"]:
				if path.begins_with("res://"):
					# One of the default levels, save it
					data.level_data.resource_path = path
					ResourceSaver.save(data.level_data)
				else:
					assert(false)
			elif ext in ["lvl", "png"]:
				data.level_data.resource_path = ""
				SaveLoad.save_level(data.level_data)
	_update_level_path_display()

func load_level(path: String) -> void:
	var ext := path.get_extension()
	if ext in ["res", "tres"]:
		if not path.begins_with("res://"):
			printerr("Loading .res and .tres levels outside res:// is not allowed")
			return
		var res := load(path)
		var valid := (res != null) and (res is LevelData)
		if valid:
			if not path.begins_with("res://"):
				path = path.get_basename() + ".lvl"
				res.resource_path = ""
			data.level_data = res
			res.file_path = path
	elif ext == "lvl" or ext == "png":
		var new_level := SaveLoad.load_from(path)
		if is_instance_valid(new_level):
			data.level_data = new_level
	else:
		assert(not ext in SaveLoad.LEVEL_EXTENSIONS, "Trying to load level with invalid extension")
		assert(false, "Not all valid extensions are covered")
	_update_level_path_display()

func _update_level_path_display() -> void:
	level_path_displayer.show()
	if data.level_data.resource_path != "":
		level_path_displayer.text = data.level_data.resource_path
	elif data.level_data.file_path != "":
		level_path_displayer.text = data.level_data.file_path
	else:
		level_path_displayer.hide()

func _on_save_as_pressed() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	
	file_dialog.clear_filters()
	file_dialog.add_filter("*.lvl", "Level file")
	file_dialog.add_filter("*.png", "Level file (image)")
	if data.level_data.file_path == "":
		var line_edit := file_dialog.get_line_edit()
		var level_name := data.level_data.name
		if level_name == "":
			level_name = "Untitled"
		line_edit.text = level_name + ".lvl"
		line_edit.caret_column = line_edit.text.length()
	
	file_dialog.popup_centered_ratio(0.9)

func _on_save_pressed() -> void:
	if data.level_data.file_path == "":
		_on_save_as_pressed()
	else:
		save_level()

func _on_load_pressed() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	
	file_dialog.clear_filters()
	file_dialog.add_filter("*.lvl", "Level file")
	file_dialog.add_filter("*.png", "Level file (image)")
	
	file_dialog.popup_centered_ratio(0.9)

func _on_load_from_clipboard_pressed() -> void:
	var image := Global.get_image_from_clipboard()
	if image == null:
		Global.show_notification("No image in clipboard (or other error)")
	else:
		var new_level := SaveLoad.load_from_image(image)
		if is_instance_valid(new_level):
			data.level_data = new_level
		_update_level_path_display()

func _on_file_selected(path: String) -> void:
	match file_dialog.file_mode:
		FileDialog.FILE_MODE_SAVE_FILE:
			# Save As
			data.level_data.file_path = path
			save_level()
		FileDialog.FILE_MODE_OPEN_FILE:
			# Load
			load_level(path)

func _on_more_options_selected(idx: int) -> void:
	var popup_menu := more_options.get_popup()
	match popup_menu.get_item_text(idx):
		"Open Level Files Location":
			OS.shell_open(ProjectSettings.globalize_path("user://levels/"))
		"More extra options coming soon? xD":
			pass
		_:
			assert(false)

# Moves all levels (incl. .res and .tres) from one location to another
func move_levels(from: String, to: String) -> void:
	var dir := DirAccess.open(from)
	for file_name in dir.get_files():
		print("moving " + file_name)
		if file_name.get_extension() in SaveLoad.LEVEL_EXTENSIONS:
			var err := dir.rename(file_name, to.path_join(file_name))
			if err != OK:
				print("failed to move %s. error code %d" % [file_name, err])
