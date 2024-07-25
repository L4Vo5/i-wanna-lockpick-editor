# GdUnit generated TestSuite
class_name KeyEditorTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from
const __source = 'res://editor/side_editors/key_editor/key_editor.gd'

var KEY_EDITOR := preload("res://editor/side_editors/key_editor/key_editor.tscn")

# Bug: Keys wouldn't be copied over properly when clicking them
func test_key_copying_bug() -> void:
	var key_editor: KeyEditor = KEY_EDITOR.instantiate()
	add_child(key_editor)
	var key_data := KeyData.new()
	key_data.amount.set_to(9, 9)
	key_data.type = Enums.KeyTypes.Exact
	key_data.is_infinite = true
	key_data.color = Enums.Colors.Purple
	await await_idle_frame()
	key_editor.data = key_data
	assert_int(key_editor.data.amount.real_part).is_equal(9)
	assert_int(key_editor.data.amount.imaginary_part).is_equal(9)
	assert_int(key_editor.data.color).is_equal(Enums.Colors.Purple)
	assert_int(key_editor.data.type).is_equal(Enums.KeyTypes.Exact)
	assert_int(key_editor.type_choice.selected_object.data.type).is_equal(Enums.KeyTypes.Exact)
	assert_bool(key_editor.data.is_infinite).is_true()
	key_data = KeyData.new()
	key_data.amount.set_to(-5, -5)
	key_editor.data = key_data
	assert_int(key_editor.data.amount.real_part).is_equal(-5)
	assert_int(key_editor.data.amount.imaginary_part).is_equal(-5)
	assert_int(key_editor.data.color).is_equal(Enums.Colors.White)
	assert_int(key_editor.data.type).is_equal(Enums.KeyTypes.Add)
	assert_int(key_editor.type_choice.selected_object.data.type).is_equal(Enums.KeyTypes.Add)
	assert_bool(key_editor.data.is_infinite).is_false()
	
	
