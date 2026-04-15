extends CharacterBody2D

@export var speed = 40
@export var max_health = 90000
@export var player: Node2D
@export var fire_hand_scene: PackedScene
@export var meteor_scene: PackedScene
@export var sound_fireball_cast: AudioStream
@export var sound_ring_warning: AudioStream
@export var sound_hand_cast: AudioStream 
@export var sound_stop_warning: AudioStream
@export var sound_stop_snap: AudioStream
@export var fire_ring_scene: PackedScene

@onready var attack_timer = $AttackTimer
@onready var audio_player = $AttackSound
@onready var stop_anim = $stop_attack
@onready var speech_bubble = $SpeechBubble
@onready var speech_label = $SpeechBubble/Label

var is_attacking = false
var attack_deck = []
var last_attack = ""
var current_health = 0

# --- VARIÁVEIS DA FASE 2 ---
var is_clone = false
var phase_2_active = false
var is_invulnerable = false
var my_clone = null

func _ready():
	player = get_tree().get_first_node_in_group("player")
	add_to_group("boss")
	
	if not is_clone:
		current_health = max_health
		attack_timer.start()
	
	if stop_anim:
		stop_anim.visible = false

func _physics_process(delta):
	if player:
		# Pequena otimização: não anda se estiver invulnerável (na cutscene de divisão)
		if not is_invulnerable:
			var direction = global_position.direction_to(player.global_position)
			velocity = direction * speed
			move_and_slide()

func _on_attack_timer_timeout():
	# O clone ignora o próprio relógio, ou se estivermos na cutscene
	if is_clone or (phase_2_active and is_invulnerable):
		return
		
	var clone_is_busy = is_instance_valid(my_clone) and my_clone.is_attacking
	
	if is_attacking or clone_is_busy:
		return
		
	pick_and_execute_attack()
	
	if is_instance_valid(my_clone):
		my_clone.pick_and_execute_attack()

func pick_and_execute_attack():
	if attack_deck.is_empty():
		if phase_2_active: refill_deck_phase_2()
		else: refill_deck()
		
	var next_attack = attack_deck.pop_back()
	if next_attack == last_attack and attack_deck.size() > 0:
		attack_deck.insert(0, next_attack)
		next_attack = attack_deck.pop_back()
	last_attack = next_attack
	
	# Encaminha para a função correta
	match next_attack:
		"hand": fire_hand_attack()
		"meteor": meteor_rain_attack()
		"stop": stop_curse_attack()
		"ring": fire_ring_attack()
			
func refill_deck():
	attack_deck.clear()
	for i in range(3): attack_deck.append("hand")   
	for i in range(3): attack_deck.append("meteor") 
	for i in range(1): attack_deck.append("stop")   
	for i in range(1): attack_deck.append("ring")   
	attack_deck.shuffle()
	print("BOSS: Novo baralho de ataques gerado (Fase 1)!")

func refill_deck_phase_2():
	attack_deck.clear()
	for i in range(4): attack_deck.append("hand")
	for i in range(4): attack_deck.append("meteor") 
	for i in range(2): attack_deck.append("ring")   
	attack_deck.shuffle()
	print("BOSS: Baralho da Fase 2 gerado (Sem Stop)!")

# ==========================================
# ATAQUES (Mantidos exatos como os teus)
# ==========================================
func fire_hand_attack():
	if not player: return
	if fire_hand_scene == null: return
	is_attacking = true
	
	if DDAManager.is_dda_active: DDAManager.trigger_threat_focus(0.5)
	
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
	var meteor_count = 12 
	
	if DDAManager.is_dda_active: DDAManager.trigger_threat_focus(1.5)
	if DDAManager.is_dda_meteor_active: DDAManager.trigger_threat_meteor_focus(1.5)
	
	audio_player.bus = "Attack_Meteor" 
	for i in range(3):
		if sound_fireball_cast:
			audio_player.stream = sound_fireball_cast
			audio_player.play(2.50)
		await get_tree().create_timer(0.15, false).timeout

	await get_tree().create_timer(1, false).timeout

	var positions = []
	var player_pos = player.global_position
	var player_velocity = Vector2.ZERO
	if "velocity" in player: player_velocity = player.velocity.normalized()

	positions.append(player_pos)
	positions.append(player_pos + (player_velocity * 80))
	positions.append(player_pos + (player_velocity * 160))

	for i in range(meteor_count - 3):
		var angle = randf_range(0, TAU)
		var distance = randf_range(50, 250) 
		var pos = player_pos + Vector2.RIGHT.rotated(angle) * distance
		positions.append(pos)

	for pos in positions:
		spawn_meteor(pos)
		await get_tree().create_timer(0.05, false).timeout
		
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
	
	var duration = 4.5 if phase_2_active else 7.0
	
	if DDAManager.is_dda_active: DDAManager.trigger_threat_focus(duration)
	
	if sound_ring_warning:
		audio_player.bus = "Attack_Ring"
		audio_player.stream = sound_ring_warning
		audio_player.play(0.0) 
	
	var timer = 0.0
	while timer < duration:
		# ==========================================
		# O SEGREDO ANTI-CRASH: Se o boss foi apagado, aborta tudo!
		# ==========================================
		if not is_inside_tree():
			return
			
		var tremor_forca = 4 if phase_2_active else 2
		global_position += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (timer * tremor_forca)
		
		await get_tree().process_frame
		timer += get_process_delta_time()
		
		if timer >= duration:
			audio_player.stop()
			break

	# Confirmação dupla antes de instanciar o anel
	if not is_inside_tree(): return

	if fire_ring_scene:
		var ring = fire_ring_scene.instantiate()
		ring.global_position = global_position
		
		if phase_2_active:
			ring.scale = Vector2(0.65, 0.65)
			
		get_tree().current_scene.add_child(ring)
		
	print("Anel de Fogo disparado após ", duration, "s de carga!")
	
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree(): return # Outra segurança final
	
	speed = original_speed
	is_attacking = false
	
func stop_curse_attack():
	if phase_2_active:
		is_attacking = false
		return

	if not player: return
	is_attacking = true
	var original_speed = speed
	speed = 0
	
	var telegraph_time = 1.2
	var check_time = 0.3
	
	if DDAManager.is_dda_active: DDAManager.trigger_threat_focus(telegraph_time + check_time)
		
	if sound_stop_warning:
		audio_player.bus = "Attack_Stop"
		audio_player.stream = sound_stop_warning
		audio_player.play()
	
	if has_node("Sprite2D"): $Sprite2D.visible = false
	if stop_anim:
		stop_anim.visible = true
		stop_anim.frame = 0 
		stop_anim.play("stop_attack")
	
	await get_tree().create_timer(telegraph_time, false).timeout
	
	# Verifica se o Boss ainda existe e se a cutscene não ativou
	if not is_inside_tree(): return
	if phase_2_active and not is_clone:
		is_attacking = false
		return
	
	audio_player.stop() 
	if sound_stop_snap:
		audio_player.stream = sound_stop_snap
		audio_player.play()
	
	var player_moved = false
	var timer = 0.0
	
	while timer < check_time:
		if not is_inside_tree(): return # Anti-crash
		
		if "velocity" in player and player.velocity.length() > 5.0:
			player_moved = true
		timer += get_process_delta_time()
		await get_tree().process_frame
		
	if not is_inside_tree(): return # Anti-crash
		
	if stop_anim:
		stop_anim.visible = false
		stop_anim.stop()
	if has_node("Sprite2D"): $Sprite2D.visible = true
		
	if player_moved:
		if player.has_method("take_damage"): player.take_damage(30)
		if speech_bubble and speech_label:
			var taunts = ["I SAID STOP!", "BE STILL!", "MOVEMENT DETECTED!", "YOU DARE MOVE?", "RUNNING KILLS YOU FASTER!"]
			speech_label.text = taunts.pick_random()
			speech_bubble.visible = true
			get_tree().create_timer(2.0, false).timeout.connect(func(): speech_bubble.visible = false)
		
	await get_tree().create_timer(0.5, false).timeout
	if not is_inside_tree(): return # Anti-crash
	
	speed = original_speed
	is_attacking = false
	
# ==========================================
# SISTEMA DE DANO E FASE 2
# ==========================================
func take_damage(amount):
	if is_invulnerable:
		return
		
	current_health -= amount
	
	# Efeito visual de levar dano
	modulate = Color(1.0, 0.3, 0.3)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	
	# --- GATILHO DA FASE 2 (Garante que só o Mestre pode ativar isto e apenas 1 vez) ---
	if current_health <= (max_health / 2.0) and not phase_2_active and not is_clone:
		enter_phase_2()
	
	if current_health <= 0:
		die()

func enter_phase_2():
	phase_2_active = true
	is_invulnerable = true
	is_attacking = true # Bloqueia ataques durante a cutscene
	var original_speed = speed
	speed = 0
	
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	
	if has_node("CollisionShape2D"): $CollisionShape2D.set_deferred("disabled", true)
	
	var original_z = z_index
	var original_z_rel = z_as_relative
	self.z_index = 100 
	self.z_as_relative = false 
	
	var cutscene_cam = Camera2D.new()
	add_child(cutscene_cam)
	cutscene_cam.make_current()
	
	var dark_bg = ColorRect.new()
	dark_bg.color = Color(0, 0, 0, 0) 
	dark_bg.size = Vector2(10000, 10000) 
	dark_bg.position = -dark_bg.size / 2.0 
	dark_bg.z_index = 90 
	dark_bg.z_as_relative = false 
	cutscene_cam.add_child(dark_bg)
	
	# --- FASE 1: ZOOM E ESCURO (1.5s) ---
	var cam_tween = create_tween().set_parallel(true)
	cam_tween.tween_property(cutscene_cam, "zoom", Vector2(1.8, 1.8), 1.5).set_trans(Tween.TRANS_SINE)
	cam_tween.tween_property(dark_bg, "color:a", 0.85, 1.5) 
	modulate = Color(2.0, 1.0, 1.0) 
	await cam_tween.finished
	
	# --- FASE 2: TREMOR (1.5s) ---
	var original_pos = global_position
	var shake_tween = create_tween()
	for i in range(30):
		var random_offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
		shake_tween.tween_property(self, "global_position", original_pos + random_offset, 0.05)
	shake_tween.tween_property(self, "global_position", original_pos, 0.05)
	await shake_tween.finished
	
	# --- FASE 3: SPAWN DO CLONE ---
	var clone_scene = load(scene_file_path) 
	my_clone = clone_scene.instantiate() # Mestre guarda a referência
	
	my_clone.is_clone = true
	my_clone.is_invulnerable = true # Clone nasce bloqueado!
	my_clone.is_attacking = true    # Clone nasce bloqueado!
	my_clone.global_position = self.global_position
	my_clone.current_health = self.current_health 
	my_clone.phase_2_active = true 
	my_clone.process_mode = Node.PROCESS_MODE_ALWAYS
	my_clone.z_index = 99 
	my_clone.z_as_relative = false
	my_clone.modulate = Color(2.0, 1.0, 1.0, 0.0) 
	
	get_tree().current_scene.add_child(my_clone)
	
	# --- FASE 4: SEPARAÇÃO (2.0s) ---
	var sep_tween = create_tween().set_parallel(true)
	sep_tween.tween_property(my_clone, "modulate:a", 1.0, 1.5)
	sep_tween.tween_property(self, "global_position", original_pos + Vector2(-80, 0), 2.0).set_trans(Tween.TRANS_CUBIC)
	sep_tween.tween_property(my_clone, "global_position", original_pos + Vector2(80, 0), 2.0).set_trans(Tween.TRANS_CUBIC)
	await sep_tween.finished
	
	# --- FASE 5: VOLTAR (1.0s) ---
	var cam_back = create_tween().set_parallel(true)
	cam_back.tween_property(cutscene_cam, "zoom", Vector2(1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE)
	cam_back.tween_property(dark_bg, "color:a", 0.0, 1.0)
	cam_back.tween_property(self, "modulate", Color.WHITE, 1.0)
	cam_back.tween_property(my_clone, "modulate", Color.WHITE, 1.0)
	await cam_back.finished
	
	# --- FINALIZAÇÃO: LIBERTAÇÃO ---
	cutscene_cam.queue_free()
	z_index = original_z
	z_as_relative = original_z_rel
	my_clone.z_index = original_z
	my_clone.z_as_relative = original_z_rel
	
	if has_node("CollisionShape2D"): $CollisionShape2D.set_deferred("disabled", false)
	if my_clone.has_node("CollisionShape2D"): my_clone.get_node("CollisionShape2D").set_deferred("disabled", false)
	
	speed = original_speed + 15
	my_clone.speed = speed
	
	# AGORA SIM, libertamos o movimento e ataques para ambos
	self.is_invulnerable = false
	self.is_attacking = false
	my_clone.is_invulnerable = false
	my_clone.is_attacking = false
	
	self.process_mode = Node.PROCESS_MODE_INHERIT
	my_clone.process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().paused = false

func die():
	print("Um Boss foi derrotado!")
	
	# Verifica se há mais algum Boss vivo na arena
	var remaining_bosses = 0
	var bosses = get_tree().get_nodes_in_group("boss")
	for b in bosses:
		if is_instance_valid(b) and b != self and b.current_health > 0:
			remaining_bosses += 1
			
	# Se já não houver mais Bosses vivos, acabou!
	if remaining_bosses == 0:
		print("VITÓRIA TOTAL! A arena está limpa.")
		if DDAManager.is_dda_active or DDAManager.is_dda_meteor_active:
			if DDAManager.has_method("reset_mix"):
				DDAManager.reset_mix()
	
	if audio_player.playing:
		audio_player.stop()
		
	queue_free()
