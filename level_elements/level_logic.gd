extends Node2D
class_name LevelLogic
## A Level will leverage this object to try to handle the logic side of things
## This alleviates responsibilities for the Level and for the ..Data objects.
## And also serves as a central place where most of the core mechanics reside.

## The LevelData it should refer to
var level_data: LevelData
## The Level it should refer to.
var level: Level
var player: Kid:
	get:
		return level.player

var key_counts := {
	Enums.colors.glitch: ComplexNumber.new(),
	Enums.colors.black: ComplexNumber.new(),
	Enums.colors.white: ComplexNumber.new(),
	Enums.colors.pink: ComplexNumber.new(),
	Enums.colors.orange: ComplexNumber.new(),
	Enums.colors.purple: ComplexNumber.new(),
	Enums.colors.cyan: ComplexNumber.new(),
	Enums.colors.red: ComplexNumber.new(),
	Enums.colors.green: ComplexNumber.new(),
	Enums.colors.blue: ComplexNumber.new(),
	Enums.colors.brown: ComplexNumber.new(),
	Enums.colors.pure: ComplexNumber.new(),
	Enums.colors.master: ComplexNumber.new(),
	Enums.colors.stone: ComplexNumber.new(),
}
var star_keys := {
	Enums.colors.glitch: false,
	Enums.colors.black: false,
	Enums.colors.white: false,
	Enums.colors.pink: false,
	Enums.colors.orange: false,
	Enums.colors.purple: false,
	Enums.colors.cyan: false,
	Enums.colors.red: false,
	Enums.colors.green: false,
	Enums.colors.blue: false,
	Enums.colors.brown: false,
	Enums.colors.pure: false,
	Enums.colors.master: false,
	Enums.colors.stone: false,
}
# Not really a setter, just used for undo/redo
func set_star_key(color: Enums.colors, val: bool) -> void:
	star_keys[color] = val

var undo_redo: GoodUndoRedo

signal changed_glitch_color
## The main glitch color. Keep in mind some doors might have a different glitch color.
var glitch_color := Enums.colors.glitch:
	set(val):
		if glitch_color == val: return
		glitch_color = val
		changed_glitch_color.emit()

signal changed_i_view
var i_view := false:
	set(val):
		if i_view == val: return
		i_view = val
		changed_i_view.emit()

func _init() -> void:
	undo_redo = GoodUndoRedo.new()

var last_player_undo: Callable
var last_saved_player_undo: Callable
func _physics_process(_delta: float) -> void:
	if is_instance_valid(player):
		if player.on_floor:
			last_player_undo = player.get_undo_action()


## should only be called from Level.reset
func reset() -> void:
	for color in key_counts.keys():
		key_counts[color].set_to(0, 0)
	for color in star_keys.keys():
		star_keys[color] = false
	glitch_color = Enums.colors.glitch
	i_view = false
	undo_redo.clear_history()
	
	# set up the undo in the start position
	if is_instance_valid(player): 
		last_player_undo = player.get_undo_action()
		start_undo_action()
		end_undo_action()

func open_door(door: Door) -> void:
	pass


## A key, door, or anything else can call these functions to ensure that the undo_redo object is ready for writing
func start_undo_action() -> void:
	if exclude_player: return
	if last_player_undo == last_saved_player_undo:
		if undo_redo.get_action_count() > 1:
			undo_redo.start_merge_last()
			return
	undo_redo.start_action()
	
	undo_redo.add_do_method(last_player_undo)
	undo_redo.add_undo_method(last_player_undo)
	last_saved_player_undo = last_player_undo

## This is called after start_undo_action to finish the action
func end_undo_action() -> void:
	if exclude_player: return
	undo_redo.commit_action(false)

# For legal reasons this should happen in a deferred call, so it's at the end of the frame and everything that happens in this frame had time to record their undo calls
func undo() -> void:
	if not Global.is_playing: return
	undo_sound.pitch_scale = 0.6
	undo_sound.play()
	undo_redo.undo()
	should_update_gates.emit()
	last_player_undo = player.get_undo_action()
	if undo_redo.get_last_action() == -1:
		undo_redo._last_action = 0
	update_mouseover()
