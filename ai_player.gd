extends Node
class_name AIPlayer

var role: int  # Role.CEO or Role.CANDIDATE
var player_id: int
var budget: float
var score: int
var resume: Dictionary
var game_instance: Node  # Reference to the main game instance

# AI personality traits (0.0 to 1.0)
var risk_tolerance: float
var generosity: float
var patience: float

func _init(p_role: int, p_player_id: int, p_budget: float, p_resume: Dictionary, p_game_instance: Node):
	role = p_role
	player_id = p_player_id
	budget = p_budget
	resume = p_resume
	game_instance = p_game_instance
	score = 0
	
	# Randomize AI personality
	risk_tolerance = randf()
	generosity = randf()
	patience = randf()

func make_decision():
	print(str(player_id) + " AI making decision")
	if role == game_instance.Role.CEO:
		make_ceo_decision()
	else:
		make_candidate_decision()

func make_ceo_decision():
	var candidates = game_instance.get_available_candidates()
	if candidates.is_empty():
		return
	
	var chosen_candidate = candidates[randi() % candidates.size()]
	var offer_amount = calculate_offer_amount(chosen_candidate)
	
	if offer_amount > 0 and offer_amount <= budget:
		game_instance.make_offer(player_id, chosen_candidate, offer_amount)
		budget -= offer_amount

func make_candidate_decision():
	var offers = game_instance.get_offers_for_candidate(player_id)
	if offers.is_empty():
		return
	
	var best_offer = evaluate_best_offer(offers)
	if best_offer:
		game_instance.accept_offer(player_id, best_offer["ceo_id"], best_offer["amount"])

func calculate_offer_amount(candidate):
	var perceived_value = candidate["resume"]["value"] * (1 + (randf() - 0.5) * 0.2)  # +/- 10% perception error
	var max_offer = perceived_value * (1 + risk_tolerance)
	var min_offer = perceived_value * (1 - risk_tolerance)
	
	var offer = lerp(min_offer, max_offer, generosity)
	return min(offer, budget)

func evaluate_best_offer(offers):
	var best_offer = null
	var best_value = 0
	
	for offer in offers:
		var offer_value = calculate_offer_value(offer)
		if offer_value > best_value:
			best_value = offer_value
			best_offer = offer
	
	return best_offer if best_value > resume["value"] * (1 - risk_tolerance) else null

func calculate_offer_value(offer):
	var time_factor = 1 - (game_instance.get_remaining_time() / game_instance.round_duration)
	var urgency = lerp(1, 1.2, 1 - patience)  # Increase perceived value as time runs out
	return offer["amount"] * urgency * (1 + time_factor)

func update_score(new_score):
	score = new_score

func get_ai_name():
	return "AI Player " + str(player_id)
