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

const COUNTER_PART := preload("res://level_elements/key_counters/counter_part.tscn")

@onready var part_holder := %Holder as Control

var level: Level

func _ready() -> void:
	if is_instance_valid(level):
		assert(visible)
	update_visuals()

func _enter_tree():
	if not is_node_ready(): return
	update_size.call_deferred()
	
	update_visuals()

func _exit_tree() -> void:
	remove_counter_parts()

func _connect_data() -> void:
	if not is_instance_valid(data): return
	data.changed.connect(update_visuals)
	update_size()
	update_visuals()

func _disconnect_data() -> void:
	if not is_instance_valid(data): return
	data.changed.disconnect(update_visuals)

func update_visuals() -> void:
	update_position()
	update_counter_parts()
	update_size()

func update_size() -> void:
	if not is_instance_valid(data): return
	# Vertical size is updated by the minimum size of the color counters
	custom_minimum_size = Vector2(data.length, 0)
	size = custom_minimum_size

func update_position() -> void:
	if not is_instance_valid(data): return
	if not ignore_position:
		position = data.position

func remove_counter_parts() -> void:
	for counter_part in part_holder.get_children():
		part_holder.remove_child(counter_part)
		NodePool.return_node(counter_part)

func update_counter_parts() -> void:
	if not is_node_ready(): return
	if not is_instance_valid(data): return
	remove_counter_parts()
	for part_data in data.colors:
		var new_counter_part: CounterPart = NodePool.pool_node(COUNTER_PART)
		new_counter_part.level = level
		new_counter_part.data = part_data
		part_holder.add_child(new_counter_part)
