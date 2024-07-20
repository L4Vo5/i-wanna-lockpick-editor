# GdUnit generated TestSuite
class_name LevelPropertiesEditorTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from
const __source = 'res://editor/side_editors/level_properties_editor/level_properties_editor.gd'
const LEVEL_PROPERTIES_EDITOR = preload("res://editor/side_editors/level_properties_editor/level_properties_editor.tscn")

var editor: LevelPropertiesEditor
var level_pack: LevelPackData

func before_test() -> void:
	editor = LEVEL_PROPERTIES_EDITOR.instantiate()
	add_child(editor)
	await await_idle_frame()

func test_add_level() -> void:
	editor._create_new_level()

func test_select_level() -> void:
	editor._set_level_number(0)

func test_change_level_properties() -> void:
	var lvl_name := "Level name!"
	var author := "Somebody"
	var title := "The First"
	var level := editor._level_data
	var size := Vector2i(32*121, 32*109)
	
	assert_str(level.name).is_not_equal(lvl_name)
	assert_str(level.author).is_not_equal(author)
	assert_str(level.title).is_not_equal(title)
	assert_vector(level.size).is_not_equal(size)
	
	editor.level_name.text = lvl_name
	editor.level_name.text_changed.emit(editor.level_name.text)
	assert_str(level.name).is_equal(lvl_name)
	
	editor.level_author.text = author
	editor.level_author.text_changed.emit(editor.level_author.text)
	assert_str(level.author).is_equal(author)
	
	editor.level_title.text = title
	editor.level_title.text_changed.emit(editor.level_title.text)
	assert_str(level.title).is_equal(title)
	
	editor.width.value = size.x
	assert_int(level.size.x).is_equal(size.x)
	editor.height.value = size.y
	assert_vector(level.size).is_equal(size)

# at the time of writing, this fails only on a standalone scene, not when testing the whole editor manually
func test_change_third_level_properties() -> void:
	editor._create_new_level()
	editor._create_new_level()
	editor._create_new_level()
	editor._set_level_number(2)
	var lvl_name := "Level name!"
	var author := "Somebody"
	var title := "The First"
	var level := editor._level_pack_data.get_level_by_position(2)
	var size := Vector2i(32*121, 32*109)
	
	assert_str(level.name).is_not_equal(lvl_name)
	assert_str(level.author).is_not_equal(author)
	assert_str(level.title).is_not_equal(title)
	assert_vector(level.size).is_not_equal(size)
	
	editor.level_name.text = lvl_name
	editor.level_name.text_changed.emit(editor.level_name.text)
	assert_str(level.name).is_equal(lvl_name)
	
	editor.level_author.text = author
	editor.level_author.text_changed.emit(editor.level_author.text)
	assert_str(level.author).is_equal(author)
	
	editor.level_title.text = title
	editor.level_title.text_changed.emit(editor.level_title.text)
	assert_str(level.title).is_equal(title)
	
	editor.width.value = size.x
	assert_int(level.size.x).is_equal(size.x)
	editor.height.value = size.y
	assert_vector(level.size).is_equal(size)

# now for the three bugs that prompted me to test this in the first place
func test_deleted_level_so_properties_changed() -> void:
	# [name, title, author, size (square)]
	var properties := [
		["First level", "1-1", "Me", 32*100],
		["SECOND level", "1-2", "Who knows", 32*103],
		["THIS IS THE THIRD", "1-3", "L4Vo6", 32*105]
	]
	var pack_data := editor._level_pack_data
	for i in properties.size():
		var props = properties[i]
		var lvl := LevelData.get_default_level()
		lvl.name = props[0]
		lvl.title = props[1]
		lvl.author = props[2]
		lvl.size = Vector2i.ONE * props[3]
		pack_data.add_level(lvl, i)
	pack_data.delete_level_by_position(3)
	editor._set_level_number(0)
	
	for arr in [[0, 1], [1, 2]]:
		var i: int = arr[0]
		var j: int = arr[1]
		var props_1: Array = properties[i]
		var props_2: Array = properties[j]
		assert_array(props_1).is_not_equal(props_2)
		assert_str(editor.level_name.text).is_equal(props_1[0])
		assert_str(editor.level_title.text).is_equal(props_1[1])
		assert_str(editor.level_author.text).is_equal(props_1[2])
		assert_float(editor.width.value).is_equal(props_1[3])
		assert_float(editor.height.value).is_equal(props_1[3])
		
		editor._delete_current_level()
		
		assert_str(editor.level_name.text).is_equal(props_2[0])
		assert_str(editor.level_title.text).is_equal(props_2[1])
		assert_str(editor.level_author.text).is_equal(props_2[2])
		assert_float(editor.width.value).is_equal(props_2[3])
		assert_float(editor.height.value).is_equal(props_2[3])

func test_delete_last_level() -> void:
	editor._create_new_level()
	editor._create_new_level()
	editor._set_level_number(0)
	editor._delete_current_level()
	editor._set_level_number(1)
	
	var levels := editor._level_pack_data.get_levels_ordered()
	assert_array(levels).has_size(2)
	var first_level := levels[0]
	var second_level := levels[1]
	assert_object(first_level).is_not_same(second_level)
	assert_object(editor._level_data).is_same(second_level)
	assert_object(editor._level_data).is_not_same(first_level)
	
	editor._delete_current_level()
	assert_object(editor._level_data).is_same(first_level)
	assert_object(editor._level_data).is_not_same(second_level)
	levels = editor._level_pack_data.get_levels_ordered()
	assert_array(levels).has_size(1)
	assert_object(levels[0]).is_same(first_level)

func test_delete_only_level() -> void:
	assert_array(editor._level_pack_data.get_levels_ordered())\
		.has_size(1)
	var level := editor._level_data
	editor._delete_current_level()
	assert_object(editor._level_data).is_not_same(level)

