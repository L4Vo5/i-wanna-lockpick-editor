class_name SaveLoadVersion
## System for handling sequential version of encoding/decoding functions that work with a binary format.
## (Doesn't handle any files, only the binary data I/O)

const MAX_ARRAY_SIZE := 50_000_000

## Returns null on error. [br]
## Non-current, incompatible version should produce a dict
## and return [next version].load_from_dict([next version].convert_dict([dict])).
# Yeah, it's annoying to have to call it like that, but inheriting methods on static functions doesn't work properly. And there's annoying consequences to making this non-static.
@warning_ignore("unused_parameter")
static func load_from_bytes(bytes: PackedByteArray, offset: int):
	assert(false, "Unimplemented!")

## Loads from the dict produced by this version.
## Non-current, incompatible versions should instead call [next version].load_from_dict([next version].convert_dict([dict])), making this a one-line function.
@warning_ignore("unused_parameter")
static func load_from_dict(dict: Dictionary):
	assert(false, "Unimplemented!")

## Converts the dict produced by the previous version into one that this version would produce (that it can load in load_from_dict).
@warning_ignore("unused_parameter")
static func convert_dict(dict: Dictionary) -> Dictionary:
	assert(false, "Unimplemented!")
	return {}

# (Works in-place on the data as an optimization).
@warning_ignore("unused_parameter")
static func save(thing_being_saved, data: PackedByteArray, offset: int) -> void:
	assert(false, "Unimplemented!")

func _init() -> void:
	assert(false, "Don't instantiate this!")


# Helper functions for load_from_dict

## Naively tries to shove all dict keys into an object
static func dict_keys_to_object(dict: Dictionary, object: Object) -> void:
	for key in dict:
		object.set(key, dict[key])

## Takes a dict and instantiates it as an object, as long as it has a "_type" key, otherwise returns the dict. _type should ideally be a StringName
## If there's a "_type" key, an optional "_inspect" key (could be an array or dict, as "in" will be what's used on it) dictates inner Array or Dictionary variables that should be inspected, and if their elements/keys/values contain dictionaries, they'll be fed into this fuction and replaced with the result.
## All other keys are fed into the object, except Dictionaries that aren't in _inspect: those are passed into this function first.
## (To be clear, inspecting a dictionary is meant for when it's actually a dictionary, and its keys and/or values can be objects. a dictionary with _type will always be an object)
static var is_in := false
static var indent_level := ""
static func increase_indent():
	if is_in:
		indent_level = "--" + indent_level
	else:
		indent_level = ">"
		is_in = true
static func decrease_indent():
	if indent_level == ">":
		is_in = false
	else:
		indent_level = indent_level.right(-2)
static func dict_into_variable(dict: Dictionary):
	increase_indent()
	print(indent_level + "dict_into_variable")
	var type: StringName = dict.get(&"_type", &"")
	print(indent_level, "type is " , type)
	if type == &"":
		decrease_indent()
		return dict
	else:
		var inspect = dict.get(&"_inspect", [])
		var obj
		if type in Global.classes:
			obj = Global.classes[type].new()
		elif ClassDB.class_exists(type):
			obj = ClassDB.instantiate(type)
		assert(obj)
		for key in dict:
			if key == &"_type" or key == &"_inspect": continue
			var value = dict[key]
			print(indent_level, "moving on to ", key)
			if key in inspect:
				value = _inspect(value)
			elif value is Dictionary:
				value = dict_into_variable(value)
			if value is Array:
				# deal with typed array nonsense...
				obj.set(key, [])
				obj.get(key).append_array(value)
			else:
				obj.set(key, value)
			print(indent_level,"set ", key, " to ", value)
			print(indent_level,"just to make sure... ", obj.get(key))
		print(indent_level, " obj is ", obj)
		decrease_indent()
		return obj

static func _inspect(thing):
	increase_indent()
	print(indent_level, "inspecting thing")
	if thing is Array:
		print(indent_level, "thing is array")
		for i in thing.size():
			if thing[i] is Dictionary:
				thing[i] = dict_into_variable(thing[i])
		print(indent_level, "array thing is now ", thing)
		decrease_indent()
		return thing
	elif thing is Dictionary:
		print(indent_level, "thing is dictionary")
		var new_dict := {}
		for key in thing:
			var value = thing[key]
			if value is Dictionary:
				value = dict_into_variable(value)
			if key is Dictionary:
				key = dict_into_variable(key)
			new_dict[key] = value
		print(indent_level, "dictionary thing is now ", thing)
		decrease_indent()
		return new_dict
	else:
		assert(false, "I can't inspect this!")
