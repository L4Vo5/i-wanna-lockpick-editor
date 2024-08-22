# GdUnit generated TestSuite
class_name GameplayManagerTest
extends GdUnitTestSuite
@warning_ignore('unused_parameter')
@warning_ignore('return_value_discarded')

# TestSuite generated from
const __source = 'res://level_elements/gameplay_manager.gd'
const GAMEPLAY = preload("res://level_elements/gameplay.tscn")

func test_no_goal_salvage_crash() -> void:
	const PATH := "res://tests/levels/bugs/no goal salvage crash.lvl"
	var pack_data: LevelPackData = SaveLoad.load_from_path(PATH)
	var gameplay := GAMEPLAY.instantiate()
	var pack_state := LevelPackStateData.make_from_pack_data(pack_data)
	add_child(gameplay)
	gameplay.load_level_pack(pack_data, pack_state)
	await gameplay.started_transition
