@tool
extends RefCounted

var plugin: EditorPlugin

func show_menu(container: Control, window: Window):
	# Clear existing children
	for child in container.get_children():
		child.queue_free()
	
	# Add your menu content here
	var label = Label.new()
	label.text = "Sci-Fi City"
	container.add_child(label)
	
	# Always add a back button
	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.pressed.connect(plugin.go_back)
	container.add_child(back_btn)

func cleanup():
	# Clean up any resources when the plugin exits
	pass
