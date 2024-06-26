const ByteAccess = preload("res://misc/saving_versions/byte_access_v1.gd")

static func load(data: ByteAccess) -> LevelPackData:
	return LevelPackData.make_from_level(_load_level(data))

static func _load_level(data: ByteAccess) -> LevelData:
	assert(PerfManager.start("SaveLoadV1::load"))
	var level := LevelData.new()
	level.name = data.get_string()
	level.author = data.get_string()
	level.size = Vector2i(data.get_u32(), data.get_u32())
	
	level.custom_lock_arrangements = data.get_var()
	level.goal_position = Vector2i(data.get_u32(), data.get_u32())
	level.player_spawn_position = Vector2i(data.get_u32(), data.get_u32())
	if SaveLoad.PRINT_LOAD: print("loaded player pos: %s" % str(level.player_spawn_position))
	
	var tile_amount := data.get_u32()
	if SaveLoad.PRINT_LOAD: print("tile count is %d" % tile_amount)
	for _i in tile_amount:
		level.tiles[Vector2i(data.get_u32(), data.get_u32())] = true
	
	var key_amount := data.get_u32()
	if SaveLoad.PRINT_LOAD: print("key count is %d" % key_amount)
	level.keys.resize(key_amount)
	for i in key_amount:
		level.keys[i] = _load_key(data)
	
	var door_amount := data.get_u32()
	if SaveLoad.PRINT_LOAD: print("door count is %d" % door_amount)
	level.doors.resize(door_amount)
	assert(PerfManager.start("SaveLoadV1::load (loading doors)"))
	for i in door_amount:
		level.doors[i] = _load_door(data)
	assert(PerfManager.end("SaveLoadV1::load (loading doors)"))
	
	assert(PerfManager.end("SaveLoadV1::load"))
	return level

static func _load_key(data: ByteAccess) -> KeyData:
	var key := KeyData.new()
	key.amount = _load_complex(data)
	key.position = Vector2i(data.get_u32(), data.get_u32())
	var type_and_color := data.get_u8()
	key.color = type_and_color & 0b1111
	key.type = type_and_color >> 4
	
	return key

static func _load_door(data: ByteAccess) -> DoorData:
	var door := DoorData.new()
	
	door.amount = _load_complex(data)
	door.position = Vector2i(data.get_u32(), data.get_u32())
	door.size = Vector2i(data.get_u32(), data.get_u32())
	
	var curses_color := data.get_u8()
	# bits are, x1234444, 1 = ice, 2 = erosion, 3 = paint, 4 = color
	door.set_curse(Enums.curse.ice, curses_color & (1<<6) != 0)
	door.set_curse(Enums.curse.erosion, curses_color & (1<<5) != 0)
	door.set_curse(Enums.curse.paint, curses_color & (1<<4) != 0)
	door.outer_color = curses_color & 0b1111
	
	var lock_amount := data.get_u16()
	door.locks.resize(lock_amount)
	for i in lock_amount:
		door.locks[i] = _load_lock(data)
	return door

static func _load_lock(data: ByteAccess) -> LockData:
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
	lock.dont_show_lock = bit_data & 0b1
	bit_data >>= 1
	lock.color = bit_data & 0b1111
	bit_data >>= 4
	lock.lock_type = bit_data
	
	return lock

static func _load_complex(data: ByteAccess) -> ComplexNumber:
	return ComplexNumber.new_with(data.get_s64(), data.get_s64())

static func make_byte_access(data: PackedByteArray, offset := 0) -> ByteAccess:
	return ByteAccess.new(data, offset)
