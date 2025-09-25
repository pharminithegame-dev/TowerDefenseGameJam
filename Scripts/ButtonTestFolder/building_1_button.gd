extends Button

@export_node_path("Node3D") var world_root_path: NodePath
@export_node_path("Camera3D") var camera_path: NodePath
@export var box_size: Vector3 = Vector3.ONE
@export var raycast_length: float = 20000.0

# Validation
@export var accept_plane_mesh: bool = true
@export var accept_horizontal_surfaces: bool = true
@export var require_group_match: bool = false
@export var place_on_groups: Array[StringName] = [&"Placeable"]

# Fallback display when no collider is hit
@export var use_fallback_plane: bool = true
@export var fallback_plane_height: float = 0.0

# Debug
@export var debug_logs: bool = false

@onready var world_root: Node3D = get_node_or_null(world_root_path) as Node3D
@onready var camera_node: Camera3D = get_node_or_null(camera_path) as Camera3D

var _placing: bool = false
var _ghost: Node3D

func _ready() -> void:
	toggle_mode = true
	set_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	if _placing:
		return
	if world_root == null:
		push_error("[BoxPlaceButton] Set world_root_path in the Inspector.")
		return
	if camera_node == null:
		push_error("[BoxPlaceButton] Set camera_path in the Inspector.")
		return

	_placing = true
	button_pressed = true
	release_focus()

	_ghost = _make_box_instance(true)
	world_root.add_child(_ghost)

	# Pop the ghost ~3m in front of camera so it's visible immediately
	var fwd: Vector3 = -camera_node.global_transform.basis.z
	var start_pos: Vector3 = camera_node.global_transform.origin + fwd * 3.0
	_ghost.global_transform.origin = start_pos
	_ghost.visible = true
	if debug_logs: print("[BoxPlaceButton] Ghost spawned at ", start_pos)

func _input(event: InputEvent) -> void:
	if not _placing:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var hit: Dictionary = _raycast_mouse()
			if debug_logs: print("[BoxPlaceButton] LMB pressed. Hit: ", hit)
			if not hit.is_empty() and _is_valid_hit(hit):
				var pos: Vector3 = hit.get("position") as Vector3
				var final_box: Node3D = _make_box_instance(false)
				final_box.global_transform.origin = pos
				world_root.add_child(final_box)
				if debug_logs: print("[BoxPlaceButton] Placed at ", pos)
				_exit_placement()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if debug_logs: print("[BoxPlaceButton] Cancelled with RMB.")
			_exit_placement()

func _unhandled_input(event: InputEvent) -> void:
	_input(event)

func _process(_dt: float) -> void:
	if not _placing or _ghost == null:
		return

	var hit: Dictionary = _raycast_mouse()
	if not hit.is_empty():
		var pos: Vector3 = hit.get("position") as Vector3
		_ghost.global_transform.origin = pos
		_ghost.visible = true
		_set_ghost_valid(_is_valid_hit(hit))
	else:
		if use_fallback_plane:
			var pos_fb: Vector3 = _project_to_y_plane(camera_node, fallback_plane_height)
			_ghost.global_transform.origin = pos_fb
			_ghost.visible = true
			_set_ghost_valid(false)
			if debug_logs: print_verbose("[BoxPlaceButton] No physics hit; fallback at ", pos_fb)
		else:
			_ghost.visible = false

func _raycast_mouse() -> Dictionary:
	# Use the camera's viewport for mouse position (SubViewport-safe)
	var vp: Viewport = camera_node.get_viewport()
	var mouse: Vector2 = vp.get_mouse_position()
	var from: Vector3 = camera_node.project_ray_origin(mouse)
	var dir: Vector3 = camera_node.project_ray_normal(mouse)
	var to: Vector3 = from + dir * raycast_length

	var space_state: PhysicsDirectSpaceState3D = world_root.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	# query.collision_mask = ...  # set if you want layer filtering
	return space_state.intersect_ray(query)

# Always returns a Vector3 (no Variant/null), so no "Variant inferred" warning.
func _project_to_y_plane(cam: Camera3D, height: float) -> Vector3:
	var vp: Viewport = cam.get_viewport()
	var mouse: Vector2 = vp.get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse)
	var dir: Vector3 = cam.project_ray_normal(mouse)
	if absf(dir.y) < 1e-6:
		return from + dir * 10.0
	var t: float = (height - from.y) / dir.y
	return from + dir * t

func _is_valid_hit(hit: Dictionary) -> bool:
	var collider: Object = hit.get("collider")

	if require_group_match and collider is Node:
		var node_c: Node = collider
		var ok: bool = false
		for g: StringName in place_on_groups:
			if node_c.is_in_group(g):
				ok = true
				break
		if not ok:
			return false

	if accept_plane_mesh and collider is MeshInstance3D:
		var mi: MeshInstance3D = collider
		if mi.mesh is PlaneMesh:
			return true

	if accept_horizontal_surfaces:
		var nrm: Vector3 = (hit.get("normal", Vector3.UP) as Vector3)
		if nrm.dot(Vector3.UP) > 0.95:
			return true

	return false

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
	release_focus()
