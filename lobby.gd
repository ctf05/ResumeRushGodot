extends Control

var player_list_node

func _ready():
	player_list_node = $VBoxContainer/PlayerList
	$VBoxContainer/StartButton.pressed.connect(self._on_start_pressed)
	$VBoxContainer/AddAIButton.pressed.connect(self._on_add_ai_pressed)
	$VBoxContainer/RemoveAIButton.pressed.connect(self._on_remove_ai_pressed)
	update_player_list(get_parent().players)
	
	# Apply custom theme
	var custom_theme = get_parent().custom_theme
	if custom_theme:
		theme = custom_theme
	
	# Update game settings display
	$VBoxContainer/GameSettings.text = "Round Duration: %d seconds\nCEO Starting Budget: $%d\nTotal Rounds: %d" % [
		get_parent().round_duration,
		get_parent().ceo_starting_budget,
		get_parent().total_rounds
	]

func update_player_list(players):
	player_list_node.clear()
	for id in players:
		var player_name = players[id]["name"]
		if "is_ai" in players[id] and players[id]["is_ai"]:
			player_name += " (AI)"
		player_list_node.add_item(player_name)
	
	# Only show the Start button for the host (first player to join)
	var start_button = $VBoxContainer/StartButton
	if multiplayer.get_unique_id() == players.keys()[0]:
		start_button.show()
	else:
		start_button.hide()

func _on_start_pressed():
	if get_parent().players.size() >= get_parent().MIN_PLAYERS:
		get_parent().rpc("_start_game_rpc")
	else:
		$NotEnoughPlayersDialog.popup_centered()

func _on_add_ai_pressed():
	get_parent()._add_ai_player()

func _on_remove_ai_pressed():
	get_parent()._remove_ai_player()

func _on_not_enough_players_dialog_confirmed():
	$NotEnoughPlayersDialog.hide()
