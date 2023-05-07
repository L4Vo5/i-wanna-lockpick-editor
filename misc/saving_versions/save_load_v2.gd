#static func save_v2(level: LevelData, data: ByteAccess) -> void:
#	data.store_u16(level.num_version)
#	data.store_string(level.editor_version)
#	data.store_string(level.name)
#	data.store_string(level.author)
#	data.store_u32(level.size.x)
#	data.store_u32(level.size.y)
#	data.store_var(level.custom_lock_arrangements)
#	data.store_u32(level.goal_position.x)
#	data.store_u32(level.goal_position.y)
#	data.store_u32(level.player_spawn_position.x)
#	data.store_u32(level.player_spawn_position.y)
#	# Tiles
#	# Make sure there aren't *checks notes* 2^32 - 1, or, 4294967295 tiles. Meaning the level size is constrained to about, uh, 2097120x2097120
#	data.store_u32(level.tiles.size())
#	for key in level.tiles:
#		data.store_u32(key.x)
#		data.store_u32(key.y)
#	# Keys
#	data.store_u32(level.keys.size())
#	for key in level.keys:
#		_save_key(data, key)
#	# Doors
#	data.store_u32(level.doors.size())
#	for door in level.doors:
#		_save_door(data, door)
#
#static func _save_key(data: ByteAccess, key: KeyData) -> void:
#	_save_complex(data, key.amount)
#	data.store_u32(key.position.x)
#	data.store_u32(key.position.y)
#	# color is 4 bytes, type is 3. 7 bytes total
#	# bits are: 01112222, 1 = type, 2 = color
#	data.store_u8((key.type << 4) + key.color)
#
#static func _save_door(data: ByteAccess, door: DoorData) -> void:
#	# In the current version:
#	# Glitch color should always start as glitch
#	# Doors can never start browned
#	_save_complex(data, door.amount)
#	data.store_u32(door.position.x)
#	data.store_u32(door.position.y)
#	data.store_u32(door.size.x)
#	data.store_u32(door.size.y)
#	# Curses take 3 bits. color takes 4 bits. 7 bits total
#	# bits are, x1234444, 1 = ice, 2 = erosion, 3 = paint, 4 = color
#	var curses := 0
#	curses += 4 if door.get_curse(Enums.curse.ice) else 0
#	curses += 2 if door.get_curse(Enums.curse.erosion) else 0
#	curses += 1 if door.get_curse(Enums.curse.paint) else 0
#	data.store_u8((curses << 4) + door.outer_color)
#	data.store_u16(door.locks.size())
#	for lock in door.locks:
#		_save_lock(data, lock)
#
#static func _save_lock(data: ByteAccess, lock:LockData) -> void:
#	data.store_u32(lock.position.x)
#	data.store_u32(lock.position.y)
#	data.store_u32(lock.size.x)
#	data.store_u32(lock.size.y)
#	data.store_u16(lock.lock_arrangement)
#	data.store_s64(lock.magnitude)
#	# Sign takes 1 bit, value type takes 1, dont_show_lock takes 1. color takes 4. lock type is 2. 9 bits total :(
#	# bits are, 0000000112222345, 1 = lock type, 2 = color, 3 = dont show lock, 4 = value type, 5 = sign
#	var bit_data := 0
#	bit_data += lock.sign << 0
#	bit_data += lock.value_type << 1
#	bit_data += lock.dont_show_lock as int << 2
#	bit_data += lock.color << 3
#	bit_data += lock.lock_type << 7
#	data.store_u16(bit_data)
#
#static func _save_complex(data: ByteAccess, n: ComplexNumber) -> void:
#	data.store_s64(n.real_part)
#	data.store_s64(n.imaginary_part)
#
#class ByteAccess:
#	extends RefCounted
#	var data: PackedByteArray
#	var curr := 0
#	func _init(_data: PackedByteArray) -> void:
#		data = _data
#
#	func compress() -> void:
#		data.resize(curr)
#
#	func make_space(how_much: int) -> void:
#		if data.size() < 128:
#			data.resize(128)
#		while curr + how_much > data.size():
#			data.resize(data.size() * 2)
#
#	func store_u8(v: int) -> void:
#		make_space(1)
#		data.encode_u8(curr, v)
#		curr += 1
#
#	func store_s8(v: int) -> void:
#		make_space(1)
#		data.encode_s8(curr, v)
#		curr += 1
#
#	func store_u16(v: int) -> void:
#		make_space(2)
#		data.encode_u16(curr, v)
#		curr += 2
#
#	func store_s16(v: int) -> void:
#		make_space(2)
#		data.encode_s16(curr, v)
#		curr += 2
#
#	func store_u32(v: int) -> void:
#		make_space(4)
#		data.encode_u32(curr, v)
#		curr += 4
#
#	func store_s32(v: int) -> void:
#		make_space(4)
#		data.encode_s32(curr, v)
#		curr += 4
#
#	func store_s64(v: int) -> void:
#		make_space(8)
#		data.encode_s64(curr, v)
#		curr += 8
#
#	func store_var(v: Variant) -> void:
#		# encode_var is weird. if it doesn't work, it returns -1, otherwise the used size
#		var len := data.encode_var(curr, v)
#		while len == -1:
#			make_space(data.size())
#			len = data.encode_var(curr, v)
#		curr += len
#
#	func store_string(s: String) -> void:
#		store_var(s)
#
#	func get_u8() -> int:
#		curr += 1
#		return data.decode_u8(curr - 1)
#
#	func get_s8() -> int:
#		curr += 1
#		return data.decode_s8(curr - 1)
#
#	func get_u16() -> int:
#		curr += 2
#		return data.decode_u16(curr - 2)
#
#	func get_s16() -> int:
#		curr += 2
#		return data.decode_s16(curr - 2)
#
#	func get_u32() -> int:
#		curr += 4
#		return data.decode_u32(curr - 4)
#
#	func get_s32() -> int:
#		curr += 4
#		return data.decode_s32(curr - 4)
#
#	func get_s64() -> int:
#		curr += 8
#		return data.decode_s64(curr - 8)
#
#	func get_var() -> Variant:
#		var len := data.decode_var_size(curr)
#		curr += len
#		return data.decode_var(curr - len)
#
#	func get_string() -> String:
#		return get_var()
#
