extends Resource
class_name DoorData

## Contains a door's logical data


@export var real_amount := 1
@export var imaginary_amount := 0
@export var outer_color := Enums.color.none
@export var locks: Array[LockData] = []
@export var sequence_next: Array[DoorData] = []
@export var width := 1.0
@export var height := 1.0
