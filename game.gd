extends Node2D

const Role = preload("res://main.gd").Role
const GameState = preload("res://main.gd").GameState
const AIPlayer = preload("res://ai_player.gd")

signal game_ended

var players = {}
var candidates = []
var player_id = 0
var current_round = 0
var round_timer = 0
var game_state = GameState.PLAYING
var resumes = []
var offers = {}
var accepted_offers = []
var current_player_role: int
var player_ui: Control

var chat_window: Panel
var notification_area: Panel
var emoji_panel: Panel
var notification_vbox: VBoxContainer
var notification_scroll: ScrollContainer

var round_duration = 300  # Default value, will be set by main script
var ceo_starting_budget = 1000000  # Default value, will be set by main script
var total_rounds = 3  # Default value, will be set by main script

var chat_histories = {}
var current_chat_partner = "Everyone"

var ai_players = {}

var emojis = ["👍", "👎", "😊", "😢", "💼", "💰"]

func _ready():
	current_player_role = players[player_id]["role"]
	_create_common_elements()
	if current_player_role == Role.CEO:
		_create_ceo_ui()
	else:
		_create_candidate_ui()
	_create_chat_window()
	_create_notification_area()
	_create_emoji_panel()
	_start_round()

func initialize(p_players, player_idd, p_round_duration, p_ceo_starting_budget, p_total_rounds, p_resumes, p_ai_players):
	players = p_players
	player_id = player_idd
	round_duration = p_round_duration
	ceo_starting_budget = p_ceo_starting_budget
	total_rounds = p_total_rounds
	resumes = p_resumes
	
	for ai_id in p_ai_players:
		ai_players[ai_id] = AIPlayer.new(players[ai_id]["role"], ai_id, players[ai_id]["budget"], players[ai_id].get("resume", {}), self)
		ai_players[ai_id].ai_action_interval = 3.0

func _create_common_elements():
	var background = TextureRect.new()
	background.texture = load("res://assets/backgrounds/" + ("ceo_background.png" if current_player_role == Role.CEO else "candidate_background.png"))
	background.expand = true
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	score_label.set_offset(SIDE_LEFT, 860)
	score_label.set_offset(SIDE_TOP, 10)
	score_label.set_offset(SIDE_RIGHT, 1060)
	score_label.set_offset(SIDE_BOTTOM, 50)
	score_label.add_theme_color_override("font_color", Color.BLACK)
	score_label.text = "Score: 0"
	add_child(score_label)

	var timer = TextureProgressBar.new()
	timer.name = "Timer"
	timer.texture_progress = load("res://assets/ui/clock.png")
	timer.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	timer.set_offset(SIDE_LEFT, 860)
	timer.set_offset(SIDE_TOP, 60)
	timer.set_offset(SIDE_RIGHT, 1060)
	timer.set_offset(SIDE_BOTTOM, 110)
	add_child(timer)

	var resume_display = TextureRect.new()
	resume_display.name = "ResumeDisplay"
	resume_display.texture = load("res://assets/ui/clipboard.png")
	resume_display.expand = true
	resume_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	resume_display.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	resume_display.set_offset(SIDE_LEFT, 640)
	resume_display.set_offset(SIDE_TOP, 120)
	resume_display.set_offset(SIDE_RIGHT, 1280)
	resume_display.set_offset(SIDE_BOTTOM, 1070)
	add_child(resume_display)

	var resume_text = RichTextLabel.new()
	resume_text.name = "ResumeText"
	resume_text.bbcode_enabled = true
	resume_text.fit_content = true
	resume_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resume_text.set_offset(SIDE_LEFT, 120)
	resume_text.set_offset(SIDE_TOP, 310)
	resume_text.set_offset(SIDE_RIGHT, 600)
	resume_text.set_offset(SIDE_BOTTOM, 800)
	resume_display.add_child(resume_text)
	
func _update_chat_display():
	var chat_display = chat_window.get_node("ChatDisplay")
	chat_display.clear()
	
	if current_chat_partner == "Everyone":
		for message in chat_histories["Everyone"]:
			chat_display.append_text(message + "\n")
	else:
		var current_player_id = str(player_id)
		var partner_id = str(_get_player_id_by_name(current_chat_partner))
		for message in chat_histories[current_player_id][partner_id]:
			chat_display.append_text(message + "\n")

# Update the _on_player_selected function:
func _on_player_selected(index):
	var player_dropdown = chat_window.get_node("OptionButton")
	current_chat_partner = player_dropdown.get_item_text(index)
	_update_chat_display()

# Add this helper function:
func _get_player_id_by_name(player_name):
	if player_name == "Everyone":
		return "Everyone"
	for player_id in players:
		if players[player_id]["name"] == player_name:
			return str(player_id)
	return null
	
func _str_to_int_id(id):
	return int(id) if id != "Everyone" else id

# Update the _show_notification function to handle global and personal notifications:
@rpc("any_peer", "reliable", "call_local")
func _show_global_notification(message):
	_show_notification(message, true)
	
func _show_notification(message, is_global = false):
	print(message)
	var notification = Label.new()
	notification.text = message
	
	if is_global:
		notification.add_theme_color_override("font_color", Color.YELLOW)
	else:
		notification.add_theme_color_override("font_color", Color.WHITE)
	
	notification_vbox.add_child(notification)
	
	var tween = create_tween()
	tween.tween_property(notification, "modulate:a", 1.0, 0.5).from(0.0)
	tween.tween_interval(3.0)
	tween.tween_property(notification, "modulate:a", 0.0, 0.5)
	tween.tween_callback(notification.queue_free)
	
	# Scroll to the bottom to show the latest notification
	await get_tree().create_timer(0.1).timeout  # Wait for the next frame
	notification_scroll.scroll_vertical = notification_scroll.get_v_scroll_bar().max_value

func _create_notification_area():
	notification_area = Panel.new()
	notification_area.name = "NotificationArea"
	notification_area.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	notification_area.set_offset(SIDE_LEFT, 0)
	notification_area.set_offset(SIDE_TOP, 0)
	notification_area.set_offset(SIDE_RIGHT, 640)
	notification_area.set_offset(SIDE_BOTTOM, 540)
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.1, 0.1, 0.1, 0.7)  # Dark, semi-transparent background
	style_box.corner_radius_top_left = 10
	style_box.corner_radius_top_right = 10
	style_box.corner_radius_bottom_left = 10
	style_box.corner_radius_bottom_right = 10
	notification_area.add_theme_stylebox_override("panel", style_box)
	
	add_child(notification_area)
	
	notification_scroll = ScrollContainer.new()
	notification_scroll.name = "NotificationScroll"
	notification_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notification_scroll.set_offset(SIDE_LEFT, 10)
	notification_scroll.set_offset(SIDE_TOP, 10)
	notification_scroll.set_offset(SIDE_RIGHT, -10)
	notification_scroll.set_offset(SIDE_BOTTOM, -10)
	notification_area.add_child(notification_scroll)
	
	notification_vbox = VBoxContainer.new()
	notification_vbox.name = "NotificationVBox"
	notification_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notification_scroll.add_child(notification_vbox)

func _create_ceo_ui():
	var candidate_list = ItemList.new()
	candidate_list.name = "CandidateList"
	candidate_list.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	candidate_list.set_offset(SIDE_LEFT, 0)
	candidate_list.set_offset(SIDE_TOP, 540)
	candidate_list.set_offset(SIDE_RIGHT, 640)
	candidate_list.set_offset(SIDE_BOTTOM, 950)
	candidate_list.connect("item_selected", Callable(self, "_on_candidate_selected"))
	add_child(candidate_list)

	var offer_input = LineEdit.new()
	offer_input.name = "OfferInput"
	offer_input.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	offer_input.set_offset(SIDE_LEFT, 0)
	offer_input.set_offset(SIDE_TOP, 960)
	offer_input.set_offset(SIDE_RIGHT, 490)
	offer_input.set_offset(SIDE_BOTTOM, 1010)
	offer_input.placeholder_text = "Enter offer amount"
	add_child(offer_input)

	var budget_display = TextureRect.new()
	budget_display.name = "BudgetDisplay"
	budget_display.texture = load("res://assets/ui/money_stack.png")
	budget_display.expand = true
	budget_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	budget_display.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	budget_display.set_offset(SIDE_LEFT, 0)
	budget_display.set_offset(SIDE_TOP, 1020)
	budget_display.set_offset(SIDE_RIGHT, 50)
	budget_display.set_offset(SIDE_BOTTOM, 1070)
	add_child(budget_display)

	var budget_label = Label.new()
	budget_label.name = "BudgetLabel"
	budget_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	budget_label.set_offset(SIDE_LEFT, 60)
	budget_label.set_offset(SIDE_TOP, 1020)
	budget_label.set_offset(SIDE_RIGHT, 490)
	budget_label.set_offset(SIDE_BOTTOM, 1070)
	budget_label.text = "Budget: $" + str(ceo_starting_budget)
	budget_label.add_theme_color_override("font_color", Color.BLACK)
	add_child(budget_label)

	var make_offer_button = HitboxGenerator.create_texture_button_with_hitbox("res://assets/buttons/make_offer.png")
	make_offer_button.name = "MakeOfferButton"
	make_offer_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	make_offer_button.set_offset(SIDE_LEFT, 540)
	make_offer_button.set_offset(SIDE_TOP, 960)
	make_offer_button.set_offset(SIDE_RIGHT, 640)
	make_offer_button.set_offset(SIDE_BOTTOM, 1070)
	make_offer_button.connect("pressed", Callable(self, "_on_make_offer_pressed"))
	add_child(make_offer_button)
	
	_update_offer_display()

func _create_candidate_ui():
	var offer_list = ItemList.new()
	offer_list.name = "OfferList"
	offer_list.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	offer_list.set_offset(SIDE_LEFT, 0)
	offer_list.set_offset(SIDE_TOP, 540)
	offer_list.set_offset(SIDE_RIGHT, 640)
	offer_list.set_offset(SIDE_BOTTOM, 950)
	add_child(offer_list)

	var accept_offer_button = HitboxGenerator.create_texture_button_with_hitbox("res://assets/buttons/accept_offer.png")
	accept_offer_button.name = "AcceptOfferButton"
	accept_offer_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	accept_offer_button.set_offset(SIDE_LEFT, 0)
	accept_offer_button.set_offset(SIDE_TOP, 960)
	accept_offer_button.set_offset(SIDE_RIGHT, 310)
	accept_offer_button.set_offset(SIDE_BOTTOM, 1070)
	accept_offer_button.connect("pressed", Callable(self, "_on_accept_offer_pressed"))
	add_child(accept_offer_button)

	var decline_offer_button = HitboxGenerator.create_texture_button_with_hitbox("res://assets/buttons/decline_offer.png")
	decline_offer_button.name = "DeclineOfferButton"
	decline_offer_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	decline_offer_button.set_offset(SIDE_LEFT, 330)
	decline_offer_button.set_offset(SIDE_TOP, 960)
	decline_offer_button.set_offset(SIDE_RIGHT, 640)
	decline_offer_button.set_offset(SIDE_BOTTOM, 1070)
	decline_offer_button.connect("pressed", Callable(self, "_on_decline_offer_pressed"))
	add_child(decline_offer_button)

func _create_chat_window():
	chat_window = Panel.new()
	chat_window.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	chat_window.set_offset(SIDE_LEFT, 1280)
	chat_window.set_offset(SIDE_TOP, 0)
	chat_window.set_offset(SIDE_RIGHT, 1920)
	chat_window.set_offset(SIDE_BOTTOM, 1020)
	add_child(chat_window)

	var player_dropdown = OptionButton.new()
	player_dropdown.name = "OptionButton"
	player_dropdown.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	player_dropdown.set_offset(SIDE_LEFT, 10)
	player_dropdown.set_offset(SIDE_TOP, 10)
	player_dropdown.set_offset(SIDE_RIGHT, 630)
	player_dropdown.set_offset(SIDE_BOTTOM, 50)
	player_dropdown.add_item("Everyone")
	print(players)
	print("tetrrge")
	for player_idd in players:
		print(players[player_idd])
		if players[player_idd]["name"] != players[player_id]["name"]:
			player_dropdown.add_item(players[player_idd]["name"])
	player_dropdown.connect("item_selected", Callable(self, "_on_player_selected"))
	chat_window.add_child(player_dropdown)

	var chat_display = RichTextLabel.new()
	chat_display.name = "ChatDisplay"
	chat_display.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	chat_display.set_offset(SIDE_LEFT, 10)
	chat_display.set_offset(SIDE_TOP, 60)
	chat_display.set_offset(SIDE_RIGHT, 630)
	chat_display.set_offset(SIDE_BOTTOM, 940)
	chat_window.add_child(chat_display)

	var chat_input = LineEdit.new()
	chat_input.name = "ChatInput"
	chat_input.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	chat_input.set_offset(SIDE_LEFT, 10)
	chat_input.set_offset(SIDE_TOP, 950)
	chat_input.set_offset(SIDE_RIGHT, 590)
	chat_input.set_offset(SIDE_BOTTOM, 1010)
	chat_window.add_child(chat_input)

	var send_button = HitboxGenerator.create_texture_button_with_hitbox("res://assets/ui/paper_plane.png")
	send_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	send_button.set_offset(SIDE_LEFT, 600)
	send_button.set_offset(SIDE_TOP, 950)
	send_button.set_offset(SIDE_RIGHT, 630)
	send_button.set_offset(SIDE_BOTTOM, 1010)
	send_button.connect("pressed", Callable(self, "_on_chat_send_pressed"))
	chat_window.add_child(send_button)
	
	# Initialize chat histories
	_initialize_chat_histories()
	
func _initialize_chat_histories():
	chat_histories["Everyone"] = []
	for player_id in players:
		chat_histories[str(player_id)] = {}
		for other_id in players:
			if player_id != other_id:
				chat_histories[str(player_id)][str(other_id)] = []

func _create_emoji_panel():
	emoji_panel = Panel.new()
	emoji_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	emoji_panel.set_offset(SIDE_LEFT, 1280)
	emoji_panel.set_offset(SIDE_TOP, 1020)
	emoji_panel.set_offset(SIDE_RIGHT, 1920)
	emoji_panel.set_offset(SIDE_BOTTOM, 1070)
	add_child(emoji_panel)

	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	score_label.text = "Score: " + str(players[player_id]["score"])

func _end_game():
	emit_signal("game_ended")

func _show_game_over_screen():
	var game_over_panel = Panel.new()
	game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(game_over_panel)
	
	var vbox = VBoxContainer.new()
	game_over_panel.add_child(vbox)
	
	var game_over_label = Label.new()
	game_over_label.text = "Game Over!"
	game_over_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(game_over_label)
	
	var final_score_label = Label.new()
	final_score_label.text = "Your Final Score: " + str(players[player_id]["score"])
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
	var offer_input = get_node("OfferInput")
	var candidate_list = get_node("CandidateList")
	
	var amount = int(offer_input.text)
	var selected_items = candidate_list.get_selected_items()
	
	if selected_items.is_empty():
		_show_notification("Please select a candidate first.")
		return
	
	var candidate_id = players.keys()[selected_items[0]]
	
	if amount <= 0 or amount > players[player_id]["budget"]:
		_show_notification("Invalid offer amount.")
		return
	
	players[player_id]["budget"] -= amount
	offers[candidate_id] = {"ceo_id": player_id, "amount": amount}
	
	_update_budget_display()
	_update_offers(offers)
	
	rpc("_show_global_notification", "Offer of $" + str(amount) + " made to " + players[candidate_id]["name"])
	SoundManager.play_sound("offer_made")
	
func make_offer(ceo_id, candidate_id, amount):
	if ceo_id in players and players[ceo_id]["role"] == Role.CEO and players[ceo_id]["budget"] >= amount:
		offers[candidate_id] = {"ceo_id": ceo_id, "amount": amount}
		players[ceo_id]["budget"] -= amount
		_update_offer_display()
		rpc("_update_offers", offers)
		rpc("_update_player_list", players)

func _on_accept_offer_pressed():
	if current_player_role != Role.CANDIDATE:
		return
		
	var current_player_id = player_id
	
	for i in range(accepted_offers.size()):
		if accepted_offers[i].has(current_player_id):
			return
			
	var offer_list = get_node("OfferList")
	var selected_items = offer_list.get_selected_items()
	
	if selected_items.is_empty():
		_show_notification("Please select an offer first.")
		return
	
	var offer = offers[current_player_id]
	
	rpc("_update_accepted_offers", {current_player_id: offer})
	
	rpc("_show_global_notification", "Offer of $" + str(offer["amount"]) + " accepted from " + players[offer["ceo_id"]]["name"])
	SoundManager.play_sound("offer_accepted")

func _on_decline_offer_pressed():
	if current_player_role != Role.CANDIDATE:
		return

	var offer_list = get_node("OfferList")
	var selected_items = offer_list.get_selected_items()
	
	if selected_items.is_empty():
		_show_notification("Please select an offer first.")
		return
	
	var offer = offers[player_id]
	offers.erase(player_id)
	
	_update_offers(offers)
	
	rpc("_show_global_notification", "Offer of $" + str(offer["amount"]) + " declined from " + players[offer["ceo_id"]]["name"])
	SoundManager.play_sound("offer_declined")

func _update_budget_display():
	var budget_label = get_node("BudgetLabel")
	budget_label.text = "Budget: $" + str(players[player_id]["budget"])

func _update_offer_display():
	if current_player_role == Role.CANDIDATE:
		var offer_list = get_node("OfferList")
		offer_list.clear()
		
		if player_id in offers:
			var offer = offers[player_id]
			offer_list.add_item("Offer from " + players[offer["ceo_id"]]["name"] + ": $" + str(offer["amount"]))
	elif current_player_role == Role.CEO:
		var candidate_list = get_node("CandidateList")
		candidate_list.clear()
		for player_id in players:
			if players[player_id]["role"] == Role.CANDIDATE:
				candidates.append(player_id)
				candidate_list.add_item(players[player_id]["name"])

@rpc("any_peer", "reliable", "call_local")
func _update_offers(new_offers):
	offers = new_offers
	_update_offer_display()

@rpc("any_peer", "reliable", "call_local")
func _update_accepted_offers(offer):
	accepted_offers.append(offer)
	_update_offer_display()

func _on_chat_send_pressed():
	var chat_input = chat_window.get_node("ChatInput")
	var message = chat_input.text.strip_edges()
	
	if message != "":
		var sender_id = str(player_id)
		var sender_name = players[int(sender_id)]["name"]
		
		if current_chat_partner == "Everyone":
			_add_chat_message(sender_name, message, "Everyone")
			rpc("_receive_chat_message", sender_name, message, "Everyone")
		else:
			var recipient_id = _get_player_id_by_name(current_chat_partner)
			_add_chat_message(sender_name, message, recipient_id)
			rpc_id(int(recipient_id), "_receive_chat_message", sender_name, message, sender_id)
		
		chat_input.text = ""
		
@rpc("any_peer", "reliable", "call_local")
func _receive_chat_message(sender_name, message, recipient):
	if recipient == "Everyone":
		_add_chat_message(sender_name, message, "Everyone")
	else:
		var recipient_id = str(recipient)
		_add_chat_message(sender_name, message, recipient_id)
	
	if current_chat_partner == "Everyone" or current_chat_partner == sender_name:
		_update_chat_display()
		
func receive_ai_chat_message(sender_name, message, recipient):
	_receive_chat_message(sender_name, message, str(recipient))

func _add_chat_message(sender_name, message, recipient):
	var formatted_message = "[color=yellow]%s:[/color] %s" % [sender_name, message]
	
	if recipient == "Everyone":
		chat_histories["Everyone"].append(formatted_message)
	else:
		var sender_id = str(_get_player_id_by_name(sender_name))
		var recipient_id = str(recipient)
		
		chat_histories[sender_id][recipient_id].append(formatted_message)
		if sender_id != recipient_id:
			chat_histories[recipient_id][sender_id].append(formatted_message)
	
	_update_chat_display()

func _on_candidate_selected(index):
	var candidate_id = candidates[index]
	print(candidate_id)
	if players[candidate_id]["role"] == Role.CANDIDATE:
		_show_resume(players[candidate_id]["resume"])

func _show_resume(resume):
	print("resume")
	var resume_text = get_node("ResumeDisplay/ResumeText")
	resume_text.bbcode_text = """[color=black]
	[b]Name:[/b] %s
	[b]Age:[/b] %d
	[b]Education:[/b] %s
	[b]Skills:[/b] %s
	[b]Experience:[/b] %s
	[/color]
	""" % [resume["name"], resume["age"], resume["education"], resume["skills"], resume["experience"]]

func _handle_ai_actions(delta):
	for ai_id in ai_players:
		ai_players[ai_id].make_decision(delta)

func _on_emoji_pressed(emoji):
	rpc("_broadcast_emoji", players[player_id]["name"], emoji)

@rpc("any_peer", "reliable", "call_local")
func _broadcast_emoji(player_name, emoji):
	_show_notification(player_name + ": " + emoji, true)
	SoundManager.play_sound("emoji_reaction")

# Add any additional helper functions or AI-related functions here
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

func get_game_state():
	return {
		"players": players,
		"current_round": current_round,
		"round_timer": round_timer,
		"game_state": game_state,
		"resumes": resumes,
		"offers": offers,
		"accepted_offers": accepted_offers
	}

func set_game_state(state):
	players = state["players"]
	current_round = state["current_round"]
	round_timer = state["round_timer"]
	game_state = state["game_state"]
	resumes = state["resumes"]
	offers = state["offers"]
	accepted_offers = state["accepted_offers"]
	_update_game_display()

func _update_game_display():
	# Update all UI elements based on the new game state
	_update_score_display()
	_update_timer()
	_update_offer_display()
	# Add any other necessary display updates
