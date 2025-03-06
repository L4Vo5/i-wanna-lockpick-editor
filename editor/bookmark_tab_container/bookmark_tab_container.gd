@tool
extends Container
class_name BookmarkTabContainer

signal tab_changed

var flaps: Array[Node]:
	get:
		return flaps_parent.get_children()
@onready var flaps_parent: VBoxContainer = $flaps
var tab_to_flap := {}
var flap_to_tab := {}

const name_to_icon := {
	Doors = preload("res://editor/bookmark_tab_container/icons/door.png"),
	Keys = preload("res://editor/bookmark_tab_container/icons/key.png"),
	Tiles = preload("res://editor/bookmark_tab_container/icons/tile.png"),
	SalvagePoints = preload("res://editor/bookmark_tab_container/icons/salvage_point.png"),
	Entries = preload("res://editor/bookmark_tab_container/icons/entry.png"),
	LevelPack = preload("res://editor/bookmark_tab_container/icons/level_pack.png"),
	Settings = preload("res://editor/bookmark_tab_container/icons/settings.svg"),
	KeyCounters = preload("res://editor/bookmark_tab_container/icons/wood.png"),
}

const BOOKMARK_FLAP = preload("res://editor/bookmark_tab_container/bookmark_flap.tscn")

var current_tab: Control = null

func set_current_tab_control(tab: Control):
	if current_tab == tab: return
	_on_flap_toggled(true, tab_to_flap[tab])

func _ready() -> void:
	regen_flaps()
	resized.connect(_on_resize)
	_on_resize()
	flaps_parent.gui_input.connect(_on_flap_parent_input)

func _on_resize() -> void:
	var r := get_rect()
	r.position = Vector2.ZERO
	r.position.x += flaps_size
	r.size.x -= flaps_size
	for child in get_children():
		if child == flaps_parent: continue
		fit_child_in_rect(child, r)
	flaps_parent.size.y = size.y

var flaps_size := 0

func regen_flaps() -> void:
	current_tab = null
	flaps_size = 0
	for flap in flaps:
		flap.queue_free()
	tab_to_flap.clear()
	flap_to_tab.clear()
	var i := 0
	for child in get_children():
		if child == flaps_parent: continue
		var new_flap: Button = BOOKMARK_FLAP.instantiate()
		new_flap.icon = name_to_icon[child.name]
		new_flap.name = child.name
		new_flap.toggled.connect(_on_flap_toggled.bind(new_flap))
		new_flap.set_meta(&"_flap_index", i)
		flaps_parent.add_child(new_flap)
		flaps_size = max(flaps_size, new_flap.size.x)
		tab_to_flap[child] = new_flap
		flap_to_tab[new_flap] = child
		i += 1
	#flaps_parent.position.x = -flaps_size
	if !flaps.is_empty():
		_on_flap_toggled(true, flaps[0])

func _on_flap_parent_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				scroll(-1)
				accept_event()
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				scroll(1)
				accept_event()

func scroll(direction: int) -> void:
	var i := flaps.find(tab_to_flap[current_tab])
	assert(i != -1)
	i += direction
	i = (i + flaps.size()) % flaps.size()
	_on_flap_toggled(true, flaps[i])

func _on_flap_toggled(toggled: bool, flap: Button) -> void:
	flap.set_pressed_no_signal(true)
	if !toggled:
		return
	else:
		current_tab = flap_to_tab[flap]
		current_tab.show()
		for other_flap in flaps:
			if other_flap == flap: continue
			other_flap.set_pressed_no_signal(false)
			flap_to_tab[other_flap].hide()
		tab_changed.emit()

func _get_minimum_size() -> Vector2:
	var s := Vector2.ZERO
	for child in get_children():
		if child == flaps_parent: continue
		s.x = max(s.x, child.get_combined_minimum_size().x)
	custom_minimum_size.x = s.x + flaps_size
	return s

func get_current_tab_control() -> Control:
	return current_tab

func get_current_tab_index() -> int:
	var current_flap: Control = tab_to_flap[current_tab]
	return current_flap.get_meta(&"_flap_index")

func set_current_tab_index(index: int) -> void:
	var flap := flaps_parent.get_child(index)
	set_current_tab_control(flap_to_tab[flap])

func _get_allowed_size_flags_horizontal() -> PackedInt32Array:
	return []

func _get_allowed_size_flags_vertical() -> PackedInt32Array:
	return []

func _draw() -> void:
	pass
