class_name SaveLoad

const PRINT_LOAD := true
const LATEST_FORMAT := 4
const V1 := preload("res://misc/saving_versions/save_load_v1.gd")
const V2 := preload("res://misc/saving_versions/save_load_v2.gd")
const V3 := preload("res://misc/saving_versions/save_load_v3.gd")
const V4 := preload("res://misc/saving_versions/save_load_v4.gd")
## A reference to the current save/load version
const VC := V4
const LEVEL_EXTENSIONS := ["res", "tres", "lvl", "png"]

static func get_data(level_pack: LevelPackData) -> PackedByteArray:
	var data: PackedByteArray
	var byte_access := VC.make_byte_access([])
	VC.save(level_pack, byte_access)
	data = byte_access.data
	return data

static func get_image(level_pack: LevelPackData) -> Image:
	var data := get_data(level_pack)
	if data.size() == 0: return null
	var img := Image.new()
	
	# full color. alternatively, call image_to_b_w here (for some visual variety)
	var pixel_count := (data.size() + 2) / 3
	var image_size := (ceili(sqrt(pixel_count as float)))
	
	data.resize(image_size * image_size * 3)
	img.set_data(image_size, image_size, false, Image.FORMAT_RGB8, data)
	return img


static func load_from_image(image: Image) -> LevelPackData:
	image.convert(Image.FORMAT_RGB8)
	var data := image.get_data()
	var byte_access := VC.make_byte_access(data)
	var version := byte_access.get_u16()
	var editor_ver := byte_access.get_string()
	data = data.slice(byte_access.get_position())
	return load_from_buffer(data, byte_access.get_position(), version, editor_ver, "")

static func save_level(level_pack: LevelPackData) -> void:
	var path := level_pack.file_path
	if path.get_extension() == "lvl":
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(get_data(level_pack))
		print("saving to " + path)
		file.close()
	elif path.get_extension() == "png":
		var image := get_image(level_pack)
		path = level_pack.file_path.get_basename() + ".png"
		print("saving to " + path)
		var err := image.save_png(path)
		if err != OK:
			print("error saving image: " + str(err))

# Similar to load_from_buffer, but loads the entire file
static func load_from_file_buffer(buffer: PackedByteArray, path: String) -> LevelPackData:
	# Check png header
	if buffer.slice(0, 8).get_string_from_ascii() == "\u0089PNG\r\n\u001a\n":
		# Try loading as a png file
		var img := Image.new()
		var error := img.load_png_from_buffer(buffer)
		if error == OK:
			# Is a png file
			img.convert(Image.FORMAT_RGB8)
			buffer = img.get_data()
	var byte_access := VC.make_byte_access(buffer)
	var version := byte_access.get_u16()
	var original_editor_version := byte_access.get_string()
	return load_from_buffer(buffer, byte_access.get_position(), version, original_editor_version, path)

# Loads a .lvl file
# If read_only is true, only open for reading (cannot save afterwards)
static func load_from(path: String, read_only: bool = false) -> LevelPackData:
	var version: int = -1
	var original_editor_version := ""
	var buf: PackedByteArray
	
	# first, handle version 1 which is exceptional as it requires reading a file
	# the rest will be handled from a buffer
	if path.get_extension() == "lvl": # v1 can only be .lvl
		var file := FileAccess.open(path, FileAccess.READ)
		version = file.get_16()
		original_editor_version = file.get_pascal_string()
		if version == 1:
			var lvl_data: LevelData = V1.load(file)
			var lvl_pack_data = LevelPackData.make_from_level(lvl_data)
			finishing_touches(lvl_pack_data, path)
			
			return LevelPackData.make_from_level(lvl_pack_data)
		buf = file.get_buffer(file.get_length() - file.get_position())
	elif path.get_extension() == "png":
		var img := Image.load_from_file(path)
		var data := img.get_data()
		var byte_access := VC.make_byte_access(data)
		version = byte_access.get_u16()
		original_editor_version = byte_access.get_string()
		buf = data.slice(byte_access.get_position())
	
	if read_only:
		# is enough to prevent it from writing into it
		path = ""
	
	# with the buffer and V1 out of the way, we can load in a more generic way+
	return load_from_buffer(buf, 0, version, original_editor_version, path)

# data DOESN'T include version and original_editor_version
static func load_from_buffer(
	data: PackedByteArray,
	offset: int,
	version: int,
	original_editor_version: String, path: String) -> LevelPackData:
	if original_editor_version == "":
		original_editor_version = "Unknown (oops)"
	var lvl_pack_data: LevelPackData
	
	if PRINT_LOAD: print("Loading from %s. format version is %d. editor version was %s" % [path, version, original_editor_version])
	# Shouldn't be allowed to be version 1
	if version == 1:
		var error_text := \
"""Something terrible has happened!
A level with saving format 1 shouldn't reach this function...
If you're on the latest version, please report this."""
		Global.safe_error(error_text, Vector2i(700, 100))
		return null
	elif version == 2:
		var byte_access := V2.make_byte_access(data, offset)
		var lvl_data: LevelData = V2.load(byte_access)
		lvl_pack_data = LevelPackData.make_from_level(lvl_data)
	elif version == 3:
		var byte_access := V3.make_byte_access(data, offset)
		lvl_pack_data = V3.load(byte_access)
	elif version == 4:
		var byte_access := V4.make_byte_access(data, offset)
		lvl_pack_data = V4.load(byte_access)
	else:
		var error_text := \
"""This level was made in editor version %s and uses the saving format N°%d.
You're on version %s, which supports up to the saving format N°%d.
Consider updating the editor to a newer version.
Loading cancelled.""" % [original_editor_version, version, Global.game_version, LATEST_FORMAT]
		Global.safe_error(error_text, Vector2i(700, 100))
		return null
	
	# Now that it's imported, it'll save with the latest version
	finishing_touches(lvl_pack_data, path)
	return lvl_pack_data

static func finishing_touches(lvl_pack_data: LevelPackData, path: String) -> void:
	lvl_pack_data.editor_version = Global.game_version
	lvl_pack_data.file_path = path

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
