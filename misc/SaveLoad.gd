class_name SaveLoad

const PRINT_LOAD := true
const LATEST_FORMAT := 1

static func get_image(level: LevelData) -> Image:
	# Currently I'm not sure how to keep the advantages of the store_* and get_* functions without using FileAccess
	var file := FileAccess.open("", FileAccess.WRITE_READ)
	_save_v1(level, file)
	
	var data := file.get_buffer(file.get_length())
	var img := Image.new()
	var pixel_count := data.size() / 3 + 1
	var image_size := (ceili(sqrt(pixel_count as float)))
	data.resize(image_size*image_size*3)
	img.set_data(image_size, image_size, false, Image.FORMAT_RGB8, data)
	
	return img


		# Load image
#		var img := Image.load_from_file("user://test.png")
#		var new_file := FileAccess.open("invalid", FileAccess.WRITE_READ)
#		new_file.store_buffer(img.get_data())
#		new_file.seek(0)
#		file = new_file
#		file.get_16()
#		lvl_data = _load_v1(file)

static func save_level(level: LevelData) -> void:
	var path := level.file_path
	var file := FileAccess.open(path, FileAccess.WRITE)
	_save_v1(level, file)

static func load_from(path: String) -> LevelData:
	var file := FileAccess.open(path, FileAccess.READ)
	var version := file.get_16()
	var lvl_data: LevelData
	var original_editor_version := file.get_pascal_string()
	if PRINT_LOAD: print("Loading from %s. format version is %d. editor version is %s" % [path, version, original_editor_version])
	if version == 1:
		lvl_data = _load_v1(file)
	else:
		var error_text := \
"""This level was made in editor version %s and uses the saving format N°%d.
You're on version %s, which supports up to the saving format %d.
Loading cancelled.""" % [original_editor_version, version, Global.game_version, LATEST_FORMAT]
		Global.safe_error(error_text, Vector2i(700, 100))
#		assert(false, "File is version %d, which is unsupported " % version)
		return null
	# Now that it's imported, it'll save with the latest version
	lvl_data.num_version = LATEST_FORMAT
	lvl_data.editor_version = Global.game_version
	lvl_data.file_path = path
	return lvl_data

static func _save_v1(level: LevelData, file: FileAccess) -> void:
	file.store_16(level.num_version)
	file.store_pascal_string(level.editor_version)
	file.store_pascal_string(level.name)
	file.store_pascal_string(level.author)
	file.store_32(level.size.x)
	file.store_32(level.size.y)
	file.store_var(level.custom_lock_arrangements)
	file.store_32(level.goal_position.x)
	file.store_32(level.goal_position.y)
	file.store_32(level.player_spawn_position.x)
	file.store_32(level.player_spawn_position.y)
	# Tiles
	# Make sure there aren't *checks notes* 2^32 - 1, or, 4294967295 tiles. Meaning the level size is constrained to about, uh, 2097120x2097120
	file.store_32(level.tiles.size())
	for key in level.tiles:
		file.store_32(key.x)
		file.store_32(key.y)
	# Keys
	file.store_32(level.keys.size())
	for key in level.keys:
		_save_key_v1(file, key)
	# Doors
	file.store_32(level.doors.size())
	for door in level.doors:
		_save_door_v1(file, door)
	

static func _save_key_v1(file: FileAccess, key: KeyData) -> void:
	_save_complex_v1(file, key.amount)
	file.store_32(key.position.x)
	file.store_32(key.position.y)
	# color is 4 bytes, type is 3. 7 bytes total
	# bits are: 01112222, 1 = type, 2 = color
	file.store_8((key.type << 4) + key.color)

static func _save_door_v1(file: FileAccess, door: DoorData) -> void:
	# In the current version:
	# Glitch color should always start as glitch
	# Doors can never start browned
	_save_complex_v1(file, door.amount)
	file.store_32(door.position.x)
	file.store_32(door.position.y)
	file.store_32(door.size.x)
	file.store_32(door.size.y)
	# Curses take 3 bits. color takes 4 bits. 7 bits total
	# bits are, x1234444, 1 = ice, 2 = erosion, 3 = paint, 4 = color
	var curses := 0
	curses += 4 if door.get_curse(Enums.curse.ice) else 0
	curses += 2 if door.get_curse(Enums.curse.erosion) else 0
	curses += 1 if door.get_curse(Enums.curse.paint) else 0
	file.store_8((curses << 4) + door.outer_color)
	file.store_16(door.locks.size())
	for lock in door.locks:
		_save_lock_v1(file, lock)

static func _save_lock_v1(file: FileAccess, lock:LockData) -> void:
	file.store_32(lock.position.x)
	file.store_32(lock.position.y)
	file.store_32(lock.size.x)
	file.store_32(lock.size.y)
	file.store_16(lock.lock_arrangement)
	file.store_64(lock.magnitude)
	# Sign takes 1 bit, value type takes 1, dont_show_lock takes 1. color takes 4. lock type is 2. 9 bits total :(
	# bits are, 0000000112222345, 1 = lock type, 2 = color, 3 = dont show lock, 4 = value type, 5 = sign
	var bit_data := 0
	bit_data += lock.sign << 0
	bit_data += lock.value_type << 1
	bit_data += lock.dont_show_lock as int << 2
	bit_data += lock.color << 3
	bit_data += lock.lock_type << 7
	file.store_16(bit_data)

static func _save_complex_v1(file: FileAccess, n: ComplexNumber) -> void:
	file.store_64(n.real_part)
	file.store_64(n.imaginary_part)

static func _load_v1(file: FileAccess) -> LevelData:
	var level := LevelData.new()
	level.name = file.get_pascal_string()
	level.author = file.get_pascal_string()
	level.size = Vector2i(file.get_32(), file.get_32())
	level.custom_lock_arrangements = file.get_var()
	level.goal_position = Vector2i(file.get_32(), file.get_32())
	level.player_spawn_position = Vector2i(file.get_32(), file.get_32())
	if PRINT_LOAD: print("loaded player pos: %s" % str(level.player_spawn_position))
	
	var tile_amount := file.get_32()
	if PRINT_LOAD: print("tile count is %d" % tile_amount)
	for _i in tile_amount:
		level.tiles[Vector2i(file.get_32(), file.get_32())] = true
	
	var key_amount := file.get_32()
	if PRINT_LOAD: print("key count is %d" % key_amount)
	level.keys.resize(key_amount)
	for i in key_amount:
		level.keys[i] = _load_key_v1(file)
	
	var door_amount := file.get_32()
	if PRINT_LOAD: print("door count is %d" % door_amount)
	level.doors.resize(door_amount)
	for i in door_amount:
		level.doors[i] = _load_door_v1(file)
	
	return level

static func _load_key_v1(file: FileAccess) -> KeyData:
	var key := KeyData.new()
	key.amount = _load_complex_v1(file)
	key.position = Vector2i(file.get_32(), file.get_32())
	var type_and_color := file.get_8()
	key.color = type_and_color & 0b1111
	key.type = type_and_color >> 4
	
	return key

static func _load_door_v1(file: FileAccess) -> DoorData:
	var door := DoorData.new()
	
	door.amount = _load_complex_v1(file)
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
		door.locks[i] = _load_lock_v1(file)
	
	return door

static func _load_lock_v1(file: FileAccess) -> LockData:
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

static func _load_complex_v1(file: FileAccess) -> ComplexNumber:
	return ComplexNumber.new_with(file.get_64(), file.get_64())
