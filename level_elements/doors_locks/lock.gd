@tool
extends MarginContainer
class_name Lock

signal clicked(event: InputEventMouseButton)

const FRAME_POS := preload("res://level_elements/doors_locks/textures/lock_frame_texture_pos.png")
const FRAME_NEG := preload("res://level_elements/doors_locks/textures/lock_frame_texture_neg.png")

signal changed_lock_data
@export var lock_data: LockData:
	set(val):
		if lock_data == val: return
		disconnect_lock_data()
		lock_data = val
		connect_lock_data()

@onready var inner_color := %Color as ColorRect
@onready var frame := %Frame as NinePatchRect
@onready var special_anim: Sprite2D = %SpecialAnim # master and pure
@onready var stone_texture: TextureRect = %StoneTexture
@onready var glitch: NinePatchRect = %Glitch

@onready var locks_parent := %Locks as Node2D
@onready var lock_count_number := %LockCountDraw
@onready var lock_template := %LockTemplate as Sprite2D

@export var ignore_position := false

## There's too many connections, so this makes them more organized...
## For each method, what LockData signals is it called from?
# Believe it or not, making it a variable is about twice as fast as a constant, since the constant needs me to construct the callable references myself from the signal names
var CONNECTIONS = {
	update_position: [&"changed_position"],
	update_size: [&"changed_size"],
	update_lock_size: [&"changed_minimum_size"],
	update_frame_visible: [&"changed_dont_show_frame"],
	update_frame_texture: [&"changed_sign", &"changed_rotation"],
	update_colors: [&"changed_color", &"changed_glitch", &"changed_is_cursed"],
	regenerate_locks: [&"changed_lock_type", &"changed_magnitude", &"changed_sign", &"changed_value_type", &"changed_dont_show_lock", &"changed_lock_arrangement", &"changed_rotation", ],
}

func connect_lock_data() -> void:
	if not is_instance_valid(lock_data): return
	if not is_node_ready(): return
	assert(PerfManager.start(&"Lock::connect_lock_data"))
	# Connect all the signals
	lock_data.changed_position.connect(update_position)
	lock_data.changed_size.connect(update_size)
	lock_data.changed_minimum_size.connect(update_lock_size)
	lock_data.changed_dont_show_frame.connect(update_frame_visible)
	lock_data.changed_sign.connect(update_frame_texture)
	lock_data.changed_rotation.connect(update_frame_texture)
	lock_data.changed_color.connect(update_colors)
	lock_data.changed_glitch.connect(update_colors)
	lock_data.changed_is_cursed.connect(update_colors)
	lock_data.changed_lock_type.connect(regenerate_locks)
	lock_data.changed_magnitude.connect(regenerate_locks)
	lock_data.changed_sign.connect(regenerate_locks)
	lock_data.changed_value_type.connect(regenerate_locks)
	lock_data.changed_dont_show_lock.connect(regenerate_locks)
	lock_data.changed_lock_arrangement.connect(regenerate_locks)
	lock_data.changed_rotation.connect(regenerate_locks)
	
	# Call the methods to update everything now
	update_position()
	update_size()
	update_lock_size()
	update_frame_visible()
	update_frame_texture()
	update_colors()
	regenerate_locks()
	assert(PerfManager.end(&"Lock::connect_lock_data"))

func disconnect_lock_data() -> void:
	if not is_instance_valid(lock_data): return
	for method in CONNECTIONS.keys():
		for sig in CONNECTIONS[method]:
			lock_data.disconnect(sig, method)

func _ready() -> void:
	connect_lock_data()

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(lock_data): return
	special_anim.frame = floori(Global.time / Rendering.SPECIAL_ANIM_SPEED) % special_anim.hframes * special_anim.vframes
	if lock_data.color == Enums.colors.glitch:
		special_anim.frame = 0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		clicked.emit(event)
		# the event should be accepted on the signal receiver's side

func update_position() -> void:
	if not ignore_position:
		position = lock_data.position

func update_size() -> void:
	custom_minimum_size = lock_data.size
	size = custom_minimum_size
	special_anim.scale = size / Vector2(1,64)

func update_lock_size() -> void:
	lock_data.size = Vector2i(
		maxi(lock_data.size.x, lock_data.minimum_size.x),
		maxi(lock_data.size.y, lock_data.minimum_size.y))


func update_frame_visible() -> void:
	if lock_data.dont_show_frame:
		frame.hide()
		locks_parent.hide()
		lock_count_number.hide()
	else:
		frame.show()
		locks_parent.show()
		lock_count_number.show()

func update_frame_texture() -> void:
	var amount := lock_data.get_complex_amount().multiply_by(lock_data.rotation)
	var sign := amount.sign_1d()
	frame.texture = FRAME_POS if sign == Enums.sign.positive else FRAME_NEG

func update_colors() -> void:
	inner_color.hide()
	special_anim.hide()
	stone_texture.hide()
	glitch.hide()
	
	if lock_data.color == Enums.colors.none:
		return
	var used_color := lock_data.color
	if lock_data.is_cursed:
		used_color = Enums.colors.brown
	
	if used_color == Enums.colors.glitch:
		glitch.show()
		if lock_data.glitch_color == Enums.colors.glitch:
			glitch.texture = preload("res://level_elements/doors_locks/textures/glitch_lock_1.png")
			return
		else:
			glitch.texture = preload("res://level_elements/doors_locks/textures/glitch_lock_2.png")
			used_color = lock_data.glitch_color
	
	if used_color in [Enums.colors.master, Enums.colors.pure]:
		special_anim.show()
		special_anim.hframes = 4
		special_anim.texture = {
			Enums.colors.master: preload("res://level_elements/doors_locks/textures/gold_gradient.png"),
			Enums.colors.pure: preload("res://level_elements/doors_locks/textures/pure_gradient.png")
		}[used_color]
	elif used_color == Enums.colors.stone:
		stone_texture.show()
	elif used_color == Enums.colors.glitch:
		glitch.show()
	else:
		inner_color.show()
		inner_color.color = Rendering.color_colors[used_color][0]

# PERF: Currently it takes about 2ms to draw the 24-lock variation, 1ms for the 8-lock. Just draw the locks manually instead of using nodes. Maybe same for the LockCountDraw: make it a static method or even just draw it in this class. Would make it not show properly if the number exceeds the box and it goes offscreen, but the number shouldn't exceed the box in the first place. 
func regenerate_locks() -> void:
	assert(PerfManager.start(&"Lock::regenerate_locks"))
	var amount := lock_data.get_complex_amount().multiply_by(lock_data.rotation)
	var sign := amount.sign_1d()
	var value_type := amount.value_type_1d()
	# magnitude is the same lol
	var magnitude := lock_data.magnitude
	lock_count_number.text = ""
	for child in locks_parent.get_children():
		child.queue_free()
	match lock_data.lock_type:
		Enums.lock_types.blast:
			lock_count_number.modulate = Rendering.lock_colors[sign]
			lock_count_number.text = "x" if value_type == Enums.value.real else "+"
			lock_count_number.lock_type = 2
		Enums.lock_types.all:
			lock_count_number.modulate = Rendering.lock_colors[sign]
			lock_count_number.text = "="
			lock_count_number.lock_type = 2
		Enums.lock_types.normal:
			var arrangement = Rendering.get_lock_arrangement(magnitude, lock_data.lock_arrangement)
			if arrangement != null:
				locks_parent.modulate = Rendering.lock_colors[sign]
				lock_data.minimum_size = Vector2i(arrangement[0], arrangement[1])
				for lock_position in arrangement[2]:
					var lock := lock_template.duplicate() as Sprite2D
					lock.show()
					lock.frame = lock_position[2] + (3 if value_type == Enums.value.imaginary else 0)
					lock.position = Vector2(lock_position[0], lock_position[1])
					lock.rotation_degrees = lock_position[3]
					if lock_position.size() == 5:
						lock.flip_h = lock_position[4]
					locks_parent.add_child(lock)
			else:
				lock_count_number.modulate = Rendering.lock_colors[sign]
				lock_count_number.text = str(magnitude)
				lock_count_number.lock_type = 2 if lock_data.dont_show_lock else 0 if value_type == Enums.value.real else 1 if value_type == Enums.value.imaginary else 2
				# Add 4 for the frame size
				lock_data.minimum_size = lock_count_number.custom_minimum_size + Vector2(4, 4)
	assert(PerfManager.end(&"Lock::regenerate_locks"))


