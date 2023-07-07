@tool
extends Window
class_name InvalidLevelLoad
@onready var container: Container = %Container
@onready var fixable: Label = %Fixable
@onready var fixable_list: Label = %FixableList
@onready var unfixable: Label = %Unfixable
@onready var unfixable_list: Label = %UnfixableList
@onready var explanation: Label = %Explanation
@onready var scroll_container: ScrollContainer = %ScrollContainer

signal load_level_fixed
signal load_level_unfixed
@onready var load_unfixed: Button = %LoadUnfixed
@onready var load_fixed: Button = %LoadFixed
@onready var cancel: Button = %Cancel

func _ready() -> void:
	close_requested.connect(hide)
	cancel.pressed.connect(hide)
	load_fixed.pressed.connect(hide)
	load_fixed.pressed.connect(func(): load_level_fixed.emit())
	load_unfixed.pressed.connect(hide)
	load_unfixed.pressed.connect(func(): load_level_unfixed.emit())
	size_changed.connect(_adjust)
	container.minimum_size_changed.connect(_adjust)

var last_position := position
func _process(_delta: float) -> void:
	if position != last_position:
		_adjust()

func _adjust() -> void:
	var min := container.get_minimum_size()
	min = min.clamp(scroll_container.get_minimum_size(), min)
	var new_rect := Rect2i(position, size)
	new_rect.size = new_rect.size.clamp(min, max_size)
	new_rect.size.y = min.y as int
	var border := 10
	var border_2 := 35
	new_rect = Global.smart_adjust_rect(new_rect, Rect2i(Vector2i(border, border_2), get_tree().root.size - Vector2i(border * 2, border + border_2)))
	if size != new_rect.size:
		size = new_rect.size
	if position != new_rect.position:
		position = new_rect.position
	last_position = position

func appear(fixable_problems: Array[String], unfixable_problems: Array[String]) -> void:
	print(get_viewport().size)
	fixable.visible = not fixable_problems.is_empty()
	fixable_list.visible = not fixable_problems.is_empty()
	unfixable.visible = not unfixable_problems.is_empty()
	unfixable_list.visible = not unfixable_problems.is_empty()
	fixable_list.text = ""
	unfixable_list.text = ""
	for problem in fixable_problems:
		fixable_list.text += " • " + problem + "\n"
	fixable_list.text = fixable_list.text.trim_suffix("\n")
	for problem in unfixable_problems:
		unfixable_list.text += " • " + problem + "\n"
	unfixable_list.text = unfixable_list.text.trim_suffix("\n")
	if fixable_problems.is_empty():
		unfixable.text = "It has the following unfixable problems:"
		explanation.hide()
		load_unfixed.text = "Load Anyways"
		load_fixed.hide()
	else:
		unfixable.text = "And the following unfixable problems:"
		explanation.show()
		load_unfixed.text = "Load Unfixed"
		load_fixed.show()
	
	popup_centered()
	_adjust()
