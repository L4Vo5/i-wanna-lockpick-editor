extends SaveLoadVersionLVL

# Differences from V3:
# Loading corrupted levels *attempts* to not crash/hang up.
# Pack has level_order array with level ids, and levels *dict*
# Pack id was added (unfortunately this is handled by SaveLoad, oops, guess i'll just default it to like 0 or something)
# Entry skins are stored as u8 instead of u32
# Salvage points
# ??? whate else


static func convert_dict(dict: Dictionary) -> Dictionary:
	var new_levels := {}
	dict.level_order = []
	for i: int in dict.levels.size():
		var id := i
		new_levels[id] = dict.levels[i]
		dict.level_order.push_back(i)
	dict.levels = new_levels
	dict.pack_id = 0
	dict.salvage_points = {}
	
	#assert(false, "Unfinished!")
	return dict

static func load_from_dict(dict: Dictionary):
	return V5.load_from_dict(V5.convert_dict(dict))

static func load_from_bytes(raw_data: PackedByteArray, offset: int):
	var dict := load_level_pack(raw_data, offset)
	if dict.is_empty(): return null
	return V5.load_from_dict(V5.convert_dict(dict))
	
static func load_level_pack(raw_data: PackedByteArray, offset: int) -> Dictionary:
	var data := ByteAccess.new(raw_data, offset)
	var level_pack := {}
	level_pack._type = &"LevelPackData"
	level_pack._inspect = ["levels"]
	level_pack.name = data.get_string()
	level_pack.author = data.get_string()
	level_pack.pack_id = data.get_s64()
	
	var level_count := data.get_u32()
	
	# Load all levels
	if level_count > MAX_ARRAY_SIZE: return {}
	level_pack.level_order = []
	level_pack.levels = {}
	level_pack.level_order.resize(level_count)
	for i in level_count:
		if data.reached_eof(): return {}
		var id := data.get_u16()
		level_pack.level_order[i] = id
		level_pack.levels[id] = load_level(data)
		if level_pack.levels[id].is_empty(): return {}
	return level_pack

static func load_level(data: ByteAccess) -> Dictionary:
	var level := {}
	level._type = &"LevelData"
	level._inspect = ["keys", "doors", "entries", "salvage_points"]
	var title_name := data.get_string().split("\n")
	assert(title_name.size() == 2)
	level.title = title_name[0]
	level.name = title_name[1]
	level.size = Vector2i(data.get_u32(), data.get_u32())
	var flags := data.get_u8()
	if flags & 1:
		level.goal_position = Vector2i(data.get_u32(), data.get_u32())
	else:
		level.has_goal = false
	level.exitable = (flags & 2) as bool
	level.player_spawn_position = Vector2i(data.get_u32(), data.get_u32())
	
	var tile_amount := data.get_u32()
	level.tiles = {}
	for _i in tile_amount:
		if data.reached_eof(): return {}
		level.tiles[Vector2i(data.get_u32(), data.get_u32())] = true
	
	var key_amount := data.get_u32()
	if key_amount > MAX_ARRAY_SIZE: return {}
	level.keys = []
	level.keys.resize(key_amount)
	for i in key_amount:
		if data.reached_eof(): return {}
		level.keys[i] = load_key(data)
	
	var door_amount := data.get_u32()
	if door_amount > MAX_ARRAY_SIZE: return {}
	level.doors = []
	level.doors.resize(door_amount)
	for i in door_amount:
		if data.reached_eof(): return {}
		level.doors[i] = load_door(data)
		if level.doors[i].is_empty(): return {}
	
	var entry_amount := data.get_u32()
	if entry_amount > MAX_ARRAY_SIZE: return {}
	level.entries = []
	level.entries.resize(entry_amount)
	for i in entry_amount:
		if data.reached_eof(): return {}
		level.entries[i] = load_entry(data)
	
	var salvage_point_amount := data.get_u32()
	if salvage_point_amount > MAX_ARRAY_SIZE: return {}
	level.salvage_points = []
	level.salvage_points.resize(salvage_point_amount)
	for i in salvage_point_amount:
		if data.reached_eof(): return {}
		level.salvage_points[i] = load_salvage_point(data)
	
	return level

static func load_key(data: ByteAccess) -> Dictionary:
	return V3.load_key(data)

# Largely the same as V1 still, but it has early exit on error.
static func load_door(data: ByteAccess) -> Dictionary:
	var door := {}
	door._type = &"DoorData"
	door._inspect = ["locks"]
	
	door.amount = load_complex(data)
	door.position = Vector2i(data.get_u32(), data.get_u32())
	door.size = Vector2i(data.get_u32(), data.get_u32())
	
	var curses_color := data.get_u8()
	# bits are, x1234444, 1 = ice, 2 = erosion, 3 = paint, 4 = color
	door._curses = {}
	# 0 = ice, 1 = erosion, 2 = paint, 3 = brown
	door._curses[0] = curses_color & (1<<6) != 0
	door._curses[1] = curses_color & (1<<5) != 0
	door._curses[2] = curses_color & (1<<4) != 0
	door._curses[3] = false
	door.outer_color = curses_color & 0b1111
	
	var lock_amount := data.get_u16()
	if lock_amount > MAX_ARRAY_SIZE: return {}
	door.locks = []
	door.locks.resize(lock_amount)
	for i in lock_amount:
		if data.reached_eof(): return {}
		door.locks[i] = load_lock(data)
	return door

static func load_lock(data: ByteAccess) -> Dictionary:
	return V1.load_lock(data)

static func load_entry(data: ByteAccess) -> Dictionary:
	var entry := {}
	entry._type = &"EntryData"
	entry.position = Vector2i(data.get_u32(), data.get_u32())
	entry.skin = data.get_u8()
	entry.leads_to = data.get_u16()
	return entry

static func load_salvage_point(data: ByteAccess) -> Dictionary:
	var salvage_point := {}
	salvage_point._type = &"SalvagePointData"
	salvage_point.position = Vector2i(data.get_u32(), data.get_u32())
	salvage_point.is_output = data.get_u8() != 0
	salvage_point.sid = data.get_s32()
	return salvage_point

static func load_complex(data: ByteAccess) -> Dictionary:
	return V1.load_complex(data)

class ByteAccess:
	extends V3.ByteAccess
	
	func store_bool(v: bool) -> void:
		make_space(1)
		data.encode_u8(curr, v)
		curr += 1
	
	func reached_eof() -> bool:
		return curr >= data.size()
	
	func get_bool() -> bool:
		curr += 1
		return data.decode_u8(curr - 1)
