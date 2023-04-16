extends RefCounted
class_name EditorData

var level_data: LevelData

var is_playing := false
var disable_editing := false

# what's currently being edited
var tilemap_edit := false
var objects := false
var doors := false
var keys := false
var level_properties := false
