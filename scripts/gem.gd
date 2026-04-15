extends Area2D

@export var xp_amount = 10

var base_pickup_radius = 20

func _ready():
	# --- NOVO: Adiciona a gema ao grupo para o EnemyManager conseguir contá-las! ---
	add_to_group("gem")
	
	update_pickup_range()
	
func update_pickup_range():
	var player = get_tree().get_first_node_in_group("player")
	
	if not player:
		return
	
	var shape = $CollisionShape2D.shape.duplicate()
	$CollisionShape2D.shape = shape
	
	# cada nível aumenta 10 pixels
	var bonus = player.pickup_range_level * 10
	
	shape.radius = base_pickup_radius + bonus

func _on_body_entered(body):
	if body.is_in_group("player"):
		body.gain_experience(xp_amount)
		queue_free() # A gema desaparece
