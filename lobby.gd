extends Control

signal start_game
signal add_ai_player
signal remove_ai_player

var player_cards = []
var avatars = []
var chat_container: Control
var whiteboard: TextureRect
var global_code_label: Label
var local_code_label: Label

func _ready():
	_load_avatars()
	_create_background()
	_create_player_cards()
	_create_room_code_display()
	_create_chat_system()
	_create_game_settings_display()
	_create_start_button()
	_create_ai_controls()

func _load_avatars():
	for i in range(1, 21):  # Assuming 20 avatar images
		avatars.append(load("res://assets/avatars/avatar_%02d.png" % i))

func _create_background():
	var background = TextureRect.new()
	background.texture = load("res://assets/backgrounds/lobby_background.png")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

func _create_player_cards():
	var card_container = HBoxContainer.new()
	card_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 20)
	add_child(card_container)

	for i in range(8):  # Assuming max 8 players
		var card = _create_player_card()
		card_container.add_child(card)
		player_cards.append(card)

func _create_player_card():
	var card = Panel.new()
	card.set_custom_minimum_size(Vector2(100, 150))
	
	var avatar = TextureRect.new()
	avatar.texture = avatars[randi() % avatars.size()]
	avatar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 10)
	card.add_child(avatar)
	
	var name_label = Label.new()
	name_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 10)
	card.add_child(name_label)
	
	return card

func _create_room_code_display():
	whiteboard = TextureRect.new()
	whiteboard.texture = load("res://assets/furniture/whiteboard.png")
	whiteboard.expand = true
	whiteboard.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	whiteboard.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE)
	add_child(whiteboard)

	var codes_container = VBoxContainer.new()
	codes_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	whiteboard.add_child(codes_container)

	global_code_label = Label.new()
	global_code_label.text = "Global Code: ..."
	codes_container.add_child(global_code_label)

	local_code_label = Label.new()
	local_code_label.text = "Local Code: ..."
	codes_container.add_child(local_code_label)

func _create_chat_system():
	chat_container = Panel.new()
	chat_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	chat_container.set_custom_minimum_size(Vector2(300, 200))
	add_child(chat_container)
	
	var chat_display = RichTextLabel.new()
	chat_display.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 10)
	chat_container.add_child(chat_display)
	
	var chat_input = LineEdit.new()
	chat_input.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 10)
	chat_container.add_child(chat_input)

	var send_button = Button.new()
	send_button.text = "Send"
	send_button.connect("pressed", Callable(self, "_on_send_pressed"))
	chat_container.add_child(send_button)

func _create_game_settings_display():
	var settings_display = Panel.new()
	settings_display.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	add_child(settings_display)
	
	var settings_label = Label.new()
	settings_label.text = "Round Duration: 5 min\nStarting Budget: $1,000,000"  # Replace with actual settings
	settings_display.add_child(settings_label)

func _create_start_button():
	var start_button = HitboxGenerator.create_texture_button_with_hitbox("res://assets/buttons/go_sign.png")
	start_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	start_button.connect("pressed", Callable(self, "_on_start_pressed"))
	add_child(start_button)

func _create_ai_controls():
	var ai_control_container = HBoxContainer.new()
	ai_control_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	add_child(ai_control_container)

	var add_ai_button = HitboxGenerator.create_texture_button_with_hitbox("res://assets/buttons/add_ai.png")
	add_ai_button.connect("pressed", Callable(self, "_on_add_ai_pressed"))
	ai_control_container.add_child(add_ai_button)

	var remove_ai_button = HitboxGenerator.create_texture_button_with_hitbox("res://assets/buttons/remove_ai.png")
	remove_ai_button.connect("pressed", Callable(self, "_on_remove_ai_pressed"))
	ai_control_container.add_child(remove_ai_button)

func update_player_list(players):
	for i in range(player_cards.size()):
		if i < players.size():
			var player = players.values()[i]
			var card = player_cards[i]
			card.get_node("TextureRect").texture = avatars[randi() % avatars.size()]
			card.get_node("Label").text = player["name"]
			card.show()
		else:
			player_cards[i].hide()

func update_lobby_codes(global_code, local_code):
	global_code_label.text = "Global Code: " + global_code
	local_code_label.text = "Local Code: " + local_code

func _on_send_pressed():
	var chat_input = chat_container.get_node("LineEdit")
	if chat_input.text.strip_edges() != "":
		get_parent().play_sound("button_click")
		get_parent()._receive_chat_message(get_parent().players[multiplayer.get_unique_id()]["name"], chat_input.text, "Everyone")
		chat_input.text = ""

func _on_start_pressed():
	get_parent().play_sound("button_click")
	emit_signal("start_game")

func show_notification(message):
	var notification = Label.new()
	notification.text = message
	notification.add_theme_color_override("font_color", Color.YELLOW)
	add_child(notification)
	
	var tween = create_tween()
	tween.tween_property(notification, "position:y", notification.position.y - 50, 1.0)
	tween.parallel().tween_property(notification, "modulate:a", 0, 1.0)
	tween.tween_callback(notification.queue_free)

func _on_add_ai_pressed():
	emit_signal("add_ai_player")

func _on_remove_ai_pressed():
	emit_signal("remove_ai_player")
