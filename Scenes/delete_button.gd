extends TextureButton

@export_node_path("Camera3D") var camera_path: NodePath
@export var raycast_length: float = 10000.0
@export var collide_with_bodies: bool = true
@export var collide_with_areas: bool = false
@export var ray_collision_mask: int = 0xFFFFFFFF
@export var require_registered: bool = true
@export var debug_logs: bool = false

@export var highlight_color: Color = Color(1.0, 0.5, 0.1, 0.15)
@export var highlight_emission: Color = Color(1.0, 0.6, 0.2, 1.0)

var camera: Camera3D
var mgr: building_manager

var _selected: Node3D = null
var _highlight_mat: StandardMaterial3D
var _saved_mats: Dictionary = {}

func _ready() -> void:
	toggle_mode = false
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

	camera = (get_node_or_null(camera_path) as Camera3D) if camera_path != NodePath() else get_viewport().get_camera_3d()
	_resolve_manager()

	_highlight_mat = StandardMaterial3D.new()
	_highlight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_mat.albedo_color = highlight_color
	_highlight_mat.emission_enabled = true
	_highlight_mat.emission = highlight_emission

	set_process_unhandled_input(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _resolve_manager() -> void:
	mgr = get_node_or_null("/root/building_manager") as building_manager
	if mgr == null:
		mgr = get_node_or_null("/root/BuildingManager") as building_manager
	if mgr == null:
		for child in get_tree().root.get_children():
			if child is building_manager:
				mgr = child as building_manager
				break
	if mgr == null:
		push_error("DeleteButton: Autoload 'building_manager' not found. Name it 'building_manager' (recommended) or 'BuildingManager'.")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_select_under_mouse()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_clear_selection()

func _on_pressed() -> void:
	if _selected == null or mgr == null:
		if debug_logs: print("[DeleteButton] Nothing selected or manager missing.")
		return
	if debug_logs:
		print("[DeleteButton] Deleting: ", _selected.name, " kind=", mgr.get_kind_for(_selected))
	_clear_selection(true)
	mgr.unregister_building(_selected)
	_selected.queue_free()
	_selected = null

func _select_under_mouse() -> void:
	if camera == null:
		return
	if mgr == null:
		_resolve_manager()
		if mgr == null:
			return

	var vp: Viewport = camera.get_viewport()
	var mouse: Vector2 = vp.get_mouse_position()
	var from: Vector3 = camera.project_ray_origin(mouse)
	var dir: Vector3 = camera.project_ray_normal(mouse)
	var to: Vector3 = from + dir * raycast_length

	var space: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_bodies = collide_with_bodies
	q.collide_with_areas = collide_with_areas
	q.collision_mask = ray_collision_mask
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		if debug_logs: print("[DeleteButton] No hit.")
		return

	var col: Object = hit.get("collider")
	if not (col is Node):
		return

	var root: Node3D = mgr.find_building_root(col as Node)
	if root == null:
		if require_registered:
			if debug_logs: print("[DeleteButton] Hit is not a registered building: ", (col as Node).get_path())
			return
		root = _top_node3d(col as Node)
		if root == null:
			return

	_apply_selection(root)

func _apply_selection(node: Node3D) -> void:
	if _selected != null and _selected != node:
		_unhighlight(_selected)
	_selected = node
	_highlight(_selected)
	if debug_logs and mgr != null:
		print("[DeleteButton] Selected: ", _selected.name, " kind=", mgr.get_kind_for(_selected))

func _clear_selection(keep_selected_ref: bool = false) -> void:
	if _selected != null:
		_unhighlight(_selected)
	if not keep_selected_ref:
		_selected = null

func _top_node3d(n: Node) -> Node3D:
	var last_nd3d: Node3D = null
	var p: Node = n
	while p != null:
		if p is Node3D:
			last_nd3d = p as Node3D
		p = p.get_parent()
	return last_nd3d

func _highlight(target: Node) -> void:
	_saved_mats.clear()
	_collect_and_apply_highlight(target)

func _collect_and_apply_highlight(n: Node) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		var surfaces: int = (mi.mesh.get_surface_count() if mi.mesh != null else 0)
		var originals: Array = []
		originals.resize(surfaces)
		for i in range(surfaces):
			originals[i] = mi.get_surface_override_material(i)
			mi.set_surface_override_material(i, _highlight_mat)
		_saved_mats[mi] = originals
	elif n is GeometryInstance3D:
		var gi: GeometryInstance3D = n
		var prev: Material = gi.material_override
		gi.material_override = _highlight_mat
		_saved_mats[gi] = prev
	for child in n.get_children():
		if child is Node:
			_collect_and_apply_highlight(child)

func _unhighlight(_target: Node) -> void:
	for k in _saved_mats.keys():
		if not is_instance_valid(k):
			continue
		if k is MeshInstance3D:
			var mi: MeshInstance3D = k
			var originals: Array = _saved_mats[k]
			var count: int = originals.size()
			for i in range(count):
				var mat: Material = originals[i] as Material
				mi.set_surface_override_material(i, mat)
		elif k is GeometryInstance3D:
			var gi: GeometryInstance3D = k
			var prev: Material = _saved_mats[k] as Material
			gi.material_override = prev
	_saved_mats.clear()
