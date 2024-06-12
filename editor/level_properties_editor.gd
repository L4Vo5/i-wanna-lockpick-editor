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
			_on_what_to_place_changed()
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

@onready var pack_name: LineEdit = %PackName
@onready var pack_author: LineEdit = %PackAuthor
@onready var pack_description: CodeEdit = %PackDescription
@onready var level_count_label: Label = %LevelCountLabel

## Always remember this value is 1-indexed, unlike how levels are stored in the background
@onready var level_number: SpinBox = %LevelNumber
@onready var delete_level: Button = %DeleteLevel

@onready var level_name: LineEdit = %LevelName
@onready var level_title: LineEdit = %LevelTitle
@onready var level_author: LineEdit = %LevelAuthor
@onready var is_world: CheckBox = %IsWorld
@onready var completion_count: SpinBox = %CompletionCount
@onready var width: SpinBox = %Width
@onready var height: SpinBox = %Height

@onready var player_spawn_coord: Label = %PlayerSpawnCoord
@onready var goal_coord: Label = %GoalCoord
@onready var what_to_place: OptionButton = %WhatToPlace


@onready var no_image: Label = %NoImage
@onready var level_image_rect: Control = %LevelImageRect
@onready var copy_to_clipboard: Button = %CopyToClipboard

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

func _disconnect_level_data() -> void:
	if not is_instance_valid(_level_data): return
	_level_data.changed_player_spawn_position.disconnect(_on_changed_player_spawn_pos)
	_level_data.changed_goal_position.disconnect(_on_changed_goal_position)
	_level_data.changed.disconnect(_set_to_level_data)

func _ready() -> void:
	# These are just so the scene works in isolation
	_level_data = LevelData.new()
	_level_pack_data = LevelPackData.new()
	
	if not Global.image_copier_exists:
		copy_to_clipboard.text = "Force Refresh"
	
	_on_changed_player_spawn_pos()
	_on_changed_goal_position()
	what_to_place.clear()
	what_to_place.add_item("Player Spawn")
	what_to_place.add_item("Goal")
	what_to_place.item_selected.connect(_on_what_to_place_changed.unbind(1))
	visibility_changed.connect(func(): if visible: _reload_image())
	_on_what_to_place_changed()
	level_name.text_changed.connect(_on_set_name)
	level_title.text_changed.connect(_on_set_title)
	level_author.text_changed.connect(_on_set_author)
	pack_name.text_changed.connect(_on_set_pack_name)
	pack_author.text_changed.connect(_on_set_pack_author)
	pack_description.text_changed.connect(_on_set_pack_description)
	Global.changed_level.connect(_reload_image)
	copy_to_clipboard.pressed.connect(_copy_image_to_clipboard)
	width.value_changed.connect(_on_size_changed.unbind(1))
	height.value_changed.connect(_on_size_changed.unbind(1))
	is_world.pressed.connect(_on_changed_is_world)
	completion_count.value_changed.connect(_on_changed_completion_count.unbind(1))
	
	level_number.value_changed.connect(_set_level_number)
	delete_level.pressed.connect(_delete_current_level)

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
	goal_coord.text = str(_level_data.goal_position)

func _on_what_to_place_changed() -> void:
	if not is_node_ready(): return
	if not is_instance_valid(editor_data): return
	editor_data.player_spawn = what_to_place.selected == 0
	editor_data.goal_position = what_to_place.selected == 1

func _on_changed_is_world() -> void:
	if not is_node_ready(): return
	if not is_instance_valid(_level_data): return
	if not is_instance_valid(editor_data): return
	var pressed = is_world.button_pressed
	completion_count.get_parent().visible = pressed
	goal_coord.get_parent().visible = not pressed
	editor_data.level.goal.visible = not pressed
	_on_changed_completion_count()
	# If any entry refers to itself
	for entry: Entry in editor_data.level.entries.get_children():
		entry.update_status()
	# cannot place goals in worlds
	what_to_place.clear()
	what_to_place.add_item("Player Spawn")
	if not pressed:
		what_to_place.add_item("Goal")
	_on_what_to_place_changed()

func _on_changed_completion_count() -> void:
	if not is_node_ready(): return
	if not is_instance_valid(_level_data): return
	if is_world.button_pressed:
		_level_data.world_completion_count = completion_count.value as int
	else:
		_level_data.world_completion_count = -1

# adapts the controls to the level's data
var _setting_to_data := false
func _set_to_level_data() -> void:
	if _setting_to_data: return
	if DEBUG: print_debug("Setting to level data")
	_setting_to_data = true
	# Stop the caret from going back to the start
	width.value = _level_data.size.x
	height.value = _level_data.size.y
	is_world.button_pressed = _level_data.world_completion_count != -1
	completion_count.value = maxi(0, _level_data.world_completion_count)
	_on_changed_is_world()
	if level_name.text != _level_data.name:
		level_name.text = _level_data.name
	if level_title.text != _level_data.title:
		level_title.text = _level_data.title
	if level_author.text != _level_data.author:
		level_author.text = _level_data.author
	_setting_to_data = false
	_reload_image()

func _set_to_level_pack_data() -> void:
	if _setting_to_data: return
	_setting_to_data = true
	pack_name.text = _level_pack_data.name
	pack_author.text = _level_pack_data.author
	pack_description.text = _level_pack_data.description
	level_number.max_value = _level_pack_data.levels.size() + 1
	if _level_pack_data.state_data:
		level_number.value = _level_pack_data.state_data.current_level + 1
	level_count_label.text = str(_level_pack_data.levels.size())
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
	_reload_image()

func _on_set_title(new_title: String) -> void:
	if _setting_to_data: return
	if _level_data.title == new_title: return
	_level_data.title = new_title
	_reload_image()

func _on_set_author(new_author: String) -> void:
	if _setting_to_data: return
	if _level_data.author == new_author: return
	_level_data.author = new_author
	if DEBUG: print_debug("Level author: " + new_author)
	_reload_image()

func _on_set_pack_name(new_name: String) -> void:
	if _setting_to_data: return
	if _level_pack_data.name == new_name: return
	_level_pack_data.name = new_name
	if DEBUG: print_debug("Pack name: " + new_name)

func _on_set_pack_author(new_author: String) -> void:
	if _setting_to_data: return
	if _level_pack_data.author == new_author: return
	_level_pack_data.author = new_author
	if DEBUG: print_debug("Pack author: " + new_author)

func _on_set_pack_description(new_description: String) -> void:
	if _setting_to_data: return
	if _level_pack_data.description == new_description: return
	_level_pack_data.description = new_description
	if DEBUG: print_debug("Pack description: " + new_description)

func _set_level_number(new_number: int) -> void:
	assert(new_number == level_number.value)
	if level_number.value == level_number.max_value:
		_level_pack_data.add_level(LevelData.get_default_level())
		level_number.max_value = _level_pack_data.levels.size() + 1
		level_count_label.text = str(_level_pack_data.levels.size())
	editor_data.gameplay.transition_to_level(level_number.value as int - 1)

func _delete_current_level() -> void:
	_level_pack_data.delete_level(level_number.value as int - 1)
	level_number.value -= 1
	if _level_pack_data.levels.size() == 0:
		_level_pack_data.add_level(LevelData.get_default_level())
	level_number.max_value = _level_pack_data.levels.size() + 1
	level_count_label.text = str(_level_pack_data.levels.size())
	editor_data.gameplay.transition_to_level(level_number.value as int - 1)

func _reload_image() -> void:
	if not visible: return
	if not _level_pack_data: return
	var img := SaveLoad.get_image(_level_pack_data)
	if img != null:
		level_image_rect.texture = ImageTexture.create_from_image(img)
	else:
		level_image_rect.texture = null

func _copy_image_to_clipboard() -> void:
	_reload_image() # Just to make sure it's updated
	if level_image_rect.texture != null:
		Global.copy_image_to_clipboard(level_image_rect.texture.get_image())
