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
		return level.player if level else null

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
		player._on_changed_i_view()
		changed_i_view.emit()

const OPEN_COOLDOWN_TIME := 0.5

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
	
	update_gates()

# TODO: the way undos would work here would make each individual affected door take up an action! oh no! either merge them or apply them all at once.
func apply_auras_on_door(door: Door) -> void:
	var door_data := door.door_data
	if key_counts[Enums.colors.red].real_part >= 1:
		if apply_curse_door(door, Enums.curse.ice, false):
			door.break_curse_ice()
	if key_counts[Enums.colors.green].real_part >= 5:
		if apply_curse_door(door, Enums.curse.erosion, false):
			door.break_curse_erosion()
	if key_counts[Enums.colors.blue].real_part >= 3:
		apply_curse_door(door, Enums.curse.paint, false)
		door.break_curse_paint()
	if key_counts[Enums.colors.brown].real_part >= 1:
		if apply_curse_door(door, Enums.curse.brown, true):
			door.curse_brown()
	elif key_counts[Enums.colors.brown].real_part <= 1:
		if apply_curse_door(door, Enums.curse.brown, false):
			door.break_curse_brown()
	if undo_redo.is_building_action():
		end_undo_action()
		# TODO: you don't actually care about gates, but currently it stands for "generally update stuff"
		update_gates()

## Returns true if the curse/uncurse was successful (and the animation should play), false if it wasn't.
func apply_curse_door(door: Door, curse: Enums.curse, val: bool) -> bool:
	var door_data := door.door_data
	if door_data.outer_color == Enums.colors.gate: return false
	if door_data.get_curse(curse) == val: return false
	
	if curse == Enums.curse.brown:
		if door_data.has_color(Enums.colors.pure): return false
		# Can't curse completely brown doors (doesn't matter either way, but it's a visual change)
		if door_data.outer_color == Enums.colors.brown and door_data.locks.all(func(l: LockData) -> bool: return l.color == Enums.colors.brown):
			return false
	
	door_data.set_curse(curse, val)
	
	if !undo_redo.is_building_action():
		start_undo_action()
	undo_redo.add_undo_method(door_data.set_curse.bind(curse, !val))
	undo_redo.add_do_method(door_data.set_curse.bind(curse, val))
	
	return true

## Tries to open a door, and communicates the result to the door so it can handle sounds and animation.
func try_open_door(door: Door) -> void:
	var door_data := door.door_data
	# Check if the door is currently in cooldown state
	if door.open_cooldown > 0: return
	# Gates have separate logic, this function doesn't concern them
	if door_data.outer_color == Enums.colors.gate: return
		
	var result := try_open_door_data(door_data, player.master_equipped)
	
	var opened: bool = result.opened
	var used_master_key: bool = result.master_key
	var amount_delta: ComplexNumber = result.amount_delta
	var new_glitch_color: Enums.colors = result.new_glitch_color
	var changed_key_color: Enums.colors = result.changed_color
	var color_delta: ComplexNumber = result.color_delta
	
	if not opened: return
	if not undo_redo.is_building_action():
		start_undo_action()
	
	if used_master_key:
		# stop equipping master key, unless X is still pressed, for convenience
		if not Input.is_action_pressed(&"master"):
			if not player.master_equipped.is_zero():
				player.update_master_equipped(true, false)
	
	if changed_key_color != Enums.colors.none:
		var color_count: ComplexNumber = key_counts[changed_key_color]
		undo_redo.add_do_method(color_count.add.bind(color_delta))
		undo_redo.add_undo_method(color_count.sub.bind(color_delta))
		color_count.add(color_delta)
	
	if new_glitch_color != Enums.colors.none:
		# HACK: Come up with something better.
		# (it's hard tho...)
		# cleanest solution almost seems to be removing the level's
		# changed_glitch_color signal altogether, and updating everything manually,
		# either here or on the level... but that's troublesome and bad OOP (does that matter?)
		# PERF: maybe the level keeps a list of all doors and keys with glitch, 
		# so that it doesn't have to go through ALL all? 
		for _door: Door in level.doors.get_children():
			var _door_data := _door.door_data
			if not _door_data.get_curse(Enums.curse.brown):
				# If the door was previously cursed, its glitch color won't match up, so we need to keep track of that in the undo.
				if _door_data.glitch_color != level.glitch_color:
					undo_redo.add_undo_property(_door_data, &"glitch_color", _door_data.glitch_color)
					_door_data.glitch_color = new_glitch_color
		
		if glitch_color != new_glitch_color:
			undo_redo.add_undo_property(self, &"glitch_color", glitch_color)
			undo_redo.add_do_property(self, &"glitch_color", new_glitch_color)
			glitch_color = new_glitch_color
	
	
	# handles animations, sounds, etc.
	door.open(result)
	level.on_door_opened(door)
	# TODO: refactor this too
	if door_data.amount.is_zero():
		assert(level.undo_redo.is_building_action())
		level.undo_redo.add_do_method(door.hide)
		door.hide()
		level.undo_redo.add_undo_method(door.show)
		level.undo_redo.add_undo_property(door.static_body, &"process_mode", door.static_body.process_mode)
		assert(door.static_body.process_mode == StaticBody2D.PROCESS_MODE_INHERIT)
		door.resolve_collision_mode()
		assert(door.static_body.process_mode == StaticBody2D.PROCESS_MODE_DISABLED)
		level.undo_redo.add_do_property(door.static_body, &"process_mode", door.static_body.process_mode)
	if undo_redo.is_building_action():
		end_undo_action()
	door.open_cooldown = OPEN_COOLDOWN_TIME
	update_gates()

## try to open the door with the current keys.
## doesn't actually open it! (no side effects). returns a dict with information:
## opened: true if it'd be opened. if not true, you can safely ignore all other fields
## master_keY: true if the opening happens with a master key
## added_copy: if the master key also added a copy (used for animations)
## amount_delta: how much to change the door's amount by
## new_glitch_color: the new glitch color (or none)
## changed_color: what key color to change the amount of (or none)
## color_delta: how much to change that color by
# PERF: for performance, don't use a dictionary? is that even close to a bottleneck? should be easy to use a struct/array, or even keep a dict but access it with numbers instead of strings.
func try_open_door_data(door_data: DoorData, master_equipped: ComplexNumber) -> Dictionary:
	var return_dict := {
		"opened": false,
		"master_key": false,
		"added_copy": false, 
		"amount_delta": ComplexNumber.new(),
		"new_glitch_color": Enums.colors.none,
		"changed_color": Enums.colors.none,
		"color_delta": ComplexNumber.new(),
	}
	if door_data.amount.is_zero(): return return_dict
	if door_data.get_curse(Enums.curse.ice) or door_data.get_curse(Enums.curse.erosion) or door_data.get_curse(Enums.curse.paint): return return_dict
	
	var used_outer_color := door_data.get_used_color()
	var is_gate := door_data.outer_color == Enums.colors.gate
	
	# first, try to open with master keys
	if not is_gate and not master_equipped.is_zero():
		var can_master := true
		const NON_COPIABLE_COLORS := [Enums.colors.master, Enums.colors.pure]
		if used_outer_color in NON_COPIABLE_COLORS:
			can_master = false
		else:
			for lock: LockData in door_data.locks:
				if lock.get_used_color() in NON_COPIABLE_COLORS:
					can_master = false
					break
		if can_master:
			return_dict.opened = true
			return_dict.master_key = true
			return_dict.amount_delta = master_equipped.flipped()
			return_dict.added_copy = master_equipped.is_negative()
			
			if not star_keys[Enums.colors.master]:
				return_dict.changed_color = Enums.colors.master
				return_dict.color_delta = player.master_equipped.flipped()
			return return_dict
	
	# open normally
	
	# when there's both real and imaginary copies, it should try opening the door twice, first for the currently-focused one (real if no i-view, imaginary if i-view)
	# but also, even the currently-focused one should be skipped if there are 0 copies 
	# so this variable dictates, for real and then imaginary copies: [should it even try?, should it rotor the locks?, should it flip them?]
	var dims_try_rotor_flip := [
		[door_data.amount.real_part != 0, false, door_data.amount.real_part < 0],
		[door_data.amount.imaginary_part != 0, true, door_data.amount.imaginary_part < 0]]
	
	# if i-view, try imaginary copies first
	if i_view: 
		dims_try_rotor_flip.reverse()
	
	# how much the keys corresponding door's outer color will be changed by
	var diff: ComplexNumber
	var did_it_open: bool
	# The actual dimension it ended up opening in.
	# (can have negative values, for example if the door has -5 copies this'll end up as -1+0i)
	var open_dim := ComplexNumber.new_with(1, 0)
	for try_rotor_flip in dims_try_rotor_flip:
		var try: bool = try_rotor_flip[0]
		var rotor: bool = try_rotor_flip[1]
		var flip: bool = try_rotor_flip[2]
		if not try: continue
		diff = ComplexNumber.new_with(0, 0)
		did_it_open = true
		for lock_data in door_data.locks:
			var used_lock_color := lock_data.get_used_color()
			
			var key_amount: ComplexNumber = key_counts[used_lock_color]
			var diff_after_open := open_lock_data_with(lock_data, key_amount, flip, rotor)
			# open_lock_data_with returns null if it couldn't be opened
			if diff_after_open == null:
				did_it_open = false
				break
			diff.add(diff_after_open)
		if did_it_open: 
			if rotor:
				open_dim.rotor()
			if flip:
				open_dim.flip()
			# if it worked for the first dimension, skip the other
			break
	
	if not did_it_open: return return_dict
	
	return_dict.opened = true
	
	if is_gate: return return_dict
	
	return_dict.amount_delta = open_dim.flipped()
	return_dict.new_glitch_color = used_outer_color
	
	if not star_keys[used_outer_color]:
		return_dict.changed_color = used_outer_color
		return_dict.color_delta = diff
	
	return return_dict

## Re-evaluates all gates.
func update_gates() -> void:
	if not level: return
	for door: Door in level.doors.get_children():
		update_gate(door)
	# TODO: none of this
	if player:
		player.update_auras()

func update_gate(gate: Door) -> void:
	var door_data := gate.door_data
	if door_data.outer_color != Enums.colors.gate:
		if gate.ignore_collisions_gate != -1:
			gate.ignore_collisions_gate = -1
			gate.resolve_collision_mode()
	else:
		if not gate.ignore_collisions:
			gate.ignore_collisions_gate = 0
			if is_instance_valid(level) and is_instance_valid(level.player):
				var result := try_open_door_data(door_data, ComplexNumber.new())
				if result.opened:
					gate.ignore_collisions_gate = 1
		gate.resolve_collision_mode()
	gate.update_gate_anim()

# I can't believe I made this lmao??? fine tho
const value_type_to_ComplexNumber_var: Dictionary = {
	Enums.value.real: &"real_part",
	Enums.value.imaginary: &"imaginary_part",
}
# returns the key count difference after opening, or null if it can't be opened
func open_lock_data_with(lock_data: LockData, key_count: ComplexNumber, flipped: bool, is_rotor: bool) -> ComplexNumber:
	# listen... it works lmao
	if flipped or is_rotor:
		var temp_lock: LockData = lock_data.duplicated()
		if flipped:
			temp_lock.flip_sign()
		if is_rotor:
			temp_lock.rotor()
		return open_lock_data_with(temp_lock, key_count, false, false)
	
	if lock_data.lock_type == Enums.lock_types.all:
		if key_count.is_zero():
			return null
		else:
			return key_count.duplicated().flip()
	elif lock_data.lock_type == Enums.lock_types.blank:
		if not key_count.is_zero():
			return null
		else:
			return ComplexNumber.new()
	
	# only normal and blast doors left
	if key_count.is_zero():
		return null
	var new_key_count := ComplexNumber.new()
	# use 1 for blast doors
	var used_magnitude := lock_data.magnitude if lock_data.lock_type == Enums.lock_types.normal else 1
	var signed_magnitude := used_magnitude if lock_data.sign == Enums.sign.positive else -used_magnitude
	var relevant_value_sn: StringName = value_type_to_ComplexNumber_var[lock_data.value_type]
	var relevant_value = key_count.get(relevant_value_sn)
	
	if abs(relevant_value) < used_magnitude or signi(relevant_value) != signi(signed_magnitude):
		return null
	
	match lock_data.lock_type:
		Enums.lock_types.normal:
			new_key_count.set(relevant_value_sn, -signed_magnitude)
		Enums.lock_types.blast:
			new_key_count.set(relevant_value_sn, -relevant_value)
	
	return new_key_count


func pick_up_key(key: Key) -> void:
	var key_data := key.key_data
	start_undo_action()
	undo_redo.add_undo_method(key.undo)
	undo_redo.add_do_method(key.redo)
	if not key_data.is_infinite:
		key_data.is_spent = true
		key.collision.call_deferred("set_process_mode", Node.PROCESS_MODE_DISABLED)
		hide()
	var used_color := key_data.get_used_color()
	var current_count: ComplexNumber = key_counts[used_color]
	var orig_count: ComplexNumber = current_count.duplicated()
	var orig_star: bool = star_keys[used_color]
	
	if star_keys[used_color]:
		if key_data.type == Enums.key_types.unstar:
			star_keys[used_color] = false
	else:
		match key_data.type:
			Enums.key_types.add:
				current_count.add(key_data.amount)
			Enums.key_types.exact:
				current_count.set_to_this(key_data.amount)
			Enums.key_types.rotor:
				current_count.rotor()
			Enums.key_types.flip:
				current_count.flip()
			Enums.key_types.rotor_flip:
				current_count.rotor().flip()
			Enums.key_types.star:
				star_keys[used_color] = true
	
	if star_keys[used_color] != orig_star:
		undo_redo.add_do_method(set_star_key.bind(used_color, star_keys[used_color]))
		undo_redo.add_undo_method(set_star_key.bind(used_color, orig_star))
	if not current_count.is_equal_to(orig_count):
		undo_redo.add_do_method(current_count.set_to.bind(current_count.real_part, current_count.imaginary_part))
		undo_redo.add_undo_method(current_count.set_to.bind(orig_count.real_part, orig_count.imaginary_part))
	end_undo_action()
	update_gates()

func win() -> void:
	start_undo_action()
	undo_redo.add_do_method(level.goal.win)
	undo_redo.add_undo_method(level.goal.undo_win)
	end_undo_action()

## A key, door, or anything else can call these functions to ensure that the undo_redo object is ready for writing
func start_undo_action() -> void:
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
	undo_redo.commit_action(false)

# For legal reasons this should happen in a deferred call, so it's at the end of the frame and everything that happens in this frame had time to record their undo calls
func undo() -> void:
	undo_redo.undo()
	last_player_undo = player.get_undo_action()
	if undo_redo.get_last_action() == -1:
		undo_redo._last_action = 0
	update_gates()

