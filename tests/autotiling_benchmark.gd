extends Node2D

@onready var gameplay: GameplayManager = $Gameplay

func _ready() -> void:
	var pack_data := LevelPackData.get_default_level_pack()
	var level_data := pack_data.levels[0]
	
	
	var SIZE := Vector2i(10000, 10000)
	var REPETITIONS := 20
	var densities = [0.1, 0.25, 0.5, 0.9]
	print("Level size: %s, Repetitions: %s" % [SIZE, REPETITIONS])
	gameplay.pack_data = pack_data
	print("Baseline: Default level size, no tiles")
	PerfManager.print_report(["Level::reset (tiles)"])
	
	for density: float in densities:
		randomize_tiles(level_data, density)
		for i in REPETITIONS:
			gameplay.pack_data = pack_data
		print("Normal level size, tile density %s%s" % [density * 100, "%"])
		PerfManager.print_report(["Level::reset (tiles)"])
	
	level_data.size = Vector2i(10000, 10000)
	for i in REPETITIONS:
		gameplay.pack_data = pack_data
	print("Big level, no tiles")
	PerfManager.print_report(["Level::reset (tiles)"])
	
	
	for density: float in densities:
		randomize_tiles(level_data, density)
		for i in REPETITIONS:
			gameplay.pack_data = pack_data
		print("Big level, tile density %s%s" % [density * 100, "%"])
		PerfManager.print_report(["Level::reset (tiles)"])
	

func randomize_tiles(level_data: LevelData, proportion: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for x in level_data.size.x/32:
		for y in level_data.size.y/32:
			var v := Vector2i(x, y)
			if rng.randf() < proportion:
				level_data.tiles[Vector2i(x, y)] = true
			else:
				level_data.tiles.erase(Vector2i(x, y))
