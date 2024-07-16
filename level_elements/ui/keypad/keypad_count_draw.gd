@tool
extends Control

const FONT := preload("res://fonts/spr_pda_count.png")
const CHAR_SET := "x0123456789+-i"
const OFFSETS := [1,2,2,2,2,2,2,2,2,2,2,2,2,-5]
const CHAR_SIZE := Vector2i(10, 14)

@export var strings: Array[String] = [
	"x0", "x0",
	"x0", "x0",
	"x0", "x0",
	"x0", "x0",
	"x0", "x0",
	"x0", "x0",
	"x0", "x0",
]

var level: Level:
	get:
		return owner.level

# PERF: simply do not do this every frame :)
func _process(_delta: float) -> void:
	queue_redraw()

func _ready() -> void:
	modulate = Color("00FF00")

func _draw() -> void:
	for y in 7:
		for x in 2:
			var str := strings[y * 2 + x]
			var color: Enums.colors = KeyPad.KEY_COLORS[y * 2 + x]
			var key_count := ComplexNumber.new()
			if is_instance_valid(level):
				key_count = level.logic.key_counts[color]
			str = "x" + str(key_count)
			
			draw_str(KeyPad.KEY_START + KeyPad.KEY_DIFF * Vector2i(x, y) + Vector2i(36, 13), str)

func draw_str(pos: Vector2i, string: String) -> void:
	var x := 0
	var xoff := 0
	for c in string:
		draw_character(pos + Vector2i(x * CHAR_SIZE.x + xoff, 0), c)
		xoff += OFFSETS[CHAR_SET.find(c)]
		x += 1

func draw_character(pos: Vector2i, character: String) -> void:
	var i := CHAR_SET.find(character)
	draw_texture_rect_region(FONT, Rect2(pos, CHAR_SIZE), Rect2(CHAR_SIZE * Vector2i(i, 0), CHAR_SIZE))
