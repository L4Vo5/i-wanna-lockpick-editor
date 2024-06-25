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
	lock_data.color = Enums.colors.white
	editor.lock_data = lock_data
	add_child(editor)
	# This is just to try and catch when the scene changes, because it means the test might need to be updated accordingly.
	assert_object(editor.lock.get_parent()).is_instanceof(CenterContainer)
	
	assert_vector(editor.lock.get_parent().size)\
		.is_greater_equal(Vector2(lock_data.size))
	# We neither notify the lock that it should change or wait a frame - again, adjust the test if the way things work changes
	lock_data.size.y = 180
	assert_vector(editor.lock.get_parent().size)\
		.is_greater_equal(Vector2(lock_data.size))
	
	

