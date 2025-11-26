extends Node2D

# Arrastamos a cena do inimigo para aqui no Inspector
@export var enemy_scene: PackedScene 

func _on_enemy_spawner_timeout():
	# 1. Cria o inimigo
	var new_enemy = enemy_scene.instantiate()
	
	# 2. Encontra o Player para saber onde o criar
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# 3. Matemática para escolher um ponto aleatório à volta do player
		# Cria um vetor aleatório e afasta-o 400 pixels (fora do ecrã)
		var random_direction = Vector2.RIGHT.rotated(randf_range(0, TAU))
		var spawn_position = player.global_position + (random_direction * 400)
		
		new_enemy.global_position = spawn_position
		
		# 4. Adiciona o inimigo ao mundo
		add_child(new_enemy)
