extends Area2D

@export var bullet_scene: PackedScene

@onready var shooting_point = $ShootingPoint
@onready var timer = $Timer

var player = null

func _ready():
	player = get_tree().get_first_node_in_group("player")
	
	timer.wait_time = 1
	timer.start()

func _process(delta):
	if not player:
		return
	
	# Rodar arma consoante direção do player
	if player.is_facing_right:
		scale.x = 1
	else:
		scale.x = -1

func _on_timer_timeout():
	shoot()

func shoot():
	if bullet_scene == null:
		print("Bullet scene não atribuída!")
		return
	
	var new_bullet = bullet_scene.instantiate()
	
	# Adiciona ao mundo
	get_tree().current_scene.add_child(new_bullet)
	
	# Define posição e rotação
	new_bullet.global_position = shooting_point.global_position
	new_bullet.global_rotation = shooting_point.global_rotation
