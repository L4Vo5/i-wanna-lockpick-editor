# GdUnit generated TestSuite
class_name ObjectGridChooserTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from
const __source = 'res://editor/property_editors/object_grid_chooser.gd'


func test_stuff() -> void:
	var obj := ObjectGridChooser.new()
	add_child(obj)
	var children := []
	for i in 10:
		children.push_back(Control.new())
		children[i].set_meta(&"i", i)
		obj.add_child(children[i])
	
	await await_idle_frame()
	assert_int(obj.selected_object.get_meta(&"i")).is_equal(0)
	children[0].hide()
	await await_idle_frame()
	assert_int(obj.selected_object.get_meta(&"i")).is_equal(1)
	children[0].show()
	await await_idle_frame()
	assert_int(obj.selected_object.get_meta(&"i")).is_equal(1)
	children[1].hide()
	await await_idle_frame()
	assert_int(obj.selected_object.get_meta(&"i")).is_equal(2)
	obj.selected_object = children[8]
	assert_int(obj.selected_object.get_meta(&"i")).is_equal(8)
	children[9].hide()
	await await_idle_frame()
	assert_int(obj.selected_object.get_meta(&"i")).is_equal(8)
	children[7].hide()
	await await_idle_frame()
	assert_int(obj.selected_object.get_meta(&"i")).is_equal(8)
	children[8].hide()
	await await_idle_frame()
	assert_int(obj.selected_object.get_meta(&"i")).is_equal(6)
	children[8].show()
	await await_idle_frame()
	assert_int(obj.selected_object.get_meta(&"i")).is_equal(6)
