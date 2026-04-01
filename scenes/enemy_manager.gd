extends Node2D

# ========================
# CONFIGURAÇÃO
# ========================
@export var enemy_sprite: Texture2D
@export var gem_scene: PackedScene
@export var max_enemies = 500
@export var enemy_speed = 80
@export var enemy_health = 30
@export var attack_radius = 30
@export var attack_damage = 5
@export var enemy_size = Vector2(32,32) # Tamanho do inimigo no MultiMesh

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

	mm.instance_count = 0
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
	multimesh_instance.multimesh.instance_count = enemies.size()

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
	if not player:
		return

	grid.clear()

	# Preenche grid
	for i in range(enemies.size()):
		var e = enemies[i]
		var cell = Vector2(floor(e.position.x / grid_size), floor(e.position.y / grid_size))
		if not grid.has(cell):
			grid[cell] = []
		grid[cell].append(i)

	# Atualiza inimigos de trás para frente para evitar erros ao remover
	for i in range(enemies.size() - 1, -1, -1):
		var e = enemies[i]

		# Movimento em direção ao player
		var dir = (player.global_position - e.position).normalized()
		e.velocity = dir * e.speed

		# Separação usando grid
		var separation = Vector2.ZERO
		var cell = Vector2(floor(e.position.x / grid_size), floor(e.position.y / grid_size))
		for dx in range(-1, 2):  # -1,0,1
			for dy in range(-1, 2):
				var neighbor_cell = cell + Vector2(dx, dy)
				if grid.has(neighbor_cell):
					for j in grid[neighbor_cell]:
						if i == j:
							continue
						var other = enemies[j]
						var dist = e.position.distance_to(other.position)
						if dist < 20:
							separation -= (other.position - e.position).normalized() * (20 - dist)
		e.velocity += separation
		e.position += e.velocity * delta

		# Ataque ao player
		if e.position.distance_to(player.global_position) < attack_radius:
			if player.has_method("take_damage"):
				player.take_damage(attack_damage * delta)

		# Atualiza MultiMesh
		multimesh_instance.multimesh.set_instance_transform_2d(i, Transform2D(0, e.position))

		# Remove inimigo se morreu
		if e.health <= 0:
			spawn_gem(e.position, e.xp_value)
			enemies.remove_at(i)
			multimesh_instance.multimesh.instance_count = enemies.size()

# ========================
# FUNÇÃO DE DAR DANO A INIMIGOS
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
	multimesh_instance.multimesh.instance_count = 0
	
