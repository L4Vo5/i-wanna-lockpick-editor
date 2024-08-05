class_name AutoTiling

# Given a tile's position in the grid, returns the corresponding atlas_coords for that tile.
static func get_tile(tile_coord: Vector2i, tile_type: int, level_data: LevelData) -> Vector2i:
	assert(PerfManager.start(&"AutoTiling::get_tile"))
	var level_width: int = level_data.size.x / 32
	var level_height: int = level_data.size.y / 32
	var tiles := level_data.tiles
	
	var bits := 0
	var vec: Vector2i
	for i in TILE_LOOKUP_ORDER.size():
		vec = TILE_LOOKUP_ORDER[i] + tile_coord
		if (tiles.has(vec) and (tiles[vec] as int) == tile_type) or vec.x < 0 or vec.y < 0 or vec.x >= level_width or vec.y >= level_height:
			bits |= 1 << i
	assert(PerfManager.end(&"AutoTiling::get_tile"))
	return tiling_lookups[tile_type][bits]

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

static var tiling_lookup_w1 := create_tiling_lookup_w1()
static var tiling_lookup_w6 := create_tiling_lookup_w6()

static var tiling_lookups := {
	1: tiling_lookup_w1, # world 1
	2: tiling_lookup_w1, # world 12
	3: tiling_lookup_w6, # world 6
}

static func create_tiling_lookup_w1() -> PackedVector2Array:
	var array := PackedVector2Array()
	array.resize(256)
	for i in 256:
		var what_tile := get_autotiling_tile_for_bits_w1(i)
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

static func get_autotiling_tile_for_bits_w1(bits: int) -> Vector2i:
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

# sorry, I couldn't find the pattern lol
static func create_tiling_lookup_w6() -> PackedVector2Array:
	return generic_create_lookup_base64("MzMjIzMzIyMyMmUiMjJlIjAwZGQwMCAgMTFRUjExUCEzMyMjMzMjIzIyZSIyMmUiMDBkZDAwICAxMVFSMTFQIQMDExMDAxMTVVUVJVVVFSVUVBQUVFQkJEFBQyZBQQZTAwMTEwMDExMCAgUSAgIFElRUFBRUVCQkQkI2YUJCVjQzMyMjMzMjIzIyZSIyMmUiMDBkZDAwICAxMVFSMTFQITMzIyMzMyMjMjJlIjIyZSIwMGRkMDAgIDExUVIxMVAhAwMTEwMDExNVVRUlVVUVJQAABAQAABAQQEAWRkBAYjUDAxMTAwMTEwICBRICAgUSAAAEBAAAEBABAWNEAQFFEQ==")

static func generic_create_lookup_base64(base64_str: String) -> PackedVector2Array:
	var bytes := Marshalls.base64_to_raw(base64_str)
	var array := PackedVector2Array()
	array.resize(256)
	for i in 256:
		array[i] = Vector2(bytes[i] & 0xF, bytes[i] >> 4)
	return array
