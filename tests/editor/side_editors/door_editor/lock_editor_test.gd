# GdUnit generated TestSuite
class_name LockEditorTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from
const __source = 'res://editor/side_editors/door_editor/lock_editor.gd'

const LOCK_EDITOR = preload("res://editor/side_editors/door_editor/lock_editor.tscn")

## Tests the bug that makes locks with increased size not increase the size of the LockEditor.
func test_lock_size_bug() -> void:
	var editor: LockEditor = LOCK_EDITOR.instantiate()
	var lock_data := LockData.new()
	lock_data.size = Vector2i(18, 18)
	lock_data.color = Enums.colors.white
	editor.lock_data = lock_data
	add_child(editor)
	# This is just to try and catch when the scene changes, because it means the test might need to be updated accordingly.
	var lock_parent := editor.lock.get_parent()
	assert_object(lock_parent).is_instanceof(CenterContainer)
	
	# Wait a frame to let all the containers position their children
	# Technically unnecessary, but with this we check against the actual layout I guess
	await await_idle_frame()
	
	# We neither notify the lock that it should change or wait a frame for the lock to catch up - again, adjust the test if the way things work changes
	assert_float(lock_parent.size.x).is_greater_equal(18)
	assert_float(lock_parent.size.y).is_greater_equal(18)
	lock_data.size.y = 180
	await await_idle_frame()
	assert_float(lock_parent.size.x).is_greater_equal(18)
	assert_float(lock_parent.size.y).is_greater_equal(180)
	lock_data.size.x = 400
	await await_idle_frame()
	assert_float(lock_parent.size.x).is_greater_equal(400)
	assert_float(lock_parent.size.y).is_greater_equal(180)
	

