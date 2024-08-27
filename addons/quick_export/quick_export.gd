@tool
extends EditorPlugin
var BUTLER := ""
var BASE_EXPORT_DIR := ""
var ORIGINAL_EXPORT_DIR := "res://meta/Temp Exports/"

func _enter_tree() -> void:
	add_tool_menu_item("Move Exports", move_exports)
	add_tool_menu_item("Quick Publish", quick_publish)
	BUTLER = FileAccess.get_file_as_string("res://meta/butler_path.txt").split("\n")[0]
	BASE_EXPORT_DIR = FileAccess.get_file_as_string("res://meta/export_dir_path.txt").split("\n")[0]

func _exit_tree() -> void:
	remove_tool_menu_item("Move Export")
	remove_tool_menu_item("Quick Publish")

const TARGETS: Array[String] = ["Windows", "Linux", "Web"]
var last_versions := {
	"Windows": "",
	"Linux": "",
	"Web": ""
}
const URL := "https://itch.io/api/1/x/wharf/latest?game_id=2027861&channel_name="
var has_finished_http_requests := true
var http_response_countdown := 0
var game_version := ""

# Comment targets out here
var targets := [
	"Windows",
	"Linux",
	"Web",
]

var is_moving_exports := false
func move_exports() -> void:
	game_version = ProjectSettings.get_setting("application/config/version")
	assert(DirAccess.dir_exists_absolute(BASE_EXPORT_DIR), "base dir doesn't exist!")
	if is_moving_exports:
		if Input.is_physical_key_pressed(KEY_CTRL):
			print("Overriding the fact that is_moving_exports is true")
		else:
			print("Already moving exports!")
			return
	is_moving_exports = true
	for target in targets:
		await move_export(target)

var is_publishing := false
func quick_publish() -> void:
	game_version = ProjectSettings.get_setting("application/config/version")
	assert(FileAccess.file_exists(BUTLER), "butler doesn't exist at '%s'" % BUTLER)
	if not await update_last_versions(): return
	
	if is_publishing:
		if Input.is_physical_key_pressed(KEY_CTRL):
			print("Overriding the fact that is_publishing is true")
		else:
			print("Already publishing!")
			return
	print("quick_publish called")
	is_publishing = true
	
	var threads: Array[Thread] = []
	for target in targets:
		var thread := Thread.new()
		var err := thread.start(_publish_for_target.bind(target))
		if err == OK:
			threads.push_back(thread)
		else:
			print("Error creating thread for target %s" % target)
	var finished := []
	print("Publishing to %d targets" % threads.size())
	
	while not threads.is_empty() and is_inside_tree():
		for thread in threads:
			if not thread.is_alive():
				var ret = thread.wait_to_finish()
				if not ret is String:
					print("ret isn't string wtf? ret is: %s" % str(ret))
				print("Thread finished: %s" % ret)
				finished.push_back(thread)
		for thread in finished:
			threads.erase(thread)
		finished.clear()
		await get_tree().process_frame
	print("Finished quick publish")
	is_publishing = false

# pls await this
func update_last_versions() -> bool:
	# We'll make sure to always double-check the last versions on itch
	for key in last_versions:
		last_versions[key] = ""
	
	var https := []
	http_response_countdown = TARGETS.size()
	has_finished_http_requests = false
	for target in TARGETS:
		var http := HTTPRequest.new()
		http.use_threads = false
		add_child(http)
		http.request_completed.connect(_http_request_completed.bind(target))
		http.request(URL + target.to_lower())
	print("Awaiting response for versions...")
	
	var wait_time := 0.0
	while (not has_finished_http_requests) and (wait_time <= 30):
		await get_tree().create_timer(0.1).timeout
		wait_time += 0.1
		if wait_time > 30:
			print("Couldn't finish http requests in time...")
			return false
	for http in https:
		http.queue_free()
	print("Versions result: %s" % last_versions)
	return true

func get_paths_for_target(target: String) -> Dictionary:
	var base_export_dir := BASE_EXPORT_DIR.path_join(target)
	var zip_export_path := base_export_dir.path_join("Lockpick Editor (%s) v%s.zip" % [target, game_version.replace(".","_")])
	return {
		base_export_dir = base_export_dir,
		zip_export_path = zip_export_path,
	}

func move_export(target: String) -> void:
	# The awaits are to not hang up the engine as much, and let print statements through.
	print("Moving export for target: %s" % target)
	var path := ORIGINAL_EXPORT_DIR.path_join(target)
	path = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(path):
		print(path, " doesn't exist")
	var base_name := "Lockpick Editor (%s)" % target
	var new_name := "Lockpick Editor (%s) v%s" % [target, game_version.replace(".","_")]
	var files := DirAccess.get_files_at(path)
	var expected_endings: Array = {
		"Windows": [".pck", ".exe"],
		"Linux": [".pck", ".x86_64"],
		"Web": [".html",".wasm",
".png",".pck",".js",".icon.png",".audio.worklet.js",".apple-touch-icon.png",]
	}[target]
	var not_found := []
	for ending: String in expected_endings:
		var expected_file_name := base_name + ending
		var found := false
		for file_name in files:
			if file_name == expected_file_name:
				found = true
				break
		if not found:
			not_found.push_back(expected_file_name)
	if not not_found.is_empty():
		print("Couldn't find the following files: ", not_found)
		return
	if not files.size() == expected_endings.size():
		print("Expected ", expected_endings.size(), " files, but found ", files.size())
		return
	await get_tree().process_frame
	var zip_export_path: String = get_paths_for_target(target).zip_export_path
	var zip := ZIPPacker.new()
	zip.open(zip_export_path)
	print("Creating zip at ", zip_export_path)
	var err: int
	for ending: String in expected_endings:
		var file_name := base_name + ending
		var file_path := path.path_join(file_name)
		var new_file_name := new_name + ending
		if target == "Web":
			# otherwise it causes errors ad index.html will reference the old names.
			# web exports aren't meant to be downloaded anyways, so it's fine if
			# the name doesn't have the version, I think. at least, it's easier
			# than modifying index.html
			new_file_name = file_name
		if file_name.get_extension() == "html":
			new_file_name = "index.html"
		var new_file_path := path.path_join(new_file_name)
		print(file_name, " -> ", new_file_name)
		await get_tree().process_frame
		err = zip.start_file(new_file_name)
		assert(err == OK)
		err = zip.write_file(FileAccess.get_file_as_bytes(file_path))
		assert(err == OK)
		err = zip.close_file()
		assert(err == OK)
	print("closing zip")
	await get_tree().process_frame
	err = zip.close()
	assert(err == OK)
	assert(FileAccess.file_exists(zip_export_path))
	var zip_file := FileAccess.open(zip_export_path, FileAccess.READ)
	var size_in_bytes := zip_file.get_length()
	zip_file.close()
	var size_in_megabytes := size_in_bytes / 1024.0 / 1024.0
	assert(size_in_megabytes > (6 if target == "Web" else 20))
	assert(size_in_megabytes < 100)
	print(zip_export_path, " created (", snappedf(size_in_megabytes, 0.01), "MB)")
	print("Deleting temp files...")
	await get_tree().process_frame
	for ending: String in expected_endings:
		var file_name := base_name + ending
		var file_path := path.path_join(file_name)
		err = DirAccess.remove_absolute(file_path)
		assert(err == OK)
		await get_tree().process_frame
	assert(DirAccess.get_files_at(path).is_empty())

# Butler time.
# reference:
# butler push "Linux/Lockpick Editor (Linux) v0_3_0_2.zip" l4vo5/i-wanna-lockpick-editor:linux --userversion 0.3.0.2 --if-changed
func _publish_for_target(target: String) -> String:
	var zip_export_path: String = get_paths_for_target(target).zip_export_path
	var return_message := ""
	var do_butler := true
	if last_versions[target] == "":
		return_message += "Unknown last version, won't do butler\n"
		do_butler = false
	if game_version.naturalnocasecmp_to(last_versions[target]) <= 0:
		return_message += "Last version for %s channel is %s, and the exported version is %s. Won't do butler.\n" % [target, last_versions[target], game_version]
		do_butler = false
	if do_butler:
		return_message += "Pushing with butler...\n"
		var channel_name := target.to_lower()
		var args := [
			"push",
			zip_export_path,
			"l4vo5/i-wanna-lockpick-editor:" + channel_name,
			"--userversion",
			game_version,
			"--if-changed"
		]
		var res := []
		OS.execute(BUTLER, args, res, true)
		return_message += "Butler output: %s\n" % res
	
	return return_message

func _http_request_completed(_result, _response_code, _headers, body: PackedByteArray, target: String):
	var s := body.get_string_from_ascii()
	var dic = JSON.parse_string(s)
	if (dic is Dictionary and dic.has("latest")):
		last_versions[target] = dic["latest"]
		print("Last version for %s: %s" % [target, dic["latest"]])
	else:
		last_versions[target] = ""
	http_response_countdown -= 1
	if http_response_countdown == 0:
		has_finished_http_requests = true
