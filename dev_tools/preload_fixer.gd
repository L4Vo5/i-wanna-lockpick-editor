@tool
extends EditorScript

func _run() -> void:
	var files := {}
	load_files("res://", files)
	var some_file_changed := false
	for file_name: String in files.keys():
		if file_name.get_extension() == "gd":
			if files[file_name] is String:
				some_file_changed = some_file_changed or fix_script(files[file_name], files)
			else:
				for file_path in files[file_name]:
					some_file_changed = some_file_changed or fix_script(file_path, files)
	if !some_file_changed:
		print("No preload issues found.")

func load_files(path: String, files_dict: Dictionary) -> void:
	# Since this is meant to fix preloads, .gdignore stuff can't possibly be relevant
	if FileAccess.file_exists(path.path_join(".gdignore")): return
	
	for file_name in DirAccess.get_files_at(path):
		var file_path := path.path_join(file_name)
		var prev = files_dict.get(file_name)
		if prev == null:
			files_dict[file_name] = file_path
		else:
			if prev is String:
				files_dict[file_name] = [files_dict[file_name], file_path]
			else:
				assert(prev is Array)
			files_dict[file_name].push_back(file_path)
	for dir_name in DirAccess.get_directories_at(path):
		var dir_path = path.path_join(dir_name)
		load_files(dir_path, files_dict)

func fix_script(script_path: String, files: Dictionary) -> bool:
	if script_path == get_script().resource_path:
		return false
	var script_content := FileAccess.get_file_as_string(script_path)
	var pos := -1
	var changed := false
	pos = script_content.find("preload(")
	while pos != -1:
		var start := pos + "preload(\"".length()
		var end := script_content.find("\"", start)
		var old_location := script_content.substr(start, end - start)
		if not FileAccess.file_exists(old_location):
			var line_num := script_content.count("\n", 0, start) + 1
			var new_location = files[old_location.get_file()]
			if new_location is Array:
				print_rich("[b]%s:%d[/b]: Manually fix this preload: [b]%s[/b]. New location is one of [b]%s[/b]" % [script_path, line_num, old_location, new_location])
			elif new_location is String:
				print_rich("%s:%d: Fixing this preload: [b]%s[/b]. New location is: [b]%s[/b]" % [script_path, line_num, old_location, new_location])
				changed = true
				script_content = script_content.replace(old_location, new_location)
		
		pos = script_content.find("preload(\"", pos + 1)
	if changed:
		var file := FileAccess.open(script_path, FileAccess.WRITE)
		file.store_string(script_content)
		file.close()
	return changed
