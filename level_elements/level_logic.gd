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
var active_salvage: SalvagePoint

var key_counts := {
	Enums.Colors.Glitch: ComplexNumber.new(),
	Enums.Colors.Black: ComplexNumber.new(),
	Enums.Colors.White: ComplexNumber.new(),
	Enums.Colors.Pink: ComplexNumber.new(),
	Enums.Colors.Orange: ComplexNumber.new(),
	Enums.Colors.Purple: ComplexNumber.new(),
	Enums.Colors.Cyan: ComplexNumber.new(),
	Enums.Colors.Red: ComplexNumber.new(),
	Enums.Colors.Green: ComplexNumber.new(),
	Enums.Colors.Blue: ComplexNumber.new(),
	Enums.Colors.Brown: ComplexNumber.new(),
	Enums.Colors.Pure: ComplexNumber.new(),
	Enums.Colors.Master: ComplexNumber.new(),
	Enums.Colors.Stone: ComplexNumber.new(),
}
var star_keys := {
	Enums.Colors.Glitch: false,
	Enums.Colors.Black: false,
	Enums.Colors.White: false,
	Enums.Colors.Pink: false,
	Enums.Colors.Orange: false,
	Enums.Colors.Purple: false,
	Enums.Colors.Cyan: false,
	Enums.Colors.Red: false,
	Enums.Colors.Green: false,
	Enums.Colors.Blue: false,
	Enums.Colors.Brown: false,
	Enums.Colors.Pure: false,
	Enums.Colors.Master: false,
	Enums.Colors.Stone: false,
}
# Not really a setter, just used for undo/redo
func set_star_key(color: Enums.Colors, val: bool) -> void:
	star_keys[color] = val

var undo_redo: GoodUndoRedo

signal changed_glitch_color
## The main glitch color. Keep in mind some doors might have a different glitch color.
var glitch_color := Enums.Colors.Glitch:
	set(val):
		if glitch_color == val: return
		glitch_color = val
		changed_glitch_color.emit()

signal changed_i_view
var i_view := false:
	set(val):
		if i_view == val: return
		i_view = val
		if player:
			player._on_changed_i_view()
		for door: Door in level.doors.get_children():
			door._on_changed_i_view()
		changed_i_view.emit()

var master_equipped := ComplexNumber.new()

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
	glitch_color = Enums.Colors.Glitch
	for key: KeyElement in level.keys.get_children():
		# TODO: definitely no! ... ?
		key._on_changed_glitch_color()
	i_view = false
	undo_redo.clear_history()
	active_salvage = null
	
	# TODO: Change how this is handled (output collision)
	if level.load_output_points:
		for salvage_point: SalvagePoint in level.salvage_points.get_children():
			salvage_point.prep_output_step_1()
		for salvage_point: SalvagePoint in level.salvage_points.get_children():
			salvage_point.prep_output_step_2()
		for salvage_point: SalvagePoint in level.salvage_points.get_children():
			salvage_point.prep_output_step_3()
	
	# set up the undo in the start position
	if is_instance_valid(player): 
		last_player_undo = player.get_undo_action()
		start_undo_action()
		end_undo_action()
	
	update_gates()
	update_master_equipped(false, false, true)

# TODO: the way undos would work here would make each individual affected door take up an action! oh no! either merge them or apply them all at once.
func apply_auras_on_door(door: Door) -> void:
	if key_counts[Enums.Colors.Red].real_part >= 1:
		if apply_curse_door(door, Enums.Curse.Ice, false):
			door.break_curse_ice()
	if key_counts[Enums.Colors.Green].real_part >= 5:
		if apply_curse_door(door, Enums.Curse.Erosion, false):
			door.break_curse_erosion()
	if key_counts[Enums.Colors.Blue].real_part >= 3:
		apply_curse_door(door, Enums.Curse.Paint, false)
		door.break_curse_paint()
	if key_counts[Enums.Colors.Brown].real_part >= 1:
		if apply_curse_door(door, Enums.Curse.Brown, true):
			door.curse_brown()
	elif key_counts[Enums.Colors.Brown].real_part <= -1:
		if apply_curse_door(door, Enums.Curse.Brown, false):
			door.break_curse_brown()
	if undo_redo.is_building_action():
		end_undo_action()
		# TODO: you don't actually care about gates, but currently it stands for "generally update stuff"
		update_gates()

## Returns true if the curse/uncurse was successful (and the animation should play), false if it wasn't.
func apply_curse_door(door: Door, curse: Enums.Curse, val: bool) -> bool:
	var door_data := door.data
	if door_data.outer_color == Enums.Colors.Gate: return false
	if door_data.get_curse(curse) == val: return false
	
	if curse == Enums.Curse.Brown:
		if door_data.has_color(Enums.Colors.Pure): return false
		# Can't curse completely brown doors (doesn't matter either way, but it's a visual change)
		if door_data.outer_color == Enums.Colors.Brown and door_data.locks.all(func(l: LockData) -> bool: return l.color == Enums.Colors.Brown):
			return false
	
	door_data.set_curse(curse, val)
	
	if !undo_redo.is_building_action():
		start_undo_action()
	undo_redo.add_undo_method(door_data.set_curse.bind(curse, !val))
	undo_redo.add_do_method(door_data.set_curse.bind(curse, val))
	
	return true

func set_glitch_color(new_glitch_color: Enums.Colors, is_undo := false) -> void:
	var old_glitch_color := glitch_color
	glitch_color = new_glitch_color
	
	if not is_undo and old_glitch_color != new_glitch_color:
		undo_redo.add_undo_method(set_glitch_color.bind(old_glitch_color, true))
		undo_redo.add_do_method(set_glitch_color.bind(new_glitch_color, true))
	
	# HACK: Come up with something better.
	# (it's hard tho...)
	# PERF: maybe the level keeps a list of all doors and keys with glitch, 
	# so that it doesn't have to go through ALL all? 
	
	for key: KeyElement in level.keys.get_children():
		if key.data.color == Enums.Colors.Glitch:
			key._on_changed_glitch_color()
	
	for door: Door in level.doors.get_children():
		var _door_data := door.data
		if not _door_data.get_curse(Enums.Curse.Brown):
			# If the door was previously cursed, its glitch color might not match up, so we need to keep track of that in the undo.
			# (unless this is an undo)
			if not is_undo and _door_data.glitch_color != old_glitch_color:
				undo_redo.add_undo_property(_door_data, &"glitch_color", _door_data.glitch_color)
			
			_door_data.glitch_color = new_glitch_color
		# TODO/PERF: super no!!!
		door.update_visuals()

## Tries to open a door, and communicates the result to the door so it can handle sounds and animation.
func try_open_door(door: Door) -> void:
	var door_data := door.data
	# Check if the door is currently in cooldown state
	if door.open_cooldown > 0: return
	# Gates have separate logic, this function doesn't concern them
	if door_data.outer_color == Enums.Colors.Gate: return
	
	var result := try_open_door_data(door_data, false)
	
	var opened: bool = result.opened
	var used_master_key: bool = result.master_key
	var amount_delta: ComplexNumber = result.amount_delta
	var new_glitch_color: Enums.Colors = result.new_glitch_color
	var changed_key_color: Enums.Colors = result.changed_color
	var color_delta: ComplexNumber = result.color_delta
	
	if not opened: return
	if not undo_redo.is_building_action():
		start_undo_action()
	
	if used_master_key:
		# stop equipping master key, unless X is still pressed, for convenience
		if not Input.is_action_pressed(&"master"):
			if not master_equipped.is_zero():
				update_master_equipped(true, false)
	
	if changed_key_color != Enums.Colors.None:
		var color_count: ComplexNumber = key_counts[changed_key_color]
		undo_redo.add_do_method(color_count.add.bind(color_delta))
		undo_redo.add_undo_method(color_count.sub.bind(color_delta))
		color_count.add(color_delta)
	
	if new_glitch_color != Enums.Colors.None:
		set_glitch_color(new_glitch_color)
	
	door_data.amount.add(amount_delta)
	undo_redo.add_do_method(door_data.amount.add.bind(amount_delta))
	undo_redo.add_undo_method(door_data.amount.sub.bind(amount_delta))
	
	# handles animations, sounds, etc.
	door.open(result)
	
	# TODO: refactor this too
	if door_data.amount.is_zero():
		if active_salvage != null:
			on_salvaged_door(door)
		assert(undo_redo.is_building_action())
		undo_redo.add_do_method(door.hide)
		door.hide()
		undo_redo.add_undo_method(door.show)
		undo_redo.add_undo_property(door.static_body, &"process_mode", door.static_body.process_mode)
		assert(door.static_body.process_mode == StaticBody2D.PROCESS_MODE_INHERIT)
		door.resolve_collision_mode()
		assert(door.static_body.process_mode == StaticBody2D.PROCESS_MODE_DISABLED)
		undo_redo.add_do_property(door.static_body, &"process_mode", door.static_body.process_mode)
	level.on_door_opened(door)
	end_undo_action()
	door.open_cooldown = OPEN_COOLDOWN_TIME
	update_gates()
	if changed_key_color == Enums.Colors.Master:
		update_master_equipped(false, false, true)

## try to open the door with the current keys.
## doesn't actually open it! (no side effects). returns a dict with information:
## opened: true if it'd be opened. if not true, you can safely ignore all other fields
## master_key: true if the opening happens with a master key
## added_copy: if the master key also added a copy (used for animations)
## amount_delta: how much to change the door's amount by
## new_glitch_color: the new glitch color (or none)
## changed_color: what key color to change the amount of (or none)
## color_delta: how much to change that color by
# PERF: for performance, don't use a dictionary? is that even close to a bottleneck? should be easy to use a struct/array, or even keep a dict but access it with numbers instead of strings.
func try_open_door_data(door_data: DoorData, ignore_master: bool) -> Dictionary:
	var return_dict := {
		"opened": false,
		"master_key": false,
		"added_copy": false, 
		"amount_delta": ComplexNumber.new(),
		"new_glitch_color": Enums.Colors.None,
		"changed_color": Enums.Colors.None,
		"color_delta": ComplexNumber.new(),
	}
	if door_data.amount.is_zero(): return return_dict
	if door_data.get_curse(Enums.Curse.Ice) or door_data.get_curse(Enums.Curse.Erosion) or door_data.get_curse(Enums.Curse.Paint): return return_dict
	
	var used_outer_color := door_data.get_used_color()
	var is_gate := door_data.outer_color == Enums.Colors.Gate
	if is_gate: assert(ignore_master)
	
	# first, try to open with master keys
	if not ignore_master and not master_equipped.is_zero():
		var can_master := true
		const NON_COPIABLE_COLORS := [Enums.Colors.Master, Enums.Colors.Pure]
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
			
			if not star_keys[Enums.Colors.Master]:
				return_dict.changed_color = Enums.Colors.Master
				return_dict.color_delta = master_equipped.flipped()
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
	var door_data := gate.data
	if door_data.outer_color != Enums.Colors.Gate:
		if gate.ignore_collisions_gate != -1:
			gate.ignore_collisions_gate = -1
			gate.resolve_collision_mode()
	else:
		gate.ignore_collisions_gate = 0
		if is_instance_valid(level.player):
			var result := try_open_door_data(door_data, true)
			if result.opened:
				gate.ignore_collisions_gate = 1
		gate.resolve_collision_mode()
	gate.update_gate_anim()

# I can't believe I made this lmao??? fine tho
const value_type_to_ComplexNumber_var: Dictionary = {
	Enums.Value.Real: &"real_part",
	Enums.Value.Imaginary: &"imaginary_part",
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
	
	if lock_data.lock_type == Enums.LockTypes.All:
		if key_count.is_zero():
			return null
		else:
			return key_count.duplicated().flip()
	elif lock_data.lock_type == Enums.LockTypes.Blank:
		if not key_count.is_zero():
			return null
		else:
			return ComplexNumber.new()
	
	# only normal and blast doors left
	if key_count.is_zero():
		return null
	var new_key_count := ComplexNumber.new()
	# use 1 for blast doors
	var used_magnitude := lock_data.magnitude if lock_data.lock_type == Enums.LockTypes.Normal else 1
	var signed_magnitude := used_magnitude if lock_data.sign == Enums.Sign.Positive else -used_magnitude
	var relevant_value_sn: StringName = value_type_to_ComplexNumber_var[lock_data.value_type]
	var relevant_value = key_count.get(relevant_value_sn)
	
	if abs(relevant_value) < used_magnitude or signi(relevant_value) != signi(signed_magnitude):
		return null
	
	match lock_data.lock_type:
		Enums.LockTypes.Normal:
			new_key_count.set(relevant_value_sn, -signed_magnitude)
		Enums.LockTypes.Blast:
			new_key_count.set(relevant_value_sn, -relevant_value)
	
	return new_key_count

# updates the equipped master keys for the player
# if switch_state is true, that's probably because X was just pressed
# if it's false, it's because the master key count changed, and we wanna make sure the current master equipped state is still valid
func update_master_equipped(switch_state := false, play_sounds := true, unequip_if_different := false) -> void:
	var last_master_equipped := master_equipped.duplicated()
	if !player: return
	# if the objective is for it to be "on" or not
	var obj_on := (master_equipped.is_zero() and switch_state) or (not master_equipped.is_zero() and not switch_state)
	if not obj_on:
		master_equipped.set_to(0, 0)
	else:
		var original_count := master_equipped.duplicated()
		master_equipped.set_to(0,0)
		if not i_view:
			master_equipped.real_part = signi(key_counts[Enums.Colors.Master].real_part)
		else:
			master_equipped.imaginary_part = signi(key_counts[Enums.Colors.Master].imaginary_part)
		if unequip_if_different and not original_count.is_equal_to(master_equipped):
			master_equipped.set_to(0, 0)
	if play_sounds:
		player.master_equipped_sounds(last_master_equipped)

# if you call this function, run _resolve_collision_mode on the key later
func pick_up_key(key: KeyElement) -> void:
	var key_data := key.data
	start_undo_action()
	undo_redo.add_undo_method(key.undo)
	undo_redo.add_do_method(key.redo)
	if not key_data.is_infinite:
		key_data.is_spent = true
		# TODO: hmm order of operations
		# can't do when reset happens in the same frame (salvages)
		# key.collision.call_deferred(&"set_process_mode", PROCESS_MODE_DISABLED)
		key._resolve_collision_mode.call_deferred()
		key.hide()
	var used_color := key_data.get_used_color()
	var current_count: ComplexNumber = key_counts[used_color]
	var orig_count: ComplexNumber = current_count.duplicated()
	var orig_star: bool = star_keys[used_color]
	
	if star_keys[used_color]:
		if key_data.type == Enums.KeyTypes.Unstar:
			star_keys[used_color] = false
	else:
		match key_data.type:
			Enums.KeyTypes.Add:
				current_count.add(key_data.amount)
			Enums.KeyTypes.Exact:
				current_count.set_to_this(key_data.amount)
			Enums.KeyTypes.Rotor:
				current_count.rotor()
			Enums.KeyTypes.Flip:
				current_count.flip()
			Enums.KeyTypes.RotorFlip:
				current_count.rotor().flip()
			Enums.KeyTypes.Star:
				star_keys[used_color] = true
	
	if star_keys[used_color] != orig_star:
		undo_redo.add_do_method(set_star_key.bind(used_color, star_keys[used_color]))
		undo_redo.add_undo_method(set_star_key.bind(used_color, orig_star))
	if not current_count.is_equal_to(orig_count):
		undo_redo.add_do_method(current_count.set_to.bind(current_count.real_part, current_count.imaginary_part))
		undo_redo.add_undo_method(current_count.set_to.bind(orig_count.real_part, orig_count.imaginary_part))
	end_undo_action()
	update_gates()
	if used_color == Enums.Colors.Master:
		update_master_equipped(false, false, true)

func on_salvaged_door(door: Door) -> void:
	assert(active_salvage != null)
	var sid := active_salvage.data.sid
	var door_data := door.data.duplicated()
	# Unnecessary... but helps in the salvage point editor
	door_data.amount.set_to(1, 0)
	level.goal.snd_win.play()
	level.gameplay_manager.pack_state.salvage_door(sid, door_data)
	level.gameplay_manager.win_animation("Door Salvaged!")

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

