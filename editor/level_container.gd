extends Control
class_name LevelContainer
## Contains the level, centered, and at the correct aspect ratio

@onready var inner_container := $LevelContainerInner
@onready var level: Level = $LevelContainerInner/Level

#var level_offset :=  Vector2(0, 0)

const OBJ_SIZE := Vector2(800, 608)
func _process(delta: float) -> void:
	# center it
	inner_container.position = (size - OBJ_SIZE) / 2
	inner_container.size = OBJ_SIZE

