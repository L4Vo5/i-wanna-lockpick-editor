extends Resource
class_name DoorData

## Contains a door's logical data

# amount for every universe
@export var amount := [ComplexNumber.new_with(1, 0)]
@export var outer_color := Enums.color.none
@export var locks: Array[LockData] = []
@export var sequence_next: Array[DoorData] = []
@export var width := 1.0
@export var height := 1.0
