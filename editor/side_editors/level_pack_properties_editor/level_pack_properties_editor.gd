extends MarginContainer
class_name LevelPackPropertiesEditor

static var DEBUG := false

# set externally
var editor_data: EditorData:
	set(val):
		assert(editor_data == null)
		assert(val)
		assert(level_properties_editor)
		editor_data = val
		val.level_properties_editor = level_properties_editor
		level_properties_editor.editor_data = val
		editor_data.changed_level_pack_data \
			.connect(_update_level_pack_data)
		_update_level_pack_data()

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

@onready var no_image: Label = %NoImage
@onready var level_image_rect: Control = %LevelImageRect
@onready var copy_to_clipboard: Button = %CopyToClipboard

@onready var erase_save_state: Button = %EraseSaveState
@onready var completed_levels_label: Label = %CompletedLevelsLabel
@onready var salvaged_doors_label: Label = %SalvagedDoorsLabel

@onready var level_properties_editor: LevelPropertiesEditor = %LevelPropertiesEditor

func _connect_pack_data() -> void:
	if not is_instance_valid(_level_pack_data): return
	_level_pack_data.changed.connect(_set_to_level_pack_data)
	_set_to_level_pack_data()

func _disconnect_pack_data() -> void:
	if not is_instance_valid(_level_pack_data): return
	_level_pack_data.changed.disconnect(_set_to_level_pack_data)

func _ready() -> void:
	# These are just so the scene works in isolation
	_level_pack_data = LevelPackData.new()
	
	if not Global.image_copier_exists:
		copy_to_clipboard.text = "Force Refresh"
	
	visibility_changed.connect(func():
		if visible:
			_reload_image()
			_set_to_level_pack_data()
	)
	pack_name.text_changed.connect(_on_set_pack_name)
	pack_author.text_changed.connect(_on_set_pack_author)
	pack_description.text_changed.connect(_on_set_pack_description)
	Global.changed_level.connect(_reload_image)
	copy_to_clipboard.pressed.connect(_copy_image_to_clipboard)
	erase_save_state.pressed.connect(_erase_save_state)

func _update_level_pack_data() -> void:
	_level_pack_data = editor_data.level_pack_data

var _setting_to_data := false

func _set_to_level_pack_data() -> void:
	if _setting_to_data: return
	_setting_to_data = true
	pack_name.text = _level_pack_data.name
	pack_author.text = _level_pack_data.author
	pack_description.text = _level_pack_data.description
	var state_data := _level_pack_data.state_data
	if state_data:
		completed_levels_label.text = str(state_data.get_completed_levels_count())
		salvaged_doors_label.text = str(state_data.get_salvaged_doors_count())
	level_count_label.text = str(_level_pack_data.levels.size())
	_setting_to_data = false

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

func _on_set_pack_description() -> void:
	if _setting_to_data: return
	var new_description: String = pack_description.text
	if _level_pack_data.description == new_description: return
	_level_pack_data.description = new_description
	if DEBUG: print_debug("Pack description: " + new_description)

func _reload_image() -> void:
	if not level_image_rect.is_visible_in_tree(): return
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

func _erase_save_state() -> void:
	_level_pack_data.state_data.erase()
