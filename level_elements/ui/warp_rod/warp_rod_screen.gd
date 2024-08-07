@tool
extends Control

@export var can_drag_nodes := true:
	set(val):
		can_drag_nodes = val
		for node in get_children():
			node.can_be_dragged = can_drag_nodes

@onready var beep: AudioStreamPlayer = %Beep

func _init() -> void:
	child_entered_tree.connect(_on_node_added)
	child_exiting_tree.connect(_on_node_removed)

func _on_node_added(node: WarpRodNode) -> void:
	node.hovered.connect(_on_node_hovered.bind(node))
	node.can_be_dragged = can_drag_nodes

func _on_node_removed(node: WarpRodNode) -> void:
	node.hovered.disconnect(_on_node_hovered.bind(node))

func _on_node_hovered(node: WarpRodNode) -> void:
	if not can_drag_nodes:
		if node.state != node.State.Unavailable:
			beep.play()

func _draw() -> void:
	for node: WarpRodNode in get_children():
		var pos1 := node.get_center()
		for node2 in node.connects_to:
			var pos2 := node2.get_center()
			if not test_vecs(pos1, pos2): continue
			#print("Drawing line between %s and %s" % [pos1, pos2])
			var shadow_angle := pos2.angle_to_point(pos1)
			var shadow_offset := Vector2.DOWN.rotated(shadow_angle) * 2
			if shadow_offset.y < 0:
				shadow_offset = -shadow_offset
			draw_line(pos1 + shadow_offset, pos2 + shadow_offset, Color(0, 0, 0, 0.25), 2)
			draw_line(pos1, pos2, Color.WHITE, 2)

# For a pair of non-equal vecs A, B, whatever value is returned for (A, B), the opposite is always returned for (B, A)
func test_vecs(v1: Vector2, v2: Vector2) -> bool:
	return v1.x < v2.x or (v1.x == v2.x and v1.y < v2.y)
