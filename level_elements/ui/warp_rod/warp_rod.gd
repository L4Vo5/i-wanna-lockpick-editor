@tool
extends NinePatchRect
class_name WarpRod

const WARP_ROD_NODE = preload("res://level_elements/ui/warp_rod/warp_rod_node.tscn")

@onready var sound: AudioStreamPlayer = %Sound
@onready var warp_node_dragger: NodeDragger = %WarpNodeDragger
@onready var warp_rod_screen: Control = %WarpRodScreen

var pack_data: LevelPackData:
	set(val):
		pack_data = val
		regen_nodes()

func _ready() -> void:
	warp_rod_screen.node_dragger = warp_node_dragger
	# Kinda useless to do it this way but just making sure.
	var margin_container: MarginContainer = $MarginContainer as MarginContainer
	margin_container.add_theme_constant_override("margin_top", patch_margin_top)
	margin_container.add_theme_constant_override("margin_bottom", patch_margin_bottom)
	margin_container.add_theme_constant_override("margin_left", patch_margin_left)
	margin_container.add_theme_constant_override("margin_right", patch_margin_right)

func show_warp_rod() -> void:
	show()
	sound.pitch_scale = 1.5
	sound.play()
	regen_nodes()

func hide_warp_rod() -> void:
	hide()
	sound.pitch_scale = 1
	sound.play()

var level_to_node := {}
var node_to_level := {}

func regen_nodes() -> void:
	var connections := {}
	for child in warp_rod_screen.get_children():
		child.free()
		level_to_node.clear()
		node_to_level.clear()
	
	var i := 0
	for level in pack_data.levels:
		var warp_title := level.name if level.name else level.title if level.title else "Untitled"
		var pos := Vector2.ZERO
		pos.x = floorf(randf() * warp_rod_screen.size.x)
		pos.y = floorf(randf() * warp_rod_screen.size.y)
		var node := WARP_ROD_NODE.instantiate()
		level_to_node[level] = node
		node_to_level[node] = level
		node.text = warp_title
		warp_rod_screen.add_child(node)
		node.position = pos
		node.state = node.State.Available
		if pack_data.state_data.current_level == i:
			node.state = node.State.Current
		i += 1
	for node: WarpRodNode in node_to_level.keys():
		var level: LevelData = node_to_level[node]
		var connects_to := {}
		for entry in level.entries:
			connects_to[entry.leads_to] = true
		for id: int in connects_to.keys():
			var other_level: LevelData = pack_data.levels[id]
			# Must store connection both ways for the strategy that's used to avoid drawing the same connection twice
			node.connects_to.push_back(level_to_node[other_level])
			level_to_node[other_level].connects_to.push_back(node)
	warp_rod_screen.queue_redraw()
