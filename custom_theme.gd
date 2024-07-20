[gd_resource type="Theme" load_steps=6 format=3 uid="uid://b6x8ckwq7rjy8"]

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_1"]
bg_color = Color(0.1, 0.1, 0.1, 1)
corner_radius_top_left = 5
corner_radius_top_right = 5
corner_radius_bottom_right = 5
corner_radius_bottom_left = 5

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_2"]
bg_color = Color(0.2, 0.2, 0.2, 1)
corner_radius_top_left = 5
corner_radius_top_right = 5
corner_radius_bottom_right = 5
corner_radius_bottom_left = 5

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_3"]
bg_color = Color(0.3, 0.3, 0.3, 1)
corner_radius_top_left = 5
corner_radius_top_right = 5
corner_radius_bottom_right = 5
corner_radius_bottom_left = 5

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_4"]
bg_color = Color(0.15, 0.15, 0.15, 1)
corner_radius_top_left = 5
corner_radius_top_right = 5
corner_radius_bottom_right = 5
corner_radius_bottom_left = 5

[sub_resource type="FontFile" id="FontFile_1"]
font_path = "res://assets/fonts/Roboto-Regular.ttf"

[resource]
default_font = SubResource("FontFile_1")
default_font_size = 16
Button/styles/hover = SubResource("StyleBoxFlat_1")
Button/styles/normal = SubResource("StyleBoxFlat_2")
Button/styles/pressed = SubResource("StyleBoxFlat_3")
Panel/styles/panel = SubResource("StyleBoxFlat_4")
Label/colors/font_color = Color(0.9, 0.9, 0.9, 1)
LineEdit/colors/font_color = Color(0.9, 0.9, 0.9, 1)
LineEdit/styles/normal = SubResource("StyleBoxFlat_2")
ItemList/colors/font_color = Color(0.9, 0.9, 0.9, 1)
ItemList/styles/panel = SubResource("StyleBoxFlat_4")
