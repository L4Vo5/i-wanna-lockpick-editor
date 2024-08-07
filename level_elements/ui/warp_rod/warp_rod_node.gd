@tool
extends NinePatchRect
class_name WarpRodNode

signal hovered
signal unhovered

@export var state := State.Unavailable: set = set_state
enum State {
	Unavailable,
	Available,
	Current
}
@export var text := "":
	set(val):
		text = val
		custom_minimum_size = FONT.get_string_size(text) + Vector2(16, 16)
		queue_redraw()
@export var can_be_dragged := true:
	set(val):
		can_be_dragged = val
		if node_dragger:
			node_dragger.visible = can_be_dragged

const NODE_UNAVAILABLE = preload("res://level_elements/ui/warp_rod/node_unavailable.png")
const NODE_AVAILABLE = preload("res://level_elements/ui/warp_rod/node_available.png")
const NODE_CURRENT = preload("res://level_elements/ui/warp_rod/node_current.png")
const FONT = preload("res://fonts/ms_ui_gothic.fnt")

@onready var outline: NinePatchRect = %Outline
@onready var node_dragger: NodeDragger = %NodeDragger

# tip: can make it @export when testing
var connects_to: Array[WarpRodNode] = []

func _init() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _ready() -> void:
	# trigger setter
	can_be_dragged = can_be_dragged

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

func _draw() -> void:
	var pos := Vector2(8, 8)
	pos.y += FONT.get_string_size(text).y
	draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
