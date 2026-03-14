extends Node2D

# Arrastamos a cena do inimigo para aqui no Inspector
@export var enemy_scene: PackedScene 

@export var boss_scene: PackedScene
var boss_spawned = false
var enemies_spawned = 0
var max_enemies = 200

func _on_enemy_spawner_timeout():
	if get_tree().get_nodes_in_group("enemy").size() >= max_enemies:
		return
	for i in range(5): # spawn 5 inimigos de cada vez
	
		var new_enemy = enemy_scene.instantiate()
		var player = get_tree().get_first_node_in_group("player")
		
		if player:
			var random_direction = Vector2.RIGHT.rotated(randf_range(0, TAU))
			var spawn_position = player.global_position + (random_direction * 700)
			
			new_enemy.global_position = spawn_position
			add_child(new_enemy)
		
		enemies_spawned += 5
		
		if (enemies_spawned % 150) == 0:
			print("Spawned")
			spawn_boss()
		
func spawn_boss():
	
	var boss = boss_scene.instantiate()
	var player = get_tree().get_first_node_in_group("player")
	
	if player:
		var random_direction = Vector2.RIGHT.rotated(randf_range(0, TAU))
		var spawn_position = player.global_position + (random_direction * 700)
		
		boss.global_position = spawn_position
		add_child(boss)
		
		boss_spawned = true
