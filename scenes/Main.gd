extends Node
## Thin bootstrapper. Loads save data, hands SceneRouter its container,
## then routes to the overworld. See GAME_CONCEPT.md section 9.1.

func _ready() -> void:
	GameState.load_game()
	SceneRouter.set_stack($SceneStack)
	SceneRouter.change_scene("res://scenes/ui/Hub.tscn")
