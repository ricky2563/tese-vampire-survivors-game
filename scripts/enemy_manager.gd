extends Node2D

# ========================
# CONFIGURAÇÃO GERAL
# ========================
@export var enemy_sprite: Texture2D
@export var elite_sprite: Texture2D
@export var elite_mutated_sprite: Texture2D
@export var gem_scene: PackedScene
@export var max_enemies = 480
@export var max_tanks_allowed = 250
@export var attack_radius = 30.0
@export var attack_damage = 5
@export var max_attack_damage = 15.0
@export var enemy_size = Vector2(32, 32)
@export var elite_scale = 2
@export var elite_mutated_scale = 1.3

# ========================
# CONFIGURAÇÃO DOS INIMIGOS
# ========================
@export var enemy_speed = 80.0
@export var enemy_health = 30

@export var tank_sprite: Texture2D
@export var tank_speed = 40.0    
@export var tank_health = 150
@export var sprout_sprite: Texture2D
@export var sprout_scale = 1.25

var difficulty_multiplier = 1.0 # NOVO: Controla a dificuldade global

# ========================
# AUDIO DA HORDA
# ========================
@export var sound_step: AudioStream
var horde_audio_player: AudioStreamPlayer
var sound_timer = 0.0

# ========================
# VARIÁVEIS INTERNAS
# ========================
var enemies = []
var player = null
var multimesh_instance: MultiMeshInstance2D
var multimesh_instance_elites: MultiMeshInstance2D
var multimesh_instance_tanks: MultiMeshInstance2D
var multimesh_instance_sprouts: MultiMeshInstance2D
var multimesh_instance_elites_mutated: MultiMeshInstance2D
var debug_print_timer = 0.0
var pending_xp = 0
var current_tank_count = 0
var current_sprout_count = 0
var tanks_mutated = false
var elites_mutated = false
var current_elite_mutated_count = 0

var gem_container: Node2D

func _ready():
	add_to_group("enemy_manager")
	player = get_tree().get_first_node_in_group("player")
	
	gem_container = Node2D.new()
	gem_container.name = "GemContainer"
	add_child(gem_container)
	
	# --- MULTIMESH DOS INIMIGOS NORMAIS ---
	multimesh_instance = $EnemiesMesh
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	var quad = QuadMesh.new()
	quad.size = enemy_size
	mm.mesh = quad
	var mat = CanvasItemMaterial.new()
	multimesh_instance.material = mat
	multimesh_instance.texture = enemy_sprite
	mm.instance_count = max_enemies
	mm.visible_instance_count = 0
	multimesh_instance.multimesh = mm

	# --- NOVO: MULTIMESH DOS ELITES ---
	multimesh_instance_elites = MultiMeshInstance2D.new()
	add_child(multimesh_instance_elites)
	
	var mm_elite = MultiMesh.new()
	mm_elite.transform_format = MultiMesh.TRANSFORM_2D
	var quad_elite = QuadMesh.new()
	quad_elite.size = enemy_size
	mm_elite.mesh = quad_elite
	
	var mat_elite = CanvasItemMaterial.new()
	multimesh_instance_elites.material = mat_elite
	multimesh_instance_elites.texture = elite_sprite # Atribui a textura elite
	
	mm_elite.instance_count = max_enemies
	mm_elite.visible_instance_count = 0
	multimesh_instance_elites.multimesh = mm_elite

	# --- MULTIMESH DOS TANKS ---
	multimesh_instance_tanks = MultiMeshInstance2D.new()
	add_child(multimesh_instance_tanks)
	
	var mm_tank = MultiMesh.new()
	mm_tank.transform_format = MultiMesh.TRANSFORM_2D
	var quad_tank = QuadMesh.new()
	quad_tank.size = enemy_size
	mm_tank.mesh = quad_tank
	
	var mat_tank = CanvasItemMaterial.new()
	multimesh_instance_tanks.material = mat_tank
	multimesh_instance_tanks.texture = tank_sprite 
	
	mm_tank.instance_count = max_enemies
	mm_tank.visible_instance_count = 0
	multimesh_instance_tanks.multimesh = mm_tank
	
	# --- MULTIMESH DOS SPROUTS ---
	multimesh_instance_sprouts = MultiMeshInstance2D.new()
	add_child(multimesh_instance_sprouts)
	
	var mm_sprout = MultiMesh.new()
	mm_sprout.transform_format = MultiMesh.TRANSFORM_2D
	var quad_sprout = QuadMesh.new()
	quad_sprout.size = enemy_size
	mm_sprout.mesh = quad_sprout
	
	var mat_sprout = CanvasItemMaterial.new()
	multimesh_instance_sprouts.material = mat_sprout
	multimesh_instance_sprouts.texture = sprout_sprite 
	
	mm_sprout.instance_count = max_enemies
	mm_sprout.visible_instance_count = 0
	multimesh_instance_sprouts.multimesh = mm_sprout
	
	# --- MULTIMESH DOS GHOST ---
	multimesh_instance_elites_mutated = MultiMeshInstance2D.new()
	add_child(multimesh_instance_elites_mutated)
	
	var mm_elite_m = MultiMesh.new()
	mm_elite_m.transform_format = MultiMesh.TRANSFORM_2D
	var quad_elite_m = QuadMesh.new()
	quad_elite_m.size = enemy_size
	mm_elite_m.mesh = quad_elite_m
	
	var mat_elite_m = CanvasItemMaterial.new()
	multimesh_instance_elites_mutated.material = mat_elite_m
	multimesh_instance_elites_mutated.texture = elite_mutated_sprite
	
	mm_elite_m.instance_count = max_enemies
	mm_elite_m.visible_instance_count = 0
	multimesh_instance_elites_mutated.multimesh = mm_elite_m

	horde_audio_player = AudioStreamPlayer.new()
	horde_audio_player.bus = "Horde"
	horde_audio_player.max_polyphony = 16 
	add_child(horde_audio_player)

# ========================
# SPAWN DE INIMIGOS
# ========================
func spawn_enemy(pos: Vector2, is_boss=false, is_tank=false):
	if enemies.size() >= max_enemies:
		return
	
	# Garante que o limite de pesados não é ultrapassado (soma tanks e sprouts)
	if is_tank and (current_tank_count + current_sprout_count) >= max_tanks_allowed:
		is_tank = false

	var is_sprout = false
	
	# Se íamos fazer spawn de um Tank, mas já evoluímos, ele nasce como Sprout!
	if is_tank and tanks_mutated:
		is_tank = false
		is_sprout = true

	var is_elite = false
	var is_elite_mutated = false
	
	if not is_tank and not is_sprout and not is_boss:
		if difficulty_multiplier >= 1.45:
			if elites_mutated:
				is_elite_mutated = true
			else:
				is_elite = true

	# A velocidade e vida baseiam-se nas stats do Tank original
	var base_spd = tank_speed if (is_tank or is_sprout) else enemy_speed
	var actual_speed = base_spd * randf_range(0.85, 1.15)
	
	var final_health = 0.0
	
	if is_tank or is_sprout:
		var tank_multiplier = lerp(1.0, difficulty_multiplier, 0.3) 
		final_health = tank_health * tank_multiplier
	else:
		var health_multiplier = min(difficulty_multiplier, 2.0)
		final_health = enemy_health * health_multiplier
		if is_elite: 
			final_health *= 1.5 
		
	var wobble_phase = randf_range(0.0, TAU)

	var enemy = {
		"position": pos,
		"health": final_health,
		"speed": actual_speed,
		"xp_value": 100 if is_boss else (30 if (is_tank or is_sprout) else (20 if is_elite else 10)),
		"is_tank": is_tank,
		"is_sprout": is_sprout,
		"is_elite": is_elite, 
		"is_elite_mutated": is_elite_mutated,
		"wobble_phase": wobble_phase
	}
	enemies.append(enemy)

func spawn_gem(pos: Vector2, xp_value: int):
	if gem_scene == null: return
	
	pending_xp += xp_value
	var current_gems = gem_container.get_child_count()
		
	var drop_chance = 1.0 
	if enemies.size() > 400:
		drop_chance = 0.05
	elif enemies.size() > 150:
		drop_chance = 0.15 
		
	if pending_xp >= 200 or (current_gems <= 40 and randf() < drop_chance):
		var gem = gem_scene.instantiate()
		gem.global_position = pos
		
		gem.xp_amount = pending_xp 
		
		if pending_xp >= 200:
			gem.scale = Vector2(2.0, 2.0)
			gem.modulate = Color(1.0, 0.5, 0.0) # Gema VIP Laranja
		elif pending_xp >= 50:
			gem.scale = Vector2(1.5, 1.5)
			
		gem_container.call_deferred("add_child", gem)
		pending_xp = 0

# ========================
# PROCESSO EXTREMAMENTE OTIMIZADO
# ========================
func _process(delta):
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(player): return

	var player_pos = player.global_position
	var attack_rad_sq = attack_radius * attack_radius

	var normal_count = 0
	var elite_count = 0
	var elite_m_count = 0
	var tank_count = 0
	var sprout_count = 0
	
	var trans := Transform2D()
	trans.y = Vector2(0, -1.0) 

	var i = enemies.size() - 1
	while i >= 0:
		var e = enemies[i]
		
		if e.health <= 0:
			spawn_gem(e.position, e.xp_value)
			enemies[i] = enemies[enemies.size() - 1]
			enemies.pop_back()
			i -= 1
			continue

		var diff_to_player = player_pos - e.position
		var velocity = Vector2.ZERO
		var dist_sq = diff_to_player.length_squared()
		
		if dist_sq > 1.0:
			var dist = sqrt(dist_sq)
			var dir_to_player = diff_to_player / dist
			
			var wobble = Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
			velocity = (dir_to_player + wobble) * e.speed

		e.position += velocity * delta

		if dist_sq < attack_rad_sq:
			if player.has_method("take_damage"):
				var scaled_damage = attack_damage * difficulty_multiplier
				scaled_damage = min(scaled_damage, max_attack_damage)
				
				var enemy_type = "Horda (Normal)"
				if e.is_elite or e.get("is_elite_mutated", false): 
					enemy_type = "Horda (Elite)"
				elif e.is_tank: 
					enemy_type = "Horda (Tank)"
				elif e.is_sprout:
					enemy_type = "Horda (Sprout)"
				player.take_damage(scaled_damage * delta, enemy_type)

		var scale_factor = 1.0
		if e.is_elite:
			scale_factor = elite_scale
		elif e.get("is_elite_mutated", false):
			scale_factor = elite_mutated_scale
		elif e.is_sprout:
			scale_factor = sprout_scale # Usa o teu novo tamanho configurável!

		var flip_x = -scale_factor if diff_to_player.x < 0 else scale_factor
		trans.x = Vector2(flip_x, 0)
		trans.y = Vector2(0, -scale_factor)
		trans.origin = e.position
		
		if e.is_tank:
			if multimesh_instance_tanks and multimesh_instance_tanks.multimesh:
				multimesh_instance_tanks.multimesh.set_instance_transform_2d(tank_count, trans)
			tank_count += 1
		elif e.is_sprout:
			if multimesh_instance_sprouts and multimesh_instance_sprouts.multimesh:
				multimesh_instance_sprouts.multimesh.set_instance_transform_2d(sprout_count, trans)
			sprout_count += 1
		elif e.get("is_elite_mutated", false): # NOVO MULTIMESH
			if multimesh_instance_elites_mutated and multimesh_instance_elites_mutated.multimesh:
				multimesh_instance_elites_mutated.multimesh.set_instance_transform_2d(elite_m_count, trans)
			elite_m_count += 1
		elif e.is_elite:
			if multimesh_instance_elites and multimesh_instance_elites.multimesh:
				multimesh_instance_elites.multimesh.set_instance_transform_2d(elite_count, trans)
			elite_count += 1
		else:
			if multimesh_instance and multimesh_instance.multimesh:
				multimesh_instance.multimesh.set_instance_transform_2d(normal_count, trans)
			normal_count += 1
		
		i -= 1

	if multimesh_instance and multimesh_instance.multimesh:
		multimesh_instance.multimesh.visible_instance_count = normal_count
	if multimesh_instance_elites and multimesh_instance_elites.multimesh:
		multimesh_instance_elites.multimesh.visible_instance_count = elite_count
	if multimesh_instance_elites_mutated and multimesh_instance_elites_mutated.multimesh:
		multimesh_instance_elites_mutated.multimesh.visible_instance_count = elite_m_count
	if multimesh_instance_tanks and multimesh_instance_tanks.multimesh:
		multimesh_instance_tanks.multimesh.visible_instance_count = tank_count
	if multimesh_instance_sprouts and multimesh_instance_sprouts.multimesh:
		multimesh_instance_sprouts.multimesh.visible_instance_count = sprout_count
		
	current_tank_count = tank_count
	current_sprout_count = sprout_count
	current_elite_mutated_count = elite_m_count
	
	var total_enemies = enemies.size()
	
	if total_enemies > 0 and sound_step:
		var chaos_factor = min(total_enemies / 150.0, 1.0)
		var play_interval = lerp(0.6, 0.3, chaos_factor)
		var volume_db = lerp(-25.0, -8.0, chaos_factor)
		
		horde_audio_player.volume_db = volume_db
		
		sound_timer += delta
		if sound_timer >= play_interval:
			horde_audio_player.stream = sound_step
			horde_audio_player.pitch_scale = randf_range(0.7, 1.4) 
			horde_audio_player.play()
			sound_timer = randf_range(-0.05, 0.05)

	debug_print_timer += delta
	if debug_print_timer >= 1.0:
		print("Horda: ", normal_count, " | Elites: ", elite_count, " | Tanks: ", tank_count, " | Sprouts: ", sprout_count, " | FPS: ", Engine.get_frames_per_second())
		debug_print_timer = 0.0

# ========================
# FUNÇÕES EXTRAS
# ========================
func damage_enemy_at_position(pos: Vector2, damage: int):
	var attack_rad_sq = attack_radius * attack_radius
	for e in enemies:
		if e.position.distance_squared_to(pos) < attack_rad_sq:
			e.health -= damage
			break 

func check_bullet_hit(bullet_pos: Vector2, hit_radius: float, damage: int) -> bool:
	var hit_confirmed = false
	var radius_squared = hit_radius * hit_radius
	
	for i in range(enemies.size() - 1, -1, -1):
		var e = enemies[i]
		if e.position.distance_squared_to(bullet_pos) < radius_squared:
			e.health -= damage
			hit_confirmed = true
			break 
			
	return hit_confirmed
	
func clear_all_enemies():
	enemies.clear()
	pending_xp = 0
	difficulty_multiplier = 1.0
	tanks_mutated = false
	elites_mutated = false
	current_elite_mutated_count = 0
	if multimesh_instance_elites_mutated and multimesh_instance_elites_mutated.multimesh:
		multimesh_instance_elites_mutated.multimesh.visible_instance_count = 0
	if multimesh_instance and multimesh_instance.multimesh:
		multimesh_instance.multimesh.visible_instance_count = 0
	if multimesh_instance_elites and multimesh_instance_elites.multimesh:
		multimesh_instance_elites.multimesh.visible_instance_count = 0
	if multimesh_instance_tanks and multimesh_instance_tanks.multimesh:
		multimesh_instance_tanks.multimesh.visible_instance_count = 0
	current_sprout_count = 0
	if multimesh_instance_sprouts and multimesh_instance_sprouts.multimesh:
		multimesh_instance_sprouts.multimesh.visible_instance_count = 0
	if is_instance_valid(gem_container):
		for gem in gem_container.get_children():
			gem.queue_free()


func evolve_tanks():
	if not tanks_mutated:
		tanks_mutated = true
		
func evolve_elites():
	if not elites_mutated:
		elites_mutated = true
