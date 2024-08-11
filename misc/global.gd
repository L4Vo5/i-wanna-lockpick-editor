@tool
extends Node

# in the godot editor, as opposed to the "game" (exported or f5)
var in_editor := Engine.is_editor_hint()
var is_exported := OS.has_feature("release")
var is_web := OS.has_feature("web")
var is_windows := OS.has_feature("windows")
var is_linux := OS.has_feature("linux")
var is_in_test := ("res://addons/gdUnit4/src/core/GdUnitRunner.tscn" in OS.get_cmdline_args()) and (not is_exported)

var settings: LockpickSettings

var game_version: String = ProjectSettings.get_setting("application/config/version")

@onready var safe_error_dialog: AcceptDialog = %SafeError
@onready var http_request: HTTPRequest = $HTTPRequest
var _non_fullscreen_window_mode := Window.MODE_MAXIMIZED

signal changed_level

var time := 0.0
var physics_time := 0.0
var physics_step := 0

var image_copier
var image_copier_exists:
	get:
		return is_instance_valid(image_copier)

## Currently "unused", as you're always on the editor.
## Gameplay mode will set the window's resolution to the in-game one, and the content will stretch accordingly.
## Editor mode will maximize the window.
var current_mode := Modes.GAMEPLAY:
	set = set_mode
enum Modes {
	GAMEPLAY, EDITOR
}

func _init() -> void:
	if ClassDB.class_exists(&"ClipboardImageCopier"):
		image_copier = ClassDB.instantiate(&"ClipboardImageCopier")
	if not in_editor:
		settings = LockpickSettings.new()

func _ready() -> void:
	set_mode(current_mode)
	
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

func _process(delta: float) -> void:
	time += delta
	RenderingServer.global_shader_parameter_set(&"FPS_TIME", time)
	RenderingServer.global_shader_parameter_set(&"NOISE_OFFSET", Vector2(randf_range(-1000, 1000), randf_range(-1000, 1000)))

func _physics_process(delta: float) -> void:
	physics_time += delta
	physics_step += 1
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
	if current_mode == mode: return
	current_mode = mode 
	if current_mode == Modes.GAMEPLAY:
		_set_viewport_to_gameplay()
	else:
		_set_viewport_to_editor()

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
	
	if settings.pause_when_unfocused and unfocus_timer.is_stopped():
		unfocus_timer.start(settings.seconds_until_unfocus_pause)

func _unfocus_stuff() -> void:
	# Just in case
	if get_tree().root.has_focus():
		return
	if not settings.pause_when_unfocused:
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

static func distance_between_rects(r1: Rect2, r2: Rect2) -> Vector2:
	var rect_diff := r1.merge(r2)
	rect_diff.size -= r1.size + r2.size
	return rect_diff.size.clamp(Vector2.ZERO, Vector2.INF)

func release_gui_focus() -> void:
	if get_viewport().gui_get_focus_owner():
		get_viewport().gui_get_focus_owner().release_focus()
