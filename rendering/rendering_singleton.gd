@tool
extends Node

const RENDERED_PATH := "res://rendering/doors_locks/rendered_textures/"
## Animation speed of special keys and doors (master, pure)
## This is how much each frame takes, not the speed at which they increase
const SPECIAL_ANIM_SPEED := 0.2

# Order: main, clear, dark
var frame_colors := generate_colors({
	Enums.sign.positive: ["584027", "84603C", "2C2014"],
	Enums.sign.negative: ["D8BFA7", "EBDFD3", "C49F7B"],
})

var lock_colors := {
	Enums.sign.positive: Color("2C2014"),
	Enums.sign.negative: Color("EBDFD3"),
}

# middle / light / dark
var color_colors := generate_colors({
#	Enums.color.none: [],
#	Enums.color.glitch: [],
	Enums.color.black: ["363029", "554B40", "181512"],
	Enums.color.white: ["D6CFC9", "EDEAE7", "BBAEA4"],
	Enums.color.pink: ["CF709F", "E4AFCA", "AF3A75"],
	Enums.color.orange: ["D68F49", "E7BF98", "9C6023"],
	Enums.color.purple: ["8F5FC0", "BFA4DB", "603689"],
	Enums.color.cyan: ["50AFAF", "8ACACA", "357575"],
	Enums.color.red: ["8F1B1B", "C83737", "480D0D"],
	Enums.color.green: ["359F50", "70CF88", "1B5028"],
	Enums.color.blue: ["5F71A0", "8795B8", "3A4665"],
	Enums.color.brown: ["704010", "AA6015", "382007"],
#	Enums.color.pure: [],
#	Enums.color.master: [],
#	Enums.color.stone: [],
})

var key_colors := generate_colors({
#	Enums.color.none: ,
#	Enums.color.glitch: ,
	Enums.color.black: "363029",
	Enums.color.white: "D6CFC9",
	Enums.color.pink: "CF709F",
	Enums.color.orange: "D68F49",
	Enums.color.purple: "8D5BBF",
	Enums.color.cyan: "50AFAF",
	Enums.color.red: "C83737",
	Enums.color.green: "359F50",
	Enums.color.blue: "5F71A0",
	Enums.color.brown: "704010",
#	Enums.color.pure: ,
#	Enums.color.master: ,
#	Enums.color.stone: ,
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
