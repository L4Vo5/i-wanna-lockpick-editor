@tool
extends NinePatchRect
class_name WarpRod

const WARP_ROD_NODE = preload("res://level_elements/ui/warp_rod/warp_rod_node.tscn")

@onready var sound: AudioStreamPlayer = %Sound
@onready var warp_rod_screen: Control = %WarpRodScreen

var pack_data: LevelPackData:
	get:
		return gameplay_manager.pack_data

var state_data: LevelPackStateData:
	get:
		return gameplay_manager.pack_state

var gameplay_manager: GameplayManager:
	set(val):
		gameplay_manager = val
		regen_nodes()

func _ready() -> void:
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
	if not gameplay_manager: return
	for child in warp_rod_screen.get_children():
		child.free()
		level_to_node.clear()
		node_to_level.clear()
	
	for level_id in pack_data.levels:
		var level: LevelData = pack_data.levels[level_id]
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
		if state_data.current_level == level_id:
			node.state = node.State.Current
	for node: WarpRodNode in node_to_level.keys():
		var level: LevelData = node_to_level[node]
		var connects_to := {}
		for entry in level.entries:
			if pack_data.levels.has(entry.leads_to):
				connects_to[entry.leads_to] = true
		for id: int in connects_to.keys():
			var other_level: LevelData = pack_data.levels[id]
			# Must store connection both ways for the strategy that's used to avoid drawing the same connection twice
			node.connects_to.push_back(level_to_node[other_level])
			level_to_node[other_level].connects_to.push_back(node)
	warp_rod_screen.queue_redraw()
