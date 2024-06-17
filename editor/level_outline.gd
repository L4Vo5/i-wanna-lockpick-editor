extends Node2D

var level_data: LevelData

func _ready() -> void:
	_connect_level.call_deferred()

func _connect_level():
	# TODO: no
	var level: Level = get_parent().level
	level.changed_level_data.connect(_on_changed_level_data)
	_on_changed_level_data()

func _on_changed_level_data() -> void:
	# TODO: no
	var level: Level = get_parent().level
	if is_instance_valid(level_data) and level_data.changed_size.is_connected(queue_redraw):
		level_data.changed_size.disconnect(queue_redraw)
	level_data = level.level_data
	if is_instance_valid(level_data):
		level_data.changed_size.connect(queue_redraw)
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(level_data): return
	var border_size := 2
	var rect := Rect2(-position, level_data.size)
	var col := Color.WHITE
	# Left
	draw_rect(Rect2(rect.position - Vector2(border_size, border_size), Vector2(border_size, rect.size.y + border_size)), col)
	# Top
	draw_rect(Rect2(rect.position - Vector2(border_size, border_size), Vector2(rect.size.x + border_size, border_size)), col)
	# Bottom
	draw_rect(Rect2(rect.position + Vector2(-border_size, rect.size.y - border_size), Vector2(rect.size.x + border_size, border_size)), col)
	# Right
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - border_size, - border_size), Vector2(border_size, rect.size.y + border_size)), col)
