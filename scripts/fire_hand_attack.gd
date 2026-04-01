extends Area2D

@export var damage = 20
@export var lifetime = 2.0 

@onready var timer = $Timer
@onready var anim = $AnimatedSprite2D

func _ready():
	# começa com animação (telegraph visual)
	anim.play("rise")
	
	# opcional: mais transparente no início
	modulate = Color(1,1,1,1)
	
	timer.start()

func _on_timer_timeout():
	# impacto
	modulate = Color(1,1,1,1)
	
	# dano ao player
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			body.take_damage(damage)
	
	# pequena pausa antes de desaparecer
	await get_tree().create_timer(0.2).timeout
	queue_free()


func _on_animated_sprite_2d_animation_finished():
	# quando a mão termina de subir → dá dano
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			body.take_damage(damage)
	
	queue_free()
	
