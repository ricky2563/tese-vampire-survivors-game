extends Node

# ==========================================
# SINAIS PARA O MUNDO (Eventos Ambientais)
# ==========================================
signal weather_event_started(event_type)
signal weather_event_ended(event_type)

var is_weather_active = false
var base_weather_timer = 0.0
var dda_weather_cooldown = 10.0

var is_dda_active = true 

enum TestMode { DYNAMIC, ALWAYS_EASY, ALWAYS_CHALLENGE }
var current_test_mode: TestMode = TestMode.DYNAMIC

var bus_music: int
var bus_horde: int
var bus_threats: int

var bus_attack_hand: int
var bus_attack_meteor: int
var bus_attack_ring: int
var bus_attack_stop: int
var bus_attack_nova: int

const FILTER_LOWPASS = 0   # Desafio (Abafa)
const FILTER_HIGHSHELF = 1 # Ajuda (Realça)

# ==========================================
# PAINEL DE AFINAÇÃO DO DDA (Dashboard no Inspector)
# ==========================================
@export_category("Afinações DDA - Tempos de Crise")
@export var duck_horde_db: float = -1.0
@export var duck_music_db: float = -1.0
@export var challenge_horde_boost: float = 1.5

var attack_history = {
	"Boss: Meteor Attack": {"hits": 0, "dodges": 0, "bus_name": "Attack_Meteor", "challenge_volume": -10.0},
	"Boss: Ring Attack":   {"hits": 0, "dodges": 0, "bus_name": "Attack_Ring",   "challenge_volume": -2.0},
	"Boss: Stop Attack":   {"hits": 0, "dodges": 0, "bus_name": "Attack_Stop",   "challenge_volume": 0.0}, 
	"Boss: Hand Attack":   {"hits": 0, "dodges": 0, "bus_name": "Attack_Hand",   "challenge_volume": 1.0},
	"Boss: Nova Attack":   {"hits": 0, "dodges": 0, "bus_name": "Attack_Nova",   "challenge_volume": 2.0}
}

var active_duckings = 0 
var attack_tweens = {} 

var time_since_last_damage = 0.0
var horde_pressure_level = 0.0
var cluster_tween: Tween 

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
	bus_attack_nova = AudioServer.get_bus_index("Attack_Nova")

func _process(delta):
	# O RELÓGIO NUNCA PÁRA (Mesmo com DDA desligado para a tese ter dados!)
	play_time += delta 
	time_since_last_damage += delta
	
	# ==========================================
	# LÓGICA DE EVENTOS AMBIENTAIS (CHUVA)
	# ==========================================
	if not is_weather_active:
		if not is_dda_active:
			base_weather_timer += delta
			if base_weather_timer >= 30.0:
				base_weather_timer = 0.0
				if randf() <= 0.25:
					start_weather_event("rain_storm")
		else:
			if are_all_attacks_challenge():
				dda_weather_cooldown -= delta
				if dda_weather_cooldown <= 0.0:
					dda_weather_cooldown = 60.0
					if randf() <= 0.8: # 30% de probabilidade
						start_weather_event("rain_storm")
			else:
				dda_weather_cooldown = 10.0 # Se o player perder dodges, o cooldown faz reset rápido
	# ==========================================
	
	# Só mexe na horda se o DDA estiver ativo
	if is_dda_active:
		if current_test_mode == TestMode.ALWAYS_CHALLENGE:
			horde_pressure_level = 5.0
			AudioServer.set_bus_volume_db(bus_horde, horde_pressure_level)
		elif current_test_mode == TestMode.ALWAYS_EASY:
			horde_pressure_level = 0.0
			AudioServer.set_bus_volume_db(bus_horde, horde_pressure_level)
		else:
			if time_since_last_damage > 20.0 and active_duckings == 0:
				horde_pressure_level = min(horde_pressure_level + (delta * 0.2), 5.0)
				if not cluster_tween or not cluster_tween.is_running():
					AudioServer.set_bus_volume_db(bus_horde, horde_pressure_level)
		
	# A GRAVAÇÃO NUNCA PÁRA
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
			"nova_state": get_dda_state(bus_attack_nova),
			"event": "", 
			"details": ""
		})
		log_timer = 0.0

func get_dda_state(bus_idx: int) -> int:
	if AudioServer.is_bus_effect_enabled(bus_idx, FILTER_LOWPASS): return -1
	if AudioServer.is_bus_effect_enabled(bus_idx, FILTER_HIGHSHELF): return 1
	return 0

func record_event(event_name: String, details: String = ""):
	dda_log.append({
		"time": play_time, 
		"horde_vol": AudioServer.get_bus_volume_db(bus_horde),
		"music_vol": AudioServer.get_bus_volume_db(bus_music),
		"hand_state": get_dda_state(bus_attack_hand),
		"meteor_state": get_dda_state(bus_attack_meteor),
		"ring_state": get_dda_state(bus_attack_ring),
		"stop_state": get_dda_state(bus_attack_stop),
		"nova_state": get_dda_state(bus_attack_nova),
		"event": event_name, 
		"details": details
	})

func export_dda_telemetry():
	if dda_log.is_empty(): return
	
	# 1. Puxamos a verificação para cima para sabermos o que escrever nas linhas
	var p_id = "Offline"
	var versao = "X"
	var tipo_versao_csv = "BASE" # O que vai aparecer no SPSS
	
	if has_node("/root/ExperimentManager"):
		p_id = ExperimentManager.participant_id
		versao = ExperimentManager.current_version
		
	# 2. Descobre se a Run atual tem o DDA ligado ou não
	if is_dda_active:
		tipo_versao_csv = "DDA"
	else:
		tipo_versao_csv = "BASE"
	
	# 3. Adicionada a coluna 'Versao' aqui no fim do cabeçalho
	var csv_string = "Tempo(s),Horda(dB),Musica(dB),Mao(Estado),Meteoro(Estado),Anel(Estado),Stop(Estado),Nova(Estado),Evento,Detalhes,Versao\n"
	
	for entry in dda_log:
		# 4. Adicionada a variável `tipo_versao_csv` no fim de cada linha!
		var linha = str(snapped(entry.time, 0.1)) + "," + \
					str(snapped(entry.horde_vol, 0.1)) + "," + \
					str(snapped(entry.music_vol, 0.1)) + "," + \
					str(entry.hand_state) + "," + \
					str(entry.meteor_state) + "," + \
					str(entry.ring_state) + "," + \
					str(entry.stop_state) + "," + \
					str(entry.nova_state) + "," + \
					entry.event + "," + entry.details + "," + tipo_versao_csv
		csv_string += linha + "\n"
		
	var time_str = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	
	# ==========================================
	# NOVO: DESCOBRIR A PASTA DO EXECUTÁVEL
	# ==========================================
	var base_dir = ""
	if OS.has_feature("editor"):
		# No editor, guarda na pasta de utilizador para não gerar ficheiros de tradução!
		base_dir = ProjectSettings.globalize_path("user://")
	else:
		# No jogo exportado, guarda ao lado do .exe
		base_dir = OS.get_executable_path().get_base_dir()
		
	var file_name = "DDA_Log_%s_Versao%s_%s.csv" % [p_id, versao, time_str]
	var filename = base_dir.path_join(file_name)
	# ==========================================
	
	var file = FileAccess.open(filename, FileAccess.WRITE)
	if file:
		file.store_string(csv_string)
		file.close()
		print("💾 Backup Local DDA guardado em: ", filename)
		
	if has_node("/root/ExperimentManager") and ExperimentManager.has_method("receive_dda_csv"):
		ExperimentManager.receive_dda_csv(csv_string)

# ==========================================
# GESTÃO LOCAL (O ATAQUE COMEÇOU/ACABOU)
# ==========================================
func start_attack(attack_name: String):
	if not attack_history.has(attack_name): return
	
	if not is_dda_active:
		record_event("Ataque Base (Sem DDA)", attack_name)
		return
	
	var my_bus = AudioServer.get_bus_index(attack_history[attack_name]["bus_name"])
	
	AudioServer.set_bus_effect_enabled(my_bus, FILTER_LOWPASS, false)
	AudioServer.set_bus_effect_enabled(my_bus, FILTER_HIGHSHELF, false)
	
	var force_challenge = false
	var force_easy = false
	
	if current_test_mode == TestMode.ALWAYS_CHALLENGE:
		force_challenge = true
	elif current_test_mode == TestMode.ALWAYS_EASY:
		force_easy = true
	else:
		var dodges = attack_history[attack_name]["dodges"]
		var hits = attack_history[attack_name]["hits"]
		if dodges >= 2: force_challenge = true
		elif hits > dodges: force_easy = true

	if force_challenge:
		AudioServer.set_bus_effect_enabled(my_bus, FILTER_LOWPASS, true)
		var volume_amount = attack_history[attack_name]["challenge_volume"]
		
		if attack_tweens.has(attack_name) and attack_tweens[attack_name]: 
			attack_tweens[attack_name].kill()
		attack_tweens[attack_name] = create_tween()
		attack_tweens[attack_name].tween_method(func(v): AudioServer.set_bus_volume_db(my_bus, v), 0.0, volume_amount, 0.5)
		
		if active_duckings == 0 and current_test_mode != TestMode.ALWAYS_CHALLENGE:
			if cluster_tween: cluster_tween.kill()
			cluster_tween = create_tween()
			cluster_tween.tween_method(func(v): AudioServer.set_bus_volume_db(bus_horde, v), AudioServer.get_bus_volume_db(bus_horde), horde_pressure_level + challenge_horde_boost, 1.0)
			
		record_event("Desafio (Abafado/Forçado)", attack_name) 
		
	elif force_easy:
		AudioServer.set_bus_effect_enabled(my_bus, FILTER_HIGHSHELF, true)
		record_event("Ajuda (Realçado/Forçada)", attack_name) 
	else:
		record_event("Normal (Sem Filtros)", attack_name)

func end_attack(attack_name: String):
	if not attack_history.has(attack_name): return
	
	attack_history[attack_name]["dodges"] += 1
	
	if not is_dda_active: return
		
	var my_bus = AudioServer.get_bus_index(attack_history[attack_name]["bus_name"])
	AudioServer.set_bus_effect_enabled(my_bus, FILTER_LOWPASS, false)
	AudioServer.set_bus_effect_enabled(my_bus, FILTER_HIGHSHELF, false)
	
	if attack_tweens.has(attack_name) and attack_tweens[attack_name]: 
		attack_tweens[attack_name].kill()
	attack_tweens[attack_name] = create_tween()
	attack_tweens[attack_name].tween_method(func(v): AudioServer.set_bus_volume_db(my_bus, v), AudioServer.get_bus_volume_db(my_bus), 0.0, 0.5)
	
	if active_duckings == 0:
		if cluster_tween: cluster_tween.kill()
		cluster_tween = create_tween()
		cluster_tween.tween_method(func(v): AudioServer.set_bus_volume_db(bus_horde, v), AudioServer.get_bus_volume_db(bus_horde), horde_pressure_level, 1.5)

func register_damage(source: String):
	if attack_history.has(source):
		attack_history[source]["hits"] += 1
		attack_history[source]["dodges"] = 0 
		record_event("Dano Sofrido", source)
		
	if is_dda_active:
		time_since_last_damage = 0.0 
		horde_pressure_level = 0.0
		if active_duckings == 0:
			AudioServer.set_bus_volume_db(bus_horde, 0.0) 

func trigger_threat_focus(attack_name: String, duration: float):
	if not attack_history.has(attack_name): return 
	
	if not is_dda_active: return
	if current_test_mode == TestMode.ALWAYS_CHALLENGE: return
	
	if current_test_mode == TestMode.DYNAMIC and attack_history[attack_name]["hits"] <= attack_history[attack_name]["dodges"]: 
		return
		
	active_duckings += 1
	record_event("Ducking Ativado", "Micro-ajuste Horda/Musica") 
	
	var duck_tween = create_tween().set_parallel(true)
	duck_tween.tween_method(func(v): AudioServer.set_bus_volume_db(bus_horde, v), AudioServer.get_bus_volume_db(bus_horde), horde_pressure_level + duck_horde_db, 0.4).set_ease(Tween.EASE_OUT)
	duck_tween.tween_method(func(v): AudioServer.set_bus_volume_db(bus_music, v), AudioServer.get_bus_volume_db(bus_music), duck_music_db, 0.4).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(duration, false).timeout

	active_duckings = max(0, active_duckings - 1)
	
	if active_duckings == 0:
		var restore_tween = create_tween().set_parallel(true)
		restore_tween.tween_method(func(v): AudioServer.set_bus_volume_db(bus_horde, v), horde_pressure_level + duck_horde_db, horde_pressure_level, 0.8).set_ease(Tween.EASE_IN_OUT)
		restore_tween.tween_method(func(v): AudioServer.set_bus_volume_db(bus_music, v), duck_music_db, 0.0, 0.8).set_ease(Tween.EASE_IN_OUT)

# ==========================================
# SISTEMA AMBIENTAL (CHUVA / TROVOADA)
# ==========================================
func are_all_attacks_challenge() -> bool:
	if current_test_mode == TestMode.ALWAYS_CHALLENGE:
		return true
		
	var active_attacks_checked = 0
	var challenged_attacks = 0

	for attack in attack_history:
		# Só verifica os ataques que o Boss já tentou usar (hits + dodges > 0)
		var total_uses = attack_history[attack]["hits"] + attack_history[attack]["dodges"]
		if total_uses > 0:
			active_attacks_checked += 1
			if attack_history[attack]["dodges"] >= 2:
				challenged_attacks += 1

	# Se ele ainda não atacou, não chove
	if active_attacks_checked == 0:
		return false

	# Devolve true se TODOS os ataques que ele JÁ USOU estiverem em modo Challenge
	return challenged_attacks == active_attacks_checked

func start_weather_event(event_type: String):
	is_weather_active = true
	record_event("Evento Ambiental Início", event_type)
	weather_event_started.emit(event_type)
	print("⛈️ O EVENTO AMBIENTAL COMEÇOU: ", event_type)
	
	# O evento de tempestade dura 20 segundos
	await get_tree().create_timer(20.0, false).timeout
	
	is_weather_active = false
	record_event("Evento Ambiental Fim", event_type)
	weather_event_ended.emit(event_type)
	print("☀️ O EVENTO AMBIENTAL TERMINOU")

func reset_dda_telemetry():
	dda_log.clear()
	play_time = 0.0
	log_timer = 0.0
	active_duckings = 0
	time_since_last_damage = 0.0
	horde_pressure_level = 0.0
	
	is_weather_active = false
	base_weather_timer = 0.0
	dda_weather_cooldown = 10.0
	
	for attack in attack_history:
		attack_history[attack]["hits"] = 0
		attack_history[attack]["dodges"] = 0
		
	print("🔄 DDA: Telemetria e histórico limpos para o Restart.")
