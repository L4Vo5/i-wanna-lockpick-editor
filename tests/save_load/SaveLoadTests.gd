# GdUnit generated TestSuite
class_name SaveLoadTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from
const __source = 'res://misc/SaveLoad.gd'


func test_versions() -> void:
	var base_path := "res://tests/save_load/levels/"
	var dirs := DirAccess.get_directories_at(base_path)
	assert_array(dirs).is_not_empty()
	for dir_name in dirs:
		assert_str(dir_name[0]).is_equal("v")
		assert_bool(dir_name.right(-1).is_valid_int()).is_true()
		var dir_version := dir_name.right(-1).to_int()
		assert_int(dir_version).is_greater_equal(1)
		var dir_path := base_path.path_join(dir_name)
		assert_array(DirAccess.get_directories_at(dir_path)).is_empty()
		var files := DirAccess.get_files_at(dir_path)
		assert_array(files).is_not_empty()
		for file_name in files:
			var file_path := dir_path.path_join(file_name)
			var pack_version := SaveLoad.get_version_from_path(file_path)
			var level_pack := SaveLoad.load_from_path(file_path)
			assert_object(level_pack).is_not_null()
			assert_int(pack_version)\
				.override_failure_message("Expected version %d but was %d for level %s" % [dir_version, pack_version, file_path])\
				.is_equal(dir_version)
			assert_str(level_pack.file_path)\
				.override_failure_message("File path should be '%s' but was '%s'" % [file_path, level_pack.file_path])\
				.is_equal(file_path)
			## Back and forth and back strategy as a saving test
			var data := SaveLoad.get_data(level_pack)
			var new_level_pack := SaveLoad.load_from_buffer(data, "")
			var new_data := SaveLoad.get_data(new_level_pack)
			assert_array(data)\
				.override_failure_message("Re-saving level causes different data")\
				.is_equal(new_data)
