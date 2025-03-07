extends Node2D
class_name LevelComment

@onready var comment: Label = %Comment
@onready var room_type: Label = %RoomType
@onready var label: Label = %Label

var level: Level:
	set = set_level

var level_data: LevelData

func set_level(lvl: Level) -> void:
	level = lvl
	level.changed_level_data.connect(on_changed_level_data)

func on_changed_level_data() -> void:
	disconnect_level_data()
	level_data = level.level_data
	connect_level_data()

func disconnect_level_data() -> void:
	if not is_instance_valid(level_data): return
	level_data.changed.disconnect(update)

func connect_level_data() -> void:
	level_data.changed.connect(update)
	update()

func update() -> void:
	if level_data.comment.is_empty():
		hide()
	else:
		show()
		comment.text = level_data.comment
		label.text = level_data.label
		# TODO: allow different texts here?
		room_type.text = "PUZZLE"
