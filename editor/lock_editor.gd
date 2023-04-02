extends Control

@onready var lock: LockVisual = %Lock

func set_lock_data(data: LockData) -> void:
	lock.lock_data = data

