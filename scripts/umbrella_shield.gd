extends Area2D

func _ready():
	# Muda a cor para Dourado/Amarelo brilhante (o Alpha 'a' começa a 0)
	modulate = Color(2.0, 2.0, 2.0, 0.0) 
	
	var tween = create_tween()
	# Efeito visual de "aparecer" (fade in) 
	tween.tween_property(self, "modulate:a", 0.8, 0.2) 
	tween.tween_interval(1.6) # Fica ativo
	# "Desaparecer" (fade out)
	tween.tween_property(self, "modulate:a", 0.0, 0.2) 
	tween.tween_callback(queue_free)

# Esta função será chamada pelo jogador quando ele bloquear um ataque
func block_attack():
	print("HUD: Ataque bateu no escudo e foi bloqueado!")
	
	# Efeito de absorção: O escudo incha um bocadinho e volta ao normal rápido!
	var bounce_tween = create_tween()
	bounce_tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.1)
	bounce_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
