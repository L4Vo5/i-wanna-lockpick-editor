@tool
extends Node

# in the godot editor, as opposed to the level editor
var in_editor := Engine.is_editor_hint()
var in_level_editor := false
## Will basically be true if there's a player moving around
var is_playing := false
var game_version = ProjectSettings.get_setting("application/config/game_version")
@onready var key_pad: Control = %KeyPad
@onready var fatal_error_dialog: AcceptDialog = %FatalError
@onready var safe_error_dialog: AcceptDialog = %SafeError
@onready var http_request: HTTPRequest = $HTTPRequest

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

enum Modes {
	GAMEPLAY, EDITOR
}

func _ready() -> void:
	if in_editor:
		key_pad.hide()
	set_mode(_current_mode)
	
	# Look for update...
	var dl_button := update_dialog.add_button("Download", true)
	dl_button.pressed.connect(_open_download_page)
	http_request.request_completed.connect(_http_request_completed)

	var error = http_request.request("https://l4vo5.itch.io/i-wanna-lockpick-editor")
	if error != OK:
		push_error("An error occurred in the HTTP request.")

@onready var update_dialog: AcceptDialog = $Update/UpdateDialog
var newer_version := ""
func _http_request_completed(result, response_code, headers, body: PackedByteArray):
	var s := body.get_string_from_ascii()
	var start := s.find("The current version is ")
	start += "The current version is ".length()
	# Gotta find 3 version dots + the final dot:
	var end := start
	for i in 4:
		end = s.find(".", end+1)
	newer_version = s.substr(start, end - start)
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

func _physics_process(delta: float) -> void:
	physics_time += delta
	physics_step += 1
	RenderingServer.global_shader_parameter_set(&"FPS_TIME", physics_time)
	RenderingServer.global_shader_parameter_set(&"NOISE_OFFSET", Vector2(randf_range(-1000, 1000), randf_range(-1000, 1000)))
	if not in_editor:
		# TODO: No real need to do this every frame
		key_pad.update_pos()

# sets the viewport according to gameplay settings
func _set_viewport_to_gameplay() -> void:
	if in_editor: return
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS

# sets the viewport according to editor settings
func _set_viewport_to_editor() -> void:
	if in_editor: return
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.mode = Window.MODE_MAXIMIZED

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
	
