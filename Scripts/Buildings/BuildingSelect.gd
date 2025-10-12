extends Area3D

### Export Variables
@export var popup_ui: CanvasLayer

### Private Variables
var is_selected := false
 

### Displays building popup UI
func select_building() -> void:
	if is_selected: return
	is_selected = true
	popup_ui.visible = true


### Hides building popup UI
func deselect_building() -> void:
	if !is_selected: return
	is_selected = false
	popup_ui.visible = false
