extends SaveLoadVersionLVL

# Differences from V4:
# Level title and name are stored separately
# Level author, description, and label are stored
# Level pack description is stored

static func convert_dict(dict: Dictionary) -> Dictionary:
	# Nothing to do yet!
	return dict

static func load_from_dict(dict: Dictionary):
	var data: LevelPackData = dict_into_variable(dict)
	assert(data)
	return data

static func load_from_bytes(raw_data: PackedByteArray, offset: int):
	return load_level_pack(raw_data, offset)

static func save(level_pack: LevelPackData, raw_data: PackedByteArray, offset: int) -> void:
	var data := ByteAccess.new(raw_data, offset)
	data.store_string(level_pack.name)
	data.store_string(level_pack.author)
	data.store_string(level_pack.description)
	data.store_s64(level_pack.pack_id)
	
	data.store_u32(level_pack.levels.size())
	
	# Save all levels
	for level_id in level_pack.level_order:
		var level: LevelData = level_pack.levels[level_id]
		data.store_u16(level_id)
		save_level(level, data)
	
	data.compress()

static func save_level(level: LevelData, data: ByteAccess) -> void:
	data.store_string(level.name)
	data.store_string(level.title)
	data.store_string(level.label)
	data.store_string(level.author)
	data.store_string(level.description)
	data.store_u32(level.size.x)
	data.store_u32(level.size.y)
	
	var flags := 0
	flags |= level.has_goal as int
	flags |= (level.exitable as int) << 1
	data.store_u8(flags)
	if level.has_goal:
		data.store_u32(level.goal_position.x)
		data.store_u32(level.goal_position.y)
	data.store_u32(level.player_spawn_position.x)
	data.store_u32(level.player_spawn_position.y)
	# Tiles
	# Make sure there aren't *checks notes* 2^32 - 1, or, 4294967295 tiles. Meaning the level size is constrained to about, uh, 2097120x2097120
	data.store_u32(level.tiles.size())
	for key in level.tiles:
		data.store_u32(key.x)
		data.store_u32(key.y)
	# Keys
	data.store_u32(level.keys.size())
	for key in level.keys:
		save_key(data, key)
	# Doors
	data.store_u32(level.doors.size())
	for door in level.doors:
		save_door(data, door)
	# Entries
	data.store_u32(level.entries.size())
	for entry in level.entries:
		save_entry(data, entry)
	# Salvage Points
	data.store_u32(level.salvage_points.size())
	for salvage_point in level.salvage_points:
		save_salvage_point(data, salvage_point)

static func save_key(data: ByteAccess, key: KeyData) -> void:
	save_complex(data, key.amount)
	data.store_u32(key.position.x)
	data.store_u32(key.position.y)
	# color is 4 bytes, type is 3. is_infinite is 1. 8 bytes total
	# bits are: 01112222, 0 = is_infinite, 1 = type, 2 = color
	data.store_u8(((key.is_infinite as int) << 7) + (key.type << 4) + key.color)

static func save_door(data: ByteAccess, door: DoorData) -> void:
	# In the current version:
	# Glitch color should always start as glitch
	# Doors can never start browned
	save_complex(data, door.amount)
	data.store_u32(door.position.x)
	data.store_u32(door.position.y)
	data.store_u32(door.size.x)
	data.store_u32(door.size.y)
	# Curses take 3 bits. color takes 4 bits. 7 bits total
	# bits are, x1234444, 1 = ice, 2 = erosion, 3 = paint, 4 = color
	var curses := 0
	curses += 4 if door.get_curse(Enums.Curse.Ice) else 0
	curses += 2 if door.get_curse(Enums.Curse.Erosion) else 0
	curses += 1 if door.get_curse(Enums.Curse.Paint) else 0
	data.store_u8((curses << 4) + door.outer_color)
	data.store_u16(door.locks.size())
	for lock in door.locks:
		save_lock(data, lock)

static func save_lock(data: ByteAccess, lock: LockData) -> void:
	data.store_u32(lock.position.x)
	data.store_u32(lock.position.y)
	data.store_u32(lock.size.x)
	data.store_u32(lock.size.y)
	data.store_u16(lock.lock_arrangement)
	data.store_s64(lock.magnitude)
	# Sign takes 1 bit, value type takes 1, dont_show_lock takes 1. color takes 4. lock type is 2. 9 bits total :(
	# bits are, 0000000112222345, 1 = lock type, 2 = color, 3 = dont show lock, 4 = value type, 5 = sign
	var bit_data := 0
	bit_data += lock.sign << 0
	bit_data += lock.value_type << 1
	bit_data += lock.dont_show_lock as int << 2
	bit_data += lock.color << 3
	bit_data += lock.lock_type << 7
	data.store_u16(bit_data)

static func save_entry(data: ByteAccess, entry: EntryData) -> void:
	data.store_u32(entry.position.x)
	data.store_u32(entry.position.y)
	data.store_u8(entry.skin)
	data.store_u16(entry.leads_to)

static func save_salvage_point(data: ByteAccess, salvage_point: SalvagePointData) -> void:
	data.store_u32(salvage_point.position.x)
	data.store_u32(salvage_point.position.y)
	data.store_u8(1 if salvage_point.is_output else 0)
	data.store_s32(salvage_point.sid)

static func save_complex(data: ByteAccess, n: ComplexNumber) -> void:
	data.store_s64(n.real_part)
	data.store_s64(n.imaginary_part)

static func load_level_pack(raw_data: PackedByteArray, offset: int) -> LevelPackData:
	var data := ByteAccess.new(raw_data, offset)
	var level_pack := LevelPackData.new()
	level_pack.name = data.get_string()
	level_pack.author = data.get_string()
	level_pack.description = data.get_string()
	level_pack.pack_id = data.get_s64()
	if SaveLoad.PRINT_LOAD: print("Loading level pack %s by %s" % [level_pack.name, level_pack.author])
	
	var level_count := data.get_u32()
	
	# Load all levels
	if SaveLoad.PRINT_LOAD: print("It has %d levels" % level_count)
	if level_count > MAX_ARRAY_SIZE: return
	level_pack.level_order.resize(level_count)
	for i in level_count:
		if data.reached_eof(): return
		var id := data.get_u16()
		level_pack.level_order[i] = id
		level_pack.levels[id] = load_level(data)
	return level_pack

static func load_level(data: ByteAccess) -> LevelData:
	var level := LevelData.new()
	level.title = data.get_string()
	level.name = data.get_string()
	level.label = data.get_string()
	level.author = data.get_string()
	if SaveLoad.PRINT_LOAD: print("Loading level %s" % level.name)
	level.size = Vector2i(data.get_u32(), data.get_u32())
	var flags := data.get_u8()
	if flags & 1:
		level.goal_position = Vector2i(data.get_u32(), data.get_u32())
	else:
		level.has_goal = false
	level.exitable = (flags & 2) as bool
	level.player_spawn_position = Vector2i(data.get_u32(), data.get_u32())
	if SaveLoad.PRINT_LOAD: print("loaded player pos: %s" % str(level.player_spawn_position))
	
	var tile_amount := data.get_u32()
	if SaveLoad.PRINT_LOAD: print("tile count is %d" % tile_amount)
	for _i in tile_amount:
		if data.reached_eof(): return
		level.tiles[Vector2i(data.get_u32(), data.get_u32())] = true
	
	var key_amount := data.get_u32()
	if SaveLoad.PRINT_LOAD: print("key count is %d" % key_amount)
	if key_amount > MAX_ARRAY_SIZE: return
	level.keys.resize(key_amount)
	for i in key_amount:
		if data.reached_eof(): return
		level.keys[i] = load_key(data)
	
	var door_amount := data.get_u32()
	if SaveLoad.PRINT_LOAD: print("door count is %d" % door_amount)
	if door_amount > MAX_ARRAY_SIZE: return
	level.doors.resize(door_amount)
	for i in door_amount:
		if data.reached_eof(): return
		level.doors[i] = load_door(data)
	
	var entry_amount := data.get_u32()
	if SaveLoad.PRINT_LOAD: print("entry count is %d" % entry_amount)
	if entry_amount > MAX_ARRAY_SIZE: return
	level.entries.resize(entry_amount)
	for i in entry_amount:
		if data.reached_eof(): return
		level.entries[i] = load_entry(data)
	
	var salvage_point_amount := data.get_u32()
	if SaveLoad.PRINT_LOAD: print("salvage point count is %d" % salvage_point_amount)
	if salvage_point_amount > MAX_ARRAY_SIZE: return
	level.salvage_points.resize(salvage_point_amount)
	for i in salvage_point_amount:
		if data.reached_eof(): return
		level.salvage_points[i] = load_salvage_point(data)

	return level

static func load_key(data: ByteAccess) -> KeyData:
	var key := KeyData.new()
	key.amount = load_complex(data)
	key.position = Vector2i(data.get_u32(), data.get_u32())
	var inf_type_color := data.get_u8()
	key.color = inf_type_color & 0b1111
	key.type = inf_type_color >> 4 & 0b111
	key.is_infinite = (inf_type_color >> 7) == 1
	
	return key

static func load_door(data: ByteAccess) -> DoorData:
	var door := DoorData.new()
	
	door.amount = load_complex(data)
	door.position = Vector2i(data.get_u32(), data.get_u32())
	door.size = Vector2i(data.get_u32(), data.get_u32())
	
	var curses_color := data.get_u8()
	# bits are, x1234444, 1 = ice, 2 = erosion, 3 = paint, 4 = color
	door.set_curse(Enums.Curse.Ice, curses_color & (1<<6) != 0)
	door.set_curse(Enums.Curse.Erosion, curses_color & (1<<5) != 0)
	door.set_curse(Enums.Curse.Paint, curses_color & (1<<4) != 0)
	door.outer_color = curses_color & 0b1111
	
	var lock_amount := data.get_u16()
	if lock_amount > MAX_ARRAY_SIZE: return
	door.locks.resize(lock_amount)
	for i in lock_amount:
		if data.reached_eof(): return
		door.locks[i] = load_lock(data)
	return door

static func load_lock(data: ByteAccess) -> LockData:
	var lock := LockData.new()
	lock.position = Vector2i(data.get_u32(), data.get_u32())
	lock.size = Vector2i(data.get_u32(), data.get_u32())
	lock.lock_arrangement = data.get_u16()
	lock.magnitude = data.get_s64()
	var bit_data := data.get_u16()
	lock.sign = bit_data & 0b1
	bit_data >>= 1
	lock.value_type = bit_data & 0b1
	bit_data >>= 1
	lock.dont_show_lock = bit_data & 0b1 as bool
	bit_data >>= 1
	lock.color = bit_data & 0b1111
	bit_data >>= 4
	lock.lock_type = bit_data
	
	return lock

static func load_entry(data: ByteAccess) -> EntryData:
	var entry := EntryData.new()
	entry.position = Vector2i(data.get_u32(), data.get_u32())
	entry.skin = data.get_u8()
	entry.leads_to = data.get_u16()
	return entry

static func load_salvage_point(data: ByteAccess) -> SalvagePointData:
	var salvage_point := SalvagePointData.new()
	salvage_point.position = Vector2i(data.get_u32(), data.get_u32())
	salvage_point.is_output = data.get_u8() != 0
	salvage_point.sid = data.get_s32()
	return salvage_point

static func load_complex(data: ByteAccess) -> ComplexNumber:
	return ComplexNumber.new_with(data.get_s64(), data.get_s64())

static var SCHEMA := {
	"LevelPackData": {
		"@type": Type.Class,
		"@class_name": "LevelPackData",
		"name": {"@type": Type.Str},
		"author": {"@type": Type.Str},
		"description": {"@type": Type.Str},
		"pack_id": {
			"@type": Type.Int,
			"@is_natural": true,
		},
		# here the custom functions shine, so I don't have to store level_order!
		"levels": {
			"@type": Type.Arr,
			"@amount": {
				"@type": Type.Int,
				"@bits": [4, 6, 8, 64],
			},
			"@custom_getter": _pack_data_levels_getter,
			"@keys": "#level_id"
		},
		"@custom_deserialize": _pack_data_custom_deserialize
	},
	"#level_id": {
		"@type": Type.Int,
		"@is_natural": true,
		"@diff": DiffKind.IntGuaranteedDifference,
		# I think level ids, MOST of the time, will either be small or have a small
		# consecutive difference. even tho reordering them is possible, it may not be THAT common
		# to end up with a mess that makes this schema not worth it
		# it seems fine to try 3 smaller bit values, and otherwise just give up
		"@bits": [2, 4, 8, 64],
	},
}

static func _pack_data_levels_getter(pack_data):
	var levels := {}
	for id in pack_data.level_order:
		levels[id] = pack_data.levels[id]
	return levels

static func _pack_data_custom_deserialize(__, pack_data):
	pack_data.level_order = []
	pack_data.level_order.append_array(pack_data.levels.keys())
	return pack_data

# How the schema works:
# The schema itself is a series of "type descriptions", where the key is the type name.
# These are the "global" types.

# A "type description" is a dictionary that describes how a type
# should be stored and retrieved.

# When a type description is expected, it could be declared in-place, nesting types.
# Or, it could be a String referring to another type declared further up.
# All types can have a "@types", a dict declaring common types, which will be caught
# before any same-named type "further up" the chain (global types are the furthest up)
# Only non-implicit types can be named.

# the main key is the "@type", containing a field of the Type enum.
# other keys are settings for the type. 

# Type.Class will have a @class_name which should correspond to a real class that will be instantiated
# (or not, when the output is a dictionary), as well as its fields and their types.
# Type.Bool and Type.Str have no further arguments.

# Type.Int is, when you get down to it, the main type. So it has all these arguments:
# - @bits: how many bits it should be stored as. this can be an int on an array (size should be a
# power of two). if it's for example a 4-member array [2, 4, 8, 32], 2 bits will be used to express
# which of the 4 bit counts was used, meaning it'll take a minimum of 4 and a maximum of 34 bits.
# (default 64)
# - @is_natural: if true, the value can't be negative (default false)
# - @small_infinity: if you expect infinity to be a somewhat regular value (such as with
# door counts), +/- infinity will take few bits instead of the maximum (but this'll slightly
# displace other values) (default false)
# - @div: the number will be divided by this before being stored (usually 16 or 32 for grid-snapped stuff). default 1
# In the special case that @bits are 64 and is_natural is true, the extra bit will be taken advantage of. no bit wasted.

# Type.Arr's main argument is "@arr_type" (another dictionary), OR an array "@arr_types" if there's many possible types.
# But they can have "@amount" which can be a fixed number, or another type declaration (should be int),
# to specify how it should be stored.

# Type.Dict will have "@keys" and "@values" type declarations, as well as "@amount".
# both keys and values could also be arrays of types....
# ArrayLikeDict is a special type of dict where the keys are consecutive integers starting from 0. Intended use is dicts where the keys are enums. They have the same arguments as Arr.

# Type.FieldDict is a dictionary with fixed keys (the fields). It'll be declared like a class.

# Type.BuiltIn will be a built-in type like Vector2i.
# Idk how to instantiate them just based on a string,
# so you're forced to include a "@default" argument.
# Otherwise, the fields are declared just like in a FieldDict.

# All types except Bool have another important field: "@diff".
# If @diff is present, then when that type is stored, a single bit will be used to see
# if it has the same value as the previous instance of that type.
# The main value is DiffKind.Default, which it'll have if the value is "true"
# but if it's DiffKind.IntDifference, then if the value is of type Int, the difference between
# this and the previous value will be stored
# (usually, this'll reserve an extra bit in the case of the largest @bits representation,
# in case the difference literally can not be expressed)
# (the difference is post-applying the corrections to take @small_infinity into account)
# (the difference is always a signed number, even if @is_natural is used)
# (but otherwise it uses the same bit counts as @bits)
# DiffKind.IntGuaranteedDifference will always assume there's a difference, saving the diff bit.
# sadly the value "0" for the diff amount won't be saved in either IntDifference kind :(
# DiffKind.GuaranteedSameGlobal guarantees all instances of this field will have the same value, globally

# Type.Simile will have a "@simile" field, which is the name of a type further up the chain that it will
# imitate, but it's "legally distinct" for the purposes of @diff.

# "@custom_getter" is a Callable that'll be called instead of reading this attribute, with the object to read
# it from as an argument. it should return the desired value. only used for serialization
# "@custom_deserialize" is a Callable that'll be called right before setting the final value for
# this attribute, with two arguments: the object being deserialized that owns this type,
# and the to-be value as an argument. 
# it should return the new value. Only used for deserialization
# "the object being deserialized" will be null at the topmost level (when the type is THE type
# you want to deserialize), please ignore it

enum Type {
	Simile,
	Class,
	BuiltIn,
	Bool,
	Str,
	Int,
	Arr,
	Dict,
	FieldDict,
}

enum DiffKind {
	Default,
	IntDifference,
	IntGuaranteedDifference,
	GuaranteedSameGlobal,
}


const ByteAccess := V4.ByteAccess
