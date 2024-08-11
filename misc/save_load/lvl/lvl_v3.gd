extends SaveLoadVersionLVL

# Differences from V2:
# Entries were added
# Keys can be infinite
# level pack instead of level data

static func convert_dict(dict: Dictionary) -> Dictionary:
	dict.entries = []
	for key in dict.keys:
		key.is_infinite = false
	var new_dict := {}
	new_dict._type = &"LevelPackData"
	new_dict._inspect = ["levels"]
	new_dict.levels = [dict]
	new_dict.name = dict.name
	new_dict.author = dict.author
	dict.erase("name")
	dict.erase("author")
	return new_dict

static func load_from_dict(dict: Dictionary):
	return V4.load_from_dict(V4.convert_dict(dict))

static func load_from_bytes(raw_data: PackedByteArray, offset: int):
	var data := ByteAccess.new(raw_data, offset)
	var level_pack := {}
	level_pack._type = &"LevelPackData"
	level_pack._inspect = ["levels"]
	level_pack.name = data.get_string()
	level_pack.author = data.get_string()
	
	var level_count := data.get_u32()
	
	level_pack.levels = []
	for i in level_count:
		level_pack.levels.push_back(load_level(data))
	return V4.load_from_dict(V4.convert_dict(level_pack))

static func load_level(data: ByteAccess) -> Dictionary:
	var level := {}
	level._type = &"LevelData"
	level._inspect = ["keys", "doors", "entries"]
	var title_name := data.get_string().split("\n")
	assert(title_name.size() == 2)
	level.title = title_name[0]
	level.name = title_name[1]
	level.size = Vector2i(data.get_u32(), data.get_u32())
	var _custom_lock_arrangements = data.get_var()
	level.goal_position = Vector2i(data.get_u32(), data.get_u32())
	level.player_spawn_position = Vector2i(data.get_u32(), data.get_u32())
	
	var tile_amount := data.get_u32()
	level.tiles = {}
	for _i in tile_amount:
		level.tiles[Vector2i(data.get_u32(), data.get_u32())] = true
	
	var key_amount := data.get_u32()
	level.keys = []
	level.keys.resize(key_amount)
	for i in key_amount:
		level.keys[i] = load_key(data)
	
	var door_amount := data.get_u32()
	level.doors = []
	level.doors.resize(door_amount)
	for i in door_amount:
		level.doors[i] = load_door(data)
	
	var entry_amount := data.get_u32()
	level.entries = []
	level.entries.resize(entry_amount)
	for i in entry_amount:
		level.entries[i] = load_entry(data)

	return level

static func load_key(data: ByteAccess) -> Dictionary:
	var key := {}
	key._type = &"KeyData"
	key.amount = load_complex(data)
	key.position = Vector2i(data.get_u32(), data.get_u32())
	var inf_type_color := data.get_u8()
	key.color = inf_type_color & 0b1111
	key.type = inf_type_color >> 4 & 0b111
	key.is_infinite = (inf_type_color >> 7) == 1
	
	return key

static func load_door(data: ByteAccess) -> Dictionary:
	return V1.load_door(data)

static func load_entry(data: ByteAccess) -> Dictionary:
	var entry := {}
	entry._type = &"EntryData"
	entry.position = Vector2i(data.get_u32(), data.get_u32())
	entry.skin = data.get_u32()
	entry.leads_to = data.get_u32()
	return entry

static func load_complex(data: ByteAccess) -> Dictionary:
	return V1.load_complex(data)

const ByteAccess := V2.ByteAccess
