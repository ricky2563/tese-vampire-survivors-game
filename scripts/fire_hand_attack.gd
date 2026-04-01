extends Area2D

@export var damage = 20
@export var track_duration = 1.5   
@export var follow_speed = 6.0     

var player: Node2D
var is_tracking = true
var track_timer = 0.0

@onready var anim = $AnimatedSprite2D

func _ready():
	player = get_tree().get_first_node_in_group("player")
	
	# 1. Toca a animação da tua sombra! 
	# (Atenção: muda "shadow" para o nome exato que deste à tua animação da sombra no painel do AnimatedSprite2D)
	anim.play("shadow")
	
	# Retiramos a transparência (modulate) já que agora tens um sprite próprio para isto

func _process(delta):
	if not is_instance_valid(player):
		return
		
	if is_tracking:
		global_position = global_position.lerp(player.global_position, follow_speed * delta)
		
		track_timer += delta
		if track_timer >= track_duration:
			start_attack()

func start_attack():
	is_tracking = false
	
	# 2. Transição: A sombra para e a mão sobe
	anim.play("rise")

func _on_animated_sprite_2d_animation_finished():
	# 3. PROTEÇÃO: Verifica se a animação que acabou foi mesmo o ataque ("rise").
	# Isto evita que a mão desapareça e dê erro caso a animação "shadow" termine antes do tempo!
	if anim.animation == "rise":
		for body in get_overlapping_bodies():
			if body.is_in_group("player"):
				body.take_damage(damage)
		
		queue_free()
