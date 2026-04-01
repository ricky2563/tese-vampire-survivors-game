extends Area2D

func _ready():
	# O escudo dura 2 segundos e depois desaparece
	var tween = create_tween()
	# Efeito visual de "aparecer" (fade in) e depois "desaparecer" (fade out)
	modulate.a = 0
	tween.tween_property(self, "modulate:a", 1.0, 0.2) # Fade in rápido
	tween.tween_interval(1.6) # Fica ativo
	tween.tween_property(self, "modulate:a", 0.0, 0.2) # Fade out
	tween.tween_callback(queue_free)

# Esta função será chamada pelo meteoro quando ele impactar
func block_attack():
	# Aqui podes pôr um efeito de faíscas ou som de "block"
	print("Ataque bloqueado pelo guarda-chuva!")
