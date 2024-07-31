extends Node2D

const MIN_PLAYERS = 4
const MAX_PLAYERS = 8
const DEFAULT_PORT = 4242
const DEFAULT_ROUND_DURATION = 300  # 5 minutes in seconds
const DEFAULT_CEO_STARTING_BUDGET = 1000000
const IP_CHECK_URL = "https://api.ipify.org"
const DESIGN_RESOLUTION = Vector2(1920, 1080)  # Our target design resolution
const HEARTBEAT_INTERVAL = 1.0  # Send heartbeat every 1 second
const HEARTBEAT_TIMEOUT = 5.0   # Consider connection lost after 5 seconds without heartbeat
const MAX_RECONNECTION_ATTEMPTS = 5
const RECONNECTION_INTERVAL = 2.0  # Seconds between reconnection attempts
const CONNECTION_CHECK_INTERVAL = 2.0  # Check connections every 2 seconds

enum Role { CEO, CANDIDATE }
enum GameState { LOBBY, PLAYING, ENDED }

var players = {}
var resumes = []
var available_avatars = []
var peer = ENetMultiplayerPeer.new()
var main_menu: Control
var game_instance: Node2D
var results_instance: Node2D
var round_duration = DEFAULT_ROUND_DURATION
var ceo_starting_budget = DEFAULT_CEO_STARTING_BUDGET
var total_rounds = 3
var external_ip = ""
var local_ip = ""
var global_lobby_code = ""
var local_lobby_code = ""
var ai_players = []
var is_host = false
var connected_peers = {}
var host_ip = ""
var lobby = preload("res://lobby.tscn").instantiate()
var is_connecting = false
var heartbeat_timer: Timer
var last_heartbeat_time = {}
var http_request = HTTPRequest.new()
var reconnection_attempts = {}
var reconnection_timer: Timer
var connection_check_timer: Timer


@onready var background_music: AudioStreamPlayer = $BackgroundMusic
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

var custom_theme: Theme

func _ready():
	_setup_viewport_scaling()
	multiplayer.peer_connected.connect(self._player_connected)
	multiplayer.peer_disconnected.connect(self._player_disconnected)
	multiplayer.connected_to_server.connect(self._connected_to_server)
	
	add_child(http_request)
	http_request.connect("request_completed", self._on_ip_request_completed)
	
	_load_theme()
	_initialize_main_menu()
	_load_resumes()
	_load_audio()
	
	get_public_ip()
	_initialize_avatars()
	
func _initialize_connection_check_system():
	print("init check system")
	connection_check_timer = Timer.new()
	connection_check_timer.wait_time = CONNECTION_CHECK_INTERVAL
	connection_check_timer.connect("timeout", Callable(self, "_check_connections"))
	add_child(connection_check_timer)
	connection_check_timer.start()
	
func _initialize_heartbeat_system():
	print("init heartbeat")
	heartbeat_timer = Timer.new()
	heartbeat_timer.wait_time = HEARTBEAT_INTERVAL
	heartbeat_timer.connect("timeout", Callable(self, "_on_heartbeat_timer_timeout"))
	add_child(heartbeat_timer)
	heartbeat_timer.start()
	
func _on_heartbeat_timer_timeout():
	if is_host:
		for peer_id in connected_peers.keys():
			rpc_id(peer_id, "_receive_heartbeat", multiplayer.get_unique_id())
	else:
		rpc_id(1, "_receive_heartbeat", multiplayer.get_unique_id())
		
@rpc("any_peer", "reliable")
func _receive_heartbeat(sender_id):
	last_heartbeat_time[sender_id] = Time.get_ticks_msec()

func get_public_ip():
	
	http_request.request(IP_CHECK_URL)
	
func _check_connection_to_peer(peer_id):
	if not multiplayer.multiplayer_peer.get_connected_peers().has(peer_id):
		print("Lost connection to peer: ", peer_id)
		_handle_peer_disconnect(peer_id)

func _check_connection_to_host():
	if not multiplayer.multiplayer_peer or not multiplayer.multiplayer_peer.get_connected_peers().has(1):
		print("Lost connection to host")
		_handle_host_disconnect()
		
func _check_connections():
	var current_time = Time.get_ticks_msec()
	if is_host:
		for peer_id in connected_peers.keys():
			if current_time - last_heartbeat_time.get(peer_id, 0) > HEARTBEAT_TIMEOUT * 1000:
				_handle_peer_disconnect(peer_id)
	else:
		if current_time - last_heartbeat_time.get(1, 0) > HEARTBEAT_TIMEOUT * 1000:
			_handle_host_disconnect()

func _handle_peer_disconnect(peer_id):
	print("Lost connection to peer: ", peer_id)
	get_public_ip()
	_attempt_reconnection(peer_id)

func _handle_host_disconnect():
	print("Lost connection to host")
	get_public_ip()
	_attempt_reconnection(1)  # Assuming host always has ID 1

@rpc("any_peer")
func update_client_ip(client_id, new_ip):
	if is_host:
		print("Updating IP for client: ", client_id, " to ", new_ip)
		connected_peers[client_id] = new_ip
		multiplayer.multiplayer_peer.set_peer_address(client_id, new_ip, DEFAULT_PORT)

@rpc("any_peer")
func update_host_ip(new_ip):
	if not is_host:
		print("Updating host IP to: ", new_ip)
		host_ip = new_ip
		join_lobby(compress_ip(new_ip))

func _on_ip_request_completed(result, response_code, headers, body):
	if result == HTTPRequest.RESULT_SUCCESS:
		var new_ip = body.get_string_from_utf8()
		global_lobby_code = compress_ip(external_ip)
		if new_ip != external_ip:
			external_ip = new_ip
			if is_host:
				host_ip = external_ip
				global_lobby_code = compress_ip(external_ip)
				_notify_peers_of_ip_change()
			else:
				rpc_id(1, "update_client_ip", multiplayer.get_unique_id(), external_ip)
		print("Public IP: ", external_ip)
		_update_lobby_ip()
	else:
		print("Failed to get public IP")

func _notify_peers_of_ip_change():
	for peer_id in connected_peers:
		rpc_id(peer_id, "update_host_ip", external_ip)

func _player_connected(id):
	print("Player connected: ", id)
	players[id] = {"role": null, "score": 0, "budget": ceo_starting_budget, "name": "Player " + str(id)}
	connected_peers[id] = ""  # Will be updated when we receive the client's IP
	_update_player_list(players)
	if is_host:
		show_notification("Player " + str(id) + " joined the lobby")
	last_heartbeat_time[id] = Time.get_ticks_msec()
	

func _initialize_avatars():
	available_avatars = range(1, 9)  # Creates a list [1, 2, 3, 4, 5, 6, 7, 8]
	
func _setup_viewport_scaling():
	var window_size = DisplayServer.window_get_size()
	var scale = min(window_size.x / float(DESIGN_RESOLUTION.x), window_size.y / float(DESIGN_RESOLUTION.y))
	var scaled_size = (DESIGN_RESOLUTION * scale).round()
	var margins = ((Vector2(window_size) - scaled_size) / 2).round()
	
	get_tree().root.content_scale_factor = scale
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	
	# Set the viewport size to match our scaled size
	get_viewport().size = Vector2i(scaled_size)
	
	# Center the viewport in the window
	var window = get_tree().root
	window.position = DisplayServer.window_get_position() + Vector2i(margins)
	
	# Set minimum window size
	DisplayServer.window_set_min_size(Vector2i(scaled_size))

func add_player(id, is_ai = false):
	if id not in players:
		var avatar_index = _get_unique_avatar()
		players[id] = {
			"role": null, 
			"score": 0, 
			"budget": ceo_starting_budget, 
			"name": "AI Player " + str(id) if is_ai else "Player " + str(id),
			"is_ai": is_ai,
			"avatar": avatar_index
		}
		print("Player added: ", players[id])
		_update_player_list(players)
	else:
		print("Player already exists: ", players[id])

func _get_unique_avatar():
	if available_avatars.is_empty():
		# If all avatars are used, reset the list
		_initialize_avatars()
	var index = randi() % available_avatars.size()
	var avatar = available_avatars[index]
	available_avatars.remove_at(index)
	return avatar

func remove_player(id):
	if id in players:
		# Return the avatar to the available list
		available_avatars.append(players[id]["avatar"])
		players.erase(id)
		print("Player removed: ", id)
		_update_player_list(players)
	else:
		print("Player not found: ", id)

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
			print(upnp.get_gateway())
			print("UPnP gateway failed")
	else:
		print("UPnP discovery failed")
		
	get_public_ip()
	
	var error = peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	if error != OK:
		print("Failed to create server. Error code: ", error)
		return
	multiplayer.multiplayer_peer = peer
	print("Server created successfully on port ", DEFAULT_PORT)
	
	var host_id = multiplayer.get_unique_id()
	add_player(host_id)
	
	_show_lobby()

func join_lobby(code):
	is_host = false
	is_connecting = true
	
	host_ip = decompress_ip(code)
	print("Attempting to connect to ", host_ip, ":", DEFAULT_PORT)
	var error = peer.create_client(host_ip, DEFAULT_PORT)
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
	get_public_ip()  # Get our own public IP
	rpc_id(1, "request_host_ip")  # Request the host's IP
	#_show_lobby()

func _connection_failed():
	print("Failed to connect to the server")
	if is_connecting:
		is_connecting = false
		_show_error_dialog("Failed to connect to the server. Please check the IP and try again.")
		multiplayer.multiplayer_peer = null

@rpc("any_peer")
func request_host_ip():
	var requester_id = multiplayer.get_remote_sender_id()
	rpc_id(requester_id, "receive_host_ip", external_ip)

@rpc("any_peer")
func receive_host_ip(ip):
	if not is_host:
		host_ip = ip
		global_lobby_code = compress_ip(ip)
		_update_lobby_ip()

func _show_lobby():
	_initialize_connection_check_system()
	_initialize_heartbeat_system()
	main_menu.hide()
	lobby.connect("start_game", Callable(self, "_on_lobby_start_game"))
	lobby.connect("add_ai_player", Callable(self, "_add_ai_player"))
	lobby.connect("remove_ai_player", Callable(self, "_remove_ai_player"))
	add_child(lobby)
	_update_lobby_ip()
	lobby.update_player_list(players)
	
func _get_local_ip():
	for address in IP.get_local_addresses():
		if "." in address and not address.begins_with("127.") and not address.begins_with("169.254."):
			if address.begins_with("192.168.") or address.begins_with("10.") or (address.begins_with("172.") and int(address.split(".")[1]) >= 16 and int(address.split(".")[1]) <= 31):
				local_ip = address
				local_lobby_code = compress_ip(local_ip)
				break
	if local_ip == '':
		print("No local IP found")

func _update_lobby_ip():
	_get_local_ip()
	if has_node("Lobby"):
		get_node("Lobby").update_lobby_codes(global_lobby_code, local_lobby_code)

func show_notification(message):
	if has_node("Lobby"):
		get_node("Lobby").show_notification(message)

@rpc("any_peer")
func _update_host_ip(new_ip):
	if not is_host:
		print("Updating host IP to: ", new_ip)
		host_ip = new_ip
		# Only update the lobby code if we're not the host
		global_lobby_code = compress_ip(new_ip)
		_update_lobby_ip()

func _player_disconnected(id):
	print("Player disconnected: ", id)
	players.erase(id)
	connected_peers.erase(id)
	_update_player_list(players)
	last_heartbeat_time.erase(id)

@rpc("any_peer", "call_local")
func _start_game_rpc():
	print("_start_game_rpc called")
	_start_game()

func _load_theme():
	custom_theme = load("res://themes/theme.tres")
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
	
func _create_background():
	var background = TextureRect.new()
	background.texture = load("res://assets/backgrounds/office_background.png")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.custom_minimum_size = Vector2(1920, 1080)
	add_child(background)

func _initialize_main_menu():
	_create_background()
	main_menu = Control.new()
	main_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main_menu)
	
	# Background
	var background = TextureRect.new()
	background.texture = load("res://assets/backgrounds/office_background.png")
	background.expand = true
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_menu.add_child(background)
	
	# Dark overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_menu.add_child(overlay)
	
	# Logo
	var logo = TextureRect.new()
	logo.texture = load("res://assets/ui/resume_rush_logo.png")
	logo.expand = true
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	logo.offset_left = 660
	logo.offset_top = 50
	logo.offset_right = 1260
	logo.offset_bottom = 250
	main_menu.add_child(logo)
	
	# Main Button Container
	var button_container = Panel.new()
	button_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	button_container.offset_left = 740
	button_container.offset_top = 20
	button_container.offset_right = 1180
	button_container.offset_bottom = 1000
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(1, 1, 1, 0.2)
	style_box.corner_radius_top_left = 20
	style_box.corner_radius_top_right = 20
	style_box.corner_radius_bottom_left = 20
	style_box.corner_radius_bottom_right = 20
	button_container.add_theme_stylebox_override("panel", style_box)
	main_menu.add_child(button_container)
	
	# Main Buttons
	var buttons = [
		{"text": "Host Game", "icon": "nameplate.png", "action": "_on_host_pressed"},
		{"text": "Join Game", "icon": "id_card.png", "action": "_on_join_pressed"},
		{"text": "Quick Play", "icon": "quick_play.png", "action": "_on_quick_play_pressed"},
		{"text": "Settings", "icon": "gear.png", "action": "_on_settings_pressed"}
	]
	
	for i in range(buttons.size()):
		var button_data = buttons[i]
		var button = HitboxGenerator.create_texture_button_with_hitbox("res://assets/ui/" + button_data["icon"])
		button.stretch_mode = TextureButton.STRETCH_SCALE
		if (i == buttons.size() - 1):
			button.custom_minimum_size = Vector2(100, 100)
			button.offset_left = 130
			button.offset_top = 400 + (i * 130)
			button.offset_right = 290
			button.offset_bottom = 500 + (i * 130)
		else:
			button.custom_minimum_size = Vector2(400, 100)
			button.offset_left = 20
			button.offset_top = 400 + (i * 130)
			button.offset_right = 400
			button.offset_bottom = 100 + (i * 130)
		button.connect("pressed", Callable(self, button_data["action"]))
		button.connect("mouse_entered", Callable(self, "_on_button_hover").bind(button))
		button.connect("mouse_exited", Callable(self, "_on_button_unhover").bind(button))
		
		
		button_container.add_child(button)
	
	# Decorative Elements
	var decorative_elements = [
		{"texture": "res://assets/icons/ceo.png", "position": Vector2(50, 880), "size": Vector2(150, 150)},
		{"texture": "res://assets/icons/candidate.png", "position": Vector2(1720, 880), "size": Vector2(150, 150)},
		{"texture": "res://assets/ui/money_stack.png", "position": Vector2(100, 100), "size": Vector2(120, 120), "rotation": 15},
		{"texture": "res://assets/ui/clipboard.png", "position": Vector2(1700, 100), "size": Vector2(120, 120), "rotation": -15}
	]
	
	for element in decorative_elements:
		var texture_rect = TextureRect.new()
		texture_rect.texture = load(element["texture"])
		texture_rect.expand = true
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		texture_rect.offset_left = element["position"].x
		texture_rect.offset_top = element["position"].y
		texture_rect.custom_minimum_size = element["size"]
		if "rotation" in element:
			texture_rect.rotation_degrees = element["rotation"]
		main_menu.add_child(texture_rect)
		
		if "res://assets/icons/" in element["texture"]:
			_add_bobbing_animation(texture_rect)
		elif "res://assets/ui/" in element["texture"]:
			_add_rotation_animation(texture_rect)
	
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
	main_menu.add_child(particles)
	
	# Footer
	var footer = ColorRect.new()
	footer.color = Color(0, 0, 0, 0.5)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -50
	main_menu.add_child(footer)
	
	var footer_text = Label.new()
	footer_text.text = "© 2024 ResumeRush | Version 1.0"
	footer_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	footer_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(footer_text)

func _on_button_hover(button):
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(button, "modulate", Color(1.2, 1.2, 1.2), 0.1)

func _on_button_unhover(button):
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1, 1), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(button, "modulate", Color(1, 1, 1), 0.1)

func _add_bobbing_animation(node):
	var animation_player = AnimationPlayer.new()
	node.add_child(animation_player)
	
	var animation_library = AnimationLibrary.new()
	var animation = Animation.new()
	var track_index = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, ":position:y")
	animation.track_insert_key(track_index, 0.0, node.position.y)
	animation.track_insert_key(track_index, 1.0, node.position.y - 20)
	animation.track_insert_key(track_index, 2.0, node.position.y)
	
	animation.loop_mode = Animation.LOOP_PINGPONG
	
	animation_library.add_animation("bobbing", animation)
	animation_player.add_animation_library("", animation_library)
	animation_player.play("bobbing")

func _add_rotation_animation(node):
	var animation_player = AnimationPlayer.new()
	node.add_child(animation_player)
	
	var animation_library = AnimationLibrary.new()
	var animation = Animation.new()
	var track_index = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, ":rotation_degrees")
	animation.track_insert_key(track_index, 0.0, node.rotation_degrees)
	animation.track_insert_key(track_index, 1.0, node.rotation_degrees + 5)
	animation.track_insert_key(track_index, 2.0, node.rotation_degrees)
	
	animation.loop_mode = Animation.LOOP_PINGPONG
	
	animation_library.add_animation("rotating", animation)
	animation_player.add_animation_library("", animation_library)
	animation_player.play("rotating")

func _animate_button(button: TextureButton):
	button.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(button, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.play()

func _on_host_pressed():
	play_sound("button_click")
	create_server()
	_show_lobby()

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
	lobby.update_player_list(new_players)

func _start_game():
	print("Starting game...")
	if players.size() < MIN_PLAYERS:
		print("Cannot start game. Players:", players.size())
		return
	
	_assign_roles()
	_initialize_game()
	
func _start_results():
	_initialize_results()

func _assign_roles():
	var player_ids = players.keys()
	player_ids.shuffle()
	for i in range(player_ids.size()):
		var role = Role.CEO if i < player_ids.size() / 2 else Role.CANDIDATE
		players[player_ids[i]]["role"] = role
		if role == Role.CANDIDATE:
			players[player_ids[i]]["resume"] = _assign_resume()
	_update_player_list(players)

func _initialize_game():
	if has_node("Lobby"):
		get_node("Lobby").queue_free()
	
	game_instance = preload("res://game.tscn").instantiate()
	game_instance.initialize(players, round_duration, ceo_starting_budget, total_rounds, resumes, ai_players)
	game_instance.connect("game_ended", Callable(self, "_on_game_ended"))
	add_child(game_instance)
	
func _initialize_results():
	if has_node("Results"):
		get_node("Results").queue_free()
	
	results_instance = preload("res://results.tscn").instantiate()
	results_instance.initialize(players)
	add_child(results_instance)

func _on_game_ended():
	game_instance.queue_free()
	_show_results_screen()

func _show_results_screen():
	var results_scene = preload("res://results.tscn").instantiate()
	results_scene.initialize(players, _get_game_statistics())
	add_child(results_scene)

func _get_game_statistics():
	var ceos = []
	var candidates = []
	var scores = []
	var hires = []
	var final_offers = []
	
	for p in players.values():
		if p["role"] == Role.CEO:
			ceos.append(p)
			hires.append(p.get("hires", 0))
		elif p["role"] == Role.CANDIDATE:
			candidates.append(p)
			final_offers.append(p.get("final_offer", 0))
		scores.append(p["score"])
	
	var stats = {
		"Total Rounds": total_rounds,
		"Total Players": players.size(),
		"CEOs": len(ceos),
		"Candidates": len(candidates),
		"Highest Score": max(scores),
		"Lowest Score": min(scores),
		"Average Score": float(sum(scores)) / players.size() if players.size() > 0 else 0,
		"Total Hires": sum(hires),
		"Average Salary": float(sum(final_offers)) / len(candidates) if len(candidates) > 0 else 0
	}
	return stats

func sum(array):
	var total = 0
	for item in array:
		total += item
	return total

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

func _on_lobby_start_game():
	print("Received start game signal from lobby")
	rpc("_start_game_rpc")
	
func _on_game_start_results():
	print("Received start results signal from game")
	rpc("_start_results_rpc")

func _add_ai_player():
	var ai_id = players.size() + 1  # Assign a unique ID to the AI player
	add_player(ai_id, true)
	ai_players.append(ai_id)

func _remove_ai_player():
	if ai_players:
		var ai_id = ai_players.pop_back()
		remove_player(ai_id)

func compress_ip(ip: String) -> String:
	var parts = ip.split(".")
	if parts.size() != 4:
		print(ip)
		push_error("Invalid IP address format")
		return ""
	
	var num = (parts[0].to_int() << 24) | (parts[1].to_int() << 16) | (parts[2].to_int() << 8) | parts[3].to_int()
	return base_36_encode(num)

func decompress_ip(compressed: String) -> String:
	var num = base_36_decode(compressed)
	return "%d.%d.%d.%d" % [
		(num >> 24) & 255,
		(num >> 16) & 255,
		(num >> 8) & 255,
		num & 255
	]

func base_36_encode(number: int) -> String:
	if number == 0:
		return '0'
	var base36 = ''
	while number != 0:
		var quotient = number / 36
		var remainder = number % 36
		base36 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"[remainder] + base36
		number = quotient
	return base36

func base_36_decode(number: String) -> int:
	var result = 0
	for digit in number:
		result = result * 36 + "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".find(digit)
	return result
	
func _attempt_reconnection(peer_id):
	print("Attempting to reconnect to peer: ", peer_id)
	
	if peer_id not in reconnection_attempts:
		reconnection_attempts[peer_id] = 0
	
	if reconnection_attempts[peer_id] >= MAX_RECONNECTION_ATTEMPTS:
		print("Max reconnection attempts reached for peer ", peer_id)
		_handle_reconnection_failed(peer_id)
		return
	
	reconnection_attempts[peer_id] += 1
	
	if is_host:
		_host_reconnect_to_peer(peer_id)
	else:
		_client_reconnect_to_host()
	
	# Start or restart the reconnection timer
	if not reconnection_timer:
		reconnection_timer = Timer.new()
		reconnection_timer.one_shot = true
		reconnection_timer.connect("timeout", Callable(self, "_on_reconnection_timeout").bind(peer_id))
		add_child(reconnection_timer)
	
	reconnection_timer.start(RECONNECTION_INTERVAL)

func _host_reconnect_to_peer(peer_id):
	var peer_ip = connected_peers.get(peer_id, "")
	if peer_ip:
		print("Host attempting to reconnect to peer ", peer_id, " at IP ", peer_ip)
		multiplayer.multiplayer_peer.create_peer(peer_id, peer_ip, DEFAULT_PORT)
	else:
		print("No IP address found for peer ", peer_id)
		_handle_reconnection_failed(peer_id)

func _client_reconnect_to_host():
	print("Client attempting to reconnect to host at IP ", host_ip)
	var error = peer.create_client(host_ip, DEFAULT_PORT)
	if error != OK:
		print("Failed to create client for reconnection. Error code: ", error)
		_handle_reconnection_failed(1)  # 1 is the assumed host ID

func _on_reconnection_timeout(peer_id):
	if peer_id in connected_peers:
		print("Reconnection successful for peer ", peer_id)
		_handle_reconnection_success(peer_id)
	else:
		print("Reconnection attempt failed for peer ", peer_id)
		_attempt_reconnection(peer_id)  # Try again

func _handle_reconnection_success(peer_id):
	reconnection_attempts.erase(peer_id)
	if reconnection_timer:
		reconnection_timer.stop()
	
	# Synchronize game state
	_synchronize_game_state(peer_id)

func _handle_reconnection_failed(peer_id):
	reconnection_attempts.erase(peer_id)
	if reconnection_timer:
		reconnection_timer.stop()
	
	if is_host:
		# Remove the peer from the game
		players.erase(peer_id)
		connected_peers.erase(peer_id)
		_update_player_list(players)
		print("Peer ", peer_id, " has been removed from the game due to failed reconnection")
	else:
		# Client failed to reconnect to host
		print("Failed to reconnect to host. Returning to main menu.")
		_return_to_main_menu()

func _synchronize_game_state(peer_id):
	if is_host and game_instance:
		# Get current game state from game_instance
		var game_state = game_instance.get_game_state()
		# Send current game state to the reconnected peer
		rpc_id(peer_id, "_receive_game_state", game_state)
	else:
		# Client requests game state from host
		rpc_id(1, "_request_game_state")

@rpc("any_peer", "reliable")
func _receive_game_state(game_state):
	if game_instance:
		game_instance.set_game_state(game_state)

@rpc("any_peer", "reliable")
func _request_game_state():
	var requester_id = multiplayer.get_remote_sender_id()
	_synchronize_game_state(requester_id)
	
func _return_to_main_menu():
	# Reset necessary variables
	is_host = false
	is_connecting = false
	host_ip = ""
	multiplayer.multiplayer_peer = null
	
	# Remove any game-specific nodes
	if has_node("Lobby"):
		get_node("Lobby").queue_free()
	if game_instance:
		game_instance.queue_free()
	
	# Show the main menu
	if main_menu:
		main_menu.show()
	else:
		# If main_menu doesn't exist, you might need to recreate it or change scene
		get_tree().change_scene_to_file("res://main.tscn")
	
func _update_game_display():
	print("updating ui not implemented, unsure if necessary")

func _exit_tree():
	if heartbeat_timer:
		heartbeat_timer.stop()
		heartbeat_timer.queue_free()
	if connection_check_timer:
		connection_check_timer.stop()
		connection_check_timer.queue_free()
