@tool
extends Resource
class_name CounterData

## Contains a door's logical data

static var level_element_type := Enums.LevelElementTypes.KeyCounter

@export var length := 200

@export var colors: Array[CounterPartData] = []

@export var position := Vector2i(0, 0)

var glitch_color := Enums.Colors.Glitch

func add_counter(lock: CounterPartData) -> void:
	colors.push_back(lock)
	changed.emit()

func remove_lock_at(pos: int) -> void:
	colors.remove_at(pos)
	changed.emit()

func set_star(val: bool, color: Enums.Colors) -> void:
	var change := []
	for counter in colors:
		if counter.color == color:
			change.push_front(counter.position)
			break
	if change.is_empty(): return
	for counter in change: counter.is_starred = val
	changed.emit()

func duplicated() -> CounterData:
	var dupe := CounterData.new()
	dupe.length = length
	dupe.position = position
	
	for l in colors:
		dupe.colors.push_back(l.duplicated())
	return dupe

func has_point(point: Vector2i) -> bool:
	return get_rect().has_point(point)

func get_rect() -> Rect2i:
	return Rect2i(position, Vector2i(length, 17 + colors.size() * 49))

## Returns true if the door has a given color (taking glitch and curses into account)
func has_color(color: Enums.Colors) -> bool:
	for lock in colors:
		if lock.color == color:
			return true
	return false

func check_valid(level_data: LevelData, should_correct: bool) -> bool:
	var is_valid := true
	if colors.is_empty():
		level_data.add_invalid_reason("Key Counter has no Counters", true)
		is_valid = is_valid and should_correct
		if should_correct:
			var stone := CounterPartData.new()
			stone.color = Enums.Colors.Stone
			add_counter(stone)
	return is_valid
