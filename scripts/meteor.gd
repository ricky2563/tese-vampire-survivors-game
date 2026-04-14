extends Node2D

@export var fall_time = 0.5
@export var damage = 25
@export var shadow_scene: PackedScene

var shadow
var target_position
var start_position

@onready var sprite = $Sprite2D

func _ready():
	# Meteoro começa bem lá no alto (fora do ecrã)
	start_position = target_position + Vector2(0, -500) 
	global_position = start_position
	
	create_shadow()
	fall()

func fall():
	var tween = create_tween()
	
	# O Meteoro cai
	tween.tween_property(self, "global_position", target_position, fall_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(impact)

	# OTIMIZAÇÃO VISUAL: A sombra cresce à medida que o meteoro cai!
	# Isto avisa os jogadores visuais do tempo exato do impacto
	if shadow:
		var shadow_tween = create_tween()
		shadow.scale = Vector2(0.1, 0.1) # Começa minúscula
		shadow_tween.tween_property(shadow, "scale", Vector2(1.5, 1.5), fall_time)

func impact():
	# ... (A tua lógica de dano mantém-se perfeitamente igual) ...
	var player_target = null
	for body in $Area2D.get_overlapping_bodies():
		if body.is_in_group("player"):
			player_target = body
			break
	
	if player_target:
		if player_target.is_shield_active:
			print("Meteoro bloqueado pelo estado do escudo!")
			var shield_node = player_target.get_node_or_null("UmbrellaShield")
			if shield_node and shield_node.has_method("block_attack"):
				shield_node.block_attack()
		else:
			player_target.take_damage(damage)
			
	if shadow:
		shadow.queue_free()
	queue_free()

func create_shadow():
	if shadow_scene == null:
		return
	
	shadow = shadow_scene.instantiate()
	shadow.global_position = target_position
	shadow.z_index = -1 # GARANTE QUE FICA DEBAIXO DO PLAYER E DOS INIMIGOS
	
	get_tree().current_scene.add_child(shadow)
