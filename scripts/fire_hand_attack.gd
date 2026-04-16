extends Area2D

@export var damage = 25
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
	shadow_anim.play("shadow")
	
	# Começa a sombra bem suave (Alpha 0.4)
	shadow_anim.scale = Vector2(1.2, 1.2)
	shadow_anim.modulate = Color(0.8, 0.2, 0.1, 0.1)

func _process(delta):
	if not is_instance_valid(player):
		return
		
	if is_tracking:
		# Perseguição um pouco mais pesada para o jogador não fugir sem querer
		global_position = global_position.lerp(player.global_position, follow_speed * delta)
		
		track_timer += delta
		
		# --- LÓGICA DE CAMUFLAGEM (SEM PISCAR!) ---
		var progresso = track_timer / track_duration # Vai de 0.0 a 1.0
		
		# A sombra começa quase invisível (0.1) e vai até um vermelho/preto semi-transparente (0.6)
		# Como o fundo é lava, um alpha de 0.6 vai misturar-se muito bem com o chão e a horda
		var alpha_base = lerp(0.1, 0.6, progresso)
		
		# Para o jogador visual puro: A sombra encolhe ligeiramente (foca) mesmo antes do ataque
		# É subtil, mas é "justo" e não chama a atenção do olho humano como um piscar faz
		var escala_base = lerp(1.2, 0.8, progresso)
		shadow_anim.scale = Vector2(escala_base, escala_base)
		
		# Se tiveres uma cor "avermelhada" ou "laranja" escuro para a sombra, ela camufla-se melhor na lava
		shadow_anim.modulate = Color(0.8, 0.2, 0.1, alpha_base) 
		
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
				body.take_damage(damage, "Boss: Hand Attack")
		
		queue_free()
