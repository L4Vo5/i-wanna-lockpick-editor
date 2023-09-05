@tool
extends Control
class_name ColorChoiceEditor

const LOCK := preload("res://level_elements/doors_locks/lock.tscn")
var lock_size := 14
var lock_sep := 10
var lock_occupied_size: int:
	get:
		return lock_size + lock_sep
var locks: Array[Lock] = []
@onready var color_rect: ColorRect = $ColorRect
signal changed_color(color: Enums.colors)
var selected_lock: Lock = null:
	set(val):
		if selected_lock == val: return
		selected_lock = val
		if selected_lock != null:
			changed_color.emit(selected_lock.lock_data.color)

func _ready():
	for color in Enums.COLOR_NAMES.keys():
		if color == Enums.colors.none: continue
		var l := LOCK.instantiate()
		var ld := LockData.new()
		ld.dont_show_frame = true
		ld.color = color
		# Lock will draw it 4px smaller to account for frame
		ld.size = Vector2i.ONE * (lock_size + 4)
		l.ignore_position = true
		l.lock_data = ld
		locks.push_back(l)
		add_child(l)
	resized.connect(_redistribute_locks)
	_redistribute_locks()
	custom_minimum_size.x = lock_size
	custom_minimum_size.y = lock_size

var locks_per_row: int
var free_space: float
var row_count: int
func _redistribute_locks() -> void:
	locks_per_row = ceili(size.x / lock_occupied_size)
	free_space = size.x - (locks_per_row * lock_size + (locks_per_row - 1) * lock_sep)
	# Round up so there's always at least 1 row
	row_count = ((locks.size() + locks_per_row - 1) / locks_per_row)
	custom_minimum_size.y = row_count * lock_occupied_size
	for i in locks.size():
		# -2 because locks are drawn taking frame into account
		var x := free_space / 2.0 + (i % locks_per_row) * lock_occupied_size - 2 
		var y := (i / locks_per_row) * lock_occupied_size + lock_sep / 2.0 - 2
		var lock := locks[i]
		lock.position = Vector2(x, y)
	reposition_color_rect()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if detect_selected_lock():
				accept_event()
	elif (event is InputEventMouseMotion) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if detect_selected_lock():
			accept_event()

func detect_selected_lock() -> bool:
	var mouse_pos := get_local_mouse_position()
	var base_rect := Rect2(Vector2.ZERO, size)
	var virtual_rect := Rect2(
		Vector2(free_space / 2.0, 0), 
			Vector2(
				size.x - free_space,
				row_count * lock_occupied_size
			)
		)
	if base_rect.has_point(mouse_pos):
		var grid_pos := Vector2i((mouse_pos - virtual_rect.position) / lock_occupied_size)
		grid_pos.x = clampi(grid_pos.x, 0, locks_per_row - 1)
		grid_pos.y = clampi(grid_pos.y, 0, row_count - 1)
		var i := grid_pos.x + grid_pos.y * locks_per_row
		i = clampi(i, 0, locks.size() - 1)
		selected_lock = locks[i]
		reposition_color_rect()
		return true
	else:
		return false

func reposition_color_rect() -> void:
	color_rect.size = Vector2.ONE * (lock_size + 4)
	if not is_instance_valid(selected_lock):
		color_rect.hide()
	else:
		color_rect.show()
		color_rect.position = selected_lock.position

# TODO?
func set_to_color(color: Enums.colors) -> void:
	for l in locks:
		if l.lock_data.color == color:
			selected_lock = l
			return
