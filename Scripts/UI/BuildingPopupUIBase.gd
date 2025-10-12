class_name BuildingPopupUI extends CanvasLayer


### Sets the stat values for building popup ui
func set_popup_ui_stats(stats: Dictionary):
	# This should be overrided in inherited scripts
	push_error("set_popup_ui_stats() not implemented in child class!")


### Hides popup ui when close button is clicked
func on_popup_close_button_down() -> void:
	self.visible = false
