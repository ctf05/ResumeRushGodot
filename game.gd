extends Node2D

signal game_ended

const Role = preload("res://main.gd").Role
const GameState = preload("res://main.gd").GameState

var players = {}
var current_round = 0
var round_timer = 0
var game_state = GameState.PLAYING
var resumes = []
var offers = {}
var accepted_offers = []

var game_ui: Control
var chat_box: RichTextLabel
var chat_input: LineEdit
var timer_label: Label

var round_duration = 300  # Default value, will be set by main script
var ceo_starting_budget = 1000000  # Default value, will be set by main script
var total_rounds = 3  # Default value, will be set by main script

var custom_theme: Theme

var tween: Tween

var ai_players = []

# Unique references to specific nodes
var offer_input: LineEdit
var candidate_list: ItemList
var offer_list: ItemList

# AI and Chat variables
var AI_ACTION_INTERVAL = 5  # AI performs an action every 5 seconds
var ai_timer = 0
var chat_history = {}
var current_chat_partner = "Everyone"
var chat_partner_dropdown: OptionButton

func _ready():
	_initialize_game_ui()
	_start_round()
	_initialize_chat_history()

func initialize(p_players, p_round_duration, p_ceo_starting_budget, p_total_rounds, p_custom_theme, p_resumes, p_ai_players):
	players = p_players
	round_duration = p_round_duration
	ceo_starting_budget = p_ceo_starting_budget
	total_rounds = p_total_rounds
	custom_theme = p_custom_theme
	resumes = p_resumes
	ai_players = p_ai_players

func _initialize_game_ui():
	print("Initializing game UI")
	game_ui = Control.new()
	game_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(game_ui)
	
	if custom_theme:
		print("Applying custom theme to game UI")
		game_ui.theme = custom_theme
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	game_ui.add_child(vbox)
	
	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)
	
	timer_label = Label.new()
	timer_label.text = "Time: " + str(round_duration)
	timer_label.add_theme_font_size_override("font_size", 24)
	hbox.add_child(timer_label)
	
	var score_label = Label.new()
	score_label.text = "Score: 0"
	score_label.add_theme_font_size_override("font_size", 24)
	hbox.add_child(score_label)
	
	print("Initializing role-specific UI")
	if players[multiplayer.get_unique_id()]["role"] == Role.CEO:
		_initialize_ceo_ui(vbox)
	else:
		_initialize_candidate_ui(vbox)
	
	_initialize_chat_system(vbox)
	
	print("Game UI initialization complete")

func _initialize_ceo_ui(parent):
	var hbox = HBoxContainer.new()
	parent.add_child(hbox)
	
	var left_panel = VBoxContainer.new()
	hbox.add_child(left_panel)
	
	var budget_label = Label.new()
	budget_label.text = "Budget: $" + str(players[multiplayer.get_unique_id()]["budget"])
	left_panel.add_child(budget_label)
	
	candidate_list = ItemList.new()
	candidate_list.set_custom_minimum_size(Vector2(200, 200))
	for player_id in players:
		if players[player_id]["role"] == Role.CANDIDATE:
			candidate_list.add_item(players[player_id]["name"])
	left_panel.add_child(candidate_list)
	
	var right_panel = VBoxContainer.new()
	right_panel.name = "RightPanel"  # Assign a name for easy access later
	hbox.add_child(right_panel)
	
	offer_input = LineEdit.new()
	offer_input.name = "OfferInput"  # Assign a name for easy access later
	offer_input.placeholder_text = "Enter offer amount"
	right_panel.add_child(offer_input)
	
	var make_offer_button = Button.new()
	make_offer_button.text = "Make Offer"
	make_offer_button.pressed.connect(self._on_make_offer_pressed)
	right_panel.add_child(make_offer_button)

func _initialize_candidate_ui(parent):
	var hbox = HBoxContainer.new()
	parent.add_child(hbox)
	
	var left_panel = VBoxContainer.new()
	hbox.add_child(left_panel)
	
	var resume_display = RichTextLabel.new()
	resume_display.set_custom_minimum_size(Vector2(200, 200))
	var resume = players[multiplayer.get_unique_id()]["resume"]
	resume_display.text = "Name: %s\nAge: %d\nEducation: %s\nSkills: %s\nExperience: %s" % [
		resume["name"], resume["age"], resume["education"], resume["skills"], resume["experience"]
	]
	left_panel.add_child(resume_display)
	
	var right_panel = VBoxContainer.new()
	hbox.add_child(right_panel)
	
	offer_list = ItemList.new()
	offer_list.set_custom_minimum_size(Vector2(200, 200))
	right_panel.add_child(offer_list)
	
	var accept_offer_button = Button.new()
	accept_offer_button.text = "Accept Offer"
	accept_offer_button.pressed.connect(self._on_accept_offer_pressed)
	right_panel.add_child(accept_offer_button)
	
	right_panel.name = "RightPanel"  # Assign a name for easy access later
	offer_list.name = "OfferList"

func _initialize_chat_system(parent):
	var chat_container = VBoxContainer.new()
	chat_container.set_custom_minimum_size(Vector2(0, 200))
	parent.add_child(chat_container)
	
	chat_partner_dropdown = OptionButton.new()
	chat_partner_dropdown.add_item("Everyone")
	for player_id in players:
		if player_id != multiplayer.get_unique_id():
			chat_partner_dropdown.add_item(players[player_id]["name"])
	chat_partner_dropdown.connect("item_selected", self._on_chat_partner_changed)
	chat_container.add_child(chat_partner_dropdown)
	
	chat_box = RichTextLabel.new()
	chat_box.scroll_following = true
	chat_box.set_custom_minimum_size(Vector2(0, 150))
	chat_container.add_child(chat_box)
	
	var input_container = HBoxContainer.new()
	chat_container.add_child(input_container)
	
	chat_input = LineEdit.new()
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_container.add_child(chat_input)
	
	var send_button = Button.new()
	send_button.text = "Send"
	send_button.pressed.connect(self._on_chat_send_pressed)
	input_container.add_child(send_button)

func _initialize_chat_history():
	chat_history = {}
	chat_history["Everyone"] = []
	for player_id in players:
		chat_history[players[player_id]["name"]] = []

func _on_chat_partner_changed(index):
	current_chat_partner = chat_partner_dropdown.get_item_text(index)
	if current_chat_partner not in chat_history:
		chat_history[current_chat_partner] = []
	_update_chat_display()

func _update_chat_display():
	chat_box.clear()
	if current_chat_partner in chat_history:
		for message in chat_history[current_chat_partner]:
			chat_box.add_text(message + "\n")
	else:
		print("Chat history not found for: ", current_chat_partner)

func _on_chat_send_pressed():
	var message = chat_input.text
	if message.strip_edges() != "":
		_receive_chat_message(players[multiplayer.get_unique_id()]["name"], message, current_chat_partner)
		rpc("_receive_chat_message", players[multiplayer.get_unique_id()]["name"], message, current_chat_partner)
		chat_input.text = ""
	get_parent().play_sound("button_click")

@rpc("any_peer", "reliable")
func _receive_chat_message(sender_name, message, recipient):
	var formatted_message = sender_name + ": " + message
	
	# Ensure chat histories exist for sender and recipient
	if sender_name not in chat_history:
		chat_history[sender_name] = []
	if recipient not in chat_history and recipient != "Everyone":
		chat_history[recipient] = []
	
	if recipient == "Everyone":
		chat_history["Everyone"].append(formatted_message)
		_update_chat_display()
	else:
		chat_history[sender_name].append(formatted_message)
		chat_history[recipient].append(formatted_message)
		if current_chat_partner == sender_name or current_chat_partner == recipient:
			_update_chat_display()
	
	# Show notification and update local player's chat history
	if recipient == players[multiplayer.get_unique_id()]["name"] or recipient == "Everyone":
		_show_chat_notification(sender_name)
		if recipient != "Everyone":
			chat_history[players[multiplayer.get_unique_id()]["name"]].append(formatted_message)

	print("Chat message received - Sender: ", sender_name, ", Recipient: ", recipient, ", Message: ", message)

func _get_player_id_by_name(player_name):
	for player_id in players:
		if players[player_id]["name"] == player_name:
			return player_id
	return -1

func _show_chat_notification(sender_name):
	var notification = Label.new()
	notification.text = "New message from " + sender_name
	notification.add_theme_color_override("font_color", Color.RED)
	game_ui.add_child(notification)
	
	var tween = create_tween()
	tween.tween_property(notification, "modulate:a", 0, 2)
	tween.tween_callback(notification.queue_free)

func _on_make_offer_pressed():
	get_parent().play_sound("button_click")

	var amount = int(offer_input.text)
	print("Offer amount entered: ", amount)
	
	var selected_items = candidate_list.get_selected_items()
	if selected_items.is_empty():
		_show_error_dialog("Please select a candidate first.")
		return
	
	var candidate_index = selected_items[0]
	var candidate_id = players.keys()[candidate_index]
	print("Candidate ID selected: ", candidate_id)
	
	if amount <= players[multiplayer.get_unique_id()]["budget"]:
		offers[candidate_id] = {"ceo_id": multiplayer.get_unique_id(), "amount": amount}
		players[multiplayer.get_unique_id()]["budget"] -= amount
		get_parent().play_sound("offer_made")
		rpc("_update_offers", offers)
		rpc("_update_player_list", players)
		
		# Animate the offer being made
		var offer_label = Label.new()
		offer_label.text = "Offer: $" + str(amount)
		offer_label.position = Vector2(get_viewport().size.x / 2, get_viewport().size.y)
		add_child(offer_label)
		_animate_ui_element(offer_label, "position:y", get_viewport().size.y, get_viewport().size.y / 2, 0.5)
		await get_tree().create_timer(1.0).timeout
		_animate_ui_element(offer_label, "modulate:a", 1, 0, 0.5)
		await get_tree().create_timer(0.5).timeout
		offer_label.queue_free()
	else:
		_show_error_dialog("Insufficient funds")
		
func _on_accept_offer_pressed():
	get_parent().play_sound("button_click")
	
	var player_id = multiplayer.get_unique_id()
	if player_id in accepted_offers:
		_show_error_dialog("You have already accepted an offer this round.")
		return
	
	var selected_items = offer_list.get_selected_items()
	if selected_items.is_empty():
		_show_error_dialog("Please select an offer first.")
		return
	
	var offer_index = selected_items[0]
	var ceo_id = offers.keys()[offer_index]
	
	if player_id not in offers or offers[player_id]["ceo_id"] != ceo_id:
		_show_error_dialog("Invalid offer selected.")
		return
	
	get_parent().play_sound("offer_accepted")
	_finalize_offer(player_id, ceo_id)
	
	# Animate the offer acceptance
	var acceptance_label = Label.new()
	acceptance_label.text = "Offer Accepted!"
	acceptance_label.position = Vector2(get_viewport().size.x / 2, get_viewport().size.y / 2)
	acceptance_label.modulate.a = 0
	add_child(acceptance_label)
	
	_animate_ui_element(acceptance_label, "modulate:a", 0, 1, 0.5)
	await get_tree().create_timer(1.0).timeout
	_animate_ui_element(acceptance_label, "modulate:a", 1, 0, 0.5)
	await get_tree().create_timer(0.5).timeout
	acceptance_label.queue_free()

func _process(delta):
	if game_state == GameState.PLAYING:
		if round_timer > 0:
			round_timer -= delta
			if is_instance_valid(timer_label):
				timer_label.text = "Time: " + str(int(round_timer))
			else:
				print("Timer label is not valid during _process")
		
		if round_timer <= 0:
			print("Round timer reached 0, ending round")
			_end_round()
		
		# AI actions
		ai_timer += delta
		if ai_timer >= AI_ACTION_INTERVAL:
			ai_timer = 0
			_ai_turn()

func _start_round():
	print("Starting round ", current_round)
	round_timer = round_duration
	offers.clear()
	accepted_offers.clear()  # Clear accepted offers at the start of each round
	get_parent().play_sound("round_start")
	
	if is_instance_valid(timer_label):
		timer_label.text = "Time: " + str(int(round_timer))
	else:
		print("Timer label is not valid at round start")
	
	set_process(true)
	
	# Animate the round start
	var round_label = Label.new()
	round_label.text = "Round " + str(current_round) + " Start!"
	round_label.position = Vector2(get_viewport().size.x / 2, get_viewport().size.y / 2)
	round_label.modulate.a = 0
	add_child(round_label)
	
	_animate_ui_element(round_label, "modulate:a", 0, 1, 0.5)
	_animate_ui_element(round_label, "scale", Vector2(0.5, 0.5), Vector2(1, 1), 0.5)
	await get_tree().create_timer(1.5).timeout
	_animate_ui_element(round_label, "modulate:a", 1, 0, 0.5)
	await get_tree().create_timer(0.5).timeout
	round_label.queue_free()
	
	# AI turns
	_ai_turn()

func _end_round():
	print("Ending round")
	set_process(false)
	get_parent().play_sound("round_end")
	_calculate_scores()
	current_round += 1
	if current_round > total_rounds:
		print("All rounds completed, ending game")
		_end_game()
	else:
		print("Starting next round")
		_start_round()

func _calculate_scores():
	for player_id in players:
		if players[player_id]["role"] == Role.CEO:
			var total_value = 0
			var total_paid = 0
			for candidate_id in offers:
				if offers[candidate_id]["ceo_id"] == player_id:
					total_value += players[candidate_id]["resume"]["value"]
					total_paid += offers[candidate_id]["amount"]
			players[player_id]["score"] += total_value - total_paid
		else:
			if player_id in offers:
				players[player_id]["score"] += offers[player_id]["amount"] - players[player_id]["resume"]["value"]
	rpc("_update_player_list", players)

func _end_game():
	game_state = GameState.ENDED
	get_parent().play_sound("game_over")
	emit_signal("game_ended")

func _ai_turn():
	for ai_id in ai_players:
		if players[ai_id]["role"] == Role.CEO:
			_ai_make_offer(ai_id)
		elif players[ai_id]["role"] == Role.CANDIDATE:
			_ai_accept_offer(ai_id)
		
		# AI chat
		if randf() < 0.3:  # 30% chance to send a chat message
			_ai_send_chat(ai_id)

func _ai_make_offer(ai_id):
	if players[ai_id]["role"] != Role.CEO:
		return
	
	for candidate_id in players:
		if players[candidate_id]["role"] == Role.CANDIDATE and candidate_id not in offers:
			var candidate_value = players[candidate_id]["resume"]["value"]
			var offer_amount = int(candidate_value * (0.8 + randf() * 0.4))  # 80% to 120% of true value
			
			if offer_amount <= players[ai_id]["budget"]:
				offers[candidate_id] = {"ceo_id": ai_id, "amount": offer_amount}
				players[ai_id]["budget"] -= offer_amount
				rpc("_update_offers", offers)
				rpc("_update_player_list", players)
				print("AI CEO ", ai_id, " made an offer of $", offer_amount, " to candidate ", candidate_id)
				break

func _ai_accept_offer(ai_id):
	if players[ai_id]["role"] != Role.CANDIDATE:
		print("AI ", ai_id, " is not a candidate")
		return
	
	if ai_id in accepted_offers:
		print("AI Candidate ", ai_id, " has already accepted an offer")
		return
	
	if ai_id not in offers:
		print("No offers for AI Candidate ", ai_id)
		return
	
	var best_offer = offers[ai_id]
	print("AI Candidate ", ai_id, " attempting to accept an offer of $", best_offer["amount"], " from CEO ", best_offer["ceo_id"])
	_finalize_offer(ai_id, best_offer["ceo_id"])

func _ai_send_chat(ai_id):
	var message = "Hello from AI " + str(ai_id) + "!"
	var recipient = "Everyone" if randf() < 0.5 else players[players.keys()[randi() % players.size()]]["name"]
	_receive_chat_message(players[ai_id]["name"], message, recipient)
	rpc("_receive_chat_message", players[ai_id]["name"], message, recipient)
	print("AI ", ai_id, " sent a chat message to ", recipient, ": ", message)

@rpc("any_peer", "reliable")
func _update_offers(new_offers):
	offers = new_offers
	_update_offer_ui()

func _finalize_offer(candidate_id, ceo_id):
	print("Attempting to finalize offer for candidate ", candidate_id, " from CEO ", ceo_id)
	print("Current accepted_offers: ", accepted_offers)
	
	if candidate_id in accepted_offers:
		print("Offer already accepted for candidate ", candidate_id)
		return
	
	if candidate_id not in offers or offers[candidate_id]["ceo_id"] != ceo_id:
		print("Invalid offer for candidate ", candidate_id)
		return
	
	var offer = offers[candidate_id]
	players[ceo_id]["budget"] -= offer["amount"]
	players[candidate_id]["final_offer"] = offer["amount"]
	players[candidate_id]["hired_by"] = players[ceo_id]["name"]
	players[ceo_id]["hires"] = players[ceo_id].get("hires", 0) + 1
	accepted_offers.append(candidate_id)  # Add candidate ID to the accepted_offers array
	offers.erase(candidate_id)  # Remove the offer after it's accepted
	_update_offer_ui()
	_update_player_list(players)
	print("Offer finalized for candidate ", candidate_id, " from CEO ", ceo_id)
	print("Updated accepted_offers: ", accepted_offers)

func _update_offer_ui():
	if players[multiplayer.get_unique_id()]["role"] == Role.CANDIDATE:
		offer_list.clear()
		var player_id = multiplayer.get_unique_id()
		if player_id in offers and player_id not in accepted_offers:
			offer_list.add_item("Offer from " + players[offers[player_id]["ceo_id"]]["name"] + ": $" + str(offers[player_id]["amount"]))
		elif player_id in accepted_offers:
			offer_list.add_item("You have accepted an offer this round.")
	elif players[multiplayer.get_unique_id()]["role"] == Role.CEO:
		# Update CEO UI to show which offers have been accepted
		# This part depends on how you've structured your CEO UI
		pass
		
func _show_error_dialog(message):
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "Error"
	add_child(dialog)
	dialog.popup_centered()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if game_state == GameState.PLAYING:
			_show_pause_menu()

func _show_pause_menu():
	var pause_menu = Control.new()
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.set_process_input(true)
	
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE, 20)
	pause_menu.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	panel.add_child(vbox)
	
	var resume_button = Button.new()
	resume_button.text = "Resume"
	resume_button.pressed.connect(func(): pause_menu.queue_free())
	vbox.add_child(resume_button)
	
	var quit_button = Button.new()
	quit_button.text = "Quit to Main Menu"
	quit_button.pressed.connect(func(): get_tree().reload_current_scene())
	vbox.add_child(quit_button)
	
	add_child(pause_menu)
	get_tree().paused = true
	
	pause_menu.connect("tree_exited", func(): get_tree().paused = false)

func _animate_ui_element(element: Control, property: String, start_value, end_value, duration: float):
	if not is_instance_valid(element):
		print("Invalid element for animation")
		return
	
	if tween and tween.is_valid():
		tween.kill()  # Stop any ongoing animations
	
	tween = create_tween()
	tween.set_parallel(true)
	element.set(property, start_value)
	tween.tween_property(element, property, end_value, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

@rpc("any_peer", "reliable")
func _update_player_list(new_players):
	players = new_players
	# Update UI elements that display player information
	# This might include updating score displays, budget information, etc.
