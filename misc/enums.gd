@tool
class_name Enums

# INT_MIN could be 1 less, but this way you can multiply both by -1 and it'll work out
const INT_MAX := 9223372036854775807
const INT_MIN := -9223372036854775807

# Tip: it's not properly documented in-engine, but named enums are actually dictionaries where the keys are the names and the values are the corresponding integers

enum Colors {
	None,
	White,
	Black,
	Orange,
	Purple,
	Cyan,
	Pink,
	Red,
	Green,
	Blue,
	Brown,
	Master,
	Pure,
	Glitch,
	Stone,
	Gate, # exclusive to doors, but locks can render it too for convenience
}

const COLOR_NAMES := {
	Colors.None: "none",
	Colors.White: "white",
	Colors.Black: "black",
	Colors.Orange: "orange",
	Colors.Purple: "purple",
	Colors.Cyan: "cyan",
	Colors.Pink: "pink",
	Colors.Red: "red",
	Colors.Green: "green",
	Colors.Blue: "blue",
	Colors.Brown: "brown",
	Colors.Master: "master",
	Colors.Glitch: "glitch",
	Colors.Pure: "pure",
	Colors.Stone: "stone",
	Colors.Gate: "gate",
}

# 0 shall be considered a positive number
enum Sign {
	Positive = 0,
	Negative = 1,
}

enum Value {
	Real = 0,
	Imaginary = 1
}

enum Curse {
	Ice, # 1 red
	Erosion, # 5 green
	Paint, # 3 blue
	Brown, # caused by 1 brown, cured by -1 brown
}

enum KeyTypes {
	Add, Exact,
	Star, Unstar,
	Flip, Rotor, RotorFlip
}
const KEY_TYPE_NAMES := {
	KeyTypes.Add: "add",
	KeyTypes.Exact: "exact",
	KeyTypes.Star: "star",
	KeyTypes.Unstar: "unstar",
	KeyTypes.Flip: "flip",
	KeyTypes.Rotor: "rotor",
	KeyTypes.RotorFlip: "rotor_flip",
}

enum LockTypes {
	Normal,
	Blast,
	Blank, # will ignore value_type and sign_type
	All, # will ignore value_type and sign_type
}
const LOCK_TYPE_NAMES := {
	LockTypes.Normal: "normal",
	LockTypes.Blast: "blast",
	LockTypes.Blank: "blank",
	LockTypes.All: "all",
}

enum LevelElementTypes {
	Door,
	Key,
	Entry,
	SalvagePoint,
	Tile,
	PlayerSpawn,
	Goal,
}

## The ones that are represtented by multiple nodes. (so not PlayerSpawn or Goal)
const NODE_LEVEL_ELEMENTS := [
	LevelElementTypes.Door,
	LevelElementTypes.Key,
	LevelElementTypes.Entry,
	LevelElementTypes.SalvagePoint
]
