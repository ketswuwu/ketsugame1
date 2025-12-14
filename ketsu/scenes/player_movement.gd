extends CharacterBody2D

@export var move_speed: float = 500
@export var attack_duration: float = 0.20
@export var invulnerability_time: float = 0.6
@export var flicker_speed: float = 0.1
@export var knockback_force: float = 600.0
@export var knockback_duration: float = 0.2
@export var dash_speed: float = 1200
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5

@onready var main_camera: Camera2D = get_tree().get_current_scene().get_node("Camera2D")

var is_dashing: bool = false
var can_dash: bool = true
var is_invincible: bool = false

var knockback_vector: Vector2 = Vector2.ZERO
var is_knocked_back: bool = false

var current_health: int
var is_hurt: bool = false

var character_direction: Vector2

@onready var animated_sprite_2d: AnimatedSprite2D = $sprite
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D
@onready var attack_timer: Timer = $AttackTimer
@onready var attack_combo_timer: Timer = $AttackComboTimer
@onready var attack_lunge_timer: Timer = $AttackLungeTimer
@onready var hurt_timer: Timer = $HurtTimer
@onready var dash_timer: Timer = $DashTimer
@onready var dash_cooldown_timer: Timer = $DashCooldownTimer
@onready var interact_box: Area2D = $Direction/ActionableFinder

var normal_collision_layer
var normal_collision_mask
var last_move_dir: Vector2 = Vector2.RIGHT
var is_lunging: bool = false
var can_deal_damage: bool = false
var animation_direction: String = "down"
var is_attacking: bool = false
var combo_step: int = 0
var max_combo: int = 3
var combo_window: float = 0.8  # seconds to continue combo
var lunge_force := [150, 150, 300]  # Attack 1, 2, 3
# attack 1 → 40 px
# attack 2 → 60 px
# attack 3 → 120 px (big lunge)
var attack_offset := {
	"up": Vector2(0, -32),
	"down": Vector2(0, 32),
	"side": Vector2(32, 0)
}

func _ready():
	# Initialize from PlayerData
	normal_collision_layer = collision_layer
	normal_collision_mask = collision_mask
	print(collision_mask)
	current_health = Playerdata.stats["health"]
	Playerdata.lock_ability("Double Jump")
	Playerdata.unlock_ability("Dash")
	
func _physics_process(delta):
	if is_attacking:
		# No player control, but keep lunge velocity active
		move_and_slide()
		return

	if is_lunging:
		velocity.x = lerp(velocity.x, 0.0, 0.15)  # smooth slowdown

	elif is_dashing:
		move_and_slide()
		return

	else:
		# READ PLAYER INPUT
		# -------------------------
		character_direction.x = Input.get_axis("move_left", "move_right")
		character_direction.y = Input.get_axis("move_up", "move_down")
		character_direction = character_direction.normalized()

		# 🔥 NEW CODE HERE — update last_move_dir for top-down lunges
		var input_dir = Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
		).normalized()

		if input_dir != Vector2.ZERO:
			last_move_dir = input_dir
		# -------------------------

		update_sprite_direction(character_direction)

		if character_direction != Vector2.ZERO:
			animated_sprite_2d.play("walk_" + animation_direction)
		else:
			animated_sprite_2d.play("idle_" + animation_direction)

		update_interact_box_direction()

		if character_direction.x > 0:
			%sprite.flip_h = false
			$AttackHitbox.position.x = abs($AttackHitbox.position.x)
		elif character_direction.x < 0:
			%sprite.flip_h = true
			$AttackHitbox.position.x = -abs($AttackHitbox.position.x)

		velocity = character_direction * move_speed
		move_and_slide()

	# Attack input
	if Input.is_action_just_pressed("attack_melee") and not is_attacking and not is_dashing:
		start_attack()

	# Dash input
	if Input.is_action_just_pressed("dash") and can_dash and not is_attacking:
		start_dash()
func start_attack():
	if attack_combo_timer.is_stopped():
		combo_step = 1
	else:
		combo_step += 1

	if combo_step > max_combo:
		combo_step = 1

	# ---- PLAY CORRECT ATTACK ANIMATION ----
	var anim_name = "attack_" + animation_direction + "_" + str(combo_step)
	animated_sprite_2d.play(anim_name)

	is_attacking = true

	# ---- APPLY LUNGE MOVEMENT ----
	apply_lunge()
	
	update_attack_hitbox_direction()

	can_deal_damage = true
	attack_hitbox.monitoring = true
	attack_hitbox.set_deferred("monitorable", true)

	# Duration of the attack animation
	await get_tree().create_timer(attack_duration).timeout

	# ---- END ATTACK ----
	is_attacking = false
	can_deal_damage = false
	attack_hitbox.monitoring = false
	if is_attacking == false:
		print("notattacking")

	# start combo window
	attack_combo_timer.start(combo_window)
func update_interact_box_direction():
	match animation_direction:
		"up":
			interact_box.position = Vector2(0, -80)
			interact_box.rotation_degrees = 0
		"down":
			interact_box.position = Vector2(0, 0)
			interact_box.rotation_degrees = 0
		"side":
			var x_offset = 40 if not %sprite.flip_h else -40
			interact_box.position = Vector2(x_offset, -40)
			interact_box.rotation_degrees = 0


func update_attack_hitbox_direction():
	match animation_direction:
		"up":
			attack_hitbox.position = Vector2(-40, -80)
			attack_hitbox.rotation_degrees = 90
		"down":
			attack_hitbox.position = Vector2(-40, -5)
			attack_hitbox.rotation_degrees = 90
		"side":
			var x_offset = -32 if %sprite.flip_h else 32
			attack_hitbox.position = Vector2(x_offset, 0)
			attack_hitbox.rotation_degrees = 0


func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	if not can_deal_damage or not is_attacking:
		return

	if area.is_in_group("enemy") and area.has_method("take_damage"):
		var damage = Playerdata.stats["attack"]
		area.take_damage(damage, global_position)

	if area.is_in_group("breakable") and area.has_method("take_damage"):
		var damage = Playerdata.stats["attack"]
		area.take_damage(damage)
		
func apply_lunge():
	var force = lunge_force[combo_step - 1]
	velocity = last_move_dir * force
	is_lunging = true
	attack_lunge_timer.start(0.1)
func start_dash():
	if last_move_dir == Vector2.ZERO:
		return

	is_dashing = true

	# Save normal collision settings
	normal_collision_layer = collision_layer
	normal_collision_mask = collision_mask

	# Disable collision with everything EXCEPT what you want
	collision_layer = 2               # player belongs to no layer
	collision_mask = 3               # player collides with nothing
	if collision_mask == 3:
		print("collision mask is 3")
	velocity = last_move_dir.normalized() * dash_speed

	dash_timer.start(dash_duration)
	
func set_invincible(value: bool):
	is_invincible = value
	if value:
		animated_sprite_2d.modulate = Color(1, 0.4, 0.4, 0.8)
	else:
		animated_sprite_2d.modulate = Color(1, 1, 1, 1)


func _on_dash_timer_timeout() -> void:
	is_dashing = false
	set_invincible(false)

	# Restore original collision layers
	collision_layer = normal_collision_layer
	collision_mask = normal_collision_mask
	print(collision_layer)
	print(collision_mask)

func _on_dash_cooldown_timer_timeout() -> void:
	can_dash = true


func take_damage(amount: int, source_position: Vector2 = global_position):
	if is_invincible or is_hurt:
		return

	current_health -= amount
	Playerdata.stats["health"] = current_health  # sync back to PlayerData

	is_hurt = true
	print("[Player] Took", amount, "damage. Health now:", current_health)

	var direction = (global_position - source_position).normalized()
	knockback_vector = direction * knockback_force
	is_knocked_back = true
	start_knockback()

	animated_sprite_2d.play("hurt_" + animation_direction)

	if current_health <= 0:
		die()
		return

	start_flicker_effect()

	if is_instance_valid(main_camera) and main_camera.has_method("apply_shake"):
		Engine.time_scale = 0.1
		await get_tree().create_timer(0.018, false).timeout
		Engine.time_scale = 1.0
		main_camera.apply_shake(6.0, 0.25)

	hurt_timer.start(invulnerability_time)

func _on_attack_lunge_timer_timeout():
	is_lunging = false
func start_knockback():
	var elapsed = 0.0
	while elapsed < knockback_duration and is_knocked_back:
		var t = elapsed / knockback_duration
		velocity = knockback_vector * (1.0 - t)
		move_and_slide()
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	is_knocked_back = false
	velocity = Vector2.ZERO


func start_flicker_effect() -> void:
	if not is_instance_valid(animated_sprite_2d):
		return

	var flicker_interval := 0.1
	var flicker_count := int(invulnerability_time / flicker_interval / 2)

	for i in range(flicker_count):
		if not is_hurt:
			break
		animated_sprite_2d.modulate = Color(2, 2, 2, 1)
		await get_tree().create_timer(flicker_interval).timeout
		animated_sprite_2d.modulate = Color(1, 1, 1, 1)
		await get_tree().create_timer(flicker_interval).timeout

	animated_sprite_2d.modulate = Color(1, 1, 1, 1)


func _on_attack_timer_timeout() -> void:
	is_attacking = false
	can_deal_damage = false
	attack_hitbox.monitoring = false
	
func _on_attack_combo_timer_timeout() -> void:
	combo_step = 0

func _on_hurt_timer_timeout() -> void:
	is_hurt = false


func die():
	print("[Player] Player has died!")

	is_attacking = false
	is_hurt = false
	velocity = Vector2.ZERO
	set_process(false)
	set_physics_process(false)

	$CollisionShape2D.disabled = true

	start_flicker_effect()

	# Camera shake (if you have one)
	if is_instance_valid(main_camera) and main_camera.has_method("apply_shake"):
		Engine.time_scale = 0.1
		await get_tree().create_timer(0.018).timeout
		Engine.time_scale = 1.0
		main_camera.apply_shake(25.0, 0.25)

	var death_anim = "dead_" + animation_direction

	if animated_sprite_2d.sprite_frames.has_animation(death_anim):
		animated_sprite_2d.play(death_anim)

		# 🔒 If animation loops, force reload after a delay
		var anim_len = animated_sprite_2d.sprite_frames.get_frame_count(death_anim) / animated_sprite_2d.sprite_frames.get_animation_speed(death_anim)
		var timeout = max(anim_len, 0.3)

		await get_tree().create_timer(timeout).timeout
	else:
		await get_tree().create_timer(0.4).timeout
	Playerdata.stats["health"] = Playerdata.stats["max_health"]
	
	get_tree().reload_current_scene()
	# --- RELOAD SCENE ---
func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		var actionables = interact_box.get_overlapping_areas()
		if actionables.size() > 0:
			actionables[0].action()
			return


func update_sprite_direction(input: Vector2) -> void:
	if input == Vector2.ZERO:
		return

	if abs(input.x) > abs(input.y):
		animation_direction = "side"
	elif input.y > 0:
		animation_direction = "down"
	else:
		animation_direction = "up"
