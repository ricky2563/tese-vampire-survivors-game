extends Area2D

@export var damage = 25
@export var track_duration = 1.5   
@export var follow_speed = 6.0     

var player: Node2D
var is_tracking = true
var track_timer = 0.0
var is_nova = false

@onready var anim = $AnimatedSprite2D
@onready var shadow_anim = $Shadow 

func _ready():
	player = get_tree().get_first_node_in_group("player")
	
	if is_nova:
		scale = Vector2(0.70, 0.70)
	
	anim.visible = false
	shadow_anim.visible = true
	shadow_anim.play("shadow")
	
	# Começa a sombra bem suave (Alpha 0.4)
	shadow_anim.scale = Vector2(1.2, 1.2)
	shadow_anim.modulate = Color(0.8, 0.2, 0.1, 0.1)

func _process(delta):
	if not is_instance_valid(player):
		return
		
	# A perseguição SÓ acontece se o is_tracking for verdadeiro
	if is_tracking:
		global_position = global_position.lerp(player.global_position, follow_speed * delta)
	
	track_timer += delta
	
	var progresso = track_timer / track_duration
	var alpha_base = lerp(0.1, 0.6, progresso)
	var escala_base = lerp(1.2, 0.8, progresso)
	shadow_anim.scale = Vector2(escala_base, escala_base)
	shadow_anim.modulate = Color(0.8, 0.2, 0.1, alpha_base) 
	
	if track_timer >= track_duration:
		start_attack()

func start_attack():
	is_tracking = false
	
	# 3. Transição: Esconde a sombra
	shadow_anim.visible = false
	
	# 4. Mostra a Mão e toca o "rise"
	anim.visible = true
	if is_nova:
		anim.play("nova")
	else:
		anim.play("rise")

func _on_animated_sprite_2d_animation_finished():
	if anim.animation == "rise" or anim.animation == "nova":
		for body in get_overlapping_bodies():
			if body.is_in_group("player"):
				var attack_name = "Boss: Nova Attack" if is_nova else "Boss: Hand Attack"
				body.take_damage(damage, attack_name)
		
		queue_free()
