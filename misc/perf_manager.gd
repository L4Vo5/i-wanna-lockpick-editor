@tool
extends Node

# each key is [total time, sub-time, count] where sub-time deducts other measured times that happened in between, and count is times called
var times := {}
var balance := {}
# inner array is [name, start time, sub-start time, sub-time sum]
var stack: Array[Array] = []

var baseline_time := 0.0
func _ready() -> void:
	if Global.in_editor: return
	if Global.is_exported: return
#	return
	print("node count before: %d" % get_tree().get_node_count())
	var l = preload("res://level_elements/level.tscn").instantiate()
	l.level_data = SaveLoad.load_from("user://levels/many doors.lvl")
#	l.level_data = SaveLoad.load_from("user://levels/many_counts.lvl")
#	l.level_data = SaveLoad.load_from("user://levels/big_doors.lvl")
	add_child(l)
	# by making l reset now, we can test only soft resets if we also bind false
	l.reset()
	await test_func(l.reset.bind(true), 30)
	print("node count after: %d" % get_tree().get_node_count())
	l.queue_free()

func _input(event: InputEvent) -> void:
	if Global.in_editor: return
	if Global.is_exported: return
	if event is InputEventKey:
		if event.is_pressed():
			if event.keycode == KEY_F12:
				print_report()

func start(who: StringName) -> bool:
	if Global.in_editor: return true
	if not balance.has(who):
		balance[who] = 0
	if not times.has(who):
		times[who] = [0, 0, 0]
	# "pause" the last one
	if stack.size() != 0:
		var i := stack.size() - 1
		stack[i][3] += Time.get_ticks_usec() - stack[i][2]
	stack.push_back([who, Time.get_ticks_usec(), Time.get_ticks_usec(), 0])
	balance[who] += 1
	return true

func end(who: StringName) -> bool:
	if Global.in_editor: return true
	var data = stack.pop_back()
	assert(data[0] == who)
	data[3] += Time.get_ticks_usec() - data[2]
	times[who][2] += 1
	times[who][1] += data[3]
	times[who][0] += Time.get_ticks_usec() - data[1]
	balance[who] -= 1
	# "resume" the last one
	if stack.size() != 0:
		var i := stack.size() - 1
		stack[i][2] = Time.get_ticks_usec()
	return true

func clear() -> void:
	if Global.in_editor: return
	check_balances()
	times.clear()
	balance.clear()
	stack.clear()

func check_balances() -> bool:
	if Global.in_editor: return true
	for b in balance.values():
		assert(b == 0)
	assert(stack.is_empty())
	return true

func print_report() -> void:
	if Global.in_editor: return
	check_balances()
	for key in times:
		print_rich("%s (%d calls): [b]%s[/b] total, [b]%s[/b] self" % [key, times[key][2], get_time_string(times[key][0]), get_time_string(times[key][1])])
	clear()

func test_func(f: Callable, repetitions: int) -> void:
	print_report()
	clear()
	var who := "==== test_func (%s, %d repetitions) ====" % [f.get_method(), repetitions]
	var time_collections := []
	for i in repetitions:
		start(who)
		f.call()
		end(who)
		time_collections.push_back(times.duplicate(true))
		# Must wait for a frame for nodes to be freed
		await get_tree().process_frame
		await get_tree().physics_frame
		clear()
	# time for statistics babey
	start("Statistic calculations")
	var sum := {}
	var amount := time_collections.size()
	for time in time_collections:
		for key in time:
			if not sum.has(key):
				sum[key] = [0, 0, 0]
			sum[key][0] += time[key][0]
			sum[key][1] += time[key][1]
			sum[key][2] += time[key][2]
	var avgs := {}
	for key in sum:
		avgs[key] = [sum[key][0] / float(amount), sum[key][1] / float(amount), sum[key][2] / float(amount)]
	var sds := {}
	for time in time_collections:
		for key in time:
			if not sds.has(key):
				sds[key] = [0.0, 0.0]
			sds[key][0] += pow(time[key][0] - avgs[key][0], 2)
			sds[key][1] += pow(time[key][1] - avgs[key][1], 2)
	for key in sds:
		sds[key][0] = sqrt(sds[key][0] / amount)
		sds[key][1] = sqrt(sds[key][1] / amount)
	print_rich("%s: total [b]%s[/b], avg [b]%s[/b]" % [who, get_time_string(sum[who][0]), get_time_string(avgs[who][0])])
	for key in sum:
		if key == who: continue
		print_rich("%s (%d calls): avg [b]%s[/b], sd [b]%s[/b]" % [key, avgs[key][2], get_time_string(avgs[key][1]), get_time_string(sds[key][1])])
	end("Statistic calculations")
	print_report()
	clear()

func get_time_string(usec: float) -> String:
	if usec < 1_000:
		return "%.3f μs" % (usec) 
	elif usec < 1_000_000:
		return "%.3f ms" % (usec / 1_000.0) 
	elif usec < 60_000_000:
		return "%.3f s" % (usec / 1_000_000.0) 
	elif usec < 360_000_000_000:
		return "%.3f m" % (usec / 60_000_000.0) 
	else:
		return "%.3f h" % (usec / 360_000_000_000.0) 
