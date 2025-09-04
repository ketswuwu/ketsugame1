extends CharacterBody2D

@export var move_speed : float = 500
var character_direction : Vector2

@onready var animated_sprite_2d: AnimatedSprite2D = $sprite

var animation_direction: String = "down"
var animation_state: String = ""
var attack_state: String = ""
var isAttacking: bool = false

func update_sprite_direction(input: Vector2) -> void:
	match input:
		Vector2.DOWN:
			animation_direction = "down"
		Vector2.UP:
			animation_direction = "up"
		Vector2.LEFT:
			animation_direction = "side"
		Vector2.RIGHT:
			animation_direction = "side"
	
func update_sprite() -> void:
			animation_state = "default"	
			attack_state = "attack"
func _physics_process(delta):
		character_direction.x = Input.get_axis("move_left", "move_right")
		character_direction.y = Input.get_axis("move_up", "move_down")
		character_direction = character_direction.normalized()
		
		update_sprite_direction(character_direction)
		update_sprite()
		animated_sprite_2d.play(animation_state+animation_direction)
			
		if  Input.is_action_just_pressed("attack_melee"):
			animated_sprite_2d.play("attack"+animation_direction)
			isAttacking = true
			await animated_sprite_2d.animation_finished
			isAttacking = false
		#flip	
		if character_direction.x > 0: %sprite.flip_h = false
		elif character_direction.x < 0: %sprite.flip_h = true
		velocity = character_direction * move_speed
		
		move_and_collide(velocity*delta)
		
