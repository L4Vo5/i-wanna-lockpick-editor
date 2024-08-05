extends CanvasGroup

var grid_size := Vector2(32, 32):
	set(val):
		if grid_size == val: return
		grid_size = val
		if distance_grid_draw:
			distance_grid_draw.grid_size = grid_size

var offset := Vector2(8, 0):
	set(val):
		offset = val
		adjust_based_on_mouse_pos()

@onready var distance_grid_draw: PhantomGridDraw = %DistanceGridDraw

func _ready() -> void:
	var amount := 2
	distance_grid_draw.grid_size = grid_size
	distance_grid_draw.amount = amount
	var actual_amount := amount * 2 + 1
	material.set_shader_parameter("dist_mult", 1.0 / ((actual_amount-1)/(actual_amount as float)))
	adjust_based_on_mouse_pos()
	
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()

func _on_visibility_changed() -> void:
	if visible:
		set_process_input(true)
	else:
		set_process_input(false)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		adjust_based_on_mouse_pos()

func adjust_based_on_mouse_pos() -> void:
	var mouse_pos := get_global_mouse_position()
	#var plus_pos := Vector2.ZERO
	#if get_viewport().get_camera_2d():
		#plus_pos = get_viewport().get_camera_2d().position
	#mouse_pos += plus_pos
	
	var snapped_pos := ((mouse_pos - offset) / grid_size).floor() * grid_size + offset
	distance_grid_draw.position = snapped_pos
	var rect := distance_grid_draw.get_rect()
	var center := (mouse_pos - rect.position) / rect.size
	material.set_shader_parameter("center", center)

