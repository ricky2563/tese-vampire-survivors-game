extends Area2D

@export var xp_amount = 10

func _on_body_entered(body):
	if body.is_in_group("player"):
		body.gain_experience(xp_amount)
		queue_free() # A gema desaparece
