extends Area2D

@export var max_health: int = 1
@export var damage: int = 1
@export var damage_cooldown: float = 0.5

var can_damage: bool = true
var player_in_range: Node = null
var current_health: int
var is_hurt: bool = false

@onready var damage_timer: Timer = $DamageTimer
@onready var sprite: Sprite2D = $Sprite2D


func _ready():
	current_health = max_health  # ✅ Initialize health
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))
	damage_timer.connect("timeout", Callable(self, "_on_DamageTimer_timeout"))
	
	
	# 🩸 Called by player when hit
func take_damage(amount: int, from_position: Vector2):
	if is_hurt:
		return
		
	is_hurt = true
	current_health -= amount
	print("[Enemy] Took damage:", amount, "remaining:", current_health)

		# ✅ Flash red briefly for feedback
	sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color(1, 1, 1)
	is_hurt = false

		# ✅ Check if dead
	if current_health <= 0:
		die()


func die():
	print("[Enemy] Died!")
	is_hurt = false
		
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true

		# Hide sprite
	sprite.visible = false

		# Optional: spawn particles, sound, or loot here
	await get_tree().create_timer(0.2).timeout
	queue_free()


	# 🔻 When player enters the enemy’s hit area
func _on_body_entered(body):
	if body.is_in_group("player"):
		print("[Enemy] Player entered range.")
		player_in_range = body
		_deal_damage()


	# 🔺 When player exits
func _on_body_exited(body):
	if body.is_in_group("player"):
		print("[Enemy] Player exited range.")
		player_in_range = null


	# 💥 Deal contact damage
func _deal_damage():
	if not can_damage or player_in_range == null:
		return

	if player_in_range.has_method("take_damage"):
		print("[Enemy] Dealing", damage, "damage to player.")
		player_in_range.take_damage(damage, global_position)
	else:
		print("[Enemy] Player lacks take_damage()!")

	can_damage = false
	damage_timer.start(damage_cooldown)


func _on_DamageTimer_timeout():
	can_damage = true
	if player_in_range:
		_deal_damage()
