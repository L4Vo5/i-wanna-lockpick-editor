static func load(file: FileAccess) -> LevelData:
	assert(PerfManager.start("SaveLoadV1::load"))
	var level := LevelData.new()
	level.name = file.get_pascal_string()
	level.author = file.get_pascal_string()
	level.size = Vector2i(file.get_32(), file.get_32())
	level.custom_lock_arrangements = file.get_var()
	level.goal_position = Vector2i(file.get_32(), file.get_32())
	level.player_spawn_position = Vector2i(file.get_32(), file.get_32())
	if SaveLoad.PRINT_LOAD: print("loaded player pos: %s" % str(level.player_spawn_position))
	
	var tile_amount := file.get_32()
	if SaveLoad.PRINT_LOAD: print("tile count is %d" % tile_amount)
	for _i in tile_amount:
		level.tiles.set_bit(file.get_32(), file.get_32(), true)
	
	var key_amount := file.get_32()
	if SaveLoad.PRINT_LOAD: print("key count is %d" % key_amount)
	level.keys.resize(key_amount)
	for i in key_amount:
		level.keys[i] = _load_key(file)
	
	var door_amount := file.get_32()
	if SaveLoad.PRINT_LOAD: print("door count is %d" % door_amount)
	level.doors.resize(door_amount)
	assert(PerfManager.start("SaveLoadV1::load (loading doors)"))
	for i in door_amount:
		level.doors[i] = _load_door(file)
	assert(PerfManager.end("SaveLoadV1::load (loading doors)"))
	
	assert(PerfManager.end("SaveLoadV1::load"))
	return level

static func _load_key(file: FileAccess) -> KeyData:
	var key := KeyData.new()
	key.amount = _load_complex(file)
	key.position = Vector2i(file.get_32(), file.get_32())
	var type_and_color := file.get_8()
	key.color = type_and_color & 0b1111
	key.type = type_and_color >> 4
	
	return key

static func _load_door(file: FileAccess) -> DoorData:
	var door := DoorData.new()
	
	door.amount = _load_complex(file)
	door.position = Vector2i(file.get_32(), file.get_32())
	door.size = Vector2i(file.get_32(), file.get_32())
	
	var curses_color := file.get_8()
	# bits are, x1234444, 1 = ice, 2 = erosion, 3 = paint, 4 = color
	door.set_curse(Enums.curse.ice, curses_color & (1<<6) != 0)
	door.set_curse(Enums.curse.erosion, curses_color & (1<<5) != 0)
	door.set_curse(Enums.curse.paint, curses_color & (1<<4) != 0)
	door.outer_color = curses_color & 0b1111
	
	var lock_amount := file.get_16()
	door.locks.resize(lock_amount)
	for i in lock_amount:
		door.locks[i] = _load_lock(file)
	
	return door

static func _load_lock(file: FileAccess) -> LockData:
	var lock := LockData.new()
	lock.position = Vector2i(file.get_32(), file.get_32())
	lock.size = Vector2i(file.get_32(), file.get_32())
	lock.lock_arrangement = file.get_16()
	lock.magnitude = file.get_64()
	var bit_data := file.get_16()
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

static func _load_complex(file: FileAccess) -> ComplexNumber:
	return ComplexNumber.new_with(file.get_64(), file.get_64())

