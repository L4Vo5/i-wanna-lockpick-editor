# GdUnit generated TestSuite
class_name LevelPackDataTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from
const __source = 'res://data/level_pack_data.gd'

var pack_data: LevelPackData

func before_test() -> void:
	pack_data = LevelPackData.new()
	var levels_data := [
		[0, [0]],
		[1, [1, 2]],
		[2, [1]],
		[3, [1, 4, 4]],
		[4, [4, 0]],
	]
	pack_data.levels = make_levels_from_data(levels_data)
	verify_levels_integrity()

func test_duplicate_level() -> void:
	pack_data.duplicate_level(1) # label: 1
	set_level_data(2, "N", [1, 2])
	verify_levels_integrity()
	verify_level_labels([0, 1, "N", 2, 3, 4])
	pack_data.duplicate_level(4) # label: 3
	set_level_data(5, "O", [1, 4, 4])
	verify_levels_integrity()
	verify_level_labels([0, 1, "N", 2, 3, "O", 4])

func test_swap_levels() -> void:
	var swaps := [
		[0, 1], [0, 1], [1, 0], [1, 2], [0, 1],
		[0, 0], [3, 3], [2, 4], [3, 0], [4, 1],
	]
	var labels := [0, 1, 2, 3, 4]
	for swap in swaps:
		pack_data.swap_levels(swap[0], swap[1])
		var d = labels[swap[0]]
		labels[swap[0]] = labels[swap[1]]
		labels[swap[1]] = d
		verify_levels_integrity()
		verify_level_labels(labels)

@warning_ignore("unused_parameter")
func test_delete_level(data, test_parameters := [
	[[[3, 0], [3, 0], [2, 1], [1, 0], [0, 0]]],
	[[[4, 2], [1, 4], [2, 1], [1, 0]]],
	[[[1, 2]]],
	[[[2, 1]]],
]) -> void:
	var labels := [0, 1, 2, 3, 4]
	for deletion in data:
		var id_to_delete = deletion[0]
		var expected_invalid_entries = deletion[1]
		pack_data.delete_level(id_to_delete)
		verify_levels_integrity(expected_invalid_entries)
		labels.remove_at(deletion[0])
		verify_level_labels(labels)

func test_duplicate_delete_swap() -> void:
	# this test should be unnecessary, but whatever
	
	pack_data.duplicate_level(1)
	set_level_data(2, "N", [1, 2])
	verify_levels_integrity()
	verify_level_labels([0, 1, "N", 2, 3, 4])
	
	pack_data.delete_level(3)
	verify_levels_integrity(2)
	verify_level_labels([0, 1, "N", 3, 4])
	
	pack_data.swap_levels(0, 2)
	verify_levels_integrity(2)
	verify_level_labels(["N", 1, 0, 3, 4])
	
	var level := LevelData.new()
	for leads_to in [0, 2]:
		var entry := EntryData.new()
		entry.leads_to = leads_to
		level.entries.push_back(entry)
	pack_data.add_level(level)
	set_level_data(5, "E", ["N", 0])
	verify_levels_integrity(2)
	verify_level_labels(["N", 1, 0, 3, 4, "E"])
	
	pack_data.swap_levels(0, 1)
	verify_levels_integrity(2)
	verify_level_labels([1, "N", 0, 3, 4, "E"])
	
	pack_data.delete_level(1)
	verify_levels_integrity(2)
	verify_level_labels([1, 0, 3, 4, "E"])
	
	pack_data.delete_level(1)
	verify_levels_integrity(4)
	verify_level_labels([1, 3, 4, "E"])

# Array of "level data"
# where "level data" is [label, entries]
# label can be anything. entries is an array of labels it leads to
# this is used to initialize the array, so labels are integers and correspond to level id (i'm lazy to make a super complicated perfect system lol)
func make_levels_from_data(levels_data: Array) -> Array[LevelData]:
	var arr: Array[LevelData] = []
	for level_data in levels_data:
		var level := LevelData.new()
		level.set_meta("label", level_data[0])
		level.set_meta("self", level)
		for entry_goal in level_data[1]:
			var entry := EntryData.new()
			entry.leads_to = entry_goal
			entry.set_meta("leads_to_label", entry_goal)
			entry.set_meta("self", entry)
			level.entries.push_back(entry)
		arr.push_back(level)
	return arr

# sets level label, and points entries to the indicated labels (without modifying leads_to).
func set_level_data(level_id: int, label: Variant, leads_to: Array) -> void:
	var level := pack_data.levels[level_id]
	# in case duplicating levels keeps their meta (currently, it doesn't)
	if level.has_meta("self"):
		assert_object(level.get_meta("self")).is_not_same(level)
	level.set_meta("label", label)
	level.set_meta("self", level)
	assert_int(level.entries.size()).is_equal(leads_to.size())
	for i in level.entries.size():
		var entry := level.entries[i]
		var obj_label = leads_to[i]
		# in case duplicating entries keeps their meta (currently, it does)
		if entry.has_meta("self"):
			assert_object(entry.get_meta("self")).is_not_same(entry)
		entry.set_meta("leads_to_label", obj_label)
		entry.set_meta("self", entry)

func verify_levels_integrity(expected_invalid_entries := 0) -> void:
	var levels := pack_data.levels
	# check that there are no repeated labels
	var labels := {}
	for level in levels:
		assert_bool(level.has_meta("label")).is_true()
		var label = level.get_meta("label")
		assert_dict(labels).not_contains_same_keys([label])
		labels[label] = true
		assert_dict(labels).contains_same_keys([label])
		assert_object(level.get_meta("self")).is_same(level)
	# check every entry leads where it should
	var invalid_entries := 0
	for level in levels:
		for entry in level.entries:
			assert_object(entry.get_meta("self")).is_same(entry)
			var leads_to_label = entry.get_meta("leads_to_label")
			if entry.leads_to == -1:
				assert_bool(labels.has(leads_to_label)).is_false()
				invalid_entries += 1
			else:
				var l := levels[entry.leads_to]
				var label = l.get_meta("label")
				assert_that(label).is_equal(leads_to_label)
	assert_int(invalid_entries)\
		.append_failure_message(str(get_stack()[1]))\
		.is_equal(expected_invalid_entries)

func verify_level_labels(labels: Array) -> void:
	var levels := pack_data.levels
	for i in levels.size():
		var level := levels[i]
		assert_bool(level.has_meta("label")).is_true()
		assert_that(level.get_meta("label"))\
			.append_failure_message("i: %d. stack: " % i + str(get_stack()[1]))\
			.is_equal(labels[i])
