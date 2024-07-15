@tool
extends Container
class_name MinimumSizeContainer
## A node that sets its minimum size to its children's size.
## It also sets its children's size to its own size.

@export var vertical := false:
	set(val):
		vertical = val
		queue_sort()
@export var horizontal := false:
	set(val):
		vertical = val
		queue_sort()

func _init() -> void:
	sort_children.connect(_sort_children)
	child_entered_tree.connect(_on_child_entered_tree)
	child_exiting_tree.connect(_on_child_exiting_tree)

func _on_child_entered_tree(child: Node) -> void:
	if child is Control:
		child.resized.connect(_sort_children)

func _on_child_exiting_tree(child: Node) -> void:
	if child is Control:
		child.resized.disconnect(_sort_children)

func _sort_children() -> void:
	if horizontal or vertical:
		for child in get_children():
			if not horizontal:
				child.size.x = size.x
			if not vertical:
				child.size.y = size.y
	update_minimum_size()

func _get_minimum_size() -> Vector2:
	var s := Vector2.ZERO
	for child: Control in get_children():
		var s2 := Vector2.ZERO
		if vertical:
			s2.y = child.size.y
		else:
			s2.y = child.get_combined_minimum_size().y
		if horizontal:
			s2.x = child.size.x
		else:
			s2.x = child.get_combined_minimum_size().x
		s.x = maxf(s.x, s2.x)
		s.y = maxf(s.y, s2.y)
	return s
