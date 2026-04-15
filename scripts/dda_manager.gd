extends Node

var is_dda_active = false 
var is_dda_meteor_active = false

var bus_music: int
var bus_horde: int
var bus_threats: int

var bus_attack_hand: int
var bus_attack_meteor: int
var bus_attack_ring: int
var bus_attack_stop: int

func _ready():
	bus_music = AudioServer.get_bus_index("Music")
	bus_horde = AudioServer.get_bus_index("Horde")
	bus_threats = AudioServer.get_bus_index("Threats")
	
	bus_attack_hand = AudioServer.get_bus_index("Attack_Hand")
	bus_attack_meteor = AudioServer.get_bus_index("Attack_Meteor")
	bus_attack_ring = AudioServer.get_bus_index("Attack_Ring")
	bus_attack_stop = AudioServer.get_bus_index("Attack_Stop")

func trigger_threat_focus(duration: float):
	if not is_dda_active:
		return 

	AudioServer.set_bus_effect_enabled(bus_horde, 0, true)
	AudioServer.set_bus_effect_enabled(bus_music, 0, true)
	
	AudioServer.set_bus_volume_db(bus_horde, -12.0)
	AudioServer.set_bus_volume_db(bus_music, -8.0)

	AudioServer.set_bus_volume_db(bus_threats, 6.0)

	await get_tree().create_timer(duration, false).timeout

	reset_mix()
	
func trigger_threat_meteor_focus(duration: float):
	if not is_dda_meteor_active:
		return 

	#AudioServer.set_bus_effect_enabled(bus_horde, 0, true)
	#AudioServer.set_bus_effect_enabled(bus_music, 0, true)
	
	AudioServer.set_bus_volume_db(bus_horde, -2.0)
	AudioServer.set_bus_volume_db(bus_music, -2.0)

	AudioServer.set_bus_volume_db(bus_attack_meteor, 10.0)

	await get_tree().create_timer(duration, false).timeout

	reset_mix()

func reset_mix():
	AudioServer.set_bus_effect_enabled(bus_horde, 0, false)
	AudioServer.set_bus_effect_enabled(bus_music, 0, false)
	
	AudioServer.set_bus_volume_db(bus_horde, 0.0)
	AudioServer.set_bus_volume_db(bus_music, 0.0)
	AudioServer.set_bus_volume_db(bus_threats, 0.0)
