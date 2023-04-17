@tool
extends Control
class_name DoorEditor

@export var door_data: DoorData:
	set(val):
		door_data = val.duplicated()
		if not is_ready: await ready
		# TODO: Allow editing doors in the level (currently not done so you can't resize them)
		door.door_data = door_data
		_set_to_door_data()
@onready var door: Door = %Door

@onready var ice_checkbox: CheckBox = %IceCheckbox
@onready var erosion_checkbox: CheckBox = %ErosionCheckbox
@onready var paint_checkbox: CheckBox = %PaintCheckbox
@onready var ice_button: Button = %IceButton
@onready var erosion_button: Button = %ErosionButton
@onready var paint_button: Button = %PaintButton
@onready var width: SpinBox = %Width
@onready var height: SpinBox = %Height
@onready var real_copies: SpinBox = %RealCopies
@onready var imaginary_copies: SpinBox = %ImaginaryCopies
@onready var color_choice: OptionButton = %ColorChoice
@onready var lock_editor_parent: VBoxContainer = %LockEditors
@onready var add_lock: Button = %AddLock
const LOCK_EDITOR := preload("res://editor/lock_editor.tscn")
## the idea is that non-standard-levels should be able to exist, maybe, but they must be labeled as such (for example doors with non-32-multiple sizes, or a door starting out browned or with a different glitch color. things that are valid but.. not standard)
## unimplemented for now tho lol
var non_standard_mode := false

func _init() -> void:
	if not is_instance_valid(door_data):
		door_data = DoorData.new()
		door_data.outer_color = Enums.colors.white
		var lock := LockData.new()
		lock.color = Enums.colors.white
		door_data.locks.push_back(lock)

var is_ready := false
func _ready() -> void:
	is_ready = true
	door.door_data = door_data
	width.get_line_edit().add_theme_constant_override(&"minimum_character_width", 2)
	height.get_line_edit().add_theme_constant_override(&"minimum_character_width", 2)
	real_copies.get_line_edit().add_theme_constant_override(&"minimum_character_width", 2)
	imaginary_copies.get_line_edit().add_theme_constant_override(&"minimum_character_width", 2)
	width.get_line_edit().expand_to_text_length = true
	height.get_line_edit().expand_to_text_length = true
	real_copies.get_line_edit().expand_to_text_length = true
	imaginary_copies.get_line_edit().expand_to_text_length = true
	
	ice_button.tooltip_text = "Ice curse, broken with 1 red key or more."
	erosion_button.tooltip_text = "Erosion curse, broken with 5 green keys or more."
	paint_button.tooltip_text = "Paint curse, broken with 3 blue keys or more."
	ice_button.toggled.connect(ice_checkbox.set_pressed_no_signal)
	ice_button.toggled.connect(set_curse.bind(Enums.curse.ice))
	erosion_button.toggled.connect(erosion_checkbox.set_pressed_no_signal)
	erosion_button.toggled.connect(set_curse.bind(Enums.curse.erosion))
	paint_button.toggled.connect(paint_checkbox.set_pressed_no_signal)
	paint_button.toggled.connect(set_curse.bind(Enums.curse.paint))
	
	width.value_changed.connect(_update_door_size.unbind(1))
	height.value_changed.connect(_update_door_size.unbind(1))
	real_copies.value_changed.connect(_update_door_amount.unbind(1))
	imaginary_copies.value_changed.connect(_update_door_amount.unbind(1))
	color_choice.item_selected.connect(_update_door_color.unbind(1))
	
	color_choice.clear()
	for key in Enums.COLOR_NAMES.keys():
		if key == Enums.colors.none: continue
		color_choice.add_item(Enums.COLOR_NAMES[key].capitalize(), key)
	
	add_lock.pressed.connect(_add_new_lock)
	
	_set_to_door_data()

func _set_to_door_data() -> void:
	ice_button.button_pressed = door_data.get_curse(Enums.curse.ice)
	erosion_button.button_pressed = door_data.get_curse(Enums.curse.erosion)
	paint_button.button_pressed = door_data.get_curse(Enums.curse.paint)
	width.value = door_data.size.x
	height.value = door_data.size.y
	
	real_copies.value = door_data.amount.real_part
	imaginary_copies.value = door_data.amount.imaginary_part
	
	color_choice.selected = color_choice.get_item_index(door_data.outer_color) 
	
	_regen_lock_editors()

func set_curse(val: bool, which: Enums.curse) -> void:
	door_data.set_curse(which, val)

func _update_door_size() -> void:
	door_data.size = Vector2i(roundi(width.value), roundi(height.value))
	_update_lock_editors_door_size()

func _update_door_amount() -> void:
	door_data.amount.set_to(real_copies.value, imaginary_copies.value)

func _update_door_color() -> void:
	door_data.outer_color = color_choice.get_item_id(color_choice.selected)

func _regen_lock_editors() -> void:
	for child in lock_editor_parent.get_children():
		child.queue_free()
	var i := 1
	for lock_data in door_data.locks:
		var lock_editor: LockEditor = LOCK_EDITOR.instantiate()
		lock_editor.lock_number = i
		lock_editor.lock_data = lock_data
		lock_editor.door_size = door_data.size
		lock_editor.delete.connect(_delete_lock.bind(i-1))
		lock_editor_parent.add_child(lock_editor)
		i += 1
	add_lock.text = "Add Lock %d" % i

func _update_lock_editors_door_size() -> void:
	for editor in lock_editor_parent.get_children():
		editor.door_size = door_data.size

func _add_new_lock() -> void:
	var new_lock := LockData.new()
	new_lock.color = door_data.outer_color
	door_data.locks.push_back(new_lock)
	# TODO: Make the door simply add a lock
	door.update_locks()
	# TODO: Simply add an editor
	_regen_lock_editors()

func _delete_lock(i: int) -> void:
	door_data.locks.remove_at(i)
	# TODO: Make the door simply remove a lock
	door.update_locks()
	# TODO: Simply remove an editor
	_regen_lock_editors()
