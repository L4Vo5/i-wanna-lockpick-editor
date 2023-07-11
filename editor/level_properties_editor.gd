extends MarginContainer
class_name LevelPropertiesEditor

var editor_data: EditorData:
	set(val):
		if editor_data == val: return
		if is_instance_valid(editor_data):
			editor_data.changed_level_data.disconnect(_update_level_data)
		editor_data = val
		if is_instance_valid(editor_data):
			_on_what_to_place_changed()
			editor_data.changed_level_data.connect(_update_level_data)
			_update_level_data()

var _level_data: LevelData:
	set(val):
		if _level_data == val: return
		_disconnect_level_data()
		_level_data = val
		_connect_level_data()

@onready var player_spawn_coord: Label = %PlayerSpawnCoord
@onready var goal_coord: Label = %GoalCoord
@onready var what_to_place: OptionButton = %WhatToPlace
@onready var width: SpinBox = %Width
@onready var height: SpinBox = %Height

@onready var level_path: Label = %LevelPath
@onready var level_name: LineEdit = %LevelName
@onready var level_author: LineEdit = %LevelAuthor

@onready var no_image: Label = %NoImage
@onready var level_image_rect: Control = %LevelImageRect
@onready var copy_to_clipboard: Button = %CopyToClipboard

func _connect_level_data() -> void:
	if not is_instance_valid(_level_data): return
	_level_data.changed_player_spawn_position.connect(_on_changed_player_spawn_pos)
	_level_data.changed_goal_position.connect(_on_changed_goal_position)
	_level_data.changed.connect(_set_to_level_data)
	_on_changed_player_spawn_pos()
	_on_changed_goal_position()
	_set_to_level_data()
	if not Global.image_copier_exists:
		copy_to_clipboard.text = "Force Refresh"

func _disconnect_level_data() -> void:
	if not is_instance_valid(_level_data): return
	_level_data.changed_player_spawn_position.disconnect(_on_changed_player_spawn_pos)
	_level_data.changed_goal_position.disconnect(_on_changed_goal_position)
	_level_data.changed.disconnect(_set_to_level_data)

func _ready() -> void:
	_on_changed_player_spawn_pos()
	_on_changed_goal_position()
	what_to_place.add_item("Player Spawn")
	what_to_place.add_item("Goal")
	what_to_place.item_selected.connect(_on_what_to_place_changed.unbind(1))
	visibility_changed.connect(func(): if visible: _reload_image())
	_on_what_to_place_changed()
	level_name.text_changed.connect(_on_set_name)
	level_author.text_changed.connect(_on_set_author)
	Global.changed_level.connect(_reload_image)
	copy_to_clipboard.pressed.connect(_copy_image_to_clipboard)
	width.value_changed.connect(_on_size_changed.unbind(1))
	height.value_changed.connect(_on_size_changed.unbind(1))

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

# adapts the controls to the level's data
var _setting_to_data := false
func _set_to_level_data() -> void:
	if _setting_to_data: return
	_setting_to_data = true
#	level_size.text = str(_level_data.size)
	level_path.text = str(_level_data.file_path)
	level_author.text = _level_data.author
	level_name.text = _level_data.name
	width.value = _level_data.size.x
	height.value = _level_data.size.y
	_reload_image()
	_setting_to_data = false

func _on_size_changed() -> void:
	if _setting_to_data: return
	_level_data.size.x = width.value as int
	_level_data.size.y = height.value as int

func _on_set_name(new_name: String) -> void:
	if _setting_to_data: return
	if _level_data.name == new_name: return
	_level_data.name = new_name
	_reload_image()

func _on_set_author(new_author: String) -> void:
	if _setting_to_data: return
	if _level_data.author == new_author: return
	_level_data.author = new_author
	_reload_image()

func _reload_image() -> void:
	if not visible: return
	var img := SaveLoad.get_image(Global.current_level.level_data)
	if img != null:
		level_image_rect.texture = ImageTexture.create_from_image(img)
	else:
		level_image_rect.texture = null

func _copy_image_to_clipboard() -> void:
	_reload_image() # Just to make sure it's updated
	if level_image_rect.texture != null:
		Global.copy_image_to_clipboard(level_image_rect.texture.get_image())
