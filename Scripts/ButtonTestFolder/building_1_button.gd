extends Button

# --- Assign these in the Inspector ---
@export_node_path("Node3D") var world_root_path: NodePath
@export_node_path("Camera3D") var camera_path: NodePath
@export var building_scene: PackedScene = preload("res://scenes/buildings/HitscanBuilding.tscn")

@export var raycast_length: float = 20000.0

# Placement area (node-based)
@export var use_placeable_root: bool = false                       # turn on to restrict placement to a node subtree
@export_node_path("Node") var placeable_root_path: NodePath        # pick your "placeable area" node
@export var allow_descendants_of_placeable: bool = true            # allow any child under that node

# Other validators (optional)
@export var accept_plane_mesh: bool = true
@export var accept_horizontal_surfaces: bool = true
@export var min_up_dot: float = 0.2                                # 0..1; raise to require flatter ground

# Fallback when no collider is hit (ghost visibility)
@export var use_fallback_plane: bool = true
@export var fallback_plane_height: float = 0.0

# Debug
@export var debug_logs: bool = false

@onready var world_root: Node3D = get_node_or_null(world_root_path) as Node3D
@onready var camera_node: Camera3D = get_node_or_null(camera_path) as Camera3D
@onready var placeable_root: Node = get_node_or_null(placeable_root_path) as Node

var _placing: bool = false
var _ghost: Node3D
var _ghost_mat_ok: StandardMaterial3D
var _ghost_mat_bad: StandardMaterial3D

func _ready() -> void:
	toggle_mode = true
	set_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)
	pressed.connect(_on_pressed)

	_ghost_mat_ok = StandardMaterial3D.new()
	_ghost_mat_ok.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat_ok.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat_ok.albedo_color = Color(0, 1, 0, 0.45)

	_ghost_mat_bad = StandardMaterial3D.new()
	_ghost_mat_bad.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat_bad.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat_bad.albedo_color = Color(1, 0, 0, 0.45)

func _on_pressed() -> void:
	if _placing:
		return
	if world_root == null:
		push_error("[PlaceButton] Set world_root_path in the Inspector.")
		return
	if camera_node == null:
		push_error("[PlaceButton] Set camera_path in the Inspector.")
		return
	if building_scene == null:
		push_error("[PlaceButton] building_scene is not assigned.")
		return

	_placing = true
	button_pressed = true
	release_focus()

	_ghost = _make_building_instance(true)
	if _ghost == null:
		push_error("[PlaceButton] building_scene root was not a Node3D.")
		_exit_placement()
		return

	world_root.add_child(_ghost)

	var fwd: Vector3 = -camera_node.global_transform.basis.z
	var start_pos: Vector3 = camera_node.global_transform.origin + fwd * 3.0
	_ghost.global_transform.origin = start_pos
	_ghost.visible = true
	if debug_logs:
		print("[PlaceButton] Ghost spawned at ", start_pos)

func _input(event: InputEvent) -> void:
	if not _placing:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var hit: Dictionary = _raycast_mouse()
			if debug_logs: print("[PlaceButton] LMB pressed. Hit: ", hit)
			if not hit.is_empty() and _is_valid_hit(hit):
				var pos: Vector3 = hit.get("position") as Vector3
				var final_inst: Node3D = _make_building_instance(false)
				if final_inst != null:
					final_inst.global_transform.origin = pos
					world_root.add_child(final_inst)
					if debug_logs: print("[PlaceButton] Placed at ", pos)
				_exit_placement()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if debug_logs: print("[PlaceButton] Cancelled with RMB.")
			_exit_placement()
	elif event is InputEventKey:
		var k: InputEventKey = event
		if k.pressed and k.keycode == KEY_ESCAPE:
			if debug_logs: print("[PlaceButton] Cancelled with Esc.")
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
			if debug_logs: print_verbose("[PlaceButton] No physics hit; fallback at ", pos_fb)
		else:
			_ghost.visible = false

# --- Placement helpers ---

func _make_building_instance(is_ghost: bool) -> Node3D:
	var inst_node := building_scene.instantiate()
	if inst_node == null:
		return null
	if not (inst_node is Node3D):
		return null

	var root: Node3D = inst_node as Node3D

	if is_ghost:
		_apply_material_recursive(root, _ghost_mat_ok)
		_set_cast_shadows_recursive(root, false)
		_enable_collisions_recursive(root, false)
	return root

func _set_ghost_valid(ok: bool) -> void:
	if _ghost == null:
		return
	_apply_material_recursive(_ghost, (_ghost_mat_ok if ok else _ghost_mat_bad))

func _apply_material_recursive(node: Node, mat: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		var real_surfaces: int = (mi.mesh.get_surface_count() if mi.mesh != null else 0)
		for i in range(real_surfaces):
			mi.set_surface_override_material(i, mat)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		if child is Node:
			_apply_material_recursive(child, mat)

func _set_cast_shadows_recursive(node: Node, on: bool) -> void:
	if node is GeometryInstance3D:
		var gi: GeometryInstance3D = node
		gi.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for child in node.get_children():
		if child is Node:
			_set_cast_shadows_recursive(child, on)

func _enable_collisions_recursive(node: Node, enabled: bool) -> void:
	if node is CollisionObject3D:
		var co: CollisionObject3D = node
		co.collision_layer = (co.collision_layer if enabled else 0)
		co.collision_mask = (co.collision_mask if enabled else 0)
		if co is Area3D:
			var ar: Area3D = co
			ar.monitoring = enabled
			ar.monitorable = enabled
	for child in node.get_children():
		if child is Node:
			_enable_collisions_recursive(child, enabled)

# --- Raycast / math ---

func _raycast_mouse() -> Dictionary:
	var vp: Viewport = camera_node.get_viewport()
	var mouse: Vector2 = vp.get_mouse_position()
	var from: Vector3 = camera_node.project_ray_origin(mouse)
	var dir: Vector3 = camera_node.project_ray_normal(mouse)
	var to: Vector3 = from + dir * raycast_length
	var space_state: PhysicsDirectSpaceState3D = world_root.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	return space_state.intersect_ray(query)

func _project_to_y_plane(cam: Camera3D, height: float) -> Vector3:
	var vp: Viewport = cam.get_viewport()
	var mouse: Vector2 = vp.get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse)
	var dir: Vector3 = cam.project_ray_normal(mouse)
	if absf(dir.y) < 1e-6:
		return from + dir * 10.0
	var t: float = (height - from.y) / dir.y
	return from + dir * t

# --- Node-based validity ---

func _is_valid_hit(hit: Dictionary) -> bool:
	var collider: Object = hit.get("collider")

	# Restrict to a specific node (or its subtree)
	if use_placeable_root:
		if placeable_root == null:
			return false
		if not (collider is Node):
			return false
		var n: Node = collider
		var ok_node: bool = (n == placeable_root) or (allow_descendants_of_placeable and placeable_root.is_ancestor_of(n))
		if not ok_node:
			return false

	# Optional additional checks
	if accept_plane_mesh and collider is MeshInstance3D:
		var mi: MeshInstance3D = collider
		if mi.mesh is PlaneMesh:
			return true

	if accept_horizontal_surfaces:
		var nrm: Vector3 = (hit.get("normal", Vector3.UP) as Vector3)
		if nrm.dot(Vector3.UP) >= min_up_dot:
			return true

	# If you require the node constraint only, you could 'return true' here when use_placeable_root is true.
	# As written, both node constraint AND one of the optional checks must pass.
	return use_placeable_root and placeable_root != null

func _exit_placement() -> void:
	_placing = false
	button_pressed = false
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	release_focus()
