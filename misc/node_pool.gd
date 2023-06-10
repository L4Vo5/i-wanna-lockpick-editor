@tool
extends Node
var known_scenes := {}

# nodes that are free to use
var pooled_nodes := {
	
}

var total_instantiated_nodes := 0
# please use return_node to return them uwu
func pool_node(scene: PackedScene) -> Node:
	var node: Node
	var arr = pooled_nodes.get(scene.resource_path)
	if arr != null:
		if arr.size() != 0:
			node = arr.pop_back()
	else:
		pooled_nodes[scene.resource_path] = []
	if node == null:
		total_instantiated_nodes += 1
		node = scene.instantiate()
	return node

func return_node(node: Node) -> void:
	pooled_nodes[node.scene_file_path].push_back(node)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for nodes in pooled_nodes.values():
			for node in nodes:
				node.free()
