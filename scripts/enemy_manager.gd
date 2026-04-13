extends Node2D

# ========================
# CONFIGURAÇÃO GERAL
# ========================
@export var enemy_sprite: Texture2D
@export var gem_scene: PackedScene
@export var max_enemies = 700
@export var attack_radius = 30.0
@export var attack_damage = 5
@export var enemy_size = Vector2(32, 32)

# ========================
# CONFIGURAÇÃO DOS INIMIGOS
# ========================
@export var enemy_speed = 80.0
@export var enemy_health = 30

@export var tank_sprite: Texture2D
@export var tank_speed = 40.0    
@export var tank_health = 200

# ========================
# VARIÁVEIS INTERNAS
# ========================
var enemies = []
var grid_size = 40 
var grid = {}
var player = null
var multimesh_instance: MultiMeshInstance2D
var multimesh_instance_tanks: MultiMeshInstance2D # NOVO: O MultiMesh dos Tanks
var debug_print_timer = 0.0
var pending_xp = 0

func _ready():
	add_to_group("enemy_manager")
	player = get_tree().get_first_node_in_group("player")
	
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

	# --- NOVO: MULTIMESH DOS TANKS ---
	multimesh_instance_tanks = MultiMeshInstance2D.new()
	add_child(multimesh_instance_tanks) # Adiciona à cena automaticamente
	
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

# ========================
# SPAWN DE INIMIGOS (ATUALIZADO)
# ========================
func spawn_enemy(pos: Vector2, is_boss=false, is_tank=false):
	if enemies.size() >= max_enemies:
		return

	var enemy = {
		"position": pos,
		"health": tank_health if is_tank else enemy_health,
		"speed": tank_speed if is_tank else enemy_speed,
		"xp_value": 100 if is_boss else (30 if is_tank else 10),
		"is_tank": is_tank # NOVO: Guarda a informação se é tank
	}
	enemies.append(enemy)

func spawn_gem(pos: Vector2, xp_value: int):
	if gem_scene == null: return
	
	pending_xp += xp_value
	
	var drop_chance = 1.0 
	
	if enemies.size() > 400:
		drop_chance = 0.1 
	elif enemies.size() > 150:
		drop_chance = 0.25 
		
	if randf() < drop_chance or pending_xp >= 100:
		var gem = gem_scene.instantiate()
		gem.global_position = pos
		gem.xp_amount = pending_xp 
		if pending_xp >= 50:
			gem.scale = Vector2(1.5, 1.5)
			
		get_tree().root.call_deferred("add_child", gem)
		pending_xp = 0 

# ========================
# PROCESSO SUPER OTIMIZADO
# ========================
func _process(delta):
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(player): return

	var player_pos = player.global_position
	var attack_rad_sq = attack_radius * attack_radius

	# 1. PREENCHER A GRID 
	grid.clear()
	for e in enemies:
		var cell = Vector2(int(e.position.x / grid_size), int(e.position.y / grid_size))
		var cell_list = grid.get(cell)
		if cell_list == null:
			grid[cell] = [e] 
		else:
			cell_list.append(e)

	# NOVO: Contadores separados para os gráficos
	var normal_count = 0
	var tank_count = 0

	# 2. ITERAR INIMIGOS DE TRÁS PARA A FRENTE
	var i = enemies.size() - 1
	while i >= 0:
		var e = enemies[i]
		
		# MORTE E LIMPEZA 
		if e.health <= 0:
			spawn_gem(e.position, e.xp_value)
			enemies[i] = enemies[enemies.size() - 1]
			enemies.pop_back()
			i -= 1
			continue

		# DIREÇÃO
		var diff_to_player = player_pos - e.position
		var velocity = Vector2.ZERO
		
		if diff_to_player.length_squared() > 1.0:
			velocity = diff_to_player.normalized() * e.speed

		# SEPARAÇÃO 
		var separation = Vector2.ZERO
		var cell = Vector2(int(e.position.x / grid_size), int(e.position.y / grid_size))
		
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var neighbor_cell = cell + Vector2(dx, dy)
				var cell_list = grid.get(neighbor_cell)
				
				if cell_list != null:
					var checks = 0
					for other in cell_list: 
						if e == other: continue 
						if other.health <= 0: continue 
						
						var diff = e.position - other.position
						var dist_sq = diff.length_squared()
						
						if dist_sq > 0.1 and dist_sq < 400.0:
							var push_strength = (400.0 - dist_sq) / 40.0
							separation += diff * push_strength
							
							checks += 1
							if checks >= 4:
								break 

		velocity += separation
		e.position += velocity * delta

		# ATAQUE
		if e.position.distance_squared_to(player_pos) < attack_rad_sq:
			if player.has_method("take_damage"):
				player.take_damage(attack_damage * delta)

		# --- NOVO: ATUALIZAÇÃO VISUAL SEPARADA POR TIPO ---
		var flip_x = -1.0 if velocity.x < 0 else 1.0
		var trans = Transform2D(Vector2(flip_x, 0), Vector2(0, -1.0), e.position)
		
		if e.is_tank:
			if multimesh_instance_tanks and multimesh_instance_tanks.multimesh:
				multimesh_instance_tanks.multimesh.set_instance_transform_2d(tank_count, trans)
			tank_count += 1
		else:
			if multimesh_instance and multimesh_instance.multimesh:
				multimesh_instance.multimesh.set_instance_transform_2d(normal_count, trans)
			normal_count += 1
		
		i -= 1

	# Esconde os inimigos que não existem nas duas listas
	if multimesh_instance and multimesh_instance.multimesh:
		multimesh_instance.multimesh.visible_instance_count = normal_count
	if multimesh_instance_tanks and multimesh_instance_tanks.multimesh:
		multimesh_instance_tanks.multimesh.visible_instance_count = tank_count

	debug_print_timer += delta
	if debug_print_timer >= 1.0:
		print("Horda: ", normal_count, " | Tanks: ", tank_count, " | FPS: ", Engine.get_frames_per_second())
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
	if multimesh_instance and multimesh_instance.multimesh:
		multimesh_instance.multimesh.visible_instance_count = 0
	if multimesh_instance_tanks and multimesh_instance_tanks.multimesh:
		multimesh_instance_tanks.multimesh.visible_instance_count = 0
