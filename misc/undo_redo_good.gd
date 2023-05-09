extends RefCounted
class_name GoodUndoRedo
## UndoRedo but good
var _actions: Array[GURAction]
var _built_action: GURAction
var _last_action := -1
var _max_action := -1

func _init() -> void:
	_actions = []

func start_action() -> void:
	assert(not is_instance_valid(_built_action))
	_built_action = GURAction.new()

# Starts merging extra data into the last action
func start_merge_last() -> void:
	assert(not is_instance_valid(_built_action))
	_built_action = _actions[_last_action]
	_last_action -= 1

func commit_action(also_execute := true) -> void:
	assert(is_instance_valid(_built_action))
	_last_action += 1
	_max_action = _last_action
	if _actions.size() <= _last_action:
		_actions.resize(_actions.size() * 2 + 1)
	_actions[_last_action] = _built_action
	_built_action = null
	if also_execute:
		_actions[_last_action].do()

func add_do_method(method: Callable) -> void:
	assert(is_instance_valid(_built_action))
	_built_action.do_steps.push_back(method)

func add_undo_method(method: Callable) -> void:
	assert(is_instance_valid(_built_action))
	_built_action.undo_steps.push_back(method)

func add_do_property(object: Object, property: StringName, value: Variant) -> void:
	add_do_method(object.set.bind(property, value))

func add_undo_property(object: Object, property: StringName, value: Variant) -> void:
	add_undo_method(object.set.bind(property, value))

func is_building_action() -> bool:
	return is_instance_valid(_built_action)

func get_last_action() -> int:
	return _last_action

func get_action_count() -> int:
	return _max_action + 1

func clear_history() -> void:
	_built_action = null
	_last_action = -1
	_max_action = -1

func undo() -> void:
	assert(!is_building_action())
	assert(_last_action >= 0)
	if _last_action >= 0: 
		_actions[_last_action].undo()
		_last_action -= 1

func redo() -> void:
	if _last_action <= _max_action:
		_actions[_last_action].do()
		_last_action += 1

class GURAction:
	extends RefCounted
	var do_steps: Array[Callable] = []
	var undo_steps: Array[Callable] = []
	func do() -> void:
		for step in do_steps:
			step.call()
	func undo() -> void:
		var i := undo_steps.size()
		while i > 0:
			i -= 1
			undo_steps[i].call()
