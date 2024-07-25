extends Node2D

const Role = preload("res://main.gd").Role
const GameState = preload("res://main.gd").GameState
const AIPlayer = preload("res://ai_player.gd")

signal game_ended

var players = {}
var current_round = 0
var round_timer = 0
var game_state = GameState.PLAYING
var resumes = []
var offers = {}
var accepted_offers = []
var current_player_role: int
var player_ui: Control

var ceo_section: Control
var candidate_section: Control
var chat_sidebar: Control
var notification_area: Control
var emoji_panel: Panel

var round_duration = 300  # Default value, will be set by main script
var ceo_starting_budget = 1000000  # Default value, will be set by main script
var total_rounds = 3  # Default value, will be set by main script

var ai_players = {}

var emojis = ["👍", "👎", "😊", "😢", "💼", "💰"]

func _ready():
	current_player_role = players[multiplayer.get_unique_id()]["role"]
	_create_player_ui()
	_create_common_elements()
	_create_chat_sidebar()
	_create_notification_area()
	_create_emoji_panel()
	_start_round()

func initialize(p_players, p_round_duration, p_ceo_starting_budget, p_total_rounds, p_resumes, p_ai_players):
	players = p_players
	round_duration = p_round_duration
	ceo_starting_budget = p_ceo_starting_budget
	total_rounds = p_total_rounds
	resumes = p_resumes
	
	for ai_id in p_ai_players:
		ai_players[ai_id] = AIPlayer.new(players[ai_id]["role"], ai_id, players[ai_id]["budget"], players[ai_id].get("resume", {}), self)

func _create_player_ui():
	player_ui = Control.new()
	player_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(player_ui)

	var background = TextureRect.new()
	background.texture = load("res://assets/backgrounds/" + ("ceo_office.png" if current_player_role == Role.CEO else "candidate_room.png"))
	background.expand = true
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player_ui.add_child(background)

	if current_player_role == Role.CEO:
		_create_ceo_ui()
	else:
		_create_candidate_ui()

func _create_ceo_ui():
	var budget_display = TextureProgressBar.new()
	budget_display.texture_progress = load("res://assets/ui/money_stack.png")
	budget_display.custom_minimum_size = Vector2(300, 50)
	budget_display.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	player_ui.add_child(budget_display)
	
	var candidate_list = ItemList.new()
	candidate_list.custom_minimum_size = Vector2(400, 600)
	candidate_list.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE, Control.PRESET_MODE_MINSIZE, 20)
	candidate_list.connect("item_selected", Callable(self, "_on_candidate_selected"))
	player_ui.add_child(candidate_list)
	
	var offer_input = LineEdit.new()
	offer_input.custom_minimum_size = Vector2(200, 50)
	offer_input.placeholder_text = "Enter offer amount"
	offer_input.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	player_ui.add_child(offer_input)
	
	var make_offer_button = HitboxGenerator.create_texture_button_with_hitbox("res://assets/buttons/make_offer.png")
	make_offer_button.custom_minimum_size = Vector2(150, 50)
	make_offer_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	make_offer_button.position.x = offer_input.position.x + offer_input.size.x + 10
	make_offer_button.connect("pressed", Callable(self, "_on_make_offer_pressed"))
	player_ui.add_child(make_offer_button)

func _create_candidate_ui():
	var resume_display = TextureRect.new()
	resume_display.texture = load("res://assets/ui/clipboard.png")
	resume_display.expand = true
	resume_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	resume_display.custom_minimum_size = Vector2(400, 600)
	resume_display.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE, Control.PRESET_MODE_MINSIZE, 20)
	player_ui.add_child(resume_display)
	
	var resume_text = RichTextLabel.new()
	resume_text.bbcode_enabled = true
	resume_text.fit_content = true
	resume_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	resume_display.add_child(resume_text)
	
	var offer_list = ItemList.new()
	offer_list.custom_minimum_size = Vector2(400, 300)
	offer_list.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE, Control.PRESET_MODE_MINSIZE, 20)
	player_ui.add_child(offer_list)
	
	var accept_offer_button = HitboxGenerator.create_texture_button_with_hitbox("res://assets/buttons/accept_offer.png")
	accept_offer_button.custom_minimum_size = Vector2(200, 50)
	accept_offer_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	accept_offer_button.connect("pressed", Callable(self, "_on_accept_offer_pressed"))
	player_ui.add_child(accept_offer_button)

func _create_common_elements():
	var timer = TextureProgressBar.new()
	timer.texture_progress = load("res://assets/ui/clock.png")
	timer.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 20)
	add_child(timer)
	
	var score_display = Label.new()
	score_display.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 20)
	add_child(score_display)

func _create_chat_sidebar():
	chat_sidebar = Panel.new()
	chat_sidebar.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE, Control.PRESET_MODE_MINSIZE, 20)
	chat_sidebar.set_custom_minimum_size(Vector2(200, 0))
	add_child(chat_sidebar)
	
	var chat_display = RichTextLabel.new()
	chat_display.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 10)
	chat_sidebar.add_child(chat_display)
	
	var chat_input = LineEdit.new()
	chat_input.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 10)
	chat_sidebar.add_child(chat_input)
	
	var send_button = HitboxGenerator.create_texture_button_with_hitbox("res://assets/buttons/send.png")
	send_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	send_button.connect("pressed", Callable(self, "_on_chat_send_pressed"))
	chat_sidebar.add_child(send_button)

func _create_notification_area():
	notification_area = VBoxContainer.new()
	notification_area.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 20)
	add_child(notification_area)

func _create_emoji_panel():
	emoji_panel = Panel.new()
	emoji_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 20)
	add_child(emoji_panel)
	
	var hbox = HBoxContainer.new()
	emoji_panel.add_child(hbox)
	
	for emoji in emojis:
		var button = Button.new()
		button.text = emoji
		button.connect("pressed", Callable(self, "_on_emoji_pressed").bind(emoji))
		hbox.add_child(button)

func _start_round():
	current_round += 1
	round_timer = round_duration
	offers.clear()
	accepted_offers.clear()
	
	_animate_round_start()
	
	set_process(true)

func _animate_round_start():
	var round_label = Label.new()
	round_label.text = "Round " + str(current_round)
	round_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(round_label)
	
	var tween = create_tween()
	tween.tween_property(round_label, "modulate:a", 1.0, 0.5).from(0.0)
	tween.tween_property(round_label, "scale", Vector2(1.5, 1.5), 0.5).from(Vector2(1, 1))
	tween.tween_property(round_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(round_label.queue_free)
	
	SoundManager.play_sound("round_start")

func _process(delta):
	if round_timer > 0:
		round_timer -= delta
		_update_timer()
		_handle_ai_actions(delta)
	else:
		_end_round()

func _update_timer():
	var timer = get_node("Timer")
	timer.value = (round_timer / round_duration) * 100
	
	if round_timer <= 10:
		var tween = create_tween()
		tween.tween_property(timer, "modulate", Color.RED, 0.5)
		tween.tween_property(timer, "modulate", Color.WHITE, 0.5)

func _end_round():
	set_process(false)
	_animate_round_end()
	_calculate_scores()
	
	if current_round >= total_rounds:
		_end_game()
	else:
		_start_round()

func _animate_round_end():
	var round_end_label = Label.new()
	round_end_label.text = "Round " + str(current_round) + " Ended!"
	round_end_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(round_end_label)
	
	var tween = create_tween()
	tween.tween_property(round_end_label, "modulate:a", 1.0, 0.5).from(0.0)
	tween.tween_property(round_end_label, "scale", Vector2(1.5, 1.5), 0.5).from(Vector2(1, 1))
	tween.tween_property(round_end_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(round_end_label.queue_free)
	
	SoundManager.play_sound("round_end")

func _calculate_scores():
	for player_id in players:
		if players[player_id]["role"] == Role.CEO:
			var total_value = 0
			var total_paid = 0
			for candidate_id in accepted_offers:
				if accepted_offers[candidate_id]["ceo_id"] == player_id:
					total_value += players[candidate_id]["resume"]["value"]
					total_paid += accepted_offers[candidate_id]["amount"]
			players[player_id]["score"] += total_value - total_paid
		else:
			if player_id in accepted_offers:
				players[player_id]["score"] += accepted_offers[player_id]["amount"] - players[player_id]["resume"]["value"]
	
	_update_score_display()

func _update_score_display():
	var score_label = get_node("ScoreLabel")
	score_label.text = "Score: " + str(players[multiplayer.get_unique_id()]["score"])
	
	var tween = create_tween()
	tween.tween_property(score_label, "modulate", Color.GREEN, 0.5)
	tween.tween_property(score_label, "modulate", Color.WHITE, 0.5)

func _end_game():
	emit_signal("game_ended")
	_show_game_over_screen()

func _show_game_over_screen():
	var game_over_panel = Panel.new()
	game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	add_child(game_over_panel)
	
	var vbox = VBoxContainer.new()
	game_over_panel.add_child(vbox)
	
	var game_over_label = Label.new()
	game_over_label.text = "Game Over!"
	game_over_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(game_over_label)
	
	var final_score_label = Label.new()
	final_score_label.text = "Your Final Score: " + str(players[multiplayer.get_unique_id()]["score"])
	vbox.add_child(final_score_label)
	
	var return_to_menu_button = Button.new()
	return_to_menu_button.text = "Return to Main Menu"
	return_to_menu_button.connect("pressed", Callable(self, "_on_return_to_menu_pressed"))
	vbox.add_child(return_to_menu_button)
	
	_animate_game_over_screen(game_over_panel)
	
	SoundManager.play_sound("game_over")

func _animate_game_over_screen(panel):
	panel.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 1.0)
	tween.parallel().tween_property(panel, "scale", Vector2(1, 1), 1.0).from(Vector2(0.5, 0.5))

func _on_return_to_menu_pressed():
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_make_offer_pressed():
	if current_player_role != Role.CEO:
		return
	var offer_input = player_ui.get_node("LineEdit")  # Update node path as necessary
	var candidate_list = player_ui.get_node("ItemList")  # Update node path as necessary
	
	var amount = int(offer_input.text)
	var selected_items = candidate_list.get_selected_items()
	
	if selected_items.is_empty():
		_show_error("Please select a candidate first.")
		return
	
	var candidate_id = players.keys()[selected_items[0]]
	
	if amount <= 0 or amount > players[multiplayer.get_unique_id()]["budget"]:
		_show_error("Invalid offer amount.")
		return
	
	players[multiplayer.get_unique_id()]["budget"] -= amount
	offers[candidate_id] = {"ceo_id": multiplayer.get_unique_id(), "amount": amount}
	
	_animate_offer_submission(offer_input.global_position, candidate_list.get_selected_items()[0].global_position)
	_update_budget_display()
	rpc("_update_offers", offers)
	
	SoundManager.play_sound("offer_made")

func _animate_offer_submission(from_pos: Vector2, to_pos: Vector2):
	var paper_plane = Sprite2D.new()
	paper_plane.texture = load("res://assets/ui/paper_plane.png")
	paper_plane.position = from_pos
	add_child(paper_plane)
	
	var tween = create_tween()
	tween.tween_property(paper_plane, "position", to_pos, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(paper_plane.queue_free)

func _update_budget_display():
	var budget_label = ceo_section.get_node("BudgetLabel")
	budget_label.text = "Budget: $" + str(players[multiplayer.get_unique_id()]["budget"])
	
	var tween = create_tween()
	tween.tween_property(budget_label, "modulate", Color.RED, 0.5)
	tween.tween_property(budget_label, "modulate", Color.WHITE, 0.5)

@rpc("any_peer", "reliable")
func _update_offers(new_offers):
	offers = new_offers
	_update_offer_display()

func _update_offer_display():
	if players[multiplayer.get_unique_id()]["role"] == Role.CANDIDATE:
		var offer_list = candidate_section.get_node("OfferList")
		offer_list.clear()
		
		if multiplayer.get_unique_id() in offers:
			var offer = offers[multiplayer.get_unique_id()]
			offer_list.add_item("Offer from " + players[offer["ceo_id"]]["name"] + ": $" + str(offer["amount"]))
			_animate_offer_received(offer_list.global_position)

func _animate_offer_received(pos: Vector2):
	var envelope = Sprite2D.new()
	envelope.texture = load("res://assets/ui/envelope.png")
	envelope.position = pos
	add_child(envelope)
	
	var tween = create_tween()
	tween.tween_property(envelope, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(envelope, "scale", Vector2(1.0, 1.0), 0.2)
	tween.tween_interval(0.5)
	tween.tween_callback(envelope.queue_free)
	
	SoundManager.play_sound("offer_received")

func _on_accept_offer_pressed():
	if current_player_role != Role.CANDIDATE:
		return

	var offer_list = player_ui.get_node("ItemList")
	var selected_items = offer_list.get_selected_items()
	
	if selected_items.is_empty():
		_show_error("Please select an offer first.")
		return
	
	var offer = offers[multiplayer.get_unique_id()]
	accepted_offers[multiplayer.get_unique_id()] = offer
	
	_animate_offer_accepted(offer["amount"])
	rpc("_update_accepted_offers", accepted_offers)
	
	SoundManager.play_sound("offer_accepted")

func _animate_offer_accepted(amount):
	var accept_label = Label.new()
	accept_label.text = "Offer Accepted: $" + str(amount)
	accept_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(accept_label)
	
	var tween = create_tween()
	tween.tween_property(accept_label, "scale", Vector2(1.5, 1.5), 0.5).from(Vector2(1, 1))
	tween.tween_property(accept_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(accept_label.queue_free)
	
	_animate_hiring(accept_label.global_position)

func _animate_hiring(pos: Vector2):
	var particles = CPUParticles2D.new()
	particles.texture = load("res://assets/ui/confetti.png")
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	add_child(particles)
	
	await get_tree().create_timer(2.0).timeout
	particles.queue_free()

@rpc("any_peer", "reliable")
func _update_accepted_offers(new_accepted_offers):
	accepted_offers = new_accepted_offers
	_update_offer_display()

func _show_error(message):
	var error_label = Label.new()
	error_label.text = message
	error_label.add_theme_color_override("font_color", Color.RED)
	error_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 20)
	add_child(error_label)
	
	var tween = create_tween()
	tween.tween_property(error_label, "modulate:a", 1.0, 0.5).from(0.0)
	tween.tween_interval(2.0)
	tween.tween_property(error_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(error_label.queue_free)

func _on_chat_send_pressed():
	var chat_input = chat_sidebar.get_node("ChatInput")
	var message = chat_input.text.strip_edges()
	
	if message != "":
		_add_chat_message(players[multiplayer.get_unique_id()]["name"], message)
		rpc("_receive_chat_message", players[multiplayer.get_unique_id()]["name"], message)
		chat_input.text = ""

@rpc("any_peer", "reliable")
func _receive_chat_message(sender_name, message):
	_add_chat_message(sender_name, message)

func _add_chat_message(sender_name, message):
	var chat_display = chat_sidebar.get_node("ChatDisplay")
	var formatted_message = "[color=yellow]%s:[/color] %s" % [sender_name, message]
	chat_display.append_bbcode(formatted_message + "\n")
	
	var tween = create_tween()
	tween.tween_property(chat_display, "scroll_vertical", chat_display.get_v_scroll_bar().max_value, 0.5)

func _on_candidate_selected(index):
	var candidate_id = players.keys()[index]
	if players[candidate_id]["role"] == Role.CANDIDATE:
		_show_resume(players[candidate_id]["resume"])

func _show_resume(resume):
	var resume_popup = Panel.new()
	resume_popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	add_child(resume_popup)
	
	var resume_text = RichTextLabel.new()
	resume_text.bbcode_text = """
	[b]Name:[/b] %s
	[b]Age:[/b] %d
	[b]Education:[/b] %s
	[b]Skills:[/b] %s
	[b]Experience:[/b] %s
	""" % [resume["name"], resume["age"], resume["education"], resume["skills"], resume["experience"]]
	resume_popup.add_child(resume_text)
	
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.connect("pressed", Callable(resume_popup, "queue_free"))
	resume_popup.add_child(close_button)

func _handle_ai_actions(delta):
	for ai_id in ai_players:
		ai_players[ai_id].make_decision()

func make_offer(ceo_id, candidate_id, amount):
	if ceo_id in players and players[ceo_id]["role"] == Role.CEO and players[ceo_id]["budget"] >= amount:
		offers[candidate_id] = {"ceo_id": ceo_id, "amount": amount}
		players[ceo_id]["budget"] -= amount
		_update_offer_display()
		rpc("_update_offers", offers)
		rpc("_update_player_list", players)

func accept_offer(candidate_id, ceo_id, amount):
	if candidate_id in players and players[candidate_id]["role"] == Role.CANDIDATE:
		if candidate_id in offers and offers[candidate_id]["ceo_id"] == ceo_id:
			accepted_offers[candidate_id] = {"ceo_id": ceo_id, "amount": amount}
			_update_offer_display()
			rpc("_update_accepted_offers", accepted_offers)

func get_available_candidates():
	var available = []
	for player_id in players:
		if players[player_id]["role"] == Role.CANDIDATE and player_id not in accepted_offers:
			available.append(players[player_id])
	return available

func get_offers_for_candidate(candidate_id):
	if candidate_id in offers:
		return [offers[candidate_id]]
	return []

func get_remaining_time():
	return round_timer

func _on_emoji_pressed(emoji):
	rpc("_broadcast_emoji", players[multiplayer.get_unique_id()]["name"], emoji)

@rpc("any_peer", "reliable")
func _broadcast_emoji(player_name, emoji):
	var emoji_label = Label.new()
	emoji_label.text = player_name + ": " + emoji
	emoji_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 20)
	add_child(emoji_label)
	
	var tween = create_tween()
	tween.tween_property(emoji_label, "modulate:a", 1.0, 0.5).from(0.0)
	tween.tween_interval(2.0)
	tween.tween_property(emoji_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(emoji_label.queue_free)
	
	SoundManager.play_sound("emoji_reaction")

func _animate_budget_update(amount: int):
	var label = Label.new()
	label.text = ("+" if amount > 0 else "") + str(amount)
	label.add_theme_color_override("font_color", Color.GREEN if amount > 0 else Color.RED)
	label.position = ceo_section.get_node("BudgetLabel").position + Vector2(0, -30)
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 50, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)
