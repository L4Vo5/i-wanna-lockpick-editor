@tool
extends TextureRect
class_name WarpRodNode

signal hovered
signal unhovered

const NODE_UNAVAILABLE = preload("res://level_elements/ui/warp_rod/node_unavailable.png")
const NODE_AVAILABLE = preload("res://level_elements/ui/warp_rod/node_available.png")
const NODE_CURRENT = preload("res://level_elements/ui/warp_rod/node_current.png")
@onready var outline: TextureRect = %Outline

static var connects_to: Array[WarpRodNode] = []

@export var state := State.Unavailable: set = set_state
enum State {
	Unavailable,
	Available,
	Current
}

func _init() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	connects_to.push_back(self)

func _on_mouse_entered() -> void:
	if state != State.Unavailable:
		outline.show()
	hovered.emit()

func _on_mouse_exited() -> void:
	outline.hide()
	unhovered.emit()

func set_state(val: State) -> void:
	state = val
	match state:
		State.Unavailable:
			texture = NODE_UNAVAILABLE
			outline.hide()
		State.Available:
			texture = NODE_AVAILABLE
		State.Current:
			texture = NODE_CURRENT

func get_center() -> Vector2:
	return position + size / 2
