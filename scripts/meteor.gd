extends Node2D

@export var fall_time = 1.0
@export var damage = 25
@export var shadow_scene: PackedScene

var shadow
var target_position
var start_position

@onready var sprite = $Sprite2D

func _ready():
	start_position = target_position + Vector2(0, -300)
	global_position = start_position
	
	create_shadow()
	
	# O 'false' diz ao timer: "Se o jogo pausar, para de contar!"
	await get_tree().create_timer(0.3, false).timeout 
	
	fall()

func fall():
	# Substituímos o while complicado por um Tween (animação por código)
	var tween = create_tween()
	
	# Move do ponto atual para o target_position durante o fall_time
	tween.tween_property(self, "global_position", target_position, fall_time)
	
	# Quando acabar de mover, chama o impacto automaticamente
	tween.tween_callback(impact)

func impact():
	# 1. Procurar o player na área de impacto
	var player_target = null
	for body in $Area2D.get_overlapping_bodies():
		if body.is_in_group("player"):
			player_target = body
			break
	
	# 2. Lógica de Dano vs Escudo
	if player_target:
		if player_target.is_shield_active:
			# BLOQUEADO: O player tem o escudo ligado
			print("Meteoro bloqueado pelo estado do escudo!")
			# Se quiseres chamar um som ou animação no escudo:
			var shield_node = player_target.get_node_or_null("UmbrellaShield")
			if shield_node and shield_node.has_method("block_attack"):
				shield_node.block_attack()
		else:
			# DANO: O player está vulnerável
			player_target.take_damage(damage)
			
	# Limpeza
	if shadow:
		shadow.queue_free()
	queue_free()

func create_shadow():
	if shadow_scene == null:
		print("Shadow scene não atribuída!")
		return
	
	shadow = shadow_scene.instantiate()
	shadow.global_position = target_position
	
	get_tree().current_scene.add_child(shadow)
	
# TODO acho que a shadow n está exatamente onde deve estar
