@tool
extends Control
# Shouldn't call it Key because there's a global enum called Key!
class_name CounterPart
## Key lol

@export var data: CounterPartData:
	set(val):
		if data == val: return
		_disconnect_data()
		data = val
		_connect_data()

@onready var key: KeyElement = %key
@onready var star: Sprite2D = %Star

@onready var text: Label = %Amount

var level: Level = null:
	set(val):
		if level == val: return
		disconnect_level()
		level = val
		connect_level()

func _ready() -> void:
	update_visual()
	key.data = KeyData.new()
	if data:
		key.data.color = data.color

func disconnect_level() -> void:
	if not is_instance_valid(level): return

func connect_level() -> void:
	if not is_instance_valid(level): return

func _connect_data() -> void:
	if not is_instance_valid(data): return
	data.changed.connect(update_visual)
	update_visual()
	# look... ok?
	show()

func _disconnect_data() -> void:
	if is_instance_valid(data):
		data.changed.disconnect(update_visual)

func _process(_delta: float) -> void:
	if !data: return
	update_visual()


func update_visual() -> void:
	if not is_node_ready(): return
	if not is_instance_valid(data): return
	key.data.color = data.color
	
	star.hide()
	star.rotation_degrees += 1.1
	
	if level:
		text.text = "x " + str(level.logic.key_counts[data.color])
		if level.logic.star_keys[data.color]:
			star.show()
	else:
		text.text = "x 0"
