@tool
extends Resource
class_name EntryData

@export var position: Vector2i:
	set(val):
		if position == val: return
		position = val
		changed.emit()
# The actual saved data of where it leads to is stored in the LevelPackData resource. This is so that design-wise, levels are mostly "independent" by themselves, and the connections are handled by the pack
# This variable is assigned when the level loads
var leads_to: int

func get_rect() -> Rect2i:
	return Rect2i(position, Vector2i(32, 32))

# TODO: Optimize if needed
func duplicated() -> EntryData:
	return duplicate(true)
