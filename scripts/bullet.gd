extends Area2D

var travelled_distance = 0
var speed = 400
var bullet_range = 1200 # Distância máxima que a bala viaja
var piercing = 0
var enemies_hit = []

# --- NOVAS VARIÁVEIS ---
var damage = 30
var hit_radius = 20.0 
var hit_cooldown = 0.0
var math_check_timer = 0.0
var MATH_CHECK_INTERVAL = 0.05

func _physics_process(delta):
	# 1. Movimento da Bala
	var direction = Vector2.RIGHT.rotated(rotation)
	position += direction * speed * delta
	
	travelled_distance += speed * delta
	if travelled_distance > bullet_range:
		queue_free()
		return
		
	# 2. COLISÃO MATEMÁTICA (Horda)
	if hit_cooldown > 0:
		hit_cooldown -= delta
	else:
		# Só faz a matemática pesada se o micro-timer apitar!
		math_check_timer -= delta
		if math_check_timer <= 0.0:
			math_check_timer = MATH_CHECK_INTERVAL # Reseta o relógio
			
			# Pergunta ao Autoload se bateu nalguma coordenada inimiga
			if EnemyManager.check_bullet_hit(global_position, hit_radius, damage):
				piercing -= 1
				hit_cooldown = 0.1 # Dá um tempo maior porque ACERTOU
				
				if piercing < 0:
					queue_free()
					return

# ==========================================
# 3. COLISÃO FÍSICA (Para os Bosses)
# ==========================================
# Mantemos este sinal ativado! Como os bosses continuam a ser CharacterBody2D,
# a física normal do Godot vai detetá-os aqui.
func _on_body_entered(body):
	if body.has_method("take_damage"):
		
		# evitar hits duplicados
		if body in enemies_hit:
			return
		
		enemies_hit.append(body)
		body.take_damage(damage)
		
		# reduz piercing
		piercing -= 1
		
		if piercing < 0:
			queue_free()
