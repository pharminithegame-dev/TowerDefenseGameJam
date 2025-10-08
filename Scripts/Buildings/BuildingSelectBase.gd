extends Area3D

### Export Variables
@export var popup_ui: PackedScene

### Private Variables
var is_selected := false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
 


### Displays building popup UI
func select_building() -> void:
	print("Selecting building")
	if is_selected: return
	is_selected = true
	
	# TODO


### Hides building popup UI
func deselect_building() -> void:
	print("Deselecting building")
	if !is_selected: return
	is_selected = false
	
	# TODO
