@tool
extends Container
class_name GrowContainer

@export_group("Sides", "grow_")
# could add the rest in theory, but no need to right now
@export var grow_bottom := true
#@export var grow_top := false
#@export var grow_left := false
#@export var grow_right := false

@export var grabber_offset := 5
var max_child_size := -1:
	set(val):
		max_child_size = val
		# hack but whatever
		_on_grabber_moved(Vector2.ZERO)

var _grabber_bottom: GrowContainerGrabber

var _v_grabber_texture: Texture2D
var _h_grabber_texture: Texture2D

func _init() -> void:
	theme_changed.connect(_update_theme)
	sort_children.connect(_sort_children)

func _ready() -> void:
	_grabber_bottom = GrowContainerGrabber.new()
	add_child(_grabber_bottom, false, Node.INTERNAL_MODE_FRONT)
	_grabber_bottom.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	_grabber_bottom.texture = _v_grabber_texture
	_grabber_bottom.moved_mult = Vector2(0, 1)
	_grabber_bottom.moved.connect(_on_grabber_moved)

func _update_theme() -> void:
	_v_grabber_texture = get_theme_icon("v_grabber", "SplitContainer")
	_h_grabber_texture = get_theme_icon("h_grabber", "SplitContainer")

func _get_configuration_warnings() -> PackedStringArray:
	if get_child_count() > 1:
		return ["This node should only have one child."]
	return []

func _on_grabber_moved(relative: Vector2) -> void:
	if get_child_count() == 0: return
	var child: Control = get_child(0)
	var new_size := child.size + relative
	if max_child_size != -1:
		new_size.y = min(max_child_size, new_size.y)
	child.size = new_size 
	queue_sort()

func _sort_children() -> void:
	if get_child_count() == 0: return
	var child := get_child(0)
	child.size.x = size.x
	custom_minimum_size.y = child.size.y
	if grow_bottom:
		custom_minimum_size.y += grabber_offset + _v_grabber_texture.get_size().y
	_grabber_bottom.position.y = child.size.y
	_grabber_bottom.size.x = size.x
	_grabber_bottom.size.y = grabber_offset + _v_grabber_texture.get_size().y
	if child.size.y >= max_child_size:
		_grabber_bottom.hidden_alpha = 0
	else:
		_grabber_bottom.hidden_alpha = 0.5

class GrowContainerGrabber:
	extends Control
	var texture: Texture2D
	
	signal moved(relative: Vector2)
	var moved_mult := Vector2.ZERO
	
	@export var hidden_alpha := 0.25:
		set(val):
			hidden_alpha = val
			if not mouse_inside:
				modulate.a = hidden_alpha
	
	func _ready() -> void:
		hidden_alpha = hidden_alpha
	
	var is_clicked := false
	var mouse_inside := false
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				is_clicked = false
			if is_clicked:
				var rel: Vector2 = event.relative * moved_mult
				if not rel.is_zero_approx():
					moved.emit(rel)
		elif event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				is_clicked = event.pressed
				accept_event()
	
	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER:
			mouse_inside = true
			modulate.a = 1
		if what == NOTIFICATION_MOUSE_EXIT:
			mouse_inside = false
			modulate.a = hidden_alpha
	
	func _draw() -> void:
		var pos := (size - texture.get_size()) / 2.0
		draw_texture(texture, pos)
