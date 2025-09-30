extends Node
class_name building_manager

signal building_registered(node: Node3D, kind: StringName)
signal building_unregistered(node: Node3D, kind: StringName)

var hitscan: Dictionary = {}
var projectile: Dictionary = {}

const GROUP_PLACED := &"PlacedBuilding"

func register_building(node: Node3D, kind: StringName) -> void:
	if node == null:
		return
	var id: int = node.get_instance_id()
	match kind:
		&"hitscan":
			hitscan[id] = node
		&"projectile":
			projectile[id] = node
		_:
			push_warning("Unknown building kind: %s" % String(kind))
	node.add_to_group(GROUP_PLACED)
	node.set_meta("building_kind", kind)
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
	if node.has_meta("building_kind"):
		node.remove_meta("building_kind")
	emit_signal("building_unregistered", node, kind)

func get_kind_for(node: Node) -> StringName:
	if node == null:
		return StringName()
	if node.has_meta("building_kind"):
		return node.get_meta("building_kind") as StringName
	var id: int = node.get_instance_id()
	if hitscan.has(id):
		return &"hitscan"
	if projectile.has(id):
		return &"projectile"
	return StringName()

func is_registered(node: Node) -> bool:
	if node == null:
		return false
	var id: int = node.get_instance_id()
	return hitscan.has(id) or projectile.has(id)

func find_building_root(start: Node) -> Node3D:
	var cur: Node = start
	while cur != null:
		if cur is Node3D and is_registered(cur):
			return cur as Node3D
		cur = cur.get_parent()
	return null
