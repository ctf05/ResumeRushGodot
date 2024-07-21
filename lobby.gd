extends Node2D

var player_list_node
var start_button
var add_ai_button
var remove_ai_button
var game_settings_label
var not_enough_players_dialog
var lobby_code_label: Label
signal start_game
signal add_ai_player
signal remove_ai_player

func _ready():
	print("Lobby _ready() called")
	_create_ui()
	
	print("Parent node: ", get_parent().name if get_parent() else "No parent")
	
	if get_parent() and get_parent().has_method("get_players"):
		var players = get_parent().get_players()
		print("Players: ", players)
		if players.is_empty():
			print("Player list is empty")
			# You might want to add the local player here
			if get_parent().has_method("add_player"):
				get_parent().add_player(multiplayer.get_unique_id())
				players = get_parent().get_players()
				print("Updated players: ", players)
		update_player_list(players)
	else:
		print("Parent node doesn't have get_players method")

	# Apply custom theme
	if get_parent() and get_parent().has_method("get_custom_theme"):
		var custom_theme = get_parent().get_custom_theme()
		if custom_theme:
			_apply_theme_recursively(self, custom_theme)
			print("Custom theme applied")
		else:
			print("Custom theme not found")
	else:
		print("Parent node doesn't have get_custom_theme method")

	# Update game settings display
	if get_parent() and get_parent().has_method("get_game_settings"):
		var settings = get_parent().get_game_settings()
		game_settings_label.text = "Round Duration: %d seconds\nCEO Starting Budget: $%d\nTotal Rounds: %d" % [
			settings.round_duration,
			settings.ceo_starting_budget,
			settings.total_rounds
		]
		print("Game settings updated")
	else:
		print("get_game_settings method not found")

func _create_ui():
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)
	
	lobby_code_label = Label.new()
	lobby_code_label.text = "Lobby Code: " + get_parent().lobby_code
	vbox.add_child(lobby_code_label)

	game_settings_label = Label.new()
	game_settings_label.text = "Game Settings"
	vbox.add_child(game_settings_label)

	player_list_node = ItemList.new()
	vbox.add_child(player_list_node)

	start_button = Button.new()
	start_button.text = "Start Game"
	start_button.pressed.connect(self._on_start_pressed)
	vbox.add_child(start_button)

	add_ai_button = Button.new()
	add_ai_button.text = "Add AI Player"
	add_ai_button.pressed.connect(self._on_add_ai_pressed)
	vbox.add_child(add_ai_button)

	remove_ai_button = Button.new()
	remove_ai_button.text = "Remove AI Player"
	remove_ai_button.pressed.connect(self._on_remove_ai_pressed)
	vbox.add_child(remove_ai_button)

	not_enough_players_dialog = AcceptDialog.new()
	not_enough_players_dialog.dialog_text = "Need at least 4 players to start the game."
	add_child(not_enough_players_dialog)

	print("UI created")

func _apply_theme_recursively(node: Node, theme: Theme):
	if node is Control:
		node.theme = theme
	for child in node.get_children():
		_apply_theme_recursively(child, theme)

func update_player_list(players):
	print("Updating player list")
	if player_list_node:
		player_list_node.clear()
		for id in players:
			var player_name = players[id]["name"]
			if "is_ai" in players[id] and players[id]["is_ai"]:
				player_name += " (AI)"
			player_list_node.add_item(player_name)
		print("Player list updated with %d players" % players.size())
	else:
		print("Cannot update player list: PlayerList node not found")

	# Only show the Start button for the host (first player to join)
	if start_button:
		if players.size() > 0 and multiplayer.get_unique_id() == players.keys()[0]:
			start_button.show()
			print("Start button shown")
		else:
			start_button.hide()
			print("Start button hidden")
	else:
		print("StartButton not found for visibility update")

func _on_start_pressed():
	print("Start button pressed")
	if get_parent() and get_parent().has_method("get_players") and get_parent().has_method("get_min_players"):
		var players = get_parent().get_players()
		var min_players = get_parent().get_min_players()
		print("Current players: %d, Minimum required: %d" % [players.size(), min_players])
		if players.size() >= min_players:
			print("Emitting start_game signal")
			emit_signal("start_game")
		else:
			print("Not enough players, showing dialog")
			not_enough_players_dialog.popup_centered()
	else:
		print("Parent node missing required methods")

func _on_add_ai_pressed():
	print("Add AI button pressed")
	emit_signal("add_ai_player")

func _on_remove_ai_pressed():
	print("Remove AI button pressed")
	emit_signal("remove_ai_player")
