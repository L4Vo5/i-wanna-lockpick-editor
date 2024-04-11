@tool
extends Container
class_name BookmarkTabContainer

signal tab_changed

var flaps:
	get:
		return flaps_parent.get_children()
@onready var flaps_parent: VBoxContainer = $flaps

const name_to_icon := {
	Doors = preload("res://editor/bookmark_tab_container/icons/door.png"),
	Keys = preload("res://editor/bookmark_tab_container/icons/key.png"),
	Tiles = preload("res://editor/bookmark_tab_container/icons/tile.png"),
	Level = preload("res://editor/bookmark_tab_container/icons/level.png"),
	Entries = preload("res://editor/bookmark_tab_container/icons/entry.png"),
}

const BOOKMARK_FLAP = preload("res://editor/bookmark_tab_container/bookmark_flap.tscn")

var current_tab: Control = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	regen_flaps()
	resized.connect(_on_resize)
	_on_resize()

func _on_resize() -> void:
	var r := get_rect()
	r.position = Vector2.ZERO
	r.position.x += flaps_size
	r.size.x -= flaps_size
	for child in get_children():
		if child == flaps_parent: continue
		fit_child_in_rect(child, r)

var flaps_size := 0

func regen_flaps() -> void:
	current_tab = null
	flaps_size = 0
	for flap in flaps:
		flap.queue_free()
	for child in get_children():
		if child == flaps_parent: continue
		var new_flap: Button = BOOKMARK_FLAP.instantiate()
		new_flap.icon = name_to_icon[child.name]
		new_flap.name = child.name
		#new_flap.button_group = button_group
		new_flap.toggled.connect(_on_flap_toggled.bind(new_flap))
		flaps_parent.add_child(new_flap)
		flaps_size = max(flaps_size, new_flap.size.x)
	#flaps_parent.position.x = -flaps_size
	_on_resize()
	if !flaps.is_empty():
		_on_flap_toggled(true, flaps[0])

func _on_flap_toggled(toggled: bool, flap: Button) -> void:
	flap.set_pressed_no_signal(true)
	if !toggled:
		return
	else:
		current_tab = get_node(NodePath(flap.name))
		get_node(NodePath(flap.name)).show()
		for other_flap in flaps:
			if other_flap == flap: continue
			other_flap.set_pressed_no_signal(false)
			get_node(NodePath(other_flap.name)).hide()
		tab_changed.emit()

func get_current_tab_control() -> Control:
	return current_tab

func _get_allowed_size_flags_horizontal() -> PackedInt32Array:
	return []

func _get_allowed_size_flags_vertical() -> PackedInt32Array:
	return []

func _draw() -> void:
	pass
