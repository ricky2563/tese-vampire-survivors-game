extends Area2D

@export var damage = 20
@export var track_duration = 1.5   
@export var follow_speed = 6.0     

var player: Node2D
var is_tracking = true
var track_timer = 0.0

@onready var anim = $AnimatedSprite2D
@onready var shadow_anim = $Shadow 

func _ready():
	player = get_tree().get_first_node_in_group("player")
	
	anim.visible = false
	shadow_anim.visible = true
	shadow_anim.play("default")
	
	# Começa a sombra bem suave (Alpha 0.4)
	shadow_anim.modulate = Color(1, 1, 1, 0.4)

func _process(delta):
	if not is_instance_valid(player):
		return
		
	if is_tracking:
		# Perseguição suave
		global_position = global_position.lerp(player.global_position, follow_speed * delta)
		
		track_timer += delta
		
		# --- LÓGICA DE ALPHA (TRANSITIONS) ---
		var progresso = track_timer / track_duration # Vai de 0.0 a 1.0
		
		# Mantemos a cor original (1, 1, 1) e aumentamos apenas o Alpha.
		# Começa em 0.1 e termina em 1.0
		var novo_alpha = lerp(0.1, 1.0, progresso)
		shadow_anim.modulate = Color(1, 1, 1, novo_alpha)
		
		if track_timer >= track_duration:
			start_attack()

func start_attack():
	is_tracking = false
	
	# 3. Transição: Esconde a sombra
	shadow_anim.visible = false
	
	# 4. Mostra a Mão e toca o "rise"
	anim.visible = true
	anim.play("rise")

func _on_animated_sprite_2d_animation_finished():
	# 5. Como este sinal continua ligado ao AnimatedSprite2D principal, a lógica mantém-se!
	if anim.animation == "rise":
		for body in get_overlapping_bodies():
			if body.is_in_group("player"):
				body.take_damage(damage)
		
		queue_free()
