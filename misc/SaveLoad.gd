class_name SaveLoad

const PRINT_LOAD := true
const LATEST_FORMAT := 1
const V1 := preload("res://misc/saving_versions/save_load_v1.gd")

static func get_image(level: LevelData) -> Image:
	# Currently I'm not sure how to keep the advantages of the store_* and get_* functions without using FileAccess
#	var file := FileAccess.open("", FileAccess.WRITE_READ)
	var path := level.file_path
	var file := FileAccess.open(path, FileAccess.WRITE)
	V1.save_v1(level, file)
	file.close()
	
	file = FileAccess.open(path, FileAccess.READ)
	print(file.get_length())
	var data := file.get_buffer(file.get_length())
	var img := Image.new()
	var pixel_count := data.size() / 3 + 1
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
