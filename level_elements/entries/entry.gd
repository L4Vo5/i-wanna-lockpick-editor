@tool
extends Control
class_name Entry

var entry_data: EntryData

func enter() -> void:
	print("[S] %s: Enter" % self)
