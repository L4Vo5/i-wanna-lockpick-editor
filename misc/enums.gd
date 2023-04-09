@tool
class_name Enums

enum colors {
	none,
	white,
	black,
	orange,
	purple,
	cyan,
	pink,
	red,
	green,
	blue,
	brown,
	master,
	pure,
	glitch,
	stone,
}

const COLOR_NAMES := {
	colors.none: "none",
	colors.white: "white",
	colors.black: "black",
	colors.orange: "orange",
	colors.purple: "purple",
	colors.cyan: "cyan",
	colors.pink: "pink",
	colors.red: "red",
	colors.green: "green",
	colors.blue: "blue",
	colors.brown: "brown",
	colors.master: "master",
	colors.glitch: "glitch",
	colors.pure: "pure",
	colors.stone: "stone",
}

# 0 shall generally be considered positive
enum sign {
	positive,
	negative,
}

enum value {
	real,
	imaginary
}

enum curse {
	ice, # 1 red
	erosion, # 5 green
	paint, # 3 blue
	brown, # caused by 1 brown, cured by -1 brown
}

enum key_types {
	add, exact,
	star, unstar,
	flip, rotor, rotor_flip
}
const KEY_TYPE_NAMES := {
	key_types.add: "add",
	key_types.exact: "exact",
	key_types.star: "star",
	key_types.unstar: "unstar",
	key_types.flip: "flip",
	key_types.rotor: "rotor",
	key_types.rotor_flip: "rotor_flip",
}

enum lock_types {
	normal,
	blast,
	blank, # will ignore value_type and sign_type
	all, # will ignore value_type and sign_type
}
const LOCK_TYPE_NAMES := {
	lock_types.normal: "normal",
	lock_types.blast: "blast",
	lock_types.blank: "blank",
	lock_types.all: "all",
}
