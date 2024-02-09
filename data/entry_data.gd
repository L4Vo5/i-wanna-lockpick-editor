@tool
extends Resource
class_name EntryData

@export var position: Vector2i:
	set(val):
		if position == val: return
		position = val
		changed.emit()
# A bit of tight coupling with the specific order the levels are in in the level pack, but it makes saving and loading these much easier
## What level it leads to. -1 means it doesn't lead anywhere
@export var leads_to: int = -1
# Will likely use this later so I'm adding it so I don't have to change the entry save load code just for this
@export var skin: int

func get_rect() -> Rect2i:
	return Rect2i(position, Vector2i(32, 32))

# TODO: Optimize if needed
func duplicated() -> EntryData:
	return duplicate(true)
