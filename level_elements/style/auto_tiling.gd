class_name AutoTiling

# Given a tile's position in the grid, returns the corresponding atlas_coords for that tile.
static func get_tile(tile_coord: Vector2i, level_data: LevelData) -> Vector2i:
	assert(PerfManager.start(&"AutoTiling::get_tile"))
	var level_width: int = level_data.size.x / 32
	var level_height: int = level_data.size.y / 32
	var tiles := level_data.tiles
	
	var bits := 0
	var vec: Vector2i
	for i in TILE_LOOKUP_ORDER.size():
		vec = TILE_LOOKUP_ORDER[i] + tile_coord
		if tiles.get(vec) or vec.x < 0 or vec.y < 0 or vec.x >= level_width or vec.y >= level_height:
			bits |= 1 << i
	assert(PerfManager.end(&"AutoTiling::get_tile"))
	return tiling_lookup[bits] 

# Internal stuff

const NEIGHBORS_ALL := [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1,  0),                  Vector2i(1,  0),
	Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1),
]
const NEIGHBORS_V := [Vector2i(0, -1), Vector2i(0, 1)]
const NEIGHBORS_H := [Vector2i(-1, 0), Vector2i(1, 0)]
const NEIGHBORS_U := [Vector2i(-1, -1), Vector2i( 0, -1), Vector2i( 1, -1)]
const NEIGHBORS_D := [Vector2i(-1,  1), Vector2i( 0,  1), Vector2i( 1,  1)]
const NEIGHBORS_L := [Vector2i(-1, -1), Vector2i(-1,  0), Vector2i(-1,  1)]
const NEIGHBORS_R := [Vector2i( 1, -1), Vector2i( 1,  0), Vector2i( 1,  1)]
const NEIGHBOR_U := [Vector2i( 0, -1)]
const NEIGHBOR_D := [Vector2i( 0,  1)]
const NEIGHBOR_L := [Vector2i(-1,  0)]
const NEIGHBOR_R := [Vector2i( 1,  0)]

const TILE_LOOKUP_ORDER: Array = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1,  0),                  Vector2i(1,  0),
	Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1),
]

static var tiling_lookup := create_tiling_lookup()

static func create_tiling_lookup() -> PackedVector2Array:
	var array := PackedVector2Array()
	array.resize(256)
	for i in 256:
		var what_tile := get_autotiling_tile_for_bits(i)
		array[i] = Vector2(what_tile)
	return array

static func count_tiles_bits(tiles: Array, bits: int) -> int:
	var count := 0
	var bit := 1
	for vec in TILE_LOOKUP_ORDER:
		if (bit & bits) != 0 and vec in tiles:
			count += 1
		bit *= 2
	return count

static func get_autotiling_tile_for_bits(bits: int) -> Vector2i:
	var what_tile := Vector2i(1,1)
	var all_count := count_tiles_bits(NEIGHBORS_ALL, bits)
	var h_count := count_tiles_bits(NEIGHBORS_H, bits)
	var v_count := count_tiles_bits(NEIGHBORS_V, bits)
	if all_count == 8:
		what_tile = Vector2i(0, 0)
	elif h_count == 2 and v_count != 2:
		what_tile = Vector2i(0, 1)
		if count_tiles_bits(NEIGHBOR_U, bits) == 1:
			if count_tiles_bits(NEIGHBORS_U, bits) != 3:
				what_tile = Vector2i(1, 1)
		if count_tiles_bits(NEIGHBOR_D, bits) == 1:
			if count_tiles_bits(NEIGHBORS_D, bits) != 3:
				what_tile = Vector2i(1, 1)
	elif v_count == 2 and h_count != 2:
		what_tile = Vector2i(1, 0)
		if count_tiles_bits(NEIGHBOR_L, bits) == 1:
			if count_tiles_bits(NEIGHBORS_L, bits) != 3:
				what_tile = Vector2i(1, 1)
		if count_tiles_bits(NEIGHBOR_R, bits) == 1:
			if count_tiles_bits(NEIGHBORS_R, bits) != 3:
				what_tile = Vector2i(1, 1)
	return what_tile
