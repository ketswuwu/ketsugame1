extends Panel

@onready var animated_sprite_2d: AnimatedSprite2D = $Control/AnimatedSprite2D

var talk: Array = ["talk"]

func _ready() -> void:
	animated_sprite_2d.play("talk")
	
func play_emote(animation: String) -> void:
	animated_sprite_2d.play(animation)
