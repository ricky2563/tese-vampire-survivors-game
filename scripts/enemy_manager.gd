extends Node2D

# ========================
# CONFIGURAÇÃO
# ========================
@export var enemy_sprite: Texture2D
@export var gem_scene: PackedScene
@export var max_enemies = 1000
@export var enemy_speed = 80
@export var enemy_health = 30
@export var attack_radius = 30
@export var attack_damage = 5
@export var enemy_size = Vector2(32, 32) # Tamanho manual (ajusta no Inspector!)

# ========================
# VARIÁVEIS INTERNAS
# ========================
var enemies = []
var grid_size = 50
var grid = {}
var player = null
var multimesh_instance: MultiMeshInstance2D

# ========================
# READY
# ========================
func _ready():
	add_to_group("enemy_manager")
	player = get_tree().get_first_node_in_group("player")
	multimesh_instance = $EnemiesMesh

	# Criar MultiMesh
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D

	# QuadMesh para cada inimigo
	var quad = QuadMesh.new()
	quad.size = enemy_size
	mm.mesh = quad
	
	var mat = CanvasItemMaterial.new()
	multimesh_instance.material = mat
	multimesh_instance.texture = enemy_sprite

	# PRÉ-ALOCAÇÃO (O segredo para não piscar no spawn)
	mm.instance_count = max_enemies # Reserva a memória toda
	mm.visible_instance_count = 0   # Mas esconde-os para já
	multimesh_instance.multimesh = mm

	# Adiciona ao grupo para as balas encontrarem
	add_to_group("enemy_manager")

# ========================
# SPAWN DE INIMIGOS
# ========================
func spawn_enemy(pos: Vector2, is_boss=false):
	if enemies.size() >= max_enemies:
		return

	var enemy = {
		"position": pos,
		"velocity": Vector2.ZERO,
		"health": enemy_health,
		"speed": enemy_speed,
		"is_boss": is_boss,
		"xp_value": 100 if is_boss else 10,
		"gem_scene": gem_scene,
		"attack_cooldown": 0.0
	}
	enemies.append(enemy)
	# REMOVIDO: A atualização do MultiMesh daqui. O _process vai tratar disso em segurança!

# ========================
# SPAWN DE GEMAS
# ========================
func spawn_gem(pos: Vector2, xp_value):
	if gem_scene:
		var gem = gem_scene.instantiate()
		gem.global_position = pos
		gem.xp_amount = xp_value
		get_tree().root.call_deferred("add_child", gem)

# ========================
# PROCESSO DE MOVIMENTO E ATAQUE
# ========================
func _process(delta):
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(player):
			return

	grid.clear()

	# 1. PREENCHER A GRID
	for i in range(enemies.size()):
		var e = enemies[i]
		var cell = Vector2(floor(e.position.x / grid_size), floor(e.position.y / grid_size))
		if not grid.has(cell):
			grid[cell] = []
		grid[cell].append(i)

	# 2. LÓGICA DE MOVIMENTO E SEPARAÇÃO
	for i in range(enemies.size()):
		var e = enemies[i]
		
		# Ignora os que já morreram neste frame
		if e.health <= 0:
			continue

		# Direção para o player
		var dir_to_player = player.global_position - e.position
		if dir_to_player.length_squared() > 0:
			dir_to_player = dir_to_player.normalized()
		else:
			dir_to_player = Vector2.RIGHT # Previne NaN se estiverem em cima do player

		e.velocity = dir_to_player * e.speed

		# Separação Segura
		var separation = Vector2.ZERO
		var cell = Vector2(floor(e.position.x / grid_size), floor(e.position.y / grid_size))
		
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var neighbor_cell = cell + Vector2(dx, dy)
				if grid.has(neighbor_cell):
					for j in grid[neighbor_cell]:
						if i == j:
							continue
						
						var other = enemies[j]
						if other.health <= 0:
							continue
						
						var diff = e.position - other.position
						var dist_squared = diff.length_squared()
						
						# Proteção contra NaN (Divisão por zero) / Linhas infinitas
						if dist_squared < 0.1:
							separation += Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * 10
						elif dist_squared < 400: 
							var dist = sqrt(dist_squared)
							separation += (diff / dist) * (20 - dist)

		e.velocity += separation
		e.position += e.velocity * delta

		# Ataque ao player
		if e.position.distance_squared_to(player.global_position) < (attack_radius * attack_radius):
			if player.has_method("take_damage"):
				player.take_damage(attack_damage * delta)

	# 3. LIMPEZA SEGURA (Removemos os mortos sem estragar os índices)
	var sobreviventes = []
	for e in enemies:
		if e.health > 0:
			sobreviventes.append(e)
		else:
			spawn_gem(e.position, e.xp_value) # Larga a gema ao morrer
	
	# Substituímos a lista antiga pela nova lista limpa
	enemies = sobreviventes

	# 4. ATUALIZAÇÃO VISUAL NO MULTIMESH
	multimesh_instance.multimesh.visible_instance_count = enemies.size()
	for i in range(enemies.size()):
		var e = enemies[i]
		
		var flip_x = -1.0 if e.velocity.x < 0 else 1.0
		var flip_y = -1.0 
		
		var trans = Transform2D(
			Vector2(flip_x, 0), 
			Vector2(0, flip_y), 
			e.position          
		)
		
		multimesh_instance.multimesh.set_instance_transform_2d(i, trans)

# ========================
# FUNÇÃO DE DAR DANO A INIMIGOS (Geral)
# ========================
func damage_enemy_at_position(pos: Vector2, damage: int):
	for e in enemies:
		if e.position.distance_to(pos) < attack_radius: # attack_radius é o tamanho do hitbox
			e.health -= damage
			break # aplica dano a 1 inimigo por vez

# ========================
# FUNÇÃO DE LIMPAR TODOS INIMIGOS
# ========================
func clear_all_enemies():
	enemies.clear()
	multimesh_instance.multimesh.visible_instance_count = 0

# ========================
# COLISÃO COM BALAS
# ========================
func check_bullet_hit(bullet_pos: Vector2, hit_radius: float, damage: int) -> bool:
	var hit_confirmed = false
	var radius_squared = hit_radius * hit_radius
	
	for i in range(enemies.size() - 1, -1, -1):
		var e = enemies[i]
		
		if e.position.distance_squared_to(bullet_pos) < radius_squared:
			# Damos apenas o dano. A limpeza (Fase 3 do _process) tratará de apagá-lo!
			e.health -= damage
			hit_confirmed = true
			break 
			
	return hit_confirmed
