@tool
extends Node

@export var font_name := "fn_UT"
var gamemaker_fonts_path := ""
const GMS_font_extension := ".font.gmx"
const GMS_bitmap_extension := ".png"
const bitmap_extension := ".png"
const font_extension := ".fnt"
const fonts_path := "res://fonts/"

@export var convert_font: bool = false:
	set(val):
		if convert_font == val: return
		convert_font = val
		_convert()

func _ready() -> void:
	gamemaker_fonts_path = FileAccess.get_file_as_string(("res://meta/fonts_path.txt")).split("\n")[0]

func _convert():
	# Copy the .png file
#	var dir = Directory.new()
	print("Converting!")
	var err := DirAccess.copy_absolute(gamemaker_fonts_path.path_join(font_name + GMS_bitmap_extension), fonts_path.path_join(font_name + bitmap_extension))
	if err != 0:
		print("Error opening directory: " + str(err))
		return 0
	# Read the .font.gmx file
	var file := FileAccess.open(gamemaker_fonts_path.path_join(font_name + GMS_font_extension), FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	
	while (not FileAccess.file_exists(fonts_path.path_join(font_name + bitmap_extension))):
		await get_tree().process_frame
	var image := Image.new()
	image.load(fonts_path.path_join(font_name + bitmap_extension))
	var size = image.get_size()
	# Parse the content
	var new_content = font_gmx_to_fnt(content, size)
	
	print(new_content)
	# Write the .fnt file
	if not FileAccess.file_exists(fonts_path.path_join(font_name + font_extension)):
		print("Writing to " + font_name + font_extension)
		file = file.open(fonts_path.path_join(font_name + font_extension), FileAccess.WRITE)
		file.store_string(new_content)
		file.close()
		print("Content of " + font_name + " copied to clipboard!")
	else:
		# Just in case. I've had issues of .fnt files being emptied for some reason.
		print(font_name + font_extension + " already exists, copying to clipboard instead of updating")
	DisplayServer.clipboard_set(new_content)
	print("Done importing " + font_name + "!")

func string_from_to(string, start_substr: String, end_substr: String) -> String:
	var start = string.find(start_substr) + len(start_substr)
	var end = string.find(end_substr)
	return string.substr(start, end - start)

# Gets a number specifically formated as such:
# blabablblabla value="10" blablablalbal
# where blablabla is whatever. value is the second argument, and 10 is the returned number
func string_get_value(string, value):
	var start = string.find(" " + value + '="') + len(value) + 3
	var ret = string.substr(start)
	ret = ret.substr(0, ret.find('"'))
	return ret

func font_gmx_to_fnt(orig: String, texture_size: Vector2) -> String:
	var original := orig.split("\n", true)
	var result = ""
	
	var font_size
	var char_count = 0
	var char_list: String = ""
	for l in original:
		var line: String = l
		if "<size>" in line:
			font_size = string_from_to(line, "<size>", "</size>")
		if "<glyph " in line:
			char_count += 1
			var id = string_get_value(line, "character") 
			var x = string_get_value(line, "x")
			var y = string_get_value(line, "y")
			var w = string_get_value(line, "w")
			var h = string_get_value(line, "h")
			var shift = string_get_value(line, "shift")
			var offset = string_get_value(line, "offset")
			
			char_list += "char id=" + str(id) + " x=" + str(x) + " y=" + str(y)
			char_list += " width=" + str(w) + " height=" + str(h)
			char_list += " xoffset="+offset+" yoffset=0"
			char_list += " xadvance=" + str(shift)
			char_list += " page=0  chnl=15"
			char_list += "\n"
			
	result += "info "
	# result += "face=" + '"' + file_font_name + '" '
	result += "size=" + font_size + " "
	result += 'charset="ANSI" '
	result += "bold=0 italic=0 unicode=0 stretchH=100 smooth=0 aa=0 padding=0,0,0,0 spacing=1,1 outline=0"
	result += "\n"
	result += "common "
	result += "lineHeight=" + font_size + " base=16 scaleW=" + str(texture_size.x) + " scaleH="+ str(texture_size.y) +" pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4"
	result += "\n"
	result += "page id=0 file=" + '"' + font_name + bitmap_extension + '"'
	result += "\n"
	result += "chars count=" + str(char_count)
	result += "\n"
	result += char_list
	return result
	
