extends Area2D

@export var xp_amount = 10
var base_pickup_radius = 40 

var is_magnetized = false
var player_ref = null
var magnet_speed = 400.0

func _ready():
	add_to_group("gem")
	
	# TRUQUE 1: Desliga o _process! A gema parada não gasta CPU nenhum.
	set_process(false) 
	
	update_pickup_range()
	
func update_pickup_range():
	var player = get_tree().get_first_node_in_group("player")
	if not player: return
	
	var shape = $CollisionShape2D.shape.duplicate()
	$CollisionShape2D.shape = shape
	
	# Calcula o raio real que queremos que ela tenha
	var bonus = player.pickup_range_level * 35 
	var target_radius = base_pickup_radius + bonus
	
	# O SEGREDO: Dividir pela escala da gema! 
	# Se a escala for 2.0, o raio interno passa a metade, para que o raio global final fique exatamente o mesmo das outras gemas!
	shape.radius = target_radius / scale.x

func _process(delta):
	# Como desligámos o _process, o código só chega aqui quando a gema estiver a voar!
	if is_instance_valid(player_ref):
		var direction = (player_ref.global_position - global_position).normalized()
		global_position += direction * magnet_speed * delta
		
		# TRUQUE 2: distance_squared_to é muito mais rápido para o CPU que distance_to
		# 225 é o quadrado de 15 pixeis (15 * 15)
		if global_position.distance_squared_to(player_ref.global_position) < 225.0:
			player_ref.gain_experience(xp_amount)
			queue_free()

func _on_body_entered(body):
	if body.is_in_group("player") and not is_magnetized:
		player_ref = body
		is_magnetized = true
		
		# ACORDA O SCRIPT! Agora sim, gasta CPU só durante o segundo em que voa.
		set_process(true) 
		
		# TRUQUE 3: Desliga as colisões! O motor de física já não precisa de olhar para esta gema.
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		
		magnet_speed = 500.0 + (player_ref.pickup_range_level * 50)
