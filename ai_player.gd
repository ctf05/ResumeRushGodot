extends Node

const Role = preload("res://main.gd").Role

var role: int
var player_id: int
var budget: int
var resume: Dictionary
var game_scene: Node
var personality: Dictionary
var ai_action_interval: float = 2.0  # Seconds between AI actions
var ai_action_timer: float = 0.0

func _init(p_role: int, p_player_id: int, p_budget: int, p_resume: Dictionary, p_game_scene: Node):
	role = p_role
	player_id = p_player_id
	budget = p_budget
	resume = p_resume
	game_scene = p_game_scene
	_generate_personality()

func _generate_personality():
	personality = {
		"risk_tolerance": randf(),
		"generosity": randf(),
		"patience": randf(),
		"chattiness": lerp(.6, .8, randf())  # New personality trait for determining chat frequency
	}

func make_decision(delta):
	ai_action_timer += delta
	if ai_action_timer >= ai_action_interval:
		ai_action_timer = 0.0
		
		# Decide between chatting and making an offer
		if randf() < personality["chattiness"]:
			_send_chat_message()
		else:
			if role == Role.CEO:
				_make_offer()
			else:
				_respond_to_offer()

func _send_chat_message():
	var recipients = game_scene.players.keys()
	recipients.erase(player_id)  # Remove self from recipients
	
	if recipients.is_empty():
		return  # No one to chat with
	
	var recipient_id = recipients[randi() % recipients.size()]
	var message = _generate_chat_message()
	
	var sender_name = game_scene.players[player_id]["name"]
	
	# Call the game scene's method to send the chat message
	print("AI " + sender_name + " sending message to " + str(recipient_id) + ": " + message)
	game_scene.receive_ai_chat_message(sender_name, message, recipient_id)

func _generate_chat_message() -> String:
	var messages = [
		"How's everyone doing?",
		"This round is intense!",
		"Any good offers yet?",
		"I'm feeling lucky today!",
		"May the best negotiator win!",
		"Remember, it's just a game... or is it?",
		"I wonder what the next round will bring.",
		"Is anyone else feeling the pressure?",
		"Good luck to all!",
		"I'm really enjoying this game!"
	]
	return messages[randi() % messages.size()]
	
func _make_offer():
	var available_candidates = game_scene.get_available_candidates()
	if available_candidates.is_empty():
		return

	var candidate = available_candidates[randi() % available_candidates.size()]
	var candidate_id = game_scene.players.keys()[game_scene.players.values().find(candidate)]
	
	var max_offer = min(budget, int(candidate["resume"]["value"] * (1.0 + personality["risk_tolerance"])))
	var min_offer = int(candidate["resume"]["value"] * (1.0 - personality["risk_tolerance"]))
	var offer_amount = int(lerp(min_offer, max_offer, personality["generosity"]))

	if offer_amount > 0 and offer_amount <= budget:
		game_scene.make_offer(player_id, candidate_id, offer_amount)

func _respond_to_offer():
	var offers = game_scene.get_offers_for_candidate(player_id)
	if offers.is_empty():
		return

	var offer = offers[0]  # Assume there's only one offer for simplicity
	var offer_value = offer["amount"]
	var resume_value = resume["value"]

	var acceptance_threshold = resume_value * (1.0 - personality["risk_tolerance"])
	if offer_value >= acceptance_threshold:
		game_scene.rpc("_update_accepted_offers", {player_id: offer})
	else:
		# Decline the offer
		game_scene.offers.erase(player_id)
		game_scene.rpc("_update_offers", game_scene.offers)

func get_ai_name():
	return "AI Player " + str(player_id)
