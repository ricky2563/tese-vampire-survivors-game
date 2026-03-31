extends Area2D

var travelled_distance = 0
var speed = 400
var bullet_range = 1200 # Distância máxima que a bala viaja
var piercing = 0
var enemies_hit = []

func _physics_process(delta):
	# Mover para a frente (na direção em que a bala está rodada)
	# Vector2.RIGHT roda com o objeto, por isso funciona
	var direction = Vector2.RIGHT.rotated(rotation)
	position += direction * speed * delta
	
	travelled_distance += speed * delta
	if travelled_distance > bullet_range:
		queue_free() # Destroi a bala se for longe demais

# Liga este sinal através do painel Node -> body_entered
func _on_body_entered(body):
	if body.has_method("take_damage"):
		
		# evitar hits duplicados
		if body in enemies_hit:
			return
		
		enemies_hit.append(body)
		body.take_damage(50)
		
		# reduz piercing
		piercing -= 1
		
		if piercing < 0:
			queue_free()
