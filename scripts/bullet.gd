extends Area2D

var travelled_distance = 0
var speed = 400
var range = 1200 # Distância máxima que a bala viaja

func _physics_process(delta):
	# Mover para a frente (na direção em que a bala está rodada)
	# Vector2.RIGHT roda com o objeto, por isso funciona
	var direction = Vector2.RIGHT.rotated(rotation)
	position += direction * speed * delta
	
	travelled_distance += speed * delta
	if travelled_distance > range:
		queue_free() # Destroi a bala se for longe demais

# Liga este sinal através do painel Node -> body_entered
func _on_body_entered(body):
	queue_free() # A bala destrói-se ao bater
	if body.has_method("take_damage"):
		body.take_damage(50) # Tira 50 de vida ao inimigo
