extends Node2D

# ========================
# MODOS DE SPAWN
# ========================
enum SpawnMode {
	CONTINUOUS,
	HORDE,
	WAVES_WITH_BOSS,
	LINE_HORDE
}

@export var spawn_mode: SpawnMode = SpawnMode.CONTINUOUS

# ========================
# SCENES
# ========================
@export var enemy_scene: PackedScene
@export var boss_scene: PackedScene
@export var boss_scene_fire: PackedScene

# ========================
# CONTROLO
# ========================
var max_enemies = 100
var enemies_spawned = 0

# ========================
# MAIN SPAWNER
# ========================
func _on_enemy_spawner_timeout():
	if get_tree().get_nodes_in_group("enemy").size() >= max_enemies:
		return
	
	match spawn_mode:
		SpawnMode.CONTINUOUS:
			spawn_continuous()
		SpawnMode.HORDE:
			spawn_horde()
		SpawnMode.WAVES_WITH_BOSS:
			spawn_wave_with_boss()
		SpawnMode.LINE_HORDE:
			spawn_line_horde()

# ========================
# SCENARIO 1 — CONTÍNUO
# ========================
func spawn_continuous():
	for i in range(5):
		spawn_enemy_around_player(700)
		enemies_spawned += 5
	
	# Boss aparece de X em X inimigos
	if enemies_spawned % 150 == 0:
		spawn_boss()

# ========================
# SCENARIO 2 — HORDA
# ========================
func spawn_horde():
	var player = get_player()
	if not player:
		return
	
	var base_direction = Vector2.RIGHT.rotated(randf_range(0, TAU))
	var base_position = player.global_position + (base_direction * 500)
	
	for i in range(20):
		var offset = Vector2(randf_range(-30,30), randf_range(-30,30))
		spawn_enemy_at(base_position + offset)

# ========================
# SCENARIO 3 — WAVES + BOSS
# ========================
func spawn_wave_with_boss():
	var player = get_player()
	if not player:
		return
	
	var base_direction = Vector2.RIGHT.rotated(randf_range(0, TAU))
	var base_position = player.global_position + (base_direction * 600)
	
	# Spawn inimigos em grupo
	for i in range(20):
		var offset = Vector2(randf_range(-40,40), randf_range(-40,40))
		spawn_enemy_at(base_position + offset)
	
	# 50% chance de boss no meio
	if randf() < 0.5:
		var boss = boss_scene.instantiate()
		boss.global_position = base_position
		add_child(boss)
		
# ========================
# SCENARIO 4 — Horda Linha
# ========================
func spawn_line_horde():
	var player = get_player()
	if not player:
		return
	
	# Base vertical aleatória em torno do jogador
	var base_direction = Vector2.RIGHT.rotated(randf_range(0, TAU))
	var base_position = player.global_position + (base_direction * 500)
	
	var group_size = 10      # número de inimigos no grupo
	var vertical_spacing = 30
	var horizontal_spread = 20
	
	var boss_index = randi() % group_size  # sorteia quem será o boss
	
	for i in range(group_size):
		# offset vertical + horizontal aleatório
		var offset = Vector2(randf_range(-horizontal_spread, horizontal_spread),
							 i * vertical_spacing - (group_size*vertical_spacing/2))
		
		if i == boss_index:
			# Spawn do boss no meio do grupo
			var boss = boss_scene.instantiate()
			boss.global_position = base_position + offset
			add_child(boss)
		else:
			# Spawn de inimigo normal
			spawn_enemy_at(base_position + offset)

# ========================
# SPAWN BOSS (GENÉRICO)
# ========================
func spawn_boss():
	var player = get_player()
	if not player:
		return
	
	var boss = boss_scene.instantiate()
	
	var random_direction = Vector2.RIGHT.rotated(randf_range(0, TAU))
	var spawn_position = player.global_position + (random_direction * 700)
	
	boss.global_position = spawn_position
	add_child(boss)

# ========================
# SPAWN BOSS (Fire)
# ========================
func spawn_boss_fire():
	var player = get_player()
	if not player:
		return
	
	if boss_scene_fire == null:
		print("Boss fire não atribuído!")
		return
	
	var boss = boss_scene_fire.instantiate()
	
	# spawn perto do player (para veres bem)
	var offset = Vector2(150, 0)
	boss.global_position = player.global_position + offset
	
	add_child(boss)

# ========================
# HELPERS
# ========================
func get_player():
	return get_tree().get_first_node_in_group("player")

func spawn_enemy_around_player(distance):
	var player = get_player()
	if not player:
		return
	
	var dir = Vector2.RIGHT.rotated(randf_range(0, TAU))
	var pos = player.global_position + (dir * distance)
	
	spawn_enemy_at(pos)

func spawn_enemy_at(pos):
	var enemy = enemy_scene.instantiate()
	enemy.global_position = pos
	add_child(enemy)

# ========================
# DEBUG CONTROLS (OPCIONAL)
# ========================
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				spawn_mode = SpawnMode.CONTINUOUS
				print("Modo: CONTINUOUS")
			KEY_2:
				spawn_mode = SpawnMode.HORDE
				print("Modo: HORDE")
			KEY_3:
				spawn_mode = SpawnMode.WAVES_WITH_BOSS
				print("Modo: WAVES WITH BOSS")
			KEY_4:
				spawn_mode = SpawnMode.LINE_HORDE
				print("Modo: HORDE LINE")
			KEY_N:
				spawn_boss_fire()
				print("Boss FIRE spawnado")
			KEY_SPACE:   # <--- tecla espaço
				clear_enemies()
		update_label()

func update_label():
	$CanvasLayer/Label.text = ["CONTINUOUS", "HORDE", "WAVES", "LINE"][spawn_mode]
	
func clear_enemies():
	# Pega todos os inimigos ativos
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		enemy.queue_free()
		
	# Opcional: também limpa bosses se quiser
	var bosses = get_tree().get_nodes_in_group("boss")
	for boss in bosses:
		boss.queue_free()
	
	enemies_spawned = 0
	print("Tela limpa! " + str(enemies.size()) + " inimigos removidos")
