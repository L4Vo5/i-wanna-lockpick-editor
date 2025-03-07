extends SaveLoadVersionLVL

# Differences from V5:
# Key Counters

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
	data.store_string(level.title)
	data.store_string(level.name)
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
	# Counters
	data.store_u32(level.keycounters.size())
	for counter in level.keycounters:
		save_key_counter(data, counter)
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

static func save_key_counter(data: ByteAccess, counter: CounterData) -> void:
	data.store_u32(counter.position.x)
	data.store_u32(counter.position.y)
	data.store_u32(counter.length)
	
	data.store_u16(counter.colors.size())
	for color in counter.colors:
		save_key_counter_part(data, color)

static func save_key_counter_part(data: ByteAccess, counterpart: CounterPartData) -> void:
	data.store_u8(counterpart.color)

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
		assert(level_pack.levels[id])
	return level_pack

static func load_level(data: ByteAccess) -> LevelData:
	var level := LevelData.new()
	level.title = data.get_string()
	level.name = data.get_string()
	level.label = data.get_string()
	level.author = data.get_string()
	level.description = data.get_string()
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
		
	var counter_amount := data.get_u32()
	if SaveLoad.PRINT_LOAD: print("key counter count is %d" % counter_amount)
	if counter_amount > MAX_ARRAY_SIZE: return
	level.keycounters.resize(counter_amount)
	for i in counter_amount:
		if data.reached_eof(): return
		level.keycounters[i] = load_key_counter(data)
	
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

static func load_key_counter(data: ByteAccess) -> CounterData:
	var key_counter := CounterData.new()
	
	key_counter.position = Vector2i(data.get_u32(), data.get_u32())
	key_counter.length = data.get_u32()
	
	var colors_amount := data.get_u16()
	if colors_amount > MAX_ARRAY_SIZE: return
	key_counter.colors.resize(colors_amount)
	for i in colors_amount:
		if data.reached_eof(): return
		key_counter.colors[i] = load_key_counter_part(data, i)
	
	return key_counter

static func load_key_counter_part(data: ByteAccess, number: int) -> CounterPartData:
	var key_counter_part := CounterPartData.new()
	key_counter_part.color = data.get_u8()
	key_counter_part.position = number
	
	return key_counter_part

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

const ByteAccess := V4.ByteAccess
