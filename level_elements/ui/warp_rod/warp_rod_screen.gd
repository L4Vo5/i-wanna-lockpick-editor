@tool
extends Control

@export var can_drag_nodes := true

var node_dragger: NodeDragger:
	set(val):
		assert(not node_dragger)
		node_dragger = val
		node_dragger.moved_node.connect(queue_redraw)
@onready var beep: AudioStreamPlayer = %Beep

var _current_hover: WarpRodNode:
	set = _set_current_hover
var _cancel_hover := false

func _init() -> void:
	child_entered_tree.connect(_on_node_added)
	child_exiting_tree.connect(_on_node_removed)

func _ready() -> void:
	# Debug
	for child in get_children():
		for other_child in get_children():
			if child != other_child:
				child.connects_to.push_back(other_child)

func _on_node_added(node: WarpRodNode) -> void:
	node.hovered.connect(_on_node_hovered.bind(node))
	node.unhovered.connect(_on_node_unhovered.bind(node))

func _on_node_removed(node: WarpRodNode) -> void:
	node.hovered.disconnect(_on_node_hovered.bind(node))
	node.unhovered.disconnect(_on_node_unhovered.bind(node))
	if _current_hover == node:
		_current_hover = null

func _process(delta: float) -> void:
	# maybe replace with a dragger release event?
	if _cancel_hover and not node_dragger.action_is_pressed:
		_current_hover = null

func _on_node_hovered(node: WarpRodNode) -> void:
	if _current_hover == null:
		_current_hover = node
	if _current_hover == node:
		_cancel_hover = false

func _on_node_unhovered(node: WarpRodNode) -> void:
	if _current_hover == node:
		if not node_dragger.action_is_pressed:
			_current_hover = null
		else:
			_cancel_hover = true

func _set_current_hover(node: WarpRodNode) -> void:
	if _current_hover == node: return
	if node:
		if not can_drag_nodes:
			if node.state != node.State.Unavailable:
				node.outline.show()
				beep.play()
		else:
			node.outline.show()
	_current_hover = node
	if can_drag_nodes:
		node_dragger.node = node

func _draw() -> void:
	for node: WarpRodNode in get_children():
		var pos1 := node.get_center()
		for node2 in node.connects_to:
			var pos2 := node2.get_center()
			if not test_vecs(pos1, pos2): continue
			#print("Drawing line between %s and %s" % [pos1, pos2])
			var shadow_angle := pos2.angle_to(pos1)
			var shadow_offset := Vector2.DOWN.rotated(shadow_angle) * 4
			if shadow_offset.y < 0:
				shadow_offset = -shadow_offset
			draw_line(pos1 + shadow_offset, pos2 + shadow_offset, Color(0, 0, 0, 0.25), 2)
			draw_line(pos1, pos2, Color.WHITE, 2)

# For a pair of non-equal vecs A, B, whatever value is returned for (A, B), the opposite is always returned for (B, A)
func test_vecs(v1: Vector2, v2: Vector2) -> bool:
	return v1.x < v2.x or (v1.x == v2.x and v1.y < v2.y)
