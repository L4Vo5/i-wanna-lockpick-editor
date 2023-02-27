extends MarginContainer

@export var lock_data: LockData:
	set(val):
		if lock_data == val: return
		lock_data = val
		lock_data.changed.connect(generate_locks)
		if is_ready:
			generate_locks()
		else:
			call_deferred(&"generate_locks")

@onready var inner_color := %Color as ColorRect
@onready var frame := %Frame as NinePatchRect
@onready var locks_parent := %Locks as Node2D
@onready var lock_count_number := %LockCountDraw
@onready var lock_template := %LockTemplate as Sprite2D

@onready var is_ready := true

# OPTIMIZATION: Currently it takes about 2ms to draw the 24-lock variation, 1ms for the 8-lock. Just draw the locks manually instead of using nodes. Maybe same for the LockCountDraw: make it a static method or even just draw it in this class. Would make it not show properly if the number exceeds the box and it goes offscreen, but the number shouldn't exceed the box in the first place. 
func generate_locks() -> void:
	assert(lock_data == null or lock_data is LockData)
	position = lock_data.position
	size = lock_data.size
	frame.texture = DoorRendering.get_lock_frame_texture(lock_data.sign)
	inner_color.color = DoorRendering.color_colors[lock_data.color][0]
	for child in locks_parent.get_children():
		child.queue_free()
	match lock_data.lock_type:
		LockData.lock_types.normal:
			if not lock_data.dont_show_lock and lock_positions.has(lock_data.magnitude) and lock_positions[lock_data.magnitude].size() > lock_data.lock_arrangement:
				lock_count_number.hide()
				locks_parent.modulate = DoorRendering.lock_colors[lock_data.sign]
				var arrangement = lock_positions[lock_data.magnitude][lock_data.lock_arrangement]
				lock_data.size = Vector2(arrangement[0], arrangement[1])
				size = lock_data.size
				for lock_position in arrangement[2]:
					var lock := lock_template.duplicate() as Sprite2D
					lock.show()
					lock.frame = lock_position[2] + (3 if lock_data.value_type == Enums.value.imaginary else 0)
					lock.position = Vector2(lock_position[0], lock_position[1])
					lock.rotation_degrees = lock_position[3]
					if lock_position.size() == 5:
						lock.flip_h = lock_position[4]
					locks_parent.add_child(lock)
			else:
				lock_count_number.show()
				lock_count_number.text = str(lock_data.magnitude)
				lock_count_number.lock_type = 2 if lock_data.dont_show_lock else 0 if lock_data.value_type == Enums.value.real else 1 if lock_data.value_type == Enums.value.imaginary else 2


# the keys are lock count with multiple arrays inside. each array corresponds to a lock arrangement
# a lock arrangement is [width, height, [lock_1_position, ...]]
# width and height will change lock_data's `size`
# each lock position is [x, y, type, rotation_degrees, flip_h]
# type being 0 (straight) 1 (45°) 2 (the other weird angle). flip_h is optional, assumed to be false
const lock_positions := {
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
