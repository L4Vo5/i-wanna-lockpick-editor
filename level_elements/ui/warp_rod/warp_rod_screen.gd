#@tool
extends Control
class_name WarpRodScreen

signal node_clicked(node: WarpRodNode)
@export var can_drag_nodes := false:
	set(val):
		can_drag_nodes = val
		for node in get_children():
			node.can_be_dragged = can_drag_nodes

@onready var beep: AudioStreamPlayer = %Beep
var connection_draw: WarpRodConnectionDraw

@export var use_physics := false

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
# Distance you wanna have with nodes you're not connected to
const DIST_DISCONNECTED := 40.0
# Distance you wanna have with nodes you're connected to
const DIST_CONNECTED := 40.0
const PULL_STRENGTH := 0.5

var collision_system := CollisionSystem.new(64)
var node_to_id := {}

func _physics_process(delta: float) -> void:
	if not is_visible_in_tree(): return
	if not use_physics: return
	if Global.in_editor: return
	if get_child_count() == 0: return
	time += 1
	if time <= 1: return
	assert(PerfManager.start("WarpRodScreen::physics"))
	var avg_position := Vector2.ZERO
	delta *= MULT
	var forces := {}
	var complication_factor := 0.0
	for node: WarpRodNode in get_children():
		var id: int = node_to_id[node]
		avg_position += node.get_center()
		var rect := node.get_rect()
		var force := Vector2.ZERO
		# separate from close ones
		var extended_rect := rect.grow(DIST_DISCONNECTED+20)
		var close_ids := collision_system.get_rects_intersecting_rect_in_grid(extended_rect)
		var collision_count := 0
		var repellent_force := Vector2.ZERO
		for id2: int in close_ids:
			if id2 == id: continue
			var node2: WarpRodNode = collision_system.get_rect_data(id2)
			var rect2 := node2.get_rect()
			# direction vector for movement
			var diff: Vector2 = node2.get_center() - node.get_center()
			# current distance
			# WAITING4GODOT: can't infer???
			var distance: float = Global.distance_between_rects(rect, rect2).length()
			# We want distance to go this much further
			var further := DIST_DISCONNECTED - distance
			if node2 in node.connects_to:
				further = DIST_CONNECTED - distance
			if distance <= 1.0:
				collision_count += 1
			if further < 0:
				# don't get closer
				continue
			repellent_force -= diff.normalized() * further
		force += repellent_force
		# get closer to connected ones
		var attraction_force := Vector2.ZERO
		var attraction_count = 0
		for node2 in node.connects_to:
			var rect2 := node2.get_rect()
			var diff: Vector2 = node2.get_center() - node.get_center()
			# WAITING4GODOT: can't infer???
			var distance: float = Global.distance_between_rects(rect, rect2).length()
			# we want distance to get this much closer
			var closer := distance - DIST_CONNECTED
			if closer <= 0:
				# don't get further
				continue
			attraction_force += diff.normalized() * closer
			attraction_count += 1
		if attraction_count != 0:
			var attraction_force_reduction := 1.0 - repellent_force.length() / DIST_CONNECTED * (collision_count+1)
			if attraction_force_reduction > 0.0:
				force += attraction_force / attraction_count * attraction_force_reduction * PULL_STRENGTH
		# Prevents being locked on one axis
		force = force.rotated(randf()*0.0001)
		forces[node] = force
		complication_factor += force.length() / DIST_DISCONNECTED * (collision_count + 1)
	delta = clampf(delta * complication_factor / get_child_count(), delta, 0.9)
	for node in forces:
		node.position += forces[node] * delta
	avg_position /= get_child_count()
	# avg_position MUST be centered...
	var avg_position_offset = size / 2 - avg_position
	for node in get_children():
		node.position += avg_position_offset
	assert(PerfManager.end("WarpRodScreen::physics"))

func _on_node_added(node: WarpRodNode) -> void:
	node.hovered.connect(_on_node_hovered.bind(node))
	node.item_rect_changed.connect(_on_node_moved.bind(node))
	node.clicked.connect(_on_node_clicked.bind(node))
	node.can_be_dragged = can_drag_nodes
	var id := collision_system.add_rect(node.get_rect() as Rect2i, node)
	node_to_id[node] = id
	connection_draw.queue_redraw()

func _on_node_removed(node: WarpRodNode) -> void:
	node.hovered.disconnect(_on_node_hovered.bind(node))
	node.item_rect_changed.disconnect(_on_node_moved.bind(node))
	node.clicked.disconnect(_on_node_clicked.bind(node))
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

func _on_node_clicked(node: WarpRodNode) -> void:
	node_clicked.emit(node)
