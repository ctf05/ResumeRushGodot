extends Node

var sounds = {
	"button_click": preload("res://assets/audio/button_click.wav"),
	"offer_sent": preload("res://assets/audio/offer_sent.wav"),
	"offer_received": preload("res://assets/audio/offer_received.wav"),
	"offer_accepted": preload("res://assets/audio/offer_accepted.wav"),
	"hired": preload("res://assets/audio/hired.wav"),
	"round_start": preload("res://assets/audio/round_start.wav"),
	"round_end": preload("res://assets/audio/round_end.wav"),
	"game_over": preload("res://assets/audio/game_over.wav"),
	"emoji_reaction": preload("res://assets/audio/emoji_reaction.wav")
}

var audio_players = []

func _ready():
	for i in range(5):  # Create a pool of audio players
		var player = AudioStreamPlayer.new()
		add_child(player)
		audio_players.append(player)

func play_sound(sound_name: String):
	if sound_name in sounds:
		var available_player = _get_available_player()
		if available_player:
			available_player.stream = sounds[sound_name]
			available_player.play()

func _get_available_player() -> AudioStreamPlayer:
	for player in audio_players:
		if not player.playing:
			return player
	return null  # All players are busy
