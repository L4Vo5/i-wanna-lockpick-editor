@tool
extends Container
class_name Node2DCenterContainer

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		for child in get_children():
			child.position = size / 2
