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
		"@min": 0,
		"@max": 1,
	},
	"u2": {
		"@type": Type.Int,
		"@bits": 2,
		"@min": 0,
		"@max": 3,
	},
	"@LevelPackData": {
		"name": "String",
		"author": "String",
		"description": "String",
		"pack_id": {
			"@type": Type.Int,
			"@min": 0,
			"@max": 9223372036854775807,
		},
		# here the custom functions shine, so I don't have to store level_order!
		"levels": {
			"@type": Type.Dict,
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
			"@skip": (func(context): return not context[-1].has_goal),
			"@inherit": "#elem_pos",
			# -1 is the int, -2 the goal position, -3 the level data
			"%MaxXFunc": _elem_get_max_pos.bind(-3, 0),
			"%MaxYFunc": _elem_get_max_pos.bind(-3, 1),
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
		# For most elements: -1 is the int, -2 is the Vector2i, -3 is the element, -4 is the element array, -5 is the desired LevelData
		"%MaxXFunc": _elem_get_max_pos.bind(-5, 0),
		"%MaxYFunc": _elem_get_max_pos.bind(-5, 1),
		"@type": Type.BuiltIn,
		"@default": Vector2i(0, 0),
		"x": {
			"@type": Type.Int,
			"@div": 32,
			"@max": "%[MaxXFunc]",
			"@min": 0,
		},
		"y": {
			"@type": Type.Int,
			"@div": 32,
			"@max": "%[MaxYFunc]",
			"@min": 0,
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
			# -1 is the int, -2 the vector2, -3 the tiles dict, -4 the level
			"x": {
				"@inherit": "#tile_coord",
				"@max": _tile_get_max_pos.bind(-4, 0),
			},
			"y": {
				"@inherit": "#tile_coord",
				"@max": _tile_get_max_pos.bind(-4, 1),
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
		"@arr_type": "%[Class]",
	},
	"@DoorData": {
		"amount": "#door_amount",
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
			"@skip": (func(context): return context[-1].lock_type >= 2),
			"@type": Type.Int,
			"@bits": 1,
		},
		"sign": {
			"@skip": (func(context): return context[-1].lock_type >= 2),
			"@type": Type.Int,
			"@bits": 1,
		},
		"lock_arrangement": {
			# only for Normal locks
			"@skip": (func(context): return context[-1].lock_type >= 1),
			"@type": Type.Int,
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
				"@max": get_lock_max_pos.bind(1),
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
				"@max": get_lock_max_size.bind(1),
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
			# only present if it's Add or Exact
			"@skip": (func(context): return context[-1].type > 1),
			"@type": Type.Class,
			"@class_name": "ComplexNumber",
			"_real_part": {"@inherit" : "#component"},
			"_imaginary_part": {"@inherit" : "#component"},
			"@types": {
				"#component": {
					"@type": Type.Int,
					"@min": -1_000_000_000_000_000_000,
					"@max": 1_000_000_000_000_000_000,
					# actually [3, 6, 11, 20, 37, 70]
					"@bits": [2, 4, 8, 16, 32, 64],
					"@bits_strategy": BitsStrategy.IndexAsConsecutiveZeroes,
					"@diff": DiffKind.Default,
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
	"#door_amount": {
		"@type": Type.Class,
		"@class_name": "ComplexNumber",
		"_real_part": {
			"@inherit": "#probably_small_amount_int",
			"@diff": DiffKind.Default,
		},
		"_imaginary_part": {
			"@inherit": "#probably_small_amount_int",
			"@diff": DiffKind.Default,
		},
		#"@diff": DiffKind.Default,
	},
	"#probably_small_amount_int": {
		"@type": Type.Int,
		"@min": -1_000_000_000_000_000_000,
		"@max": 1_000_000_000_000_000_000,
		"@has_infinity": true,
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

static func _pack_data_levels_getter(context):
	var levels := {}
	var pack_data = context[-1]
	for id in pack_data.level_order:
		levels[id] = pack_data.levels[id]
	return levels

static func _pack_data_custom_deserialize(_context, pack_data: LevelPackData):
	pack_data.level_order = PackedInt32Array()
	pack_data.level_order.append_array(pack_data.levels.keys())
	return pack_data

static func _tile_dict_sort(context): 
	var tiles: Dictionary = context[-1].tiles
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
	var door = context[-3]
	var level = context[-5]
	return level.size[vector_component] - door.position[vector_component]

# not using minimum lock sizes because that'd be hard
static func get_lock_max_pos(context, vector_component: int):
	# -1 is the int, -2 is the Vector2i, -3 is the lock, -4 the locks array, -5 the door
	return context[-5].size[vector_component]

# not using minimum lock sizes because that'd be hard
static func get_lock_max_size(context, vector_component: int):
	# -1 is the int, -2 is the Vector2i, -3 is the lock, -4 the locks array, -5 the door
	return context[-5].size[vector_component] - context[-3].position[vector_component]

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
# anything that starts with "+" is private/hidden, so don't use it.

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
# whenever a setting value is expected, a lot of times you can optionally pass a Callable
# Exceptions are:
# - settings that already expect a Callable
# - @type, @has_infinity, @bits
# (except for @type, and settings that already take Callables anyway)
# this Callable will take as an argument the context that the current instance of the type is 
# in (an array where the previous to last element is the owner of the type, the one before that the owner
# of that owner, etc. the last element will be the element being encoded, or null when decoding)
# in both serialization and deseralization what'll be passed is the real object.
# make sure any fiels of that object you wanna rely on were declared BEFORE whenever this is being
# called.

# "@skip" will be true if this type should be skipped. this can be a Callable.
# Since @skip specifically is called before doing anything else with the type, the context won't have
# the type itself at the end (and won't have null, when deserializing). instead, context[-1]
# is the owner of this field.

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
# - @has_infinity: infinity support, off by default.
# if true,2 will represent infinity, -2 -infinity. then, 3 will represent 2, and so on.
# -1, 0, and 1 are left untouched. this is because they're generally even more common values than infinity
# - @div: the number will be divided by this before being stored (usually 16 or 32 for grid-snapped stuff). default 1
# - @min / @max: the range of values the integer can have, before @div is applied. can shave some bits off if you overestimated them, and MAYBE "fractional bits" could be used.
# In the special case that @bits are 64 and is_natural is true, the extra bit will be taken advantage of. no bit wasted.

# Type.Arr's main setting is "@arr_type" (another dictionary)
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
# (the difference is post-applying the corrections to take @has_infinity into account)
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
	None,
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
	var type_values := {}
	var stack := []
	func _init(_schema: Dictionary):
		if not _schema.has("+compiled"):
			_schema = compile_schema(_schema)
		schema = _schema
	
	# A compiled schema is ready to be used properly
	static func compile_schema(schema_to_compile: Dictionary) -> Dictionary:
		assert(PerfManager.start("compile_schema"))
		var new_schema := {}
		new_schema["+compiled"] = true
		# First, register the global types
		for type_name in schema_to_compile.keys():
			var type: Dictionary = schema_to_compile[type_name]
			# for easy class_name
			if type_name.begins_with("@"):
				type_name = type_name.right(-1)
				if not type.has("@type"):
					type["@type"] = Type.Class
				if not type.has("@class_name"):
					type["@class_name"] = type_name
			type_name = handle_type_name_arguments(type, type_name)
			new_schema[type_name] = type
		
		# Now, resolve inner types
		var pending_type_names = new_schema.keys()
		var pending_types = new_schema.values()
		while not pending_types.is_empty():
			var type_name: String = pending_type_names.pop_back() as String
			if type_name.begins_with("+"):
				pending_types.pop_back()
				continue
			var type: Dictionary = pending_types.pop_back() as Dictionary
			
			if type.has("@types"):
				var types: Dictionary = type["@types"]
				for new_type_name: String in types:
					var value: Dictionary = types[new_type_name]
					new_type_name = type_name + ":" + new_type_name
					assert(not new_schema.has(new_type_name))
					handle_inherit(new_schema, value, new_type_name, type_name)
					new_schema[new_type_name] = value
					pending_type_names.push_back(new_type_name)
					pending_types.push_back(value)
					
				type.erase("@types")
			if type.has("@class_name"):
				type["+class_name"] = type["@class_name"]
				type.erase("@class_name")
			
			var amount_default := {
				"@type": Type.Int,
				"@min": 0,
			}
			# Process the fields AND arguments
			var keys := type.keys()
			for key_name in keys:
				var value = type[key_name]
				if key_name is String and key_name.begins_with("+"):
					pass
				else:
					# if it's String, should be a type. find it.
					if value is String and not value.is_empty():
						# handle template arguments to make a new type
						var argument_start: int = value.find("<")
						if argument_start != -1:
							# new type. find the base
							var base_type_name: String = value.left(argument_start)
							if not new_schema.has(base_type_name):
								print("missing base type: ", base_type_name)
								continue
							var base_type: Dictionary = new_schema[base_type_name]
							var new_type := {
								"@inherit": base_type_name
							}
							
							
							# extract the arguments
							var arguments_str: String = value.substr(argument_start+1,value.length()-argument_start-2)
							var arguments := arguments_str.split(",")
							var positional_arguments = base_type["+positional_arguments"]
							var using_named_arguments := arguments[0].contains("=")
							for i in arguments.size():
								var argument := arguments[i]
								assert(argument.contains("=") == using_named_arguments, "Can't mix named and positional arguments")
								if using_named_arguments:
									var arr := argument.split("=")
									assert(arr.size() == 2)
									var argument_name := arr[0].strip_edges()
									var argument_value := arr[1].strip_edges()
									new_type["%" + argument_name] = argument_value
								else:
									var argument_name: String = positional_arguments[i]
									new_type["%" + argument_name] = argument
							# let the part that handles Dictionaries do the work of actually adding it.
							value = new_type
					if value is String and not value.is_empty():
						if not value.begins_with("%"):
							value = find_type_contextually(new_schema, type_name, value)
							if not new_schema.has(value):
								print("missing type: ", value)
							type[key_name] = value
					if value is Dictionary:
						# new type
						var new_type_name := type_name + ":" + str(key_name)
						assert(not new_schema.has(new_type_name))
						handle_inherit(new_schema, value, new_type_name, type_name)
						if key_name == "@amount":
							value.merge(amount_default)
						print("adding new type: ", new_type_name)
						new_schema[new_type_name] = value
						type[key_name] = new_type_name
						pending_type_names.push_back(new_type_name)
						pending_types.push_back(value)
			new_schema[type_name] = type
		
		# Now that it's been flattened, replace all arguments with their values
		for type_name: String in new_schema.keys():
			var type = new_schema[type_name]
			if not type is Dictionary: continue
			for key in type:
				var value = type[key]
				if value is String:
					var new_value: String = value
					var pos := new_value.find("%")
					if pos != -1:
						var was_non_string := false
						while pos != -1:
							assert(new_value.substr(pos+1,1) == "[")
							var end := new_value.find("]", pos)
							assert(end != -1)
							var argument_name := new_value.substr(pos + 2, end - 2 - pos)
							var argument_value = find_argument_contextually(new_schema, type_name, argument_name)
							print("for key ", value, " of type ", type_name, " found argument ", argument_name, " with value ", argument_value)
							if argument_value is Callable:
								print("bound arguments: ", argument_value.get_bound_arguments())
							if not argument_value is String:
								type[key] = argument_value
								was_non_string = true
								break
							new_value = new_value.left(pos) + argument_value + new_value.right(-end-1)
							
							pos = new_value.find("%")
						if not was_non_string:
							type[key] = new_value
		# get rid of all arguments
		for type_name: String in new_schema.keys():
			if type_name.begins_with("+"): continue
			var type: Dictionary = new_schema[type_name]
			for key in type.keys():
				if key is String and key.begins_with("%"):
					type.erase(key)
		
		# remove incomplete types + get rid of the trash + group fields in +fields
		for type_name: String in new_schema.keys():
			if type_name.begins_with("+"): continue
			var type: Dictionary = new_schema[type_name]
			var fields := {}
			for key in type.keys():
				if key is String and key == "+positional_arguments":
					type.erase(key)
					continue
				if key is String and key.begins_with("+"):
					continue
				var value = type[key]
				if not (key is String and (key.begins_with("+") or key.begins_with("@"))):
					fields[key] = value
					type.erase(key)
				if value is String:
					if not new_schema.has(value):
						print("rip ", type_name, ". u have ", value)
						print(type)
						new_schema.erase(type_name)
						break
			type["+fields"] = fields
		
		# for int types lacking min/max, auto assign if the highest bits value isn't 64
		# (bit counts under 64 will always be auto-assigned as unsigned, so assign them if
		# you want signed numbers under 64 bits)
		for type_name: String in new_schema.keys():
			if type_name.begins_with("+"): continue
			var type: Dictionary = new_schema[type_name]
			if not type.get("@type", Type.Null) == Type.Int: continue
			if not type.has("@bits"): continue
			var maybe_bits = type["@bits"]
			var bits: int = maybe_bits if maybe_bits is int else maybe_bits[-1]
			if bits == 64: continue
			if type.has("@min") and type.has("@max"): continue
			if type.has("@max"):
				var max = type["@max"]
				if not max is Callable:
					type["@min"] = type["@max"] - (1 << bits) + 1
					print("type ", type_name, " had max but no min. min is now ", type["@min"])
			else:
				var min = type.get("@min", 0)
				type["@min"] = min
				if not min is Callable:
					type["@max"] = min + (1 << bits) - 1
		
		# add default value to most settings on all types
		var defaults := {
			"@type": Type.Null,
			"@bits": 64,
			"@bits_strategy": BitsStrategy.IndexAsInt,
			"@has_infinity": false,
			"@min": -1_000_000_000_000_000_000,
			"@max": 1_000_000_000_000_000_000,
			"@div": 1,
			"@diff": false,
			"@diff_kind": DiffKind.IntDifference,
			"@skip": false,
			"@custom_getter": Callable(),
			"@custom_deserialize": Callable(),
		}
		for type_name: String in new_schema.keys():
			if type_name.begins_with("+"): continue
			var type: Dictionary = new_schema[type_name]
			type.merge(defaults)
		
		# add @default to all types
		for type_name: String in new_schema.keys():
			if type_name.begins_with("+"): continue
			var type: Dictionary = new_schema[type_name]
			type["@default"] = get_default_for_type(type, new_schema)
		
		# assert that remaining types do work
		for type_name: String in new_schema.keys():
			if type_name.begins_with("+"): continue
			var type: Dictionary = new_schema[type_name]
			assert(not type["@type"] is Callable)
			assert(not type["@has_infinity"] is Callable)
			assert(not type["@bits"] is Callable)
			for value in type["+fields"].values():
				if value is String:
					assert(new_schema.has(value), "type not found: " + str(value))
		
		# get the int values sorted out
		#for type_name: String in new_schema.keys():
			#if type_name.begins_with("+"): continue
			#var type: Dictionary = new_schema[type_name]
			#type["@default"] = get_default_for_type(type, new_schema)
		
		
		assert(PerfManager.end("compile_schema"))
		#print(JSON.stringify(new_schema, "\t"))
		#DisplayServer.clipboard_set(JSON.stringify(new_schema, "\t"))
		#DisplayServer.clipboard_set(JSON.stringify(schema_to_compile, "\t"))
		return new_schema
	
	static func get_default_for_type(type: Dictionary, used_schema: Dictionary):
		if type.has("@default"):
			return type["@default"]
		var default
		match type["@type"]:
			Type.Int:
				default = 0
				var min = type["@min"]
				var max = type["@max"]
				if min is int and default < min:
					default = min
				elif max is int and default > max:
					default = max
			Type.Str:
				default = ""
			Type.Class:
				default = null
			Type.BuiltIn, Type.Null, Type.Constant:
				assert(false)
			Type.Bool:
				default = false
			Type.Arr:
				default = []
				var amount = type["@amount"]
				if amount is String:
					amount = get_default_for_type(used_schema[amount], used_schema)
				default.resize(amount)
				var default_val = get_default_for_type(used_schema[type["@arr_type"]], used_schema)
				default.fill(default_val)
			Type.Dict:
				default = {}
			Type.FieldDict:
				default = {}
				var fields: Dictionary = type["+fields"]
				for field in fields:
					var value_type = fields[field]
					# catch int defaults, etc.
					var default_value = value_type
					if value_type is String:
						default_value = get_default_for_type(used_schema[value_type], used_schema)
					default[field] = default_value
		return default
	
	## Modifies [type] and returns a new type_name
	static func handle_type_name_arguments(type: Dictionary, type_name: String) -> String:
		if type_name.contains("<"):
			assert(type_name.ends_with(">"))
			var arguments := []
			var pos := type_name.find("<")
			var arguments_str := type_name.substr(pos + 1, type_name.length() - pos - 2)
			var arguments_arr := arguments_str.split(",")
			for argument: String in arguments_arr:
				var sp := argument.split("=")
				assert(sp.size() <= 2)
				var argument_name = sp[0].strip_edges()
				arguments.push_back(argument_name)
				if not type.has("%"+argument_name):
					var argument_value = ""
					if sp.size() == 2:
						argument_value = sp[1].strip_edges()
					type["%"+argument_name] = argument_value
			type_name = type_name.left(pos)
			type["+positional_arguments"] = arguments
		return type_name
	
	# For each power of 2, this stores what power it is
	# (the one for 64 is a negative number, but that's what nearest_po2 returns anyway, so it works out)
	static var BIT_POWS := generate_bit_pows()
	static func generate_bit_pows() -> Dictionary:
		var bit_pows := {}
		for bit_count in 64:
			bit_pows[1 << bit_count] = bit_count
		return bit_pows
	
	# find the existing type that's closest to the current context/namespace
	static func find_type_contextually(schema: Dictionary, current_namespace: String, type_name: String) -> String:
		assert(not current_namespace.ends_with(":"))
		var candidate_type_name := current_namespace + ":" + type_name
		while not schema.has(candidate_type_name):
			var next_namespace := current_namespace.rfind(":")
			if next_namespace == -1:
				return type_name
			current_namespace = current_namespace.left(next_namespace)
			candidate_type_name = current_namespace + ":" + type_name
		return candidate_type_name
	# return the value of an argument, which may be at a higher scope
	static func find_argument_contextually(schema: Dictionary, type_name: String, argument_name: String):
		assert(not type_name.ends_with(":"))
		argument_name = "%" + argument_name
		while not schema[type_name].has(argument_name):
			var next_namespace := type_name.rfind(":")
			if next_namespace == -1:
				return schema[argument_name]
			type_name = type_name.left(next_namespace)
		return schema[type_name][argument_name]
	
	static func handle_inherit(used_schema: Dictionary, new_type: Dictionary, new_type_name: String, new_type_parent: String) -> void:
		if not new_type.has("@inherit"): return
		var base_type_name: String = new_type["@inherit"]
		base_type_name = find_type_contextually(used_schema, new_type_parent, base_type_name)
		var base_type: Dictionary = used_schema[base_type_name]
		assert(not base_type.has("@inherit"))
		new_type.merge(base_type) # overwrite is false
		new_type.erase("@inherit")
		
		# the hard part: inherit sub-types, too.
		for key in new_type:
			var value = new_type[key]
			if value is String:
				if value.begins_with(base_type_name + ":"):
					# Thankfully, it's fine to inherit namespaced stuff
					new_type[key] = {
						"@inherit": value,
					}
	
	func get_object_bits(object_type: String, object) -> PackedByteArray:
		assert(PerfManager.start("SchemaSaver::get_object_bits"))
		assert(schema.has(object_type))
		type_values.clear()
		stack.clear()
		for type_name in schema:
			if type_name.begins_with("+"): continue
			var type: Dictionary = schema[type_name]
			type["+last_value"] = type["@default"]
			type["+bits"] = 0
		
		data = SchemaByteAccess.new([])
		encode_object_bits(object_type, object)
		data.finish()
		assert(PerfManager.end("SchemaSaver::get_object_bits"))
		print("total bytes: ", data.data.size())
		var bits_accounted_for := 0
		for type_name in schema:
			if type_name.begins_with("+"): continue
			var type: Dictionary = schema[type_name]
			if type["+bits"] != 0:
				print("type ", type_name, " accounts for ", type["+bits"], " bits")
			bits_accounted_for += type["+bits"]
		print("total bytes accounted for: ", (bits_accounted_for+7)/8)
		return data.data
	
	func encode_object_bits(type_name, object) -> void:
		assert(not type_name is Callable)
		type_name = maybe_call(type_name)
		if not type_name is String:
			# Must've passed a constant.. it's easier to catch it here
			return
		stack.push_back(object)
		var type_schema: Dictionary = schema[type_name]
		var type: Type = type_schema["@type"]
		var diff_kind: int = type_schema.get("@diff", DiffKind.None)
		assert(diff_kind != DiffKind.Inherited, "Unimplemented")
		match diff_kind:
			DiffKind.Default, DiffKind.IntDifference:
				assert(type_schema.has("+last_value"))
				assert(type == Type.Int)
				var last_value = type_schema["+last_value"]
				if last_value == object:
					data.store_bool(false)
					type_schema["+bits"] += 1
					stack.pop_back()
					return
				else:
					data.store_bool(true)
					type_schema["+bits"] += 1
		type_schema["+last_value"] = object
		
		# encode based on the type
		if type == Type.Null:
			pass
		elif type == Type.Str:
			assert(object is String)
			data.store_string(object)
			type_schema["+bits"] += object.length() + 32
		elif type == Type.Int:
			assert(object is int)
			var bits = type_schema["@bits"]
			var val: int = object
			var min: int = maybe_call(type_schema["@min"])
			var max: int = maybe_call(type_schema["@max"])
			var div: int = maybe_call(type_schema["@div"])
			min /= div
			max /= div
			val /= div
			
			# squeeze in infinity
			# won't work well if @max and @min don't allow for -2/2, but that'll never happen, right?
			if type_schema["@has_infinity"]:
				assert(max >= 2)
				assert(min <= -2)
				min -= 1
				max += 1
				if val == Enums.INT_MAX:
					val = 2
				elif val == Enums.INT_MIN:
					val = -2
				elif val >= 2:
					val += 1
				elif val <= -2:
					val -= 1
			
			# Have to do this because Main Hub.lvl has some stuff out of bounds......
			if val < min:
				push_warning("val < min. adjusting it.")
				val = min
			elif val > max:
				push_warning("val > max. adjusting it.")
				val = max
			assert(min <= max)
			assert(val >= min)
			assert(val <= max)
			if min == max:
				# No need to store it!
				breakpoint # but I wanna find out if this happens
				stack.pop_back()
				return
			if not bits is int:
				bits = bits[-1]
			if bits is int:
				# apply bits reduction: how many bits does it *really* take?
				var range := max - min + 1
				var nearest := nearest_po2(range)
				bits = BIT_POWS[nearest]
				type_schema["+bits"] += bits
				if bits == 64:
					data.store_s64(val)
				else:
					data.store_bits(bits, val - min)
			else:
				data.store_s64(object)
			
		elif type == Type.Arr:
			assert(object is Array)
			encode_object_bits(type_schema["@amount"], object.size())
			for val in object:
				encode_object_bits(type_schema["@arr_type"], val)
		elif type == Type.Dict:
			assert(object is Dictionary)
			encode_object_bits(type_schema["@amount"], object.size())
			for key in object:
				encode_object_bits(type_schema["@keys"], key)
			for value in object.values():
				encode_object_bits(type_schema["@values"], value)
		elif type == Type.Bool:
			data.store_bool(object)
			type_schema["+bits"] += 1
		elif type == Type.Class or type == Type.FieldDict or type == Type.BuiltIn:
			pass
		else:
			assert(false)
		
		# encode further fields.
		var fields: Dictionary = type_schema["+fields"]
		for field_name in fields:
			var field_type_name = fields[field_name]
			if not field_type_name is String:
				# It's a constant, no need to store it.
				pass
			else:
				var field_type = schema[field_type_name]
				if maybe_call(field_type["@skip"]):
					continue
				var getter: Callable = field_type["@custom_getter"]
				var value = getter.call(stack) if not getter.is_null() else object[field_name]
				encode_object_bits(field_type_name, value)
		var popped = stack.pop_back()
		assert(popped == object)
	
	func maybe_call(value):
		if value is Callable:
			value = value.call(stack)
		return value
	
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
			var original_val = val
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
			
			#var v = -99
			#print("hi")
			#for i in 10:
				## investigation time
				#var s = ""
				#for bit in 64:
					#var b = 1 << bit
					#s += "0" if v & b == 0 else "1"
				#s = s.reverse()
				#print(s)
				#store_u32(v)
				#curr -= 4
				#print(get_u32())
				#curr -= 4
				##print(String.num_int64(v, 2))
				#v >>= 1
			#print("...")
			assert(val == 0 or val == -1)
		
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
		
		func store_bool(v: bool) -> void:
			store_bit(v as int)
		
		func get_bool() -> bool:
			return get_bit() == 1
		
		func finish() -> void:
			if individual_byte_pos != -1:
				data.encode_u8(individual_byte_pos, individual_byte)
			compress()
		

const ByteAccess := V4.ByteAccess
