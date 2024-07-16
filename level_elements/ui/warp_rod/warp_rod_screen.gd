extends Control

@onready var node_dragger: NodeDragger = %WarpNodeDragger
@onready var beep: AudioStreamPlayer = %Beep

var _current_hover: WarpRodNode:
	set = _set_current_hover
var _cancel_hover := false

func _init() -> void:
	child_entered_tree.connect(_on_node_added)
	child_exiting_tree.connect(_on_node_removed)

func _ready() -> void:
	node_dragger.moved_node.connect(queue_redraw)

func _on_node_added(node: WarpRodNode) -> void:
	node.hovered.connect(_on_node_hovered.bind(node))
	node.unhovered.connect(_on_node_unhovered.bind(node))

func _on_node_removed(node: WarpRodNode) -> void:
	node.hovered.disconnect(_on_node_hovered.bind(node))
	node.unhovered.disconnect(_on_node_unhovered.bind(node))
	if _current_hover == node:
		_current_hover = null

func _process(delta: float) -> void:
	# TODO: dragger release event?
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
		beep.play()
	_current_hover = node
	node_dragger.node = node

func _draw() -> void:
	for node: WarpRodNode in get_children():
		var pos1 := node.get_center()
		for node2 in node.connects_to:
			var pos2 := node2.get_center()
			var shadow_angle := pos2.angle_to(pos1)
			var shadow_offset := Vector2.DOWN.rotated(shadow_angle) * 2
			draw_line(pos1 + shadow_offset, pos2 + shadow_offset, Color(0, 0, 0, 0.25), 2)
			draw_line(pos1, pos2, Color.WHITE, 2)
