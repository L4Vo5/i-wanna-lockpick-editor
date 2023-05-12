@tool
extends Node

const RENDERED_PATH := "res://rendering/doors_locks/rendered_textures/"
## Animation speed of special keys and doors (master, pure)
## This is how much each frame takes, not the speed at which they increase
const SPECIAL_ANIM_SPEED := 0.2

signal changed_special_anim_frame
var special_anim_frame := 0:
	set(val):
		if val == special_anim_frame: return
		special_anim_frame = val
		changed_special_anim_frame.emit()

func _physics_process(delta: float) -> void:
	special_anim_frame = floori(Global.time / SPECIAL_ANIM_SPEED) % 4

# Order: main, clear, dark
var frame_colors := generate_colors({
	Enums.sign.positive: ["584027", "84603C", "2C2014"],
	Enums.sign.negative: ["D8BFA7", "EBDFD3", "C49F7B"],
})
var frame_s_v := [
	[70.0 / 100.0, 90.0 / 100.0],
	[50.0 / 100.0, 100.0 / 100.0],
	[100.0 / 100.0, 75.0 / 100.0]
]

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

var key_number_colors: Array[Color] = [Color("EBE3DD"), Color("363029")]

func generate_colors(from: Dictionary) -> Dictionary:
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

func get_lock_arrangement(lock_count: int, option: int):
	if option <= -1: return null
	var level := Global.current_level
	var all_options := []
	# technically less efficient to merge the arrays... but by default, the first array will have only one element and the second not that many more, so it shouldn't be a problem
	if LOCK_ARRANGEMENTS.has(lock_count):
		all_options.append_array(LOCK_ARRANGEMENTS[lock_count])
	if is_instance_valid(level) and level.level_data.custom_lock_arrangements.has(lock_count):
		all_options.append_array(level.level_data.custom_lock_arrangements[lock_count])
	
	if option >= all_options.size(): return null # remember option starts at 0 but size at 1
	return all_options[option]
#	return fix_lock_arrangement(all_options[option])

#func fix_lock_arrangement(arrangement: Array) -> Array:
#	var arr = arrangement.duplicate(true)
#	for l in arr[2]:
#		# l[2] is type 
#		# l[3] is rotation
#		# l[4] is flip_h
#		# type: 4, 2, 1
#		var a = 0
#		a = [4, 2, 1][l[2]]
#		if l.size() == 5 and l[4]:
#			a = 8-a
#		a = ((a % 16) + 16) % 16
#		a += 4 * (l[3]/90)
#		a = ((a % 16) + 16) % 16
#		l[0] = Vector2i(l[0], l[1])
#		l[1] = a
#		l.resize(2)
#	arr[0] = Vector2i(arr[0], arr[1])
#	arr[1] = arr[2]
#	arr.resize(2)
##	print(arrangement)
#	return arr
#
#func _ready() -> void:
#	var new_arrangements := {}
#	for lock_amount in LOCK_ARRANGEMENTS.keys():
#		new_arrangements[lock_amount] = []
#		for arr in LOCK_ARRANGEMENTS[lock_amount]:
#			var new_arr := fix_lock_arrangement(arr)
#
#
#			new_arrangements[lock_amount].push_back(new_arr)
#	var str = "{"
#	str += "\n"
#	for key in new_arrangements.keys():
#		var arr = new_arrangements[key][0]
#		var amount = arr[1].size()
#		str += "	" + str(key) + ": [\n"
#
#		str += "		[" + str(arr[0]) + ", "
#		for l in arr[1]:
#			str += "" + str(l) + ", "
##			str += "["
##			str += str(l[0]) + ""
##			str += "]"
##			if amount > 0:
##				str += "\n"
#
#		str += "]\n	],\n"
#
#	str = str.replace("(", "Vector2i(")
#
#	str += "\n}"
#	print(str)
#	DisplayServer.clipboard_set(str)


# the keys are lock count with multiple arrays inside. each array corresponds to a lock arrangement
# a lock arrangement is [width, height, [lock_1_position, ...]]
# width and height will change lock_data's `size`
# each lock position is [x, y, type, rotation_degrees, flip_h]
# type being 0 (straight) 1 (45°) 2 (the other weird angle, 22.5°?). flip_h is optional, default false
# TODO: fix lock arrangements:
# [x, y, angle]
# where angle is 0 to 15 and denotes the angle in 22.5° increments
const LOCK_ARRANGEMENTS_OLD := {
	1: [
		[18, 18, [[7, 7, 0, 0]]]
	],
	2: [
		[18, 50, [
		[7, 13, 0, 0],
		[7, 34, 0, 180]]]
	],
	3: [
		[18, 50, [
		[7, 9, 1, 0], 
		[7, 23, 1, 0], 
		[7, 37, 1, 0]]]
	],
	4: [
		[50, 50, [
		[13, 13, 1, 0], 
		[33, 13, 1, 90], 
		[33, 33, 1, 180],
		[13, 33, 1, 270]]]
	],
	5: [
		[50, 50, [
		[23, 11, 0, 0], 
		[11, 18, 2, 0], 
		[35, 18, 2, 0, true],
		[32, 35, 1, 180],
		[14, 35, 1, 270]]]
	],
	6: [
		[50, 50, [
		[23, 10, 0, 0], 
		[11, 15, 2, 0], 
		[35, 15, 2, 0, true], 
		[11, 31, 2, 180, true], 
		[35, 31, 2, 180], 
		[23, 36, 0, 180]]]
	],
	8: [
		[50, 50, [
		[23, 8, 0, 0], 
		[23, 38, 0, 180], 
		[8, 23, 0, -90], 
		[38, 23, 0, 90], 
		[13, 13, 1, 0], 
		[33, 13, 1, 90], 
		[13, 33, 1, 270], 
		[33, 33, 1, 180], 
		]]
	],
	12: [
		[50, 50, [
		[23, 8, 0, 0], 
		[23, 38, 0, 180], 
		[8, 23, 0, -90], 
		[38, 23, 0, 90], 
		[16, 16, 1, 0], 
		[30, 16, 1, 90], 
		[16, 30, 1, 270], 
		[30, 30, 1, 180], 
		[6, 6, 1, 0], 
		[40, 6, 1, 90], 
		[6, 40, 1, 270], 
		[40, 40, 1, 180], 
		]]
	],
	24: [ # jeez
		[82, 82, [
		[39, 8, 0, 0], 
		[39, 24, 0, 0], 
		[39, 54, 0, 180], 
		[39, 70, 0, 180], 
		[8, 39, 0, -90], 
		[24, 39, 0, -90], 
		[54, 39, 0, 90], 
		[70, 39, 0, 90], 
		[15, 15, 1, 0], 
		[29, 29, 1, 0], 
		[63, 15, 1, 90], 
		[49, 29, 1, 90], 
		[15, 63, 1, 270], 
		[29, 49, 1, 270], 
		[63, 63, 1, 180], 
		[49, 49, 1, 180], 
		[10, 26, 2, 0, false], 
		[68, 26, 2, 0, true], 
		[10, 52, 2, 180, true], 
		[68, 52, 2, 180, false], 
		[26, 10, 2, 270, true], 
		[52, 10, 2, 90, false], 
		[26, 68, 2, 270, false], 
		[52, 68, 2, 90, true], 
		]]
	],
}

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
