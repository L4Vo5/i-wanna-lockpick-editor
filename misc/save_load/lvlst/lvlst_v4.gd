extends SaveLoadVersionLVLST

const ByteAccess := SaveLoadVersionLVL.V4.ByteAccess
# pack state related functions
static func save(state: LevelPackStateData, raw_data: PackedByteArray, offset: int) -> void:
	var data := ByteAccess.new(raw_data, offset)
	
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
		save_door(data, door)
	
	data.compress()

static func load_from_bytes(raw_data: PackedByteArray, offset: int):
	return load_pack_state(raw_data, offset)

static func load_pack_state(raw_data: PackedByteArray, offset: int) -> LevelPackStateData:
	var data := ByteAccess.new(raw_data, offset)
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
			state.salvaged_doors[i] = load_door(data)
	
	return state

static func save_door(data: ByteAccess, door: DoorData) -> void:
	# In the current version:
	# Glitch color should always start as glitch
	# Doors can never start browned
	save_complex(data, door.amount)
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
		save_lock(data, lock)

static func save_lock(data: ByteAccess, lock: LockData) -> void:
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

static func save_complex(data: ByteAccess, n: ComplexNumber) -> void:
	data.store_s64(n.real_part)
	data.store_s64(n.imaginary_part)



static func load_door(data: ByteAccess) -> DoorData:
	var door := DoorData.new()
	
	door.amount = load_complex(data)
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
		door.locks[i] = load_lock(data)
	return door


static func load_lock(data: ByteAccess) -> LockData:
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
	lock.dont_show_lock = bit_data & 0b1 as bool
	bit_data >>= 1
	lock.color = bit_data & 0b1111
	bit_data >>= 4
	lock.lock_type = bit_data
	
	return lock

static func load_complex(data: ByteAccess) -> ComplexNumber:
	return ComplexNumber.new_with(data.get_s64(), data.get_s64())
