extends Area2D

@export var bullet_scene: PackedScene

@onready var shooting_point = $ShootingPoint
@onready var timer = $Timer

var player = null
var triple_shot = false
var piercing_level = 0
var amount_level = 0

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
	var total_bullets = 1 + amount_level
	
	for i in range(total_bullets):
		spawn_bullet(0)
		await get_tree().create_timer(0.2).timeout
	
func shoot_triple():
	var angles = [0, deg_to_rad(20), deg_to_rad(-20)]
	var total_bullets = 1 + amount_level
	
	for i in range(total_bullets):
		for angle in angles:
			spawn_bullet(angle)
		
		await get_tree().create_timer(0.2).timeout
			
func spawn_bullet(angle):
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	
	bullet.global_position = shooting_point.global_position
	bullet.global_rotation = shooting_point.global_rotation + angle
	
	# passar piercing
	bullet.piercing = piercing_level
