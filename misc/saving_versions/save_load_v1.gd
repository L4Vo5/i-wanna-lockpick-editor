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
		var bytes := var_to_bytes(v)
		store_u32(bytes.size())
		store_bytes(bytes)

	# Similar to FileAccess.store_pascal_string
	func store_string(s: String) -> void:
		var bytes := s.to_utf8_buffer()
		store_u32(bytes.size())
		store_bytes(bytes)

	# TODO / WAITING4GODOT: find a better way to store buffers
	func store_bytes(data: PackedByteArray) -> void:
		for byte in data:
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
		var len := get_u32()
		return bytes_to_var(get_bytes(len))

	# Similar to FileAccess.get_pascal_string
	func get_string() -> String:
		var len := get_u32()
		var bytes := data.slice(curr, curr + len)
		curr += len
		return bytes.get_string_from_utf8()

	func get_bytes(size: int) -> PackedByteArray:
		var bytes := data.slice(curr, curr + size)
		curr += size
		return bytes
