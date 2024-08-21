extends Node

func _ready() -> void:
	#SaveLoadVersionLVL.V5.schema_to_bits(SaveLoadVersionLVL.V5.SCHEMA, null, "LevelPackData", [], 0)
	var main_hub := SaveLoad.load_from_path("user://levels/main_hub.lvl")
	main_hub.file_path = "user://levels/main_hub v5 new.lvl"
	SaveLoad.save_level(main_hub)
