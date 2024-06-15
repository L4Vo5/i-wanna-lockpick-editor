static func save(level_pack: LevelPackData, data: ByteAccess) -> void:
	data.store_u16(SaveLoad.LATEST_FORMAT)
	level_pack.editor_version = Global.game_version
	data.store_string(level_pack.editor_version)
	data.store_string(level_pack.name)
	data.store_string(level_pack.author)
	
	data.store_u32(level_pack.levels.size())
	
	# Save all levels
	for level in level_pack.levels:
		_save_level(level, data)

static func _save_level(level: LevelData, data: ByteAccess) -> void:
	data.store_string(level.title + "\n" + level.name)
	data.store_u32(level.size.x)
	data.store_u32(level.size.y)
	data.store_var(level.custom_lock_arrangements)
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
		_save_key(data, key)
	# Doors
	data.store_u32(level.doors.size())
	for door in level.doors:
		_save_door(data, door)
	# Entries
	data.store_u32(level.entries.size())
	for entry in level.entries:
		_save_entry(data, entry)
	data.compress()

static func _save_key(data: ByteAccess, key: KeyData) -> void:
	_save_complex(data, key.amount)
	data.store_u32(key.position.x)
	data.store_u32(key.position.y)
	# color is 4 bytes, type is 3. is_infinite is 1. 8 bytes total
	# bits are: 01112222, 0 = is_infinite, 1 = type, 2 = color
	data.store_u8(((key.is_infinite as int) << 7) + (key.type << 4) + key.color)

static func _save_door(data: ByteAccess, door: DoorData) -> void:
	# In the current version:
	# Glitch color should always start as glitch
	# Doors can never start browned
	_save_complex(data, door.amount)
	data.store_u32(door.position.x)
	data.store_u32(door.position.y)
	data.store_u32(door.size.x)
	data.store_u32(door.size.y)
	# Curses take 3 bits. color takes 4 bits. 7 bits total
	# bits are, x1234444, 1 = ice, 2 = erosion, 3 = paint, 4 = color
	var curses := 0
	curses += 4 if door.get_curse(Enums.curse.ice) else 0
	curses += 2 if door.get_curse(Enums.curse.erosion) else 0
	curses += 1 if door.get_curse(Enums.curse.paint) else 0
	data.store_u8((curses << 4) + door.outer_color)
	data.store_u16(door.locks.size())
	for lock in door.locks:
		_save_lock(data, lock)

static func _save_lock(data: ByteAccess, lock: LockData) -> void:
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

static func _save_entry(data: ByteAccess, entry: EntryData) -> void:
	data.store_u32(entry.position.x)
	data.store_u32(entry.position.y)
	data.store_u32(entry.skin)
	data.store_u32(entry.leads_to)

static func _save_complex(data: ByteAccess, n: ComplexNumber) -> void:
	data.store_s64(n.real_part)
	data.store_s64(n.imaginary_part)

static func load(data: ByteAccess) -> LevelPackData:
	var level_pack := LevelPackData.new()
	level_pack.name = data.get_string()
	level_pack.author = data.get_string()
	if SaveLoad.PRINT_LOAD: print("Loading level pack %s by %s" % [level_pack.name, level_pack.author])
	
	var level_count := data.get_u32()
	
	# Load all levels
	if SaveLoad.PRINT_LOAD: print("It has %d levels" % level_count)
	for i in level_count:
		level_pack.levels.push_back(_load_level(data))
	return level_pack

static func _load_level(data: ByteAccess) -> LevelData:
	assert(PerfManager.start("SaveLoadV2::load"))
	var level := LevelData.new()
	var title_name := data.get_string().split("\n")
	assert(title_name.size() == 2)
	level.title = title_name[0]
	level.name = title_name[1]
	if SaveLoad.PRINT_LOAD: print("Loading level %s" % level.name)
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
	assert(PerfManager.start("SaveLoadV2::load (loading doors)"))
	for i in door_amount:
		level.doors[i] = _load_door(data)
	assert(PerfManager.end("SaveLoadV2::load (loading doors)"))
	
	var entry_amount := data.get_u32()
	if SaveLoad.PRINT_LOAD: print("entry count is %d" % entry_amount)
	level.entries.resize(entry_amount)
	for i in entry_amount:
		level.entries[i] = _load_entry(data)

	assert(PerfManager.end("SaveLoadV2::load"))
	return level

static func _load_key(data: ByteAccess) -> KeyData:
	var key := KeyData.new()
	key.amount = _load_complex(data)
	key.position = Vector2i(data.get_u32(), data.get_u32())
	var inf_type_color := data.get_u8()
	key.color = inf_type_color & 0b1111
	key.type = inf_type_color >> 4 & 0b111
	key.is_infinite = (inf_type_color >> 7) == 1
	
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
	door.connect_all_locks()
	return door

static func _load_entry(data: ByteAccess) -> EntryData:
	var entry := EntryData.new()
	entry.position = Vector2i(data.get_u32(), data.get_u32())
	entry.skin = data.get_u32()
	entry.leads_to = data.get_u32()
	return entry

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

class ByteAccess:
	extends RefCounted
	var data: PackedByteArray
	var curr := 0
	func _init(_data: PackedByteArray, _offset := 0) -> void:
		data = _data
		curr = _offset

	func seek(pos: int) -> void:
		curr = pos
	
	func get_position() -> int:
		return curr

	func compress() -> void:
		data.resize(curr)

	func make_space(how_much: int) -> void:
		if data.size() < 128:
			data.resize(128)
		while curr + how_much > data.size():
			data.resize(data.size() * 2)

	func store_u8(v: int) -> void:
		make_space(1)
		data.encode_u8(curr, v)
		curr += 1

	func store_s8(v: int) -> void:
		make_space(1)
		data.encode_s8(curr, v)
		curr += 1

	func store_u16(v: int) -> void:
		make_space(2)
		data.encode_u16(curr, v)
		curr += 2

	func store_s16(v: int) -> void:
		make_space(2)
		data.encode_s16(curr, v)
		curr += 2

	func store_u32(v: int) -> void:
		make_space(4)
		data.encode_u32(curr, v)
		curr += 4

	func store_s32(v: int) -> void:
		make_space(4)
		data.encode_s32(curr, v)
		curr += 4

	func store_s64(v: int) -> void:
		make_space(8)
		data.encode_s64(curr, v)
		curr += 8

	func store_var(v: Variant) -> void:
		#print("Storing var %s" % v)
		# encode_var is weird. if it doesn't work, it returns -1, otherwise the used size
		var len := data.encode_var(curr, v)
		while len == -1:
			make_space(data.size())
			len = data.encode_var(curr, v)
		#print("Encoded as %d bytes: %s" % [len, data.slice(curr, curr + len)])
		curr += len
	
	# Similar to FileAccess.store_pascal_string
	func store_string(s: String) -> void:
		var bytes := s.to_utf8_buffer()
		store_u32(bytes.size())
		# TODO / WAITING4GODOT: find a better way to store buffers
		for byte in bytes:
			store_u8(byte)

	func get_u8() -> int:
		curr += 1
		return data.decode_u8(curr - 1)

	func get_s8() -> int:
		curr += 1
		return data.decode_s8(curr - 1)

	func get_u16() -> int:
		curr += 2
		return data.decode_u16(curr - 2)

	func get_s16() -> int:
		curr += 2
		return data.decode_s16(curr - 2)

	func get_u32() -> int:
		curr += 4
		return data.decode_u32(curr - 4)

	func get_s32() -> int:
		curr += 4
		return data.decode_s32(curr - 4)

	func get_s64() -> int:
		curr += 8
		return data.decode_s64(curr - 8)

	func get_var() -> Variant:
		var len := data.decode_var_size(curr)
		#print("Decoding variant with %d bytes" % len)
		#print("The bytes are: %s" % data.slice(curr, curr + len))
		curr += len
		return data.decode_var(curr - len)
	
	# Similar to FileAccess.get_pascal_string
	func get_string() -> String:
		var len := get_u32()
		var bytes = data.slice(curr, curr + len)
		curr += len
		return bytes.get_string_from_utf8()

