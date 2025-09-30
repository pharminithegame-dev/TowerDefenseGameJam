# File: BoxPlaceButton.gd
extends Button

@export var world_root: Node3D
@export var box_size: Vector3 = Vector3.ONE
@export var raycast_length: float = 500.0

var _placing: bool = false
var _ghost: Node3D
var _cam: Camera3D

func _ready() -> void:
	toggle_mode = true
	_cam = get_viewport().get_camera_3d()
	pressed.connect(_on_pressed)
	set_process(true)
	set_process_unhandled_input(true)

func _on_pressed() -> void:
	if _placing:
		return
	_placing = true
	button_pressed = true
	_ensure_world_root()
	_ghost = _make_box_instance(true)
	world_root.add_child(_ghost)

func _unhandled_input(event: InputEvent) -> void:
	if not _placing:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var hit: Dictionary = _raycast_mouse()
			if not hit.is_empty() and _is_valid_plane(hit):
				var final_box: Node3D = _make_box_instance(false)
				var pos: Vector3 = hit.get("position") as Vector3
				final_box.global_transform.origin = pos
				world_root.add_child(final_box)
				_exit_placement()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_exit_placement()
	elif event is InputEventKey:
		var k: InputEventKey = event as InputEventKey
		if k.pressed and k.keycode == KEY_ESCAPE:
			_exit_placement()

func _process(_dt: float) -> void:
	if not _placing or _ghost == null:
		return
	var hit: Dictionary = _raycast_mouse()
	if not hit.is_empty():
		var pos: Vector3 = hit.get("position") as Vector3
		_ghost.global_transform.origin = pos
		_set_ghost_valid(_is_valid_plane(hit))

func _raycast_mouse() -> Dictionary:
	if _cam == null:
		_cam = get_viewport().get_camera_3d()
		if _cam == null:
			return {}
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = _cam.project_ray_origin(mouse)
	var dir: Vector3 = _cam.project_ray_normal(mouse)
	var to: Vector3 = from + dir * raycast_length

	var space_state: PhysicsDirectSpaceState3D = get_viewport().get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	return space_state.intersect_ray(query)

func _is_valid_plane(hit: Dictionary) -> bool:
	var collider: Object = hit.get("collider")
	if collider is MeshInstance3D:
		var mi: MeshInstance3D = collider as MeshInstance3D
		if mi.mesh is PlaneMesh:
			return true
	var n: Vector3 = (hit.get("normal", Vector3.UP) as Vector3)
	return n.dot(Vector3.UP) > 0.95

func _set_ghost_valid(ok: bool) -> void:
	if _ghost == null:
		return
	var mi: MeshInstance3D = _ghost.get_node_or_null("Mesh") as MeshInstance3D
	if mi:
		var mat: Material = mi.get_active_material(0)
		if mat == null or not (mat is StandardMaterial3D):
			mat = StandardMaterial3D.new()
			mi.set_surface_override_material(0, mat)
		var sm: StandardMaterial3D = mat as StandardMaterial3D
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.albedo_color = (Color(0, 1, 0, 0.5) if ok else Color(1, 0, 0, 0.5))

func _make_box_instance(is_ghost: bool) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = ("GhostBox" if is_ghost else "Box")

	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "Mesh"
	var box: BoxMesh = BoxMesh.new()
	box.size = box_size
	mesh.mesh = box
	root.add_child(mesh)

	if is_ghost:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1, 1, 1, 0.5)
		mesh.set_surface_override_material(0, mat)
	else:
		var col: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = box_size
		col.shape = shape
		root.add_child(col)

	return root

func _exit_placement() -> void:
	_placing = false
	button_pressed = false
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null

func _ensure_world_root() -> void:
	if world_root:
		return
	var cs: Node = get_tree().current_scene
	if cs and cs is Node3D:
		world_root = cs
	elif cs:
		for c in cs.get_children():
			if c is Node3D:
				world_root = c
				break
