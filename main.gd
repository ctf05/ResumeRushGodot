extends Node

const MIN_PLAYERS = 4
const MAX_PLAYERS = 8
const DEFAULT_ROUND_DURATION = 300  # 5 minutes in seconds
const DEFAULT_CEO_STARTING_BUDGET = 1000000

enum Role { CEO, CANDIDATE }
enum GameState { LOBBY, PLAYING, ENDED }

var players = {}
var current_round = 0
var round_timer = 0
var game_state = GameState.LOBBY
var resumes = []
var offers = {}

var peer = ENetMultiplayerPeer.new()

var main_menu
var game_ui
var chat_box
var chat_input

var round_duration = DEFAULT_ROUND_DURATION
var ceo_starting_budget = DEFAULT_CEO_STARTING_BUDGET
var total_rounds = 3

@onready var background_music = $BackgroundMusic
@onready var sfx_player = $SFXPlayer

var custom_theme

var sound_effects = {
	"button_click": preload("res://assets/audio/button_click.wav"),
	"offer_made": preload("res://assets/audio/offer_made.wav"),
	"offer_accepted": preload("res://assets/audio/offer_accepted.wav"),
	"round_start": preload("res://assets/audio/round_start.wav"),
	"round_end": preload("res://assets/audio/round_end.wav"),
	"game_over": preload("res://assets/audio/game_over.wav")
}

var tween: Tween

var ai_players = []

func _ready():
	multiplayer.peer_connected.connect(self._player_connected)
	multiplayer.peer_disconnected.connect(self._player_disconnected)
	
	_load_theme()
	_initialize_main_menu()
	_load_resumes()
	_load_audio()
	
	tween = create_tween()
	tween.set_parallel(true)

func _load_theme():
	custom_theme = load("res://theme.tres")
	if custom_theme:
		theme = custom_theme

func _load_audio():
	var music = load("res://assets/audio/background_music.ogg")
	background_music.stream = music
	background_music.play()

func play_sound(sound_name):
	if sound_name in sound_effects:
		sfx_player.stream = sound_effects[sound_name]
		sfx_player.play()

func _initialize_main_menu():
	main_menu = Control.new()
	main_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_menu.add_child(vbox)
	
	var title = Label.new()
	title.text = "ResumeRush"
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)
	
	var host_button = Button.new()
	host_button.text = "Host Game"
	host_button.pressed.connect(self._on_host_pressed)
	vbox.add_child(host_button)
	
	var join_button = Button.new()
	join_button.text = "Join Game"
	join_button.pressed.connect(self._on_join_pressed)
	vbox.add_child(join_button)
	
	var options_button = Button.new()
	options_button.text = "Options"
	options_button.pressed.connect(self._on_options_pressed)
	vbox.add_child(options_button)
	
	var tutorial_button = Button.new()
	tutorial_button.text = "How to Play"
	tutorial_button.pressed.connect(self._show_tutorial)
	vbox.add_child(tutorial_button)
	
	var exit_button = Button.new()
	exit_button.text = "Exit"
	exit_button.pressed.connect(self._on_exit_pressed)
	vbox.add_child(exit_button)
	
	add_child(main_menu)

func _on_host_pressed():
	play_sound("button_click")
	create_server()
	_show_lobby()

func _on_join_pressed():
	play_sound("button_click")
	_show_ip_dialog()

func _on_options_pressed():
	play_sound("button_click")
	_show_options_menu()

func _on_exit_pressed():
	play_sound("button_click")
	get_tree().quit()

func _show_ip_dialog():
	var dialog = AcceptDialog.new()
	dialog.title = "Join Game"
	
	var ip_input = LineEdit.new()
	ip_input.placeholder_text = "Enter IP Address"
	dialog.add_child(ip_input)
	
	dialog.add_button("Join", true, "join")
	dialog.connect("custom_action", func(action):
		if action == "join":
			join_server(ip_input.text)
			_show_lobby()
		dialog.queue_free()
	)
	
	add_child(dialog)
	dialog.popup_centered()

func _show_options_menu():
	var options_menu = Control.new()
	options_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE, 20)
	options_menu.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	panel.add_child(vbox)
	
	var round_duration_input = SpinBox.new()
	round_duration_input.min_value = 60
	round_duration_input.max_value = 600
	round_duration_input.value = round_duration
	round_duration_input.prefix = "Round Duration: "
	round_duration_input.suffix = " seconds"
	round_duration_input.connect("value_changed", func(value): round_duration = value)
	vbox.add_child(round_duration_input)
	
	var budget_input = SpinBox.new()
	budget_input.min_value = 500000
	budget_input.max_value = 2000000
	budget_input.step = 100000
	budget_input.value = ceo_starting_budget
	budget_input.prefix = "CEO Starting Budget: $"
	budget_input.connect("value_changed", func(value): ceo_starting_budget = value)
	vbox.add_child(budget_input)
	
	var rounds_input = SpinBox.new()
	rounds_input.min_value = 1
	rounds_input.max_value = 10
	rounds_input.value = total_rounds
	rounds_input.prefix = "Total Rounds: "
	rounds_input.connect("value_changed", func(value): total_rounds = value)
	vbox.add_child(rounds_input)
	
	var back_button = Button.new()
	back_button.text = "Back to Main Menu"
	back_button.pressed.connect(func(): options_menu.queue_free())
	vbox.add_child(back_button)
	
	add_child(options_menu)

func _show_lobby():
	main_menu.hide()
	var lobby = preload("res://lobby.tscn").instantiate()
	add_child(lobby)

func _player_connected(id):
	print("Player connected: ", id)
	players[id] = {"role": null, "score": 0, "budget": ceo_starting_budget, "name": "Player " + str(id)}
	rpc("_update_player_list", players)

func _player_disconnected(id):
	print("Player disconnected: ", id)
	players.erase(id)
	rpc("_update_player_list", players)
	if game_state == GameState.PLAYING and players.size() < MIN_PLAYERS:
		_end_game()

@rpc("any_peer", "reliable")
func _update_player_list(new_players):
	players = new_players
	if has_node("Lobby"):
		get_node("Lobby").update_player_list(players)

func _start_game():
	if game_state != GameState.LOBBY or players.size() < MIN_PLAYERS:
		return
	
	game_state = GameState.PLAYING
	current_round = 1
	_assign_roles()
	_initialize_game_ui()
	_start_round()

func _assign_roles():
	var player_ids = players.keys()
	player_ids.shuffle()
	for i in range(player_ids.size()):
		var role = Role.CEO if i < player_ids.size() / 2 else Role.CANDIDATE
		players[player_ids[i]]["role"] = role
		if role == Role.CANDIDATE:
			players[player_ids[i]]["resume"] = _assign_resume()
	rpc("_update_player_list", players)

func _initialize_game_ui():
	if has_node("Lobby"):
		get_node("Lobby").queue_free()
	
	game_ui = Control.new()
	game_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	game_ui.add_child(vbox)
	
	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)
	
	var timer_label = Label.new()
	timer_label.text = "Time: " + str(round_duration)
	hbox.add_child(timer_label)
	
	var score_label = Label.new()
	score_label.text = "Score: 0"
	hbox.add_child(score_label)
	
	if players[multiplayer.get_unique_id()]["role"] == Role.CEO:
		_initialize_ceo_ui(vbox)
	else:
		_initialize_candidate_ui(vbox)
	
	_initialize_chat_system(vbox)
	
	add_child(game_ui)
	
	# Animate the UI elements appearing
	for child in game_ui.get_children():
		child.modulate.a = 0
		_animate_ui_element(child, "modulate:a", 0, 1, 0.5)

func _initialize_ceo_ui(parent):
	var hbox = HBoxContainer.new()
	parent.add_child(hbox)
	
	var left_panel = VBoxContainer.new()
	hbox.add_child(left_panel)
	
	var budget_label = Label.new()
	budget_label.text = "Budget: $" + str(players[multiplayer.get_unique_id()]["budget"])
	left_panel.add_child(budget_label)
	
	var candidate_list = ItemList.new()
	candidate_list.set_custom_minimum_size(Vector2(200, 200))
	for player_id in players:
		if players[player_id]["role"] == Role.CANDIDATE:
			candidate_list.add_item(players[player_id]["name"])
	left_panel.add_child(candidate_list)
	
	var right_panel = VBoxContainer.new()
	hbox.add_child(right_panel)
	
	var offer_input = LineEdit.new()
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
	
	var offer_list = ItemList.new()
	offer_list.set_custom_minimum_size(Vector2(200, 200))
	right_panel.add_child(offer_list)
	
	var accept_offer_button = Button.new()
	accept_offer_button.text = "Accept Offer"
	accept_offer_button.pressed.connect(self._on_accept_offer_pressed)
	right_panel.add_child(accept_offer_button)

func _initialize_chat_system(parent):
	var chat_container = VBoxContainer.new()
	chat_container.set_custom_minimum_size(Vector2(0, 150))
	parent.add_child(chat_container)
	
	chat_box = RichTextLabel.new()
	chat_box.scroll_following = true
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

func _on_chat_send_pressed():
	var message = chat_input.text
	if message.strip_edges() != "":
		rpc("_receive_chat_message", players[multiplayer.get_unique_id()]["name"], message)
		chat_input.text = ""
	play_sound("button_click")

@rpc("any_peer", "reliable")
func _receive_chat_message(sender_name, message):
	chat_box.add_text(sender_name + ": " + message + "\n")

func _start_round():
	round_timer = round_duration
	offers.clear()
	play_sound("round_start")
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

func _process(delta):
	if game_state == GameState.PLAYING:
		round_timer -= delta
		game_ui.get_node("VBoxContainer/HBoxContainer/Label").text = "Time: " + str(int(round_timer))
		
		if round_timer <= 0:
			_end_round()

func _end_round():
	set_process(false)
	play_sound("round_end")
	_calculate_scores()
	current_round += 1
	if current_round > total_rounds:
		_end_game()
	else:
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
	play_sound("game_over")
	_show_end_game_screen()

func _show_end_game_screen():
	game_ui.queue_free()
	
	var end_screen = Control.new()
	end_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var scroll_container = ScrollContainer.new()
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_screen.add_child(scroll_container)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	scroll_container.add_child(vbox)
	
	var title = Label.new()
	title.text = "Game Over - Final Results"
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)
	
	var ceo_stats = _get_ceo_statistics()
	var candidate_stats = _get_candidate_statistics()
	
	vbox.add_child(_create_statistics_table("CEO Statistics", ceo_stats))
	vbox.add_child(_create_statistics_table("Candidate Statistics", candidate_stats))
	
	var overall_stats = _get_overall_statistics()
	vbox.add_child(_create_statistics_table("Overall Game Statistics", overall_stats))
	
	var return_button = Button.new()
	return_button.text = "Return to Main Menu"
	return_button.pressed.connect(self._on_return_to_menu_pressed)
	vbox.add_child(return_button)
	
	add_child(end_screen)

func _create_statistics_table(title, stats):
	var table = VBoxContainer.new()
	
	var header = Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 24)
	table.add_child(header)
	
	var grid = GridContainer.new()
	grid.columns = 2
	table.add_child(grid)
	
	for key in stats:
		var key_label = Label.new()
		key_label.text = key
		grid.add_child(key_label)
		
		var value_label = Label.new()
		value_label.text = str(stats[key])
		grid.add_child(value_label)
	
	return table

func _get_ceo_statistics():
	var stats = {}
	for player_id in players:
		if players[player_id]["role"] == Role.CEO:
			stats[players[player_id]["name"]] = {
				"Score": players[player_id]["score"],
				"Remaining Budget": players[player_id]["budget"],
				"Hires Made": _count_hires(player_id)
			}
	return stats

func _get_candidate_statistics():
	var stats = {}
	for player_id in players:
		if players[player_id]["role"] == Role.CANDIDATE:
			var offer = _get_final_offer(player_id)
			stats[players[player_id]["name"]] = {
				"Score": players[player_id]["score"],
				"True Value": players[player_id]["resume"]["value"],
				"Final Offer": offer["amount"] if offer else "N/A",
				"Hired By": players[offer["ceo_id"]]["name"] if offer else "N/A"
			}
	return stats

func _get_overall_statistics():
	var total_offers = 0
	var total_hires = 0
	var highest_offer = 0
	var lowest_offer = INF
	
	for candidate_id in offers:
		total_offers += 1
		var offer_amount = offers[candidate_id]["amount"]
		highest_offer = max(highest_offer, offer_amount)
		lowest_offer = min(lowest_offer, offer_amount)
		if _get_final_offer(candidate_id):
			total_hires += 1
	
	var average_offer = "N/A"
	if total_offers > 0:
		average_offer = _calculate_average_offer()
	
	return {
		"Total Rounds Played": current_round,
		"Total Offers Made": total_offers,
		"Total Hires": total_hires,
		"Highest Offer": highest_offer,
		"Lowest Offer": "N/A" if lowest_offer == INF else lowest_offer,
		"Average Offer": average_offer
	}

func _count_hires(ceo_id):
	var count = 0
	for candidate_id in offers:
		if offers[candidate_id]["ceo_id"] == ceo_id:
			count += 1
	return count

func _get_final_offer(candidate_id):
	return offers[candidate_id] if candidate_id in offers else null

func _calculate_average_offer():
	var total = 0
	var count = 0
	for candidate_id in offers:
		total += offers[candidate_id]["amount"]
		count += 1
	return total / count if count > 0 else 0

func _on_return_to_menu_pressed():
	play_sound("button_click")
	get_tree().reload_current_scene()

func create_server():
	peer.create_server(4242, MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer
	print("Server created")

func join_server(ip):
	peer.create_client(ip, 4242)
	multiplayer.multiplayer_peer = peer
	print("Joined server")

func _load_resumes():
	var file = FileAccess.open("res://data/resumes.json", FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error == OK:
		resumes = json.data
	else:
		print("JSON Parse Error: ", json.get_error_message(), " in ", file.get_as_text(), " at line ", json.get_error_line())
	file.close()

func _assign_resume():
	var index = randi() % resumes.size()
	return resumes[index]

func _on_make_offer_pressed():
	play_sound("button_click")
	var amount = int(game_ui.get_node("VBoxContainer/HBoxContainer/VBoxContainer2/LineEdit").text)
	var candidate_index = game_ui.get_node("VBoxContainer/HBoxContainer/VBoxContainer/ItemList").get_selected_items()[0]
	var candidate_id = players.keys()[candidate_index]
	
	if amount <= players[multiplayer.get_unique_id()]["budget"]:
		offers[candidate_id] = {"ceo_id": multiplayer.get_unique_id(), "amount": amount}
		players[multiplayer.get_unique_id()]["budget"] -= amount
		play_sound("offer_made")
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
	play_sound("button_click")
	var offer_index = game_ui.get_node("VBoxContainer/HBoxContainer/VBoxContainer2/ItemList").get_selected_items()[0]
	var ceo_id = offers.keys()[offer_index]
	
	play_sound("offer_accepted")
	rpc("_finalize_offer", multiplayer.get_unique_id(), ceo_id)
	
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

@rpc("any_peer", "reliable")
func _update_offers(new_offers):
	offers = new_offers
	_update_offer_ui()

@rpc("any_peer", "reliable")
func _finalize_offer(candidate_id, ceo_id):
	var offer = offers[candidate_id]
	players[ceo_id]["budget"] -= offer["amount"]
	_update_offer_ui()
	rpc("_update_player_list", players)

func _update_offer_ui():
	var offer_list
	if players[multiplayer.get_unique_id()]["role"] == Role.CANDIDATE:
		offer_list = game_ui.get_node("VBoxContainer/HBoxContainer/VBoxContainer2/ItemList")
	else:
		return  # CEOs don't need to update their offer UI
	
	offer_list.clear()
	for ceo_id in offers:
		if offers[ceo_id]["ceo_id"] != multiplayer.get_unique_id():
			offer_list.add_item("Offer from " + players[offers[ceo_id]["ceo_id"]]["name"] + ": $" + str(offers[ceo_id]["amount"]))

@rpc("any_peer", "reliable")
func _start_game_rpc():
	_start_game()

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
	tween.kill()  # Stop any ongoing animations
	tween = create_tween()
	tween.set_parallel(true)
	element.set(property, start_value)
	tween.tween_property(element, property, end_value, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _add_ai_player():
	var ai_id = players.size() + 1  # Assign a unique ID to the AI player
	var ai_player = {
		"id": ai_id,
		"name": "AI Player " + str(ai_id),
		"role": null,
		"score": 0,
		"budget": ceo_starting_budget,
		"is_ai": true
	}
	players[ai_id] = ai_player
	ai_players.append(ai_id)
	rpc("_update_player_list", players)

func _remove_ai_player():
	if ai_players.size() > 0:
		var ai_id = ai_players.pop_back()
		players.erase(ai_id)
		rpc("_update_player_list", players)

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
				break

func _ai_accept_offer(ai_id):
	if players[ai_id]["role"] != Role.CANDIDATE:
		return
	
	var best_offer = null
	var best_offer_amount = 0
	
	for ceo_id in offers:
		if offers[ceo_id]["ceo_id"] != ai_id and offers[ceo_id]["amount"] > best_offer_amount:
			best_offer = ceo_id
			best_offer_amount = offers[ceo_id]["amount"]
	
	if best_offer:
		rpc("_finalize_offer", ai_id, best_offer)

func _ai_turn():
	for ai_id in ai_players:
		if players[ai_id]["role"] == Role.CEO:
			_ai_make_offer(ai_id)
		elif players[ai_id]["role"] == Role.CANDIDATE:
			_ai_accept_offer(ai_id)

func _show_tutorial():
	var tutorial = Control.new()
	tutorial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE, 20)
	tutorial.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "How to Play ResumeRush"
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	var instructions = RichTextLabel.new()
	instructions.bbcode_enabled = true
	instructions.bbcode_text = """
	[b]Objective:[/b]
	CEOs aim to hire the best candidates within their budget. Candidates aim to secure the highest paying job.

	[b]Gameplay:[/b]
	1. Players are randomly assigned roles: CEO or Candidate.
	2. CEOs review candidate resumes and make offers.
	3. Candidates can accept one offer per round.
	4. The game lasts for [color=yellow]%d[/color] rounds.

	[b]Scoring:[/b]
	- CEOs: Score = Sum(Hired Candidates' True Values) - Sum(Accepted Offer Amounts)
	- Candidates: Score = Accepted Offer Amount - True Value

	[b]Tips:[/b]
	- CEOs: Balance offer amounts with candidate potential value.
	- Candidates: Consider your true value when accepting offers.
	""" % total_rounds
	instructions.fit_content = true
	vbox.add_child(instructions)
	
	var close_button = Button.new()
	close_button.text = "Close Tutorial"
	close_button.pressed.connect(func(): tutorial.queue_free())
	vbox.add_child(close_button)
	
	add_child(tutorial)
