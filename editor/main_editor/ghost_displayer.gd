extends CanvasGroup
class_name GhostDisplayer

var info: NewLevelElementInfo:
	set(val):
		_disconnect_info()
		info = val
		_connect_info()

@onready var ghost_door: Door = %GhostDoor
@onready var ghost_key: KeyElement = %GhostKey
@onready var ghost_entry: Entry = %GhostEntry
@onready var ghost_salvage_point: SalvagePoint = %GhostSalvagePoint

@onready var ghosts: Dictionary = {
	Enums.LevelElementTypes.Door: ghost_door,
	Enums.LevelElementTypes.Key: ghost_key,
	Enums.LevelElementTypes.Entry: ghost_entry,
	Enums.LevelElementTypes.SalvagePoint: ghost_salvage_point,
}

func update_type() -> void:
	for thing in ghosts.values():
		thing.hide()
	if not ghosts.has(info.type):
		return
	var ghost: CanvasItem = ghosts[info.type]
	ghost.show()
	if info.type in Enums.NODE_LEVEL_ELEMENTS:
		ghost.data = info.data

func _connect_info() -> void:
	if not info: return
	info.changed_position.connect(_on_update_position)
	_on_update_position()
	update_type()

func _disconnect_info() -> void:
	if not info: return
	info.changed_position.disconnect(_on_update_position)

func _on_update_position() -> void:
	position = info.position
