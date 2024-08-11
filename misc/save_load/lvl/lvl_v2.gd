extends SaveLoadVersionLVL

# Differences from V1:
# store_var() and get_var(). Nothing else
# (originally, the big difference was that V1 used FileAccess, but that's been updated)

static func convert_dict(dict: Dictionary) -> Dictionary:
	# Nothing to do!
	return dict

static func load_from_dict(dict: Dictionary):
	return V3.load_from_dict(V3.convert_dict(dict))

static func load_from_bytes(raw_data: PackedByteArray, offset: int):
	var data := ByteAccess.new(raw_data, offset)
	var dict := load_level(data)
	return V3.load_from_dict(V3.convert_dict(dict))

static func load_level(data: ByteAccess) -> Dictionary:
	# V1 is the same, EXCEPT for the get_var() function.
	# But since we pass the newer ByteAccess with the V2 function, it works out.
	return V1.load_level(data)

class ByteAccess:
	extends V1.ByteAccess

	func store_var(v: Variant) -> void:
		# encode_var is weird. if it doesn't work, it returns -1, otherwise the used size
		var len := data.encode_var(curr, v)
		while len == -1:
			make_space(data.size())
			len = data.encode_var(curr, v)
		curr += len

	func get_var() -> Variant:
		var len := data.decode_var_size(curr)
		curr += len
		return data.decode_var(curr - len)
	
