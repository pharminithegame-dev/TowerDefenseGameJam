extends TextureButton

# --- Picking ---------------------------------------------------------------
@export_node_path("Camera3D") var camera_path: NodePath
@export var raycast_length: float = 10000.0
@export var collide_with_bodies: bool = true
@export var collide_with_areas: bool = false
@export_flags_3d_physics var ray_collision_mask: int = 0xFFFFFFFF
@export var require_registered: bool = true     # true = must be in manager registry
@export var debug_logs: bool = false

# --- Highlight look & feel -------------------------------------------------
@export var highlight_tint: Color = Color(1.0, 0.7, 0.2, 0.25)  # color + alpha
@export var flash_speed: float = 2.0                             # flashes per second

# --------------------------------------------------------------------------
var camera: Camera3D = null
var mgr: building_manager = null

var _selected: Node3D = null

var _highlight_shader: Shader = null
var _highlight_mat: ShaderMaterial = null
var _saved_mesh_mats: Dictionary = {}       # MeshInstance3D -> Array[Material]
var _saved_geom_override: Dictionary = {}   # GeometryInstance3D -> Material

func _ready() -> void:
	toggle_mode = false
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

	# Resolve camera (allow inspector path or fallback to viewport camera)
	if camera_path != NodePath():
		camera = get_node_or_null(camera_path) as Camera3D
	else:
		camera = get_viewport().get_camera_3d()

	_resolve_manager()

	# Build a tiny flashing shader once.
	_highlight_shader = Shader.new()
	_highlight_shader.code = """
		shader_type spatial;
		render_mode unshaded, cull_disabled, depth_draw_opaque, blend_mix;

		uniform vec4 tint : source_color;
		uniform float speed = 2.0;

		void fragment() {
			float s = sin(TIME * 6.2831853 * speed) * 0.5 + 0.5; // [0..1]
			ALBEDO = tint.rgb;
			EMISSION = tint.rgb * (1.0 + s * 2.0);
			ALPHA = tint.a * (0.55 + 0.45 * s);
		}
	""";
	_highlight_mat = ShaderMaterial.new()
	_highlight_mat.shader = _highlight_shader
	_highlight_mat.set_shader_parameter("tint", highlight_tint)
	_highlight_mat.set_shader_parameter("speed", flash_speed)

	set_process_unhandled_input(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _resolve_manager() -> void:
	# Support either autoload name
	var m1: Node = get_node_or_null("/root/building_manager")
	var m2: Node = get_node_or_null("/root/BuildingManager")
	if m1 is building_manager:
		mgr = m1 as building_manager
	elif m2 is building_manager:
		mgr = m2 as building_manager
	else:
		# Fallback: scan root children
		var kids: Array = get_tree().root.get_children()
		for i in range(kids.size()):
			var k: Node = kids[i] as Node
			if k is building_manager:
				mgr = k as building_manager
				break
	if mgr == null:
		push_error("DeleteButton: Autoload instance of `building_manager` not found (expected /root/building_manager or /root/BuildingManager).")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_select_under_mouse()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_clear_selection()

func _on_pressed() -> void:
	# Delete button clicked
	if _selected == null:
		if debug_logs: print("[DeleteButton] Nothing selected.")
		return

	# Best-effort unregister first (keeps manager tidy even if queue_free is deferred)
	if mgr != null and mgr.is_registered(_selected):
		mgr.unregister_building(_selected)

	# Call the building’s own sell function (per your requirement) safely
	if _selected.has_method("sell_building"):
		if debug_logs: print("[DeleteButton] Calling sell_building() on: ", _selected.name)
		_selected.call_deferred("sell_building")
	else:
		push_warning("[DeleteButton] Selected node has no sell_building(); ignoring.")

	# Clear selection & highlight immediately
	_clear_selection()

# --- Selection -------------------------------------------------------------

func _select_under_mouse() -> void:
	if camera == null:
		# Try to recover a camera once if none set
		camera = get_viewport().get_camera_3d()
		if camera == null:
			return
	if mgr == null:
		_resolve_manager()

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

	var col_obj: Object = hit.get("collider")
	if not (col_obj is Node):
		return
	var col: Node = col_obj as Node

	var root: Node3D = null
	# Prefer the nearest ancestor that is actually registered as a building
	if mgr != null:
		root = mgr.find_building_root(col)

	# If we require registry and none were found, bail.
	if root == null and require_registered:
		if debug_logs:
			print("[DeleteButton] Hit is not a registered building: ", col.get_path())
		return

	# If registry is optional, allow the nearest ancestor that implements sell_building()
	if root == null:
		root = _nearest_with_sell_building(col)
		if root == null:
			return

	_apply_selection(root)

func _nearest_with_sell_building(n: Node) -> Node3D:
	var cur: Node = n
	while cur != null:
		if cur is Node3D and cur.has_method("sell_building"):
			return cur as Node3D
		cur = cur.get_parent()
	return null

func _apply_selection(node: Node3D) -> void:
	# Toggle OFF if clicking the same building again.
	if _selected == node:
		_clear_selection()
		return

	# Switching selection: unhighlight old, highlight new.
	if _selected != null:
		_unhighlight(_selected)

	_selected = node
	_highlight(_selected)

	if debug_logs and mgr != null:
		var kind: StringName = mgr.get_kind_for(_selected)
		print("[DeleteButton] Selected: ", _selected.name, " kind=", String(kind))

func _clear_selection() -> void:
	if _selected != null:
		_unhighlight(_selected)
	_selected = null

# --- Highlight (shader override) ------------------------------------------

func _highlight(target: Node) -> void:
	_saved_mesh_mats.clear()
	_saved_geom_override.clear()
	_collect_and_apply_highlight(target)

func _collect_and_apply_highlight(n: Node) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n as MeshInstance3D
		var surfaces: int = 0
		if mi.mesh != null:
			surfaces = mi.mesh.get_surface_count()
		var originals: Array[Material] = []
		originals.resize(surfaces)
		for i in range(surfaces):
			var prev_mat: Material = mi.get_surface_override_material(i)
			originals[i] = prev_mat
			mi.set_surface_override_material(i, _highlight_mat)
		_saved_mesh_mats[mi] = originals
	elif n is GeometryInstance3D:
		# MeshInstance3D is also GeometryInstance3D, but we already handled meshes above.
		var gi: GeometryInstance3D = n as GeometryInstance3D
		var prev: Material = gi.material_override
		gi.material_override = _highlight_mat
		_saved_geom_override[gi] = prev

	var kids: Array = n.get_children()
	for idx in range(kids.size()):
		var child: Node = kids[idx] as Node
		_collect_and_apply_highlight(child)

func _unhighlight(_target: Node) -> void:
	# Restore per-surface overrides for meshes
	var mesh_keys: Array = _saved_mesh_mats.keys()
	for k_idx in range(mesh_keys.size()):
		var k_obj: Object = mesh_keys[k_idx]
		if not is_instance_valid(k_obj):
			continue
		var mi: MeshInstance3D = k_obj as MeshInstance3D
		var originals_any: Array = _saved_mesh_mats[k_obj]
		for i in range(originals_any.size()):
			var mat: Material = originals_any[i] as Material
			mi.set_surface_override_material(i, mat)

	# Restore material_override for non-mesh GeometryInstance3D
	var gi_keys: Array = _saved_geom_override.keys()
	for g_idx in range(gi_keys.size()):
		var g_obj: Object = gi_keys[g_idx]
		if not is_instance_valid(g_obj):
			continue
		var gi: GeometryInstance3D = g_obj as GeometryInstance3D
		var prev: Material = _saved_geom_override[g_obj] as Material
		gi.material_override = prev

	_saved_mesh_mats.clear()
	_saved_geom_override.clear()
