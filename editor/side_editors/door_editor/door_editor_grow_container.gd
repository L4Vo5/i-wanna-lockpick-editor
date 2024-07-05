extends GrowContainer
# if this is unused it's because I changed my mind

func _ready() -> void:
	super._ready()
	get_child(0).get_child(0).resized.connect(_adjust_max_size)

func _adjust_max_size() -> void:
	max_child_size = get_child(0).get_child(0).size.y + 8
