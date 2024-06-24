extends RefCounted
class_name ByteAccess

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
	var bytes := data.slice(curr, curr + len)
	curr += len
	return bytes.get_string_from_utf8()

func get_bytes(size: int) -> PackedByteArray:
	var bytes := data.slice(curr, curr + size)
	curr += size
	return bytes
