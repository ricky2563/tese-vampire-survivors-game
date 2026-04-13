extends Area2D

@export var bullet_scene: PackedScene

@onready var shooting_point = $ShootingPoint
@onready var timer = $Timer

var player = null
var triple_shot = false
var piercing_level = 0
var amount_level = 0
var multi_direction_level = 0
var bounce_level = 0

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
	if bullet_scene == null: return
	
	# 1. Definir para que lados o jogador atira (Base)
	var base_angles = [0.0]
	if multi_direction_level == 1:
		base_angles = [0.0, PI] # Frente e Trás (180º)
	elif multi_direction_level == 2:
		base_angles = [0.0, PI/2, PI, -PI/2] # 4 Direções
	elif multi_direction_level >= 3:
		base_angles = [0.0, PI/4, PI/2, 3*PI/4, PI, -3*PI/4, -PI/2, -PI/4] # 8 Direções
		
	# 2. Definir o "Espalhamento" (Triple Shot)
	var spread_angles = [0.0]
	if triple_shot:
		spread_angles = [0.0, deg_to_rad(20), deg_to_rad(-20)]
		
	var total_bullets = 1 + amount_level
	
	# 3. Disparar a matriz toda!
	for i in range(total_bullets):
		for base_a in base_angles:
			for spread_a in spread_angles:
				# AQUI ESTÁ A CORREÇÃO:
				# Sem invenções matemáticas. O 'scale.x = -1' no _process já faz o trabalho todo!
				var final_angle = base_a + spread_a
					
				spawn_bullet(final_angle)
		
		# Espera antes de lançar a próxima "vaga" do amount_level
		await get_tree().create_timer(0.2).timeout

func spawn_bullet(angle):
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	
	bullet.global_position = shooting_point.global_position
	bullet.global_rotation = shooting_point.global_rotation + angle
	
	# Passar apenas o piercing
	bullet.piercing = piercing_level
