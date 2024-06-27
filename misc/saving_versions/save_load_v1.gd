## Fully converts V1 bytes into V3
static func convert_to_newer_version(data: ByteAccess, editor_version: String) -> PackedByteArray:
	const target_version := 3
	var new_data := SaveLoad.V3.make_byte_access([], 0)
	
	# initial structure common to all .lvl files
	new_data.store_u16(target_version)
	new_data.store_string(editor_version)
	
	# actual V1 data being turned to V3
	# level name and author saved as pack name and author
	new_data.store_string(data.get_string())
	new_data.store_string(data.get_string())
	# level count = 1
	new_data.store_u32(1)
	# level title + name
	new_data.store_string("\n")
	# level size
	new_data.store_u32(data.get_u32())
	new_data.store_u32(data.get_u32())
	# custom lock arrangements
	new_data.store_var(data.get_var())
	# goal pos, player spawn pos
	new_data.store_u32(data.get_u32())
	new_data.store_u32(data.get_u32())
	new_data.store_u32(data.get_u32())
	new_data.store_u32(data.get_u32())
	
	# tiles
	var tile_count := data.get_u32()
	new_data.store_u32(tile_count)
	for i in tile_count:
		# x and y of each tile
		new_data.store_u32(data.get_u32())
		new_data.store_u32(data.get_u32())
	
	# keys
	var key_count := data.get_u32()
	new_data.store_u32(key_count)
	for _i in key_count:
		_convert_key(data, new_data)
	
	# doors
	var door_count := data.get_u32()
	new_data.store_u32(door_count)
	for _i in door_count:
		_convert_door(data, new_data)
	
	# entries, of which there are zero
	new_data.store_u32(0)
	
	new_data.compress()
	return new_data.data

static func _convert_key(data: ByteAccess, new_data: SaveLoad.V3.ByteAccess) -> void:
	# key amount
	_convert_complex(data, new_data)
	# key position
	new_data.store_u32(data.get_u32())
	new_data.store_u32(data.get_u32())
	# pretty sure this byte can stay as-is? is_infinite should already be 0
	new_data.store_u8(data.get_u8())

static func _convert_door(data: ByteAccess, new_data: SaveLoad.V3.ByteAccess) -> void:
	# door amount
	_convert_complex(data, new_data)
	# position and size
	new_data.store_u32(data.get_u32())
	new_data.store_u32(data.get_u32())
	new_data.store_u32(data.get_u32())
	new_data.store_u32(data.get_u32())
	# pretty sure this byte can stay as-is? door curses
	new_data.store_u8(data.get_u8())
	var lock_count := data.get_u16()
	new_data.store_u16(lock_count)
	for _i in lock_count:
		_convert_lock(data, new_data)

static func _convert_lock(data: ByteAccess, new_data: SaveLoad.V3.ByteAccess) -> void:
	# position and size
	new_data.store_u32(data.get_u32())
	new_data.store_u32(data.get_u32())
	new_data.store_u32(data.get_u32())
	new_data.store_u32(data.get_u32())
	# lock arrangement and magnitude
	new_data.store_u16(data.get_u16())
	new_data.store_s64(data.get_s64())
	# pretty sure this can stay as-is? sign, value type, dont_show_lock, color, and lock_type
	new_data.store_u16(data.get_u16())

static func _convert_complex(data: ByteAccess, new_data: SaveLoad.V3.ByteAccess) -> void:
	new_data.store_s64(data.get_s64())
	new_data.store_s64(data.get_s64())

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
