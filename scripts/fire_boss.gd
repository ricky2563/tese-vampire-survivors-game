extends CharacterBody2D

@export var speed = 40
@export var player: Node2D
@export var fire_hand_scene: PackedScene
@export var meteor_scene: PackedScene
@export var sound_fireball_cast: AudioStream
@export var sound_ring_warning: AudioStream
@export var sound_hand_cast: AudioStream 
@export var fire_ring_scene: PackedScene

@onready var attack_timer = $AttackTimer
@onready var audio_player = $AttackSound

var is_attacking = false

func _ready():
	player = get_tree().get_first_node_in_group("player")
	attack_timer.start()

func _physics_process(delta):
	if player:
		var direction = global_position.direction_to(player.global_position)
		velocity = direction * speed
		move_and_slide()

func _on_attack_timer_timeout():
	if is_attacking:
		return
	var r = randf()
	if r < 0.4:
		fire_hand_attack()
	elif r < 0.9:
		meteor_rain_attack()
	else:
		fire_ring_attack()

func fire_hand_attack():
	if not player: return
	if fire_hand_scene == null: return
	
	is_attacking = true
	
	if sound_hand_cast:
		audio_player.bus = "Attack_Hand"
		audio_player.stream = sound_hand_cast
		audio_player.play()
	
	var attack = fire_hand_scene.instantiate()
	var offset = Vector2(randf_range(-50,50), randf_range(-50,50))
	attack.global_position = player.global_position + offset
	get_tree().root.add_child(attack)
	
	await get_tree().create_timer(0.5, false).timeout
	is_attacking = false

func meteor_rain_attack():
	if not player: return
	
	is_attacking = true 
	var meteor_count = 12 # Aumentámos para criar uma "Chuva" real
	
	# --- 1. FASE DE AVISO SONORO (TELEGRAPH) ---
	# Um aviso sonoro mais longo e assustador (ex: toca 3 vezes rápido)
	audio_player.bus = "Attack_Meteor" 
	for i in range(3):
		if sound_fireball_cast:
			audio_player.stream = sound_fireball_cast
			audio_player.play(2.50)
		await get_tree().create_timer(0.15, false).timeout

	# --- 2. JANELA DE REAÇÃO (DDA) ---
	await get_tree().create_timer(0.7, false).timeout

	# --- 3. CÁLCULO INTELIGENTE (BOMBARDEAMENTO) ---
	var positions = []
	var player_pos = player.global_position
	
	# Opcional: Se o teu player tiver a variável 'velocity', podemos prever para onde ele vai
	var player_velocity = Vector2.ZERO
	if "velocity" in player:
		player_velocity = player.velocity.normalized()

	# Meteoro 1: Em cima do jogador
	positions.append(player_pos)
	
	# Meteoro 2 e 3: À frente do jogador (cortam a fuga)
	positions.append(player_pos + (player_velocity * 80))
	positions.append(player_pos + (player_velocity * 160))

	# Meteoros 4 a 12: Espalhados aleatoriamente num raio grande para criar caos
	for i in range(meteor_count - 3):
		var angle = randf_range(0, TAU)
		# Raio maior (de 50 a 250 pixels de distância)
		var distance = randf_range(50, 250) 
		var pos = player_pos + Vector2.RIGHT.rotated(angle) * distance
		positions.append(pos)

	# --- 4. SPAWN EM CASCATA ---
	for pos in positions:
		spawn_meteor(pos)
		# Caem muito rápido uns a seguir aos outros (0.05s)
		await get_tree().create_timer(0.05, false).timeout
		
	# Espera os meteoros acabarem de cair antes de libertar o Boss
	await get_tree().create_timer(1.2, false).timeout
	is_attacking = false

func spawn_meteor(pos):
	var meteor = meteor_scene.instantiate()
	meteor.target_position = pos
	get_tree().current_scene.add_child(meteor)
	
func fire_ring_attack():
	if not player: return
	
	is_attacking = true

	var original_speed = speed
	speed = 0 
	
	if sound_ring_warning:
		audio_player.bus = "Attack_Ring"
		audio_player.stream = sound_ring_warning
		audio_player.play(0.0) 
	
	var duration = 7.0
	var timer = 0.0
	while timer < duration:
		# Efeito de tremor (shaking)
		global_position += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (timer * 2)
		
		# Espera um frame
		await get_tree().process_frame
		timer += get_process_delta_time()
		
		if timer >= 7.0:
			audio_player.stop()
			break

	# --- FASE 2: EXPLOSÃO ---
	
	if fire_ring_scene:
		var ring = fire_ring_scene.instantiate()
		ring.global_position = global_position
		get_tree().current_scene.add_child(ring)
		
	print("Anel de Fogo disparado após 7s de carga!")
	await get_tree().create_timer(1.0).timeout
	
	speed = original_speed
	is_attacking = false
