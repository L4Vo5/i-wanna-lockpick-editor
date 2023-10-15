@tool
extends Resource
class_name EntryData

@export var position: Vector2i
# The actual saved data of where it leads to is stored in the LevelPackData resource. This is so that design-wise, levels are mostly "independent" by themselves, and the connections are handled by the pack
# This variable is assigned when the level loads
var leads_to: LevelData
