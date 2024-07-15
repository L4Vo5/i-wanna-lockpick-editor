@tool
extends Node2D

const STAR := preload("res://level_elements/ui/keypad/spr_star.png")

# PERF: simply do not do this every frame :)
func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_stars()

func draw_stars() -> void:
	if not is_instance_valid(Global.current_level): return
	for y in 7:
		for x in 2:
			var color : Enums.colors = KeyPad.KEY_COLORS[y * 2 + x]
			if Global.current_level.logic.star_keys[color]:
				var pos := KeyPad.KEY_START + KeyPad.KEY_DIFF * Vector2i(x, y)
				draw_texture(STAR, pos + Vector2i(6, 22))
