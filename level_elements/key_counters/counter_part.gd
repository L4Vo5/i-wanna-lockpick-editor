@tool
extends Control
class_name CounterPart

@export var data: CounterPartData

@onready var key: KeyElement = %key
@onready var star: Sprite2D = %Star

@onready var text: Label = %Amount

var level: Level

func _ready() -> void:
	update_visual()
	key.data = KeyData.new()
	if data:
		key.data.color = data.color

func _process(_delta: float) -> void:
	if !data: return
	update_visual()

func update_visual() -> void:
	if not is_node_ready(): return
	if not is_instance_valid(data): return
	key.data.color = data.color
	
	star.hide()
	star.rotation_degrees -= 2
	
	if level:
		text.text = "x " + str(level.logic.key_counts[data.color])
		if level.logic.star_keys[data.color]:
			star.show()
	else:
		text.text = "x 0"
