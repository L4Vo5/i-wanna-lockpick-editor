@tool
extends Node

# in the godot editor, as opposed to the level editor (exported or f5)
var in_editor := Engine.is_editor_hint()
# in the level editor (as opposed to like, an individual level)
# TODO: this is a duplicate of _current_mode??
var in_level_editor := false
var is_exported := OS.has_feature("release")
var is_web := OS.has_feature("web")
var is_windows := OS.has_feature("windows")
var is_linux := OS.has_feature("linux")
var is_in_test := ("res://addons/gdUnit4/src/core/GdUnitRunner.tscn" in OS.get_cmdline_args()) and (not is_exported)

var settings: LockpickSettings

signal changed_is_playing
## Will basically be true if there's a player moving around
var is_playing := false:
	set(val):
		if is_playing == val: return
		is_playing = val
		changed_is_playing.emit()

var game_version: String = ProjectSettings.get_setting("application/config/game_version")

@onready var fatal_error_dialog: AcceptDialog = %FatalError
@onready var safe_error_dialog: AcceptDialog = %SafeError
@onready var http_request: HTTPRequest = $HTTPRequest
var _non_fullscreen_window_mode := Window.MODE_MAXIMIZED

var danger_override: bool:
	get:
		return (not is_exported) and (Input.is_key_pressed(KEY_CTRL))

signal changed_level
var current_level: Level:
	set(val):
		if current_level == val: return
		current_level = val
		changed_level.emit()

var time := 0.0
var physics_time := 0.0
var physics_step := 0
var _current_mode := Modes.GAMEPLAY

var image_copier
var image_copier_exists:
	get:
		return is_instance_valid(image_copier)

enum Modes {
	GAMEPLAY, EDITOR
}

func _init() -> void:
	if ClassDB.class_exists(&"ClipboardImageCopier"):
		image_copier = ClassDB.instantiate(&"ClipboardImageCopier")
	if not in_editor:
		settings = LockpickSettings.new()

func _ready() -> void:
	set_mode(_current_mode)
	
	_setup_unfocus()
	
	# Look for update...
	if is_exported and not is_web:
		search_update()
	
	if is_web:
		safe_error_dialog.get_ok_button().text = "Ok"
		# wait for the size to be adjusted
		await get_tree().process_frame
		# More a notification than an error, but whatever
		safe_error(
	"""Downloading the desktop version of the editor is the recommended way to use it."""
	, Vector2i(250,100))

func _input(event: InputEvent) -> void:
	if in_editor: return
	if event.is_action_pressed(&"fullscreen"):
		var current_window_mode := get_tree().root.mode
		if current_window_mode == Window.MODE_WINDOWED or current_window_mode == Window.MODE_MAXIMIZED:
			_non_fullscreen_window_mode = current_window_mode
			get_tree().root.mode = Window.MODE_FULLSCREEN
		elif current_window_mode == Window.MODE_FULLSCREEN:
			get_tree().root.mode = _non_fullscreen_window_mode
	if event is InputEventKey:
		if event.keycode == KEY_F11 and event.pressed:
			if is_instance_valid(current_level):
				var img: Image = await current_level.level_data.get_screenshot()
				img.save_png("user://screenshot.png")
				print("Saved screenshot")
				

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(settings):
		settings.on_exit()

func search_update() -> void:
	if is_web: return
	var current_time := floori(Time.get_unix_time_from_system())
	if FileAccess.file_exists("user://last_update_check"):
		var str := FileAccess.get_file_as_string("user://last_update_check")
		var last_time := str.to_int()
		if current_time - last_time < 60*60*1:
			print("last update check was %d seconds ago. not searching" % (current_time - last_time))
			return
	var file := FileAccess.open("user://last_update_check", FileAccess.WRITE)
	file.store_string(str(current_time))
	print_debug("saving update check time as %d" % current_time)
	var dl_button := update_dialog.add_button("Download", true)
	dl_button.pressed.connect(_open_download_page)
	http_request.request_completed.connect(_http_request_completed)
	
	var url := "https://itch.io/api/1/x/wharf/latest?game_id=2027861&channel_name=%s" % ["windows" if is_windows else "linux"]
	
	var error := http_request.request(url)
	if error != OK:
		push_error("An error occurred in the HTTP request.")

@onready var update_dialog: AcceptDialog = $Update/UpdateDialog
var newer_version := ""
func _http_request_completed(_result, _response_code, _headers, body: PackedByteArray):
	var s := body.get_string_from_ascii()
	var dic = JSON.parse_string(s)
	if (not dic is Dictionary) or dic == null:
		print("Couldn't parse string as json when searching for update: %s" % s)
		return
	if dic.has("errors"):
		print("Errors found in json when searching for update: %s" % dic["errors"])
	elif not dic.has("latest"):
		print("Couldn't find version in json when searching for update: %s" % dic)
	if dic.has("latest"):
		newer_version = dic["latest"]
		inform_newer_version()

func inform_newer_version() -> void:
	print("Newest version on the itch.io page is %s" % newer_version)
	if newer_version.naturalnocasecmp_to(Global.game_version) <= 0:
		print("Newest version is equal or older! won't popup")
		return
	var text := "There's an update available: " + newer_version
	text += "\nCurrent version: " + game_version
	update_dialog.dialog_text = text
	update_dialog.popup_centered()

func _open_download_page() -> void:
	OS.shell_open("https://l4vo5.itch.io/i-wanna-lockpick-editor")

## Disconnects every signal the emitter had connected to the receiver.
## Returns how many signals were disconnected (so you can assert if you know beforehand)
# TODO: ? check if, for anonymous functions, this actually disconnects them from ALL receivers
func fully_disconnect(receiver: Object, emitter: Object) -> int:
	var count := 0
	# anonymous functions have the script itself as the owner... may not be that good tho
	var receiver_script = receiver.get_script()
	assert(receiver_script is Object)
	for sig_data in emitter.get_signal_list():
		assert(not sig_data.name is StringName) # maybe they'll update it 
		var sig_name: String = sig_data.name
		for connection_data in emitter.get_signal_connection_list(sig_name):
			var sig: Signal = connection_data.signal
			var callable: Callable = connection_data.callable
#			var met = receiver.get(callable.get_method())
#			if not met is Callable: continue
#			if sig.is_connected(met): 
			var obj: Object = callable.get_object()
			if obj == receiver or obj == receiver_script:
				sig.disconnect(callable)
				count += 1
	return count

func _process(delta: float) -> void:
	time += delta

func _physics_process(delta: float) -> void:
	physics_time += delta
	physics_step += 1
	RenderingServer.global_shader_parameter_set(&"FPS_TIME", physics_time)
	RenderingServer.global_shader_parameter_set(&"NOISE_OFFSET", Vector2(randf_range(-1000, 1000), randf_range(-1000, 1000)))
	if not in_editor:
		assert(PerfManager.check_balances())

# sets the viewport according to gameplay settings
func _set_viewport_to_gameplay() -> void:
	if in_editor: return
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS

# sets the viewport according to editor settings
func _set_viewport_to_editor() -> void:
	if in_editor: return
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_non_fullscreen_window_mode = Window.MODE_MAXIMIZED
	if not get_tree().root.mode == Window.MODE_FULLSCREEN:
		get_tree().root.mode = _non_fullscreen_window_mode

func set_mode(mode: Modes) -> void:
	if _current_mode == mode: return
	_current_mode = mode 
	if _current_mode == Modes.GAMEPLAY:
		_set_viewport_to_gameplay()
	else:
		_set_viewport_to_editor()

func fatal_error(text: String, size: Vector2i) -> void:
	fatal_error_dialog.get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	fatal_error_dialog.size = size
	fatal_error_dialog.dialog_text = text
	
	fatal_error_dialog.popup_centered()
	await fatal_error_dialog.visibility_changed
	get_tree().quit()

func safe_error(text: String, size: Vector2i) -> void:
	safe_error_dialog.get_label().horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	safe_error_dialog.size = size
	safe_error_dialog.dialog_text = text
	
	safe_error_dialog.popup_centered()

func show_notification(what: String) -> void:
	print("Global Notification: " + what)

# Wrapper for the ClipboardImageCopier class,
# to ensure there's no errors if the gdextension doesn't work
func get_image_from_clipboard() -> Image:
	if image_copier_exists:
		return image_copier.get_image_from_clipboard()
	return null

func get_image_from_clipboard_or_error() -> Variant:
	if image_copier_exists:
		return image_copier.get_image_from_clipboard_or_error()
	return "ClipboardImageCopier doesn't exist"

func copy_image_to_clipboard(image: Image) -> void:
	if image_copier_exists:
		var res = image_copier.copy_image_to_clipboard(image)
		if res != "":
			print("Error when copying image: " + res)
	else:
		print(":( no image copier")

func smart_adjust_rect(rect: Rect2i, bound: Rect2i) -> Rect2i:
	# First, constrain to bound size
	rect.size = rect.size.clamp(Vector2.ZERO, bound.size)
	# Then, reposition as best as possible toward the upper left corner
	var max_pos := bound.position + bound.size - rect.size
	rect.position = rect.position.clamp(bound.position, max_pos)
	return rect

var unfocus_timer: Timer
func _setup_unfocus() -> void:
	if not in_editor and not is_in_test:
		get_tree().root.focus_entered.connect(_on_window_focused)
		get_tree().root.focus_exited.connect(_on_window_unfocused)
		unfocus_timer = Timer.new()
		unfocus_timer.one_shot = true
		unfocus_timer.timeout.connect(_unfocus_stuff)
		add_child(unfocus_timer)

# reduce cpu usage as much as possible when the window is unfocused
func _on_window_unfocused() -> void:
	# WAITING4GODOT: if I don't check this, focusing inner Windows (like the file dialog) will stop everything.
	if get_tree().root.has_focus():
		return
	
	if unfocus_timer.is_stopped():
		unfocus_timer.start(10)

func _unfocus_stuff() -> void:
	# Just in case
	if get_tree().root.has_focus():
		return
	get_tree().paused = true
	
	OS.low_processor_usage_mode = true
	OS.low_processor_usage_mode_sleep_usec = 300_000
	
	# This stops all rendering.
	var viewport_rid := get_tree().root.get_viewport_rid()
	RenderingServer.viewport_set_update_mode(viewport_rid, RenderingServer.VIEWPORT_UPDATE_DISABLED)
	

func _on_window_focused() -> void:
	unfocus_timer.stop()
	get_tree().paused = false
	
	OS.low_processor_usage_mode = false
	
	var viewport_rid := get_tree().root.get_viewport_rid()
	RenderingServer.viewport_set_update_mode(viewport_rid, RenderingServer.VIEWPORT_UPDATE_WHEN_VISIBLE)
