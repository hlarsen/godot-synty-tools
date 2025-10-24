@tool

# Base class for UI menus
class_name BaseMenu
extends RefCounted

var plugin: EditorPlugin
var container: Control
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
	
	# Bottom spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(spacer2)
	
	# Back button at bottom
	var back_row = HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	back_row.add_theme_constant_override("separation", 10)
	
	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(150, 60)
	back_btn.pressed.connect(plugin.go_back)
	back_row.add_child(back_btn)
	
	container.add_child(back_row)
