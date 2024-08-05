@tool
extends Resource
class_name KeyRebindAction

@export var action_name: StringName
@export var label: String
@export var tooltip: String

var rebinder: KeyRebindButton
var default_bind: InputEvent
