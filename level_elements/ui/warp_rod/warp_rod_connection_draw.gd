extends Control
# Necessary otherwise the screen goes out of view...........
class_name WarpRodConnectionDraw

var screen: WarpRodScreen

func _draw() -> void:
	assert(PerfManager.start("WarpRodConnectionDraw::_draw"))
	for node: WarpRodNode in screen.get_children():
		var pos1 := node.get_center() + screen.position
		for node2 in node.connects_to:
			var pos2 := node2.get_center() + screen.position
			if not test_vecs(pos1, pos2): continue
			#print("Drawing line between %s and %s" % [pos1, pos2])
			var shadow_angle := pos2.angle_to_point(pos1)
			var shadow_offset := Vector2.DOWN.rotated(shadow_angle) * 2
			if shadow_offset.y < 0:
				shadow_offset = -shadow_offset
			draw_line(pos1 + shadow_offset, pos2 + shadow_offset, Color(0, 0, 0, 0.25), 2)
			draw_line(pos1, pos2, Color.WHITE, 2)
	assert(PerfManager.end("WarpRodConnectionDraw::_draw"))

# For a pair of non-equal vecs A, B, whatever value is returned for (A, B), the opposite is always returned for (B, A)
func test_vecs(v1: Vector2, v2: Vector2) -> bool:
	return v1.x < v2.x or (v1.x == v2.x and v1.y < v2.y)
