extends Node2D

const MIN_PLAYERS = 4
const MAX_PLAYERS = 8
const DEFAULT_ROUND_DURATION = 300  # 5 minutes in seconds
const DEFAULT_CEO_STARTING_BUDGET = 1000000
const DESIGN_RESOLUTION = Vector2(1920, 1080)  # Our target design resolution

enum Role { CEO, CANDIDATE }
enum GameState { LOBBY, PLAYING, ENDED }

var players = {}
var resumes = []
var available_avatars = []
var peer = WebRTCMultiplayerPeer.new()
var webrtc_peer = WebRTCPeerConnection.new()
var main_menu: Control
var game_instance: Node2D
var results_instance: Node2D
var room_id = ""
var round_duration = DEFAULT_ROUND_DURATION
var ceo_starting_budget = DEFAULT_CEO_STARTING_BUDGET
var total_rounds = 3
var current_request_id = 0
var ai_players = []
var is_connecting = false
var is_host = false
var is_polling = false
var polling_timer: Timer
var connected_peers = {}
var lobby = preload("res://lobby.tscn").instantiate()
var http_request = HTTPRequest.new()
var player_id = 0

@onready var background_music: AudioStreamPlayer = $BackgroundMusic
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

var custom_theme: Theme

const FIREBASE_URL = "https://us-central1-resumerushgodot.cloudfunctions.net/webRTCSignaling"

func _ready():
	_setup_viewport_scaling()
	multiplayer.peer_connected.connect(self._player_connected)
	multiplayer.peer_disconnected.connect(self._player_disconnected)
	multiplayer.connected_to_server.connect(self._connected_to_server)
	
	add_child(http_request)
	
	_load_theme()
	_initialize_main_menu()
	_load_resumes()
	_load_audio()
	_initialize_avatars()
	
	webrtc_peer.initialize({
		"iceServers": [{ "urls": ["stun:stun.l.google.com:19302"] }]
	})
	webrtc_peer.connect("session_description_created", self._on_session_description_created)
	webrtc_peer.connect("ice_candidate_created", self._on_ice_candidate_created)
	webrtc_peer.connect("connection_state_changed", self._on_connection_state_changed)
	http_request.request_completed.connect(self._on_request_completed)
	print("Game initialized")

func _on_connection_state_changed(state):
	match state:
		WebRTCPeerConnection.STATE_NEW:
			print("WebRTC: New connection")
		WebRTCPeerConnection.STATE_CONNECTING:
			print("WebRTC: Connecting...")
		WebRTCPeerConnection.STATE_CONNECTED:
			print("WebRTC: Connected")
		WebRTCPeerConnection.STATE_DISCONNECTED:
			print("WebRTC: Disconnected")
			_handle_disconnection()
		WebRTCPeerConnection.STATE_FAILED:
			print("WebRTC: Connection failed")
			_handle_connection_failure()
		WebRTCPeerConnection.STATE_CLOSED:
			print("WebRTC: Connection closed")
	
func create_server():
	is_host = true
	room_id = _generate_room_id()
	player_id = 1 # Host always uses player ID 1
	var body = {
		"action": "create_room",
		"roomId": room_id,
		"playerId": player_id
	}
	_send_request(body)
	_update_lobby_code()

func join_lobby(code):
	is_host = false
	room_id = code
	player_id = randi() % 10000000 + 1  # Generate a random player ID between 1 and 10,000,000
	_join_room()

func _create_room():
	var body = JSON.stringify({
		"action": "create_room",
		"roomId": room_id,
		"playerId": player_id
	})
	_send_request(body)
	_update_lobby_code()

func _join_room():
	var body = JSON.stringify({
		"action": "join_room",
		"roomId": room_id,
		"playerId": player_id
	})
	_send_request(body)
	_update_lobby_code()

func _connected_to_server():
	print("Successfully connected to WebRTC signaling server")
	is_connecting = false
	# We don't need to get public IP or request host IP in WebRTC
	# The connection details will be handled through the signaling process
	_show_lobby()

func _connection_failed():
	print("Failed to connect to WebRTC signaling server")
	is_connecting = false
	_show_error_dialog("Failed to connect to the signaling server. Please check your internet connection and try again.")
	# Reset the peer
	if webrtc_peer:
		webrtc_peer.close()
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = null

func _handle_disconnection():
	print("WebRTC: Disconnected. Attempting to reconnect...")
	# WebRTC will attempt to reconnect automatically
	# We can start a timer here to check if reconnection is successful after a certain time
	get_tree().create_timer(10.0).timeout.connect(_check_reconnection_status)

func _handle_connection_failure():
	print("WebRTC: Connection failed")
	_show_error_dialog("Connection failed. Returning to main menu.")
	_return_to_main_menu()

func _check_reconnection_status():
	if webrtc_peer.get_connection_state() != WebRTCPeerConnection.STATE_CONNECTED:
		print("Reconnection failed after timeout. Returning to main menu.")
		_return_to_main_menu()
	else:
		print("Successfully reconnected")

# Add this new function to handle closed connections
func _handle_connection_closed():
	print("WebRTC: Connection closed")
	_show_error_dialog("Connection closed. Returning to main menu.")
	_return_to_main_menu()

func _send_request(body, custom_action = ""):
	var headers = ["Content-Type: application/json"]
	var full_url = FIREBASE_URL
	if custom_action:
		full_url += "?action=" + custom_action
	
	print("Sending request to URL: ", full_url)
	print("Request headers: ", headers)
	
	# Ensure body is a dictionary
	var body_dict = body if typeof(body) == TYPE_DICTIONARY else JSON.parse_string(body)
	if body_dict == null:
		print("Error: Invalid body format")
		return
	
	# Convert dictionary to JSON string
	var json_string = JSON.stringify(body_dict)
	print("Request body (JSON string): ", json_string)
	
	var error = http_request.request(full_url, headers, HTTPClient.METHOD_POST, json_string)
	if error != OK:
		print("An error occurred in the HTTP request: ", error)
	return error

func _on_request_completed(result, response_code, headers, body):
	print("Received response: ", result, " ", response_code)
	print("Response body: ", body.get_string_from_utf8())
	
	var response = JSON.parse_string(body.get_string_from_utf8())
	if response == null:
		print("Failed to parse response")
		return
	
	if response.has("success"):
		if response.success:
			if response.has("roomId"):  # Room creation or join response
				print("Room operation successful with ID: ", response.get("roomId", "unknown"))
				room_id = response.get("roomId", room_id)
				if is_host:
					_initialize_webrtc_host()
				else:
					_initialize_webrtc_client()
				_show_lobby()
				_update_lobby_code()
			elif response.has("notifications"):  # Polling response
				_handle_notifications(response.notifications)
			else:
				# Handle other successful responses (offer, answer, ice_candidate)
				_handle_webrtc_signaling(response)
		else:
			print("Error in response: ", response.get("message", "Unknown error"))
			_handle_error(response.get("message", "Unknown error"))
	else:
		print("Unexpected response format: ", response)

func _handle_error(error_message):
	_show_error_dialog("An error occurred: " + error_message)
	print("Handling error: ", error_message)
	if error_message == "Room not found":
		_return_to_main_menu()
		
func _handle_webrtc_signaling(response):
	match response.get("action"):
		"offer":
			if not is_host:
				webrtc_peer.set_remote_description("offer", response.data.sdp)
				webrtc_peer.create_answer()
		"answer":
			if is_host:
				webrtc_peer.set_remote_description("answer", response.data.sdp)
		"ice_candidate":
			webrtc_peer.add_ice_candidate(response.data.media, response.data.index, response.data.name)

func _initialize_webrtc_host():
	peer.create_mesh(MAX_PLAYERS)
	multiplayer.multiplayer_peer = peer

func _initialize_webrtc_client():
	peer.create_client(room_id)
	multiplayer.multiplayer_peer = peer
	webrtc_peer.create_offer()

func _on_session_description_created(type, sdp):
	webrtc_peer.set_local_description(type, sdp)
	if is_host:
		_send_offer(sdp)
	else:
		_send_answer(sdp)

func _on_ice_candidate_created(media, index, name):
	_send_ice_candidate(media, index, name)

func _send_offer(sdp):
	var body = JSON.stringify({
		"action": "offer",
		"roomId": room_id,
		"playerId": multiplayer.get_unique_id(),
		"data": {
			"type": "offer",
			"sdp": sdp
		}
	})
	_send_request(body)

func _send_answer(sdp):
	var body = JSON.stringify({
		"action": "answer",
		"roomId": room_id,
		"playerId": multiplayer.get_unique_id(),
		"data": {
			"type": "answer",
			"sdp": sdp,
			"from": multiplayer.get_unique_id()
		}
	})
	_send_request(body)

func _send_ice_candidate(media, index, name):
	var body = JSON.stringify({
		"action": "ice_candidate",
		"roomId": room_id,
		"playerId": multiplayer.get_unique_id(),
		"data": {
			"media": media,
			"index": index,
			"name": name
		}
	})
	_send_request(body)

func _start_notification_polling():
	print("Starting notification polling")
	if polling_timer:
		polling_timer.queue_free()
	
	polling_timer = Timer.new()
	polling_timer.wait_time = 5.0  # Poll every 5 seconds, adjust as needed
	polling_timer.one_shot = false
	polling_timer.connect("timeout", self._poll_notifications)
	add_child(polling_timer)
	
	is_polling = true
	polling_timer.start()

func _poll_notifications():
	if not is_polling:
		return
	
	print("Polling for notifications")
	var query_params = "?action=poll_notifications&roomId=" + room_id + "&playerId=" + str(player_id)
	var full_url = FIREBASE_URL + query_params
	
	print("Sending request to URL: ", full_url)
	var headers = ["Content-Type: application/json"]
	var error = http_request.request(full_url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		print("An error occurred in the HTTP request: ", error)
	
# Add a function to stop polling
func _stop_notification_polling():
	print("Stopping notification polling")
	is_polling = false
	if polling_timer:
		polling_timer.stop()
		polling_timer.queue_free()
		polling_timer = null

func _handle_notifications(notifications):
	print("Handling notifications: ", notifications)
	for notification in notifications:
		match notification.type:
			"new_player":
				_handle_new_player(notification)
			"player_left":
				_handle_player_left(notification)
			"offer":
				_handle_offer(notification)
			"answer":
				_handle_answer(notification)
			"ice_candidate":
				_handle_ice_candidate(notification)
			_:
				print("Unknown notification type: ", notification.type)

func _handle_new_player(notification):
	var new_player_id = notification.playerId
	if new_player_id not in players:
		players[new_player_id] = {
			"role": null,
			"score": 0,
			"budget": ceo_starting_budget,
			"name": "Player " + str(new_player_id),
			"avatar": _get_unique_avatar()
		}
		print("New player added: ", players[new_player_id])
		_update_player_list(players)
		show_notification("Player " + str(new_player_id) + " joined the game")

func _handle_player_left(notification):
	var left_player_id = notification.playerId
	if left_player_id in players:
		print("Player left: ", players[left_player_id])
		remove_player(left_player_id)
		show_notification("Player " + str(left_player_id) + " left the game")

func _handle_offer(notification):
	if not is_host and notification.from != multiplayer.get_unique_id():
		print("Received offer from: ", notification.from)
		webrtc_peer.set_remote_description("offer", notification.offer.sdp)
		var answer = webrtc_peer.create_answer()
		webrtc_peer.set_local_description("answer", answer)
		_send_answer(answer)

func _handle_answer(notification):
	if is_host and notification.from != multiplayer.get_unique_id():
		print("Received answer from: ", notification.from)
		webrtc_peer.set_remote_description("answer", notification.answer.sdp)

func _handle_ice_candidate(notification):
	if notification.from != multiplayer.get_unique_id():
		print("Received ICE candidate from: ", notification.from)
		webrtc_peer.add_ice_candidate(
			notification.candidate.media,
			notification.candidate.index,
			notification.candidate.name
		)

func _player_connected(id):
	print("Player connected: ", id)
	players[id] = {"role": null, "score": 0, "budget": ceo_starting_budget, "name": "Player " + str(id)}
	connected_peers[id] = ""
	_update_player_list(players)
	if is_host:
		show_notification("Player " + str(id) + " joined the lobby")

func _player_disconnected(id):
	print("Player disconnected: ", id)
	players.erase(id)
	connected_peers.erase(id)
	_update_player_list(players)
	_send_leave_room(id)

func _send_leave_room(player_id):
	var body = JSON.stringify({
		"action": "leave_room",
		"roomId": room_id,
		"playerId": player_id
	})
	_send_request(body)

func _client_reconnect_to_host():
	print("Client attempting to reconnect to host")
	_initialize_webrtc_client()
	_join_room()  # This will trigger the signaling process again

func _generate_room_id():
	return str(randi() % 1000000).pad_zeros(6)
	

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

func _show_lobby():
	main_menu.hide()
	lobby.connect("start_game", Callable(self, "_on_lobby_start_game"))
	lobby.connect("add_ai_player", Callable(self, "_add_ai_player"))
	lobby.connect("remove_ai_player", Callable(self, "_remove_ai_player"))
	add_child(lobby)
	lobby.update_player_list(players)
	_update_lobby_code()
	_start_notification_polling()

func show_notification(message):
	if has_node("Lobby"):
		get_node("Lobby").show_notification(message)

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
	_stop_notification_polling()
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
		
func _update_lobby_code():
	if has_node("Lobby"):
		get_node("Lobby").update_lobby_codes(room_id)
	
func _return_to_main_menu():
	_stop_notification_polling()
	# Reset necessary variables
	is_host = false
	is_connecting = false
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
		
func _exit_tree():
	_stop_notification_polling()
	if http_request:
		http_request.cancel_request()
