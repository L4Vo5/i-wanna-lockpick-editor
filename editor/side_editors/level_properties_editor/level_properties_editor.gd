extends MarginContainer
class_name LevelPropertiesEditor

static var DEBUG := false

# set externally
var editor_data: EditorData:
	set(val):
		if editor_data == val: return
		if is_instance_valid(editor_data):
			editor_data.changed_level_pack_data.disconnect(_update_level_pack_data)
			editor_data.changed_level_data.disconnect(_update_level_data)
		editor_data = val
		if is_instance_valid(editor_data):
			editor_data.changed_level_pack_data.connect(_update_level_pack_data)
			editor_data.changed_level_data.connect(_update_level_data)
			_update_level_pack_data()
			_update_level_data()

var _level_data: LevelData:
	set(val):
		if _level_data == val: return
		_disconnect_level_data()
		_level_data = val
		_connect_level_data()
var _level_pack_data: LevelPackData:
	set(val):
		if _level_pack_data == val: return
		_disconnect_pack_data()
		_level_pack_data = val
		_connect_pack_data()

@onready var search: LineEdit = %Search
@onready var level_list: LevelList = %LevelList

@onready var delete_level: Button = %DeleteLevel
@onready var duplicate_level: Button = %Duplicate
@onready var add_level: Button = %AddLevel


@onready var level_name: LineEdit = %LevelName
@onready var level_title: LineEdit = %LevelTitle
@onready var level_author: LineEdit = %LevelAuthor
@onready var width: SpinBox = %Width
@onready var height: SpinBox = %Height

@onready var player_spawn_coord: Label = %PlayerSpawnCoord
@onready var goal_coord: Label = %GoalCoord

@onready var what_to_place: ObjectGridChooser = %WhatToPlace
@onready var place_player_spawn: TextureRect = %StartPos
@onready var place_goal: Node2DCenterContainer = %Goal
@onready var remove_goal: Button = %RemoveGoal

@onready var exitable: CheckBox = %Exitable

func _connect_pack_data() -> void:
	if not is_instance_valid(_level_pack_data): return
	_level_pack_data.changed.connect(_set_to_level_pack_data)
	_set_to_level_pack_data()

func _disconnect_pack_data() -> void:
	if not is_instance_valid(_level_pack_data): return
	_level_pack_data.changed.disconnect(_set_to_level_pack_data)

func _connect_level_data() -> void:
	if not is_instance_valid(_level_data): return
	_level_data.changed_player_spawn_position.connect(_on_changed_player_spawn_pos)
	_level_data.changed_goal_position.connect(_on_changed_goal_position)
	_level_data.changed.connect(_set_to_level_data)
	_on_changed_player_spawn_pos()
	_on_changed_goal_position()
	_set_to_level_data()
	_on_what_to_place_changed(place_player_spawn)

func _disconnect_level_data() -> void:
	if not is_instance_valid(_level_data): return
	_level_data.changed_player_spawn_position.disconnect(_on_changed_player_spawn_pos)
	_level_data.changed_goal_position.disconnect(_on_changed_goal_position)
	_level_data.changed.disconnect(_set_to_level_data)

func _ready() -> void:
	# These are just so the scene works in isolation
	_level_pack_data = LevelPackData.get_default_level_pack()
	_level_data = _level_pack_data.levels[0]
	
	_on_changed_player_spawn_pos()
	_on_changed_goal_position()
	visibility_changed.connect(func():
		if visible:
			_set_to_level_pack_data()
	)
	what_to_place.object_selected.connect(_on_what_to_place_changed)
	level_name.text_changed.connect(_on_set_name)
	level_title.text_changed.connect(_on_set_title)
	level_author.text_changed.connect(_on_set_author)
	width.value_changed.connect(_on_size_changed.unbind(1))
	height.value_changed.connect(_on_size_changed.unbind(1))
	remove_goal.pressed.connect(_on_remove_goal_button_pressed)
	
	exitable.pressed.connect(_on_changed_exitable)
	
	search.text_changed.connect(level_list.update_visibility)
	level_list.selected_level.connect(_set_level_number)
	
	delete_level.pressed.connect(_delete_current_level)
	duplicate_level.pressed.connect(_duplicate_current_level)
	add_level.pressed.connect(_create_new_level)

func _update_level_pack_data() -> void:
	_level_pack_data = editor_data.level_pack_data

func _update_level_data() -> void:
	_level_data = editor_data.level_data

func _on_changed_player_spawn_pos() -> void:
	if not is_node_ready(): return
	if not is_instance_valid(_level_data): return
	player_spawn_coord.text = str(_level_data.player_spawn_position)

func _on_changed_goal_position() -> void:
	if not is_node_ready(): return
	if not is_instance_valid(_level_data): return
	if _level_data.has_goal:
		goal_coord.text = str(_level_data.goal_position)
	else:
		goal_coord.text = "(none)"

func _on_what_to_place_changed(selected_object: Node) -> void:
	if not is_node_ready(): return
	if not is_instance_valid(editor_data): return
	editor_data.player_spawn = selected_object == place_player_spawn
	editor_data.goal_position = selected_object == place_goal

# adapts the controls to the level's data
var _setting_to_data := false
func _set_to_level_data() -> void:
	if _setting_to_data: return
	if DEBUG: print_debug("Setting to level data")
	_setting_to_data = true
	# Stop the caret from going back to the start
	width.value = _level_data.size.x
	height.value = _level_data.size.y
	if level_name.text != _level_data.name:
		level_name.text = _level_data.name
	if level_title.text != _level_data.title:
		level_title.text = _level_data.title
	if level_author.text != _level_data.author:
		level_author.text = _level_data.author
	exitable.button_pressed = _level_data.exitable
	_setting_to_data = false

func _set_to_level_pack_data() -> void:
	if _setting_to_data: return
	_setting_to_data = true
	level_list.pack_data = _level_pack_data
	if editor_data:
		level_list.set_selected_to(editor_data.current_level)
	_setting_to_data = false

func _on_size_changed() -> void:
	if _setting_to_data: return
	_level_data.size.x = width.value as int
	_level_data.size.y = height.value as int

func _on_set_name(new_name: String) -> void:
	if _setting_to_data: return
	if _level_data.name == new_name: return
	_level_data.name = new_name
	if DEBUG: print_debug("Level name: " + new_name)

func _on_set_title(new_title: String) -> void:
	if _setting_to_data: return
	if _level_data.title == new_title: return
	_level_data.title = new_title

func _on_set_author(new_author: String) -> void:
	if _setting_to_data: return
	if _level_data.author == new_author: return
	_level_data.author = new_author
	if DEBUG: print_debug("Level author: " + new_author)

func _set_level_number(new_number: int) -> void:
	if _level_pack_data.state_data.current_level != new_number:
		_level_pack_data.state_data.current_level = new_number
		if editor_data:
			editor_data.gameplay.set_current_level(new_number)

func _on_remove_goal_button_pressed() -> void:
	if _setting_to_data: return
	_level_data.has_goal = false

func _on_changed_exitable() -> void:
	if _setting_to_data: return
	_level_data.exitable = exitable.button_pressed
	for entry: Entry in editor_data.level.entries.get_children():
		entry.update_status()

func _delete_current_level() -> void:
	_level_pack_data.delete_level(editor_data.current_level)
	if _level_pack_data.levels.size() == 0:
		_level_pack_data.add_level(LevelData.get_default_level(), 0)

func _create_new_level() -> void:
	var new_level := LevelData.get_default_level()
	_level_pack_data.add_level(new_level, editor_data.current_level + 1)

func _duplicate_current_level() -> void:
	_level_pack_data.duplicate_level(editor_data.current_level)
