extends Control

var players = {}
var avatars = []

func _ready():
	_load_avatars()
	_create_background()
	_create_podium()
	_create_leaderboard()
	_create_return_button()
	_animate_results()

func initialize(p_players, game_stats):
	players = p_players

func _load_avatars():
	for i in range(1, 21):  # Assuming 20 avatar images
		avatars.append(load("res://assets/avatars/avatar_%02d.png" % i))

func _create_background():
	var background = TextureRect.new()
	background.texture = load("res://assets/backgrounds/results_background.png")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

func _create_podium():
	var podium = HBoxContainer.new()
	podium.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 20)
	add_child(podium)

	var positions = [2, 1, 3]  # 2nd, 1st, 3rd
	var sorted_players = players.values().sort_custom(func(a, b): return a.score > b.score)
	
	for i in range(3):
		var place = positions[i]
		var pedestal = TextureRect.new()
		pedestal.texture = load("res://assets/ui/podium_%d.png" % place)
		
		if i < sorted_players.size():
			var player = sorted_players[i]
			var avatar = TextureRect.new()
			avatar.texture = avatars[randi() % avatars.size()]
			avatar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 10)
			pedestal.add_child(avatar)
			
			var name_label = Label.new()
			name_label.text = player.name
			name_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 10)
			pedestal.add_child(name_label)
		
		podium.add_child(pedestal)

func _create_leaderboard():
	var leaderboard = Panel.new()
	leaderboard.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 20)
	add_child(leaderboard)
	
	var title = Label.new()
	title.text = "Leaderboard"
	title.add_theme_font_size_override("font_size", 24)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 10)
	leaderboard.add_child(title)
	
	var list = VBoxContainer.new()
	list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	leaderboard.add_child(list)
	
	var sorted_players = players.values().sort_custom(func(a, b): return a.score > b.score)
	
	for player in sorted_players:
		var item = HBoxContainer.new()
		
		var avatar = TextureRect.new()
		avatar.texture = avatars[randi() % avatars.size()]
		item.add_child(avatar)
		
		var name_label = Label.new()
		name_label.text = player.name
		item.add_child(name_label)
		
		var score_label = Label.new()
		score_label.text = "Score: %d" % player.score
		item.add_child(score_label)
		
		list.add_child(item)

func _create_return_button():
	var return_button = Button.new()
	return_button.text = "Return to Main Menu"
	return_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 20)
	return_button.connect("pressed", Callable(self, "_on_return_pressed"))
	add_child(return_button)

func _on_return_pressed():
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _animate_results():
	var tween = create_tween()
	
	# Animate podium
	var podium = get_node("Podium")
	for child in podium.get_children():
		child.modulate.a = 0
		tween.tween_property(child, "modulate:a", 1.0, 0.5)
		tween.tween_interval(0.2)
	
	# Animate leaderboard
	var leaderboard = get_node("Leaderboard")
	leaderboard.modulate.a = 0
	tween.tween_property(leaderboard, "modulate:a", 1.0, 1.0)
	
	# Animate return button
	var return_button = get_node("ReturnButton")
	return_button.modulate.a = 0
	tween.tween_property(return_button, "modulate:a", 1.0, 0.5)
