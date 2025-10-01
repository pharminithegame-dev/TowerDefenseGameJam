extends Node
class_name building_manager

signal building_registered(node: Node3D, kind: StringName)
signal building_unregistered(node: Node3D, kind: StringName)

const KIND_HITSCAN: StringName = &"hitscan"
const KIND_PROJECTILE: StringName = &"projectile"
const GROUP_PLACED: StringName = &"PlacedBuilding"

var hitscan: Dictionary = {}     # int(instance_id) -> Node3D
var projectile: Dictionary = {}  # int(instance_id) -> Node3D

func register_building(node: Node3D, kind: StringName) -> void:
	if node == null:
		return
	var id: int = node.get_instance_id()
	# Accept both lowercase and TitleCase
	if kind == KIND_HITSCAN or kind == StringName("Hitscan"):
		hitscan[id] = node
	elif kind == KIND_PROJECTILE or kind == StringName("Projectile"):
		projectile[id] = node
	else:
		# Default bucket so existing callers don't break
		projectile[id] = node

	if not node.is_in_group(GROUP_PLACED):
		node.add_to_group(GROUP_PLACED)
	if not node.is_connected("tree_exited", Callable(self, "_on_building_tree_exited")):
		node.connect("tree_exited", Callable(self, "_on_building_tree_exited").bind(node))

	emit_signal("building_registered", node, kind)

func unregister_building(node: Node3D) -> void:
	if node == null:
		return
	var id: int = node.get_instance_id()
	var kind: StringName = get_kind_for(node)

	hitscan.erase(id)
	projectile.erase(id)

	if node.is_in_group(GROUP_PLACED):
		node.remove_from_group(GROUP_PLACED)

	emit_signal("building_unregistered", node, kind)

func is_registered(node: Node) -> bool:
	if node == null:
		return false
	var id: int = node.get_instance_id()
	return hitscan.has(id) or projectile.has(id)

func get_kind_for(node: Node3D) -> StringName:
	if node == null:
		return StringName()
	var id: int = node.get_instance_id()
	if hitscan.has(id):
		return KIND_HITSCAN
	if projectile.has(id):
		return KIND_PROJECTILE
	return StringName()

func find_building_root(start: Node) -> Node3D:
	# Walk up until we find the nearest Node3D that appears in our registry.
	var cur: Node = start
	while cur != null:
		if cur is Node3D and is_registered(cur):
			return cur as Node3D
		cur = cur.get_parent()
	return null

func _on_building_tree_exited(node: Node) -> void:
	if node is Node3D:
		var nd: Node3D = node as Node3D
		if is_registered(nd):
			unregister_building(nd)
