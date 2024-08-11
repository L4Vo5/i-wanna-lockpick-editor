extends SaveLoadVersion
class_name SaveLoadVersionLVL

const V1 := preload("res://misc/save_load/lvl/lvl_v1.gd")
const V2 := preload("res://misc/save_load/lvl/lvl_v2.gd")
const V3 := preload("res://misc/save_load/lvl/lvl_v3.gd")
const V4 := preload("res://misc/save_load/lvl/lvl_v4.gd")
const V5 := preload("res://misc/save_load/lvl/lvl_v5.gd")
static var CURRENT := V5
const LATEST_FORMAT := 5
static var VERSIONS: Dictionary = {
	1: V1,
	2: V2,
	3: V3,
	4: V4,
	5: V5,
}
