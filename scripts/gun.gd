extends Area2D

@export var bullet_scene: PackedScene # Vamos arrastar a bala para aqui
@onready var shooting_point = $ShootingPoint
@onready var timer = $Timer

func _ready():
	timer.wait_time = 1 # Dispara a cada meio segundo
	timer.start()

func _physics_process(delta):
	# 1. Encontrar todos os inimigos dentro do círculo (CollisionShape)
	var enemies_in_range = get_overlapping_bodies()
	
	if enemies_in_range.size() > 0:
		var target_enemy = null
		var shortest_distance = INF # Começa com infinito
		
		# 2. Loop para descobrir qual está mais perto
		for enemy in enemies_in_range:
			# Verifica se é mesmo um inimigo (para não apontar para paredes ou outras coisas)
			if enemy.is_in_group("enemy"): # 
				var current_distance = global_position.distance_to(enemy.global_position)
				if current_distance < shortest_distance:
					shortest_distance = current_distance
					target_enemy = enemy
		
		# 3. Apontar a arma
		if target_enemy:
			look_at(target_enemy.global_position)

func _on_timer_timeout():
	shoot()

func shoot():
	# Verifica se há inimigos antes de tentar disparar
	var enemies = get_overlapping_bodies()
	if enemies.size() > 0:
		var new_bullet = bullet_scene.instantiate()
		
		# O SEGREDO ESTÁ AQUI:
		# 1. Adicionar primeiro ao "Root" (o topo do mundo), ignorando o Player
		get_tree().root.add_child(new_bullet)
		
		# 2. Definir a posição DEPOIS de adicionar ao mundo
		# Assim garantimos que ele usa as coordenadas globais reais
		new_bullet.global_position = shooting_point.global_position
		new_bullet.global_rotation = shooting_point.global_rotation
		
