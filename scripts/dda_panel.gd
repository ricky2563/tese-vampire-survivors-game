extends CanvasLayer

@export var sound_eruption: AudioStream
@export var sound_fake_threat: AudioStream

var complication_player: AudioStreamPlayer
var bus_horde: int
var bus_threats: int
var bus_hand: int
var bus_meteor: int
var bus_music: int
var bus_stop: int

func _ready():
	# Guarda os IDs da mesa de mistura
	bus_horde = AudioServer.get_bus_index("Horde")
	bus_threats = AudioServer.get_bus_index("Threats")
	bus_hand = AudioServer.get_bus_index("Attack_Hand")
	bus_meteor = AudioServer.get_bus_index("Attack_Meteor")
	bus_music = AudioServer.get_bus_index("Music")
	bus_stop = AudioServer.get_bus_index("Attack_Stop")
	
	# Cria o leitor de áudio para as complicações automaticamente
	complication_player = AudioStreamPlayer.new()
	complication_player.bus = "Master" # As complicações tocam sempre no canal principal
	add_child(complication_player)

# ==========================================
# 1. BOTÃO DDA (Ligar/Desligar Ajuda)
# ==========================================
func _on_check_button_toggled(toggled_on):
	# Altera a variável global do teu DDA!
	DDAManager.is_dda_active = toggled_on
	print("DDA Ativo: ", DDAManager.is_dda_active)
	
func _on_check_button_meteor_toggled(toggled_on):
	# Altera a variável global do teu DDA!
	DDAManager.is_dda_meteor_active = toggled_on
	print("DDA Ativo (Meteor): ", DDAManager.is_dda_meteor_active)

# ==========================================
# 2. SLIDERS DE VOLUME (Testes Manuais)
# ==========================================
func _on_slider_boss_value_changed(value):
	AudioServer.set_bus_volume_db(bus_threats, value)

func _on_slider_horda_value_changed(value):
	AudioServer.set_bus_volume_db(bus_horde, value)
	
func _on_slider_hand_value_changed(value):
	AudioServer.set_bus_volume_db(bus_hand, value)
	
func _on_slider_meteor_value_changed(value):
	AudioServer.set_bus_volume_db(bus_meteor, value)
	
func _on_slider_music_value_changed(value):
	AudioServer.set_bus_volume_db(bus_music, value)
	
func _on_slider_stop_value_changed(value):
	AudioServer.set_bus_volume_db(bus_stop, value)
