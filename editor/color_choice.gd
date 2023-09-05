extends Control

const LOCK := preload("res://level_elements/doors_locks/lock.tscn")
# Called when the node enters the scene tree for the first time.
func _ready():
	var l := LOCK.instantiate()
	var ld := LockData.new()
	ld.dont_show_frame = true
	ld.color = Enums.colors.red
	l.lock_data = ld
	add_child(l)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
