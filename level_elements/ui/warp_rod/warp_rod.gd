#@tool
extends NinePatchRect
class_name WarpRod

const WARP_ROD_NODE = preload("res://level_elements/ui/warp_rod/warp_rod_node.tscn")

@onready var sound: AudioStreamPlayer = %Sound
@onready var levels_screen: Control = %LevelsScreen
@onready var history_screen: Control = %HistoryScreen

@onready var levels_button: Button = %LevelsButton
@onready var history_button: Button = %HistoryButton
@onready var levels_container: MarginContainer = %Levels
@onready var history_container: MarginContainer = %History
@onready var levels_outline_text: OutlineText = %LevelsOutlineText
@onready var history_outline_text: OutlineText = %HistoryOutlineText

@export var button_group: ButtonGroup

var pack_data: LevelPackData:
	get:
		return gameplay_manager.pack_data

var state_data: LevelPackStateData:
	get:
		return gameplay_manager.pack_state

var gameplay_manager: GameplayManager:
	set(val):
		gameplay_manager = val
		gameplay_manager.pack_data_changed.connect(regen_level_nodes)
		gameplay_manager.pack_data_changed.connect(regen_history_nodes)
		gameplay_manager.entered_level.connect(update_level_nodes)
		gameplay_manager.entered_level.connect(update_history_nodes)
		regen_level_nodes()
		regen_history_nodes()

func _ready() -> void:
	button_group.pressed.connect(_update_visible_tab.unbind(1))
	levels_screen.node_clicked.connect(_on_level_clicked)
	history_screen.node_clicked.connect(_on_history_clicked)
	_update_visible_tab()

func _update_visible_tab() -> void:
	levels_container.visible = button_group.get_pressed_button() == levels_button
	history_container.visible = button_group.get_pressed_button() == history_button
	# xd it works
	levels_outline_text.position.y = 35 if levels_container.visible else 37
	history_outline_text.position.y = 35 if history_container.visible else 37

func show_warp_rod() -> void:
	show()
	sound.pitch_scale = 1.5
	sound.play()

func hide_warp_rod() -> void:
	hide()
	sound.pitch_scale = 1
	sound.play()

func _on_level_clicked(node: WarpRodNode) -> void:
	if node.state == WarpRodNode.State.Current: return
	var level: LevelData = node_to_level[node]
	var id: int = pack_data.levels.find_key(level)
	gameplay_manager.enter_level_new_stack(id)

func _on_history_clicked(node: WarpRodNode) -> void:
	if node.state == WarpRodNode.State.Current: return
	var i: int = node_to_history_index[node]
	gameplay_manager.exit_until(i)

var history_index_to_node: Array[WarpRodNode] = []
var node_to_history_index := {}
func regen_history_nodes() -> void:
	if not gameplay_manager: return
	node_to_history_index.clear()
	history_index_to_node.clear()
	for child in history_screen.get_children():
		child.free()
	
	var base_pos := Vector2.ZERO
	base_pos.x = history_screen.size.x / 2
	var last_y := (state_data.exit_levels.size() - 1) * 32
	if last_y > history_screen.size.y - 32:
		base_pos.y = history_screen.size.y - state_data.exit_levels.size() * 32
	
	# last iteration goes though the current level
	for i in state_data.exit_levels.size() + 1:
		var level_id := state_data.exit_levels[i] if i < state_data.exit_levels.size() else state_data.current_level
		var level: LevelData = pack_data.levels[level_id]
		var warp_title := level.name if level.name else level.title if level.title else "Untitled"
		var pos := base_pos
		pos.y += i * 32
		var node := WARP_ROD_NODE.instantiate()
		history_index_to_node.push_back(node)
		node_to_history_index[node] = i
		node.text = warp_title
		history_screen.add_child(node)
		node.position = pos
		node.position.x -= node.size.x / 2
		node.state = node.State.Available
	history_index_to_node[-1].state = WarpRodNode.State.Current
	for node: WarpRodNode in node_to_history_index.keys():
		var i: int = node_to_history_index[node]
		if i != 0:
			node.connects_to.push_back(history_index_to_node[i-1])
		# remember history_index_to_node has an extra node (the current level)
		if i < state_data.exit_levels.size():
			node.connects_to.push_back(history_index_to_node[i+1])

func update_history_nodes() -> void:
	# I guess it could do something more optimized, but, meh for now
	regen_history_nodes()

var level_to_node := {}
var node_to_level := {}

func regen_level_nodes() -> void:
	if not gameplay_manager: return
	
	for child in levels_screen.get_children():
		child.free()
		level_to_node.clear()
		node_to_level.clear()
	
	for level_id in pack_data.levels:
		var level: LevelData = pack_data.levels[level_id]
		var warp_title := level.name if level.name else level.title if level.title else "Untitled"
		var pos := Vector2.ZERO
		pos.x = floorf(randf() * pack_data.levels.size() * 40)
		pos.y = floorf(randf() * pack_data.levels.size() * 40)
		var node := WARP_ROD_NODE.instantiate()
		level_to_node[level] = node
		node_to_level[node] = level
		node.text = warp_title
		levels_screen.add_child(node)
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

func update_level_nodes() -> void:
	for level_id in pack_data.levels:
		var node: WarpRodNode = level_to_node[pack_data.levels[level_id]]
		node.state = node.State.Available
		if state_data.current_level == level_id:
			node.state = node.State.Current
