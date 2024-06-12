@tool
extends Control
class_name Entry

static var level_element_type := Enums.level_element_types.entry

@export var entry_data: EntryData:
	set(val):
		if entry_data == val: return
		_disconnect_entry_data()
		entry_data = val
		_connect_entry_data()
var level: Level:
	set(val):
		level = val
		if not is_instance_valid(val): return
		pack_data = val.gameplay_manager.pack_data
var pack_data: LevelPackData

@export var ignore_position := false

@onready var sprite: Sprite2D = %Sprite
@onready var completion_overlay: Sprite2D = %CompletionOverlay
@onready var arrow: AnimatedSprite2D = %Arrow
@onready var level_name: Node2D = %Name

const ENTRY_CLOSED = preload("res://level_elements/entries/textures/simple/entry_closed.png")
const ENTRY_COMPLETED = preload("res://level_elements/entries/textures/simple/entry_completed.png")
const ENTRY_ERR = preload("res://level_elements/entries/textures/simple/entry_err.png")
const ENTRY_OPEN = preload("res://level_elements/entries/textures/simple/entry_open.png")
const ENTRY_STAR_2 = preload("res://level_elements/entries/textures/simple/entry_star2.png")
const ENTRY_STAR = preload("res://level_elements/entries/textures/simple/entry_star.png")

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
	if entry_data.leads_to >= 0 and entry_data.leads_to < pack_data.levels.size():
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

# called by kid.gd
func enter() -> void:
	if not is_instance_valid(level): return
	if entry_data.leads_to == -1: return
	level.gameplay_manager.enter_level(entry_data.leads_to)

func update_position() -> void:
	if not ignore_position:
		position = entry_data.position

func update_name() -> void:
	if not is_instance_valid(pack_data): return
	if not is_node_ready(): return
	level_name.text = "\n[Invalid entry]"
	if entry_data.leads_to >= 0 and entry_data.leads_to < pack_data.levels.size():
		var level_data := pack_data.levels[entry_data.leads_to]
		level_name.text = level_data.title + "\n" + level_data.name

func update_status() -> void:
	if not is_instance_valid(pack_data): return
	if not is_node_ready(): return
	if entry_data.leads_to < 0 or entry_data.leads_to >= pack_data.levels.size():
		sprite.texture = ENTRY_ERR
		return
	# [completed, required, total]
	var completion: Array = pack_data.get_completion_information(entry_data.leads_to)
	var completed: int = completion[0]
	var required: int = completion[1]
	var total: int = completion[2]
	if total == -1: # normal level
		sprite.texture = ENTRY_OPEN
		sprite.position.y = -4
	else: # world
		sprite.texture = ENTRY_WORLD
		sprite.position.y = -36
	if completed == 0 or required == 0 or completed < required:
		completion_overlay.hide()
	elif completed == total:
		completion_overlay.texture = STAR
		completion_overlay.show()
	else:
		completion_overlay.texture = COMPLETED
		completion_overlay.show()

func _disconnect_entry_data() -> void:
	if not is_instance_valid(entry_data): return
	entry_data.changed.disconnect(update_position)

func _connect_entry_data() -> void:
	if not is_instance_valid(entry_data): return
	entry_data.changed.connect(update_position)
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
	s += "Leads to:\n" + level_name.text
	return s
