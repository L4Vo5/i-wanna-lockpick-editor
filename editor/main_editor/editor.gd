extends Control
class_name LockpickEditor

@export var gameplay: GameplayManager
@onready var level: Level = gameplay.level 
@export var right_dock: MarginContainer
@export var side_tabs: BookmarkTabContainer
@export var door_editor: DoorEditor
@export var key_editor: KeyEditor
@export var counter_editor: CounterEditor
@export var tile_editor: Control
@export var level_pack_properties_editor: LevelPackPropertiesEditor
@export var entry_editor: EntryEditor
@export var salvage_point_editor: SalvagePointEditor

@onready var level_element_editors: Dictionary = {
	Enums.LevelElementTypes.Door: door_editor,
	Enums.LevelElementTypes.Key: key_editor,
	Enums.LevelElementTypes.KeyCounter: counter_editor,
	Enums.LevelElementTypes.Entry: entry_editor,
	Enums.LevelElementTypes.SalvagePoint: salvage_point_editor,
}

@export var level_container: LevelContainer

@export var play_button: Button
@export var save_button: Button
@export var save_as_button: Button
@export var download_button: Button
@export var load_button: Button
@export var load_from_clipboard_button: Button
@export var level_path_displayer: LineEdit
@export var open_files_location: Button
@export var new_level_button: Button
@export var more_options: MenuButton

@onready var hide_on_play: Array[CanvasItem] = [
	save_button,
	save_as_button,
	load_button,
	load_from_clipboard_button,
	new_level_button
]
@onready var hide_on_web: Array[CanvasItem] = [
	open_files_location,
]
@onready var hide_on_no_image_copy: Array[CanvasItem] = [
	load_from_clipboard_button
]

@export var file_dialog: FileDialog
@export var invalid_level_dialog: InvalidLevelLoad

var drag_and_drop_web: DragAndDropWeb = null

var data := EditorData.new()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("play"):
		_on_play_pressed()
		accept_event()

func _ready() -> void:
	DirAccess.make_dir_absolute("user://levels")
	DirAccess.make_dir_absolute("user://level_saves")
	file_dialog.current_dir = "levels"
	Global.set_mode(Global.Modes.EDITOR)
	
	data.gameplay = gameplay
	data.level = level
	gameplay.is_editing = true
	if FileAccess.file_exists(Global.settings.current_editor_pack):
		load_level(Global.settings.current_editor_pack)
	else:
		_on_new_level_button_pressed()
	
	data.door_editor = door_editor
	door_editor.editor_data = data
	data.key_editor = key_editor
	data.tile_editor = tile_editor
	data.counter_editor = counter_editor
	data.level_pack_properties_editor = level_pack_properties_editor
	data.entry_editor = entry_editor
	data.salvage_point_editor = salvage_point_editor
	data.side_tabs = side_tabs
	data.level_element_editors = level_element_editors
	data.level_container = level_container
	
	level_container.editor_data = data
	level_pack_properties_editor.editor_data = data
	entry_editor.editor_data = data
	salvage_point_editor.editor_data = data
	
	side_tabs.tab_changed.connect(_update_mode)
	play_button.pressed.connect(_on_play_pressed)
	
	save_button.pressed.connect(_on_save_pressed)
	save_as_button.pressed.connect(_on_save_as_pressed)
	load_button.pressed.connect(_on_load_pressed)
	load_from_clipboard_button.pressed.connect(_on_load_from_clipboard_pressed)
	
	open_files_location.pressed.connect(_on_open_files_location_pressed)
	
	new_level_button.pressed.connect(_on_new_level_button_pressed)
	
	level_path_displayer.tooltip_text = "The current level's path"
	
	file_dialog.add_filter("*.lvl", "Level file")
	file_dialog.add_filter("*.png", "Level file (image)")
	file_dialog.file_selected.connect(_on_file_selected)
	
	var popup_menu := more_options.get_popup()
	popup_menu.add_item("Open Level Files Location")
	popup_menu.add_item("More extra options coming soon? xD")
	popup_menu.index_pressed.connect(_on_more_options_selected)
	
	invalid_level_dialog.load_level_fixed.connect(_on_load_fixed)
	invalid_level_dialog.load_level_unfixed.connect(_on_load_unfixed)
	
	_update_level_path_display()
	resolve_visibility()
	
	if Global.is_web:
		# drag and drop on web version
		drag_and_drop_web = DragAndDropWeb.new()
		drag_and_drop_web.file_dropped.connect(_on_file_buffer_dropped)
		download_button.show()
		download_button.pressed.connect(_on_download_pressed)
	else:
		# drag and drop on desktop
		get_window().files_dropped.connect(_on_files_dropped)
	
	side_tabs.set_current_tab_index(Global.settings.current_editor_tab)
	_update_mode()

func _on_files_dropped(files: PackedStringArray) -> void:
	if files.is_empty():
		return
	# Load only the first
	load_level(files[0])

## Only applicable on web
func _on_file_buffer_dropped(buffer: PackedByteArray) -> void:
	new_level_pack = SaveLoad.load_from_file_buffer(buffer, "")
	finish_loading_level()

func _on_download_pressed() -> void:
	assert(Global.is_web)
	var buffer := SaveLoad.get_data(data.level_pack_data)
	var file_name := ""
	if data.level_pack_data.file_path != "":
		file_name = data.level_pack_data.file_path.get_basename().get_file()
	else:
		file_name = data.level_pack_data.name + ".lvl"
	JavaScriptBridge.download_buffer(buffer, file_name)

func resolve_visibility() -> void:
	for node in hide_on_play:
		node.show()
	for node in hide_on_no_image_copy:
		node.show()
	for node in hide_on_web:
		node.show()
	if data.is_playing:
		for node in hide_on_play:
			node.hide()
	if not Global.image_copier_exists:
		for node in hide_on_no_image_copy:
			node.hide()
	if Global.is_web:
		for node in hide_on_web:
			node.hide()

func _update_mode() -> void:
	Global.settings.current_editor_tab = side_tabs.get_current_tab_index()
	var current_tab := side_tabs.get_current_tab_control()
	data.current_tab = current_tab

func _on_play_pressed() -> void:
	Global.release_gui_focus()
	if Global.settings.should_save_on_play and not data.is_playing:
		if SaveLoad.is_path_valid_for_saving(data.level_pack_data.file_path):
			save_level()
	if data.is_playing:
		data.pack_state.save()
	data.is_playing = not data.is_playing
	data.disable_editing = data.is_playing
	right_dock.visible = not data.disable_editing
	play_button.text = ["Play", "Stop"][data.is_playing as int]
	gameplay.is_editing = not data.is_playing
	gameplay.reset()
	resolve_visibility()

func save_level() -> void:
	if not Global.in_editor:
		if not data.is_playing:
			var path := data.level_pack_data.file_path
			if path == "":
				path = data.level_pack_data.resource_path
			var ext := path.get_extension()
			data.pack_state.save()
			if ext in ["res", "tres"]:
				# Allow saving res and tres anywhere when testing
				if not Global.is_exported:
					data.level_pack_data.resource_path = path
					print("Saving to %s" % path)
					ResourceSaver.save(data.level_pack_data, path)
				else:
					Global.safe_error("Report this (saving resource).", Vector2(300, 100))
			elif ext in ["lvl", "png"]:
				data.level_pack_data.resource_path = ""
				SaveLoad.save_level(data.level_pack_data)
	_update_level_path_display()

var new_level_pack: LevelPackData = null
func load_level(path: String) -> void:
	new_level_pack = null
	var ext := path.get_extension()
	if ext in ["res", "tres"]:
		if Global.is_exported and not path.begins_with("res://"):
			Global.safe_error("Loading resource levels outside res:// is not allowed", Vector2(300, 100))
			return
		var res := load(path)
		var valid := (res != null)
		if valid and res is LevelData:
			res = LevelPackData.make_from_level(res)
		if valid and res is LevelPackData:
			new_level_pack = res
			new_level_pack.file_path = path
	elif ext == "lvl" or ext == "png":
		new_level_pack = SaveLoad.load_from_path(path)
	else:
		assert(not ext in SaveLoad.LEVEL_EXTENSIONS, "Trying to load level with invalid extension")
		assert(false, "Not all valid extensions are covered")
	finish_loading_level()

func _on_load_from_clipboard_pressed() -> void:
	var image := Global.get_image_from_clipboard()
	if image == null:
		Global.show_notification("No image in clipboard (or other error)")
	else:
		new_level_pack = SaveLoad.load_from_image(image)
		finish_loading_level()

func finish_loading_level() -> void:
	if is_instance_valid(new_level_pack):
		new_level_pack.check_valid(false)
		var fixable_problems := new_level_pack.get_fixable_invalid_reasons()
		var unfixable_problems := new_level_pack.get_unfixable_invalid_reasons()
		if fixable_problems.is_empty() and unfixable_problems.is_empty():
			_actually_finish_loading_level()
		else:
			invalid_level_dialog.appear(fixable_problems, unfixable_problems)

func _on_load_fixed() -> void:
	new_level_pack.check_valid(true)
	_actually_finish_loading_level()

func _on_load_unfixed() -> void:
	_actually_finish_loading_level()

func _actually_finish_loading_level() -> void:
	var new_pack_state := LevelPackStateData.find_state_file_for_pack_or_create_new(new_level_pack)
	data.set_pack_and_state(new_level_pack, new_pack_state)
	_update_level_path_display()

func _update_level_path_display() -> void:
	level_path_displayer.show()
	if data.level_pack_data.resource_path != "":
		level_path_displayer.text = data.level_pack_data.resource_path
	elif data.level_pack_data.file_path != "":
		level_path_displayer.text = data.level_pack_data.file_path
	else:
		level_path_displayer.hide()

func _on_save_as_pressed() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	
	file_dialog.clear_filters()
	file_dialog.add_filter("*.lvl", "Level file")
	file_dialog.add_filter("*.png", "Level file (image)")
	if Global.settings.allow_resource_files:
		file_dialog.add_filter("*.res", "Binary Resource")
		file_dialog.add_filter("*.tres", "Text Resource")
	if data.level_pack_data.file_path == "":
		var line_edit := file_dialog.get_line_edit()
		var level_name := data.level_pack_data.name
		if level_name == "":
			level_name = "Untitled"
		line_edit.text = level_name + ".lvl"
		line_edit.caret_column = line_edit.text.length()
	
	file_dialog.popup_centered_ratio(0.9)


func _on_save_pressed() -> void:
	if Global.settings.allow_resource_files:
		save_level()
	elif SaveLoad.is_path_valid_for_saving(data.level_pack_data.file_path):
		save_level()
	else:
		# "Save As" logic will assign a new path
		_on_save_as_pressed()

func _on_load_pressed() -> void:
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	
	file_dialog.clear_filters()
	file_dialog.add_filter("*.lvl", "Level file")
	file_dialog.add_filter("*.png", "Level file (image)")
	if Global.settings.allow_resource_files:
		file_dialog.add_filter("*.res", "Binary Resource")
		file_dialog.add_filter("*.tres", "Text Resource")
	
	file_dialog.popup_centered_ratio(0.9)

func _on_file_selected(path: String) -> void:
	match file_dialog.file_mode:
		FileDialog.FILE_MODE_SAVE_FILE:
			# Save As
			data.level_pack_data.file_path = path
			save_level()
		FileDialog.FILE_MODE_OPEN_FILE:
			# Load
			load_level(path)

func _on_new_level_button_pressed() -> void:
	var pack := LevelPackData.get_default_level_pack()
	var state := LevelPackStateData.make_from_pack_data(pack)
	data.set_pack_and_state(pack, state)
	_update_level_path_display()

func _on_open_files_location_pressed() -> void:
	OS.shell_open(SaveLoad.LEVELS_PATH)

func _on_more_options_selected(idx: int) -> void:
	var popup_menu := more_options.get_popup()
	match popup_menu.get_item_text(idx):
		"Open Level Files Location":
			OS.shell_open(ProjectSettings.globalize_path("user://levels/"))
		"More extra options coming soon? xD":
			pass
		_:
			assert(false)
