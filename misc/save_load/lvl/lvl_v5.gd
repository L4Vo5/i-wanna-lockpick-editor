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
	schema_to_bits(SCHEMA, level_pack, "LevelPackData", raw_data, offset)
	return
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
	"String": {
		"@type": Type.Str
	},
	"bool": {
		"@type": Type.Bool,
	},
	"u32": {
		"@type": Type.Int,
		"@bits": 32,
		"@min": 0,
	},
	"s64": {
		"@type": Type.Int,
		"@bits": 64,
	},
	"u1": {
		"@type": Type.Int,
		"@bits": 1,
	},
	"u2": {
		"@type": Type.Int,
		"@bits": 1,
	},
	"@LevelPackData": {
		"name": "String",
		"author": "String",
		"description": "String",
		"pack_id": {
			"@type": Type.Int,
			"@min": 0,
		},
		# here the custom functions shine, so I don't have to store level_order!
		"levels": {
			"@type": Type.Arr,
			"@amount": {
				"@type": Type.Int,
				"@bits": [4, 6, 8, 64],
			},
			"@custom_getter": _pack_data_levels_getter,
			"@keys": "#level_id",
			"@values": "LevelData",
		},
		"@custom_deserialize": _pack_data_custom_deserialize
	},
	"#level_id": {
		"@type": Type.Int,
		"@min": 0,
		"@diff": DiffKind.IntGuaranteedDifference,
		# I think level ids, MOST of the time, will either be small or have a small
		# consecutive difference. even tho reordering them is possible, it may not be THAT common
		# to end up with a mess that makes this schema not worth it
		# it seems fine to try 3 smaller bit values, and otherwise just give up
		"@bits": [2, 4, 8, 64],
	},
	"@LevelData": {
		"name": "String",
		"title": "String",
		"label": "String",
		"author": "String",
		"description": "String",
		"exitable": "bool",
		"size": {
			"@type": Type.BuiltIn,
			"@default": Vector2i(800, 608),
			"x": {
				"@inherit": "#level_size_component",
				"@min": 800,
			},
			"y": {
				"@inherit": "#level_size_component",
				"@min": 608,
			},
		},
		"tiles": "#level_tiles",
		"player_spawn_position": {
			# idk the exact limits for this so whatever lol
			"@type": Type.BuiltIn,
			"@default": Vector2i(398, 304),
			"x": "u32",
			"y": "u32",
		},
		"has_goal": "bool",
		"goal_position": {
			"@inherit": "elem_pos",
			"%MaxXFunc": _elem_get_max_pos.bind(-2, 0),
			"%MaxYFunc": _elem_get_max_pos.bind(-2, 1),
		},
		"doors": "#element_array<DoorData>",
		"keys": "#element_array<KeyData>",
		"entries": "#element_array<EntryData>",
		"salvage_points": "#element_array<SalvagePointData>",
		"@types": {
			"#level_size_component": {
				"@type": Type.Int,
				"@diff": DiffKind.IntDifference,
				"@div": 32,
				# 8 bits takes care of level sizes up to 4096.
				# otherwise you have enough stuff to make the 33 bits worth it.
				"@bits": [7, 32],
			},
		},
	},
	"#elem_pos<MaxXFunc, MaxYFunc>": {
		# For most elements: -1 is the Vector2i, -2 is the element, -3 is the element array, -4 is the desired LevelData
		"%MaxXFunc": _elem_get_max_pos.bind(-4, 0),
		"%MaxYFunc": _elem_get_max_pos.bind(-4, 1),
		"@type": Type.BuiltIn,
		"@default": Vector2i(0, 0),
		"x": {
			"@type": Type.Int,
			"@div": 32,
			"@max": "%[MaxXFunc]",
		},
		"y": {
			"@type": Type.Int,
			"@div": 32,
			"@max": "%[MaxYFunc]",
		},
	},
	"#level_tiles": {
		"@type": Type.Dict,
		"@amount": {
			"@type": Type.Int,
		},
		"@values": true, # constant
		"@keys": {
			"@type": Type.BuiltIn,
			"@default": Vector2i.ZERO,
			"x": {
				"@inherit": "#tile_coord",
				"@max": _tile_get_max_pos.bind(-2, 0),
			},
			"y": {
				"@inherit": "#tile_coord",
				"@max": _tile_get_max_pos.bind(-2, 1),
			},
		},
		"@types": {
			"#tile_coord": {
				"@type": Type.Int,
				"@diff": DiffKind.IntDifference,
				"@min": 0,
				# pretty efficient packing of tiles that are *right* next to eachother (4 bits per tile)
				"@bits": [1, 4, 8, 32],
			},
		},
		# For the diff to work out, they've gotta have *some* sort of sorting.
		# Specially since there's no "smart rearranging" option (yet?).
		"@custom_getter": _tile_dict_sort,
	},
	"#element_array<Class>": {
		"@type": Type.Arr,
		"@amount": {
			"@type": Type.Int,
			"@min": 0,
			# surely most levels won't have more than 127 of any given thing.
			# I can spare the extra bit for levels that do.
			"@bits": [7, 32],
		},
		"@values": "%[Class]",
	},
	"@DoorData": {
		"amount": "ComplexNumber",
		"outer_color": "#color",
		"position": "#elem_pos",
		"size": {
			"@type": Type.BuiltIn,
			"@default": Vector2i(0, 0),
			"x": {
				"@type": Type.Int,
				"@div": 32,
				"@min": 32,
				"@max": _get_door_data_max_size.bind(0),
			},
			"y": {
				"@type": Type.Int,
				"@div": 32,
				"@min": 32,
				"@max": _get_door_data_max_size.bind(1),
			},
		},
		"_curses": {
			"@type": Type.FieldDict,
			0: "bool",
			1: "bool",
			2: "bool",
		},
		"locks": {
			"@type": Type.Arr,
			"@amount": {
				"@type": Type.Int,
				"@bits": [1, 2, 6, 16, 32],
				"@bits_strategy": BitsStrategy.IndexAsConsecutiveZeroes,
			},
			"@arr_type": "LockData",
		}
	},
	"@LockData": {
		"color": "#color",
		"lock_type": "u2",
		"value_type": {
			"@type": (func(context): return Type.Null if context[-1].lock_type >= 2 else Type.Int),
			"@bits": 1,
		},
		"sign": {
			"@type": (func(context): return Type.Null if context[-1].lock_type >= 2 else Type.Int),
			"@bits": 1,
		},
		"lock_arrangement": {
			# only for Normal locks
			"@type": (func(context): return Type.Null if context[-1].lock_type >= 1 else Type.Int),
			"@bits": [1, 2, 16],
			"@bits_strategy": BitsStrategy.IndexAsConsecutiveZeroes,
		},
		"position": {
			"@type": Type.BuiltIn,
			"@default": Vector2i(7, 7),
			"x": {
				"@type": Type.Int,
				"@min": 0,
				"@max": get_lock_max_pos.bind(0),
			},
			"y": {
				"@type": Type.Int,
				"@min": 0,
				"@max": get_lock_max_pos.bind(0),
			},
		},
		"size": {
			"@type": Type.BuiltIn,
			"@default": Vector2i(18, 18),
			"x": {
				"@type": Type.Int,
				"@min": 1,
				"@max": get_lock_max_size.bind(0),
			},
			"y": {
				"@type": Type.Int,
				"@min": 1,
				"@max": get_lock_max_size.bind(0),
			},
		},
	},
	"@KeyData": {
		"position": "#elem_pos",
		"is_infinite": "bool",
		"color": "#color",
		"type": {
			"@type": Type.Int,
			"@min": 0,
			"@max": 6,
		},
		"amount": {
			# only if Add or Exact
			"@type": (func(context): return Type.Class if context[-1].type <= 1 else Type.Null),
			"@class_name": "ComplexNumber",
			"_real_part": "#component",
			"_imaginary_part": "#component",
			"@types": {
				"#component": {
				"@type": Type.Int,
				"@min": -1_000_000_000_000_000_000,
				"@max": 1_000_000_000_000_000_000,
				# actually [3, 6, 11, 20, 37, 70]
				"@bits": [2, 4, 8, 16, 32, 64],
				"@bits_strategy": BitsStrategy.IndexAsConsecutiveZeroes,
				},
			},
		},
	},
	"@EntryData": {
		"position": "#elem_pos",
		"leads_to": {
			"@type": Type.Int,
			"@min": 0,
			# actually [3, 6, 11, 20, 37, 70]
			"@bits": [2, 4, 8, 16, 32, 64],
		},
	},
	"@SalvagePointData": {
		"position": "#elem_pos",
		"is_output": "bool",
		"leads_to": {
			"@type": Type.Int,
			"@min": -1,
			"@max": 999,
			"@bits": [4, 10],
		},
	},
	"@ComplexNumber": {
		"_real_part": {
			"@inherit": "#probably_small_amount_int",
		},
		"_imaginary_part": {
			"@inherit": "#probably_small_amount_int",
		},
		"@diff": DiffKind.Default,
	},
	"#probably_small_amount_int": {
		"@type": Type.Int,
		"@min": -1_000_000_000_000_000_000,
		"@max": 1_000_000_000_000_000_000,
		"@small_infinity": true,
		# the smallest values are -1, -inf, 0, inf, 1, which will also be the most common.
		# 2, 1 can represent 6 different values. with IndexAsConsecutiveZeroes, these small values will
		# take 3 bits. so small ComplexNumbers will take 7 bits 
		"@bits": [2, 1, 8, 16, 64],
		"@bits_strategy": BitsStrategy.IndexAsConsecutiveZeroes,
	},
	"#color": {
		"@type": Type.Int,
		"@min": 1, # "None" doesn't count
		"@max": 15, # "Gate"
	}
}

static func _pack_data_levels_getter(pack_data):
	var levels := {}
	for id in pack_data.level_order:
		levels[id] = pack_data.levels[id]
	return levels

static func _pack_data_custom_deserialize(_context, pack_data: LevelPackData):
	pack_data.level_order = PackedInt32Array()
	pack_data.level_order.append_array(pack_data.levels.keys())
	return pack_data

static func _tile_dict_sort(_context, tiles): 
	var new_tiles := {}
	var tiles_coords: Array = tiles.keys()
	# default sort on vectors will leave like-x vectors together
	# but since this game is mostly horizontal, I think it's better to instead
	# leave like-y vectors together
	tiles_coords.sort_custom(func(v1, v2):
		return (v1.y < v2.y) or (v1.y == v2.y and v1.x < v2.x)
	)
	for coord in tiles_coords:
		new_tiles[coord] = tiles[coord]
	return new_tiles

static func _tile_get_max_pos(context, level_data_index: int, vector_component: int):
	return context[level_data_index].size[vector_component] / 32 - 1

# elements are always at least 32x32
static func _elem_get_max_pos(context, level_data_index: int, vector_component: int):
	return context[level_data_index].size[vector_component] - 32

static func _get_door_data_max_size(context, vector_component: int):
	var door = context[-2]
	var level = context[-4]
	return level.size[vector_component] - door.position[vector_component]

# not using minimum lock sizes because that'd be hard
static func get_lock_max_pos(context, vector_component: int):
	# -1 is the Vector2i, -2 is the lock, -3 the locks array, -4 the door
	return context[-4].size[vector_component]

# not using minimum lock sizes because that'd be hard
static func get_lock_max_size(context, vector_component: int):
	# -1 is the Vector2i, -2 is the lock, -3 the locks array, -4 the door
	return context[-4].size[vector_component] - context[-2].position[vector_component]

# How the schema works:
# The schema itself is a series of "type descriptions", where the key is the type name.
# These are the "global" types.

# Type names:
# by convention, non-class types are denoted with # if they refer to something used only in 
# a couple specific contexts, and without # if it's a generic type that can be used in many places
# types starting with @ will automatically have the Type.Class type and
# have @class_name assigned with the same name. but for convenience they're called without the @,
# so don't make a type with that name.
# (this is inherited, so technically it can be overriden)

# A "type description" is a dictionary that describes how a type
# should be stored and retrieved.
# settings start with "@"

# Types can have template arguments, declared at the end of the type within <> triangle brackets
# Their names can't have any special characters or spaces.
# Within the type, these arguments are used within %[]. for example in the type "Name<Thing, Thing2>",
# anywhere in scope of that type can do %[Thing] or %[Thing2] to replace whatever's inside with the argument.
# arguments are typically strings, and they default to an empty string.
# to give them a default value use =, for example "Name<Thing = bool, Thing2>"
# If you want arguments to have non-string values, use it as a field, for example "%Thing2" = 5
# To use arguments with string values the easiest way is to pass them in triangle brackets, either
# in order or named. for example "Name<bool, int>" or "Name<Thing2 = int>"
# To use non-string arguments, one way is to use "@inherit" and override the default there.
# BUT, since arguments are scoped, you can have a "ghost argument" that's not part of the type or used
# in the type, but given a non-string value so it can be easily passed to another type with *another* argument
# For example, you declare "%IntBits" = [2, 4, 8, 32], then if there's an Int class with "Bits" as
# an argument, you can do "Int<Bits = %[IntBits]>" (or "Int<%[IntBits]>")
# internally, each set of arguments a type is called with will create a whole separate type, so
# currently their arguments cannot be Callables (if they are, they'll just be passed as an argument,
# not executed to find out what argument to get)
# the extra type will be declared alongside the use for it, so it can use types from its context.

# When a type description is expected, it could be declared in-place, nesting types.
# Or, it could be a String referring to another type declared further up.
# All types can have a "@types", a dict declaring common types, which will be caught
# before any same-named type "further up" the chain (global types are the furthest up)
# Only non-implicit types can be named.
# The third alternative is a constant. For dictionary or string constants, use Type.Constant.

# the main setting is "@type", containing a field of the Type enum.
# whenever a setting value is expected, you can optionally pass a Callable
# (except for the settings that already take Callables anyway)
# this Callable will take as an argument the context that the current instance of the type is 
# in (an array where the last element is the owner of the type, the previous to last the owner
# of that owner, etc.)
# in both serialization and deseralization what'll be passed is the real object.
# make sure any fiels of that object you wanna rely on were declared BEFORE whenever this is being
# called.

# Type.Class will have a @class_name which should correspond to a real class that will be instantiated
# (or not, when the output is a dictionary), as well as its fields and their types.
# Type.Bool and Type.Str have no further arguments.

# Type.Int is, when you get down to it, the main type. So it has all these settings:
# - @bits: how many bits it should be stored as. this can be an int or an array.
# if it's for example a 4-member array [2, 4, 8, 32], by default 2 bits will be used to express
# which of the 4 bit counts was used, meaning it'll take a minimum of 4 and a maximum of 34 bits.
# (default 64)
# the unused permutations from smaller bit counts are semi-utilized. for example, if @bits is [2, 4, 8]
# @min is 0, and 4 bits are used, it certainly won't be 0, 1, 2 or 3. so, if 4 bits are used,
# 0000 will represent 4, 0001 will be 5, 0010 6, and so on, representing up to 19.
# with this in mind, a value like [2, 1, 4] can still make sense
# - @bits_strategy: the strategy used to encode the information for how many bits it'll take,
# a member of the BitsStrategy enum. default is IndexAsInt.
# - - IndexAsInt: the index will be encoded as an unsigned integer, taking up as many bits as the
# max index needs
# - - IndexAsConsecutiveZeroes: The index will be an amount of consecutive zeroes followed by a 1,
# no zeroes means the first index, one means the second, etc. the advantage of this approach is it can
# scale with the amount of bits needed. for example, the array [1, 2, 4, 8, 16, 32, 64] means the amount
# of bits used are [2, 4, 7, 12, 21, 38, 71]. with the IndexAsInt strategy it'd be [4, 5, 7...]
# meaning, if mostly 1 or 2 bits are used, this strategy will be more efficient. and for bigger bit
# counts, the extra bits are proportionally small anyway.
# - @small_infinity: if you expect infinity to be a somewhat regular value (such as with
# door counts), +/- infinity will take few bits instead of the maximum (but this'll slightly
# displace other values) (default false). this is also needed if you set a min or max that don't
# cover infinity.
# to be specific, 2 will represent infinity, -2 -infinity. then, 3 will represent 2, and so on.
# -1, 0, and 1 are left untouched. this is because they're generally even more common values than infinity
# - @div: the number will be divided by this before being stored (usually 16 or 32 for grid-snapped stuff). default 1
# - @min / @max: the range of values the integer can have, before @div is applied. can shave some bits off if you overestimated them, and MAYBE "fractional bits" could be used.
# In the special case that @bits are 64 and is_natural is true, the extra bit will be taken advantage of. no bit wasted.

# Type.Arr's main setting is "@arr_type" (another dictionary), OR an array "@arr_types" if there's many possible types.
# But they can have "@amount" which can be a fixed number, or another type declaration (should be int),
# to specify how it should be stored. if it's a typed declaration, it'll by default have
# is_natural set to true, bits set to 64, and be an Int.
# and really, it being a fixed number is basically shorthand for a Type.Constant.
# Note that an @amount type will always have a @min of at least 0.
# Arr also accepts a "@default" value, useful to avoid errors on typed/packed arrays

# Type.Dict will have "@keys" and "@values" type declarations, as well as "@amount".
# both keys and values could also be arrays of types....
# ArrayLikeDict is a special type of dict where the keys are consecutive integers starting from 0. Intended use is dicts where the keys are enums. They have the same settings as Arr.

# Type.FieldDict is a dictionary with fixed keys (the fields). It'll be declared like a class.

# Type.BuiltIn will be a built-in type like Vector2i.
# Idk how to instantiate them just based on a string,
# so you're forced to include a "@default" setting.
# Otherwise, the fields are declared just like in a FieldDict.

# Type.Constant always has the same value, which comes from the field "@value".
# Useful for "dicts" where the values are constants. this is an alternative to needing custom
# functions to save on those extra bits.

# Type.Null will be ignored. Useful for excluding a variable based on another variable.

# All types except Bool have another important field: "@diff".
# If @diff is present, then when that type is stored, a single bit will be used to see
# if it has the same value as the previous instance of that type.
# The main value is DiffKind.Default, which it'll have if the value is "true"
# but if it's DiffKind.IntDifference, then if the value is of type Int, the difference between
# this and the previous value will be stored
# (usually, this'll reserve an extra bit in the case of the largest @bits representation,
# in case the difference literally can not be expressed)
# (the difference is post-applying the corrections to take @small_infinity into account)
# (the difference is always a signed number)
# (but otherwise it uses the same bit counts as @bits)
# DiffKind.IntGuaranteedDifference will always assume there's a difference, omitting the diff bit.
# This difference *can* be 0, so it doesn't have to REALLY be guaranteed. but if it's 0 very often, you'll
# miss out on the savings the diff bit could bring.
# DiffKind.GuaranteedSameGlobal guarantees all instances of this field will have the same value, globally
# @diff only works across the *same* type. different types, even @inherit-ed ones, will each have their own diff.

# all type descriptions can have an "@inherit" field, which is the name of a type further up the
# chain that it will imitate, but it's "legally distinct" for the purposes of @diff.
# any other fields will override the inherited ones

# "@custom_getter" is a Callable that'll be called instead of reading this attribute, with the context
# as an argument. (the owner can be gotten with context[-1])
# it should return the desired value. only used for serialization
# "@custom_deserialize" is a Callable that'll be called right before setting the final value for
# this attribute, with two arguments: the context, and the to-be value as an argument. 
# it should return the new value. Only used for deserialization
# the context will be empty at the topmost level, when the type is THE type you want to deserialize

enum Type {
	Null,
	Class,
	Constant,
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
	Inherited,
}

enum BitsStrategy {
	IndexAsInt,
	IndexAsConsecutiveZeroes,
}

static func schema_to_bits(schema: Dictionary, object, object_type: String, raw_data: PackedByteArray, offset: int) -> void:
	var schema_saver := SchemaSaver.new(schema)
	var bits := schema_saver.get_object_bits(object_type, object)
	raw_data.resize(offset)
	raw_data.append_array(bits)

class SchemaSaver:
	var schema: Dictionary
	var data: SchemaByteAccess
	var all_types := {}
	func _init(_schema: Dictionary):
		if not _schema.has("+flattened"):
			_schema = flatten_schema(_schema)
		schema = _schema
	
	static func flatten_schema(schema_to_compile: Dictionary) -> Dictionary:
		assert(PerfManager.start("compile_schema"))
		var new_schema := {}
		new_schema["+flattened"] = true
		var pending_type_names = schema_to_compile.keys()
		var pending_types = schema_to_compile.values()
		while not pending_types.is_empty():
			var type_name: String = pending_type_names.pop_back() as String
			var type: Dictionary = pending_types.pop_back() as Dictionary
			if type_name.begins_with("@"):
				type_name = type_name.right(-1)
				if not type.has("@type"):
					type["@type"] = Type.Class
				if not type.has("@class_name"):
					type["@class_name"] = type_name
			new_schema[type_name] = type
		assert(PerfManager.end("compile_schema"))
		print(JSON.stringify(new_schema, " "))
		return new_schema
	
	func get_object_bits(object_type: String, object) -> PackedByteArray:
		assert(schema.has(object_type))
		all_types.clear()
		data = SchemaByteAccess.new([])
		var stack := []
		
		
		return data.data
	
	func encode_object_bits(type: String, object) -> void:
		pass
	
	class SchemaByteAccess:
		extends ByteAccess
		# 0-indexed
		var current_individual_bit := -1
		var individual_byte := 0
		var individual_byte_pos := -1
		
		func store_bit(val: int) -> void:
			assert(val == 0 or val == 1)
			if current_individual_bit == 7:
				data.encode_u8(individual_byte_pos, individual_byte)
				individual_byte = 0
			if current_individual_bit == 7 or current_individual_bit == -1:
				make_space(1)
				individual_byte_pos = curr
				curr += 1
				current_individual_bit = 0
			else:
				current_individual_bit += 1
			individual_byte |= val << current_individual_bit
		
		func get_bit() -> int:
			individual_byte >>= 1
			if current_individual_bit == -1 or current_individual_bit == 7:
				individual_byte = get_u8()
				current_individual_bit = 0
			else:
				current_individual_bit += 1
			return individual_byte & 1
		
		# will store them UNSIGNED.
		func store_bits(bit_count: int, val: int) -> void:
			assert(bit_count < 64)
			assert(val <= (1 << bit_count) - 1)
			# store bytes first. least significant bytes are stored first
			if bit_count >= 32:
				store_u32(val & 0xFFFFFFFF)
				val >>= 32
				bit_count -= 32
			if bit_count >= 16:
				store_u16(val & 0xFFFF)
				val >>= 16
				bit_count -= 16
			if bit_count >= 8:
				store_u8(val & 0xFF)
				val >>= 8
				bit_count -= 8
			# I'll just be lazy for now
			for i in bit_count:
				store_bit(val & 1)
				val >>= 1
			assert(val == 0)
		
		func get_bits(bit_count: int) -> int:
			var val := 0
			# read bytes first, least significant bytes are loaded first
			var bytes_offset := 0
			if bit_count >= 32:
				val += get_u32() << bytes_offset
				bytes_offset += 32
				bit_count -= 32
			if bit_count >= 16:
				val += get_u16() << bytes_offset
				bytes_offset += 16
				bit_count -= 16
			if bit_count >= 8:
				val += get_u8() << bytes_offset
				bytes_offset += 8
				bit_count -= 8
			for i in bit_count:
				val += get_bit() << bytes_offset
				bytes_offset += 1
			return val
		
		func finish() -> void:
			if individual_byte_pos != -1:
				data.encode_u8(individual_byte_pos, individual_byte)
		

const ByteAccess := V4.ByteAccess
