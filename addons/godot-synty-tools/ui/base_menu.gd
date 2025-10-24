@tool

# Base class for UI menus
class_name BaseMenu
extends RefCounted

var container: Control
var plugin: EditorPlugin
var window: Window

# Override this to add your custom content
func build_content() -> void:
#	push_warning("build_content() has not been overriden in the child class")
	pass

# Override this for cleanup
# TODO: fold into base? might have to adjust vars, not sure we need it
func cleanup() -> void:
#	push_warning("cleanup() has not been overriden in the child class")
	pass

# Override this for runtime checks before allowing processing
func validate_and_enable_run_button() -> void:
	pass

func show_menu(button_grid: Control, popup_window: Window) -> void:
	container = button_grid
	window = popup_window
	
	for child in container.get_children():
		child.queue_free()
	
	# let the subclass build its content
	build_content()
