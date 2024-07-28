extends Node2D

signal start_game
signal add_ai_player
signal remove_ai_player

var player_cards = []
var avatars = []
var chat_container: Control
var whiteboard: TextureRect
var code_label: Label

func _ready():
	_load_avatars()
	_create_background()
	_create_central_whiteboard()
	_create_player_cards()
	_create_room_code_display()
	_create_chat_system()
	_create_game_settings_display()
	_create_button_container()
	_create_particle_effects()

func _create_background():
	var background = TextureRect.new()
	background.texture = load("res://assets/backgrounds/lobby_background.png")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.set_offset(SIDE_LEFT, 0)
	background.set_offset(SIDE_TOP, 0)
	background.set_offset(SIDE_RIGHT, 1920)
	background.set_offset(SIDE_BOTTOM, 1080)
	add_child(background)

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.3)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.set_offset(SIDE_LEFT, 0)
	overlay.set_offset(SIDE_TOP, 0)
	overlay.set_offset(SIDE_RIGHT, 1920)
	overlay.set_offset(SIDE_BOTTOM, 1080)
	add_child(overlay)

func _create_central_whiteboard():
	whiteboard = TextureRect.new()
	whiteboard.texture = load("res://assets/furniture/whiteboard.png")
	whiteboard.expand = true
	whiteboard.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	whiteboard.set_anchors_preset(Control.PRESET_TOP_LEFT)
	whiteboard.set_offset(SIDE_LEFT, 260)
	whiteboard.set_offset(SIDE_TOP, 140)
	whiteboard.set_offset(SIDE_RIGHT, 1660)
	whiteboard.set_offset(SIDE_BOTTOM, 940)
	add_child(whiteboard)

	var tween = create_tween().set_loops()
	tween.tween_property(whiteboard, "position:y", whiteboard.position.y - 5, 2)
	tween.tween_property(whiteboard, "position:y", whiteboard.position.y + 5, 2)

func _create_player_cards():
	var card_container = GridContainer.new()
	card_container.columns = 4
	card_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card_container.set_offset(SIDE_LEFT, 95)
	card_container.set_offset(SIDE_TOP, 50)
	card_container.set_offset(SIDE_RIGHT, 1350)
	card_container.set_offset(SIDE_BOTTOM, 450)
	whiteboard.add_child(card_container)

	for i in range(8):  # 8 player cards
		var card = _create_player_card()
		card_container.add_child(card)
		player_cards.append(card)

func _create_button_container():
	var button_container = Panel.new()
	button_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button_container.set_offset(SIDE_LEFT, 1560)
	button_container.set_offset(SIDE_TOP, 740)
	button_container.set_offset(SIDE_RIGHT, 1910)
	button_container.set_offset(SIDE_BOTTOM, 1070)
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(1, 1, 1, 0.2)
	style_box.corner_radius_top_left = 20
	style_box.corner_radius_top_right = 20
	style_box.corner_radius_bottom_left = 20
	style_box.corner_radius_bottom_right = 20
	button_container.add_theme_stylebox_override("panel", style_box)
	add_child(button_container)

	_create_ai_controls(button_container)
	_create_start_button(button_container)

func _create_ai_controls(container):
	var add_ai_button = HitboxGenerator.create_texture_button_with_hitbox("res://assets/buttons/add_ai.png")
	add_ai_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_ai_button.set_offset(SIDE_LEFT, 20)
	add_ai_button.set_offset(SIDE_TOP, 20)
	add_ai_button.set_offset(SIDE_RIGHT, 110)
	add_ai_button.set_offset(SIDE_BOTTOM, 110)
	add_ai_button.connect("pressed", Callable(self, "_on_add_ai_pressed"))
	container.add_child(add_ai_button)

	var remove_ai_button = HitboxGenerator.create_texture_button_with_hitbox("res://assets/buttons/remove_ai.png")
	remove_ai_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	remove_ai_button.set_offset(SIDE_LEFT, 230)
	remove_ai_button.set_offset(SIDE_TOP, 20)
	remove_ai_button.set_offset(SIDE_RIGHT, 320)
	remove_ai_button.set_offset(SIDE_BOTTOM, 110)
	remove_ai_button.connect("pressed", Callable(self, "_on_remove_ai_pressed"))
	container.add_child(remove_ai_button)

func _create_start_button(container):
	var start_button = HitboxGenerator.create_texture_button_with_hitbox("res://assets/buttons/go_sign.png")
	start_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	start_button.set_offset(SIDE_LEFT, 20)
	start_button.set_offset(SIDE_TOP, 130)
	start_button.set_offset(SIDE_RIGHT, 320)
	start_button.set_offset(SIDE_BOTTOM, 320)
	start_button.connect("pressed", Callable(self, "_on_start_pressed"))
	container.add_child(start_button)

	var tween = create_tween().set_loops()
	tween.tween_property(start_button, "scale", Vector2(1.1, 1.1), 1)
	tween.tween_property(start_button, "scale", Vector2(1, 1), 1)

func _create_player_card():
	var card = Panel.new()
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Dark gray, mostly opaque
	style_box.corner_radius_top_left = 20
	style_box.corner_radius_top_right = 20
	style_box.corner_radius_bottom_left = 20
	style_box.corner_radius_bottom_right = 20
	card.add_theme_stylebox_override("panel", style_box)
	card.custom_minimum_size = Vector2(300, 220)  # Set a minimum size for the card
	
	var avatar = TextureRect.new()
	avatar.name = "AvatarTexture"
	avatar.expand = true
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	avatar.set_offset(SIDE_LEFT, 75)
	avatar.set_offset(SIDE_TOP, 10)
	avatar.set_offset(SIDE_RIGHT, 225)
	avatar.set_offset(SIDE_BOTTOM, 160)
	card.add_child(avatar)
	
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	name_label.set_offset(SIDE_LEFT, 10)
	name_label.set_offset(SIDE_TOP, 180)
	name_label.set_offset(SIDE_RIGHT, 290)
	name_label.set_offset(SIDE_BOTTOM, 220)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)  # Increase font size
	card.add_child(name_label)
	
	return card

func _create_room_code_display():
	var codes_container = VBoxContainer.new()
	codes_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	codes_container.set_offset(SIDE_LEFT, 400)
	codes_container.set_offset(SIDE_TOP, 10)
	codes_container.set_offset(SIDE_RIGHT, 1000)
	codes_container.set_offset(SIDE_BOTTOM, 90)
	whiteboard.add_child(codes_container)

	code_label = Label.new()
	codes_container.add_child(code_label)

func _create_chat_system():
	chat_container = Panel.new()
	chat_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	chat_container.set_offset(SIDE_LEFT, 10)
	chat_container.set_offset(SIDE_TOP, 770)
	chat_container.set_offset(SIDE_RIGHT, 460)
	chat_container.set_offset(SIDE_BOTTOM, 1070)
	add_child(chat_container)
	
	var chat_display = RichTextLabel.new()
	chat_display.set_anchors_preset(Control.PRESET_TOP_LEFT)
	chat_display.set_offset(SIDE_LEFT, 10)
	chat_display.set_offset(SIDE_TOP, 10)
	chat_display.set_offset(SIDE_RIGHT, 440)
	chat_display.set_offset(SIDE_BOTTOM, 260)
	chat_container.add_child(chat_display)
	
	var chat_input = LineEdit.new()
	chat_input.set_anchors_preset(Control.PRESET_TOP_LEFT)
	chat_input.set_offset(SIDE_LEFT, 10)
	chat_input.set_offset(SIDE_TOP, 270)
	chat_input.set_offset(SIDE_RIGHT, 410)
	chat_input.set_offset(SIDE_BOTTOM, 300)
	chat_container.add_child(chat_input)

	var send_button = HitboxGenerator.create_texture_button_with_hitbox("res://assets/ui/paper_plane.png")
	send_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	send_button.set_offset(SIDE_LEFT, 410)
	send_button.set_offset(SIDE_TOP, 260)
	send_button.set_offset(SIDE_RIGHT, 450)
	send_button.set_offset(SIDE_BOTTOM, 300)
	send_button.connect("pressed", Callable(self, "_on_send_pressed"))
	chat_container.add_child(send_button)

func _create_game_settings_display():
	var settings_display = Panel.new()
	settings_display.set_anchors_preset(Control.PRESET_TOP_LEFT)
	settings_display.set_offset(SIDE_LEFT, 10)
	settings_display.set_offset(SIDE_TOP, 10)
	settings_display.set_offset(SIDE_RIGHT, 260)
	settings_display.set_offset(SIDE_BOTTOM, 210)
	add_child(settings_display)
	
	var settings_label = Label.new()
	settings_label.text = "Round Duration: 5 min\nStarting Budget: $1,000,000\nNumber of Rounds: 3"
	settings_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	settings_label.set_offset(SIDE_LEFT, 10)
	settings_label.set_offset(SIDE_TOP, 10)
	settings_label.set_offset(SIDE_RIGHT, 240)
	settings_label.set_offset(SIDE_BOTTOM, 190)
	settings_display.add_child(settings_label)

func _create_particle_effects():
	# Particle Effects
	var particles = GPUParticles2D.new()
	var particle_material = ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particle_material.emission_box_extents = Vector3(1920, 1, 1)
	particle_material.direction = Vector3(0, 1, 0)
	particle_material.spread = 10
	particle_material.gravity = Vector3(0, 98, 0)
	particle_material.initial_velocity_min = 50
	particle_material.initial_velocity_max = 100
	particle_material.scale_min = 0.05
	particle_material.scale_max = 0.3
	particles.process_material = particle_material
	particles.texture = load("res://assets/ui/confetti.png")
	particles.amount = 20
	particles.lifetime = 5
	add_child(particles)
	
func show_notification(message):
	var notification = Label.new()
	notification.text = message
	notification.add_theme_color_override("font_color", Color.YELLOW)
	notification.set_anchors_preset(Control.PRESET_TOP_LEFT)
	notification.set_offset(SIDE_LEFT, 860)
	notification.set_offset(SIDE_TOP, 50)
	notification.set_offset(SIDE_RIGHT, 1060)
	notification.set_offset(SIDE_BOTTOM, 80)
	add_child(notification)
	
	var tween = create_tween()
	tween.tween_property(notification, "position:y", notification.position.y - 50, 1.0)
	tween.parallel().tween_property(notification, "modulate:a", 0, 1.0)
	tween.tween_callback(notification.queue_free)

func _load_avatars():
	for i in range(1, 9):  # Assuming 8 avatar images
		avatars.append(load("res://assets/avatars/avatar_%02d.png" % i))

func update_lobby_codes(global_code, local_code):
	code_label.text = "Global Code: " + global_code + "                 Local Code: " + local_code

func _on_send_pressed():
	var chat_input = chat_container.get_node("LineEdit")
	if chat_input.text.strip_edges() != "":
		get_parent().play_sound("button_click")
		get_parent()._receive_chat_message(get_parent().players[multiplayer.get_unique_id()]["name"], chat_input.text, "Everyone")
		chat_input.text = ""

func _on_start_pressed():
	get_parent().play_sound("button_click")
	emit_signal("start_game")

func _on_add_ai_pressed():
	emit_signal("add_ai_player")

func _on_remove_ai_pressed():
	emit_signal("remove_ai_player")

func update_player_list(players):
	print("Updating player list with players: ", players)
	for i in range(player_cards.size()):
		var card = player_cards[i]
		if i < players.size():
			var player = players.values()[i]
			_update_player_card(card, player)
			card.show()
		else:
			card.hide()

func _update_player_card(card, player):
	var avatar_texture = load("res://assets/avatars/avatar_%02d.png" % player["avatar"])
	
	var avatar_node = card.get_node("AvatarTexture")
	avatar_node.texture = avatar_texture
	
	var name_label = card.get_node("NameLabel")
	name_label.text = player["name"]
	
	var ai_indicator = card.get_node_or_null("AIIndicator")
	if player.get("is_ai", false):
		if not ai_indicator:
			ai_indicator = Label.new()
			ai_indicator.name = "AIIndicator"
			ai_indicator.text = "AI"
			ai_indicator.add_theme_font_size_override("font_size", 30)
			ai_indicator.add_theme_color_override("font_color", Color.RED)
			ai_indicator.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 15)
			card.add_child(ai_indicator)
	elif ai_indicator:
		ai_indicator.queue_free()
