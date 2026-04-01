extends Area2D

@export var max_size = 5.0      # Ficou maior para compensar a lentidão
@export var expansion_speed = 3.0 # AGORA DEMORA 3 SEGUNDOS A EXPANDIR (Mais lento)
@export var damage = 40

func _ready():
	scale = Vector2(0.1, 0.1)
	modulate.a = 1.0
	
	var tween = create_tween()
	
	# Transição LINEAR para ser uma expansão constante e previsível
	tween.tween_property(self, "scale", Vector2(max_size, max_size), expansion_speed).set_trans(Tween.TRANS_LINEAR)
	
	# O desaparecimento (fade out) só começa a meio da expansão
	tween.parallel().tween_property(self, "modulate:a", 0.0, expansion_speed).set_delay(expansion_speed * 0.5)
	
	tween.tween_callback(queue_free)

func _on_body_entered(body):
	if body.is_in_group("player"):
		# Dano direto (ignora o shield)
		body.take_damage(damage)
