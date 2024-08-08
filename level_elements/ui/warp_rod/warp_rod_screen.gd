#@tool
extends Control
class_name WarpRodScreen

@export var can_drag_nodes := true:
	set(val):
		can_drag_nodes = val
		for node in get_children():
			node.can_be_dragged = can_drag_nodes

@onready var beep: AudioStreamPlayer = %Beep
var connection_draw: WarpRodConnectionDraw

var use_physics := true

func _init() -> void:
	connection_draw = WarpRodConnectionDraw.new()
	connection_draw.screen = self
	item_rect_changed.connect(connection_draw.queue_redraw)
	child_entered_tree.connect(_on_node_added)
	child_exiting_tree.connect(_on_node_removed)

func _ready() -> void:
	get_parent().add_child.call_deferred(connection_draw, false, Node.INTERNAL_MODE_FRONT)

var time := 0
const MULT := 10
const REPEL_MULT := (1280.0 ** 2)
const REPEL_MULT_CONNECTION := REPEL_MULT / 2.0
const ATTRACT_MULT := 8.0
var collision_system := CollisionSystem.new(64)
var node_to_id := {}
func _physics_process(delta: float) -> void:
	if not is_visible_in_tree(): return
	if not use_physics: return
	if Global.in_editor: return
	time += 1
	if time <= 1: return
	assert(PerfManager.start("WarpRodScreen::physics"))
	var avg_position := Vector2.ZERO
	delta *= MULT
	for node: WarpRodNode in get_children():
		var id: int = node_to_id[node]
		avg_position += node.get_center()
		var rect := node.get_rect()
		var force := Vector2.ZERO
		# separate from close ones
		var extended_rect := rect.grow(640)
		var close_ids := collision_system.get_rects_intersecting_rect_in_grid(extended_rect)
		var has_collision := false
		for id2: int in close_ids:
			if id2 == id: continue
			var node2: WarpRodNode = collision_system.get_rect_data(id2)
			var rect2 := node2.get_rect()
			# diff vector for movement
			var diff: Vector2 = node2.get_center() - node.get_center()
			# distance to measure force
			# WAITING4GODOT: can't infer???
			var distance: float = Global.distance_between_rects(rect, rect2).length_squared()
			if distance <= 1.0:
				distance = 1
				has_collision = true
			# force gets smaller the further away it is
			if node2 in node.connects_to:
				force -= diff.normalized() * (1.0 / distance) * REPEL_MULT_CONNECTION
			else:
				force -= diff.normalized() * (1.0 / distance) * REPEL_MULT
		# get closer to connected ones
		if not has_collision:
			var attraction_force := Vector2.ZERO
			for node2 in node.connects_to:
				var rect2 := node2.get_rect()
				var diff: Vector2 = node2.get_center() - node.get_center()
				# WAITING4GODOT: can't infer???
				var distance: float = Global.distance_between_rects(rect, rect2).length()
				if distance <= 3.0:
					distance = 0
				# force gets bigger the further away it is
				attraction_force += diff.normalized() * distance * ATTRACT_MULT
			force += attraction_force / node.connects_to.size()
		
		node.position += force * delta * delta
	avg_position /= get_child_count()
	# avg_position MUST be centered...
	var avg_position_offset = size / 2 - avg_position
	for node in get_children():
		node.position += avg_position_offset
	assert(PerfManager.end("WarpRodScreen::physics"))

func _on_node_added(node: WarpRodNode) -> void:
	node.hovered.connect(_on_node_hovered.bind(node))
	node.item_rect_changed.connect(_on_node_moved.bind(node))
	node.can_be_dragged = can_drag_nodes
	var id := collision_system.add_rect(node.get_rect() as Rect2i, node)
	node_to_id[node] = id
	connection_draw.queue_redraw()

func _on_node_removed(node: WarpRodNode) -> void:
	node.hovered.disconnect(_on_node_hovered.bind(node))
	node.item_rect_changed.disconnect(_on_node_moved.bind(node))
	collision_system.remove_rect(node_to_id[node])
	node_to_id.erase(node)
	connection_draw.queue_redraw()

func _on_node_hovered(node: WarpRodNode) -> void:
	if not can_drag_nodes:
		if node.state != node.State.Unavailable:
			beep.play()

func _on_node_moved(node: WarpRodNode) -> void:
	var id: int = node_to_id[node]
	collision_system.change_rect(id, node.get_rect() as Rect2i)
	connection_draw.queue_redraw()

