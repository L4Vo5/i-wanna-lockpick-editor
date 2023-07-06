class_name SaveLoad

const PRINT_LOAD := true
const LATEST_FORMAT := 2
const V1 := preload("res://misc/saving_versions/save_load_v1.gd")
const V2 := preload("res://misc/saving_versions/save_load_v2.gd")
const VC := V2
const LEVEL_EXTENSIONS := ["res", "tres", "lvl", "png"]

static func get_data(level: LevelData) -> PackedByteArray:
	var path := level.file_path
	var data: PackedByteArray
	# SHOULDN'T SUPPORT THIS. it makes loading images/data ambiguous!
#	if path == "":
#		# it's probably a built-in .res or .tres
#		path = level.resource_path
#		if path == "" or not path.get_extension() in ["res", "tres"]:
#			return []
#		ResourceSaver.save(level)
#		var file := FileAccess.open(path, FileAccess.READ)
#		data = file.get_buffer(file.get_length())
#	else:
	var byte_access := VC.make_byte_access([])
	VC.save(level, byte_access)
	data = byte_access.data
	return data

static func get_image(level: LevelData) -> Image:
	var data := get_data(level)
	if data.size() == 0: return null
	var img := Image.new()
	
	# full color. alternatively, call image_to_b_w here (for some visual variety)
	var pixel_count := (data.size() + 2) / 3
	var image_size := (ceili(sqrt(pixel_count as float)))
	
	data.resize(image_size * image_size * 3)
	img.set_data(image_size, image_size, false, Image.FORMAT_RGB8, data)
	return img


static func load_from_image(image: Image) -> LevelData:
	image.convert(Image.FORMAT_RGB8)
	var data := image.get_data()
	var byte_access := VC.make_byte_access(data)
	var version := byte_access.get_u16()
	var editor_ver := byte_access.get_string()
	data = data.slice(byte_access.get_position())
	return load_from_buffer(data, version, editor_ver, "")

static func save_level(level: LevelData) -> void:
	var path := level.file_path
	if path.get_extension() == "lvl":
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(get_data(level))
		print("saving to " + path)
		file.close()
	elif path.get_extension() == "png":
		var image := get_image(level)
		path = level.file_path.get_basename() + ".png"
		print("saving to " + path)
		var err := image.save_png(path)
		if err != OK:
			print("error saving image: " + str(err))

# Loads a .lvl file
static func load_from(path: String) -> LevelData:
	var lvl_data: LevelData = null
	
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
			lvl_data = V1.load(file)
			finishing_touches(lvl_data, path)
			return lvl_data
		buf = file.get_buffer(file.get_length() - file.get_position())
	elif path.get_extension() == "png":
		var img := Image.load_from_file(path)
		var data := img.get_data()
		var byte_access := VC.make_byte_access(data)
		version = byte_access.get_u16()
		original_editor_version = byte_access.get_string()
		buf = data.slice(byte_access.get_position())
	
	# with the buffer and V1 out of the way, we can load in a more generic way
	return load_from_buffer(buf, version, original_editor_version, path)

# data DOESN'T include version and original_editor_version
static func load_from_buffer(
	data: PackedByteArray,
	version: int,
	original_editor_version: String, path: String) -> LevelData:
	var lvl_data: LevelData
	
	if PRINT_LOAD: print("Loading from %s. format version is %d. editor version is %s" % [path, version, original_editor_version])
	# Shouldn't be allowed to be version 1
	if version == 1:
		var error_text := \
"""Something terrible has happened!
A level with saving format 1 shouldn't reach this function...
If you're on the latest version, please report this."""
		Global.safe_error(error_text, Vector2i(700, 100))
		return null
	elif version == 2:
		var byte_access := V2.make_byte_access(data)
		lvl_data = V2.load(byte_access)
	else:
		var error_text := \
"""This level was made in editor version %s and uses the saving format N°%d.
You're on version %s, which supports up to the saving format N°%d.
Consider updating the editor to a newer version.
Loading cancelled.""" % [original_editor_version, version, Global.game_version, LATEST_FORMAT]
		Global.safe_error(error_text, Vector2i(700, 100))
		return null
	
	# Now that it's imported, it'll save with the latest version
	finishing_touches(lvl_data, path)
	return lvl_data

static func finishing_touches(lvl_data: LevelData, path: String) -> void:
	lvl_data.editor_version = Global.game_version
	lvl_data.file_path = path

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
