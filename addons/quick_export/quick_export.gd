@tool
extends EditorPlugin
var BUTLER := ""
const BASE_EXPORT_DIR := "../../Compiled/Lockpick Editor/"

func _enter_tree() -> void:
	add_tool_menu_item("Quick Export", quick_export)
	BUTLER = FileAccess.get_file_as_string("res://meta/butler_path.txt").split("\n")[0]

const TARGETS: Array[String] = ["Windows", "Linux", "Web"]
var last_versions := {
	"Windows": "",
	"Linux": "",
	"Web": ""
}
const URL := "https://itch.io/api/1/x/wharf/latest?game_id=2027861&channel_name="
var has_finished_http_requests := true
var http_response_countdown := 0

var is_exporting := false
func quick_export() -> void:
	assert(FileAccess.file_exists(BUTLER), "butler doesn't exist at '%s'" % BUTLER)
	assert(DirAccess.dir_exists_absolute(BASE_EXPORT_DIR), "base dir doesn't exist!")
	
	if is_exporting:
		if Input.is_physical_key_pressed(KEY_CTRL):
			print("Overriding the fact that is_exporting is true")
		else:
			print("Already exporting!")
			return
	print("quick_export called")
	is_exporting = true
	
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
	for http in https:
		http.queue_free()
	print("Versions result: %s" % last_versions)
	
	var win_thread := Thread.new()
	var linux_thread := Thread.new()
	var web_thread := Thread.new()
	var threads: Array[Thread] = [win_thread, linux_thread, web_thread]
	win_thread.start(_export_to_target.bind("Windows"))
	linux_thread.start(_export_to_target.bind("Linux"))
	web_thread.start(_export_to_target.bind("Web"))
	var finished := []
	# This initial part is just for debug (remove excluded threads)
	for thread in threads:
		if not thread.is_started():
			finished.push_back(thread)
	for thread in finished:
		threads.erase(thread)
	finished.clear()
	print("Exporting to %d targets" % threads.size())
	
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
		await get_tree().create_timer(0.1)
	print("Finished quick export")
	is_exporting = false

func _export_to_target(target: String) -> String:
	var do_godot_export := true
	var do_butler := true
	var return_message := "%s export:\n" % target
	if not target in ["Windows", "Linux", "Web"]:
		return "Error: target not recognized"
	
	var res := []
	var args := []
	var base_export_dir := BASE_EXPORT_DIR.path_join(target)
	if not DirAccess.dir_exists_absolute(base_export_dir):
		return "Error: path %s doesn't exist" % base_export_dir
	var zip_export_path := base_export_dir.path_join("Lockpick Editor (%s) v%s.zip" % [target, Global.game_version.replace(".","_")])
	var used_export_path := zip_export_path
	
	if FileAccess.file_exists(zip_export_path):
		return_message += "File '%s' already exists.\n" % zip_export_path
		do_godot_export = false
	var tmp_dir := ""
	if target == "Web":
		tmp_dir = base_export_dir.path_join("tmp")
		DirAccess.make_dir_absolute(tmp_dir)
		used_export_path = tmp_dir.path_join("Lockpick Editor (%s) v%s.html" % [target, Global.game_version])
	args.push_back("--path")
	args.push_back(ProjectSettings.globalize_path("res://"))
	args.push_back("--headless")
	args.push_back("--export-release")
	args.push_back(target)
	args.push_back(used_export_path)
	if do_godot_export:
		return_message += "Doing Godot export...\n"
		OS.execute(OS.get_executable_path(), args, res, true)
		if not FileAccess.file_exists(used_export_path):
			return_message += "Seemingly failed to create %s\n" % used_export_path
			#return_message += "Godot export output: %s\n" % res
			return return_message
		if target == "Web":
			DirAccess.rename_absolute(used_export_path, tmp_dir.path_join("index.html"))
			var zip := ZIPPacker.new()
			zip.open(zip_export_path)
			if DirAccess.get_directories_at(tmp_dir).size() != 0:
				return "Error: web export has directories! aborting"
			for file in DirAccess.get_files_at(tmp_dir):
				var path := tmp_dir.path_join(file)
				zip.start_file(file)
				zip.write_file(FileAccess.get_file_as_bytes(path))
				zip.close_file()
				DirAccess.remove_absolute(path)
			zip.close()
			var err := DirAccess.remove_absolute(tmp_dir)
			if err != OK:
				return "Error: couldn't delete temp folder"
		return_message += "Successfully exported to %s at %s\n" % [target, zip_export_path]
	
	if not FileAccess.file_exists(zip_export_path):
		return_message += "Error: %s doesn't actually exist\n" % zip_export_path
		return return_message
	
	# Butler time.
	# reference:
	# butler push "Linux/Lockpick Editor (Linux) v0_3_0_2.zip" l4vo5/i-wanna-lockpick-editor:linux --userversion 0.3.0.2 --if-changed
	if last_versions[target] == "":
		return_message += "Unknown last version, won't do butler\n"
		do_butler = false
	if Global.game_version.naturalnocasecmp_to(last_versions[target]) <= 0:
		return_message += "Last version for %s channel is %s, and the exported version is %s. Won't do butler.\n" % [target, last_versions[target], Global.game_version]
		do_butler = false
	if do_butler:
		return_message += "Pushing with butler...\n"
		var channel_name := target.to_lower()
		args.clear()
		args += [
			"push",
			zip_export_path,
			"l4vo5/i-wanna-lockpick-editor:" + channel_name,
			"--userversion",
			Global.game_version,
			"--if-changed"
		]
		res = []
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

func _exit_tree() -> void:
	remove_tool_menu_item("Quick Export")
