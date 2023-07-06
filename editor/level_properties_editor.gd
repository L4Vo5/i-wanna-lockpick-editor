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
@onready var level_size: Label = %LevelSize
@onready var level_path: Label = %LevelPath
@onready var level_name: LineEdit = %LevelName
@onready var level_author: LineEdit = %LevelAuthor

@onready var no_image: Label = %NoImage
@onready var level_image_rect: TextureRect = %LevelImageRect
@onready var copy_to_clipboard: Button = %CopyToClipboard

func _connect_level_data() -> void:
	if not is_instance_valid(_level_data): return
	_level_data.changed_player_spawn_position.connect(_on_changed_player_spawn_pos)
	_level_data.changed_goal_position.connect(_on_changed_goal_position)
	_level_data.changed.connect(_on_general_changed)
	_on_changed_player_spawn_pos()
	_on_changed_goal_position()
	_on_general_changed()

func _disconnect_level_data() -> void:
	if not is_instance_valid(_level_data): return
	_level_data.changed_player_spawn_position.disconnect(_on_changed_player_spawn_pos)
	_level_data.changed_goal_position.disconnect(_on_changed_goal_position)
	_level_data.changed.disconnect(_on_general_changed)

func _ready() -> void:
	_on_changed_player_spawn_pos()
	_on_changed_goal_position()
	what_to_place.add_item("Player Spawn")
	what_to_place.add_item("Goal")
	what_to_place.item_selected.connect(_on_what_to_place_changed.unbind(1))
	_on_what_to_place_changed()
	level_name.text_changed.connect(_on_set_name)
	level_author.text_changed.connect(_on_set_author)
	Global.changed_level.connect(_reload_image)
	copy_to_clipboard.pressed.connect(_copy_image_to_clipboard)

func _update_level_data() -> void:
	_level_data = editor_data.level_data
	_reload_image()

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

func _on_general_changed() -> void:
	level_size.text = str(_level_data.size)
	level_path.text = str(_level_data.file_path)
	if level_author.text != _level_data.author:
		level_author.text = _level_data.author
	if level_name.text != _level_data.name:
		level_name.text = _level_data.name

func _on_set_name(new_name: String) -> void:
	_level_data.name = new_name

func _on_set_author(new_author: String) -> void:
	_level_data.author = new_author

func _reload_image() -> void:
#	if not visible: return
	var img := SaveLoad.get_image(Global.current_level.level_data)
	if img != null:
		level_image_rect.texture = ImageTexture.create_from_image(img)
	else:
		level_image_rect.texture = null

func _copy_image_to_clipboard() -> void:
	_reload_image() # Just to make sure it's updated
	if level_image_rect.texture != null:
		Global.copy_image_to_clipboard(level_image_rect.texture.get_image())
