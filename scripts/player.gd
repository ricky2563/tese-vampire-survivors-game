extends CharacterBody2D

@export var speed = 150.0
@export var max_health = 100.0

@onready var health_bar = $HealthBar
@onready var level_label = $HUD/LevelLabel
@onready var umbrella_icon = $HUD/WeaponsContainer/IconUmbrella

# --- NOVO: Referência para o AnimatedSprite2D ---
@onready var anim = $AnimatedSprite2D

@export var experience = 0
@export var experience_required = 20
@export var level = 1
@export var umbrella_scene: PackedScene

@onready var experience_bar = $HUD/ExperienceBar

# --- Variáveis de Atributos ---
var health = 100.0
var armor = 0.0
var health_regen = 0.0
var extra_damage = 0
var crit_chance = 0.0

var upgrades_owned = []
var pickup_range_level = 0
var max_health_level = 0
var armor_level = 0
var regen_level = 0
var move_speed_level = 0
var bonus_damage_level = 0
var luck_level = 0

var is_facing_right = true 
var is_dead = false
var can_umbrella = true
var umbrella_cooldown = 5.0
var is_shield_active = false
var flicker_tween: Tween

var auto_heal_enabled = false

# --- TELEMETRIA ---
var health_log = []
var play_time = 0.0
var log_timer = 0.0

var weapons = {
	"bow": {
		"level": 0
	}
}

func _input(event):
	# Se o jogador estiver morto ou o menu de upgrade estiver aberto, não faz nada
	if is_dead or get_tree().paused:
		return
		
	# Verifica se a tecla E foi pressionada e se o cooldown terminou
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if can_umbrella:
			deploy_umbrella()
		else:
			print("Guarda-chuva em cooldown!")

func deploy_umbrella():
	if umbrella_scene == null:
		print("Erro: Cena do Guarda-Chuva não atribuída no Inspector!")
		return
		
	# --- FASE 1: USOU A HABILIDADE ---
	can_umbrella = false
	is_shield_active = true
	
	# Instancia e adiciona o escudo
	var shield = umbrella_scene.instantiate()
	shield.name = "UmbrellaShield" # <--- ESTA LINHA É NOVA E SUPER IMPORTANTE!
	add_child(shield)
	
	print("Guarda-chuva ATIVADO!")
	
	# --- FASE 2: ATUALIZAR HUD (INÍCIO COOLDOWN) ---
	# 1. Faz o ícone ficar semi-transparente imediatamente
	umbrella_icon.modulate.a = 0.2
	
	# 2. Cria e inicia o Tween para piscar o Alpha (de 0.2 a 0.8 repetidamente)
	flicker_tween = create_tween()
	
	# Define o loop infinito para o piscar
	flicker_tween.set_loops() 
	
	# Transição de 0.2 a 0.8 durante 0.3 segundos
	flicker_tween.tween_property(umbrella_icon, "modulate:a", 0.8, 0.3) 
	
	# Transição de volta de 0.8 a 0.2 durante 0.3 segundos
	flicker_tween.tween_property(umbrella_icon, "modulate:a", 0.2, 0.3)
	
	print("HUD: Ícone começou a piscar (cooldown)")

	# --- FASE 3: DURAÇÃO DO ESCUDO ---
	# Espera os 2 segundos de duração do escudo ativo
	await get_tree().create_timer(2.0, false).timeout
	is_shield_active = false
	
	# --- FASE 4: RESTO DO COOLDOWN (AJUSTADO) ---
	# Espera o resto do tempo do cooldown total
	# (umbrella_cooldown - 2.0s que já passaram)
	await get_tree().create_timer(umbrella_cooldown - 2.0, false).timeout
	
	# --- FASE 5: PRONTO A USAR (FIM COOLDOWN) ---
	can_umbrella = true
	
	# 1. Cancela a animação de piscar (o Tween para)
	if is_instance_valid(flicker_tween):
		flicker_tween.kill() 
		
	# 2. Volta o ícone para opacidade total (1.0) para avisar que está pronto
	umbrella_icon.modulate.a = 1.0
	
	print("Guarda-chuva pronto a usar! HUD atualizada.")

func _ready():
	health = max_health
	health_bar.max_value = max_health
	health_bar.value = health
	
	experience_bar.max_value = experience_required
	experience_bar.value = experience
	
	level_label.text = "Lvl. " + str(level)
	
	# Começa com a animação parado
	anim.play("idle_right")

func _physics_process(delta):
	if health < max_health and health_regen > 0:
		health += health_regen * delta
		health = min(health, max_health)
		health_bar.value = health
	
	if not is_dead:
		play_time += delta
		log_timer += delta
		if log_timer >= 1.0:
			health_log.append({"time": play_time, "hp": health, "event": "Normal"})
			log_timer = 0.0
		
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if direction:
		velocity = direction * speed
		
		# --- Lógica de Direção ---
		if direction.x > 0:
			is_facing_right = true
		elif direction.x < 0:
			is_facing_right = false
			
		if is_facing_right:
			anim.play("move_right")
		else:
			anim.play("move_left")
			
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)
		
		# --- Lógica de Parar ---
		if is_facing_right:
			anim.play("idle_right")
		else:
			anim.play("idle_left")
			
	move_and_slide()

func take_damage(amount, source = "Desconhecido"):
	if is_dead:
		return
		
	# ==========================================
	# ESCUDO: AGORA SÓ BLOQUEIA METEOROS!
	# ==========================================
	if is_shield_active and source == "Boss: Meteor Attack":
		print("Escudo bloqueou com sucesso: ", source)
		
		# 1. Diz ao escudo para fazer o seu efeitinho
		var shield_node = get_node_or_null("UmbrellaShield")
		if shield_node and shield_node.has_method("block_attack"):
			shield_node.block_attack()
			
		# 2. Faz a personagem piscar a branco
		anim.modulate = Color(5.0, 5.0, 5.0, 1.0)
		var flash_tween = create_tween()
		flash_tween.tween_property(anim, "modulate", Color(1, 1, 1, 1), 0.2)
		
		# 3. Toca o som (se ele existir na cena)
		if has_node("ShieldSound"):
			$ShieldSound.play()
			
		return # <-- Cancela o resto da função! Bloqueaste o meteoro!
	# ==========================================
		
	# DDA: AVISAR O CÉREBRO QUE LEVÁMOS DANO (Agora os inimigos normais passam pelo escudo!)
	if DDAManager.has_method("register_damage"):
		DDAManager.register_damage(source)
		
	var damage_reduction = armor * 0.025 # Corta 10% por nível
	var actual_damage = amount * (1.0 - damage_reduction)
	actual_damage = max(0.0, actual_damage)
	
	health -= actual_damage
	health_bar.value = health 
	
	# Feedback de Dor: Personagem pisca a vermelho!
	anim.modulate = Color(1.0, 0.2, 0.2, 1.0) 
	var dmg_tween = create_tween()
	dmg_tween.tween_property(anim, "modulate", Color(1, 1, 1, 1), 0.3)
	
	# TELEMETRIA: Registar a pancada no Excel
	if actual_damage > 0.5: 
		health_log.append({
			"time": play_time, 
			"hp": health, 
			"event": "Dano: " + source + " (-" + str(snapped(actual_damage, 0.1)) + ")"
		})
	
	if health <= 0:
		die()

func die():
	if is_dead: return
	is_dead = true 
	print("Morreu!")
	
	print("\n======================================")
	print("💀 O JOGADOR MORREU! RELATÓRIO DO BOSS:")
	
	var main_scene = get_tree().current_scene
	if "game_time" in main_scene:
		var t = main_scene.game_time
		var minutes = int(t) / 60
		var seconds = int(t) % 60
		print("-> TEMPO DE SOBREVIVÊNCIA: ", minutes, "m ", str(seconds).pad_zeros(2), "s")
		print("--------------------------------------")
	
	var bosses = get_tree().get_nodes_in_group("boss")
	
	if bosses.size() > 0:
		for boss in bosses:
			if "current_health" in boss and "max_health" in boss:
				var hp = boss.current_health
				var max_hp = boss.max_health
				var percentagem = (float(hp) / float(max_hp)) * 100.0
				
				print("-> FIRE BOSS: ", hp, " / ", max_hp, " HP (", "%0.1f" % percentagem, "% restantes)")
				
				if percentagem <= 50.0:
					print("-> Nota: Já tinhas chegado à Fase 2!")
	else:
		print("-> O Boss ainda não tinha feito spawn ou já estava morto.")
		
	print("======================================\n")
	
	if main_scene and main_scene.has_method("trigger_game_over"):
		main_scene.trigger_game_over(false, "DERROTA...\nMorreste em combate!")
	
func export_telemetry_to_csv():
	if health_log.is_empty(): return
	
	var bosses = get_tree().get_nodes_in_group("boss")
	if bosses.size() > 0:
		for boss in bosses:
			if "current_health" in boss and "max_health" in boss:
				var hp = boss.current_health
				var max_hp = boss.max_health
				var percentagem = (float(hp) / float(max_hp)) * 100.0
				
				var tipo_boss = "Clone" if ("is_clone" in boss and boss.is_clone) else "Original"
				
				health_log.append({
					"time": play_time,
					"hp": health,
					"event": "FIM: Boss HP (%s) -> %d/%d (%0.1f%%)" % [tipo_boss, hp, max_hp, percentagem]
				})
	else:
		health_log.append({
			"time": play_time,
			"hp": health,
			"event": "FIM: Boss Morto ou Não Spawnado"
		})
	
	var csv_string = "Tempo(s),Vida,Evento\n"
	
	for entry in health_log:
		var linha = str(snapped(entry.time, 0.1)) + "," + str(snapped(entry.hp, 0.1)) + "," + entry.event
		csv_string += linha + "\n"
		
	var time_str = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var p_id = "Offline"
	var versao = "X"
	
	if has_node("/root/ExperimentManager"):
		p_id = ExperimentManager.participant_id
		versao = ExperimentManager.current_version
		
	var filename = "user://Vida_Log_%s_Versao%s_%s.csv" % [p_id, versao, time_str]
	var file = FileAccess.open(filename, FileAccess.WRITE)
	if file:
		file.store_string(csv_string)
		file.close()
		print("💾 Backup Local Vida guardado com estado do Boss.")
		
	if has_node("/root/ExperimentManager") and ExperimentManager.has_method("receive_player_csv"):
		ExperimentManager.receive_player_csv(csv_string)
		
func record_event(event_name):
	health_log.append({
		"time": play_time, 
		"hp": health, 
		"event": event_name
	})
	print("TELEMETRIA: Evento registado: ", event_name)
	
func gain_experience(amount):
	experience += amount
	experience_bar.value = experience
	
	if experience >= experience_required:
		level_up()

func level_up():
	level += 1
	experience = 0 
	
	# ==========================================
	# CURVA DE XP HÍBRIDA
	# ==========================================
	if level <= 5:
		# Até ao nível 5, mantém a tua fórmula original super rápida!
		experience_required += 15 
	else:
		# A partir daqui, trava um bocado para não spamar o menu
		experience_required += 40 
	# ==========================================
	
	experience_bar.max_value = experience_required
	experience_bar.value = experience
	level_label.text = "Lvl. " + str(level)
		
	if auto_heal_enabled:
		# Cura massiva no late game (25 HP)
		health += 25.0 
		health = min(health, max_health)
		if is_instance_valid(health_bar):
			health_bar.value = health
	else:
		show_upgrade_menu()
	
func show_upgrade_menu():
	get_tree().paused = true
	
	var menu = preload("res://scenes/upgrade_menu.tscn").instantiate()
	get_tree().current_scene.add_child(menu)
	
func get_weapon_upgrade(weapon_name, level):
	match weapon_name:
		"bow":
			match level:
				0: return "bow_amount"      # Nível 1 (+1 flecha)
				1: return "bow_piercing"    # Nível 2 (+2 piercing de uma vez!)
				2: return "bow_multishot"      # Nível 3 (Spread em cone)
				3: return "bow_triple"   # Nível 4 (Dispara para Frente e Trás)
				4: return "bow_amount"   
				5: return "bow_piercing"    # Nível 5 (+2 piercing)
				6: return "bow_multishot"   # Nível 6 (MAX: Dispara nas 4 Direções)
								
	return "none"
