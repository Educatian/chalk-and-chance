extends Node
## Thin bootstrapper. Loads save data, hands SceneRouter its container,
## then routes to the overworld. See GAME_CONCEPT.md section 9.1.

func _ready() -> void:
	GameState.load_game()
	SceneRouter.set_stack($SceneStack)
	# Route to the learner login first if accounts are provisioned; otherwise straight
	# to the hub (offline). Login is skippable, so the game always reaches the hub.
	if Auth.configured() and not Auth.signed_in():
		SceneRouter.change_scene("res://scenes/ui/Login.tscn")
	else:
		SceneRouter.change_scene("res://scenes/ui/Hub.tscn")
