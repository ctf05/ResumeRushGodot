extends Node2D

const MIN_PLAYERS = 4
const MAX_PLAYERS = 8
const DEFAULT_ROUND_DURATION = 300  # 5 minutes in seconds
const DEFAULT_CEO_STARTING_BUDGET = 1000000

enum Role { CEO, CANDIDATE }
enum GameState { LOBBY, PLAYING, ENDED }

var players = {}
var resumes = []

var peer = ENetMultiplayerPeer.new()

var main_menu: Control
var game_instance: Node2D

var round_duration = DEFAULT_ROUND_DURATION
var ceo_starting_budget = DEFAULT_CEO_STARTING_BUDGET
var total_rounds = 3
var ai_players = []

@onready var background_music: AudioStreamPlayer = $BackgroundMusic
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

var custom_theme: Theme

var sound_effects = {
	"button_click": preload("res://assets/audio/button_click.wav"),
	"offer_made": preload("res://assets/audio/offer_made.wav"),
	"offer_accepted": preload("res://assets/audio/offer_accepted.wav"),
	"round_start": preload("res://assets/audio/round_start.wav"),
	"round_end": preload("res://assets/audio/round_end.wav"),
	"game_over": preload("res://assets/audio/game_over.wav")
}

func _ready():
	multiplayer.peer_connected.connect(self._player_connected)
	multiplayer.peer_disconnected.connect(self._player_disconnected)
	
	_load_theme()
	_initialize_main_menu()
	_load_resumes()
	_load_audio()

@rpc("any_peer", "call_local")
func _start_game_rpc():
	print("_start_game_rpc called")
	_start_game()

func _load_theme():
	custom_theme = load("res://theme.tres")
	if custom_theme:
		get_tree().root.theme = custom_theme

func _load_audio():
	var music = load("res://assets/audio/background_music.ogg")
	if music:
		background_music.stream = music
		background_music.play()
	else:
		print("Failed to load background music")

func play_sound(sound_name):
	if sound_name in sound_effects:
		sfx_player.stream = sound_effects[sound_name]
		sfx_player.play()
	else:
		print("Sound not found: ", sound_name)

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
	if has_node("OptionsMenu"):
		get_node("OptionsMenu").queue_free()
	
	var options_menu = Control.new()
	options_menu.name = "OptionsMenu"
	options_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(options_menu)
	
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
	back_button.pressed.connect(func():
		options_menu.queue_free()
		if main_menu:
			main_menu.show()
	)
	vbox.add_child(back_button)
	
	if main_menu:
		main_menu.hide()

func _player_connected(id):
	print("Player connected: ", id)
	players[id] = {"role": null, "score": 0, "budget": ceo_starting_budget, "name": "Player " + str(id)}
	rpc("_update_player_list", players)

func _player_disconnected(id):
	print("Player disconnected: ", id)
	players.erase(id)
	rpc("_update_player_list", players)

@rpc("any_peer", "reliable")
func _update_player_list(new_players):
	players = new_players
	if has_node("Lobby"):
		get_node("Lobby").update_player_list(players)

func _start_game():
	print("Starting game...")
	if players.size() < MIN_PLAYERS:
		print("Cannot start game. Players:", players.size())
		return
	
	_assign_roles()
	_initialize_game()

func _assign_roles():
	var player_ids = players.keys()
	player_ids.shuffle()
	for i in range(player_ids.size()):
		var role = Role.CEO if i < player_ids.size() / 2 else Role.CANDIDATE
		players[player_ids[i]]["role"] = role
		if role == Role.CANDIDATE:
			players[player_ids[i]]["resume"] = _assign_resume()
	rpc("_update_player_list", players)

func _on_game_ended():
	game_instance.queue_free()
	_show_end_game_screen()

func _show_end_game_screen():
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
				"Hires Made": players[player_id].get("hires", 0)
			}
	return stats

func _get_candidate_statistics():
	var stats = {}
	for player_id in players:
		if players[player_id]["role"] == Role.CANDIDATE:
			stats[players[player_id]["name"]] = {
				"Score": players[player_id]["score"],
				"True Value": players[player_id]["resume"]["value"],
				"Final Offer": players[player_id].get("final_offer", "N/A"),
				"Hired By": players[player_id].get("hired_by", "N/A")
			}
	return stats

func _get_overall_statistics():
	var total_offers = 0
	var total_hires = 0
	var highest_offer = 0
	var lowest_offer = INF
	
	for player_id in players:
		if players[player_id]["role"] == Role.CANDIDATE:
			if players[player_id].get("final_offer", 0) > 0:
				total_offers += 1
				total_hires += 1
				highest_offer = max(highest_offer, players[player_id]["final_offer"])
				lowest_offer = min(lowest_offer, players[player_id]["final_offer"])
	
	var average_offer = "N/A"
	if total_offers > 0:
		var total = 0
		for player_id in players:
			if players[player_id]["role"] == Role.CANDIDATE and players[player_id].get("final_offer", 0) > 0:
				total += players[player_id]["final_offer"]
		average_offer = total / total_offers
	
	return {
		"Total Rounds Played": total_rounds,
		"Total Offers Made": total_offers,
		"Total Hires": total_hires,
		"Highest Offer": highest_offer if highest_offer > 0 else "N/A",
		"Lowest Offer": lowest_offer if lowest_offer != INF else "N/A",
		"Average Offer": average_offer
	}

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

func _show_error_dialog(message):
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "Error"
	add_child(dialog)
	dialog.popup_centered()

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

func get_players():
	return players

func get_min_players():
	return MIN_PLAYERS

func get_custom_theme():
	return custom_theme

func get_game_settings():
	return {
		"round_duration": round_duration,
		"ceo_starting_budget": ceo_starting_budget,
		"total_rounds": total_rounds
	}

func add_player(id):
	if id not in players:
		players[id] = {"role": null, "score": 0, "budget": ceo_starting_budget, "name": "Player " + str(id)}
		print("Player added: ", players[id])
	else:
		print("Player already exists: ", players[id])

func _on_lobby_start_game():
	print("Received start game signal from lobby")
	rpc("_start_game_rpc")
	
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
	if has_node("Lobby"):
		get_node("Lobby").update_player_list(players)

func _remove_ai_player():
	if ai_players.size() > 0:
		var ai_id = ai_players.pop_back()
		players.erase(ai_id)
		rpc("_update_player_list", players)
		if has_node("Lobby"):
			get_node("Lobby").update_player_list(players)

# Update the _initialize_game function to pass AI players to the game instance
func _initialize_game():
	if has_node("Lobby"):
		get_node("Lobby").queue_free()
	
	game_instance = preload("res://game.tscn").instantiate()
	game_instance.initialize(players, round_duration, ceo_starting_budget, total_rounds, custom_theme, resumes, ai_players)
	game_instance.connect("game_ended", Callable(self, "_on_game_ended"))
	add_child(game_instance)

# Update the _show_lobby function to connect AI player management
func _show_lobby():
	main_menu.hide()
	var lobby = preload("res://lobby.tscn").instantiate()
	lobby.connect("start_game", Callable(self, "_on_lobby_start_game"))
	lobby.connect("add_ai_player", Callable(self, "_add_ai_player"))
	lobby.connect("remove_ai_player", Callable(self, "_remove_ai_player"))
	add_child(lobby)
