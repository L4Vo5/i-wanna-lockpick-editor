enum level_meta_category {
	_end = 0,
	custom_lock_arrangements = 1,
	tiles = 2,
	keys = 3,
	doors = 4,
	entries = 5,
	salvage_points = 6,
}

static func save(level_pack: LevelPackData, data: ByteWriter) -> void:
	data.store_16(SaveLoad.LATEST_FORMAT)
	level_pack.editor_version = Global.game_version
	data.store_pascal_string(level_pack.editor_version) # for compatibility
	data.store_64(level_pack.pack_id)
	data.store_string(level_pack.name)
	data.store_string(level_pack.author)
	
	data.store_uint(level_pack.levels.size())
	
	# Save all levels
	for level in level_pack.levels:
		_save_level(data, level)
	data.compress()

static func _save_level(data: ByteWriter, level: LevelData) -> void:
	data.store_string(level.title + "\n" + level.name)
	data.store_uint(level.size.x)
	data.store_uint(level.size.y)
	data.store_uint(level.goal_position.x)
	data.store_uint(level.goal_position.y)
	data.store_uint(level.player_spawn_position.x)
	data.store_uint(level.player_spawn_position.y)
	
	if not level.custom_lock_arrangements.is_empty():
		data.store_uint(level_meta_category.custom_lock_arrangements)
		data.store_var(level.custom_lock_arrangements)
	
	# Tiles
	# Did anyone talk about limitations? No more!
	if not level.tiles.is_empty():
		data.store_uint(level_meta_category.tiles)
		data.store_uint(level.tiles.size())
		for tile in level.tiles:
			data.store_uint(tile.x)
			data.store_uint(tile.y)
	# Keys
	if not level.keys.is_empty():
		data.store_uint(level_meta_category.keys)
		data.store_uint(level.keys.size())
		for key in level.keys:
			_save_key(data, key)
	# Doors
	if not level.doors.is_empty():
		data.store_uint(level_meta_category.doors)
		data.store_uint(level.doors.size())
		for door in level.doors:
			_save_door(data, door)
	# Entries
	if not level.entries.is_empty():
		data.store_uint(level_meta_category.entries)
		data.store_uint(level.entries.size())
		for entry in level.entries:
			_save_entry(data, entry)
	# Salvage Points
	if not level.salvage_points.is_empty():
		data.store_uint(level_meta_category.salvage_points)
		data.store_uint(level.salvage_points.size())
		for salvage_point in level.salvage_points:
			_save_salvage_point(data, salvage_point)
	data.store_uint(level_meta_category._end)

static func _save_key(data: ByteWriter, key: KeyData) -> void:
	data.store_uint(key.position.x)
	data.store_uint(key.position.y)
	_save_complex(data, key.amount)
	# color is 4 bits, type is 3. is_infinite is 1. 8 bits total
	# bits are: x1_2223333, 1 = is_infinite, 2 = type, 3 = color
	# kinda bad for leb128 but oh well
	data.store_uint(((key.is_infinite as int) << 7) + (key.type << 4) + key.color)

static func _save_door(data: ByteWriter, door: DoorData) -> void:
	data.store_uint(door.position.x)
	data.store_uint(door.position.y)
	data.store_uint(door.size.x)
	data.store_uint(door.size.y)
	# In the current version:
	# Glitch color should always start as glitch
	# Doors can never start browned
	_save_complex(data, door.amount)
	# Curses take 3 bits. color takes 4 bits. 7 bits total
	# bits are, x1234444, 1 = ice, 2 = erosion, 3 = paint, 4 = color
	var curses := 0
	curses += 4 if door.get_curse(Enums.curse.ice) else 0
	curses += 2 if door.get_curse(Enums.curse.erosion) else 0
	curses += 1 if door.get_curse(Enums.curse.paint) else 0
	data.store_uint((curses << 4) + door.outer_color)
	data.store_uint(door.locks.size())
	for lock in door.locks:
		_save_lock(data, lock)

static func _save_lock(data: ByteWriter, lock: LockData) -> void:
	data.store_uint(lock.position.x)
	data.store_uint(lock.position.y)
	data.store_uint(lock.size.x)
	data.store_uint(lock.size.y)
	data.store_uint(lock.lock_arrangement)
	data.store_int(lock.magnitude)
	# Sign takes 1 bit, value type takes 1, dont_show_lock takes 1. color takes 4. lock type is 2. 9 bits total :(
	# bits are, x12_3445555, 1 = dont show lock, 2 = value type, 3 = sign, 4 = lock type, 5 = color
	var bit_data := 0
	bit_data |= lock.color << 0
	bit_data |= lock.lock_type << 4
	bit_data |= lock.sign << 6
	bit_data |= lock.value_type << 7
	bit_data |= lock.dont_show_lock as int << 8
	data.store_uint(bit_data)

static func _save_entry(data: ByteWriter, entry: EntryData) -> void:
	data.store_uint(entry.position.x)
	data.store_uint(entry.position.y)
	data.store_uint(entry.skin)
	data.store_uint(entry.leads_to)

static func _save_salvage_point(data: ByteWriter, salvage_point: SalvagePointData) -> void:
	data.store_uint(salvage_point.position.x)
	data.store_uint(salvage_point.position.y)
	data.store_uint(salvage_point.is_output as int)
	data.store_uint(salvage_point.sid)

static func _save_complex(data: ByteWriter, n: ComplexNumber) -> void:
	data.store_int(n.real_part)
	data.store_int(n.imaginary_part)

static func load(data: ByteReader) -> LevelPackData:
	var level_pack := LevelPackData.new()
	level_pack.pack_id = data.get_s64()
	level_pack.name = data.get_string()
	level_pack.author = data.get_string()
	if SaveLoad.PRINT_LOAD: print("Loading level pack %s by %s" % [level_pack.name, level_pack.author])
	
	var level_count := data.get_uint()
	
	# Load all levels
	if SaveLoad.PRINT_LOAD: print("It has %d levels" % level_count)
	for i in level_count:
		level_pack.levels.push_back(_load_level(data))
	return level_pack

static func _load_level(data: ByteReader) -> LevelData:
	var level := LevelData.new()
	var title_name := data.get_string().split("\n")
	assert(title_name.size() == 2)
	level.title = title_name[0]
	level.name = title_name[1]
	if SaveLoad.PRINT_LOAD: print("Loading level %s" % level.name)
	level.size = Vector2i(data.get_uint(), data.get_uint())
	level.goal_position = Vector2i(data.get_uint(), data.get_uint())
	level.player_spawn_position = Vector2i(data.get_uint(), data.get_uint())
	if SaveLoad.PRINT_LOAD: print("loaded player pos: %s" % str(level.player_spawn_position))
	
	while true:
		var category: level_meta_category = data.get_uint()
		if category == level_meta_category._end:
			break
		elif category == level_meta_category.custom_lock_arrangements:
			level.custom_lock_arrangements = data.get_var()
		elif category == level_meta_category.tiles:
			var tile_amount := data.get_uint()
			for _i in tile_amount:
				level.tiles[Vector2i(data.get_uint(), data.get_uint())] = true
		elif category == level_meta_category.keys:
			var amount := data.get_uint()
			level.keys.resize(amount)
			for i in amount:
				level.keys[i] = _load_key(data)
		elif category == level_meta_category.doors:
			var amount := data.get_uint()
			level.doors.resize(amount)
			for i in amount:
				level.doors[i] = _load_door(data)
		elif category == level_meta_category.entries:
			var amount := data.get_uint()
			level.entries.resize(amount)
			for i in amount:
				level.entries[i] = _load_entry(data)
		elif category == level_meta_category.salvage_points:
			var amount := data.get_uint()
			level.salvage_points.resize(amount)
			for i in amount:
				level.salvage_points[i] = _load_salvage_point(data)
		else:
			assert(false, "Error, invalid category %d" % category)
	return level

static func _load_key(data: ByteReader) -> KeyData:
	var key := KeyData.new()
	key.position = Vector2i(data.get_uint(), data.get_uint())
	
	key.amount = _load_complex(data)
	var inf_type_color := data.get_uint()
	key.color = inf_type_color & 0b1111
	key.type = inf_type_color >> 4 & 0b111
	key.is_infinite = ((inf_type_color >> 7) & 0b1) == 1
	
	return key

static func _load_door(data: ByteReader) -> DoorData:
	var door := DoorData.new()
	door.position = Vector2i(data.get_uint(), data.get_uint())
	door.size = Vector2i(data.get_uint(), data.get_uint())
	
	door.amount = _load_complex(data)
	var curses_color := data.get_uint()
	# bits are, x1234444, 1 = ice, 2 = erosion, 3 = paint, 4 = color
	door.set_curse(Enums.curse.ice, curses_color & (1<<6) != 0)
	door.set_curse(Enums.curse.erosion, curses_color & (1<<5) != 0)
	door.set_curse(Enums.curse.paint, curses_color & (1<<4) != 0)
	door.outer_color = curses_color & 0b1111
	
	var lock_amount := data.get_uint()
	door.locks.resize(lock_amount)
	for i in lock_amount:
		door.locks[i] = _load_lock(data)
		door.locks[i].changed.connect(door.emit_changed)
	
	return door

static func _load_entry(data: ByteReader) -> EntryData:
	var entry := EntryData.new()
	entry.position = Vector2i(data.get_uint(), data.get_uint())
	entry.skin = data.get_uint()
	entry.leads_to = data.get_uint()
	return entry

static func _load_lock(data: ByteReader) -> LockData:
	var lock := LockData.new()
	lock.position = Vector2i(data.get_uint(), data.get_uint())
	lock.size = Vector2i(data.get_uint(), data.get_uint())
	lock.lock_arrangement = data.get_uint()
	lock.magnitude = data.get_int()
	var bit_data := data.get_uint()
	lock.color = bit_data & 0b1111
	bit_data >>= 4
	lock.lock_type = bit_data & 0b11
	bit_data >>= 2
	lock.sign = bit_data & 0b1
	bit_data >>= 1
	lock.value_type = bit_data & 0b1
	bit_data >>= 1
	lock.dont_show_lock = bit_data & 0b1
	
	return lock

static func _load_salvage_point(data: ByteReader) -> SalvagePointData:
	var salvage_point := SalvagePointData.new()
	salvage_point.position = Vector2i(data.get_uint(), data.get_uint())
	salvage_point.is_output = data.get_uint() == 1
	salvage_point.sid = data.get_uint()
	return salvage_point

static func _load_complex(data: ByteReader) -> ComplexNumber:
	return ComplexNumber.new_with(data.get_int(), data.get_int())

static func make_byte_reader(data: PackedByteArray, offset := 0) -> ByteReader:
	return ByteReader.new(data, offset)

static func make_byte_writer() -> ByteWriter:
	return ByteWriter.new()

class ByteReader:
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
	
	## Unsigned LEB128
	## Special case: 0x81 0x00 -> -1 for invalid entries / SIDs
	func get_uint() -> int:
		var value := 0
		var shift := 0
		while true:
			var b := data.decode_u8(curr)
			curr += 1
			if b < 128:
				if b != 0:
					return value | (b << shift)
				# special
				if value == 1:
					return -1
				return value
			value |= (b & 0x7F) << shift
			shift += 7
		return value
	
	func get_u8() -> int:
		curr += 1
		return data.decode_u8(curr - 1)
	
	func get_u16() -> int:
		curr += 2
		return data.decode_u16(curr - 2)
	
	func get_u32() -> int:
		curr += 4
		return data.decode_u32(curr - 4)
	
	func get_s32() -> int:
		curr += 4
		return data.decode_s32(curr - 4)
	
	func get_s64() -> int:
		curr += 8
		return data.decode_s64(curr - 8)
	
	## Signed LEB128
	## Special cases:
	##  0x81 0x00 -> Enums.INT_MAX (infinity)
	##  0x82 0x00 -> Enums.INT_MIN (-infinity)
	func get_int() -> int:
		var value := 0
		var shift := 0
		while true:
			var b := data.decode_u8(curr)
			curr += 1
			if b < 128:
				if b != 0:
					if b < 64:
						return value | (b << shift)
					# negative
					return value | ((b - 128) << shift)
				# special
				if value == 1:
					return Enums.INT_MAX
				if value == 2:
					return Enums.INT_MAX
				return value
			value |= (b & 0x7F) << shift
			shift += 7
		return value
	
	func get_var() -> Variant:
		var len := data.decode_var_size(curr)
		curr += len
		return data.decode_var(curr - len)
	
	func get_string() -> String:
		var len := get_uint()
		var bytes = data.slice(curr, curr + len)
		curr += len
		return bytes.get_string_from_utf8()
	
	# Similar to FileAccess.get_pascal_string
	func get_pascal_string() -> String:
		var len := get_u32()
		var bytes = data.slice(curr, curr + len)
		curr += len
		return bytes.get_string_from_utf8()

class ByteWriter:
	extends RefCounted
	var buffer: StreamPeerBuffer
	
	func _init() -> void:
		buffer = StreamPeerBuffer.new()
		buffer.resize(128)
	
	func get_data() -> PackedByteArray:
		return buffer.data_array
	
	func compress() -> void:
		buffer.resize(buffer.get_position())

	func make_space(how_much: int) -> void:
		var min = buffer.get_position() + how_much
		while min > buffer.get_size():
			buffer.resize(buffer.get_size() * 2)
	
	func store_8(value: int) -> void:
		make_space(1)
		buffer.put_8(value)
	
	func store_16(value: int) -> void:
		make_space(2)
		buffer.put_16(value)
	
	func store_32(value: int) -> void:
		make_space(4)
		buffer.put_32(value)
	
	func store_64(value: int) -> void:
		make_space(8)
		buffer.put_64(value)
	
	## Unsigned LEB128
	## Special case: 0x81 0x00 -> -1 for invalid entries / SIDs
	func store_uint(value: int) -> void:
		make_space(9) # at most 9 bytes (9 * 7 = 63 bits)
		if value == -1:
			buffer.put_8(0x81)
			buffer.put_8(0x00)
			return
		assert(value >= 0)
		while value >= 128:
			buffer.put_8((value & 0x7F) | 0x80)
			value >>= 7
		buffer.put_8(value)
	
	## Signed LEB128
	## Special cases:
	##  0x81 0x00 -> Enums.INT_MAX (infinity)
	##  0x82 0x00 -> Enums.INT_MIN (-infinity)
	func store_int(value: int) -> void:
		make_space(10) # at most 10 bytes (10 * 7 = 70 bits), 63 is not enough :(
		if value == Enums.INT_MAX:
			buffer.put_8(0x81)
			buffer.put_8(0x00)
			return
		if value == Enums.INT_MIN:
			buffer.put_8(0x82)
			buffer.put_8(0x00)
			return
		while value < -64 or value >= 64:
			buffer.put_8((value & 0x7F) | 0x80)
			value >>= 7
		buffer.put_8(value & 0x7F)
	
	func store_var(v: Variant) -> void:
		# damn, that also encodes the size, not what we want
		#buffer.put_var(v)
		var bytes := var_to_bytes(v)
		make_space(bytes.size())
		buffer.put_partial_data(bytes)
	
	func store_string(str: String) -> void:
		var bytes := str.to_utf8_buffer()
		store_uint(bytes.size())
		make_space(bytes.size())
		buffer.put_partial_data(bytes)
	
	func store_pascal_string(str: String) -> void:
		var bytes := str.to_utf8_buffer()
		store_32(bytes.size())
		make_space(bytes.size())
		buffer.put_partial_data(bytes)
