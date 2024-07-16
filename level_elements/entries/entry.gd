@tool
extends Control
class_name Entry

static var level_element_type := Enums.level_element_types.entry

@export var data: EntryData:
	set(val):
		if data == val: return
		_disconnect_data()
		data = val
		_connect_data()
var level: Level:
	set(val):
		level = val
		if not is_instance_valid(val): return
		pack_data = val.gameplay_manager.pack_data
var pack_data: LevelPackData

@export var ignore_position := false

@onready var sprite: Sprite2D = %Sprite
@onready var completion: Sprite2D = %Completion
@onready var arrow: AnimatedSprite2D = %Arrow
@onready var level_name: Node2D = %Name

const ENTRY_CLOSED = preload("res://level_elements/entries/textures/simple/entry_closed.png")
const ENTRY_ERR = preload("res://level_elements/entries/textures/simple/entry_err.png")
const ENTRY_OPEN = preload("res://level_elements/entries/textures/simple/entry_open.png")
const ENTRY_WORLD = preload("res://level_elements/entries/textures/world/entry_world.png")
const COMPLETED = preload("res://level_elements/entries/textures/completion/completed.png")
const STAR = preload("res://level_elements/entries/textures/completion/star.png")

var name_tween: Tween
@onready var name_start_y := level_name.position.y
var tween_progress := 0.0
const tween_time := 0.3
const tween_y_offset := 20

func _ready() -> void:
	if Global.in_editor: return
	if not is_instance_valid(level): return
	level_name.position.y += tween_y_offset
	level_name.modulate.a = 0
	update_name()
	update_status()

# called by kid.gd
func player_touching() -> void:
	if not is_instance_valid(level): return
	if data.leads_to >= 0 and data.leads_to < pack_data.levels.size():
		arrow.show()
	level_name.show()
	if name_tween: name_tween.kill()
	name_tween = create_tween().set_parallel(true)
	var t = tween_time * (1.0 - tween_progress)
	name_tween.tween_property(level_name, "modulate:a", 1, t).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	name_tween.tween_property(level_name, "position:y", name_start_y, t).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	name_tween.tween_property(self, "tween_progress", 1, t)

# called by kid.gd
func player_stopped_touching() -> void:
	if not is_instance_valid(level): return
	arrow.hide()
	#level_name.hide()
	if name_tween: name_tween.kill()
	name_tween = create_tween().set_parallel(true)
	var t = tween_time * (tween_progress)
	name_tween.tween_property(level_name, "modulate:a", 0, t).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	name_tween.tween_property(level_name, "position:y", name_start_y + tween_y_offset, t).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	name_tween.tween_property(self, "tween_progress", 0, t)

func end_animation() -> void:
	if not is_node_ready(): return
	# to make resets properly reset the entry
	arrow.hide()
	if name_tween: name_tween.kill()
	level_name.modulate.a = 0
	level_name.position.y = name_start_y + tween_y_offset
	tween_progress = 0

# called by kid.gd
func enter() -> void:
	if not is_instance_valid(level): return
	if data.leads_to == -1: return
	level.gameplay_manager.enter_level(data.leads_to, data.position + Vector2i(14, 32))

func update_position() -> void:
	if not ignore_position:
		position = data.position

func update_name() -> void:
	if not is_instance_valid(level): return
	if not is_node_ready(): return
	level_name.text = "\n[Invalid entry]"
	if data.leads_to >= 0 and data.leads_to < pack_data.levels.size():
		var level_data := level.gameplay_manager.pack_data.levels[data.leads_to]
		level_name.text = level_data.title + "\n" + level_data.name
		if not level_data.name and not level_data.title:
			level_name.text = "\nUntitled"

func update_status() -> void:
	if not is_instance_valid(level): return
	if not is_node_ready(): return
	if data.leads_to < 0 or data.leads_to >= pack_data.levels.size():
		sprite.texture = ENTRY_ERR
		return
	if pack_data.levels[data.leads_to].exitable:
		sprite.texture = ENTRY_OPEN
		sprite.position.y = -4
	else:
		sprite.texture = ENTRY_WORLD
		sprite.position.y = -36
	if level.gameplay_manager.active_state.completed_levels.has(pack_data.levels[data.leads_to].unique_id):
		completion.texture = COMPLETED
		completion.visible = true
	else:
		completion.visible = false

func _disconnect_data() -> void:
	if not is_instance_valid(data): return
	data.changed.disconnect(update_position)

func _connect_data() -> void:
	if not is_instance_valid(data): return
	data.changed.connect(update_position)
	end_animation()
	update_name()
	update_position()
	update_status()

func get_mouseover_text() -> String:
	update_name()
	var s := ""
	if sprite.texture == ENTRY_ERR:
		s += "Invalid Entry"
		return s
	if sprite.texture == ENTRY_OPEN:
		s += "Open "
	s += "Entry\n"
	s += "Leads to:\n"
	s += level_name.text.trim_prefix("\n")
	return s
