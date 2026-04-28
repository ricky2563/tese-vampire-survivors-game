extends Node

var is_dda_active = true 

var bus_music: int
var bus_horde: int
var bus_threats: int

var bus_attack_hand: int
var bus_attack_meteor: int
var bus_attack_ring: int
var bus_attack_stop: int

const FILTER_LOWPASS = 0   # Desafio (Abafa)
const FILTER_HIGHSHELF = 1 # Ajuda (Realça)

# ==========================================
# O DICIONÁRIO AGORA TEM AFINAÇÃO INDIVIDUAL ("challenge_volume")
# ==========================================
var attack_history = {
	"Boss: Meteor Attack": {"hits": 0, "dodges": 0, "bus_name": "Attack_Meteor", "challenge_volume": 2.0},
	"Boss: Ring Attack":   {"hits": 0, "dodges": 0, "bus_name": "Attack_Ring",   "challenge_volume": -2.0},
	"Boss: Stop Attack":   {"hits": 0, "dodges": 0, "bus_name": "Attack_Stop",   "challenge_volume": 0.0}, 
	"Boss: Hand Attack":   {"hits": 0, "dodges": 0, "bus_name": "Attack_Hand",   "challenge_volume": 1.0}
}

var current_active_attack = ""

var time_since_last_damage = 0.0
var horde_pressure_level = 0.0
var is_ducking = false

# Tweens
var cluster_tween: Tween 
var attack_vol_tween: Tween 

# Telemetria
var dda_log = []
var play_time = 0.0
var log_timer = 0.0 

func _ready():
	bus_music = AudioServer.get_bus_index("Music")
	bus_horde = AudioServer.get_bus_index("Horde")
	bus_threats = AudioServer.get_bus_index("Threats")
	
	bus_attack_hand = AudioServer.get_bus_index("Attack_Hand")
	bus_attack_meteor = AudioServer.get_bus_index("Attack_Meteor")
	bus_attack_ring = AudioServer.get_bus_index("Attack_Ring")
	bus_attack_stop = AudioServer.get_bus_index("Attack_Stop")

func _process(delta):
	if not is_dda_active: return
	
	play_time += delta 
	time_since_last_damage += delta
	
	if time_since_last_damage > 20.0 and not is_ducking:
		horde_pressure_level = min(horde_pressure_level + (delta * 0.2), 5.0)
		if not cluster_tween or not cluster_tween.is_running():
			AudioServer.set_bus_volume_db(bus_horde, horde_pressure_level)
		
	log_timer += delta
	if log_timer >= 0.5:
		dda_log.append({
			"time": play_time, 
			"horde_vol": AudioServer.get_bus_volume_db(bus_horde),
			"music_vol": AudioServer.get_bus_volume_db(bus_music),
			"hand_state": get_dda_state(bus_attack_hand),
			"meteor_state": get_dda_state(bus_attack_meteor),
			"ring_state": get_dda_state(bus_attack_ring),
			"stop_state": get_dda_state(bus_attack_stop),
			"event": "", 
			"details": ""
		})
		log_timer = 0.0

func get_dda_state(bus_idx: int) -> int:
	if AudioServer.is_bus_effect_enabled(bus_idx, FILTER_LOWPASS): return -1
	if AudioServer.is_bus_effect_enabled(bus_idx, FILTER_HIGHSHELF): return 1
	return 0

# ==========================================
# FUNÇÕES DE TELEMETRIA
# ==========================================
func record_event(event_name: String, details: String = ""):
	dda_log.append({
		"time": play_time, 
		"horde_vol": AudioServer.get_bus_volume_db(bus_horde),
		"music_vol": AudioServer.get_bus_volume_db(bus_music),
		"hand_state": get_dda_state(bus_attack_hand),
		"meteor_state": get_dda_state(bus_attack_meteor),
		"ring_state": get_dda_state(bus_attack_ring),
		"stop_state": get_dda_state(bus_attack_stop),
		"event": event_name, 
		"details": details
	})

func export_dda_telemetry():
	if dda_log.is_empty(): return
	var file = FileAccess.open("user://grafico_dda_audio.csv", FileAccess.WRITE)
	if file:
		file.store_line("Tempo(s),Horda(dB),Musica(dB),Mao(Estado),Meteoro(Estado),Anel(Estado),Stop(Estado),Evento,Detalhes")
		for entry in dda_log:
			var linha = str(snapped(entry.time, 0.1)) + "," + \
						str(snapped(entry.horde_vol, 0.1)) + "," + \
						str(snapped(entry.music_vol, 0.1)) + "," + \
						str(entry.hand_state) + "," + \
						str(entry.meteor_state) + "," + \
						str(entry.ring_state) + "," + \
						str(entry.stop_state) + "," + \
						entry.event + "," + entry.details
			file.store_line(linha)
		file.close()
		var folder_path = ProjectSettings.globalize_path("user://")
		OS.shell_open(folder_path)
		print("🎧 DADOS DO DDA (ÁUDIO) GRAVADOS COM SUCESSO EM: ", folder_path)

# ==========================================
# GESTÃO LOCAL (O ATAQUE COMEÇOU/ACABOU)
# ==========================================
func start_attack(attack_name: String):
	current_active_attack = attack_name
	
	if not is_dda_active or not attack_history.has(attack_name): return
	
	var dodges = attack_history[attack_name]["dodges"]
	var hits = attack_history[attack_name]["hits"]
	var my_bus = AudioServer.get_bus_index(attack_history[attack_name]["bus_name"])
	
	AudioServer.set_bus_effect_enabled(my_bus, FILTER_LOWPASS, false)
	AudioServer.set_bus_effect_enabled(my_bus, FILTER_HIGHSHELF, false)
	
	if dodges >= 2:
		AudioServer.set_bus_effect_enabled(my_bus, FILTER_LOWPASS, true)
		
		var volume_amount = attack_history[attack_name]["challenge_volume"]
		
		if attack_vol_tween: attack_vol_tween.kill()
		attack_vol_tween = create_tween()
		attack_vol_tween.tween_method(func(v): AudioServer.set_bus_volume_db(my_bus, v), 0.0, volume_amount, 0.5)
		
		if not is_ducking:
			if cluster_tween: cluster_tween.kill()
			cluster_tween = create_tween()
			cluster_tween.tween_method(func(v): AudioServer.set_bus_volume_db(bus_horde, v), AudioServer.get_bus_volume_db(bus_horde), horde_pressure_level + 1.5, 1.0)
			
		record_event("Desafio (Abafado)", attack_name) 
		
	elif hits > dodges:
		AudioServer.set_bus_effect_enabled(my_bus, FILTER_HIGHSHELF, true)
		record_event("Ajuda (Realçado)", attack_name) 
	else:
		record_event("Normal (Sem Filtros)", attack_name) 

func end_attack():
	if current_active_attack == "" or not attack_history.has(current_active_attack): return
	
	attack_history[current_active_attack]["dodges"] += 1
		
	var my_bus = AudioServer.get_bus_index(attack_history[current_active_attack]["bus_name"])
	AudioServer.set_bus_effect_enabled(my_bus, FILTER_LOWPASS, false)
	AudioServer.set_bus_effect_enabled(my_bus, FILTER_HIGHSHELF, false)
	
	if attack_vol_tween: attack_vol_tween.kill()
	attack_vol_tween = create_tween()
	attack_vol_tween.tween_method(func(v): AudioServer.set_bus_volume_db(my_bus, v), AudioServer.get_bus_volume_db(my_bus), 0.0, 0.5)
	
	if not is_ducking:
		if cluster_tween: cluster_tween.kill()
		cluster_tween = create_tween()
		cluster_tween.tween_method(func(v): AudioServer.set_bus_volume_db(bus_horde, v), AudioServer.get_bus_volume_db(bus_horde), horde_pressure_level, 1.5)
		
	current_active_attack = ""

func register_damage(source: String):
	time_since_last_damage = 0.0 
	horde_pressure_level = 0.0
	if not is_ducking:
		AudioServer.set_bus_volume_db(bus_horde, 0.0) 
	
	if attack_history.has(source):
		attack_history[source]["hits"] += 1
		attack_history[source]["dodges"] = 0 
		record_event("Dano Sofrido", source)

# ==========================================
# FOCUS GERAL (Ducking para Ajuda)
# ==========================================
func trigger_threat_focus(duration: float):
	if not is_dda_active or is_ducking: return 
	if current_active_attack == "" or not attack_history.has(current_active_attack): return
	if attack_history[current_active_attack]["hits"] <= attack_history[current_active_attack]["dodges"]: return 
		
	is_ducking = true
	record_event("Ducking Ativado", "Micro-ajuste -1.0dB") 
	
	var duck_tween = create_tween().set_parallel(true)
	duck_tween.tween_method(func(v): AudioServer.set_bus_volume_db(bus_horde, v), AudioServer.get_bus_volume_db(bus_horde), horde_pressure_level - 1.0, 0.4).set_ease(Tween.EASE_OUT)
	duck_tween.tween_method(func(v): AudioServer.set_bus_volume_db(bus_music, v), AudioServer.get_bus_volume_db(bus_music), -1.0, 0.4).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(duration, false).timeout

	var restore_tween = create_tween().set_parallel(true)
	restore_tween.tween_method(func(v): AudioServer.set_bus_volume_db(bus_horde, v), horde_pressure_level - 1.0, horde_pressure_level, 0.8).set_ease(Tween.EASE_IN_OUT)
	restore_tween.tween_method(func(v): AudioServer.set_bus_volume_db(bus_music, v), -1.0, 0.0, 0.8).set_ease(Tween.EASE_IN_OUT)
	
	await restore_tween.finished
	is_ducking = false
