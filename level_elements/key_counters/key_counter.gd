@tool
extends MarginContainer
class_name KeyCounter

static var level_element_type := Enums.LevelElementTypes.KeyCounter

@export var ignore_position := false
@export var data: CounterData:
	set(val):
		if data == val: return
		_disconnect_data()
		data = val
		_connect_data()

const COUNTERPART := preload("res://level_elements/key_counters/counter_part.tscn")
const KEY_START := Vector2i(20, 20)
const KEY_DIFF := Vector2i(204, 68) - KEY_START
const WOOD := preload("res://level_elements/key_counters/box.png")
const STAR := preload("res://level_elements/key_counters/counterstar.png")

@onready var part_holder := %Holder as Control

var using_i_view_colors := false
var level: Level = null:
	set(val):
		if level == val: return
		disconnect_level()
		level = val

func _ready() -> void:
	assert(PerfManager.start("Counter::_ready"))
	
	if is_instance_valid(level):
		assert(visible)
	update_visuals()
	assert(PerfManager.end("Counter::_ready"))
	
func _enter_tree():
	if not is_node_ready(): return
	
	# reset collisions
	update_visuals()

func _exit_tree():
	# in case that problem ever would appear on doors as well
	custom_minimum_size = Vector2(0, 0)

func _connect_data() -> void:
	if not is_instance_valid(data): return
	data.changed.connect(update_visuals)
	
	if not is_inside_tree(): return
	update_visuals()
	show()

func _disconnect_data() -> void:
	if not is_instance_valid(data): return
	update_visuals()
	data.changed.disconnect(update_visuals)

func disconnect_level() -> void:
	if not is_instance_valid(level): return

func update_visuals() -> void:
	# We will run this later, when we _enter_tree
	if not is_inside_tree(): return
	if not is_instance_valid(data): return
	assert(PerfManager.start(&"Counter::update_visuals"))
	update_position()
	update_textures()
	update_counter_parts()
	
	assert(PerfManager.end(&"Counter::update_visuals"))

func update_position() -> void:
	if not ignore_position:
		position = data.position

func update_textures() -> void:
	if not is_node_ready(): return
	if not is_instance_valid(data): return
	custom_minimum_size = Vector2i(data.length, 17 + data.colors.size() * 49)
	
func update_counter_parts() -> void:
	if not is_instance_valid(data): return
	assert(PerfManager.start(&"Counter::update_counter_parts"))
	
	var needed_counter_parts := data.colors.size()
	var current_counter_parts := part_holder.get_child_count()
	# redo the current ones
	for i in mini(needed_counter_parts, current_counter_parts):
		var counter_part := part_holder.get_child(i)
		counter_part.level = level
		counter_part.data = data.colors[i]
	# shave off the rest
	if current_counter_parts > needed_counter_parts:
		for _i in current_counter_parts - needed_counter_parts:
			var counter_part := part_holder.get_child(-1)
			part_holder.remove_child(counter_part)
			NodePool.return_node(counter_part)
	# or add them
	else:
		for i in range(current_counter_parts, needed_counter_parts):
			var new_counter_part: CounterPart = NodePool.pool_node(COUNTERPART)
			new_counter_part.level = level
			new_counter_part.data = data.colors[i]
			part_holder.add_child(new_counter_part)
	
	assert(PerfManager.end(&"Counter::update_counter_parts"))
