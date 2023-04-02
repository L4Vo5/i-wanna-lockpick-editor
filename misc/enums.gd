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

const color_names := {
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
