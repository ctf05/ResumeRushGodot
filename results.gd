extends Control

var players = {}
var game_stats = {}
var avatars = []

func _ready():
	_load_avatars()
	_create_background()
	_create_header()
	_create_podium()
	_create_leaderboard()
	_create_statistics_panel()
	_create_return_button()
	_create_confetti()
	await get_tree().process_frame
	_animate_results()
	

func initialize(p_players, p_game_stats):
	players = p_players
	game_stats = p_game_stats

func _load_avatars():
	for i in range(1, 9):
		avatars.append(load("res://assets/avatars/avatar_0%d.png" % i))

func _create_background():
	var background = TextureRect.new()
	background.texture = load("res://assets/backgrounds/results_background.png")
	background.expand = true
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

func _create_header():
	var header = Control.new()
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 560
	header.offset_top = 20
	header.offset_right = 1360
	header.offset_bottom = 170
	add_child(header)

	var logo_left = TextureRect.new()
	logo_left.texture = load("res://assets/ui/resume_rush_logo.png")
	logo_left.expand = true
	logo_left.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	logo_left.offset_right = 120
	logo_left.offset_bottom = 120
	header.add_child(logo_left)

	var title = Label.new()
	title.text = "Game Results"
	title.add_theme_font_size_override("font_size", 64)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 140
	title.offset_right = -140
	title.offset_bottom = 120
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	var logo_right = TextureRect.new()
	logo_right.texture = load("res://assets/ui/resume_rush_logo.png")
	logo_right.expand = true
	logo_right.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	logo_right.offset_left = -120
	logo_right.offset_bottom = 120
	header.add_child(logo_right)

func _create_podium():
	var podium = Control.new()
	podium.name = "Podium"
	podium.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	podium.offset_left = 560
	podium.offset_top = -400
	podium.offset_right = 1360
	add_child(podium)

	var positions = [
		{"place": 2, "x": 60, "y": 100, "width": 200, "height": 300},
		{"place": 1, "x": 300, "y": 50, "width": 200, "height": 350},
		{"place": 3, "x": 540, "y": 150, "width": 200, "height": 250}
	]

	var sorted_players = players.values().sort_custom(func(a, b): return a["score"] > b["score"])

	for i in range(3):
		if i >= sorted_players.size():
			break

		var pos = positions[i]
		var player = sorted_players[i]

		var pedestal = TextureRect.new()
		pedestal.texture = load("res://assets/ui/podium_%d.png" % pos["place"])
		pedestal.expand = true
		pedestal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pedestal.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		pedestal.offset_left = pos["x"]
		pedestal.offset_top = pos["y"]
		pedestal.offset_right = pos["x"] + pos["width"]
		pedestal.offset_bottom = pos["y"] + pos["height"]
		podium.add_child(pedestal)

		var avatar = TextureRect.new()
		avatar.texture = avatars[player["avatar"] - 1]
		avatar.expand = true
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		avatar.offset_left = -75
		avatar.offset_top = -180
		avatar.offset_right = 75
		avatar.offset_bottom = -30
		pedestal.add_child(avatar)

		var nameplate = TextureRect.new()
		nameplate.texture = load("res://assets/ui/nameplate.png")
		nameplate.expand = true
		nameplate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		nameplate.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		nameplate.offset_left = -90
		nameplate.offset_top = -40
		nameplate.offset_right = 90
		nameplate.offset_bottom = 0
		pedestal.add_child(nameplate)

		var name_label = Label.new()
		name_label.text = player["name"]
		name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nameplate.add_child(name_label)

		var score_label = Label.new()
		score_label.text = "Score: %d" % player["score"]
		score_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		score_label.offset_left = -90
		score_label.offset_top = 10
		score_label.offset_right = 90
		score_label.offset_bottom = 40
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pedestal.add_child(score_label)

func _create_leaderboard():
	var leaderboard = Panel.new()
	leaderboard.name = "Leaderboard"
	leaderboard.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	leaderboard.offset_left = 50
	leaderboard.offset_top = 190
	leaderboard.offset_right = 500
	leaderboard.offset_bottom = 890
	add_child(leaderboard)

	var title = Label.new()
	title.text = "Leaderboard"
	title.add_theme_font_size_override("font_size", 32)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_bottom = 50
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leaderboard.add_child(title)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 60
	scroll.offset_left = 10
	scroll.offset_right = -10
	scroll.offset_bottom = -10
	leaderboard.add_child(scroll)

	var list = VBoxContainer.new()
	list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.add_child(list)

	var sorted_players = players.values().sort_custom(func(a, b): return a["score"] > b["score"])

	for player in sorted_players:
		var item = HBoxContainer.new()
		item.custom_minimum_size.y = 60

		var avatar = TextureRect.new()
		avatar.texture = avatars[player["avatar"] - 1]
		avatar.expand = true
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar.custom_minimum_size = Vector2(50, 50)
		item.add_child(avatar)

		var name_label = Label.new()
		name_label.text = player["name"]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_child(name_label)

		var score_label = Label.new()
		score_label.text = _format_number(player["score"])
		item.add_child(score_label)

		var role_icon = TextureRect.new()
		role_icon.texture = load("res://assets/icons/ceo.png" if player["role"] == 0 else "res://assets/icons/candidate.png")
		role_icon.expand = true
		role_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		role_icon.custom_minimum_size = Vector2(30, 30)
		item.add_child(role_icon)

		list.add_child(item)

func _create_statistics_panel():
	var stats_panel = Panel.new()
	stats_panel.name = "StatsPanel"
	stats_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	stats_panel.offset_left = 1420
	stats_panel.offset_top = 190
	stats_panel.offset_right = -50
	stats_panel.offset_bottom = 890
	add_child(stats_panel)

	var title = Label.new()
	title.text = "Game Statistics"
	title.add_theme_font_size_override("font_size", 32)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_bottom = 50
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_panel.add_child(title)

	var list = VBoxContainer.new()
	list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	list.offset_top = 60
	list.offset_left = 10
	list.offset_right = -10
	list.offset_bottom = -10
	stats_panel.add_child(list)

	var stat_data = [
		{"key": "total_rounds", "icon": "res://assets/ui/clock.png"},
		{"key": "total_players", "icon": "res://assets/icons/candidate.png"},
		{"key": "highest_score", "icon": "res://assets/ui/emoji/emoji_thumbs_up.png"},
		{"key": "average_score", "icon": "res://assets/ui/clipboard.png"},
		{"key": "total_hires", "icon": "res://assets/icons/resume.png"},
		{"key": "average_salary", "icon": "res://assets/ui/money_stack.png"}
	]

	for stat in stat_data:
		var item = HBoxContainer.new()
		item.custom_minimum_size.y = 50

		var icon = TextureRect.new()
		icon.texture = load(stat["icon"])
		icon.expand = true
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(30, 30)
		item.add_child(icon)

		var label = Label.new()
		label.text = stat["key"].capitalize().replace("_", " ") + ":"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_child(label)

		var value = Label.new()
		value.text = str(game_stats[stat["key"]])
		item.add_child(value)

		list.add_child(item)

func _create_return_button():
	var return_button = Button.new()
	return_button.name = "ReturnButton"
	return_button.text = "Return to Main Menu"
	return_button.icon = load("res://assets/ui/close.png")
	return_button.expand_icon = true
	return_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	return_button.offset_left = 810
	return_button.offset_top = -110
	return_button.offset_right = 1110
	return_button.offset_bottom = -30
	return_button.connect("pressed", Callable(self, "_on_return_pressed"))
	add_child(return_button)

func _create_confetti():
	var particles = GPUParticles2D.new()
	particles.amount = 50
	particles.lifetime = 5
	particles.explosiveness = 0.1
	particles.randomness = 1.0
	particles.fixed_fps = 30
	particles.local_coords = false

	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(960, 1, 1)
	material.gravity = Vector3(0, 98, 0)
	material.initial_velocity_min = 100
	material.initial_velocity_max = 200
	material.scale_min = 0.1
	material.scale_max = 0.3
	material.color = Color(1, 1, 1, 1)
	particles.process_material = material

	var texture = load("res://assets/ui/confetti.png")
	particles.texture = texture

	particles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(particles)

func _animate_results():
	var tween = create_tween()
	
	# Animate podium
	var podium = get_node("Podium")
	for child in podium.get_children():
		child.modulate.a = 0
		tween.tween_property(child, "modulate:a", 1.0, 0.5)
		tween.parallel().tween_property(child, "scale", Vector2(1.1, 1.1), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(child, "scale", Vector2(1, 1), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_interval(0.2)
	
	# Animate leaderboard
	var leaderboard = get_node("Leaderboard")
	leaderboard.modulate.a = 0
	tween.tween_property(leaderboard, "modulate:a", 1.0, 1.0)
	
	# Animate statistics panel
	var stats_panel = get_node("StatsPanel")
	stats_panel.modulate.a = 0
	tween.tween_property(stats_panel, "modulate:a", 1.0, 1.0)
	
	# Animate return button
	var return_button = get_node("ReturnButton")
	return_button.modulate.a = 0
	tween.tween_property(return_button, "modulate:a", 1.0, 0.5)
	
	# Start confetti after a short delay
	tween.tween_callback(func(): get_node("Confetti").emitting = true).delay(1.0)

func _on_return_pressed():
	# Transition back to the main menu
	get_tree().change_scene_to_file("res://main_menu.tscn")

# Add a subtle pulsing effect to the podium
func _process(delta):
	var podium = get_node("Podium")
	for child in podium.get_children():
		var pulse = sin(Time.get_ticks_msec() * 0.005 + child.get_index() * PI / 2) * 0.05 + 1.0
		child.scale = Vector2(pulse, pulse)

# Helper function to format numbers with commas for thousands
func _format_number(number):
	var string = str(number)
	var mod = string.length() % 3
	var result = ""

	for i in range(string.length()):
		if i != 0 && i % 3 == mod:
			result += ","
		result += string[i]

	return result

# Add a method to handle window resizing
func _on_window_resized():
	# Adjust the scale of the root control to fit the window
	var window_size = get_viewport().size
	var scale = min(window_size.x / 1920.0, window_size.y / 1080.0)
	self.scale = Vector2(scale, scale)
	
	# Center the root control in the window
	self.position = (window_size - (Vector2(1920, 1080) * scale)) / 2
