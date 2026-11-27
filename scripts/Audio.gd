extends Node
## Background music + sound effects (WAV files in assets/audio).

var music := AudioStreamPlayer.new()
var players := {}


func _ready() -> void:
	add_child(music)
	var m = load("res://assets/audio/music.wav")
	if m is AudioStreamWAV:
		m.loop_mode = AudioStreamWAV.LOOP_FORWARD
		m.loop_begin = 0
		m.loop_end = m.data.size() / 2
	music.stream = m
	music.volume_db = -9.0
	for n in ["coin", "click", "level", "error"]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/audio/%s.wav" % n)
		p.volume_db = -4.0
		add_child(p)
		players[n] = p


func play(n: String) -> void:
	if GS.sfx_on and players.has(n):
		players[n].play()


func apply_settings() -> void:
	if GS.music_on:
		if music.stream and not music.playing:
			music.play()
	else:
		music.stop()
