extends Area2D

@export var bullet_scene: PackedScene

@onready var shooting_point = $ShootingPoint
@onready var timer = $Timer

var player = null
var triple_shot = false
var piercing_level = 0

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
		return
	
	if triple_shot:
		shoot_triple()
	else:
		shoot_single()

func shoot_single():
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	
	bullet.global_position = shooting_point.global_position
	bullet.global_rotation = shooting_point.global_rotation
	bullet.piercing = piercing_level
	
func shoot_triple():
	var angles = [0, deg_to_rad(20), deg_to_rad(-20)]
	
	for angle in angles:
		var bullet = bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		
		bullet.global_position = shooting_point.global_position
		bullet.global_rotation = shooting_point.global_rotation + angle
		bullet.piercing = piercing_level
