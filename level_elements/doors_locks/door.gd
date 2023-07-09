@tool
extends MarginContainer
class_name Door

signal lock_clicked(event: InputEventMouseButton, lock: Lock)
#signal lock_clicked(which: int)

const LOCK := preload("res://level_elements/doors_locks/lock.tscn")
const DEBRIS := preload("res://level_elements/doors_locks/debris/door_debris.tscn")
const FRAME_POS := preload("res://level_elements/doors_locks/textures/door_frame_texture_pos.png")
const FRAME_NEG := preload("res://level_elements/doors_locks/textures/door_frame_texture_neg.png")

var open_cooldown := 0.5
var can_open := true

@export var ignore_position := false
@export var door_data: DoorData:
	set(val):
		if door_data == val: return
		_disconnect_door_data()
		door_data = val
		_connect_door_data()
# used to be meta, but found enough uses to keep it around
var original_door_data: DoorData
@export var ignore_collisions := false

@onready var static_body := %StaticBody2D as StaticBody2D
@onready var lock_holder := %LockHolder as Control

@onready var ice: MarginContainer = %Ice
@onready var paint: TextureRect = %Paint
@onready var erosion: MarginContainer = %Erosion
@onready var brown_curse: Control = %BrownCurse

@onready var snd_open: AudioStreamPlayer = %Open
@onready var copies: Label = %Copies

var using_i_view_colors := false
var level: Level = null

func _ready() -> void:
	assert(PerfManager.start("Door::_ready"))
	_create_canvas_items()
	
	static_body.disable_mode = CollisionObject2D.DISABLE_MODE_REMOVE
	copies.minimum_size_changed.connect(position_copies)
	Global.changed_level.connect(connect_level)
	_resolve_collision_mode()
	if not ignore_collisions:
		assert(visible)
		assert(not door_data.amount.is_zero())
	update_everything()
	connect_level()
	assert(PerfManager.end("Door::_ready"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_destroy_canvas_items()

func _connect_door_data() -> void:
	if not is_instance_valid(door_data): return
	door_data.changed.connect(update_everything)
	if not is_node_ready(): return
	update_everything()
	# look.... ok?
	
	show()
	_resolve_collision_mode()

func _disconnect_door_data() -> void:
	if not is_instance_valid(door_data): return
	door_data.changed.disconnect(update_everything)

func connect_level() -> void:
	level = Global.current_level
	if is_instance_valid(level):
		level.changed_i_view.connect(_on_changed_i_view)
		level.changed_glitch_color.connect(_on_changed_glitch_color)
		_on_changed_i_view()
		_on_changed_glitch_color()

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(door_data): return
	var text := ""
	if not door_data.amount.is_value(1,0):
		text = "×" + str(door_data.amount)
	copies.text = text
	if using_i_view_colors:
		_draw_frame()

func _resolve_collision_mode() -> void:
	if ignore_collisions or door_data.amount.is_zero() or not visible:
		static_body.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		static_body.process_mode = Node.PROCESS_MODE_INHERIT

var update_everything_count := 0
func update_everything() -> void:
	if not is_instance_valid(door_data): return
	assert(PerfManager.start(&"Door::update_everything"))
	
	_draw_base()
	_draw_frame()
	
	update_everything_count += 1
	
	_on_changed_i_view()
	update_textures()
	update_locks()
	update_curses()
	if not ignore_position:
		position = door_data.position
	assert(PerfManager.end(&"Door::update_everything"))

func position_copies() -> void:
	copies.size.x = size.x
	var diff := copies.size.x - size.x
	copies.position.x = -diff/2

func _on_changed_i_view() -> void:
	if not is_instance_valid(level): return
	if not is_instance_valid(door_data): return
	var is_aligned := false
	var is_flipped := false
	if not level.i_view and door_data.amount.real_part != 0:
		is_aligned = true
		if door_data.amount.real_part < 0:
			is_flipped = true
	if level.i_view and door_data.amount.imaginary_part != 0:
		is_aligned = true
		if door_data.amount.imaginary_part < 0:
			is_flipped = true
	using_i_view_colors = not is_aligned and not door_data.amount.is_zero()
	if not using_i_view_colors:
		update_textures()
	for lock in door_data.locks:
		if not is_instance_valid(lock): continue
		lock.dont_show_frame = not is_aligned
		lock.rotation = (90 if level.i_view else 0) + (180 if is_flipped else 0)

func _on_changed_glitch_color() -> void:
	if not is_instance_valid(door_data): return
	door_data.update_glitch_color(level.glitch_color)

func update_textures() -> void:
	if not is_instance_valid(door_data): return
	custom_minimum_size = door_data.size
	size = door_data.size
	position_copies()
	static_body.scale = size
	_draw_frame()

func update_locks() -> void:
	if not is_instance_valid(door_data): return
	assert(PerfManager.start(&"Door::update_locks"))
	
	var needed_locks := door_data.locks.size()
	var current_locks := lock_holder.get_child_count()
	# redo the current ones
	for i in mini(needed_locks, current_locks):
		var lock := lock_holder.get_child(i)
		lock.lock_data = door_data.locks[i]
	# shave off the rest
	if current_locks > needed_locks:
		for _i in current_locks - needed_locks:
			var lock := lock_holder.get_child(-1)
			lock_holder.remove_child(lock)
			lock.clicked.disconnect(_on_lock_clicked)
			NodePool.return_node(lock)
	# or add them
	else:
		for i in range(current_locks, needed_locks):
			var new_lock = NodePool.pool_node(LOCK)
			new_lock.clicked.connect(_on_lock_clicked.bind(new_lock))
			new_lock.lock_data = door_data.locks[i]
			lock_holder.add_child(new_lock)
	
	assert(PerfManager.end(&"Door::update_locks"))

func _on_lock_clicked(event: InputEventMouseButton, lock: Lock) -> void:
	lock_clicked.emit(event, lock)

func update_curses() -> void:
	if not is_instance_valid(door_data): return
	ice.visible = door_data.get_curse(Enums.curse.ice)
	erosion.visible = door_data.get_curse(Enums.curse.erosion)
	paint.visible = door_data.get_curse(Enums.curse.paint)
	brown_curse.visible = door_data.get_curse(Enums.curse.brown)

func try_open() -> void:
	if not can_open: return
	var should_create_debris := false
	var opened_at_all := false
	for i in level.door_multiplier:
		# "opened", "master_key", "added_copy", "do_methods", "undo_methods"
		var result := door_data.try_open()
		if result.opened:
			opened_at_all = true
			level.start_undo_action()
			for do_method in result.do_methods:
				level.undo_redo.add_do_method(do_method)
			for undo_method in result.undo_methods:
				level.undo_redo.add_undo_method(undo_method)
			
			if result.added_copy:
				snd_open.stream = preload("res://level_elements/doors_locks/copy.wav")
			elif result.master_key:
				snd_open.stream = preload("res://level_elements/doors_locks/open_master.wav")
			elif door_data.locks.size() > 1:
				snd_open.stream = preload("res://level_elements/doors_locks/open_combo.wav")
			elif door_data.outer_color == Enums.colors.master:
				snd_open.stream = preload("res://level_elements/doors_locks/open_master.wav")
			else:
				snd_open.stream = preload("res://level_elements/doors_locks/open.wav")
			snd_open.play()
			should_create_debris = true
		if door_data.amount.is_zero():
			assert(level.undo_redo.is_building_action())
			level.undo_redo.add_do_method(hide)
			hide()
			level.undo_redo.add_undo_method(show)
			level.undo_redo.add_undo_property(static_body, &"process_mode", static_body.process_mode)
			assert(static_body.process_mode == StaticBody2D.PROCESS_MODE_INHERIT)
			_resolve_collision_mode()
			assert(static_body.process_mode == StaticBody2D.PROCESS_MODE_DISABLED)
			level.undo_redo.add_do_property(static_body, &"process_mode", static_body.process_mode)
			break
	if not opened_at_all: return
	if level.undo_redo.is_building_action():
		level.end_undo_action()
	if should_create_debris:
		create_debris()
	can_open = false
	get_tree().create_timer(open_cooldown).timeout.connect(func(): can_open = true)

# do the effects for the curses
func break_curse_ice() -> void:
	door_data.set_curse(Enums.curse.ice, false, true)

func break_curse_erosion() -> void:
	door_data.set_curse(Enums.curse.erosion, false, true)

func break_curse_paint() -> void:
	door_data.set_curse(Enums.curse.paint, false, true)

func curse_brown() -> void:
	door_data.set_curse(Enums.curse.brown, true, true)

func break_curse_brown() -> void:
	door_data.set_curse(Enums.curse.brown, false, true)

func create_debris() -> void:
	for x in floori(size.x / 16):
		for y in floori(size.y / 16):
			var debris := DEBRIS.instantiate()
			debris.can_move = true
			var timer := Timer.new()
			timer.timeout.connect(debris.queue_free)
			debris.add_child(timer)
			debris.color = door_data.outer_color
			if door_data.get_curse(Enums.curse.brown):
				debris.color = Enums.colors.brown
			elif door_data.outer_color == Enums.colors.glitch:
				debris.color = door_data.glitch_color
				debris.is_glitched_color = true
			debris.global_position = global_position
			debris.position.x += randf_range(-4, 4) + 16 * x
			debris.position.y += randf_range(0, 8) + 16 * y
			if Global.in_editor:
				add_child(debris)
			else:
				level.add_debris_child(debris)
			timer.start(20)

func _create_canvas_items() -> void:
	door_base = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(door_base, get_canvas_item())
#	RenderingServer.canvas_item_set_draw_index(door_base, 0)
	door_glitch = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(door_glitch, get_canvas_item())
#	RenderingServer.canvas_item_set_draw_index(door_glitch, 1)
	door_frame = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(door_frame, get_canvas_item())
#	RenderingServer.canvas_item_set_draw_index(door_frame, 2)
	
	RenderingServer.canvas_item_set_material(door_glitch, GLITCH_MATERIAL.get_rid())

func _destroy_canvas_items() -> void:
	RenderingServer.free_rid(door_base)
	RenderingServer.free_rid(door_glitch)
	RenderingServer.free_rid(door_frame)

# Door base covers the main color/texture
var door_base: RID
const BASE_LIGHT := preload("res://level_elements/doors_locks/textures/door_color_light.png")
const BASE_MID := preload("res://level_elements/doors_locks/textures/door_color_mid.png")
const BASE_DARK := preload("res://level_elements/doors_locks/textures/door_color_dark.png")
const BASE_STONE := preload("res://level_elements/doors_locks/textures/stone_texture.png")
const BASE_MASTER := preload("res://level_elements/doors_locks/textures/gold_gradient.png")
const BASE_PURE := preload("res://level_elements/doors_locks/textures/pure_gradient.png")
const GLITCH_MASTER := preload("res://level_elements/doors_locks/textures/gold_glitch.png")
const GLITCH_PURE := preload("res://level_elements/doors_locks/textures/pure_glitch.png")

const BASE_TEX_RECT := Rect2(0, 0, 13, 15)
const BASE_DIST := Vector2(6, 7)
const BASE_ANIM_TILE_SIZE := Vector2(1, 64)

# Glitch will pop up on top of the base if needed
var door_glitch: RID
const GLITCH_MATERIAL := preload("res://rendering/glitch.material")
const GLITCH_BASE := preload("res://level_elements/doors_locks/textures/glitch_door.png")
const GLITCH_BASE_SHARED := preload("res://level_elements/doors_locks/textures/glitch_door_2.png")
const GLITCH_2_RECT := Rect2(0, 0, 58, 58)
const GLITCH_2_DIST := Vector2(6, 6)

func _draw_base() -> void:
	if not is_instance_valid(door_data): return
	assert(BASE_TEX_RECT.size == BASE_LIGHT.get_size())
	assert(BASE_TEX_RECT.size == BASE_MID.get_size())
	assert(BASE_TEX_RECT.size == BASE_DARK.get_size())
	assert(BASE_TEX_RECT.size == GLITCH_BASE.get_size())
	assert(GLITCH_2_RECT.size == GLITCH_BASE_SHARED.get_size())
	assert(BASE_ANIM_TILE_SIZE * Vector2(4, 1) == BASE_MASTER.get_size())
	assert(BASE_ANIM_TILE_SIZE * Vector2(4, 1) == BASE_PURE.get_size())
	assert(PerfManager.start("Door:_draw_base"))
	
	RenderingServer.canvas_item_clear(door_base)
	RenderingServer.canvas_item_clear(door_glitch)
	var rect := Rect2(Vector2(3,3),door_data.size - Vector2i(6, 6))
	var used_color := door_data.outer_color
	if door_data.get_curse(Enums.curse.brown):
		used_color = Enums.colors.brown
	
	# Glitch is a special boy...
	if used_color == Enums.colors.glitch:
		if door_data.glitch_color == Enums.colors.glitch:
			RenderingServer.canvas_item_add_nine_patch(door_glitch, rect, BASE_TEX_RECT, GLITCH_BASE.get_rid(), BASE_DIST, BASE_DIST)
			assert(PerfManager.end("Door:_draw_base"))
			return
		else:
			used_color = door_data.glitch_color
			
			RenderingServer.canvas_item_add_nine_patch(door_glitch, rect, GLITCH_2_RECT, GLITCH_BASE_SHARED.get_rid(), GLITCH_2_DIST, GLITCH_2_DIST, RenderingServer.NINE_PATCH_TILE, RenderingServer.NINE_PATCH_TILE)
	
	match used_color:
		Enums.colors.master, Enums.colors.pure:
			if door_data.outer_color == Enums.colors.glitch:
				var tex := GLITCH_MASTER if used_color == Enums.colors.master else GLITCH_PURE
				RenderingServer.canvas_item_add_texture_rect(door_base, rect, tex)
			else:
				var tex := BASE_MASTER if used_color == Enums.colors.master else BASE_PURE
				for i in 4:
					RenderingServer.canvas_item_add_animation_slice(door_base, Rendering.SPECIAL_ANIM_LENGTH, i * Rendering.SPECIAL_ANIM_DURATION, (i+1) * Rendering.SPECIAL_ANIM_DURATION)
					RenderingServer.canvas_item_add_texture_rect_region(door_base, rect, tex, Rect2(Vector2(i, 0) * BASE_ANIM_TILE_SIZE, BASE_ANIM_TILE_SIZE))
				RenderingServer.canvas_item_add_animation_slice(door_base, 1, 0, 1)
			
		Enums.colors.stone:
			RenderingServer.canvas_item_add_texture_rect(door_base, rect, BASE_STONE.get_rid(), true)
		Enums.colors.none:
			pass
		_: # normal colors
			# Draw top part, then middle, then bottom
			RenderingServer.canvas_item_add_nine_patch(door_base, rect, BASE_TEX_RECT, BASE_LIGHT.get_rid(), BASE_DIST, BASE_DIST, RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, false, Rendering.color_colors[used_color][1])
			RenderingServer.canvas_item_add_nine_patch(door_base, rect, BASE_TEX_RECT, BASE_MID.get_rid(), BASE_DIST, BASE_DIST, RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, true, Rendering.color_colors[used_color][0])
			RenderingServer.canvas_item_add_nine_patch(door_base, rect, BASE_TEX_RECT, BASE_DARK.get_rid(), BASE_DIST, BASE_DIST, RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, false, Rendering.color_colors[used_color][2])
	assert(PerfManager.end("Door:_draw_base"))

# Frame. Duh.
var door_frame: RID
const FRAME_LIGHT := preload("res://level_elements/doors_locks/textures/door_frame_light.png")
const FRAME_MID := preload("res://level_elements/doors_locks/textures/door_frame_mid.png")
const FRAME_DARK := preload("res://level_elements/doors_locks/textures/door_frame_dark.png")
const FRAME_TEXT_RECT := Rect2(0, 0, 7, 7)
const FRAME_TL := Vector2(4, 4)
const FRAME_BR := Vector2(4, 4)
func _draw_frame() -> void:
	if not is_instance_valid(door_data): return
	assert(PerfManager.start("Door:_draw_frame"))
	var rect := Rect2(Vector2.ZERO,door_data.size)
	RenderingServer.canvas_item_clear(door_frame)
	var frame_palette: Array
	if using_i_view_colors:
		frame_palette = Rendering.i_view_palette
	else:
		frame_palette = Rendering.frame_colors[Enums.sign.positive if door_data.amount.real_part >= 0 else Enums.sign.negative]
	
	RenderingServer.canvas_item_add_nine_patch(door_frame, rect, FRAME_TEXT_RECT, FRAME_LIGHT.get_rid(), FRAME_TL, FRAME_BR, RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, false,  frame_palette[1])
	RenderingServer.canvas_item_add_nine_patch(door_frame, rect, FRAME_TEXT_RECT, FRAME_MID.get_rid(), FRAME_TL, FRAME_BR, RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, true, frame_palette[0])
	RenderingServer.canvas_item_add_nine_patch(door_frame, rect, FRAME_TEXT_RECT, FRAME_DARK.get_rid(), FRAME_TL, FRAME_BR, RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, false, frame_palette[2])
	assert(PerfManager.end("Door:_draw_frame"))
