# File: DeleteTool.gd
extends Button

signal object_deleted(node: Node)

@export var target_groups: Array[String] = ["TempPlaced", "Placed"]
@export var raycast_length: float = 200.0
@export var clear_surface_occupied: bool = true
@export var occupied_flag_property: String = "is_occupied"

var _cam: Camera3D
var _delete_mode: bool = false

func _ready() -> void:
	toggle_mode = true
	_cam = get_viewport().get_camera_3d()
	connect("pressed", Callable(self, "_on_button_pressed"))

func _on_button_pressed() -> void:
	if _delete_mode:
		return
	_delete_mode = true
	button_pressed = true

func _finish() -> void:
	_delete_mode = false
	button_pressed = false

func _input(event: InputEvent) -> void:
	if not _delete_mode:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_finish()
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_try_delete_under_mouse()

func _try_delete_under_mouse() -> void:
	if _cam == null:
		_finish()
		return

	var mouse: Vector2 = get_viewport().get_mouse_position()
	var origin: Vector3 = _cam.project_ray_origin(mouse)
	var dir: Vector3 = _cam.project_ray_normal(mouse)
	var to: Vector3 = origin + dir * raycast_length

	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	params.from = origin
	params.to = to
	params.collision_mask = 0x7FFFFFFF

	var hit: Dictionary = get_viewport().world_3d.direct_space_state.intersect_ray(params)
	if hit.is_empty():
		_finish()
		return

	var col: Object = hit.collider
	if not (col is Node):
		_finish()
		return

	var start_node: Node = col
	var victim: Node = _find_node_in_groups(start_node)
	if victim != null:
		if clear_surface_occupied and victim.has_meta("surface"):
			var surface: Object = victim.get_meta("surface") as Object
			if surface != null and _has_property(surface, occupied_flag_property):
				surface.set(occupied_flag_property, false)
		victim.queue_free()
		emit_signal("object_deleted", victim)

	_finish()

func _find_node_in_groups(start: Node) -> Node:
	var n: Node = start
	while n != null:
		for g in target_groups:
			if n.is_in_group(g):
				return n
		n = n.get_parent()
	return null

func _has_property(obj: Object, prop: StringName) -> bool:
	var plist: Array = obj.get_property_list()
	for d in plist:
		# d is a Dictionary like {"name": String, ...}
		if d is Dictionary and d.has("name") and d["name"] == prop:
			return true
	return false
