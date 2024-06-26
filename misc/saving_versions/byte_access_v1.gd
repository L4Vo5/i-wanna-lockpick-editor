extends RefCounted
class_name ByteAccessV1

# byte access for save load v1

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
