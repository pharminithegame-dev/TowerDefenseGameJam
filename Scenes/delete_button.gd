extends TextureButton

@export_node_path("Camera3D") var camera_path: NodePath
@export var raycast_length: float = 10000.0
@export var collide_with_bodies: bool = false
@export var collide_with_areas: bool = true
@export_flags_3d_physics var ray_collision_mask: int = 0x4  # Layer 3 (SelectArea3D)
@export var require_registered: bool = true
@export var debug_logs: bool = false

@export var highlight_tint: Color = Color(1.0, 0.7, 0.2, 0.25)
@export var flash_speed: float = 2.0

var camera: Camera3D = null
var mgr: building_manager = null
var _selected: Node3D = null
var _delete_mode_active: bool = false

# Highlight materials
var _highlight_shader: Shader = null
var _highlight_mat: ShaderMaterial = null
var _saved_mesh_mats: Dictionary = {}
var _saved_geom_override: Dictionary = {}

func _ready() -> void:
	toggle_mode = true  # Button can be toggled on/off
	button_pressed = false  # Start in OFF state
	
	# Connect signals
	toggled.connect(_on_delete_mode_toggled)
	
	# Find camera
	if camera_path != NodePath():
		camera = get_node_or_null(camera_path) as Camera3D
	if camera == null:
		camera = get_viewport().get_camera_3d()
	
	# Find building manager
	_find_manager()
	
	# Create highlight shader
	_create_highlight_shader()

func _find_manager() -> void:
	# Try common autoload paths
	mgr = get_node_or_null("/root/BuildingManager") as building_manager
	if mgr == null:
		mgr = get_node_or_null("/root/building_manager") as building_manager
	
	# Fallback: search root children
	if mgr == null:
		for child in get_tree().root.get_children():
			if child is building_manager:
				mgr = child as building_manager
				break
	
	if mgr == null:
		push_error("[DeleteButton] building_manager autoload not found!")

func _create_highlight_shader() -> void:
	_highlight_shader = Shader.new()
	_highlight_shader.code = """
		shader_type spatial;
		render_mode unshaded, cull_disabled, depth_draw_opaque, blend_mix;

		uniform vec4 tint : source_color;
		uniform float speed = 2.0;

		void fragment() {
			float pulse = sin(TIME * 6.2831853 * speed) * 0.5 + 0.5;
			ALBEDO = tint.rgb;
			EMISSION = tint.rgb * (1.0 + pulse * 2.0);
			ALPHA = tint.a * (0.55 + 0.45 * pulse);
		}
	"""
	
	_highlight_mat = ShaderMaterial.new()
	_highlight_mat.shader = _highlight_shader
	_highlight_mat.set_shader_parameter("tint", highlight_tint)
	_highlight_mat.set_shader_parameter("speed", flash_speed)

# Handle deletion modes

func _on_delete_mode_toggled(is_on: bool) -> void:
	_delete_mode_active = is_on
	
	if _delete_mode_active:
		# Entering delete mode
		if debug_logs:
			print("[DeleteButton] Delete mode ENABLED")
		modulate = Color(1.0, 0.7, 0.7)  # Slight red tint
	else:
		# Exiting delete mode
		if debug_logs:
			print("[DeleteButton] Delete mode DISABLED")
		modulate = Color(1.0, 1.0, 1.0)
		_clear_selection()

# Handle clicking on buildings

func _input(event: InputEvent) -> void:
	# Only process input when delete mode is active
	if not _delete_mode_active:
		return
	
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			# Try to select building under mouse
			_handle_left_click()
			
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			# Clear selection
			_clear_selection()
			get_viewport().set_input_as_handled()

func _handle_left_click() -> void:
	# Don't process if clicking on UI
	var mouse_pos := get_viewport().get_mouse_position()
	if _is_clicking_ui(mouse_pos):
		return
	
	# Raycast to find building
	var hit_building := _raycast_for_building(mouse_pos)
	
	if hit_building != null:
		_toggle_selection(hit_building)
		get_viewport().set_input_as_handled()

func _is_clicking_ui(mouse_pos: Vector2) -> bool:
	# Check if clicking on any Control node
	# You can expand this to check other UI elements if needed
	return false

func _raycast_for_building(screen_pos: Vector2) -> Node3D:
	if camera == null:
		camera = get_viewport().get_camera_3d()
		if camera == null:
			return null
	
	# Setup ray
	var from := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	var to := from + direction * raycast_length
	
	# Perform raycast
	var space := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = collide_with_bodies
	query.collide_with_areas = collide_with_areas
	query.collision_mask = ray_collision_mask
	
	var result := space.intersect_ray(query)
	
	if result.is_empty():
		if debug_logs:
			print("[DeleteButton] Raycast hit nothing")
		return null
	
	# Get the collider
	var collider: Object = result.get("collider")
	if not (collider is Node):
		return null
	
	if debug_logs:
		print("[DeleteButton] Hit: ", collider.name)
	
	# Find the building root
	return _find_building_from_collider(collider as Node)

func _find_building_from_collider(collider: Node) -> Node3D:
	# First try: use manager's registry
	if mgr != null:
		var root := mgr.find_building_root(collider)
		if root != null:
			if debug_logs:
				print("[DeleteButton] Found registered building: ", root.name)
			return root
	
	# If require_registered is true, don't allow non-registered buildings
	if require_registered:
		if debug_logs:
			print("[DeleteButton] Not a registered building")
		return null
	
	# Second try: find any ancestor with sell_building method
	var current := collider
	while current != null:
		if current is Node3D and current.has_method("sell_building"):
			if debug_logs:
				print("[DeleteButton] Found building via sell_building: ", current.name)
			return current as Node3D
		current = current.get_parent()
	
	return null

# Handle the selection in deletion moon

func _toggle_selection(building: Node3D) -> void:
	if _selected == building:
		# Clicking same building - execute deletion immediately
		if debug_logs:
			print("[DeleteButton] Re-clicked selected building - deleting")
		_execute_deletion()
	else:
		# Select new building
		_select_building(building)

func _select_building(building: Node3D) -> void:
	# Clear previous selection
	if _selected != null:
		_remove_highlight(_selected)
	
	# Set new selection
	_selected = building
	_apply_highlight(_selected)
	
	if debug_logs:
		var kind := ""
		if mgr != null:
			kind = String(mgr.get_kind_for(_selected))
		print("[DeleteButton] Selected: ", _selected.name, " (", kind, ")")

func _clear_selection() -> void:
	if _selected != null:
		if debug_logs:
			print("[DeleteButton] Clearing selection")
		_remove_highlight(_selected)
		_selected = null

# Handle Deletion of buildings

func _execute_deletion() -> void:
	if _selected == null:
		if debug_logs:
			print("[DeleteButton] Cannot delete - nothing selected")
		return
	
	var building := _selected
	if debug_logs:
		print("[DeleteButton] Deleting: ", building.name)
	
	# Clear selection first
	_clear_selection()
	
	# Unregister from manager
	if mgr != null and mgr.is_registered(building):
		mgr.unregister_building(building)
	
	# Call sell_building if it exists
	if building.has_method("sell_building"):
		var refund: Variant = building.call("sell_building")
		
		# Handle refund
		if refund is int or refund is float:
			var money_mgr: Node = get_node_or_null("/root/MoneyManager")
			if money_mgr != null and money_mgr.has_method("add_money"):
				money_mgr.add_money(refund)
				if debug_logs:
					print("[DeleteButton] Refunded: $", refund)
	else:
		# Fallback: just queue_free
		push_warning("[DeleteButton] Building has no sell_building() - using queue_free")
		building.queue_free()

# Apply building highlight

func _apply_highlight(node: Node) -> void:
	_saved_mesh_mats.clear()
	_saved_geom_override.clear()
	_recursive_highlight(node)

func _recursive_highlight(node: Node) -> void:
	# Handle MeshInstance3D
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		if mesh_inst.mesh != null:
			var surface_count := mesh_inst.mesh.get_surface_count()
			var saved_materials: Array[Material] = []
			saved_materials.resize(surface_count)
			
			for i in range(surface_count):
				saved_materials[i] = mesh_inst.get_surface_override_material(i)
				mesh_inst.set_surface_override_material(i, _highlight_mat)
			
			_saved_mesh_mats[mesh_inst] = saved_materials
	
	# Handle other GeometryInstance3D (but not MeshInstance3D again)
	elif node is GeometryInstance3D:
		var geom_inst := node as GeometryInstance3D
		_saved_geom_override[geom_inst] = geom_inst.material_override
		geom_inst.material_override = _highlight_mat
	
	# Recurse to children
	for child in node.get_children():
		_recursive_highlight(child)

func _remove_highlight(node: Node) -> void:
	# Restore MeshInstance3D materials
	for mesh_inst in _saved_mesh_mats:
		if not is_instance_valid(mesh_inst):
			continue
		
		var saved_mats: Array = _saved_mesh_mats[mesh_inst]
		for i in range(saved_mats.size()):
			mesh_inst.set_surface_override_material(i, saved_mats[i])
	
	# Restore GeometryInstance3D materials
	for geom_inst in _saved_geom_override:
		if not is_instance_valid(geom_inst):
			continue
		
		geom_inst.material_override = _saved_geom_override[geom_inst]
	
	_saved_mesh_mats.clear()
	_saved_geom_override.clear()
