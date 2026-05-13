extends CharacterBody2D

@export var speed = 40
@export var max_health = 170000
@export var player: Node2D
@export var fire_hand_scene: PackedScene
@export var meteor_scene: PackedScene
@export var sound_fireball_cast: AudioStream
@export var sound_ring_warning: AudioStream
@export var sound_hand_cast: AudioStream 
@export var sound_stop_warning: AudioStream
@export var sound_stop_snap: AudioStream
@export var sound_nova_warning: AudioStream
@export var fire_ring_scene: PackedScene
@export var phase_4_texture: Texture2D

@onready var attack_timer = $AttackTimer
@onready var audio_player = $AttackSound
@onready var stop_anim = $stop_attack
@onready var speech_bubble = $SpeechBubble
@onready var speech_label = $SpeechBubble/Label
@onready var screen_notifier = $VisibleOnScreenNotifier2D
@onready var pointer = $IndicatorLayer/Pointer

var is_attacking = false
var attack_deck = []
var last_attack = ""
var current_health = 0
var original_speed = 0

# --- VARIÁVEIS DA FASE 2 A 4 ---
var is_clone = false
var current_phase = 1
var is_invulnerable = false
var my_clone = null
var my_partner = null

func _ready():
	player = get_tree().get_first_node_in_group("player")
	add_to_group("boss")
	original_speed = speed
	
	if not is_clone:
		current_health = max_health
		attack_timer.start()
	
	if stop_anim:
		stop_anim.visible = false
	if pointer:
		pointer.visible = false

func _physics_process(delta):
	if player:
		if not is_invulnerable:
			var target_pos = player.global_position
			
			# LÓGICA DA FASE 3 (FLANQUEAMENTO / PINÇA)
			if current_phase == 3:
				var offset_x = 250 if is_clone else -250
				var offset_y = sin(Time.get_ticks_msec() / 400.0) * 150
				target_pos = player.global_position + Vector2(offset_x, offset_y)
				
			var direction = global_position.direction_to(target_pos)
			velocity = direction * speed
			move_and_slide()
		update_offscreen_pointer()

func _on_attack_timer_timeout():
	if is_clone or (current_phase == 2 and is_invulnerable):
		return
		
	var clone_is_busy = is_instance_valid(my_clone) and my_clone.is_attacking
	
	if is_attacking or clone_is_busy:
		return
		
	pick_and_execute_attack()
	
	if is_instance_valid(my_clone):
		my_clone.pick_and_execute_attack()

func pick_and_execute_attack():
	if attack_deck.is_empty():
		if current_phase == 4: refill_deck_phase_4()
		elif current_phase >= 2: refill_deck_phase_2()
		else: refill_deck()
		
	var next_attack = attack_deck.pop_back()
	if next_attack == last_attack and attack_deck.size() > 0:
		attack_deck.insert(0, next_attack)
		next_attack = attack_deck.pop_back()
	last_attack = next_attack
	
	match next_attack:
		"hand": fire_hand_attack()
		"meteor": meteor_rain_attack()
		"stop": stop_curse_attack()
		"ring": fire_ring_attack()
		"nova": fire_nova_attack() # NOVO ATAQUE DA FASE 4
			
func refill_deck():
	attack_deck.clear()
	for i in range(3): attack_deck.append("hand")   
	for i in range(3): attack_deck.append("meteor") 
	for i in range(1): attack_deck.append("stop")   
	for i in range(1): attack_deck.append("ring")   
	attack_deck.shuffle()
	print("BOSS: Novo baralho de ataques gerado (Fase 1)!")

func refill_deck_phase_2(): # Fase 2 e 3 (sem Stop)
	attack_deck.clear()
	for i in range(5): attack_deck.append("hand")
	for i in range(5): attack_deck.append("meteor") 
	for i in range(1): attack_deck.append("ring")   
	attack_deck.shuffle()
	print("BOSS: Baralho da Fase 2/3 gerado (Sem Stop)!")

func refill_deck_phase_4(): # Fase 4 (Nova e Stop)
	attack_deck.clear()
	for i in range(3): attack_deck.append("hand")
	for i in range(3): attack_deck.append("meteor") 
	for i in range(1): attack_deck.append("ring")
	for i in range(3): attack_deck.append("nova")
	attack_deck.shuffle()
	print("BOSS: Baralho da Fase 4 (Vingança) gerado!")

# ==========================================
# ATAQUES 
# ==========================================
func fire_hand_attack():
	if not player: return
	if fire_hand_scene == null: return
	is_attacking = true
	
	if DDAManager.has_method("start_attack"):
		DDAManager.start_attack("Boss: Hand Attack")
	
	if DDAManager.is_dda_active: DDAManager.trigger_threat_focus("Boss: Hand Attack", 0.5)
	
	if sound_hand_cast:
		audio_player.bus = "Attack_Hand"
		audio_player.volume_db = 0.0
		audio_player.stream = sound_hand_cast
		audio_player.play()
	
	var attack = fire_hand_scene.instantiate()
	var offset = Vector2(randf_range(-50,50), randf_range(-50,50))
	attack.global_position = player.global_position + offset
	get_tree().current_scene.add_child(attack)
	
	await get_tree().create_timer(2.5, false).timeout
	is_attacking = false
	
	if DDAManager.has_method("end_attack"):
		DDAManager.end_attack("Boss: Hand Attack")

func meteor_rain_attack():
	if not player: return
	is_attacking = true 
	var meteor_count = 12 
	
	if DDAManager.has_method("start_attack"):
		DDAManager.start_attack("Boss: Meteor Attack")
	
	if DDAManager.is_dda_active: DDAManager.trigger_threat_focus("Boss: Meteor Attack", 1.5)
	
	audio_player.bus = "Attack_Meteor" 
	audio_player.volume_db = 6.0
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
	
	if DDAManager.has_method("end_attack"):
		DDAManager.end_attack("Boss: Meteor Attack")

func spawn_meteor(pos):
	var meteor = meteor_scene.instantiate()
	meteor.target_position = pos
	if "is_phase_4" in meteor:
		meteor.is_phase_4 = (current_phase == 4)
	get_tree().current_scene.add_child(meteor)
	
func fire_ring_attack():
	if not player: return
	is_attacking = true

	if DDAManager.has_method("start_attack"):
		DDAManager.start_attack("Boss: Ring Attack")

	var temp_speed = speed # Evita conflitos com a speed original na Fase 4
	speed = 0 
	
	var duration = 4.5 if current_phase >= 2 else 7.0
	
	if DDAManager.is_dda_active: DDAManager.trigger_threat_focus("Boss: Ring Attack", duration)
	
	if sound_ring_warning:
		audio_player.bus = "Attack_Ring"
		audio_player.volume_db = 0.0
		audio_player.stream = sound_ring_warning
		audio_player.play(0.0) 
	
	var timer = 0.0
	while timer < duration:
		if not is_inside_tree():
			return
		
		if get_tree().paused:
			await get_tree().process_frame
			continue
	
		var tremor_forca = 4 if current_phase >= 2 else 2
		global_position += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (timer * tremor_forca)
		
		await get_tree().process_frame
		timer += get_process_delta_time()
		
		if timer >= duration:
			audio_player.stop()
			break

	if not is_inside_tree(): return

	if fire_ring_scene:
		var ring = fire_ring_scene.instantiate()
		ring.global_position = global_position
		
		if current_phase >= 2:
			ring.scale = Vector2(0.5, 0.5)
		elif current_phase == 4:
			ring.scale = Vector2(1.0, 1.0)
		get_tree().current_scene.add_child(ring)
		
	print("Anel de Fogo disparado após ", duration, "s de carga!")
	
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree(): return
	
	speed = temp_speed
	is_attacking = false
	
	if DDAManager.has_method("end_attack"):
		DDAManager.end_attack("Boss: Ring Attack")
	
func stop_curse_attack():
	if current_phase == 2 or current_phase == 3:
		is_attacking = false
		return

	if not player: return
	is_attacking = true
	var temp_speed = speed
	speed = 0
	
	if DDAManager.has_method("start_attack"):
		DDAManager.start_attack("Boss: Stop Attack")
	
	var telegraph_time = 1.2
	var check_time = 0.3
	
	if DDAManager.is_dda_active: DDAManager.trigger_threat_focus("Boss: Stop Attack", telegraph_time + check_time)
		
	if sound_stop_warning:
		audio_player.bus = "Attack_Stop"
		audio_player.volume_db = 0.0
		audio_player.stream = sound_stop_warning
		audio_player.play()
	
	if has_node("Sprite2D"): $Sprite2D.visible = false
	if stop_anim:
		stop_anim.visible = true
		stop_anim.frame = 0 
		stop_anim.play("stop_attack")
	
	await get_tree().create_timer(telegraph_time, false).timeout
	
	if not is_inside_tree(): return
	if (current_phase == 2 or current_phase == 3) and not is_clone:
		is_attacking = false
		return
	
	audio_player.stop() 
	if sound_stop_snap:
		audio_player.stream = sound_stop_snap
		audio_player.play()
	
	var player_moved = false
	var timer = 0.0
	
	while timer < check_time:
		if not is_inside_tree(): return 
		
		if "velocity" in player and player.velocity.length() > 5.0:
			player_moved = true
		timer += get_process_delta_time()
		await get_tree().process_frame
		
	if not is_inside_tree(): return 
		
	if stop_anim:
		stop_anim.visible = false
		stop_anim.stop()
	if has_node("Sprite2D"): $Sprite2D.visible = true
		
	if player_moved:
		if player.has_method("take_damage"): player.take_damage(30, "Boss: Stop Attack")
		if speech_bubble and speech_label:
			var taunts = ["I SAID STOP!", "BE STILL!", "MOVEMENT DETECTED!", "YOU DARE MOVE?", "RUNNING KILLS YOU FASTER!"]
			speech_label.text = taunts.pick_random()
			speech_bubble.visible = true
			get_tree().create_timer(2.0, false).timeout.connect(func(): speech_bubble.visible = false)
		
	await get_tree().create_timer(0.5, false).timeout
	if not is_inside_tree(): return 
	
	speed = temp_speed
	is_attacking = false
	
	if DDAManager.has_method("end_attack"):
		DDAManager.end_attack("Boss: Stop Attack")

func fire_nova_attack():
	if not player or fire_hand_scene == null: return
	is_attacking = true
	
	if DDAManager.has_method("start_attack"): DDAManager.start_attack("Boss: Nova Attack")
	if DDAManager.is_dda_active: DDAManager.trigger_threat_focus("Boss: Nova Attack", 2.0)
	
	var temp_speed = speed
	speed = speed * 0.2 
	
	await get_tree().create_timer(1.0, false).timeout
	if not is_inside_tree(): return
	
	var num_hands = 24        
	var radius_step = 25      
	var angle_step = PI / 4.0 
	
	for i in range(num_hands):
		if not is_inside_tree(): return
		if get_tree().paused:
			await get_tree().process_frame
			continue
			
		var radius = 60 + (i * radius_step)
		var angle = i * angle_step
		var pos = global_position + Vector2(cos(angle), sin(angle)) * radius
		
		var attack = fire_hand_scene.instantiate()
		attack.global_position = pos
		if "is_tracking" in attack:
			attack.is_tracking = false
		if "is_nova" in attack:
			attack.is_nova = true

		if i == 0 or i == 8 or i == 16:
			var pitch = 0.85
			if i == 8: pitch = 1.0
			if i == 16: pitch = 1.15
			
			play_delayed_tum(pitch, attack.track_duration)
		# ==========================================
		
		get_tree().current_scene.add_child(attack)
		
		await get_tree().create_timer(0.06, false).timeout
		
	speed = temp_speed
	is_attacking = false
	
	# Repõe o som normal para os próximos ataques
	if sound_nova_warning:
		audio_player.pitch_scale = 1.0 
		
	if DDAManager.has_method("end_attack"): DDAManager.end_attack("Boss: Nova Attack")


# ==========================================
func play_delayed_tum(pitch_val: float, delay: float):
	await get_tree().create_timer(delay, false).timeout
	
	if not is_inside_tree() or not sound_nova_warning: return
	
	audio_player.bus = "Attack_Nova"
	audio_player.stream = sound_nova_warning
	audio_player.pitch_scale = pitch_val
	audio_player.play(0.0)
	
# ==========================================
# SISTEMA DE DANO E MUDANÇAS DE FASE
# ==========================================
func take_damage(amount):
	if is_invulnerable:
		return
		
	current_health -= amount
	
	modulate = Color(1.0, 0.3, 0.3)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	
	if current_health <= (max_health * 0.60) and current_phase == 1 and not is_clone:
		enter_phase_2()
		
	elif current_health <= (max_health * 0.40) and current_phase == 2 and not is_clone:
		enter_phase_3()
	
	if current_health <= 0:
		die()

func enter_phase_2():
	current_phase = 2
	is_invulnerable = true
	is_attacking = true
	var temp_speed = speed
	speed = 0
	
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	
	if is_instance_valid(player) and player.has_method("record_event"):
		player.record_event("BOSS: INÍCIO FASE 2")
	
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
	
	var cam_tween = create_tween().set_parallel(true)
	cam_tween.tween_property(cutscene_cam, "zoom", Vector2(1.8, 1.8), 1.5).set_trans(Tween.TRANS_SINE)
	cam_tween.tween_property(dark_bg, "color:a", 0.85, 1.5) 
	modulate = Color(2.0, 1.0, 1.0) 
	await cam_tween.finished
	
	var original_pos = global_position
	var shake_tween = create_tween()
	for i in range(30):
		var random_offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
		shake_tween.tween_property(self, "global_position", original_pos + random_offset, 0.05)
	shake_tween.tween_property(self, "global_position", original_pos, 0.05)
	await shake_tween.finished
	
	var clone_scene = load(scene_file_path) 
	my_clone = clone_scene.instantiate() 
	
	my_clone.is_clone = true
	my_clone.current_phase = 2
	my_clone.is_invulnerable = true
	my_clone.is_attacking = true    
	my_clone.global_position = self.global_position
	my_clone.current_health = self.current_health 
	my_clone.process_mode = Node.PROCESS_MODE_ALWAYS
	my_clone.z_index = 99 
	my_clone.z_as_relative = false
	my_clone.modulate = Color(2.0, 1.0, 1.0, 0.0) 
	
	get_tree().current_scene.add_child(my_clone)
	
	self.my_partner = my_clone
	my_clone.my_partner = self
	
	var sep_tween = create_tween().set_parallel(true)
	sep_tween.tween_property(my_clone, "modulate:a", 1.0, 1.5)
	sep_tween.tween_property(self, "global_position", original_pos + Vector2(-80, 0), 2.0).set_trans(Tween.TRANS_CUBIC)
	sep_tween.tween_property(my_clone, "global_position", original_pos + Vector2(80, 0), 2.0).set_trans(Tween.TRANS_CUBIC)
	await sep_tween.finished
	
	var cam_back = create_tween().set_parallel(true)
	cam_back.tween_property(cutscene_cam, "zoom", Vector2(1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE)
	cam_back.tween_property(dark_bg, "color:a", 0.0, 1.0)
	cam_back.tween_property(self, "modulate", Color.WHITE, 1.0)
	cam_back.tween_property(my_clone, "modulate", Color.WHITE, 1.0)
	await cam_back.finished
	
	cutscene_cam.queue_free()
	z_index = original_z
	z_as_relative = original_z_rel
	my_clone.z_index = original_z
	my_clone.z_as_relative = original_z_rel
	
	if has_node("CollisionShape2D"): $CollisionShape2D.set_deferred("disabled", false)
	if my_clone.has_node("CollisionShape2D"): my_clone.get_node("CollisionShape2D").set_deferred("disabled", false)
	
	speed = temp_speed + 15
	my_clone.speed = speed
	
	self.is_invulnerable = false
	self.is_attacking = false
	my_clone.is_invulnerable = false
	my_clone.is_attacking = false
	
	self.process_mode = Node.PROCESS_MODE_INHERIT
	my_clone.process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().paused = false

func enter_phase_3():
	current_phase = 3
	
	if is_instance_valid(player) and player.has_method("record_event"):
		player.record_event("BOSS: INÍCIO FASE 3")
	
	if is_instance_valid(my_clone):
		my_clone.current_phase = 3
		
	if speech_bubble and speech_label:
		speech_label.text = "FLANK HIM!"
		speech_bubble.visible = true
		get_tree().create_timer(2.0, false).timeout.connect(func(): speech_bubble.visible = false)
		
	print("BOSS FASE 3: Tática de Pinça Ativada!")

func enter_phase_4():
	current_phase = 4
	is_invulnerable = true
	is_attacking = true 
	speed = 0
	
	if is_instance_valid(player) and player.has_method("record_event"):
		player.record_event("BOSS: INÍCIO FASE 4")
	
	print("BOSS FASE 4: MODO VINGANÇA!")
	
	if speech_bubble and speech_label:
		speech_label.text = "I WILL BURN YOU FOR THAT!"
		speech_bubble.visible = true
		get_tree().create_timer(3.0, false).timeout.connect(func(): speech_bubble.visible = false)

	var flash_tween = create_tween()
	flash_tween.tween_property(self, "modulate", Color(5.0, 5.0, 5.0), 0.5) 
	
	await flash_tween.finished
	if not is_inside_tree(): return
	
	if has_node("Sprite2D") and phase_4_texture != null:
		$Sprite2D.texture = phase_4_texture
		
	var restore_tween = create_tween()
	restore_tween.tween_property(self, "modulate", Color.WHITE, 0.5) 
	
	await restore_tween.finished
	if not is_inside_tree(): return
	
	current_health = max_health * 0.30
	speed = original_speed * 2 
	is_invulnerable = false
	is_attacking = false
	
	refill_deck_phase_4()
	if not is_clone: attack_timer.start()

func die():
	if is_instance_valid(my_partner) and my_partner.current_health > 0 and my_partner.current_phase != 4:
		my_partner.enter_phase_4()
		if not is_clone:
			my_partner.is_clone = false
			my_partner.attack_timer.start()

	print("Um Boss foi derrotado!")
	
	var remaining_bosses = 0
	var bosses = get_tree().get_nodes_in_group("boss")
	for b in bosses:
		if is_instance_valid(b) and b != self and b.current_health > 0:
			remaining_bosses += 1
			
	if remaining_bosses == 0:
		print("VITÓRIA TOTAL! A arena está limpa.")
		if DDAManager.is_dda_active or DDAManager.is_dda_meteor_active:
			if DDAManager.has_method("reset_mix"):
				DDAManager.reset_mix()
	
	if audio_player.playing:
		audio_player.stop()
		
	queue_free()
	
func update_offscreen_pointer():
	if not pointer or not screen_notifier: return
	
	# Se o Boss está visível na câmara do jogador, esconde a seta
	if screen_notifier.is_on_screen():
		pointer.visible = false
		return
		
	pointer.visible = true
	
	var viewport_rect = get_viewport_rect()
	var screen_center = viewport_rect.size / 2.0
	
	var boss_screen_pos = get_global_transform_with_canvas().origin
	
	# Roda a seta para apontar para o Boss
	var direction = (boss_screen_pos - screen_center).normalized()
	pointer.rotation = direction.angle()
	
	# Prende a seta às bordas do ecrã (margin de 40 pixeis)
	var padding = 40.0
	var clamped_pos = boss_screen_pos
	clamped_pos.x = clamp(clamped_pos.x, padding, viewport_rect.size.x - padding)
	clamped_pos.y = clamp(clamped_pos.y, padding, viewport_rect.size.y - padding)
	
	pointer.position = clamped_pos
