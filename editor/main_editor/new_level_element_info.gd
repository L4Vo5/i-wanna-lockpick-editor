class_name NewLevelElementInfo
## basically a "struct" used only to pass around the data required to add a new element to a level

signal changed_position

var type: Enums.LevelElementTypes = Enums.LevelElementTypes.None
# will be preferred over the data's position
var position: Vector2i:
	set(val):
		position = val
		changed_position.emit()
# data, if any (one of the Data classes)
var data

static func new_from_data(_data) -> NewLevelElementInfo:
	var e = NewLevelElementInfo.new()
	e.type = _data.level_element_type
	e.data = _data
	e.position = _data.position
	return e

func get_rect() -> Rect2i:
	match type:
		Enums.LevelElementTypes.Tile, Enums.LevelElementTypes.Goal, Enums.LevelElementTypes.PlayerSpawn:
			return Rect2i(position, Vector2i(32, 32))
		_:
			data.position = position
			return data.get_rect()
