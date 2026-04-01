extends CharacterBody2D

@export var speed = 40
@export var player: Node2D
@export var fire_hand_scene: PackedScene
@export var meteor_scene: PackedScene
@export var sound_fireball_cast: AudioStream
@export var sound_ring_warning: AudioStream
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
	# 60% de chance para a mão, 40% para os meteoros
	if r < 0.4:
		fire_hand_attack()
	elif r < 0.7:
		meteor_rain_attack()
	else:
		fire_ring_attack()

func fire_hand_attack():
	if not player: return
	if fire_hand_scene == null: return
	
	# --- TELEGRAFADO DA MÃO ---
	# (Opcional: Podes tocar um som diferente aqui no futuro)
	
	var attack = fire_hand_scene.instantiate()
	var offset = Vector2(randf_range(-50,50), randf_range(-50,50))
	attack.global_position = player.global_position + offset
	get_tree().root.add_child(attack)

func meteor_rain_attack():
	if not player: return
	
	var meteor_count = 4
	var positions = []
	var min_distance = 80
	var attempts = 0
	
	# 1. CALCULAR POSIÇÕES (Lógica que já tinhas)
	while positions.size() < meteor_count and attempts < 50:
		var angle = randf_range(0, TAU)
		var distance = randf_range(80, 200)
		var pos = player.global_position + Vector2.RIGHT.rotated(angle) * distance
		
		var too_close = false
		for p in positions:
			if p.distance_to(pos) < min_distance:
				too_close = true
				break
		if not too_close:
			positions.append(pos)
		attempts += 1

	# --- 2. FASE DE AVISO SONORO (TELEGRAPH) ---
	# Tocamos os sons ANTES de qualquer efeito visual aparecer
	for i in range(meteor_count):
		if sound_fireball_cast:
			audio_player.stream = sound_fireball_cast
			# Toca a partir do ponto onde o som realmente começa (2.50s)
			audio_player.play(2.50)
		
		# Intervalo rápido entre os "disparos" sonoros
		await get_tree().create_timer(0.12, false).timeout

	# --- 3. JANELA DE REAÇÃO (DDA) ---
	# Esta pausa dá tempo ao jogador para processar o som e usar o guarda-chuva
	# Para a tese: Aumentar este valor = Jogo mais fácil / Diminuir = Jogo mais difícil !!!!
	await get_tree().create_timer(0.7, false).timeout

	# --- 4. SPAWN DOS METEOROS ---
	for pos in positions:
		spawn_meteor(pos)
		# Pequeno atraso visual entre cada queda
		await get_tree().create_timer(0.15, false).timeout

func spawn_meteor(pos):
	var meteor = meteor_scene.instantiate()
	meteor.target_position = pos
	get_tree().current_scene.add_child(meteor)
	
	
func fire_ring_attack():
	if not player: return
	
	is_attacking = true
	# --- FASE 1: CARGA (7 SEGUNDOS) ---
	var original_speed = speed
	speed = 0 # O Boss para completamente
	
	if sound_ring_warning:
		audio_player.stream = sound_ring_warning
		# Se o teu som também tiver um atraso inicial, ajusta o segundo aqui:
		audio_player.play(0.0) 
	
	# --- FEEDBACK VISUAL PARA A TESE ---
	# Como 7 segundos é muito tempo, o Boss deve "tremer" cada vez mais
	# para indicar que a energia está a ficar instável.
	var duration = 7.0
	var timer = 0.0
	while timer < duration:
		# Efeito de tremor (shaking)
		global_position += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (timer * 2)
		
		# Espera um frame
		await get_tree().process_frame
		timer += get_process_delta_time()
		
		# Se o áudio chegar aos 7 segundos, paramos o som
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
