class_name SaveLoad

const PRINT_LOAD := false
const LATEST_FORMAT := 4
const V1 := preload("res://misc/saving_versions/save_load_v1.gd")
const V2 := preload("res://misc/saving_versions/save_load_v2.gd")
const V3 := preload("res://misc/saving_versions/save_load_v3.gd")
const V4 := preload("res://misc/saving_versions/save_load_v4.gd")
const VERSIONS: Dictionary = {
	1: V1,
	2: V2,
	3: V3,
	4: V4
}
## A reference to the current save/load version
const VC := V4
const LEVEL_EXTENSIONS := ["res", "tres", "lvl", "png"]
static var LEVELS_PATH := ProjectSettings.globalize_path("user://levels/")

## Used for testing
static var _last_loaded_version := -1

## Given a LevelPack, gets the byte data to save it as the current format version.
static func get_data(level_pack: LevelPackData) -> PackedByteArray:
	var byte_access := VC.make_byte_access([])
	VC.save(level_pack, byte_access)
	return byte_access.data

## Given a LevelPack, gets the Image to save it as the current format version.
static func get_image(level_pack: LevelPackData) -> Image:
	var data := get_data(level_pack)
	var img := Image.new()
	
	# full color. alternatively, call image_to_b_w here (for some visual variety)
	var pixel_count := (data.size() + 2) / 3
	var image_size := (ceili(sqrt(pixel_count as float)))
	
	data.resize(image_size * image_size * 3)
	img.set_data(image_size, image_size, false, Image.FORMAT_RGB8, data)
	return img

static func is_path_valid(path: String) -> bool:
	if path == "": return false
	var globalized_path := ProjectSettings.globalize_path(path)
	return Global.danger_override or globalized_path.begins_with(LEVELS_PATH)

## Saves a LevelPackData to its file_path
static func save_level(level_pack: LevelPackData) -> void:
	var path := level_pack.file_path
	assert(is_path_valid(path))
	
	if path.get_extension() == "lvl":
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(get_data(level_pack))
		print("saving to " + path)
		file.close()
	elif path.get_extension() == "png":
		var image := get_image(level_pack)
		print("saving to " + path)
		var err := image.save_png(path)
		if err != OK:
			print("error saving image: " + str(err))
	else:
		assert(false)
	if not level_pack.is_pack_id_saved:
		level_pack.is_pack_id_saved = true
		level_pack.state_data.save()

static func load_and_check_pack_state_from_path(path: String, pack: LevelPackData) -> LevelPackStateData:
	return load_and_check_pack_state_from_buffer(FileAccess.get_file_as_bytes(path), pack)

static func load_and_check_pack_state_from_buffer(data: PackedByteArray, pack: LevelPackData) -> LevelPackStateData:
	# All versions must respect this initial structure
	var pack_id := data.decode_u64(8)
	if pack_id != pack.pack_id:
		return null
	var version := data.decode_u16(8)
	var len := data.decode_u32(10)
	var bytes := data.slice(14, 14 + len)
	var original_editor_version := bytes.get_string_from_utf8()
	if not VERSIONS.has(version):
		printerr("Invalid level pack state version: %d (%s)" % [version, original_editor_version])
		return null
	var load_script: Script = VERSIONS[version]
	var byte_access = load_script.make_byte_access(data)
	if not load_script.has_method(&"load_pack_state"):
		printerr("Version doesn't support pack states: %d (%s)" % [version, original_editor_version])
		return null
	var state_data: LevelPackStateData = load_script.load_pack_state(byte_access)
	state_data.pack_id = pack_id
	
	var expected_levels = pack.levels.size()
	var found_levels = state_data.completed_levels.size()
	if expected_levels != found_levels:
		print("completed_levels.size() != %s vs levels.size() = %s, resizing." % [found_levels, expected_levels])
		state_data.completed_levels.resize(expected_levels)
	return state_data

static func get_pack_state_data(state: LevelPackStateData) -> PackedByteArray:
	var byte_access = VC.make_byte_access([])
	VC.save_pack_state(byte_access, state)
	return byte_access.data

static func save_pack_state(state: LevelPackStateData) -> void:
	var path := state.file_path
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(get_pack_state_data(state))
	file.close()

## Loads a LevelPackData from a file path.
static func load_from_path(path: String) -> LevelPackData:
	if path.get_extension() == "png":
		return load_from_image(Image.load_from_file(path), path)
	elif path.get_extension() == "lvl":
		return load_from_buffer(FileAccess.get_file_as_bytes(path), path)
	else:
		assert(false)
		return null

## Loads a LevelPackData from the binary contents of a file.
## (which could require changes as png files can't be directly read as level data)
static func load_from_file_buffer(buffer: PackedByteArray, path: String) -> LevelPackData:
	# Check png header
	if buffer.slice(0, 8).get_string_from_ascii() == "\u0089PNG\r\n\u001a\n":
		# Get the correct buffer from png file
		var img := Image.new()
		var error := img.load_png_from_buffer(buffer)
		if error == OK:
			return load_from_image(img)
	return load_from_buffer(buffer, path)

## Loads a LevelPackData from an Image
static func load_from_image(image: Image, path := "") -> LevelPackData:
	image.convert(Image.FORMAT_RGB8)
	var data := image.get_data()
	return load_from_buffer(data, path)

## Loads a LevelPackData from a valid save buffer.
static func load_from_buffer(data: PackedByteArray, path: String) -> LevelPackData:
	# All versions must respect this initial structure
	var version := data.decode_u16(0)
	var len := data.decode_u32(2)
	var bytes := data.slice(6, 6 + len)
	var original_editor_version := bytes.get_string_from_utf8()
	
	if original_editor_version == "":
		original_editor_version = "Unknown (oops)"
	var offset := 6+len
	
	print("Loading from %s. format version is %d. editor version was %s" % [path, version, original_editor_version])
	print("hash is %d" % hash(data))
	
	_last_loaded_version = version
	if not VERSIONS.has(version):
		var error_text := \
	"""This level was made in editor version %s and uses the saving format N°%d.
	You're on version %s, which supports up to the saving format N°%d.
	Consider updating the editor to a newer version.
	Loading cancelled.""" % [original_editor_version, version, Global.game_version, LATEST_FORMAT]
		Global.safe_error(error_text, Vector2i(700, 100))
		return null
	var load_script: Script = VERSIONS[version]
	var byte_access = load_script.make_byte_access(data, offset)
	var lvl_pack_data: LevelPackData = load_script.load(byte_access)
	
	# Now that it's imported, it'll save with the latest version
	lvl_pack_data.editor_version = Global.game_version
	lvl_pack_data.file_path = path
	return lvl_pack_data

# fun
static func image_to_b_w(img: Image, data: PackedByteArray) -> void:
	var pixel_count := data.size() * 8
	var image_size := (ceili(sqrt(pixel_count as float)))
	var width := (image_size / 8) * 8
	var height := (pixel_count + width - 1) / width
	height *= 2
	width += width / 8 + 1
	var img_data: PackedByteArray = []
	img_data.resize(width * height * 3)
	var i := 0
	for byte in data:
		if (i / 3) % width == 0:
			for x in width:
				img_data[i + 0] = 128
				img_data[i + 1] = 128
				img_data[i + 2] = 128
				i += 3
		img_data[i + 0] = 128
		img_data[i + 1] = 128
		img_data[i + 2] = 128
		i += 3
		for j in 8:
			if byte & 1 == 1:
				img_data[i + 0] = 255
				img_data[i + 1] = 255
				img_data[i + 2] = 255
			byte >>= 1
			i += 3
		if (i / 3) % width == width - 1:
			img_data[i + 0] = 128
			img_data[i + 1] = 128
			img_data[i + 2] = 128
			i += 3
		
	img.set_data(width, height, false, Image.FORMAT_RGB8, img_data)
