extends Resource
class_name LevelData

# has this level been loaded already? (no version check should be done)
var has_been_loaded := false
@export var version: String:
	set(val):
		version = val
		check_version()

@export var doors: Array[DoorData] = []
@export var keys: Array[KeyData] = []
@export var size := Vector2(800, 608)
signal changed_player_spawn_position
@export var player_spawn_position := Vector2(400, 304):
	set(val):
		if player_spawn_position == val: return
		player_spawn_position = val
		changed_player_spawn_position.emit()
		changed.emit()
@export var custom_lock_arrangements := {}
## Just saves all positions for the tiles... I'll come up with something better later ok
# It's a dict so it's not absurdly inefficient to check for repeats when placing new ones
@export var tiles := {}

func check_version() -> void:
	if has_been_loaded: return
	has_been_loaded = true
	
	print("Loading a level from version \"%s\"" % version)
	if version == "" or version == null:
		printerr("Why is this level being set to a null version?")
		breakpoint
		version = Global.game_version
	match version.naturalnocasecmp_to(Global.game_version):
		-1: # made in older version
			pass # currently unhandled
		0:
			pass
		1: # made in newer version
			Global.error_dialog.size = Vector2i(500, 200)
			Global.error_dialog.get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			Global.error_dialog.popup_centered()
			Global.error_dialog.dialog_text = \
"""This level was made in version %s.
You're on version %s.
There's currently no plan to try to handle this.
Please install the new version.
The application will now be closed.""" % [version, Global.game_version]
			await Global.error_dialog.visibility_changed
			Global.get_tree().quit()
