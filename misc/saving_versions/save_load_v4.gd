const MAX_ARRAY_SIZE := 50_000_000

static func save(level_pack: LevelPackData, data: ByteAccess) -> void:
	data.store_string(level_pack.name)
	data.store_string(level_pack.author)
	data.store_s64(level_pack.pack_id)
	
	data.store_u32(level_pack.levels.size())
	
	# Save all levels
	for level_id in level_pack.level_order:
		var level: LevelData = level_pack.levels[level_id]
		data.store_u16(level_id)
		_save_level(level, data)
	
	data.compress()

static func _save_level(level: LevelData, data: ByteAccess) -> void:
	data.store_string(level.title + "\n" + level.name)
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
		_save_key(data, key)
	# Doors
	data.store_u32(level.doors.size())
	for door in level.doors:
		_save_door(data, door)
	# Entries
	data.store_u32(level.entries.size())
	for entry in level.entries:
		_save_entry(data, entry)
	# Salvage Points
	data.store_u32(level.salvage_points.size())
	for salvage_point in level.salvage_points:
		_save_salvage_point(data, salvage_point)

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
	curses += 4 if door.get_curse(Enums.Curse.Ice) else 0
	curses += 2 if door.get_curse(Enums.Curse.Erosion) else 0
	curses += 1 if door.get_curse(Enums.Curse.Paint) else 0
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
	data.store_u8(entry.skin)
	data.store_u16(entry.leads_to)

static func _save_salvage_point(data: ByteAccess, salvage_point: SalvagePointData) -> void:
	data.store_u32(salvage_point.position.x)
	data.store_u32(salvage_point.position.y)
	data.store_u8(1 if salvage_point.is_output else 0)
	data.store_s32(salvage_point.sid)

static func _save_complex(data: ByteAccess, n: ComplexNumber) -> void:
	data.store_s64(n.real_part)
	data.store_s64(n.imaginary_part)

static func load(raw_data: PackedByteArray, offset: int) -> LevelPackData:
	var data := make_byte_access(raw_data, offset)
	var level_pack := LevelPackData.new()
	level_pack.name = data.get_string()
	level_pack.author = data.get_string()
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
		level_pack.levels[id] = _load_level(data)
	return level_pack

static func _load_level(data: ByteAccess) -> LevelData:
	var level := LevelData.new()
	var title_name := data.get_string().split("\n")
	assert(title_name.size() == 2)
	level.title = title_name[0]
	level.name = title_name[1]
	if SaveLoad.PRINT_LOAD: print("Loading level %s" % level.name)
	level.size = Vector2i(data.get_u32(), data.get_u32())
	var flags := data.get_u8()
	if flags & 1:
		level.goal_position = Vector2i(data.get_u32(), data.get_u32())
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
		level.keys[i] = _load_key(data)
	
	var door_amount := data.get_u32()
	if SaveLoad.PRINT_LOAD: print("door count is %d" % door_amount)
	if door_amount > MAX_ARRAY_SIZE: return
	level.doors.resize(door_amount)
	for i in door_amount:
		if data.reached_eof(): return
		level.doors[i] = _load_door(data)
	
	var entry_amount := data.get_u32()
	if SaveLoad.PRINT_LOAD: print("entry count is %d" % entry_amount)
	if entry_amount > MAX_ARRAY_SIZE: return
	level.entries.resize(entry_amount)
	for i in entry_amount:
		if data.reached_eof(): return
		level.entries[i] = _load_entry(data)
	
	var salvage_point_amount := data.get_u32()
	if SaveLoad.PRINT_LOAD: print("salvage point count is %d" % salvage_point_amount)
	if salvage_point_amount > MAX_ARRAY_SIZE: return
	level.salvage_points.resize(salvage_point_amount)
	for i in salvage_point_amount:
		if data.reached_eof(): return
		level.salvage_points[i] = _load_salvage_point(data)

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
	door.set_curse(Enums.Curse.Ice, curses_color & (1<<6) != 0)
	door.set_curse(Enums.Curse.Erosion, curses_color & (1<<5) != 0)
	door.set_curse(Enums.Curse.Paint, curses_color & (1<<4) != 0)
	door.outer_color = curses_color & 0b1111
	
	var lock_amount := data.get_u16()
	if lock_amount > MAX_ARRAY_SIZE: return
	door.locks.resize(lock_amount)
	for i in lock_amount:
		if data.reached_eof(): return
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

static func _load_entry(data: ByteAccess) -> EntryData:
	var entry := EntryData.new()
	entry.position = Vector2i(data.get_u32(), data.get_u32())
	entry.skin = data.get_u8()
	entry.leads_to = data.get_u16()
	return entry

static func _load_salvage_point(data: ByteAccess) -> SalvagePointData:
	var salvage_point := SalvagePointData.new()
	salvage_point.position = Vector2i(data.get_u32(), data.get_u32())
	salvage_point.is_output = data.get_u8() != 0
	salvage_point.sid = data.get_s32()
	return salvage_point

static func _load_complex(data: ByteAccess) -> ComplexNumber:
	return ComplexNumber.new_with(data.get_s64(), data.get_s64())

# pack state related functions
static func save_pack_state(data: ByteAccess, state: LevelPackStateData) -> void:
	data.store_u16(SaveLoad.LATEST_FORMAT)
	data.store_string(Global.game_version)
	
	data.store_s64(state.pack_id)
	data.store_u32(state.current_level)
	var completed_level_count := state.completed_levels.size()
	data.store_u32(completed_level_count)
	for id in state.completed_levels:
		data.store_u16(id)
	
	data.store_u32(state.exit_levels.size())
	assert(state.exit_levels.size() == state.exit_positions.size())
	for id in state.exit_levels:
		data.store_u32(id)
	
	for vec in state.exit_positions:
		data.store_u32(vec.x)
		data.store_u32(vec.y)
	
	data.store_u32(state.salvaged_doors.size())
	for door in state.salvaged_doors:
		if door == null:
			data.store_u8(0)
			continue
		data.store_u8(1)
		_save_door(data, door)
	
	data.compress()

static func load_pack_state(data: ByteAccess) -> LevelPackStateData:
	var state := LevelPackStateData.new()
	state.pack_id = data.get_s64()
	
	state.current_level = data.get_u32()
	var completed_level_count := data.get_u32()
	if completed_level_count > MAX_ARRAY_SIZE: return
	
	for i in completed_level_count:
		if data.reached_eof(): return
		state.completed_levels[data.get_u16()] = true
	
	var exit_count := data.get_u32()
	state.exit_levels.resize(exit_count)
	state.exit_positions.resize(exit_count)
	for i in exit_count:
		if data.reached_eof(): return
		state.exit_levels[i] = data.get_u32()
	for i in exit_count:
		if data.reached_eof(): return
		state.exit_positions[i] = Vector2i(
			data.get_u32(),
			data.get_u32()
		)
	
	var salvage_count := data.get_u32()
	if salvage_count > MAX_ARRAY_SIZE: return
	state.salvaged_doors.resize(salvage_count)
	for i in salvage_count:
		if data.reached_eof(): return
		var salvage_exists := data.get_u8()
		if salvage_exists != 0:
			state.salvaged_doors[i] = _load_door(data)
	
	return state


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

	func store_bool(v: bool) -> void:
		make_space(1)
		data.encode_u8(curr, v)
		curr += 1

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
		store_bytes(bytes)

	# TODO / WAITING4GODOT: find a better way to store buffers
	func store_bytes(bytes: PackedByteArray) -> void:
		for byte in bytes:
			store_u8(byte)

	func reached_eof() -> bool:
		return curr >= data.size()
	
	func get_bool() -> bool:
		curr += 1
		return data.decode_u8(curr - 1)

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
		var bytes := data.slice(curr, curr + len)
		curr += len
		return bytes.get_string_from_utf8()

	func get_bytes(size: int) -> PackedByteArray:
		var bytes := data.slice(curr, curr + size)
		curr += size
		return bytes
