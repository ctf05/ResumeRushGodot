extends Theme

func _init():
	# Define colors
	var bg_color = Color(0.1, 0.1, 0.1, 1)
	var fg_color = Color(0.9, 0.9, 0.9, 1)
	var accent_color = Color(0.3, 0.7, 0.9, 1)

	# Button styles
	var button_normal = StyleBoxFlat.new()
	button_normal.bg_color = bg_color
	button_normal.border_width_bottom = 4
	button_normal.border_color = accent_color
	button_normal.corner_radius_top_left = 5
	button_normal.corner_radius_top_right = 5
	button_normal.corner_radius_bottom_right = 5
	button_normal.corner_radius_bottom_left = 5

	var button_hover = button_normal.duplicate()
	button_hover.bg_color = bg_color.lightened(0.1)

	var button_pressed = button_normal.duplicate()
	button_pressed.bg_color = accent_color
	button_pressed.border_color = bg_color

	set_stylebox("normal", "Button", button_normal)
	set_stylebox("hover", "Button", button_hover)
	set_stylebox("pressed", "Button", button_pressed)
	set_color("font_color", "Button", fg_color)
	set_color("font_focus_color", "Button", fg_color)

	# Panel style
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = bg_color.lightened(0.05)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.corner_radius_bottom_left = 10

	set_stylebox("panel", "Panel", panel_style)

	# LineEdit style
	var line_edit_style = StyleBoxFlat.new()
	line_edit_style.bg_color = bg_color.lightened(0.1)
	line_edit_style.border_width_bottom = 2
	line_edit_style.border_color = accent_color
	set_stylebox("normal", "LineEdit", line_edit_style)
	set_color("font_color", "LineEdit", fg_color)

	# ItemList style
	set_stylebox("panel", "ItemList", panel_style.duplicate())
	set_color("font_color", "ItemList", fg_color)

	# Label colors
	set_color("font_color", "Label", fg_color)

	# Set default font
	var default_font = load("res://assets/fonts/Roboto-Regular.ttf")
	if default_font:
		set_default_font(default_font)
		set_default_font_size(16)
