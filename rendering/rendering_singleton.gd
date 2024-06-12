@tool
extends Node

const RENDERED_PATH := "res://rendering/doors_locks/rendered_textures/"
## Animation of special keys and doors (master, pure):
## length of the whole animation, and duration of each frame
const SPECIAL_ANIM_LENGTH := 0.8
const SPECIAL_ANIM_DURATION := 0.8 / 4.0

# Order: main, clear, dark
var frame_colors := generate_colors({
	Enums.sign.positive: ["584027", "84603C", "2C2014"],
	Enums.sign.negative: ["D8BFA7", "EBDFD3", "C49F7B"],
})
const frame_s_v := [
	[70.0 / 100.0, 90.0 / 100.0],
	[50.0 / 100.0, 100.0 / 100.0],
	[100.0 / 100.0, 75.0 / 100.0]
]
var i_view_palette := [
	Color.from_hsv(0, frame_s_v[0][0], frame_s_v[0][1]),
	Color.from_hsv(0, frame_s_v[1][0], frame_s_v[1][1]),
	Color.from_hsv(0, frame_s_v[2][0], frame_s_v[2][1]),
]
var salvage_point_input_color := Color.WHITE
var salvage_point_active_input_color := Color.WHITE
var salvage_point_output_color := Color.WHITE
var salvage_point_error_output_color := Color.WHITE


func _process(_delta: float) -> void:
		# PERF: use shader instead? it's way too inefficient to update a bunch of sprites each frame, right? ... is it?
	var i_view_hue := fmod((Global.time * 0.75 * 50.0) / 255.0, 1.0)
	i_view_palette[0] = Color.from_hsv(i_view_hue, Rendering.frame_s_v[0][0], Rendering.frame_s_v[0][1])
	i_view_palette[1] = Color.from_hsv(i_view_hue, Rendering.frame_s_v[1][0], Rendering.frame_s_v[1][1])
	i_view_palette[2] = Color.from_hsv(i_view_hue, Rendering.frame_s_v[2][0], Rendering.frame_s_v[2][1])
	
	var salvage_sat := 150.0 + 105 * sin(deg_to_rad(Global.time * 100))
	var salvage_error_sat := 150.0 + 105 * sin(deg_to_rad(Global.time * 300))
	salvage_sat /= 255.0
	salvage_error_sat /= 255.0
	salvage_point_input_color = Color.from_hsv(0.745, salvage_sat, 1)
	salvage_point_active_input_color = Color.from_hsv(0.333, salvage_sat, 1)
	salvage_point_output_color = Color.from_hsv(0.55, salvage_sat, 1)
	salvage_point_error_output_color = Color.from_hsv(0, salvage_error_sat, 1)

var lock_colors := {
	Enums.sign.positive: Color("2C2014"),
	Enums.sign.negative: Color("EBDFD3"),
}

# middle / light / dark
var color_colors := generate_colors({
#	Enums.colors.none: [],
#	Enums.colors.glitch: [],
	Enums.colors.black: ["363029", "554B40", "181512"],
	Enums.colors.white: ["D6CFC9", "EDEAE7", "BBAEA4"],
	Enums.colors.pink: ["CF709F", "E4AFCA", "AF3A75"],
	Enums.colors.orange: ["D68F49", "E7BF98", "9C6023"],
	Enums.colors.purple: ["8F5FC0", "BFA4DB", "603689"],
	Enums.colors.cyan: ["50AFAF", "8ACACA", "357575"],
	Enums.colors.red: ["8F1B1B", "C83737", "480D0D"],
	Enums.colors.green: ["359F50", "70CF88", "1B5028"],
	Enums.colors.blue: ["5F71A0", "8795B8", "3A4665"],
	Enums.colors.brown: ["704010", "AA6015", "382007"],
#	Enums.colors.pure: [],
#	Enums.colors.master: [],
#	Enums.colors.stone: [],
})

var key_colors := generate_colors({
#	Enums.colors.none: ,
#	Enums.colors.glitch: ,
	Enums.colors.black: "363029",
	Enums.colors.white: "D6CFC9",
	Enums.colors.pink: "CF709F",
	Enums.colors.orange: "D68F49",
	Enums.colors.purple: "8D5BBF",
	Enums.colors.cyan: "50AFAF",
	Enums.colors.red: "C83737",
	Enums.colors.green: "359F50",
	Enums.colors.blue: "5F71A0",
	Enums.colors.brown: "704010",
#	Enums.colors.pure: ,
#	Enums.colors.master: ,
#	Enums.colors.stone: ,
})

const key_number_colors: Array[Color] = [Color("EBE3DD"), Color("363029")]

static func generate_colors(from: Dictionary) -> Dictionary:
	var dict := {}
	for key in from.keys():
		if from[key] is Array:
			dict[key] = from[key].map(
				func(s: String):
					return Color(s)
			)
		else:
			dict[key] = Color(from[key])
	return dict

func get_lock_arrangement(level_data: LevelData, lock_count: int, option: int):
	# this function needs to be fast because it's just weird for this to take too long lmao. so no merging arrays anymore
	# ASSUMPTION: there's only one default arrangement per count
	if option <= -1: return null
	assert(PerfManager.start("Rendering::get_lock_arrangement"))
	var use_level := false
	if LOCK_ARRANGEMENTS.has(lock_count):
		if option > 0:
			use_level = true
			option -= 1
	else:
		use_level = true
	var options = level_data.custom_lock_arrangements.get(lock_count) if use_level and is_instance_valid(level_data) else LOCK_ARRANGEMENTS.get(lock_count)
	assert(PerfManager.end("Rendering::get_lock_arrangement"))
	if options == null or option >= options.size(): return null # remember option starts at 0 but size at 1
	return options[option]



# the keys are lock count with multiple arrays inside. each array corresponds to a lock arrangement
# a lock arrangement is [size, [lock_1_position, ...]]
# width and height will change lock_data's `size`
# each lock position is [position, angle]
# where angle is 0 to 15 and denotes the angle in 22.5° increments
const LOCK_ARRANGEMENTS := {
	1: [
		[Vector2i(18, 18), [[Vector2i(7, 7), 4]]]
	],
	2: [
		[Vector2i(18, 50), [[Vector2i(7, 13), 4], [Vector2i(7, 34), 12]]]
	],
	3: [
		[Vector2i(18, 50), [
		[Vector2i(7, 9), 2],
		[Vector2i(7, 23), 2],
		[Vector2i(7, 37), 2]]]
	],
	4: [
		[Vector2i(50, 50), [
		[Vector2i(13, 13), 2],
		[Vector2i(33, 13), 6],
		[Vector2i(33, 33), 10],
		[Vector2i(13, 33), 14]]]
	],
	5: [
		[Vector2i(50, 50), [
		[Vector2i(23, 11), 4],
		[Vector2i(11, 18), 1],
		[Vector2i(35, 18), 7],
		[Vector2i(32, 35), 10],
		[Vector2i(14, 35), 14]]]
	],
	6: [
		[Vector2i(50, 50), [
		[Vector2i(23, 10), 4],
		[Vector2i(11, 15), 1],
		[Vector2i(35, 15), 7],
		[Vector2i(11, 31), 15],
		[Vector2i(35, 31), 9],
		[Vector2i(23, 36), 12]]]
	],
	8: [
		[Vector2i(50, 50), [
		[Vector2i(23, 8), 4],
		[Vector2i(23, 38), 12],
		[Vector2i(8, 23), 0],
		[Vector2i(38, 23), 8],
		[Vector2i(13, 13), 2],
		[Vector2i(33, 13), 6],
		[Vector2i(13, 33), 14],
		[Vector2i(33, 33), 10]]]
	],
	12: [
		[Vector2i(50, 50), [
		[Vector2i(23, 8), 4],
		[Vector2i(23, 38), 12],
		[Vector2i(8, 23), 0],
		[Vector2i(38, 23), 8],
		[Vector2i(16, 16), 2],
		[Vector2i(30, 16), 6],
		[Vector2i(16, 30), 14],
		[Vector2i(30, 30), 10],
		[Vector2i(6, 6), 2],
		[Vector2i(40, 6), 6],
		[Vector2i(6, 40), 14],
		[Vector2i(40, 40), 10]]]
	],
	24: [
		[Vector2i(82, 82), [
		[Vector2i(39, 8), 4],
		[Vector2i(39, 24), 4],
		[Vector2i(39, 54), 12],
		[Vector2i(39, 70), 12],
		[Vector2i(8, 39), 0], 
		[Vector2i(24, 39), 0],
		[Vector2i(54, 39), 8],
		[Vector2i(70, 39), 8],
		[Vector2i(15, 15), 2],
		[Vector2i(29, 29), 2],
		[Vector2i(63, 15), 6],
		[Vector2i(49, 29), 6],
		[Vector2i(15, 63), 14],
		[Vector2i(29, 49), 14],
		[Vector2i(63, 63), 10],
		[Vector2i(49, 49), 10],
		[Vector2i(10, 26), 1],
		[Vector2i(68, 26), 7],
		[Vector2i(10, 52), 15],
		[Vector2i(68, 52), 9],
		[Vector2i(26, 10), 3],
		[Vector2i(52, 10), 5],
		[Vector2i(26, 68), 13],
		[Vector2i(52, 68), 11]]]
	],
}
