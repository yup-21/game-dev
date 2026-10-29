extends Node
## Original synthesized ambience and short cues. Zero external audio assets/licensing.
const SAMPLE_RATE: float=22050.0
var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var effects: Array=[]
var sample_index: int=0
var rain_enabled: bool=false

func _ready() -> void:
	var generator=AudioStreamGenerator.new()
	generator.mix_rate=SAMPLE_RATE
	generator.buffer_length=0.14
	player=AudioStreamPlayer.new()
	player.stream=generator
	player.volume_db=-20.0
	add_child(player)
	player.play()
	playback=player.get_stream_playback() as AudioStreamGeneratorPlayback

func cue(kind: String) -> void:
	var frequency: float=380.0
	var duration: float=0.10
	var strength: float=0.17
	match kind:
		"attack", "ATTACK_DECLARED":
			frequency=680.0; duration=0.18; strength=0.29
		"damage", "DAMAGE":
			frequency=140.0; duration=0.23; strength=0.29
		"guard", "SHIELD", "INTERCEPT_JUDGED":
			frequency=940.0; duration=0.12; strength=0.14
		"dialogue":
			frequency=520.0; duration=0.035; strength=0.045
		"menu":
			frequency=430.0; duration=0.11; strength=0.11
		"COMBO_TRIGGERED":
			frequency=870.0; duration=0.31; strength=0.25
		_:
			return
	effects.append({"frequency":frequency,"duration":maxi(1,roundi(duration*SAMPLE_RATE)),"left":maxi(1,roundi(duration*SAMPLE_RATE)),"phase":0.0,"strength":strength})
	if effects.size()>12: effects.pop_front()

func _process(_delta: float) -> void:
	if playback==null: return
	var available: int=mini(900,playback.get_frames_available())
	for i in range(available):
		var value: float=0.0
		if rain_enabled:
			# Gentle deterministic noise; never use the combat RNG.
			var n: float=sin(float(sample_index)*1.894)+sin(float(sample_index)*0.573)+sin(float(sample_index)*2.321)
			value+=n*0.012
		for effect in effects:
			if int(effect.left)<=0: continue
			var envelope: float=float(effect.left)/float(effect.duration)
			var pitch: float=float(effect.frequency)*(0.78+0.24*envelope)
			value+=sin(float(effect.phase))*envelope*float(effect.strength)
			effect.phase=float(effect.phase)+TAU*pitch/SAMPLE_RATE
			effect.left=int(effect.left)-1
		value=clampf(value,-0.8,0.8)
		playback.push_frame(Vector2(value,value))
		sample_index+=1
	for index in range(effects.size()-1,-1,-1):
		if int(effects[index].left)<=0: effects.remove_at(index)
