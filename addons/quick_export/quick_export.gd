@tool
extends EditorPlugin
const BUTLER := "[Oops shouldn't leave that around]"
const BASE_EXPORT_DIR := "../../Compiled/Lockpick Editor/"

func _enter_tree() -> void:
	add_tool_menu_item("Quick Export", quick_export)

func quick_export() -> void:
	print("quick_export called")
	assert(FileAccess.file_exists(BUTLER), "butler doesn't exist at '%s'" % BUTLER)
	assert(DirAccess.dir_exists_absolute(BASE_EXPORT_DIR), "base dir doesn't exist!")
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
				var ret: String = thread.wait_to_finish()
				print("Thread finished: %s" % ret)
				finished.push_back(thread)
		for thread in finished:
			threads.erase(thread)
		finished.clear()
		await get_tree().process_frame

func _export_to_target(target: String) -> String:
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
	OS.execute(OS.get_executable_path(), args, res, true)
	if not FileAccess.file_exists(used_export_path):
		return_message += "Seemingly failed to create %s\n" % used_export_path
		return_message += "Godot export output: %s\n" % res
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
	
	# Butler time.
	# reference:
	# butler push "Linux/Lockpick Editor (Linux) v0_3_0_2.zip" l4vo5/i-wanna-lockpick-editor:linux --userversion 0.3.0.2 --if-changed
	args.clear()
	args += [
		"push",
		zip_export_path,
		"l4vo5/i-wanna-lockpick-editor:" + target.to_lower(),
		"--userversion",
		Global.game_version,
		"--if-changed"
	]
	res = []
	OS.execute(BUTLER, args, res, true)
	return_message += "Butler output: %s\n" % res
	
	return return_message

func _exit_tree() -> void:
	remove_tool_menu_item("Quick Export")
