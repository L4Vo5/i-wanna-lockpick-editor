# GdUnit generated TestSuite
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')


func test_bigger_lock_bug() -> void:
	var gameplay_manager: GameplayManager = preload("res://level_elements/gameplay.tscn").instantiate()
	var pack_data := LevelPackData.get_default_level_pack()
	add_child(gameplay_manager)
	gameplay_manager.load_level_pack(pack_data)
	var level: Level = gameplay_manager.level
	
	print("adding door 1")
	var door_data_1 := DoorData.new()
	var lock_data_1 := LockData.new()
	lock_data_1.color = Enums.colors.white
	lock_data_1.size = Vector2i(20, 1000)
	door_data_1.size = Vector2i(32, 128)
	door_data_1.add_lock(lock_data_1)
	var door_1: Door = level.add_element(door_data_1, Enums.level_element_types.door)
	level.remove_element(door_1, Enums.level_element_types.door)
	
	print("adding door 2")
	var door_data_2 := DoorData.new()
	var lock_data_2 := LockData.new()
	lock_data_2.color = Enums.colors.white
	lock_data_2.size = Vector2i(20, 20)
	door_data_2.size = Vector2i(32, 32)
	door_data_2.add_lock(lock_data_2)
	var door_2: Door = level.add_element(door_data_2, Enums.level_element_types.door)
	var lock_2: Lock = door_2.lock_holder.get_child(0)
	var lock_2_size := lock_2.size
	assert_vector(lock_2_size).is_equal(Vector2(20, 20))
	assert_vector(Vector2i(lock_2_size)).is_equal(lock_2.lock_data.size)
	gameplay_manager.free()
