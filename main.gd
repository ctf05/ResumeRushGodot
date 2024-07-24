extends Node2D

const MIN_PLAYERS = 4
const MAX_PLAYERS = 8
const DEFAULT_PORT = 4242
const DEFAULT_ROUND_DURATION = 300  # 5 minutes in seconds
const DEFAULT_CEO_STARTING_BUDGET = 1000000
const STUN_SERVER = "stun.l.google.com"
const STUN_PORT = 19302
const IP_CHECK_INTERVAL = 60  # Check IP every 60 seconds
const IP_CHECK_URL = "https://api.ipify.org"

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
var external_ip = ""
var local_ip = ""
var global_lobby_code = ""
var local_lobby_code = ""
var ai_players = []
var is_host = false
var connected_peers = []
var host_ip = ""
var is_connecting = false
var ip_check_timer = Timer.new()
var http_request = HTTPRequest.new()

@onready var background_music: AudioStreamPlayer = $BackgroundMusic
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

var custom_theme: Theme

func _ready():
	multiplayer.peer_connected.connect(self._player_connected)
	multiplayer.peer_disconnected.connect(self._player_disconnected)
	multiplayer.connected_to_server.connect(self._connected_to_server)
	multiplayer.connection_failed.connect(self._connection_failed)
	
	ip_check_timer.connect("timeout", self._check_ip)
	add_child(ip_check_timer)
	
	add_child(http_request)
	http_request.connect("request_completed", self._on_ip_request_completed)
	
	_load_theme()
	_initialize_main_menu()
	_load_resumes()
	_load_audio()
	
	get_public_ip()
	get_local_ip()

func create_server():
	is_host = true
	var upnp = UPNP.new()
	var discover_result = upnp.discover()
	if discover_result == UPNP.UPNP_RESULT_SUCCESS:
		if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
			var map_result = upnp.add_port_mapping(DEFAULT_PORT, DEFAULT_PORT, ProjectSettings.get_setting("application/config/name"), "UDP")
			if map_result == UPNP.UPNP_RESULT_SUCCESS:
				print("Port forwarded successfully using UPnP")
			else:
				print("UPnP port mapping failed")
	else:
		print("UPnP discovery failed")
	
	var error = peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	if error != OK:
		print("Failed to create server. Error code: ", error)
		return
	multiplayer.multiplayer_peer = peer
	print("Server created successfully on port ", DEFAULT_PORT)
	_show_lobby()

func join_lobby(code):
	is_host = false
	is_connecting = true
	var ip = decompress_ip(code)
	print("Attempting to connect to ", ip, ":", DEFAULT_PORT)
	var error = peer.create_client(ip, DEFAULT_PORT)
	if error != OK:
		print("Failed to create client. Error code: ", error)
		_connection_failed()
		return
	multiplayer.multiplayer_peer = peer
	print("Client peer created, waiting for connection...")
	
	# Set a timeout for the connection attempt
	var timeout = 10  # 10 seconds timeout
	while is_connecting and timeout > 0:
		await get_tree().create_timer(1.0).timeout
		print("Waiting for connection... ", timeout, " seconds left")
		timeout -= 1
	
	if is_connecting:
		_connection_failed()

func _connected_to_server():
	print("Successfully connected to server")
	is_connecting = false
	_show_lobby()

func _connection_failed():
	if is_connecting:
		print("Failed to connect to the server")
		is_connecting = false
		_show_error_dialog("Failed to connect to the server. Please check the IP and try again.")
		multiplayer.multiplayer_peer = null

@rpc("any_peer")
func request_host_ip():
	var requester_id = multiplayer.get_remote_sender_id()
	rpc_id(requester_id, "receive_host_ip", external_ip)

@rpc("any_peer")
func receive_host_ip(ip):
	host_ip = ip
	_update_lobby_ip()

func _show_lobby():
	main_menu.hide()
	var lobby = preload("res://lobby.tscn").instantiate()
	lobby.connect("start_game", Callable(self, "_on_lobby_start_game"))
	lobby.connect("add_ai_player", Callable(self, "_add_ai_player"))
	lobby.connect("remove_ai_player", Callable(self, "_remove_ai_player"))
	add_child(lobby)
	_update_lobby_ip()

func _update_lobby_ip():
	if has_node("Lobby"):
		get_node("Lobby").update_lobby_codes(global_lobby_code, local_lobby_code)

func _check_ip():
	if is_host:
		get_public_ip()

func get_public_ip():
	http_request.request(IP_CHECK_URL)

func get_local_ip():
	local_ip = IP.get_local_addresses()[0]  # Get the first local IP address
	local_lobby_code = compress_ip(local_ip)
	_update_lobby_ip()

func _on_ip_request_completed(result, response_code, headers, body):
	if result == HTTPRequest.RESULT_SUCCESS:
		var new_ip = body.get_string_from_utf8()
		if new_ip != external_ip:
			external_ip = new_ip
			host_ip = external_ip
			global_lobby_code = compress_ip(external_ip)
			if is_host:
				_notify_peers_of_ip_change()
		print("Public IP: ", external_ip)
		_update_lobby_ip()
	else:
		print("Failed to get public IP")

func _notify_peers_of_ip_change():
	for peer_id in players.keys():
		if peer_id != multiplayer.get_unique_id():
			rpc_id(peer_id, "receive_host_ip", host_ip)

func _player_connected(id):
	print("Player connected: ", id)
	players[id] = {"role": null, "score": 0, "budget": ceo_starting_budget, "name": "Player " + str(id)}
	rpc("_update_player_list", players)
	if is_host:
		rpc("show_notification", "Player " + str(id) + " joined the lobby")

@rpc("any_peer")
func show_notification(message):
	if has_node("Lobby"):
		get_node("Lobby").show_notification(message)

@rpc("any_peer", "reliable")
func _update_host_ip(new_ip):
	external_ip = new_ip
	print("Host IP updated to: ", external_ip)
	_update_lobby_ip()

func _player_disconnected(id):
	print("Player disconnected: ", id)
	players.erase(id)
	connected_peers.erase(id)
	rpc("_update_player_list", players)

@rpc("any_peer", "call_local")
func _start_game_rpc():
	print("_start_game_rpc called")
	_start_game()

func _load_theme():
	custom_theme = load("res://themes/cartoon_office_theme.tres")
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
	SoundManager.play_sound(sound_name)

func _initialize_main_menu():
	main_menu = Control.new()
	main_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var background = AnimatedTexture.new()
	background.frames = 30  # Adjust based on your GIF
	for i in range(30):
		background.set_frame_texture(i, load("res://assets/backgrounds/office_anim_%02d.png" % i))
	
	var background_texture = TextureRect.new()
	background_texture.texture = background
	background_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_menu.add_child(background_texture)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_menu.add_child(vbox)
	
	var title = Label.new()
	title.text = "ResumeRush"
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)
	
	var buttons = [
		{"text": "Host Game", "icon": "nameplate.png", "action": "_on_host_pressed"},
		{"text": "Join Game", "icon": "id_card.png", "action": "_on_join_pressed"},
		{"text": "Quick Play", "icon": "quick_play.png", "action": "_on_quick_play_pressed"},
		{"text": "Settings", "icon": "gear.png", "action": "_on_settings_pressed"}
	]

	for button_data in buttons:
		var button = HitboxGenerator.create_texture_button_with_hitbox("res://assets/ui/" + button_data["icon"])
		button.connect("pressed", Callable(self, button_data["action"]))
		_animate_button(button)
		vbox.add_child(button)
	
	add_child(main_menu)

func _animate_button(button: TextureButton):
	button.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(button, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.play()

func _on_host_pressed():
	play_sound("button_click")
	create_server()
	_show_lobby()
	_show_host_ip()

func _show_host_ip():
	var dialog = AcceptDialog.new()
	dialog.title = "Your IP Address"
	dialog.dialog_text = "Your IP address (give this to other players): " + external_ip
	add_child(dialog)
	dialog.popup_centered()

func _on_join_pressed():
	play_sound("button_click")
	_show_join_dialog()

func _on_settings_pressed():
	play_sound("button_click")
	_show_options_menu()

func _on_quick_play_pressed():
	# Implement quick play functionality
	pass

func _show_join_dialog():
	var dialog = AcceptDialog.new()
	dialog.title = "Join Game"
	
	var ip_input = LineEdit.new()
	ip_input.placeholder_text = "Enter Host IP"
	dialog.add_child(ip_input)
	
	dialog.add_button("Join", true, "join")
	dialog.connect("custom_action", func(action):
		if action == "join":
			join_lobby(ip_input.text)
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

func _initialize_game():
	if has_node("Lobby"):
		get_node("Lobby").queue_free()
	
	game_instance = preload("res://game.tscn").instantiate()
	game_instance.initialize(players, round_duration, ceo_starting_budget, total_rounds, custom_theme, resumes, ai_players)
	game_instance.connect("game_ended", Callable(self, "_on_game_ended"))
	add_child(game_instance)

func _on_game_ended():
	game_instance.queue_free()
	_show_results_screen()

func _show_results_screen():
	var results_scene = preload("res://results.tscn").instantiate()
	results_scene.initialize(players, _get_game_statistics())
	add_child(results_scene)

func _get_game_statistics():
	var stats = {
		"Total Rounds": total_rounds,
		"Total Players": players.size(),
		"CEOs": len([p for p in players.values() if p["role"] == Role.CEO]),
		"Candidates": len([p for p in players.values() if p["role"] == Role.CANDIDATE]),
		"Highest Score": max([p["score"] for p in players.values()]),
		"Lowest Score": min([p["score"] for p in players.values()]),
		"Average Score": float(sum([p["score"] for p in players.values()])) / players.size() if players.size() > 0 else 0,
		"Total Hires": sum([p.get("hires", 0) for p in players.values() if p["role"] == Role.CEO]),
		"Average Salary": float(sum([p.get("final_offer", 0) for p in players.values() if p["role"] == Role.CANDIDATE])) / len([p for p in players.values() if p["role"] == Role.CANDIDATE]) if len([p for p in players.values() if p["role"] == Role.CANDIDATE]) > 0 else 0
	}
	return stats

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
	var tutorial = preload("res://tutorial_overlay.tscn").instantiate()
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

func add_player(id, is_ai = false):
	if id not in players:
		players[id] = {
			"role": null, 
			"score": 0, 
			"budget": ceo_starting_budget, 
			"name": "AI Player " + str(id) if is_ai else "Player " + str(id),
			"is_ai": is_ai
		}
		print("Player added: ", players[id])
	else:
		print("Player already exists: ", players[id])
	rpc("_update_player_list", players)

func remove_player(id):
	if id in players:
		players.erase(id)
		print("Player removed: ", id)
		rpc("_update_player_list", players)
	else:
		print("Player not found: ", id)

func _on_lobby_start_game():
	print("Received start game signal from lobby")
	rpc("_start_game_rpc")

func _add_ai_player():
	var ai_id = players.size() + 1  # Assign a unique ID to the AI player
	add_player(ai_id, true)
	ai_players.append(ai_id)

func _remove_ai_player():
	if ai_players:
		var ai_id = ai_players.pop_back()
		remove_player(ai_id)

func compress_ip(ip):
	var parts = ip.split('.')
	var num = (int(parts[0]) << 24) | (int(parts[1]) << 16) | (int(parts[2]) << 8) | int(parts[3])
	return base_36_encode(num)

func decompress_ip(compressed):
	var num = base_36_decode(compressed)
	return "%d.%d.%d.%d" % [(num >> 24) & 255, (num >> 16) & 255, (num >> 8) & 255, num & 255]

func base_36_encode(number):
	if number == 0:
		return '0'
	var base36 = ''
	while number != 0:
		var quotient = number / 36
		var remainder = number % 36
		base36 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"[remainder] + base36
		number = quotient
	return base36

func base_36_decode(number):
	var result = 0
	for digit in number:
		result = result * 36 + "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".find(digit)
	return result
