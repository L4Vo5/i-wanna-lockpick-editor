extends SaveLoadVersionLVL

static func load_from_bytes(raw_data: PackedByteArray, offset: int) -> LevelPackData:
	var data := ByteAccess.new(raw_data, offset)
	var dict := load_level(data)
	return V2.load_from_dict(V2.convert_dict(dict))

static func load_level(data: ByteAccess) -> Dictionary:
	var level := {}
	level["@class_name"] = &"LevelData"
	level["@inspect"] = ["keys", "doors"]
	level.name = data.get_string()
	level.author = data.get_string()
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
	return level

static func load_key(data: ByteAccess) -> Dictionary:
	var key := {}
	key["@class_name"] = &"KeyData"
	key.amount = load_complex(data)
	key.position = Vector2i(data.get_u32(), data.get_u32())
	var type_and_color := data.get_u8()
	key.color = type_and_color & 0b1111
	key.type = type_and_color >> 4
	
	return key

static func load_door(data: ByteAccess) -> Dictionary:
	var door := {}
	door["@class_name"] = &"DoorData"
	door["@inspect"] = ["locks"]
	
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
	door.locks = []
	door.locks.resize(lock_amount)
	for i in lock_amount:
		door.locks[i] = load_lock(data)
	return door

static func load_lock(data: ByteAccess) -> Dictionary:
	var lock := {}
	lock["@class_name"] = &"LockData"
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

static func load_complex(data: ByteAccess) -> Dictionary:
	return {
		_type = &"ComplexNumber",
		real_part = data.get_s64(),
		imaginary_part = data.get_s64(),
	}

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
	func store_bytes(bytes: PackedByteArray) -> void:
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
