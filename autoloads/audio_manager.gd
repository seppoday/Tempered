extends Node

@export var max_sfx_players: int = 32
@export var music_bus_name: String = "Music"

var _players: Array[AudioStreamPlayer] = []
var _next_player_index: int = 0
var _music_player: AudioStreamPlayer


func _ready() -> void:
	for i in range(max_sfx_players):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer_%02d" % i
		add_child(player)
		_players.append(player)

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = music_bus_name
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)

# Music

func play_music(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		Log.warning("AudioManager: Nie ma podpiętego streama do playera Music")
		return
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.volume_db = volume_db
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()

func set_bus_volume_db(bus_index: int = 0, volume: float = 0.0) -> void:
	AudioServer.set_bus_volume_db(bus_index, volume)


# Generalna metoda
func play_sound(stream: AudioStream, bus_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	if stream == null:
		Log.warning("AudioManager: przekazano pusty AudioStream.")
		return null

	var player := _get_available_player()

	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.bus = bus_name

	player.play()

	return player


func play_sound_random_pitch(stream: AudioStream, bus_name: String, volume_db: float = 0.0, min_pitch: float = 0.9, max_pitch: float = 1.1) -> AudioStreamPlayer:
	return play_sound(stream, bus_name, volume_db, RNG.randf_range(min_pitch, max_pitch))


# Skróty per kategoria
func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	return play_sound(stream, "SFX", volume_db, pitch_scale)

func play_sfx_random_pitch(stream: AudioStream, volume_db: float = 0.0, min_pitch: float = 0.9, max_pitch: float = 1.1) -> AudioStreamPlayer:
	return play_sound_random_pitch(stream, "SFX", volume_db, min_pitch, max_pitch)

func play_ui(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	return play_sound(stream, "UI", volume_db, pitch_scale)

func play_ambience(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	return play_sound(stream, "Ambience", volume_db, pitch_scale)

func play_dialogue(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer:
	return play_sound(stream, "Dialogue", volume_db, pitch_scale)


func _get_available_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player

	var player := _players[_next_player_index]
	_next_player_index += 1
	if _next_player_index >= _players.size():
		_next_player_index = 0
	player.stop()
	return player
