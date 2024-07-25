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

enum LockTypes {
	Normal,
	Blast,
	Blank, # will ignore value_type and sign_type
	All, # will ignore value_type and sign_type
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
