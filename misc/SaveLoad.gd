class_name SaveLoad

const PRINT_LOAD := true
const LATEST_FORMAT := 1
const V1 := preload("res://misc/saving_versions/save_load_v1.gd")
const V2 := preload("res://misc/saving_versions/save_load_v2.gd")

static func get_image(level: LevelData) -> Image:
	# Currently it forcibly saves the .lvl file.
	# This should be changed when format is updated to 2.
	
	var path := level.file_path
	if path == "":
		# it's probably a built-in .res or .tres
		path = level.resource_path
		if path == "":
			return null
		
		ResourceSaver.save(level)
	else:
		var file := FileAccess.open(path, FileAccess.WRITE)
		V1.save_v1(level, file)
		file.close()
	
	var file := FileAccess.open(path, FileAccess.READ)
	var data := file.get_buffer(file.get_length())
	var img := Image.new()
	
	# full color
	# alternatively, call image_to_b_w here
	var pixel_count := (data.size() + 2) / 3
	var image_size := (ceili(sqrt(pixel_count as float)))
	
	data.resize(image_size*image_size*3)
	img.set_data(image_size, image_size, false, Image.FORMAT_RGB8, data)
	
	return img

		# Load image
#		var img := Image.load_from_file("user://test.png")
#		var new_file := FileAccess.open("invalid", FileAccess.WRITE_READ)
#		new_file.store_buffer(img.get_data())
#		new_file.seek(0)
#		file = new_file
#		file.get_16()
#		lvl_data = _load_v1(file)

static func save_level(level: LevelData) -> void:
	var path := level.file_path
	var file := FileAccess.open(path, FileAccess.WRITE)
	V1.save_v1(level, file)
	file.close()
	
	var image := get_image(level)
	path = level.file_path.get_basename() + ".png"
	print("saving to " + path)
	var err := image.save_png(path)
	if err != OK:
		print("error saving image: " + str(err))

static func load_from(path: String) -> LevelData:
	assert(PerfManager.start("SaveLoad::load_from"))
	var file := FileAccess.open(path, FileAccess.READ)
	var version := file.get_16()
	var lvl_data: LevelData
	var original_editor_version := file.get_pascal_string()
	if PRINT_LOAD: print("Loading from %s. format version is %d. editor version is %s" % [path, version, original_editor_version])
	if version == 1:
		lvl_data = V1.load_v1(file)
	else:
		var error_text := \
"""This level was made in editor version %s and uses the saving format N°%d.
You're on version %s, which supports up to the saving format %d.
Loading cancelled.""" % [original_editor_version, version, Global.game_version, LATEST_FORMAT]
		Global.safe_error(error_text, Vector2i(700, 100))
#		assert(false, "File is version %d, which is unsupported " % version)
		assert(PerfManager.end("SaveLoad::load_from"))
		return null
	# Now that it's imported, it'll save with the latest version
	lvl_data.num_version = LATEST_FORMAT
	lvl_data.editor_version = Global.game_version
	lvl_data.file_path = path
	assert(PerfManager.end("SaveLoad::load_from"))
	return lvl_data

static func load_from_image(image: Image) -> LevelData:
	assert(is_instance_valid(image))
	# Currently it forcibly saves the .lvl file.
	# This should be changed when format is updated to 2.
	
	
	var lvl_data: LevelData
	
	return lvl_data

func image_to_b_w(img: Image, data: PackedByteArray) -> void:
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
